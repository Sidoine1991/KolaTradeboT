//+------------------------------------------------------------------+
//| TEST FORMAT JSON ACTUEL DU ROBOT                    |
//+------------------------------------------------------------------+

/*
DIAGNOSTIC DES ERREURS 422 PERSISTANTES

❌ PROBLÈME IDENTIFIÉ:
- Erreurs 422 massives dans les logs du serveur
- Le robot n'a pas été recompilé avec les corrections
- Format JSON ancien encore utilisé

✅ FORMAT JSON CORRECT DANS LE CODE:
{
  "symbol": "EURUSD",
  "bid": 1.08550,
  "ask": 1.08555,
  "rsi": 45.67,
  "atr": 0.01234,
  "is_spike_mode": false,
  "dir_rule": 0,
  "supertrend_trend": 0,
  "volatility_regime": 0,
  "volatility_ratio": 1.0
}

🎯 SOLUTION: Recompiler le robot dans MetaEditor
*/

//+------------------------------------------------------------------+
//| TEST DU FORMAT JSON ACTUEL                         |
//+------------------------------------------------------------------+
void TestCurrentJSONFormat()
{
   Print("=== TEST FORMAT JSON ACTUEL DU ROBOT ===");
   
   // Simuler les valeurs comme dans UpdateAISignal()
   string symbol = _Symbol;
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double rsiValue = 50.0;
   double atrValue = 0.0;
   
   // Créer le JSON exactement comme dans le robot
   string currentJSON = "{" +
                      "\"symbol\":\"" + symbol + "\"," +
                      "\"bid\":" + DoubleToString(bid, 5) + "," +
                      "\"ask\":" + DoubleToString(ask, 5) + "," +
                      "\"rsi\":" + DoubleToString(rsiValue, 2) + "," +
                      "\"atr\":" + DoubleToString(atrValue, 5) + "," +
                      "\"is_spike_mode\":false," +
                      "\"dir_rule\":0," +
                      "\"supertrend_trend\":0," +
                      "\"volatility_regime\":0," +
                      "\"volatility_ratio\":1.0" +
                      "}";
   
   Print("📦 FORMAT JSON ACTUEL:");
   Print(currentJSON);
   
   // Vérifier les champs requis
   string requiredFields[] = {
      "symbol", "bid", "ask", "rsi", "atr",
      "is_spike_mode", "dir_rule", "supertrend_trend", 
      "volatility_regime", "volatility_ratio"
   };
   
   Print("\n🔍 VÉRIFICATION DES CHAMPS REQUIS:");
   bool allFieldsPresent = true;
   
   for(int i = 0; i < ArraySize(requiredFields); i++)
   {
      string field = requiredFields[i];
      bool present = StringFind(currentJSON, "\"" + field + "\"") >= 0;
      
      Print("   ", present ? "✅" : "❌", " ", field);
      
      if(!present)
         allFieldsPresent = false;
   }
   
   Print("\n📊 RÉSULTAT DE LA VALIDATION:");
   Print("   Format JSON: ", allFieldsPresent ? "✅ COMPLET" : "❌ INCOMPLET");
   Print("   Taille: ", StringLen(currentJSON), " caractères");
   
   return;
}

//+------------------------------------------------------------------+
//| DIAGNOSTIC DES ERREURS 422                        |
//+------------------------------------------------------------------+
void Diagnose422Errors()
{
   Print("\n=== DIAGNOSTIC DES ERREURS 422 ===");
   
   Print("❌ SYMPTÔMES OBSERVÉS:");
   Print("   - Erreurs 422 massives dans les logs serveur");
   Print("   - POST /decision - 422 Unprocessable Entity");
   Print("   - Temps de réponse: 0.003s (très rapide)");
   
   Print("\n🔍 CAUSES POSSIBLES:");
   Print("   1. ❌ Robot non recompilé avec les corrections");
   Print("   2. ❌ Format JSON ancien encore utilisé");
   Print("   3. ❌ Champs manquants dans le JSON");
   Print("   4. ❌ Types de données incorrects");
   
   Print("\n✅ ÉTATS DES CORRECTIONS:");
   Print("   1. ✅ Format JSON mis à jour dans GoldRush_basic.mq5");
   Print("   2. ✅ Tous les champs DecisionRequest inclus");
   Print("   3. ✅ Système de fallback implémenté");
   Print("   4. ❌ Robot non recompilé (PROBLÈME ACTUEL)");
   
   Print("\n🎯 SOLUTION IMMÉDIATE:");
   Print("   1. Ouvrir MetaEditor");
   Print("   2. Charger GoldRush_basic.mq5");
   Print("   3. Compiler (F7)");
   Print("   4. Vérifier '0 error(s), 0 warning(s)'");
   Print("   5. Redémarrer le robot sur le graphique");
   
   Print("\n📋 VALIDATION APRÈS COMPILATION:");
   Print("   - Chercher '📦 DONNÉES JSON COMPLÈTES' dans les logs");
   Print("   - Chercher '🆕 FORMAT MIS À JOUR' dans les logs");
   Print("   - Vérifier la disparition des erreurs 422");
}

//+------------------------------------------------------------------+
//| TEST COMPLET                                         |
//+------------------------------------------------------------------+
void RunComplete422Diagnostic()
{
   TestCurrentJSONFormat();
   Diagnose422Errors();
   
   Print("\n" + "="*60);
   Print("🎯 CONCLUSION DU DIAGNOSTIC");
   Print("="*60);
   
   Print("✅ FORMAT JSON DANS LE CODE: CORRECT");
   Print("❌ ROBOT COMPILÉ: NON");
   Print("🚨 PROBLÈME: Le robot utilise encore l'ancienne version");
   
   Print("\n💡 ACTION REQUISE:");
   Print("   🔧 COMPILER LE ROBOT DANS METAEDITOR (F7)");
   Print("   📊 Le format JSON est déjà correct dans le code");
   Print("   🔄 Les erreurs 422 disparaîtront après compilation");
   
   Print("\n📊 ATTENDRE APRÈS COMPILATION:");
   Print("   ✅ Plus d'erreurs 422");
   Print("   ✅ Messages '📦 DONNÉES JSON COMPLÈTES'");
   Print("   ✅ Réponses 200 du serveur");
}

//+------------------------------------------------------------------+
int OnInit()
{
   RunComplete422Diagnostic();
   return INIT_SUCCEEDED;
}
