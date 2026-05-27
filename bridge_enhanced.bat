@echo off
REM TradBOT Bridge Enhanced - Version amelioree avec multi-langue et envoi WhatsApp
REM
REM Usage:
REM   bridge_enhanced.bat              (mode wizard complet)
REM   bridge_enhanced.bat --symbol XAUUSD --lang FR --account medium

setlocal

set TRADBOT_ROOT=%~dp0
set VENV_PYTHON=D:\Dev\Depot Github\TradingAgents-main\.venv\Scripts\python.exe

if not exist "%VENV_PYTHON%" (
    echo [ERROR] TradingAgents venv introuvable: %VENV_PYTHON%
    echo.
    echo Installation venv requise:
    echo   cd "D:\Dev\Depot Github\TradingAgents-main"
    echo   python -m venv .venv
    echo   .venv\Scripts\pip install -r requirements.txt
    pause
    exit /b 1
)

echo.
echo ========================================
echo   TradBOT Bridge Enhanced
echo ========================================
echo.

"%VENV_PYTHON%" "%TRADBOT_ROOT%Python\tradbot_bridge_enhanced.py" %*

if errorlevel 1 (
    echo.
    echo [ERREUR] Le bridge a rencontre une erreur.
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Rapport genere et envoye!
pause
