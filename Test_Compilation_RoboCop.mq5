//+------------------------------------------------------------------+
//|                Test_Compilation_RoboCop.mq5                      |
//|                     Test de compilation only                      |
//+------------------------------------------------------------------+
#property copyright "Test"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\List.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>

// Test des fonctions HistoryOrder avec les bons enums
void TestHistoryOrderFunctions()
{
   ulong orderID = 12345;
   
   // Test avec les bons enums - devrait compiler sans erreur
   string symbol = HistoryOrderGetString(orderID, ORDER_SYMBOL);
   double volume = HistoryOrderGetDouble(orderID, ORDER_VOLUME_INITIAL);
   double price = HistoryOrderGetDouble(orderID, ORDER_PRICE_OPEN);
   double sl = HistoryOrderGetDouble(orderID, ORDER_SL);
   double tp = HistoryOrderGetDouble(orderID, ORDER_TP);
   double profit = HistoryOrderGetDouble(orderID, ORDER_PROFIT);
   double closePrice = HistoryOrderGetDouble(orderID, ORDER_PRICE_CURRENT);
   long magic = HistoryOrderGetInteger(orderID, ORDER_MAGIC);
   long orderType = HistoryOrderGetInteger(orderID, ORDER_TYPE);
   datetime timeOpen = (datetime)HistoryOrderGetInteger(orderID, ORDER_TIME_OPEN);
   datetime timeClose = (datetime)HistoryOrderGetInteger(orderID, ORDER_TIME_CLOSE);
   string comment = HistoryOrderGetString(orderID, ORDER_COMMENT);
   
   // Test des fonctions Position
   if(PositionSelect(_Symbol))
   {
      ulong ticket = PositionGetTicket(0);
      int magicPos = PositionGetInteger(POSITION_MAGIC);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   TestHistoryOrderFunctions();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
}
//+------------------------------------------------------------------+
