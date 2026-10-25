@echo off
echo ============================================================
echo   SYSTEME SMC SIMPLIFIE - DEMARRAGE
echo ============================================================
echo.

REM Activer l'environnement Python
call python -m venv venv
call venv\Scripts\activate

REM Installer les dépendances
echo Installation des dependances...
pip install MetaTrader5 pandas numpy

echo.
echo ============================================================
echo   OPTIONS
echo ============================================================
echo.
echo 1. Test du systeme
echo 2. Lancement du systeme automatique
echo 3. Quitter
echo.

set /p choice="Votre choix (1-3): "

if "%choice%"=="1" (
    echo.
    echo Lancement des tests...
    python test_smc_system.py
)

if "%choice%"=="2" (
    echo.
    echo Lancement du systeme automatique...
    python srmc_trading_system.py
)

if "%choice%"=="3" (
    exit
)

echo.
echo Appuyez sur une touche pour fermer...
pause >nul
