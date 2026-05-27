@echo off
REM ============================================================
REM START XAUUSD UNIFIED SYSTEM NOW
REM ============================================================

echo ============================================================
echo 🚀 TradBOT XAUUSD System — STARTING NOW
echo ============================================================
echo.

REM Kill ALL Python processes (orphan cleanup)
echo [1/3] Cleaning up orphaned processes...
taskkill /F /IM python.exe /T 2>nul
timeout /T 2 /nobreak

REM Run the centralized monitor ONCE
echo [2/3] Running central monitor (single cycle)...
cd /d D:\Dev\TradBOT
python xauusd_central_monitor.py

REM Check for errors
if errorlevel 1 (
    echo.
    echo ❌ ERROR: Central monitor failed
    echo Check:
    echo   1. Python is installed
    echo   2. D:\Dev\TradBOT\xauusd_central_monitor.py exists
    echo   3. AI Server running (http://127.0.0.1:8000)
    echo   4. TradingView is open
    echo.
    pause
    exit /b 1
)

REM Success
echo.
echo [3/3] System ready
echo.
echo ============================================================
echo ✅ XAUUSD MESSAGE SENT
echo ============================================================
echo.
echo Signal files created:
echo   • D:\Dev\TradBOT\data\gom_signal.json (→ TradeManager)
echo   • D:\Dev\TradBOT\data\opportunities.json (→ MT5)
echo.
echo WhatsApp message:
echo   To: +2290196911346
echo   Format: 8 sections (Price, GOM, Bias, Order, TA, Confluence, Decision)
echo.
echo Fallback log:
echo   D:\Dev\TradBOT\whatsapp_alerts.log (if PsychoBot offline)
echo.
echo ============================================================
echo.
pause
