@echo off
cd /d "D:\Dev\TradBOT"
"D:\Program Files\MetaTrader 5\MetaEditor64.exe" /compile:"D:\Dev\TradBOT\TradeManager.mq5" /log:"D:\Dev\TradBOT\mt5\test_log.txt"
timeout /t 10
type "D:\Dev\TradBOT\mt5\test_log.txt" | findstr /I "error result warning"
