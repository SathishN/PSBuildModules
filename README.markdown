#Welcome to the PS Build Modules Project!

This project contians a set of PowerShell modules used to help with automated builds. 
It has recipes for: 
* Loading environment files for psake
* Deploying with MSDeploy
* Compiling with MSBuild
* Transforming configuration files
* Deploying NServiceBus
* Zipping files.

##What are PowerShell Modules?
For more information about PowerShell modules look here:
(http://msdn.microsoft.com/en-us/library/dd901839%28v=vs.85%29.aspx)

##PowerShell with .NET 4.0
Some of these modules require .NET 4.0 assemblies, which PowerShell does not support out of the box. Please do one of the following:
> Run the 'PsDotNet40\PowerShellDotNet4.reg' file to add support for .NET 4.0
or
> Copy 'PsDotNet40\powershell_ise.exe.config' to %Windir%\System32\WindowsPowerShell\v1.0 and %Windir%\SysWOW64\WindowsPowerShell

Solutions described here:
(http://stackoverflow.com/questions/2094694/launch-powershell-under-net-4)

##Using with PSake
These modules can be used without psake. If you do use psake, then simply copy the files from the 'Src' directory into a folder called 'modules' in the same folder as your psake files. They will automatically get imported for use.

##Samples
These samples use psake to build. The modules get imported from the 'Src' directory by overriding the default modules directory in 'Build\psake-config.ps'.

###NServiceBus Deployment Sample
This sample shows how to deploy using NServiceBus. It uses convention (*.Handlers) to find the NServiceBus projects to deploy. You can specify the deploy location, server, & credentials in the property files.

You can look at the ReleaseHandlers task in 'build\default.ps1' to see how to deploy NServiceBus. It calls Release-Handler function from the NServiceBus.psm1 module. It's a wrapper function that calls Deploy, Install, & Start functions. However, you could call these individually yourself.