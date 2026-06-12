#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Register TradBOT Autonomous Trading Scheduler (Windows Task Scheduler)

.DESCRIPTION
    Creates scheduled tasks for:
    - GOM Sync + WhatsApp Report (every 10 minutes)
    - Pipeline Hourly (every hour, at :00 minute)

.EXAMPLE
    .\register-autonomous-scheduler.ps1

.NOTES
    Requires: Administrator privileges
#>

param(
    [Switch]$Force,
    [Switch]$Unregister
)

$ErrorActionPreference = "Stop"

# Check admin
$isAdmin = [Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "❌ This script requires Administrator privileges!" -ForegroundColor Red
    Write-Host "   Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    exit 1
}

$TradbotDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogDir = Join-Path $TradbotDir "logs"

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "📅 TradBOT Autonomous Scheduler Registration" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

if ($Unregister) {
    Write-Host "[UNREGISTER] Removing scheduled tasks..." -ForegroundColor Yellow

    @("TradBOT-GOM-Sync-10min", "TradBOT-Pipeline-Hourly") | ForEach-Object {
        if (Get-ScheduledTask -TaskName $_ -ErrorAction SilentlyContinue) {
            Unregister-ScheduledTask -TaskName $_ -Confirm:$false
            Write-Host "   ✅ Removed: $_" -ForegroundColor Green
        }
    }

    exit 0
}

# Task 1: GOM Sync every 10 minutes
Write-Host "[1/2] Creating GOM Sync task (every 10 minutes)..." -ForegroundColor Yellow

$taskName = "TradBOT-GOM-Sync-10min"
$scriptPath = Join-Path $TradbotDir "Python\gom_sync_with_report.py"
$logFile = Join-Path $LogDir "gom_sync_scheduled.log"

# Check if already exists
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    if ($Force) {
        Write-Host "   Removing existing task..." -ForegroundColor Gray
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    } else {
        Write-Host "   ℹ️  Task already exists. Use -Force to replace." -ForegroundColor Yellow
    }
}

# Create action: Run Python script
$action = New-ScheduledTaskAction -Execute "python" `
    -Argument "`"$scriptPath`" --report" `
    -WorkingDirectory $TradbotDir

# Create trigger: Repeat every 10 minutes indefinitely
$trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 10) `
    -At (Get-Date -Hour 0 -Minute 0 -Second 0) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

# Create settings: Run whether user is logged in or not
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable `
    -MultipleInstancePolicy SkipNewInstance `
    -StartWhenAvailable

# Register task
Register-ScheduledTask -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "TradBOT: GOM Sync + WhatsApp Report (every 10 min)" `
    -RunLevel Highest | Out-Null

Write-Host "   ✅ Task registered: $taskName" -ForegroundColor Green

# Task 2: Pipeline Hourly
Write-Host ""
Write-Host "[2/2] Creating Pipeline task (every hour)..." -ForegroundColor Yellow

$taskName = "TradBOT-Pipeline-Hourly"
$scriptPath = Join-Path $TradbotDir "Python\pipeline_hourly_autonomous.py"
$logFile = Join-Path $LogDir "pipeline_scheduled.log"

# Check if already exists
if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
    if ($Force) {
        Write-Host "   Removing existing task..." -ForegroundColor Gray
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    } else {
        Write-Host "   ℹ️  Task already exists. Use -Force to replace." -ForegroundColor Yellow
    }
}

# Create action
$action = New-ScheduledTaskAction -Execute "python" `
    -Argument "`"$scriptPath`" --once" `
    -WorkingDirectory $TradbotDir

# Create trigger: Run every hour at :00 minute
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday `
    -At "00:00" -RepetitionInterval (New-TimeSpan -Hours 1) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

# Create settings
$settings = New-ScheduledTaskSettingsSet -RunOnlyIfNetworkAvailable `
    -MultipleInstancePolicy SkipNewInstance `
    -StartWhenAvailable

# Register task
Register-ScheduledTask -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "TradBOT: Pipeline Hourly Autonomous Execution" `
    -RunLevel Highest | Out-Null

Write-Host "   ✅ Task registered: $taskName" -ForegroundColor Green

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "✅ SCHEDULER SETUP COMPLETE" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Scheduled Tasks:" -ForegroundColor Yellow
Write-Host "   • GOM Sync + Report ........... Every 10 minutes" -ForegroundColor Green
Write-Host "   • Pipeline Hourly ............ Every 1 hour" -ForegroundColor Green
Write-Host ""

Write-Host "View/Manage Tasks:" -ForegroundColor Yellow
Write-Host "   • GUI: tasksched.msc" -ForegroundColor Gray
Write-Host "   • CLI: Get-ScheduledTask -TaskName 'TradBOT-*'" -ForegroundColor Gray
Write-Host ""

Write-Host "To unregister all tasks:" -ForegroundColor Yellow
Write-Host "   .\register-autonomous-scheduler.ps1 -Unregister" -ForegroundColor Gray
Write-Host ""

Write-Host "Reports Directory:" -ForegroundColor Yellow
Write-Host "   $LogDir" -ForegroundColor Gray
Write-Host ""

Write-Host "============================================================" -ForegroundColor Cyan
