@echo off
echo Testing compilation of F_INX_Scalper_double.mq5...
echo.

REM Try to find MetaEditor in common locations
for %%P in (
    "C:\Program Files\MetaTrader 5\metaeditor64.exe"
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe"
    "%LOCALAPPDATA%\MetaQuotes\Terminal\*\metaeditor64.exe"
) do (
    if exist "%%~fP" (
        set METAEDITOR="%%~fP"
        goto :found
    )
)

REM Try from PATH
where metaeditor64.exe >nul 2>&1
if %ERRORLEVEL% equ 0 (
    set METAEDITOR=metaeditor64.exe
    goto :found
)

echo MetaEditor not found
echo Please install MetaTrader 5 or add metaeditor64.exe to PATH
pause
exit /b 1

:found
echo Using MetaEditor: %METAEDITOR%
%METAEDITOR% /compile "F_INX_Scalper_double.mq5" /close

echo.
echo Compilation completed. Check the MetaEditor log for details.
pause
