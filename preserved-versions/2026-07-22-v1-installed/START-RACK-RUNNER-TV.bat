@echo off
setlocal
set "APPFILE=%LOCALAPPDATA%\RackRunner\RACK-RUNNER-TV-MODE.html"
if not exist "%APPFILE%" (
  echo Rack Runner TV file not found:
  echo %APPFILE%
  pause
  exit /b 1
)
start "" "%APPFILE%"
exit /b 0
