@echo off
REM ============================================================
REM VERIFY ONLY ONE MONITOR IS RUNNING
REM ============================================================

echo.
echo ============================================================
echo 🔍 VERIFICATION: Checking for conflicting monitor processes
echo ============================================================
echo.

REM Count Python processes
for /f %%A in ('tasklist ^| find /c "python"') do set COUNT=%%A

if %COUNT% GTR 0 (
    echo ❌ WARNING: %COUNT% Python process(es) currently running
    echo.
    echo Running processes:
    tasklist | find "python"
    echo.
    echo To clean up, run:
    echo   KILL_ALL_MONITORS.bat
    echo.
) else (
    echo ✅ Clean state: No Python processes running
    echo.
)

REM List all xauusd scripts (should be only 1)
echo Authorized monitor script:
dir /b xauusd_central_monitor.py 2>nul
if errorlevel 1 (
    echo ❌ ERROR: xauusd_central_monitor.py not found!
) else (
    echo ✅ Central monitor found
)

echo.
echo ============================================================
echo Ready to launch: RUN_XAUUSD_NOW.bat
echo ============================================================
echo.
pause
