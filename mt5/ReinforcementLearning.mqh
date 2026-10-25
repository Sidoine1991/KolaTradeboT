//+------------------------------------------------------------------+
//| ReinforcementLearning.mqh                                       |
//| Système d'apprentissage par renforcement pour SpikeHunter EA   |
//| Version: 1.0                                                    |
//+------------------------------------------------------------------+

#ifndef REINFORCEMENTLEARNING_MQH
#define REINFORCEMENTLEARNING_MQH

#property copyright "SpikeHunter AI"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Déclarations forward pour éviter les erreurs de compilation      |
//+------------------------------------------------------------------+
class CTradeExecutor;
class CRiskManager;
class CSignalDetector;
class CSignalValidator;

//+------------------------------------------------------------------+
//| Structures pour l'historique des trades                         |
//+------------------------------------------------------------------+

// Structure pour stocker l'historique complet d'un trade
struct TradeHistory {
    ulong ticket;                    // Ticket du trade
    string symbol;                   // Symbole tradé
    int direction;                   // Direction (BUY/SELL)
    double entry_price;              // Prix d'entrée
    double exit_price;               // Prix de sortie
    double lot_size;                 // Taille de la position
    double profit;                   // Profit/Perte final
    datetime entry_time;             // Heure d'entrée
    datetime exit_time;              // Heure de sortie
    int exit_reason;                 // Raison de sortie (TP, SL, Manual, etc.)
    double atr_at_entry;             // ATR au moment de l'entrée
    double spread_at_entry;          // Spread au moment de l'entrée
    double confidence_score;         // Score de confiance initial
    bool was_winner;                 // Trade gagnant ou perdant
    double max_favorable;            // Plus haut profit atteint
    double max_adverse;              // Plus bas profit atteint
    int hold_duration_minutes;       // Durée de détention en minutes
    double volatility_at_entry;      // Volatilité au moment de l'entrée
    int market_session;              // Session de marché (Asian, London, NY)
    double price_range_high;         // Plus haut de la plage de prix
    double price_range_low;          // Plus bas de la plage de prix
    double price_range_mid;          // Milieu de la plage de prix
    bool in_support_zone;            // Dans une zone de support
    bool in_resistance_zone;         // Dans une zone de résistance
    double distance_to_support;      // Distance au support le plus proche
    double distance_to_resistance;   // Distance à la résistance la plus proche
};

// Structure pour analyser les patterns de succès/échec
struct PricePattern {
    double price_level;              // Niveau de prix
    double success_rate;             // Taux de succès à ce niveau
    int total_trades;                // Nombre total de trades
    int winning_trades;              // Nombre de trades gagnants
    double avg_profit;               // Profit moyen
    double avg_loss;                 // Perte moyenne
    double profit_factor;            // Facteur de profit
    datetime last_updated;           // Dernière mise à jour
};

// Structure pour l'apprentissage par symbole
struct SymbolLearning {
    string symbol;                   // Symbole
    double success_rate;             // Taux de succès global
    int total_trades;                // Nombre total de trades
    double avg_profit_per_trade;     // Profit moyen par trade
    double best_price_ranges[10];    // Meilleures plages de prix
    double worst_price_ranges[10];   // Pires plages de prix
    int best_session;                // Meilleure session de trading
    double optimal_lot_size;         // Taille de lot optimale
    double optimal_atr_multiplier;   // Multiplicateur ATR optimal
    datetime last_analysis;          // Dernière analyse
    PricePattern price_patterns[100]; // Patterns de prix
    int pattern_count;               // Nombre de patterns
};

//+------------------------------------------------------------------+
//| Classe principale d'apprentissage par renforcement              |
//+------------------------------------------------------------------+
class CReinforcementLearning {
private:
    TradeHistory m_tradeHistory[1000];  // Historique des trades
    int m_historyCount;                 // Nombre de trades dans l'historique
    SymbolLearning m_symbolLearning[50]; // Apprentissage par symbole
    int m_symbolCount;                  // Nombre de symboles appris
    double m_learningRate;              // Taux d'apprentissage
    double m_discountFactor;            // Facteur d'escompte
    double m_explorationRate;           // Taux d'exploration
    int m_maxHistorySize;               // Taille maximale de l'historique
    string m_dataFile;                  // Fichier de sauvegarde des données
    
    // Méthodes publiques
    void SaveLearningData();
    void LoadLearningData();
    void UpdateSymbolLearning(const TradeHistory &trade);
    void UpdatePricePatterns(const TradeHistory &trade);
    double CalculateReward(const TradeHistory &trade);
    void OptimizeParameters();
    int FindSymbolIndex(const string symbol);
    void CleanOldData();
    
public:
    // Constructeur
    CReinforcementLearning();
    
    // Destructeur
    ~CReinforcementLearning();
    
    // Méthodes publiques
    void AddTradeToHistory(const TradeHistory &trade);
    void UpdateTradeExit(const ulong ticket, const double exit_price, const int exit_reason);
    double GetSymbolConfidence(const string symbol, const double price);
    double GetOptimalLotSize(const string symbol);
    double GetOptimalATRMultiplier(const string symbol);
    int GetBestTradingSession(const string symbol);
    bool IsPriceInSuccessZone(const string symbol, const double price);
    double GetSuccessProbability(const string symbol, const double price, const int direction);
    void AnalyzePerformance();
    void PrintLearningStats();
    void ResetLearning();
    void ExportLearningData(const string filename);
    void ImportLearningData(const string filename);
    
    // Getters pour l'analyse
    double GetSymbolSuccessRate(const string symbol);
    int GetSymbolTotalTrades(const string symbol);
    double GetSymbolAvgProfit(const string symbol);
    PricePattern GetBestPricePattern(const string symbol);
    PricePattern GetWorstPricePattern(const string symbol);
};

//+------------------------------------------------------------------+
//| Constructeur                                                     |
//+------------------------------------------------------------------+
CReinforcementLearning::CReinforcementLearning()
{
    m_historyCount = 0;
    m_symbolCount = 0;
    m_learningRate = 0.1;
    m_discountFactor = 0.9;
    m_explorationRate = 0.1;
    m_maxHistorySize = 1000;
    m_dataFile = "SpikeHunter_Learning.dat";
    
    // Initialiser les structures
    ArrayInitialize(m_tradeHistory, 0);
    ArrayInitialize(m_symbolLearning, 0);
    
    // Charger les données existantes
    LoadLearningData();
}

//+------------------------------------------------------------------+
//| Destructeur                                                      |
//+------------------------------------------------------------------+
CReinforcementLearning::~CReinforcementLearning() {
    SaveLearningData();
}

//+------------------------------------------------------------------+
//| Ajouter un trade à l'historique                                 |
//+------------------------------------------------------------------+
void CReinforcementLearning::AddTradeToHistory(TradeHistory trade)
{
    if (m_historyCount >= m_maxHistorySize) {
        CleanOldData();
    }
    
    m_tradeHistory[m_historyCount] = trade;
    m_historyCount++;
    
    // Mettre à jour l'apprentissage
    UpdateSymbolLearning(trade);
    UpdatePricePatterns(trade);
    
    Print("📊 Trade ajouté à l'historique: ", trade.symbol, " - Ticket: ", trade.ticket);
}

//+------------------------------------------------------------------+
//| Mettre à jour la sortie d'un trade                              |
//+------------------------------------------------------------------+
void CReinforcementLearning::UpdateTradeExit(ulong ticket, double exit_price, int exit_reason)
{
    for (int i = 0; i < m_historyCount; i++) {
        if (m_tradeHistory[i].ticket == ticket) {
            m_tradeHistory[i].exit_price = exit_price;
            m_tradeHistory[i].exit_time = TimeCurrent();
            m_tradeHistory[i].exit_reason = exit_reason;
            m_tradeHistory[i].profit = (m_tradeHistory[i].direction == ORDER_TYPE_BUY) ? 
                (exit_price - m_tradeHistory[i].entry_price) * m_tradeHistory[i].lot_size * 100000 :
                (m_tradeHistory[i].entry_price - exit_price) * m_tradeHistory[i].lot_size * 100000;
            m_tradeHistory[i].was_winner = (m_tradeHistory[i].profit > 0);
            m_tradeHistory[i].hold_duration_minutes = (int)((m_tradeHistory[i].exit_time - m_tradeHistory[i].entry_time) / 60);
            
            // Recalculer les statistiques du symbole
            UpdateSymbolLearning(m_tradeHistory[i]);
            
            Print("📊 Trade mis à jour: ", m_tradeHistory[i].symbol, " - Profit: ", DoubleToString(m_tradeHistory[i].profit, 2));
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Obtenir la confiance pour un symbole et un prix                 |
//+------------------------------------------------------------------+
double CReinforcementLearning::GetSymbolConfidence(string symbol, double price)
{
    int symbolIndex = FindSymbolIndex(symbol);
    if (symbolIndex == -1) return 0.5; // Confiance neutre si pas de données
    
    SymbolLearning learning = m_symbolLearning[symbolIndex];
    
    // Calculer la confiance basée sur l'historique
    double baseConfidence = learning.success_rate;
    
    // Ajuster selon la plage de prix
    for (int i = 0; i < learning.pattern_count; i++) {
        if (MathAbs(price - learning.price_patterns[i].price_level) < 10 * _Point) {
            baseConfidence = learning.price_patterns[i].success_rate;
            break;
        }
    }
    
    // Ajuster selon le nombre de trades (plus de données = plus de confiance)
    double dataConfidence = MathMin(1.0, learning.total_trades / 50.0);
    
    return (baseConfidence * 0.7 + dataConfidence * 0.3);
}

//+------------------------------------------------------------------+
//| Obtenir la taille de lot optimale pour un symbole               |
//+------------------------------------------------------------------+
double CReinforcementLearning::GetOptimalLotSize(string symbol)
{
    int symbolIndex = FindSymbolIndex(symbol);
    if (symbolIndex == -1) return 0.01; // Taille par défaut
    
    return m_symbolLearning[symbolIndex].optimal_lot_size;
}

//+------------------------------------------------------------------+
//| Obtenir le multiplicateur ATR optimal pour un symbole           |
//+------------------------------------------------------------------+
double CReinforcementLearning::GetOptimalATRMultiplier(string symbol)
{
    int symbolIndex = FindSymbolIndex(symbol);
    if (symbolIndex == -1) return 2.0; // Multiplicateur par défaut
    
    return m_symbolLearning[symbolIndex].optimal_atr_multiplier;
}

//+------------------------------------------------------------------+
//| Obtenir la meilleure session de trading pour un symbole         |
//+------------------------------------------------------------------+
int CReinforcementLearning::GetBestTradingSession(string symbol)
{
    int symbolIndex = FindSymbolIndex(symbol);
    if (symbolIndex == -1) return 0; // Session par défaut
    
    return m_symbolLearning[symbolIndex].best_session;
}

//+------------------------------------------------------------------+
//| Vérifier si un prix est dans une zone de succès                 |
//+------------------------------------------------------------------+
bool CReinforcementLearning::IsPriceInSuccessZone(string symbol, double price)
{
    int symbolIndex = FindSymbolIndex(symbol);
    if (symbolIndex == -1) return false;
    
    SymbolLearning learning = m_symbolLearning[symbolIndex];
    
    // Vérifier les meilleures plages de prix
    for (int i = 0; i < 10; i++) {
        if (learning.best_price_ranges[i] > 0) {
            double range = learning.best_price_ranges[i];
            if (price >= range * 0.95 && price <= range * 1.05) {
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Obtenir la probabilité de succès pour un symbole, prix et direction |
//+------------------------------------------------------------------+
double CReinforcementLearning::GetSuccessProbability(string symbol, double price, int direction)
{
    int symbolIndex = FindSymbolIndex(symbol);
    if (symbolIndex == -1) return 0.5;
    
    SymbolLearning learning = m_symbolLearning[symbolIndex];
    
    // Chercher le pattern de prix le plus proche
    double bestMatch = 0.5;
    double minDistance = DBL_MAX;
    
    for (int i = 0; i < learning.pattern_count; i++) {
        double distance = MathAbs(price - learning.price_patterns[i].price_level);
        if (distance < minDistance) {
            minDistance = distance;
            bestMatch = learning.price_patterns[i].success_rate;
        }
    }
    
    return bestMatch;
}

//+------------------------------------------------------------------+
//| Analyser les performances                                       |
//+------------------------------------------------------------------+
void CReinforcementLearning::AnalyzePerformance()
{
    Print("📊 === ANALYSE DES PERFORMANCES ===");
    
    for (int i = 0; i < m_symbolCount; i++) {
        SymbolLearning learning = m_symbolLearning[i];
        if (learning.total_trades > 0) {
            Print("📈 ", learning.symbol, ":");
            Print("   Taux de succès: ", DoubleToString(learning.success_rate * 100, 2), "%");
            Print("   Total trades: ", learning.total_trades);
            Print("   Profit moyen: ", DoubleToString(learning.avg_profit_per_trade, 2));
            Print("   Lot optimal: ", DoubleToString(learning.optimal_lot_size, 2));
            Print("   Multiplicateur ATR optimal: ", DoubleToString(learning.optimal_atr_multiplier, 2));
        }
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour l'apprentissage par symbole                       |
//+------------------------------------------------------------------+
void CReinforcementLearning::UpdateSymbolLearning(TradeHistory trade)
{
    int symbolIndex = FindSymbolIndex(trade.symbol);
    
    if (symbolIndex == -1) {
        // Nouveau symbole
        if (m_symbolCount < 50) {
            symbolIndex = m_symbolCount;
            m_symbolLearning[symbolIndex].symbol = trade.symbol;
            m_symbolCount++;
        } else {
            return; // Pas de place pour un nouveau symbole
        }
    }
    
    SymbolLearning learning = m_symbolLearning[symbolIndex];
    
    // Mettre à jour les statistiques
    learning.total_trades++;
    if (trade.was_winner) {
        learning.success_rate = (learning.success_rate * (learning.total_trades - 1) + 1.0) / learning.total_trades;
    } else {
        learning.success_rate = (learning.success_rate * (learning.total_trades - 1) + 0.0) / learning.total_trades;
    }
    
    learning.avg_profit_per_trade = (learning.avg_profit_per_trade * (learning.total_trades - 1) + trade.profit) / learning.total_trades;
    
    // Optimiser la taille de lot
    if (trade.profit > 0) {
        learning.optimal_lot_size = learning.optimal_lot_size * (1 + m_learningRate);
    } else {
        learning.optimal_lot_size = learning.optimal_lot_size * (1 - m_learningRate * 0.5);
    }
    
    // Limiter la taille de lot
    learning.optimal_lot_size = MathMax(0.01, MathMin(10.0, learning.optimal_lot_size));
    
    learning.last_analysis = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Mettre à jour les patterns de prix                              |
//+------------------------------------------------------------------+
void CReinforcementLearning::UpdatePricePatterns(TradeHistory trade)
{
    int symbolIndex = FindSymbolIndex(trade.symbol);
    if (symbolIndex == -1) return;
    
    SymbolLearning learning = m_symbolLearning[symbolIndex];
    
    // Trouver ou créer un pattern pour ce niveau de prix
    int patternIndex = -1;
    for (int i = 0; i < learning.pattern_count; i++) {
        if (MathAbs(trade.entry_price - learning.price_patterns[i].price_level) < 20 * _Point) {
            patternIndex = i;
            break;
        }
    }
    
    if (patternIndex == -1 && learning.pattern_count < 100) {
        // Créer un nouveau pattern
        patternIndex = learning.pattern_count;
        learning.price_patterns[patternIndex].price_level = trade.entry_price;
        learning.price_patterns[patternIndex].total_trades = 0;
        learning.price_patterns[patternIndex].winning_trades = 0;
        learning.pattern_count++;
    }
    
    if (patternIndex != -1) {
        PricePattern pattern = learning.price_patterns[patternIndex];
        pattern.total_trades++;
        if (trade.was_winner) {
            pattern.winning_trades++;
        }
        pattern.success_rate = (double)pattern.winning_trades / pattern.total_trades;
        pattern.avg_profit = (pattern.avg_profit * (pattern.total_trades - 1) + trade.profit) / pattern.total_trades;
        pattern.last_updated = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Calculer la récompense pour un trade                            |
//+------------------------------------------------------------------+
double CReinforcementLearning::CalculateReward(TradeHistory trade)
{
    double reward = 0;
    
    if (trade.was_winner) {
        reward = trade.profit / 100.0; // Normaliser le profit
    } else {
        reward = trade.profit / 100.0; // Normaliser la perte (négative)
    }
    
    // Bonus pour les trades rapides et profitables
    if (trade.was_winner && trade.hold_duration_minutes < 30) {
        reward *= 1.5;
    }
    
    // Malus pour les trades qui ont touché le SL
    if (trade.exit_reason == 1) { // SL
        reward *= 0.5;
    }
    
    return reward;
}

//+------------------------------------------------------------------+
//| Trouver l'index d'un symbole dans l'apprentissage               |
//+------------------------------------------------------------------+
int CReinforcementLearning::FindSymbolIndex(string symbol)
{
    for (int i = 0; i < m_symbolCount; i++) {
        if (m_symbolLearning[i].symbol == symbol) {
            return i;
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Nettoyer les anciennes données                                  |
//+------------------------------------------------------------------+
void CReinforcementLearning::CleanOldData()
{
    // Garder seulement les 500 derniers trades
    int keepCount = 500;
    int removeCount = m_historyCount - keepCount;
    
    for (int i = 0; i < keepCount; i++) {
        m_tradeHistory[i] = m_tradeHistory[i + removeCount];
    }
    
    m_historyCount = keepCount;
    Print("🧹 Nettoyage des données: ", removeCount, " anciens trades supprimés");
}

//+------------------------------------------------------------------+
//| Sauvegarder les données d'apprentissage                         |
//+------------------------------------------------------------------+
void CReinforcementLearning::SaveLearningData()
{
    int fileHandle = FileOpen(m_dataFile, FILE_WRITE | FILE_BIN);
    if (fileHandle == INVALID_HANDLE) {
        Print("❌ Erreur sauvegarde données d'apprentissage: ", GetLastError());
        return;
    }
    
    FileWriteInteger(fileHandle, m_historyCount);
    FileWriteInteger(fileHandle, m_symbolCount);
    
    // Sauvegarder l'historique des trades
    for (int i = 0; i < m_historyCount; i++) {
        FileWriteString(fileHandle, m_tradeHistory[i].symbol);
        FileWriteInteger(fileHandle, m_tradeHistory[i].direction);
        FileWriteDouble(fileHandle, m_tradeHistory[i].entry_price);
        FileWriteDouble(fileHandle, m_tradeHistory[i].exit_price);
        FileWriteDouble(fileHandle, m_tradeHistory[i].lot_size);
        FileWriteDouble(fileHandle, m_tradeHistory[i].profit);
        FileWriteLong(fileHandle, m_tradeHistory[i].entry_time);
        FileWriteLong(fileHandle, m_tradeHistory[i].exit_time);
        FileWriteInteger(fileHandle, m_tradeHistory[i].exit_reason);
        FileWriteDouble(fileHandle, m_tradeHistory[i].atr_at_entry);
        FileWriteDouble(fileHandle, m_tradeHistory[i].spread_at_entry);
        FileWriteDouble(fileHandle, m_tradeHistory[i].confidence_score);
        FileWriteInteger(fileHandle, m_tradeHistory[i].was_winner ? 1 : 0);
        FileWriteDouble(fileHandle, m_tradeHistory[i].max_favorable);
        FileWriteDouble(fileHandle, m_tradeHistory[i].max_adverse);
        FileWriteInteger(fileHandle, m_tradeHistory[i].hold_duration_minutes);
        FileWriteDouble(fileHandle, m_tradeHistory[i].volatility_at_entry);
        FileWriteInteger(fileHandle, m_tradeHistory[i].market_session);
        FileWriteDouble(fileHandle, m_tradeHistory[i].price_range_high);
        FileWriteDouble(fileHandle, m_tradeHistory[i].price_range_low);
        FileWriteDouble(fileHandle, m_tradeHistory[i].price_range_mid);
        FileWriteInteger(fileHandle, m_tradeHistory[i].in_support_zone ? 1 : 0);
        FileWriteInteger(fileHandle, m_tradeHistory[i].in_resistance_zone ? 1 : 0);
        FileWriteLong(fileHandle, m_tradeHistory[i].ticket);
    }
    
    // Sauvegarder l'apprentissage par symbole
    for (int i = 0; i < m_symbolCount; i++) {
        FileWriteString(fileHandle, m_symbolLearning[i].symbol);
        FileWriteDouble(fileHandle, m_symbolLearning[i].success_rate);
        FileWriteInteger(fileHandle, m_symbolLearning[i].total_trades);
        FileWriteDouble(fileHandle, m_symbolLearning[i].avg_profit_per_trade);
        FileWriteDouble(fileHandle, m_symbolLearning[i].optimal_lot_size);
        FileWriteDouble(fileHandle, m_symbolLearning[i].optimal_atr_multiplier);
        FileWriteInteger(fileHandle, m_symbolLearning[i].best_session);
        FileWriteInteger(fileHandle, m_symbolLearning[i].pattern_count);
        
        // Sauvegarder les patterns de prix
        for (int j = 0; j < m_symbolLearning[i].pattern_count; j++) {
            FileWriteDouble(fileHandle, m_symbolLearning[i].price_patterns[j].price_range_low);
            FileWriteDouble(fileHandle, m_symbolLearning[i].price_patterns[j].price_range_high);
            FileWriteDouble(fileHandle, m_symbolLearning[i].price_patterns[j].success_rate);
            FileWriteInteger(fileHandle, m_symbolLearning[i].price_patterns[j].total_trades);
            FileWriteInteger(fileHandle, m_symbolLearning[i].price_patterns[j].winning_trades);
            FileWriteDouble(fileHandle, m_symbolLearning[i].price_patterns[j].avg_profit);
            FileWriteDouble(fileHandle, m_symbolLearning[i].price_patterns[j].avg_loss);
            FileWriteDouble(fileHandle, m_symbolLearning[i].price_patterns[j].profit_factor);
            FileWriteLong(fileHandle, m_symbolLearning[i].price_patterns[j].last_analysis);
        }
    }
    
    FileClose(fileHandle);
    Print("💾 Données d'apprentissage sauvegardées");
}

//+------------------------------------------------------------------+
//| Charger les données d'apprentissage                             |
//+------------------------------------------------------------------+
void CReinforcementLearning::LoadLearningData()
{
    int fileHandle = FileOpen(m_dataFile, FILE_READ | FILE_BIN);
    if (fileHandle == INVALID_HANDLE) {
        Print("ℹ️ Aucune donnée d'apprentissage existante");
        return;
    }
    
    m_historyCount = FileReadInteger(fileHandle);
    m_symbolCount = FileReadInteger(fileHandle);
    
    // Charger l'historique des trades
    for (int i = 0; i < m_historyCount; i++) {
        m_tradeHistory[i].symbol = FileReadString(fileHandle);
        m_tradeHistory[i].direction = FileReadInteger(fileHandle);
        m_tradeHistory[i].entry_price = FileReadDouble(fileHandle);
        m_tradeHistory[i].exit_price = FileReadDouble(fileHandle);
        m_tradeHistory[i].lot_size = FileReadDouble(fileHandle);
        m_tradeHistory[i].profit = FileReadDouble(fileHandle);
        m_tradeHistory[i].entry_time = (datetime)FileReadLong(fileHandle);
        m_tradeHistory[i].exit_time = (datetime)FileReadLong(fileHandle);
        m_tradeHistory[i].exit_reason = FileReadInteger(fileHandle);
        m_tradeHistory[i].atr_at_entry = FileReadDouble(fileHandle);
        m_tradeHistory[i].spread_at_entry = FileReadDouble(fileHandle);
        m_tradeHistory[i].confidence_score = FileReadDouble(fileHandle);
        m_tradeHistory[i].was_winner = (FileReadInteger(fileHandle) == 1);
        m_tradeHistory[i].max_favorable = FileReadDouble(fileHandle);
        m_tradeHistory[i].max_adverse = FileReadDouble(fileHandle);
        m_tradeHistory[i].hold_duration_minutes = FileReadInteger(fileHandle);
        m_tradeHistory[i].volatility_at_entry = FileReadDouble(fileHandle);
        m_tradeHistory[i].market_session = FileReadInteger(fileHandle);
        m_tradeHistory[i].price_range_high = FileReadDouble(fileHandle);
        m_tradeHistory[i].price_range_low = FileReadDouble(fileHandle);
        m_tradeHistory[i].price_range_mid = FileReadDouble(fileHandle);
        m_tradeHistory[i].in_support_zone = (FileReadInteger(fileHandle) == 1);
        m_tradeHistory[i].in_resistance_zone = (FileReadInteger(fileHandle) == 1);
        m_tradeHistory[i].ticket = FileReadLong(fileHandle);
    }
    
    // Charger l'apprentissage par symbole
    for (int i = 0; i < m_symbolCount; i++) {
        m_symbolLearning[i].symbol = FileReadString(fileHandle);
        m_symbolLearning[i].success_rate = FileReadDouble(fileHandle);
        m_symbolLearning[i].total_trades = FileReadInteger(fileHandle);
        m_symbolLearning[i].avg_profit_per_trade = FileReadDouble(fileHandle);
        m_symbolLearning[i].optimal_lot_size = FileReadDouble(fileHandle);
        m_symbolLearning[i].optimal_atr_multiplier = FileReadDouble(fileHandle);
        m_symbolLearning[i].best_session = FileReadInteger(fileHandle);
        m_symbolLearning[i].pattern_count = FileReadInteger(fileHandle);
        
        // Charger les patterns de prix
        for (int j = 0; j < m_symbolLearning[i].pattern_count; j++) {
            m_symbolLearning[i].price_patterns[j].price_range_low = FileReadDouble(fileHandle);
            m_symbolLearning[i].price_patterns[j].price_range_high = FileReadDouble(fileHandle);
            m_symbolLearning[i].price_patterns[j].success_rate = FileReadDouble(fileHandle);
            m_symbolLearning[i].price_patterns[j].total_trades = FileReadInteger(fileHandle);
            m_symbolLearning[i].price_patterns[j].winning_trades = FileReadInteger(fileHandle);
            m_symbolLearning[i].price_patterns[j].avg_profit = FileReadDouble(fileHandle);
            m_symbolLearning[i].price_patterns[j].avg_loss = FileReadDouble(fileHandle);
            m_symbolLearning[i].price_patterns[j].profit_factor = FileReadDouble(fileHandle);
            m_symbolLearning[i].price_patterns[j].last_analysis = (datetime)FileReadLong(fileHandle);
        }
    }
    
    FileClose(fileHandle);
    Print("📂 Données d'apprentissage chargées: ", m_historyCount, " trades, ", m_symbolCount, " symboles");
}

//+------------------------------------------------------------------+
//| Afficher les statistiques d'apprentissage                       |
//+------------------------------------------------------------------+
void CReinforcementLearning::PrintLearningStats()
{
    Print("🧠 === STATISTIQUES D'APPRENTISSAGE ===");
    Print("Total trades dans l'historique: ", m_historyCount);
    Print("Symboles appris: ", m_symbolCount);
    
    for (int i = 0; i < m_symbolCount; i++) {
        SymbolLearning learning = m_symbolLearning[i];
        if (learning.total_trades > 0) {
            Print("📊 ", learning.symbol, ":");
            Print("   Trades: ", learning.total_trades);
            Print("   Succès: ", DoubleToString(learning.success_rate * 100, 1), "%");
            Print("   Profit moyen: ", DoubleToString(learning.avg_profit_per_trade, 2));
            Print("   Patterns: ", learning.pattern_count);
        }
    }
}

//+------------------------------------------------------------------+
//| Réinitialiser l'apprentissage                                   |
//+------------------------------------------------------------------+
void CReinforcementLearning::ResetLearning()
{
    m_historyCount = 0;
    m_symbolCount = 0;
    ArrayInitialize(m_tradeHistory, 0);
    ArrayInitialize(m_symbolLearning, 0);
    Print("🔄 Apprentissage réinitialisé");
}

//+------------------------------------------------------------------+
//| Exporter les données d'apprentissage                            |
//+------------------------------------------------------------------+
void CReinforcementLearning::ExportLearningData(string filename)
{
    int fileHandle = FileOpen(filename, FILE_WRITE | FILE_CSV);
    if (fileHandle == INVALID_HANDLE) {
        Print("❌ Erreur export données: ", GetLastError());
        return;
    }
    
    // En-têtes CSV
    FileWriteString(fileHandle, "Symbol,Entry_Price,Exit_Price,Direction,Profit,Success_Rate,Entry_Time,Exit_Time\n");
    
    // Données des trades
    for (int i = 0; i < m_historyCount; i++) {
        TradeHistory trade = m_tradeHistory[i];
        string line = StringFormat("%s,%.5f,%.5f,%d,%.2f,%.2f,%s,%s\n",
            trade.symbol,
            trade.entry_price,
            trade.exit_price,
            trade.direction,
            trade.profit,
            trade.was_winner ? 1.0 : 0.0,
            TimeToString(trade.entry_time),
            TimeToString(trade.exit_time)
        );
        FileWriteString(fileHandle, line);
    }
    
    FileClose(fileHandle);
    Print("📤 Données exportées vers: ", filename);
}

//+------------------------------------------------------------------+
//| Importer les données d'apprentissage                            |
//+------------------------------------------------------------------+
void CReinforcementLearning::ImportLearningData(string filename)
{
    int fileHandle = FileOpen(filename, FILE_READ | FILE_CSV);
    if (fileHandle == INVALID_HANDLE) {
        Print("❌ Erreur import données: ", GetLastError());
        return;
    }
    
    // Lire l'en-tête
    FileReadString(fileHandle);
    
    // Lire les données
    while (!FileIsEnding(fileHandle)) {
        string line = FileReadString(fileHandle);
        if (StringLen(line) > 0) {
            // Parser la ligne CSV (simplifié)
            // Dans une implémentation complète, il faudrait parser correctement le CSV
        }
    }
    
    FileClose(fileHandle);
    Print("📥 Données importées depuis: ", filename);
}

//+------------------------------------------------------------------+
//| Getters pour l'analyse                                          |
//+------------------------------------------------------------------+
double CReinforcementLearning::GetSymbolSuccessRate(string symbol)
{
    int symbolIndex = FindSymbolIndex(symbol);
    if (symbolIndex == -1) return 0.5;
    return m_symbolLearning[symbolIndex].success_rate;
}

int CReinforcementLearning::GetSymbolTotalTrades(string symbol)
{
    int symbolIndex = FindSymbolIndex(symbol);
    if (symbolIndex == -1) return 0;
    return m_symbolLearning[symbolIndex].total_trades;
}

double CReinforcementLearning::GetSymbolAvgProfit(string symbol)
{
    int symbolIndex = FindSymbolIndex(symbol);
    if (symbolIndex == -1) return 0.0;
    return m_symbolLearning[symbolIndex].avg_profit_per_trade;
}

PricePattern CReinforcementLearning::GetBestPricePattern(string symbol)
{
    int symbolIndex = FindSymbolIndex(symbol);
    PricePattern emptyPattern = {0};
    if (symbolIndex == -1) return emptyPattern;
    
    SymbolLearning learning = m_symbolLearning[symbolIndex];
    PricePattern bestPattern = emptyPattern;
    double bestSuccessRate = 0;
    
    for (int i = 0; i < learning.pattern_count; i++) {
        if (learning.price_patterns[i].success_rate > bestSuccessRate && learning.price_patterns[i].total_trades >= 5) {
            bestSuccessRate = learning.price_patterns[i].success_rate;
            bestPattern = learning.price_patterns[i];
        }
    }
    
    return bestPattern;
}

PricePattern CReinforcementLearning::GetWorstPricePattern(string symbol)
{
    int symbolIndex = FindSymbolIndex(symbol);
    PricePattern emptyPattern = {0};
    if (symbolIndex == -1) return emptyPattern;
    
    SymbolLearning learning = m_symbolLearning[symbolIndex];
    PricePattern worstPattern = emptyPattern;
    double worstSuccessRate = 1.0;
    
    for (int i = 0; i < learning.pattern_count; i++) {
        if (learning.price_patterns[i].success_rate < worstSuccessRate && learning.price_patterns[i].total_trades >= 5) {
            worstSuccessRate = learning.price_patterns[i].success_rate;
            worstPattern = learning.price_patterns[i];
        }
    }
    
    return worstPattern;
}

#endif // REINFORCEMENTLEARNING_MQH
