@echo off
REM ============================================================================
REM start_mt5_stack.bat — lance les 4 workers MT5, puis ai_server, puis le poller
REM
REM Ordre important : les workers doivent etre up (connexion au terminal en
REM cours) AVANT ai_server et gom_mt5_poller, sinon les premiers appels
REM /candles echoueront le temps que chaque worker se connecte.
REM
REM Place ce fichier a la racine du projet (a cote de ai_server.py, python\, etc.)
REM et adapte les chemins ci-dessous si besoin.
REM ============================================================================

cd /d %~dp0

echo [1/6] Lancement worker Weltrade (port 8010)...
start "MT5-Worker-Weltrade" cmd /k python python\mt5_worker.py --broker weltrade

echo [2/6] Lancement worker Deriv (port 8011)...
start "MT5-Worker-Deriv" cmd /k python python\mt5_worker.py --broker deriv

echo [3/6] Lancement worker StarTrader (port 8012)...
start "MT5-Worker-StarTrader" cmd /k python python\mt5_worker.py --broker startrader

echo [4/6] Lancement worker XMGlobal (port 8013)...
start "MT5-Worker-XMGlobal" cmd /k python python\mt5_worker.py --broker xmglobal

echo Attente 15s — laisse le temps aux 4 workers de se connecter a leur terminal...
timeout /t 15 /nobreak

echo [5/6] Lancement ai_server.py...
start "AI-Server" cmd /k python ai_server.py

echo Attente 8s — laisse ai_server demarrer avant le poller...
timeout /t 8 /nobreak

echo [6/6] Lancement gom_mt5_poller.py...
start "GOM-Poller" cmd /k python python\gom_mt5_poller.py

echo.
echo Stack complete lancee dans 6 fenetres separees.
echo Verifie chaque fenetre worker : elle doit logger "Connecte [broker]: ...".
echo.
pause
