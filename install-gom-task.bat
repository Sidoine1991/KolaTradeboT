@echo off
REM GOM Sync 10-Minute Task Scheduler Installation
REM Elevate to admin and create scheduled task

setlocal enabledelayedexpansion

REM Check for admin rights
net session >/dev/null 2>&1
if %errorlevel% neq 0 (
    echo [INFO] Requesting Administrator privileges...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c call install-gom-task.bat' -Verb runAs"
    exit /b 0
)

REM Now we have admin rights
cd /d D:\Dev\TradBOT

echo.
echo ========================================================
echo GOM SYNC 10-MINUTE TASK SCHEDULER
echo ========================================================
echo.

REM Create the batch script that will be called
echo [STEP 1] Ensuring run script exists...
if not exist "scripts\run-gom-sync-10min.bat" (
    echo [ERROR] scripts\run-gom-sync-10min.bat not found
    exit /b 1
)
echo [OK] Script found: scripts\run-gom-sync-10min.bat

REM Delete old task if exists
echo [STEP 2] Cleaning up old task...
schtasks /delete /tn "TradBOT\GOM-Sync-10min" /f >/dev/null 2>&1

REM Create the task
echo [STEP 3] Creating scheduled task...
schtasks /create ^
    /tn "TradBOT\GOM-Sync-10min" ^
    /tr "D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat" ^
    /sc minute ^
    /mo 10 ^
    /f

if %errorlevel% equ 0 (
    echo.
    echo [SUCCESS] Task created successfully!
    echo.
    echo Task Details:
    echo   Name:     TradBOT\GOM-Sync-10min
    echo   Action:   D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat
    echo   Schedule: Every 10 minutes
    echo.
    echo Configuration:
    echo   Logs:      D:\Dev\TradBOT\logs\gom_sync.log
    echo   Dashboard: http://127.0.0.1:8765/gom
    echo.
    echo Status:
    schtasks /query /tn "TradBOT\GOM-Sync-10min" /v /fo list | findstr /c:"Scheduled Task State" /c:"Last Run Time" /c:"Next Run Time"
    echo.
    echo [INFO] Task will run in 10 minutes automatically
    echo [INFO] To manually run: schtasks /run /tn "TradBOT\GOM-Sync-10min"
    echo.
    echo ========================================================
    echo.
) else (
    echo [ERROR] Failed to create task
    exit /b 1
)

pause
