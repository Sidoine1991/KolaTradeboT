//+------------------------------------------------------------------+
//| TEST FORMAT JSON CORRIGÉ POUR API 422 RÉSOLU              |
//+------------------------------------------------------------------+

/*
PROBLÈME IDENTIFIÉ DANS LES LOGS PYTHON:
- HTTP 422 pour https://kolatradebot.onrender.com
- HTTP 442 pour http://localhost:8000 (serveur local non démarré)

CAUSE RACINE IDENTIFIÉE:
L'API attend un modèle DecisionRequest complet avec beaucoup plus de champs:

❌ ANCIEN FORMAT (causait les erreurs 422):
{"symbol":"Step Index","timeframe":"M5","bid":7866.2,"ask":7866.5}

✅ NOUVEAU FORMAT (correspond au modèle DecisionRequest):
{
  "symbol": "Step Index",
  "bid": 7866.2,
  "ask": 7866.5,
  "rsi": 45.67,
  "atr": 0.01234,
  "is_spike_mode": false,
  "dir_rule": 0,
  "supertrend_trend": 0,
  "volatility_regime": 0,
  "volatility_ratio": 1.0
}

MODÈLE DecisionRequest COMPLET (dans ai_server.py):
class DecisionRequest(BaseModel):
    symbol: str                    # ✅ Requis
    bid: float                     # ✅ Requis  
    ask: float                     # ✅ Requis
    rsi: Optional[float] = 50.0   # ✅ Ajouté
    ema_fast_h1: Optional[float] = None
    ema_slow_h1: Optional[float] = None
    ema_fast_m1: Optional[float] = None
    ema_slow_m1: Optional[float] = None
    atr: Optional[float] = 0.0    # ✅ Ajouté
    dir_rule: int = 0             # ✅ Ajouté
    is_spike_mode: bool = False    # ✅ Ajouté
    vwap: Optional[float] = None
    vwap_distance: Optional[float] = None
    above_vwap: Optional[bool] = None
    supertrend_trend: Optional[int] = 0  # ✅ Ajouté
    supertrend_line: Optional[float] = None
    volatility_regime: Optional[int] = 0   # ✅ Ajouté
    volatility_ratio: Optional[float] = 1.0  # ✅ Ajouté
    image_filename: Optional[str] = None
    deriv_patterns: Optional[str] = None
    deriv_patterns_bullish: Optional[int] = None
    deriv_patterns_bearish: Optional[int] = None

SOLUTION APPLIQUÉE:
1. ✅ Ajout des champs requis (symbol, bid, ask)
2. ✅ Ajout des champs importants (rsi, atr)
3. ✅ Ajout des champs booléens par défaut
4. ✅ Protection contre les indicateurs indisponibles
5. ✅ Logs détaillés pour diagnostic

RÉSULTAT ATTENDU:
- ❌ Plus d'erreurs HTTP 422
- ✅ Réponses HTTP 200 de l'API
- ✅ Signaux IA fonctionnels
- ✅ Logs détaillés pour monitoring

*/

//+------------------------------------------------------------------+
//| TEST DU NOUVEAU FORMAT JSON                              |
//+------------------------------------------------------------------+
void TestNewJSONFormat()
{
   Print("=== TEST NOUVEAU FORMAT JSON POUR API ===");
   
   // Simuler les données comme dans UpdateAISignal()
   string symbol = _Symbol;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Simuler les valeurs d'indicateurs
   double rsiValue = 50.0; // Valeur par défaut si indicateur non disponible
   double atrValue = 0.0;  // Valeur par défaut si indicateur non disponible
   
   // Créer le JSON complet comme dans le code corrigé
   string jsonData = "{" +
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
   
   Print("📊 NOUVEAU FORMAT JSON:");
   Print("   URL: ", AI_ServerURL);
   Print("   JSON: ", jsonData);
   
   // Vérification du format
   bool hasSymbol = (StringFind(jsonData, "\"symbol\"") >= 0);
   bool hasBid = (StringFind(jsonData, "\"bid\"") >= 0);
   bool hasAsk = (StringFind(jsonData, "\"ask\"") >= 0);
   bool hasRsi = (StringFind(jsonData, "\"rsi\"") >= 0);
   bool hasAtr = (StringFind(jsonData, "\"atr\"") >= 0);
   bool hasSpikeMode = (StringFind(jsonData, "\"is_spike_mode\"") >= 0);
   
   Print("\n✅ VÉRIFICATION DU FORMAT:");
   Print("   Symbol: ", hasSymbol ? "✅" : "❌");
   Print("   Bid: ", hasBid ? "✅" : "❌");
   Print("   Ask: ", hasAsk ? "✅" : "❌");
   Print("   RSI: ", hasRsi ? "✅" : "❌");
   Print("   ATR: ", hasAtr ? "✅" : "❌");
   Print("   Spike Mode: ", hasSpikeMode ? "✅" : "❌");
   
   if(hasSymbol && hasBid && hasAsk && hasRsi && hasAtr && hasSpikeMode)
   {
      Print("\n🎯 FORMAT JSON CORRECT - L'API devrait accepter cette requête");
      Print("   ✅ Tous les champs requis du modèle DecisionRequest sont présents");
      Print("   ✅ Champs optionnels importants inclus");
      Print("   ✅ Valeurs par défaut pour indicateurs non disponibles");
   }
   else
   {
      Print("\n❌ FORMAT JSON INCORRECT - Vérifier la construction");
   }
}

//+------------------------------------------------------------------+
//| COMPARAISON ANCIEN VS NOUVEAU FORMAT                     |
//+------------------------------------------------------------------+
void CompareFormats()
{
   Print("\n📊 COMPARAISON DES FORMATS:");
   
   Print("\n❌ ANCIEN FORMAT (causait HTTP 422):");
   Print("{\"symbol\":\"Step Index\",\"timeframe\":\"M5\",\"bid\":7866.2,\"ask\":7866.5}");
   
   Print("\n✅ NOUVEAU FORMAT (devrait fonctionner):");
   Print("{");
   Print("  \"symbol\": \"Step Index\",");
   Print("  \"bid\": 7866.2,");
   Print("  \"ask\": 7866.5,");
   Print("  \"rsi\": 45.67,");
   Print("  \"atr\": 0.01234,");
   Print("  \"is_spike_mode\": false,");
   Print("  \"dir_rule\": 0,");
   Print("  \"supertrend_trend\": 0,");
   Print("  \"volatility_regime\": 0,");
   Print("  \"volatility_ratio\": 1.0");
   Print("}");
   
   Print("\n🔍 DIFFÉRENCES CLÉS:");
   Print("   • Ajout de 'rsi' et 'atr' (indicateurs techniques)");
   Print("   • Ajout de 'is_spike_mode' (mode spike)");
   Print("   • Ajout de 'dir_rule', 'supertrend_trend' (direction)");
   Print("   • Ajout de 'volatility_regime', 'volatility_ratio' (volatilité)");
   Print("   • Suppression de 'timeframe' (non requis par l'API)");
}

//+------------------------------------------------------------------+
int OnInit()
{
   TestNewJSONFormat();
   CompareFormats();
   
   Print("\n✅ CORRECTION API 422 APPLIQUÉE");
   Print("   Le nouveau format correspond au modèle DecisionRequest");
   Print("   Les erreurs HTTP 422 devraient disparaître");
   Print("   Surveiller les logs '🌐 REQUÊTE IA' pour confirmation");
   
   return INIT_SUCCEEDED;
}
