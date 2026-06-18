@echo off
REM Auto-elevate to admin and install GOM task
REM This batch file will request admin privileges automatically

:checkAdmin
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    timeout /t 2 > nul
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process cmd -ArgumentList '/c cd D:\Dev\TradBOT && call install-gom-task-auto-admin.bat' -Verb runAs"
    exit /b 0
)

REM If we get here, we have admin rights
cd /d D:\Dev\TradBOT

echo.
echo ========================================
echo GOM SYNC 10-MINUTE TASK INSTALLATION
echo ========================================
echo.
echo Running with Administrator privileges...
echo.

REM Delete old task
echo [STEP 1] Removing old task...
schtasks /delete /tn "TradBOT\TradBOT-GOM-Sync-10min" /f >nul 2>&1
timeout /t 1 > nul

REM Create new task
echo [STEP 2] Creating new task...
schtasks /create ^
  /tn "TradBOT\TradBOT-GOM-Sync-10min" ^
  /tr "D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat" ^
  /sc minute ^
  /mo 10 ^
  /st 00:00:00 ^
  /f

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo ✅ TASK CREATED SUCCESSFULLY
    echo ========================================
    echo.
    echo Schedule: Every 10 minutes
    echo Script: D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat
    echo Logs: D:\Dev\TradBOT\logs\gom_sync.log
    echo.
    echo Status:
    schtasks /query /tn "TradBOT\TradBOT-GOM-Sync-10min" /v /fo list | findstr /c:"Scheduled Task State" /c:"Last Run Time" /c:"Next Run Time"
) else (
    echo.
    echo ❌ ERROR: Failed to create task
    echo.
)

echo.
pause
