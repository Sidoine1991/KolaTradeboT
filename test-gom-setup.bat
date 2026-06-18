@echo off
REM Test GOM Sync Setup
REM This script tests the complete GOM sync pipeline

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

echo.
echo ========================================
echo GOM SYNC SETUP TEST
echo ========================================
echo Time: %date% %time%
echo.

REM Test 1: Python availability
echo [TEST 1] Python executable...
for /f "delims=" %%A in ('where python') do set PYTHON_EXE=%%A
if defined PYTHON_EXE (
    echo ✅ Found: !PYTHON_EXE!
    !PYTHON_EXE! --version
) else (
    echo ❌ Python not found in PATH
    exit /b 1
)

echo.
echo [TEST 2] Script exists...
if exist "Python\gom_sync_with_report.py" (
    echo ✅ Python\gom_sync_with_report.py found
) else (
    echo ❌ Script not found
    exit /b 1
)

echo.
echo [TEST 3] Wrapper exists...
if exist "scripts\run-gom-sync-10min.bat" (
    echo ✅ scripts\run-gom-sync-10min.bat found
) else (
    echo ❌ Wrapper not found
    exit /b 1
)

echo.
echo [TEST 4] Logs directory...
if not exist "logs" mkdir "logs"
echo ✅ logs\ directory ready

echo.
echo [TEST 5] Running one iteration...
echo Running: python Python\gom_sync_with_report.py --report
echo.
!PYTHON_EXE! Python\gom_sync_with_report.py --report

if %ERRORLEVEL% equ 0 (
    echo.
    echo ✅ GOM Sync executed successfully
) else (
    echo.
    echo ❌ GOM Sync failed with exit code %ERRORLEVEL%
    exit /b %ERRORLEVEL%
)

echo.
echo [TEST 6] Checking logs...
if exist "logs\gom_sync.log" (
    echo ✅ logs\gom_sync.log created/updated
    echo Last 5 lines:
    powershell -Command "Get-Content 'logs\gom_sync.log' -Tail 5"
) else (
    echo ❌ Log file not found
    exit /b 1
)

echo.
echo ========================================
echo ✅ ALL TESTS PASSED
echo ========================================
echo.
echo Next step: Run PowerShell setup
echo   cd D:\Dev\TradBOT
echo   powershell -ExecutionPolicy Bypass -File .\scripts\setup-gom-task.ps1
echo.

pause
