//+------------------------------------------------------------------+
//| risk_audit_checker.mq5                                           |
//| Script de diagnostic de gestion de risque                        |
//| À exécuter AVANT de relancer un EA                               |
//+------------------------------------------------------------------+
#property copyright "TradBOT Risk Audit"
#property version   "1.00"
#property script_show_inputs

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   Print("════════════════════════════════════════════════════════");
   Print("🔍 AUDIT DE GESTION DE RISQUE - ", TimeCurrent());
   Print("════════════════════════════════════════════════════════");

   // 1. Vérifier les positions ouvertes
   CheckOpenPositions();

   // 2. Analyser l'historique du jour
   AnalyzeDailyHistory();

   // 3. Vérifier les paramètres du compte
   CheckAccountParameters();

   // 4. Vérifier la volatilité actuelle
   CheckMarketConditions();

   // 5. Recommandations
   PrintRecommendations();

   Print("════════════════════════════════════════════════════════");
   Print("✅ Audit terminé");
   Print("════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Vérifier les positions ouvertes                                  |
//+------------------------------------------------------------------+
void CheckOpenPositions()
{
   Print("\n📊 POSITIONS OUVERTES :");
   Print("─────────────────────────────────────────────────────────");

   int total = PositionsTotal();
   if(total == 0)
   {
      Print("✅ Aucune position ouverte");
      return;
   }

   double totalRisk = 0.0;
   double totalProfit = 0.0;

   for(int i = 0; i < total; i++)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         long magic = PositionGetInteger(POSITION_MAGIC);
         long type = PositionGetInteger(POSITION_TYPE);
         double lots = PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double profit = PositionGetDouble(POSITION_PROFIT);

         totalProfit += profit;

         string typeStr = (type == POSITION_TYPE_BUY) ? "BUY" : "SELL";

         Print("Position #", i+1, " : ", symbol, " | ", typeStr, " | Lot: ", lots);
         Print("  Magic: ", magic, " | Prix: ", openPrice, " | Profit: ", DoubleToString(profit, 2), "$");

         // Vérifier le SL
         if(sl == 0)
         {
            Print("  ⚠️ ❌ AUCUN STOP LOSS - DANGER CRITIQUE !");
            totalRisk += 999999;  // Risque infini
         }
         else
         {
            double slDistance = MathAbs(openPrice - sl);
            double riskUSD = lots * slDistance * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) / SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
            totalRisk += riskUSD;
            Print("  SL: ", sl, " | Distance: ", DoubleToString(slDistance / SymbolInfoDouble(symbol, SYMBOL_POINT), 0), " pts | Risque: ", DoubleToString(riskUSD, 2), "$");
         }

         // Vérifier le TP
         if(tp == 0)
            Print("  ⚠️ Aucun Take Profit défini");
         else
            Print("  TP: ", tp);

         Print("─────────────────────────────────────────────────────────");
      }
   }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   Print("\n📈 RÉSUMÉ :");
   Print("  Nombre de positions : ", total);
   Print("  Profit flottant total : ", DoubleToString(totalProfit, 2), "$");
   Print("  Risque total : ", (totalRisk > 999999) ? "INFINI (pas de SL!)" : DoubleToString(totalRisk, 2) + "$");
   Print("  Balance : ", DoubleToString(balance, 2), "$");
   Print("  Equity : ", DoubleToString(equity, 2), "$");

   if(totalRisk > 999999)
   {
      Print("\n🚨 ALERTE ROUGE : POSITIONS SANS STOP LOSS !");
      Print("🚨 FERMER CES POSITIONS IMMÉDIATEMENT !");
   }
   else if(totalRisk > balance * 0.05)
   {
      Print("\n⚠️ ALERTE : Risque total > 5% du compte !");
   }
}

//+------------------------------------------------------------------+
//| Analyser l'historique du jour                                    |
//+------------------------------------------------------------------+
void AnalyzeDailyHistory()
{
   Print("\n📜 HISTORIQUE DU JOUR :");
   Print("─────────────────────────────────────────────────────────");

   datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   if(!HistorySelect(today, TimeCurrent()))
   {
      Print("⚠️ Impossible de charger l'historique");
      return;
   }

   int totalDeals = HistoryDealsTotal();
   int closedTrades = 0;
   double totalProfit = 0.0;
   double totalLoss = 0.0;
   int winTrades = 0;
   int lossTrades = 0;

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         long entry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
         if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
            double netProfit = profit + commission + swap;

            closedTrades++;

            if(netProfit > 0)
            {
               winTrades++;
               totalProfit += netProfit;
            }
            else if(netProfit < 0)
            {
               lossTrades++;
               totalLoss += netProfit;
            }
         }
      }
   }

   double netPnL = totalProfit + totalLoss;
   double winRate = (closedTrades > 0) ? (winTrades * 100.0 / closedTrades) : 0.0;

   Print("  Trades fermés aujourd'hui : ", closedTrades);
   Print("  Trades gagnants : ", winTrades, " | Trades perdants : ", lossTrades);
   Print("  Win rate : ", DoubleToString(winRate, 1), "%");
   Print("  Profit total : +", DoubleToString(totalProfit, 2), "$");
   Print("  Pertes totales : ", DoubleToString(totalLoss, 2), "$");
   Print("  P&L net du jour : ", DoubleToString(netPnL, 2), "$");

   if(netPnL < -50.0)
   {
      Print("\n🚨 ALERTE : Perte journalière > 50$ !");
      Print("🚨 ARRÊTER LE TRADING POUR AUJOURD'HUI !");
   }
   else if(closedTrades > 20)
   {
      Print("\n⚠️ WARNING : Plus de 20 trades aujourd'hui - Overtrading possible !");
   }
}

//+------------------------------------------------------------------+
//| Vérifier les paramètres du compte                                |
//+------------------------------------------------------------------+
void CheckAccountParameters()
{
   Print("\n💰 PARAMÈTRES DU COMPTE :");
   Print("─────────────────────────────────────────────────────────");

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);

   Print("  Balance : ", DoubleToString(balance, 2), "$");
   Print("  Equity : ", DoubleToString(equity, 2), "$");
   Print("  Marge utilisée : ", DoubleToString(margin, 2), "$");
   Print("  Marge libre : ", DoubleToString(freeMargin, 2), "$");

   if(margin > 0)
      Print("  Niveau de marge : ", DoubleToString(marginLevel, 2), "%");

   // Calcul du drawdown
   double drawdown = balance - equity;
   double drawdownPercent = (balance > 0) ? (drawdown * 100.0 / balance) : 0.0;

   Print("  Drawdown flottant : ", DoubleToString(drawdown, 2), "$ (", DoubleToString(drawdownPercent, 2), "%)");

   if(marginLevel < 200 && margin > 0)
   {
      Print("\n🚨 ALERTE MARGE : Niveau < 200% - Risque de margin call !");
   }

   if(drawdownPercent > 10)
   {
      Print("\n⚠️ ALERTE DRAWDOWN : > 10% - Réduire l'exposition !");
   }

   // Recommandations de lot size
   double recommendedLot = (balance * 0.005) / 100.0;  // 0.5% risk
   recommendedLot = MathMax(0.01, MathMin(recommendedLot, 0.1));

   Print("\n  💡 Lot size recommandé (0.5% risk) : ", DoubleToString(recommendedLot, 2));
}

//+------------------------------------------------------------------+
//| Vérifier les conditions de marché                                |
//+------------------------------------------------------------------+
void CheckMarketConditions()
{
   Print("\n📊 CONDITIONS DE MARCHÉ :");
   Print("─────────────────────────────────────────────────────────");

   string symbol = _Symbol;

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double spread = (ask - bid) / SymbolInfoDouble(symbol, SYMBOL_POINT);

   Print("  Symbole : ", symbol);
   Print("  Bid : ", bid, " | Ask : ", ask);
   Print("  Spread : ", DoubleToString(spread, 1), " points");

   // Vérifier ATR pour volatilité
   int atrHandle = iATR(symbol, PERIOD_M5, 14);
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuffer[];
      ArraySetAsSeries(atrBuffer, true);

      if(CopyBuffer(atrHandle, 0, 0, 10, atrBuffer) > 0)
      {
         double currentATR = atrBuffer[0];
         double avgATR = 0;
         for(int i = 0; i < 10; i++)
            avgATR += atrBuffer[i];
         avgATR /= 10;

         Print("  ATR(14) M5 : ", DoubleToString(currentATR, 5));
         Print("  ATR moyen (10) : ", DoubleToString(avgATR, 5));

         double atrRatio = currentATR / avgATR;
         Print("  Ratio volatilité : ", DoubleToString(atrRatio, 2), "x");

         if(atrRatio > 2.0)
         {
            Print("\n⚠️ ALERTE VOLATILITÉ : ATR > 2x moyenne - MARCHÉ AGITÉ !");
            Print("⚠️ RÉDUIRE LE LOT SIZE OU ÉVITER D'OUVRIR !");
         }
      }

      IndicatorRelease(atrHandle);
   }

   if(spread > 50)
   {
      Print("\n⚠️ ALERTE SPREAD : Spread > 50 points - Conditions défavorables !");
   }
}

//+------------------------------------------------------------------+
//| Afficher les recommandations                                     |
//+------------------------------------------------------------------+
void PrintRecommendations()
{
   Print("\n💡 RECOMMANDATIONS :");
   Print("─────────────────────────────────────────────────────────");

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   if(balance < 50)
   {
      Print("❌ Balance trop faible (< 50$) :");
      Print("  → Recharger le compte à minimum 100$");
      Print("  → Utiliser lot size 0.01 MAXIMUM");
      Print("  → Maximum 1 position à la fois");
   }
   else if(balance < 200)
   {
      Print("⚠️ Balance limitée (< 200$) :");
      Print("  → Lot size 0.01 - 0.02 recommandé");
      Print("  → Maximum 2 positions simultanées");
      Print("  → Risk 0.5% par trade MAXIMUM");
   }
   else
   {
      Print("✅ Balance acceptable (>= 200$) :");
      Print("  → Lot size 0.01 - 0.05 selon volatilité");
      Print("  → Maximum 3 positions simultanées");
      Print("  → Risk 1% par trade MAXIMUM");
   }

   Print("\n📋 CHECKLIST AVANT LANCEMENT EA :");
   Print("  [ ] Vérifier que MaxPositions = 1 ou 2");
   Print("  [ ] Vérifier que StopLoss > 0 (activé)");
   Print("  [ ] Vérifier que LotSize <= 0.05");
   Print("  [ ] Vérifier que RiskPercent <= 1%");
   Print("  [ ] Vérifier que MaxTradesPerDay <= 10");
   Print("  [ ] Tester en DÉMO pendant 24h minimum");
   Print("  [ ] Surveiller les 5 premiers trades en réel");
}
