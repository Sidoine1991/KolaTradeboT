# ============================================================================
# XAUUSD Signal Monitor — Attendre 07:00 UTC et valider gates
# ============================================================================
# Workflow:
# 1. Attend 07:00 UTC
# 2. Valide tous les gates (Session, IA, RSI, M15, MTF)
# 3. Envoie notification WhatsApp avec décision PLACER / REJETER
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File monitor_xauusd_7am.ps1
#   powershell -ExecutionPolicy Bypass -File monitor_xauusd_7am.ps1 -TestNow
# ============================================================================

param(
    [switch]$TestNow = $false
)

$ErrorActionPreference = "Continue"
$workDir = "D:\Dev\TradBOT"
$pythonCmd = "python"
$scriptPath = "$workDir\python\monitor_xauusd_signal.py"
$logDir = "$workDir\logs"
$logFile = "$logDir\monitor_xauusd_7am.log"

# Create logs dir
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

function Log-Message {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMsg = "[$timestamp] $Message"
    Write-Host $logMsg
    Add-Content -Path $logFile -Value $logMsg -Encoding UTF8
}

Log-Message "=========================================="
Log-Message "XAUUSD SELL SIGNAL MONITOR — START"
Log-Message "=========================================="
Log-Message "Target: XAUUSD SELL @ 4241 (SL: 4253, TP: 4210)"
Log-Message "Gates validation at 07:00 UTC"
Log-Message "=========================================="

if ($TestNow) {
    Log-Message "[TEST] Running immediate validation..."
    Push-Location $workDir
    & $pythonCmd $scriptPath --test-now 2>&1 | ForEach-Object {
        Add-Content -Path $logFile -Value $_ -Encoding UTF8
        Write-Host $_
    }
    Pop-Location
    Log-Message "Test complete."
    exit 0
}

# Normal mode: wait until 07:00 UTC
Log-Message "Waiting for 07:00 UTC..."

Push-Location $workDir
& $pythonCmd $scriptPath --target-hour 7 2>&1 | ForEach-Object {
    Add-Content -Path $logFile -Value $_ -Encoding UTF8
    Write-Host $_
}
Pop-Location

Log-Message "=========================================="
Log-Message "XAUUSD SELL SIGNAL MONITOR — COMPLETE"
Log-Message "=========================================="
