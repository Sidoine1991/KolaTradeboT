//+------------------------------------------------------------------+
//|                                                EA_Diagnostic.mq5 |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Diagnostic"
#property link      ""
#property version   "1.00"
#property strict

input bool PlaceTestOrder = false;
input double TestLotSize = 0.01;
input string TestSymbol = "XAUUSD";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== EA DIAGNOSTIC START ===");
   Print("Terminal: ", TerminalInfoString(TERMINAL_COMPANY));
   Print("Account: ", AccountInfoInteger(ACCOUNT_LOGIN));
   Print("Server: ", AccountInfoString(ACCOUNT_SERVER));
   Print("Balance: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2));
   Print("Equity: ", DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2));
   Print("Margin Free: ", DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2));
   Print("Trade Allowed: ", TerminalInfoInteger(TERMINAL_TRADE_ALLOWED));
   Print("Connected: ", TerminalInfoInteger(TERMINAL_CONNECTED));
   
   if(PlaceTestOrder)
   {
      Print("=== PLACING TEST ORDER ===");
      PlaceTestBuyOrder();
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== EA DIAGNOSTIC STOP ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastCheck = 0;
   if(TimeCurrent() - lastCheck < 10) return;
   lastCheck = TimeCurrent();
   
   Print("Tick - Bid: ", SymbolInfoDouble(_Symbol, SYMBOL_BID), 
         " Ask: ", SymbolInfoDouble(_Symbol, SYMBOL_ASK));
}

//+------------------------------------------------------------------+
//| Place test buy order                                             |
//+------------------------------------------------------------------+
void PlaceTestBuyOrder()
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = TestSymbol;
   request.volume = TestLotSize;
   request.type = ORDER_TYPE_BUY;
   request.price = SymbolInfoDouble(TestSymbol, SYMBOL_ASK);
   request.sl = 0;
   request.tp = 0;
   request.deviation = 10;
   request.magic = 999999;
   request.comment = "DIAGNOSTIC TEST";
   
   bool success = OrderSend(request, result);
   
   if(success)
   {
      Print("✅ TEST ORDER SUCCESS - Ticket: ", result.order);
   }
   else
   {
      int error = GetLastError();
      Print("❌ TEST ORDER FAILED");
      Print("Error code: ", error);
      Print("Retcode: ", result.retcode);
      Print("Comment: ", result.comment);
      
      // Detailed error info
      switch(error)
      {
         case 4756: Print("Error: Trade request failed"); break;
         case 10004: Print("Error: Requote"); break;
         case 10006: Print("Error: Request rejected"); break;
         case 10007: Print("Error: Order cancelled by trader"); break;
         case 10010: Print("Error: Only partial execution"); break;
         case 10011: Print("Error: Trade error"); break;
         case 10012: Print("Error: Request timeout"); break;
         case 10013: Print("Error: Invalid request"); break;
         case 10014: Print("Error: Invalid volume"); break;
         case 10015: Print("Error: Invalid price"); break;
         case 10016: Print("Error: Invalid stops"); break;
         case 10017: Print("Error: Trade disabled"); break;
         case 10018: Print("Error: Market closed"); break;
         case 10019: Print("Error: Insufficient funds"); break;
         case 10020: Print("Error: Prices changed"); break;
         case 10021: Print("Error: No quotes"); break;
         case 10022: Print("Error: Invalid expiration"); break;
         case 10023: Print("Error: Order state changed"); break;
         case 10024: Print("Error: Too many requests"); break;
         case 10025: Print("Error: No changes"); break;
         case 10026: Print("Error: Autotrading disabled"); break;
         case 10027: Print("Error: Autotrading disabled by client"); break;
         case 10028: Print("Error: Request blocked"); break;
         case 10029: Print("Error: Connection lost"); break;
         case 10030: Print("Error: Only for real accounts"); break;
         case 10031: Print("Error: Position limit reached"); break;
         case 10032: Print("Error: Pending order limit reached"); break;
         case 10033: Print("Error: Volume limit reached"); break;
         case 10034: Print("Error: Prohibition"); break;
         case 10035: Print("Error: Connection rejected"); break;
         case 10036: Print("Error: Only for demo accounts"); break;
         case 10038: Print("Error: Order filled"); break;
         case 10039: Print("Error: Order not found"); break;
         case 10040: Print("Error: Order already exists"); break;
         case 10041: Print("Error: Order executed"); break;
         case 10042: Print("Error: Order expired"); break;
         case 10043: Print("Error: Order cancelled"); break;
         case 10044: Print("Error: Order rejected"); break;
         case 10045: Print("Error: Order cancelled by client"); break;
         case 10046: Print("Error: Order rejected by broker"); break;
         case 10047: Print("Error: Order rejected by broker"); break;
         default: Print("Error: Unknown error"); break;
      }
   }
}
//+------------------------------------------------------------------+
