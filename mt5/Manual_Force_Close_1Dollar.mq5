//+------------------------------------------------------------------+
//|                        Manual_Force_Close_1Dollar.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00 - MANUAL FORCE CLOSE"
#property script_show_inputs

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| PARAMÈTRES DU SCRIPT                                             |
//+------------------------------------------------------------------+
input double ProfitTarget = 1.0;              // Profit cible pour fermeture
input bool   ForceCloseAll = true;             // Forcer fermeture immédiate
input bool   ShowAllPositions = true;          // Afficher toutes les positions
input bool   EnableNotifications = true;       // Notifications MT5

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
   Print("🚨 SCRIPT MANUEL - FERMETURE FORCÉE À ", ProfitTarget, "$");
   Print("📊 Positions actuelles: ", PositionsTotal());
   
   int positionsClosed = 0;
   double totalProfitClosed = 0;
   
   // Analyser toutes les positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         double profit = position.Profit() + position.Swap() + position.Commission();
         ulong ticket = position.Ticket();
         ENUM_POSITION_TYPE posType = position.PositionType();
         double volume = position.Volume();
         string symbol = position.Symbol();
         
         // Afficher toutes les positions si demandé
         if(ShowAllPositions)
         {
            Print("📋 Position #", ticket);
            Print("   Symbole: ", symbol);
            Print("   Type: ", EnumToString(posType));
            Print("   Volume: ", DoubleToString(volume, 3));
            Print("   Profit: ", DoubleToString(profit, 2), "$");
            Print("   ──────────────────────────");
         }
         
         // Vérifier si la position doit être fermée
         if(profit >= ProfitTarget)
         {
            Print("💰 POSITION À FERMER DÉTECTÉE !");
            Print("   Ticket: ", ticket);
            Print("   Profit: ", DoubleToString(profit, 2), "$ (>= ", ProfitTarget, "$)");
            
            // Fermer la position
            if(trade.PositionClose(ticket))
            {
               positionsClosed++;
               totalProfitClosed += profit;
               
               Print("✅ POSITION FERMÉE AVEC SUCCÈS !");
               Print("   Ticket: ", ticket);
               Print("   Profit sécurisé: ", DoubleToString(profit, 2), "$");
               
               // Notification
               if(EnableNotifications)
               {
                  string message = StringFormat("MANUEL: Position %d fermée à %.2f$", ticket, profit);
                  SendNotification(message);
               }
            }
            else
            {
               uint error = GetLastError();
               Print("❌ ERREUR FERMETURE POSITION ", ticket);
               Print("   Code erreur: ", error);
               Print("   Description: ", trade.ResultComment());
            }
         }
      }
   }
   
   // Résumé final
   Print("🎯 RÉSUMÉ DU SCRIPT:");
   Print("   Positions fermées: ", positionsClosed);
   Print("   Profit total sécurisé: ", DoubleToString(totalProfitClosed, 2), "$");
   
   if(positionsClosed > 0)
   {
      Print("🎉 MISSION ACCOMPLIE - GAINS SÉCURISÉS !");
   }
   else
   {
      Print("ℹ️ Aucune position n'a atteint la cible de ", ProfitTarget, "$");
   }
}

//+------------------------------------------------------------------+
//| FONCTION DE TEST CONTINU                                        |
//+------------------------------------------------------------------+
void TestContinuousClose()
{
   Print("🔄 TEST CONTINU DE FERMETURE...");
   
   while(!IsStopped())
   {
      int positionsAtTarget = 0;
      double totalProfit = 0;
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(position.SelectByIndex(i))
         {
            double profit = position.Profit() + position.Swap() + position.Commission();
            
            if(profit >= ProfitTarget)
            {
               positionsAtTarget++;
               totalProfit += profit;
               
               Print("🎯 Position #", position.Ticket(), " à ", DoubleToString(profit, 2), "$");
               
               // Fermer immédiatement
               if(trade.PositionClose(position.Ticket()))
               {
                  Print("✅ Fermée immédiatement !");
               }
            }
         }
      }
      
      if(positionsAtTarget > 0)
      {
         Print("💰 ", positionsAtTarget, " positions fermées - Profit: ", DoubleToString(totalProfit, 2), "$");
      }
      
      Sleep(1000); // Attendre 1 seconde
   }
}

//+------------------------------------------------------------------+
//| DIAGNOSTIC COMPLET                                               |
//+------------------------------------------------------------------+
void FullDiagnostic()
{
   Print("🔍 DIAGNOSTIC COMPLET DES POSITIONS");
   Print("📊 Total positions: ", PositionsTotal());
   
   double totalProfit = 0;
   int profitablePositions = 0;
   int positionsAtTarget = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         double profit = position.Profit() + position.Swap() + position.Commission();
         totalProfit += profit;
         
         if(profit > 0) profitablePositions++;
         if(profit >= ProfitTarget) positionsAtTarget++;
         
         Print("📈 Position #", position.Ticket());
         Print("   Symbole: ", position.Symbol());
         Print("   Type: ", EnumToString(position.PositionType()));
         Print("   Volume: ", DoubleToString(position.Volume(), 3));
         Print("   Profit brut: ", DoubleToString(position.Profit(), 2), "$");
         Print("   Swap: ", DoubleToString(position.Swap(), 2), "$");
         Print("   Commission: ", DoubleToString(position.Commission(), 2), "$");
         Print("   PROFIT TOTAL: ", DoubleToString(profit, 2), "$");
         Print("   Status: ", profit >= ProfitTarget ? "À FERMER" : "CONSERVER");
         Print("   ──────────────────────────");
      }
   }
   
   Print("📊 RÉSUMÉ DIAGNOSTIC:");
   Print("   Positions profitables: ", profitablePositions, "/", PositionsTotal());
   Print("   Positions à fermer: ", positionsAtTarget);
   Print("   Profit total: ", DoubleToString(totalProfit, 2), "$");
   
   if(positionsAtTarget > 0)
   {
      Print("🚨 ACTION REQUISE: ", positionsAtTarget, " positions doivent être fermées !");
   }
}
