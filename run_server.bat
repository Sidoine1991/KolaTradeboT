@echo off
REM Lance le serveur IA principal (racine) avec acces AWS RDS + code ML a jour
cd /d D:\Dev\TradBOT
chcp 65001 >nul 2>&1
set PYTHONIOENCODING=utf-8
set PYTHONPATH=D:\Dev\TradBOT
REM Charger python\.env (RDS_HOST...) puis .env racine si present
python -c "from dotenv import load_dotenv; from pathlib import Path; r=Path(r'D:\Dev\TradBOT'); load_dotenv(r/'python'/'.env'); load_dotenv(r/'.env')"
python ai_server.py
