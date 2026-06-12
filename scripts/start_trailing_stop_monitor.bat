@echo off
REM Lance le monitoring de trailing stop + breakeven SL
REM Met à jour automatiquement les SL des positions ouvertes

setlocal enabledelayedexpansion

cd /d D:\Dev\TradBOT

echo.
echo ================================
echo Trailing Stop Monitor
echo ================================
echo Time: %date% %time%
echo.
echo Mode: Monitoring continu (toutes les 5 sec)
echo Logs: D:\Dev\TradBOT\logs\trademanager_sync.log
echo.
echo - Breakeven SL @ $2 profit
echo - Trailing Stop (0.5%%)
echo - SL jamais descend (seulement monte)
echo.
echo Ctrl+C pour arrêter
echo.

python Python\trademanager_position_sync.py

pause
