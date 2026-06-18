# ============================================================================
# GOM Sync + Report Daemon — Boucle 10 minutes
# ============================================================================
# Exécute la synchronisation GOM toutes les 10 minutes
# Logs stockés dans logs/gom_sync.log et logs/gom_sync_loop.log
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1
#   powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1 -IntervalMinutes 5
#   powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1 -RunOnce
# ============================================================================

param(
    [int]$IntervalMinutes = 10,
    [switch]$RunOnce = $false
)

$ErrorActionPreference = "Continue"
$workDir = "D:\Dev\TradBOT"
$pythonCmd = "python"
$scriptPath = "$workDir\python\gom_sync_with_report.py"
$logDir = "$workDir\logs"
$logFile = "$logDir\gom_sync_loop.log"
$intervalSeconds = $IntervalMinutes * 60

# Créer dossier logs si absent
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
Log-Message "GOM SYNC DAEMON - Demarrage"
Log-Message "Intervalle: $IntervalMinutes minutes"
Log-Message "Logs: $logFile"
Log-Message "=========================================="

$runCount = 0
$successCount = 0
$errorCount = 0

while ($true) {
    $runCount++
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Log-Message "[$runCount] Execution synchronisation GOM..."

    try {
        Push-Location $workDir
        & $pythonCmd $scriptPath --report 2>&1 | ForEach-Object {
            Add-Content -Path $logFile -Value $_ -Encoding UTF8
        }
        $exitCode = $LASTEXITCODE

        if ($exitCode -eq 0) {
            Log-Message "[$runCount] [OK] Succes (exit code 0)"
            $successCount++
        } else {
            Log-Message "[$runCount] [WARN] Avertissement (exit code $exitCode)"
            $errorCount++
        }

        Pop-Location
    } catch {
        $errorMsg = $_.Exception.Message
        Log-Message "[$runCount] [ERROR] ERREUR: $errorMsg"
        $errorCount++
    }

    # Statistiques
    Log-Message "Stats: $successCount succes, $errorCount erreurs (total: $runCount)"
    Log-Message "---"

    if ($RunOnce) {
        Log-Message "Mode --RunOnce: arret apres execution unique"
        break
    }

    $nextTime = (Get-Date).AddSeconds($intervalSeconds).ToString("yyyy-MM-dd HH:mm:ss")
    Log-Message "Prochaine execution a $nextTime (attente $($IntervalMinutes)min)..."

    Start-Sleep -Seconds $intervalSeconds
}

Log-Message "=========================================="
Log-Message "GOM SYNC DAEMON - Arret"
Log-Message "=========================================="
