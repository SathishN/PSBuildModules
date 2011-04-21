function Set-StartupProjects {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $solutionFile,
		[string[]] $includeRegex = "^.+((\.Handlers.csproj$)|(\.Saga.csproj$)|(\.TimeoutManager.csproj$))"
	)
	
	write-verbose "Finding startup projects"
	
	$dte = new-object -com VisualStudio.DTE.10.0 -strict
	
	#HACK: Com objects suck in PowerShell
	#$dte.SuppressUI = $true
	[System.__ComObject].InvokeMember("SuppressUI",[System.Reflection.BindingFlags]::SetProperty,$null,$dte,$true)
	
	#$dte.UserControl = $false
	[System.__ComObject].InvokeMember("UserControl",[System.Reflection.BindingFlags]::SetProperty,$null,$dte,$false)
	
	#$sln = $dte.Solution
	$sln = [System.__ComObject].InvokeMember("Solution",[System.Reflection.BindingFlags]::GetProperty,$null,$dte,$null)
	
	#$sln.Open($solutionFile)
	[System.__ComObject].InvokeMember("Open",[System.Reflection.BindingFlags]::InvokeMethod,$null,$sln,$solutionFile)
	
	#$projects = $sln.Projects | Where-Object { $_.Name -match $includeRegex }
	$projects = [System.__ComObject].InvokeMember("Projects",[System.Reflection.BindingFlags]::GetProperty,$null,$sln,$null)
	
	$projectNames = $projects | foreach { $_.UniqueName }
	
	[string[]] $startupProjects = $projectNames | Where-Object { $_ -match $includeRegex }
	
	write-host "Found the following startup projects:"
	$startupProjects | foreach { write-host $_ }
	
	#HACK:I don't know why InvokeMember craps out on collections
	SetStartupProjectsForSolution $sln $startupProjects
}

function SetStartupProjectsForSolution {
	param(
		$solution,
		[string[]] $startupProjects
	)
	
	$refs = @(
		"EnvDTE100, Version=10.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a",
		"EnvDTE80, Version=8.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a",
		"EnvDTE, Version=8.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a",
		"EnvDTE90, Version=9.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a"
	)
	
	Add-Type -ReferencedAssemblies $refs @"
public class SetStartupForSolution {
	public void Set(object solution, string[] items) {
		EnvDTE100.Solution4 sln4 = (EnvDTE100.Solution4)solution;
		
		object[] items2 = new object[items.Length];
		
		for(int i=0; i<items.Length; i++) {
			items2[i] = items[i];
		}
		
		sln4.SolutionBuild.StartupProjects = items2;
	}
}
"@
	
	$setter = new-object SetStartupForSolution
	
	$setter.Set($solution, $startupProjects) | out-null
}

Export-ModuleMember -Function "Set-StartupProjects"