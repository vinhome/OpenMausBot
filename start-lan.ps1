param(
    [int]$Port = 8799,
    [string]$PublicUrl = "https://manus.4bytes.org"
)

$ErrorActionPreference = "Stop"
$env:PATH = "C:\Users\daica\bin;$env:APPDATA\npm;" + $env:PATH
$env:NODE_OPTIONS = "--max-old-space-size=4096"
Set-Location "C:\Users\daica\OpenMausBot"

Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "  Starting OpenMausBot Server in LAN / Domain Mode" -ForegroundColor Green
Write-Host "  IP:         192.168.91.1 (or local LAN IP)" -ForegroundColor Yellow
Write-Host "  Port:       $Port" -ForegroundColor Yellow
Write-Host "  Public URL: $PublicUrl" -ForegroundColor Yellow
Write-Host "=================================================" -ForegroundColor Cyan

node --experimental-strip-types server/openmausbot.ts serve --lan --port $Port --public-url $PublicUrl
