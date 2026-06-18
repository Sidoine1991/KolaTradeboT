@echo off
REM Script de suivi horaire du signal XAUUSD BUY
REM Utilise l'API MT5 ou prix manuel
REM A launcher toutes les heures manuellement ou via Task Scheduler

setlocal enabledelayedexpansion

set WORK_DIR=D:\Dev\TradBOT
set PYTHON=python
set SCRIPT=%WORK_DIR%\python\monitor_xauusd_signal.py
set LOG_DIR=%WORK_DIR%\logs
set LOG_FILE=%LOG_DIR%\xauusd_hourly_check.log

REM Creer le dossier logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Recuperer le prix actuel (vous devez remplacer par votre source MT5)
REM Pour maintenant, utilisez un prix manuel ou ajustez selon votre API
set /p "CURRENT_PRICE=Entrez le prix XAUUSD actuel: "

if "%CURRENT_PRICE%"=="" (
    echo [%date% %time%] ERROR: Pas de prix fourni >> "%LOG_FILE%"
    echo [ERROR] Entrez un prix XAUUSD
    pause
    exit /b 1
)

cd /d "%WORK_DIR%"

echo. >> "%LOG_FILE%"
echo [%date% %time%] === CHECK HORAIRE === >> "%LOG_FILE%"
echo [%date% %time%] Prix actuel: %CURRENT_PRICE% >> "%LOG_FILE%"

REM Executer le moniteur
%PYTHON% "%SCRIPT%" %CURRENT_PRICE% >> "%LOG_FILE%" 2>&1

echo [%date% %time%] Check termine >> "%LOG_FILE%"
echo.
echo [OK] Suivi enregistre dans: %LOG_FILE%
echo [INFO] Dashboard disponible via: python %WORK_DIR%\python\monitor_xauusd_signal.py
pause
