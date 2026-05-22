@echo off
REM Lance le serveur ai_server avec environnement propre
setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT
set PYTHONIOENCODING=utf-8
set PYTHONPATH=D:\Dev\TradBOT

echo.
echo ========================================
echo   TradBOT IA Server Launcher
echo ========================================
echo.

REM Charger dotenv
python -c "from dotenv import load_dotenv; from pathlib import Path; r=Path(r'D:\Dev\TradBOT'); load_dotenv(r/'python'/'.env'); load_dotenv(r/'.env'); print('OK: Environment loaded')" 2>nul

echo.
echo Starting ai_server.py on http://localhost:8000
echo API Docs: http://localhost:8000/docs
echo.

REM Lancer le serveur
python ai_server.py --port 8000

pause
