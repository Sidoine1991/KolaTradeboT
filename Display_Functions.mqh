//+------------------------------------------------------------------+
//| Fonctions d'affichage améliorées pour le robot                    |
//+------------------------------------------------------------------+

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
   ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 200);
   ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrWhite);
   
   // Titre
   DrawAIText("AI_PANEL_TITLE", x + 10, y + 10, "🤖 SERVEUR IA", clrLime, 12);
   
   // Recommandation du serveur IA
   string aiAction = (g_aiAction == "BUY") ? "🟢 BUY" : 
                     (g_aiAction == "SELL") ? "🔴 SELL" : 
                     (g_aiAction == "HOLD") ? "🟡 HOLD" : "❓ INCONNU";
   
   DrawAIText("AI_PANEL_ACTION", x + 10, y + 35, "Recommandation: " + aiAction, clrWhite, 10);
   
   // Confiance en pourcentage (corrigé)
   double confidencePercent = g_aiConfidence * 100.0; // Convertir en pourcentage
   string confidenceText = StringFormat("Confiance: %.1f%%", confidencePercent);
   color confidenceColor = (confidencePercent >= 70.0) ? clrLime : 
                           (confidencePercent >= 50.0) ? clrYellow : clrRed;
   
   DrawAIText("AI_PANEL_CONFIDENCE", x + 10, y + 55, confidenceText, confidenceColor, 10);
   
   // Alignement des tendances
   string alignmentText = GetAlignmentText();
   DrawAIText("AI_PANEL_ALIGNMENT", x + 10, y + 75, alignmentText, clrWhite, 10);
   
   // Décision finale
   string decisionText = GetFinalDecisionText();
   color decisionColor = (StringFind(decisionText, "BUY") >= 0) ? clrLime :
                        (StringFind(decisionText, "SELL") >= 0) ? clrRed : clrYellow;
   
   DrawAIText("AI_PANEL_DECISION", x + 10, y + 95, "Décision: " + decisionText, decisionColor, 11, true);
   
   // Zone de prédiction avec pourcentage corrigé
   if(g_predictionsValid)
   {
      string zoneText = GetPredictionZoneText();
      DrawAIText("AI_PANEL_ZONE", x + 10, y + 115, "Zone: " + zoneText, clrAqua, 10);
   }
   
   // Canal prédictif
   if(g_predictiveChannelValid)
   {
      string channelText = StringFormat("Canal: %.1f%% confiance", g_predictiveChannelConfidence * 100.0);
      DrawAIText("AI_PANEL_CHANNEL", x + 10, y + 135, channelText, clrOrange, 10);
   }
   
   // Timestamp
   string timeText = TimeToString(TimeCurrent(), TIME_SECONDS);
   DrawAIText("AI_PANEL_TIME", x + 10, y + 155, "Dernière MAJ: " + timeText, clrGray, 9);
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
   
   // M1
   if(g_emaFastM1 > g_emaSlowM1)
      text += "M1🟢 ";
   else
      text += "M1🔴 ";
   
   // M5
   if(g_emaFastM5 > g_emaSlowM5)
      text += "M5🟢 ";
   else
      text += "M5🔴 ";
   
   // H1
   if(g_emaFastH1 > g_emaSlowH1)
      text += "H1🟢 ";
   else
      text += "H1🔴 ";
   
   return text;
}

//+------------------------------------------------------------------+
//| Obtenir le texte de décision finale                               |
//+------------------------------------------------------------------+
string GetFinalDecisionText()
{
   if(!g_hasPosition)
   {
      if(g_aiAction == "BUY" && g_aiConfidence >= MinConfidence/100.0)
         return "🟢 EXECUTER BUY";
      else if(g_aiAction == "SELL" && g_aiConfidence >= MinConfidence/100.0)
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
   if(!g_predictionsValid)
      return "Non disponible";
   
   // Zone de prédiction basée sur les niveaux calculés
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(currentPrice < g_buyZoneLevel)
      return "🟢 ZONE BUY (" + DoubleToString(g_buyZoneLevel, _Digits) + ")";
   else if(currentPrice > g_sellZoneLevel)
      return "🔴 ZONE SELL (" + DoubleToString(g_sellZoneLevel, _Digits) + ")";
   else
      return "🟡 ZONE NEUTRE";
}

//+------------------------------------------------------------------+
//| Supprimer les objets par préfixe                                 |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
      {
         ObjectDelete(0, name);
      }
   }
}
