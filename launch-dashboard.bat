@echo off
REM Lance le serveur dashboard TradBOT sur le port 8765
REM Affiche le journal de trades avec Top 3 recommandations

setlocal enabledelayedexpansion

set WORK_DIR=D:\Dev\TradBOT
set PYTHON=python
set SCRIPT=%WORK_DIR%\dashboard\serve_trade_journal.py
set PORT=8765
set URL=http://127.0.0.1:%PORT%/

echo.
echo ========================================
echo  TradBOT Dashboard Launcher
echo ========================================
echo.
echo [INIT] Demarrage du serveur dashboard...
echo [INFO] URL: %URL%
echo.

cd /d "%WORK_DIR%"

REM Lancer le serveur
%PYTHON% "%SCRIPT%"

echo.
echo [STOP] Serveur arrete.
echo.
pause
