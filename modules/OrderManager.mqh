//+------------------------------------------------------------------+
//| OrderManager.mqh - Entry management abstraction                   |
//| All inputs come from main EA — NO input declarations here         |
//+------------------------------------------------------------------+
#ifndef SMC_ORDER_MANAGER_MQH
#define SMC_ORDER_MANAGER_MQH

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//--- Forward declarations (inputs are global from main EA via include order)
// InpMagicNumber is already an input in main EA — no redeclaration needed

CTrade g_orderTrade;
int g_orderDailyTradeCount = 0;
datetime g_orderLastTradeDay = 0;

//+------------------------------------------------------------------+
//| Check daily trade limit                                           |
//+------------------------------------------------------------------+
bool OrderMgr_CheckDailyLimit()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));

   if(today != g_orderLastTradeDay)
   {
      g_orderDailyTradeCount = 0;
      g_orderLastTradeDay = today;
   }

   if(g_orderDailyTradeCount >= MaxDailyTrades)
   {
      static datetime lastLog = 0;
      if(TimeCurrent() - lastLog >= 60)
      {
         lastLog = TimeCurrent();
         Print("[ORDER] Daily limit reached: ", g_orderDailyTradeCount, "/", MaxDailyTrades);
      }
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Check max open positions                                          |
//+------------------------------------------------------------------+
bool OrderMgr_CheckPositionLimit()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) count++;
   }

   if(count >= MaxOpenPositions)
   {
      static datetime lastLog = 0;
      if(TimeCurrent() - lastLog >= 60)
      {
         lastLog = TimeCurrent();
         Print("[ORDER] Position limit reached: ", count, "/", MaxOpenPositions);
      }
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Safe order send with validation                                   |
//+------------------------------------------------------------------+
bool OrderMgr_SendOrder(string symbol, ENUM_ORDER_TYPE type, double volume,
                        double price, double sl, double tp, string comment)
{
   if(!OrderMgr_CheckDailyLimit()) return false;
   if(!OrderMgr_CheckPositionLimit()) return false;

   // Validate volume
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   volume = MathMax(minLot, MathMin(maxLot, volume));
   volume = MathFloor(volume / stepLot) * stepLot;

   if(volume < minLot)
   {
      Print("[ORDER] Volume too small: ", volume, " < ", minLot);
      return false;
   }

   // Normalize prices
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   price = NormalizeDouble(price, digits);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   // Vérifier GOM=WAIT avant d'envoyer l'ordre
   if(g_smcGomVerdictNum == 0)
   {
      Print("[ORDER] ORDRE BLOQUÉ — GOM=WAIT (vn=0) | ", symbol, " ", (type == ORDER_TYPE_BUY ? "BUY" : "SELL"));
      return false;
   }

   // Vérifier que le verdict est GOOD/PERFECT (|vn|>=2)
   if(MathAbs(g_smcGomVerdictNum) < 2)
   {
      Print("[ORDER] ORDRE BLOQUÉ — GOM=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ") — seul GOOD/PERFECT autorisé | ", symbol);
      return false;
   }

   bool result = g_orderTrade.PositionOpen(symbol, type, volume, price, sl, tp, comment);

   if(result)
   {
      g_orderDailyTradeCount++;
      ulong ticket = g_orderTrade.ResultOrder();
      Print(StringFormat("[ORDER] OPENED %s %s %.2f lots at %.5f SL=%.5f TP=%.5f | #%d",
            symbol, (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), volume, price, sl, tp, ticket));
   }
   else
   {
      Print(StringFormat("[ORDER] FAILED %s %s %.2f lots | err=%d",
            symbol, (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), volume, GetLastError()));
   }

   return result;
}

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
void OrderManager_Init()
{
   g_orderDailyTradeCount = 0;
   g_orderLastTradeDay = 0;
   Print("[ORDER] Manager initialized");
}

#endif // SMC_ORDER_MANAGER_MQH
