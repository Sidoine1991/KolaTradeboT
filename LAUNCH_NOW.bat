@echo off
setlocal enabledelayedexpansion

title Perfect Scanner Launcher

cls

echo.
echo =========================================================
echo PERFECT OPPORTUNITIES SCANNER
echo =========================================================
echo.

REM Use the Python we found
set "PYTHON=C:\Users\USER\AppData\Roaming\uv\python\cpython-3.14.0-windows-x86_64-none\python.exe"

echo Detected Python: %PYTHON%
"%PYTHON%" --version

echo.
echo Creating logs directory...
if not exist "D:\Dev\TradBOT\logs" mkdir "D:\Dev\TradBOT\logs"

echo.
echo =========================================================
echo Starting AI Server...
echo =========================================================
echo.

cd /d D:\Dev\TradBOT\Python

REM Start AI Server in background
start "AI Server" "%PYTHON%" ai_server.py

timeout /t 5 /nobreak

echo.
echo =========================================================
echo Starting Perfect Scanner...
echo =========================================================
echo.

REM Start Scanner in background
start "Perfect Scanner" "%PYTHON%" perfect_opportunity_scanner.py

timeout /t 3 /nobreak

echo.
echo =========================================================
echo Opening Dashboard...
echo =========================================================
echo.

start http://localhost:8000/dashboard/perfect_opportunities.html

echo.
echo =========================================================
echo SUCCESS! SCANNER LAUNCHED
echo =========================================================
echo.
echo Services launched:
echo   [1] AI Server (port 8000)
echo   [2] Perfect Scanner (scanning every 30s)
echo   [3] Dashboard (browser)
echo.
echo Check:
echo   Dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
echo   Logs: D:\Dev\TradBOT\logs\scanner.log
echo   WhatsApp: Check for real-time alerts
echo.
echo Press any key to close this window...
pause

