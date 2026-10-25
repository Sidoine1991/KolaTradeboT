@echo off
echo Test de compilation de fx_robot2.mq5...
echo.

REM Essayer les chemins possibles pour MetaEditor
set ME_PATH1="C:\Program Files\MetaTrader 5\metaeditor64.exe"
set ME_PATH2="C:\Program Files (x86)\MetaTrader 5\metaeditor64.exe"
set ME_PATH3="C:\Program Files\MetaTrader 5\metaeditor.exe"
set ME_PATH4="C:\Program Files (x86)\MetaTrader 5\metaeditor.exe"

if exist %ME_PATH1% (
    echo Utilisation de: %ME_PATH1%
    %ME_PATH1% /compile fx_robot2.mq5
    if %errorlevel% equ 0 (
        echo Compilation réussie!
    ) else (
        echo Erreur de compilation: %errorlevel%
    )
    goto :end
)

if exist %ME_PATH2% (
    echo Utilisation de: %ME_PATH2%
    %ME_PATH2% /compile fx_robot2.mq5
    if %errorlevel% equ 0 (
        echo Compilation réussie!
    ) else (
        echo Erreur de compilation: %errorlevel%
    )
    goto :end
)

if exist %ME_PATH3% (
    echo Utilisation de: %ME_PATH3%
    %ME_PATH3% /compile fx_robot2.mq5
    if %errorlevel% equ 0 (
        echo Compilation réussie!
    ) else (
        echo Erreur de compilation: %errorlevel%
    )
    goto :end
)

if exist %ME_PATH4% (
    echo Utilisation de: %ME_PATH4%
    %ME_PATH4% /compile fx_robot2.mq5
    if %errorlevel% equ 0 (
        echo Compilation réussie!
    ) else (
        echo Erreur de compilation: %errorlevel%
    )
    goto :end
)

echo MetaEditor non trouve dans les chemins standards.
echo Verifiez l'installation de MetaTrader 5.
goto :eof

:end
echo.
echo Test termine.
pause
