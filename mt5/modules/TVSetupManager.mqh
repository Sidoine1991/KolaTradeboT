//+------------------------------------------------------------------+
//| TVSetupManager.mqh — Manage TV setup limit orders (OB/KOLA)      |
//+------------------------------------------------------------------+
#ifndef TM_TV_SETUP_MQH
#define TM_TV_SETUP_MQH

#include "TMState.mqh"
#include "ValidationPipeline.mqh"
#include "TMEvents.mqh"
#include "TMDebug.mqh"
#include "Notifications.mqh"

// ═══════════════════════════════════════════════════════════════════
// SETUP INGESTION (read from TradingView table)
// ═══════════════════════════════════════════════════════════════════

void TV_RefreshSetup()
{
   // In production: read from TV table via Pine script data window
   // For now: placeholder to detect setup from KOLA + BB if TV unavailable

   if(!g_state.config.useTVSetup)
      return;

   if(!g_state.config.tvSetupInferFromGOM)
   {
      // Assume TV provides setup; check for change
      // This would read from a custom indicator that exports setup via label/table
      // For now, mark as invalid (waiting for TV data)
      g_state.setup.valid = false;
      return;
   }

   // ───────────────────────────────────────────────────────────────
   // INFER from KOLA + BB if TV unavailable
   // ───────────────────────────────────────────────────────────────

   if(g_state.gom.verdictNum == 0)
   {
      g_state.setup.valid = false;
      return;  // WAIT = no setup
   }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   int direction = (g_state.gom.verdictNum > 0) ? 1 : -1;
   double bbWidth = g_state.gom.bbUp - g_state.gom.bbDn;

   // Setup entry = nearest KOLA level
   double setupEntry = (direction == 1) ? g_state.gom.kolaBuy : g_state.gom.kolaSell;
   if(setupEntry == 0.0)
      setupEntry = g_state.gom.bbMid;  // Fallback to BB mid

   // SL = outside opposite band
   double setupSL = (direction == 1) ? (setupEntry - bbWidth * 0.5) : (setupEntry + bbWidth * 0.5);

   // TP1 = half band width above
   double tp1 = (direction == 1) ? (setupEntry + bbWidth * 0.5) : (setupEntry - bbWidth * 0.5);

   // TP2 = full band width
   double tp2 = (direction == 1) ? (setupEntry + bbWidth) : (setupEntry - bbWidth);

   double rr = MathAbs(tp2 - setupEntry) / MathAbs(setupSL - setupEntry);

   // ───────────────────────────────────────────────────────────────
   // DETECT CHANGE (same setup = no refresh)
   // ───────────────────────────────────────────────────────────────

   string setupKey = StringFormat("%d_%.5f_%.5f_%.5f", direction, setupEntry, setupSL, tp1);
   if(g_state.setup.key == setupKey)
      return;  // No change

   g_state.setup.key = setupKey;
   g_state.setup.valid = true;
   g_state.setup.direction = direction;
   g_state.setup.entry = setupEntry;
   g_state.setup.sl = setupSL;
   g_state.setup.tp1 = tp1;
   g_state.setup.tp2 = tp2;
   g_state.setup.rr = rr;
   g_state.setup.type = (direction == 1) ? "OB_BULL" : "OB_BEAR";
   g_state.setup.confirm = (g_state.gom.verdictNum > 1 || g_state.gom.verdictNum < -1) ? "GOOD" : "SIMPLE";

   DebugInfo("TVSetup", "Setup inferred", StringFormat("%s entry=%.5f sl=%.5f rr=%.2f",
            g_state.setup.type, setupEntry, setupSL, rr));
   Event_SetupChanged(_Symbol);
}

// ═══════════════════════════════════════════════════════════════════
// LIMIT ORDER MANAGEMENT
// ═══════════════════════════════════════════════════════════════════

void TV_ManageLimitOrder()
{
   if(!g_state.config.useTVSetupLimit)
      return;

   TV_RefreshSetup();

   if(!g_state.setup.valid)
   {
      // No setup; cancel any pending order
      if(g_state.setup.orderTicket > 0 && PositionSelectByTicket(g_state.setup.orderTicket))
      {
         CTrade trade;
         trade.OrderDelete(g_state.setup.orderTicket);
         g_state.setup.orderTicket = 0;
         DebugDetail("TVSetup", "Pending order cancelled", "No valid setup");
      }
      return;
   }

   // ───────────────────────────────────────────────────────────────
   // CHECK IF GOM=WAIT (block or cancel limit order)
   // ───────────────────────────────────────────────────────────────

   if(g_state.gom.verdictNum == 0)  // WAIT
   {
      if(g_state.config.tvSetupBlockPlaceOnWait)
      {
         // Don't place if GOM=WAIT
         if(g_state.setup.orderTicket == 0)
         {
            DebugDetail("TVSetup", "Order blocked", "GOM=WAIT");
            return;
         }
      }

      if(g_state.config.tvSetupCancelOnWaitTouch)
      {
         // If entry was touched while GOM=WAIT, cancel
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double tolerance = g_state.setup.entry * g_state.config.tvSetupEntryTolPct;

         bool touched = false;
         if(g_state.setup.direction == 1 && ask >= g_state.setup.entry - tolerance)
            touched = true;
         if(g_state.setup.direction == -1 && bid <= g_state.setup.entry + tolerance)
            touched = true;

         if(touched && g_state.setup.orderTicket > 0)
         {
            if(PositionSelectByTicket(g_state.setup.orderTicket))
            {
               CTrade trade;
               trade.OrderDelete(g_state.setup.orderTicket);
               DebugDetail("TVSetup", "Pending cancelled", "Entry touched + GOM=WAIT");
               g_state.setup.orderTicket = 0;
               g_state.setup.cancelAt = TimeCurrent();
               return;
            }
         }
      }
   }

   // ───────────────────────────────────────────────────────────────
   // PLACE LIMIT ORDER (if not already active)
   // ───────────────────────────────────────────────────────────────

   if(g_state.setup.orderTicket == 0)
   {
      CTrade trade;
      trade.SetExpertMagicNumber(g_state.config.tvSetupMagicNumber);

      bool success = false;
      if(g_state.setup.direction == 1)
         success = trade.BuyLimit(0.01, g_state.setup.entry, _Symbol, g_state.setup.sl, g_state.setup.tp1);
      else
         success = trade.SellLimit(0.01, g_state.setup.entry, _Symbol, g_state.setup.sl, g_state.setup.tp1);

      if(success)
      {
         g_state.setup.orderTicket = trade.ResultOrder();
         g_state.setup.placedAt = TimeCurrent();
         g_state.setup.entryTouched = false;
         DebugInfo("TVSetup", "Limit order placed", StringFormat("#%llu %s @ %.5f",
                  g_state.setup.orderTicket, g_state.setup.direction==1?"BUY":"SELL", g_state.setup.entry));
         SendWAAlert("TV Setup", StringFormat("%s limit @ %.5f (SL=%.5f TP=%.5f RR=%.2f)",
                    g_state.setup.type, g_state.setup.entry, g_state.setup.sl, g_state.setup.tp1, g_state.setup.rr));
      }
      else
      {
         DebugWarn("TVSetup", "Limit order failed", trade.ResultComment());
         g_state.setup.placeFailAt = TimeCurrent();
      }
      return;
   }

   // ───────────────────────────────────────────────────────────────
   // MONITOR: Check if entry was touched
   // ───────────────────────────────────────────────────────────────

   if(!g_state.setup.entryTouched)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double tolerance = g_state.setup.entry * g_state.config.tvSetupEntryTolPct;

      if(g_state.setup.direction == 1 && ask >= g_state.setup.entry - tolerance)
         g_state.setup.entryTouched = true;
      if(g_state.setup.direction == -1 && bid <= g_state.setup.entry + tolerance)
         g_state.setup.entryTouched = true;

      if(g_state.setup.entryTouched)
         DebugDetail("TVSetup", "Entry touched", "Waiting for breakout confirmation");
   }

   // ───────────────────────────────────────────────────────────────
   // BREAKOUT: Market execution if price breaks above entry
   // ───────────────────────────────────────────────────────────────

   if(g_state.config.tvSetupMarketOnBreakout && g_state.setup.entryTouched)
   {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double breakoutTol = g_state.setup.entry * g_state.config.tvSetupBreakoutTolPct;

      bool breakoutUp = (g_state.setup.direction == 1) && (bid > g_state.setup.entry + breakoutTol);
      bool breakoutDn = (g_state.setup.direction == -1) && (ask < g_state.setup.entry - breakoutTol);

      if(breakoutUp || breakoutDn)
      {
         // ─────────────────────────────────────────────────────────
         // VALIDATE before market entry
         // ─────────────────────────────────────────────────────────

         FilterContext ctx;
         ctx.symbol = _Symbol;
         ctx.direction = g_state.setup.direction;
         ctx.entryPrice = (g_state.setup.direction == 1) ? ask : bid;
         ctx.stopLoss = g_state.setup.sl;
         ctx.takeProfit = g_state.setup.tp1;
         ctx.source = "tv_setup_breakout";
         ctx.isPipeline = false;

         string rejectReason = "", rejectFilter = "";
         if(!ValidateGOMAutoEntry(ctx, rejectReason, rejectFilter))
         {
            DebugWarn("TVSetup", "Breakout entry rejected", rejectReason);
            return;
         }

         // ─────────────────────────────────────────────────────────
         // EXECUTE market order
         // ─────────────────────────────────────────────────────────

         CTrade trade;
         trade.SetExpertMagicNumber(g_state.config.tvSetupMagicNumber);

         bool success = false;
         if(g_state.setup.direction == 1)
            success = trade.Buy(0.01, _Symbol, ask, g_state.setup.sl, g_state.setup.tp1);
         else
            success = trade.Sell(0.01, _Symbol, bid, g_state.setup.sl, g_state.setup.tp1);

         if(success)
         {
            DebugInfo("TVSetup", "Breakout market execution", StringFormat("#%llu %s @ %.5f",
                     trade.ResultOrder(), g_state.setup.direction==1?"BUY":"SELL",
                     g_state.setup.direction==1?ask:bid));
            SendWAOrderEntry(_Symbol, g_state.setup.direction, ctx.entryPrice, g_state.setup.sl,
                           g_state.setup.tp1, 0.01, "TV setup breakout");
            g_state.setup.orderTicket = 0;  // Clear limit order
            g_state.setup.valid = false;    // Reset setup
         }
         else
         {
            DebugError("TVSetup", "Breakout execution failed", trade.ResultComment());
         }
      }
   }

   // ───────────────────────────────────────────────────────────────
   // REARM: Allow new setup after timeout
   // ───────────────────────────────────────────────────────────────

   if(g_state.setup.cancelAt > 0)
   {
      if(TimeCurrent() - g_state.setup.cancelAt > g_state.config.tvSetupRearmCooldownSec)
      {
         g_state.setup.cancelAt = 0;
         g_state.setup.valid = false;  // Reset for next setup
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void TV_Init()
{
   g_state.setup.valid = false;
   g_state.setup.orderTicket = 0;
   DebugInfo("TVSetupManager", "Initialized", StringFormat("tvSetupLimit=%d infer=%d marketOnBreakout=%d",
            g_state.config.useTVSetupLimit ? 1 : 0, g_state.config.tvSetupInferFromGOM ? 1 : 0,
            g_state.config.tvSetupMarketOnBreakout ? 1 : 0));
}

void TV_Tick()
{
   TV_ManageLimitOrder();
}

void TV_Deinit()
{
   if(g_state.setup.orderTicket > 0 && PositionSelectByTicket(g_state.setup.orderTicket))
   {
      CTrade trade;
      trade.OrderDelete(g_state.setup.orderTicket);
   }
   DebugInfo("TVSetupManager", "Shutdown", "Pending orders cancelled");
}

#endif // TM_TV_SETUP_MQH
