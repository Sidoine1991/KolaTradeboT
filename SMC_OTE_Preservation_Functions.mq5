//+------------------------------------------------------------------+
//| FONCTIONS DE PRÉSERVATION DES GAINS - APPROCHE SCIENTIFIQUE      |
//+------------------------------------------------------------------+

// Initialiser le système de préservation des gains
void InitializeGainPreservationSystem()
{
   g_dailyStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquity = g_dailyStartEquity;
   g_protectionActive = false;
   g_protectionStartTime = 0;
   
   // Initialiser les trackers OTE
   ArrayInitialize(g_activeOTESetups, 0);
   
   Print("🛡️ SYSTÈME DE PRÉSERVATION DES GAINS INITIALISÉ");
   Print("   💰 Équité de départ: ", DoubleToString(g_dailyStartEquity, 2), "$");
   Print("   🎯 Seuil de protection: ", DoubleToString(DailyGainProtectionThreshold, 2), "$");
   Print("   📉 Max drawdown après protection: ", DoubleToString(MaxDrawdownAfterProtection, 2), "$");
}

// Mettre à jour le système de préservation des gains
void UpdateGainPreservationSystem()
{
   if(!UseGainPreservationSystem) return;
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyProfit = currentEquity - g_dailyStartEquity;
   
   // Mettre à jour le pic d'équité
   if(currentEquity > g_peakEquity)
      g_peakEquity = currentEquity;
   
   // Vérifier si on doit activer la protection
   if(!g_protectionActive && dailyProfit >= DailyGainProtectionThreshold)
   {
      ActivateGainProtection();
   }
   
   // Si la protection est active, vérifier le drawdown
   if(g_protectionActive)
   {
      double drawdown = g_peakEquity - currentEquity;
      
      // Logs de surveillance toutes les 60 secondes
      static datetime lastLogTime = 0;
      if(TimeCurrent() - lastLogTime >= 60)
      {
         Print("🛡️ PROTECTION GAINS ACTIVE - Accumulé: ", DoubleToString(dailyProfit, 2), "$");
         Print("   📉 Drawdown actuel: ", DoubleToString(drawdown, 2), "$ / ", DoubleToString(MaxDrawdownAfterProtection, 2), "$ max");
         lastLogTime = TimeCurrent();
      }
      
      // Si le drawdown dépasse le maximum, fermer toutes les positions
      if(drawdown >= MaxDrawdownAfterProtection)
      {
         Print("🚨 PERTE MAXIMALE ATTEINTE - Drawdown: ", DoubleToString(drawdown, 2), "$ ≥ ", DoubleToString(MaxDrawdownAfterProtection, 2), "$");
         Print("   🔄 Fermeture de toutes les positions pour protéger les gains accumulés");
         
         CloseAllPositionsForGainProtection();
         DeactivateGainProtection();
      }
   }
}

// Activer la protection des gains
void ActivateGainProtection()
{
   g_protectionActive = true;
   g_protectionStartTime = TimeCurrent();
   
   double dailyProfit = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartEquity;
   
   Print("🛡️ PROTECTION GAINS ACTIVÉE - Gains accumulés: ", DoubleToString(dailyProfit, 2), "$ ≥ ", DoubleToString(DailyGainProtectionThreshold, 2), "$");
   Print("   💰 Sommet atteint: ", DoubleToString(g_peakEquity, 2), "$");
   Print("   🚫 Perte maximale autorisée: ", DoubleToString(MaxDrawdownAfterProtection, 2), "$");
}

// Désactiver la protection des gains
void DeactivateGainProtection()
{
   g_protectionActive = false;
   g_protectionStartTime = 0;
   g_lastProtectionCooldown = TimeCurrent();
   
   Print("✅ PROTECTION GAINS DÉSACTIVÉE - Période de refroidissement activée");
}

// Fermer toutes les positions pour la protection des gains
void CloseAllPositionsForGainProtection()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByIndex(i))
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double profit = PositionGetDouble(POSITION_PROFIT);
         
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            bool success = PositionCloseWithLog(ticket, "Protection gains accumulés - perte max atteinte");
            if(success)
            {
               Print("✅ Position fermée - ", symbol, ": ", DoubleToString(profit, 2), "$ (Protection gains accumulés)");
            }
         }
      }
   }
   
   // Annuler aussi tous les ordres pending
   CancelAllPendingOrdersForGainProtection();
}

// Annuler tous les ordres pending pour la protection
void CancelAllPendingOrdersForGainProtection()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            ulong ticket = OrderGetTicket(i);
            MqlTradeRequest req = {0};
            MqlTradeResult res = {0};
            
            req.action = TRADE_ACTION_REMOVE;
            req.order = ticket;
            
            if(OrderSend(req, res))
            {
               Print("✅ Ordre annulé - Ticket: ", ticket, " (Protection gains accumulés)");
            }
         }
      }
   }
}

// Vérifier si le trading est autorisé (protection gains)
bool IsTradingAllowedForGainPreservation()
{
   if(!UseGainPreservationSystem) return true;
   
   // Si la protection est active, bloquer les nouveaux trades
   if(g_protectionActive)
   {
      static datetime lastBlockLog = 0;
      if(TimeCurrent() - lastBlockLog >= 60) // Log toutes les minutes
      {
         Print("🚫 TRADES BLOQUÉS - Protection gains accumulés active");
         lastBlockLog = TimeCurrent();
      }
      return false;
   }
   
   // Période de refroidissement après protection
   if(g_lastProtectionCooldown > 0)
   {
      int cooldownRemaining = (int)(g_lastProtectionCooldown + ProtectionCooldownMinutes * 60 - TimeCurrent());
      if(cooldownRemaining > 0)
      {
         static datetime lastCooldownLog = 0;
         if(TimeCurrent() - lastCooldownLog >= 120) // Log toutes les 2 minutes
         {
            Print("⏳ PÉRIODE DE REFROIDISSEMENT - ", cooldownRemaining / 60, "min ", cooldownRemaining % 60, "s restantes");
            lastCooldownLog = TimeCurrent();
         }
         return false;
      }
      else
      {
         g_lastProtectionCooldown = 0; // Fin du refroidissement
         Print("✅ PÉRIODE DE REFROIDISSEMENT TERMINÉE - Trading autorisé");
      }
   }
   
   return true;
}

// Calculer l'espérance mathématique d'un trade
double CalculateTradeExpectancy(string direction, double entryPrice, double stopLoss, double takeProfit)
{
   // Calculer les ratios
   double risk = MathAbs(entryPrice - stopLoss);
   double reward = MathAbs(takeProfit - entryPrice);
   
   if(risk <= 0) return 0.0;
   
   double riskRewardRatio = reward / risk;
   
   // Estimer la probabilité de succès basée sur:
   // 1. Ratio R/R
   // 2. Confiance IA
   // 3. Alignement de tendance
   // 4. Distance OTE
   
   double baseProbability = 0.5; // 50% de base
   
   // Ajuster selon le ratio R/R
   if(riskRewardRatio >= 3.0) baseProbability += 0.15;
   else if(riskRewardRatio >= 2.0) baseProbability += 0.10;
   else if(riskRewardRatio >= 1.5) baseProbability += 0.05;
   
   // Ajuster selon la confiance IA
   if(g_lastAIConfidence >= 80.0) baseProbability += 0.10;
   else if(g_lastAIConfidence >= 70.0) baseProbability += 0.05;
   
   // Ajuster selon l'alignement de tendance
   string trendDirection = GetCurrentTrendDirection();
   if((direction == "BUY" && trendDirection == "UPTREND") ||
      (direction == "SELL" && trendDirection == "DOWNTREND"))
   {
      baseProbability += 0.08;
   }
   
   // Limiter la probabilité entre 0.3 et 0.8
   if(baseProbability > 0.8) baseProbability = 0.8;
   if(baseProbability < 0.3) baseProbability = 0.3;
   
   // Calculer l'espérance: E = p × W - (1-p) × L
   double expectancy = baseProbability * riskRewardRatio - (1.0 - baseProbability) * 1.0;
   
   return expectancy;
}

//+------------------------------------------------------------------+
//| FONCTIONS OTE AMÉLIORÉES - ENTRÉE AVANT OTE               |
//+------------------------------------------------------------------+

// Ajouter un setup OTE au suivi
int AddOTESetup(double entryPrice, double stopLoss, double takeProfit, string direction)
{
   // Trouver un slot libre
   int slot = -1;
   for(int i = 0; i < ArraySize(g_activeOTESetups); i++)
   {
      if(!g_activeOTESetups[i].isValid)
      {
         slot = i;
         break;
      }
   }
   
   if(slot == -1) return -1; // Pas de slot libre
   
   // Remplir la structure
   g_activeOTESetups[slot].setupTime = TimeCurrent();
   g_activeOTESetups[slot].entryPrice = entryPrice;
   g_activeOTESetups[slot].stopLoss = stopLoss;
   g_activeOTESetups[slot].takeProfit = takeProfit;
   g_activeOTESetups[slot].direction = direction;
   g_activeOTESetups[slot].isValid = true;
   g_activeOTESetups[slot].orderId = 0;
   g_activeOTESetups[slot].setupId = g_nextOTESetupId++;
   
   Print("📍 SETUP OTE AJOUTÉ - ID: ", g_activeOTESetups[slot].setupId, " | ", direction);
   Print("   📍 Entry: ", DoubleToString(entryPrice, _Digits));
   Print("   🛡️ SL: ", DoubleToString(stopLoss, _Digits));
   Print("   🎯 TP: ", DoubleToString(takeProfit, _Digits));
   
   return g_activeOTESetups[slot].setupId;
}

// Vérifier si un setup OTE est toujours valide
bool IsOTESetupStillValid(int setupId)
{
   for(int i = 0; i < ArraySize(g_activeOTESetups); i++)
   {
      if(g_activeOTESetups[i].isValid && g_activeOTESetups[i].setupId == setupId)
      {
         // Vérifier l'âge du setup (max 2 heures)
         if(TimeCurrent() - g_activeOTESetups[i].setupTime > 7200)
         {
            Print("⏰ SETUP OTE EXPIRÉ - ID: ", setupId, " (> 2 heures)");
            g_activeOTESetups[i].isValid = false;
            return false;
         }
         
         // Vérifier si la structure SMC est toujours valide
         if(!IsSMCStructureStillValid(g_activeOTESetups[i].direction))
         {
            Print("❌ SETUP OTE INVALIDÉ - ID: ", setupId, " | Structure SMC rompue");
            g_activeOTESetups[i].isValid = false;
            return false;
         }
         
         return true;
      }
   }
   
   return false; // Setup non trouvé
}

// Vérifier si la structure SMC est toujours valide
bool IsSMCStructureStillValid(string direction)
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Vérifier les swing points récents
   double recentSwingHigh = 0, recentSwingLow = 0;
   datetime recentSwingHighTime = 0, recentSwingLowTime = 0;
   
   // Chercher les swing points dans les 50 dernières bougies
   if(!GetRecentSwingPoints(50, recentSwingHigh, recentSwingLow, recentSwingHighTime, recentSwingLowTime))
      return true; // Pas assez de données, considérer comme valide
   
   // Pour un setup BUY: le prix ne doit pas casser le swing low récent
   if(direction == "BUY" && recentSwingLow > 0)
   {
      if(currentPrice < recentSwingLow - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10)
      {
         Print("🚨 STRUCTURE BUY INVALIDÉE - Prix sous swing low récent");
         return false;
      }
   }
   
   // Pour un setup SELL: le prix ne doit pas casser le swing high récent
   if(direction == "SELL" && recentSwingHigh > 0)
   {
      if(currentPrice > recentSwingHigh + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10)
      {
         Print("🚨 STRUCTURE SELL INVALIDÉE - Prix au-dessus swing high récent");
         return false;
      }
   }
   
   return true;
}

// Obtenir les swing points récents
bool GetRecentSwingPoints(int lookback, double &swingHigh, double &swingLow, datetime &swingHighTime, datetime &swingLowTime)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, lookback, rates) < lookback)
      return false;
   
   swingHigh = 0;
   swingLow = DBL_MAX;
   swingHighTime = 0;
   swingLowTime = 0;
   
   // Identifier les swing points (simple pour l'instant)
   for(int i = 2; i < lookback - 2; i++)
   {
      // Swing High
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
         rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
      {
         if(rates[i].high > swingHigh)
         {
            swingHigh = rates[i].high;
            swingHighTime = rates[i].time;
         }
      }
      
      // Swing Low
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
         rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
      {
         if(rates[i].low < swingLow)
         {
            swingLow = rates[i].low;
            swingLowTime = rates[i].time;
         }
      }
   }
   
   return (swingHigh > 0 && swingLow < DBL_MAX);
}

// Exécuter une entrée avant l'OTE pour capturer les spikes
void ExecutePreOTESpikeEntry(string direction, double oteEntryPrice, double stopLoss, double takeProfit)
{
   if(!UsePreOTEEntry) return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, (direction == "BUY") ? SYMBOL_ASK : SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculer le prix d'entrée avant l'OTE
   double preOTEEntryPrice;
   if(direction == "BUY")
   {
      preOTEEntryPrice = oteEntryPrice - (oteEntryPrice * PreOTEEntryDistancePercent / 100.0);
      // S'assurer que le prix est au-dessus du prix actuel pour BUY
      if(preOTEEntryPrice < currentPrice)
         preOTEEntryPrice = currentPrice + point * 5;
   }
   else // SELL
   {
      preOTEEntryPrice = oteEntryPrice + (oteEntryPrice * PreOTEEntryDistancePercent / 100.0);
      // S'assurer que le prix est en-dessous du prix actuel pour SELL
      if(preOTEEntryPrice > currentPrice)
         preOTEEntryPrice = currentPrice - point * 5;
   }
   
   // Calculer l'espérance mathématique
   double expectancy = CalculateTradeExpectancy(direction, preOTEEntryPrice, stopLoss, takeProfit);
   
   if(expectancy < MinExpectancyThreshold)
   {
      Print("🚫 ENTRÉE PRÉ-OTE BLOQUÉE - Espérance: ", DoubleToString(expectancy, 3), " < ", DoubleToString(MinExpectancyThreshold, 3));
      return;
   }
   
   // Vérifier si le trading est autorisé
   if(!IsTradingAllowedForGainPreservation())
   {
      Print("🚫 ENTRÉE PRÉ-OTE BLOQUÉE - Protection gains active");
      return;
   }
   
   double lot = NormalizeVolumeForSymbol(GetMinLotForSymbol(_Symbol));
   if(lot <= 0.0)
   {
      Print("❌ ENTRÉE PRÉ-OTE BLOQUÉE - lot minimum indisponible");
      return;
   }
   
   // Exécuter l'ordre au marché
   bool success = false;
   string comment = "PRE_OTE_SPIKE_" + direction;
   
   if(direction == "BUY")
   {
      success = trade.Buy(lot, _Symbol, preOTEEntryPrice, stopLoss, takeProfit, comment);
   }
   else
   {
      success = trade.Sell(lot, _Symbol, preOTEEntryPrice, stopLoss, takeProfit, comment);
   }
   
   if(success)
   {
      Print("🚀 ENTRÉE PRÉ-OTE EXÉCUTÉE - ", direction, " sur ", _Symbol);
      Print("   📍 Prix OTE: ", DoubleToString(oteEntryPrice, _Digits));
      Print("   📍 Entrée: ", DoubleToString(preOTEEntryPrice, _Digits), " (", DoubleToString(PreOTEEntryDistancePercent, 1), "% avant OTE)");
      Print("   🛡️ SL: ", DoubleToString(stopLoss, _Digits));
      Print("   🎯 TP: ", DoubleToString(takeProfit, _Digits));
      Print("   📊 Espérance: ", DoubleToString(expectancy, 3));
      Print("   💰 Lot: ", DoubleToString(lot, 2));
   }
   else
   {
      Print("❌ ENTRÉE PRÉ-OTE ÉCHOUÉE - ", direction, " sur ", _Symbol);
      Print("   ❌ Erreur: ", trade.ResultRetcode(), " - ", trade.ResultComment());
   }
}

// Vérifier le toucher du niveau OTE pour exécution au marché
void CheckAndExecuteMarketOnOTETouch()
{
   if(!ExecuteMarketOnOTETouch) return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Parcourir tous les setups OTE actifs
   for(int i = 0; i < ArraySize(g_activeOTESetups); i++)
   {
      if(!g_activeOTESetups[i].isValid) continue;
      
      OTESetupTracker setup = g_activeOTESetups[i];
      
      // Vérifier si le prix touche le niveau d'entrée OTE
      bool touched = false;
      if(setup.direction == "BUY" && askPrice >= setup.entryPrice)
      {
         touched = true;
      }
      else if(setup.direction == "SELL" && currentPrice <= setup.entryPrice)
      {
         touched = true;
      }
      
      if(touched)
      {
         Print("🎯 TOUCHE NIVEAU OTE DÉTECTÉ - ID: ", setup.setupId, " | ", setup.direction);
         Print("   📍 Prix: ", DoubleToString((setup.direction == "BUY") ? askPrice : currentPrice, _Digits));
         Print("   🎯 Niveau OTE: ", DoubleToString(setup.entryPrice, _Digits));
         
         // Exécuter l'ordre au marché
         ExecuteMarketOrderOnOTETouch(setup);
         
         // Marquer le setup comme traité
         g_activeOTESetups[i].isValid = false;
      }
   }
}

// Exécuter l'ordre au marché au toucher OTE
void ExecuteMarketOrderOnOTETouch(OTESetupTracker &setup)
{
   if(!IsTradingAllowedForGainPreservation())
   {
      Print("🚫 EXÉCUTION OTE TOUCH BLOQUÉE - Protection gains active");
      return;
   }
   
   double lot = NormalizeVolumeForSymbol(GetMinLotForSymbol(_Symbol));
   if(lot <= 0.0)
   {
      Print("❌ EXÉCUTION OTE TOUCH BLOQUÉE - lot minimum indisponible");
      return;
   }
   
   // Exécuter l'ordre au marché
   bool success = false;
   string comment = "OTE_TOUCH_MARKET_" + setup.direction;
   
   if(setup.direction == "BUY")
   {
      success = trade.Buy(lot, _Symbol, setup.entryPrice, setup.stopLoss, setup.takeProfit, comment);
   }
   else
   {
      success = trade.Sell(lot, _Symbol, setup.entryPrice, setup.stopLoss, setup.takeProfit, comment);
   }
   
   if(success)
   {
      Print("✅ EXÉCUTION OTE TOUCH RÉUSSIE - ", setup.direction, " sur ", _Symbol);
      Print("   📍 Entry: ", DoubleToString(setup.entryPrice, _Digits));
      Print("   🛡️ SL: ", DoubleToString(setup.stopLoss, _Digits));
      Print("   🎯 TP: ", DoubleToString(setup.takeProfit, _Digits));
      Print("   💰 Lot: ", DoubleToString(lot, 2));
      Print("   📝 Comment: ", comment);
   }
   else
   {
      Print("❌ EXÉCUTION OTE TOUCH ÉCHOUÉE - ", setup.direction, " sur ", _Symbol);
      Print("   ❌ Erreur: ", trade.ResultRetcode(), " - ", trade.ResultComment());
   }
}

// Annuler les ordres OTE si le setup disparaît
void CancelOTESetupsOnInvalidation()
{
   if(!CancelOTEOnSetupInvalidation) return;
   
   for(int i = 0; i < ArraySize(g_activeOTESetups); i++)
   {
      if(!g_activeOTESetups[i].isValid) continue;
      
      // Vérifier si le setup est encore valide
      if(!IsOTESetupStillValid(g_activeOTESetups[i].setupId))
      {
         // Si un ordre pending est associé, l'annuler
         if(g_activeOTESetups[i].orderId > 0)
         {
            MqlTradeRequest req = {0};
            MqlTradeResult res = {0};
            
            req.action = TRADE_ACTION_REMOVE;
            req.order = g_activeOTESetups[i].orderId;
            
            if(OrderSend(req, res))
            {
               Print("✅ ORDRE OTE ANNULÉ - Setup ID: ", g_activeOTESetups[i].setupId, " invalide");
               Print("   🎫 Ticket: ", g_activeOTESetups[i].orderId);
            }
         }
         
         g_activeOTESetups[i].isValid = false;
      }
   }
}

//+------------------------------------------------------------------+
