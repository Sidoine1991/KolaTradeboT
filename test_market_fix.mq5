//+------------------------------------------------------------------+
//| Test compilation for market hours fix                           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property version   "1.00"

// Test parameters
input bool DebugMode = true;

//+------------------------------------------------------------------+
//| Test function for market validation                              |
//+------------------------------------------------------------------+
bool ValidateMarketHoursForSyntheticIndices()
{
   string symbol = _Symbol;
   
   // Check if it's a synthetic index that trades 24/7
   if(StringFind(symbol, "Boom") != -1 || 
      StringFind(symbol, "Crash") != -1 || 
      StringFind(symbol, "Volatility") != -1 || 
      StringFind(symbol, "Step") != -1)
   {
      // Synthetic indices trade 24/7 - always allow processing
      if(DebugMode)
         Print("✅ Synthetic index detected: ", symbol, " - Market always open");
      return true;
   }
   
   // For other symbols (Forex, etc.), check normal market hours
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Weekend check (Saturday/Sunday)
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
   {
      if(DebugMode)
         Print("INFO: Marché fermé - week-end pour ", symbol);
      return false;
   }
   
   // Forex market hours check (Sunday 22:00 UTC to Friday 22:00 UTC)
   if(dt.day_of_week == 5 && dt.hour >= 22)
   {
      if(DebugMode)
         Print("INFO: Marché fermé - fin de semaine forex pour ", symbol);
      return false;
   }
   
   // Market is open for normal symbols
   if(DebugMode)
      Print("✅ Market open for: ", symbol);
   return true;
}

//+------------------------------------------------------------------+
//| Test OnTick function                                            |
//+------------------------------------------------------------------+
void OnTick()
{
   // Test the market validation
   if(!ValidateMarketHoursForSyntheticIndices())
   {
      Print("❌ Tick processing blocked for: ", _Symbol);
      return;
   }
   
   Print("✅ Tick processing allowed for: ", _Symbol);
}

//+------------------------------------------------------------------+
//| OnInit function                                                |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== MARKET HOURS FIX TEST ===");
   Print("Testing market validation for: ", _Symbol);
   
   // Test the function
   bool result = ValidateMarketHoursForSyntheticIndices();
   Print("Validation result: ", result ? "✅ PASS" : "❌ FAIL");
   Print("==========================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
