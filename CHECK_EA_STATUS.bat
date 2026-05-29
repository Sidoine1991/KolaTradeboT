@echo off
REM Attendre que MT5 se charge (30 sec)
echo ⏳ Attente du chargement MT5...
timeout /T 30 /nobreak

REM Vérifier les fichiers source
echo.
echo ════════════════════════════════════════════════════════════════
echo 📋 VÉRIFICATION DES PARAMÈTRES SOURCE
echo ════════════════════════════════════════════════════════════════

echo.
echo [TradeManager.mq5]
findstr "GOMBlockOnWait = " "D:\Dev\TradBOT\TradeManager.mq5" | findstr /R "false|true"
echo.
findstr "GOMMinCoherence = " "D:\Dev\TradBOT\TradeManager.mq5"
echo.
findstr "MinTAConfidence = " "D:\Dev\TradBOT\TradeManager.mq5"
echo.

echo [SpikeRiderEA.mq5]
findstr "InpGOMBlockOnWait = " "D:\Dev\TradBOT\SpikeRiderEA.mq5" | findstr /R "false|true"
echo.
findstr "InpSniperMinConfidence = " "D:\Dev\TradBOT\SpikeRiderEA.mq5"
echo.

echo ════════════════════════════════════════════════════════════════
echo.
echo ✅ Vérifier dans MT5:
echo   1. Experts -> EA autorité activée (Allow algorithmic trading)
echo   2. Terminals -> Connecté au serveur de trading
echo   3. Charts -> TradeManager et SpikeRiderEA chargés
echo   4. Logs -> Messages "[GOM-Auto]" et "[SpikeRider]"
echo.
echo 🚀 Si les signaux continuent d'être ignorés:
echo   - Vérifier que GOMBlockOnWait = false (pas = true)
echo   - Relancer MetaEditor avec F5 (compile)
echo   - Relancer les EAs (detach/attach)
echo.
pause
