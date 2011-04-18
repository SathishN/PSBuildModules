function New-PrivateMSMQQueue { 
	param (
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$name,
		[bool] $transactional = $true,
		[string[]]$admins,
		$computerName,
		$credential
	) 
	
	$scriptblock = {
		Param($name, $admins, $transactional)
		[void][System.Reflection.Assembly]::LoadWithPartialName("System.Messaging")
		
		$queuePath = ".\private$\$name"
		
		if ([System.Messaging.MessageQueue]::Exists($queuePath))
		{
			write-host "$name already exists"
			
			$queue = new-object System.Messaging.MessageQueue -argumentList $queuePath
		}
		else
		{
			$queue = [System.Messaging.MessageQueue]::Create($queuePath, $transactional)
			
			if ([System.Messaging.MessageQueue]::Exists($queuePath))
			{
				write-host "Private queue ""$name"" has been created"
				$queue.Label = $name
			}
			else
			{
				write-error "$name could not be created!!!"
			}
		}		
	
		$queue.SetPermissions("BUILTIN\Administrators", [System.Messaging.MessageQueueAccessRights]::FullControl, [System.Messaging.AccessControlEntryType]::Set)

		$admins | foreach {
			$queue.SetPermissions($_, [System.Messaging.MessageQueueAccessRights]::FullControl, [System.Messaging.AccessControlEntryType]::Set)
		}
	}
	
	$args = @($name, $admins, $transactional)
	
	if($computerName -ne $null) {
		write-verbose "New-PrivateMSMQQueue on computer: $computerName"
		$session = New-PSSession -computerName $computerName -credential $credential
		invoke-command -session $session -argumentList $args -scriptblock $scriptBlock
		Remove-PSSession $session
	}
	else {
		$scriptBlock.Invoke($args)
	}
}

Export-ModuleMember -Function "New-PrivateMSMQQueue"