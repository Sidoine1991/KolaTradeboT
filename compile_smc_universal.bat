@echo off
echo ========================================
echo COMPILATION - SMC_Universal.mq5
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
echo Compilation de SMC_Universal.mq5...
echo.

"%METAPATH%" /compile "SMC_Universal.mq5" /log:compile_smc_log.txt

timeout /t 3 /nobreak >nul

if exist "SMC_Universal.ex5" (
    echo.
    echo COMPILATION REUSSIE!
    echo Fichier cree: SMC_Universal.ex5
) else (
    echo.
    echo ECHEC DE LA COMPILATION
    echo.
    echo Log de compilation:
    type compile_smc_log.txt
)

:end
echo.
pause
