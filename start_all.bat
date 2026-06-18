@echo off
REM Start AI Server + Perfect Scanner all-in-one

title TradBOT Services

echo.
echo ====================================
echo TradBOT Services Launcher
echo ====================================
echo.

REM Check Python
set PYTHON_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python314\python.exe
if not exist "%PYTHON_PATH%" (
    echo ERROR: Python 3.14 not found
    echo Please install Python first
    pause
    exit /b 1
)

echo Starting services...
echo.

REM Start AI Server in separate window
echo [1/2] Starting AI Server (port 8000)...
start "TradBOT AI Server" /min "%PYTHON_PATH%" "D:\Dev\TradBOT\Python\ai_server.py"

REM Wait for AI Server to be ready
timeout /t 5

REM Start Perfect Scanner in separate window
echo [2/2] Starting Perfect Opportunities Scanner...
start "TradBOT Perfect Scanner" /min "%PYTHON_PATH%" "D:\Dev\TradBOT\Python\perfect_opportunity_scanner.py"

timeout /t 2

echo.
echo SUCCESS! All services started.
echo.
echo Services:
echo   AI Server: http://localhost:8000
echo   Dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
echo   API: http://localhost:8000/perfect-opportunities
echo.
echo Opening dashboard...
timeout /t 2

start http://localhost:8000/dashboard/perfect_opportunities.html

echo.
echo Done! Check the windows and WhatsApp for alerts.
echo.

pause
