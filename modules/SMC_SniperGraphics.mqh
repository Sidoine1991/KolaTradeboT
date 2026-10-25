//+------------------------------------------------------------------+
//| SMC_SniperGraphics.mqh - Visualisations avancées pour entrées sniper |
//| FVG, Order Blocks, Liquidity Pools, ICT 2022 Model                |
//+------------------------------------------------------------------+
#ifndef SMC_SNIPER_GRAPHICS_MQH
#define SMC_SNIPER_GRAPHICS_MQH

#include "SMC_SymbolCategory.mqh"

//+------------------------------------------------------------------+
// Structures pour les zones sniper
//+------------------------------------------------------------------+
struct SMC_FVG
{
   double high;
   double low;
   datetime time;
   int direction;  // +1 bullish, -1 bearish
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
   int direction;  // +1 bullish, -1 bearish
   double range;
   double mitigationPct;
   bool isActive;
   int ageBars;
};

struct SMC_LiquidityPool
{
   double high;
   double low;
   datetime startTime;
   datetime endTime;
   double volume;
   bool isSwept;
   int sweepCount;
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
// Variables globales
//+------------------------------------------------------------------+
SMC_FVG g_fvgs[];
SMC_OrderBlock g_orderBlocks[];
SMC_LiquidityPool g_liquidityPools[];
SMC_SniperEntry g_sniperEntries[];

int g_maxFVGs = 20;
int g_maxOrderBlocks = 15;
int g_maxLiquidityPools = 10;
int g_maxSniperEntries = 5;

//+------------------------------------------------------------------+
// Initialisation du module sniper graphics
//+------------------------------------------------------------------+
void SMC_SG_Init()
{
   ArrayResize(g_fvgs, g_maxFVGs);
   ArrayResize(g_orderBlocks, g_maxOrderBlocks);
   ArrayResize(g_liquidityPools, g_maxLiquidityPools);
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
   
   for(int i = 0; i < g_maxLiquidityPools; i++)
   {
      ZeroMemory(g_liquidityPools[i]);
      g_liquidityPools[i].isSwept = false;
   }
   
   for(int i = 0; i < g_maxSniperEntries; i++)
   {
      ZeroMemory(g_sniperEntries[i]);
      g_sniperEntries[i].isActive = false;
   }
}

//+------------------------------------------------------------------+
// Détecter les FVG (Fair Value Gaps)
//+------------------------------------------------------------------+
void SMC_SG_DetectFVGs(const string symbol, ENUM_TIMEFRAMES tf)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int lookback = 100;
   if(CopyRates(symbol, tf, 1, lookback, rates) < lookback) return;
   
   double atr = iATR(symbol, tf, 14, 0);
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Nettoyer les FVGs expirés (> 50 bougies)
   for(int i = 0; i < g_maxFVGs; i++)
   {
      if(g_fvgs[i].isActive)
      {
         g_fvgs[i].ageBars++;
         if(g_fvgs[i].ageBars > 50)
            g_fvgs[i].isActive = false;
      }
   }
   
   // Détecter nouveaux FVGs
   for(int i = 2; i < lookback - 1; i++)
   {
      // Bullish FVG: gap entre candle i-1 high et candle i+1 low
      if(rates[i-1].high < rates[i+1].low)
      {
         double gapSize = rates[i+1].low - rates[i-1].high;
         double gapPercent = (gapSize / atr) * 100;
         
         if(gapPercent >= 50)  // FVG significatif (> 50% ATR)
         {
            // Trouver slot libre
            int slot = -1;
            for(int j = 0; j < g_maxFVGs; j++)
            {
               if(!g_fvgs[j].isActive) { slot = j; break; }
            }
            
            if(slot >= 0)
            {
               g_fvgs[slot].high = rates[i+1].low;
               g_fvgs[slot].low = rates[i-1].high;
               g_fvgs[slot].time = rates[i].time;
               g_fvgs[slot].direction = 1;
               g_fvgs[slot].atrPercent = gapPercent;
               g_fvgs[slot].isActive = true;
               g_fvgs[slot].ageBars = 0;
               g_fvgs[slot].isNested = SMC_SG_IsNestedFVG(g_fvgs[slot]);
            }
         }
      }
      
      // Bearish FVG: gap entre candle i-1 low et candle i+1 high
      if(rates[i-1].low > rates[i+1].high)
      {
         double gapSize = rates[i-1].low - rates[i+1].high;
         double gapPercent = (gapSize / atr) * 100;
         
         if(gapPercent >= 50)
         {
            int slot = -1;
            for(int j = 0; j < g_maxFVGs; j++)
            {
               if(!g_fvgs[j].isActive) { slot = j; break; }
            }
            
            if(slot >= 0)
            {
               g_fvgs[slot].high = rates[i-1].low;
               g_fvgs[slot].low = rates[i+1].high;
               g_fvgs[slot].time = rates[i].time;
               g_fvgs[slot].direction = -1;
               g_fvgs[slot].atrPercent = gapPercent;
               g_fvgs[slot].isActive = true;
               g_fvgs[slot].ageBars = 0;
               g_fvgs[slot].isNested = SMC_SG_IsNestedFVG(g_fvgs[slot]);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
// Vérifier si un FVG est imbriqué dans un autre
//+------------------------------------------------------------------+
bool SMC_SG_IsNestedFVG(SMC_FVG &fvg)
{
   for(int i = 0; i < g_maxFVGs; i++)
   {
      if(i == ArraySize(g_fvgs)) break;
      if(!g_fvgs[i].isActive || g_fvgs[i].direction != fvg.direction) continue;
      
      // Vérifier si fvg est à l'intérieur de g_fvgs[i]
      if(fvg.high <= g_fvgs[i].high && fvg.low >= g_fvgs[i].low)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
// Détecter les Order Blocks
//+------------------------------------------------------------------+
void SMC_SG_DetectOrderBlocks(const string symbol, ENUM_TIMEFRAMES tf)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int lookback = 80;
   if(CopyRates(symbol, tf, 1, lookback, rates) < lookback) return;
   
   double atr = iATR(symbol, tf, 14, 0);
   
   // Nettoyer les OBs expirés (> 30 bougies)
   for(int i = 0; i < g_maxOrderBlocks; i++)
   {
      if(g_orderBlocks[i].isActive)
      {
         g_orderBlocks[i].ageBars++;
         
         // Calculer mitigation
         double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
         if(g_orderBlocks[i].direction == 1)  // Bullish OB
         {
            if(currentPrice >= g_orderBlocks[i].low && currentPrice <= g_orderBlocks[i].high)
            {
               double consumed = (currentPrice - g_orderBlocks[i].low) / g_orderBlocks[i].range;
               g_orderBlocks[i].mitigationPct = consumed * 100;
            }
         }
         else  // Bearish OB
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
   
   // Détecter nouveaux Order Blocks (candles impulsifs)
   for(int i = 3; i < lookback - 2; i++)
   {
      double body = MathAbs(rates[i].close - rates[i].open);
      double range = rates[i].high - rates[i].low;
      double bodyRatio = body / range;
      
      if(bodyRatio < 0.5) continue;  // Pas assez de corps
      
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
      
      if(movePercent >= 100)  // Mouvement significatif (> 1 ATR)
      {
         int slot = -1;
         for(int j = 0; j < g_maxOrderBlocks; j++)
         {
            if(!g_orderBlocks[j].isActive) { slot = j; break; }
         }
         
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
// Dessiner les FVGs sur le graphique
//+------------------------------------------------------------------+
void SMC_SG_DrawFVGs()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime now = TimeCurrent();
   int tfSec = PeriodSeconds(PERIOD_CURRENT);
   
   for(int i = 0; i < g_maxFVGs; i++)
   {
      if(!g_fvgs[i].isActive) continue;
      
      string name = "SG_FVG_" + IntegerToString(i);
      ObjectDelete(0, name);
      
      datetime endTime = now + (datetime)(tfSec * 10);  // 10 bougies dans le futur
      
      color fvgColor = g_fvgs[i].direction == 1 ? clrLime : clrRed;
      if(g_fvgs[i].isNested) fvgColor = clrGold;  // FVG imbriqué en or
      
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, g_fvgs[i].time, g_fvgs[i].low, endTime, g_fvgs[i].high);
      ObjectSetInteger(0, name, OBJPROP_COLOR, ColorToARGB(fvgColor, 30));
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, fvgColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      // Label avec informations
      string labelName = "SG_FVG_LBL_" + IntegerToString(i);
      ObjectDelete(0, labelName);
      
      string lblText = StringFormat("FVG %d%% %s", (int)g_fvgs[i].atrPercent, 
                                    g_fvgs[i].isNested ? "N" : "");
      
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
// Dessiner les Order Blocks sur le graphique
//+------------------------------------------------------------------+
void SMC_SG_DrawOrderBlocks()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime now = TimeCurrent();
   int tfSec = PeriodSeconds(PERIOD_CURRENT);
   
   for(int i = 0; i < g_maxOrderBlocks; i++)
   {
      if(!g_orderBlocks[i].isActive) continue;
      
      string name = "SG_OB_" + IntegerToString(i);
      ObjectDelete(0, name);
      
      datetime endTime = now + (datetime)(tfSec * 15);
      
      color obColor = g_orderBlocks[i].direction == 1 ? clrDodgerBlue : clrOrangeRed;
      
      // Couleur change selon mitigation
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
      
      // Label avec mitigation
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
// Créer Sniper Entry Zones sur FVG/OB actifs
//+------------------------------------------------------------------+
void SMC_SG_CreateSniperEntries(const string symbol)
{
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   datetime now = TimeCurrent();
   
   // Clear expired entries
   for(int i = 0; i < g_maxSniperEntries; i++)
   {
      if(g_sniperEntries[i].isActive && TimeCurrent() > g_sniperEntries[i].expiry)
         g_sniperEntries[i].isActive = false;
   }
   
   // Check FVG entries
   for(int i = 0; i < g_maxFVGs; i++)
   {
      if(!g_fvgs[i].isActive) continue;
      
      // Check if price is in FVG
      if(currentPrice >= g_fvgs[i].low && currentPrice <= g_fvgs[i].high)
      {
         // Check if entry already exists for this FVG
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
            // Create new sniper entry
            int slot = -1;
            for(int j = 0; j < g_maxSniperEntries; j++)
            {
               if(!g_sniperEntries[j].isActive) { slot = j; break; }
            }
            
            if(slot >= 0)
            {
               g_sniperEntries[slot].strategy = "FVG Entry";
               g_sniperEntries[slot].entryPrice = currentPrice;
               g_sniperEntries[slot].direction = g_fvgs[i].direction;
               g_sniperEntries[slot].confidence = MathMin(90, 60 + g_fvgs[i].atrPercent);
               g_sniperEntries[slot].expiry = now + 300;  // 5 minutes
               g_sniperEntries[slot].isActive = true;
               
               // Calculate SL/TP
               double atr = iATR(symbol, PERIOD_CURRENT, 14, 0);
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
   
   // Check Order Block entries
   for(int i = 0; i < g_maxOrderBlocks; i++)
   {
      if(!g_orderBlocks[i].isActive) continue;
      if(g_orderBlocks[i].mitigationPct < 40 || g_orderBlocks[i].mitigationPct > 80) continue;
      
      // Check if price is in OB
      if(currentPrice >= g_orderBlocks[i].low && currentPrice <= g_orderBlocks[i].high)
      {
         bool exists = false;
         for(int j = 0; j < g_maxSniperEntries; j++)
         {
            if(g_sniperEntries[j].isActive && StringFind(g_sniperEntries[j].strategy, "OB") >= 0)
            {
               exists = true;
               break;
            }
         }
         
         if(!exists)
         {
            int slot = -1;
            for(int j = 0; j < g_maxSniperEntries; j++)
            {
               if(!g_sniperEntries[j].isActive) { slot = j; break; }
            }
            
            if(slot >= 0)
            {
               g_sniperEntries[slot].strategy = "OB Mitigation Entry";
               g_sniperEntries[slot].entryPrice = currentPrice;
               g_sniperEntries[slot].direction = g_orderBlocks[i].direction;
               g_sniperEntries[slot].confidence = MathMin(85, 55 + (100 - g_orderBlocks[i].mitigationPct) * 0.3);
               g_sniperEntries[slot].expiry = now + 300;
               g_sniperEntries[slot].isActive = true;
               
               double atr = iATR(symbol, PERIOD_CURRENT, 14, 0);
               if(g_orderBlocks[i].direction == 1)
               {
                  g_sniperEntries[slot].stopLoss = g_orderBlocks[i].low - atr * 0.3;
                  g_sniperEntries[slot].takeProfit = g_orderBlocks[i].high + atr * 1.2;
               }
               else
               {
                  g_sniperEntries[slot].stopLoss = g_orderBlocks[i].high + atr * 0.3;
                  g_sniperEntries[slot].takeProfit = g_orderBlocks[i].low - atr * 1.2;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
// Dessiner les Sniper Entry Zones
//+------------------------------------------------------------------+
void SMC_SG_DrawSniperEntries()
{
   for(int i = 0; i < g_maxSniperEntries; i++)
   {
      if(!g_sniperEntries[i].isActive) continue;
      
      string name = "SG_ENTRY_" + IntegerToString(i);
      ObjectDelete(0, name);
      
      datetime now = TimeCurrent();
      datetime endTime = g_sniperEntries[i].expiry;
      
      color entryColor = g_sniperEntries[i].direction == 1 ? clrLime : clrRed;
      
      // Cercle autour du prix d'entrée
      ObjectCreate(0, name, OBJ_ELLIPSE, 0, now - 60, g_sniperEntries[i].entryPrice - 0.001, 
                  now + 60, g_sniperEntries[i].entryPrice + 0.001);
      ObjectSetInteger(0, name, OBJPROP_COLOR, entryColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      
      // Label avec informations
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
// Mise à jour principale (à appeler chaque tick/timer)
//+------------------------------------------------------------------+
void SMC_SG_Update(const string symbol)
{
   SMC_SG_DetectFVGs(symbol, PERIOD_M1);
   SMC_SG_DetectFVGs(symbol, PERIOD_M5);
   SMC_SG_DetectOrderBlocks(symbol, PERIOD_M1);
   SMC_SG_CreateSniperEntries(symbol);
   
   SMC_SG_DrawFVGs();
   SMC_SG_DrawOrderBlocks();
   SMC_SG_DrawSniperEntries();
}

//+------------------------------------------------------------------+
// Nettoyer tous les objets graphiques sniper
//+------------------------------------------------------------------+
void SMC_SG_ClearAll()
{
   ObjectsDeleteAll(0, "SG_FVG_");
   ObjectsDeleteAll(0, "SG_OB_");
   ObjectsDeleteAll(0, "SG_ENTRY_");
}

#endif // SMC_SNIPER_GRAPHICS_MQH
