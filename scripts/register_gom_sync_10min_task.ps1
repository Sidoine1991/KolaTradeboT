# Register scheduled task for GOM Sync (every 10 minutes)
# Usage: PowerShell -ExecutionPolicy Bypass -File register_gom_sync_10min_task.ps1

param(
    [int]$Interval = 10  # Minutes entre exécutions
)

$TaskName = "TradBOT-GOM-Sync-10min"
$ScriptPath = "D:\Dev\TradBOT\scripts\start_gom_sync_10min.bat"
$WorkingDir = "D:\Dev\TradBOT"
$LogPath = "D:\Dev\TradBOT\logs\gom_sync_scheduler.log"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Register GOM Sync Scheduled Task"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Task:     $TaskName"
Write-Host "Interval: Every $Interval minutes"
Write-Host "Script:   $ScriptPath"
Write-Host "Working:  $WorkingDir"
Write-Host "Log:      $LogPath"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

# Supprimer ancienne tâche si elle existe
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Suppression tâche existante..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Start-Sleep -Seconds 1
}

# Créer trigger (toutes les 10 minutes)
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes $Interval) `
    -RepetitionDuration (New-TimeSpan -Days 999)

# Action: lancer le script
$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"$ScriptPath`" >> `"$LogPath`" 2>&1" `
    -WorkingDirectory $WorkingDir

# Settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew

# Registrer la tâche
Register-ScheduledTask `
    -TaskName $TaskName `
    -Trigger $trigger `
    -Action $action `
    -Settings $settings `
    -RunLevel Highest `
    -Force

Write-Host "✅ Tâche enregistrée avec succès"
Write-Host ""
Write-Host "Vérifier l'état:"
Write-Host "  Get-ScheduledTask -TaskName '$TaskName'"
Write-Host ""
Write-Host "Lancer manuellement:"
Write-Host "  Start-ScheduledTask -TaskName '$TaskName'"
Write-Host ""
Write-Host "Voir les logs:"
Write-Host "  tail -f $LogPath"
