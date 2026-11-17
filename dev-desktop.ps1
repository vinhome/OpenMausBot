param(
    [int]$Port = 8799,
    [int]$UiPort = 5199,
    [string]$PublicUrl = "https://manus.4bytes.org"
)

$ErrorActionPreference = "Continue"
$OpenMausDir = "C:\Users\daica\OpenMausBot"
Set-Location $OpenMausDir

$env:PATH = "C:\Users\daica\bin;$env:APPDATA\npm;" + $env:PATH
$env:NODE_OPTIONS = "--max-old-space-size=4096"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  Starting OpenMausBot in FULL DEV DESKTOP MODE           " -ForegroundColor Green
Write-Host "  Backend Server:  http://127.0.0.1:$Port ($PublicUrl)" -ForegroundColor Yellow
Write-Host "  Frontend (Vite): http://127.0.0.1:$UiPort (Hot Reload)  " -ForegroundColor Yellow
Write-Host "  Electron App:    Native CUA / Computer Use / Terminal   " -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Check if backend server is already running on port 8799
$serverLive = Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet
if (-not $serverLive) {
    Write-Host "`n[1/3] Starting OpenMausBot backend server on port $Port..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "$OpenMausDir\start-lan.ps1", "-Port", "$Port", "-PublicUrl", "$PublicUrl"
    
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-NetConnection -ComputerName 127.0.0.1 -Port $Port -InformationLevel Quiet) {
            Write-Host "      Backend server is ready!" -ForegroundColor Green
            break
        }
    }
} else {
    Write-Host "`n[1/3] Backend server is already running on port $Port." -ForegroundColor Green
}

# 2. Check if Vite is running on port 5199
$viteLive = Test-NetConnection -ComputerName 127.0.0.1 -Port $UiPort -InformationLevel Quiet
if (-not $viteLive) {
    Write-Host "`n[2/3] Starting Vite dev server on port $UiPort..." -ForegroundColor Cyan
    $viteCmd = "Set-Location '$OpenMausDir'; `$env:PATH = 'C:\Users\daica\bin;`$env:APPDATA\npm;' + `$env:PATH; node node_modules\vite\bin\vite.js --port $UiPort"
    Start-Process powershell -ArgumentList "-NoExit", "-Command", $viteCmd
    
    for ($i = 0; $i -lt 30; $i++) {
        Start-Sleep -Seconds 1
        if (Test-NetConnection -ComputerName 127.0.0.1 -Port $UiPort -InformationLevel Quiet) {
            Write-Host "      Vite dev server is ready!" -ForegroundColor Green
            break
        }
    }
} else {
    Write-Host "`n[2/3] Vite dev server is already running on port $UiPort." -ForegroundColor Green
}

# 3. Check cloudflared connector
Write-Host "`n[3/3] Checking Cloudflared connector..." -ForegroundColor Cyan
node scripts/prepare-cloudflared.mjs --current

# 4. Generate 24h pairing link
Write-Host "`n==========================================================" -ForegroundColor Magenta
Write-Host "  PAIRING LINK CHO ĐIỆN THOẠI / TRÌNH DUYỆT NGOÀI (24h)   " -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Magenta
try {
    $pairOutput = node --experimental-strip-types server/openmausbot.ts pair --ttl 24h --public-url $PublicUrl
    Write-Host $pairOutput -ForegroundColor White
} catch {
    Write-Host "Could not auto-generate pair link. Use get-pair-code.bat on Desktop." -ForegroundColor Gray
}
Write-Host "==========================================================`n" -ForegroundColor Magenta

# 5. Launch Electron Desktop App
Write-Host "Launching Electron Desktop Window in Dev Mode..." -ForegroundColor Green
$electronCmd = "$OpenMausDir\node_modules\.bin\electron.cmd"
Start-Process $electronCmd -ArgumentList "." -WorkingDirectory $OpenMausDir
