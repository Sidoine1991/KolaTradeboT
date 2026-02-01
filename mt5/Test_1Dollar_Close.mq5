//+------------------------------------------------------------------+
//|                           Test_1Dollar_Close.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00 - TEST 1$ CLOSE"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| PARAMÈTRES DE TEST                                               |
//+------------------------------------------------------------------+
input group "=== TEST PARAMETERS ==="
input double ProfitTarget = 1.0;              // Profit cible en dollars
input bool   EnableTestMode = true;           // Mode test activé
input int    CheckIntervalSeconds = 1;        // Intervalle de vérification
input bool   ForceCloseAll = false;           // Forcer fermeture de tout

input group "=== DEBUG ==="
input bool   VerboseDebug = true;             // Debug très détaillé

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo position;

static datetime lastCheckTime = 0;
static int totalChecks = 0;
static int totalCloses = 0;

//+------------------------------------------------------------------+
//| INITIALISATION                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(999999);
   trade.SetDeviationInPoints(10);
   
   Print("🧪 TEST 1$ CLOSE - Initialisé");
   Print("🎯 Profit cible: ", ProfitTarget, "$");
   Print("📊 Mode test: ", EnableTestMode ? "ACTIVÉ" : "DÉSACTIVÉ");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| TICK PRINCIPAL                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérifier à intervalles réguliers
   if(TimeCurrent() - lastCheckTime >= CheckIntervalSeconds)
   {
      lastCheckTime = TimeCurrent();
      totalChecks++;
      
      if(VerboseDebug)
      {
         Print("🔍 Check #", totalChecks, " - Heure: ", TimeToString(TimeCurrent()));
      }
      
      // Fonction de test principale
      TestClosePositionsAtProfit();
   }
}

//+------------------------------------------------------------------+
//| FONCTION DE TEST PRINCIPALE                                       |
//+------------------------------------------------------------------+
void TestClosePositionsAtProfit()
{
   int positionsFound = 0;
   int positionsProfitable = 0;
   int positionsClosed = 0;
   
   Print("📋 === DÉBUT VÉRIFICATION POSITIONS ===");
   Print("📊 Positions totales: ", PositionsTotal());
   
   // Parcourir toutes les positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         positionsFound++;
         
         ulong ticket = position.Ticket();
         string symbol = position.Symbol();
         ENUM_POSITION_TYPE posType = position.PositionType();
         double volume = position.Volume();
         double profit = position.Profit();
         double swap = position.Swap();
         double commission = position.Commission();
         double totalProfit = profit + swap + commission;
         
         Print("📈 Position #", ticket);
         Print("   Symbole: ", symbol);
         Print("   Type: ", EnumToString(posType));
         Print("   Volume: ", DoubleToString(volume, 3));
         Print("   Profit brut: ", DoubleToString(profit, 2), "$");
         Print("   Swap: ", DoubleToString(swap, 2), "$");
         Print("   Commission: ", DoubleToString(commission, 2), "$");
         Print("   PROFIT TOTAL: ", DoubleToString(totalProfit, 2), "$");
         Print("   ──────────────────────────");
         
         // Vérifier si le profit cible est atteint
         if(totalProfit >= ProfitTarget)
         {
            positionsProfitable++;
            Print("💰 POSITION PROFITABLE DÉTECTÉE !");
            Print("   Ticket: ", ticket);
            Print("   Profit: ", DoubleToString(totalProfit, 2), "$ (>= ", ProfitTarget, "$)");
            
            // Fermer la position
            if(EnableTestMode || ForceCloseAll)
            {
               Print("🔄 Tentative de fermeture...");
               
               if(trade.PositionClose(ticket))
               {
                  positionsClosed++;
                  totalCloses++;
                  Print("✅ Position ", ticket, " FERMÉE AVEC SUCCÈS !");
                  Print("   Profit réalisé: ", DoubleToString(totalProfit, 2), "$");
               }
               else
               {
                  uint error = GetLastError();
                  Print("❌ ERREUR FERMETURE POSITION ", ticket);
                  Print("   Code erreur: ", error);
                  Print("   Description: ", trade.ResultComment());
                  Print("   Result code: ", trade.ResultCode());
                  Print("   Result comment: ", trade.ResultComment());
               }
            }
            else
            {
               Print("⚠️ Mode test DÉSACTIVÉ - Position non fermée");
            }
         }
         else if(totalProfit > 0)
         {
            Print("⏳ Position en progression: ", DoubleToString(totalProfit, 2), "$ (target: ", ProfitTarget, "$)");
         }
         else
         {
            Print("📉 Position en perte: ", DoubleToString(totalProfit, 2), "$");
         }
      }
   }
   
   // Résumé
   Print("📊 === RÉSUMÉ VÉRIFICATION #", totalChecks, " ===");
   Print("   Positions trouvées: ", positionsFound);
   Print("   Positions profitables: ", positionsProfitable);
   Print("   Positions fermées: ", positionsClosed);
   Print("   Total fermées (cumul): ", totalCloses);
   Print("   Mode test: ", EnableTestMode ? "ACTIVÉ" : "DÉSACTIVÉ");
   Print("🏁 === FIN VÉRIFICATION ===");
   Print("");
}

//+------------------------------------------------------------------+
//| FORCER LA FERMETURE DE TOUTES LES POSITIONS                       |
//+------------------------------------------------------------------+
void ForceCloseAllPositions()
{
   Print("🚨 FERMETURE FORCÉE DE TOUTES LES POSITIONS");
   
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(position.SelectByIndex(i))
      {
         ulong ticket = position.Ticket();
         double profit = position.Profit() + position.Swap() + position.Commission();
         
         if(trade.PositionClose(ticket))
         {
            closed++;
            Print("✅ Position ", ticket, " fermée - Profit: ", DoubleToString(profit, 2), "$");
         }
         else
         {
            Print("❌ Erreur fermeture position ", ticket);
         }
      }
   }
   
   Print("🎯 Total positions fermées: ", closed);
}

//+------------------------------------------------------------------+
//| OBTENIR STATISTIQUES                                             |
//+------------------------------------------------------------------+
void PrintStatistics()
{
   Print("📊 STATISTIQUES DU TEST:");
   Print("   Vérifications totales: ", totalChecks);
   Print("   Fermetures réussies: ", totalCloses);
   Print("   Positions actuelles: ", PositionsTotal());
   
   double totalProfit = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(position.SelectByIndex(i))
      {
         totalProfit += position.Profit() + position.Swap() + position.Commission();
      }
   }
   
   Print("   Profit actuel total: ", DoubleToString(totalProfit, 2), "$");
}

//+------------------------------------------------------------------+
//| TEST DE CONNEXION TRADE                                          |
//+------------------------------------------------------------------+
void TestTradeConnection()
{
   Print("🔧 TEST CONNEXION TRADE:");
   
   // Tester si le trade est autorisé
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("❌ Trading non autorisé dans le terminal");
      return;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      Print("❌ Trading non autorisé pour le compte");
      return;
   }
   
   // Tester les informations du compte
   Print("✅ Connexion trade OK");
   Print("   Nom du compte: ", AccountInfoString(ACCOUNT_NAME));
   Print("   Broker: ", AccountInfoString(ACCOUNT_COMPANY));
   Print("   Solde: ", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), "$");
   Print("   Equity: ", DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2), "$");
}

//+------------------------------------------------------------------+
//| FONCTIONS DE TEST UTILITAIRES                                    |
//+------------------------------------------------------------------+

// Activer/Désactiver le mode test
void SetTestMode(bool enabled)
{
   EnableTestMode = enabled;
   Print("🔧 Mode test ", enabled ? "ACTIVÉ" : "DÉSACTIVÉ");
}

// Changer le profit cible
void SetProfitTarget(double target)
{
   ProfitTarget = target;
   Print("🎯 Profit cible changé à: ", target, "$");
}

// Afficher les détails d'une position spécifique
void PrintPositionDetails(ulong ticket)
{
   if(position.SelectByTicket(ticket))
   {
      Print("📋 DÉTAILS POSITION #", ticket);
      Print("   Symbole: ", position.Symbol());
      Print("   Type: ", EnumToString(position.PositionType()));
      Print("   Volume: ", DoubleToString(position.Volume(), 3));
      Print("   Prix d'entrée: ", DoubleToString(position.PriceOpen(), 5));
      Print("   Prix actuel: ", DoubleToString(position.PriceCurrent(), 5));
      Print("   Profit: ", DoubleToString(position.Profit(), 2), "$");
      Print("   Swap: ", DoubleToString(position.Swap(), 2), "$");
      Print("   Commission: ", DoubleToString(position.Commission(), 2), "$");
      Print("   Profit total: ", DoubleToString(position.Profit() + position.Swap() + position.Commission(), 2), "$");
   }
   else
   {
      Print("❌ Position #", ticket, " non trouvée");
   }
}
