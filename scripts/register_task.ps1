$action = New-ScheduledTaskAction `
    -Execute 'cmd.exe' `
    -Argument '/c D:\Dev\TradBOT\run_pipeline_auto.bat' `
    -WorkingDirectory 'D:\Dev\TradBOT'

$trigger = New-ScheduledTaskTrigger `
    -RepetitionInterval (New-TimeSpan -Hours 1) `
    -Once -At '07:00' `
    -RepetitionDuration (New-TimeSpan -Hours 15)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 10) `
    -MultipleInstances IgnoreNew `
    -Hidden

Unregister-ScheduledTask -TaskName 'TradBOT_Pipeline_Horaire' -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName 'TradBOT_Pipeline_Horaire' `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -RunLevel Highest `
    -Description 'TradBOT scan pipeline toutes les heures 07h-22h' `
    -Force

Write-Host "Tache planifiee enregistree OK"
