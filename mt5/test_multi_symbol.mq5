//+------------------------------------------------------------------+
//| Test de l'analyse multi-symboles pour fx_robot2.mq5               |
//+------------------------------------------------------------------+
#property script_show_inputs

// Paramètres de test
input string TestSymbol1 = "Boom 1000 Index";
input string TestSymbol2 = "Crash 1000 Index";
input ENUM_TIMEFRAMES TestTimeframe = PERIOD_M1;

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("=== Test de l'analyse multi-symboles ===");
    
    // Tableau de symboles à tester
    string symbols[] = {TestSymbol1, TestSymbol2};
    
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        string symbol = symbols[i];
        
        Print("Test du symbole: ", symbol);
        
        // Vérifier si le symbole existe
        if(!SymbolInfoString(symbol, SYMBOL_DESCRIPTION, symbol))
        {
            Print("❌ Symbole ", symbol, " non trouvé ou invalide");
            continue;
        }
        
        // Sélectionner le symbole
        if(!SymbolSelect(symbol, true))
        {
            Print("❌ Impossible de sélectionner le symbole: ", symbol);
            continue;
        }
        
        // Obtenir des données de prix
        MqlRates rates[];
        int copied = CopyRates(symbol, TestTimeframe, 0, 10, rates);
        
        if(copied > 0)
        {
            Print("✅ Symbole ", symbol, " - ", copied, " bougies récupérées");
            Print("   Dernier prix: ", rates[0].close);
            
            // Tester la fonction IsSpikeDetectedForSymbol
            double spikeStrength = 0;
            int spikeDirection = 0;
            bool spikeDetected = IsSpikeDetectedForSymbol(symbol, TestTimeframe, spikeStrength, spikeDirection);
            
            if(spikeDetected)
            {
                Print("🔥 Spike détecté sur ", symbol, " - Direction: ", (spikeDirection > 0 ? "BUY" : "SELL"), ", Force: ", spikeStrength);
            }
            else
            {
                Print("📊 Aucun spike détecté sur ", symbol);
            }
            
            // Tester les fonctions de calcul
            double vpin = ComputeVPINForSymbol(symbol, 20, TestTimeframe);
            double obi = ComputeOBIForSymbol(symbol, 20, TestTimeframe);
            double cvd = ComputeCVDForSymbol(symbol, 20, TestTimeframe);
            
            Print("   VPIN: ", DoubleToString(vpin, 4));
            Print("   OBI: ", DoubleToString(obi, 4));
            Print("   CVD: ", DoubleToString(cvd, 2));
        }
        else
        {
            Print("❌ Impossible d'obtenir les données pour ", symbol);
        }
        
        Print("");
    }
    
    Print("=== Test terminé ===");
}

//+------------------------------------------------------------------+
//| Fonctions de test (copies simplifiées)                           |
//+------------------------------------------------------------------+
bool IsSpikeDetectedForSymbol(string symbol, ENUM_TIMEFRAMES tf, double &spikeStrength, int &spikeDirection)
{
    MqlRates rates[];
    int lookback = 20;
    if(CopyRates(symbol, tf, 0, lookback, rates) < lookback) return false;
    
    // Calculer la moyenne et l'écart-type des mouvements
    double moves[];
    ArrayResize(moves, lookback - 1);
    double sumMoves = 0;
    
    for(int i = 0; i < lookback - 1; i++)
    {
        moves[i] = MathAbs(rates[i].close - rates[i+1].close);
        sumMoves += moves[i];
    }
    
    double avgMove = sumMoves / (lookback - 1);
    if(avgMove <= 0) return false;
    
    // Calculer l'écart-type
    double variance = 0;
    for(int i = 0; i < lookback - 1; i++)
    {
        variance += MathPow(moves[i] - avgMove, 2);
    }
    double stdDev = MathSqrt(variance / (lookback - 1));
    
    // Mouvement actuel
    double currentMove = MathAbs(rates[0].close - rates[0].open);
    
    // Z-Score du mouvement
    double zScore = (currentMove - avgMove) / (stdDev > 0 ? stdDev : avgMove);
    
    // Détecter le spike si le mouvement est significatif
    double zScoreThreshold = (tf == PERIOD_M1) ? 1.0 : 1.5;
    double moveMultiplier = (tf == PERIOD_M1) ? 1.5 : 2.0;
    
    bool isSpike = (zScore > zScoreThreshold) || (currentMove > avgMove * moveMultiplier);
    
    if(isSpike)
    {
        spikeStrength = zScore * 20;
        spikeDirection = (rates[0].close > rates[0].open) ? 1 : -1;
        return true;
    }
    
    return false;
}

double ComputeVPINForSymbol(string symbol, int windowBars, ENUM_TIMEFRAMES tf)
{
    if(windowBars <= 10) return 0.0;
    MqlRates rates[];
    int copied = CopyRates(symbol, tf, 1, windowBars, rates);
    if(copied <= 0) return 0.0;
    double buyVol=0.0, sellVol=0.0, totalVol=0.0;
    for(int i=0; i<copied; i++)
    {
        long tv = rates[i].tick_volume;
        totalVol += (double)tv;
        if(rates[i].close > rates[i].open) buyVol += (double)tv;
        else if(rates[i].close < rates[i].open) sellVol += (double)tv;
        else { buyVol += (double)tv*0.5; sellVol += (double)tv*0.5; }
    }
    if(totalVol <= 0.0) return 0.0;
    return MathAbs(buyVol - sellVol) / totalVol;
}

double ComputeOBIForSymbol(string symbol, int lookbackBars, ENUM_TIMEFRAMES tf)
{
    if(lookbackBars <= 10) return 0.0;
    MqlRates rates[];
    int copied = CopyRates(symbol, tf, 1, lookbackBars, rates);
    if(copied <= 0) return 0.0;
    double buyVol=0.0, sellVol=0.0;
    for(int i=0; i<copied; i++)
    {
        long tv = rates[i].tick_volume;
        if(rates[i].close > rates[i].open) buyVol += (double)tv;
        else if(rates[i].close < rates[i].open) sellVol += (double)tv;
    }
    double total = buyVol + sellVol;
    if(total <= 0.0) return 0.0;
    return (buyVol - sellVol) / total;
}

double ComputeCVDForSymbol(string symbol, int windowBars, ENUM_TIMEFRAMES tf)
{
    if(windowBars <= 5) return 0.0;
    MqlRates rates[];
    int copied = CopyRates(symbol, tf, 1, windowBars, rates);
    if(copied <= 0) return 0.0;
    double cvd = 0.0;
    for(int i=0; i<copied; i++)
    {
        double sign = 0.0;
        if(rates[i].close > rates[i].open) sign = 1.0;
        else if(rates[i].close < rates[i].open) sign = -1.0;
        cvd += sign * (double)rates[i].tick_volume;
    }
    return cvd;
}
