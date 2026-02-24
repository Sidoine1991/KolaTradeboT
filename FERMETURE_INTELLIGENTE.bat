@echo off
echo ========================================
echo FERMETURE INTELLIGENTE - CASSURES & LIMITES
echo ========================================
echo.
echo ✅ NOUVELLES LOGIQUES DE FERMETURE:
echo.
echo 1. DÉTECTION DE CASSURE SANS RETOURNEMENT:
echo    📊 Analyse des bougies M5 (vraies données)
echo    🔍 Bougie forte = corps > 70% de la range
echo    🚨 Fermeture si 2+ bougies fortes SAME DIRECTION + cassure
echo    📈 BUY: bougies baissières fortes qui cassent le support
echo    📉 SELL: bougies haussières fortes qui cassent la résistance
echo.
echo 2. LIMITES DE PERTE SPÉCIFIQUES:
echo    💥 Boom/Crash: perte maximale = 3$ par position
echo    💥 Autres symboles: perte maximale = 5$ par position
echo    🛡️ Protection automatique immédiate
echo.
echo 3. RÈGLES EXISTANTES CONSERVÉES:
echo    💰 Volatility: fermeture obligatoire à 2$ profit
echo    🚀 Boom/Crash: fermeture après capture spike
echo    ✅ Autres: fermeture optionnelle à 2$ profit
echo.
echo ========================================
echo LOGS DE FERMETURE INTELLIGENTE:
echo ========================================
echo.
echo 🚨 CASSURE SANS RETOURNEMENT:
echo    "🚨 CASSURE SANS RETOURNEMENT: Support cassé après 2 bougies fortes M5"
echo    "   Prix actuel: 1.08567"
echo    "   Niveau cassé: 1.08550"
echo    "   Dernière bougie M5: 1.08545 (range: 0.00025)"
echo    "   Perte: -2.35$"
echo.
echo 🛑 LIMITE DE PERTE ATTEINTE:
echo    "🛑 Position fermée: Perte maximale atteinte (-3.00$ <= -3.00$) - PROTECTION"
echo    "   Type symbole: Boom/Crash (limite 3$)"
echo.
echo 💰 VOLATILITY PROFIT:
echo    "💰 VOLATILITY: Fermeture obligatoire à 2$ atteints (2.15$)"
echo.
echo 🚀 BOOM/CRASH SPIKE:
echo    "🚀 BOOM/CRASH: Spike capturé! Fermeture après pic (max: 3.45$, actuel: 2.76$)"
echo.
echo ========================================
echo FONCTIONNEMENT DÉTAILLÉ:
echo ========================================
echo.
echo 1. SURVEILLANCE CONTINUE:
echo    - Vérification toutes les 5 minutes (M5)
echo    - Analyse des 2 dernières bougies M5
echo    - Détection de direction et force
echo.
echo 2. LOGIQUE DE CASSURE:
echo    - Position BUY: surveillance cassure support
echo    - Position SELL: surveillance cassure résistance
echo    - Condition: bougies fortes SAME DIRECTION + cassure
echo    - Action: fermeture immédiate + recherche nouvelle entrée
echo.
echo 3. PROTECTION CAPITAL:
echo    - Limite perte: 3$ (Boom/Crash) ou 5$ (autres)
echo    - Fermeture automatique si limite atteinte
echo    - Logs détaillés pour analyse
echo.
echo ========================================
echo AVANTAGES:
echo ========================================
echo.
echo ✅ Évite les pertes excessives sur cassures
echo ✅ Détecte les changements de tendance M5
echo ✅ Limites de perte adaptées par type de symbole
echo ✅ Logs complets pour suivi et optimisation
echo ✅ Recherche automatique de nouvelle entrée après cassure
echo.
echo ========================================
echo INSTRUCTIONS:
echo ========================================
echo.
echo 1. Compilez F_INX_Scalper_double.mq5
echo 2. Redémarrez le robot sur MT5
echo 3. Surveillez les logs pour:
echo    - "🚨 CASSURE SANS RETOURNEMENT" (cassure détectée)
echo    - "🛑 Position fermée: Perte maximale" (protection)
echo    - "💰 VOLATILITY: Fermeture obligatoire" (profit sécurisé)
echo.
echo ⚠️ Le robot fermera automatiquement sur:
echo    - Cassure de support/résistance sans retournement
echo    - Perte de 3$ (Boom/Crash) ou 5$ (autres)
echo    - Profit de 2$ (Volatility) ou spike capturé (Boom/Crash)
echo.
echo 🎉 FERMETURE INTELLIGENTE ACTIVÉE!
echo.
pause
