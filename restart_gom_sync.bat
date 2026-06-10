@echo off
REM Tue tous les pollers et relance le bon
echo [GOM Sync] Stopping old processes...
taskkill /F /IM python.exe /T 2>nul
timeout /T 2 /NOBREAK

echo [GOM Sync] Starting new sync...
cd /d D:\Dev\TradBOT
python gom_sync_working.py

pause
