@echo off
REM Launcher GOM Sync Daemon — Boucle 10 minutes autonome
REM Exécution: start_gom_daemon.bat

setlocal enabledelayedexpansion
cd /d D:\Dev\TradBOT

REM Créer dossier logs s'il n'existe pas
if not exist logs mkdir logs

REM Timestamp pour les logs
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c%%a%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a%%b)

set LOGFILE=logs\gom_sync_daemon_%mydate%_%mytime%.log

echo. >> %LOGFILE%
echo ============================================================ >> %LOGFILE%
echo GOM SYNC DAEMON — Demarrage >> %LOGFILE%
echo ============================================================ >> %LOGFILE%

:loop
python Python/gom_sync_with_report.py --report >> %LOGFILE% 2>&1

REM Prochain sync dans 10 minutes
timeout /t 600 /nobreak >> %LOGFILE% 2>&1

goto loop
