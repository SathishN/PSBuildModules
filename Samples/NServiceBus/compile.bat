@echo off
.\build\psake.cmd -task default -framework '4.0' -parameters "@{ environment = 'local' }"
PAUSE