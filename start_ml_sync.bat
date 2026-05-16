@echo off
title TradBOT - ML Stats Sync (AWS RDS -> MT5)
color 0A

echo ========================================
echo  TRADBOT ML STATS SYNCHRONISATION
echo ========================================
echo.
echo [INFO] Demarrage de la synchronisation...
echo [INFO] AWS RDS -> MT5 GlobalVariables
echo [INFO] Rafraichissement: toutes les 30s
echo.
echo Appuyez sur Ctrl+C pour arreter
echo ========================================
echo.

REM Activer l'environnement virtuel si présent
if exist venv\Scripts\activate.bat (
    echo [INFO] Activation environnement virtuel...
    call venv\Scripts\activate.bat
)

REM Lancer le script Python
python sync_ml_stats_to_mt5.py

pause
