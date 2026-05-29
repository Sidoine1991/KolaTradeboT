@echo off
setlocal enabledelayedexpansion

REM ════════════════════════════════════════════════════════════════
REM 🚀 START TRADING SYSTEM — Complete Automation
REM ════════════════════════════════════════════════════════════════

cls
echo.
echo ════════════════════════════════════════════════════════════════
echo   🚀 TRADBOT COMPLETE STARTUP SEQUENCE
echo ════════════════════════════════════════════════════════════════
echo.

REM Change to TradBOT directory
cd /d "D:\Dev\TradBOT"

REM Step 1: Auto-Compile
echo [1/4] Running auto-compilation...
echo.
call python auto_compile.py
if errorlevel 1 (
    echo ❌ Compilation failed!
    pause
    exit /b 1
)
echo.

REM Step 2: Wait for MT5 to fully load
echo [2/4] Waiting for MT5 to fully load (30 seconds)...
echo.
timeout /T 30 /nobreak

REM Step 3: Verify system
echo.
echo [3/4] Verifying system status...
echo.
python monitor_eas.py

REM Step 4: Instructions
echo.
echo [4/4] System startup complete!
echo.
echo ════════════════════════════════════════════════════════════════
echo   ✅ TRADING SYSTEM READY
echo ════════════════════════════════════════════════════════════════
echo.
echo 📋 MANUAL STEPS REQUIRED:
echo.
echo   1. In MT5 Terminal (now open):
echo      → Menu > Tools > Options > Experts
echo      → Enable "Allow algorithmic trading" ✓
echo      → Enable "Allow DLL imports" ✓
echo      → Click OK
echo.
echo   2. Attach EAs to charts:
echo      → Right-click on chart > Expert Advisors
echo      → XAUUSD M1 → Select "TradeManager"
echo      → Boom 600 M1 → Select "SpikeRiderEA"
echo      → Crash 600 M1 → Select "SpikeRiderEA"
echo      → (Repeat for Crash 1000, Boom 1000)
echo.
echo   3. Monitor trading:
echo      → Press F2 to view Expert logs
echo      → Look for [GOM-Auto] and [SpikeRider] messages
echo      → Trades will appear in the chart
echo.
echo 📊 MONITORING:
echo.
echo   To check trading status anytime:
echo   → python monitor_eas.py
echo.
echo   To view trade log:
echo   → D:\Dev\TradBOT\whatsapp_alerts.log
echo.
echo ════════════════════════════════════════════════════════════════
echo.
pause
