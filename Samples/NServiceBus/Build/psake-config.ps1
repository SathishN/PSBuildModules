$psake.config = new-object psobject -property @{
  defaultbuildfilename="default.ps1";
  tasknameformat="Executing {0}";
  exitcode="1";
  modules=(new-object psobject -property @{ autoload=$true; directory="..\..\src" })
}