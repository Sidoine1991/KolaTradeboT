@echo off
REM ====================================================================
REM TradingView Drawing Sync Service v1
REM Synchronises SL/TP levels between TradingView chart and pending orders
REM ====================================================================
REM
REM Dependencies:
REM - Python 3.9+ with aiohttp
REM - AI server running on http://127.0.0.1:8000
REM - TradingView Desktop with MCP server
REM
REM Launch sequence:
REM 1. start_ai_server.bat (FastAPI server)
REM 2. start_tv_drawing_sync.bat (this script)
REM 3. start_xauusd_monitor.bat (WhatsApp monitor)
REM
REM ====================================================================

cd /d D:\Dev\TradBOT

echo [%date% %time%] Starting TradingView Drawing Sync Service...
echo.
echo Connecting to:
echo   - AI Server: http://127.0.0.1:8000
echo   - TradingView: Desktop MCP (localhost:3000)
echo   - Symbol: XAUUSD
echo   - Poll interval: 5 seconds
echo.

python Python/tv_drawing_sync_service.py --symbol XAUUSD --interval 5

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Drawing sync service failed with exit code %errorlevel%
    echo Check logs at: tv_drawing_sync.log
    pause
)

pause
