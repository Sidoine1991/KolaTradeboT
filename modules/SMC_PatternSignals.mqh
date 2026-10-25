//+------------------------------------------------------------------+
//| SMC_PatternSignals.mqh — Stratégies d'entrée M1/M5/H1            |
//| Chandeliers + SMC (OB, Demand, FVG, Fib50, trendline retest)     |
//+------------------------------------------------------------------+
#ifndef SMC_PATTERN_SIGNALS_MQH
#define SMC_PATTERN_SIGNALS_MQH

#include "SMC_SharedCore.mqh"

 // Définition unique (inclus une seule fois via guard). Partagée avec SMC_Universal.mq5.
bool   g_sr20BounceArmedBuy  = false;
bool   g_sr20BounceArmedSell = false;
int    g_sr20BounceBuyBars   = 0;
int    g_sr20BounceSellBars  = 0;

bool SMCPS_Fib50Zone(const string symbol, const ENUM_TIMEFRAMES tf, const int dirSign, double &fib50);
bool PlacePatternSniperOrder(const string direction, const string tag, const string levelSource, const double entryLevel);

int SMCPS_PatternWeight(const int id)
{
   switch(id)
   {
      // Breaker = flip + liquidity sweep → plus haute conviction (littérature 2025-2026)
      case PAT_BREAKER_DEMAND:
      case PAT_BREAKER_SUPPLY:
         return 4;
      case PAT_BULL_ENGULFING:
      case PAT_BEAR_ENGULFING:
      case PAT_MORNING_STAR:
      case PAT_EVENING_STAR:
      case PAT_THREE_SOLDIERS:
      case PAT_THREE_CROWS:
      case PAT_OB_RETEST:
      case PAT_DEMAND_FLIP:   // Mitigation (sans sweep)
      case PAT_SUPPLY_FLIP:   // Mitigation (sans sweep)
      case PAT_DOUBLE_BOTTOM:
      case PAT_DOUBLE_TOP:
      case PAT_LIQ_SWEEP:
         return 3;
      case PAT_TWEEZER_BOTTOM:
      case PAT_TWEEZER_TOP:
      case PAT_FIB50_OB:
      case PAT_TRENDLINE_RETEST:
      case PAT_HAMMER:
      case PAT_SHOOTING_STAR:
      case PAT_FVG_DEMAND:
      case PAT_FVG_SUPPLY:
         return 2;
      default:
         return 1;
   }
}

double SMCPS_ATR(const string symbol, const ENUM_TIMEFRAMES tf, const int period = 14)
{
   static string s_sym = "";
   static ENUM_TIMEFRAMES s_tf = PERIOD_CURRENT;
   static int s_h = INVALID_HANDLE;
   if(s_h == INVALID_HANDLE || s_sym != symbol || s_tf != tf)
   {
      if(s_h != INVALID_HANDLE) IndicatorRelease(s_h);
      s_h = iATR(symbol, tf, period);
      s_sym = symbol;
      s_tf = tf;
   }
   if(s_h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(s_h, 0, 0, 1, buf) < 1) return 0.0;
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
                  const datetime barTime, const double entryLevel, const string name,
                  const bool inZone = false)
{
   if(g_smcps.hitCount >= SMCPS_MAX_PATTERNS) return;
   int w = SMCPS_PatternWeight(id);
   if(PatternWeakNeedsZone && w <= 1 && !inZone) return;
   if(PatternRequireZoneContext && w < 3 && !inZone) return;
   int i = g_smcps.hitCount++;
   g_smcps.hits[i].id = id;
   g_smcps.hits[i].dirSign = dirSign;
   g_smcps.hits[i].tf = tf;
   g_smcps.hits[i].barTime = barTime;
   g_smcps.hits[i].entryLevel = entryLevel;
   g_smcps.hits[i].name = name;
   g_smcps.hits[i].weight = w;
   g_smcps.hits[i].inZone = inZone;
   double addW = (double)w * (inZone ? 1.15 : 1.0);
   if(tf == PERIOD_M1) addW *= 1.10;
   else if(tf == PERIOD_M5) addW *= 1.05;
   if(dirSign > 0)
   {
      g_smcps.bullScore++;
      g_smcps.bullWeight += addW;
      if(w >= 3) g_smcps.bullStrong++;
   }
   else if(dirSign < 0)
   {
      g_smcps.bearScore++;
      g_smcps.bearWeight += addW;
      if(w >= 3) g_smcps.bearStrong++;
   }
}

double SMCPS_DirWeight(const int dirSign)
{
   if(dirSign > 0) return g_smcps.bullWeight;
   if(dirSign < 0) return g_smcps.bearWeight;
   return 0.0;
}

int SMCPS_DirStrong(const int dirSign)
{
   if(dirSign > 0) return g_smcps.bullStrong;
   if(dirSign < 0) return g_smcps.bearStrong;
   return 0;
}

double SMCPS_CandleSniperLevel(const string symbol, const ENUM_TIMEFRAMES tf, const int dirSign)
{
   double o = iOpen(symbol, tf, 1), c = iClose(symbol, tf, 1);
   double h = iHigh(symbol, tf, 1), l = iLow(symbol, tf, 1);
   if(dirSign > 0) return (l + MathMin(o, c)) * 0.5;
   return (h + MathMax(o, c)) * 0.5;
}

bool SMCPS_PriceInZone(const string symbol, const ENUM_TIMEFRAMES tf, const int dirSign)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return false;
   double px = (dirSign > 0) ? bid : ask;
   double atr = SMCPS_ATR(symbol, tf);
   if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 20.0;
   double tol = atr * 0.50;

   if(dirSign > 0)
   {
      if(g_sr20BounceArmedBuy) return true;
      if(g_impulseSupport20 > 0 && MathAbs(px - g_impulseSupport20) <= tol) return true;
      if(g_smcObBullTop > 0 && g_smcObBullBot > 0)
      {
         double zH = MathMax(g_smcObBullTop, g_smcObBullBot);
         double zL = MathMin(g_smcObBullTop, g_smcObBullBot);
         if(px <= zH + tol && px >= zL - tol) return true;
      }
   }
   else
   {
      if(g_sr20BounceArmedSell) return true;
      if(g_impulseResistance20 > 0 && MathAbs(px - g_impulseResistance20) <= tol) return true;
      if(g_smcObBearTop > 0 && g_smcObBearBot > 0)
      {
         double zH = MathMax(g_smcObBearTop, g_smcObBearBot);
         double zL = MathMin(g_smcObBearTop, g_smcObBearBot);
         if(px <= zH + tol && px >= zL - tol) return true;
      }
   }

   double fib50 = 0;
   if(SMCPS_Fib50Zone(symbol, tf, dirSign, fib50) && MathAbs(px - fib50) <= tol)
      return true;

   int look = 20;
   if(dirSign > 0)
   {
      int li = iLowest(symbol, tf, MODE_LOW, look, 1);
      if(li >= 0 && MathAbs(px - iLow(symbol, tf, li)) <= tol) return true;
   }
   else
   {
      int hi = iHighest(symbol, tf, MODE_HIGH, look, 1);
      if(hi >= 0 && MathAbs(px - iHigh(symbol, tf, hi)) <= tol) return true;
   }
   return false;
}

bool SMCPS_QualityOK(const int dirSign)
{
   if(dirSign == 0) return false;
   double w = SMCPS_DirWeight(dirSign);
   if(w < PatternMinWeightedScore) return false;
   if(SMCPS_DirStrong(dirSign) <= 0 && w < (PatternMinWeightedScore + 1.0))
      return false;
   if(PatternRequireZoneContext)
   {
      bool zoneHit = false;
      for(int i = 0; i < g_smcps.hitCount; i++)
      {
         if(g_smcps.hits[i].dirSign == dirSign && g_smcps.hits[i].inZone)
         { zoneHit = true; break; }
      }
      if(!zoneHit) return false;
   }
   return true;
}

double SMCPS_BestSniperLevel(const int dirSign)
{
   double best = 0;
   int bestW = -1;
   ENUM_TIMEFRAMES bestTf = PERIOD_H1;
   for(int i = 0; i < g_smcps.hitCount; i++)
   {
      if(g_smcps.hits[i].dirSign != dirSign || g_smcps.hits[i].entryLevel <= 0) continue;
      int w = g_smcps.hits[i].weight;
      if(g_smcps.hits[i].inZone) w += 1;
      bool better = (w > bestW) || (w == bestW && g_smcps.hits[i].tf < bestTf);
      if(!better) continue;
      bestW = w;
      bestTf = g_smcps.hits[i].tf;
      best = g_smcps.hits[i].entryLevel;
   }
   return best;
}

bool SMCPS_NotExtended(const string symbol, const int dirSign)
{
   double lvl = SMCPS_BestSniperLevel(dirSign);
   if(lvl <= 0) return false;
   double atr = SMCPS_ATR(symbol, PERIOD_M1);
   if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 20.0;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return false;
   double px = (dirSign > 0) ? ask : bid;
   double maxExt = atr * MathMax(0.10, PatternMaxExtensionATR);
   if(dirSign > 0 && px > lvl + maxExt) return false;
   if(dirSign < 0 && px < lvl - maxExt) return false;
   return true;
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
   double atr = SMCPS_ATR(symbol, tf);
   if(atr > 0 && SMCPS_Body(symbol, tf, 1) < atr * 0.15) return false;
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

// FIX 2026-09-13 (Claude, recherche demandée par Sidoine): 6 figures
// chartistes fréquemment citées comme les plus fiables (avec confirmation
// de contexte) et absentes jusque-là — pin bars (Hammer/Shooting Star),
// Harami, Piercing Line/Dark Cloud Cover. Taux de réussite réels avec
// confirmation (littérature/backtests publics, PAS 90% — voir note envoyée
// à Sidoine) : Hammer ~65%, Shooting Star ~57-59%, Harami ~55-56% (signal
// d'alerte plus que déclencheur), Piercing/Dark Cloud ~56-60%. D'où leur
// usage ici en CONFIRMATION au sein du score bull/bear, jamais seules.
bool SMCPS_Hammer(const string symbol, const ENUM_TIMEFRAMES tf)
{
   double o1 = iOpen(symbol, tf, 1), c1 = iClose(symbol, tf, 1);
   double h1 = iHigh(symbol, tf, 1), l1 = iLow(symbol, tf, 1);
   double body = MathAbs(c1 - o1);
   double range = h1 - l1;
   if(range <= 0 || body <= 0) return false;
   double lowerWick = MathMin(o1, c1) - l1;
   double upperWick = h1 - MathMax(o1, c1);
   // Corps dans le tiers supérieur, mèche basse >= 2x corps, mèche haute négligeable
   if(lowerWick < body * 2.0) return false;
   if(upperWick > body * 0.5) return false;
   if(!SMCPS_IsBear(symbol, tf, 2)) return false; // contexte baissier préalable requis
   return true;
}

bool SMCPS_ShootingStar(const string symbol, const ENUM_TIMEFRAMES tf)
{
   double o1 = iOpen(symbol, tf, 1), c1 = iClose(symbol, tf, 1);
   double h1 = iHigh(symbol, tf, 1), l1 = iLow(symbol, tf, 1);
   double body = MathAbs(c1 - o1);
   double range = h1 - l1;
   if(range <= 0 || body <= 0) return false;
   double lowerWick = MathMin(o1, c1) - l1;
   double upperWick = h1 - MathMax(o1, c1);
   if(upperWick < body * 2.0) return false;
   if(lowerWick > body * 0.5) return false;
   if(!SMCPS_IsBull(symbol, tf, 2)) return false; // contexte haussier préalable requis
   return true;
}

bool SMCPS_BullHarami(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!SMCPS_IsBear(symbol, tf, 2) || !SMCPS_IsBull(symbol, tf, 1)) return false;
   double o2 = iOpen(symbol, tf, 2), c2 = iClose(symbol, tf, 2);
   double o1 = iOpen(symbol, tf, 1), c1 = iClose(symbol, tf, 1);
   // Corps 1 entièrement contenu dans le corps 2 (inverse de l'engulfing)
   return (o1 > c2 && c1 < o2);
}

bool SMCPS_BearHarami(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!SMCPS_IsBull(symbol, tf, 2) || !SMCPS_IsBear(symbol, tf, 1)) return false;
   double o2 = iOpen(symbol, tf, 2), c2 = iClose(symbol, tf, 2);
   double o1 = iOpen(symbol, tf, 1), c1 = iClose(symbol, tf, 1);
   return (o1 < c2 && c1 > o2);
}

bool SMCPS_PiercingLine(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!SMCPS_IsBear(symbol, tf, 2) || !SMCPS_IsBull(symbol, tf, 1)) return false;
   double o2 = iOpen(symbol, tf, 2), c2 = iClose(symbol, tf, 2), l2 = iLow(symbol, tf, 2);
   double o1 = iOpen(symbol, tf, 1), c1 = iClose(symbol, tf, 1);
   double mid2 = (o2 + c2) * 0.5;
   if(o1 > c2) return false;           // pas de gap baissier à l'ouverture
   return (c1 > mid2 && c1 < o2);      // clôture au-delà du milieu, sous l'open précédent
}

bool SMCPS_DarkCloudCover(const string symbol, const ENUM_TIMEFRAMES tf)
{
   if(!SMCPS_IsBull(symbol, tf, 2) || !SMCPS_IsBear(symbol, tf, 1)) return false;
   double o2 = iOpen(symbol, tf, 2), c2 = iClose(symbol, tf, 2), h2 = iHigh(symbol, tf, 2);
   double o1 = iOpen(symbol, tf, 1), c1 = iClose(symbol, tf, 1);
   double mid2 = (o2 + c2) * 0.5;
   if(o1 < c2) return false;           // pas de gap haussier à l'ouverture
   return (c1 < mid2 && c1 > o2);      // clôture au-delà du milieu, au-dessus de l'open précédent
}

bool SMCPS_BullFVG(const string symbol, const ENUM_TIMEFRAMES tf)
{
   double hi3 = iHigh(symbol, tf, 3);
   double lo1 = iLow(symbol, tf, 1);
   if(lo1 <= hi3) return false;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double atr = SMCPS_ATR(symbol, tf);
   if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10.0;
   return (bid <= lo1 + atr * 0.15 && bid >= hi3 - atr * 0.10);
}

bool SMCPS_BearFVG(const string symbol, const ENUM_TIMEFRAMES tf)
{
   double lo3 = iLow(symbol, tf, 3);
   double hi1 = iHigh(symbol, tf, 1);
   if(hi1 >= lo3) return false;
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double atr = SMCPS_ATR(symbol, tf);
   if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 10.0;
   return (ask >= hi1 - atr * 0.15 && ask <= lo3 + atr * 0.10);
}

bool SMCPS_LiquiditySweep(const string symbol, const ENUM_TIMEFRAMES tf, const int dirSign)
{
   int look = 20;
   if(dirSign > 0)
   {
      int li = iLowest(symbol, tf, MODE_LOW, look, 2);
      if(li < 0) return false;
      double liq = iLow(symbol, tf, li);
      return (iLow(symbol, tf, 1) < liq && iClose(symbol, tf, 1) > liq && SMCPS_IsBull(symbol, tf, 1));
   }
   int hi = iHighest(symbol, tf, MODE_HIGH, look, 2);
   if(hi < 0) return false;
   double liqH = iHigh(symbol, tf, hi);
   return (iHigh(symbol, tf, 1) > liqH && iClose(symbol, tf, 1) < liqH && SMCPS_IsBear(symbol, tf, 1));
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

// FIX 2026-09-19 (recherche ICT/SMC 2025-2026) :
// Un Breaker Block se distingue d'un Mitigation Block UNIQUEMENT par la
// présence d'un liquidity sweep (raid de stops) AVANT le retournement.
// Cette fonction cherche un balayage de liquidité externe dans les 2-15
// barres précédant la bougie 1 (celle du flip / structure shift).
bool SMCPS_HadPriorLiquiditySweep(const string symbol, const ENUM_TIMEFRAMES tf, const int dirSign)
{
   // dirSign > 0 = sweep baissier (SSL) avant flip haussier
   // dirSign < 0 = sweep haussier (BSL) avant flip baissier
   int look = 20;
   double atr = SMCPS_ATR(symbol, tf);
   if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 20.0;

   if(dirSign > 0)
   {
      int li = iLowest(symbol, tf, MODE_LOW, look, 3);
      if(li < 0) return false;
      double liq = iLow(symbol, tf, li);
      for(int s = 2; s <= 15; s++)
      {
         if(iLow(symbol, tf, s) < liq - atr * 0.02 &&
            iClose(symbol, tf, s) > liq &&
            SMCPS_IsBull(symbol, tf, s))
            return true;
      }
   }
   else
   {
      int hi = iHighest(symbol, tf, MODE_HIGH, look, 3);
      if(hi < 0) return false;
      double liqH = iHigh(symbol, tf, hi);
      for(int s = 2; s <= 15; s++)
      {
         if(iHigh(symbol, tf, s) > liqH + atr * 0.02 &&
            iClose(symbol, tf, s) < liqH &&
            SMCPS_IsBear(symbol, tf, s))
            return true;
      }
   }
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
   double buySniper = SMCPS_CandleSniperLevel(symbol, tf, 1);
   double sellSniper = SMCPS_CandleSniperLevel(symbol, tf, -1);
   bool zoneBuy = SMCPS_PriceInZone(symbol, tf, 1);
   bool zoneSell = SMCPS_PriceInZone(symbol, tf, -1);

   if(SMCPS_BullishEngulfing(symbol, tf))
      SMCPS_AddHit(PAT_BULL_ENGULFING, 1, tf, bt, buySniper, "Bull Engulf", zoneBuy);
   if(SMCPS_BearishEngulfing(symbol, tf))
      SMCPS_AddHit(PAT_BEAR_ENGULFING, -1, tf, bt, sellSniper, "Bear Engulf", zoneSell);
   if(SMCPS_MorningStar(symbol, tf))
      SMCPS_AddHit(PAT_MORNING_STAR, 1, tf, bt, buySniper, "Morning Star", zoneBuy);
   if(SMCPS_EveningStar(symbol, tf))
      SMCPS_AddHit(PAT_EVENING_STAR, -1, tf, bt, sellSniper, "Evening Star", zoneSell);
   if(SMCPS_ThreeSoldiers(symbol, tf))
      SMCPS_AddHit(PAT_THREE_SOLDIERS, 1, tf, bt, buySniper, "3 Soldiers", zoneBuy);
   if(SMCPS_ThreeCrows(symbol, tf))
      SMCPS_AddHit(PAT_THREE_CROWS, -1, tf, bt, sellSniper, "3 Crows", zoneSell);
   if(SMCPS_TweezerBottom(symbol, tf))
      SMCPS_AddHit(PAT_TWEEZER_BOTTOM, 1, tf, bt, buySniper, "Tweezer Bot", zoneBuy);
   if(SMCPS_TweezerTop(symbol, tf))
      SMCPS_AddHit(PAT_TWEEZER_TOP, -1, tf, bt, sellSniper, "Tweezer Top", zoneSell);
   if(SMCPS_Hammer(symbol, tf))
      SMCPS_AddHit(PAT_HAMMER, 1, tf, bt, buySniper, "Hammer", zoneBuy);
   if(SMCPS_ShootingStar(symbol, tf))
      SMCPS_AddHit(PAT_SHOOTING_STAR, -1, tf, bt, sellSniper, "Shooting Star", zoneSell);
   if(SMCPS_BullHarami(symbol, tf))
      SMCPS_AddHit(PAT_BULL_HARAMI, 1, tf, bt, buySniper, "Bull Harami", zoneBuy);
   if(SMCPS_BearHarami(symbol, tf))
      SMCPS_AddHit(PAT_BEAR_HARAMI, -1, tf, bt, sellSniper, "Bear Harami", zoneSell);
   if(SMCPS_PiercingLine(symbol, tf))
      SMCPS_AddHit(PAT_PIERCING_LINE, 1, tf, bt, buySniper, "Piercing Line", zoneBuy);
   if(SMCPS_DarkCloudCover(symbol, tf))
      SMCPS_AddHit(PAT_DARK_CLOUD_COVER, -1, tf, bt, sellSniper, "Dark Cloud", zoneSell);
   if(SMCPS_OBRetest(symbol, tf, 1))
      SMCPS_AddHit(PAT_OB_RETEST, 1, tf, bt, MathMin(g_smcObBullTop, g_smcObBullBot), "OB Retest+", true);
   if(SMCPS_OBRetest(symbol, tf, -1))
      SMCPS_AddHit(PAT_OB_RETEST, -1, tf, bt, MathMax(g_smcObBearTop, g_smcObBearBot), "OB Retest-", true);
   // FIX 2026-09-19 : distinction Breaker (avec sweep) vs Mitigation (sans sweep)
   // Littérature ICT/SMC 2025-2026 : le sweep de liquidité est le critère unique
   // qui élève la conviction (poids 4 vs 3).
   if(SMCPS_DemandSupplyFlip(symbol, tf, 1))
   {
      if(SMCPS_HadPriorLiquiditySweep(symbol, tf, 1) || SMCPS_LiquiditySweep(symbol, tf, 1))
         SMCPS_AddHit(PAT_BREAKER_DEMAND, 1, tf, bt, buySniper, "Breaker+", true);
      else
         SMCPS_AddHit(PAT_DEMAND_FLIP, 1, tf, bt, buySniper, "Mitigation+", true);
   }
   if(SMCPS_DemandSupplyFlip(symbol, tf, -1))
   {
      if(SMCPS_HadPriorLiquiditySweep(symbol, tf, -1) || SMCPS_LiquiditySweep(symbol, tf, -1))
         SMCPS_AddHit(PAT_BREAKER_SUPPLY, -1, tf, bt, sellSniper, "Breaker-", true);
      else
         SMCPS_AddHit(PAT_SUPPLY_FLIP, -1, tf, bt, sellSniper, "Mitigation-", true);
   }
   if(SMCPS_BullFVG(symbol, tf))
      SMCPS_AddHit(PAT_FVG_DEMAND, 1, tf, bt, iHigh(symbol, tf, 3), "FVG Demand", true);
   if(SMCPS_BearFVG(symbol, tf))
      SMCPS_AddHit(PAT_FVG_SUPPLY, -1, tf, bt, iLow(symbol, tf, 3), "FVG Supply", true);
   if(SMCPS_DoubleBottom(symbol, tf))
      SMCPS_AddHit(PAT_DOUBLE_BOTTOM, 1, tf, bt, buySniper, "Double Bottom", zoneBuy);
   if(SMCPS_DoubleTop(symbol, tf))
      SMCPS_AddHit(PAT_DOUBLE_TOP, -1, tf, bt, sellSniper, "Double Top", zoneSell);
   if(SMCPS_TrendlineBreakRetest(symbol, tf, 1))
      SMCPS_AddHit(PAT_TRENDLINE_RETEST, 1, tf, bt, buySniper, "TL Retest+", zoneBuy);
   if(SMCPS_TrendlineBreakRetest(symbol, tf, -1))
      SMCPS_AddHit(PAT_TRENDLINE_RETEST, -1, tf, bt, sellSniper, "TL Retest-", zoneSell);
   double fib50 = 0;
   if(SMCPS_Fib50Zone(symbol, tf, 1, fib50) && SMCPS_OBRetest(symbol, tf, 1))
      SMCPS_AddHit(PAT_FIB50_OB, 1, tf, bt, fib50, "Fib50+OB", true);
   if(SMCPS_Fib50Zone(symbol, tf, -1, fib50) && SMCPS_OBRetest(symbol, tf, -1))
      SMCPS_AddHit(PAT_FIB50_OB, -1, tf, bt, fib50, "Fib50+OB", true);
   if(SMCPS_ZoneRejection(symbol, tf, 1))
      SMCPS_AddHit(PAT_ZONE_REJECTION, 1, tf, bt, buySniper, "Zone Rej+", zoneBuy);
   if(SMCPS_ZoneRejection(symbol, tf, -1))
      SMCPS_AddHit(PAT_ZONE_REJECTION, -1, tf, bt, sellSniper, "Zone Rej-", zoneSell);
   if(SMCPS_LiquiditySweep(symbol, tf, 1))
      SMCPS_AddHit(PAT_LIQ_SWEEP, 1, tf, bt, iClose(symbol, tf, 1), "Liq Sweep+", true);
   if(SMCPS_LiquiditySweep(symbol, tf, -1))
      SMCPS_AddHit(PAT_LIQ_SWEEP, -1, tf, bt, iClose(symbol, tf, 1), "Liq Sweep-", true);
}

void SMCPS_Scan(const string symbol)
{
   g_smcps.hitCount = 0;
   g_smcps.bullScore = 0;
   g_smcps.bearScore = 0;
   g_smcps.bullWeight = 0;
   g_smcps.bearWeight = 0;
   g_smcps.bullStrong = 0;
   g_smcps.bearStrong = 0;
   g_smcps.bestName = "";
   g_smcps.bestDir = 0;
   g_smcps.summary = "";

   SMCPS_ScanTF(symbol, PERIOD_M1);
   SMCPS_ScanTF(symbol, PERIOD_M5);
   SMCPS_ScanTF(symbol, PERIOD_M15); // NOUVEAU 2026-09-19 : déclencheur cascade M15->M5/M1
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

// FIX 2026-09-19 (Claude, demande Sidoine): pattern M15 comme déclencheur de
// la cascade M15->M5(lent)/M1(rapide). Filtre par poids mini pour ignorer les
// patterns M15 trop faibles (ex. simple Harami hors zone).
bool SMCPS_HasQualifyingM15Pattern(const int dirSign, const int minWeight)
{
   if(dirSign == 0) return false;
   for(int i = 0; i < g_smcps.hitCount; i++)
      if(g_smcps.hits[i].dirSign == dirSign && g_smcps.hits[i].tf == PERIOD_M15
         && g_smcps.hits[i].weight >= minWeight)
         return true;
   return false;
}

// Meilleur niveau d'entrée pour une direction, restreint à un timeframe donné.
// SMCPS_BestSniperLevel (existant) mélange tous les TF ; ici on isole la
// cassure M5 de la cassure M1 pour la cascade M15->M5/M1.
double SMCPS_BestSniperLevelForTF(const int dirSign, const ENUM_TIMEFRAMES tf)
{
   double best = 0;
   int bestW = -1;
   for(int i = 0; i < g_smcps.hitCount; i++)
   {
      if(g_smcps.hits[i].dirSign != dirSign || g_smcps.hits[i].tf != tf) continue;
      if(g_smcps.hits[i].entryLevel <= 0) continue;
      int w = g_smcps.hits[i].weight;
      if(g_smcps.hits[i].inZone) w += 1;
      if(w <= bestW) continue;
      bestW = w;
      best = g_smcps.hits[i].entryLevel;
   }
   return best;
}

// Variante de SMCPS_BreakoutConfirmed restreinte à un TF précis (niveau ET
// ATR du TF donné, au lieu du meilleur niveau tous TF + ATR M1). Utilisée par
// le volet "lent" (M5) de la cascade M15->M5/M1 : on attend la cassure sur M5,
// jamais une cassure M1 qui validerait le volet censé être plus prudent.
bool SMCPS_BreakoutConfirmedOnTF(const string symbol, const int dirSign, const ENUM_TIMEFRAMES tf)
{
   if(!SMCPS_NotExtended(symbol, dirSign)) return false;
   double lvl = SMCPS_BestSniperLevelForTF(dirSign, tf);
   if(lvl <= 0) return false;
   double atr = SMCPS_ATR(symbol, tf);
   if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 20.0;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return false;
   double px = (dirSign > 0) ? ask : bid;
   double near = atr * MathMax(0.12, PatternMaxExtensionATR);
   if(MathAbs(px - lvl) <= near) return true;
   if(!PatternBreakoutIntrabar)
   {
      double cl = iClose(symbol, tf, 1);
      return (MathAbs(cl - lvl) <= near);
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
   if(!SMCPS_HasPatternForDirection(dirSign) || !SMCPS_QualityOK(dirSign))
   {
      if(logBlock)
      {
         static datetime s_log = 0;
         if(TimeCurrent() - s_log >= 45)
         {
            s_log = TimeCurrent();
            Print("[PATTERN-SIGNAL] BLOQUE — qualité insuffisante ", (dirSign > 0 ? "BUY" : "SELL"),
                  " | wBuy=", DoubleToString(g_smcps.bullWeight, 1),
                  " wSell=", DoubleToString(g_smcps.bearWeight, 1),
                  " seuil=", DoubleToString(PatternMinWeightedScore, 1),
                  " | ", g_smcps.summary);
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
   if(!SMCPS_NotExtended(symbol, dirSign)) return false;
   double lvl = SMCPS_BestSniperLevel(dirSign);
   if(lvl <= 0) return false;
   double atr = SMCPS_ATR(symbol, PERIOD_M1);
   if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 20.0;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return false;
   double px = (dirSign > 0) ? ask : bid;
   double near = atr * MathMax(0.12, PatternMaxExtensionATR);
   if(MathAbs(px - lvl) <= near) return true;
   if(!PatternBreakoutIntrabar)
   {
      double cl = iClose(symbol, PERIOD_M1, 1);
      return (MathAbs(cl - lvl) <= near);
   }
   return false;
}

//+------------------------------------------------------------------+
//| Diagnostic: la raison EXACTE pour laquelle l'entrée pattern est   |
//| bloquée (ou "OK — prêt à entrer"). Affichée au dashboard et       |
//| loggée toutes les 30s en OnTick ([PATTERN-DIAG]).                 |
//+------------------------------------------------------------------+
string SMCPS_PatternBlockReason(const string symbol, const int dirSign)
{
   if(!PatternTriggerMarketEntry || !UsePatternEntrySignals)
      return "entree pattern desactivee";
   if(dirSign == 0)
   {
      if(!g_smcGomConnected) return "GOM deconnecte - aucune entree";
      return "GOM=WAIT (vn=0) - aucune entree";
   }
   // GATE 1: verdict GOM GOOD/PERFECT aligné (bloqueur silencieux historique)
   if(!SMC_EntryVerdictOK(symbol, dirSign))
   {
      if(!g_smcGomConnected) return "GOM deconnecte";
      int vn = g_smcGomVerdictNum;
      if(vn == -999 || vn == 0) return "GOM=WAIT - etat bloquant";
      if(!SMCGP_IsGoodPerfect(vn)) return "GOM SIMPLE vn=" + IntegerToString(vn) + " - GOOD/PERFECT requis";
      return "GOM contre direction (vn=" + IntegerToString(vn) + ")";
   }
   // GATE 2: spikes (cross-corr / SCH1 relaxables en contexte pattern, veto BC conserve)
   if(SMC_IsSpikeStyleSymbol(symbol))
   {
      string r = "";
      if(!SMC_MarketEntryTripleGateOK(dirSign, r, true))
         return r;
   }
   // GATE 3: pattern présent
   SMCPS_EnsureScanned(symbol);
   if(!SMCPS_HasPatternForDirection(dirSign))
      return "aucun pattern " + (dirSign > 0 ? "BUY" : "SELL") + " (M1/M5/H1)";
   if(PatternRequireM1orM5 && !SMCPS_HasShortTFPattern(dirSign))
   {
      if(!PatternAllowH1Only || !SMCPS_HasH1Pattern(dirSign))
         return "pattern H1 seul - M1/M5 requis";
   }
   // Confirmation de cassure de l'entry level
   if(PatternRequireBreakout && !SMCPS_BreakoutConfirmed(symbol, dirSign))
      return "attente cassure entry level ("
            + (PatternBreakoutIntrabar ? "intrabar" : "cloture M1") + ")";
   return "OK - pret a entrer";
}

bool SMCPS_M1PatternMatchesLevel(const string symbol, const int dirSign,
                                 const double level, const double tolerance)
{
   if(dirSign == 0 || level <= 0) return false;
   SMCPS_EnsureScanned(symbol);
   for(int i = 0; i < g_smcps.hitCount; i++)
   {
      if(g_smcps.hits[i].dirSign != dirSign || g_smcps.hits[i].tf != PERIOD_M1)
         continue;
      if(MathAbs(g_smcps.hits[i].entryLevel - level) <= tolerance)
         return true;
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
   // WAIT trading = WAIT. Jamais remonter srv:PERFECT pour ouvrir.
   if(g_smcGomVerdictNum == 0) return 0;
   if(MathAbs(g_smcGomVerdictNum) >= 2) return g_smcGomVerdictNum;
   // Fenêtre resume : uniquement si le verdict trading n'est PAS WAIT
   if(SMCGP_IsCorrectionResumeWindow() && MathAbs(g_smcGomVerdictNumServer) >= 2
      && g_smcGomVerdictNum != 0)
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

int SMCPS_GetPatternTypeCount() { return 26; } // +2 Breaker Demand/Supply (2026-09-19)

void SMCPS_ClearDrawings()
{
   ObjectsDeleteAll(0, "SMCPS_");
}

void SMCPS_DrawSetup(const string symbol, const SMCPS_Hit &hit, const int index)
{
   // NOUVEAU 2026-09-19 (demande Sidoine) : dessin dynamique étendu à M15
   // (setups), en plus de M1 (scalp). Auparavant restreint à M1 uniquement.
   if((hit.tf != PERIOD_M1 && hit.tf != PERIOD_M15) || hit.entryLevel <= 0 || hit.barTime <= 0) return;

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double atr = SMCPS_ATR(symbol, hit.tf);
   if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 20.0;

   datetime startTime = iTime(symbol, hit.tf, 4);
   datetime endTime = iTime(symbol, hit.tf, 1) + PeriodSeconds(hit.tf) * 8;
   if(startTime <= 0 || endTime <= 0) return;

   double formationHigh = iHigh(symbol, hit.tf, 4);
   double formationLow = iLow(symbol, hit.tf, 4);
   for(int shift = 1; shift <= 4; shift++)
   {
      formationHigh = MathMax(formationHigh, iHigh(symbol, hit.tf, shift));
      formationLow = MathMin(formationLow, iLow(symbol, hit.tf, shift));
   }
   if(formationHigh <= formationLow) return;

   color accent = (hit.dirSign > 0) ? clrLime : clrOrangeRed;
   string prefix = "SMCPS_SETUP_" + IntegerToString(index);

   string zone = prefix + "_ZONE";
   if(ObjectCreate(0, zone, OBJ_RECTANGLE, 0, startTime, formationHigh, endTime, formationLow))
   {
      ObjectSetInteger(0, zone, OBJPROP_COLOR, accent);
      ObjectSetInteger(0, zone, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, zone, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, zone, OBJPROP_FILL, false);
      ObjectSetInteger(0, zone, OBJPROP_BACK, true);
      ObjectSetInteger(0, zone, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, zone, OBJPROP_TOOLTIP, hit.name + " formation M1");
   }

   string entry = prefix + "_ENTRY";
   if(ObjectCreate(0, entry, OBJ_TREND, 0, hit.barTime, hit.entryLevel, endTime, hit.entryLevel))
   {
      ObjectSetInteger(0, entry, OBJPROP_COLOR, accent);
      ObjectSetInteger(0, entry, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, entry, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, entry, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, entry, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, entry, OBJPROP_TOOLTIP,
         "ENTRY " + DoubleToString(hit.entryLevel, digits));
   }

   double invalidation = (hit.dirSign > 0) ? formationLow - atr * 0.15 : formationHigh + atr * 0.15;
   double target = (hit.dirSign > 0)
      ? hit.entryLevel + MathMax(formationHigh - formationLow, atr)
      : hit.entryLevel - MathMax(formationHigh - formationLow, atr);

   string invalid = prefix + "_INVALID";
   if(ObjectCreate(0, invalid, OBJ_TREND, 0, startTime, invalidation, endTime, invalidation))
   {
      ObjectSetInteger(0, invalid, OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, invalid, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, invalid, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, invalid, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, invalid, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, invalid, OBJPROP_TOOLTIP,
         "INVALIDATION " + DoubleToString(invalidation, digits));
   }

   string targetName = prefix + "_TARGET";
   if(ObjectCreate(0, targetName, OBJ_TREND, 0, hit.barTime, target, endTime, target))
   {
      ObjectSetInteger(0, targetName, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, targetName, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, targetName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, targetName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, targetName, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, targetName, OBJPROP_TOOLTIP,
         "TARGET " + DoubleToString(target, digits));
   }
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

      SMCPS_DrawSetup(symbol, g_smcps.hits[i], drawn);

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
