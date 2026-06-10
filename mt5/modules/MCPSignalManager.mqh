//+------------------------------------------------------------------+
//| MCPSignalManager.mqh — Poll /pending-order, ingest, validate, exec|
//| "MCP" = Multi-modal Channel Pipeline (TradingView + WhatsApp)     |
//+------------------------------------------------------------------+
#ifndef TM_MCP_MANAGER_MQH
#define TM_MCP_MANAGER_MQH

#include "TMState.mqh"
#include "HTTPTransport.mqh"
#include "ValidationPipeline.mqh"
#include "TMEvents.mqh"
#include "TMDebug.mqh"
#include "Notifications.mqh"

// ═══════════════════════════════════════════════════════════════════
// PENDING ORDER POLL & INGEST
// ═══════════════════════════════════════════════════════════════════

void MCP_PollSignals()
{
   // Rate limit: check interval from config
   if(TimeCurrent() - g_state.timing.lastMCPPoll < g_state.config.mcpPollIntervalSec)
      return;

   g_state.timing.lastMCPPoll = TimeCurrent();

   HTTPResponse resp = HTTP_GetPendingOrders();
   if(!resp.success)
   {
      DebugWarn("MCP", "Poll failed", StringFormat("code=%d", resp.code));
      return;
   }

   // Parse JSON array: [{"symbol":"XAUUSD","action":"BUY","entry":2540.5,"sl":2535.0,"tp":2550.0,"lot":0.10}, ...]
   // Simplified: just extract first order if present
   if(StringFind(resp.body, "symbol") < 0)
      return;  // Empty or invalid

   string symbol = "", action = "";
   double entry = 0.0, sl = 0.0, tp = 0.0, lot = 0.0;

   JsonGetString(resp.body, "symbol", symbol);
   JsonGetString(resp.body, "action", action);
   JsonGetDouble(resp.body, "entry", entry);
   JsonGetDouble(resp.body, "sl", sl);
   JsonGetDouble(resp.body, "tp", tp);
   JsonGetDouble(resp.body, "lot", lot);

   if(symbol == "" || entry == 0.0)
      return;  // Invalid order

   int direction = (StringFind(action, "BUY") >= 0) ? 1 : -1;

   // Ingest into pending array
   MCP_IngestOrder(symbol, direction, entry, sl, tp, lot);
}

void MCP_IngestOrder(const string symbol, int direction, double entry,
                     double sl, double tp, double lot)
{
   // Check for duplicate (same symbol, direction, entry within last 5s)
   for(int i = 0; i < g_state.mcpCount; i++)
   {
      if(g_state.mcpSignals[i].symbol == symbol &&
         g_state.mcpSignals[i].direction == direction &&
         MathAbs(g_state.mcpSignals[i].entryPrice - entry) < 0.0001 &&
         TimeCurrent() - g_state.mcpSignals[i].receivedAt < 5)
      {
         DebugWarn("MCP", "Duplicate rejected", StringFormat("%s %s @ %.5f", symbol,
                   direction==1?"BUY":"SELL", entry));
         return;
      }
   }

   int idx = AddMCPSignal();
   g_state.mcpSignals[idx].active = true;
   g_state.mcpSignals[idx].executed = false;
   g_state.mcpSignals[idx].duplicated = false;
   g_state.mcpSignals[idx].symbol = symbol;
   g_state.mcpSignals[idx].direction = direction;
   g_state.mcpSignals[idx].entryPrice = entry;
   g_state.mcpSignals[idx].stopLoss = sl;
   g_state.mcpSignals[idx].takeProfit1 = tp;
   g_state.mcpSignals[idx].lot = lot;
   g_state.mcpSignals[idx].receivedAt = TimeCurrent();
   g_state.mcpSignals[idx].entryNotifSent = false;
   g_state.mcpSignals[idx].failCount = 0;
   g_state.mcpSignals[idx].source = "pipeline";

   DebugLogSignal(symbol, direction, entry, sl, tp, "MCP_Pipeline");
   Event_MCPSignalReceived(symbol, direction);
}

// ═══════════════════════════════════════════════════════════════════
// VALIDATION & EXECUTION
// ═══════════════════════════════════════════════════════════════════

bool MCP_TryExecuteSignal(int sigIdx)
{
   if(sigIdx < 0 || sigIdx >= g_state.mcpCount) return false;
   if(g_state.mcpSignals[sigIdx].executed) return true;  // Already done

   TMMCPSignal &sig = g_state.mcpSignals[sigIdx];
   string symbol = sig.symbol;
   int direction = sig.direction;
   double entry = sig.entryPrice;
   double sl = sig.stopLoss;
   double tp = sig.takeProfit1;
   double lot = sig.lot;

   // ───────────────────────────────────────────────────────────────
   // STEP 1: Validation Pipeline
   // ───────────────────────────────────────────────────────────────

   FilterContext ctx;
   ctx.symbol = symbol;
   ctx.direction = direction;
   ctx.entryPrice = entry;
   ctx.stopLoss = sl;
   ctx.takeProfit = tp;
   ctx.source = "pipeline";
   ctx.isPipeline = true;  // Pipeline orders have priority

   string rejectReason = "", rejectFilter = "";
   if(!ValidatePipelineEntry(ctx, rejectReason, rejectFilter))
   {
      DebugWarn("MCP", "Validation rejected", StringFormat("%s %s: %s", symbol,
                direction==1?"BUY":"SELL", rejectReason));
      Event_FilterRejected(symbol, rejectReason, direction);
      sig.failCount++;
      return false;
   }

   // ───────────────────────────────────────────────────────────────
   // STEP 2: Price Adjustment (limit order tolerance)
   // ───────────────────────────────────────────────────────────────

   double adjustedEntry = entry;
   if(sig.marketExec == false && g_state.config.mcpExecuteAtMarket)
   {
      // Market execution: use bid/ask
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      adjustedEntry = (direction == 1) ? ask : bid;
   }
   else if(sig.marketExec == false)
   {
      // Limit execution: check if price touched entry ±tolerance
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double tolerance = entry * g_state.config.mcpEntryTolerancePct;

      if(direction == 1)
      {
         // BUY limit: ask must touch entry-tolerance to entry+tolerance
         if(ask > entry + tolerance)
         {
            DebugWarn("MCP", "Entry not touched", StringFormat("%s BUY: ask=%.5f > entry+tol=%.5f",
                      symbol, ask, entry + tolerance));
            return false;
         }
         adjustedEntry = ask;
      }
      else
      {
         // SELL limit: bid must touch entry-tolerance to entry+tolerance
         if(bid < entry - tolerance)
         {
            DebugWarn("MCP", "Entry not touched", StringFormat("%s SELL: bid=%.5f < entry-tol=%.5f",
                      symbol, bid, entry - tolerance));
            return false;
         }
         adjustedEntry = bid;
      }
   }

   // ───────────────────────────────────────────────────────────────
   // STEP 3: Order Execution
   // ───────────────────────────────────────────────────────────────

   CTrade trade;
   trade.SetExpertMagicNumber(g_state.config.mcpMagicNumber);
   bool success = false;

   if(direction == 1)
      success = trade.Buy(lot, symbol, adjustedEntry, sl, tp);
   else
      success = trade.Sell(lot, symbol, adjustedEntry, sl, tp);

   if(!success)
   {
      DebugError("MCP", "Trade failed", StringFormat("%s %s: %s", symbol, direction==1?"BUY":"SELL",
                 trade.ResultComment()));
      sig.failCount++;
      if(sig.failCount >= g_state.config.maxSignalFailCount)
      {
         sig.active = false;  // Give up after N failures
         DebugWarn("MCP", "Signal abandoned", StringFormat("failCount=%d", sig.failCount));
      }
      return false;
   }

   // ───────────────────────────────────────────────────────────────
   // STEP 4: Success — Update state & send notification
   // ───────────────────────────────────────────────────────────────

   sig.executed = true;
   sig.ticket = trade.ResultOrder();
   sig.entryNotifSent = true;

   DebugLogPosition(sig.ticket, symbol, direction, adjustedEntry, sl, tp, lot);
   SendWAOrderEntry(symbol, direction, adjustedEntry, sl, tp, lot, "Pipeline execution");
   Event_PositionOpened(sig.ticket, symbol, direction, adjustedEntry, lot);

   // Notify AI server of execution (for record keeping)
   string execJson = StringFormat("{\"ticket\":%llu,\"symbol\":\"%s\",\"direction\":%d,\"entry\":%.5f,\"sl\":%.5f,\"tp\":%.5f,\"lot\":%.2f}",
                                   sig.ticket, symbol, direction, adjustedEntry, sl, tp, lot);
   HTTPResponse execResp = HTTP_PostPendingOrderExecuted(sig.orderId, execJson);
   if(!execResp.success)
      DebugWarn("MCP", "Execution notification failed", StringFormat("code=%d", execResp.code));

   return true;
}

// ═══════════════════════════════════════════════════════════════════
// POSITION MANAGEMENT (after execution)
// ═══════════════════════════════════════════════════════════════════

void MCP_CheckPendingClosures()
{
   // Remove executed signals that are no longer relevant
   for(int i = 0; i < g_state.mcpCount; i++)
   {
      if(!g_state.mcpSignals[i].executed) continue;

      ulong ticket = g_state.mcpSignals[i].ticket;
      if(!PositionSelect(ticket))
      {
         // Position closed
         g_state.mcpSignals[i].active = false;
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// DUPLICATION LOGIC (after position reaches min profit)
// ═══════════════════════════════════════════════════════════════════

void MCP_CheckDuplication()
{
   if(!g_state.config.mcpDuplicateOnce)
      return;

   for(int i = 0; i < g_state.mcpCount; i++)
   {
      if(!g_state.mcpSignals[i].executed || g_state.mcpSignals[i].duplicated)
         continue;

      TMMCPSignal &sig = g_state.mcpSignals[i];
      ulong ticket = sig.ticket;

      if(!PositionSelect(ticket))
         continue;

      // Check if position is profitable
      double currentProfit = PositionGetDouble(POSITION_PROFIT);
      if(currentProfit < sig.lot * g_state.config.mcpDuplicateMinProfit)
         continue;  // Not yet at min profit

      // Check if profit has been stable for DupProfitStableSec
      if(TimeCurrent() - sig.receivedAt < g_state.config.dupProfitStableSec)
         continue;

      // Check duplication criteria
      if(g_state.config.duplicateRequireGoodPerfect && MathAbs(g_state.gom.verdictNum) < 2)
         continue;  // Need at least GOOD (±2)

      if(g_state.gom.globalStrength < g_state.config.duplicateMinGlobalStrength)
         continue;

      if(g_state.gom.quality < g_state.config.duplicateMinQuality)
         continue;

      if(g_state.gom.coherence < g_state.config.duplicateMinCoherence)
         continue;

      // ───────────────────────────────────────────────────────────
      // DUPLICATE: Open second position with half lot
      // ───────────────────────────────────────────────────────────

      CTrade trade;
      trade.SetExpertMagicNumber(g_state.config.mcpMagicNumber);

      double dupLot = sig.lot * 0.5;
      double bid = SymbolInfoDouble(sig.symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(sig.symbol, SYMBOL_ASK);

      bool dupSuccess = false;
      if(sig.direction == 1)
         dupSuccess = trade.Buy(dupLot, sig.symbol, ask, sig.stopLoss, sig.takeProfit1);
      else
         dupSuccess = trade.Sell(dupLot, sig.symbol, bid, sig.stopLoss, sig.takeProfit1);

      if(dupSuccess)
      {
         sig.duplicated = true;
         DebugInfo("MCP", "Duplication executed", StringFormat("%s dup_lot=%.2f", sig.symbol, dupLot));
         SendWAAlert("Duplication", StringFormat("%s duplicated at %.5f with %.2f lot", sig.symbol,
                     sig.direction==1?ask:bid, dupLot));
         AddDuplicateTicket(trade.ResultOrder());
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void MCP_Init()
{
   g_state.mcpCount = 0;
   g_state.timing.lastMCPPoll = 0;
   DebugInfo("MCPSignalManager", "Initialized", "Ready to poll /pending-order");
}

void MCP_Tick()
{
   // 1. Poll new signals from AI server
   MCP_PollSignals();

   // 2. Try to execute pending signals
   for(int i = 0; i < g_state.mcpCount; i++)
   {
      if(g_state.mcpSignals[i].active && !g_state.mcpSignals[i].executed)
      {
         MCP_TryExecuteSignal(i);
      }
   }

   // 3. Check for closed positions
   MCP_CheckPendingClosures();

   // 4. Check duplication criteria
   MCP_CheckDuplication();
}

void MCP_Deinit()
{
   DebugInfo("MCPSignalManager", "Shutdown", StringFormat("processed %d signals", g_state.mcpCount));
}

#endif // TM_MCP_MANAGER_MQH
