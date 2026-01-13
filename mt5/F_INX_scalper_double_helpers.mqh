//+------------------------------------------------------------------+
//| Helper functions for F_INX_scalper_double                       |
//+------------------------------------------------------------------+

int CountDuplicatePositions(string symbol)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Symbol() == symbol && positionInfo.Magic() == InpMagicNumber)
         {
            if(positionInfo.Comment() == "DUPLICATA")
               count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Appliquer le Trailing Stop dynamique basé sur l'ATR              |
//+------------------------------------------------------------------+
void ApplyDynamicTrailingStop(ulong ticket)
{
   if(!UseTrailingStop || !positionInfo.SelectByTicket(ticket))
      return;
   
   double currentPrice = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atrValue = 0;
   double atr_b[];
   ArraySetAsSeries(atr_b, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr_b) > 0) atrValue = atr_b[0];
   
   if(atrValue <= 0) return;
   
   double trailingDistance = atrValue * 1.5; // Trailing serré à 1.5x ATR
   double currentSL = positionInfo.StopLoss();
   double newSL = 0;
   
   if(positionInfo.PositionType() == POSITION_TYPE_BUY)
   {
      newSL = NormalizeDouble(currentPrice - trailingDistance, _Digits);
      if(newSL > currentSL + (5 * point) || (currentSL == 0 && newSL < currentPrice - point))
      {
         trade.PositionModify(ticket, newSL, positionInfo.TakeProfit());
      }
   }
   else if(positionInfo.PositionType() == POSITION_TYPE_SELL)
   {
      newSL = NormalizeDouble(currentPrice + trailingDistance, _Digits);
      if(newSL < currentSL - (5 * point) || (currentSL == 0 && newSL > currentPrice + point))
      {
         trade.PositionModify(ticket, newSL, positionInfo.TakeProfit());
      }
   }
}
