// SpikeChainDetector.mqh
#ifndef SPIKE_CHAIN_DETECTOR_MQH
#define SPIKE_CHAIN_DETECTOR_MQH

#include "TMState.mqh"
#include "SymbolScanner.mqh"

// Simple spike-chain detector maintained per-symbol (lightweight, non-blocking)
#define SPD_MAX_TRACKED 128

struct SPD_State
{
   string symbol;
   int    dir; // +1 buy spike, -1 sell spike
   int    count; // number of consecutive spike bars
   datetime startTime;
   int    lastBarIndex;
   double score;
   bool   active;
};

static SPD_State g_spdStates[SPD_MAX_TRACKED];
static int g_spdCount = 0;

// Parameters (can be tuned)
input int   SPD_MIN_CHAIN_COUNT = 2;      // minimum spikes to consider a chain active
input double SPD_MIN_SCORE = 1.6;         // minimal spike score (range/ATR)
input int   SPD_SCAN_MAX_SYMBOLS = 40;    // limit scanned symbols per update

// Helper: find or create state index for symbol
int SPD_FindIndex(const string symbol)
{
   for(int i=0;i<g_spdCount;i++) if(g_spdStates[i].symbol == symbol) return i;
   if(g_spdCount < SPD_MAX_TRACKED)
   {
      int idx = g_spdCount++;
      g_spdStates[idx].symbol = symbol;
      g_spdStates[idx].dir = 0;
      g_spdStates[idx].count = 0;
      g_spdStates[idx].startTime = 0;
      g_spdStates[idx].lastBarIndex = -1;
      g_spdStates[idx].score = 0.0;
      g_spdStates[idx].active = false;
      return idx;
   }
   return -1;
}

// Update state for a single symbol using M1 bars
void SPD_UpdateSymbol(const string symbol)
{
   int idx = SPD_FindIndex(symbol);
   if(idx < 0) return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 3, rates) < 1) return;

   double atr = 0.0;
   // compute simple ATR over 3 bars
   int n = MathMin(ArraySize(rates), 3);
   for(int i=0;i<n;i++) atr += MathAbs(rates[i].high - rates[i].low);
   atr = (atr > 0 && n>0) ? atr / n : 0.0;
   if(atr <= 0.0) return;

   // analyze most recent bar
   double lastRange = MathAbs(rates[0].high - rates[0].low);
   double body = MathAbs(rates[0].close - rates[0].open);
   int dir = 0;
   if(rates[0].close > rates[0].open) dir = 1; else if(rates[0].close < rates[0].open) dir = -1;

   double score = lastRange / atr;
   // prefer bars with big bodies
   if(body > lastRange * 0.5) score *= 1.1;

   // threshold detection
   if(score >= SPD_MIN_SCORE)
   {
      // candidate spike
      if(g_spdStates[idx].lastBarIndex == rates[0].time)
      {
         // already processed this bar
      }
      else
      {
         // same direction continuation?
         if(g_spdStates[idx].dir == dir && g_spdStates[idx].active)
         {
            g_spdStates[idx].count++;
            g_spdStates[idx].score += score;
            g_spdStates[idx].lastBarIndex = rates[0].time;
         }
         else
         {
            // new candidate chain
            g_spdStates[idx].dir = dir;
            g_spdStates[idx].count = 1;
            g_spdStates[idx].score = score;
            g_spdStates[idx].startTime = rates[0].time;
            g_spdStates[idx].lastBarIndex = rates[0].time;
            g_spdStates[idx].active = false;
         }

         // activate if count reaches threshold
         if(g_spdStates[idx].count >= SPD_MIN_CHAIN_COUNT)
            g_spdStates[idx].active = true;
      }
   }
   else
   {
      // no spike -> decay chain slowly
      if(g_spdStates[idx].active)
      {
         // if brief pause, keep chain but decay
         g_spdStates[idx].score *= 0.8;
         if(g_spdStates[idx].score < SPD_MIN_SCORE) g_spdStates[idx].active = false;
      }
      else
      {
         // reset if no activity
         g_spdStates[idx].dir = 0;
         g_spdStates[idx].count = 0;
         g_spdStates[idx].score = 0.0;
         g_spdStates[idx].lastBarIndex = rates[0].time;
      }
   }
}

// Public: update global spike chain state by scanning MarketWatch symbols (bounded cost)
void SMC_UpdateSpikeChainState()
{
   string syms[128];
   int n = GetMarketWatchSymbols(syms, SPD_SCAN_MAX_SYMBOLS);
   if(n <= 0) return;

   for(int i=0;i<n;i++)
   {
      SPD_UpdateSymbol(syms[i]);
   }
}

// Public: check if any chain active and return earliest direction (BUY/SELL)
bool SMC_IsSpikeChainEarlyEntry(string &outDirection)
{
   outDirection = "";
   double bestScore = 0.0;
   int bestIdx = -1;
   for(int i=0;i<g_spdCount;i++)
   {
      if(!g_spdStates[i].active) continue;
      if(g_spdStates[i].score > bestScore)
      {
         bestScore = g_spdStates[i].score;
         bestIdx = i;
      }
   }
   if(bestIdx >= 0)
   {
      outDirection = (g_spdStates[bestIdx].dir > 0) ? "BUY" : "SELL";
      return true;
   }
   return false;
}

#endif // SPIKE_CHAIN_DETECTOR_MQH
