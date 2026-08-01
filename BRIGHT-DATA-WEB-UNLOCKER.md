# Green Rack Runner — Bright Data Web Unlocker

Green Rack Runner now includes a secure server-side Bright Data Web Unlocker endpoint in `green-rack-runner-sync-server.cjs`.

## Why it is server-side

The Bright Data API key must never be placed inside the phone HTML, browser JavaScript, screenshots, or the public GitHub repository. The Green Rack Runner server reads the secret from an environment variable and makes the Bright Data request on behalf of the app.

## Required environment variables

Open PowerShell on the Windows computer running Green Rack Runner and set:

```powershell
$env:BRIGHTDATA_API_KEY = "PASTE-YOUR-BRIGHT-DATA-API-KEY-HERE"
$env:BRIGHTDATA_ZONE = "rack_runner"
```

Optional protection for the local Rack Runner endpoint:

```powershell
$env:RACK_RUNNER_API_TOKEN = "CREATE-A-LONG-RANDOM-LOCAL-TOKEN"
```

Start the server in the same PowerShell window:

```powershell
node .\green-rack-runner-sync-server.cjs
```

## Local endpoint

```text
POST http://127.0.0.1:8765/api/brightdata/unlock
```

Example PowerShell request:

```powershell
$headers = @{ "Content-Type" = "application/json" }

if ($env:RACK_RUNNER_API_TOKEN) {
  $headers["x-rack-runner-token"] = $env:RACK_RUNNER_API_TOKEN
}

$body = @{
  url = "https://geo.brdtest.com/welcome.txt"
  country = "de"
  format = "raw"
} | ConvertTo-Json

Invoke-RestMethod `
  -Method Post `
  -Uri "http://127.0.0.1:8765/api/brightdata/unlock" `
  -Headers $headers `
  -Body $body
```

## Supported request fields

- `url` — required public HTTP or HTTPS target
- `country` — optional two-letter country code, such as `us` or `de`
- `format` — `raw` or `json`

## Response

The endpoint returns:

- request success status
- upstream HTTP status
- Bright Data `x-response-id`
- response content type
- returned page data

## Security rules

- Do not commit the API key.
- Do not paste the API key into the Green Rack Runner HTML.
- Rotate any key that appears in a screenshot, chat, log, or public repository.
- Keep CAPTCHA handling enabled only for lawful access to public web pages.
- Respect website terms, robots rules where applicable, privacy requirements, and rate limits.
