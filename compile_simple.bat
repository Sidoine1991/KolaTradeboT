@echo off
echo ========================================
echo COMPILATION - F_INX_Scalper_double.mq5
echo ========================================
echo.

echo Recherche de MetaEditor...
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
    echo MetaEditor non trouve
    goto :end
)

echo.
echo Compilation de F_INX_Scalper_double.mq5...
echo.

"%METAPATH%" /compile "F_INX_Scalper_double.mq5" /log:compile_log.txt

timeout /t 3 /nobreak >nul

if exist "F_INX_Scalper_double.ex5" (
    echo.
    echo COMPILATION REUSSIE!
    echo Fichier cree: F_INX_Scalper_double.ex5
) else (
    echo.
    echo ECHEC DE LA COMPILATION
    echo.
    echo Log de compilation:
    type compile_log.txt
)

:end
echo.
pause
