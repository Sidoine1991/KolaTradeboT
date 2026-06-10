@echo off
setlocal enabledelayedexpansion

set "METAEDITOR=C:\Program Files\MetaTrader 5\metaeditor64.exe"
set "EA=D:\Dev\TradBOT\mt5\UploadCandlesEA.mq5"

echo Recompiling UploadCandlesEA.mq5 (interval now = 1 minute)...
echo.

"%METAEDITOR%" /compile:"%EA%" /exit

echo.
echo Done! Reattach the EA to the chart and check Expert logs (Ctrl+T)
echo You should see "UploadCandlesEA v2.0 STARTED" in the logs
pause
