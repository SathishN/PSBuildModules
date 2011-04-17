@echo off
.\build\psake.cmd -task release -framework '4.0' -parameters "@{ environment = 'local' }"
PAUSE