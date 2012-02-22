function Invoke-DosCommand {
	param(
		$program, 
		[string[]] $programArgs = @(),
		$computerName,
		[switch] $passThru
	)
	
	write-host "Running command: $program on $computerName";
	write-verbose " Args:"
	
	0..($programArgs.Count-1) | foreach-object { Write-Verbose " $($_+1): $($programArgs[$_])" }
	
	if($computerName -eq $null) {
		& $program $programArgs | Out-Host

		$exitCode = $LastExitCode
	}
	else {
		$session = New-PSSession -computername $computerName
		
		invoke-command -session $session -argumentList @($program, $programArgs) -scriptblock { 
			Param($program, $programArgs)
			& $program $programArgs | out-null
		} | Out-Host
		
		$exitCode = invoke-command -session $session { 
			$LastExitCode
		}

		remove-pssession -session $session | out-null		
	}

	if($passThru.IsPresent) {
		return $exitCode
	}
}

function Expect-ExitCode {
	param(
		[parameter(Position=0)]
		[Int32[]] $expectedExitCode = @(0),
		[parameter(Position=1)]
		$formatMessage = $null,
		[parameter(ValueFromPipeline = $true, Position=3)]
		[Int32] $exitCode = $LastExitCode
	)
	if(!($expectedExitCode -contains $exitCode)) {
		write-verbose "Exit Code $exitCode was not expected"
		
		if($formatMessage -ne $null) {
			$message = invoke-command -argumentList @($exitCode) -scriptblock $formatMessage
		}
		
		if($message -eq $null) {
			$message = "Exit Code was not expected"
		}
		
		throw $message
	}
}

Export-ModuleMember -Function "Invoke-DosCommand", "Expect-ExitCode"