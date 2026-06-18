@echo off
REM Test Perfect Scanner API

title Test Perfect Scanner

cls

echo.
echo ====================================
echo Testing Perfect Opportunities API
echo ====================================
echo.

echo Checking AI Server status...
timeout /t 1

REM Test with curl
curl -s http://localhost:8000/health >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] AI Server is running
    echo.
    echo Testing /perfect-opportunities endpoint...
    curl -s http://localhost:8000/perfect-opportunities
    echo.
    echo.
    echo Dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
) else (
    echo [FAIL] AI Server not running on port 8000
    echo.
    echo Start AI Server first:
    echo   python D:\Dev\TradBOT\Python\ai_server.py
    echo.
    echo Or use:
    echo   start_all.bat
)

echo.
echo.
pause
