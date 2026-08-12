//+------------------------------------------------------------------+
//|                            F_INX_DuplicateManager.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00 - DUPLICATE MANAGER"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| PARAMÈTRES POUR GESTION DES POSITIONS DUPLIQUÉES                 |
//+------------------------------------------------------------------+
input group "=== GESTION DUPLIQUÉS ==="
input double IndividualProfitTarget = 1.0;      // Profit cible par position ($)
input double TotalProfitTarget = 2.0;            // Profit total cible ($)
input int    MaxDuplicatePositions = 5;          // Max positions dupliquées
input bool   AutoReopenAfterProfit = true;       // Réouvrir automatiquement
input double ReopenDelaySeconds = 2.0;           // Délai avant réouverture (secondes)

input group "=== LOT SIZE MANAGEMENT ==="
input double BaseLotSize = 0.01;                 // Lot de base
input double MaxLotSize = 1.0;                    // Lot maximum
input bool   UseCompoundLot = true;              // Augmenter lot après profit
input double CompoundMultiplier = 1.2;            // Multiplicateur de lot

input group "=== RISK MANAGEMENT ==="
input double StopLossPoints = 50;                // Stop Loss en points
input double TakeProfitPoints = 150;             // Take Profit en points (ratio 3:1)
input double MaxDailyLoss = 20.0;                // Perte quotidienne max
input double DailyProfitTarget = 50.0;           // Objectif profit quotidien

input group "=== DEBUG ==="
input bool   DebugMode = true;                    // Logs détaillés
input bool   ShowNotifications = true;           // Notifications MT5

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;

// Variables de gestion
static double currentLotSize = 0.01;
static double dailyProfit = 0;
static double dailyLoss = 0;
static datetime lastResetDate = 0;
static datetime lastReopenTime = 0;

// Structure pour suivre les positions dupliquées
struct DuplicatePosition {
   ulong ticket;
   double entryPrice;
   double lotSize;
   datetime openTime;
   double profitAtClose;
   bool isClosed;
};

static DuplicatePosition duplicatePositions[];

//+------------------------------------------------------------------+
//| INITIALISATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(999999);
   trade.SetDeviationInPoints(10);
   
   currentLotSize = BaseLotSize;
   ArrayResize(duplicatePositions, MaxDuplicatePositions);
   
   Print("✅ F_INX_DuplicateManager initialisé");
   Print("🎯 Profit cible individuel: ", IndividualProfitTarget, "$");
   Print("📊 Lot de base: ", BaseLotSize);
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| TICK PRINCIPAL                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   // Réinitialiser les compteurs quotidiens
   ResetDailyCounters();
   
   // Mettre à jour les compteurs
   UpdateDailyCounters();
   
   // Vérifier si le trading est autorisé
   if(!IsTradingAllowed()) return;
   
   // Vérifier et gérer les positions dupliquées
   CheckAndManageDuplicatePositions();
}

//+------------------------------------------------------------------+
//| RÉINITIALISER COMPTEURS QUOTIDIENS                               |
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
      currentLotSize = BaseLotSize;
      lastResetDate = today;
      
      // Réinitialiser les positions suivies
      for(int i = 0; i < MaxDuplicatePositions; i++)
      {
         duplicatePositions[i].ticket = 0;
         duplicatePositions[i].isClosed = false;
      }
      
      if(DebugMode) 
      {
         Print("📅 Réinitialisation quotidienne - Lot remis à: ", BaseLotSize);
      }
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
         if(position.Symbol() == _Symbol && position.Magic() == 999999)
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
   // Vérifier les limites quotidiennes
   if(dailyProfit >= DailyProfitTarget)
   {
      if(DebugMode) Print("🎯 Objectif profit quotidien atteint: ", dailyProfit, "$");
      return false;
   }
   
   if(dailyLoss >= MaxDailyLoss)
   {
      if(DebugMode) Print("🛑 Limite perte quotidienne atteinte: ", dailyLoss, "$");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| VÉRIFIER ET GÉRER LES POSITIONS DUPLIQUÉES                        |
//+------------------------------------------------------------------+
void CheckAndManageDuplicatePositions()
{
   int positionsClosed = 0;
   double totalProfitClosed = 0;
   
   // Parcourir toutes les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == 999999)
         {
            double positionProfit = position.Profit() + position.Swap() + position.Commission();
            ulong ticket = position.Ticket();
            
            // Vérifier si cette position individuelle atteint le profit cible
            if(positionProfit >= IndividualProfitTarget)
            {
               if(DebugMode)
               {
                  Print("💰 Position ", ticket, " atteint ", DoubleToString(positionProfit, 2), "$");
                  Print("🎯 Fermeture et réouverture automatique...");
               }
               
               // Fermer la position profitable
               if(trade.PositionClose(ticket))
               {
                  positionsClosed++;
                  totalProfitClosed += positionProfit;
                  
                  // Enregistrer la position fermée
                  RecordClosedPosition(ticket, positionProfit);
                  
                  // Envoyer notification
                  if(ShowNotifications)
                  {
                     string message = StringFormat("Position %d fermée à %.2f$", ticket, positionProfit);
                     SendNotification(message);
                  }
                  
                  // Réouvrir après le délai
                  if(AutoReopenAfterProfit)
                  {
                     ReopenPositionAfterDelay(position.PositionType(), position.Volume());
                  }
               }
               else
               {
                  Print("❌ Erreur fermeture position ", ticket, ": ", GetLastError());
               }
            }
         }
      }
   }
   
   // Vérifier si le profit total dépasse la cible
   double totalProfit = GetTotalProfit();
   if(totalProfit >= TotalProfitTarget && positionsClosed == 0)
   {
      if(DebugMode) Print("💰 Profit total atteint: ", DoubleToString(totalProfit, 2), "$");
      CloseAllAndReopen();
   }
   
   if(positionsClosed > 0)
   {
      if(DebugMode)
      {
         Print("🎯 Résumé - Positions fermées: ", positionsClosed);
         Print("💰 Profit total fermé: ", DoubleToString(totalProfitClosed, 2), "$");
         Print("📊 Lot size actuel: ", DoubleToString(currentLotSize, 3));
      }
      
      // Augmenter le lot size si compound activé
      if(UseCompoundLot)
      {
         IncreaseLotSize();
      }
   }
}

//+------------------------------------------------------------------+
//| ENREGISTRER POSITION FERMÉE                                       |
//+------------------------------------------------------------------+
void RecordClosedPosition(ulong ticket, double profit)
{
   for(int i = 0; i < MaxDuplicatePositions; i++)
   {
      if(duplicatePositions[i].ticket == 0 || duplicatePositions[i].isClosed)
      {
         duplicatePositions[i].ticket = ticket;
         duplicatePositions[i].profitAtClose = profit;
         duplicatePositions[i].isClosed = true;
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| ROUVRIR POSITION APRÈS DÉLAI                                      |
//+------------------------------------------------------------------+
void ReopenPositionAfterDelay(ENUM_POSITION_TYPE posType, double volume)
{
   // Vérifier le délai minimum
   if(TimeCurrent() - lastReopenTime < ReopenDelaySeconds)
   {
      if(DebugMode) Print("⏰ Délai d'attente avant réouverture...");
      return;
   }
   
   double price, sl, tp;
   
   if(posType == POSITION_TYPE_BUY)
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
   
   // Validation des distances minimales
   double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(minStopLevel > 0)
   {
      if(posType == POSITION_TYPE_BUY)
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
   
   bool result = false;
   if(posType == POSITION_TYPE_BUY)
   {
      result = SafeTradeBuy(volume, _Symbol, price, sl, tp, "Duplicate BUY");
   }
   else
   {
      result = SafeTradeSell(volume, _Symbol, price, sl, tp, "Duplicate SELL");
   }
   
   if(result)
   {
      lastReopenTime = TimeCurrent();
      if(DebugMode)
      {
         Print("🔄 Position réouverte - Type: ", posType == POSITION_TYPE_BUY ? "BUY" : "SELL");
         Print("📊 Lot: ", DoubleToString(volume, 3), " | SL: ", sl, " | TP: ", tp);
      }
   }
   else
   {
      Print("❌ Erreur réouverture: ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| FERMER TOUTES LES POSITIONS ET ROUVRIR                           |
//+------------------------------------------------------------------+
void CloseAllAndReopen()
{
   ENUM_ORDER_TYPE lastDirection = WRONG_VALUE;
   double totalVolume = 0;
   
   // Fermer toutes les positions et enregistrer la direction
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == 999999)
         {
            lastDirection = position.PositionType();
            totalVolume += position.Volume();
            
            if(!trade.PositionClose(position.Ticket()))
            {
               Print("❌ Erreur fermeture position ", position.Ticket());
            }
         }
      }
   }
   
   // Réouvrir dans la même direction si possible
   if(lastDirection != WRONG_VALUE && totalVolume > 0)
   {
      if(DebugMode) Print("🔄 Réouverture totale - Direction: ", EnumToString(lastDirection));
      ReopenPositionAfterDelay(lastDirection, totalVolume);
   }
}

//+------------------------------------------------------------------+
//| AUGMENTER LOT SIZE (COMPOUND)                                     |
//+------------------------------------------------------------------+
void IncreaseLotSize()
{
   double newLotSize = MathMin(currentLotSize * CompoundMultiplier, MaxLotSize);
   
   if(newLotSize > currentLotSize)
   {
      currentLotSize = newLotSize;
      if(DebugMode)
      {
         Print("📈 Compound activé - Nouveau lot: ", DoubleToString(currentLotSize, 3));
      }
   }
}

//+------------------------------------------------------------------+
//| CALCULER PROFIT TOTAL                                             |
//+------------------------------------------------------------------+
double GetTotalProfit()
{
   double totalProfit = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == 999999)
         {
            totalProfit += position.Profit() + position.Swap() + position.Commission();
         }
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| FONCTIONS UTILITAIRES                                            |
//+------------------------------------------------------------------+

// Ouvrir une position dupliquée manuellement
void OpenDuplicatePosition(ENUM_ORDER_TYPE orderType, double lotSize = 0)
{
   if(lotSize <= 0) lotSize = currentLotSize;
   
   double price, sl, tp;
   
   if(orderType == ORDER_TYPE_BUY)
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
   
   bool result = false;
   if(orderType == ORDER_TYPE_BUY)
   {
      result = SafeTradeBuy(lotSize, _Symbol, price, sl, tp, "Manual Duplicate BUY");
   }
   else
   {
      result = SafeTradeSell(lotSize, _Symbol, price, sl, tp, "Manual Duplicate SELL");
   }
   
   if(result)
   {
      if(DebugMode) Print("✅ Position dupliquée ouverte - Lot: ", lotSize);
   }
}

// Obtenir le nombre de positions actives
int GetActivePositionsCount()
{
   int count = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == 999999)
         {
            count++;
         }
      }
   }
   
   return count;
}

