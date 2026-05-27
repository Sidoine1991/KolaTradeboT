@echo off
REM ============================================================
REM XAUUSD Central Monitor — SINGLE AUTHORITATIVE SCRIPT
REM ============================================================
REM This is the ONLY startup script to use
REM All other monitors are deprecated and killed automatically
REM ============================================================

title TradBOT — XAUUSD Central Monitor
cd /d D:\Dev\TradBOT

echo ============================================================
echo 🚀 TradBOT XAUUSD Central Monitor
echo ============================================================
echo.
echo Killing all orphaned processes...
taskkill /F /IM python.exe /T 2>nul
timeout /T 2 /nobreak

echo.
echo ============================================================
echo 📊 Collecting XAUUSD Data (ÉTAPES 1-4)
echo ============================================================
echo.
echo • ÉTAPE 1: TradingView (quote, indicators, GOM KOLA)
echo • ÉTAPE 2: AI Server (bias, order, TA) — parallel
echo • ÉTAPE 3: Build unified WhatsApp message
echo • ÉTAPE 4: Send via PsychoBot (fallback: log file)
echo.
echo Signal files created:
echo • D:\Dev\TradBOT\data\gom_signal.json (for TradeManager)
echo • D:\Dev\TradBOT\data\opportunities.json (for MT5)
echo.
echo Press Ctrl+C to stop
echo ============================================================
echo.

python xauusd_central_monitor.py

pause
