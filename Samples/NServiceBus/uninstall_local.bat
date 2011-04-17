@echo off
.\build\psake.cmd -task UninstallHandlers -framework '4.0' -parameters "@{ environment = 'local' }"
PAUSE