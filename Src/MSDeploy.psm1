[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.Web.Deployment")  | out-null;

function Sync-Provider { 
	param(
		$sourceProvider,
		$sourcePath,
		$destinationProvider,
		$destinationPath,
		$setParamFile,
		$skip,
		$computer,
		[switch] $useTempAgent
	)

    $destBaseOptions   = new-object Microsoft.Web.Deployment.DeploymentBaseOptions
    $syncOptions       = new-object Microsoft.Web.Deployment.DeploymentSyncOptions
    $deploymentObject = [Microsoft.Web.Deployment.DeploymentManager]::CreateObject($sourceProvider, $sourcePath)
	
	if($setParamFile -ne $null) {
		$deploymentObject.SyncParameters.Load($setParamFile)
	}
	
	if($computer -ne $null) {
		$destBaseOptions.ComputerName = $computer
	}
	
	if($useTempAgent) {
		$destBaseOptions.TempAgent = $true
	}
	
	if($skip -ne $null) {
		$skip | foreach { 
			write-host "Skipping: $_"
			$directive = new-object Microsoft.Web.Deployment.DeploymentSkipDirective -argumentList $_, $_
			$destBaseOptions.SkipDirectives.Add($directive)
		}
	}
	
    $deploymentObject.SyncTo($destinationProvider,$destinationPath,$destBaseOptions,$syncOptions)
}

Export-ModuleMember -Function "Sync-Provider"