@echo off
schtasks /create /tn "TradBOT\GOM-Sync-10min" /tr "D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat" /sc minute /mo 10 /f
echo.
schtasks /query /tn "TradBOT\GOM-Sync-10min" /v /fo list
