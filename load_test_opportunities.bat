@echo off
REM Load test data for Perfect Opportunities Scanner dashboard

cls

echo.
echo ====================================
echo Loading Test Data
echo ====================================
echo.

REM Check if AI Server is running
curl -s http://localhost:8000/health >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] AI Server not running on port 8000
    echo.
    echo Start AI Server first:
    echo   python D:\Dev\TradBOT\Python\ai_server.py
    echo.
    echo Or use:
    echo   start_all.bat
    echo.
    pause
    exit /b 1
)

echo [OK] AI Server is running
echo.
echo Loading test opportunities...

REM Load test data
curl -X POST http://localhost:8000/perfect-opportunities/test-data

echo.
echo.
echo Success! Test data loaded.
echo.
echo Check dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
echo Or API: http://localhost:8000/perfect-opportunities
echo.

pause
