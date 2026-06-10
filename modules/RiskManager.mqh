//+------------------------------------------------------------------+
//| RiskManager.mqh — Capital management, lot sizing, daily limits   |
//+------------------------------------------------------------------+
#ifndef TM_RISK_MANAGER_MQH
#define TM_RISK_MANAGER_MQH

#include "TMState.mqh"
#include "TMDebug.mqh"
#include "TMEvents.mqh"
#include "Notifications.mqh"

// ═══════════════════════════════════════════════════════════════════
// DAILY STATS INITIALIZATION
// ═══════════════════════════════════════════════════════════════════

void Risk_ResetDailyStats()
{
   datetime today = TimeCurrent();
   if(g_state.discipline.dailyResetDate == today)
      return;  // Already reset today

   g_state.discipline.dailyResetDate = today;
   g_state.discipline.dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_state.discipline.dailyTradeCount = 0;
   g_state.discipline.dailyTargetHit = false;
   g_state.discipline.totalWins = 0;
   g_state.discipline.totalLosses = 0;
   g_state.discipline.totalProfitWins = 0.0;
   g_state.discipline.totalLossAmount = 0.0;

   DebugInfo("RiskManager", "Daily stats reset", StringFormat("balance=%.2f", g_state.discipline.dailyStartBalance));
}

// ═══════════════════════════════════════════════════════════════════
// DAILY PROFIT/LOSS TRACKING (scans closed deals)
// ═══════════════════════════════════════════════════════════════════

double Risk_CalcDailyClosedProfit()
{
   double profit = 0.0;
   datetime today = TimeCurrent();

   if(!HistorySelect(today, TimeCurrent() + 86400))  // Select today + 1 day
   {
      DebugWarn("RiskManager", "HistorySelect failed");
      return 0.0;
   }

   int dealsCount = HistoryDealsTotal();
   for(int i = 0; i < dealsCount; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;  // Only count closed deals

      double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      profit += dealProfit;
   }

   return profit;
}

void Risk_UpdateDailyStats()
{
   double dailyProfit = Risk_CalcDailyClosedProfit();

   // Count wins/losses from today's closed deals
   datetime today = TimeCurrent();
   if(!HistorySelect(today, TimeCurrent() + 86400))
      return;

   int winCount = 0, lossCount = 0;
   double winProfit = 0.0, lossAmount = 0.0;

   int dealsCount = HistoryDealsTotal();
   for(int i = 0; i < dealsCount; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;

      double dealProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      if(dealProfit > 0.01)
      {
         winCount++;
         winProfit += dealProfit;
      }
      else if(dealProfit < -0.01)
      {
         lossCount++;
         lossAmount += MathAbs(dealProfit);
      }
   }

   g_state.discipline.totalWins = winCount;
   g_state.discipline.totalLosses = lossCount;
   g_state.discipline.totalProfitWins = winProfit;
   g_state.discipline.totalLossAmount = lossAmount;
}

// ═══════════════════════════════════════════════════════════════════
// DAILY TARGET CHECK
// ═══════════════════════════════════════════════════════════════════

void Risk_CheckDailyTarget()
{
   if(!g_state.config.useCapitalManager)
      return;

   Risk_UpdateDailyStats();

   double dailyProfit = g_state.discipline.totalProfitWins - g_state.discipline.totalLossAmount;
   double targetProfit = g_state.discipline.dailyProfitTarget;

   if(dailyProfit >= targetProfit)
   {
      if(!g_state.discipline.dailyTargetHit)
      {
         g_state.discipline.dailyTargetHit = true;
         DebugInfo("RiskManager", "Daily profit target HIT", StringFormat("profit=%.2f >= target=%.2f",
                   dailyProfit, targetProfit));
         SendWAAlert("Daily Target", StringFormat("Profit goal reached: %.2f$ (target %.2f$)", dailyProfit, targetProfit));
         Event_DailyTargetHit(dailyProfit);
      }
   }
   else
   {
      if(g_state.discipline.dailyTargetHit)
         g_state.discipline.dailyTargetHit = false;
   }
}

// ═══════════════════════════════════════════════════════════════════
// LOT SIZING (adaptive based on capital + risk %)
// ═══════════════════════════════════════════════════════════════════

double Risk_CalcLotSize(double sl, double tp, const string symbol)
{
   if(!g_state.config.useCapitalManager)
   {
      return 0.01;  // Default lot
   }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance < g_state.config.cm_minCapitalToTrade)
   {
      DebugWarn("RiskManager", "Insufficient capital", StringFormat("%.2f < %.2f", balance,
                g_state.config.cm_minCapitalToTrade));
      return 0.0;  // Cannot trade
   }

   // Risk = capital * riskPct%
   double riskUSD = balance * (g_state.config.cm_lotRiskPct / 100.0);

   // Get pip value for symbol
   double pipValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(pipValue == 0.0) pipValue = 1.0;  // Fallback

   // SL distance in pips
   double slDistance = MathAbs(tp - sl);
   if(slDistance < 0.0001)
      return 0.01;  // Invalid SL/TP

   // Lot = risk / (slDistance * pipValue)
   double lot = riskUSD / (slDistance * pipValue);

   // Clamp to reasonable bounds
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;

   // Round to step
   lot = MathRound(lot / step) * step;

   DebugDetail("RiskManager", "Lot size calculated", StringFormat("%s lot=%.2f risk=%.2f slDist=%.5f",
              symbol, lot, riskUSD, slDistance));

   return lot;
}

// ═══════════════════════════════════════════════════════════════════
// POSITION COUNT TRACKING
// ═══════════════════════════════════════════════════════════════════

int Risk_CountOpenPositions()
{
   return PositionsTotal();
}

int Risk_CountOpenPositionsBySymbol(const string symbol)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == symbol)
         count++;
   }
   return count;
}

bool Risk_CanOpenPosition()
{
   return Risk_CountOpenPositions() < g_state.config.maxGlobalPositions;
}

bool Risk_CanOpenPositionOnSymbol(const string symbol)
{
   return Risk_CountOpenPositionsBySymbol(symbol) < g_state.config.maxPositionsPerSymbol;
}

// ═══════════════════════════════════════════════════════════════════
// TRADE INCREMENT (called when new trade opens)
// ═══════════════════════════════════════════════════════════════════

void Risk_OnTradeOpened(ulong ticket, const string symbol, double lot)
{
   g_state.discipline.dailyTradeCount++;
   DebugDetail("RiskManager", "Trade opened", StringFormat("%s %d/%d",
              symbol, g_state.discipline.dailyTradeCount, g_state.discipline.maxDailyTrades));
}

// ═══════════════════════════════════════════════════════════════════
// MODULE LIFECYCLE
// ═══════════════════════════════════════════════════════════════════

void Risk_Init()
{
   Risk_ResetDailyStats();
   DebugInfo("RiskManager", "Initialized", StringFormat("CM enabled=%d, maxTrades=%d, dailyTarget=%.2f",
            g_state.config.useCapitalManager ? 1 : 0, g_state.discipline.maxDailyTrades,
            g_state.config.cm_dailyTargetPct));
}

void Risk_Tick()
{
   // Periodic checks
   Risk_ResetDailyStats();
   Risk_CheckDailyTarget();
}

void Risk_Deinit()
{
   DebugInfo("RiskManager", "Shutdown", StringFormat("daily: %d wins, %d losses, profit=%.2f",
            g_state.discipline.totalWins, g_state.discipline.totalLosses,
            g_state.discipline.totalProfitWins - g_state.discipline.totalLossAmount));
}

#endif // TM_RISK_MANAGER_MQH
