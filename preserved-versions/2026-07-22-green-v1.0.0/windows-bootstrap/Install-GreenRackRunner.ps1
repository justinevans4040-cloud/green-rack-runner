$ErrorActionPreference = 'Stop'

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$BundledApp = Join-Path $PackageRoot 'app'
$InstallRoot = Join-Path $env:LOCALAPPDATA 'Programs\Green Rack Runner'
$Executable = Join-Path $InstallRoot 'Green Rack Runner.exe'
$StartMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$DesktopShortcut = Join-Path ([Environment]::GetFolderPath('Desktop')) 'Green Rack Runner.lnk'
$StartShortcut = Join-Path $StartMenu 'Green Rack Runner.lnk'
$RuntimeUrl = 'https://github.com/electron/electron/releases/download/v39.2.7/electron-v39.2.7-win32-x64.zip'
$RuntimeSha256 = '3464537fa4be6b7b073f1c9b694ac2eb1f632d6ec36f6eeac9e00d8a279f188c'
$WorkRoot = Join-Path $env:TEMP ('GreenRackRunner-' + [Guid]::NewGuid().ToString('N'))
$RuntimeZip = Join-Path $WorkRoot 'electron-runtime.zip'
$RuntimeRoot = Join-Path $WorkRoot 'runtime'

if (-not (Test-Path (Join-Path $BundledApp 'dist\index.html'))) {
  throw 'The Green Rack Runner application files are missing from this package.'
}

try {
  New-Item -ItemType Directory -Force -Path $WorkRoot, $RuntimeRoot | Out-Null
  Write-Host 'Downloading the verified Windows desktop runtime...'
  Invoke-WebRequest -Uri $RuntimeUrl -OutFile $RuntimeZip -UseBasicParsing
  $ActualSha256 = (Get-FileHash -Path $RuntimeZip -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($ActualSha256 -ne $RuntimeSha256) {
    throw 'The downloaded desktop runtime failed its security verification.'
  }

  Expand-Archive -Path $RuntimeZip -DestinationPath $RuntimeRoot -Force
  Get-Process -Name 'Green Rack Runner' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
  Copy-Item -Path (Join-Path $RuntimeRoot '*') -Destination $InstallRoot -Recurse -Force
  Rename-Item -Path (Join-Path $InstallRoot 'electron.exe') -NewName 'Green Rack Runner.exe' -Force

  $ResourcesApp = Join-Path $InstallRoot 'resources\app'
  New-Item -ItemType Directory -Force -Path $ResourcesApp | Out-Null
  Copy-Item -Path (Join-Path $BundledApp '*') -Destination $ResourcesApp -Recurse -Force
  Copy-Item -Path (Join-Path $PackageRoot 'Uninstall-RackRunner.ps1') -Destination $InstallRoot -Force

  $Shell = New-Object -ComObject WScript.Shell
  foreach ($ShortcutPath in @($DesktopShortcut, $StartShortcut)) {
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = $Executable
    $Shortcut.WorkingDirectory = $InstallRoot
    $Shortcut.Description = 'Green Rack Runner'
    $Shortcut.Save()
  }

  $UninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GreenRackRunner'
  New-Item -Path $UninstallKey -Force | Out-Null
  New-ItemProperty -Path $UninstallKey -Name DisplayName -Value 'Green Rack Runner' -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $UninstallKey -Name DisplayVersion -Value '1.0.0' -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $UninstallKey -Name Publisher -Value 'Justin Evans' -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $UninstallKey -Name InstallLocation -Value $InstallRoot -PropertyType String -Force | Out-Null
  New-ItemProperty -Path $UninstallKey -Name UninstallString -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstallRoot\Uninstall-RackRunner.ps1`"" -PropertyType String -Force | Out-Null

  Start-Process $Executable
  Write-Host 'Green Rack Runner installed successfully.' -ForegroundColor Green
}
finally {
  if (Test-Path $WorkRoot) {
    Remove-Item -Path $WorkRoot -Recurse -Force -ErrorAction SilentlyContinue
  }
}
