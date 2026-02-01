//+------------------------------------------------------------------+
//|                        Test_Global_Close_2Dollars.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00 - GLOBAL CLOSE TEST"
#property script_show_inputs

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| PARAMÈTRES DU SCRIPT                                             |
//+------------------------------------------------------------------+
input double GlobalProfitTarget = 2.0;         // Objectif global de profit
input bool   ShowAllPositions = true;          // Afficher toutes les positions
input bool   EnableNotifications = true;       // Notifications MT5
input bool   ContinuousMode = false;           // Mode continu
input int    CheckIntervalMs = 1000;            // Intervalle de vérification

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;

//+------------------------------------------------------------------+
//| FONCTION PRINCIPALE DU SCRIPT                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   if(ContinuousMode)
   {
      TestContinuousGlobalClose();
   }
   else
   {
      TestSingleGlobalClose();
   }
}

//+------------------------------------------------------------------+
//| TEST UNIQUE DE FERMETURE GLOBALE                                |
//+------------------------------------------------------------------+
void TestSingleGlobalClose()
{
   Print("🚨 SCRIPT TEST - FERMETURE GLOBALE À ", GlobalProfitTarget, "$");
   
   double totalGlobalProfit = 0;
   int totalPositions = 0;
   
   // Calculer le profit global
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         double positionProfit = position.Profit() + position.Swap() + position.Commission();
         totalGlobalProfit += positionProfit;
         totalPositions++;
         
         if(ShowAllPositions)
         {
            Print("📋 Position #", position.Ticket());
            Print("   Symbole: ", position.Symbol());
            Print("   Type: ", EnumToString(position.PositionType()));
            Print("   Volume: ", DoubleToString(position.Volume(), 3));
            Print("   Profit: ", DoubleToString(positionProfit, 2), "$");
            Print("   ──────────────────────────");
         }
      }
   }
   
   Print("💰 PROFIT GLOBAL ACTUEL: ", DoubleToString(totalGlobalProfit, 2), "$");
   Print("🎯 OBJECTIF GLOBAL: ", DoubleToString(GlobalProfitTarget, 2), "$");
   Print("📊 Positions totales: ", totalPositions);
   
   // Vérifier si l'objectif est atteint
   if(totalGlobalProfit >= GlobalProfitTarget)
   {
      Print("🚨🚨🚨 OBJECTIF GLOBAL ATTEINT - FERMETURE TOTALE ! 🚨🚨🚨");
      ExecuteGlobalClose();
   }
   else
   {
      Print("⏳ Objectif pas encore atteint");
      Print("   Manque: ", DoubleToString(GlobalProfitTarget - totalGlobalProfit, 2), "$");
   }
}

//+------------------------------------------------------------------+
//| TEST CONTINU DE FERMETURE GLOBALE                                |
//+------------------------------------------------------------------+
void TestContinuousGlobalClose()
{
   Print("🔄 MODE CONTINU - SURVEILLANCE GLOBALE");
   Print("🎯 Objectif: ", GlobalProfitTarget, "$");
   Print("⏱️ Vérification toutes les ", CheckIntervalMs, "ms");
   
   while(!IsStopped())
   {
      double totalGlobalProfit = 0;
      int totalPositions = 0;
      
      // Calculer le profit global
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(position.SelectByIndex(i))
         {
            double positionProfit = position.Profit() + position.Swap() + position.Commission();
            totalGlobalProfit += positionProfit;
            totalPositions++;
         }
      }
      
      // Afficher le statut
      Print("💰 Profit global: ", DoubleToString(totalGlobalProfit, 2), "$ / ", DoubleToString(GlobalProfitTarget, 2), "$");
      Print("📊 Positions: ", totalPositions);
      
      // Vérifier si l'objectif est atteint
      if(totalGlobalProfit >= GlobalProfitTarget)
      {
         Print("🚨🚨🚨 OBJECTIF GLOBAL ATTEINT - FERMETURE IMMÉDIATE ! 🚨🚨🚨");
         
         if(ExecuteGlobalClose())
         {
            Print("✅ Fermeture globale réussie - Arrêt du script");
            break;
         }
      }
      else
      {
         Print("⏳ Progression: ", DoubleToString((totalGlobalProfit/GlobalProfitTarget)*100, 1), "%");
      }
      
      Sleep(CheckIntervalMs);
   }
}

//+------------------------------------------------------------------+
//| EXÉCUTER LA FERMETURE GLOBALE                                    |
//+------------------------------------------------------------------+
bool ExecuteGlobalClose()
{
   int positionsClosed = 0;
   double actualProfitClosed = 0;
   
   // FERMER TOUTES LES POSITIONS
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         ulong ticket = position.Ticket();
         double positionProfit = position.Profit() + position.Swap() + position.Commission();
         
         Print("🔄 Fermeture position #", ticket, " - Profit: ", DoubleToString(positionProfit, 2), "$");
         
         // Fermer avec multi-essais
         bool closed = false;
         
         // Essai 1
         if(trade.PositionClose(ticket))
         {
            closed = true;
         }
         else
         {
            Print("❌ Essai 1 échoué - Retry...");
            Sleep(50);
            
            // Essai 2
            if(trade.PositionClose(ticket))
            {
               closed = true;
            }
            else
            {
               Print("❌ Essai 2 échoué - Retry...");
               Sleep(100);
               
               // Essai 3
               if(trade.PositionClose(ticket))
               {
                  closed = true;
               }
               else
               {
                  Print("❌ Essai 3 échoué - Retry...");
                  Sleep(200);
                  
                  // Essai 4 FINAL
                  if(trade.PositionClose(ticket))
                  {
                     closed = true;
                  }
                  else
                  {
                     uint error = GetLastError();
                     Print("💥 ERREUR FATALE FERMETURE: ", error);
                  }
               }
            }
         }
         
         if(closed)
         {
            positionsClosed++;
            actualProfitClosed += positionProfit;
            
            Print("✅ Position ", ticket, " fermée - Profit: ", DoubleToString(positionProfit, 2), "$");
            
            // Notification
            if(EnableNotifications)
            {
               string message = StringFormat("GLOBAL: Position %d fermée - Profit %.2f$", ticket, positionProfit);
               SendNotification(message);
            }
         }
      }
   }
   
   // Résumé
   Print("🎯🎯🎯 FERMETURE GLOBALE TERMINÉE ! 🎯🎯🎯");
   Print("   Positions fermées: ", positionsClosed);
   Print("   Profit réel fermé: ", DoubleToString(actualProfitClosed, 2), "$");
   
   // Notification globale
   if(EnableNotifications)
   {
      string globalMessage = StringFormat("FERMETURE GLOBALE: %d positions fermées - Profit %.2f$", positionsClosed, actualProfitClosed);
      SendNotification(globalMessage);
   }
   
   return positionsClosed > 0;
}

//+------------------------------------------------------------------+
//| DIAGNOSTIC GLOBAAL                                               |
//+------------------------------------------------------------------+
void GlobalDiagnostic()
{
   Print("🔍 DIAGNOSTIC GLOBALE COMPLET");
   
   double totalProfit = 0;
   double totalLoss = 0;
   int profitablePositions = 0;
   int losingPositions = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         double profit = position.Profit() + position.Swap() + position.Commission();
         totalProfit += profit;
         
         if(profit > 0)
         {
            profitablePositions++;
         }
         else
         {
            losingPositions++;
            totalLoss += MathAbs(profit);
         }
         
         Print("📊 Position #", position.Ticket());
         Print("   Symbole: ", position.Symbol());
         Print("   Type: ", EnumToString(position.PositionType()));
         Print("   Volume: ", DoubleToString(position.Volume(), 3));
         Print("   Profit: ", DoubleToString(profit, 2), "$");
         Print("   ──────────────────────────");
      }
   }
   
   Print("📈 RÉSUMÉ GLOBAL:");
   Print("   Positions totales: ", PositionsTotal());
   Print("   Positions profitables: ", profitablePositions);
   Print("   Positions perdantes: ", losingPositions);
   Print("   Profit total: ", DoubleToString(totalProfit, 2), "$");
   Print("   Perte totale: ", DoubleToString(totalLoss, 2), "$");
   Print("   Net: ", DoubleToString(totalProfit - totalLoss, 2), "$");
   Print("   Objectif: ", DoubleToString(GlobalProfitTarget, 2), "$");
   
   if(totalProfit >= GlobalProfitTarget)
   {
      Print("🚨 OBJECTIF ATTEINT - FERMETURE REQUISE !");
   }
   else
   {
      Print("⏳ Objectif pas atteint - Manque: ", DoubleToString(GlobalProfitTarget - totalProfit, 2), "$");
   }
}
