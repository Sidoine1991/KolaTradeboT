@echo off
REM setup-gom-task.bat
REM Enregistre une tâche Windows planifiée pour GOM Sync

setlocal enabledelayedexpansion

echo.
echo =====================================================
echo  SETUP: GOM SYNC SCHEDULED TASK
echo =====================================================
echo.
echo This will register a Windows scheduled task to run
echo GOM Sync every 10 minutes in the background.
echo.
echo REQUIREMENTS: Administrator privileges
echo.

REM Vérifier si lancé en tant qu'admin
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo ERROR: This script requires Administrator privileges!
    echo.
    echo Please:
    echo   1. Right-click this file
    echo   2. Select "Run as administrator"
    echo   3. Click "Yes" when prompted
    echo.
    pause
    exit /b 1
)

echo OK: Administrator privileges detected
echo.

REM Créer la tâche
cd /d D:\Dev\TradBOT

echo Creating scheduled task: TradBOT-GOM-Sync-10min
echo.

REM Supprimer la tâche si elle existe
schtasks /delete /tn "TradBOT\TradBOT-GOM-Sync-10min" /f >nul 2>&1

REM Créer la tâche
schtasks /create /tn "TradBOT\TradBOT-GOM-Sync-10min" ^
    /tr "python D:\Dev\TradBOT\Python\gom_sync_with_report.py --report" ^
    /sc minute /mo 10 ^
    /ru "%USERDOMAIN%\%USERNAME%" ^
    /rp "" ^
    /f

if %ERRORLEVEL% equ 0 (
    echo.
    echo =====================================================
    echo  SUCCESS: Task registered!
    echo =====================================================
    echo.
    echo Task details:
    echo   Name: TradBOT-GOM-Sync-10min
    echo   Path: \TradBOT\
    echo   Frequency: Every 10 minutes
    echo   Status: Running in background
    echo.
    echo The task will:
    echo   1. Load GOM verdicts every 10 minutes
    echo   2. Send WhatsApp report
    echo   3. Log everything
    echo   4. Run 24/7 automatically
    echo.
    echo Logs: D:\Dev\TradBOT\logs\gom_sync_task.log
    echo.
    echo To verify the task is running:
    echo   schtasks /query /tn "TradBOT\TradBOT-GOM-Sync-10min"
    echo.
    echo To delete the task (if needed):
    echo   schtasks /delete /tn "TradBOT\TradBOT-GOM-Sync-10min" /f
    echo.
    echo.
    pause
) else (
    echo.
    echo ERROR: Failed to create the task!
    echo.
    pause
    exit /b 1
)
