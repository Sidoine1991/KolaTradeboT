//+------------------------------------------------------------------+
//|                        Test_Priority_Close.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00 - PRIORITY CLOSE TEST"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| PARAMÈTRES DE TEST PRIORITAIRE                                    |
//+------------------------------------------------------------------+
input group "=== PRIORITÉ ABSOLUE ==="
input double ProfitTarget1 = 1.0;              // Premier objectif de profit
input double ProfitTarget2 = 2.0;              // Deuxième objectif de profit
input bool   ForceCloseAll = true;             // Forcer fermeture de tout
input bool   EnableNotifications = true;        // Notifications MT5
input int    CheckIntervalMs = 500;             // Vérification toutes les 500ms

input group "=== DEBUG ==="
input bool   VerboseMode = true;               // Mode verbeux
input bool   ShowAllPositions = true;          // Afficher toutes les positions

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;

static datetime lastCheckTime = 0;
static int totalChecks = 0;
static int totalCloses = 0;
static double totalProfitSecured = 0;

//+------------------------------------------------------------------+
//| INITIALISATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(777777);
   trade.SetDeviationInPoints(10);
   
   Print("🚨 TEST PRIORITÉ ABSOLUE - INITIALISÉ");
   Print("🎯 Cibles: ", ProfitTarget1, "$ et ", ProfitTarget2, "$");
   Print("⚡ ForceCloseAll: ", ForceCloseAll ? "OUI" : "NON");
   Print("📊 Vérification toutes les ", CheckIntervalMs, "ms");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| TICK PRINCIPAL                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérification très fréquente pour priorité absolue
   if(TimeCurrent() * 1000 - lastCheckTime >= CheckIntervalMs)
   {
      lastCheckTime = TimeCurrent();
      totalChecks++;
      
      // FONCTION PRIORITAIRE ABSOLUE
      PriorityCloseCheck();
   }
}

//+------------------------------------------------------------------+
//| VÉRIFICATION PRIORITAIRE ABSOLUE                                 |
//+------------------------------------------------------------------+
void PriorityCloseCheck()
{
   int positionsToClose = 0;
   double totalProfit = 0;
   
   if(VerboseMode)
   {
      Print("🔍 PRIORITÉ ABSOLUE - Check #", totalChecks);
      Print("📊 Positions actuelles: ", PositionsTotal());
   }
   
   // Analyser toutes les positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         double profit = position.Profit() + position.Swap() + position.Commission();
         ulong ticket = position.Ticket();
         ENUM_POSITION_TYPE posType = position.PositionType();
         double volume = position.Volume();
         
         if(ShowAllPositions || profit >= ProfitTarget1)
         {
            Print("📋 Position #", ticket);
            Print("   Type: ", EnumToString(posType));
            Print("   Volume: ", DoubleToString(volume, 3));
            Print("   Profit: ", DoubleToString(profit, 2), "$");
            Print("   ──────────────────────────");
         }
         
         // VÉRIFICATION PRIORITAIRE ABSOLUE
         if(profit >= ProfitTarget1)
         {
            positionsToClose++;
            totalProfit += profit;
            
            Print("💰 POSITION À FERMER PRIORITAIREMENT !");
            Print("   Ticket: ", ticket);
            Print("   Profit: ", DoubleToString(profit, 2), "$ (>= ", ProfitTarget1, "$)");
            
            // FERMETURE IMMÉDIATE ET FORCÉE
            if(ForceClosePosition(ticket))
            {
               totalCloses++;
               totalProfitSecured += profit;
               
               Print("✅ POSITION FERMÉE AVEC SUCCÈS !");
               Print("   Ticket: ", ticket);
               Print("   Profit sécurisé: ", DoubleToString(profit, 2), "$");
               
               // Notification immédiate
               if(EnableNotifications)
               {
                  string message = StringFormat("PRIORITÉ: Position %d fermée à %.2f$", ticket, profit);
                  SendNotification(message);
               }
               
               // Réouvrir immédiatement si nécessaire
               ReopenImmediately(posType, volume);
            }
            else
            {
               Print("❌ ERREUR FERMETURE PRIORITAIRE !");
               Print("   Ticket: ", ticket);
               Print("   Erreur: ", GetLastError());
            }
         }
      }
   }
   
   // Résumé de la vérification prioritaire
   if(positionsToClose > 0)
   {
      Print("🎯 RÉSUMÉ PRIORITAIRE:");
      Print("   Positions fermées: ", positionsToClose);
      Print("   Profit total: ", DoubleToString(totalProfit, 2), "$");
      Print("   ⚡ GAINS SÉCURISÉS - SORTIE RAPIDE !");
   }
   else if(VerboseMode)
   {
      Print("⏸️ Aucune position n'atteint la cible de ", ProfitTarget1, "$");
   }
}

//+------------------------------------------------------------------+
//| FORCER LA FERMETURE D'UNE POSITION                              |
//+------------------------------------------------------------------+
bool ForceClosePosition(ulong ticket)
{
   // Première tentative
   if(trade.PositionClose(ticket))
   {
      return true;
   }
   
   // Deuxième tentative immédiate
   Print("🔄 Deuxième tentative de fermeture...");
   Sleep(50);
   if(trade.PositionClose(ticket))
   {
      return true;
   }
   
   // Troisième tentative avec retry
   Print("🔄 Troisième tentative de fermeture...");
   Sleep(100);
   if(trade.PositionClose(ticket))
   {
      return true;
   }
   
   // Dernière tentative
   Print("🔄 Dernière tentative de fermeture...");
   Sleep(200);
   return trade.PositionClose(ticket);
}

//+------------------------------------------------------------------+
//| ROUVRIR IMMÉDIATEMENT                                            |
//+------------------------------------------------------------------+
void ReopenImmediately(ENUM_POSITION_TYPE posType, double volume)
{
   double price, sl, tp;
   
   if(posType == POSITION_TYPE_BUY)
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
   if(posType == POSITION_TYPE_BUY)
   {
      result = trade.Buy(volume, _Symbol, price, sl, tp, "PRIORITÉ REOPEN BUY");
   }
   else
   {
      result = trade.Sell(volume, _Symbol, price, sl, tp, "PRIORITÉ REOPEN SELL");
   }
   
   if(result)
   {
      Print("🔄 RÉOUVERTURE PRIORITAIRE RÉUSSIE");
      Print("   Type: ", EnumToString(posType));
      Print("   Volume: ", DoubleToString(volume, 3));
   }
   else
   {
      Print("❌ Erreur réouverture: ", trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| STATISTIQUES                                                     |
//+------------------------------------------------------------------+
void PrintPriorityStatistics()
{
   Print("📊 STATISTIQUES PRIORITAIRES:");
   Print("   Vérifications totales: ", totalChecks);
   Print("   Fermetures réussies: ", totalCloses);
   Print("   Profit total sécurisé: ", DoubleToString(totalProfitSecured, 2), "$");
   Print("   Positions actuelles: ", PositionsTotal());
   
   double currentTotalProfit = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         currentTotalProfit += position.Profit() + position.Swap() + position.Commission();
      }
   }
   
   Print("   Profit actuel total: ", DoubleToString(currentTotalProfit, 2), "$");
}

//+------------------------------------------------------------------+
//| TEST MANUEL                                                      |
//+------------------------------------------------------------------+
void ManualPriorityTest()
{
   Print("🧪 TEST MANUEL PRIORITAIRE");
   
   double totalProfit = 0;
   int positionsAtTarget = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         double profit = position.Profit() + position.Swap() + position.Commission();
         totalProfit += profit;
         
         if(profit >= ProfitTarget1)
         {
            positionsAtTarget++;
            Print("🎯 Position #", position.Ticket(), " doit être fermée (", DoubleToString(profit, 2), "$)");
         }
      }
   }
   
   Print("📊 Résultat test manuel:");
   Print("   Positions à fermer: ", positionsAtTarget);
   Print("   Profit total: ", DoubleToString(totalProfit, 2), "$");
   
   if(positionsAtTarget > 0)
   {
      Print("🚨 ACTION REQUISE - ", positionsAtTarget, " positions doivent être fermées !");
   }
}

//+------------------------------------------------------------------+
//| CONFIGURATION RAPIDE                                             |
//+------------------------------------------------------------------+

// Changer les cibles de profit
void SetProfitTargets(double target1, double target2 = 0)
{
   ProfitTarget1 = target1;
   if(target2 > 0) ProfitTarget2 = target2;
   
   Print("🎯 Nouvelles cibles: ", ProfitTarget1, "$ et ", ProfitTarget2, "$");
}

// Activer/Désactiver le mode force
void SetForceClose(bool enabled)
{
   ForceCloseAll = enabled;
   Print("🔧 ForceClose: ", enabled ? "ACTIVÉ" : "DÉSACTIVÉ");
}

// Changer l'intervalle de vérification
void SetCheckInterval(int milliseconds)
{
   CheckIntervalMs = milliseconds;
   Print("⏱️ Intervalle de vérification: ", milliseconds, "ms");
}
