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
   if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "Boom") >= 0 ||
      StringFind(symbol, "CRASH") >= 0 || StringFind(symbol, "Crash") >= 0)
      return SYM_BOOM_CRASH;

   string symUpper = symbol;
   StringToUpper(symUpper);
   if(StringFind(symUpper, "PAINX") >= 0 || StringFind(symUpper, "GAINX") >= 0
      || StringFind(symUpper, "TRENDX") >= 0 || StringFind(symUpper, "BREAKX") >= 0)
      return SYM_BOOM_CRASH;

   if(StringFind(symbol, "VOL") >= 0 || StringFind(symbol, "Vol") >= 0 ||
      StringFind(symbol, "FXVOL") >= 0 || StringFind(symbol, "SFVVOL") >= 0 ||
      StringFind(symbol, "SFXVOL") >= 0)
      return SYM_VOLATILITY;

   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0 ||
      StringFind(symbol, "Gold") >= 0 ||
      StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0 ||
      StringFind(symbol, "Silver") >= 0)
      return SYM_METAL;

   if(StringFind(symbol, "BTC") >= 0 || StringFind(symbol, "ETH") >= 0)
      return SYM_CRYPTO;

   if(StringLen(symbol) <= 7)
      return SYM_FOREX;

   return SYM_UNKNOWN;
}

#endif // SMC_SYMBOL_CATEGORY_MQH
