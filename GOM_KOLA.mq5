#property strict
#property indicator_chart_window
#property indicator_plots 0

input group "TIMEFRAMES"
input bool ShowH1Levels = true;
input bool ShowH4Levels = true;
input bool ShowD1Levels = false;
input bool ShowW1Levels = false;

input group "ALGORITHM (THREE LINE BREAK)"
input int  LineBreakPeriod = 3;
input int  MaxBarsToAnalyze = 300;

input group "TOUCH SYSTEM"
input bool   EnableTouchDetection = true;
input double TouchZoneATRPercent = 25.0;   // % de ATR
input int    BarsForTouchCount = 200;
input int    MinLineWidth = 1;
input int    MaxLineWidth = 5;
input int    TouchesForMaxWidth = 10;

input group "PARAMETRES D'AFFICHAGE"
input bool  ShowLabels = true;
input bool  ShowTouchCount = false;
input int   LabelShiftBars = 3;
input color BuyLevelColor = clrLimeGreen;
input color SellLevelColor = clrRed;

string TFTag(const ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_H1) return "H1";
   if(tf == PERIOD_H4) return "H4";
   if(tf == PERIOD_D1) return "D1";
   if(tf == PERIOD_W1) return "W1";
   return "UNK";
}

string GVKey(const string tfTag, const string side)
{
   return "GOM_KOLA_" + _Symbol + "_" + tfTag + "_" + side;
}

void PublishLevel(const string tfTag, const string side, const double level)
{
   string key = GVKey(tfTag, side);
   GlobalVariableSet(key, level);
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

int WidthFromTouches(const int touches)
{
   int tMax = MathMax(1, TouchesForMaxWidth);
   double r = MathMin(1.0, (double)touches / (double)tMax);
   int w = (int)MathRound(MinLineWidth + (MaxLineWidth - MinLineWidth) * r);
   return (int)MathMax(MinLineWidth, MathMin(MaxLineWidth, w));
}

void DrawLevel(const string tfTag, const string side, const double level, const int touches, const color clr, const ENUM_TIMEFRAMES tf)
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

   datetime t = TimeCurrent() + (datetime)(LabelShiftBars * PeriodSeconds(tf));
   if(ObjectFind(0, labelName) < 0)
      ObjectCreate(0, labelName, OBJ_TEXT, 0, t, level);

   ObjectMove(0, labelName, 0, t, level);
   ObjectSetString(0, labelName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void ClearTFObjects(const string tfTag)
{
   ObjectDelete(0, "GOM_KOLA_BUY_" + tfTag);
   ObjectDelete(0, "GOM_KOLA_SELL_" + tfTag);
   ObjectDelete(0, "GOM_KOLA_BUY_" + tfTag + "_LBL");
   ObjectDelete(0, "GOM_KOLA_SELL_" + tfTag + "_LBL");
}

void ProcessTF(const ENUM_TIMEFRAMES tf)
{
   string tfTag = TFTag(tf);
   if(tfTag == "UNK") return;

   int lb = MathMax(1, LineBreakPeriod);
   int barsNeeded = MathMax(60, MaxBarsToAnalyze + lb * 4);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, tf, 0, barsNeeded, rates);
   if(copied < (lb * 3 + 20))
   {
      ClearTFObjects(tfTag);
      PublishLevel(tfTag, "BUY", 0.0);
      PublishLevel(tfTag, "SELL", 0.0);
      return;
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0) bid = rates[0].close;

   int atrHandle = iATR(_Symbol, tf, 14);
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double ab[];
      ArraySetAsSeries(ab, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, ab) >= 1) atrVal = ab[0];
      IndicatorRelease(atrHandle);
   }
   if(atrVal <= 0.0) atrVal = bid * 0.001;
   double zone = EnableTouchDetection ? (atrVal * (TouchZoneATRPercent / 100.0)) : 0.0;

   double bestBuy = 0.0, bestSell = 0.0;
   int bestBuyTouches = -1, bestSellTouches = -1;

   int maxIdx = MathMin(copied - lb - 1, MaxBarsToAnalyze);
   for(int i = lb + 1; i <= maxIdx; i++)
   {
      if(IsPivotLow(rates, copied, i, lb))
      {
         double lvl = rates[i].low;
         if(lvl > 0.0)
         {
            int touches = EnableTouchDetection ? CalcTouches(rates, copied, lvl, zone, BarsForTouchCount) : 1;
            bool better = false;
            if(lvl < bid)
               better = (touches > bestBuyTouches) || (touches == bestBuyTouches && lvl > bestBuy);
            else if(bestBuy <= 0.0)
               better = (touches > bestBuyTouches);

            if(better)
            {
               bestBuy = lvl;
               bestBuyTouches = touches;
            }
         }
      }

      if(IsPivotHigh(rates, copied, i, lb))
      {
         double lvl = rates[i].high;
         if(lvl > 0.0)
         {
            int touches = EnableTouchDetection ? CalcTouches(rates, copied, lvl, zone, BarsForTouchCount) : 1;
            bool better = false;
            if(lvl > bid)
               better = (touches > bestSellTouches) || (touches == bestSellTouches && (bestSell <= 0.0 || lvl < bestSell));
            else if(bestSell <= 0.0)
               better = (touches > bestSellTouches);

            if(better)
            {
               bestSell = lvl;
               bestSellTouches = touches;
            }
         }
      }
   }

   if(bestBuy > 0.0)
      DrawLevel(tfTag, "BUY", bestBuy, MathMax(1, bestBuyTouches), BuyLevelColor, tf);
   else
      ObjectDelete(0, "GOM_KOLA_BUY_" + tfTag);

   if(bestSell > 0.0)
      DrawLevel(tfTag, "SELL", bestSell, MathMax(1, bestSellTouches), SellLevelColor, tf);
   else
      ObjectDelete(0, "GOM_KOLA_SELL_" + tfTag);

   PublishLevel(tfTag, "BUY", bestBuy);
   PublishLevel(tfTag, "SELL", bestSell);
}

int OnInit()
{
   IndicatorSetString(INDICATOR_SHORTNAME, "GOM KOLA");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   string tfs[] = {"H1", "H4", "D1", "W1"};
   for(int i = 0; i < ArraySize(tfs); i++)
      ClearTFObjects(tfs[i]);
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
   if(ShowH1Levels) ProcessTF(PERIOD_H1); else { ClearTFObjects("H1"); PublishLevel("H1", "BUY", 0.0); PublishLevel("H1", "SELL", 0.0); }
   if(ShowH4Levels) ProcessTF(PERIOD_H4); else { ClearTFObjects("H4"); PublishLevel("H4", "BUY", 0.0); PublishLevel("H4", "SELL", 0.0); }
   if(ShowD1Levels) ProcessTF(PERIOD_D1); else { ClearTFObjects("D1"); PublishLevel("D1", "BUY", 0.0); PublishLevel("D1", "SELL", 0.0); }
   if(ShowW1Levels) ProcessTF(PERIOD_W1); else { ClearTFObjects("W1"); PublishLevel("W1", "BUY", 0.0); PublishLevel("W1", "SELL", 0.0); }
   return(rates_total);
}
