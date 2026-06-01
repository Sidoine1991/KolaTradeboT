# Master GOM Poller Runner - Restart automatique en cas de crash
# À exécuter en tant que: PowerShell -ExecutionPolicy Bypass -File "D:\Dev\TradBOT\master_gom_poller_runner.ps1"

$pythonScript = "D:\Dev\TradBOT\python\master_gom_poller.py"
$pythonExe = "python"
$interval = 30  # Secondes entre les cycles
$maxRestarts = 0  # 0 = redémarrage infini
$restartDelay = 10  # Secondes avant de relancer après un crash

$restartCount = 0

function Start-Poller {
    param([int]$Attempt)

    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Runner] 🚀 Starting Master GOM Poller (Attempt $Attempt)..." -ForegroundColor Green

    try {
        & $pythonExe $pythonScript --interval $interval
    }
    catch {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Runner] ❌ Poller crashed: $_" -ForegroundColor Red
    }
}

Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Runner] ======================================================================" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Runner] MASTER GOM POLLER RUNNER - Auto-Restart Mode" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Runner] Script: $pythonScript" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Runner] Interval: ${interval}s" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Runner] ======================================================================" -ForegroundColor Cyan
Write-Host ""

while ($true) {
    $restartCount++

    if ($maxRestarts -gt 0 -and $restartCount -gt $maxRestarts) {
        Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Runner] ⏹️ Max restarts ($maxRestarts) reached. Stopping." -ForegroundColor Yellow
        exit 0
    }

    Start-Poller $restartCount

    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Runner] ⏱️ Poller exited. Restarting in ${restartDelay}s..." -ForegroundColor Yellow
    Start-Sleep -Seconds $restartDelay
}
