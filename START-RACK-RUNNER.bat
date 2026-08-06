@echo off
setlocal
set "APPFILE=%~dp0index.html"
if not exist "%APPFILE%" (
  echo Green Rack Runner index.html not found:
  echo %APPFILE%
  pause
  exit /b 1
)
start "" "%APPFILE%"
exit /b 0
