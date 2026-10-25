@echo off
REM Script pour copier OrderBlockPremiumDiscountStrategy.mqh vers le répertoire MetaTrader
REM Ajustez le chemin ci-dessous selon votre installation MetaTrader

set MT5_PATH=C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\MQL5\Experts

if not exist "%MT5_PATH%" (
    echo Erreur: Le répertoire MetaTrader n'existe pas: %MT5_PATH%
    echo Veuillez ajuster le chemin dans ce script.
    pause
    exit /b 1
)

copy "OrderBlockPremiumDiscountStrategy.mqh" "%MT5_PATH%\OrderBlockPremiumDiscountStrategy.mqh"

if %ERRORLEVEL% EQU 0 (
    echo Fichier copie avec succes vers: %MT5_PATH%
) else (
    echo Erreur lors de la copie du fichier.
)

pause

