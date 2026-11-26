# Builds (or rebuilds) the Meshtastic Web image from the latest upstream source and starts it.
# Usage:  .\build.ps1                 # builds WEB_REF from .env (default: main)
#         .\build.ps1 -Ref v2.6.6     # build a specific tag/branch/commit
param([string]$Ref)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if ($Ref) { $env:WEB_REF = $Ref }

docker compose build --pull
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

docker compose up -d
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$port = if ($env:WEB_PORT) { $env:WEB_PORT } else {
    ((Get-Content .env | Where-Object { $_ -match '^WEB_PORT=' }) -replace 'WEB_PORT=', '')
}
if (-not $port) { $port = 8080 }
Write-Host "`nMeshtastic Web is running at http://localhost:$port"
