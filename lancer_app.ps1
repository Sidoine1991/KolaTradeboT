# Script PowerShell pour lancer TradBOT Temps Réel
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "    TRADBOT - APPLICATION TEMPS REEL" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Vérifier que Python est installé
try {
    $pythonVersion = python --version
    Write-Host "✅ Python détecté: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python n'est pas installé ou n'est pas dans le PATH" -ForegroundColor Red
    exit 1
}

# Vérifier que Streamlit est installé
try {
    $streamlitVersion = streamlit --version
    Write-Host "✅ Streamlit détecté" -ForegroundColor Green
} catch {
    Write-Host "❌ Streamlit n'est pas installé. Installation en cours..." -ForegroundColor Yellow
    python -m pip install streamlit
}

# Changer vers le répertoire frontend
Set-Location "frontend"

Write-Host ""
Write-Host "🚀 Lancement de l'application temps réel..." -ForegroundColor Green
Write-Host "📱 L'application s'ouvrira dans votre navigateur" -ForegroundColor Yellow
Write-Host "🌐 Adresse: http://localhost:8501" -ForegroundColor Yellow
Write-Host ""

# Lancer l'application
try {
    streamlit run app_real_time.py
} catch {
    Write-Host "❌ Erreur lors du lancement de l'application" -ForegroundColor Red
    Write-Host "Détails: $_" -ForegroundColor Red
    Read-Host "Appuyez sur Entrée pour fermer"
} 