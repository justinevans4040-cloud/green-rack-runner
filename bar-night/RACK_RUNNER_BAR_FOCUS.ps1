# Rack Runner BAR FOCUS — stop noisy apps; do not uninstall anything.
# Keep Green Rack Runner (and this PowerShell session) running.
$ErrorActionPreference = 'Continue'
$keepName = @(
  'Green Rack Runner',
  'powershell', 'pwsh', 'WindowsTerminal', 'cmd', 'conhost',
  'explorer', 'SearchHost', 'ShellExperienceHost', 'StartMenuExperienceHost',
  'TextInputHost', 'ApplicationFrameHost', 'SystemSettings', 'dwm', 'sihost', 'csrss'
)
$stopName = @(
  'Discord', 'DiscordPTB', 'DiscordCanary',
  'Spotify', 'Steam', 'steamwebhelper', 'EpicGamesLauncher', 'EpicWebHelper',
  'TikTok', 'Slack', 'Teams', 'ms-teams', 'OUTLOOK',
  'Voicemod', 'VoicemodV3',
  'chrome', 'msedge', 'firefox', 'Opera', 'brave',
  'Code', 'Cursor', 'GitHubDesktop',
  'Copilot', 'WhatsApp', 'Telegram', 'Signal',
  'iTunes', 'AppleMusic', 'Amazon Music', 'MusicBee',
  'OBS', 'obs64', 'Streamlabs OBS', 'TikTok LIVE Studio',
  'UserBenchmark', 'Everything', 'Notion', 'Figma'
)

Write-Host ''
Write-Host '=== RACK RUNNER BAR FOCUS ===' -ForegroundColor Green
Write-Host 'Stopping non-Rack-Runner background apps (process stop only).' -ForegroundColor Yellow
Write-Host ''

$stopped = @()
Get-Process -ErrorAction SilentlyContinue | ForEach-Object {
  $n = $_.ProcessName
  if ($keepName -contains $n) { return }
  if ($stopName -contains $n) {
    try {
      Stop-Process -Id $_.Id -Force -ErrorAction Stop
      $stopped += $n
      Write-Host ("  stopped: {0}" -f $n) -ForegroundColor Cyan
    } catch {
      Write-Host ("  skip: {0} ({1})" -f $n, $_.Exception.Message) -ForegroundColor DarkYellow
    }
  }
}

if (-not $stopped.Count) {
  Write-Host '  nothing from the bar denylist was running.' -ForegroundColor DarkGray
} else {
  Write-Host ''
  Write-Host ("Stopped {0} process name(s)." -f (($stopped | Sort-Object -Unique).Count)) -ForegroundColor Green
}

$exe = Join-Path $env:LOCALAPPDATA 'Programs\Green Rack Runner\Green Rack Runner.exe'
if (Test-Path -LiteralPath $exe) {
  $running = Get-Process -Name 'Green Rack Runner' -ErrorAction SilentlyContinue
  if (-not $running) {
    Write-Host 'Starting Green Rack Runner...' -ForegroundColor Green
    Start-Process -FilePath $exe
    Start-Sleep -Seconds 2
  }
  try {
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class RRFocus {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@ -ErrorAction SilentlyContinue
    $p = Get-Process -Name 'Green Rack Runner' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($p -and $p.MainWindowHandle -ne [IntPtr]::Zero) {
      [RRFocus]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
      [RRFocus]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
      Write-Host 'Green Rack Runner focused.' -ForegroundColor Green
    }
  } catch {}
} else {
  Write-Host "Green Rack Runner exe not found: $exe" -ForegroundColor Red
}

Write-Host ''
Write-Host 'Bar focus done. Close this window when ready.' -ForegroundColor Green
Start-Sleep -Seconds 4
