@echo off
REM GOM Sync + Trade History Report (10-minute interval)
REM Exécute GOM sync + charge historique trades + envoie rapport WhatsApp

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

REM Timestamp
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a:%%b)

echo [%mydate% %mytime%] GOM Sync + History starting...

REM Step 1: Process trade journal (import tous les trades MT5)
echo [STEP 1] Processing trade journal...
python Python/trade_journal_processor_fixed.py >> logs\gom_sync_history.log 2>&1

REM Step 2: GOM Sync + Load history
echo [STEP 2] Running GOM sync with history...
python Python/gom_sync_with_history.py >> logs\gom_sync_history.log 2>&1

REM Step 3: Generate combined report
echo [STEP 3] Generating combined report...
python Python/gom_sync_with_report.py --report >> logs\gom_sync_history.log 2>&1

echo [%mydate% %mytime%] GOM Sync + History complete

exit /b 0
