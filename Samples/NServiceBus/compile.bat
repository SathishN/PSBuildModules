@echo off
cd .\build\
psake.cmd -task default -parameters "@{ environment = 'local' }"
cd ..
PAUSE