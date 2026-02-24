//+------------------------------------------------------------------+
//| Market Hours Fix for Synthetic Indices                          |
//| Fixes false "Market Closed" detection for Boom/Crash/Volatility |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, TradBOT"
#property link      ""
#property version   "1.00"

//+------------------------------------------------------------------+
//| Validate if market is actually open for synthetic indices        |
//+------------------------------------------------------------------+
bool IsMarketActuallyOpen()
{
   // For synthetic indices (Boom, Crash, Volatility, Step), market is 24/7
   string symbol = _Symbol;
   
   // Check if it's a synthetic index
   if(StringFind(symbol, "Boom") != -1 || 
      StringFind(symbol, "Crash") != -1 || 
      StringFind(symbol, "Volatility") != -1 || 
      StringFind(symbol, "Step") != -1)
   {
      // Synthetic indices trade 24/7 - always return true
      return true;
   }
   
   // For other symbols, check normal market hours
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Weekend check (Saturday/Sunday)
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   
   // Forex market hours (approximate)
   // Sunday 22:00 UTC to Friday 22:00 UTC
   if(dt.day_of_week == 5 && dt.hour >= 22)
      return false;
   
   // Market is open
   return true;
}

//+------------------------------------------------------------------+
//| Enhanced tick validation that bypasses false market closed       |
//+------------------------------------------------------------------+
bool ValidateTickProcessing()
{
   // Always allow processing for synthetic indices
   if(!IsMarketActuallyOpen())
   {
      // Only log if not a synthetic index (to avoid spam)
      if(StringFind(_Symbol, "Boom") == -1 && 
         StringFind(_Symbol, "Crash") == -1 && 
         StringFind(_Symbol, "Volatility") == -1 && 
         StringFind(_Symbol, "Step") == -1)
      {
         Print("INFO: Marché fermé - tick ignoré pour ", _Symbol);
      }
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Function to add to OnTick() to replace market closed logic       |
//+------------------------------------------------------------------+
void OnTickMarketFix()
{
   // Replace any existing market closed checks with this
   if(!ValidateTickProcessing())
      return;
   
   // Continue with normal tick processing...
   // Your existing OnTick logic goes here
}

//+------------------------------------------------------------------+
//| Diagnostic function to check symbol status                       |
//+------------------------------------------------------------------+
void DiagnoseMarketStatus()
{
   string symbol = _Symbol;
   bool isSynthetic = (StringFind(symbol, "Boom") != -1 || 
                      StringFind(symbol, "Crash") != -1 || 
                      StringFind(symbol, "Volatility") != -1 || 
                      StringFind(symbol, "Step") != -1);
   
   Print("=== DIAGNOSTIC MARKET STATUS ===");
   Print("Symbole: ", symbol);
   Print("Type: ", isSynthetic ? "Synthétique (24/7)" : "Normal");
   Print("Market Open: ", IsMarketActuallyOpen() ? "✅ OUI" : "❌ NON");
   Print("Current Time: ", TimeToString(TimeCurrent(), TIME_SECONDS));
   
   // Check broker trade mode
   long tradeMode = SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE);
   Print("Trade Mode: ", tradeMode);
   
   // Check if symbol is visible
   bool visible = SymbolInfoInteger(symbol, SYMBOL_VISIBLE);
   Print("Visible: ", visible ? "✅ OUI" : "❌ NON");
   
   // Check current tick
   MqlTick tick;
   if(SymbolInfoTick(symbol, tick))
   {
      Print("Last Tick: ", TimeToString(tick.time, TIME_SECONDS));
      Print("Bid: ", tick.bid, " Ask: ", tick.ask);
   }
   else
   {
      Print("❌ No tick data available");
   }
   Print("===============================");
}

//+------------------------------------------------------------------+
