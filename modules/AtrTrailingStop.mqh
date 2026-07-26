//+------------------------------------------------------------------+
//| AtrTrailingStop.mqh — Dynamic ATR-based trailing stop            |
//| Trailing adapte a la volatilite: BE rapide, trail agressif,      |
//| trail conservateur, lock profit monotone.                        |
//+------------------------------------------------------------------+
#ifndef TM_ATR_TRAILING_STOP_MQH
#define TM_ATR_TRAILING_STOP_MQH

#include "TMState.mqh"
#include "TMDebug.mqh"
#include "TMEvents.mqh"

// ═══════════════════════════════════════════════════════════════════
// ATR TRAILING STATE PER POSITION
// ═══════════════════════════════════════════════════════════════════

struct ATRTrailPosition
{
   ulong    ticket;
   double   entryATR;       // ATR au moment de l'ouverture
   double   peakProfitUSD;  // Pic de profit en USD
   double   lastSL;         // Dernier SL applique
   bool     beTriggered;    // Break-even deja active
   bool     aggrTriggered;  // Trail agressif active
   bool     consTriggered;  // Trail conservateur active
   datetime openedAt;       // Heure ouverture
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
// GET OR CREATE TRACKING FOR A POSITION
// ═══════════════════════════════════════════════════════════════════

ATRTrailPosition* ATRTRAIL_GetOrCreate(ulong ticket, string symbol)
{
   for(int i = 0; i < g_atrPositionCount; i++)
   {
      if(g_atrPositions[i].ticket == ticket)
         return &g_atrPositions[i];
   }

   // Get current ATR
   int hATR = iATR(symbol, g_state.config.atrTrailPeriod, 14);
   double atr = 0;
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

   return &g_atrPositions[idx];
}

// ═══════════════════════════════════════════════════════════════════
// GET CURRENT ATR FOR A SYMBOL
// ═══════════════════════════════════════════════════════════════════

double ATRTRAIL_GetATR(const string symbol)
{
   int hATR = iATR(symbol, g_state.config.atrTrailPeriod, 14);
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

double ATRTRAIL_CalcNewSL(const ATRTrailPosition &pos, int direction,
                           double currentPrice, double currentSL, double atr)
{
   if(atr <= 0) return currentSL;

   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   double newSL = currentSL;

   // Calculate profit in ATR units
   double profitPts = 0;
   if(direction > 0) // BUY
      profitPts = currentPrice - entry;
   else // SELL
      profitPts = entry - currentPrice;

   double profitATR = profitPts / atr;

   // === PHASE 1: Break-even trigger ===
   if(!pos.beTriggered && profitATR >= g_state.config.atrTrailBETrigger)
   {
      // Move SL to entry (breakeven)
      if(direction > 0)
         newSL = MathMax(newSL, entry);
      else
         newSL = MathMin(newSL, entry);

      return newSL;
   }

   // === PHASE 2: Aggressive trail (tight) ===
   if(profitATR >= g_state.config.atrTrailAggressive)
   {
      double trailDist = atr * g_state.config.atrTrailAggrDist;
      double trailSL = 0;

      if(direction > 0)
      {
         trailSL = currentPrice - trailDist;
         trailSL = MathMax(trailSL, entry); // Never below entry
         newSL = MathMax(newSL, trailSL);
      }
      else
      {
         trailSL = currentPrice + trailDist;
         trailSL = MathMin(trailSL, entry); // Never above entry
         newSL = MathMin(newSL, trailSL);
      }

      return newSL;
   }

   // === PHASE 3: Conservative trail (wide) ===
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

   // === PHASE 4: Basic profit lock (if profit exists) ===
   if(profitPts > 0)
   {
      // Lock 50% of current profit
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

void ATRTRAIL_ManageAll()
{
   if(!g_state.config.useATRTrail) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      int direction = (int)PositionGetInteger(POSITION_TYPE); // 0=BUY, 1=SELL
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double profit = PositionGetDouble(POSITION_PROFIT);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      // Skip if position just opened (< 5 seconds)
      if(TimeCurrent() - openTime < 5) continue;

      // Get or create tracking
      ATRTrailPosition *pos = ATRTRAIL_GetOrCreate(ticket, symbol);

      // Update peak profit
      if(profit > pos->peakProfitUSD)
         pos->peakProfitUSD = profit;

      // Get current ATR
      double atr = ATRTRAIL_GetATR(symbol);
      if(atr <= 0) atr = pos->entryATR; // Fallback to entry ATR
      if(atr <= 0) continue;

      // Get current price
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double currentPrice = (direction == 0) ? bid : ask;

      // Calculate new SL
      double newSL = ATRTRAIL_CalcNewSL(*pos, direction, currentPrice, currentSL, atr);

      // Only update if new SL is more profitable (monotone increasing for BUY, decreasing for SELL)
      bool shouldUpdate = false;
      if(direction == 0) // BUY
         shouldUpdate = (newSL > currentSL);
      else // SELL
         shouldUpdate = (newSL < currentSL || currentSL == 0);

      if(shouldUpdate && MathAbs(newSL - currentSL) > SymbolInfoDouble(symbol, SYMBOL_POINT) * 2)
      {
         CTrade trade;
         if(trade.PositionModify(ticket, newSL, tp))
         {
            pos->lastSL = newSL;

            // Update trigger flags
            double profitATR = ((direction == 0) ? (currentPrice - entry) : (entry - currentPrice)) / atr;
            if(profitATR >= g_state.config.atrTrailBETrigger) pos->beTriggered = true;
            if(profitATR >= g_state.config.atrTrailAggressive) pos->aggrTriggered = true;
            if(profitATR >= g_state.config.atrTrailConservative) pos->consTriggered = true;

            DebugDetail("ATRTrailing", "SL updated",
                       StringFormat("%s #%llu newSL=%.5f profit=$%.2f ATR=%.5f phase=%s",
                                   symbol, ticket, newSL, profit, atr,
                                   pos->consTriggered ? "CONS" :
                                   pos->aggrTriggered ? "AGGR" :
                                   pos->beTriggered ? "BE" : "LOCK"));
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
         // Position closed — remove tracking
         for(int k = i; k < g_atrPositionCount - 1; k++)
            g_atrPositions[k] = g_atrPositions[k + 1];
         g_atrPositionCount--;
         ArrayResize(g_atrPositions, g_atrPositionCount);
      }
   }
}

#endif // TM_ATR_TRAILING_STOP_MQH
