@echo off
echo ========================================
echo Test de Compilation - fx_robot2.mq5
echo ========================================
echo.

REM Vérifier si MetaEditor est disponible
where metaeditor >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERREUR: MetaEditor n'est pas trouvé dans le PATH
    echo Veuillez installer MetaTrader 5 ou ajouter MetaEditor au PATH
    pause
    exit /b 1
)

echo MetaEditor trouve, tentative de compilation...
echo.

REM Compiler le fichier
metaeditor /compile:"d:\Dev\TradBOT\mt5\fx_robot2.mq5" /close

echo.
echo ========================================
echo Compilation terminee
echo ========================================
echo.

REM Vérifier si le fichier .ex5 a été créé
if exist "d:\Dev\TradBOT\mt5\fx_robot2.ex5" (
    echo SUCCES: Fichier fx_robot2.ex5 cree avec succes
    echo Taille du fichier:
    dir "d:\Dev\TradBOT\mt5\fx_robot2.ex5" | find "fx_robot2.ex5"
) else (
    echo ATTENTION: Fichier fx_robot2.ex5 non trouve
    echo Verifiez les erreurs dans le journal de MetaEditor
)

echo.
pause
