//+------------------------------------------------------------------+
//| SpikeHunter_Enhanced_EA.mq5                                     |
//| EA avec système d'apprentissage par renforcement                |
//| Version: 4.0 - Enhanced with AI Learning                        |
//+------------------------------------------------------------------+

#property copyright "SpikeHunter AI"
#property version   "4.00"
#property description "SpikeHunter Enhanced with Reinforcement Learning"
#property strict

#include <Trade\Trade.mqh>
#include "ReinforcementLearning.mqh"
#include "PricePatternAnalyzer.mqh"
#include "AdaptiveStrategy.mqh"

//+------------------------------------------------------------------+
//| Paramètres d'entrée                                              |
//+------------------------------------------------------------------+

input group "=== CONFIGURATION GÉNÉRALE ==="
input bool     InpEnableTrading        = true;     // Activer le trading
input int      InpMagicNumber          = 123456;   // Magic number
input string   InpSymbols              = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD"; // Symboles à trader
input double   InpInitialBalance       = 10000.0;  // Balance initiale pour l'apprentissage

input group "=== SYSTÈME D'APPRENTISSAGE ==="
input bool     InpEnableLearning       = true;     // Activer l'apprentissage par renforcement
input bool     InpLearningMode         = true;     // Mode d'apprentissage (réduit les lots)
input double   InpLearningRate         = 0.1;      // Taux d'apprentissage
input double   InpDiscountFactor       = 0.9;      // Facteur d'escompte
input double   InpExplorationRate      = 0.1;      // Taux d'exploration
input int      InpMaxHistorySize       = 1000;     // Taille maximale de l'historique
input bool     InpEnablePatternAnalysis = true;   // Activer l'analyse des patterns
input bool     InpEnableAdaptiveStrategy = true;  // Activer la stratégie adaptative

input group "=== PARAMÈTRES ADAPTATIFS ==="
input double   InpLotSizeMultiplier    = 1.0;      // Multiplicateur de taille de lot
input double   InpATRMultiplier        = 2.0;      // Multiplicateur ATR pour SL/TP
input double   InpConfidenceThreshold  = 0.6;      // Seuil de confiance minimum
input double   InpRiskMultiplier       = 1.0;      // Multiplicateur de risque
input int      InpMaxTradesPerSession  = 5;        // Nombre max de trades par session
input int      InpCooldownMinutes      = 30;       // Cooldown entre trades (minutes)
input bool     InpHighProbOnly         = false;    // Trader seulement les zones haute probabilité
input double   InpProfitTargetMultiplier = 1.0;    // Multiplicateur de profit target
input double   InpStopLossMultiplier   = 1.0;      // Multiplicateur de stop loss
input int      InpSessionPreference    = 1;        // Préférence de session (0=Asian, 1=London, 2=NY, 3=Overlap)
input bool     InpUseDynamicSizing     = true;     // Utiliser le sizing dynamique
input bool     InpUsePatternFiltering  = true;     // Utiliser le filtrage par patterns
input double   InpPatternConfidenceMin = 0.5;      // Confiance minimum des patterns

input group "=== GESTION DES RISQUES ==="
input double   InpMaxRiskPerTrade      = 2.0;      // Risque maximum par trade (%)
input double   InpMaxDailyLoss         = 5.0;      // Perte quotidienne maximum (%)
input double   InpMaxDrawdown          = 10.0;     // Drawdown maximum (%)
input int      InpMaxConsecutiveLosses = 5;        // Nombre max de pertes consécutives
input bool     InpEnableGlobalStop     = true;     // Activer l'arrêt global
input int      InpGlobalCooldownMin    = 60;       // Cooldown global après arrêt (minutes)

input group "=== NOTIFICATIONS ==="
input bool     InpEnableNotifications  = true;     // Activer les notifications
input bool     InpNotifyOnTrade        = true;     // Notifier à chaque trade
input bool     InpNotifyOnLearning     = true;     // Notifier les mises à jour d'apprentissage
input bool     InpNotifyOnPerformance  = true;     // Notifier les rapports de performance

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+

// Système d'apprentissage
CReinforcementLearning *g_learning = NULL;
CPricePatternAnalyzer *g_patternAnalyzer = NULL;
CAdaptiveStrategy *g_adaptiveStrategy = NULL;

// Gestionnaires existants (conservés pour compatibilité)
CRiskManager *g_riskManager = NULL;
CSignalDetector *g_signalDetector = NULL;
CSignalValidator *g_signalValidator = NULL;
CTradeExecutor *g_tradeExecutor = NULL;

// Variables pour l'apprentissage
TradeHistory g_currentTrade = {0};
bool g_tradeInProgress = false;
datetime g_lastAnalysis = 0;
int g_analysisInterval = 15; // Analyser toutes les 15 minutes

// Variables pour les performances
double g_initialBalance = 0;
double g_currentBalance = 0;
double g_peakBalance = 0;
datetime g_lastPerformanceReport = 0;
int g_performanceReportInterval = 3600; // Rapport toutes les heures

// Variables pour les notifications
datetime g_lastNotification = 0;
int g_notificationInterval = 300; // Notifications toutes les 5 minutes

//+------------------------------------------------------------------+
//| Fonction d'initialisation                                        |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🧠 SPIKE HUNTER ENHANCED - Version 4.0 avec Apprentissage par Renforcement");
    Print("   ✅ Système d'apprentissage par renforcement");
    Print("   ✅ Analyse avancée des patterns de prix");
    Print("   ✅ Stratégie adaptative intelligente");
    Print("   ✅ Gestion des risques améliorée");
    
    // Initialiser la balance
    g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    g_currentBalance = g_initialBalance;
    g_peakBalance = g_initialBalance;
    
    // Initialiser le système d'apprentissage
    if (InpEnableLearning) {
        g_learning = new CReinforcementLearning();
        g_patternAnalyzer = new CPricePatternAnalyzer();
        g_adaptiveStrategy = new CAdaptiveStrategy();
        
        // Configurer la stratégie adaptative
        g_adaptiveStrategy->SetInitialBalance(g_initialBalance);
        g_adaptiveStrategy->SetLearningMode(InpLearningMode);
        
        // Initialiser pour chaque symbole
        string symbols[];
        StringSplit(InpSymbols, ',', symbols);
        for (int i = 0; i < ArraySize(symbols); i++) {
            StringTrimLeft(symbols[i]);
            StringTrimRight(symbols[i]);
            g_adaptiveStrategy->Initialize(symbols[i]);
            g_patternAnalyzer->Initialize(symbols[i]);
        }
        
        Print("🧠 Système d'apprentissage initialisé");
    }
    
    // Initialiser les gestionnaires existants
    g_riskManager = new CRiskManager();
    g_signalDetector = new CSignalDetector();
    g_signalValidator = new CSignalValidator();
    g_tradeExecutor = new CTradeExecutor();
    
    // Afficher les paramètres
    Print("📊 Paramètres d'apprentissage:");
    Print("   Mode d'apprentissage: ", InpLearningMode ? "ACTIVÉ" : "DÉSACTIVÉ");
    Print("   Taux d'apprentissage: ", InpLearningRate);
    Print("   Seuil de confiance: ", InpConfidenceThreshold);
    Print("   Analyse des patterns: ", InpEnablePatternAnalysis ? "ACTIVÉE" : "DÉSACTIVÉE");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Fonction de désinitialisation                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🧠 SPIKE HUNTER ENHANCED - Arrêt du système d'apprentissage");
    
    // Sauvegarder les données d'apprentissage
    if (g_learning != NULL) {
        g_learning->SaveLearningData();
        g_learning->PrintLearningStats();
        delete g_learning;
        g_learning = NULL;
    }
    
    if (g_patternAnalyzer != NULL) {
        delete g_patternAnalyzer;
        g_patternAnalyzer = NULL;
    }
    
    if (g_adaptiveStrategy != NULL) {
        g_adaptiveStrategy->PrintPerformanceReport();
        delete g_adaptiveStrategy;
        g_adaptiveStrategy = NULL;
    }
    
    // Nettoyer les gestionnaires existants
    if (g_riskManager != NULL) {
        delete g_riskManager;
        g_riskManager = NULL;
    }
    if (g_signalDetector != NULL) {
        delete g_signalDetector;
        g_signalDetector = NULL;
    }
    if (g_signalValidator != NULL) {
        delete g_signalValidator;
        g_signalValidator = NULL;
    }
    if (g_tradeExecutor != NULL) {
        delete g_tradeExecutor;
        g_tradeExecutor = NULL;
    }
    
    Print("🧠 Système d'apprentissage arrêté");
}

//+------------------------------------------------------------------+
//| Fonction principale OnTick                                       |
//+------------------------------------------------------------------+
void OnTick()
{
    if (!InpEnableTrading) return;
    
    // Mettre à jour la balance actuelle
    g_currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    if (g_currentBalance > g_peakBalance) {
        g_peakBalance = g_currentBalance;
    }
    
    // Gérer les trades existants
    ManageExistingTrades();
    
    // Analyser et trader si le système d'apprentissage est activé
    if (InpEnableLearning && g_adaptiveStrategy != NULL) {
        AnalyzeAndTrade();
    } else {
        // Utiliser le système de trading original
        ExecuteOriginalTrading();
    }
    
    // Gérer les notifications
    if (InpEnableNotifications) {
        ManageNotifications();
    }
    
    // Gérer les rapports de performance
    ManagePerformanceReports();
}

//+------------------------------------------------------------------+
//| Analyser et trader avec le système d'apprentissage              |
//+------------------------------------------------------------------+
void AnalyzeAndTrade()
{
    string symbols[];
    StringSplit(InpSymbols, ',', symbols);
    
    for (int i = 0; i < ArraySize(symbols); i++) {
        StringTrimLeft(symbols[i]);
        StringTrimRight(symbols[i]);
        
        // Obtenir les données de prix
        MqlRates rates[];
        if (CopyRates(symbols[i], PERIOD_CURRENT, 0, 100, rates) < 50) continue;
        
        // Mettre à jour l'analyse des patterns
        if (g_patternAnalyzer != NULL) {
            g_patternAnalyzer->UpdateAnalysis(symbols[i], rates);
        }
        
        // Générer un signal adaptatif
        if (g_adaptiveStrategy != NULL) {
            AdaptiveSignal signal = g_adaptiveStrategy->GenerateSignal(symbols[i], rates);
            
            if (signal.direction != 0 && g_adaptiveStrategy->ValidateSignal(signal)) {
                ExecuteAdaptiveTrade(signal);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Exécuter un trade adaptatif                                     |
//+------------------------------------------------------------------+
void ExecuteAdaptiveTrade(const AdaptiveSignal &signal)
{
    // Vérifier les conditions de risque
    if (!CheckRiskConditions(signal)) {
        Print("⚠️ Trade rejeté: conditions de risque non respectées");
        return;
    }
    
    // Préparer le trade
    MqlTradeRequest request = {0};
    MqlTradeResult result = {0};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = signal.symbol;
    request.volume = signal.lot_size;
    request.type = signal.direction;
    request.price = (signal.direction == ORDER_TYPE_BUY) ? 
        SymbolInfoDouble(signal.symbol, SYMBOL_ASK) : 
        SymbolInfoDouble(signal.symbol, SYMBOL_BID);
    request.sl = signal.stop_loss;
    request.tp = signal.take_profit;
    request.magic = InpMagicNumber;
    request.comment = "AdaptiveAI";
    request.deviation = 10;
    
    // Exécuter le trade
    if (OrderSend(request, result)) {
        Print("✅ Trade adaptatif exécuté: ", signal.symbol, 
              " - Direction: ", (signal.direction == ORDER_TYPE_BUY ? "BUY" : "SELL"),
              " - Lot: ", DoubleToString(signal.lot_size, 2),
              " - Confiance: ", DoubleToString(signal.confidence, 2));
        
        // Enregistrer le trade pour l'apprentissage
        RecordTradeForLearning(signal, result.order);
        
        // Notifier si activé
        if (InpEnableNotifications && InpNotifyOnTrade) {
            SendNotification("Trade adaptatif: " + signal.symbol + " " + 
                           (signal.direction == ORDER_TYPE_BUY ? "BUY" : "SELL") + 
                           " - Confiance: " + DoubleToString(signal.confidence, 2));
        }
    } else {
        Print("❌ Échec trade adaptatif: ", GetLastError(), " - ", result.comment);
    }
}

//+------------------------------------------------------------------+
//| Enregistrer un trade pour l'apprentissage                       |
//+------------------------------------------------------------------+
void RecordTradeForLearning(const AdaptiveSignal &signal, const ulong ticket)
{
    // Initialiser le trade dans l'historique
    g_currentTrade.ticket = ticket;
    g_currentTrade.symbol = signal.symbol;
    g_currentTrade.direction = signal.direction;
    g_currentTrade.entry_price = signal.entry_price;
    g_currentTrade.lot_size = signal.lot_size;
    g_currentTrade.entry_time = TimeCurrent();
    g_currentTrade.confidence_score = signal.confidence;
    g_currentTrade.atr_at_entry = iATR(signal.symbol, PERIOD_CURRENT, 14);
    g_currentTrade.spread_at_entry = SymbolInfoInteger(signal.symbol, SYMBOL_SPREAD) * _Point;
    g_currentTrade.volatility_at_entry = 0; // À calculer
    g_currentTrade.market_session = signal.session;
    g_currentTrade.in_support_zone = false; // À déterminer
    g_currentTrade.in_resistance_zone = false; // À déterminer
    g_currentTrade.distance_to_support = 0; // À calculer
    g_currentTrade.distance_to_resistance = 0; // À calculer
    
    g_tradeInProgress = true;
    
    Print("📊 Trade enregistré pour l'apprentissage: ", signal.symbol, " - Ticket: ", ticket);
}

//+------------------------------------------------------------------+
//| Gérer les trades existants                                       |
//+------------------------------------------------------------------+
void ManageExistingTrades()
{
    // Vérifier les trades en cours
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if (!PositionSelectByTicket(ticket)) continue;
        if ((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ?
            SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
        
        // Vérifier si le trade est fermé
        if (g_tradeInProgress && g_currentTrade.ticket == ticket) {
            // Le trade est toujours ouvert, continuer à le surveiller
            continue;
        }
    }
    
    // Vérifier les trades fermés dans l'historique
    if (g_tradeInProgress) {
        bool tradeStillOpen = false;
        for (int i = PositionsTotal() - 1; i >= 0; i--) {
            ulong ticket = PositionGetTicket(i);
            if (ticket == g_currentTrade.ticket) {
                tradeStillOpen = true;
                break;
            }
        }
        
        if (!tradeStillOpen) {
            // Le trade a été fermé, l'ajouter à l'historique d'apprentissage
            CompleteTradeLearning();
        }
    }
}

//+------------------------------------------------------------------+
//| Compléter l'apprentissage d'un trade                            |
//+------------------------------------------------------------------+
void CompleteTradeLearning()
{
    if (!g_tradeInProgress) return;
    
    // Obtenir les détails de fermeture depuis l'historique des ordres
    HistorySelect(g_currentTrade.entry_time, TimeCurrent());
    for (int i = HistoryDealsTotal() - 1; i >= 0; i--) {
        ulong ticket = HistoryDealGetTicket(i);
        if (ticket == g_currentTrade.ticket) {
            g_currentTrade.exit_price = HistoryDealGetDouble(ticket, DEAL_PRICE);
            g_currentTrade.exit_time = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
            g_currentTrade.exit_reason = (int)HistoryDealGetInteger(ticket, DEAL_REASON);
            g_currentTrade.profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            g_currentTrade.was_winner = (g_currentTrade.profit > 0);
            g_currentTrade.hold_duration_minutes = (int)((g_currentTrade.exit_time - g_currentTrade.entry_time) / 60);
            break;
        }
    }
    
    // Ajouter à l'historique d'apprentissage
    if (g_learning != NULL) {
        g_learning->AddTradeToHistory(g_currentTrade);
    }
    
    // Mettre à jour la stratégie adaptative
    if (g_adaptiveStrategy != NULL) {
        g_adaptiveStrategy->OnTradeClose(g_currentTrade);
    }
    
    // Mettre à jour l'analyseur de patterns
    if (g_patternAnalyzer != NULL) {
        g_patternAnalyzer->AddTradeResult(g_currentTrade.symbol, 
                                        g_currentTrade.entry_price, 
                                        g_currentTrade.exit_price, 
                                        g_currentTrade.was_winner);
    }
    
    Print("📊 Trade complété: ", g_currentTrade.symbol, 
          " - Profit: ", DoubleToString(g_currentTrade.profit, 2),
          " - Gagnant: ", g_currentTrade.was_winner ? "OUI" : "NON");
    
    g_tradeInProgress = false;
}

//+------------------------------------------------------------------+
//| Vérifier les conditions de risque                               |
//+------------------------------------------------------------------+
bool CheckRiskConditions(const AdaptiveSignal &signal)
{
    // Vérifier le drawdown maximum
    double currentDrawdown = (g_peakBalance - g_currentBalance) / g_peakBalance * 100;
    if (currentDrawdown > InpMaxDrawdown) {
        Print("⚠️ Drawdown maximum atteint: ", DoubleToString(currentDrawdown, 2), "%");
        return false;
    }
    
    // Vérifier la perte quotidienne
    double dailyLoss = (g_initialBalance - g_currentBalance) / g_initialBalance * 100;
    if (dailyLoss > InpMaxDailyLoss) {
        Print("⚠️ Perte quotidienne maximum atteinte: ", DoubleToString(dailyLoss, 2), "%");
        return false;
    }
    
    // Vérifier le risque par trade
    double riskAmount = g_currentBalance * InpMaxRiskPerTrade / 100;
    double tradeRisk = MathAbs(signal.entry_price - signal.stop_loss) * signal.lot_size * 100000;
    if (tradeRisk > riskAmount) {
        Print("⚠️ Risque par trade trop élevé: ", DoubleToString(tradeRisk, 2), " > ", DoubleToString(riskAmount, 2));
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Exécuter le trading original (sans apprentissage)               |
//+------------------------------------------------------------------+
void ExecuteOriginalTrading()
{
    // Ici, vous pouvez intégrer la logique de trading originale
    // ou appeler les fonctions existantes de l'EA original
    Print("📈 Exécution du trading original (sans apprentissage)");
}

//+------------------------------------------------------------------+
//| Gérer les notifications                                          |
//+------------------------------------------------------------------+
void ManageNotifications()
{
    if (TimeCurrent() - g_lastNotification < g_notificationInterval) return;
    
    g_lastNotification = TimeCurrent();
    
    // Notifier les mises à jour d'apprentissage
    if (InpNotifyOnLearning && g_learning != NULL) {
        // Vérifier s'il y a des nouvelles données d'apprentissage
        // (Cette logique dépendrait de l'implémentation spécifique)
    }
    
    // Notifier les performances
    if (InpNotifyOnPerformance && g_adaptiveStrategy != NULL) {
        PerformanceStats stats = g_adaptiveStrategy->GetPerformanceStats();
        if (stats.total_trades > 0 && stats.total_trades % 10 == 0) {
            SendNotification("Rapport de performance: " + 
                           DoubleToString(stats.win_rate * 100, 1) + "% de succès, " +
                           DoubleToString(stats.total_profit, 2) + " profit total");
        }
    }
}

//+------------------------------------------------------------------+
//| Gérer les rapports de performance                                |
//+------------------------------------------------------------------+
void ManagePerformanceReports()
{
    if (TimeCurrent() - g_lastPerformanceReport < g_performanceReportInterval) return;
    
    g_lastPerformanceReport = TimeCurrent();
    
    if (g_adaptiveStrategy != NULL) {
        g_adaptiveStrategy->PrintPerformanceReport();
    }
    
    if (g_learning != NULL) {
        g_learning->PrintLearningStats();
    }
    
    if (g_patternAnalyzer != NULL) {
        string symbols[];
        StringSplit(InpSymbols, ',', symbols);
        for (int i = 0; i < ArraySize(symbols); i++) {
            StringTrimLeft(symbols[i]);
            StringTrimRight(symbols[i]);
            g_patternAnalyzer->PrintZoneAnalysis(symbols[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Fonction de gestion des événements de trading                   |
//+------------------------------------------------------------------+
void OnTrade()
{
    // Cette fonction est appelée à chaque fois qu'un trade est exécuté
    if (g_adaptiveStrategy != NULL) {
        // Mettre à jour la stratégie adaptative
        // (Cette logique dépendrait de l'implémentation spécifique)
    }
}

//+------------------------------------------------------------------+
//| Fonction de gestion des événements de timer                     |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Cette fonction peut être utilisée pour des tâches périodiques
    if (g_learning != NULL) {
        g_learning->AnalyzePerformance();
    }
}

//+------------------------------------------------------------------+
//| Fonction de gestion des événements de chart                     |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    // Gérer les événements de chart si nécessaire
    if (id == CHARTEVENT_KEYDOWN) {
        // Gérer les touches de raccourci
        if (lparam == 'L') { // Touche L pour afficher les statistiques d'apprentissage
            if (g_learning != NULL) {
                g_learning->PrintLearningStats();
            }
        } else if (lparam == 'P') { // Touche P pour afficher les performances
            if (g_adaptiveStrategy != NULL) {
                g_adaptiveStrategy->PrintPerformanceReport();
            }
        } else if (lparam == 'R') { // Touche R pour réinitialiser l'apprentissage
            if (g_learning != NULL) {
                g_learning->ResetLearning();
                Print("🔄 Apprentissage réinitialisé");
            }
        }
    }
}
