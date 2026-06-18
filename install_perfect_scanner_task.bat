@echo off
REM Install Perfect Opportunity Scanner as Windows Task
REM Runs: perfect_opportunity_scanner.py every 1 minute

set PYTHON_PATH=C:\Users\%USERNAME%\AppData\Local\Programs\Python\Python314\python.exe
set SCRIPT_PATH=D:\Dev\TradBOT\Python\perfect_opportunity_scanner.py
set LOG_PATH=D:\Dev\TradBOT\logs\scanner.log
set TASK_NAME=TradBOT-PerfectOpportunitiesScanner

echo.
echo =====================================
echo Perfect Opportunity Scanner — Installer
echo =====================================
echo.

REM Check Python
if not exist "%PYTHON_PATH%" (
    echo ❌ Python 3.14 not found at %PYTHON_PATH%
    echo Please install Python 3.14 first
    pause
    exit /b 1
)

echo ✅ Python found: %PYTHON_PATH%

REM Create logs directory
if not exist "D:\Dev\TradBOT\logs" mkdir "D:\Dev\TradBOT\logs"

REM Register task
echo.
echo Installing task: %TASK_NAME%
echo Script: %SCRIPT_PATH%
echo.

schtasks /delete "%TASK_NAME%" /f 2>nul

schtasks /create /tn "%TASK_NAME%" ^
    /tr "cmd /c start /min \"%PYTHON_PATH%\" \"%SCRIPT_PATH%\" >> \"%LOG_PATH%\" 2>&1" ^
    /sc minute /mo 1 ^
    /ru "%USERNAME%" ^
    /rl highest ^
    /f

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Task installed successfully!
    echo.
    echo Task Name: %TASK_NAME%
    echo Status: Will start at next system boot
    echo Frequency: Every 1 minute
    echo Log: %LOG_PATH%
    echo.
    echo To start manually:
    echo   schtasks /run /tn "%TASK_NAME%"
    echo.
    echo To remove:
    echo   schtasks /delete "%TASK_NAME%" /f
    echo.
) else (
    echo.
    echo ❌ Installation failed (error %ERRORLEVEL%)
    echo Try running as Administrator
    echo.
)

pause
