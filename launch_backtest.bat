@echo off
REM Lancer MT5 et ouvrir Strategy Tester
cd /d "D:\Program Files\MetaTrader 5"

REM Lancer terminal avec profile E6E3D0917DD641581E4779524EB3B1AA
start terminal.exe /profile:E6E3D0917DD641581E4779524EB3B1AA

REM Attendre que MT5 se charge
timeout /t 10 /nobreak

REM Envoyer ALT+R pour ouvrir Strategy Tester
powershell -Command "Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait('%r')"

timeout /t 2 /nobreak

REM Configuration du backtest :
REM - Symbol: Boom 1000
REM - Timeframe: M1
REM - EA: deriveapro.mq5
REM - Periode: Dernieres 7 jours
REM - Optimisation: OFF

echo.
echo === Backtest lancé ===
echo Symbol: Boom 1000
echo Timeframe: M1
echo EA: deriveapro.mq5
echo Periode: 7 derniers jours
echo.
echo Configurez manuellement dans Strategy Tester et cliquez START
pause
