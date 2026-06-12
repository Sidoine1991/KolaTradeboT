@echo off
REM GOM Sync Loop - Exécute synchronisation GOM + WhatsApp toutes les 10 minutes
REM
REM Usage: start_gom_sync_loop.bat
REM Logs: D:\Dev\TradBOT\logs\gom_sync_daemon.log

setlocal enabledelayedexpansion
cd /d D:\Dev\TradBOT

echo [%date% %time%] GOM Sync Daemon started >> logs\gom_sync_daemon.log

:loop
    echo [%date% %time%] GOM Sync - Exécution >> logs\gom_sync_daemon.log

    python Python\gom_sync_with_report.py --report 2>&1 >> logs\gom_sync_daemon.log

    if errorlevel 1 (
        echo [%date% %time%] ERROR - GOM Sync failed >> logs\gom_sync_daemon.log
    ) else (
        echo [%date% %time%] OK - GOM Sync completed >> logs\gom_sync_daemon.log
    )

    REM Attendre 10 minutes (600 secondes)
    timeout /t 600 /nobreak

    goto loop

endlocal
