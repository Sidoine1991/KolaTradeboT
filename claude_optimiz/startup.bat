@echo off
REM ═══════════════════════════════════════════════════════════════════════════════
REM TradBOT v3.0 - STARTUP SCRIPT Windows
REM ═══════════════════════════════════════════════════════════════════════════════

setlocal enabledelayedexpansion

title TradBOT v3.0 - AI Server

echo.
echo ╔═══════════════════════════════════════════════════════════════════════════════╗
echo ║             TradBOT v3.0 - Démarrage MACHINE DE GUERRE                        ║
echo ╚═══════════════════════════════════════════════════════════════════════════════╝

REM Vérifier Python
echo.
echo [1/4] Vérification Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python non trouvé! Installer Python 3.8+
    pause
    exit /b 1
)
echo ✅ Python OK

REM Vérifier Ollama
echo.
echo [2/4] Vérification Ollama...
powershell -Command "try { $response = Invoke-WebRequest -Uri 'http://127.0.0.1:11434/api/tags' -ErrorAction Stop; Write-Host '✅ Ollama OK'; exit 0 } catch { Write-Host '❌ Ollama indisponible'; exit 1 }"
if errorlevel 1 (
    echo.
    echo ❌ Ollama n'est pas actif!
    echo.
    echo Démarrer Ollama:
    echo 1. Ouvrir nouvelle fenêtre CMD
    echo 2. Taper: ollama serve
    echo 3. Laisser tourner
    echo.
    pause
    exit /b 1
)

REM Installer dépendances
echo.
echo [3/4] Installation dépendances Python...
pip install --quiet fastapi uvicorn requests pydantic 2>nul
echo ✅ Dépendances OK

REM Lancer serveur IA
echo.
echo [4/4] Démarrage serveur IA...
set TRADER_PORT=8000
start "TradBOT IA Server" /wait python ai_server_v3_OPTIMIZED.py

REM Vérifier que le serveur a démarré
timeout /t 2 /nobreak >nul

REM Si on arrive ici, le serveur s'est arrêté
echo.
echo ❌ Serveur IA arrêté
pause
exit /b 1
