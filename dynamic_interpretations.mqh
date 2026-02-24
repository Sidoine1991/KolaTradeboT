//+------------------------------------------------------------------+
//| INTERPRÉTATIONS DYNAMIQUES - FONCTIONS AUTONOMES               |
//+------------------------------------------------------------------+

// NOTE: Les variables globales sont déclarées dans le fichier principal
// Pas besoin de déclarations externes pour éviter les conflits

//+------------------------------------------------------------------+
//| DESSINER LES INTERPRÉTATIONS DYNAMIQUES SUR LE GRAPHIQUE         |
//+------------------------------------------------------------------+
bool DrawDynamicInterpretations()
{
   // Vérifier si les graphiques sont désactivés
   if(DisableAllGraphics) return false;
   
   // Nettoyer les anciennes interprétations
   ObjectsDeleteAll(0, "INTERP_");
   
   // Récupérer les données actuelles
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Obtenir les données de prix pour analyse
   double close[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 50, close) < 50 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 50, high) < 50 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 50, low) < 50)
      return false;
   
   datetime currentTime = TimeCurrent();
   datetime displayTime = currentTime + 300; // Afficher 5 minutes dans le futur
   
   // === 1. ZONE D'INTERPRÉTATION PRINCIPALE ===
   string mainInterpretation = GetMainInterpretation(currentPrice, close, high, low);
   color mainColor = GetInterpretationColor(mainInterpretation);
   
   ObjectCreate(0, "INTERP_MAIN", OBJ_TEXT, 0, displayTime, currentPrice + 500 * point);
   ObjectSetString(0, "INTERP_MAIN", OBJPROP_TEXT, mainInterpretation);
   ObjectSetInteger(0, "INTERP_MAIN", OBJPROP_COLOR, mainColor);
   ObjectSetInteger(0, "INTERP_MAIN", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, "INTERP_MAIN", OBJPROP_BACK, false);
   
   // === 2. ANALYSE MULTI-TIMEFRAME ===
   string mtfAnalysis = GetMultiTimeframeAnalysis();
   
   ObjectCreate(0, "INTERP_MTF", OBJ_TEXT, 0, displayTime, currentPrice + 300 * point);
   ObjectSetString(0, "INTERP_MTF", OBJPROP_TEXT, "M1 M5 M15 H1: " + mtfAnalysis);
   ObjectSetInteger(0, "INTERP_MTF", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "INTERP_MTF", OBJPROP_FONTSIZE, 8);
   
   // === 3. ÉTAT IA ET CONFIANCE ===
   string aiStatus = GetAIStatusInterpretation();
   
   ObjectCreate(0, "INTERP_AI", OBJ_TEXT, 0, displayTime, currentPrice + 100 * point);
   ObjectSetString(0, "INTERP_AI", OBJPROP_TEXT, aiStatus);
   ObjectSetInteger(0, "INTERP_AI", OBJPROP_COLOR, clrCyan);
   ObjectSetInteger(0, "INTERP_AI", OBJPROP_FONTSIZE, 8);
   
   // === 4. ZONES PREMIUM/DISCOUNT INTERPRÉTATION ===
   string zoneInterpretation = GetZoneInterpretation(currentPrice, close);
   
   ObjectCreate(0, "INTERP_ZONE", OBJ_TEXT, 0, displayTime, currentPrice - 100 * point);
   ObjectSetString(0, "INTERP_ZONE", OBJPROP_TEXT, zoneInterpretation);
   ObjectSetInteger(0, "INTERP_ZONE", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, "INTERP_ZONE", OBJPROP_FONTSIZE, 8);
   
   // === 5. SCÉNARIOS POSSIBLES ===
   string scenarios = GetPossibleScenarios(currentPrice, close);
   
   ObjectCreate(0, "INTERP_SCENARIOS", OBJ_TEXT, 0, displayTime, currentPrice - 300 * point);
   ObjectSetString(0, "INTERP_SCENARIOS", OBJPROP_TEXT, scenarios);
   ObjectSetInteger(0, "INTERP_SCENARIOS", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "INTERP_SCENARIOS", OBJPROP_FONTSIZE, 8);
   
   // === 6. NIVEAUX CLÉS DYNAMIQUES ===
   string keyLevels = GetKeyLevelsInterpretation(high, low);
   
   ObjectCreate(0, "INTERP_LEVELS", OBJ_TEXT, 0, displayTime, currentPrice - 500 * point);
   ObjectSetString(0, "INTERP_LEVELS", OBJPROP_TEXT, keyLevels);
   ObjectSetInteger(0, "INTERP_LEVELS", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "INTERP_LEVELS", OBJPROP_FONTSIZE, 8);
   
   // === 7. ACTION RECOMMANDÉE ===
   string actionRecommendation = GetActionRecommendation();
   
   ObjectCreate(0, "INTERP_ACTION", OBJ_TEXT, 0, displayTime, currentPrice - 700 * point);
   ObjectSetString(0, "INTERP_ACTION", OBJPROP_TEXT, "ACTION: " + actionRecommendation);
   ObjectSetInteger(0, "INTERP_ACTION", OBJPROP_COLOR, GetActionColor(actionRecommendation));
   ObjectSetInteger(0, "INTERP_ACTION", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "INTERP_ACTION", OBJPROP_BACK, false);
   
   return true;
}

//+------------------------------------------------------------------+
//| OBTENIR L'INTERPRÉTATION PRINCIPALE                              |
//+------------------------------------------------------------------+
string GetMainInterpretation(double currentPrice, double &close[], double &high[], double &low[])
{
   // Calculer la moyenne mobile simple
   double sma20 = 0;
   for(int i = 0; i < 20; i++)
      sma20 += close[i];
   sma20 /= 20;
   
   // Déterminer la position par rapport à la SMA
   double distanceFromSMA = (currentPrice - sma20) / (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100);
   
   string interpretation = "";
   
   if(distanceFromSMA > 10)
   {
      interpretation = "🔥 PRIX EN ZONE PREMIUM - SURÉVALUÉ";
   }
   else if(distanceFromSMA < -10)
   {
      interpretation = "💧 PRIX EN ZONE DISCOUNT - SOUS-ÉVALUÉ";
   }
   else
   {
      interpretation = "⚖️ PRIX EN ZONE D'ÉQUILIBRE - NEUTRE";
   }
   
   // Ajouter l'analyse de momentum
   double momentum = (close[0] - close[5]) / close[5] * 100;
   
   if(momentum > 0.1)
      interpretation += " | MOMENTUM HAUSSIER 📈";
   else if(momentum < -0.1)
      interpretation += " | MOMENTUM BAISSIER 📉";
   else
      interpretation += " | MOMENTUM STABLE ➡️";
   
   return interpretation;
}

//+------------------------------------------------------------------+
//| OBTENIR L'ANALYSE MULTI-TIMEFRAME                               |
//+------------------------------------------------------------------+
string GetMultiTimeframeAnalysis()
{
   // Simuler l'analyse multi-timeframe (remplacer par vraie analyse)
   string m1 = GetTrendOnTimeframe(PERIOD_M1);
   string m5 = GetTrendOnTimeframe(PERIOD_M5);
   string m15 = GetTrendOnTimeframe(PERIOD_M15);
   string h1 = GetTrendOnTimeframe(PERIOD_H1);
   
   return m1 + " | " + m5 + " | " + m15 + " | " + h1;
}

//+------------------------------------------------------------------+
//| OBTENIR LA TENDANCE SUR UN TIMEFRAME SPÉCIFIQUE                  |
//+------------------------------------------------------------------+
string GetTrendOnTimeframe(ENUM_TIMEFRAMES timeframe)
{
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   int localEmaFastHandle = iMA(_Symbol, timeframe, 9, 0, MODE_EMA, PRICE_CLOSE);
   int localEmaSlowHandle = iMA(_Symbol, timeframe, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   if(CopyBuffer(localEmaFastHandle, 0, 0, 2, emaFast) < 2 ||
      CopyBuffer(localEmaSlowHandle, 0, 0, 2, emaSlow) < 2)
      return "??";
   
   if(emaFast[0] > emaSlow[0] && emaFast[1] > emaSlow[1])
      return "📈UP";
   else if(emaFast[0] < emaSlow[0] && emaFast[1] < emaSlow[1])
      return "📉DOWN";
   else
      return "➡️SIDE";
}

//+------------------------------------------------------------------+
//| OBTENIR L'INTERPRÉTATION DE L'ÉTAT IA                           |
//+------------------------------------------------------------------+
string GetAIStatusInterpretation()
{
   string signal = g_aiSignal.recommendation;
   double confidence = g_aiSignal.confidence;
   
   string status = "";
   
   if(confidence >= 0.8)
      status = "🤖 IA: " + signal + " (FORTE: " + DoubleToString(confidence * 100, 1) + "%)";
   else if(confidence >= 0.6)
      status = "🤖 IA: " + signal + " (MODÉRÉE: " + DoubleToString(confidence * 100, 1) + "%)";
   else
      status = "🤖 IA: WAITING (FAIBLE: " + DoubleToString(confidence * 100, 1) + "%)";
   
   return status;
}

//+------------------------------------------------------------------+
//| OBTENIR L'INTERPRÉTATION DES ZONES                              |
//+------------------------------------------------------------------+
string GetZoneInterpretation(double currentPrice, double &close[])
{
   // Calculer SMA20
   double sma20 = 0;
   for(int i = 0; i < 20; i++)
      sma20 += close[i];
   sma20 /= 20;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double distance = (currentPrice - sma20) / point;
   
   if(distance > 500)
      return "🔥 ZONE PREMIUM - Chercher des signaux de VENTE";
   else if(distance < -500)
      return "💧 ZONE DISCOUNT - Chercher des signaux d'ACHAT";
   else
      return "⚖️ ZONE D'ÉQUILIBRE - Attendre une cassure";
}

//+------------------------------------------------------------------+
//| OBTENIR LES SCÉNARIOS POSSIBLES                                   |
//+------------------------------------------------------------------+
string GetPossibleScenarios(double currentPrice, double &close[])
{
   double sma20 = 0;
   for(int i = 0; i < 20; i++)
      sma20 += close[i];
   sma20 /= 20;
   
   string scenarios = "";
   
   if(currentPrice > sma20)
   {
      scenarios = "📈 SCÉNARIOS: 1) Continuation haussière 2) Retest SMA 3) Retournement";
   }
   else
   {
      scenarios = "📉 SCÉNARIOS: 1) Continuation baissière 2) Rebond SMA 3) Retournement";
   }
   
   return scenarios;
}

//+------------------------------------------------------------------+
//| OBTENIR L'INTERPRÉTATION DES NIVEAUX CLÉS                        |
//+------------------------------------------------------------------+
string GetKeyLevelsInterpretation(double &high[], double &low[])
{
   // Trouver le plus haut et plus bas récents
   double recentHigh = high[ArrayMaximum(high, 0, 20)];
   double recentLow = low[ArrayMinimum(low, 0, 20)];
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   string levels = "🎯 NIVEAUX CLÉS: ";
   
   if(currentPrice < recentHigh)
      levels += "RÉSISTANCE " + DoubleToString(recentHigh, 5);
   
   if(currentPrice > recentLow)
      levels += " | SUPPORT " + DoubleToString(recentLow, 5);
   
   return levels;
}

//+------------------------------------------------------------------+
//| OBTENIR L'ACTION RECOMMANDÉE                                     |
//+------------------------------------------------------------------+
string GetActionRecommendation()
{
   double confidence = g_aiSignal.confidence;
   string signal = g_aiSignal.recommendation;
   
   if(confidence >= 0.8 && signal != "waiting")
   {
      if(signal == "buy")
         return "🟢 ACHETER IMMÉDIATEMENT";
      else if(signal == "sell")
         return "🔴 VENDRE IMMÉDIATEMENT";
   }
   else if(confidence >= 0.6)
   {
      return "🟡 SURVEILLER - SEUIL APPROCHE";
   }
   else
   {
      return "🔴 ATTENTE - CONDITIONS NON OPTIMALES";
   }
   
   return "⚪ EN ANALYSE";
}

//+------------------------------------------------------------------+
//| OBTENIR LA COULEUR D'INTERPRÉTATION                              |
//+------------------------------------------------------------------+
color GetInterpretationColor(string interpretation)
{
   if(StringFind(interpretation, "PREMIUM") >= 0)
      return clrOrange;
   else if(StringFind(interpretation, "DISCOUNT") >= 0)
      return clrDodgerBlue;
   else if(StringFind(interpretation, "ÉQUILIBRE") >= 0)
      return clrGray;
   else if(StringFind(interpretation, "HAUSSIER") >= 0)
      return clrLime;
   else if(StringFind(interpretation, "BAISSIER") >= 0)
      return clrRed;
   
   return clrWhite;
}

//+------------------------------------------------------------------+
//| OBTENIR LA COULEUR D'ACTION                                      |
//+------------------------------------------------------------------+
color GetActionColor(string action)
{
   if(StringFind(action, "ACHETER") >= 0)
      return clrLime;
   else if(StringFind(action, "VENDRE") >= 0)
      return clrRed;
   else if(StringFind(action, "SURVEILLER") >= 0)
      return clrYellow;
   else if(StringFind(action, "ATTENTE") >= 0)
      return clrOrange;
   
   return clrGray;
}
