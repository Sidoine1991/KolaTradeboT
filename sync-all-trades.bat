@echo off
REM Synchronise TOUS les trades: export MT5 + traitement + base de données

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

echo.
echo ========================================
echo TRADE JOURNAL FULL SYNC
echo ========================================
echo.

echo [1/3] Syncing trades via AI Server...
python Python/sync_trades_via_ai_server.py

echo.
echo [2/3] Importing trades to database...
python Python/trade_journal_processor.py

echo.
echo ========================================
echo ✅ ALL TRADES SYNCED
echo ========================================
echo.
echo CSV: data/trade_journal.csv
echo DB: data/trades.db
echo Logs: logs/sync_trades_ai_server.log
echo Logs: logs/trade_journal_processor.log
echo.
