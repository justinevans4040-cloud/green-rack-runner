@echo off
setlocal
set "EXE=%LOCALAPPDATA%\Programs\Green Rack Runner\Green Rack Runner.exe"
set "TVHTML=%~dp0RACK-RUNNER-TV-MODE.html"
if exist "%TVHTML%" start "" "%TVHTML%"
if exist "%EXE%" (
  start "" "%EXE%"
  exit /b 0
)
echo Green Rack Runner Functional V2 not found:
echo %EXE%
pause
exit /b 1
