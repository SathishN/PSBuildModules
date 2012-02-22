function New-PSCredential {
	Param(
		[parameter(Mandatory=$true, Position=0)]
		[string] $username,
		[parameter(Mandatory=$false, Position=1)]
		[string] $password
	)

    $secure_pwd = convertto-securestring -asPlainText -force -string $password
	$credential = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secure_pwd
	
	return $credential
}