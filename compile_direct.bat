@echo off
echo Compilation directe avec MetaEditor...

REM Trouver MetaEditor
set METAPATH=""
for %%f in (
    "C:\Program Files\MetaTrader 5\metaeditor64.exe"
    "C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe"
) do (
    if exist %%f (
        set METAPATH=%%f
        echo MetaEditor trouve: %%f
        goto :compile
    )
)

:compile
if "%METAPATH%"=="" (
    echo MetaEditor non trouve - veuillez compiler manuellement
    echo 1. Ouvrir MetaTrader 5
    echo 2. Presser F4 pour ouvrir MetaEditor
    echo 3. Ouvrir F_INX_scalper_double.mq5
    echo 4. Presser F7 pour compiler
    pause
    exit /b 1
)

echo Lancement de la compilation...
"%METAPATH%" /compile "F_INX_Scalper_double.mq5" /s

pause
