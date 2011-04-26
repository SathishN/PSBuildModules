function Set-StartupProjects {
	param(
		[parameter(Mandatory=$true, ValueFromPipeline = $true)]
		[ValidateNotNullOrEmpty()]
		[string] $solutionFile,
		[string[]] $includeRegex = "^.+((\.Handlers.csproj$)|(\.Saga.csproj$)|(\.TimeoutManager.csproj$))"
	)
	
	write-verbose "Finding startup projects"
	
	[System.Reflection.Assembly]::Load("EnvDTE100, Version=10.0.0.0, Culture=neutral, PublicKeyToken=b03f5f7f11d50a3a") | out-null
	
	$dte = new-object -com VisualStudio.DTE.10.0 -strict
	
	#HACK: Com objects suck in PowerShell
	#$dte.SuppressUI = $true
	[System.__ComObject].InvokeMember("SuppressUI",[System.Reflection.BindingFlags]::SetProperty,$null,$dte,$true)
	
	#$dte.UserControl = $false
	[System.__ComObject].InvokeMember("UserControl",[System.Reflection.BindingFlags]::SetProperty,$null,$dte,$false)
	
	#$sln = $dte.Solution
	$sln = [System.__ComObject].InvokeMember("Solution",[System.Reflection.BindingFlags]::GetProperty,$null,$dte,$null)
	
	write-verbose ("Solution: " + $solutionFile)
	
	#$sln.Open($solutionFile)
	[System.__ComObject].InvokeMember("Open",[System.Reflection.BindingFlags]::InvokeMethod,$null,$sln,$solutionFile)

	#HACK:I don't know why InvokeMember craps out on collections, so I made a dynamic c# class that does the casting
	$helper = GetHelper
	
	$projects = $helper.GetProjectsForSolution($sln)
		
	write-verbose "Available projects:"
	$projects | foreach { write-verbose $_ }
	
	[string[]] $startupProjects = $projects | Where-Object { $_ -match $includeRegex }
	
	if($startupProjects -ne $null) {
		write-host "Found the following startup projects:"
		$startupProjects | foreach { write-host $_ }
	}
	else {
		write-host "No startup projects were found"
	}
	
	$helper.SetStartupProjects($sln, $startupProjects) | out-null
}

function GetHelper {
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
public class SolutionHelper {
	public void SetStartupProjects(object solution, string[] items) {
		EnvDTE100.Solution4 sln4 = (EnvDTE100.Solution4)solution;
		
		var length = items != null ? items.Length : 0;
		
		object[] items2 = new object[length];
		
		for(int i=0; i < length; i++) {
			items2[i] = items[i];
		}
		
		sln4.SolutionBuild.StartupProjects = items2;
	}
	
	public System.Collections.Generic.IEnumerable<string> GetProjectsForSolution(object solution) 
	{
		var sln4 = (EnvDTE100.Solution4)solution;
		
		var projects = new System.Collections.Generic.List<string>();
		
		foreach(EnvDTE.Project project in sln4.Projects) {
			projects.AddRange(GetProjects(project));
		}
		
		return projects;
	}

	public System.Collections.Generic.IEnumerable<string> GetProjects(EnvDTE.Project project) 
	{
		var isAProject = project.ConfigurationManager != null;
		
		if(isAProject)
		{
			yield return project.UniqueName;
		}
		else 
		{
			foreach(EnvDTE.ProjectItem item in project.ProjectItems) {
				if(item.SubProject != null) {
					var subProjects = GetProjects(item.SubProject);
					
					foreach(var subProject in subProjects) {
						yield return subProject;
					}
				}
			}
		}
	}
}
"@
	
	$helper = new-object SolutionHelper
	
	return $helper
}

Export-ModuleMember -Function "Set-StartupProjects"