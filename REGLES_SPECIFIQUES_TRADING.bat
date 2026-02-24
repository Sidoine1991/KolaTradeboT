@echo off
echo ========================================
echo RÈGLES SPÉCIFIQUES DE TRADING IMPLÉMENTÉES
echo ========================================
echo.
echo ✅ NOUVELLES RÈGLES PAR TYPE DE SYMBOLE:
echo.
echo 1. VOLATILITY INDICES:
echo    🎯 Fermeture OBLIGATOIRE à 2$ de profit
echo    📊 Log: "💰 VOLATILITY: Fermeture obligatoire à 2$ atteints"
echo    ⚡ Exécution immédiate dès 2$ atteints
echo.
echo 2. BOOM/CRASH INDICES:
echo    🚀 Fermeture après capture du spike
echo    📈 Détection: profit commence à baisser après pic (20% de baisse)
echo    🎯 Seuil minimum: 0.50$ pour confirmer spike capturé
echo    📊 Log: "🚀 BOOM/CRASH: Spike capturé! Fermeture après pic"
echo    ⏱️ Vérification chaque seconde
echo.
echo 3. AUTRES SYMBOLES (Forex, etc.):
echo    💰 Fermeture optionnelle à 2$ de profit
echo    📊 Log: "✅ Position fermée: Profit individuel atteint"
echo.
echo ========================================
echo CONDITIONS PRÉALABLES OBLIGATOIRES:
echo ========================================
echo.
echo 🔍 AVANT TOUT TRADE:
echo    ✅ Flèche DERIV visible sur le graphique
echo    ✅ Décision finale différente de "WAIT" ou "HOLD"
echo    ✅ Confiance IA >= seuil requis
echo.
echo 📊 LOGS DE VÉRIFICATION:
echo    "🔍 Vérification conditions obligatoires:"
echo    "   Flèche DERIV présente: ✅/❌"
echo    "   Décision finale: BUY/SELL (xx.x%)"
echo    "   Décision non-WAIT: ✅/❌"
echo.
echo ========================================
echo FONCTIONNEMENT:
echo ========================================
echo.
echo 1. ATTENTE:
echo    - Robot attend l'apparition de la flèche verte/rouge
echo    - Robot attend que la décision finale ne soit pas "WAIT"
echo    - Logs: "⏳ Conditions non remplies - attente flèche et/ou décision finale"
echo.
echo 2. EXÉCUTION:
echo    - Dès que flèche + décision finale OK → trade exécuté
echo    - Logs: "✅ Conditions remplies - exécution du trade..."
echo    - SL/TP désactivés pour Boom/Crash
echo.
echo 3. FERMETURE:
echo    - Volatility: automatique à 2$
echo    - Boom/Crash: automatique après pic du spike
echo    - Autres: optionnelle à 2$
echo.
echo ========================================
echo SÉCURITÉ:
echo ========================================
echo.
echo ✅ Plus d'erreurs "Invalid stops" (SL/TP désactivés Boom/Crash)
echo ✅ Gestion automatique des profits par type de symbole
echo ✅ Conditions préalables strictes évitent les trades prématurés
echo ✅ Logs détaillés pour suivi et débogage
echo.
echo ========================================
echo INSTRUCTIONS:
echo ========================================
echo.
echo 1. Compilez F_INX_Scalper_double.mq5
echo 2. Redémarrez le robot sur MT5
echo 3. Surveillez les logs pour vérifier:
echo    - "⏳ Conditions non remplies" (attente normale)
echo    - "✅ Conditions remplies" (trade imminent)
echo    - "💰 VOLATILITY: Fermeture obligatoire" (profit sécurisé)
echo    - "🚀 BOOM/CRASH: Spike capturé" (spike bien capturé)
echo.
echo 🎉 RÈGLES SPÉCIFIQUES ACTIVES!
echo.
pause
