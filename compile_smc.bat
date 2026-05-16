@echo off
REM Compiler SMC_Universal.mq5 avec MetaTrader 5

cd D:\Dev\TradBOT

REM Chercher le compilateur mql64.exe
for /F "delims=" %%i in ('where mql64.exe 2^>nul') do set MQL_COMPILER=%%i

if "%MQL_COMPILER%"=="" (
    echo Recherche dans Program Files...
    if exist "C:\Program Files\MetaTrader 5\mql64.exe" (
        set MQL_COMPILER=C:\Program Files\MetaTrader 5\mql64.exe
    ) else if exist "C:\Program Files (x86)\MetaTrader 5\mql64.exe" (
        set MQL_COMPILER=C:\Program Files (x86)\MetaTrader 5\mql64.exe
    ) else (
        echo ❌ Compilateur MQL5 non trouvé !
        exit /b 1
    )
)

echo ✅ Compilateur trouvé: %MQL_COMPILER%

REM Compiler
"%MQL_COMPILER%" /compile:SMC_Universal.mq5 /log:compile.log

if %ERRORLEVEL% equ 0 (
    echo ✅ Compilation réussie !
    type compile.log
) else (
    echo ❌ Erreur de compilation
    type compile.log
    exit /b 1
)

pause
