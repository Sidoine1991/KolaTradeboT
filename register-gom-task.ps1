$taskName = "TradBOT-GOM-Sync-10min"
$taskPath = "\TradBOT\"
$scriptPath = "D:\Dev\TradBOT\Python\gom_sync_with_report.py"

Write-Host "Registering GOM Sync task..."

$action = New-ScheduledTaskAction -Execute "python.exe" -Argument "`"$scriptPath`" --report" -WorkingDirectory "D:\Dev\TradBOT"
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10)
$settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Highest

$existing = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -Force
}

Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description "TradBOT: GOM Sync every 10 minutes" -Force

Write-Host "Task registered successfully!"
Write-Host "Status: Running every 10 minutes in background"
Write-Host "Logs: D:\Dev\TradBOT\logs\gom_sync_task.log"
