@echo off
REM Verify Perfect Scanner is running and working

cls

echo.
echo =========================================================
echo PERFECT SCANNER STATUS CHECK
echo =========================================================
echo.

echo Checking services...
echo.

REM Check 1: AI Server health
echo [1] AI Server Status
echo     URL: http://localhost:8000/health
curl -s http://localhost:8000/health >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo     Status: [OK] Running
    for /f "delims=" %%A in ('curl -s http://localhost:8000/health') do echo     Response: %%A
) else (
    echo     Status: [FAIL] Not responding
)

echo.

REM Check 2: Scanner API
echo [2] Scanner API Status
echo     URL: http://localhost:8000/perfect-opportunities
curl -s http://localhost:8000/perfect-opportunities >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo     Status: [OK] Responding
    for /f "delims=" %%A in ('curl -s http://localhost:8000/perfect-opportunities') do echo     Response: %%A
) else (
    echo     Status: [FAIL] Not responding
)

echo.

REM Check 3: Python processes
echo [3] Python Processes
tasklist /FI "IMAGENAME eq python.exe" | find /I "python.exe" >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo     Status: [OK] Python running
    echo.
    tasklist /FI "IMAGENAME eq python.exe"
) else (
    echo     Status: [FAIL] No Python processes found
)

echo.

REM Check 4: Log file
echo [4] Scanner Log File
if exist "D:\Dev\TradBOT\logs\scanner.log" (
    echo     Status: [OK] Found
    echo     File: D:\Dev\TradBOT\logs\scanner.log
    echo.
    echo     Last 10 lines:
    echo     ---
    for /f "delims=" %%A in ('type D:\Dev\TradBOT\logs\scanner.log ^| findstr /R ".*"') do echo     %%A
    echo     ---
) else (
    echo     Status: [FAIL] Log file not created yet
    echo     (Scanner not started, or still initializing)
)

echo.

REM Summary
echo =========================================================
echo SUMMARY
echo =========================================================
echo.
echo If all checks show [OK]:
echo   - Scanner is running properly
echo   - Dashboard should work
echo   - API is responding
echo.
echo If checks show [FAIL]:
echo   1. Start scanner: double-click LAUNCH_SCANNER_NOW.bat
echo   2. Wait 5-10 seconds
echo   3. Run this script again
echo.
echo Dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
echo API: http://localhost:8000/perfect-opportunities
echo.

pause
