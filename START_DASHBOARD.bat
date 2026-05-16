@echo off
REM ============================================================================
REM Dashboard Render TradBOT - Monitoring en temps réel
REM ============================================================================

echo.
echo ======================================
echo  TRADBOT DASHBOARD - RENDER
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
pip show requests tkinter >nul 2>&1
if errorlevel 1 (
    echo Installation des dependances manquantes...
    pip install -q requests
)
echo Dependances... OK
echo.

REM Lancer le dashboard
echo [3/3] Lancement du dashboard...
echo.
echo ======================================
echo  DASHBOARD DEMARRE
echo  Connecté à: https://kolatradebot-7ofl.onrender.com
echo ======================================
echo.

python dashboard_render.py

pause
