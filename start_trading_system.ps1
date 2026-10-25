# Script de démarrage complet pour le système de trading IA
# Auteur: TradBOT Team
# Date: 2026-01-25

param(
    [switch]$Dashboard,
    [switch]$Trading,
    [switch]$Both
)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "🤖 TRADING IA SYSTEM LAUNCHER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# Fonction pour vérifier si un processus est en cours d'exécution
function Test-ProcessRunning {
    param($ProcessName)
    $processes = Get-Process | Where-Object { $_.ProcessName -like "*$ProcessName*" }
    return $processes.Count -gt 0
}

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
Write-Host "📈 Vérification de MetaTrader 5..." -ForegroundColor Yellow
try {
    # Test de connexion MT5
    $testScript = @"
import MetaTrader5 as mt5
if mt5.initialize():
    account = mt5.account_info()
    print(f"✅ MT5 connecté - Compte: {account.login}")
    mt5.shutdown()
else:
    print("❌ MT5 non connecté")
"@
    
    $result = python -c $testScript 2>&1
    Write-Host $result -ForegroundColor $(if($result -like "✅*") {"Green"} else {"Red"})
} catch {
    Write-Host "❌ Erreur de connexion MT5" -ForegroundColor Red
}

# Vérifier Render API
Write-Host "🌐 Vérification de Render API..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "https://kolatradebot.onrender.com/health" -TimeoutSec 10
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Render API en ligne" -ForegroundColor Green
    } else {
        Write-Host "⚠️ Render API réponse: $($response.StatusCode)" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Render API inaccessible" -ForegroundColor Red
}

Write-Host ""

# Lancer les composants demandés
if ($Dashboard -or $Both) {
    Write-Host "🚀 Démarrage du Dashboard..." -ForegroundColor Green
    
    if (Test-ProcessRunning "dashboard") {
        Write-Host "⚠️ Dashboard déjà en cours d'exécution" -ForegroundColor Yellow
    } else {
        Start-Process python -ArgumentList "dashboard.py" -WindowStyle Normal
        Write-Host "✅ Dashboard démarré" -ForegroundColor Green
    }
}

if ($Trading -or $Both) {
    Write-Host "🚀 Démarrage du Trading IA..." -ForegroundColor Green
    
    if (Test-ProcessRunning "mt5_ai_client") {
        Write-Host "⚠️ Trading client déjà en cours d'exécution" -ForegroundColor Yellow
    } else {
        Start-Process python -ArgumentList "mt5_ai_client_simple.py" -WindowStyle Minimized
        Write-Host "✅ Trading IA démarré (fenêtre minimisée)" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "📊 SYSTÈME ACTIF:" -ForegroundColor Cyan
Write-Host "📈 Dashboard: Interface de monitoring en temps réel" -ForegroundColor White
Write-Host "🤖 Trading IA: Exécution automatique des signaux" -ForegroundColor White
Write-Host "🔄 Mise à jour: Toutes les 5 secondes" -ForegroundColor White
Write-Host ""
Write-Host "🎯 RÈGLES DE TRADING:" -ForegroundColor Yellow
Write-Host "• Boom: SELL uniquement (baisse des spikes)" -ForegroundColor White
Write-Host "• Crash: BUY uniquement (hausse des spikes)" -ForegroundColor White
Write-Host "• Confiance minimale: 70%" -ForegroundColor White
Write-Host "• Sans SL/TP (temporaire)" -ForegroundColor White
Write-Host ""
Write-Host "🛑 ARRÊT:" -ForegroundColor Red
Write-Host "• Dashboard: Fermer la fenêtre du dashboard" -ForegroundColor White
Write-Host "• Trading: Ctrl+C dans la console ou fermer la fenêtre" -ForegroundColor White
Write-Host "• Les deux: Exécuter 'Stop-Process -Name python'" -ForegroundColor White
Write-Host ""

if ($Both) {
    Write-Host "🎉 SYSTÈME COMPLET DÉMARRÉ !" -ForegroundColor Green
    Write-Host "Surveillez le dashboard pour suivre les performances." -ForegroundColor Cyan
} elseif ($Dashboard) {
    Write-Host "📊 DASHBOARD SEUL DÉMARRÉ" -ForegroundColor Green
} elseif ($Trading) {
    Write-Host "🤖 TRADING IA SEUL DÉMARRÉ" -ForegroundColor Green
}

# Monitor option
Write-Host ""
Write-Host "Appuyez sur une touche pour afficher l'état actuel..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

Write-Host ""
Write-Host "📊 ÉTAT ACTUEL:" -ForegroundColor Cyan

# Check running processes
$dashboardRunning = Test-ProcessRunning "dashboard"
$tradingRunning = Test-ProcessRunning "mt5_ai_client"

Write-Host "Dashboard: $(if($dashboardRunning){"🟢 ACTIF"} else {"🔴 INACTIF"})" -ForegroundColor $(if($dashboardRunning) {"Green"} else {"Red"})
Write-Host "Trading IA: $(if($tradingRunning){"🟢 ACTIF"} else {"🔴 INACTIF"})" -ForegroundColor $(if($tradingRunning) {"Green"} else {"Red"})

if ($tradingRunning) {
    Write-Host ""
    Write-Host "📈 Positions actuelles:" -ForegroundColor Yellow
    try {
        $positionsScript = @"
import MetaTrader5 as mt5
if mt5.initialize():
    positions = mt5.positions_get()
    if positions:
        for pos in positions:
            if 'Boom' in pos.symbol or 'Crash' in pos.symbol:
                profit = pos.profit
                symbol = pos.symbol
                type_str = 'BUY' if pos.type == 0 else 'SELL'
                print(f"  {symbol}: {type_str} | P&L: {profit:+.2f}")
    else:
        print("  Aucune position ouverte")
    mt5.shutdown()
"@
        $positions = python -c $positionsScript 2>&1
        Write-Host $positions -ForegroundColor White
    } catch {
        Write-Host "Impossible de récupérer les positions" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "✨ Bon trading !" -ForegroundColor Cyan
