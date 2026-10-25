//+------------------------------------------------------------------+
//| SMC_MarketRegime.mqh                                              |
//| Détection temps réel : RANGE / CORRECTION / TENDANCE / BREAKOUT   |
//| Filtre pour EA SMC — ne remplace pas BOS/OB/FVG, les gate.        |
//+------------------------------------------------------------------+
#ifndef SMC_MARKET_REGIME_MQH
#define SMC_MARKET_REGIME_MQH

//--- États de marché
enum MARKET_STATE
{
   MARKET_UNKNOWN = 0,
   MARKET_RANGE,
   MARKET_TREND_UP,
   MARKET_TREND_DOWN,
   MARKET_CORRECTION_UP,    // rebond dans une tendance baissière
   MARKET_CORRECTION_DOWN   // pullback dans une tendance haussière
};

//--- Résultat d'analyse
struct MarketAnalysis
{
   MARKET_STATE state;
   double       confidence;          // 0..100
   double       range_high;
   double       range_low;
   double       range_width;
   double       range_width_atr;
   double       atr;
   double       adx;
   double       trend_strength;      // 0..100
   double       correction_percent;  // 0..100 (retracement Fib approx)
   bool         breakout_up;
   bool         breakout_down;
   int          trend_dir;           // +1 / -1 / 0
   string       reason;
};

//--- Inputs (préfixe MR_ pour ne pas collisionner)
input group "=== MARKET REGIME (range/correction/trend) ==="
input bool   MR_Enable                 = false;  // FIX v1.28: false - bloquait FX Vol (rebond 27.5% vs 30%+)
input int    MR_LookbackBars           = 40;     // Bougies M1 pour structure / range
input int    MR_SwingStrength          = 2;      // Force pivots (barres de chaque côté)
input double MR_ADX_RangeMax           = 18.0;   // ADX sous ce seuil → biais RANGE
input double MR_ADX_TrendMin           = 22.0;   // ADX au-dessus → biais TENDANCE
input double MR_MaxRangeWidthATR       = 2.80;   // Largeur max range (x ATR)
input double MR_MinRangeWidthATR       = 0.25;   // Largeur min pour parler de "box"
input double MR_BreakoutBufferATR      = 0.12;   // Buffer cassure hors box
input double MR_CorrectionMaxPct       = 65.0;   // Au-delà = plutôt retournement / range
input double MR_CorrectionMinPct       = 20.0;   // Sous ce seuil = encore impulse
input bool   MR_BlockRangeEntries      = true;   // Bloquer TOUTES les entrées en RANGE
input bool   MR_RequireBreakoutFromRange = true; // En range: autoriser seulement après cassure directionnelle
input bool   MR_BlockCorrectionAgainstTrend = true; // Bloquer BUY en CORRECTION_DOWN (pullback non épuisé)
input double MR_MinConfidence          = 55.0;   // Confiance min pour appliquer un blocage

//--- Cache par symbole (chart courant prioritaire)
MarketAnalysis g_mrLast;
datetime       g_mrLastBarTime = 0;
string         g_mrLastSymbol  = "";

//+------------------------------------------------------------------+
string MR_StateToString(const MARKET_STATE s)
{
   switch(s)
   {
      case MARKET_RANGE:           return "RANGE";
      case MARKET_TREND_UP:        return "TREND_UP";
      case MARKET_TREND_DOWN:      return "TREND_DOWN";
      case MARKET_CORRECTION_UP:   return "CORRECTION_UP";
      case MARKET_CORRECTION_DOWN: return "CORRECTION_DOWN";
      default:                     return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
double MR_GetATR(const string symbol, const ENUM_TIMEFRAMES tf, const int period = 14)
{
   int h = iATR(symbol, tf, period);
   if(h == INVALID_HANDLE) return 0.0;
   double b[];
   ArraySetAsSeries(b, true);
   if(CopyBuffer(h, 0, 0, 1, b) < 1) return 0.0;
   return b[0];
}

//+------------------------------------------------------------------+
double MR_GetADX(const string symbol, const ENUM_TIMEFRAMES tf, const int period = 14)
{
   int h = iADX(symbol, tf, period);
   if(h == INVALID_HANDLE) return 0.0;
   double b[];
   ArraySetAsSeries(b, true);
   // buffer 0 = ADX principal
   if(CopyBuffer(h, 0, 0, 1, b) < 1) return 0.0;
   return b[0];
}

//+------------------------------------------------------------------+
//| Pivots swing simple                                                |
//+------------------------------------------------------------------+
bool MR_IsSwingHigh(const MqlRates &r[], const int i, const int strength)
{
   if(i < strength || i + strength >= ArraySize(r)) return false;
   for(int k = 1; k <= strength; k++)
   {
      if(r[i].high <= r[i - k].high) return false;
      if(r[i].high <= r[i + k].high) return false;
   }
   return true;
}

bool MR_IsSwingLow(const MqlRates &r[], const int i, const int strength)
{
   if(i < strength || i + strength >= ArraySize(r)) return false;
   for(int k = 1; k <= strength; k++)
   {
      if(r[i].low >= r[i - k].low) return false;
      if(r[i].low >= r[i + k].low) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Analyse structure HH/HL vs LH/LL sur les derniers swings          |
//+------------------------------------------------------------------+
int MR_StructureBias(const MqlRates &r[], const int strength, double &lastHH, double &lastHL, double &lastLH, double &lastLL)
{
   lastHH = lastHL = lastLH = lastLL = 0.0;
   double highs[], lows[];
   datetime ht[], lt[];
   ArrayResize(highs, 0);
   ArrayResize(lows, 0);

   int n = ArraySize(r);
   for(int i = strength; i < n - strength; i++)
   {
      if(MR_IsSwingHigh(r, i, strength))
      {
         int sz = ArraySize(highs);
         ArrayResize(highs, sz + 1);
         ArrayResize(ht, sz + 1);
         highs[sz] = r[i].high;
         ht[sz] = r[i].time;
      }
      if(MR_IsSwingLow(r, i, strength))
      {
         int sz = ArraySize(lows);
         ArrayResize(lows, sz + 1);
         ArrayResize(lt, sz + 1);
         lows[sz] = r[i].low;
         lt[sz] = r[i].time;
      }
   }

   // series: index 0 = plus récent (ArraySetAsSeries sur rates → on a scanné i croissant = ancien→récent si series)
   // Avec rates en series, i=0 est le plus récent. Les swings trouvés en premier sont plus récents.
   int bull = 0, bear = 0;
   if(ArraySize(highs) >= 2)
   {
      // highs[0] plus récent que highs[1] si on a scanné i de strength vers n (i petit = récent en series)
      if(highs[0] > highs[1]) { bull++; lastHH = highs[0]; }
      else { bear++; lastLH = highs[0]; }
   }
   if(ArraySize(lows) >= 2)
   {
      if(lows[0] > lows[1]) { bull++; lastHL = lows[0]; }
      else { bear++; lastLL = lows[0]; }
   }

   if(bull >= 2 && bear == 0) return 1;
   if(bear >= 2 && bull == 0) return -1;
   if(bull > bear) return 1;
   if(bear > bull) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Cœur : DetectMarketState                                           |
//+------------------------------------------------------------------+
MarketAnalysis DetectMarketState(const string symbol, const ENUM_TIMEFRAMES timeframe = PERIOD_M1)
{
   MarketAnalysis a;
   ZeroMemory(a);
   a.state = MARKET_UNKNOWN;
   a.reason = "";

   int lookback = MathMax(25, MR_LookbackBars);
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, timeframe, 0, lookback + MR_SwingStrength + 2, r) < lookback)
   {
      a.reason = "rates_insufficient";
      return a;
   }

   double atr = MR_GetATR(symbol, timeframe, 14);
   if(atr <= 0.0)
      atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 50.0;
   a.atr = atr;

   double adx = MR_GetADX(symbol, timeframe, 14);
   a.adx = adx;

   // --- Box range (high/low du lookback hors bougie 0 en formation optionnel: on inclut 0)
   double maxH = r[0].high, minL = r[0].low;
   for(int i = 1; i < lookback; i++)
   {
      if(r[i].high > maxH) maxH = r[i].high;
      if(r[i].low  < minL) minL = r[i].low;
   }
   a.range_high = maxH;
   a.range_low  = minL;
   a.range_width = maxH - minL;
   a.range_width_atr = (atr > 0.0) ? a.range_width / atr : 0.0;

   // Oscillation: touché tiers haut et bas
   double third = a.range_width / 3.0;
   bool touchTop = false, touchBot = false;
   double avgBody = 0.0;
   for(int i = 0; i < lookback; i++)
   {
      if(r[i].high >= maxH - third) touchTop = true;
      if(r[i].low  <= minL + third) touchBot = true;
      avgBody += MathAbs(r[i].close - r[i].open);
   }
   avgBody /= (double)lookback;
   bool oscillating = touchTop && touchBot;
   bool smallBodies = (a.range_width > 0.0 && avgBody < a.range_width * 0.22);

   // Pente EMA21 approx via closes
   double ema = r[lookback - 1].close;
   double k = 2.0 / (21.0 + 1.0);
   for(int i = lookback - 2; i >= 0; i--)
      ema = r[i].close * k + ema * (1.0 - k);
   double slopeNorm = (atr > 0.0) ? (r[0].close - ema) / atr : 0.0;

   // Structure
   double lhh, lhl, llh, lll;
   int structBias = MR_StructureBias(r, MR_SwingStrength, lhh, lhl, llh, lll);

   // Breakouts
   double buf = atr * MathMax(0.0, MR_BreakoutBufferATR);
   a.breakout_up   = (r[0].close > maxH + buf);
   a.breakout_down = (r[0].close < minL - buf);

   // --- Score RANGE
   double rangeScore = 0.0;
   if(a.range_width_atr >= MR_MinRangeWidthATR && a.range_width_atr <= MR_MaxRangeWidthATR)
      rangeScore += 30.0;
   if(oscillating) rangeScore += 25.0;
   if(smallBodies) rangeScore += 15.0;
   if(adx > 0.0 && adx < MR_ADX_RangeMax) rangeScore += 20.0;
   if(MathAbs(slopeNorm) < 0.35) rangeScore += 10.0;
   if(structBias == 0) rangeScore += 10.0;

   // --- Score TREND
   double trendScore = 0.0;
   if(adx >= MR_ADX_TrendMin) trendScore += 30.0;
   else if(adx >= MR_ADX_RangeMax) trendScore += 15.0;
   if(structBias == 1) trendScore += 25.0;
   if(structBias == -1) trendScore += 25.0;
   if(MathAbs(slopeNorm) > 0.8) trendScore += 20.0;
   if(!oscillating && a.range_width_atr > MR_MaxRangeWidthATR * 0.85) trendScore += 10.0;
   // extension mono-directionnelle
   int upBars = 0, dnBars = 0;
   for(int i = 1; i <= 8 && i < lookback; i++)
   {
      if(r[i].close > r[i].open) upBars++;
      if(r[i].close < r[i].open) dnBars++;
   }
   if(upBars >= 6) { trendScore += 15.0; structBias = (structBias == 0 ? 1 : structBias); }
   if(dnBars >= 6) { trendScore += 15.0; structBias = (structBias == 0 ? -1 : structBias); }

   a.trend_dir = structBias;
   if(a.trend_dir == 0)
   {
      if(slopeNorm > 0.5) a.trend_dir = 1;
      else if(slopeNorm < -0.5) a.trend_dir = -1;
   }
   a.trend_strength = MathMin(100.0, trendScore);

   // --- Correction % (retracement depuis extrême récent de la jambe)
   double legHigh = r[1].high, legLow = r[1].low;
   for(int i = 1; i < MathMin(20, lookback); i++)
   {
      if(r[i].high > legHigh) legHigh = r[i].high;
      if(r[i].low  < legLow)  legLow  = r[i].low;
   }
   double px = r[0].close;
   a.correction_percent = 0.0;
   if(a.trend_dir > 0 && legHigh > legLow)
      a.correction_percent = 100.0 * (legHigh - px) / (legHigh - legLow);
   else if(a.trend_dir < 0 && legHigh > legLow)
      a.correction_percent = 100.0 * (px - legLow) / (legHigh - legLow);

   bool corrCandidate = (a.trend_strength >= 40.0 &&
                         a.correction_percent >= MR_CorrectionMinPct &&
                         a.correction_percent <= MR_CorrectionMaxPct &&
                         adx >= MR_ADX_RangeMax * 0.85);

   // --- Classification
   if(a.breakout_up && rangeScore >= 50.0)
   {
      a.state = MARKET_TREND_UP;
      a.confidence = MathMin(95.0, 60.0 + (adx > 0 ? MathMin(adx, 30.0) : 10.0));
      a.reason = "breakout_up_from_range";
      a.trend_dir = 1;
   }
   else if(a.breakout_down && rangeScore >= 50.0)
   {
      a.state = MARKET_TREND_DOWN;
      a.confidence = MathMin(95.0, 60.0 + (adx > 0 ? MathMin(adx, 30.0) : 10.0));
      a.reason = "breakout_down_from_range";
      a.trend_dir = -1;
   }
   else if(rangeScore >= trendScore && rangeScore >= 55.0)
   {
      a.state = MARKET_RANGE;
      a.confidence = MathMin(95.0, rangeScore);
      a.reason = StringFormat("range score=%.0f adx=%.1f width=%.2fATR osc=%d",
                              rangeScore, adx, a.range_width_atr, oscillating ? 1 : 0);
      a.trend_dir = 0;
   }
   else if(corrCandidate && a.trend_dir > 0)
   {
      a.state = MARKET_CORRECTION_DOWN;
      a.confidence = MathMin(90.0, 50.0 + a.correction_percent * 0.4);
      a.reason = StringFormat("pullback_in_uptrend corr=%.1f%%", a.correction_percent);
   }
   else if(corrCandidate && a.trend_dir < 0)
   {
      a.state = MARKET_CORRECTION_UP;
      a.confidence = MathMin(90.0, 50.0 + a.correction_percent * 0.4);
      a.reason = StringFormat("bounce_in_downtrend corr=%.1f%%", a.correction_percent);
   }
   else if(trendScore >= 50.0 && a.trend_dir > 0)
   {
      a.state = MARKET_TREND_UP;
      a.confidence = MathMin(95.0, trendScore);
      a.reason = StringFormat("trend_up adx=%.1f struct=%d", adx, structBias);
   }
   else if(trendScore >= 50.0 && a.trend_dir < 0)
   {
      a.state = MARKET_TREND_DOWN;
      a.confidence = MathMin(95.0, trendScore);
      a.reason = StringFormat("trend_down adx=%.1f struct=%d", adx, structBias);
   }
   else
   {
      a.state = MARKET_UNKNOWN;
      a.confidence = 40.0;
      a.reason = StringFormat("mixed rangeScore=%.0f trendScore=%.0f", rangeScore, trendScore);
   }

   return a;
}

//+------------------------------------------------------------------+
//| Mise à jour cache (appel OnTick / nouvelle bougie)                 |
//+------------------------------------------------------------------+
void MR_Update(const string symbol, const ENUM_TIMEFRAMES tf = PERIOD_M1)
{
   datetime t = iTime(symbol, tf, 0);
   // Toujours recalculer le breakout sur le close courant; structure au max 1x / barre
   bool newBar = (symbol != g_mrLastSymbol || t != g_mrLastBarTime);
   if(newBar || g_mrLast.state == MARKET_UNKNOWN)
   {
      g_mrLast = DetectMarketState(symbol, tf);
      g_mrLastSymbol = symbol;
      g_mrLastBarTime = t;
   }
   else
   {
      // refresh breakout flags only
      double atr = (g_mrLast.atr > 0.0) ? g_mrLast.atr : MR_GetATR(symbol, tf, 14);
      double buf = atr * MathMax(0.0, MR_BreakoutBufferATR);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(g_mrLast.range_high > 0.0)
         g_mrLast.breakout_up = (bid > g_mrLast.range_high + buf);
      if(g_mrLast.range_low > 0.0)
         g_mrLast.breakout_down = (bid < g_mrLast.range_low - buf);

      // Si cassure confirmée pendant la barre → promouvoir en tendance
      if(g_mrLast.state == MARKET_RANGE)
      {
         if(g_mrLast.breakout_up)
         {
            g_mrLast.state = MARKET_TREND_UP;
            g_mrLast.trend_dir = 1;
            g_mrLast.reason = "intrabar_breakout_up";
         }
         else if(g_mrLast.breakout_down)
         {
            g_mrLast.state = MARKET_TREND_DOWN;
            g_mrLast.trend_dir = -1;
            g_mrLast.reason = "intrabar_breakout_down";
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gate d'entrée pour l'EA SMC                                        |
//| dirSign: +1 BUY / -1 SELL                                          |
//| return true = autoriser                                            |
//+------------------------------------------------------------------+
bool MR_AllowsEntry(const string symbol, const int dirSign, string &whyOut)
{
   whyOut = "";
   if(!MR_Enable) { whyOut = "MR_off"; return true; }
   if(dirSign == 0) { whyOut = "no_dir"; return false; }

   MR_Update(symbol, PERIOD_M1);
   MarketAnalysis a = g_mrLast;

   if(a.confidence < MR_MinConfidence && a.state != MARKET_RANGE)
   {
      whyOut = "low_confidence:" + a.reason;
      return true; // pas assez sûr pour bloquer
   }

   // RANGE strict
   if(a.state == MARKET_RANGE)
   {
      if(!MR_BlockRangeEntries)
      {
         whyOut = "range_allow_flag";
         return true;
      }
      if(MR_RequireBreakoutFromRange)
      {
         if(dirSign > 0 && a.breakout_up)
         {
            whyOut = "range_breakout_up";
            return true;
         }
         if(dirSign < 0 && a.breakout_down)
         {
            whyOut = "range_breakout_down";
            return true;
         }
         whyOut = StringFormat("RANGE no breakout box=[%.5f-%.5f] conf=%.0f | %s",
                               a.range_low, a.range_high, a.confidence, a.reason);
         return false;
      }
      whyOut = "RANGE blocked";
      return false;
   }

   // Correction contre le sens demandé
   if(MR_BlockCorrectionAgainstTrend)
   {
      // BUY pendant pullback d'un uptrend : on peut autoriser si correction assez profonde (OTE-like)
      // mais on BLOQUE BUY si on est en CORRECTION_UP (rebond contre downtrend) sans retournement
      if(dirSign > 0 && a.state == MARKET_CORRECTION_UP)
      {
         whyOut = StringFormat("CORRECTION_UP (contre-trend BUY) corr=%.1f%%", a.correction_percent);
         return false;
      }
      if(dirSign < 0 && a.state == MARKET_CORRECTION_DOWN)
      {
         whyOut = StringFormat("CORRECTION_DOWN (contre-trend SELL) corr=%.1f%%", a.correction_percent);
         return false;
      }
      // BUY en pullback uptrend (CORRECTION_DOWN) : autorisé seulement si correction >= 30%
      if(dirSign > 0 && a.state == MARKET_CORRECTION_DOWN && a.correction_percent < 30.0)
      {
         whyOut = StringFormat("pullback trop peu profond (%.1f%%) — attendre 30%%+", a.correction_percent);
         return false;
      }
      if(dirSign < 0 && a.state == MARKET_CORRECTION_UP && a.correction_percent < 30.0)
      {
         whyOut = StringFormat("rebond trop peu profond (%.1f%%) — attendre 30%%+", a.correction_percent);
         return false;
      }
   }

   // Tendance opposée
   if(a.state == MARKET_TREND_DOWN && dirSign > 0)
   {
      whyOut = "TREND_DOWN — BUY refusé";
      return false;
   }
   if(a.state == MARKET_TREND_UP && dirSign < 0)
   {
      whyOut = "TREND_UP — SELL refusé";
      return false;
   }

   whyOut = MR_StateToString(a.state) + " OK | " + a.reason;
   return true;
}

// Surcharge sans string out
bool MR_AllowsEntry(const string symbol, const int dirSign)
{
   string dummy;
   return MR_AllowsEntry(symbol, dirSign, dummy);
}

#endif // SMC_MARKET_REGIME_MQH
