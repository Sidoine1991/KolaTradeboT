@echo off
REM ============================================================
REM Install GOM Sync 10-Minute Task Scheduler (with Admin elevation)
REM ============================================================

setlocal enabledelayedexpansion

echo.
echo ============================================================
echo Checking for Administrator privileges...
echo ============================================================
echo.

REM Check for admin privileges using net session
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ ERROR: Administrator privileges required!
    echo.
    echo This script must be run as Administrator.
    echo.
    echo 🔧 To run as Admin:
    echo    1. Right-click this file
    echo    2. Select "Run as Administrator"
    echo    3. Click "Yes" when prompted
    echo.
    pause
    exit /b 1
)

echo ✅ Administrator privileges confirmed
echo.

REM Get the directory of this script
set "SCRIPT_DIR=%~dp0"
set "PS_SCRIPT=%SCRIPT_DIR%install-gom-sync-10min-task.ps1"

echo Executing PowerShell script...
echo.

REM Run the PowerShell script
powershell.exe -ExecutionPolicy Bypass -File "%PS_SCRIPT%"

if %errorlevel% neq 0 (
    echo.
    echo ❌ Installation failed
    pause
    exit /b 1
)

echo.
echo ✅ Installation completed successfully
echo.
pause
