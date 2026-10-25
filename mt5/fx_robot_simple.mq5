//+------------------------------------------------------------------+
//| Fx_robot_simple - Robot de trading M5 avec gestion du risque     |
//| - Seulement opportunités de long terme (buy/sell) en M5          |
//| - Gestion du risque : 3$ max par position                        |
//| - Maximum 2 positions ouvertes simultanément                     |
//| - Ordres limites pour les autres signaux                         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Arrays\ArrayObj.mqh>

//--- Paramètres du robot
input double InpMaxRiskPerTrade = 3.0;     // Risque max par trade (en $)
input int    InpMaxOpenPositions = 2;      // Nombre max de positions ouvertes
input int    InpMagicNumber = 20251115;    // Magic Number pour identifier nos trades
input int    InpSlippage = 3;              // Slippage en points
input bool   InpEnableTrading = true;      // Activer le trading
input bool   InpShowAlerts = true;         // Afficher les alertes

//--- Paramètres des indicateurs
input int      InpEmaFastPeriod  = 20;     // Période EMA rapide
input int      InpEmaSlowPeriod  = 50;     // Période EMA lente
input int      InpAtrPeriod      = 14;     // Période ATR pour le stop loss
input double   InpAtrMultiplier  = 2.0;    // Multiplicateur ATR pour le stop loss
input double   InpRiskReward     = 2.0;    // Ratio risque/récompense

//--- Paramètres avancés
input group "=== PARAMETRES AVANCES ==="
input ENUM_ORDER_TYPE_FILLING InpOrderFilling = ORDER_FILLING_FOK;  // Type d'exécution des ordres
input bool   InpCloseOnOppositeSignal = true;  // Fermer les positions sur signal opposé
input bool   InpUseTrailingStop = false;       // Activer le trailing stop
input int    InpTrailingStop = 100;            // Distance du trailing stop (en points)
input int    InpTrailingStep = 50;             // Pas du trailing stop (en points)

//--- Handles des indicateurs
int g_emaFastHandle = INVALID_HANDLE;
int g_emaSlowHandle = INVALID_HANDLE;
int g_atrHandle = INVALID_HANDLE;

//--- Objets de trading
CTrade trade;
CPositionInfo positionInfo;

//--- Variables globales
datetime g_lastBarTime = 0;
int g_openPositions = 0;

//--- Structure pour les ordres en attente
struct PendingOrder {
   string symbol;
   double price;
   double sl;
   double tp;
   double lots;
   ENUM_ORDER_TYPE type;
   datetime expiration;
};

CArrayObj *g_pendingOrders;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Fx_robot_simple - Initialisation...");
   
   // Initialisation des indicateurs
   g_emaFastHandle = iMA(_Symbol, PERIOD_M5, InpEmaFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_emaSlowHandle = iMA(_Symbol, PERIOD_M5, InpEmaSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   g_atrHandle = iATR(_Symbol, PERIOD_M5, InpAtrPeriod);
   
   // Vérification des handles
   if(g_emaFastHandle == INVALID_HANDLE || g_emaSlowHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création des indicateurs");
      return(INIT_FAILED);
   }
   
   // Initialisation du tableau des ordres en attente
   g_pendingOrders = new CArrayObj();
   
   // Configuration du trade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetMarginMode();
   trade.SetTypeFilling(InpOrderFilling);
   
   // Afficher les paramètres
   Print("=== Robot de trading M5 initialisé ===");
   Print("Risque max par trade: ", InpMaxRiskPerTrade, " $");
   Print("Max positions ouvertes: ", InpMaxOpenPositions);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Libérer les handles des indicateurs
   if(g_emaFastHandle != INVALID_HANDLE) 
      IndicatorRelease(g_emaFastHandle);
   if(g_emaSlowHandle != INVALID_HANDLE) 
      IndicatorRelease(g_emaSlowHandle);
   if(g_atrHandle != INVALID_HANDLE) 
      IndicatorRelease(g_atrHandle);
   
   // Nettoyer les objets graphiques
   ObjectsDeleteAll(0, 0, -1);
   
   // Supprimer le tableau des ordres en attente
   if(CheckPointer(g_pendingOrders) == POINTER_DYNAMIC)
   {
      g_pendingOrders.Clear();
      delete g_pendingOrders;
   }
   
   Print("Robot arrêté - Raison: ", GetUninitReasonText(reason));
}

//+------------------------------------------------------------------+
//| Vérifie si c'est une nouvelle bougie                             |
//+------------------------------------------------------------------+
bool IsNewBar(ENUM_TIMEFRAMES timeframe)
{
   datetime currentBarTime = iTime(_Symbol, timeframe, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Met à jour le nombre de positions ouvertes                       |
//+------------------------------------------------------------------+
void UpdateOpenPositions()
{
   int total = PositionsTotal();
   g_openPositions = 0;
   
   for(int i = total-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            g_openPositions++;
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie les opportunités de trading                              |
//+------------------------------------------------------------------+
void CheckTradingOpportunity()
{
   // Vérifier si le trading est activé et que nous n'avons pas atteint le nombre max de positions
   if(!InpEnableTrading || g_openPositions >= InpMaxOpenPositions)
      return;
   
   // Récupérer les valeurs des indicateurs
   double emaFast[2], emaSlow[2], atr[1];
   
   if(CopyBuffer(g_emaFastHandle, 0, 0, 2, emaFast) <= 0 ||
      CopyBuffer(g_emaSlowHandle, 0, 0, 2, emaSlow) <= 0 ||
      CopyBuffer(g_atrHandle, 0, 0, 1, atr) <= 0)
   {
      Print("Erreur lors de la copie des données des indicateurs");
      return;
   }
   
   // Vérifier les croisements de moyennes mobiles
   bool buySignal = (emaFast[1] <= emaSlow[1] && emaFast[0] > emaSlow[0]);
   bool sellSignal = (emaFast[1] >= emaSlow[1] && emaFast[0] < emaSlow[0]);
   
   // Si pas de signal, on sort
   if(!buySignal && !sellSignal)
      return;
   
   // Calculer le risque et la taille de position
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Calculer le stop loss et take profit
   double atrValue = atr[0];
   double slPoints = atrValue * InpAtrMultiplier / point;
   double tpPoints = slPoints * InpRiskReward;
   
   // Calculer la taille de position basée sur le risque
   double riskAmount = InpMaxRiskPerTrade;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   double riskPerLot = slPoints * point * tickValue / tickSize;
   double lots = NormalizeDouble(riskAmount / riskPerLot, 2);
   
   // Ajuster la taille du lot selon les limites du broker
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   
   if(lots < minLot)
   {
      Print("Taille de position trop petite: ", lots, " (min: ", minLot, ")");
      return;
   }
   
   // Exécuter le trade
   if(buySignal)
   {
      double sl = bid - slPoints * point;
      double tp = bid + tpPoints * point;
      
      if(g_openPositions < InpMaxOpenPositions)
      {
         // Fermer les positions vendeuses si nécessaire
         if(InpCloseOnOppositeSignal)
            CloseAllPositions(POSITION_TYPE_SELL);
            
         // Ouvrir une position d'achat
         if(trade.Buy(lots, _Symbol, 0, sl, tp, "M5 Long"))
         {
            if(InpShowAlerts)
               Alert("Achat ", _Symbol, " ", lots, " lots à ", ask, " SL:", sl, " TP:", tp);
         }
      }
      else
      {
         // Ajouter un ordre limite
         AddPendingOrder(ORDER_TYPE_BUY_LIMIT, ask, sl, tp, lots);
      }
   }
   else if(sellSignal)
   {
      double sl = ask + slPoints * point;
      double tp = ask - tpPoints * point;
      
      if(g_openPositions < InpMaxOpenPositions)
      {
         // Fermer les positions acheteuses si nécessaire
         if(InpCloseOnOppositeSignal)
            CloseAllPositions(POSITION_TYPE_BUY);
            
         // Ouvrir une position de vente
         if(trade.Sell(lots, _Symbol, 0, sl, tp, "M5 Short"))
         {
            if(InpShowAlerts)
               Alert("Vente ", _Symbol, " ", lots, " lots à ", bid, " SL:", sl, " TP:", tp);
         }
      }
      else
      {
         // Ajouter un ordre limite
         AddPendingOrder(ORDER_TYPE_SELL_LIMIT, bid, sl, tp, lots);
      }
   }
}

//+------------------------------------------------------------------+
//| Ferme toutes les positions d'un type donné                       |
//+------------------------------------------------------------------+
void CloseAllPositions(ENUM_POSITION_TYPE positionType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && 
            PositionGetInteger(POSITION_TYPE) == positionType)
         {
            trade.PositionClose(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Ajoute un ordre en attente                                       |
//+------------------------------------------------------------------+
void AddPendingOrder(ENUM_ORDER_TYPE type, double price, double sl, double tp, double lots)
{
   PendingOrder *order = new PendingOrder();
   order.symbol = _Symbol;
   order.price = price;
   order.sl = sl;
   order.tp = tp;
   order.lots = lots;
   order.type = type;
   order.expiration = TimeCurrent() + PERIOD_M5 * 60; // Expire à la fin de la bougie actuelle
   
   g_pendingOrders.Add(order);
   
   if(InpShowAlerts)
      Print("Ordre ", EnumToString(type), " ajouté pour ", _Symbol, " à ", price);
}

//+------------------------------------------------------------------+
//| Vérifie les ordres en attente                                    |
//+------------------------------------------------------------------+
void CheckPendingOrders()
{
   datetime currentTime = TimeCurrent();
   
   for(int i = g_pendingOrders.Total()-1; i >= 0; i--)
   {
      PendingOrder *order = g_pendingOrders.At(i);
      
      // Vérifier l'expiration
      if(currentTime >= order.expiration)
      {
         g_pendingOrders.Delete(i);
         delete order;
         continue;
      }
      
      // Vérifier si le prix a été touché
      double currentBid = SymbolInfoDouble(order.symbol, SYMBOL_BID);
      double currentAsk = SymbolInfoDouble(order.symbol, SYMBOL_ASK);
      
      bool priceReached = false;
      
      if(order.type == ORDER_TYPE_BUY_LIMIT && currentAsk <= order.price)
         priceReached = true;
      else if(order.type == ORDER_TYPE_SELL_LIMIT && currentBid >= order.price)
         priceReached = true;
      
      if(priceReached && g_openPositions < InpMaxOpenPositions)
      {
         // Exécuter l'ordre
         if(order.type == ORDER_TYPE_BUY_LIMIT)
            trade.Buy(order.lots, order.symbol, 0, order.sl, order.tp, "M5 Long (Limite)");
         else if(order.type == ORDER_TYPE_SELL_LIMIT)
            trade.Sell(order.lots, order.symbol, 0, order.sl, order.tp, "M5 Short (Limite)");
         
         // Supprimer l'ordre traité
         g_pendingOrders.Delete(i);
         delete order;
      }
   }
}

//+------------------------------------------------------------------+
//| Gestion du trailing stop                                         |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!InpUseTrailingStop) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         double currentStopLoss = PositionGetDouble(POSITION_SL);
         double currentPrice = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 
                              SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                              SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         double newStopLoss = 0;
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            newStopLoss = currentPrice - InpTrailingStop * point;
            if(newStopLoss > currentStopLoss + InpTrailingStep * point)
            {
               trade.PositionModify(ticket, newStopLoss, PositionGetDouble(POSITION_TP));
            }
         }
         else
         {
            newStopLoss = currentPrice + InpTrailingStop * point;
            if(newStopLoss < currentStopLoss - InpTrailingStep * point || currentStopLoss == 0)
            {
               trade.PositionModify(ticket, newStopLoss, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérifier si nous sommes sur une nouvelle bougie M5
   if(!IsNewBar(PERIOD_M5)) 
   {
      // Gérer le trailing stop à chaque tick si activé
      if(InpUseTrailingStop)
         ManageTrailingStop();
      return;
   }
   
   // Mettre à jour le nombre de positions ouvertes
   UpdateOpenPositions();
   
   // Vérifier les opportunités de trading
   CheckTradingOpportunity();
   
   // Vérifier les ordres en attente
   CheckPendingOrders();
}
