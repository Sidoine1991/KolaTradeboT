//+------------------------------------------------------------------+
//|                                        Test_SLTP_Validation.mq5 |
//|                        Copyright 2025, Test SL/TP Validation    |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Test SL/TP Validation"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Test de validation des SL/TP pour éviter les erreurs 'invalid stop'"

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("🧪 TEST DE VALIDATION DES SL/TP");
    Print("===============================");
    
    // Tester différents symboles
    string symbols[] = {"Boom 1000 Index", "Crash 1000 Index", "EURUSD", "GBPUSD"};
    
    for(int i = 0; i < ArraySize(symbols); i++) {
        string symbol = symbols[i];
        
        if(SymbolSelect(symbol, true)) {
            Print("\n📊 SYMBOLE: ", symbol);
            
            // Obtenir les contraintes du symbole
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
            int stops_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double min_distance = stops_level * point;
            
            Print("   Point: ", DoubleToString(point, 5));
            Print("   Digits: ", digits);
            Print("   Stops Level: ", stops_level);
            Print("   Distance min: ", DoubleToString(min_distance, 5), " (", DoubleToString(min_distance/point, 0), " points)");
            
            // Tester les ordres BUY et SELL
            TestOrderType(symbol, 1);  // BUY
            TestOrderType(symbol, -1); // SELL
        } else {
            Print("❌ Symbole non disponible: ", symbol);
        }
    }
    
    Print("\n✅ TEST TERMINÉ");
}

//+------------------------------------------------------------------+
//| Tester un type d'ordre (BUY/SELL)                               |
//+------------------------------------------------------------------+
void TestOrderType(string symbol, int direction)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    int stops_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double min_distance = stops_level * point;
    
    // Prix d'entrée simulé
    double entry_price = (direction > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    
    Print("\n   🎯 ", (direction > 0 ? "BUY" : "SELL"), " @ ", DoubleToString(entry_price, digits));
    
    // Calculer les SL/TP optimaux
    double sl_distance, tp_distance;
    CalculateOptimalSLTP(symbol, entry_price, direction, sl_distance, tp_distance);
    
    // Calculer les prix SL/TP
    double sl_price, tp_price;
    if(direction > 0) { // BUY
        sl_price = entry_price - sl_distance;
        tp_price = entry_price + tp_distance;
    } else { // SELL
        sl_price = entry_price + sl_distance;
        tp_price = entry_price - tp_distance;
    }
    
    // Normaliser les prix
    sl_price = NormalizeDouble(sl_price, digits);
    tp_price = NormalizeDouble(tp_price, digits);
    
    // Afficher les résultats
    Print("   SL: ", DoubleToString(sl_price, digits), " (distance: ", DoubleToString(sl_distance/point, 0), " pts)");
    Print("   TP: ", DoubleToString(tp_price, digits), " (distance: ", DoubleToString(tp_distance/point, 0), " pts)");
    
    // Valider les SL/TP
    bool is_valid = ValidateSLTPPrices(symbol, entry_price, sl_price, tp_price, direction);
    Print("   Validation: ", (is_valid ? "✅ VALIDE" : "❌ INVALIDE"));
    
    if(is_valid) {
        double risk_reward_ratio = tp_distance / sl_distance;
        Print("   Ratio R:R: ", DoubleToString(risk_reward_ratio, 2));
    }
}

//+------------------------------------------------------------------+
//| Calculer les SL/TP optimaux avec ratio risque/récompense        |
//+------------------------------------------------------------------+
void CalculateOptimalSLTP(string symbol, double order_price, int direction, double &sl_distance, double &tp_distance)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int stops_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double min_distance = stops_level * point;
    
    // Pour les indices Boom/Crash, utiliser des distances adaptées
    if(IsBoomCrashIndex(symbol)) {
        // Distances plus petites pour le scalping rapide
        sl_distance = MathMax(min_distance * 3.0, 20 * point); // 3x distance min ou 20 points
        tp_distance = MathMax(min_distance * 5.0, 35 * point); // 5x distance min ou 35 points
    } else {
        // Distances standard pour autres symboles
        sl_distance = MathMax(min_distance * 4.0, 30 * point); // 4x distance min ou 30 points
        tp_distance = MathMax(min_distance * 6.0, 50 * point); // 6x distance min ou 50 points
    }
    
    // S'assurer que TP > SL (ratio risque/récompense minimum 1:1.5)
    double min_ratio = 1.5;
    if(tp_distance < sl_distance * min_ratio) {
        tp_distance = sl_distance * min_ratio;
    }
}

//+------------------------------------------------------------------+
//| Valider les prix SL/TP avant envoi                               |
//+------------------------------------------------------------------+
bool ValidateSLTPPrices(string symbol, double order_price, double sl_price, double tp_price, int direction)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int stops_level = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double min_distance = stops_level * point;
    
    // Vérifier que SL et TP sont dans le bon sens
    if(direction > 0) { // BUY
        if(sl_price > 0 && sl_price >= order_price) {
            Print("   ❌ SL invalide pour BUY: ", DoubleToString(sl_price, _Digits), " >= ", DoubleToString(order_price, _Digits));
            return false;
        }
        if(tp_price > 0 && tp_price <= order_price) {
            Print("   ❌ TP invalide pour BUY: ", DoubleToString(tp_price, _Digits), " <= ", DoubleToString(order_price, _Digits));
            return false;
        }
    } else { // SELL
        if(sl_price > 0 && sl_price <= order_price) {
            Print("   ❌ SL invalide pour SELL: ", DoubleToString(sl_price, _Digits), " <= ", DoubleToString(order_price, _Digits));
            return false;
        }
        if(tp_price > 0 && tp_price >= order_price) {
            Print("   ❌ TP invalide pour SELL: ", DoubleToString(tp_price, _Digits), " >= ", DoubleToString(order_price, _Digits));
            return false;
        }
    }
    
    // Vérifier les distances minimales
    if(sl_price > 0) {
        double sl_distance = MathAbs(order_price - sl_price);
        if(sl_distance < min_distance) {
            Print("   ❌ Distance SL trop petite: ", DoubleToString(sl_distance/point, 0), " < ", DoubleToString(min_distance/point, 0), " points");
            return false;
        }
    }
    
    if(tp_price > 0) {
        double tp_distance = MathAbs(order_price - tp_price);
        if(tp_distance < min_distance) {
            Print("   ❌ Distance TP trop petite: ", DoubleToString(tp_distance/point, 0), " < ", DoubleToString(min_distance/point, 0), " points");
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Vérifier si c'est un index Boom/Crash                           |
//+------------------------------------------------------------------+
bool IsBoomCrashIndex(string symbol)
{
    return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
}
