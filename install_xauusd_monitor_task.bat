@echo off
REM ============================================================================
REM XAUUSD Signal Monitor Task — Windows Scheduler
REM Attendre 07:00 UTC chaque jour et valider gates du signal trader
REM ============================================================================

setlocal enabledelayedexpansion

set TASK_NAME=TradBOT-XAUUSD-Monitor-7am
set TASK_DESC=Monitor XAUUSD SELL signal - Validate gates at 07:00 UTC daily
set SCRIPT_PATH=D:\Dev\TradBOT\monitor_xauusd_7am.ps1
set PYTHON_CMD=python
set WORK_DIR=D:\Dev\TradBOT
set LOG_DIR=%WORK_DIR%\logs

REM Verifier si admin
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [ERROR] Administrator privileges required!
    echo Relaunch with: runas /user:Administrator "cmd.exe"
    pause
    exit /b 1
)

if "%1"=="install" goto INSTALL
if "%1"=="uninstall" goto UNINSTALL
if "%1"=="status" goto STATUS
if "%1"=="test" goto TEST
if "%1"=="" goto USAGE

:USAGE
echo.
echo XAUUSD Signal Monitor — Windows Scheduler Task
echo.
echo Usage:
echo   %0 install    — Install daily task at 07:00 UTC
echo   %0 uninstall  — Remove task
echo   %0 status     — Check task status
echo   %0 test       — Test validation immediately
echo.
goto END

:INSTALL
echo.
echo [*] Installing XAUUSD Monitor task...
echo    Name: %TASK_NAME%
echo    Script: %SCRIPT_PATH%
echo    Schedule: Daily at 07:00 UTC
echo.

REM Create logs dir
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Remove existing task
tasklist /FI "TASKSCHED.EXE" >nul 2>&1
schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1

REM Create new task - 07:00 UTC = ~10:00 CAT (UTC+3) or adjust for your timezone
REM Windows Scheduler runs on LOCAL time, so adjust accordingly
REM For UTC 07:00, calculate local time = UTC + your timezone offset
REM Example: UTC+3 CAT → 07:00 UTC = 10:00 local
schtasks /create ^
  /tn "%TASK_NAME%" ^
  /tr "powershell.exe -ExecutionPolicy Bypass -File \"%SCRIPT_PATH%\"" ^
  /sc daily /st 10:00 ^
  /ru SYSTEM ^
  /f

if %errorLevel% equ 0 (
    echo [OK] Task created successfully!
    echo [OK] Scheduled for daily execution
    echo [INFO] Timezone note: 07:00 UTC = adjust time for your timezone
    echo        Example: UTC+3 CAT = 10:00 local (set above)
    echo.
    echo [OK] Logs: %LOG_DIR%\monitor_xauusd_7am.log
) else (
    echo [ERROR] Failed to create task
    exit /b 1
)

echo.
echo Task details:
schtasks /query /tn "%TASK_NAME%" /v /fo list
goto END

:UNINSTALL
echo.
echo [*] Removing XAUUSD Monitor task...
echo    Name: %TASK_NAME%
echo.

schtasks /delete /tn "%TASK_NAME%" /f

if %errorLevel% equ 0 (
    echo [OK] Task removed
) else (
    echo [WARNING] Task not found or removal failed
)
goto END

:STATUS
echo.
echo [*] XAUUSD Monitor task status...
echo    Name: %TASK_NAME%
echo.

schtasks /query /tn "%TASK_NAME%" /v /fo list

if %errorLevel% equ 0 (
    echo.
    echo Recent logs:
    if exist "%LOG_DIR%\monitor_xauusd_7am.log" (
        echo.
        powershell -Command "Get-Content '%LOG_DIR%\monitor_xauusd_7am.log' | Select-Object -Last 30"
    ) else (
        echo No logs found yet
    )
) else (
    echo [ERROR] Task not found
)
goto END

:TEST
echo.
echo [*] Testing XAUUSD Monitor validation immediately...
echo.

Push-Location "%WORK_DIR%"
powershell -ExecutionPolicy Bypass -File "%SCRIPT_PATH%" -TestNow
Pop-Location

goto END

:END
echo.
pause
