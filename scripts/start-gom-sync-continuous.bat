@echo off
REM ============================================================
REM GOM Continuous Sync - Keeps Verdicts Fresh Every 5 Minutes
REM ============================================================
REM
REM This script runs gom_sync_with_report.py in a continuous loop
REM Every 5 minutes it:
REM   1. Fetches latest GOM verdicts
REM   2. Updates timestamps
REM   3. Sends fresh verdicts to AI Server
REM   4. Generates WhatsApp report
REM
REM ============================================================

cd /d D:\Dev\TradBOT

echo.
echo ============================================================
echo [GOM] Continuous Sync - Every 5 Minutes
echo ============================================================
echo.
echo Starting GOM Verdict Sync...
echo Reports will update every 5 minutes
echo Press Ctrl+C to stop
echo.

:loop
echo.
echo [%date% %time%] Syncing GOM verdicts...
python Python/gom_sync_with_report.py --report 2>&1 | tee -a logs/gom_continuous_sync.log

echo [%date% %time%] Waiting 5 minutes...
timeout /t 300 /nobreak

goto loop
