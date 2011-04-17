function Release-Handler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$projectPath,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		$destinationPath,
		$profile,
		[switch] $recurse,
		[switch] $skipUninstall,
		[switch] $skipCreateQueues,
		$computerName,
		$credential
	)
	
	if(!$skipUninstall) {
		$uninstallPaths = @(GetHandlerProjectPaths -path $destinationPath -recurse:$recurse -computerName $computerName -credential $credential)
		
		UninstallHandler -paths $uninstallPaths -computerName $computerName -credential $credential
	}
	
	$paths = GetHandlerProjectPaths -path $projectPath -recurse:$recurse

	DeployHandler -paths $paths -destinationPath $destinationPath -computerName $computerName -credential $credential

	NewHandlerInputQueue -paths $paths -computerName $computerName -credential $credential

	$installPaths = @(GetHandlerProjectPaths -path $destinationPath -recurse:$recurse -computerName $computerName -credential $credential)

	InstallHandler -paths $installPaths -profile $profile -computerName $computerName -credential $credential

	StartHandler -paths $installPaths -computerName $computerName -credential $credential
}

function Get-HandlerProjectPaths {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $path,
		[string[]] $include = @("*.Handlers","*.Saga","*.Service"),
		[switch] $name,
		$computerName,
		$credential
	)
	return @(GetHandlerProjectPaths -path $path -include $include -name:$name -computerName $computerName -recurse)
}

function Get-HandlerName {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$path
	)
	
	return $path.Name
}

function Deploy-Handler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$projectPath,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		$destinationPath,
		[switch] $recurse,
		$computerName,
		$credential
	)

	$paths = @(GetHandlerProjectPaths -path $projectPath -recurse:$recurse -computerName $computerName)
	
	DeployHandler -paths $paths -destinationPath $destinationPath -computerName $computerName
}

function Package-Handler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$projectPath,
		$destination,
		[string] $configuration,
		[switch] $recurse
	)
	
	$paths = @(GetHandlerProjectPaths -path $projectPath -recurse:$recurse -computerName $computerName)
	
	PackageHandler -paths $paths -destination $destination -configuration $configuration
}

function Install-Handler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$path,
		$profile,
		[switch] $recurse,
		$computerName,
		$credential
	)
	
	$paths = @(GetHandlerProjectPaths -path $path -recurse:$recurse -computerName $computerName)
	
	InstallHandler -paths $paths -profile $profile -computerName $computerName
}

function Uninstall-Handler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$path,
		[switch] $recurse,
		$computerName,
		$credential
	)
	
	$paths = @(GetHandlerProjectPaths -path $path -recurse:$recurse -computerName $computerName)
	
	UninstallHandler -paths $paths
}

function Start-Handler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$path,
		[switch] $recurse,
		$computerName,
		$credential
	)
	
	$paths = @(GetHandlerProjectPaths -path $projectPath -recurse:$recurse -computerName $computerName)
	
	StartHandler -paths $paths -computerName $computerName
}

function New-HandlerInputQueue {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$path,
		[switch] $recurse,
		$computerName,
		$credential
	)

	$paths = @(GetHandlerProjectPaths -path $path -recurse:$recurse -computerName $computerName)

	NewHandlerInputQueue -paths $paths -computerName $computerName -credential $credential
}

function Get-HandlerInputQueue {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$path
	)
	
	if(!(test-path $path.FullName)) { write-error ("Handler path does not exist: " + $path.FullName) }
	
	$handlerName = $path.Name
	
	$projectAppConfig = join-path $path.FullName "$handlerName.dll.config"
	$timeoutAppConfig = join-path $path.FullName "Timeout.MessageHandlers.dll.config"
	
	$appConfig = $projectAppConfig
	
	if(!(test-path $appConfig)) { 
		$appConfig = $timeoutAppConfig
	}
	
	if(!(test-path $appConfig)) { write-error "Handler app.config does not exist at: $projectAppConfig or at $timeoutAppConfig" }

	$inputQueue = Select-Xml "//UnicastBusConfig/@LocalAddress[1]" -path $appConfig
	
	if($inputQueue -eq $null) { 
		$inputQueue = Select-Xml "//MsmqTransportConfig/@InputQueue[1]" -path $appConfig
	}

	if($inputQueue -eq $null) { write-error "Input queue is not defined in either UnicastBusConfig or an MsmqTransportConfig element: $appConfig" }
	
	$queueName =  $inputQueue.Node.Value
	
	if($queueName -eq $null) { write-error "Could not parse the inputQueue attribute in app.config: $appConfig" }
	
	return $queueName
}

function GetHandlerProjectPaths {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $path,
		[string[]] $include = @("*.Handlers","*.Saga","*.Service","*.TimeoutManager"),
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
		Param($rootPath, $include)
		$includePath = $rootPath.TrimEnd('\') + "*"
		
		get-childitem -path $includePath -include $include -recurse | where { $_.PsIsContainer }
	}
		
	$args = @($path, $include)
	
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
		write-host "Paths was Null"
		$paths = @()
	}
	
	$isNull = ($null -eq $paths)
	write-host ("Is Null: " + $isNull)
	
	if($name) { 
		return $paths | foreach { Get-HandlerName $_ } 
	}
	else {
		$paths | foreach { write-verbose $_ }
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

function DeployHandler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNull()]
		$paths,
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		$destinationPath,
		$computerName,
		$credential
	)
	
	$paths | foreach {
		$path = $_
		$handlerName = $path.Name
			
		$dest = join-path $destinationPath $handlerName
		
		write-host ("Deploying Handler from {0} to {1}" -f $path, $dest)
		
		Sync-Provider -sourcePath $path.ToString() -sourceProvider "dirPath" -destinationPath $dest -destinationProvider "dirPath" -computer $computerName
	}
}

function NewHandlerInputQueue {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNull()]
		$paths,
		$computerName,
		$credential
	)
	
	$paths | foreach {
		$path = $_
		$inputQueueName = Get-HandlerInputQueue $path
		
		write-host "Creating handler queue: $inputQueueName"

		New-PrivateMSMQQueue -name $inputQueueName -admins @("NT AUTHORITY\SYSTEM") -computerName $computerName -credential $credential
	}
}

function InstallHandler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNull()]
		$paths,
		$profile,
		$computerName,
		$credential
	)

	$session = $null
	
	if($computerName -ne $null) {
		$profile = "NServiceBus.Lite"
	}
	
	if($computerName -ne $null) {
		write-verbose "Install-Handler on computer: $computerName"
		$session = New-PSSession -computerName $computerName -credential $credential
	}
	
	$scriptBlock = {
		Param($nsbHostPath, $handlerName, $profile)
		if(!(test-path $nsbHostPath)) { write-error "Could not install handler '$handlerName' Unable to find NServiceBus.Host.exe at $nsbHostPath" }

		& $nsbHostPath $profile /install /serviceName:$handlerName /displayName:$handlerName

		if($LastExitCode -ne 0) { write-error "$handlerName did not install correctly" }
	}
	
	$paths | foreach {
		$path = $_
		$handlerName = Get-HandlerName $path
		
		write-host "Installing $handlerName using profile: $profile"
		
		$nsbHostPath = join-path $path "NServiceBus.Host.exe"
	
		$args = @($nsbHostPath, $handlerName, $profile)
		
		if($session -ne $null) {
			invoke-command -session $session -argumentList $args -scriptblock $scriptBlock
		}else {
			$scriptBlock.Invoke($args)
		}
	}
	
	if($session -ne $null) { Remove-PSSession $session }
}

function UninstallHandler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNull()]
		$paths,
		$computerName,
		$credential
	)
	
	$session = $null
	
	if($computerName -ne $null) {
		write-verbose "Install-Handler on computer: $computerName"
		$session = New-PSSession -computerName $computerName -credential $credential
	}
	
	$scriptBlock = {
		Param($nsbHostPath, $handlerName)
		if(!(test-path $nsbHostPath)) { write-error "Could not uninstall handler '$handlerName' Unable to find NServiceBus.Host.exe at $nsbHostPath" }

		& $nsbHostPath /uninstall /serviceName:$handlerName

		if($LastExitCode -ne 0) { write-error "$handlerName did not uninstall correctly" }
	}
	
	$paths | foreach {
		$path = $_
		$handlerName = Get-HandlerName $path

		write-host "Uninstalling $handlerName"

		$nsbHostPath = join-path $path "NServiceBus.Host.exe"

		$args = @($nsbHostPath, $handlerName)

		if($session -ne $null) {
			invoke-command -session $session -argumentList $args -scriptblock $scriptBlock
		}else {
			$scriptBlock.Invoke($args)
		}
	}
	
	if($session -ne $null) { Remove-PSSession $session }
}

function StartHandler {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNull()]
		$paths,
		$computerName,
		$credential
	)

	$session = $null
	
	if($computerName -ne $null) {
		write-verbose "Install-Handler on computer: $computerName"
		$session = New-PSSession -computerName $computerName -credential $credential
	}
	
	$scriptBlock = {
		Param($handlerName)
		
		Start-Service $handlerName
	}
	
	$paths | foreach {
		$path = $_
		$handlerName = Get-HandlerName $path
		
		write-host "Starting $handlerName"
		
		$args = @($handlerName)
		
		if($session -ne $null) {
			invoke-command -session $session -argumentList $args -scriptblock $scriptBlock
		}else {
			$scriptBlock.Invoke($args)
		}
	}
	
	if($session -ne $null) { Remove-PSSession $session }
}

Export-ModuleMember -Function "Release-Handler", "Deploy-Handler", "Get-HandlerProjectPaths", "Package-Handler", "Copy-HandlerProjectOutput", "Install-Handler", "Uninstall-Handler", "New-HandlerInputQueue", "Get-HandlerInputQueue"