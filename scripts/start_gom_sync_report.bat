@echo off
REM GOM Sync + Rapport WhatsApp — one-shot (appele par Task Scheduler toutes les 10 min)
REM Prerequis:
REM   1. ai_server.py en cours (port 8000)
REM   2. gom_signal.json a jour dans data/
REM   3. PsychoBot actif pour livraison WhatsApp

cd /d "%~dp0.."

if not exist logs mkdir logs

python python\gom_sync_with_report.py --report >> logs\gom_sync.log 2>&1
