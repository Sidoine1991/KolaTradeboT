//+------------------------------------------------------------------+
//| RoboCop_V2_Compiled_Fixed.mq5 |
//| Copyright 2025, Sidoine & Grok/xAI |
//| https://x.ai/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Sidoine & Grok/xAI"
#property link "https://x.ai"
#property version "2.00"
#property strict

//--- Inclusions standards
#include <Trade\Trade.mqh>
#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\List.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Déclaration de l'objet Trade
CTrade trade;
CArrayObj *dashboardObjects;
CList *tradeHistory;

//--- Énumérations pour les états et les types
enum ENUM_EA_STATE
{
   EA_STATE_INIT,
   EA_STATE_READY,
   EA_STATE_TRADING,
   EA_STATE_PAUSED,
   EA_STATE_ERROR
};

enum ENUM_TRADE_SIGNAL
{
   SIGNAL_NONE,
   SIGNAL_BUY,
   SIGNAL_SELL,
   SIGNAL_CLOSE_BUY,
   SIGNAL_CLOSE_SELL
};

//--- Classe pour stocker les données des trades
class TradeData : public CObject
{
public:
   ulong ticket;
   string symbol;
   double volume;
   double openPrice;
   double sl;
   double tp;
   double profit;
   datetime openTime;
   datetime closeTime;
   ENUM_TRADE_SIGNAL signal;
   
   TradeData()
   {
      ticket = 0;
      symbol = "";
      volume = 0.0;
      openPrice = 0.0;
      sl = 0.0;
      tp = 0.0;
      profit = 0.0;
      openTime = 0;
      closeTime = 0;
      signal = SIGNAL_NONE;
   }
};

//+------------------------------------------------------------------+
//| Paramètres d'entrée |
//+------------------------------------------------------------------+
input double RiskPercent = 1.0;
input double FixedLot = 0.1;
input bool UseFixedLot = false;
input int TrailingStart = 100;
input int TrailingStep = 50;
input int BreakevenStart = 100;
input double AdxThreshold = 20.0;
input int BreakoutPeriod = 20;
input double ATRMultiplier = 1.5;
input double RiskReward = 2.0;
input int MagicBuy = 20231201;
input int MagicSell = 20231202;
input int HourStart1 = 8;
input int HourEnd1 = 11;
input int HourStart2 = 13;
input int HourEnd2 = 17;
input int MaxSpreadPoints = 20;
input double DailyProfitTarget = 100.0;
input bool EnableNotifications = true;
input string NotificationEmail = "";
input bool EnableCSVLogging = true;
input bool EnableDashboard = true;

//--- Variables globales
int emaHandle9, emaHandle21, emaHandle50;
int rsiHandle, adxHandle, atrHandle, macdHandle;
double dailyProfit = 0.0;
int tradesToday = 0;
string lastSignal = "HOLD";
int lastTradingDay = -1;
int fileHandle = INVALID_HANDLE;
ENUM_EA_STATE eaState = EA_STATE_INIT;
datetime lastTradeTime = 0;

//+------------------------------------------------------------------+
//| Fonction d'initialisation |
//+------------------------------------------------------------------+
int OnInit()
{
   emaHandle9 = iMA(_Symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
   emaHandle21 = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
   emaHandle50 = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, _Period, 14);
   atrHandle = iATR(_Symbol, _Period, 14);
   macdHandle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);

   if(EnableCSVLogging)
   {
      string filename = "trades_log_" + _Symbol + ".csv";
      fileHandle = FileOpen(filename, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(fileHandle == INVALID_HANDLE)
      {
         Print("Échec de l'ouverture du fichier CSV: ", GetLastError());
      }
      else
      {
         FileWrite(fileHandle, "Date", "Heure", "Symbole", "Type", "Lot", "Prix Ouverture", "SL", "TP", "Prix Fermeture", "Profit", "Magic", "Signal", "Commentaire");
      }
   }

   tradeHistory = new CList();
   eaState = EA_STATE_READY;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Fonction de désinitialisation |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(emaHandle9);
   IndicatorRelease(emaHandle21);
   IndicatorRelease(emaHandle50);
   IndicatorRelease(rsiHandle);
   IndicatorRelease(adxHandle);
   IndicatorRelease(atrHandle);
   IndicatorRelease(macdHandle);

   if(fileHandle != INVALID_HANDLE)
   {
      FileClose(fileHandle);
   }

   if(tradeHistory != NULL)
   {
      delete tradeHistory;
   }
}

//+------------------------------------------------------------------+
//| Fonction principale du tick |
//+------------------------------------------------------------------+
void OnTick()
{
   if(eaState == EA_STATE_ERROR)
   {
      return;
   }

   int today = (int)Day();
   if(today != lastTradingDay)
   {
      dailyProfit = 0.0;
      tradesToday = 0;
      lastTradingDay = today;
   }

   if(DailyProfitTarget > 0 && dailyProfit >= DailyProfitTarget)
   {
      return;
   }

   ManageOpenPositions();
}

//+------------------------------------------------------------------+
//| Gère les positions ouvertes |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!PositionSelect(_Symbol)) continue;
      ulong ticket = PositionGetTicket(i);
      int magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != MagicBuy && magic != MagicSell) continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      if(profit > TrailingStart * _Point)
      {
         double newSL = (type == POSITION_TYPE_BUY) ?
            SymbolInfoDouble(_Symbol, SYMBOL_BID) - TrailingStep * _Point :
            SymbolInfoDouble(_Symbol, SYMBOL_ASK) + TrailingStep * _Point;

         if((type == POSITION_TYPE_BUY && newSL > sl) || (type == POSITION_TYPE_SELL && (sl == 0 || newSL < sl)))
         {
            trade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gestion des transactions commerciales |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_ORDER_ADD && trans.order > 0)
   {
      LogTradeToFile(trans.order);
   }
   else if(trans.type == TRADE_TRANSACTION_DEAL_ADD && trans.deal > 0)
   {
      UpdateDailyStatsFromDeal(trans.deal);
   }
}

//+------------------------------------------------------------------+
//| Enregistre un trade dans le fichier CSV |
//+------------------------------------------------------------------+
void LogTradeToFile(ulong orderID)
{
   if(!EnableCSVLogging || fileHandle == INVALID_HANDLE) return;

   if(HistoryOrderSelect(orderID))
   {
      string sym = HistoryOrderGetString(orderID, ORDER_SYMBOL);
      double vol = HistoryOrderGetDouble(orderID, ORDER_VOLUME_INITIAL);
      double price = HistoryOrderGetDouble(orderID, ORDER_PRICE_OPEN);
      double sl = HistoryOrderGetDouble(orderID, ORDER_SL);
      double tp = HistoryOrderGetDouble(orderID, ORDER_TP);
      double profit = HistoryOrderGetDouble(orderID, ORDER_PROFIT);
      double closePrice = HistoryOrderGetDouble(orderID, ORDER_PRICE_CURRENT);
      string dateStr = TimeToString(HistoryOrderGetInteger(orderID, ORDER_TIME_OPEN), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string timeStr = TimeToString(HistoryOrderGetInteger(orderID, ORDER_TIME_OPEN), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string comment = HistoryOrderGetString(orderID, ORDER_COMMENT);

      FileWrite(fileHandle,
         dateStr, timeStr, sym,
         (HistoryOrderGetInteger(orderID, ORDER_TYPE) == ORDER_TYPE_BUY) ? "BUY" : "SELL",
         vol, price, sl, tp, closePrice, profit,
         HistoryOrderGetInteger(orderID, ORDER_MAGIC),
         lastSignal, comment);
   }
}

//+------------------------------------------------------------------+
//| Met à jour les statistiques après un deal |
//+------------------------------------------------------------------+
void UpdateDailyStatsFromDeal(ulong dealID)
{
   if(HistoryDealSelect(dealID))
   {
      double profit = HistoryDealGetDouble(dealID, DEAL_PROFIT);
      dailyProfit += profit;
      tradesToday++;
   }
}

//+------------------------------------------------------------------+
//| Sauvegarde l'historique des trades dans un fichier |
//+------------------------------------------------------------------+
void SaveTradeHistoryToFile()
{
   string filename = "trade_history_" + _Symbol + ".csv";
   int handle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
   if(handle != INVALID_HANDLE)
   {
      FileWrite(handle, "Ticket", "Symbol", "Volume", "OpenPrice", "SL", "TP", "Profit", "OpenTime", "CloseTime", "Signal");
      for(int i = 0; i < tradeHistory.Total(); i++)
      {
         TradeData *tradeData = tradeHistory.At(i);
         if(tradeData != NULL)
         {
            FileWrite(handle, 
               IntegerToString(tradeData.ticket),
               tradeData.symbol,
               DoubleToString(tradeData.volume, 2),
               DoubleToString(tradeData.openPrice, _Digits),
               DoubleToString(tradeData.sl, _Digits),
               DoubleToString(tradeData.tp, _Digits),
               DoubleToString(tradeData.profit, 2),
               TimeToString(tradeData.openTime),
               TimeToString(tradeData.closeTime),
               EnumToString(tradeData.signal)
            );
         }
      }
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//| Met à jour l'historique des trades |
//+------------------------------------------------------------------+
void UpdateTradeHistory()
{
   for(int i = 0; i < HistoryOrdersTotal(); i++)
   {
      ulong orderTicket = HistoryOrderGetTicket(i);
      if(HistoryOrderSelect(orderTicket))
      {
         if(HistoryOrderGetInteger(orderTicket, ORDER_MAGIC) == MagicBuy || HistoryOrderGetInteger(orderTicket, ORDER_MAGIC) == MagicSell)
         {
            TradeData *tradeData = new TradeData();
            tradeData.ticket = orderTicket;
            tradeData.symbol = HistoryOrderGetString(orderTicket, ORDER_SYMBOL);
            tradeData.volume = HistoryOrderGetDouble(orderTicket, ORDER_VOLUME_INITIAL);
            tradeData.openPrice = HistoryOrderGetDouble(orderTicket, ORDER_PRICE_OPEN);
            tradeData.sl = HistoryOrderGetDouble(orderTicket, ORDER_SL);
            tradeData.tp = HistoryOrderGetDouble(orderTicket, ORDER_TP);
            tradeData.profit = HistoryOrderGetDouble(orderTicket, ORDER_PROFIT);
            tradeData.openTime = (datetime)HistoryOrderGetInteger(orderTicket, ORDER_TIME_OPEN);
            tradeData.closeTime = (datetime)HistoryOrderGetInteger(orderTicket, ORDER_TIME_CLOSE);
            tradeData.signal = (HistoryOrderGetInteger(orderTicket, ORDER_TYPE) == ORDER_TYPE_BUY) ? SIGNAL_BUY : SIGNAL_SELL;
            tradeHistory.Add(tradeData);
         }
      }
   }
}
//+------------------------------------------------------------------+
