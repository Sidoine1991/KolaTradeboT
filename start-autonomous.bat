@echo off
REM start-autonomous.bat
REM Lance tous les services de trading autonome

setlocal enabledelayedexpansion

echo.
echo =====================================================
echo  🤖 AUTONOMOUS TRADING SYSTEM LAUNCHER
echo =====================================================
echo.

cd /d D:\Dev\TradBOT

REM Vérifier que Python est disponible
python --version >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ❌ Python n'est pas installé ou non accessible
    pause
    exit /b 1
)

echo ✅ Python trouvé
echo.
echo 📌 Lancement de 3 terminaux (gardez-les ouverts)...
echo.

REM Terminal 1: Master GOM Poller
start "Master GOM Poller (KEEP RUNNING)" cmd /k ^
    cd /d D:\Dev\TradBOT ^& ^
    echo. ^& ^
    echo 🚀 Master GOM Poller DÉMARRÉ ^& ^
    echo ================================================ ^& ^
    echo. ^& ^
    python Python/master_gom_poller.py

timeout /t 2

REM Terminal 2: GOM Sync Scheduler
start "GOM Sync Scheduler (10 min loop)" cmd /k ^
    cd /d D:\Dev\TradBOT ^& ^
    echo. ^& ^
    echo 🚀 GOM Sync Scheduler DÉMARRÉ ^& ^
    echo ================================================ ^& ^
    echo. ^& ^
    python Python/gom_sync_scheduler.py

timeout /t 2

REM Terminal 3: Position Monitor
start "Trailing Stop Monitor (5 sec loop)" cmd /k ^
    cd /d D:\Dev\TradBOT ^& ^
    echo. ^& ^
    echo 🚀 Position Monitor DÉMARRÉ ^& ^
    echo ================================================ ^& ^
    echo. ^& ^
    python Python/trademanager_position_sync.py

echo.
echo =====================================================
echo  ✅ TOUS LES SERVICES LANCÉS
echo =====================================================
echo.
echo 📊 PROCHAINES ÉTAPES:
echo.
echo 1️⃣  Ouvrir MT5
echo 2️⃣  Attacher SMC_Universal.mq5 à un graphique
echo 3️⃣  Activer AutoTrading (bouton toolbar)
echo 4️⃣  Vérifier les inputs EA:
echo     • DisableAllAutoEntries = FALSE
echo     • AllowLiveTrading = TRUE
echo     • GOM_RequireCoherence = TRUE
echo.
echo 🎯 LE SYSTÈME EST MAINTENANT AUTONOME!
echo.
echo Verdicts GOM:        ✅ Chargés toutes les 10 min
echo SL/TP:               ✅ Mis à jour toutes les 5 sec
echo Ordres:              ✅ Placés automatiquement
echo Rapports WhatsApp:   ✅ Envoyés chaque 10 min
echo.
echo 📁 3 terminaux ont été lancés:
echo   - Master GOM Poller (CRITICAL - DO NOT CLOSE)
echo   - GOM Sync Scheduler (Reports every 10 min)
echo   - Trailing Stop Monitor (SL updates every 5 sec)
echo.
echo Maintenez-les tous ouverts pour le trading 24/7
echo.
pause
