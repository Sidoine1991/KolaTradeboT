@echo off
setlocal enabledelayedexpansion

title Perfect Scanner - Service Launcher

cls

echo.
echo =========================================================
echo PERFECT OPPORTUNITIES SCANNER - SERVICE LAUNCHER
echo =========================================================
echo.

set "PYTHON=C:\Users\USER\AppData\Roaming\uv\python\cpython-3.14.0-windows-x86_64-none\python.exe"

echo Python: %PYTHON%
"%PYTHON%" --version
echo.

echo Creating logs directory...
if not exist "D:\Dev\TradBOT\logs" mkdir "D:\Dev\TradBOT\logs"

echo.
echo =========================================================
echo Step 1: STARTING AI SERVER (port 8000)
echo =========================================================
echo.
echo This may take 10-20 seconds to initialize...
echo.

cd /d D:\Dev\TradBOT\Python

REM Start AI Server
"%PYTHON%" ai_server.py > "D:\Dev\TradBOT\logs\ai_server.log" 2>&1 &

echo Waiting for AI Server to start...
timeout /t 15 /nobreak

echo.
echo Checking if AI Server is responding...

REM Test if AI Server is running
curl -s http://localhost:8000/health >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] AI Server is responding on port 8000
) else (
    echo [FAIL] AI Server not responding
    echo Please check: D:\Dev\TradBOT\logs\ai_server.log
    echo.
    pause
    exit /b 1
)

echo.
echo =========================================================
echo Step 2: STARTING PERFECT SCANNER
echo =========================================================
echo.

REM Start Scanner
"%PYTHON%" perfect_opportunity_scanner.py > "D:\Dev\TradBOT\logs\scanner.log" 2>&1 &

timeout /t 3 /nobreak

echo Scanner started (check logs: D:\Dev\TradBOT\logs\scanner.log)

echo.
echo =========================================================
echo Step 3: OPENING DASHBOARD
echo =========================================================
echo.

timeout /t 2 /nobreak

start http://localhost:8000/dashboard/perfect_opportunities.html

echo.
echo =========================================================
echo SUCCESS! ALL SERVICES RUNNING
echo =========================================================
echo.
echo Services:
echo   [OK] AI Server (port 8000)
echo   [OK] Perfect Scanner
echo   [OK] Dashboard (browser)
echo.
echo Monitoring:
echo   Dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
echo   API: http://localhost:8000/perfect-opportunities
echo   Logs (AI): D:\Dev\TradBOT\logs\ai_server.log
echo   Logs (Scanner): D:\Dev\TradBOT\logs\scanner.log
echo.
echo WhatsApp alerts sent every 2 minutes when opportunities found.
echo.
echo Press any key to close...
pause
