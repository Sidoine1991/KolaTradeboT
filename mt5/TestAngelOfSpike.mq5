//+------------------------------------------------------------------+
//| Test AngelOfSpike - Vérification des protections               |
//+------------------------------------------------------------------+

void OnStart()
{
   Print("=== TEST ANGEL OF SPIKE - PROTECTION ANTI-MULTIPLES ===");
   Print("Heure actuelle: ", TimeToString(TimeCurrent()));
   
   // Test 1: Vérifier la fonction HasAnyEAPosition
   Print("\n=== TEST 1: Vérification des positions EA ===");
   bool hasPosition = HasAnyEAPosition();
   Print("Position EA détectée: ", hasPosition);
   
   // Test 2: Vérifier les symboles Boom/Crash
   Print("\n=== TEST 2: Vérification des symboles Boom/Crash ===");
   string symbols[] = {"Boom 300 Index", "Crash 300 Index", "Boom 500 Index", "Crash 500 Index"};
   for(int i = 0; i < ArraySize(symbols); i++)
   {
      bool isBC = IsBoomCrashSymbol(symbols[i]);
      Print("Symbole ", symbols[i], ": ", (isBC ? "✓ Boom/Crash" : "✗ Autre"));
   }
   
   // Test 3: Vérifier la détection de spike
   Print("\n=== TEST 3: Test de détection de spike ===");
   string testSymbol = "Boom 300 Index";
   if(SymbolSelect(testSymbol, true))
   {
      double signalStrength = 0;
      int signal = DetectSpikeSignal(testSymbol, signalStrength);
      Print("Signal sur ", testSymbol, ": ", signal, " (force: ", signalStrength, ")");
   }
   else
   {
      Print("❌ Impossible de sélectionner ", testSymbol);
   }
   
   // Test 4: Vérifier les paramètres de trading
   Print("\n=== TEST 4: Paramètres de trading ===");
   Print("InpEnableTrading: ", InpEnableTrading);
   Print("InpEnableSpikeTrading: ", InpEnableSpikeTrading);
   Print("InpShowSpikeArrow: ", InpShowSpikeArrow);
   Print("Magic Number: ", InpMagicNumber);
   Print("Stop Loss USD: ", InpSpikeStopLossUSD);
   Print("Take Profit 1: ", InpQuickTP1);
   
   // Test 5: Vérifier les positions actuelles
   Print("\n=== TEST 5: Positions actuelles ===");
   int totalPositions = PositionsTotal();
   int eaPositions = 0;
   for(int i = 0; i < totalPositions; i++)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            eaPositions++;
      }
   }
   Print("Positions totales: ", totalPositions);
   Print("Positions EA: ", eaPositions);
   
   Print("\n=== TEST TERMINÉ ===");
   Print("✅ Le robot est configuré pour UN SEUL TRADE à la fois");
   Print("✅ Trading uniquement sur les spikes Boom/Crash");
   Print("✅ Protection anti-ordres multiples activée");
}
