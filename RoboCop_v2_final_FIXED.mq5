//+------------------------------------------------------------------+
//|                     RoboCop_V2_Final.mq5                         |
//|                  Copyright 2025, Sidoine & Grok/xAI              |
//|                             https://x.ai/                         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Sidoine & Grok/xAI"
#property link      "https://x.ai/"
#property version   "2.00"
#property strict

//--- Inclusion standard
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>

//--- Déclaration de l'objet Trade
CTrade trade;

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

//--- Structure pour stocker les données des trades
struct TradeData
{
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
};

//+------------------------------------------------------------------+
//| Paramètres d'entrée                                              |
//+------------------------------------------------------------------+
input double RiskPercent        = 1.0;          // % de risque par trade
input double FixedLot           = 0.1;          // Lot fixe si activé
input bool   UseFixedLot        = false;        // Utiliser lot fixe
input int    TrailingStart      = 100;          // Points pour démarrer le trailing (pips)
input int    TrailingStep       = 50;           // Points de trailing step (pips)
input int    BreakevenStart     = 100;          // Points pour passer en breakeven
input double AdxThreshold       = 20.0;         // Seuil ADX pour confirmer la tendance
input int    BreakoutPeriod     = 20;           // Période pour calculer le breakout
input double ATRMultiplier      = 1.5;          // Multiplicateur ATR pour calculer le SL
input double RiskReward         = 2.0;          // Ratio Risque/Rendement pour calculer le TP
input int    MagicBuy           = 20231201;     // Magic Number pour les achats
input int    MagicSell          = 20231202;     // Magic Number pour les ventes
input int    HourStart1         = 8;            // Heure de début de trading (session 1)
input int    HourEnd1           = 11;           // Heure de fin de trading (session 1)
input int    HourStart2         = 13;           // Heure de début de trading (session 2)
input int    HourEnd2           = 17;           // Heure de fin de trading (session 2)
input int    MaxSpreadPoints    = 20;           // Spread maximum autorisé (en points)
input double DailyProfitTarget  = 100.0;        // Objectif de profit journalier
input bool   EnableNotifications= true;         // Activer les notifications
input string NotificationEmail  = "";           // Email pour les notifications
input bool   EnableCSVLogging   = true;         // Activer la journalisation CSV
input bool   EnableDashboard    = true;         // Activer le tableau de bord visuel

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
double equityPeak = 0.0;
double drawdown = 0.0;

//+------------------------------------------------------------------+
//| Déclaration des fonctions                                       |
//+------------------------------------------------------------------+
bool IsAllowedHour();
bool IsSpreadAllowed();
void UpdateDashboard();
void ManageOpenPositions();
double CalculateLot(bool isBuy, double stopDistance);
void OpenBuyOrder();
void OpenSellOrder();
void CloseAllPositions();
void LogTradeToFile(ulong orderID);
void UpdateDailyStatsFromDeal(ulong dealID);
void ResetDailyStats();
void SendCustomNotification(string message);
void CheckMarginLevel();
string GetTradeSignal();
bool IsNewBar();
void HandleError(int errorCode);
string GetLastErrorMessage();
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);

//+------------------------------------------------------------------+
//| Fonction d'initialisation                                       |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialisation des indicateurs
   emaHandle9  = iMA(_Symbol, _Period, 9,  0, MODE_EMA, PRICE_CLOSE);
   emaHandle21 = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
   emaHandle50 = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle   = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   adxHandle   = iADX(_Symbol, _Period, 14);
   atrHandle   = iATR(_Symbol, _Period, 14);
   macdHandle  = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);

   //--- Initialisation du fichier de journalisation CSV
   if(EnableCSVLogging)
   {
      string filename = "trades_log_" + _Symbol + ".csv";
      fileHandle = FileOpen(filename, FILE_WRITE|FILE_CSV|FILE_ANSI, ',');
      if(fileHandle == INVALID_HANDLE)
      {
         Print("Échec de l'ouverture du fichier CSV: ", GetLastError());
      }
      else
      {
         FileWrite(fileHandle, "Date", "Heure", "Symbole", "Type", "Lot", "Prix Ouverture", "SL", "TP", "Prix Fermeture", "Profit", "Magic", "Signal");
      }
   }

   //--- Initialisation des variables globales
   lastTradingDay = TimeDay(TimeCurrent());
   eaState = EA_STATE_READY;

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Fonction de désinitialisation                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Libération des indicateurs
   IndicatorRelease(emaHandle9);
   IndicatorRelease(emaHandle21);
   IndicatorRelease(emaHandle50);
   IndicatorRelease(rsiHandle);
   IndicatorRelease(adxHandle);
   IndicatorRelease(atrHandle);
   IndicatorRelease(macdHandle);

   //--- Fermeture du fichier CSV
   if(fileHandle != INVALID_HANDLE)
   {
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Fonction principale du tick                                    |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Vérification de l'état de l'EA
   if(eaState == EA_STATE_ERROR)
   {
      HandleError(GetLastError());
      return;
   }

   //--- Mise à jour des variables globales
   equityPeak = MathMax(equityPeak, AccountInfoDouble(ACCOUNT_EQUITY));
   drawdown = (equityPeak - AccountInfoDouble(ACCOUNT_EQUITY)) / equityPeak * 100;

   //--- Réinitialisation des statistiques quotidiennes si nouveau jour
   int today = TimeDay(TimeCurrent());
   if(today != lastTradingDay)
   {
      ResetDailyStats();
      lastTradingDay = today;
   }

   //--- Vérification de la marge
   CheckMarginLevel();

   //--- Mise à jour du tableau de bord
   UpdateDashboard();

   //--- Arrêt des nouveaux trades si l'objectif journalier est atteint
   if(DailyProfitTarget > 0 && dailyProfit >= DailyProfitTarget)
   {
      SendCustomNotification("Objectif de profit journalier atteint: " + DoubleToString(DailyProfitTarget, 2));
      return;
   }

   //--- Vérification des heures de trading et du spread
   if(!IsAllowedHour() || !IsSpreadAllowed())
   {
      return;
   }

   //--- Gestion des positions ouvertes
   ManageOpenPositions();

   //--- Détection des nouveaux signaux de trading
   string signal = GetTradeSignal();
   if(signal == "BUY" && lastSignal != "BUY")
   {
      OpenBuyOrder();
      lastSignal = "BUY";
   }
   else if(signal == "SELL" && lastSignal != "SELL")
   {
      OpenSellOrder();
      lastSignal = "SELL";
   }
}

//+------------------------------------------------------------------+
//| Vérifie si une nouvelle barre est formée                        |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(lastBarTime != currentBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie les heures de trading autorisées                        |
//+------------------------------------------------------------------+
bool IsAllowedHour()
{
   int hour = TimeHour(TimeCurrent());
   return ((hour >= HourStart1 && hour < HourEnd1) || (hour >= HourStart2 && hour < HourEnd2));
}

//+------------------------------------------------------------------+
//| Vérifie si le spread est acceptable                             |
//+------------------------------------------------------------------+
bool IsSpreadAllowed()
{
   long spread;
   if(!SymbolInfoInteger(_Symbol, SYMBOL_SPREAD, spread))
   {
      spread = (long)MathRound((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point);
   }
   return (spread <= MaxSpreadPoints);
}

//+------------------------------------------------------------------+
//| Met à jour le tableau de bord                                    |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(!EnableDashboard) return;

   string dashboardText =
      "Profit Journalier: " + DoubleToString(dailyProfit, 2) + "\n" +
      "Trades Aujourd'hui: " + IntegerToString(tradesToday) + "\n" +
      "Dernier Signal: " + lastSignal + "\n" +
      "Drawdown: " + DoubleToString(drawdown, 2) + "%\n" +
      "Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);

   if(ObjectFind(0, "EA_Dashboard") < 0)
   {
      ObjectCreate(0, "EA_Dashboard", OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, "EA_Dashboard", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "EA_Dashboard", OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, "EA_Dashboard", OBJPROP_YDISTANCE, 20);
   }
   ObjectSetString(0, "EA_Dashboard", OBJPROP_TEXT, dashboardText);
}

//+------------------------------------------------------------------+
//| Gère les positions ouvertes                                     |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByIndex(i)) continue;
      ulong ticket = PositionGetTicket(i);
      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != MagicBuy && magic != MagicSell) continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      //--- Trailing Stop
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

      //--- Breakeven
      if(type == POSITION_TYPE_BUY && SymbolInfoDouble(_Symbol, SYMBOL_BID) - entry >= BreakevenStart * _Point)
      {
         if(entry > sl)
         {
            trade.PositionModify(ticket, entry, tp);
         }
      }
      else if(type == POSITION_TYPE_SELL && entry - SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= BreakevenStart * _Point)
      {
         if(entry < sl || sl == 0)
         {
            trade.PositionModify(ticket, entry, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calcule le lot en fonction du risque                            |
//+------------------------------------------------------------------+
double CalculateLot(bool isBuy, double stopDistance)
{
   double lot = FixedLot;
   if(!UseFixedLot)
   {
      double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100.0;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      lot = riskAmount / (stopDistance * tickValue * tickSize);
      lot = NormalizeDouble(lot, 2);
   }

   //--- Vérification des limites de lot
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   lot = MathFloor(lot / lotStep) * lotStep;

   return lot;
}

//+------------------------------------------------------------------+
//| Ouvre un ordre d'achat                                          |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
   {
      Print("Erreur de copie du buffer ATR");
      return;
   }

   double sl = ask - atr[0] * ATRMultiplier * _Point;
   double tp = ask + atr[0] * ATRMultiplier * RiskReward * _Point;
   double stopDistance = (ask - sl) / _Point;
   double lot = CalculateLot(true, stopDistance);

   trade.SetExpertMagicNumber(MagicBuy);
   if(trade.Buy(lot, _Symbol, ask, sl, tp, "EA Buy Order"))
   {
      lastSignal = "BUY";
      lastTradeTime = TimeCurrent();
      SendCustomNotification("Nouvel ordre d'achat ouvert: " + DoubleToString(lot, 2) + " lots @ " + DoubleToString(ask, _Digits));
   }
   else
   {
      Print("Erreur d'ouverture d'ordre d'achat: ", GetLastError());
      HandleError(GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Ouvre un ordre de vente                                         |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
   {
      Print("Erreur de copie du buffer ATR");
      return;
   }

   double sl = bid + atr[0] * ATRMultiplier * _Point;
   double tp = bid - atr[0] * ATRMultiplier * RiskReward * _Point;
   double stopDistance = (sl - bid) / _Point;
   double lot = CalculateLot(false, stopDistance);

   trade.SetExpertMagicNumber(MagicSell);
   if(trade.Sell(lot, _Symbol, bid, sl, tp, "EA Sell Order"))
   {
      lastSignal = "SELL";
      lastTradeTime = TimeCurrent();
      SendCustomNotification("Nouvel ordre de vente ouvert: " + DoubleToString(lot, 2) + " lots @ " + DoubleToString(bid, _Digits));
   }
   else
   {
      Print("Erreur d'ouverture d'ordre de vente: ", GetLastError());
      HandleError(GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Ferme toutes les positions                                      |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByIndex(i)) continue;
      ulong ticket = PositionGetTicket(i);
      trade.PositionClose(ticket);
   }
   SendCustomNotification("Toutes les positions ont été fermées");
}

//+------------------------------------------------------------------+
//| Détermine le signal de trading                                  |
//+------------------------------------------------------------------+
string GetTradeSignal()
{
   double ema9[1], ema21[1], ema50[1], rsi[1], adx[1], atr[1], macd[2];
   CopyBuffer(emaHandle9, 0, 0, 1, ema9);
   CopyBuffer(emaHandle21, 0, 0, 1, ema21);
   CopyBuffer(emaHandle50, 0, 0, 1, ema50);
   CopyBuffer(rsiHandle, 0, 0, 1, rsi);
   CopyBuffer(adxHandle, 0, 0, 1, adx);
   CopyBuffer(macdHandle, 0, 0, 2, macd);

   bool uptrend = (ema9[0] > ema21[0] && ema21[0] > ema50[0] && adx[0] > AdxThreshold);
   bool downtrend = (ema9[0] < ema21[0] && ema21[0] < ema50[0] && adx[0] > AdxThreshold);
   bool macdBuy = (macd[0] > 0 && macd[0] > macd[1]);
   bool macdSell = (macd[0] < 0 && macd[0] < macd[1]);

   if(uptrend && macdBuy && rsi[0] > 50)
      return "BUY";
   else if(downtrend && macdSell && rsi[0] < 50)
      return "SELL";
   else
      return "HOLD";
}

//+------------------------------------------------------------------+
//| Envoie une notification                                         |
//+------------------------------------------------------------------+
void SendCustomNotification(string message)
{
   if(EnableNotifications)
   {
      Print(message);
      Alert(message);
      if(NotificationEmail != "")
         SendMail("RoboCop EA Notification", message);
   }
}

//+------------------------------------------------------------------+
//| Réinitialise les statistiques quotidiennes                      |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
   dailyProfit = 0.0;
   tradesToday = 0;
}

//+------------------------------------------------------------------+
//| Vérifie le niveau de marge                                      |
//+------------------------------------------------------------------+
void CheckMarginLevel()
{
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   if(marginLevel < 50.0)
   {
      SendCustomNotification("Alerte: Niveau de marge bas (" + DoubleToString(marginLevel, 2) + "%)");
      CloseAllPositions();
      eaState = EA_STATE_PAUSED;
   }
   else if(marginLevel < 100.0 && eaState == EA_STATE_PAUSED)
      eaState = EA_STATE_READY;
}

//+------------------------------------------------------------------+
//| Gère les erreurs                                                |
//+------------------------------------------------------------------+
void HandleError(int errorCode)
{
   string errorMessage = "Erreur " + IntegerToString(errorCode) + ": " + GetLastErrorMessage();
   Print(errorMessage);
   SendCustomNotification(errorMessage);
   eaState = EA_STATE_ERROR;
}

//+------------------------------------------------------------------+
//| Obtient le message d'erreur pour le dernier code d'erreur       |
//+------------------------------------------------------------------+
string GetLastErrorMessage()
{
   int errorCode = GetLastError();
   ResetLastError();

   switch(errorCode)
   {
      case 0: return "Opération réussie";
      case 4001: return "Erreur commune";
      case 4003: return "Paramètre invalide";
      case 4002: return "Mémoire insuffisante";
      case 4005: return "Stops invalides";
      case 4006: return "Volume de trade invalide";
      case 4018: return "Marché fermé";
      case 4011: return "Pas assez d'argent";
      case 4014: return "Trade désactivé";
      case 4015: return "Timeout du trade";
      case 4013: return "Prix invalide";
      case 4016: return "Expiration invalide";
      case 4017: return "Ordre modifié";
      case 4019: return "Trop de requêtes";
      case 4020: return "Contexte de trade occupé";
      case 4021: return "Trop d'ordres";
      case 4022: return "Serveur occupé";
      case 4023: return "Compte invalide";
      case 4024: return "Expiration de trade refusée";
      case 4025: return "Trade invalide";
      case 4026: return "Type d'ordre invalide";
      case 4027: return "Mode de remplissage invalide";
      default: return "Erreur inconnue " + IntegerToString(errorCode);
   }
}

//+------------------------------------------------------------------+
//| Enregistre un trade dans le fichier CSV                         |
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
      string timeStr = dateStr;
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
//| Met à jour les statistiques après un deal                       |
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
//| Gestion des transactions commerciales                            |
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
