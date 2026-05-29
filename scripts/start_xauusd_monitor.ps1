# XAUUSD Real-Time Monitoring System
# Launches continuous 20-min monitoring loop with WhatsApp alerts via PsychoBot
#
# Usage:
#   .\start_xauusd_monitor.ps1 -Phone "+2290196911346" -Interval 1200
#
# Features:
#   - Collects TradingView data in parallel
#   - Collects AI server data in parallel
#   - Sends unified WhatsApp message every 20 minutes
#   - Auto-fallback to log file if PsychoBot is unreachable
#   - Graceful SSL handling for Render-deployed services

param(
    [string]$Phone = "+2290196911346",
    [int]$Interval = 1200,  # 20 minutes in seconds
    [string]$PythonPath = "python",
    [string]$LogDir = "logs"
)

# Ensure log directory exists
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
    Write-Host "📁 Created logs directory: $LogDir" -ForegroundColor Green
}

# Start the monitor
$monitorScript = "python/unified_xauusd_monitor.py"
$logFile = "$LogDir/xauusd_monitor_ps.log"

Write-Host "🚀 Starting XAUUSD Real-Time Monitor" -ForegroundColor Cyan
Write-Host "   Phone: $Phone" -ForegroundColor Gray
Write-Host "   Interval: $Interval seconds ($(($Interval / 60)) minutes)" -ForegroundColor Gray
Write-Host "   Log file: $logFile" -ForegroundColor Gray
Write-Host ""

# Launch Python process
$process = Start-Process `
    -FilePath $PythonPath `
    -ArgumentList $monitorScript, "--phone", $Phone, "--interval", $Interval `
    -RedirectStandardOutput $logFile `
    -RedirectStandardError "$LogDir/xauusd_monitor_err.log" `
    -NoNewWindow `
    -PassThru

Write-Host "✅ Monitor started (PID: $($process.Id))" -ForegroundColor Green
Write-Host "📊 Monitoring XAUUSD every $($Interval / 60) minutes..." -ForegroundColor Yellow
Write-Host ""
Write-Host "📋 Monitor output:" -ForegroundColor Cyan
Write-Host "   View live: Get-Content -Path '$logFile' -Wait" -ForegroundColor Gray
Write-Host ""
Write-Host "⏹️  To stop monitoring, run:" -ForegroundColor Yellow
Write-Host "   Stop-Process -Id $($process.Id)" -ForegroundColor Gray
Write-Host ""
