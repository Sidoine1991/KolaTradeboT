# Script PowerShell pour activer l'environnement virtuel .venv
# Usage: .\activate_venv.ps1

Write-Host "🔍 Recherche de l'environnement virtuel..." -ForegroundColor Yellow

$venvPath = "D:\Dev\TradBOT\.venv"

# Vérifier si le dossier .venv existe
if (-not (Test-Path $venvPath)) {
    Write-Host "❌ L'environnement virtuel n'existe pas à: $venvPath" -ForegroundColor Red
    Write-Host "📋 Création de l'environnement virtuel..." -ForegroundColor Yellow
    
    # Créer l'environnement virtuel
    try {
        python -m venv $venvPath
        Write-Host "✅ Environnement virtuel créé avec succès!" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Erreur lors de la création de l'environnement virtuel" -ForegroundColor Red
        Write-Host "📋 Vérifiez que Python est installé et accessible" -ForegroundColor Yellow
        exit 1
    }
}

# Activer l'environnement virtuel
Write-Host "🚀 Activation de l'environnement virtuel..." -ForegroundColor Yellow

try {
    # Script d'activation pour PowerShell
    $activateScript = Join-Path $venvPath "Scripts\Activate.ps1"
    
    if (Test-Path $activateScript) {
        # Exécuter le script d'activation
        & $activateScript
        
        # Afficher les informations
        Write-Host "✅ Environnement virtuel activé avec succès!" -ForegroundColor Green
        Write-Host "📍 Chemin: $venvPath" -ForegroundColor Cyan
        Write-Host "🐍 Python: $(python --version)" -ForegroundColor Cyan
        Write-Host "📦 Pip: $(pip --version)" -ForegroundColor Cyan
        
        # Afficher les packages installés
        Write-Host "`n📦 Packages installés:" -ForegroundColor Yellow
        pip list
        
        Write-Host "`n🎯 L'environnement est prêt!" -ForegroundColor Green
        Write-Host "💡 Pour désactiver: deactivate" -ForegroundColor Gray
    }
    else {
        Write-Host "❌ Script d'activation non trouvé: $activateScript" -ForegroundColor Red
        exit 1
    }
}
catch {
    Write-Host "❌ Erreur lors de l'activation de l'environnement virtuel" -ForegroundColor Red
    Write-Host "📋 Message d'erreur: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
