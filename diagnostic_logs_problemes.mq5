//+------------------------------------------------------------------+
//| GUIDE DIAGNOSTIC - PROBLÈMES IDENTIFIÉS DANS LES LOGS          |
//+------------------------------------------------------------------+

/*
PROBLÈMES IDENTIFIÉS DANS LES LOGS DU 2026.02.05 20:21:

1. ❌ STOPS INVALIDES PERSISTANTS
   Logs: "❌ Stops invalides pour BUY - SL: 7836.2 >= Prix: 7866.2 ou TP: 5874.748 <= Prix: 7866.2"
   
   ANALYSE:
   - SL: 7836.2 est supérieur au prix 7866.2 (INCORRECT pour BUY)
   - TP: 5874.748 est inférieur au prix 7866.2 (INCORRECT pour BUY)
   - Pour BUY: SL doit être < prix, TP doit être > prix

2. ❌ ERREURS API 422 PERSISTANTES  
   Logs: "❌ Erreur IA: Code 422"
   
   ANALYSE:
   - L'API retourne toujours des erreurs 422
   - Malgré la correction du format JSON
   - Possible problème de connectivité ou format

3. 📊 DIAGNOSTIC PROFITS FONCTIONNE
   Logs: "📊 DIAGNOSTIC PROFITS - Total: 0.00$ - Positions: 1 - AutoClose: OUI/NON"
   
   ANALYSE:
   - Le robot a 1 position ouverte
   - AutoClose change de OUI à NON (normal)
   - Profit total à 0.00$

SOLUTIONS APPLIQUÉES:

1. 🔍 DIAGNOSTIC AMÉLIORÉ DANS ExecuteAdvancedTrade()
   - Logs détaillés des prix et paramètres
   - Affichage du calcul des stops
   - Validation avant exécution

2. 🌐 LOGS AMÉLIORÉS DANS UpdateAISignal()
   - Affichage des données JSON envoyées
   - Diagnostic détaillé des erreurs 422
   - Vérification de la connectivité

PROCHAINES ÉTAPES:

1. ✅ SURVEILLER LES NOUVEAUX LOGS
   - "🔍 DIAGNOSTIC TRADE" pour comprendre les stops
   - "🌐 REQUÊTE IA" pour voir le JSON exact
   - "📊 Stops dynamiques/fixes" pour le calcul

2. 🔧 VÉRIFIER LES PARAMÈTRES
   - InpStopLoss: 500 points
   - InpTakeProfit: 1000 points  
   - _Point pour Step Index

3. 🌐 VÉRIFIER L'API
   - URL: https://kolatradebot.onrender.com/decision
   - Format JSON attendu
   - Connectivité internet

LOGS ATTENDUS APRÈS CORRECTIONS:

🔍 DIAGNOSTIC TRADE - Type: BUY
   Ask: 7866.5 - Bid: 7866.2
   InpStopLoss: 500 - InpTakeProfit: 1000
   _Point: 0.1
📊 Stops par défaut - SL: 7816.2 - TP: 7966.2
🔍 Validation - Prix: 7866.5 - SL: 7816.2 - TP: 7966.2
✅ Trade ACHAT exécuté

🌐 REQUÊTE IA - URL: https://kolatradebot.onrender.com/decision
   Données: {"symbol":"Step Index","timeframe":"M5","bid":7866.2,"ask":7866.5}
✅ IA Signal: buy (confiance: 0.85)

*/

//+------------------------------------------------------------------+
//| FONCTION DE DIAGNOSTIC IMMÉDIAT                              |
//+------------------------------------------------------------------+
void DiagnosticImmediate()
{
   Print("=== DIAGNOSTIC IMMÉDIAT DES PROBLÈMES ===");
   
   // 1. Diagnostic des prix actuels
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   Print("📊 PRIX ACTUELS:");
   Print("   Symbol: ", _Symbol);
   Print("   Ask: ", ask);
   Print("   Bid: ", bid);
   Print("   Point: ", point);
   
   // 2. Calcul des stops attendus
   double expectedSL = bid - InpStopLoss * point;
   double expectedTP = bid + InpTakeProfit * point;
   
   Print("🎯 STOPS ATTENDUS POUR BUY:");
   Print("   SL: ", expectedSL, " (doit être < ", bid, ")");
   Print("   TP: ", expectedTP, " (doit être > ", bid, ")");
   
   // 3. Validation
   bool slValid = (expectedSL < bid);
   bool tpValid = (expectedTP > bid);
   
   Print("✅ VALIDATION:");
   Print("   SL valide: ", slValid ? "OUI" : "NON");
   Print("   TP valide: ", tpValid ? "OUI" : "NON");
   
   // 4. Test API
   Print("🌐 TEST API:");
   Print("   URL: ", AI_ServerURL);
   Print("   UseAI_Agent: ", UseAI_Agent ? "OUI" : "NON");
   
   // 5. Positions actuelles
   Print("📈 POSITIONS:");
   Print("   Total: ", PositionsTotal());
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNum)
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
            Print("   Position #", ticket, " - Profit: ", profit);
         }
      }
   }
   
   Print("\n🔍 RECOMMANDATIONS:");
   if(!slValid || !tpValid)
   {
      Print("   ❌ CORRIGER LES PARAMÈTRES InpStopLoss/InpTakeProfit");
   }
   else
   {
      Print("   ✅ STOPS CORRECTS");
   }
   
   if(!UseAI_Agent)
   {
      Print("   ❌ ACTIVER UseAI_Agent pour utiliser l'API");
   }
   else
   {
      Print("   ✅ API ACTIVÉE - Surveiller les logs 422");
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   DiagnosticImmediate();
   return INIT_SUCCEEDED;
}
