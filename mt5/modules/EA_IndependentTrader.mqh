//+------------------------------------------------------------------+
//| EA_IndependentTrader.mqh � Ex�cution des entr�es ind�pendantes   |
//| Conditionn� par: GOOD/PERFECT GOM + IA Status ?70%               |
//+------------------------------------------------------------------+
#ifndef EA_INDEPENDENT_TRADER_MQH
#define EA_INDEPENDENT_TRADER_MQH

// ?? Structure de r�sultat d'entr�e ??????????????????????????????????
struct TradeResult
{
   bool     success;
   ulong    ticket;
   string   reason;
   double   entry;
   double   tp;
   double   sl;
};

// ?? Ex�cuter un BUY ind�pendant ?????????????????????????????????????
TradeResult EAIT_ExecuteBUY(const double lotSize = 0.01)
{
   TradeResult result;
   result.success = false;
   result.ticket = 0;

   // 1. V�rifier gating
   if(!SMCGP_AllowsDirectIndependentEntry(1))
   {
      result.reason = "GOM GATING FAILED";
      Print("[EAIT-BUY] ? ", result.reason);
      return result;
   }

   // 2. Calculer setup
   BUYSetup setup = EAPE_GetBUYSetup();
   if(!setup.valid)
   {
      result.reason = "INVALID SETUP";
      Print("[EAIT-BUY] ? ", result.reason);
      return result;
   }

   // 3. Attendre que le prix touche l'entry
   if(!EAPE_IsPriceTouchingEntry(setup.entry))
   {
      result.reason = "PRICE NOT AT ENTRY";
      Print("[EAIT-BUY] ?? Prix n'a pas touch� entry, attente...";
      return result;
   }

   // 4. Pr�parer la requ�te
   MqlTradeRequest request;
   MqlTradeResult tradeResult;

    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_BUY;
    request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.sl = setup.sl;
    request.tp = setup.tp;
    request.deviation = 50;
    request.magic = 12345;
    request.comment = "EA_INDEP_BUY | GOM=" + g_smcGomVerdict;

    // Vérifier et corriger SL/TP par rapport au stops_level broker
    int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    if(stopLevel > 0)
    {
       double minDist = stopLevel * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
       if(request.price - request.sl < minDist)
          request.sl = NormalizeDouble(request.price - minDist, _Digits);
       if(request.tp - request.price < minDist)
          request.tp = NormalizeDouble(request.price + minDist, _Digits);
    }

    // 5. Envoyer l'ordre
    if(!OrderSend(request, tradeResult))
   {
      result.reason = "ORDER_SEND_FAILED: " + IntegerToString(tradeResult.retcode);
      Print("[EAIT-BUY] ? OrderSend failed: ", result.reason);
      return result;
   }

   // 6. Succ�s
   result.success = true;
   result.ticket = tradeResult.deal;
   result.entry = setup.entry;
   result.tp = setup.tp;
   result.sl = setup.sl;
   result.reason = "SUCCESS";

   Print("[EAIT-BUY] ? BUY plac�:");
   Print("   Ticket: ", result.ticket);
   Print("   Entry: ", DoubleToString(setup.entry, _Digits));
   Print("   TP: ", DoubleToString(setup.tp, _Digits));
   Print("   SL: ", DoubleToString(setup.sl, _Digits));
   Print("   Lot: ", DoubleToString(lotSize, 2));
   Print("   Verdict: ", g_smcGomVerdict, " | IA Status: ", DoubleToString(g_iaStatusConfidence, 1), "%");

   return result;
}

// ?? Ex�cuter un SELL ind�pendant ????????????????????????????????????
TradeResult EAIT_ExecuteSELL(const double lotSize = 0.01)
{
   TradeResult result;
   result.success = false;
   result.ticket = 0;

   // 1. V�rifier gating
   if(!SMCGP_AllowsDirectIndependentEntry(-1))
   {
      result.reason = "GOM GATING FAILED";
      Print("[EAIT-SELL] ? ", result.reason);
      return result;
   }

   // 2. Calculer setup
   SELLSetup setup = EAPE_GetSELLSetup();
   if(!setup.valid)
   {
      result.reason = "INVALID SETUP";
      Print("[EAIT-SELL] ? ", result.reason);
      return result;
   }

   // 3. Attendre que le prix touche l'entry
   if(!EAPE_IsPriceTouchingEntry(setup.entry))
   {
      result.reason = "PRICE NOT AT ENTRY";
      Print("[EAIT-SELL] ?? Prix n'a pas touch� entry, attente...");
      return result;
   }

   // 4. Pr�parer la requ�te
   MqlTradeRequest request;
   MqlTradeResult tradeResult;

    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lotSize;
    request.type = ORDER_TYPE_SELL;
    request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    request.sl = setup.sl;
    request.tp = setup.tp;
    request.deviation = 50;
    request.magic = 12346;
    request.comment = "EA_INDEP_SELL | GOM=" + g_smcGomVerdict;

    // Vérifier et corriger SL/TP par rapport au stops_level broker
    int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    if(stopLevel > 0)
    {
       double minDist = stopLevel * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
       if(request.sl - request.price < minDist)
          request.sl = NormalizeDouble(request.price + minDist, _Digits);
       if(request.price - request.tp < minDist)
          request.tp = NormalizeDouble(request.price - minDist, _Digits);
    }

    // 5. Envoyer l'ordre
    if(!OrderSend(request, tradeResult))
   {
      result.reason = "ORDER_SEND_FAILED: " + IntegerToString(tradeResult.retcode);
      Print("[EAIT-SELL] ? OrderSend failed: ", result.reason);
      return result;
   }

   // 6. Succ�s
   result.success = true;
   result.ticket = tradeResult.deal;
   result.entry = setup.entry;
   result.tp = setup.tp;
   result.sl = setup.sl;
   result.reason = "SUCCESS";

   Print("[EAIT-SELL] ? SELL plac�:");
   Print("   Ticket: ", result.ticket);
   Print("   Entry: ", DoubleToString(setup.entry, _Digits));
   Print("   TP: ", DoubleToString(setup.tp, _Digits));
   Print("   SL: ", DoubleToString(setup.sl, _Digits));
   Print("   Lot: ", DoubleToString(lotSize, 2));
   Print("   Verdict: ", g_smcGomVerdict, " | IA Status: ", DoubleToString(g_iaStatusConfidence, 1), "%");

   return result;
}

#endif
