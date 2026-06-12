@echo off
REM Run GOM sync + WhatsApp report with fixed Python
REM Usage: run_gom_sync.bat [--report] [--once]

echo.
echo [GOM SYNC] Starting GOM verdicts synchronization...
echo.

cd /d D:\Dev\TradBOT

C:\Python314_old\python.exe Python/gom_sync_with_report.py %* 2>&1

echo.
echo [GOM SYNC] Execution complete
echo.
pause
