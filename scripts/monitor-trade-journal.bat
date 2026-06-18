@echo off
REM Monitor Trade Journal — Traite et envoie rapports des trades fermés

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

echo.
echo ========================================
echo TRADE JOURNAL MONITOR
echo ========================================
echo.

:loop
echo [%date% %time%] Checking for new trades...
python Python/trade_journal_processor.py

echo [%date% %time%] Next check in 10 minutes...
timeout /t 600 /nobreak

goto loop
