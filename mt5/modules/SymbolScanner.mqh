// SymbolScanner.mqh - simple fast scanner to detect spike-like moves across MarketWatch symbols
#ifndef SYMBOL_SCANNER_MQH
#define SYMBOL_SCANNER_MQH

#include <stdlib.mqh>

// Configuration
input int   SCAN_LOOKBACK_BARS = 5;      // bars to examine on M1 for spikes
input double SCAN_MIN_ATR_MULT = 1.5;    // bar size must exceed this * ATR to be considered spike
input int   SCAN_MAX_SYMBOLS = 50;       // max symbols to scan (to avoid long loops)

struct ScanResult {
   string symbol;
   double score; // higher is better
};

// Compute simple spike score on M1: last bar range / ATR
double ComputeSpikeScore(const string symbol)
{
   int tf = PERIOD_M1;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, SCAN_LOOKBACK_BARS, rates) < 2) return 0.0;

   // ATR over lookback
   double highLowDiffs[32];
   int count = MathMin(ArraySize(rates), SCAN_LOOKBACK_BARS);
   for(int i=0;i<count;i++) highLowDiffs[i] = MathAbs(rates[i].high - rates[i].low);

   double atr = 0;
   for(int i=0;i<count;i++) atr += highLowDiffs[i];
   atr = atr / count;
   if(atr <= 0.0) return 0.0;

   // Use most recent bar as candidate
   double lastRange = MathAbs(rates[0].high - rates[0].low);
   double score = lastRange / atr;
   // Bonus if close near high/low (momentum)
   double body = MathAbs(rates[0].close - rates[0].open);
   if(body > lastRange * 0.6) score *= 1.1;

   return score;
}

// Get list of symbols from MarketWatch up to maxSymbols
int GetMarketWatchSymbols(string syms[], int maxSymbols)
{
   int total = SymbolsTotal(false);
   int added = 0;
   for(int i=0;i<total && added < maxSymbols;i++)
   {
      string s = SymbolName(i, false);
      if(StringLen(s) == 0) continue;
      syms[added++] = s;
   }
   return added;
}

// Find best spike symbol
bool SymbolScanner_FindBest(string &bestSymbol, double &bestScore)
{
   bestSymbol = "";
   bestScore = 0.0;
   string syms[128];
   int n = GetMarketWatchSymbols(syms, SCAN_MAX_SYMBOLS);
   if(n <= 0) return false;

   for(int i=0;i<n;i++)
   {
      double score = ComputeSpikeScore(syms[i]);
      if(score > bestScore)
      {
         bestScore = score;
         bestSymbol = syms[i];
      }
   }

   return (bestScore > SCAN_MIN_ATR_MULT);
}

#endif // SYMBOL_SCANNER_MQH
