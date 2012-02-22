function Invoke-CommandLocalOrRemotely {
	param(
		$scriptBlock,
		$argumentList = @(),
		$computerName,
		$credential,
		$session
	)
	
	$closeSession = $false
	
	if($session -eq $null -and $computerName -ne $null) {
		#write-host "Creating remote session for computer: $computerName"
		#$session = New-PSSession -computerName $computerName -credential $credential -ea Stop
		
		write-verbose ("Running on computer {0}" -f $computerName)
		
		invoke-command -computerName $computerName -credential $credential -argumentList $argumentList -scriptblock $scriptBlock -verbose -ea Stop
		
		#write-host "Closing remote session for computer: $computerName"
		#Remove-PSSession $session
		
	}
	elseif($session -ne $null) {
		write-verbose ("Running on computer {0}" -f $session.ComputerName)
		return invoke-command -session $session -argumentList $argumentList -scriptblock $scriptBlock -verbose -ea Stop
	}
	else {
		write-verbose "Running locally"
		return $scriptBlock.Invoke($argumentList)
	}
}

Export-ModuleMember -Function "Invoke-CommandLocalOrRemotely"