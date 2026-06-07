@echo off
REM TradBOT Pipeline avec Validation WhatsApp
REM Usage: run_pipeline.bat [--top-n 5] [--timeout 300] [--auto]
REM
REM  --top-n N     Nombre de symboles à analyser (défaut 5)
REM  --timeout N   Secondes pour répondre OUI/NON (défaut 300 = 5 min)
REM  --auto        Valider tout automatiquement sans confirmation

title TradBOT Pipeline Approval

cd /d D:\Dev\TradBOT

set TRADINGAGENTS_REPO=D:\Dev\Depot Github\TradingAgents-main
set VENV_PYTHON=%TRADINGAGENTS_REPO%\.venv\Scripts\python.exe
set PYTHONHTTPSVERIFY=0
set REQUESTS_CA_BUNDLE=
set SSL_CERT_FILE=
set CURL_CA_BUNDLE=
set HTTPX_VERIFY=0

REM Vérifier ai_server
curl -s http://127.0.0.1:8000/health >nul 2>&1
if errorlevel 1 (
    echo [WARN] ai_server non accessible sur port 8000
    echo Lancez d'abord: python ai_server.py
    pause
)

echo.
echo ============================================================
echo   TradBOT Pipeline avec Validation WhatsApp
echo   Chaque signal sera envoyé par WhatsApp pour validation
echo   Repondez OUI SYMBOLE ou NON SYMBOLE pour chaque signal
echo ============================================================
echo.

%VENV_PYTHON% Python\pipeline_with_approval.py %*

echo.
echo Pipeline termine. Appuyez sur une touche pour fermer.
pause
