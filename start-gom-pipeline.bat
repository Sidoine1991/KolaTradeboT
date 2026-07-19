@echo off
setlocal enabledelayedexpansion
title TradBOT — GOM Pipeline (ai_server + poller)

cd /d D:\Dev\TradBOT

echo.
echo ============================================================
echo  GOM PIPELINE — ai_server + MT5 Poller
echo ============================================================
echo.

set PYTHON=python
where python >nul 2>&1 || set PYTHON=C:\Python314_old\python.exe

echo [1/3] Verification ai_server (port 8000)...
curl -s -m 3 http://127.0.0.1:8000/health >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo [OK] ai_server deja actif
    goto START_POLLER
)

echo [2/3] Demarrage ai_server en arriere-plan...
start "TradBOT ai_server" cmd /k "%PYTHON%" ai_server.py

echo Attente demarrage (max 60s)...
set /a WAIT=0
:WAIT_LOOP
curl -s -m 2 http://127.0.0.1:8000/health >nul 2>&1
if %ERRORLEVEL% EQU 0 goto START_POLLER
timeout /t 3 /nobreak >nul
set /a WAIT+=3
if !WAIT! GEQ 60 (
    echo [ERREUR] ai_server ne repond pas apres 60s
    echo Verifiez la fenetre "TradBOT ai_server" pour les erreurs Python.
    pause
    exit /b 1
)
goto WAIT_LOOP

:START_POLLER
echo [3/3] Lancement GOM MT5 Poller...
echo.
"%PYTHON%" python\gom_mt5_poller.py

pause
