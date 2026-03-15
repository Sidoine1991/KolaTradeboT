@echo off
echo ========================================
echo COMPILATION - SMC_Universal.mq5
echo ========================================
echo.

REM Utiliser le chemin correct de MetaTrader
set METAE_EDITOR="D:\Program Files\MetaTrader 5\metaeditor64.exe"

echo Compilation de SMC_Universal.mq5...
echo.

%METAE_EDITOR% /compile SMC_Universal.mq5

echo.
echo ========================================
echo COMPILATION TERMINEE
echo ========================================
pause
