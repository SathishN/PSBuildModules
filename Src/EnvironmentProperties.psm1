function propertiesFile {
	Param(
		[parameter(Mandatory=$true)]
		[ValidateNotNullOrEmpty()]
		[string] $path
	)
	
	if(test-path $path) {
		write-host ("Loading properties file: {0}" -f $path)
		properties { . $path }
	}
	else {
		throw ("Properties file not found at: {0}" -f $path)
	}	
}

function environmentPropertiesFile {
	Param(
		[parameter(Mandatory=$true)]
		[string] $environment,
		[parameter(Mandatory=$false)]
		[string] $directory = "."
	)
	
	if([string]::IsNullOrEmpty($environment)) {
		throw "Environment was not specified. Please specify environment in the parameters for psake Ex: -parameters @{ environment='CI' }"
	}
	
	write-host "Environment: $environment"
	
	$environmentPropertiesFile = ("$directory\properties.{0}.ps1" -f $environment)
    
	if(test-path $environmentPropertiesFile) {
		propertiesFile $environmentPropertiesFile
	}
	else {
		write-host ("Environment property file not found at: {0}" -f $environmentPropertiesFile)
	}
}

Export-ModuleMember -function "propertiesFile", "environmentPropertiesFile"