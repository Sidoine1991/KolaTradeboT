@echo off
REM Continuous GOM Sync + WhatsApp Report every 10 minutes
REM This script runs gom_sync_with_report.py in a loop with 10-minute intervals

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

echo.
echo ============================================================
echo   🚀 GOM SYNC + WHATSAPP REPORT - 10 MINUTE LOOP
echo ============================================================
echo.
echo Actions executed every 10 minutes:
echo   1. Load GOM data from gom_signal.json
echo   2. Send verdicts via POST /gom-verdict to ai_server:8000
echo   3. Build report (format: 🟢 SYMBOL — BUY ^| Entry/SL/TP)
echo   4. Send report via WhatsApp (PsychoBot or fallback)
echo   5. Logs stored in logs/ (timestamps + errors)
echo.
echo Starting loop... (Press Ctrl+C to stop)
echo.

set /a iteration=0

:loop
set /a iteration+=1
echo.
echo [%date% %time%] === ITERATION %iteration% ===
echo.

REM Run gom_sync_with_report.py and append to log
C:\Python314_old\python.exe Python/gom_sync_with_report.py --report 2>&1 | tee -a logs/gom_sync.log

REM Calculate next execution time
for /f "tokens=1-4 delims=/:" %%a in ("%date:* =%% %time%") do (
    set "nextrun=in 10 minutes at %%a:%%b:%%c"
)

echo.
echo [WAIT] Next execution %nextrun%...
echo.

REM Wait 600 seconds (10 minutes)
timeout /t 600 /nobreak

goto loop
