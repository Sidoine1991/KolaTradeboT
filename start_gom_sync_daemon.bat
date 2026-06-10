@echo off
REM Start GOM Sync + WhatsApp Report Daemon (10-minute loop)
REM Usage: start_gom_sync_daemon.bat

cd /d D:\Dev\TradBOT

echo ======================================================================
echo Starting GOM Sync Daemon (10-minute autonomous loop)
echo ======================================================================
echo.
echo Log file: logs\gom_sync_daemon_10min.log
echo.
echo Daemon will:
echo  1. Load GOM data from gom_signal.json
echo  2. Send verdicts via /gom-verdict to ai_server:8000
echo  3. Build report: [Verdict] [Symbol] Entry: X.XX
echo  4. Send via WhatsApp (PsychoBot or fallback log)
echo  5. Wait 10 minutes, repeat
echo.
echo Press Ctrl+C to stop
echo.

python Python\gom_sync_daemon_10min.py

pause
