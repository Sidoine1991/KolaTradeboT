@echo off
REM start-mt5-poller.bat
REM Démarre le GOM MT5 Poller en boucle continue

setlocal enabledelayedexpansion

echo.
echo =====================================================
echo  🎯 GOM MT5 POLLER — LIVE DATA FEED
echo =====================================================
echo.
echo Ce processus:
echo   1. Lit les candles LIVE depuis MT5 Terminal
echo   2. Calcule GOM (Boom/Crash/Forex/Metals)
echo   3. POST verdicts à /gom-verdict endpoint
echo   4. Renouvelle TOUTES LES 30 SECONDES
echo.
echo Résultat: Verdicts GOM TOUJOURS EN LIVE
echo.

cd /d D:\Dev\TradBOT

echo 🚀 Lancement du MT5 GOM Poller...
echo.

python Python/gom_mt5_poller.py

echo.
echo ⚠️  Poller arrêté
pause
