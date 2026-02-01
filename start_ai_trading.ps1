# Script PowerShell pour démarrer le système de trading IA complet

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🤖 TRADBOT AI - TRADING SYSTEM" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

Write-Host "Ce script va démarrer:" -ForegroundColor White
Write-Host "  1. Entraînement des modèles ML (si nécessaire)" -ForegroundColor Gray
Write-Host "  2. Client MT5 pour trading automatique" -ForegroundColor Gray
Write-Host "  3. Communication avec le serveur IA Render" -ForegroundColor Gray
Write-Host ""

# Vérifier les prérequis
Write-Host "🔍 Vérification des prérequis..." -ForegroundColor Yellow

# Vérifier Python
try {
    $pythonVersion = python --version 2>$null
    Write-Host "✅ Python: $pythonVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Python non trouvé" -ForegroundColor Red
    exit 1
}

# Vérifier MT5
try {
    $mt5Test = python -c "import MetaTrader5 as mt5; print('MT5 OK')" 2>&1
    if ($mt5Test -like "*MT5 OK*") {
        Write-Host "✅ MetaTrader5 disponible" -ForegroundColor Green
    } else {
        Write-Host "❌ MetaTrader5 non disponible" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "❌ Erreur vérification MT5" -ForegroundColor Red
    exit 1
}

# Vérifier connexion Render
try {
    $response = Invoke-RestMethod -Uri "https://kolatradebot.onrender.com/health" -TimeoutSec 10
    Write-Host "✅ Serveur Render accessible" -ForegroundColor Green
    Write-Host "   Status: $($response.status)" -ForegroundColor Cyan
} catch {
    Write-Host "❌ Serveur Render inaccessible" -ForegroundColor Red
    Write-Host "   Vérifiez votre connexion internet" -ForegroundColor Yellow
}

# Vérifier variables d'environnement MT5
$mt5Login = $env:MT5_LOGIN
$mt5Password = $env:MT5_PASSWORD
$mt5Server = $env:MT5_SERVER

if ($mt5Login -and $mt5Password -and $mt5Server) {
    Write-Host "✅ Variables MT5 configurées" -ForegroundColor Green
} else {
    Write-Host "⚠️ Variables MT5 non configurées (utilise connexion existante)" -ForegroundColor Yellow
}

Write-Host ""

# Menu des options
Write-Host "🚋 OPTIONS DE DÉMARRAGE" -ForegroundColor Cyan
Write-Host "1. 🔄 Entraîner les modèles + Démarrer trading" -ForegroundColor Green
Write-Host "2. 🤖 Démarrer trading uniquement (modèles existants)" -ForegroundColor Yellow
Write-Host "3. 📊 Entraîner les modèles uniquement" -ForegroundColor Blue
Write-Host ""

$choice = Read-Host "Votre choix (1/2/3)"

switch ($choice) {
    "1" {
        Write-Host "🔄 Entraînement des modèles..." -ForegroundColor Green
        
        # Activer l'environnement virtuel si disponible
        if (Test-Path ".venv\Scripts\Activate.ps1") {
            & .\.venv\Scripts\Activate.ps1
        }
        
        # Entraîner les modèles
        try {
            python train_and_upload_models.py --train-upload
            
            if ($LASTEXITCODE -eq 0) {
                Write-Host "✅ Entraînement terminé" -ForegroundColor Green
                Write-Host "🤖 Démarrage du client MT5..." -ForegroundColor Yellow
                
                # Démarrer le client MT5
                python mt5_ai_client.py
            } else {
                Write-Host "❌ Erreur lors de l'entraînement" -ForegroundColor Red
            }
        } catch {
            Write-Host "❌ Erreur: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    "2" {
        Write-Host "🤖 Démarrage du client MT5..." -ForegroundColor Yellow
        
        # Activer l'environnement virtuel si disponible
        if (Test-Path ".venv\Scripts\Activate.ps1") {
            & .\.venv\Scripts\Activate.ps1
        }
        
        try {
            python mt5_ai_client.py
        } catch {
            Write-Host "❌ Erreur: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    "3" {
        Write-Host "📊 Entraînement des modèles uniquement..." -ForegroundColor Blue
        
        # Activer l'environnement virtuel si disponible
        if (Test-Path ".venv\Scripts\Activate.ps1") {
            & .\.venv\Scripts\Activate.ps1
        }
        
        try {
            python train_and_upload_models.py --train-upload
        } catch {
            Write-Host "❌ Erreur: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
    
    default {
        Write-Host "❌ Choix invalide" -ForegroundColor Red
    }
}

Write-Host "`n✨ Opération terminée" -ForegroundColor Cyan
