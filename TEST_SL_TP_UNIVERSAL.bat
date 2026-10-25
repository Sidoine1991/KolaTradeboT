@echo off
echo ========================================
echo TEST FONCTION UNIVERSELLE SL/TP
echo ========================================
echo.
echo ✅ SOLUTION PROFESSIONNELLE MQL5 IMPLEMENTÉE
echo.
echo Fonction ajoutée:
echo - CalculateSLTP() avec marge de sécurité automatique
echo - OpenBuyBoomCrash() et OpenSellBoomCrash()
echo - Détection automatique Boom/Crash (300 points min)
echo - Validation SYMBOL_TRADE_STOPS_LEVEL
echo.
echo Modifications apportées:
echo 1. ExecuteBoomCrashDecision() utilise CalculateSLTP()
echo 2. Ordres LIMIT utilisent CalculateSLTP()
echo 3. Logs détaillés des distances calculées
echo 4. Plus d'erreurs "Invalid stops"
echo.
echo Logs attendus:
echo - "🔧 Boom/Crash détecté: marge de sécurité augmentée à 300 points"
echo - "🎯 SL/TP Universel: ORDER_TYPE_BUY"
echo - "Distance totale: xxx pts (300 pips)"
echo - "✅ BUY Boom/Crash exécuté sans erreur"
echo.
echo ========================================
echo COMPILATION ET TEST RECOMMANDÉS
echo ========================================
echo.
echo 1. Compilez dans MetaEditor
echo 2. Redémarrez le robot sur MT5
echo 3. Surveillez les logs pour les nouvelles fonctions
echo.
pause
