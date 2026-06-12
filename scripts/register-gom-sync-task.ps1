# register-gom-sync-task.ps1
# Enregistre une tâche Windows planifiée pour lancer GOM Sync toutes les 10 minutes

# Définir les paramètres de la tâche
$taskName = "TradBOT-GOM-Sync-10min"
$taskDescription = "TradBOT: Sync GOM verdicts and send WhatsApp report every 10 minutes"
$taskPath = "\TradBOT\"
$scriptPath = "D:\Dev\TradBOT\Python\gom_sync_with_report.py"
$logPath = "D:\Dev\TradBOT\logs\gom_sync_task.log"

# Créer le répertoire s'il n'existe pas
$logDir = Split-Path -Parent $logPath
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Créer l'action de la tâche
$action = New-ScheduledTaskAction -Execute "python" `
    -Argument "`"$scriptPath`" --report" `
    -WorkingDirectory "D:\Dev\TradBOT"

# Créer le trigger: toutes les 10 minutes
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes 10)

# Créer les paramètres d'exécution
$settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable `
    -DontStopIfGoingOnBatteries `
    -AllowStartIfOnBatteries

# Enregistrer la tâche
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive -RunLevel Highest

try {
    # Vérifier si la tâche existe déjà
    $existingTask = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue

    if ($existingTask) {
        Write-Host "⚠️  Tâche existante trouvée: $taskName" -ForegroundColor Yellow
        Write-Host "Suppression de la tâche ancienne..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false
        Write-Host "✅ Tâche supprimée" -ForegroundColor Green
    }

    # Enregistrer la nouvelle tâche
    Write-Host "📌 Enregistrement de la tâche planifiée..." -ForegroundColor Cyan
    Register-ScheduledTask -TaskName $taskName `
        -TaskPath $taskPath `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description $taskDescription `
        -Force | Out-Null

    Write-Host "✅ Tâche enregistrée avec succès!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Détails de la tâche:" -ForegroundColor Green
    Write-Host "  Nom: $taskName" -ForegroundColor Green
    Write-Host "  Chemin: $taskPath" -ForegroundColor Green
    Write-Host "  Fréquence: Toutes les 10 minutes" -ForegroundColor Green
    Write-Host "  Script: $scriptPath" -ForegroundColor Green
    Write-Host "  Logs: $logPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "✅ La tâche tournera en arrière-plan 24/7" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 Pour vérifier le statut:" -ForegroundColor Cyan
    Write-Host "   Get-ScheduledTask -TaskName '$taskName'" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "💡 Pour supprimer la tâche:" -ForegroundColor Cyan
    Write-Host "   Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false" -ForegroundColor Cyan
    Write-Host ""

} catch {
    Write-Host "❌ Erreur lors de l'enregistrement de la tâche:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
