@echo off
cd .\build\
psake.cmd -task Package -framework '4.0' -parameters "@{ environment = 'ci' }"
cd ..
PAUSE