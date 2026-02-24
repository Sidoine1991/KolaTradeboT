//+------------------------------------------------------------------+
//| SMC_Concepts.mqh - Smart Money Concepts (ICT)                    |
//| Concepts: FVG, IFVG, IMB, MSS, BOS, OTE, POI, OB, BB, MB,       |
//|           EQH, EQL, CE, P/D, LS, SSL, BSL, IRL, ERL             |
//+------------------------------------------------------------------+
#property strict

#ifndef SMC_CONCEPTS_MQH
#define SMC_CONCEPTS_MQH

//+------------------------------------------------------------------+
//| Structures SMC                                                    |
//+------------------------------------------------------------------+
struct FVGData {
   double top;
   double bottom;
   int direction;      // 1=Bullish, -1=Bearish
   datetime time;
   bool isInversion;   // IFVG
   int barIndex;
};

struct OrderBlockData {
   double high;
   double low;
   int direction;      // 1=Bullish, -1=Bearish
   datetime time;
   int barIndex;
   string type;        // "OB", "BB", "MB"
};

struct LiquidityData {
   double price;
   string type;        // "SSL", "BSL", "IRL", "ERL"
   int equalCount;     // EQH/EQL count
   datetime time;
};

struct SMC_Signal {
   string action;      // "BUY", "SELL", "HOLD"
   double confidence;
   string concept;     // "FVG", "OB", "BOS", "LS", etc.
   string reasoning;
   double entryPrice;
   double stopLoss;
   double takeProfit;
};

//+------------------------------------------------------------------+
//| Catégorie d'instrument (Boom, Volatility, Forex, Commodity)      |
//+------------------------------------------------------------------+
enum ENUM_SYMBOL_CATEGORY {
   SYM_BOOM_CRASH,
   SYM_VOLATILITY,
   SYM_FOREX,
   SYM_COMMODITY,
   SYM_METAL,
   SYM_UNKNOWN
};

//+------------------------------------------------------------------+
//| Détecter la catégorie du symbole                                 |
//+------------------------------------------------------------------+
ENUM_SYMBOL_CATEGORY SMC_GetSymbolCategory(string symbol)
{
   string s = symbol;
   StringToUpper(s);
   
   if(StringFind(s, "BOOM") >= 0 || StringFind(s, "CRASH") >= 0)
      return SYM_BOOM_CRASH;
   if(StringFind(s, "VOLATILITY") >= 0 || StringFind(s, "RANGE BREAK") >= 0)
      return SYM_VOLATILITY;
   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0)
      return SYM_METAL;
   if(StringFind(s, "XAG") >= 0 || StringFind(s, "SILVER") >= 0)
      return SYM_METAL;
   if(StringFind(s, "OIL") >= 0 || StringFind(s, "COPPER") >= 0)
      return SYM_COMMODITY;
   if(StringFind(s, "USD") >= 0 || StringFind(s, "EUR") >= 0 || 
      StringFind(s, "GBP") >= 0 || StringFind(s, "JPY") >= 0)
      return SYM_FOREX;
      
   return SYM_UNKNOWN;
}

//+------------------------------------------------------------------+
//| FVG - Fair Value Gap (IMB Imbalance)                             |
//+------------------------------------------------------------------+
bool SMC_DetectFVG(string symbol, ENUM_TIMEFRAMES tf, int lookback, FVGData &fvgOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, lookback, rates) < lookback) return false;
   
   for(int i = 2; i < lookback - 1; i++)
   {
      // FVG Bullish: low[i-1] > high[i+1]
      if(rates[i-1].low > rates[i+1].high)
      {
         double gap = rates[i-1].low - rates[i+1].high;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(gap > point * 3)
         {
            fvgOut.top = rates[i-1].low;
            fvgOut.bottom = rates[i+1].high;
            fvgOut.direction = 1;
            fvgOut.time = rates[i].time;
            fvgOut.isInversion = false;
            fvgOut.barIndex = i;
            return true;
         }
      }
      // FVG Bearish: high[i-1] < low[i+1]
      if(rates[i-1].high < rates[i+1].low)
      {
         double gap = rates[i+1].low - rates[i-1].high;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(gap > point * 3)
         {
            fvgOut.top = rates[i+1].low;
            fvgOut.bottom = rates[i-1].high;
            fvgOut.direction = -1;
            fvgOut.time = rates[i].time;
            fvgOut.isInversion = false;
            fvgOut.barIndex = i;
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| BOS - Break Of Structure (changement de structure)               |
//+------------------------------------------------------------------+
bool SMC_DetectBOS(string symbol, ENUM_TIMEFRAMES tf, int &directionOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 20, rates) < 20) return false;
   
   double prevSwingHigh = MathMax(rates[3].high, MathMax(rates[4].high, rates[5].high));
   double prevSwingLow = MathMin(rates[3].low, MathMin(rates[4].low, rates[5].low));
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minBreak = point * 5;
   
   if(rates[1].close > prevSwingHigh + minBreak)
   {
      directionOut = 1;
      return true;
   }
   if(rates[1].close < prevSwingLow - minBreak)
   {
      directionOut = -1;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| EQH/EQL - Equal Highs / Equal Lows (liquidité)                   |
//+------------------------------------------------------------------+
bool SMC_DetectEqualHighs(string symbol, ENUM_TIMEFRAMES tf, double &priceOut, int tolerancePips = 5)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 30, rates) < 30) return false;
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tolerance = tolerancePips * point * 10;
   
   int eqCount = 0;
   double refPrice = rates[1].high;
   
   for(int i = 1; i < 20; i++)
   {
      if(MathAbs(rates[i].high - refPrice) <= tolerance)
         eqCount++;
   }
   if(eqCount >= 2)
   {
      priceOut = refPrice;
      return true;
   }
   return false;
}

bool SMC_DetectEqualLows(string symbol, ENUM_TIMEFRAMES tf, double &priceOut, int tolerancePips = 5)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 30, rates) < 30) return false;
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tolerance = tolerancePips * point * 10;
   
   int eqCount = 0;
   double refPrice = rates[1].low;
   
   for(int i = 1; i < 20; i++)
   {
      if(MathAbs(rates[i].low - refPrice) <= tolerance)
         eqCount++;
   }
   if(eqCount >= 2)
   {
      priceOut = refPrice;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| LS - Liquidity Sweep (SSL/BSL sweep)                             |
//+------------------------------------------------------------------+
bool SMC_DetectLiquiditySweep(string symbol, ENUM_TIMEFRAMES tf, string &typeOut)
{
   int barsAgo;
   return SMC_DetectLiquiditySweepEx(symbol, tf, typeOut, barsAgo);
}

//+------------------------------------------------------------------+
//| LS Ex - avec barsAgo (0 = bar 1, 1 = bar 2, etc.)                |
//+------------------------------------------------------------------+
bool SMC_DetectLiquiditySweepEx(string symbol, ENUM_TIMEFRAMES tf, string &typeOut, int &barsAgoOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 15, rates) < 15) return false;
   barsAgoOut = 99;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minSweep = point * 5;
   for(int b = 1; b <= 5; b++)
   {
      if(b + 2 >= ArraySize(rates)) break;
      double prevHigh = rates[b+1].high;
      double prevLow = rates[b+1].low;
      double currHigh = rates[b].high;
      double currLow = rates[b].low;
      if(currHigh > prevHigh && (currHigh - prevHigh) > minSweep)
      {
         typeOut = "BSL";
         barsAgoOut = b;
         return true;
      }
      if(currLow < prevLow && (prevLow - currLow) > minSweep)
      {
         typeOut = "SSL";
         barsAgoOut = b;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| OB - Order Block (dernière bougie opposée avant rupture)         |
//+------------------------------------------------------------------+
bool SMC_DetectOrderBlock(string symbol, ENUM_TIMEFRAMES tf, OrderBlockData &obOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 50, rates) < 50) return false;
   
   for(int i = 3; i < 45; i++)
   {
      // OB Bullish: bearish candle before strong bullish move
      if(rates[i].close < rates[i].open && rates[i+1].close > rates[i+1].open)
      {
         double moveUp = rates[i+2].high - rates[i].low;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(moveUp > point * 20)
         {
            obOut.high = rates[i].high;
            obOut.low = rates[i].low;
            obOut.direction = 1;
            obOut.time = rates[i].time;
            obOut.barIndex = i;
            obOut.type = "OB";
            return true;
         }
      }
      // OB Bearish
      if(rates[i].close > rates[i].open && rates[i+1].close < rates[i+1].open)
      {
         double moveDown = rates[i].high - rates[i+2].low;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(moveDown > point * 20)
         {
            obOut.high = rates[i].high;
            obOut.low = rates[i].low;
            obOut.direction = -1;
            obOut.time = rates[i].time;
            obOut.barIndex = i;
            obOut.type = "OB";
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| OTE - Optimal Trade Entry (zone Fibonacci 0.62-0.79)             |
//+------------------------------------------------------------------+
bool SMC_IsInOTEZone(string symbol, double price, double swingHigh, double swingLow, bool isBullish)
{
   double range = swingHigh - swingLow;
   if(range <= 0) return false;
   
   double oteLow = swingLow + range * 0.62;
   double oteHigh = swingLow + range * 0.79;
   
   if(isBullish)
      return (price >= oteLow && price <= oteHigh);
   else
   {
      oteLow = swingHigh - range * 0.79;
      oteHigh = swingHigh - range * 0.62;
      return (price >= oteLow && price <= oteHigh);
   }
}

//+------------------------------------------------------------------+
//| P/D - Premium/Discount (50% niveau)                              |
//+------------------------------------------------------------------+
double SMC_GetEquilibrium(string symbol, ENUM_TIMEFRAMES tf, int lookback = 50)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, lookback, rates) < lookback) return 0;
   
   double high = rates[1].high;
   double low = rates[1].low;
   for(int i = 1; i < lookback; i++)
   {
      if(rates[i].high > high) high = rates[i].high;
      if(rates[i].low < low) low = rates[i].low;
   }
   return (high + low) / 2.0;
}

//+------------------------------------------------------------------+
//| Vérifier sessions LO (London Open) / NYO (New York Open)         |
//+------------------------------------------------------------------+
bool SMC_IsLondonOpen(int hourStart = 8, int hourEnd = 11)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= hourStart && dt.hour <= hourEnd);
}

bool SMC_IsNewYorkOpen(int hourStart = 13, int hourEnd = 16)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= hourStart && dt.hour <= hourEnd);
}

bool SMC_IsKillZone(int loStart = 8, int loEnd = 11, int nyoStart = 13, int nyoEnd = 16)
{
   return SMC_IsLondonOpen(loStart, loEnd) || SMC_IsNewYorkOpen(nyoStart, nyoEnd);
}

//+------------------------------------------------------------------+
//| ATR pour calcul SL/TP par catégorie                              |
//+------------------------------------------------------------------+
double SMC_GetATRMultiplier(ENUM_SYMBOL_CATEGORY cat)
{
   switch(cat)
   {
      case SYM_BOOM_CRASH:  return 1.5;   // Plus serré
      case SYM_VOLATILITY:  return 2.0;
      case SYM_FOREX:       return 2.0;
      case SYM_COMMODITY:   return 2.5;
      case SYM_METAL:       return 2.5;
      default:              return 2.0;
   }
}

#endif // SMC_CONCEPTS_MQH
