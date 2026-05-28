@echo off
REM Start TradingView Drawing Sync Service
REM Watches for manual SL/TP adjustments on TradingView chart and syncs to MT5 via AI server

cd /d D:\Dev\TradBOT
python Python\tv_drawing_sync_service.py --symbol XAUUSD --interval 5
pause
