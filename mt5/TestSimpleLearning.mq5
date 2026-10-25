//+------------------------------------------------------------------+
//| TestSimpleLearning.mq5                                          |
//| Script de test simple pour le système d'apprentissage           |
//| Version: 1.0                                                    |
//+------------------------------------------------------------------+

#property copyright "SpikeHunter AI"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "ReinforcementLearning.mqh"

//+------------------------------------------------------------------+
//| Fonction principale du script                                   |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("🧪 Test simple du système d'apprentissage par renforcement");
    
    // Créer une instance du système d'apprentissage
    CReinforcementLearning* learning = new CReinforcementLearning();
    
    if (learning == NULL) {
        Print("❌ Erreur: Impossible de créer CReinforcementLearning");
        return;
    }
    
    Print("✅ CReinforcementLearning créé avec succès");
    
    // Créer un trade de test
    TradeHistory testTrade = {0};
    testTrade.symbol = "EURUSD";
    testTrade.direction = ORDER_TYPE_BUY;
    testTrade.entry_price = 1.1000;
    testTrade.exit_price = 1.1050;
    testTrade.profit = 50.0;
    testTrade.was_winner = true;
    testTrade.entry_time = TimeCurrent();
    testTrade.exit_time = TimeCurrent() + 3600;
    testTrade.lot_size = 0.01;
    testTrade.confidence_score = 0.8;
    testTrade.atr_at_entry = 0.001;
    testTrade.spread_at_entry = 0.0001;
    testTrade.volatility_at_entry = 0.001;
    testTrade.market_session = 1;
    testTrade.in_support_zone = true;
    testTrade.in_resistance_zone = false;
    testTrade.distance_to_support = 0.0005;
    testTrade.distance_to_resistance = 0.002;
    testTrade.hold_duration_minutes = 60;
    testTrade.max_favorable = 60.0;
    testTrade.max_adverse = -10.0;
    testTrade.exit_reason = 1;
    
    // Ajouter le trade à l'historique
    learning->AddTradeToHistory(testTrade);
    Print("✅ Trade de test ajouté à l'historique");
    
    // Tester la confiance
    double confidence = learning->GetSymbolConfidence("EURUSD", 1.1000);
    Print("Confiance pour EURUSD à 1.1000: ", DoubleToString(confidence, 3));
    
    // Tester la taille de lot optimale
    double lotSize = learning->GetOptimalLotSize("EURUSD");
    Print("Taille de lot optimale pour EURUSD: ", DoubleToString(lotSize, 3));
    
    // Afficher les statistiques
    learning->PrintLearningStats();
    
    // Nettoyer
    delete learning;
    
    Print("✅ Test terminé avec succès !");
}
