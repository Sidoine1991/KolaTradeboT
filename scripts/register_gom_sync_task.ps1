$action = New-ScheduledTaskAction `
    -Execute 'cmd.exe' `
    -Argument '/c D:\Dev\TradBOT\scripts\start_gom_sync_report.bat' `
    -WorkingDirectory 'D:\Dev\TradBOT'

$trigger = New-ScheduledTaskTrigger `
    -RepetitionInterval (New-TimeSpan -Minutes 10) `
    -Once -At (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss') `
    -RepetitionDuration (New-TimeSpan -Days 365)

$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -MultipleInstances IgnoreNew `
    -Hidden

Unregister-ScheduledTask -TaskName 'TradBOT_GOM_Sync_10min' -Confirm:$false -ErrorAction SilentlyContinue

Register-ScheduledTask `
    -TaskName 'TradBOT_GOM_Sync_10min' `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -RunLevel Highest `
    -Description 'GOM Sync + Rapport WhatsApp toutes les 10 minutes' `
    -Force

Write-Host "Tache TradBOT_GOM_Sync_10min enregistree OK"
