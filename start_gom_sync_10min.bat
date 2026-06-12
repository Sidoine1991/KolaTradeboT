@echo off
REM ============================================================
REM GOM SYNC LOOP - Every 10 Minutes
REM ============================================================
REM
REM Command: cd D:/Dev/TradBOT && python Python/gom_sync_with_report.py --report
REM
REM Actions:
REM   1. Charge les donnees GOM depuis gom_signal.json
REM   2. Envoie chaque verdict via POST /gom-verdict a ai_server:8000
REM   3. Construit un rapport formatte
REM   4. Envoie le rapport via WhatsApp (PsychoBot ou fallback log)
REM   5. Logs stockes dans logs/ avec timestamps, verdicts, entrees, erreurs
REM
REM ============================================================

setlocal enabledelayedexpansion
cd /d D:\Dev\TradBOT

echo.
echo ============================================================
echo GOM SYNC - 10 Minute Loop (CONTINUOUS)
echo ============================================================
echo.
echo Command: python Python/gom_sync_with_report.py --report
echo Interval: Every 10 minutes
echo Logs: logs/gom_sync.log
echo.
echo Starting continuous GOM sync with reports...
echo Press Ctrl+C to stop
echo.

set iteration=0

:loop
set /a iteration+=1
for /f "tokens=2-4 delims=/ " %%a in ('date /t') do (set mydate=%%c-%%a-%%b)
for /f "tokens=1-2 delims=/:" %%a in ('time /t') do (set mytime=%%a:%%b)

echo [!mydate! !mytime!] ========================================
echo [!mydate! !mytime!] Iteration #!iteration! - GOM SYNC
echo [!mydate! !mytime!] Loading GOM verdicts...
echo [!mydate! !mytime!] Sending verdicts to /gom-verdict...
echo [!mydate! !mytime!] Building WhatsApp report...

cd D:\Dev\TradBOT
python Python/gom_sync_with_report.py --report 2>&1 | tee -a logs/gom_sync.log

echo [!mydate! !mytime!] Sync completed.
echo [!mydate! !mytime!] Next execution in 10 minutes...
echo.

timeout /t 600 /nobreak

goto loop
