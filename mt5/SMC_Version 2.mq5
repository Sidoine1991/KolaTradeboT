//+------------------------------------------------------------------+
//| TrendStrength_SMC_Pro.mq5                                        |
//| Indicateur MTF + SMC Ultra-Pro : Trend Strength + BOS/CHOCH/OB/FVG |
//| Auteur: ChatGPT (adapté pour toi)                                |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
#property version "1.0"

//--- includes
#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>
#include <ChartObjects\ChartObjectsShapes.mqh>

//--- Timeframes to show
ENUM_TIMEFRAMES TF_LIST[] = { PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1 };

//--- parameters
input int    MAperiod = 34;
input int    ADXperiod = 14;
input int    RSIperiod = 14;
input int    ATRperiod = 14;
input int    LookbackBars = 200;        // bars used for swing detection
input int    SwingWindow = 5;           // window to detect local highs/lows
input double MinFVGSizePips = 1.0;      // min size of FVG in pips (visual filter)
input int    MaxOBLookback = 50;        // max bars to search for order block

//--- visual positions
int table_x = 10;
int table_y = 8;
int table_line_height = 18;

//--- internal
datetime lastDrawTime = 0;

//+------------------------------------------------------------------+
//| Utility: create safe label                                        |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int font_size=11)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, font_size);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

//+------------------------------------------------------------------+
//| Utility: color for score                                          |
//+------------------------------------------------------------------+
color ScoreColor(double score)
{
   if(score >= 66) return clrLime;
   if(score >= 36) return clrYellow;
   return clrRed;
}

//+------------------------------------------------------------------+
//| Create and release handle helper                                 |
//+------------------------------------------------------------------+
double ReadIndicatorValue(int handle)
{
   double buf[];
   ArrayResize(buf,1);
   if(CopyBuffer(handle,0,0,1,buf) > 0) return buf[0];
   return 0.0;
}

//+------------------------------------------------------------------+
//| Compute MA slope (uses temporary handle)                          |
//+------------------------------------------------------------------+
double GetMASlope(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int h = iMA(symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArrayResize(buf, 3);
   if(CopyBuffer(h, 0, 0, 3, buf) < 2) { IndicatorRelease(h); return 0.0; }
   double slope = buf[0] - buf[1];
   IndicatorRelease(h);
   return slope;
}

//+------------------------------------------------------------------+
//| Get ADX value (main line)                                        |
//+------------------------------------------------------------------+
double GetADXValue(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int h = iADX(symbol, tf, period);
   if(h == INVALID_HANDLE) return 0.0;
   
   double adxBuffer[];
   ArraySetAsSeries(adxBuffer, true);
   if(CopyBuffer(h, 0, 0, 1, adxBuffer) <= 0) 
   {
      IndicatorRelease(h);
      return 0.0;
   }
   
   double adxValue = adxBuffer[0];
   IndicatorRelease(h);
   return adxValue;
}
double GetRSIValue(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int h = iRSI(symbol, tf, period, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 0.0;
   double v = ReadIndicatorValue(h);
   IndicatorRelease(h);
   return v;
}
double GetATRValue(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int h = iATR(symbol, tf, period);
   if(h == INVALID_HANDLE) return 0.0;
   double v = ReadIndicatorValue(h);
   IndicatorRelease(h);
   return v;
}

//+------------------------------------------------------------------+
//| Normalize helper                                                  |
//+------------------------------------------------------------------+
double NormalizeTo100(double value, double minv, double maxv)
{
   if(maxv == minv) return 0;
   double res = (value - minv) / (maxv - minv) * 100.0;
   if(res < 0) res = 0;
   if(res > 100) res = 100;
   return res;
}

//+------------------------------------------------------------------+
//| Compute Trend Strength with improved calculations                |
//+------------------------------------------------------------------+
double ComputeTrendStrength(string symbol, ENUM_TIMEFRAMES tf)
{
   // Get ADX value (0-100 scale)
   double adx = GetADXValue(symbol, tf, ADXperiod);
   // Normalize ADX (10-50 range is most relevant)
   double adx_s = NormalizeTo100(adx, 10, 50);
   
   // Get RSI (0-100 scale)
   double rsi = GetRSIValue(symbol, tf, RSIperiod);
   // Score based on distance from 50 (0-50 range)
   double rsi_s = fabs(rsi - 50.0) * 2.0; // Convert 0-50 range to 0-100
   
   // Get MA slope
   double slope = GetMASlope(symbol, tf, MAperiod);
   double price_buf[];
   ArrayResize(price_buf, 2);
   if(CopyClose(symbol, tf, 0, 2, price_buf) <= 1) return 0;
   double price = price_buf[0];
   
   // Normalize slope (0.1% of price as max slope)
   double max_slope = price * 0.001;
   double slope_s = 0;
   if(max_slope > 0) 
      slope_s = NormalizeTo100(fabs(slope), 0, max_slope);
   
   // Get ATR
   double atr = GetATRValue(symbol, tf, ATRperiod);
   // Normalize ATR (0.3% of price as max ATR)
   double max_atr = price * 0.003;
   double atr_s = 0;
   if(max_atr > 0)
      atr_s = NormalizeTo100(atr, 0, max_atr);
   
   // Weighted sum with adjusted weights
   double score = (adx_s * 0.40) +  // ADX has highest weight
                 (rsi_s * 0.30) +  // RSI distance from 50
                 (slope_s * 0.20) + // MA slope
                 (atr_s * 0.10);    // ATR has lowest weight
   
   // Ensure score is within bounds
   score = MathMax(0, MathMin(100, score));
   
   return score;
}

//+------------------------------------------------------------------+
//| Local swing detection (detect indices of swing highs/lows)       |
//+------------------------------------------------------------------+
struct SwingPoint { int index; double price; bool isHigh; };
int DetectSwings(string symbol, ENUM_TIMEFRAMES tf, int bars, int window, SwingPoint &swings[])
{
   // copy high/low
   double highs[], lows[];
   ArrayResize(highs, bars);
   ArrayResize(lows, bars);
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   int ch = CopyHigh(symbol, tf, 0, bars, highs);
   int cl = CopyLow(symbol, tf, 0, bars, lows);
   if(ch <= 0 || cl <= 0) return 0;

   int count = 0;
   for(int i = window; i < bars - window; i++)
   {
      bool isHigh=false, isLow=false;
      double valH = highs[i];
      double valL = lows[i];
      // high
      bool higher=true;
      for(int k=1;k<=window;k++) if(highs[i-k] >= valH || highs[i+k] >= valH) { higher=false; break; }
      if(higher) { isHigh=true; }
      // low
      bool lower=true;
      for(int k=1;k<=window;k++) if(lows[i-k] <= valL || lows[i+k] <= valL) { lower=false; break; }
      if(lower) { isLow=true; }

      if(isHigh)
      {
         ArrayResize(swings, count+1);
         swings[count].index = i;
         swings[count].price = valH;
         swings[count].isHigh = true;
         count++;
      }
      if(isLow)
      {
         ArrayResize(swings, count+1);
         swings[count].index = i;
         swings[count].price = valL;
         swings[count].isHigh = false;
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Find last significant swing (returns index in chart timeframe)    |
//+------------------------------------------------------------------+
int FindLastSwingIndex(string symbol, ENUM_TIMEFRAMES tf, bool wantHigh, int lookback)
{
   SwingPoint swings[];
   int n = DetectSwings(symbol, tf, lookback, SwingWindow, swings);
   for(int i = n-1; i>=0; i--)
      if(swings[i].isHigh == wantHigh) return swings[i].index;
   return -1;
}

//+------------------------------------------------------------------+
//| Detect BOS/CHOCH based on swing break                             |
//| - BOS up: price breaks above previous swing high                 |
//| - BOS down: price breaks below previous swing low                |
//| CHOCH occurs when break is opposite to recent trend             |
//+------------------------------------------------------------------+
enum ENUM_STRUCT { STRUCT_NONE=0, STRUCT_BOS_UP=1, STRUCT_BOS_DOWN=2, STRUCT_CHOCH_UP=3, STRUCT_CHOCH_DOWN=4 };
ENUM_STRUCT DetectStructure(string symbol, ENUM_TIMEFRAMES tf)
{
   // get recent swings (a few)
   SwingPoint swings[];
   int n = DetectSwings(symbol, tf, LookbackBars, SwingWindow, swings);
   if(n < 4) return STRUCT_NONE;

   // find last two swing highs and lows
   double lastHigh = -1, prevHigh = -1, lastLow = -1, prevLow = -1;
   for(int i = n-1; i>=0; i--)
   {
      if(swings[i].isHigh)
      {
         if(lastHigh < 0) lastHigh = swings[i].price;
         else if(prevHigh < 0) { prevHigh = swings[i].price; }
      }
      if(swings[i].isHigh && lastHigh>=0 && prevHigh>=0) break;
   }
   for(int i = n-1; i>=0; i--)
   {
      if(!swings[i].isHigh)
      {
         if(lastLow < 0) lastLow = swings[i].price;
         else if(prevLow < 0) { prevLow = swings[i].price; }
      }
      if(lastLow>=0 && prevLow>=0) break;
   }

   // get price (current close)
   double price_buf[];
   ArrayResize(price_buf,1);
   if(CopyClose(symbol, tf, 0, 1, price_buf) <= 0) return STRUCT_NONE;
   double price = price_buf[0];

   // BOS up
   if(prevHigh > 0 && price > prevHigh) // price breaks above prevHigh
   {
      // if price also below lastHigh? interpret CHOCH
      if(lastLow > 0 && price < lastLow) return STRUCT_CHOCH_UP;
      return STRUCT_BOS_UP;
   }
   // BOS down
   if(prevLow > 0 && price < prevLow)
   {
      if(lastHigh > 0 && price > lastHigh) return STRUCT_CHOCH_DOWN;
      return STRUCT_BOS_DOWN;
   }
   return STRUCT_NONE;
}

//+------------------------------------------------------------------+
//| Detect simple FVGs (three-bar gap)                               |
//| naive detection: if middle candle creates an inefficiency        |
//+------------------------------------------------------------------+
struct FVGZone { int bar_time_index; double top; double bottom; ENUM_TIMEFRAMES tf; };
int DetectFVG(string symbol, ENUM_TIMEFRAMES tf, int lookback, FVGZone &zones[])
{
   // copy OHLC
   int bars = MathMin(lookback, 200);
   double opens[], highs[], lows[], closes[];
   ArraySetAsSeries(opens,true); ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true); ArraySetAsSeries(closes,true);
   if(CopyOpen(symbol, tf, 0, bars, opens) <= 0) return 0;
   CopyHigh(symbol, tf, 0, bars, highs);
   CopyLow(symbol, tf, 0, bars, lows);
   CopyClose(symbol, tf, 0, bars, closes);

   int count = 0;
   // iterate through bars i = 2..bars-1 (we need 3 bars: i+2, i+1, i)
   for(int i = 0; i < bars - 2; i++)
   {
      // Consider candles with middle 'gap' between first and third
      // bullish FVG: low of bar i+2 > high of bar i  -> gap up (rare)
      // bearish FVG: high of bar i+2 < low of bar i -> gap down
      double high1 = highs[i+2];
      double low3  = lows[i];
      // we'll use middle candle i+1 as the gap maker (simplified)
      double gap_top = MathMin(highs[i+2], highs[i]);
      double gap_bottom = MathMax(lows[i+2], lows[i]);
      // Simpler detection: if the middle candle body creates unused range:
      double mid_high = highs[i+1], mid_low = lows[i+1];
      // bullish FVG if mid_low > high of next? This is fuzzy—use simple rule:
      if(highs[i] < lows[i+2] - (MinFVGSizePips * _Point))
      {
         // bullish FVG
         ArrayResize(zones, count+1);
         zones[count].bar_time_index = i;
         zones[count].top = lows[i+2];    // top of gap
         zones[count].bottom = highs[i];  // bottom of gap
         zones[count].tf = tf;
         count++;
      }
      else if(lows[i] > highs[i+2] + (MinFVGSizePips * _Point))
      {
         // bearish FVG
         ArrayResize(zones, count+1);
         zones[count].bar_time_index = i;
         zones[count].top = lows[i];      // top
         zones[count].bottom = highs[i+2];// bottom
         zones[count].tf = tf;
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Structure pour stocker les informations d'un Order Block          |
//+------------------------------------------------------------------+
struct OBZone 
{
   datetime         time1;      // Temps de début
   datetime         time2;      // Temps de fin
   double           high;       // Niveau haut
   double           low;        // Niveau bas
   ENUM_TIMEFRAMES  tf;         // Timeframe
   bool             bullish;    // Direction haussière ou baissière
};
int DetectOrderBlocks(string symbol, ENUM_TIMEFRAMES tf, int lookback, OBZone &obs[])
{
   // copy OHLC for lookback
   int bars = MathMin(lookback, 200);
   double opens[], highs[], lows[], closes[];
   ArraySetAsSeries(opens,true); ArraySetAsSeries(highs,true); ArraySetAsSeries(lows,true); ArraySetAsSeries(closes,true);
   if(CopyOpen(symbol, tf, 0, bars, opens) <= 0) return 0;
   CopyHigh(symbol, tf, 0, bars, highs);
   CopyLow(symbol, tf, 0, bars, lows);
   CopyClose(symbol, tf, 0, bars, closes);
   // naive: look for strong directional move after a single candle (engulf or strong body)
   int count = 0;
   for(int i = 3; i < bars-3; i++)
   {
      // candle i is potential OB if body small and next 2 candles move strongly opposite
      double body_i = MathAbs(opens[i]-closes[i]);
      double range_next = MathAbs(closes[i-2] - closes[i+1]);
      if(body_i < (ATRperiod>0 ? GetATRValue(symbol, tf, ATRperiod) * 0.5 : _Point*5) && range_next > (GetATRValue(symbol, tf, ATRperiod)*1.2))
      {
         // bullish OB if next move up
         if(closes[i-1] < closes[i+1])
         {
            ArrayResize(obs, count+1);
            obs[count].time1 = iTime(symbol, tf, i+1);
            obs[count].time2 = iTime(symbol, tf, i-1);
            obs[count].high = highs[i];
            obs[count].low  = lows[i];
            obs[count].tf = tf;
            obs[count].bullish = true;
            count++;
         }
         else if(closes[i-1] > closes[i+1])
         {
            ArrayResize(obs, count+1);
            obs[count].time1 = iTime(symbol, tf, i+1);
            obs[count].time2 = iTime(symbol, tf, i-1);
            obs[count].high = highs[i];
            obs[count].low  = lows[i];
            obs[count].tf = tf;
            obs[count].bullish = false;
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Drawing helpers                                                  |
//+------------------------------------------------------------------+
void DrawFVGRectangle(string baseName, ENUM_TIMEFRAMES tf, double top, double bottom, int idx)
{
   string nm = baseName + "_FVG_" + EnumToString(tf) + "_" + IntegerToString(idx);
   if(ObjectFind(0,nm) < 0)
      ObjectCreate(0, nm, OBJ_RECTANGLE, 0, TimeCurrent(), top, TimeCurrent(), bottom);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clrMediumPurple);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, top);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, bottom);
}
//+------------------------------------------------------------------+
//| Dessine un rectangle pour l'Order Block                          |
//+------------------------------------------------------------------+
void DrawOBRectangle(string baseName, const OBZone &ob, int idx)
{
   string nm = baseName + "_OB_" + IntegerToString(ob.tf) + "_" + IntegerToString(idx);
   
   if(ObjectFind(0, nm) < 0)
   {
      if(!ObjectCreate(0, nm, OBJ_RECTANGLE, 0, ob.time1, ob.high, ob.time2, ob.low))
      {
         Print("Erreur création rectangle OB: ", GetLastError());
         return;
      }
   }
   
   color c = ob.bullish ? clrDodgerBlue : clrOrangeRed;
   
   // Définition des propriétés de l'objet
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   
   // Mise à jour des coordonnées
   ObjectSetInteger(0, nm, OBJPROP_TIME, 0, ob.time1);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, ob.high);
   ObjectSetInteger(0, nm, OBJPROP_TIME, 1, ob.time2);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, ob.low);
   
   // Ajustement des propriétés visuelles
   ObjectSetInteger(0, nm, OBJPROP_FILL, true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, nm, OBJPROP_ZORDER, 0);
}
void DrawBOSLine(string baseName, ENUM_TIMEFRAMES tf, double price, bool up, int idx)
{
   string nm = baseName + "_BOS_" + EnumToString(tf) + "_" + IntegerToString(idx);
   if(ObjectFind(0,nm) < 0)
      ObjectCreate(0,nm,OBJ_HLINE,0,0,price);
   ObjectSetInteger(0,nm,OBJPROP_COLOR, up ? clrLime : clrRed);
   ObjectSetInteger(0,nm,OBJPROP_STYLE, up ? STYLE_SOLID : STYLE_SOLID);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}
void DrawCHOCHMarker(string baseName, ENUM_TIMEFRAMES tf, double price, bool up, int idx)
{
   string nm = baseName + "_CHOCH_" + EnumToString(tf) + "_" + IntegerToString(idx);
   if(ObjectFind(0,nm) < 0)
      ObjectCreate(0,nm,OBJ_ARROW,0,TimeCurrent(),price);
   ObjectSetInteger(0,nm,OBJPROP_ARROWCODE, up ? 233 : 234);
   ObjectSetInteger(0,nm,OBJPROP_COLOR, up ? clrBlue : clrMagenta);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

//+------------------------------------------------------------------+
//| Remove previous SMC objects                                       |
//+------------------------------------------------------------------+
void ClearSMCObjects()
{
   int total = ObjectsTotal(0);
   for(int i=total-1;i>=0;i--)
   {
      string nm = ObjectName(0,i);
      if(StringFind(nm,"TS_")==0 || StringFind(nm,"SMC_")==0)
         ObjectDelete(0,nm);
   }
}

//+------------------------------------------------------------------+
//| Main drawing / calculation loop (OnCalculate)                    |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   string sym = _Symbol;
   // throttle redraw (every 1s)
   if(TimeCurrent() == lastDrawTime) return rates_total;
   lastDrawTime = TimeCurrent();

   // clear previous SMC specific labels only (keeps other charts objects)
   //Better to keep to avoid flicker: only remove labels with TS_ prefix
   int tot = ObjectsTotal(0);
   for(int i=tot-1;i>=0;i--)
   {
      string nm = ObjectName(0,i);
      if(StringFind(nm,"TS_")==0)
         ObjectDelete(0,nm);
   }

   // Draw title
   CreateLabel("TS_Title", table_x, table_y, "TrendStrength SMC Pro", clrWhite, 13);
   int y = table_y + table_line_height;

   // For each timeframe compute score + structure + draw
   for(int i=0;i<ArraySize(TF_LIST);i++)
   {
      ENUM_TIMEFRAMES tf = TF_LIST[i];
      double score = ComputeTrendStrength(sym, tf);
      color sc_col = ScoreColor(score);
      string line = EnumToString(tf) + " : " + DoubleToString(score,1);
      CreateLabel("TS_"+IntegerToString(i), table_x, y, line, sc_col, 11);
      y += table_line_height;

      // Detect structure
      ENUM_STRUCT st = DetectStructure(sym, tf);
      if(st == STRUCT_BOS_UP)
      {
         // draw BOS line at prevHigh (naive)
         // find previous swing high index
         int idx = FindLastSwingIndex(sym, tf, true, LookbackBars);
         if(idx > 0)
         {
            double price_buf[];
            ArrayResize(price_buf,1);
            if(CopyHigh(sym, tf, idx, 1, price_buf) > 0)
               DrawBOSLine("TS_SMC", tf, price_buf[0], true, i);
         }
      }
      else if(st == STRUCT_BOS_DOWN)
      {
         int idx = FindLastSwingIndex(sym, tf, false, LookbackBars);
         if(idx > 0)
         {
            double price_buf[];
            ArrayResize(price_buf,1);
            if(CopyLow(sym, tf, idx, 1, price_buf) > 0)
               DrawBOSLine("TS_SMC", tf, price_buf[0], false, i);
         }
      }
      else if(st == STRUCT_CHOCH_UP || st == STRUCT_CHOCH_DOWN)
      {
         // mark CHOCH with arrow at current price
         double price_buf[];
         ArrayResize(price_buf,1);
         if(CopyClose(sym, tf, 0, 1, price_buf) > 0)
            DrawCHOCHMarker("TS_SMC", tf, price_buf[0], st==STRUCT_CHOCH_UP, i);
      }

      // Detect some FVGs and OBs (limited number to avoid clutter)
      FVGZone fvg[];
      int nf = DetectFVG(sym, tf, 120, fvg);
      for(int j=0;j<MathMin(nf,3);j++)
         DrawFVGRectangle("TS_SMC", tf, fvg[j].top, fvg[j].bottom, j);

      OBZone obs[];
      int no = DetectOrderBlocks(sym, tf, MaxOBLookback, obs);
      for(int j=0;j<MathMin(no,2);j++)
         DrawOBRectangle("TS_SMC", obs[j], j);
   }

   // Legend + short tips
   CreateLabel("TS_Legend1", table_x+220, table_y, "BOS: green/red line", clrWhite, 10);
   CreateLabel("TS_Legend2", table_x+220, table_y+14, "CHOCH: arrows", clrWhite, 10);
   CreateLabel("TS_Legend3", table_x+220, table_y+28, "OB: rectangles", clrWhite, 10);
   CreateLabel("TS_Legend4", table_x+220, table_y+42, "FVG: purple zones", clrWhite, 10);

   return(rates_total);
}
//+------------------------------------------------------------------+
