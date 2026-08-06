# Rack Runner Player Alerts — leave open on bar night.
# Polls Functional V2 sync at http://127.0.0.1:8765/api/sync
# Pops when tables are Called, disputed, or unpaid check-ins appear.
$ErrorActionPreference = 'Continue'
Add-Type -AssemblyName System.Windows.Forms | Out-Null
Add-Type -AssemblyName System.Drawing | Out-Null

$syncUrl = 'http://127.0.0.1:8765/api/sync'
$pollSeconds = 1.5
$seen = @{}
$lastUpdated = 0
$offlineWarned = $false

function Get-PlayerName($state, $id) {
  if ($null -eq $id) { return '?' }
  $p = @($state.players) | Where-Object { [string]$_.id -eq [string]$id } | Select-Object -First 1
  if ($p -and $p.name) { return [string]$p.name }
  return ("P{0}" -f $id)
}

function Show-Alert([string]$title, [string]$body) {
  [Console]::Beep(880, 180)
  Start-Sleep -Milliseconds 80
  [Console]::Beep(1175, 220)
  Write-Host ''
  Write-Host ("[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $title) -ForegroundColor Yellow
  Write-Host $body -ForegroundColor White
  try {
    $null = [System.Windows.Forms.MessageBox]::Show(
      $body,
      $title,
      [System.Windows.Forms.MessageBoxButtons]::OK,
      [System.Windows.Forms.MessageBoxIcon]::Exclamation
    )
  } catch {
    # console fallback already printed
  }
}

function Get-AlertKeys($data) {
  $keys = @()
  if (-not $data -or -not $data.state) { return $keys }
  $S = $data.state
  $matches = @($S.matches)
  foreach ($m in $matches) {
    $status = [string]$m.status
    if ($status -eq 'called' -or $status -eq 'disputed') {
      $a = Get-PlayerName $S $m.playerA
      $b = Get-PlayerName $S $m.playerB
      $table = if ($m.table) { "T$($m.table)" } else { 'T?' }
      $label = if ($m.label) { [string]$m.label } else { 'Match' }
      $keys += [pscustomobject]@{
        Id = "match:$($m.id):$status"
        Title = if ($status -eq 'called') { "TABLE CALL — $table" } else { "DISPUTE — $table" }
        Body = "$label`n$a vs $b`nStatus: $status"
      }
    }
  }
  $players = @($S.players)
  foreach ($p in $players) {
    if ($p.active -eq $false) { continue }
    if ($p.eliminated) { continue }
    if ($p.paid) { continue }
    if ($S.phase -ne 'active' -and $S.phase -ne 'setup') { continue }
    $keys += [pscustomobject]@{
      Id = "unpaid:$($p.id)"
      Title = 'UNPAID PLAYER'
      Body = ("{0} is checked in but not marked paid." -f $p.name)
    }
  }
  return $keys
}

Clear-Host
Write-Host '=== RACK RUNNER PLAYER ALERTS ===' -ForegroundColor Green
Write-Host 'Leave this window open. Watching sync for calls / disputes / unpaid.' -ForegroundColor Cyan
Write-Host ("Sync: {0}" -f $syncUrl) -ForegroundColor DarkGray
Write-Host 'Start Green Rack Runner first so port 8765 is live.' -ForegroundColor DarkGray
Write-Host ''

while ($true) {
  try {
    $resp = Invoke-RestMethod -Uri ($syncUrl + '?ts=' + [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()) -TimeoutSec 3
    $offlineWarned = $false
    if ($resp.hasState) {
      $updated = [int64]($resp.updatedAt)
      if ($updated -ne $lastUpdated) {
        $lastUpdated = $updated
        $alerts = Get-AlertKeys $resp
        foreach ($a in $alerts) {
          if (-not $seen.ContainsKey($a.Id)) {
            $seen[$a.Id] = $true
            Show-Alert $a.Title $a.Body
          }
        }
        # drop stale ids so a re-call can fire again after status leaves and returns
        $live = @{}
        foreach ($a in $alerts) { $live[$a.Id] = $true }
        foreach ($k in @($seen.Keys)) {
          if (-not $live.ContainsKey($k)) { $seen.Remove($k) }
        }
      }
      Write-Host ("`r watching... updatedAt={0}  alertsTracked={1}   " -f $lastUpdated, $seen.Count) -NoNewline
    } else {
      Write-Host ("`r sync online, no tournament state yet...   ") -NoNewline
    }
  } catch {
    if (-not $offlineWarned) {
      Write-Host ''
      Write-Host 'Sync offline — open Green Rack Runner (Functional V2).' -ForegroundColor Red
      $offlineWarned = $true
    }
  }
  Start-Sleep -Seconds $pollSeconds
}
