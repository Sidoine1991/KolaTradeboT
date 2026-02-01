# Script PowerShell pour entraîner et uploader les modèles ML
# Ce script lance le script Python d'entraînement

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🤖 TRADBOT ML - TRAINING & UPLOAD" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Vérifier si Python est disponible
try {
    $pythonVersion = python --version 2>$null
    Write-Host "✅ Python trouvé: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python non trouvé. Veuillez installer Python 3.8+" -ForegroundColor Red
    exit 1
}

# Vérifier si nous sommes dans le bon répertoire
if (-not (Test-Path "ai_server.py")) {
    Write-Host "❌ ai_server.py non trouvé. Veuillez exécuter ce script depuis le répertoire racine de TradBOT." -ForegroundColor Red
    exit 1
}

Write-Host "✅ Fichier ai_server.py trouvé" -ForegroundColor Green

# Activer l'environnement virtuel si disponible
if (Test-Path ".venv\Scripts\Activate.ps1") {
    Write-Host "🔄 Activation de l'environnement virtuel..." -ForegroundColor Yellow
    & .\.venv\Scripts\Activate.ps1
    Write-Host "✅ Environnement virtuel activé" -ForegroundColor Green
}

# Vérifier les dépendances
Write-Host "🔍 Vérification des dépendances..." -ForegroundColor Yellow

$requiredPackages = @(
    "requests",
    "pandas",
    "numpy",
    "scikit-learn",
    "MetaTrader5",
    "joblib"
)

foreach ($package in $requiredPackages) {
    try {
        pip show $package >$null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host "   ✅ $package" -ForegroundColor Green
        } else {
            Write-Host "   ❌ $package (manquant)" -ForegroundColor Red
            Write-Host "📦 Installation de $package..." -ForegroundColor Yellow
            pip install $package
        }
    } catch {
        Write-Host "   ❌ Erreur vérification $package" -ForegroundColor Red
    }
}

# Vérifier la connexion MT5
Write-Host "`n🔌 Vérification de la connexion MT5..." -ForegroundColor Yellow
try {
    $mt5Test = python -c "import MetaTrader5 as mt5; print('MT5 module disponible')" 2>&1
    if ($mt5Test -like "*MT5 module disponible*") {
        Write-Host "✅ Module MetaTrader5 disponible" -ForegroundColor Green
    } else {
        Write-Host "❌ Module MetaTrader5 non disponible" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Erreur vérification MT5" -ForegroundColor Red
}

# Vérifier la connexion au serveur Render
Write-Host "`n🌐 Vérification de la connexion au serveur Render..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "https://kolatradebot.onrender.com/health" -TimeoutSec 10
    Write-Host "✅ Serveur Render accessible" -ForegroundColor Green
    Write-Host "   Status: $($response.status)" -ForegroundColor Cyan
    Write-Host "   MT5 initialisé: $($response.mt5_initialized)" -ForegroundColor Cyan
    Write-Host "   yfinance disponible: $($response.yfinance_available)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Serveur Render inaccessible" -ForegroundColor Red
    Write-Host "   Erreur: $($_.Exception.Message)" -ForegroundColor Red
}

# Demander confirmation
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "🚀 LANCEMENT DE L'ENTRAÎNEMENT ET UPLOAD" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan
Write-Host "Ce script va:" -ForegroundColor White
Write-Host "  1. Détecter automatiquement les symboles ouverts dans MT5" -ForegroundColor White
Write-Host "  2. Détecter les robots actifs sur les graphiques" -ForegroundColor White
Write-Host "  3. Entraîner les modèles ML localement avec MT5" -ForegroundColor White
Write-Host "  4. Uploader les modèles sur le serveur Render" -ForegroundColor White
Write-Host "" -ForegroundColor White
Write-Host "Les symboles seront détectés automatiquement depuis vos graphiques MT5" -ForegroundColor Cyan
Write-Host "Si aucun graphique n'est ouvert, les symboles par défaut seront utilisés" -ForegroundColor Gray
Write-Host ""

$confirmation = Read-Host "Voulez-vous continuer? (O/N)"
if ($confirmation -notmatch "^[OoYy]") {
    Write-Host "❌ Annulé par l'utilisateur" -ForegroundColor Red
    exit 0
}

# Lancer le script Python
Write-Host "`n🤖 Lancement de l'entraînement..." -ForegroundColor Green
Write-Host "Cela peut prendre plusieurs minutes..." -ForegroundColor Yellow

try {
    python train_and_upload_models.py
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n🎉 SUCCÈS! Tous les modèles ont été entraînés et uploadés." -ForegroundColor Green
        Write-Host "Le serveur Render peut maintenant utiliser ces modèles." -ForegroundColor Cyan
    } else {
        Write-Host "`n❌ ERREUR lors de l'exécution" -ForegroundColor Red
        Write-Host "Vérifiez les logs ci-dessus pour plus de détails." -ForegroundColor Yellow
    }
} catch {
    Write-Host "`n❌ Erreur lors de l'exécution du script" -ForegroundColor Red
    Write-Host "Erreur: $($_.Exception.Message)" -ForegroundColor Red
}

# Afficher les logs si disponibles
$logFile = Get-ChildItem -Path "training_upload_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($logFile) {
    Write-Host "`n📄 Dernier fichier de log: $($logFile.Name)" -ForegroundColor Cyan
    Write-Host "Pour voir les logs complets:" -ForegroundColor Yellow
    Write-Host "Get-Content '$($logFile.FullName)' | Select-Object -Last 50" -ForegroundColor Gray
}

Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "✨ TERMINÉ" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan
