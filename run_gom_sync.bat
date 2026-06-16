@echo off
REM GOM Sync + WhatsApp Report — boucle 10 minutes
REM Lance directement si pas d'argument --loop, sinon mode boucle interne

cd /d D:\Dev\TradBOT

if "%1"=="--loop" goto loop

REM Mode single-shot (appelé par Task Scheduler ou manuellement)
C:\Python314_old\python.exe Python\gom_sync_with_report.py --report >> logs\gom_sync_scheduler.log 2>&1
exit /b 0

:loop
REM Mode boucle infinie (fenêtre dédiée)
title GOM Sync Loop — 10min
set /a iter=0
:next
set /a iter+=1
echo.
echo [%date% %time%] === ITERATION %iter% ===
C:\Python314_old\python.exe Python\gom_sync_with_report.py --report
echo [%date% %time%] Prochaine execution dans 10 minutes...
timeout /t 600 /nobreak
goto next
