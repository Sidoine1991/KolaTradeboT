// Simple compilation test for RoboCop_v2_final.mq5
// This file checks for basic syntax errors

#include <Trade\Trade.mqh>
#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\List.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>

// Test enum usage
void TestEnumUsage()
{
    ulong orderID = 12345;
    
    // Test correct enum usage
    string symbol = HistoryOrderGetString(orderID, ORDER_SYMBOL);
    double volume = HistoryOrderGetDouble(orderID, ORDER_VOLUME_INITIAL);
    double price = HistoryOrderGetDouble(orderID, ORDER_PRICE_OPEN);
    double sl = HistoryOrderGetDouble(orderID, ORDER_SL);
    double tp = HistoryOrderGetDouble(orderID, ORDER_TP);
    double profit = HistoryOrderGetDouble(orderID, ORDER_PROFIT);
    long magic = HistoryOrderGetInteger(orderID, ORDER_MAGIC);
    long orderType = HistoryOrderGetInteger(orderID, ORDER_TYPE);
    datetime timeOpen = (datetime)HistoryOrderGetInteger(orderID, ORDER_TIME_OPEN);
    datetime timeClose = (datetime)HistoryOrderGetInteger(orderID, ORDER_TIME_CLOSE);
    string comment = HistoryOrderGetString(orderID, ORDER_COMMENT);
    
    // Test position functions
    if(PositionSelect(_Symbol))
    {
        ulong ticket = PositionGetTicket(0);
        int magicPos = PositionGetInteger(POSITION_MAGIC);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    }
}

//+------------------------------------------------------------------+
