@echo off
REM ============================================================================
REM Web Dashboard TradBOT - Interface Web temps réel
REM ============================================================================

echo.
echo ======================================
echo  TRADBOT WEB DASHBOARD
echo ======================================
echo.

cd /d "%~dp0"

REM Verifier que Python est installe
python --version >nul 2>&1
if errorlevel 1 (
    echo ERREUR: Python n'est pas installe ou pas dans le PATH
    pause
    exit /b 1
)

echo [1/2] Verification Python... OK
echo.

REM Verifier les dependances
echo [2/2] Verification des dependances...
pip show fastapi uvicorn >nul 2>&1
if errorlevel 1 (
    echo Installation des dependances manquantes...
    pip install -q fastapi uvicorn requests
)
echo Dependances... OK
echo.

REM Lancer le dashboard web
echo [3/3] Lancement du web dashboard...
echo.
echo ======================================
echo  WEB DASHBOARD DEMARRE
echo  📊 URL: http://localhost:8080
echo  🔌 WebSocket: ws://localhost:8080/ws
echo  📡 Connecté à: https://kolatradebot-7ofl.onrender.com
echo ======================================
echo.
echo Ouvre http://localhost:8080 dans ton navigateur
echo.

python web_dashboard_app.py

pause
