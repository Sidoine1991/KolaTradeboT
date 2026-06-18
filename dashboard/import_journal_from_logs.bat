@echo off
title Import journal MT5 logs -> trade_journal.csv
cd /d "%~dp0\.."
python dashboard\import_journal_from_logs.py
echo.
echo Relancez start_dashboard.bat pour voir les donnees
pause
