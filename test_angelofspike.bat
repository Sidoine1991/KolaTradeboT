@echo off
echo ========================================
echo    TEST ANGEL OF SPIKE - SCALPING
echo ========================================
echo.
echo Ce script teste le robot Angel of Spike avec le scalping automatique.
echo.
echo Verifications:
echo - 1. Compilation du fichier MQ5
echo - 2. Verification des parametres de scalping
echo - 3. Test de l'API de tendance
echo.

echo 1. Verification de la compilation...
echo Le fichier AngelOfSpike.mq5 doit etre compile dans MetaTrader 5
echo.

echo 2. Parametres de scalping actives:
echo - InpEnableAutoScalping = true
echo - InpScalpMaxLossUSD = 3.50
echo - InpScalpTargetProfitUSD = 5.00
echo - InpScalpMinIntervalSec = 60
echo.

echo 3. Symboles configures:
echo - Boom 300 Index, Crash 300 Index
echo - Boom 500 Index, Crash 500 Index  
echo - Boom 1000 Index, Crash 1000 Index
echo.

echo 4. Test de l'API de tendance...
echo Demarrage de l'API sur le port 8001...
start "Trend API" cmd /k "cd /d D:\Dev\TradBOT && python trend_api.py"
echo.

echo 5. Instructions pour MetaTrader 5:
echo - Ouvrir MetaTrader 5
echo - Compiler AngelOfSpike.mq5
echo - Attacher l'EA a un graphique Boom ou Crash
echo - Verifier que les flèches de prediction apparaissent
echo - Verifier que les positions s'ouvrent automatiquement
echo.

echo 6. Surveillance des logs:
echo - Ouvrir l'onglet "Experts" dans MetaTrader 5
echo - Chercher les messages "SIGNAL EMA DETECTE" ou "SPIKE PREDIT"
echo - Verifier les messages "Position ouverte au marche"
echo.

pause
