//+------------------------------------------------------------------+
//| SMC_PatternSignals.mqh — Stratégies d'entrée M1/M5/H1            |
//| Chandeliers + SMC (OB, Demand, FVG, Fib50, trendline retest)     |
//+------------------------------------------------------------------+
#ifndef SMC_PATTERN_SIGNALS_MQH
#define SMC_PATTERN_SIGNALS_MQH

#define SMCPS_MAX_PATTERNS 48

// Définition unique (inclus une seule fois via guard). Partagée avec SMC_Universal.mq5.
bool   g_sr20BounceArmedBuy  = false;
bool   g_sr20BounceArmedSell = false;
int    g_sr20BounceBuyBars   = 0;
int    g_sr20BounceSellBars  = 0;

enum SMC_PATTERN_ID
{
   PAT_NONE = 0,
   PAT_BULL_ENGULFING,
   PAT_BEAR_ENGULFING,
   PAT_MORNING_STAR,
   PAT_EVENING_STAR,
   PAT_THREE_SOLDIERS,
   PAT_THREE_CROWS,
   PAT_TWEEZER_BOTTOM,
   PAT_TWEEZER_TOP,
   PAT_OB_RETEST,
   PAT_DEMAND_FLIP,
   PAT_SUPPLY_FLIP,
   PAT_FVG_DEMAND,
   PAT_FVG_SUPPLY,
   PAT_DOUBLE_BOTTOM,
   PAT_DOUBLE_TOP,
   PAT_TRENDLINE_RETEST,
   PAT_FIB50_OB,
   PAT_ZONE_REJECTION
};

struct SMCPS_Hit
{
   int              id;
   int              dirSign;
   ENUM_TIMEFRAMES  tf;
   datetime         barTime;
   double           entryLevel;
   string           name;
};

struct SMCPS_State
{
   SMCPS_Hit hits[SMCPS_MAX_PATTERNS];
   int       hitCount;
   int       bullScore;
   int       bearScore;
   string    bestName;
   int       bestDir;
   ENUM_TIMEFRAMES bestTf;
   datetime  lastScan;
   string    summary;
};

SMCPS_State g_smcps = { {}, 0, 0, 0, "", 0, PERIOD_CURRENT, 0, "" };

double SMCPS_ATR(const string symbol, const ENUM_TIMEFRAMES tf, const int period = 14)
{
   int h = iATR(symbol, tf, period);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h, 0, 0, 1, buf) < 1) { IndicatorRelease(h); return 0.0; }
   IndicatorRelease(h);
   return buf[0];
}

double SMCPS_Body(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
{
   return MathAbs(iClose(symbol, tf, shift) - iOpen(symbol, tf, shift));
}

bool SMCPS_IsBull(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
{
   return iClose(symbol, tf, shift) > iOpen(symbol, tf, shift);
}

bool SMCPS_IsBear(const string symbol, const ENUM_TIMEFRAMES tf, const int shift)
{
   return iClose(symbol, tf, shift) < iOpen(symbol, tf, shift);
}

void SMCPS_AddHit(const int id, const int dirSign, const ENUM_TIMEFRAMES tf,
                  const datetime barTime, const double entryLevel, const string name)
{
   if(g_smcps.hitCount >= SMCPS_MAX_PATTERNS) return;
   int i = g_smcps.hitCount++;
   g_smcps.hits[i].id = id;
   g_smcps.hits[i].dirSign = dirSign;
   g_smcps.hits[i].tf = tf;
   g_smcps.hits[i].barTime = barTime;
   g_smcps.hits[i].entryLevel = entryLevel;
   g_smcps.hits[i].name = name;
   if(dirSign > 0) g_smcps.bullScore++;
   else if(dirSign < 0) g_smcps.bearScore++;
}

bool SMCPS_BullishEngulfing(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!SMCPS_IsBear(symbol, tf, 2) || !SMCPS_IsBull(symbol, tf, 1)) return false;
   double o2 = iOpen(symbol, tf, 2), c2 = iClose(symbol, tf, 2);
   double o1 = iOpen(symbol, tf, 1), c1 = iClose(symbol, tf, 1);
   if(c1 <= o2 || o1 >= c2) return false;
   if(SMCPS_Body(symbol, tf, 1) < SMCPS_Body(symbol, tf, 2) * 0.8) return false;
   return true;
}

bool SMCPS_BearishEngulfing(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!SMCPS_IsBull(symbol, tf, 2) || !SMCPS_IsBear(symbol, tf, 1)) return false;
   double o2 = iOpen(symbol, tf, 2), c2 = iClose(symbol, tf, 2);
   double o1 = iOpen(symbol, tf, 1), c1 = iClose(symbol, tf, 1);
   if(c1 >= o2 || o1 <= c2) return false;
   if(SMCPS_Body(symbol, tf, 1) < SMCPS_Body(symbol, tf, 2) * 0.8) return false;
   return true;
}

bool SMCPS_MorningStar(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!SMCPS_IsBear(symbol, tf, 3)) return false;
   double b3 = SMCPS_Body(symbol, tf, 3);
   double b2 = SMCPS_Body(symbol, tf, 2);
   if(b3 <= 0 || b2 > b3 * 0.45) return false;
   if(!SMCPS_IsBull(symbol, tf, 1)) return false;
   double mid3 = (iOpen(symbol, tf, 3) + iClose(symbol, tf, 3)) * 0.5;
   return iClose(symbol, tf, 1) > mid3;
}

bool SMCPS_EveningStar(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!SMCPS_IsBull(symbol, tf, 3)) return false;
   double b3 = SMCPS_Body(symbol, tf, 3);
   double b2 = SMCPS_Body(symbol, tf, 2);
   if(b3 <= 0 || b2 > b3 * 0.45) return false;
   if(!SMCPS_IsBear(symbol, tf, 1)) return false;
   double mid3 = (iOpen(symbol, tf, 3) + iClose(symbol, tf, 3)) * 0.5;
   return iClose(symbol, tf, 1) < mid3;
}

bool SMCPS_ThreeSoldiers(const string symbol, const ENUM_TIMEFRAMES tf)
{
   for(int s = 1; s <= 3; s++)
      if(!SMCPS_IsBull(symbol, tf, s)) return false;
   if(iClose(symbol, tf, 1) <= iClose(symbol, tf, 2)) return false;
   if(iClose(symbol, tf, 2) <= iClose(symbol, tf, 3)) return false;
   double atr = SMCPS_ATR(symbol, tf);
   if(atr > 0 && SMCPS_Body(symbol, tf, 1) < atr * 0.15) return false;
   return true;
}

bool SMCPS_ThreeCrows(const string symbol, const ENUM_TIMEFRAMES tf)
{
   for(int s = 1; s <= 3; s++)
      if(!SMCPS_IsBear(symbol, tf, s)) return false;
   if(iClose(symbol, tf, 1) >= iClose(symbol, tf, 2)) return false;
   if(iClose(symbol, tf, 2) >= iClose(symbol, tf, 3)) return false;
   return true;
}

bool SMCPS_TweezerBottom(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!SMCPS_IsBear(symbol, tf, 2) || !SMCPS_IsBull(symbol, tf, 1)) return false;
   double l1 = iLow(symbol, tf, 1), l2 = iLow(symbol, tf, 2);
   double tol = SMCPS_ATR(symbol, tf) * 0.08;
   if(tol <= 0) tol = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
   return MathAbs(l1 - l2) <= tol;
}

bool SMCPS_TweezerTop(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!SMCPS_IsBull(symbol, tf, 2) || !SMCPS_IsBear(symbol, tf, 1)) return false;
   double h1 = iHigh(symbol, tf, 1), h2 = iHigh(symbol, tf, 2);
   double tol = SMCPS_ATR(symbol, tf) * 0.08;
   if(tol <= 0) tol = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10;
   return MathAbs(h1 - h2) <= tol;
}

bool SMCPS_BullFVG(const string symbol, const ENUM_TIMEFRAMES tf)
{
   double hi3 = iHigh(symbol, tf, 3);
   double lo1 = iLow(symbol, tf, 1);
   return lo1 > hi3;
}

bool SMCPS_BearFVG(const string symbol, const ENUM_TIMEFRAMES tf)
{
   double lo3 = iLow(symbol, tf, 3);
   double hi1 = iHigh(symbol, tf, 1);
   return hi1 < lo3;
}

bool SMCPS_DoubleBottom(const string symbol, const ENUM_TIMEFRAMES tf)
{
   double lows[20];
   int n = 0;
   for(int i = 2; i < 22 && n < 20; i++)
   {
      double l = iLow(symbol, tf, i);
      double lL = iLow(symbol, tf, i + 1);
      double lR = iLow(symbol, tf, i - 1);
      if(l <= lL && l <= lR) { lows[n++] = l; if(n >= 2) break; }
   }
   if(n < 2) return false;
   double tol = SMCPS_ATR(symbol, tf) * 0.12;
   if(tol <= 0) tol = SymbolInfoDouble(symbol, SYMBOL_POINT) * 15;
   if(MathAbs(lows[0] - lows[1]) > tol) return false;
   return iClose(symbol, tf, 1) > MathMax(lows[0], lows[1]) + tol * 0.5;
}

bool SMCPS_DoubleTop(const string symbol, const ENUM_TIMEFRAMES tf)
{
   double highs[20];
   int n = 0;
   for(int i = 2; i < 22 && n < 20; i++)
   {
      double h = iHigh(symbol, tf, i);
      double hL = iHigh(symbol, tf, i + 1);
      double hR = iHigh(symbol, tf, i - 1);
      if(h >= hL && h >= hR) { highs[n++] = h; if(n >= 2) break; }
   }
   if(n < 2) return false;
   double tol = SMCPS_ATR(symbol, tf) * 0.12;
   if(tol <= 0) tol = SymbolInfoDouble(symbol, SYMBOL_POINT) * 15;
   if(MathAbs(highs[0] - highs[1]) > tol) return false;
   return iClose(symbol, tf, 1) < MathMin(highs[0], highs[1]) - tol * 0.5;
}

bool SMCPS_TrendlineBreakRetest(const string symbol, const ENUM_TIMEFRAMES tf, const int dirSign)
{
   double highs[3], lows[3];
   int hi = 0, lo = 0;
   for(int i = 2; i < 40; i++)
   {
      double h = iHigh(symbol, tf, i);
      if(h > iHigh(symbol, tf, i + 1) && h > iHigh(symbol, tf, i - 1) && hi < 3)
         highs[hi++] = h;
      double l = iLow(symbol, tf, i);
      if(l < iLow(symbol, tf, i + 1) && l < iLow(symbol, tf, i - 1) && lo < 3)
         lows[lo++] = l;
      if(hi >= 2 && lo >= 2) break;
   }
   if(dirSign > 0 && hi >= 2)
   {
      if(highs[0] >= highs[1]) return false;
      double tl = highs[1] + (highs[0] - highs[1]) * 0.5;
      if(iClose(symbol, tf, 2) <= tl && iClose(symbol, tf, 1) > tl)
         return true;
   }
   if(dirSign < 0 && lo >= 2)
   {
      if(lows[0] <= lows[1]) return false;
      double tl = lows[1] + (lows[0] - lows[1]) * 0.5;
      if(iClose(symbol, tf, 2) >= tl && iClose(symbol, tf, 1) < tl)
         return true;
   }
   return false;
}

bool SMCPS_Fib50Zone(const string symbol, const ENUM_TIMEFRAMES tf, const int dirSign, double &fib50)
{
   double swingHi = 0, swingLo = 0;
   for(int i = 2; i < 30; i++)
   {
      double h = iHigh(symbol, tf, i);
      double l = iLow(symbol, tf, i);
      if(swingHi <= 0 || h > swingHi) swingHi = h;
      if(swingLo <= 0 || l < swingLo) swingLo = l;
   }
   if(swingHi <= swingLo) return false;
   fib50 = swingLo + (swingHi - swingLo) * 0.5;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double tol = SMCPS_ATR(symbol, tf) * 0.25;
   if(tol <= 0) tol = (swingHi - swingLo) * 0.05;
   if(dirSign > 0) return (bid >= fib50 - tol && bid <= fib50 + tol);
   return (bid <= fib50 + tol && bid >= fib50 - tol);
}

bool SMCPS_OBRetest(const string symbol, const ENUM_TIMEFRAMES tf, const int dirSign)
{
   double top = 0, bot = 0;
   if(dirSign > 0) { top = g_smcObBullTop; bot = g_smcObBullBot; }
   else { top = g_smcObBearTop; bot = g_smcObBearBot; }
   if(top <= 0 || bot <= 0) return false;
   double zH = MathMax(top, bot), zL = MathMin(top, bot);
   double lo = iLow(symbol, tf, 1), hi = iHigh(symbol, tf, 1), cl = iClose(symbol, tf, 1);
   double atr = SMCPS_ATR(symbol, tf);
   if(dirSign > 0)
   {
      if(lo > zH + atr * 0.3) return false;
      if(lo < zL - atr * 0.2) return false;
      return (cl > zL && cl > iOpen(symbol, tf, 1));
   }
   if(hi < zL - atr * 0.3) return false;
   if(hi > zH + atr * 0.2) return false;
   return (cl < zH && cl < iOpen(symbol, tf, 1));
}

bool SMCPS_DemandSupplyFlip(const string symbol, const ENUM_TIMEFRAMES tf, const int dirSign)
{
   double res = 0;
   for(int i = 3; i < 25; i++)
   {
      double h = iHigh(symbol, tf, i);
      if(h > iHigh(symbol, tf, i + 1) && h > iHigh(symbol, tf, i - 1))
      { res = h; break; }
   }
   if(res <= 0) return false;
   double tol = SMCPS_ATR(symbol, tf) * 0.2;
   double cl1 = iClose(symbol, tf, 1);
   double lo1 = iLow(symbol, tf, 1);
   double hi1 = iHigh(symbol, tf, 1);
   bool brokeUp = false, brokeDn = false;
   for(int j = 2; j < 12; j++)
   {
      if(iClose(symbol, tf, j) > res + tol) brokeUp = true;
      if(iClose(symbol, tf, j) < res - tol) brokeDn = true;
   }
   if(dirSign > 0 && brokeUp)
      return (lo1 <= res + tol && lo1 >= res - tol * 2 && cl1 > res);
   if(dirSign < 0 && brokeDn)
      return (hi1 >= res - tol && hi1 <= res + tol * 2 && cl1 < res);
   return false;
}

bool SMCPS_ZoneRejection(const string symbol, const ENUM_TIMEFRAMES tf, const int dirSign)
{
   double atr = SMCPS_ATR(symbol, tf);
   if(atr <= 0) return false;
   double o = iOpen(symbol, tf, 1), h = iHigh(symbol, tf, 1);
   double l = iLow(symbol, tf, 1), c = iClose(symbol, tf, 1);
   double body = MathAbs(c - o);
   if(dirSign < 0)
   {
      double upperWick = h - MathMax(o, c);
      return (upperWick > body * 1.2 && c < o && body > atr * 0.25);
   }
   double lowerWick = MathMin(o, c) - l;
   return (lowerWick > body * 1.2 && c > o && body > atr * 0.25);
}

void SMCPS_ScanTF(const string symbol, const ENUM_TIMEFRAMES tf)
{
   datetime bt = iTime(symbol, tf, 1);
   double entry = iHigh(symbol, tf, 1);

   if(SMCPS_BullishEngulfing(symbol, tf))
      SMCPS_AddHit(PAT_BULL_ENGULFING, 1, tf, bt, entry, "Bull Engulf");
   if(SMCPS_BearishEngulfing(symbol, tf))
      SMCPS_AddHit(PAT_BEAR_ENGULFING, -1, tf, bt, iLow(symbol, tf, 1), "Bear Engulf");
   if(SMCPS_MorningStar(symbol, tf))
      SMCPS_AddHit(PAT_MORNING_STAR, 1, tf, bt, entry, "Morning Star");
   if(SMCPS_EveningStar(symbol, tf))
      SMCPS_AddHit(PAT_EVENING_STAR, -1, tf, bt, iLow(symbol, tf, 1), "Evening Star");
   if(SMCPS_ThreeSoldiers(symbol, tf))
      SMCPS_AddHit(PAT_THREE_SOLDIERS, 1, tf, bt, entry, "3 Soldiers");
   if(SMCPS_ThreeCrows(symbol, tf))
      SMCPS_AddHit(PAT_THREE_CROWS, -1, tf, bt, iLow(symbol, tf, 1), "3 Crows");
   if(SMCPS_TweezerBottom(symbol, tf))
      SMCPS_AddHit(PAT_TWEEZER_BOTTOM, 1, tf, bt, entry, "Tweezer Bot");
   if(SMCPS_TweezerTop(symbol, tf))
      SMCPS_AddHit(PAT_TWEEZER_TOP, -1, tf, bt, iLow(symbol, tf, 1), "Tweezer Top");
   if(SMCPS_OBRetest(symbol, tf, 1))
      SMCPS_AddHit(PAT_OB_RETEST, 1, tf, bt, entry, "OB Retest+");
   if(SMCPS_OBRetest(symbol, tf, -1))
      SMCPS_AddHit(PAT_OB_RETEST, -1, tf, bt, iLow(symbol, tf, 1), "OB Retest-");
   if(SMCPS_DemandSupplyFlip(symbol, tf, 1))
      SMCPS_AddHit(PAT_DEMAND_FLIP, 1, tf, bt, entry, "Demand Flip");
   if(SMCPS_DemandSupplyFlip(symbol, tf, -1))
      SMCPS_AddHit(PAT_SUPPLY_FLIP, -1, tf, bt, iLow(symbol, tf, 1), "Supply Flip");
   if(SMCPS_BullFVG(symbol, tf))
      SMCPS_AddHit(PAT_FVG_DEMAND, 1, tf, bt, entry, "FVG Demand");
   if(SMCPS_BearFVG(symbol, tf))
      SMCPS_AddHit(PAT_FVG_SUPPLY, -1, tf, bt, iLow(symbol, tf, 1), "FVG Supply");
   if(SMCPS_DoubleBottom(symbol, tf))
      SMCPS_AddHit(PAT_DOUBLE_BOTTOM, 1, tf, bt, entry, "Double Bottom");
   if(SMCPS_DoubleTop(symbol, tf))
      SMCPS_AddHit(PAT_DOUBLE_TOP, -1, tf, bt, iLow(symbol, tf, 1), "Double Top");
   if(SMCPS_TrendlineBreakRetest(symbol, tf, 1))
      SMCPS_AddHit(PAT_TRENDLINE_RETEST, 1, tf, bt, entry, "TL Retest+");
   if(SMCPS_TrendlineBreakRetest(symbol, tf, -1))
      SMCPS_AddHit(PAT_TRENDLINE_RETEST, -1, tf, bt, iLow(symbol, tf, 1), "TL Retest-");
   double fib50 = 0;
   if(SMCPS_Fib50Zone(symbol, tf, 1, fib50) && SMCPS_OBRetest(symbol, tf, 1))
      SMCPS_AddHit(PAT_FIB50_OB, 1, tf, bt, fib50, "Fib50+OB");
   if(SMCPS_Fib50Zone(symbol, tf, -1, fib50) && SMCPS_OBRetest(symbol, tf, -1))
      SMCPS_AddHit(PAT_FIB50_OB, -1, tf, bt, fib50, "Fib50+OB");
   if(SMCPS_ZoneRejection(symbol, tf, 1))
      SMCPS_AddHit(PAT_ZONE_REJECTION, 1, tf, bt, entry, "Zone Rej+");
   if(SMCPS_ZoneRejection(symbol, tf, -1))
      SMCPS_AddHit(PAT_ZONE_REJECTION, -1, tf, bt, iLow(symbol, tf, 1), "Zone Rej-");
}

void SMCPS_Scan(const string symbol)
{
   g_smcps.hitCount = 0;
   g_smcps.bullScore = 0;
   g_smcps.bearScore = 0;
   g_smcps.bestName = "";
   g_smcps.bestDir = 0;
   g_smcps.summary = "";

   SMCPS_ScanTF(symbol, PERIOD_M1);
   SMCPS_ScanTF(symbol, PERIOD_M5);
   SMCPS_ScanTF(symbol, PERIOD_H1);

   g_smcps.lastScan = TimeCurrent();
   string parts = "";
   for(int i = 0; i < g_smcps.hitCount; i++)
   {
      if(StringLen(parts) > 0) parts += " | ";
      parts += g_smcps.hits[i].name + "@" + EnumToString(g_smcps.hits[i].tf);
      if(g_smcps.bestName == "" || g_smcps.hits[i].tf == PERIOD_M1)
      {
         g_smcps.bestName = g_smcps.hits[i].name;
         g_smcps.bestDir = g_smcps.hits[i].dirSign;
         g_smcps.bestTf = g_smcps.hits[i].tf;
      }
   }
   g_smcps.summary = parts;
}

bool SMCPS_HasPatternForDirection(const int dirSign)
{
   if(dirSign == 0) return false;
   for(int i = 0; i < g_smcps.hitCount; i++)
      if(g_smcps.hits[i].dirSign == dirSign) return true;
   return false;
}

bool SMCPS_HasShortTFPattern(const int dirSign)
{
   for(int i = 0; i < g_smcps.hitCount; i++)
   {
      if(g_smcps.hits[i].dirSign != dirSign) continue;
      if(g_smcps.hits[i].tf == PERIOD_M1 || g_smcps.hits[i].tf == PERIOD_M5)
         return true;
   }
   return false;
}

bool SMCPS_HasH1Pattern(const int dirSign)
{
   for(int i = 0; i < g_smcps.hitCount; i++)
   {
      if(g_smcps.hits[i].dirSign == dirSign && g_smcps.hits[i].tf == PERIOD_H1)
         return true;
   }
   return false;
}

string SMCPS_TfShort(const ENUM_TIMEFRAMES tf)
{
   if(tf == PERIOD_M1)  return "M1";
   if(tf == PERIOD_M5)  return "M5";
   if(tf == PERIOD_M15) return "M15";
   if(tf == PERIOD_H1)  return "H1";
   if(tf == PERIOD_H4)  return "H4";
   if(tf == PERIOD_D1)  return "D1";
   return EnumToString(tf);
}

bool SMCPS_EnsureScanned(const string symbol)
{
   if(g_smcps.lastScan == 0 || (int)(TimeCurrent() - g_smcps.lastScan) > 2)
      SMCPS_Scan(symbol);
   return (g_smcps.hitCount > 0);
}

bool SMCPS_PatternGateOK(const string symbol, const int dirSign, const bool logBlock = true)
{
   if(!UsePatternEntrySignals) return true;
   if(dirSign == 0) return false;

   SMCPS_EnsureScanned(symbol);
   if(!SMCPS_HasPatternForDirection(dirSign))
   {
      if(logBlock)
      {
         static datetime s_log = 0;
         if(TimeCurrent() - s_log >= 45)
         {
            s_log = TimeCurrent();
            Print("[PATTERN-SIGNAL] BLOQUE — aucun pattern ", (dirSign > 0 ? "BUY" : "SELL"),
                  " M1/M5/H1 | bull=", g_smcps.bullScore, " bear=", g_smcps.bearScore);
         }
      }
      return false;
   }
   if(PatternRequireM1orM5 && !SMCPS_HasShortTFPattern(dirSign))
   {
      if(!PatternAllowH1Only || !SMCPS_HasH1Pattern(dirSign))
      {
         if(logBlock)
         {
            static datetime s_log2 = 0;
            if(TimeCurrent() - s_log2 >= 45)
            {
               s_log2 = TimeCurrent();
               Print("[PATTERN-SIGNAL] BLOQUE — pattern H1 seul insuffisant | ", g_smcps.summary);
            }
         }
         return false;
      }
   }
   return true;
}

bool SMCPS_BreakoutConfirmed(const string symbol, const int dirSign)
{
   if(!PatternRequireBreakout) return true;
   double px = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(px <= 0) return false;
   for(int i = 0; i < g_smcps.hitCount; i++)
   {
      if(g_smcps.hits[i].dirSign != dirSign) continue;
      if(dirSign > 0 && px >= g_smcps.hits[i].entryLevel) return true;
      if(dirSign < 0 && px <= g_smcps.hits[i].entryLevel) return true;
   }
   return false;
}

string SMCPS_BestPatternTag(const int dirSign)
{
   for(int i = 0; i < g_smcps.hitCount; i++)
   {
      if(g_smcps.hits[i].dirSign != dirSign) continue;
      if(g_smcps.hits[i].tf == PERIOD_M1) return g_smcps.hits[i].name + "@" + SMCPS_TfShort(g_smcps.hits[i].tf);
   }
   for(int j = 0; j < g_smcps.hitCount; j++)
   {
      if(g_smcps.hits[j].dirSign != dirSign) continue;
      return g_smcps.hits[j].name + "@" + SMCPS_TfShort(g_smcps.hits[j].tf);
   }
   return "pattern";
}

int SMCPS_EffectiveGOMVerdictNum()
{
   if(MathAbs(g_smcGomVerdictNum) >= 2) return g_smcGomVerdictNum;
   if(SMCGP_IsCorrectionResumeWindow() && MathAbs(g_smcGomVerdictNumServer) >= 2)
      return g_smcGomVerdictNumServer;
   return g_smcGomVerdictNum;
}

bool SMCPS_TryExecutePatternEntry(const string symbol, const int dirSign, const string direction)
{
   if(!PatternTriggerMarketEntry || !UsePatternEntrySignals) return false;
   if(dirSign == 0) return false;
   int effVn = SMCPS_EffectiveGOMVerdictNum();
   if(MathAbs(effVn) < 2) return false;
   if(dirSign == 1 && effVn <= 0) return false;
   if(dirSign == -1 && effVn >= 0) return false;

   static datetime s_lastPatTry = 0;
   if(TimeCurrent() - s_lastPatTry < 5) return false;

   if(!SMCPS_PatternGateOK(symbol, dirSign, false)) return false;
   
   if(!SMCPS_BreakoutConfirmed(symbol, dirSign))
   {
      static datetime s_boLog = 0;
      if(TimeCurrent() - s_boLog >= 45)
      {
         s_boLog = TimeCurrent();
         Print("[PATTERN-EXEC] Attente breakout entry | ", direction,
               " | ", g_smcps.summary, " | GOM vn=", g_smcGomVerdictNum);
      }
      return false;
   }

   s_lastPatTry = TimeCurrent();
   string tag = SMCPS_BestPatternTag(dirSign);
   
   bool useAlignBypass = GOM_EntryAlignmentOK(dirSign);
   if(useAlignBypass) g_smcAlignExecBypass = true;

   bool ok = PlaceGOMMarketOrder(direction, "GOM_PATTERN", tag);

   if(useAlignBypass) g_smcAlignExecBypass = false;

   if(ok)
   {
      Print("[PATTERN-EXEC] MARKET ", direction, " | ", g_smcps.summary,
            " | GOM ", g_smcGomVerdict, " vn=", g_smcGomVerdictNum);
      return true;
   }
   Print("[PATTERN-EXEC] ECHEC MARKET ", direction, " | pattern OK mais ordre refusé | ",
         g_smcps.summary, " | vn=", g_smcGomVerdictNum,
         " align=", (GOM_EntryAlignmentOK(dirSign) ? "OK" : "NON"));
   return false;
}

//+------------------------------------------------------------------+
//| Détéction du RETEST du pointillé Entry d'un pattern : le prix vient  |
//| toucher le niveau (corps OU mèche de bougie) sans le casser dans  |
//| le sens du breakout. C'est le comportement "pullback sur l'entry".  |
//| Retourne l'entryLevel touché (le plus proche du prix) ou 0.       |
//+------------------------------------------------------------------+
double SMCPS_RetestEntryLevel(const string symbol, const int dirSign, double &tolOut)
{
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    if(bid <= 0 || ask <= 0) return 0.0;
    double px = (dirSign > 0) ? bid : ask;

    double atr = SMCPS_ATR(symbol, PERIOD_CURRENT);
    if(atr <= 0) atr = (ask - bid) * 2.0;
    if(atr <= 0) return 0.0;
    // Tolérance de toucher = mèche d'une bougie (~0.35 ATR) ou 10 points
    double tol = MathMax(atr * 0.35, SymbolInfoDouble(symbol, SYMBOL_POINT) * 10);
    tolOut = tol;

    double best = 0.0, bestDist = 999 * atr;
    for(int i = 0; i < g_smcps.hitCount; i++)
    {
        if(g_smcps.hits[i].dirSign != dirSign) continue;
        double lvl = g_smcps.hits[i].entryLevel;
        if(lvl <= 0) continue;
        double dist = MathAbs(px - lvl);
        if(dist <= tol && dist < bestDist)
        {
            bestDist = dist;
            best = lvl;
        }
    }
    return best;
}

//+------------------------------------------------------------------+
//| Entrée MARCHÉ sur RETEST du pointillé Entry (corps/mèche),         |
//| conditionnée par: S/R 20 bars DÉJÀ touché+rebondi (impulsion     |
//| forte) + verdict GOM GOOD/PERFECT. 1 ordre par toucher (debounce |
//| par bougie de toucher) pour éviter les doublons.                   |
//+------------------------------------------------------------------+
void SMCPS_TryExecutePatternEntryOnRetest(const string symbol, const int dirSign, const string direction)
{
    if(!PatternTriggerMarketEntry || !UsePatternEntrySignals) return;
    if(dirSign == 0) return;
    if(!SMC_IsSpikeStyleSymbol(symbol)) return;   // uniquement symboles spike

    // 1) S/R 20 bars touché + rebondi (preuve impulsion forte)
    bool armed = (dirSign > 0) ? g_sr20BounceArmedBuy : g_sr20BounceArmedSell;
    if(!armed) return;

    // 2) Verdict GOM : on exécute le retest SEULEMENT si GOM = GOOD/PERFECT.
    // Sous WAIT -> on n'entre PAS (on attend le retour du verdict).
    int effVn = SMCPS_EffectiveGOMVerdictNum();
    if(MathAbs(effVn) < 2) return;           // WAIT -> pas d'entrée, on attend
    if(dirSign == 1 && effVn <= 0) return;   // GOM SELL clair -> BUY interdit
    if(dirSign == -1 && effVn >= 0) return;  // GOM BUY clair -> SELL interdit

    // 3) Pattern présent dans la direction
    if(!SMCPS_PatternGateOK(symbol, dirSign, false)) return;

    // 4) Le prix touche le pointillé Entry (retest, pas breakout)
    double tol = 0;
    double lvl = SMCPS_RetestEntryLevel(symbol, dirSign, tol);
    if(lvl <= 0) return;

    // Debounce: 1 ordre par bougie de toucher (ne pas re-déclencher sur ticks voisins)
    static datetime s_lastRetestBar = 0;
    datetime curBar = iTime(symbol, PERIOD_CURRENT, 0);
    static double   s_lastRetestLvl  = 0;
    if(curBar == s_lastRetestBar && MathAbs(lvl - s_lastRetestLvl) < tol) return;
    s_lastRetestBar = curBar;
    s_lastRetestLvl  = lvl;

    string tag = SMCPS_BestPatternTag(dirSign) + "_RETST";

    // Entrée sur retest : on utilise UNIQUEMENT le verdict GOM GOOD/PERFECT
    // (pas le gate strict COG/IA/prédiction qui bloque tout). Bypass le gate.
    g_smcAlignExecBypass = true;

    bool ok = PlaceGOMMarketOrder(direction, "GOM_PATTERN", tag);

    g_smcAlignExecBypass = false;

    if(ok)
    {
        Print("[PATTERN-RETST] MARKET ", direction, " (retest Entry=", DoubleToString(lvl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
              ") | SR20 rebondi + GOM ", g_smcGomVerdict, " vn=", effVn,
              " | ", g_smcps.summary);
    }
    else
    {
        Print("[PATTERN-RETST] ECHEC ", direction, " retest Entry=", DoubleToString(lvl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)),
              " | GOM ", g_smcGomVerdict, " align=", (GOM_EntryAlignmentOK(dirSign) ? "OK" : "NON"));
    }
}

bool SMCPS_EntryAllowed(const string symbol, const int dirSign)
{
   if(!SMCPS_PatternGateOK(symbol, dirSign, true)) return false;
   Print("[PATTERN-SIGNAL] OK ", (dirSign > 0 ? "BUY" : "SELL"), " — ", g_smcps.summary);
   return true;
}

// Gate universelle : direction GOM + pattern Charly confirmé (breakout si activé)
bool SMCPS_ValidateGOMDirectionAndPattern(const string symbol, const int dirSign,
                                            const bool requirePattern = true)
{
   if(dirSign == 0) return false;

   if(UseGOMVerdictFilter && g_smcGomConnected)
   {
      int effVn = SMCPS_EffectiveGOMVerdictNum();
      if(effVn == 0)
      {
         Print("[ENTRY-GATE] BLOQUE — GOM=WAIT (vn=0) | ", symbol,
               " ordre=", (dirSign > 0 ? "BUY" : "SELL"));
         return false;
      }
      if(dirSign == 1 && effVn <= 0)
      {
         Print("[ENTRY-GATE] BLOQUE — BUY interdit vs GOM ", g_smcGomVerdict,
               " (vn=", effVn, ") | ", symbol);
         return false;
      }
      if(dirSign == -1 && effVn >= 0)
      {
         Print("[ENTRY-GATE] BLOQUE — SELL interdit vs GOM ", g_smcGomVerdict,
               " (vn=", effVn, ") | ", symbol);
         return false;
      }
   }

   if(!requirePattern || !UsePatternEntrySignals) return true;

   if(!SMCPS_PatternGateOK(symbol, dirSign, true)) return false;

   if(!SMCPS_BreakoutConfirmed(symbol, dirSign))
   {
      static datetime s_boLog = 0;
      if(TimeCurrent() - s_boLog >= 45)
      {
         s_boLog = TimeCurrent();
         Print("[ENTRY-GATE] Attente confirmation breakout | ",
               (dirSign > 0 ? "BUY" : "SELL"), " | ", g_smcps.summary,
               " | GOM vn=", g_smcGomVerdictNum);
      }
      return false;
   }
   return true;
}

string SMCPS_GetSummary() { return g_smcps.summary; }

int SMCPS_GetPatternTypeCount() { return 18; }

void SMCPS_ClearDrawings()
{
   ObjectsDeleteAll(0, "SMCPS_");
}

void SMCPS_DrawMarker(const string symbol)
{
   if(!PatternDrawOnChart) return;

   SMCPS_ClearDrawings();

   if(g_smcps.hitCount <= 0)
      return;

   int dp = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   int drawn = 0;
   const int maxArrows = 12;

   for(int i = 0; i < g_smcps.hitCount && drawn < maxArrows; i++)
   {
      double px = g_smcps.hits[i].entryLevel;
      datetime bt = g_smcps.hits[i].barTime;
      if(px <= 0 || bt <= 0) continue;

      color clr = (g_smcps.hits[i].dirSign > 0) ? clrLime : clrOrangeRed;
      int arrowCode = (g_smcps.hits[i].dirSign > 0) ? 233 : 234;
      double yOff = SMCPS_ATR(symbol, g_smcps.hits[i].tf) * 0.15;
      if(yOff <= 0) yOff = SymbolInfoDouble(symbol, SYMBOL_POINT) * 20;
      double y = (g_smcps.hits[i].dirSign > 0) ? (px - yOff) : (px + yOff);

      string arw = "SMCPS_ARW_" + IntegerToString(drawn);
      ObjectCreate(0, arw, OBJ_ARROW, 0, bt, y);
      ObjectSetInteger(0, arw, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, arw, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, arw, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arw, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, arw, OBJPROP_TOOLTIP,
         g_smcps.hits[i].name + " " + SMCPS_TfShort(g_smcps.hits[i].tf));

      string txt = "SMCPS_TXT_" + IntegerToString(drawn);
      ObjectCreate(0, txt, OBJ_TEXT, 0, bt, y);
      ObjectSetString(0, txt, OBJPROP_TEXT,
         g_smcps.hits[i].name + "@" + SMCPS_TfShort(g_smcps.hits[i].tf));
      ObjectSetInteger(0, txt, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, txt, OBJPROP_FONTSIZE, 7);
      ObjectSetString(0, txt, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, txt, OBJPROP_ANCHOR,
         (g_smcps.hits[i].dirSign > 0) ? ANCHOR_UPPER : ANCHOR_LOWER);
      ObjectSetInteger(0, txt, OBJPROP_SELECTABLE, false);

      string lvl = "SMCPS_LVL_" + IntegerToString(drawn);
      ObjectCreate(0, lvl, OBJ_TREND, 0, bt, px, bt + PeriodSeconds(g_smcps.hits[i].tf) * 3, px);
      ObjectSetInteger(0, lvl, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lvl, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, lvl, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, lvl, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lvl, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, lvl, OBJPROP_TOOLTIP,
         "Entry " + DoubleToString(px, dp));

      drawn++;
   }

   string panel = "SMCPS_PANEL";
   ObjectCreate(0, panel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, panel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, panel, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, panel, OBJPROP_YDISTANCE, 120);
   color pClr = (g_smcps.bullScore > g_smcps.bearScore) ? clrLime :
                (g_smcps.bearScore > g_smcps.bullScore) ? clrOrangeRed : clrGold;
   ObjectSetInteger(0, panel, OBJPROP_COLOR, pClr);
   string panelTxt = StringFormat("PATTERNS: %d actifs | BUY=%d SELL=%d | %s",
      g_smcps.hitCount, g_smcps.bullScore, g_smcps.bearScore,
      (g_smcps.bestName != "" ? g_smcps.bestName + "@" + SMCPS_TfShort(g_smcps.bestTf) : "-"));
   ObjectSetString(0, panel, OBJPROP_TEXT, panelTxt);
   ObjectSetInteger(0, panel, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, panel, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, panel, OBJPROP_SELECTABLE, false);

   ChartRedraw(0);
}

#endif
