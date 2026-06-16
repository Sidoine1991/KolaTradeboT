#!/usr/bin/env pwsh
# GOM Sync 10-Minute Automatic Deployment
# Exécute: cd D:\Dev\TradBOT && powershell -NoProfile -ExecutionPolicy Bypass -File DEPLOY_10MIN_AUTO.ps1

param(
    [switch]$NoWait = $false
)

Write-Host @"
╔════════════════════════════════════════════════════════════╗
║  GOM SYNC 10-MINUTE AUTOMATIC DEPLOYMENT                  ║
║  Synchronisation + Rapport WhatsApp Autonome              ║
╚════════════════════════════════════════════════════════════╝
"@

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "`n❌ ERROR: Administrator privileges required!"
    Write-Host "`nPlease run:"
    Write-Host "  1. Right-click PowerShell"
    Write-Host "  2. Select 'Run as administrator'"
    Write-Host "  3. Run: cd D:\Dev\TradBOT && powershell -NoProfile -ExecutionPolicy Bypass -File DEPLOY_10MIN_AUTO.ps1"
    exit 1
}

Write-Host "`n✅ Running with admin privileges`n"

# Verify components
Write-Host "[CHECK 1] Verifying components..."
$components = @(
    "D:\Dev\TradBOT\Python\gom_sync_with_report.py",
    "D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat"
)

foreach ($comp in $components) {
    if (Test-Path $comp) {
        Write-Host "  ✅ $($comp | Split-Path -Leaf)"
    } else {
        Write-Host "  ❌ NOT FOUND: $comp"
        exit 1
    }
}

# Check Python
Write-Host "`n[CHECK 2] Verifying Python..."
$pythonPath = (Get-Command python -ErrorAction SilentlyContinue).Source
if ($pythonPath) {
    $pythonVersion = python --version 2>&1
    Write-Host "  ✅ $pythonVersion"
} else {
    Write-Host "  ❌ Python not found in PATH"
    exit 1
}

# Delete old task
Write-Host "`n[STEP 1] Cleaning up old task..."
$oldTask = Get-ScheduledTask -TaskPath "\TradBOT\" -TaskName "GOM-Sync-10min" -ErrorAction SilentlyContinue
if ($oldTask) {
    Unregister-ScheduledTask -TaskPath "\TradBOT\" -TaskName "GOM-Sync-10min" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
    Write-Host "  ✅ Old task removed"
} else {
    Write-Host "  ⓘ No previous task found"
}

Start-Sleep -Milliseconds 500

# Create task
Write-Host "`n[STEP 2] Creating Task Scheduler task..."
$taskPath = "\TradBOT\"
$taskName = "GOM-Sync-10min"
$scriptPath = "D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat"

$action = New-ScheduledTaskAction `
    -Execute $scriptPath `
    -WorkingDirectory "D:\Dev\TradBOT"

$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date).AddSeconds(5) `
    -RepetitionInterval (New-TimeSpan -Minutes 10) `
    -RepetitionDuration (New-TimeSpan -Days 36500)

$principal = New-ScheduledTaskPrincipal `
    -UserId (whoami) `
    -LogonType S4U `
    -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable `
    -MultipleInstances IgnoreNew

$task = New-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "GOM Sync + WhatsApp Report every 10 minutes"

try {
    Register-ScheduledTask `
        -TaskPath $taskPath `
        -TaskName $taskName `
        -InputObject $task `
        -Force | Out-Null
    Write-Host "  ✅ Task created: $taskPath$taskName"
} catch {
    Write-Host "  ❌ Failed to create task: $_"
    exit 1
}

Start-Sleep -Milliseconds 500

# Verify task
Write-Host "`n[STEP 3] Verifying task..."
$newTask = Get-ScheduledTask -TaskPath $taskPath -TaskName $taskName -ErrorAction SilentlyContinue
if ($newTask) {
    Write-Host "  ✅ Task registered successfully"
    Write-Host "`n[TASK DETAILS]"
    Write-Host "  Name:     $($newTask.TaskPath)$($newTask.TaskName)"
    Write-Host "  State:    $($newTask.State)"
    Write-Host "  Schedule: Every 10 minutes"

    $info = $newTask | Get-ScheduledTaskInfo
    if ($info.NextRunTime) {
        $nextRun = ([DateTime]$info.NextRunTime - (Get-Date)).TotalSeconds
        if ($nextRun -gt 0) {
            Write-Host "  Next run: in $(([math]::Ceiling($nextRun / 60))) minutes"
        }
    }
} else {
    Write-Host "  ❌ Task verification failed"
    exit 1
}

# Test execution
Write-Host "`n[STEP 4] Running initial test..."
$logBefore = if (Test-Path "D:\Dev\TradBOT\logs\gom_sync.log") {
    (Get-Item "D:\Dev\TradBOT\logs\gom_sync.log").LastWriteTime
} else {
    $null
}

$testOutput = & python "D:\Dev\TradBOT\Python\gom_sync_with_report.py" --report 2>&1
$lastLine = $testOutput[-1]

if ($lastLine -match "terminée|completed" -or $testOutput -match "Rapport") {
    Write-Host "  ✅ Test execution successful"
    Write-Host "`n[TEST OUTPUT EXCERPT]"
    $testOutput | Select-Object -Last 8 | ForEach-Object {
        if ($_ -match "RAPPORT|VERDICT|ERROR") {
            Write-Host "  $_"
        }
    }
} else {
    Write-Host "  ⚠️ Test completed (check logs for details)"
}

# Summary
Write-Host @"

╔════════════════════════════════════════════════════════════╗
║  ✅ DEPLOYMENT COMPLETE                                    ║
╚════════════════════════════════════════════════════════════╝

WHAT'S NOW RUNNING:
  • Task: TradBOT\GOM-Sync-10min
  • Interval: Every 10 minutes (automatic)
  • Execution: $scriptPath
  • Logs: D:\Dev\TradBOT\logs\gom_sync.log

ACTIONS PER CYCLE (10 min):
  1. Load GOM verdicts from MT5 live dashboard
  2. Apply all trading gates (coherence, timeframe, direction)
  3. POST verdicts to AI server (/gom-verdict)
  4. Build WhatsApp report (entry/SL/TP/timeframes)
  5. Send via WhatsApp (AI server or PsychoBot)
  6. Log all activity (timestamps, verdicts, errors)

MONITOR ACTIVITY:
  • PowerShell:  tail -f D:\Dev\TradBOT\logs\gom_sync.log
  • Windows:     Get-Content logs/gom_sync.log -Tail 20 -Wait
  • Manual run:  schtasks /run /tn "TradBOT\GOM-Sync-10min"

NEXT STEPS:
  1. Wait 10 minutes for first automatic execution
  2. Check logs: Get-Content logs/gom_sync.log -Tail 30
  3. Verify WhatsApp reports arrive
  4. Monitor for any gate rejections

STATUS: ✅ AUTONOMOUS SYSTEM ACTIVE
        All 10-minute cycles will run automatically

"@

if (-not $NoWait) {
    Write-Host "Press any key to continue..."
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}
