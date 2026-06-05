@echo off
REM TradBOT Pipeline Autonome — exécution silencieuse (planificateur Windows)
REM Tourne toutes les heures entre 07h et 22h (heures de marché)

cd /d D:\Dev\TradBOT

set TRADINGAGENTS_REPO=D:\Dev\Depot Github\TradingAgents-main
set VENV_PYTHON=%TRADINGAGENTS_REPO%\.venv\Scripts\python.exe

REM Charger .env
if exist .env (
    for /f "usebackq tokens=1,2 delims==" %%a in (".env") do (
        if not "%%a"=="" if not "%%b"=="" set %%a=%%b
    )
)

REM Vérifier ai_server — sortir silencieusement si absent
curl -s http://127.0.0.1:8000/health >nul 2>&1
if errorlevel 1 (
    echo %DATE% %TIME% [SKIP] ai_server absent >> D:\Dev\TradBOT\logs\pipeline_scheduler.log
    exit /b 0
)

REM Log démarrage
echo %DATE% %TIME% [START] Pipeline horaire >> D:\Dev\TradBOT\logs\pipeline_scheduler.log

REM Lancer pipeline complet avec TradingAgents (confirmation des signaux TV)
%VENV_PYTHON% Python\autonomous_pipeline.py --ta-timeout 180 >> D:\Dev\TradBOT\logs\pipeline_scheduler.log 2>&1

echo %DATE% %TIME% [DONE] Pipeline terminé >> D:\Dev\TradBOT\logs\pipeline_scheduler.log
exit /b 0
