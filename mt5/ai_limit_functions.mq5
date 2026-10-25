//+------------------------------------------------------------------+
//| Fonctions pour placer des ordres LIMIT basés sur l'analyse IA    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Place un ordre BUY LIMIT basé sur l'analyse IA                   |
//+------------------------------------------------------------------+
void PlaceAIBuyLimitOrder(double entryPrice)
{
   if(entryPrice <= 0) return;
   
   // Vérifier si un ordre similaire existe déjà
   if(OrderExists(ORDER_TYPE_BUY_LIMIT, entryPrice))
   {
      Print("Un ordre BUY LIMIT existe déjà à ce prix: ", entryPrice);
      return;
   }
   
   // Calculer le lot selon la gestion du risque
   double lotSize = CalculateLotSize(entryPrice, 0, 0, true);
   if(lotSize <= 0) return;
   
   // Calculer SL et TP
   double sl = CalculateStopLoss(entryPrice, true);
   double tp = CalculateTakeProfit(entryPrice, true);
   
   // Placer l'ordre
   CTrade trade;
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   string comment = StringFormat("AI BUY LIMIT | Conf: %.2f%% | %s", 
                               g_lastAIConfidence * 100, 
                               g_lastAIReason);
   
   if(trade.BuyLimit(lotSize, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment))
   {
      Print("Ordre BUY LIMIT placé à ", entryPrice, 
            " SL: ", sl, " TP: ", tp, 
            " Lot: ", lotSize);
   }
   else
   {
      Print("Erreur lors du placement de l'ordre BUY LIMIT: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Place un ordre SELL LIMIT basé sur l'analyse IA                  |
//+------------------------------------------------------------------+
void PlaceAISellLimitOrder(double entryPrice)
{
   if(entryPrice <= 0) return;
   
   // Vérifier si un ordre similaire existe déjà
   if(OrderExists(ORDER_TYPE_SELL_LIMIT, entryPrice))
   {
      Print("Un ordre SELL LIMIT existe déjà à ce prix: ", entryPrice);
      return;
   }
   
   // Calculer le lot selon la gestion du risque
   double lotSize = CalculateLotSize(entryPrice, 0, 0, false);
   if(lotSize <= 0) return;
   
   // Calculer SL et TP
   double sl = CalculateStopLoss(entryPrice, false);
   double tp = CalculateTakeProfit(entryPrice, false);
   
   // Placer l'ordre
   CTrade trade;
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   string comment = StringFormat("AI SELL LIMIT | Conf: %.2f%% | %s", 
                               g_lastAIConfidence * 100, 
                               g_lastAIReason);
   
   if(trade.SellLimit(lotSize, entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment))
   {
      Print("Ordre SELL LIMIT placé à ", entryPrice, 
            " SL: ", sl, " TP: ", tp, 
            " Lot: ", lotSize);
   }
   else
   {
      Print("Erreur lors du placement de l'ordre SELL LIMIT: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Vérifie si un ordre similaire existe déjà                       |
//+------------------------------------------------------------------+
bool OrderExists(ENUM_ORDER_TYPE type, double price, double tolerance = 0.00001)
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == _Symbol && 
            OrderMagicNumber() == InpMagicNumber &&
            OrderType() == type)
         {
            if(MathAbs(OrderOpenPrice() - price) <= tolerance)
               return true;
         }
      }
   }
   return false;
}
