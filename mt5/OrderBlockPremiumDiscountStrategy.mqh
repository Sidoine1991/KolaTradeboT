//+------------------------------------------------------------------+
//| OrderBlockPremiumDiscountStrategy.mqh                            |
//| Stratégie: Entrée sur Order Block, cible Premium/Discount puis  |
//| Old High/Low                                                     |
//| Version: 1.0                                                    |
//+------------------------------------------------------------------+
#ifndef ORDERBLOCKPREMIUMDISCOUNTSTRATEGY_MQH
#define ORDERBLOCKPREMIUMDISCOUNTSTRATEGY_MQH

#property copyright "TradBOT"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| OBZone est défini dans le fichier principal avant cet include    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Structures pour la stratégie                                    |
//+------------------------------------------------------------------+

// Structure pour les zones Premium/Discount
struct PremiumDiscountZone {
    double premiumLevel;      // Niveau Premium (haut de la zone)
    double discountLevel;     // Niveau Discount (bas de la zone)
    double equilibriumLevel; // Niveau d'équilibre (milieu, 50%)
    double rangeHigh;         // Plus haut du range
    double rangeLow;          // Plus bas du range
    datetime lastUpdate;      // Dernière mise à jour
    bool isValid;            // Zone valide
};

// Structure pour les Old High/Low
struct OldHighLow {
    double oldHigh;          // Ancien plus haut
    double oldLow;           // Ancien plus bas
    datetime highTime;       // Temps du plus haut
    datetime lowTime;        // Temps du plus bas
    int lookbackPeriod;      // Période de lookback
    bool isValid;            // Valide
};

// Structure pour le signal de trading de la stratégie
struct OBStrategySignal {
    bool isValid;                    // Signal valide
    int direction;                   // Direction: 1 = BUY, -1 = SELL
    double entryPrice;              // Prix d'entrée (sur l'OB)
    double stopLoss;                 // Stop Loss
    double takeProfit1;              // TP1: Premium ou Discount
    double takeProfit2;              // TP2: Old High ou Low
    OBZone orderBlock;               // Order Block utilisé
    PremiumDiscountZone pdZone;      // Zone Premium/Discount
    OldHighLow oldLevels;            // Old High/Low
    double confidence;               // Confiance du signal (0-1)
    string reason;                   // Raison du signal
    datetime signalTime;             // Temps du signal
};

//+------------------------------------------------------------------+
//| Classe principale de la stratégie                               |
//+------------------------------------------------------------------+
class COrderBlockPremiumDiscountStrategy {
private:
    PremiumDiscountZone m_pdZone;
    OldHighLow m_oldLevels;
    OBStrategySignal m_lastSignal;
    int m_lookbackPeriod;            // Période pour calculer Premium/Discount
    int m_oldHighLowLookback;        // Période pour Old High/Low
    datetime m_lastUpdate;
    int m_updateInterval;            // Intervalle de mise à jour en secondes
    
    // Méthodes privées
    void CalculatePremiumDiscountZone(string symbol, ENUM_TIMEFRAMES tf);
    void CalculateOldHighLow(string symbol, ENUM_TIMEFRAMES tf);
    bool IsPriceInOrderBlock(string symbol, OBZone &ob, double price);
    double GetATRValue(string symbol, ENUM_TIMEFRAMES tf, int period = 14);
    bool ValidateOrderBlockForEntry(OBZone &ob, string symbol);
    
public:
    // Constructeur
    COrderBlockPremiumDiscountStrategy();
    
    // Destructeur
    ~COrderBlockPremiumDiscountStrategy();
    
    // Méthodes publiques
    void Initialize(string symbol, ENUM_TIMEFRAMES tf);
    void Update(string symbol, ENUM_TIMEFRAMES tf);
    OBStrategySignal GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, OBZone &obs[], int obCount);
    bool IsValidSignal(OBStrategySignal &signal);
    
    // Getters
    PremiumDiscountZone GetPremiumDiscountZone();
    OldHighLow GetOldHighLow();
    OBStrategySignal GetLastSignal();
    
    // Setters
    void SetLookbackPeriod(int period);
    void SetOldHighLowLookback(int period);
};

//+------------------------------------------------------------------+
//| Constructeur                                                     |
//+------------------------------------------------------------------+
COrderBlockPremiumDiscountStrategy::COrderBlockPremiumDiscountStrategy() {
    m_lookbackPeriod = 100;          // Par défaut, analyser les 100 dernières bougies
    m_oldHighLowLookback = 200;      // Par défaut, analyser les 200 dernières bougies pour Old High/Low
    m_lastUpdate = 0;
    m_updateInterval = 60;             // Mettre à jour toutes les minutes
    
    // Initialiser les structures
    m_pdZone.premiumLevel = 0;
    m_pdZone.discountLevel = 0;
    m_pdZone.equilibriumLevel = 0;
    m_pdZone.rangeHigh = 0;
    m_pdZone.rangeLow = 0;
    m_pdZone.lastUpdate = 0;
    m_pdZone.isValid = false;
    
    m_oldLevels.oldHigh = 0;
    m_oldLevels.oldLow = DBL_MAX;
    m_oldLevels.highTime = 0;
    m_oldLevels.lowTime = 0;
    m_oldLevels.lookbackPeriod = m_oldHighLowLookback;
    m_oldLevels.isValid = false;
    
    m_lastSignal.isValid = false;
    
    Print("✅ Stratégie Order Block Premium/Discount initialisée");
}

//+------------------------------------------------------------------+
//| Destructeur                                                      |
//+------------------------------------------------------------------+
COrderBlockPremiumDiscountStrategy::~COrderBlockPremiumDiscountStrategy() {
}

//+------------------------------------------------------------------+
//| Initialiser la stratégie                                        |
//+------------------------------------------------------------------+
void COrderBlockPremiumDiscountStrategy::Initialize(string symbol, ENUM_TIMEFRAMES tf) {
    CalculatePremiumDiscountZone(symbol, tf);
    CalculateOldHighLow(symbol, tf);
    Print("🚀 Stratégie initialisée pour ", symbol, " sur ", EnumToString(tf));
}

//+------------------------------------------------------------------+
//| Mettre à jour la stratégie                                      |
//+------------------------------------------------------------------+
void COrderBlockPremiumDiscountStrategy::Update(string symbol, ENUM_TIMEFRAMES tf) {
    if (TimeCurrent() - m_lastUpdate < m_updateInterval) {
        return; // Pas encore le temps de mettre à jour
    }
    
    m_lastUpdate = TimeCurrent();
    CalculatePremiumDiscountZone(symbol, tf);
    CalculateOldHighLow(symbol, tf);
}

//+------------------------------------------------------------------+
//| Calculer les zones Premium/Discount                             |
//+------------------------------------------------------------------+
void COrderBlockPremiumDiscountStrategy::CalculatePremiumDiscountZone(string symbol, ENUM_TIMEFRAMES tf) {
    MqlRates rates[];
    int copied = CopyRates(symbol, tf, 0, m_lookbackPeriod, rates);
    
    if (copied < 50) {
        m_pdZone.isValid = false;
        return;
    }
    
    // Trouver le plus haut et le plus bas sur la période
    double rangeHigh = rates[0].high;
    double rangeLow = rates[0].low;
    
    for (int i = 0; i < copied; i++) {
        if (rates[i].high > rangeHigh) rangeHigh = rates[i].high;
        if (rates[i].low < rangeLow) rangeLow = rates[i].low;
    }
    
    // Calculer les niveaux
    double range = rangeHigh - rangeLow;
    m_pdZone.rangeHigh = rangeHigh;
    m_pdZone.rangeLow = rangeLow;
    m_pdZone.equilibriumLevel = (rangeHigh + rangeLow) / 2.0; // 50% (équilibre)
    
    // Premium = zone supérieure (au-dessus de l'équilibre)
    // Discount = zone inférieure (en-dessous de l'équilibre)
    // On peut définir Premium comme les 30% supérieurs et Discount comme les 30% inférieurs
    double premiumThreshold = rangeHigh - (range * 0.3);  // 70% du range = début Premium
    double discountThreshold = rangeLow + (range * 0.3);  // 30% du range = fin Discount
    
    m_pdZone.premiumLevel = premiumThreshold;
    m_pdZone.discountLevel = discountThreshold;
    m_pdZone.lastUpdate = TimeCurrent();
    m_pdZone.isValid = true;
    
    Print("📊 Premium/Discount calculé: Premium=", DoubleToString(m_pdZone.premiumLevel, _Digits),
          ", Discount=", DoubleToString(m_pdZone.discountLevel, _Digits),
          ", Equilibrium=", DoubleToString(m_pdZone.equilibriumLevel, _Digits));
}

//+------------------------------------------------------------------+
//| Calculer les Old High/Low                                       |
//+------------------------------------------------------------------+
void COrderBlockPremiumDiscountStrategy::CalculateOldHighLow(string symbol, ENUM_TIMEFRAMES tf) {
    MqlRates rates[];
    int copied = CopyRates(symbol, tf, 0, m_oldHighLowLookback, rates);
    
    if (copied < 20) {
        m_oldLevels.isValid = false;
        return;
    }
    
    // Trouver le plus haut et le plus bas sur la période
    double oldHigh = rates[0].high;
    double oldLow = rates[0].low;
    datetime highTime = rates[0].time;
    datetime lowTime = rates[0].time;
    
    for (int i = 0; i < copied; i++) {
        if (rates[i].high > oldHigh) {
            oldHigh = rates[i].high;
            highTime = rates[i].time;
        }
        if (rates[i].low < oldLow) {
            oldLow = rates[i].low;
            lowTime = rates[i].time;
        }
    }
    
    m_oldLevels.oldHigh = oldHigh;
    m_oldLevels.oldLow = oldLow;
    m_oldLevels.highTime = highTime;
    m_oldLevels.lowTime = lowTime;
    m_oldLevels.isValid = true;
    
    Print("📈 Old High/Low calculé: High=", DoubleToString(m_oldLevels.oldHigh, _Digits),
          ", Low=", DoubleToString(m_oldLevels.oldLow, _Digits));
}

//+------------------------------------------------------------------+
//| Générer un signal de trading                                     |
//+------------------------------------------------------------------+
OBStrategySignal COrderBlockPremiumDiscountStrategy::GenerateSignal(string symbol, ENUM_TIMEFRAMES tf, OBZone &obs[], int obCount) {
    OBStrategySignal signal = {0};
    signal.isValid = false;
    signal.signalTime = TimeCurrent();
    
    // Mettre à jour les zones si nécessaire
    Update(symbol, tf);
    
    if (!m_pdZone.isValid || !m_oldLevels.isValid) {
        signal.reason = "Zones Premium/Discount ou Old High/Low non valides";
        return signal;
    }
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double atr = GetATRValue(symbol, tf);
    
    // Chercher un Order Block valide proche du prix actuel
    OBZone bestOB = {0};  // Initialiser la structure
    bool foundOB = false;
    double minDistance = DBL_MAX;
    
    for (int i = 0; i < obCount; i++) {
        if (!ValidateOrderBlockForEntry(obs[i], symbol)) {
            continue;
        }
        
        // Vérifier si le prix est proche de l'OB
        double obMid = (obs[i].high + obs[i].low) / 2.0;
        double distance = MathAbs(currentPrice - obMid);
        
        // Si le prix est dans l'OB ou très proche (dans 0.5 ATR)
        if (IsPriceInOrderBlock(symbol, obs[i], currentPrice) || distance < atr * 0.5) {
            if (distance < minDistance) {
                minDistance = distance;
                bestOB = obs[i];
                foundOB = true;
            }
        }
    }
    
    if (!foundOB) {
        signal.reason = "Aucun Order Block valide trouvé près du prix actuel";
        return signal;
    }
    
    // Déterminer la direction basée sur l'OB
    // OB haussier (bullish) = entrée BUY, OB baissier (bearish) = entrée SELL
    signal.direction = bestOB.bullish ? 1 : -1;
    signal.orderBlock = bestOB;
    
    // Prix d'entrée: milieu de l'OB ou prix actuel si dans l'OB
    if (IsPriceInOrderBlock(symbol, bestOB, currentPrice)) {
        signal.entryPrice = currentPrice;
    } else {
        signal.entryPrice = (bestOB.high + bestOB.low) / 2.0;
    }
    
    // Stop Loss: de l'autre côté de l'OB
    if (signal.direction == 1) { // BUY
        signal.stopLoss = bestOB.low - (atr * 0.2); // Légèrement en-dessous de l'OB
    } else { // SELL
        signal.stopLoss = bestOB.high + (atr * 0.2); // Légèrement au-dessus de l'OB
    }
    
    // TP1: Premium ou Discount selon la direction
    if (signal.direction == 1) { // BUY - cibler Premium d'abord
        signal.takeProfit1 = m_pdZone.premiumLevel;
        // Si Premium est trop proche, utiliser Old High
        if (MathAbs(signal.entryPrice - m_pdZone.premiumLevel) < atr * 0.5) {
            signal.takeProfit1 = m_oldLevels.oldHigh;
        }
    } else { // SELL - cibler Discount d'abord
        signal.takeProfit1 = m_pdZone.discountLevel;
        // Si Discount est trop proche, utiliser Old Low
        if (MathAbs(signal.entryPrice - m_pdZone.discountLevel) < atr * 0.5) {
            signal.takeProfit1 = m_oldLevels.oldLow;
        }
    }
    
    // TP2: Old High ou Low selon la direction
    if (signal.direction == 1) { // BUY
        signal.takeProfit2 = m_oldLevels.oldHigh;
    } else { // SELL
        signal.takeProfit2 = m_oldLevels.oldLow;
    }
    
    // Vérifier que TP2 est plus loin que TP1
    if (signal.direction == 1) {
        if (signal.takeProfit2 <= signal.takeProfit1) {
            signal.takeProfit2 = signal.takeProfit1 + (atr * 1.0); // Ajuster si nécessaire
        }
    } else {
        if (signal.takeProfit2 >= signal.takeProfit1) {
            signal.takeProfit2 = signal.takeProfit1 - (atr * 1.0); // Ajuster si nécessaire
        }
    }
    
    // Calculer la confiance
    double confidence = 0.5; // Base
    
    // Augmenter la confiance si l'OB est validé
    if (bestOB.isValidated) confidence += 0.2;
    
    // Augmenter la confiance selon la force de l'OB
    confidence += (bestOB.strength / 100.0) * 0.2;
    
    // Augmenter la confiance si le prix est dans une zone Premium/Discount
    if (signal.direction == 1 && currentPrice < m_pdZone.equilibriumLevel) {
        confidence += 0.1; // Prix en Discount, bon pour un BUY
    } else if (signal.direction == -1 && currentPrice > m_pdZone.equilibriumLevel) {
        confidence += 0.1; // Prix en Premium, bon pour un SELL
    }
    
    signal.confidence = MathMin(1.0, confidence);
    signal.pdZone = m_pdZone;
    signal.oldLevels = m_oldLevels;
    signal.isValid = true;
    signal.reason = StringFormat("Signal %s sur OB %s, TP1: %s, TP2: %s",
                                 signal.direction == 1 ? "BUY" : "SELL",
                                 bestOB.bullish ? "bullish" : "bearish",
                                 DoubleToString(signal.takeProfit1, _Digits),
                                 DoubleToString(signal.takeProfit2, _Digits));
    
    m_lastSignal = signal;
    return signal;
}

//+------------------------------------------------------------------+
//| Valider un signal                                                |
//+------------------------------------------------------------------+
bool COrderBlockPremiumDiscountStrategy::IsValidSignal(OBStrategySignal &signal) {
    // DÉSACTIVÉ: Vérifications minimales seulement - accepter presque tous les signaux
    if (!signal.isValid) return false;
    if (signal.direction == 0) return false;
    if (signal.entryPrice <= 0) return false;
    
    // DÉSACTIVÉ: Vérifications de SL/TP et confiance désactivées
    // if (signal.stopLoss <= 0) return false;
    // if (signal.takeProfit1 <= 0) return false;
    // if (signal.takeProfit2 <= 0) return false;
    // if (signal.confidence < 0.5) return false;
    
    // DÉSACTIVÉ: Vérifications de ratio risque/récompense désactivées
    // double risk = MathAbs(signal.entryPrice - signal.stopLoss);
    // double reward1 = MathAbs(signal.takeProfit1 - signal.entryPrice);
    // double reward2 = MathAbs(signal.takeProfit2 - signal.entryPrice);
    // if (risk <= 0) return false;
    // if (reward1 / risk < 1.0) return false;
    // if (reward2 / risk < 1.5) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est dans l'Order Block                      |
//+------------------------------------------------------------------+
bool COrderBlockPremiumDiscountStrategy::IsPriceInOrderBlock(string symbol, OBZone &ob, double price) {
    return (price >= ob.low && price <= ob.high);
}

//+------------------------------------------------------------------+
//| Valider un Order Block pour l'entrée                            |
//+------------------------------------------------------------------+
bool COrderBlockPremiumDiscountStrategy::ValidateOrderBlockForEntry(OBZone &ob, string symbol) {
    // DÉSACTIVÉ: Vérifications minimales seulement
    if (ob.high <= ob.low) return false;
    
    // DÉSACTIVÉ: Vérifications de force et âge désactivées
    // if (ob.strength < 30.0) return false;
    // datetime currentTime = TimeCurrent();
    // int ageInSeconds = (int)(currentTime - ob.time1);
    // int maxAge = 50 * PeriodSeconds(ob.tf);
    // if (ageInSeconds > maxAge) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Obtenir la valeur ATR                                            |
//+------------------------------------------------------------------+
double COrderBlockPremiumDiscountStrategy::GetATRValue(string symbol, ENUM_TIMEFRAMES tf, int period = 14) {
    int handle = iATR(symbol, tf, period);
    if (handle == INVALID_HANDLE) return 0;
    
    double atr[];
    ArraySetAsSeries(atr, true);
    if (CopyBuffer(handle, 0, 0, 1, atr) <= 0) {
        IndicatorRelease(handle);
        return 0;
    }
    
    IndicatorRelease(handle);
    return atr[0];
}

//+------------------------------------------------------------------+
//| Getters                                                          |
//+------------------------------------------------------------------+
PremiumDiscountZone COrderBlockPremiumDiscountStrategy::GetPremiumDiscountZone() {
    return m_pdZone;
}

OldHighLow COrderBlockPremiumDiscountStrategy::GetOldHighLow() {
    return m_oldLevels;
}

OBStrategySignal COrderBlockPremiumDiscountStrategy::GetLastSignal() {
    return m_lastSignal;
}

//+------------------------------------------------------------------+
//| Setters                                                          |
//+------------------------------------------------------------------+
void COrderBlockPremiumDiscountStrategy::SetLookbackPeriod(int period) {
    m_lookbackPeriod = period;
}

void COrderBlockPremiumDiscountStrategy::SetOldHighLowLookback(int period) {
    m_oldHighLowLookback = period;
}

#endif // ORDERBLOCKPREMIUMDISCOUNTSTRATEGY_MQH

