#!/usr/bin/env pwsh
<#
.SYNOPSIS
    GOM Sync Continuous Loop (Every 10 Minutes)

.DESCRIPTION
    Runs GOM Sync indefinitely, executing every 10 minutes.
    - Loads GOM verdicts
    - Sends each verdict via POST /gom-verdict
    - Generates WhatsApp report
    - Saves logs with timestamps

.EXAMPLE
    .\gom_sync_loop_10min.ps1

.NOTES
    Runs until Ctrl+C is pressed
    Logs saved to: logs\gom_sync.log
#>

$ErrorActionPreference = "SilentlyContinue"

# Get TradBOT directory
$TradbotDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogsDir = Join-Path $TradbotDir "logs"

# Ensure logs directory exists
if (!(Test-Path $LogsDir)) {
    New-Item -ItemType Directory -Path $LogsDir | Out-Null
}

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "🔄 GOM SYNC - 10 Minute Continuous Loop" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Starting GOM Sync execution every 10 minutes" -ForegroundColor Yellow
Write-Host "Reports generated every 10 minutes" -ForegroundColor Yellow
Write-Host "Logs saved to: $LogsDir\gom_sync.log" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press Ctrl+C to stop" -ForegroundColor Gray
Write-Host ""

$iteration = 0

while ($true) {
    $iteration++
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Write-Host ""
    Write-Host "[$timestamp] ========================================" -ForegroundColor Cyan
    Write-Host "[$timestamp] Iteration #$iteration - Executing GOM Sync..." -ForegroundColor Yellow
    Write-Host ""

    # Execute GOM sync with report
    Push-Location $TradbotDir

    # Run with logging
    python Python/gom_sync_with_report.py --report 2>&1 | Tee-Object -FilePath (Join-Path $LogsDir "gom_sync.log") -Append

    $lastExit = $LASTEXITCODE

    Pop-Location

    # Display next run time
    $nextRun = (Get-Date).AddSeconds(600)
    $nextFormatted = $nextRun.ToString("HH:mm:ss")

    Write-Host ""
    if ($lastExit -eq 0) {
        Write-Host "[$timestamp] ✅ GOM Sync completed successfully" -ForegroundColor Green
    } else {
        Write-Host "[$timestamp] ❌ GOM Sync exited with code: $lastExit" -ForegroundColor Red
    }

    Write-Host "[$timestamp] Waiting 10 minutes..." -ForegroundColor Gray
    Write-Host "[$timestamp] Next execution will run at approximately: $nextFormatted" -ForegroundColor Gray
    Write-Host ""

    # Wait 10 minutes (600 seconds)
    for ($i = 600; $i -gt 0; $i--) {
        $remaining = [timespan]::FromSeconds($i)
        Write-Host "`r[$timestamp] ⏳ Next sync in: $($remaining.ToString('mm\:ss'))" -NoNewline -ForegroundColor Gray
        Start-Sleep -Seconds 1
    }

    Write-Host "`r" + (' ' * 80) + "`r" -NoNewline
}
