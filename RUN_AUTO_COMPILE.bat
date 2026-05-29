@echo off
setlocal enabledelayedexpansion

REM ════════════════════════════════════════════════════════════════
REM 🚀 AUTO-COMPILE WRAPPER — Lancer le script Python
REM ════════════════════════════════════════════════════════════════

cd /d "D:\Dev\TradBOT"

echo.
echo ════════════════════════════════════════════════════════════════
echo   🔨 AUTO-COMPILE SCRIPT LAUNCHER
echo ════════════════════════════════════════════════════════════════
echo.

REM Vérifier que Python est disponible
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ Python not found in PATH
    echo.
    echo Please install Python from: https://www.python.org/downloads/
    echo Or add Python to your PATH variable
    echo.
    pause
    exit /b 1
)

REM Installer psutil si nécessaire
python -m pip install psutil -q 2>nul

REM Lancer le script Python
echo Starting auto-compilation...
echo.
python auto_compile.py

if errorlevel 1 (
    echo.
    echo ❌ Script failed with errors
    pause
    exit /b 1
)

echo.
echo ✅ All done! MT5 should now be running with compiled EAs.
echo.
pause
