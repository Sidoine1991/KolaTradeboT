@echo off
echo Compilation de F_INX_scalper_double.mq5 avec FVG et Order Blocks...
cd /d "d:\Dev\TradBOT\mt5"

REM Chercher MetaEditor dans les emplacements courants
if exist "C:\Program Files\MetaTrader 5\metaeditor64.exe" (
    "C:\Program Files\MetaTrader 5\metaeditor64.exe" /compile F_INX_scalper_double.mq5
) else if exist "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe" (
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe" /compile F_INX_scalper_double.mq5
) else (
    echo MetaEditor non trouvé. Veuillez compiler manuellement dans MetaEditor.
    pause
)

echo Compilation terminée.
pause
