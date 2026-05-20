@echo off
REM TradBOT Bridge — lance tradbot_bridge.py avec le venv TradingAgents
REM Usage:
REM   bridge.bat --symbol EURUSD
REM   bridge.bat --symbol "Boom 300 Index" --date 2026-05-20
REM   bridge.bat --symbol XAUUSD --auto
REM   bridge.bat --symbol EURUSD --no-pending

SET TA_PYTHON=D:\Dev\Depot Github\TradingAgents-main\.venv\Scripts\python.exe
SET BRIDGE=%~dp0Python\tradbot_bridge.py

IF NOT EXIST "%TA_PYTHON%" (
    echo [bridge] ERREUR: venv TradingAgents introuvable: %TA_PYTHON%
    echo Verifiez AI_TRADINGAGENTS_REPO_PATH dans .env
    pause
    exit /b 1
)

REM Injecter --analysts market,social si non fourni par l'utilisateur
echo %* | findstr /i "analysts" >nul 2>&1
if errorlevel 1 (
    "%TA_PYTHON%" "%BRIDGE%" %* --analysts market,social
) else (
    "%TA_PYTHON%" "%BRIDGE%" %*
)
