# TradBOT - Graphique Temps Réel
# Script PowerShell pour lancer l'application

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    TradBOT - Graphique Temps Réel" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier si Python est disponible
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✅ Python détecté: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ ERREUR: Python n'est pas installé ou pas dans le PATH" -ForegroundColor Red
    Read-Host "Appuyez sur Entrée pour quitter"
    exit 1
}

# Activer l'environnement virtuel si il existe
if (Test-Path "venv\Scripts\Activate.ps1") {
    Write-Host "🔄 Activation de l'environnement virtuel..." -ForegroundColor Yellow
    & "venv\Scripts\Activate.ps1"
}

Write-Host ""
Write-Host "🚀 Lancement de l'application de graphique temps réel..." -ForegroundColor Green
Write-Host "📊 L'application va s'ouvrir dans votre navigateur" -ForegroundColor Blue
Write-Host "⏹️  Appuyez sur Ctrl+C pour arrêter l'application" -ForegroundColor Yellow
Write-Host ""

# Lancer l'application Streamlit
try {
    streamlit run frontend/app_realtime_chart.py --server.port 8501 --server.address localhost
} catch {
    Write-Host "❌ Erreur lors du lancement de Streamlit" -ForegroundColor Red
    Write-Host "Vérifiez que Streamlit est installé: pip install streamlit" -ForegroundColor Yellow
}

Read-Host "Appuyez sur Entrée pour quitter"
