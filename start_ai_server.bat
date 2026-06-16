@echo off
REM Start ai_server with Python 3.14.4

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

echo.
echo ============================================================
echo   🚀 STARTING AI_SERVER (Python 3.14.4)
echo ============================================================
echo.

REM Kill existing process if running
taskkill /F /IM python.exe /T 2>nul

REM Wait for cleanup
timeout /t 2 /nobreak

REM Start ai_server
echo Starting ai_server on http://127.0.0.1:8000
echo.

"C:\Python314_old\python.exe" ai_server.py

pause
