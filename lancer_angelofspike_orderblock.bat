@echo off
echo ========================================
echo   ANGELOFSPIKE ORDER BLOCK - DEMARRAGE
echo ========================================
echo.

echo [1/4] Verification des fichiers...
if not exist "mt5\AngelOfSpike.mq5" (
    echo ERREUR: Fichier AngelOfSpike.mq5 non trouve
    pause
    exit /b 1
)
echo OK: Fichier AngelOfSpike.mq5 trouve

echo.
echo [2/4] Test de la strategie Order Block...
python test_angelofspike_orderblock.py
if %errorlevel% neq 0 (
    echo ERREUR: Test de la strategie echoue
    pause
    exit /b 1
)

echo.
echo [3/4] Configuration recommandee...
echo.
echo PARAMETRES ORDER BLOCK:
echo - InpEnableOrderBlocks = true
echo - InpShowOrderBlocks = true  
echo - InpOrderBlockLookback = 50
echo - InpOrderBlockMinVolume = 1.5
echo - InpOrderBlockMaxAge = 100
echo.
echo PARAMETRES GENERAUX:
echo - InpEnableTrading = true
echo - InpBoomCrashLot = 0.2
echo - InpMinSpikeM1Probability = 30.0
echo - InpDebug = true
echo.

echo [4/4] Instructions d'utilisation...
echo.
echo ETAPES SUIVANTES:
echo 1. Ouvrez MetaTrader 5
echo 2. Compilez le fichier AngelOfSpike.mq5 (F7)
echo 3. Attachez l'EA sur un graphique Boom/Crash
echo 4. Configurez les parametres selon les recommandations
echo 5. Lancez le robot et surveillez les logs
echo.
echo SYMBOLES RECOMMANDES:
echo - Boom 300 Index
echo - Crash 300 Index
echo - Boom 500 Index
echo - Crash 500 Index
echo.
echo MONITORING:
echo - Surveillez l'onglet Experts pour les logs
echo - Vérifiez les Order Blocks sur le graphique
echo - Attendez les signaux de trading
echo.

echo ========================================
echo   ROBOT PRET POUR LE TRADING!
echo ========================================
echo.
echo Appuyez sur une touche pour fermer...
pause >nul
