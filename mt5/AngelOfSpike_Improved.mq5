//+------------------------------------------------------------------+
//|                                              AngelOfSpike_Improved.mq5 |
//|                        Copyright 2025, Your Name                  |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Your Name"
#property link      "https://www.yoursite.com"
#property version   "1.00"

//--- includes
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/DealInfo.mqh>

//--- paramètres d'entrée
input group "=== GESTION DU RISQUE ==="
input double InpCapitalPerTradePercent = 2.0;     // % du capital à risquer
input double InpMaxDailyDrawdown = 5.0;          // Drawdown quotidien max (%)
input bool   InpDebug = true;                    // Activer les logs de débogage

input group "=== FILTRES ==="
input bool   InpUseVolatilityFilter = true;      // Filtre de volatilité
input double InpMinATR = 0.0002;                 // ATR minimum
input bool   InpUseTimeFilter = true;            // Filtre horaire
input string InpTradeStartTime = "08:00";        // Heure de début
input string InpTradeEndTime = "20:00";          // Heure de fin
input int    InpMaxSpreadPoints = 20;            // Spread max en points

input group "=== GESTION DES POSITIONS ==="
input bool   InpUseTrailingStop = true;          // Activer le trailing stop
input double InpTrailingStart = 10.0;            // Distance pour démarrer
input double InpTrailingStep = 5.0;              // Pas du trailing
input bool   InpUseBreakEven = true;             // Activer le break-even
input double InpBreakEvenAt = 10.0;              // Niveau pour le break-even

//--- variables globales
CTrade trade;
CPositionInfo posInfo;
CDealInfo dealInfo;
double g_dailyStartBalance = 0;
double g_maxDailyDrawdown = 0;
bool g_tradingAllowed = true;
datetime g_lastTradeTime = 0;
int g_magicNumber = 123456;  // Changez ce numéro magique

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialisation du trade
   trade.SetExpertMagicNumber(g_magicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Initialisation des soldes
   g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_maxDailyDrawdown = g_dailyStartBalance * (1 - InpMaxDailyDrawdown/100.0);
   
   // Vérification des paramètres
   if(InpCapitalPerTradePercent <= 0 || InpCapitalPerTradePercent > 100)
   {
      Print("Erreur: Le pourcentage de risque par trade doit être compris entre 0 et 100");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   Print("=== AngelOfSpike Initialisé ===");
   Print("Capital initial: ", g_dailyStartBalance);
   Print("Niveau de drawdown maximum: ", g_maxDailyDrawdown);
   Print("Heure de trading: ", InpTradeStartTime, " - ", InpTradeEndTime);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Vérifier si c'est une nouvelle barre                             |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(lastBarTime != currentBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier les conditions du marché                                |
//+------------------------------------------------------------------+
bool CheckMarketConditions(string symbol)
{
   // Vérifier l'heure de trading
   if(InpUseTimeFilter && !IsTradeTime())
   {
      if(InpDebug) Print("Heure de trading en dehors des plages autorisées");
      return false;
   }
   
   // Vérifier la volatilité
   if(InpUseVolatilityFilter)
   {
      double atr = iATR(symbol, PERIOD_M15, 14);
      double atrThreshold = SymbolInfoDouble(symbol, SYMBOL_POINT) * InpMinATR;
      
      if(atr < atrThreshold)
      {
         if(InpDebug) Print("Volatilité trop faible: ATR=", atr, " (min=", atrThreshold, ")");
         return false;
      }
   }
   
   // Vérifier le spread
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(spread > InpMaxSpreadPoints * SymbolInfoDouble(symbol, SYMBOL_POINT))
   {
      if(InpDebug) Print("Spread trop élevé: ", spread);
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Vérifier si c'est l'heure de trading                             |
//+------------------------------------------------------------------+
bool IsTradeTime()
{
   datetime timeNow = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(timeNow, timeStruct);
   
   int currentMinutes = timeStruct.hour * 60 + timeStruct.min;
   int startMinutes = (int)StringToInteger(StringSubstr(InpTradeStartTime, 0, 2)) * 60 + 
                     (int)StringToInteger(StringSubstr(InpTradeStartTime, 3, 2));
   int endMinutes = (int)StringToInteger(StringSubstr(InpTradeEndTime, 0, 2)) * 60 + 
                   (int)StringToInteger(StringSubstr(InpTradeEndTime, 3, 2));
   
   return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
}

//+------------------------------------------------------------------+
//| Mettre à jour le trailing stop                                   |
//+------------------------------------------------------------------+
void UpdateTrailingStop(string symbol)
{
   if(!InpUseTrailingStop) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_magicNumber) continue;
      
      double currentStop = PositionGetDouble(POSITION_SL);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double newStop = 0;
      bool modify = false;
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double distance = (currentPrice - openPrice) / point;
         if(distance >= InpTrailingStart / point)
         {
            newStop = currentPrice - (InpTrailingStep * point);
            if(newStop > currentStop + (point * 10))
            {
               modify = true;
            }
         }
      }
      else // SELL
      {
         double distance = (openPrice - currentPrice) / point;
         if(distance >= InpTrailingStart / point)
         {
            newStop = currentPrice + (InpTrailingStep * point);
            if(newStop < currentStop - (point * 10) || currentStop == 0)
            {
               modify = true;
            }
         }
      }
      
      if(modify)
      {
         double takeProfit = PositionGetDouble(POSITION_TP);
         trade.PositionModify(ticket, newStop, takeProfit);
      }
   }
}

//+------------------------------------------------------------------+
//| Fonction principale                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérifier le drawdown quotidien
   if(AccountInfoDouble(ACCOUNT_BALANCE) < g_maxDailyDrawdown)
   {
      if(g_tradingAllowed)
      {
         Print("Drawdown quotidien maximum atteint. Arrêt du trading pour aujourd'hui.");
         g_tradingAllowed = false;
      }
      return;
   }
   
   // Mise à jour du trailing stop
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         if(PositionGetInteger(POSITION_MAGIC) == g_magicNumber)
         {
            UpdateTrailingStop(symbol);
         }
      }
   }
   
   // Vérifier les conditions pour de nouvelles entrées
   if(IsNewBar() && g_tradingAllowed && CheckMarketConditions(_Symbol))
   {
      // Votre logique de trading ici
      // Exemple: if(ConditionAchat()) { trade.Buy(...); }
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== AngelOfSpike Arrêté ===");
   Print("Raison: ", reason);
}