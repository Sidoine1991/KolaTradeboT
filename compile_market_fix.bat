@echo off
echo Compiling F_INX_Scalper_double.mq5 with market hours fix...
echo.

REM Try to find MetaEditor in common locations
set METEDITOR_PATH=""

if exist "C:\Program Files\MetaTrader 5\metaeditor64.exe" (
    set METEDITOR_PATH="C:\Program Files\MetaTrader 5\metaeditor64.exe"
) else if exist "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe" (
    set METEDITOR_PATH="C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe"
) else (
    echo MetaEditor64.exe not found in standard locations
    echo Please compile manually in MetaTrader 5 terminal
    pause
    exit /b 1
)

echo Found MetaEditor at: %METEDITOR_PATH%
echo.

REM Compile the file
%METEDITOR_PATH% /compile:"F_INX_Scalper_double.mq5" /close

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Compilation successful!
    echo Market hours fix has been applied to F_INX_Scalper_double.mq5
    echo.
    echo The fix prevents false "Market Closed" detection for:
    echo - Boom indices (24/7 trading)
    echo - Crash indices (24/7 trading) 
    echo - Volatility indices (24/7 trading)
    echo - Step indices (24/7 trading)
    echo.
    echo Normal forex symbols will still respect market hours.
) else (
    echo.
    echo ❌ Compilation failed!
    echo Please check for syntax errors in the file.
)

pause
