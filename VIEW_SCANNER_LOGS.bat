@echo off
REM View Perfect Scanner logs in real-time

title Perfect Scanner Logs

cls

echo.
echo =========================================================
echo PERFECT SCANNER LOGS (Real-time)
echo =========================================================
echo.

if not exist "D:\Dev\TradBOT\logs\scanner.log" (
    echo [WARNING] Log file not found yet
    echo Path: D:\Dev\TradBOT\logs\scanner.log
    echo.
    echo Scanner hasn't been started, or is still initializing
    echo.
    echo To start scanner:
    echo   double-click: D:\Dev\TradBOT\LAUNCH_SCANNER_NOW.bat
    echo.
    pause
    exit /b 1
)

echo Showing logs from: D:\Dev\TradBOT\logs\scanner.log
echo.
echo [Press Ctrl+C to stop viewing]
echo.
echo =========================================================
echo.

REM Show logs with real-time update
:loop
cls
echo =========================================================
echo PERFECT SCANNER LOGS (Updated: %date% %time%)
echo =========================================================
echo.

type "D:\Dev\TradBOT\logs\scanner.log"

echo.
echo [Refreshing in 5 seconds... Press Ctrl+C to stop]
timeout /t 5 /nobreak
goto loop
