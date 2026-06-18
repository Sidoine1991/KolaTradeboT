# GOM Sync 10-Minute Scheduled Task Setup (Non-Interactive)
# This script creates the Windows Task Scheduler task for GOM sync every 10 minutes

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "This script requires Administrator privileges." -ForegroundColor Red
    Write-Host "Please run PowerShell as Administrator" -ForegroundColor Yellow
    exit 1
}

Write-Host "[SETUP] GOM Sync 10-Minute Task" -ForegroundColor Green
Write-Host "================================" -ForegroundColor Green

# Define task details
$taskName = "TradBOT-GOM-Sync-10min"
$taskPath = "\TradBOT\"
$scriptPath = "D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat"
$workingDir = "D:\Dev\TradBOT"

# Delete existing task if it exists
Write-Host "[1/4] Removing existing task..." -ForegroundColor Yellow
Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue

# Create trigger (every 10 minutes)
Write-Host "[2/4] Creating trigger..." -ForegroundColor Yellow
$startTime = Get-Date
$trigger = New-ScheduledTaskTrigger -Once -At $startTime -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Hours 23 -Minutes 50)

# Create action
Write-Host "[3/4] Creating action..." -ForegroundColor Yellow
$action = New-ScheduledTaskAction -Execute $scriptPath -WorkingDirectory $workingDir

# Create settings
$settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 5) -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

# Register task
Write-Host "[4/4] Registering task..." -ForegroundColor Yellow
try {
    Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Trigger $trigger -Action $action -Settings $settings -Force | Out-Null
    Write-Host "`n[SUCCESS] Task created successfully" -ForegroundColor Green

    # Verify
    $task = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName
    Write-Host "Task Name: $($task.TaskName)" -ForegroundColor Cyan
    Write-Host "Task Path: $($task.TaskPath)" -ForegroundColor Cyan
    Write-Host "State: $($task.State)" -ForegroundColor Cyan
    Write-Host "`n[INFO] Task will run every 10 minutes starting immediately" -ForegroundColor Green
    Write-Host "[INFO] Log file: D:\Dev\TradBOT\logs\gom_sync.log" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Failed to create task: $_" -ForegroundColor Red
    exit 1
}
