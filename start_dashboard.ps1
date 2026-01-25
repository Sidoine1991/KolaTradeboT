# Script de démarrage pour le Dashboard Trading IA
# Auteur: TradBOT Team
# Date: 2026-01-25

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🤖 TRADING IA DASHBOARD LAUNCHER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Vérifier Python
try {
    $pythonVersion = python --version 2>&1
    Write-Host "✅ Python trouvé: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python non trouvé. Veuillez installer Python 3.8+" -ForegroundColor Red
    exit 1
}

# Vérifier les dépendances
Write-Host "📦 Vérification des dépendances..." -ForegroundColor Yellow

$requiredPackages = @("requests", "MetaTrader5")
foreach ($package in $requiredPackages) {
    try {
        pip show $package >$null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "✅ $package installé" -ForegroundColor Green
        } else {
            Write-Host "⚠️ Installation de $package..." -ForegroundColor Yellow
            pip install $package
        }
    } catch {
        Write-Host "❌ Erreur lors de l'installation de $package" -ForegroundColor Red
    }
}

# Vérifier MT5
try {
    Add-Type -Path "C:\Program Files\MetaTrader 5\terminal64.exe" -ErrorAction SilentlyContinue
    Write-Host "✅ MetaTrader 5 détecté" -ForegroundColor Green
} catch {
    Write-Host "⚠️ MetaTrader 5 non détecté. Assurez-vous que MT5 est installé." -ForegroundColor Yellow
}

# Démarrer le dashboard
Write-Host "🚀 Démarrage du dashboard..." -ForegroundColor Green
Write-Host "📊 Dashboard: http://localhost:8080 (si disponible)" -ForegroundColor Cyan
Write-Host "🔄 Mise à jour toutes les 5 secondes" -ForegroundColor Cyan
Write-Host "❌ Fermez la fenêtre pour arrêter" -ForegroundColor Red
Write-Host ""

try {
    python dashboard.py
} catch {
    Write-Host "❌ Erreur lors du démarrage du dashboard: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Dépannage:" -ForegroundColor Yellow
    Write-Host "1. Vérifiez que Python est installé" -ForegroundColor White
    Write-Host "2. Vérifiez les dépendances: pip install requests MetaTrader5" -ForegroundColor White
    Write-Host "3. Assurez-vous que MT5 est en cours d'exécution" -ForegroundColor White
}

Write-Host ""
Write-Host "Dashboard fermé. Au revoir !" -ForegroundColor Cyan
