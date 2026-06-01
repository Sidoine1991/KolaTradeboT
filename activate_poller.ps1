# Activate Master GOM Poller Task - À exécuter en tant qu'Administrateur

Enable-ScheduledTask -TaskName 'TradBOT-Master-GOM-Poller'
Start-ScheduledTask -TaskName 'TradBOT-Master-GOM-Poller'

Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ✅ Task activated!" -ForegroundColor Green
Get-ScheduledTask -TaskName 'TradBOT-Master-GOM-Poller' | Select-Object TaskName, State
