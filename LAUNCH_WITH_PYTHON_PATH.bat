@echo off
REM Launch scanner with manual Python path input

setlocal enabledelayedexpansion

title Scanner Launcher — Custom Python Path

cls

echo.
echo =========================================================
echo PERFECT SCANNER — CUSTOM PYTHON PATH
echo =========================================================
echo.
echo Python not found at default location.
echo Please provide the path to python.exe
echo.
echo Example paths:
echo   C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python314\python.exe
echo   C:\Python39\python.exe
echo   C:\Program Files\Python\python.exe
echo.

:INPUT
set /p PYTHON_PATH="Enter full path to python.exe: "

REM Verify it exists
if not exist "%PYTHON_PATH%" (
    echo.
    echo [ERROR] File not found: %PYTHON_PATH%
    echo.
    goto :INPUT
)

REM Verify it's actually python
"%PYTHON_PATH%" --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] This doesn't appear to be Python executable
    echo.
    goto :INPUT
)

echo.
echo [OK] Python found!
"%PYTHON_PATH%" --version
echo.

REM Create logs directory
if not exist "D:\Dev\TradBOT\logs" mkdir "D:\Dev\TradBOT\logs"

echo.
echo =========================================================
echo LAUNCHING SERVICES
echo =========================================================
echo.

echo [1] Starting AI Server...
start "TradBOT AI Server" ^
    cmd /k ^
    "cd /d D:\Dev\TradBOT\Python && ^
     echo. && ^
     echo ========================================== && ^
     echo AI SERVER RUNNING && ^
     echo ========================================== && ^
     echo Using Python: %PYTHON_PATH% && ^
     echo. && ^
     "%PYTHON_PATH%" ai_server.py && ^
     pause"

timeout /t 5

echo [2] Starting Perfect Scanner...
start "TradBOT Perfect Scanner" ^
    cmd /k ^
    "cd /d D:\Dev\TradBOT\Python && ^
     echo. && ^
     echo ========================================== && ^
     echo PERFECT OPPORTUNITIES SCANNER RUNNING && ^
     echo ========================================== && ^
     echo Using Python: %PYTHON_PATH% && ^
     echo. && ^
     "%PYTHON_PATH%" perfect_opportunity_scanner.py && ^
     pause"

timeout /t 3

echo [3] Opening Dashboard...
start http://localhost:8000/dashboard/perfect_opportunities.html

echo.
echo =========================================================
echo SUCCESS! SCANNER LAUNCHED
echo =========================================================
echo.
echo Python Path: %PYTHON_PATH%
echo.
echo Services started:
echo   [1] AI Server (port 8000)
echo   [2] Perfect Scanner
echo   [3] Dashboard (browser)
echo.
echo Monitoring:
echo   Dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
echo   Logs: D:\Dev\TradBOT\logs\scanner.log
echo   API: http://localhost:8000/perfect-opportunities
echo.
echo Next time, you can:
echo   1. Use: FIND_PYTHON_AND_LAUNCH.bat (auto-search)
echo   2. Or: LAUNCH_WITH_PYTHON_PATH.bat (manual)
echo.

pause
