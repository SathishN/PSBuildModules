function New-PrivateMSMQQueue { 
	param (
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string]$name,
		[bool] $transactional = $true,
		[string[]]$admins = @("NT AUTHORITY\SYSTEM"),
		$computerName,
		$credential,
		$session
	) 
	
	$args = @($name, $admins, $transactional)
	
	Invoke-CommandLocalOrRemotely -session $session -computerName $computerName -credential $credential -argumentList $args -ea Stop -scriptblock {
		Param($name, $admins, $transactional)
		[void][System.Reflection.Assembly]::LoadWithPartialName("System.Messaging")
		
		$queuePath = ".\private$\$name"
		
		if ([System.Messaging.MessageQueue]::Exists($queuePath))
		{
			write-host "Queue '$name' already exists"
			
			$queue = new-object System.Messaging.MessageQueue -argumentList $queuePath
		}
		else
		{
			$queue = [System.Messaging.MessageQueue]::Create($queuePath, $transactional)
			
			if ([System.Messaging.MessageQueue]::Exists($queuePath))
			{
				write-host "Private queue '$name' has been created"
				$queue.Label = $name
			}
			else
			{
				write-error "Queue '$name' could not be created!!!"
			}
		}		
	
		$queue.SetPermissions("BUILTIN\Administrators", [System.Messaging.MessageQueueAccessRights]::FullControl, [System.Messaging.AccessControlEntryType]::Set)
		
		if($admins -ne $null) {
			$admins | foreach {
				$queue.SetPermissions($_, [System.Messaging.MessageQueueAccessRights]::FullControl, [System.Messaging.AccessControlEntryType]::Set)
			}
		}
	}
}

Export-ModuleMember -Function "New-PrivateMSMQQueue"