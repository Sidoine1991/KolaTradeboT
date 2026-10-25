# Script PowerShell pour lancer l'API de tendance
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    LANCEMENT API TREND POUR SCALPING" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Démarrage de l'API de tendance sur le port 8001..." -ForegroundColor Green
Write-Host "Cette API fournit les données de tendance pour le scalping automatique." -ForegroundColor Yellow
Write-Host ""
Write-Host "Appuyez sur Ctrl+C pour arrêter l'API" -ForegroundColor Red
Write-Host ""

# Changer vers le répertoire du projet
Set-Location "D:\Dev\TradBOT"

# Activer l'environnement virtuel si disponible
if (Test-Path ".venv\Scripts\Activate.ps1") {
    Write-Host "Activation de l'environnement virtuel..." -ForegroundColor Blue
    & .\.venv\Scripts\Activate.ps1
}

# Lancer l'API
Write-Host "Lancement de l'API de tendance..." -ForegroundColor Green
python trend_api.py
