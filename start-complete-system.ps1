#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Complete TradBOT System Startup
    Launches: PsychoBot (WhatsApp) + AI Server + Pipeline

.DESCRIPTION
    Starts all necessary services for autonomous trading
    - PsychoBot on port 8888 (WhatsApp messaging)
    - AI Server on port 8000 (Trading logic)
    - Configures automatic GOM sync and pipeline execution

.EXAMPLE
    .\start-complete-system.ps1
#>

$ErrorActionPreference = "SilentlyContinue"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "🚀 TradBOT Complete System Startup" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# Get paths
$TradbotDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PsychobotDir = Join-Path (Split-Path -Parent $TradbotDir) "Psychobot"
$LogsDir = Join-Path $TradbotDir "logs"

# Step 1: Create logs directory
Write-Host "[1/4] Creating logs directory..." -ForegroundColor Yellow
if (!(Test-Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir | Out-Null
}
Write-Host "✅ Logs directory ready" -ForegroundColor Green

# Step 2: Verify Node.js
Write-Host ""
Write-Host "[2/4] Checking Node.js..." -ForegroundColor Yellow
$nodeVersion = node --version
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Node.js found: $nodeVersion" -ForegroundColor Green
} else {
    Write-Host "❌ Node.js not found! Please install Node.js >=20.0.0" -ForegroundColor Red
    Write-Host "   Download from: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

# Step 3: Start PsychoBot
Write-Host ""
Write-Host "[3/4] Starting PsychoBot (WhatsApp Bot)..." -ForegroundColor Yellow
Write-Host "   Port: 8888" -ForegroundColor Gray
Write-Host "   Directory: $PsychobotDir" -ForegroundColor Gray

Push-Location $PsychobotDir

# Check if node_modules exists
if (!(Test-Path "node_modules")) {
    Write-Host "   Installing dependencies..." -ForegroundColor Gray
    npm install | Out-Null
}

# Start PsychoBot in background
$psychobotProcess = Start-Process -NoNewWindow -PassThru -FilePath "npm" -ArgumentList "start"
Write-Host "✅ PsychoBot started (PID: $($psychobotProcess.Id))" -ForegroundColor Green

# Wait for startup
Start-Sleep -Seconds 5

Pop-Location

# Step 4: Start AI Server
Write-Host ""
Write-Host "[4/4] Starting TradBOT AI Server..." -ForegroundColor Yellow
Write-Host "   Port: 8000" -ForegroundColor Gray
Write-Host "   Directory: $TradbotDir" -ForegroundColor Gray

Push-Location $TradbotDir

# Start AI Server in background
$aiProcess = Start-Process -NoNewWindow -PassThru -FilePath "python" -ArgumentList "ai_server.py"
Write-Host "✅ AI Server started (PID: $($aiProcess.Id))" -ForegroundColor Green

Start-Sleep -Seconds 3

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "✅ SYSTEM STARTUP COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Services Running:" -ForegroundColor Yellow
Write-Host "   • PsychoBot WhatsApp Bot ........ http://localhost:8888" -ForegroundColor Green
Write-Host "   • TradBOT AI Server ............ http://localhost:8000" -ForegroundColor Green
Write-Host "   • Pipeline Logs ............... $LogsDir\" -ForegroundColor Green
Write-Host ""

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "   1. Wait 30s for both services to fully initialize" -ForegroundColor Gray
Write-Host "   2. Execute: python Python\gom_sync_with_report.py --report" -ForegroundColor Gray
Write-Host "   3. Execute: python Python\pipeline_hourly_autonomous.py --once" -ForegroundColor Gray
Write-Host ""

Write-Host "Reports will be sent to WhatsApp automatically!" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Pop-Location

# Keep running
Write-Host "Press Ctrl+C to stop all services..." -ForegroundColor Gray
Write-Host ""

# Wait for processes
try {
    Wait-Process -Id $psychobotProcess.Id
    Wait-Process -Id $aiProcess.Id
} catch {
    # Cleanup on interrupt
    Stop-Process -Id $psychobotProcess.Id -ErrorAction SilentlyContinue
    Stop-Process -Id $aiProcess.Id -ErrorAction SilentlyContinue
}
