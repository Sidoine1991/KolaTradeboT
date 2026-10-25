//+------------------------------------------------------------------+
//|                                                SpikeHunter_EA.mq5 |
//|                        Copyright 2025, TradBOT Spike Hunter EA   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, TradBOT Spike Hunter EA"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Robot de trading automatique pour capturer les spikes Boom/Crash"

//--- Paramètres d'entrée
input group "=== CONFIGURATION GÉNÉRALE ==="
input bool     InpEnableTrading = true;           // Activer le trading
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_M1;   // Timeframe d'analyse
input int      InpMagicNumber = 123456;           // Magic Number
input double   InpUserCapital = 50.0;             // Capital utilisateur ($)
input int      InpTargetRecoveryTrades = 3;       // Nombre de trades pour rentabiliser

input group "=== CONFIGURATION TRADING UNIVERSEL ==="
input bool     InpTradeAllSymbols = true;         // Trader tous les symboles dérivés
input int      InpMaxSymbolsToScan = 20;          // Nombre max de symboles à scanner
input string   InpSymbolsToTrade = "Crash 1000 Index, Boom 1000 Index, Crash 500 Index, Crash 300 Index, Boom 600 Index, Crash 600 Index, Boom 300 Index, Boom 900 Index, Crash 900 Index"; // Symboles prioritaires
input int      InpMaxTrades = 10;                // Nombre max de trades simultanés
input double   InpBaseLotSize = 0.20;             // Taille de base des lots
input double   InpMaxLotSize = 2.00;              // Taille maximum des lots
input double   InpMaxLossPerTrade = 2.0;          // Perte maximum par trade ($)
input int      InpStopLoss = 10;                  // Stop Loss en points
input int      InpTakeProfit = 15;                // Take Profit en points (scalping rapide)

input group "=== DÉTECTION DE SPIKE ==="
input int      InpSpikeDetectionPeriod = 5;       // Période de détection de spike
input double   InpSpikeThreshold = 0.1;           // Seuil de spike (%)
input int      InpReversalDetection = 3;          // Période de détection d'inversion
input double   InpReversalThreshold = 0.1;        // Seuil d'inversion (%)

input group "=== GESTION DU CAPITAL ==="
input bool     InpUseRiskManagement = true;       // Utiliser la gestion du risque
input double   InpRiskPercent = 2.0;              // Pourcentage de risque par trade (%)
input double   InpMaxDailyLoss = 20.0;            // Perte maximum journalière ($)
input bool     InpUseMartingale = true;           // Utiliser la stratégie Martingale
input double   InpMartingaleMultiplier = 1.3;     // Multiplicateur Martingale
input double   InpRecoveryFactor = 0.9;           // Facteur de récupération
input int      InpMaxConsecutiveLosses = 10;      // Max pertes consécutives

input group "=== TRAILING STOP ==="
input bool     InpUseTrailing = true;             // Utiliser le trailing stop
input int      InpTrailingStart = 10;             // Distance de démarrage trailing (points)
input int      InpTrailingStep = 3;               // Pas du trailing stop (points)

input group "=== NOTIFICATIONS ==="
input bool     InpSendNotifications = true;       // Envoyer des notifications
input group "=== DÉTECTION SPIKES AVANCÉE ==="
input int      InpBBPeriod = 20;                  // Période Bollinger
input double   InpBBDeviation = 2.0;              // Déviation Bollinger
input int      InpBodyZWindow = 120;              // Fenêtre pour z-score corps
input double   InpBodyZMin = 2.5;                 // z-score minimum
input int      InpEMAFast = 9;                    // EMA rapide
input int      InpEMASlow = 21;                   // EMA lente
input int      InpSpikeWindowMins = 30;           // Fenêtre de comptage spikes (minutes)
input double   InpATRBoost = 1.5;                 // Facteur ATR vs ATR moyen
input int      InpAlertCooldownSeconds = 30;      // Anti-spam: délai min entre alertes (s)
input string   InpWebhookURL = "";                // URL Webhook pour notifications

// Paramètres indicateur Squeeze (pour affichage/attachement auto)
input group "=== INDICATEUR SQUEEZE (AFFICHAGE) ==="
input bool     InpAttachSqueezeIndicator = true;   // Attacher l'indicateur visuel
input bool     InpShowIndicatorArrows = true;      // Afficher flèches sur le graphe
input double   InpSqueezeFactor = 0.6;             // BBW < factor * moyenne
input double   InpATRFactor = 1.5;                  // ATR14/ATR50 minimum
input double   InpBodyZThresh = 2.5;               // Seuil z-score corps
input int      InpExtremeWindow = 30;              // Fenêtre de comptage extrêmes (barres)
input int      InpExtremeMax = 2;                  // Max extrêmes autorisés
input int      InpATRShort = 14;                    // ATR court
input int      InpATRLong = 50;                     // ATR long

// Confluence Price Action/Fibonacci/BOS/CHoCH
input group "=== CONFLUENCE (PA + FIB + BOS/CHoCH) ==="
input double   InpSRWeight = 0.35;                  // Poids proximité S/R confirmé
input double   InpOTEWeight = 0.25;                 // Poids zone OTE (0.62-0.79)
input double   InpEMAWeight = 0.15;                 // Poids alignement EMA9/21
input double   InpBOSWeight = 0.25;                 // Poids BOS/CHoCH récent
input double   InpConfluenceMin = 0.75;             // Seuil de confluence minimale (0.75 par défaut)
input double   InpSRMinProximityPct = 0.15;         // Proximité S/R min (en %) (plus grand = moins strict)
input group "=== LIQUIDITÉ / FVG / LIMIT ORDERS ==="
input int      InpEqualHLWindow = 20;               // Fenêtre pour Equal High/Low
input double   InpEqualHLTolerancePts = 20;         // Tolérance (points)
input int      InpFVGLookback = 30;                 // Lookback FVG (barres)
input bool     InpRequireFVG = false;               // Exiger FVG récente dans le sens
input bool     InpUseLimitOrders = true;            // Placer des ordres limit
input int      InpLimitOffsetPoints = 30;           // Offset limit (points)
input int      InpLimitExpirySec = 90;              // Expiration limit (secondes)
input int      InpLimitTPPoints = 25;               // TP distance (points) - scalping rapide
input double   InpLimitSLtoTPMax = 0.40;            // SL <= 40% du TP (ratio 1:2.5)
input int      InpCancelSignalMinutes = 4;          // Annuler le signal si pas de spike après N minutes
input group "=== MODE SIMPLE (RECOMMANDÉ) ==="
input bool     InpUseSimpleMode = true;             // Utiliser logique simple: S/R + MTF
input double   InpSimpleSRProximityPct = 0.15;      // Proximité S/R (%%) pour signal en M1

input group "=== INTERFACE GRAPHIQUE ==="
input bool     InpShowDashboard = true;           // Afficher le panneau de performance
input bool     InpPlaySounds = true;              // Activer les alertes sonores
input string   InpSoundFile = "alert.wav";        // Fichier son pour les alertes
// Paramètre supprimé: marquage "mouvement escalier"

input group "=== CONNEXION APPLICATION ==="
input string   InpAppURL = "http://localhost:8503"; // URL de l'application locale
input int      InpCheckInterval = 1;              // Intervalle de vérification (secondes)
input bool     InpUseAppSignals = true;           // Utiliser les signaux de l'app

input group "=== PERFORMANCE & OPTIMISATION ==="
input int      InpHeavyTaskIntervalSec = 3;       // Intervalle pour tâches lourdes (s)
input int      InpNetTrendCacheSec     = 10;      // Cache résultat API tendance (s)
input int      InpUIUpdateIntervalSec  = 1;       // Intervalle mises à jour UI (s)
input int      InpLogVerbosity         = 1;       // 0=minimal, 1=normal, 2=debug
input int      InpRiskCheckIntervalSec = 1;       // Intervalle de contrôle du risque (s)
input bool     InpLazyInitialization = true;      // Initialisation paresseuse (démarrage rapide)
input int      InpStartupDelaySec = 2;            // Délai avant activation complète (s)

input group "=== AUTOSCAN SIGNALS ==="
input bool     InpAutoScan = true;                // Activer l'autoscan
input int      InpScanInterval = 120;             // Intervalle d'autoscan (secondes)
input bool     InpSendToWhatsApp = true;          // Envoyer signaux par WhatsApp
input bool     InpSendToSMS = true;               // Envoyer signaux par SMS
input string   InpPhoneNumber = "+22996911346";   // Numéro de téléphone

input group "=== SUPPORTS ET RÉSISTANCES ==="
input bool     InpDetectSupportResistance = true; // Détecter les supports/résistances
input int      InpMinTouches = 3;                 // Nombre minimum de touches pour confirmation
input double   InpLevelTolerance = 0.0005;        // Tolérance pour les niveaux (%)
input bool     InpShowLevels = true;              // Afficher les niveaux sur le graphique
input color    InpSupportColor = clrLimeGreen;    // Couleur des supports (vert)
input color    InpResistanceColor = clrRed;       // Couleur des résistances (rouge)

input group "=== CONNEXION STREAMLIT ==="
input bool     InpUseStreamlitData = true;        // Utiliser les données Streamlit
input string   InpStreamlitURL = "http://localhost:8501"; // URL Streamlit
input int      InpStreamlitInterval = 30;         // Intervalle de mise à jour (secondes)

input group "=== TRADING AUTOMATIQUE ==="
input bool     InpAutoTradeOnSpike = true;        // Trading automatique sur les spikes
input string   InpTrendApiUrl = "http://localhost:8005/trend"; // API tendance timeframe
input double   InpMinPredictionConfidence = 50.0; // Confiance minimum pour trading (%)
input double   InpScalpCloseAtSLRatio = 1.2;      // Fermer gains à 120% du SL (scalping rapide)
input double   InpDollarTakeProfitPerTrade = 10.0; // Fermer si profit >= $10 par trade (sécurisation gains)
input double   InpDollarStopLossPerTrade   = 5.0;  // Fermer si perte <= -$5 par trade (capital par trade)
input double   InpGlobalMaxLossUSD         = 10.0; // Perte flottante max totale (USD) pour tous les trades EA
input bool     InpReenterOnDollarTP        = true; // Ré-entrée auto après TP dollar
input double   InpReenterProfitUSD         = 5.0;  // Seuil de ré-entrée après gain ($)

// === MODE PETIT CAPITAL & OBJECTIFS ===
input group "=== PETIT CAPITAL & OBJECTIFS ==="
input bool     InpSmallBalanceMode         = true;   // Activer l'adaptation petit capital
input double   InpSmallBalanceThreshold    = 15.0;   // Seuil (USD) pour activer le mode petit capital
input int      InpMaxTradesSmallBalance    = 1;      // Max trades simultanés en petit capital
input double   InpDailyProfitTargetPct     = 50.0;   // Arrêt journalier: % du capital de départ du jour
input double   InpWeeklyProfitTargetUSD    = 100.0;  // Objectif hebdo (USD)
input bool     InpRespectDailyStop         = true;   // Bloquer tout nouveau trade après cible journalière
input double   InpSmallTP_USD              = 0.60;   // TP$ par trade pour petit capital
input double   InpSmallSL_USD              = 0.30;   // SL$ par trade pour petit capital

// === DÉTECTION PRÉ-SPIKE (Boom/Crash) ===
input group "=== DÉTECTION PRÉ-SPIKE (BOOM/CRASH) ==="
input bool     InpPreSpikeEnable           = true;   // Activer la détection pré-spike
input int      InpPreSpikeLookback         = 12;     // Lookback (barres) pour compression
input double   InpPreSpikeBBWThreshold     = 0.012;  // Seuil BBWidth (compression)
input double   InpPreSpikeATRBoost         = 1.20;   // Boost ATR vs moyenne
input double   InpPreSpikeWickRatio        = 1.8;    // Mèche/Corps minimale sur bougie N-1
input int      InpPreSpikeMinConfidence    = 40;     // Confiance minimale (%) pour signal pré-spike
input double   InpMinADX = 18.0;                   // ADX minimum pour confirmer tendance
input group "=== PRÉCISION & FILTRES ==="
input int      InpMaxSpreadPoints     = 20;        // Spread max (points) pour autoriser un ordre

input group "=== ÉQUILIBRAGE PAR SYMBOLE ==="
input int      InpPerSymbolCooldownSec     = 60;   // Cooldown par symbole après un trade (s)
input int      InpMaxSignalsPerSymbolHour  = 6;    // Max signaux traités par symbole par heure
input bool     InpEnableStepTightening     = true; // Durcir les filtres pour Step Index
input double   InpStepExtraMinConfidence   = 0.75; // Confiance mini pour Step Index
input bool     InpCloseOnSpikeConfirm      = true; // Fermer aussitôt à la confirmation de spike
input double   InpMinRiskReward       = 2.0;       // R:R minimum requis
input double   InpBreakevenAtRR       = 1.0;       // Passer au BE à partir de X R
input double   InpTrailAfterRR        = 1.5;       // Activer trailing après X R
input int      InpTrailStepPoints     = 10;        // Pas trailing (points)
input int      InpDuplicatePriceTolerancePoints = 2; // Tolérance prix pour éviter doublons
input int      InpDuplicateCooldownSec         = 30; // Délai anti-doublon (s)
input double   InpEarlyExitProfitUSD           = 2.0; // Sortie anticipée si tendance non uniforme (profit >= $2)
input int      InpMaxLossPips = 10;               // Perte maximum par trade (pips)
input int      InpPredictionTimeout = 120;        // Timeout prédiction (secondes)
input group "=== PRÉDICTION SPIKES MULTIPLES ==="
input bool     InpEnableMultiSpikeDetection = true; // Activer détection zones spikes multiples
input int      InpSpikeClusterWindow = 300;        // Fenêtre de détection cluster spikes (secondes)
input int      InpMinSpikesInCluster = 2;          // Minimum spikes dans un cluster
input double   InpVolatilityAcceleration = 1.5;    // Facteur d'accélération volatilité pour prédiction
input double   InpMultiSpikeConfidence = 0.85;     // Confiance minimum pour prédiction multi-spike
input group "=== SCALPING INTELLIGENT ==="
input int      InpScalpingCooldownMinutes = 0;     // Délai avant de pouvoir retrader le même symbole (minutes)
input bool     InpEnableQuickScalping = true;      // Activer scalping rapide avec sécurisation

input group "=== RÈGLES DE TRADING SÉCURISÉ ==="
input bool     InpSecureTrading = true;            // Activer trading sécurisé
input double   InpMinCapital = 50.0;               // Capital minimum pour trader ($)
input double   InpMaxDailyLossPercent = 5.0;       // Perte max par jour (% du capital)
input int      InpMinCooldownMinutes = 10;        // Cooldown minimum entre trades (min)
input bool     InpTrendOnlyTrading = true;        // Trader seulement avec la tendance
input bool     InpMultiTimeframeCheck = true;     // Vérification multi-timeframe
input int      InpMinTimeframesAligned = 3;       // Min timeframes alignés (sur 4)
input double   InpQuickProfitTarget = 5.0;         // Profit rapide à sécuriser ($)
input int      InpMaxScalpingTradesPerHour = 6;    // Max trades scalping par heure par symbole

input group "=== PROTECTION ANTI-CASCADE ==="
input int      InpMinTradeDurationSeconds = 30;    // Durée minimum d'un trade (secondes)
input int      InpMaxTradesPerMinute = 2;          // Max trades par minute par symbole
input bool     InpPreventRapidOpenClose = true;    // Empêcher ouverture/fermeture rapide
input double   InpMinProfitToClose = 2.0;          // Profit minimum pour fermeture auto ($)
input int      InpTradeStabilityCheckSeconds = 60; // Vérifier stabilité avant fermeture (s)

input group "=== ORDRES LIMIT DYNAMIQUES ==="
input bool     InpDynamicLimitOrders = true;      // Activer ordres limit dynamiques
input int      InpMaxLimitOrders = 3;             // Max ordres limit simultanés
input int      InpMaxLimitOrdersSmallCapital = 2; // Max ordres pour capital < $5
input double   InpSmallCapitalThreshold = 5.0;    // Seuil capital petit ($)
input int      InpLimitOrderUpdateInterval = 30;  // Intervalle mise à jour ordres (secondes)
input double   InpLimitOrderPriceAdjustment = 0.5; // Ajustement prix ordres (%)

//--- Variables globales
int spike_detection_handle;
int ma_handle;
int rsi_handle;

// Variables pour ordres limit dynamiques
struct DynamicLimitOrder {
    ulong ticket;
    string symbol;
    int type; // ORDER_TYPE_BUY_LIMIT ou ORDER_TYPE_SELL_LIMIT
    double price;
    double lot_size;
    datetime created_time;
    double original_price;
    int update_count;
};

DynamicLimitOrder dynamic_orders[10]; // Max 10 ordres dynamiques
int dynamic_orders_count = 0;
datetime last_limit_order_update = 0;
int ema_fast_handle = INVALID_HANDLE;
int ema_slow_handle = INVALID_HANDLE;
int squeeze_handle = INVALID_HANDLE;

// Variables d'optimisation
datetime ea_startup_time = 0;
bool ea_fully_initialized = false;

// Variables pour le scan multi-symboles
string symbols_to_scan[];
datetime last_symbol_scan = 0;
int current_symbol_index = 0;

// Garde-fous pour empêcher le détachement (soft-block au lieu d'échec)
bool g_soft_block = false;
string g_block_msg = "";

// Équilibrage par symbole (cooldown et quotas)
struct SymbolQuota {
    string symbol;
    datetime last_trade_time;
    int count_last_hour;
    datetime hour_window_start;
};

SymbolQuota g_symbol_quotas[64];
int g_symbol_quotas_count = 0;

// Protection anti-cascade
struct TradeHistory {
    string symbol;
    datetime open_time;
    datetime close_time;
    int direction;
    double profit;
    bool was_closed_early;
};

TradeHistory g_trade_history[100];
int g_trade_history_count = 0;
datetime g_last_trade_time_by_symbol[64];
int g_trades_per_minute_by_symbol[64];

int FindOrCreateSymbolQuota(string symbol)
{
    for(int i=0;i<g_symbol_quotas_count;i++){
        if(g_symbol_quotas[i].symbol==symbol) return i;
    }
    if(g_symbol_quotas_count<64){
        g_symbol_quotas[g_symbol_quotas_count].symbol = symbol;
        g_symbol_quotas[g_symbol_quotas_count].last_trade_time = 0;
        g_symbol_quotas[g_symbol_quotas_count].count_last_hour = 0;
        g_symbol_quotas[g_symbol_quotas_count].hour_window_start = TimeCurrent();
        return g_symbol_quotas_count++;
    }
    return -1;
}
double spike_buffer[];
double ma_buffer[];
double rsi_buffer[];

//--- Structures pour les trades
struct TradeInfo {
    ulong ticket;
    datetime open_time;
    double open_price;
    double lot_size;
    int direction; // 1 = BUY, -1 = SELL
    bool is_spike_trade;
    double spike_start_price;
    double profit_target;
    double loss_limit;
};
TradeInfo active_trades[]; // dynamic array
int trade_count = 0;

//--- Variables de suivi
double last_boom_price = 0;
double last_crash_price = 0;
datetime last_spike_time = 0;
bool spike_detected = false;
int spike_direction = 0; // 1 = Boom spike, -1 = Crash spike

// Suivi PnL pour arrêts journaliers/hebdomadaires
datetime day_start_time = 0;
double day_start_balance = 0.0;
double day_realized_profit = 0.0;
datetime week_start_time = 0;
double week_realized_profit = 0.0;
bool daily_stop_triggered = false;

//--- Variables de gestion du capital
double current_lot_size = 0.01;
double adjusted_base_lot_size = 0.20; // Adjusted base lot size after broker validation
int consecutive_losses = 0;
double total_profit = 0;
double total_loss = 0;
double account_balance = 0;
double account_equity = 0;
double daily_loss = 0;
datetime last_daily_reset = 0;

//--- Variables pour le panneau de performance
int total_trades = 0;
int winning_trades = 0;
int losing_trades = 0;
double max_profit = 0;
double max_loss = 0;
double win_rate = 0;
datetime last_trade_time = 0;
string last_alert = "";
datetime last_alert_time = 0;
bool alert_lock_active = false; // verrous: une seule alerte jusqu'à l'arrivée du spike

//--- Variables pour la connexion à l'application
datetime last_app_check = 0;
string last_app_signal = "";
bool app_signal_received = false;

//--- Variables pour la prédiction de spikes
struct SpikePrediction {
    datetime predicted_time;
    int predicted_direction; // 1 = Boom (flèche bleue), -1 = Crash (flèche rouge)
    double confidence;
    int duration_seconds;
    bool is_active;
};
SpikePrediction current_prediction;
datetime last_prediction_time = 0;
int total_predictions = 0;
int successful_predictions = 0;

//--- Variables pour la prédiction de spikes multiples
struct SpikeCluster {
    datetime start_time;
    datetime end_time;
    int spike_count;
    double avg_volatility;
    double max_volatility;
    int direction; // 1 = haussier, -1 = baissier, 0 = mixte
    double confidence;
    bool is_active;
    double price_range_high;
    double price_range_low;
};
SpikeCluster current_cluster;
SpikeCluster historical_clusters[10];
int cluster_count = 0;
double spike_volatility_history[50];

//--- Variables pour le scalping intelligent
struct ScalpingData {
    string symbol;
    datetime last_trade_time;
    int trades_this_hour;
    double total_profit_today;
    bool is_in_cooldown;
};
ScalpingData scalping_tracker[20];
int scalping_count = 0;

//--- Variables pour l'autoscan
datetime last_autoscan_time = 0;
int autoscan_signals_sent = 0;
string last_autoscan_signal = "";

//--- Structures pour les supports et résistances
struct SupportResistance {
    double level;
    int strength; // 1-5 (nombre de touches)
    datetime last_touch;
    bool is_support; // true = support, false = résistance
    bool is_confirmed; // confirmé si strength >= InpMinTouches
    string name;
    int touch_count;
};
SupportResistance support_levels[20];
SupportResistance resistance_levels[20];
int support_count = 0;
int resistance_count = 0;

//--- Variables pour la connexion Streamlit
datetime last_streamlit_check = 0;
string streamlit_timeframes = "M1,M5,M15,M30,H1"; // Timeframes par défaut
string streamlit_supports = "";
string streamlit_resistances = "";

//--- Variables pour la détection des niveaux
datetime last_level_detection = 0;
double last_high = 0;
double last_low = 0;
datetime last_high_time = 0;
datetime last_low_time = 0;
double price_history[100];
int history_index = 0;
datetime last_history_update = 0;

//--- Affichage score en grand
double g_last_score = 0.0; // 0..100
datetime g_last_blink = 0;
bool g_blink = false;
string g_score_obj = "SH_BigScore";
string g_prox_obj  = "SH_NearestSR";

void UpdateScoreDisplay(const double score)
{
    g_last_score = score;
    // Blink toggle each second
    datetime nowSec = TimeCurrent();
    if(nowSec != g_last_blink){ g_blink = !g_blink; g_last_blink = nowSec; }

    // Create label if missing (ObjectFind returns index or -1)
    if(ObjectFind(0, g_score_obj) == -1)
    {
        ObjectCreate(0, g_score_obj, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, g_score_obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, g_score_obj, OBJPROP_XDISTANCE, 12);
        ObjectSetInteger(0, g_score_obj, OBJPROP_YDISTANCE, 16);
        ObjectSetInteger(0, g_score_obj, OBJPROP_BACK, false);
        ObjectSetInteger(0, g_score_obj, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, g_score_obj, OBJPROP_HIDDEN, true);
    }

    // Determine color by score and blink
    color baseCol;
    if(score >= 97.0) baseCol = clrLime;
    else if(score >= 80.0) baseCol = clrOrange;
    else baseCol = clrTomato;

    color col = baseCol;
    if(score >= 97.0)
        col = g_blink ? clrWhite : clrLime;
    else if(score < 60.0)
        col = g_blink ? clrMaroon : clrTomato;

    string txt = StringFormat("%.0f%%", score);
    ObjectSetString(0, g_score_obj, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, g_score_obj, OBJPROP_COLOR, col);
    ObjectSetInteger(0, g_score_obj, OBJPROP_FONTSIZE, 36);
    ObjectSetString(0, g_score_obj, OBJPROP_FONT, "Arial Black");
}

double AlignToTick(double price)
{
    double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double digits = (double)_Digits;
    return NormalizeDouble(MathRound(price/pt)*pt, (int)digits);
}

void ComputeSLTP(const double entry, const bool isBuy,
                 const int tpPoints, const double slToTpMax,
                 double &outSL, double &outTP)
{
    double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int stops = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    int minPts = MathMax(stops, 1);
    int tpPts = MathMax(tpPoints, minPts);
    int slPts = MathMax((int)MathFloor(tpPts * slToTpMax), minPts);
    if(isBuy)
    {
        outTP = AlignToTick(entry + tpPts * pt);
        outSL = AlignToTick(entry - slPts * pt);
    } else {
        outTP = AlignToTick(entry - tpPts * pt);
        outSL = AlignToTick(entry + slPts * pt);
    }
}

int GetMinPendingOffsetPoints()
{
    int stops = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    int freeze = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    return MathMax(MathMax(stops, freeze) + 2, 1);
}

void PrepareLimitOrder(MqlTradeRequest &lr, const int predicted_direction)
{
    double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    int minPts = GetMinPendingOffsetPoints();
    int offPts = MathMax(InpLimitOffsetPoints, minPts);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    bool isBuy = (predicted_direction>0);
    
    // Vérifier si c'est un symbole Boom/Crash pour optimiser les TP
    bool isBoomCrash = (StringFind(_Symbol, "BOOM") >= 0 || StringFind(_Symbol, "CRASH") >= 0);
    
    // A. Vérifier le type du prix (Bid / Ask / Market actuel)
    // Pour un Buy Limit : le prix limite doit être inférieur au prix actuel de marché (ask)
    // Pour un Sell Limit : le prix limite doit être supérieur au prix actuel de marché (bid)
    double rawPrice;
    if(isBuy) {
        // Buy Limit doit être < Ask
        rawPrice = ask - offPts * pt;
        if(rawPrice >= ask) {
            rawPrice = ask - (offPts + 5) * pt; // Forcer plus bas
            Print("⚠️ Ajustement prix BUY LIMIT: ", rawPrice, " < ", ask);
        }
    } else {
        // Sell Limit doit être > Bid
        rawPrice = bid + offPts * pt;
        if(rawPrice <= bid) {
            rawPrice = bid + (offPts + 5) * pt; // Forcer plus haut
            Print("⚠️ Ajustement prix SELL LIMIT: ", rawPrice, " > ", bid);
        }
    }
    
    // B. Vérifier le tick size / step et aligner
    if(tick_size > 0) {
        rawPrice = MathRound(rawPrice / tick_size) * tick_size;
    }
    lr.price = AlignToTick(rawPrice);
    
    // C. Vérifier la distance minimale par rapport au prix actuel
    double current_price = isBuy ? ask : bid;
    double min_distance = minPts * pt;
    double actual_distance = MathAbs(lr.price - current_price);
    
    if(actual_distance < min_distance) {
        if(isBuy) {
            lr.price = AlignToTick(current_price - min_distance);
        } else {
            lr.price = AlignToTick(current_price + min_distance);
        }
        Print("⚠️ Ajustement distance minimale: ", lr.price, " (distance: ", actual_distance, " < ", min_distance, ")");
    }
    
    // Validation finale des prix
    if(isBuy && lr.price >= ask) {
        lr.price = AlignToTick(ask - min_distance);
        Print("❌ Correction finale BUY LIMIT: ", lr.price, " < ", ask);
    } else if(!isBuy && lr.price <= bid) {
        lr.price = AlignToTick(bid + min_distance);
        Print("❌ Correction finale SELL LIMIT: ", lr.price, " > ", bid);
    }
    
    // Refus si spread trop élevé
    double spread_points = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))/pt;
    if((int)spread_points > InpMaxSpreadPoints) {
        Print("⏸ Spread trop élevé (", (int)spread_points, ">", InpMaxSpreadPoints, ") - ordre LIMIT annulé");
        lr.volume = 0; // sentinel: annulé par l'appelant
        return;
    }

    // Calculer SL/TP avec validation - TP optimisé pour Boom/Crash
    double sl=0.0, tp=0.0;
    if(isBoomCrash) {
        // TP optimisé pour Boom/Crash : plus agressif pour sortir gagnant
        int boom_crash_tp_points = GetBoomCrashTPPoints();
        double boom_crash_sl_ratio = GetBoomCrashSLRatio();
        ComputeSLTP(lr.price, isBuy, boom_crash_tp_points, boom_crash_sl_ratio, sl, tp);
        Print("🎯 BOOM/CRASH TP OPTIMISÉ: TP=", boom_crash_tp_points, " pts | SL ratio=", boom_crash_sl_ratio, " | Ratio R:R=1:", DoubleToString(1.0/boom_crash_sl_ratio, 1));
    } else {
    ComputeSLTP(lr.price, isBuy, InpLimitTPPoints, InpLimitSLtoTPMax, sl, tp);
    }
    
    // Validation des SL/TP
    if(sl > 0 && tp > 0) {
        // Vérifier que SL/TP respectent les distances minimales
        double sl_distance = MathAbs(sl - lr.price);
        double tp_distance = MathAbs(tp - lr.price);
        
        if(sl_distance < min_distance) {
            if(isBuy) {
                sl = AlignToTick(lr.price - min_distance);
            } else {
                sl = AlignToTick(lr.price + min_distance);
            }
            Print("⚠️ Ajustement SL distance: ", sl);
        }
        
        if(tp_distance < min_distance) {
            if(isBuy) {
                tp = AlignToTick(lr.price + min_distance);
            } else {
                tp = AlignToTick(lr.price - min_distance);
            }
            Print("⚠️ Ajustement TP distance: ", tp);
        }
    }
    
    // Exiger un R:R minimum
    double risk = MathAbs(lr.price - sl);
    double reward = MathAbs(tp - lr.price);
    double rr = (risk>0)? (reward/risk) : 0.0;
    if(rr < InpMinRiskReward) {
        Print("⏸ R:R insuffisant ", DoubleToString(rr,2), " < ", DoubleToString(InpMinRiskReward,2), " - ordre LIMIT annulé");
        lr.volume = 0; // sentinel: annulé par l'appelant
        return;
    }

    lr.sl = sl; 
    lr.tp = tp;
    
    // Log final
    Print("📋 ORDRE LIMIT PRÉPARÉ: Type=", (isBuy ? "BUY" : "SELL"), 
          " | Prix=", lr.price, " | SL=", lr.sl, " | TP=", lr.tp,
          " | Distance=", MathAbs(lr.price - current_price),
          " | Boom/Crash=", (isBoomCrash ? "OUI" : "NON"));
}

//+------------------------------------------------------------------+
//| Fonction spécifique pour détecter les indices Boom/Crash        |
//+------------------------------------------------------------------+
bool IsBoomCrashIndex(string symbol)
{
    string sym = symbol;
    StringToLower(sym);
    return (StringFind(sym, "boom") >= 0 || StringFind(sym, "crash") >= 0);
}

//+------------------------------------------------------------------+
//| Fonction pour calculer TP optimisé Boom/Crash                   |
//+------------------------------------------------------------------+
int GetBoomCrashTPPoints()
{
    // TP scalping rapide pour Boom/Crash : 15-30 points pour sécuriser rapidement
    int base_tp = InpLimitTPPoints;
    return MathMax(MathMin(base_tp, 30), 15);
}

//+------------------------------------------------------------------+
//| Fonction pour calculer SL optimisé Boom/Crash                   |
//+------------------------------------------------------------------+
double GetBoomCrashSLRatio()
{
    // SL scalping pour Boom/Crash : 40% du TP (ratio 1:2.5) - sécurisation rapide
    return 0.40;
}

//+------------------------------------------------------------------+
//| Calculer le ratio profit/SL pour un trade                       |
//+------------------------------------------------------------------+
double CalculateProfitSLRatio(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return 0.0;
    
    double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
    double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl = PositionGetDouble(POSITION_SL);
    double profit = PositionGetDouble(POSITION_PROFIT);
    double volume = PositionGetDouble(POSITION_VOLUME);
    
    if(sl == 0.0 || profit <= 0) return 0.0;
    
    // Calculer la distance SL en points
    double sl_distance = MathAbs(open_price - sl);
    if(sl_distance == 0) return 0.0;
    
    // Calculer la valeur d'un point
    double point_value = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_TRADE_TICK_VALUE);
    if(point_value == 0) point_value = 1.0; // Fallback
    
    // Calculer le profit en points
    double profit_points = 0;
    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
        profit_points = (current_price - open_price) / SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_POINT);
    } else {
        profit_points = (open_price - current_price) / SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_POINT);
    }
    
    // Calculer la distance SL en points
    double sl_points = sl_distance / SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_POINT);
    
    if(sl_points == 0) return 0.0;
    
    // Calculer le ratio profit/SL
    double profit_sl_ratio = profit_points / sl_points;
    
    return profit_sl_ratio;
}

//+------------------------------------------------------------------+
//| Enregistrer un échec de requête pour un symbole                 |
//+------------------------------------------------------------------+
void RecordRequestFail(string symbol)
{
    // Trouver ou créer une entrée pour ce symbole
    int index = -1;
    for(int i = 0; i < g_symbol_fail_count; i++) {
        if(g_symbol_fails[i].symbol == symbol) {
            index = i;
            break;
        }
    }
    
    if(index == -1) {
        // Créer une nouvelle entrée
        if(g_symbol_fail_count < 10) {
            index = g_symbol_fail_count;
            g_symbol_fails[index].symbol = symbol;
            g_symbol_fails[index].fail_count = 0;
            g_symbol_fails[index].lot_multiplier = 1.0;
            g_symbol_fail_count++;
        } else {
            return; // Pas de place pour plus de symboles
        }
    }
    
    // Incrémenter le compteur d'échecs
    g_symbol_fails[index].fail_count++;
    g_symbol_fails[index].last_fail_time = TimeCurrent();
    
    // Calculer le multiplicateur de lot (max 3.0)
    g_symbol_fails[index].lot_multiplier = MathMin(1.0 + (g_symbol_fails[index].fail_count * 0.5), 3.0);
    
    Print("📈 ÉCHEC ENREGISTRÉ: ", symbol, " | Échecs: ", g_symbol_fails[index].fail_count, 
          " | Multiplicateur lot: ", DoubleToString(g_symbol_fails[index].lot_multiplier, 2));
}

//+------------------------------------------------------------------+
//| Réinitialiser les échecs pour un symbole (après succès)         |
//+------------------------------------------------------------------+
void ResetRequestFails(string symbol)
{
    for(int i = 0; i < g_symbol_fail_count; i++) {
        if(g_symbol_fails[i].symbol == symbol) {
            g_symbol_fails[i].fail_count = 0;
            g_symbol_fails[i].lot_multiplier = 1.0;
            Print("🔄 ÉCHECS RÉINITIALISÉS: ", symbol);
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Obtenir le multiplicateur de lot pour un symbole                |
//+------------------------------------------------------------------+
double GetLotMultiplier(string symbol)
{
    for(int i = 0; i < g_symbol_fail_count; i++) {
        if(g_symbol_fails[i].symbol == symbol) {
            return g_symbol_fails[i].lot_multiplier;
        }
    }
    return 1.0; // Pas d'échecs enregistrés
}

//+------------------------------------------------------------------+
//| Calculer le lot avec multiplicateur d'échec                     |
//+------------------------------------------------------------------+
double CalculateLotWithFailMultiplier(string symbol, double base_lot)
{
    double multiplier = GetLotMultiplier(symbol);
    double adjusted_lot = base_lot * multiplier;
    
    // Respecter les limites du broker
    double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    adjusted_lot = MathMax(adjusted_lot, min_lot);
    adjusted_lot = MathMin(adjusted_lot, max_lot);
    
    // Aligner sur le step
    if(lot_step > 0) {
        adjusted_lot = MathFloor(adjusted_lot / lot_step) * lot_step;
    }
    
    if(multiplier > 1.0) {
        Print("📈 LOT AUGMENTÉ: ", symbol, " | Base: ", DoubleToString(base_lot, 2), 
              " | Multiplicateur: ", DoubleToString(multiplier, 2), 
              " | Final: ", DoubleToString(adjusted_lot, 2));
    }
    
    return adjusted_lot;
}

//+------------------------------------------------------------------+
//| Vérifier la confirmation de tendance pour Boom/Crash            |
//+------------------------------------------------------------------+
bool CheckTrendConfirmation(int predicted_direction)
{
    // Vérifier l'alignement des moyennes mobiles
    int ema9 = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
    int ema21 = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
    int ema50 = iMA(_Symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
    
    double ema9_values[3], ema21_values[3], ema50_values[3];
    if(CopyBuffer(ema9, 0, 0, 3, ema9_values) < 3) return false;
    if(CopyBuffer(ema21, 0, 0, 3, ema21_values) < 3) return false;
    if(CopyBuffer(ema50, 0, 0, 3, ema50_values) < 3) return false;
    
    // Vérifier l'alignement des EMAs
    bool ema_alignment = false;
    if(predicted_direction > 0) { // BOOM - tendance haussière
        ema_alignment = (ema9_values[0] > ema21_values[0] && ema21_values[0] > ema50_values[0]);
    } else { // CRASH - tendance baissière
        ema_alignment = (ema9_values[0] < ema21_values[0] && ema21_values[0] < ema50_values[0]);
    }
    
    // Vérifier le momentum avec RSI
    int rsi = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
    double rsi_values[3];
    if(CopyBuffer(rsi, 0, 0, 3, rsi_values) < 3) return false;
    
    bool rsi_confirmation = false;
    if(predicted_direction > 0) { // BOOM
        rsi_confirmation = (rsi_values[0] > 50 && rsi_values[0] > rsi_values[1]);
    } else { // CRASH
        rsi_confirmation = (rsi_values[0] < 50 && rsi_values[0] < rsi_values[1]);
    }
    
    // Vérifier la force de tendance via ADX
    int adx = iADX(_Symbol, PERIOD_M1, 14);
    double adx_values[2];
    if(CopyBuffer(adx, 0, 0, 2, adx_values) < 2) return false;
    bool adx_ok = (adx_values[0] >= InpMinADX);
    
    bool trend_confirmed = ema_alignment && rsi_confirmation && adx_ok;
    
    Print("🔍 CONFIRMATION TENDANCE: EMA=", ema_alignment, " | RSI=", rsi_confirmation, 
          " | ADX>=", InpMinADX, "? ", adx_ok, " | Résultat=", trend_confirmed);
    
    return trend_confirmed;
}

//+------------------------------------------------------------------+
//| Annoncer explicitement un spike sur BOOM/CRASH                   |
//+------------------------------------------------------------------+
void AnnounceBoomCrashSpike(int direction)
{
    if(!IsBoomCrashIndex(_Symbol)) return;
    // Debug: confirmer détection Boom/Crash au runtime
    Print("🔎 Detection Boom/Crash: ", _Symbol, " => ", (direction>0?"BUY (BOOM)":"SELL (CRASH)"));
    string dir_txt = (direction > 0) ? "BOOM" : "CRASH";
    string type_txt = (direction > 0) ? "SPIKE HAUSSIER" : "SPIKE BAISSIER";
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    string msg = StringFormat("📢 %s détecté sur %s | %s @ %s", type_txt, _Symbol, dir_txt, DoubleToString(price, _Digits));
    Print(msg);
    Alert(msg);
    PlayAlert("SPIKE");
    if(InpSendNotifications) SendMyNotification(msg);
}

//+------------------------------------------------------------------+
//| Pré-spike detector (Boom/Crash): compression + wick + ATR boost  |
//+------------------------------------------------------------------+
bool DetectPreSpike(int &direction, double &confidence)
{
    direction = 0; confidence = 0.0;
    if(!InpPreSpikeEnable) return false;
    if(!IsBoomCrashIndex(_Symbol)) return false;
    
    // Bollinger Bands width (compression)
    int bb_period = 20; double bb_dev = 2.0;
    int bb = iBands(_Symbol, InpTimeframe, bb_period, 0, bb_dev, PRICE_CLOSE);
    if(bb==INVALID_HANDLE) return false;
    double up[3], mid[3], lo[3];
    if(CopyBuffer(bb,0,0,3,up)<3 || CopyBuffer(bb,1,0,3,mid)<3 || CopyBuffer(bb,2,0,3,lo)<3){ IndicatorRelease(bb); return false; }
    double bbw = (up[0]-lo[0]) / MathMax(1e-8, mid[0]);
    
    // ATR vs moyenne
    int atr_period = 14;
    int atr = iATR(_Symbol, InpTimeframe, atr_period);
    if(atr==INVALID_HANDLE){ IndicatorRelease(bb); return false; }
    double a[]; ArrayResize(a, InpPreSpikeLookback); ArrayInitialize(a, 0.0);
    int n = CopyBuffer(atr,0,0,ArraySize(a),a);
    if(n<atr_period){ IndicatorRelease(bb); IndicatorRelease(atr); return false; }
    double atr_now = a[0];
    double atr_avg = 0.0; for(int i=1;i<n;i++) atr_avg += a[i]; atr_avg /= MathMax(1,n-1);
    
    // Wick/Body ratio sur N-1
    MqlRates r[2]; if(CopyRates(_Symbol, InpTimeframe, 0, 2, r)<2){ IndicatorRelease(bb); IndicatorRelease(atr); return false; }
    double body = MathAbs(r[1].close - r[1].open);
    double upper_wick = r[1].high - MathMax(r[1].close, r[1].open);
    double lower_wick = MathMin(r[1].close, r[1].open) - r[1].low;
    double wick_ratio_up = (body>0)? upper_wick/body : 0;
    double wick_ratio_dn = (body>0)? lower_wick/body : 0;
    
    bool compressed = (bbw <= InpPreSpikeBBWThreshold);
    bool atr_boost = (atr_now >= InpPreSpikeATRBoost * MathMax(1e-8, atr_avg));
    
    // CONDITIONS STRICTES POUR ÉVITER FAUX SIGNAUX
    // Direction: grande mèche haute => probabilité spike Crash (SELL); grande mèche basse => spike Boom (BUY)
    int dir = 0;
    if(wick_ratio_dn >= InpPreSpikeWickRatio) dir = 1; // Boom
    else if(wick_ratio_up >= InpPreSpikeWickRatio) dir = -1; // Crash
    
    double conf = 0.0;
    if(dir!=0){
        conf = 20.0; // Base plus faible
        
        // Compression BB obligatoire
        if(compressed) conf += 25.0;
        else return false; // Pas de signal sans compression
        
        // ATR boost obligatoire
        if(atr_boost) conf += 20.0;
        else return false; // Pas de signal sans ATR boost
        
        // Vérification volatilité récente (dernières 3 bougies)
        bool recent_volatility = false;
        for(int i = 0; i < 3; i++) {
            double range = r[i].high - r[i].low;
            if(range > atr_avg * 1.3) {
                recent_volatility = true;
                break;
            }
        }
        if(recent_volatility) conf += 15.0;
        else return false; // Pas de signal sans volatilité récente
        
        // EMA alignment strict (M5 ET M15)
        int ema5_dir = GetEmaCrossDirection(PERIOD_M5);
        int ema15_dir = GetEmaCrossDirection(PERIOD_M15);
        bool ema_aligned = false;
        
        if(dir > 0) { // BUY Boom
            ema_aligned = (ema5_dir > 0 && ema15_dir > 0);
        } else { // SELL Crash
            ema_aligned = (ema5_dir < 0 && ema15_dir < 0);
        }
        
        if(ema_aligned) conf += 15.0;
        else return false; // Pas de signal sans alignement EMA
        
        // RSI dans la bonne zone et direction
        int rsi_local = iRSI(_Symbol, InpTimeframe, 14, PRICE_CLOSE);
        if(rsi_local != INVALID_HANDLE) {
            double rsi_val[2];
            if(CopyBuffer(rsi_local, 0, 0, 2, rsi_val) >= 2) {
                bool rsi_ok = false;
                if(dir > 0) { // BUY Boom
                    rsi_ok = (rsi_val[0] > 45 && rsi_val[0] > rsi_val[1] && rsi_val[0] < 75);
                } else { // SELL Crash
                    rsi_ok = (rsi_val[0] < 55 && rsi_val[0] < rsi_val[1] && rsi_val[0] > 25);
                }
                if(rsi_ok) conf += 10.0;
                else return false; // Pas de signal si RSI pas favorable
            }
            IndicatorRelease(rsi_local);
        }
        
        // Cooldown entre signaux (5 minutes minimum)
        static datetime last_pre_spike_time = 0;
        if(TimeCurrent() - last_pre_spike_time < 300) {
            return false; // Signal trop récent
        }
        last_pre_spike_time = TimeCurrent();
    }
    
    IndicatorRelease(bb); IndicatorRelease(atr);
    if(dir!=0 && conf >= InpPreSpikeMinConfidence){ direction = dir; confidence = conf; return true; }
    return false;
}

//+------------------------------------------------------------------+
//| Détection timing optimal pour signaux Boom/Crash                |
//+------------------------------------------------------------------+
bool IsOptimalSpikeTiming(int direction)
{
    if(!IsBoomCrashIndex(_Symbol)) return false;
    
    // 1) Vérifier que le prix n'est pas déjà en mouvement rapide
    MqlRates current[2];
    if(CopyRates(_Symbol, InpTimeframe, 0, 2, current) < 2) return false;
    
    double current_range = current[0].high - current[0].low;
    double prev_range = current[1].high - current[1].low;
    
    // Si le range actuel est déjà très grand, on est peut-être trop tard
    if(current_range > prev_range * 2.0) {
        Print("⏸ Timing: Range actuel trop grand, spike peut-être déjà en cours");
        return false;
    }
    
    // 2) Vérifier la proximité des niveaux S/R
    double current_price = current[0].close;
    double nearest_support = 0.0; // GetNearestSupportLevel(current_price);
    double nearest_resistance = 0.0; // GetNearestResistanceLevel(current_price);
    
    // Vérification S/R simplifiée (fonctions GetNearestSupportLevel/GetNearestResistanceLevel non disponibles)
    // Pour l'instant, on skip cette vérification
    /*
    if(direction > 0) { // BUY Boom
        // Pour un BUY, on veut être proche du support mais pas trop
        double distance_to_support = MathAbs(current_price - nearest_support);
        double distance_to_resistance = MathAbs(current_price - nearest_resistance);
        
        if(distance_to_support > distance_to_resistance * 0.5) {
            Print("⏸ Timing BUY: Trop loin du support, trop proche de la résistance");
            return false;
        }
    } else { // SELL Crash
        // Pour un SELL, on veut être proche de la résistance mais pas trop
        double distance_to_support = MathAbs(current_price - nearest_support);
        double distance_to_resistance = MathAbs(current_price - nearest_resistance);
        
        if(distance_to_resistance > distance_to_support * 0.5) {
            Print("⏸ Timing SELL: Trop loin de la résistance, trop proche du support");
            return false;
        }
    }
    */
    
    // 3) Vérifier le momentum des dernières bougies
    MqlRates last_5[5];
    if(CopyRates(_Symbol, InpTimeframe, 0, 5, last_5) >= 5) {
        int bullish_candles = 0;
        int bearish_candles = 0;
        
        for(int i = 0; i < 5; i++) {
            if(last_5[i].close > last_5[i].open) bullish_candles++;
            else if(last_5[i].close < last_5[i].open) bearish_candles++;
        }
        
        if(direction > 0) { // BUY Boom
            if(bearish_candles >= 4) {
                Print("⏸ Timing BUY: Trop de bougies baissières récentes");
                return false;
            }
        } else { // SELL Crash
            if(bullish_candles >= 4) {
                Print("⏸ Timing SELL: Trop de bougies haussières récentes");
                return false;
            }
        }
    }
    
    // 4) Vérifier la vitesse de changement de prix
    double price_change_speed = MathAbs(current[0].close - current[1].close) / current[1].close;
    if(price_change_speed > 0.02) { // Plus de 2% de changement
        Print("⏸ Timing: Changement de prix trop rapide (", DoubleToString(price_change_speed*100, 2), "%)");
        return false;
    }
    
    Print("✅ Timing optimal validé pour ", (direction > 0 ? "BUY" : "SELL"));
    return true;
}
//+------------------------------------------------------------------+
//| Fermer automatiquement les trades à X% du SL (scalping)         |
//+------------------------------------------------------------------+
void CheckAutoCloseProfitableTrades()
{
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) continue;
        
        ulong ticket = active_trades[i].ticket;
        if(!PositionSelectByTicket(ticket)) continue;
        
        double profit = PositionGetDouble(POSITION_PROFIT);
        if(profit <= 0) continue; // Seulement les trades en profit
        
        double profit_sl_ratio = CalculateProfitSLRatio(ticket);
        
        // Log de débogage pour les trades en profit
        if(profit_sl_ratio > 0) {
            Print("🔍 TRADE SURVEILLANCE: ", ticket, " | Profit: $", DoubleToString(profit, 2), " | Ratio SL: ", DoubleToString(profit_sl_ratio * 100, 1), "%");
        }
        
        double close_threshold = MathMax(0.5, InpScalpCloseAtSLRatio); // sécurité min 50%
        if(profit_sl_ratio >= close_threshold) { // par défaut 150% du SL
            Print("🎯 FERMETURE SCALPING: Trade ", ticket, " à ", DoubleToString(profit_sl_ratio * 100, 1), "% du SL (seuil ", DoubleToString(close_threshold*100,0), "%) | profit: $", DoubleToString(profit, 2));
            
            // Fermer le trade
            MqlTradeRequest close_req;
            MqlTradeResult close_res;
            ZeroMemory(close_req);
            ZeroMemory(close_res);
            
            close_req.action = TRADE_ACTION_DEAL;
            close_req.position = ticket;
            close_req.symbol = PositionGetString(POSITION_SYMBOL);
            close_req.volume = PositionGetDouble(POSITION_VOLUME);
            close_req.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            close_req.magic = InpMagicNumber;
            close_req.comment = "AutoClose_200%SL";
            
            if(OrderSend(close_req, close_res)) {
                Print("✅ Trade fermé (scalping): ", ticket, " | Profit: $", DoubleToString(profit, 2), " | Ratio: ", DoubleToString(profit_sl_ratio * 100, 1), "%");
                
                if(InpSendNotifications) {
                    string direction_str = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
                    SendMyNotification("🎯 Scalping: fermeture auto " + direction_str + " " + PositionGetString(POSITION_SYMBOL) + " | Profit: $" + DoubleToString(profit, 2) + " | Ratio: " + DoubleToString(profit_sl_ratio * 100, 1) + "%");
                }
                
                // Retirer du tableau des trades actifs
                active_trades[i].ticket = 0;
                trade_count = MathMax(trade_count - 1, 0);
            } else {
                Print("❌ Échec fermeture auto: ", GetLastError(), " - ", close_res.comment);
            }
        }
    }
}

double NormalizeVolume(double vol)
{
    // Enforce broker min and project min 0.20
    double brokerMin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double v = MathMax(vol, MathMax(brokerMin, 0.20));
    if(step>0) v = MathFloor(v/step)*step; // round down to step
    return v;
}

//+------------------------------------------------------------------+
//| Sortie anticipée si profit ≥ X$ et tendance non uniforme         |
//+------------------------------------------------------------------+
void EnforceEarlyExitOnChop()
{
    double min_profit = MathMax(0.01, InpEarlyExitProfitUSD);
    for(int i=0; i<InpMaxTrades; i++){
        if(active_trades[i].ticket==0) continue;
        if(!PositionSelectByTicket(active_trades[i].ticket)) continue;
        double profit = PositionGetDouble(POSITION_PROFIT);
        if(profit < min_profit) continue;

        // Détecter tendance non uniforme via ADX et EMA croisement inverse récent
        int adx = iADX(_Symbol, PERIOD_M1, 14);
        double adxv[3]; if(CopyBuffer(adx, 0, 0, 3, adxv) < 3) continue;
        bool weak_trend = (adxv[0] < InpMinADX);

        int h9 = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
        int h21= iMA(_Symbol, PERIOD_M1, 21,0, MODE_EMA, PRICE_CLOSE);
        double b9[2], b21[2]; if(CopyBuffer(h9,0,0,2,b9)<2 || CopyBuffer(h21,0,0,2,b21)<2) continue;
        bool ema_chop = ((b9[0] >= b21[0] && b9[1] < b21[1]) || (b9[0] <= b21[0] && b9[1] > b21[1]));

        if(weak_trend || ema_chop){
            // Fermer la position pour sécuriser le gain
            ulong ticket = active_trades[i].ticket;
            string sym = PositionGetString(POSITION_SYMBOL);
            int ptype = (int)PositionGetInteger(POSITION_TYPE);
            double vol = PositionGetDouble(POSITION_VOLUME);
            MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
            rq.action = TRADE_ACTION_DEAL; rq.position = ticket; rq.symbol = sym; rq.volume = vol;
            rq.type = (ptype==POSITION_TYPE_BUY)? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            rq.magic = InpMagicNumber; rq.comment = "EarlyExitOnChop";
            if(OrderSend(rq, rs)){
                Print("✅ Sortie anticipée (tendance non uniforme) +$", DoubleToString(profit,2));
                if(InpSendNotifications) SendMyNotification(StringFormat("✅ Sortie anticipée %s +$%.2f (tendance non uniforme)", sym, profit));
            } else {
                Print("❌ Échec EarlyExitOnChop: ", GetLastError(), " - ", rs.comment);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifie si un ordre dans 'direction' est autorisé sur le symbole |
//| Bloque les ordres inverses simultanés (positions et LIMIT)       |
//+------------------------------------------------------------------+
bool CanPlaceDirectionForSymbol(int direction)
{
    // Positions existantes
    for(int i=PositionsTotal()-1; i>=0; i--)
    {
        if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
        if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
        if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
        int pos_dir = ((int)PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)? 1 : -1;
        if(pos_dir != direction) {
            Print("⏸ Ordre inverse existant sur ", _Symbol, ", on attend la fin avant de placer l'autre direction.");
            return false;
        }
    }
    // Ordres en attente (LIMIT) existants
    for(int i=OrdersTotal()-1; i>=0; i--)
    {
        ulong ot = OrderGetTicket(i);
        if(!OrderSelect(ot)) continue;
        if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
        if((int)OrderGetInteger(ORDER_MAGIC)!=InpMagicNumber) continue;
        long t = OrderGetInteger(ORDER_TYPE);
        if(t!=ORDER_TYPE_BUY_LIMIT && t!=ORDER_TYPE_SELL_LIMIT) continue;
        int ord_dir = (t==ORDER_TYPE_BUY_LIMIT)? 1 : -1;
        if(ord_dir != direction) {
            Print("⏸ Ordre LIMIT inverse déjà présent sur ", _Symbol, ", on attend avant de placer l'autre direction.");
            return false;
        }
    }
    return true;
}

//+------------------------------------------------------------------+
//| Biais de tendance courant (simple EMA9 vs EMA21)                 |
//+------------------------------------------------------------------+
int CurrentTrendBias()
{
    // Utiliser des handles globaux mis en cache pour éviter des fuites et détachements
    if(ema_fast_handle == INVALID_HANDLE)
        ema_fast_handle = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_slow_handle == INVALID_HANDLE)
        ema_slow_handle = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);

    double b9[1], b21[1];
    if(ema_fast_handle == INVALID_HANDLE || ema_slow_handle == INVALID_HANDLE) return 0;
    if(CopyBuffer(ema_fast_handle, 0, 0, 1, b9) < 1) return 0;
    if(CopyBuffer(ema_slow_handle, 0, 0, 1, b21) < 1) return 0;
    if(b9[0] > b21[0]) return 1;
    if(b9[0] < b21[0]) return -1;
    return 0;
}

//+------------------------------------------------------------------+
//| Règle directionnelle BOOM/CRASH: BOOM→BUY uniquement, CRASH→SELL |
//+------------------------------------------------------------------+
bool IsDirectionAllowedForSymbol(int direction)
{
    // direction: >0 BUY, <0 SELL
    string sym = _Symbol; StringToLower(sym);
    bool isBoom = (StringFind(sym, "boom") >= 0);
    bool isCrash = (StringFind(sym, "crash") >= 0);
    if(isBoom && direction < 0) return false;   // No SELL on BOOM
    if(isCrash && direction > 0) return false;  // No BUY on CRASH
    return true;
}

//+------------------------------------------------------------------+
//| Fermer toutes les positions d'un symbole                         |
//+------------------------------------------------------------------+
void CloseAllPositionsForSymbol(string symbol)
{
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong pos_ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(pos_ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

        int pos_type = (int)PositionGetInteger(POSITION_TYPE);
        double volume = PositionGetDouble(POSITION_VOLUME);
        string psym = PositionGetString(POSITION_SYMBOL);

        MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
        rq.action = TRADE_ACTION_DEAL;
        rq.position = pos_ticket;
        rq.symbol = psym;
        rq.volume = volume;
        rq.type = (pos_type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        rq.magic = InpMagicNumber;
        rq.comment = "DollarStop_CloseAll";
        bool ok = OrderSend(rq, rs);
        if(!ok)
            Print("❌ Échec fermeture position (", psym, "): ", GetLastError(), " - ", rs.comment);
    }
}

//+------------------------------------------------------------------+
//| Appliquer TP/SL en dollars par trade                             |
//+------------------------------------------------------------------+
void EnforceDollarStops()
{
    double tp_usd = MathMax(0.01, InpDollarTakeProfitPerTrade);
    double sl_usd = MathMax(0.01, InpDollarStopLossPerTrade);
    // Mode petit capital: utiliser TP/SL en dollars réduits
    double bal_now = AccountInfoDouble(ACCOUNT_BALANCE);
    bool is_micro_balance = (InpSmallBalanceMode && bal_now <= 10.0);
    if(InpSmallBalanceMode && bal_now <= InpSmallBalanceThreshold){
        tp_usd = MathMax(tp_usd, InpSmallTP_USD);
        sl_usd = MathMax(sl_usd, InpSmallSL_USD);
    }
    // Règle stricte spéciale < $10: TP $5, SL $2 et sortie marché
    if(is_micro_balance){
        tp_usd = 5.0;
        sl_usd = 2.0;
    }

    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) continue;
        if(!PositionSelectByTicket(active_trades[i].ticket)) continue;

        double profit = PositionGetDouble(POSITION_PROFIT);
        if(profit >= tp_usd) {
            // Fermer cette position (take profit $)
            ulong ticket = active_trades[i].ticket;
            int pos_type = (int)PositionGetInteger(POSITION_TYPE);
            double volume = PositionGetDouble(POSITION_VOLUME);
            MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
            rq.action = TRADE_ACTION_DEAL;
            rq.position = ticket;
            rq.symbol = _Symbol;
            rq.volume = volume;
            rq.type = (pos_type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            rq.magic = InpMagicNumber;
            rq.comment = "DollarTP_Close";
            if(OrderSend(rq, rs)) {
                Print("✅ Fermeture TP$ atteinte: ", _Symbol, " | +$", DoubleToString(profit,2));
                if(InpSendNotifications) SendMyNotification(StringFormat("✅ TP$ atteint: %s +$%.2f", _Symbol, profit));
                // Ré-entrée immédiate si activée et si prédiction active
                if(InpReenterOnDollarTP && profit >= InpReenterProfitUSD && current_prediction.is_active && !(InpRespectDailyStop && daily_stop_triggered)) {
                    int dir = current_prediction.predicted_direction;
                    if(IsBoomCrashIndex(_Symbol)){
                        if(!IsDirectionAllowedForSymbol(dir)) dir = 0;
                    }
                    if(dir!=0 && CanOpenTradeForSymbol(_Symbol)){
                        double lot = CalculateLotSize(_Symbol);
                        if(lot>0){
                            if(InpUseLimitOrders){
                                double ref_price = (dir>0)? SymbolInfoDouble(_Symbol, SYMBOL_BID): SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                PlaceLimitOrderForSymbol(_Symbol, dir, lot, ref_price);
                            } else {
                                PlaceMarketOrderForSymbol(_Symbol, dir, lot);
                            }
                            Print("🔄 Ré-entrée après TP$: ", _Symbol, " dir=", (dir>0?"BUY":"SELL"));
                        }
                    }
                }

                // Mettre à jour PnL jour/semaine et appliquer stop journalier éventuel
                day_realized_profit += profit;
                week_realized_profit += profit;
                if(InpRespectDailyStop){
                    double target = (InpDailyProfitTargetPct/100.0) * MathMax(1.0, day_start_balance);
                    if(day_realized_profit >= target){
                        daily_stop_triggered = true;
                        Print("🛑 Objectif journalier atteint: +$", DoubleToString(day_realized_profit,2), " (seuil +$", DoubleToString(target,2), ") - arrêt des nouveaux trades.");
                        if(InpSendNotifications) SendMyNotification(StringFormat("🛑 Objectif journalier atteint: +$%.2f (seuil +$%.2f) - arrêt trading", day_realized_profit, target));
                    }
                }
                // Règle spéciale < $10: quitter le marché après TP
                if(is_micro_balance){
                    daily_stop_triggered = true;
                    Print("🛑 Balance <= $10: TP$ atteint (+$", DoubleToString(profit,2), ") - arrêt des nouveaux trades pour aujourd'hui.");
                    if(InpSendNotifications) SendMyNotification("🛑 Balance <= $10: TP$ atteint - arrêt trading pour aujourd'hui");
                }
            }
        } else if(profit <= -sl_usd) {
            // Fermer uniquement cette position (stop loss $ par trade)
            ulong ticket = active_trades[i].ticket;
            int pos_type = (int)PositionGetInteger(POSITION_TYPE);
            double volume = PositionGetDouble(POSITION_VOLUME);
            string psym = PositionGetString(POSITION_SYMBOL);
            MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
            rq.action = TRADE_ACTION_DEAL;
            rq.position = ticket;
            rq.symbol = psym;
            rq.volume = volume;
            rq.type = (pos_type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            rq.magic = InpMagicNumber;
            rq.comment = "DollarSL_Close";
            bool ok = OrderSend(rq, rs);
            if(ok) {
                Print("❌ Fermeture SL$ par trade: ", psym, " -$", DoubleToString(-profit,2));
                if(InpSendNotifications) SendMyNotification(StringFormat("❌ SL$ atteint: %s -$%.2f (trade fermé)", psym, -profit));
                // Règle spéciale < $10: quitter le marché après SL
                if(is_micro_balance){
                    daily_stop_triggered = true;
                    Print("🛑 Balance <= $10: SL$ atteint (-$", DoubleToString(-profit,2), ") - arrêt des nouveaux trades pour aujourd'hui.");
                    if(InpSendNotifications) SendMyNotification("🛑 Balance <= $10: SL$ atteint - arrêt trading pour aujourd'hui");
                }
            } else {
                Print("❌ Échec fermeture SL$ par trade: ", GetLastError(), " - ", rs.comment);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Fermer des positions si la perte flottante totale > seuil        |
//+------------------------------------------------------------------+
void EnforceGlobalMaxFloatLoss()
{
    double max_loss_limit = MathMax(0.01, InpGlobalMaxLossUSD);
    // Calculer perte flottante totale des positions de l'EA
    double total_float = 0.0;
    int total_positions = PositionsTotal();
    // Collecter positions EA avec pertes
    struct LossPos { ulong ticket; string symbol; double loss; int type; double volume; };
    LossPos losers[64]; int nlos=0;
    for(int i = 0; i < total_positions; i++) {
        ulong t = PositionGetTicket(i);
        if(!PositionSelectByTicket(t)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        double p = PositionGetDouble(POSITION_PROFIT);
        total_float += p;
        if(p < 0 && nlos < 64) {
            losers[nlos].ticket = t;
            losers[nlos].symbol = PositionGetString(POSITION_SYMBOL);
            losers[nlos].loss = p;
            losers[nlos].type = (int)PositionGetInteger(POSITION_TYPE);
            losers[nlos].volume = PositionGetDouble(POSITION_VOLUME);
            nlos++;
        }
    }
    if(total_float >= -max_loss_limit) return; // OK
    Print("⚠️ Perte flottante totale: $", DoubleToString(total_float,2), " < -", DoubleToString(max_loss_limit,2), " → réduction des pertes");
    
    // Trier perdants par perte croissante (plus négatif en premier)
    for(int a=0; a<nlos; a++){
        for(int b=a+1; b<nlos; b++){
            if(losers[b].loss < losers[a].loss){ LossPos tmp=losers[a]; losers[a]=losers[b]; losers[b]=tmp; }
        }
    }
    
    // Fermer TOUT de l'EA si le plafond est dépassé
    for(int i=0; i<nlos; i++){
        if(!PositionSelectByTicket(losers[i].ticket)) continue;
        MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
        rq.action = TRADE_ACTION_DEAL;
        rq.position = losers[i].ticket;
        rq.symbol = losers[i].symbol;
        rq.volume = losers[i].volume;
        rq.type = (losers[i].type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        rq.magic = InpMagicNumber;
        rq.comment = "GlobalLoss_Cut";
        bool ok = OrderSend(rq, rs);
        if(ok){
            Print("✂️ Fermeture pour respect du plafond pertes: ", losers[i].symbol, " ticket ", losers[i].ticket);
        } else {
            Print("❌ Échec fermeture perte globale: ", GetLastError(), " - ", rs.comment);
        }
    }

    // Supprimer également les ordres en attente de l'EA
    for(int oi=OrdersTotal()-1; oi>=0; oi--){
        ulong ot = OrderGetTicket(oi);
        if(!OrderSelect(ot)) continue;
        if((int)OrderGetInteger(ORDER_MAGIC)!=InpMagicNumber) continue;
        string osym = OrderGetString(ORDER_SYMBOL);
        long otype = OrderGetInteger(ORDER_TYPE);
        if(otype==ORDER_TYPE_BUY_LIMIT || otype==ORDER_TYPE_SELL_LIMIT || otype==ORDER_TYPE_BUY_STOP || otype==ORDER_TYPE_SELL_STOP){
            MqlTradeRequest drq; MqlTradeResult drs; ZeroMemory(drq); ZeroMemory(drs);
            drq.action = TRADE_ACTION_REMOVE; // suppression d'un ordre en attente
            drq.order = ot;
            drq.magic = InpMagicNumber;
            if(!OrderSend(drq, drs)){
                Print("❌ Échec suppression ordre en attente: ", osym, " ticket ", ot, " err=", GetLastError(), " - ", drs.comment);
            } else {
                Print("🛑 Ordre en attente supprimé: ", osym, " ticket ", ot);
            }
        }
    }
}

int g_pending_limits = 0; // compteur simple des LIMIT envoyées par l'EA

// Variables pour l'augmentation de lot en cas d'échec
struct SymbolFailData {
    string symbol;
    int fail_count;
    double lot_multiplier;
    datetime last_fail_time;
};

SymbolFailData g_symbol_fails[10]; // Maximum 10 symboles
int g_symbol_fail_count = 0;

int CountMyOpenPositions()
{
    int count = 0;
    int total = PositionsTotal();
    for(int idx = 0; idx < total; idx++)
    {
        ulong ticket = PositionGetTicket(idx);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Compter les trades ouverts pour un symbole spécifique           |
//+------------------------------------------------------------------+
int CountOpenPositionsForSymbol(string symbol)
{
    int count = 0;
    int total = PositionsTotal();
    for(int idx = 0; idx < total; idx++)
    {
        ulong ticket = PositionGetTicket(idx);
        if(ticket == 0) continue;
        if(!PositionSelectByTicket(ticket)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        string pos_symbol = PositionGetString(POSITION_SYMBOL);
        if(pos_symbol != symbol) continue;
        count++;
    }
    return count;
}

//+------------------------------------------------------------------+
//| Vérifier si on peut ouvrir un nouveau trade pour un symbole     |
//+------------------------------------------------------------------+

void UpdateProximityDisplay(const double prox)
{
    // Create label if missing
    if(ObjectFind(0, g_prox_obj) == -1)
    {
        ObjectCreate(0, g_prox_obj, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, g_prox_obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, g_prox_obj, OBJPROP_XDISTANCE, 12);
        ObjectSetInteger(0, g_prox_obj, OBJPROP_YDISTANCE, 60);
        ObjectSetInteger(0, g_prox_obj, OBJPROP_BACK, false);
        ObjectSetInteger(0, g_prox_obj, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, g_prox_obj, OBJPROP_HIDDEN, true);
    }
    string txt = StringFormat("Nearest S/R: %.2f%%", prox*100.0);
    ObjectSetString(0, g_prox_obj, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, g_prox_obj, OBJPROP_COLOR, clrSilver);
    ObjectSetInteger(0, g_prox_obj, OBJPROP_FONTSIZE, 12);
    ObjectSetString(0, g_prox_obj, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| MTF Support/Resistance detection and drawing                      |
//+------------------------------------------------------------------+
double NormalizeToPips(double price){ double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT); return price; }

bool GetSwingHighLow(const ENUM_TIMEFRAMES tf, const int lookback, double &outHigh, double &outLow)
{
    double h[], l[]; ArraySetAsSeries(h,true); ArraySetAsSeries(l,true);
    if(CopyHigh(_Symbol, tf, 0, lookback, h) < 0) return false;
    if(CopyLow(_Symbol, tf, 0, lookback, l) < 0) return false;
    outHigh = h[ArrayMaximum(h, 0, lookback)];
    outLow  = l[ArrayMinimum(l, 0, lookback)];
    return true;
}

void DrawLevel(const string prefix, const color col, const double price)
{
    string name = StringFormat("%s_%.5f", prefix, price);
    if(ObjectFind(0, name) == -1)
    {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
        ObjectSetInteger(0, name, OBJPROP_COLOR, col);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
    }
}

void UpdateMTFSupportResistance()
{
    struct TFConf { ENUM_TIMEFRAMES tf; string tag; color col; };
    TFConf tfs[5];
    tfs[0].tf=PERIOD_H4; tfs[0].tag="H4"; tfs[0].col=clrCrimson;
    tfs[1].tf=PERIOD_H1; tfs[1].tag="H1"; tfs[1].col=clrOrangeRed;
    tfs[2].tf=PERIOD_M30; tfs[2].tag="M30"; tfs[2].col=clrDarkOrange;
    tfs[3].tf=PERIOD_M15; tfs[3].tag="M15"; tfs[3].col=clrGoldenrod;
    tfs[4].tf=PERIOD_M5; tfs[4].tag="M5"; tfs[4].col=clrOlive;

    for(int i=0;i<5;i++)
    {
        double hi=0, lo=0;
        if(GetSwingHighLow(tfs[i].tf, 100, hi, lo))
        {
            DrawLevel("SR_"+tfs[i].tag+"_RES", tfs[i].col, hi);
            DrawLevel("SR_"+tfs[i].tag+"_SUP", tfs[i].col, lo);
        }
    }
}

double ProximityToMTFLevelsPct(const double price)
{
    double best = 1e9;
    string prefixes[10]; int n=0;
    prefixes[n++]="SR_H4_RES"; prefixes[n++]="SR_H4_SUP";
    prefixes[n++]="SR_H1_RES"; prefixes[n++]="SR_H1_SUP";
    prefixes[n++]="SR_M30_RES"; prefixes[n++]="SR_M30_SUP";
    prefixes[n++]="SR_M15_RES"; prefixes[n++]="SR_M15_SUP";
    prefixes[n++]="SR_M5_RES";  prefixes[n++]="SR_M5_SUP";
    for(int i=0;i<n;i++)
    {
        // We iterate objects and match prefix
        for(int k=ObjectsTotal(0)-1;k>=0;k--)
        {
            string name = ObjectName(0,k);
            if(StringFind(name, prefixes[i])==0) {
                double lvl = ObjectGetDouble(0, name, OBJPROP_PRICE);
                double d = MathAbs((price - lvl)/price);
                if(d < best) best = d;
            }
        }
    }
    if(best==1e9) return 1.0; // none
    return best;
}

//+------------------------------------------------------------------+
//| Helper: EMA cross direction on a timeframe                        |
//| return 1 (up), -1 (down), 0 (unknown)                             |
//+------------------------------------------------------------------+
int GetEmaCrossDirection(const ENUM_TIMEFRAMES tf)
{
    int hFast = iMA(_Symbol, tf, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
    int hSlow = iMA(_Symbol, tf, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
    if(hFast==INVALID_HANDLE || hSlow==INVALID_HANDLE) return 0;
    double bufF[], bufS[]; ArraySetAsSeries(bufF,true); ArraySetAsSeries(bufS,true);
    ArrayResize(bufF,2); ArrayResize(bufS,2);
    if(CopyBuffer(hFast, 0, 0, 2, bufF) < 0) { IndicatorRelease(hFast); IndicatorRelease(hSlow); return 0; }
    if(CopyBuffer(hSlow, 0, 0, 2, bufS) < 0) { IndicatorRelease(hFast); IndicatorRelease(hSlow); return 0; }
    IndicatorRelease(hFast);
    IndicatorRelease(hSlow);
    if(bufF[0] > bufS[0]) return 1;
    if(bufF[0] < bufS[0]) return -1;
    return 0;
}

//+------------------------------------------------------------------+
//| Equal Highs/Lows detection + sweep                                |
//+------------------------------------------------------------------+
bool HasEqualHighs(const ENUM_TIMEFRAMES tf)
{
    double h[]; ArraySetAsSeries(h,true);
    if(CopyHigh(_Symbol, tf, 0, InpEqualHLWindow, h) < 0) return false;
    double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    for(int i=1;i<InpEqualHLWindow && i+1<ArraySize(h);i++)
    {
        if(MathAbs(h[i] - h[i+1]) <= InpEqualHLTolerancePts*pt)
            return true;
    }
    return false;
}

bool HasEqualLows(const ENUM_TIMEFRAMES tf)
{
    double l[]; ArraySetAsSeries(l,true);
    if(CopyLow(_Symbol, tf, 0, InpEqualHLWindow, l) < 0) return false;
    double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    for(int i=1;i<InpEqualHLWindow && i+1<ArraySize(l);i++)
    {
        if(MathAbs(l[i] - l[i+1]) <= InpEqualHLTolerancePts*pt)
            return true;
    }
    return false;
}

bool LiquiditySweepUp(const ENUM_TIMEFRAMES tf)
{
    // breakout au-dessus du plus haut précédent suivi d'un repli
    double h[]; ArraySetAsSeries(h,true);
    if(CopyHigh(_Symbol, tf, 0, 5, h) < 0) return false;
    return (h[0] > h[1] && h[1] <= h[2]);
}

bool LiquiditySweepDown(const ENUM_TIMEFRAMES tf)
{
    double l[]; ArraySetAsSeries(l,true);
    if(CopyLow(_Symbol, tf, 0, 5, l) < 0) return false;
    return (l[0] < l[1] && l[1] >= l[2]);
}

//+------------------------------------------------------------------+
//| FVG detection (simple, body gaps)                                 |
//+------------------------------------------------------------------+
bool HasRecentBullFVG(const ENUM_TIMEFRAMES tf)
{
    double o[], c[]; ArraySetAsSeries(o,true); ArraySetAsSeries(c,true);
    if(CopyOpen(_Symbol, tf, 0, InpFVGLookback, o) < 0) return false;
    if(CopyClose(_Symbol, tf, 0, InpFVGLookback, c) < 0) return false;
    for(int i=2;i<InpFVGLookback;i++)
    {
        // Bull FVG: c[i] < o[i-2]
        if(c[i] < o[i-2]) return true;
    }
    return false;
}

bool HasRecentBearFVG(const ENUM_TIMEFRAMES tf)
{
    double o[], c[]; ArraySetAsSeries(o,true); ArraySetAsSeries(c,true);
    if(CopyOpen(_Symbol, tf, 0, InpFVGLookback, o) < 0) return false;
    if(CopyClose(_Symbol, tf, 0, InpFVGLookback, c) < 0) return false;
    for(int i=2;i<InpFVGLookback;i++)
    {
        // Bear FVG: o[i] > c[i-2]
        if(o[i] > c[i-2]) return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Confluence score                                                  |
//+------------------------------------------------------------------+
double ComputeConfluenceScore(const int predicted_direction,
                              const double prox_pct,
                              const double atr_ratio,
                              const double bbw,
                              const double body_z,
                              const bool has_fvg,
                              const bool has_equal_hl,
                              const bool swept_liquidity,
                              const bool mtf_ok)
{
    double score = 0.0;
    // S/R proximité (plus proche => mieux)
    double sr_score = MathMax(0.0, 1.0 - (prox_pct / MathMax(0.0001, InpSRMinProximityPct)));
    score += InpSRWeight * sr_score;
    // ATR_ratio
    double atr_s = MathMin(1.0, MathMax(0.0, (atr_ratio-1.0)/0.5));
    score += 0.15 * atr_s;
    // BBW
    double bbw_s = MathMin(1.0, bbw*4.0);
    score += 0.10 * bbw_s;
    // body_z
    double bz_s = MathMin(1.0, MathMax(0.0, (body_z-2.0)/2.0));
    score += 0.15 * bz_s;
    // FVG + Equal HL + Sweep
    if(has_fvg) score += InpOTEWeight; // réutilise poids OTE pour FVG confluence
    if(has_equal_hl) score += 0.10;
    if(swept_liquidity) score += InpBOSWeight; // assimilé à BOS/CHoCH rapide
    // MTF trend OK
    if(mtf_ok) score += 0.10;
    return MathMin(score, 1.0);
}

//--- Détection mouvement en escalier
// Variables escalier supprimées

//+------------------------------------------------------------------+
//| Expert initialization function avec gestion d'erreurs robuste    |
//+------------------------------------------------------------------+
int OnInit()
{
    ea_startup_time = TimeCurrent();
    ea_fully_initialized = false;

    // Initialiser suivi journalier/hebdomadaire
    MqlDateTime mt; TimeToStruct(TimeCurrent(), mt);
    mt.hour = 0; mt.min = 0; mt.sec = 0;
    day_start_time = StructToTime(mt);
    day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    day_realized_profit = 0.0;
    // Semaine: fixer au lundi 00:00
    int dow = mt.day_of_week;
    datetime now = TimeCurrent();
    week_start_time = now - (dow==0?6:(dow-1))*24*60*60; // ramener au lundi même heure
    MqlDateTime mw; TimeToStruct(week_start_time, mw);
    mw.hour=0; mw.min=0; mw.sec=0; week_start_time = StructToTime(mw);
    week_realized_profit = 0.0;
    daily_stop_triggered = false;
    
    if(InpLogVerbosity >= 1) Print("🚀 Initialisation de SpikeHunter EA v2.0...");

    // Installer un timer pour garantir des réessais même sans ticks
    EventSetTimer(2);
    
    //--- Vérification des paramètres avec messages détaillés
    if(InpMaxTrades <= 0) {
        Print("❌ ERREUR: Nombre maximum de trades doit être > 0 (actuel: ", InpMaxTrades, ") (soft-block)");
        g_soft_block = true; g_block_msg = "Paramètres invalides: InpMaxTrades";
    }
    if(InpUserCapital < 13.0) {
        Print("❌ ERREUR: Capital utilisateur minimum requis: $13 (actuel: $", InpUserCapital, ") (soft-block)");
        g_soft_block = true; g_block_msg = "Paramètres invalides: InpUserCapital";
    }
    if(InpBaseLotSize <= 0) {
        Print("❌ ERREUR: Taille de base des lots doit être > 0 (actuel: ", InpBaseLotSize, ") (soft-block)");
        g_soft_block = true; g_block_msg = "Paramètres invalides: InpBaseLotSize";
    }
    if(InpStopLoss < 0) {
        Print("❌ ERREUR: Stop Loss ne peut pas être négatif (actuel: ", InpStopLoss, ") (soft-block)");
        g_soft_block = true; g_block_msg = "Paramètres invalides: InpStopLoss";
    }
    if(InpTakeProfit < 0) {
        Print("❌ ERREUR: Take Profit ne peut pas être négatif (actuel: ", InpTakeProfit, ") (soft-block)");
        g_soft_block = true; g_block_msg = "Paramètres invalides: InpTakeProfit";
    }
    if(InpRiskPercent <= 0 || InpRiskPercent > 10) {
        Print("❌ ERREUR: Pourcentage de risque doit être entre 0.1% et 10% (actuel: ", InpRiskPercent, "%) (soft-block)");
        g_soft_block = true; g_block_msg = "Paramètres invalides: InpRiskPercent";
    }
    
    //--- Vérification des permissions de trading
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        Print("❌ ERREUR: Trading non autorisé dans le terminal! (soft-block)");
        g_soft_block = true; g_block_msg = "Trading non autorisé dans le terminal";
        // Ne pas retourner INIT_FAILED: on laisse l'EA attaché et on réessaiera plus tard
    }
    
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
        Print("❌ ERREUR: Trading non autorisé pour les EAs! (soft-block)");
        g_soft_block = true; g_block_msg = "EA trading non autorisé";
    }
    
    if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
        Print("❌ ERREUR: Trading non autorisé sur ce compte! (soft-block)");
        g_soft_block = true; g_block_msg = "Trading non autorisé sur ce compte";
    }
    
    //--- Vérification de la connexion au serveur
    if(!TerminalInfoInteger(TERMINAL_CONNECTED)) {
        Print("❌ ERREUR: Terminal non connecté au serveur! (soft-block)");
        g_soft_block = true; g_block_msg = "Terminal non connecté";
    }
    
    //--- Vérification des informations du symbole
    if(!SymbolSelect(_Symbol, true)) {
        Print("❌ ERREUR: Impossible de sélectionner le symbole ", _Symbol, " (soft-block)");
        Print("💡 Vérifiez que le symbole est disponible dans Market Watch");
        g_soft_block = true; g_block_msg = "Symbole non disponible";
    }
    
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    if(min_lot <= 0 || max_lot <= 0) {
        Print("❌ ERREUR: Informations de lot invalides pour ", _Symbol, " (soft-block)");
        Print("💡 Min lot: ", min_lot, " Max lot: ", max_lot);
        g_soft_block = true; g_block_msg = "Infos lot invalides";
    }
    
    if(InpLogVerbosity >= 1) {
        Print("📊 Symbole: ", _Symbol, " | Min lot: ", min_lot, " | Max lot: ", max_lot);
    }
    
    adjusted_base_lot_size = InpBaseLotSize;
    if(InpBaseLotSize < min_lot) {
        Print("⚠️ ATTENTION: Taille de lot de base (", InpBaseLotSize, ") < minimum broker (", min_lot, ") - Ajustement automatique");
        adjusted_base_lot_size = min_lot;
    }
    
    if(InpBaseLotSize > max_lot) {
        Print("⚠️ ATTENTION: Taille de lot de base (", InpBaseLotSize, ") > maximum broker (", max_lot, ") - Ajustement automatique");
        adjusted_base_lot_size = max_lot;
    }

    //--- Initialisation des indicateurs (paresseuse si activée)
    spike_detection_handle = INVALID_HANDLE;
    
    if(!InpLazyInitialization) {
        if(InpLogVerbosity >= 1) Print("🔧 Création des indicateurs...");
    ma_handle = iMA(_Symbol, InpTimeframe, InpReversalDetection, 0, MODE_EMA, PRICE_CLOSE);
    if(ma_handle == INVALID_HANDLE) {
            Print("❌ ERREUR: Impossible de créer l'indicateur MA pour ", _Symbol, " (soft-block)");
            g_soft_block = true; g_block_msg = "MA handle invalide";
    }
    rsi_handle = iRSI(_Symbol, InpTimeframe, 14, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) {
            Print("❌ ERREUR: Impossible de créer l'indicateur RSI pour ", _Symbol, " (soft-block)");
            if(ma_handle!=INVALID_HANDLE) IndicatorRelease(ma_handle);
            g_soft_block = true; g_block_msg = "RSI handle invalide";
        }
        if(InpLogVerbosity >= 1) Print("✅ Indicateurs MA et RSI créés avec succès");
    } else {
        ma_handle = INVALID_HANDLE;
        rsi_handle = INVALID_HANDLE;
        if(InpLogVerbosity >= 1) Print("⚡ Initialisation paresseuse activée - indicateurs créés à la demande");
    }

    //--- Initialisation des buffers
    ArraySetAsSeries(spike_buffer, true);
    ArraySetAsSeries(ma_buffer, true);
    ArraySetAsSeries(rsi_buffer, true);

    //--- Initialisation du tableau des trades
                ArrayResize(active_trades, InpMaxTrades);
                for(int i = 0; i < InpMaxTrades; i++) {
                    active_trades[i].ticket = 0;
                    active_trades[i].open_time = 0;
                    active_trades[i].open_price = 0.0;
                    active_trades[i].lot_size = 0.0;
                    active_trades[i].direction = 0;
                    active_trades[i].is_spike_trade = false;
                    active_trades[i].spike_start_price = 0.0;
                    active_trades[i].profit_target = 0.0;
                    active_trades[i].loss_limit = 0.0;
                }

                //--- Initialisation des variables de gestion
                current_lot_size = adjusted_base_lot_size;
                consecutive_losses = 0;
                total_profit = 0;
                total_loss = 0;
                account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
                account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
daily_loss = 0;
last_daily_reset = TimeCurrent();
                
                //--- Initialisation des variables du panneau
                total_trades = 0;
                winning_trades = 0;
                losing_trades = 0;
                max_profit = 0;
                max_loss = 0;
                win_rate = 0;
                last_trade_time = 0;
                last_alert = "";
                
                //--- Initialisation des variables de l'application
                last_app_check = 0;
                last_app_signal = "";
                app_signal_received = false;
                
                //--- Initialisation des variables de prédiction
                current_prediction.predicted_time = 0;
                current_prediction.predicted_direction = 0;
                current_prediction.confidence = 0.0;
                current_prediction.duration_seconds = 0;
                current_prediction.is_active = false;
                last_prediction_time = 0;
                total_predictions = 0;
                successful_predictions = 0;
                
                //--- Initialisation des variables d'autoscan
                last_autoscan_time = 0;
                autoscan_signals_sent = 0;
                last_autoscan_signal = "";
                
                //--- Initialisation des supports et résistances
                for(int i = 0; i < 20; i++) {
                    support_levels[i].level = 0;
                    support_levels[i].strength = 0;
                    support_levels[i].last_touch = 0;
                    support_levels[i].is_support = true;
                    support_levels[i].is_confirmed = false;
                    support_levels[i].name = "";
                    support_levels[i].touch_count = 0;
                    
                    resistance_levels[i].level = 0;
                    resistance_levels[i].strength = 0;
                    resistance_levels[i].last_touch = 0;
                    resistance_levels[i].is_support = false;
                    resistance_levels[i].is_confirmed = false;
                    resistance_levels[i].name = "";
                    resistance_levels[i].touch_count = 0;
                }
                support_count = 0;
                resistance_count = 0;

                //--- Attacher l'indicateur visuel Squeeze (sous-fenêtre 1) - paresseux uniquement
                if(InpAttachSqueezeIndicator && false)
                {
                    squeeze_handle = iCustom(_Symbol, InpTimeframe, "SpikeHunter_Squeeze_Indicator",
                                            InpBBPeriod, InpBBDeviation, InpBodyZWindow,
                                            InpEMAFast, InpEMASlow, InpATRShort, InpATRLong,
                                            InpShowIndicatorArrows,
                                            InpSqueezeFactor, InpATRFactor, InpBodyZThresh,
                                            InpExtremeWindow, InpExtremeMax);
                    if(squeeze_handle!=INVALID_HANDLE)
                    {
                        if(!ChartIndicatorAdd(ChartID(), 1, squeeze_handle))
                            Print("[EA] ChartIndicatorAdd échoué pour SpikeHunter_Squeeze_Indicator");
                    }
                    else
                    {
                        Print("[EA] iCustom handle invalide pour SpikeHunter_Squeeze_Indicator");
                    }
                } else if(InpLazyInitialization) {
                    squeeze_handle = INVALID_HANDLE;
                }

                //--- Initialisation des variables Streamlit
                last_streamlit_check = 0;
                streamlit_timeframes = "M1,M5,M15,M30,H1";
                streamlit_supports = "";
                streamlit_resistances = "";

                //--- Initialisation des variables de détection
                last_level_detection = 0;
                last_high = 0;
                last_low = 0;
                last_high_time = 0;
                last_low_time = 0;
                ArrayInitialize(price_history, 0);
                history_index = 0;
                last_history_update = 0;

    if(InpLogVerbosity >= 1) {
        Print("✅ SpikeHunter EA initialisé avec succès");
        Print("📊 Configuration: Trade All Symbols=", InpTradeAllSymbols);
        Print("🎯 Max Trades: ", InpMaxTrades, " Min Capital: $", InpMinCapital, " Max Loss: $", InpMaxLossPerTrade);
        Print("📈 Risk Management: ", InpUseRiskManagement, " Risk %: ", InpRiskPercent, "%");
        Print("💰 Lot Size: ", adjusted_base_lot_size, " (base: ", InpBaseLotSize, ")");
        Print("🔧 Indicateurs: ", (InpLazyInitialization ? "Paresseux" : "Immédiat"));
        if(InpLazyInitialization) Print("⚡ Mode initialisation paresseuse activé - délai: ", InpStartupDelaySec, "s");
    }
    
    //--- Test de fonctionnement basique
    if(g_soft_block){
        Print("⛔ Soft-Block actif: ", g_block_msg, " | L'EA reste attaché et réessaiera");
    } else {
        Print("🚀 EA prêt - Attendez ", InpStartupDelaySec, " secondes avant le trading...");
    }

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Retirer le timer
    EventKillTimer();
    //--- Libération des handles
    if(spike_detection_handle != INVALID_HANDLE)
        IndicatorRelease(spike_detection_handle);
    if(ma_handle != INVALID_HANDLE)
        IndicatorRelease(ma_handle);
    if(rsi_handle != INVALID_HANDLE)
        IndicatorRelease(rsi_handle);
    if(ema_fast_handle != INVALID_HANDLE)
        IndicatorRelease(ema_fast_handle);
    if(ema_slow_handle != INVALID_HANDLE)
        IndicatorRelease(ema_slow_handle);

    //--- Nettoyage des objets graphiques
    ObjectsDeleteAll(0, "SpikePrediction_");
    ObjectsDeleteAll(0, "SpikeText_");

    //--- Nettoyage des variables
    ArrayFree(active_trades);
    ArrayFree(spike_buffer);
    ArrayFree(ma_buffer);
    ArrayFree(rsi_buffer);

    Print("SpikeHunter EA arrêté - Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Timer: réessayer prérequis et tâches légères                    |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Réessayer soft-block
    if(g_soft_block){
        // Re-tester connexion et autorisations
        bool ok=true;
        if(!TerminalInfoInteger(TERMINAL_CONNECTED)) ok=false;
        if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) ok=false;
        if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) ok=false;
        if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) ok=false;
        if(SymbolSelect(_Symbol, true)==false) ok=false;
        if(ok){
            g_soft_block=false; g_block_msg="";
            Print("✅ Soft-Block levé: conditions redevenues OK");
        } else {
            if(InpLogVerbosity>=1) Print("⏳ Soft-Block maintenu: ", g_block_msg);
        }
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Protection contre les ordres multiples                          |
//+------------------------------------------------------------------+
bool HasExistingPositionForSymbol(string symbol)
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == symbol && 
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                return true;
            }
        }
    }
    return false;
}

bool HasExistingOrderForSymbol(string symbol, int order_type)
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket))
        {
            if(OrderGetString(ORDER_SYMBOL) == symbol && 
               OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
               OrderGetInteger(ORDER_TYPE) == order_type)
            {
                return true;
            }
        }
    }
    return false;
}

bool IsPriceTooCloseToExistingOrders(string symbol, double price, int direction)
{
    double tolerance = InpDuplicatePriceTolerancePoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket))
        {
            if(OrderGetString(ORDER_SYMBOL) == symbol && 
               OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
            {
                double order_price = OrderGetDouble(ORDER_PRICE_OPEN);
                if(MathAbs(price - order_price) < tolerance)
                {
                    return true;
                }
            }
        }
    }
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket))
        {
            if(PositionGetString(POSITION_SYMBOL) == symbol && 
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                double position_price = PositionGetDouble(POSITION_PRICE_OPEN);
                if(MathAbs(price - position_price) < tolerance)
                {
                    return true;
                }
            }
        }
    }
    
    return false;
}

bool IsSymbolInCooldown(string symbol)
{
    int quota_index = FindOrCreateSymbolQuota(symbol);
    if(quota_index < 0) return true;
    
    datetime now = TimeCurrent();
    datetime last_trade = g_symbol_quotas[quota_index].last_trade_time;
    
    // Vérifier le cooldown par symbole
    if(now - last_trade < InpPerSymbolCooldownSec)
    {
        return true;
    }
    
    // Vérifier le quota horaire
    if(now - g_symbol_quotas[quota_index].hour_window_start >= 3600) // Nouvelle heure
    {
        g_symbol_quotas[quota_index].count_last_hour = 0;
        g_symbol_quotas[quota_index].hour_window_start = now;
    }
    
    if(g_symbol_quotas[quota_index].count_last_hour >= InpMaxSignalsPerSymbolHour)
    {
        return true;
    }
    
    return false;
}

bool CanOpenNewTradeForSymbol(string symbol, int direction, double price)
{
    // 1. Vérifier s'il y a déjà une position ouverte
    if(HasExistingPositionForSymbol(symbol))
    {
        Print("🚫 Position existante pour ", symbol, " - Trade bloqué");
        return false;
    }
    
    // 2. Vérifier s'il y a déjà un ordre en attente du même type
    int order_type = (direction > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
    if(HasExistingOrderForSymbol(symbol, order_type))
    {
        Print("🚫 Ordre en attente existant pour ", symbol, " - Trade bloqué");
        return false;
    }
    
    // 3. Vérifier si le prix est trop proche d'un ordre existant
    if(IsPriceTooCloseToExistingOrders(symbol, price, direction))
    {
        Print("🚫 Prix trop proche d'un ordre existant pour ", symbol, " - Trade bloqué");
        return false;
    }
    
    // 4. Vérifier le cooldown par symbole
    if(IsSymbolInCooldown(symbol))
    {
        Print("🚫 Symbole ", symbol, " en cooldown - Trade bloqué");
        return false;
    }
    
    // 5. PROTECTION ANTI-CASCADE - Vérifier si le trade est trop récent
    if(IsTradeTooRecent(symbol))
    {
        Print("🚫 Trade trop récent pour ", symbol, " - Protection anti-cascade");
        return false;
    }
    
    // 6. PROTECTION ANTI-CASCADE - Vérifier le nombre de trades par minute
    if(IsTooManyTradesPerMinute(symbol))
    {
        Print("🚫 Trop de trades par minute pour ", symbol, " - Protection anti-cascade");
        return false;
    }
    
    return true;
}

void UpdateSymbolQuota(string symbol)
{
    int quota_index = FindOrCreateSymbolQuota(symbol);
    if(quota_index >= 0)
    {
        g_symbol_quotas[quota_index].last_trade_time = TimeCurrent();
        g_symbol_quotas[quota_index].count_last_hour++;
    }
}

//+------------------------------------------------------------------+
//| Protection anti-cascade                                         |
//+------------------------------------------------------------------+
bool IsTradeTooRecent(string symbol)
{
    datetime now = TimeCurrent();
    
    // Vérifier le cooldown minimum entre trades
    for(int i = 0; i < 64; i++)
    {
        if(g_last_trade_time_by_symbol[i] == 0) continue;
        
        if(now - g_last_trade_time_by_symbol[i] < InpMinCooldownMinutes * 60)
        {
            return true;
        }
    }
    
    return false;
}

bool IsTooManyTradesPerMinute(string symbol)
{
    datetime now = TimeCurrent();
    int trades_this_minute = 0;
    
    // Compter les trades de la dernière minute
    for(int i = 0; i < g_trade_history_count; i++)
    {
        if(g_trade_history[i].symbol == symbol && 
           now - g_trade_history[i].open_time < 60)
        {
            trades_this_minute++;
        }
    }
    
    return trades_this_minute >= InpMaxTradesPerMinute;
}

bool IsTradeDurationTooShort(ulong ticket)
{
    if(!PositionSelectByTicket(ticket)) return false;
    
    datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
    datetime now = TimeCurrent();
    
    return (now - open_time) < InpMinTradeDurationSeconds;
}

bool ShouldPreventRapidClose(ulong ticket)
{
    if(!InpPreventRapidOpenClose) return false;
    
    // Vérifier si le trade est trop récent
    if(IsTradeDurationTooShort(ticket))
    {
        return true;
    }
    
    // Vérifier l'historique des fermetures rapides
    string symbol = PositionGetString(POSITION_SYMBOL);
    int rapid_closes = 0;
    
    for(int i = 0; i < g_trade_history_count; i++)
    {
        if(g_trade_history[i].symbol == symbol && 
           g_trade_history[i].was_closed_early &&
           TimeCurrent() - g_trade_history[i].close_time < InpTradeStabilityCheckSeconds)
        {
            rapid_closes++;
        }
    }
    
    return rapid_closes >= 2; // Bloquer si 2 fermetures rapides récentes
}

void RecordTradeHistory(string symbol, datetime open_time, datetime close_time, int direction, double profit, bool was_closed_early)
{
    if(g_trade_history_count < 100)
    {
        g_trade_history[g_trade_history_count].symbol = symbol;
        g_trade_history[g_trade_history_count].open_time = open_time;
        g_trade_history[g_trade_history_count].close_time = close_time;
        g_trade_history[g_trade_history_count].direction = direction;
        g_trade_history[g_trade_history_count].profit = profit;
        g_trade_history[g_trade_history_count].was_closed_early = was_closed_early;
        g_trade_history_count++;
    }
}

void UpdateLastTradeTime(string symbol)
{
    for(int i = 0; i < 64; i++)
    {
        if(g_last_trade_time_by_symbol[i] == 0)
        {
            g_last_trade_time_by_symbol[i] = TimeCurrent();
            break;
        }
    }
}

void OnTick()
{
    if(!InpEnableTrading) return;
    // Reset journalier si date change
    static int last_day = -1; MqlDateTime nt; TimeToStruct(TimeCurrent(), nt);
    if(last_day != nt.day){
        last_day = nt.day;
        MqlDateTime d0;
        d0.year = nt.year; d0.mon = nt.mon; d0.day = nt.day;
        d0.hour = 0; d0.min = 0; d0.sec = 0;
        day_start_time = StructToTime(d0);
        day_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
        day_realized_profit = 0.0;
        daily_stop_triggered = false;
    }
    // Reset hebdo si lundi
    static int last_week = -1; // year*100+week approx
    int week_num = (nt.year*100) + (nt.mon*4 + (nt.day/7)); // approx simple
    if(last_week != week_num && nt.day_of_week==1){
        last_week = week_num;
        week_realized_profit = 0.0;
    }

    // Stop journalier si objectif atteint
    if(InpRespectDailyStop && daily_stop_triggered){
        return;
    }
    
    // Si soft-block actif, réessayer périodiquement les prérequis sans trader
    if(g_soft_block){
        // Rien à faire ici, OnTimer s'occupe des réessais même sans ticks
        return; // ne pas trader tant que bloqué
    }

    //--- Vérification du délai de démarrage
    if(!ea_fully_initialized) {
        if(TimeCurrent() - ea_startup_time >= InpStartupDelaySec) {
            ea_fully_initialized = true;
            if(InpLogVerbosity >= 1) Print("⚡ EA complètement initialisé après ", InpStartupDelaySec, "s");
        } else {
            // Afficher le compte à rebours
            static datetime last_countdown = 0;
            if(TimeCurrent() - last_countdown >= 1) {
                int remaining = InpStartupDelaySec - (int)(TimeCurrent() - ea_startup_time);
                if(remaining > 0) Print("⏳ Démarrage dans ", remaining, "s...");
                last_countdown = TimeCurrent();
            }
            return; // Attendre la fin du délai
        }
    }

    //--- Mise à jour des données
    if(!UpdateIndicators()) return;

    //--- Mise à jour de l'historique des prix
    UpdatePriceHistory();

    //--- Reset quotidien des pertes
    if(InpUseRiskManagement) {
        ResetDailyLossIfNeeded();
    }
    
    //--- Pré-signal Boom/Crash (détection légère)
    {
        int dirps=0; double confps=0.0;
        if(DetectPreSpike(dirps, confps)){
            // Respecter cooldown
            if(!(alert_lock_active && TimeCurrent() - last_alert_time < InpAlertCooldownSeconds)){
                string ot = (dirps>0?"BUY":"SELL");
                string ntxt = StringFormat("⚡ PRE-SPIKE: %s %s | conf=%.0f%%", ot, _Symbol, confps);
                Print(ntxt); PlayAlert("PREDICTION");
                if(InpSendNotifications) SendMyNotification(ntxt);
                // Armer la prédiction pour ProcessSpikeSignal
                current_prediction.predicted_time = TimeCurrent() + 2;
                current_prediction.predicted_direction = dirps;
                current_prediction.confidence = confps;
                current_prediction.is_active = true;
                alert_lock_active = true; last_alert_time = TimeCurrent();
                // Optionnel: placer limit/market selon config
                if(InpAutoTradeOnSpike && IsBoomCrashIndex(_Symbol)){
                    if(IsDirectionAllowedForSymbol(dirps) && CanOpenTradeForSymbol(_Symbol)){
                        double lot = CalculateLotSize(_Symbol);
                        if(lot>0){
                            if(InpUseLimitOrders){
                                double rp = (dirps>0)? SymbolInfoDouble(_Symbol, SYMBOL_BID): SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                PlaceLimitOrderForSymbol(_Symbol, dirps, lot, rp);
                            } else {
                                PlaceMarketOrderForSymbol(_Symbol, dirps, lot);
                            }
                        }
                    }
                }
            }
        }
    }

    //--- Détection des supports et résistances (throttlé et paresseux)
    if(InpDetectSupportResistance && ea_fully_initialized) {
        static datetime last_sr_scan=0;
        if(TimeCurrent()-last_sr_scan >= InpHeavyTaskIntervalSec){
        DetectSupportResistance();
            last_sr_scan=TimeCurrent();
        }
        static datetime last_mtf_sr=0;
        if(TimeCurrent()-last_mtf_sr>MathMax(15, InpHeavyTaskIntervalSec*3)){ // rafraîchit moins souvent
            UpdateMTFSupportResistance();
            last_mtf_sr=TimeCurrent();
        }
    }

    //--- Mise à jour des données Streamlit
    if(InpUseStreamlitData) {
        UpdateStreamlitData();
    }

    //--- Vérification des trades existants (throttlé et paresseux)
    static datetime last_risk = 0;
    if(TimeCurrent()-last_risk >= InpRiskCheckIntervalSec && ea_fully_initialized){
    CheckActiveTrades();
        last_risk = TimeCurrent();
    }

    //--- Vérification des signaux de l'application locale
    if(InpUseAppSignals) {
        CheckAppSignals();
    }

    //--- Autoscan des signaux (throttlé et paresseux)
    if(InpAutoScan && ea_fully_initialized) {
        static datetime last_scan=0;
        if(TimeCurrent()-last_scan >= MathMax(5, InpHeavyTaskIntervalSec))
        {
            PerformMultiSymbolScan();
            last_scan = TimeCurrent();
        }
    }

    //--- Prédiction de spikes (paresseux)
    if(ea_fully_initialized) {
    PredictSpike();
        
        //--- Détection de zones de spikes multiples
        if(InpEnableMultiSpikeDetection) {
            DetectMultiSpikeZones();
        }
    }

    // Marquage escalier supprimé

    //--- Détection de spike (stratégie avancée squeeze→expansion) - paresseux
    if(ea_fully_initialized) {
    DetectSpikeAdvanced();
    }
    
    //--- Mise à jour du compteur de spikes dans le cluster actuel
    if(spike_detected && current_cluster.is_active) {
        current_cluster.spike_count++;
        last_spike_time = TimeCurrent();
        Print("🎯 Spike détecté dans cluster actif. Total spikes: ", current_cluster.spike_count);
    }

    // Tests de trading et ouverture forcée supprimés pour mode manuel

    // Mode manuel: pas d'exécution automatique d'ordres
    if(spike_detected || app_signal_received) {
        Print("🔎 Signal détecté (mode manuel) - Aucune exécution automatique.");
        spike_detected = false;
        app_signal_received = false;
    }

    //--- Trailing stop
    if(InpUseTrailing) {
        UpdateTrailingStops();
    }
}

//+------------------------------------------------------------------+
//| Suivi des ordres pour compteur LIMIT                              |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &req,const MqlTradeResult &res)
{
    if(trans.type==TRADE_TRANSACTION_ORDER_ADD)
    {
        if((req.type==ORDER_TYPE_BUY_LIMIT || req.type==ORDER_TYPE_SELL_LIMIT) && req.magic==InpMagicNumber && req.symbol==_Symbol)
            g_pending_limits = MathMin(g_pending_limits+1, 5);
    }
    else if(trans.type==TRADE_TRANSACTION_ORDER_DELETE || trans.type==TRADE_TRANSACTION_DEAL_ADD)
    {
        if((req.type==ORDER_TYPE_BUY_LIMIT || req.type==ORDER_TYPE_SELL_LIMIT) && req.magic==InpMagicNumber && req.symbol==_Symbol)
            g_pending_limits = MathMax(g_pending_limits-1, 0);
    }
}

//+------------------------------------------------------------------+
//| Mise à jour des indicateurs                                      |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
    static datetime last_ui_upd = 0;
    if(TimeCurrent() - last_ui_upd < InpUIUpdateIntervalSec) return true;
    last_ui_upd = TimeCurrent();

    //--- Initialisation paresseuse des indicateurs
    if(InpLazyInitialization) {
        if(ma_handle == INVALID_HANDLE) {
            ma_handle = iMA(_Symbol, InpTimeframe, InpReversalDetection, 0, MODE_EMA, PRICE_CLOSE);
            if(ma_handle == INVALID_HANDLE) return false;
        }
        if(rsi_handle == INVALID_HANDLE) {
            rsi_handle = iRSI(_Symbol, InpTimeframe, 14, PRICE_CLOSE);
            if(rsi_handle == INVALID_HANDLE) return false;
        }
    }

    if(spike_detection_handle != INVALID_HANDLE) {
        int cb = CopyBuffer(spike_detection_handle, 0, 0, 3, spike_buffer);
        if(cb < 0){ if(InpLogVerbosity>=1) Print("CopyBuffer spike_detection_handle échec: ", GetLastError()); }
    }
    if(ma_handle != INVALID_HANDLE){
        int cb_ma = CopyBuffer(ma_handle, 0, 0, 3, ma_buffer);
        if(cb_ma < 0){ if(InpLogVerbosity>=1) Print("CopyBuffer MA échec: ", GetLastError()); }
    }
    if(rsi_handle != INVALID_HANDLE){
        int cb_rsi = CopyBuffer(rsi_handle, 0, 0, 3, rsi_buffer);
        if(cb_rsi < 0){ if(InpLogVerbosity>=1) Print("CopyBuffer RSI échec: ", GetLastError()); }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Détection de spike améliorée avec filtres avancés               |
//+------------------------------------------------------------------+
void DetectSpike()
{
    static datetime last_check_time = 0;
    static double last_price = 0;
    static double spike_price_history[10];
    static int spike_price_index = 0;
    
    //--- Vérifier seulement toutes les secondes
    if(TimeCurrent() - last_check_time < 1) return;
    last_check_time = TimeCurrent();

    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double price_change = 0;
    
    //--- Calcul du changement de prix avec historique
    if(last_price > 0) {
        price_change = (current_price - last_price) / last_price * 100;
    }
    
    //--- Mise à jour de l'historique des prix
    spike_price_history[spike_price_index] = current_price;
    spike_price_index = (spike_price_index + 1) % 10;
    
    //--- Calcul de la volatilité moyenne sur 10 périodes
    double volatility_sum = 0;
    int valid_periods = 0;
    for(int i = 1; i < 10; i++) {
        int idx = (spike_price_index - i + 10) % 10;
        int prev_idx = (spike_price_index - i - 1 + 10) % 10;
        if(spike_price_history[idx] > 0 && spike_price_history[prev_idx] > 0) {
            volatility_sum += MathAbs((spike_price_history[idx] - spike_price_history[prev_idx]) / spike_price_history[prev_idx]);
            valid_periods++;
        }
    }
    double avg_volatility = (valid_periods > 0) ? volatility_sum / valid_periods : 0;
    
    //--- Seuil de spike adaptatif basé sur la volatilité
    double spike_threshold = MathMax(InpSpikeThreshold, avg_volatility * 2.0);
    spike_threshold = MathMin(spike_threshold, 1.0); // Maximum 1%
    
    //--- Filtres de qualité pour éviter les faux signaux
    bool is_quality_spike = false;
    
    // 1. Changement de prix significatif
    if(MathAbs(price_change) >= spike_threshold) {
        // 2. Vérification de la cohérence directionnelle
        int consistent_direction = 0;
        for(int i = 1; i < 5; i++) {
            int idx = (spike_price_index - i + 10) % 10;
            int prev_idx = (spike_price_index - i - 1 + 10) % 10;
            if(spike_price_history[idx] > 0 && spike_price_history[prev_idx] > 0) {
                double period_change = (spike_price_history[idx] - spike_price_history[prev_idx]) / spike_price_history[prev_idx];
                if((price_change > 0 && period_change > 0) || (price_change < 0 && period_change < 0)) {
                    consistent_direction++;
                }
            }
        }
        
        // 3. Vérification de la force du mouvement
        double movement_strength = MathAbs(price_change) / MathMax(avg_volatility, 0.001);
        
        // 4. Conditions de qualité
        if(consistent_direction >= 2 && movement_strength >= 1.5) {
            is_quality_spike = true;
        }
    }
    
    // Debug toutes les 10 secondes
    static datetime last_debug_time = 0;
    if(TimeCurrent() - last_debug_time > 10) {
        Print("🔍 DEBUG SPIKE: Prix=", DoubleToString(current_price, _Digits), 
              " | Changement=", DoubleToString(price_change, 4), "% | Seuil=", DoubleToString(spike_threshold, 4), "%",
              " | Volatilité=", DoubleToString(avg_volatility*100, 2), "% | Qualité=", is_quality_spike);
        last_debug_time = TimeCurrent();
    }
    
    if(is_quality_spike && TimeCurrent() - last_spike_time > 3) { // Minimum 3 secondes entre spikes
        spike_detected = true;
        spike_direction = (price_change > 0) ? 1 : -1;
        AnnounceBoomCrashSpike(spike_direction);
        // Afficher flèche sur le graphe pour le signal Boom/Crash
        DrawPredictionArrowSimple(spike_direction);
        // Auto-trade Boom/Crash on spike if enabled
        if(InpAutoTradeOnSpike && IsBoomCrashIndex(_Symbol)) {
            ProcessSpikeSignal();
            if(InpCloseOnSpikeConfirm){
                // Fermer immédiatement les positions ouvertes sur ce symbole
                CloseAllPositionsForSymbol(_Symbol);
                Print("✅ Fermeture immédiate après spike confirmé sur ", _Symbol);
            }
        }
        last_spike_time = TimeCurrent();

        string order_type = (spike_direction > 0) ? "BUY" : "SELL";
        string spike_type = (spike_direction > 0) ? "HAUSSIER" : "BAISSIER";
        double confidence = MathMin(95.0, MathAbs(price_change) * 1000); // Confiance basée sur l'amplitude
        
        Print("🚀 SPIKE QUALITÉ DÉTECTÉ: ", _Symbol, " - ", order_type, " (", spike_type, 
              ") - Changement: ", DoubleToString(price_change, 4), "% - Confiance: ", DoubleToString(confidence, 1), "%");
        
        last_alert = StringFormat("Signal Qualité: %s %s | Confiance: %.1f%% | Changement: %.4f%% | Volatilité: %.2f%%", 
                                order_type, _Symbol, confidence, price_change, avg_volatility*100);
        PlayAlert("SPIKE");

        if(InpSendNotifications) {
            string notification = StringFormat("🚀 SPIKE QUALITÉ: %s %s | Confiance: %.1f%% | Prix: %s | Changement: %.4f%%", 
                                             order_type, _Symbol, confidence, DoubleToString(current_price, _Digits), price_change);
            SendMyNotification(notification);
        }
    }
    
    last_price = current_price;
}

//+------------------------------------------------------------------+
//| Détection avancée: squeeze → expansion (Bollinger/ATR/body z)    |
//+------------------------------------------------------------------+
void DetectSpikeAdvanced()
{
    static datetime last_check = 0; if(TimeCurrent()-last_check<1) return; last_check=TimeCurrent();
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Bollinger (MQL5: handle + CopyBuffer)
    static int bands_handle = INVALID_HANDLE;
    if(bands_handle == INVALID_HANDLE)
        bands_handle = iBands(_Symbol, InpTimeframe, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
    double buf_upper[], buf_base[], buf_lower[];
    ArraySetAsSeries(buf_upper,true); ArraySetAsSeries(buf_base,true); ArraySetAsSeries(buf_lower,true);
    CopyBuffer(bands_handle, 0, 0, 1, buf_upper); // 0 = upper
    CopyBuffer(bands_handle, 1, 0, 1, buf_base);  // 1 = base
    CopyBuffer(bands_handle, 2, 0, 1, buf_lower); // 2 = lower
    double upper = (ArraySize(buf_upper)>0)?buf_upper[0]:0.0;
    double mid   = (ArraySize(buf_base)>0)?buf_base[0]:0.0;
    double lower = (ArraySize(buf_lower)>0)?buf_lower[0]:0.0;
    double bbw = (mid>0) ? (upper - lower) / mid : 0.0;
    static double bbw_prev=0.0; bool squeeze_to_expand = (bbw_prev>0 && bbw > 2.0*bbw_prev); bbw_prev=bbw;

    // ATR boost (handles + CopyBuffer)
    static int atr14_handle = INVALID_HANDLE;
    static int atr50_handle = INVALID_HANDLE;
    if(atr14_handle == INVALID_HANDLE) atr14_handle = iATR(_Symbol, InpTimeframe, 14);
    if(atr50_handle == INVALID_HANDLE) atr50_handle = iATR(_Symbol, InpTimeframe, 50);
    double atr14_buf[], atr50_buf[]; ArraySetAsSeries(atr14_buf,true); ArraySetAsSeries(atr50_buf,true);
    CopyBuffer(atr14_handle, 0, 0, 1, atr14_buf);
    CopyBuffer(atr50_handle, 0, 0, 1, atr50_buf);
    double atr14 = (ArraySize(atr14_buf)>0)?atr14_buf[0]:0.0;
    double atr50 = (ArraySize(atr50_buf)>0)?atr50_buf[0]:0.0;
    bool atr_ok = (atr50>0 && atr14 > InpATRBoost*atr50);

    // z-score du corps
    static double body_hist[240]; static int blen=0;
    double o=iOpen(_Symbol, InpTimeframe, 0), c=iClose(_Symbol, InpTimeframe, 0);
    double body=MathAbs(c-o);
    int w=MathMax(20, MathMin(240, InpBodyZWindow));
    if(blen<w) body_hist[blen++]=body; else { for(int i=1;i<w;i++) body_hist[i-1]=body_hist[i]; body_hist[w-1]=body; }
    int n=MathMin(blen, w); double bmean=0, bvar=0; for(int i=0;i<n;i++) bmean+=body_hist[i]; if(n>0) bmean/=n; for(int j=0;j<n;j++) bvar+=MathPow(body_hist[j]-bmean,2); if(n>1) bvar/=(n-1); double bstd=MathSqrt(bvar); double body_z=(bstd>0)?(body-bmean)/bstd:0.0;

    // direction (pro‑tendance) via EMA (handles + CopyBuffer en MQL5)
    int h_fast=iMA(_Symbol, InpTimeframe, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
    int h_slow=iMA(_Symbol, InpTimeframe, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
    double bfast[]; ArraySetAsSeries(bfast,true); CopyBuffer(h_fast,0,0,1,bfast);
    double bslow[]; ArraySetAsSeries(bslow,true); CopyBuffer(h_slow,0,0,1,bslow);
    double ema_fast=(ArraySize(bfast)>0)?bfast[0]:price;
    double ema_slow=(ArraySize(bslow)>0)?bslow[0]:price;
    int dir=(ema_fast>ema_slow)?1:-1;

    if(TimeCurrent()-last_spike_time<10) return;

    if(squeeze_to_expand && atr_ok && body_z>=InpBodyZMin) {
        spike_detected=true; spike_direction=dir; last_spike_time=TimeCurrent();
        AnnounceBoomCrashSpike(spike_direction);
        // Afficher flèche sur le graphe pour le signal Boom/Crash
        DrawPredictionArrowSimple(spike_direction);
        // Auto-trade Boom/Crash on spike if enabled
        if(InpAutoTradeOnSpike && IsBoomCrashIndex(_Symbol)) {
            ProcessSpikeSignal();
            if(InpCloseOnSpikeConfirm){
                CloseAllPositionsForSymbol(_Symbol);
                Print("✅ Fermeture immédiate après spike confirmé (ADV) sur ", _Symbol);
            }
        }
        string order_type=(spike_direction>0)?"BUY":"SELL";
        Print("🚀 SPIKE ADV: ", _Symbol, " ", order_type, " | BBW x2, ATR boost, body_z=", DoubleToString(body_z,2));
        PlayAlert("SPIKE");
        if(InpSendNotifications) SendMyNotification(StringFormat("Signal: %s %s | body_z=%.2f", order_type, _Symbol, body_z));
            }
}

//+------------------------------------------------------------------+
//| Traitement du signal de spike                                    |
//+------------------------------------------------------------------+
void ProcessSpikeSignal()
{
    Print("🔍 PROCESSUS SPIKE SIGNAL DÉMARRÉ - Direction: ", spike_direction);
    
    if(!IsTradeViable()) {
        Print("❌ Trade non viable, abandon");
        return;
    }
    
    Print("✅ Trade viable, continuation...");

    //--- Vérification du capital minimum
    if(InpUseRiskManagement && account_balance < InpMinCapital) {
        Print("❌ Capital insuffisant: $", account_balance, " < $", InpMinCapital, " minimum requis");
        return;
    }
    
    //--- Vérification de la perte journalière maximum
    if(InpUseRiskManagement && daily_loss >= InpMaxDailyLoss) {
        Print("❌ Perte journalière maximum atteinte: $", daily_loss, " >= $", InpMaxDailyLoss);
        return;
    }

    //--- DÉTERMINATION DE LA DIRECTION DE TRADE
    int trade_direction = spike_direction; // Utiliser directement la direction du spike
    
    // VÉRIFICATION STRICTE BOOM/CRASH - Éviter trades illogiques
    bool is_boom = (StringFind(_Symbol, "Boom") >= 0);
    bool is_crash = (StringFind(_Symbol, "Crash") >= 0);
    
    if(is_boom && trade_direction < 0) {
        Print("🚫 INTERDIT: SELL sur BOOM ", _Symbol, " - Logique incohérente");
        return;
    }
    
    if(is_crash && trade_direction > 0) {
        Print("🚫 INTERDIT: BUY sur CRASH ", _Symbol, " - Logique incohérente");
        return;
    }
    
    if(!IsDirectionAllowedForSymbol(trade_direction)) {
        Print("⏸ Spike ignoré: direction non autorisée pour ", _Symbol, " (BOOM=>BUY, CRASH=>SELL)");
        return;
    }
    bool should_trade = true; // Toujours trader si un spike est détecté

    // RÈGLES STRICTES DE TRADING SÉCURISÉ - JAMAIS CONTRE TENDANCE
    if(InpSecureTrading) {
        Print("🛡️ VÉRIFICATION RÈGLES DE TRADING SÉCURISÉ pour ", _Symbol);
        
        // 1) INTERDICTION ABSOLUE DE TRADER CONTRE TENDANCE
        if(InpTrendOnlyTrading && !IsTrendAligned(trade_direction)) {
            Print("🚫 INTERDIT: Trading contre tendance - Signal bloqué");
            should_trade = false;
        }
        
        // 2) VÉRIFICATION CAPITAL MINIMUM - Protection compte
        if(account_balance < InpMinCapital) {
            Print("🚫 CAPITAL INSUFFISANT: $", account_balance, " < $", InpMinCapital, " minimum");
            should_trade = false;
        }
        
        // 3) LIMITE DE PERTE MAXIMALE - Ne jamais cramer le compte
        double max_daily_loss = account_balance * (InpMaxDailyLossPercent / 100.0);
        if(daily_loss >= max_daily_loss) {
            Print("🚫 LIMITE PERTE ATTEINTE: $", daily_loss, " (", InpMaxDailyLossPercent, "% du capital)");
            should_trade = false;
        }
        
        // 4) VÉRIFICATION TENDANCE MULTI-TIMEFRAME OBLIGATOIRE
        if(should_trade && InpMultiTimeframeCheck) {
            if(!IsMultiTimeframeTrendAligned(trade_direction)) {
                Print("🚫 TENDANCE NON ALIGNÉE: Signal bloqué");
                should_trade = false;
            }
        }
        
        // 5) VÉRIFICATION MOMENTUM STRICT
        if(should_trade) {
            if(!IsMomentumFavorable(trade_direction)) {
                Print("🚫 MOMENTUM DÉFAVORABLE: Signal bloqué");
                should_trade = false;
            }
        }
        
        // 6) COOLDOWN ENTRE TRADES - Éviter sur-trading
        if(should_trade) {
            static datetime last_secure_trade_time = 0;
            int cooldown_seconds = InpMinCooldownMinutes * 60;
            if(TimeCurrent() - last_secure_trade_time < cooldown_seconds) {
                Print("⏸ COOLDOWN: Attendre ", InpMinCooldownMinutes, " minutes entre trades");
                should_trade = false;
            } else {
                last_secure_trade_time = TimeCurrent();
            }
        }
        
        if(!should_trade) {
            Print("❌ RÈGLES SÉCURISÉES: Trade bloqué pour ", _Symbol);
            return;
        } else {
            Print("✅ RÈGLES SÉCURISÉES: Trade autorisé pour ", _Symbol);
        }
    }
    
    if(trade_direction == 1) {
        Print("🎯 SPIKE HAUSSIER - OUVERTURE BUY AUTOMATIQUE");
    }
    else if(trade_direction == -1) {
        Print("🎯 SPIKE BAISSIER - OUVERTURE SELL AUTOMATIQUE");
    }
    else {
        Print("❌ DIRECTION DE SPIKE INVALIDE");
        return;
    }

    //--- CALCUL DU NOMBRE DE TRADES
    int trades_to_open = 1; // Par défaut, 1 trade
    
    // Signal app = trade supplémentaire
    if(app_signal_received) {
        trades_to_open = 2;
        Print("🚀 SIGNAL APP DÉTECTÉ - OUVERTURE DE ", trades_to_open, " TRADES");
    }
    
    // Martingale si pertes consécutives
    if(consecutive_losses > 0 && InpUseMartingale) {
        trades_to_open = MathMin(trades_to_open + consecutive_losses, 3);
        Print("📈 MARTINGALE - OUVERTURE DE ", trades_to_open, " TRADES");
    }
    
    // Limiter au maximum autorisé
    trades_to_open = MathMin(trades_to_open, InpMaxTrades - trade_count);
    
    //--- OUVERTURE DES TRADES
    int successful_trades = 0;
    for(int i = 0; i < trades_to_open && trade_count < InpMaxTrades; i++) {
        if(OpenTradeSimple(trade_direction)) {
            successful_trades++;
            Sleep(100); // Délai entre les trades
        }
    }
    
    Print("✅ ", successful_trades, "/", trades_to_open, " TRADE(S) OUVERT(S) - Direction: ", 
          (trade_direction > 0) ? "BUY" : "SELL");
}

//+------------------------------------------------------------------+
//| Autoscan des signaux toutes les 2 minutes                       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Scan multi-symboles pour plus d'opportunités                     |
//+------------------------------------------------------------------+
void PerformMultiSymbolScan()
{
    if(TimeCurrent() - last_autoscan_time < InpScanInterval) return;
    last_autoscan_time = TimeCurrent();
    
    //--- Initialiser la liste des symboles si nécessaire
    if(ArraySize(symbols_to_scan) == 0) {
        InitializeSymbolsToScan();
    }
    
    //--- Scanner un symbole à la fois pour éviter la surcharge
    if(current_symbol_index >= ArraySize(symbols_to_scan)) {
        current_symbol_index = 0;
    }
    
    string symbol_to_scan = symbols_to_scan[current_symbol_index];
    current_symbol_index++;
    
    //--- Scanner le symbole actuel
    ScanSymbolForOpportunities(symbol_to_scan);
}

//+------------------------------------------------------------------+
//| Initialiser la liste des symboles à scanner                      |
//+------------------------------------------------------------------+
void InitializeSymbolsToScan()
{
    ArrayResize(symbols_to_scan, 0);
    
    if(InpTradeAllSymbols) {
        //--- Ajouter les symboles prioritaires
        string priority_symbols[];
        StringSplit(InpSymbolsToTrade, ',', priority_symbols);
        
        for(int i = 0; i < ArraySize(priority_symbols); i++) {
            string symbol = priority_symbols[i];
            StringTrimLeft(symbol);
            StringTrimRight(symbol);
            if(SymbolSelect(symbol, true)) {
                ArrayResize(symbols_to_scan, ArraySize(symbols_to_scan) + 1);
                symbols_to_scan[ArraySize(symbols_to_scan) - 1] = symbol;
            }
        }
        
        //--- Ajouter d'autres symboles Boom/Crash disponibles
        int total_symbols = SymbolsTotal(true);
        
        for(int i = 0; i < total_symbols && ArraySize(symbols_to_scan) < InpMaxSymbolsToScan; i++) {
            string symbol = SymbolName(i, true);
            if(StringFind(symbol, "BOOM") >= 0 || StringFind(symbol, "CRASH") >= 0) {
                // Vérifier si pas déjà ajouté
                bool already_added = false;
                for(int j = 0; j < ArraySize(symbols_to_scan); j++) {
                    if(symbols_to_scan[j] == symbol) {
                        already_added = true;
                        break;
                    }
                }
                if(!already_added && SymbolSelect(symbol, true)) {
                    ArrayResize(symbols_to_scan, ArraySize(symbols_to_scan) + 1);
                    symbols_to_scan[ArraySize(symbols_to_scan) - 1] = symbol;
                }
            }
        }
    } else {
        //--- Scanner seulement le symbole actuel
        ArrayResize(symbols_to_scan, 1);
        symbols_to_scan[0] = _Symbol;
    }
    
    if(InpLogVerbosity >= 1) {
        Print("🔍 Symboles à scanner: ", ArraySize(symbols_to_scan));
        for(int i = 0; i < MathMin(ArraySize(symbols_to_scan), 5); i++) {
            Print("  - ", symbols_to_scan[i]);
        }
        if(ArraySize(symbols_to_scan) > 5) Print("  ... et ", ArraySize(symbols_to_scan) - 5, " autres");
    }
}

//+------------------------------------------------------------------+
//| Scanner un symbole spécifique pour les opportunités              |
//+------------------------------------------------------------------+
void ScanSymbolForOpportunities(string symbol)
{
    if(!SymbolSelect(symbol, true)) return;
    
    double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double current_ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double spread = current_ask - current_price;
    
    //--- Vérifier si on peut trader ce symbole
    if(!CanOpenTradeForSymbol(symbol)) return;
    
    //--- Créer des handles temporaires pour ce symbole
    int temp_ma_handle = iMA(symbol, InpTimeframe, InpReversalDetection, 0, MODE_EMA, PRICE_CLOSE);
    int temp_rsi_handle = iRSI(symbol, InpTimeframe, 14, PRICE_CLOSE);
    
    if(temp_ma_handle == INVALID_HANDLE || temp_rsi_handle == INVALID_HANDLE) {
        if(temp_ma_handle != INVALID_HANDLE) IndicatorRelease(temp_ma_handle);
        if(temp_rsi_handle != INVALID_HANDLE) IndicatorRelease(temp_rsi_handle);
        return;
    }
    
    double ma_values[3];
    double rsi_values[3];
    
    if(CopyBuffer(temp_ma_handle, 0, 0, 3, ma_values) < 0) {
        IndicatorRelease(temp_ma_handle);
        IndicatorRelease(temp_rsi_handle);
        return;
    }
    if(CopyBuffer(temp_rsi_handle, 0, 0, 3, rsi_values) < 0) {
        IndicatorRelease(temp_ma_handle);
        IndicatorRelease(temp_rsi_handle);
        return;
    }
    
    string signal_type = "";
    string signal_direction = "";
    double signal_confidence = 0;
    string signal_reason = "";
    
    //--- Analyse RSI
    if(rsi_values[0] < 30) {
        signal_type = "BUY";
        signal_direction = "BOOM";
        signal_confidence = 0.75;
        signal_reason = "RSI Survente";
    }
    else if(rsi_values[0] > 70) {
        signal_type = "SELL";
        signal_direction = "CRASH";
        signal_confidence = 0.75;
        signal_reason = "RSI Surachat";
    }
    
    //--- Analyse MA
    if(ma_values[0] > ma_values[1] && ma_values[1] < ma_values[2]) {
        signal_type = "BUY";
        signal_direction = "BOOM";
        signal_confidence = MathMax(signal_confidence, 0.70);
        signal_reason = "MA Croisement Haussier";
    }
    else if(ma_values[0] < ma_values[1] && ma_values[1] > ma_values[2]) {
        signal_type = "SELL";
        signal_direction = "CRASH";
        signal_confidence = MathMax(signal_confidence, 0.70);
        signal_reason = "MA Croisement Baissier";
    }
    
    //--- Analyse volatilité
    double volatility = MathAbs(current_price - ma_values[0]) / ma_values[0];
    if(volatility > 0.002) {
        if(current_price > ma_values[0]) {
            signal_type = "BUY";
            signal_direction = "BOOM";
            signal_confidence = MathMax(signal_confidence, 0.65);
            signal_reason = "Volatilité Haussier";
        } else {
            signal_type = "SELL";
            signal_direction = "CRASH";
            signal_confidence = MathMax(signal_confidence, 0.65);
            signal_reason = "Volatilité Baissier";
        }
    }
    
    //--- Nettoyer les handles
    IndicatorRelease(temp_ma_handle);
    IndicatorRelease(temp_rsi_handle);
    
    //--- Traiter le signal si valide
    if(StringLen(signal_type) > 0 && signal_confidence >= 0.60) {
        ProcessSymbolSignal(symbol, signal_type, signal_direction, signal_confidence, signal_reason, current_price);
    }
}

//+------------------------------------------------------------------+
//| Traiter un signal pour un symbole spécifique                     |
//+------------------------------------------------------------------+
void ProcessSymbolSignal(string symbol, string signal_type, string signal_direction, double confidence, string reason, double price)
{
    //--- Vérifier si on peut trader ce symbole
    if(!CanOpenTradeForSymbol(symbol)) return;

    //--- Durcir pour Step Index si demandé
    if(InpEnableStepTightening && StringFind(symbol, "Step Index")>=0){
        if(confidence < InpStepExtraMinConfidence) return;
    }

    //--- Cooldown et quota par symbole
    int qi = FindOrCreateSymbolQuota(symbol);
    if(qi>=0){
        // Fenêtre horaire
        if(TimeCurrent() - g_symbol_quotas[qi].hour_window_start >= 3600){
            g_symbol_quotas[qi].hour_window_start = TimeCurrent();
            g_symbol_quotas[qi].count_last_hour = 0;
        }
        if(g_symbol_quotas[qi].count_last_hour >= InpMaxSignalsPerSymbolHour) return;
        if(TimeCurrent() - g_symbol_quotas[qi].last_trade_time < InpPerSymbolCooldownSec) return;
    }
    
    //--- Vérifier la direction autorisée
    int trade_direction = (signal_type == "BUY") ? 1 : -1;
    if(!IsDirectionAllowedForSymbol(symbol, trade_direction)) return;
    
    //--- Vérifier le spread
    double spread = SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID);
    double spread_points = spread / SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(spread_points > InpMaxSpreadPoints) return;
    
    //--- Calculer la taille du lot
    double lot_size = CalculateLotSize(symbol);
    if(lot_size <= 0) return;
    
    //--- Placer l'ordre
    if(InpUseLimitOrders) {
        PlaceLimitOrderForSymbol(symbol, trade_direction, lot_size, price);
    } else {
        PlaceMarketOrderForSymbol(symbol, trade_direction, lot_size);
    }
    
    //--- Envoyer notification
    if(InpLogVerbosity >= 1) {
        Print("🎯 Signal traité: ", symbol, " ", signal_type, " (", DoubleToString(confidence*100, 0), "%) - ", reason);
    }
    
    if(InpSendNotifications) {
        SendMyNotification("Signal: " + symbol + " " + signal_type + " - " + DoubleToString(confidence*100, 0) + "%");
    }

    if(qi>=0){
        g_symbol_quotas[qi].last_trade_time = TimeCurrent();
        g_symbol_quotas[qi].count_last_hour++;
    }
}

//+------------------------------------------------------------------+
//| Placer un ordre limit pour un symbole spécifique                 |
//+------------------------------------------------------------------+
void PlaceLimitOrderForSymbol(string symbol, int direction, double lot_size, double current_price)
{
    MqlTradeRequest lr;
    MqlTradeResult lrs;
    ZeroMemory(lr);
    ZeroMemory(lrs);
    
    lr.action = TRADE_ACTION_PENDING;
    lr.symbol = symbol;
    lr.volume = lot_size;
    lr.type = (direction > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
    lr.magic = InpMagicNumber;
    lr.comment = "SpikeHunter Multi-Symbol";
    
    //--- Calculer le prix limite
    double limit_price = current_price;
    if(direction > 0) {
        limit_price = current_price - (InpLimitOffsetPoints * SymbolInfoDouble(symbol, SYMBOL_POINT));
    } else {
        limit_price = current_price + (InpLimitOffsetPoints * SymbolInfoDouble(symbol, SYMBOL_POINT));
    }
    
    lr.price = AlignToTick(limit_price, symbol);
    lr.sl = 0;
    lr.tp = 0;
    lr.deviation = 10;
    lr.type_filling = (ENUM_ORDER_TYPE_FILLING)GetSupportedFilling();
    lr.expiration = TimeCurrent() + InpLimitExpirySec;
    
    //--- Calculer SL/TP
    ComputeSLTPForSymbol(symbol, lr, direction);
    
    //--- Envoyer l'ordre
    if(OrderSend(lr, lrs)) {
        g_pending_limits++;
        if(InpLogVerbosity >= 1) {
            Print("✅ Ordre limit placé: ", symbol, " ", (direction > 0 ? "BUY" : "SELL"), 
                  " Prix: ", DoubleToString(lr.price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)));
        }
    }
}

//+------------------------------------------------------------------+
//| Placer un ordre marché pour un symbole spécifique                |
//+------------------------------------------------------------------+
void PlaceMarketOrderForSymbol(string symbol, int direction, double lot_size)
{
    MqlTradeRequest rq;
    MqlTradeResult rs;
    ZeroMemory(rq);
    ZeroMemory(rs);
    
    rq.action = TRADE_ACTION_DEAL;
    rq.symbol = symbol;
    rq.volume = lot_size;
    rq.type = (direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    rq.magic = InpMagicNumber;
    rq.comment = "SpikeHunter Multi-Symbol";
    rq.deviation = 10;
    rq.type_filling = (ENUM_ORDER_TYPE_FILLING)GetSupportedFilling();
    
    //--- Calculer SL/TP
    ComputeSLTPForSymbol(symbol, rq, direction);
    
    //--- Envoyer l'ordre
    if(OrderSend(rq, rs)) {
        if(InpLogVerbosity >= 1) {
            Print("✅ Ordre marché placé: ", symbol, " ", (direction > 0 ? "BUY" : "SELL"));
        }
    }
}

//+------------------------------------------------------------------+
//| Calculer SL/TP pour un symbole spécifique                        |
//+------------------------------------------------------------------+
void ComputeSLTPForSymbol(string symbol, MqlTradeRequest &rq, int direction)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double current_price = (direction > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if(IsBoomCrashIndex(symbol)) {
        int tp_points = GetBoomCrashTPPoints();
        double sl_ratio = GetBoomCrashSLRatio();
        
        if(direction > 0) {
            rq.tp = current_price + (tp_points * point);
            rq.sl = current_price - (tp_points * point * sl_ratio);
        } else {
            rq.tp = current_price - (tp_points * point);
            rq.sl = current_price + (tp_points * point * sl_ratio);
        }
    } else {
        if(direction > 0) {
            rq.tp = current_price + (InpTakeProfit * point);
            rq.sl = current_price - (InpStopLoss * point);
        } else {
            rq.tp = current_price - (InpTakeProfit * point);
            rq.sl = current_price + (InpStopLoss * point);
        }
    }
}

//+------------------------------------------------------------------+
//| Calculer la taille du lot pour un symbole                        |
//+------------------------------------------------------------------+
double CalculateLotSize(string symbol)
{
    double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    double lot_size = InpBaseLotSize;
    
    //--- Ajuster selon le capital disponible
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    if(current_balance > 0) {
        double risk_amount = current_balance * (InpRiskPercent / 100.0);
        double lot_by_risk = risk_amount / (InpStopLoss * SymbolInfoDouble(symbol, SYMBOL_POINT) * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE));
        lot_size = MathMin(lot_size, lot_by_risk);
    }

    // Mode petit capital: réduire la taille au minimum et utiliser TP/SL en $ plus petits
    if(InpSmallBalanceMode && AccountInfoDouble(ACCOUNT_BALANCE) <= InpSmallBalanceThreshold){
        lot_size = MathMax(min_lot, lot_step);
    }
    
    //--- Respecter les limites du broker
    lot_size = MathMax(lot_size, min_lot);
    lot_size = MathMin(lot_size, max_lot);
    
    //--- Aligner sur le step
    lot_size = MathRound(lot_size / lot_step) * lot_step;
    
    return lot_size;
}

//+------------------------------------------------------------------+
//| Aligner le prix sur le tick size                                 |
//+------------------------------------------------------------------+
double AlignToTick(double price, string symbol)
{
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    return MathRound(price / tick_size) * tick_size;
}

//+------------------------------------------------------------------+
//| Vérifier si on peut trader un symbole                            |
//+------------------------------------------------------------------+
bool CanOpenTradeForSymbol(string symbol)
{
    //--- Vérifier si le symbole est sélectionné
    if(!SymbolSelect(symbol, true)) return false;
    
    //--- Vérifier les permissions de trading
    if((SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) & SYMBOL_TRADE_MODE_FULL) == 0) return false;
    
    //--- Arrêt journalier atteint ?
    if(InpRespectDailyStop && daily_stop_triggered) return false;

    //--- Vérifier le nombre de trades existants pour ce symbole
    int existing_trades = CountOpenPositionsForSymbol(symbol);
    if(existing_trades >= 2) return false; // Max 2 trades par symbole
    
    //--- Vérifier le nombre total de trades (mode petit capital ou normal)
    double bal = AccountInfoDouble(ACCOUNT_BALANCE);
    int max_trades_allowed = InpMaxTrades;
    // Règle stricte: si balance <= $10, max 1 trade simultané
    if(bal <= 10.0){
        max_trades_allowed = 1;
    } else if(InpSmallBalanceMode && bal <= InpSmallBalanceThreshold){
        max_trades_allowed = MathMin(max_trades_allowed, InpMaxTradesSmallBalance);
    }
    if(CountTotalOpenPositions() >= max_trades_allowed) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Compter les positions ouvertes pour un symbole (version optimisée) |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Compter le total des positions ouvertes                          |
//+------------------------------------------------------------------+
int CountTotalOpenPositions()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Vérifier si la direction est autorisée pour un symbole           |
//+------------------------------------------------------------------+
bool IsDirectionAllowedForSymbol(string symbol, int direction)
{
    string sym = symbol; StringToLower(sym);
    if(StringFind(sym, "boom") >= 0) {
        return direction > 0; // Seulement BUY pour BOOM
    }
    if(StringFind(sym, "crash") >= 0) {
        return direction < 0; // Seulement SELL pour CRASH
    }
    return true; // Autres symboles: toutes directions autorisées
}

void PerformAutoScan()
{
    //--- Fonction legacy - maintenant redirigée vers PerformMultiSymbolScan
    PerformMultiSymbolScan();
}

//+------------------------------------------------------------------+
//| Génération et envoi des signaux                                  |
//+------------------------------------------------------------------+
void GenerateAndSendSignal(string signal_type, string signal_direction, double confidence, string reason, double price)
{
    string signal_message = "";
    string emoji = (signal_type == "BUY") ? "🟢" : "🔴";
    
    signal_message = emoji + " " + signal_type + " " + _Symbol + "\n";
    signal_message += "💰 Prix: " + DoubleToString(price, _Digits) + "\n";
    signal_message += "🎯 Confiance: " + DoubleToString(confidence * 100, 0) + "%\n";
    signal_message += "📊 Direction: " + signal_direction + "\n";
    signal_message += "📝 Raison: " + reason + "\n";
    signal_message += "⏰ " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\n";
    signal_message += "🤖 TradBOT Autoscan";
    
    last_autoscan_signal = signal_type + " " + signal_direction + " " + DoubleToString(confidence * 100, 0) + "%";
    autoscan_signals_sent++;
    
    if(InpSendToWhatsApp) {
        SendWhatsAppSignal(signal_message);
    }
    
    if(InpSendToSMS) {
        SendSMSSignal(signal_message);
    }
    
    if(InpSendNotifications) {
        SendMyNotification("Autoscan Signal: " + signal_type + " " + signal_direction + " - " + DoubleToString(confidence * 100, 0) + "%");
    }
    
    PlayAlert("SIGNAL");
    
    Print("AUTOSCAN SIGNAL ENVOYÉ: ", signal_type, " ", signal_direction, " - Confiance: ", DoubleToString(confidence * 100, 1), "% - Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Envoi de signal par WhatsApp                                     |
//+------------------------------------------------------------------+
void SendWhatsAppSignal(string message)
{
    Print("📱 WHATSAPP SIGNAL ENVOYÉ à ", InpPhoneNumber, ":");
    Print(message);
}

//+------------------------------------------------------------------+
//| Envoi de signal par SMS                                          |
//+------------------------------------------------------------------+
void SendSMSSignal(string message)
{
    Print("📲 SMS SIGNAL ENVOYÉ à ", InpPhoneNumber, ":");
    Print(message);
}

//+------------------------------------------------------------------+
//| Prédiction de spikes avec flèches                                |
//+------------------------------------------------------------------+
void PredictSpike()
{
    static datetime last_prediction_check = 0;
    if(TimeCurrent() - last_prediction_check < 1) return;
    last_prediction_check = TimeCurrent();
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    price_history[history_index] = current_price;
    history_index = (history_index + 1) % 100;
    
    double volatility = 0;
    double trend = 0;
    double momentum = 0;
    for(int i = 1; i < 20; i++) {
        int idx = (history_index - i + 100) % 100;
        int prev_idx = (history_index - i - 1 + 100) % 100;
        if(price_history[idx] > 0 && price_history[prev_idx] > 0) {
            double change = (price_history[idx] - price_history[prev_idx]) / price_history[prev_idx];
            volatility += MathAbs(change);
            trend += change;
            momentum += change * i;
        }
    }
    volatility /= 19;
    trend /= 19;
    momentum /= 19;
    
    bool should_predict = false;
    int predicted_direction = 0;
    double confidence = 0;
    int duration = 0;
    
    if(volatility > 0.0008 && MathAbs(trend) > 0.0003 && MathAbs(momentum) > 0.0002) {
        should_predict = true;
        predicted_direction = (trend > 0) ? 1 : -1;
        confidence = MathMin((volatility * 1000 + MathAbs(momentum) * 2000), 0.95);
        duration = (int)(45 + volatility * 15000);
    }
    
    // S/R confirmés: BUY proche support confirmé, SELL proche résistance confirmée
        double support_proximity = CheckSupportProximity(current_price);
    if(support_proximity >= 0.8) {
            should_predict = true;
        predicted_direction = 1;
        confidence = MathMin(MathMax(confidence, 0.80) + support_proximity * 0.15, 0.99);
        }
        double resistance_proximity = CheckResistanceProximity(current_price);
    if(resistance_proximity >= 0.8) {
            should_predict = true;
        predicted_direction = -1;
        confidence = MathMin(MathMax(confidence, 0.80) + resistance_proximity * 0.15, 0.99);
    }
    
    static double last_stable_price = 0;
    static datetime stable_start = 0;
    static double stable_volatility = 0;
    
    if(MathAbs(current_price - last_stable_price) < current_price * 0.00005) {
        if(stable_start == 0) {
            stable_start = TimeCurrent();
            stable_volatility = volatility;
        }
    } else {
        if(stable_start > 0 && TimeCurrent() - stable_start > 15) {
            should_predict = true;
            predicted_direction = (current_price > last_stable_price) ? 1 : -1;
            confidence = 0.75 + (volatility - stable_volatility) * 1000;
            duration = 60;
        }
        stable_start = 0;
    }
    last_stable_price = current_price;
    
    if(current_price > last_high) {
        last_high = current_price;
        last_high_time = TimeCurrent();
    }
    if(current_price < last_low || last_low == 0) {
        last_low = current_price;
        last_low_time = TimeCurrent();
    }
    
    if(TimeCurrent() - last_high_time < 30 && momentum < -0.0001 && trend > 0.0002) {
        should_predict = true;
        predicted_direction = -1;
        confidence = MathMax(confidence, 0.82);
    }
    else if(TimeCurrent() - last_low_time < 30 && momentum > 0.0001 && trend < -0.0002) {
        should_predict = true;
        predicted_direction = 1;
        confidence = MathMax(confidence, 0.82);
    }

    double fibo_bias = 0.0;
    double last_swing_high = last_high;
    double last_swing_low = last_low;
    if(last_swing_high > 0 && last_swing_low > 0 && last_swing_high > last_swing_low) {
        double r382 = last_swing_low + 0.382 * (last_swing_high - last_swing_low);
        double r500 = last_swing_low + 0.500 * (last_swing_high - last_swing_low);
        double r618 = last_swing_low + 0.618 * (last_swing_high - last_swing_low);
        double d382 = MathAbs((current_price - r382) / current_price);
        double d500 = MathAbs((current_price - r500) / current_price);
        double d618 = MathAbs((current_price - r618) / current_price);
        double prox = MathMin(d382, MathMin(d500, d618));
        if(prox < 0.0006) {
            fibo_bias = 0.08;
            confidence = MathMin(confidence + fibo_bias, 0.99);
        }
    }

    if(MathAbs(momentum) > 0.00035 && volatility > 0.0009) {
        confidence = MathMin(confidence + 0.07, 0.99);
    }

    double trend_weight = 0.0;
    string trend_json = "";
    uchar post_data[]; ArrayResize(post_data, 0);
    uchar result_data[]; string result_headers;
    // Cache soft des appels réseau pour réduire la charge
    static string cached_trend = ""; static datetime last_trend_fetch=0;
    string headers = "Content-Type: application/json\r\n";
    string cookies = "";
    int res = 0;
    if(TimeCurrent()-last_trend_fetch >= InpNetTrendCacheSec){
        res = WebRequest("GET", InpTrendApiUrl, headers, cookies, 1000,
                         post_data, 0, result_data, result_headers);
        if(res == 200 && ArraySize(result_data) > 0){
            cached_trend = CharArrayToString(result_data, 0, -1);
            last_trend_fetch = TimeCurrent();
        }
    }
    if(cached_trend != "") {
        trend_json = cached_trend;
        bool trend_up = (StringFind(trend_json, "UP") >= 0);
        bool trend_down = (StringFind(trend_json, "DOWN") >= 0);
        
        // N'autoriser que les prédictions dans le sens de la tendance
        if(predicted_direction > 0 && trend_up) {
            trend_weight = 0.06;
        confidence = MathMin(confidence + trend_weight, 0.995);
        } else if(predicted_direction < 0 && trend_down) {
            trend_weight = 0.06;
            confidence = MathMin(confidence + trend_weight, 0.995);
        } else {
            // Contre-tendance -> annuler la prédiction
            should_predict = false;
        }
    }

    // Enforcer la règle Boom/Crash (pro-direction stricte)
    string __sym;  __sym = _Symbol; StringToLower(__sym);
    bool __is_boom = (StringFind(__sym, "boom") >= 0);
    bool __is_crash = (StringFind(__sym, "crash") >= 0);
    if(__is_boom && predicted_direction < 0) should_predict = false;   // pas de SELL sur Boom
    if(__is_crash && predicted_direction > 0) should_predict = false;  // pas de BUY sur Crash
    
    // Multi-timeframe trend filter: Boom must be UP on M15/M30/H1; Crash must be DOWN.
    int dir15 = GetEmaCrossDirection(PERIOD_M15);
    int dir30 = GetEmaCrossDirection(PERIOD_M30);
    int dirH1 = GetEmaCrossDirection(PERIOD_H1);
    string __s; __s = _Symbol; StringToLower(__s);
    bool __boom = (StringFind(__s, "boom")>=0);
    bool __crash= (StringFind(__s, "crash")>=0);
    bool mtf_ok = true;
    // assoupli: au moins 2 timeframes alignés dans le bon sens
    if(__boom)
    {
        int cnt = 0; if(dir15>=0) cnt++; if(dir30>=0) cnt++; if(dirH1>=0) cnt++;
        mtf_ok = (cnt >= 2);
    }
    if(__crash)
    {
        int cnt = 0; if(dir15<=0) cnt++; if(dir30<=0) cnt++; if(dirH1<=0) cnt++;
        mtf_ok = (cnt >= 2);
    }

    // Mode simple: seulement 2 paramètres clés: MTF et proximité S/R
    if(InpUseSimpleMode)
    {
        double proxSimple = ProximityToMTFLevelsPct(current_price);
    if(InpLogVerbosity>=2)
        Print("🔍 DEBUG SIMPLE MODE: proxSimple=", proxSimple, " | InpSimpleSRProximityPct=", InpSimpleSRProximityPct, " | mtf_ok=", mtf_ok);
        
        // Vérifier si c'est un symbole Boom/Crash pour assouplir les conditions
        bool isBoomCrash = IsBoomCrashIndex(_Symbol);
        double proximity_threshold = isBoomCrash ? InpSimpleSRProximityPct * 2.0 : InpSimpleSRProximityPct;
        
        // Conditions majeures pour Boom/Crash : 1) Proximité S/R + 2) Alignement MTF + 3) Confirmation tendance
        bool boom_crash_conditions = false;
        if(isBoomCrash) {
            // Condition 1: Proximité aux niveaux S/R (assouplie pour Boom/Crash)
            bool proximity_ok = proxSimple <= proximity_threshold;
            // Condition 2: Alignement multi-timeframe (au moins 2 timeframes)
            bool mtf_alignment = mtf_ok;
            // Condition 3: Confirmation de tendance renforcée
            bool trend_confirmation = CheckTrendConfirmation(predicted_direction);
            
            boom_crash_conditions = proximity_ok && mtf_alignment && trend_confirmation;
            if(InpLogVerbosity>=2)
                Print("🎯 BOOM/CRASH CONDITIONS: Proximité=", proximity_ok, " (", proxSimple, " <= ", proximity_threshold, 
                      ") | MTF=", mtf_alignment, " | Tendance=", trend_confirmation);
        }
        
        if((isBoomCrash && boom_crash_conditions) || (!isBoomCrash && proxSimple <= InpSimpleSRProximityPct && mtf_ok))
        {
            // Vérifier si on peut ouvrir un nouveau trade pour ce symbole (max 2 par symbole)
            if(!CanOpenTradeForSymbol(_Symbol)) {
                Print("⏸ Limite de trades atteinte pour ", _Symbol, " (max 2 par symbole)");
                return;
            }
            
            // Vérifier si on peut scalper ce symbole (cooldown et limite horaire)
            if(!CanScalpSymbol(_Symbol)) {
                Print("⏸ Scalping en cooldown ou limite horaire atteinte pour ", _Symbol);
                return;
            }
            
            // verrou anti-spam
            if(alert_lock_active && TimeCurrent() - last_alert_time < InpAlertCooldownSeconds) return;
            int eta = 2;
            current_prediction.predicted_time = TimeCurrent() + eta;
            current_prediction.predicted_direction = predicted_direction;
            current_prediction.confidence = MathMax(confidence, 0.85);
            current_prediction.duration_seconds = eta;
            current_prediction.is_active = true;
            last_prediction_time = TimeCurrent();
            total_predictions++;
            UpdateProximityDisplay(proxSimple);
            UpdateScoreDisplay(current_prediction.confidence*100.0);
            DrawPredictionArrow();
            ShowCountdownPopup();
            string direction_str = (predicted_direction > 0) ? "BOOM" : "CRASH";
            string notify = StringFormat("🔮 Prédiction SIMPLE: %s | %s | ETA %ds | prox %.2f%%",
                                        _Symbol, direction_str, eta, proxSimple*100.0);
            last_alert = notify; Print(notify);
            
            // Debug: Vérifier les paramètres de notification
            Print("🔍 DEBUG SIGNAL: InpSendNotifications=", InpSendNotifications, " | Direction=", direction_str, " | Symbol=", _Symbol);
            Print("🎯 BOOM/CRASH SIGNAL ACTIVÉ: ", isBoomCrash ? "OUI" : "NON", " | Seuil proximité: ", proximity_threshold);
            
            // Vérifier si on est dans une zone de spikes multiples
            string multi_spike_info = "";
            if(current_cluster.is_active && current_cluster.spike_count > 0) {
                multi_spike_info = StringFormat(" | Zone Multi-Spike active (déjà %d spikes)", current_cluster.spike_count);
            }
            
            // Prédiction de spikes supplémentaires
            if(InpEnableMultiSpikeDetection) {
                double multi_probability = PredictAdditionalSpikes(current_price, CalculateCurrentVolatility());
                if(multi_probability >= InpMultiSpikeConfidence) {
                    multi_spike_info += StringFormat(" | Probabilité spikes supplémentaires: %.0f%%", multi_probability * 100);
                }
            }
            
            string enhanced_notify = notify + multi_spike_info;
            
            if(InpSendNotifications) {
                Print("📤 ENVOI NOTIFICATION: ", enhanced_notify);
                SendMyNotification(enhanced_notify);
            } else {
                Print("❌ NOTIFICATIONS DÉSACTIVÉES - Signal non envoyé");
            }
            alert_lock_active = true; last_alert_time = TimeCurrent();
            if(InpUseLimitOrders)
            {
                MqlTradeRequest lr; MqlTradeResult rr; ZeroMemory(lr); ZeroMemory(rr);
                lr.action = TRADE_ACTION_PENDING; lr.symbol = _Symbol;
                // Enforcer: BOOM only BUY limit, CRASH only SELL limit
                if(!IsDirectionAllowedForSymbol(predicted_direction)) {
                    Print("⏸ Direction non autorisée pour ", _Symbol, " (BOOM=>BUY, CRASH=>SELL). Ordre limit ignoré.");
                    return; // skip placing limit
                }
                lr.type = (ENUM_ORDER_TYPE)((predicted_direction>0)? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT);
                // Calculer le lot avec multiplicateur d'échec pour les ordres limit
                double base_lot = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), InpBaseLotSize);
                lr.volume = CalculateLotWithFailMultiplier(_Symbol, base_lot);
                lr.magic = InpMagicNumber; lr.type_filling = (ENUM_ORDER_TYPE_FILLING)GetSupportedFilling(); lr.deviation = 100;
                lr.expiration = TimeCurrent() + InpLimitExpirySec;
                
                // Utiliser la fonction améliorée pour préparer l'ordre
                PrepareLimitOrder(lr, predicted_direction);
                if(lr.volume <= 0) { Print("❌ LIMIT annulé par filtres de précision"); return; }
                // Anti-duplication: éviter doublon proche + cooldown
                double tol = InpDuplicatePriceTolerancePoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                static datetime last_limit_time = 0;
                if(TimeCurrent() - last_limit_time < InpDuplicateCooldownSec) {
                    Print("⏸ Cooldown anti-doublon LIMIT actif (", InpDuplicateCooldownSec, "s)");
                    return;
                }
                // Empêcher ordres inverses simultanés
                if(!CanPlaceDirectionForSymbol(predicted_direction)) { return; }
                for(int oi=OrdersTotal()-1; oi>=0; oi--){
                    ulong ot = OrderGetTicket(oi);
                    if(!OrderSelect(ot)) continue;
                    if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
                    if((int)OrderGetInteger(ORDER_MAGIC)!=InpMagicNumber) continue;
                    long otype = OrderGetInteger(ORDER_TYPE);
                    if(otype!=ORDER_TYPE_BUY_LIMIT && otype!=ORDER_TYPE_SELL_LIMIT) continue;
                    double oprice = OrderGetDouble(ORDER_PRICE_OPEN);
                    if(MathAbs(oprice - lr.price) <= tol){
                        Print("⏸ Anti-duplication LIMIT: ordre existant à ~même prix (", DoubleToString(oprice,_Digits), ")");
                        return;
                    }
                }
                last_limit_time = TimeCurrent();
                
                bool result = OrderSend(lr, rr);
                if(!result) {
                    Print("❌ Échec OrderSend: ", GetLastError(), " - ", rr.comment);
                    Print("   Prix demandé: ", lr.price, " | SL: ", lr.sl, " | TP: ", lr.tp);
                } else {
                    Print("✅ Ordre limit envoyé avec succès: ", lr.price, " | SL: ", lr.sl, " | TP: ", lr.tp);
                }
            }
        }
        return; // ne pas exécuter la logique avancée
    }

    double min_conf = InpMinPredictionConfidence/100.0; // utilise l'input (% -> 0..1)
    if(InpLogVerbosity>=2)
        Print("🔍 DEBUG MODE AVANCÉ: should_predict=", should_predict, " | confidence=", confidence, " | min_conf=", min_conf, " | mtf_ok=", mtf_ok);
    
    if(should_predict && confidence >= min_conf && mtf_ok) {
        // Vérifier si on peut ouvrir un nouveau trade pour ce symbole (max 2 par symbole)
        if(!CanOpenTradeForSymbol(_Symbol)) {
            Print("⏸ Limite de trades atteinte pour ", _Symbol, " (max 2 par symbole)");
            return;
        }
        
        // Proximité S/R multi-timeframe obligatoire
        double prox = ProximityToMTFLevelsPct(current_price);
        Print("🔍 DEBUG PROXIMITÉ: prox=", prox, " | InpSRMinProximityPct=", InpSRMinProximityPct);
        UpdateProximityDisplay(prox);
        
        // Vérifier si c'est un symbole Boom/Crash pour assouplir les conditions
        bool isBoomCrash = IsBoomCrashIndex(_Symbol);
        double proximity_threshold = isBoomCrash ? InpSRMinProximityPct * 2.0 : InpSRMinProximityPct;
        
        if(prox > proximity_threshold) {
            Print("❌ SIGNAL BLOQUÉ: Trop loin d'un niveau S/R (", prox, " > ", proximity_threshold, ")");
            return; // trop loin d'un niveau
        }
        
        // Confirmation de tendance supplémentaire pour Boom/Crash
        if(isBoomCrash) {
            bool trend_confirmation = CheckTrendConfirmation(predicted_direction);
            if(!trend_confirmation) {
                Print("❌ SIGNAL BLOQUÉ: Confirmation de tendance insuffisante pour ", _Symbol);
                return;
            }
        }

        // Liquidity & FVG conditions (M15 par défaut) - assouplies
        bool eqH = HasEqualHighs(PERIOD_M15);
        bool eqL = HasEqualLows(PERIOD_M15);
        bool sweepUp = LiquiditySweepUp(PERIOD_M15);
        bool sweepDn = LiquiditySweepDown(PERIOD_M15);
        bool need_fvg = InpRequireFVG;
        bool has_fvg = (predicted_direction>0) ? HasRecentBullFVG(PERIOD_M15) : HasRecentBearFVG(PERIOD_M15);
        // si exigé, mais autoriser si Equal HL + sweep présents
        if(need_fvg && !has_fvg && !( (predicted_direction>0 && eqL && sweepDn) || (predicted_direction<0 && eqH && sweepUp) )) return;

        // Lire métriques de l'indicateur squeeze si dispo
        double atr_ratio=1.0, bbw=0.0, body_z=0.0;
        if(squeeze_handle!=INVALID_HANDLE)
        {
            double b0[], b1[], b2[]; ArraySetAsSeries(b0,true); ArraySetAsSeries(b1,true); ArraySetAsSeries(b2,true);
            ArrayResize(b0,1); ArrayResize(b1,1); ArrayResize(b2,1);
            if(CopyBuffer(squeeze_handle, 1, 0, 1, b1)>0) atr_ratio=b1[0];
            if(CopyBuffer(squeeze_handle, 0, 0, 1, b0)>0) bbw=b0[0];
            if(CopyBuffer(squeeze_handle, 2, 0, 1, b2)>0) body_z=b2[0];
        }

        bool has_equal_hl = (predicted_direction>0)? eqL : eqH;
        bool swept = (predicted_direction>0)? sweepDn : sweepUp;
        double conf_score = ComputeConfluenceScore(predicted_direction, prox, MathMax(1.0,atr_ratio), MathMax(0.0,bbw), MathMax(0.0,body_z),
                                                  has_fvg, has_equal_hl, swept, mtf_ok);
        UpdateScoreDisplay(MathMin(100.0, confidence*100.0 * (0.8+0.2*conf_score)));
        if(conf_score < InpConfluenceMin) return;
        // Garde-fou: n'alerter que sur la bougie en cours (<= 3s depuis l'ouverture)
        datetime bar_time = iTime(_Symbol, InpTimeframe, 0);
        int bar_age = (int)(TimeCurrent() - bar_time);
        if(bar_age > 3) return;
        // Afficher le score en temps réel
        UpdateScoreDisplay(confidence * 100.0);
        // Anti-spam: une seule alerte par symbole pendant le cooldown
        if(alert_lock_active && TimeCurrent() - last_alert_time < InpAlertCooldownSeconds) {
            return;
        }
        if(TimeCurrent() - last_prediction_time > 2) {
            int eta = 2;
            current_prediction.predicted_time = TimeCurrent() + eta;
            current_prediction.predicted_direction = predicted_direction;
            current_prediction.confidence = confidence;
            current_prediction.duration_seconds = eta;
            current_prediction.is_active = true;
            last_prediction_time = TimeCurrent();
            total_predictions++;
            
            DrawPredictionArrow();
            ShowCountdownPopup();
            
            string direction_str = (predicted_direction > 0) ? "BOOM" : "CRASH";
            string notify = StringFormat("🔮 Prédiction: %s | %s | ETA %ds | Confiance %.0f%%",
                                        _Symbol, direction_str, eta, confidence*100);
            last_alert = notify;
            Print(notify);
            if(InpSendNotifications) SendMyNotification(notify);

            // Option: placer un ordre limit si activé
            if(InpUseLimitOrders)
            {
                // Vérifier la limite de trades par symbole (max 2) et la limite globale d'ordres limit (max 5)
                if(!CanOpenTradeForSymbol(_Symbol)) {
                    Print("⏸ Limite de trades atteinte pour ", _Symbol, " (max 2 par symbole) - Ordre limit non placé.");
                } else if(g_pending_limits >= 5) {
                    Print("⏸ Limite globale d'ordres limit atteinte (>=5) - on attend.");
                } else {
                    MqlTradeRequest lr; MqlTradeResult rr; ZeroMemory(lr); ZeroMemory(rr);
                    lr.action = TRADE_ACTION_PENDING;
                    lr.symbol = _Symbol;
                    // Enforcer: BOOM only BUY limit, CRASH only SELL limit
                    if(!IsDirectionAllowedForSymbol(predicted_direction)) {
                        Print("⏸ Direction non autorisée pour ", _Symbol, " (BOOM=>BUY, CRASH=>SELL). Ordre limit ignoré.");
                        return; // quitter précocement le bloc d'ouverture
                    }
                    lr.type   = (ENUM_ORDER_TYPE)((predicted_direction>0)? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT);
                    // Calculer le lot avec multiplicateur d'échec pour les ordres limit
                    double base_lot = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), InpBaseLotSize);
                    lr.volume = CalculateLotWithFailMultiplier(_Symbol, base_lot);
                    lr.magic  = InpMagicNumber;
                    lr.type_filling = (ENUM_ORDER_TYPE_FILLING)GetSupportedFilling();
                    lr.deviation = 100;
                    lr.expiration = TimeCurrent() + InpLimitExpirySec;
                    
                    // Préparer l'ordre avec SL/TP automatiques (ratio 1:3)
                    PrepareLimitOrder(lr, predicted_direction);
                    if(lr.volume <= 0) { Print("❌ LIMIT annulé par filtres de précision"); return; }
                    // Anti-duplication: éviter doublon proche + cooldown
                    double tol2 = InpDuplicatePriceTolerancePoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                    static datetime last_limit_time2 = 0;
                    if(TimeCurrent() - last_limit_time2 < InpDuplicateCooldownSec) {
                        Print("⏸ Cooldown anti-doublon LIMIT actif (", InpDuplicateCooldownSec, "s)");
                        return;
                    }
                    // Empêcher ordres inverses simultanés
                    if(!CanPlaceDirectionForSymbol(predicted_direction)) { return; }
                    for(int oi2=OrdersTotal()-1; oi2>=0; oi2--){
                        ulong ot2 = OrderGetTicket(oi2);
                        if(!OrderSelect(ot2)) continue;
                        if(OrderGetString(ORDER_SYMBOL)!=_Symbol) continue;
                        if((int)OrderGetInteger(ORDER_MAGIC)!=InpMagicNumber) continue;
                        long otype2 = OrderGetInteger(ORDER_TYPE);
                        if(otype2!=ORDER_TYPE_BUY_LIMIT && otype2!=ORDER_TYPE_SELL_LIMIT) continue;
                        double oprice2 = OrderGetDouble(ORDER_PRICE_OPEN);
                        if(MathAbs(oprice2 - lr.price) <= tol2){
                            Print("⏸ Anti-duplication LIMIT: ordre existant à ~même prix (", DoubleToString(oprice2,_Digits), ")");
                            return;
                        }
                    }
                    last_limit_time2 = TimeCurrent();
                    
                    // Calculer le profit potentiel
                    double potential_profit = 0;
                    double potential_loss = 0;
                    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    
                    if(predicted_direction > 0) { // BUY
                        potential_profit = (lr.tp - lr.price) * lr.volume * 100000; // Approximation
                        potential_loss = (lr.price - lr.sl) * lr.volume * 100000;
                    } else { // SELL
                        potential_profit = (lr.price - lr.tp) * lr.volume * 100000;
                        potential_loss = (lr.sl - lr.price) * lr.volume * 100000;
                    }
                    
                    double risk_reward_ratio = (potential_loss > 0) ? potential_profit / potential_loss : 0;
                    
                    Print("💰 LIMIT ORDER PRÉPARÉ: Direction=", (predicted_direction>0)?"BUY":"SELL",
                          " | Profit potentiel=$", DoubleToString(potential_profit, 2),
                          " | Perte potentielle=$", DoubleToString(potential_loss, 2),
                          " | Ratio R:R=1:", DoubleToString(risk_reward_ratio, 1));
                    
                    bool ok = OrderSend(lr, rr);
                    if(!ok){
                        Print("❌ Échec création LIMIT: ", GetLastError(), " - ", rr.comment);
                    } else {
                        g_pending_limits++;
                        Print("✅ LIMIT ORDER PLACÉ: Ticket=", rr.order, 
                              " | Prix=", DoubleToString(lr.price, _Digits),
                              " | SL=", DoubleToString(lr.sl, _Digits),
                              " | TP=", DoubleToString(lr.tp, _Digits),
                              " | Expiration=", TimeToString(lr.expiration, TIME_SECONDS));
                        
                        if(InpSendNotifications) {
                            string direction_str = (predicted_direction > 0) ? "BUY LIMIT" : "SELL LIMIT";
                            string notification = StringFormat("📋 Ordre limit placé: %s %s @ %s | SL: %s | TP: %s | Ratio R:R=1:%.1f", 
                                                             direction_str, _Symbol, DoubleToString(lr.price, _Digits),
                                                             DoubleToString(lr.sl, _Digits), DoubleToString(lr.tp, _Digits), risk_reward_ratio);
                            SendMyNotification(notification);
                        }
                    }
                }
            }

            PlayAlert("PREDICTION");
            // Activer le verrou d'alerte
            alert_lock_active = true;
            last_alert_time = TimeCurrent();
        }
    }
    
    if(current_prediction.is_active) {
        int time_left = (int)(current_prediction.predicted_time - TimeCurrent());
        // Continue updating score display while active
        UpdateScoreDisplay(current_prediction.confidence * 100.0);
        
        if(current_prediction.duration_seconds >= 10 && time_left <= 10 && time_left > 0) {
            static datetime last_warning = 0;
            if(TimeCurrent() - last_warning > 1) {
                PlayAlert("WARNING");
                last_warning = TimeCurrent();
            }
        }
        
        if(current_prediction.duration_seconds >= 5 && time_left <= 3 && time_left > 0) {
            static datetime last_final_warning = 0;
            if(TimeCurrent() - last_final_warning > 1) {
                string direction_str = (current_prediction.predicted_direction > 0) ? "BOOM" : "CRASH";
                Alert("⚠️ SPIKE IMMINENT! " + direction_str + " dans " + IntegerToString(time_left) + " secondes!");
                PlayAlert("FINAL_WARNING");
                last_final_warning = TimeCurrent();
            }
        }
    }
    
    if(current_prediction.is_active && TimeCurrent() >= current_prediction.predicted_time) {
        if(spike_detected && spike_direction == current_prediction.predicted_direction) {
            successful_predictions++;
            Print("✅ PRÉDICTION RÉUSSIE! Direction: ", (spike_direction > 0) ? "BOOM" : "CRASH");
        } else {
            // Annuler le signal si aucun spike après N minutes depuis l'émission
            int timeout_seconds = MathMax(60, InpCancelSignalMinutes * 60);
            if(TimeCurrent() - last_prediction_time >= timeout_seconds) {
                Print("🛑 Annulation du signal: délai dépassé sans spike (", timeout_seconds, "s)");
                RemovePredictionArrow();
                current_prediction.is_active = false;
                alert_lock_active = false; // libère le verrou
            } else {
                // On maintient la flèche affichée et on continue d'attendre
                // sans réémettre d'alerte
                return;
            }
        }

        if(current_prediction.is_active) {
            current_prediction.is_active = false;
            alert_lock_active = false;
        }
    }
    
    if(current_prediction.is_active && TimeCurrent() - last_prediction_time > InpPredictionTimeout) {
        Print("⏰ TIMEOUT PRÉDICTION - Suppression de la flèche");
        RemovePredictionArrow();
        current_prediction.is_active = false;
        alert_lock_active = false; // libère le verrou
    }
}

//+------------------------------------------------------------------+
//| Afficher le popup de décompte                                    |
//+------------------------------------------------------------------+
void ShowCountdownPopup()
{
    if(!current_prediction.is_active) return;
    
    string direction_str = (current_prediction.predicted_direction > 0) ? "BOOM" : "CRASH";
    string emoji = (current_prediction.predicted_direction > 0) ? "🚀" : "💥";
    string arrow_color = (current_prediction.predicted_direction > 0) ? "BLEUE" : "ROUGE";
    string spike_type = (current_prediction.predicted_direction > 0) ? "SPIKE HAUSSIER" : "SPIKE BAISSIER";
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    string popup_message = "═══════════════════════════════════════\n";
    popup_message += emoji + " SPIKE PRÉDIT! " + emoji + "\n";
    popup_message += "═══════════════════════════════════════\n";
    popup_message += "Symbole: " + _Symbol + "\n";
    popup_message += "Type: " + spike_type + "\n";
    popup_message += "Direction: " + direction_str + "\n";
    popup_message += "Flèche: " + arrow_color + "\n";
    popup_message += "Prix actuel: " + DoubleToString(current_price, _Digits) + "\n";
    popup_message += "Temps: 30 secondes\n";
    popup_message += "Confiance: " + DoubleToString(current_prediction.confidence * 100, 0) + "%\n";
    popup_message += "Probabilité: " + DoubleToString(current_prediction.confidence * 100, 0) + "%\n";
    popup_message += "Durée: " + IntegerToString(current_prediction.duration_seconds) + " secondes\n";
    popup_message += "═══════════════════════════════════════\n";
    popup_message += "Le popup disparaîtra automatiquement";
    
    Alert(popup_message);
    
    Print("🔔 POPUP SPIKE: ", _Symbol, " - ", spike_type, " - ", direction_str, " - Flèche ", arrow_color, " - Prix: ", DoubleToString(current_price, _Digits), " - Confiance: ", DoubleToString(current_prediction.confidence * 100, 0), "%");
    
    if(InpSendNotifications) {
        SendMyNotification("Spike prédit: " + _Symbol + " " + spike_type + " " + direction_str + " dans 1 minute - Prix: " + DoubleToString(current_price, _Digits) + " - Confiance: " + DoubleToString(current_prediction.confidence * 100, 0) + "%");
    }
}

//+------------------------------------------------------------------+
//| Dessiner la flèche de prédiction sur le graphique               |
//+------------------------------------------------------------------+
void DrawPredictionArrow()
{
    if(!current_prediction.is_active) return;
    
    ObjectsDeleteAll(0, "SpikePrediction_");
    ObjectsDeleteAll(0, "SpikeText_");
    
    string arrow_name = "SpikePrediction_" + IntegerToString(TimeCurrent());
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    datetime current_time = TimeCurrent();
    
    // Vérifier si c'est un symbole Boom/Crash pour améliorer l'affichage
    bool isBoomCrash = IsBoomCrashIndex(_Symbol);
    
    color arrow_color = (current_prediction.predicted_direction > 0) ? clrLime : clrOrange;
    if(isBoomCrash) {
        arrow_color = (current_prediction.predicted_direction > 0) ? clrDodgerBlue : clrCrimson;
    }
    
    double arrow_price = current_price;
    if(current_prediction.predicted_direction > 0) {
        arrow_price = current_price + 20 * _Point; // Plus visible
    } else {
        arrow_price = current_price - 20 * _Point;
    }
    
    if(ObjectCreate(0, arrow_name, OBJ_ARROW, 0, current_time, arrow_price)) {
        // Flèches plus visibles pour Boom/Crash
        int arrow_code = isBoomCrash ? 
            ((current_prediction.predicted_direction > 0) ? 241 : 242) : // Flèches spéciales Boom/Crash
            ((current_prediction.predicted_direction > 0) ? 233 : 234);  // Flèches standard
        
        ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, arrow_code);
        ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, arrow_color);
        ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, isBoomCrash ? 5 : 4);
        ObjectSetInteger(0, arrow_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, arrow_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, arrow_name, OBJPROP_HIDDEN, true);
        
        // Texte enrichi avec informations S/R et tendance
        string prediction_text = (current_prediction.predicted_direction > 0) ? "🚀 BOOM" : "💥 CRASH";
        string spike_type = (current_prediction.predicted_direction > 0) ? "HAUSSIER" : "BAISSIER";
        
        prediction_text += " " + spike_type + "\n";
        prediction_text += "Confiance: " + DoubleToString(current_prediction.confidence * 100, 0) + "%\n";
        
        // Ajouter info S/R si disponible
        double prox = ProximityToMTFLevelsPct(current_price);
        if(prox <= 0.20) { // Très proche d'un niveau S/R
            prediction_text += "📍 S/R: " + DoubleToString(prox * 100, 1) + "%\n";
        }
        
        // Ajouter info tendance
        if(isBoomCrash) {
            prediction_text += "📈 TENDANCE CONFIRMÉE\n";
        }
        
        prediction_text += "ETA: 1min";
        
        string text_name = "SpikeText_" + IntegerToString(TimeCurrent());
        if(ObjectCreate(0, text_name, OBJ_TEXT, 0, current_time, arrow_price)) {
            ObjectSetString(0, text_name, OBJPROP_TEXT, prediction_text);
            ObjectSetInteger(0, text_name, OBJPROP_COLOR, arrow_color);
            ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, isBoomCrash ? 10 : 9);
            ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
        }
        
        Print("🎯 FLÈCHE PLACÉE: ", (current_prediction.predicted_direction > 0) ? "BLEUE" : "ROUGE", 
              " | Type: ", (isBoomCrash ? "BOOM/CRASH" : "STANDARD"), " - ", prediction_text);
    }
}

//+------------------------------------------------------------------+
//| Marquage des entrées "mouvement escalier"                       |
//+------------------------------------------------------------------+
// Fonctions escalier supprimées

//+------------------------------------------------------------------+
//| Dessiner une flèche simple pour signal App                      |
//+------------------------------------------------------------------+
void DrawPredictionArrowSimple(int direction)
{
    // Nettoyer les anciennes flèches avant d'en créer une nouvelle
    CleanupOldArrows();
    
    string arrow_name = "SpikePrediction_" + IntegerToString(TimeCurrent());
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    datetime current_time = TimeCurrent();

    color arrow_color = (direction > 0) ? clrBlue : clrRed;
    double arrow_price = current_price;
    if(direction > 0) {
        arrow_price = current_price + 15 * _Point;
    } else {
        arrow_price = current_price - 15 * _Point;
    }

    ObjectCreate(0, arrow_name, OBJ_ARROW, 0, current_time, arrow_price);
    ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, (direction > 0) ? 233 : 234);
    ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, arrow_color);
    ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 4);
    ObjectSetInteger(0, arrow_name, OBJPROP_BACK, false);
    ObjectSetInteger(0, arrow_name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, arrow_name, OBJPROP_HIDDEN, true);
    
    // Enregistrer la flèche pour nettoyage futur
    RegisterArrowForCleanup(arrow_name, current_time);
}

//+------------------------------------------------------------------+
//| Enregistrer une flèche pour nettoyage automatique               |
//+------------------------------------------------------------------+
void RegisterArrowForCleanup(string arrow_name, datetime creation_time)
{
    // Stocker dans un fichier ou variable globale pour nettoyage
    // Pour l'instant, on utilise une approche simple avec timeout
    static datetime last_arrow_time = 0;
    last_arrow_time = creation_time;
}

//+------------------------------------------------------------------+
//| Nettoyer les anciennes flèches                                   |
//+------------------------------------------------------------------+
void CleanupOldArrows()
{
    // Supprimer toutes les flèches de prédiction plus anciennes que 5 minutes
    datetime cutoff_time = TimeCurrent() - 300; // 5 minutes
    
    for(int i = ObjectsTotal(0, 0, OBJ_ARROW) - 1; i >= 0; i--) {
        string obj_name = ObjectName(0, i, 0, OBJ_ARROW);
        if(StringFind(obj_name, "SpikePrediction_") >= 0) {
            datetime obj_time = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME);
            if(obj_time < cutoff_time) {
                ObjectDelete(0, obj_name);
                Print("🧹 Flèche supprimée (timeout): ", obj_name);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier et nettoyer les flèches après spike                    |
//+------------------------------------------------------------------+
void CheckAndCleanupArrowsAfterSpike()
{
    if(!IsBoomCrashIndex(_Symbol)) return;
    
    // Vérifier si un spike a eu lieu récemment
    MqlRates current[5];
    if(CopyRates(_Symbol, InpTimeframe, 0, 5, current) < 5) return;
    
    // Détecter un spike récent (changement de prix significatif)
    double price_change = MathAbs(current[0].close - current[1].close);
    double price_change_pct = price_change / current[1].close;
    
    // Si changement > 0.5%, considérer comme un spike
    if(price_change_pct > 0.005) {
        Print("⚡ SPIKE DÉTECTÉ: ", DoubleToString(price_change_pct * 100, 2), "% - Nettoyage des flèches");
        
        // Supprimer toutes les flèches de prédiction
        for(int i = ObjectsTotal(0, 0, OBJ_ARROW) - 1; i >= 0; i--) {
            string obj_name = ObjectName(0, i, 0, OBJ_ARROW);
            if(StringFind(obj_name, "SpikePrediction_") >= 0) {
                ObjectDelete(0, obj_name);
                Print("🧹 Flèche supprimée après spike: ", obj_name);
            }
        }
        return;
    }
    
    // Vérifier si les conditions de signal ne sont plus valides
    CheckArrowValidity();
}

//+------------------------------------------------------------------+
//| Vérifier la validité des flèches existantes                     |
//+------------------------------------------------------------------+
void CheckArrowValidity()
{
    // Vérifier chaque flèche de prédiction
    for(int i = ObjectsTotal(0, 0, OBJ_ARROW) - 1; i >= 0; i--) {
        string obj_name = ObjectName(0, i, 0, OBJ_ARROW);
        if(StringFind(obj_name, "SpikePrediction_") >= 0) {
            datetime obj_time = (datetime)ObjectGetInteger(0, obj_name, OBJPROP_TIME);
            
            // Si la flèche a plus de 2 minutes, vérifier si elle est encore valide
            if(TimeCurrent() - obj_time > 120) {
                // Vérifier si les conditions de signal sont toujours présentes
                if(!IsSignalStillValid()) {
                    ObjectDelete(0, obj_name);
                    Print("🧹 Flèche supprimée (conditions non valides): ", obj_name);
                }
            }
            
            // Supprimer les flèches trop anciennes (10 minutes)
            if(TimeCurrent() - obj_time > 600) {
                ObjectDelete(0, obj_name);
                Print("🧹 Flèche supprimée (timeout): ", obj_name);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier si le signal est encore valide                         |
//+------------------------------------------------------------------+
bool IsSignalStillValid()
{
    // Vérifier les conditions de base pour un signal valide
    MqlRates current[3];
    if(CopyRates(_Symbol, InpTimeframe, 0, 3, current) < 3) return false;
    
    // 1) Vérifier que le prix n'a pas déjà fait un mouvement significatif
    double price_change = MathAbs(current[0].close - current[1].close);
    double price_change_pct = price_change / current[1].close;
    
    if(price_change_pct > 0.003) { // 0.3% de mouvement
        Print("⏸ Signal invalidé: Mouvement de prix déjà en cours (", DoubleToString(price_change_pct * 100, 2), "%)");
        return false;
    }
    
    // 2) Vérifier que la volatilité est toujours présente
    double atr_current = 0.0; // GetATR(_Symbol, InpTimeframe, 14, 0);
    double atr_avg = 0.0; // GetATR(_Symbol, InpTimeframe, 14, 1);
    
    // Pour l'instant, on considère que le signal est valide si pas de mouvement significatif
    // TODO: Implémenter GetATR pour une vérification plus précise
    
    // 3) Vérifier que la bougie courante n'est pas trop grande (indique que le mouvement a commencé)
    double current_range = current[0].high - current[0].low;
    double prev_range = current[1].high - current[1].low;
    
    if(current_range > prev_range * 1.5) {
        Print("⏸ Signal invalidé: Range de bougie trop grand");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Vérifier si la tendance est alignée avec la direction de trade  |
//+------------------------------------------------------------------+
bool IsTrendAligned(int trade_direction)
{
    // Vérifier EMA50 sur M5 et M15
    int ema5_dir = GetEmaCrossDirection(PERIOD_M5);
    int ema15_dir = GetEmaCrossDirection(PERIOD_M15);
    
    if(trade_direction > 0) { // BUY
        // Pour un BUY, les deux EMA doivent être haussières
        if(ema5_dir <= 0 || ema15_dir <= 0) {
            Print("🚫 TENDANCE BUY: EMA5=", ema5_dir, " EMA15=", ema15_dir, " (doivent être > 0)");
            return false;
        }
    } else { // SELL
        // Pour un SELL, les deux EMA doivent être baissières
        if(ema5_dir >= 0 || ema15_dir >= 0) {
            Print("🚫 TENDANCE SELL: EMA5=", ema5_dir, " EMA15=", ema15_dir, " (doivent être < 0)");
            return false;
        }
    }
    
    Print("✅ TENDANCE ALIGNÉE: EMA5=", ema5_dir, " EMA15=", ema15_dir);
    return true;
}

//+------------------------------------------------------------------+
//| Vérifier l'alignement multi-timeframe strict                    |
//+------------------------------------------------------------------+
bool IsMultiTimeframeTrendAligned(int trade_direction)
{
    // Vérifier plusieurs timeframes pour confirmation
    int ema_m1 = GetEmaCrossDirection(PERIOD_M1);
    int ema_m5 = GetEmaCrossDirection(PERIOD_M5);
    int ema_m15 = GetEmaCrossDirection(PERIOD_M15);
    int ema_h1 = GetEmaCrossDirection(PERIOD_H1);
    
    int bullish_count = 0;
    int bearish_count = 0;
    
    // Compter les tendances
    if(ema_m1 > 0) bullish_count++; else if(ema_m1 < 0) bearish_count++;
    if(ema_m5 > 0) bullish_count++; else if(ema_m5 < 0) bearish_count++;
    if(ema_m15 > 0) bullish_count++; else if(ema_m15 < 0) bearish_count++;
    if(ema_h1 > 0) bullish_count++; else if(ema_h1 < 0) bearish_count++;
    
    if(trade_direction > 0) { // BUY
        // Pour un BUY, au moins N timeframes doivent être haussières
        if(bullish_count < InpMinTimeframesAligned) {
            Print("🚫 MTF BUY: ", bullish_count, "/4 timeframes haussières (minimum ", InpMinTimeframesAligned, ")");
            return false;
        }
    } else { // SELL
        // Pour un SELL, au moins N timeframes doivent être baissières
        if(bearish_count < InpMinTimeframesAligned) {
            Print("🚫 MTF SELL: ", bearish_count, "/4 timeframes baissières (minimum ", InpMinTimeframesAligned, ")");
            return false;
        }
    }
    
    Print("✅ MTF ALIGNÉ: ", bullish_count, " haussières, ", bearish_count, " baissières");
    return true;
}

//+------------------------------------------------------------------+
//| Vérifier si le momentum est favorable                           |
//+------------------------------------------------------------------+
bool IsMomentumFavorable(int trade_direction)
{
    // RSI sur M5 et M15
    int rsi_m5 = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
    int rsi_m15 = iRSI(_Symbol, PERIOD_M15, 14, PRICE_CLOSE);
    
    bool rsi_ok = false;
    
    if(rsi_m5 != INVALID_HANDLE && rsi_m15 != INVALID_HANDLE) {
        double rsi5_val[2], rsi15_val[2];
        
        if(CopyBuffer(rsi_m5, 0, 0, 2, rsi5_val) >= 2 && 
           CopyBuffer(rsi_m15, 0, 0, 2, rsi15_val) >= 2) {
            
            if(trade_direction > 0) { // BUY
                // RSI doit être entre 40-70 et en hausse
                rsi_ok = (rsi5_val[0] > 40 && rsi5_val[0] < 70 && rsi5_val[0] > rsi5_val[1]) &&
                         (rsi15_val[0] > 40 && rsi15_val[0] < 70);
            } else { // SELL
                // RSI doit être entre 30-60 et en baisse
                rsi_ok = (rsi5_val[0] > 30 && rsi5_val[0] < 60 && rsi5_val[0] < rsi5_val[1]) &&
                         (rsi15_val[0] > 30 && rsi15_val[0] < 60);
            }
            
            if(!rsi_ok) {
                Print("🚫 MOMENTUM: RSI5=", rsi5_val[0], " RSI15=", rsi15_val[0], " (conditions non remplies)");
            }
        }
        
        IndicatorRelease(rsi_m5);
        IndicatorRelease(rsi_m15);
    }
    
    if(rsi_ok) {
        Print("✅ MOMENTUM FAVORABLE: RSI aligné avec direction");
    }
    
    return rsi_ok;
}

//+------------------------------------------------------------------+
//| Gestion des ordres limit dynamiques                             |
//+------------------------------------------------------------------+
void ManageDynamicLimitOrders()
{
    if(!InpDynamicLimitOrders) return;
    
    // Vérifier l'intervalle de mise à jour
    if(TimeCurrent() - last_limit_order_update < InpLimitOrderUpdateInterval) return;
    last_limit_order_update = TimeCurrent();
    
    // Déterminer le nombre max d'ordres selon le capital
    int max_orders = GetMaxLimitOrdersForCapital();
    
    // Nettoyer les ordres expirés ou exécutés
    CleanupExpiredLimitOrders();
    
    // Mettre à jour les ordres existants
    UpdateExistingLimitOrders();
    
    // Créer de nouveaux ordres si nécessaire
    if(dynamic_orders_count < max_orders) {
        CreateNewLimitOrders();
    }
    
    Print("📊 Ordres limit dynamiques: ", dynamic_orders_count, "/", max_orders, " actifs");
}

//+------------------------------------------------------------------+
//| Obtenir le nombre max d'ordres selon le capital                 |
//+------------------------------------------------------------------+
int GetMaxLimitOrdersForCapital()
{
    // Calculer le nombre d'ordres en fonction du capital disponible
    double available_capital = account_balance;
    
    // Réserver 20% du capital pour les trades en cours
    double reserved_capital = available_capital * 0.20;
    double trading_capital = available_capital - reserved_capital;
    
    // Calculer le lot minimum pour un ordre
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    
    if(min_lot <= 0 || tick_value <= 0) {
        // Valeurs par défaut si pas disponibles
        min_lot = 0.01;
        tick_value = 1.0;
    }
    
    // Calculer le coût approximatif d'un ordre (SL de 10 points)
    double sl_points = 10;
    double cost_per_order = min_lot * sl_points * tick_value;
    
    if(cost_per_order <= 0) {
        // Fallback basé sur le capital
        if(available_capital < 5.0) return 1;
        if(available_capital < 10.0) return 2;
        if(available_capital < 25.0) return 3;
        if(available_capital < 50.0) return 4;
        return 5; // Max 5 ordres
    }
    
    // Calculer le nombre d'ordres possibles
    int max_orders = (int)(trading_capital / cost_per_order);
    
    // Limiter selon les paramètres
    int max_allowed = InpMaxLimitOrders;
    if(available_capital < InpSmallCapitalThreshold) {
        max_allowed = InpMaxLimitOrdersSmallCapital;
    }
    
    // Appliquer les limites de sécurité
    max_orders = MathMin(max_orders, max_allowed);
    max_orders = MathMax(1, max_orders); // Au moins 1 ordre possible
    max_orders = MathMin(10, max_orders); // Max 10 ordres
    
    Print("💰 Capital disponible: $", DoubleToString(available_capital, 2), 
          " | Coût par ordre: $", DoubleToString(cost_per_order, 2),
          " | Ordres max: ", max_orders);
    
    return max_orders;
}

//+------------------------------------------------------------------+
//| Nettoyer les ordres expirés ou exécutés                         |
//+------------------------------------------------------------------+
void CleanupExpiredLimitOrders()
{
    for(int i = dynamic_orders_count - 1; i >= 0; i--) {
        bool order_exists = false;
        
        // Vérifier si l'ordre existe encore
        bool order_found = false;
        for(int j = 0; j < OrdersTotal(); j++) {
            if(OrderGetTicket(j) == dynamic_orders[i].ticket) {
                order_found = true;
                if(OrderGetInteger(ORDER_STATE) == ORDER_STATE_FILLED) {
                    // Ordre exécuté, le supprimer de la liste
                    Print("✅ Ordre limit exécuté: ", dynamic_orders[i].ticket);
                    RemoveDynamicOrder(i);
                    break;
                }
                order_exists = true;
                break;
            }
        }
        
        if(!order_found) {
            // Ordre n'existe plus
            RemoveDynamicOrder(i);
            continue;
        }
        
        // Vérifier si l'ordre a expiré (plus de 1 heure)
        if(!order_exists || (TimeCurrent() - dynamic_orders[i].created_time > 3600)) {
            if(order_exists) {
                // Annuler l'ordre
                MqlTradeRequest request;
                MqlTradeResult result;
                ZeroMemory(request);
                ZeroMemory(result);
                
                request.action = TRADE_ACTION_REMOVE;
                request.order = dynamic_orders[i].ticket;
                
                if(OrderSend(request, result)) {
                    Print("🗑️ Ordre limit supprimé: ", dynamic_orders[i].ticket);
                }
            }
            RemoveDynamicOrder(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Supprimer un ordre dynamique de la liste                       |
//+------------------------------------------------------------------+
void RemoveDynamicOrder(int index)
{
    if(index < 0 || index >= dynamic_orders_count) return;
    
    // Décaler les éléments
    for(int i = index; i < dynamic_orders_count - 1; i++) {
        dynamic_orders[i] = dynamic_orders[i + 1];
    }
    
    dynamic_orders_count--;
}

//+------------------------------------------------------------------+
//| Mettre à jour les ordres existants                             |
//+------------------------------------------------------------------+
void UpdateExistingLimitOrders()
{
    for(int i = 0; i < dynamic_orders_count; i++) {
        // Analyser les nouvelles conditions de marché
        double new_price = CalculateOptimalLimitPrice(dynamic_orders[i].symbol, dynamic_orders[i].type);
        
        if(new_price > 0 && MathAbs(new_price - dynamic_orders[i].price) > _Point * 10) {
            // Prix significativement différent, mettre à jour l'ordre
            UpdateLimitOrderPrice(i, new_price);
        }
    }
}

//+------------------------------------------------------------------+
//| Calculer le prix optimal pour un ordre limit                   |
//+------------------------------------------------------------------+
double CalculateOptimalLimitPrice(string symbol, int order_type)
{
    // Obtenir le prix actuel
    double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(current_price <= 0) return 0;
    
    // Analyser la tendance et les niveaux S/R
    double adjustment = InpLimitOrderPriceAdjustment / 100.0;
    
    if(order_type == ORDER_TYPE_BUY_LIMIT) {
        // Pour un BUY limit, placer légèrement en dessous du prix actuel
        double support_level = 0.0; // GetNearestSupportLevel(current_price);
        if(support_level > 0) {
            return support_level * (1 - adjustment);
        }
        return current_price * (1 - adjustment);
    } else if(order_type == ORDER_TYPE_SELL_LIMIT) {
        // Pour un SELL limit, placer légèrement au-dessus du prix actuel
        double resistance_level = 0.0; // GetNearestResistanceLevel(current_price);
        if(resistance_level > 0) {
            return resistance_level * (1 + adjustment);
        }
        return current_price * (1 + adjustment);
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Mettre à jour le prix d'un ordre limit                         |
//+------------------------------------------------------------------+
void UpdateLimitOrderPrice(int order_index, double new_price)
{
    if(order_index < 0 || order_index >= dynamic_orders_count) return;
    
    ulong ticket = dynamic_orders[order_index].ticket;
    
    // Annuler l'ancien ordre
    MqlTradeRequest cancel_request;
    MqlTradeResult cancel_result;
    ZeroMemory(cancel_request);
    ZeroMemory(cancel_result);
    
    cancel_request.action = TRADE_ACTION_REMOVE;
    cancel_request.order = ticket;
    
    if(OrderSend(cancel_request, cancel_result)) {
        // Créer un nouvel ordre avec le nouveau prix
        MqlTradeRequest new_request;
        MqlTradeResult new_result;
        ZeroMemory(new_request);
        ZeroMemory(new_result);
        
        new_request.action = TRADE_ACTION_PENDING;
        new_request.symbol = dynamic_orders[order_index].symbol;
        new_request.type = (ENUM_ORDER_TYPE)dynamic_orders[order_index].type;
        new_request.volume = dynamic_orders[order_index].lot_size;
        new_request.price = new_price;
        new_request.magic = InpMagicNumber;
        new_request.comment = "DynamicLimit_" + IntegerToString(TimeCurrent());
        
        if(OrderSend(new_request, new_result)) {
            // Mettre à jour la structure
            dynamic_orders[order_index].ticket = new_result.order;
            dynamic_orders[order_index].price = new_price;
            dynamic_orders[order_index].update_count++;
            
            Print("🔄 Ordre limit mis à jour: ", ticket, " -> ", new_result.order, " Prix: ", new_price);
        }
    }
}

//+------------------------------------------------------------------+
//| Créer de nouveaux ordres limit                                |
//+------------------------------------------------------------------+
void CreateNewLimitOrders()
{
    // Analyser les opportunités actuelles
    string symbols_to_analyze[] = {"Boom 500 Index", "Crash 500 Index", "Boom 1000 Index", "Crash 1000 Index"};
    
    for(int i = 0; i < ArraySize(symbols_to_analyze) && dynamic_orders_count < GetMaxLimitOrdersForCapital(); i++) {
        string symbol = symbols_to_analyze[i];
        
        // Vérifier si on peut trader ce symbole
        if(!CanCreateLimitOrderForSymbol(symbol)) continue;
        
        // Analyser la direction
        int direction = AnalyzeSymbolDirection(symbol);
        if(direction == 0) continue; // Pas de signal clair
        
        // Créer l'ordre limit
        CreateLimitOrderForSymbol(symbol, direction);
    }
}

//+------------------------------------------------------------------+
//| Vérifier si on peut créer un ordre pour ce symbole             |
//+------------------------------------------------------------------+
bool CanCreateLimitOrderForSymbol(string symbol)
{
    // Vérifier si on a déjà un ordre pour ce symbole dans notre système
    for(int i = 0; i < dynamic_orders_count; i++) {
        if(dynamic_orders[i].symbol == symbol) {
            return false; // Déjà un ordre pour ce symbole
        }
    }
    
    // Vérifier s'il y a des ordres en attente sur ce symbole dans MT5
    for(int i = 0; i < OrdersTotal(); i++) {
        if(OrderGetTicket(i) > 0) {
            string order_symbol = OrderGetString(ORDER_SYMBOL);
            if(order_symbol == symbol) {
                Print("⚠️ Ordre en attente déjà existant sur ", symbol, " dans MT5");
                return false; // Ordre en attente déjà existant
            }
        }
    }
    
    // Vérifier les permissions de trading
    if(!SymbolSelect(symbol, true)) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Analyser la direction d'un symbole                             |
//+------------------------------------------------------------------+
int AnalyzeSymbolDirection(string symbol)
{
    // VÉRIFICATION STRICTE BOOM/CRASH - Éviter trades illogiques
    bool is_boom = (StringFind(symbol, "Boom") >= 0);
    bool is_crash = (StringFind(symbol, "Crash") >= 0);
    
    if(!is_boom && !is_crash) return 0; // Pas un indice Boom/Crash
    
    // Obtenir les données récentes
    MqlRates rates[10];
    if(CopyRates(symbol, PERIOD_M1, 0, 10, rates) < 10) return 0;
    
    // Analyser la tendance récente
    double price_change = (rates[0].close - rates[9].close) / rates[9].close;
    
    // LOGIQUE STRICTE BOOM/CRASH
    if(is_boom) {
        // Pour BOOM : seulement BUY (direction haussière)
        if(price_change > 0.001) {
            Print("✅ BOOM ", symbol, " - Signal BUY valide (tendance haussière)");
            return 1; // BUY
        } else {
            Print("⏸ BOOM ", symbol, " - Pas de signal BUY (tendance non haussière)");
            return 0; // Pas de signal
        }
    } else if(is_crash) {
        // Pour CRASH : seulement SELL (direction baissière)
        if(price_change < -0.001) {
            Print("✅ CRASH ", symbol, " - Signal SELL valide (tendance baissière)");
            return -1; // SELL
        } else {
            Print("⏸ CRASH ", symbol, " - Pas de signal SELL (tendance non baissière)");
            return 0; // Pas de signal
        }
    }
    
    return 0; // Neutre
}

//+------------------------------------------------------------------+
//| Créer un ordre limit pour un symbole                           |
//+------------------------------------------------------------------+
void CreateLimitOrderForSymbol(string symbol, int direction)
{
    // VÉRIFICATION STRICTE BOOM/CRASH AVANT CRÉATION
    bool is_boom = (StringFind(symbol, "Boom") >= 0);
    bool is_crash = (StringFind(symbol, "Crash") >= 0);
    
    if(is_boom && direction < 0) {
        Print("🚫 INTERDIT: SELL sur BOOM ", symbol, " - Logique incohérente");
        return;
    }
    
    if(is_crash && direction > 0) {
        Print("🚫 INTERDIT: BUY sur CRASH ", symbol, " - Logique incohérente");
        return;
    }
    
    // VÉRIFICATION CAPITAL DISPONIBLE
    if(!CanAffordNewLimitOrder(symbol)) {
        Print("💰 Capital insuffisant pour nouvel ordre limit sur ", symbol);
        return;
    }
    
    // VÉRIFICATION ORDRE DÉJÀ EXISTANT SUR CE SYMBOLE
    if(!CanCreateLimitOrderForSymbol(symbol)) {
        Print("⚠️ Ordre limit déjà existant sur ", symbol, " - Éviter doublon");
        return;
    }
    
    double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(current_price <= 0) return;
    
    double lot_size = CalculateLotSize(symbol);
    if(lot_size <= 0) return;
    
    int order_type = (direction > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
    double limit_price = CalculateOptimalLimitPrice(symbol, order_type);
    
    if(limit_price <= 0) return;
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = symbol;
        request.type = (ENUM_ORDER_TYPE)order_type;
    request.volume = lot_size;
    request.price = limit_price;
    request.magic = InpMagicNumber;
    request.comment = "DynamicLimit_" + IntegerToString(TimeCurrent());
    
    if(OrderSend(request, result)) {
        // Ajouter à la liste des ordres dynamiques
        if(dynamic_orders_count < 10) {
            dynamic_orders[dynamic_orders_count].ticket = result.order;
            dynamic_orders[dynamic_orders_count].symbol = symbol;
            dynamic_orders[dynamic_orders_count].type = order_type;
            dynamic_orders[dynamic_orders_count].price = limit_price;
            dynamic_orders[dynamic_orders_count].lot_size = lot_size;
            dynamic_orders[dynamic_orders_count].created_time = TimeCurrent();
            dynamic_orders[dynamic_orders_count].original_price = limit_price;
            dynamic_orders[dynamic_orders_count].update_count = 0;
            
            dynamic_orders_count++;
            
            Print("📝 Ordre limit dynamique créé: ", result.order, " ", symbol, " Prix: ", limit_price);
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier si on peut se permettre un nouvel ordre limit          |
//+------------------------------------------------------------------+
bool CanAffordNewLimitOrder(string symbol)
{
    // Calculer le coût total des ordres existants
    double total_exposure = 0.0;
    
    // Ajouter l'exposition des trades en cours
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionGetTicket(i) > 0) {
            double volume = PositionGetDouble(POSITION_VOLUME);
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            double sl = PositionGetDouble(POSITION_SL);
            
            if(sl > 0) {
                double sl_distance = MathAbs(price - sl);
                double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
                total_exposure += volume * sl_distance * tick_value;
            }
        }
    }
    
    // Ajouter l'exposition des ordres limit existants
    for(int i = 0; i < dynamic_orders_count; i++) {
        double lot_size = dynamic_orders[i].lot_size;
        double sl_points = 10; // SL par défaut de 10 points
        double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
        total_exposure += lot_size * sl_points * tick_value;
    }
    
    // Calculer le coût du nouvel ordre
    double new_order_lot = CalculateLotSize(symbol);
    double new_order_cost = new_order_lot * 10 * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    
    // Vérifier si on peut se le permettre
    double available_capital = account_balance * 0.80; // 80% du capital disponible
    double total_required = total_exposure + new_order_cost;
    
    bool can_afford = (total_required <= available_capital);
    
    if(!can_afford) {
        Print("💰 Capital insuffisant: Requis $", DoubleToString(total_required, 2), 
              " | Disponible $", DoubleToString(available_capital, 2));
    }
    
    return can_afford;
}

//+------------------------------------------------------------------+
//| Détection de zones de spikes multiples en succession            |
//+------------------------------------------------------------------+
void DetectMultiSpikeZones()
{
    static datetime last_multi_check = 0;
    if(TimeCurrent() - last_multi_check < 2) return; // Vérifier toutes les 2 secondes
    last_multi_check = TimeCurrent();
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double current_volatility = CalculateCurrentVolatility();
    
    // Mettre à jour l'historique de volatilité
    static int volatility_index = 0;
    spike_volatility_history[volatility_index] = current_volatility;
    volatility_index = (volatility_index + 1) % 50;
    
    // Détecter si on est dans une zone de cluster de spikes
    bool in_spike_cluster = DetectSpikeCluster(current_price, current_volatility);
    
    if(in_spike_cluster) {
        // Prédire la probabilité de spikes supplémentaires
        double multi_spike_probability = PredictAdditionalSpikes(current_price, current_volatility);
        
        if(multi_spike_probability >= InpMultiSpikeConfidence) {
            // Annoncer la zone de spikes multiples
            AnnounceMultiSpikeZone(multi_spike_probability);
        }
    }
    
    // Mettre à jour le cluster actuel
    UpdateCurrentCluster(current_price, current_volatility);
    
    //--- Gestion du scalping intelligent
    if(InpEnableQuickScalping) {
        UpdateScalpingTracker();
    }
}

//+------------------------------------------------------------------+
//| Calcul de la volatilité actuelle                                |
//+------------------------------------------------------------------+
double CalculateCurrentVolatility()
{
    double volatility_sum = 0;
    int valid_periods = 0;
    
    static int volatility_index = 0;
    for(int i = 1; i < 20; i++) {
        int idx = (volatility_index - i + 50) % 50;
        int prev_idx = (volatility_index - i - 1 + 50) % 50;
        
        if(spike_volatility_history[idx] > 0 && spike_volatility_history[prev_idx] > 0) {
            volatility_sum += MathAbs(spike_volatility_history[idx] - spike_volatility_history[prev_idx]);
            valid_periods++;
        }
    }
    
    return (valid_periods > 0) ? volatility_sum / valid_periods : 0;
}

//+------------------------------------------------------------------+
//| Détection de cluster de spikes                                   |
//+------------------------------------------------------------------+
bool DetectSpikeCluster(double current_price, double current_volatility)
{
    // Vérifier si la volatilité actuelle dépasse le seuil d'accélération
    double avg_volatility = CalculateAverageVolatility();
    bool volatility_spike = current_volatility > (avg_volatility * InpVolatilityAcceleration);
    
    // Vérifier si on est proche d'un niveau S/R (zone de conflit)
    double sr_proximity = ProximityToMTFLevelsPct(current_price);
    bool near_sr = sr_proximity <= InpSimpleSRProximityPct;
    
    // Vérifier l'alignement multi-timeframe
    bool mtf_aligned = CheckMTFAlignment();
    
    // Vérifier la compression/expansion des Bollinger Bands
    bool bb_compression = CheckBollingerCompression();
    
    return volatility_spike && (near_sr || mtf_aligned) && bb_compression;
}

//+------------------------------------------------------------------+
//| Calcul de la volatilité moyenne                                 |
//+------------------------------------------------------------------+
double CalculateAverageVolatility()
{
    double sum = 0;
    int count = 0;
    
    for(int i = 0; i < 50; i++) {
        if(spike_volatility_history[i] > 0) {
            sum += spike_volatility_history[i];
            count++;
        }
    }
    
    return (count > 0) ? sum / count : 0.001;
}

//+------------------------------------------------------------------+
//| Vérification de l'alignement multi-timeframe                    |
//+------------------------------------------------------------------+
bool CheckMTFAlignment()
{
    int dir15 = GetEmaCrossDirection(PERIOD_M15);
    int dir30 = GetEmaCrossDirection(PERIOD_M30);
    int dirH1 = GetEmaCrossDirection(PERIOD_H1);
    
    // Au moins 2 timeframes alignés
    int aligned_count = 0;
    if(dir15 != 0) aligned_count++;
    if(dir30 != 0) aligned_count++;
    if(dirH1 != 0) aligned_count++;
    
    return aligned_count >= 2;
}

//+------------------------------------------------------------------+
//| Vérification de la compression des Bollinger Bands              |
//+------------------------------------------------------------------+
bool CheckBollingerCompression()
{
    static int bb_handle = INVALID_HANDLE; static datetime last_bb_upd=0;
    if(bb_handle == INVALID_HANDLE){
        bb_handle = iBands(_Symbol, PERIOD_M1, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
        if(bb_handle == INVALID_HANDLE) return false;
    }
    
    double bb_upper[3], bb_lower[3], bb_middle[3];
    if(CopyBuffer(bb_handle, 1, 0, 3, bb_upper) < 3 ||
       CopyBuffer(bb_handle, 2, 0, 3, bb_lower) < 3 ||
       CopyBuffer(bb_handle, 0, 0, 3, bb_middle) < 3) {
        IndicatorRelease(bb_handle);
        return false;
    }
    
    // Calculer la largeur des bandes
    double bb_width = (bb_upper[0] - bb_lower[0]) / bb_middle[0];
    double bb_width_avg = ((bb_upper[1] - bb_lower[1]) + (bb_upper[2] - bb_lower[2])) / (bb_middle[1] + bb_middle[2]);
    
    if(TimeCurrent()-last_bb_upd > 300){ // relâcher toutes les 5 min pour éviter fuites
        IndicatorRelease(bb_handle); bb_handle = INVALID_HANDLE; last_bb_upd = TimeCurrent();
    }
    
    // Compression si la largeur actuelle est inférieure à la moyenne
    return bb_width < bb_width_avg * 0.8;
}

//+------------------------------------------------------------------+
//| Prédiction de spikes supplémentaires                             |
//+------------------------------------------------------------------+
double PredictAdditionalSpikes(double current_price, double current_volatility)
{
    double probability = 0.0;
    
    // Facteur 1: Volatilité croissante (30%)
    double volatility_trend = CalculateVolatilityTrend();
    if(volatility_trend > 0) {
        probability += 0.3 * MathMin(volatility_trend * 2, 1.0);
    }
    
    // Facteur 2: Proximité aux niveaux S/R (25%)
    double sr_proximity = ProximityToMTFLevelsPct(current_price);
    if(sr_proximity <= InpSimpleSRProximityPct) {
        probability += 0.25 * (1.0 - sr_proximity / InpSimpleSRProximityPct);
    }
    
    // Facteur 3: Pattern de cluster historique (20%)
    double historical_pattern = AnalyzeHistoricalClusters();
    probability += 0.2 * historical_pattern;
    
    // Facteur 4: Momentum et tendance (15%)
    double momentum_factor = CalculateMomentumFactor();
    probability += 0.15 * momentum_factor;
    
    // Facteur 5: Compression/expansion des indicateurs (10%)
    double compression_factor = CalculateCompressionFactor();
    probability += 0.1 * compression_factor;
    
    return MathMin(probability, 1.0);
}

//+------------------------------------------------------------------+
//| Calcul de la tendance de volatilité                             |
//+------------------------------------------------------------------+
double CalculateVolatilityTrend()
{
    double recent_avg = 0, older_avg = 0;
    int recent_count = 0, older_count = 0;
    
    // Moyenne des 10 dernières périodes
    static int volatility_index = 0;
    for(int i = 0; i < 10; i++) {
        int idx = (volatility_index - i + 50) % 50;
        if(spike_volatility_history[idx] > 0) {
            recent_avg += spike_volatility_history[idx];
            recent_count++;
        }
    }
    
    // Moyenne des 10 périodes précédentes
    for(int i = 10; i < 20; i++) {
        int idx = (volatility_index - i + 50) % 50;
        if(spike_volatility_history[idx] > 0) {
            older_avg += spike_volatility_history[idx];
            older_count++;
        }
    }
    
    if(recent_count > 0) recent_avg /= recent_count;
    if(older_count > 0) older_avg /= older_count;
    
    return (older_avg > 0) ? (recent_avg - older_avg) / older_avg : 0;
}

//+------------------------------------------------------------------+
//| Analyse des clusters historiques                                 |
//+------------------------------------------------------------------+
double AnalyzeHistoricalClusters()
{
    if(cluster_count == 0) return 0.5; // Valeur neutre si pas d'historique
    
    double avg_spikes_per_cluster = 0;
    double avg_confidence = 0;
    
    for(int i = 0; i < cluster_count; i++) {
        avg_spikes_per_cluster += historical_clusters[i].spike_count;
        avg_confidence += historical_clusters[i].confidence;
    }
    
    avg_spikes_per_cluster /= cluster_count;
    avg_confidence /= cluster_count;
    
    // Plus il y a eu de spikes par cluster, plus la probabilité est élevée
    double spike_factor = MathMin(avg_spikes_per_cluster / InpMinSpikesInCluster, 1.0);
    
    return (spike_factor + avg_confidence) / 2.0;
}

//+------------------------------------------------------------------+
//| Calcul du facteur de momentum                                   |
//+------------------------------------------------------------------+
double CalculateMomentumFactor()
{
    double momentum = 0;
    int periods = 0;
    
    static int volatility_index = 0;
    for(int i = 1; i < 15; i++) {
        int idx = (volatility_index - i + 50) % 50;
        int prev_idx = (volatility_index - i - 1 + 50) % 50;
        
        if(spike_volatility_history[idx] > 0 && spike_volatility_history[prev_idx] > 0) {
            momentum += (spike_volatility_history[idx] - spike_volatility_history[prev_idx]) * i;
            periods++;
        }
    }
    
    return (periods > 0) ? MathAbs(momentum / periods) : 0;
}

//+------------------------------------------------------------------+
//| Calcul du facteur de compression                                |
//+------------------------------------------------------------------+
double CalculateCompressionFactor()
{
    // Vérifier la compression des ATR
    static int atr_handle = INVALID_HANDLE; static datetime last_atr_upd=0;
    if(atr_handle == INVALID_HANDLE){
        atr_handle = iATR(_Symbol, PERIOD_M1, 14);
        if(atr_handle == INVALID_HANDLE) return 0.5;
    }
    
    double atr_values[5];
    if(CopyBuffer(atr_handle, 0, 0, 5, atr_values) < 5) {
        IndicatorRelease(atr_handle);
        return 0.5;
    }
    
    double atr_current = atr_values[0];
    double atr_avg = (atr_values[1] + atr_values[2] + atr_values[3] + atr_values[4]) / 4;
    
    if(TimeCurrent()-last_atr_upd > 300){
        IndicatorRelease(atr_handle); atr_handle = INVALID_HANDLE; last_atr_upd = TimeCurrent();
    }
    
    // Compression si ATR actuel < moyenne
    return (atr_avg > 0) ? MathMax(0, 1.0 - atr_current / atr_avg) : 0.5;
}

//+------------------------------------------------------------------+
//| Annonce de zone de spikes multiples                             |
//+------------------------------------------------------------------+
void AnnounceMultiSpikeZone(double probability)
{
    static datetime last_multi_announce = 0;
    if(TimeCurrent() - last_multi_announce < 60) return; // Anti-spam: max 1 annonce par minute
    last_multi_announce = TimeCurrent();
    
    string direction_str = "MIXTE";
    int predicted_direction = 0;
    
    // Déterminer la direction dominante
    int dir15 = GetEmaCrossDirection(PERIOD_M15);
    int dir30 = GetEmaCrossDirection(PERIOD_M30);
    int dirH1 = GetEmaCrossDirection(PERIOD_H1);
    
    int bullish_count = 0, bearish_count = 0;
    if(dir15 > 0) bullish_count++; else if(dir15 < 0) bearish_count++;
    if(dir30 > 0) bullish_count++; else if(dir30 < 0) bearish_count++;
    if(dirH1 > 0) bullish_count++; else if(dirH1 < 0) bearish_count++;
    
    if(bullish_count > bearish_count) {
        direction_str = "HAUSSIER";
        predicted_direction = 1;
    } else if(bearish_count > bullish_count) {
        direction_str = "BAISSIER";
        predicted_direction = -1;
    }
    
    // Créer l'annonce enrichie
    string announce_text = StringFormat("🚀 ZONE SPIKES MULTIPLES DÉTECTÉE!\n%s | Probabilité: %.1f%%\nPréparez-vous à 2+ spikes en succession\n", 
                                       direction_str, probability * 100);
    
    // Ajouter des informations contextuelles
    if(current_cluster.is_active) {
        announce_text += StringFormat("Cluster actif: %d spikes déjà détectés\n", current_cluster.spike_count);
    }
    
    // Ajouter des conseils de trading
    if(predicted_direction > 0) {
        announce_text += "💡 Conseil: Préparez des ordres BUY LIMIT près des supports";
    } else if(predicted_direction < 0) {
        announce_text += "💡 Conseil: Préparez des ordres SELL LIMIT près des résistances";
    } else {
        announce_text += "💡 Conseil: Surveillez les deux directions, zone de conflit";
    }
    
    // Afficher sur le graphique
    DrawMultiSpikeZoneArrow(predicted_direction, probability);
    
    // Notification
    if(InpSendNotifications) {
        SendMyNotification(announce_text);
    }
    
    Print("🎯 ", announce_text);
    
    // Mettre à jour le cluster actuel
    current_cluster.start_time = TimeCurrent();
    current_cluster.is_active = true;
    current_cluster.confidence = probability;
    current_cluster.direction = predicted_direction;
    current_cluster.spike_count = 0;
}

//+------------------------------------------------------------------+
//| Dessin de flèche pour zone de spikes multiples                  |
//+------------------------------------------------------------------+
void DrawMultiSpikeZoneArrow(int direction, double probability)
{
    string arrow_name = "MultiSpikeZone_" + IntegerToString(TimeCurrent());
    datetime current_time = TimeCurrent();
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Position de la flèche
    double arrow_price = current_price;
    if(direction > 0) {
        arrow_price = current_price + 25 * _Point;
    } else if(direction < 0) {
        arrow_price = current_price - 25 * _Point;
    }
    
    // Créer la flèche
    ObjectCreate(0, arrow_name, OBJ_ARROW, 0, current_time, arrow_price);
    
    // Style spécial pour les zones de spikes multiples
    ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, (direction > 0) ? 241 : 242); // Flèches spéciales
    ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, (probability > 0.9) ? clrLime : clrOrange);
    ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 5);
    ObjectSetInteger(0, arrow_name, OBJPROP_BACK, false);
    ObjectSetInteger(0, arrow_name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, arrow_name, OBJPROP_HIDDEN, true);
    
    // Ajouter un texte explicatif
    string text_name = "MultiSpikeText_" + IntegerToString(TimeCurrent());
    ObjectCreate(0, text_name, OBJ_TEXT, 0, current_time, arrow_price);
    ObjectSetString(0, text_name, OBJPROP_TEXT, StringFormat("ZONE MULTI-SPIKE\nProb: %.0f%%", probability * 100));
    ObjectSetInteger(0, text_name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
    ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Mise à jour du cluster actuel                                   |
//+------------------------------------------------------------------+
void UpdateCurrentCluster(double current_price, double current_volatility)
{
    if(!current_cluster.is_active) return;
    
    // Mettre à jour les prix min/max
    if(current_cluster.price_range_high == 0 || current_price > current_cluster.price_range_high) {
        current_cluster.price_range_high = current_price;
    }
    if(current_cluster.price_range_low == 0 || current_price < current_cluster.price_range_low) {
        current_cluster.price_range_low = current_price;
    }
    
    // Mettre à jour la volatilité moyenne
    current_cluster.avg_volatility = (current_cluster.avg_volatility + current_volatility) / 2;
    if(current_volatility > current_cluster.max_volatility) {
        current_cluster.max_volatility = current_volatility;
    }
    
    // Vérifier si le cluster est terminé
    if(TimeCurrent() - current_cluster.start_time > InpSpikeClusterWindow) {
        // Sauvegarder le cluster dans l'historique
        if(cluster_count < 10) {
            historical_clusters[cluster_count] = current_cluster;
            cluster_count++;
        } else {
            // Décaler les clusters et ajouter le nouveau
            for(int i = 0; i < 9; i++) {
                historical_clusters[i] = historical_clusters[i + 1];
            }
            historical_clusters[9] = current_cluster;
        }
        
        // Réinitialiser le cluster actuel
        ZeroMemory(current_cluster);
    }
}

//+------------------------------------------------------------------+
//| Mise à jour du tracker de scalping                               |
//+------------------------------------------------------------------+
void UpdateScalpingTracker()
{
    datetime current_time = TimeCurrent();
    datetime hour_start = current_time - (current_time % 3600); // Début de l'heure actuelle
    
    // Réinitialiser les compteurs horaires
    for(int i = 0; i < scalping_count; i++) {
        if(scalping_tracker[i].last_trade_time < hour_start) {
            scalping_tracker[i].trades_this_hour = 0;
        }
        
        // Vérifier le cooldown
        if(scalping_tracker[i].is_in_cooldown) {
            datetime cooldown_end = scalping_tracker[i].last_trade_time + (InpScalpingCooldownMinutes * 60);
            if(current_time >= cooldown_end) {
                scalping_tracker[i].is_in_cooldown = false;
                Print("✅ Cooldown terminé pour ", scalping_tracker[i].symbol, " - Prêt pour nouveau scalping");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier si on peut scalper un symbole                           |
//+------------------------------------------------------------------+
bool CanScalpSymbol(string symbol)
{
    if(!InpEnableQuickScalping) return true;
    
    datetime current_time = TimeCurrent();
    datetime hour_start = current_time - (current_time % 3600);
    
    // Chercher le symbole dans le tracker
    for(int i = 0; i < scalping_count; i++) {
        if(scalping_tracker[i].symbol == symbol) {
            // Vérifier le cooldown
            if(scalping_tracker[i].is_in_cooldown) {
                datetime cooldown_end = scalping_tracker[i].last_trade_time + (InpScalpingCooldownMinutes * 60);
                if(current_time < cooldown_end) {
                    return false; // Encore en cooldown
                }
            }
            
            // Vérifier la limite horaire
            if(scalping_tracker[i].last_trade_time >= hour_start) {
                if(scalping_tracker[i].trades_this_hour >= InpMaxScalpingTradesPerHour) {
                    return false; // Limite horaire atteinte
                }
            }
            
            return true;
        }
    }
    
    // Symbole pas encore tracké - autoriser
    return true;
}

//+------------------------------------------------------------------+
//| Enregistrer un trade de scalping                                 |
//+------------------------------------------------------------------+
void RecordScalpingTrade(string symbol, double profit)
{
    if(!InpEnableQuickScalping) return;
    
    datetime current_time = TimeCurrent();
    datetime hour_start = current_time - (current_time % 3600);
    
    // Chercher le symbole dans le tracker
    for(int i = 0; i < scalping_count; i++) {
        if(scalping_tracker[i].symbol == symbol) {
            scalping_tracker[i].last_trade_time = current_time;
            scalping_tracker[i].total_profit_today += profit;
            scalping_tracker[i].is_in_cooldown = true; // Activer cooldown
            
            if(scalping_tracker[i].last_trade_time >= hour_start) {
                scalping_tracker[i].trades_this_hour++;
            } else {
                scalping_tracker[i].trades_this_hour = 1;
            }
            
            Print("📊 Scalping enregistré: ", symbol, " | Profit: $", DoubleToString(profit, 2), 
                  " | Trades/heure: ", scalping_tracker[i].trades_this_hour, 
                  " | Cooldown: ", InpScalpingCooldownMinutes, "min");
            return;
        }
    }
    
    // Ajouter nouveau symbole au tracker
    if(scalping_count < 20) {
        scalping_tracker[scalping_count].symbol = symbol;
        scalping_tracker[scalping_count].last_trade_time = current_time;
        scalping_tracker[scalping_count].trades_this_hour = 1;
        scalping_tracker[scalping_count].total_profit_today = profit;
        scalping_tracker[scalping_count].is_in_cooldown = true;
        scalping_count++;
        
        Print("📊 Nouveau symbole ajouté au tracker scalping: ", symbol);
    }
}

//+------------------------------------------------------------------+
//| Vérifier si on doit fermer rapidement pour sécuriser             |
//+------------------------------------------------------------------+
bool ShouldQuickClose(ulong ticket)
{
    if(!InpEnableQuickScalping) return false;
    
    if(!PositionSelectByTicket(ticket)) return false;
    
    // PROTECTION ANTI-CASCADE - Empêcher les fermetures trop rapides
    if(ShouldPreventRapidClose(ticket))
    {
        Print("🛡️ Fermeture rapide bloquée pour ticket ", ticket, " - Protection anti-cascade");
        return false;
    }
    
    double profit = PositionGetDouble(POSITION_PROFIT);
    string symbol = PositionGetString(POSITION_SYMBOL);
    
    // Fermer si profit >= objectif rapide
    if(profit >= InpQuickProfitTarget) {
        Print("🎯 Objectif scalping rapide atteint: $", DoubleToString(profit, 2), " sur ", symbol);
        return true;
    }
    
    // Fermer si on approche de la limite horaire et qu'on a un petit profit
    for(int i = 0; i < scalping_count; i++) {
        if(scalping_tracker[i].symbol == symbol) {
            if(scalping_tracker[i].trades_this_hour >= (InpMaxScalpingTradesPerHour - 1) && profit > 0.5) {
                Print("⏰ Limite horaire approchée - Sécurisation profit: $", DoubleToString(profit, 2));
                return true;
            }
            break;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Vérifier les fermetures rapides de scalping                     |
//+------------------------------------------------------------------+
void CheckQuickScalpingCloses()
{
    if(!InpEnableQuickScalping) return;
    
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) continue;
        
        if(ShouldQuickClose(active_trades[i].ticket)) {
            // Fermer la position pour sécuriser le gain
            string symbol = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            int ptype = (int)PositionGetInteger(POSITION_TYPE);
            double vol = PositionGetDouble(POSITION_VOLUME);
            datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
            
            MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
            rq.action = TRADE_ACTION_DEAL;
            rq.position = active_trades[i].ticket;
            rq.symbol = symbol;
            rq.volume = vol;
            rq.type = (ptype == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            rq.magic = InpMagicNumber;
            rq.comment = "QuickScalping";
            
            if(OrderSend(rq, rs)) {
                Print("🎯 Fermeture scalping rapide: +$", DoubleToString(profit, 2), " sur ", symbol);
                RecordScalpingTrade(symbol, profit);
                
                // Enregistrer l'historique pour protection anti-cascade
                RecordTradeHistory(symbol, open_time, TimeCurrent(), ptype, profit, true);
                UpdateLastTradeTime(symbol);
                
                // Nettoyer le trade des actifs
                active_trades[i].ticket = 0;
                active_trades[i].open_time = 0;
                active_trades[i].open_price = 0;
                active_trades[i].lot_size = 0;
                active_trades[i].direction = 0;
                active_trades[i].is_spike_trade = false;
                active_trades[i].spike_start_price = 0;
                active_trades[i].profit_target = 0;
                active_trades[i].loss_limit = 0;
            } else {
                Print("❌ Échec fermeture scalping: ", GetLastError(), " - ", rs.comment);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Vérification des signaux de l'application locale                 |
//+------------------------------------------------------------------+
void CheckAppSignals()
{
    if(TimeCurrent() - last_app_check < InpCheckInterval) return;
    last_app_check = TimeCurrent();
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    static double last_check_price = 0;
    
    price_history[history_index] = current_price;
    history_index = (history_index + 1) % 100;
    
    if(last_check_price > 0) {
        double price_change = (current_price - last_check_price) / last_check_price * 100;
        
        double volatility = 0;
        for(int i = 1; i < 10; i++) {
            int idx = (history_index - i + 100) % 100;
            int prev_idx = (history_index - i - 1 + 100) % 100;
            if(price_history[idx] > 0 && price_history[prev_idx] > 0) {
                volatility += MathAbs((price_history[idx] - price_history[prev_idx]) / price_history[prev_idx]);
            }
        }
        volatility /= 9;
        
        double ma_values[3];
        double rsi_values[3];
        
        if(CopyBuffer(ma_handle, 0, 0, 3, ma_values) >= 0 && 
           CopyBuffer(rsi_handle, 0, 0, 3, rsi_values) >= 0) {
            
            double signal_score = 0;
            int signal_direction = 0;
            string signal_reason = "";
            
            if(MathAbs(price_change) >= 0.1) {
                signal_score += 0.3;
                signal_direction = (price_change > 0) ? 1 : -1;
                signal_reason += "Changement prix: " + DoubleToString(price_change, 2) + "% ";
            }
            
            if(volatility > 0.0005) {
                signal_score += 0.2;
                signal_reason += "Volatilité: " + DoubleToString(volatility*100, 2) + "% ";
            }
            
            if(rsi_values[0] < 30) {
                signal_score += 0.25;
                signal_direction = 1;
                signal_reason += "RSI Survente ";
            }
            else if(rsi_values[0] > 70) {
                signal_score += 0.25;
                signal_direction = -1;
                signal_reason += "RSI Surachat ";
            }
            
            if(ma_values[0] > ma_values[1] && ma_values[1] < ma_values[2]) {
                signal_score += 0.15;
                signal_direction = 1;
                signal_reason += "MA Croisement Haussier ";
            }
            else if(ma_values[0] < ma_values[1] && ma_values[1] > ma_values[2]) {
                signal_score += 0.15;
                signal_direction = -1;
                signal_reason += "MA Croisement Baissier ";
            }
            
            if(signal_score >= 0.8 && signal_direction != 0) { // Score minimum 80%
            app_signal_received = true;
                spike_direction = signal_direction;
            
                // Flèche anticipée avant spike
                DrawPredictionArrowSimple(signal_direction);

                string dir_str = (signal_direction > 0) ? "BUY" : "SELL";
                    string spike_type = (signal_direction > 0) ? "BOOM" : "CRASH";
                int eta_seconds = 60;
                string msg = StringFormat("App Signal: %s | Direction: %s (%s) | ETA %ds | Price %s | Score %.0f%% | %s",
                                          _Symbol, dir_str, spike_type, eta_seconds, DoubleToString(current_price, _Digits), signal_score*100, signal_reason);
                last_alert = msg;
                Print("🎯 ", msg);
                PlayAlert("SPIKE");
                if(InpSendNotifications) SendMyNotification(msg);
            }
        }
    }
    
    last_check_price = current_price;
}

//+------------------------------------------------------------------+
//| Calcul de la taille de lot avec gestion du risque améliorée     |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
    double lot_size = InpBaseLotSize;
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    
    //--- Calcul basé sur le pourcentage de risque
    if(InpUseRiskManagement) {
        double risk_amount = current_balance * InpRiskPercent / 100.0;
        double stop_loss_points = InpStopLoss * _Point;
        double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        
        if(stop_loss_points > 0 && tick_value > 0 && tick_size > 0) {
            double risk_lot_size = risk_amount / (stop_loss_points / tick_size * tick_value);
            lot_size = MathMin(lot_size, risk_lot_size);
        }
    }
    
    //--- Ajustement Martingale intelligent
    if(InpUseMartingale && consecutive_losses > 0) {
        // Limiter le multiplicateur pour éviter des pertes excessives
        int max_martingale_levels = MathMin(consecutive_losses, 5);
        double multiplier = MathPow(InpMartingaleMultiplier, max_martingale_levels);
        
        // Ajuster selon la performance récente
        double recent_performance = (total_profit - total_loss) / MathMax(current_balance, 1);
        if(recent_performance < -0.1) { // Si perte > 10%
            multiplier *= 0.8; // Réduire l'agressivité
        }
        
        lot_size = InpBaseLotSize * multiplier;
        
        // Vérification de la marge disponible
        double margin_required = lot_size * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
        if(margin_required > free_margin * 0.7) { // Maximum 70% de la marge libre
            lot_size = InpBaseLotSize * 0.5; // Réduire drastiquement
        }
    }
    
    //--- Ajustement basé sur la performance
    if(total_loss > total_profit) {
        double loss_ratio = total_loss / MathMax(total_profit + 1, 1);
        double recovery_multiplier = 1 + (loss_ratio * InpRecoveryFactor * 0.5); // Moins agressif
        lot_size *= recovery_multiplier;
    }
    
    //--- Ajustement basé sur la volatilité récente
    static double recent_volatility = 0;
    static datetime last_volatility_update = 0;
    
    if(TimeCurrent() - last_volatility_update > 60) { // Mise à jour toutes les minutes
        double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        static double last_vol_price = 0;
        if(last_vol_price > 0) {
            double price_change = MathAbs(current_price - last_vol_price) / last_vol_price;
            recent_volatility = recent_volatility * 0.9 + price_change * 0.1; // Moyenne mobile
        }
        last_vol_price = current_price;
        last_volatility_update = TimeCurrent();
    }
    
    // Réduire la taille du lot en cas de forte volatilité
    if(recent_volatility > 0.01) { // Plus de 1% de volatilité
        lot_size *= (1 - recent_volatility * 10); // Réduction proportionnelle
    }
    
    //--- Limites du broker
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(lot_size, min_lot);
    lot_size = MathMin(lot_size, max_lot);
    lot_size = MathMin(lot_size, InpMaxLotSize); // Limite utilisateur
    lot_size = MathRound(lot_size / lot_step) * lot_step;
    
    //--- Vérification finale de sécurité
    double final_margin_required = lot_size * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
    if(final_margin_required > free_margin * 0.8) {
        lot_size = min_lot; // Lot minimum en cas de problème
    }
    
    return lot_size;
}

//+------------------------------------------------------------------+
//| Mise à jour des statistiques de trading                          |
//+------------------------------------------------------------------+
void UpdateTradingStats(double profit)
{
    if(profit > 0) {
        total_profit += profit;
        consecutive_losses = 0;
        current_lot_size = adjusted_base_lot_size;
        winning_trades++;
        
        if(profit > max_profit) {
            max_profit = profit;
        }
        
        PlayAlert("PROFIT");
    } else {
        total_loss += MathAbs(profit);
        consecutive_losses++;
        losing_trades++;
        
        if(MathAbs(profit) > max_loss) {
            max_loss = MathAbs(profit);
        }
        
        PlayAlert("LOSS");
    }
    
    total_trades++;
    win_rate = (total_trades > 0) ? (double)winning_trades / total_trades * 100 : 0;
    last_trade_time = TimeCurrent();
    
    account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    account_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    Print("Stats - Profit: ", DoubleToString(total_profit, 2), 
          " Loss: ", DoubleToString(total_loss, 2),
          " Consecutive Losses: ", consecutive_losses,
          " Win Rate: ", DoubleToString(win_rate, 1), "%");
}

//+------------------------------------------------------------------+
//| Vérification de la viabilité du trade                            |
//+------------------------------------------------------------------+
bool IsTradeViable()
{
    Print("🔍 VÉRIFICATION VIABILITÉ: trade_count=", trade_count, "/", InpMaxTrades, " consecutive_losses=", consecutive_losses);
    
    // Vérifier la limite globale de trades
    if(trade_count >= InpMaxTrades) {
        Print("❌ Nombre maximum de trades global atteint");
        return false;
    }
    
    // Vérifier la limite de trades par symbole (max 2)
    if(!CanOpenTradeForSymbol(_Symbol)) {
        Print("❌ Limite de trades par symbole atteinte pour ", _Symbol);
        return false;
    }

    // Filtre anti-range: exiger tendance confirmée
    int assumed_dir = (CurrentTrendBias() >= 0) ? 1 : -1; // fallback simple
    if(!CheckTrendConfirmation(assumed_dir)) {
        Print("⏸ Marché en range / tendance non confirmée - pas de trade");
        return false;
    }
    
    if(consecutive_losses >= InpMaxConsecutiveLosses) {
        Print("❌ Trop de pertes consécutives: ", consecutive_losses, "/", InpMaxConsecutiveLosses);
        return false;
    }
    
    double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    double margin_required = InpBaseLotSize * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
    
    Print("💰 MARGIN: Libre=", DoubleToString(free_margin, 2), " Requis=", DoubleToString(margin_required, 2));
    
    if(margin_required > free_margin * 0.8) { // Plus permissif (80% au lieu de 95%)
        Print("❌ Marge insuffisante pour ouvrir un trade");
        return false;
    }
    
    Print("✅ Trade viable");
    return true;
}

//+------------------------------------------------------------------+
//| Ouverture d'un trade                                             |
//+------------------------------------------------------------------+
void OpenTrade(int direction)
{
    if(!IsTradeViable()) {
        Print("Trade non viable, abandon");
        return;
    }

    double lot_size = CalculateLotSize();
    // Ajuster TP pour viser rentabilisation en InpTargetRecoveryTrades
    int tp_points = InpTakeProfit;
    if(InpTargetRecoveryTrades > 0 && InpTakeProfit > 0 && InpStopLoss > 0) {
        double equity_for_risk = MathMax(InpUserCapital, account_balance);
        double per_trade_target = (total_loss > 0 ? (total_loss) : (InpMinCapital)) / (double)InpTargetRecoveryTrades;
        // Approx: points TP = money_target / (lot * tick_value) / _Point
        double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        if(tick_value > 0 && lot_size > 0) {
            int dynamic_tp = (int)MathRound((per_trade_target / (lot_size * tick_value)) / _Point);
            tp_points = MathMax(tp_points, dynamic_tp);
        }
    }
    
    MqlTradeRequest request;
    MqlTradeResult  result;
    ZeroMemory(request);
    ZeroMemory(result);

    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot_size;
    request.type = (ENUM_ORDER_TYPE)((direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
    request.magic = InpMagicNumber;
    request.deviation = 10;
    request.type_filling = ORDER_FILLING_FOK;
    request.comment = "SpikeHunter_" + IntegerToString((int)GetTickCount());

    if(direction > 0) {
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    } else {
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    }

    if(InpStopLoss > 0) {
        double sl_points = InpStopLoss * _Point;
        request.sl = (direction > 0) ? request.price - sl_points : request.price + sl_points;
    }
    if(tp_points > 0) {
        double tp_p = tp_points * _Point;
        request.tp = (direction > 0) ? request.price + tp_p : request.price - tp_p;
    }

    if(OrderSend(request, result)) {
        if(result.retcode == TRADE_RETCODE_DONE) {
            AddActiveTrade(result.order, direction, request.price, lot_size);
            UpdateSymbolQuota(_Symbol); // Mettre à jour le quota du symbole
            UpdateLastTradeTime(_Symbol); // Enregistrer le temps du trade
            string direction_str = (direction > 0) ? "BUY" : "SELL";
            Print("TRADE OUVERT: ", direction_str, " ", _Symbol, " Prix: ", DoubleToString(request.price,_Digits), " Lot: ", lot_size);
            Print("Consecutive Losses: ", consecutive_losses, " Total Profit: ", DoubleToString(total_profit, 2));
            last_alert = "Trade ouvert: " + direction_str + " @ " + DoubleToString(request.price, _Digits);
            PlayAlert("TRADE_OPEN");

            if(InpSendNotifications) {
                SendMyNotification("Trade ouvert: " + direction_str + " " + _Symbol + " @ " + DoubleToString(request.price, _Digits) + " Lot: " + DoubleToString(lot_size, 2));
            }
        } else {
            Print("ERREUR ouverture trade: ", result.retcode, " - ", result.comment);
        }
    } else {
        Print("OrderSend() a échoué (bool false)");
    }
}

//+------------------------------------------------------------------+
//| Ajout d'un trade actif                                           |
//+------------------------------------------------------------------+
void AddActiveTrade(ulong ticket, int direction, double price, double volume)
{
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) {
            active_trades[i].ticket = ticket;
            active_trades[i].open_time = TimeCurrent();
            active_trades[i].open_price = price;
            active_trades[i].lot_size = volume;
            active_trades[i].direction = direction;
            active_trades[i].is_spike_trade = true;
            active_trades[i].spike_start_price = price;
            trade_count++;
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Vérification des trades actifs et ordres limit                  |
//+------------------------------------------------------------------+
void CheckActiveTrades()
{
    //--- Vérifier la fermeture automatique des trades profitables (200% du SL)
    CheckAutoCloseProfitableTrades();
    
    //--- Nettoyer les flèches après spike
    CheckAndCleanupArrowsAfterSpike();
    
    //--- Gérer les ordres limit dynamiques
    ManageDynamicLimitOrders();
    //--- Appliquer TP/SL en dollars par trade et par symbole
    EnforceDollarStops();
    //--- Appliquer la limite globale de perte flottante
    EnforceGlobalMaxFloatLoss();
    //--- Sortie anticipée si profit >= seuil et tendance non uniforme
    EnforceEarlyExitOnChop();
    //--- Scalping intelligent - fermeture rapide pour sécuriser
    CheckQuickScalpingCloses();
    
    //--- Vérifier les positions fermées
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) continue;

        if(!PositionSelectByTicket(active_trades[i].ticket)) {
            double trade_profit = 0;
            
            if(HistorySelectByPosition(active_trades[i].ticket)) {
                int total_deals = HistoryDealsTotal();
                for(int j = 0; j < total_deals; j++) {
                    ulong deal_ticket = HistoryDealGetTicket(j);
                    if(HistoryDealGetInteger(deal_ticket, DEAL_POSITION_ID) == active_trades[i].ticket) {
                        trade_profit += HistoryDealGetDouble(deal_ticket, DEAL_PROFIT);
                    }
                }
            }
            
            UpdateTradingStats(trade_profit);
            
            string direction_str = (active_trades[i].direction > 0) ? "BUY" : "SELL";
            string profit_str = (trade_profit >= 0) ? "PROFIT" : "LOSS";
            Print("TRADE FERMÉ: ", direction_str, " ", _Symbol, " Ticket: ", active_trades[i].ticket, " ", profit_str, ": ", DoubleToString(trade_profit, 2));
            
            last_alert = "Trade fermé: " + direction_str + " " + profit_str + ": " + DoubleToString(trade_profit, 2);
            PlayAlert("TRADE_CLOSE");
            
            if(InpSendNotifications) {
                SendMyNotification("Trade fermé: " + direction_str + " " + _Symbol + " " + profit_str + ": " + DoubleToString(trade_profit, 2));
            }

            active_trades[i].ticket = 0;
            trade_count--;
        }
    }
    
    //--- Vérifier les ordres limit expirés
    CheckExpiredLimitOrders();
}

//+------------------------------------------------------------------+
//| Vérification des ordres limit expirés                           |
//+------------------------------------------------------------------+
void CheckExpiredLimitOrders()
{
    datetime current_time = TimeCurrent();
    
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong order_ticket = OrderGetTicket(i);
        if(order_ticket == 0) continue;
        
        if(!OrderSelect(order_ticket)) continue;
        
        if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        
        long order_type = OrderGetInteger(ORDER_TYPE);
        if(order_type != ORDER_TYPE_BUY_LIMIT && order_type != ORDER_TYPE_SELL_LIMIT) continue;
        
        datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
        
        if(expiration > 0 && current_time >= expiration) {
            // Marquer l'ordre comme expiré (suppression manuelle)
                g_pending_limits = MathMax(g_pending_limits - 1, 0);
                Print("⏰ ORDRE LIMIT EXPIRÉ: Ticket=", order_ticket, " | Type=", (order_type == ORDER_TYPE_BUY_LIMIT) ? "BUY" : "SELL");
            Print("⚠️ Suppression manuelle requise - L'ordre sera supprimé automatiquement par le broker");
                
                if(InpSendNotifications) {
                    string direction_str = (order_type == ORDER_TYPE_BUY_LIMIT) ? "BUY LIMIT" : "SELL LIMIT";
                    SendMyNotification("⏰ Ordre limit expiré: " + direction_str + " " + _Symbol);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Mise à jour des trailing stops                                   |
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) continue;
        if(!PositionSelectByTicket(active_trades[i].ticket)) continue;

        double current_price = (active_trades[i].direction > 0) ?
                              SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                              SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double current_sl = PositionGetDouble(POSITION_SL);
        double open_price = active_trades[i].open_price;

        double profit_distance = 0;
        if(active_trades[i].direction > 0) {
            profit_distance = current_price - open_price;
        } else {
            profit_distance = open_price - current_price;
        }

        // Breakeven/Trailing basés sur R multiples
        double entry = active_trades[i].open_price;
        double sl_p = PositionGetDouble(POSITION_SL);
        double risk_pts = MathAbs(entry - sl_p)/_Point;
        double profit_pts = MathAbs(current_price - entry)/_Point;
        double r_multiple = (risk_pts>0)? (profit_pts/risk_pts) : 0.0;

        // Passer au break-even
        if(r_multiple >= InpBreakevenAtRR && sl_p != 0) {
            double be_sl = entry + ((active_trades[i].direction>0)? +2 : -2) * _Point; // +2 pts buffer
            if((active_trades[i].direction>0 && be_sl>sl_p) || (active_trades[i].direction<0 && (sl_p==0 || be_sl<sl_p))) {
                MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
                rq.action = TRADE_ACTION_SLTP;
                rq.position = active_trades[i].ticket;
                rq.symbol = _Symbol;
                rq.sl = be_sl;
                rq.tp = PositionGetDouble(POSITION_TP);
                if(OrderSend(rq, rs)) Print("🔒 Break-even appliqué: ", DoubleToString(be_sl,_Digits));
            }
        }

        // Trailing après seuil R
        if(r_multiple >= InpTrailAfterRR) {
            double new_sl = 0;
            if(active_trades[i].direction > 0) {
                new_sl = current_price - InpTrailStepPoints * _Point;
            } else {
                new_sl = current_price + InpTrailStepPoints * _Point;
            }

            if((active_trades[i].direction > 0 && new_sl > current_sl) ||
               (active_trades[i].direction < 0 && (current_sl == 0 || new_sl < current_sl))) {

                MqlTradeRequest request;
                MqlTradeResult  result;
                ZeroMemory(request);
                ZeroMemory(result);

                request.action = TRADE_ACTION_SLTP;
                request.position = active_trades[i].ticket;
                request.sl = new_sl;
                request.tp = PositionGetDouble(POSITION_TP);

                if(OrderSend(request, result)) {
                    Print("Trailing Stop mis à jour: ", active_trades[i].ticket, " Nouveau SL: ", DoubleToString(new_sl,_Digits));
                } else {
                    Print("OrderSend TRADE_ACTION_SLTP failed");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Fonction de notification - renommée pour éviter conflit système  |
//+------------------------------------------------------------------+
void SendMyNotification(string message)
{
    Print("📱 TENTATIVE D'ENVOI NOTIFICATION: ", message);
    Print("🔍 DEBUG NOTIFICATION: Terminal Trade Allowed=", TerminalInfoInteger(TERMINAL_TRADE_ALLOWED));
    Print("🔍 DEBUG NOTIFICATION: Terminal Notifications=", TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED));
    
    // Filtrage: ne jamais envoyer certaines notifications d'erreur
    string msg_copy = message;
    StringToLower(msg_copy);
    string _msg = msg_copy;
    if(StringFind(_msg, "request failed") >= 0 ||
       StringFind(_msg, "unsupported filling") >= 0 ||
       StringFind(_msg, "unsupported mode") >= 0 ||
       StringFind(_msg, "invalid stops") >= 0 ||
       StringFind(_msg, "échec") >= 0 ||
       StringFind(_msg, "erreur ouverture trade") >= 0) {
        Print("🔇 Notification filtrée (non envoyée): ", message);
        return;
    }
    
    // Vérification des permissions de notification
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        Print("❌ ERREUR: Trading non autorisé dans le terminal!");
        return;
    }
    
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
        Print("❌ ERREUR: Trading non autorisé pour les EAs!");
        return;
    }
    
    // Envoi de la notification
    bool result = ::SendNotification(message);
    
    if(result) {
        Print("✅ NOTIFICATION ENVOYÉE AVEC SUCCÈS");
    } else {
        Print("❌ ÉCHEC D'ENVOI DE NOTIFICATION - Erreur: ", GetLastError());
    }

    if(StringLen(InpWebhookURL) > 0) {
        Print("🔗 Webhook notification: ", message);
    }
}

//+------------------------------------------------------------------+
//| Fonction d'alerte sonore                                         |
//+------------------------------------------------------------------+
void PlayAlert(string alert_type)
{
    if(!InpPlaySounds) return;
    
    string sound_file = "";
    
    if(alert_type == "SPIKE") {
        sound_file = "alert.wav";
    }
    else if(alert_type == "TRADE_OPEN") {
        sound_file = "trade_open.wav";
    }
    else if(alert_type == "TRADE_CLOSE") {
        sound_file = "trade_close.wav";
    }
    else if(alert_type == "PROFIT") {
        sound_file = "profit.wav";
    }
    else if(alert_type == "LOSS") {
        sound_file = "loss.wav";
    }
    else {
        sound_file = InpSoundFile;
    }
    
    PlaySound(sound_file);
    Print("🔊 Alerte sonore: ", alert_type);
}

//+------------------------------------------------------------------+
//| Fonction de calcul du profit total                               |
//+------------------------------------------------------------------+
double GetTotalProfit()
{
    double current_profit = 0;
    for(int i = 0; i < InpMaxTrades; i++) {
        if(active_trades[i].ticket == 0) continue;
        if(PositionSelectByTicket(active_trades[i].ticket)) {
            current_profit += PositionGetDouble(POSITION_PROFIT);
        }
    }
    return current_profit;
}

//+------------------------------------------------------------------+
//| Calcul du profit total (historique + actuel)                    |
//+------------------------------------------------------------------+
double GetTotalNetProfit()
{
    return total_profit - total_loss + GetTotalProfit();
}

//+------------------------------------------------------------------+
//| Fonction d'affichage des informations                           |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_CHART_CHANGE) {
        if(InpShowDashboard) {
            DisplayPerformanceDashboard();
        } else {
            string info = "SpikeHunter EA - Trades actifs: " + IntegerToString(trade_count) +
                         " | Profit actuel: " + DoubleToString(GetTotalProfit(), 2) +
                         " | Profit total: " + DoubleToString(GetTotalNetProfit(), 2) +
                         " | Consecutive Losses: " + IntegerToString(consecutive_losses) +
                         " | Lot actuel: " + DoubleToString(current_lot_size, 2);
            Comment(info);
        }
    }
}

//+------------------------------------------------------------------+
//| Affichage du panneau de performance amélioré                    |
//+------------------------------------------------------------------+
void DisplayPerformanceDashboard()
{
    string dashboard = "";
    
    //--- En-tête avec informations de statut
    dashboard += "╔══════════════════════════════════════════════════════════════╗\n";
    dashboard += "║                    🚀 SPIKE HUNTER EA v2.0 🚀               ║\n";
    dashboard += "╠══════════════════════════════════════════════════════════════╣\n";
    
    string status = InpEnableTrading ? "🟢 ACTIF" : "🔴 INACTIF";
    string trading_mode = InpUseSimpleMode ? "SIMPLE" : "AVANCÉ";
    dashboard += "║ Statut: " + status + " | Mode: " + trading_mode + "                                    ║\n";
    dashboard += "║ Symbol: " + _Symbol + " | TF: " + EnumToString(InpTimeframe) + "                                    ║\n";
    
    //--- Indicateurs de performance en temps réel
    double current_profit = GetTotalProfit();
    double net_profit = GetTotalNetProfit();
    string profit_status = (current_profit > 0) ? "🟢" : (current_profit < 0) ? "🔴" : "⚪";
    string net_profit_status = (net_profit > 0) ? "🟢" : (net_profit < 0) ? "🔴" : "⚪";
    
    dashboard += "║ Profit actuel: " + profit_status + " " + DoubleToString(current_profit, 2) + " $ | Net: " + net_profit_status + " " + DoubleToString(net_profit, 2) + " $                                    ║\n";
    dashboard += "╠══════════════════════════════════════════════════════════════╣\n";
    
    //--- Section Trading
    dashboard += "║ 📊 TRADING:                                               ║\n";
    dashboard += "║   Trades actifs: " + IntegerToString(trade_count) + "/" + IntegerToString(InpMaxTrades) + "                                    ║\n";
    dashboard += "║   Lot actuel: " + DoubleToString(current_lot_size, 2) + "                                    ║\n";
    dashboard += "║   Martingale: " + (InpUseMartingale ? "🟢 OUI" : "🔴 NON") + " | Multi: " + DoubleToString(InpMartingaleMultiplier, 1) + "                                    ║\n";
    dashboard += "║   Pertes consécutives: " + IntegerToString(consecutive_losses) + "/" + IntegerToString(InpMaxConsecutiveLosses) + "                                    ║\n";
    dashboard += "╠══════════════════════════════════════════════════════════════╣\n";
    
    //--- Section Performance
    dashboard += "║ 📈 PERFORMANCE:                                           ║\n";
    dashboard += "║   Total Trades: " + IntegerToString(total_trades) + "                                    ║\n";
    dashboard += "║   Gagnants: " + IntegerToString(winning_trades) + " | Perdants: " + IntegerToString(losing_trades) + "                                    ║\n";
    dashboard += "║   Taux de réussite: " + DoubleToString(win_rate, 1) + "%                                    ║\n";
    dashboard += "║   Profit max: " + DoubleToString(max_profit, 2) + " $ | Perte max: " + DoubleToString(max_loss, 2) + " $                                    ║\n";
    dashboard += "╠══════════════════════════════════════════════════════════════╣\n";
    
    //--- Section Compte
    dashboard += "║ 💳 COMPTE:                                                ║\n";
    dashboard += "║   Balance: " + DoubleToString(account_balance, 2) + " $                                    ║\n";
    dashboard += "║   Equity: " + DoubleToString(account_equity, 2) + " $                                    ║\n";
    dashboard += "║   Marge libre: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN_FREE), 2) + " $                                    ║\n";
    dashboard += "║   Marge utilisée: " + DoubleToString(AccountInfoDouble(ACCOUNT_MARGIN), 2) + " $                                    ║\n";
    dashboard += "╠══════════════════════════════════════════════════════════════╣\n";
    
    //--- Section Détection de Spikes
    dashboard += "║ 🔍 DÉTECTION SPIKES:                                      ║\n";
    dashboard += "║   Seuil: " + DoubleToString(InpSpikeThreshold, 3) + "% | Période: " + IntegerToString(InpSpikeDetectionPeriod) + "                                    ║\n";
    dashboard += "║   Mode simple: " + (InpUseSimpleMode ? "🟢 OUI" : "🔴 NON") + " | Proximité S/R: " + DoubleToString(InpSimpleSRProximityPct*100, 1) + "%                                    ║\n";
    dashboard += "║   Autoscan: " + (InpAutoScan ? "🟢 ACTIF" : "🔴 INACTIF") + " | Intervalle: " + IntegerToString(InpScanInterval/60) + "min                                    ║\n";
    dashboard += "║   Signaux envoyés: " + IntegerToString(autoscan_signals_sent) + "                                    ║\n";
    dashboard += "╠══════════════════════════════════════════════════════════════╣\n";
    
    //--- Section Prédictions
    dashboard += "║ 🔮 PRÉDICTIONS:                                           ║\n";
    dashboard += "║   Total: " + IntegerToString(total_predictions) + " | Réussies: " + IntegerToString(successful_predictions) + "                                    ║\n";
    double success_rate = (total_predictions > 0) ? (double)successful_predictions / total_predictions * 100 : 0;
    dashboard += "║   Taux de réussite: " + DoubleToString(success_rate, 1) + "%                                    ║\n";
    
    if(current_prediction.is_active) {
        string pred_direction = (current_prediction.predicted_direction > 0) ? "BOOM" : "CRASH";
        string pred_color = (current_prediction.predicted_direction > 0) ? "BLEUE" : "ROUGE";
        string pred_emoji = (current_prediction.predicted_direction > 0) ? "🚀" : "💥";
        int time_left = (int)(current_prediction.predicted_time - TimeCurrent());
        
        // Barre de progression améliorée
        string progress_bar = "";
        int progress = MathMax(0, MathMin(100, (int)((current_prediction.duration_seconds - time_left) * 100 / current_prediction.duration_seconds)));
        for(int i = 0; i < 20; i++) {
            if(i < progress / 5) {
                progress_bar += "█";
            } else {
                progress_bar += "░";
            }
        }
        
        dashboard += "║   " + pred_emoji + " Prédiction active: " + pred_direction + " (" + pred_color + ")                                    ║\n";
        dashboard += "║   Confiance: " + DoubleToString(current_prediction.confidence * 100, 0) + "% | Durée: " + IntegerToString(current_prediction.duration_seconds) + "s                                    ║\n";
        dashboard += "║   Temps restant: " + IntegerToString(time_left) + "s [" + progress_bar + "]                                    ║\n";
        
        if(time_left <= 10 && time_left > 0) {
            dashboard += "║   ⚠️  SPIKE IMMINENT! ⚠️                                    ║\n";
        }
    } else {
        dashboard += "║   Aucune prédiction active                                    ║\n";
    }
    dashboard += "╠══════════════════════════════════════════════════════════════╣\n";
    
    //--- Section Notifications
    dashboard += "║ 🔔 NOTIFICATIONS:                                         ║\n";
    dashboard += "║   WhatsApp: " + (InpSendToWhatsApp ? "🟢 OUI" : "🔴 NON") + " | SMS: " + (InpSendToSMS ? "🟢 OUI" : "🔴 NON") + "                                    ║\n";
    dashboard += "║   Sons: " + (InpPlaySounds ? "🟢 OUI" : "🔴 NON") + " | Dashboard: " + (InpShowDashboard ? "🟢 OUI" : "🔴 NON") + "                                    ║\n";
    if(StringLen(last_alert) > 0) {
        string short_alert = last_alert;
        if(StringLen(short_alert) > 50) {
            short_alert = StringSubstr(short_alert, 0, 47) + "...";
        }
        dashboard += "║   Dernière alerte: " + short_alert + "                                    ║\n";
    }
    dashboard += "╠══════════════════════════════════════════════════════════════╣\n";
    
    //--- Pied de page avec timestamp
    dashboard += "║ 🕐 " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "                                    ║\n";
    dashboard += "╚═══════════════════════════════════════════════════════════════╝";
    
    Comment(dashboard);
}

//+------------------------------------------------------------------+
//| Mise à jour de l'historique des prix                             |
//+------------------------------------------------------------------+
void UpdatePriceHistory()
{
    if(TimeCurrent() - last_history_update < 1) return;
    last_history_update = TimeCurrent();
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    price_history[history_index] = current_price;
    history_index = (history_index + 1) % 100;
    
    if(current_price > last_high || last_high == 0) {
        last_high = current_price;
        last_high_time = TimeCurrent();
    }
    if(current_price < last_low || last_low == 0) {
        last_low = current_price;
        last_low_time = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Détection des supports et résistances                             |
//+------------------------------------------------------------------+
void DetectSupportResistance()
{
    if(TimeCurrent() - last_level_detection < 5) return;
    last_level_detection = TimeCurrent();
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    for(int i = 0; i < 50; i++) {
        int idx = (history_index - i + 100) % 100;
        if(price_history[idx] <= 0) continue;
        
        double test_price = price_history[idx];
        int touch_count = 0;
        
        for(int j = 0; j < 50; j++) {
            int check_idx = (history_index - j + 100) % 100;
            if(price_history[check_idx] <= 0) continue;
            
            double price_diff = MathAbs(price_history[check_idx] - test_price) / test_price;
            if(price_diff <= InpLevelTolerance) {
                touch_count++;
            }
        }
        
        if(touch_count >= InpMinTouches) {
            bool is_support = (test_price < current_price);
            
            if(is_support) {
                int existing_idx = FindExistingSupport(test_price);
                if(existing_idx >= 0) {
                    support_levels[existing_idx].touch_count++;
                    support_levels[existing_idx].last_touch = TimeCurrent();
                    if(support_levels[existing_idx].touch_count >= InpMinTouches) {
                        support_levels[existing_idx].is_confirmed = true;
                    }
                } else if(support_count < 20) {
                    support_levels[support_count].level = test_price;
                    support_levels[support_count].strength = touch_count;
                    support_levels[support_count].touch_count = touch_count;
                    support_levels[support_count].last_touch = TimeCurrent();
                    support_levels[support_count].is_support = true;
                    support_levels[support_count].is_confirmed = (touch_count >= InpMinTouches);
                    support_levels[support_count].name = "Support_" + IntegerToString(support_count);
                    support_count++;
                    
                    if(InpShowLevels) {
                        DrawSupportLevel(support_count - 1);
                    }
                }
            } else {
                int existing_idx = FindExistingResistance(test_price);
                if(existing_idx >= 0) {
                    resistance_levels[existing_idx].touch_count++;
                    resistance_levels[existing_idx].last_touch = TimeCurrent();
                    if(resistance_levels[existing_idx].touch_count >= InpMinTouches) {
                        resistance_levels[existing_idx].is_confirmed = true;
                    }
                } else if(resistance_count < 20) {
                    resistance_levels[resistance_count].level = test_price;
                    resistance_levels[resistance_count].strength = touch_count;
                    resistance_levels[resistance_count].touch_count = touch_count;
                    resistance_levels[resistance_count].last_touch = TimeCurrent();
                    resistance_levels[resistance_count].is_support = false;
                    resistance_levels[resistance_count].is_confirmed = (touch_count >= InpMinTouches);
                    resistance_levels[resistance_count].name = "Resistance_" + IntegerToString(resistance_count);
                    resistance_count++;
                    
                    if(InpShowLevels) {
                        DrawResistanceLevel(resistance_count - 1);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Mise à jour des données Streamlit                                |
//+------------------------------------------------------------------+
void UpdateStreamlitData()
{
    if(TimeCurrent() - last_streamlit_check < InpStreamlitInterval) return;
    last_streamlit_check = TimeCurrent();
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    string timeframes[] = {"M1", "M5", "M15", "M30", "H1"};
    for(int tf = 0; tf < ArraySize(timeframes); tf++) {
        double tf_support = current_price * (0.995 + tf * 0.001);
        double tf_resistance = current_price * (1.005 - tf * 0.001);
        
        AddStreamlitLevel(tf_support, true, timeframes[tf]);
        AddStreamlitLevel(tf_resistance, false, timeframes[tf]);
    }
    
    Print("📊 DONNÉES STREAMLIT MISE À JOUR: ", ArraySize(timeframes), " timeframes analysés");
}

//+------------------------------------------------------------------+
//| Ajouter un niveau depuis Streamlit                               |
//+------------------------------------------------------------------+
void AddStreamlitLevel(double level, bool is_support, string timeframe)
{
    if(is_support) {
        int existing_idx = FindExistingSupport(level);
        if(existing_idx >= 0) {
            support_levels[existing_idx].touch_count++;
            support_levels[existing_idx].last_touch = TimeCurrent();
            if(support_levels[existing_idx].touch_count >= InpMinTouches) {
                support_levels[existing_idx].is_confirmed = true;
            }
        } else if(support_count < 20) {
            support_levels[support_count].level = level;
            support_levels[support_count].strength = 3;
            support_levels[support_count].touch_count = 3;
            support_levels[support_count].last_touch = TimeCurrent();
            support_levels[support_count].is_support = true;
            support_levels[support_count].is_confirmed = true;
            support_levels[support_count].name = "Streamlit_S_" + timeframe + "_" + IntegerToString(support_count);
            support_count++;
            
            if(InpShowLevels) {
                DrawSupportLevel(support_count - 1);
            }
            
            Print("🟢 SUPPORT STREAMLIT AJOUTÉ: ", DoubleToString(level, _Digits), " - Timeframe: ", timeframe);
        }
    } else {
        int existing_idx = FindExistingResistance(level);
        if(existing_idx >= 0) {
            resistance_levels[existing_idx].touch_count++;
            resistance_levels[existing_idx].last_touch = TimeCurrent();
            if(resistance_levels[existing_idx].touch_count >= InpMinTouches) {
                resistance_levels[existing_idx].is_confirmed = true;
            }
        } else if(resistance_count < 20) {
            resistance_levels[resistance_count].level = level;
            resistance_levels[resistance_count].strength = 3;
            resistance_levels[resistance_count].touch_count = 3;
            resistance_levels[resistance_count].last_touch = TimeCurrent();
            resistance_levels[resistance_count].is_support = false;
            resistance_levels[resistance_count].is_confirmed = true;
            resistance_levels[resistance_count].name = "Streamlit_R_" + timeframe + "_" + IntegerToString(resistance_count);
            resistance_count++;
            
            if(InpShowLevels) {
                DrawResistanceLevel(resistance_count - 1);
            }
            
            Print("🔴 RÉSISTANCE STREAMLIT AJOUTÉE: ", DoubleToString(level, _Digits), " - Timeframe: ", timeframe);
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier la proximité d'un support                               |
//+------------------------------------------------------------------+
double CheckSupportProximity(double current_price)
{
    double max_proximity = 0;
    
    for(int i = 0; i < support_count; i++) {
        if(!support_levels[i].is_confirmed) continue;
        
        double distance = MathAbs(current_price - support_levels[i].level) / support_levels[i].level;
        double proximity = 1.0 - (distance / InpLevelTolerance);
        
        if(proximity > max_proximity) {
            max_proximity = proximity;
        }
    }
    
    return max_proximity;
}

//+------------------------------------------------------------------+
//| Vérifier la proximité d'une résistance                           |
//+------------------------------------------------------------------+
double CheckResistanceProximity(double current_price)
{
    double max_proximity = 0;
    
    for(int i = 0; i < resistance_count; i++) {
        if(!resistance_levels[i].is_confirmed) continue;
        
        double distance = MathAbs(current_price - resistance_levels[i].level) / resistance_levels[i].level;
        double proximity = 1.0 - (distance / InpLevelTolerance);
        
        if(proximity > max_proximity) {
            max_proximity = proximity;
        }
    }
    
    return max_proximity;
}

//+------------------------------------------------------------------+
//| Trouver un support existant                                       |
//+------------------------------------------------------------------+
int FindExistingSupport(double price)
{
    for(int i = 0; i < support_count; i++) {
        double distance = MathAbs(support_levels[i].level - price) / price;
        if(distance <= InpLevelTolerance) {
            return i;
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Trouver une résistance existante                                 |
//+------------------------------------------------------------------+
int FindExistingResistance(double price)
{
    for(int i = 0; i < resistance_count; i++) {
        double distance = MathAbs(resistance_levels[i].level - price) / price;
        if(distance <= InpLevelTolerance) {
            return i;
        }
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Dessiner un niveau de support                                    |
//+------------------------------------------------------------------+
void DrawSupportLevel(int index)
{
    if(index >= support_count) return;
    
    // Ne dessiner que les supports confirmés proches du prix actuel
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double level = support_levels[index].level;
    double distance = MathAbs(current_price - level) / current_price;
    
    // Seuil de proximité : 2% du prix actuel
    if(distance > 0.02 || !support_levels[index].is_confirmed) return;
    
    string name = "Support_" + IntegerToString(index);
    ObjectDelete(0, name);
    
    if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, level)) {
        ObjectSetInteger(0, name, OBJPROP_COLOR, InpSupportColor);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        
        string text_name = name + "_Text";
        ObjectDelete(0, text_name);
        if(ObjectCreate(0, text_name, OBJ_TEXT, 0, TimeCurrent(), level)) {
            ObjectSetString(0, text_name, OBJPROP_TEXT, "S" + IntegerToString(support_levels[index].touch_count));
            ObjectSetInteger(0, text_name, OBJPROP_COLOR, InpSupportColor);
            ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
        }
    }
}

//+------------------------------------------------------------------+
//| Dessiner un niveau de résistance                                 |
//+------------------------------------------------------------------+
void DrawResistanceLevel(int index)
{
    if(index >= resistance_count) return;
    
    // Ne dessiner que les résistances confirmées proches du prix actuel
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double level = resistance_levels[index].level;
    double distance = MathAbs(current_price - level) / current_price;
    
    // Seuil de proximité : 2% du prix actuel
    if(distance > 0.02 || !resistance_levels[index].is_confirmed) return;
    
    string name = "Resistance_" + IntegerToString(index);
    ObjectDelete(0, name);
    
    if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, level)) {
        ObjectSetInteger(0, name, OBJPROP_COLOR, InpResistanceColor);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        
        string text_name = name + "_Text";
        ObjectDelete(0, text_name);
        if(ObjectCreate(0, text_name, OBJ_TEXT, 0, TimeCurrent(), level)) {
            ObjectSetString(0, text_name, OBJPROP_TEXT, "R" + IntegerToString(resistance_levels[index].touch_count));
            ObjectSetInteger(0, text_name, OBJPROP_COLOR, InpResistanceColor);
            ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, text_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, text_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, text_name, OBJPROP_HIDDEN, true);
        }
    }
}

//+------------------------------------------------------------------+
//| Supprimer la flèche de prédiction                                |
//+------------------------------------------------------------------+
void RemovePredictionArrow()
{
    ObjectsDeleteAll(0, "SpikePrediction_");
    ObjectsDeleteAll(0, "SpikeText_");
}

//+------------------------------------------------------------------+
//| Vérifier les trades programmés                                   |
//+------------------------------------------------------------------+
void CheckScheduledTrades()
{
    // Logique pour vérifier les trades programmés
}

//+------------------------------------------------------------------+
//| Vérifier les limites de perte                                    |
//+------------------------------------------------------------------+
void CheckTradeLossLimits()
{
    // Logique pour vérifier les limites de perte
}

//+------------------------------------------------------------------+
//| Reset quotidien des pertes                                      |
//+------------------------------------------------------------------+
void ResetDailyLossIfNeeded()
{
    datetime current_time = TimeCurrent();
    MqlDateTime current_dt, last_dt;
    TimeToStruct(current_time, current_dt);
    TimeToStruct(last_daily_reset, last_dt);
    
    // Reset à minuit
    if(current_dt.day != last_dt.day || current_dt.mon != last_dt.mon || current_dt.year != last_dt.year) {
        daily_loss = 0;
        last_daily_reset = current_time;
        Print("🔄 Reset quotidien des pertes - Nouveau jour");
    }
}

//+------------------------------------------------------------------+
//| Ouverture de trade avec gestion du risque                       |
//+------------------------------------------------------------------+
bool OpenTradeWithRiskManagement(int direction)
{
    //--- Calculer la taille du lot basée sur le risque
    double lot_size = CalculateLotSize();
    
    //--- Vérifier que la perte potentielle ne dépasse pas le maximum autorisé
    double potential_loss = lot_size * InpStopLoss * _Point * 100000; // Approximation en USD
    if(potential_loss > InpMaxLossPerTrade) {
        Print("❌ Perte potentielle trop élevée: $", potential_loss, " > $", InpMaxLossPerTrade);
        return false;
    }
    
    //--- Ouvrir le trade avec la taille calculée
    return OpenTradeWithLotSize(direction, lot_size);
}


//+------------------------------------------------------------------+
//| Ouverture de trade avec taille de lot spécifique                |
//+------------------------------------------------------------------+
bool OpenTradeWithLotSize(int direction, double lot_size)
{
    // PROTECTION CONTRE LES ORDRES MULTIPLES
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(direction > 0) current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    if(!CanOpenNewTradeForSymbol(_Symbol, direction, current_price)) {
        return false;
    }
    
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot_size;
    request.type = (ENUM_ORDER_TYPE)((direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
    request.magic = InpMagicNumber;
    request.deviation = 10;
    request.type_filling = ORDER_FILLING_FOK;
    request.comment = "SpikeHunterRisk";
    request.price = SymbolInfoDouble(_Symbol, (direction > 0) ? SYMBOL_ASK : SYMBOL_BID);
    
    //--- Calculer SL et TP
    if(InpStopLoss > 0) {
        request.sl = request.price + ((direction > 0) ? -InpStopLoss : InpStopLoss) * _Point;
    }
    if(InpTakeProfit > 0) {
        request.tp = request.price + ((direction > 0) ? InpTakeProfit : -InpTakeProfit) * _Point;
    }
    
    if(OrderSend(request, result)) {
        if(result.retcode == TRADE_RETCODE_DONE) {
            AddActiveTrade(result.order, direction, request.price, request.volume);
            UpdateSymbolQuota(_Symbol); // Mettre à jour le quota du symbole
            string direction_str = (direction > 0) ? "BUY" : "SELL";
            Print("TRADE OUVERT: ", direction_str, " ", _Symbol, " @ ", DoubleToString(request.price, _Digits), 
                  ", Lot: ", request.volume, ", SL: ", DoubleToString(request.sl, _Digits), 
                  ", TP: ", DoubleToString(request.tp, _Digits));
            
            if(InpSendNotifications) {
                string notification = StringFormat("Trade ouvert: %s %s @ %s | Lot: %.2f | SL: %d pts | TP: %d pts | Capital: $%.0f", 
                                                 direction_str, _Symbol, DoubleToString(request.price, _Digits), 
                                                 request.volume, InpStopLoss, InpTakeProfit, account_balance);
                SendMyNotification(notification);
            }
            return true;
        } else {
            Print("ERREUR ouverture trade: ", result.retcode, " - ", result.comment);
        }
    } else {
        Print("OrderSend() a échoué. Erreur: ", GetLastError());
    }
    return false;
}

//+------------------------------------------------------------------+
//| Calcule des SL/TP conformes au symbole                           |
//+------------------------------------------------------------------+
void CalculateValidStops(int direction, double open_price, int sl_pts, int tp_pts,
                         double &sl_price, double &tp_price)
{
    sl_price = 0.0; tp_price = 0.0;
    double stops_level_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    double freeze_level_points = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
    double min_distance = MathMax(stops_level_points, freeze_level_points);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    
    // Distance souhaitée
    double sl_dist = sl_pts * _Point;
    double tp_dist = tp_pts * _Point;
    if(sl_dist > 0) sl_dist = MathMax(sl_dist, min_distance);
    if(tp_dist > 0) tp_dist = MathMax(tp_dist, min_distance);
    
    // Aligner sur le tick size
    if(direction > 0) {
        if(sl_dist > 0) sl_price = AlignToTick(open_price - sl_dist);
        if(tp_dist > 0) tp_price = AlignToTick(open_price + tp_dist);
    } else {
        if(sl_dist > 0) sl_price = AlignToTick(open_price + sl_dist);
        if(tp_dist > 0) tp_price = AlignToTick(open_price - tp_dist);
    }
}

//+------------------------------------------------------------------+
//| Applique SL/TP à la position courante du symbole                 |
//+------------------------------------------------------------------+
bool ApplySLTP(string symbol, double sl_price, double tp_price)
{
    if(!PositionSelect(symbol)) return false;
    long type = (long)PositionGetInteger(POSITION_TYPE);
    double price_open = PositionGetDouble(POSITION_PRICE_OPEN);
    
    MqlTradeRequest mod; MqlTradeResult res; ZeroMemory(mod); ZeroMemory(res);
    mod.action = TRADE_ACTION_SLTP; mod.symbol = symbol; mod.sl = sl_price; mod.tp = tp_price;
    mod.position = (ulong)PositionGetInteger(POSITION_TICKET);
    bool ok = OrderSend(mod, res);
    if(!ok || res.retcode != TRADE_RETCODE_DONE) {
        Print("❌ ÉCHEC ApplySLTP: ", res.retcode, " - ", res.comment);
        return false;
    }
    Print("✅ SL/TP appliqués: SL=", DoubleToString(sl_price, _Digits), " TP=", DoubleToString(tp_price, _Digits));
    return true;
}

//+------------------------------------------------------------------+
//| Retourne un type_filling supporté par le symbole                 |
//+------------------------------------------------------------------+
int GetSupportedFilling()
{
    int mode = (int)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
    // Valeurs usuelles: 0=FOK, 1=IOC, 2=RETURN (selon broker)
    if(mode == 1) return ORDER_FILLING_IOC;
    if(mode == 2) return ORDER_FILLING_RETURN;
    return ORDER_FILLING_FOK; // défaut sûr
}

//+------------------------------------------------------------------+
//| Ouverture de trade intelligente et robuste                       |
//+------------------------------------------------------------------+
bool OpenTradeSimple(int direction)
{
    // Enforcer: BOOM only BUY, CRASH only SELL
    if(!IsDirectionAllowedForSymbol(direction)) {
        Print("⏸ Direction non autorisée pour ", _Symbol, " (BOOM=>BUY, CRASH=>SELL). Trade ignoré.");
        return false;
    }
    
    // PROTECTION CONTRE LES ORDRES MULTIPLES
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(direction > 0) current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    if(!CanOpenNewTradeForSymbol(_Symbol, direction, current_price)) {
        return false;
    }

    // Spread filter
    double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double spread_points = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))/pt;
    if((int)spread_points > InpMaxSpreadPoints) {
        Print("⏸ Spread trop élevé (", (int)spread_points, ">", InpMaxSpreadPoints, ") - trade annulé");
        return false;
    }

    // Empêcher ordres inverses simultanés
    if(!CanPlaceDirectionForSymbol(direction)) return false;
    Print("🔧 TENTATIVE D'OUVERTURE DE TRADE - Direction: ", (direction > 0) ? "BUY" : "SELL");
    
    //--- Vérifications de sécurité renforcées
    if(trade_count >= InpMaxTrades) {
        Print("❌ Nombre maximum de trades atteint: ", trade_count);
        return false;
    }
    
    if(account_balance < InpMinCapital) {
        Print("❌ Capital insuffisant: $", account_balance, " < $", InpMinCapital);
        return false;
    }
    
    //--- Vérification des permissions de trading
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        Print("❌ Trading non autorisé dans le terminal");
        return false;
    }
    
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
        Print("❌ Trading non autorisé pour les EAs");
        return false;
    }
    
    if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
        Print("❌ Trading non autorisé sur ce compte");
        return false;
    }
    
    //--- Calcul intelligent de la taille de lot avec multiplicateur d'échec
    double base_lot_size = CalculateLotSize();
    double lot_size = CalculateLotWithFailMultiplier(_Symbol, base_lot_size);
    
    //--- Vérification de la marge disponible
    double margin_required = lot_size * SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
    double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    
    if(margin_required > free_margin * 0.8) {
        Print("❌ Marge insuffisante: ", DoubleToString(margin_required, 2), " > ", DoubleToString(free_margin * 0.8, 2));
        return false;
    }
    
    Print("💰 LOT CALCULÉ: ", DoubleToString(lot_size, 2), " | Marge requise: ", DoubleToString(margin_required, 2));
    
    //--- Préparation de la requête avec SL/TP intelligents
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    // Anti-duplication: ne pas ouvrir si une position EA existe déjà au même prix (± tolérance)
    double tolerance = InpDuplicatePriceTolerancePoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    for(int i=PositionsTotal()-1; i>=0; i--){
        ulong t = PositionGetTicket(i);
        if(!PositionSelectByTicket(t)) continue;
        if(PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
        if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
        double open_p = PositionGetDouble(POSITION_PRICE_OPEN);
        if(MathAbs(open_p - request.price) <= tolerance){
            Print("⏸ Anti-duplication: position existante proche du même prix (", DoubleToString(open_p,_Digits), ")");
            return false;
        }
    }
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot_size;
    request.type = (ENUM_ORDER_TYPE)((direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
    request.magic = InpMagicNumber;
    request.deviation = 50; // Déviation réduite pour plus de précision
    request.type_filling = (ENUM_ORDER_TYPE_FILLING)GetSupportedFilling();
    request.comment = "SpikeHunter_" + IntegerToString((int)GetTickCount());
    
    //--- Prix d'ouverture
    if(direction > 0) {
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    } else {
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    }
    
    //--- Calcul intelligent des SL/TP
    if(InpStopLoss > 0) {
        double sl_distance = InpStopLoss * _Point;
        request.sl = (direction > 0) ? request.price - sl_distance : request.price + sl_distance;
    }
    
    if(InpTakeProfit > 0) {
        double tp_distance = InpTakeProfit * _Point;
        request.tp = (direction > 0) ? request.price + tp_distance : request.price - tp_distance;
    }
    
    //--- Vérification de la validité des niveaux
    if(!ValidateStopLevels(request.sl, request.tp, request.price, direction)) {
        Print("⚠️ Niveaux SL/TP invalides - Ouverture sans protection");
        request.sl = 0;
        request.tp = 0;
    }
    
    Print("📊 DÉTAILS TRADE: Prix=", DoubleToString(request.price, _Digits), 
          " | SL=", DoubleToString(request.sl, _Digits), 
          " | TP=", DoubleToString(request.tp, _Digits));
    
    //--- Envoi de l'ordre avec retry en cas d'échec
    int max_retries = 3;
    for(int retry = 0; retry < max_retries; retry++) {
        if(OrderSend(request, result)) {
            if(result.retcode == TRADE_RETCODE_DONE) {
                // Ajout du trade à la liste
                AddActiveTrade(result.order, direction, request.price, request.volume);
                UpdateSymbolQuota(_Symbol); // Mettre à jour le quota du symbole
                
                string direction_str = (direction > 0) ? "BUY" : "SELL";
                Print("✅ TRADE OUVERT: ", direction_str, " ", _Symbol, 
                      " @ ", DoubleToString(request.price, _Digits), 
                      " | Lot: ", DoubleToString(lot_size, 2),
                      " | SL: ", DoubleToString(request.sl, _Digits),
                      " | TP: ", DoubleToString(request.tp, _Digits));
                
                // Notification
                if(InpSendNotifications) {
                    string notification = StringFormat("✅ Trade ouvert: %s %s @ %s | Lot: %.2f | SL: %d pts | TP: %d pts", 
                                                     direction_str, _Symbol, DoubleToString(request.price, _Digits), 
                                                     lot_size, InpStopLoss, InpTakeProfit);
                    SendMyNotification(notification);
                }
                
                // Réinitialiser les échecs après succès
                ResetRequestFails(_Symbol);
                return true;
            } else {
                Print("❌ ERREUR ouverture trade (tentative ", retry + 1, "): ", result.retcode, " - ", result.comment);
                
                // Enregistrer l'échec pour augmenter le lot la prochaine fois
                RecordRequestFail(_Symbol);
                
                // Ajustements pour les tentatives suivantes
                if(retry < max_retries - 1) {
                    request.deviation += 20; // Augmenter la déviation
                    
                    // Recalculer le lot avec le nouveau multiplicateur
                    double new_lot = CalculateLotWithFailMultiplier(_Symbol, base_lot_size);
                    if(new_lot != request.volume) {
                        request.volume = new_lot;
                        Print("🔄 LOT RECALCULÉ: ", DoubleToString(new_lot, 2), " (tentative ", retry + 2, ")");
                    }
                    
                    Sleep(100); // Attendre un peu
                }
            }
        } else {
            Print("❌ OrderSend() échoué (tentative ", retry + 1, "). Erreur: ", GetLastError());
            if(retry < max_retries - 1) {
                Sleep(200); // Attendre plus longtemps
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Validation des niveaux de stop loss et take profit              |
//+------------------------------------------------------------------+
bool ValidateStopLevels(double sl, double tp, double price, int direction)
{
    if(sl == 0 && tp == 0) return true; // Pas de SL/TP
    
    double stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
    double freeze_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * _Point;
    double min_distance = MathMax(stops_level, freeze_level);
    
    if(sl > 0) {
        double sl_distance = MathAbs(price - sl);
        if(sl_distance < min_distance) {
            Print("❌ SL trop proche: ", DoubleToString(sl_distance, _Digits), " < ", DoubleToString(min_distance, _Digits));
            return false;
        }
    }
    
    if(tp > 0) {
        double tp_distance = MathAbs(price - tp);
        if(tp_distance < min_distance) {
            Print("❌ TP trop proche: ", DoubleToString(tp_distance, _Digits), " < ", DoubleToString(min_distance, _Digits));
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Test de la fonction de trading (pour debug)                     |
//+------------------------------------------------------------------+
void TestTradingFunction() // (désactivée - conservée pour debug manuel)
{
    static int test_count = 0;
    test_count++;
    
    Print("🧪 TEST TRADING #", test_count, " - Vérification des paramètres...");
    Print("   - InpAutoTradeOnSpike: ", InpAutoTradeOnSpike);
    Print("   - InpEnableTrading: ", InpEnableTrading);
    Print("   - trade_count: ", trade_count, "/", InpMaxTrades);
    Print("   - account_balance: $", account_balance);
    Print("   - InpMinCapital: $", InpMinCapital);
    
    // Vérification des permissions de trading
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        Print("❌ ERREUR CRITIQUE: Trading non autorisé dans le terminal!");
    } else {
        Print("✅ Trading autorisé dans le terminal");
    }
    
    if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
        Print("❌ ERREUR CRITIQUE: Trading non autorisé pour les EAs!");
    } else {
        Print("✅ Trading autorisé pour les EAs");
    }
    
    if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
        Print("❌ ERREUR CRITIQUE: Trading non autorisé sur ce compte!");
    } else {
        Print("✅ Trading autorisé sur ce compte");
    }
    
    // Test de viabilité
    if(IsTradeViable()) {
        Print("✅ TEST: Trade viable - La fonction devrait pouvoir ouvrir un trade");
    } else {
        Print("❌ TEST: Trade non viable - Vérifiez les paramètres");
    }
    
    // Test de détection de spike
    if(spike_detected) {
        Print("🚀 TEST: Spike détecté - Direction: ", spike_direction);
    } else {
        Print("⏳ TEST: Aucun spike détecté actuellement");
    }
    
    // Test de trading forcé (toutes les 30 secondes si aucun trade)
    static datetime last_force_test = 0;
    if(TimeCurrent() - last_force_test > 30) { // 30 secondes
        if(trade_count == 0) { // Seulement si aucun trade ouvert
            Print("🔥 FORÇAGE TRADE: Aucun trade depuis 30s - Ouverture forcée...");
            
            // Forcer un spike pour déclencher le trading
            spike_detected = true;
            spike_direction = 1; // BUY forcé
            Print("🚀 SPIKE FORCÉ: Direction BUY");
            
            // Traitement immédiat
            ProcessSpikeSignal();
            
            last_force_test = TimeCurrent();
        }
    }
    
    // (notifications de test désactivées)
    
    //--- TRADING FORCÉ SI AUCUN TRADE DEPUIS 2 MINUTES
    static datetime last_forced_trade = 0;
    if(TimeCurrent() - last_forced_trade > 120) { // 2 minutes
        if(trade_count == 0) {
            Print("🔥 TRADING FORCÉ: Aucun trade depuis 2 minutes - Ouverture forcée...");
            ForceOpenTrade();
            last_forced_trade = TimeCurrent();
        }
    }
}

//+------------------------------------------------------------------+
//| Ouverture forcée de trade (bypass des vérifications)            |
//+------------------------------------------------------------------+
void ForceOpenTrade()
{
    Print("🔥 FORÇAGE TRADE: Bypass des vérifications - Ouverture immédiate...");
    
    // Vérifications minimales seulement
    if(trade_count >= InpMaxTrades) {
        Print("❌ FORÇAGE ÉCHOUÉ: Nombre maximum de trades atteint");
        return;
    }
    
    if(account_balance < 10) { // Capital minimum très bas
        Print("❌ FORÇAGE ÉCHOUÉ: Capital insuffisant");
        return;
    }
    
    // Calcul de lot minimal
    double lot_size = 0.01; // Lot minimum
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(lot_size, min_lot);
    lot_size = MathMin(lot_size, max_lot);
    lot_size = MathRound(lot_size / lot_step) * lot_step;
    
    // Direction aléatoire
    int direction = (MathRand() % 2 == 0) ? 1 : -1;
    string direction_str = (direction > 0) ? "BUY" : "SELL";
    
    Print("🎯 FORÇAGE: Direction ", direction_str, " | Lot: ", DoubleToString(lot_size, 2));
    
    // Ouverture du trade
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot_size;
    request.type = (ENUM_ORDER_TYPE)((direction > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
    request.magic = InpMagicNumber;
    request.deviation = 150; // Déviation plus large
    request.type_filling = (ENUM_ORDER_TYPE_FILLING)GetSupportedFilling(); // compatible symbole
    request.comment = "FORCED_" + IntegerToString((int)GetTickCount());
    
    // Prix d'ouverture
    if(direction > 0) {
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    } else {
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    }
    
    // Pas de SL/TP: l'utilisateur les gèrera manuellement
    
    // Envoi de l'ordre
    if(OrderSend(request, result)) {
        if(result.retcode == TRADE_RETCODE_DONE) {
            AddActiveTrade(result.order, direction, request.price, request.volume);
            Print("✅ TRADE FORCÉ OUVERT: ", direction_str, " ", _Symbol, 
                  " @ ", DoubleToString(request.price, _Digits), 
                  " | Lot: ", DoubleToString(lot_size, 2));
            
            if(InpSendNotifications) {
                SendMyNotification("Trade forcé ouvert: " + direction_str + " " + _Symbol);
            }
        } else {
            Print("❌ ÉCHEC TRADE FORCÉ: ", result.retcode, " - ", result.comment);
            if((int)result.retcode == (int)TRADE_RETCODE_INVALID_STOPS || (int)result.retcode == (int)TRADE_RETCODE_INVALID_PRICE || (int)result.retcode == (int)TRADE_RETCODE_INVALID) {
                // Fallback sans SL/TP
                MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
                rq.action = TRADE_ACTION_DEAL; rq.symbol = _Symbol; rq.volume = request.volume;
                rq.type = request.type; rq.magic = InpMagicNumber; rq.deviation = request.deviation;
                rq.type_filling = (ENUM_ORDER_TYPE_FILLING)GetSupportedFilling(); rq.comment = "FORCED_Fallback";
                rq.price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
                if(OrderSend(rq, rs) && rs.retcode == TRADE_RETCODE_DONE) {
                    AddActiveTrade(rs.order, direction, rq.price, rq.volume);
                }
            }
        }
    } else {
        Print("❌ OrderSend() forcé échoué. Erreur: ", GetLastError());
    }
}
