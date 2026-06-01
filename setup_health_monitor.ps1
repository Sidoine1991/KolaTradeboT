# Setup Health Monitor Task - Vérifie la santé du poller toutes les heures

$monitorTaskName = "TradBOT-Poller-Health-Monitor"
$healthCheckScript = "D:\Dev\TradBOT\check_poller_health.ps1"
$logFile = "D:\Dev\TradBOT\logs\poller_health.log"

# Créer le dossier logs s'il n'existe pas
$logsDir = Split-Path $logFile
if (-not (Test-Path $logsDir)) {
    New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
}

# Vérifier si la tâche existe déjà
$existingMonitor = Get-ScheduledTask -TaskName $monitorTaskName -ErrorAction SilentlyContinue
if ($existingMonitor) {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Monitor Setup] ⚠️ Monitor task already exists. Removing..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $monitorTaskName -Confirm:$false
}

# Créer la tâche de monitoring
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -File `"$healthCheckScript`" | Add-Content `"$logFile`""

$trigger = New-ScheduledTaskTrigger -Daily -At 00:00 -RepetitionInterval (New-TimeSpan -Hours 1) -RepetitionDuration (New-TimeSpan -Days 365)

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

$task = Register-ScheduledTask `
    -TaskName $monitorTaskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Monitor Master GOM Poller health every hour"

Write-Host ""
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Monitor Setup] ✅ Health Monitor task created!" -ForegroundColor Green
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Monitor Setup] Task Name: $monitorTaskName" -ForegroundColor Green
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Monitor Setup] Frequency: Every 1 hour" -ForegroundColor Green
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Monitor Setup] Log File: $logFile" -ForegroundColor Green
Write-Host ""
