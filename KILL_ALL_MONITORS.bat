@echo off
REM ============================================================
REM EMERGENCY: Kill all XAUUSD monitors
REM ============================================================

echo ============================================================
echo 🔴 KILLING ALL MONITORS
echo ============================================================
echo.
echo This will terminate ALL Python processes
echo Press Ctrl+C to cancel, or press any key to continue...
echo.
pause >/dev/null

taskkill /F /IM python.exe /T
timeout /T 2 /nobreak

echo.
echo ✅ All Python processes killed
echo.
echo Next: Run D:\Dev\TradBOT\RUN_XAUUSD_NOW.bat
echo.
pause
