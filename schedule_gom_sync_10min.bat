@echo off
REM GOM Sync + WhatsApp Report — Windows Task Scheduler setup
REM Exécute toutes les 10 minutes

REM Create the scheduled task
powershell -Command ^
  $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days 365); ^
  $action = New-ScheduledTaskAction -Execute 'C:\Python314_old\python.exe' -Argument 'D:\Dev\TradBOT\Python\gom_sync_with_report.py --report' -WorkingDirectory 'D:\Dev\TradBOT'; ^
  $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew; ^
  $existing = Get-ScheduledTask -TaskName 'TradBOT-GOM-Sync-10min' -ErrorAction SilentlyContinue; ^
  if ($existing) { Unregister-ScheduledTask -TaskName 'TradBOT-GOM-Sync-10min' -Confirm:$false }; ^
  Register-ScheduledTask -TaskName 'TradBOT-GOM-Sync-10min' -TaskPath '\TradBOT\' -Trigger $trigger -Action $action -Settings $settings -RunLevel Highest -Force

echo Task created: TradBOT-GOM-Sync-10min
echo Schedule: Every 10 minutes
echo Logs: D:\Dev\TradBOT\logs\gom_sync.log
echo DONE!
