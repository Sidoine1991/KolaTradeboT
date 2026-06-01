# Career-Ops + PsychoBot Integration Setup
# Envoie automatiquement les rapports et lettres de motivation via WhatsApp

Write-Host "╔════════════════════════════════════════════════════════════════╗"
Write-Host "║  CAREER-OPS + PSYCHOBOT WHATSAPP INTEGRATION SETUP           ║"
Write-Host "║  Automated daily job prospection reports                     ║"
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$projectRoot = "D:\Dev\TradBOT"
$aiServerPath = "$projectRoot\ai_server.py"
$automationScript = "$projectRoot\career_ops_whatsapp_automation.py"

Write-Host "`n[1/3] Checking files..." -ForegroundColor Yellow

if (-Not (Test-Path $aiServerPath)) {
    Write-Host "[ERROR] ai_server.py not found at $aiServerPath" -ForegroundColor Red
    exit 1
}

if (-Not (Test-Path $automationScript)) {
    Write-Host "[ERROR] career_ops_whatsapp_automation.py not found" -ForegroundColor Red
    exit 1
}

Write-Host "[OK] Files verified" -ForegroundColor Green

# Read ai_server.py
Write-Host "`n[2/3] Reading ai_server.py..." -ForegroundColor Yellow
$aiServerContent = Get-Content $aiServerPath -Raw

# Check if already integrated
if ($aiServerContent -like "*career_ops_psychobot_bridge*") {
    Write-Host "[OK] Career-Ops already integrated in ai_server.py" -ForegroundColor Green
} else {
    Write-Host "[INFO] Will add Career-Ops router to ai_server.py" -ForegroundColor Cyan
    Write-Host "`nManual Integration Required:" -ForegroundColor Yellow
    Write-Host "`nAdd these lines to ai_server.py (after other imports):`n" -ForegroundColor White

    $code = @"
from career_ops_psychobot_bridge import router as careerops_router

# Then add this line in the app setup section (after other routers):
app.include_router(careerops_router, prefix="/api")
"@

    Write-Host $code -ForegroundColor Cyan
    Write-Host "`n[ACTION] Please add these lines manually to ai_server.py" -ForegroundColor Yellow
}

# Setup Windows Task Scheduler
Write-Host "`n[3/3] Setting up Windows Task Scheduler..." -ForegroundColor Yellow

$taskName = "CareerOps_DailyWhatsApp"
$taskExists = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if ($taskExists) {
    Write-Host "[INFO] Task '$taskName' already exists" -ForegroundColor Yellow
    Write-Host "[ACTION] Removing old task..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Create task
$action = New-ScheduledTaskAction `
    -Execute "python" `
    -Argument "$automationScript"

$trigger = New-ScheduledTaskTrigger `
    -Daily `
    -At 06:00:00

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
    -Description "Career-Ops: Daily job prospection report + motivation letter via WhatsApp"

Register-ScheduledTask -TaskName $taskName -InputObject $task -Force | Out-Null

Write-Host "[OK] Task scheduled: '$taskName' at 06:00 WAT daily" -ForegroundColor Green

# Verify
$verifyTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($verifyTask) {
    Write-Host "[OK] Task verified in Windows Task Scheduler" -ForegroundColor Green
    Write-Host "     Status: $($verifyTask.State)" -ForegroundColor Cyan
    Write-Host "     Trigger: Daily at 06:00:00" -ForegroundColor Cyan
} else {
    Write-Host "[ERROR] Task verification failed" -ForegroundColor Red
}

# Setup environment check
Write-Host "`n[ENV CHECK] Verifying environment variables..." -ForegroundColor Yellow

$envVars = @(
    "PSYCHOBOT_URL",
    "WHATSAPP_PHONE",
    "EMAIL_ADDRESS",
    "DATABASE_URL"
)

foreach ($var in $envVars) {
    $value = [System.Environment]::GetEnvironmentVariable($var, [System.EnvironmentVariableTarget]::User)
    if ($value) {
        $shortVal = if ($value.Length -gt 40) { $value.Substring(0, 37) + "..." } else { $value }
        Write-Host "[OK] $var = $shortVal" -ForegroundColor Green
    } else {
        Write-Host "[WARNING] $var not set" -ForegroundColor Yellow
    }
}

# Summary
Write-Host "`n╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║  SETUP COMPLETE!                                             ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Green

Write-Host "`n[✓] Career-Ops WhatsApp automation is ready!" -ForegroundColor Green
Write-Host "`n📋 NEXT STEPS:" -ForegroundColor Cyan
Write-Host "  1. Manually add Career-Ops router to ai_server.py (see above)" -ForegroundColor White
Write-Host "  2. Restart ai_server.py: python ai_server.py" -ForegroundColor White
Write-Host "  3. Verify PsychoBot is online: https://psychobot-1si7.onrender.com" -ForegroundColor White
Write-Host "  4. Tomorrow at 06:00 WAT, you'll receive the first report!" -ForegroundColor White

Write-Host "`n📊 AUTOMATION DETAILS:" -ForegroundColor Cyan
Write-Host "  Task Name: $taskName" -ForegroundColor White
Write-Host "  Schedule: Daily @ 06:00 WAT" -ForegroundColor White
Write-Host "  Script: $automationScript" -ForegroundColor White
Write-Host "  Deliverables:" -ForegroundColor White
Write-Host "    • Career-Ops prospection report (Word)" -ForegroundColor White
Write-Host "    • Motivation letter for best match (Word)" -ForegroundColor White
Write-Host "    • WhatsApp message with summary" -ForegroundColor White

Write-Host "`n🚀 Ready to automate career prospection!" -ForegroundColor Green
Write-Host ""
