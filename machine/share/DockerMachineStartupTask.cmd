@echo off
cd %USERPROFILE%\.docker\machine
"C:\ProgramData\chocolatey\bin\docker-machine.exe" start dokarr >NUL 2>&1
