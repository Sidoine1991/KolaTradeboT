# Simple GOM Sync Task Installation (Run as Administrator)
# RUN THIS: Right-click PowerShell → Run as Administrator, then paste:
# cd D:\Dev\TradBOT; .\install-gom-task-simple.ps1

Write-Host "`n[INSTALL] GOM Sync 10-Minute Task" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Green

# Check admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "❌ ERROR: Run as Administrator" -ForegroundColor Red
    exit 1
}

Write-Host "✅ Admin privileges detected`n" -ForegroundColor Green

# Delete old task
Write-Host "[STEP 1] Removing old task..."
Unregister-ScheduledTask -TaskPath "\TradBOT\" -TaskName "TradBOT-GOM-Sync-10min" -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500

# Create trigger
Write-Host "[STEP 2] Creating 10-minute trigger..."
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10) -RepetitionDuration (New-TimeSpan -Hours 23 -Minutes 50)

# Create action
Write-Host "[STEP 3] Creating action..."
$action = New-ScheduledTaskAction `
    -Execute "D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat" `
    -WorkingDirectory "D:\Dev\TradBOT"

# Create settings
Write-Host "[STEP 4] Creating settings..."
$settings = New-ScheduledTaskSettingsSet `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 5) `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable

# Register task
Write-Host "[STEP 5] Registering task...`n"
Register-ScheduledTask `
    -TaskName "TradBOT-GOM-Sync-10min" `
    -TaskPath "\TradBOT\" `
    -Trigger $trigger `
    -Action $action `
    -Settings $settings `
    -Force | Out-Null

Write-Host "✅ Task created successfully`n" -ForegroundColor Green
Write-Host "Details:" -ForegroundColor Green
Get-ScheduledTask -TaskPath "\TradBOT\" -TaskName "TradBOT-GOM-Sync-10min" | Select-Object TaskName, State

Write-Host "`n✅ Installation complete" -ForegroundColor Green
Write-Host "Task will run every 10 minutes starting now`n" -ForegroundColor Green
