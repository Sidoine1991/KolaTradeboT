# Setup GOM Sync 10-minute task for Windows Task Scheduler
# Run as Administrator

param(
    [switch]$Uninstall
)

$TaskPath = "\TradBOT\"
$TaskName = "TradBOT-GOM-Sync-10min"
$FullTaskName = "$TaskPath$TaskName"

if ($Uninstall) {
    Write-Host "[UNINSTALL] Suppression de la tâche $FullTaskName..."
    Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    Write-Host "✅ Tâche supprimée"
    exit 0
}

Write-Host "[SETUP] Configuration de la tâche GOM Sync 10 minutes"
Write-Host "Task: $FullTaskName"

# Supprimer l'existant si présent
Write-Host "[CLEANUP] Suppression de la tâche existante..."
Unregister-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
Start-Sleep -Milliseconds 1000

# Créer le trigger — 10 minutes à partir de maintenant, répétées 23h50
$now = Get-Date
$trigger = New-ScheduledTaskTrigger -Once -At $now -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Hours 23 -Minutes 50)

# Action
$action = New-ScheduledTaskAction `
    -Execute "D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat" `
    -WorkingDirectory "D:\Dev\TradBOT"

# Settings
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

# Enregistrer
Write-Host "[CREATE] Création de la tâche..."
Register-ScheduledTask `
    -TaskName $TaskName `
    -TaskPath $TaskPath `
    -Trigger $trigger `
    -Action $action `
    -Settings $settings `
    -Force | Out-Null

Write-Host "✅ Tâche créée avec succès"
Write-Host ""
Write-Host "Détails:"
Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName | Select-Object TaskName, State, @{N='LastRun'; E={$_ | Get-ScheduledTaskInfo | Select-Object -ExpandProperty LastRunTime}}
