//+------------------------------------------------------------------+
//|                                            Test_SpikeHunter.mq5 |
//|                        Copyright 2025, Test Spike Hunter EA     |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Test Spike Hunter EA"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Test des paramètres de lot pour Boom/Crash"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("🧪 TEST DES PARAMÈTRES DE LOT POUR BOOM/CRASH");
    Print("================================================");
    
    // Tester différents symboles
    string symbols[] = {"Boom 1000 Index", "Crash 1000 Index", "Boom 500 Index", "Crash 500 Index"};
    
    for(int i = 0; i < ArraySize(symbols); i++) {
        string symbol = symbols[i];
        
        if(SymbolSelect(symbol, true)) {
            Print("\n📊 SYMBOLE: ", symbol);
            
            double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
            double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
            double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
            double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
            
            Print("   Lot minimum: ", DoubleToString(minLot, 2));
            Print("   Lot maximum: ", DoubleToString(maxLot, 2));
            Print("   Step de lot: ", DoubleToString(lotStep, 2));
            Print("   Taille tick: ", DoubleToString(tickSize, 5));
            Print("   Valeur tick: ", DoubleToString(tickValue, 2));
            
            // Tester différents lots
            double testLots[] = {0.01, 0.1, 0.2, 0.5, 1.0};
            
            for(int j = 0; j < ArraySize(testLots); j++) {
                double testLot = testLots[j];
                double normalizedLot = NormalizeLot(symbol, testLot);
                
                Print("   Test lot ", DoubleToString(testLot, 2), 
                      " -> Normalisé: ", DoubleToString(normalizedLot, 2),
                      " (", (normalizedLot > 0 ? "✅ VALIDE" : "❌ INVALIDE"), ")");
            }
        } else {
            Print("❌ Symbole non disponible: ", symbol);
        }
    }
    
    Print("\n✅ TEST TERMINÉ");
}

//+------------------------------------------------------------------+
//| Normaliser un lot selon les contraintes du symbole              |
//+------------------------------------------------------------------+
double NormalizeLot(string symbol, double lotSize)
{
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // S'assurer que le lot est dans les limites
    if(lotSize < minLot) lotSize = minLot;
    if(lotSize > maxLot) lotSize = maxLot;
    
    // Normaliser selon le step
    lotSize = MathRound(lotSize / lotStep) * lotStep;
    
    // Vérifier que le lot est valide
    if(lotSize < minLot || lotSize > maxLot) {
        return 0;
    }
    
    return lotSize;
}
