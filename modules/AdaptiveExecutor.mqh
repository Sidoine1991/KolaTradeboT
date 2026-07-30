//+------------------------------------------------------------------+
//| AdaptiveExecutor.mqh — LIMIT/MARKET adaptive execution           |
//| Decide whether to place LIMIT (DOW trendline) or MARKET (urgent) |
//| Calcul du lot sizing pour SL=$3 max, TP=$1 target.               |
//+------------------------------------------------------------------+
#ifndef TM_ADAPTIVE_EXECUTOR_MQH
#define TM_ADAPTIVE_EXECUTOR_MQH

#include "TMState.mqh"
#include "TMDebug.mqh"
#include "Notifications.mqh"

// ═══════════════════════════════════════════════════════════════════
// TRADE EXECUTION TRACKING
// ═══════════════════════════════════════════════════════════════════

struct AdaptiveTradeRecord
{
   string   symbol;
   ulong    ticket;
   int      direction;
   double   entryPrice;
   double   sl;
   double   tp;
   double   lot;
   string   mode;        // "LIMIT" or "MARKET"
   datetime openedAt;
   bool     active;
};

AdaptiveTradeRecord g_adaptiveTrades[];
int                 g_adaptiveTradeCount = 0;
datetime            g_lastAdaptiveTradeTime = 0;

// ═══════════════════════════════════════════════════════════════════
// INITIALIZATION
// ═══════════════════════════════════════════════════════════════════

void ADAPTIVE_Init()
{
   g_adaptiveTradeCount = 0;
   ArrayResize(g_adaptiveTrades, 0);
   g_lastAdaptiveTradeTime = 0;
   DebugInfo("AdaptiveExecutor", "Initialized",
             StringFormat("MaxLoss=$%.1f TP=$%.1f MaxPos=%d",
                         g_state.config.maxLossUSD,
                         g_state.config.targetProfitUSD,
                         g_state.config.maxOpenPositions));
}

// ═══════════════════════════════════════════════════════════════════
// LOT SIZING: Ensure SL loss never exceeds MaxLossUSD ($3)
// ═══════════════════════════════════════════════════════════════════

double ADAPTIVE_CalcLotSize(const string symbol, double slDistancePoints)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = minLot;
   if(slDistancePoints <= 0) return minLot;

   double tickVal = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(tickVal <= 0 || tickSize <= 0 || point <= 0) return minLot;

   // Value of 1 point for 1 lot
   double pointValuePerLot = (tickVal / tickSize) * point;
   if(pointValuePerLot <= 0) return minLot;

   // Lot = maxLoss / (slDistance × pointValuePerLot)
   double lot = g_state.config.maxLossUSD / (slDistancePoints * pointValuePerLot);
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathRound(lot / lotStep) * lotStep;

   // Additional safety: never risk more than 20% of balance
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxLotByBalance = balance / 10.0;
   lot = MathMin(lot, maxLotByBalance);

   return NormalizeDouble(lot, 2);
}

// ═══════════════════════════════════════════════════════════════════
// CALCULATE SL/TP for a trade
// ═══════════════════════════════════════════════════════════════════

void ADAPTIVE_CalcSLTP(const string symbol, int direction, double entry,
                        double atr, double &outSL, double &outTP)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double maxLoss = g_state.config.maxLossUSD;
   double targetProfit = g_state.config.targetProfitUSD;

   // Calculate SL distance in price to ensure max loss = $3
   // We need to find the SL distance that results in exactly $3 loss
   double tickVal = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickVal <= 0 || tickSize <= 0)
   {
      // Fallback: use ATR-based SL
      if(direction > 0)
      {
         outSL = NormalizeDouble(entry - atr * 1.5, digits);
         outTP = NormalizeDouble(entry + atr * 1.0, digits);
      }
      else
      {
         outSL = NormalizeDouble(entry + atr * 1.5, digits);
         outTP = NormalizeDouble(entry - atr * 1.0, digits);
      }
      return;
   }

   // Price per tick for 1 lot
   double tickPrice = tickVal; // $ per tick for 1 lot

   // SL distance in ticks for $3 loss
   double slTicks = maxLoss / tickPrice;
   double slDistance = slTicks * tickSize;

   // TP distance in ticks for $1 profit
   double tpTicks = targetProfit / tickPrice;
   double tpDistance = tpTicks * tickSize;

   // Apply minimum: SL must be at least 1 ATR away
   double minSLDist = atr * 0.5;
   slDistance = MathMax(slDistance, minSLDist);
   tpDistance = MathMax(tpDistance, atr * 0.3);

   if(direction > 0)
   {
      outSL = NormalizeDouble(entry - slDistance, digits);
      outTP = NormalizeDouble(entry + tpDistance, digits);
   }
   else
   {
      outSL = NormalizeDouble(entry + slDistance, digits);
      outTP = NormalizeDouble(entry - tpDistance, digits);
   }
}

// ═══════════════════════════════════════════════════════════════════
// CAN EXECUTE? (global limits check)
// ═══════════════════════════════════════════════════════════════════

bool ADAPTIVE_CanExecute(const TMScannerOpportunity &opp)
{
   // 1. Max open positions check
   int openCount = PositionsTotal();
   if(openCount >= g_state.config.maxOpenPositions)
   {
      DebugWarn("AdaptiveExecutor", "Max positions reached",
                StringFormat("open=%d max=%d", openCount, g_state.config.maxOpenPositions));
      return false;
   }

   // 2. Max positions per symbol
   int symCount = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == opp.symbol)
         symCount++;
   }
   if(symCount >= g_state.config.maxPositionsPerSymbol)
   {
      DebugWarn("AdaptiveExecutor", "Max positions per symbol reached",
                StringFormat("sym=%s count=%d max=%d", opp.symbol, symCount, g_state.config.maxPositionsPerSymbol));
      return false;
   }

   // 3. Cooldown between trades (min 3 seconds)
   if(TimeCurrent() - g_lastAdaptiveTradeTime < 3)
      return false;

   // 4. Daily limit check
   if(g_state.discipline.dailyTargetHit)
   {
      DebugWarn("AdaptiveExecutor", "Daily target hit, no more trades");
      return false;
   }

   // 5. Cooldown after loss
   if(g_state.discipline.consecutiveLosses >= 2)
   {
      // Already managed by existing loss cooldown
   }

   // 6. Duplicate check (no double trade on same symbol)
   for(int i = 0; i < g_adaptiveTradeCount; i++)
   {
      if(g_adaptiveTrades[i].active && g_adaptiveTrades[i].symbol == opp.symbol)
      {
         DebugWarn("AdaptiveExecutor", "Already active on symbol",
                   StringFormat("sym=%s ticket=#%llu", opp.symbol, g_adaptiveTrades[i].ticket));
         return false;
      }
   }

   return true;
}

// ═══════════════════════════════════════════════════════════════════
// EXECUTE LIMIT ORDER (DOW trendline touch)
// ═══════════════════════════════════════════════════════════════════

bool ADAPTIVE_ExecuteLimit(const TMScannerOpportunity &opp)
{
   double bid = SymbolInfoDouble(opp.symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(opp.symbol, SYMBOL_ASK);
   int digits = (int)SymbolInfoInteger(opp.symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(opp.symbol, SYMBOL_POINT);

   // Get ATR for SL/TP calculation
   ScannerSymbolData *sd = DOWSCAN_GetOrCreateData(opp.symbol);
   double atr = sd->lastATR_M1;
   if(atr <= 0)
   {
      // Fallback ATR
      int h = iATR(opp.symbol, PERIOD_M1, 14);
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(h, 0, 0, 1, buf) > 0) atr = buf[0];
      IndicatorRelease(h);
      if(atr <= 0) return false;
   }

   // Determine entry price (at DOW trendline level)
   double entry = 0;
   MqlRates rates[];
   if(CopyRates(opp.symbol, PERIOD_M1, 0, 10, rates) >= 10)
   {
      if(opp.direction > 0)
         entry = rates[1].low; // BUY at swing low
      else
         entry = rates[1].high; // SELL at swing high
   }

   if(entry <= 0) return false;

   // Normalize entry to valid price
   double curAsk = SymbolInfoDouble(opp.symbol, SYMBOL_ASK);
   double curBid = SymbolInfoDouble(opp.symbol, SYMBOL_BID);

   // Validate limit price relative to current market
   if(opp.direction > 0 && entry >= curAsk)
      entry = curAsk - point * 10; // BUY limit must be below Ask
   if(opp.direction < 0 && entry <= curBid)
      entry = curBid + point * 10; // SELL limit must be above Bid

   // Calculate SL/TP
   double sl, tp;
   ADAPTIVE_CalcSLTP(opp.symbol, opp.direction, entry, atr, sl, tp);

   // Calculate lot
   double slDistPts = MathAbs(entry - sl) / point;
   double lot = ADAPTIVE_CalcLotSize(opp.symbol, slDistPts);
   if(lot <= 0) return false;

   // Build order request
   MqlTradeRequest req = {};
   MqlTradeResult res = {};
   req.action = TRADE_ACTION_PENDING;
   req.symbol = opp.symbol;
   req.volume = lot;
   req.type = (opp.direction > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   req.price = NormalizeDouble(entry, digits);
   req.sl = NormalizeDouble(sl, digits);
   req.tp = NormalizeDouble(tp, digits);
   req.magic = 20260725; // DOW Scanner magic
   req.deviation = 50;
   req.comment = "DOW SCALP";

   if(!SafeOrderSend(req, res))
   {
      DebugWarn("AdaptiveExecutor", "LIMIT order failed",
                StringFormat("sym=%s rc=%d err=%s", opp.symbol, res.retcode, res.comment));
      return false;
   }

   // Track
   int idx = g_adaptiveTradeCount;
   ArrayResize(g_adaptiveTrades, idx + 1);
   g_adaptiveTrades[idx].symbol = opp.symbol;
   g_adaptiveTrades[idx].ticket = res.order;
   g_adaptiveTrades[idx].direction = opp.direction;
   g_adaptiveTrades[idx].entryPrice = entry;
   g_adaptiveTrades[idx].sl = sl;
   g_adaptiveTrades[idx].tp = tp;
   g_adaptiveTrades[idx].lot = lot;
   g_adaptiveTrades[idx].mode = "LIMIT";
   g_adaptiveTrades[idx].openedAt = TimeCurrent();
   g_adaptiveTrades[idx].active = true;
   g_adaptiveTradeCount++;
   g_lastAdaptiveTradeTime = TimeCurrent();

   string dir = (opp.direction > 0) ? "BUY" : "SELL";
   string msg = StringFormat("LIMIT %s %s\nEntry: %.5f SL: %.5f TP: %.5f\nLot: %.2f (SL=$%.1f)",
                            dir, opp.symbol, entry, sl, tp, lot, g_state.config.maxLossUSD);
   DebugInfo("AdaptiveExecutor", "LIMIT placed", msg);

   // WhatsApp notification
   if(g_state.config.useWhatsApp2)
   {
      string waMsg = StringFormat("DOW LIMIT %s %s\nEntry: %.5f\nSL: %.5f ($%.1f)\nTP: %.5f ($%.1f)\nLot: %.2f",
                                 dir, opp.symbol, entry, sl, g_state.config.maxLossUSD,
                                 tp, g_state.config.targetProfitUSD, lot);
      SendNotification(waMsg);
   }

   return true;
}

// ═══════════════════════════════════════════════════════════════════
// EXECUTE MARKET ORDER (urgent signal)
// ═══════════════════════════════════════════════════════════════════

bool ADAPTIVE_ExecuteMarket(const TMScannerOpportunity &opp)
{
   double ask = SymbolInfoDouble(opp.symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(opp.symbol, SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(opp.symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(opp.symbol, SYMBOL_POINT);

   // Get ATR for SL/TP calculation
   ScannerSymbolData *sd = DOWSCAN_GetOrCreateData(opp.symbol);
   double atr = sd->lastATR_M1;
   if(atr <= 0)
   {
      int h = iATR(opp.symbol, PERIOD_M1, 14);
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(h, 0, 0, 1, buf) > 0) atr = buf[0];
      IndicatorRelease(h);
      if(atr <= 0) return false;
   }

   // Entry = current market price
   double entry = (opp.direction > 0) ? ask : bid;

   // Calculate SL/TP
   double sl, tp;
   ADAPTIVE_CalcSLTP(opp.symbol, opp.direction, entry, atr, sl, tp);

   // Calculate lot
   double slDistPts = MathAbs(entry - sl) / point;
   double lot = ADAPTIVE_CalcLotSize(opp.symbol, slDistPts);
   if(lot <= 0) return false;

   // Build order request
   MqlTradeRequest req = {};
   MqlTradeResult res = {};
   req.action = TRADE_ACTION_DEAL;
   req.symbol = opp.symbol;
   req.volume = lot;
   req.type = (opp.direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   req.price = (opp.direction > 0) ? ask : bid;
   req.sl = NormalizeDouble(sl, digits);
   req.tp = NormalizeDouble(tp, digits);
   req.magic = 20260725;
   req.deviation = 50;
   req.comment = "DOW SCALP";

   if(!SafeOrderSend(req, res))
   {
      DebugWarn("AdaptiveExecutor", "MARKET order failed",
                StringFormat("sym=%s rc=%d err=%s", opp.symbol, res.retcode, res.comment));
      return false;
   }

   // Track
   int idx = g_adaptiveTradeCount;
   ArrayResize(g_adaptiveTrades, idx + 1);
   g_adaptiveTrades[idx].symbol = opp.symbol;
   g_adaptiveTrades[idx].ticket = res.deal;
   g_adaptiveTrades[idx].direction = opp.direction;
   g_adaptiveTrades[idx].entryPrice = entry;
   g_adaptiveTrades[idx].sl = sl;
   g_adaptiveTrades[idx].tp = tp;
   g_adaptiveTrades[idx].lot = lot;
   g_adaptiveTrades[idx].mode = "MARKET";
   g_adaptiveTrades[idx].openedAt = TimeCurrent();
   g_adaptiveTrades[idx].active = true;
   g_adaptiveTradeCount++;
   g_lastAdaptiveTradeTime = TimeCurrent();

   string dir = (opp.direction > 0) ? "BUY" : "SELL";
   string msg = StringFormat("MARKET %s %s\nEntry: %.5f SL: %.5f TP: %.5f\nLot: %.2f (SL=$%.1f)",
                            dir, opp.symbol, entry, sl, tp, lot, g_state.config.maxLossUSD);
   DebugInfo("AdaptiveExecutor", "MARKET executed", msg);

   if(g_state.config.useWhatsApp2)
   {
      string waMsg = StringFormat("DOW MARKET %s %s\nEntry: %.5f\nSL: %.5f ($%.1f)\nTP: %.5f ($%.1f)\nLot: %.2f",
                                 dir, opp.symbol, entry, sl, g_state.config.maxLossUSD,
                                 tp, g_state.config.targetProfitUSD, lot);
      SendNotification(waMsg);
   }

   return true;
}

// ═══════════════════════════════════════════════════════════════════
// MANAGE PENDING LIMIT ORDERS (chase, cancel)
// ═══════════════════════════════════════════════════════════════════

void ADAPTIVE_ManagePendingOrders()
{
   // Iterate through orders in queue
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;

      string comment = OrderGetString(ORDER_COMMENT);
      if(StringFind(comment, "DOW SCALP") < 0) continue;

      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double orderSL = OrderGetDouble(ORDER_SL);
      double orderTP = OrderGetDouble(ORDER_TP);
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      string symbol = OrderGetString(ORDER_SYMBOL);

      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);

      // Check if order is stale (older than 60 seconds without fill)
      datetime placed = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(TimeCurrent() - placed > 60)
      {
         // Cancel stale order
         MqlTradeRequest req = {};
         MqlTradeResult res = {};
         req.action = TRADE_ACTION_REMOVE;
         req.order = ticket;

         if(SafeOrderSend(req, res))
         {
            DebugInfo("AdaptiveExecutor", "Stale LIMIT cancelled",
                      StringFormat("sym=%s ticket=#%llu age=%ds",
                                  symbol, ticket, (int)(TimeCurrent() - placed)));
         }
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
// CLEANUP
// ═══════════════════════════════════════════════════════════════════

void ADAPTIVE_Cleanup()
{
   // Mark inactive trades
   for(int i = 0; i < g_adaptiveTradeCount; i++)
   {
      if(!g_adaptiveTrades[i].active) continue;

      // Check if position still exists
      bool found = false;
      for(int j = 0; j < PositionsTotal(); j++)
      {
         ulong ticket = PositionGetTicket(j);
         if(ticket == g_adaptiveTrades[i].ticket)
         {
            found = true;
            break;
         }
      }
      if(!found) g_adaptiveTrades[i].active = false;
   }
}

#endif // TM_ADAPTIVE_EXECUTOR_MQH

