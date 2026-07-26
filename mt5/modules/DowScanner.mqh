//+------------------------------------------------------------------+
//| DowScanner.mqh — Multi-symbol opportunity scanner (DOW engine)   |
//| Scanne tous les symboles, calcule un score composite,             |
//| identifie le meilleur DOW trendline + GOM alignment.              |
//| MQL5-compatible: no struct pointers, index-based array access.    |
//+------------------------------------------------------------------+
#ifndef TM_DOW_SCANNER_MQH
#define TM_DOW_SCANNER_MQH

#include "TMState.mqh"
#include "TMDebug.mqh"
#include "HTTPTransport.mqh"

// ═══════════════════════════════════════════════════════════════════
// SCORING WEIGHTS
// ═══════════════════════════════════════════════════════════════════

#define SCAN_W_DOW       0.35
#define SCAN_W_GOM       0.30
#define SCAN_W_ATR       0.15
#define SCAN_W_RSI       0.10
#define SCAN_W_SESSION   0.10

// ═══════════════════════════════════════════════════════════════════
// SCANNER HANDLES (per-symbol cached indicators)
// ═══════════════════════════════════════════════════════════════════

struct ScannerSymbolData
{
   string   symbol;
   int      hATR_M1;
   int      hATR_M5;
   int      hRSI_M1;
   int      hEMA_Fast;
   int      hEMA_Slow;
   double   lastATR_M1;
   double   lastATR_M5;
   double   lastRSI;
   double   lastEMA_Fast;
   double   lastEMA_Slow;
   datetime lastUpdate;
   bool     valid;
};

ScannerSymbolData g_scanData[];
int               g_scanDataCount = 0;

// ═══════════════════════════════════════════════════════════════════
// INITIALIZATION
// ═══════════════════════════════════════════════════════════════════

void DOWSCAN_Init()
{
   g_state.scanner.count = 0;
   g_state.scanner.lastScanTime = 0;
   g_state.scanner.initialized = true;
   ArrayResize(g_state.scanner.opportunities, 0);
   ArrayResize(g_scanData, 0);
   g_scanDataCount = 0;

   DebugInfo("DowScanner", "Initialized",
             StringFormat("MaxSymbols=%d Interval=%ds MinScore=%.0f",
                         g_state.config.scannerMaxSymbols,
                         g_state.config.scannerIntervalSec,
                         g_state.config.scannerMinScore));
}

// ═══════════════════════════════════════════════════════════════════
// PARSE SYMBOL LIST
// ═══════════════════════════════════════════════════════════════════

int DOWSCAN_ParseSymbols(string &outSymbols[])
{
   string symList = g_state.config.inpPollSymbols;
   if(StringLen(symList) == 0) return 0;

   ArrayResize(outSymbols, 0);
   int count = 0;

   string parts[];
   int n = StringSplit(symList, ',', parts);

   for(int i = 0; i < n && count < g_state.config.scannerMaxSymbols; i++)
   {
      string s = parts[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      if(StringLen(s) == 0) continue;

      if(SymbolInfoDouble(s, SYMBOL_POINT) > 0)
      {
         int sz = ArraySize(outSymbols);
         ArrayResize(outSymbols, sz + 1);
         outSymbols[sz] = s;
         count++;
      }
   }

   return count;
}

// ═══════════════════════════════════════════════════════════════════
// GET OR CREATE SCANNER DATA INDEX (returns index, NOT pointer)
// ═══════════════════════════════════════════════════════════════════

int DOWSCAN_GetOrCreateIdx(const string symbol)
{
   for(int i = 0; i < g_scanDataCount; i++)
   {
      if(g_scanData[i].symbol == symbol)
         return i;
   }

   int idx = g_scanDataCount;
   ArrayResize(g_scanData, idx + 1);
   g_scanData[idx].symbol = symbol;
   g_scanData[idx].hATR_M1 = iATR(symbol, PERIOD_M1, 14);
   g_scanData[idx].hATR_M5 = iATR(symbol, PERIOD_M5, 14);
   g_scanData[idx].hRSI_M1 = iRSI(symbol, PERIOD_M1, 14, PRICE_CLOSE);
   g_scanData[idx].hEMA_Fast = iMA(symbol, PERIOD_M1, 8, 0, MODE_EMA, PRICE_CLOSE);
   g_scanData[idx].hEMA_Slow = iMA(symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
   g_scanData[idx].lastATR_M1 = 0;
   g_scanData[idx].lastATR_M5 = 0;
   g_scanData[idx].lastRSI = 50;
   g_scanData[idx].lastEMA_Fast = 0;
   g_scanData[idx].lastEMA_Slow = 0;
   g_scanData[idx].lastUpdate = 0;
   g_scanData[idx].valid = true;
   g_scanDataCount++;

   return idx;
}

// ═══════════════════════════════════════════════════════════════════
// UPDATE INDICATOR DATA FOR A SYMBOL (by index)
// ═══════════════════════════════════════════════════════════════════

void DOWSCAN_UpdateIndicatorsByIdx(int idx)
{
   if(idx < 0 || idx >= g_scanDataCount) return;
   if(TimeCurrent() - g_scanData[idx].lastUpdate < 5) return;

   double buf[];
   ArraySetAsSeries(buf, true);

   if(CopyBuffer(g_scanData[idx].hATR_M1, 0, 0, 1, buf) > 0) g_scanData[idx].lastATR_M1 = buf[0];
   if(CopyBuffer(g_scanData[idx].hATR_M5, 0, 0, 1, buf) > 0) g_scanData[idx].lastATR_M5 = buf[0];
   if(CopyBuffer(g_scanData[idx].hRSI_M1, 0, 0, 1, buf) > 0) g_scanData[idx].lastRSI = buf[0];
   if(CopyBuffer(g_scanData[idx].hEMA_Fast, 0, 0, 1, buf) > 0) g_scanData[idx].lastEMA_Fast = buf[0];
   if(CopyBuffer(g_scanData[idx].hEMA_Slow, 0, 0, 1, buf) > 0) g_scanData[idx].lastEMA_Slow = buf[0];

   g_scanData[idx].lastUpdate = TimeCurrent();
}

// ═══════════════════════════════════════════════════════════════════
// SCORE: DOW STRUCTURE (0-100)
// ═══════════════════════════════════════════════════════════════════

double DOWSCAN_CalcDowScore(const string symbol)
{
   double score = 0;

   MqlRates rates[];
   int barsNeeded = 30;
   if(CopyRates(symbol, PERIOD_M1, 0, barsNeeded, rates) < barsNeeded)
      return 0;

   int hAtr = iATR(symbol, PERIOD_M1, 14);
   if(hAtr == INVALID_HANDLE) return 0;
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(hAtr, 0, 0, 1, atrBuf) < 1) { IndicatorRelease(hAtr); return 0; }
   double atr = atrBuf[0];
   IndicatorRelease(hAtr);
   if(atr <= 0) return 0;

   int swingLookback = 3;
   int swingHighs = 0, swingLows = 0;

   for(int i = swingLookback; i < barsNeeded - swingLookback; i++)
   {
      bool isSwingHigh = true;
      bool isSwingLow = true;
      for(int j = 1; j <= swingLookback; j++)
      {
         if(rates[i].high <= rates[i-j].high || rates[i].high <= rates[i+j].high)
            isSwingHigh = false;
         if(rates[i].low >= rates[i-j].low || rates[i].low >= rates[i+j].low)
            isSwingLow = false;
      }
      if(isSwingHigh) swingHighs++;
      if(isSwingLow) swingLows++;
   }

   int totalSwings = swingHighs + swingLows;
   if(totalSwings >= 2)
   {
      score += MathMin(50.0, totalSwings * 12.0);

      // Bonus if trending (EMA alignment)
      int sdIdx = DOWSCAN_GetOrCreateIdx(symbol);
      DOWSCAN_UpdateIndicatorsByIdx(sdIdx);

      double emaFast = g_scanData[sdIdx].lastEMA_Fast;
      double emaSlow = g_scanData[sdIdx].lastEMA_Slow;
      if(emaFast > 0 && emaSlow > 0)
      {
         double emaDiff = MathAbs(emaFast - emaSlow) / atr;
         if(emaDiff > 0.5) score += 25;
         else if(emaDiff > 0.2) score += 15;
      }

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double lastHigh = rates[1].high;
      double lastLow = rates[1].low;
      double distToHigh = MathAbs(bid - lastHigh) / atr;
      double distToLow = MathAbs(bid - lastLow) / atr;
      double minDist = MathMin(distToHigh, distToLow);

      if(minDist < 0.5) score += 25;
      else if(minDist < 1.0) score += 15;
      else if(minDist < 2.0) score += 5;
   }
   else if(totalSwings == 1)
   {
      score += 20;
   }

   return MathMin(100.0, score);
}

// ═══════════════════════════════════════════════════════════════════
// SCORE: GOM VERDICT (0-100)
// ═══════════════════════════════════════════════════════════════════

double DOWSCAN_CalcGomScore(const string symbol, int &outDir)
{
   outDir = 0;

   // For _Symbol: use global GOM verdict directly
   if(symbol == _Symbol && g_state.gom.verdictNum != 999)
   {
      int vn = g_state.gom.verdictNum;
      if(vn == 0) return 0;

      outDir = (vn > 0) ? 1 : -1;
      double score = 0;

      int absVn = MathAbs(vn);
      if(absVn == 3) score = 100;
      else if(absVn == 2) score = 70;
      else if(absVn == 1) score = 40;

      score *= (g_state.gom.quality / 100.0) * 0.3 + 0.7;
      score *= (g_state.gom.coherence / 100.0) * 0.3 + 0.7;

      return MathMin(100.0, score);
   }

   // For other symbols: use EMA cross + ATR momentum as direction proxy
   int sdIdx = DOWSCAN_GetOrCreateIdx(symbol);
   if(sdIdx < 0) return 0;

   double emaFast = g_scanData[sdIdx].lastEMA_Fast;
   double emaSlow = g_scanData[sdIdx].lastEMA_Slow;
   double localAtrM1 = g_scanData[sdIdx].lastATR_M1;
   double localAtrM5 = g_scanData[sdIdx].lastATR_M5;
   if(emaFast <= 0 || emaSlow <= 0 || localAtrM1 <= 0) return 0;

   // Direction from EMA cross
   if(emaFast > emaSlow) outDir = 1;
   else if(emaFast < emaSlow) outDir = -1;
   if(outDir == 0) return 0;

   // Score from ATR momentum
   double score = 50;
   if(localAtrM5 > 0)
   {
      double zscore = (localAtrM1 - localAtrM5) / localAtrM5 * 100;
      if(zscore > 30) score = 80;
      else if(zscore > 10) score = 60;
      else if(zscore > -10) score = 40;
      else score = 30;
   }

   // Bonus for EMA separation
   double emaGap = MathAbs(emaFast - emaSlow) / localAtrM1;
   if(emaGap > 1.0) score += 20;
   else if(emaGap > 0.5) score += 10;

   return MathMax(10, MathMin(100.0, score));
}

// ═══════════════════════════════════════════════════════════════════
// SCORE: ATR MOMENTUM (0-100)
// ═══════════════════════════════════════════════════════════════════

double DOWSCAN_CalcAtrScore(const string symbol)
{
   int sdIdx = DOWSCAN_GetOrCreateIdx(symbol);
   DOWSCAN_UpdateIndicatorsByIdx(sdIdx);

   double scanAtrM1 = g_scanData[sdIdx].lastATR_M1;
   double scanAtrM5 = g_scanData[sdIdx].lastATR_M5;
   if(scanAtrM1 <= 0 || scanAtrM5 <= 0) return 0;

   double ratio = scanAtrM1 / scanAtrM5;
   double score = 0;

   if(ratio > 1.5) score = 90;
   else if(ratio > 1.2) score = 70;
   else if(ratio > 1.0) score = 50;
   else if(ratio > 0.8) score = 30;
   else score = 10;

   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 4, rates) >= 4)
   {
      double recentRange = 0;
      for(int i = 0; i < 3; i++)
         recentRange += MathAbs(rates[i].close - rates[i].open);

      double avgRange = recentRange / 3.0;
      if(avgRange > atrM1 * 1.3) score += 15;
      else if(avgRange < atrM1 * 0.7) score -= 10;
   }

   return MathMax(0, MathMin(100.0, score));
}

// ═══════════════════════════════════════════════════════════════════
// SCORE: RSI CONFIRMATION (0-100)
// ═══════════════════════════════════════════════════════════════════

double DOWSCAN_CalcRsiScore(const string symbol, int direction)
{
   int sdIdx = DOWSCAN_GetOrCreateIdx(symbol);
   DOWSCAN_UpdateIndicatorsByIdx(sdIdx);

   double rsi = g_scanData[sdIdx].lastRSI;
   if(rsi <= 0) return 0;

   double score = 0;

   if(direction > 0)
   {
      if(rsi >= 30 && rsi <= 40) score = 95;
      else if(rsi >= 40 && rsi <= 50) score = 80;
      else if(rsi >= 50 && rsi <= 60) score = 50;
      else if(rsi >= 60 && rsi <= 70) score = 25;
      else if(rsi > 70) score = 5;
      else if(rsi < 30) score = 60;
   }
   else
   {
      if(rsi >= 60 && rsi <= 70) score = 95;
      else if(rsi >= 50 && rsi <= 60) score = 80;
      else if(rsi >= 40 && rsi <= 50) score = 50;
      else if(rsi >= 30 && rsi <= 40) score = 25;
      else if(rsi < 30) score = 5;
      else if(rsi > 70) score = 60;
   }

   return score;
}

// ═══════════════════════════════════════════════════════════════════
// SCORE: SESSION QUALITY (0-100)
// ═══════════════════════════════════════════════════════════════════

double DOWSCAN_CalcSessionScore(const string symbol)
{
   MqlDateTime dt;
   TimeCurrent(dt);

   double score = 50;
   int hour = dt.hour;
   int dow = dt.day_of_week;

   if(dow == 0 || dow == 6) return 0;

   if(hour >= 7 && hour <= 16) score += 20;
   if(hour >= 12 && hour <= 21) score += 15;
   if(hour >= 12 && hour <= 16) score += 15;
   if(hour >= 22 || hour <= 7) score -= 10;
   if(hour == 7 || hour == 12 || hour == 16 || hour == 21) score -= 10;

   string symUpper = symbol;
   StringToUpper(symUpper);
   if(StringFind(symUpper, "BOOM") >= 0 || StringFind(symUpper, "CRASH") >= 0 ||
      StringFind(symUpper, "VOLATILITY") >= 0 || StringFind(symUpper, "INDEX") >= 0)
   {
      score = MathMax(score, 50);
   }

   return MathMax(0, MathMin(100.0, score));
}

// ═══════════════════════════════════════════════════════════════════
// CALCULATE COMPOSITE SCORE
// ═══════════════════════════════════════════════════════════════════

double DOWSCAN_CalcCompositeScore(const string symbol, int &outDir,
                                   double &outDow, double &outGom,
                                   double &outAtr, double &outRsi,
                                   double &outSession)
{
   int gomDir = 0;
   outDow = DOWSCAN_CalcDowScore(symbol);
   outGom = DOWSCAN_CalcGomScore(symbol, gomDir);
   outAtr = DOWSCAN_CalcAtrScore(symbol);

   outDir = gomDir;
   if(outDir == 0)
   {
      // Fallback: use EMA trend for direction
      int sdIdx = DOWSCAN_GetOrCreateIdx(symbol);
      if(sdIdx >= 0)
      {
         double emaF = g_scanData[sdIdx].lastEMA_Fast;
         double emaS = g_scanData[sdIdx].lastEMA_Slow;
         if(emaF > emaS && outDow > 40) outDir = 1;
         else if(emaF < emaS && outDow > 40) outDir = -1;
      }
   }

   outRsi = (outDir != 0) ? DOWSCAN_CalcRsiScore(symbol, outDir) : 50;
   outSession = DOWSCAN_CalcSessionScore(symbol);

   double score = (outDow * SCAN_W_DOW) +
                  (outGom * SCAN_W_GOM) +
                  (outAtr * SCAN_W_ATR) +
                  (outRsi * SCAN_W_RSI) +
                  (outSession * SCAN_W_SESSION);

   return MathMin(100.0, score);
}

// ═══════════════════════════════════════════════════════════════════
// DETERMINE LIMIT vs MARKET READINESS
// ═══════════════════════════════════════════════════════════════════

void DOWSCAN_EvalExecutionMode(TMScannerOpportunity &opp)
{
   opp.limitReady = false;
   opp.marketReady = false;

   double bid = SymbolInfoDouble(opp.symbol, SYMBOL_BID);

   int sdIdx = DOWSCAN_GetOrCreateIdx(opp.symbol);
   DOWSCAN_UpdateIndicatorsByIdx(sdIdx);

   double atr = g_scanData[sdIdx].lastATR_M1;
   if(atr <= 0) return;

   // LIMIT: price near DOW swing
   double threshold = g_state.config.limitATRThreshold;
   MqlRates rates[];
   if(CopyRates(opp.symbol, PERIOD_M1, 0, 10, rates) >= 10)
   {
      double lastHigh = rates[1].high;
      double lastLow = rates[1].low;
      double distToHigh = MathAbs(bid - lastHigh) / atr;
      double distToLow = MathAbs(bid - lastLow) / atr;

      if(opp.direction > 0 && distToLow < threshold)
         opp.limitReady = true;
      else if(opp.direction < 0 && distToHigh < threshold)
         opp.limitReady = true;
   }

   // MARKET: multiple conditions (any one triggers)
   double zscore = 0;
   double atrM5Scan = g_scanData[sdIdx].lastATR_M5;
   if(atr > 0 && atrM5Scan > 0)
      zscore = (atr - atrM5Scan) / atrM5Scan * 100;

   // 1. GOM verdict strong
   if(MathAbs(g_state.gom.verdictNum) >= 2 && g_state.gom.quality > 60)
      opp.marketReady = true;

   // 2. ATR momentum spike
   if(zscore > 50)
      opp.marketReady = true;

   // 3. EMA strong trend (gap > 1 ATR)
   double emaF = g_scanData[sdIdx].lastEMA_Fast;
   double emaS = g_scanData[sdIdx].lastEMA_Slow;
   if(emaF > 0 && emaS > 0 && atr > 0)
   {
      double emaGap = MathAbs(emaF - emaS) / atr;
      if(emaGap > 1.2)
         opp.marketReady = true;
   }

   // 4. Always allow if direction is clear and score is decent
   if(opp.direction != 0 && opp.score > 60)
      opp.marketReady = true;
}

// ═══════════════════════════════════════════════════════════════════
// SPIKE TIMING CALCULATION (per symbol)
// ═══════════════════════════════════════════════════════════════════

void DOWSCAN_CalcSpikeTiming(const string symbol,
                              double &outImminence,
                              double &outPreSpike,
                              int &outBarsSinceSpike,
                              int &outSpikeFreq,
                              double &outATR_M1,
                              double &outATR_M5)
{
   outImminence = 0;
   outPreSpike = 0;
   outBarsSinceSpike = 0;
   outSpikeFreq = 50; // Default
   outATR_M1 = 0;
   outATR_M5 = 0;

   // ATR M1/M5 pour momentum
   int sdIdx = DOWSCAN_GetOrCreateIdx(symbol);
   if(sdIdx >= 0)
   {
      DOWSCAN_UpdateIndicatorsByIdx(sdIdx);
      outATR_M1 = g_scanData[sdIdx].lastATR_M1;
      outATR_M5 = g_scanData[sdIdx].lastATR_M5;
   }

   // Calculer imminence basé sur:
   // 1. Compression des bougies (range récent vs ATR)
   // 2. Distance au support/résistance
   // 3. Volatilité en baisse (consolidation)

   MqlRates rates[];
   int barsNeeded = 30;
   if(CopyRates(symbol, PERIOD_M1, 0, barsNeeded, rates) < barsNeeded) return;

   double atr = outATR_M1;
   if(atr <= 0) return;

   // 1. Compression: range des 5 dernières bougies vs ATR
   double recentRange = 0;
   for(int i = 0; i < 5; i++)
      recentRange += MathAbs(rates[i].close - rates[i].open);
   recentRange /= 5.0;

   double compressionRatio = recentRange / atr;
   if(compressionRatio < 0.5)
      outPreSpike = 90.0; // Forte compression
   else if(compressionRatio < 0.7)
      outPreSpike = 70.0;
   else if(compressionRatio < 0.9)
      outPreSpike = 50.0;
   else
      outPreSpike = 20.0;

   // 2. Imminence: basée sur la position du prix dans la range
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(bid <= 0) return;

   // Trouver le high/low des 20 dernières bougies
   double highestHigh = rates[0].high;
   double lowestLow = rates[0].low;
   for(int i = 1; i < 20; i++)
   {
      if(rates[i].high > highestHigh) highestHigh = rates[i].high;
      if(rates[i].low < lowestLow) lowestLow = rates[i].low;
   }

   double range = highestHigh - lowestLow;
   if(range <= 0) return;

   // Position dans la range (0 = bottom, 100 = top)
   double position = ((bid - lowestLow) / range) * 100.0;

   // Imminence = plus le prix est proche d'un extrême + compression
   double extremeDistance = MathMin(position, 100.0 - position);
   if(extremeDistance < 10)
      outImminence = 80.0 + (10 - extremeDistance) * 2.0;
   else if(extremeDistance < 20)
      outImminence = 60.0 + (20 - extremeDistance) * 2.0;
   else if(extremeDistance < 30)
      outImminence = 40.0 + (30 - extremeDistance) * 2.0;
   else
      outImminence = MathMax(10.0, 40.0 - extremeDistance);

   // Bonus si compression forte
   outImminence = MathMin(100.0, outImminence + outPreSpike * 0.2);

   // 3. Bars since last spike (détecter un spike = bougie > 2x ATR)
   outBarsSinceSpike = 0;
   for(int i = 1; i < barsNeeded; i++)
   {
      double bodySize = MathAbs(rates[i].close - rates[i].open);
      if(bodySize > atr * 2.0)
      {
         outBarsSinceSpike = i;
         break;
      }
   }

   // 4. Spike frequency estimation (moyenne mobile simple)
   int spikeCount = 0;
   int lastSpikeBar = 0;
   for(int i = 1; i < barsNeeded; i++)
   {
      double bodySize = MathAbs(rates[i].close - rates[i].open);
      if(bodySize > atr * 1.5)
      {
         if(lastSpikeBar > 0)
            spikeCount++;
         lastSpikeBar = i;
      }
   }
   if(spikeCount > 0)
      outSpikeFreq = barsNeeded / spikeCount;
}

// ═══════════════════════════════════════════════════════════════════
// MAIN SCAN LOOP
// ═══════════════════════════════════════════════════════════════════

void DOWSCAN_ScanAllSymbols()
{
   if(!g_state.config.useDowScanner) return;

   string symbols[];
   int symCount = DOWSCAN_ParseSymbols(symbols);
   if(symCount == 0) return;

   g_state.scanner.count = 0;
   ArrayResize(g_state.scanner.opportunities, 0);

   for(int i = 0; i < symCount; i++)
   {
      string sym = symbols[i];

      int dir = 0;
      double dowScore, gomScore, atrScore, rsiScore, sessionScore;
      double totalScore = DOWSCAN_CalcCompositeScore(sym, dir,
                             dowScore, gomScore, atrScore, rsiScore, sessionScore);

      if(totalScore < g_state.config.scannerMinScore) continue;
      if(dir == 0) continue;

      int idx = g_state.scanner.count;
      ArrayResize(g_state.scanner.opportunities, idx + 1);

      TMScannerOpportunity opp;
      opp.symbol = sym;
      opp.score = totalScore;
      opp.direction = dir;
      opp.dowScore = dowScore;
      opp.gomScore = gomScore;
      opp.atrScore = atrScore;
      opp.rsiScore = rsiScore;
      opp.sessionScore = sessionScore;
      opp.dowPrice = 0;
      opp.distToDow = 999;
      opp.dowActive = (dowScore > 50);
      opp.lastUpdate = TimeCurrent();

      // Spike timing data
      double imminence, preSpike, spikeAtrM1, spikeAtrM5;
      int barsSinceSpike, spikeFreq;
      DOWSCAN_CalcSpikeTiming(sym, imminence, preSpike,
                              barsSinceSpike, spikeFreq, spikeAtrM1, spikeAtrM5);
      opp.imminencePct = imminence;
      opp.preSpikePct = preSpike;
      opp.barsSinceSpike = barsSinceSpike;
      opp.spikeFreqBars = spikeFreq;
      opp.spikeProgressPct = 0;
      opp.spikeScore = 0;
      opp.estMinutesToSpike = 999;

      DOWSCAN_EvalExecutionMode(opp);

      g_state.scanner.opportunities[idx] = opp;
      g_state.scanner.count++;
   }

   // Sort by score (bubble sort)
   for(int i = 0; i < g_state.scanner.count - 1; i++)
   {
      for(int j = i + 1; j < g_state.scanner.count; j++)
      {
         if(g_state.scanner.opportunities[j].score > g_state.scanner.opportunities[i].score)
         {
            TMScannerOpportunity tmp = g_state.scanner.opportunities[i];
            g_state.scanner.opportunities[i] = g_state.scanner.opportunities[j];
            g_state.scanner.opportunities[j] = tmp;
         }
      }
   }

   g_state.scanner.lastScanTime = TimeCurrent();
   g_state.scanner.lastTopIdx = 0;

   if(g_state.scanner.count > 0)
   {
      DebugInfo("DowScanner", "Scan complete",
                StringFormat("Top: %s %s score=%.1f DOW=%.0f GOM=%.0f ATR=%.0f",
                           g_state.scanner.opportunities[0].symbol,
                           (g_state.scanner.opportunities[0].direction > 0 ? "BUY" : "SELL"),
                           g_state.scanner.opportunities[0].score,
                           g_state.scanner.opportunities[0].dowScore,
                           g_state.scanner.opportunities[0].gomScore,
                           g_state.scanner.opportunities[0].atrScore));
   }
}

// ═══════════════════════════════════════════════════════════════════
// GET TOP OPPORTUNITY
// ═══════════════════════════════════════════════════════════════════

bool DOWSCAN_GetTopOpportunity(TMScannerOpportunity &out)
{
   if(g_state.scanner.count == 0) return false;
   out = g_state.scanner.opportunities[0];
   return true;
}

// ═══════════════════════════════════════════════════════════════════
// GET TOP N OPPORTUNITIES
// ═══════════════════════════════════════════════════════════════════

int DOWSCAN_GetTopN(int n, TMScannerOpportunity &out[])
{
   int count = MathMin(n, g_state.scanner.count);
   ArrayResize(out, count);
   for(int i = 0; i < count; i++)
      out[i] = g_state.scanner.opportunities[i];
   return count;
}

// ═══════════════════════════════════════════════════════════════════
// CLEANUP (release indicator handles)
// ═══════════════════════════════════════════════════════════════════

void DOWSCAN_Cleanup()
{
   for(int i = 0; i < g_scanDataCount; i++)
   {
      if(g_scanData[i].hATR_M1 != INVALID_HANDLE) IndicatorRelease(g_scanData[i].hATR_M1);
      if(g_scanData[i].hATR_M5 != INVALID_HANDLE) IndicatorRelease(g_scanData[i].hATR_M5);
      if(g_scanData[i].hRSI_M1 != INVALID_HANDLE) IndicatorRelease(g_scanData[i].hRSI_M1);
      if(g_scanData[i].hEMA_Fast != INVALID_HANDLE) IndicatorRelease(g_scanData[i].hEMA_Fast);
      if(g_scanData[i].hEMA_Slow != INVALID_HANDLE) IndicatorRelease(g_scanData[i].hEMA_Slow);
   }
   ArrayResize(g_scanData, 0);
   g_scanDataCount = 0;
}

#endif // TM_DOW_SCANNER_MQH
