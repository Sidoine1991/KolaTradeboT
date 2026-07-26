//+------------------------------------------------------------------+
//| DowScanner.mqh — Multi-symbol opportunity scanner (DOW engine)   |
//| Scanne tous les symboles, calcule un score composite,             |
//| identifie le meilleur DOW trendline + GOM alignment.              |
//+------------------------------------------------------------------+
#ifndef TM_DOW_SCANNER_MQH
#define TM_DOW_SCANNER_MQH

#include "TMState.mqh"
#include "TMDebug.mqh"
#include "HTTPTransport.mqh"

// ═══════════════════════════════════════════════════════════════════
// SCORING WEIGHTS
// ═══════════════════════════════════════════════════════════════════

#define SCAN_W_DOW       0.35   // DOW structure weight
#define SCAN_W_GOM       0.30   // GOM verdict weight
#define SCAN_W_ATR       0.15   // ATR momentum weight
#define SCAN_W_RSI       0.10   // RSI confirmation weight
#define SCAN_W_SESSION   0.10   // Session quality weight

// ═══════════════════════════════════════════════════════════════════
// SCANNER HANDLES (per-symbol cached indicators)
// ═══════════════════════════════════════════════════════════════════

struct ScannerSymbolData
{
   string   symbol;
   int      hATR_M1;       // ATR M1 handle
   int      hATR_M5;       // ATR M5 handle
   int      hRSI_M1;       // RSI M1 handle
   int      hEMA_Fast;     // EMA 8 M1
   int      hEMA_Slow;     // EMA 21 M1
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
   string sep = ",";

   // Parse comma-separated list
   string parts[];
   int n = StringSplit(symList, ',', parts);

   for(int i = 0; i < n && count < g_state.config.scannerMaxSymbols; i++)
   {
      string s = parts[i];
      StringTrimLeft(s);
      StringTrimRight(s);
      if(StringLen(s) == 0) continue;

      // Vérifier que le symbole existe dans le terminal
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
// GET OR CREATE SCANNER DATA FOR SYMBOL
// ═══════════════════════════════════════════════════════════════════

ScannerSymbolData* DOWSCAN_GetOrCreateData(const string symbol)
{
   // Search existing
   for(int i = 0; i < g_scanDataCount; i++)
   {
      if(g_scanData[i].symbol == symbol)
         return &g_scanData[i];
   }

   // Create new
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

   return &g_scanData[idx];
}

// ═══════════════════════════════════════════════════════════════════
// UPDATE INDICATOR DATA FOR A SYMBOL
// ═══════════════════════════════════════════════════════════════════

void DOWSCAN_UpdateIndicators(ScannerSymbolData &sd)
{
   if(TimeCurrent() - sd.lastUpdate < 5) return; // Rate limit 5s

   double buf[];
   ArraySetAsSeries(buf, true);

   if(CopyBuffer(sd.hATR_M1, 0, 0, 1, buf) > 0) sd.lastATR_M1 = buf[0];
   if(CopyBuffer(sd.hATR_M5, 0, 0, 1, buf) > 0) sd.lastATR_M5 = buf[0];
   if(CopyBuffer(sd.hRSI_M1, 0, 0, 1, buf) > 0) sd.lastRSI = buf[0];
   if(CopyBuffer(sd.hEMA_Fast, 0, 0, 1, buf) > 0) sd.lastEMA_Fast = buf[0];
   if(CopyBuffer(sd.hEMA_Slow, 0, 0, 1, buf) > 0) sd.lastEMA_Slow = buf[0];

   sd.lastUpdate = TimeCurrent();
}

// ═══════════════════════════════════════════════════════════════════
// SCORE: DOW STRUCTURE (0-100)
// ═══════════════════════════════════════════════════════════════════

double DOWSCAN_CalcDowScore(const string symbol)
{
   double score = 0;

   // 1. Vérifier si une trendline DOW est active (via les swings M1)
   MqlRates rates[];
   int barsNeeded = 30;
   if(CopyRates(symbol, PERIOD_M1, 0, barsNeeded, rates) < barsNeeded)
      return 0;

   double atr = iATR(symbol, PERIOD_M1, 14, 0);
   if(atr <= 0) return 0;

   // Détecter les swing highs/lows
   int swingLookback = 3;
   int swingHighs = 0, swingLows = 0;
   bool lowerHighs = true, higherLows = true;

   for(int i = swingLookback; i < barsNeeded - swingLookback; i++)
   {
      // Swing high: higher than N bars before and after
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

   // Score based on swing structure clarity
   int totalSwings = swingHighs + swingLows;
   if(totalSwings >= 2)
   {
      // More swings = clearer structure
      score += MathMin(50.0, totalSwings * 12.0);

      // Bonus if trending (EMA alignment)
      ScannerSymbolData *sd = DOWSCAN_GetOrCreateData(symbol);
      DOWSCAN_UpdateIndicators(*sd);
      if(sd->lastEMA_Fast > 0 && sd->lastEMA_Slow > 0)
      {
         double emaDiff = MathAbs(sd->lastEMA_Fast - sd->lastEMA_Slow) / atr;
         if(emaDiff > 0.5) score += 25; // Strong trend
         else if(emaDiff > 0.2) score += 15; // Moderate trend
      }

      // Bonus for price near a swing (potential DOW touch)
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double lastHigh = rates[1].high;
      double lastLow = rates[1].low;
      double distToHigh = MathAbs(bid - lastHigh) / atr;
      double distToLow = MathAbs(bid - lastLow) / atr;
      double minDist = MathMin(distToHigh, distToLow);

      if(minDist < 0.5) score += 25; // Very close to swing = prime DOW setup
      else if(minDist < 1.0) score += 15;
      else if(minDist < 2.0) score += 5;
   }
   else if(totalSwings == 1)
   {
      score += 20; // Partial structure
   }

   return MathMin(100.0, score);
}

// ═══════════════════════════════════════════════════════════════════
// SCORE: GOM VERDICT (0-100)
// ═══════════════════════════════════════════════════════════════════

double DOWSCAN_CalcGomScore(const string symbol, int &outDir)
{
   outDir = 0;

   // Si c'est le symbole actuel du chart, utiliser le verdict local
   if(symbol == _Symbol && g_state.gom.verdictNum != 999)
   {
      int vn = g_state.gom.verdictNum;
      if(vn == 0) return 0; // WAIT

      outDir = (vn > 0) ? 1 : -1;
      double score = 0;

      // Verdict quality
      int absVn = MathAbs(vn);
      if(absVn == 3) score = 100;      // PERFECT
      else if(absVn == 2) score = 70;  // GOOD
      else if(absVn == 1) score = 40;  // SIMPLE

      // Bonus for quality and coherence
      score *= (g_state.gom.quality / 100.0) * 0.3 + 0.7;
      score *= (g_state.gom.coherence / 100.0) * 0.3 + 0.7;

      return MathMin(100.0, score);
   }

   // Pour les autres symboles, retourner 0 (pas de données GOM distantes)
   // Le scanner peut être étendu avec un poll GOM multi-symbol
   return 0;
}

// ═══════════════════════════════════════════════════════════════════
// SCORE: ATR MOMENTUM (0-100)
// ═══════════════════════════════════════════════════════════════════

double DOWSCAN_CalcAtrScore(const string symbol)
{
   ScannerSymbolData *sd = DOWSCAN_GetOrCreateData(symbol);
   DOWSCAN_UpdateIndicators(*sd);

   if(sd->lastATR_M1 <= 0 || sd->lastATR_M5 <= 0) return 0;

   // ATR M1 vs M5 = momentum indicator
   double ratio = sd->lastATR_M1 / sd->lastATR_M5;
   double score = 0;

   // High momentum when M1 ATR > M5 ATR (spike building)
   if(ratio > 1.5) score = 90;       // Very high momentum
   else if(ratio > 1.2) score = 70;  // High momentum
   else if(ratio > 1.0) score = 50;  // Normal
   else if(ratio > 0.8) score = 30;  // Low momentum
   else score = 10;                   // Very low

   // Bonus: check recent candle range (last 3 bars)
   MqlRates rates[];
   if(CopyRates(symbol, PERIOD_M1, 0, 4, rates) >= 4)
   {
      double recentRange = 0;
      for(int i = 0; i < 3; i++)
         recentRange += MathAbs(rates[i].close - rates[i].open);

      double avgRange = recentRange / 3.0;
      if(avgRange > sd->lastATR_M1 * 1.3) score += 15; // Expansion
      else if(avgRange < sd->lastATR_M1 * 0.7) score -= 10; // Contraction
   }

   return MathMax(0, MathMin(100.0, score));
}

// ═══════════════════════════════════════════════════════════════════
// SCORE: RSI CONFIRMATION (0-100)
// ═══════════════════════════════════════════════════════════════════

double DOWSCAN_CalcRsiScore(const string symbol, int direction)
{
   ScannerSymbolData *sd = DOWSCAN_GetOrCreateData(symbol);
   DOWSCAN_UpdateIndicators(*sd);

   double rsi = sd->lastRSI;
   if(rsi <= 0) return 0;

   double score = 0;

   if(direction > 0) // BUY
   {
      // Best RSI for BUY: 30-50 (oversold recovery zone)
      if(rsi >= 30 && rsi <= 40) score = 95;       // Deep oversold
      else if(rsi >= 40 && rsi <= 50) score = 80;  // Recovery zone
      else if(rsi >= 50 && rsi <= 60) score = 50;  // Neutral
      else if(rsi >= 60 && rsi <= 70) score = 25;  // Getting overbought
      else if(rsi > 70) score = 5;                  // Overbought
      else if(rsi < 30) score = 60;                 // Very oversold (momentum down)
   }
   else // SELL
   {
      // Best RSI for SELL: 50-70 (overbought reversal zone)
      if(rsi >= 60 && rsi <= 70) score = 95;       // Deep overbought
      else if(rsi >= 50 && rsi <= 60) score = 80;  // Reversal zone
      else if(rsi >= 40 && rsi <= 50) score = 50;  // Neutral
      else if(rsi >= 30 && rsi <= 40) score = 25;  // Getting oversold
      else if(rsi < 30) score = 5;                  // Oversold
      else if(rsi > 70) score = 60;                 // Very overbought (momentum up)
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

   double score = 50; // Default neutral

   // Bonus during high-volume sessions
   int hour = dt.hour;
   int dow = dt.day_of_week;

   // No trade on weekends
   if(dow == 0 || dow == 6) return 0;

   // London session (07:00-16:00 UTC) - high volume
   if(hour >= 7 && hour <= 16) score += 20;

   // New York session (12:00-21:00 UTC) - high volume
   if(hour >= 12 && hour <= 21) score += 15;

   // Overlap London/NY (12:00-16:00 UTC) - highest volume
   if(hour >= 12 && hour <= 16) score += 15;

   // Asian session (22:00-07:00 UTC) - lower volume for forex, ok for volatility
   if(hour >= 22 || hour <= 7) score -= 10;

   // Avoid first/last 15 min of major sessions (spreads widen)
   if(hour == 7 || hour == 12 || hour == 16 || hour == 21) score -= 10;

   // Check if symbol is synthetics (Deriv) — trade 24/7
   string symUpper = symbol;
   StringToUpper(symUpper);
   if(StringFind(symUpper, "BOOM") >= 0 || StringFind(symUpper, "CRASH") >= 0 ||
      StringFind(symUpper, "VOLATILITY") >= 0 || StringFind(symUpper, "INDEX") >= 0)
   {
      // Synthetics: session less important, but avoid low-vol hours
      score = MathMax(score, 50); // Floor at 50
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

   // Determine direction from GOM (primary) or DOW (fallback)
   outDir = gomDir;
   if(outDir == 0 && outDow > 50) outDir = 1; // Default BUY if DOW is active

   outRsi = (outDir != 0) ? DOWSCAN_CalcRsiScore(symbol, outDir) : 50;
   outSession = DOWSCAN_CalcSessionScore(symbol);

   // Composite weighted score
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
   double ask = SymbolInfoDouble(opp.symbol, SYMBOL_ASK);
   double atr = SymbolInfoDouble(opp.symbol, SYMBOL_ASK); // fallback
   ScannerSymbolData *sd = DOWSCAN_GetOrCreateData(opp.symbol);
   atr = sd->lastATR_M1;
   if(atr <= 0) return;

   // LIMIT: price near DOW swing (within threshold × ATR)
   double threshold = g_state.config.limitATRThreshold;
   MqlRates rates[];
   if(CopyRates(opp.symbol, PERIOD_M1, 0, 10, rates) >= 10)
   {
      double lastHigh = rates[1].high;
      double lastLow = rates[1].low;
      double distToHigh = MathAbs(bid - lastHigh) / atr;
      double distToLow = MathAbs(bid - lastLow) / atr;

      if(opp.direction > 0 && distToLow < threshold)
         opp.limitReady = true; // BUY near swing low
      else if(opp.direction < 0 && distToHigh < threshold)
         opp.limitReady = true; // SELL near swing high
   }

   // MARKET: GOM GOOD/PERFECT OR high ATR momentum
   double zscore = 0;
   if(atr > 0 && sd->lastATR_M5 > 0)
      zscore = (sd->lastATR_M1 - sd->lastATR_M5) / sd->lastATR_M5 * 100;

   if(MathAbs(g_state.gom.verdictNum) >= 2 && g_state.gom.quality > 60)
      opp.marketReady = true;

   if(zscore > 80) // High momentum spike
      opp.marketReady = true;

   // Neither ready = skip
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

   // Reset opportunities
   g_state.scanner.count = 0;
   ArrayResize(g_state.scanner.opportunities, 0);

   for(int i = 0; i < symCount; i++)
   {
      string sym = symbols[i];

      // Score each symbol
      int dir = 0;
      double dowScore, gomScore, atrScore, rsiScore, sessionScore;
      double totalScore = DOWSCAN_CalcCompositeScore(sym, dir,
                             dowScore, gomScore, atrScore, rsiScore, sessionScore);

      if(totalScore < g_state.config.scannerMinScore) continue;
      if(dir == 0) continue; // No clear direction

      // Create opportunity entry
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

      // Evaluate execution mode
      DOWSCAN_EvalExecutionMode(opp);

      g_state.scanner.opportunities[idx] = opp;
      g_state.scanner.count++;
   }

   // Sort by score (bubble sort — small N)
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
