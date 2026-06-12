# setup-gom-sync-task-simple.ps1
# Enregistre une tâche Windows planifiée plus simplement

$taskName = "TradBOT-GOM-Sync-10min"
$taskPath = "\TradBOT\"
$scriptPath = "D:\Dev\TradBOT\Python\gom_sync_with_report.py"

Write-Host ""
Write-Host "📌 Enregistrement de la tâche planifiée..." -ForegroundColor Cyan
Write-Host ""

# Créer l'action: exécute python avec le script
$action = New-ScheduledTaskAction `
    -Execute "python.exe" `
    -Argument "`"$scriptPath`" --report" `
    -WorkingDirectory "D:\Dev\TradBOT"

# Créer le trigger: toutes les 10 minutes
$trigger = New-ScheduledTaskTrigger `
    -Once `
    -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 10)

# Settings pour le comportement
$settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable

# Principal: user courant avec privilèges élevés
$principal = New-ScheduledTaskPrincipal `
    -UserId "$env:USERDOMAIN\$env:USERNAME" `
    -LogonType Interactive `
    -RunLevel Highest

try {
    # Vérifier si la tâche existe
    $existing = Get-ScheduledTask -TaskName $taskName -TaskPath $taskPath -ErrorAction SilentlyContinue

    if ($existing) {
        Write-Host "⚠️  Tâche existante trouvée: $taskName" -ForegroundColor Yellow
        Write-Host "Suppression..." -ForegroundColor Yellow
        Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false | Out-Null
        Write-Host "✅ Supprimée" -ForegroundColor Green
        Start-Sleep -Seconds 1
    }

    # Enregistrer la tâche
    Register-ScheduledTask `
        -TaskName $taskName `
        -TaskPath $taskPath `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "TradBOT: GOM Sync every 10 minutes + WhatsApp report" `
        -Force | Out-Null

    Write-Host "✅ Tâche enregistrée avec succès!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📊 Détails de la tâche:" -ForegroundColor Green
    Write-Host "  Nom: $taskName" -ForegroundColor Green
    Write-Host "  Chemin: $taskPath" -ForegroundColor Green
    Write-Host "  Fréquence: Toutes les 10 minutes" -ForegroundColor Green
    Write-Host "  Prochaine exécution: Dans ~10 minutes" -ForegroundColor Green
    Write-Host "  Script: $scriptPath" -ForegroundColor Green
    Write-Host "  Logs: D:\Dev\TradBOT\logs\gom_sync_task.log" -ForegroundColor Green
    Write-Host ""
    Write-Host "🎯 La tâche tournera en arrière-plan 24/7" -ForegroundColor Green
    Write-Host ""
    Write-Host "💡 Commandes utiles:" -ForegroundColor Cyan
    Write-Host "  Vérifier:" -ForegroundColor Cyan
    Write-Host "    Get-ScheduledTask -TaskName '$taskName'" -ForegroundColor Cyan
    Write-Host "  Supprimer:" -ForegroundColor Cyan
    Write-Host "    Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false" -ForegroundColor Cyan
    Write-Host "  Exécuter maintenant:" -ForegroundColor Cyan
    Write-Host "    Start-ScheduledTask -TaskName '$taskName'" -ForegroundColor Cyan
    Write-Host ""

} catch {
    Write-Host "❌ Erreur: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
