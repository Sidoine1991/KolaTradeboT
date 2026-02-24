//+------------------------------------------------------------------+
//|                                          F_INX_scalper_double.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"
#property strict

// Constantes manquantes pour la compatibilité
#ifndef ANCHOR_LEFT_UPPER
#define ANCHOR_LEFT_UPPER 0
#endif
#ifndef ANCHOR_LEFT
#define ANCHOR_LEFT 0
#endif

// Inclusions des bibliothèques Windows nécessaires
#include <WinAPI\errhandlingapi.mqh>
#include <WinAPI\sysinfoapi.mqh>
#include <WinAPI\processenv.mqh>
#include <WinAPI\libloaderapi.mqh>
#include <WinAPI\memoryapi.mqh>

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>

//--- input parameters
input group           "Paramètres de Trading"
input double           InpLotSize           = 0.01;     // Taille du lot
input ulong            InpMagicNumber       = 12345;    // Magic Number
input int              InpStopLoss          = 100;      // Stop Loss en points
input int              InpTakeProfit        = 200;      // Take Profit en points

input group           "Paramètres de Debug"
input bool             DebugMode            = true;     // Mode debug

input group           "Paramètres IA"
input bool             UseAI_Agent          = true;     // Utiliser l'agent IA

//--- global variables
CTrade                trade;
CPositionInfo         positionInfo;
COrderInfo            orderInfo;
CDealInfo             dealInfo;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- set trade object magic number
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
   
   if(DebugMode)
      Print("Robot F_INX_Scalper_double initialisé");
      
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(DebugMode)
      Print("Robot F_INX_Scalper_double arrêté");
}

//+------------------------------------------------------------------+
//| Market hours validation for synthetic indices                    |
//| Prevents false "Market Closed" detection for 24/7 indices        |
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
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // FIX: Market hours validation for synthetic indices
   // Prevent false "Market Closed" detection for Boom/Crash/Volatility/Step indices
   if(!ValidateMarketHoursForSyntheticIndices())
      return;
   
   // Simple trading logic for testing
   static datetime lastTradeTime = 0;
   
   // Only check for trades every 60 seconds
   if(TimeCurrent() - lastTradeTime < 60)
      return;
   
   // Check if we already have a position
   if(PositionsTotal() > 0)
      return;
   
   // Simple buy condition (for testing)
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double sl = ask - InpStopLoss * point;
   double tp = ask + InpTakeProfit * point;
   
   if(trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "Test trade"))
   {
      if(DebugMode)
         Print("✅ Trade ouvert: BUY ", _Symbol, " à ", ask);
      lastTradeTime = TimeCurrent();
   }
   else
   {
      if(DebugMode)
         Print("❌ Erreur ouverture trade: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
