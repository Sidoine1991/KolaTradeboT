@echo off
title TradBOT — Trading + 6 Agents (parallele, separes)
cd /d "%~dp0"
setlocal enabledelayedexpansion

echo.
echo  ================================================================
echo   TradBOT — Mode parallele
echo   [1] ai_server.py      port 8000  (GOM, MT5, trading)
echo   [2] agents/server.py  port 8001  (6 agents intelligence)
echo  ================================================================
echo.

set PYTHON=python
where python >nul 2>&1 || set PYTHON=C:\Python314_old\python.exe

:: --- Arreter anciens processus agents/ai_server si ports occupes ---
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8001 " ^| findstr LISTENING') do (
    echo  Liberation port 8001 PID %%a...
    taskkill /F /PID %%a >nul 2>&1
)
timeout /t 1 /nobreak >nul

:: --- [1] Serveur agents AUTONOME (6 threads paralleles) ---
echo  Demarrage serveur AGENTS sur port 8001...
start "TradBOT Agents (6 parallel)" cmd /k ^
    "cd /d %~dp0 && set AI_ENABLE_INTELLIGENCE_AGENTS=false && %PYTHON% -m agents.server --port 8001 --host 127.0.0.1"

echo  Attente agents (8s)...
timeout /t 8 /nobreak >nul

curl -s http://127.0.0.1:8001/health >nul 2>&1
if %errorlevel%==0 (
    echo  [OK] Agents server — http://127.0.0.1:8001/dashboard
) else (
    echo  [WARN] Agents server pas encore pret — verifiez la fenetre Agents
)

:: --- [2] ai_server SANS agents integres (proxy /agents vers 8001) ---
echo.
if exist "%~dp0logs" (set LOGDIR=%~dp0logs) else (mkdir "%~dp0logs" 2>nul & set LOGDIR=%~dp0logs)

netstat -ano | findstr ":8000 " | findstr LISTENING >nul 2>&1
if %errorlevel%==0 (
    echo  ai_server deja actif sur 8000 — conserve.
) else (
    echo  Demarrage ai_server sur port 8000 (agents=proxy vers 8001)...
    start "TradBOT AI Server" cmd /k ^
        "cd /d %~dp0 && set AI_ENABLE_INTELLIGENCE_AGENTS=false && set AGENTS_SERVER_URL=http://127.0.0.1:8001 && set AGENTS_PROXY_ENABLED=true && %PYTHON% -B ai_server.py"
    echo  Attente ai_server (15s)...
    timeout /t 15 /nobreak >nul
)

curl -s http://127.0.0.1:8000/health >nul 2>&1
if %errorlevel%==0 (
    echo  [OK] ai_server — http://127.0.0.1:8000
) else (
    echo  [WARN] ai_server pas encore pret
)

:: --- Dashboard agents ---
echo.
echo  Ouverture dashboard agents...
start "" "http://127.0.0.1:8001/dashboard"
start "" "http://127.0.0.1:8000/agents-dashboard"

echo.
echo  ================================================================
echo   SERVICES LANCES
echo   Agents API  : http://127.0.0.1:8001/agents/status
echo   Dashboard   : http://127.0.0.1:8001/dashboard
echo   Trading API : http://127.0.0.1:8000/health
echo   EA gate     : http://127.0.0.1:8000/agents/gate/... (proxy)
echo  ================================================================
echo.
pause
