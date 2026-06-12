@echo off
REM Démarre GOM Sync + WhatsApp Report toutes les 10 minutes
REM Logs dans logs/gom_sync_scheduler.log

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

echo.
echo ================================
echo GOM Sync Scheduler (10 min)
echo ================================
echo Time: %date% %time%
echo.
echo Logs: D:\Dev\TradBOT\logs\gom_sync_scheduler.log
echo.
echo Ctrl+C pour arrêter
echo.

python Python\gom_sync_scheduler.py

pause
