@echo off
REM start-gom-sync-10min.bat
REM Démarre le GOM Sync Scheduler en boucle 10 min

setlocal enabledelayedexpansion

echo.
echo =====================================================
echo  🎯 GOM SYNC SCHEDULER — 10 MIN LOOP
echo =====================================================
echo.
echo Démarrage: %date% %time%
echo Répertoire: %cd%
echo.

cd /d D:\Dev\TradBOT

REM Créer le répertoire logs s'il n'existe pas
if not exist logs mkdir logs

REM Lancer le scheduler
echo 🚀 Lancement du GOM Sync Scheduler...
echo.
echo ℹ️  Ce processus tournera indéfiniment
echo ℹ️  Rapports GOM envoyés toutes les 10 minutes
echo ℹ️  Logs stockés dans: logs/gom_sync_scheduler.log
echo.
echo Appuyez sur Ctrl+C pour arrêter
echo.

python Python/gom_sync_scheduler.py

REM Si le script se termine, afficher un message
echo.
echo ⚠️  GOM Sync Scheduler ARRÊTÉ
echo.
pause
