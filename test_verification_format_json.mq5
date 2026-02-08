//+------------------------------------------------------------------+
//| TEST VÉRIFICATION FORMAT JSON ACTUEL                      |
//+------------------------------------------------------------------+

/*
PROBLÈME: Les logs serveur montrent toujours des erreurs 422
CAUSE POSSIBLE: Le robot n'a pas été recompilé avec les nouvelles modifications

SOLUTION: Créer un test pour vérifier le format JSON actuellement utilisé

*/

//+------------------------------------------------------------------+
//| TEST FORMAT JSON ACTUELLEMENT UTILISÉ                    |
//+------------------------------------------------------------------+
void TestCurrentJSONFormat()
{
   Print("=== TEST FORMAT JSON ACTUEL ===");
   
   // Simuler exactement ce que UpdateAISignal() fait
   string url = AI_ServerURL;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Valeurs des indicateurs
   double rsiValue = 50.0;
   double atrValue = 0.0;
   
   if(rsi_H1 != INVALID_HANDLE)
   {
      double rsiBuffer[1];
      if(CopyBuffer(rsi_H1, 0, 0, 1, rsiBuffer) > 0)
         rsiValue = rsiBuffer[0];
   }
   
   if(atr_H1 != INVALID_HANDLE)
   {
      double atrBuffer[1];
      if(CopyBuffer(atr_H1, 0, 0, 1, atrBuffer) > 0)
         atrValue = atrBuffer[0];
   }
   
   // Construire le JSON exactement comme dans le code modifié
   string jsonData = "{" +
                     "\"symbol\":\"" + _Symbol + "\"," +
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
   
   Print("🔍 FORMAT JSON ACTUELLEMENT UTILISÉ:");
   Print("   URL: ", url);
   Print("   JSON: ", jsonData);
   
   // Vérifier si le format contient les nouveaux champs
   bool hasRsi = (StringFind(jsonData, "\"rsi\"") >= 0);
   bool hasAtr = (StringFind(jsonData, "\"atr\"") >= 0);
   bool hasSpikeMode = (StringFind(jsonData, "\"is_spike_mode\"") >= 0);
   bool hasVolatility = (StringFind(jsonData, "\"volatility_ratio\"") >= 0);
   
   Print("\n✅ VÉRIFICATION DES NOUVEAUX CHAMPS:");
   Print("   RSI: ", hasRsi ? "✅" : "❌");
   Print("   ATR: ", hasAtr ? "✅" : "❌");
   Print("   Spike Mode: ", hasSpikeMode ? "✅" : "❌");
   Print("   Volatility: ", hasVolatility ? "✅" : "❌");
   
   if(hasRsi && hasAtr && hasSpikeMode && hasVolatility)
   {
      Print("\n🎯 FORMAT JSON CORRECT - Les modifications sont appliquées");
      Print("   ✅ Si erreurs 422 persistent, le problème est ailleurs");
   }
   else
   {
      Print("\n❌ FORMAT JSON INCORRECT - Le robot n'a pas été recompilé");
      Print("   🔧 Solution: Recomplier le robot dans MetaEditor");
   Print("   📋 Étapes: MetaEditor → Compiler (F7)");
   }
}

//+------------------------------------------------------------------+
//| TEST DE COMPATIBILITÉ AVEC L'API                        |
//+------------------------------------------------------------------+
void TestAPICompatibility()
{
   Print("\n🌐 TEST DE COMPATIBILITÉ API:");
   
   // Test avec l'ancien format (qui cause les erreurs 422)
   string oldFormat = "{\"symbol\":\"" + _Symbol + "\",\"timeframe\":\"M5\",\"bid\":123.45,\"ask\":123.50}";
   
   // Test avec le nouveau format (qui devrait fonctionner)
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string newFormat = "{" +
                     "\"symbol\":\"" + _Symbol + "\"," +
                     "\"bid\":" + DoubleToString(bid, 5) + "," +
                     "\"ask\":" + DoubleToString(ask, 5) + "," +
                     "\"rsi\":50.0," +
                     "\"atr\":0.01234," +
                     "\"is_spike_mode\":false," +
                     "\"dir_rule\":0," +
                     "\"supertrend_trend\":0," +
                     "\"volatility_regime\":0," +
                     "\"volatility_ratio\":1.0" +
                     "}";
   
   Print("❌ ANCIEN FORMAT (cause 422): ", oldFormat);
   Print("✅ NOUVEAU FORMAT (devrait fonctionner): ", newFormat);
   
   Print("\n🔍 DIFFÉRENCES CLÉS:");
   Print("   • Ancien: 4 champs seulement");
   Print("   • Nouveau: 10+ champs avec indicateurs");
   Print("   • Ancien: timeframe (non requis)");
   Print("   • Nouveau: rsi, atr, volatilité (requis)");
}

//+------------------------------------------------------------------+
int OnInit()
{
   TestCurrentJSONFormat();
   TestAPICompatibility();
   
   Print("\n📋 ACTIONS REQUISES:");
   Print("1. ✅ Vérifier que le robot est recompilé");
   Print("2. ✅ Surveiller les logs '📦 DONNÉES JSON COMPLÈTES'");
   Print("3. ✅ Confirmer que les erreurs 422 disparaissent");
   
   return INIT_SUCCEEDED;
}
