@echo off
REM Compile SMC_Universal.mq5 et affiche les erreurs

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

echo.
echo ========================================
echo COMPILE SMC_Universal.mq5
echo ========================================
echo.

set METAEDITOR="C:\Program Files\MetaTrader 5\metaeditor64.exe"

if not exist %METAEDITOR% (
    echo ❌ MetaEditor not found at: %METAEDITOR%
    pause
    exit /b 1
)

echo ✅ MetaEditor found
echo.

echo Compiling: mt5\SMC_Universal.mq5
%METAEDITOR% /compile:mt5\SMC_Universal.mq5 /log:compilation.log

if %errorlevel% equ 0 (
    echo.
    echo ✅ COMPILATION SUCCESSFUL
    echo.
) else (
    echo.
    echo ❌ COMPILATION FAILED (error code: %errorlevel%)
    echo.
)

if exist compilation.log (
    echo Checking log file...
    type compilation.log | findstr /i "error" && (
        echo.
        echo Errors found - showing full log:
        type compilation.log
    ) || (
        echo No errors in log
    )
)

echo.
pause
