# PowerShell Script: Start WhatsApp Report Daemon
# Lance le script Python en arrière-plan avec logs

$pythonPath = "python"
$scriptPath = Join-Path (Get-Location) "scripts\whatsapp_report_daemon.py"
$logPath = Join-Path (Get-Location) "whatsapp_daemon.log"

if (-not (Test-Path $scriptPath)) {
    Write-Host "❌ Script not found: $scriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "=" * 60 -ForegroundColor Cyan
Write-Host "🚀 Démarrage WhatsApp Report Daemon" -ForegroundColor Green
Write-Host "Script: $scriptPath" -ForegroundColor Cyan
Write-Host "Log: $logPath" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

# Lancer en arrière-plan avec redirection des logs
$process = Start-Process $pythonPath -ArgumentList $scriptPath -RedirectStandardOutput $logPath -WindowStyle Hidden -PassThru

Write-Host "✅ Daemon lancé (PID: $($process.Id))" -ForegroundColor Green
Write-Host "📋 Logs en temps réel:" -ForegroundColor Cyan

# Afficher les logs en temps réel
Get-Content -Path $logPath -Wait | ForEach-Object {
    Write-Host $_
}
