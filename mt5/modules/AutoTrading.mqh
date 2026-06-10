//+------------------------------------------------------------------+
//| AutoTrading.mqh — Placement automatique + Trailing Stop           |
//| Simplifié pour MQL5 (OrderModify natif, pas de CTrade)            |
//+------------------------------------------------------------------+
#ifndef AUTO_TRADING_MQH
#define AUTO_TRADING_MQH

// ═══════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════

input group "=== AUTO TRADING ==="
input bool   UseAutoTrading        = true;
input double AutoTrailActivateUSD   = 2.0;      // Profit minimum avant trailing
input double AutoTrailLockPct       = 0.30;     // 30% giveback allowed
input int    MaxTrackedPositions    = 10;
input bool   UseAutoReentry         = true;     // Re-entry sur même signal
input bool   UseProtectiveStop      = true;     // SL Protection (ne pas perdre >50%)

// ═══════════════════════════════════════════════════════════════════
// STRUCTURES
// ═══════════════════════════════════════════════════════════════════

struct TradeTracker
{
   ulong ticket;
   double peakProfit;
   datetime lastUpdate;
};

TradeTracker g_trackedTrades[10];
int g_trackedCount = 0;

// ═══════════════════════════════════════════════════════════════════
//| PLACE ORDER AUTOMATIQUEMENT
//+------------------------------------------------------------------+

bool AutoPlaceOrder(string symbol, string direction, double entry, double sl, double tp, double lot)
{
   if(!UseAutoTrading) return false;
   if(lot <= 0) return false;

   MqlTradeRequest request = {};
   MqlTradeResult result = {};

   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = lot;
   request.sl = NormalizeDouble(sl, _Digits);
   request.tp = NormalizeDouble(tp, _Digits);
   request.deviation = 100;
   request.magic = 99999;
   request.comment = "AUTO-TRADE";

   if(direction == "BUY")
   {
      request.type = ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(symbol, SYMBOL_ASK);
   }
   else if(direction == "SELL")
   {
      request.type = ORDER_TYPE_SELL;
      request.price = SymbolInfoDouble(symbol, SYMBOL_BID);
   }
   else
      return false;

   OrderSend(&request, &result);

   if(result.retcode == TRADE_RETCODE_DONE)
   {
      Print("AUTO-", direction, ": ", symbol, " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits));
      return true;
   }
   else
   {
      Print("FAIL: ", result.retcode);
      return false;
   }
}

// ═══════════════════════════════════════════════════════════════════
//| MANAGE AUTO TRAILING STOP
//+------------------------------------------------------------------+

void AutoManageTrailingStop()
{
   if(!UseAutoTrading) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i)))
         continue;

      ulong ticket = PositionGetTicket(i);
      string symbol = PositionGetString(POSITION_SYMBOL);
      int type = (int)PositionGetInteger(POSITION_TYPE);
      double posOpen = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      double profit = PositionGetDouble(POSITION_PROFIT);

      // Track peak profit
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double currentPrice = (type == 0) ? bid : ask;

      // Find or create tracker for this ticket
      int trackIdx = -1;
      for(int j = 0; j < g_trackedCount; j++)
      {
         if(g_trackedTrades[j].ticket == ticket)
         {
            trackIdx = j;
            break;
         }
      }

      double peakProfit = 0.0;
      if(trackIdx >= 0)
         peakProfit = g_trackedTrades[trackIdx].peakProfit;

      // Update peak profit
      if(peakProfit == 0.0 || profit > peakProfit)
      {
         if(trackIdx < 0 && g_trackedCount < MaxTrackedPositions)
         {
            trackIdx = g_trackedCount;
            g_trackedTrades[trackIdx].ticket = ticket;
            g_trackedCount++;
         }
         if(trackIdx >= 0)
         {
            g_trackedTrades[trackIdx].peakProfit = profit;
            g_trackedTrades[trackIdx].lastUpdate = TimeCurrent();
            peakProfit = profit;
         }
      }

      // ═══════════════════════════════════════════════════════════
      // PROTECTIVE STOP: Prevent loss >50% of peak profit
      // ═══════════════════════════════════════════════════════════
      if(UseProtectiveStop && peakProfit >= AutoTrailActivateUSD)
      {
         double maxAllowedLoss = peakProfit * 0.5;
         double currentLoss = profit - peakProfit;

         if(currentLoss < -maxAllowedLoss)
         {
            // Close position
            MqlTradeRequest close_req = {};
            MqlTradeResult close_res = {};
            close_req.action = TRADE_ACTION_DEAL;
            close_req.position = ticket;
            close_req.symbol = symbol;
            close_req.volume = PositionGetDouble(POSITION_VOLUME);
            close_req.type = (type == 0) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            close_req.price = (type == 0) ? bid : ask;
            close_req.deviation = 100;
            close_req.comment = "PROTECTIVE-STOP";

            OrderSend(&close_req, &close_res);

            Print("PROTECTIVE STOP: ", symbol, " | Peak: ", DoubleToString(peakProfit, 2), "$ | Loss: ", DoubleToString(profit, 2), "$");

            if(UseAutoReentry)
               Print("RE-ENTRY signal for ", symbol);

            continue;
         }
      }

      // ═══════════════════════════════════════════════════════════
      // TRAILING STOP: Activate at 2$ profit
      // ═══════════════════════════════════════════════════════════
      if(profit >= AutoTrailActivateUSD)
      {
         double lockMin = peakProfit * (1.0 - AutoTrailLockPct);
         if(lockMin < 0.1) lockMin = 0.1;

         double newSL = 0.0;
         if(type == 0) // BUY
         {
            double givebackDist = (peakProfit * AutoTrailLockPct) / bid;
            newSL = bid - givebackDist;
            newSL = MathMax(newSL, posOpen);
         }
         else // SELL
         {
            double givebackDist = (peakProfit * AutoTrailLockPct) / ask;
            newSL = ask + givebackDist;
            newSL = MathMin(newSL, posOpen);
         }

         // Update SL if more profitable
         if((type == 0 && newSL > sl) || (type == 1 && newSL < sl))
         {
            MqlTradeRequest modify_req = {};
            MqlTradeResult modify_res = {};
            modify_req.action = TRADE_ACTION_SLTP;
            modify_req.position = ticket;
            modify_req.sl = NormalizeDouble(newSL, _Digits);
            modify_req.tp = NormalizeDouble(tp, _Digits);

            if(OrderSend(&modify_req, &modify_res))
            {
               Print("TRAILING: ", symbol, " | SL: ", DoubleToString(newSL, _Digits), " | Peak: ", DoubleToString(peakProfit, 2), "$");
            }
         }
      }
   }

   // Cleanup closed positions
   for(int i = 0; i < g_trackedCount; i++)
   {
      if(!PositionSelectByTicket(g_trackedTrades[i].ticket))
      {
         for(int j = i; j < g_trackedCount - 1; j++)
            g_trackedTrades[j] = g_trackedTrades[j + 1];
         g_trackedCount--;
         i--;
      }
   }
}

// ═══════════════════════════════════════════════════════════════════
//| AUTO TRADING LOOP (call from OnTick)
//+--================================================================+

void AutoTradingTick()
{
   if(!UseAutoTrading) return;
   AutoManageTrailingStop();
}

#endif
