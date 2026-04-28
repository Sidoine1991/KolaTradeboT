# Script PowerShell pour lancer le monitoring automatique des pertes
# Ce script surveille en continu toutes les positions ouvertes et ferme automatiquement
# celles qui dépassent une perte de 3 dollars

Write-Host "================================================================================================" -ForegroundColor Cyan
Write-Host "  PROTECTION AUTOMATIQUE DES PERTES - TradBOT" -ForegroundColor Yellow
Write-Host "================================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ce script surveille en continu vos positions MT5 et ferme automatiquement" -ForegroundColor White
Write-Host "toute position dont la perte depasse 3 dollars." -ForegroundColor White
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Green
Write-Host "  - Perte maximale par trade: 3.00 USD" -ForegroundColor White
Write-Host "  - Verification: toutes les 1 seconde" -ForegroundColor White
Write-Host "  - Reconnexion automatique en cas de deconnexion MT5" -ForegroundColor White
Write-Host ""
Write-Host "================================================================================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier si Python est installé
try {
    $pythonVersion = python --version 2>&1
    Write-Host "Python detecte: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "ERREUR: Python n'est pas installe ou n'est pas dans le PATH" -ForegroundColor Red
    Write-Host "Veuillez installer Python 3.8 ou superieur" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host ""

# Vérifier que le fichier de monitoring existe
$monitorScript = Join-Path $PSScriptRoot "backend\continuous_loss_monitor.py"
if (-not (Test-Path $monitorScript)) {
    Write-Host "ERREUR: Le script de monitoring n'a pas ete trouve:" -ForegroundColor Red
    Write-Host "  $monitorScript" -ForegroundColor Yellow
    pause
    exit 1
}

Write-Host "Script de monitoring trouve: $monitorScript" -ForegroundColor Green
Write-Host ""
Write-Host "================================================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "DEMARRAGE DU MONITORING..." -ForegroundColor Yellow
Write-Host ""
Write-Host "Appuyez sur Ctrl+C pour arreter le monitoring" -ForegroundColor Cyan
Write-Host ""
Write-Host "================================================================================================" -ForegroundColor Cyan
Write-Host ""

# Lancer le script de monitoring
try {
    python $monitorScript
} catch {
    Write-Host ""
    Write-Host "ERREUR lors de l'execution du monitoring:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Yellow
    Write-Host ""
    pause
    exit 1
}

Write-Host ""
Write-Host "================================================================================================" -ForegroundColor Cyan
Write-Host "Monitoring arrete." -ForegroundColor Yellow
Write-Host "================================================================================================" -ForegroundColor Cyan
Write-Host ""
pause
