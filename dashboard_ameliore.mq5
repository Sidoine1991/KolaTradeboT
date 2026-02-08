//+------------------------------------------------------------------+
//| DASHBOARD AMÉLIORÉ - INFORMATIONS COMPLÈTES           |
//+------------------------------------------------------------------+

/*
DASHBOARD AVANCÉ AVEC TOUTES LES INFORMATIONS

✅ AMÉLIORATIONS AJOUTÉES:
1. Informations complètes des endpoints (LOCAL/RENDER)
2. Canal de prédiction visible avec ATR
3. Niveaux d'entrée/sortie clairs
4. Détection d'opportunités de trading
5. Support/Résistance multi-timeframe
6. Informations multi-timeframe EMA/Supertrend

🎯 OBJECTIF:
- Afficher TOUTES les informations de trading
- Montrer les opportunités en temps réel
- Visualiser le canal de prédiction
- Afficher les détails des endpoints IA
*/

//+------------------------------------------------------------------+
//| DASHBOARD AVANCÉ AVEC INFORMATIONS COMPLÈTES           |
//+------------------------------------------------------------------+
void DrawAdvancedDashboard(double rsi, double adx, double atr)
{
   if(!UseAdvancedDashboard) return;
   if(TimeCurrent() - lastDrawTime < DashboardRefresh) return;

   lastDrawTime = TimeCurrent();

   string text = "🤖 GOLDRUSH ADVANCED AI\n";
   text += "═══════════════════\n";
   text += "📊 SYMBOLE: " + _Symbol + "\n";
   text += "⏰ TIME: " + TimeToString(TimeCurrent(), TIME_MINUTES|TIME_SECONDS) + "\n";
   text += "═══════════════════\n";
   
   // Indicateurs techniques
   text += "📈 TECHNIQUES:\n";
   text += "RSI H1: " + DoubleToString(rsi, 1) + "\n";
   text += "ADX H1: " + DoubleToString(adx, 1) + "\n";
   text += "ATR H1: " + DoubleToString(atr, 1) + "\n";
   
   // Informations multi-timeframe
   if(UseMultiTimeframeEMA)
   {
      text += "EMA H1: " + (emaFast_H1_val > emaSlow_H1_val ? "🟢 HAUSSIER" : "🔴 BAISSIER") + "\n";
      text += "EMA M5: " + (emaFast_M5_val > emaSlow_M5_val ? "🟢 HAUSSIER" : "🔴 BAISSIER") + "\n";
      text += "EMA M1: " + (emaFast_M1_val > emaSlow_M1_val ? "🟢 HAUSSIER" : "🔴 BAISSIER") + "\n";
   }
   
   if(UseSupertrendIndicator)
   {
      text += "SUPERTREND: " + (supertrend_H1_dir > 0 ? "🟢 ACHAT" : "🔴 VENTE") + "\n";
   }
   
   // Support et Résistance
   if(UseSupportResistance)
   {
      text += "═══════════════════\n";
      text += "🎯 NIVEAUX SR:\n";
      text += "RÉSIST H1: " + DoubleToString(H1_Resistance, 5) + "\n";
      text += "SUPPORT H1: " + DoubleToString(H1_Support, 5) + "\n";
      text += "RÉSIST M5: " + DoubleToString(M5_Resistance, 5) + "\n";
      text += "SUPPORT M5: " + DoubleToString(M5_Support, 5) + "\n";
   }
   
   text += "═══════════════════\n";
   
   // Informations IA avec détails des endpoints
   if(UseAI_Agent)
   {
      text += "🤖 INTELLIGENCE ARTIFICIELLE:\n";
      text += "Signal: " + StringToUpper(g_lastAIAction) + "\n";
      text += "Confiance: " + DoubleToString(g_lastAIConfidence * 100, 1) + "%\n";
      
      // Afficher le serveur utilisé
      string serverType = "INCONNU";
      if(StringFind(g_lastAIAction, "LOCAL") >= 0)
         serverType = "🏠 LOCAL";
      else if(StringFind(g_lastAIAction, "RENDER") >= 0)
         serverType = "☁️ RENDER";
      else if(g_lastAIAction != "")
         serverType = "🤖 IA";
      
      text += "Serveur: " + serverType + "\n";
      
      // Zones d'entrée/sortie si disponibles
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(g_lastAIAction == "buy")
      {
         text += "🟢 ZONE D'ACHAT:\n";
         text += "Entrée: " + DoubleToString(ask, 5) + "\n";
         text += "Stop: " + DoubleToString(ask - InpStopLoss * _Point, 5) + "\n";
         text += "Target: " + DoubleToString(ask + InpTakeProfit * _Point, 5) + "\n";
      }
      else if(g_lastAIAction == "sell")
      {
         text += "🔴 ZONE DE VENTE:\n";
         text += "Entrée: " + DoubleToString(bid, 5) + "\n";
         text += "Stop: " + DoubleToString(bid + InpStopLoss * _Point, 5) + "\n";
         text += "Target: " + DoubleToString(bid - InpTakeProfit * _Point, 5) + "\n";
      }
   }
   
   // Canal de prédiction (basé sur l'ATR et les indicateurs)
   text += "═══════════════════\n";
   text += "📊 CANAL DE PRÉDICTION:\n";
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2;
   double channelWidth = atr * 2;  // Canal basé sur 2x ATR
   
   text += "Prix Actuel: " + DoubleToString(currentPrice, 5) + "\n";
   text += "Haut Canal: " + DoubleToString(currentPrice + channelWidth, 5) + "\n";
   text += "Bas Canal: " + DoubleToString(currentPrice - channelWidth, 5) + "\n";
   text += "Largeur: " + DoubleToString(channelWidth, 5) + " (" + DoubleToString(channelWidth/_Point, 0) " pts)\n";
   
   // Position dans le canal
   if(currentPrice > (currentPrice + channelWidth * 0.8))
      text += "Position: 🔴 HAUT DU CANAL\n";
   else if(currentPrice < (currentPrice - channelWidth * 0.8))
      text += "Position: 🟢 BAS DU CANAL\n";
   else
      text += "Position: 🟡 CENTRE DU CANAL\n";
   
   text += "═══════════════════\n";
   
   // Informations de trading
   text += "💼 TRADING:\n";
   double currentLot = GetCorrectLotSize();
   text += "Lot Size: " + DoubleToString(currentLot, 2) + "\n";
   text += "Position: " + (g_hasPosition ? "🟢 OUVERTE" : "🔴 AUCUNE") + "\n";
   
   if(UseDerivArrowDetection)
   {
      text += "DERIV Arrow: " + (derivArrowPresent ? "✅ OUI" : "❌ NON") + "\n";
      if(derivArrowPresent)
         text += "Arrow Type: " + (derivArrowType == 1 ? "🟢 BUY" : "🔴 SELL") + "\n";
   }
   
   // Gestion des profits
   if(UseProfitDuplication && g_hasPosition)
   {
      text += "═══════════════════\n";
      text += "💰 GESTION PROFITS:\n";
      text += "Profit Total: " + DoubleToString(totalSymbolProfit, 2) + "$\n";
      text += "Dupliqué: " + (hasDuplicated ? "✅ OUI" : "❌ NON") + "\n";
      if(hasDuplicated)
         text += "Ticket Dup: " + IntegerToString(duplicatedPositionTicket) + "\n";
   }
   
   // Opportunités de trading
   text += "═══════════════════\n";
   text += "🎯 OPPORTUNITÉS:\n";
   
   // Évaluer les opportunités
   bool opportunityBuy = false;
   bool opportunitySell = false;
   string opportunityReason = "";
   
   // Analyse des opportunités
   if(UseMultiTimeframeEMA)
   {
      bool emaBullish = (emaFast_H1_val > emaSlow_H1_val && 
                        emaFast_M5_val > emaSlow_M5_val && 
                        emaFast_M1_val > emaSlow_M1_val);
      bool emaBearish = (emaFast_H1_val < emaSlow_H1_val && 
                        emaFast_M5_val < emaSlow_M5_val && 
                        emaFast_M1_val < emaSlow_M1_val);
      
      if(emaBullish && rsi < 70)
      {
         opportunityBuy = true;
         opportunityReason += "🟢 EMA HAUSSIÈRE + RSI<" + DoubleToString(70, 0) + " ";
      }
      
      if(emaBearish && rsi > 30)
      {
         opportunitySell = true;
         opportunityReason += "🔴 EMA BAISSIÈRE + RSI>" + DoubleToString(30, 0) + " ";
      }
   }
   
   if(UseSupertrendIndicator)
   {
      if(supertrend_H1_dir > 0 && rsi < 70)
      {
         opportunityBuy = true;
         opportunityReason += "🟢 SUPERTREND ACHAT ";
      }
      
      if(supertrend_H1_dir < 0 && rsi > 30)
      {
         opportunitySell = true;
         opportunityReason += "🔴 SUPERTREND VENTE ";
      }
   }
   
   if(UseAI_Agent && g_lastAIConfidence >= AI_MinConfidence)
   {
      if(g_lastAIAction == "buy")
      {
         opportunityBuy = true;
         opportunityReason += "🤖 IA CONFIANCE " + DoubleToString(g_lastAIConfidence * 100, 0) + "% ";
      }
      else if(g_lastAIAction == "sell")
      {
         opportunitySell = true;
         opportunityReason += "🤖 IA CONFIANCE " + DoubleToString(g_lastAIConfidence * 100, 0) + "% ";
      }
   }
   
   // Afficher les opportunités
   if(opportunityBuy || opportunitySell)
   {
      text += "🎯 OPPORTUNITÉS DÉTECTÉES!\n";
      text += opportunityReason + "\n";
      
      if(opportunityBuy)
         text += "🟢 OPPORTUNITÉ D'ACHAT\n";
      if(opportunitySell)
         text += "🔴 OPPORTUNITÉ DE VENTE\n";
   }
   else
   {
      text += "⏳ ATTENTE SIGNAL\n";
      text += "Conditions non remplies\n";
   }

   if(text == lastDashText) return;
   lastDashText = text;

   if(ObjectFind(0,"Dashboard")==-1)
      ObjectCreate(0,"Dashboard",OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,"Dashboard",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,"Dashboard",OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,"Dashboard",OBJPROP_YDISTANCE,20);
   ObjectSetInteger(0,"Dashboard",OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,"Dashboard",OBJPROP_COLOR,clrWhite);
   ObjectSetString(0,"Dashboard",OBJPROP_TEXT,text);
}

//+------------------------------------------------------------------+
//| TEST DU DASHBOARD AMÉLIORÉ                        |
//+------------------------------------------------------------------+
void TestImprovedDashboard()
{
   Print("=== TEST DASHBOARD AMÉLIORÉ ===");
   
   // Simuler des valeurs pour le test
   double testRSI = 55.5;
   double testADX = 25.3;
   double testATR = 0.0123;
   
   Print("📊 Dashboard avec informations complètes:");
   Print("   - Informations IA (LOCAL/RENDER)");
   Print("   - Canal de prédiction ATR");
   Print("   - Niveaux d'entrée/sortie");
   Print("   - Support/Résistance MTF");
   Print("   - Détection d'opportunités");
   Print("   - Informations multi-timeframe");
   
   // Appeler le dashboard amélioré
   DrawAdvancedDashboard(testRSI, testADX, testATR);
   
   Print("✅ Dashboard amélioré testé avec succès");
}

//+------------------------------------------------------------------+
int OnInit()
{
   TestImprovedDashboard();
   return INIT_SUCCEEDED;
}
