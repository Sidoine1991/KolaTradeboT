//+------------------------------------------------------------------+
//| Visuals.mqh - Gestion des éléments visuels pour Fx_robot         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property strict

//--- Inclusions
#include "D:\\Dev\\TradBOT\\mt5\\includes\\Common.mqh"

//--- Variables d'entrée pour les visuels
input color    InpColorOB_Bull          = clrLime;
input color    InpColorOB_Bear          = clrRed;
input color    InpColorTrend            = clrYellow;
input color    InpColorSpikeArrow       = clrMagenta;

//+------------------------------------------------------------------+
//| Supprime tous les objets créés par l'EA                          |
//+------------------------------------------------------------------+
void DeleteAllEAObjects()
{
   if(!InpShowVisuals) return;
   
   string prefix = "FXPRO_" + (string)InpMagicNumber + "_";
   int total = ObjectsTotal(0);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Dessine les blocs d'ordres autour des dernières bougies          |
//+------------------------------------------------------------------+
void DrawOrderBlocksAroundLastBars(int lookbackBars, int widthBars)
{
   if(!InpShowVisuals) return;
   
   MqlRates r[];
   ArraySetAsSeries(r, true);
   
   if(CopyRates(_Symbol, InpSpikeTimeframe, 0, lookbackBars, r) < lookbackBars)
   {
      Print("Erreur dans CopyRates pour DrawOrderBlocks: ", GetLastError());
      return;
   }
   
   string prefix = "FXPRO_" + (string)InpMagicNumber + "_OB_";
   
   for(int i = 0; i < lookbackBars - 1; i++)
   {
      double body = MathAbs(r[i].close - r[i].open);
      double range = r[i].high - r[i].low;
      
      if(range <= 0) continue;
      
      if(body >= 0.6 * range)
      {
         datetime t_high = r[i].time;
         double price_high = r[i].high;
         double price_low = r[i].low;
         string name = prefix + IntegerToString((int)t_high);
         
         if(ObjectFind(0, name) == -1)
         {
            datetime t2 = t_high + (datetime)(widthBars * PeriodSeconds(InpSpikeTimeframe));
            
            if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t_high, price_high, t2, price_low))
            {
               Print("Erreur création OBJ_RECTANGLE: ", GetLastError());
               continue;
            }
            
            color clr = (r[i].close > r[i].open) ? InpColorOB_Bull : InpColorOB_Bear;
            
            ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Dessine une ligne de tendance simple                             |
//+------------------------------------------------------------------+
void DrawSimpleTrendline(int lookback)
{
   if(!InpShowVisuals) return;
   
   MqlRates r[];
   if(CopyRates(_Symbol, InpSpikeTimeframe, 1, lookback, r) <= 0)
   {
      Print("Erreur dans CopyRates pour DrawSimpleTrendline: ", GetLastError());
      return;
   }
   
   double maxv = -1e12; int idxMax = -1;
   double minv = 1e12;  int idxMin = -1;
   
   for(int i = 0; i < lookback; i++)
   {
      if(r[i].high > maxv) { maxv = r[i].high; idxMax = i; }
      if(r[i].low  < minv) { minv = r[i].low;  idxMin = i; }
   }
   
   if(idxMax >= 0 && idxMin >= 0)
   {
      datetime t1 = r[idxMax].time; double p1 = r[idxMax].high;
      datetime t2 = r[idxMin].time; double p2 = r[idxMin].low;
      string name = "FXPRO_" + (string)InpMagicNumber + "_TREND";
      
      if(ObjectFind(0, name) != -1) 
         ObjectDelete(0, name);
         
      if(!ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2))
      {
         Print("Erreur création OBJ_TREND: ", GetLastError());
         return;
      }
      
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorTrend);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Dessine les niveaux de Fibonacci sur le dernier mouvement        |
//+------------------------------------------------------------------+
void DrawFiboOnLastMove(int lookback)
{
   if(!InpShowVisuals) return;
   
   MqlRates r[];
   if(CopyRates(_Symbol, InpSpikeTimeframe, 1, lookback, r) <= 0)
   {
      Print("Erreur dans CopyRates pour DrawFiboOnLastMove: ", GetLastError());
      return;
   }
   
   double maxv = -1e12; int imax = -1;
   double minv = 1e12;  int imin = -1;
   
   for(int i = 0; i < lookback; i++)
   {
      if(r[i].high > maxv) { maxv = r[i].high; imax = i; }
      if(r[i].low  < minv) { minv = r[i].low; imin = i; }
   }
   
   if(imax < 0 || imin < 0) return;
   
   datetime t_high = r[imax].time;
   datetime t_low = r[imin].time;
   double price_high = r[imax].high;
   double price_low = r[imin].low;
   
   // Vérifier si le mouvement est suffisamment important
   double move = MathAbs(price_high - price_low);
   double atr = iATR(_Symbol, InpSpikeTimeframe, 14, 0);
   
   if(move < atr * 0.5) return; // Mouvement trop faible pour dessiner un Fibo
   
   string name = "FXPRO_" + (string)InpMagicNumber + "_FIBO";
   
   if(ObjectFind(0, name) != -1) 
      ObjectDelete(0, name);
      
   if(!ObjectCreate(0, name, OBJ_FIBO, 0, t_low, price_low, t_high, price_high))
   {
      Print("Erreur création OBJ_FIBO: ", GetLastError());
      return;
   }
   
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   
   // Définir les niveaux Fibo personnalisés
   ObjectSetInteger(0, name, OBJPROP_LEVELS, 6);
   
   // Niveaux Fibo standard : 0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0
   ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, 0, clrRed);
   ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, 1, clrYellow);
   ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, 2, clrLime);
   ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, 3, clrDodgerBlue);
   ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, 4, clrMagenta);
   ObjectSetInteger(0, name, OBJPROP_LEVELCOLOR, 5, clrRed);
   
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 0, 0.0);
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 1, 0.236);
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 2, 0.382);
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 3, 0.5);
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 4, 0.618);
   ObjectSetDouble(0, name, OBJPROP_LEVELVALUE, 5, 1.0);
}

//+------------------------------------------------------------------+
//| Dessine les zones de support et résistance                      |
//+------------------------------------------------------------------+
void DrawSRZones(int lookback, int zonePips)
{
   if(!InpShowVisuals) return;
   
   MqlRates r[];
   if(CopyRates(_Symbol, PERIOD_H4, 0, lookback, r) < lookback)
   {
      Print("Erreur dans CopyRates pour DrawSRZones: ", GetLastError());
      return;
   }
   
   int buckets = 40;
   double high = r[0].high, low = r[0].low;
   
   // Trouver le plus haut et le plus bas dans la période
   for(int i = 1; i < lookback; i++)
   {
      if(r[i].high > high) high = r[i].high;
      if(r[i].low < low) low = r[i].low;
   }
   
   double range = high - low;
   if(range <= 0.0) return;
   
   double step = range / buckets;
   double freq[];
   ArrayResize(freq, buckets);
   ArrayInitialize(freq, 0.0);
   
   // Remplir les buckets avec la fréquence des prix
   for(int i = 0; i < lookback; i++)
   {
      int idx = (int)((r[i].close - low) / step);
      if(idx < 0) idx = 0;
      if(idx >= buckets) idx = buckets - 1;
      freq[idx] += 1.0;
   }
   
   // Dessiner les zones de support/résistance
   for(int i = 0; i < buckets; i++)
   {
      if(freq[i] >= 3.0) // Seuil de fréquence pour considérer une zone SR
      {
         double price_center = low + (i + 0.5) * step;
         string name = "FXPRO_" + (string)InpMagicNumber + "_SR_" + IntegerToString(i);
         
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double top = price_center + zonePips * point * 10; // 10 pips en haut
         double bot = price_center - zonePips * point * 10; // 10 pips en bas
         
         if(ObjectFind(0, name) != -1) 
            ObjectDelete(0, name);
            
         datetime t0 = TimeCurrent();
         datetime t1 = t0 + (datetime)(PeriodSeconds(PERIOD_H4) * 10);
         
         if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t0, top, t1, bot))
         {
            Print("Erreur création OBJ_RECTANGLE pour SR: ", GetLastError());
            continue;
         }
         
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorSR);
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, InpColorSR);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
   }
}

//+------------------------------------------------------------------+
//| Dessine une flèche de signal de trading                         |
//+------------------------------------------------------------------+
void DrawSpikeArrow(int direction)
{
   if(!InpShowVisuals) return;
   
   static datetime lastSpikeTime = 0;
   static int lastDirection = 0;
   static bool blinkState = false;
   
   // Réinitialiser si la direction change
   if(direction != 0 && direction != lastDirection)
   {
      lastSpikeTime = TimeCurrent();
      lastDirection = direction;
      blinkState = true;
   }
   
   // Ne rien faire si pas de signal de spike
   if(direction == 0) return;
   
   // Gérer le clignotement (500ms on/off)
   if(TimeCurrent() - lastSpikeTime > 10000) // Arrêter le clignotement après 10 secondes
   {
      ObjectDelete(0, "FXPRO_" + (string)InpMagicNumber + "_SPIKE_ARROW");
      return;
   }
   
   // Basculer l'état du clignotement toutes les 500ms
   if(GetTickCount() % 1000 < 500)
   {
      if(!blinkState) 
      {
         blinkState = true;
         // Créer ou mettre à jour la flèche
         string name = "FXPRO_" + (string)InpMagicNumber + "_SPIKE_ARROW";
         datetime time = iTime(_Symbol, InpSpikeTimeframe, 0);
         double price = iClose(_Symbol, InpSpikeTimeframe, 0);
         
         if(ObjectFind(0, name) < 0) // Si l'objet n'existe pas, le créer
         {
            if(!ObjectCreate(0, name, OBJ_ARROW, 0, time, price))
            {
               Print("Erreur création OBJ_ARROW: ", GetLastError());
               return;
            }
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
         }
         
         // Mettre à jour la position
         ObjectMove(0, name, 0, time, price);
         
         // Définir la couleur et la forme de la flèche
         color arrowColor = (direction > 0) ? clrLimeGreen : clrRed;
         int arrowCode = (direction > 0) ? 233 : 234; // Flèche vers le haut ou vers le bas
         
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
         ObjectSetInteger(0, name, OBJPROP_COLOR, arrowColor);
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
   }
   else
   {
      if(blinkState)
      {
         blinkState = false;
         // Cacher la flèche
         string name = "FXPRO_" + (string)InpMagicNumber + "_SPIKE_ARROW";
         if(ObjectFind(0, name) >= 0)
         {
            ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
         }
      }
   }
}
