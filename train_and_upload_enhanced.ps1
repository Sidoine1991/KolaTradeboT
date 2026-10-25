# Script PowerShell amélioré pour l'entraînement et upload ML
# Ce script combine les fonctionnalités de trigger_ml_training.py et du nouveau système

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🤖 TRADBOT ML - ENHANCED TRAINING" -ForegroundColor Cyan
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

# Menu de sélection du mode
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "🚀 SÉLECTION DU MODE D'ENTRAÎNEMENT" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan
Write-Host "Choisissez le mode d'entraînement:" -ForegroundColor White
Write-Host ""
Write-Host "1. 🤖 NOUVEAU SYSTÈME (recommandé)" -ForegroundColor Green
Write-Host "   - Entraîne les modèles localement avec MT5" -ForegroundColor Gray
Write-Host "   - Upload les modèles pré-entraînés sur Render" -ForegroundColor Gray
Write-Host "   - Plus rapide et plus efficace" -ForegroundColor Gray
Write-Host ""
Write-Host "2. 📡 ANCIEN SYSTÈME (trigger_ml_training.py)" -ForegroundColor Yellow
Write-Host "   - Envoie les données brutes à Render" -ForegroundColor Gray
Write-Host "   - Render entraîne les modèles avec les données" -ForegroundColor Gray
Write-Host "   - Compatible avec l'ancien système" -ForegroundColor Gray
Write-Host ""
Write-Host "3. 🔄 LES DEUX MODES" -ForegroundColor Cyan
Write-Host "   - Exécute les deux systèmes pour comparaison" -ForegroundColor Gray
Write-Host "   - Maximum de compatibilité" -ForegroundColor Gray
Write-Host ""

$choice = Read-Host "Votre choix (1/2/3)"

# Déterminer le mode
$runNew = $false
$runOld = $false

switch ($choice) {
    "1" { 
        $runNew = $true
        Write-Host "✅ Mode sélectionné: NOUVEAU SYSTÈME" -ForegroundColor Green
    }
    "2" { 
        $runOld = $true
        Write-Host "✅ Mode sélectionné: ANCIEN SYSTÈME" -ForegroundColor Yellow
    }
    "3" { 
        $runNew = $true
        $runOld = $true
        Write-Host "✅ Mode sélectionné: LES DEUX MODES" -ForegroundColor Cyan
    }
    default { 
        Write-Host "❌ Choix invalide. Utilisation du nouveau système par défaut." -ForegroundColor Red
        $runNew = $true
    }
}

# Afficher les symboles qui seront traités
Write-Host "`n🔍 Détection des symboles MT5..." -ForegroundColor Yellow
try {
    $symbolsCheck = python -c "
import sys
sys.path.append('.')
from train_and_upload_models import get_symbols_to_train
symbols = get_symbols_to_train()
print(f'Symboles détectés: {[f\"{s} {tf}\" for s, tf in symbols]}')
print(f'Nombre de symboles: {len(symbols)}')
" 2>&1
    Write-Host $symbolsCheck -ForegroundColor Cyan
} catch {
    Write-Host "⚠️ Impossible de détecter les symboles automatiquement" -ForegroundColor Yellow
}

# Demander confirmation
Write-Host "`n" + "="*60 -ForegroundColor Cyan
Write-Host "🚀 LANCEMENT DE L'ENTRAÎNEMENT" -ForegroundColor Cyan
Write-Host "="*60 -ForegroundColor Cyan

if ($runNew -and $runOld) {
    Write-Host "Les deux systèmes vont être exécutés séquentiellement." -ForegroundColor White
} elseif ($runNew) {
    Write-Host "Nouveau système: Entraînement local + upload modèles" -ForegroundColor White
} else {
    Write-Host "Ancien système: Synchronisation des données brutes" -ForegroundColor White
}

Write-Host ""

$confirmation = Read-Host "Voulez-vous continuer? (O/N)"
if ($confirmation -notmatch "^[OoYy]") {
    Write-Host "❌ Annulé par l'utilisateur" -ForegroundColor Red
    exit 0
}

# Exécuter les scripts
$success = $true

if ($runNew) {
    Write-Host "`n🤖 EXÉCUTION DU NOUVEAU SYSTÈME..." -ForegroundColor Green
    Write-Host "Entraînement local + upload des modèles..." -ForegroundColor Yellow
    
    try {
        python train_and_upload_models.py --train-upload
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Erreur lors de l'exécution du nouveau système" -ForegroundColor Red
            $success = $false
        } else {
            Write-Host "✅ Nouveau système terminé avec succès" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Erreur lors de l'exécution du nouveau système" -ForegroundColor Red
        Write-Host "Erreur: $($_.Exception.Message)" -ForegroundColor Red
        $success = $false
    }
}

if ($runOld) {
    if ($runNew) {
        Write-Host "`n⏳ Pause de 5 secondes avant le deuxième système..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
    
    Write-Host "`n📡 EXÉCUTION DE L'ANCIEN SYSTÈME..." -ForegroundColor Yellow
    Write-Host "Synchronisation des données brutes avec Render..." -ForegroundColor Yellow
    
    try {
        python train_and_upload_models.py --sync-only
        
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Erreur lors de l'exécution de l'ancien système" -ForegroundColor Red
            $success = $false
        } else {
            Write-Host "✅ Ancien système terminé avec succès" -ForegroundColor Green
        }
    } catch {
        Write-Host "❌ Erreur lors de l'exécution de l'ancien système" -ForegroundColor Red
        Write-Host "Erreur: $($_.Exception.Message)" -ForegroundColor Red
        $success = $false
    }
}

# Résultat final
Write-Host "`n" + "="*60 -ForegroundColor Cyan
if ($success) {
    Write-Host "🎉 SUCCÈS! Tous les systèmes ont été exécutés." -ForegroundColor Green
    Write-Host "Les modèles sont maintenant disponibles sur Render." -ForegroundColor Cyan
} else {
    Write-Host "⚠️ TERMINÉ AVEC DES ERREURS" -ForegroundColor Yellow
    Write-Host "Vérifiez les logs ci-dessus pour plus de détails." -ForegroundColor Gray
}
Write-Host "="*60 -ForegroundColor Cyan

# Afficher les logs si disponibles
$logFiles = Get-ChildItem -Path "training_upload_*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 2
if ($logFiles) {
    Write-Host "`n📄 Fichiers de log récents:" -ForegroundColor Cyan
    foreach ($file in $logFiles) {
        Write-Host "   - $($file.Name)" -ForegroundColor Gray
    }
    Write-Host "Pour voir les logs: Get-Content 'nom_du_fichier.log' | Select-Object -Last 50" -ForegroundColor Yellow
}

Write-Host "`n✨ TERMINÉ" -ForegroundColor Cyan
