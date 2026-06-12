#!/usr/bin/env pwsh
<#
.SYNOPSIS
    GOM SYNC Loop - Every 10 Minutes (CONTINUOUS)

.DESCRIPTION
    Exécution continue: cd D:/Dev/TradBOT && python Python/gom_sync_with_report.py --report

    Actions:
    1. Charge les données GOM depuis gom_signal.json
    2. Envoie chaque verdict via POST /gom-verdict à ai_server:8000
    3. Construit un rapport formaté: 🟢 XAUUSD — BUY | Entry: 6031.70
    4. Envoie rapport via WhatsApp (PsychoBot ou fallback log)
    5. Logs stockés dans logs/ avec timestamps complets

    Logs inclus: timestamps, verdicts, entrées, erreurs

.EXAMPLE
    .\gom_sync_loop_10min_final.ps1
#>

$ErrorActionPreference = "Continue"

$TradbotDir = "D:\Dev\TradBOT"
$LogDir = Join-Path $TradbotDir "logs"

# Ensure logs directory exists
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force | Out-Null
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "GOM SYNC - 10 Minute Loop (CONTINUOUS)" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Command: python Python/gom_sync_with_report.py --report" -ForegroundColor Yellow
Write-Host "Interval: Every 10 minutes" -ForegroundColor Yellow
Write-Host "Logs: logs/gom_sync.log" -ForegroundColor Yellow
Write-Host ""
Write-Host "Starting continuous GOM sync..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

$iteration = 0

while ($true) {
    $iteration++
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Write-Host ""
    Write-Host "[$timestamp] ========================================" -ForegroundColor Cyan
    Write-Host "[$timestamp] Iteration #$iteration - Executing GOM Sync..." -ForegroundColor Yellow
    Write-Host "[$timestamp] Loading GOM verdicts from server..." -ForegroundColor Gray

    # Execute the command exactly as specified
    Push-Location $TradbotDir

    # Run with tee-like output (append to log)
    $logFile = Join-Path $LogDir "gom_sync.log"
    python Python/gom_sync_with_report.py --report 2>&1 | Tee-Object -FilePath $logFile -Append

    $exitCode = $LASTEXITCODE
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Pop-Location

    # Display result
    if ($exitCode -eq 0) {
        Write-Host "[$timestamp] Sync completed successfully ✓" -ForegroundColor Green
    } else {
        Write-Host "[$timestamp] Sync completed with code: $exitCode" -ForegroundColor Yellow
    }

    Write-Host "[$timestamp] Waiting 10 minutes until next execution..." -ForegroundColor Gray

    # Show countdown (every minute)
    for ($i = 600; $i -gt 0; $i -= 60) {
        $min = [math]::Floor($i / 60)
        $sec = $i % 60
        Write-Host "`r[$timestamp] Next execution in: $($min):$('{0:d2}' -f $sec) " -NoNewline -ForegroundColor Gray
        Start-Sleep -Seconds 60
    }

    Write-Host "`r" + (' ' * 80) + "`r" -NoNewline

}
