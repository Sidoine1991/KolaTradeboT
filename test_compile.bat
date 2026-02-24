@echo off
echo Testing compilation...
"D:\Program Files\MetaTrader 5\metaeditor64.exe" /compile "F_INX_Scalper_double.mq5"
echo Compilation attempt completed.
if exist "F_INX_Scalper_double.ex5" (
    echo SUCCESS: .ex5 file created
) else (
    echo FAILED: No .ex5 file found
)
pause
