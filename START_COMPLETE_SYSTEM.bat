@echo off
REM ============================================================
REM XAUUSD COMPLETE TRADING SYSTEM - UNIFIED STARTUP
REM ============================================================

setlocal enabledelayedexpansion

echo ============================================================
echo 🚀 XAUUSD COMPLETE SYSTEM — UNIFIED STARTUP
echo ============================================================
echo.

REM Kill all previous processes
echo [1/3] Killing orphaned processes...
taskkill /F /IM python.exe /T 2>nul
timeout /T 2 /nobreak

REM Start XAUUSD Central Monitor
echo [2/3] Starting Central Monitor...
cd D:\Dev\TradBOT
start "XAUUSD Monitor" python xauusd_central_monitor.py

REM Wait for it to create signal files
timeout /T 3 /nobreak

REM Launch MetaTrader 5 Terminal with TradeManager
echo [3/3] Launching MetaTrader 5...
start "" "C:\Program Files\MetaTrader 5\terminal64.exe"

echo.
echo ============================================================
echo ✅ SYSTEM STARTUP COMPLETE
echo ============================================================
echo.
echo Active Services:
echo  • xauusd_central_monitor.py — Collects TV + AI data, sends WhatsApp
echo  • TradeManager.mq5 — Reads GOM signals + opportunities from JSON files
echo  • MetaTrader 5 Terminal — Executing trades
echo.
echo Signal files created in: D:\Dev\TradBOT\data\
echo  • gom_signal.json — GOM verdict for TradeManager
echo  • opportunities.json — Trading opportunities
echo.
pause
