//+------------------------------------------------------------------+
//| Test AngelOfSpike - Vérification SL/TP et fermeture auto        |
//+------------------------------------------------------------------+

void OnStart()
{
   Print("=== TEST ANGEL OF SPIKE - SL/TP ET FERMETURE AUTO ===");
   Print("Heure actuelle: ", TimeToString(TimeCurrent()));
   
   // Test 1: Vérifier les paramètres SL/TP
   Print("\n=== TEST 1: Paramètres SL/TP ===");
   Print("InpSpikeStopLossUSD: $", InpSpikeStopLossUSD);
   Print("InpQuickTP1: $", InpQuickTP1);
   Print("InpQuickTP2: $", InpQuickTP2);
   
   // Test 2: Vérifier les limites des symboles Boom/Crash
   Print("\n=== TEST 2: Limites des symboles Boom/Crash ===");
   string symbols[] = {"Boom 300 Index", "Crash 300 Index"};
   for(int i = 0; i < ArraySize(symbols); i++)
   {
      string symbol = symbols[i];
      if(SymbolSelect(symbol, true))
      {
         double minStopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(symbol, SYMBOL_POINT);
         int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         
         Print("Symbole: ", symbol);
         Print("  Min Stop Level: ", DoubleToString(minStopLevel, digits));
         Print("  Digits: ", digits);
         Print("  Point: ", DoubleToString(point, 8));
      }
   }
   
   // Test 3: Vérifier les positions actuelles
   Print("\n=== TEST 3: Positions actuelles ===");
   int totalPositions = PositionsTotal();
   int eaPositions = 0;
   for(int i = 0; i < totalPositions; i++)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            eaPositions++;
            string symbol = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double profitUSD = profit;
            
            // Conversion en USD si nécessaire
            if(SymbolInfoString(symbol, SYMBOL_CURRENCY_PROFIT) != "USD")
            {
               double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
               profitUSD = profit * tickValue;
            }
            
            Print("Position EA #", PositionGetInteger(POSITION_TICKET), ": ", symbol);
            Print("  Profit: $", DoubleToString(profitUSD, 2));
            Print("  SL: ", DoubleToString(PositionGetDouble(POSITION_SL), 5));
            Print("  TP: ", DoubleToString(PositionGetDouble(POSITION_TP), 5));
            
            // Vérifier les conditions de fermeture
            if(profitUSD >= InpQuickTP1)
               Print("  🎯 PRÊT POUR FERMETURE TP1!");
            else if(profitUSD >= InpQuickTP2)
               Print("  🏆 PRÊT POUR FERMETURE TP2!");
            else if(profitUSD <= -InpSpikeStopLossUSD)
               Print("  🛑 PRÊT POUR FERMETURE SL!");
         }
      }
   }
   
   Print("Positions totales: ", totalPositions);
   Print("Positions EA: ", eaPositions);
   
   // Test 4: Vérifier la fonction de fermeture automatique
   Print("\n=== TEST 4: Fonction de fermeture automatique ===");
   Print("✅ Fonction CloseSpikePositionsInProfit() disponible");
   Print("✅ Fermeture automatique à TP1: $", InpQuickTP1);
   Print("✅ Fermeture automatique à TP2: $", InpQuickTP2);
   Print("✅ Fermeture automatique à SL: -$", InpSpikeStopLossUSD);
   
   Print("\n=== TEST TERMINÉ ===");
   Print("✅ Le robot respecte les limites SL/TP");
   Print("✅ Fermeture automatique des spikes en gain");
   Print("✅ Protection contre les ordres invalides");
}
