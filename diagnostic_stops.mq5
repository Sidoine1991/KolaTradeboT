//+------------------------------------------------------------------+
//| DIAGNOSTIC DU PROBLÈME STOPS INVALIDES - Boom 600 Index        |
//+------------------------------------------------------------------+

void DiagnoseInvalidStopsIssue()
{
   Print("=== DIAGNOSTIC STOPS INVALIDES ===");
   
   // Informations sur le symbole
   string symbol = _Symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double digits = SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopsLevel * point;
   
   Print("Symbole: ", symbol);
   Print("Point: ", point);
   Print("Digits: ", digits);
   Print("Stop Level: ", stopsLevel, " points");
   Print("Distance minimum: ", minDistance);
   
   // Vérifier si c'est Boom/Crash
   bool isBoomCrash = (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
   Print("Boom/Crash: ", isBoomCrash ? "OUI" : "NON");
   
   // Simulation du problème rencontré
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double invalidSL = 7833.600;  // SL invalide du log
   double validTP = 5874.748;     // TP du log
   
   Print("\n--- ANALYSE DU CAS RÉEL ---");
   Print("Prix actuel (approx): ", currentPrice);
   Print("SL invalide: ", invalidSL);
   Print("TP: ", validTP);
   
   // Vérification des règles
   bool slValid = (invalidSL < currentPrice);  // Pour BUY, SL doit être < prix
   bool tpValid = (validTP > currentPrice);     // Pour BUY, TP doit être > prix
   
   Print("SL valide (doit être < prix): ", slValid ? "OUI" : "NON");
   Print("TP valide (doit être > prix): ", tpValid ? "OUI" : "NON");
   
   if(!slValid)
   {
      Print("❌ PROBLÈME: SL ", invalidSL, " est AU-DESSUS du prix ", currentPrice);
      Print("   Pour un BUY, le SL doit TOUJOURS être en dessous du prix d'entrée");
   }
   
   // Calcul des stops corrects
   double correctSL = currentPrice - (500 * point);  // 500 points de SL
   double correctTP = currentPrice + (1000 * point); // 1000 points de TP
   
   Print("\n--- STOPS CORRECTS PROPOSÉS ---");
   Print("SL correct: ", correctSL, " (distance: ", currentPrice - correctSL, ")");
   Print("TP correct: ", correctTP, " (distance: ", correctTP - currentPrice, ")");
   
   // Validation avec notre fonction
   bool stopsOk = ValidateStopLevels(currentPrice, correctSL, correctTP, true);
   Print("Validation stops: ", stopsOk ? "✅ VALIDES" : "❌ INVALIDES");
   
   Print("\n=== RECOMMANDATIONS ===");
   Print("1. Vérifier la logique de calcul du SL dans ManageTrailingStop()");
   Print("2. Pour Boom/Crash, utiliser des distances plus grandes (min 50 points)");
   Print("3. Toujours valider les stops avant modification");
   Print("4. Ajouter des logs détaillés pour chaque modification de SL/TP");
}

//+------------------------------------------------------------------+
int OnInit()
{
   DiagnoseInvalidStopsIssue();
   return INIT_SUCCEEDED;
}
