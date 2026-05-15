@echo off
REM ============================================================================
REM Lancement du serveur IA TradBOT - Mode Local (sans Supabase/Gemini)
REM ============================================================================

echo.
echo ======================================
echo  SERVEUR IA TRADBOT - MODE LOCAL
echo ======================================
echo.

cd /d "%~dp0"

REM Verifier que Python est installe
python --version >/dev/null 2>&1
if errorlevel 1 (
    echo ERREUR: Python n'est pas installe ou pas dans le PATH
    pause
    exit /b 1
)

echo [1/3] Verification Python... OK
echo.

REM Verifier les dependances
echo [2/3] Verification des dependances...
pip show fastapi uvicorn pandas >/dev/null 2>&1
if errorlevel 1 (
    echo Installation des dependances manquantes...
    pip install -q fastapi uvicorn pandas numpy requests joblib scikit-learn
)
echo Dependances... OK
echo.

REM Lancer le serveur
echo [3/3] Lancement du serveur IA...
echo.
echo ======================================
echo  SERVEUR DEMARRE
echo  URL Local:  http://127.0.0.1:8000
echo  URL Render: https://kolatradebot-7ofl.onrender.com
echo ======================================
echo.
echo Appuyez sur CTRL+C pour arreter le serveur
echo.

python ai_server.py

pause
