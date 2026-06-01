# Career-Ops Windows Task Scheduler Setup
# Registers autonomous daily job scan at 06:00 WAT (UTC+1)

param(
    [string]$ProjectPath = "D:\Dev\TradBOT",
    [string]$Time = "06:00",
    [string]$TaskName = "CareerOps_DailyScan"
)

Write-Host "=" -NoNewline; Write-Host "=" * 68 -NoNewline; Write-Host "="
Write-Host "Career-Ops Windows Task Scheduler Setup" -ForegroundColor Cyan
Write-Host "=" -NoNewline; Write-Host "=" * 68 -NoNewline; Write-Host "="
Write-Host ""

# Verify Python
Write-Host "[Check] Python installation..." -ForegroundColor Yellow
$pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
if ($pythonPath) {
    Write-Host "[OK] Python found: $pythonPath"
} else {
    Write-Host "[ERROR] Python not found in PATH"
    exit 1
}

# Verify project
Write-Host "[Check] Project path..." -ForegroundColor Yellow
if (Test-Path "$ProjectPath\career_ops\scheduler.py") {
    Write-Host "[OK] Scheduler found: $ProjectPath\career_ops\scheduler.py"
} else {
    Write-Host "[ERROR] Scheduler not found at $ProjectPath\career_ops\scheduler.py"
    exit 1
}

# Create task action
Write-Host ""
Write-Host "[Setup] Creating task action..." -ForegroundColor Yellow

$taskAction = New-ScheduledTaskAction `
    -Execute $pythonPath `
    -Argument "career_ops\scheduler.py" `
    -WorkingDirectory $ProjectPath

Write-Host "[OK] Task action created"

# Create trigger (daily at specified time)
Write-Host "[Setup] Creating daily trigger at $Time..." -ForegroundColor Yellow

$taskTrigger = New-ScheduledTaskTrigger `
    -Daily `
    -At $Time

Write-Host "[OK] Trigger created (Daily @ $Time)"

# Create settings
Write-Host "[Setup] Configuring task settings..." -ForegroundColor Yellow

$taskSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -RunOnlyIfIdle $false `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit ([TimeSpan]::FromHours(2))

Write-Host "[OK] Settings configured"

# Register task
Write-Host ""
Write-Host "[Action] Registering task..." -ForegroundColor Cyan

try {
    # Try to remove existing task
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null

    # Register new task
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $taskAction `
        -Trigger $taskTrigger `
        -Settings $taskSettings `
        -Description "Career-Ops: Daily autonomous job scan at 06:00 WAT" `
        -Force | Out-Null

    Write-Host "[OK] Task registered: $TaskName"
} catch {
    Write-Host "[ERROR] Failed to register task: $_"
    exit 1
}

# Verify registration
Write-Host "[Verify] Checking task registration..." -ForegroundColor Yellow

$task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($task) {
    Write-Host "[OK] Task found"
    Write-Host "  Name: $($task.TaskName)"
    Write-Host "  Path: $($task.TaskPath)"
    Write-Host "  State: $($task.State)"
    Write-Host "  Trigger: Daily @ $Time"
} else {
    Write-Host "[ERROR] Task not found after registration"
    exit 1
}

Write-Host ""
Write-Host "=" -NoNewline; Write-Host "=" * 68 -NoNewline; Write-Host "="
Write-Host "SETUP COMPLETE" -ForegroundColor Green
Write-Host "=" -NoNewline; Write-Host "=" * 68 -NoNewline; Write-Host "="
Write-Host ""

Write-Host "Task Information:"
Write-Host "  Name: $TaskName"
Write-Host "  Schedule: Daily @ $Time"
Write-Host "  Action: python career_ops\scheduler.py"
Write-Host "  Location: $ProjectPath"
Write-Host ""

Write-Host "Manual Execution:"
Write-Host "  Start task: Start-ScheduledTask -TaskName '$TaskName'"
Write-Host "  Run now: & '$pythonPath' (Get-ScheduledTask -TaskName '$TaskName').Actions[0].Arguments"
Write-Host ""

Write-Host "Next Steps:"
Write-Host "  1. Task will run automatically at $Time tomorrow"
Write-Host "  2. Check reports/career_ops/daily_*.json for daily logs"
Write-Host "  3. Verify .env has PSYCHOBOT_URL and WHATSAPP_PHONE set"
Write-Host ""
