@echo off
REM Quick status check - No compilation, just verify
cls

echo.
echo ════════════════════════════════════════════════════════════════
echo   📋 QUICK STATUS CHECK
echo ════════════════════════════════════════════════════════════════
echo.

REM Check 1: MT5 running
tasklist | find /i "terminal64.exe" >nul
if errorlevel 1 (
    echo ❌ MT5 Terminal: OFFLINE
) else (
    echo ✅ MT5 Terminal: ONLINE
)

REM Check 2: Source files exist
if exist "D:\Dev\TradBOT\TradeManager.mq5" (
    echo ✅ TradeManager.mq5: EXISTS
) else (
    echo ❌ TradeManager.mq5: MISSING
)

if exist "D:\Dev\TradBOT\SpikeRiderEA.mq5" (
    echo ✅ SpikeRiderEA.mq5: EXISTS
) else (
    echo ❌ SpikeRiderEA.mq5: MISSING
)

REM Check 3: Python available
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python: NOT INSTALLED
) else (
    echo ✅ Python: INSTALLED
    python --version
)

REM Check 4: Trade log
if exist "D:\Dev\TradBOT\whatsapp_alerts.log" (
    echo ✅ Trade log: EXISTS
    for /F %%A in ('find /C /V "" ^< "D:\Dev\TradBOT\whatsapp_alerts.log"') do (
        echo    Lines: %%A
    )
) else (
    echo ⚠️  Trade log: NOT YET CREATED
)

echo.
echo ════════════════════════════════════════════════════════════════
echo   🔨 OPTIONS
echo ════════════════════════════════════════════════════════════════
echo.
echo   1. Auto-compile:       RUN_AUTO_COMPILE.bat
echo   2. Full startup:       START_TRADING_SYSTEM.bat
echo   3. Monitor status:     python monitor_eas.py
echo   4. View trade log:     whatsapp_alerts.log
echo.
pause
