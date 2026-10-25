//+------------------------------------------------------------------+
//| AdaptiveStrategy.mqh                                            |
//| Stratégie adaptative basée sur l'apprentissage par renforcement |
//| Version: 1.0                                                    |
//+------------------------------------------------------------------+

#ifndef ADAPTIVESTRATEGY_MQH
#define ADAPTIVESTRATEGY_MQH

#property copyright "SpikeHunter AI"
#property version   "1.00"
#property strict

#include "ReinforcementLearning.mqh"
#include "PricePatternAnalyzer.mqh"

//+------------------------------------------------------------------+
//| Déclarations forward pour éviter les erreurs de compilation      |
//+------------------------------------------------------------------+
class CTradeExecutor;
class CRiskManager;
class CSignalDetector;
class CSignalValidator;

//+------------------------------------------------------------------+
//| Structures pour la stratégie adaptative                         |
//+------------------------------------------------------------------+

// Structure pour les paramètres adaptatifs
struct AdaptiveParameters {
    double lot_size_multiplier;     // Multiplicateur de taille de lot
    double atr_multiplier;          // Multiplicateur ATR pour SL/TP
    double confidence_threshold;    // Seuil de confiance minimum
    double risk_multiplier;         // Multiplicateur de risque
    int max_trades_per_session;     // Nombre max de trades par session
    int cooldown_minutes;           // Cooldown entre trades
    bool enable_high_prob_only;     // Trader seulement les zones haute probabilité
    double profit_target_multiplier; // Multiplicateur de profit target
    double stop_loss_multiplier;    // Multiplicateur de stop loss
    int session_preference;         // Préférence de session (0=Asian, 1=London, 2=NY, 3=Overlap)
    bool use_dynamic_sizing;        // Utiliser le sizing dynamique
    bool use_pattern_filtering;     // Utiliser le filtrage par patterns
    double pattern_confidence_min;  // Confiance minimum des patterns
};

// Structure pour les statistiques de performance
struct PerformanceStats {
    double total_profit;            // Profit total
    double total_trades;            // Nombre total de trades
    double winning_trades;          // Nombre de trades gagnants
    double losing_trades;           // Nombre de trades perdants
    double win_rate;                // Taux de gain
    double profit_factor;           // Facteur de profit
    double avg_profit;              // Profit moyen
    double avg_loss;                // Perte moyenne
    double max_drawdown;            // Drawdown maximum
    double sharpe_ratio;            // Ratio de Sharpe
    double recovery_factor;         // Facteur de récupération
    datetime last_update;           // Dernière mise à jour
    double monthly_return;          // Rendement mensuel
    double weekly_return;           // Rendement hebdomadaire
    double daily_return;            // Rendement quotidien
};

// Structure pour les signaux adaptatifs
struct AdaptiveSignal {
    int direction;                  // Direction du signal
    double confidence;              // Confiance du signal (0-1)
    double entry_price;             // Prix d'entrée suggéré
    double stop_loss;               // Stop loss suggéré
    double take_profit;             // Take profit suggéré
    double lot_size;                // Taille de lot suggérée
    string reason;                  // Raison du signal
    double risk_reward_ratio;       // Ratio risque/récompense
    bool is_high_probability;       // Signal haute probabilité
    int session;                    // Session de marché
    double pattern_strength;        // Force du pattern
    string symbol;                  // Symbole
    datetime timestamp;             // Timestamp du signal
};

//+------------------------------------------------------------------+
//| Classe principale de stratégie adaptative                       |
//+------------------------------------------------------------------+
class CAdaptiveStrategy {
private:
    CReinforcementLearning m_learning;        // Système d'apprentissage
    CPricePatternAnalyzer m_patternAnalyzer;  // Analyseur de patterns
    AdaptiveParameters m_params;               // Paramètres adaptatifs
    PerformanceStats m_stats;                  // Statistiques de performance
    AdaptiveSignal m_lastSignal;               // Dernier signal généré
    datetime m_lastAnalysis;                   // Dernière analyse
    int m_analysisInterval;                    // Intervalle d'analyse en minutes
    double m_initialBalance;                   // Balance initiale
    double m_currentBalance;                   // Balance actuelle
    double m_peakBalance;                      // Balance maximale
    double m_troughBalance;                    // Balance minimale
    int m_consecutiveLosses;                   // Pertes consécutives
    int m_consecutiveWins;                     // Gains consécutifs
    datetime m_lastTradeTime;                  // Dernière heure de trade
    bool m_isLearningMode;                     // Mode d'apprentissage
    int m_learningTrades;                      // Nombre de trades d'apprentissage
    
    // Méthodes privées
    void UpdateParameters();
    void UpdatePerformanceStats();
    void AnalyzeMarketConditions(string symbol, MqlRates &rates[]);
    void OptimizeRiskParameters();
    void AdjustLotSize();
    void AdjustStopLossTakeProfit();
    void UpdateSessionPreference();
    void UpdatePatternConfidence();
    double CalculateOptimalLotSize(string symbol, double price, double confidence);
    double CalculateOptimalStopLoss(string symbol, double price, int direction);
    double CalculateOptimalTakeProfit(string symbol, double price, int direction);
    bool IsGoodTimeToTrade(string symbol, int session);
    bool IsPriceInOptimalZone(string symbol, double price, int direction);
    void LearnFromTradeResult(TradeHistory trade);
    void AdjustStrategyAfterLoss();
    void AdjustStrategyAfterWin();
    void ResetAfterConsecutiveLosses();
    void OptimizeAfterConsecutiveWins();
    
public:
    // Constructeur
    CAdaptiveStrategy();
    
    // Destructeur
    ~CAdaptiveStrategy();
    
    // Méthodes d'initialisation
    void Initialize(string symbol);
    void SetLearningMode(bool enable);
    void SetInitialBalance(double balance);
    
    // Méthodes de génération de signaux
    AdaptiveSignal GenerateSignal(string symbol, MqlRates &rates[]);
    bool ValidateSignal(AdaptiveSignal signal);
    void UpdateSignalConfidence(AdaptiveSignal &signal);
    
    // Méthodes de gestion des trades
    void OnTradeOpen(TradeHistory trade);
    void OnTradeClose(TradeHistory trade);
    void OnTradeUpdate(TradeHistory trade);
    
    // Méthodes d'analyse
    void AnalyzePerformance();
    void AnalyzeSymbolPerformance(string symbol);
    void AnalyzeSessionPerformance();
    void AnalyzePatternPerformance();
    
    // Méthodes de paramètres
    void SetParameter(string paramName, double value);
    double GetParameter(string paramName);
    void ResetParameters();
    void OptimizeParameters();
    
    // Méthodes de reporting
    void PrintPerformanceReport();
    void PrintSymbolReport(string symbol);
    void PrintParameterReport();
    void ExportPerformanceData(string filename);
    
    // Getters
    PerformanceStats GetPerformanceStats();
    AdaptiveParameters GetParameters();
    double GetCurrentConfidence(string symbol);
    bool IsLearningMode();
    int GetLearningTrades();
    
    // Méthodes de sauvegarde/chargement
    void SaveStrategyState(string filename);
    void LoadStrategyState(string filename);
    void ResetStrategy();
};

//+------------------------------------------------------------------+
//| Constructeur                                                     |
//+------------------------------------------------------------------+
CAdaptiveStrategy::CAdaptiveStrategy() {
    
    // Initialiser les paramètres par défaut
    m_params.lot_size_multiplier = 1.0;
    m_params.atr_multiplier = 2.0;
    m_params.confidence_threshold = 0.6;
    m_params.risk_multiplier = 1.0;
    m_params.max_trades_per_session = 5;
    m_params.cooldown_minutes = 30;
    m_params.enable_high_prob_only = false;
    m_params.profit_target_multiplier = 1.0;
    m_params.stop_loss_multiplier = 1.0;
    m_params.session_preference = 1; // London par défaut
    m_params.use_dynamic_sizing = true;
    m_params.use_pattern_filtering = true;
    m_params.pattern_confidence_min = 0.5;
    
    // Initialiser les statistiques
    m_stats.total_profit = 0.0;
    m_stats.total_trades = 0;
    m_stats.winning_trades = 0;
    m_stats.losing_trades = 0;
    m_stats.win_rate = 0.0;
    m_stats.profit_factor = 1.0;
    m_stats.avg_profit = 0.0;
    m_stats.avg_loss = 0.0;
    m_stats.max_drawdown = 0.0;
    m_stats.sharpe_ratio = 0.0;
    m_stats.recovery_factor = 0.0;
    m_stats.last_update = TimeCurrent();
    m_stats.monthly_return = 0.0;
    m_stats.weekly_return = 0.0;
    m_stats.daily_return = 0.0;
    
    m_lastAnalysis = 0;
    m_analysisInterval = 15; // Analyser toutes les 15 minutes
    m_initialBalance = 10000.0;
    m_currentBalance = m_initialBalance;
    m_peakBalance = m_initialBalance;
    m_troughBalance = m_initialBalance;
    m_consecutiveLosses = 0;
    m_consecutiveWins = 0;
    m_lastTradeTime = 0;
    m_isLearningMode = true;
    m_learningTrades = 0;
    
    Print("🧠 Stratégie adaptative initialisée");
}

//+------------------------------------------------------------------+
//| Destructeur                                                      |
//+------------------------------------------------------------------+
CAdaptiveStrategy::~CAdaptiveStrategy() {
}

//+------------------------------------------------------------------+
//| Initialiser la stratégie                                        |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::Initialize(string symbol)
{
    m_learning.Initialize(symbol);
    m_patternAnalyzer.Initialize(symbol);
    Print("🚀 Stratégie adaptative initialisée pour ", symbol);
}

//+------------------------------------------------------------------+
//| Activer/désactiver le mode d'apprentissage                      |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::SetLearningMode(const bool enable)
{
    m_isLearningMode = enable;
    Print("🧠 Mode d'apprentissage: ", enable ? "ACTIVÉ" : "DÉSACTIVÉ");
}

//+------------------------------------------------------------------+
//| Définir la balance initiale                                     |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::SetInitialBalance(double balance)
{
    m_initialBalance = balance;
    m_currentBalance = balance;
    m_peakBalance = balance;
    m_troughBalance = balance;
}

//+------------------------------------------------------------------+
//| Générer un signal adaptatif                                     |
//+------------------------------------------------------------------+
AdaptiveSignal CAdaptiveStrategy::GenerateSignal(string symbol, MqlRates &rates[]) {
    AdaptiveSignal signal = {0};
    signal.symbol = symbol;
    signal.timestamp = TimeCurrent();
    
    // Vérifier si c'est le bon moment pour trader
    if (!IsGoodTimeToTrade(symbol, 0)) {
        signal.direction = 0; // Pas de signal
        signal.reason = "Mauvais timing";
        return signal;
    }
    
    // Analyser les conditions du marché
    AnalyzeMarketConditions(symbol, rates);
    
    // Obtenir la confiance du système d'apprentissage
    double learningConfidence = m_learning.GetSymbolConfidence(symbol, rates[0].close);
    
    // Obtenir la probabilité de succès des patterns
    double patternConfidence = m_patternAnalyzer.GetPriceSuccessProbability(symbol, rates[0].close, ORDER_TYPE_BUY);
    
    // Calculer la confiance globale
    signal.confidence = (learningConfidence + patternConfidence) / 2.0;
    
    // Vérifier le seuil de confiance
    if (signal.confidence < m_params.confidence_threshold) {
        signal.direction = 0;
        signal.reason = "Confiance insuffisante";
        return signal;
    }
    
    // Déterminer la direction basée sur l'analyse
    double buyProbability = m_patternAnalyzer.GetPriceSuccessProbability(symbol, rates[0].close, ORDER_TYPE_BUY);
    double sellProbability = m_patternAnalyzer.GetPriceSuccessProbability(symbol, rates[0].close, ORDER_TYPE_SELL);
    
    if (buyProbability > sellProbability && buyProbability > 0.6) {
        signal.direction = ORDER_TYPE_BUY;
        signal.entry_price = rates[0].close;
        signal.reason = "Signal d'achat haute probabilité";
    } else if (sellProbability > buyProbability && sellProbability > 0.6) {
        signal.direction = ORDER_TYPE_SELL;
        signal.entry_price = rates[0].close;
        signal.reason = "Signal de vente haute probabilité";
    } else {
        signal.direction = 0;
        signal.reason = "Pas de direction claire";
        return signal;
    }
    
    // Calculer les niveaux de prix
    signal.stop_loss = CalculateOptimalStopLoss(symbol, signal.entry_price, signal.direction);
    signal.take_profit = CalculateOptimalTakeProfit(symbol, signal.entry_price, signal.direction);
    signal.lot_size = CalculateOptimalLotSize(symbol, signal.entry_price, signal.confidence);
    
    // Calculer le ratio risque/récompense
    double risk = MathAbs(signal.entry_price - signal.stop_loss);
    double reward = MathAbs(signal.take_profit - signal.entry_price);
    signal.risk_reward_ratio = (risk > 0) ? reward / risk : 0;
    
    // Vérifier si c'est une zone de haute probabilité
    signal.is_high_probability = m_patternAnalyzer.IsPriceInHighProbabilityZone(symbol, signal.entry_price);
    
    // Obtenir la force du pattern
    signal.pattern_strength = m_patternAnalyzer.GetZoneStrength(symbol, signal.entry_price);
    
    // Déterminer la session
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    if (time.hour >= 8 && time.hour < 16) signal.session = 1; // London
    else if (time.hour >= 13 && time.hour < 21) signal.session = 2; // NY
    else if (time.hour >= 8 && time.hour < 16) signal.session = 3; // Overlap
    else signal.session = 0; // Asian
    
    m_lastSignal = signal;
    return signal;
}

//+------------------------------------------------------------------+
//| Valider un signal                                                |
//+------------------------------------------------------------------+
bool CAdaptiveStrategy::ValidateSignal(const AdaptiveSignal &signal) {
    if (signal.direction == 0) return false;
    if (signal.confidence < m_params.confidence_threshold) return false;
    if (signal.risk_reward_ratio < 1.0) return false;
    if (signal.lot_size < 0.01) return false;
    
    // Vérifier le cooldown
    if (TimeCurrent() - m_lastTradeTime < m_params.cooldown_minutes * 60) {
        return false;
    }
    
    // Vérifier le nombre maximum de trades par session
    // (Cette vérification nécessiterait un compteur de trades par session)
    
    return true;
}

//+------------------------------------------------------------------+
//| Mettre à jour la confiance d'un signal                          |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::UpdateSignalConfidence(AdaptiveSignal &signal)
{
    // Ajuster la confiance basée sur les conditions actuelles
    double timeAdjustment = 1.0;
    double volatilityAdjustment = 1.0;
    double patternAdjustment = 1.0;
    
    // Ajustement temporel
    MqlDateTime time;
    TimeToStruct(TimeCurrent(), time);
    if (time.hour >= 8 && time.hour < 16) timeAdjustment = 1.2; // London
    else if (time.hour >= 13 && time.hour < 21) timeAdjustment = 1.1; // NY
    
    // Ajustement de volatilité
    double atr = iATR(signal.symbol, PERIOD_CURRENT, 14);
    if (atr > 0) {
        double currentATR = atr;
        double avgATR = 0;
        // Calculer l'ATR moyen (simplifié)
        for (int i = 0; i < 20; i++) {
            avgATR += iATR(signal.symbol, PERIOD_CURRENT, 14);
        }
        avgATR /= 20;
        
        if (currentATR > avgATR * 1.5) volatilityAdjustment = 0.8; // Volatilité élevée
        else if (currentATR < avgATR * 0.5) volatilityAdjustment = 1.1; // Volatilité faible
    }
    
    // Ajustement de pattern
    if (signal.is_high_probability) patternAdjustment = 1.3;
    else if (signal.pattern_strength < 0.3) patternAdjustment = 0.7;
    
    // Appliquer les ajustements
    signal.confidence *= timeAdjustment * volatilityAdjustment * patternAdjustment;
    signal.confidence = MathMin(1.0, MathMax(0.0, signal.confidence));
}

//+------------------------------------------------------------------+
//| Calculer la taille de lot optimale                              |
//+------------------------------------------------------------------+
double CAdaptiveStrategy::CalculateOptimalLotSize(string symbol, double price, double confidence)
{
    double baseLotSize = m_learning.GetOptimalLotSize(symbol);
    
    // Ajuster selon la confiance
    double confidenceMultiplier = 0.5 + (confidence * 1.5); // 0.5 à 2.0
    
    // Ajuster selon les paramètres adaptatifs
    double adaptiveMultiplier = m_params.lot_size_multiplier;
    
    // Ajuster selon le mode d'apprentissage
    if (m_isLearningMode) {
        adaptiveMultiplier *= 0.5; // Réduire la taille en mode apprentissage
    }
    
    // Ajuster selon les pertes consécutives
    if (m_consecutiveLosses > 2) {
        adaptiveMultiplier *= 0.5; // Réduire après 2 pertes consécutives
    }
    
    // Ajuster selon les gains consécutifs
    if (m_consecutiveWins > 3) {
        adaptiveMultiplier *= 1.2; // Augmenter après 3 gains consécutifs
    }
    
    double finalLotSize = baseLotSize * confidenceMultiplier * adaptiveMultiplier;
    
    // Limiter la taille de lot
    return MathMax(0.01, MathMin(10.0, finalLotSize));
}

//+------------------------------------------------------------------+
//| Calculer le stop loss optimal                                   |
//+------------------------------------------------------------------+
double CAdaptiveStrategy::CalculateOptimalStopLoss(string symbol, double price, int direction)
{
    double atr = iATR(symbol, PERIOD_CURRENT, 14);
    if (atr <= 0) atr = price * 0.01; // Fallback
    
    double atrMultiplier = m_learning.GetOptimalATRMultiplier(symbol);
    atrMultiplier *= m_params.atr_multiplier;
    atrMultiplier *= m_params.stop_loss_multiplier;
    
    double stopDistance = atr * atrMultiplier;
    
    if (direction == ORDER_TYPE_BUY) {
        return price - stopDistance;
    } else {
        return price + stopDistance;
    }
}

//+------------------------------------------------------------------+
//| Calculer le take profit optimal                                 |
//+------------------------------------------------------------------+
double CAdaptiveStrategy::CalculateOptimalTakeProfit(string symbol, double price, int direction)
{
    double atr = iATR(symbol, PERIOD_CURRENT, 14);
    if (atr <= 0) atr = price * 0.01; // Fallback
    
    double atrMultiplier = m_learning.GetOptimalATRMultiplier(symbol);
    atrMultiplier *= m_params.atr_multiplier;
    atrMultiplier *= m_params.profit_target_multiplier;
    
    // Ajuster selon le ratio risque/récompense souhaité
    double riskRewardRatio = 2.0; // Par défaut 1:2
    if (m_consecutiveWins > 2) riskRewardRatio = 1.5; // Réduire après gains
    if (m_consecutiveLosses > 1) riskRewardRatio = 3.0; // Augmenter après pertes
    
    double profitDistance = atr * atrMultiplier * riskRewardRatio;
    
    if (direction == ORDER_TYPE_BUY) {
        return price + profitDistance;
    } else {
        return price - profitDistance;
    }
}

//+------------------------------------------------------------------+
//| Vérifier si c'est le bon moment pour trader                     |
//+------------------------------------------------------------------+
bool CAdaptiveStrategy::IsGoodTimeToTrade(string symbol, int session) {
    // Vérifier le cooldown
    if (TimeCurrent() - m_lastTradeTime < m_params.cooldown_minutes * 60) {
        return false;
    }
    
    // Vérifier la session préférée
    if (m_params.session_preference != session && m_params.session_preference != 3) {
        return false;
    }
    
    // Vérifier les pertes consécutives
    if (m_consecutiveLosses >= 5) {
        return false; // Arrêter après 5 pertes consécutives
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est dans une zone optimale                 |
//+------------------------------------------------------------------+
bool CAdaptiveStrategy::IsPriceInOptimalZone(string symbol, double price, int direction) {
    if (!m_params.use_pattern_filtering) return true;
    
    return m_patternAnalyzer.IsPriceInHighProbabilityZone(symbol, price);
}

//+------------------------------------------------------------------+
//| Apprendre du résultat d'un trade                                |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::LearnFromTradeResult(const TradeHistory &trade)
{
    // Ajouter à l'historique d'apprentissage
    m_learning.AddTradeToHistory(trade);
    
    // Mettre à jour l'analyseur de patterns
    m_patternAnalyzer.AddTradeResult(trade.symbol, trade.entry_price, trade.exit_price, trade.was_winner);
    
    // Mettre à jour les statistiques
    UpdatePerformanceStats();
    
    // Ajuster la stratégie
    if (trade.was_winner) {
        AdjustStrategyAfterWin();
    } else {
        AdjustStrategyAfterLoss();
    }
    
    // Mettre à jour les paramètres
    UpdateParameters();
}

//+------------------------------------------------------------------+
//| Ajuster la stratégie après un gain                              |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::AdjustStrategyAfterWin()
{
    m_consecutiveWins++;
    m_consecutiveLosses = 0;
    
    // Augmenter légèrement la confiance
    m_params.confidence_threshold = MathMax(0.5, m_params.confidence_threshold - 0.01);
    
    // Optimiser après plusieurs gains consécutifs
    if (m_consecutiveWins >= 3) {
        OptimizeAfterConsecutiveWins();
    }
}

//+------------------------------------------------------------------+
//| Ajuster la stratégie après une perte                            |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::AdjustStrategyAfterLoss()
{
    m_consecutiveLosses++;
    m_consecutiveWins = 0;
    
    // Augmenter le seuil de confiance
    m_params.confidence_threshold = MathMin(0.9, m_params.confidence_threshold + 0.02);
    
    // Réduire la taille des lots
    m_params.lot_size_multiplier *= 0.9;
    
    // Réinitialiser après plusieurs pertes consécutives
    if (m_consecutiveLosses >= 5) {
        ResetAfterConsecutiveLosses();
    }
}

//+------------------------------------------------------------------+
//| Réinitialiser après pertes consécutives                         |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::ResetAfterConsecutiveLosses()
{
    m_consecutiveLosses = 0;
    m_params.confidence_threshold = 0.7; // Seuil plus élevé
    m_params.lot_size_multiplier = 0.5; // Réduire la taille des lots
    m_params.cooldown_minutes = 60; // Cooldown plus long
    
    Print("🔄 Stratégie réinitialisée après pertes consécutives");
}

//+------------------------------------------------------------------+
//| Optimiser après gains consécutifs                               |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::OptimizeAfterConsecutiveWins()
{
    // Augmenter légèrement la taille des lots
    m_params.lot_size_multiplier = MathMin(2.0, m_params.lot_size_multiplier * 1.1);
    
    // Réduire le cooldown
    m_params.cooldown_minutes = MathMax(15, m_params.cooldown_minutes - 5);
    
    Print("📈 Stratégie optimisée après gains consécutifs");
}

//+------------------------------------------------------------------+
//| Mettre à jour les paramètres                                    |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::UpdateParameters()
{
    // Mettre à jour les paramètres basés sur les performances
    if (m_stats.win_rate > 0.7) {
        m_params.confidence_threshold = MathMax(0.5, m_params.confidence_threshold - 0.01);
    } else if (m_stats.win_rate < 0.4) {
        m_params.confidence_threshold = MathMin(0.9, m_params.confidence_threshold + 0.01);
    }
    
    // Ajuster le multiplicateur de lot basé sur le profit
    if (m_stats.profit_factor > 2.0) {
        m_params.lot_size_multiplier = MathMin(2.0, m_params.lot_size_multiplier * 1.05);
    } else if (m_stats.profit_factor < 1.0) {
        m_params.lot_size_multiplier = MathMax(0.5, m_params.lot_size_multiplier * 0.95);
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour les statistiques de performance                   |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::UpdatePerformanceStats()
{
    m_stats.total_trades++;
    // Note: was_winner and profit fields need to be passed from trade result
    // This method should be called with trade result data
    
    m_stats.win_rate = m_stats.winning_trades / m_stats.total_trades;
    m_stats.avg_profit = m_stats.total_profit / m_stats.total_trades;
    
    // Calculer le facteur de profit
    if (m_stats.avg_loss != 0) {
        m_stats.profit_factor = MathAbs(m_stats.avg_profit) / MathAbs(m_stats.avg_loss);
    }
    
    // Mettre à jour la balance
    // m_currentBalance += profit; // Should be passed as parameter
    if (m_currentBalance > m_peakBalance) {
        m_peakBalance = m_currentBalance;
    }
    if (m_currentBalance < m_troughBalance) {
        m_troughBalance = m_currentBalance;
    }
    
    // Calculer le drawdown
    m_stats.max_drawdown = (m_peakBalance - m_troughBalance) / m_peakBalance;
    
    m_stats.last_update = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Analyser les conditions du marché                               |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::AnalyzeMarketConditions(string symbol, MqlRates &rates[])
{
    // Mettre à jour l'analyse des patterns
    m_patternAnalyzer.UpdateAnalysis(symbol, rates);
    
    // Analyser les performances par session
    AnalyzeSessionPerformance();
    
    // Optimiser les paramètres de risque
    OptimizeRiskParameters();
}

//+------------------------------------------------------------------+
//| Optimiser les paramètres de risque                              |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::OptimizeRiskParameters()
{
    // Ajuster le multiplicateur ATR basé sur la volatilité
    // Note: This method needs a symbol parameter to work properly
    // For now, using a default symbol or the current chart symbol
    string symbol = Symbol();
    
    double avgATR = 0;
    for (int i = 0; i < 20; i++) {
        avgATR += iATR(symbol, PERIOD_CURRENT, 14);
    }
    avgATR /= 20;
    
    double currentATR = iATR(symbol, PERIOD_CURRENT, 14);
    if (currentATR > avgATR * 1.5) {
        m_params.atr_multiplier *= 0.9; // Réduire en haute volatilité
    } else if (currentATR < avgATR * 0.5) {
        m_params.atr_multiplier *= 1.1; // Augmenter en faible volatilité
    }
}

//+------------------------------------------------------------------+
//| Afficher le rapport de performance                               |
//+------------------------------------------------------------------+
void CAdaptiveStrategy::PrintPerformanceReport()
{
    Print("📊 === RAPPORT DE PERFORMANCE ===");
    Print("Total trades: ", m_stats.total_trades);
    Print("Taux de gain: ", DoubleToString(m_stats.win_rate * 100, 2), "%");
    Print("Profit total: ", DoubleToString(m_stats.total_profit, 2));
    Print("Facteur de profit: ", DoubleToString(m_stats.profit_factor, 2));
    Print("Drawdown max: ", DoubleToString(m_stats.max_drawdown * 100, 2), "%");
    Print("Balance actuelle: ", DoubleToString(m_currentBalance, 2));
    Print("Gains consécutifs: ", m_consecutiveWins);
    Print("Pertes consécutives: ", m_consecutiveLosses);
}

//+------------------------------------------------------------------+
//| Obtenir les statistiques de performance                          |
//+------------------------------------------------------------------+
PerformanceStats CAdaptiveStrategy::GetPerformanceStats() {
    return m_stats;
}

//+------------------------------------------------------------------+
//| Obtenir les paramètres                                          |
//+------------------------------------------------------------------+
AdaptiveParameters CAdaptiveStrategy::GetParameters() {
    return m_params;
}

//+------------------------------------------------------------------+
//| Obtenir la confiance actuelle                                   |
//+------------------------------------------------------------------+
double CAdaptiveStrategy::GetCurrentConfidence(string symbol)
{
    return m_learning.GetSymbolConfidence(symbol, SymbolInfoDouble(symbol, SYMBOL_BID));
}

//+------------------------------------------------------------------+
//| Vérifier si en mode apprentissage                               |
//+------------------------------------------------------------------+
bool CAdaptiveStrategy::IsLearningMode() {
    return m_isLearningMode;
}

//+------------------------------------------------------------------+
//| Obtenir le nombre de trades d'apprentissage                     |
//+------------------------------------------------------------------+
int CAdaptiveStrategy::GetLearningTrades()
{
    return m_learningTrades;
}

#endif // ADAPTIVESTRATEGY_MQH
