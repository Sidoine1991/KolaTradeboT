//+------------------------------------------------------------------+
//| SMC_Universal_MINIMAL.mq5 - VERSION MINIMALISTE POUR DIAGNOSTIC |
//| Teste seulement les fonctions de base pour identifier le problème |
//+------------------------------------------------------------------+

#property copyright "SMC Universal"
#property link      "https://www.mql5.com"
#property version   "1.00"

// INCLUDES DE BASE
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

// PARAMÈTRES MINIMAUX
input bool UseAIServer = false; // IA désactivée par défaut
input double TakeProfitDollars = 2.0; // Fermeture à 2$
input double MaxLossDollars = 6.0; // Stop loss max

// VARIABLES GLOBALES MINIMALES
CTrade trade;
CPositionInfo posInfo;

//+------------------------------------------------------------------+
//| FONCTION DE FERMATURE À 2$ UNIQUEMENT                            |
//+------------------------------------------------------------------+
void ManageDollarExits()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      string symbol = PositionGetSymbol(i);
      if(symbol == "") continue;
      
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      if(ticket == 0) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      // FERMURE À 2$ POUR TOUS LES SYMBOLES
      if(profit >= 2.0)
      {
         if(trade.PositionClose(ticket))
            Print("✅ Position fermée: bénéfice 2$ atteint (", DoubleToString(profit, 2), "$) - ", symbol);
         continue;
      }
      
      // STOP LOSS MAX
      if(profit <= -MaxLossDollars)
      {
         if(trade.PositionClose(ticket))
            Print("🛑 Position fermée: perte max atteinte (", DoubleToString(profit, 2), "$) - ", symbol);
         continue;
      }
   }
}

//+------------------------------------------------------------------+
//| FONCTION PRINCIPALE MINIMALISTE                                 |
//+------------------------------------------------------------------+
void OnTick()
{
   static int tickCounter = 0;
   static datetime startTime = 0;
   
   if(startTime == 0) startTime = TimeCurrent();
   tickCounter++;
   
   // LOG MINIMAL TOUTES LES 100 TICKS
   if(tickCounter % 100 == 0)
   {
      datetime runningTime = TimeCurrent() - startTime;
      Print("🧪 MINIMAL MODE - Tick #", tickCounter, " | Temps écoulé: ", runningTime, "s");
   }
   
   // SEULEMENT LA FONCTION DE FERMATURE À 2$
   ManageDollarExits();
   
   // AUCUNE AUTRE FONCTION - MODE TEST PUR
}

//+------------------------------------------------------------------+
//| INITIALISATION MINIMALISTE                                       |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🧪 SMC_Universal_MINIMAL - Mode test activé");
   Print("   Fonctions: Fermeture à 2$ seulement");
   Print("   IA: Désactivée");
   Print("   Graphiques: Aucun");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DÉINITIALISATION MINIMALISTE                                     |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("🧪 SMC_Universal_MINIMAL - Arrêt propre");
}
