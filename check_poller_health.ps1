# Check Master GOM Poller Health Status
# À exécuter régulièrement pour vérifier que le poller tourne

$taskName = "TradBOT-Master-GOM-Poller"

$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] ❌ Task not found!" -ForegroundColor Red
    exit 1
}

$state = $task.State
$lastRun = $task.LastRunTime
$lastResult = $task.LastTaskResult

Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] ======================================================================" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] MASTER GOM POLLER - HEALTH CHECK" -ForegroundColor Cyan
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] ======================================================================" -ForegroundColor Cyan
Write-Host ""

# État de la tâche
if ($state -eq "Ready") {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] ✅ Task State: $state (enabled)" -ForegroundColor Green
} elseif ($state -eq "Running") {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] 🔄 Task State: $state (actively running)" -ForegroundColor Yellow
} else {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] ⚠️ Task State: $state" -ForegroundColor Yellow
}

Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] Last Run: $lastRun" -ForegroundColor White
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] Last Result: $lastResult" -ForegroundColor White

# Vérifier le process Python
$pythonProcess = Get-Process python -ErrorAction SilentlyContinue | Where-Object { $_.StartTime -ge (Get-Date).AddHours(-24) } | Select-Object -First 1
if ($pythonProcess) {
    $uptime = (Get-Date) - $pythonProcess.StartTime
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] ✅ Python Process: PID $($pythonProcess.Id), Uptime: $([int]$uptime.TotalMinutes)m" -ForegroundColor Green
} else {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] ⚠️ Python Process: Not found (may have just restarted)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Health] ✅ Health check complete" -ForegroundColor Green
