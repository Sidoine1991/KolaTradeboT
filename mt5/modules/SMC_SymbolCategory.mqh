//+------------------------------------------------------------------+
//| SMC_SymbolCategory.mqh — catégorie symbole (Boom/Crash, FX, etc.) |
//+------------------------------------------------------------------+
#ifndef SMC_SYMBOL_CATEGORY_MQH
#define SMC_SYMBOL_CATEGORY_MQH

#ifndef ENUM_SYMBOL_CATEGORY_DEFINED
   enum ENUM_SYMBOL_CATEGORY
   {
      SYM_BOOM_CRASH,
      SYM_VOLATILITY,
      SYM_FOREX,
      SYM_COMMODITY,
      SYM_METAL,
      SYM_CRYPTO,
      SYM_UNKNOWN
   };
   #define ENUM_SYMBOL_CATEGORY_DEFINED
#endif

//+------------------------------------------------------------------+
ENUM_SYMBOL_CATEGORY SMC_GetSymbolCategory(const string symbol)
{
   string s = symbol;
   StringToUpper(s);

   // Deriv: indices de spike (Boom/Crash)
   if(StringFind(s, "BOOM") >= 0 || StringFind(s, "CRASH") >= 0)
      return SYM_BOOM_CRASH;

   // Weltrade / synthétiques spike (PainX, GainX, TrendX, BreakX)
   if(StringFind(s, "PAINX") >= 0 || StringFind(s, "GAINX") >= 0
      || StringFind(s, "TRENDX") >= 0 || StringFind(s, "BREAKX") >= 0)
      return SYM_BOOM_CRASH;

   // Deriv: Volatility, Jump, Step, Range Break
   if(StringFind(s, "VOLATILITY") >= 0 || StringFind(s, "RANGE BREAK") >= 0
      || StringFind(s, "JUMP") >= 0 || StringFind(s, "STEP") >= 0
      || StringFind(s, "VOL") >= 0 || StringFind(s, "FXVOL") >= 0
      || StringFind(s, "SFVVOL") >= 0 || StringFind(s, "SFXVOL") >= 0)
      return SYM_VOLATILITY;

   // Métaux (XAUUSD, XAUUSDm, GOLD#, etc.)
   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0
      || StringFind(s, "XAG") >= 0 || StringFind(s, "SILVER") >= 0)
      return SYM_METAL;

   // Commodities
   if(StringFind(s, "OIL") >= 0 || StringFind(s, "COPPER") >= 0)
      return SYM_COMMODITY;

   // Crypto
   if(StringFind(s, "BTC") >= 0 || StringFind(s, "ETH") >= 0 || StringFind(s, "SOL") >= 0
      || StringFind(s, "CRYPTO") >= 0 || StringFind(s, "BITCOIN") >= 0
      || StringFind(s, "ETHEREUM") >= 0)
      return SYM_CRYPTO;

   // Forex majeurs
   if(StringFind(s, "USD") >= 0 || StringFind(s, "EUR") >= 0
      || StringFind(s, "GBP") >= 0 || StringFind(s, "JPY") >= 0)
      return SYM_FOREX;

   if(StringLen(symbol) <= 7)
      return SYM_FOREX;

   return SYM_UNKNOWN;
}

#endif // SMC_SYMBOL_CATEGORY_MQH
