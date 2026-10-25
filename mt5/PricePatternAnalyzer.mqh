//+------------------------------------------------------------------+
//| PricePatternAnalyzer.mqh                                        |
//| Analyseur de patterns de prix et zones de support/résistance    |
//| Version: 1.0                                                    |
//+------------------------------------------------------------------+

#ifndef PRICEPATTERNANALYZER_MQH
#define PRICEPATTERNANALYZER_MQH

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
//| Structures pour l'analyse des patterns                          |
//+------------------------------------------------------------------+

// Structure pour une zone de support/résistance
struct SupportResistanceZone {
    double level;                    // Niveau de prix
    double strength;                 // Force de la zone (0-1)
    int touch_count;                // Nombre de touches
    datetime first_touch;           // Première touche
    datetime last_touch;            // Dernière touche
    bool is_support;                // True si support, false si résistance
    double success_rate;            // Taux de succès des trades à ce niveau
    int total_trades;               // Nombre total de trades à ce niveau
    int winning_trades;             // Nombre de trades gagnants
    double avg_profit;              // Profit moyen
    double avg_loss;                // Perte moyenne
    double profit_factor;           // Facteur de profit
    bool is_active;                 // Zone encore active
    datetime created_time;          // Temps de création
    int timeframe;                  // Timeframe de la zone
};

// Structure pour l'analyse des plages de prix
struct PriceRangeAnalysis {
    double high;                    // Plus haut de la plage
    double low;                     // Plus bas de la plage
    double mid;                     // Milieu de la plage
    double range_size;              // Taille de la plage
    double success_rate;            // Taux de succès dans cette plage
    int total_trades;               // Nombre total de trades
    int winning_trades;             // Nombre de trades gagnants
    double avg_profit;              // Profit moyen
    double volatility;              // Volatilité dans cette plage
    int session;                    // Session de marché
    datetime last_analysis;         // Dernière analyse
    bool is_high_probability;       // Zone de haute probabilité
    double confidence;              // Niveau de confiance
};

// Structure pour l'analyse des sessions de marché
struct MarketSessionAnalysis {
    int session;                    // 0=Asian, 1=London, 2=NY, 3=Overlap
    double success_rate;            // Taux de succès
    int total_trades;               // Nombre total de trades
    double avg_profit;              // Profit moyen
    double avg_volatility;          // Volatilité moyenne
    double best_price_range[2];     // Meilleure plage de prix [low, high]
    int best_direction;             // Meilleure direction (BUY/SELL)
    double optimal_lot_size;        // Taille de lot optimale
    datetime last_analysis;         // Dernière analyse
};

//+------------------------------------------------------------------+
//| Classe principale d'analyse des patterns de prix                |
//+------------------------------------------------------------------+
class CPricePatternAnalyzer {
private:
    SupportResistanceZone m_zones[100];     // Zones de support/résistance
    int m_zoneCount;                        // Nombre de zones
    PriceRangeAnalysis m_priceRanges[50];   // Analyses de plages de prix
    int m_rangeCount;                       // Nombre de plages analysées
    MarketSessionAnalysis m_sessions[4];    // Analyses par session
    double m_atrHandle;                     // Handle ATR
    double m_atrBuffer[1000];               // Buffer ATR
    int m_atrPeriod;                        // Période ATR
    datetime m_lastAnalysis;                // Dernière analyse
    int m_analysisInterval;                 // Intervalle d'analyse en minutes
    
    // Méthodes privées
    void DetectSupportResistanceZones(const string symbol, const int timeframe);
    void UpdateZoneStatistics(const string symbol, const double price, const bool is_winner);
    void AnalyzePriceRanges(const string symbol, const MqlRates &rates[]);
    void AnalyzeMarketSessions(const string symbol, const MqlRates &rates[]);
    double CalculateZoneStrength(const SupportResistanceZone &zone);
    bool IsPriceInZone(const double price, const SupportResistanceZone &zone);
    void CleanOldZones();
    int FindZoneIndex(const double price, const double tolerance);
    void UpdateATRBuffer(const string symbol);
    
public:
    // Constructeur
    CPricePatternAnalyzer();
    
    // Destructeur
    ~CPricePatternAnalyzer();
    
    // Méthodes publiques
    void Initialize(const string symbol);
    void UpdateAnalysis(const string symbol, const MqlRates &rates[]);
    void AddTradeResult(const string symbol, const double entry_price, const double exit_price, const bool is_winner);
    
    // Getters pour l'analyse
    SupportResistanceZone GetBestSupportZone(const string symbol, const double current_price);
    SupportResistanceZone GetBestResistanceZone(const string symbol, const double current_price);
    PriceRangeAnalysis GetBestPriceRange(const string symbol);
    MarketSessionAnalysis GetBestTradingSession(const string symbol);
    double GetPriceSuccessProbability(const string symbol, const double price, const int direction);
    bool IsPriceInHighProbabilityZone(const string symbol, const double price);
    double GetOptimalLotSizeForPrice(const string symbol, const double price);
    double GetZoneStrength(const string symbol, const double price);
    
    // Méthodes d'analyse avancée
    void AnalyzeVolatilityPatterns(const string symbol, const MqlRates &rates[]);
    void AnalyzeTrendStrength(const string symbol, const MqlRates &rates[]);
    void AnalyzeMomentumPatterns(const string symbol, const MqlRates &rates[]);
    void AnalyzeVolumePatterns(const string symbol, const MqlRates &rates[]);
    
    // Méthodes de reporting
    void PrintZoneAnalysis(const string symbol);
    void PrintPriceRangeAnalysis(const string symbol);
    void PrintSessionAnalysis(const string symbol);
    void ExportAnalysisData(const string filename);
    
    // Méthodes de nettoyage
    void CleanOldData();
    void ResetAnalysis();
};

//+------------------------------------------------------------------+
//| Constructeur                                                     |
//+------------------------------------------------------------------+
CPricePatternAnalyzer::CPricePatternAnalyzer() {
    m_zoneCount = 0;
    m_rangeCount = 0;
    m_atrHandle = INVALID_HANDLE;
    m_atrPeriod = 14;
    m_lastAnalysis = 0;
    m_analysisInterval = 60; // Analyser toutes les heures
    
    // Initialiser les structures
    ArrayInitialize(m_zones, 0);
    ArrayInitialize(m_priceRanges, 0);
    ArrayInitialize(m_sessions, 0);
    ArrayInitialize(m_atrBuffer, 0);
    
    // Initialiser les sessions
    for (int i = 0; i < 4; i++) {
        m_sessions[i].session = i;
        m_sessions[i].success_rate = 0.5;
        m_sessions[i].total_trades = 0;
        m_sessions[i].avg_profit = 0.0;
        m_sessions[i].avg_volatility = 0.0;
        m_sessions[i].best_direction = 0;
        m_sessions[i].optimal_lot_size = 0.01;
        m_sessions[i].last_analysis = 0;
    }
}

//+------------------------------------------------------------------+
//| Destructeur                                                      |
//+------------------------------------------------------------------+
CPricePatternAnalyzer::~CPricePatternAnalyzer() {
    if (m_atrHandle != INVALID_HANDLE) {
        IndicatorRelease((int)m_atrHandle);
    }
}

//+------------------------------------------------------------------+
//| Initialiser l'analyseur                                         |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::Initialize(string symbol)
{
    // Créer l'indicateur ATR
    m_atrHandle = iATR(symbol, PERIOD_CURRENT, m_atrPeriod);
    if (m_atrHandle == INVALID_HANDLE) {
        Print("❌ Erreur création ATR pour ", symbol);
        return;
    }
    
    // Détecter les zones initiales
    DetectSupportResistanceZones(symbol, PERIOD_CURRENT);
    
    Print("🔍 Analyseur de patterns initialisé pour ", symbol);
}

//+------------------------------------------------------------------+
//| Mettre à jour l'analyse                                          |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::UpdateAnalysis(string symbol, MqlRates &rates[])
{
    if (TimeCurrent() - m_lastAnalysis < m_analysisInterval * 60) {
        return; // Pas encore le temps d'analyser
    }
    
    m_lastAnalysis = TimeCurrent();
    
    // Mettre à jour le buffer ATR
    UpdateATRBuffer(symbol);
    
    // Détecter les nouvelles zones
    DetectSupportResistanceZones(symbol, PERIOD_CURRENT);
    
    // Analyser les plages de prix
    AnalyzePriceRanges(symbol, rates);
    
    // Analyser les sessions de marché
    AnalyzeMarketSessions(symbol, rates);
    
    // Nettoyer les anciennes données
    CleanOldZones();
    
    Print("📊 Analyse des patterns mise à jour pour ", symbol);
}

//+------------------------------------------------------------------+
//| Détecter les zones de support/résistance                        |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::DetectSupportResistanceZones(string symbol, int timeframe)
{
    MqlRates rates[];
    int copied = CopyRates(symbol, (ENUM_TIMEFRAMES)timeframe, 0, 200, rates);
    if (copied < 50) return;
    
    // Chercher les pivots hauts et bas
    for (int i = 2; i < copied - 2; i++) {
        // Pivot haut
        if (rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
            rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high) {
            
            // Vérifier si cette zone existe déjà
            int zoneIndex = FindZoneIndex(rates[i].high, 10 * _Point);
            if (zoneIndex == -1 && m_zoneCount < 100) {
                // Créer une nouvelle zone de résistance
                m_zones[m_zoneCount].level = rates[i].high;
                m_zones[m_zoneCount].strength = 0.5;
                m_zones[m_zoneCount].touch_count = 1;
                m_zones[m_zoneCount].first_touch = rates[i].time;
                m_zones[m_zoneCount].last_touch = rates[i].time;
                m_zones[m_zoneCount].is_support = false;
                m_zones[m_zoneCount].success_rate = 0.5;
                m_zones[m_zoneCount].total_trades = 0;
                m_zones[m_zoneCount].winning_trades = 0;
                m_zones[m_zoneCount].avg_profit = 0.0;
                m_zones[m_zoneCount].avg_loss = 0.0;
                m_zones[m_zoneCount].profit_factor = 1.0;
                m_zones[m_zoneCount].is_active = true;
                m_zones[m_zoneCount].created_time = rates[i].time;
                m_zones[m_zoneCount].timeframe = timeframe;
                m_zoneCount++;
            } else if (zoneIndex != -1) {
                // Mettre à jour la zone existante
                m_zones[zoneIndex].touch_count++;
                m_zones[zoneIndex].last_touch = rates[i].time;
                m_zones[zoneIndex].strength = CalculateZoneStrength(m_zones[zoneIndex]);
            }
        }
        
        // Pivot bas
        if (rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
            rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low) {
            
            // Vérifier si cette zone existe déjà
            int zoneIndex = FindZoneIndex(rates[i].low, 10 * _Point);
            if (zoneIndex == -1 && m_zoneCount < 100) {
                // Créer une nouvelle zone de support
                m_zones[m_zoneCount].level = rates[i].low;
                m_zones[m_zoneCount].strength = 0.5;
                m_zones[m_zoneCount].touch_count = 1;
                m_zones[m_zoneCount].first_touch = rates[i].time;
                m_zones[m_zoneCount].last_touch = rates[i].time;
                m_zones[m_zoneCount].is_support = true;
                m_zones[m_zoneCount].success_rate = 0.5;
                m_zones[m_zoneCount].total_trades = 0;
                m_zones[m_zoneCount].winning_trades = 0;
                m_zones[m_zoneCount].avg_profit = 0.0;
                m_zones[m_zoneCount].avg_loss = 0.0;
                m_zones[m_zoneCount].profit_factor = 1.0;
                m_zones[m_zoneCount].is_active = true;
                m_zones[m_zoneCount].created_time = rates[i].time;
                m_zones[m_zoneCount].timeframe = timeframe;
                m_zoneCount++;
            } else if (zoneIndex != -1) {
                // Mettre à jour la zone existante
                m_zones[zoneIndex].touch_count++;
                m_zones[zoneIndex].last_touch = rates[i].time;
                m_zones[zoneIndex].strength = CalculateZoneStrength(m_zones[zoneIndex]);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour les statistiques des zones                        |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::UpdateZoneStatistics(string symbol, double price, bool is_winner)
{
    for (int i = 0; i < m_zoneCount; i++) {
        if (IsPriceInZone(price, m_zones[i])) {
            m_zones[i].total_trades++;
            if (is_winner) {
                m_zones[i].winning_trades++;
            }
            m_zones[i].success_rate = (double)m_zones[i].winning_trades / m_zones[i].total_trades;
        }
    }
}

//+------------------------------------------------------------------+
//| Analyser les plages de prix                                     |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::AnalyzePriceRanges(string symbol, MqlRates &rates[])
{
    if (ArraySize(rates) < 50) return;
    
    // Calculer les plages de prix sur différentes périodes
    double high_20 = 0, low_20 = DBL_MAX;
    double high_50 = 0, low_50 = DBL_MAX;
    double high_100 = 0, low_100 = DBL_MAX;
    
    // Plage 20 périodes
    for (int i = 0; i < MathMin(20, ArraySize(rates)); i++) {
        if (rates[i].high > high_20) high_20 = rates[i].high;
        if (rates[i].low < low_20) low_20 = rates[i].low;
    }
    
    // Plage 50 périodes
    for (int i = 0; i < MathMin(50, ArraySize(rates)); i++) {
        if (rates[i].high > high_50) high_50 = rates[i].high;
        if (rates[i].low < low_50) low_50 = rates[i].low;
    }
    
    // Plage 100 périodes
    for (int i = 0; i < MathMin(100, ArraySize(rates)); i++) {
        if (rates[i].high > high_100) high_100 = rates[i].high;
        if (rates[i].low < low_100) low_100 = rates[i].low;
    }
    
    // Créer ou mettre à jour les analyses de plages
    double ranges[3][2] = {{low_20, high_20}, {low_50, high_50}, {low_100, high_100}};
    
    for (int i = 0; i < 3; i++) {
        bool found = false;
        for (int j = 0; j < m_rangeCount; j++) {
            if (MathAbs(m_priceRanges[j].high - ranges[i][1]) < 20 * _Point &&
                MathAbs(m_priceRanges[j].low - ranges[i][0]) < 20 * _Point) {
                found = true;
                break;
            }
        }
        
        if (!found && m_rangeCount < 50) {
            m_priceRanges[m_rangeCount].high = ranges[i][1];
            m_priceRanges[m_rangeCount].low = ranges[i][0];
            m_priceRanges[m_rangeCount].mid = (ranges[i][1] + ranges[i][0]) / 2;
            m_priceRanges[m_rangeCount].range_size = ranges[i][1] - ranges[i][0];
            m_priceRanges[m_rangeCount].success_rate = 0.5;
            m_priceRanges[m_rangeCount].total_trades = 0;
            m_priceRanges[m_rangeCount].winning_trades = 0;
            m_priceRanges[m_rangeCount].avg_profit = 0.0;
            m_priceRanges[m_rangeCount].volatility = 0.0;
            m_priceRanges[m_rangeCount].session = 0;
            m_priceRanges[m_rangeCount].last_analysis = TimeCurrent();
            m_priceRanges[m_rangeCount].is_high_probability = false;
            m_priceRanges[m_rangeCount].confidence = 0.5;
            m_rangeCount++;
        }
    }
}

//+------------------------------------------------------------------+
//| Analyser les sessions de marché                                 |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::AnalyzeMarketSessions(string symbol, MqlRates &rates[])
{
    if (ArraySize(rates) < 10) return;
    
    MqlDateTime time;
    TimeToStruct(rates[0].time, time);
    int currentHour = time.hour;
    
    // Déterminer la session actuelle
    int session = 0; // Asian par défaut
    if (currentHour >= 8 && currentHour < 16) session = 1; // London
    else if (currentHour >= 13 && currentHour < 21) session = 2; // NY
    else if (currentHour >= 8 && currentHour < 16) session = 3; // Overlap
    
    // Mettre à jour les statistiques de session
    m_sessions[session].total_trades++;
    m_sessions[session].last_analysis = TimeCurrent();
    
    // Calculer la volatilité moyenne
    double volatility = 0;
    for (int i = 0; i < MathMin(10, ArraySize(rates)); i++) {
        volatility += (rates[i].high - rates[i].low) / rates[i].close;
    }
    volatility /= MathMin(10, ArraySize(rates));
    
    m_sessions[session].avg_volatility = (m_sessions[session].avg_volatility * (m_sessions[session].total_trades - 1) + volatility) / m_sessions[session].total_trades;
}

//+------------------------------------------------------------------+
//| Calculer la force d'une zone                                    |
//+------------------------------------------------------------------+
double CPricePatternAnalyzer::CalculateZoneStrength(SupportResistanceZone zone)
{
    double strength = 0;
    
    // Facteur de touches
    strength += MathMin(1.0, zone.touch_count / 5.0) * 0.4;
    
    // Facteur de temps (zones plus récentes sont plus fortes)
    double timeFactor = 1.0 - (TimeCurrent() - zone.last_touch) / (24 * 3600 * 7); // 7 jours
    strength += MathMax(0, timeFactor) * 0.3;
    
    // Facteur de succès
    strength += zone.success_rate * 0.3;
    
    return MathMin(1.0, strength);
}

//+------------------------------------------------------------------+
//| Vérifier si un prix est dans une zone                           |
//+------------------------------------------------------------------+
bool CPricePatternAnalyzer::IsPriceInZone(double price, SupportResistanceZone zone)
{
    double tolerance = 10 * _Point;
    return (price >= zone.level - tolerance && price <= zone.level + tolerance);
}

//+------------------------------------------------------------------+
//| Nettoyer les anciennes zones                                    |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::CleanOldZones()
{
    datetime cutoff = TimeCurrent() - (7 * 24 * 3600); // 7 jours
    
    for (int i = m_zoneCount - 1; i >= 0; i--) {
        if (m_zones[i].last_touch < cutoff) {
            // Supprimer la zone
            for (int j = i; j < m_zoneCount - 1; j++) {
                m_zones[j] = m_zones[j + 1];
            }
            m_zoneCount--;
        }
    }
}

//+------------------------------------------------------------------+
//| Trouver l'index d'une zone par prix                             |
//+------------------------------------------------------------------+
int CPricePatternAnalyzer::FindZoneIndex(double price, double tolerance)
{
    for (int i = 0; i < m_zoneCount; i++) {
        if (MathAbs(price - m_zones[i].level) <= tolerance) {
            return i;
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Mettre à jour le buffer ATR                                     |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::UpdateATRBuffer(string symbol)
{
    if (m_atrHandle == INVALID_HANDLE) return;
    
    int copied = CopyBuffer((int)m_atrHandle, 0, 0, 1000, m_atrBuffer);
    if (copied <= 0) {
        Print("❌ Erreur copie buffer ATR");
    }
}

//+------------------------------------------------------------------+
//| Obtenir la meilleure zone de support                            |
//+------------------------------------------------------------------+
SupportResistanceZone CPricePatternAnalyzer::GetBestSupportZone(string symbol, double current_price)
{
    SupportResistanceZone bestZone = {0};
    double bestScore = 0;
    
    for (int i = 0; i < m_zoneCount; i++) {
        if (m_zones[i].is_support && m_zones[i].level < current_price && m_zones[i].is_active) {
            double score = m_zones[i].strength * m_zones[i].success_rate;
            if (score > bestScore) {
                bestScore = score;
                bestZone = m_zones[i];
            }
        }
    }
    
    return bestZone;
}

//+------------------------------------------------------------------+
//| Obtenir la meilleure zone de résistance                         |
//+------------------------------------------------------------------+
SupportResistanceZone CPricePatternAnalyzer::GetBestResistanceZone(string symbol, double current_price)
{
    SupportResistanceZone bestZone = {0};
    double bestScore = 0;
    
    for (int i = 0; i < m_zoneCount; i++) {
        if (!m_zones[i].is_support && m_zones[i].level > current_price && m_zones[i].is_active) {
            double score = m_zones[i].strength * m_zones[i].success_rate;
            if (score > bestScore) {
                bestScore = score;
                bestZone = m_zones[i];
            }
        }
    }
    
    return bestZone;
}

//+------------------------------------------------------------------+
//| Obtenir la meilleure plage de prix                              |
//+------------------------------------------------------------------+
PriceRangeAnalysis CPricePatternAnalyzer::GetBestPriceRange(string symbol)
{
    PriceRangeAnalysis bestRange = {0};
    double bestScore = 0;
    
    for (int i = 0; i < m_rangeCount; i++) {
        if (m_priceRanges[i].total_trades >= 5) {
            double score = m_priceRanges[i].success_rate * m_priceRanges[i].confidence;
            if (score > bestScore) {
                bestScore = score;
                bestRange = m_priceRanges[i];
            }
        }
    }
    
    return bestRange;
}

//+------------------------------------------------------------------+
//| Obtenir la meilleure session de trading                         |
//+------------------------------------------------------------------+
MarketSessionAnalysis CPricePatternAnalyzer::GetBestTradingSession(string symbol)
{
    MarketSessionAnalysis bestSession = m_sessions[0];
    double bestScore = 0;
    
    for (int i = 0; i < 4; i++) {
        if (m_sessions[i].total_trades >= 5) {
            double score = m_sessions[i].success_rate * m_sessions[i].avg_profit;
            if (score > bestScore) {
                bestScore = score;
                bestSession = m_sessions[i];
            }
        }
    }
    
    return bestSession;
}

//+------------------------------------------------------------------+
//| Obtenir la probabilité de succès pour un prix et une direction  |
//+------------------------------------------------------------------+
double CPricePatternAnalyzer::GetPriceSuccessProbability(string symbol, double price, int direction)
{
    double probability = 0.5; // Probabilité de base
    int count = 0;
    
    // Analyser les zones proches
    for (int i = 0; i < m_zoneCount; i++) {
        if (IsPriceInZone(price, m_zones[i]) && m_zones[i].total_trades >= 3) {
            if ((direction == ORDER_TYPE_BUY && m_zones[i].is_support) ||
                (direction == ORDER_TYPE_SELL && !m_zones[i].is_support)) {
                probability = (probability * count + m_zones[i].success_rate) / (count + 1);
                count++;
            }
        }
    }
    
    // Analyser les plages de prix
    for (int i = 0; i < m_rangeCount; i++) {
        if (price >= m_priceRanges[i].low && price <= m_priceRanges[i].high && m_priceRanges[i].total_trades >= 3) {
            probability = (probability * count + m_priceRanges[i].success_rate) / (count + 1);
            count++;
        }
    }
    
    return probability;
}

//+------------------------------------------------------------------+
//| Vérifier si un prix est dans une zone de haute probabilité     |
//+------------------------------------------------------------------+
bool CPricePatternAnalyzer::IsPriceInHighProbabilityZone(string symbol, double price)
{
    // Vérifier les zones de support/résistance
    for (int i = 0; i < m_zoneCount; i++) {
        if (IsPriceInZone(price, m_zones[i]) && m_zones[i].success_rate > 0.7 && m_zones[i].total_trades >= 5) {
            return true;
        }
    }
    
    // Vérifier les plages de prix
    for (int i = 0; i < m_rangeCount; i++) {
        if (price >= m_priceRanges[i].low && price <= m_priceRanges[i].high && 
            m_priceRanges[i].success_rate > 0.7 && m_priceRanges[i].total_trades >= 5) {
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Obtenir la taille de lot optimale pour un prix                  |
//+------------------------------------------------------------------+
double CPricePatternAnalyzer::GetOptimalLotSizeForPrice(string symbol, double price)
{
    double baseLotSize = 0.01;
    
    // Ajuster selon les zones
    for (int i = 0; i < m_zoneCount; i++) {
        if (IsPriceInZone(price, m_zones[i]) && m_zones[i].total_trades >= 5) {
            if (m_zones[i].success_rate > 0.7) {
                baseLotSize *= 1.5; // Augmenter pour les zones de haute probabilité
            } else if (m_zones[i].success_rate < 0.3) {
                baseLotSize *= 0.5; // Réduire pour les zones de faible probabilité
            }
        }
    }
    
    return MathMax(0.01, MathMin(10.0, baseLotSize));
}

//+------------------------------------------------------------------+
//| Obtenir la force d'une zone pour un prix                        |
//+------------------------------------------------------------------+
double CPricePatternAnalyzer::GetZoneStrength(string symbol, double price)
{
    double maxStrength = 0;
    
    for (int i = 0; i < m_zoneCount; i++) {
        if (IsPriceInZone(price, m_zones[i])) {
            maxStrength = MathMax(maxStrength, m_zones[i].strength);
        }
    }
    
    return maxStrength;
}

//+------------------------------------------------------------------+
//| Ajouter un résultat de trade                                    |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::AddTradeResult(string symbol, double entry_price, double exit_price, bool is_winner)
{
    // Mettre à jour les statistiques des zones
    UpdateZoneStatistics(symbol, entry_price, is_winner);
    
    // Mettre à jour les plages de prix
    for (int i = 0; i < m_rangeCount; i++) {
        if (entry_price >= m_priceRanges[i].low && entry_price <= m_priceRanges[i].high) {
            m_priceRanges[i].total_trades++;
            if (is_winner) {
                m_priceRanges[i].winning_trades++;
            }
            m_priceRanges[i].success_rate = (double)m_priceRanges[i].winning_trades / m_priceRanges[i].total_trades;
        }
    }
}

//+------------------------------------------------------------------+
//| Afficher l'analyse des zones                                    |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::PrintZoneAnalysis(string symbol)
{
    Print("🔍 === ANALYSE DES ZONES - ", symbol, " ===");
    Print("Nombre de zones: ", m_zoneCount);
    
    for (int i = 0; i < m_zoneCount; i++) {
        if (m_zones[i].is_active) {
            Print("Zone ", i, ": ", 
                  (m_zones[i].is_support ? "Support" : "Résistance"), " à ", 
                  DoubleToString(m_zones[i].level, _Digits),
                  " - Force: ", DoubleToString(m_zones[i].strength, 2),
                  " - Succès: ", DoubleToString(m_zones[i].success_rate * 100, 1), "%",
                  " - Trades: ", m_zones[i].total_trades);
        }
    }
}

//+------------------------------------------------------------------+
//| Afficher l'analyse des plages de prix                           |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::PrintPriceRangeAnalysis(string symbol)
{
    Print("📊 === ANALYSE DES PLAGES - ", symbol, " ===");
    Print("Nombre de plages: ", m_rangeCount);
    
    for (int i = 0; i < m_rangeCount; i++) {
        if (m_priceRanges[i].total_trades > 0) {
            Print("Plage ", i, ": ", 
                  DoubleToString(m_priceRanges[i].low, _Digits), " - ",
                  DoubleToString(m_priceRanges[i].high, _Digits),
                  " - Succès: ", DoubleToString(m_priceRanges[i].success_rate * 100, 1), "%",
                  " - Trades: ", m_priceRanges[i].total_trades);
        }
    }
}

//+------------------------------------------------------------------+
//| Afficher l'analyse des sessions                                 |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::PrintSessionAnalysis(string symbol)
{
    Print("⏰ === ANALYSE DES SESSIONS - ", symbol, " ===");
    
    string sessionNames[] = {"Asian", "London", "NY", "Overlap"};
    
    for (int i = 0; i < 4; i++) {
        if (m_sessions[i].total_trades > 0) {
            Print("Session ", sessionNames[i], ": ",
                  "Succès: ", DoubleToString(m_sessions[i].success_rate * 100, 1), "%",
                  " - Trades: ", m_sessions[i].total_trades,
                  " - Profit moyen: ", DoubleToString(m_sessions[i].avg_profit, 2));
        }
    }
}

//+------------------------------------------------------------------+
//| Nettoyer les anciennes données                                  |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::CleanOldData()
{
    CleanOldZones();
    
    // Nettoyer les plages de prix anciennes
    datetime cutoff = TimeCurrent() - (30 * 24 * 3600); // 30 jours
    for (int i = m_rangeCount - 1; i >= 0; i--) {
        if (m_priceRanges[i].last_analysis < cutoff) {
            for (int j = i; j < m_rangeCount - 1; j++) {
                m_priceRanges[j] = m_priceRanges[j + 1];
            }
            m_rangeCount--;
        }
    }
}

//+------------------------------------------------------------------+
//| Réinitialiser l'analyse                                         |
//+------------------------------------------------------------------+
void CPricePatternAnalyzer::ResetAnalysis()
{
    m_zoneCount = 0;
    m_rangeCount = 0;
    ArrayInitialize(m_zones, 0);
    ArrayInitialize(m_priceRanges, 0);
    ArrayInitialize(m_sessions, 0);
    Print("🔄 Analyse des patterns réinitialisée");
}

#endif // PRICEPATTERNANALYZER_MQH
