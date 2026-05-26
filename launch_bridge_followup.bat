@echo off
REM Suivi WhatsApp toutes les 10 min (pending + biais + etat unifie)
cd /d "%~dp0"
set SYMBOL=%1
if "%SYMBOL%"=="" set SYMBOL=BOOM 600 INDEX
python python\bridge_followup_monitor.py --symbol "%SYMBOL%" --interval 600
