@echo off
setlocal enabledelayedexpansion
REM ============================================================
REM TradBOT COMPLETE SYSTEM STARTUP
REM ============================================================

echo.
echo ============================================================
echo 🚀 TradBOT Complete System Startup
echo ============================================================
echo.

REM Get absolute paths
set TRADBOT_DIR=%~dp0
set PSYCHOBOT_DIR=%TRADBOT_DIR:~0,-1%\..\Psychobot

echo [1/3] Creating logs directory...
if not exist "%TRADBOT_DIR%logs" mkdir "%TRADBOT_DIR%logs"
echo ✅ Logs directory ready

echo.
echo [2/3] Starting PsychoBot (Node.js WhatsApp Bot)...
echo Port: 8888
echo Command: npm start
cd /d "%PSYCHOBOT_DIR%"

REM Check if node_modules exists
if not exist "%PSYCHOBOT_DIR%\node_modules" (
    echo Installing dependencies...
    call npm install
)

REM Start PsychoBot in background
start "PsychoBot - WhatsApp" cmd /k npm start

REM Wait for PsychoBot to start
timeout /t 5 /nobreak

echo.
echo [3/3] Starting TradBOT AI Server...
echo Port: 8000
cd /d "%TRADBOT_DIR%"

REM Start AI Server
start "TradBOT AI Server" cmd /k python ai_server.py

echo.
timeout /t 3 /nobreak

echo ============================================================
echo ✅ SYSTEM STARTUP COMPLETE
echo ============================================================
echo.
echo Services Running:
echo   • PsychoBot WhatsApp Bot ........ http://localhost:8888
echo   • TradBOT AI Server ............ http://localhost:8000
echo   • Pipeline Logs ............... %TRADBOT_DIR%logs\
echo.
echo Next Steps:
echo   1. Wait 30s for both services to fully initialize
echo   2. Execute: python Python\gom_sync_with_report.py --report
echo   3. Execute: python Python\pipeline_hourly_autonomous.py --once
echo.
echo Reports will be sent to WhatsApp automatically!
echo ============================================================
echo.
pause
