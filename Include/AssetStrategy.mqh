//+------------------------------------------------------------------+
//| AssetStrategy.mqh - Asset family / trading mode helpers           |
//+------------------------------------------------------------------+
#ifndef ASSET_STRATEGY_MQH
#define ASSET_STRATEGY_MQH

string AssetStrategy_GetCategoryName(const string symbol)
{
   string s = symbol;
   StringToUpper(s);

   if(StringFind(s, "BOOM") >= 0 && StringFind(s, "CRASH") < 0)
      return "Boom";
   if(StringFind(s, "CRASH") >= 0)
      return "Crash";
   if(StringFind(s, "VOLATILITY") >= 0 || StringFind(s, "VOL ") >= 0)
      return "Volatility";
   if(StringFind(s, "STEP") >= 0)
      return "Step";
   if(StringFind(s, "RANGE BREAK") >= 0)
      return "Range";
   if(StringFind(s, "JUMP") >= 0)
      return "Jump";
   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0)
      return "Metals";
   if(StringLen(s) == 6 && StringFind(s, "USD") >= 0)
      return "Forex";

   return "Unknown";
}

string AssetStrategy_GetTradingMode(const string symbol)
{
   string cat = AssetStrategy_GetCategoryName(symbol);
   if(cat == "Boom" || cat == "Crash")
      return "SPIKE";
   if(cat == "Volatility" || cat == "Step" || cat == "Jump" || cat == "Range")
      return "SYNTH";
   if(cat == "Forex" || cat == "Metals")
      return "CLASSIC";
   return "GENERIC";
}

bool AssetStrategy_IsSynthetic(const string symbol)
{
   string mode = AssetStrategy_GetTradingMode(symbol);
   return (mode == "SPIKE" || mode == "SYNTH");
}

#endif
