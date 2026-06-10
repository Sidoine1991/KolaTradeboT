//+------------------------------------------------------------------+
//| DerivEngine.mqh — Boom/Crash/Volatility spike detection + entry  |
//| ICT framework: BOS, CHÓCH, Liq sweep, OB, FVG, OTE               |
//+------------------------------------------------------------------+
#ifndef TM_DERIV_ENGINE_MQH
#define TM_DERIV_ENGINE_MQH

#include "TMState.mqh"
#include "ValidationPipeline.mqh"
#include "TMEvents.mqh"
#include "TMDebug.mqh"
#include "Notifications.mqh"

// ═══════════════════════════════════════════════════════════════════
// SPIKE DETECTION (candle with extended wick)
// ═══════════════════════════════════════════════════════════════════

bool DRV_IsSpike(int barShift = 0)
{
   if(!g_state.config.useDerivEngine)
      return false;

   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M1, barShift, 1, rates) < 1)
      return false;

   double atr = iATR(_Symbol, PERIOD_M1, 14, barShift);
   if(atr <= 0) return false;

   double body = MathAbs(rates[0].close - rates[0].open);
   double wickHi = rates[0].high - MathMax(rates[0].open, rates[0].close);
   double wickLo = MathMin(rates[0].open, rates[0].close) - rates[0].low;

   double bodyReq = g_state.config.drv_spikeBodyMult * atr;
   double wickReq = g_state.config.drv_spikeWickMult * atr;

   // Spike = small body + large wick
   bool isSpike = (body < bodyReq) && (MathMax(wickHi, wickLo) > wickReq);

   return isSpike;
}

// ═══════════════════════════════════════════════════════════════════
// CYCLE TRACKING (detect spike cycles)
// ═══════════════════════════════════════════════════════════════════

void DRV_UpdateCycle()
{
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M1, 0, g_state.config.drv_barsMin + 5, rates) < g_state.config.drv_barsMin)
      return;

   int totalBars = ArraySize(rates);

   // Detect if we just completed a cycle (every N bars)
   if(g_state.deriv.lastProcessedBar == rates[0].time)
      return;  // Already processed this bar

   g_state.deriv.lastProcessedBar = rates[0].time;

   // Check for spike in recent bars
   for(int i = 1; i < MathMin(5, totalBars); i++)
   {
      double body = MathAbs(rates[i].close - rates[i].open);
      double atr = iATR(_Symbol, PERIOD_M1, 14, i);
      if(atr <= 0) continue;

      double bodyReq = g_state.config.drv_spikeBodyMult * atr;
      double wickHi = rates[i].high - MathMax(rates[i].open, rates[i].close);
      double wickLo = MathMin(rates[i].open, rates[i].close) - rates[i].low;
      double wickReq = g_state.config.drv_spikeWickMult * atr;

      if(body < bodyReq && MathMax(wickHi, wickLo) > wickReq)
      {
         g_state.deriv.barsSinceSpike = 0;
         g_state.deriv.lastSpikeBar = rates[i].time;
         g_state.deriv.spikeExtHigh = rates[i].high;
         g_state.deriv.spikeExtLow = rates[i].low;
         DebugDetail("DerivEngine", "Spike detected", StringFormat("barsSince=0 at %.5f", rates[i].high));
         Event_SpikeDetected(_Symbol, 0);
         return;
      }
   }

   g_state.deriv.barsSinceSpike++;
}

// ═══════════════════════════════════════════════════════════════════
// ICT SCORING (Order Block, FVG, BOS/CHÓCH presence)
// ═══════════════════════════════════════════════════════════════════

int DRV_CalcICTScore()
{
   int score = 0;

   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M1, 0, g_state.config.drv_ictLookback, rates) < g_state.config.drv_ictLookback)
      return score;

   // BOS Detection: break of structure (higher high, higher low / lower low, lower high)
   if(g_state.config.drv_useBOS && ArraySize(rates) >= 3)
   {
      if((rates[1].high > rates[2].high && rates[0].high > rates[1].high) ||
         (rates[1].low < rates[2].low && rates[0].low < rates[1].low))
         score += 15;  // Strong BOS
   }

   // CHÓCH Detection: change of character (significant shift in structure)
   if(g_state.config.drv_useCHOCH && ArraySize(rates) >= 5)
   {
      double avgBodiesOld = 0.0, avgBodiesNew = 0.0;
      for(int i = 2; i < 4; i++) avgBodiesOld += MathAbs(rates[i].close - rates[i].open);
      for(int i = 0; i < 2; i++) avgBodiesNew += MathAbs(rates[i].close - rates[i].open);
      if(avgBodiesNew > avgBodiesOld * 1.5)
         score += 10;  // Character change
   }

   // Order Block: strong rejection candle
   if(g_state.config.drv_useOB)
   {
      if(ArraySize(rates) >= 2)
      {
         double spread = MathAbs(rates[1].high - rates[1].low);
         double body = MathAbs(rates[1].close - rates[1].open);
         if(body > spread * 0.6)
            score += 8;  // Strong OB candle
      }
   }

   // Fair Value Gap: gap between candles without fill
   if(g_state.config.drv_useFVG && ArraySize(rates) >= 3)
   {
      if(rates[2].high < rates[0].low || rates[2].low > rates[0].high)
         score += 5;  // Unfilled gap
   }

   // Optimal Trade Entry (Fib 62-79%)
   if(g_state.config.drv_useOTE && g_state.deriv.lastSpikeBar > 0)
   {
      double spikeRange = g_state.deriv.spikeExtHigh - g_state.deriv.spikeExtLow;
      double fib62 = g_state.deriv.spikeExtLow + (spikeRange * 0.62);
      double fib79 = g_state.deriv.spikeExtLow + (spikeRange * 0.79);

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid >= fib62 && bid <= fib79)
         score += 7;  // Within OTE zone
   }

   return score;
}

// ═══════════════════════════════════════════════════════════════════
// ENTRY EVALUATION
// ═══════════════════════════════════════════════════════════════════

bool DRV_EvaluateEntry(int &direction)
{
   if(!g_state.config.useDerivEngine)
      return false;

   // ─────────────────────────────────────────────────────────────
   // Check if we're in spike anticipation window
   // ─────────────────────────────────────────────────────────────

   int barsInCycle = g_state.deriv.barsSinceSpike;
   int cycleLen = g_state.config.drv_barsMin;

   double windowStart = cycleLen * g_state.config.drv_windowStart;
   double windowEnd = cycleLen * g_state.config.drv_windowEnd;

   if(barsInCycle < windowStart || barsInCycle > windowEnd)
      return false;  // Outside anticipation window

   // ─────────────────────────────────────────────────────────────
   // Calculate ICT score
   // ─────────────────────────────────────────────────────────────

   int ictScore = DRV_CalcICTScore();
   g_state.deriv.ictScore = ictScore;

   if(ictScore < g_state.config.drv_minICTScore)
      return false;  // Score too low

   // Grade the score
   if(ictScore >= 40) g_state.deriv.ictGrade = "A";
   else if(ictScore >= 30) g_state.deriv.ictGrade = "B";
   else if(ictScore >= 20) g_state.deriv.ictGrade = "C";
   else g_state.deriv.ictGrade = "D";

   // ─────────────────────────────────────────────────────────────
   // DETERMINE DIRECTION (counter-trend vs spike direction)
   // ─────────────────────────────────────────────────────────────

   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M1, 0, 3, rates) < 3)
      return false;

   // Boom: trend DOWN → spike UP → BUY pullback
   // Crash: trend UP → spike DOWN → SELL pullback
   direction = (rates[0].close > rates[1].close) ? 1 : -1;

   DebugDetail("DerivEngine", "Entry evaluated", StringFormat("dir=%s ictScore=%d grade=%s",
              direction==1?"BUY":"SELL", ictScore, g_state.deriv.ictGrade));

   return true;
}

// ═══════════════════════════════════════════════════════════════════
// POSITION MANAGEMENT (quick exit, smart BE, trailing)
// ═══════════════════════════════════════════════════════════════════

void DRV_ManagePosition()
{
   if(!g_state.config.useDerivEngine)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != g_state.config.tvSetupMagicNumber) continue;

      int direction = (int)PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      // ─────────────────────────────────────────────────────────
      // Quick exit: close on next spike bar
      // ─────────────────────────────────────────────────────────

      if(g_state.config.drv_useQuickExit)
      {
         double atr = iATR(_Symbol, PERIOD_M1, 14, 0);
         double profitReq = atr * (g_state.config.drv_quickExitMinPct / 100.0);

         if(profit > profitReq && g_state.deriv.barsSinceSpike < 2)
         {
            CTrade trade;
            trade.PositionClose(ticket);
            DebugLogClose(ticket, _Symbol, direction, 0.0, profit, "DerivEngine quick exit");
            SendWAOrderClose(_Symbol, direction, 0.0, 0.0, profit, "Deriv quick exit");
         }
      }

      // ─────────────────────────────────────────────────────────
      // Time stop: close after N minutes
      // ─────────────────────────────────────────────────────────

      if(g_state.config.drv_TimeStopMin > 0)
      {
         if(TimeCurrent() - openTime > g_state.config.drv_timeStopMin * 60)
         {
            CTrade trade;
            trade.PositionClose(ticket);
            DebugLogClose(ticket, _Symbol, direction, 0.0, profit, StringFormat("DerivEngine time stop %dmin", g_state.config.drv_timeStopMin));
            SendWAOrderClose(_Symbol, direction, 0.0, 0.0, profit, "Deriv time stop");
         }
      }

      // ─────────────────────────────────────────────────────────
      // Smart breakeven: move SL to entry at N×ATR profit
      // ─────────────────────────────────────────────────────────

      if(g_state.config.drv_useSmartBE && !g_state.deriv.beTriggered)
      {
         double atr = iATR(_Symbol, PERIOD_M1, 14, 0);
         double beTrigger = atr * g_state.config.drv_beTrigger;

         if(profit > beTrigger)
         {
            double entry = PositionGetDouble(POSITION_PRICE_OPEN);
            CTrade trade;
            trade.PositionModify(ticket, entry, tp);
            g_state.deriv.beTriggered = true;
            DebugDetail("DerivEngine", "Smart BE triggered", StringFormat("sl moved to entry %.5f", entry));
         }
      }

      // ─────────────────────────────────────────────────────────
      // Trailing: lock in profit
      // ─────────────────────────────────────────────────────────

      if(g_state.config.drv_useTrail)
      {
         double atr = iATR(_Symbol, PERIOD_M1, 14, 0);
         double trailDist = atr * g_state.config.drv_trailATR;
         double trailActivation = atr * g_state.config.drv_trailActivation;

         if(profit > trailActivation)
         {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double newSL = (direction == 0) ? (bid - trailDist) : (bid + trailDist);

            if((direction == 0 && newSL > sl) || (direction == 1 && newSL < sl))
            {
               CTrade trade;
               trade.PositionModify(ticket, newSL, tp);
               DebugDetail("DerivEngine", "Trailing SL updated", StringFormat("newSL=%.5f", newSL));
            }
         }
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void DRV_Init()
{
   g_state.deriv.barsSinceSpike = 0;
   g_state.deriv.lastProcessedBar = 0;
   g_state.deriv.beTriggered = false;

   // Create indicator handles
   g_state.deriv.hATR = iATR(_Symbol, PERIOD_M1, 14);
   g_state.deriv.hRSI = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);

   DebugInfo("DerivEngine", "Initialized", StringFormat("enabled=%d windowStart=%.0f%% windowEnd=%.0f%%",
            g_state.config.useDerivEngine ? 1 : 0, g_state.config.drv_windowStart * 100,
            g_state.config.drv_windowEnd * 100));
}

void DRV_Tick()
{
   DRV_UpdateCycle();
   DRV_ManagePosition();

   // Check for entry opportunities (would be called by MCP executor)
   // int direction = 0;
   // if(DRV_EvaluateEntry(direction))
   // {
   //   Emit entry signal or execute
   // }
}

void DRV_Deinit()
{
   // Release indicator handles
   if(g_state.deriv.hATR != INVALID_HANDLE) ReleasedIndicator(g_state.deriv.hATR);
   if(g_state.deriv.hRSI != INVALID_HANDLE) ReleasedIndicator(g_state.deriv.hRSI);

   DebugInfo("DerivEngine", "Shutdown", StringFormat("lastCycleScore=%d", g_state.deriv.ictScore));
}

#endif // TM_DERIV_ENGINE_MQH
