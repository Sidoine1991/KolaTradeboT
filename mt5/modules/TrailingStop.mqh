//+------------------------------------------------------------------+
//| TrailingStop.mqh — Trailing, stagnation exit, profit giveback    |
//+------------------------------------------------------------------+
#ifndef TM_TRAILING_STOP_MQH
#define TM_TRAILING_STOP_MQH

#include "TMState.mqh"
#include "TMDebug.mqh"
#include "TMEvents.mqh"
#include "Notifications.mqh"

// ═══════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════

#define GRACE_PERIOD_SEC 120  // Min time before allowing closure

// ═══════════════════════════════════════════════════════════════════
// TRAILING STOP LOGIC
// ═══════════════════════════════════════════════════════════════════

void Trail_ManageTrailing()
{
   if(!g_state.config.useTrailing)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      int direction = (int)PositionGetInteger(POSITION_TYPE);  // 0=BUY, 1=SELL
      double posOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      double profit = PositionGetDouble(POSITION_PROFIT);

      // ─────────────────────────────────────────────────────────
      // STEP 1: Check if position is profitable enough for trailing
      // ─────────────────────────────────────────────────────────

      if(profit < g_state.config.trailActivateUSD)
         continue;  // Not profitable enough yet

      // ─────────────────────────────────────────────────────────
      // STEP 2: Track peak profit for this ticket
      // ─────────────────────────────────────────────────────────

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double currentPrice = (direction == 0) ? bid : ask;

      double peakProfit = GetTicketPeak(ticket);
      if(peakProfit == 0.0 || profit > peakProfit)
      {
         SetTicketPeak(ticket, profit);
         peakProfit = profit;
      }

      // ─────────────────────────────────────────────────────────
      // STEP 3: Calculate new SL based on peak (lock in profit)
      // ─────────────────────────────────────────────────────────

      double lockMinUSD = peakProfit * (1.0 - g_state.config.trailLockPct);  // 30% giveback
      if(lockMinUSD < 0.1) lockMinUSD = 0.1;  // Min floor

      double newSL = 0.0;
      if(direction == 0)  // BUY
      {
         double givebackDistance = (peakProfit * g_state.config.trailLockPct) / bid;
         newSL = bid - givebackDistance;
         newSL = MathMax(newSL, posOpen);  // Don't move SL below entry
      }
      else  // SELL
      {
         double givebackDistance = (peakProfit * g_state.config.trailLockPct) / ask;
         newSL = ask + givebackDistance;
         newSL = MathMin(newSL, posOpen);  // Don't move SL above entry
      }

      // Only update if new SL is more profitable than current
      if((direction == 0 && newSL > sl) || (direction == 1 && newSL < sl))
      {
         CTrade trade;
         trade.PositionModify(ticket, newSL, tp);
         DebugDetail("TrailingStop", "SL updated", StringFormat("%s #%llu newSL=%.5f peakProfit=%.2f",
                    symbol, ticket, newSL, peakProfit));
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// STAGNATION EXIT (position stuck at same profit for too long)
// ═══════════════════════════════════════════════════════════════════

void Trail_ManageStagnation()
{
   if(!g_state.config.useStagnationExit)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      int direction = (int)PositionGetInteger(POSITION_TYPE);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      double profit = PositionGetDouble(POSITION_PROFIT);

      // ─────────────────────────────────────────────────────────
      // Check if entering stagnation zone (profit >= trigger)
      // ─────────────────────────────────────────────────────────

      if(profit < g_state.config.stagnationTriggerUSD)
      {
         // Not yet in stagnation zone
         int symIdx = AddOrGetSymbolState(symbol);
         g_state.symbols[symIdx].stagnationArmed = false;
         continue;
      }

      int symIdx = AddOrGetSymbolState(symbol);

      if(!g_state.symbols[symIdx].stagnationArmed)
      {
         // Entering stagnation zone for first time
         g_state.symbols[symIdx].stagnationArmed = true;
         g_state.symbols[symIdx].stagnationZoneSince = TimeCurrent();
         g_state.symbols[symIdx].stagnationPeakUSD = profit;
         g_state.symbols[symIdx].stagnationLastPeakTime = TimeCurrent();
         DebugDetail("TrailingStop", "Stagnation armed", StringFormat("%s #%llu profit=%.2f",
                    symbol, ticket, profit));
         continue;
      }

      // ─────────────────────────────────────────────────────────
      // Monitor for profit recul (giveback) in stagnation zone
      // ─────────────────────────────────────────────────────────

      double maxGiveback = g_state.symbols[symIdx].stagnationPeakUSD * g_state.config.stagnationMaxGivebackUSD;
      double minFloor = g_state.symbols[symIdx].stagnationPeakUSD - maxGiveback;

      if(profit > g_state.symbols[symIdx].stagnationPeakUSD)
      {
         // New peak in stagnation zone
         g_state.symbols[symIdx].stagnationPeakUSD = profit;
         g_state.symbols[symIdx].stagnationLastPeakTime = TimeCurrent();
         DebugDetail("TrailingStop", "New peak in stagnation", StringFormat("%s profit=%.2f", symbol, profit));
         continue;
      }

      // Check if profit has receded below floor
      if(profit < minFloor)
      {
         // Recul > maxGiveback — close position
         CTrade trade;
         trade.PositionClose(ticket);
         DebugLogClose(ticket, symbol, direction, 0.0, profit, "Stagnation exit: recul > threshold");
         SendWAOrderClose(symbol, direction, 0.0, 0.0, profit, "Stagnation exit");
         Event_PositionClosed(ticket, symbol, direction, 0.0, profit);
         g_state.symbols[symIdx].stagnationArmed = false;
         continue;
      }

      // ─────────────────────────────────────────────────────────
      // Timeout: if profit has been stuck for too long, close
      // ─────────────────────────────────────────────────────────

      if(TimeCurrent() - g_state.symbols[symIdx].stagnationLastPeakTime > g_state.config.stagnationHoldSec)
      {
         CTrade trade;
         trade.PositionClose(ticket);
         DebugLogClose(ticket, symbol, direction, 0.0, profit, "Stagnation exit: timeout");
         SendWAOrderClose(symbol, direction, 0.0, 0.0, profit, "Stagnation timeout");
         Event_PositionClosed(ticket, symbol, direction, 0.0, profit);
         g_state.symbols[symIdx].stagnationArmed = false;
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// PROFIT GIVEBACK EXIT (if we turn unprofitable after being profitable)
// ═══════════════════════════════════════════════════════════════════

void Trail_ManageProfitGiveback()
{
   if(!g_state.config.useProfitGiveback)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      int direction = (int)PositionGetInteger(POSITION_TYPE);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      double profit = PositionGetDouble(POSITION_PROFIT);

      int symIdx = AddOrGetSymbolState(symbol);

      // ─────────────────────────────────────────────────────────
      // Track peak profit ever achieved
      // ─────────────────────────────────────────────────────────

      if(profit > g_state.symbols[symIdx].peakProfit)
         g_state.symbols[symIdx].peakProfit = profit;

      // ─────────────────────────────────────────────────────────
      // Arm giveback exit if position hits min profit
      // ─────────────────────────────────────────────────────────

      if(!g_state.symbols[symIdx].waitingReEntry && profit >= g_state.config.profitGivebackArmUSD)
      {
         // Track that we've been profitable enough to arm giveback
         g_state.symbols[symIdx].waitingReEntry = true;  // Repurpose flag: armed for giveback
      }

      // Check for give-back if armed
      if(g_state.symbols[symIdx].waitingReEntry)
      {
         double maxGiveback = g_state.symbols[symIdx].peakProfit * g_state.config.maxGivebackFromPeakUSD;
         double floor = g_state.symbols[symIdx].peakProfit - maxGiveback;

         if(profit < floor)
         {
            // Giveback threshold exceeded → close
            CTrade trade;
            trade.PositionClose(ticket);
            DebugLogClose(ticket, symbol, direction, 0.0, profit, StringFormat("Giveback: peak=%.2f max=%.2f",
                         g_state.symbols[symIdx].peakProfit, maxGiveback));
            SendWAOrderClose(symbol, direction, 0.0, 0.0, profit, "Profit giveback protection");
            Event_PositionClosed(ticket, symbol, direction, 0.0, profit);
            g_state.symbols[symIdx].waitingReEntry = false;
            g_state.symbols[symIdx].peakProfit = 0.0;
            continue;
         }
      }

      // ─────────────────────────────────────────────────────────
      // Absolute max loss cap (never trade if going below -MaxRiskUSD)
      // ─────────────────────────────────────────────────────────

      if(profit < -g_state.config.maxRiskUSD)
      {
         CTrade trade;
         trade.PositionClose(ticket);
         DebugLogClose(ticket, symbol, direction, 0.0, profit, "Max loss cap");
         SendWAOrderClose(symbol, direction, 0.0, 0.0, profit, "Max loss reached");
         Event_PositionClosed(ticket, symbol, direction, 0.0, profit);
         g_state.symbols[symIdx].waitingReEntry = false;
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// GRACE PERIOD CHECK (positions must stay open minimum 120 seconds)
// ═══════════════════════════════════════════════════════════════════

bool Trail_IsInGracePeriod(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   return (TimeCurrent() - openTime < GRACE_PERIOD_SEC);
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void Trail_Init()
{
   DebugInfo("TrailingStop", "Initialized", StringFormat("trailing=%d stagnation=%d giveback=%d",
            g_state.config.useTrailing ? 1 : 0, g_state.config.useStagnationExit ? 1 : 0,
            g_state.config.useProfitGiveback ? 1 : 0));
}

void Trail_Tick()
{
   Trail_ManageTrailing();
   Trail_ManageStagnation();
   Trail_ManageProfitGiveback();
}

void Trail_Deinit()
{
   DebugInfo("TrailingStop", "Shutdown");
}

#endif // TM_TRAILING_STOP_MQH
