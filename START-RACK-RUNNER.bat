@echo off
setlocal
set "APPFILE=%LOCALAPPDATA%\RackRunner\rack-runner-tournament-director.html"
if not exist "%APPFILE%" (
  echo Rack Runner app file not found:
  echo %APPFILE%
  pause
  exit /b 1
)
start "" "%APPFILE%"
exit /b 0
