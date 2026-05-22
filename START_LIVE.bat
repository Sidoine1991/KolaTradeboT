@echo off
REM =============================================================================
REM TradBOT IA Server Launcher - SIMPLE VERSION
REM =============================================================================

cd /d D:\Dev\TradBOT
set PYTHONIOENCODING=utf-8
set PYTHONPATH=D:\Dev\TradBOT

echo.
echo =============================================================================
echo TradBOT IA Server - STARTING NOW
echo =============================================================================
echo.
echo Server will run on: http://localhost:8000
echo Documentation: http://localhost:8000/docs
echo Health check: http://localhost:8000/health
echo.

python ai_server.py --port 8000

pause
