# Script PowerShell pour démarrer le serveur IA TradBOT avec venv
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Démarrage du Serveur IA TradBOT" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

cd 'D:\Dev\TradBOT'

# Vérifier si l'environnement virtuel existe
$venvPython = ".\venv\Scripts\python.exe"
if (-not (Test-Path $venvPython)) {
    Write-Host "❌ Environnement virtuel venv non trouvé!" -ForegroundColor Red
    Write-Host "💡 Créez-le avec:" -ForegroundColor Yellow
    Write-Host "   python -m venv venv" -ForegroundColor White
    Write-Host "   venv\Scripts\activate" -ForegroundColor White
    Write-Host "   pip install fastapi uvicorn pandas numpy requests joblib" -ForegroundColor White
    Write-Host ""
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}

Write-Host "✅ Environnement virtuel trouvé" -ForegroundColor Green
Write-Host "🚀 Démarrage du serveur IA..." -ForegroundColor Yellow
Write-Host ""

# Lancer le serveur avec l'environnement virtuel
try {
    & $venvPython ai_server.py
} catch {
    Write-Host "❌ Erreur lors du démarrage du serveur:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ""
Write-Host "🛑 Serveur IA arrêté" -ForegroundColor Yellow
Read-Host "Appuyez sur Entrée pour quitter"

