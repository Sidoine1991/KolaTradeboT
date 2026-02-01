//+------------------------------------------------------------------+
//|                           F_INX_SmartDuplicate.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00 - SMART DUPLICATE"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| PARAMÈTRES DE GESTION INTELLIGENTE DES DUPLIQUÉS                |
//+------------------------------------------------------------------+
input group "=== GESTION DES DUPLIQUÉS ==="
input bool   EnableDuplicateManagement = true;    // Activer gestion des doublons
input bool   CloseDuplicatesAtProfit = true;       // Fermer doublons à profit
input double DuplicateProfitTarget = 1.0;         // Profit cible pour doublons
input int    MinDuplicateCount = 2;               // Nombre minimum pour considérer doublon
input bool   KeepFirstPosition = true;            // Garder la première position ouverte

input group "=== GESTION POSITIONS UNIQUES ==="
input bool   CloseUniquePositions = false;        // Fermer aussi positions uniques
input double UniqueProfitTarget = 2.0;            // Profit cible pour positions uniques
input bool   AllowUniqueCompound = true;          // Autoriser compound sur positions uniques

input group "=== STRATÉGIE DE FERMETURE ==="
input bool   CloseOldestFirst = true;             // Fermer la position la plus ancienne
input bool   CloseSmallestProfit = false;         // Fermer celle avec le plus petit profit
input bool   CloseLargestLot = false;             // Fermer celle avec le plus gros lot

input group "=== COMPOUND ET RÉOUVERTURE ==="
input bool   AutoReopen = true;                   // Réouvrir automatiquement
input double CompoundMultiplier = 1.2;           // Multiplicateur de lot
input int    ReopenDelaySeconds = 2;             // Délai avant réouverture
input bool   UsePyramiding = false;               // Ajouter positions pyramides

input group "=== DEBUG ==="
input bool   DebugMode = true;                    // Logs détaillés
input bool   ShowDuplicateLogic = true;           // Afficher logique de détection
input bool   VerboseLogging = false;              // Logging très verbeux

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;

// Variables de suivi
static datetime lastReopenTime = 0;
static int totalDuplicatesClosed = 0;
static int totalUniquesClosed = 0;
static double totalProfitFromDuplicates = 0;
static double totalProfitFromUniques = 0;

// Structure pour analyser les positions
struct PositionAnalysis {
   ulong ticket;
   ENUM_POSITION_TYPE type;
   double profit;
   double lotSize;
   datetime openTime;
   bool isDuplicate;
   int duplicateIndex;
};

static PositionAnalysis positionsArray[];

//+------------------------------------------------------------------+
//| INITIALISATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(888888);
   trade.SetDeviationInPoints(10);
   
   ArrayResize(positionsArray, 20);
   
   Print("✅ F_INX_SmartDuplicate initialisé");
   Print("🎯 Gestion doublons: ", EnableDuplicateManagement ? "ACTIVÉE" : "DÉSACTIVÉE");
   Print("📊 Profit cible doublons: ", DuplicateProfitTarget, "$");
   Print("🔢 Min doublons: ", MinDuplicateCount);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| TICK PRINCIPAL                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!EnableDuplicateManagement) return;
   
   // Analyser et gérer les positions
   AnalyzeAndManagePositions();
}

//+------------------------------------------------------------------+
//| ANALYSER ET GÉRER LES POSITIONS                                   |
//+------------------------------------------------------------------+
void AnalyzeAndManagePositions()
{
   // Réinitialiser l'array
   ArrayResize(positionsArray, 0);
   ArrayResize(positionsArray, PositionsTotal());
   
   int positionCount = 0;
   int buyCount = 0;
   int sellCount = 0;
   
   // Premier passage : collecter et analyser les positions
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         if(position.Symbol() == _Symbol && position.Magic() == 888888)
         {
            // Remplir la structure
            positionsArray[positionCount].ticket = position.Ticket();
            positionsArray[positionCount].type = position.PositionType();
            positionsArray[positionCount].profit = position.Profit() + position.Swap() + position.Commission();
            positionsArray[positionCount].lotSize = position.Volume();
            positionsArray[positionCount].openTime = position.Time();
            positionsArray[positionCount].isDuplicate = false;
            positionsArray[positionCount].duplicateIndex = -1;
            
            // Compter par type
            if(position.PositionType() == POSITION_TYPE_BUY)
               buyCount++;
            else
               sellCount++;
            
            positionCount++;
         }
      }
   }
   
   if(DebugMode)
   {
      Print("🔍 Analyse positions - Total: ", positionCount);
      Print("📈 BUY: ", buyCount, " | 📉 SELL: ", sellCount);
   }
   
   // Deuxième passage : identifier les doublons
   IdentifyDuplicates(buyCount, sellCount, positionCount);
   
   // Troisième passage : gérer les positions selon les règles
   ManagePositionsByRules(positionCount);
}

//+------------------------------------------------------------------+
//| IDENTIFIER LES DOUBLONS                                           |
//+------------------------------------------------------------------+
void IdentifyDuplicates(int buyCount, int sellCount, int totalCount)
{
   int buyIndex = 0;
   int sellIndex = 0;
   
   for(int i = 0; i < totalCount; i++)
   {
      if(positionsArray[i].type == POSITION_TYPE_BUY)
      {
         if(buyCount >= MinDuplicateCount)
         {
            positionsArray[i].isDuplicate = true;
            positionsArray[i].duplicateIndex = buyIndex;
            buyIndex++;
            
            if(ShowDuplicateLogic)
               Print("🔄 BUY #", positionsArray[i].ticket, " marqué comme doublon #", buyIndex);
         }
      }
      else // SELL
      {
         if(sellCount >= MinDuplicateCount)
         {
            positionsArray[i].isDuplicate = true;
            positionsArray[i].duplicateIndex = sellIndex;
            sellIndex++;
            
            if(ShowDuplicateLogic)
               Print("🔄 SELL #", positionsArray[i].ticket, " marqué comme doublon #", sellIndex);
         }
      }
   }
   
   if(DebugMode)
   {
      int duplicateCount = 0;
      int uniqueCount = 0;
      
      for(int i = 0; i < totalCount; i++)
      {
         if(positionsArray[i].isDuplicate)
            duplicateCount++;
         else
            uniqueCount++;
      }
      
      Print("📊 Résultat analyse:");
      Print("   Doublons: ", duplicateCount);
      Print("   Uniques: ", uniqueCount);
   }
}

//+------------------------------------------------------------------+
//| GÉRIR LES POSITIONS SELON LES RÈGLES                             |
//+------------------------------------------------------------------+
void ManagePositionsByRules(int totalCount)
{
   int duplicatesClosed = 0;
   int uniquesClosed = 0;
   double profitFromDuplicates = 0;
   double profitFromUniques = 0;
   
   // Gérer les doublons
   if(CloseDuplicatesAtProfit)
   {
      duplicatesClosed = CloseDuplicatePositions(totalCount, profitFromDuplicates);
      totalDuplicatesClosed += duplicatesClosed;
      totalProfitFromDuplicates += profitFromDuplicates;
   }
   
   // Gérer les positions uniques si activé
   if(CloseUniquePositions)
   {
      uniquesClosed = CloseUniquePositions(totalCount, profitFromUniques);
      totalUniquesClosed += uniquesClosed;
      totalProfitFromUniques += profitFromUniques;
   }
   
   // Afficher le résumé
   if(DebugMode && (duplicatesClosed > 0 || uniquesClosed > 0))
   {
      Print("🎯 Résumé gestion:");
      Print("   Doublons fermés: ", duplicatesClosed, " | Profit: ", DoubleToString(profitFromDuplicates, 2), "$");
      Print("   Uniques fermés: ", uniquesClosed, " | Profit: ", DoubleToString(profitFromUniques, 2), "$");
   }
}

//+------------------------------------------------------------------+
//| FERMER LES POSITIONS DUPLIQUÉES                                   |
//+------------------------------------------------------------------+
int CloseDuplicatePositions(int totalCount, double &totalProfit)
{
   int closed = 0;
   totalProfit = 0;
   
   // Trier les doublons selon la stratégie
   SortPositionsByStrategy(totalCount, true);
   
   for(int i = 0; i < totalCount; i++)
   {
      if(!positionsArray[i].isDuplicate) continue;
      if(positionsArray[i].profit < DuplicateProfitTarget) continue;
      
      // Si on doit garder la première position
      if(KeepFirstPosition && positionsArray[i].duplicateIndex == 0)
      {
         if(DebugMode) Print("⚠️ Premier doublon conservé - Ticket: ", positionsArray[i].ticket);
         continue;
      }
      
      // Fermer la position
      if(ClosePositionByTicket(positionsArray[i].ticket))
      {
         closed++;
         totalProfit += positionsArray[i].profit;
         
         if(DebugMode)
         {
            Print("💰 DOUBLON fermé - Ticket: ", positionsArray[i].ticket);
            Print("   Profit: ", DoubleToString(positionsArray[i].profit, 2), "$");
         }
         
         // Réouvrir si activé
         if(AutoReopen)
         {
            ENUM_ORDER_TYPE orderType = (positionsArray[i].type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            ReopenPositionDelayed(orderType, positionsArray[i].lotSize);
         }
      }
   }
   
   return closed;
}

//+------------------------------------------------------------------+
//| FERMER LES POSITIONS UNIQUES                                     |
//+------------------------------------------------------------------+
int CloseUniquePositions(int totalCount, double &totalProfit)
{
   int closed = 0;
   totalProfit = 0;
   
   // Trier les uniques selon la stratégie
   SortPositionsByStrategy(totalCount, false);
   
   for(int i = 0; i < totalCount; i++)
   {
      if(positionsArray[i].isDuplicate) continue;
      if(positionsArray[i].profit < UniqueProfitTarget) continue;
      
      // Fermer la position unique
      if(ClosePositionByTicket(positionsArray[i].ticket))
      {
         closed++;
         totalProfit += positionsArray[i].profit;
         
         if(DebugMode)
         {
            Print("💰 UNIQUE fermé - Ticket: ", positionsArray[i].ticket);
            Print("   Profit: ", DoubleToString(positionsArray[i].profit, 2), "$");
         }
         
         // Réouvrir si activé
         if(AutoReopen)
         {
            ENUM_ORDER_TYPE orderType = (positionsArray[i].type == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            ReopenPositionDelayed(orderType, positionsArray[i].lotSize);
         }
      }
   }
   
   return closed;
}

//+------------------------------------------------------------------+
//| TRIER LES POSITIONS SELON LA STRATÉGIE                           |
//+------------------------------------------------------------------+
void SortPositionsByStrategy(int totalCount, bool duplicatesOnly)
{
   // Implémentation simple du tri selon la stratégie choisie
   // Pour l'exemple, tri par profit croissant (fermer les plus petits profits d'abord)
   
   for(int i = 0; i < totalCount - 1; i++)
   {
      for(int j = i + 1; j < totalCount; j++)
      {
         // Vérifier si on doit comparer ces positions
         bool compareI = duplicatesOnly ? positionsArray[i].isDuplicate : !positionsArray[i].isDuplicate;
         bool compareJ = duplicatesOnly ? positionsArray[j].isDuplicate : !positionsArray[j].isDuplicate;
         
         if(!compareI || !compareJ) continue;
         
         // Stratégie : fermer le plus petit profit d'abord
         if(CloseSmallestProfit && positionsArray[i].profit > positionsArray[j].profit)
         {
            // Échanger
            PositionAnalysis temp = positionsArray[i];
            positionsArray[i] = positionsArray[j];
            positionsArray[j] = temp;
         }
         // Stratégie : fermer la plus ancienne d'abord
         else if(CloseOldestFirst && positionsArray[i].openTime > positionsArray[j].openTime)
         {
            // Échanger
            PositionAnalysis temp = positionsArray[i];
            positionsArray[i] = positionsArray[j];
            positionsArray[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FERMER POSITION PAR TICKET                                       |
//+------------------------------------------------------------------+
bool ClosePositionByTicket(ulong ticket)
{
   if(trade.PositionClose(ticket))
   {
      if(VerboseLogging)
         Print("✅ Position ", ticket, " fermée avec succès");
      return true;
   }
   else
   {
      Print("❌ Erreur fermeture position ", ticket, ": ", GetLastError());
      return false;
   }
}

//+------------------------------------------------------------------+
//| ROUVRIR POSITION AVEC DÉLAI                                       |
//+------------------------------------------------------------------+
void ReopenPositionDelayed(ENUM_ORDER_TYPE orderType, double volume)
{
   if(TimeCurrent() - lastReopenTime < ReopenDelaySeconds)
   {
      if(DebugMode) Print("⏰ Délai de réouverture en cours...");
      return;
   }
   
   double price, sl, tp;
   double lotSize = volume * CompoundMultiplier;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = price - 50 * _Point;
      tp = price + 150 * _Point;
   }
   else
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = price + 50 * _Point;
      tp = price - 150 * _Point;
   }
   
   bool result = false;
   if(orderType == ORDER_TYPE_BUY)
   {
      result = trade.Buy(lotSize, _Symbol, price, sl, tp, "Smart Duplicate BUY");
   }
   else
   {
      result = trade.Sell(lotSize, _Symbol, price, sl, tp, "Smart Duplicate SELL");
   }
   
   if(result)
   {
      lastReopenTime = TimeCurrent();
      if(DebugMode)
      {
         Print("🔄 Position réouverte - Type: ", EnumToString(orderType));
         Print("📊 Lot: ", DoubleToString(lotSize, 3), " (x", CompoundMultiplier, ")");
      }
   }
}

//+------------------------------------------------------------------+
//| OBTENIR STATISTIQUES                                             |
//+------------------------------------------------------------------+
void PrintStatistics()
{
   Print("📊 STATISTIQUES SMART DUPLICATE:");
   Print("   Doublons fermés (total): ", totalDuplicatesClosed);
   Print("   Uniques fermés (total): ", totalUniquesClosed);
   Print("   Profit doublons: ", DoubleToString(totalProfitFromDuplicates, 2), "$");
   Print("   Profit uniques: ", DoubleToString(totalProfitFromUniques, 2), "$");
   Print("   Profit total: ", DoubleToString(totalProfitFromDuplicates + totalProfitFromUniques, 2), "$");
}

//+------------------------------------------------------------------+
//| FONCTIONS DE CONFIGURATION                                       |
//+------------------------------------------------------------------+

// Activer/Désactiver la gestion des doublons
void SetDuplicateManagement(bool enabled)
{
   EnableDuplicateManagement = enabled;
   Print("🔧 Gestion doublons ", enabled ? "ACTIVÉE" : "DÉSACTIVÉE");
}

// Changer le profit cible pour doublons
void SetDuplicateProfitTarget(double target)
{
   DuplicateProfitTarget = target;
   Print("🎯 Profit cible doublons: ", target, "$");
}

// Changer le profit cible pour uniques
void SetUniqueProfitTarget(double target)
{
   UniqueProfitTarget = target;
   Print("🎯 Profit cible uniques: ", target, "$");
}

// Activer/Désactiver la fermeture des uniques
void SetUniqueClosing(bool enabled)
{
   CloseUniquePositions = enabled;
   Print("🔧 Fermeture uniques ", enabled ? "ACTIVÉE" : "DÉSACTIVÉE");
}
