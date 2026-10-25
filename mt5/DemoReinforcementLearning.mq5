//+------------------------------------------------------------------+
//| DemoReinforcementLearning.mq5                                   |
//| Script de démonstration du système d'apprentissage par renforcement |
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
//| Paramètres d'entrée pour la démonstration                       |
//+------------------------------------------------------------------+
input string   InpDemoSymbol = "EURUSD";           // Symbole de démonstration
input int      InpDemoTrades = 100;                // Nombre de trades de démonstration
input bool     InpShowStepByStep = true;           // Afficher étape par étape
input bool     InpGenerateCharts = true;           // Générer des graphiques
input bool     InpExportResults = true;            // Exporter les résultats
input string   InpExportFile = "DemoResults.csv";  // Fichier d'export

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
CReinforcementLearning *g_demoLearning = NULL;
CPricePatternAnalyzer *g_demoPatternAnalyzer = NULL;
CAdaptiveStrategy *g_demoStrategy = NULL;

//+------------------------------------------------------------------+
//| Fonction principale du script                                   |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("🎭 === DÉMONSTRATION DU SYSTÈME D'APPRENTISSAGE PAR RENFORCEMENT ===");
    
    // Initialiser les composants
    if (!InitializeDemoComponents()) {
        Print("❌ Échec de l'initialisation des composants de démonstration");
        return;
    }
    
    // Phase 1: Génération de données de démonstration
    Print("📊 Phase 1: Génération de données de démonstration...");
    GenerateDemoData();
    
    // Phase 2: Simulation d'apprentissage
    Print("🧠 Phase 2: Simulation d'apprentissage...");
    SimulateLearningProcess();
    
    // Phase 3: Démonstration des capacités adaptatives
    Print("🎯 Phase 3: Démonstration des capacités adaptatives...");
    DemonstrateAdaptiveCapabilities();
    
    // Phase 4: Analyse des résultats
    Print("📈 Phase 4: Analyse des résultats...");
    AnalyzeResults();
    
    // Phase 5: Génération de rapports
    Print("📋 Phase 5: Génération de rapports...");
    GenerateReports();
    
    // Nettoyer
    CleanupDemoComponents();
    
    Print("✅ Démonstration terminée avec succès !");
}

//+------------------------------------------------------------------+
//| Initialiser les composants de démonstration                     |
//+------------------------------------------------------------------+
bool InitializeDemoComponents()
{
    Print("🔧 Initialisation des composants de démonstration...");
    
    // Initialiser le système d'apprentissage
    g_demoLearning = new CReinforcementLearning();
    if (g_demoLearning == NULL) {
        Print("❌ Échec création CReinforcementLearning");
        return false;
    }
    
    // Initialiser l'analyseur de patterns
    g_demoPatternAnalyzer = new CPricePatternAnalyzer();
    if (g_demoPatternAnalyzer == NULL) {
        Print("❌ Échec création CPricePatternAnalyzer");
        return false;
    }
    
    // Initialiser la stratégie adaptative
    g_demoStrategy = new CAdaptiveStrategy();
    if (g_demoStrategy == NULL) {
        Print("❌ Échec création CAdaptiveStrategy");
        return false;
    }
    
    // Initialiser pour le symbole de démonstration
    g_demoStrategy->Initialize(InpDemoSymbol);
    g_demoPatternAnalyzer->Initialize(InpDemoSymbol);
    
    Print("✅ Composants de démonstration initialisés");
    return true;
}

//+------------------------------------------------------------------+
//| Générer des données de démonstration                            |
//+------------------------------------------------------------------+
void GenerateDemoData()
{
    Print("📊 Génération de ", InpDemoTrades, " trades de démonstration...");
    
    // Obtenir les données historiques
    MqlRates rates[];
    if (CopyRates(InpDemoSymbol, PERIOD_CURRENT, 0, 200, rates) < 100) {
        Print("❌ Impossible d'obtenir les données historiques");
        return;
    }
    
    // Générer des trades de démonstration avec différents patterns
    for (int i = 0; i < InpDemoTrades; i++) {
        TradeHistory demoTrade = GenerateRealisticDemoTrade(rates, i);
        g_demoLearning->AddTradeToHistory(demoTrade);
        
        // Mettre à jour l'analyseur de patterns
        g_demoPatternAnalyzer->AddTradeResult(demoTrade.symbol, 
                                            demoTrade.entry_price, 
                                            demoTrade.exit_price, 
                                            demoTrade.was_winner);
        
        if (InpShowStepByStep && i % 10 == 0) {
            Print("   Trade ", i, " généré: ", demoTrade.symbol, 
                  " - ", (demoTrade.was_winner ? "GAGNANT" : "PERDANT"),
                  " - Profit: ", DoubleToString(demoTrade.profit, 2));
        }
    }
    
    Print("✅ ", InpDemoTrades, " trades de démonstration générés");
}

//+------------------------------------------------------------------+
//| Générer un trade de démonstration réaliste                      |
//+------------------------------------------------------------------+
TradeHistory GenerateRealisticDemoTrade(const MqlRates &rates[], const int index)
{
    TradeHistory trade = {0};
    
    // Sélectionner une période aléatoire mais réaliste
    int randomIndex = MathRand() % (ArraySize(rates) - 50);
    
    // Générer les données du trade avec des patterns réalistes
    trade.symbol = InpDemoSymbol;
    trade.direction = (MathRand() % 2 == 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    trade.entry_price = rates[randomIndex].close;
    trade.lot_size = 0.01 + (MathRand() % 5) * 0.01; // 0.01 à 0.05
    trade.entry_time = rates[randomIndex].time;
    trade.exit_time = trade.entry_time + (30 + MathRand() % 1440) * 60; // 30min à 24h
    trade.confidence_score = 0.4 + (MathRand() % 50) / 100.0; // 0.4 à 0.9
    trade.atr_at_entry = rates[randomIndex].high - rates[randomIndex].low;
    trade.spread_at_entry = 0.0001;
    trade.volatility_at_entry = trade.atr_at_entry / trade.entry_price;
    trade.market_session = MathRand() % 4;
    trade.in_support_zone = (MathRand() % 3 == 0); // 33% de chance
    trade.in_resistance_zone = (MathRand() % 3 == 0); // 33% de chance
    trade.distance_to_support = (MathRand() % 50) * _Point;
    trade.distance_to_resistance = (MathRand() % 50) * _Point;
    
    // Calculer le prix de sortie avec des patterns réalistes
    double priceMovement = 0;
    double baseMovement = trade.atr_at_entry * (0.5 + MathRand() % 100 / 100.0);
    
    // Ajuster selon la direction et les conditions
    if (trade.direction == ORDER_TYPE_BUY) {
        // Plus de chance de gain si dans une zone de support
        if (trade.in_support_zone) {
            priceMovement = baseMovement * (0.7 + MathRand() % 30 / 100.0);
        } else {
            priceMovement = baseMovement * (0.3 + MathRand() % 70 / 100.0);
        }
    } else {
        // Plus de chance de gain si dans une zone de résistance
        if (trade.in_resistance_zone) {
            priceMovement = -baseMovement * (0.7 + MathRand() % 30 / 100.0);
        } else {
            priceMovement = -baseMovement * (0.3 + MathRand() % 70 / 100.0);
        }
    }
    
    trade.exit_price = trade.entry_price + priceMovement;
    
    // Calculer le profit
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
//| Simuler le processus d'apprentissage                            |
//+------------------------------------------------------------------+
void SimulateLearningProcess()
{
    Print("🧠 Simulation du processus d'apprentissage...");
    
    // Phase 1: Apprentissage initial
    Print("   Phase 1: Apprentissage initial...");
    g_demoLearning->AnalyzePerformance();
    
    // Phase 2: Optimisation des paramètres
    Print("   Phase 2: Optimisation des paramètres...");
    for (int i = 0; i < 10; i++) {
        // Simuler l'optimisation des paramètres
        double confidence = g_demoLearning->GetSymbolConfidence(InpDemoSymbol, 1.1000);
        double lotSize = g_demoLearning->GetOptimalLotSize(InpDemoSymbol);
        
        if (InpShowStepByStep) {
            Print("     Itération ", i, ": Confiance = ", DoubleToString(confidence, 3),
                  ", Lot optimal = ", DoubleToString(lotSize, 3));
        }
    }
    
    // Phase 3: Analyse des patterns
    Print("   Phase 3: Analyse des patterns...");
    g_demoPatternAnalyzer->PrintZoneAnalysis(InpDemoSymbol);
    
    Print("✅ Processus d'apprentissage simulé");
}

//+------------------------------------------------------------------+
//| Démonstrer les capacités adaptatives                            |
//+------------------------------------------------------------------+
void DemonstrateAdaptiveCapabilities()
{
    Print("🎯 Démonstration des capacités adaptatives...");
    
    // Obtenir les données historiques
    MqlRates rates[];
    if (CopyRates(InpDemoSymbol, PERIOD_CURRENT, 0, 100, rates) < 50) {
        Print("❌ Impossible d'obtenir les données pour la démonstration");
        return;
    }
    
    // Générer des signaux adaptatifs
    Print("   Génération de signaux adaptatifs...");
    for (int i = 0; i < 5; i++) {
        AdaptiveSignal signal = g_demoStrategy->GenerateSignal(InpDemoSymbol, rates);
        
        if (signal.direction != 0) {
            Print("   Signal ", i, ": ", (signal.direction == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                  " - Confiance: ", DoubleToString(signal.confidence, 3),
                  " - Lot: ", DoubleToString(signal.lot_size, 3),
                  " - SL: ", DoubleToString(signal.stop_loss, _Digits),
                  " - TP: ", DoubleToString(signal.take_profit, _Digits));
        } else {
            Print("   Signal ", i, ": Aucun signal généré");
        }
    }
    
    // Démonstrer l'analyse des zones
    Print("   Analyse des zones de haute probabilité...");
    for (double price = 1.0950; price <= 1.1050; price += 0.0010) {
        bool isHighProb = g_demoPatternAnalyzer->IsPriceInHighProbabilityZone(InpDemoSymbol, price);
        if (isHighProb) {
            Print("     Zone haute probabilité détectée à ", DoubleToString(price, _Digits));
        }
    }
    
    Print("✅ Capacités adaptatives démontrées");
}

//+------------------------------------------------------------------+
//| Analyser les résultats                                          |
//+------------------------------------------------------------------+
void AnalyzeResults()
{
    Print("📈 Analyse des résultats...");
    
    // Statistiques d'apprentissage
    Print("   --- Statistiques d'apprentissage ---");
    g_demoLearning->PrintLearningStats();
    
    // Performances de la stratégie
    Print("   --- Performances de la stratégie ---");
    g_demoStrategy->PrintPerformanceReport();
    
    // Analyse des patterns
    Print("   --- Analyse des patterns ---");
    g_demoPatternAnalyzer->PrintZoneAnalysis(InpDemoSymbol);
    g_demoPatternAnalyzer->PrintPriceRangeAnalysis(InpDemoSymbol);
    g_demoPatternAnalyzer->PrintSessionAnalysis(InpDemoSymbol);
    
    Print("✅ Analyse des résultats terminée");
}

//+------------------------------------------------------------------+
//| Générer des rapports                                            |
//+------------------------------------------------------------------+
void GenerateReports()
{
    Print("📋 Génération de rapports...");
    
    if (InpExportResults) {
        // Exporter les données d'apprentissage
        g_demoLearning->ExportLearningData("LearningData_" + InpDemoSymbol + ".csv");
        
        // Exporter les performances
        g_demoStrategy->ExportPerformanceData("PerformanceData_" + InpDemoSymbol + ".csv");
        
        Print("   Rapports exportés vers:");
        Print("     - LearningData_", InpDemoSymbol, ".csv");
        Print("     - PerformanceData_", InpDemoSymbol, ".csv");
    }
    
    // Générer un rapport de synthèse
    GenerateSummaryReport();
    
    Print("✅ Rapports générés");
}

//+------------------------------------------------------------------+
//| Générer un rapport de synthèse                                  |
//+------------------------------------------------------------------+
void GenerateSummaryReport()
{
    Print("📊 === RAPPORT DE SYNTHÈSE ===");
    
    // Calculer les statistiques globales
    double totalTrades = g_demoLearning->GetSymbolTotalTrades(InpDemoSymbol);
    double successRate = g_demoLearning->GetSymbolSuccessRate(InpDemoSymbol);
    double avgProfit = g_demoLearning->GetSymbolAvgProfit(InpDemoSymbol);
    
    Print("Symbole: ", InpDemoSymbol);
    Print("Total trades: ", totalTrades);
    Print("Taux de succès: ", DoubleToString(successRate * 100, 2), "%");
    Print("Profit moyen: ", DoubleToString(avgProfit, 2));
    
    // Analyser les patterns
    PricePattern bestPattern = g_demoLearning->GetBestPricePattern(InpDemoSymbol);
    PricePattern worstPattern = g_demoLearning->GetWorstPricePattern(InpDemoSymbol);
    
    if (bestPattern.price_level > 0) {
        Print("Meilleur pattern: ", DoubleToString(bestPattern.price_level, _Digits),
              " - Succès: ", DoubleToString(bestPattern.success_rate * 100, 1), "%");
    }
    
    if (worstPattern.price_level > 0) {
        Print("Pire pattern: ", DoubleToString(worstPattern.price_level, _Digits),
              " - Succès: ", DoubleToString(worstPattern.success_rate * 100, 1), "%");
    }
    
    // Recommandations
    Print("--- Recommandations ---");
    if (successRate > 0.6) {
        Print("✅ Bon taux de succès - Continuer avec la stratégie actuelle");
    } else if (successRate > 0.4) {
        Print("⚠️ Taux de succès moyen - Ajuster les paramètres");
    } else {
        Print("❌ Taux de succès faible - Réviser la stratégie");
    }
    
    if (avgProfit > 0) {
        Print("✅ Profit moyen positif - Stratégie rentable");
    } else {
        Print("❌ Profit moyen négatif - Stratégie non rentable");
    }
}

//+------------------------------------------------------------------+
//| Nettoyer les composants de démonstration                        |
//+------------------------------------------------------------------+
void CleanupDemoComponents()
{
    Print("🧹 Nettoyage des composants de démonstration...");
    
    if (g_demoLearning != NULL) {
        delete g_demoLearning;
        g_demoLearning = NULL;
    }
    
    if (g_demoPatternAnalyzer != NULL) {
        delete g_demoPatternAnalyzer;
        g_demoPatternAnalyzer = NULL;
    }
    
    if (g_demoStrategy != NULL) {
        delete g_demoStrategy;
        g_demoStrategy = NULL;
    }
    
    Print("✅ Nettoyage terminé");
}
