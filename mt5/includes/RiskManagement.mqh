//+------------------------------------------------------------------+
//| RiskManagement.mqh - Gestion des risques pour Fx_robot           |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property strict

//--- Inclusions
#include "D:\\Dev\\TradBOT\\mt5\\includes\\Common.mqh"

//+------------------------------------------------------------------+
//| Fonctions de gestion du risque                                   |
//+------------------------------------------------------------------+

//--- Variables d'entrée pour la gestion du risque
input double   InpRiskPercent     = 1.0;     // Pourcentage de risque par trade
input double   InpLotFixed        = 0.0;     // Taille de lot fixe (0=auto)
input double   InpMaxDailyLoss    = 5.0;     // Perte quotidienne maximale (% du solde)
input bool     InpUseTrailingStop = true;    // Activer le trailing stop
input double   InpTrailingStopATR = 1.5;     // Multiplicateur ATR pour le trailing stop

//--- Variables globales
double g_dailyStartBalance = 0.0;
datetime g_lastDayChecked = 0;

//+------------------------------------------------------------------+
//| Vérifie si le risque quotidien est dépassé                       |
//+------------------------------------------------------------------+
bool IsDailyLossLimitReached()
{
   datetime currentDay = TimeCurrent() / 86400 * 86400;
   
   // Réinitialiser le solde de départ pour le nouveau jour
   if(g_lastDayChecked != currentDay)
   {
      g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_lastDayChecked = currentDay;
      return false;
   }
   
   // Vérifier la perte quotidienne
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double dailyLoss = g_dailyStartBalance - currentBalance;
   double maxAllowedLoss = g_dailyStartBalance * (InpMaxDailyLoss / 100.0);
   
   if(dailyLoss >= maxAllowedLoss)
   {
      Print("Limite de perte quotidienne atteinte : ", DoubleToString(dailyLoss, 2), 
            " (", DoubleToString(InpMaxDailyLoss, 1), "%)");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calcule la taille de position appropriée                         |
//+------------------------------------------------------------------+
double CalculatePositionSize(string symbol, double stopLossPips)
{
   if(InpLotFixed > 0) 
      return NormalizeLotSize(symbol, InpLotFixed);
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(tickValue == 0 || tickSize == 0 || point == 0) 
      return NormalizeLotSize(symbol, SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN));
   
   double lotSize = riskAmount / (stopLossPips * tickValue * point / tickSize);
   return NormalizeLotSize(symbol, lotSize);
}

//+------------------------------------------------------------------+
//| Normalise la taille du lot selon les paramètres du symbole       |
//+------------------------------------------------------------------+
double NormalizeLotSize(string symbol, double lotSize)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| Gère le trailing stop pour toutes les positions                  |
//+------------------------------------------------------------------+
void ManageTrailingStops()
{
   if(!InpUseTrailingStop) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         ulong magic = PositionGetInteger(POSITION_MAGIC);
         
         if(magic != InpMagicNumber) continue;
         
         int atr_handle = iATR(symbol, PERIOD_CURRENT, 14);
         double atr[1];
         if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0)
         {
            Print("Erreur lors de la copie des données ATR: ", GetLastError());
            continue;
         }
         IndicatorRelease(atr_handle);
         double newStopLoss = 0;
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            newStopLoss = currentPrice - (atr[0] * InpTrailingStopATR);
            
            if(newStopLoss > PositionGetDouble(POSITION_SL) + SymbolInfoDouble(symbol, SYMBOL_POINT))
            {
               trade.PositionModify(PositionGetInteger(POSITION_TICKET), 
                                  newStopLoss, 
                                  PositionGetDouble(POSITION_TP));
            }
         }
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            newStopLoss = currentPrice + (atr * InpTrailingStopATR);
            
            if(newStopLoss < PositionGetDouble(POSITION_SL) - SymbolInfoDouble(symbol, SYMBOL_POINT) || 
               PositionGetDouble(POSITION_SL) == 0)
            {
               trade.PositionModify(PositionGetInteger(POSITION_TICKET), 
                                  newStopLoss, 
                                  PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}
