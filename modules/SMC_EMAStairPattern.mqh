//+------------------------------------------------------------------+
//| SMC_EMAStairPattern.mqh — Zigzag EMA M5 (touch → trade + projection) |
//+------------------------------------------------------------------+
#ifndef SMC_EMA_STAIR_PATTERN_MQH
#define SMC_EMA_STAIR_PATTERN_MQH

struct SMC_StairPatternState
{
   bool     active;
   bool     forming;
   bool     bullish;
   int      touchCount;
   int      dirSign;
   datetime lastTouchBar;
   datetime lastEntryTime;
   datetime lastAlertTime;
   double   avgImpulse;
   double   lastEma;
   double   lastTouchPrice;
};

SMC_StairPatternState g_stairPattern = {false, false, false, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0};

double SMCSP_GetM5ATR(const string symbol)
{
   int h = iATR(symbol, PERIOD_M5, 14);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h, 0, 0, 1, buf) < 1) return 0.0;
   IndicatorRelease(h);
   return buf[0];
}

bool SMCSP_CopyM5EMA(const int emaHandle, const int count, double &ema[])
{
   ArraySetAsSeries(ema, true);
   if(emaHandle == INVALID_HANDLE) return false;
   return (CopyBuffer(emaHandle, 0, 0, count, ema) >= count);
}

bool SMCSP_EMASlopeOK(const int dirSign, const double &ema[], const int lookback = 5)
{
   if(ArraySize(ema) < lookback + 1) return false;
   double delta = ema[1] - ema[lookback];
   double minMove = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20;
   if(dirSign == 1)  return (delta > minMove);
   if(dirSign == -1) return (delta < -minMove);
   return false;
}

bool SMCSP_IsTouchBar(const int dirSign, const int barIdx, const double emaVal, const double tol)
{
   double hi = iHigh(_Symbol, PERIOD_M5, barIdx);
   double lo = iLow(_Symbol, PERIOD_M5, barIdx);
   double cl = iClose(_Symbol, PERIOD_M5, barIdx);
   if(hi <= 0 || lo <= 0) return false;

   if(dirSign == 1)
      return (lo <= emaVal + tol && cl >= emaVal - tol * 0.25);
   return (hi >= emaVal - tol && cl <= emaVal + tol * 0.25);
}

bool SMCSP_TrendBodiesOK(const int dirSign, const int minBodies, const int lookback = 8)
{
   int cnt = 0;
   for(int i = 1; i <= lookback; i++)
   {
      double o = iOpen(_Symbol, PERIOD_M5, i);
      double c = iClose(_Symbol, PERIOD_M5, i);
      if(dirSign == 1 && c > o) cnt++;
      if(dirSign == -1 && c < o) cnt++;
   }
   return (cnt >= minBodies);
}

void SMCSP_ClearProjection()
{
   ObjectsDeleteAll(0, "STAIR_PROJ_");
   ObjectDelete(0, "STAIR_LBL");
}

void SMCSP_DrawProjection(const int dirSign, const double emaNow, const double impulseAmp, const int steps)
{
   if(!EMAStairDrawProjection || steps < 1 || impulseAmp <= 0) return;

   SMCSP_ClearProjection();

   datetime t0 = iTime(_Symbol, PERIOD_M5, 0);
   if(t0 <= 0) t0 = TimeCurrent();
   int barSec = PeriodSeconds(PERIOD_M5);
   double p = (dirSign == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(p <= 0) p = iClose(_Symbol, PERIOD_M5, 0);

   color clr = (dirSign == 1) ? clrGold : clrOrangeRed;
   datetime ta = t0;
   double pa = p;

   for(int s = 0; s < steps; s++)
   {
      datetime tb = ta + (datetime)(barSec * 3);
      datetime tc = tb + (datetime)barSec;
      double pb = (dirSign == 1) ? pa + impulseAmp : pa - impulseAmp;
      double pc = emaNow;

      string segImp = "STAIR_PROJ_IMP_" + IntegerToString(s);
      ObjectDelete(0, segImp);
      ObjectCreate(0, segImp, OBJ_TREND, 0, ta, pa, tb, pb);
      ObjectSetInteger(0, segImp, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, segImp, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, segImp, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, segImp, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, segImp, OBJPROP_SELECTABLE, false);

      string segPb = "STAIR_PROJ_PB_" + IntegerToString(s);
      ObjectDelete(0, segPb);
      ObjectCreate(0, segPb, OBJ_TREND, 0, tb, pb, tc, pc);
      ObjectSetInteger(0, segPb, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, segPb, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, segPb, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, segPb, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, segPb, OBJPROP_SELECTABLE, false);

      ta = tc;
      pa = pc;
   }

   string lbl = "STAIR_LBL";
   ObjectDelete(0, lbl);
   ObjectCreate(0, lbl, OBJ_TEXT, 0, ta, pa);
   string dirTxt = (dirSign == 1) ? "HAUSSIER" : "BAISSIER";
   ObjectSetString(0, lbl, OBJPROP_TEXT, "STAIR " + dirTxt + " | touches=" + IntegerToString(g_stairPattern.touchCount));
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, lbl, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, lbl, OBJPROP_ANCHOR, (dirSign == 1) ? ANCHOR_LEFT_LOWER : ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);
   ChartRedraw(0);
}

void SMCSP_AlertPattern(const string msg)
{
   Print("[EMA-STAIR] ", msg);
   if(EMAStairAlertOnForm)
   {
      Alert(msg);
      PB_SendWhatsAppAlert(msg);
   }
}

double SMCSP_MeasureImpulse(const int dirSign, const int touchBar, const double emaAtTouch)
{
   int peakBar = touchBar + 1;
   double extreme = (dirSign == 1) ? iHigh(_Symbol, PERIOD_M5, peakBar) : iLow(_Symbol, PERIOD_M5, peakBar);
   if(extreme <= 0) return 0.0;
   return (dirSign == 1) ? MathMax(0.0, extreme - emaAtTouch) : MathMax(0.0, emaAtTouch - extreme);
}

void SMCSP_Reset()
{
   g_stairPattern.active = false;
   g_stairPattern.forming = false;
   g_stairPattern.bullish = false;
   g_stairPattern.touchCount = 0;
   g_stairPattern.dirSign = 0;
   SMCSP_ClearProjection();
}

bool SMCSP_IsNewM5Bar()
{
   static datetime s_last = 0;
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   if(t <= 0 || t == s_last) return false;
   s_last = t;
   return true;
}

void SMCSP_UpdatePattern(const int emaHandle)
{
   if(!UseEMAStairPattern) return;

   double ema[];
   if(!SMCSP_CopyM5EMA(emaHandle, 25, ema)) return;

   double atrM5 = SMCSP_GetM5ATR(_Symbol);
   double tol = MathMax(atrM5 * EMAStairTouchTolATR, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 15);

   int bullTouches = 0, bearTouches = 0;
   double bullImpSum = 0.0, bearImpSum = 0.0;

   for(int b = 1; b <= 12; b++)
   {
      if(SMCSP_IsTouchBar(1, b, ema[b], tol))
      {
         bullTouches++;
         bullImpSum += SMCSP_MeasureImpulse(1, b, ema[b]);
      }
      if(SMCSP_IsTouchBar(-1, b, ema[b], tol))
      {
         bearTouches++;
         bearImpSum += SMCSP_MeasureImpulse(-1, b, ema[b]);
      }
   }

   int dirSign = 0;
   if(bullTouches >= bearTouches && bullTouches >= 1
      && SMCSP_EMASlopeOK(1, ema) && SMCSP_TrendBodiesOK(1, EMAStairFormBars))
      dirSign = 1;
   else if(bearTouches > bullTouches && bearTouches >= 1
           && SMCSP_EMASlopeOK(-1, ema) && SMCSP_TrendBodiesOK(-1, EMAStairFormBars))
      dirSign = -1;

   if(dirSign == 0)
   {
      if(g_stairPattern.active && g_stairPattern.touchCount > 0)
      {
         static datetime s_invalLog = 0;
         if(TimeCurrent() - s_invalLog >= 120)
         {
            s_invalLog = TimeCurrent();
            Print("[EMA-STAIR] Pattern invalidé — pente EMA / structure");
         }
      }
      SMCSP_Reset();
      return;
   }

   int touches = (dirSign == 1) ? bullTouches : bearTouches;
   double impAvg = (dirSign == 1)
      ? ((bullTouches > 0) ? bullImpSum / bullTouches : atrM5)
      : ((bearTouches > 0) ? bearImpSum / bearTouches : atrM5);
   if(impAvg <= 0) impAvg = atrM5;
   if(impAvg <= 0) impAvg = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50;

   bool wasActive = g_stairPattern.active;
   bool wasForming = g_stairPattern.forming;

   g_stairPattern.dirSign = dirSign;
   g_stairPattern.bullish = (dirSign == 1);
   g_stairPattern.touchCount = touches;
   g_stairPattern.lastEma = ema[1];
   g_stairPattern.avgImpulse = impAvg;
   g_stairPattern.forming = (touches >= 1 && touches < EMAStairMinSteps);
   g_stairPattern.active = (touches >= EMAStairMinSteps);

   datetime bar1 = iTime(_Symbol, PERIOD_M5, 1);
   if(bar1 > 0 && SMCSP_IsTouchBar(dirSign, 1, ema[1], tol))
   {
      g_stairPattern.lastTouchBar = bar1;
      g_stairPattern.lastTouchPrice = ema[1];
   }

   if(g_stairPattern.forming && !wasForming && TimeCurrent() - g_stairPattern.lastAlertTime >= 300)
   {
      g_stairPattern.lastAlertTime = TimeCurrent();
      string msg = StringFormat("STAIR %s en formation — %d touche(s) EMA M5 | %s",
                                (dirSign == 1 ? "HAUSSIER" : "BAISSIER"),
                                touches, _Symbol);
      SMCSP_AlertPattern(msg);
   }

   if(g_stairPattern.active && (!wasActive || !wasForming))
   {
      if(TimeCurrent() - g_stairPattern.lastAlertTime >= 60)
      {
         g_stairPattern.lastAlertTime = TimeCurrent();
         string msg = StringFormat("STAIR %s ACTIF — entrées sur touche EMA M5 | %s",
                                   (dirSign == 1 ? "HAUSSIER" : "BAISSIER"), _Symbol);
         SMCSP_AlertPattern(msg);
      }
      SMCSP_DrawProjection(dirSign, ema[1], impAvg, EMAStairProjSteps);
   }
   else if(g_stairPattern.active)
   {
      SMCSP_DrawProjection(dirSign, ema[1], impAvg, EMAStairProjSteps);
   }
}

bool SMCSP_IsTouchEntryNow(const int dirSign, const int emaHandle)
{
   if(dirSign == 0 || !g_stairPattern.active) return false;

   double ema[];
   if(!SMCSP_CopyM5EMA(emaHandle, 3, ema)) return false;

   double atrM5 = SMCSP_GetM5ATR(_Symbol);
   double tol = MathMax(atrM5 * EMAStairTouchTolATR, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 15);

   if(SMCSP_IsTouchBar(dirSign, 1, ema[1], tol))
   {
      datetime bar1 = iTime(_Symbol, PERIOD_M5, 1);
      if(bar1 > 0 && bar1 != g_stairPattern.lastTouchBar)
         return true;
   }

   double ema0 = ema[0];
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return false;

   if(dirSign == 1)
   {
      double lo0 = iLow(_Symbol, PERIOD_M5, 0);
      return (lo0 <= ema0 + tol && bid >= ema0 - tol * 0.25);
   }
   double hi0 = iHigh(_Symbol, PERIOD_M5, 0);
   return (hi0 >= ema0 - tol && ask <= ema0 + tol * 0.25);
}

void ManageEMAStairPattern()
{
   if(!UseEMAStairPattern || BlockAllTrades) return;

   int emaHandle = emaStairM5;
   if(emaHandle == INVALID_HANDLE) emaHandle = emaFastM5;
   if(emaHandle == INVALID_HANDLE) emaHandle = emaSlowM5;
   if(emaHandle == INVALID_HANDLE) return;

   if(SMCSP_IsNewM5Bar())
      SMCSP_UpdatePattern(emaHandle);

   if(!g_stairPattern.active || !EMAStairAutoTrade) return;

   int dirSign = g_stairPattern.dirSign;
   if(TimeCurrent() - g_stairPattern.lastEntryTime < EMAStairCooldownSec) return;
   if(!SMCSP_IsTouchEntryNow(dirSign, emaHandle)) return;

   string direction = (dirSign == 1) ? "BUY" : "SELL";
   bool executed = false;
   if(EMAStairUseAlignGate)
      executed = SMC_ExecuteAlignMarketIfOK(dirSign, direction, "EMA_STAIR_TOUCH");
   else
      executed = PlaceGOMMarketOrder(direction, "GOM_STAIR", "EMA_STAIR_TOUCH");

   if(executed)
   {
      g_stairPattern.lastEntryTime = TimeCurrent();
      datetime bar1 = iTime(_Symbol, PERIOD_M5, 1);
      if(bar1 > 0) g_stairPattern.lastTouchBar = bar1;
      Print("[EMA-STAIR] Entrée ", direction, " sur touche EMA M5 | ", _Symbol,
            " | touches=", g_stairPattern.touchCount);
   }
}

#endif
