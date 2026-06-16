@echo off
REM Start ai_server with Python 3.14.4 (bypassing Python 3.11 corruption)

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

echo.
echo ============================================================
echo   🚀 STARTING AI_SERVER (Python 3.14.4)
echo ============================================================
echo.

REM Kill any existing Python process
echo Cleaning up existing processes...
taskkill /F /IM python.exe /T 2>nul
timeout /t 2 /nobreak

REM Start ai_server with explicit Python 3.14 path
echo.
echo Starting ai_server on http://127.0.0.1:8000
echo Press Ctrl+C to stop
echo.

"C:\Python314_old\python.exe" -u ai_server.py

REM Keep window open on error
if errorlevel 1 (
    echo.
    echo ❌ ERROR: ai_server failed to start
    echo Check the error messages above
    pause
)
