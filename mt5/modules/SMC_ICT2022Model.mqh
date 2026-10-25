//+------------------------------------------------------------------+
//| SMC_ICT2022Model.mqh - ICT 2022 Model pour entrées sniper          |
//| Liquidity Sweep + Inefficiency Entry + Mitigation                  |
//+------------------------------------------------------------------+
#ifndef SMC_ICT2022_MODEL_MQH
#define SMC_ICT2022_MODEL_MQH

#include "SMC_SniperGraphics.mqh"

//+------------------------------------------------------------------+
// Structures ICT 2022
//+------------------------------------------------------------------+
struct SMC_LiquiditySweep
{
   double sweepPrice;
   datetime sweepTime;
   int direction;  // +1 sweep high, -1 sweep low
   double sweepSize;
   bool isValid;
};

struct SMC_Inefficiency
{
   double high;
   double low;
   datetime time;
   string type;  // "FVG", "OB", "CHoCH"
   int direction;
   bool isActive;
};

struct SMC_ICTEntry
{
   string entryType;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   int direction;
   double confidence;
   datetime expiry;
   bool isActive;
   string reason;
};

//+------------------------------------------------------------------+
// Variables globales ICT 2022
//+------------------------------------------------------------------+
SMC_LiquiditySweep g_liquiditySweeps[];
SMC_Inefficiency g_inefficiencies[];
SMC_ICTEntry g_ictEntries[];

int g_maxSweeps = 10;
int g_maxInefficiencies = 15;
int g_maxICTEntries = 5;

//+------------------------------------------------------------------+
// Initialisation ICT 2022
//+------------------------------------------------------------------+
void SMC_ICT_Init()
{
   ArrayResize(g_liquiditySweeps, g_maxSweeps);
   ArrayResize(g_inefficiencies, g_maxInefficiencies);
   ArrayResize(g_ictEntries, g_maxICTEntries);
   
   for(int i = 0; i < g_maxSweeps; i++)
   {
      ZeroMemory(g_liquiditySweeps[i]);
      g_liquiditySweeps[i].isValid = false;
   }
   
   for(int i = 0; i < g_maxInefficiencies; i++)
   {
      ZeroMemory(g_inefficiencies[i]);
      g_inefficiencies[i].isActive = false;
   }
   
   for(int i = 0; i < g_maxICTEntries; i++)
   {
      ZeroMemory(g_ictEntries[i]);
      g_ictEntries[i].isActive = false;
   }
}

//+------------------------------------------------------------------+
// Détecter les Liquidity Sweeps
//+------------------------------------------------------------------+
void SMC_ICT_DetectLiquiditySweeps(const string symbol, ENUM_TIMEFRAMES tf)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int lookback = 50;
   if(CopyRates(symbol, tf, 1, lookback, rates) < lookback) return;
   
   double atr = iATR(symbol, tf, 14, 0);
   
   // Nettoyer les sweeps expirés (> 20 bougies)
   for(int i = 0; i < g_maxSweeps; i++)
   {
      if(g_liquiditySweeps[i].isValid)
      {
         datetime sweepAge = TimeCurrent() - g_liquiditySweeps[i].sweepTime;
         if(sweepAge > PeriodSeconds(tf) * 20)
            g_liquiditySweeps[i].isValid = false;
      }
   }
   
   // Détecter nouveaux sweeps
   for(int i = 2; i < lookback - 1; i++)
   {
      // Sweep high: candle i dépasse le high précédent significatif
      if(rates[i].high > rates[i+1].high && rates[i+1].high > rates[i+2].high)
      {
         double sweepSize = rates[i].high - rates[i+1].high;
         double sweepPercent = (sweepSize / atr) * 100;
         
         if(sweepPercent >= 30)  // Sweep significatif
         {
            int slot = -1;
            for(int j = 0; j < g_maxSweeps; j++)
            {
               if(!g_liquiditySweeps[j].isValid) { slot = j; break; }
            }
            
            if(slot >= 0)
            {
               g_liquiditySweeps[slot].sweepPrice = rates[i].high;
               g_liquiditySweeps[slot].sweepTime = rates[i].time;
               g_liquiditySweeps[slot].direction = 1;
               g_liquiditySweeps[slot].sweepSize = sweepSize;
               g_liquiditySweeps[slot].isValid = true;
            }
         }
      }
      
      // Sweep low: candle i dépasse le low précédent significatif
      if(rates[i].low < rates[i+1].low && rates[i+1].low < rates[i+2].low)
      {
         double sweepSize = rates[i+1].low - rates[i].low;
         double sweepPercent = (sweepSize / atr) * 100;
         
         if(sweepPercent >= 30)
         {
            int slot = -1;
            for(int j = 0; j < g_maxSweeps; j++)
            {
               if(!g_liquiditySweeps[j].isValid) { slot = j; break; }
            }
            
            if(slot >= 0)
            {
               g_liquiditySweeps[slot].sweepPrice = rates[i].low;
               g_liquiditySweeps[slot].sweepTime = rates[i].time;
               g_liquiditySweeps[slot].direction = -1;
               g_liquiditySweeps[slot].sweepSize = sweepSize;
               g_liquiditySweeps[slot].isValid = true;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
// Détecter les Inefficiencies (FVG, OB, CHoCH)
//+------------------------------------------------------------------+
void SMC_ICT_DetectInefficiencies(const string symbol, ENUM_TIMEFRAMES tf)
{
   // Utiliser les FVGs déjà détectés dans SMC_SniperGraphics
   for(int i = 0; i < g_maxFVGs; i++)
   {
      if(!g_fvgs[i].isActive) continue;
      
      int slot = -1;
      for(int j = 0; j < g_maxInefficiencies; j++)
      {
         if(!g_inefficiencies[j].isActive) { slot = j; break; }
      }
      
      if(slot >= 0)
      {
         g_inefficiencies[slot].high = g_fvgs[i].high;
         g_inefficiencies[slot].low = g_fvgs[i].low;
         g_inefficiencies[slot].time = g_fvgs[i].time;
         g_inefficiencies[slot].type = "FVG";
         g_inefficiencies[slot].direction = g_fvgs[i].direction;
         g_inefficiencies[slot].isActive = true;
      }
   }
   
   // Détecter CHoCH (Change of Character)
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int lookback = 30;
   if(CopyRates(symbol, tf, 1, lookback, rates) < lookback) return;
   
   double ema20 = iMA(symbol, tf, 20, 0, MODE_EMA, PRICE_CLOSE);
   double emaValues[];
   ArraySetAsSeries(emaValues, true);
   if(CopyBuffer(ema20, 0, 1, lookback, emaValues) < lookback) return;
   
   for(int i = 3; i < lookback - 2; i++)
   {
      // Bullish CHoCH: cassure de swing low + croissement EMA
      if(rates[i].low < rates[i+1].low && rates[i+1].low < rates[i+2].low)
      {
         if(rates[i].close > emaValues[i] && rates[i-1].close < emaValues[i-1])
         {
            int slot = -1;
            for(int j = 0; j < g_maxInefficiencies; j++)
            {
               if(!g_inefficiencies[j].isActive) { slot = j; break; }
            }
            
            if(slot >= 0)
            {
               g_inefficiencies[slot].high = rates[i].high;
               g_inefficiencies[slot].low = rates[i].low;
               g_inefficiencies[slot].time = rates[i].time;
               g_inefficiencies[slot].type = "CHoCH";
               g_inefficiencies[slot].direction = 1;
               g_inefficiencies[slot].isActive = true;
            }
         }
      }
      
      // Bearish CHoCH: cassure de swing high + croissement EMA
      if(rates[i].high > rates[i+1].high && rates[i+1].high > rates[i+2].high)
      {
         if(rates[i].close < emaValues[i] && rates[i-1].close > emaValues[i-1])
         {
            int slot = -1;
            for(int j = 0; j < g_maxInefficiencies; j++)
            {
               if(!g_inefficiencies[j].isActive) { slot = j; break; }
            }
            
            if(slot >= 0)
            {
               g_inefficiencies[slot].high = rates[i].high;
               g_inefficiencies[slot].low = rates[i].low;
               g_inefficiencies[slot].time = rates[i].time;
               g_inefficiencies[slot].type = "CHoCH";
               g_inefficiencies[slot].direction = -1;
               g_inefficiencies[slot].isActive = true;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
// Générer les entrées ICT 2022
//+------------------------------------------------------------------+
void SMC_ICT_GenerateEntries(const string symbol)
{
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   datetime now = TimeCurrent();
   
   // Clear expired entries
   for(int i = 0; i < g_maxICTEntries; i++)
   {
      if(g_ictEntries[i].isActive && TimeCurrent() > g_ictEntries[i].expiry)
         g_ictEntries[i].isActive = false;
   }
   
   // ICT 2022 Model: Sweep + Inefficiency Entry
   for(int i = 0; i < g_maxSweeps; i++)
   {
      if(!g_liquiditySweeps[i].isValid) continue;
      
      // Chercher inefficiency correspondante après le sweep
      for(int j = 0; j < g_maxInefficiencies; j++)
      {
         if(!g_inefficiencies[j].isActive) continue;
         if(g_inefficiencies[j].direction != g_liquiditySweeps[i].direction) continue;
         
         // Vérifier timing: inefficiency après sweep
         if(g_inefficiencies[j].time > g_liquiditySweeps[i].sweepTime)
         {
            // Vérifier si prix est dans l'inefficiency
            if(currentPrice >= g_inefficiencies[j].low && currentPrice <= g_inefficiencies[j].high)
            {
               // Vérifier si entry existe déjà
               bool exists = false;
               for(int k = 0; k < g_maxICTEntries; k++)
               {
                  if(g_ictEntries[k].isActive && 
                     StringFind(g_ictEntries[k].reason, "ICT") >= 0 &&
                     g_ictEntries[k].direction == g_liquiditySweeps[i].direction)
                  {
                     exists = true;
                     break;
                  }
               }
               
               if(!exists)
               {
                  int slot = -1;
                  for(int k = 0; k < g_maxICTEntries; k++)
                  {
                     if(!g_ictEntries[k].isActive) { slot = k; break; }
                  }
                  
                  if(slot >= 0)
                  {
                     g_ictEntries[slot].entryType = "ICT 2022";
                     g_ictEntries[slot].entryPrice = currentPrice;
                     g_ictEntries[slot].direction = g_liquiditySweeps[i].direction;
                     g_ictEntries[slot].confidence = 85;
                     g_ictEntries[slot].expiry = now + 300;
                     g_ictEntries[slot].isActive = true;
                     g_ictEntries[slot].reason = "Sweep + " + g_inefficiencies[j].type;
                     
                     double atr = iATR(symbol, PERIOD_CURRENT, 14, 0);
                     if(g_liquiditySweeps[i].direction == 1)
                     {
                        g_ictEntries[slot].stopLoss = g_inefficiencies[j].low - atr * 0.5;
                        g_ictEntries[slot].takeProfit = g_inefficiencies[j].high + atr * 2.0;
                     }
                     else
                     {
                        g_ictEntries[slot].stopLoss = g_inefficiencies[j].high + atr * 0.5;
                        g_ictEntries[slot].takeProfit = g_inefficiencies[j].low - atr * 2.0;
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
// Dessiner les Liquidity Sweeps
//+------------------------------------------------------------------+
void SMC_ICT_DrawLiquiditySweeps()
{
   for(int i = 0; i < g_maxSweeps; i++)
   {
      if(!g_liquiditySweeps[i].isValid) continue;
      
      string name = "ICT_SWEEP_" + IntegerToString(i);
      ObjectDelete(0, name);
      
      color sweepColor = g_liquiditySweeps[i].direction == 1 ? clrRed : clrLime;
      
      // Marquer le sweep avec un X
      ObjectCreate(0, name, OBJ_TEXT, 0, g_liquiditySweeps[i].sweepTime, g_liquiditySweeps[i].sweepPrice);
      ObjectSetString(0, name, OBJPROP_TEXT, "✗");
      ObjectSetInteger(0, name, OBJPROP_COLOR, sweepColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 16);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      // Label "Liquidity Sweep"
      string labelName = "ICT_SWEEP_LBL_" + IntegerToString(i);
      ObjectDelete(0, labelName);
      
      string lblText = "Liquidity Sweep";
      
      ObjectCreate(0, labelName, OBJ_TEXT, 0, g_liquiditySweeps[i].sweepTime, g_liquiditySweeps[i].sweepPrice);
      ObjectSetString(0, labelName, OBJPROP_TEXT, lblText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, sweepColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LOWER);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
// Dessiner les entrées ICT
//+------------------------------------------------------------------+
void SMC_ICT_DrawICTEntries()
{
   for(int i = 0; i < g_maxICTEntries; i++)
   {
      if(!g_ictEntries[i].isActive) continue;
      
      string name = "ICT_ENTRY_" + IntegerToString(i);
      ObjectDelete(0, name);
      
      color entryColor = g_ictEntries[i].direction == 1 ? clrLime : clrRed;
      
      // Flèche directionnelle
      int arrowCode = g_ictEntries[i].direction == 1 ? 233 : 234;
      
      ObjectCreate(0, name, OBJ_ARROW, 0, TimeCurrent(), g_ictEntries[i].entryPrice);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, name, OBJPROP_COLOR, entryColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 4);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      // Label avec informations
      string labelName = "ICT_ENTRY_LBL_" + IntegerToString(i);
      ObjectDelete(0, labelName);
      
      string lblText = StringFormat("ICT %s\n%s\nConf: %.0f%%\nSL: %.5f\nTP: %.5f", 
                                    g_ictEntries[i].entryType,
                                    g_ictEntries[i].reason,
                                    g_ictEntries[i].confidence,
                                    g_ictEntries[i].stopLoss,
                                    g_ictEntries[i].takeProfit);
      
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 320);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 100 + i * 80);
      ObjectSetString(0, labelName, OBJPROP_TEXT, lblText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, entryColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
// Mise à jour principale ICT 2022
//+------------------------------------------------------------------+
void SMC_ICT_Update(const string symbol)
{
   SMC_ICT_DetectLiquiditySweeps(symbol, PERIOD_M1);
   SMC_ICT_DetectLiquiditySweeps(symbol, PERIOD_M5);
   SMC_ICT_DetectInefficiencies(symbol, PERIOD_M1);
   SMC_ICT_GenerateEntries(symbol);
   
   SMC_ICT_DrawLiquiditySweeps();
   SMC_ICT_DrawICTEntries();
}

//+------------------------------------------------------------------+
// Nettoyer tous les objets ICT
//+------------------------------------------------------------------+
void SMC_ICT_ClearAll()
{
   ObjectsDeleteAll(0, "ICT_SWEEP_");
   ObjectsDeleteAll(0, "ICT_ENTRY_");
}

#endif // SMC_ICT2022_MODEL_MQH
