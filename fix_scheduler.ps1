# Script a lancer en tant qu'Administrateur
$taskName = "TradBOT_Pipeline_Horaire"

# Supprimer l'ancienne tache
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# Action
$action = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c D:\Dev\TradBOT\run_pipeline_auto.bat" `
    -WorkingDirectory "D:\Dev\TradBOT"

# Trigger : toutes les heures
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Hours 1) -Once -At (Get-Date)

# Settings : pas de contrainte batterie, timeout 1h
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -RestartCount 2 `
    -RestartInterval (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew

# Principal
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -RunLevel Highest `
    -LogonType Interactive

# Creer la tache
Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "TradBOT Pipeline autonome - toutes les heures" `
    -Force

# Verifier
$task = Get-ScheduledTask -TaskName $taskName
$info = $task | Get-ScheduledTaskInfo
Write-Host "Tache creee - Etat: $($task.State)"
Write-Host "Prochain run: $($info.NextRunTime)"
Write-Host "AllowBattery: $($task.Settings.AllowStartIfOnBatteries)"
Write-Host "Timeout: $($task.Settings.ExecutionTimeLimit)"
