@echo off
title TradBOT AI Server + Intelligence Agents
cd /d "%~dp0"

echo.
echo  ================================================
echo   TradBOT Intelligence Agents
echo   Dashboard: http://127.0.0.1:8000/agents-dashboard
echo  ================================================
echo.

:: Si serveur deja actif, juste ouvrir le dashboard (pas de redemarrage)
netstat -ano | findstr ":8000 " | findstr LISTENING >nul 2>&1
if %errorlevel%==0 (
    echo  Serveur deja actif sur port 8000.
    echo  Ouverture du dashboard...
    start "" "http://127.0.0.1:8000/agents-dashboard"
    exit /b 0
)

:: Port libre — tuer eventuels ai_server orphelins
echo  Arret des anciens processus ai_server...
wmic process where "name='python.exe' and commandline like '%%ai_server%%'" delete >nul 2>&1
timeout /t 2 /nobreak >nul

echo  Demarrage du serveur (attendre ~22 secondes)...
echo.

:: Ouvre le dashboard apres 22 secondes via URL HTTP (jamais le fichier local)
start "" cmd /c "timeout /t 22 /nobreak >nul && start http://127.0.0.1:8000/agents-dashboard"

:: Lance ai_server.py
python ai_server.py

pause
