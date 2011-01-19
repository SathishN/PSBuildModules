$script:zipConfig = @{}
$script:zipConfig.zipLibPath = join-path ($MyInvocation.MyCommand.Path | Split-Path) "Ionic.Zip.dll"

Export-ModuleMember -Variable "zipConfig"

function New-ZipFile {
	param(
		[parameter(Mandatory=$true, Position=0)]
		[string]$zipFileName,
		[parameter(Mandatory=$true, Position=1)]
		[string]$directory
	)

	[System.Reflection.Assembly]::LoadFrom($script:zipConfig.zipLibPath) | out-null;

	$files = get-childItem $directory
	
	$zipfile =  new-object Ionic.Zip.ZipFile

	try {
		$zipfile.AddDirectory($directory) | out-null

		write-verbose ("Saving zip file to {0}" -f $zipFileName)
		$zipfile.Save($zipFileName)
	} 
	catch [Exception]
	{
		write-error $_.Exception
	}
}

Export-ModuleMember -Function "New-ZipFile"