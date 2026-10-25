//+------------------------------------------------------------------+
//| Diagnostic AngelOfSpike - Vérification des paramètres            |
//+------------------------------------------------------------------+

void OnStart()
{
   Print("=== DIAGNOSTIC ANGEL OF SPIKE ===");
   Print("Heure actuelle: ", TimeToString(TimeCurrent()));
   Print("Symbole actuel: ", _Symbol);
   Print("Timeframe: ", EnumToString(_Period));
   
   // Vérifier les paramètres de trading
   Print("\n=== PARAMÈTRES DE TRADING ===");
   Print("InpEnableTrading: ", InpEnableTrading);
   Print("InpEnableSpikeTrading: ", InpEnableSpikeTrading);
   Print("InpShowSpikeArrow: ", InpShowSpikeArrow);
   Print("InpAllowManualTrading: ", InpAllowManualTrading);
   Print("InpTradeOtherSymbols: ", InpTradeOtherSymbols);
   
   // Vérifier les symboles autorisés
   Print("\n=== SYMBOLES AUTORISÉS ===");
   Print("InpAllowedSymbols: ", InpAllowedSymbols);
   
   string symbols[];
   StringSplit(InpAllowedSymbols, ',', symbols);
   for(int i = 0; i < ArraySize(symbols); i++)
   {
      string symbol = StringTrim(symbols[i]);
      Print("Symbole ", i, ": '", symbol, "'");
      if(SymbolSelect(symbol, true))
      {
         Print("  ✓ Disponible dans Market Watch");
      }
      else
      {
         Print("  ✗ Non disponible dans Market Watch");
      }
   }
   
   // Vérifier les conditions de trading
   Print("\n=== CONDITIONS DE TRADING ===");
   Print("Magic Number: ", InpMagicNumber);
   Print("Max Positions Globales: ", InpMaxGlobalPositions);
   Print("Max Positions par Symbole: ", InpMaxPositionsPerSymbol);
   
   // Vérifier les positions actuelles
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
   
   // Vérifier les ordres en attente
   int totalOrders = OrdersTotal();
   int eaOrders = 0;
   for(int i = 0; i < totalOrders; i++)
   {
      if(OrderSelect(OrderGetTicket(i)))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
            eaOrders++;
      }
   }
   
   Print("Ordres en attente: ", totalOrders);
   Print("Ordres EA: ", eaOrders);
   
   // Vérifier les conditions de détection de spike
   Print("\n=== CONDITIONS DE DÉTECTION SPIKE ===");
   Print("InpSpikeMinVolumeRatio: ", InpSpikeMinVolumeRatio);
   Print("InpSpikeMinRangeRatio: ", InpSpikeMinRangeRatio);
   Print("InpMinSpikeM1Probability: ", InpMinSpikeM1Probability, "%");
   
   // Test de détection de spike sur le symbole actuel
   if(IsBoomCrashSymbol(_Symbol))
   {
      Print("\n=== TEST DÉTECTION SPIKE SUR ", _Symbol, " ===");
      int spikeDir = 0;
      if(DetectSpikeNow(_Symbol, spikeDir))
      {
         Print("✓ Signal de spike détecté! Direction: ", (spikeDir > 0 ? "ACHAT" : "VENTE"));
      }
      else
      {
         Print("✗ Aucun signal de spike détecté");
      }
   }
   
   Print("\n=== DIAGNOSTIC TERMINÉ ===");
}
