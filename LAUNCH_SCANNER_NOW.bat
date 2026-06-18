@echo off
REM LAUNCH PERFECT OPPORTUNITIES SCANNER NOW
REM This script starts everything needed and shows real-time output

setlocal enabledelayedexpansion

title Perfect Opportunities Scanner — LIVE

cls

echo.
echo =========================================================
echo         PERFECT OPPORTUNITIES SCANNER — LAUNCHING
echo =========================================================
echo.

REM Get Python path
set PYTHON_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python314\python.exe

REM Verify Python exists
if not exist "%PYTHON_PATH%" (
    echo [ERROR] Python 3.14 not found at:
    echo   %PYTHON_PATH%
    echo.
    echo Please install Python 3.14 first
    pause
    exit /b 1
)

echo [OK] Python found
echo     Path: %PYTHON_PATH%
echo.

REM Verify scripts exist
if not exist "D:\Dev\TradBOT\Python\ai_server.py" (
    echo [ERROR] ai_server.py not found
    pause
    exit /b 1
)

if not exist "D:\Dev\TradBOT\Python\perfect_opportunity_scanner.py" (
    echo [ERROR] perfect_opportunity_scanner.py not found
    pause
    exit /b 1
)

echo [OK] All scripts found
echo.

REM Create logs directory if needed
if not exist "D:\Dev\TradBOT\logs" mkdir "D:\Dev\TradBOT\logs"

echo =========================================================
echo STEP 1: Starting AI Server (port 8000)
echo =========================================================
echo.
echo Starting: "%PYTHON_PATH%" ai_server.py
echo.

start "TradBOT AI Server" ^
    cmd /k ^
    "cd /d D:\Dev\TradBOT\Python && ^
     echo. && ^
     echo ========================================== && ^
     echo AI SERVER RUNNING && ^
     echo ========================================== && ^
     echo Press Ctrl+C to stop && ^
     echo. && ^
     "%PYTHON_PATH%" ai_server.py && ^
     pause"

REM Wait for AI Server to initialize
echo Waiting for AI Server to initialize...
timeout /t 5

echo.
echo =========================================================
echo STEP 2: Starting Perfect Opportunities Scanner
echo =========================================================
echo.
echo Starting: "%PYTHON_PATH%" perfect_opportunity_scanner.py
echo.

start "TradBOT Perfect Scanner" ^
    cmd /k ^
    "cd /d D:\Dev\TradBOT\Python && ^
     echo. && ^
     echo ========================================== && ^
     echo PERFECT OPPORTUNITIES SCANNER RUNNING && ^
     echo ========================================== && ^
     echo Press Ctrl+C to stop && ^
     echo. && ^
     "%PYTHON_PATH%" perfect_opportunity_scanner.py && ^
     pause"

REM Wait a bit
timeout /t 3

echo.
echo =========================================================
echo STEP 3: Opening Dashboard
echo =========================================================
echo.
echo Opening browser dashboard...
timeout /t 2

start http://localhost:8000/dashboard/perfect_opportunities.html

echo.
echo =========================================================
echo SUCCESS! SCANNER IS RUNNING
echo =========================================================
echo.
echo Services:
echo   [1] AI Server Console Window — http://localhost:8000
echo   [2] Scanner Console Window — Processing opportunities
echo   [3] Dashboard Browser Window — http://localhost:8000/dashboard/perfect_opportunities.html
echo.
echo What's happening:
echo   - Scanner polls every 30 seconds
echo   - Dashboard updates in real-time
echo   - WhatsApp alerts sent every 2 minutes
echo.
echo Files:
echo   - Logs: D:\Dev\TradBOT\logs\scanner.log
echo   - Dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
echo   - API: http://localhost:8000/perfect-opportunities
echo.
echo Thresholds:
echo   - IA Confidence: >= 70%%
echo   - GOM Coherence: >= 85%%
echo   - Probability: >= 65%%
echo.
echo Test the API:
echo   curl http://localhost:8000/perfect-opportunities
echo.
echo Load test data:
echo   double-click: D:\Dev\TradBOT\load_test_opportunities.bat
echo.
echo =========================================================
echo.
echo Console windows are open. Close them to stop services.
echo Press any key to close this window...
echo.

pause
