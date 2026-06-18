@echo off
REM Autonomous Pipeline Hourly Loop
REM Exécute le pipeline complet toutes les heures: scan → TA → trade → rapport

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

:LOOP
REM Timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a:%%b)

echo.
echo ========================================
echo [%mydate% %mytime%] Starting autonomous pipeline...
echo ========================================
echo.

REM Phase 1: Load GOM verdicts
echo [PHASE 1] Loading GOM verdicts...
python Python/gom_sync_with_history.py >> logs\pipeline_hourly.log 2>&1

REM Phase 2: TradingAgents subprocess
echo [PHASE 2] Running TradingAgents analysis...
python Python/tradbot_execute_with_ta.py --auto >> logs\pipeline_hourly.log 2>&1

REM Phase 3: Generate report
echo [PHASE 3] Building final report...
python Python/gom_sync_with_report.py --report >> logs\pipeline_hourly.log 2>&1

REM Sleep for 1 hour (3600 seconds)
echo [INFO] Waiting 1 hour until next cycle...
timeout /t 3600 /nobreak

goto LOOP
