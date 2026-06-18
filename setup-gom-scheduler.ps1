# GOM Sync 10-Minute Task Scheduler Setup (PowerShell)
# Run as Administrator: powershell -ExecutionPolicy Bypass -File setup-gom-scheduler.ps1

$taskPath = "\TradBOT\"
$taskName = "GOM-Sync-10min-Report"
$scriptPath = "D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat"
$workingDir = "D:\Dev\TradBOT"

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "GOM SYNC 10-MINUTE TASK SETUP" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host ""

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "[ERROR] This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator and try again" -ForegroundColor Yellow
    exit 1
}

Write-Host "[STEP 1] Removing existing task..." -ForegroundColor Yellow
Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

Write-Host "[STEP 2] Creating trigger (every 10 minutes)..." -ForegroundColor Yellow
$startTime = Get-Date
$trigger = New-ScheduledTaskTrigger -Once -At $startTime -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days 365)

Write-Host "[STEP 3] Creating action..." -ForegroundColor Yellow
$action = New-ScheduledTaskAction -Execute $scriptPath -WorkingDirectory $workingDir

Write-Host "[STEP 4] Creating task settings..." -ForegroundColor Yellow
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

Write-Host "[STEP 5] Registering task..." -ForegroundColor Yellow
try {
    Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Trigger $trigger -Action $action -Settings $settings -Force | Out-Null
    Write-Host ""
    Write-Host "[SUCCESS] Task registered successfully!" -ForegroundColor Green
    Write-Host ""

    # Verify and display
    $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName
    Write-Host "Task Details:" -ForegroundColor Cyan
    Write-Host "  Name:       $($task.TaskName)" -ForegroundColor Gray
    Write-Host "  Path:       $($task.TaskPath)" -ForegroundColor Gray
    Write-Host "  State:      $($task.State)" -ForegroundColor Gray
    Write-Host "  Action:     $scriptPath" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Cyan
    Write-Host "  Interval:   Every 10 minutes" -ForegroundColor Gray
    Write-Host "  Duration:   365 days" -ForegroundColor Gray
    Write-Host "  Timeout:    5 minutes max per execution" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Logs:" -ForegroundColor Cyan
    Write-Host "  Primary:    D:\Dev\TradBOT\logs\gom_sync.log" -ForegroundColor Gray
    Write-Host "  Dashboard:  http://127.0.0.1:8765/gom" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Task will start automatically in 10 minutes" -ForegroundColor Gray
    Write-Host "  2. Monitor logs: Get-Content D:\Dev\TradBOT\logs\gom_sync.log -Tail 20" -ForegroundColor Gray
    Write-Host "  3. Check dashboard: http://127.0.0.1:8765/gom" -ForegroundColor Gray
    Write-Host "  4. To manually run: Start-ScheduledTask -TaskPath '$taskPath' -TaskName '$taskName'" -ForegroundColor Gray
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host ""

} catch {
    Write-Host "[ERROR] Failed to register task: $_" -ForegroundColor Red
    exit 1
}
