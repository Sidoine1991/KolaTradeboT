//+------------------------------------------------------------------+
//| SMC_MarketIntelligence.mqh                                       |
//| Market regime detection, correlation filter, session quality     |
//| Am�liore la s�lection des trades en filtrant par r�gime/session  |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.00"
#property strict

#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Forward declarations from main EA                                |
//+------------------------------------------------------------------+
ENUM_SYMBOL_CATEGORY SMC_GetSymbolCategory(const string symbol);

// InpMagicNumber is input global in SMC_Universal.mq5 � accessible directly

//+------------------------------------------------------------------+
//| Module-level CPositionInfo (main file declares 'posInfo' later)  |
//+------------------------------------------------------------------+
CPositionInfo g_posInfoMI;

//+------------------------------------------------------------------+
//| Configuration variables                                          |
//+------------------------------------------------------------------+
bool   ExtUseRegimeFilter       = true;    // Bloquer hors r�gime id�al
double ExtRangeATRPercentile    = 0.25;    // Range si ATR < 25e percentile
double ExtTrendADXThreshold     = 28.0;    // Trend fort si ADX > 28
double ExtExtremeATRPercentile  = 0.85;    // Volatilit� extr�me si ATR > 85e percentile

bool   ExtUseCorrelationFilter  = true;    // Bloquer positions corr�l�es
int    ExtMaxPerGroup           = 1;       // Max positions par groupe

bool   ExtUseSessionQuality     = true;    // Filtrer par qualit� de session
double ExtMinSessionQuality     = 50.0;    // Qualit� min (0-100) pour trader

//+------------------------------------------------------------------+
//| Market regime enum                                               |
//+------------------------------------------------------------------+
enum ENUM_MARKET_REGIME
{
   REGIME_UNKNOWN      = 0,
   REGIME_RANGE        = 1,   // March� range / sideway
   REGIME_TREND_BULL   = 2,   // Tendance haussi�re mod�r�e
   REGIME_TREND_BEAR   = 3,   // Tendance baissi�re mod�r�e
   REGIME_STRONG_BULL  = 4,   // Tendance haussi�re forte
   REGIME_STRONG_BEAR  = 5,   // Tendance baissi�re forte
   REGIME_VOLATILE     = 6,   // Volatilit� excessive
   REGIME_SQUEEZE      = 7    // Compression (pr�-mouvement)
};

//+------------------------------------------------------------------+
//| Correlation groups                                               |
//+------------------------------------------------------------------+
enum ENUM_CORRELATION_GROUP
{
   CORR_GROUP_NONE     = 0,
   CORR_GROUP_EUR      = 1,   // EURUSD, EURJPY, EURGBP etc.
   CORR_GROUP_USD      = 2,   // USDJPY, USDCHF, USDCAD
   CORR_GROUP_GBP      = 3,   // GBPUSD, GBPJPY
   CORR_GROUP_AUD      = 4,   // AUDUSD, AUDJPY, NZDUSD
   CORR_GROUP_METAL    = 5,   // XAUUSD, XAGUSD
   CORR_GROUP_CRYPTO   = 6,   // BTCUSD, ETHUSD
   CORR_GROUP_INDEX    = 7,   // US30, NAS100, SP500
   CORR_GROUP_OIL      = 8,   // WTI, BRENT
   CORR_GROUP_BC       = 9    // Boom/Crash (tous)
};

//+------------------------------------------------------------------+
//| Session quality structure                                        |
//+------------------------------------------------------------------+
struct SMC_SessionInfo
{
   int    hourBegin;    // Heure de d�but (UTC)
   int    hourEnd;      // Heure de fin (UTC)
   string label;        // "London AM", "NY Open", etc.
   double quality;      // Qualit� 0-100 pour ce symbole/cat�gorie
};

//+------------------------------------------------------------------+
//| Globals                                                          |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME g_marketRegime       = REGIME_UNKNOWN;
double             g_regimeScore        = 50.0;     // 0-100 adapt� au r�gime
string             g_regimeName         = "UNKNOWN";
datetime           g_regimeLastUpdate   = 0;

// Handles ATR pour percentile
int                g_regimeATR_Handle   = INVALID_HANDLE;
int                g_regimeADX_Handle   = INVALID_HANDLE;
int                g_regimeBB_Handle    = INVALID_HANDLE;

// Positions par groupe de corr�lation
int                g_groupPositionCount[10];

// Session quality cache
double             g_currentSessionQuality = 50.0;

//+------------------------------------------------------------------+
//| Get correlation group for a symbol                               |
//+------------------------------------------------------------------+
ENUM_CORRELATION_GROUP SMC_GetCorrelationGroup(const string symbol)
{
   string s = symbol;
   StringToUpper(s);

   // Boom/Crash et �quivalents
   if(StringFind(s, "BOOM") >= 0 || StringFind(s, "CRASH") >= 0 ||
      StringFind(s, "PAINX") >= 0 || StringFind(s, "GAINX") >= 0)
      return CORR_GROUP_BC;

   // M�taux
   if(StringFind(s, "XAU") >= 0 || StringFind(s, "XAG") >= 0 ||
      StringFind(s, "GOLD") >= 0 || StringFind(s, "SILVER") >= 0)
      return CORR_GROUP_METAL;

   // Crypto
   if(StringFind(s, "BTC") >= 0 || StringFind(s, "ETH") >= 0 ||
      StringFind(s, "SOL") >= 0 || StringFind(s, "XRP") >= 0)
      return CORR_GROUP_CRYPTO;

   // Indices
   if(StringFind(s, "US30") >= 0 || StringFind(s, "NAS100") >= 0 ||
      StringFind(s, "SP500") >= 0 || StringFind(s, "DJ30") >= 0 ||
      StringFind(s, "JPN225") >= 0 || StringFind(s, "GER30") >= 0 ||
      StringFind(s, "UK100") >= 0)
      return CORR_GROUP_INDEX;

   // P�trole
   if(StringFind(s, "WTI") >= 0 || StringFind(s, "BRENT") >= 0 ||
      StringFind(s, "OIL") >= 0 || StringFind(s, "CL") >= 0)
      return CORR_GROUP_OIL;

   // Paires Forex
   if(StringFind(s, "EUR") >= 0) return CORR_GROUP_EUR;
   if(StringFind(s, "GBP") >= 0) return CORR_GROUP_GBP;
   if(StringFind(s, "AUD") >= 0 || StringFind(s, "NZD") >= 0) return CORR_GROUP_AUD;

   // USD pairs (JPY, CHF, CAD)
   if(StringFind(s, "USD") >= 0)
   {
      if(StringFind(s, "JPY") >= 0 || StringFind(s, "CHF") >= 0 ||
         StringFind(s, "CAD") >= 0)
         return CORR_GROUP_USD;
   }

   return CORR_GROUP_NONE;
}

//+------------------------------------------------------------------+
//| Count current positions per correlation group                    |
//+------------------------------------------------------------------+
void SMC_UpdateGroupCounts()
{
   ArrayInitialize(g_groupPositionCount, 0);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_posInfoMI.SelectByIndex(i)) continue;
      if(g_posInfoMI.Magic() != InpMagicNumber) continue;

      ENUM_CORRELATION_GROUP grp = SMC_GetCorrelationGroup(g_posInfoMI.Symbol());
      if(grp > CORR_GROUP_NONE && grp < 10)
         g_groupPositionCount[(int)grp]++;
   }
}

//+------------------------------------------------------------------+
//| Check if correlation allows new trade                            |
//+------------------------------------------------------------------+
bool SMC_CorrelationAllowsTrade(const string symbol, const int dirSign)
{
   if(!ExtUseCorrelationFilter) return true;

   SMC_UpdateGroupCounts();
   ENUM_CORRELATION_GROUP grp = SMC_GetCorrelationGroup(symbol);

   if(grp == CORR_GROUP_NONE) return true;
   if(grp >= 10) return true;

   // G�rer les paires EUR: EURUSD long + EURJPY long = m�me direction EUR
   // Compter uniquement les positions dans la M�ME direction
   int sameDirCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!g_posInfoMI.SelectByIndex(i)) continue;
      if(g_posInfoMI.Magic() != InpMagicNumber) continue;

      ENUM_CORRELATION_GROUP posGrp = SMC_GetCorrelationGroup(g_posInfoMI.Symbol());
      if(posGrp != grp) continue;

      int posDir = (g_posInfoMI.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
      if(posDir == dirSign)
         sameDirCount++;
   }

   if(sameDirCount >= ExtMaxPerGroup)
   {
      Print(StringFormat("[CORR] BLOQUE � %s direction %d: d�j� %d position(s) dans le groupe #%d",
            symbol, dirSign, sameDirCount, (int)grp));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Get ATR percentile (simplifi� � compare aux N derni�res barres)  |
//+------------------------------------------------------------------+
double SMC_GetATRPercentile(const string symbol, const ENUM_TIMEFRAMES tf, const int period, const int lookback)
{
   double atrValues[];
   ArraySetAsSeries(atrValues, true);

   int handle = iATR(symbol, tf, period);
   if(handle == INVALID_HANDLE) return 0.5;

   if(CopyBuffer(handle, 0, 0, lookback + 1, atrValues) < lookback + 1)
   {
      IndicatorRelease(handle);
      return 0.5;
   }
   IndicatorRelease(handle);

   double currentATR = atrValues[0];

   // Compter combien de valeurs sont sous la valeur actuelle
   int belowCount = 0;
   for(int i = 1; i <= lookback; i++)
   {
      if(atrValues[i] <= currentATR)
         belowCount++;
   }

   return (double)belowCount / lookback;
}

//+------------------------------------------------------------------+
//| Detect market regime for a symbol                                |
//+------------------------------------------------------------------+
ENUM_MARKET_REGIME SMC_DetectRegime(const string symbol)
{
   // ADX pour force de tendance
   double adxVal = 0;
   double adxBuf[];
   ArraySetAsSeries(adxBuf, true);
   int adxHandle = iADX(symbol, PERIOD_H1, 14);
   if(adxHandle != INVALID_HANDLE && CopyBuffer(adxHandle, 0, 0, 1, adxBuf) >= 1)
      adxVal = adxBuf[0];
   if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);

   // ATR pour volatilit�
   double atrCurrent = 0;
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   int atrH = iATR(symbol, PERIOD_H1, 14);
   if(atrH != INVALID_HANDLE && CopyBuffer(atrH, 0, 0, 1, atrBuf) >= 1)
      atrCurrent = atrBuf[0];
   if(atrH != INVALID_HANDLE) IndicatorRelease(atrH);

   // BB width pour squeeze / range
   double bbWidth = 0;
   double bbUpper[], bbLower[];
   ArraySetAsSeries(bbUpper, true);
   ArraySetAsSeries(bbLower, true);
   int bbH = iBands(symbol, PERIOD_H1, 20, 0, 2.0, PRICE_CLOSE);
   if(bbH != INVALID_HANDLE && CopyBuffer(bbH, 1, 0, 1, bbUpper) >= 1 && CopyBuffer(bbH, 2, 0, 1, bbLower) >= 1)
      bbWidth = bbUpper[0] - bbLower[0];
   if(bbH != INVALID_HANDLE) IndicatorRelease(bbH);

   // EMA50 slope pour direction
   double emaBuf[];
   ArraySetAsSeries(emaBuf, true);
   int emaH = iMA(symbol, PERIOD_H1, 50, 0, MODE_EMA, PRICE_CLOSE);
   int emaDir = 0;
   if(emaH != INVALID_HANDLE && CopyBuffer(emaH, 0, 0, 3, emaBuf) >= 3)
   {
      if(emaBuf[0] > emaBuf[2] * 1.001) emaDir = 1;     // pente haussi�re significative
      else if(emaBuf[0] < emaBuf[2] * 0.999) emaDir = -1; // pente baissi�re significative
   }
   if(emaH != INVALID_HANDLE) IndicatorRelease(emaH);

   // Calculer ATR percentile sur 48h (48 barres H1)
   double atrPct = SMC_GetATRPercentile(symbol, PERIOD_H1, 14, 48);

   // --- Logique de d�cision ---

   // Volatilit� extr�me
   if(atrPct > ExtExtremeATRPercentile)
      return REGIME_VOLATILE;

   // BB squeeze (BB tr�s serr� = compression)
   if(bbWidth > 0 && atrCurrent > 0)
   {
      double bbPct = SMC_GetATRPercentile(symbol, PERIOD_H1, 20, 48); // proxy
      if(bbPct < ExtRangeATRPercentile)
         return REGIME_SQUEEZE;
   }

   // Trend fort
   if(adxVal > ExtTrendADXThreshold)
   {
      if(emaDir == 1) return REGIME_STRONG_BULL;
      if(emaDir == -1) return REGIME_STRONG_BEAR;
      return REGIME_VOLATILE; // ADX haut mais direction ambigu�
   }

   // Trend mod�r�
   if(adxVal > 20)
   {
      if(emaDir == 1) return REGIME_TREND_BULL;
      if(emaDir == -1) return REGIME_TREND_BEAR;
   }

   // Range (ADX bas + BB serr�)
   if(atrPct < ExtRangeATRPercentile || adxVal < 20)
      return REGIME_RANGE;

   return REGIME_UNKNOWN;
}

//+------------------------------------------------------------------+
//| Get regime score (0-100) � how favorable for SMC trades         |
//+------------------------------------------------------------------+
double SMC_GetRegimeScore(const ENUM_MARKET_REGIME regime, const int dirSign)
{
   switch(regime)
   {
      case REGIME_STRONG_BULL:
         return (dirSign == 1) ? 90.0 : 20.0;  // Favorable BUY only
      case REGIME_STRONG_BEAR:
         return (dirSign == -1) ? 90.0 : 20.0; // Favorable SELL only
      case REGIME_TREND_BULL:
         return (dirSign == 1) ? 80.0 : 30.0;
      case REGIME_TREND_BEAR:
         return (dirSign == -1) ? 80.0 : 30.0;
      case REGIME_RANGE:
         return 30.0;  // Mauvais pour SMC
      case REGIME_VOLATILE:
         return 15.0;  // Tr�s mauvais
      case REGIME_SQUEEZE:
         return (dirSign == 1 || dirSign == -1) ? 60.0 : 50.0; // Pr�paration mouvement
      default:
         return 50.0;
   }
}

//+------------------------------------------------------------------+
//| Check if regime allows trade                                     |
//+------------------------------------------------------------------+
bool SMC_RegimeAllowsTrade(const string symbol, const int dirSign, double &outScore)
{
   if(!ExtUseRegimeFilter)
   {
      outScore = 100.0;
      return true;
   }

   ENUM_MARKET_REGIME regime = SMC_DetectRegime(symbol);

   // Mettre � jour globals pour dashboard
   g_marketRegime = regime;
   g_regimeScore = SMC_GetRegimeScore(regime, dirSign);
   outScore = g_regimeScore;

   switch(regime)
   {
      case REGIME_RANGE:
         Print(StringFormat("[REGIME] BLOQUE %s � March� RANGE (ATR bas, pas de tendance) | Score=%.0f",
               symbol, g_regimeScore));
         return false;

      case REGIME_VOLATILE:
         Print(StringFormat("[REGIME] BLOQUE %s � Volatilit� EXTR�ME (ATR > %.0f%% percentile) | Score=%.0f",
               symbol, ExtExtremeATRPercentile * 100, g_regimeScore));
         return false;

      case REGIME_STRONG_BULL:
         if(dirSign == -1)
         {
            Print(StringFormat("[REGIME] BLOQUE %s SELL � March� FORTEMENT HAUSSIER | Score=%.0f",
                  symbol, g_regimeScore));
            return false;
         }
         return true;

      case REGIME_STRONG_BEAR:
         if(dirSign == 1)
         {
            Print(StringFormat("[REGIME] BLOQUE %s BUY � March� FORTEMENT BAISSIER | Score=%.0f",
                  symbol, g_regimeScore));
            return false;
         }
         return true;

      case REGIME_SQUEEZE:
         // Squeeze: neutre, laisser passer si autres conditions OK
         return true;

      default:
         return true;
   }
}

//+------------------------------------------------------------------+
//| Session quality data                                             |
//| Chaque cat�gorie a des cr�neaux horaires de qualit� optimale     |
//+------------------------------------------------------------------+
double SMC_GetSessionQuality(const string symbol, const int utcHour)
{
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
   ENUM_CORRELATION_GROUP grp = SMC_GetCorrelationGroup(symbol);

   // Qualit� par heure UTC pour chaque cat�gorie (0-100)
   // Heures: 0-23 UTC

   if(cat == SYM_FOREX)
   {
      // Forex: London + NY overlap = meilleur
      if(utcHour >= 8 && utcHour <= 11) return 90;   // London AM + NY overlap (13-16h)
      if(utcHour >= 13 && utcHour <= 16) return 85;   // NY session
      if(utcHour >= 2 && utcHour <= 5)   return 60;   // Asian session
      if(utcHour >= 6 && utcHour <= 7)   return 70;   // London open
      return 30;  // Hors session
   }

   if(cat == SYM_METAL)
   {
      // XAUUSD: London + NY
      if(utcHour >= 8 && utcHour <= 11) return 85;
      if(utcHour >= 12 && utcHour <= 17) return 90;   // NY peak
      if(utcHour >= 2 && utcHour <= 5)   return 50;
      return 25;
   }

   if(cat == SYM_BOOM_CRASH || grp == CORR_GROUP_BC)
   {
      // Boom/Crash: suivent les sessions actives
      if(utcHour >= 8 && utcHour <= 17) return 80;
      if(utcHour >= 6 && utcHour <= 7)   return 60;
      if(utcHour >= 18 && utcHour <= 20) return 50;
      return 30;
   }

   if(cat == SYM_CRYPTO)
   {
      // Crypto: 24h, mais meilleur pendant NY + Asian overlap
      if(utcHour >= 13 && utcHour <= 20) return 75;
      if(utcHour >= 2 && utcHour <= 8)   return 65;
      return 40;
   }

   if(cat == SYM_VOLATILITY)
   {
      if(utcHour >= 9 && utcHour <= 16) return 80;
      return 35;
   }

   // Default
   return 50;
}

//+------------------------------------------------------------------+
//| Check session quality                                            |
//+------------------------------------------------------------------+
bool SMC_SessionQualityAllowsTrade(const string symbol)
{
   if(!ExtUseSessionQuality) return true;

   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   int utcHour = dt.hour;

   double quality = SMC_GetSessionQuality(symbol, utcHour);
   g_currentSessionQuality = quality;

   if(quality < ExtMinSessionQuality)
   {
      Print(StringFormat("[SESSION] BLOQUE %s � Heure %02d:00 UTC qualit�=%.0f (min %.0f)",
            symbol, utcHour, quality, ExtMinSessionQuality));
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| MTF structure enhancement � H4/H1/M15 alignment check           |
//| Returns number of aligned TFs (0-3) and detailed scores         |
//+------------------------------------------------------------------+
int SMC_GetMTFAlignment(const string symbol, const int dirSign,
                        double &outH4score, double &outH1score, double &outM15score)
{
   outH4score = 50.0;
   outH1score = 50.0;
   outM15score = 50.0;
   int aligned = 0;

   // --- H4: EMA50 slope + price vs EMA ---
   double h4ema[];
   ArraySetAsSeries(h4ema, true);
   double h4close[];
   ArraySetAsSeries(h4close, true);
   int h4emaH = iMA(symbol, PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE);
   if(h4emaH != INVALID_HANDLE && CopyBuffer(h4emaH, 0, 0, 5, h4ema) >= 5)
   {
      MqlRates h4r[];
      ArraySetAsSeries(h4r, true);
      if(CopyRates(symbol, PERIOD_H4, 0, 2, h4r) >= 2)
      {
         double slope = (h4ema[0] - h4ema[2]) / h4ema[2] * 10000;
         int h4dir = (slope > 0.5) ? 1 : (slope < -0.5) ? -1 : 0;
         if(h4dir == dirSign)
         {
            aligned++;
            outH4score = 80.0 + MathMin(MathAbs(slope) * 5, 20.0);
         }
         else if(h4dir == 0)
            outH4score = 40.0;
         else
            outH4score = 20.0;
      }
      // Price vs EMA
      if(h4r[0].close > h4ema[0] && dirSign == 1) outH4score += 10;
      else if(h4r[0].close < h4ema[0] && dirSign == -1) outH4score += 10;
      else outH4score -= 10;
   }
   if(h4emaH != INVALID_HANDLE) IndicatorRelease(h4emaH);

   // --- H1: EMA21 + structure (swing HL) ---
   double h1ema21[];
   ArraySetAsSeries(h1ema21, true);
   MqlRates h1r[];
   ArraySetAsSeries(h1r, true);
   int h1emaH = iMA(symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
   if(h1emaH != INVALID_HANDLE && CopyBuffer(h1emaH, 0, 0, 5, h1ema21) >= 5)
   {
      double h1slope = (h1ema21[0] - h1ema21[4]) / h1ema21[4] * 10000;
      int h1dir = (h1slope > 0.3) ? 1 : (h1slope < -0.3) ? -1 : 0;
      if(h1dir == dirSign)
      {
         aligned++;
         outH1score = 75.0 + MathMin(MathAbs(h1slope) * 5, 25.0);
      }
      else if(h1dir == 0)
         outH1score = 35.0;
      else
         outH1score = 15.0;

      // Structure: HH/HL detection
      if(CopyRates(symbol, PERIOD_H1, 0, 10, h1r) >= 10)
      {
         double swingHigh = h1r[0].high;
         double swingLow = h1r[0].low;
         for(int i = 1; i < 10; i++)
         {
            if(h1r[i].high > swingHigh) swingHigh = h1r[i].high;
            if(h1r[i].low < swingLow) swingLow = h1r[i].low;
         }
         bool makingHigherHigh = (h1r[0].high > h1r[2].high && h1r[0].high > h1r[4].high);
         bool makingLowerLow = (h1r[0].low < h1r[2].low && h1r[0].low < h1r[4].low);

         if(makingHigherHigh && dirSign == 1) outH1score += 15;
         else if(makingLowerLow && dirSign == -1) outH1score += 15;
         else if((makingHigherHigh && dirSign == -1) || (makingLowerLow && dirSign == 1)) outH1score -= 15;
      }
   }
   if(h1emaH != INVALID_HANDLE) IndicatorRelease(h1emaH);

   // --- M15: RSI + momentum + M1 micro-structure ---
   double m15rsi[];
   ArraySetAsSeries(m15rsi, true);
   MqlRates m15r[];
   ArraySetAsSeries(m15r, true);
   int m15rsiH = iRSI(symbol, PERIOD_M15, 14, PRICE_CLOSE);
   if(m15rsiH != INVALID_HANDLE && CopyBuffer(m15rsiH, 0, 0, 3, m15rsi) >= 3)
   {
      int m15dir = 0;
      if(m15rsi[0] > 55) m15dir = 1;
      else if(m15rsi[0] < 45) m15dir = -1;

      if(m15dir == dirSign)
      {
         aligned++;
         // Plus le RSI est fort/extr�me (dans la bonne direction), meilleur est le score
         double rsiStrength = (dirSign == 1) ? (m15rsi[0] - 50) : (50 - m15rsi[0]);
         outM15score = 65.0 + MathMin(rsiStrength * 1.5, 35.0);
      }
      else if(m15dir == 0)
         outM15score = 30.0;
      else
         outM15score = 10.0;

      // V�rifier momentum: RSI progression
      if(CopyRates(symbol, PERIOD_M15, 0, 3, m15r) >= 3)
      {
         double body1 = m15r[0].close - m15r[0].open;
         double body2 = m15r[1].close - m15r[1].open;
         double body3 = m15r[2].close - m15r[2].open;

         // Momentum croissant dans la bonne direction
         bool momUp = (body1 > body2 && body2 > body3);
         bool momDown = (body1 < body2 && body2 < body3);

         if((momUp && dirSign == 1) || (momDown && dirSign == -1))
         {
            aligned++;
            outM15score += 15;
         }
      }
   }
   if(m15rsiH != INVALID_HANDLE) IndicatorRelease(m15rsiH);

   // Clamp scores
   outH4score = MathMax(0, MathMin(100, outH4score));
   outH1score = MathMax(0, MathMin(100, outH1score));
   outM15score = MathMax(0, MathMin(100, outM15score));

   return aligned;
}

//+------------------------------------------------------------------+
//| Main market filter � combine regime + correlation + session      |
//| Returns true if trade is allowed, false if blocked               |
//+------------------------------------------------------------------+
bool SMC_MarketAllowsTrade(const string symbol, const int dirSign, double &totalScore)
{
   totalScore = 100.0;
   double componentScore = 100.0;
   int components = 0;

   // 1. R�gime filter
   double regimeScore = 100.0;
   if(ExtUseRegimeFilter)
   {
      if(!SMC_RegimeAllowsTrade(symbol, dirSign, regimeScore))
      {
         totalScore = 0;
         return false;
      }
      componentScore += regimeScore;
      components++;
   }

   // 2. Session quality
   double sessionScore = 100.0;
   if(ExtUseSessionQuality)
   {
      if(!SMC_SessionQualityAllowsTrade(symbol))
      {
         totalScore = 0;
         return false;
      }
      sessionScore = g_currentSessionQuality;
      componentScore += sessionScore;
      components++;
   }

   // 3. MTF alignment
   double h4s, h1s, m15s;
   int aligned = SMC_GetMTFAlignment(symbol, dirSign, h4s, h1s, m15s);
   double mtfScore = (h4s + h1s + m15s) / 3.0;
   componentScore += mtfScore;
   components++;

   // 4. Correlation
   if(ExtUseCorrelationFilter)
   {
      if(!SMC_CorrelationAllowsTrade(symbol, dirSign))
      {
         totalScore = 0;
         return false;
      }
   }

   // Calculer le score total
   if(components > 0)
      totalScore = componentScore / components;
   else
      totalScore = 100.0;

   return true;
}

//+------------------------------------------------------------------+
//| Get readable regime name                                         |
//+------------------------------------------------------------------+
string SMC_RegimeToString(const ENUM_MARKET_REGIME regime)
{
   switch(regime)
   {
      case REGIME_RANGE:       return "RANGE";
      case REGIME_TREND_BULL:  return "TREND_BULL";
      case REGIME_TREND_BEAR:  return "TREND_BEAR";
      case REGIME_STRONG_BULL: return "STRONG_BULL";
      case REGIME_STRONG_BEAR: return "STRONG_BEAR";
      case REGIME_VOLATILE:    return "VOLATILE";
      case REGIME_SQUEEZE:     return "SQUEEZE";
      default:                 return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Init module                                                      |
//+------------------------------------------------------------------+
void SMC_InitMarketIntelligence()
{
   ArrayInitialize(g_groupPositionCount, 0);
   g_marketRegime = REGIME_UNKNOWN;
   g_regimeScore = 50.0;
   g_currentSessionQuality = 50.0;
   Print("[SMC-Intelligence] Module initialis� | Regime=", ExtUseRegimeFilter,
         " Corr=", ExtUseCorrelationFilter, " Session=", ExtUseSessionQuality);
}
//+------------------------------------------------------------------+
