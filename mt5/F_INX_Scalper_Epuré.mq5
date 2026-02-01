//+------------------------------------------------------------------+
//|                                    F_INX_Scalper_Epuré.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "2.00 - ÉPURÉ"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| PARAMÈTRES ESSENTIELS SEULEMENT                                   |
//+------------------------------------------------------------------+
input group "=== CONFIGURATION PRINCIPALE ==="
input int    MagicNumber        = 888888;     // Magic Number
input double LotSize           = 0.01;        // Taille de lot
input double StopLossPoints    = 100;         // Stop Loss en points
input double TakeProfitPoints  = 300;         // Take Profit en points
input double RiskPerTrade      = 2.0;         // Risque par trade en %

input group "=== STRATÉGIE SIMPLE ==="
input int    FastEMA           = 21;          // EMA rapide
input int    SlowEMA           = 50;          // EMA lente
input int    RSIPeriod         = 14;          // Période RSI
input double RSIOverbought     = 70;          // RSI surachat
input double RSIOversold       = 30;          // RSI survente

input group "=== PROTECTION ==="
input bool   UseTrendFilter    = true;        // Filtrer par tendance
input bool   UseRangeFilter    = true;        // Éviter les ranges
input int    MaxPositions      = 1;           // Max positions simultanées
input double DailyProfitTarget = 50.0;       // Objectif profit quotidien
input double DailyLossLimit    = 20.0;        // Limite perte quotidienne

input group "=== SESSIONS ==="
input bool   UseSessionFilter  = true;        // Filtrer par sessions
input int    StartHour         = 8;            // Heure début (8h)
input int    EndHour           = 18;           // Heure fin (18h)

input group "=== DEBUG ==="
input bool   DebugMode         = true;        // Logs détaillés

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;

// Compteurs quotidiens
static double dailyProfit = 0;
static double dailyLoss = 0;
static datetime lastResetDate = 0;

// Indicateurs
static int emaFastHandle;
static int emaSlowHandle;
static int rsiHandle;

//+------------------------------------------------------------------+
//| INITIALISATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(10);
   
   // Initialiser les indicateurs
   emaFastHandle = iMA(_Symbol, PERIOD_CURRENT, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, PERIOD_CURRENT, SlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSIPeriod, PRICE_CLOSE);
   
   if(emaFastHandle < 0 || emaSlowHandle < 0 || rsiHandle < 0)
   {
      Print("❌ Erreur initialisation indicateurs");
      return INIT_FAILED;
   }
   
   Print("✅ F_INX_Scalper_Epuré initialisé");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALISATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("🔄 F_INX_Scalper_Epuré arrêté");
}

//+------------------------------------------------------------------+
//| TICK PRINCIPAL                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   // Réinitialiser les compteurs quotidiens
   ResetDailyCounters();
   
   // Mettre à jour les compteurs de profit/perte
   UpdateDailyCounters();
   
   // Vérifier si le trading est autorisé
   if(!IsTradingAllowed()) return;
   
   // Récupérer les données des indicateurs
   double emaFast[], emaSlow[], rsi[];
   ArrayResize(emaFast, 3);
   ArrayResize(emaSlow, 3);
   ArrayResize(rsi, 3);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFast) < 3 ||
      CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlow) < 3 ||
      CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3)
   {
      return;
   }
   
   // Stratégie de trading
   CheckForTradingOpportunities(emaFast, emaSlow, rsi);
}

//+------------------------------------------------------------------+
//| RÉINITIALISER COMPTEURS QUOTIDIENS                                |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));
   
   if(today != lastResetDate)
   {
      dailyProfit = 0;
      dailyLoss = 0;
      lastResetDate = today;
      if(DebugMode) Print("📅 Compteurs quotidiens réinitialisés");
   }
}

//+------------------------------------------------------------------+
//| METTRE À JOUR COMPTEURS QUOTIDIENS                                |
//+------------------------------------------------------------------+
void UpdateDailyCounters()
{
   double totalProfit = 0;
   double totalLoss = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
         {
            double profit = position.Profit();
            if(profit > 0)
               totalProfit += profit;
            else
               totalLoss += MathAbs(profit);
         }
      }
   }
   
   dailyProfit = totalProfit;
   dailyLoss = totalLoss;
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI LE TRADING EST AUTORISÉ                              |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   // Vérifier les objectifs quotidiens
   if(dailyProfit >= DailyProfitTarget)
   {
      if(DebugMode) Print("🎯 Objectif profit atteint: ", dailyProfit, "$");
      return false;
   }
   
   if(dailyLoss >= DailyLossLimit)
   {
      if(DebugMode) Print("🛑 Limite perte atteinte: ", dailyLoss, "$");
      return false;
   }
   
   // Vérifier le nombre de positions
   int currentPositions = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == MagicNumber)
            currentPositions++;
      }
   }
   
   if(currentPositions >= MaxPositions)
   {
      if(DebugMode) Print("📊 Max positions atteint: ", currentPositions);
      return false;
   }
   
   // Vérifier les sessions
   if(UseSessionFilter && !IsInTradingSession())
   {
      if(DebugMode) Print("⏰ Hors session de trading");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VÉRIFIER SESSION DE TRADING                                      |
//+------------------------------------------------------------------+
bool IsInTradingSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   return (dt.hour >= StartHour && dt.hour < EndHour);
}

//+------------------------------------------------------------------+
//| VÉRIFIER OPPORTUNITÉS DE TRADING                                  |
//+------------------------------------------------------------------+
void CheckForTradingOpportunities(double &emaFast[], double &emaSlow[], double &rsi[])
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentRSI = rsi[2];
   
   // Vérifier si on est dans un range
   if(UseRangeFilter && IsMarketInRange(emaFast, emaSlow))
   {
      if(DebugMode) Print("📊 Marché en range - pas de trade");
      return;
   }
   
   // Signal BUY : croisement haussier + RSI pas suracheté
   if(emaFast[2] > emaSlow[2] && emaFast[1] <= emaSlow[1] && currentRSI < RSIOverbought)
   {
      if(DebugMode) 
      {
         Print("📈 Signal BUY:");
         Print("   EMA Fast: ", emaFast[2], " > EMA Slow: ", emaSlow[2]);
         Print("   RSI: ", currentRSI, " < ", RSIOverbought);
      }
      
      if(!HasPosition(POSITION_TYPE_BUY))
      {
         OpenPosition(POSITION_TYPE_BUY);
      }
   }
   
   // Signal SELL : croisement baissier + RSI pas survendu
   else if(emaFast[2] < emaSlow[2] && emaFast[1] >= emaSlow[1] && currentRSI > RSIOversold)
   {
      if(DebugMode) 
      {
         Print("📉 Signal SELL:");
         Print("   EMA Fast: ", emaFast[2], " < EMA Slow: ", emaSlow[2]);
         Print("   RSI: ", currentRSI, " > ", RSIOversold);
      }
      
      if(!HasPosition(POSITION_TYPE_SELL))
      {
         OpenPosition(POSITION_TYPE_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| DÉTECTER SI MARCHÉ EN RANGE                                        |
//+------------------------------------------------------------------+
bool IsMarketInRange(double &emaFast[], double &emaSlow[])
{
   double spread = MathAbs(emaFast[2] - emaSlow[2]);
   double minSpread = 20 * _Point; // Spread minimum pour considérer une tendance
   
   // Si les EMA sont trop proches, on est probablement dans un range
   if(spread < minSpread)
   {
      if(DebugMode) Print("📊 Range détecté - spread EMA: ", spread);
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI ON A UNE POSITION                                     |
//+------------------------------------------------------------------+
bool HasPosition(ENUM_POSITION_TYPE type)
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && 
            position.Magic() == MagicNumber && 
            position.PositionType() == type)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| OUVRIR UNE POSITION                                               |
//+------------------------------------------------------------------+
void OpenPosition(ENUM_POSITION_TYPE type)
{
   double price, sl, tp;
   
   if(type == POSITION_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = price - StopLossPoints * _Point;
      tp = price + TakeProfitPoints * _Point;
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = price + StopLossPoints * _Point;
      tp = price - TakeProfitPoints * _Point;
   }
   
   // Validation des distances minimales du broker
   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(minStopLevel > 0)
   {
      if(type == POSITION_TYPE_BUY)
      {
         if(price - sl < minStopLevel) sl = price - minStopLevel;
         if(tp - price < minStopLevel) tp = price + minStopLevel;
      }
      else
      {
         if(sl - price < minStopLevel) sl = price + minStopLevel;
         if(price - tp < minStopLevel) tp = price - minStopLevel;
      }
   }
   
   // Calculer le lot size basé sur le risque
   double lotSize = CalculateLotSize(sl, price, type);
   
   bool result = false;
   if(type == POSITION_TYPE_BUY)
   {
      result = trade.Buy(lotSize, _Symbol, price, sl, tp, "Scalper Epuré BUY");
   }
   else
   {
      result = trade.Sell(lotSize, _Symbol, price, sl, tp, "Scalper Epuré SELL");
   }
   
   if(result)
   {
      if(DebugMode) 
      {
         Print("✅ Position ", type == POSITION_TYPE_BUY ? "BUY" : "SELL", 
               " ouverte à ", price);
         Print("   SL: ", sl, " TP: ", tp, " Lot: ", lotSize);
      }
   }
   else
   {
      if(DebugMode) Print("❌ Erreur ouverture position: ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| CALCULER LOT SIZE BASÉ SUR LE RISQUE                              |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl, double entry, ENUM_POSITION_TYPE type)
{
   double riskPoints = MathAbs(entry - sl);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * RiskPerTrade / 100.0;
   
   double lotSize = riskAmount / (riskPoints * tickValue / tickSize);
   
   // Normaliser et valider
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   return lotSize;
}
