@echo off
REM ========================================
REM XAUUSD WhatsApp Monitor Launcher
REM ========================================
REM
REM Usage:
REM   1. Modifier PHONE_NUMBER ci-dessous
REM   2. Double-cliquer ce fichier
REM   3. Laisser tourner en background
REM
REM Alertes automatiques:
REM   - Setup SELL valide
REM   - Biais change
REM   - TP1/TP2 atteints
REM
REM ========================================

REM === CONFIGURATION ===
SET PHONE_NUMBER=+33612345678
SET INTERVAL=600

REM === NE PAS MODIFIER CI-DESSOUS ===
cd /d "%~dp0"
echo.
echo ========================================
echo  TradBOT - XAUUSD WhatsApp Monitor
echo ========================================
echo.
echo Phone:    %PHONE_NUMBER%
echo Interval: %INTERVAL%s (%INTERVAL%/60 min)
echo.
echo [INFO] Demarrage surveillance...
echo [INFO] Appuyez sur Ctrl+C pour arreter
echo.

python Python\xauusd_whatsapp_monitor.py --phone %PHONE_NUMBER% --interval %INTERVAL%

if errorlevel 1 (
    echo.
    echo [ERREUR] La surveillance a echoue
    echo.
    echo Verifiez:
    echo   - Python est installe
    echo   - Les dependances sont installees: pip install requests websockets
    echo   - Le serveur AI tourne sur http://127.0.0.1:8000
    echo   - Votre numero WhatsApp est correct
    pause
)
