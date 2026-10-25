@echo off
echo Testing compilation of F_INX_Scalper_double.mq5...
echo.

REM Try to find MetaEditor
if exist "C:\Program Files\MetaTrader 5\metaeditor64.exe" (
    set METAEDITOR="C:\Program Files\MetaTrader 5\metaeditor64.exe"
) else if exist "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe" (
    set METAEDITOR="C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe"
) else (
    echo MetaEditor not found in standard locations
    echo Trying to use metaeditor64 from PATH...
    set METAEDITOR=metaeditor64.exe
)

echo Using: %METAEDITOR%
%METAEDITOR% /compile "F_INX_Scalper_double.mq5" /close

echo.
echo Compilation test completed.
pause
