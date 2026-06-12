# Register scheduled task for pipeline auto Good/Perfect
# Usage: PowerShell -ExecutionPolicy Bypass -File register_pipeline_auto_goodperfect_task.ps1

param(
    [string]$Frequency = "Hourly",  # Hourly, Daily, etc.
    [int]$Interval = 1              # Every 1 hour
)

$TaskName = "TradBOT-Pipeline-Auto-GoodPerfect"
$ScriptPath = "D:\Dev\TradBOT\scripts\start_pipeline_auto_goodperfect.bat"
$WorkingDir = "D:\Dev\TradBOT"
$LogPath = "D:\Dev\TradBOT\logs\pipeline_auto_goodperfect_scheduler.log"

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Register Scheduled Task: $TaskName"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host "Frequency: $Frequency"
Write-Host "Interval:  Every $Interval $Frequency(s)"
Write-Host "Script:    $ScriptPath"
Write-Host "Working:   $WorkingDir"
Write-Host "Log:       $LogPath"
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
Write-Host ""

# Supprimer ancienne tâche si elle existe
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host "Suppression tâche existante..."
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Start-Sleep -Seconds 1
}

# Créer trigger
if ($Frequency -eq "Hourly") {
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Hours $Interval) -RepetitionDuration (New-TimeSpan -Days 999)
} elseif ($Frequency -eq "Daily") {
    $trigger = New-ScheduledTaskTrigger -Daily -At "00:00" -DaysInterval $Interval
} else {
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date)
}

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
Write-Host "Pour vérifier l'état:"
Write-Host "  Get-ScheduledTask -TaskName '$TaskName'"
Write-Host ""
Write-Host "Pour désactiver:"
Write-Host "  Disable-ScheduledTask -TaskName '$TaskName'"
Write-Host ""
Write-Host "Pour lancer manuellement:"
Write-Host "  Start-ScheduledTask -TaskName '$TaskName'"
