@echo off
REM TradBOT — Scan matinal (Deriv / Weltrade, Top 3, rapport Word)
cd /d "D:\Dev\TradBOT"
if not exist "logs" mkdir logs

echo [%DATE% %TIME%] Scan matinal demarre >> logs\morning_scan.log

python python\morning_scan.py >> logs\morning_scan.log 2>&1
set EXITCODE=%ERRORLEVEL%

echo [%DATE% %TIME%] Scan matinal termine exit=%EXITCODE% >> logs\morning_scan.log
exit /b %EXITCODE%
