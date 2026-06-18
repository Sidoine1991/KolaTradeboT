@echo off
REM Quick start for Perfect Opportunity Scanner

title Perfect Opportunity Scanner

echo.
echo ====================================
echo Perfect Trading Opportunities
echo Real-Time Scanner
echo ====================================
echo.

REM Check if scanner task is running
echo Checking scanner status...
tasklist /FI "IMAGENAME eq python.exe" /FI "SESSION NAME eq Console" | find /I "python.exe" > nul

if %ERRORLEVEL% EQU 0 (
    echo ✅ Scanner is RUNNING
) else (
    echo ❌ Scanner is NOT running
    echo Starting scanner task...
    schtasks /run /tn "TradBOT-PerfectOpportunitiesScanner"
    timeout /t 3
)

echo.
echo 📊 Opening Dashboard in browser...
timeout /t 1
start http://localhost:8000/dashboard/perfect_opportunities.html

echo.
echo ✅ Scanner should be running
echo.
echo 📱 Check WhatsApp for real-time alerts
echo 📊 Dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
echo 📡 API: http://localhost:8000/api/perfect-opportunities
echo 📋 Logs: D:\Dev\TradBOT\logs\scanner.log
echo.
echo Commands:
echo   - To stop: schtasks /change /tn "TradBOT-PerfectOpportunitiesScanner" /disable
echo   - To view logs: type D:\Dev\TradBOT\logs\scanner.log
echo.

pause
