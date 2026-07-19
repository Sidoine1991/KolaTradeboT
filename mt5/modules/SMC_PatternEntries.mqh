//+------------------------------------------------------------------+
//| SMC_PatternEntries.mqh — Patterns M1/M5/H1 + entrée GOM alignée   |
//| Candlestick + OB/Demand/Fib50/DoubleBottom/Liquidity sweep        |
//+------------------------------------------------------------------+
#ifndef SMC_PATTERN_ENTRIES_MQH
#define SMC_PATTERN_ENTRIES_MQH

struct SMCPE_PatternHit
{
   int              dir;
   string           patternId;
   string           patternLabel;
   ENUM_TIMEFRAMES  tf;
   int              tfCount;
   double           triggerPrice;
};

bool SMCPE_IsBullCandle(const MqlRates &c)
{
   return (c.close > c.open);
}

bool SMCPE_IsBearCandle(const MqlRates &c)
{
   return (c.close < c.open);
}

double SMCPE_Body(const MqlRates &c)
{
   return MathAbs(c.close - c.open);
}

double SMCPE_Range(const MqlRates &c)
{
   return MathMax(c.high - c.low, SymbolInfoDouble(_Symbol, SYMBOL_POINT));
}

bool SMCPE_ThreeSoldiers(const MqlRates &r[], int dir)
{
   if(dir == 1)
   {
      if(!SMCPE_IsBullCandle(r[1]) || !SMCPE_IsBullCandle(r[2]) || !SMCPE_IsBullCandle(r[3]))
         return false;
      return (r[1].close > r[2].close && r[2].close > r[3].close
              && SMCPE_Body(r[1]) > SMCPE_Range(r[1]) * 0.35);
   }
   if(!SMCPE_IsBearCandle(r[1]) || !SMCPE_IsBearCandle(r[2]) || !SMCPE_IsBearCandle(r[3]))
      return false;
   return (r[1].close < r[2].close && r[2].close < r[3].close
           && SMCPE_Body(r[1]) > SMCPE_Range(r[1]) * 0.35);
}

bool SMCPE_Engulfing(const MqlRates &r[], int dir)
{
   if(dir == 1)
   {
      if(!SMCPE_IsBullCandle(r[1]) || !SMCPE_IsBearCandle(r[2])) return false;
      return (r[1].close >= r[2].open && r[1].open <= r[2].close
              && SMCPE_Body(r[1]) > SMCPE_Body(r[2]) * 1.05);
   }
   if(!SMCPE_IsBearCandle(r[1]) || !SMCPE_IsBullCandle(r[2])) return false;
   return (r[1].close <= r[2].open && r[1].open >= r[2].close
           && SMCPE_Body(r[1]) > SMCPE_Body(r[2]) * 1.05);
}

bool SMCPE_MorningEveningStar(const MqlRates &r[], int dir)
{
   if(dir == 1)
   {
      if(!SMCPE_IsBearCandle(r[3]) || !SMCPE_IsBullCandle(r[1])) return false;
      double mid3 = (r[3].open + r[3].close) * 0.5;
      if(SMCPE_Body(r[2]) > SMCPE_Range(r[2]) * 0.55) return false;
      return (r[1].close > mid3);
   }
   if(!SMCPE_IsBullCandle(r[3]) || !SMCPE_IsBearCandle(r[1])) return false;
   double mid3 = (r[3].open + r[3].close) * 0.5;
   if(SMCPE_Body(r[2]) > SMCPE_Range(r[2]) * 0.55) return false;
   return (r[1].close < mid3);
}

bool SMCPE_Tweezer(const MqlRates &r[], int dir)
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol = pt * 15;
   if(dir == 1)
   {
      if(!SMCPE_IsBullCandle(r[1]) || !SMCPE_IsBearCandle(r[2])) return false;
      return (MathAbs(r[1].low - r[2].low) <= tol);
   }
   if(!SMCPE_IsBearCandle(r[1]) || !SMCPE_IsBullCandle(r[2])) return false;
   return (MathAbs(r[1].high - r[2].high) <= tol);
}

bool SMCPE_ComputeOBZone(const string sym, ENUM_TIMEFRAMES tf,
                         double &bullTop, double &bullBot,
                         double &bearTop, double &bearBot)
{
   bullTop = bullBot = bearTop = bearBot = 0;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int need = 55;
   if(CopyRates(sym, tf, 1, need, rates) < need) return false;
   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   double minMove = pt * 20;

   for(int i = 3; i < need - 4; i++)
   {
      if(rates[i].close < rates[i].open && rates[i + 1].close > rates[i + 1].open)
      {
         double moveUp = rates[i + 2].high - rates[i].low;
         if(moveUp > minMove)
         {
            bullTop = rates[i].high;
            bullBot = rates[i].low;
         }
      }
      if(rates[i].close > rates[i].open && rates[i + 1].close < rates[i + 1].open)
      {
         double moveDn = rates[i].high - rates[i + 2].low;
         if(moveDn > minMove)
         {
            bearTop = rates[i].high;
            bearBot = rates[i].low;
         }
      }
   }
   return (bullTop > bullBot && bullTop > 0) || (bearTop > bearBot && bearTop > 0);
}

bool SMCPE_OrderBlockRetest(const MqlRates &r[], int dir, ENUM_TIMEFRAMES tf)
{
   double bTop, bBot, sTop, sBot;
   if(!SMCPE_ComputeOBZone(_Symbol, tf, bTop, bBot, sTop, sBot)) return false;
   double px = (dir == 1) ? r[1].close : r[1].close;

   if(dir == 1 && bTop > bBot)
   {
      if(px < bBot || px > bTop) return false;
      double lowerWick = MathMin(r[1].open, r[1].close) - r[1].low;
      return (lowerWick >= SMCPE_Range(r[1]) * 0.35 && SMCPE_IsBullCandle(r[1]));
   }
   if(dir == -1 && sTop > sBot)
   {
      if(px < sBot || px > sTop) return false;
      double upperWick = r[1].high - MathMax(r[1].open, r[1].close);
      return (upperWick >= SMCPE_Range(r[1]) * 0.35 && SMCPE_IsBearCandle(r[1]));
   }
   return false;
}

bool SMCPE_DemandSupplyFlip(const MqlRates &r[], int dir, ENUM_TIMEFRAMES tf)
{
   int look = 30;
   if(ArraySize(r) < look + 2) return false;
   if(dir == 1)
   {
      int hiIdx = iHighest(_Symbol, tf, MODE_HIGH, look, 2);
      if(hiIdx < 0) return false;
      double res = r[hiIdx];
      if(r[1].close <= res) return false;
      double tol = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 25;
      return (r[1].low <= res + tol && r[1].close > res && SMCPE_IsBullCandle(r[1]));
   }
   int loIdx = iLowest(_Symbol, tf, MODE_LOW, look, 2);
   if(loIdx < 0) return false;
   double sup = r[loIdx];
   if(r[1].close >= sup) return false;
   double tol = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 25;
   return (r[1].high >= sup - tol && r[1].close < sup && SMCPE_IsBearCandle(r[1]));
}

bool SMCPE_Fib50OB(const MqlRates &r[], int dir, ENUM_TIMEFRAMES tf)
{
   int look = 40;
   if(ArraySize(r) < look + 2) return false;
   int hi = iHighest(_Symbol, tf, MODE_HIGH, look, 2);
   int lo = iLowest(_Symbol, tf, MODE_LOW, look, 2);
   if(hi < 0 || lo < 0) return false;
   double swingH = r[hi], swingL = r[lo];
   if(swingH <= swingL) return false;
   double fib50 = swingL + (swingH - swingL) * 0.5;
   double tol = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 30;
   if(MathAbs(r[1].close - fib50) > tol) return false;

   double bTop, bBot, sTop, sBot;
   SMCPE_ComputeOBZone(_Symbol, tf, bTop, bBot, sTop, sBot);
   if(dir == 1 && bTop > bBot)
      return (fib50 >= bBot - tol && fib50 <= bTop + tol);
   if(dir == -1 && sTop > sBot)
      return (fib50 >= sBot - tol && fib50 <= sTop + tol);
   return (MathAbs(r[1].close - fib50) <= tol);
}

bool SMCPE_DoubleBottomTopRetest(const MqlRates &r[], int dir, ENUM_TIMEFRAMES tf)
{
   int look = 25;
   if(ArraySize(r) < look + 2) return false;
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tol = pt * 20;

   if(dir == 1)
   {
      int l1 = -1, l2 = -1;
      for(int i = 2; i < look; i++)
      {
         if(i + 1 >= look) break;
         bool isLow = (r[i].low <= r[i + 1].low && r[i].low <= r[i - 1].low);
         if(!isLow) continue;
         if(l1 < 0) l1 = i;
         else if(l2 < 0 && MathAbs(r[i].low - r[l1].low) <= tol) l2 = i;
      }
      if(l1 < 0 || l2 < 0) return false;
      int a = MathMin(l1, l2), b = MathMax(l1, l2);
      double neck = r[a].high;
      for(int j = a; j <= b; j++)
         if(r[j].high > neck) neck = r[j].high;
      return (r[1].low <= neck + tol && r[1].close > neck && SMCPE_IsBullCandle(r[1]));
   }

   int h1 = -1, h2 = -1;
   for(int i = 2; i < look; i++)
   {
      if(i + 1 >= look) break;
      bool isHigh = (r[i].high >= r[i + 1].high && r[i].high >= r[i - 1].high);
      if(!isHigh) continue;
      if(h1 < 0) h1 = i;
      else if(h2 < 0 && MathAbs(r[i].high - r[h1].high) <= tol) h2 = i;
   }
   if(h1 < 0 || h2 < 0) return false;
   int a2 = MathMin(h1, h2), b2 = MathMax(h1, h2);
   double neck2 = r[a2].low;
   for(int j2 = a2; j2 <= b2; j2++)
      if(r[j2].low < neck2) neck2 = r[j2].low;
   return (r[1].high >= neck2 - tol && r[1].close < neck2 && SMCPE_IsBearCandle(r[1]));
}

bool SMCPE_LiquiditySweep(const MqlRates &r[], int dir, ENUM_TIMEFRAMES tf)
{
   int look = 20;
   if(ArraySize(r) < look + 2) return false;
   if(dir == 1)
   {
      int li = iLowest(_Symbol, tf, MODE_LOW, look, 2);
      if(li < 0) return false;
      double liq = r[li];
      return (r[1].low < liq && r[1].close > liq && SMCPE_IsBullCandle(r[1]));
   }
   int hi = iHighest(_Symbol, tf, MODE_HIGH, look, 2);
   if(hi < 0) return false;
   double liqH = r[hi];
   return (r[1].high > liqH && r[1].close < liqH && SMCPE_IsBearCandle(r[1]));
}

bool SMCPE_TrendBreakRetest(const MqlRates &r[], int dir, ENUM_TIMEFRAMES tf)
{
   if(ArraySize(r) < 25) return false;
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
   int n = 15;
   for(int i = 2; i < 2 + n; i++)
   {
      double x = (double)i;
      double y = r[i].close;
      sumX += x; sumY += y; sumXY += x * y; sumX2 += x * x;
   }
   double denom = n * sumX2 - sumX * sumX;
   if(MathAbs(denom) < 1e-12) return false;
   double slope = (n * sumXY - sumX * sumY) / denom;
   double intercept = (sumY - slope * sumX) / n;
   double trendNow = intercept + slope * 2.0;
   double tol = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 20;

   if(dir == 1)
   {
      if(slope >= 0) return false;
      return (r[2].close < trendNow && r[1].close > trendNow - tol && SMCPE_IsBullCandle(r[1]));
   }
   if(slope <= 0) return false;
   return (r[2].close > trendNow && r[1].close < trendNow + tol && SMCPE_IsBearCandle(r[1]));
}

bool SMCPE_ScanOneTF(const string sym, ENUM_TIMEFRAMES tf, int wantDir, SMCPE_PatternHit &hit)
{
   hit.dir = 0;
   hit.patternId = "";
   hit.patternLabel = "";
   hit.tf = tf;
   hit.tfCount = 0;
   hit.triggerPrice = 0;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(sym, tf, 1, 60, r) < 10) return false;

   string ids[];
   string labels[];
   ArrayResize(ids, 10);
   ArrayResize(labels, 10);
   int n = 0;

   if(SMCPE_ThreeSoldiers(r, wantDir))           { ids[n] = "THREE_SOLDIERS"; labels[n] = "Three Soldiers"; n++; }
   if(SMCPE_Engulfing(r, wantDir))               { ids[n] = "ENGULFING"; labels[n] = "Engulfing"; n++; }
   if(SMCPE_MorningEveningStar(r, wantDir))      { ids[n] = "STAR"; labels[n] = (wantDir==1?"Morning Star":"Evening Star"); n++; }
   if(SMCPE_Tweezer(r, wantDir))                 { ids[n] = "TWEEZER"; labels[n] = "Tweezer"; n++; }
   if(SMCPE_OrderBlockRetest(r, wantDir, tf))     { ids[n] = "OB_RETEST"; labels[n] = "OB Retest"; n++; }
   if(SMCPE_DemandSupplyFlip(r, wantDir, tf))    { ids[n] = "SR_FLIP"; labels[n] = (wantDir==1?"Demand Flip":"Supply Flip"); n++; }
   if(SMCPE_Fib50OB(r, wantDir, tf))             { ids[n] = "FIB50_OB"; labels[n] = "Fib 50% OB"; n++; }
   if(SMCPE_DoubleBottomTopRetest(r, wantDir, tf)){ ids[n] = "DBL_RETEST"; labels[n] = "Double Retest"; n++; }
   if(SMCPE_LiquiditySweep(r, wantDir, tf))      { ids[n] = "LIQ_SWEEP"; labels[n] = "Liquidity Sweep"; n++; }
   if(SMCPE_TrendBreakRetest(r, wantDir, tf))    { ids[n] = "TL_BREAK"; labels[n] = "Trend Break Retest"; n++; }

   if(n <= 0) return false;
   hit.dir = wantDir;
   hit.patternId = ids[0];
   hit.patternLabel = labels[0];
   hit.tf = tf;
   hit.tfCount = 1;
   hit.triggerPrice = r[1].close;
   return true;
}

bool SMCPE_GetConfluence(const string sym, int wantDir, SMCPE_PatternHit &out)
{
   ENUM_TIMEFRAMES tfs[3] = {PERIOD_M1, PERIOD_M5, PERIOD_H1};
   string tfNames[3] = {"M1", "M5", "H1"};
   int hits = 0;
   string bestId = "";
   string bestLbl = "";
   ENUM_TIMEFRAMES bestTf = PERIOD_M1;
   double trigger = 0;

   for(int i = 0; i < 3; i++)
   {
      SMCPE_PatternHit h;
      if(!SMCPE_ScanOneTF(sym, tfs[i], wantDir, h)) continue;
      hits++;
      if(bestId == "" || tfs[i] == PERIOD_H1)
      {
         bestId = h.patternId;
         bestLbl = h.patternLabel + "@" + tfNames[i];
         bestTf = tfs[i];
         trigger = h.triggerPrice;
      }
   }

   if(hits < MathMax(1, MathMin(3, PatternMinTFCount))) return false;
   out.dir = wantDir;
   out.patternId = bestId;
   out.patternLabel = bestLbl;
   out.tf = bestTf;
   out.tfCount = hits;
   out.triggerPrice = trigger;
   return true;
}

bool SMCPE_AlignmentOK(const int dirSign)
{
   if(dirSign == 0) return false;
   if(!g_smcGomConnected) return false;
   if(SMCGP_CorrectionBlocksEntry(SMCGP_IsBoomCrashSym(_Symbol))) return false;
   if(SMC_IsCorrectionZoneForDirection(_Symbol, dirSign)) return false;
   if(PatternRequireGOMGood && !SMCGP_IsGoodPerfect(g_smcGomVerdictNum)) return false;
   if(!PatternRequireGOMGood && MathAbs(g_smcGomVerdictNum) < 1) return false;
   if(dirSign == 1 && g_smcGomVerdictNum <= 0) return false;
   if(dirSign == -1 && g_smcGomVerdictNum >= 0) return false;
   if(!GOM_EntryAlignmentOK(dirSign)) return false;
   return true;
}

void SMCPE_ManagePatternEntries()
{
   if(!UsePatternEntryStrategy || BlockAllTrades) return;
   if(!UseGOMVerdictFilter) return;

   static datetime s_lastEntry = 0;
   if(TimeCurrent() - s_lastEntry < PatternEntryCooldownSec) return;

   int gomDir = 0;
   if(g_smcGomVerdictNum > 0) gomDir = 1;
   else if(g_smcGomVerdictNum < 0) gomDir = -1;
   if(gomDir == 0) return;
   if(!SMCPE_AlignmentOK(gomDir)) return;

   SMCPE_PatternHit hit;
   if(!SMCPE_GetConfluence(_Symbol, gomDir, hit)) return;

   string direction = (gomDir == 1) ? "BUY" : "SELL";
   string tag = "PAT_" + hit.patternId;
   string src = hit.patternLabel + "_x" + IntegerToString(hit.tfCount);

   if(!GOM_CanOpenNewTrade(gomDir)) return;
   if(!CanOpenAdditionalPositionForSymbol(_Symbol, direction)) return;

   if(PlaceGOMMarketOrder(direction, tag, src))
   {
      s_lastEntry = TimeCurrent();
      Print("[PATTERN-ENTRY] ", hit.patternLabel, " | TFhits=", hit.tfCount,
            " | GOM=", g_smcGomVerdict, " | IA=", g_smcIAStatusAction,
            " | COG=", g_cogDirection5m);
   }
}

#endif // SMC_PATTERN_ENTRIES_MQH
