@echo off
REM Lance TOUS les services TradBOT automatiquement
REM Usage: double-click ce fichier

echo [TradBOT] Demarrage des services...

REM 1. Verifier ai_server
echo [1/2] Verifiant ai_server...
curl -s http://127.0.0.1:8000/health >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] ai_server non disponible sur port 8000
    pause
    exit /b 1
)
echo [OK] ai_server repond

REM 2. Lancer le poller GOM
echo [2/2] Lancement poller GOM...
cd /d D:\Dev\TradBOT
start "GOM Poller" python gom_sync_working.py

echo.
echo [TradBOT] Services demarres
echo - AI Server: RUNNING
echo - GOM Poller: RUNNING
echo - MT5 EA: Lancez manuellement sur le chart
echo.
pause
