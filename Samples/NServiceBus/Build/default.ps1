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
	
	$nservicebus_profile = "NServiceBus.Lite"
}

#Environment overrides
properties {
	write-host "Environment: $environment"

	if($environment -eq $null) {
		throw "Environment was not specified. Please specify environment in the parameters for psake Ex: -parameters @{ environment='Development' }"
	}
	
	$environmentPropertiesFile = (".\properties.{0}.ps1" -f $environment)
    
	if(test-path $environmentPropertiesFile) {
		. $environmentPropertiesFile
	}
	else {
		write-host ("No Environment Property File Found at: {0}" -f $environmentPropertiesFile)
	}
}

task default -depends Compile

task Release -depends ReleaseHandlers

task Package -depends PackageHandlers

task ReleaseHandlers -depends PackageHandlers {
	if($deploy_username -ne $null ) {
		$password = convertto-securestring -asPlainText -force -string $deploy_password
		$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $deploy_username,$password
	}
	
	Release-Handler -projectPath $release_directory -destinationPath $deploy_directory -profile $nservicebus_profile -Recurse -verbose -computerName $deploy_computer -credential $credential
}

task CreateQueues -description "Development task to create queues" -depends Package {
	if($deploy_username -ne $null ) {
		$password = convertto-securestring -asPlainText -force -string $deploy_password
		$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $deploy_username,$password
	}
	
	New-HandlerInputQueue -path $release_directory -Recurse -verbose -computerName $deploy_computer -credential $credential
}

task UninstallHandlers {
	if($deploy_username -ne $null ) {
		$password = convertto-securestring -asPlainText -force -string $deploy_password
		$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $deploy_username,$password
	}
	
	Uninstall-Handler -path $deploy_directory -Recurse -computerName $deploy_computer -credential $credential
}

task CreateReleaseDirectory {
	New-Directory $release_directory
}

task PackageHandlers -depends Clean, Compile, CreateReleaseDirectory {
	Package-Handler -projectPath $src_directory -destination $release_directory -configuration $compile_config -recurse
}

task Compile -Precondition { !($skipCompile -ne $null) } -Action {
	Compile-MSBuild -solutionfile $src_directory -configuration $compile_config -ea Stop
	Transform-ConfigFileForProject -projectPath $src_directory -configuration $compile_config -environment $app_config -recurse -ea Stop
}

task Clean {
	Clean-Item $release_directory
	get-Item -path "$base_directory\*" -include "_ReSharper.*" -force | Clean-Item -ea Continue
	get-Item -path "$base_directory\*" -include "*.suo", "*.user", "*.cache", "_ReSharper*" -force | Clean-Item -ea Continue
}