//+------------------------------------------------------------------+
//|                     TrendBreakoutEA_Advanced.mq5                 |
//|                  Copyright 2023, MetaQuotes Software Corp.      |
//|                             https://www.metaquotes.net/          |
//+------------------------------------------------------------------+
#property copyright "2023, MetaQuotes Software Corp."
#property link      "https://www.metaquotes.net/"
#property version   "2.00"
#property strict

//--- Inclusions standards
#include <Trade\Trade.mqh>
#include <Object.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\Array.mqh>
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
input int    DashboardX         = 20;           // Position X du tableau de bord
input int    DashboardY         = 20;           // Position Y du tableau de bord
input color  DashboardColor      = clrYellow;     // Couleur du tableau de bord
input int    DashboardFontSize  = 12;           // Taille de la police du tableau de bord

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
int consecutiveLosses = 0;
int consecutiveWins = 0;
double avgWin = 0.0;
double avgLoss = 0.0;
int totalTrades = 0;
int winningTrades = 0;
int losingTrades = 0;
double maxDrawdown = 0.0;
double sharpeRatio = 0.0;
double profitFactor = 0.0;
double expectancy = 0.0;

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
void CalculatePerformanceMetrics();
void CreateDashboard();
void UpdateDashboardObject(string name, string value, int x, int y);
void DeleteDashboard();
string GetTradeSignal();
void CheckForNewBar();
bool IsNewBar();
void UpdateTradeHistory();
void SaveTradeHistoryToFile();
void LoadTradeHistoryFromFile();
void CalculateStatistics();
void CheckMarginLevel();
void CheckForNewsEvents();
void UpdateGlobalVariables();
void HandleError(int errorCode);
string GetLastErrorMessage();
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result);

//+------------------------------------------------------------------+
//| Fonction d'initialisation                                       |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialisation des indicateurs
   emaHandle9 = iMA(_Symbol, _Period, 9, 0, MODE_EMA, PRICE_CLOSE);
   emaHandle21 = iMA(_Symbol, _Period, 21, 0, MODE_EMA, PRICE_CLOSE);
   emaHandle50 = iMA(_Symbol, _Period, 50, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, _Period, 14);
   atrHandle = iATR(_Symbol, _Period, 14);
   macdHandle = iMACD(_Symbol, _Period, 12, 26, 9, PRICE_CLOSE);

   //--- Initialisation du fichier de journalisation CSV
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

   //--- Initialisation de l'historique des trades
   tradeHistory = new CList();
   LoadTradeHistoryFromFile();

   //--- Création du tableau de bord
   if(EnableDashboard)
   {
      CreateDashboard();
   }

   //--- Initialisation des variables globales
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   lastTradingDay = dt.day;
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

   //--- Sauvegarde de l'historique des trades
   SaveTradeHistoryToFile();

   //--- Suppression du tableau de bord
   if(EnableDashboard)
   {
      DeleteDashboard();
   }

   //--- Libération de la mémoire
   if(tradeHistory != NULL)
   {
      delete tradeHistory;
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
   UpdateGlobalVariables();

   //--- Réinitialisation des statistiques quotidiennes si nouveau jour
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int today = dt.day;
   if(today != lastTradingDay)
   {
      ResetDailyStats();
      lastTradingDay = today;
   }

   //--- Vérification de la marge
   CheckMarginLevel();

   //--- Mise à jour du tableau de bord
   if(EnableDashboard)
   {
      UpdateDashboard();
   }

   //--- Arrêt des nouveaux trades si l'objectif journalier est atteint
   if(DailyProfitTarget > 0 && dailyProfit >= DailyProfitTarget)
   {
      SendCustomNotification("Objectif de profit journalier atteint: " + DoubleToString(DailyProfitTarget, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY));
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

   //--- Vérification des nouvelles barres
   static datetime lastBarTime = 0;
   if(IsNewBar())
   {
      lastBarTime = iTime(_Symbol, _Period, 0);
      CheckForNewsEvents();
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
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   return ((hour >= HourStart1 && hour < HourEnd1) || (hour >= HourStart2 && hour < HourEnd2));
}

//+------------------------------------------------------------------+
//| Vérifie si le spread est acceptable                             |
//+------------------------------------------------------------------+
bool IsSpreadAllowed()
{
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
   {
      spread = (long)MathRound((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point);
   }
   return (spread <= MaxSpreadPoints);
}

//+------------------------------------------------------------------+
//| Met à jour les variables globales                               |
//+------------------------------------------------------------------+
void UpdateGlobalVariables()
{
   equityPeak = MathMax(equityPeak, AccountInfoDouble(ACCOUNT_EQUITY));
   drawdown = (equityPeak - AccountInfoDouble(ACCOUNT_EQUITY)) / equityPeak * 100;
   maxDrawdown = MathMax(maxDrawdown, drawdown);
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
   {
      eaState = EA_STATE_READY;
   }
}

//+------------------------------------------------------------------+
//| Vérifie les événements de news (exemple)                        |
//+------------------------------------------------------------------+
void CheckForNewsEvents()
{
   //--- Logique pour vérifier les événements de news (à implémenter)
   //--- Exemple: Vérifier un calendrier économique ou un flux RSS
}

//+------------------------------------------------------------------+
//| Gère les positions ouvertes                                     |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(!PositionSelect(_Symbol)) continue;
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
      if(!PositionSelect(_Symbol)) continue;
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
   {
      return "BUY";
   }
   else if(downtrend && macdSell && rsi[0] < 50)
   {
      return "SELL";
   }
   else
   {
      return "HOLD";
   }
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
      {
         SendMail("TrendBreakoutEA Notification", message);
      }
   }
}

//+------------------------------------------------------------------+
//| Réinitialise les statistiques quotidiennes                      |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
   dailyProfit = 0.0;
   tradesToday = 0;
   consecutiveLosses = 0;
   consecutiveWins = 0;
   CalculateStatistics();
}

//+------------------------------------------------------------------+
//| Met à jour les statistiques de performance                      |
//+------------------------------------------------------------------+
void CalculateStatistics()
{
   if(totalTrades > 0)
   {
      avgWin = (winningTrades > 0) ? (dailyProfit / winningTrades) : 0;
      avgLoss = (losingTrades > 0) ? (dailyProfit / losingTrades) : 0;
      profitFactor = (winningTrades > 0 && losingTrades > 0) ? (avgWin / MathAbs(avgLoss)) : 0;
      expectancy = (avgWin * (winningTrades / totalTrades)) + (avgLoss * (losingTrades / totalTrades));
   }
}

//+------------------------------------------------------------------+
//| Crée le tableau de bord visuel                                  |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   dashboardObjects = new CArrayObj();
   string labels[] = {"Profit Journalier", "Trades Aujourd'hui", "Dernier Signal", "Drawdown", "Profit Factor", "Equity", "Balance", "Margin Level"};
   for(int i = 0; i < ArraySize(labels); i++)
   {
      string name = "EA_Dashboard_" + IntegerToString(i);
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, DashboardX);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, DashboardY + (i * 20));
      ObjectSetString(0, name, OBJPROP_TEXT, labels[i] + ": ");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, DashboardFontSize);
      ObjectSetInteger(0, name, OBJPROP_COLOR, DashboardColor);
      // Pas besoin d'ajouter les noms au tableau, on les générera dynamiquement
   }
}

//+------------------------------------------------------------------+
//| Met à jour un objet du tableau de bord                           |
//+------------------------------------------------------------------+
void UpdateDashboardObject(string name, string value, int x, int y)
{
   if(ObjectFind(0, name) >= 0)
   {
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, value);
   }
}

//+------------------------------------------------------------------+
//| Met à jour le tableau de bord                                    |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(dashboardObjects == NULL) return;

   UpdateDashboardObject("EA_Dashboard_0", "Profit Journalier: " + DoubleToString(dailyProfit, 2), DashboardX, DashboardY);
   UpdateDashboardObject("EA_Dashboard_1", "Trades Aujourd'hui: " + IntegerToString(tradesToday), DashboardX, DashboardY + 20);
   UpdateDashboardObject("EA_Dashboard_2", "Dernier Signal: " + lastSignal, DashboardX, DashboardY + 40);
   UpdateDashboardObject("EA_Dashboard_3", "Drawdown: " + DoubleToString(drawdown, 2) + "%", DashboardX, DashboardY + 60);
   UpdateDashboardObject("EA_Dashboard_4", "Profit Factor: " + DoubleToString(profitFactor, 2), DashboardX, DashboardY + 80);
   UpdateDashboardObject("EA_Dashboard_5", "Equity: " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2), DashboardX, DashboardY + 100);
   UpdateDashboardObject("EA_Dashboard_6", "Balance: " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), DashboardX, DashboardY + 120);
   UpdateDashboardObject("EA_Dashboard_7", "Margin Level: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_LEVEL), 2) + "%", DashboardX, DashboardY + 140);
}

//+------------------------------------------------------------------+
//| Supprime le tableau de bord                                     |
//+------------------------------------------------------------------+
void DeleteDashboard()
{
   if(dashboardObjects == NULL) return;

   // Supprimer tous les objets dashboard créés
   for(int i = 0; i < 8; i++)  // 8 objets dashboard créés dans CreateDashboard
   {
      string name = "EA_Dashboard_" + IntegerToString(i);
      ObjectDelete(0, name);
   }
   delete dashboardObjects;
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
      string timeStr = TimeToString(HistoryOrderGetInteger(orderID, ORDER_TIME_OPEN), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      string comment = HistoryOrderGetString(orderID, ORDER_COMMENT);

      FileWrite(fileHandle,
         dateStr, timeStr, sym,
         (HistoryOrderGetInteger(orderID, ORDER_TYPE) == ORDER_TYPE_BUY) ? "BUY" : "SELL",  // ORDER_TYPE == ORDER_TYPE_BUY
         vol, price, sl, tp, closePrice, profit,
         HistoryOrderGetInteger(orderID, ORDER_MAGIC),  // ORDER_MAGIC
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

      if(profit > 0)
      {
         consecutiveWins++;
         consecutiveLosses = 0;
         winningTrades++;
      }
      else if(profit < 0)
      {
         consecutiveLosses++;
         consecutiveWins = 0;
         losingTrades++;
      }

      totalTrades++;
      CalculateStatistics();
   }
}

//+------------------------------------------------------------------+
//| Sauvegarde l'historique des trades dans un fichier              |
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
         TradeData *tradeData = (TradeData*)tradeHistory.At(i);
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
//| Charge l'historique des trades depuis un fichier                |
//+------------------------------------------------------------------+
void LoadTradeHistoryFromFile()
{
   string filename = "trade_history_" + _Symbol + ".csv";
   int handle = FileOpen(filename, FILE_READ|FILE_CSV|FILE_ANSI, ',');
   if(handle != INVALID_HANDLE)
   {
      // Skip header line
      FileReadString(handle);
      
      while(!FileIsEnding(handle))
      {
         TradeData *tradeData = new TradeData();
         tradeData.ticket = StringToInteger(FileReadString(handle));
         tradeData.symbol = FileReadString(handle);
         tradeData.volume = StringToDouble(FileReadString(handle));
         tradeData.openPrice = StringToDouble(FileReadString(handle));
         tradeData.sl = StringToDouble(FileReadString(handle));
         tradeData.tp = StringToDouble(FileReadString(handle));
         tradeData.profit = StringToDouble(FileReadString(handle));
         tradeData.openTime = StringToTime(FileReadString(handle));
         tradeData.closeTime = StringToTime(FileReadString(handle));
         tradeData.signal = (ENUM_TRADE_SIGNAL)StringToInteger(FileReadString(handle));
         
         if(tradeData.ticket > 0)
            tradeHistory.Add(tradeData);
         else
            delete tradeData;
      }
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//| Met à jour l'historique des trades                              |
//+------------------------------------------------------------------+
void UpdateTradeHistory()
{
   for(int i = 0; i < HistoryOrdersTotal(); i++)
   {
      if(HistoryOrderSelect(HistoryOrderGetTicket(i)))
      {
         ulong orderTicket = HistoryOrderGetTicket(i);
         if(HistoryOrderGetInteger(orderTicket, ORDER_MAGIC) == MagicBuy || HistoryOrderGetInteger(orderTicket, ORDER_MAGIC) == MagicSell)  // ORDER_MAGIC
         {
            TradeData *tradeData = new TradeData();
            tradeData.ticket = orderTicket;
            tradeData.symbol = HistoryOrderGetString(orderTicket, ORDER_SYMBOL);  // ORDER_SYMBOL
            tradeData.volume = HistoryOrderGetDouble(orderTicket, ORDER_VOLUME_INITIAL);  // ORDER_VOLUME_INITIAL
            tradeData.openPrice = HistoryOrderGetDouble(orderTicket, ORDER_PRICE_OPEN); // ORDER_PRICE_OPEN
            tradeData.sl = HistoryOrderGetDouble(orderTicket, ORDER_SL);     // ORDER_SL
            tradeData.tp = HistoryOrderGetDouble(orderTicket, ORDER_TP);     // ORDER_TP
            tradeData.profit = HistoryOrderGetDouble(orderTicket, ORDER_PROFIT); // ORDER_PROFIT
            tradeData.openTime = HistoryOrderGetInteger(orderTicket, ORDER_TIME_OPEN);  // ORDER_TIME_OPEN
            tradeData.closeTime = HistoryOrderGetInteger(orderTicket, ORDER_TIME_CLOSE); // ORDER_TIME_CLOSE
            tradeData.signal = (HistoryOrderGetInteger(orderTicket, ORDER_TYPE) == ORDER_TYPE_BUY) ? SIGNAL_BUY : SIGNAL_SELL; // ORDER_TYPE == ORDER_TYPE_BUY
            tradeHistory.Add(tradeData);
         }
      }
   }
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
      case 0: return "Opération réussie";  // ERR_SUCCESS
      case 4001: return "Erreur commune";  // ERR_COMMON_ERROR
      case 4003: return "Paramètre invalide";  // ERR_INVALID_PARAMETER
      case 4002: return "Mémoire insuffisante";  // ERR_NOT_ENOUGH_MEMORY
      case 4005: return "Stops invalides";  // ERR_INVALID_STOPS
      case 4006: return "Volume de trade invalide";  // ERR_INVALID_TRADE_VOLUME
      case 4018: return "Marché fermé";  // ERR_MARKET_CLOSED
      case 4011: return "Pas assez d'argent";  // ERR_NO_MONEY
      case 4014: return "Trade désactivé";  // ERR_TRADE_DISABLED
      case 4015: return "Timeout du trade";  // ERR_TRADE_TIMEOUT
      case 4013: return "Prix invalide";  // ERR_INVALID_PRICE
      case 4016: return "Expiration invalide";  // ERR_INVALID_EXPIRATION
      case 4017: return "Ordre modifié";  // ERR_ORDER_CHANGED
      case 4019: return "Trop de requêtes";  // ERR_TOO_MANY_REQUESTS
      case 4020: return "Contexte de trade occupé";  // ERR_TRADE_CONTEXT_BUSY
      case 4021: return "Trop d'ordres";  // ERR_TOO_MANY_ORDERS
      case 4022: return "Serveur occupé";  // ERR_SERVER_BUSY
      case 4023: return "Compte invalide";  // ERR_INVALID_ACCOUNT
      case 4024: return "Expiration de trade refusée";  // ERR_TRADE_EXPIRATION_DENIED
      case 4025: return "Trade invalide";  // ERR_INVALID_TRADE
      case 4026: return "Type d'ordre invalide";  // ERR_INVALID_ORDER_TYPE
      case 4027: return "Mode de remplissage invalide";  // ERR_INVALID_FILLING
      default: return "Erreur inconnue " + IntegerToString(errorCode);
   }
}
//+------------------------------------------------------------------+
//| Calcule les métriques de performance                           |
//+------------------------------------------------------------------+
void CalculatePerformanceMetrics()
{
   // Calcul des métriques de performance (implémentation de base)
   if(totalTrades > 0)
   {
      // Les métriques sont déjà calculées dans CalculateStatistics()
      CalculateStatistics();
   }
}

//+------------------------------------------------------------------+
//| Vérifie les nouvelles barres                                     |
//+------------------------------------------------------------------+
void CheckForNewBar()
{
   // Cette fonction est appelée dans OnTick quand une nouvelle barre est détectée
   // Implémentation vide pour le moment
}
//+------------------------------------------------------------------+
