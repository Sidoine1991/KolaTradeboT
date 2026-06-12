# Register GOM Sync Daemon as Windows Scheduled Task
# Run as Administrator
#
# Usage: powershell -ExecutionPolicy Bypass -File scripts/register_gom_sync_daemon.ps1

$taskName = "TradBOT-GOM-Sync-Daemon"
$scriptPath = "D:\Dev\TradBOT\scripts\start_gom_sync_loop.bat"
$logPath = "D:\Dev\TradBOT\logs\gom_sync_daemon.log"

# Ensure logs directory exists
if (-not (Test-Path "D:\Dev\TradBOT\logs")) {
    New-Item -ItemType Directory -Path "D:\Dev\TradBOT\logs" -Force | Out-Null
}

# Check if task already exists and remove it
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "Removing existing task: $taskName"
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Create trigger: Start at system startup
$trigger = New-ScheduledTaskTrigger -AtStartup

# Create action: Run the batch script
$action = New-ScheduledTaskAction -Execute $scriptPath

# Create task settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

# Register the task
Register-ScheduledTask `
    -TaskName $taskName `
    -Trigger $trigger `
    -Action $action `
    -Settings $settings `
    -Description "TradBOT GOM Sync Daemon - Runs every 10 minutes" `
    -RunLevel Highest | Out-Null

Write-Host "✅ Tâche planifiée créée: $taskName"
Write-Host "   Script: $scriptPath"
Write-Host "   Logs: $logPath"
Write-Host ""
Write-Host "Pour démarrer manuellement:"
Write-Host "   Start-ScheduledTask -TaskName '$taskName'"
Write-Host ""
Write-Host "Pour voir les logs:"
Write-Host "   Get-Content $logPath -Tail 50 -Wait"
