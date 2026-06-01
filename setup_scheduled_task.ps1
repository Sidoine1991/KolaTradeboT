# Setup Windows Scheduled Task pour Master GOM Poller
# À exécuter en tant qu'Administrateur

$taskName = "TradBOT-Master-GOM-Poller"
$runnerScript = "D:\Dev\TradBOT\master_gom_poller_runner.ps1"
$pythonExe = "python"

# Vérifier si la tâche existe déjà et la supprimer
$existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Setup] ⚠️ Task already exists. Removing..." -ForegroundColor Yellow
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
}

# Créer une nouvelle tâche
$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$runnerScript`""

$trigger = New-ScheduledTaskTrigger -AtStartup

$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -RunOnlyIfNetworkAvailable

$task = Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Settings $settings `
    -Description "Master GOM Poller - Autonomous data collection with auto-restart"

Write-Host ""
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Setup] ✅ Scheduled task created successfully!" -ForegroundColor Green
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Setup] Task Name: $taskName" -ForegroundColor Green
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Setup] Trigger: On System Startup" -ForegroundColor Green
Write-Host "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [Setup] Runner: $runnerScript" -ForegroundColor Green
Write-Host ""
Write-Host "🔧 To start the task immediately, run:" -ForegroundColor Cyan
Write-Host "   Start-ScheduledTask -TaskName `"$taskName`"" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 To view the task, run:" -ForegroundColor Cyan
Write-Host "   Get-ScheduledTask -TaskName `"$taskName`"" -ForegroundColor Cyan
Write-Host ""
Write-Host "🗑️ To remove the task, run:" -ForegroundColor Cyan
Write-Host "   Unregister-ScheduledTask -TaskName `"$taskName`" -Confirm:`$false" -ForegroundColor Cyan
