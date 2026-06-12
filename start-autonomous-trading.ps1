#!/usr/bin/env powershell
# start-autonomous-trading.ps1
# Démarre tout le système de trading autonome en parallèle

Write-Host "🚀 DÉMARRAGE SYSTÈME DE TRADING AUTONOME" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green

# Vérifier que les processus ne sont pas déjà lancés
$processes = @(
    "master_gom_poller",
    "gom_sync_scheduler",
    "trademanager_position_sync"
)

Write-Host "`n🔍 Vérification des processus existants..." -ForegroundColor Cyan
foreach ($proc in $processes) {
    $running = Get-Process -Name "python" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*$proc*" }
    if ($running) {
        Write-Host "⚠️  $proc est déjà en cours d'exécution" -ForegroundColor Yellow
    } else {
        Write-Host "✅ $proc n'est pas lancé (prêt à démarrer)" -ForegroundColor Green
    }
}

Write-Host "`n" -ForegroundColor Green

# Lancer Terminal 1: Master GOM Poller
Write-Host "📌 Terminal 1: Lancement du Master GOM Poller..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList @"
`$host.UI.RawUI.WindowTitle = 'Master GOM Poller (Keep Running)'
cd D:\Dev\TradBOT
Write-Host '🚀 Master GOM Poller démarré' -ForegroundColor Green
python Python/master_gom_poller.py
Read-Host 'Appuyez sur Entrée pour fermer'
"@ -NoNewWindow

Start-Sleep -Seconds 2

# Lancer Terminal 2: GOM Sync Scheduler
Write-Host "📌 Terminal 2: Lancement du GOM Sync Scheduler..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList @"
`$host.UI.RawUI.WindowTitle = 'GOM Sync Scheduler (10 min loop)'
cd D:\Dev\TradBOT
Write-Host '🚀 GOM Sync Scheduler démarré' -ForegroundColor Green
python Python/gom_sync_scheduler.py
Read-Host 'Appuyez sur Entrée pour fermer'
"@ -NoNewWindow

Start-Sleep -Seconds 2

# Lancer Terminal 3: Position Monitor
Write-Host "📌 Terminal 3: Lancement du Position Monitor..." -ForegroundColor Cyan
Start-Process powershell -ArgumentList @"
`$host.UI.RawUI.WindowTitle = 'Trailing Stop Position Monitor (5 sec loop)'
cd D:\Dev\TradBOT
Write-Host '🚀 Position Monitor démarré' -ForegroundColor Green
python Python/trademanager_position_sync.py
Read-Host 'Appuyez sur Entrée pour fermer'
"@ -NoNewWindow

Write-Host "`n" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "✅ TOUS LES PROCESSUS LANCÉS" -ForegroundColor Green
Write-Host "================================================" -ForegroundColor Green
Write-Host "`n📊 Prochaines étapes:" -ForegroundColor Cyan
Write-Host "1️⃣  Ouvrir MT5" -ForegroundColor Cyan
Write-Host "2️⃣  Attacher SMC_Universal.mq5 à un graphique" -ForegroundColor Cyan
Write-Host "3️⃣  Activer AutoTrading (bouton toolbar)" -ForegroundColor Cyan
Write-Host "4️⃣  Vérifier les inputs EA:" -ForegroundColor Cyan
Write-Host "   • DisableAllAutoEntries = FALSE" -ForegroundColor Cyan
Write-Host "   • AllowLiveTrading = TRUE" -ForegroundColor Cyan
Write-Host "   • GOM_RequireCoherence = TRUE" -ForegroundColor Cyan
Write-Host "`n🎯 Le système est maintenant autonome!" -ForegroundColor Green
Write-Host "   • Verdicts GOM chargés toutes les 10 min" -ForegroundColor Green
Write-Host "   • SL/TP mis à jour toutes les 5 sec" -ForegroundColor Green
Write-Host "   • Ordres placés automatiquement" -ForegroundColor Green
Write-Host "   • Rapports WhatsApp envoyés chaque 10 min" -ForegroundColor Green
Write-Host "`n" -ForegroundColor Green
Write-Host "Fenêtre mère se ferme dans 10 secondes..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
