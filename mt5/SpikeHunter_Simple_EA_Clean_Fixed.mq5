//+------------------------------------------------------------------+
//| Properties & Includes                                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Professional Trading EA"
#property link      "https://www.mql5.com"
#property version   "3.00"
#property description "Spike Hunter - Trading professionnel et securise"

//--- Includes
#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>

//--- Variables globales pour la gestion des cooldowns
static int g_consecutiveLosses = 0;
static int g_consecutiveWins = 0;
static datetime g_cooldownEndTime = 0;
static bool g_inCooldown = false;

//--- Variables globales pour le trading automatique
static datetime g_lastSignalTime = 0;
static int g_pendingOrdersCount = 0;
static double g_lastSignalPrice = 0;
static int g_lastSignalDirection = 0;
static bool g_autoTradingEnabled = true;
static datetime g_lastOrderTime = 0;

//--- Variables globales pour la gestion des risques
static datetime g_globalCooldownUntil = 0;
static bool g_isEarlySignal = false;

//--- Input parameters optimisés pour trading automatique gagnant
input group "=== CONFIGURATION GÉNÉRALE ==="
input bool     InpEnableTrading        = true;     // Activer le trading
input int      InpMagicNumber          = 123456;   // Magic number
input double   InpLotSize              = 0.1;      // Taille du lot par défaut (réduit pour sécurité)
input int      InpStopLoss             = 10;       // Stop Loss (points) - plus serré
input int      InpTakeProfit           = 20;       // Take Profit (points) - ratio 1:2

input group "=== GESTION DES RISQUES ==="
input double   InpMaxRiskPercent       = 0.5;      // Risque maximum par trade (%) - réduit pour sécurité
input double   InpMaxDailyLoss         = 5.0;      // Perte max journalière ($) - réduit
input int      InpMaxTrades            = 3;        // Nombre max de trades - augmenté
input int      InpCooldownMinutes      = 1;        // Cooldown entre trades (min) - réduit
input bool     InpStrictSinglePosition = false;    // Une seule position à la fois
input bool     InpEnableSpikeReentry   = true;     // Ré-entrée après spike
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_M15; // Timeframe pour tendance - plus réactif
input int      InpMaxGlobalSimultaneousTrades = 3; // Nombre max de trades simultanés global - augmenté

input group "=== TRADING INTELLIGENT (FAIBLE PERTE, MAX GAIN) ==="
input bool     InpUseSmartTrading       = true;     // Activer le trading intelligent
input double   InpMaxRiskPerTrade       = 0.3;      // Risque max par trade (0.3% du capital) - réduit
input double   InpMinRiskRewardRatio   = 2.5;      // Ratio risque/récompense minimum (1:2.5) - amélioré
input double   InpMinConfidenceThreshold = 85.0;    // Seuil de confiance minimum (85%) - plus accessible
input bool     InpSpikeOnlyMode         = true;     // N'entrer que si probabilité de spike élevée
input bool     InpValidateTradeWin      = true;     // Valider que le trade est gagnant en 1 min
input bool     InpVerifySpikeBeforeSignal = true;   // Vérifier le spike avant d'annoncer
input bool     InpEnableEarlyDetection  = true;     // Activer la détection précoce
input int      InpLookbackPeriod        = 15;       // Période de lookback pour détection - réduit
input double   InpConsolidationThreshold = 0.6;     // Seuil de consolidation (0.6 = 60%) - plus strict
input double   InpWickRatioThreshold    = 1.8;      // Seuil de ratio de mèche (1.8 = 180%) - plus strict
input bool     InpUseMultiTimeframe     = true;     // Utiliser la validation multi-timeframe - activé
input bool     InpUseSupportResistance  = true;     // Utiliser la validation support/résistance - activé
input int      InpMinConfidence         = 75;       // Confiance minimum pour validation - augmenté
input double   InpVolatilityThreshold   = 1.2;      // Seuil d'augmentation de volatilité (1.2 = 120%) - plus strict
input double   InpSRProximityPercent    = 0.3;      // Proximité S/R en pourcentage (0.3%) - plus strict
input bool     InpUseDynamicTP          = true;     // Take Profit dynamique basé sur volatilité
input bool     InpUseAdaptiveSL         = true;     // Stop Loss adaptatif
input bool     InpUsePartialClose       = true;     // Fermeture partielle des positions
input double   InpPartialClosePercent   = 60.0;     // Pourcentage de fermeture partielle - augmenté
input int      InpPartialCloseAtProfit  = 8;       // Fermeture partielle à X points de profit - augmenté
input bool     InpUseTrailingStopSmart  = true;    // Trailing stop intelligent
input int      InpTrailingStartPoints   = 6;       // Démarrage trailing stop (points) - augmenté
input int      InpTrailingStepPoints    = 3;       // Pas du trailing stop (points) - augmenté

input group "=== OBJECTIFS MONÉTAIRES PAR TRADE ==="
input bool     InpEnforceDollarTargets = true;     // Forcer objectifs $ par trade
input double   InpMaxLossUSDPerTrade   = 2.0;      // Perte max $ par trade - augmenté
input double   InpTargetProfitUSD      = 5.0;      // Gain cible $ par trade - ratio 1:2.5

input group "=== OBJECTIF GLOBAL OUVERT ==="
input double   InpMaxGlobalOpenLossUSD = 6.0;      // Perte totale ouverte max ($) pour forcer clôture - augmenté
input int      InpGlobalCooldownMin    = 3;        // Cooldown global après perte (minutes) - réduit

input group "=== TENDANCE & RÉENTRÉE ==="
input int      InpEMAFast              = 15;        // EMA rapide - plus réactif
input int      InpEMASlow              = 35;        // EMA lente - plus réactif
input bool     InpEnforceM1Trend       = true;      // Interdire les entrées contre-tendance M1
input bool     InpRequireTrendAlign    = true;      // N'entrer que si aligné avec la tendance
input int      InpMinEdgeConfidence    = 80;        // Score minimum pour engager un trade (0-100) - augmenté
input int      InpMaxSpreadPoints      = 25;        // Spread max autorisé (points) - réduit
input int      InpReentryMinBars       = 1;         // Attendre au moins N petites bougies - réduit
input int      InpReentryMaxBars       = 3;         // Au plus N petites bougies - réduit
input double   InpSmallCandlePct       = 0.50;      // Bougie petite si range < 50% de la moyenne - plus strict
input double   InpPerTradeLossCloseUSD = 2.0;       // Fermer une position si perte ≥ $2.0 - augmenté
input int      InpReentryCooldownMin   = 2;         // Attendre N minutes avant reprise après perte - réduit
input int      InpConsecutiveLossCooldownMin = 2;   // Cooldown après 2 pertes consécutives (minutes) - réduit
input int      InpMaxConsecutiveLosses = 2;        // Nombre max de pertes consécutives avant cooldown - réduit
input double   InpPerTradeProfitCloseUSD = 3.0;     // Fermer une position si gain ≥ $3 - augmenté

input group "=== SYSTÈME SPIKE ULTRA-PRÉCIS ==="
input bool     InpUltraPreciseMode     = true;     // Mode ultra-précis : entrée SEULEMENT sur spike confirmé
input double   InpSpikeConfirmationThreshold = 0.15; // Seuil de confirmation spike (%) - Plus accessible
input double   InpMinSpikeStrength     = 1.8;      // Force minimum du spike (vs ATR) - Plus accessible
input bool     InpImmediateCloseAfterSpike = true; // Fermeture immédiate après capture
input double   InpQuickGainThreshold   = 1.0;      // Seuil de gain rapide pour fermeture ($) - augmenté
input double   InpUltraHighConfidence  = 90.0;     // Confiance minimum ultra-élevée (%) - Plus accessible
input double   InpStableConfidenceMin  = 85.0;     // Confiance minimum stable pour trading (%) - Plus accessible
input double   InpConfidenceStabilityMax = 3.0;    // Écart-type maximum pour stabilité (%) - Plus accessible
input bool     InpSingleTradeOnly      = false;    // Un seul trade à la fois
input int      InpMaxSimultaneousTrades = 3;       // Nombre maximum de trades simultanés - augmenté
input int      InpMinTradeIntervalSeconds = 60;   // Intervalle minimum entre trades (sec) - réduit
input double   InpMaxLossPerTradeUSD   = 2.0;      // Perte maximale par trade ($) - 2$ max
input int      InpCooldownAfterLosses  = 2;        // Nombre de pertes consécutives avant cooldown - réduit
input int      InpCooldownAfterWins    = 5;        // Nombre de gains consécutifs avant cooldown - réduit
input int      InpCooldownLossMinutes  = 3;        // Cooldown après pertes (minutes) - réduit
input int      InpCooldownWinMinutes   = 1;        // Cooldown après gains (minutes) - réduit
input double   InpMaxCapitalEngagedUSD = 30.0;     // Capital engagé maximum par jour ($) - augmenté

input group "=== TRADING AUTOMATIQUE ==="
input bool     InpEnableAutoTrading      = true;      // Activer le trading automatique
input bool     InpUseDirectOrders        = true;      // Utiliser ordres directs (market)
input bool     InpUseLimitOrders         = true;      // Utiliser ordres limit
input double   InpLimitOrderDistance     = 0.0003;   // Distance ordres limit (en prix) - réduit
input int      InpMaxPendingOrders       = 5;        // Nombre max d'ordres en attente - augmenté
input int      InpOrderExpirationMin     = 15;       // Expiration ordres limit (minutes) - réduit
input bool     InpUseTrailingStop        = true;      // Utiliser trailing stop
input double   InpTrailingStopDistance   = 0.0002;   // Distance trailing stop - réduit
input double   InpTrailingStep           = 0.0001;   // Pas du trailing stop
input bool     InpUseBreakEven           = true;      // Passer en break-even
input double   InpBreakEvenTrigger       = 0.0001;   // Déclencheur break-even (en prix) - réduit
input int      InpMaxTradesPerHour       = 8;         // Nombre max de trades par heure - augmenté
input bool     InpUseSmartSizing         = true;      // Utiliser sizing intelligent
input double   InpRiskPerTrade           = 0.015;    // Risque par trade (% du capital) - réduit
input bool     InpUseTimeFilter          = false;     // Utiliser filtre temporel (désactivé pour trading 24h/24)
input int      InpStartHour              = 0;         // Heure de début trading - 24h/24
input int      InpEndHour                = 23;        // Heure de fin trading - 24h/24

//--- Classes et structures
class CRiskManager {
private:
    double m_dailyLoss;
    double m_dailyStartBalance;
    int m_tradesToday;
    datetime m_lastTradeTime;
    
public:
    CRiskManager() {
        m_dailyLoss = 0;
        m_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_tradesToday = 0;
        m_lastTradeTime = 0;
    }
    
    bool CanOpenTrade() {
        // VÉRIFICATION ABSOLUE: Maximum 3 positions simultanées
        int currentPositions = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                currentPositions++;
            }
        }
        
        if(currentPositions >= InpMaxGlobalSimultaneousTrades) {
            Print("🚫 CANOPEN TRADE BLOQUÉ - ", currentPositions, " positions ouvertes (MAXIMUM: ", InpMaxGlobalSimultaneousTrades, ")");
            return false;
        }
        
        // Vérifier la perte journalière
        if(m_dailyLoss >= InpMaxDailyLoss) {
            Print("❌ Arrêt journalier atteint: $", DoubleToString(m_dailyLoss, 2));
            return false;
        }
        
        // Vérifier le nombre de trades
        if(m_tradesToday >= InpMaxTrades) {
            Print("❌ Limite de trades atteinte: ", m_tradesToday);
            return false;
        }
        
        return true;
    }
    
    void UpdateTradeStats(double profit) {
        m_tradesToday++;
        m_lastTradeTime = TimeCurrent();
        m_dailyLoss += (profit < 0) ? MathAbs(profit) : 0;
    }
};

//--- Instance globale du Risk Manager
CRiskManager g_riskManager;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 SpikeHunter EA Initialisé - Version 3.00");
    Print("📊 Configuration: Trading automatique activé");
    Print("💰 Lot Size: ", InpLotSize);
    Print("🛡️ Risque max par trade: ", InpMaxRiskPercent, "%");
    Print("📈 Trades max simultanés: ", InpMaxGlobalSimultaneousTrades);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🛑 SpikeHunter EA Arrêté - Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    if(!InpEnableTrading) return;
    
    // Vérifier si on peut trader
    if(!g_riskManager.CanOpenTrade()) return;
    
    // Vérifier les signaux de spike
    CheckSpikeSignals();
    
    // Gérer les positions ouvertes
    ManageOpenPositions();
}

//+------------------------------------------------------------------+
//| Vérifier les signaux de spike                                   |
//+------------------------------------------------------------------+
void CheckSpikeSignals()
{
    // Détecter les signaux de spike avec validation stricte
    int signal = DetectSpikeSignal();
    
    if(signal != 0) {
        Print("🎯 Signal de spike détecté: ", (signal > 0) ? "BUY" : "SELL");
        
        // Exécuter le trade si les conditions sont remplies
        if(ValidateSignal(signal)) {
            ExecuteTrade(signal);
        }
    }
}

//+------------------------------------------------------------------+
//| Détecter un signal de spike                                     |
//+------------------------------------------------------------------+
int DetectSpikeSignal()
{
    // Logique de détection de spike simplifiée
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, rates) < 3) return 0;
    
    // Détecter un spike basé sur la volatilité
    double currentRange = rates[0].high - rates[0].low;
    double avgRange = 0;
    
    for(int i = 1; i < 3; i++) {
        avgRange += (rates[i].high - rates[i].low);
    }
    avgRange /= 2.0;
    
    // Spike détecté si le range actuel est 1.8x supérieur à la moyenne
    if(currentRange > (avgRange * InpMinSpikeStrength)) {
        // Déterminer la direction basée sur la tendance
        if(rates[0].close > rates[0].open) {
            return 1; // BUY
        } else {
            return -1; // SELL
        }
    }
    
    return 0; // Pas de signal
}

//+------------------------------------------------------------------+
//| Valider un signal                                               |
//+------------------------------------------------------------------+
bool ValidateSignal(int signal)
{
    // Validation basique du signal
    if(signal == 0) return false;
    
    // Vérifier la tendance
    if(InpRequireTrendAlign) {
        int trend = GetTrendDirection();
        if((signal > 0 && trend <= 0) || (signal < 0 && trend >= 0)) {
            return false;
        }
    }
    
    // Vérifier le spread
    double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(spread > InpMaxSpreadPoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT)) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Obtenir la direction de la tendance                             |
//+------------------------------------------------------------------+
int GetTrendDirection()
{
    double emaFast = iMA(_Symbol, InpTrendTF, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
    double emaSlow = iMA(_Symbol, InpTrendTF, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
    
    if(emaFast > emaSlow) return 1;
    if(emaFast < emaSlow) return -1;
    return 0;
}

//+------------------------------------------------------------------+
//| Exécuter un trade                                               |
//+------------------------------------------------------------------+
void ExecuteTrade(int direction)
{
    CTrade trade;
    trade.SetExpertMagicNumber(InpMagicNumber);
    
    double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl = CalculateStopLoss(price, direction);
    double tp = CalculateTakeProfit(price, direction);
    
    bool result = (direction > 0) ? 
        trade.Buy(InpLotSize, _Symbol, price, sl, tp, "SpikeHunter") :
        trade.Sell(InpLotSize, _Symbol, price, sl, tp, "SpikeHunter");
    
    if(result) {
        Print("✅ Trade exécuté: ", (direction > 0) ? "BUY" : "SELL", " - Prix: ", price);
        g_riskManager.UpdateTradeStats(0); // Sera mis à jour lors de la fermeture
    } else {
        Print("❌ Échec de l'exécution du trade: ", trade.ResultRetcode());
    }
}

//+------------------------------------------------------------------+
//| Calculer le Stop Loss                                           |
//+------------------------------------------------------------------+
double CalculateStopLoss(double price, int direction)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double sl = (direction > 0) ? 
        price - InpStopLoss * point : 
        price + InpStopLoss * point;
    return sl;
}

//+------------------------------------------------------------------+
//| Calculer le Take Profit                                         |
//+------------------------------------------------------------------+
double CalculateTakeProfit(double price, int direction)
{
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tp = (direction > 0) ? 
        price + InpTakeProfit * point : 
        price - InpTakeProfit * point;
    return tp;
}

//+------------------------------------------------------------------+
//| Gérer les positions ouvertes                                    |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            double profit = PositionGetDouble(POSITION_PROFIT);
            double profitUSD = profit * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            
            // Fermer si perte atteinte
            if(profitUSD <= -InpMaxLossUSDPerTrade) {
                CTrade trade;
                if(trade.PositionClose(PositionGetTicket(i))) {
                    Print("🛑 Position fermée - Perte atteinte: $", DoubleToString(MathAbs(profitUSD), 2));
                    g_riskManager.UpdateTradeStats(profit);
                }
            }
            // Fermer si gain atteint
            else if(profitUSD >= InpTargetProfitUSD) {
                CTrade trade;
                if(trade.PositionClose(PositionGetTicket(i))) {
                    Print("💰 Position fermée - Gain atteint: $", DoubleToString(profitUSD, 2));
                    g_riskManager.UpdateTradeStats(profit);
                }
            }
        }
    }
}
