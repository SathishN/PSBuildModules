properties {
    $base_directory = Resolve-Path .. 
	$release_directory = "$base_directory\Release"
	$build_directory = "$base_directory\build"
	$src_directory = "$base_directory\Src"
	
	$compile_config = "debug"
	$app_config = "local"
	
	$deploy_directory = "c:\deploy"

	$deploy_computer = $null
	$deploy_password = $null
	$deploy_username = $null
	
	if($deploy_username -ne $null) {
		$deploy_credential = New-PSCredential $deploy_username $deploy_password
	}
		
	$handlers_release_directory = "$release_directory\Handlers"
	$handlers_deploy_directory = "$deploy_directory\Handlers"
	$handler_admins = @("NT AUTHORITY\SYSTEM", "Network Service")
	$nservicebus_profile = "NServiceBus.Lite"
	
	$solutionFile = "$src_directory\PubSub.sln"
}

#Environment overrides
properties {
	write-host "Environment: $environment"

	if($environment -eq $null) {
		write-host "Environment was not specified. Please specify environment in the parameters for psake Ex: -parameters @{ environment='Development' }"
	}
	else {
		$environmentPropertiesFile = (".\properties.{0}.ps1" -f $environment)
    
		if(test-path $environmentPropertiesFile) {
			. $environmentPropertiesFile
		}
		else {
			write-host ("No Environment Property File Found at: {0}" -f $environmentPropertiesFile)
		}
	}
}

task default -depends Compile

task Release -depends ReleaseHandlers

task Package -depends PackageHandlers

task ReleaseHandlers -depends CreateManualQueues {
	Release-Handler -projectPath $handlers_release_directory `
		-destinationPath $handlers_deploy_directory `
		-profile $nservicebus_profile `
		-admins $handler_admins `
		-verbose `
		-computerName $deploy_computer `
		-credential $deploy_credential
}


task CreateManualQueues {
	$createQueue = {
		Param($name, $admins = $handler_admins, $computer = $deploy_computer, $credential = $deploy_credential)
		New-PrivateMSMQQueue -name $name -admins $admins -computerName $computer -credential $credential
	}
	
	&$createQueue "Sample.Errors"
}

task UninstallHandlers {
	Uninstall-Handler -path $handlers_deploy_directory -computerName $deploy_computer -credential $deploy_credential
}

task CreateReleaseDirectory {
	New-Directory $release_directory
}

task PackageHandlers -depends Clean, Compile, CreateReleaseDirectory {
	Package-Handler -projectPath $src_directory `
		-destination $handlers_release_directory `
		-configuration $compile_config `
		-recurse `
		-verbose
}

task Compile -Precondition { !($skipCompile -ne $null) } -Action {
	Compile-MSBuild -solutionfile $src_directory -configuration $compile_config -ea Stop
	Transform-ConfigFileForProject -projectPath $src_directory -configuration $compile_config -environment $app_config -recurse -ea Stop
}

task Clean {
	Clean-Item $release_directory
	get-Item -path "$base_directory\*" -include "_ReSharper.*" -force | Clean-Item -ea Continue
	get-Item -path "$base_directory\*" -include "*.suo", "*.user", "*.cache", "_ReSharper*" -force | Clean-Item -ea Continue
	Get-ChildItem $src_directory -include bin,obj -Recurse | foreach ($_) { remove-item $_.fullname -Force -Recurse }
	Get-ChildItem $test_directory -include bin,obj -Recurse | foreach ($_) { remove-item $_.fullname -Force -Recurse }
}

#Local development tasks
task CreateQueues -depends CreateManualQueues {
	Create-HandlerQueues -projectPath $src_directory `
		-admins $handler_admins `
		-verbose `
		-computerName $deploy_computer `
		-credential $deploy_credential
}

task SetStartupProjects -description "Development task to set the startup projects for a solution" {
	Set-StartupProjects -solutionFile $solutionFile
}