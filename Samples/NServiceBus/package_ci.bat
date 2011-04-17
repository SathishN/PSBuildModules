@echo off
.\build\psake.cmd -task Package -framework '4.0' -parameters "@{ environment = 'ci' }"
PAUSE