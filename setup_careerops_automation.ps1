# Career-Ops WhatsApp Automation Setup
# Windows Task Scheduler configuration

Write-Host "CAREER-OPS PSYCHOBOT INTEGRATION SETUP" -ForegroundColor Cyan
Write-Host ""

$projectRoot = "D:\Dev\TradBOT"
$taskName = "CareerOps_DailyWhatsApp"
$automationScript = "$projectRoot\career_ops_whatsapp_automation.py"

# Remove old task if exists
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($taskExists) {
    Write-Host "Removing existing task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Create new task
Write-Host "Creating new scheduled task..." -ForegroundColor Yellow

$action = New-ScheduledTaskAction -Execute "python" -Argument $automationScript

$trigger = New-ScheduledTaskTrigger -Daily -At 06:00:00

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest

$task = New-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Principal $principal `
    -Description "Career-Ops: Daily job prospection via WhatsApp"

Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null

Write-Host "Task created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Scheduled Task Details:" -ForegroundColor Cyan
Write-Host "  Name: $taskName" -ForegroundColor White
Write-Host "  Schedule: Daily at 06:00 WAT" -ForegroundColor White
Write-Host "  Script: $automationScript" -ForegroundColor White
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Add to ai_server.py:" -ForegroundColor White
Write-Host "   from career_ops_psychobot_bridge import router as careerops_router" -ForegroundColor Cyan
Write-Host "   app.include_router(careerops_router, prefix='/api')" -ForegroundColor Cyan
Write-Host ""
Write-Host "2. Restart ai_server.py" -ForegroundColor White
Write-Host ""
Write-Host "3. Tomorrow at 06:00 WAT - First automated report!" -ForegroundColor Green
Write-Host ""
