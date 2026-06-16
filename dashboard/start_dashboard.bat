@echo off
title TradBOT Trade Journal Dashboard
cd /d "%~dp0"
echo Demarrage du dashboard journal de trades...
python serve_trade_journal.py
pause
