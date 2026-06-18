@echo off
REM Simple direct compilation of SMC_Universal.mq5

echo.
echo Deleting old compiled files...
del /Q "D:\Dev\TradBOT\mt5\SMC_Universal.ex5" 2>nul

echo Compiling SMC_Universal.mq5...
echo.

"D:\Program Files\MetaTrader 5\MetaEditor64.exe" "D:\Dev\TradBOT\mt5\SMC_Universal.mq5" /compile

echo.
if exist "D:\Dev\TradBOT\mt5\SMC_Universal.ex5" (
    echo ✅ SUCCESS! Binary created.
    echo Location: D:\Dev\TradBOT\mt5\SMC_Universal.ex5
) else (
    echo ❌ Failed to compile. Check output above.
)

pause
