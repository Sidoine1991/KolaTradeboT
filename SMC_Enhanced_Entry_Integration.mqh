//+------------------------------------------------------------------+
//| SMC_Enhanced_Entry_Integration.mqh                              |
//| Intégration du système d'entrée avancé dans SMC_Universal       |
//+------------------------------------------------------------------+

#ifndef __SMC_ENHANCED_ENTRY_INTEGRATION_MQH__
#define __SMC_ENHANCED_ENTRY_INTEGRATION_MQH__

#include "SMC_Advanced_Entry_System.mqh"

//+------------------------------------------------------------------+
//| FONCTION PRINCIPALE: EXÉCUTION DES ENTRÉES PRICE ACTION        |
//+------------------------------------------------------------------+

void CheckAndExecuteAdvancedPriceActionEntry()
{
   if(IsMilestoneProfitRestActive()) return;
   // Vérifier que le système est activé
   if(!UseAdvancedPriceActionEntry)
      return;
   
   // NOUVEAU: Mettre à jour la prédiction de direction basée sur les patterns candlestick
   CandlestickPrediction candlePred;
   PredictPriceDirectionFromPatterns(PERIOD_M1, 50, candlePred);
   
   if(AdvancedEntryLogPatternDetails && candlePred.patternCount > 0)
   {
      Print("🕯️ CANDLESTICK PREDICTION: ", candlePred.direction, 
            " | Conf: ", DoubleToString(candlePred.confidence, 1), "%",
            " | Dominant: ", candlePred.dominantPattern,
            " | Patterns: ", candlePred.patternCount);
   }
   
   // Vérifications préalables
   if(!IsTradingTimeValid()) return;
   if(IsMaxPositionsReached()) return;
   if(IsEntryCooldownActive()) return;
   if(!IsSpreadAcceptable()) return;

   // Catégorie du symbole
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);

   // Cette entrée s'applique à tous les symboles sauf les exclusions
   if(cat == SYM_UNKNOWN) return;

   // Déterminer les directions à tester (selon la stratégie)
   string directionsToTest[];
   int dirCount = 0;

   if(UseAIServer && g_lastAIAction != "")
   {
      // Mode IA: ne tester que la direction de l'IA
      if(g_lastAIAction == "BUY" || g_lastAIAction == "buy")
      {
         ArrayResize(directionsToTest, 1);
         directionsToTest[0] = "BUY";
         dirCount = 1;
      }
      else if(g_lastAIAction == "SELL" || g_lastAIAction == "sell")
      {
         ArrayResize(directionsToTest, 1);
         directionsToTest[0] = "SELL";
         dirCount = 1;
      }
      else if(g_lastAIAction == "HOLD" || g_lastAIAction == "hold")
      {
         return;  // Pas d'entrée si HOLD
      }
   }
   else
   {
      // Mode sans IA: tester les deux directions (contrôle de position)
      ArrayResize(directionsToTest, 2);
      directionsToTest[0] = "BUY";
      directionsToTest[1] = "SELL";
      dirCount = 2;
   }

   // Boucle sur chaque direction à tester
   for(int d = 0; d < dirCount; d++)
   {
      string direction = directionsToTest[d];

      // NOUVEAU: Filtrer par prédiction candlestick si activée
      if(UseCandlestickPrediction && candlePred.confidence >= MinCandlePatternConfidence)
      {
         if(candlePred.direction != direction && candlePred.direction != "HOLD")
         {
            if(AdvancedEntryLogPatternDetails)
            {
               Print("🚫 CANDLESTICK FILTER - ", direction, 
                     " | Prediction: ", candlePred.direction,
                     " | Conf: ", DoubleToString(candlePred.confidence, 1), "%");
            }
            continue;  // Direction non alignée avec la prédiction pattern
         }
         if(AdvancedEntryLogPatternDetails && candlePred.direction == direction)
         {
            Print("✅ CANDLESTICK ALIGN - ", direction,
                  " | Conf: ", DoubleToString(candlePred.confidence, 1), "%",
                  " | Pattern: ", candlePred.dominantPattern);
         }
      }

      // Calculer le score complet du setup
      SetupScore setupScore;
      if(!CalculateCompleteSetupScore(direction, setupScore))
         continue;  // Pas de pattern valide pour cette direction

      // Vérifier que le score dépasse le seuil (75% par défaut ou personnalisé)
      if(setupScore.totalScore < AdvancedEntryMinimumScorePercent)
      {
         if(AdvancedEntryLogPatternDetails)
         {
            Print("⚠️  SETUP REJECTED - ", direction, " | Score: ", 
                  DoubleToString(setupScore.totalScore, 1), "% < ", 
                  DoubleToString(AdvancedEntryMinimumScorePercent, 1), "%");
         }
         continue;
      }

      if(AdvancedEntryLogPatternDetails)
      {
         Print("✅ SETUP ACCEPTED - ", direction, 
               " | Pattern: ", DoubleToString(setupScore.patternScore, 1), "% | ",
               "Confluence: ", DoubleToString(setupScore.confluenceScore, 1), "%");
      }

      // Déterminer les niveaux d'entrée, SL, TP
      double entryPrice, stopLoss, takeProfit;
      string entryReason;

      if(!DetermineAdvancedEntryLevels(direction, entryPrice, stopLoss, takeProfit, entryReason))
         continue;

      // Vérifications de sécurité finales
      if(!ValidateEntryPrice(direction, entryPrice))
         continue;

      // Filtres supplémentaires (IA confiance, alignement multi-TF, etc.)
      if(UseAIServer)
      {
         double minConf = (double)OTESetupMarketMinAIConfidencePercent / 100.0;
         if(g_lastAIConfidence < minConf)
         {
            if(AdvancedEntryLogPatternDetails)
            {
               Print("❌ IA CONFIDENCE FILTER - ", direction, 
                     " | Conf: ", DoubleToString(g_lastAIConfidence * 100.0, 1), 
                     "% < ", DoubleToString(minConf * 100.0, 1), "%");
            }
            continue;
         }
      }

      if(cat == SYM_BOOM_CRASH)
      {
         if(!IsBoomCrashDirectionAllowedByIA(_Symbol, direction))
            continue;
      }
      else if(!PassDiscretionaryMacroContextForDirection(direction))
      {
         if(AdvancedEntryLogPatternDetails)
            Print("🚫 MACRO+RANGE - ADV_PA skip | ", _Symbol, " | ", direction);
         continue;
      }

      if(!TryAcquireOpenLock())
         continue;
      if(ExecuteAdvancedEntry(direction, entryPrice, stopLoss, takeProfit, entryReason))
      {
         if(AdvancedEntryLogPatternDetails)
            Print("✅ ADV_PA EXÉCUTÉ | ", _Symbol, " | ", direction, " | ", entryReason);
         ReleaseOpenLock();
         return;
      }
      ReleaseOpenLock();
   }
}

//+------------------------------------------------------------------+
//| VALIDER LE PRIX D'ENTRÉE                                       |
//+------------------------------------------------------------------+

bool ValidateEntryPrice(const string direction, double entryPrice)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = ask - bid;
   double maxSpread = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;

   // Vérifier que le spread n'est pas trop large
   if(spread > maxSpread)
      return false;

   // Vérifier que le prix d'entrée est raisonnable
   if(direction == "BUY" && entryPrice > ask + spread)
      return false;
   if(direction == "SELL" && entryPrice < bid - spread)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| EXÉCUTER L'ENTRÉE ADVANCED PRICE ACTION                        |
//+------------------------------------------------------------------+

bool ExecuteAdvancedEntry(const string direction, 
                          double entryPrice, 
                          double stopLoss, 
                          double takeProfit,
                          const string reason)
{
   // Calcul de la taille de position
   double lot = CalculateLotSize();
   if(lot <= 0.0)
      return false;

   // Appliquer le hard cap SL si configuré
   const double maxLossUsd = 3.5;
   double lotAdjusted = lot;
   double slAdjusted = stopLoss;

   if(!ApplyHardMaxLossUsdToStopLoss(_Symbol, direction, entryPrice, lotAdjusted, maxLossUsd, slAdjusted))
      return false;

   lot = lotAdjusted;
   stopLoss = slAdjusted;
   {
      double mkt = (direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(mkt > 0.0) entryPrice = mkt;
      ValidateAndAdjustStopLossTakeProfit(direction, entryPrice, stopLoss, takeProfit);
   }

   // Normaliser les prix
   entryPrice = NormalizeDouble(entryPrice, _Digits);
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);

   // Exécuter au marché
   bool result = false;
   string comment = "ADV_PA_" + reason + "_" + direction;

   if(direction == "BUY")
   {
      result = trade.Buy(lot, _Symbol, 0.0, stopLoss, takeProfit, comment);
   }
   else if(direction == "SELL")
   {
      result = trade.Sell(lot, _Symbol, 0.0, stopLoss, takeProfit, comment);
   }

   return result;
}

//+------------------------------------------------------------------+
//| HELPER: Vérifier si le trading est autorisé maintenant         |
//+------------------------------------------------------------------+

bool IsTradingTimeValid()
{
   // Implémenter les vérifications de temps de trading
   // (peut être une fonction existante dans SMC_Universal)
   return true;  // Placeholder
}

#endif // __SMC_ENHANCED_ENTRY_INTEGRATION_MQH__
