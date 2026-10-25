//+------------------------------------------------------------------+
//| Affiche les EMA sur le graphique avec différentes couleurs        |
//+------------------------------------------------------------------+
void DrawEMAOnChart()
{
   // Noms des objets pour les EMA
   string emaFastName = "EMA_FAST_LINE";
   string emaSlowName = "EMA_SLOW_LINE";
   string emaFastEntryName = "EMA_FAST_ENTRY_LINE";
   string emaSlowEntryName = "EMA_SLOW_ENTRY_LINE";
   
   // Supprimer les anciennes lignes EMA
   ObjectDelete(0, emaFastName);
   ObjectDelete(0, emaSlowName);
   ObjectDelete(0, emaFastEntryName);
   ObjectDelete(0, emaSlowEntryName);
   
   // Récupérer les données des EMA pour les dernières 100 bougies
   int barsToDraw = 100;
   double emaFast[], emaSlow[], emaFastEntry[], emaSlowEntry[];
   datetime time[];
   
   if(CopyBuffer(emaFastHandle, 0, 0, barsToDraw, emaFast) < barsToDraw ||
      CopyBuffer(emaSlowHandle, 0, 0, barsToDraw, emaSlow) < barsToDraw ||
      CopyBuffer(emaFastEntryHandle, 0, 0, barsToDraw, emaFastEntry) < barsToDraw ||
      CopyBuffer(emaSlowEntryHandle, 0, 0, barsToDraw, emaSlowEntry) < barsToDraw ||
      CopyTime(_Symbol, PERIOD_CURRENT, 0, barsToDraw, time) < barsToDraw)
   {
      return;
   }
   
   // Créer les lignes EMA Fast (H1) - Bleu
   if(!ObjectCreate(0, emaFastName, OBJ_TREND, 0, 0, 0))
      return;
   
   ObjectSetInteger(0, emaFastName, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, emaFastName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, emaFastName, OBJPROP_WIDTH, 2);
   ObjectSetString(0, emaFastName, OBJPROP_TEXT, "EMA Fast H1");
   ObjectSetInteger(0, emaFastName, OBJPROP_RAY_RIGHT, false);
   
   // Définir les points de la ligne EMA Fast
   for(int i = 0; i < barsToDraw - 1; i++)
   {
      if(i == 0)
      {
         ObjectSetInteger(0, emaFastName, OBJPROP_TIME, 0, time[i]);
         ObjectSetDouble(0, emaFastName, OBJPROP_PRICE, 0, emaFast[i]);
      }
      ObjectSetInteger(0, emaFastName, OBJPROP_TIME, 1, time[barsToDraw - 1]);
      ObjectSetDouble(0, emaFastName, OBJPROP_PRICE, 1, emaFast[barsToDraw - 1]);
   }
   
   // Créer les lignes EMA Slow (H1) - Rouge
   if(!ObjectCreate(0, emaSlowName, OBJ_TREND, 0, 0, 0))
      return;
   
   ObjectSetInteger(0, emaSlowName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, emaSlowName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, emaSlowName, OBJPROP_WIDTH, 2);
   ObjectSetString(0, emaSlowName, OBJPROP_TEXT, "EMA Slow H1");
   ObjectSetInteger(0, emaSlowName, OBJPROP_RAY_RIGHT, false);
   
   // Définir les points de la ligne EMA Slow
   for(int i = 0; i < barsToDraw - 1; i++)
   {
      if(i == 0)
      {
         ObjectSetInteger(0, emaSlowName, OBJPROP_TIME, 0, time[i]);
         ObjectSetDouble(0, emaSlowName, OBJPROP_PRICE, 0, emaSlow[i]);
      }
      ObjectSetInteger(0, emaSlowName, OBJPROP_TIME, 1, time[barsToDraw - 1]);
      ObjectSetDouble(0, emaSlowName, OBJPROP_PRICE, 1, emaSlow[barsToDraw - 1]);
   }
   
   // Créer les lignes EMA Fast Entry (M1) - Vert
   if(!ObjectCreate(0, emaFastEntryName, OBJ_TREND, 0, 0, 0))
      return;
   
   ObjectSetInteger(0, emaFastEntryName, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, emaFastEntryName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, emaFastEntryName, OBJPROP_WIDTH, 1);
   ObjectSetString(0, emaFastEntryName, OBJPROP_TEXT, "EMA Fast M1");
   ObjectSetInteger(0, emaFastEntryName, OBJPROP_RAY_RIGHT, false);
   
   // Définir les points de la ligne EMA Fast Entry
   for(int i = 0; i < barsToDraw - 1; i++)
   {
      if(i == 0)
      {
         ObjectSetInteger(0, emaFastEntryName, OBJPROP_TIME, 0, time[i]);
         ObjectSetDouble(0, emaFastEntryName, OBJPROP_PRICE, 0, emaFastEntry[i]);
      }
      ObjectSetInteger(0, emaFastEntryName, OBJPROP_TIME, 1, time[barsToDraw - 1]);
      ObjectSetDouble(0, emaFastEntryName, OBJPROP_PRICE, 1, emaFastEntry[barsToDraw - 1]);
   }
   
   // Créer les lignes EMA Slow Entry (M1) - Orange
   if(!ObjectCreate(0, emaSlowEntryName, OBJ_TREND, 0, 0, 0))
      return;
   
   ObjectSetInteger(0, emaSlowEntryName, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, emaSlowEntryName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, emaSlowEntryName, OBJPROP_WIDTH, 1);
   ObjectSetString(0, emaSlowEntryName, OBJPROP_TEXT, "EMA Slow M1");
   ObjectSetInteger(0, emaSlowEntryName, OBJPROP_RAY_RIGHT, false);
   
   // Définir les points de la ligne EMA Slow Entry
   for(int i = 0; i < barsToDraw - 1; i++)
   {
      if(i == 0)
      {
         ObjectSetInteger(0, emaSlowEntryName, OBJPROP_TIME, 0, time[i]);
         ObjectSetDouble(0, emaSlowEntryName, OBJPROP_PRICE, 0, emaSlowEntry[i]);
      }
      ObjectSetInteger(0, emaSlowEntryName, OBJPROP_TIME, 1, time[barsToDraw - 1]);
      ObjectSetDouble(0, emaSlowEntryName, OBJPROP_PRICE, 1, emaSlowEntry[barsToDraw - 1]);
   }
   
   // Ajouter une légende pour les EMA
   string legendName = "EMA_LEGEND";
   ObjectDelete(0, legendName);
   
   if(ObjectCreate(0, legendName, OBJ_LABEL, 0, 0, 0))
   {
      string legendText = "EMA LÉGENDE\n";
      legendText += "━━━━━━━━━━━━━━━━\n";
      legendText += "EMA Fast H1: ■\n";
      legendText += "EMA Slow H1: ■\n";
      legendText += "EMA Fast M1: ■\n";
      legendText += "EMA Slow M1: ■";
      
      ObjectSetString(0, legendName, OBJPROP_TEXT, legendText);
      ObjectSetInteger(0, legendName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, legendName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, legendName, OBJPROP_YDISTANCE, 100);
      ObjectSetInteger(0, legendName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, legendName, OBJPROP_FONT, "Courier New");
      ObjectSetInteger(0, legendName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, legendName, OBJPROP_BACK, true);
      ObjectSetInteger(0, legendName, OBJPROP_BGCOLOR, C'20,20,20');
      ObjectSetInteger(0, legendName, OBJPROP_BORDER_COLOR, C'60,60,60');
   }
}
