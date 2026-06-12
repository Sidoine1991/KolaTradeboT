@echo off
REM ============================================================
REM GOM SYNC - Continuous Loop (Every 10 Minutes)
REM ============================================================
REM
REM This script runs GOM Sync continuously
REM - Loads GOM verdicts every 10 minutes
REM - Sends each verdict via POST /gom-verdict
REM - Generates WhatsApp report
REM - Saves logs with timestamps
REM
REM Usage: Double-click to start OR: gom_sync_loop_10min.bat
REM
REM ============================================================

setlocal enabledelayedexpansion
cd /d D:\Dev\TradBOT

echo.
echo ============================================================
echo 🔄 GOM SYNC - 10 Minute Loop
echo ============================================================
echo.
echo Starting continuous GOM Sync...
echo Reports generated every 10 minutes
echo Logs saved to: logs\gom_sync.log
echo.
echo Press Ctrl+C to stop
echo.

:loop
echo.
echo [%date% %time%] ========================================
echo [%date% %time%] Executing GOM Sync...
python Python/gom_sync_with_report.py --report 2>&1 | tee -a logs/gom_sync.log

echo [%date% %time%] Waiting 10 minutes (600 seconds)...
echo [%date% %time%] Next sync will run at approximately:
for /f "tokens=1-2 delims=/:" %%a in ("%time%") do (
    set /a nextmin=%%b+10
    if !nextmin! geq 60 set /a nextmin=!nextmin!-60
    echo [%date% %%a:!nextmin!] Next execution
)

timeout /t 600 /nobreak

goto loop

