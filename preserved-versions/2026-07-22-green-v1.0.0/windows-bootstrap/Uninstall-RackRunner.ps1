$ErrorActionPreference = 'Stop'
$InstallRoot = Join-Path $env:LOCALAPPDATA 'Programs\Green Rack Runner'
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Green Rack Runner.lnk'
$StartShortcut = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Green Rack Runner.lnk'

Get-Process -Name 'Green Rack Runner' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-Item $DesktopShortcut -Force -ErrorAction SilentlyContinue
Remove-Item $StartShortcut -Force -ErrorAction SilentlyContinue
Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GreenRackRunner' -Recurse -Force -ErrorAction SilentlyContinue

$Cleanup = Join-Path $env:TEMP 'green-rack-runner-uninstall-cleanup.ps1'
@"
Start-Sleep -Seconds 2
Remove-Item -LiteralPath '$InstallRoot' -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath `$MyInvocation.MyCommand.Path -Force -ErrorAction SilentlyContinue
"@ | Set-Content -LiteralPath $Cleanup -Encoding UTF8
Start-Process powershell.exe -WindowStyle Hidden -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$Cleanup`""
