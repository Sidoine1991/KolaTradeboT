@echo off
echo Compilation rapide SMC_Universal.mq5
echo.
set METAE_EDITOR="D:\Program Files\MetaTrader 5\metaeditor64.exe"
%METAE_EDITOR% /compile SMC_Universal.mq5
echo.
echo Compilation terminée.
pause
