@echo off
REM TradBOT Pipeline Approval — exécution horaire planifiée
REM Mode --auto : valide et place les ordres directement sans confirmation WhatsApp
REM
REM Pour validation manuelle (recommandé) : utiliser run_pipeline.bat sans --auto

cd /d D:\Dev\TradBOT

set TRADINGAGENTS_REPO=D:\Dev\Depot Github\TradingAgents-main
set VENV_PYTHON=%TRADINGAGENTS_REPO%\.venv\Scripts\python.exe
set PYTHONHTTPSVERIFY=0
set REQUESTS_CA_BUNDLE=
set SSL_CERT_FILE=
set CURL_CA_BUNDLE=
set HTTPX_VERIFY=0

REM Vérifier ai_server — sortir silencieusement si absent
curl -s http://127.0.0.1:8000/health >nul 2>&1
if errorlevel 1 (
    echo %DATE% %TIME% [SKIP] ai_server absent >> D:\Dev\TradBOT\logs\pipeline_scheduler.log
    exit /b 0
)

echo %DATE% %TIME% [START] Pipeline approval (auto) >> D:\Dev\TradBOT\logs\pipeline_scheduler.log

%VENV_PYTHON% Python\pipeline_with_approval.py --auto >> D:\Dev\TradBOT\logs\pipeline_scheduler.log 2>&1

echo %DATE% %TIME% [DONE] Pipeline terminé >> D:\Dev\TradBOT\logs\pipeline_scheduler.log
exit /b 0
