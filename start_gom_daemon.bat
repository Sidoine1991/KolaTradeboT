@echo off
REM GOM Sync + WhatsApp Report — Autonomous 10-minute daemon
REM No arguments = infinite loop (better for production)

title GOM Sync Daemon [10min loop]

cd /d D:\Dev\TradBOT

echo.
echo ============================================================
echo   🚀 GOM SYNC DAEMON - AUTONOMOUS 10 MINUTE LOOP
echo ============================================================
echo.
echo Configuration:
echo   • Interval: Every 10 minutes
echo   • Source: /gom-kola-dashboard (MT5 live)
echo   • Destination: WhatsApp (AI server)
echo   • Logs: logs\gom_sync.log
echo.
echo Actions per cycle:
echo   1. Load GOM verdicts from MT5
echo   2. Apply gates (RSI, M15, session, Boom/Crash)
echo   3. Process verdict changes (WAIT→close, GOOD→PERFECT)
echo   4. Place market orders
echo   5. Build + send WhatsApp report
echo.
echo Starting daemon... (Press Ctrl+C to stop)
echo.

REM No --report = infinite loop (same as python Python/gom_sync_with_report.py)
C:\Python314_old\python.exe Python\gom_sync_with_report.py

echo.
echo Daemon stopped.
pause
