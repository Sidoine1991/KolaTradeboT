//| SMC_Universal_Enhanced.mq5                                        |
//| Robot Smart Money Concepts - VERSION AMÉLIORÉE                    |
//| Boom/Crash | Volatility | Forex | Commodities | Metals           |
//| FVG | OB | BOS | LS | OTE | EQH/EQL | P/D | LO/NYO              |
//| AMÉLIORATIONS:                                                     |
//| 1. Refactorisation - Code organisé en sections claires            |
//| 2. Gestion des risques - Système de protection renforcé           |
//| 3. Communication IA-MT5 - Connecteur robuste avec cache          |
//+------------------------------------------------------------------+
#property copyright "TradBOT SMC Enhanced"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| SECTION 1: INCLUDES ET IMPORTS                                     |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
#include <Charts/Chart.mqh>

//+------------------------------------------------------------------+
//| SECTION 2: CONFIGURATION CENTRALISÉE                               |
//+------------------------------------------------------------------+

// === MODE DE RISQUE ===
enum ENUM_RISK_MODE {
    RISK_CONSERVATIVE,  // 1 position max, 2$ perte max
    RISK_MODERATE,      // 2 positions max, 3$ perte max
    RISK_AGGRESSIVE     // 3 positions max, 5$ perte max
};

// === PROFIL D'EXÉCUTION ===
enum ENUM_EXECUTION_PROFILE {
    EXEC_PROFILE_SAFE = 0,
    EXEC_PROFILE_AGGRESSIVE = 1
};

// === CATÉGORIE DE SYMBOLE ===
enum ENUM_SYMBOL_CATEGORY {
    CATEGORY_BOOM_CRASH,
    CATEGORY_VOLATILITY,
    CATEGORY_FOREX,
    CATEGORY_COMMODITIES,
    CATEGORY_INDICES,
    CATEGORY_CRYPTO,
    CATEGORY_OTHER
};

// === CONFIGURATION GLOBALE ===
struct SMC_Config {
    // Gestion des risques
    ENUM_RISK_MODE risk_mode;
    double max_loss_per_trade;
    int max_positions;
    double max_total_loss_dollars;
    double daily_profit_target;
    double max_daily_drawdown_percent;

    // Paramètres SMC
    bool use_fvg;
    bool use_ob;
    bool use_bos;
    bool use_ls;
    bool use_ote;

    // Paramètres IA
    bool use_ai_signals;
    string ai_server_url;
    int ai_timeout_ms;
    double min_ai_confidence;

    // Timeframes
    ENUM_TIMEFRAMES primary_timeframe;
    ENUM_TIMEFRAMES secondary_timeframe;

    // Logging
    bool enable_logging;
    int log_level;

    // Méthodes
    void Load();
    bool Validate();
    string ToString();
};

// Instance de configuration
SMC_Config g_config;

//+------------------------------------------------------------------+
//| STRUCTURES SMC HEDGE FUND                                      |
//+------------------------------------------------------------------+

// === ZONE DE LIQUIDITÉ ===
struct LiquidityZone {
    double price;
    datetime time;
    int touches;
    string type; // "SWING_HIGH", "SWING_LOW", "EQUAL_HIGH", "EQUAL_LOW"
    double strength;
    bool isActive;
    string objectId;
    
    void Reset() {
        price = 0.0;
        time = 0;
        touches = 0;
        type = "";
        strength = 0.0;
        isActive = false;
        objectId = "";
    }
};

// === STRUCTURE DE MARCHÉ SMC ===
struct SMCMarketStructure {
    double lastSwingHigh;
    double lastSwingLow;
    datetime lastSwingHighTime;
    datetime lastSwingLowTime;
    double currentEqualHigh;
    double currentEqualLow;
    int equalHighTouches;
    int equalLowTouches;
    bool bullishStructure;
    bool bearishStructure;
    
    void Reset() {
        lastSwingHigh = 0.0;
        lastSwingLow = 0.0;
        lastSwingHighTime = 0;
        lastSwingLowTime = 0;
        currentEqualHigh = 0.0;
        currentEqualLow = 0.0;
        equalHighTouches = 0;
        equalLowTouches = 0;
        bullishStructure = false;
        bearishStructure = false;
    }
};

// === CONFIGURATION SMC HEDGE FUND ===
struct SMCHedgeFundConfig {
    // Détection de liquidité
    int swingLookback;
    double equalTolerance;
    int minEqualTouches;
    double liquidityStrength;
    int maxLiquidityZones;
    bool useTrendlines;
    
    // Stratégie d'entrée
    bool waitForSweep;
    double sweepThreshold;
    bool confirmBreakOfStructure;
    int entryDelayBars;
    double minMoveAfterSweep;
    bool useVolumeConfirmation;
    
    // Gestion des risques
    double maxDailyLoss;
    int maxDailyTrades;
    double maxSpreadPoints;
    double stopLossBuffer;
    bool useTrailingStop;
    double trailingStopATR;
    
    // Affichage
    bool showLiquidityZones;
    bool showSweeps;
    bool showEntries;
    bool showDashboard;
    color liquidityColor;
    color sweepColor;
    color entryColor;
    
    void LoadDefaults() {
        swingLookback = 5;
        equalTolerance = 15.0;
        minEqualTouches = 2;
        liquidityStrength = 0.7;
        maxLiquidityZones = 10;
        useTrendlines = true;
        
        waitForSweep = true;
        sweepThreshold = 5.0;
        confirmBreakOfStructure = true;
        entryDelayBars = 1;
        minMoveAfterSweep = 10.0;
        useVolumeConfirmation = true;
        
        maxDailyLoss = 50.0;
        maxDailyTrades = 20;
        maxSpreadPoints = 5.0;
        stopLossBuffer = 3.0;
        useTrailingStop = true;
        trailingStopATR = 1.5;
        
        showLiquidityZones = true;
        showSweeps = true;
        showEntries = true;
        showDashboard = true;
        liquidityColor = clrOrange;
        sweepColor = clrRed;
        entryColor = clrLime;
    }
};

// Variables globales SMC Hedge Fund
SMCHedgeFundConfig g_smcConfig;
SMCMarketStructure g_smcMarketStructure;
LiquidityZone g_smcLiquidityZones[];
double g_smcDailyPL = 0.0;
int g_smcDailyTradeCount = 0;
datetime g_smcLastBarTime = 0;
datetime g_smcDailyResetTime = 0;

//+------------------------------------------------------------------+
//| SECTION 3: STRUCTURES DE DONNÉES                                 |
//+------------------------------------------------------------------+

// === SIGNAL IA ===
struct AISignal {
    string symbol;
    string direction;      // "BUY", "SELL", "HOLD"
    double confidence;     // 0.0 - 1.0
    double entry_price;
    double stop_loss;
    double take_profit;
    string reasoning;
    datetime timestamp;
    bool is_valid;
    string server_status;  // statut brut renvoyé par ai_server.py
    bool is_fallback;      // vrai uniquement si fallback local EA
    // Décision /decision — technical_analysis.chart_pattern (ai_server)
    string chart_pattern_name;
    string chart_pattern_direction; // BUY / SELL / NEUTRAL / HOLD
    double chart_pattern_score;     // 0..1 ou 0..100 (normalisé en 0..1 côté parse)
    double chart_pattern_zone_low;
    double chart_pattern_zone_high;

    void Reset() {
        symbol = "";
        direction = "HOLD";
        confidence = 0.0;
        entry_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        reasoning = "";
        timestamp = 0;
        is_valid = false;
        server_status = "UNKNOWN";
        is_fallback = false;
        chart_pattern_name = "";
        chart_pattern_direction = "";
        chart_pattern_score = 0.0;
        chart_pattern_zone_low = 0.0;
        chart_pattern_zone_high = 0.0;
    }
};

void ExtractAiServerChartPatternFromJson(const string json, AISignal &signal);
string NormalizeOllamaSide(const string recIn);
bool JsonBlkPickQuoted(const string blk, const string key, string &outVal);
bool JsonBlkPickNumber(const string blk, const string key, double &outVal);

// === ANALYSE OLLAMA (LLM local) ===
struct OllamaAnalysis {
    string symbol;
    string timeframe;
    string analysis;       // Analyse textuelle complète
    string summary;          // Résumé court
    string sentiment;      // BULLISH / BEARISH / NEUTRAL
    string recommendation; // BUY / SELL / HOLD
    double confidence;     // 0.0 - 1.0
    string reasoning;
    double key_support;
    double key_resistance;
    double key_entry_buy;
    double key_entry_sell;
    double risk_reward;
    datetime timestamp;
    bool is_valid;
    double latency_ms;

    void Reset() {
        symbol = "";
        timeframe = "";
        analysis = "";
        summary = "";
        sentiment = "NEUTRAL";
        recommendation = "HOLD";
        confidence = 0.0;
        reasoning = "";
        key_support = 0.0;
        key_resistance = 0.0;
        key_entry_buy = 0.0;
        key_entry_sell = 0.0;
        risk_reward = 0.0;
        timestamp = 0;
        is_valid = false;
        latency_ms = 0.0;
    }
};

// === ANALYSE TRADINGAGENTS (ai_server /tradingagents/realtime/status) ===
struct TradingAgentsAnalysis {
    string symbol;
    string recommendation; // BUY / SELL / HOLD
    double confidence;     // 0.0 - 1.0
    string reasoning;      // Résumé / analyse courte
    datetime timestamp;
    bool is_valid;

    void Reset() {
        symbol = "";
        recommendation = "HOLD";
        confidence = 0.0;
        reasoning = "";
        timestamp = 0;
        is_valid = false;
    }
};

// === PATTERN SMC ===
struct SMCPattern {
    string type;           // "FVG", "OB", "BOS", "LS", "OTE"
    double price_level;
    datetime start_time;
    datetime end_time;
    bool is_bullish;
    double strength;       // 0.0 - 1.0
    bool is_active;

    void Reset() {
        type = "";
        price_level = 0.0;
        start_time = 0;
        end_time = 0;
        is_bullish = false;
        strength = 0.0;
        is_active = false;
    }
};

// === NIVEAUX SUPPORT/RESISTANCE MULTI-TIMEFRAMES ===
struct SRLevels {
    string timeframe;
    double buy_level;      // Support
    double sell_level;     // Résistance
    double double_top;
    double double_bottom;
    
    void Reset() {
        timeframe = "";
        buy_level = 0.0;
        sell_level = 0.0;
        double_top = 0.0;
        double_bottom = 0.0;
    }
};

struct SRLevelsMultiTF {
    SRLevels m1;
    SRLevels m5;
    SRLevels m15;
    SRLevels m30;
    SRLevels h1;
    SRLevels h4;
    SRLevels d1;
    SRLevels w1;
    
    void Reset() {
        m1.Reset();
        m5.Reset();
        m15.Reset();
        m30.Reset();
        h1.Reset();
        h4.Reset();
        d1.Reset();
        w1.Reset();
    }
};

// === SETUP DE TRADING ===
struct TradingSetup {
    string symbol;
    string direction;
    double entry_price;
    double stop_loss;
    double take_profit;
    double lot_size;
    double risk_reward_ratio;
    double setup_score;      // 0.0 - 100.0
    AISignal ai_signal;
    SMCPattern patterns[];
    datetime setup_time;
    bool is_valid;
    string rejection_reason;

    void Reset() {
        symbol = "";
        direction = "";
        entry_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        lot_size = 0.0;
        risk_reward_ratio = 0.0;
        setup_score = 0.0;
        ai_signal.Reset();
        ArrayResize(patterns, 0);
        setup_time = 0;
        is_valid = false;
        rejection_reason = "";
    }
};

// === CACHE DE SIGNAL IA ===
struct CachedSignal {
    AISignal signal;
    datetime cache_time;
    int ttl_seconds;

    void Reset() {
        signal.Reset();
        cache_time = 0;
        ttl_seconds = 0;
    }

    bool IsExpired() {
        return (TimeCurrent() - cache_time) > ttl_seconds;
    }
};

//+------------------------------------------------------------------+
//| SECTION 4: VARIABLES GLOBALES                                    |
//+------------------------------------------------------------------+

// === OBJETS DE TRADING ===
CTrade trade;
CPositionInfo positionInfo;
COrderInfo orderInfo;
CDealInfo dealInfo;
CHistoryOrderInfo historyOrderInfo;

// === VARIABLES IA ===
AISignal g_lastAIAction;
CachedSignal g_aiCache;
datetime g_lastAIUpdateTime = 0;
int g_aiUpdateInterval = 30; // secondes
datetime g_smc_ai_health_last_ping = 0;
bool g_smc_ai_health_last_ok = true;

// === VARIABLES OLLAMA (LLM local) ===
OllamaAnalysis g_lastOllamaAnalysis;
datetime g_lastOllamaUpdateTime = 0;
int g_ollamaUpdateInterval = 60; // 1 minute en secondes (plus visible sur graphe)
string g_ollamaLastSummary = "";   // Pour notification anti-doublon

// === VARIABLES TRADINGAGENTS (analyse serveur temps réel) ===
TradingAgentsAnalysis g_lastTradingAgentsAnalysis;
datetime g_lastTradingAgentsUpdateTime = 0;
string g_lastTradingAgentsSummary = "";
double g_lastOpportunityCostScore = 0.0;
double g_lastOpportunityPriceDevATR = 0.0;

// === VARIABLES SMC ===
double g_lastSwingHigh = 0.0;
double g_lastSwingLow = 0.0;
datetime g_lastSwingHighTime = 0;
datetime g_lastSwingLowTime = 0;
SMCPattern g_activePatterns[];

// === VARIABLES DE GESTION DES RISQUES ===
double g_dailyProfit = 0.0;
double g_dailyLoss = 0.0;
int g_dailyTradeCount = 0;
datetime g_dailyResetTime = 0;
double g_peakEquity = 0.0;
double g_currentDrawdown = 0.0;

// Pause après seuil de profit journalier (réalisé)
datetime g_tenDollarProfitPauseStartTime = 0;
bool     g_tenDollarProfitTargetReached = false;
double   g_tenDollarProfitPeak = 0.0;
datetime g_tenDollarPauseUntil = 0;

// === VARIABLES DE COOLDOWN ===
datetime g_lastEntryTime = 0;
datetime g_lastCloseTime = 0;
ulong g_lastCloseTickets[16] = {0};
datetime g_lastCloseTimes[16] = {0};
int g_lastCloseIdx = 0;
double g_lastNotifiedVerdictNum = 9999.0;
string g_lastNotifiedDirection = "";
datetime g_lastNotifyTime = 0;
string g_lastOpportunityKey = "";
datetime g_lastOpportunityNotifyTime = 0;

//+------------------------------------------------------------------+
//| SECTION 5: INPUTS UTILISATEUR                                     |
//+------------------------------------------------------------------+

input group "=== GÉNÉRAL ==="
input bool   EnableTrading      = true;   // Activer/Désactiver le trading
input double InpLotSize         = 0.01;  // Taille de lot par défaut (optimisée pour risque minimal)
input int    MaxPositionsTerminal = 3;   // Nombre max de positions (augmenté pour plus d'opportunités)
input bool   OnePositionPerSymbol = false; // Permettre multiples positions par symbole pour maximiser les opportunités
input int    InpMagicNumber       = 202502; // Magic Number
input ENUM_EXECUTION_PROFILE ExecutionProfile = EXEC_PROFILE_AGGRESSIVE; // Profil d'exécution agressif
input bool   UseMinLotOnly      = false;  // Permettre lots variables selon calcul risque

input group "=== GESTION DES RISQUES ==="
input double MaxLossPerTradeDollars = 5.0;   // Perte max par trade ($) (augmenté pour plus de flexibilité)
input double MaxTotalLossDollars = 25.0;  // Perte maximale totale ($) (augmentée)
input double DailyProfitTarget = 50.0;    // Objectif profit journalier ($) (augmenté pour maximiser)
input double MaxDailyDrawdownPercent = 15.0; // Drawdown max journalier (%) (flexibilité accrue)
input double MaxDailyLossDollars = 20.0;   // Perte journalière max ($) (augmentée)
input bool   EnableTenDollarProfitPause = false; // Désactiver pause pour maximiser les opportunités
input double TenDollarProfitThreshold = 25.0;    // Seuil profit journalier ($, deals fermés, magic EA)
input int    TenDollarProfitPauseHours = 0;      // Durée pause (heures) - désactivée
input bool   UseAdaptiveRisk = true;        // Adapter le risque selon performance
input double MinHoldSecondsAfterEntry = 60;  // Temps min avant fermeture (sec) - réduit pour plus de réactivité
input bool   BlockEarlyClose = false;       // Permettre fermetures précoces pour sécuriser profits

input group "=== STRATÉGIES SMC ==="
input bool   UseFVG            = true;   // Fair Value Gap
input bool   UseOrderBlocks    = true;   // Order Blocks
input bool   UseBOS            = true;   // Break Of Structure
input bool   UseLiquiditySweep = true;   // Liquidity Sweep
input bool   UseOTE            = true;   // Optimal Trade Entry
input bool   UseEqualHL        = true;   // Equal Highs/Lows
input double MinSetupScoreEntry = 65.0;  // Score setup minimum (0-100) - réduit pour plus d'entrées
input double MinRiskReward     = 1.5;    // Ratio R:R minimum - réduit pour plus d'opportunités

input group "=== SMC HEDGE FUND STRATEGY ==="
input bool   EnableSMCHedgeFund = true;   // Activer stratégie Hedge Fund
input int    SMCSwingLookback   = 5;      // Période pour détection swing
input double SMCEqualTolerance  = 15.0;   // Tolérance pour equal highs/lows (points)
input int    SMCMinEqualTouches = 2;       // Touches minimum pour equal high/low
input double SMCLiquidityStrength = 0.7;    // Force minimale de la zone (0-1)
input int    SMCMaxLiquidityZones = 10;     // Nombre max de zones à tracking
input bool   SMCUseTrendlines   = true;      // Utiliser trendlines diagonales
input bool   SMCWaitForSweep    = true;      // Attendre sweep de liquidité
input double SMCSweepThreshold  = 5.0;       // Seuil de sweep (points)
input bool   SMCConfirmBOS      = true;       // Confirmer BOS après sweep
input int    SMCEntryDelayBars  = 1;          // Délai en barres après sweep
input double SMCMinMoveAfterSweep = 10.0;     // Mouvement minimum après sweep
input bool   SMCUseVolumeConfirmation = true;   // Confirmation volume
input double SMCMaxDailyLoss    = 50.0;      // Perte journalière maximale ($)
input int    SMCMaxDailyTrades  = 20;         // Trades max par jour
input double SMCMaxSpreadPoints = 5.0;        // Spread maximum autorisé
input double SMCStopLossBuffer  = 3.0;        // Buffer SL au-dessus/en dessous zone
input bool   SMCUseTrailingStop  = true;       // Utiliser trailing stop
input double SMCTrailingStopATR = 1.5;        // Trailing stop en ATR
input bool   SMCShowLiquidityZones = true;     // Afficher zones de liquidité
input bool   SMCShowSweeps       = true;       // Afficher sweeps détectés
input bool   SMCShowEntries      = true;       // Afficher TOUS les points d'entrée
input bool   SMCShowDashboard    = true;       // Afficher tableau de bord

input group "=== IA ET SIGNAUX ==="
input bool   UseAIServer       = true;   // Utiliser le serveur IA
input bool   EnableOllamaRemoteAnalysis = false; // true = appels /analyze/ollama + GV Ollama ; false = aucun impact LLM
input bool   EnableTradingAgentsRemoteAnalysis = true; // Lire analyse TradingAgents depuis ai_server (/tradingagents/realtime/status)
input int    TradingAgentsUpdateIntervalSeconds = 300; // Rafraîchissement analyse TradingAgents (5 min)
input double TradingAgentsMinConfidenceInfluence = 0.60; // Seuil conf mini pour influencer décision
input bool   TradingAgentsBlockContradiction = true; // Bloquer trade si contradiction forte TradingAgents
input string AI_ServerURL       = "http://127.0.0.1:8000";  // URL du serveur IA
input int    AI_Timeout_ms     = 3000;   // Timeout WebRequest (ms) - réduit pour plus de réactivité
input int    AI_UpdateInterval_Seconds = 15;  // Intervalle mise à jour IA (sec) - plus fréquent
input double MinAIConfidence   = 0.55;   // Confiance IA min (0-1) - réduite pour plus de signaux
input bool   UseAICache        = false;  // Désactiver cache pour signaux temps réel
input int    AICacheTTL        = 10;     // TTL du cache IA (sec) - réduit
input bool   AI_PreflightHealthPing = true;   // Tester GET /health (throttled) avant POST /decision
input int    AI_HealthPing_ms = 1000;         // Timeout GET /health - réduit
input int    AI_HealthPingThrottleSec = 10;   // Ne re-tester la santé qu'après X secondes - plus fréquent
input bool   AI_BlockPostWhenHealthFails = false; // false = tenter même si /health KO (plus agressif)
input bool   AI_UseNetworkFallbackTrend = true;  // SI échec POST → signal EMA fallback (TradBOT optim.)
input bool   UseScriptVerdictSync = true; // Suivre strictement le verdict GOM_SCRIPT_*
input double BoomCrashMaxFloatLossUsdBeforeScriptWaitClose = 5.0; // Augmenté pour plus de tolérance
input bool   TradeOnlyGoodPerfect = true; // true = aucune entrée tant que le verdict GOM n'est pas GOOD ou PERFECT (|verdict_num| ≥ 2)
input double MinFilterRatioForPlainVerdict = 0.65; // ratio augmenté pour filtrer les faux signaux
input bool   ReduceFalseSignals = true;              // ACTIVÉ pour réduire les faux signaux
input bool   PlainVerdictRequireAndFilters = false; // Mode OU pour plus de flexibilité
input double MinVerdictStrengthForPlain = 2.0;    // Force script min réduite
input int    MinFilterPassesForPlain = 3;          // Nombre min de filtres OK - augmenté
input double MinSpikeProbGoodPerfect = 0.50;       // Prob. spike min réduite
input double MinSpikeProbPlainBypass = 0.55;       // Réduite pour plus d'opportunités
input bool   SpikeBypassSkipsRangeAndMtf = false; // false = spike respecte anti-range + MTF (plus sûr)
input bool   BlockIfServerAiContradicts = false;    // Désactivé pour plus de flexibilité
input double ServerAiContradictMinConf = 0.60;
input double MinScriptFilterQuality = 0.45; // Seuil qualité filtres script réduit
input bool   EnforceExtraMinFilterQualityInEA = false; // Désactivé pour plus de flexibilité
input bool   SkipCorrectionFilterWhenScriptSync = true; // Sync script: ne pas refuser le trade pour IsCorrectionMove
input bool   EnablePushNotifications = true; // Notifications push MT5
input bool   PushTradingAgentsSummary = true; // Push MT5 quand nouveau résumé TradingAgents

input group "=== OPPORTUNITY COST (QUALITE TRADE) ==="
input bool   EnableOpportunityCostFilter = true; // Filtre coût d'opportunité (qualité)
input double OpportunityCostMinScore = 60.0; // Score mini autorisé [0..100]
input double OpportunityCostMaxScore = 100.0; // Score max autorisé [0..100]
input double OpportunityPriceDevMinATR = 0.00; // Distance min prix-entrée en ATR
input double OpportunityPriceDevMaxATR = 1.20; // Distance max prix-entrée en ATR

input group "=== GOM INTELLIGENCE (OBJETS / NIVEAUX SCRIPT) ==="
input bool   UseGomChartObjectIntel = true; // true = lire objets GOM_KOLA_* / GOM_SIDO_* (+ GV) pour affiner entrée et SL (ACTIVÉ)
input bool   GomIntelSkipWhenNoLevels = false; // false = exiger niveaux KOLA pour plus de précision
input bool   GomIntelRequireNearKolaLine = true; // Exiger que le prix soit proche d’au moins GomIntelMinKolaTfHits lignes d’entrée KOLA du même sens
input double GomIntelNearKolaMaxATR = 2.0; // |prix − niveau KOLA| ≤ ce multiple d’ATR M1 (augmenté)
input int    GomIntelMinKolaTfHits = 1; // Nombre minimal de TF « proches » parmi les cases cochées
input bool   GomIntelTfM1 = true;
input bool   GomIntelTfM5 = true;
input bool   GomIntelTfM15 = true;
input bool   GomIntelTfM30 = true; // Activé pour plus de précision
input bool   GomIntelTfH1 = true;
input bool   GomIntelPlainRequireSidoFigure = false; // Désactivé pour plus de flexibilité
input bool   GomIntelWidenSLToSidoStructure = true; // Reculer le SL derrière le niveau SIDO si le SL script était trop « serré » vs figure
input double GomIntelSidoSlBufferATR = 0.50; // Marge ATR augmentée pour plus de sécurité

input group "=== SL/TP DYNAMIQUES ==="
input double SL_ATRMult        = 1.5;    // Stop Loss (x ATR) - réduit pour plus de réactivité
input double TP_ATRMult        = 8.0;    // Take Profit (x ATR) - augmenté pour plus de profit
input int    ResyncScriptStopsIfEntryDriftPoints = 5; // Si >0 et niveaux script : recalcul SL/TP (ATR) quand |prix marché − entrée script| dépasse ce nombre de points ; 0 = garder script + seulement correction broker
input bool   UseTrailingStop    = true;   // Trailing / SL dynamique (symboles hors Boom/Crash/GainX/PainX : actif même si false)
input double TrailingStop_ATRMult = 1.2;  // Distance Trailing (x ATR) - réduite pour trailing plus serré
input double TrailingStartProfitDollars = 0.05; // Profit min pour trailing ($) - réduit
input bool   BoomCrashNoTrailingStop = false;   // Boom/Crash/GainX/PainX : permettre trailing pour maximiser profits
input bool   BoomCrashCloseOnScriptSpike = true; // Fermer si le script publie un spike aligné avec la position
input double BoomCrashSpikeCloseMinProb = 0.50;  // Probabilité spike min réduite
input double BoomCrashSpikeCloseMinProfitUSD = 0.0; // 0 = dès que le spike script est aligné

input group "=== GRAPHIQUES ==="
input bool   ShowChartGraphics = true;   // Afficher les graphiques SMC
input bool   ShowAIServerPatternOnChart = true; // Dessiner zone + libellé chart_pattern (ai_server) sur M1
input int    AIServerPatternZoneBarsM1 = 36;    // Largeur horizontale de la zone (bougies M1)
input color  AIServerPatternRectColor = clrDodgerBlue;
input color  AIServerPatternTextColor = clrWhite;
input bool   ShowDashboard      = true;   // Afficher le tableau de bord
input bool   ShowSignalArrow    = true;   // Afficher la flèche de signal

input bool EnableChartLeftShift = true; // Activé - décale légèrement le graphique vers la gauche
input double ChartLeftShiftPct = 25.0; // Largeur zone future (%) - décalage modéré
input bool ShowPastFutureSeparator = true; // Separation visuelle Passe/Futur
input int FutureZoneBars = 36; // Largeur zone future en bougies du TF courant
input color FutureZoneFillColor = 0x202020; // Fond discret zone future
input group "=== TIMING ==="
input bool   EnforceTradingTimeZones = false; // Zones de trading - désactivées pour 24/7
input int    MaxDailyTrades     = 50;     // Trades max par jour - augmenté
input int    EntryCooldownSeconds = 30;  // Cooldown entre entrées (sec) — réduit pour plus d'opportunités

input group "=== DIRECTION MTF (STRUCTURE) ==="
input bool   EnforceMtfTrendForScriptSync = false;  // Sync GOM : désactivé pour plus de flexibilité
input bool   MtfUnanimousForPlainVerdict = false;   // Verdict simple : mode majorité pour plus de signaux
input double MtfMinStrengthPercent = 50.0;           // Force alignement min (%) réduite

input group "=== ANTI-RANGE / CONSOLIDATION ==="
input bool   BlockConsolidationRange = false;      // Ne pas bloquer si marché en chop / range (plus d'opportunités)
input ENUM_TIMEFRAMES Consolidation_TF = PERIOD_M5; // Timeframe pour mesures (M5 = moins de bruit que M1)
input int    ConsolidationERLookback = 20;         // Barres pour le ratio d'efficacité prix
input double ConsolidationERMax = 0.35;            // Au-dessous = peu de déplacement net vs zigzag (chop) - augmenté
input bool   ConsolidationUseATRCompress = false;  // Désactivé pour moins de restrictions
input int    ConsolidationATRCompareBars = 50;     // Moyenne ATR sur N barres (min 14)
input double ConsolidationATRRatioMax = 0.85;      // ATR(0) / moyenne(ATR) : en dessous = volatilité compressée - augmenté
input bool   ConsolidationUseBBWidth = false;       // Désactivé pour moins de restrictions
input int    ConsolidationBBPeriod = 20;           // Période Bollinger
input double ConsolidationBBWidthMaxPct = 1.25;    // (Upper-Lower)/Middle * 100 ≤ seuil → squeeze (ajuster au symbole) - augmenté

//+------------------------------------------------------------------+
//| SECTION 6: FONCTIONS DE CONFIGURATION                             |
//+------------------------------------------------------------------+

void SMC_Config::Load() {
    // Charger la configuration depuis les inputs
    switch(ExecutionProfile) {
        case EXEC_PROFILE_SAFE:
            risk_mode = RISK_CONSERVATIVE;
            max_loss_per_trade = 2.0;
            max_positions = 1;
            break;
        case EXEC_PROFILE_AGGRESSIVE:
            risk_mode = RISK_AGGRESSIVE;
            max_loss_per_trade = 5.0;
            max_positions = 3;
            break;
        default:
            risk_mode = RISK_MODERATE;
            max_loss_per_trade = 3.0;
            max_positions = 2;
            break;
    }

    // Charger depuis les inputs
    max_total_loss_dollars = MaxTotalLossDollars;
    daily_profit_target = DailyProfitTarget;
    max_daily_drawdown_percent = MaxDailyDrawdownPercent;

    use_fvg = UseFVG;
    use_ob = UseOrderBlocks;
    use_bos = UseBOS;
    use_ls = UseLiquiditySweep;
    use_ote = UseOTE;

    use_ai_signals = UseAIServer;
    ai_server_url = AI_ServerURL;
    ai_timeout_ms = AI_Timeout_ms;
    min_ai_confidence = MinAIConfidence;

    primary_timeframe = PERIOD_M5;
    secondary_timeframe = PERIOD_H1;

    enable_logging = true;
    log_level = 1;
}

bool SMC_Config::Validate() {
    if(max_loss_per_trade <= 0) {
        Print("❌ Erreur: max_loss_per_trade doit être > 0");
        return false;
    }

    if(max_positions <= 0) {
        Print("❌ Erreur: max_positions doit être > 0");
        return false;
    }

    if(daily_profit_target <= 0) {
        Print("❌ Erreur: daily_profit_target doit être > 0");
        return false;
    }

    if(max_daily_drawdown_percent <= 0 || max_daily_drawdown_percent > 100) {
        Print("❌ Erreur: max_daily_drawdown_percent doit être entre 0 et 100");
        return false;
    }

    if(min_ai_confidence < 0 || min_ai_confidence > 1) {
        Print("❌ Erreur: min_ai_confidence doit être entre 0 et 1");
        return false;
    }

    return true;
}

string SMC_Config::ToString() {
    string result = "=== CONFIGURATION SMC ===\n";
    result += "Mode de risque: " + EnumToString(risk_mode) + "\n";
    result += "Perte max/trade: $" + DoubleToString(max_loss_per_trade, 2) + "\n";
    result += "Positions max: " + IntegerToString(max_positions) + "\n";
    result += "Perte totale max: $" + DoubleToString(max_total_loss_dollars, 2) + "\n";
    result += "Objectif profit journalier: $" + DoubleToString(daily_profit_target, 2) + "\n";
    result += "Drawdown max: " + DoubleToString(max_daily_drawdown_percent, 1) + "%\n";
    result += "IA activée: " + (use_ai_signals ? "OUI" : "NON") + "\n";
    result += "Confiance IA min: " + DoubleToString(min_ai_confidence * 100, 1) + "%\n";
    result += "Stratégies: ";
    if(use_fvg) result += "FVG ";
    if(use_ob) result += "OB ";
    if(use_bos) result += "BOS ";
    if(use_ls) result += "LS ";
    if(use_ote) result += "OTE ";
    result += "\n";
    return result;
}

//+------------------------------------------------------------------+
//| SECTION 7: GESTIONNAIRE DE RISQUES                               |
//+------------------------------------------------------------------+

class CSMCRiskManager {
private:
    double m_max_loss_per_trade;
    int m_max_positions;
    double m_daily_loss_limit;
    double m_current_daily_loss;
    double m_peak_equity;
    double m_current_drawdown;

public:
    CSMCRiskManager() {
        m_max_loss_per_trade = 3.0;
        m_max_positions = 2;
        m_daily_loss_limit = 10.0;
        m_current_daily_loss = 0.0;
        m_peak_equity = 0.0;
        m_current_drawdown = 0.0;
    }

    void SetParameters(double max_loss, int max_positions, double daily_limit) {
        m_max_loss_per_trade = max_loss;
        m_max_positions = max_positions;
        m_daily_loss_limit = daily_limit;
    }

    bool CanOpenPosition(string symbol, double lot) {
        // Vérifier le nombre de positions
        int total_positions = PositionsTotal();
        if(total_positions >= m_max_positions) {
            Print("⛔ RISQUE: Limite de positions atteinte (", total_positions, "/", m_max_positions, ")");
            return false;
        }

        // Vérifier une position par symbole
        if(OnePositionPerSymbol) {
            for(int i = 0; i < total_positions; i++) {
                if(PositionSelectByTicket(PositionGetTicket(i))) {
                    if(PositionGetString(POSITION_SYMBOL) == symbol) {
                        Print("⛔ RISQUE: Position déjà ouverte sur ", symbol);
                        return false;
                    }
                }
            }
        }

        // Vérifier la perte journalière
        if(m_current_daily_loss >= m_daily_loss_limit) {
            Print("⛔ RISQUE: Limite perte journalière atteinte ($", DoubleToString(m_current_daily_loss, 2), ")");
            return false;
        }

        // Vérifier le drawdown
        UpdateDrawdown();
        if(m_current_drawdown >= MaxDailyDrawdownPercent) {
            Print("⛔ RISQUE: Drawdown max atteint (", DoubleToString(m_current_drawdown, 1), "%)");
            return false;
        }

        return true;
    }

    bool ShouldClosePosition(string symbol, double current_profit) {
        // Fermer si perte dépasse le seuil
        if(current_profit < 0 && MathAbs(current_profit) >= m_max_loss_per_trade) {
            Print("⚠️ RISQUE: Perte max atteinte sur ", symbol, " ($", DoubleToString(current_profit, 2), ")");
            return true;
        }

        // Fermer si profit journalier atteint
        if(g_dailyProfit >= DailyProfitTarget) {
            Print("🎯 RISQUE: Objectif profit journalier atteint ($", DoubleToString(g_dailyProfit, 2), ")");
            return true;
        }

        return false;
    }

    double CalculateOptimalLotSize(double account_balance, double risk_percent, double stop_loss_points) {
        if(stop_loss_points <= 0) return InpLotSize;

        double risk_amount = account_balance * (risk_percent / 100.0);
        double point_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double lot_size = risk_amount / (stop_loss_points * point_value);

        // Arrondir au lot minimum
        double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

        lot_size = MathMax(min_lot, lot_size);
        lot_size = MathFloor(lot_size / lot_step) * lot_step;

        return NormalizeDouble(lot_size, 2);
    }

    double CalculateMaxStopLoss(double entry_price, double lot) {
        double risk_amount = m_max_loss_per_trade;
        double point_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double max_distance = risk_amount / (lot * point_value);

        return max_distance;
    }

    void UpdateDailyLoss(double realized_profit) {
        if(realized_profit < 0) {
            m_current_daily_loss += MathAbs(realized_profit);
        }
    }

    void ResetDailyLoss() {
        m_current_daily_loss = 0.0;
        g_dailyProfit = 0.0;
        g_dailyTradeCount = 0;
        g_dailyResetTime = TimeCurrent();
        Print("📅 RISQUE: Reset statistiques journalières");
    }

    void UpdateDrawdown() {
        double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);

        if(current_equity > m_peak_equity) {
            m_peak_equity = current_equity;
        }

        if(m_peak_equity > 0) {
            m_current_drawdown = ((m_peak_equity - current_equity) / m_peak_equity) * 100.0;
        }
    }

    double GetMaxLossPerTrade() { return m_max_loss_per_trade; }
    int GetMaxPositions() { return m_max_positions; }
    double GetCurrentDailyLoss() { return m_current_daily_loss; }
    double GetCurrentDrawdown() { return m_current_drawdown; }
};

// Instance du gestionnaire de risques
CSMCRiskManager g_riskManager;

//+------------------------------------------------------------------+
//| SECTION 8: CONNECTEUR IA                                          |
//+------------------------------------------------------------------+

class CSMCAIConnector {
private:
    string m_server_url;
    int m_timeout;
    int m_max_retries;

public:
    CSMCAIConnector(string url, int timeout = 5000, int max_retries = 3) {
        m_server_url = url;
        m_timeout = timeout;
        m_max_retries = max_retries;
    }

    string JsonSafeNumber(const double v, const int digits = 8) {
        if(!MathIsValidNumber(v) || v == DBL_MAX || v == -DBL_MAX) {
            return "null";
        }
        return DoubleToString(v, digits);
    }

    string JsonSafeString(const string s) {
        string t = s;
        StringReplace(t, "\\", "\\\\");
        StringReplace(t, "\"", "\\\"");
        return "\"" + t + "\"";
    }

    // 20 dernières bougies OHLC (TF = celui de la requête), ordre chronologique ancien → récent pour le serveur / Qwen.
    string BuildRecentCandlesJson(string symbol, ENUM_TIMEFRAMES tf, const int count) {
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        int n = CopyRates(symbol, tf, 0, count, rates);
        if(n <= 0) return "";
        int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        if(dg < 0 || dg > 18) dg = _Digits;
        string out = "\"recent_candles\":[";
        for(int i = n - 1; i >= 0; i--) {
            if(i < n - 1) out += ",";
            out += "{\"o\":" + JsonSafeNumber(rates[i].open, dg) +
                   ",\"h\":" + JsonSafeNumber(rates[i].high, dg) +
                   ",\"l\":" + JsonSafeNumber(rates[i].low, dg) +
                   ",\"c\":" + JsonSafeNumber(rates[i].close, dg) + "}";
        }
        out += "]";
        return out;
    }

    AISignal GetSignal(string symbol, ENUM_TIMEFRAMES timeframe) {
        AISignal signal;
        signal.Reset();

        // Vérifier le cache
        if(UseAICache && !g_aiCache.IsExpired() &&
           g_aiCache.signal.symbol == symbol) {
            signal = g_aiCache.signal;
            Print("📦 IA: Signal depuis cache pour ", symbol);
            return signal;
        }

      // Préparer la requête avec données de marché complètes
      string url = m_server_url + "/decision";
      double _bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double _ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      double _rsi = GetRSIValue(PERIOD_M1, 14);
      double _ema_f_m1 = 0.0, _ema_s_m1 = 0.0;
      double _ema_f_m5 = 0.0, _ema_s_m5 = 0.0;
      double _ema_f_h1 = 0.0, _ema_s_h1 = 0.0;
      double _atr = GetATRValue(PERIOD_M1, 14);

      int _h9m1 = iMA(symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
      int _h21m1 = iMA(symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
      int _h9m5 = iMA(symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
      int _h21m5 = iMA(symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
      int _h9h1 = iMA(symbol, PERIOD_H1, 9, 0, MODE_EMA, PRICE_CLOSE);
      int _h21h1 = iMA(symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);

      double _tmp[];
      ArraySetAsSeries(_tmp, true);
      if(_h9m1 != INVALID_HANDLE && CopyBuffer(_h9m1, 0, 0, 1, _tmp) >= 1) _ema_f_m1 = _tmp[0];
      if(_h21m1 != INVALID_HANDLE && CopyBuffer(_h21m1, 0, 0, 1, _tmp) >= 1) _ema_s_m1 = _tmp[0];
      if(_h9m5 != INVALID_HANDLE && CopyBuffer(_h9m5, 0, 0, 1, _tmp) >= 1) _ema_f_m5 = _tmp[0];
      if(_h21m5 != INVALID_HANDLE && CopyBuffer(_h21m5, 0, 0, 1, _tmp) >= 1) _ema_s_m5 = _tmp[0];
      if(_h9h1 != INVALID_HANDLE && CopyBuffer(_h9h1, 0, 0, 1, _tmp) >= 1) _ema_f_h1 = _tmp[0];
      if(_h21h1 != INVALID_HANDLE && CopyBuffer(_h21h1, 0, 0, 1, _tmp) >= 1) _ema_s_h1 = _tmp[0];

      if(_h9m1 != INVALID_HANDLE) IndicatorRelease(_h9m1);
      if(_h21m1 != INVALID_HANDLE) IndicatorRelease(_h21m1);
      if(_h9m5 != INVALID_HANDLE) IndicatorRelease(_h9m5);
      if(_h21m5 != INVALID_HANDLE) IndicatorRelease(_h21m5);
      if(_h9h1 != INVALID_HANDLE) IndicatorRelease(_h9h1);
      if(_h21h1 != INVALID_HANDLE) IndicatorRelease(_h21h1);

      // Lecture de tous les niveaux GOM KOLA pour tous les timeframes
      double _m1buy = ReadGlobalDouble("GOM_KOLA_" + symbol + "_M1_BUY", 0.0);
      double _m1sell = ReadGlobalDouble("GOM_KOLA_" + symbol + "_M1_SELL", 0.0);
      double _m5buy = ReadGlobalDouble("GOM_KOLA_" + symbol + "_M5_BUY", 0.0);
      double _m5sell = ReadGlobalDouble("GOM_KOLA_" + symbol + "_M5_SELL", 0.0);
      double _m15buy = ReadGlobalDouble("GOM_KOLA_" + symbol + "_M15_BUY", 0.0);
      double _m15sell = ReadGlobalDouble("GOM_KOLA_" + symbol + "_M15_SELL", 0.0);
      double _m30buy = ReadGlobalDouble("GOM_KOLA_" + symbol + "_M30_BUY", 0.0);
      double _m30sell = ReadGlobalDouble("GOM_KOLA_" + symbol + "_M30_SELL", 0.0);
      double _h1buy = ReadGlobalDouble("GOM_KOLA_" + symbol + "_H1_BUY", 0.0);
      double _h1sell = ReadGlobalDouble("GOM_KOLA_" + symbol + "_H1_SELL", 0.0);
      double _h4buy = ReadGlobalDouble("GOM_KOLA_" + symbol + "_H4_BUY", 0.0);
      double _h4sell = ReadGlobalDouble("GOM_KOLA_" + symbol + "_H4_SELL", 0.0);
      double _d1buy = ReadGlobalDouble("GOM_KOLA_" + symbol + "_D1_BUY", 0.0);
      double _d1sell = ReadGlobalDouble("GOM_KOLA_" + symbol + "_D1_SELL", 0.0);
      double _w1buy = ReadGlobalDouble("GOM_KOLA_" + symbol + "_W1_BUY", 0.0);
      double _w1sell = ReadGlobalDouble("GOM_KOLA_" + symbol + "_W1_SELL", 0.0);
      
      int _dir_rule = 0;
      string _symUp = symbol; StringToUpper(_symUp);
      if(StringFind(_symUp, "BOOM") >= 0 || StringFind(_symUp, "GAINX") >= 0) _dir_rule = 1;
      else if(StringFind(_symUp, "CRASH") >= 0 || StringFind(_symUp, "PAINX") >= 0) _dir_rule = -1;

      string _recent_candles = BuildRecentCandlesJson(symbol, timeframe, 20);

      string post_data = "{\"symbol\":" + JsonSafeString(symbol) + "," +
      "\"timeframe\":" + JsonSafeString(EnumToString(timeframe)) + "," +
      "\"timestamp\":" + JsonSafeString(TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS)) + "," +
      "\"bid\":" + JsonSafeNumber(_bid, _Digits) + "," +
      "\"ask\":" + JsonSafeNumber(_ask, _Digits) + "," +
      "\"rsi\":" + JsonSafeNumber(_rsi, 2) + "," +
      "\"ema_fast_m1\":" + JsonSafeNumber(_ema_f_m1, _Digits) + "," +
      "\"ema_slow_m1\":" + JsonSafeNumber(_ema_s_m1, _Digits) + "," +
      "\"ema_fast_m5\":" + JsonSafeNumber(_ema_f_m5, _Digits) + "," +
      "\"ema_slow_m5\":" + JsonSafeNumber(_ema_s_m5, _Digits) + "," +
      "\"ema_fast_h1\":" + JsonSafeNumber(_ema_f_h1, _Digits) + "," +
      "\"ema_slow_h1\":" + JsonSafeNumber(_ema_s_h1, _Digits) + "," +
      "\"atr\":" + JsonSafeNumber(_atr, _Digits) + "," +
      "\"dir_rule\":" + IntegerToString(_dir_rule) + "," +
      "\"m1_buy_entry_point\":" + JsonSafeNumber(_m1buy, _Digits) + "," +
      "\"m1_sell_entry_point\":" + JsonSafeNumber(_m1sell, _Digits) + "," +
      "\"m5_buy_entry_point\":" + JsonSafeNumber(_m5buy, _Digits) + "," +
      "\"m5_sell_entry_point\":" + JsonSafeNumber(_m5sell, _Digits) + "," +
      "\"m15_buy_entry_point\":" + JsonSafeNumber(_m15buy, _Digits) + "," +
      "\"m15_sell_entry_point\":" + JsonSafeNumber(_m15sell, _Digits) + "," +
      "\"m30_buy_entry_point\":" + JsonSafeNumber(_m30buy, _Digits) + "," +
      "\"m30_sell_entry_point\":" + JsonSafeNumber(_m30sell, _Digits) + "," +
      "\"h1_buy_entry_point\":" + JsonSafeNumber(_h1buy, _Digits) + "," +
      "\"h1_sell_entry_point\":" + JsonSafeNumber(_h1sell, _Digits) + "," +
      "\"h4_buy_entry_point\":" + JsonSafeNumber(_h4buy, _Digits) + "," +
      "\"h4_sell_entry_point\":" + JsonSafeNumber(_h4sell, _Digits) + "," +
      "\"d1_buy_entry_point\":" + JsonSafeNumber(_d1buy, _Digits) + "," +
      "\"d1_sell_entry_point\":" + JsonSafeNumber(_d1sell, _Digits) + "," +
      "\"w1_buy_entry_point\":" + JsonSafeNumber(_w1buy, _Digits) + "," +
      "\"w1_sell_entry_point\":" + JsonSafeNumber(_w1sell, _Digits) +
      (StringLen(_recent_candles) > 0 ? "," + _recent_candles : "") + "}";

        if(AI_PreflightHealthPing)
        {
            datetime now_hp = TimeCurrent();
            if(g_smc_ai_health_last_ping == 0 ||
               (now_hp - g_smc_ai_health_last_ping) >= AI_HealthPingThrottleSec)
            {
                g_smc_ai_health_last_ok = PingAIServerHealth();
                g_smc_ai_health_last_ping = now_hp;
                if(!g_smc_ai_health_last_ok)
                    Print("⚠️ IA: GET /health indisponible (base=", m_server_url, ")");
            }
            if(AI_BlockPostWhenHealthFails && !g_smc_ai_health_last_ok)
            {
                Print("⚠️ IA: pas de POST /decision (/health KO) — fallback ou invalide");
                if(AI_UseNetworkFallbackTrend)
                    return TrendFallbackFromEMA(symbol, timeframe, _bid, _ask);
                return GetInvalidSignal(symbol);
            }
        }

        // Envoyer la requête avec retry
        for(int retry = 0; retry < m_max_retries; retry++) {
            string response;
            int timeout = m_timeout;

            char result[];
            char data[];
            string resultHeaders;
            // Envoyer un JSON UTF-8 sans octet nul terminal pour éviter les payloads invalides côté FastAPI.
            StringToCharArray(post_data, data, 0, StringLen(post_data), CP_UTF8);

            int res = WebRequest("POST", url, "Content-Type: application/json\r\n",
                                timeout, data, result, resultHeaders);

            if(res == -1) {
                int error = GetLastError();
                Print("❌ IA: Erreur WebRequest (tentative ", retry + 1, "/", m_max_retries,
                      ") url=", url, " err=", error);
                continue;
            }

            if(res == 200) {
                response = CharArrayToString(result);

                // Parser la réponse JSON
                if(ParseAIResponse(response, signal)) {
                    signal.symbol = symbol;
                    signal.timestamp = TimeCurrent();
                    ExtractAiServerChartPatternFromJson(response, signal);
                    signal.is_valid = ValidateSignal(signal);

                    // Mettre en cache
                    if(UseAICache) {
                        g_aiCache.signal = signal;
                        g_aiCache.cache_time = TimeCurrent();
                        g_aiCache.ttl_seconds = AICacheTTL;
                    }

                    Print("✅ IA: Signal reçu pour ", symbol, " - ", signal.direction,
                          " (confiance: ", DoubleToString(signal.confidence * 100, 1), "%)");
                    return signal;
                }
            }
        }

        if(AI_UseNetworkFallbackTrend)
        {
            Print("⚠️ IA: échec POST /decision — fallback technique EMA (optim. TradBOT)");
            return TrendFallbackFromEMA(symbol, timeframe, _bid, _ask);
        }
        Print("⚠️ IA: Échec obtention signal, statut INVALID");
        return GetInvalidSignal(symbol);
    }

    bool ParseAIResponse(string json, AISignal &signal) {
        // Log de debug pour voir la réponse brute
        Print("🔍 IA: Parsing JSON response: ", StringSubstr(json, 0, 250));
        
        // Parser JSON robuste (copie de SMC_Universal.mq5 original)
        // Format attendu: {"action": "buy", "confidence": 0.75, ...}
        
        int action_pos = StringFind(json, "\"action\"");
        if(action_pos < 0) action_pos = StringFind(json, "'action'");
        
        int confidence_pos = StringFind(json, "\"confidence\"");
        if(confidence_pos < 0) confidence_pos = StringFind(json, "'confidence'");
        
        int reason_pos = StringFind(json, "\"reason\"");
        if(reason_pos < 0) reason_pos = StringFind(json, "'reason'");
        
        int status_pos = StringFind(json, "\"status\"");
        if(status_pos < 0) status_pos = StringFind(json, "'status'");
        
        int entry_pos = StringFind(json, "\"entry_price\"");
        if(entry_pos < 0) entry_pos = StringFind(json, "'entry_price'");
        
        int sl_pos = StringFind(json, "\"stop_loss\"");
        if(sl_pos < 0) sl_pos = StringFind(json, "'stop_loss'");
        
        int tp_pos = StringFind(json, "\"take_profit\"");
        if(tp_pos < 0) tp_pos = StringFind(json, "'take_profit'");
        int decision_pos_v3 = StringFind(json, "\"decision\"");
        if(decision_pos_v3 < 0) decision_pos_v3 = StringFind(json, "'decision'");

        // Extraire "action" si présent ; sinon autres clés dont "decision" (payloads TradBOT unified)
        string action = "";

        if(action_pos >= 0)
        {
        int actionStart = StringFind(json, "\"", action_pos + 9);  // Chercher quote après "action":
        if(actionStart < 0) actionStart = StringFind(json, "'", action_pos + 9);
        if(actionStart >= 0)
        {
            actionStart += 1;  // Après la quote ouvrante
            int actionEnd = StringFind(json, "\"", actionStart);
            if(actionEnd < 0) actionEnd = StringFind(json, "'", actionStart);
            if(actionEnd > actionStart)
            {
                action = StringSubstr(json, actionStart, actionEnd - actionStart);
            }
        }
        
        // Si pas trouvé avec quotes, essayer sans quotes (valeur numérique ou directe)
        if(action == "")
        {
            int valStart = StringFind(json, ":", action_pos) + 1;
            int valEnd = StringFind(json, ",", valStart);
            if(valEnd < 0) valEnd = StringFind(json, "}", valStart);
            if(valEnd > valStart)
            {
                action = StringSubstr(json, valStart, valEnd - valStart);
                StringTrimLeft(action);
                StringTrimRight(action);
            }
        }
        }
        
        // Fallback 1: certains endpoints renvoient "recommendation" au lieu de "action".
        if(action == "")
        {
            int rec_pos = StringFind(json, "\"recommendation\"");
            if(rec_pos < 0) rec_pos = StringFind(json, "'recommendation'");
            if(rec_pos >= 0)
            {
                int recStart = StringFind(json, "\"", rec_pos + 16);
                if(recStart < 0) recStart = StringFind(json, "'", rec_pos + 16);
                if(recStart >= 0)
                {
                    recStart += 1;
                    int recEnd = StringFind(json, "\"", recStart);
                    if(recEnd < 0) recEnd = StringFind(json, "'", recStart);
                    if(recEnd > recStart)
                        action = StringSubstr(json, recStart, recEnd - recStart);
                }
            }
        }

        // Fallback 1c: payloads avec "decision" (majuscules BUY/SELL/HOLD ou minuscules)
        if(action == "" && decision_pos_v3 >= 0)
        {
            int dcStart = StringFind(json, "\"", decision_pos_v3 + 11);
            if(dcStart < 0) dcStart = StringFind(json, "'", decision_pos_v3 + 11);
            if(dcStart >= 0)
            {
                dcStart += 1;
                int dcEnd = StringFind(json, "\"", dcStart);
                if(dcEnd < 0) dcEnd = StringFind(json, "'", dcStart);
                if(dcEnd > dcStart)
                    action = StringSubstr(json, dcStart, dcEnd - dcStart);
            }
            if(action == "")
            {
                int valStart = StringFind(json, ":", decision_pos_v3) + 1;
                int valEnd = StringFind(json, ",", valStart);
                if(valEnd < 0) valEnd = StringFind(json, "}", valStart);
                if(valEnd > valStart)
                {
                    action = StringSubstr(json, valStart, valEnd - valStart);
                    StringTrimLeft(action);
                    StringTrimRight(action);
                }
            }
        }

        // Fallback 2: certains payloads encapsulent l'action dans final_decision/action.
        if(action == "")
        {
            int fd_pos = StringFind(json, "\"final_decision\"");
            if(fd_pos >= 0)
            {
                int nested_action_pos = StringFind(json, "\"action\"", fd_pos);
                if(nested_action_pos >= 0)
                {
                    int nStart = StringFind(json, "\"", nested_action_pos + 9);
                    if(nStart < 0) nStart = StringFind(json, "'", nested_action_pos + 9);
                    if(nStart >= 0)
                    {
                        nStart += 1;
                        int nEnd = StringFind(json, "\"", nStart);
                        if(nEnd < 0) nEnd = StringFind(json, "'", nStart);
                        if(nEnd > nStart)
                            action = StringSubstr(json, nStart, nEnd - nStart);
                    }
                }
            }
        }

        if(action == "")
        {
            Print("❌ IA: aucun champ action/recommendation/final_decision/decision exploitable dans JSON");
            return false;
        }

        StringToUpper(action);
        StringReplace(action, "\"", "");
        StringReplace(action, "'", "");
        StringTrimLeft(action);
        StringTrimRight(action);

        // Normalisation de synonymes possibles côté serveurs/LLM.
        if(action == "LONG" || action == "ACHAT") action = "BUY";
        if(action == "SHORT" || action == "VENTE") action = "SELL";
        if(action == "WAIT" || action == "NEUTRAL" || action == "NONE" || action == "ATTENTE") action = "HOLD";
        
        // Vérifier si l'action est valide
        if(action == "" || action == "NULL" ||
           (action != "BUY" && action != "SELL" && action != "HOLD"))
        {
            if(action != "")
                Print("⚠️ IA: Action invalide '", action, "'");
            action = "HOLD";
        }
        
        Print("✅ IA: Action extraite: '", action, "'");

        // Extraire la confiance
        double confidence = 0.0;
        if(confidence_pos >= 0)
        {
            int conf_start = StringFind(json, ":", confidence_pos) + 1;
            int conf_end = StringFind(json, ",", conf_start);
            if(conf_end < 0) conf_end = StringFind(json, "}", conf_start);
            if(conf_end > conf_start)
            {
                string conf_str = StringSubstr(json, conf_start, conf_end - conf_start);
                StringTrimLeft(conf_str);
                StringTrimRight(conf_str);
                confidence = StringToDouble(conf_str);
            }
        }
        if(confidence > 1.0) confidence /= 100.0; // certains serveurs renvoient 68 au lieu de 0.68
        if(confidence <= 0.0) confidence = 0.5;
        if(confidence < 0.0) confidence = 0.0;
        if(confidence > 1.0) confidence = 1.0;

        // Extraire la raison
        string reason = "";
        if(reason_pos >= 0) {
            int reason_start = StringFind(json, ":", reason_pos) + 1;
            int reason_end = StringFind(json, ",", reason_start);
            if(reason_end < 0) reason_end = StringFind(json, "}", reason_start);
            reason = StringSubstr(json, reason_start, reason_end - reason_start);
            StringTrimLeft(reason);
            StringTrimRight(reason);
            StringReplace(reason, "\"", "");
        }
        
        // Extraire le statut brut du serveur si présent.
        // Priorité: statut explicite; sinon inférence depuis la charge utile.
        string server_status = "";
        if(status_pos >= 0) {
            int st_start = StringFind(json, "\"", status_pos + 9);
            if(st_start < 0) st_start = StringFind(json, "'", status_pos + 9);
            if(st_start >= 0) {
                st_start += 1;
                int st_end = StringFind(json, "\"", st_start);
                if(st_end < 0) st_end = StringFind(json, "'", st_start);
                if(st_end > st_start) {
                    server_status = StringSubstr(json, st_start, st_end - st_start);
                    StringToUpper(server_status);
                }
            }
        }
        if(server_status == "")
        {
            string upperJson = json;
            StringToUpper(upperJson);
            if(StringFind(upperJson, "\"STATUS\":\"SCHEDULED_SKIP\"") >= 0 ||
               StringFind(upperJson, "\"STATUS\": \"SCHEDULED_SKIP\"") >= 0)
                server_status = "SCHEDULED_SKIP";
            else if(StringFind(upperJson, "\"STATUS\":\"ERROR\"") >= 0 ||
                    StringFind(upperJson, "\"STATUS\": \"ERROR\"") >= 0)
                server_status = "ERROR";
            else if(StringFind(upperJson, "\"STATUS\":\"REJECTED\"") >= 0 ||
                    StringFind(upperJson, "\"STATUS\": \"REJECTED\"") >= 0)
                server_status = "REJECTED";
            else if(action == "BUY" || action == "SELL" || action == "HOLD")
                server_status = "LIVE";
            else
                server_status = "UNKNOWN";
        }

        // Extraire entry_price
        double entry_price = 0.0;
        if(entry_pos >= 0) {
            int entry_start = StringFind(json, ":", entry_pos) + 1;
            int entry_end = StringFind(json, ",", entry_start);
            if(entry_end < 0) entry_end = StringFind(json, "}", entry_start);
            string entry_str = StringSubstr(json, entry_start, entry_end - entry_start);
            StringTrimLeft(entry_str);
            entry_price = StringToDouble(entry_str);
        }

        // Extraire stop_loss
        double stop_loss = 0.0;
        if(sl_pos >= 0) {
            int sl_start = StringFind(json, ":", sl_pos) + 1;
            int sl_end = StringFind(json, ",", sl_start);
            if(sl_end < 0) sl_end = StringFind(json, "}", sl_start);
            string sl_str = StringSubstr(json, sl_start, sl_end - sl_start);
            StringTrimLeft(sl_str);
            stop_loss = StringToDouble(sl_str);
        }

        // Extraire take_profit
        double take_profit = 0.0;
        if(tp_pos >= 0) {
            int tp_start = StringFind(json, ":", tp_pos) + 1;
            int tp_end = StringFind(json, ",", tp_start);
            if(tp_end < 0) tp_end = StringFind(json, "}", tp_start);
            string tp_str = StringSubstr(json, tp_start, tp_end - tp_start);
            StringTrimLeft(tp_str);
            take_profit = StringToDouble(tp_str);
        }

        signal.direction = action;
        signal.confidence = confidence;
        signal.reasoning = reason;
        signal.entry_price = entry_price;
        signal.stop_loss = stop_loss;
        signal.take_profit = take_profit;
        signal.server_status = server_status;
        signal.is_fallback = false;

        return true;
    }

    bool ValidateSignal(AISignal &signal) {
        if(signal.direction != "BUY" && signal.direction != "SELL" && signal.direction != "HOLD") {
            signal.direction = "HOLD";
            signal.reasoning = "Direction invalide";
            return false;
        }

        // Important: HOLD peut être un état valide du serveur (pas forcément un fallback).
        // On n'applique le seuil MinAIConfidence que pour BUY/SELL.
        if((signal.direction == "BUY" || signal.direction == "SELL") && signal.confidence < MinAIConfidence) {
            signal.reasoning = "Confiance insuffisante";
            return false;
        }

        return true;
    }

    AISignal GetInvalidSignal(string symbol) {
        AISignal signal;
        signal.Reset();
        signal.symbol = symbol;
        signal.direction = "HOLD";
        signal.confidence = 0.0;
        signal.reasoning = "IA indisponible";
        signal.timestamp = TimeCurrent();
        signal.is_valid = false;
        signal.server_status = "INVALID";
        signal.is_fallback = false;

        return signal;
    }

    bool PingAIServerHealth(void)
    {
        uchar req[];
        uchar res[];
        string rh = "";
        int ms = AI_HealthPing_ms;
        if(ms < 500)
            ms = 500;
        if(ms > m_timeout)
            ms = m_timeout;
        int code = WebRequest("GET", m_server_url + "/health",
                               "Content-Type: application/json\r\n",
                               ms, req, res, rh);
        return (code == 200);
    }

    AISignal TrendFallbackFromEMA(const string symbol, const ENUM_TIMEFRAMES timeframe,
                                   const double bid, const double ask)
    {
        AISignal fb;
        fb.Reset();
        fb.symbol = symbol;
        fb.timestamp = TimeCurrent();
        fb.is_fallback = true;
        fb.server_status = "FALLBACK_NET";

        double price_mid = bid;
        if(bid > 0.0 && ask > 0.0)
            price_mid = (bid + ask) / 2.0;
        else if(ask > 0.0)
            price_mid = ask;

        double mf = 0.0, mslow = 0.0;
        double mbuf[];
        ArraySetAsSeries(mbuf, true);
        int hf = iMA(symbol, timeframe, 9, 0, MODE_SMA, PRICE_CLOSE);
        int hs = iMA(symbol, timeframe, 21, 0, MODE_SMA, PRICE_CLOSE);
        if(hf != INVALID_HANDLE && CopyBuffer(hf, 0, 0, 1, mbuf) >= 1)
            mf = mbuf[0];
        if(hs != INVALID_HANDLE && CopyBuffer(hs, 0, 0, 1, mbuf) >= 1)
            mslow = mbuf[0];
        if(hf != INVALID_HANDLE)
            IndicatorRelease(hf);
        if(hs != INVALID_HANDLE)
            IndicatorRelease(hs);

        string ts = "NEUTRAL";
        if(mf > mslow * 1.001 && mslow > 0.0)
            ts = "UPTREND";
        else if(mf < mslow * 0.999 && mslow > 0.0)
            ts = "DOWNTREND";

        fb.reasoning = "Fallback EMA réseau: " + ts;

        if(ts == "UPTREND" && price_mid > 0.0)
        {
            fb.direction = "BUY";
            fb.confidence = 0.65;
            fb.entry_price = (ask > 0.0 ? ask : price_mid);
            fb.stop_loss = price_mid * 0.99;
            fb.take_profit = price_mid * 1.015;
        }
        else if(ts == "DOWNTREND" && price_mid > 0.0)
        {
            fb.direction = "SELL";
            fb.confidence = 0.65;
            fb.entry_price = (bid > 0.0 ? bid : price_mid);
            fb.stop_loss = price_mid * 1.01;
            fb.take_profit = price_mid * 0.985;
        }
        else
        {
            fb.direction = "HOLD";
            fb.confidence = 0.55;
            fb.entry_price = price_mid;
        }

        fb.is_valid = ValidateSignal(fb);
        return fb;
    }

    bool SendTradeResult(string symbol, bool success, double profit) {
        if(!UseAIServer) return true;

        string url = m_server_url + "/trades/feedback";
        string post_data = "{\"symbol\":\"" + symbol +
                          "\",\"success\":" + (success ? "true" : "false") +
                          ",\"profit\":" + DoubleToString(profit, 2) +
                          ",\"timestamp\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}";

        char result[];
        char data[];
        string resultHeaders;
        StringToCharArray(post_data, data);

        int res = WebRequest("POST", url, "Content-Type: application/json\r\n",
                            m_timeout, data, result, resultHeaders);

        return (res == 200);
    }

    // === PONT OLLAMA: Analyse approfondie par LLM local ===
    OllamaAnalysis GetOllamaAnalysis(string symbol, ENUM_TIMEFRAMES timeframe,
                                     double bid, double ask, double rsi,
                                     double ema_f_m1, double ema_s_m1,
                                     double ema_f_m5, double ema_s_m5,
                                     double ema_f_h1, double ema_s_h1,
                                     double atr,
                                     double m1_buy, double m1_sell,
                                     double m5_buy, double m5_sell,
                                     double m15_buy, double m15_sell,
                                     double h1_buy, double h1_sell) {
        OllamaAnalysis result;
        result.Reset();
        result.symbol = symbol;
        result.timeframe = EnumToString(timeframe);

        string url = m_server_url + "/analyze/ollama";
        string tf_str = EnumToString(timeframe);
        StringReplace(tf_str, "PERIOD_", "");

        // Construire le JSON de requête
        string jsonReq = "{" +
            "\"symbol\":\"" + symbol + "\"," +
            "\"timeframe\":\"" + tf_str + "\"," +
            "\"bid\":" + DoubleToString(bid, _Digits) + "," +
            "\"ask\":" + DoubleToString(ask, _Digits) + "," +
            "\"rsi\":" + DoubleToString(rsi, 2) + "," +
            "\"ema_fast_m1\":" + DoubleToString(ema_f_m1, _Digits) + "," +
            "\"ema_slow_m1\":" + DoubleToString(ema_s_m1, _Digits) + "," +
            "\"ema_fast_m5\":" + DoubleToString(ema_f_m5, _Digits) + "," +
            "\"ema_slow_m5\":" + DoubleToString(ema_s_m5, _Digits) + "," +
            "\"ema_fast_h1\":" + DoubleToString(ema_f_h1, _Digits) + "," +
            "\"ema_slow_h1\":" + DoubleToString(ema_s_h1, _Digits) + "," +
            "\"atr\":" + DoubleToString(atr, _Digits) + ",";

        if(m1_buy > 0.0)  jsonReq += "\"m1_buy_entry\":" + DoubleToString(m1_buy, _Digits) + ",";
        if(m1_sell > 0.0) jsonReq += "\"m1_sell_entry\":" + DoubleToString(m1_sell, _Digits) + ",";
        if(m5_buy > 0.0)  jsonReq += "\"m5_buy_entry\":" + DoubleToString(m5_buy, _Digits) + ",";
        if(m5_sell > 0.0) jsonReq += "\"m5_sell_entry\":" + DoubleToString(m5_sell, _Digits) + ",";
        if(m15_buy > 0.0) jsonReq += "\"m15_buy_entry\":" + DoubleToString(m15_buy, _Digits) + ",";
        if(m15_sell > 0.0) jsonReq += "\"m15_sell_entry\":" + DoubleToString(m15_sell, _Digits) + ",";
        if(h1_buy > 0.0)  jsonReq += "\"h1_buy_entry\":" + DoubleToString(h1_buy, _Digits) + ",";
        if(h1_sell > 0.0) jsonReq += "\"h1_sell_entry\":" + DoubleToString(h1_sell, _Digits) + ",";

        string _rc_ollama = BuildRecentCandlesJson(symbol, timeframe, 20);
        if(StringLen(_rc_ollama) > 0) {
            jsonReq += _rc_ollama;
            jsonReq += ",\"timestamp\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}";
        } else {
            jsonReq += "\"timestamp\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\"}";
        }

        Print("🧠 OLLAMA: Envoi analyse pour ", symbol, " → ", url);

        char data[];
        char resultArr[];
        string resultHeaders;
        StringToCharArray(jsonReq, data);

        int res = WebRequest("POST", url, "Content-Type: application/json\r\n",
                            15000, data, resultArr, resultHeaders); // 15s timeout

        if(res == -1) {
            int err = GetLastError();
            Print("❌ OLLAMA: Erreur WebRequest err=", err);
            return result;
        }

        if(res != 200) {
            Print("❌ OLLAMA: HTTP ", res);
            return result;
        }

        string jsonResp = CharArrayToString(resultArr);
        Print("🧠 OLLAMA: Réponse reçue (", StringLen(jsonResp), " chars)");

        // Parser la réponse JSON
        result = ParseOllamaResponse(jsonResp, symbol, tf_str);
        return result;
    }

    OllamaAnalysis ParseOllamaResponse(string json, string symbol, string tf) {
        OllamaAnalysis result;
        result.Reset();
        result.symbol = symbol;
        result.timeframe = tf;

        Print("🔍 OLLAMA: Parsing JSON (", StringSubstr(json, 0, 200), ")");

        // Extraire analysis
        int aPos = StringFind(json, "\"analysis\"");
        if(aPos >= 0) {
            int aStart = StringFind(json, "\"", aPos + 11) + 1;
            int aEnd = StringFind(json, "\",", aStart);
            if(aEnd < 0) aEnd = StringFind(json, "\"}", aStart);
            if(aEnd > aStart)
                result.analysis = StringSubstr(json, aStart, aEnd - aStart);
        }

        // Extraire summary
        int sPos = StringFind(json, "\"summary\"");
        if(sPos >= 0) {
            int sStart = StringFind(json, "\"", sPos + 10) + 1;
            int sEnd = StringFind(json, "\",", sStart);
            if(sEnd < 0) sEnd = StringFind(json, "\"}", sStart);
            if(sEnd > sStart)
                result.summary = StringSubstr(json, sStart, sEnd - sStart);
        }

        // Extraire sentiment
        int sentPos = StringFind(json, "\"sentiment\"");
        if(sentPos >= 0) {
            int sentStart = StringFind(json, "\"", sentPos + 12) + 1;
            int sentEnd = StringFind(json, "\"", sentStart);
            if(sentEnd > sentStart) {
                result.sentiment = StringSubstr(json, sentStart, sentEnd - sentStart);
                StringToUpper(result.sentiment);
            }
        }

        // Extraire recommendation
        int recPos = StringFind(json, "\"recommendation\"");
        if(recPos >= 0) {
            int recStart = StringFind(json, "\"", recPos + 17) + 1;
            int recEnd = StringFind(json, "\"", recStart);
            if(recEnd > recStart) {
                result.recommendation = StringSubstr(json, recStart, recEnd - recStart);
                StringToUpper(result.recommendation);
            }
        }

        // Extraire confidence
        int cPos = StringFind(json, "\"confidence\"");
        if(cPos >= 0) {
            int cStart = StringFind(json, ":", cPos) + 1;
            int cEnd = StringFind(json, ",", cStart);
            if(cEnd < 0) cEnd = StringFind(json, "}", cStart);
            if(cEnd > cStart) {
                string cStr = StringSubstr(json, cStart, cEnd - cStart);
                StringTrimLeft(cStr);
                StringTrimRight(cStr);
                result.confidence = StringToDouble(cStr);
                if(result.confidence > 1.0) result.confidence /= 100.0;
            }
        }

        // Extraire reasoning
        int rPos = StringFind(json, "\"reasoning\"");
        if(rPos >= 0) {
            int rStart = StringFind(json, "\"", rPos + 12) + 1;
            int rEnd = StringFind(json, "\",", rStart);
            if(rEnd < 0) rEnd = StringFind(json, "\"}", rStart);
            if(rEnd > rStart)
                result.reasoning = StringSubstr(json, rStart, rEnd - rStart);
        }

        // Extraire latency_ms
        int lPos = StringFind(json, "\"latency_ms\"");
        if(lPos >= 0) {
            int lStart = StringFind(json, ":", lPos) + 1;
            int lEnd = StringFind(json, ",", lStart);
            if(lEnd < 0) lEnd = StringFind(json, "}", lStart);
            if(lEnd > lStart) {
                string lStr = StringSubstr(json, lStart, lEnd - lStart);
                result.latency_ms = StringToDouble(lStr);
            }
        }

        // Extraire key_levels
        int klPos = StringFind(json, "\"key_levels\"");
        if(klPos >= 0) {
            int klStart = StringFind(json, "{", klPos);
            int klEnd = StringFind(json, "}", klStart);
            if(klEnd > klStart) {
                string klJson = StringSubstr(json, klStart, klEnd - klStart + 1);

                // support
                int supPos = StringFind(klJson, "\"support\"");
                if(supPos >= 0) {
                    int supStart = StringFind(klJson, ":", supPos) + 1;
                    int supEnd = StringFind(klJson, ",", supStart);
                    if(supEnd < 0) supEnd = StringFind(klJson, "}", supStart);
                    if(supEnd > supStart) {
                        string supStr = StringSubstr(klJson, supStart, supEnd - supStart);
                        StringTrimLeft(supStr); StringTrimRight(supStr);
                        if(supStr != "null" && supStr != "")
                            result.key_support = StringToDouble(supStr);
                    }
                }

                // resistance
                int resPos = StringFind(klJson, "\"resistance\"");
                if(resPos >= 0) {
                    int resStart = StringFind(klJson, ":", resPos) + 1;
                    int resEnd = StringFind(klJson, ",", resStart);
                    if(resEnd < 0) resEnd = StringFind(klJson, "}", resStart);
                    if(resEnd > resStart) {
                        string resStr = StringSubstr(klJson, resStart, resEnd - resStart);
                        StringTrimLeft(resStr); StringTrimRight(resStr);
                        if(resStr != "null" && resStr != "")
                            result.key_resistance = StringToDouble(resStr);
                    }
                }

                // entry_buy
                int ebPos = StringFind(klJson, "\"entry_buy\"");
                if(ebPos >= 0) {
                    int ebStart = StringFind(klJson, ":", ebPos) + 1;
                    int ebEnd = StringFind(klJson, ",", ebStart);
                    if(ebEnd < 0) ebEnd = StringFind(klJson, "}", ebStart);
                    if(ebEnd > ebStart) {
                        string ebStr = StringSubstr(klJson, ebStart, ebEnd - ebStart);
                        StringTrimLeft(ebStr); StringTrimRight(ebStr);
                        if(ebStr != "null" && ebStr != "")
                            result.key_entry_buy = StringToDouble(ebStr);
                    }
                }

                // entry_sell
                int esPos = StringFind(klJson, "\"entry_sell\"");
                if(esPos >= 0) {
                    int esStart = StringFind(klJson, ":", esPos) + 1;
                    int esEnd = StringFind(klJson, ",", esStart);
                    if(esEnd < 0) esEnd = StringFind(klJson, "}", esStart);
                    if(esEnd > esStart) {
                        string esStr = StringSubstr(klJson, esStart, esEnd - esStart);
                        StringTrimLeft(esStr); StringTrimRight(esStr);
                        if(esStr != "null" && esStr != "")
                            result.key_entry_sell = StringToDouble(esStr);
                    }
                }
            }
        }

        // Extraire risk_reward
        int rrPos = StringFind(json, "\"risk_reward\"");
        if(rrPos >= 0) {
            int rrStart = StringFind(json, ":", rrPos) + 1;
            int rrEnd = StringFind(json, ",", rrStart);
            if(rrEnd < 0) rrEnd = StringFind(json, "}", rrStart);
            if(rrEnd > rrStart) {
                string rrStr = StringSubstr(json, rrStart, rrEnd - rrStart);
                StringTrimLeft(rrStr); StringTrimRight(rrStr);
                if(rrStr != "null" && rrStr != "")
                    result.risk_reward = StringToDouble(rrStr);
            }
        }

        result.timestamp = TimeCurrent();
        result.is_valid = (result.recommendation == "BUY" || result.recommendation == "SELL" || result.recommendation == "HOLD");

        if(result.confidence <= 1e-9 && result.is_valid) {
            if(result.recommendation == "BUY" || result.recommendation == "SELL")
                result.confidence = 0.68;
            else if(result.sentiment == "BULLISH" || result.sentiment == "BEARISH")
                result.confidence = 0.58;
            else
                result.confidence = 0.52;
        }

        Print("✅ OLLAMA: Parse OK - Sentiment=", result.sentiment,
              " Reco=", result.recommendation,
              " Conf=", DoubleToString(result.confidence * 100, 1), "%",
              " Lat=", DoubleToString(result.latency_ms, 0), "ms");

        return result;
    }

    TradingAgentsAnalysis GetTradingAgentsAnalysis(const string symbol) {
        TradingAgentsAnalysis ta;
        ta.Reset();
        ta.symbol = symbol;

        string url = m_server_url + "/tradingagents/realtime/status";
        char req[];
        char resultArr[];
        string resultHeaders;
        ArrayResize(req, 0);

        int res = WebRequest("GET", url, "Content-Type: application/json\r\n",
                             m_timeout, req, resultArr, resultHeaders);
        if(res == -1) {
            Print("❌ TRADINGAGENTS: WebRequest GET status err=", GetLastError());
            return ta;
        }
        if(res != 200) {
            Print("❌ TRADINGAGENTS: HTTP ", res, " sur ", url);
            return ta;
        }

        string json = CharArrayToString(resultArr);
        if(StringLen(json) <= 0) return ta;

        string symbolKey = "\"" + symbol + "\":{";
        int sPos = StringFind(json, symbolKey);
        if(sPos < 0) {
            return ta;
        }

        int blkStart = StringFind(json, "{", sPos);
        if(blkStart < 0) return ta;
        int depth = 0;
        int blkEnd = -1;
        int len = StringLen(json);
        for(int i = blkStart; i < len; i++) {
            ushort ch = StringGetCharacter(json, i);
            if(ch == '{') depth++;
            else if(ch == '}') {
                depth--;
                if(depth <= 0) {
                    blkEnd = i;
                    break;
                }
            }
        }
        if(blkEnd <= blkStart) return ta;

        string blk = StringSubstr(json, blkStart, blkEnd - blkStart + 1);
        string rec = "";
        string rsn = "";
        double conf = 0.0;
        bool okRec = JsonBlkPickQuoted(blk, "recommendation", rec);
        bool okRsn = JsonBlkPickQuoted(blk, "reasoning", rsn);
        bool okConf = JsonBlkPickNumber(blk, "confidence", conf);
        if(!okRec && !okRsn && !okConf) return ta;

        StringToUpper(rec);
        if(conf > 1.0) conf /= 100.0;
        if(conf < 0.0) conf = 0.0;
        if(conf > 1.0) conf = 1.0;

        ta.recommendation = NormalizeOllamaSide(rec);
        ta.confidence = conf;
        ta.reasoning = rsn;
        ta.timestamp = TimeCurrent();
        ta.is_valid = (ta.recommendation == "BUY" || ta.recommendation == "SELL" || ta.recommendation == "HOLD");
        return ta;
    }
};

// Instance du connecteur IA
CSMCAIConnector *g_aiConnector = NULL;

//+------------------------------------------------------------------+
//| SECTION 9: DÉTECTEUR DE PATTERNS SMC                             |
//+------------------------------------------------------------------+

class CSMCPatternDetector {
public:
    // Détection FVG (Fair Value Gap)
    static bool DetectFVG(const double &open[], const double &high[],
                         const double &low[], const double &close[],
                         int index, SMCPattern &pattern) {
        pattern.Reset();

        if(index < 2) return false;

        // FVG haussier: bougie i-2 high < bougie i low
        if(high[index-2] < low[index]) {
            pattern.type = "FVG";
            pattern.price_level = high[index-2];
            pattern.is_bullish = true;
            pattern.strength = 0.8;
            pattern.is_active = true;
            pattern.start_time = 0;
            pattern.end_time = 0;
            return true;
        }

        // FVG baissier: bougie i-2 low > bougie i high
        if(low[index-2] > high[index]) {
            pattern.type = "FVG";
            pattern.price_level = low[index-2];
            pattern.is_bullish = false;
            pattern.strength = 0.8;
            pattern.is_active = true;
            pattern.start_time = 0;
            pattern.end_time = 0;
            return true;
        }

        return false;
    }

    // Détection Order Block
    static bool DetectOB(const double &open[], const double &high[],
                        const double &low[], const double &close[],
                        int index, SMCPattern &pattern) {
        pattern.Reset();

        if(index < 3) return false;

        // OB haussier: bougie baissière forte suivie d'un mouvement haussier
        if(close[index-3] < open[index-3] && // bougie baissière
           close[index] > close[index-3] && // mouvement haussier
           high[index-3] - low[index-3] > (high[index] - low[index]) * 1.5) { // OB plus grand
            pattern.type = "OB";
            pattern.price_level = low[index-3];
            pattern.is_bullish = true;
            pattern.strength = 0.7;
            pattern.is_active = true;
            return true;
        }

        // OB baissier: bougie haussière forte suivie d'un mouvement baissier
        if(close[index-3] > open[index-3] && // bougie haussière
           close[index] < close[index-3] && // mouvement baissier
           high[index-3] - low[index-3] > (high[index] - low[index]) * 1.5) { // OB plus grand
            pattern.type = "OB";
            pattern.price_level = high[index-3];
            pattern.is_bullish = false;
            pattern.strength = 0.7;
            pattern.is_active = true;
            return true;
        }

        return false;
    }

    // Détection BOS (Break of Structure)
    static bool DetectBOS(const double &high[], const double &low[],
                         int index, SMCPattern &pattern) {
        pattern.Reset();

        if(index < 5) return false;

        // BOS haussier: cassure d'un swing high
        double recent_high = high[0];
        for(int i = 1; i < 5; i++) {
            if(high[i] > recent_high) {
                recent_high = high[i];
            }
        }

        if(high[index] > recent_high) {
            pattern.type = "BOS";
            pattern.price_level = recent_high;
            pattern.is_bullish = true;
            pattern.strength = 0.9;
            pattern.is_active = true;
            return true;
        }

        // BOS baissier: cassure d'un swing low
        double recent_low = low[0];
        for(int i = 1; i < 5; i++) {
            if(low[i] < recent_low) {
                recent_low = low[i];
            }
        }

        if(low[index] < recent_low) {
            pattern.type = "BOS";
            pattern.price_level = recent_low;
            pattern.is_bullish = false;
            pattern.strength = 0.9;
            pattern.is_active = true;
            return true;
        }

        return false;
    }

    // Calcul de confluence de patterns
    static double CalculatePatternConfluence(SMCPattern &patterns[]) {
        if(ArraySize(patterns) == 0) return 0.0;

        double total_strength = 0.0;
        int active_count = 0;

        for(int i = 0; i < ArraySize(patterns); i++) {
            if(patterns[i].is_active) {
                total_strength += patterns[i].strength;
                active_count++;
            }
        }

        if(active_count == 0) return 0.0;

        return (total_strength / active_count) * 100.0;
    }
};

//+------------------------------------------------------------------+
//| SECTION 10: ANALYSE MULTI-TIMEFRAME                              |
//+------------------------------------------------------------------+

class CSMCMultiTimeframeAnalyzer {
private:
    ENUM_TIMEFRAMES m_timeframes[];
    int m_timeframe_count;

    bool CopyEmaPair(const string symbol, const ENUM_TIMEFRAMES tf, double &fastOut, double &slowOut) {
        int ema_fast = iMA(symbol, tf, 9, 0, MODE_EMA, PRICE_CLOSE);
        int ema_slow = iMA(symbol, tf, 21, 0, MODE_EMA, PRICE_CLOSE);
        if(ema_fast == INVALID_HANDLE || ema_slow == INVALID_HANDLE) {
            if(ema_fast != INVALID_HANDLE) IndicatorRelease(ema_fast);
            if(ema_slow != INVALID_HANDLE) IndicatorRelease(ema_slow);
            return false;
        }
        double fast_buf[], slow_buf[];
        ArrayResize(fast_buf, 1);
        ArrayResize(slow_buf, 1);
        ArraySetAsSeries(fast_buf, true);
        ArraySetAsSeries(slow_buf, true);
        bool ok = (CopyBuffer(ema_fast, 0, 0, 1, fast_buf) >= 1 && CopyBuffer(ema_slow, 0, 0, 1, slow_buf) >= 1);
        if(ok) {
            fastOut = fast_buf[0];
            slowOut = slow_buf[0];
        }
        IndicatorRelease(ema_fast);
        IndicatorRelease(ema_slow);
        return ok;
    }

public:
    CSMCMultiTimeframeAnalyzer() {
        // M5 / M15 / H1 : structure sans bruit M1
        ArrayResize(m_timeframes, 3);
        m_timeframes[0] = PERIOD_M5;
        m_timeframes[1] = PERIOD_M15;
        m_timeframes[2] = PERIOD_H1;
        m_timeframe_count = 3;
    }

    bool GetTrendAlignment(string symbol, string &direction, double &strength) {
        int aligned_count = 0;
        int total_count = 0;

        for(int i = 0; i < m_timeframe_count; i++) {
            ENUM_TIMEFRAMES tf = m_timeframes[i];
            double fastv = 0.0, slowv = 0.0;
            if(!CopyEmaPair(symbol, tf, fastv, slowv)) continue;

            total_count++;
            if(fastv > slowv)
                aligned_count++;
        }

        if(total_count == 0) {
            direction = "NEUTRAL";
            strength = 0.0;
            return false;
        }

        double alignment_ratio = (double)aligned_count / total_count;

        if(alignment_ratio >= 0.67) {
            direction = "BUY";
            strength = alignment_ratio * 100.0;
            return true;
        }
        if(alignment_ratio <= 0.33) {
            direction = "SELL";
            strength = (1.0 - alignment_ratio) * 100.0;
            return true;
        }
        direction = "NEUTRAL";
        strength = 50.0;
        return false;
    }

    // Tous les TF : EMA rapide > lente (BUY) ou < (SELL)
    bool ValidateUnanimousTrend(string symbol, string direction) {
        if(direction != "BUY" && direction != "SELL") return false;
        for(int i = 0; i < m_timeframe_count; i++) {
            double fastv = 0.0, slowv = 0.0;
            if(!CopyEmaPair(symbol, m_timeframes[i], fastv, slowv)) return false;
            if(direction == "BUY" && !(fastv > slowv)) return false;
            if(direction == "SELL" && !(fastv < slowv)) return false;
        }
        return true;
    }

    bool ValidateSignal(string symbol, string direction, const double minStrength) {
        string tf_direction;
        double tf_strength;
        if(!GetTrendAlignment(symbol, tf_direction, tf_strength))
            return false;
        return (tf_direction == direction && tf_strength + 1e-9 >= minStrength);
    }
};

// Instance de l'analyseur multi-timeframe
CSMCMultiTimeframeAnalyzer *g_mtfAnalyzer = NULL;

//+------------------------------------------------------------------+
//| SECTION 11: FONCTIONS UTILITAIRES                                 |
//+------------------------------------------------------------------+

double GetATRValue(ENUM_TIMEFRAMES tf, int period = 14) {
    int atr_handle = iATR(_Symbol, tf, period);
    if(atr_handle == INVALID_HANDLE) return 0.0;

    double atr_buf[];
    ArrayResize(atr_buf, (int)1);
    ArraySetAsSeries(atr_buf, true);

    if(CopyBuffer(atr_handle, 0, 0, 1, atr_buf) < 1) {
        IndicatorRelease(atr_handle);
        return 0.0;
    }

    double atr_value = atr_buf[0];
    IndicatorRelease(atr_handle);

    return atr_value;
}

double GetRSIValue(ENUM_TIMEFRAMES tf, int period = 14) {
    int rsi_handle = iRSI(_Symbol, tf, period, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) return 50.0;

    double rsi_buf[];
    ArrayResize(rsi_buf, (int)1);
    ArraySetAsSeries(rsi_buf, true);

    if(CopyBuffer(rsi_handle, 0, 0, 1, rsi_buf) < 1) {
        IndicatorRelease(rsi_handle);
        return 50.0;
    }

    double rsi_value = rsi_buf[0];
    IndicatorRelease(rsi_handle);

    return rsi_value;
}

// Ratio d'efficacité (0..1) : |Δprix net| / Σ|Δbarre|. Faible = chop / range, élevé = tendance lisse.
double ComputePriceEfficiencyRatio(ENUM_TIMEFRAMES tf, int lookback) {
    if(lookback < 3) return 1.0;
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int need = lookback + 1;
    if(CopyRates(_Symbol, tf, 0, need, rates) < need) return 1.0;
    double net = MathAbs(rates[0].close - rates[lookback].close);
    double path = 0.0;
    for(int i = 0; i < lookback; i++)
        path += MathAbs(rates[i].close - rates[i + 1].close);
    if(path <= 1e-12) return 0.0;
    double er = net / path;
    if(er > 1.0) er = 1.0;
    return er;
}

// ATR courant / moyenne ATR sur N barres (compression si ratio faible).
bool ConsolidationATRCompressed(ENUM_TIMEFRAMES tf, int compareBars, double ratioMax, double &outRatio) {
    outRatio = 1.0;
    int n = MathMax(compareBars, 15);
    int atr_handle = iATR(_Symbol, tf, 14);
    if(atr_handle == INVALID_HANDLE) return false;
    double buf[];
    ArraySetAsSeries(buf, true);
    if(CopyBuffer(atr_handle, 0, 0, n + 1, buf) < n + 1) {
        IndicatorRelease(atr_handle);
        return false;
    }
    IndicatorRelease(atr_handle);
    double cur = buf[0];
    if(cur <= 0.0) return false;
    double sum = 0.0;
    int count = 0;
    for(int i = 1; i <= n && i < ArraySize(buf); i++) {
        if(buf[i] > 0.0) {
            sum += buf[i];
            count++;
        }
    }
    if(count < 5) return false;
    double avg = sum / (double)count;
    if(avg <= 1e-12) return false;
    outRatio = cur / avg;
    return (outRatio + 1e-9 <= ratioMax);
}

// Largeur BB en % du milieu : faible = squeeze.
bool ConsolidationBBSqueeze(ENUM_TIMEFRAMES tf, int period, double widthMaxPct, double &outWidthPct) {
    outWidthPct = 999.0;
    if(period < 2) return false;
    int h = iBands(_Symbol, tf, period, 0, 2.0, PRICE_CLOSE);
    if(h == INVALID_HANDLE) return false;
    double up[], mid[], lo[];
    ArraySetAsSeries(up, true);
    ArraySetAsSeries(mid, true);
    ArraySetAsSeries(lo, true);
    bool ok = (CopyBuffer(h, 1, 0, 1, up) >= 1 && CopyBuffer(h, 0, 0, 1, mid) >= 1 && CopyBuffer(h, 2, 0, 1, lo) >= 1);
    IndicatorRelease(h);
    if(!ok) return false;
    double m = mid[0];
    if(m <= 1e-12) return false;
    outWidthPct = (up[0] - lo[0]) / m * 100.0;
    return (outWidthPct + 1e-9 <= widthMaxPct);
}

// true = marché considéré range/chop : bloquer une nouvelle entrée (sauf bypass spike ailleurs).
bool IsConsolidationOrChoppyRange() {
    if(!BlockConsolidationRange) return false;
    ENUM_TIMEFRAMES tf = Consolidation_TF;
    double er = ComputePriceEfficiencyRatio(tf, ConsolidationERLookback);
    bool lowEr = (er + 1e-9 <= ConsolidationERMax);
    if(!lowEr) return false;

    bool atrOk = true;
    double atrRatio = 1.0;
    if(ConsolidationUseATRCompress)
        atrOk = ConsolidationATRCompressed(tf, ConsolidationATRCompareBars, ConsolidationATRRatioMax, atrRatio);

    bool bbOk = true;
    double bbW = 999.0;
    if(ConsolidationUseBBWidth)
        bbOk = ConsolidationBBSqueeze(tf, ConsolidationBBPeriod, ConsolidationBBWidthMaxPct, bbW);

    if(ConsolidationUseATRCompress && ConsolidationUseBBWidth)
        return (atrOk || bbOk);
    if(ConsolidationUseATRCompress)
        return atrOk;
    if(ConsolidationUseBBWidth)
        return bbOk;
    return true;
}

string GetSymbolCategory(string symbol) {
    string upper = symbol;
    StringToUpper(upper);

    if(StringFind(upper, "BOOM") >= 0 || StringFind(upper, "CRASH") >= 0) {
        return "BOOM_CRASH";
    }

    if(StringFind(upper, "VOLATILITY") >= 0 || StringFind(upper, "STEP") >= 0 ||
       StringFind(upper, "JUMP") >= 0) {
        return "VOLATILITY";
    }

    if(StringFind(upper, "GOLD") >= 0 || StringFind(upper, "XAU") >= 0 ||
       StringFind(upper, "SILVER") >= 0 || StringFind(upper, "XAG") >= 0) {
        return "COMMODITIES";
    }

    if(StringFind(upper, "BTC") >= 0 || StringFind(upper, "ETH") >= 0) {
        return "CRYPTO";
    }

    // Détection Forex (6 caractères)
    if(StringLen(symbol) == 6) {
        return "FOREX";
    }

    return "OTHER";
}

bool IsDirectionAllowedForCurrentSymbol(string direction) {
    string upper = _Symbol;
    StringToUpper(upper);
    bool isBoom = (StringFind(upper, "BOOM") >= 0);
    bool isCrash = (StringFind(upper, "CRASH") >= 0);

    if(direction == "BUY" && isCrash) return false;
    if(direction == "SELL" && isBoom) return false;
    return true;
}

// Synthétiques type Boom500 / Crash1000 / GainX / PainX : pas de trailing SL, sortie privilégiée sur spike script.
bool IsBoomCrashStyleSymbol(const string symbol) {
    string u = symbol;
    StringToUpper(u);
    return (StringFind(u, "BOOM") >= 0 || StringFind(u, "CRASH") >= 0 ||
            StringFind(u, "GAINX") >= 0 || StringFind(u, "PAINX") >= 0);
}

double GetCategoryMinAIConfidence(string symbol) {
    string category = GetSymbolCategory(symbol);

    if(category == "BOOM_CRASH") {
        return 0.75; // 75%
    } else if(category == "VOLATILITY") {
        return 0.70; // 70%
    } else if(category == "FOREX") {
        return 0.65; // 65%
    } else {
        return 0.68; // 68%
    }
}

bool IsSpreadAcceptable() {
    long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    double spread_points = (double)spread; // SYMBOL_SPREAD est déjà exprimé en points
    
    // Seuils adaptatifs par catégorie (en points broker)
    double max_spread_points = 250.0;
    string cat = GetSymbolCategory(_Symbol);
    if(cat == "FOREX")        max_spread_points = 250.0;
    else if(cat == "COMMODITIES") max_spread_points = 400.0;   // ex: XAU, USOIL
    else if(cat == "CRYPTO")  max_spread_points = 1500.0;      // ex: BTC/ETH/BCH
    else if(cat == "BOOM_CRASH" || cat == "VOLATILITY") max_spread_points = 600.0;

    // Log pour debug
    Print("🔍 SPREAD: ", _Symbol, " spread=", spread, " points=", DoubleToString(spread_points, 1),
          " (max=", DoubleToString(max_spread_points, 0), ", cat=", cat, ")");

    return (spread_points <= max_spread_points);
}

bool IsEntryCooldownActive() {
    if(EntryCooldownSeconds <= 0) return false;

    datetime now = TimeCurrent();
    int elapsed = (int)(now - g_lastEntryTime);

    return (elapsed < EntryCooldownSeconds);
}

bool IsMaxPositionsReached() {
    return (PositionsTotal() >= MaxPositionsTerminal);
}

double ReadGlobalDouble(const string key, const double def_value = 0.0) {
    if(!GlobalVariableCheck(key)) return def_value;
    return GlobalVariableGet(key);
}

bool EA_IsBoomCrashLikeSymbol(const string sym) {
    string u = sym;
    StringToUpper(u);
    return (StringFind(u, "BOOM") >= 0 || StringFind(u, "CRASH") >= 0 ||
            StringFind(u, "GAINX") >= 0 || StringFind(u, "PAINX") >= 0);
}

// Aligné sur SMC_Universal.mq5 : distances broker + contrainte Bid/Ask pour éviter invalid stops.
void EA_ValidateAndAdjustStops(const string sym, const string direction, const double entryPrice,
                               double &stopLoss, double &takeProfit) {
    double point = SymbolInfoDouble(sym, SYMBOL_POINT);
    if(point <= 0) point = 0.0001;
    double tickSize = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
    if(tickSize <= 0) tickSize = point;

    double stopsLevel = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL) * point;
    double freezeLevel = (double)SymbolInfoInteger(sym, SYMBOL_TRADE_FREEZE_LEVEL) * point;

    double minDistance;
    if(StringFind(sym, "XAG") >= 0 || StringFind(sym, "XAU") >= 0)
        minDistance = MathMax(MathMax(stopsLevel, freezeLevel), 50 * tickSize);
    else if(EA_IsBoomCrashLikeSymbol(sym))
        minDistance = MathMax(MathMax(stopsLevel, freezeLevel), 80 * tickSize);
    else
        minDistance = MathMax(MathMax(stopsLevel, freezeLevel), 30 * tickSize);
    minDistance = MathMax(minDistance, 2.0 * tickSize);

    double bid = SymbolInfoDouble(sym, SYMBOL_BID);
    double ask = SymbolInfoDouble(sym, SYMBOL_ASK);

    if(direction == "BUY") {
        if(stopLoss >= entryPrice) stopLoss = entryPrice - minDistance;
        if(takeProfit <= entryPrice) takeProfit = entryPrice + (2.0 * minDistance);
        if(entryPrice - stopLoss < minDistance)
            stopLoss = entryPrice - minDistance;
        if(takeProfit - entryPrice < minDistance * 2)
            takeProfit = entryPrice + minDistance * 2;
        if(bid > 0.0) {
            if(bid - stopLoss < minDistance) stopLoss = bid - minDistance;
            if(takeProfit - bid < minDistance) takeProfit = bid + minDistance;
        }
        stopLoss = MathFloor(stopLoss / tickSize) * tickSize;
        takeProfit = MathCeil(takeProfit / tickSize) * tickSize;
    } else {
        if(stopLoss <= entryPrice) stopLoss = entryPrice + minDistance;
        if(takeProfit >= entryPrice) takeProfit = entryPrice - (2.0 * minDistance);
        if(stopLoss - entryPrice < minDistance)
            stopLoss = entryPrice + minDistance;
        if(entryPrice - takeProfit < minDistance * 2)
            takeProfit = entryPrice - minDistance * 2;
        if(ask > 0.0) {
            if(stopLoss - ask < minDistance) stopLoss = ask + minDistance;
            if(ask - takeProfit < minDistance) takeProfit = ask - minDistance;
        }
        stopLoss = MathCeil(stopLoss / tickSize) * tickSize;
        takeProfit = MathFloor(takeProfit / tickSize) * tickSize;
    }
    stopLoss = NormalizeDouble(stopLoss, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
    takeProfit = NormalizeDouble(takeProfit, (int)SymbolInfoInteger(sym, SYMBOL_DIGITS));
}

bool JsonBlkPickQuoted(const string blk, const string key, string &outVal) {
    if(blk == "") return false;
    string needle = "\"" + key + "\"";
    int p = StringFind(blk, needle);
    if(p < 0) return false;
    int colon = StringFind(blk, ":", p + StringLen(needle));
    if(colon < 0) return false;
    int q1 = StringFind(blk, "\"", colon + 1);
    if(q1 < 0) return false;
    q1++;
    int q2 = StringFind(blk, "\"", q1);
    if(q2 <= q1) return false;
    outVal = StringSubstr(blk, q1, q2 - q1);
    return true;
}

bool JsonBlkPickNumber(const string blk, const string key, double &outVal) {
    string needle = "\"" + key + "\"";
    int p = StringFind(blk, needle);
    if(p < 0) return false;
    int c = StringFind(blk, ":", p);
    if(c < 0) return false;
    c++;
    int len = StringLen(blk);
    while(c < len) {
        ushort ch = StringGetCharacter(blk, c);
        if(ch == ' ' || ch == '\t' || ch == '\r' || ch == '\n') {
            c++;
            continue;
        }
        break;
    }
    int e = StringFind(blk, ",", c);
    if(e < 0) e = StringFind(blk, "}", c);
    if(e < 0) e = len;
    string s = StringSubstr(blk, c, e - c);
    StringTrimLeft(s);
    StringTrimRight(s);
    outVal = StringToDouble(s);
    return true;
}

void ExtractAiServerChartPatternFromJson(const string json, AISignal &signal) {
    signal.chart_pattern_name = "";
    signal.chart_pattern_direction = "";
    signal.chart_pattern_score = 0.0;
    signal.chart_pattern_zone_low = 0.0;
    signal.chart_pattern_zone_high = 0.0;

    int taPos = StringFind(json, "\"technical_analysis\"");
    string scope = json;
    if(taPos >= 0) {
        int maxSlice = 12000;
        int rem = StringLen(json) - taPos;
        if(rem > maxSlice) rem = maxSlice;
        scope = StringSubstr(json, taPos, rem);
    }

    int cp = StringFind(scope, "\"chart_pattern\"");
    string blk = "";
    if(cp >= 0) {
        int ob = StringFind(scope, "{", cp);
        if(ob >= 0) {
            int depth = 0;
            int i = ob;
            int n = StringLen(scope);
            for(; i < n; i++) {
                ushort c = StringGetCharacter(scope, i);
                if(c == '{') depth++;
                else if(c == '}') {
                    depth--;
                    if(depth == 0) break;
                }
            }
            if(depth == 0)
                blk = StringSubstr(scope, ob, i - ob + 1);
        }
    }

    if(blk != "") {
        string pn = "";
        if(!JsonBlkPickQuoted(blk, "pattern_name", pn))
            JsonBlkPickQuoted(blk, "name", pn);
        if(pn != "") signal.chart_pattern_name = pn;

        string pdir = "";
        if(JsonBlkPickQuoted(blk, "direction", pdir)) {
            StringToUpper(pdir);
            StringTrimLeft(pdir);
            StringTrimRight(pdir);
            signal.chart_pattern_direction = pdir;
        }

        double sc = 0.0;
        if(JsonBlkPickNumber(blk, "score", sc)) {
            if(sc > 1.0) sc /= 100.0;
            if(sc < 0.0) sc = 0.0;
            if(sc > 1.0) sc = 1.0;
            signal.chart_pattern_score = sc;
        }

        double zl = 0.0, zh = 0.0;
        if(JsonBlkPickNumber(blk, "zone_low", zl)) signal.chart_pattern_zone_low = zl;
        if(JsonBlkPickNumber(blk, "zone_high", zh)) signal.chart_pattern_zone_high = zh;
    }

    if(signal.chart_pattern_name == "") {
        string topName = "";
        if(JsonBlkPickQuoted(json, "chart_pattern_name", topName))
            signal.chart_pattern_name = topName;
        string topDir = "";
        if(JsonBlkPickQuoted(json, "chart_pattern_direction", topDir)) {
            StringToUpper(topDir);
            signal.chart_pattern_direction = topDir;
        }
        double ts = 0.0;
        if(JsonBlkPickNumber(json, "chart_pattern_score", ts)) {
            if(ts > 1.0) ts /= 100.0;
            signal.chart_pattern_score = ts;
        }
        JsonBlkPickNumber(json, "chart_pattern_zone_low", signal.chart_pattern_zone_low);
        JsonBlkPickNumber(json, "chart_pattern_zone_high", signal.chart_pattern_zone_high);
    }
}

string SanitizeSymbolForObjectName(const string sym) {
    string o = sym;
    StringReplace(o, " ", "_");
    StringReplace(o, ".", "_");
    return o;
}

void DeleteAIServerPatternObjects() {
    string pref = "SMCEN_CP_" + SanitizeSymbolForObjectName(_Symbol) + "_";
    int total = ObjectsTotal(0);
    for(int i = total - 1; i >= 0; i--) {
        string nm = ObjectName(0, i);
        if(StringFind(nm, pref) == 0)
            ObjectDelete(0, nm);
    }
}

void DrawAIServerChartPatternOverlayM1() {
    if(!ShowAIServerPatternOnChart || !ShowChartGraphics) {
        DeleteAIServerPatternObjects();
        return;
    }
    string nm = g_lastAIAction.chart_pattern_name;
    StringToUpper(nm);
    StringTrimLeft(nm);
    StringTrimRight(nm);
    if(nm == "" || nm == "NONE" || nm == "NULL") {
        DeleteAIServerPatternObjects();
        return;
    }

    string pref = "SMCEN_CP_" + SanitizeSymbolForObjectName(_Symbol) + "_";
    DeleteAIServerPatternObjects();

    double zl = g_lastAIAction.chart_pattern_zone_low;
    double zh = g_lastAIAction.chart_pattern_zone_high;
    double ptZ = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(ptZ <= 0) ptZ = 0.0001;
    if(zl <= 0.0 || zh <= 0.0 || MathAbs(zh - zl) < ptZ * 3.0) {
        double atr = GetATRValue(PERIOD_M1, 14);
        double mid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(atr <= 0) atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 80.0;
        zl = mid - atr * 0.25;
        zh = mid + atr * 0.25;
    }
    if(zl > zh) {
        double t = zl;
        zl = zh;
        zh = t;
    }

    int nb = AIServerPatternZoneBarsM1;
    if(nb < 5) nb = 5;
    datetime tL = iTime(_Symbol, PERIOD_M1, nb);
    if(tL <= 0) tL = TimeCurrent() - (datetime)(nb * 60);
    datetime tR = TimeCurrent();

    string rectName = pref + "RECT";
    if(!ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, tL, zh, tR, zl)) {
        ObjectMove(0, rectName, 0, tL, zh);
        ObjectMove(0, rectName, 1, tR, zl);
    }
    ObjectSetInteger(0, rectName, OBJPROP_COLOR, AIServerPatternRectColor);
    ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
    ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
    ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);

    string pdir = g_lastAIAction.chart_pattern_direction;
    StringToUpper(pdir);
    double scDisp = g_lastAIAction.chart_pattern_score * 100.0;
    if(scDisp > 100.0) scDisp = 100.0;
    string txt = g_lastAIAction.chart_pattern_name + " " + pdir + " " + DoubleToString(scDisp, 0) + "%";
    string txtName = pref + "LBL";
    double midp = (zl + zh) * 0.5;
    if(!ObjectCreate(0, txtName, OBJ_TEXT, 0, tR, midp)) {
        ObjectMove(0, txtName, 0, tR, midp);
    }
    ObjectSetString(0, txtName, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, txtName, OBJPROP_COLOR, AIServerPatternTextColor);
    ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, txtName, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, txtName, OBJPROP_SELECTABLE, false);
    ChartRedraw(0);
}

string ScriptGVKey(const string suffix) {
    return "GOM_SCRIPT_" + _Symbol + "_" + suffix;
}

// === LECTURE DES NIVEAUX S/R MULTI-TIMEFRAMES ===
string SRGVKey(const string moduleTag, const string tfTag, const string sideTag) {
    return moduleTag + "_" + _Symbol + "_" + tfTag + "_" + sideTag;
}

void LoadSRLevels(SRLevels &levels, const string tfTag) {
    levels.timeframe = tfTag;
    levels.buy_level = ReadGlobalDouble(SRGVKey("GOM_KOLA", tfTag, "BUY"), 0.0);
    levels.sell_level = ReadGlobalDouble(SRGVKey("GOM_KOLA", tfTag, "SELL"), 0.0);
    levels.double_top = ReadGlobalDouble(SRGVKey("GOM_SIDO", tfTag, "DOUBLE_TOP"), 0.0);
    levels.double_bottom = ReadGlobalDouble(SRGVKey("GOM_SIDO", tfTag, "DOUBLE_BOTTOM"), 0.0);
}

void LoadAllSRLevels(SRLevelsMultiTF &srLevels) {
    srLevels.Reset();
    LoadSRLevels(srLevels.m1, "M1");
    LoadSRLevels(srLevels.m5, "M5");
    LoadSRLevels(srLevels.m15, "M15");
    LoadSRLevels(srLevels.m30, "M30");
    LoadSRLevels(srLevels.h1, "H1");
    LoadSRLevels(srLevels.h4, "H4");
    LoadSRLevels(srLevels.d1, "D1");
    LoadSRLevels(srLevels.w1, "W1");
}

// --- Lecture niveau KOLA : priorité OBJ_HLINE GOM_KOLA_BUY_M1 puis GV (même clé que le script) ---
bool GomGetKolaEntryLevel(const string sideUpper, const string tfTag, double &levelOut) {
    levelOut = 0.0;
    string nm = "GOM_KOLA_" + sideUpper + "_" + tfTag;
    if(ObjectFind(0, nm) >= 0) {
        double px = ObjectGetDouble(0, nm, OBJPROP_PRICE, 0);
        if(px > 0.0) {
            levelOut = px;
            return true;
        }
    }
    double gv = ReadGlobalDouble(SRGVKey("GOM_KOLA", tfTag, sideUpper), 0.0);
    if(gv > 0.0) {
        levelOut = gv;
        return true;
    }
    return false;
}

bool GomSidoFigurePresent(const string patternUpper, const string tfTag) {
    string lbl = "GOM_SIDO_" + patternUpper + "_" + tfTag + "_LBL";
    if(ObjectFind(0, lbl) >= 0) return true;
    return (ReadGlobalDouble(SRGVKey("GOM_SIDO", tfTag, patternUpper), 0.0) > 0.0);
}

bool GomSidoFigureAnyTf(const string patternUpper) {
    if(GomSidoFigurePresent(patternUpper, "M1")) return true;
    if(GomSidoFigurePresent(patternUpper, "M5")) return true;
    if(GomSidoFigurePresent(patternUpper, "M15")) return true;
    if(GomSidoFigurePresent(patternUpper, "M30")) return true;
    if(GomSidoFigurePresent(patternUpper, "H1")) return true;
    if(GomSidoFigurePresent(patternUpper, "H4")) return true;
    return false;
}

void GomIntelCollectActiveTfTags(string &tags[], int &n) {
    n = 0;
    ArrayResize(tags, 6);
    if(GomIntelTfM1) { tags[n] = "M1"; n++; }
    if(GomIntelTfM5) { tags[n] = "M5"; n++; }
    if(GomIntelTfM15) { tags[n] = "M15"; n++; }
    if(GomIntelTfM30) { tags[n] = "M30"; n++; }
    if(GomIntelTfH1) { tags[n] = "H1"; n++; }
    ArrayResize(tags, n);
}

bool GomChartIntelEntryGate(const string direction, const double price, const double atrM1,
                            const bool plainVerdictOnly, string &rejectReason) {
    rejectReason = "";
    if(!UseGomChartObjectIntel || !UseScriptVerdictSync) return true;
    if(price <= 0.0) return true;
    if(atrM1 <= 0.0) return true;

    string side = (direction == "BUY") ? "BUY" : "SELL";
    if(side != "BUY" && side != "SELL") return true;

    string tfTags[];
    int nTf = 0;
    GomIntelCollectActiveTfTags(tfTags, nTf);
    if(nTf <= 0) return true;

    int definedAny = 0;
    int nearHits = 0;
    const double maxDist = atrM1 * GomIntelNearKolaMaxATR;

    for(int i = 0; i < nTf; i++) {
        double lv = 0.0;
        if(!GomGetKolaEntryLevel(side, tfTags[i], lv)) continue;
        definedAny++;
        if(MathAbs(price - lv) <= maxDist) nearHits++;
    }

    if(definedAny == 0 && GomIntelSkipWhenNoLevels) return true;

    if(GomIntelRequireNearKolaLine) {
        int need = GomIntelMinKolaTfHits;
        if(need < 1) need = 1;
        if(definedAny > 0 && nearHits < need) {
            rejectReason = "prix hors zone KOLA (hits=" + IntegerToString(nearHits) + " besoin>=" + IntegerToString(need) +
                           " maxDistATR=" + DoubleToString(GomIntelNearKolaMaxATR, 2) + ")";
            return false;
        }
    }

    if(GomIntelPlainRequireSidoFigure && plainVerdictOnly) {
        if(direction == "BUY" && !GomSidoFigureAnyTf("DOUBLE_BOTTOM")) {
            rejectReason = "verdict simple BUY sans figure DOUBLE_BOTTOM (objet ou GV SIDO)";
            return false;
        }
        if(direction == "SELL" && !GomSidoFigureAnyTf("DOUBLE_TOP")) {
            rejectReason = "verdict simple SELL sans figure DOUBLE_TOP (objet ou GV SIDO)";
            return false;
        }
    }
    return true;
}

double GomMaxDoubleBottomBelowPrice(const SRLevelsMultiTF &sr, const double refPrice) {
    double best = 0.0;
    if(sr.m1.double_bottom > 0.0 && sr.m1.double_bottom < refPrice) best = MathMax(best, sr.m1.double_bottom);
    if(sr.m5.double_bottom > 0.0 && sr.m5.double_bottom < refPrice) best = MathMax(best, sr.m5.double_bottom);
    if(sr.m15.double_bottom > 0.0 && sr.m15.double_bottom < refPrice) best = MathMax(best, sr.m15.double_bottom);
    if(sr.m30.double_bottom > 0.0 && sr.m30.double_bottom < refPrice) best = MathMax(best, sr.m30.double_bottom);
    if(sr.h1.double_bottom > 0.0 && sr.h1.double_bottom < refPrice) best = MathMax(best, sr.h1.double_bottom);
    if(sr.h4.double_bottom > 0.0 && sr.h4.double_bottom < refPrice) best = MathMax(best, sr.h4.double_bottom);
    if(sr.d1.double_bottom > 0.0 && sr.d1.double_bottom < refPrice) best = MathMax(best, sr.d1.double_bottom);
    return best;
}

double GomMinDoubleTopAbovePrice(const SRLevelsMultiTF &sr, const double refPrice) {
    double best = 0.0;
    if(sr.m1.double_top > 0.0 && sr.m1.double_top > refPrice) {
        if(best <= 0.0) best = sr.m1.double_top; else best = MathMin(best, sr.m1.double_top);
    }
    if(sr.m5.double_top > 0.0 && sr.m5.double_top > refPrice) {
        if(best <= 0.0) best = sr.m5.double_top; else best = MathMin(best, sr.m5.double_top);
    }
    if(sr.m15.double_top > 0.0 && sr.m15.double_top > refPrice) {
        if(best <= 0.0) best = sr.m15.double_top; else best = MathMin(best, sr.m15.double_top);
    }
    if(sr.m30.double_top > 0.0 && sr.m30.double_top > refPrice) {
        if(best <= 0.0) best = sr.m30.double_top; else best = MathMin(best, sr.m30.double_top);
    }
    if(sr.h1.double_top > 0.0 && sr.h1.double_top > refPrice) {
        if(best <= 0.0) best = sr.h1.double_top; else best = MathMin(best, sr.h1.double_top);
    }
    if(sr.h4.double_top > 0.0 && sr.h4.double_top > refPrice) {
        if(best <= 0.0) best = sr.h4.double_top; else best = MathMin(best, sr.h4.double_top);
    }
    if(sr.d1.double_top > 0.0 && sr.d1.double_top > refPrice) {
        if(best <= 0.0) best = sr.d1.double_top; else best = MathMin(best, sr.d1.double_top);
    }
    return best;
}

void GomIntelRefineSLFromSido(const string direction, const double refPrice, const SRLevelsMultiTF &sr,
                              const double atrM1, double &sl) {
    if(!UseGomChartObjectIntel || !GomIntelWidenSLToSidoStructure || atrM1 <= 0.0) return;
    if(refPrice <= 0.0) return;
    const double buf = atrM1 * GomIntelSidoSlBufferATR;

    if(direction == "BUY") {
        double neck = GomMaxDoubleBottomBelowPrice(sr, refPrice);
        if(neck > 0.0) {
            double cap = neck - buf;
            if(sl > cap) sl = cap;
        }
    } else if(direction == "SELL") {
        double neck = GomMinDoubleTopAbovePrice(sr, refPrice);
        if(neck > 0.0) {
            double cap = neck + buf;
            if(sl < cap) sl = cap;
        }
    }
}

// === DÉTECTION DE CORRECTION VS TENDANCE ===
bool IsPriceNearSRLevel(double price, double level, double atr, double tolerancePercent = 0.3) {
    if(level <= 0.0) return false;
    double distance = MathAbs(price - level);
    double threshold = atr * tolerancePercent;
    return (distance <= threshold);
}

// Détecter si le mouvement est une correction (contre la tendance multi-timeframe)
bool IsCorrectionMove(string direction, double currentPrice, const SRLevelsMultiTF &srLevels, double atr) {
    // Compter les S/R alignés contre la direction
    int againstCount = 0;
    int totalCount = 0;
    
    // Vérifier les timeframes supérieurs (H1, H4, D1, W1) pour la tendance principale
    if(srLevels.h1.buy_level > 0.0 || srLevels.h1.sell_level > 0.0) {
        totalCount++;
        if(direction == "BUY" && IsPriceNearSRLevel(currentPrice, srLevels.h1.sell_level, atr, 0.4)) againstCount++;
        if(direction == "SELL" && IsPriceNearSRLevel(currentPrice, srLevels.h1.buy_level, atr, 0.4)) againstCount++;
    }
    if(srLevels.h4.buy_level > 0.0 || srLevels.h4.sell_level > 0.0) {
        totalCount++;
        if(direction == "BUY" && IsPriceNearSRLevel(currentPrice, srLevels.h4.sell_level, atr, 0.4)) againstCount++;
        if(direction == "SELL" && IsPriceNearSRLevel(currentPrice, srLevels.h4.buy_level, atr, 0.4)) againstCount++;
    }
    if(srLevels.d1.buy_level > 0.0 || srLevels.d1.sell_level > 0.0) {
        totalCount++;
        if(direction == "BUY" && IsPriceNearSRLevel(currentPrice, srLevels.d1.sell_level, atr, 0.4)) againstCount++;
        if(direction == "SELL" && IsPriceNearSRLevel(currentPrice, srLevels.d1.buy_level, atr, 0.4)) againstCount++;
    }
    
    // Si plus de 50% des S/R sont contre, c'est une correction
    if(totalCount > 0 && againstCount >= totalCount / 2) {
        return true;
    }
    
    return false;
}

// Trouver le meilleur entry point basé sur les S/R multi-timeframes
double FindOptimalEntry(string direction, double currentPrice, const SRLevelsMultiTF &srLevels, double atr) {
    double optimalEntry = currentPrice;
    double bestScore = 0.0;
    
    // Chercher le meilleur S/R aligné avec la direction
    SRLevels tfLevels[5];
    tfLevels[0].buy_level = srLevels.m1.buy_level;
    tfLevels[0].sell_level = srLevels.m1.sell_level;
    tfLevels[1].buy_level = srLevels.m5.buy_level;
    tfLevels[1].sell_level = srLevels.m5.sell_level;
    tfLevels[2].buy_level = srLevels.m15.buy_level;
    tfLevels[2].sell_level = srLevels.m15.sell_level;
    tfLevels[3].buy_level = srLevels.m30.buy_level;
    tfLevels[3].sell_level = srLevels.m30.sell_level;
    tfLevels[4].buy_level = srLevels.h1.buy_level;
    tfLevels[4].sell_level = srLevels.h1.sell_level;
    
    for(int i = 0; i < 5; i++) {
        double level = (direction == "BUY") ? tfLevels[i].buy_level : tfLevels[i].sell_level;
        if(level <= 0.0) continue;
        
        double distance = MathAbs(currentPrice - level);
        double atrDistance = distance / atr;
        
        // Score: proche du prix mais pas trop, aligné avec la direction
        double score = 0.0;
        if(atrDistance >= 0.1 && atrDistance <= 0.8) {
            score = 1.0 - atrDistance; // Plus proche = meilleur score
            score *= (i + 1) * 0.2; // Poids pour les timeframes supérieurs
        }
        
        if(score > bestScore) {
            bestScore = score;
            optimalEntry = level;
        }
    }
    
    // Si aucun bon S/R trouvé, utiliser le prix actuel
    if(bestScore < 0.3) {
        optimalEntry = currentPrice;
    }
    
    return optimalEntry;
}

// Calculer un TP intelligent basé sur les S/R
double CalculateSmartTP(string direction, double entryPrice, const SRLevelsMultiTF &srLevels, double defaultTP) {
    double nearestTP = defaultTP;
    double minDistance = DBL_MAX;
    double atr = GetATRValue(PERIOD_M1, 14);
    
    // Vérifier chaque timeframe individuellement
    SRLevels tfLevels[4];
    tfLevels[0].buy_level = srLevels.m15.buy_level;
    tfLevels[0].sell_level = srLevels.m15.sell_level;
    tfLevels[1].buy_level = srLevels.m30.buy_level;
    tfLevels[1].sell_level = srLevels.m30.sell_level;
    tfLevels[2].buy_level = srLevels.h1.buy_level;
    tfLevels[2].sell_level = srLevels.h1.sell_level;
    tfLevels[3].buy_level = srLevels.h4.buy_level;
    tfLevels[3].sell_level = srLevels.h4.sell_level;
    
    for(int i = 0; i < 4; i++) {
        double level = (direction == "BUY") ? tfLevels[i].sell_level : tfLevels[i].buy_level;
        if(level <= 0.0) continue;
        
        double distance = MathAbs(level - entryPrice);
        
        // Vérifier que le TP est raisonnable (pas trop proche, pas trop loin)
        double atrDistance = distance / atr;
        
        if(atrDistance >= 0.5 && atrDistance <= 3.0 && distance < minDistance) {
            minDistance = distance;
            nearestTP = level;
        }
    }
    
    return nearestTP;
}

struct ScriptVerdictData {
    bool is_available;
    string direction;  // BUY / SELL / WAIT
    double verdict_num;
    double buy_entry;
    double sell_entry;
    double stop_loss;
    double tp1;
    double tp2;
    double tp3;
    double tech_buy_score;
    double tech_sell_score;
    double verdict_strength;
    double filter_quality;
};

void LoadScriptVerdictData(ScriptVerdictData &data) {
    data.is_available = false;
    data.direction = "WAIT";
    data.verdict_num = ReadGlobalDouble(ScriptGVKey("VERDICT_NUM"), 0.0);
    data.buy_entry = ReadGlobalDouble(ScriptGVKey("BUY_ENTRY"), 0.0);
    data.sell_entry = ReadGlobalDouble(ScriptGVKey("SELL_ENTRY"), 0.0);
    data.stop_loss = ReadGlobalDouble(ScriptGVKey("SL"), 0.0);
    data.tp1 = ReadGlobalDouble(ScriptGVKey("TP1"), 0.0);
    data.tp2 = ReadGlobalDouble(ScriptGVKey("TP2"), 0.0);
    data.tp3 = ReadGlobalDouble(ScriptGVKey("TP3"), 0.0);
    data.tech_buy_score = ReadGlobalDouble(ScriptGVKey("TECH_BUY_SCORE"), 0.0);
    data.tech_sell_score = ReadGlobalDouble(ScriptGVKey("TECH_SELL_SCORE"), 0.0);
    data.verdict_strength = ReadGlobalDouble(ScriptGVKey("VERDICT_STRENGTH"), 0.0);
    data.filter_quality = ReadGlobalDouble(ScriptGVKey("FILTER_QUALITY"), 0.0);

    if(data.verdict_num > 0.0 || data.buy_entry > 0.0) {
        data.direction = "BUY";
        data.is_available = true;
        return;
    }
    if(data.verdict_num < 0.0 || data.sell_entry > 0.0) {
        data.direction = "SELL";
        data.is_available = true;
        return;
    }
}

// Normalise un libellé de recommandation Ollama (ou texte voisin) vers BUY / SELL / HOLD.
string NormalizeOllamaSide(const string recIn)
{
    string rec = recIn;
    StringToUpper(rec);
    StringTrimLeft(rec);
    StringTrimRight(rec);
    if(rec == "" || rec == "NONE" || rec == "WAIT" || rec == "NEUTRAL") return "HOLD";
    if(rec == "LONG" || rec == "ACHAT") return "BUY";
    if(rec == "SHORT" || rec == "VENTE") return "SELL";
    bool has_buy = (StringFind(rec, "BUY") >= 0);
    bool has_sell = (StringFind(rec, "SELL") >= 0);
    if(has_buy && !has_sell) return "BUY";
    if(has_sell && !has_buy) return "SELL";
    return "HOLD";
}

void PublishRobotServerDecisionGlobals()
{
    // Confiance POST /decision (ai_server) — visible sur le dash GOM même si UseScriptVerdictSync (sync n’appelle pas GetSignal).
    string base = "SMC_UNIVERSAL_" + _Symbol + "_";
    if(!UseAIServer) {
        GlobalVariableSet(base + "SERVER_AI_CONF", 0.0);
        GlobalVariableSet(base + "SERVER_AI_ACTION_NUM", 0.0);
        GlobalVariableSet(base + "SERVER_AI_VALID", 0.0);
        GlobalVariableSet(base + "SERVER_AI_LAST_TS", 0.0);
        return;
    }
    double cf = g_lastAIAction.confidence;
    if(cf > 1.0) cf /= 100.0;
    if(cf < 0.0) cf = 0.0;
    if(cf > 1.0) cf = 1.0;
    double act = 0.0;
    if(g_lastAIAction.direction == "BUY") act = 1.0;
    else if(g_lastAIAction.direction == "SELL") act = -1.0;
    GlobalVariableSet(base + "SERVER_AI_CONF", cf);
    GlobalVariableSet(base + "SERVER_AI_ACTION_NUM", act);
    GlobalVariableSet(base + "SERVER_AI_VALID", g_lastAIAction.is_valid ? 1.0 : 0.0);
    GlobalVariableSet(base + "SERVER_AI_LAST_TS", (double)g_lastAIUpdateTime);

    double cpScGv = g_lastAIAction.chart_pattern_score;
    if(cpScGv > 0.0 && cpScGv <= 1.0) cpScGv *= 100.0;
    double cpDirGv = 0.0;
    string cpSd = g_lastAIAction.chart_pattern_direction;
    StringToUpper(cpSd);
    if(cpSd == "BUY" || cpSd == "BULL" || cpSd == "LONG" || cpSd == "BULLISH") cpDirGv = 1.0;
    else if(cpSd == "SELL" || cpSd == "BEAR" || cpSd == "SHORT" || cpSd == "BEARISH") cpDirGv = -1.0;
    GlobalVariableSet(base + "CHART_PATTERN_SCORE", cpScGv);
    GlobalVariableSet(base + "CHART_PATTERN_DIR_NUM", cpDirGv);
    GlobalVariableSet(base + "CHART_PATTERN_ZONE_LO", g_lastAIAction.chart_pattern_zone_low);
    GlobalVariableSet(base + "CHART_PATTERN_ZONE_HI", g_lastAIAction.chart_pattern_zone_high);
}

void PublishRobotOllamaGlobals()
{
    string base = "SMC_UNIVERSAL_" + _Symbol + "_";
    string side = NormalizeOllamaSide(g_lastOllamaAnalysis.recommendation);
    double action_num = 0.0;
    if(side == "BUY") action_num = 1.0;
    else if(side == "SELL") action_num = -1.0;

    double conf = g_lastOllamaAnalysis.confidence;
    if(conf > 1.0) conf /= 100.0;
    if(conf < 0.0) conf = 0.0;
    if(conf > 1.0) conf = 1.0;

    double sentiment_num = 0.0;
    if(g_lastOllamaAnalysis.sentiment == "BULLISH") sentiment_num = 1.0;
    else if(g_lastOllamaAnalysis.sentiment == "BEARISH") sentiment_num = -1.0;

    datetime ts_o = g_lastOllamaAnalysis.timestamp;
    if(ts_o <= 0) ts_o = TimeCurrent();

    GlobalVariableSet(base + "OLLAMA_ACTION_NUM", action_num);
    GlobalVariableSet(base + "OLLAMA_CONF", conf);
    GlobalVariableSet(base + "OLLAMA_VALID", g_lastOllamaAnalysis.is_valid ? 1.0 : 0.0);
    GlobalVariableSet(base + "OLLAMA_LAST_TS", (double)TimeCurrent());
    GlobalVariableSet(base + "OLLAMA_ANALYSIS_TS", (double)ts_o);
    GlobalVariableSet(base + "OLLAMA_SENTIMENT_NUM", sentiment_num);
}

void NotifyTradingAgentsAnalysis() {
    if(!PushTradingAgentsSummary || !EnablePushNotifications) return;
    if(!TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED)) return;
    if(!g_lastTradingAgentsAnalysis.is_valid) return;
    if(g_lastTradingAgentsAnalysis.reasoning == "") return;

    string sig = g_lastTradingAgentsAnalysis.recommendation + "|" +
                 DoubleToString(g_lastTradingAgentsAnalysis.confidence * 100.0, 0) + "|" +
                 g_lastTradingAgentsAnalysis.reasoning;
    if(sig == g_lastTradingAgentsSummary) return;
    g_lastTradingAgentsSummary = sig;

    string msg = "🧭 TradingAgents " + _Symbol +
                 "\nReco=" + g_lastTradingAgentsAnalysis.recommendation +
                 " (" + DoubleToString(g_lastTradingAgentsAnalysis.confidence * 100.0, 0) + "%)" +
                 "\n" + g_lastTradingAgentsAnalysis.reasoning;
    SendNotification(msg);
}

void UpdateTradingAgentsAnalysis() {
    datetime now = TimeCurrent();
    if((now - g_lastTradingAgentsUpdateTime) < TradingAgentsUpdateIntervalSeconds) return;

    g_lastTradingAgentsUpdateTime = now;
    if(!EnableTradingAgentsRemoteAnalysis || g_aiConnector == NULL) return;

    TradingAgentsAnalysis ta = g_aiConnector.GetTradingAgentsAnalysis(_Symbol);
    if(!ta.is_valid) return;
    g_lastTradingAgentsAnalysis = ta;
    NotifyTradingAgentsAnalysis();
    Print("🧭 TRADINGAGENTS: ", ta.recommendation, " conf=", DoubleToString(ta.confidence * 100.0, 1),
          "% | ", ta.reasoning);
}

double ComputeOpportunityCostScore(const ScriptVerdictData &script_data,
                                   const string direction,
                                   const double entry_price,
                                   const double sl,
                                   const double tp) {
    double score = 0.0;
    double fq = script_data.filter_quality;
    if(fq > 1.0) fq /= 100.0;
    if(fq < 0.0) fq = 0.0;
    if(fq > 1.0) fq = 1.0;
    score += fq * 35.0;

    double vAbs = MathAbs(script_data.verdict_num);
    double verdictScore = MathMin(1.0, vAbs / 3.0);
    score += verdictScore * 25.0;

    double rr = 0.0;
    if(entry_price > 0.0 && sl > 0.0 && tp > 0.0) {
        double risk = MathAbs(entry_price - sl);
        double reward = MathAbs(tp - entry_price);
        if(risk > 1e-9) rr = reward / risk;
    }
    double rrNorm = MathMin(1.0, rr / 3.0);
    score += rrNorm * 20.0;

    if(g_lastAIAction.is_valid && g_lastAIAction.confidence >= MinAIConfidence) {
        if(g_lastAIAction.direction == direction) score += 10.0;
        else if(g_lastAIAction.direction == "HOLD") score += 4.0;
    }

    if(g_lastTradingAgentsAnalysis.is_valid && g_lastTradingAgentsAnalysis.confidence >= TradingAgentsMinConfidenceInfluence) {
        if(g_lastTradingAgentsAnalysis.recommendation == direction) score += 10.0;
        else if(g_lastTradingAgentsAnalysis.recommendation == "HOLD") score += 4.0;
    }

    if(score < 0.0) score = 0.0;
    if(score > 100.0) score = 100.0;
    return score;
}

string VerdictLabelFromNum(const double verdict_num) {
    if(verdict_num >= 3.0) return "PERFECT BUY";
    if(verdict_num >= 2.0) return "GOOD BUY";
    if(verdict_num >= 1.0) return "BUY";
    if(verdict_num <= -3.0) return "PERFECT SELL";
    if(verdict_num <= -2.0) return "GOOD SELL";
    if(verdict_num <= -1.0) return "SELL";
    return "WAIT";
}

void PushSignalNotification(const ScriptVerdictData &data, const string direction,
                           const double entry_price = 0.0, const double sl = 0.0, const double tp = 0.0,
                           const bool is_opportunity = false) {
    if(!EnablePushNotifications) return;
    if(!TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED)) return;

    datetime now = TimeCurrent();
    if((now - g_lastNotifyTime) < 3 && !is_opportunity) return;

    bool changed = (MathAbs(data.verdict_num - g_lastNotifiedVerdictNum) > 0.001 || direction != g_lastNotifiedDirection);
    if(!changed && !is_opportunity) return;

    string oppKey = direction + "|" + DoubleToString(data.verdict_num, 2) + "|" + DoubleToString(entry_price, _Digits);
    if(is_opportunity) {
        if(oppKey == g_lastOpportunityKey && (now - g_lastOpportunityNotifyTime) < 45) return;
    }

    string verdict_label = VerdictLabelFromNum(data.verdict_num);
    double fq_push = data.filter_quality;
    if(fq_push > 1.0) fq_push /= 100.0;
    string filt_line = "FILTRE_Q=" + DoubleToString(fq_push * 100.0, 0) + "%";
    double spread_pts = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    double rr = 0.0;
    if(entry_price > 0.0 && sl > 0.0 && tp > 0.0) {
        double risk = MathAbs(entry_price - sl);
        double reward = MathAbs(tp - entry_price);
        if(risk > 0.0) rr = reward / risk;
    }
    string prefix = is_opportunity ? "OPPORTUNITE ORDRE" : "STATUT SIGNAL";
    string msg = prefix + " | " + _Symbol +
                 "\nVerdict=" + verdict_label + " | Dir=" + direction +
                 "\nForce=" + DoubleToString(data.verdict_strength, 2) +
                 " | Tech B/S=" + DoubleToString(data.tech_buy_score, 2) + "/" + DoubleToString(data.tech_sell_score, 2) +
                 "\n" + filt_line +
                 "\nEntry=" + DoubleToString(entry_price, _Digits) +
                 " | SL=" + DoubleToString(sl, _Digits) + " | TP1=" + DoubleToString(tp, _Digits) +
                 " | RR=" + DoubleToString(rr, 2) +
                 "\nSpread=" + DoubleToString(spread_pts, 0) + " pts";
    SendNotification(msg);
    g_lastNotifiedVerdictNum = data.verdict_num;
    g_lastNotifiedDirection = direction;
    g_lastNotifyTime = now;
    if(is_opportunity) {
        g_lastOpportunityKey = oppKey;
        g_lastOpportunityNotifyTime = now;
    }
}

//+------------------------------------------------------------------+
//| SECTION 12: FONCTIONS DE TRADING                                  |
//+------------------------------------------------------------------+

double CalculateLotSize() {
    if(UseMinLotOnly) {
        return SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    }

    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double atr = GetATRValue(PERIOD_M1, 14);

    if(atr <= 0) return InpLotSize;

    double sl_distance = atr * SL_ATRMult;
    if(account_balance <= 0.0) return InpLotSize;
    double risk_percent = (MaxLossPerTradeDollars / account_balance) * 100.0;
    double lot_size = g_riskManager.CalculateOptimalLotSize(account_balance, risk_percent, sl_distance);

    return lot_size;
}

void CalculateStopLossTakeProfit(string direction, double entry_price,
                                  double &stop_loss, double &take_profit) {
    double atr = GetATRValue(PERIOD_M1, 14);

    if(atr <= 0) {
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        atr = point * 100.0;
    }

    double sl_distance = atr * SL_ATRMult;
    double tp_distance = atr * TP_ATRMult;

    if(direction == "BUY") {
        stop_loss = entry_price - sl_distance;
        take_profit = entry_price + tp_distance;
    } else {
        stop_loss = entry_price + sl_distance;
        take_profit = entry_price - tp_distance;
    }

    // Normaliser
    stop_loss = NormalizeDouble(stop_loss, _Digits);
    take_profit = NormalizeDouble(take_profit, _Digits);
}

bool ExecuteTrade(string direction, double lot, double sl, double tp, string comment) {
    Print("🔍 EXECUTE_TRADE: Début - Dir=", direction, " Lot=", lot, " SL=", sl, " TP=", tp);
    
    if(!EnableTrading) {
        Print("⛔ TRADING: Trading désactivé");
        return false;
    }

    if(!g_riskManager.CanOpenPosition(_Symbol, lot)) {
        Print("⛔ TRADING: RiskManager refuse la position");
        return false;
    }

    if(!IsSpreadAcceptable()) {
        Print("⛔ TRADING: Spread trop élevé");
        return false;
    }

    if(IsEntryCooldownActive()) {
        Print("⛔ TRADING: Cooldown actif");
        return false;
    }

    if(IsMaxPositionsReached()) {
        Print("⛔ TRADING: Limite de positions atteinte");
        return false;
    }

    if(!IsDirectionAllowedForCurrentSymbol(direction)) {
        Print("⛔ TRADING: Direction interdite pour symbole ", _Symbol, " (", direction, ")");
        return false;
    }

    double slAdj = sl;
    double tpAdj = tp;
    double mktRef = (direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    EA_ValidateAndAdjustStops(_Symbol, direction, mktRef, slAdj, tpAdj);
    if(MathAbs(slAdj - sl) > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 0.5 ||
       MathAbs(tpAdj - tp) > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 0.5) {
        Print("🔧 STOPS: Ajustement broker — SL ", DoubleToString(sl, _Digits), " → ", DoubleToString(slAdj, _Digits),
              " | TP ", DoubleToString(tp, _Digits), " → ", DoubleToString(tpAdj, _Digits),
              " (ref ", DoubleToString(mktRef, _Digits), ")");
    }
    
    Print("✅ EXECUTE_TRADE: Toutes validations passées, envoi ordre");

    bool result = false;

    if(direction == "BUY") {
        result = trade.Buy(lot, _Symbol, 0.0, slAdj, tpAdj, comment);
    } else if(direction == "SELL") {
        result = trade.Sell(lot, _Symbol, 0.0, slAdj, tpAdj, comment);
    }

    if(result) {
        g_lastEntryTime = TimeCurrent();
        g_dailyTradeCount++;
        Print("✅ TRADING: Ordre ", direction, " exécuté sur ", _Symbol,
              " (lot: ", DoubleToString(lot, 2), ", SL: ", DoubleToString(slAdj, _Digits),
              ", TP: ", DoubleToString(tpAdj, _Digits), ")");
    } else {
        Print("❌ TRADING: Échec ordre ", direction, " - ", trade.ResultComment());
    }

    return result;
}

bool ClosePosition(ulong ticket, string reason) {
    // Guard: bloquer fermeture si position trop récente
    if(BlockEarlyClose) {
        if(PositionSelectByTicket(ticket)) {
            datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
            int age_seconds = (int)(TimeCurrent() - open_time);

            if(age_seconds < MinHoldSecondsAfterEntry) {
                Print("⛔ CLOSE: Fermeture bloquée - position âgée de ", age_seconds, "s < ",
                      MinHoldSecondsAfterEntry, "s");
                return false;
            }
        }
    }

    // Anti-doublon de fermeture
    datetime now = TimeCurrent();
    for(int i = 0; i < 16; i++) {
        if(g_lastCloseTickets[i] == ticket &&
           g_lastCloseTimes[i] > 0 &&
           (now - g_lastCloseTimes[i]) <= 3) {
            Print("⏭️ CLOSE: Skip duplicate close (cooldown)");
            return true;
        }
    }

    // Exécuter la fermeture
    bool result = trade.PositionClose(ticket);

    // Enregistrer dans l'historique
    g_lastCloseTickets[g_lastCloseIdx] = ticket;
    g_lastCloseTimes[g_lastCloseIdx] = now;
    g_lastCloseIdx = (g_lastCloseIdx + 1) % 16;

    if(result) {
        g_lastCloseTime = now;
        Print("✅ CLOSE: Position fermée - ", reason);
    } else {
        Print("❌ CLOSE: Échec fermeture - ", trade.ResultComment());
    }

    return result;
}

//+------------------------------------------------------------------+
//| SECTION 13: GESTION DU TRAILING STOP                              |
//+------------------------------------------------------------------+

void ManageTrailingStop() {
    if(BoomCrashNoTrailingStop && IsBoomCrashStyleSymbol(_Symbol)) return;

    const bool trailMandatory = !IsBoomCrashStyleSymbol(_Symbol);
    if(!trailMandatory && !UseTrailingStop) return;

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(!PositionSelectByTicket(PositionGetTicket(i))) continue;

        string symbol = PositionGetString(POSITION_SYMBOL);
        if(symbol != _Symbol) continue;
        if(BoomCrashNoTrailingStop && IsBoomCrashStyleSymbol(symbol)) continue;

        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
        double sl = PositionGetDouble(POSITION_SL);
        double tp = PositionGetDouble(POSITION_TP);
        ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        double profit = PositionGetDouble(POSITION_PROFIT);

        // Vérifier si le profit minimum est atteint
        if(profit < TrailingStartProfitDollars) continue;

        double atr = GetATRValue(PERIOD_M1, 14);
        if(atr <= 0) continue;

        double trail_distance = atr * TrailingStop_ATRMult;
        double new_sl = 0.0;

        if(type == POSITION_TYPE_BUY) {
            new_sl = current_price - trail_distance;

            // Ne déplacer le SL que s'il est plus haut
            if(new_sl > sl && new_sl > open_price) {
                trade.PositionModify(PositionGetTicket(i), new_sl, tp);
                Print("📈 TRAIL: SL BUY déplacé à ", DoubleToString(new_sl, _Digits));
            }
        } else if(type == POSITION_TYPE_SELL) {
            new_sl = current_price + trail_distance;

            // Ne déplacer le SL que s'il est plus bas
            if(new_sl < sl && new_sl < open_price) {
                trade.PositionModify(PositionGetTicket(i), new_sl, tp);
                Print("📉 TRAIL: SL SELL déplacé à ", DoubleToString(new_sl, _Digits));
            }
        }
    }
}

bool ShouldCloseBoomCrashOnScriptSpike(const string symbol, const ENUM_POSITION_TYPE ptype) {
    if(!BoomCrashCloseOnScriptSpike) return false;
    if(!IsBoomCrashStyleSymbol(symbol)) return false;
    double sp = ReadGlobalDouble(ScriptGVKey("SPIKE_PROB"), 0.0);
    double sd = ReadGlobalDouble(ScriptGVKey("SPIKE_DIR_NUM"), 0.0);
    if(sp + 1e-9 < BoomCrashSpikeCloseMinProb) return false;
    if(ptype == POSITION_TYPE_BUY && sd > 0.5) return true;
    if(ptype == POSITION_TYPE_SELL && sd < -0.5) return true;
    return false;
}

//+------------------------------------------------------------------+
//| SECTION 14: FONCTIONS D'AFFICHAGE                                 |
//+------------------------------------------------------------------+

void UpdateDashboard() {
    if(!ShowDashboard) return;

    string dashboard = "=== TRADBOT DASHBOARD ===\n";
    dashboard += "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n";
    dashboard += "Equity: $" + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2) + "\n";
    dashboard += "Profit jour: $" + DoubleToString(g_dailyProfit, 2) + "\n";
    dashboard += "Perte jour: $" + DoubleToString(g_dailyLoss, 2) + "\n";
    dashboard += "Drawdown: " + DoubleToString(g_riskManager.GetCurrentDrawdown(), 1) + "%\n";
    dashboard += "Positions: " + IntegerToString(PositionsTotal()) + "/" +
                  IntegerToString(MaxPositionsTerminal) + "\n";
    dashboard += "Trades jour: " + IntegerToString(g_dailyTradeCount) + "\n";
    if(EnableTenDollarProfitPause && TenDollarPauseBlocksNewEntries()) {
        int rem = (int)(g_tenDollarPauseUntil - TimeCurrent());
        if(rem < 0) rem = 0;
        dashboard += "PAUSE PROFIT: " + IntegerToString(rem / 3600) + "h" +
                     IntegerToString((rem % 3600) / 60) + "m (seuil $" +
                     DoubleToString(TenDollarProfitThreshold, 0) + ")\n";
    }

    if(g_lastOllamaAnalysis.is_valid) {
        string d_side = NormalizeOllamaSide(g_lastOllamaAnalysis.recommendation);
        double d_conf = g_lastOllamaAnalysis.confidence;
        if(d_conf > 1.0) d_conf /= 100.0;
        dashboard += "OLLAMA: " + d_side +
                     " (" + DoubleToString(d_conf * 100, 1) + "%) " +
                     g_lastOllamaAnalysis.sentiment + "\n";
        string o_note = g_lastOllamaAnalysis.summary;
        if(StringLen(o_note) > 90) o_note = StringSubstr(o_note, 0, 90) + "...";
        dashboard += "OLLAMA_NOTE: " + o_note + "\n";
    }

    if(g_lastTradingAgentsAnalysis.is_valid) {
        string ta_note = g_lastTradingAgentsAnalysis.reasoning;
        if(StringLen(ta_note) > 90) ta_note = StringSubstr(ta_note, 0, 90) + "...";
        dashboard += "TRADINGAGENTS: " + g_lastTradingAgentsAnalysis.recommendation +
                     " (" + DoubleToString(g_lastTradingAgentsAnalysis.confidence * 100.0, 1) + "%)\n";
        dashboard += "TA_NOTE: " + ta_note + "\n";
    }
    if(EnableOpportunityCostFilter) {
        dashboard += "OPP_SCORE: " + DoubleToString(g_lastOpportunityCostScore, 1) + "/100" +
                     " | DevATR=" + DoubleToString(g_lastOpportunityPriceDevATR, 2) + "\n";
    }

    // Afficher sur le graphique
    string label = "DASHBOARD";
    if(ObjectFind(0, label) < 0) {
        ObjectCreate(0, label, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, label, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, label, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, label, OBJPROP_YDISTANCE, 20);
        ObjectSetInteger(0, label, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
        ObjectSetString(0, label, OBJPROP_FONT, "Courier New");
    }

    ObjectSetString(0, label, OBJPROP_TEXT, dashboard);
}

void DrawSignalArrow() {
    if(!ShowSignalArrow) return;

    string arrow_name = "SIGNAL_ARROW";

    ScriptVerdictData sd;
    LoadScriptVerdictData(sd);
    string arr_side = UseScriptVerdictSync ? sd.direction : g_lastAIAction.direction;
    if(arr_side != "BUY" && arr_side != "SELL") arr_side = "HOLD";

    if(arr_side == "BUY") {
        if(ObjectFind(0, arrow_name) < 0) {
            ObjectCreate(0, arrow_name, OBJ_ARROW, 0, TimeCurrent(),
                        SymbolInfoDouble(_Symbol, SYMBOL_BID));
        }
        ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrLime);
        ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, 233);
        ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
    } else if(arr_side == "SELL") {
        if(ObjectFind(0, arrow_name) < 0) {
            ObjectCreate(0, arrow_name, OBJ_ARROW, 0, TimeCurrent(),
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK));
        }
        ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, 234);
        ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 3);
    } else {
        ObjectDelete(0, arrow_name);
    }
}

//+------------------------------------------------------------------+
//| AFFICHAGE OLLAMA (LLM local) sur le graphique                     |
//+------------------------------------------------------------------+

void DisplayOllamaAnalysis() {
    if(!EnableOllamaRemoteAnalysis) {
        ObjectDelete(0, "OLLAMA_SUMMARY");
        ObjectDelete(0, "OLLAMA_REASON");
        ObjectDelete(0, "OLLAMA_LEVELS");
        ObjectDelete(0, "OLLAMA_LAT");
        ObjectDelete(0, "OLLAMA_SUPPORT");
        ObjectDelete(0, "OLLAMA_RESISTANCE");
        return;
    }
    if(!g_lastOllamaAnalysis.is_valid) {
        // Afficher un statut explicite au lieu de ne rien afficher
        string labelMainWait = "OLLAMA_SUMMARY";
        if(ObjectFind(0, labelMainWait) < 0) {
            ObjectCreate(0, labelMainWait, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, labelMainWait, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
            ObjectSetInteger(0, labelMainWait, OBJPROP_XDISTANCE, 10);
            ObjectSetInteger(0, labelMainWait, OBJPROP_YDISTANCE, 20);
            ObjectSetInteger(0, labelMainWait, OBJPROP_FONTSIZE, 11);
            ObjectSetString(0, labelMainWait, OBJPROP_FONT, "Segoe UI");
        }
        ObjectSetString(0, labelMainWait, OBJPROP_TEXT, "🧠 OLLAMA/QWEN: en attente ou indisponible");
        ObjectSetInteger(0, labelMainWait, OBJPROP_COLOR, clrDimGray);

        string labelDetailWait = "OLLAMA_REASON";
        if(ObjectFind(0, labelDetailWait) < 0) {
            ObjectCreate(0, labelDetailWait, OBJ_LABEL, 0, 0, 0);
            ObjectSetInteger(0, labelDetailWait, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
            ObjectSetInteger(0, labelDetailWait, OBJPROP_XDISTANCE, 10);
            ObjectSetInteger(0, labelDetailWait, OBJPROP_YDISTANCE, 45);
            ObjectSetInteger(0, labelDetailWait, OBJPROP_FONTSIZE, 9);
            ObjectSetString(0, labelDetailWait, OBJPROP_FONT, "Segoe UI");
        }
        ObjectSetString(0, labelDetailWait, OBJPROP_TEXT, "Aucune analyse valide recue jusqu'ici.");
        ObjectSetInteger(0, labelDetailWait, OBJPROP_COLOR, clrGray);
        return;
    }

    // Couleur selon sentiment
    color sentimentColor = clrDarkGray;
    if(g_lastOllamaAnalysis.sentiment == "BULLISH") sentimentColor = clrLimeGreen;
    else if(g_lastOllamaAnalysis.sentiment == "BEARISH") sentimentColor = clrCrimson;
    else if(g_lastOllamaAnalysis.sentiment == "NEUTRAL") sentimentColor = clrGold;

    // Label principal: résumé + sentiment
    string labelMain = "OLLAMA_SUMMARY";
    if(ObjectFind(0, labelMain) < 0) {
        ObjectCreate(0, labelMain, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelMain, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, labelMain, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, labelMain, OBJPROP_YDISTANCE, 20);
        ObjectSetInteger(0, labelMain, OBJPROP_FONTSIZE, 11);
        ObjectSetString(0, labelMain, OBJPROP_FONT, "Segoe UI");
    }
    string summaryText = "🧠 OLLAMA: " + g_lastOllamaAnalysis.sentiment +
                         " | " + g_lastOllamaAnalysis.recommendation +
                         " (" + DoubleToString(g_lastOllamaAnalysis.confidence * 100, 0) + "%)";
    ObjectSetString(0, labelMain, OBJPROP_TEXT, summaryText);
    ObjectSetInteger(0, labelMain, OBJPROP_COLOR, sentimentColor);

    // Label détails: reasoning
    string labelDetail = "OLLAMA_REASON";
    if(ObjectFind(0, labelDetail) < 0) {
        ObjectCreate(0, labelDetail, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelDetail, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, labelDetail, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, labelDetail, OBJPROP_YDISTANCE, 45);
        ObjectSetInteger(0, labelDetail, OBJPROP_FONTSIZE, 9);
        ObjectSetString(0, labelDetail, OBJPROP_FONT, "Segoe UI");
    }
    string reasonText = g_lastOllamaAnalysis.reasoning;
    if(StringLen(reasonText) > 80) reasonText = StringSubstr(reasonText, 0, 80) + "...";
    ObjectSetString(0, labelDetail, OBJPROP_TEXT, reasonText);
    ObjectSetInteger(0, labelDetail, OBJPROP_COLOR, clrLightGray);

    // Label niveaux clés
    string labelLevels = "OLLAMA_LEVELS";
    if(ObjectFind(0, labelLevels) < 0) {
        ObjectCreate(0, labelLevels, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelLevels, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, labelLevels, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, labelLevels, OBJPROP_YDISTANCE, 65);
        ObjectSetInteger(0, labelLevels, OBJPROP_FONTSIZE, 8);
        ObjectSetString(0, labelLevels, OBJPROP_FONT, "Courier New");
    }
    string levelsText = "";
    if(g_lastOllamaAnalysis.key_support > 0.0)
        levelsText += "S=" + DoubleToString(g_lastOllamaAnalysis.key_support, _Digits) + "  ";
    if(g_lastOllamaAnalysis.key_resistance > 0.0)
        levelsText += "R=" + DoubleToString(g_lastOllamaAnalysis.key_resistance, _Digits) + "  ";
    if(g_lastOllamaAnalysis.risk_reward > 0.0)
        levelsText += "RR=" + DoubleToString(g_lastOllamaAnalysis.risk_reward, 1);
    if(levelsText == "") levelsText = "Niveaux: N/A";
    ObjectSetString(0, labelLevels, OBJPROP_TEXT, levelsText);
    ObjectSetInteger(0, labelLevels, OBJPROP_COLOR, clrSilver);

    // Label latence
    string labelLat = "OLLAMA_LAT";
    if(ObjectFind(0, labelLat) < 0) {
        ObjectCreate(0, labelLat, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, labelLat, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
        ObjectSetInteger(0, labelLat, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, labelLat, OBJPROP_YDISTANCE, 82);
        ObjectSetInteger(0, labelLat, OBJPROP_FONTSIZE, 7);
        ObjectSetString(0, labelLat, OBJPROP_FONT, "Courier New");
    }
    ObjectSetString(0, labelLat, OBJPROP_TEXT,
                    "lat=" + DoubleToString(g_lastOllamaAnalysis.latency_ms, 0) + "ms");
    ObjectSetInteger(0, labelLat, OBJPROP_COLOR, clrDimGray);

    // Lignes horizontales pour support/résistance si valides
    if(g_lastOllamaAnalysis.key_support > 0.0) {
        string objS = "OLLAMA_SUPPORT";
        if(ObjectFind(0, objS) < 0)
            ObjectCreate(0, objS, OBJ_HLINE, 0, 0, g_lastOllamaAnalysis.key_support);
        else
            ObjectSetDouble(0, objS, OBJPROP_PRICE, g_lastOllamaAnalysis.key_support);
        ObjectSetInteger(0, objS, OBJPROP_COLOR, clrForestGreen);
        ObjectSetInteger(0, objS, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, objS, OBJPROP_WIDTH, 1);
    }
    if(g_lastOllamaAnalysis.key_resistance > 0.0) {
        string objR = "OLLAMA_RESISTANCE";
        if(ObjectFind(0, objR) < 0)
            ObjectCreate(0, objR, OBJ_HLINE, 0, 0, g_lastOllamaAnalysis.key_resistance);
        else
            ObjectSetDouble(0, objR, OBJPROP_PRICE, g_lastOllamaAnalysis.key_resistance);
        ObjectSetInteger(0, objR, OBJPROP_COLOR, clrFireBrick);
        ObjectSetInteger(0, objR, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, objR, OBJPROP_WIDTH, 1);
    }
}

void NotifyOllamaAnalysis() {
    if(!g_lastOllamaAnalysis.is_valid) return;
    if(g_lastOllamaAnalysis.summary == "") return;

    // Anti-doublon: ne pas notifier si le summary est identique au précédent
    if(g_lastOllamaAnalysis.summary == g_ollamaLastSummary) return;
    g_ollamaLastSummary = g_lastOllamaAnalysis.summary;

    // Construire le message de notification
    string emoji = "⚪";
    if(g_lastOllamaAnalysis.sentiment == "BULLISH") emoji = "🟢";
    else if(g_lastOllamaAnalysis.sentiment == "BEARISH") emoji = "🔴";

    string notifTitle = emoji + " OLLAMA " + _Symbol + " " + g_lastOllamaAnalysis.timeframe;
    string notifBody = g_lastOllamaAnalysis.recommendation +
                       " (conf " + DoubleToString(g_lastOllamaAnalysis.confidence * 100, 0) + "%)\n" +
                       g_lastOllamaAnalysis.summary;

    // Envoyer notification push MT5
    SendNotification(notifTitle + "\n" + notifBody);

    // Log
    Print("🧠 OLLAMA NOTIF: ", notifTitle, " | ", notifBody);
}

//+------------------------------------------------------------------+
//| SECTION 15: FONCTIONS PRINCIPALES                                 |
//+------------------------------------------------------------------+

void UpdateAIDecision() {
    datetime now = TimeCurrent();

    // Vérifier si une mise à jour est nécessaire
    if((now - g_lastAIUpdateTime) < AI_UpdateInterval_Seconds) {
        return;
    }

    if(!UseAIServer) {
        g_lastAIAction.Reset();
        g_lastAIAction.reasoning = "IA désactivée";
        g_lastAIAction.server_status = "DISABLED";
        PublishRobotServerDecisionGlobals();
        DrawAIServerChartPatternOverlayM1();
        return;
    }

    if(g_aiConnector == NULL) {
        PublishRobotServerDecisionGlobals();
        DrawAIServerChartPatternOverlayM1();
        return;
    }

    // Obtenir le signal IA
    Print("🔍 UPDATE_AI: Récupération signal pour ", _Symbol);
    g_lastAIAction = g_aiConnector.GetSignal(_Symbol, PERIOD_M5);
    g_lastAIUpdateTime = now;
    Print("🔍 UPDATE_AI: Résultat - Dir=", g_lastAIAction.direction, 
          " Conf=", DoubleToString(g_lastAIAction.confidence * 100, 1), "%",
          " Valid=", g_lastAIAction.is_valid ? "OUI" : "NON",
          " Reason=", g_lastAIAction.reasoning);
    PublishRobotServerDecisionGlobals();
    DrawAIServerChartPatternOverlayM1();
}

void UpdateOllamaAnalysis() {
    datetime now = TimeCurrent();

    // Vérifier si une mise à jour est nécessaire (toutes les 5 minutes)
    if((now - g_lastOllamaUpdateTime) < g_ollamaUpdateInterval) {
        return;
    }

    if(!EnableOllamaRemoteAnalysis) {
        g_lastOllamaUpdateTime = now;
        return;
    }

    if(!UseAIServer || g_aiConnector == NULL) {
        return;
    }

    Print("🧠 OLLAMA: Mise à jour analyse pour ", _Symbol);

    // Récupérer les indicateurs techniques
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double rsi = GetRSIValue(PERIOD_M1, 14);
    double atr = GetATRValue(PERIOD_M1, 14);

    // EMAs
    double ema_f_m1 = 0.0, ema_s_m1 = 0.0;
    double ema_f_m5 = 0.0, ema_s_m5 = 0.0;
    double ema_f_h1 = 0.0, ema_s_h1 = 0.0;

    int h9m1 = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
    int h21m1 = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
    int h9m5 = iMA(_Symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
    int h21m5 = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
    int h9h1 = iMA(_Symbol, PERIOD_H1, 9, 0, MODE_EMA, PRICE_CLOSE);
    int h21h1 = iMA(_Symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);

    double tmp[];
    ArraySetAsSeries(tmp, true);
    if(h9m1 != INVALID_HANDLE && CopyBuffer(h9m1, 0, 0, 1, tmp) >= 1) ema_f_m1 = tmp[0];
    if(h21m1 != INVALID_HANDLE && CopyBuffer(h21m1, 0, 0, 1, tmp) >= 1) ema_s_m1 = tmp[0];
    if(h9m5 != INVALID_HANDLE && CopyBuffer(h9m5, 0, 0, 1, tmp) >= 1) ema_f_m5 = tmp[0];
    if(h21m5 != INVALID_HANDLE && CopyBuffer(h21m5, 0, 0, 1, tmp) >= 1) ema_s_m5 = tmp[0];
    if(h9h1 != INVALID_HANDLE && CopyBuffer(h9h1, 0, 0, 1, tmp) >= 1) ema_f_h1 = tmp[0];
    if(h21h1 != INVALID_HANDLE && CopyBuffer(h21h1, 0, 0, 1, tmp) >= 1) ema_s_h1 = tmp[0];

    if(h9m1 != INVALID_HANDLE) IndicatorRelease(h9m1);
    if(h21m1 != INVALID_HANDLE) IndicatorRelease(h21m1);
    if(h9m5 != INVALID_HANDLE) IndicatorRelease(h9m5);
    if(h21m5 != INVALID_HANDLE) IndicatorRelease(h21m5);
    if(h9h1 != INVALID_HANDLE) IndicatorRelease(h9h1);
    if(h21h1 != INVALID_HANDLE) IndicatorRelease(h21h1);

    // Entry points GOM KOLA
    double m1_buy = ReadGlobalDouble("GOM_KOLA_" + _Symbol + "_M1_BUY", 0.0);
    double m1_sell = ReadGlobalDouble("GOM_KOLA_" + _Symbol + "_M1_SELL", 0.0);
    double m5_buy = ReadGlobalDouble("GOM_KOLA_" + _Symbol + "_M5_BUY", 0.0);
    double m5_sell = ReadGlobalDouble("GOM_KOLA_" + _Symbol + "_M5_SELL", 0.0);
    double m15_buy = ReadGlobalDouble("GOM_KOLA_" + _Symbol + "_M15_BUY", 0.0);
    double m15_sell = ReadGlobalDouble("GOM_KOLA_" + _Symbol + "_M15_SELL", 0.0);
    double h1_buy = ReadGlobalDouble("GOM_KOLA_" + _Symbol + "_H1_BUY", 0.0);
    double h1_sell = ReadGlobalDouble("GOM_KOLA_" + _Symbol + "_H1_SELL", 0.0);

    // Appeler l'analyse Ollama
    g_lastOllamaAnalysis = g_aiConnector.GetOllamaAnalysis(
        _Symbol, PERIOD_M5,
        bid, ask, rsi,
        ema_f_m1, ema_s_m1,
        ema_f_m5, ema_s_m5,
        ema_f_h1, ema_s_h1,
        atr,
        m1_buy, m1_sell,
        m5_buy, m5_sell,
        m15_buy, m15_sell,
        h1_buy, h1_sell
    );

    g_lastOllamaUpdateTime = now;
    PublishRobotOllamaGlobals();

    Print("🧠 OLLAMA: Analyse reçue - ", g_lastOllamaAnalysis.sentiment,
          " | ", g_lastOllamaAnalysis.recommendation,
          " | Conf=", DoubleToString(g_lastOllamaAnalysis.confidence * 100, 1), "%");

    // Afficher et notifier
    DisplayOllamaAnalysis();
    NotifyOllamaAnalysis();
}

bool ValidateTradingConditions(string direction) {
    // Vérifier la confiance IA
    double min_conf = GetCategoryMinAIConfidence(_Symbol);
    if(g_lastAIAction.confidence < min_conf) {
        Print("⛔ VALIDATION: Confiance IA insuffisante (",
              DoubleToString(g_lastAIAction.confidence * 100, 1), "% < ",
              DoubleToString(min_conf * 100, 1), "%)");
        return false;
    }

    // Vérifier l'alignement direction
    if(g_lastAIAction.direction != direction && g_lastAIAction.direction != "HOLD") {
        Print("⛔ VALIDATION: Direction IA non alignée (IA: ", g_lastAIAction.direction,
              ", demandé: ", direction, ")");
        return false;
    }

    // Vérifier l'alignement multi-timeframe
    if(g_mtfAnalyzer != NULL) {
        if(!g_mtfAnalyzer.ValidateSignal(_Symbol, direction, MtfMinStrengthPercent)) {
            Print("⛔ VALIDATION: Multi-timeframe non aligné (seuil ",
                  DoubleToString(MtfMinStrengthPercent, 0), "%)");
            return false;
        }
    }

    return true;
}

void CheckAndExecuteTrades() {
    if(!EnableTrading) return;
    if(TenDollarPauseBlocksNewEntries()) return;

    // Décision trading: uniquement le verdict script (pas d'IA serveur / Ollama).
    if(!UseScriptVerdictSync)
        UpdateAIDecision();

    ScriptVerdictData script_data;
    LoadScriptVerdictData(script_data);
    double script_spike_prob = ReadGlobalDouble(ScriptGVKey("SPIKE_PROB"), 0.0);
    double script_spike_dir_num = ReadGlobalDouble(ScriptGVKey("SPIKE_DIR_NUM"), 0.0);

    string final_direction = UseScriptVerdictSync ? script_data.direction : g_lastAIAction.direction;
    bool use_script_plan = UseScriptVerdictSync;

    if(UseScriptVerdictSync) {
        if(!script_data.is_available || script_data.direction == "WAIT") {
            return;
        }
        final_direction = script_data.direction;
    }

    // Vérifier si un signal de trading est présent
    if(final_direction == "HOLD" || final_direction == "WAIT") return;

    // Influence TradingAgents: blocage des contradictions fortes
    if(EnableTradingAgentsRemoteAnalysis && TradingAgentsBlockContradiction &&
       g_lastTradingAgentsAnalysis.is_valid &&
       g_lastTradingAgentsAnalysis.confidence + 1e-9 >= TradingAgentsMinConfidenceInfluence) {
        bool ta_contradict =
            (final_direction == "BUY" && g_lastTradingAgentsAnalysis.recommendation == "SELL") ||
            (final_direction == "SELL" && g_lastTradingAgentsAnalysis.recommendation == "BUY");
        if(ta_contradict) {
            Print("⛔ TRADINGAGENTS: Trade bloqué (contradiction ",
                  g_lastTradingAgentsAnalysis.recommendation, " vs ", final_direction,
                  ", conf=", DoubleToString(g_lastTradingAgentsAnalysis.confidence * 100.0, 1), "%)");
            return;
        }
    }

    double fTotalEa = ReadGlobalDouble(ScriptGVKey("FILTER_TOTAL"), 0.0);
    double fPassEa = ReadGlobalDouble(ScriptGVKey("FILTER_PASS_COUNT"), 0.0);
    double passRatioEa = (fTotalEa > 0.5) ? (fPassEa / fTotalEa) : 1.0;
    double fqEa = script_data.filter_quality;
    if(fqEa > 1.0) fqEa /= 100.0;
    bool goodOrPerfectEa = MathAbs(script_data.verdict_num) >= 2.0;
    bool plainVerdictOnly = (MathAbs(script_data.verdict_num) >= 1.0 && MathAbs(script_data.verdict_num) < 2.0);

    double spikeProbNeed = goodOrPerfectEa ? MinSpikeProbGoodPerfect : MinSpikeProbPlainBypass;
    bool script_spike_opportunity =
        (script_spike_prob >= spikeProbNeed &&
         ((final_direction == "BUY" && script_spike_dir_num > 0.5) ||
          (final_direction == "SELL" && script_spike_dir_num < -0.5)));
    const bool spike_skips_range_mtf = (SpikeBypassSkipsRangeAndMtf && script_spike_opportunity);

    bool useAndFilters = (ReduceFalseSignals && PlainVerdictRequireAndFilters);
    bool filtersExceedThird = useAndFilters
        ? ((passRatioEa + 1e-9 >= MinFilterRatioForPlainVerdict) && (fqEa + 1e-9 >= MinFilterRatioForPlainVerdict))
        : ((passRatioEa + 1e-9 >= MinFilterRatioForPlainVerdict) || (fqEa + 1e-9 >= MinFilterRatioForPlainVerdict));

    if(UseScriptVerdictSync && TradeOnlyGoodPerfect) {
        // Aucun contournement spike : entrées uniquement si verdict final GOOD ou PERFECT (aligné VerdictLabelFromNum : |num| ≥ 2).
        if(MathAbs(script_data.verdict_num) < 2.0) {
            static datetime s_lastVerdictGateLog = 0;
            datetime tv = TimeCurrent();
            if(tv - s_lastVerdictGateLog >= 30) {
                Print("⛔ SYNC: Entrée refusée — GOOD ou PERFECT requis (actuel ",
                      VerdictLabelFromNum(script_data.verdict_num),
                      ", num=", DoubleToString(script_data.verdict_num, 2), ")");
                s_lastVerdictGateLog = tv;
            }
            return;
        }
    } else if(UseScriptVerdictSync) {
        if(MathAbs(script_data.verdict_num) < 1.0) return;
        if(!goodOrPerfectEa && !script_spike_opportunity && !filtersExceedThird) {
            Print("⛔ SYNC: BUY/SELL script bloqué — filtres insuffisants (ratio ",
                  DoubleToString(passRatioEa * 100.0, 1), "%, qualité ",
                  DoubleToString(fqEa * 100.0, 1), "%", useAndFilters ? ", mode ET" : ", mode OU", ")");
            return;
        }
    }

    if(UseScriptVerdictSync && ReduceFalseSignals && plainVerdictOnly && !script_spike_opportunity) {
        if(fTotalEa < 1.0) {
            Print("⛔ ANTI-FAUX: Pas de métriques filtres script (FILTER_TOTAL) — entrée refusée");
            return;
        }
        if(fTotalEa >= 2.0) {
            int nTot = (int)(fTotalEa + 0.001);
            int needPasses = MinFilterPassesForPlain;
            if(nTot < needPasses) needPasses = MathMax(1, nTot);
            if(fPassEa + 1e-9 < needPasses) {
                Print("⛔ ANTI-FAUX: Trop peu de filtres OK (", DoubleToString(fPassEa, 0), "/",
                      DoubleToString(fTotalEa, 0), ", min ", IntegerToString(needPasses), ")");
                return;
            }
        }
        if(script_data.verdict_strength + 1e-9 < MinVerdictStrengthForPlain) {
            Print("⛔ ANTI-FAUX: Force verdict script trop faible (",
                  DoubleToString(script_data.verdict_strength, 2), " < ",
                  DoubleToString(MinVerdictStrengthForPlain, 2), ")");
            return;
        }
    }

    if(BlockIfServerAiContradicts && UseScriptVerdictSync && UseAIServer) {
        string srvBase = "SMC_UNIVERSAL_" + _Symbol + "_";
        double srvAct = ReadGlobalDouble(srvBase + "SERVER_AI_ACTION_NUM", 0.0);
        double srvCf = ReadGlobalDouble(srvBase + "SERVER_AI_CONF", 0.0);
        if(srvCf > 1.0) srvCf /= 100.0;
        bool contradicts =
            (final_direction == "BUY" && srvAct < -0.5) ||
            (final_direction == "SELL" && srvAct > 0.5);
        if(contradicts && srvCf + 1e-9 >= ServerAiContradictMinConf) {
            Print("⛔ ANTI-FAUX: Serveur /decision contredit le sens (action=", DoubleToString(srvAct, 0),
                  " conf=", DoubleToString(srvCf * 100.0, 0), "%)");
            return;
        }
    }
    if(UseScriptVerdictSync && EnforceExtraMinFilterQualityInEA) {
        double fqEnforce = script_data.filter_quality;
        if(fqEnforce > 1.0) fqEnforce /= 100.0;
        if(fqEnforce > 0.0 && fqEnforce + 1e-9 < MinScriptFilterQuality) {
            Print("⛔ SYNC: Qualité filtres script insuffisante (extra EA, ",
                  DoubleToString(fqEnforce * 100.0, 0), "% < ",
                  DoubleToString(MinScriptFilterQuality * 100.0, 0), "%)");
            return;
        }
    }

    // Éviter entrées en plein range / consolidation (spike ne contourne que si SpikeBypassSkipsRangeAndMtf).
    if(BlockConsolidationRange && !spike_skips_range_mtf && IsConsolidationOrChoppyRange()) {
        static datetime s_lastRangeLog = 0;
        datetime tn = TimeCurrent();
        if(tn - s_lastRangeLog >= 45) {
            double er = ComputePriceEfficiencyRatio(Consolidation_TF, ConsolidationERLookback);
            Print("⛔ ANTI-RANGE: Entrée refusée — chop / consolidation (ER=", DoubleToString(er, 3),
                  " ≤ ", DoubleToString(ConsolidationERMax, 3),
                  ", TF=", EnumToString(Consolidation_TF),
                  " | ATR+BB selon inputs)");
            s_lastRangeLog = tn;
        }
        return;
    }

    // Direction structurelle M5+M15+H1 : obligatoire en sync script ; spike contourne MTF seulement si SpikeBypassSkipsRangeAndMtf.
    if(UseScriptVerdictSync && EnforceMtfTrendForScriptSync && g_mtfAnalyzer != NULL && !spike_skips_range_mtf) {
        bool plainVerdict = (MathAbs(script_data.verdict_num) >= 1.0 && MathAbs(script_data.verdict_num) < 2.0);
        bool needUnanimous = (plainVerdict && MtfUnanimousForPlainVerdict);
        bool mtfOk = needUnanimous
                       ? g_mtfAnalyzer.ValidateUnanimousTrend(_Symbol, final_direction)
                       : g_mtfAnalyzer.ValidateSignal(_Symbol, final_direction, MtfMinStrengthPercent);
        if(!mtfOk) {
            static datetime s_lastMtfBlockLog = 0;
            datetime tm = TimeCurrent();
            if(tm - s_lastMtfBlockLog >= 40) {
                string mode = needUnanimous ? "unanime M5+M15+H1" : ("majorité ≥" + DoubleToString(MtfMinStrengthPercent, 0) + "%");
                Print("⛔ MTF STRUCTURE: Direction ", final_direction, " refusée (", mode,
                      ", verdict=", DoubleToString(script_data.verdict_num, 2), ") — EMA 9/21");
                s_lastMtfBlockLog = tm;
            }
            return;
        }
    }

    // Charger les niveaux S/R multi-timeframes pour une analyse intelligente
    SRLevelsMultiTF srLevels;
    LoadAllSRLevels(srLevels);
    
    double currentPrice = (final_direction == "BUY") ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double atr = GetATRValue(PERIOD_M1, 14);

    string gomIntelRej = "";
    if(!GomChartIntelEntryGate(final_direction, currentPrice, atr, plainVerdictOnly, gomIntelRej)) {
        static datetime s_gomIntelLog = 0;
        datetime tgi = TimeCurrent();
        if(tgi - s_gomIntelLog >= 30) {
            Print("⛔ GOM-INTEL: Entrée refusée — ", gomIntelRej);
            s_gomIntelLog = tgi;
        }
        return;
    }
    
    Print("🔍 EXEC: Direction=", final_direction, " Prix=", currentPrice, " ATR=", atr);
    Print("🔍 EXEC: Script entry BUY=", script_data.buy_entry, " SELL=", script_data.sell_entry);
    Print("🔍 EXEC: Script SL=", script_data.stop_loss, " TP1=", script_data.tp1);
    
    // Éviter de trader les corrections (contre la tendance multi-timeframe), sauf si le script a déjà tranché.
    if(!(UseScriptVerdictSync && SkipCorrectionFilterWhenScriptSync) &&
       IsCorrectionMove(final_direction, currentPrice, srLevels, atr)) {
        Print("⛔ S/R: Mouvement détecté comme CORRECTION contre S/R multi-timeframes => skip trade");
        return;
    }
    
    Print("✅ EXEC: Passé le filtre correction, prêt pour exécution");

    // En mode IA pur (sans sync script), appliquer les validations IA existantes.
    if(!UseScriptVerdictSync) {
        if(!ValidateTradingConditions(final_direction)) return;
    }

    // Calculer les paramètres de trade
    double lot = CalculateLotSize();
    double entry_price = (final_direction == "BUY") ?
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK) :
                        SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double sl, tp;
    
    // Pour le scalping: utiliser systématiquement les entry points et TP du script quand verdict est BUY/SELL/GOOD/PERFECT
    if(use_script_plan) {
        // Priorité 1: Utiliser l'entry point du script si disponible
        if(final_direction == "BUY" && script_data.buy_entry > 0.0) {
            entry_price = script_data.buy_entry;
        } else if(final_direction == "SELL" && script_data.sell_entry > 0.0) {
            entry_price = script_data.sell_entry;
        } else {
            // Priorité 2: Utiliser l'entry point optimal basé sur les S/R multi-timeframes
            double optimalEntry = FindOptimalEntry(final_direction, currentPrice, srLevels, atr);
            if(optimalEntry != currentPrice) {
                entry_price = optimalEntry;
                Print("✅ S/R: Entry optimal basé sur S/R multi-timeframes - Entry=", entry_price);
            }
        }
        
        // Utiliser SL/TP du script pour le scalping
        if(script_data.stop_loss > 0.0 && script_data.tp1 > 0.0) {
            sl = script_data.stop_loss;
            tp = script_data.tp1;
            Print("✅ SCALPING: Utilisation niveaux script - Entry=", entry_price, " SL=", sl, " TP1=", tp);
        } else {
            CalculateStopLossTakeProfit(final_direction, entry_price, sl, tp);
        }
        
        // Améliorer le TP avec les S/R multi-timeframes si possible
        if(script_data.tp1 > 0.0) {
            double smartTP = CalculateSmartTP(final_direction, entry_price, srLevels, script_data.tp1);
            if(smartTP != script_data.tp1) {
                tp = smartTP;
                Print("✅ S/R: TP intelligent ajusté basé sur S/R multi-timeframes - TP=", tp);
            }
        }
    } else if(g_lastAIAction.entry_price > 0.0 && 
              g_lastAIAction.stop_loss > 0.0 && 
              g_lastAIAction.take_profit > 0.0) {
        // Mode IA pur: utiliser les instructions de l'AI server si disponibles
        entry_price = g_lastAIAction.entry_price;
        sl = g_lastAIAction.stop_loss;
        tp = g_lastAIAction.take_profit;
        Print("✅ IA: Utilisation instructions serveur - Entry=", entry_price, " SL=", sl, " TP=", tp);
    } else {
        // Mode IA sans instructions: utiliser les S/R multi-timeframes
        double optimalEntry = FindOptimalEntry(final_direction, currentPrice, srLevels, atr);
        if(optimalEntry != currentPrice) {
            entry_price = optimalEntry;
            Print("✅ S/R: Entry optimal basé sur S/R multi-timeframes - Entry=", entry_price);
        }
        CalculateStopLossTakeProfit(final_direction, entry_price, sl, tp);
        double smartTP = CalculateSmartTP(final_direction, entry_price, srLevels, tp);
        if(smartTP != tp) {
            tp = smartTP;
            Print("✅ S/R: TP intelligent ajusté basé sur S/R multi-timeframes - TP=", tp);
        }
    }

    double mktExecRef = (final_direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(use_script_plan && script_data.stop_loss > 0.0 && script_data.tp1 > 0.0 && ResyncScriptStopsIfEntryDriftPoints > 0) {
        double ptDr = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        if(ptDr > 0.0) {
            double refE = 0.0;
            if(final_direction == "BUY" && script_data.buy_entry > 0.0) refE = script_data.buy_entry;
            else if(final_direction == "SELL" && script_data.sell_entry > 0.0) refE = script_data.sell_entry;
            if(refE > 0.0 && MathAbs(mktExecRef - refE) >= (double)ResyncScriptStopsIfEntryDriftPoints * ptDr) {
                Print("⚠️ SL/TP: entrée script éloignée du marché — recalcul ATR (marché=", DoubleToString(mktExecRef, _Digits),
                      " script=", DoubleToString(refE, _Digits), ")");
                CalculateStopLossTakeProfit(final_direction, mktExecRef, sl, tp);
            }
        }
    }
    GomIntelRefineSLFromSido(final_direction, mktExecRef, srLevels, atr, sl);
    EA_ValidateAndAdjustStops(_Symbol, final_direction, mktExecRef, sl, tp);

    if(UseScriptVerdictSync) {
        bool opportunity = (MathAbs(script_data.verdict_num) >= 2.0 && (final_direction == "BUY" || final_direction == "SELL"));
        PushSignalNotification(script_data, final_direction, entry_price, sl, tp, opportunity);
    }

    // Coût d'opportunité: privilégier la qualité plutôt que le volume
    if(EnableOpportunityCostFilter) {
        double oppScore = ComputeOpportunityCostScore(script_data, final_direction, entry_price, sl, tp);
        g_lastOpportunityCostScore = oppScore;

        if(oppScore + 1e-9 < OpportunityCostMinScore || oppScore - 1e-9 > OpportunityCostMaxScore) {
            Print("⛔ OPP-COST: score hors intervalle [",
                  DoubleToString(OpportunityCostMinScore, 1), ", ",
                  DoubleToString(OpportunityCostMaxScore, 1), "] (score=",
                  DoubleToString(oppScore, 1), ")");
            return;
        }

        double atrGate = GetATRValue(PERIOD_M1, 14);
        if(atrGate > 1e-9 && entry_price > 0.0) {
            double market_ref = (final_direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double devAtr = MathAbs(market_ref - entry_price) / atrGate;
            g_lastOpportunityPriceDevATR = devAtr;
            if(devAtr + 1e-9 < OpportunityPriceDevMinATR || devAtr - 1e-9 > OpportunityPriceDevMaxATR) {
                Print("⛔ OPP-COST: distance prix/entrée hors intervalle ATR [",
                      DoubleToString(OpportunityPriceDevMinATR, 2), ", ",
                      DoubleToString(OpportunityPriceDevMaxATR, 2), "] (dev=",
                      DoubleToString(devAtr, 2), ")");
                return;
            }
        }
    }

    // Exécuter le trade
    Print("🚀 EXEC: TENTATIVE EXECUTION - Dir=", final_direction, " Lot=", lot, " Entry=", entry_price, " SL=", sl, " TP=", tp);
    double fq = script_data.filter_quality;
    if(fq > 1.0) fq /= 100.0;
    string comment = (use_script_plan ? "SCRIPT_" : "AI_") + final_direction + "_FQ" +
                    DoubleToString(fq * 100.0, 0) + "%";
    ExecuteTrade(final_direction, lot, sl, tp, comment);
}

void CheckAndClosePositions() {
    ScriptVerdictData script_data;
    LoadScriptVerdictData(script_data);
    bool force_wait_close = (UseScriptVerdictSync && (!script_data.is_available || script_data.direction == "WAIT" || MathAbs(script_data.verdict_num) < 0.5));

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        if(!PositionSelectByTicket(PositionGetTicket(i))) continue;

        string symbol = PositionGetString(POSITION_SYMBOL);
        if(symbol != _Symbol) continue;

        double profit = PositionGetDouble(POSITION_PROFIT);
        ulong ticket = PositionGetInteger(POSITION_TICKET);
        ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        bool spikeProfitOk = (BoomCrashSpikeCloseMinProfitUSD <= 0.0)
                             ? (profit >= 0.0)
                             : (profit >= BoomCrashSpikeCloseMinProfitUSD);
        if(ShouldCloseBoomCrashOnScriptSpike(symbol, ptype) && spikeProfitOk) {
            if(trade.PositionClose(ticket)) {
                Print("⚡ SPIKE EXIT: Position fermée (Boom/Crash style) — prob spike=",
                      DoubleToString(ReadGlobalDouble(ScriptGVKey("SPIKE_PROB"), 0.0) * 100.0, 1),
                      "% profit=$", DoubleToString(profit, 2));
            }
            continue;
        }

        if(force_wait_close) {
            if(IsBoomCrashStyleSymbol(symbol) && BoomCrashMaxFloatLossUsdBeforeScriptWaitClose > 1e-6) {
                double sw = PositionGetDouble(POSITION_SWAP);
                double com = PositionGetDouble(POSITION_PROFIT) - PositionGetDouble(POSITION_PRICE_OPEN) * PositionGetDouble(POSITION_VOLUME);
                double totalUsd = profit + sw + com;
                if(totalUsd < 0.0 && totalUsd > -BoomCrashMaxFloatLossUsdBeforeScriptWaitClose) {
                    Print("⏭️ SKIP CLOSE WAIT: Boom/Crash — P/L=", DoubleToString(totalUsd, 2),
                          " $ (seuil cut=", DoubleToString(BoomCrashMaxFloatLossUsdBeforeScriptWaitClose, 2), " $) | attente spike");
                    continue;
                }
            }
            bool closed = trade.PositionClose(ticket);
            if(closed) {
                Print("🛑 CLOSE WAIT: Position fermée car verdict script = WAIT (ou sync script)");
            } else {
                Print("❌ CLOSE WAIT: Échec fermeture - ", trade.ResultComment());
            }
            continue;
        }

        // Vérifier si la position doit être fermée
        if(g_riskManager.ShouldClosePosition(symbol, profit)) {
            string reason = (profit < 0) ? "Perte max atteinte" : "Objectif profit atteint";
            ClosePosition(ticket, reason);
        }
    }
}

datetime GetTodayStart() {
    MqlDateTime dt;
    TimeCurrent(dt);
    dt.hour = 0;
    dt.min = 0;
    dt.sec = 0;
    return StructToTime(dt);
}

double CalculateDailyProfitFromHistory() {
    datetime todayStart = GetTodayStart();
    if(!HistorySelect(todayStart, TimeCurrent()))
        return 0.0;
    double dailyProfit = 0.0;
    for(int i = 0; i < HistoryDealsTotal(); i++) {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(dealTicket == 0) continue;
        datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
        if(dealTime < todayStart) continue;
        if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) continue;
        dailyProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                       + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                       + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
    }
    return dailyProfit;
}

bool CheckTenDollarProfitPause() {
    if(!EnableTenDollarProfitPause)
        return false;
    double dailyProfitClosed = CalculateDailyProfitFromHistory();
    if(dailyProfitClosed >= TenDollarProfitThreshold && !g_tenDollarProfitTargetReached) {
        g_tenDollarProfitTargetReached = true;
        g_tenDollarProfitPauseStartTime = TimeCurrent();
        g_tenDollarProfitPeak = dailyProfitClosed;
        datetime pauseEndTime = g_tenDollarProfitPauseStartTime +
                                TenDollarProfitPauseHours * 3600;
        g_tenDollarPauseUntil = pauseEndTime;
        Print("SEUIL PROFIT RÉALISÉ: $", DoubleToString(dailyProfitClosed, 2),
              " ≥ $", DoubleToString(TenDollarProfitThreshold, 2),
              " → pause ", TenDollarProfitPauseHours, " h jusqu'à ",
              TimeToString(pauseEndTime, TIME_SECONDS));
        return true;
    }
    if(g_tenDollarProfitTargetReached && g_tenDollarProfitPauseStartTime > 0) {
        datetime pauseEndTime = g_tenDollarPauseUntil;
        if(TimeCurrent() >= pauseEndTime) {
            Print("FIN PAUSE PROFIT ($", DoubleToString(TenDollarProfitThreshold, 1),
                  ") — nouvelles entrées autorisées");
            g_tenDollarProfitTargetReached = false;
            g_tenDollarProfitPauseStartTime = 0;
            g_tenDollarProfitPeak = 0.0;
            g_tenDollarPauseUntil = 0;
            return false;
        }
        static datetime lastTenDollarPauseLog = 0;
        if(TimeCurrent() - lastTenDollarPauseLog >= 300) {
            int rem = (int)(pauseEndTime - TimeCurrent());
            Print("PAUSE PROFIT: ", rem / 3600, "h ", (rem % 3600) / 60, "min restantes | P/L jour ",
                  DoubleToString(dailyProfitClosed, 2), " $");
            lastTenDollarPauseLog = TimeCurrent();
        }
        return true;
    }
    return false;
}

bool TenDollarPauseBlocksNewEntries() {
    if(!EnableTenDollarProfitPause) return false;
    if(g_tenDollarPauseUntil <= 0) return false;
    return (TimeCurrent() < g_tenDollarPauseUntil);
}

void UpdateDailyStats() {
    datetime now = TimeCurrent();

    // Reset journalier
    MqlDateTime dt;
    TimeToStruct(now, dt);
    MqlDateTime last_dt;
    TimeToStruct(g_dailyResetTime, last_dt);

    if(dt.day != last_dt.day) {
        g_riskManager.ResetDailyLoss();
        g_tenDollarProfitTargetReached = false;
        g_tenDollarProfitPauseStartTime = 0;
        g_tenDollarProfitPeak = 0.0;
        g_tenDollarPauseUntil = 0;
    }

    // Calculer le profit journalier
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    static double start_balance = 0.0;

    if(start_balance == 0.0) {
        start_balance = current_balance;
    }

    g_dailyProfit = current_balance - start_balance;

    // Mettre à jour le drawdown
    g_riskManager.UpdateDrawdown();

    CheckTenDollarProfitPause();
}

//+------------------------------------------------------------------+
//| SECTION 14: FONCTIONS SMC HEDGE FUND                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| FONCTIONS DE CALCUL                                           |
//+------------------------------------------------------------------+

double SMCCalculateOptimalLotSize(double stopLossPoints) {
    if(stopLossPoints <= 0) return InpLotSize;
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (MaxLossPerTradeDollars / 100.0);
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tickValue <= 0 || pointValue <= 0) return InpLotSize;
    
    double lotSize = riskAmount / (stopLossPoints * tickValue / pointValue);
    
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
    lotSize = MathFloor(lotSize / lotStep) * lotStep;
    
    return NormalizeDouble(lotSize, 2);
}

double SMCGetATR(int period, ENUM_TIMEFRAMES timeframe) {
    int handle = iATR(_Symbol, timeframe, period);
    if(handle == INVALID_HANDLE) return 0.0;
    
    double atr[];
    ArraySetAsSeries(atr, true);
    if(CopyBuffer(handle, 0, 0, 1, atr) > 0) {
        IndicatorRelease(handle);
        return atr[0];
    }
    
    IndicatorRelease(handle);
    return 0.0;
}

double SMCGetVolume(int shift, ENUM_TIMEFRAMES timeframe) {
    long volume[];
    ArraySetAsSeries(volume, true);
    if(CopyTickVolume(_Symbol, timeframe, shift, 1, volume) > 0) {
        return (double)volume[0];
    }
    return 0.0;
}

double SMCGetAverageVolume(int period, ENUM_TIMEFRAMES timeframe) {
    long volume[];
    ArraySetAsSeries(volume, true);
    if(CopyTickVolume(_Symbol, timeframe, 0, period, volume) > 0) {
        double sum = 0.0;
        for(int i = 0; i < period; i++) {
            sum += (double)volume[i];
        }
        return sum / period;
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| DÉTECTION SWING HIGH/LOW                                      |
//+------------------------------------------------------------------+

bool SMCIsSwingHigh(int index, ENUM_TIMEFRAMES timeframe) {
    double high = iHigh(_Symbol, timeframe, index);
    
    for(int i = 1; i <= g_smcConfig.swingLookback; i++) {
        if(index + i >= Bars(_Symbol, timeframe)) break;
        if(iHigh(_Symbol, timeframe, index + i) >= high) return false;
    }
    
    for(int i = 1; i <= g_smcConfig.swingLookback; i++) {
        if(index - i < 0) break;
        if(iHigh(_Symbol, timeframe, index - i) >= high) return false;
    }
    
    return true;
}

bool SMCIsSwingLow(int index, ENUM_TIMEFRAMES timeframe) {
    double low = iLow(_Symbol, timeframe, index);
    
    for(int i = 1; i <= g_smcConfig.swingLookback; i++) {
        if(index + i >= Bars(_Symbol, timeframe)) break;
        if(iLow(_Symbol, timeframe, index + i) <= low) return false;
    }
    
    for(int i = 1; i <= g_smcConfig.swingLookback; i++) {
        if(index - i < 0) break;
        if(iLow(_Symbol, timeframe, index - i) <= low) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| DÉTECTION EQUAL HIGHS/LOWS                                   |
//+------------------------------------------------------------------+

bool SMCIsEqualHigh(double price1, double price2) {
    return MathAbs(price1 - price2) <= g_smcConfig.equalTolerance * _Point;
}

bool SMCIsEqualLow(double price1, double price2) {
    return MathAbs(price1 - price2) <= g_smcConfig.equalTolerance * _Point;
}

//+------------------------------------------------------------------+
//| BREAK OF STRUCTURE (BOS)                                      |
//+------------------------------------------------------------------+

bool SMCIsBullishBOS() {
    if(g_smcMarketStructure.lastSwingHigh == 0.0) return false;
    
    double currentClose = iClose(_Symbol, PERIOD_M15, 0);
    return currentClose > g_smcMarketStructure.lastSwingHigh;
}

bool SMCIsBearishBOS() {
    if(g_smcMarketStructure.lastSwingLow == 0.0) return false;
    
    double currentClose = iClose(_Symbol, PERIOD_M15, 0);
    return currentClose < g_smcMarketStructure.lastSwingLow;
}

//+------------------------------------------------------------------+
//| DÉTECTION DE SWEEP DE LIQUIDITÉ                             |
//+------------------------------------------------------------------+

bool SMCIsLiquiditySweepAbove(double zonePrice) {
    double currentHigh = iHigh(_Symbol, PERIOD_M15, 1);
    double previousHigh = iHigh(_Symbol, PERIOD_M15, 2);
    
    return currentHigh > zonePrice && previousHigh <= zonePrice;
}

bool SMCIsLiquiditySweepBelow(double zonePrice) {
    double currentLow = iLow(_Symbol, PERIOD_M15, 1);
    double previousLow = iLow(_Symbol, PERIOD_M15, 2);
    
    return currentLow < zonePrice && previousLow >= zonePrice;
}

//+------------------------------------------------------------------+
//| GESTION DES ZONES DE LIQUIDITÉ                             |
//+------------------------------------------------------------------+

void SMCAddLiquidityZone(double price, datetime time, string type, double strength) {
    if(ArraySize(g_smcLiquidityZones) >= g_smcConfig.maxLiquidityZones) {
        // Supprimer la plus ancienne zone
        for(int i = ArraySize(g_smcLiquidityZones) - 1; i > 0; i--) {
            g_smcLiquidityZones[i] = g_smcLiquidityZones[i-1];
        }
        ArrayResize(g_smcLiquidityZones, ArraySize(g_smcLiquidityZones) - 1);
    }
    
    int newSize = ArraySize(g_smcLiquidityZones) + 1;
    ArrayResize(g_smcLiquidityZones, newSize);
    
    LiquidityZone newZone;
    newZone.price = price;
    newZone.time = time;
    newZone.type = type;
    newZone.strength = strength;
    newZone.touches = 1;
    newZone.isActive = true;
    newZone.objectId = type + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
    
    g_smcLiquidityZones[newSize - 1] = newZone;
    
    if(g_smcConfig.showLiquidityZones) {
        SMCDrawLiquidityZone(newZone);
    }
}

void SMCUpdateLiquidityZones() {
    for(int i = 0; i < ArraySize(g_smcLiquidityZones); i++) {
        if(!g_smcLiquidityZones[i].isActive) continue;
        
        // Vérifier si le prix touche la zone
        double currentHigh = iHigh(_Symbol, PERIOD_M15, 0);
        double currentLow = iLow(_Symbol, PERIOD_M15, 0);
        
        bool touched = false;
        if(g_smcLiquidityZones[i].type == "SWING_HIGH" || g_smcLiquidityZones[i].type == "EQUAL_HIGH") {
            touched = currentHigh >= g_smcLiquidityZones[i].price && currentLow <= g_smcLiquidityZones[i].price;
        } else if(g_smcLiquidityZones[i].type == "SWING_LOW" || g_smcLiquidityZones[i].type == "EQUAL_LOW") {
            touched = currentLow <= g_smcLiquidityZones[i].price && currentHigh >= g_smcLiquidityZones[i].price;
        }
        
        if(touched) {
            g_smcLiquidityZones[i].touches++;
            
            // Mettre à jour equal highs/lows
            if(g_smcLiquidityZones[i].type == "EQUAL_HIGH" || g_smcLiquidityZones[i].type == "EQUAL_LOW") {
                SMCUpdateEqualZone(g_smcLiquidityZones[i]);
            }
        }
    }
}

void SMCUpdateEqualZone(LiquidityZone &zone) {
    if(zone.type == "EQUAL_HIGH") {
        g_smcMarketStructure.equalHighTouches++;
        if(g_smcMarketStructure.equalHighTouches >= g_smcConfig.minEqualTouches) {
            zone.strength = MathMin(1.0, zone.strength + 0.2);
        }
    } else if(zone.type == "EQUAL_LOW") {
        g_smcMarketStructure.equalLowTouches++;
        if(g_smcMarketStructure.equalLowTouches >= g_smcConfig.minEqualTouches) {
            zone.strength = MathMin(1.0, zone.strength + 0.2);
        }
    }
}

//+------------------------------------------------------------------+
//| FONCTIONS DE DESSIN                                          |
//+------------------------------------------------------------------+

void SMCDrawLiquidityZone(LiquidityZone &zone) {
    string objName = zone.objectId;
    
    if(ObjectFind(0, objName) >= 0) {
        ObjectDelete(0, objName);
    }
    
    ObjectCreate(0, objName, OBJ_HLINE, 0, 0, zone.price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, g_smcConfig.liquidityColor);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    
    // Ajouter label
    string labelName = objName + "_LABEL";
    if(ObjectFind(0, labelName) >= 0) {
        ObjectDelete(0, labelName);
    }
    
    ObjectCreate(0, labelName, OBJ_TEXT, 0, zone.time, zone.price);
    ObjectSetString(0, labelName, OBJPROP_TEXT, zone.type + " (" + IntegerToString(zone.touches) + ")");
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, g_smcConfig.liquidityColor);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void SMCDrawSweep(string direction, double price, datetime time) {
    if(!g_smcConfig.showSweeps) return;
    
    string objName = "SMC_SWEEP_" + direction + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
    
    // Supprimer l'objet existant pour éviter le retracement
    if(ObjectFind(0, objName) >= 0) {
        ObjectDelete(0, objName);
    }
    
    ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, g_smcConfig.sweepColor);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 4);
    ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, direction == "BUY" ? 233 : 234);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, objName, OBJPROP_STATE, false);
}

void SMCDrawEntry(string direction, double price, datetime time) {
    if(!g_smcConfig.showEntries) return;
    
    string objName = "SMC_ENTRY_" + direction + "_" + TimeToString(time, TIME_DATE|TIME_SECONDS);
    
    // Supprimer l'objet existant pour éviter le retracement
    if(ObjectFind(0, objName) >= 0) {
        ObjectDelete(0, objName);
    }
    
    ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, direction == "BUY" ? clrLimeGreen : clrRed);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
    ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, direction == "BUY" ? 241 : 242);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, objName, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| LOGIQUE D'ENTRÉE                                           |
//+------------------------------------------------------------------+

void SMCCheckForLiquiditySweep() {
    double currentPrice = iClose(_Symbol, PERIOD_M15, 0);
    double atr = SMCGetATR(14, PERIOD_M15);
    
    for(int i = 0; i < ArraySize(g_smcLiquidityZones); i++) {
        if(!g_smcLiquidityZones[i].isActive || g_smcLiquidityZones[i].strength < g_smcConfig.liquidityStrength) continue;
        
        bool sweepDetected = false;
        string direction = "";
        
        // Vérifier sweep au-dessus (pour entrée BUY)
        if((g_smcLiquidityZones[i].type == "SWING_HIGH" || g_smcLiquidityZones[i].type == "EQUAL_HIGH") && 
           SMCIsLiquiditySweepBelow(g_smcLiquidityZones[i].price)) {
            
            sweepDetected = true;
            direction = "BUY";
            
            // Confirmation BOS
            if(g_smcConfig.confirmBreakOfStructure && !SMCIsBullishBOS()) continue;
            
        }
        // Vérifier sweep en dessous (pour entrée SELL)
        else if((g_smcLiquidityZones[i].type == "SWING_LOW" || g_smcLiquidityZones[i].type == "EQUAL_LOW") && 
                SMCIsLiquiditySweepAbove(g_smcLiquidityZones[i].price)) {
            
            sweepDetected = true;
            direction = "SELL";
            
            // Confirmation BOS
            if(g_smcConfig.confirmBreakOfStructure && !SMCIsBearishBOS()) continue;
        }
        
        if(sweepDetected) {
            // Confirmation volume
            if(g_smcConfig.useVolumeConfirmation) {
                double currentVolume = SMCGetVolume(1, PERIOD_M15);
                double avgVolume = SMCGetAverageVolume(20, PERIOD_M15);
                if(currentVolume < avgVolume * 1.2) continue;
            }
            
            // Vérifier mouvement après sweep
            if(direction == "BUY") {
                double lowAfterSweep = iLow(_Symbol, PERIOD_M15, 0);
                if(lowAfterSweep > g_smcLiquidityZones[i].price + g_smcConfig.minMoveAfterSweep * _Point) {
                    SMCDrawSweep(direction, g_smcLiquidityZones[i].price, TimeCurrent());
                    // Publier Global Variable pour SMC_Universal_Enhanced
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_DETECTED", 1.0);
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_DIRECTION", direction == "BUY" ? 1.0 : -1.0);
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_PRICE", g_smcLiquidityZones[i].price);
                }
            } else if(direction == "SELL") {
                double highAfterSweep = iHigh(_Symbol, PERIOD_M15, 0);
                if(highAfterSweep < g_smcLiquidityZones[i].price - g_smcConfig.minMoveAfterSweep * _Point) {
                    SMCDrawSweep(direction, g_smcLiquidityZones[i].price, TimeCurrent());
                    // Publier Global Variable pour SMC_Universal_Enhanced
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_DETECTED", 1.0);
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_DIRECTION", direction == "BUY" ? 1.0 : -1.0);
                    GlobalVariableSet("SMC_SWEEP_" + _Symbol + "_PRICE", g_smcLiquidityZones[i].price);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| GESTION DES RISQUES                                         |
//+------------------------------------------------------------------+

bool SMCCheckTradingConditions() {
    // Vérifier perte journalière
    if(g_smcDailyPL < -MathAbs(g_smcConfig.maxDailyLoss)) {
        Print("SMC: Perte journalière maximale atteinte");
        return false;
    }
    
    // Vérifier nombre de trades journaliers
    if(g_smcDailyTradeCount >= g_smcConfig.maxDailyTrades) {
        Print("SMC: Nombre maximum de trades journaliers atteint");
        return false;
    }
    
    // Vérifier spread
    double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
    if(spread > g_smcConfig.maxSpreadPoints) {
        Print("SMC: Spread trop élevé: ", spread, " points");
        return false;
    }
    
    return true;
}

void SMCResetDailyCounters() {
    g_smcDailyPL = 0.0;
    g_smcDailyTradeCount = 0;
    g_smcDailyResetTime = TimeCurrent();
    Print("SMC: Compteurs journaliers réinitialisés");
}

void SMCUpdateDailyPL() {
    datetime currentTime = TimeCurrent();
    
    // Réinitialiser à minuit
    MqlDateTime currentTimeStruct, resetTimeStruct;
    TimeToStruct(currentTime, currentTimeStruct);
    TimeToStruct(g_smcDailyResetTime, resetTimeStruct);
    
    if(currentTimeStruct.day != resetTimeStruct.day) {
        SMCResetDailyCounters();
        return;
    }
    
    // Calculer P&L du jour
    double todayPL = 0.0;
    for(int i = 0; i < HistoryDealsTotal(); i++) {
        if(HistorySelect(0, TimeCurrent())) {
            if(HistoryDealSelect(i)) {
                ulong dealTicket = HistoryDealGetTicket(i);
                if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber) {
                    datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                    MqlDateTime dealTimeStruct;
                    TimeToStruct(dealTime, dealTimeStruct);
                    if(dealTimeStruct.day == currentTimeStruct.day) {
                        todayPL += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                    }
                }
            }
        }
    }
    
    g_smcDailyPL = todayPL;
}

//+------------------------------------------------------------------+
//| ANALYSE PRINCIPALE                                          |
//+------------------------------------------------------------------+

void SMCAnalyzeMarketStructure() {
    int barsToAnalyze = 100;
    
    for(int i = barsToAnalyze; i >= 0; i--) {
        datetime barTime = iTime(_Symbol, PERIOD_M15, i);
        
        // Détecter swing highs
        if(SMCIsSwingHigh(i, PERIOD_M15)) {
            double swingHigh = iHigh(_Symbol, PERIOD_M15, i);
            
            if(swingHigh > g_smcMarketStructure.lastSwingHigh) {
                g_smcMarketStructure.lastSwingHigh = swingHigh;
                g_smcMarketStructure.lastSwingHighTime = barTime;
                
                SMCAddLiquidityZone(swingHigh, barTime, "SWING_HIGH", 0.8);
            }
            
            // Vérifier equal high
            if(g_smcMarketStructure.currentEqualHigh > 0 && SMCIsEqualHigh(swingHigh, g_smcMarketStructure.currentEqualHigh)) {
                g_smcMarketStructure.equalHighTouches++;
                if(g_smcMarketStructure.equalHighTouches >= g_smcConfig.minEqualTouches) {
                    SMCAddLiquidityZone(g_smcMarketStructure.currentEqualHigh, barTime, "EQUAL_HIGH", 0.9);
                }
            } else {
                g_smcMarketStructure.currentEqualHigh = swingHigh;
                g_smcMarketStructure.equalHighTouches = 1;
            }
        }
        
        // Détecter swing lows
        if(SMCIsSwingLow(i, PERIOD_M15)) {
            double swingLow = iLow(_Symbol, PERIOD_M15, i);
            
            if(swingLow < g_smcMarketStructure.lastSwingLow || g_smcMarketStructure.lastSwingLow == 0.0) {
                g_smcMarketStructure.lastSwingLow = swingLow;
                g_smcMarketStructure.lastSwingLowTime = barTime;
                
                SMCAddLiquidityZone(swingLow, barTime, "SWING_LOW", 0.8);
            }
            
            // Vérifier equal low
            if(g_smcMarketStructure.currentEqualLow > 0 && SMCIsEqualLow(swingLow, g_smcMarketStructure.currentEqualLow)) {
                g_smcMarketStructure.equalLowTouches++;
                if(g_smcMarketStructure.equalLowTouches >= g_smcConfig.minEqualTouches) {
                    SMCAddLiquidityZone(g_smcMarketStructure.currentEqualLow, barTime, "EQUAL_LOW", 0.9);
                }
            } else {
                g_smcMarketStructure.currentEqualLow = swingLow;
                g_smcMarketStructure.equalLowTouches = 1;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| TABLEAU DE BORD                                             |
//+------------------------------------------------------------------+

void SMCUpdateDashboard() {
    if(!g_smcConfig.showDashboard) return;
    
    string info = "=== SMC HEDGE FUND ===\n";
    info += "Zones: " + IntegerToString(ArraySize(g_smcLiquidityZones)) + "\n";
    info += "P&L: $" + DoubleToString(g_smcDailyPL, 2) + "\n";
    info += "Trades: " + IntegerToString(g_smcDailyTradeCount) + "\n";
    
    if(SMCIsBullishBOS()) info += "Structure: BULLISH BOS\n";
    else if(SMCIsBearishBOS()) info += "Structure: BEARISH BOS\n";
    else info += "Structure: NEUTRAL\n";
    
    Comment(info);
}

//+------------------------------------------------------------------+
//| NETTOYAGE DES OBJETS                                        |
//+------------------------------------------------------------------+

void SMCCleanChartObjects() {
    for(int i = ObjectsTotal(0) - 1; i >= 0; i--) {
        string objName = ObjectName(0, i);
        if(StringFind(objName, "SMC_") >= 0) {
            ObjectDelete(0, objName);
        }
    }
}

//+------------------------------------------------------------------+
//| FONCTION PRINCIPALE SMC                                     |
//+------------------------------------------------------------------+

void SMCProcess() {
    if(!EnableSMCHedgeFund) return;
    
    datetime currentBar = iTime(_Symbol, PERIOD_M15, 0);
    
    // Exécuter seulement sur nouvelle barre
    if(currentBar == g_smcLastBarTime) return;
    g_smcLastBarTime = currentBar;
    
    // Mettre à jour les compteurs journaliers
    SMCUpdateDailyPL();
    
    // Analyser la structure du marché
    SMCAnalyzeMarketStructure();
    
    // Mettre à jour les zones de liquidité
    SMCUpdateLiquidityZones();
    
    // Vérifier les sweeps de liquidité
    if(g_smcConfig.waitForSweep) {
        SMCCheckForLiquiditySweep();
    }
    
    // Mettre à jour le tableau de bord
    SMCUpdateDashboard();
}

//+------------------------------------------------------------------+
//| SECTION 15: GESTION ZONE FUTURE                                  |
//+------------------------------------------------------------------+

void SMC_ManageFutureZone() {
    // Forcer le décalage du graphique par le robot
    if(EnableChartLeftShift) {
        // Activer le décalage et le figer
        ChartSetInteger(0, 0, CHART_SHIFT, 1);
        ChartSetDouble(0, CHART_SHIFT_SIZE, ChartLeftShiftPct / 100.0);
        
        // Fixer le maximum pour éviter les changements automatiques
        ChartSetInteger(0, 0, CHART_FIXED_POSITION, 1);
    }
    
    // Toujours dessiner la zone future
    // pour garantir qu'elle soit visible et figée
    
    // Dessiner la séparation passé/futur
    if(ShowPastFutureSeparator) {
        SMC_DrawPastFutureSeparator();
    }

    // Dessiner le fond de la zone future
    if(FutureZoneFillColor != clrNONE) {
        SMC_DrawFutureZoneBackground();
    }
}

void SMC_DrawPastFutureSeparator() {
    string objName = "SMC_PAST_FUTURE_SEPARATOR";
    
    if(ObjectFind(0, objName) >= 0) {
        ObjectDelete(0, objName);
    }
    
    // Trouver le point de séparation (dernière bougie réelle)
    datetime lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    double lastBarClose = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // Créer la ligne verticale de séparation
    ObjectCreate(0, objName, OBJ_VLINE, 0, lastBarTime, 0);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    
    // Ajouter le label "PASSE <<<"
    string labelName = "SMC_PAST_LABEL";
    if(ObjectFind(0, labelName) >= 0) {
        ObjectDelete(0, labelName);
    }
    
    ObjectCreate(0, labelName, OBJ_TEXT, 0, lastBarTime - PeriodSeconds(PERIOD_CURRENT) * 5, lastBarClose);
    ObjectSetString(0, labelName, OBJPROP_TEXT, "PASSE <<<");
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 14);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Black");
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
    
    // Ajouter le label ">>> FUTUR"
    string futureLabelName = "SMC_FUTURE_LABEL";
    if(ObjectFind(0, futureLabelName) >= 0) {
        ObjectDelete(0, futureLabelName);
    }
    
    ObjectCreate(0, futureLabelName, OBJ_TEXT, 0, lastBarTime + PeriodSeconds(PERIOD_CURRENT) * 5, lastBarClose);
    ObjectSetString(0, futureLabelName, OBJPROP_TEXT, ">>> FUTUR");
    ObjectSetInteger(0, futureLabelName, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, futureLabelName, OBJPROP_FONTSIZE, 14);
    ObjectSetString(0, futureLabelName, OBJPROP_FONT, "Arial Black");
    ObjectSetInteger(0, futureLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
}

void SMC_DrawFutureZoneBackground() {
    string objName = "SMC_FUTURE_ZONE_BG";
    
    // Supprimer et recréer pour garantir la mise à jour
    if(ObjectFind(0, objName) >= 0) {
        ObjectDelete(0, objName);
    }
    
    // Calculer les coordonnées de la zone future
    datetime lastBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    datetime futureEndTime = lastBarTime + PeriodSeconds(PERIOD_CURRENT) * FutureZoneBars;
    
    double priceMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double priceMin = ChartGetDouble(0, CHART_PRICE_MIN);
    
    // Créer le rectangle de fond avec une bordure visible
    ObjectCreate(0, objName, OBJ_RECTANGLE, 0, lastBarTime, priceMax, futureEndTime, priceMin);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrSilver);
    ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, objName, OBJPROP_FILL, true);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, FutureZoneFillColor);
    ObjectSetInteger(0, objName, OBJPROP_BACK, true);
    ObjectSetInteger(0, objName, OBJPROP_STATE, false);
    ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 1);
    
    // Ajouter un label dans la zone future
    string labelName = "SMC_FUTURE_ZONE_LABEL";
    if(ObjectFind(0, labelName) >= 0) {
        ObjectDelete(0, labelName);
    }
    
    ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) - (int)(ChartGetInteger(0, CHART_WIDTH_IN_PIXELS) * ChartLeftShiftPct / 200.0));
    ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 20);
    ObjectSetString(0, labelName, OBJPROP_TEXT, "ZONE FUTURE");
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrLightGray);
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 12);
    ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Black");
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
    ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
}

//+------------------------------------------------------------------+
//| SECTION 16: INITIALISATION ET NETTOYAGE                          |
//+------------------------------------------------------------------+

int OnInit() {
    // Initialiser le trade
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(10);
    
    // Initialiser SMC Hedge Fund
    if(EnableSMCHedgeFund) {
        g_smcConfig.LoadDefaults();
        g_smcConfig.swingLookback = SMCSwingLookback;
        g_smcConfig.equalTolerance = SMCEqualTolerance;
        g_smcConfig.minEqualTouches = SMCMinEqualTouches;
        g_smcConfig.liquidityStrength = SMCLiquidityStrength;
        g_smcConfig.maxLiquidityZones = SMCMaxLiquidityZones;
        g_smcConfig.useTrendlines = SMCUseTrendlines;
        g_smcConfig.waitForSweep = SMCWaitForSweep;
        g_smcConfig.sweepThreshold = SMCSweepThreshold;
        g_smcConfig.confirmBreakOfStructure = SMCConfirmBOS;
        g_smcConfig.entryDelayBars = SMCEntryDelayBars;
        g_smcConfig.minMoveAfterSweep = SMCMinMoveAfterSweep;
        g_smcConfig.useVolumeConfirmation = SMCUseVolumeConfirmation;
        g_smcConfig.maxDailyLoss = SMCMaxDailyLoss;
        g_smcConfig.maxDailyTrades = SMCMaxDailyTrades;
        g_smcConfig.maxSpreadPoints = SMCMaxSpreadPoints;
        g_smcConfig.stopLossBuffer = SMCStopLossBuffer;
        g_smcConfig.useTrailingStop = SMCUseTrailingStop;
        g_smcConfig.trailingStopATR = SMCTrailingStopATR;
        g_smcConfig.showLiquidityZones = SMCShowLiquidityZones;
        g_smcConfig.showSweeps = SMCShowSweeps;
        g_smcConfig.showEntries = SMCShowEntries;
        g_smcConfig.showDashboard = SMCShowDashboard;
        g_smcConfig.liquidityColor = clrOrange;
        g_smcConfig.sweepColor = clrRed;
        g_smcConfig.entryColor = clrLime;
        
        ArrayResize(g_smcLiquidityZones, 0);
        g_smcMarketStructure.Reset();
        g_smcDailyResetTime = TimeCurrent();
        
        Print("=== SMC Hedge Fund Strategy Initialisé ===");
        Print("Swing Lookback: ", g_smcConfig.swingLookback);
        Print("Equal Tolerance: ", g_smcConfig.equalTolerance, " points");
        Print("Liquidity Strength: ", g_smcConfig.liquidityStrength);
    }
    trade.SetTypeFilling(ORDER_FILLING_IOC);

    // Charger la configuration
    g_config.Load();
    if(!g_config.Validate()) {
        Print("❌ Erreur: Configuration invalide");
        return INIT_FAILED;
    }

    // Afficher la configuration
    Print(g_config.ToString());

    // Initialiser le gestionnaire de risques
    g_riskManager.SetParameters(
        MaxLossPerTradeDollars,
        MaxPositionsTerminal,
        MaxDailyLossDollars
    );

    // Initialiser le connecteur IA
    if(UseAIServer) {
        g_aiConnector = new CSMCAIConnector(AI_ServerURL, AI_Timeout_ms);
        Print("✅ Connecteur IA initialisé: ", AI_ServerURL);
    }
    
    // Initialiser les variables IA globales
    g_lastAIAction.Reset();
    g_lastAIAction.direction = "HOLD";
    g_lastAIAction.confidence = 0.0;
    g_lastAIAction.is_valid = false;
    g_lastAIUpdateTime = 0;
    Print("✅ Variables IA internes initialisées (non publiées sur le graphe)");

    // Initialiser les variables Ollama
    g_lastOllamaAnalysis.Reset();
    g_lastOllamaUpdateTime = 0;
    g_ollamaLastSummary = "";
    g_lastTradingAgentsAnalysis.Reset();
    g_lastTradingAgentsUpdateTime = 0;
    g_lastTradingAgentsSummary = "";
    g_lastOpportunityCostScore = 0.0;
    g_lastOpportunityPriceDevATR = 0.0;
    PublishRobotOllamaGlobals();
    Print("✅ Pont OllamaGlobals initialisées");
    // Première lecture /decision → GV SERVER_AI_* pour le script (tableau GOM)
    UpdateAIDecision();
    UpdateTradingAgentsAnalysis();

    // Initialiser l'analyseur multi-timeframe
    g_mtfAnalyzer = new CSMCMultiTimeframeAnalyzer();

    // Initialiser le temps de reset journalier
    g_dailyResetTime = TimeCurrent();

    Print("✅ TradBOT Enhanced initialisé avec succès");
    Print("   Version: 2.00");
    Print("   Symbole: ", _Symbol);
    Print("   Timeframe: ", EnumToString(Period()));

    EventSetTimer(60);
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {
    EventKillTimer();
    // Nettoyer les objets graphiques
    ObjectsDeleteAll(0);
    
    // Nettoyer spécifiquement les objets SMC
    ObjectDelete(0, "SMC_PAST_FUTURE_SEPARATOR");
    ObjectDelete(0, "SMC_PAST_LABEL");
    ObjectDelete(0, "SMC_FUTURE_LABEL");
    ObjectDelete(0, "SMC_FUTURE_ZONE_BG");
    ObjectDelete(0, "SMC_FUTURE_ZONE_LABEL");

    // Libérer la mémoire
    if(g_aiConnector != NULL) {
        delete g_aiConnector;
        g_aiConnector = NULL;
    }

    if(g_mtfAnalyzer != NULL) {
        delete g_mtfAnalyzer;
        g_mtfAnalyzer = NULL;
    }

    Print("🔌 TradBOT Enhanced désactivé");
}

//+------------------------------------------------------------------+
//| SECTION 17: BOUCLE PRINCIPALE                                     |
//+------------------------------------------------------------------+

void OnTick() {
    // Mettre à jour les statistiques journalières
    UpdateDailyStats();
    
    // Traiter SMC Hedge Fund
    SMCProcess();
    
    // Gérer la zone future
    SMC_ManageFutureZone();

    // Gérer le trailing stop
    ManageTrailingStop();

    // Vérifier et fermer les positions si nécessaire
    CheckAndClosePositions();

    // Mettre à jour l'analyse TradingAgents (résumé externe)
    UpdateTradingAgentsAnalysis();

    // Vérifier et exécuter les nouveaux trades
    CheckAndExecuteTrades();

    // Mettre à jour le dashboard
    UpdateDashboard();

    // Mettre à jour la flèche de signal
    DrawSignalArrow();

    // === PONT OLLAMA: Analyse approfondie LLM local ===
    // Toutes les 5 minutes, envoyer les indicateurs à Ollama et afficher l'analyse
    UpdateOllamaAnalysis();

    // Afficher l'analyse Ollama sur le graphique (mis à jour à chaque tick si disponible)
    DisplayOllamaAnalysis();
}

//+------------------------------------------------------------------+
//| SECTION 18: TIMER (pour mises à jour périodiques)                  |
//+------------------------------------------------------------------+

void OnTimer() {
    // Mises à jour périodiques (toutes les minutes)
    UpdateDailyStats();
    UpdateDashboard();
    // Rafraîchit /decision pour le tableau GOM (confiance SRV) même si le trading suit le script.
    UpdateAIDecision();
    UpdateTradingAgentsAnalysis();
}

//+------------------------------------------------------------------+
