# Schedule GOM Sync + WhatsApp Report every 10 minutes

Write-Host "Setting up GOM Sync 10-minute scheduled task..."
Write-Host ""

$taskName = "TradBOT-GOM-Sync-10min"
$taskPath = "\TradBOT\"

# Create trigger (every 10 minutes)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days 365)

# Create action
$action = New-ScheduledTaskAction `
    -Execute "C:\Python314_old\python.exe" `
    -Argument "D:\Dev\TradBOT\Python\gom_sync_with_report.py --report" `
    -WorkingDirectory "D:\Dev\TradBOT"

# Create settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

# Check if task exists
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Removing existing task..."
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    Start-Sleep 2
}

# Register task
Register-ScheduledTask `
    -TaskName $taskName `
    -TaskPath $taskPath `
    -Trigger $trigger `
    -Action $action `
    -Settings $settings `
    -RunLevel Highest `
    -Force | Out-Null

Write-Host "Task created: $taskName"
Write-Host "Schedule: Every 10 minutes"
Write-Host "Logs: D:\Dev\TradBOT\logs\gom_sync.log"
Write-Host ""
Write-Host "Execution cycle:"
Write-Host "  1. Load GOM data from gom_signal.json"
Write-Host "  2. Send verdicts POST /gom-verdict to ai_server:8000"
Write-Host "  3. Build report: symbol, verdict, entry, SL, TP, coherence"
Write-Host "  4. Send report via WhatsApp (PsychoBot or fallback log)"
Write-Host "  5. Append logs with timestamps and errors"
Write-Host ""
Write-Host "DONE! Loop starts now."
