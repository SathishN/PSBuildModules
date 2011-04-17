@echo off
cd .\build\
psake.cmd -task default -framework '4.0' -parameters "@{ environment = 'local' }"
cd ..
PAUSE