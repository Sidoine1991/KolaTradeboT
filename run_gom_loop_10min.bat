@echo off
REM GOM Sync + WhatsApp Reports - Boucle 10 minutes
REM Lance synchronisation GOM toutes les 10 minutes indefiniment

setlocal enabledelayedexpansion

set WORK_DIR=D:\Dev\TradBOT
set PYTHON=python
set SCRIPT=%WORK_DIR%\python\gom_sync_with_report.py
set LOG_DIR=%WORK_DIR%\logs
set LOG_FILE=%LOG_DIR%\gom_sync_loop_batch.log

REM Creer dossier logs
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

REM Demarrer boucle
cd /d "%WORK_DIR%"

:LOOP
set /a RUN_COUNT+=1

echo [%date% %time%] [RUN %RUN_COUNT%] Execution synchronisation GOM... >> "%LOG_FILE%"
echo [%date% %time%] [RUN %RUN_COUNT%] Execution synchronisation GOM...

%PYTHON% "%SCRIPT%" --report >> "%LOG_FILE%" 2>&1

if errorlevel 1 (
    echo [%date% %time%] [RUN %RUN_COUNT%] ERREUR (code %errorlevel%) >> "%LOG_FILE%"
    echo [%date% %time%] [RUN %RUN_COUNT%] ERREUR
) else (
    echo [%date% %time%] [RUN %RUN_COUNT%] OK >> "%LOG_FILE%"
    echo [%date% %time%] [RUN %RUN_COUNT%] OK
)

echo [%date% %time%] Attente 10 minutes... >> "%LOG_FILE%"
echo Attente 10 minutes...
echo. >> "%LOG_FILE%"

REM Attendre 10 minutes (600 secondes)
timeout /t 600 /nobreak

goto LOOP
