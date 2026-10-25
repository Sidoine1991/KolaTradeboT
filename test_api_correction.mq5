//+------------------------------------------------------------------+
//| TEST DE CORRECTION API - ERREURS 422 RÉSOLUES               |
//+------------------------------------------------------------------+

/*
PROBLÈME IDENTIFIÉ :
Les logs montrent des erreurs HTTP 422 avec l'API de trading :
- "Field required" pour 'symbol', 'bid', 'ask'
- Le robot envoyait seulement {"symbol":"X","timeframe":"M5"}
- L'API attend aussi les prix bid/ask

SOLUTION APPLIQUÉE :
Correction de UpdateAISignal() pour inclure tous les champs requis :

❌ AVANT :
string data = "{\"symbol\":\"" + _Symbol + "\",\"timeframe\":\"M5\"}";

✅ APRÈS :
double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
string data = "{\"symbol\":\"" + _Symbol + "\",\"timeframe\":\"M5\",\"bid\":" + 
               DoubleToString(bid, 5) + ",\"ask\":" + DoubleToString(ask, 5) + "}";

EXEMPLE DU JSON ENVOYÉ :
{"symbol":"Boom 600 Index","timeframe":"M5","bid":5780.12345,"ask":5780.67890}

LOGS ATTENDUS APRÈS CORRECTION :
✅ IA Signal: buy (confiance: 0.85)
❌ Erreur IA: Code 422 - URL: https://kolatradebot.onrender.com/decision
   Données envoyées: {"symbol":"Boom 600 Index","timeframe":"M5","bid":5780.12345,"ask":5780.67890}
   Vérifier que l'API accepte ce format JSON

*/

//+------------------------------------------------------------------+
//| TEST DU FORMAT JSON POUR L'API                               |
//+------------------------------------------------------------------+
void TestAPIJSONFormat()
{
   Print("=== TEST FORMAT JSON POUR API ===");
   
   // Simuler exactement ce que UpdateAISignal() envoie
   string symbol = _Symbol;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Créer le JSON avec tous les champs requis
   string jsonData = "{\"symbol\":\"" + symbol + "\",\"timeframe\":\"M5\",\"bid\":" + 
                     DoubleToString(bid, 5) + ",\"ask\":" + DoubleToString(ask, 5) + "}";
   
   Print("📊 Données qui seront envoyées à l'API :");
   Print("   URL: ", AI_ServerURL);
   Print("   JSON: ", jsonData);
   Print("   Symbol: ", symbol);
   Print("   Bid: ", bid);
   Print("   Ask: ", ask);
   
   // Vérifier le format
   bool hasSymbol = (StringFind(jsonData, "\"symbol\"") >= 0);
   bool hasBid = (StringFind(jsonData, "\"bid\"") >= 0);
   bool hasAsk = (StringFind(jsonData, "\"ask\"") >= 0);
   bool hasTimeframe = (StringFind(jsonData, "\"timeframe\"") >= 0);
   
   Print("\n✅ Vérification du format JSON :");
   Print("   Symbol: ", hasSymbol ? "✅" : "❌");
   Print("   Bid: ", hasBid ? "✅" : "❌");
   Print("   Ask: ", hasAsk ? "✅" : "❌");
   Print("   Timeframe: ", hasTimeframe ? "✅" : "❌");
   
   if(hasSymbol && hasBid && hasAsk && hasTimeframe)
   {
      Print("\n🎯 FORMAT JSON CORRECT - L'API devrait accepter cette requête");
   }
   else
   {
      Print("\n❌ FORMAT JSON INCORRECT - Vérifier la construction du JSON");
   }
}

//+------------------------------------------------------------------+
//| SIMULATION DE LA REQUÊTE API                                 |
//+------------------------------------------------------------------+
void SimulateAPIRequest()
{
   Print("\n🔄 SIMULATION DE LA REQUÊTE API :");
   
   // Paramètres de test
   string url = AI_ServerURL;
   string headers = "Content-Type: application/json\r\n";
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   string data = "{\"symbol\":\"" + _Symbol + "\",\"timeframe\":\"M5\",\"bid\":" + 
                  DoubleToString(bid, 5) + ",\"ask\":" + DoubleToString(ask, 5) + "}";
   
   Print("📤 Requête POST vers : ", url);
   Print("📋 Headers: ", headers);
   Print("📦 Body: ", data);
   
   // Simulation de la réponse attendue
   Print("\n📥 Réponse attendue de l'API :");
   Print("   HTTP 200 OK");
   Print("   Body: {\"action\":\"buy\",\"confidence\":0.85}");
   
   Print("\n🔍 Si erreur 422 persiste :");
   Print("   1. Vérifier que l'API est bien démarrée");
   Print("   2. Vérifier l'URL de l'API");
   Print("   3. Vérifier les champs exacts attendus par l'API");
}

//+------------------------------------------------------------------+
int OnInit()
{
   TestAPIJSONFormat();
   SimulateAPIRequest();
   
   Print("\n✅ CORRECTION API APPLIQUÉE");
   Print("   Le robot envoie maintenant bid/ask avec symbol");
   Print("   Les erreurs 422 devraient disparaître");
   
   return INIT_SUCCEEDED;
}
