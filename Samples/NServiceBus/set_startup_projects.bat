@echo off
.\build\psake.cmd -task SetStartupProjects -framework '4.0' -parameters "@{ environment = 'local' }"
PAUSE