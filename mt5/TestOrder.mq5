//+------------------------------------------------------------------+
//|                                                   TestOrder.mq5 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Test"
#property link      ""
#property version   "1.00"
#property script_show_inputs

input double LotSize = 0.01;
input string SymbolToTrade = "XAUUSD";

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("=== TEST ORDER SCRIPT START ===");
   Print("Symbol: ", SymbolToTrade);
   Print("Lot: ", LotSize);
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = SymbolToTrade;
   request.volume = LotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = SymbolInfoDouble(SymbolToTrade, SYMBOL_ASK);
   request.sl = 0;
   request.tp = 0;
   request.deviation = 10;
   request.magic = 123456;
   request.comment = "TEST ORDER";
   
   bool success = OrderSend(request, result);
   
   if(success)
   {
      Print("✅ ORDRE RÉUSSI - Ticket: ", result.order);
   }
   else
   {
      Print("❌ ORDRE ÉCHOUÉ - Erreur: ", GetLastError());
      Print("Retcode: ", result.retcode);
      Print("Comment: ", result.comment);
   }
   
   Print("=== TEST ORDER SCRIPT END ===");
}
//+------------------------------------------------------------------+
