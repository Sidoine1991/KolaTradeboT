# Install GOM Sync 10-Minute Task Scheduler
# Usage: powershell.exe -ExecutionPolicy Bypass -File install-gom-sync-10min-task.ps1

$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  GOM SYNC — Windows Task Scheduler Installation" -ForegroundColor Green
Write-Host "  Creates task to run every 10 minutes" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

# Task details
$TaskName = "GOM-Sync-10Min"
$TaskDescription = "GOM Sync + WhatsApp Report — Every 10 minutes (autonomous)"
$ScriptPath = "D:\Dev\TradBOT\gom_sync_loop_10min_final.bat"
$WorkingDirectory = "D:\Dev\TradBOT"

# Check if script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Host "❌ Script not found: $ScriptPath" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Script path verified: $ScriptPath" -ForegroundColor Green
Write-Host ""

# Check admin privileges
$IsAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "⚠️  WARNING: This script requires admin privileges!" -ForegroundColor Yellow
    Write-Host "Please run: powershell -RunAs Administrator" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "If using VS Code Terminal:"
    Write-Host "  1. Ctrl+Shift+P → Terminal: Run Task"
    Write-Host "  2. Select: 'powershell'"
    Write-Host ""
    exit 1
}

Write-Host "✅ Admin privileges confirmed" -ForegroundColor Green
Write-Host ""

# Remove existing task if present
$ExistingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue

if ($ExistingTask) {
    Write-Host "⚠️  Task already exists: $TaskName" -ForegroundColor Yellow
    Write-Host "Removing previous task..." -ForegroundColor Cyan
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false | Out-Null
    Start-Sleep -Milliseconds 500
    Write-Host "✅ Previous task removed" -ForegroundColor Green
    Write-Host ""
}

# Create task action
$TaskAction = New-ScheduledTaskAction `
    -Execute "cmd.exe" `
    -Argument "/c `"$ScriptPath`"" `
    -WorkingDirectory $WorkingDirectory

# Create task trigger (every 10 minutes)
$TaskTrigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Days 365)

# Create task settings
$TaskSettings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -RunWithoutNetwork `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable

# Register the task
try {
    $Task = Register-ScheduledTask `
        -TaskName $TaskName `
        -Description $TaskDescription `
        -Action $TaskAction `
        -Trigger $TaskTrigger `
        -Settings $TaskSettings `
        -RunLevel Highest `
        -ErrorAction Stop

    Write-Host "✅ Task registered successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Task Details:" -ForegroundColor Cyan
    Write-Host "  Name: $TaskName" -ForegroundColor Gray
    Write-Host "  Description: $TaskDescription" -ForegroundColor Gray
    Write-Host "  Frequency: Every 10 minutes" -ForegroundColor Gray
    Write-Host "  Path: \$TaskName" -ForegroundColor Gray
    Write-Host "  Status: ACTIVE" -ForegroundColor Green
    Write-Host ""

    # Start the task immediately
    Write-Host "🚀 Starting task immediately..." -ForegroundColor Cyan
    Start-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 500
    Write-Host "✅ Task started" -ForegroundColor Green
    Write-Host ""

    # Show next run
    $TaskInfo = Get-ScheduledTask -TaskName $TaskName
    $TaskState = $TaskInfo.State
    Write-Host "📊 Current State:" -ForegroundColor Cyan
    Write-Host "  State: $TaskState" -ForegroundColor Gray
    Write-Host ""

    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host "✅ GOM Sync 10-Minute Task Scheduler — INSTALLED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "======================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📌 To manage the task:" -ForegroundColor Yellow
    Write-Host "  View status:     tasklist | findstr GOM" -ForegroundColor Gray
    Write-Host "  View logs:       tail -f D:\Dev\TradBOT\logs\gom_sync.log" -ForegroundColor Gray
    Write-Host "  Stop task:       Get-ScheduledTask -TaskName '$TaskName' | Stop-ScheduledTask" -ForegroundColor Gray
    Write-Host "  Remove task:     Unregister-ScheduledTask -TaskName '$TaskName'" -ForegroundColor Gray
    Write-Host ""

} catch {
    Write-Host "❌ Error registering task:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
