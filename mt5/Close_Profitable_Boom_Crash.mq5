//+------------------------------------------------------------------+
//|                                     Close_Profitable_Boom_Crash.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"
#property script_show_inputs

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| PARAMÈTRES DU SCRIPT                                             |
//+------------------------------------------------------------------+
input double MinProfitThreshold = 0.01;        // Seuil minimum de profit pour fermer
input bool   EnableNotifications = true;       // Notifications MT5
input bool   ShowDetails = true;               // Afficher les détails des positions
input bool   CloseBoomOnly = false;            // Fermer seulement Boom (false = Boom + Crash)
input bool   CloseCrashOnly = false;           // Fermer seulement Crash (false = Boom + Crash)

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
   CloseProfitableBoomCrashPositions();
}

//+------------------------------------------------------------------+
//| FERMER LES POSITIONS PROFITABLES BOOM/CRASH                      |
//+------------------------------------------------------------------+
void CloseProfitableBoomCrashPositions()
{
   int positionsClosed = 0;
   double totalProfitClosed = 0;
   int boomPositions = 0;
   int crashPositions = 0;
   
   Print("🚨 SCRIPT DE FERMETURE POSITIONS PROFITABLES BOOM/CRASH");
   Print("💰 Seuil minimum: ", DoubleToString(MinProfitThreshold, 2), "$");
   
   if(CloseBoomOnly)
   {
      Print("🎯 MODE: FERMETURE BOOM SEULEMENT");
   }
   else if(CloseCrashOnly)
   {
      Print("🎯 MODE: FERMETURE CRASH SEULEMENT");
   }
   else
   {
      Print("🎯 MODE: FERMETURE BOOM + CRASH");
   }
   
   // Parcourir toutes les positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         string symbol = position.Symbol();
         double positionProfit = position.Profit() + position.Swap() + position.Commission();
         ulong ticket = position.Ticket();
         
         // Vérifier si c'est un symbole Boom ou Crash
         bool isBoomSymbol = (StringFind(symbol, "Boom") >= 0);
         bool isCrashSymbol = (StringFind(symbol, "Crash") >= 0);
         
         // Appliquer les filtres selon les paramètres
         bool shouldProcess = false;
         
         if(CloseBoomOnly && isBoomSymbol)
         {
            shouldProcess = true;
         }
         else if(CloseCrashOnly && isCrashSymbol)
         {
            shouldProcess = true;
         }
         else if(!CloseBoomOnly && !CloseCrashOnly && (isBoomSymbol || isCrashSymbol))
         {
            shouldProcess = true;
         }
         
         // Si le symbole correspond et la position est profitable
         if(shouldProcess && positionProfit > MinProfitThreshold)
         {
            if(isBoomSymbol) boomPositions++;
            if(isCrashSymbol) crashPositions++;
            
            if(ShowDetails)
            {
               Print("📋 Position profitable trouvée:");
               Print("   Ticket: #", ticket);
               Print("   Symbole: ", symbol);
               Print("   Type: ", EnumToString(position.PositionType()));
               Print("   Volume: ", DoubleToString(position.Volume(), 3));
               Print("   Profit: ", DoubleToString(positionProfit, 2), "$");
               Print("   🔄 Fermeture en cours...");
            }
            
            // Fermer la position avec multi-essais
            bool closed = ClosePositionWithRetry(ticket);
            
            if(closed)
            {
               positionsClosed++;
               totalProfitClosed += positionProfit;
               
               Print("✅ Position #", ticket, " fermée - Profit: ", DoubleToString(positionProfit, 2), "$");
               
               // Notification
               if(EnableNotifications)
               {
                  string message = StringFormat("BOOM/CRASH: Position %s #%d fermée - Profit %.2f$", symbol, ticket, positionProfit);
                  SendNotification(message);
               }
            }
            else
            {
               Print("❌ Échec fermeture position #", ticket);
            }
         }
         else if(shouldProcess && ShowDetails)
         {
            Print("⏸️ Position non profitable:");
            Print("   Ticket: #", ticket);
            Print("   Symbole: ", symbol);
            Print("   Profit: ", DoubleToString(positionProfit, 2), "$ (seuil: ", DoubleToString(MinProfitThreshold, 2), "$)");
         }
      }
   }
   
   // Résumé final
   Print("🎯🎯🎯 FERMETURE TERMINÉE ! 🎯🎯🎯");
   Print("   Positions Boom analysées: ", boomPositions);
   Print("   Positions Crash analysées: ", crashPositions);
   Print("   Positions fermées: ", positionsClosed);
   Print("   Profit total réalisé: ", DoubleToString(totalProfitClosed, 2), "$");
   
   // Notification globale
   if(EnableNotifications && positionsClosed > 0)
   {
      string globalMessage = StringFormat("FERMETURE BOOM/CRASH: %d positions fermées - Profit %.2f$", positionsClosed, totalProfitClosed);
      SendNotification(globalMessage);
   }
   
   if(positionsClosed == 0)
   {
      Print("ℹ️ Aucune position profitable trouvée pour fermeture");
   }
}

//+------------------------------------------------------------------+
//| FERMER POSITION AVEC MULTI-ESSAIS                                |
//+------------------------------------------------------------------+
bool ClosePositionWithRetry(ulong ticket)
{
   // Essai 1
   if(trade.PositionClose(ticket))
   {
      return true;
   }
   
   Print("❌ Essai 1 échoué - Retry...");
   Sleep(50);
   
   // Essai 2
   if(trade.PositionClose(ticket))
   {
      return true;
   }
   
   Print("❌ Essai 2 échoué - Retry...");
   Sleep(100);
   
   // Essai 3
   if(trade.PositionClose(ticket))
   {
      return true;
   }
   
   Print("❌ Essai 3 échoué - Retry...");
   Sleep(200);
   
   // Essai 4 FINAL
   if(trade.PositionClose(ticket))
   {
      return true;
   }
   
   uint error = GetLastError();
   Print("💥 ERREUR FATALE FERMETURE #", ticket, ": ", error);
   return false;
}

//+------------------------------------------------------------------+
//| DIAGNOSTIC DES POSITIONS BOOM/CRASH                              |
//+------------------------------------------------------------------+
void DiagnosticBoomCrashPositions()
{
   Print("🔍 DIAGNOSTIC POSITIONS BOOM/CRASH");
   
   int totalBoom = 0;
   int totalCrash = 0;
   int profitableBoom = 0;
   int profitableCrash = 0;
   double totalBoomProfit = 0;
   double totalCrashProfit = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         string symbol = position.Symbol();
         double profit = position.Profit() + position.Swap() + position.Commission();
         
         bool isBoomSymbol = (StringFind(symbol, "Boom") >= 0);
         bool isCrashSymbol = (StringFind(symbol, "Crash") >= 0);
         
         if(isBoomSymbol)
         {
            totalBoom++;
            totalBoomProfit += profit;
            if(profit > MinProfitThreshold)
            {
               profitableBoom++;
            }
            
            Print("📊 BOOM Position #", position.Ticket());
            Print("   Symbole: ", symbol);
            Print("   Type: ", EnumToString(position.PositionType()));
            Print("   Profit: ", DoubleToString(profit, 2), "$");
         }
         else if(isCrashSymbol)
         {
            totalCrash++;
            totalCrashProfit += profit;
            if(profit > MinProfitThreshold)
            {
               profitableCrash++;
            }
            
            Print("📊 CRASH Position #", position.Ticket());
            Print("   Symbole: ", symbol);
            Print("   Type: ", EnumToString(position.PositionType()));
            Print("   Profit: ", DoubleToString(profit, 2), "$");
         }
      }
   }
   
   Print("📈 RÉSUMÉ BOOM/CRASH:");
   Print("   Positions Boom totales: ", totalBoom, " (profitables: ", profitableBoom, ")");
   Print("   Positions Crash totales: ", totalCrash, " (profitables: ", profitableCrash, ")");
   Print("   Profit Boom total: ", DoubleToString(totalBoomProfit, 2), "$");
   Print("   Profit Crash total: ", DoubleToString(totalCrashProfit, 2), "$");
   Print("   Profit total: ", DoubleToString(totalBoomProfit + totalCrashProfit, 2), "$");
   Print("   Seuil de fermeture: ", DoubleToString(MinProfitThreshold, 2), "$");
}
