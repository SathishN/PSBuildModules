$script:msbuildModule = @{}
$script:msbuildModule.msBuildPath = $null

Export-ModuleMember -Variable "msbuildModule"

function Invoke-MSBuild([string[]]$msbuildArgs)
{
	if($script:msbuildModule.msBuildPath -ne $null)
	{
		Write-Host "Custom MSBuild Path Defined: $script:msbuildModule.msBuildPath"
		$msbuild = $script:msbuildModule.msBuildPath
	}
	else
	{
		$msbuild = "msbuild.exe"
	}

	exec { msbuild $msbuildArgs }
}

function Get-SolutionFiles {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $baseDirectory
	)
	return @(get-item -path "$baseDirectory\*.sln")
}

function Compile-MSBuild {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $solutionFile, 
		
		[parameter(Mandatory=$false)]
		[string] $outDirectory, 
		
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[string] $configuration
	)
	
	if(test-path $solutionFile -pathType leaf){
		$solutions = $solutionFile
	} else {
		$solutions = Get-SolutionFiles $solutionFile
	}
	
	$solutions | foreach-object { 
		CompileMSBuild $_ $outDirectory $configuration -ea Stop
	}
}

function Package-WebApplicationProject {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $webProjectFile, 
		
		[parameter(Mandatory=$false)]
		[string] $outputPath,
		
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string] $packageLocation, 
		
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string] $configuration
	)
	
	if(!(test-path $webProjectFile -pathType leaf)){
		write-error ("Web application project does not exist at: {0}" -f $webProjectFile)
	}
	
	$parentDirectory = Split-Path -path $packageLocation -parent
	
	if(!(test-path $parentDirectory -pathType Container)) {
		new-directory $parentDirectory
	}
	
	if([string]::IsNullOrEmpty($outputPath)) {
		$outputPath = join-path $parentDirectory "bin"
		write-host ("Setting output path to: {0}" -f $outputPath)
	}
	
	write-host ("Packaging {0}" -f $webProjectFile)

	$arguments = @("`"$webProjectFile`"",
		"/t:Package",
		"/verbosity:minimal",
		"/p:Platform=Any CPU",
		"/p:PackageLocation=$packageLocation",
		"/p:OutputPath=$outputPath\\\")

	if(![string]::IsNullOrEmpty($configuration)) {
		$arguments += "/p:Configuration=$configuration"
	}

	#The \\\ on the OutDir param is needed for paths with spaces... WTF MSBuild...
	Invoke-MSBuild $arguments
			
	Expect-ExitCode -message "Package failed"
}

function CompileMSBuild {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $solutionFile, 
		
		[parameter(Mandatory=$false)]
		[string] $outDirectory, 
		
		[parameter(Mandatory=$false)]
		[ValidateNotNullOrEmpty()]
		[string] $configuration
	)

	write-host ("Compiling {0}" -f $solutionFile)
		
	$arguments = @("`"$solutionFile`"",
		"/t:Rebuild",
		"/verbosity:minimal",
		"/p:Platform=Any CPU")

	if(![string]::IsNullOrEmpty($configuration)) {
		$arguments += "/p:Configuration=$configuration"
	}		
			
	if(![string]::IsNullOrEmpty($outDirectory)) {
		$arguments += "/p:OutDir=$outDirectory\\\"
	}
		
	#The \\\ on the OutDir param is needed for paths with spaces... WTF MSBuild...
	Invoke-MSBuild $arguments
			
	Expect-ExitCode -message "Compile failed"
}

Export-ModuleMember -Function "Invoke-MSBuild", "Compile-MSBuild", "Get-SolutionFiles", "Package-WebApplicationProject"