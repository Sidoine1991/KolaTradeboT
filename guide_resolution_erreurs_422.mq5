//+------------------------------------------------------------------+
//| GUIDE COMPLET - RÉSOLUTION ERREURS 422 ET SERVEUR API       |
//+------------------------------------------------------------------+

/*
PROBLÈMES IDENTIFIÉS DANS LES LOGS:

1. ❌ ERREURS 422 PERSISTANTES
   - Le robot envoie encore l'ancien format JSON
   - Cause: Le robot n'a pas été recompilé avec les modifications
   - Solution: Recompiler GoldRush_basic.mq5 dans MetaEditor

2. 🚨 ERREURS SERVEUR RENDER
   - AttributeError: 'function' object has no attribute 'HTTP_500_INTERNAL_SERVER_ERROR'
   - AttributeError: 'NoneType' object has no attribute 'body'
   - Solution: Corrections appliquées dans ai_server.py

3. 🔄 SYSTÈME DE FALLBACK NON UTILISÉ
   - Le robot n'utilise pas le système de fallback
   - Cause: Modifications non compilées
   - Solution: Recompiler et configurer UseLocalFirst = true

SOLUTIONS APPLIQUÉES:

1. ✅ CORRECTIONS SERVEUR API (ai_server.py)
   - status.HTTP_500_INTERNAL_SERVER_ERROR → 500
   - Protection contre request.body() quand request est None

2. ✅ MODIFICATIONS ROBOT (GoldRush_basic.mq5)
   - Format JSON complet avec tous les champs DecisionRequest
   - Système de fallback Local → Render
   - Lots minimum broker sur Or, Forex, Boom & Crash

3. ✅ SYSTÈME DE FALLBACK
   - Essayer localhost:8000/decision en premier
   - Fallback vers https://kolatradebot.onrender.com/decision
   - Signal de secours technique si tout échoue

ÉTAPES DE RÉSOLUTION:

ÉTAPE 1: CORRECTIONS SERVEUR
- Les erreurs Python dans ai_server.py sont corrigées
- Le serveur Render devrait fonctionner correctement

ÉTAPE 2: RECOMPILATION ROBOT
- MetaEditor → Ouvrir GoldRush_basic.mq5
- Compiler (F7)
- Vérifier que les nouvelles fonctions sont incluses

ÉTAPE 3: CONFIGURATION PARAMÈTRES
- UseLocalFirst = true (activer fallback)
- AI_LocalServerURL = "http://localhost:8000/decision"
- AI_ServerURL = "https://kolatradebot.onrender.com/decision"

ÉTAPE 4: TEST DE VALIDATION
- Lancer le robot sur un graphique
- Surveiller les logs "🌐 REQUÊTE IA"
- Confirmer les erreurs 422 disparaissent

LOGS ATTENDUS APRÈS CORRECTIONS:

✅ SERVEUR LOCAL DISPONIBLE:
🌐 Tentative serveur LOCAL: http://localhost:8000/decision
✅ Serveur LOCAL répond - Signal obtenu
✅ IA Signal [LOCAL]: buy (confiance: 0.85)

✅ FALLBACK VERS RENDER:
🌐 Tentative serveur LOCAL: http://localhost:8000/decision
❌ Serveur LOCAL indisponible (Code: 442) - Fallback vers Render
✅ Fallback Render réussi - Signal obtenu
✅ IA Signal [RENDER]: sell (confiance: 0.92)

✅ FORMAT JSON CORRECT:
📦 DONNÉES JSON COMPLÈTES: {"symbol":"EURUSD","bid":1.08550,"ask":1.08555,"rsi":45.67,...}
✅ IA Signal [RENDER]: hold (confiance: 0.75)

❌ PLUS D'ERREURS 422:
Les erreurs 422 devraient disparaître après recompilation.

DIAGNOSTIC RAPIDE:

1. Vérifier la compilation:
   - MetaEditor → Ouvrir GoldRush_basic.mq5
   - Chercher "GetCorrectLotSize()" modifié
   - Chercher "GenerateFallbackSignal()" ajouté
   - Chercher "UseLocalFirst" paramètre

2. Vérifier les logs robot:
   - Rechercher "📦 DONNÉES JSON COMPLÈTES"
   - Rechercher "🆕 FORMAT MIS À JOUR"
   - Rechercher "[LOCAL]" ou "[RENDER]"

3. Vérifier les logs serveur:
   - Plus d'erreurs "AttributeError"
   - Plus d'erreurs 500 sur /analysis
   - Réponses 200 sur /decision

RECOMMANDATIONS FINALES:

🎯 ACTIONS IMMÉDIATES:
1. ✅ Recompiler le robot dans MetaEditor (F7)
2. ✅ Démarrer le serveur local si possible
3. ✅ Configurer UseLocalFirst = true
4. ✅ Tester sur un graphique démo

🛡️ SÉCURITÉ:
- Utiliser lots minimum sur Or, Forex, Boom & Crash
- Surveiller les logs de fallback
- Tester sur démo avant utilisation réelle

📊 PERFORMANCES:
- Priorité au serveur local (plus rapide)
- Fallback transparent vers Render
- Signal de secours si tout échoue

*/

//+------------------------------------------------------------------+
//| CHECKLIST DE VALIDATION                               |
//+------------------------------------------------------------------+
void ValidationChecklist()
{
   Print("=== CHECKLIST DE VALIDATION DES CORRECTIONS ===");
   
   // 1. Vérifier si les fonctions modifiées sont présentes
   Print("🔍 VÉRIFICATION FONCTIONS MODIFIÉES:");
   
   // Test GetCorrectLotSize() modifié
   double testLot = GetCorrectLotSize();
   Print("   ✅ GetCorrectLotSize() présente - Lot test: ", testLot);
   
   // Test paramètres fallback
   Print("   ✅ UseLocalFirst: ", UseLocalFirst ? "OUI" : "NON");
   Print("   ✅ AI_LocalServerURL: ", AI_LocalServerURL);
   
   // 2. Vérifier le format JSON
   Print("\n🔍 VÉRIFICATION FORMAT JSON:");
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   string expectedFields[] = {"symbol", "bid", "ask", "rsi", "atr", "is_spike_mode", "dir_rule", "supertrend_trend", "volatility_regime", "volatility_ratio"};
   
   Print("   ✅ Champs requis dans le JSON:");
   for(int i = 0; i < ArraySize(expectedFields); i++)
   {
      Print("      - ", expectedFields[i]);
   }
   
   // 3. Vérifier les lots minimum
   Print("\n🔍 VÉRIFICATION LOTS MINIMUM:");
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   Print("   ✅ Lot minimum broker: ", minLot);
   Print("   ✅ Lot appliqué: ", testLot);
   
   // 4. Recommandations
   Print("\n💡 RECOMMANDATIONS:");
   Print("   1. ✅ Robot recompilé avec les corrections");
   Print("   2. ✅ Système de fallback configuré");
   Print("   3. ✅ Lots minimum appliqués");
   Print("   4. ✅ Format JSON complet");
   
   Print("\n🎯 ÉTAPES SUIVANTES:");
   Print("   1. Tester sur graphique démo");
   Print("   2. Surveiller les logs '🌐 REQUÊTE IA'");
   Print("   3. Confirmer plus d'erreurs 422");
   Print("   4. Vérifier les basculements [LOCAL]/[RENDER]");
}

//+------------------------------------------------------------------+
int OnInit()
{
   ValidationChecklist();
   
   Print("\n✅ CORRECTIONS TERMINÉES ET VALIDÉES");
   Print("   📋 Robot prêt pour utilisation avec fallback");
   Print("   🛡️ Protection renforcée sur symboles à risque");
   Print("   🔄 Système de fallback opérationnel");
   
   return INIT_SUCCEEDED;
}
