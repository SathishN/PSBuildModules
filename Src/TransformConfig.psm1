$script:transformConfig = @{}
$script:transformConfig.buildFrameworkPath = join-path ($MyInvocation.MyCommand.Path | Split-Path) "Microsoft.Build.Framework.dll"
$script:transformConfig.buildUtilPath = join-path ($MyInvocation.MyCommand.Path | Split-Path) "Microsoft.Build.Utilities.v4.0.dll"
$script:transformConfig.tasksPath = join-path ($MyInvocation.MyCommand.Path | Split-Path) "Microsoft.Web.Publishing.Tasks.dll"

[System.Reflection.Assembly]::LoadFrom($script:transformConfig.buildFrameworkPath) | out-null
[System.Reflection.Assembly]::LoadFrom($script:transformConfig.buildUtilPath) | out-null
[System.Reflection.Assembly]::LoadFrom($script:transformConfig.tasksPath) | out-null

function Transform-ConfigFileForProject {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$projectPath,
		$configuration,
		$environment,
		[switch] $recurse
	)

	write-host ("Transforming config for projects in: {0}" -f $projectPath)
	
	if($environment -eq $null) { $environment = $configuration }
		
	GetProjectPaths -path $projectPath -recurse:$recurse | foreach {
		$path = $_

		$sourceFile = join-path $path ("bin\{0}\{1}.dll.config" -f $configuration, $path.Name)
		
		$continue = $false
		
		if(!(test-path $sourceFile -pathType Leaf)) {
			write-host ("Skipping transform. Source file not found at: {0}" -f $sourceFile)
			$continue = $true
		}

		$transformFile = join-path $path ("App.{0}.config" -f $environment)
		
		if(($continue -eq $false) -and !(test-path $transformFile -pathType Leaf)) {
			write-host ("Skipping transform. Transform file not found at: {0}" -f $transformFile)
			$continue = $true
		}

		if($continue -eq $false) {
			write-host ("Transforming config for project at: {0}" -f $path)
			Transform-ConfigFile -sourceFile $sourceFile -transformFile $transformFile -destinationFile $sourceFile
		}
	}
}

function Transform-ConfigFileForWebApplicationProject {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$projectPath,
		$configuration,
		$environment
	)

	write-host ("Transforming config for web application project in: {0}" -f $projectPath)
	
	if($environment -eq $null) { $environment = $configuration }

	$path = $projectPath

	$sourceFile = join-path $path ("Web.config" -f $configuration, $path.Name)
	
	$continue = $false
	
	if(!(test-path $sourceFile -pathType Leaf)) {
		write-host ("Skipping transform. Source file not found at: {0}" -f $sourceFile)
		$continue = $true
	}

	$transformFile = join-path $path ("Web.{0}.config" -f $environment)
	
	if(($continue -eq $false) -and !(test-path $transformFile -pathType Leaf)) {
		write-host ("Skipping transform. Transform file not found at: {0}" -f $transformFile)
		$continue = $true
	}

	if($continue -eq $false) {
		write-host ("Transforming config for project at: {0}" -f $path)
		Transform-ConfigFile -sourceFile $sourceFile -transformFile $transformFile -destinationFile $sourceFile
	}
}

function Transform-ConfigFileForWebApplicationProject-BeforePackage {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$projectPath,
		$configuration,
		$environment
	)
	
	
	$sourcePath = $projectPath | Split-Path -parent
	write-host ("Transforming config for web application project in: {0}" -f $sourcePath)
	
	$sourceFile = join-path $sourcePath ("Web.config" -f $configuration, $sourcePath.Name)
	write-host ("{0}configuration" -f $configuration)
	write-host ("{0}" -f $sourceFile)

	$continue = $false
	
	if(!(test-path $sourceFile -pathType Leaf)) {
		write-host ("Skipping transform. Source file not found at: {0}" -f $sourceFile)
		$continue = $true
	}

	$transformFile = join-path $sourcePath ("Web.{0}.config" -f $environment)
	write-host("{0}" -f $transformFile)

	if(($continue -eq $false) -and !(test-path $transformFile -pathType Leaf)) {
		write-host ("Skipping transform. Transform file not found at: {0}" -f $transformFile)
		$continue = $true
	}

	if($continue -eq $false) {
		write-host ("Transforming config for project at: {0}" -f $sourcePath)
		Transform-ConfigFile -sourceFile $sourceFile -transformFile $transformFile -destinationFile $sourceFile
	}
	
	
	
}

function Transform-ConfigFileForXap {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $xapPath,
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $environment,
		[string[]] $prefixes = @("ServiceReferences", "Xap"),
		[switch] $recurse
	)

	write-host ("Transforming config for xap file: {0}" -f $xapPath)
	
	foreach($prefix in $prefixes) {
		$configFile = "{0}.clientConfig" -f $prefix
		$transformFile = "{0}.{1}.clientConfig" -f $prefix, $environment

		Transform-ConfigFileForZip $xapPath $configFile $transformFile
	}
}
function Transform-ConfigFileForXap-BeforePackage {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $xapProjectPath,
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $environment
	
	)

		
	
	$sourcePath = $xapProjectPath 
	write-host ("Transforming config for web application project in: {0}" -f $sourcePath)
	
	$sourceFile = join-path $sourcePath ("App.config" -f $configuration, $sourcePath.Name)
	
	write-host ("SourceFile{0}" -f $sourceFile)

	$continue = $false
	
	if(!(test-path $sourceFile -pathType Leaf)) {
		write-host ("Skipping transform. Source file not found at: {0}" -f $sourceFile)
		$continue = $true
	}

	$transformFile = join-path $sourcePath ("App.{0}.config" -f $environment)
	write-host("TransformFile{0}" -f $transformFile)

	if(($continue -eq $false) -and !(test-path $transformFile -pathType Leaf)) {
		write-host ("Skipping transform. Transform file not found at: {0}" -f $transformFile)
		$continue = $true
	}

	if($continue -eq $false) {
		write-host ("Transforming config for project at: {0}" -f $sourcePath)
		Transform-ConfigFile -sourceFile $sourceFile -transformFile $transformFile -destinationFile $sourceFile
	}
	$sourceConfigFile = join-path $sourcePath ("ServiceReferences.ClientConfig" -f $configuration, $sourcePath.Name)
	$transformConfigFile = join-path $sourcePath ("ServiceReferences.{0}.ClientConfig" -f $environment)
	write-host("TransformConfigFile{0}" -f $transformConfigFile)

	if(($continue -eq $false) -and !(test-path $transformConfigFile -pathType Leaf)) {
		write-host ("Skipping transform. Transform file not found at: {0}" -f $transformConfigFile)
		$continue = $true
	}

	if($continue -eq $false) {
		write-host ("Transforming config for project at: {0}" -f $sourcePath)
		Transform-ConfigFile -sourceFile $sourceConfigFile -transformFile $transformConfigFile -destinationFile $sourceConfigFile
	}
	
}
function Transform-ConfigFileForZip {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[string] $zipPath,
		[string] $sourceFile,
		[string] $transformFile
	)
	
	if(!(test-path $zipPath -pathType Leaf)) {
		write-host ("Skipping transform. File not found at: {0}" -f $zipPath)
		return
	}
	
	$destination = $zipPath | Split-Path -parent
	
	write-host ("Attempting to extract '{0}' & '{1}' from '{0}'" -f $sourceFile, $transformFile, $zipPath)
	
	Extract-ZipFile -zipPath $zipPath -destination $destination -files @($sourceFile, $transformFile)
	
	$sourceDestFile = join-path $destination $sourceFile
	$transformDestFile = join-path $destination $transformFile
	
	if((test-path $sourceDestFile -pathType Leaf)) {
		write-host "Source file found: $sourceDestFile"
	}
	else {
		write-verbose "Skipping transform. Source file not found: $sourceDestFile"
		return
	}
		
	if((test-path $transformDestFile -pathType Leaf)) {
		write-host "Transformation file found: $transformDestFile"
	}
	else {
		write-verbose "Skipping transform. Transformation file not found: $transformDestFile"
		return
	}
	
	Transform-ConfigFile -sourceFile $sourceDestFile -transformFile $transformDestFile -destinationFile $sourceDestFile
	
	Update-ZipFile -zipPath $zipPath -files $sourceDestFile
	
	remove-item $sourceDestFile -ea SilentlyContinue
	remove-item $transformDestFile -ea SilentlyContinue
	
}

function Transform-ConfigFile {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		$sourceFile,
		$transformFile,
		$destinationFile
	)
	
	if(!(test-path $sourceFile -pathType Leaf)) {
		write-error ("Cannot transform config file. Source file not found: {0}" -f $sourceFile)
	}
	
	if(!(test-path $transformFile -pathType Leaf)) {
		write-error ("Cannot transform config file. Transform file not found: {0}" -f $transformFile)
	}
	
	write-host "Transforming Config"
	write-host ("  Source file: {0}" -f $sourceFile)
	write-host ("  Transform file: {0}" -f $transformFile)
	write-host ("  Destination file: {0}" -f $destinationFile)
	
	$document = new-object System.Xml.XmlDocument
	$document.Load($sourceFile);
	
	$transformation = new-object Microsoft.Web.Publishing.Tasks.XmlTransformation -argumentList $transformFile, $true, $null
	
	$result = $transformation.Apply($document);

	$document.Save($destinationFile);
}

function GetProjectPaths {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $path,
		[string[]] $include = @("*"),
		[switch] $recurse
	)
	
	$paths = @()
	
	if(!$recurse) {
		return @($path)
	}
	
	$includePath = $path.TrimEnd('\') + "*"
	
	get-childitem -path $includePath -include $include | where { $_.PsIsContainer }
}

Export-ModuleMember -Function "Transform-ConfigFileForProject", "Transform-ConfigFile", "Transform-ConfigFileForWebApplicationProject", "Transform-ConfigFileForXap", "Transform-ConfigFileForZip","Transform-ConfigFileForWebApplicationProject-BeforePackage","Transform-ConfigFileForXap-BeforePackage"