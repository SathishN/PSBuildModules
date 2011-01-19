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
		& $program $programArgs
		$exitCode = $LastExitCode
	}
	else {
		$session = New-PSSession -computername $computerName
		
		$exitCode = invoke-command -session $session -argumentList @($program, $programArgs) -scriptblock { 
			Param($program, $programArgs)
			& $program $programArgs | out-null
			return $LastExitCode
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
		[string] $message = "Exit Code was not expected",
		[parameter(ValueFromPipeline = $true, Position=2)]
		[Int32] $exitCode = $LastExitCode
	)
	if(!($expectedExitCode -contains $exitCode)) {
		write-verbose ("Exit Code {0} was not expected" -f $exitCode)
		throw $message
	}
}

Export-ModuleMember -Function "Invoke-DosCommand", "Expect-ExitCode"