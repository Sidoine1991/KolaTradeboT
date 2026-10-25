//+------------------------------------------------------------------+
//| Initialiser la gestion autonome du capital                      |
//+------------------------------------------------------------------+
void InitializeAutonomousManagement()
{
    g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    g_currentBalance = g_initialBalance;
    g_lastDayReset = TimeCurrent();
    g_dailyProfit = 0;
    g_dailyLoss = 0;
    g_consecutiveWins = 0;
    g_consecutiveLosses = 0;
    g_totalProfit = 0;
    g_totalLoss = 0;
    g_currentStrategy = InpStrategyPriority;
    g_lastStrategyChange = TimeCurrent();
    ArrayResize(g_strategyPerformance, 4);
    for(int i = 0; i < 4; i++) g_strategyPerformance[i] = 0.0;
    g_martingaleLevel = 0;
    g_martingaleLot = 0;
    g_martingaleLoss = 0;
    g_pyramidLevel = 0;
    g_pyramidProfit = 0;
    Print("💰 Gestion autonome initialisée - Solde: $", DoubleToString(g_initialBalance, 2));
}

//+------------------------------------------------------------------+
//| Calculer le lot intelligent basé sur la gestion autonome       |
//+------------------------------------------------------------------+
double CalculateIntelligentLot(const string symbol, int direction)
{
    if(!InpAutoCapitalManagement)
    {
        return CalculateBoomCrashLot(symbol);
    }
    
    g_currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = g_currentBalance * (InpMaxRiskPerTrade / 100.0);
    double pointValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double stopDistance = InpMinSLDistance * SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if(pointValue > 0 && stopDistance > 0)
    {
        double calculatedLot = riskAmount / (stopDistance * pointValue);
        double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
        
        calculatedLot = MathMax(calculatedLot, minLot);
        calculatedLot = MathMin(calculatedLot, maxLot);
        calculatedLot = MathRound(calculatedLot / lotStep) * lotStep;
        
        if(g_consecutiveWins > 0)
        {
            calculatedLot *= MathPow(InpCapitalMultiplier, MathMin(g_consecutiveWins, 3));
        }
        
        if(InpUseMartingale && g_martingaleLevel > 0)
        {
            calculatedLot = g_martingaleLot * MathPow(InpMartingaleMultiplier, g_martingaleLevel);
        }
        
        calculatedLot = MathMin(calculatedLot, InpMaxLotSize);
        
        if(InpDebug)
        {
            Print("💰 Lot intelligent: ", DoubleToString(calculatedLot, 2), 
                  " - Risque: $", DoubleToString(riskAmount, 2),
                  " - Wins: ", g_consecutiveWins,
                  " - Martingale: ", g_martingaleLevel);
        }
        
        return calculatedLot;
    }
    
    return CalculateBoomCrashLot(symbol);
}

//+------------------------------------------------------------------+
//| Gérer le trailing stop intelligent                              |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
    if(!InpUseTrailingStop) return;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double currentSL = PositionGetDouble(POSITION_SL);
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        
        if(point <= 0) continue;
        
        double profit = PositionGetDouble(POSITION_PROFIT);
        double profitPoints = 0;
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            profitPoints = (currentPrice - openPrice) / point;
            if(profitPoints >= InpTrailingStart)
            {
                double newSL = currentPrice - (InpTrailingStopLoss * point);
                if(newSL > currentSL + (InpTrailingStep * point))
                {
                    if(g_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
                    {
                        Print("📈 Trailing Stop: ", symbol, " - SL: ", newSL, " - Profit: $", DoubleToString(profit, 2));
                    }
                }
            }
        }
        else
        {
            profitPoints = (openPrice - currentPrice) / point;
            if(profitPoints >= InpTrailingStart)
            {
                double newSL = currentPrice + (InpTrailingStopLoss * point);
                if(newSL < currentSL - (InpTrailingStep * point))
                {
                    if(g_trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
                    {
                        Print("📉 Trailing Stop: ", symbol, " - SL: ", newSL, " - Profit: $", DoubleToString(profit, 2));
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour les statistiques journalières                     |
//+------------------------------------------------------------------+
void UpdateDailyStatistics()
{
    static datetime lastUpdate = 0;
    if(TimeCurrent() - lastUpdate < 60) return; // Mettre à jour toutes les minutes
    lastUpdate = TimeCurrent();
    
    g_currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    // Réinitialiser les statistiques journalières à minuit
    if(TimeDay(TimeCurrent()) != TimeDay(g_lastDayReset))
    {
        g_dailyProfit = 0;
        g_dailyLoss = 0;
        g_lastDayReset = TimeCurrent();
        Print("📅 Nouveau jour - Statistiques réinitialisées");
    }
    
    // Afficher les statistiques toutes les heures
    if(InpDebug && TimeMinute(TimeCurrent()) == 0)
    {
        Print("📊 STATISTIQUES JOURNALIERES:");
        Print("   💰 Solde actuel: $", DoubleToString(g_currentBalance, 2));
        Print("   📈 Profit journalier: $", DoubleToString(g_dailyProfit, 2));
        Print("   📉 Perte journalière: $", DoubleToString(g_dailyLoss, 2));
        Print("   🎯 Consecutive Wins: ", g_consecutiveWins);
        Print("   ❌ Consecutive Losses: ", g_consecutiveLosses);
        Print("   🔄 Martingale Level: ", g_martingaleLevel);
    }
}

//+------------------------------------------------------------------+
//| Obtenir le nom de la stratégie                                  |
//+------------------------------------------------------------------+
string GetStrategyName(int strategy)
{
    switch(strategy)
    {
        case 1: return "SCALPING";
        case 2: return "SWING TRADING";
        case 3: return "BREAKOUT";
        case 4: return "REVERSAL";
        default: return "INCONNUE";
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour les statistiques de trading                       |
//+------------------------------------------------------------------+
void UpdateTradingStatistics(double profit)
{
    if(profit > 0)
    {
        g_consecutiveWins++;
        g_consecutiveLosses = 0;
        g_dailyProfit += profit;
        g_totalProfit += profit;
        
        // Réinitialiser le martingale après un gain
        g_martingaleLevel = 0;
        g_martingaleLoss = 0;
        
        Print("✅ Trade gagnant: +$", DoubleToString(profit, 2), " - Consecutive Wins: ", g_consecutiveWins);
    }
    else
    {
        g_consecutiveLosses++;
        g_consecutiveWins = 0;
        g_dailyLoss += MathAbs(profit);
        g_totalLoss += MathAbs(profit);
        
        // Mettre à jour le martingale
        if(InpUseMartingale)
        {
            g_martingaleLevel++;
            g_martingaleLoss += MathAbs(profit);
        }
        
        Print("❌ Trade perdant: -$", DoubleToString(MathAbs(profit), 2), " - Consecutive Losses: ", g_consecutiveLosses);
    }
    
    // Vérifier les limites de risque journalier
    double dailyRisk = (g_dailyLoss / g_currentBalance) * 100.0;
    if(dailyRisk >= InpMaxDailyRisk)
    {
        Print("⚠️ Limite de risque journalier atteinte: ", DoubleToString(dailyRisk, 1), "%");
        // Arrêter le trading pour la journée
    }
}
