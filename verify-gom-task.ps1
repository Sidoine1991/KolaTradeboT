# Verify GOM Sync Task Status
# Run this script to check if the task is properly configured and running

param(
    [switch]$Fix,
    [switch]$RunNow
)

$TaskPath = "\TradBOT\"
$TaskName = "TradBOT-GOM-Sync-10min"

Write-Host "`n========================================`n"
Write-Host "GOM SYNC TASK VERIFICATION`n"

# Check if task exists
Write-Host "[CHECK 1] Task exists..."
$task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName -ErrorAction SilentlyContinue

if ($null -eq $task) {
    Write-Host "❌ Task not found at $TaskPath$TaskName"
    if ($Fix) {
        Write-Host "[FIX] Running setup..."
        & "D:\Dev\TradBOT\scripts\setup-gom-task.ps1"
        $task = Get-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
    } else {
        Write-Host "`nTo fix: Run with -Fix flag or execute:"
        Write-Host "  .\scripts\setup-gom-task.ps1"
        exit 1
    }
} else {
    Write-Host "✅ Task found: $TaskPath$TaskName"
}

# Check task status
Write-Host "`n[CHECK 2] Task state..."
Write-Host "State: $($task.State)"

# Get task info
Write-Host "`n[CHECK 3] Task schedule..."
$info = $task | Get-ScheduledTaskInfo
Write-Host "Last run: $($info.LastRunTime)"
Write-Host "Last result: $($info.LastTaskResult)"
Write-Host "Next run: $($info.NextRunTime)"

# Check if next run is within 15 minutes
$nextRun = $info.NextRunTime
if ($null -ne $nextRun) {
    $timeUntilRun = ($nextRun - (Get-Date)).TotalMinutes
    if ($timeUntilRun -lt 0) {
        Write-Host "⚠️ Next run is in the past (task may be misconfigured)"
    } else {
        Write-Host "Next run in: $(([math]::Ceiling($timeUntilRun))) minutes"
    }
}

# Check exit code
Write-Host "`n[CHECK 4] Last result code..."
if ($info.LastTaskResult -eq 0) {
    Write-Host "✅ Last execution successful (code 0)"
} elseif ($info.LastTaskResult -eq 2147942402) {
    Write-Host "❌ File access error (code 2147942402)"
    Write-Host "    This usually means the batch file path is incorrect"
    if ($Fix) {
        Write-Host "`n[FIX] Reconfiguring task..."
        & "D:\Dev\TradBOT\scripts\setup-gom-task.ps1" -Uninstall
        Start-Sleep -Seconds 2
        & "D:\Dev\TradBOT\scripts\setup-gom-task.ps1"
        Write-Host "✅ Task reconfigured"
    }
} else {
    Write-Host "⚠️ Last result code: $($info.LastTaskResult)"
}

# Test Python/script
Write-Host "`n[CHECK 5] Script accessibility..."
$scriptPath = "D:\Dev\TradBOT\Python\gom_sync_with_report.py"
if (Test-Path $scriptPath) {
    Write-Host "✅ Script found: $scriptPath"
} else {
    Write-Host "❌ Script not found: $scriptPath"
    exit 1
}

$batchPath = "D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat"
if (Test-Path $batchPath) {
    Write-Host "✅ Wrapper found: $batchPath"
} else {
    Write-Host "❌ Wrapper not found: $batchPath"
    exit 1
}

# Check logs
Write-Host "`n[CHECK 6] Recent logs..."
$logPath = "D:\Dev\TradBOT\logs\gom_sync.log"
if (Test-Path $logPath) {
    Write-Host "✅ Log file exists: $logPath"
    Write-Host ""
    Write-Host "Last 3 entries:"
    Get-Content $logPath -Tail 3 | ForEach-Object {
        if ($_ -match "\[ERROR\]") {
            Write-Host "❌ $_" -ForegroundColor Red
        } elseif ($_ -match "✅") {
            Write-Host "✅ $_" -ForegroundColor Green
        } else {
            Write-Host "  $_"
        }
    }
} else {
    Write-Host "⚠️ Log file not found yet (will be created on first run)"
}

# Run now option
if ($RunNow) {
    Write-Host "`n[MANUAL RUN] Executing immediately..."
    & Start-ScheduledTask -TaskPath $TaskPath -TaskName $TaskName
    Write-Host "✅ Task triggered"
    Write-Host "Check logs in 30 seconds..."
}

Write-Host "`n========================================`n"
Write-Host "✅ VERIFICATION COMPLETE`n"

if ($null -ne $task -and $task.State -eq "Ready") {
    Write-Host "Status: Task is configured and ready"
} else {
    Write-Host "Status: Issues detected (use -Fix to resolve)"
}

Write-Host "`nUsage:`n"
Write-Host "  .\verify-gom-task.ps1          # Check status"
Write-Host "  .\verify-gom-task.ps1 -Fix     # Fix issues"
Write-Host "  .\verify-gom-task.ps1 -RunNow  # Execute immediately`n"
