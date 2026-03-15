@echo off
echo ========================================
echo COMPILATION TEST - compile_test.mq5
echo ========================================
echo.

set METAE_EDITOR="D:\Program Files\MetaTrader 5\metaeditor64.exe"

echo Compilation de compile_test.mq5...
echo.

%METAE_EDITOR% /compile compile_test.mq5

echo.
echo ========================================
echo COMPILATION TERMINEE
echo ========================================
pause
