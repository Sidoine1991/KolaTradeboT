# PowerShell Script: Start Unified TOP 3 Daemon
# Lance le daemon qui envoie UN SEUL rapport consolidé toutes les 20 minutes

$pythonPath = "python"
$scriptPath = Join-Path (Get-Location) "scripts\unified_top3_daemon.py"
$logPath = Join-Path (Get-Location) "unified_top3_daemon.log"

if (-not (Test-Path $scriptPath)) {
    Write-Host "ERROR: Script not found: $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "Starting Unified TOP 3 Daemon" -ForegroundColor Green
Write-Host "Script: $scriptPath" -ForegroundColor Cyan
Write-Host "Log: $logPath" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Lancer en arrière-plan avec redirection des logs
$process = Start-Process $pythonPath -ArgumentList $scriptPath -RedirectStandardOutput $logPath -WindowStyle Hidden -PassThru

Write-Host "Daemon started (PID: $($process.Id))" -ForegroundColor Green
Write-Host "Logs:" -ForegroundColor Cyan

# Afficher les logs en temps réel
Get-Content -Path $logPath -Wait | ForEach-Object {
    Write-Host $_
}
