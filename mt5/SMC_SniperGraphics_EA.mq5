//+------------------------------------------------------------------+
//| SMC_SniperGraphics_EA.mq5 - EA standalone pour visualisations sniper |
//| FVG, Order Blocks, ICT 2022 Model - Fonctionne indépendamment     |
//+------------------------------------------------------------------+
#property copyright "TradBOT SMC"
#property version   "1.0"
#property strict

#include <Trade/Trade.mqh>
#include "modules/SMC_SymbolCategory.mqh"

//+------------------------------------------------------------------+
//| Structures pour les zones sniper                                   |
//+------------------------------------------------------------------+
struct SMC_FVG
{
   double high;
   double low;
   datetime time;
   int direction;
   double atrPercent;
   bool isActive;
   bool isNested;
   int ageBars;
};

struct SMC_OrderBlock
{
   double high;
   double low;
   datetime time;
   int direction;
   double range;
   double mitigationPct;
   bool isActive;
   int ageBars;
};

struct SMC_LiquiditySweep
{
   double sweepPrice;
   datetime sweepTime;
   int direction;
   double sweepSize;
   bool isValid;
};

struct SMC_SniperEntry
{
   string strategy;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   int direction;
   double confidence;
   datetime expiry;
   bool isActive;
};

//+------------------------------------------------------------------+
//| Variables globales                                                |
//+------------------------------------------------------------------+
SMC_FVG g_fvgs[];
SMC_OrderBlock g_orderBlocks[];
SMC_LiquiditySweep g_liquiditySweeps[];
SMC_SniperEntry g_sniperEntries[];

int g_maxFVGs = 20;
int g_maxOrderBlocks = 15;
int g_maxSweeps = 10;
int g_maxSniperEntries = 5;

// Paramètres d'entrée
input int    FVG_Lookback = 100;
input int    FVG_MinATRPct = 50;
input int    OB_Lookback = 80;
input int    OB_MinATRPct = 100;
input int    Sweep_Lookback = 50;
input int    Sweep_MinATRPct = 30;
input bool   ShowFVGs = true;
input bool   ShowOrderBlocks = true;
input bool   ShowSweeps = true;
input bool   ShowSniperEntries = true;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== SMC Sniper Graphics EA Initialisé ===");
   Print("Symbole: ", _Symbol);
   
   ArrayResize(g_fvgs, g_maxFVGs);
   ArrayResize(g_orderBlocks, g_maxOrderBlocks);
   ArrayResize(g_liquiditySweeps, g_maxSweeps);
   ArrayResize(g_sniperEntries, g_maxSniperEntries);
   
   for(int i = 0; i < g_maxFVGs; i++)
   {
      ZeroMemory(g_fvgs[i]);
      g_fvgs[i].isActive = false;
   }
   
   for(int i = 0; i < g_maxOrderBlocks; i++)
   {
      ZeroMemory(g_orderBlocks[i]);
      g_orderBlocks[i].isActive = false;
   }
   
   for(int i = 0; i < g_maxSweeps; i++)
   {
      ZeroMemory(g_liquiditySweeps[i]);
      g_liquiditySweeps[i].isValid = false;
   }
   
   for(int i = 0; i < g_maxSniperEntries; i++)
   {
      ZeroMemory(g_sniperEntries[i]);
      g_sniperEntries[i].isActive = false;
   }
   
   EventSetTimer(1);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ClearAllGraphics();
   Print("=== SMC Sniper Graphics EA Désactivé ===");
}

//+------------------------------------------------------------------+
//| Expert timer function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   DetectFVGs();
   DetectOrderBlocks();
   DetectLiquiditySweeps();
   CreateSniperEntries();
   
   if(ShowFVGs) DrawFVGs();
   if(ShowOrderBlocks) DrawOrderBlocks();
   if(ShowSweeps) DrawLiquiditySweeps();
   if(ShowSniperEntries) DrawSniperEntries();
}

//+------------------------------------------------------------------+
//| Détecter les FVGs                                                 |
//+------------------------------------------------------------------+
void DetectFVGs()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, FVG_Lookback, rates) < FVG_Lookback) return;
   
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14, 0);
   
   for(int i = 0; i < g_maxFVGs; i++)
   {
      if(g_fvgs[i].isActive)
      {
         g_fvgs[i].ageBars++;
         if(g_fvgs[i].ageBars > 50)
            g_fvgs[i].isActive = false;
      }
   }
   
   for(int i = 2; i < FVG_Lookback - 1; i++)
   {
      if(rates[i-1].high < rates[i+1].low)
      {
         double gapSize = rates[i+1].low - rates[i-1].high;
         double gapPercent = (gapSize / atr) * 100;
         
         if(gapPercent >= FVG_MinATRPct)
         {
            int slot = FindFreeSlotFVG();
            if(slot >= 0)
            {
               g_fvgs[slot].high = rates[i+1].low;
               g_fvgs[slot].low = rates[i-1].high;
               g_fvgs[slot].time = rates[i].time;
               g_fvgs[slot].direction = 1;
               g_fvgs[slot].atrPercent = gapPercent;
               g_fvgs[slot].isActive = true;
               g_fvgs[slot].ageBars = 0;
               g_fvgs[slot].isNested = IsNestedFVG(g_fvgs[slot]);
            }
         }
      }
      
      if(rates[i-1].low > rates[i+1].high)
      {
         double gapSize = rates[i-1].low - rates[i+1].high;
         double gapPercent = (gapSize / atr) * 100;
         
         if(gapPercent >= FVG_MinATRPct)
         {
            int slot = FindFreeSlotFVG();
            if(slot >= 0)
            {
               g_fvgs[slot].high = rates[i-1].low;
               g_fvgs[slot].low = rates[i+1].high;
               g_fvgs[slot].time = rates[i].time;
               g_fvgs[slot].direction = -1;
               g_fvgs[slot].atrPercent = gapPercent;
               g_fvgs[slot].isActive = true;
               g_fvgs[slot].ageBars = 0;
               g_fvgs[slot].isNested = IsNestedFVG(g_fvgs[slot]);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Détecter les Order Blocks                                          |
//+------------------------------------------------------------------+
void DetectOrderBlocks()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, OB_Lookback, rates) < OB_Lookback) return;
   
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   for(int i = 0; i < g_maxOrderBlocks; i++)
   {
      if(g_orderBlocks[i].isActive)
      {
         g_orderBlocks[i].ageBars++;
         
         if(g_orderBlocks[i].direction == 1)
         {
            if(currentPrice >= g_orderBlocks[i].low && currentPrice <= g_orderBlocks[i].high)
            {
               double consumed = (currentPrice - g_orderBlocks[i].low) / g_orderBlocks[i].range;
               g_orderBlocks[i].mitigationPct = consumed * 100;
            }
         }
         else
         {
            if(currentPrice >= g_orderBlocks[i].low && currentPrice <= g_orderBlocks[i].high)
            {
               double consumed = (g_orderBlocks[i].high - currentPrice) / g_orderBlocks[i].range;
               g_orderBlocks[i].mitigationPct = consumed * 100;
            }
         }
         
         if(g_orderBlocks[i].ageBars > 30 || g_orderBlocks[i].mitigationPct >= 90)
            g_orderBlocks[i].isActive = false;
      }
   }
   
   for(int i = 3; i < OB_Lookback - 2; i++)
   {
      double body = MathAbs(rates[i].close - rates[i].open);
      double range = rates[i].high - rates[i].low;
      double bodyRatio = body / range;
      
      if(bodyRatio < 0.5) continue;
      
      double moveSize = 0;
      int direction = 0;
      
      if(rates[i].close > rates[i].open)
      {
         moveSize = rates[i].high - rates[i-1].low;
         direction = 1;
      }
      else
      {
         moveSize = rates[i-1].high - rates[i].low;
         direction = -1;
      }
      
      double movePercent = (moveSize / atr) * 100;
      
      if(movePercent >= OB_MinATRPct)
      {
         int slot = FindFreeSlotOB();
         if(slot >= 0)
         {
            g_orderBlocks[slot].high = rates[i].high;
            g_orderBlocks[slot].low = rates[i].low;
            g_orderBlocks[slot].time = rates[i].time;
            g_orderBlocks[slot].direction = direction;
            g_orderBlocks[slot].range = range;
            g_orderBlocks[slot].mitigationPct = 0;
            g_orderBlocks[slot].isActive = true;
            g_orderBlocks[slot].ageBars = 0;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Détecter les Liquidity Sweeps                                     |
//+------------------------------------------------------------------+
void DetectLiquiditySweeps()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 1, Sweep_Lookback, rates) < Sweep_Lookback) return;
   
   double atr = iATR(_Symbol, PERIOD_CURRENT, 14, 0);
   
   for(int i = 0; i < g_maxSweeps; i++)
   {
      if(g_liquiditySweeps[i].isValid)
      {
         datetime sweepAge = TimeCurrent() - g_liquiditySweeps[i].sweepTime;
         if(sweepAge > PeriodSeconds(PERIOD_CURRENT) * 20)
            g_liquiditySweeps[i].isValid = false;
      }
   }
   
   for(int i = 2; i < Sweep_Lookback - 1; i++)
   {
      if(rates[i].high > rates[i+1].high && rates[i+1].high > rates[i+2].high)
      {
         double sweepSize = rates[i].high - rates[i+1].high;
         double sweepPercent = (sweepSize / atr) * 100;
         
         if(sweepPercent >= Sweep_MinATRPct)
         {
            int slot = FindFreeSlotSweep();
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
      
      if(rates[i].low < rates[i+1].low && rates[i+1].low < rates[i+2].low)
      {
         double sweepSize = rates[i+1].low - rates[i].low;
         double sweepPercent = (sweepSize / atr) * 100;
         
         if(sweepPercent >= Sweep_MinATRPct)
         {
            int slot = FindFreeSlotSweep();
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
//| Créer les Sniper Entries                                          |
//+------------------------------------------------------------------+
void CreateSniperEntries()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime now = TimeCurrent();
   
   for(int i = 0; i < g_maxSniperEntries; i++)
   {
      if(g_sniperEntries[i].isActive && TimeCurrent() > g_sniperEntries[i].expiry)
         g_sniperEntries[i].isActive = false;
   }
   
   for(int i = 0; i < g_maxFVGs; i++)
   {
      if(!g_fvgs[i].isActive) continue;
      
      if(currentPrice >= g_fvgs[i].low && currentPrice <= g_fvgs[i].high)
      {
         bool exists = false;
         for(int j = 0; j < g_maxSniperEntries; j++)
         {
            if(g_sniperEntries[j].isActive && StringFind(g_sniperEntries[j].strategy, "FVG") >= 0)
            {
               exists = true;
               break;
            }
         }
         
         if(!exists)
         {
            int slot = FindFreeSlotEntry();
            if(slot >= 0)
            {
               g_sniperEntries[slot].strategy = "FVG Entry";
               g_sniperEntries[slot].entryPrice = currentPrice;
               g_sniperEntries[slot].direction = g_fvgs[i].direction;
               g_sniperEntries[slot].confidence = MathMin(90, 60 + g_fvgs[i].atrPercent);
               g_sniperEntries[slot].expiry = now + 300;
               g_sniperEntries[slot].isActive = true;
               
               double atr = iATR(_Symbol, PERIOD_CURRENT, 14, 0);
               if(g_fvgs[i].direction == 1)
               {
                  g_sniperEntries[slot].stopLoss = g_fvgs[i].low - atr * 0.5;
                  g_sniperEntries[slot].takeProfit = g_fvgs[i].high + atr * 1.5;
               }
               else
               {
                  g_sniperEntries[slot].stopLoss = g_fvgs[i].high + atr * 0.5;
                  g_sniperEntries[slot].takeProfit = g_fvgs[i].low - atr * 1.5;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Dessiner les FVGs                                                 |
//+------------------------------------------------------------------+
void DrawFVGs()
{
   datetime now = TimeCurrent();
   int tfSec = PeriodSeconds(PERIOD_CURRENT);
   
   for(int i = 0; i < g_maxFVGs; i++)
   {
      if(!g_fvgs[i].isActive) continue;
      
      string name = "SG_FVG_" + IntegerToString(i);
      ObjectDelete(0, name);
      
      datetime endTime = now + (datetime)(tfSec * 10);
      
      color fvgColor = g_fvgs[i].direction == 1 ? clrLime : clrRed;
      if(g_fvgs[i].isNested) fvgColor = clrGold;
      
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, g_fvgs[i].time, g_fvgs[i].low, endTime, g_fvgs[i].high);
      ObjectSetInteger(0, name, OBJPROP_COLOR, ColorToARGB(fvgColor, 30));
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, fvgColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      string labelName = "SG_FVG_LBL_" + IntegerToString(i);
      ObjectDelete(0, labelName);
      
      string lblText = StringFormat("FVG %d%% %s", (int)g_fvgs[i].atrPercent, g_fvgs[i].isNested ? "N" : "");
      
      ObjectCreate(0, labelName, OBJ_TEXT, 0, g_fvgs[i].time, g_fvgs[i].high);
      ObjectSetString(0, labelName, OBJPROP_TEXT, lblText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, fvgColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Dessiner les Order Blocks                                          |
//+------------------------------------------------------------------+
void DrawOrderBlocks()
{
   datetime now = TimeCurrent();
   int tfSec = PeriodSeconds(PERIOD_CURRENT);
   
   for(int i = 0; i < g_maxOrderBlocks; i++)
   {
      if(!g_orderBlocks[i].isActive) continue;
      
      string name = "SG_OB_" + IntegerToString(i);
      ObjectDelete(0, name);
      
      datetime endTime = now + (datetime)(tfSec * 15);
      
      color obColor = g_orderBlocks[i].direction == 1 ? clrDodgerBlue : clrOrangeRed;
      
      if(g_orderBlocks[i].mitigationPct > 50)
         obColor = clrYellow;
      if(g_orderBlocks[i].mitigationPct > 75)
         obColor = clrGray;
      
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, g_orderBlocks[i].time, g_orderBlocks[i].low, endTime, g_orderBlocks[i].high);
      ObjectSetInteger(0, name, OBJPROP_COLOR, ColorToARGB(obColor, 20));
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, obColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      string labelName = "SG_OB_LBL_" + IntegerToString(i);
      ObjectDelete(0, labelName);
      
      string lblText = StringFormat("OB %d%%", (int)g_orderBlocks[i].mitigationPct);
      
      ObjectCreate(0, labelName, OBJ_TEXT, 0, g_orderBlocks[i].time, g_orderBlocks[i].high);
      ObjectSetString(0, labelName, OBJPROP_TEXT, lblText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, obColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Dessiner les Liquidity Sweeps                                     |
//+------------------------------------------------------------------+
void DrawLiquiditySweeps()
{
   for(int i = 0; i < g_maxSweeps; i++)
   {
      if(!g_liquiditySweeps[i].isValid) continue;
      
      string name = "ICT_SWEEP_" + IntegerToString(i);
      ObjectDelete(0, name);
      
      color sweepColor = g_liquiditySweeps[i].direction == 1 ? clrRed : clrLime;
      
      ObjectCreate(0, name, OBJ_TEXT, 0, g_liquiditySweeps[i].sweepTime, g_liquiditySweeps[i].sweepPrice);
      ObjectSetString(0, name, OBJPROP_TEXT, "✗");
      ObjectSetInteger(0, name, OBJPROP_COLOR, sweepColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 16);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      string labelName = "ICT_SWEEP_LBL_" + IntegerToString(i);
      ObjectDelete(0, labelName);
      
      ObjectCreate(0, labelName, OBJ_TEXT, 0, g_liquiditySweeps[i].sweepTime, g_liquiditySweeps[i].sweepPrice);
      ObjectSetString(0, labelName, OBJPROP_TEXT, "Liquidity Sweep");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, sweepColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LOWER);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Dessiner les Sniper Entries                                        |
//+------------------------------------------------------------------+
void DrawSniperEntries()
{
   for(int i = 0; i < g_maxSniperEntries; i++)
   {
      if(!g_sniperEntries[i].isActive) continue;
      
      string name = "SG_ENTRY_" + IntegerToString(i);
      ObjectDelete(0, name);
      
      color entryColor = g_sniperEntries[i].direction == 1 ? clrLime : clrRed;
      
      ObjectCreate(0, name, OBJ_ELLIPSE, 0, TimeCurrent() - 60, g_sniperEntries[i].entryPrice - 0.001, 
                  TimeCurrent() + 60, g_sniperEntries[i].entryPrice + 0.001);
      ObjectSetInteger(0, name, OBJPROP_COLOR, entryColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      string labelName = "SG_ENTRY_LBL_" + IntegerToString(i);
      ObjectDelete(0, labelName);
      
      string lblText = StringFormat("%s\nConf: %.0f%%\nSL: %.5f\nTP: %.5f", 
                                    g_sniperEntries[i].strategy,
                                    g_sniperEntries[i].confidence,
                                    g_sniperEntries[i].stopLoss,
                                    g_sniperEntries[i].takeProfit);
      
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 320);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 100 + i * 60);
      ObjectSetString(0, labelName, OBJPROP_TEXT, lblText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, entryColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Fonctions auxiliaires                                             |
//+------------------------------------------------------------------+
int FindFreeSlotFVG()
{
   for(int i = 0; i < g_maxFVGs; i++)
   {
      if(!g_fvgs[i].isActive) return i;
   }
   return -1;
}

int FindFreeSlotOB()
{
   for(int i = 0; i < g_maxOrderBlocks; i++)
   {
      if(!g_orderBlocks[i].isActive) return i;
   }
   return -1;
}

int FindFreeSlotSweep()
{
   for(int i = 0; i < g_maxSweeps; i++)
   {
      if(!g_liquiditySweeps[i].isValid) return i;
   }
   return -1;
}

int FindFreeSlotEntry()
{
   for(int i = 0; i < g_maxSniperEntries; i++)
   {
      if(!g_sniperEntries[i].isActive) return i;
   }
   return -1;
}

bool IsNestedFVG(SMC_FVG &fvg)
{
   for(int i = 0; i < g_maxFVGs; i++)
   {
      if(!g_fvgs[i].isActive || g_fvgs[i].direction != fvg.direction) continue;
      if(fvg.high <= g_fvgs[i].high && fvg.low >= g_fvgs[i].low)
         return true;
   }
   return false;
}

void ClearAllGraphics()
{
   ObjectsDeleteAll(0, "SG_FVG_");
   ObjectsDeleteAll(0, "SG_OB_");
   ObjectsDeleteAll(0, "SG_ENTRY_");
   ObjectsDeleteAll(0, "ICT_SWEEP_");
}
