@echo off
echo ========================================
echo COMPILATION - SMC_Universal.mq5
echo ========================================
echo.

REM Chercher MetaEditor
set METAE_EDITOR="C:\Program Files\MetaTrader 5\metaeditor64.exe"
if not exist %METAE_EDITOR% set METAE_EDITOR="C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe"

echo Compilation de SMC_Universal.mq5...
echo.

%METAE_EDITOR% /compile SMC_Universal.mq5

echo.
echo ========================================
echo COMPILATION TERMINEE
echo ========================================
pause
