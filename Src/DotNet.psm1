function Get-TypesFromAssembly
{ 
	Param 
	( 
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[System.IO.FileInfo] $assemblyPath, 
		
		[ValidateNotNullOrEmpty()]
		[string] $namespace,
		
		[ValidateNotNull()]
		[Type] $implementationType
	) 
	Begin 
	{
		Write-Verbose  "Namespace: $namespace"
		Write-Verbose  "Imlementation Type: $implementationType"
	} 
	Process 
	{ 
		$assembly = [System.Reflection.Assembly]::LoadFrom($assemblyPath.FullName)
		$types = $assembly.GetTypes() | Where-Object {$_.IsClass -and ($namespace -eq $null -or ($_.Namespace -ne $null -and $_.Namespace.StartsWith($namespace))) -and ($implementationType -eq $null -or $implementationType.IsAssignableFrom($_)) }
		
		if($types -ne $null)
		{
			$types | ForEach-Object { Write-Verbose $_.FullName }
		}
		
		return $types
	}
}

Export-ModuleMember -function "Get-TypesFromAssembly"