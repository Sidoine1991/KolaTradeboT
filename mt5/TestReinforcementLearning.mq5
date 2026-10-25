//+------------------------------------------------------------------+
//| TestReinforcementLearning.mq5                                   |
//| Script de test pour le système d'apprentissage par renforcement |
//| Version: 1.0                                                    |
//+------------------------------------------------------------------+

#property copyright "SpikeHunter AI"
#property version   "1.00"
#property script_show_inputs
#property strict

#include "ReinforcementLearning.mqh"
#include "PricePatternAnalyzer.mqh"
#include "AdaptiveStrategy.mqh"

//+------------------------------------------------------------------+
//| Paramètres d'entrée pour le test                                |
//+------------------------------------------------------------------+
input string   InpTestSymbol = "EURUSD";           // Symbole de test
input int      InpTestPeriod = 100;                // Nombre de périodes à analyser
input bool     InpGenerateTestData = true;         // Générer des données de test
input int      InpTestTrades = 50;                 // Nombre de trades de test
input bool     InpShowDetailedStats = true;        // Afficher les statistiques détaillées
input bool     InpExportResults = true;            // Exporter les résultats
input string   InpExportFile = "TestResults.csv";  // Fichier d'export

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
CReinforcementLearning *g_testLearning = NULL;
CPricePatternAnalyzer *g_testPatternAnalyzer = NULL;
CAdaptiveStrategy *g_testStrategy = NULL;

//+------------------------------------------------------------------+
//| Fonction principale du script                                   |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("🧪 === TEST DU SYSTÈME D'APPRENTISSAGE PAR RENFORCEMENT ===");
    
    // Initialiser les composants
    if (!InitializeTestComponents()) {
        Print("❌ Échec de l'initialisation des composants de test");
        return;
    }
    
    // Générer des données de test si demandé
    if (InpGenerateTestData) {
        GenerateTestData();
    }
    
    // Exécuter les tests
    RunLearningTests();
    RunPatternAnalysisTests();
    RunAdaptiveStrategyTests();
    
    // Afficher les résultats
    DisplayTestResults();
    
    // Exporter les résultats si demandé
    if (InpExportResults) {
        ExportTestResults();
    }
    
    // Nettoyer
    CleanupTestComponents();
    
    Print("✅ Tests terminés avec succès");
}

//+------------------------------------------------------------------+
//| Initialiser les composants de test                              |
//+------------------------------------------------------------------+
bool InitializeTestComponents()
{
    Print("🔧 Initialisation des composants de test...");
    
    // Initialiser le système d'apprentissage
    g_testLearning = new CReinforcementLearning();
    if (g_testLearning == NULL) {
        Print("❌ Échec création CReinforcementLearning");
        return false;
    }
    
    // Initialiser l'analyseur de patterns
    g_testPatternAnalyzer = new CPricePatternAnalyzer();
    if (g_testPatternAnalyzer == NULL) {
        Print("❌ Échec création CPricePatternAnalyzer");
        return false;
    }
    
    // Initialiser la stratégie adaptative
    g_testStrategy = new CAdaptiveStrategy();
    if (g_testStrategy == NULL) {
        Print("❌ Échec création CAdaptiveStrategy");
        return false;
    }
    
    // Initialiser pour le symbole de test
    g_testStrategy->Initialize(InpTestSymbol);
    g_testPatternAnalyzer->Initialize(InpTestSymbol);
    
    Print("✅ Composants de test initialisés");
    return true;
}

//+------------------------------------------------------------------+
//| Générer des données de test                                     |
//+------------------------------------------------------------------+
void GenerateTestData()
{
    Print("📊 Génération de données de test...");
    
    // Obtenir les données historiques
    MqlRates rates[];
    if (CopyRates(InpTestSymbol, PERIOD_CURRENT, 0, InpTestPeriod, rates) < InpTestPeriod) {
        Print("❌ Impossible d'obtenir les données historiques");
        return;
    }
    
    // Générer des trades de test basés sur les données historiques
    for (int i = 0; i < InpTestTrades; i++) {
        TradeHistory testTrade = GenerateRandomTrade(rates, i);
        g_testLearning->AddTradeToHistory(testTrade);
        
        // Mettre à jour l'analyseur de patterns
        g_testPatternAnalyzer->AddTradeResult(testTrade.symbol, 
                                            testTrade.entry_price, 
                                            testTrade.exit_price, 
                                            testTrade.was_winner);
    }
    
    Print("✅ ", InpTestTrades, " trades de test générés");
}

//+------------------------------------------------------------------+
//| Générer un trade aléatoire basé sur les données historiques     |
//+------------------------------------------------------------------+
TradeHistory GenerateRandomTrade(const MqlRates &rates[], const int index)
{
    TradeHistory trade = {0};
    
    // Sélectionner une période aléatoire
    int randomIndex = MathRand() % (ArraySize(rates) - 20);
    
    // Générer les données du trade
    trade.symbol = InpTestSymbol;
    trade.direction = (MathRand() % 2 == 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    trade.entry_price = rates[randomIndex].close;
    trade.lot_size = 0.01 + (MathRand() % 10) * 0.01; // 0.01 à 0.1
    trade.entry_time = rates[randomIndex].time;
    trade.exit_time = trade.entry_time + (MathRand() % 1440) * 60; // 0 à 24h
    trade.confidence_score = 0.3 + (MathRand() % 70) / 100.0; // 0.3 à 1.0
    trade.atr_at_entry = rates[randomIndex].high - rates[randomIndex].low;
    trade.spread_at_entry = 0.0001;
    trade.volatility_at_entry = trade.atr_at_entry / trade.entry_price;
    trade.market_session = MathRand() % 4;
    trade.in_support_zone = (MathRand() % 2 == 0);
    trade.in_resistance_zone = (MathRand() % 2 == 0);
    trade.distance_to_support = (MathRand() % 100) * _Point;
    trade.distance_to_resistance = (MathRand() % 100) * _Point;
    
    // Calculer le prix de sortie et le profit
    double priceMovement = (MathRand() % 200 - 100) * _Point; // -100 à +100 points
    trade.exit_price = trade.entry_price + priceMovement;
    
    if (trade.direction == ORDER_TYPE_BUY) {
        trade.profit = (trade.exit_price - trade.entry_price) * trade.lot_size * 100000;
    } else {
        trade.profit = (trade.entry_price - trade.exit_price) * trade.lot_size * 100000;
    }
    
    trade.was_winner = (trade.profit > 0);
    trade.exit_reason = trade.was_winner ? 1 : 2; // TP ou SL
    trade.hold_duration_minutes = (int)((trade.exit_time - trade.entry_time) / 60);
    trade.max_favorable = trade.profit * (1 + MathRand() % 50 / 100.0);
    trade.max_adverse = trade.profit * (0.5 - MathRand() % 50 / 100.0);
    
    return trade;
}

//+------------------------------------------------------------------+
//| Exécuter les tests d'apprentissage                              |
//+------------------------------------------------------------------+
void RunLearningTests()
{
    Print("🧠 Tests du système d'apprentissage...");
    
    // Test 1: Vérifier l'ajout de trades
    Print("Test 1: Ajout de trades à l'historique");
    TradeHistory testTrade = {0};
    testTrade.symbol = InpTestSymbol;
    testTrade.direction = ORDER_TYPE_BUY;
    testTrade.entry_price = 1.1000;
    testTrade.exit_price = 1.1050;
    testTrade.profit = 50.0;
    testTrade.was_winner = true;
    testTrade.entry_time = TimeCurrent();
    testTrade.exit_time = TimeCurrent() + 3600;
    
    g_testLearning->AddTradeToHistory(testTrade);
    Print("✅ Trade ajouté à l'historique");
    
    // Test 2: Vérifier la confiance des symboles
    Print("Test 2: Calcul de la confiance des symboles");
    double confidence = g_testLearning->GetSymbolConfidence(InpTestSymbol, 1.1000);
    Print("Confiance pour ", InpTestSymbol, " à 1.1000: ", DoubleToString(confidence, 3));
    
    // Test 3: Vérifier la taille de lot optimale
    Print("Test 3: Calcul de la taille de lot optimale");
    double optimalLotSize = g_testLearning->GetOptimalLotSize(InpTestSymbol);
    Print("Taille de lot optimale pour ", InpTestSymbol, ": ", DoubleToString(optimalLotSize, 3));
    
    // Test 4: Vérifier l'analyse des performances
    Print("Test 4: Analyse des performances");
    g_testLearning->AnalyzePerformance();
    
    Print("✅ Tests d'apprentissage terminés");
}

//+------------------------------------------------------------------+
//| Exécuter les tests d'analyse de patterns                        |
//+------------------------------------------------------------------+
void RunPatternAnalysisTests()
{
    Print("🔍 Tests de l'analyse de patterns...");
    
    // Obtenir les données historiques
    MqlRates rates[];
    if (CopyRates(InpTestSymbol, PERIOD_CURRENT, 0, 100, rates) < 50) {
        Print("❌ Impossible d'obtenir les données pour l'analyse de patterns");
        return;
    }
    
    // Test 1: Mise à jour de l'analyse
    Print("Test 1: Mise à jour de l'analyse des patterns");
    g_testPatternAnalyzer->UpdateAnalysis(InpTestSymbol, rates);
    Print("✅ Analyse des patterns mise à jour");
    
    // Test 2: Vérifier les zones de support/résistance
    Print("Test 2: Détection des zones de support/résistance");
    SupportResistanceZone supportZone = g_testPatternAnalyzer->GetBestSupportZone(InpTestSymbol, rates[0].close);
    SupportResistanceZone resistanceZone = g_testPatternAnalyzer->GetBestResistanceZone(InpTestSymbol, rates[0].close);
    
    if (supportZone.level > 0) {
        Print("Meilleure zone de support: ", DoubleToString(supportZone.level, _Digits), 
              " - Force: ", DoubleToString(supportZone.strength, 2));
    }
    
    if (resistanceZone.level > 0) {
        Print("Meilleure zone de résistance: ", DoubleToString(resistanceZone.level, _Digits), 
              " - Force: ", DoubleToString(resistanceZone.strength, 2));
    }
    
    // Test 3: Vérifier la probabilité de succès
    Print("Test 3: Calcul de la probabilité de succès");
    double buyProbability = g_testPatternAnalyzer->GetPriceSuccessProbability(InpTestSymbol, rates[0].close, ORDER_TYPE_BUY);
    double sellProbability = g_testPatternAnalyzer->GetPriceSuccessProbability(InpTestSymbol, rates[0].close, ORDER_TYPE_SELL);
    
    Print("Probabilité d'achat: ", DoubleToString(buyProbability, 3));
    Print("Probabilité de vente: ", DoubleToString(sellProbability, 3));
    
    // Test 4: Vérifier les zones de haute probabilité
    Print("Test 4: Vérification des zones de haute probabilité");
    bool isHighProb = g_testPatternAnalyzer->IsPriceInHighProbabilityZone(InpTestSymbol, rates[0].close);
    Print("Prix dans zone haute probabilité: ", isHighProb ? "OUI" : "NON");
    
    Print("✅ Tests d'analyse de patterns terminés");
}

//+------------------------------------------------------------------+
//| Exécuter les tests de stratégie adaptative                      |
//+------------------------------------------------------------------+
void RunAdaptiveStrategyTests()
{
    Print("🎯 Tests de la stratégie adaptative...");
    
    // Obtenir les données historiques
    MqlRates rates[];
    if (CopyRates(InpTestSymbol, PERIOD_CURRENT, 0, 100, rates) < 50) {
        Print("❌ Impossible d'obtenir les données pour la stratégie adaptative");
        return;
    }
    
    // Test 1: Génération de signaux
    Print("Test 1: Génération de signaux adaptatifs");
    AdaptiveSignal signal = g_testStrategy->GenerateSignal(InpTestSymbol, rates);
    
    if (signal.direction != 0) {
        Print("Signal généré: ", (signal.direction == ORDER_TYPE_BUY ? "BUY" : "SELL"));
        Print("Confiance: ", DoubleToString(signal.confidence, 3));
        Print("Prix d'entrée: ", DoubleToString(signal.entry_price, _Digits));
        Print("Stop Loss: ", DoubleToString(signal.stop_loss, _Digits));
        Print("Take Profit: ", DoubleToString(signal.take_profit, _Digits));
        Print("Taille de lot: ", DoubleToString(signal.lot_size, 3));
        Print("Ratio R/R: ", DoubleToString(signal.risk_reward_ratio, 2));
    } else {
        Print("Aucun signal généré");
    }
    
    // Test 2: Validation des signaux
    Print("Test 2: Validation des signaux");
    bool isValid = g_testStrategy->ValidateSignal(signal);
    Print("Signal valide: ", isValid ? "OUI" : "NON");
    
    // Test 3: Confiance actuelle
    Print("Test 3: Confiance actuelle du système");
    double currentConfidence = g_testStrategy->GetCurrentConfidence(InpTestSymbol);
    Print("Confiance actuelle: ", DoubleToString(currentConfidence, 3));
    
    // Test 4: Statistiques de performance
    Print("Test 4: Statistiques de performance");
    PerformanceStats stats = g_testStrategy->GetPerformanceStats();
    Print("Total trades: ", stats.total_trades);
    Print("Taux de gain: ", DoubleToString(stats.win_rate * 100, 2), "%");
    Print("Profit total: ", DoubleToString(stats.total_profit, 2));
    Print("Facteur de profit: ", DoubleToString(stats.profit_factor, 2));
    
    Print("✅ Tests de stratégie adaptative terminés");
}

//+------------------------------------------------------------------+
//| Afficher les résultats des tests                                |
//+------------------------------------------------------------------+
void DisplayTestResults()
{
    Print("📊 === RÉSULTATS DES TESTS ===");
    
    if (InpShowDetailedStats) {
        // Afficher les statistiques détaillées d'apprentissage
        if (g_testLearning != NULL) {
            Print("--- Statistiques d'apprentissage ---");
            g_testLearning->PrintLearningStats();
        }
        
        // Afficher l'analyse des patterns
        if (g_testPatternAnalyzer != NULL) {
            Print("--- Analyse des patterns ---");
            g_testPatternAnalyzer->PrintZoneAnalysis(InpTestSymbol);
            g_testPatternAnalyzer->PrintPriceRangeAnalysis(InpTestSymbol);
            g_testPatternAnalyzer->PrintSessionAnalysis(InpTestSymbol);
        }
        
        // Afficher les performances de la stratégie
        if (g_testStrategy != NULL) {
            Print("--- Performances de la stratégie ---");
            g_testStrategy->PrintPerformanceReport();
        }
    }
    
    Print("✅ Affichage des résultats terminé");
}

//+------------------------------------------------------------------+
//| Exporter les résultats des tests                                |
//+------------------------------------------------------------------+
void ExportTestResults()
{
    Print("📤 Export des résultats...");
    
    if (g_testLearning != NULL) {
        g_testLearning->ExportLearningData("LearningData_" + InpTestSymbol + ".csv");
    }
    
    if (g_testStrategy != NULL) {
        g_testStrategy->ExportPerformanceData("PerformanceData_" + InpTestSymbol + ".csv");
    }
    
    Print("✅ Export terminé");
}

//+------------------------------------------------------------------+
//| Nettoyer les composants de test                                 |
//+------------------------------------------------------------------+
void CleanupTestComponents()
{
    Print("🧹 Nettoyage des composants de test...");
    
    if (g_testLearning != NULL) {
        delete g_testLearning;
        g_testLearning = NULL;
    }
    
    if (g_testPatternAnalyzer != NULL) {
        delete g_testPatternAnalyzer;
        g_testPatternAnalyzer = NULL;
    }
    
    if (g_testStrategy != NULL) {
        delete g_testStrategy;
        g_testStrategy = NULL;
    }
    
    Print("✅ Nettoyage terminé");
}
