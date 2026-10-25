@echo off
echo Testing MQL5 compilation...
cd /d "d:\Dev\TradBOT\mt5"

REM Try to find MetaEditor executable
for %%f in (
    "C:\Program Files\MetaTrader 5\metaeditor.exe"
    "C:\Program Files (x86)\MetaTrader 5\metaeditor.exe"
    "C:\MetaTrader 5\metaeditor.exe"
) do (
    if exist "%%f" (
        echo Found MetaEditor at: %%f
        echo Compiling fx_robot2.mq5...
        "%%f" /compile fx_robot2.mq5
        goto :found
    )
)

echo MetaEditor not found in standard locations
echo Please check if MetaTrader 5 is installed
goto :end

:found
echo Compilation completed!

:end
pause
