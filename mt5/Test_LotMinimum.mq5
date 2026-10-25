//+------------------------------------------------------------------+
//|                                            Test_LotMinimum.mq5 |
//|                        Copyright 2025, Test Lot Minimum        |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Test Lot Minimum"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Test du lot minimum 0.2 pour Boom/Crash"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("🧪 TEST DU LOT MINIMUM 0.2 POUR BOOM/CRASH");
    Print("===========================================");
    
    // Tester différents symboles Boom/Crash
    string symbols[] = {"Boom 1000 Index", "Crash 1000 Index", "Boom 500 Index", "Crash 500 Index", "Boom 300 Index", "Crash 300 Index"};
    
    for(int i = 0; i < ArraySize(symbols); i++) {
        string symbol = symbols[i];
        
        if(SymbolSelect(symbol, true)) {
            Print("\n📊 SYMBOLE: ", symbol);
            
            double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
            double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
            
            Print("   Lot minimum broker: ", DoubleToString(minLot, 2));
            Print("   Lot maximum broker: ", DoubleToString(maxLot, 2));
            Print("   Step de lot: ", DoubleToString(lotStep, 2));
            
            // Tester le lot minimum forcé à 0.2
            double forcedLot = MathMax(0.2, minLot);
            Print("   Lot minimum forcé: ", DoubleToString(forcedLot, 2));
            
            // Vérifier si le lot est valide
            bool isValid = (forcedLot >= minLot && forcedLot <= maxLot);
            Print("   Lot valide: ", (isValid ? "✅ OUI" : "❌ NON"));
            
            if(isValid) {
                Print("   ✅ Le lot 0.2 est VALIDE pour ", symbol);
            } else {
                Print("   ❌ Le lot 0.2 n'est PAS VALIDE pour ", symbol);
                Print("   ⚠️  Utilisation du lot minimum du broker: ", DoubleToString(minLot, 2));
            }
        } else {
            Print("❌ Symbole non disponible: ", symbol);
        }
    }
    
    Print("\n🎯 RÉSUMÉ:");
    Print("   - Lot minimum configuré: 0.2");
    Print("   - Pour les indices Boom/Crash, le lot sera au minimum 0.2");
    Print("   - Si le broker exige plus, le lot sera ajusté automatiquement");
    
    Print("\n✅ TEST TERMINÉ");
}

//+------------------------------------------------------------------+
//| Vérifier si c'est un index Boom/Crash                           |
//+------------------------------------------------------------------+
bool IsBoomCrashIndex(string symbol)
{
    return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
}
