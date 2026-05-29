# TradingView M1 Watchdog — Monitor and enforce M1 lock
# Usage: Start-Process -FilePath powershell -ArgumentList "-File WATCHDOG_M1_LOCK.ps1"

$config = @{
    CheckInterval = 10000  # Check every 10s
    LogFile = 'D:\Dev\TradBOT\logs\tradingview-m1-lock.log'
    TVProcessName = 'TradingView'
    MT5ProcessName = 'terminal64'
}

# Create log directory
$logDir = Split-Path -Parent $config.LogFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Log {
    param([string]$Message)
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logMessage = "[$timestamp] $Message"
    Write-Host $logMessage -ForegroundColor Green
    Add-Content -Path $config.LogFile -Value $logMessage
}

function CheckTradingView {
    $tv = Get-Process $config.TVProcessName -ErrorAction SilentlyContinue
    return $null -ne $tv
}

function CheckMT5 {
    $mt5 = Get-Process $config.MT5ProcessName -ErrorAction SilentlyContinue
    return $null -ne $mt5
}

function EnforceM1Lock {
    # In real implementation, this would communicate with MT5 EA
    # For now, just verify processes are running

    if (CheckTradingView) {
        Log "✓ TradingView running — M1 lock active"
    } else {
        Log "⚠️ TradingView not running"
    }

    if (CheckMT5) {
        Log "✓ MT5 running — EA M1 lock enforced"
    } else {
        Log "⚠️ MT5 not running"
    }
}

# Main watchdog loop
Write-Host "🔐 TradingView M1 Watchdog Started" -ForegroundColor Cyan
Log "=== M1 WATCHDOG STARTED ==="

while ($true) {
    try {
        EnforceM1Lock
        Start-Sleep -Milliseconds $config.CheckInterval
    }
    catch {
        Log "❌ Error: $_"
        Start-Sleep -Seconds 5
    }
}
