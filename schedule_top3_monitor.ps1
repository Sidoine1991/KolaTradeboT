# TradBOT — Suivi 20 min Top 3 (scan matinal, PAS XAUUSD seul)
# Exécuter une fois en admin pour créer la tâche planifiée

$TaskName = "TradBOT_Top3_Monitor"
$ScriptPath = "D:\Dev\TradBOT\scripts\unified_top3_master_report.py"
$PythonPath = "python"
$LogFile = "D:\Dev\TradBOT\logs\top3_monitor_scheduled.log"

Write-Host "Planification suivi 20 min — Top 3 scan matinal" -ForegroundColor Cyan
Write-Host "(Symboles lus depuis data/state/morning_top3.json)" -ForegroundColor Gray
Write-Host ""

$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($ExistingTask) {
    Write-Host "Suppression ancienne tache $TaskName..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Desactiver l'ancienne tache XAUUSD si presente
$OldTask = Get-ScheduledTask -TaskName "TradBOT_XAUUSD_Monitor" -ErrorAction SilentlyContinue
if ($OldTask) {
    Write-Host "Desactivation TradBOT_XAUUSD_Monitor (obsolete)..." -ForegroundColor Yellow
    Disable-ScheduledTask -TaskName "TradBOT_XAUUSD_Monitor" -ErrorAction SilentlyContinue
}

if (-not (Test-Path "D:\Dev\TradBOT\logs")) {
    New-Item -ItemType Directory -Path "D:\Dev\TradBOT\logs" | Out-Null
}

$Action = New-ScheduledTaskAction `
    -Execute $PythonPath `
    -Argument "`"$ScriptPath`" >> `"$LogFile`" 2>&1" `
    -WorkingDirectory "D:\Dev\TradBOT"

$Trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 20)

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Description "TradBOT Top 3 — suivi 20 min (symboles du scan matinal)" `
    -Force

Write-Host "Tache creee: $TaskName" -ForegroundColor Green
Write-Host "  Script: $ScriptPath"
Write-Host "  Frequence: toutes les 20 minutes"
Write-Host "  Log: $LogFile"
Write-Host ""
Write-Host "Avant le 1er suivi, lancer le scan matinal:" -ForegroundColor Yellow
Write-Host "  python python\morning_scan.py"
Write-Host ""
Write-Host "Test immediat:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName '$TaskName'"
