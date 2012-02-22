function Release-Handler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$projectPath,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		$destinationPath,
		$include = "\.Handlers$",
		$exclude,
		$profile,
		$admins = @("NT AUTHORITY\SYSTEM"),
		$computerName,
		$credential
	)

	$session = $null
	
	if($computerName -ne $null) {
		$session = New-PSSession -computerName $computerName -credential $credential
	}
	
	$syncInfo = GetHandlerSyncInfo -sourcePath $projectPath -destinationPath $destinationPath -include $include -exclude $exclude -session $session
	
	write-host "Handler sync info:"
	
	$syncInfo.Values | format-list -property Name, Action, Path, DestinationPath
	
	StopServices -syncInfo $syncInfo -session $session

	UninstallServices -syncInfo $syncInfo -session $session
	
	write-host "Waiting for 30 seconds to ensure that all services have stopped"
	start-sleep -seconds 30

	SyncHandlerFolders -syncInfo $syncInfo -session $session
    
	InstallQueues -syncInfo $syncInfo -profile $profile -session $session

	InstallServices -syncInfo $syncInfo -session $session
	
	StartServices -syncInfo $syncInfo -session $session
}

function Uninstall-Handler {
	param(
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		$path,
		$computerName,
		$credential
	)

	$session = $null
	
	if($computerName -ne $null) {
		$session = New-PSSession -computerName $computerName -credential $credential
	}
	
	$info = GetHandlerProjectInfo -path $path -session $session

	#get destinations that should be uninstalled
	$info.Values | foreach {
		$_ | add-member -membertype noteproperty -name Action -value "Uninstall"
	}
	
	write-host "Handler Info:"
	
	$info.Values | format-list -property Name, Path
	
	UninstallServices -syncInfo $info -session $session
	
	SyncHandlerFolders -syncInfo $info -session $session
}

function Create-HandlerQueues {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$projectPath,
		$admins = @("NT AUTHORITY\SYSTEM"),
		$computerName,
		$credential
	)
	
	$session = $null
	
	if($computerName -ne $null) {
		$session = New-PSSession -computerName $computerName -credential $credential
	}
	
	$handlerProjectInfos = GetHandlerProjectInfo -path $projectPath -session $session

	$handlerProjectInfos.Values | foreach {
		$inputQueueName = $_.Name
		
		write-host "Creating handler queue: $inputQueueName"

		New-PrivateMSMQQueue -name $inputQueueName -admins $admins -session $session
	}
}

function GetHandlerSyncInfo {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $sourcePath,
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $destinationPath,
		[string] $include,
		[string] $exclude,
		$session
	)
	
	$syncInfos = @{}
	
	$sourceInfo = GetHandlerProjectInfo -path $sourcePath -include $include -exclude $exclude
	$destinationInfo = GetHandlerProjectInfo -path $destinationPath -include $include -session $session

	write-verbose "Handlers at source:"
	$sourceInfo.Values | foreach { write-verbose $_.Name }
	write-verbose ""
	write-verbose "Handlers at destination:"
	$destinationInfo.Values | foreach { write-verbose $_.Name }
	
	$sourceInfo.Values | where { $_.Name -ne $null } | foreach { 
			$handlerDestPath = (join-path -path $destinationPath -childPath $_.Name)
			$handlerExePath = (join-path -path $handlerDestPath -childPath "NServiceBus.Host.exe")
			
			$info = $_ | add-member -membertype noteproperty -name Action -value "Install" -PassThru |
				 add-member -membertype noteproperty -name DestinationPath -value $handlerDestPath -PassThru |
				 add-member -membertype noteproperty -name DestinationExePath -value $handlerExePath -PassThru

			$syncInfos[$info.Name] = $info
		}
	
	#get destinations that should be uninstalled
	$destinationInfo.Values | where { $_.Name -ne $null -and $sourceInfo[$_.Name] -eq $null } | foreach {
		$info = $_ | add-member -membertype noteproperty -name Action -value "Uninstall" -PassThru
		$syncInfos[$info.Name] = $info
	}
	
	return [HashTable] $syncInfos
}

function GetHandlerProjectInfo {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $path,
		[string] $include = "\.Handlers$",
		[string] $exclude,
		$session
	)

	write-host "Getting Handler Project Infos"
	$paths = Invoke-CommandLocalOrRemotely -session $session -argumentList @($path, $include, $exclude) -scriptblock {
		Param($includePath, $include, $exclude)

		$infos = @{}

		write-host "Getting Handler Project Infos at $includePath"

		if((test-path $includePath -pathType container) -eq $true) 
		{
			$items = get-childitem -path $includePath -recurse | 
				where { $_.PsIsContainer } | 
				where { $_ -match $include }
						
			if(![string]::IsNullOrEmpty($exclude)) {
				$items = $items | where { $_ -notmatch $exclude }
			}

			$items | foreach {
				if($_ -ne $null) {
					$info = $_
					
					$info = New-Object Object |            
						Add-Member NoteProperty Name $_.Name -PassThru |
						Add-Member NoteProperty Path $_.FullName -PassThru

					$infos[$info.Name] = $info
				}
			}
		}

		return [HashTable] $infos
	}

	return [HashTable] $paths
}

function Package-Handler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$projectPath,
		$destination,
		[string] $configuration,
		[string] $include = "\.Handlers$",
		[string] $exclude,
		[switch] $recurse
	)
	
	$paths = @(GetHandlerProjectPaths -path $projectPath -include $include -exclude $exclude -recurse:$recurse -computerName $computerName)
	
	
	if($paths -eq $null -or $paths.Length -eq 0) {
		write-host "No handlers found"
	}
	else {
		PackageHandler -paths $paths -destination $destination -configuration $configuration
	}
}

function Get-HandlerProjectPaths {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $path,
		[string] $include = "\.Handlers$",
		[string] $exclude,
		[switch] $name,
		$computerName,
		$credential
	)
	return @(GetHandlerProjectPaths -path $path -include $include -exclude $exclude -name:$name -computerName $computerName -recurse)
}

function GetHandlerProjectPaths {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $path,
		[string] $include = "\.Handlers$",
		[string] $exclude,
		[switch] $name,
		[switch] $recurse,
		$computerName,
		$credential
	)
	
	$paths = @()
	
	if(!$recurse) {
		return @($path)
	}
	
	$scriptBlock = {
		Param($rootPath, $include, $exclude)
		
		if((test-path $rootPath -pathType container) -eq $false) {
			@()
		}
		else {
			$items = get-childitem -path $rootPath -recurse | where { $_.PsIsContainer } 
						
			$items = $items | Where { $_ -match $include }
			
			if(![string]::IsNullOrEmpty($exclude)) {
				$items = $items | Where { $_ -notmatch $exclude }
			}

			$items
		}
	}
		
	$args = @($path, $include, $exclude)
	
	if($computerName -ne $null) {
		write-verbose "Get-HandlerProjectPaths on computer: $computerName"
		$session = New-PSSession -computerName $computerName -credential $credential
		$paths = invoke-command -session $session -argumentList $args -scriptblock $scriptBlock
		Remove-PSSession $session
	}
	else {
		$paths = $scriptBlock.Invoke($args)
	}

	if($null -eq $paths) { 
		$paths = @()
	}
		
	if($name) { 
		return $paths | foreach { Get-HandlerName $_ } 
	}
	else {
		$paths | foreach { write-verbose "Handler endpoint project found at: $_" }
		return [array] $paths 
	}
}

function PackageHandler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNull()]
		$paths,
		$destination,
		[string] $configuration
	)
	
	$paths | foreach {
		$path = $_
		
		if($path -ne $null) {
			$handlerName = $path.Name
			
			$destinationPath = join-path $destination $handlerName
			
			new-directory $destinationPath
			
			#$destinationPath = join-path $destinationPath "$handlerName.zip"
			
			$sourcePath = join-path $path.FullName "bin\$configuration"

			if(!(test-path $sourcepath -PathType Container)) { write-error "Could not find source path ( $sourcePath ). Did you forget to compile?" }

			write-host "Packaging Handler: $handlerName"
			write-host "  Source: $sourcePath" 
			write-host "  Destination: $destinationPath"

			Sync-Provider -sourcePath $sourcePath -sourceProvider "dirPath" -destinationPath $destinationPath -destinationProvider "dirpath"
		}
	}
}

function SyncHandlerFolders {
	param(
		$syncInfo,
		$session
	)

	write-host "Syncing Handler Folders:"

	$syncInfo.Values | foreach {
		$path = $_.Path
		$handlerName = $_.Name
		
		if($_.Action -eq "Install") {
			$dest = $_.DestinationPath
			
			write-host ("Copying Handler {0}" -f $handlerName)
			write-verbose ("Copying From {0}" -f $path)
			write-verbose ("Copying To {0}" -f $dest)
			
			$computer = $null
			
			if($session -ne $null) {
				$computer = $session.ComputerName
			}

			Sync-Provider -sourcePath $path.ToString() -sourceProvider "dirPath" -destinationPath $dest -destinationProvider "dirPath" -computer $computer
		}
		else {
			write-verbose ("Removing From {0}" -f $path)
			
			Invoke-CommandLocalOrRemotely -session $session -argumentList @($path) -scriptblock {
				Param($path)
				Remove-Item -path $path -force -recurse
			}
		}
	}
}

function StopServices {
	param(
		$syncInfo,
		$session
	)
	
	write-host "Stopping handler services"
	
	Invoke-CommandLocalOrRemotely -session $session -argumentList @($syncInfo) -scriptblock {	
		Param($syncInfo)
		$syncInfo.Values | foreach {
			$name = $_.Name
			
			$isInstalled = (Get-Service -include $name) -ne $null

			if(!$isInstalled) {
				write-host ("Service not found. Skipping {0}" -f $name)
			}
			else {
                write-host ("Stopping {0}" -f $name)
                $service = Stop-Service -Name $name -force -passthru
				
				#wait 30 seconds for the service to get deleted
				while(($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped) -and ($elapsed -lt 30000)) {
					start-sleep -Milliseconds 20 | out-null
					$elapsed += 20
				}

				if($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
					write-error "Service has not been stopped after timeout"
				}
			}
		}
	}
}

function UninstallServices {
	param(
		$syncInfo,
		$session
	)
	
	write-host "Uninstalling handler services"
	
	Invoke-CommandLocalOrRemotely -session $session -argumentList @($syncInfo) -scriptblock {	
		Param($syncInfo)
		$syncInfo.Values | where { $_.Action -eq "Uninstall" } | foreach {
			$name = $_.Name
			
			$isInstalled = (Get-Service -include $name) -ne $null
				
			if(!$isInstalled) {
				write-host ("Skipping {0}" -f $name)
			}
			else {
                write-host ("Stopping {0}" -f $name)
                
                Stop-Service -Name $name | out-null
				#exit
				write-host ("Uninstalling {0}" -f $name)
				$service = get-wmiobject win32_service -filter "name='$name'"
				$service.Delete() | out-null
				
				$elapsed = 0
				
				#wait for 30 seconds for the service to get deleted
				while(((Get-Service -include $name) -ne $null) -and ($elapsed -lt 30000)) {
					start-sleep -Milliseconds 50  | out-null
					$elapsed += 50
				}
				
				if((Get-Service -include $name) -ne $null) {
					write-error "Service has not been deleted after timeout"
				}
			}
		}
	}
}

function InstallQueues {
	param(
		$syncInfo,
		$session
	)
	
	$syncInfo.Values | where { $_.Action -eq "Install" } | foreach {
		$inputQueueName = $_.Name
		
		write-host "Creating handler queue: $inputQueueName"

		New-PrivateMSMQQueue -name $inputQueueName -admins $admins -session $session
	}
}

function InstallServices {
	param(
		$syncInfo,
		$profile,
		$session
	)	
	if($profile -eq $null) {
		$profile = "NServiceBus.Production"
	}

	$syncInfo.Values | where { $_.Action -eq "Install" } | foreach {
		$inputQueueName = $_.Name
		$path = $_.DestinationExePath
		write-host "Installing Service '$inputQueueName'"
		
		Invoke-CommandLocalOrRemotely -session $session -argumentList @($inputQueueName, $path, $profile) -scriptblock {
			Param($name, $path, $profile)
			
			$pathName = "$path -service $profile /servicename:$name"
			
			$service = get-wmiobject win32_service -filter "name='$name'"
						
			if($service -eq $null) 
			{
				new-service -name $name -displayName $name -Description $name -binaryPathName $pathName | out-null
			}
			elseif($service.PathName -ne $pathName) 
			{
				write-host ("Service found. Reinstalling {0}" -f $name)
				$service.Delete() | out-null
				
				new-service -name $name -displayName $name -Description $name -binaryPathName $pathName | out-null
			}
		}
	}
}

function StartServices {
	param(
		$syncInfo,
		$session
	)

	Invoke-CommandLocalOrRemotely -session $session -argumentList @($syncInfo) -scriptblock {
		Param($syncInfo)
		
		$syncInfo.Values | where { $_.Action -eq "Install" } | foreach {
			$name = $_.Name

			write-host "Starting handler service '$name'"
			
			$service = start-service -name $name -passThru
			
			#$service | wait-process -timeout 50
			
			#if($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running) {
			#	write-host "Service did not start before timeout"
			#}
			
		}
	}
}

function Invoke-CommandLocalOrRemotely {
	param(
		$scriptBlock,
		$argumentList = @(),
		$session
	)
	
	if($session -ne $null) {
		write-verbose ("Running on computer {0}" -f $session.ComputerName)
		return invoke-command -session $session -argumentList $argumentList -scriptblock $scriptBlock
	}
	else {
		write-verbose "Running locally"
		return $scriptBlock.Invoke($argumentList)
	}
}

Export-ModuleMember -Function "Release-Handler", "Uninstall-Handler", "Create-HandlerQueues", "Get-HandlerProjectPaths", "Package-Handler"