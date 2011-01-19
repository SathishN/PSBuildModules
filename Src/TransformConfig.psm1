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
		[switch] $recurse
	)

	write-host ("Transforming config for projects in: {0}" -f $projectPath)
		
	GetProjectPaths -path $projectPath -recurse:$recurse | foreach {
		$path = $_

		$sourceFile = join-path $path ("bin\{0}\{1}.dll.config" -f $configuration, $path.Name)
		
		$continue = $false
		
		if(!(test-path $sourceFile -pathType Leaf)) {
			write-host ("Skipping transform. Source file not found at: {0}" -f $sourceFile)
			$continue = $true
		}

		$transformFile = join-path $path ("App.{0}.config" -f $configuration)
		
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

Export-ModuleMember -Function "Transform-ConfigFileForProject", "Transform-ConfigFile"