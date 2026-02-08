//+------------------------------------------------------------------+
//| Fonctions d'affichage IA pour F_INX_Scalper_double.mq5            |
//+------------------------------------------------------------------+

// Déclarations des variables globales externes
extern bool g_UseAI_Agent_Live;
extern string g_lastAIAction;
extern double g_lastAIConfidence;
extern bool g_hasPosition;
extern bool g_predictionValid;
extern double g_aiBuyZoneLow;
extern double g_aiSellZoneHigh;
extern bool g_predictiveChannelValid;
extern double g_channelConfidence;
extern double MinConfidence;

// Déclarations des handles EMA externes
extern int emaFastHandle;
extern int emaSlowHandle;
extern int emaFastM5Handle;
extern int emaSlowM5Handle;
extern int emaFastH1Handle;
extern int emaSlowH1Handle;

//+------------------------------------------------------------------+
//| Afficher le panneau IA complet sur le graphique                  |
//+------------------------------------------------------------------+
void DrawCompleteAIPanel()
{
   if(!g_UseAI_Agent_Live)
      return;
   
   // Supprimer les anciens objets du panneau
   DeleteObjectsByPrefix("AI_PANEL_");
   
   // Position du panneau (coin supérieur droit)
   int x = 50;
   int y = 30;
   int lineHeight = 20;
   int panelWidth = 400;
   
   // Fond du panneau
   string panelName = "AI_PANEL_BG";
   ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, panelName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 220);
   ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrWhite);
   
   // Titre
   DrawAIText("AI_PANEL_TITLE", x + 10, y + 10, " SERVEUR IA", clrLime, 12);
   
   // Recommandation du serveur IA
   string aiAction = (g_lastAIAction == "buy") ? "🟢 BUY" : 
                     (g_lastAIAction == "sell") ? "🔴 SELL" : 
                     (g_lastAIAction == "hold") ? "🟡 HOLD" : "❓ INCONNU";
   
   DrawAIText("AI_PANEL_ACTION", x + 10, y + 35, "Recommandation: " + aiAction, clrWhite, 10);
   
   // Confiance en pourcentage (corrigé)
   double confidencePercent = g_lastAIConfidence * 100.0; // g_lastAIConfidence est en 0.0-1.0, convertir en %
   string confidenceText = StringFormat("Confiance: %.1f%%", confidencePercent);
   color confidenceColor = (confidencePercent >= 70.0) ? clrLime : 
                           (confidencePercent >= 50.0) ? clrYellow : clrRed;
   
   DrawAIText("AI_PANEL_CONFIDENCE", x + 10, y + 55, confidenceText, confidenceColor, 10);
   
   // Alignement des tendances
   string alignmentText = GetAlignmentText();
   DrawAIText("AI_PANEL_ALIGNMENT", x + 10, y + 75, alignmentText, clrWhite, 10);
   
   // Tendances par timeframe (M1, M5, H1)
   string trendText = GetTrendText();
   DrawAIText("AI_PANEL_TRENDS", x + 10, y + 95, "Tendances: " + trendText, clrCyan, 10);
   
   // Décision finale
   string decisionText = GetFinalDecisionText();
   color decisionColor = (StringFind(decisionText, "BUY") >= 0) ? clrLime :
                        (StringFind(decisionText, "SELL") >= 0) ? clrRed : clrYellow;
   
   DrawAIText("AI_PANEL_DECISION", x + 10, y + 115, "Décision: " + decisionText, decisionColor, 11, true);
   
   // Zone de prédiction avec pourcentage corrigé
   if(g_predictionValid)
   {
      string zoneText = GetPredictionZoneText();
      DrawAIText("AI_PANEL_ZONE", x + 10, y + 135, "Zone: " + zoneText, clrAqua, 10);
   }
   
   // Canal prédictif
   if(g_predictiveChannelValid)
   {
      string channelText = StringFormat("Canal: %.1f%% confiance", g_channelConfidence);
      DrawAIText("AI_PANEL_CHANNEL", x + 10, y + 155, channelText, clrOrange, 10);
   }
   
   // Timestamp
   string timeText = TimeToString(TimeCurrent(), TIME_SECONDS);
   DrawAIText("AI_PANEL_TIME", x + 10, y + 175, "Dernière MAJ: " + timeText, clrGray, 9);
}

//+------------------------------------------------------------------+
//| Dessiner un texte IA sur le graphique                            |
//+------------------------------------------------------------------+
void DrawAIText(string name, int x, int y, string text, color clr, int fontSize = 10, bool bold = false)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Obtenir le texte d'alignement des tendances                      |
//+------------------------------------------------------------------+
string GetAlignmentText()
{
   string text = "Alignement: ";
   
   // Récupérer les valeurs EMA depuis les handles
   double emaFastM1[], emaSlowM1[], emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   
   // M1
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFastM1) > 0 && 
      CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlowM1) > 0)
   {
      if(emaFastM1[0] > emaSlowM1[0])
         text += "M1🟢 ";
      else
         text += "M1🔴 ";
   }
   else
   {
      text += "M1❓ ";
   }
   
   // M5
   if(CopyBuffer(emaFastM5Handle, 0, 0, 1, emaFastM5) > 0 && 
      CopyBuffer(emaSlowM5Handle, 0, 0, 1, emaSlowM5) > 0)
   {
      if(emaFastM5[0] > emaSlowM5[0])
         text += "M5🟢 ";
      else
         text += "M5🔴 ";
   }
   else
   {
      text += "M5❓ ";
   }
   
   // H1
   if(CopyBuffer(emaFastH1Handle, 0, 0, 1, emaFastH1) > 0 && 
      CopyBuffer(emaSlowH1Handle, 0, 0, 1, emaSlowH1) > 0)
   {
      if(emaFastH1[0] > emaSlowH1[0])
         text += "H1🟢 ";
      else
         text += "H1🔴 ";
   }
   else
   {
      text += "H1❓ ";
   }
   
   return text;
}

//+------------------------------------------------------------------+
//| Obtenir le texte de décision finale                               |
//+------------------------------------------------------------------+
string GetFinalDecisionText()
{
   if(!g_hasPosition)
   {
      if(g_lastAIAction == "BUY" && g_lastAIConfidence >= MinConfidence/100.0)
         return "🟢 EXECUTER BUY";
      else if(g_lastAIAction == "SELL" && g_lastAIConfidence >= MinConfidence/100.0)
         return "🔴 EXECUTER SELL";
      else
         return "🟡 ATTENTE";
   }
   else
   {
      return "📊 POSITION OUVERTE";
   }
}

//+------------------------------------------------------------------+
//| Obtenir le texte de zone de prédiction                           |
//+------------------------------------------------------------------+
string GetPredictionZoneText()
{
   if(!g_predictionValid)
      return "Non disponible";
   
   // Zone de prédiction basée sur les niveaux calculés
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(currentPrice < g_aiBuyZoneLow)
      return "🟢 ZONE BUY (" + DoubleToString(g_aiBuyZoneLow, _Digits) + ")";
   else if(currentPrice > g_aiSellZoneHigh)
      return "🔴 ZONE SELL (" + DoubleToString(g_aiSellZoneHigh, _Digits) + ")";
   else
      return "🟡 ZONE NEUTRE";
}

//+------------------------------------------------------------------+
//| Obtenir le texte des tendances par timeframe                     |
//+------------------------------------------------------------------+
string GetTrendText()
{
   // Récupérer les EMA pour M1, M5, H1
   double emaFastM1[], emaSlowM1[], emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   
   // Copier les données des indicateurs
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFastM1) <= 0 ||
      CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlowM1) <= 0 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 1, emaFastM5) <= 0 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 1, emaSlowM5) <= 0 ||
      CopyBuffer(emaFastH1Handle, 0, 0, 1, emaFastH1) <= 0 ||
      CopyBuffer(emaSlowH1Handle, 0, 0, 1, emaSlowH1) <= 0)
   {
      return "M1:❓ M5:❓ H1:❓";
   }
   
   // Déterminer les tendances
   string m1Trend = (emaFastM1[0] > emaSlowM1[0]) ? "M1:📈" : (emaFastM1[0] < emaSlowM1[0]) ? "M1:📉" : "M1:➡️";
   string m5Trend = (emaFastM5[0] > emaSlowM5[0]) ? "M5:📈" : (emaFastM5[0] < emaSlowM5[0]) ? "M5:📉" : "M5:➡️";
   string h1Trend = (emaFastH1[0] > emaSlowH1[0]) ? "H1:📈" : (emaFastH1[0] < emaSlowH1[0]) ? "H1:📉" : "H1:➡️";
   
   return m1Trend + " " + m5Trend + " " + h1Trend;
}

//+------------------------------------------------------------------+
