@echo off
REM start-mt5-poller.bat — Poller GOM (ai_server requis sur :8000)

setlocal enabledelayedexpansion

echo.
echo =====================================================
echo  GOM MT5 POLLER — LIVE DATA FEED
echo =====================================================
echo.

cd /d D:\Dev\TradBOT

set PYTHON=python
where python >nul 2>&1 || set PYTHON=C:\Python314_old\python.exe

curl -s -m 3 http://127.0.0.1:8000/health >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ATTENTION] ai_server non detecte sur http://127.0.0.1:8000
    echo.
    echo Option A — tout demarrer ensemble:
    echo   start-gom-pipeline.bat
    echo.
    echo Option B — ai_server seul puis poller:
    echo   python ai_server.py
    echo   python python\gom_mt5_poller.py
    echo.
    choice /C AO /M "Demarrer ai_server maintenant (A) ou continuer sans (O)"
    if errorlevel 2 goto RUN_POLLER
    if errorlevel 1 (
        start "TradBOT ai_server" cmd /k "%PYTHON%" ai_server.py
        echo Attente ai_server...
        timeout /t 15 /nobreak >nul
    )
)

:RUN_POLLER
echo.
echo Lancement du poller...
"%PYTHON%" python\gom_mt5_poller.py

echo.
echo Poller arrete
pause
