@echo off
REM ============================================================
REM Launch XAUUSD Monitor — 20-Minute WhatsApp Loop
REM ============================================================

cd /d D:\Dev\TradBOT

echo.
echo ============================================================
echo  XAUUSD Unified Monitor (20-min WhatsApp updates)
echo ============================================================
echo.

python Python/xauusd_scheduler.py

pause
