#property strict
#property indicator_chart_window
#property indicator_plots 0

input group "TIMEFRAMES"
input bool ShowM15Levels = true;
input bool ShowH1Levels = true;
input bool ShowH4Levels = true;
input bool ShowD1Levels = false;
input bool ShowW1Levels = false;

input group "ALGORITHM (THREE LINE BREAK)"
input int  LineBreakPeriod = 3;
input int  MaxBarsToAnalyze = 300;

input group "TOUCH SYSTEM"
input bool   EnableTouchDetection = true;
input double TouchZoneATRPercent = 25.0;
input int    BarsForTouchCount = 200;
input int    MinLineWidth = 1;
input int    MaxLineWidth = 5;
input int    TouchesForMaxWidth = 10;

input group "PARAMETRES D'AFFICHAGE KOLA"
input bool  ShowLabels = true;
input bool  ShowTouchCount = false;
input int   LabelShiftBars = 3;
input color BuyLevelColor = clrLimeGreen;
input color SellLevelColor = clrRed;

input group "MODULE SIDO (FIGURES CHARTISTES)"
input bool   EnableSIDO = true;
input int    SIDOPivotLookback = 3;
input int    SIDOBarsToAnalyze = 300;
input int    SIDOMaxBarsBetweenSwings = 80;
input double SIDOToleranceATRPercent = 35.0;
input color  SIDODoubleTopColor = clrOrangeRed;
input color  SIDODoubleBottomColor = clrDeepSkyBlue;
input bool   ShowSIDOLabels = true;

string TFTag(const ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M15) return "M15";
   if(tf == PERIOD_H1) return "H1";
   if(tf == PERIOD_H4) return "H4";
   if(tf == PERIOD_D1) return "D1";
   if(tf == PERIOD_W1) return "W1";
   return "UNK";
}

string GVKey(const string moduleTag, const string tfTag, const string side)
{
   return moduleTag + "_" + _Symbol + "_" + tfTag + "_" + side;
}

bool IsCrashSymbol()
{
   string s = StringToLower(_Symbol);
   return (StringFind(s, "crash") >= 0);
}

bool IsBoomSymbol()
{
   string s = StringToLower(_Symbol);
   return (StringFind(s, "boom") >= 0);
}

void PublishLevel(const string moduleTag, const string tfTag, const string side, const double level)
{
   GlobalVariableSet(GVKey(moduleTag, tfTag, side), level);
}

bool IsPivotHigh(const MqlRates &rates[], const int n, const int i, const int lb)
{
   double v = rates[i].high;
   for(int k = 1; k <= lb; k++)
      if(i - k < 0 || i + k >= n || rates[i - k].high >= v || rates[i + k].high > v)
         return false;
   return true;
}

bool IsPivotLow(const MqlRates &rates[], const int n, const int i, const int lb)
{
   double v = rates[i].low;
   for(int k = 1; k <= lb; k++)
      if(i - k < 0 || i + k >= n || rates[i - k].low <= v || rates[i + k].low < v)
         return false;
   return true;
}

int CalcTouches(const MqlRates &rates[], const int n, const double level, const double zone, const int barsLookback)
{
   int touches = 0;
   int lim = MathMin(n - 1, barsLookback);
   for(int i = 0; i <= lim; i++)
   {
      double hi = rates[i].high;
      double lo = rates[i].low;
      if(MathAbs(hi - level) <= zone || MathAbs(lo - level) <= zone || (lo <= level && hi >= level))
         touches++;
   }
   return touches;
}

int WidthFromTouches(const int touches)
{
   int tMax = MathMax(1, TouchesForMaxWidth);
   double r = MathMin(1.0, (double)touches / (double)tMax);
   int w = (int)MathRound(MinLineWidth + (MaxLineWidth - MinLineWidth) * r);
   return (int)MathMax(MinLineWidth, MathMin(MaxLineWidth, w));
}

void DrawKolaLevel(const string tfTag, const string side, const double level, const int touches, const color clr, const ENUM_TIMEFRAMES tf)
{
   string nm = "GOM_KOLA_" + side + "_" + tfTag;
   if(ObjectFind(0, nm) < 0)
      ObjectCreate(0, nm, OBJ_HLINE, 0, 0, level);

   ObjectSetDouble(0, nm, OBJPROP_PRICE, level);
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, WidthFromTouches(touches));
   ObjectSetInteger(0, nm, OBJPROP_BACK, false);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, nm, OBJPROP_HIDDEN, false);

   string labelName = nm + "_LBL";
   if(!ShowLabels)
   {
      ObjectDelete(0, labelName);
      return;
   }

   string txt = tfTag + " " + side + " Level";
   if(ShowTouchCount) txt += " (" + IntegerToString(touches) + ")";

   int visShift = MathMax(0, LabelShiftBars);
   datetime t = iTime(_Symbol, PERIOD_CURRENT, visShift);
   if(t <= 0) t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(ObjectFind(0, labelName) < 0)
      ObjectCreate(0, labelName, OBJ_TEXT, 0, t, level);

   ObjectMove(0, labelName, 0, t, level);
   ObjectSetString(0, labelName, OBJPROP_TEXT, txt);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
}

void ClearKolaTFObjects(const string tfTag)
{
   ObjectDelete(0, "GOM_KOLA_BUY_" + tfTag);
   ObjectDelete(0, "GOM_KOLA_SELL_" + tfTag);
   ObjectDelete(0, "GOM_KOLA_BUY_" + tfTag + "_LBL");
   ObjectDelete(0, "GOM_KOLA_SELL_" + tfTag + "_LBL");
}

void DrawSIDOPattern(const string tfTag, const string patternType, const int idxA, const int idxB, const double levelA, const double levelB, const color clr, const MqlRates &rates[])
{
   string base = "GOM_SIDO_" + patternType + "_" + tfTag;
   string line = base + "_LN";
   string label = base + "_LBL";

   datetime tA = rates[idxA].time;
   datetime tB = rates[idxB].time;
   double y = (levelA + levelB) * 0.5;
   datetime tLabel = iTime(_Symbol, PERIOD_CURRENT, MathMax(0, LabelShiftBars));
   if(tLabel <= 0) tLabel = tB;

   if(ObjectFind(0, line) < 0)
      ObjectCreate(0, line, OBJ_TREND, 0, tA, levelA, tB, levelB);

   ObjectMove(0, line, 0, tA, levelA);
   ObjectMove(0, line, 1, tB, levelB);
   ObjectSetInteger(0, line, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, line, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, line, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, line, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, line, OBJPROP_HIDDEN, false);

   if(!ShowSIDOLabels)
   {
      ObjectDelete(0, label);
      return;
   }

   if(ObjectFind(0, label) < 0)
      ObjectCreate(0, label, OBJ_TEXT, 0, tLabel, y);

   ObjectMove(0, label, 0, tLabel, y);
   ObjectSetString(0, label, OBJPROP_TEXT, tfTag + " " + patternType);
   ObjectSetString(0, label, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, label, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, label, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, label, OBJPROP_BACK, false);
}

void ClearSIDOTFObjects(const string tfTag)
{
   string patterns[] = {"DOUBLE_TOP", "DOUBLE_BOTTOM"};
   for(int i = 0; i < ArraySize(patterns); i++)
   {
      string base = "GOM_SIDO_" + patterns[i] + "_" + tfTag;
      ObjectDelete(0, base + "_LN");
      ObjectDelete(0, base + "_LBL");
   }
}

void ProcessKolaTF(const ENUM_TIMEFRAMES tf, const MqlRates &rates[], const int copied, const double atrVal)
{
   string tfTag = TFTag(tf);
   if(tfTag == "UNK") return;

   int lb = MathMax(1, LineBreakPeriod);
   if(copied < (lb * 3 + 20))
   {
      ClearKolaTFObjects(tfTag);
      PublishLevel("GOM_KOLA", tfTag, "BUY", 0.0);
      PublishLevel("GOM_KOLA", tfTag, "SELL", 0.0);
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0) bid = rates[0].close;
   double zone = EnableTouchDetection ? (atrVal * (TouchZoneATRPercent / 100.0)) : 0.0;

   double bestBuy = 0.0, bestSell = 0.0;
   int bestBuyTouches = -1, bestSellTouches = -1;
   int maxIdx = MathMin(copied - lb - 1, MaxBarsToAnalyze);

   for(int i = lb + 1; i <= maxIdx; i++)
   {
      if(IsPivotLow(rates, copied, i, lb))
      {
         double lvl = rates[i].low;
         int touches = EnableTouchDetection ? CalcTouches(rates, copied, lvl, zone, BarsForTouchCount) : 1;
         bool better = (lvl < bid) ? ((touches > bestBuyTouches) || (touches == bestBuyTouches && lvl > bestBuy))
                                   : (bestBuy <= 0.0 && touches > bestBuyTouches);
         if(better) { bestBuy = lvl; bestBuyTouches = touches; }
      }

      if(IsPivotHigh(rates, copied, i, lb))
      {
         double lvl = rates[i].high;
         int touches = EnableTouchDetection ? CalcTouches(rates, copied, lvl, zone, BarsForTouchCount) : 1;
         bool better = (lvl > bid) ? ((touches > bestSellTouches) || (touches == bestSellTouches && (bestSell <= 0.0 || lvl < bestSell)))
                                   : (bestSell <= 0.0 && touches > bestSellTouches);
         if(better) { bestSell = lvl; bestSellTouches = touches; }
      }
   }

   // Trading guardrails:
   // - no BUY levels on Crash symbols
   // - no SELL levels on Boom symbols
   if(IsCrashSymbol()) bestBuy = 0.0;
   if(IsBoomSymbol()) bestSell = 0.0;

   if(bestBuy > 0.0) DrawKolaLevel(tfTag, "BUY", bestBuy, MathMax(1, bestBuyTouches), BuyLevelColor, tf);
   else ObjectDelete(0, "GOM_KOLA_BUY_" + tfTag);
   if(bestSell > 0.0) DrawKolaLevel(tfTag, "SELL", bestSell, MathMax(1, bestSellTouches), SellLevelColor, tf);
   else ObjectDelete(0, "GOM_KOLA_SELL_" + tfTag);

   PublishLevel("GOM_KOLA", tfTag, "BUY", bestBuy);
   PublishLevel("GOM_KOLA", tfTag, "SELL", bestSell);
}

void ProcessSIDOTF(const ENUM_TIMEFRAMES tf, const MqlRates &rates[], const int copied, const double atrVal)
{
   string tfTag = TFTag(tf);
   if(tfTag == "UNK") return;

   if(!EnableSIDO)
   {
      ClearSIDOTFObjects(tfTag);
      PublishLevel("GOM_SIDO", tfTag, "DOUBLE_TOP", 0.0);
      PublishLevel("GOM_SIDO", tfTag, "DOUBLE_BOTTOM", 0.0);
      return;
   }

   int lb = MathMax(1, SIDOPivotLookback);
   if(copied < (lb * 3 + 20))
   {
      ClearSIDOTFObjects(tfTag);
      PublishLevel("GOM_SIDO", tfTag, "DOUBLE_TOP", 0.0);
      PublishLevel("GOM_SIDO", tfTag, "DOUBLE_BOTTOM", 0.0);
      return;
   }

   double tol = atrVal * (SIDOToleranceATRPercent / 100.0);
   int maxIdx = MathMin(copied - lb - 1, SIDOBarsToAnalyze);

   int lastHigh1 = -1, lastHigh2 = -1, lastLow1 = -1, lastLow2 = -1;
   for(int i = lb + 1; i <= maxIdx; i++)
   {
      if(IsPivotHigh(rates, copied, i, lb))
      {
         lastHigh2 = lastHigh1;
         lastHigh1 = i;
      }
      if(IsPivotLow(rates, copied, i, lb))
      {
         lastLow2 = lastLow1;
         lastLow1 = i;
      }
   }

   bool hasDoubleTop = false, hasDoubleBottom = false;
   double topLevel = 0.0, bottomLevel = 0.0;

   if(lastHigh1 >= 0 && lastHigh2 >= 0)
   {
      int barsGap = MathAbs(lastHigh1 - lastHigh2);
      double a = rates[lastHigh1].high;
      double b = rates[lastHigh2].high;
      if(barsGap <= SIDOMaxBarsBetweenSwings && MathAbs(a - b) <= tol)
      {
         hasDoubleTop = true;
         topLevel = (a + b) * 0.5;
         DrawSIDOPattern(tfTag, "DOUBLE_TOP", lastHigh2, lastHigh1, b, a, SIDODoubleTopColor, rates);
      }
   }

   if(lastLow1 >= 0 && lastLow2 >= 0)
   {
      int barsGap = MathAbs(lastLow1 - lastLow2);
      double a = rates[lastLow1].low;
      double b = rates[lastLow2].low;
      if(barsGap <= SIDOMaxBarsBetweenSwings && MathAbs(a - b) <= tol)
      {
         hasDoubleBottom = true;
         bottomLevel = (a + b) * 0.5;
         DrawSIDOPattern(tfTag, "DOUBLE_BOTTOM", lastLow2, lastLow1, b, a, SIDODoubleBottomColor, rates);
      }
   }

   if(!hasDoubleTop)
   {
      ObjectDelete(0, "GOM_SIDO_DOUBLE_TOP_" + tfTag + "_LN");
      ObjectDelete(0, "GOM_SIDO_DOUBLE_TOP_" + tfTag + "_LBL");
   }
   if(!hasDoubleBottom)
   {
      ObjectDelete(0, "GOM_SIDO_DOUBLE_BOTTOM_" + tfTag + "_LN");
      ObjectDelete(0, "GOM_SIDO_DOUBLE_BOTTOM_" + tfTag + "_LBL");
   }

   PublishLevel("GOM_SIDO", tfTag, "DOUBLE_TOP", topLevel);
   PublishLevel("GOM_SIDO", tfTag, "DOUBLE_BOTTOM", bottomLevel);
}

void ProcessTF(const ENUM_TIMEFRAMES tf)
{
   int barsNeeded = MathMax(80, MathMax(MaxBarsToAnalyze, SIDOBarsToAnalyze) + MathMax(LineBreakPeriod, SIDOPivotLookback) * 4);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, barsNeeded, rates);

   int atrHandle = iATR(_Symbol, tf, 14);
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double ab[];
      ArraySetAsSeries(ab, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, ab) >= 1) atrVal = ab[0];
      IndicatorRelease(atrHandle);
   }
   if(atrVal <= 0.0)
   {
      double fallback = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(fallback <= 0.0 && copied > 0) fallback = rates[0].close;
      atrVal = fallback * 0.001;
   }

   ProcessKolaTF(tf, rates, copied, atrVal);
   ProcessSIDOTF(tf, rates, copied, atrVal);
}

int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "GOM KOLA + SIDO");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   string tfs[] = {"M15", "H1", "H4", "D1", "W1"};
   for(int i = 0; i < ArraySize(tfs); i++)
   {
      ClearKolaTFObjects(tfs[i]);
      ClearSIDOTFObjects(tfs[i]);
   }
}

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
   if(ShowM15Levels) ProcessTF(PERIOD_M15); else { ClearKolaTFObjects("M15"); ClearSIDOTFObjects("M15"); }
   if(ShowH1Levels) ProcessTF(PERIOD_H1); else { ClearKolaTFObjects("H1"); ClearSIDOTFObjects("H1"); }
   if(ShowH4Levels) ProcessTF(PERIOD_H4); else { ClearKolaTFObjects("H4"); ClearSIDOTFObjects("H4"); }
   if(ShowD1Levels) ProcessTF(PERIOD_D1); else { ClearKolaTFObjects("D1"); ClearSIDOTFObjects("D1"); }
   if(ShowW1Levels) ProcessTF(PERIOD_W1); else { ClearKolaTFObjects("W1"); ClearSIDOTFObjects("W1"); }
   ChartRedraw(0);
   return(rates_total);
}
