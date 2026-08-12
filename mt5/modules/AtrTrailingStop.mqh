//+------------------------------------------------------------------+
//| AtrTrailingStop.mqh — Dynamic ATR-based trailing stop            |
//| Trailing adapte a la volatilite: BE rapide, trail agressif,      |
//| trail conservateur, lock profit monotone.                        |
//| MQL5-compatible: no struct pointers, index-based array access.    |
//+------------------------------------------------------------------+
#ifndef TM_ATR_TRAILING_STOP_MQH
#define TM_ATR_TRAILING_STOP_MQH

#include "TMState.mqh"
#include "TMDebug.mqh"
#include "TMEvents.mqh"
#include <Trade/Trade.mqh>

// ═══════════════════════════════════════════════════════════════════
// ATR TRAILING STATE PER POSITION
// ═══════════════════════════════════════════════════════════════════

struct ATRTrailPosition
{
   ulong    ticket;
   double   entryATR;
   double   peakProfitUSD;
   double   lastSL;
   bool     beTriggered;
   bool     aggrTriggered;
   bool     consTriggered;
   datetime openedAt;
};

ATRTrailPosition g_atrPositions[];
int              g_atrPositionCount = 0;

// ═══════════════════════════════════════════════════════════════════
// INITIALIZATION
// ═══════════════════════════════════════════════════════════════════

void ATRTRAIL_Init()
{
   g_atrPositionCount = 0;
   ArrayResize(g_atrPositions, 0);
   DebugInfo("ATRTrailing", "Initialized",
             StringFormat("BE=%.1f ATR Aggr=%.1f Cons=%.1f",
                         g_state.config.atrTrailBETrigger,
                         g_state.config.atrTrailAggressive,
                         g_state.config.atrTrailConservative));
}

// ═══════════════════════════════════════════════════════════════════
// GET OR CREATE TRACKING INDEX (returns index, NOT pointer)
// ═══════════════════════════════════════════════════════════════════

int ATRTRAIL_GetOrCreateIdx(ulong ticket, string symbol)
{
   for(int i = 0; i < g_atrPositionCount; i++)
   {
      if(g_atrPositions[i].ticket == ticket)
         return i;
   }

   double atr = 0;
   int hATR = iATR(symbol, (ENUM_TIMEFRAMES)g_state.config.atrTrailPeriod, 14);
   double buf[];
   ArraySetAsSeries(buf, true);
   if(hATR != INVALID_HANDLE && CopyBuffer(hATR, 0, 0, 1, buf) > 0)
      atr = buf[0];
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);

   int idx = g_atrPositionCount;
   ArrayResize(g_atrPositions, idx + 1);
   g_atrPositions[idx].ticket = ticket;
   g_atrPositions[idx].entryATR = atr;
   g_atrPositions[idx].peakProfitUSD = 0;
   g_atrPositions[idx].lastSL = 0;
   g_atrPositions[idx].beTriggered = false;
   g_atrPositions[idx].aggrTriggered = false;
   g_atrPositions[idx].consTriggered = false;
   g_atrPositions[idx].openedAt = TimeCurrent();
   g_atrPositionCount++;

   return idx;
}

// ═══════════════════════════════════════════════════════════════════
// GET CURRENT ATR FOR A SYMBOL
// ═══════════════════════════════════════════════════════════════════

double ATRTRAIL_GetATR(const string symbol)
{
   int hATR = iATR(symbol, (ENUM_TIMEFRAMES)g_state.config.atrTrailPeriod, 14);
   double atr = 0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(hATR != INVALID_HANDLE && CopyBuffer(hATR, 0, 0, 1, buf) > 0)
      atr = buf[0];
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   return atr;
}

// ═══════════════════════════════════════════════════════════════════
// CALCULATE NEW SL BASED ON ATR TRAILING LOGIC
// ═══════════════════════════════════════════════════════════════════

double ATRTRAIL_CalcNewSL(int posIdx, int direction,
                           double currentPrice, double currentSL, double atr)
{
   if(atr <= 0) return currentSL;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double newSL = currentSL;

   double profitPts = 0;
   if(direction > 0)
      profitPts = currentPrice - entry;
   else
      profitPts = entry - currentPrice;

   double profitATR = profitPts / atr;

   // Phase 1: Break-even trigger
   if(!g_atrPositions[posIdx].beTriggered && profitATR >= g_state.config.atrTrailBETrigger)
   {
      if(direction > 0)
         newSL = MathMax(newSL, entry);
      else
         newSL = MathMin(newSL, entry);

      return newSL;
   }

   // Phase 2: Aggressive trail (tight)
   if(profitATR >= g_state.config.atrTrailAggressive)
   {
      double trailDist = atr * g_state.config.atrTrailAggrDist;
      double trailSL = 0;

      if(direction > 0)
      {
         trailSL = currentPrice - trailDist;
         trailSL = MathMax(trailSL, entry);
         newSL = MathMax(newSL, trailSL);
      }
      else
      {
         trailSL = currentPrice + trailDist;
         trailSL = MathMin(trailSL, entry);
         newSL = MathMin(newSL, trailSL);
      }

      return newSL;
   }

   // Phase 3: Conservative trail (wide)
   if(profitATR >= g_state.config.atrTrailConservative)
   {
      double trailDist = atr * g_state.config.atrTrailConsDist;
      double trailSL = 0;

      if(direction > 0)
      {
         trailSL = currentPrice - trailDist;
         trailSL = MathMax(trailSL, entry);
         newSL = MathMax(newSL, trailSL);
      }
      else
      {
         trailSL = currentPrice + trailDist;
         trailSL = MathMin(trailSL, entry);
         newSL = MathMin(newSL, trailSL);
      }

      return newSL;
   }

   // Phase 4: Basic profit lock (if profit exists)
   if(profitPts > 0)
   {
      double lockDist = profitPts * 0.5;
      if(direction > 0)
      {
         double lockSL = currentPrice - lockDist;
         lockSL = MathMax(lockSL, entry);
         newSL = MathMax(newSL, lockSL);
      }
      else
      {
         double lockSL = currentPrice + lockDist;
         lockSL = MathMin(lockSL, entry);
         newSL = MathMin(newSL, lockSL);
      }
   }

   return newSL;
}

// ═══════════════════════════════════════════════════════════════════
// MANAGE ALL POSITIONS (main loop)
// ═══════════════════════════════════════════════════════════════════

// FIX 2026-08-03: le nom/commentaire de ScannerUseATRTrail ("Trailing ATR sur
// trades scanner") indique une portée limitée au DOW Scanner, mais la boucle
// ci-dessous ne filtrait par AUCUN magic number -> elle géraient TOUTES les
// positions de l'EA (IMPULSE, GOM-ALIGN, RSI-SQUEEZE, FVG_Kill, SMC, etc.),
// écrasant leurs SL/TP calculés avec un trailing bien plus agressif que prévu.
// Ce magic doit rester synchronisé avec req.magic dans AdaptiveExecutor.mqh
// (ligne "req.magic = 20260725; // DOW Scanner magic").
#define SCANNER_ATRTRAIL_MAGIC 20260725

void ATRTRAIL_ManageAll()
{
   if(!g_state.config.useATRTrail) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != SCANNER_ATRTRAIL_MAGIC) continue; // FIX: scope scanner only

      string symbol = PositionGetString(POSITION_SYMBOL);
      int direction = (int)PositionGetInteger(POSITION_TYPE);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double profit = PositionGetDouble(POSITION_PROFIT);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      if(TimeCurrent() - openTime < 5) continue;

      int posIdx = ATRTRAIL_GetOrCreateIdx(ticket, symbol);

      if(profit > g_atrPositions[posIdx].peakProfitUSD)
         g_atrPositions[posIdx].peakProfitUSD = profit;

      double atr = ATRTRAIL_GetATR(symbol);
      if(atr <= 0) atr = g_atrPositions[posIdx].entryATR;
      if(atr <= 0) continue;

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double currentPrice = (direction == 0) ? bid : ask;

      double newSL = ATRTRAIL_CalcNewSL(posIdx, direction, currentPrice, currentSL, atr);

      bool shouldUpdate = false;
      if(direction == 0)
         shouldUpdate = (newSL > currentSL);
      else
         shouldUpdate = (newSL < currentSL || currentSL == 0);

      if(shouldUpdate && MathAbs(newSL - currentSL) > SymbolInfoDouble(symbol, SYMBOL_POINT) * 2)
      {
         CTrade atrTrade;
         if(atrTrade.PositionModify(ticket, newSL, tp))
         {
            g_atrPositions[posIdx].lastSL = newSL;

            double profitATR = ((direction == 0) ? (currentPrice - entry) : (entry - currentPrice)) / atr;
            if(profitATR >= g_state.config.atrTrailBETrigger) g_atrPositions[posIdx].beTriggered = true;
            if(profitATR >= g_state.config.atrTrailAggressive) g_atrPositions[posIdx].aggrTriggered = true;
            if(profitATR >= g_state.config.atrTrailConservative) g_atrPositions[posIdx].consTriggered = true;

            string phase = "LOCK";
            if(g_atrPositions[posIdx].consTriggered) phase = "CONS";
            else if(g_atrPositions[posIdx].aggrTriggered) phase = "AGGR";
            else if(g_atrPositions[posIdx].beTriggered) phase = "BE";

            DebugDetail("ATRTrailing", "SL updated",
                       StringFormat("%s #%llu newSL=%.5f profit=$%.2f ATR=%.5f phase=%s",
                                   symbol, ticket, newSL, profit, atr, phase));
         }
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// CLEANUP (remove tracking for closed positions)
// ═══════════════════════════════════════════════════════════════════

void ATRTRAIL_Cleanup()
{
   for(int i = g_atrPositionCount - 1; i >= 0; i--)
   {
      bool found = false;
      for(int j = 0; j < PositionsTotal(); j++)
      {
         ulong ticket = PositionGetTicket(j);
         if(ticket == g_atrPositions[i].ticket)
         {
            found = true;
            break;
         }
      }

      if(!found)
      {
         for(int k = i; k < g_atrPositionCount - 1; k++)
            g_atrPositions[k] = g_atrPositions[k + 1];
         g_atrPositionCount--;
         ArrayResize(g_atrPositions, g_atrPositionCount);
      }
   }
}

#endif // TM_ATR_TRAILING_STOP_MQH
