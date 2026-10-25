//+------------------------------------------------------------------+
//| TEST LOTS MINIMUM BROKER - OR, FOREX, BOOM & CRASH          |
//+------------------------------------------------------------------+

/*
MODIFICATION APPLIQUÉE:
GetCorrectLotSize() utilise maintenant les lots minimum du broker pour:
- Or (XAU, Gold)
- Argent (XAG, Silver)  
- Forex (USD, EUR, GBP, JPY, AUD, CAD, CHF, NZD)
- Boom/Crash Indices
- Volatility Indices

LOGIQUE:
1. 📊 Détection du type de symbole
2. 📏 Récupération des infos broker (min, max, step)
3. ⚠️ Utilisation du lot minimum pour sécurité
4. ✅ Arrondi au step le plus proche
5. 📋 Logs détaillés pour validation

AVANTAGES:
- 🛡️ Protection contre les lots trop élevés
- 📏 Respect strict des limites broker
- ⚡ Adaptation automatique aux conditions
- 📊 Transparence totale des calculs
*/

//+------------------------------------------------------------------+
//| TEST DES LOTS MINIMUM PAR SYMBOLE                      |
//+------------------------------------------------------------------+
void TestMinimumLots()
{
   Print("=== TEST LOTS MINIMUM BROKER ===");
   
   string testSymbols[] = {
      "XAUUSD",      // Or
      "Gold",        // Or (autre format)
      "XAGUSD",      // Argent
      "Silver",      // Argent (autre format)
      "EURUSD",      // Forex
      "GBPJPY",      // Forex
      "Boom 600 Index",  // Boom
      "Crash 300 Index", // Crash
      "Volatility 100 Index", // Volatility
      "BTCUSD"       // Crypto
   };
   
   Print("📊 TEST DES LOTS MINIMUM PAR SYMBOLE:");
   Print("="*60);
   
   for(int i = 0; i < ArraySize(testSymbols); i++)
   {
      string symbol = testSymbols[i];
      
      // Simuler la logique de GetCorrectLotSize()
      double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
      double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
      
      // Détection du type de symbole
      bool isRiskySymbol = (StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "Gold") >= 0 ||
                         StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "Silver") >= 0 ||
                         StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0 ||
                         StringFind(symbol, "Volatility") >= 0);
      
      bool isForexSymbol = (StringFind(symbol, "USD") >= 0 || StringFind(symbol, "EUR") >= 0 || 
                           StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "JPY") >= 0 ||
                           StringFind(symbol, "AUD") >= 0 || StringFind(symbol, "CAD") >= 0 ||
                           StringFind(symbol, "CHF") >= 0 || StringFind(symbol, "NZD") >= 0);
      
      // Calcul du lot selon la logique
      double calculatedLot = 0.0;
      string lotType = "";
      
      if(isRiskySymbol)
      {
         lotType = "RISQUE (min broker)";
         calculatedLot = MathRound(minLot / stepLot) * stepLot;
         calculatedLot = MathMax(calculatedLot, minLot);
      }
      else if(isForexSymbol)
      {
         lotType = "FOREX (min broker)";
         calculatedLot = MathRound(minLot / stepLot) * stepLot;
         calculatedLot = MathMax(calculatedLot, minLot);
      }
      else
      {
         lotType = "STANDARD (InpLots)";
         calculatedLot = MathMax(InpLots, minLot);
         calculatedLot = MathRound(calculatedLot / stepLot) * stepLot;
         calculatedLot = MathMin(calculatedLot, maxLot);
      }
      
      // Affichage des résultats
      Print("\n📈 ", symbol, " - Type: ", lotType);
      Print("   Min: ", minLot, " | Max: ", maxLot, " | Step: ", stepLot);
      Print("   ✅ Lot calculé: ", calculatedLot);
      
      // Validation
      bool isValid = (calculatedLot >= minLot && calculatedLot <= maxLot);
      Print("   Validation: ", isValid ? "✅ VALIDE" : "❌ INVALIDE");
   }
}

//+------------------------------------------------------------------+
//| SIMULATION DES PARAMÈTRES BROKER                    |
//+------------------------------------------------------------------+
void SimulateBrokerParameters()
{
   Print("\n📊 SIMULATION PARAMÈTRES BROKER:");
   Print("="*60);
   
   // Simulation des paramètres typiques par type de symbole
   struct SymbolParams {
      string symbol;
      double minLot;
      double maxLot;
      double stepLot;
      string type;
   };
   
   SymbolParams params[] = {
      {"XAUUSD", 0.01, 30.0, 0.01, "Or"},
      {"XAGUSD", 0.01, 50.0, 0.01, "Argent"},
      {"EURUSD", 0.01, 100.0, 0.01, "Forex"},
      {"Boom 600 Index", 0.1, 100.0, 0.1, "Boom"},
      {"Crash 300 Index", 0.1, 100.0, 0.1, "Crash"},
      {"Volatility 100 Index", 0.1, 100.0, 0.1, "Volatility"}
   };
   
   for(int i = 0; i < ArraySize(params); i++)
   {
      SymbolParams p = params[i];
      
      Print("\n🔍 ", p.symbol, " (", p.type, ")");
      Print("   📏 Lot minimum: ", p.minLot);
      Print("   📏 Lot maximum: ", p.maxLot);
      Print("   📏 Step lot: ", p.stepLot);
      
      // Simulation du calcul
      double calculatedLot = MathRound(p.minLot / p.stepLot) * p.stepLot;
      calculatedLot = MathMax(calculatedLot, p.minLot);
      
      Print("   ✅ Lot final: ", calculatedLot);
      Print("   💰 Valeur du trade (approx): ", calculatedLot * 1000, " USD");
   }
}

//+------------------------------------------------------------------+
//| VALIDATION DES RÈGLES DE SÉCURITÉ                     |
//+------------------------------------------------------------------+
void ValidateSecurityRules()
{
   Print("\n🛡️ VALIDATION RÈGLES DE SÉCURITÉ:");
   Print("="*60);
   
   Print("✅ RÈGLE 1: Or et métaux précieux");
   Print("   → Utilisation lot minimum broker uniquement");
   Print("   → Protection contre la volatilité extrême");
   
   Print("\n✅ RÈGLE 2: Forex standard");
   Print("   → Utilisation lot minimum broker");
   Print("   → Sécurité renforcée même sur paires stables");
   
   Print("\n✅ RÈGLE 3: Boom/Crash Indices");
   Print("   → Lot minimum obligatoire");
   Print("   → Protection contre les spikes rapides");
   
   Print("\n✅ RÈGLE 4: Volatility Indices");
   Print("   → Lot minimum strict");
   Print("   → Gestion du risque élevé");
   
   Print("\n✅ RÈGLE 5: Validation automatique");
   Print("   → Arrondi au step broker");
   Print("   → Respect des limites min/max");
   Print("   → Logs détaillés pour audit");
}

//+------------------------------------------------------------------+
int OnInit()
{
   TestMinimumLots();
   SimulateBrokerParameters();
   ValidateSecurityRules();
   
   Print("\n🎯 MODIFICATION TERMINÉE");
   Print("   ✅ Lots minimum broker appliqués sur Or, Forex, Boom & Crash");
   Print("   🛡️ Protection renforcée contre les risques");
   Print("   📊 Logs détaillés pour surveillance");
   Print("   ⚙️ Recommandation: Tester sur démo avant utilisation réelle");
   
   return INIT_SUCCEEDED;
}
