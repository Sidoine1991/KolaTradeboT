@echo off
REM ============================================================
REM TradBOT - Lancement du Poller Local (Proxy EA <-> Render)
REM ============================================================

title TradBOT Local Poller
color 0A

echo.
echo ============================================================
echo  TradBOT Local Poller - Proxy vers Render AI Server
echo ============================================================
echo.
echo Render URL: https://kolatradebot-7ofl.onrender.com
echo Port local: 8765
echo.

REM Vérifier Python
python --version 2>nul
if errorlevel 1 (
    echo [ERREUR] Python non trouvé dans PATH
    echo Installez Python 3.10+ depuis python.org
    pause
    exit /b 1
)

REM Vérifier/Installer les dépendances
echo [INFO] Vérification des dépendances...
pip install -q -r requirements_poller.txt 2>nul
if errorlevel 1 (
    echo [WARN] Erreur installation dépendances, tentative sans cache...
    pip install --no-cache-dir -r requirements_poller.txt
)

echo.
echo [INFO] Démarrage du poller sur http://0.0.0.0:8765
echo [INFO] Endpoints disponibles:
echo   - http://localhost:8765/health
echo   - http://localhost:8765/gom-verdict?symbol=XAUUSD
echo   - http://localhost:8765/gom-kola-dashboard
echo.
echo [INFO] Appuyez sur Ctrl+C pour arrêter
echo ============================================================
echo.

REM Lancer le poller
python poller_local.py

echo.
echo [INFO] Poller arrêté.
pause