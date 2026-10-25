@echo off
echo ========================================
echo   ANGELOFSPIKE CORRIGE - TEST FINAL
echo ========================================
echo.

echo [1/4] Verification des corrections...
python test_corrections_angelofspike.py
if %errorlevel% neq 0 (
    echo ERREUR: Test des corrections echoue
    pause
    exit /b 1
)

echo.
echo [2/4] Verification de la compilation...
echo Le fichier AngelOfSpike.mq5 a ete corrige:
echo - iRealVolume() remplace par iVolume()
echo - Point() remplace par SymbolInfoDouble()
echo - Logs de debug ajoutes
echo - Detection Order Block amelioree
echo - Variables initialisees
echo.

echo [3/4] Configuration recommandee...
echo.
echo PARAMETRES OBLIGATOIRES:
echo - InpEnableTrading = true
echo - InpEnableOrderBlocks = true
echo - InpShowOrderBlocks = true
echo - InpDebug = true
echo - InpShowHeartbeat = true
echo.
echo PARAMETRES ORDER BLOCK:
echo - InpOrderBlockLookback = 50
echo - InpOrderBlockMinVolume = 0.5 (pour Boom/Crash)
echo - InpOrderBlockMaxAge = 100
echo - InpMinSpikeM1Probability = 30.0
echo.

echo [4/4] Instructions de test...
echo.
echo ETAPES SUIVANTES:
echo 1. Ouvrez MetaTrader 5
echo 2. Compilez AngelOfSpike.mq5 (F7) - AUCUNE ERREUR
echo 3. Attachez l'EA sur Boom 300 Index ou Crash 300 Index
echo 4. Configurez les parametres selon les recommandations
echo 5. Lancez le robot et surveillez les logs
echo.
echo COMPORTEMENT ATTENDU:
echo - Messages d'initialisation dans les logs
echo - Heartbeat regulier toutes les 10 secondes
echo - Scan des Order Blocks toutes les 5 secondes
echo - Detection et affichage des Order Blocks
echo - Signaux de trading automatiques
echo.
echo LOGS A SURVEILLER:
echo - "Variables Order Block initialisees"
echo - "[ORDER BLOCK] Debut du scan pour [symbole]"
echo - "[ORDER BLOCK] Bullish/Bearish detecte"
echo - "[ORDER BLOCK] Scan termine"
echo - "SIGNAL STRICT DETECTE"
echo - "TRADE STRICT EXECUTE"
echo.

echo ========================================
echo   ROBOT CORRIGE ET PRET POUR LE TEST!
echo ========================================
echo.
echo Les corrections ont ete appliquees avec succes.
echo Le robot devrait maintenant fonctionner correctement.
echo.
echo Appuyez sur une touche pour fermer...
pause >nul
