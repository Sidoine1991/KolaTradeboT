# Script PowerShell pour démarrer le serveur IA TradBOT (endpoints MT5) avec venv
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Démarrage Serveur IA TradBOT (MT5 API)" -ForegroundColor Cyan
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
    Write-Host "   pip install -r requirements-local.txt" -ForegroundColor White
    Write-Host ""
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}

Write-Host "✅ Environnement virtuel trouvé" -ForegroundColor Green
Write-Host "🚀 Démarrage du serveur IA MT5 API..." -ForegroundColor Yellow
Write-Host ""

try {
    & $venvPython ai_server_supabase.py
} catch {
    Write-Host "❌ Erreur lors du démarrage du serveur:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

Write-Host ""
Write-Host "🛑 Serveur IA arrêté" -ForegroundColor Yellow
Read-Host "Appuyez sur Entrée pour quitter"

