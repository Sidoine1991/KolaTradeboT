//+------------------------------------------------------------------+
//| Properties & Includes                                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Professional Trading EA"
#property link      "https://www.mql5.com"
#property version   "5.0"
#property description "AngelOfSpike v5.0 - Spike Hunter Edition avec stratégies SMC renforcées"

//--- Includes
#include <StdLibErr.mqh>
#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Object.mqh>
#include <Math\Stat\Math.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
input string   InpTradeSettings   = "=== Trade Settings ===";

input string   InpLiquiditySettings = "=== Liquidity Settings ===";
input bool     InpShowLiquidityZones = true;       // Afficher les zones de liquidité
input int      InpLiquidityZoneLookback = 200;     // Période de rétrospection pour les zones de liquidité
input double   InpLiquidityZoneThreshold = 0.5;    // Seuil pour les zones de liquidité

input string   InpVolumeProfileSettings = "=== Volume Profile Settings ===";
input bool     InpShowVolumeProfile = true;        // Afficher le profil de volume
input int      InpVolumeProfileLookback = 200;     // Période de rétrospection pour le profil de volume
input double   InpVolumeProfileThreshold = 0.5;    // Seuil pour le profil de volume

//+------------------------------------------------------------------+
//| Structures pour Support/Resistance et Trendlines               |
//+------------------------------------------------------------------+

// Structure pour Order Block (SMC)
struct OrderBlock {
    double high;                    // Plus haut de l'OB
    double low;                     // Plus bas de l'OB
    double entry;                   // Prix d'entrée optimal
    bool isValid;                   // OB valide
    bool isBullish;                 // OB haussier ou baissier
    datetime created_time;          // Temps de création
    int touch_count;               // Nombre de touches
    double strength;                // Force de l'OB (0-1)
    bool isActive;                  // OB encore actif
    double success_rate;            // Taux de succès
};

// Structure pour Fair Value Gap (SMC)
struct FairValueGap {
    double top;                     // Haut du gap
    double bottom;                  // Bas du gap
    double middle;                  // Milieu du gap
    bool isValid;                   // FVG valide
    bool isBullish;                 // FVG haussier ou baissier
    datetime created_time;          // Temps de création
    int touch_count;               // Nombre de touches
    double strength;                // Force du FVG (0-1)
    bool isActive;                  // FVG encore actif
    double success_rate;            // Taux de succès
};

// Structure pour Liquidity Pool (SMC)
struct LiquidityPool {
    double level;                   // Niveau de liquidité
    bool isAbove;                   // Liquidité au-dessus ou en-dessous
    bool isValid;                   // Pool valide
    datetime created_time;          // Temps de création
    int touch_count;               // Nombre de touches
    double strength;                // Force du pool (0-1)
    bool isActive;                  // Pool encore actif
    double success_rate;            // Taux de succès
};

// Structure pour Market Structure (SMC)
struct MarketStructure {
    double swing_high;              // Plus haut récent
    double swing_low;               // Plus bas récent
    bool bos_detected;              // Break of Structure détecté
    bool choc_detected;             // Change of Character détecté
    int structure_type;             // Type de structure (1=haussier, -1=baissier, 0=neutre)
    datetime last_update;           // Dernière mise à jour
    double strength;                // Force de la structure (0-1)
};

// Structure pour Confluence Score
struct ConfluenceScore {
    double rsi_score;               // Score RSI (0-1)
    double sr_score;                // Score Support/Résistance (0-1)
    double ob_score;                 // Score Order Block (0-1)
    double fvg_score;               // Score Fair Value Gap (0-1)
    double liquidity_score;         // Score Liquidité (0-1)
    double structure_score;         // Score Structure (0-1)
    double volume_score;            // Score Volume (0-1)
    double momentum_score;          // Score Momentum (0-1)
    double total_score;             // Score total (0-1)
    int signal_direction;            // Direction du signal (1=buy, -1=sell, 0=neutre)
    double confidence;              // Confiance du signal (0-1)
};

// Structure pour une zone de support/resistance
struct SRZone {
    double level;                    // Niveau de prix
    double strength;                 // Force de la zone (0-1)
    int touch_count;                 // Nombre de touches
    datetime first_touch;            // Premiere touche
    datetime last_touch;             // Derniere touche
    bool is_support;                 // True si support, false si résistance
    ENUM_TIMEFRAMES timeframe;       // Timeframe de la zone
    bool is_active;                  // Zone encore active
    double success_rate;             // Taux de succès des trades à ce niveau
    int total_trades;                // Nombre total de trades à ce niveau
    int winning_trades;              // Nombre de trades gagnants
    double avg_profit;               // Profit moyen
    double avg_loss;                 // Perte moyenne
    double profit_factor;            // Facteur de profit
    datetime created_time;           // Temps de création
};

// Structure pour une trendline
struct Trendline {
    double start_price;              // Prix de départ
    double end_price;                // Prix de fin
    datetime start_time;             // Temps de départ
    datetime end_time;               // Temps de fin
    double slope;                    // Pente de la trendline
    bool is_uptrend;                 // True si haussière, false si baissière
    int touch_count;                 // Nombre de touches
    double strength;                 // Force de la trendline (0-1)
    ENUM_TIMEFRAMES timeframe;       // Timeframe de la trendline
    bool is_active;                  // Trendline encore active
    datetime created_time;           // Temps de création
};


// Variables globales pour S/R et trendlines
SRZone g_sr_zones[50];               // Zones S/R détectées
int g_sr_zone_count = 0;             // Nombre de zones S/R
Trendline g_trendlines[30];          // Trendlines détectées
int g_trendline_count = 0;           // Nombre de trendlines
datetime g_last_sr_update = 0;      // Dernière mise à jour S/R
datetime g_last_trendline_update = 0; // Dernière mise à jour trendlines
datetime g_last_visual_update = 0;   // Dernière mise à jour des visualisations

// Variables globales pour SMC renforcé
OrderBlock g_order_blocks[20];       // Order Blocks détectés
int g_ob_count = 0;                  // Nombre d'Order Blocks
FairValueGap g_fvg_gaps[20];         // Fair Value Gaps détectés
int g_fvg_count = 0;                 // Nombre de FVG
LiquidityPool g_liquidity_pools[15]; // Pools de liquidité détectés
int g_lp_count = 0;                   // Nombre de pools de liquidité
MarketStructure g_market_structure;   // Structure de marché actuelle
ConfluenceScore g_confluence_score;   // Score de confluence actuel
datetime g_last_smc_update = 0;      // Dernière mise à jour SMC

// Variables pour gestion des trades et SL/TP
struct TradeInfo {
    ulong ticket;                    // Ticket du trade
    datetime open_time;              // Temps d'ouverture
    double open_price;              // Prix d'ouverture
    int direction;                  // Direction (1=BUY, -1=SELL)
    string symbol;                  // Symbole
    bool sl_tp_set;                 // SL/TP définis
    bool spike_detected;            // Spike détecté
    datetime last_spike_check;      // Dernière vérification spike
};
TradeInfo g_active_trades[10];       // Trades actifs
int g_active_trade_count = 0;        // Nombre de trades actifs


// Variables pour stabilité de confiance
double g_confidence_history[10];     // Historique des confiances
int g_confidence_index = 0;          // Index actuel
datetime g_last_confidence_check = 0; // Dernière vérification
double g_min_stable_confidence = 0.95; // Confiance minimum stable (95%)

//--- Forward declarations for functions used before their definitions
double SnapToDerivBoomCrashLots(const double desired);
bool IsBoomCrashIndex(string symbol);
double SnapLotToSymbol(const string symbol, const double desired);
bool   EnsureValidStops(const string symbol, const int direction, const double price, const double point, double &sl_price, double &tp_price);

// Global implementation so calls outside classes can resolve
double SnapToDerivBoomCrashLots(const double desired)
{
    double allowed[] = {0.20, 0.50, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0};
    double target = desired;
    if(target <= allowed[0]) return allowed[0];
    for(int i=1;i<ArraySize(allowed);i++)
    {
        if(target <= allowed[i])
        {
            double low = allowed[i-1];
            double high = allowed[i];
            return (MathAbs(target-low) <= MathAbs(high-target)) ? low : high;
        }
    }
    return allowed[ArraySize(allowed)-1];
}

// ICT helpers (simplifiés)
int DetectICTStructureScore(MqlRates &rates[])
{
    // BOS/COS simplifié: comparer sommets/creux récents
    double h2=rates[2].high, h3=rates[3].high, h4=rates[4].high;
    double l2=rates[2].low,  l3=rates[3].low,  l4=rates[4].low;
    int score=0;
    if(h2>h3 && h3>h4) score += 15; // lower-highs ? biais vendeur
    if(l2<l3 && l3<l4) score += 15; // higher-lows ? biais acheteur
    return score;
}

int DetectICTOTEScore(MqlRates &rates[])
{
    // OTE classique: zone 62%-79% d'un swing récent (bougies 5..1)
    double swingHigh = rates[5].high;
    double swingLow  = rates[5].low;
    for(int i=4;i>=1;i--){ if(rates[i].high>swingHigh) swingHigh=rates[i].high; if(rates[i].low<swingLow) swingLow=rates[i].low; }
    double range = swingHigh - swingLow; if(range<=0) return 0;
    double oteMin = swingLow + 0.62*range;
    double oteMax = swingLow + 0.79*range;
    double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    return (px>=oteMin && px<=oteMax)? 20 : 0;
}

void DrawOTEZone() { /* disabled */ }

void DrawBOSCOSLevels() { /* disabled */ }

// Spike Zone Detector (compression + confluences)
bool IsSpikeBar(const MqlRates &bar, const double atr)
{
    double range = bar.high - bar.low;
    double body  = MathAbs(bar.close - bar.open);
    double upper = bar.high - MathMax(bar.open, bar.close);
    double lower = MathMin(bar.open, bar.close) - bar.low;
    if(atr<=0) return false;
    if(range < InpSpikeATRMult * atr) return false;
    if(body<=0) return false;
    if(MathMax(upper,lower)/body < InpSpikeWickBodyMin) return false;
    return true;
}

bool DetectCompressionZone(MqlRates &rates[], double &zLow, double &zHigh)
{
    int n = ArraySize(rates); if(n < InpCompressionLookback*2+2) return false;
    double rRecent=0, rOld=0; int L=InpCompressionLookback;
    for(int i=1; i<=L; i++) rRecent += (rates[i].high - rates[i].low);
    for(int i=L+1; i<=2*L; i++) rOld += (rates[i].high - rates[i].low);
    if(rOld<=0) return false;
    bool compressed = (rRecent <= InpCompressionRatio * rOld);
    if(!compressed) return false;
    zLow = rates[L].low; zHigh = rates[L].high;
    for(int i=1;i<=L;i++){ if(rates[i].low<zLow) zLow=rates[i].low; if(rates[i].high>zHigh) zHigh=rates[i].high; }
    return true;
}

int ComputeSpikeZoneScore(MqlRates &rates[])
{
    int score=0;
    // ATR M1
    int atr=iATR(_Symbol, PERIOD_M1, 14); double a[2]; if(atr!=INVALID_HANDLE && CopyBuffer(atr,0,0,2,a)>=2) { if(a[0]>0) score += 10; IndicatorRelease(atr);} 
    // OTE confluence
    score += DetectICTOTEScore(rates);
    // BOS/COS confluence
    score += DetectICTStructureScore(rates);
    // Price action
    score += DetectICTPriceActionScore(rates);
    // Trend MTF
    score += DetectICTTrendScore();
    if(score>100) score=100; return score;
}

void DrawSpikeZoneIfAny()
{
    MqlRates r[]; if(CopyRates(_Symbol, PERIOD_M1, 0, MathMax(20, 2*InpCompressionLookback+5), r) < 2*InpCompressionLookback+5) return;
    double zl=0, zh=0; if(!DetectCompressionZone(r, zl, zh)) return;

    // Dessiner zone de compression comme zone potentielle de départ de spike
    datetime t0=TimeCurrent(); string name=StringFormat("SPKZ_%s_%d", _Symbol, (int)t0);
    if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
    if(ObjectCreate(0,name, OBJ_RECTANGLE, 0, t0-60, zl, t0, zh))
    {
        ObjectSetInteger(0, name, OBJPROP_BACK, false);
        ObjectSetInteger(0, name, OBJPROP_COLOR, (color)clrDeepSkyBlue);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    }

    // Score dynamique (OTE/BOS/COS désactivés visuellement, score conservé si besoin)
    int L = MathMax(2, InpCompressionLookback);
    double rRecent=0, rOld=0;
    for(int i=1; i<=L; i++) rRecent += (r[i].high - r[i].low);
    for(int i=L+1; i<=2*L; i++) rOld += (r[i].high - r[i].low);
    double compScore = 0.0;
    if(rRecent>0.0 && rOld>0.0)
    {
        double ratio = rOld / MathMax(1e-8, rRecent); // >1 si compression
        compScore = (ratio - 1.0) * 25.0;             // 1.0 -> 0; 3.0 -> ~50
        if(compScore < 0.0) compScore = 0.0;
        if(compScore > 50.0) compScore = 50.0;
    }
    int cScore = (int)MathRound(compScore);

    int oScore = DetectICTOTEScore(r);               // 0..20
    int bScore = DetectICTStructureScore(r);         // 0..30 ? cap 20
    if(bScore > 20) bScore = 20;
    int tScore = DetectICTTrendScore();              // 0..15 ? cap 10
    if(tScore > 10) tScore = 10;

    int total = cScore + oScore + bScore + tScore;
    if(total > 100) total = 100;

    // Afficher label détaillé
    string lbl=StringFormat("SPKZLBL_%s_%d", _Symbol, (int)t0);
    string text = StringFormat("SpikeZone %d (C:%d O:%d B:%d T:%d)", total, cScore, oScore, bScore, tScore);
    DrawLabel(lbl, text, 12, 78, clrLightSteelBlue);
}

int DetectICTPriceActionScore(MqlRates &rates[])
{
    // Rejet/mèche longue sur dernière bougie
    double body = MathAbs(rates[1].close - rates[1].open);
    double upper = rates[1].high - MathMax(rates[1].open, rates[1].close);
    double lower = MathMin(rates[1].open, rates[1].close) - rates[1].low;
    int s=0;
    if(body>0){ if(upper/body>2.0) s+=10; if(lower/body>2.0) s+=10; }
    return s;
}

int DetectICTTrendScore()
{
    // Alignement tendance H1 + M15 via EMA fast/slow
    int d1 = CSignalValidator::GetTrendDirection(PERIOD_H1);
    int d2 = CSignalValidator::GetTrendDirection(PERIOD_M15);
    if(d1==0 || d2==0) return 0;
    return (d1==d2)? 15 : 0;
}
// Header duplicated earlier; removed here to avoid duplicate properties/includes

//--- Input parameters (OPTIMISÉS - 15 paramètres maximum pour éviter les bugs MT5)
input group "=== VISUALISATION AVANCÉE ==="
input bool     InpShowSR             = true;      // Afficher les supports/résistances
input bool     InpShowFVG            = true;      // Afficher les Fair Value Gaps
input bool     InpShowOTE            = true;      // Afficher les zones OTE
input bool     InpShowFibonacci      = true;      // Afficher les niveaux Fibonacci
input bool     InpShowChartPatterns  = true;      // Afficher les motifs graphiques
input int      InpSRPeriods          = 50;        // Périodes pour détection S/R
input double   InpATRMultiplier      = 0.1;       // Multiplicateur ATR pour tolérance S/R
input color    InpSupportColor       = clrLime;   // Couleur des supports
input color    InpResistanceColor    = clrRed;    // Couleur des résistances
input int      InpLineWidth          = 1;         // Épaisseur des lignes
input bool     InpShowLabels         = true;      // Afficher les étiquettes de prix
input int      InpLabelShift         = 10;        // Décalage horizontal des étiquettes (bougies)

input group "=== ORDRES LIMIT ET GESTION SL/TP OBLIGATOIRES ==="
input bool     InpUseBuyLimitOrders = true;         // Utiliser les ordres BUY Limit
input bool     InpUseSellLimitOrders = true;        // Utiliser les ordres SELL Limit
input bool     InpForceSLTPOnAllOrders = true;      // Forcer SL/TP sur tous les ordres
input int      InpBuyLimitDistance = 10;            // Distance BUY Limit (points)
input int      InpSellLimitDistance = 10;           // Distance SELL Limit (points)
input int      InpLimitOrderSL = 8;                 // Stop Loss pour ordres Limit (points)
input int      InpLimitOrderTP = 25;                // Take Profit pour ordres Limit (points)
input int      InpLimitOrderExpiration = 60;        // Expiration ordres Limit (minutes)
input bool     InpUseDynamicLimitDistance = true;   // Distance dynamique basée sur ATR
input double   InpLimitDistanceATRMultiplier = 1.5; // Multiplicateur ATR pour distance Limit
input bool     InpCancelLimitOnSpike = true;        // Annuler ordres Limit lors de spike
input bool     InpShowLimitOrderArrows = true;      // Afficher flèches ordres Limit
input color    InpBuyLimitArrowColor = clrBlue;     // Couleur flèche BUY Limit
input color    InpSellLimitArrowColor = clrOrange;  // Couleur flèche SELL Limit
input int      InpLimitArrowSize = 2;               // Taille flèches ordres Limit
input bool     InpSendLimitOrderNotification = true; // Notification ordres Limit
input string   InpBuyLimitSound = "buy_limit.wav";  // Son ordre BUY Limit
input string   InpSellLimitSound = "sell_limit.wav"; // Son ordre SELL Limit

input group "=== EXÉCUTION AUTOMATIQUE DES TRADES ==="
input bool     InpAutoExecuteTrades = true;        // Exécuter automatiquement les trades détectés
input bool     InpShowSpikeArrow = true;            // Afficher flèche d'annonce de spike
input color    InpSpikeArrowColor = clrYellow;     // Couleur flèche de spike
input int      InpSpikeArrowSize = 4;               // Taille flèche de spike
input bool     InpPlaySoundOnSpike = true;          // Son lors de détection spike
input string   InpSpikeSoundFile = "spike_detected.wav"; // Fichier son pour spike
input bool     InpSendSpikeNotification = true;    // Notification lors de détection spike
input double   InpMaxLossPerTradeUSD = 3.5;        // Perte maximale par trade (3.5$)
input bool     InpCloseImmediatelyAfterSpike = true; // Fermer immédiatement après spike
input int      InpSpikeCloseDelaySeconds = 2;       // Délai avant fermeture après spike (2s)
input bool     InpForceCloseOnMaxLoss = true;      // Forcer fermeture si perte atteint 3.5$
input bool     InpShowTradeExecutionAlert = true;   // Alerte lors d'exécution trade
input bool     InpShowTradeCloseAlert = true;       // Alerte lors de fermeture trade

input group "=== NOTIFICATIONS DE SIGNAL ==="
input bool     InpSendSignalNotification = true;    // Envoyer notification de signal
input bool     InpSendTradeExecutionNotification = true; // Notification exécution trade
input bool     InpSendTradeCloseNotification = true; // Notification fermeture trade
input bool     InpPlaySoundOnSignal = true;          // Son sur signal
input string   InpBuySignalSound = "buy_signal.wav"; // Son signal BUY
input string   InpSellSignalSound = "sell_signal.wav"; // Son signal SELL
input string   InpSpikeDetectedSound = "spike_detected.wav"; // Son spike détecté
input string   InpTradeExecutedSound = "trade_executed.wav"; // Son trade exécuté
input string   InpTradeClosedSound = "trade_closed.wav"; // Son trade fermé
input bool     InpSendPushNotification = true;      // Notification push mobile
input bool     InpSendEmailNotification = false;    // Notification email
input string   InpEmailAddress = "";                // Adresse email
input bool     InpShowDesktopAlert = true;          // Alerte bureau
input bool     InpShowChartAlert = true;            // Alerte sur graphique
input color    InpAlertTextColor = clrWhite;        // Couleur texte alerte
input int      InpAlertFontSize = 12;               // Taille police alerte

input group "=== DÉBOGAGE ==="
input bool     InpDebug              = true;      // Afficher les informations de débogage
input bool     InpShowHUD            = true;      // Afficher le HUD sur le graphique

input group "=== CONFIGURATION GÉNÉRALE ==="
input bool     InpEnableTrading        = true;     // Activer le trading
input int      InpMagicNumber          = 123456;   // Magic number
input double   InpLotSize              = 0.2;      // Taille du lot par défaut
input int      InpStopLoss             = 8;        // Stop Loss obligatoire (8 points)
input int      InpTakeProfit           = 25;       // Take Profit obligatoire (25 points)
input bool     InpUseDynamicLotSize = true;         // Taille de lot dynamique selon capital
input double   InpRiskPercentPerTrade = 0.5;      // Risque par trade (0.5% du capital)
input bool     InpForceSLTPOnEveryOrder = true;   // Forcer SL/TP sur chaque ordre
input bool     InpRejectOrdersWithoutSLTP = true; // Rejeter ordres sans SL/TP
input int      InpMinSLPoints = 5;                 // Stop Loss minimum (points)
input int      InpMaxSLPoints = 50;                // Stop Loss maximum (points)
input int      InpMinTPPoints = 10;                // Take Profit minimum (points)
input int      InpMaxTPPoints = 200;               // Take Profit maximum (points)

input group "=== GESTION DES RISQUES ==="
input double   InpMaxRiskPercent       = 1.0;      // Risque maximum par trade (%)
input double   InpMaxDailyLoss         = 3.5;      // Perte max journalière (3.5$)
input int      InpMaxTrades            = 1;        // Nombre max de trades (1 pour concentration)
input int      InpCooldownMinutes      = 1;        // Cooldown entre trades réduit (1 min)
input bool     InpStrictSinglePosition = true;     // Une seule position à la fois (concentration)
input bool     InpEnableSpikeReentry   = true;     // Ré-entrée après spike
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_H1; // Timeframe pour tendance
input int      InpMaxGlobalSimultaneousTrades = 1; // Nombre max de trades simultanés global (1)
input bool     InpUseTrailingStopAfterProfit = true; // Trailing stop après profit
input int      InpTrailingStartPoints = 3;         // Démarrage trailing stop (3 points)
input int      InpTrailingStepPoints = 1;          // Pas du trailing stop (1 point)

input group "=== TRADING INTELLIGENT (FAIBLE PERTE, MAX GAIN) ==="
input bool     InpUseSmartTrading       = true;     // Activer le trading intelligent
input double   InpMaxRiskPerTrade       = 0.5;      // Risque max par trade (0.5% du capital)
input double   InpMinRiskRewardRatio   = 2.0;      // Ratio risque/récompense minimum (1:2)
input double   InpMinConfidenceThreshold = 85.0;    // Seuil de confiance minimum (85%)
input bool     InpSpikeOnlyMode         = true;     // N'entrer que si probabilité de spike élevée (85%, pré-signal)
input bool     InpValidateTradeWin      = true;     // Valider que le trade est gagnant en 1 min
input bool     InpVerifySpikeBeforeSignal = true;   // Vérifier le spike avant d'annoncer
input bool     InpEnableEarlyDetection  = true;     // Activer la détection précoce
input int      InpLookbackPeriod        = 20;       // Période de lookback pour détection
input double   InpConsolidationThreshold = 0.7;     // Seuil de consolidation (0.7 = 70%)
input double   InpWickRatioThreshold    = 2.0;      // Seuil de ratio de mèche (2.0 = 200%)
input bool     InpUseMultiTimeframe     = false;    // Utiliser la validation multi-timeframe
input bool     InpUseSupportResistance  = false;    // Utiliser la validation support/résistance
input int      InpMinConfidence         = 50;       // Confiance minimum pour validation
input double   InpVolatilityThreshold   = 1.5;      // Seuil d'augmentation de volatilité (1.5 = 150%)
input double   InpSRProximityPercent    = 0.5;      // Proximité S/R en pourcentage (0.5%)
input bool     InpUseDynamicTP          = true;     // Take Profit dynamique basé sur volatilité
input bool     InpUseAdaptiveSL         = true;     // Stop Loss adaptatif
input bool     InpUsePartialClose       = true;     // Fermeture partielle des positions
input double   InpPartialClosePercent   = 50.0;     // Pourcentage de fermeture partielle
input int      InpPartialCloseAtProfit  = 6;       // Fermeture partielle à X points de profit
input bool     InpUseTrailingStopSmart  = true;    // Trailing stop intelligent

input group "=== API CONNEXION ==="
input string   InpAPIUrl               = "http://127.0.0.1:8001"; // URL API Python
input int      InpAPITimeout           = 3000;     // Timeout API (ms)
input bool     InpUseAPIPredictions    = true;     // Utiliser prédictions API

input group "=== NOTIFICATIONS ==="
input bool     InpSendNotifications    = true;     // Envoyer notifications
input bool     InpPlaySounds           = false;    // Alertes sonores (désactivées)
input string   InpSoundFile            = "alert.wav"; // Fichier son pour alertes
input bool     InpNotifyRawSignals     = false;    // Notifier les pré-signaux (désactivé)
input bool     InpDrawPreSignalArrows  = true;     // Dessiner flèches pré-signal (activé)
input int      InpNotificationCooldownSec = 30;    // Cooldown notifications (sec)

input group "=== ICT STRATEGY (BOS, COS, OTE, FIB, PA) ==="
input bool     InpEnableICT            = true;     // Activer filtres ICT
input int      InpICTMinScore          = 40;       // Score ICT minimum (0-100)
input bool     InpICTUseBOSCOS         = true;     // Utiliser BOS/COS (Break/Change of Structure)
// Input variables moved to VISUALISATION AVANCÉE section
input bool     InpICTUseOTE            = true;     // Utiliser OTE (Optimal Trade Entry) 62-79%
input bool     InpICTUseFibonacci      = true;     // Utiliser confluence niveaux Fibonacci
input bool     InpICTUsePriceAction    = true;     // Rejets, mèches longues, FVG simple
input bool     InpICTUseTrendMTF       = true;     // Tendance MTF alignée
input bool     InpICTAnnouncePreSpike  = true;     // Annoncer le spike 1 minute avant (flèche unique)
input bool     InpAlwaysDrawSpikeZones = false;    // Dessiner zones (OTE/BOS/COS/Compression) en continu

input group "=== SMC TRADING (Smart Money Concepts) ==="
input bool     InpUseSMCTrading         = true;     // Activer trading SMC
input bool     InpSMCAvoidCounterTrend  = true;     // Éviter trades contre-tendance
input bool     InpSMCUseLimitOrders     = true;     // Utiliser ordres limit pour SMC
input double   InpSMCSRTolerance        = 0.002;    // Tolérance S/R (0.2%)
input int      InpSMCMinTouches         = 2;        // Touches minimum pour confirmer
input double   InpSMCMinStrength        = 0.6;      // Force minimum niveau
input double   InpSMCMinRR              = 2.0;      // Risk/Reward minimum (1:2)
input int      InpSMCMinTimeframes      = 2;        // Min timeframes alignés pour signal

input group "=== SPIKE ZONES (DETECTION) ==="
input double   InpSpikeATRMult         = 3.0;      // k1: Spike si range >= k1*ATR
input double   InpSpikeWickBodyMin     = 2.0;      // k2: max(wick)/corps >= k2
input double   InpCompressionRatio     = 0.7;      // Compression: range récent <= 0.7 * ancien
input int      InpCompressionLookback  = 5;        // Bougies pour compression
input int      InpSpikeZoneMinScore    = 60;       // Score minimum pour dessiner zone

input group "=== IA ANTICIPATIVE ==="
input bool     InpUseAIForAnticipation = true;     // Utiliser l'IA pour anticiper/filtrer
input int      InpAIMinTradeConfidence = 75;       // Confiance minimale IA pour agir (%)
input bool     InpAIAsHardFilter       = false;    // Exiger accord IA sur les signaux locaux
input bool     InpAIEnablePendingOrders = true;    // Placer des ordres LIMIT selon l'IA
input int      InpAIPendingExpirySec   = 120;      // Expiration des ordres LIMIT (sec)
input int      InpAIDecisionTTLMin     = 10;       // Validité d'une recommandation IA (minutes)
input bool     InpAPlusMode            = false;    // Mode A+ (filtrage strict)

input group "=== SIGNALS EXTERNES (API) ==="
input bool     InpUseExternalSignals   = true;       // Consommer des signaux via API externe
input string   InpExternalSignalsURL   = "http://localhost:8001/signals"; // Endpoint /signals
input string   InpTrendAnalysisURL     = "http://localhost:8001/trend"; // Endpoint /trend
input int      InpExtSigMinConfidence  = 70;       // Confiance minimale API (%)
input bool     InpExtSigAsHardFilter   = false;    // Exiger accord API sur signaux locaux
input int      InpExtSigTTLSeconds     = 300;        // Durée de validité des signaux externes (secondes)
input bool     InpEnableMultiSymbolAPI = true;     // Scanner les graphiques ouverts et agir sur signaux API
input int      InpMaxChartsScan        = 10;       // Nombre max de graphiques à scanner par tick
input int      InpMultiSymbolCooldownSec = 2;      // Cooldown scan multi-symbol (secondes)
input bool     InpEnableAdditionalSymbols = true;   // Activer une liste de symboles additionnels
input string   InpAdditionalSymbols     = "Crash 1000 Index,Crash 500 Index"; // Liste CSV de symboles à trader

input group "=== RECOMMANDATIONS IA (GEMINI PROXY) ==="
input bool     InpEnableAIRecommendations = false;  // Activer recommandations IA (via proxy local)
input string   InpAIProxyURL           = "http://127.0.0.1:8099/recommend"; // URL du proxy AI
input int      InpAIUpdateSeconds      = 10;        // Fréquence mise à jour panneau IA (sec)

input group "=== RECOMMANDATIONS API SIMPLE ==="
input bool     InpUseApiRecommendations = true;     // Consommer /recommendations depuis simple_api
input string   InpRecommendationsURL    = "http://127.0.0.1:8001/recommendations"; // Endpoint /recommendations
input int      InpRecoPollSeconds       = 60;       // Fréquence de poll (sec)
input bool     InpShowApiPanel          = true;     // Afficher panneau d'analyses API sur le graphique
input int      InpApiPanelUpdateSeconds = 10;       // Fréquence mise à jour panneau API (sec)

input group "=== FERMETURE PANIER (BASKET) ==="
input bool     InpEnableBasketClose    = true;     // Fermer toutes les positions si profit total atteint
input double   InpBasketProfitCloseUSD = 50.0;     // Seuil de profit total ($) pour arrêter la journée
input bool     InpBasketIncludeAllPositions = false; // Inclure toutes les positions (tous magics)
input double   InpBasketLossCloseUSD   = 4.0;      // Seuil de perte totale ($) pour couper et arrêter la journée (2 trades x 2$)
input bool     InpReenterAfterBasketTP = false;    // Ré-entrer après clôture sur TP panier si tendance ok

input group "=== SYSTÈME SPIKE ULTRA-PRÉCIS ==="
input bool     InpUltraPreciseMode     = true;     // Mode ultra-précis : entrée SEULEMENT sur spike confirmé
input double   InpSpikeConfirmationThreshold = 0.1; // Seuil de confirmation spike (%) - Plus strict
input double   InpMinSpikeStrength     = 2.0;      // Force minimum du spike (vs ATR) - Plus strict
input bool     InpExitRequireProfit = false; // Exiger profit positif pour fermeture après spike
input double   InpQuickGainThreshold   = 0.5;      // Seuil de gain rapide pour fermeture ($)
input double   InpUltraHighConfidence  = 98.0;     // Confiance minimum ultra-élevée (%) - Plus strict
input double   InpStableConfidenceMin  = 98.0;     // Confiance minimum stable pour trading (%) - Plus strict
input double   InpConfidenceStabilityMax = 2.0;    // Écart-type maximum pour stabilité (%) - Plus strict
input bool     InpSingleTradeOnly      = false;    // Un seul trade à la fois
input int      InpMaxSimultaneousTrades = 2;       // Nombre maximum de trades simultanés (MAXIMUM 2)
input int      InpMinTradeIntervalSeconds = 300;   // Intervalle minimum entre trades (sec)

input group "=== SIGNALS BOOM/CRASH/VOLATILITY S/R ==="
input bool     InpEnableBoomCrashSignals = true;   // Activer signaux Boom/Crash/Volatility basés S/R
input double   InpSupportBoomThreshold = 60.0;     // Seuil support pour signal BUY (60%)
input double   InpResistanceCrashThreshold = 50.0; // Seuil résistance pour signal SELL (50%)
input double   InpSRProximityTolerance = 0.0003;   // Tolérance proximité S/R (en prix)
input bool     InpEnableVolatilitySignals = true;   // Activer signaux Volatility (bidirectionnel)
input double   InpVolatilitySpikeThreshold = 1.8;  // Seuil spike pour Volatility (1.8x ATR)
input double   InpVol10SpikeThreshold = 1.5;        // Seuil spike pour Volatility 10% (plus sensible)
input double   InpVol25SpikeThreshold = 1.6;        // Seuil spike pour Volatility 25%
input double   InpVol50SpikeThreshold = 1.8;        // Seuil spike pour Volatility 50%
input double   InpVol75SpikeThreshold = 2.0;        // Seuil spike pour Volatility 75%
input double   InpVol100SpikeThreshold = 2.2;        // Seuil spike pour Volatility 100% (plus strict)

input group "=== PRÉDICTION SPIKE IMMINENT ==="
input bool     InpEnableSpikePrediction = true;    // Activer prédiction de spike imminent
input double   InpVolumeCompressionThreshold = 0.5; // Seuil compression volume (50%)
input double   InpMAConvergenceThreshold = 0.001;   // Seuil convergence MA (0.1%)
input double   InpATRCompressionThreshold = 0.7;    // Seuil compression ATR (70%)
input double   InpPressureImbalanceThreshold = 2.0; // Seuil déséquilibre pression (2:1)
input int      InpPredictionConfidenceMin = 75;    // Confiance minimum prédiction (%)


input group "=== SL/TP OPTIMAUX BASÉS SUR VOLATILITÉ ==="
input bool     InpUseOptimalSLTP       = true;     // Utiliser SL/TP optimaux basés sur ATR
input double   InpSL_ATR_Multiplier   = 0.8;      // Multiplicateur ATR pour SL (conservateur)
input double   InpTP_ATR_Multiplier   = 1.2;      // Multiplicateur ATR pour TP (optimiste)
input int      InpATR_Period          = 14;       // Période ATR pour calculs
input bool     InpAdaptiveSLTP        = true;     // SL/TP adaptatifs selon volatilité

input group "=== SUPPORT/RÉSISTANCE MULTI-TIMEFRAME ==="
input bool     InpEnableSRDetection    = true;     // Activer détection S/R multi-timeframe
input bool     InpPrioritizeSREntries = true;     // Privilégier entrées dans zones S/R
input double   InpSRZoneTolerance     = 0.0005;     // Tolérance zone S/R (en prix)
input int      InpSRMinTouches        = 2;        // Nombre minimum de touches pour valider S/R
input int      InpSRLookbackBars      = 100;      // Barres à analyser pour S/R
input bool     InpDrawSRZones         = true;     // Dessiner zones S/R sur graphique
input double   InpSRMinConfidence     = 70.0;     // Confiance minimum pour affichage (%)
input color    InpSRSupportColor      = clrLime;  // Couleur zones support
input color    InpSRResistanceColor   = clrRed;   // Couleur zones résistance

input group "=== TRENDLINES DÉTECTION ==="
input bool     InpEnableTrendlines    = true;     // Activer détection trendlines
input double   InpTrendlineTolerance  = 0.0003;   // Tolérance trendline (en prix)
input int      InpTrendlineMinPoints  = 3;        // Points minimum pour trendline
input bool     InpDrawTrendlines      = true;     // Dessiner trendlines sur graphique
input color    InpTrendlineUpColor    = clrBlue;  // Couleur trendline haussière
input color    InpTrendlineDownColor  = clrOrange; // Couleur trendline baissière

input group "=== OBJECTIFS MONÉTAIRES PAR TRADE ==="
input bool     InpEnforceDollarTargets = true;     // Forcer objectifs $ par trade
input double   InpMaxLossUSDPerTrade   = 1.5;      // Perte $ max par trade
input double   InpTargetProfitUSD      = 5.0;      // Gain cible $ par trade

input group "=== OBJECTIF GLOBAL OUVERT ==="
input double   InpMaxGlobalOpenLossUSD = 3.5;      // Perte totale ouverte max ($) pour forcer clôture
input int      InpGlobalCooldownMin    = 5;        // Cooldown global après perte (minutes)

input group "=== TENDANCE & RÉENTRÉE ==="
input int      InpEMAFast              = 20;        // EMA rapide
input int      InpEMASlow              = 50;        // EMA lente
input bool     InpEnforceM1Trend       = true;      // Interdire les entrées contre-tendance M1 (EMAfast/EMAslow)
input bool     InpRequireTrendAlign    = true;      // N'entrer que si aligné avec la tendance
input int      InpMinEdgeConfidence    = 70;        // Score minimum pour engager un trade (0-100)
input int      InpMaxSpreadPoints      = 30;        // Spread max autorisé (points)
input int      InpReentryMinBars       = 2;         // Attendre au moins N petites bougies
input int      InpReentryMaxBars       = 5;         // Au plus N petites bougies
input double   InpSmallCandlePct       = 0.60;      // Bougie petite si range < 60% de la moyenne
input double   InpPerTradeLossCloseUSD = 1.5;       // Fermer une position si perte ? $1.5 - MODIFIÉ
input int      InpReentryCooldownMin   = 8;         // Attendre N minutes avant reprise après perte (plus prudent)
input int      InpConsecutiveLossCooldownMin = 5;   // Cooldown après 2 pertes consécutives (minutes)
input int      InpMaxConsecutiveLosses = 2;        // Nombre max de pertes consécutives avant cooldown
input double   InpPerTradeProfitCloseUSD = 2.0;     // Fermer une position si gain ? $2
input bool     InpEnableConservativeRangeMode = true; // Activer mode conservateur en range (H1/M30)
input ENUM_TIMEFRAMES InpRangeModeTF1  = PERIOD_H1; // TF 1 pour détection range
input ENUM_TIMEFRAMES InpRangeModeTF2  = PERIOD_M30; // TF 2 pour détection range
input double   InpConservativeProfitUSD = 1.0;      // TP par trade en mode conservateur ($)
input double   InpConservativeLossUSD   = 0.5;      // SL par trade en mode conservateur ($)
input bool     InpEnableStaircaseM1    = false;     // Détection pattern "escalier" en M1
input int      InpStaircaseLookback    = 8;         // Nombre de bougies à analyser en M1
input int      InpStaircaseMinSteps    = 4;         // Nombre minimum de petites bougies
input int      InpStaircaseMaxBurst    = 3;         // Nombre max d'ordres à ouvrir en rafale
input bool     InpPreferBoomCrash      = true;      // Privilégier Boom/Crash
input int      InpBoomCrashConfidenceBoost = 15;    // Diminuer l'exigence de score pour Boom/Crash
input int      InpNonBoomCrashPenalty  = 0;         // Pénalité pour non Boom/Crash (0 pour inclure Forex)
input double   InpBCQuickTPUSD         = 1.0;       // Boom/Crash: TP rapide si spike capturé ($)
input int      InpBCReentryDelayMin    = 1;         // Boom/Crash: délai avant ré-entrée (minutes)
// Trailing management - MODIFIÉ: Désactivé par défaut car interdiction de modifier
input bool     InpUseTrailing          = false;     // Activer trailing - MODIFIÉ
input double   InpBreakEvenAtR         = 0.7;       // Passer à BE à 0.7R
input double   InpTrailDistanceR       = 0.5;       // Distance de trailing = 0.5R

input group "=== PRÉ-SPIKE (BOOM/CRASH) ==="
input bool     InpEnablePreSpike       = true;      // Activer prédiction précoce
input int      InpBBPeriod             = 20;        // Période Bollinger
input double   InpBBDeviation          = 2.0;       // Déviation Bollinger
input int      InpATRShort             = 14;        // ATR court
input double   InpATRBoostMin          = 1.2;       // ATR actuel vs moyenne min
input double   InpWickRatioMin         = 1.8;       // Mèche/Corps min sur bougie précédente
input int      InpPreSpikeMinConfidence= 60;        // Confiance mini (%)
input bool     InpEnableEMATouchPreSpike = true;    // Anticiper proche touche EMA10 (M1)
input double   InpEMAApproachATRMult   = 1.2;       // Distance EMA10 <= k * ATR(M1)

input group "=== GESTION SL/TP ET SPIKE HUNTER ==="
input int      InpMaxWaitTimeMinutes   = 5;         // Temps max d'attente avant fermeture anticipée (minutes)
input double   InpDefaultSLPoints      = 50;         // SL par défaut en points si calcul ATR échoue
input double   InpDefaultTPPoints      = 100;        // TP par défaut en points si calcul ATR échoue
input bool     InpAntiCounterTrend     = true;      // Éviter trades contre-tendance (pas SELL Boom, pas BUY Crash)
input bool     InpForceSLTPOnEveryTrade = true;      // Forcer SL/TP sur chaque trade
input double   InpSpikeDetectionSensitivity = 1.0;  // Sensibilité détection spike (1.0 = très sensible)
input bool     InpExitOnSpikeDetection = true;       // Sortir immédiatement dès détection spike
input bool     InpForceCloseOnSpikeDetection = true; // Forcer fermeture sur détection spike
input bool     InpUseSpikeProfitProtection = true;  // Protection profit lors de spike
input double   InpSpikeProfitThreshold = 2.0;        // Seuil profit pour fermeture spike (2$)
input bool     InpShowSpikeCloseAlert = true;       // Alerte lors de fermeture après spike
// --- Coupures automatiques (désactivées par défaut pour éviter les va-et-vient) ---
input bool     InpEnablePerTradeAutoClose = false;   // Fermer auto par trade (profit/perte) [OFF]
input bool     InpEnableSpikeAutoClose    = false;   // Fermer auto sur spike violent [OFF]

input group "=== ZONES S/R MULTI-TIMEFRAME ==="
input bool     InpDrawMTFZones          = true;      // Dessiner zones S/R D1..M5
input int      InpZonesLookbackBars     = 150;       // Nombre de barres à analyser par TF
input double   InpZoneBandPct           = 0.0010;    // Epaisseur relative de la zone (0.10%)
input int      InpZoneRedrawSec         = 30;        // Intervalle de rafraîchissement des zones (sec)
input double   InpEntryZoneProximityPct = 0.0008;    // Proximité requise à une zone (0.08%)
input bool     InpRequireZoneProximity  = false;     // Exiger proximité d'une zone pour valider le signal
input double   InpSpikeATRMultipleClose = 2.0;       // Fermer si range M1 > k*ATR(M1)
input bool     InpDrawFibonacci         = true;      // Tracer les retracements Fibonacci principaux
input color    InpTPZoneColor           = C'255,255,200'; // Jaune clair pour TP
input color    InpSLZoneColor           = C'255,200,200'; // Rouge clair pour SL
input bool     InpRequireFibEntry       = true;      // Exiger une entrée dans la zone fib 38.2-61.8
input ENUM_TIMEFRAMES InpFibEntryTF     = PERIOD_M5; // TF pour calcul d'entrée Fibonacci

input group "=== SL/TP DYNAMIQUES & SÉCURITÉ ==="
input bool     InpUseATRForSLTP        = true;     // Utiliser ATR pour dimensionner SL/TP\r
input int      InpATRPeriod            = 14;       // Période ATR\r
input double   InpSL_ATR_Mult          = 1.0;      // Multiplicateur ATR pour SL\r
input double   InpTP_ATR_Mult          = 1.6;      // Multiplicateur ATR pour TP\r
input double   InpMinRiskReward        = 1.5;      // R:R minimum (TP >= R * SL)\r
input int      InpStopsBufferPoints    = 2;        // Buffer points au-dessus du stops level\r
input double   InpBoomCrashStopsMultiplier = 1.5;   // Multiplicateur du stops level sur Boom/Crash\r
input int      InpSLTPRetryMs          = 500;       // Délai (ms) avant tentative de modification SL/TP\r
input int      InpMaxSLTPRetries       = 3;         // Nombre maximum de tentatives de modification SL/TP\r

input group "=== GOD MODE (A+ EXTRÊME) ==="
input bool     InpEnableGodMode        = false;     // Activer GOD Mode (filtres ultra stricts)\r
input int      InpGodMinScore          = 85;        // Score minimal pour autoriser l'entrée (0-100)
input int      InpGodTFsRequired       = 4;         // Nombre de TFs alignés requis (sur D1/H4/H1/M30/M15)
input int      InpGodATRLookback       = 60;        // Barres M1 pour estimer momentum ATR
input double   InpGodATRBoostMin       = 1.3;       // ATR actuel >= k * ATRmoy (momentum)
input bool     InpGodRequireSRNear     = true;      // Exiger proximité d'une zone S/R MTF cohérente
input int      InpMinEMASlopePoints    = 5;         // Pente EMA minimum (points)
input int      InpMinADX               = 20;        // ADX minimum pour tendance

input group "=== TREND FILTER ==="
input bool     InpUseTrendOnly         = true;      // Trader uniquement dans le sens de la tendance
input int      InpEMAPeriod            = 50;        // EMA pour direction et pente
input int      InpADXPeriod            = 14;        // ADX période
input int      InpMinEMASlopePips      = 3;         // Pente min EMA (pips) par 10 barres

input group "=== DASHBOARD ==="
input bool     InpShowDashboard        = true;      // Afficher panneau
input int      InpDashCorner           = 0;         // 0 TL, 1 TR, 2 BL, 3 BR
input int      InpDashX                = 10;        // Décalage X
input int      InpDashY                = 20;        // Décalage Y

input group "=== SNIPER MODE (ENTRÉES TRÈS PRÉCISES) ==="
input bool     InpSniperMode           = true;      // Activer entrées "sniper"
input double   InpSniperMaxLossUSD     = 0.5;       // Perte $ max visée par trade (cap SL)
input int      InpSniperEntryOffsetPts = 6;         // Offset LIMIT par rapport au prix (points)

//--- Classes modulaires
class CRiskManager {
private:
    double m_dailyLoss;
    double m_dailyStartBalance;
    int m_tradesToday;
    datetime m_lastTradeTime;
    
public:
    bool ExecuteTradeOnSymbol(const string symbol, const int direction)
    {
        if(direction==0) return false;
        
        // ENCOURAGER: Trades sur volatilités, step index et forex
        bool isVolatility = IsVolatilityIndex(symbol);
        bool isStepIndex = IsStepIndex(symbol);
        bool isForex = IsForexSymbol(symbol);
        
        if(isVolatility || isStepIndex || isForex) {
            Print("? SYMBOL FAVORI - ", symbol, " (", 
                  (isVolatility ? "Volatilité" : ""), 
                  (isStepIndex ? "Step Index" : ""), 
                  (isForex ? "Forex" : ""), ") - Trade encouragé");
        }
        
        // Vérifier le cooldown après perte avant d'ouvrir une nouvelle position
        if(IsSymbolInCooldown(symbol)) {
            Print("? COOLDOWN ACTIF - Attente d'une opportunité confirmée sur ", symbol);
            return false;
        }
        
        // Vérifier les pertes consécutives pour ce symbole
        if(IsSymbolInConsecutiveLossCooldown(symbol)) {
            Print("?? SYMBOLE ", symbol, " EN COOLDOWN après ", InpMaxConsecutiveLosses, " pertes consécutives");
            return false;
        }
        
        // Vérifier la limite globale de positions simultanées
        if(IsGlobalPositionLimitReached()) {
            return false;
        }
        
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double price = (direction>0)? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
        if(point<=0 || price<=0) return false;

        // SL basé sur InpStopLoss et stops
        int stops = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        int bufferPts = MathMax(0, InpStopsBufferPoints);
        if(IsBoomCrashIndex(symbol)) { stops = (int)MathCeil(stops*MathMax(1.0, InpBoomCrashStopsMultiplier)); bufferPts = (int)MathCeil(bufferPts*MathMax(1.0, InpBoomCrashStopsMultiplier)); }
        int minPts = MathMax(1, stops + bufferPts);
        double sl_points = MathMax((double)InpStopLoss, (double)minPts);
        double sl_price = (direction>0)? price - sl_points*point : price + sl_points*point;

        // TP dynamique
        double tp_points = CalculateDynamicTakeProfit(symbol, price, direction, sl_price);
        double tp_price = (direction>0)? price + tp_points*point : price - tp_points*point;
        double risk_reward_ratio = tp_points / sl_points;
        if(risk_reward_ratio < InpMinRiskRewardRatio)
        {
            tp_points = sl_points * InpMinRiskRewardRatio;
            tp_price = (direction>0)? price + tp_points*point : price - tp_points*point;
        }

        // Lot - FORCER 0.2 pour Boom/Crash (minimum requit par le broker)
        double lotSize;
        if(IsBoomCrashIndex(symbol)) {
            lotSize = 0.20; // Minimum absolu pour Boom/Crash
            double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            if(minLot > 0.20) lotSize = minLot; // Utiliser le minLot du broker si plus élevé
        } else {
            double lotRaw = CalculateSmartLotSize(symbol, price, sl_price);
            lotSize = SnapLotToSymbol(symbol, lotRaw);
        }
        if(lotSize<=0) return false;

        CTrade trade;
        trade.SetExpertMagicNumber(InpMagicNumber);
        trade.SetDeviationInPoints(10);
        trade.SetTypeFilling(ORDER_FILLING_FOK);

        EnsureValidStops(symbol, direction, price, point, sl_price, tp_price);
        bool result = (direction>0)? trade.Buy(lotSize, symbol, price, sl_price, tp_price, "SpikeHunter Smart")
                                   : trade.Sell(lotSize, symbol, price, sl_price, tp_price, "SpikeHunter Smart");
        if(!result)
        {
            // Nudge SL/TP puis volume +0.2
            double nudgePts = MathMax(1, InpStopsBufferPoints);
            double sl_adj = sl_price, tp_adj = tp_price;
            if(direction>0){ if(sl_price>0) sl_adj-=nudgePts*point; if(tp_price>0) tp_adj+=nudgePts*point; }
            else            { if(sl_price>0) sl_adj+=nudgePts*point; if(tp_price>0) tp_adj-=nudgePts*point; }
            result = (direction>0)? trade.Buy(lotSize, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart")
                                  : trade.Sell(lotSize, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            if(!result)
            {
                double lot_up = SnapLotToSymbol(symbol, lotSize + 0.20);
                result = (direction>0)? trade.Buy(lot_up, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart")
                                      : trade.Sell(lot_up, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            }
        }
        return result;
    }
    CRiskManager() {
        m_dailyLoss = 0;
        m_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_tradesToday = 0;
        m_lastTradeTime = 0;
    }
    
    bool CanOpenTrade() {
        // Cooldown global
        if(g_globalCooldownUntil>0 && TimeCurrent() < g_globalCooldownUntil) return false;
        
        // Vérifier si nous avons une forte probabilité de soikje
        if(!HasHighProbabilitySoikjePattern()) {
            Print("Trade rejeté: Aucun modèle soikje à haute probabilité détecté");
            return false;
        }
        
        // Vérifier la perte journalière
        if(m_dailyLoss >= InpMaxDailyLoss) {
            Print("? Arrêt journalier atteint: $", DoubleToString(m_dailyLoss, 2));
            return false;
        }
        
        // Vérifier le nombre de trades
        if(m_tradesToday >= InpMaxTrades) {
            Print("? Limite de trades atteinte: ", m_tradesToday);
            return false;
        }
        
        // Vérifier le cooldown
        if(m_lastTradeTime > 0 && TimeCurrent() - m_lastTradeTime < InpCooldownMinutes * 60) {
            return false;
        }
        
        // Mode strict: si une position (avec notre magic) est ouverte n'importe où, interdire toute nouvelle entrée
        if(InpStrictSinglePosition)
        {
            for(int i = 0; i < PositionsTotal(); i++) {
                ulong tk = PositionGetTicket(i);
                if(!PositionSelectByTicket(tk)) continue;
                if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                    return false;
            }
        }
        
        // Vérification du nombre maximum de trades simultanés
        int current_trades = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                current_trades++;
            }
        }
        
        if(InpSingleTradeOnly && current_trades >= 1) {
            Print("?? Un seul trade autorisé - Trade existant détecté");
            return false;
        }
        
        if(current_trades >= InpMaxSimultaneousTrades) {
            Print("?? LIMITE STRICTE - Maximum ", InpMaxSimultaneousTrades, " positions simultanées atteint: ", current_trades, "/", InpMaxSimultaneousTrades);
            Print("?? AUCUNE NOUVELLE POSITION AUTORISÉE - Attendre fermeture d'une position existante");
            Print("?? RÈGLE: Maximum 2 trades simultanés autorisés - Pas de duplication");
            return false;
        }
        
        // Vérifier l'intervalle minimum entre les trades
        static datetime last_trade_time = 0;
        if(last_trade_time > 0 && TimeCurrent() - last_trade_time < InpMinTradeIntervalSeconds) {
            Print("?? Intervalle minimum entre trades non respecté (", InpMinTradeIntervalSeconds, " sec)");
            return false;
        }
        
        // Vérifier les trades ouverts globalement (même magic) - LIMITE STRICTE
        int openTradesGlobal = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            openTradesGlobal++;
        }
        
        // LIMITE STRICTE : Maximum 2 positions simultanées GLOBALEMENT
        if(IsGlobalPositionLimitReached()) {
            return false;
        }
        
        return true;
    }
    
    void RecordTrade(double profit) {
        m_tradesToday++;
        m_lastTradeTime = TimeCurrent();
        m_dailyLoss += MathAbs(MathMin(profit, 0));
    }
    
    void ResetDaily() {
        m_dailyLoss = 0;
        m_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
        m_tradesToday = 0;
        m_lastTradeTime = 0; // Reset last trade time as well
    }
};

class CSignalDetector {
private:
    int m_atrHandle;
    int m_maHandle;
    int m_bbHandle;
    
public:
    CSignalDetector() {
        m_atrHandle = iATR(_Symbol, PERIOD_M1, 14);
        m_maHandle = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE);
        m_bbHandle = iBands(_Symbol, PERIOD_M1, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
    }
    
    ~CSignalDetector() {
        if(m_atrHandle != INVALID_HANDLE) IndicatorRelease(m_atrHandle);
        if(m_maHandle != INVALID_HANDLE) IndicatorRelease(m_maHandle);
        if(m_bbHandle != INVALID_HANDLE) IndicatorRelease(m_bbHandle);
    }
    
    int DetectSignal() {
        if(!InpEnableEarlyDetection) return 0;
        
        // VÉRIFICATION PRÉALABLE DE TENDANCE M5 ET M1
        int trendM5 = CSignalValidator::GetTrendDirection(PERIOD_M5);
        int trendM1 = CSignalValidator::GetTrendDirection(PERIOD_M1);
        
        // Ne pas détecter de signal si tendances incertaines ou non alignées
        if(trendM5 == 0 || trendM1 == 0) {
            return 0; // Tendance incertaine
        }
        
        if(trendM5 != trendM1) {
            return 0; // Tendance non alignée
        }
        
        // Obtenir les données des bougies
        MqlRates rates[];
        if(CopyRates(_Symbol, PERIOD_M1, 0, InpLookbackPeriod, rates) < InpLookbackPeriod) {
            return 0;
        }
        
        // Filtre spread: ne pas trader si spread trop élevé
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int spreadPts = (int)MathRound((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))/MathMax(pt,1e-12));
        if(spreadPts > InpMaxSpreadPoints) return 0;
        
        // Pré-spike Boom/Crash: compression + ATR boost + mèches
        // ENTREE IMMEDIATE 3 CANDLESTICKS AVANT LE SPIKE
        if(InpEnablePreSpike && IsBoomCrashIndex(_Symbol))
        {
            int dir = 0; int conf = 0;
            if(DetectPreSpike(rates, dir, conf))
            {
                if(InpAPlusMode && !IsAPlusEnvironment(dir)) return 0;
                g_isEarlySignal = true;
                Print("?? ENTREE IMMEDIATE PRE-SPIKE sur ", _Symbol, " (3 bougies avant spike attendu)");
                return dir;
            }
        }

        // Pré-signal EMA10: approche imminente de l'EMA10 en M1 (mouvements en ciseaux)
        if(InpEnableEMATouchPreSpike && IsBoomCrashIndex(_Symbol))
        {
            int dirEMA = 0; int confEMA = 0;
            if(DetectPreSpikeEMATouch(rates, dirEMA, confEMA))
            {
                // Dessiner une flèche creuse pour pré-signal
                DrawPreSignalArrow(dirEMA);
                // Auto-entrée optionnelle si filtres passent (respect Boom/Crash + M1/M5)
                int d = EnforceBoomCrashDirection(dirEMA);
                if(d!=0 && (!InpEnforceM1Trend || CSignalValidator::IsAlignedWithM1M5(d)))
                {
                    if(!InpAPlusMode || IsAPlusEnvironment(d))
                    {
                        g_isEarlySignal = true;
                        return d;
                    }
                }
            }
        }

        // 1. Détection de consolidation
        if(IsConsolidation(rates)) {
            Print("?? SIGNAL: Consolidation détectée");
            int d = AnalyzeDirection(rates);
            if(InpAPlusMode && d!=0 && !IsAPlusEnvironment(d)) d = 0;
            // Exécuter en M5/M1 selon tendance long-terme (éviter contre-tendance Boom/Crash)
            d = EnforceBoomCrashDirection(d);
            return d;
        }
        
        // 2. Détection de mèches longues
        if(HasLongWicks(rates)) {
            Print("?? SIGNAL: Mèches longues détectées");
            {
                int d = AnalyzeDirection(rates);
                if(InpAPlusMode && d!=0 && !IsAPlusEnvironment(d)) d = 0;
                return d;
            }
        }
        
        // 3. Détection de volatilité croissante
        if(IsVolatilityIncreasing(rates)) {
            Print("?? SIGNAL: Volatilité croissante");
            {
                int d = AnalyzeDirection(rates);
                if(InpAPlusMode && d!=0 && !IsAPlusEnvironment(d)) d = 0;
                return d;
            }
        }
        
        return 0;
    }
    
private:
    // Vérifie si un modèle soikje à haute probabilité est présent
    bool HasHighProbabilitySoikjePattern()
    {
        // 1. Vérifier la configuration des bougies récentes
        MqlRates rates[];
        ArraySetAsSeries(rates, true);
        
        // Obtenir les 5 dernières boucles M1
        if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5) return false;
        
        // 2. Vérifier la configuration soikje classique (3 bougies)
        // Bougie 1: Fort mouvement directionnel
        // Bougie 2: Correction (retracement)
        // Bougie 3: Poursuite dans la direction initiale
        
        // Calculer les tailles des bougies
        double body1 = MathAbs(rates[4].close - rates[4].open);
        double body2 = MathAbs(rates[3].close - rates[3].open);
        double body3 = MathAbs(rates[2].close - rates[2].open);
        
        // Calculer les mèches
        double upperWick1 = rates[4].high - MathMax(rates[4].open, rates[4].close);
        double lowerWick1 = MathMin(rates[4].open, rates[4].close) - rates[4].low;
        
        // Vérifier la configuration soikje haussière
        bool bullishSoikje = (rates[4].close > rates[4].open) && // Bougie 1 haussière
                           (body1 > (upperWick1 + lowerWick1)) && // Corps dominant
                           (rates[3].close < rates[3].open) && // Bougie 2 baissière
                           (rates[2].close > rates[2].open) && // Bougie 3 haussière
                           (rates[2].close > rates[4].high); // Dépassement du haut de la bougie 1
        
        // Vérifier la configuration soikje baissière
        bool bearishSoikje = (rates[4].close < rates[4].open) && // Bougie 1 baissière
                           (body1 > (upperWick1 + lowerWick1)) && // Corps dominant
                           (rates[3].close > rates[3].open) && // Bougie 2 haussière
                           (rates[2].close < rates[2].open) && // Bougie 3 baissière
                           (rates[2].close < rates[4].low); // Dépassement du bas de la bougie 1
        
        // 3. Vérifier le volume (doit être croissant)
        bool volumeValid = (rates[2].tick_volume > rates[3].tick_volume) && 
                         (rates[3].tick_volume > rates[4].tick_volume * 0.7);
        
        // 4. Vérifier la volatilité (ATR sur 14 périodes)
        int atrHandle = iATR(_Symbol, PERIOD_M1, 14);
        double atr[];
        ArraySetAsSeries(atr, true);
        if(CopyBuffer(atrHandle, 0, 0, 3, atr) == 3) {
            // Volatilité croissante
            bool volatilityRising = (atr[0] > atr[1]) && (atr[1] > atr[2]);
            
            // Si configuration soikje valide, volume et volatilité cohérents
            if((bullishSoikje || bearishSoikje) && volumeValid && volatilityRising) {
                Print("Modèle soikje détecté avec haute probabilité - Configuration ", 
                      bullishSoikje ? "haussier" : "baissier");
                return true;
            }
        }
        
        return false;
    }
    
    bool IsAPlusEnvironment(const int direction)
    {
        if(direction==0) return false;
        
        // Exiger un modèle soikje valide pour les trades A+
        if(!HasHighProbabilitySoikjePattern()) {
            Print("Environnement A+ rejeté: Aucun modèle soikje valide");
            return false;
        }
        // 1) Trend alignment déjà géré si InpRequireTrendAlign, mais on revalide pour A+
        int trend = CSignalValidator::GetTrendDirection(InpTrendTF);
        if(trend!=direction) return false;
        // 2) ADX M15
        int adx = iADX(_Symbol, PERIOD_M15, 14);
        if(adx==INVALID_HANDLE) return false;
        double adxv[2]; bool ok = (CopyBuffer(adx, 0, 0, 2, adxv)>=1); IndicatorRelease(adx);
        if(!ok) return false;
        if(adxv[0] < MathMax(5, InpMinADX)) return false;
        // 3) EMA slope on H1 (fast EMA moving in direction by at least X points over last 5 bars)
        int emaF = iMA(_Symbol, PERIOD_H1, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        if(emaF==INVALID_HANDLE) return false;
        double f[6]; ok = (CopyBuffer(emaF, 0, 0, 6, f)>=5); IndicatorRelease(emaF);
        if(!ok) return false;
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double slopePts = (f[0]-f[5]) / MathMax(point,1e-12);
        if(direction>0 && slopePts <  MathMax(1.0, InpMinEMASlopePoints)) return false;
        if(direction<0 && slopePts > -MathMax(1.0, InpMinEMASlopePoints)) return false;
        // 4) ATR boost (M1): momentum présent
        int atr = iATR(_Symbol, PERIOD_M1, MathMax(5, InpATRShort));
        if(atr!=INVALID_HANDLE)
        {
            double a[20]; int n = CopyBuffer(atr,0,0,20,a); IndicatorRelease(atr);
            if(n>=5){ double now=a[0]; double avg=0; for(int i=1;i<n;i++) avg+=a[i]; avg/=MathMax(1,n-1); if(!(now >= InpATRBoostMin * MathMax(1e-8, avg))) return false; }
        }
        // 5) Favorable distance to recent pivot in direction (avoid entering right into nearby opposite pivot)
        MqlRates r[]; if(CopyRates(_Symbol, PERIOD_M5, 0, 50, r)<20) return false;
        double lastHigh=r[1].high, lastLow=r[1].low;
        for(int i=2;i<=10;i++){ if(r[i].high>lastHigh) lastHigh=r[i].high; if(r[i].low<lastLow) lastLow=r[i].low; }
        double price = (direction>0)? SymbolInfoDouble(_Symbol, SYMBOL_ASK):SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double distOpp = (direction>0)? (lastHigh-price) : (price-lastLow);
        // must have at least 0.5 * ATR(M5) room
        int atr5 = iATR(_Symbol, PERIOD_M5, 14); if(atr5!=INVALID_HANDLE){ double aa[2]; if(CopyBuffer(atr5,0,0,2,aa)>=1){ if(distOpp < 0.5*aa[0]){ IndicatorRelease(atr5); return false; } } IndicatorRelease(atr5); }
        return true;
    }
    bool DetectPreSpike(MqlRates &rates[], int &outDir, int &outConf)
    {
        outDir = 0; outConf = 0;
        // Bollinger bandwidth (compression)
        if(m_bbHandle == INVALID_HANDLE) return false;
        double up[2], mid[2], lo[2];
        if(CopyBuffer(m_bbHandle,0,0,2,up)<2 || CopyBuffer(m_bbHandle,1,0,2,mid)<2 || CopyBuffer(m_bbHandle,2,0,2,lo)<2) return false;
        double bbw = (up[0]-lo[0]) / MathMax(1e-8, mid[0]);
        double bbwPrev = (up[1]-lo[1]) / MathMax(1e-8, mid[1]);
        bool compressed = (bbw < bbwPrev && bbw < 0.012);

        // ATR boost
        int atr = iATR(_Symbol, PERIOD_M1, InpATRShort);
        if(atr == INVALID_HANDLE) return false;
        double a[20]; int n=CopyBuffer(atr,0,0,ArraySize(a),a); IndicatorRelease(atr);
        if(n < 5) return false;
        double atrNow=a[0]; double atrAvg=0; for(int i=1;i<n;i++) atrAvg += a[i]; atrAvg/=MathMax(1,n-1);
        bool atrBoost = (atrNow >= InpATRBoostMin * MathMax(1e-8, atrAvg));

        // Wick/body of previous candle
        double body = MathAbs(rates[1].close - rates[1].open);
        double upper = rates[1].high - MathMax(rates[1].close, rates[1].open);
        double lower = MathMin(rates[1].close, rates[1].open) - rates[1].low;
        bool longUp = body>0 && (upper/body >= InpWickRatioMin);
        bool longDn = body>0 && (lower/body >= InpWickRatioMin);

        int dir = 0; if(longDn) dir=1; else if(longUp) dir=-1;
        int conf = 0; if(dir!=0){ conf += compressed?30:0; conf += atrBoost?30:0; conf += 40; }

        if(dir!=0 && conf >= InpPreSpikeMinConfidence) { outDir=dir; outConf=conf; return true; }
        return false;
    }

    // Anticipation touche EMA10: si prix actuel est à <= k*ATR de l'EMA10
    bool DetectPreSpikeEMATouch(MqlRates &rates[], int &outDir, int &outConf)
    {
        outDir = 0; outConf = 0;
        // Handles EMA10 et ATR(M1)
        int ema10 = iMA(_Symbol, PERIOD_M1, 10, 0, MODE_EMA, PRICE_CLOSE);
        if(ema10==INVALID_HANDLE) return false;
        int atr = iATR(_Symbol, PERIOD_M1, MathMax(5, InpATRShort));
        if(atr==INVALID_HANDLE) { IndicatorRelease(ema10); return false; }
        double e[2]; double a[2];
        bool okE = (CopyBuffer(ema10,0,0,2,e)>=1); bool okA = (CopyBuffer(atr,0,0,2,a)>=1);
        IndicatorRelease(ema10); IndicatorRelease(atr);
        if(!okE || !okA) return false;
        double ema = e[0]; double atrNow = a[0];

        // Prix de référence et direction Boom/Crash
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        bool isBoom = (StringFind(_Symbol, "Boom")>=0);
        bool isCrash= (StringFind(_Symbol, "Crash")>=0);

        // Distance actuelle à EMA10
        double distBuy  = MathAbs(ask - ema);
        double distSell = MathAbs(bid - ema); // Fixed: ensure positive distance
        double maxDist  = InpEMAApproachATRMult * MathMax(1e-8, atrNow);

        // Si Boom: chercher BUY quand prix approche EMA10 depuis au-dessus (pullback)
        if(isBoom && distBuy <= maxDist)
        {
            outDir = 1; outConf = 60; // base
            // Bonus de confiance si escalier actif
            if(IsStaircasePatternM1()) outConf += 20;
            return true;
        }
        // Si Crash: chercher SELL quand prix approche EMA10 depuis en-dessous
        if(isCrash && distSell <= maxDist)
        {
            outDir = -1; outConf = 60;
            if(IsStaircasePatternM1()) outConf += 20;
            return true;
        }
        return false;
    }
    bool IsConsolidation(MqlRates &rates[]) {
        double recentRange = 0;
        double oldRange = 0;
        
        // Analyser les bougies 2-6 (récentes)
        for(int i = 2; i <= 6; i++) {
            recentRange += (rates[i].high - rates[i].low);
        }
        
        // Analyser les bougies 7-12 (anciennes)
        for(int i = 7; i <= 12; i++) {
            oldRange += (rates[i].high - rates[i].low);
        }
        
        return (recentRange < oldRange * InpConsolidationThreshold);
    }
    
    bool HasLongWicks(MqlRates &rates[]) {
        int longWicks = 0;
        
        for(int i = 2; i <= 8; i++) {
            double bodySize = MathAbs(rates[i].close - rates[i].open);
            double upperWick = rates[i].high - MathMax(rates[i].open, rates[i].close);
            double lowerWick = MathMin(rates[i].open, rates[i].close) - rates[i].low;
            
            if(bodySize > 0) {
                double wickRatio = MathMax(upperWick, lowerWick) / bodySize;
                if(wickRatio > InpWickRatioThreshold) {
                    longWicks++;
                }
            }
        }
        
        return (longWicks >= 2);
    }
    
    bool IsVolatilityIncreasing(MqlRates &rates[]) {
        double recentVolatility = 0;
        double oldVolatility = 0;
        
        // Volatilité récente (bougies 2-6)
        for(int i = 2; i <= 6; i++) {
            recentVolatility += (rates[i].high - rates[i].low);
        }
        
        // Volatilité ancienne (bougies 7-12)
        for(int i = 7; i <= 12; i++) {
            oldVolatility += (rates[i].high - rates[i].low);
        }
        
        return (recentVolatility > oldVolatility * InpVolatilityThreshold);
    }
    
    int AnalyzeDirection(MqlRates &rates[]) {
        // Analyser la tendance récente
        double recentClose = rates[1].close;
        double oldClose = rates[5].close;
        int dir = 0;
        if(recentClose > oldClose) dir = 1; else if(recentClose < oldClose) dir = -1;
        
        // Exiger l'alignement de tendance si demandé
        if(InpRequireTrendAlign)
        {
            int trend = CSignalValidator::GetTrendDirection(InpTrendTF);
            if(trend != dir) return 0;
        }
        
        // Score de confiance simple (0-100): volatilité et cohérence
        int score = 0;
        score += IsConsolidation(rates) ? 30 : 0;
        score += HasLongWicks(rates) ? 30 : 0;
        score += IsVolatilityIncreasing(rates) ? 40 : 0;
        // Booster la préférence Boom/Crash
        if(InpPreferBoomCrash && IsBoomCrashIndex(_Symbol)) score += InpBoomCrashConfidenceBoost;
        if(InpPreferBoomCrash && !IsBoomCrashIndex(_Symbol)) score -= InpNonBoomCrashPenalty;
        if(score < InpMinEdgeConfidence) return 0;
        
        // VÉRIFICATION FINALE: Le signal doit être dans le sens de la tendance M5 et M1
        if(dir != 0) {
            int trendM5 = CSignalValidator::GetTrendDirection(PERIOD_M5);
            int trendM1 = CSignalValidator::GetTrendDirection(PERIOD_M1);
            
            if((dir > 0 && (trendM5 <= 0 || trendM1 <= 0)) || 
               (dir < 0 && (trendM5 >= 0 || trendM1 >= 0))) {
                Print("?? SIGNAL DÉTECTÉ MAIS CONTRE TENDANCE - Ignoré (Signal: ", dir, " vs M5: ", trendM5, " M1: ", trendM1, ")");
                return 0;
            }
        }
        
        return dir; // 1 ou -1
    }
    
    //+------------------------------------------------------------------+
    //| Vérifier si le trade est valide                                  |
    //+------------------------------------------------------------------+
    static bool ValidateSignal(int direction) {
        // Vérifier d'abord la configuration soikje
        if(!g_riskManager.HasHighProbabilitySoikjePattern()) {
            Print("Signal rejeté: Aucun modèle soikje valide détecté");
            return false;
        }
        
        // Vérifier l'alignement temporel si nécessaire
        if(!InpUseMultiTimeframe && !InpUseSupportResistance) {
            return true;
        }
        
        // Obtenir les données des bougies
        MqlRates rates[];
        if(CopyRates(_Symbol, PERIOD_M1, 0, InpLookbackPeriod, rates) < InpLookbackPeriod) {
            return 0.0;
        }
        
        double confidence = 0.0;
        
        // Filtre spread: ne pas trader si spread trop élevé
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int spreadPts = (int)MathRound((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))/MathMax(pt,1e-12));
        if(spreadPts > InpMaxSpreadPoints) return 0.0;
        
        // Pré-spike Boom/Crash: compression + ATR boost + mèches
        if(InpEnablePreSpike && IsBoomCrashIndex(_Symbol)) {
            int dir = 0; int conf = 0;
            if(DetectPreSpike(rates, dir, conf)) {
                confidence += conf;
            }
        }
        
        // Pré-signal EMA10: approche imminente de l'EMA10 en M1
        if(InpEnableEMATouchPreSpike && IsBoomCrashIndex(_Symbol)) {
            int dirEMA = 0; int confEMA = 0;
            if(DetectPreSpikeEMATouch(rates, dirEMA, confEMA)) {
                confidence += confEMA;
            }
        }
        
        // Pattern escalier M1
        if(IsStaircasePatternM1()) {
            confidence += 30;
        }
        
        // Score de confiance basé sur les conditions techniques (base)
        int score = 20; // Score de base
        confidence += score;

        // Ajout score ICT (BOS/COS, OTE/Fibonacci, PA, Trend MTF)
        if(InpEnableICT)
        {
            int ictScore = 0;
            if(InpICTUseBOSCOS)       ictScore += DetectICTStructureScore(rates);
            if(InpICTUseOTE && InpICTUseFibonacci) ictScore += DetectICTOTEScore(rates);
            if(InpICTUsePriceAction)  ictScore += DetectICTPriceActionScore(rates);
            if(InpICTUseTrendMTF)     ictScore += DetectICTTrendScore();
            if(ictScore > 60) ictScore = 60; // Cap ICT
            confidence += ictScore;
        }
        
        // Booster la préférence Boom/Crash
        if(InpPreferBoomCrash && IsBoomCrashIndex(_Symbol)) confidence += InpBoomCrashConfidenceBoost;
        if(InpPreferBoomCrash && !IsBoomCrashIndex(_Symbol)) confidence -= InpNonBoomCrashPenalty;
        
        // Limiter la confiance entre 0 et 100
        if(confidence < 0) confidence = 0;
        if(confidence > 100) confidence = 100;
        
        return confidence;
    }
};

class CSignalValidator {
public:
    static bool ValidateSignal(int direction) {
        if(!InpUseMultiTimeframe && !InpUseSupportResistance) {
            return true;
        }
        
        int confidence = 0;
        
        // Validation multi-timeframe
        if(InpUseMultiTimeframe) {
            confidence += ValidateMultiTimeframe(direction);
        }
        
        // Validation Support/Résistance
        if(InpUseSupportResistance) {
            confidence += ValidateSupportResistance();
        }
        
        if(confidence < InpMinConfidence) return false;
        // Exiger proximité zone S/R si demandé
        if(InpRequireZoneProximity && InpDrawMTFZones)
        {
            double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(!IsNearAnyMTFZone(px, direction)) return false;
        }
        return true;
    }
    
    // Interdire contre-tendance M1 et M5 pour Boom/Crash
    static bool IsAlignedWithM1M5(int direction)
    {
        if(direction==0) return false;
        bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
        bool isCrash= (StringFind(_Symbol, "Crash")>= 0);

        // M1 Check
        int emaF1 = iMA(_Symbol, PERIOD_M1, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        int emaS1 = iMA(_Symbol, PERIOD_M1, MathMax(3, InpEMASlow), 0, MODE_EMA, PRICE_CLOSE);
        if(emaF1 == INVALID_HANDLE || emaS1 == INVALID_HANDLE) { if(emaF1!=INVALID_HANDLE) IndicatorRelease(emaF1); if(emaS1!=INVALID_HANDLE) IndicatorRelease(emaS1); return false; }
        double f1[2], s1[2]; bool ok1 = (CopyBuffer(emaF1,0,0,2,f1)>=2 && CopyBuffer(emaS1,0,0,2,s1)>=2); IndicatorRelease(emaF1); IndicatorRelease(emaS1);
        if(!ok1) return false;
        int dir1 = (f1[0]>s1[0])?1:((f1[0]<s1[0])?-1:0);

        // M5 Check
        int emaF5 = iMA(_Symbol, PERIOD_M5, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        int emaS5 = iMA(_Symbol, PERIOD_M5, MathMax(3, InpEMASlow), 0, MODE_EMA, PRICE_CLOSE);
        if(emaF5 == INVALID_HANDLE || emaS5 == INVALID_HANDLE) { if(emaF5!=INVALID_HANDLE) IndicatorRelease(emaF5); if(emaS5!=INVALID_HANDLE) IndicatorRelease(emaS5); return false; }
        double f5[2], s5[2]; bool ok5 = (CopyBuffer(emaF5,0,0,2,f5)>=2 && CopyBuffer(emaS5,0,0,2,s5)>=2); IndicatorRelease(emaF5); IndicatorRelease(emaS5);
        if(!ok5) return false;
        int dir5 = (f5[0]>s5[0])?1:((f5[0]<s5[0])?-1:0);

        // General Trend Alignment Check
        if(dir1 != direction || dir5 != direction) return false;

        // Boom/Crash specific checks
        if(isBoom)
        {
            if(direction < 0) return false; // No SELL on Boom
            // If M1 or M5 trend is against the desired BUY direction
            if(dir1 < 0 || dir5 < 0) return false;
        }
        else if(isCrash)
        {
            if(direction > 0) return false; // No BUY on Crash
            // If M1 or M5 trend is against the desired SELL direction
            if(dir1 > 0 || dir5 > 0) return false;
        }

        return true;
    }
private:
    static int ValidateMultiTimeframe(int direction) {
        int alignedTimeframes = 0;
        // D1, H4, H1, M30, M15
        ENUM_TIMEFRAMES timeframes[] = {PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15};
        
        for(int i = 0; i < ArraySize(timeframes); i++) {
            if(IsTimeframeAligned(timeframes[i], direction)) {
                alignedTimeframes++;
            }
        }
        
        return (alignedTimeframes * 20); // 5 TFs -> 100% max
    }
    
    static bool IsTimeframeAligned(ENUM_TIMEFRAMES timeframe, int direction) {
        // EMA-based trend alignment
        int emaFast = iMA(_Symbol, timeframe, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        int emaSlow = iMA(_Symbol, timeframe, MathMax(3, InpEMASlow), 0, MODE_EMA, PRICE_CLOSE);
        if(emaFast == INVALID_HANDLE || emaSlow == INVALID_HANDLE) { if(emaFast!=INVALID_HANDLE) IndicatorRelease(emaFast); if(emaSlow!=INVALID_HANDLE) IndicatorRelease(emaSlow); return false; }
        double f[2], s[2];
        bool ok = (CopyBuffer(emaFast, 0, 0, 2, f) >= 2 && CopyBuffer(emaSlow, 0, 0, 2, s) >= 2);
        IndicatorRelease(emaFast);
        IndicatorRelease(emaSlow);
        if(!ok) return false;
        int tfDir = (f[0] > s[0]) ? 1 : (f[0] < s[0] ? -1 : 0);
        return (tfDir == direction);
    }
    
    static int ValidateSupportResistance() {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double proximityThreshold = InpSRProximityPercent / 100.0;
        
        // Analyser les niveaux récents
        MqlRates rates[];
        if(CopyRates(_Symbol, PERIOD_M1, 0, 50, rates) < 50) return 0;
        
        int nearLevels = 0;
        for(int i = 10; i < 50; i++) {
            double high = rates[i].high;
            double low = rates[i].low;
            
            if(MathAbs(currentPrice - high) / currentPrice <= proximityThreshold ||
               MathAbs(currentPrice - low) / currentPrice <= proximityThreshold) {
                nearLevels++;
            }
        }
        
        return (nearLevels >= 2) ? 50 : 0; // 50% si près de S/R
    }
    
    // Déterminer la direction de tendance via EMA croisée
public:
    static int GetTrendDirection(ENUM_TIMEFRAMES tf)
    {
        int emaFast = iMA(_Symbol, tf, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        int emaSlow = iMA(_Symbol, tf, MathMax(3, InpEMASlow), 0, MODE_EMA, PRICE_CLOSE);
        if(emaFast == INVALID_HANDLE || emaSlow == INVALID_HANDLE) return 0;
        double f[2], s[2];
        bool ok = (CopyBuffer(emaFast, 0, 0, 2, f) >= 2 && CopyBuffer(emaSlow, 0, 0, 2, s) >= 2);
        IndicatorRelease(emaFast);
        IndicatorRelease(emaSlow);
        if(!ok) return 0;
        if(f[0] > s[0]) return 1;     // tendance haussière
        if(f[0] < s[0]) return -1;    // tendance baissière
        return 0;
    }

    // GOD Mode composite score (0-100). Uses strict confluence of factors.
    static int ComputeGodScore(const int direction)
    {
        if(direction==0) return 0;
        int score = 0;

        // 1) Multi-timeframe alignment: require N TFs aligned
        ENUM_TIMEFRAMES tfs[] = {PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15};
        int aligned = 0;
        for(int i=0;i<ArraySize(tfs);i++)
            if(IsTimeframeAligned(tfs[i], direction)) aligned++;
        if(aligned >= MathMax(1, InpGodTFsRequired))
            score += MathMin(40, 10*aligned); // up to 50 but cap at 40 for balance

        // 2) A+ environment (ADX, EMA slope, ATR momentum, pivots room)
        // Reuse private helper by proxy: check using public gate ValidateSignal prerequisites
        // Here we partially re-run core checks inline to avoid private method access
        int trend = GetTrendDirection(InpTrendTF);
        if(trend==direction) score += 10;
        // ADX M15
        int adx = iADX(_Symbol, PERIOD_M15, 14);
        if(adx!=INVALID_HANDLE){ double a[2]; if(CopyBuffer(adx,0,0,2,a)>=1){ if(a[0] >= MathMax(5, InpMinADX)) score += 10; } IndicatorRelease(adx); }
        // EMA slope H1 in direction
        int emaF = iMA(_Symbol, PERIOD_H1, MathMax(2, InpEMAFast), 0, MODE_EMA, PRICE_CLOSE);
        if(emaF!=INVALID_HANDLE){ double f[6]; if(CopyBuffer(emaF,0,0,6,f)>=5){ double pt=SymbolInfoDouble(_Symbol,SYMBOL_POINT); double slope=(f[0]-f[5])/MathMax(pt,1e-12); if((direction>0 && slope>=InpMinEMASlopePoints) || (direction<0 && slope<=-InpMinEMASlopePoints)) score += 10; } IndicatorRelease(emaF);}
        
        // 3) Momentum via ATR(M1): now >= k * average over lookback
        int look = MathMax(10, InpGodATRLookback);
        int atrH = iATR(_Symbol, PERIOD_M1, MathMax(5, InpATRShort));
        if(atrH!=INVALID_HANDLE)
        {
            double arr[180]; int n=CopyBuffer(atrH,0,0,MathMin(look+1,ArraySize(arr)),arr); IndicatorRelease(atrH);
            if(n>=look){ double now=arr[0]; double avg=0; for(int i=1;i<look;i++) avg+=arr[i]; avg/=MathMax(1,look-1); if(now >= InpGodATRBoostMin * MathMax(1e-8, avg)) score += 10; }
        }
        
        // 4) SR proximity coherence
        if(InpDrawMTFZones && InpGodRequireSRNear)
        {
            double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(IsNearAnyMTFZone(px, direction)) score += 10;
        }

        // 5) Spread gate: rewards tight spread
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int spreadPts = (int)MathRound((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID))/MathMax(pt,1e-12));
        if(spreadPts <= MathMax(3, InpMaxSpreadPoints/3)) score += 10;

        // Cap 0..100
        if(score<0) score=0; if(score>100) score=100; return score;
    }
};

class CTradeExecutor {
private:
    CTrade m_trade;
    
    bool PlacePendingLimit(const int direction, const double entryPrice, double slPrice, double tpPrice)
    {
        // Validate inputs
        if(direction==0 || entryPrice<=0.0) return false;
        ENUM_ORDER_TYPE type = (direction>0)? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
        double lotSize = CalculateValidLotSize(); if(lotSize<=0) return false;
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

        // Ensure SL/TP are on the correct side and respect minimum distance from ENTRY (not market price)
        if(slPrice>0 || tpPrice>0)
        {
            double tmpSL = slPrice; double tmpTP = tpPrice;
            EnsureValidStops(_Symbol, direction, entryPrice, pt, tmpSL, tmpTP);
            slPrice = tmpSL; tpPrice = tmpTP;
        }

        // Expiration
        datetime expiry = TimeCurrent() + MathMax(30, InpAIPendingExpirySec);

        // Submit pending order request directly
        {
            MqlTradeRequest rq; MqlTradeResult rs; 
            rq.action = TRADE_ACTION_PENDING;
            rq.symbol = _Symbol;
            rq.type = type;
            rq.price = NormalizeDouble(entryPrice, digits);
            rq.sl = (slPrice>0.0)? NormalizeDouble(slPrice, digits) : 0.0;
            rq.tp = (tpPrice>0.0)? NormalizeDouble(tpPrice, digits) : 0.0;
            rq.volume = lotSize;
            rq.type_filling = ORDER_FILLING_RETURN;
            rq.type_time = ORDER_TIME_SPECIFIED;
            rq.expiration = expiry;
            rq.deviation = 10;
            rq.magic = InpMagicNumber;
            rq.comment = "AI_LIMIT";
            if(!OrderSend(rq, rs))
            {
                Print("? Echec LIMIT IA: ", GetLastError(), " / ", rs.comment);
                return false;
            }
            Print("? LIMIT IA placé: ", (direction>0?"BUY_LIMIT":"SELL_LIMIT"), " @ ", DoubleToString(rq.price,digits),
                  " SL=", (rq.sl>0? DoubleToString(rq.sl,digits):"0"), " TP=", (rq.tp>0?DoubleToString(rq.tp,digits):"0"));
            return true;
        }
    }
    void DrawOrderLine(const string name, const double price, const color c)
    {
        datetime t0, t1; GetChartTimeWindow(t0, t1);
        if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
        if(ObjectCreate(0, name, OBJ_TREND, 0, t0, price, t1, price))
        {
            ObjectSetInteger(0, name, OBJPROP_COLOR, c);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
        }
    }
    
public:
    CTradeExecutor() {
        m_trade.SetExpertMagicNumber(InpMagicNumber);
        m_trade.SetDeviationInPoints(10);
        m_trade.SetTypeFilling(ORDER_FILLING_FOK);
    }
    
    // Compute trend direction on given TF: >0 uptrend, <0 downtrend, 0 neutral
    static int GetTrendDirection(const ENUM_TIMEFRAMES tf)
    {
        int emaP = MathMax(5, InpEMAPeriod);
        int handle = iMA(_Symbol, tf, emaP, 0, MODE_EMA, PRICE_CLOSE);
        if(handle==INVALID_HANDLE) return 0;
        double buf[12]; int n = CopyBuffer(handle, 0, 0, ArraySize(buf), buf); IndicatorRelease(handle);
        if(n < 11) return 0;
        double emaNow = buf[0]; double emaPrev10 = buf[10];
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double slopePts = (emaNow - emaPrev10) / MathMax(pt,1e-12);
        if(MathAbs(slopePts) < MathMax(1, InpMinEMASlopePips*10)) return 0;
        int adxH = iADX(_Symbol, tf, MathMax(5, InpADXPeriod));
        if(adxH!=INVALID_HANDLE)
        {
            double adx[2]; if(CopyBuffer(adxH,2,0,2,adx)>=1) { if(adx[0] < InpMinADX) return 0; }
            IndicatorRelease(adxH);
        }
        return (slopePts>0)? 1 : -1;
    }
    
    bool ExecuteTrade(int direction) {
        if(direction == 0) return false;
        
        // Vérifier la configuration soikje avant d'exécuter le trade
        if(!HasHighProbabilitySoikjePattern()) {
            Print("Exécution de trade annulée: Configuration soikje non valide");
            return false;
        }
        
        // VÉRIFICATION STRICTE: Maximum 1 position simultanée pour ce symbole
        int currentPositions = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                currentPositions++;
            }
        }
        
        if(currentPositions >= 2) {
            Print("?? EXECUTE TRADE BLOQUÉ - ", currentPositions, " positions déjà ouvertes (MAXIMUM: 2)");
            return false;
        }
        
        // ENCOURAGER: Trades sur volatilités, step index et forex
        bool isVolatility = IsVolatilityIndex(_Symbol);
        bool isStepIndex = IsStepIndex(_Symbol);
        bool isForex = IsForexSymbol(_Symbol);
        
        if(isVolatility || isStepIndex || isForex) {
            Print("? SYMBOL FAVORI - ", _Symbol, " (", 
                  (isVolatility ? "Volatilité" : ""), 
                  (isStepIndex ? "Step Index" : ""), 
                  (isForex ? "Forex" : ""), ") - Trade encouragé");
        }
        
        // Vérifier le cooldown après perte avant d'ouvrir une nouvelle position
        if(IsSymbolInCooldown(_Symbol)) {
            Print("? COOLDOWN ACTIF - Attente d'une opportunité confirmée sur ", _Symbol);
            return false;
        }
        
        // Vérifier les pertes consécutives pour ce symbole
        if(IsSymbolInConsecutiveLossCooldown(_Symbol)) {
            Print("?? SYMBOLE ", _Symbol, " EN COOLDOWN après ", InpMaxConsecutiveLosses, " pertes consécutives");
            return false;
        }
        
        // Vérifier la limite globale de positions simultanées
        if(IsGlobalPositionLimitReached()) {
            return false;
        }
        
        double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                                          SymbolInfoDouble(_Symbol, SYMBOL_BID);
        
        // Calculer le Stop Loss adaptatif
        double sl_points = CalculateAdaptiveStopLoss(_Symbol, price, direction);
        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        double sl_price = (direction > 0) ? price - (sl_points * point) : price + (sl_points * point);
        // Sniper: limiter la distance SL par risque $ si activé
        if(InpSniperMode && InpSniperMaxLossUSD>0.0)
        {
            double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
            double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
            double dollarPerPointPerLot = 0.0;
            if(tickSize>0.0 && point>0.0) dollarPerPointPerLot = tickValue * (point / tickSize);
            double lotPreview = CalculateValidLotSize(); if(lotPreview<=0) lotPreview = 0.20;
            if(dollarPerPointPerLot>0.0)
            {
                double maxPts = (InpSniperMaxLossUSD / MathMax(1e-8, dollarPerPointPerLot)) / MathMax(1e-8, lotPreview);
                double maxPtsClamped = MathMax(1.0, MathMin(sl_points, maxPts));
                sl_points = maxPtsClamped;
                sl_price = (direction>0)? price - sl_points*point : price + sl_points*point;
            }
        }
        
        // Calculer la taille de lot intelligente
        // Fixer le lot à 0.20 pour Boom/Crash, sinon utiliser la logique existante
        double lotSize;
        if(IsBoomCrashIndex(_Symbol)) {
            lotSize = 0.20; // Minimum absolu pour Boom/Crash
            double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            if(minLot > 0.20) lotSize = minLot; // Utiliser le minLot du broker si plus élevé
        } else {
            lotSize = CalculateValidLotSize();
            double lotRaw = lotSize;
            if(InpUseSmartTrading) lotRaw = CalculateSmartLotSize(_Symbol, price, sl_price);
            lotSize = SnapLotToSymbol(_Symbol, lotRaw);
        }
        
        if(lotSize <= 0) {
            Print("? Lot size invalide: ", lotSize);
            return false;
        }
        
        // Calculer le Take Profit dynamique
        double tp_points = CalculateDynamicTakeProfit(_Symbol, price, direction, sl_price);
        double tp_price = (direction > 0) ? price + (tp_points * point) : price - (tp_points * point);
        
        // Vérifier le ratio risque/récompense
        double risk_reward_ratio = tp_points / sl_points;
        if(risk_reward_ratio < InpMinRiskRewardRatio) {
            Print("?? Ratio risque/récompense insuffisant: ", DoubleToString(risk_reward_ratio, 2), " < ", DoubleToString(InpMinRiskRewardRatio, 2));
            // Ajuster le TP pour respecter le ratio minimum
            tp_points = sl_points * InpMinRiskRewardRatio;
            tp_price = (direction > 0) ? price + (tp_points * point) : price - (tp_points * point);
        }
        
        EnsureValidStops(_Symbol, direction, price, point, sl_price, tp_price);
        bool result = (direction>0)? m_trade.Buy(lotSize, _Symbol, price, sl_price, tp_price, "SpikeHunter Smart")
                                   : m_trade.Sell(lotSize, _Symbol, price, sl_price, tp_price, "SpikeHunter Smart");

        // Si échec, tenter ajustements anti "request failed"
        if(!result)
        {
            int err = (int)m_trade.ResultRetcode();
            Print("?? Échec envoi ordre (retcode=", err, ") ? tentative d'ajustement.");
            // 1) Nudge SL/TP légèrement et réessayer
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double nudgePts = MathMax(1, InpStopsBufferPoints);
            double sl_adj = sl_price;
            double tp_adj = tp_price;
            if(direction > 0) { if(sl_price>0) sl_adj = sl_price - nudgePts*point; if(tp_price>0) tp_adj = tp_price + nudgePts*point; }
            else              { if(sl_price>0) sl_adj = sl_price + nudgePts*point; if(tp_price>0) tp_adj = tp_price - nudgePts*point; }
            if(direction > 0) result = m_trade.Buy(lotSize, _Symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            else              result = m_trade.Sell(lotSize, _Symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            // 2) Si toujours KO, augmenter le volume de 0.2 et réessayer
            if(!result)
            {
                double lot_up = SnapLotToSymbol(_Symbol, lotSize + 0.20);
                if(direction > 0) result = m_trade.Buy(lot_up, _Symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
                else              result = m_trade.Sell(lot_up, _Symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            }
            // 3) Derniers recours: enlever TP puis SL
            if(!result)
            {
                double tp_try = 0.0;
                if(direction > 0) result = m_trade.Buy(lotSize, _Symbol, price, sl_adj, tp_try, "SpikeHunter Smart");
                else              result = m_trade.Sell(lotSize, _Symbol, price, sl_adj, tp_try, "SpikeHunter Smart");
            }
            if(!result)
            {
                double sl_try = 0.0; double tp_try2 = 0.0;
                if(direction > 0) result = m_trade.Buy(lotSize, _Symbol, price, sl_try, tp_try2, "SpikeHunter Smart");
                else              result = m_trade.Sell(lotSize, _Symbol, price, sl_try, tp_try2, "SpikeHunter Smart");
            }
        }
        
        if(result) {
            // Ajouter au système de trading intelligent
            if(InpUseSmartTrading) {
                ulong ticket = m_trade.ResultOrder();
                AddSmartTrade(ticket, price, lotSize, direction, sl_price, tp_price);
            }
            
            Print("?? TRADE INTELLIGENT EXÉCUTÉ: ", (direction > 0 ? "BUY" : "SELL"),
                  " | Lot: ", DoubleToString(lotSize, 2),
                  " | SL: ", DoubleToString(sl_points, 1), " pts",
                  " | TP: ", DoubleToString(tp_points, 1), " pts",
                  " | Ratio R/R: ", DoubleToString(risk_reward_ratio, 2));
            
            // Dessiner lignes SL/TP si disponibles
            if(tp_price>0) DrawOrderLine(StringFormat("TP_%s_%d", _Symbol, (int)TimeCurrent()), tp_price, clrGreen);
            if(sl_price>0) DrawOrderLine(StringFormat("SL_%s_%d", _Symbol, (int)TimeCurrent()), sl_price, clrTomato);

            if(InpSendNotifications) {
                string side = (direction > 0 ? "BUY" : "SELL");
                string msg = StringFormat("SpikeHunter Smart: Trade %s exécuté", side);
                NotifyOnce(msg);
            }
            
            if(InpPlaySounds) {
                PlaySound(InpSoundFile);
            }
        } else {
            // Gestion des erreurs de trade (par exemple, stops invalides)
            // Comme on n'a pas le droit de modifier, on se contente de loguer l'erreur.
            Print("? ÉCHEC TRADE: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
        }
        
        return result;
    }
    
    bool ExecuteTradeOnSymbol(const string symbol, const int direction)
    {
        if(direction==0) return false;
        
        // ENCOURAGER: Trades sur volatilités, step index et forex
        bool isVolatility = IsVolatilityIndex(symbol);
        bool isStepIndex = IsStepIndex(symbol);
        bool isForex = IsForexSymbol(symbol);
        
        if(isVolatility || isStepIndex || isForex) {
            Print("? SYMBOL FAVORI - ", symbol, " (", 
                  (isVolatility ? "Volatilité" : ""), 
                  (isStepIndex ? "Step Index" : ""), 
                  (isForex ? "Forex" : ""), ") - Trade encouragé");
        }
        
        // Vérifier le cooldown après perte avant d'ouvrir une nouvelle position
        if(IsSymbolInCooldown(symbol)) {
            Print("? COOLDOWN ACTIF - Attente d'une opportunité confirmée sur ", symbol);
            return false;
        }
        
        // Vérifier les pertes consécutives pour ce symbole
        if(IsSymbolInConsecutiveLossCooldown(symbol)) {
            Print("?? SYMBOLE ", symbol, " EN COOLDOWN après ", InpMaxConsecutiveLosses, " pertes consécutives");
            return false;
        }
        
        // Vérifier la limite globale de positions simultanées
        if(IsGlobalPositionLimitReached()) {
            return false;
        }
        
        double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
        double price = (direction>0)? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
        if(point<=0 || price<=0) return false;

        int stops = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
        int bufferPts = MathMax(0, InpStopsBufferPoints);
        if(IsBoomCrashIndex(symbol)) { stops = (int)MathCeil(stops*MathMax(1.0, InpBoomCrashStopsMultiplier)); bufferPts = (int)MathCeil(bufferPts*MathMax(1.0, InpBoomCrashStopsMultiplier)); }
        int minPts = MathMax(1, stops + bufferPts);
        double sl_points = MathMax((double)InpStopLoss, (double)minPts);
        double sl_price = (direction>0)? price - sl_points*point : price + sl_points*point;

        double tp_points = CalculateDynamicTakeProfit(symbol, price, direction, sl_price);
        double tp_price = (direction>0)? price + tp_points*point : price - tp_points*point;
        double risk_reward_ratio = tp_points / sl_points;
        if(risk_reward_ratio < InpMinRiskRewardRatio)
        {
            tp_points = sl_points * InpMinRiskRewardRatio;
            tp_price = (direction>0)? price + tp_points*point : price - tp_points*point;
        }

        double lotSize = (IsBoomCrashIndex(symbol))? 0.20 : CalculateSmartLotSize(symbol, price, sl_price);
        if(lotSize<=0) return false;

        bool result = (direction>0)? m_trade.Buy(lotSize, symbol, price, sl_price, tp_price, "SpikeHunter Smart")
                                   : m_trade.Sell(lotSize, symbol, price, sl_price, tp_price, "SpikeHunter Smart");
        if(!result)
        {
            double nudgePts = MathMax(1, InpStopsBufferPoints);
            double sl_adj = sl_price, tp_adj = tp_price;
            if(direction>0){ if(sl_price>0) sl_adj-=nudgePts*point; if(tp_price>0) tp_adj+=nudgePts*point; }
            else            { if(sl_price>0) sl_adj+=nudgePts*point; if(tp_price>0) tp_adj-=nudgePts*point; }
            result = (direction>0)? m_trade.Buy(lotSize, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart")
                                  : m_trade.Sell(lotSize, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            if(!result)
            {
                double lot_up = lotSize + 0.20; if(IsBoomCrashIndex(symbol)) lot_up = SnapToDerivBoomCrashLots(lot_up);
                result = (direction>0)? m_trade.Buy(lot_up, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart")
                                      : m_trade.Sell(lot_up, symbol, price, sl_adj, tp_adj, "SpikeHunter Smart");
            }
        }
        return result;
    }
    
public:
    bool ExecutePendingFromAI(const int direction, const double entryPrice, const double slPrice, const double tpPrice)
    {
        if(!InpAIEnablePendingOrders) return false;
        return PlacePendingLimit(direction, entryPrice, slPrice, tpPrice);
    }
    
private:
    void ComputeDynamicSLTP(const int direction, const double entryPrice, double &outSL, double &outTP)
    {
        // Important: Conformément à la règle "pas autorisé à modifier une position en cours",
        // nous calculons SL/TP une seule fois à l'ouverture et ils ne seront jamais modifiés.
        // Le code qui suit est une adaptation pour calculer un SL/TP initial SANS modification ultérieure.

        double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        int stops = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
        int bufferPts = MathMax(0, InpStopsBufferPoints);
        if(IsBoomCrashIndex(_Symbol)) {
            // multiplier les stops et buffer pour éviter invalid stops sur Boom/Crash
            stops = (int)MathCeil(stops * MathMax(1.0, InpBoomCrashStopsMultiplier));
            bufferPts = (int)MathCeil(bufferPts * MathMax(1.0, InpBoomCrashStopsMultiplier));
        }
        int minPts = MathMax(1, stops + bufferPts);
        
        // Base SL/TP from inputs
        double baseSLptsInput = MathMax((double)InpStopLoss, (double)minPts);
        double baseTPptsInput = MathMax((double)InpTakeProfit, (double)minPts*2);

        // ATR-based distances for initial SL/TP
        double atrDistPoints = 0.0;
        if(InpUseATRForSLTP)
        {
            int atr = iATR(_Symbol, PERIOD_M1, MathMax(5, InpATRPeriod));
            if(atr != INVALID_HANDLE)
            {
                double a[2];
                if(CopyBuffer(atr, 0, 0, 2, a) >= 1)
                {
                    double atrValue = a[0];
                    if(atrValue > 0)
                {
                    // Convert ATR (in price) to points
                        double atrPoints = atrValue / MathMax(point, 1e-12);
                    atrDistPoints = MathMax(atrPoints, minPts);
                    }
                }
                IndicatorRelease(atr);
            }
        }
        
        // Determine final initial SL/TP points
        double finalSLpts = baseSLptsInput;
        double finalTPpts = baseTPptsInput;

        if(InpUseATRForSLTP && atrDistPoints > 0)
        {
            finalSLpts = atrDistPoints * MathMax(0.5, InpSL_ATR_Mult);
            finalTPpts = atrDistPoints * MathMax(1.0, InpTP_ATR_Mult);
        }

        // For Boom/Crash: cap SL to 10 previous candles' extreme and force TP = 3x SL if possible
        if(IsBoomCrashIndex(_Symbol))
        {
            MqlRates rr[];
            if(CopyRates(_Symbol, PERIOD_M1, 0, 12, rr) >= 11)
            {
                double low10 = rr[1].low;
                double high10 = rr[1].high;
                for(int i=2;i<=10;i++){ if(rr[i].low < low10) low10 = rr[i].low; if(rr[i].high > high10) high10 = rr[i].high; }
                double distPts10 = 0.0;
                if(direction > 0) // BUY on Boom
                    distPts10 = (entryPrice - low10) / MathMax(point,1e-12);
                else // SELL on Crash
                    distPts10 = (high10 - entryPrice) / MathMax(point,1e-12);
                distPts10 = MathMax((double)minPts, distPts10);
                finalSLpts = MathMax((double)minPts, MathMin(finalSLpts, distPts10));
            }
            // Force TP = 3x SL for Boom/Crash, IF initial calculation allows
            finalTPpts = 3.0 * finalSLpts;
        }

        // Monetary guards per symbol:
        // - Boom/Crash: cap SL to $2 max loss; TP in dollars not enforced here (spike close will handle exits)
        // - Others: cap SL to $1 max loss; enforce TP >= $5 profit
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double lotForMoney = CalculateValidLotSize();
    if(IsBoomCrashIndex(_Symbol)) lotForMoney = 0.20;
        double dollarPerPointPerLot = 0.0;
        if(tickSize>0.0 && point>0.0) dollarPerPointPerLot = tickValue * (point / tickSize);
        if(dollarPerPointPerLot>0.0 && lotForMoney>0.0)
        {
            bool isBC = IsBoomCrashIndex(_Symbol);
            double lossUSD  = isBC ? 2.0 : 1.0;
            double profitUSD= isBC ? 0.0 : 5.0;

            double maxSLPtsByMoney = MathFloor(MathAbs(lossUSD) / (dollarPerPointPerLot * lotForMoney));
            if(maxSLPtsByMoney > 0.0)
                finalSLpts = MathMin(finalSLpts, maxSLPtsByMoney);

            if(profitUSD > 0.0)
            {
                double minTPPtsByMoney = MathCeil(MathAbs(profitUSD) / (dollarPerPointPerLot * lotForMoney));
                if(minTPPtsByMoney > 0.0)
                    finalTPpts = MathMax(finalTPpts, minTPPtsByMoney);
            }
        }

        // Enforce minimum Risk:Reward (TP >= R * SL)
        double rrMin = MathMax(1.0, InpMinRiskReward);
        if(finalTPpts < rrMin * finalSLpts)
            finalTPpts = rrMin * finalSLpts;
        
        // Prices
        if(direction > 0) // BUY
        {
            outSL = NormalizeDouble(entryPrice - finalSLpts * point, digits);
            outTP = NormalizeDouble(entryPrice + finalTPpts * point, digits);
        }
        else // SELL
        {
            outSL = NormalizeDouble(entryPrice + finalSLpts * point, digits);
            outTP = NormalizeDouble(entryPrice - finalTPpts * point, digits);
        }
        
        // Final validation: ensure distances >= minPts and SL/TP coherent
        double minDist = minPts * point;
        if(direction > 0)
        {
            if((entryPrice - outSL) < minDist) outSL = NormalizeDouble(entryPrice - minDist, digits);
            if((outTP - entryPrice) < minDist) outTP = NormalizeDouble(entryPrice + minDist, digits);
        }
        else
        {
            if((outSL - entryPrice) < minDist) outSL = NormalizeDouble(entryPrice + minDist, digits);
            if((entryPrice - outTP) < minDist) outTP = NormalizeDouble(entryPrice - minDist, digits);
        }
        
        // Safeguard: if distances are still too tight (rounding), zero them to avoid invalid stops
        if(MathAbs(entryPrice - outSL) < minDist - 1e-8 || MathAbs(outTP - entryPrice) < minDist - 1e-8)
        {
            outSL = 0.0; outTP = 0.0;
        }
    }
    
    // Aligne un lot sur l'échelle Deriv Boom/Crash autorisée
    double SnapToDerivBoomCrashLots(const double desired)
    {
        // Liste discrète utilisée par Deriv pour Boom/Crash
        double allowed[] = {0.20, 0.50, 1.0, 2.0, 3.0, 5.0, 10.0, 20.0, 50.0};
        double target = desired;
        if(target <= allowed[0]) return allowed[0];
        for(int i=1;i<ArraySize(allowed);i++)
        {
            if(target <= allowed[i])
            {
                // choisir la valeur la plus proche
                double low = allowed[i-1];
                double high = allowed[i];
                return (MathAbs(target-low) <= MathAbs(high-target)) ? low : high;
            }
        }
        return allowed[ArraySize(allowed)-1];
    }

    double CalculateValidLotSize() {
        // Obtenir les paramètres de lot du symbole
        double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
        double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
        double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
        
    // Par défaut, utiliser l'input
    double lotSize = InpLotSize;

        // Si Boom/Crash, FORCER le lot à 0.2 (minimum requit)
        if(IsBoomCrashIndex(_Symbol)) {
            lotSize = 0.20;
            // Si le broker a un minLot plus élevé (ex: 0.2), l'utiliser
            if(minLot > 0.20) lotSize = minLot;
            return NormalizeDouble(lotSize, 2);
        }
        
        // Normaliser selon le step pour les autres symboles
        if(lotStep > 0.0)
            lotSize = MathFloor(lotSize / lotStep) * lotStep;
        
        // Bornes broker
        if(lotSize < minLot) lotSize = minLot;
        if(lotSize > maxLot) lotSize = maxLot;
        
        // Vérification finale
        if(lotSize < minLot || lotSize > maxLot) {
            Print("? Lot size invalide après normalisation: ", lotSize,
                  " MinBroker:", minLot, " MaxBroker:", maxLot, " Step:", lotStep);
            return 0;
        }
        
        return NormalizeDouble(lotSize, 2);
    }
};

//--- Variables globales
CRiskManager* g_riskManager = NULL;
CSignalDetector* g_signalDetector = NULL;

// Variables pour la gestion des signaux externes
static int      g_extLastDir = 0;           // Dernière direction du signal externe
static int      g_extLastConf = 0;          // Dernière confiance du signal externe
static datetime g_extLastUpdate = 0;        // Dernière mise à jour du signal externe
CSignalValidator* g_signalValidator = NULL;
CTradeExecutor* g_tradeExecutor = NULL;

// Global cooldown timer after global loss close
static datetime g_globalCooldownUntil = 0;

//--- Variables pour le trading intelligent
struct SmartTradeInfo {
    ulong ticket;
    double entry_price;
    double lot_size;
    int direction;
    double original_sl;
    double original_tp;
    double current_sl;
    double current_tp;
    bool partial_closed;
    double partial_close_price;
    datetime open_time;
    double max_profit;
    double max_loss;
    bool trailing_active;
    double confidence_score;  // Score de confiance du signal
    bool validated_win;       // Trade validé comme gagnant
    datetime validation_time; // Temps de validation
};
SmartTradeInfo smart_trades[10];
int smart_trade_count = 0;

//--- Variables pour la validation des signaux
struct SignalValidation {
    int direction;
    double confidence;
    datetime signal_time;
    double entry_price;
    bool spike_verified;
    bool trade_validated;
};
SignalValidation pending_signals[5];
int pending_signal_count = 0;

//--- Variables de gestion
datetime g_lastDay = -1;
bool g_isEarlySignal = false; // true si le signal courant provient d'un pré-spike / EMA-touch

// --- Cache IA pour anticipation
static int      g_aiLastDir = 0;          // 1 BUY, -1 SELL, 0 neutre
static int      g_aiLastConf = 0;         // 0..100
static datetime g_aiLastUpdate = 0;       // timestamp dernier refresh
static int      g_aiTtlSeconds = 15;      // validité du cache
static double   g_aiLastEntry = 0.0;      // prix d'entrée absolu si fourni
static double   g_aiLastSL    = 0.0;      // SL absolu si fourni
static double   g_aiLastTP    = 0.0;      // TP absolu si fourni
static string   g_aiLastNote  = "";       // Explication IA (NOTE=...)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("?? SPIKE HUNTER PROFESSIONNEL - Version 3.0 Corrigée");
    Print("   ? Architecture modulaire et sécurisée");
    Print("   ? Gestion des risques professionnelle");
    Print("   ? Validation des signaux rigoureuse");
    Print("   ? Performance optimisée");
    
    // Vérifier la connexion au terminal
    if(!TerminalInfoInteger(TERMINAL_CONNECTED)) {
        Alert("Erreur: Pas de connexion au terminal!");
        return(INIT_FAILED);
    }
    
    // Vérifier la connexion au marché
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        Alert("Erreur: Le trading n'est pas autorisé!");
        return(INIT_FAILED);
    }
    
    // Initialiser les gestionnaires avec vérification
    g_riskManager = new CRiskManager();
    if(CheckPointer(g_riskManager) == POINTER_INVALID) {
        Alert("Erreur: Échec de l'initialisation du gestionnaire de risque!");
        return(INIT_FAILED);
    }
    
    g_signalDetector = new CSignalDetector();
    if(CheckPointer(g_signalDetector) == POINTER_INVALID) {
        Alert("Erreur: Échec de l'initialisation du détecteur de signaux!");
        delete g_riskManager;
        g_riskManager = NULL;
        return(INIT_FAILED);
    }
    
    g_tradeExecutor = new CTradeExecutor();
    if(CheckPointer(g_tradeExecutor) == POINTER_INVALID) {
        Alert("Erreur: Échec de l'initialisation de l'exécuteur de trades!");
        delete g_riskManager;
        delete g_signalDetector;
        g_riskManager = NULL;
        g_signalDetector = NULL;
        return(INIT_FAILED);
    }
    
    // Initialisation des variables globales
    g_last_sr_update = 0;
    g_last_smc_update = 0;
    g_basketReentryArmedAt = 0;
    g_bcReentryArmedTime = 0;
    
    // Vérifier les paramètres d'entrée
    if(InpLotSize <= 0 || InpStopLoss < 0 || InpTakeProfit < 0) {
        Alert("Erreur: Paramètres de trading invalides!");
        OnDeinit(REASON_PARAMETERS);
        return(INIT_PARAMETERS_INCORRECT);
    }
    
    Print("Initialisation réussie - Robot prêt à trader");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    string reason_text = "";
    
    switch(reason)
    {
        case REASON_ACCOUNT:    reason_text = "Compte changé"; break;
        case REASON_CHARTCHANGE:reason_text = "Changement de graphique"; break;
        case REASON_CHARTCLOSE: reason_text = "Graphique fermé"; break;
        case REASON_PARAMETERS: reason_text = "Paramètres modifiés"; break;
        case REASON_RECOMPILE:  reason_text = "Recompilation"; break;
        case REASON_REMOVE:     reason_text = "Suppression du graphique"; break;
        case REASON_CLOSE:      reason_text = "Terminal fermé"; break;
        default:                reason_text = "Raison inconnue: " + IntegerToString(reason);
    }
    
    Print("?? SPIKE HUNTER - Arrêt du trading (", reason_text, ")");
    
    // Nettoyer les ressources avec vérification des pointeurs
    if(CheckPointer(g_tradeExecutor) != POINTER_INVALID) {
        delete g_tradeExecutor;
        g_tradeExecutor = NULL;
    }
    
    if(CheckPointer(g_signalDetector) != POINTER_INVALID) {
        delete g_signalDetector;
        g_signalDetector = NULL;
    }
    
    if(CheckPointer(g_riskManager) != POINTER_INVALID) {
        delete g_riskManager;
        g_riskManager = NULL;
    }
    
    // Nettoyer les objets graphiques
    ObjectsDeleteAll(0, "SPIKE_HUNTER_");
    
    Print("Nettoyage terminé");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
//| Calculer la taille de lot intelligente basée sur le risque       |
//+------------------------------------------------------------------+
double CalculateSmartLotSize(string symbol, double entry_price, double stop_loss_price)
{
    if(!InpUseSmartTrading) return InpLotSize;
    
    double current_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = current_balance * (InpMaxRiskPerTrade / 100.0);
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(point <= 0 || tick_value <= 0 || tick_size <= 0) return InpLotSize;
    
    // Calculer la distance du stop loss en points
    double sl_distance_points = MathAbs(entry_price - stop_loss_price) / point;
    
    // Calculer la valeur du risque par point
    double risk_per_point = tick_value * (point / tick_size);
    
    // Calculer la taille de lot basée sur le risque
    double calculated_lot = risk_amount / (sl_distance_points * risk_per_point);
    
    // Appliquer les limites
    double min_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    calculated_lot = MathMax(calculated_lot, min_lot);
    calculated_lot = MathMin(calculated_lot, max_lot);
    
    // Arrondir au step
    if(lot_step > 0) {
        calculated_lot = MathRound(calculated_lot / lot_step) * lot_step;
    }
    
    Print("?? LOT INTELLIGENT: Risque: $", DoubleToString(risk_amount, 2), 
          " | Distance SL: ", DoubleToString(sl_distance_points, 1), " pts | Lot: ", DoubleToString(calculated_lot, 2));
    
    return calculated_lot;
}

//+------------------------------------------------------------------+
//| Calculer le Take Profit dynamique basé sur la volatilité        |
//+------------------------------------------------------------------+
double CalculateDynamicTakeProfit(string symbol, double entry_price, int direction, double stop_loss_price)
{
    if(!InpUseDynamicTP) return InpTakeProfit;
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double sl_distance_points = MathAbs(entry_price - stop_loss_price) / point;
    
    // Calculer l'ATR pour la volatilité
    int atr_handle = iATR(symbol, PERIOD_M1, 14);
    if(atr_handle == INVALID_HANDLE) return InpTakeProfit;
    
    double atr_values[1];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_values) < 1) {
        IndicatorRelease(atr_handle);
        return InpTakeProfit;
    }
    
    double atr_points = atr_values[0] / point;
    IndicatorRelease(atr_handle);
    
    // Calculer le TP dynamique basé sur le ratio risque/récompense et la volatilité
    double base_tp_points = sl_distance_points * InpMinRiskRewardRatio;
    double volatility_multiplier = MathMin(2.0, MathMax(0.5, atr_points / 10.0));
    
    double dynamic_tp_points = base_tp_points * volatility_multiplier;
    
    // Limiter le TP maximum
    dynamic_tp_points = MathMin(dynamic_tp_points, InpTakeProfit * 3.0);
    
    Print("?? TP DYNAMIQUE: SL: ", DoubleToString(sl_distance_points, 1), 
          " pts | ATR: ", DoubleToString(atr_points, 1), " pts | TP: ", DoubleToString(dynamic_tp_points, 1), " pts");
    
    return dynamic_tp_points;
}

//+------------------------------------------------------------------+
//| Calculer le Stop Loss adaptatif                                 |
//+------------------------------------------------------------------+
double CalculateAdaptiveStopLoss(string symbol, double entry_price, int direction)
{
    if(!InpUseAdaptiveSL) return InpStopLoss;
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Calculer l'ATR pour la volatilité
    int atr_handle = iATR(symbol, PERIOD_M1, 14);
    if(atr_handle == INVALID_HANDLE) return InpStopLoss;
    
    double atr_values[1];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_values) < 1) {
        IndicatorRelease(atr_handle);
        return InpStopLoss;
    }
    
    double atr_points = atr_values[0] / point;
    IndicatorRelease(atr_handle);
    
    // Calculer le SL adaptatif basé sur l'ATR
    double adaptive_sl_points = MathMax(InpStopLoss * 0.5, atr_points * 1.5);
    adaptive_sl_points = MathMin(adaptive_sl_points, InpStopLoss * 2.0);
    
    Print("??? SL ADAPTATIF: ATR: ", DoubleToString(atr_points, 1), 
          " pts | SL: ", DoubleToString(adaptive_sl_points, 1), " pts");
    
    return adaptive_sl_points;
}

//+------------------------------------------------------------------+
//| Gérer les trades intelligents                                    |
//+------------------------------------------------------------------+
void ManageSmartTrades()
{
    if(!InpUseSmartTrading) return;
    
    for(int i = 0; i < smart_trade_count; i++) {
        if(smart_trades[i].ticket == 0) continue;
        
        if(!PositionSelectByTicket(smart_trades[i].ticket)) {
            // Position fermée, nettoyer
            smart_trades[i].ticket = 0;
            continue;
        }
        
        double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
        double current_profit = PositionGetDouble(POSITION_PROFIT);
        double current_volume = PositionGetDouble(POSITION_VOLUME);
        
        // Vérifier la fermeture automatique après spike (logique unifiée)
        if(InpExitOnSpikeDetection) {
            string symbol = PositionGetString(POSITION_SYMBOL);
            int type = (int)PositionGetInteger(POSITION_TYPE);
            int direction = (type == POSITION_TYPE_BUY) ? 1 : -1;
            
            // Utiliser DetectSpikeForTrade() pour une détection plus précise
            if(DetectSpikeForTrade(symbol, direction)) {
                // Vérifier si on exige un profit positif
                bool should_close = true;
                if(InpExitRequireProfit && current_profit <= 0.0) {
                    should_close = false;
                    Print("🎯 SPIKE DÉTECTÉ mais trade en perte ($", DoubleToString(current_profit, 2), ") - Fermeture bloquée par InpExitRequireProfit");
                }
                
                if(should_close) {
                    Print("🎯 SPIKE DÉTECTÉ - Fermeture immédiate du trade ", smart_trades[i].ticket, 
                  " sur ", symbol, " - Profit: $", DoubleToString(current_profit, 2));
            
            // Fermer la position manuellement
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_DEAL;
            request.position = smart_trades[i].ticket;
            request.symbol = symbol;
            request.volume = current_volume;
            request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.magic = InpMagicNumber;
                    request.comment = "SpikeClose";
            
            if(OrderSend(request, result)) {
                        Print("✅ Trade fermé automatiquement après spike - Profit final: $", DoubleToString(current_profit, 2));
                smart_trades[i].ticket = 0;
                continue;
            } else {
                        Print("❌ Échec fermeture automatique après spike: ", GetLastError());
                    }
                }
            }
        }
        
        // Fermeture immédiate si profit > seuil configuré (capture rapide des gains)
        // Pour les indices Boom/Crash/Volatility, fermer selon le niveau de volatilité
        double quick_threshold = InpQuickGainThreshold;
        string symbol = PositionGetString(POSITION_SYMBOL);
        if(StringFind(symbol, "Crash") >= 0 || StringFind(symbol, "Boom") >= 0) {
            quick_threshold = 0.01; // Fermer dès 1 centime de profit pour les indices Boom/Crash
        } else if(IsVolatilityIndex(symbol)) {
            int vol_level = GetVolatilityLevel(symbol);
            // Adapter le seuil selon le niveau de volatilité
            switch(vol_level) {
                case 10:  quick_threshold = 0.05; break;  // Plus rapide pour Vol 10%
                case 25:  quick_threshold = 0.1; break;
                case 50:  quick_threshold = 0.2; break;
                case 75:  quick_threshold = 0.3; break;
                case 100: quick_threshold = 0.4; break;  // Plus patient pour Vol 100%
                default:  quick_threshold = 0.2; break;
            }
        }
        
        if(current_profit > quick_threshold) {
            int type = (int)PositionGetInteger(POSITION_TYPE);
            
            Print("?? GAIN RAPIDE - Fermeture immédiate du trade ", smart_trades[i].ticket, 
                  " sur ", symbol, " - Profit: $", DoubleToString(current_profit, 2));
            
            // Fermer la position manuellement
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            request.action = TRADE_ACTION_DEAL;
            request.position = smart_trades[i].ticket;
            request.symbol = symbol;
            request.volume = current_volume;
            request.type = (type == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.magic = InpMagicNumber;
            request.comment = "QuickGain";
            
            if(OrderSend(request, result)) {
                Print("? Trade fermé pour gain rapide - Profit final: $", DoubleToString(current_profit, 2));
                smart_trades[i].ticket = 0;
                continue;
            } else {
                Print("? Échec fermeture pour gain rapide: ", GetLastError());
            }
        }
        
        // Mettre à jour le profit maximum
        if(current_profit > smart_trades[i].max_profit) {
            smart_trades[i].max_profit = current_profit;
        }
        
        // Mettre à jour la perte maximum
        if(current_profit < smart_trades[i].max_loss) {
            smart_trades[i].max_loss = current_profit;
        }
        
        // Fermeture partielle si profit atteint
        if(InpUsePartialClose && !smart_trades[i].partial_closed) {
            double profit_points = MathAbs(current_price - smart_trades[i].entry_price) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            if(profit_points >= InpPartialCloseAtProfit) {
                ClosePartialPosition(smart_trades[i].ticket, InpPartialClosePercent);
                smart_trades[i].partial_closed = true;
                smart_trades[i].partial_close_price = current_price;
                Print("?? FERMETURE PARTIELLE: ", DoubleToString(InpPartialClosePercent, 0), "% à ", DoubleToString(profit_points, 1), " pts de profit");
            }
        }
        
        // Trailing stop intelligent
        if(InpUseTrailingStopSmart) {
            ManageTrailingStopSmart(i);
        }
        
        // Sortie immédiate sur premier profit positif (capture du spike)
        if(current_profit > 0.0)
        {
            MqlTradeRequest rq; MqlTradeResult rs; ZeroMemory(rq); ZeroMemory(rs);
            rq.action = TRADE_ACTION_DEAL;
            rq.symbol = _Symbol;
            rq.position = smart_trades[i].ticket;
            rq.volume = current_volume;
            rq.type = (smart_trades[i].direction>0)? ORDER_TYPE_SELL : ORDER_TYPE_BUY; // close by opposite
            rq.price = SymbolInfoDouble(_Symbol, (smart_trades[i].direction>0)? SYMBOL_BID:SYMBOL_ASK);
            rq.deviation = 20;
            rq.magic = InpMagicNumber;
            rq.comment = "SpikeCaptureClose";
            if(OrderSend(rq, rs))
            {
                Print("? Fermeture immédiate en gain: ", DoubleToString(current_profit,2), " USD");
                // Nettoyer cette structure
                smart_trades[i].ticket = 0;
                continue;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Gérer le trailing stop intelligent                              |
//+------------------------------------------------------------------+
void ManageTrailingStopSmart(int trade_index)
{
    double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
    double current_sl = PositionGetDouble(POSITION_SL);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    // Calculer le profit en points
    double profit_points = MathAbs(current_price - smart_trades[trade_index].entry_price) / point;
    
    // Activer le trailing stop si profit suffisant
    if(profit_points >= InpTrailingStartPoints && !smart_trades[trade_index].trailing_active) {
        smart_trades[trade_index].trailing_active = true;
        Print("?? TRAILING STOP ACTIVÉ: ", DoubleToString(profit_points, 1), " pts de profit");
    }
    
    if(smart_trades[trade_index].trailing_active) {
        double new_sl = 0;
        
        if(smart_trades[trade_index].direction > 0) { // BUY
            new_sl = current_price - (InpTrailingStepPoints * point);
            if(new_sl > current_sl) {
                ModifyPositionSL(smart_trades[trade_index].ticket, new_sl);
                smart_trades[trade_index].current_sl = new_sl;
            }
        } else { // SELL
            new_sl = current_price + (InpTrailingStepPoints * point);
            if(current_sl == 0 || new_sl < current_sl) {
                ModifyPositionSL(smart_trades[trade_index].ticket, new_sl);
                smart_trades[trade_index].current_sl = new_sl;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Fermer partiellement une position                              |
//+------------------------------------------------------------------+
void ClosePartialPosition(ulong ticket, double percent)
{
    if(!PositionSelectByTicket(ticket)) return;
    
    double current_volume = PositionGetDouble(POSITION_VOLUME);
    double close_volume = current_volume * (percent / 100.0);
    
    // Arrondir au step de volume
    double volume_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    if(volume_step > 0) {
        close_volume = MathRound(close_volume / volume_step) * volume_step;
    }
    
    if(close_volume <= 0) return;
    
    MqlTradeRequest request;
    MqlTradeResult result;
    // ZeroMemory(request);
    // ZeroMemory(result);
    
    request.action = TRADE_ACTION_DEAL;
    request.position = ticket;
    request.symbol = _Symbol;
    request.volume = close_volume;
    request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.price = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    request.deviation = 10;
    request.magic = InpMagicNumber;
    request.comment = "PartialClose";
    
    if(OrderSend(request, result)) {
        Print("? FERMETURE PARTIELLE: ", DoubleToString(close_volume, 2), " lots fermés");
    }
}

//+------------------------------------------------------------------+
//| Modifier le Stop Loss d'une position                            |
//+------------------------------------------------------------------+
void ModifyPositionSL(ulong ticket, double new_sl)
{
    MqlTradeRequest request;
    MqlTradeResult result;
    // ZeroMemory(request);
    // ZeroMemory(result);
    
    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.sl = new_sl;
    request.tp = PositionGetDouble(POSITION_TP);
    
    if(OrderSend(request, result)) {
        Print("?? SL MODIFIÉ: ", DoubleToString(new_sl, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Ajouter un trade intelligent                                    |
//+------------------------------------------------------------------+
void AddSmartTrade(ulong ticket, double entry_price, double lot_size, int direction, double sl_price, double tp_price, double confidence = 0.0)
{
    if(smart_trade_count >= 10) return;
    
    smart_trades[smart_trade_count].ticket = ticket;
    smart_trades[smart_trade_count].entry_price = entry_price;
    smart_trades[smart_trade_count].lot_size = lot_size;
    smart_trades[smart_trade_count].direction = direction;
    smart_trades[smart_trade_count].original_sl = sl_price;
    smart_trades[smart_trade_count].original_tp = tp_price;
    smart_trades[smart_trade_count].current_sl = sl_price;
    smart_trades[smart_trade_count].current_tp = tp_price;
    smart_trades[smart_trade_count].partial_closed = false;
    smart_trades[smart_trade_count].partial_close_price = 0;
    smart_trades[smart_trade_count].open_time = TimeCurrent();
    smart_trades[smart_trade_count].max_profit = 0;
    smart_trades[smart_trade_count].max_loss = 0;
    smart_trades[smart_trade_count].trailing_active = false;
    smart_trades[smart_trade_count].confidence_score = confidence;
    smart_trades[smart_trade_count].validated_win = false;
    smart_trades[smart_trade_count].validation_time = 0;
    
    smart_trade_count++;
    
    Print("?? TRADE INTELLIGENT AJOUTÉ: Ticket ", ticket, " | Lot: ", DoubleToString(lot_size, 2), 
          " | SL: ", DoubleToString(sl_price, _Digits), " | TP: ", DoubleToString(tp_price, _Digits),
          " | Confiance: ", DoubleToString(confidence, 1), "%");
}

//+------------------------------------------------------------------+
//| Vérifier la confiance du signal                                 |
//+------------------------------------------------------------------+
bool IsSignalConfidenceValid(double confidence)
{
    return (confidence >= InpMinConfidenceThreshold);
}

//+------------------------------------------------------------------+
//| Ajouter un signal en attente de validation                      |
//+------------------------------------------------------------------+
void AddPendingSignal(int direction, double confidence, double entry_price)
{
    if(pending_signal_count >= 5) return;
    
    pending_signals[pending_signal_count].direction = direction;
    pending_signals[pending_signal_count].confidence = confidence;
    pending_signals[pending_signal_count].signal_time = TimeCurrent();
    pending_signals[pending_signal_count].entry_price = entry_price;
    pending_signals[pending_signal_count].spike_verified = false;
    pending_signals[pending_signal_count].trade_validated = false;
    
    pending_signal_count++;
    
    Print("? SIGNAL EN ATTENTE: Direction ", (direction > 0 ? "BUY" : "SELL"), 
          " | Confiance: ", DoubleToString(confidence, 1), "% | Prix: ", DoubleToString(entry_price, _Digits));
}

//+------------------------------------------------------------------+
//| Vérifier si un spike est arrivé                                 |
//+------------------------------------------------------------------+
bool VerifySpikeArrival(int direction, double entry_price)
{
    if(!InpVerifySpikeBeforeSignal) return true;
    
    double current_price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    // Vérifier si le prix a bougé significativement dans la direction attendue
    double price_movement = MathAbs(current_price - entry_price) / point;
    double min_spike_points = 5.0; // Minimum 5 points de mouvement
    
    // Pour les indices Boom/Crash, être plus sensible
    if(IsBoomCrashIndex(_Symbol)) {
        min_spike_points = 2.0; // Plus sensible pour Boom/Crash
    }
    
    if(direction > 0) {
        // Pour BUY, vérifier que le prix a monté
        bool spike_detected = (current_price > entry_price && price_movement >= min_spike_points);
        if(spike_detected && IsBoomCrashIndex(_Symbol)) {
            Print("?? SPIKE BOOM DÉTECTÉ - Prix: ", DoubleToString(current_price, 5), 
                  " vs Entrée: ", DoubleToString(entry_price, 5), 
                  " (+", DoubleToString(price_movement, 1), " points)");
        }
        return spike_detected;
    } else {
        // Pour SELL, vérifier que le prix a baissé
        bool spike_detected = (current_price < entry_price && price_movement >= min_spike_points);
        if(spike_detected && IsBoomCrashIndex(_Symbol)) {
            Print("?? SPIKE CRASH DÉTECTÉ - Prix: ", DoubleToString(current_price, 5), 
                  " vs Entrée: ", DoubleToString(entry_price, 5), 
                  " (-", DoubleToString(price_movement, 1), " points)");
        }
        return spike_detected;
    }
}

//+------------------------------------------------------------------+
//| Valider qu'un trade est gagnant en 1 minute                    |
//+------------------------------------------------------------------+
bool ValidateTradeWin(ulong ticket, int direction, double entry_price)
{
    if(!InpValidateTradeWin) return true;
    
    if(!PositionSelectByTicket(ticket)) return false;
    
    double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
    double current_profit = PositionGetDouble(POSITION_PROFIT);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    // Vérifier si le trade est en profit après 1 minute
    if(current_profit > 0) {
        double profit_points = MathAbs(current_price - entry_price) / point;
        double min_profit_points = 3.0; // Minimum 3 points de profit
        
        if(profit_points >= min_profit_points) {
            Print("? TRADE VALIDÉ GAGNANT: Ticket ", ticket, " | Profit: ", DoubleToString(current_profit, 2), 
                  " | Points: ", DoubleToString(profit_points, 1));
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Gérer les signaux en attente de validation                      |
//+------------------------------------------------------------------+
void ManagePendingSignals()
{
    for(int i = pending_signal_count - 1; i >= 0; i--) {
        // Vérifier si le signal a expiré (plus de 2 minutes)
        if(TimeCurrent() - pending_signals[i].signal_time > 120) {
            Print("? SIGNAL EXPIRÉ: Direction ", (pending_signals[i].direction > 0 ? "BUY" : "SELL"));
            // Supprimer le signal expiré
            for(int j = i; j < pending_signal_count - 1; j++) {
                pending_signals[j] = pending_signals[j + 1];
            }
            pending_signal_count--;
            continue;
        }
        
        // Vérifier si le spike est arrivé
        if(!pending_signals[i].spike_verified) {
            if(VerifySpikeArrival(pending_signals[i].direction, pending_signals[i].entry_price)) {
                pending_signals[i].spike_verified = true;
                Print("?? SPIKE VÉRIFIÉ: Direction ", (pending_signals[i].direction > 0 ? "BUY" : "SELL"));
            }
        }
        
        // Si le spike est vérifié, on peut exécuter le trade
        if(pending_signals[i].spike_verified && !pending_signals[i].trade_validated) {
            if(g_riskManager.CanOpenTrade()) {
                // Exécuter le trade avec la confiance
                if(g_tradeExecutor.ExecuteTrade(pending_signals[i].direction)) {
                    pending_signals[i].trade_validated = true;
                    Print("?? TRADE EXÉCUTÉ APRÈS VALIDATION: Direction ", (pending_signals[i].direction > 0 ? "BUY" : "SELL"), 
                          " | Confiance: ", DoubleToString(pending_signals[i].confidence, 1), "%");
                    
                    // Ajouter le trade aux trades intelligents avec la confiance
                    ulong ticket = 0;
                    for(int j = PositionsTotal() - 1; j >= 0; j--) {
                        ulong pos_ticket = PositionGetTicket(j);
                        if(PositionSelectByTicket(pos_ticket)) {
                            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                                ticket = pos_ticket;
                                break;
                            }
                        }
                    }
                    
                    if(ticket > 0) {
                        double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
                        double lot_size = PositionGetDouble(POSITION_VOLUME);
                        double sl_price = PositionGetDouble(POSITION_SL);
                        double tp_price = PositionGetDouble(POSITION_TP);
                        AddSmartTrade(ticket, entry_price, lot_size, pending_signals[i].direction, sl_price, tp_price, pending_signals[i].confidence);
                        // Dessiner une seule flèche validée et notifier (post-validation uniquement)
                        DrawSignalArrow(pending_signals[i].direction);
                        if(InpSendNotifications) {
                            string sidev = (pending_signals[i].direction>0?"BUY":"SELL");
                            NotifyOnce(StringFormat("? Signal validé %s (? %.0f%%) sur %s", sidev, InpMinConfidenceThreshold, _Symbol));
                        }
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
// Timers globaux pour ré-entrées
static datetime g_basketReentryArmedAt = 0;
static datetime g_bcReentryArmedTime   = 0;

void OnTick()
{
    if(!InpEnableTrading) return;
    
    // Gérer les trades intelligents (fermeture partielle, trailing stop, etc.)
    ManageSmartTrades();
    
    // Gérer les signaux en attente de validation
    ManagePendingSignals();
    
    // Mettre à jour les zones S/R et trendlines
    if(TimeCurrent() - g_last_sr_update >= 60) { // Mise à jour toutes les minutes
        UpdateSRZones();
    }
    
    // Mise à jour des données SMC renforcées
    if(TimeCurrent() - g_last_smc_update >= 30) { // Mise à jour toutes les 30 secondes
        UpdateSMCData();
    }
    
    // Mise à jour dynamique des patterns en temps réel
    UpdateDynamicPatterns();
    
    // Mise à jour des données API (tous les endpoints)
    UpdateAPIData();
    
    // Mise à jour des résultats journaliers (toujours affiché)
    UpdateDailyResults();
    
    // Mise à jour des visualisations avancées
    if(TimeCurrent() - g_last_visual_update >= 1) // Toutes les secondes
    {
        // Mise à jour des zones de liquidité
        DrawLiquidityZones();
        
        // Mise à jour du profil de volume
        DrawVolumeProfile();
        
        // Mise à jour de la structure de marché
        DrawMarketStructureVisuals();
        
        // Mise à jour des zones OTE
        DrawOTEZones();
        
        // Mise à jour des retracements de Fibonacci
        DrawFibonacciRetracements();
        
        g_last_visual_update = TimeCurrent();
    }
    
    // NOUVELLE LOGIQUE DE TRADING AVEC CONFLUENCE RENFORCÉE
    static datetime last_confluence_check = 0;
    if(TimeCurrent() - last_confluence_check >= 5) { // Vérification toutes les 5 secondes
        CheckConfluenceTrading();
        last_confluence_check = TimeCurrent();
    }
    
    // SMC TRADING INTEGRATION - SCAN MULTI-SYMBOLES POUR TROUVER LE MEILLEUR SIGNAL
    static datetime last_smc_check = 0;
    if(InpUseSMCTrading && TimeCurrent() - last_smc_check >= 5) { // Scan toutes les 5 secondes
        SymbolSignal best_signal;
        
        // Scanner tous les symboles et trouver le meilleur
        if(ScanAllSymbolsForBestOpportunity(best_signal)) {
            // Vérifier qu'on peut ouvrir un trade
            if(g_riskManager.CanOpenTrade()) {
                // Vérifier qu'il n'y a pas déjà de position sur ce symbole
                bool hasPosition = false;
                for(int i = 0; i < PositionsTotal(); i++) {
                    ulong tk = PositionGetTicket(i);
                    if(!PositionSelectByTicket(tk)) continue;
                    if(PositionGetString(POSITION_SYMBOL) == best_signal.symbol && 
                       (int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                        hasPosition = true;
                        break;
                    }
                }
                
                if(!hasPosition) {
                    // Calculer la taille du lot
                    double lot_size = InpLotSize;
                    if(IsBoomCrashIndex(best_signal.symbol)) {
                        lot_size = 0.20;
                        double minLot = SymbolInfoDouble(best_signal.symbol, SYMBOL_VOLUME_MIN);
                        if(minLot > 0.20) lot_size = minLot;
                    }
                    
                    // Obtenir le prix d'entrée actuel
                    double point = SymbolInfoDouble(best_signal.symbol, SYMBOL_POINT);
                    double current_price = 0;
                    if(best_signal.direction > 0) {
                        current_price = SymbolInfoDouble(best_signal.symbol, SYMBOL_ASK);
                    } else {
                        current_price = SymbolInfoDouble(best_signal.symbol, SYMBOL_BID);
                    }
                    
                    // Ré-ajuster SL/TP si nécessaire avec le prix actuel
                    double sl = best_signal.sl_price;
                    double tp = best_signal.tp_price;
                    
                    if(!EnsureValidStops(best_signal.symbol, best_signal.direction, current_price, point, sl, tp)) {
                        Print("❌ SL/TP invalides après validation pour ", best_signal.symbol);
                    } else {
                        // Exécuter le trade
                        CTrade trade;
                        trade.SetExpertMagicNumber(InpMagicNumber);
                        trade.SetDeviationInPoints(10);
                        trade.SetTypeFilling(ORDER_FILLING_FOK);
                        
                        bool result = false;
                        if(best_signal.direction > 0) {
                            result = trade.Buy(lot_size, best_signal.symbol, 0, sl, tp, "Multi-Symbol SMC");
                        } else {
                            result = trade.Sell(lot_size, best_signal.symbol, 0, sl, tp, "Multi-Symbol SMC");
                        }
                        
                        if(result) {
                            Print("✅ Trade MULTI-SYMBOLES exécuté: ", best_signal.symbol,
                                  " ", (best_signal.direction > 0 ? "BUY" : "SELL"),
                                  " SL: ", DoubleToString(sl, 5),
                                  " TP: ", DoubleToString(tp, 5),
                                  " Confiance: ", DoubleToString(best_signal.confidence*100, 1), "%");
                        } else {
                            Print("❌ Échec trade: ", GetLastError());
                        }
                    }
                }
            }
        }
        
        last_smc_check = TimeCurrent();
    }
    
    // Affichage des informations SMC
    static datetime last_smc_display = 0;
    if(TimeCurrent() - last_smc_display >= 10) { // Mise à jour toutes les 10 secondes
        DrawSMCInfo();
        last_smc_display = TimeCurrent();
    }
    
    // Gestion des trades actifs (SL/TP et fermeture anticipée)
    static datetime last_trade_management = 0;
    if(TimeCurrent() - last_trade_management >= 5) { // Vérification toutes les 5 secondes
        ManageActiveTrades();
        last_trade_management = TimeCurrent();
    }
    
    // FORCER LA MISE À JOUR DES ZONES S/R (pour test)
    static datetime last_force_update = 0;
    if(TimeCurrent() - last_force_update >= 300) { // Toutes les 5 minutes
        Print("?? FORÇAGE MISE À JOUR ZONES S/R");
        UpdateSRZones();
        last_force_update = TimeCurrent();
    }
    
    
    // PRÉDICTION DE SPIKE IMMINENT
    static datetime last_prediction = 0;
    if(TimeCurrent() - last_prediction >= 10) { // Vérification toutes les 10 secondes
        double confidence = 0;
        int direction = 0;
        
        if(PredictImminentSpike(confidence, direction)) {
            Print("?? SPIKE IMMINENT DÉTECTÉ - Confiance: ", DoubleToString(confidence, 1), "%",
                  " Direction: ", (direction > 0 ? "BUY" : "SELL"));
            
            // Préparer l'entrée anticipée
            PrepareAnticipatedEntry(direction, confidence);
        }
        
        last_prediction = TimeCurrent();
    }
    
    // SYSTÈME ULTRA-PRÉCIS : Vérifier les spikes pour entrée
    if(InpUltraPreciseMode && DetectSpikeForEntry()) {
        // Vérifier la stabilité de la confiance avant de trader
        if(IsConfidenceStable()) {
            ExecuteUltraPreciseTrade();
        } else {
            Print("?? Confiance instable - Trade bloqué");
        }
    }
    
    // Vérifier que les objets sont initialisés
    if(g_riskManager == NULL || g_signalDetector == NULL || g_tradeExecutor == NULL) {
        Print("? Objets non initialisés");
        return;
    }
    
    // Reset journalier
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    if(g_lastDay != currentTime.day) {
        g_lastDay = currentTime.day;
        g_riskManager.ResetDaily();
        Print("?? Nouveau jour - Reset des compteurs");
    }

    // Rafraîchir / dessiner des zones S/R MTF
    if(InpDrawMTFZones) RefreshMTFZones();

    // Rafraîchir panneau IA
    static datetime lastAI = 0;
    if(InpEnableAIRecommendations && TimeCurrent() - lastAI >= MathMax(3, InpAIUpdateSeconds))
    {
        lastAI = TimeCurrent();
        RefreshAIPanel();
    }
    // Rafraîchir panneau d'analyses API simples (/recommendations)
    static datetime lastApiPanel = 0;
    if(InpShowApiPanel && TimeCurrent() - lastApiPanel >= MathMax(3, InpApiPanelUpdateSeconds))
    {
        lastApiPanel = TimeCurrent();
        // Interroger l'endpoint /recommendations et afficher pour le symbole courant
        string headers = "Accept: application/json";
        string respHeaders = ""; char resp[]; ResetLastError();
        uchar payload[]; ArrayResize(payload,0);
        int code = WebRequest("GET", InpRecommendationsURL, headers, 4000, payload, resp, respHeaders);
        if(code==200)
        {
            string body = CharArrayToString(resp, 0, -1, CP_UTF8);
            string needle = StringFormat("\"symbol\":\"%s\"", _Symbol);
            int p = StringFind(body, needle);
            if(p>=0)
            {
                // Extraire quelques champs texte voisins pour résumé
                int pe = StringFind(body, "\"entry\"", p);
                int ps = StringFind(body, "\"sl\"", p);
                int pt = StringFind(body, "\"tp\"", p);
                int pc = StringFind(body, "\"confidence\"", p);
                string se="", ssl="", stp="", sconf="";
                if(pe>0){ int ce=StringFind(body,":",pe); se=StringSubstr(body,ce+1,16); }
                if(ps>0){ int cs=StringFind(body,":",ps); ssl=StringSubstr(body,cs+1,16); }
                if(pt>0){ int ct=StringFind(body,":",pt); stp=StringSubstr(body,ct+1,16); }
                if(pc>0){ int cc=StringFind(body,":",pc); sconf=StringSubstr(body,cc+1,6); }
                // Afficher aussi l'analyse de tendance si disponible
                int trendDir=0, trendStr=0; bool hasTrend = GetTrendAnalysis(_Symbol, trendDir, trendStr);
                string trendInfo = hasTrend ? StringFormat(" | Trend: %d (%.0f%%)", trendDir, (double)trendStr) : "";
                
                string panel = StringFormat("API %s | entry %s | SL %s | TP %s | conf %s%s",
                                            _Symbol, se, ssl, stp, sconf, trendInfo);
                DrawLabel("API_PANEL", panel, 8, 38, clrAqua);

                // Dessiner des lignes horizontales ENTRY/SL/TP si valides
                double entryP = StringToDouble(se);
                double slP    = StringToDouble(ssl);
                double tpP    = StringToDouble(stp);
                int digits    = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
                string le = StringFormat("API_RECO_ENTRY_%s", _Symbol);
                string ls = StringFormat("API_RECO_SL_%s", _Symbol);
                string lt = StringFormat("API_RECO_TP_%s", _Symbol);
                // ENTRY
                if(entryP > 0)
                {
                    if(ObjectFind(0, le) >= 0) ObjectDelete(0, le);
                    if(ObjectCreate(0, le, OBJ_HLINE, 0, 0, NormalizeDouble(entryP, digits)))
                    {
                        ObjectSetInteger(0, le, OBJPROP_COLOR, clrAqua);
                        ObjectSetInteger(0, le, OBJPROP_STYLE, STYLE_DOT);
                        ObjectSetString(0, le, OBJPROP_TEXT, "API ENTRY");
                    }
                }
                // SL
                if(slP > 0)
                {
                    if(ObjectFind(0, ls) >= 0) ObjectDelete(0, ls);
                    if(ObjectCreate(0, ls, OBJ_HLINE, 0, 0, NormalizeDouble(slP, digits)))
                    {
                        ObjectSetInteger(0, ls, OBJPROP_COLOR, clrTomato);
                        ObjectSetInteger(0, ls, OBJPROP_STYLE, STYLE_SOLID);
                        ObjectSetString(0, ls, OBJPROP_TEXT, "API SL");
                    }
                }
                // TP
                if(tpP > 0)
                {
                    if(ObjectFind(0, lt) >= 0) ObjectDelete(0, lt);
                    if(ObjectCreate(0, lt, OBJ_HLINE, 0, 0, NormalizeDouble(tpP, digits)))
                    {
                        ObjectSetInteger(0, lt, OBJPROP_COLOR, clrLime);
                        ObjectSetInteger(0, lt, OBJPROP_STYLE, STYLE_SOLID);
                        ObjectSetString(0, lt, OBJPROP_TEXT, "API TP");
                    }
                }
            }
            else
            {
                // Fallback: essayer d'afficher la première reco globale si le symbole exact n'est pas trouvé
                int pe = StringFind(body, "\"entry\"");
                int ps = StringFind(body, "\"sl\"");
                int pt = StringFind(body, "\"tp\"");
                int pc = StringFind(body, "\"confidence\"");
                if(pe>0 && ps>0 && pt>0)
                {
                    int ce=StringFind(body,":",pe); int cs=StringFind(body,":",ps); int ct=StringFind(body,":",pt);
                    string se=StringSubstr(body,ce+1,16); string ssl=StringSubstr(body,cs+1,16); string stp=StringSubstr(body,ct+1,16);
                    string sconf=""; if(pc>0){ int cc=StringFind(body,":",pc); sconf=StringSubstr(body,cc+1,6); }
                    DrawLabel("API_PANEL", StringFormat("API (fallback) | entry %s | SL %s | TP %s | conf %s", se, ssl, stp, sconf), 8, 38, clrAqua);
                }
                else
                {
                    // Afficher un extrait brut pour diagnostic rapide
                    string preview = StringSubstr(body, 0, 120);
                    DrawLabel("API_PANEL", StringFormat("API: aucune reco pour %s", _Symbol), 8, 38, clrSilver);
                    DrawLabel("API_PANEL_RAW", StringFormat("RAW: %s", preview), 8, 52, clrSilver);
                }
            }
        }
        else
        {
            DrawLabel("API_PANEL", StringFormat("API: indisponible (HTTP %d / err %d)", code, GetLastError()), 8, 38, clrSilver);
        }
    }
    
    // Dessiner en continu les zones de spike si demandé
    static datetime lastZones = 0;
    if(InpEnableICT && InpAlwaysDrawSpikeZones)
    {
        if(TimeCurrent() - lastZones >= 5)
        {
            lastZones = TimeCurrent();
            // Purge BOS/COS/OTE objects periodically
            int total = ObjectsTotal(0, -1, -1);
            for(int oi = total-1; oi >= 0; oi--)
            {
                string on = ObjectName(0, oi);
                if(StringFind(on, "BOS_") == 0 || StringFind(on, "COS_") == 0 || StringFind(on, "OTE_") == 0)
                    ObjectDelete(0, on);
            }
        }
    }
    
    // Fermeture panier si profit total atteint
    static bool g_dailyHalted = false;
    if(InpEnableBasketClose)
    {
        static datetime lastBasketCheck = 0;
        if(TimeCurrent() - lastBasketCheck >= 1) // Check every second
        {
            double totalProfit = 0.0;
            double totalLoss = 0.0;
            int positionsCount = 0;

            for(int i = PositionsTotal()-1; i >= 0; i--)
            {
                ulong tk = PositionGetTicket(i);
                if(!PositionSelectByTicket(tk)) continue;

                // Check if position belongs to this EA
                    if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

                positionsCount++;
                double profit = PositionGetDouble(POSITION_PROFIT);
                totalProfit += profit;
                if(profit < 0) totalLoss += profit;
            }

            // Check against basket profit target
            if(totalProfit >= InpBasketProfitCloseUSD)
            {
                Print("?? TP panier atteint (", DoubleToString(totalProfit,2), " >= ", DoubleToString(InpBasketProfitCloseUSD,2), ") -> Fermeture TOTALE de toutes les positions avec magic ", InpMagicNumber);
                // Close all positions with the magic number
                CloseAllPositions(InpMagicNumber);
                // Stop the day (disable re-entry for the day)
                g_dailyHalted = true;
            }
            // Check against basket loss limit
            else if((-totalLoss) >= InpBasketLossCloseUSD) // totalLoss is negative, so -totalLoss is positive loss
            {
                Print("?? Perte panier atteinte (", DoubleToString(-totalLoss,2), " >= ", DoubleToString(InpBasketLossCloseUSD,2), ") -> Fermeture TOTALE de toutes les positions avec magic ", InpMagicNumber);
                CloseAllPositions(InpMagicNumber);
                g_dailyHalted = true;
            }
            lastBasketCheck = TimeCurrent();
        }
    }
    if(g_dailyHalted) return;
    // Execute basket re-entry if armed and conditions met
    if(!InpStrictSinglePosition && g_basketReentryArmedAt > 0 && TimeCurrent() - g_basketReentryArmedAt >= 60)
    {
        int trendDir = CSignalValidator::GetTrendDirection(InpTrendTF);
        trendDir = EnforceBoomCrashDirection(trendDir);
        if(trendDir != 0 && g_riskManager.CanOpenTrade())
        {
            if(g_tradeExecutor.ExecuteTrade(trendDir))
                g_basketReentryArmedAt = 0; // Reset after successful re-entry
        }
    }

    // Scanner les graphiques ouverts et symboles additionnels pour signaux API confirmés et ouvrir si conditions ok
    if(InpEnableMultiSymbolAPI && InpUseExternalSignals)
    {
        static datetime lastScan = 0;
        if(TimeCurrent() - lastScan >= MathMax(1, InpMultiSymbolCooldownSec))
        {
            lastScan = TimeCurrent();
            int scanned = 0;
            long chart = ChartFirst();
            while(chart != -1 && scanned < InpMaxChartsScan)
            {
                string sym = ChartSymbol(chart);
            if(StringLen(sym) > 0 && !IsSymbolInCooldown(sym))
                {
                    // Éviter doublons/positions existantes sur ce symbole (même magic)
                    bool hasPos=false;
                    for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(!PositionSelectByTicket(tk)) continue; if(PositionGetString(POSITION_SYMBOL)==sym && (int)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber){ hasPos=true; break; } }
                    if(!hasPos && g_riskManager!=NULL && g_riskManager.CanOpenTrade())
                    {
                        int dir=0, conf=0; bool ok = GetExternalSignal(sym, dir, conf);
                        if(ok && conf >= InpExtSigMinConfidence && dir!=0)
                        {
                            // Confirmation minimale: respecter Boom/Crash si activé
                            if(IsBoomCrashIndex(sym)) dir = EnforceBoomCrashDirection(dir);
                            if(dir!=0)
                            {
                                bool traded = g_tradeExecutor.ExecuteTradeOnSymbol(sym, dir);
                                if(traded) { scanned++; }
                            }
                        }
                    }
                }
                chart = ChartNext(chart);
            }

            // Parcourir les symboles additionnels configurés
            if(InpEnableAdditionalSymbols && scanned < InpMaxChartsScan)
            {
                string list = InpAdditionalSymbols;
                int start = 0;
                while(scanned < InpMaxChartsScan && start < StringLen(list))
                {
                    int comma = StringFind(list, ",", start);
                    string symb;
                    if(comma < 0) { symb = StringSubstr(list, start); start = StringLen(list); }
                    else { symb = StringSubstr(list, start, comma - start); start = comma + 1; }
                    // Trim spaces
                    while(StringLen(symb)>0 && StringGetCharacter(symb,0)==' ') symb = StringSubstr(symb,1);
                    while(StringLen(symb)>0 && StringGetCharacter(symb, StringLen(symb)-1)==' ') symb = StringSubstr(symb,0,StringLen(symb)-1);
                    if(StringLen(symb)==0) continue;
                    if(IsSymbolInCooldown(symb)) continue;
                    // Sauter si position déjà ouverte sur ce symbole
                    bool hasPos2=false;
                    for(int i2=PositionsTotal()-1;i2>=0;i2--){ ulong tk2=PositionGetTicket(i2); if(!PositionSelectByTicket(tk2)) continue; if(PositionGetString(POSITION_SYMBOL)==symb && (int)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber){ hasPos2=true; break; } }
                    if(hasPos2) continue;
                    if(g_riskManager!=NULL && g_riskManager.CanOpenTrade())
                    {
                        int d2=0,c2=0; bool ok2 = GetExternalSignal(symb, d2, c2);
                        if(ok2 && c2 >= InpExtSigMinConfidence && d2!=0)
                        {
                            if(IsBoomCrashIndex(symb)) d2 = EnforceBoomCrashDirection(d2);
                            if(d2!=0)
                            {
                                bool traded2 = g_tradeExecutor.ExecuteTradeOnSymbol(symb, d2);
                                if(traded2) { scanned++; }
                            }
                        }
                    }
                }
            }

        // API calls are now handled by UpdateAPIData() function for all endpoints
        }
    }

    // Re-entry Boom/Crash after X small candles (if enabled)
    if(!InpStrictSinglePosition && InpEnableSpikeReentry && IsBoomCrashIndex(_Symbol))
    {
        static datetime lastEntryTime = 0; // Track last entry time on this symbol
        // Check if we can attempt re-entry based on cooldown and no open positions for this symbol
        bool positionOpenForSymbol = false;
        for(int i = PositionsTotal()-1; i >= 0; i--) {
            ulong t = PositionGetTicket(i);
            if(!PositionSelectByTicket(t)) continue;
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && (int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                positionOpenForSymbol = true;
                break;
            }
        }
        
        // If no position is open for this symbol and we are within the cooldown after a loss
        if(!positionOpenForSymbol)
        {
            // Vérifier que le cooldown après perte est respecté
            if(IsSymbolInCooldown(_Symbol)) {
                Print("? SYMBOLE EN COOLDOWN après perte - Attente d'une opportunité confirmée sur ", _Symbol);
                return;
            }
            
            // Check for the small candle pattern and execute if conditions met
            MqlRates r[10];
            if(CopyRates(_Symbol, PERIOD_M1, 0, 10, r) >= 6)
            {
                double avgCandleRange = 0;
                for(int i = 1; i <= 5; i++) avgCandleRange += (r[i].high - r[i].low);
                avgCandleRange /= 5.0;

                int smallCandleCount = 0;
                for(int i = 1; i <= 5; i++) {
                    if((r[i].high - r[i].low) < avgCandleRange * InpSmallCandlePct) {
                        smallCandleCount++;
                    }
                }

                // If pattern detected and risk manager allows
                if(smallCandleCount >= InpReentryMinBars && smallCandleCount <= InpReentryMaxBars)
                {
                    int signal = EnforceBoomCrashDirection(CSignalValidator::GetTrendDirection(InpTrendTF));
                    if(signal != 0 && g_riskManager.CanOpenTrade())
                    {
                        if(g_tradeExecutor.ExecuteTrade(signal))
                        {
                            // Reset re-entry logic for this symbol after successful trade
                            lastEntryTime = TimeCurrent(); // update last entry time
                        }
                    }
                }
            }
        }
    }

    // Close positions per symbol if per-trade thresholds reached, then cooldown before re-entry
    // Always enforce user-specified symbol rules (Boom/Crash vs others)
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;

            if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

            string psym = PositionGetString(POSITION_SYMBOL);
            double p = PositionGetDouble(POSITION_PROFIT);
        int ptype = (int)PositionGetInteger(POSITION_TYPE);
        double entry_price = PositionGetDouble(POSITION_PRICE_OPEN);

        // Determine if conservative mode is active
        bool useConservative = false;
        if(InpEnableConservativeRangeMode)
        {
            int d1 = CSignalValidator::GetTrendDirection(InpRangeModeTF1);
            int d2 = CSignalValidator::GetTrendDirection(InpRangeModeTF2);
            // Conservative mode is active if trends are non-aligned or neutral
            if(d1==0 || d2==0 || d1!=d2) useConservative = true;
        }

        // Define loss and profit targets based on symbol rules
        bool isBCsym = IsBoomCrashIndex(psym);
        double lossThresh = InpMaxLossUSDPerTrade; // universel: quitter à -$ fixé
        double profitThresh = isBCsym ? 1e9 : 5.0; // Boom/Crash: close on spike instead of fixed profit

        // Check if trade should be closed for loss or profit
        bool closeForLoss = (p <= -lossThresh);
        bool closeForProfit = (p >= profitThresh);

        // For Boom/Crash: close immediately after spike appearance relative to entry and direction
        if(isBCsym)
        {
            int dir = (ptype==POSITION_TYPE_BUY)? 1 : -1;
            if(VerifySpikeArrival(dir, entry_price))
            {
                closeForProfit = true; // treat spike detection as exit signal
            }
        }

            if(closeForLoss || closeForProfit)
            {
            // Close this specific position
                double vol = PositionGetDouble(POSITION_VOLUME);
                MqlTradeRequest rq; MqlTradeResult rs; // ZeroMemory(rq); // ZeroMemory(rs);
                rq.action = TRADE_ACTION_DEAL; rq.position = tk; rq.symbol = psym; rq.volume = vol;
                rq.type = (ptype==POSITION_TYPE_BUY)? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                rq.magic = InpMagicNumber; rq.comment = "PerTradeAutoClose";

                if(OrderSend(rq, rs))
                {
            if(closeForLoss)
                {
                    Print("?? Perte par trade atteinte (", DoubleToString(-p,2), ") sur ", psym, " -> fermeture et cooldown.");
                    // Arm re-entry cooldown if a loss occurred
                    SetSymbolCooldown(psym, InpReentryCooldownMin * 60); // Cooldown for this symbol
                // Count consecutive loss for symbol and potentially trigger cooldown after consecutive losses
                IncrementConsecutiveLoss(psym);
                int lidx = FindLossIndex(psym);
                if(lidx>=0 && g_lossCounts[lidx] >= InpMaxConsecutiveLosses)
                {
                    Print("?? ", InpMaxConsecutiveLosses, " PERTES CONSÉCUTIVES sur ", psym, " ? COOLDOWN ", InpConsecutiveLossCooldownMin, " minutes");
                    Print("?? SYMBOLE ", psym, " TEMPORAIREMENT DÉSACTIVÉ - Retour dans ", InpConsecutiveLossCooldownMin, " minutes");
                    SetSymbolCooldown(psym, InpConsecutiveLossCooldownMin * 60);
                    
                    // Reset le compteur après avoir activé le cooldown
                    g_lossCounts[lidx] = 0;
                }
                else if(lidx>=0) {
                    Print("?? PERTE #", g_lossCounts[lidx], " sur ", psym, " - ", (InpMaxConsecutiveLosses - g_lossCounts[lidx]), " perte(s) avant cooldown");
                }
                }
                else // closeForProfit
                {
                    Print("? Gain par trade atteint (", DoubleToString(p,2), ") sur ", psym, " -> sécurisation.");
                    // If Boom/Crash and re-entry enabled, arm it after a quick TP
                    if(IsBoomCrashIndex(psym) && InpEnableSpikeReentry)
                        g_bcReentryArmedTime = TimeCurrent(); // Arm the general re-entry timer
                // Reset consecutive loss counters on profit
                ResetConsecutiveLoss(psym);
                }
            }
            else
            {
                Print("? Échec fermeture per-trade (", psym, "): ", GetLastError(), " - ", rs.comment);
            }
        }
    }

    // Global cooldown check: if any trade was closed due to loss, enforce global cooldown
    // A simple way to implement this is to check if any position was closed for loss in the last loop
    // and then prevent further trades. For simplicity, we rely on individual symbol cooldowns and the general risk manager cooldown.
    // If you need a global cooldown *after* any loss, you'd need a separate timer.

    // Vérifier si on peut trader (basé sur les règles du Risk Manager)
    if(!g_riskManager.CanOpenTrade()) return;
    
    // VÉRIFICATION STRICTE: Maximum 2 trades simultanés - Pas de duplication
    int currentPositions = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong tk = PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            currentPositions++;
        }
    }
    
    if(currentPositions >= 2) {
        Print("?? BLOCAGE STRICT - ", currentPositions, " positions ouvertes (MAXIMUM: 2)");
        Print("?? AUCUNE NOUVELLE POSITION - Attendre fermeture d'une position existante");
        Print("?? DÉTAIL POSITIONS:");
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(PositionSelectByTicket(tk)) {
                if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                    string sym = PositionGetString(POSITION_SYMBOL);
                    double profit = PositionGetDouble(POSITION_PROFIT);
                    Print("   - ", sym, " (Ticket: ", tk, ") - Profit: $", DoubleToString(profit, 2));
                }
            }
        }
        return;
    }

    // Per-symbol aggregate open-loss guard: if total open loss per symbol <= -$2 (or InpMaxLossUSDPerTrade),
    // close all positions for that symbol and arm a cooldown to prevent immediate re-entry.
    // This enforces "ne depasse pas deux dollar de perte par symbole" across concurrent positions.
    {
        string symbols[128];
        double lossBySymbol[128];
        int symCount = 0;
        for(int i=PositionsTotal()-1;i>=0;i--)
        {
            ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
            string s = PositionGetString(POSITION_SYMBOL);
            double pnl = PositionGetDouble(POSITION_PROFIT);
            int idx=-1; for(int k=0;k<symCount;k++){ if(symbols[k]==s){ idx=k; break; } }
            if(idx<0 && symCount<128){ idx=symCount; symbols[symCount]=s; lossBySymbol[symCount]=0.0; symCount++; }
            if(idx>=0) lossBySymbol[idx] += pnl;
        }
        double perSymbolCap = MathMax(0.01, InpMaxLossUSDPerTrade); // default 2.0
        for(int k=0;k<symCount;k++)
        {
            if(lossBySymbol[k] <= -perSymbolCap)
            {
                Print("?? Perte agrégée par symbole atteinte (", symbols[k], ") = ", DoubleToString(lossBySymbol[k],2), " ? -$", DoubleToString(perSymbolCap,2), " ? fermeture de sécurité");
                ClosePositionsForSymbol(symbols[k], InpMagicNumber);
                // Arm per-symbol cooldown to avoid immediate re-entry
                SetSymbolCooldown(symbols[k], InpReentryCooldownMin * 60);
            }
        }
    }

    // Global open-loss guard: if total open loss <= -InpMaxGlobalOpenLossUSD, close all our positions and arm global cooldown
    if(InpMaxGlobalOpenLossUSD > 0.0)
    {
        double totalOpenPnl = 0.0;
        for(int i=PositionsTotal()-1;i>=0;i--){ ulong t=PositionGetTicket(i); if(!PositionSelectByTicket(t)) continue; if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue; totalOpenPnl += PositionGetDouble(POSITION_PROFIT); }
        if(totalOpenPnl <= -MathAbs(InpMaxGlobalOpenLossUSD))
        {
            Print("?? Seuil global de perte atteint (", DoubleToString(totalOpenPnl,2), ") ? fermeture de sécurité");
            for(int i=PositionsTotal()-1;i>=0;i--){ 
                ulong t=PositionGetTicket(i); 
                if(!PositionSelectByTicket(t)) continue; 
                if((int)PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue; 
                double vol=PositionGetDouble(POSITION_VOLUME); 
                MqlTradeRequest rq; MqlTradeResult rs; 
                rq.action=TRADE_ACTION_DEAL; 
                rq.position=t; 
                rq.symbol=PositionGetString(POSITION_SYMBOL); 
                rq.volume=vol; 
                rq.type=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)? ORDER_TYPE_SELL: ORDER_TYPE_BUY; 
                rq.magic=InpMagicNumber; 
                rq.comment="GlobalStop"; 
                if(!OrderSend(rq, rs)) {
                    Print("? Échec fermeture globale: ", GetLastError());
                }
            }
            g_globalCooldownUntil = TimeCurrent() + InpGlobalCooldownMin*60;
            return;
        }
    }
    
    // Détecter les signaux
    int signal = g_signalDetector.DetectSignal();
    
    // VÉRIFICATION STRICTE DE TENDANCE: Ne jamais trader contre la tendance M5 et M1
    if(signal != 0) {
        int trendM5 = CSignalValidator::GetTrendDirection(PERIOD_M5);
        int trendM1 = CSignalValidator::GetTrendDirection(PERIOD_M1);
        
        // Bloquer si tendance M5 incertaine ou opposée
        if(trendM5 == 0) {
            Print("?? SIGNAL BLOQUÉ - Tendance M5 incertaine");
            signal = 0;
        } else if(signal * trendM5 < 0) {
            Print("?? SIGNAL BLOQUÉ - Contre tendance M5 (Signal: ", signal, " vs Tendance: ", trendM5, ")");
            signal = 0;
        }
        
        // Bloquer si tendance M1 incertaine ou opposée
        if(signal != 0 && trendM1 == 0) {
            Print("?? SIGNAL BLOQUÉ - Tendance M1 incertaine");
            signal = 0;
        } else if(signal != 0 && signal * trendM1 < 0) {
            Print("?? SIGNAL BLOQUÉ - Contre tendance M1 (Signal: ", signal, " vs Tendance: ", trendM1, ")");
            signal = 0;
        }
        
        // Vérifier l'alignement M5 et M1
        if(signal != 0 && trendM5 != trendM1) {
            Print("?? SIGNAL BLOQUÉ - Tendance M5 et M1 non alignées (M5: ", trendM5, " vs M1: ", trendM1, ")");
            signal = 0;
        }
        
        // Confirmation finale: signal doit être dans le sens des deux tendances
        if(signal != 0) {
            Print("? SIGNAL VALIDÉ - Aligné avec tendance M5 (", trendM5, ") et M1 (", trendM1, ")");
        }
    }
    
    // Filtre de tendance supplémentaire si activé
    if(InpUseTrendOnly && signal != 0)
    {
        int trend = CTradeExecutor::GetTrendDirection(InpTrendTF);
        if(trend==0) signal = 0; // pas de trade si tendance incertaine
        else if(signal*trend < 0) signal = 0; // bloquer contre-tendance
    }
    
    // Calculer la confiance du signal
    double signal_confidence = g_signalDetector.GetSignalConfidence();
    
    // Vérifier le seuil de confiance minimum
    if(signal != 0 && !IsSignalConfidenceValid(signal_confidence)) {
        Print("? Signal rejeté: Confiance insuffisante (", DoubleToString(signal_confidence, 1), "% < ", DoubleToString(InpMinConfidenceThreshold, 1), "%)");
        signal = 0; // Annuler le signal
    }
    // SpikeOnly: exiger un pré-signal spike et confiance ? 90%
    if(InpSpikeOnlyMode)
    {
        if(!(g_isEarlySignal && signal_confidence >= MathMax(90.0, InpMinConfidenceThreshold)))
        {
            // Dessiner une pré-flèche pour visualiser le near-miss si besoin
            if(signal!=0) DrawPreSignalArrow(signal);
            signal = 0;
        }
    }
    
    if(signal != 0) {
        Print("? Signal détecté: Direction ", (signal > 0 ? "BUY" : "SELL"), " | Confiance: ", DoubleToString(signal_confidence, 1), "%");
    }

    // 0) Analyse de tendance API: validation préalable
    int apiTrend=0, apiStrength=0; bool hasTrend = GetTrendAnalysis(_Symbol, apiTrend, apiStrength);
    if(hasTrend && InpExtSigAsHardFilter)
    {
        // Si l'API indique une tendance forte, l'utiliser comme filtre
        if(apiStrength >= 80 && signal != 0 && signal != apiTrend)
        {
            Print("? Signal rejeté: Contre-tendance API (API:", apiTrend, " vs Local:", signal, ")");
            signal = 0;
        }
    }

    // 1) Signaux externes API: possibilité d'anticiper ou filtrer
    if(InpUseExternalSignals)
    {
        int exDir=0, exConf=0; bool hasExt = GetExternalSignal(_Symbol, exDir, exConf);
        if(hasExt && exConf >= InpExtSigMinConfidence)
        {
            if(signal==0) signal = exDir; // anticipation si local vide
            else if(InpExtSigAsHardFilter && ((exDir>0 && signal<0) || (exDir<0 && signal>0))) signal = 0; // exiger accord
        }
        else if(InpExtSigAsHardFilter)
        {
            signal = 0; // hard filter actif sans accord
        }
    }

    // Option IA: anticipation / filtre / ordres LIMIT avec prix absolus
    if(InpUseAIForAnticipation)
    {
        int aiDir=0, aiConf=0; bool hasAI = GetAIDecision(_Symbol, aiDir, aiConf);
        if(hasAI && aiConf >= InpAIMinTradeConfidence)
        {
            // 1) Anticiper si aucun signal local
            if(signal==0)
                signal = aiDir;
            // 2) Filtrer si demandé: exiger accord IA
            else if(InpAIAsHardFilter && (aiDir==0 || (aiDir>0 && signal<0) || (aiDir<0 && signal>0)))
                signal = 0;
            
            // 3) Tentative de placement d'un ordre LIMIT basé sur prix absolus si fournis par l'IA
            if(InpAIEnablePendingOrders)
            {
                // Re-demander la string brute via RefreshAIPanel? Non, on parse dans GetAIDecision. Simplification: re-appeler GetAIDecision et reparser le dernier body n'est pas stocké.
                // Ici on s'en remet à la logique: si la reco contient ENTRY/SL/TP, la fonction dédiée d'exécution sera appelée via une API spécifique.
                // Pour garder le flux simple, on n'essaie pas si signal local déjà pris par marché ouvert. Les LIMIT sont utiles quand pas d'entrée immédiate.
            }
        }
        else if(InpAIAsHardFilter)
        {
            // Si hard filter et pas d'accord IA, bloquer
            signal = 0;
        }
    }
    // Notification pré-signal (désactivée par défaut)
    if(InpNotifyRawSignals && InpSendNotifications && signal!=0)
    {
        string side0 = (signal>0?"BUY":"SELL");
        NotifyOnce(StringFormat("?? Pré-signal détecté: %s %s", _Symbol, side0));
    }
    // Enforcer la règle Boom/Crash: BUY uniquement sur Boom*, SELL uniquement sur Crash*
    signal = EnforceBoomCrashDirection(signal);
    if(signal == 0) return;

    // GOD Mode gate: require a high composite score before continuing
    if(InpEnableGodMode)
    {
        int gscore = CSignalValidator::ComputeGodScore(signal);
        if(gscore < MathMax(50, InpGodMinScore))
        {
            // Optionally draw a pre-signal arrow to visualize near-miss
            DrawPreSignalArrow(signal);
            return;
        }
    }
    
    // Si la validation est activée, ajouter le signal en attente au lieu d'exécuter directement
    if(InpValidateTradeWin || InpVerifySpikeBeforeSignal || InpSpikeOnlyMode) {
        double entry_price = (signal > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
        // Annonce pré-spike (flèche unique) si ICT actif et score suffisant
        if(InpEnableICT && InpICTAnnouncePreSpike && signal_confidence >= MathMax(90.0, InpMinConfidenceThreshold)) {
            DrawPreSignalArrow(signal); // flèche unique (contrôle ON/OFF par input)
            DrawSpikeZoneIfAny(); // dessine la zone de spike candidate
            if(InpSendNotifications && InpNotifyRawSignals) {
                string sideAnn = (signal>0?"BUY":"SELL");
                NotifyOnce(StringFormat("?? Pré-spike attendu dans ~1 min: %s %s", _Symbol, sideAnn));
            }
        }
        // Suppressed ICT drawings (BOS/COS/OTE)
        AddPendingSignal(signal, signal_confidence, entry_price);
        return;
    }

    // Bloquer contre-tendance M1+M5 et règles Boom/Crash demandées
    if(InpEnforceM1Trend && !CSignalValidator::IsAlignedWithM1M5(signal))
    {
        Print("? Signal rejeté: Contre-tendance M1/M5 détectée.");
        return;
    }
    
    // Valider le signal
    if(!g_isEarlySignal)
    {
    if(!CSignalValidator::ValidateSignal(signal)) {
            Print("? Signal rejeté par validation (Confiance=", CSignalValidator::ComputeGodScore(signal), ")");
        return;
        }
    }

    // Optionnel: exiger une entrée dans la zone de retracement Fibonacci 38.2-61.8
    if(InpRequireFibEntry)
    {
        if(!IsPriceInFibEntryZone(InpFibEntryTF, signal))
        {
            // Dessine une flèche pré-signal pour visualiser le refus
            DrawPreSignalArrow(signal);
            return;
        }
    }

    // Mode strict: garantir une seule position globale; si early signal, tenter une seule entrée puis reset le flag
    if(InpStrictSinglePosition)
    {
        // If any position with our magic exists, do nothing
        for(int i=0;i<PositionsTotal();i++){ ulong tk=PositionGetTicket(i); if(!PositionSelectByTicket(tk)) continue; if((int)PositionGetInteger(POSITION_MAGIC)==InpMagicNumber) { g_isEarlySignal=false; return; } }
    }

    // If early signal or regular signal, try a single trade (risk manager still checks strict constraints)
    if(g_tradeExecutor.ExecuteTrade(signal)) {
        g_riskManager.RecordTrade(0);
// Dessin du marqueur de trade exécuté
        DrawSignalArrow(signal);
        // Afficher dashboard si actif
        if(InpShowDashboard) UpdateDashboard();
        if(InpSendNotifications)
        {
            string side = (signal>0?"BUY":"SELL");
            NotifyOnce(StringFormat("? Trade %s exécuté sur %s", side, _Symbol));
        }
    }
    else if(InpAIEnablePendingOrders && g_aiLastDir!=0 && g_aiLastEntry>0.0)
    {
        // If market entry failed or not executed, but AI provided absolute prices, place pending order
        double slp = g_aiLastSL; double tpp = g_aiLastTP;
        // Minimal sanity: ensure SL/TP on correct side if provided
        double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
        // Enforce $2 max loss by adjusting SL distance if needed (per current lot calculation)
        double lot = g_tradeExecutor==NULL? InpLotSize : 0.0;
        if(lot<=0.0) lot = InpLotSize; // fallback
        double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        double dollarPerPointPerLot = (tickSize>0.0 && pt>0.0)? (tickValue * (pt / tickSize)) : 0.0;
        if(dollarPerPointPerLot>0.0 && lot>0.0)
        {
            double maxPts = MathFloor(MathAbs(2.0) / (dollarPerPointPerLot * lot));
            if(maxPts>0)
            {
                if(g_aiLastDir>0)
                {
                    if(slp>0.0)
                    {
                        double currentPts = (g_aiLastEntry - slp) / MathMax(pt,1e-12);
                        if(currentPts > maxPts) slp = NormalizeDouble(g_aiLastEntry - maxPts*pt, digits);
                    }
                }
                else
                {
                    if(slp>0.0)
                    {
                        double currentPts = (slp - g_aiLastEntry) / MathMax(pt,1e-12);
                        if(currentPts > maxPts) slp = NormalizeDouble(g_aiLastEntry + maxPts*pt, digits);
                    }
                }
            }
        }
        if(g_aiLastDir>0)
        {
            if(slp>0 && slp>=g_aiLastEntry) slp = NormalizeDouble(g_aiLastEntry - 5*pt, digits);
            if(tpp<=0.0)
            {
                // If TP missing, set TP = entry + 1.5x (entry - SL)
                if(slp>0.0) tpp = NormalizeDouble(g_aiLastEntry + 1.5*(g_aiLastEntry - slp), digits);
            }
            if(tpp>0 && tpp<=g_aiLastEntry) tpp = NormalizeDouble(g_aiLastEntry + 5*pt, digits);
        }
        else
        {
            if(slp>0 && slp<=g_aiLastEntry) slp = NormalizeDouble(g_aiLastEntry + 5*pt, digits);
            if(tpp<=0.0)
            {
                if(slp>0.0) tpp = NormalizeDouble(g_aiLastEntry - 1.5*(slp - g_aiLastEntry), digits);
            }
            if(tpp>0 && tpp>=g_aiLastEntry) tpp = NormalizeDouble(g_aiLastEntry - 5*pt, digits);
        }
        bool placed = g_tradeExecutor.ExecutePendingFromAI(g_aiLastDir, g_aiLastEntry, slp, tpp);
        if(placed && InpSendNotifications)
        {
            string s2 = (g_aiLastDir>0?"BUY_LIMIT":"SELL_LIMIT");
            string explain = (StringLen(g_aiLastNote)>0)? (" | IA: "+g_aiLastNote) : "";
            NotifyOnce(StringFormat("?? Ordre %s placé @ %s (SL=%s, TP=%s)%s", s2, DoubleToString(g_aiLastEntry,digits), (slp>0?DoubleToString(slp,digits):"0"), (tpp>0?DoubleToString(tpp,digits):"0"), explain));
        }
    }
    g_isEarlySignal = false;
}

//+------------------------------------------------------------------+
//| Helper functions                                                 |
//+------------------------------------------------------------------+

void DrawLabel(const string name, const string text, const int x, const int y, const color col)
{
    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
    if(ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
    {
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_COLOR, col);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, name, OBJPROP_BACK, true);
    }
}

void RefreshAIPanel()
{
    // Construire un petit contexte compact
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double pt  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int spreadPts = (int)MathRound((ask-bid)/MathMax(pt,1e-12));

    // Construire JSON minimal (MQL5 n'a pas de JSON natif, on envoie un texte simplifié)
    string payload = StringFormat("{\"symbol\":\"%s\",\"timeframe\":\"M1\",\"context\":{\"bid\":%s,\"ask\":%s,\"spread\":%d}}",
                                  _Symbol, DoubleToString(bid,_Digits), DoubleToString(ask,_Digits), spreadPts);

    uchar post[]; int n = StringToCharArray(payload, post, 0, StringLen(payload), CP_UTF8);
    if(n>0) ArrayResize(post, n); // ensure exact payload size
    string headers = "Content-Type: application/json\r\nAccept: application/json";
    string respHeaders = ""; char resp[]; ResetLastError();
    int code = WebRequest("POST", InpAIProxyURL, headers, 7000, post, resp, respHeaders);
    if(code==200)
    {
        string body = CharArrayToString(resp, 0, -1, CP_UTF8);
        string txt = StringSubstr(body, 0, 200);
        DrawLabel("AI_PANEL", StringFormat("AI: %s", txt), 8, 22, clrGold);
    }
    else
    {
        DrawLabel("AI_PANEL", StringFormat("AI: indisponible (HTTP %d / err %d)", (int)code, GetLastError()), 8, 22, clrSilver);
    }
}

// Récupère l'analyse de tendance depuis l'API (/trend)
// JSON attendu: { "trend": 1, "strength": 85, "timeframe": "M1", "symbol": "Boom 1000 Index" }
bool GetTrendAnalysis(const string symbol, int &outTrend, int &outStrength)
{
    outTrend = 0; outStrength = 0;
    if(!InpUseExternalSignals) return false;
    
    string headers = "Accept: application/json";
    string respHeaders = ""; char resp[]; ResetLastError();
    uchar emptyPayload[]; ArrayResize(emptyPayload, 0);
    int code = WebRequest("GET", InpTrendAnalysisURL, headers, 5000, emptyPayload, resp, respHeaders);
    if(code!=200) return false;

    string body = CharArrayToString(resp, 0, -1, CP_UTF8);
    // Recherche de l'entrée correspondant au symbole (insensible à la casse)
    string needle = StringFormat("\"symbol\":\"%s\"", symbol);
    int p = StringFind(body, needle);
    if(p < 0)
    {
        string bodyU = body; string symU = symbol;
        for(int iuc=0;iuc<StringLen(bodyU);iuc++){ ushort ch=(ushort)StringGetCharacter(bodyU,iuc); if(ch>='a'&&ch<='z') StringSetCharacter(bodyU,iuc,(ushort)(ch-'a'+'A')); }
        for(int juc=0;juc<StringLen(symU);juc++){ ushort ch2=(ushort)StringGetCharacter(symU,juc); if(ch2>='a'&&ch2<='z') StringSetCharacter(symU,juc,(ushort)(ch2-'a'+'A')); }
        string needleU = StringFormat("\"SYMBOL\":\"%s\"", symU);
        p = StringFind(bodyU, needleU);
    }
    if(p<0) return false;

    // Parse trend et strength
    int pTrend = StringFind(body, "\"trend\"", p);
    int pStrength = StringFind(body, "\"strength\"", p);
    if(pTrend>=0 && pStrength>=0)
    {
        int c1 = StringFind(body, ":", pTrend);
        int c2 = StringFind(body, ":", pStrength);
        if(c1>=0 && c2>=0)
        {
            string sTrend = StringSubstr(body, c1+1, 6);
            string sStrength = StringSubstr(body, c2+1, 6);
            outTrend = (int)StringToInteger(sTrend);
            outStrength = (int)StringToInteger(sStrength);
            return (outTrend != 0);
        }
    }
    return false;
}

// Récupère un signal externe pour le symbole courant depuis l'API (/signals)
// JSON attendu (extrait pertinent):
//   { "signals": [ {"symbol":"Boom 1000 Index","direction":1,"confidence":85,"ts":1699999999}, ... ] }
bool GetExternalSignal(const string symbol, int &outDir, int &outConf)
{
    outDir = 0; outConf = 0;
    if(!InpUseExternalSignals) return false;
    // Cache (uniquement pour le symbole courant)
    if(symbol == _Symbol && TimeCurrent() - g_extLastUpdate <= MathMax(1, InpExtSigTTLSeconds) && g_extLastDir!=0)
    {
        outDir = g_extLastDir; outConf = g_extLastConf; return true;
    }

    string headers = "Accept: application/json";
    string respHeaders = ""; char resp[]; ResetLastError();
    // MQL5 requires an array for the payload even for GET. Use empty payload.
    uchar emptyPayload[]; ArrayResize(emptyPayload, 0);
    int code = (int)WebRequest("GET", InpExternalSignalsURL, headers, 5000, emptyPayload, resp, respHeaders);
    if(code!=200) return false;

            string body = CharArrayToString(resp, 0, -1, CP_UTF8);
            // Recherche de l'entrée correspondant au symbole (relâchée: insensible à la casse)
            string needle = StringFormat("\"symbol\":\"%s\"", symbol);
            int p = StringFind(body, needle);
            if(p < 0)
            {
                // Insensible à la casse
                string bodyU = body; string symU = symbol;
                for(int iuc=0;iuc<StringLen(bodyU);iuc++){ ushort ch=(ushort)StringGetCharacter(bodyU,iuc); if(ch>='a'&&ch<='z') StringSetCharacter(bodyU,iuc,(ushort)(ch-'a'+'A')); }
                for(int juc=0;juc<StringLen(symU);juc++){ ushort ch2=(ushort)StringGetCharacter(symU,juc); if(ch2>='a'&&ch2<='z') StringSetCharacter(symU,juc,(ushort)(ch2-'a'+'A')); }
                string needleU = StringFormat("\"SYMBOL\":\"%s\"", symU);
                p = StringFind(bodyU, needleU);
            }
    if(p<0) return false;

    // direction
    int pDirKey = StringFind(body, "\"direction\"", p);
    int pConfKey= StringFind(body, "\"confidence\"", p);
    if(pDirKey<0 || pConfKey<0) return false;
    int c1 = StringFind(body, ":", pDirKey);
    int c2 = StringFind(body, ":", pConfKey);
    if(c1<0 || c2<0) return false;
    string sDir = StringSubstr(body, c1+1, 6);
    string sConf= StringSubstr(body, c2+1, 6);
    int dir = (int)StringToInteger(sDir);
    int conf= (int)StringToInteger(sConf);
    if(dir==0) return false;

    g_extLastDir = dir; g_extLastConf = MathMax(0, MathMin(100, conf)); g_extLastUpdate = TimeCurrent();
    outDir = g_extLastDir; outConf = g_extLastConf; return true;
}

// Récupère une décision IA (direction, confiance). Utilise le cache pour limiter les requêtes.
bool GetAIDecision(const string symbol, int &outDir, int &outConf)
{
    outDir = 0; outConf = 0;
    if(!InpUseAIForAnticipation) return false;
    // Si cache valide (et <= TTL paramétré), renvoyer
    int ttlSecs = MathMax(60, InpAIDecisionTTLMin*60);
    if(TimeCurrent() - g_aiLastUpdate <= ttlSecs && g_aiLastDir!=0)
    {
        outDir = g_aiLastDir; outConf = g_aiLastConf; return true;
    }

    // Construire contexte minimal
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double pt  = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int spreadPts = (int)MathRound((ask-bid)/MathMax(pt,1e-12));

    string payload = StringFormat("{\"symbol\":\"%s\",\"timeframe\":\"M1\",\"context\":{\"bid\":%s,\"ask\":%s,\"spread\":%d}}",
                                  symbol, DoubleToString(bid,_Digits), DoubleToString(ask,_Digits), spreadPts);
    uchar post[]; int n = StringToCharArray(payload, post, 0, StringLen(payload), CP_UTF8); if(n>0) ArrayResize(post,n);
    string headers = "Content-Type: application/json\r\nAccept: application/json";
    string respHeaders = ""; char resp[]; ResetLastError();
    int code = WebRequest("POST", InpAIProxyURL, headers, 7000, post, resp, respHeaders);
    if(code!=200)
    {
        return false;
    }

    string body = CharArrayToString(resp, 0, -1, CP_UTF8);
    // Parsing flexible: 1) direction/conf numériques, 2) recommendation BUY/SELL/WAIT; with optional absolute prices: ENTRY=, SL=, TP=
    int dir = 0, conf = 0;
    int pDir = StringFind(body, "\"direction\"");
    int pConf= StringFind(body, "\"confidence\"");
    if(pDir>=0)
    {
        int c = StringFind(body, ":", pDir); if(c>=0){ string s = StringSubstr(body, c+1, 6); dir = (int)StringToInteger(s); }
    }
    if(pConf>=0)
    {
        int c = StringFind(body, ":", pConf); if(c>=0){ string s = StringSubstr(body, c+1, 6); conf = (int)StringToInteger(s); }
    }
    // Alternative schema: {"recommendation":"BUY|SELL|WAIT ...","confidence":<num|null>}
    double outEntry=0.0, outSLp=0.0, outTPp=0.0; // optional absolute prices from IA
    if(dir==0)
    {
        int pRec = StringFind(body, "\"recommendation\"");
        if(pRec>=0)
        {
            int c = StringFind(body, ":", pRec);
            if(c>=0)
            {
                // Extract a short slice and uppercase for matching
                string rec = StringSubstr(body, c+1, 128);
                // Convert to uppercase manually since StringToUpper doesn't exist in MQL5
                for(int i = 0; i < StringLen(rec); i++) {
                    ushort ch = StringGetCharacter(rec, i);
                    if(ch >= 'a' && ch <= 'z') {
                        ch = ch - 'a' + 'A';
                        StringSetCharacter(rec, i, ch);
                    }
                }
                // If API mentions 429/quota, treat as neutral (no signal)
                if(StringFind(rec, "429")>=0) { return false; }
                if(StringFind(rec, "BUY")>=0) dir = 1; else if(StringFind(rec, "SELL")>=0) dir = -1; else dir = 0;
                // Try to parse ENTRY, SL, TP as absolute prices in the same slice
                // Expected like: ENTRY=1234.56; SL=1220.00; TP=1250.00; NOTE=...
                int pe = StringFind(rec, "ENTRY="); if(pe>=0){ string seg=StringSubstr(rec, pe+6, 20); outEntry = StringToDouble(seg); }
                int ps = StringFind(rec, "SL=");    if(ps>=0){ string seg=StringSubstr(rec, ps+3, 20); outSLp  = StringToDouble(seg); }
                int pt = StringFind(rec, "TP=");    if(pt>=0){ string seg=StringSubstr(rec, pt+3, 20); outTPp  = StringToDouble(seg); }
                int pn = StringFind(rec, "NOTE=");  if(pn>=0){ g_aiLastNote = StringSubstr(rec, pn+5, 80); }
            }
        }
        // Try to parse confidence if present and numeric; null -> leave at 0
        if(pConf>=0)
        {
            int c2 = StringFind(body, ":", pConf);
            if(c2>=0)
            {
                string sc = StringSubstr(body, c2+1, 6);
                // If starts with 'n' (null), ignore; else parse integer
                if(StringLen(sc)>0 && StringGetCharacter(sc,0)!='n') conf = (int)StringToInteger(sc);
            }
        }
    }
    if(dir==0) return false;

    g_aiLastDir = dir; g_aiLastConf = MathMax(0, MathMin(100, conf)); g_aiLastUpdate = TimeCurrent();
    // Store last absolute prices if parsed (>0)
    if(outEntry>0.0) g_aiLastEntry = outEntry;
    if(outSLp>0.0)   g_aiLastSL    = outSLp;
    if(outTPp>0.0)   g_aiLastTP    = outTPp;
    outDir = g_aiLastDir; outConf = g_aiLastConf; return true;
}

// Closes all open positions for a given magic number.
void CloseAllPositions(int magic)
{
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

        string psym = PositionGetString(POSITION_SYMBOL);
        int ptype = (int)PositionGetInteger(POSITION_TYPE);
        double vol = PositionGetDouble(POSITION_VOLUME);

        MqlTradeRequest rq; MqlTradeResult rs; // ZeroMemory(rq); // ZeroMemory(rs);
        rq.action = TRADE_ACTION_DEAL;
        rq.position = tk;
        rq.symbol = psym;
        rq.volume = vol;
        rq.type = (ptype == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        rq.magic = magic;
        rq.comment = "BasketClose";

        if(!OrderSend(rq, rs))
        {
            Print("? Échec fermeture panier (", psym, "): ", GetLastError(), " - ", rs.comment);
        }
        else
        {
            Print("? Fermeture position ", psym, " (", (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL"), ", ", DoubleToString(vol, 2), ")");
        }
    }
}

// Closes all open positions for a specific symbol and magic number.
void ClosePositionsForSymbol(const string symbol, int magic)
{
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        ulong tk = PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;

        if((int)PositionGetInteger(POSITION_MAGIC) != magic || PositionGetString(POSITION_SYMBOL) != symbol) continue;

        int ptype = (int)PositionGetInteger(POSITION_TYPE);
        double vol = PositionGetDouble(POSITION_VOLUME);

        MqlTradeRequest rq; MqlTradeResult rs; // ZeroMemory(rq); // ZeroMemory(rs);
        rq.action = TRADE_ACTION_DEAL;
        rq.position = tk;
        rq.symbol = symbol;
        rq.volume = vol;
        rq.type = (ptype == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
        rq.magic = magic;
        rq.comment = "SymbolSpikeClose";

        if(!OrderSend(rq, rs))
        {
            Print("? Échec fermeture symbole (", symbol, "): ", GetLastError(), " - ", rs.comment);
        }
    }
}

// Simple per-symbol cooldown storage using fixed arrays
string  g_cdSymbols[128];
datetime g_cdUntil[128];

// Track consecutive losses per symbol and globally
string  g_lossSymbols[128];
int     g_lossCounts[128];
int     g_consecutiveLossesGlobal = 0;

int FindCooldownIndex(const string symbol)
{
    for(int i=0;i<ArraySize(g_cdSymbols);i++)
        if(g_cdSymbols[i] == symbol)
            return i;
    return -1;
}

void SetSymbolCooldown(const string symbol, const int seconds)
{
    datetime until = TimeCurrent() + (int)seconds;
    int idx = FindCooldownIndex(symbol);
    if(idx < 0)
    {
        for(int i=0;i<ArraySize(g_cdSymbols);i++)
        {
            if(g_cdSymbols[i] == "") { g_cdSymbols[i] = symbol; g_cdUntil[i] = until; break; }
        }
    }
    else
    {
        g_cdUntil[idx] = until;
    }
    Print("? Cooldown armé sur ", symbol, " jusqu'à ", (long)until);
}

bool IsSymbolInCooldown(const string symbol)
{
    int idx = FindCooldownIndex(symbol);
    if(idx < 0) return false;
    return (TimeCurrent() < g_cdUntil[idx]);
}

int FindLossIndex(const string symbol)
{
    for(int i=0;i<ArraySize(g_lossSymbols);i++)
        if(g_lossSymbols[i] == symbol)
            return i;
    return -1;
}

void IncrementConsecutiveLoss(const string symbol)
{
    int idx = FindLossIndex(symbol);
    if(idx < 0)
    {
        // Ajouter un nouveau symbole avec 1 perte
        for(int i=0;i<ArraySize(g_lossSymbols);i++)
        {
            if(g_lossSymbols[i] == "") { 
                g_lossSymbols[i] = symbol; 
                g_lossCounts[i] = 1; 
                Print("?? NOUVEAU COMPTEUR PERTES pour ", symbol, " - Perte #1");
                break; 
            }
        }
    }
    else
    {
        // Incrémenter le compteur existant
        g_lossCounts[idx]++;
        Print("?? COMPTEUR PERTES ", symbol, " - Perte #", g_lossCounts[idx]);
    }
    g_consecutiveLossesGlobal++;
}

void ResetConsecutiveLoss(const string symbol)
{
    int idx = FindLossIndex(symbol);
    if(idx >= 0) {
        if(g_lossCounts[idx] > 0) {
            Print("? COMPTEUR PERTES RÉINITIALISÉ pour ", symbol, " (gain réalisé)");
        }
        g_lossCounts[idx] = 0;
    }
    g_consecutiveLossesGlobal = 0;
}

// Vérifier si la limite globale de positions simultanées est atteinte
bool IsGlobalPositionLimitReached()
{
    int openTradesGlobal = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong tk = PositionGetTicket(i);
        if(!PositionSelectByTicket(tk)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        openTradesGlobal++;
    }
    
    if(openTradesGlobal >= InpMaxSimultaneousTrades) {
        Print("?? LIMITE STRICTE ATTEINTE - ", openTradesGlobal, " positions ouvertes (MAXIMUM: ", InpMaxSimultaneousTrades, ")");
        Print("?? AUCUNE NOUVELLE POSITION AUTORISÉE - Attendre fermeture d'une position existante");
        Print("?? Positions actuelles:");
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            string sym = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            Print("   - ", sym, " (Ticket: ", tk, ") - Profit: $", DoubleToString(profit, 2));
        }
        return true;
    }
    return false;
}

// Vérifier si un symbole est en cooldown après pertes consécutives
bool IsSymbolInConsecutiveLossCooldown(const string symbol)
{
    int loss_idx = FindLossIndex(symbol);
    if(loss_idx >= 0 && g_lossCounts[loss_idx] >= InpMaxConsecutiveLosses) {
        return true;
    }
    return false;
}

// Check if the current symbol is a Boom, Crash, or Volatility index.
bool IsBoomCrashIndex(string symbol)
{
    return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0 || 
            StringFind(symbol, "Volatility") >= 0 || StringFind(symbol, "Vol") >= 0 ||
            StringFind(symbol, "VIX") >= 0);
}

// Check if the current symbol is specifically a Volatility index (Deriv format)
bool IsVolatilityIndex(string symbol)
{
    // Reconnaître les indices Deriv Volatility avec pourcentages
    return (StringFind(symbol, "Volatility 10") >= 0 || StringFind(symbol, "Volatility 25") >= 0 ||
            StringFind(symbol, "Volatility 50") >= 0 || StringFind(symbol, "Volatility 75") >= 0 ||
            StringFind(symbol, "Volatility 100") >= 0 || StringFind(symbol, "Vol 10") >= 0 ||
            StringFind(symbol, "Vol 25") >= 0 || StringFind(symbol, "Vol 50") >= 0 ||
            StringFind(symbol, "Vol 75") >= 0 || StringFind(symbol, "Vol 100") >= 0 ||
            StringFind(symbol, "VIX") >= 0);
}

// Check if the current symbol is a Step Index
bool IsStepIndex(string symbol)
{
    return (StringFind(symbol, "Step") >= 0 || StringFind(symbol, "STEP") >= 0);
}

// Check if the current symbol is a Forex pair
bool IsForexSymbol(string symbol)
{
    // Reconnaître les paires Forex majeures et mineures
    string major_pairs[] = {"EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "USDCAD", "NZDUSD"};
    string minor_pairs[] = {"EURGBP", "EURJPY", "EURCHF", "EURAUD", "EURCAD", "EURNZD", 
                           "GBPJPY", "GBPCHF", "GBPAUD", "GBPCAD", "GBPNZD",
                           "AUDJPY", "AUDCHF", "AUDCAD", "AUDNZD",
                           "CADJPY", "CADCHF", "CADNZD",
                           "CHFJPY", "CHFNZD",
                           "NZDJPY", "NZDCHF", "NZDCAD"};
    
    // Vérifier les paires majeures
    for(int i = 0; i < ArraySize(major_pairs); i++) {
        if(StringFind(symbol, major_pairs[i]) >= 0) return true;
    }
    
    // Vérifier les paires mineures
    for(int i = 0; i < ArraySize(minor_pairs); i++) {
        if(StringFind(symbol, minor_pairs[i]) >= 0) return true;
    }
    
    // Vérifier les paires exotiques (contiennent 3 lettres de devise)
    if(StringLen(symbol) == 6) {
        string base = StringSubstr(symbol, 0, 3);
        string quote = StringSubstr(symbol, 3, 3);
        string currencies[] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "CAD", "NZD", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "TRY", "ZAR", "MXN", "BRL", "RUB", "CNY", "HKD", "SGD", "THB", "INR", "KRW"};
        
        bool base_found = false, quote_found = false;
        for(int i = 0; i < ArraySize(currencies); i++) {
            if(base == currencies[i]) base_found = true;
            if(quote == currencies[i]) quote_found = true;
        }
        if(base_found && quote_found) return true;
    }
    
    return false;
}

// Obtenir le niveau de volatilité d'un indice Deriv
int GetVolatilityLevel(string symbol)
{
    if(StringFind(symbol, "Volatility 10") >= 0 || StringFind(symbol, "Vol 10") >= 0) return 10;
    if(StringFind(symbol, "Volatility 25") >= 0 || StringFind(symbol, "Vol 25") >= 0) return 25;
    if(StringFind(symbol, "Volatility 50") >= 0 || StringFind(symbol, "Vol 50") >= 0) return 50;
    if(StringFind(symbol, "Volatility 75") >= 0 || StringFind(symbol, "Vol 75") >= 0) return 75;
    if(StringFind(symbol, "Volatility 100") >= 0 || StringFind(symbol, "Vol 100") >= 0) return 100;
    if(StringFind(symbol, "VIX") >= 0) return 50; // VIX considéré comme niveau moyen
    return 0; // Pas un indice de volatilité
}

// Trader spikes uniquement: BUY sur Boom*, SELL sur Crash*, Volatility bidirectionnel
int EnforceBoomCrashDirection(int desiredDirection)
{
    if(!IsBoomCrashIndex(_Symbol)) return desiredDirection; // No restriction on non-Boom/Crash symbols
    
    bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
    bool isCrash= (StringFind(_Symbol, "Crash")>= 0);
    bool isVolatility = IsVolatilityIndex(_Symbol);

    if(desiredDirection == 0) return 0; // No signal to enforce

    // For Volatility indices: Allow both BUY and SELL (bidirectionnel)
    if(isVolatility)
    {
        return desiredDirection; // Allow both directions for volatility
    }
    
    // For Boom: Only allow BUY signals (direction > 0)
    if(isBoom)
    {
        if(desiredDirection < 0) return 0; // Deny SELL signal
        return 1; // Allow BUY signal
    }
    // For Crash: Only allow SELL signals (direction < 0)
    else if(isCrash)
    {
        if(desiredDirection > 0) return 0; // Deny BUY signal
        return -1; // Allow SELL signal
    }

    return desiredDirection; // Should not reach here if IsBoomCrashIndex is true
}

// Snap a raw lot to symbol's min/step/max and Deriv Boom/Crash grid when applicable
double SnapLotToSymbol(const string symbol, const double desired)
{
    double volMin = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double volStep= SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double volMax = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lot = desired;
    if(IsBoomCrashIndex(symbol)) lot = SnapToDerivBoomCrashLots(lot);
    if(volStep>0.0) lot = MathFloor((lot - volMin)/volStep + 0.5)*volStep + volMin;
    if(lot < volMin) lot = volMin;
    if(volMax>0.0 && lot > volMax) lot = volMax;
    return NormalizeDouble(lot, 2);
}

// Validate SL/TP against stops level and freeze levels - AMÉLIORÉ pour éviter "failed request"
bool EnsureValidStops(const string symbol, const int direction, const double price, const double point, double &sl_price, double &tp_price)
{
    if(point <= 0 || price <= 0) return false;
    
    int stops = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    int freeze = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    int minPts = MathMax(1, stops + MathMax(0, InpStopsBufferPoints));
    double minDist = minPts * point;
    
    // Pour Boom/Crash, augmenter la distance minimum
    if(IsBoomCrashIndex(symbol)) {
        minDist *= 1.5; // 50% plus de distance pour Boom/Crash
    }
    
    bool valid = true;
    
    if(direction>0) // BUY
    {
        if(sl_price > 0) {
            if(price - sl_price < minDist) {
                sl_price = price - minDist;
                // Vérifier que SL n'est pas trop loin (max 100 points)
                int sl_pts = (int)MathRound((price - sl_price) / point);
                if(sl_pts > 100) {
                    sl_price = price - 100 * point;
                }
            }
            // Normaliser le SL
            sl_price = NormalizeDouble(sl_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
        }
        
        if(tp_price > 0) {
            if(tp_price - price < minDist) {
                tp_price = price + minDist;
            }
            // S'assurer que TP est bien au-dessus du prix
            if(tp_price <= price) {
                tp_price = price + minDist;
            }
            // Normaliser le TP
            tp_price = NormalizeDouble(tp_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
        }
    }
    else // SELL
    {
        if(sl_price > 0) {
            if(sl_price - price < minDist) {
                sl_price = price + minDist;
                // Vérifier que SL n'est pas trop loin (max 100 points)
                int sl_pts = (int)MathRound((sl_price - price) / point);
                if(sl_pts > 100) {
                    sl_price = price + 100 * point;
                }
            }
            // Normaliser le SL
            sl_price = NormalizeDouble(sl_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
        }
        
        if(tp_price > 0) {
            if(price - tp_price < minDist) {
                tp_price = price - minDist;
            }
            // S'assurer que TP est bien en-dessous du prix
            if(tp_price >= price) {
                tp_price = price - minDist;
            }
            // Normaliser le TP
            tp_price = NormalizeDouble(tp_price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
        }
    }
    
    return valid;
}

// Simple detection of the "staircase" pattern in M1: a sequence of small, directionally consistent candles.
bool IsStaircasePatternM1()
{
    if(!InpEnableStaircaseM1) return false;

    MqlRates r[];
    int lookback = MathMax(InpStaircaseLookback, 8); // Ensure enough candles are available
    if(CopyRates(_Symbol, PERIOD_M1, 0, lookback, r) < lookback) return false;

    // Calculate average range of the last few candles (excluding the most recent one)
    double avgCandleRange = 0;
    for(int i = 1; i <= 5; i++) // Use the last 5 candles for average
    {
        if(i >= lookback) break; // Prevent index out of bounds if lookback is small
        avgCandleRange += (r[i].high - r[i].low);
    }
    avgCandleRange /= MathMax(1.0, 5.0); // Avoid division by zero

    int smallCandleCount = 0;
    int consistentDirectionCount = 0;
    int currentDirection = 0; // 1 for bullish, -1 for bearish

    // Analyze candles from most recent backwards, excluding the very last one if it's a large spike or pattern not fitting
    for(int i = 1; i < lookback; i++) // Start from index 1 (previous bar)
    {
        double candleRange = r[i].high - r[i].low;

        // Count small candles
        if(candleRange < avgCandleRange * InpSmallCandlePct)
        {
            smallCandleCount++;
        }

        // Determine candle direction
        int candleDir = 0;
        if(r[i].close > r[i].open) candleDir = 1;
        else if(r[i].close < r[i].open) candleDir = -1;

        // Track consecutive candles in the same direction
        if(currentDirection == 0 && candleDir != 0) // First directional candle
        {
            currentDirection = candleDir;
            consistentDirectionCount++;
        }
        else if(candleDir == currentDirection) // Same direction as previous
        {
            consistentDirectionCount++;
        }
        else // Direction changed or candle is flat
        {
            // Reset or update direction if a new trend is established by a small candle
            if(candleDir != 0 && candleRange < avgCandleRange * InpSmallCandlePct)
            {
                currentDirection = candleDir;
                consistentDirectionCount = 1; // Reset count for the new direction
            }
            else
            {
                currentDirection = 0; // Reset if direction is broken or candle is flat
                consistentDirectionCount = 0;
            }
        }
    }

    // Check if pattern criteria are met
    return (smallCandleCount >= InpStaircaseMinSteps && consistentDirectionCount >= InpStaircaseMinSteps / 2);
}

// Draws a signal arrow (filled) at the current price.
static datetime g_lastArrowBarTime = 0;
static long     g_lastArrowBarIndex = -1;
static datetime g_lastNotificationTime = 0;
bool CanNotify()
{
    if(!InpSendNotifications) return false;
    int cd = MathMax(0, InpNotificationCooldownSec);
    if(cd==0) return true;
    return (TimeCurrent() - g_lastNotificationTime >= cd);
}
void NotifyOnce(const string message)
{
    if(!InpSendNotifications) return;
    if(CanNotify())
    {
        SendNotification(message);
        g_lastNotificationTime = TimeCurrent();
    }
}
void DrawSignalArrow(const int direction)
{
    // Enforce one arrow per bar
    datetime bt = iTime(_Symbol, PERIOD_CURRENT, 0);
    long bidx = iBarShift(_Symbol, PERIOD_CURRENT, bt);
    if(g_lastArrowBarIndex == bidx && g_lastArrowBarTime == bt) return;
    g_lastArrowBarIndex = bidx; g_lastArrowBarTime = bt;

    string name = StringFormat("Sig_%s_%d", _Symbol, (int)TimeCurrent());
    double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    datetime t = TimeCurrent();
    ENUM_OBJECT objType = (direction > 0) ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;

    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

    if(ObjectCreate(0, name, objType, 0, t, price))
    {
        color c = (direction > 0) ? clrLime : clrRed;
        ObjectSetInteger(0, name, OBJPROP_COLOR, c);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        // OBJ_ARROW_BUY/SELL affichent une grande flèche par défaut
        // Ajouter un label proche avec recommandation / confiance si disponible
        string lbl = StringFormat("SIGLBL_%s_%d", _Symbol, (int)TimeCurrent());
        string side = (direction>0?"BUY":"SELL");
        double conf = 0.0; // best effort: afficher valeur si disponible via dernière pending
        if(pending_signal_count>0) conf = pending_signals[pending_signal_count-1].confidence;
        string txt = StringFormat("%s | Conf: %.0f%%", side, conf);
        DrawLabel(lbl, txt, 12, 48, c);
    }
}

// Draws a pre-signal arrow (hollow/lighter color) for early indication.
void DrawPreSignalArrow(const int direction)
{
    if(!InpDrawPreSignalArrows) return; // disabled by default
    string name = StringFormat("PreSig_%s_%d", _Symbol, (int)TimeCurrent());
    double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    datetime t = TimeCurrent();
    ENUM_OBJECT objType = (direction > 0) ? OBJ_ARROW_UP : OBJ_ARROW_DOWN;

    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);

    if(ObjectCreate(0, name, objType, 0, t, price))
    {
        // Use lighter colors to differentiate pre-signals
        color c = (direction > 0) ? clrAqua : clrPink;
        ObjectSetInteger(0, name, OBJPROP_COLOR, c);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2); // Better visibility
        ObjectSetString(0, name, OBJPROP_TEXT, (direction > 0) ? "PreBUY" : "PreSELL");
        // Afficher un label d'annonce
        string lbl = StringFormat("PRESIGLBL_%s_%d", _Symbol, (int)TimeCurrent());
        string side = (direction>0?"BUY":"SELL");
        DrawLabel(lbl, StringFormat("Pré-signal %s (?1m)", side), 12, 82, c);
    }
}

// Simple dashboard panel
void UpdateDashboard()
{
    if(!InpShowDashboard) return;
    string name = "DASH_PANEL";
    string txt = "SpikeHunter Dashboard\n";
    txt += StringFormat("Symbol: %s\n", _Symbol);
    txt += StringFormat("Open positions: %d/%d\n", PositionsTotal(), InpMaxSimultaneousTrades);
    
    // Afficher le statut de la limite globale
    if(IsGlobalPositionLimitReached()) {
        txt += "?? LIMITE GLOBALE ATTEINTE\n";
    } else {
        txt += StringFormat("? Limite OK (%d/%d)\n", PositionsTotal(), InpMaxSimultaneousTrades);
    }
    txt += StringFormat("Cooldown: %s\n", IsSymbolInCooldown(_Symbol)? "ON" : "OFF");
    
    // Afficher le statut des pertes consécutives
    int loss_idx = FindLossIndex(_Symbol);
    if(loss_idx >= 0 && g_lossCounts[loss_idx] > 0) {
        txt += StringFormat("Pertes consécutives: %d/%d\n", g_lossCounts[loss_idx], InpMaxConsecutiveLosses);
        if(g_lossCounts[loss_idx] >= InpMaxConsecutiveLosses) {
            txt += StringFormat("?? SYMBOLE EN COOLDOWN après %d pertes\n", InpMaxConsecutiveLosses);
        }
    } else {
        txt += "Pertes consécutives: 0\n";
    }
    txt += StringFormat("TrendTF(%d): %d\n", (int)InpTrendTF, (int)CTradeExecutor::GetTrendDirection(InpTrendTF));
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, InpDashCorner);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpDashX);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpDashY);
    ObjectSetString(0, name, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
    
    // Afficher les résultats journaliers
    UpdateDailyResults();
}

//+------------------------------------------------------------------+
//| Afficher les résultats journaliers du robot                      |
//+------------------------------------------------------------------+
void UpdateDailyResults()
{
    string name = "DAILY_RESULTS_PANEL";
    
    // Calculer les statistiques journalières
    double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double dailyProfit = CalculateDailyProfit();
    double dailyLoss = CalculateDailyLoss();
    double dailyNet = dailyProfit + dailyLoss; // dailyLoss est négatif
    int dailyTrades = CalculateDailyTrades();
    
    // Debug: Afficher les valeurs calculées
    static datetime lastDebug = 0;
    if(TimeCurrent() - lastDebug >= 30) { // Debug toutes les 30 secondes
        Print("DEBUG RESULTATS: Balance=", currentBalance, " Equite=", currentEquity, 
              " Profit=", dailyProfit, " Perte=", dailyLoss, " Net=", dailyNet, " Trades=", dailyTrades);
        lastDebug = TimeCurrent();
    }
    
    
    // Afficher directement les informations sur le graphique sans cadran
    string infoText = StringFormat("Capital: $%.2f | Equite: $%.2f | Profit: $%.2f | Perte: $%.2f | Net: $%.2f | Trades: %d | Positions: %d", 
                                   currentBalance, currentEquity, dailyProfit, dailyLoss, dailyNet, dailyTrades, PositionsTotal());
    
    // Créer un label simple sans fond
    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    }
    
    // Positionner en haut à gauche
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 10);
    ObjectSetString(0, name, OBJPROP_TEXT, infoText);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial");
}


//+------------------------------------------------------------------+
//| Calculer le profit journalier                                   |
//+------------------------------------------------------------------+
double CalculateDailyProfit()
{
    double totalProfit = 0.0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    datetime todayEnd = todayStart + 86400; // +24 heures
    
    // Parcourir l'historique des trades d'aujourd'hui
    if(HistorySelect(todayStart, todayEnd)) {
        int totalDeals = HistoryDealsTotal();
        for(int i = 0; i < totalDeals; i++) {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0) {
                if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
                    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                    if(profit > 0) {
                        totalProfit += profit;
                    }
                }
            }
        }
    } else {
        // Si pas d'historique, utiliser les positions ouvertes
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket)) {
                if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                    double profit = PositionGetDouble(POSITION_PROFIT);
                    if(profit > 0) {
                        totalProfit += profit;
                    }
                }
            }
        }
    }
    
    return totalProfit;
}

//+------------------------------------------------------------------+
//| Calculer la perte journalière                                   |
//+------------------------------------------------------------------+
double CalculateDailyLoss()
{
    double totalLoss = 0.0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    datetime todayEnd = todayStart + 86400; // +24 heures
    
    // Parcourir l'historique des trades d'aujourd'hui
    if(HistorySelect(todayStart, todayEnd)) {
        int totalDeals = HistoryDealsTotal();
        for(int i = 0; i < totalDeals; i++) {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0) {
                if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
                    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                    if(profit < 0) {
                        totalLoss += profit; // profit est négatif, donc totalLoss sera négatif
                    }
                }
            }
        }
    } else {
        // Si pas d'historique, utiliser les positions ouvertes
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong ticket = PositionGetTicket(i);
            if(PositionSelectByTicket(ticket)) {
                if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                    double profit = PositionGetDouble(POSITION_PROFIT);
                    if(profit < 0) {
                        totalLoss += profit;
                    }
                }
            }
        }
    }
    
    return totalLoss;
}

//+------------------------------------------------------------------+
//| Calculer le nombre de trades journaliers                        |
//+------------------------------------------------------------------+
int CalculateDailyTrades()
{
    int tradeCount = 0;
    datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    datetime todayEnd = todayStart + 86400; // +24 heures
    
    // Parcourir l'historique des trades d'aujourd'hui
    if(HistorySelect(todayStart, todayEnd)) {
        int totalDeals = HistoryDealsTotal();
        for(int i = 0; i < totalDeals; i++) {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket > 0) {
                if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber) {
                    ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
                    if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) {
                        tradeCount++;
                    }
                }
            }
        }
    }
    
    return tradeCount;
}

// --- Multi-Timeframe Support/Resistance Zones ---
struct Zone { double low; double high; string tf; bool isSupport; datetime created; };
static Zone g_zones[60]; // Array to store zone data
static int g_zoneCount = 0;
static datetime g_lastZoneDraw = 0; // Timer for redrawing zones

// Checks if the given price is near any of the drawn MTF zones, respecting the direction.
bool IsNearAnyMTFZone(const double price, const int direction)
{
    double prox = InpEntryZoneProximityPct; // Proximity threshold from inputs
    for(int i = 0; i < g_zoneCount; i++)
    {
        double zoneCenter = 0.5 * (g_zones[i].low + g_zones[i].high);
        double zoneHeight = g_zones[i].high - g_zones[i].low;
        
        // Calculate distance as a percentage of the zone's value
        double distPct = MathAbs(price - zoneCenter) / MathMax(1e-8, zoneCenter);
        
        // Check if price is within proximity threshold
        if(distPct <= prox)
        {
            // Directional check:
            // For BUY signals (direction > 0), we need to be near a Support zone.
            // For SELL signals (direction < 0), we need to be near a Resistance zone.
            if(direction > 0 && g_zones[i].isSupport) return true;
            if(direction < 0 && !g_zones[i].isSupport) return true;
        }
    }
    return false; // Price is not near any relevant zone
}

// Draws a rectangle object on the chart.
void DrawRect(const string name, const double y1, const double y2, const color col, const int transp)
{
    // Delete existing object if it exists
    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
    
    // Define time window for the rectangle (e.g., from last lookback bar to current time)
    datetime t0 = iTime(_Symbol, PERIOD_M1, InpZonesLookbackBars - 1);
    datetime t1 = TimeCurrent();
    
    // Create the rectangle object
    if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t0, y1, t1, y2))
    {
        // Apply transparency by embedding alpha into the color
        uchar a = (uchar)MathRound(MathMin(90.0, MathMax(30.0, (double)transp)));
        color cARGB = (color)ColorToARGB(col, a);
        ObjectSetInteger(0, name, OBJPROP_COLOR, cARGB);
        ObjectSetInteger(0, name, OBJPROP_BACK, true); // Draw behind other objects
        ObjectSetInteger(0, name, OBJPROP_FILL, true); // Fill the rectangle
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    }
}

// Refreshes and redraws the multi-timeframe Support/Resistance zones.
void RefreshMTFZones()
{
    // Check if enough time has passed since the last redraw
    if(TimeCurrent() - g_lastZoneDraw < InpZoneRedrawSec) return;
    
    // Update the last redraw time
    g_lastZoneDraw = TimeCurrent();
    
    // Clear previously drawn zones
    for(int k = ObjectsTotal(0) - 1; k >= 0; k--)
    {
        string objName = ObjectName(0, k);
        // Check if the object name starts with our prefix "MTFZ_"
        if(StringFind(objName, "MTFZ_") == 0) ObjectDelete(0, objName);
    }
    
    // Reset the zone counter
    g_zoneCount = 0;
    
    // Define timeframes and corresponding tags for naming zones
    ENUM_TIMEFRAMES tfs[] = {PERIOD_D1, PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15, PERIOD_M5};
    string tags[] = {"D1", "H4", "H1", "M30", "M15", "M5"};
    
    // Iterate through each timeframe to identify zones
    for(int ti = 0; ti < ArraySize(tfs); ti++)
    {
        int lb = MathMax(50, InpZonesLookbackBars); // Ensure a minimum lookback
        MqlRates r[];
        // Copy rates for the current timeframe
        if(CopyRates(_Symbol, tfs[ti], 0, lb, r) < lb) continue; // Skip if not enough data
        
        // Draw trendlines for this TF
        DrawTrendlinesTF(tfs[ti], tags[ti]);
        
        // Find the highest high and lowest low within the lookback period (excluding the current/most recent bar)
        double highestHigh = r[1].high;
        double lowestLow = r[1].low;
        for(int i = 2; i < MathMin(lb, 200); i++) // Limit analysis to first 200 bars for performance
        {
            if(r[i].high > highestHigh) highestHigh = r[i].high;
            if(r[i].low < lowestLow) lowestLow = r[i].low;
        }
        
        // Calculate the band thickness based on percentage
        double band = InpZoneBandPct * 0.5; // Use half the percentage for each side of the zone
        
        // Draw Support Zone (based on lowest low)
        if(g_zoneCount < 60) // Ensure we don't exceed array bounds
        {
            double supportLow = lowestLow * (1.0 - band);
            double supportHigh = lowestLow * (1.0 + band);
            string zoneName = StringFormat("MTFZ_%s_SUP", tags[ti]);
            DrawRect(zoneName, supportLow, supportHigh, clrGreen, 75); // Green for support, 75% transparency
            // Store zone data
            g_zones[g_zoneCount].low = supportLow;
            g_zones[g_zoneCount].high = supportHigh;
            g_zones[g_zoneCount].tf = tags[ti];
            g_zones[g_zoneCount].isSupport = true;
            g_zones[g_zoneCount].created = TimeCurrent();
            g_zoneCount++;
        }
        
        // Draw Resistance Zone (based on highest high)
        if(g_zoneCount < 60)
        {
            double resistanceLow = highestHigh * (1.0 - band);
            double resistanceHigh = highestHigh * (1.0 + band);
            string zoneName = StringFormat("MTFZ_%s_RES", tags[ti]);
            DrawRect(zoneName, resistanceLow, resistanceHigh, clrRed, 75); // Red for resistance, 75% transparency
            // Store zone data
            g_zones[g_zoneCount].low = resistanceLow;
            g_zones[g_zoneCount].high = resistanceHigh;
            g_zones[g_zoneCount].tf = tags[ti];
            g_zones[g_zoneCount].isSupport = false;
            g_zones[g_zoneCount].created = TimeCurrent();
            g_zoneCount++;
        }
        
        // Also draw Fibonacci on higher-vol TFs for clarity (H1 and M5 as examples)
        if(tfs[ti]==PERIOD_H1 || tfs[ti]==PERIOD_M5)
            DrawFiboForMoveTF(tfs[ti], tags[ti]);
    }
}

// Helper: get approximate chart time window [t0, t1]
void GetChartTimeWindow(datetime &t0, datetime &t1)
{
    t1 = TimeCurrent();
    // Use the longest of lookback or a fixed bars count for safety
    int lb = MathMax(300, InpZonesLookbackBars);
    t0 = iTime(_Symbol, PERIOD_M1, lb-1);
}

string MakeObj(const string prefix)
{
    return StringFormat("%s_%s_%d", prefix, _Symbol, (int)TimeCurrent());
}

// Draw trendlines by connecting recent swing highs and lows for a TF
void DrawTrendlinesTF(const ENUM_TIMEFRAMES tf, const string tag)
{
    if(!InpDrawTrendlines) return;
    int bars = MathMax(200, InpZonesLookbackBars);
    MqlRates r[]; if(CopyRates(_Symbol, tf, 0, bars, r) < 100) return;
    // Find last two swing highs and lows
    int sh1=-1, sh2=-1, sl1=-1, sl2=-1;
    for(int i=3; i<MathMin(bars-3, 400); i++)
    {
        bool highSwing = (r[i].high > r[i-1].high && r[i].high > r[i+1].high && r[i].high > r[i-2].high && r[i].high > r[i+2].high);
        bool lowSwing  = (r[i].low  < r[i-1].low  && r[i].low  < r[i+1].low  && r[i].low  < r[i-2].low  && r[i].low  < r[i+2].low);
        if(highSwing){ sh2=sh1; sh1=i; }
        if(lowSwing){  sl2=sl1; sl1=i; }
        if(sh1>=0 && sh2>=0 && sl1>=0 && sl2>=0) break;
    }
    datetime t0, t1; GetChartTimeWindow(t0, t1);
    if(sh1>=0 && sh2>=0)
    {
        string n = StringFormat("TL_%s_H_%s", tag, _Symbol);
        if(ObjectFind(0, n)>=0) ObjectDelete(0, n);
        ObjectCreate(0, n, OBJ_TREND, 0, r[sh2].time, r[sh2].high, r[sh1].time, r[sh1].high);
        ObjectSetInteger(0, n, OBJPROP_COLOR, clrOrange);
        ObjectSetInteger(0, n, OBJPROP_WIDTH, 2);
    }
    if(sl1>=0 && sl2>=0)
    {
        string n = StringFormat("TL_%s_L_%s", tag, _Symbol);
        if(ObjectFind(0, n)>=0) ObjectDelete(0, n);
        ObjectCreate(0, n, OBJ_TREND, 0, r[sl2].time, r[sl2].low, r[sl1].time, r[sl1].low);
        ObjectSetInteger(0, n, OBJPROP_COLOR, clrDodgerBlue);
        ObjectSetInteger(0, n, OBJPROP_WIDTH, 2);
    }
}

// Detect a recent high-volatility move on M5 and draw Fibonacci retracements
void DrawFiboForMoveTF(const ENUM_TIMEFRAMES tf, const string tag)
{
    if(!InpDrawFibonacci) return;
    int bars = 200;
    MqlRates r[]; if(CopyRates(_Symbol, tf, 0, bars, r) < 60) return;
    // Identify the strongest move over last 50 bars by range
    int bestStart=20, bestEnd=1; double bestRange=0.0;
    for(int i=1;i<=50;i++)
    {
        int s = i+20; if(s>=bars) break; // window of 20 bars behind i
        double hi=r[i].high, lo=r[i].low;
        for(int k=i;k<=s;k++){ if(r[k].high>hi) hi=r[k].high; if(r[k].low<lo) lo=r[k].low; }
        double range = hi-lo;
        if(range>bestRange){ bestRange=range; bestStart=s; bestEnd=i; }
    }
    if(bestRange<=0) return;
    double hi=r[bestEnd].high, lo=r[bestEnd].low;
    for(int k=bestEnd;k<=bestStart;k++){ if(r[k].high>hi) hi=r[k].high; if(r[k].low<lo) lo=r[k].low; }
    bool upMove = (r[bestEnd].close < r[bestStart].close);
    double moveHigh = upMove? hi : hi;
    double moveLow  = upMove? lo : lo;
    // Fibo levels
    double f0 = moveHigh; double f100 = moveLow;
    if(!upMove){ f0=moveLow; f100=moveHigh; }
    double f236 = f0 + 0.236*(f100 - f0);
    double f382 = f0 + 0.382*(f100 - f0);
    double f500 = f0 + 0.500*(f100 - f0);
    double f618 = f0 + 0.618*(f100 - f0);
    double f786 = f0 + 0.786*(f100 - f0);
    datetime t0, t1; GetChartTimeWindow(t0, t1);
    // Draw fib lines
    struct FiboLine { string nm; double y; color c; };
    FiboLine lines[6] = {
        { StringFormat("FB_%s_0",tag), f0, clrSilver },
        { StringFormat("FB_%s_23",tag), f236, clrSilver },
        { StringFormat("FB_%s_38",tag), f382, clrSilver },
        { StringFormat("FB_%s_50",tag), f500, clrSilver },
        { StringFormat("FB_%s_61",tag), f618, clrSilver },
        { StringFormat("FB_%s_78",tag), f786, clrSilver }
    };
    for(int i=0;i<6;i++)
    {
        if(ObjectFind(0, lines[i].nm)>=0) ObjectDelete(0, lines[i].nm);
        ObjectCreate(0, lines[i].nm, OBJ_TREND, 0, t0, lines[i].y, t1, lines[i].y);
        ObjectSetInteger(0, lines[i].nm, OBJPROP_COLOR, lines[i].c);
        ObjectSetInteger(0, lines[i].nm, OBJPROP_STYLE, STYLE_DOT);
    }
    // TP zone (light yellow) between 38.2 and 61.8
    double tpLow = MathMin(f382, f618), tpHigh = MathMax(f382, f618);
    string tpN = StringFormat("FB_%s_TP", tag);
    DrawRect(tpN, tpLow, tpHigh, InpTPZoneColor, 60);
    // SL zone (light red) near 78.6..100 of the move
    double slLow = MathMin(f786, f100), slHigh = MathMax(f786, f100);
    string slN = StringFormat("FB_%s_SL", tag);
    DrawRect(slN, slLow, slHigh, InpSLZoneColor, 60);
}

bool IsPriceInFibEntryZone(const ENUM_TIMEFRAMES tf, const int direction)
{
    if(!InpDrawFibonacci) return true; // if drawing disabled, don't block
    int bars = 200; MqlRates r[]; if(CopyRates(_Symbol, tf, 0, bars, r) < 60) return true;
    // same detection as DrawFiboForMoveTF
    int bestStart=20, bestEnd=1; double bestRange=0.0;
    for(int i=1;i<=50;i++)
    {
        int s = i+20; if(s>=bars) break;
        double hi=r[i].high, lo=r[i].low;
        for(int k=i;k<=s;k++){ if(r[k].high>hi) hi=r[k].high; if(r[k].low<lo) lo=r[k].low; }
        double range = hi-lo; if(range>bestRange){ bestRange=range; bestStart=s; bestEnd=i; }
    }
    if(bestRange<=0) return true;
    double hi=r[bestEnd].high, lo=r[bestEnd].low; for(int k=bestEnd;k<=bestStart;k++){ if(r[k].high>hi) hi=r[k].high; if(r[k].low<lo) lo=r[k].low; }
    bool upMove = (r[bestEnd].close < r[bestStart].close);
    double f0 = upMove? hi : lo; double f100 = upMove? lo : hi;
    double f382 = f0 + 0.382*(f100 - f0); double f618 = f0 + 0.618*(f100 - f0);
    double px = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double lowZ = MathMin(f382, f618), highZ = MathMax(f382, f618);
    // Entry logic: if direction>0 (BUY), prefer price in the retracement zone of an up move.
    // If the detected move direction mismatches the trade direction, allow (return true) to avoid blocking too much.
    if(direction>0 && !upMove) return true;
    if(direction<0 && upMove) return true;
    return (px >= lowZ && px <= highZ);
}

//+------------------------------------------------------------------+
//| Détection de spike pour fermeture automatique                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Détection ultra-précise de spike pour entrée                    |
//+------------------------------------------------------------------+
bool DetectSpikeForEntry()
{
    if(!InpUltraPreciseMode) return false;
    
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 30, rates) < 30) return false;
    
    // Obtenir ATR pour validation
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
    if(atr_handle == INVALID_HANDLE) return false;
    
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    if(CopyBuffer(atr_handle, 0, 0, 3, atr_buffer) < 3) {
        IndicatorRelease(atr_handle);
        return false;
    }
    
    double current_atr = atr_buffer[0];
    IndicatorRelease(atr_handle);
    
    // Analyser la barre actuelle
    MqlRates current_bar = rates[0];
    double current_range = current_bar.high - current_bar.low;
    double current_body = MathAbs(current_bar.close - current_bar.open);
    
    // Calculer la moyenne des ranges des 20 barres précédentes
    double avg_range = 0.0;
    for(int i = 1; i < 21; i++) {
        avg_range += (rates[i].high - rates[i].low);
    }
    avg_range /= 20.0;
    
                // CRITÈRES ULTRA-STRICTS POUR ENTRÉE (MILIMÉTRÉ)
                // 1. Range actuel > moyenne + seuil de confirmation (plus strict)
                double range_threshold = avg_range * (1.0 + InpSpikeConfirmationThreshold/100.0);
                if(current_range <= range_threshold) {
                    Print("? Range insuffisant: ", DoubleToString(current_range, 5), " vs ", DoubleToString(range_threshold, 5));
                    return false;
                }
                
                // 2. Range actuel > ATR * multiplicateur minimum (plus strict)
                if(current_range <= current_atr * InpMinSpikeStrength) {
                    Print("? Force spike insuffisante: ", DoubleToString(current_range, 5), " vs ", DoubleToString(current_atr * InpMinSpikeStrength, 5));
                    return false;
                }
                
                // 3. Corps significatif (plus strict - 60% minimum)
                if(current_body <= current_range * 0.6) {
                    Print("? Corps insuffisant: ", DoubleToString(current_body, 5), " vs ", DoubleToString(current_range * 0.6, 5));
                    return false;
                }
                
                // 4. Vérification supplémentaire: momentum fort
                double momentum = MathAbs(rates[0].close - rates[1].close);
                double avg_momentum = 0;
                for(int i = 1; i < 6; i++) {
                    avg_momentum += MathAbs(rates[i].close - rates[i+1].close);
                }
                avg_momentum /= 5.0;
                
                if(momentum <= avg_momentum * 1.5) {
                    Print("? Momentum insuffisant: ", DoubleToString(momentum, 5), " vs ", DoubleToString(avg_momentum * 1.5, 5));
                    return false;
                }
    
    // 4. Direction claire du spike
    bool bullish_spike = current_bar.close > current_bar.open;
    bool bearish_spike = current_bar.close < current_bar.open;
    if(!bullish_spike && !bearish_spike) return false;
    
    // 5. Validation de la tendance (EMA rapide vs lente)
    int ema_fast = iMA(_Symbol, PERIOD_CURRENT, 10, 0, MODE_EMA, PRICE_CLOSE);
    int ema_slow = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
    if(ema_fast == INVALID_HANDLE || ema_slow == INVALID_HANDLE) return false;
    
    double ema_fast_buffer[], ema_slow_buffer[];
    ArraySetAsSeries(ema_fast_buffer, true);
    ArraySetAsSeries(ema_slow_buffer, true);
    
    if(CopyBuffer(ema_fast, 0, 0, 2, ema_fast_buffer) < 2 || 
       CopyBuffer(ema_slow, 0, 0, 2, ema_slow_buffer) < 2) {
        IndicatorRelease(ema_fast);
        IndicatorRelease(ema_slow);
        return false;
    }
    
    // Vérifier l'alignement de la tendance
    bool trend_bullish = ema_fast_buffer[0] > ema_slow_buffer[0];
    bool trend_bearish = ema_fast_buffer[0] < ema_slow_buffer[0];
    
    // Spike doit être dans le sens de la tendance
    if(bullish_spike && !trend_bullish) return false;
    if(bearish_spike && !trend_bearish) return false;
    
    IndicatorRelease(ema_fast);
    IndicatorRelease(ema_slow);
    
    // VÉRIFICATION DES SIGNALS BOOM/CRASH BASÉS S/R (CRITÈRES RENFORCÉS + TENDANCE)
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double zone_level = 0, zone_strength = 0;
    
    // Déterminer la tendance générale
    int general_trend = DetermineGeneralTrend();
    
    if(InpEnableBoomCrashSignals) {
        // Vérifier signal BOOM (BUY) près d'un support - CRITÈRES RENFORCÉS + TENDANCE
        if(bullish_spike && IsNearSupportZone(current_price, zone_level, zone_strength)) {
            if(zone_strength * 100 >= InpSupportBoomThreshold + 20) { // +20% de marge
                // Vérifier que c'est cohérent avec la tendance générale
                if(general_trend >= 0) { // Tendance haussière ou neutre
                    // Vérification supplémentaire de stabilité
                    if(IsConfidenceStable()) {
                        Print("?? SIGNAL BOOM CONFIRMÉ - BUY près du support - Range: ", DoubleToString(current_range, 5), 
                              " vs Moyenne: ", DoubleToString(avg_range, 5), 
                              " vs ATR: ", DoubleToString(current_atr, 5),
                              " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
                              " Support: ", DoubleToString(zone_level, 5), " Force: ", DoubleToString(zone_strength*100, 1), "%");
                        return true;
                    } else {
                        Print("?? SIGNAL BOOM DÉTECTÉ MAIS CONFIANCE INSTABLE - Trade bloqué");
                        return false;
                    }
                } else {
                    Print("?? SIGNAL BOOM DÉTECTÉ MAIS CONTRE TENDANCE GÉNÉRALE - Trade bloqué");
                    return false;
                }
            }
        }
        
        // Vérifier signal CRASH (SELL) près d'une résistance - CRITÈRES RENFORCÉS + TENDANCE
        if(!bullish_spike && IsNearResistanceZone(current_price, zone_level, zone_strength)) {
            if(zone_strength * 100 >= InpResistanceCrashThreshold + 20) { // +20% de marge
                // Vérifier que c'est cohérent avec la tendance générale
                if(general_trend <= 0) { // Tendance baissière ou neutre
                    // Vérification supplémentaire de stabilité
                    if(IsConfidenceStable()) {
                        Print("?? SIGNAL CRASH CONFIRMÉ - SELL près de la résistance - Range: ", DoubleToString(current_range, 5), 
                              " vs Moyenne: ", DoubleToString(avg_range, 5), 
                              " vs ATR: ", DoubleToString(current_atr, 5),
                              " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
                              " Résistance: ", DoubleToString(zone_level, 5), " Force: ", DoubleToString(zone_strength*100, 1), "%");
                        return true;
                    } else {
                        Print("?? SIGNAL CRASH DÉTECTÉ MAIS CONFIANCE INSTABLE - Trade bloqué");
                        return false;
                    }
                } else {
                    Print("?? SIGNAL CRASH DÉTECTÉ MAIS CONTRE TENDANCE GÉNÉRALE - Trade bloqué");
                    return false;
                }
            }
        }
        
        Print("?? SPIKE DÉTECTÉ MAIS CONDITIONS BOOM/CRASH NON REMPLIES - Attente d'une meilleure opportunité");
        return false;
    }
    
    // VÉRIFICATION DES ZONES S/R - PRIORITÉ MAXIMALE (mode classique) - CRITÈRES RENFORCÉS + TENDANCE
    if(InpPrioritizeSREntries) {
        bool near_sr = IsNearSRZone(current_price, bullish_spike, zone_level, zone_strength);
        if(near_sr) {
            // Vérifier que c'est cohérent avec la tendance générale
            bool trend_ok = false;
            if(bullish_spike && general_trend >= 0) trend_ok = true;      // BUY si tendance haussière/neutre
            if(!bullish_spike && general_trend <= 0) trend_ok = true;     // SELL si tendance baissière/neutre
            
            if(trend_ok) {
                // Vérification supplémentaire de stabilité pour zones S/R
                if(IsConfidenceStable()) {
                    Print("?? SPIKE CONFIRMÉ DANS ZONE S/R - Range: ", DoubleToString(current_range, 5), 
                          " vs Moyenne: ", DoubleToString(avg_range, 5), 
                          " vs ATR: ", DoubleToString(current_atr, 5),
                          " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
                          " Direction: ", (bullish_spike ? "HAUSSIER" : "BAISSIER"),
                          " Zone: ", DoubleToString(zone_level, 5), " Force: ", DoubleToString(zone_strength*100, 1), "%");
                    return true;
                } else {
                    Print("?? SPIKE DANS ZONE S/R MAIS CONFIANCE INSTABLE - Trade bloqué");
                    return false;
                }
            } else {
                Print("?? SPIKE DANS ZONE S/R MAIS CONTRE TENDANCE GÉNÉRALE - Trade bloqué");
                return false;
            }
        } else {
            Print("?? SPIKE DÉTECTÉ MAIS HORS ZONE S/R - Attente d'une meilleure opportunité");
            return false;
        }
    }
    
    Print("?? SPIKE CONFIRMÉ POUR ENTRÉE - Range: ", DoubleToString(current_range, 5), 
          " vs Moyenne: ", DoubleToString(avg_range, 5), 
          " vs ATR: ", DoubleToString(current_atr, 5),
          " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
          " Direction: ", (bullish_spike ? "HAUSSIER" : "BAISSIER"));
    
    return true;
}

//+------------------------------------------------------------------+
//| Détection de spike pour fermeture immédiate (OBSOLÈTE)          |
//| Cette fonction est maintenant obsolète - utiliser DetectSpikeForTrade() |
//+------------------------------------------------------------------+
bool DetectSpikeForClose()
{
    // REDIRECTION: Utiliser la nouvelle fonction unifiée
    // Déterminer la direction basée sur le type de position actuelle
    int direction = 0;
    for(int i = 0; i < smart_trade_count; i++) {
        if(smart_trades[i].ticket != 0 && PositionSelectByTicket(smart_trades[i].ticket)) {
            int type = (int)PositionGetInteger(POSITION_TYPE);
            direction = (type == POSITION_TYPE_BUY) ? 1 : -1;
                break;
            }
        }
        
    if(direction == 0) {
        Print("⚠️ DetectSpikeForClose() - Aucune position active trouvée");
    return false;
}

    // Utiliser la fonction unifiée
    bool result = DetectSpikeForTrade(_Symbol, direction);
    if(result) {
        Print("🔄 DetectSpikeForClose() redirigé vers DetectSpikeForTrade() - Spike détecté");
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Mise à jour dynamique des patterns en temps réel               |
//+------------------------------------------------------------------+
void UpdateDynamicPatterns()
{
    // Obtenir le prix actuel
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    datetime current_time = TimeCurrent();
    
    // Vérifier si un spike est déjà apparu - si oui, supprimer la flèche
    if(DetectSpikeForClose()) {
        RemoveDynamicArrow();
        return;
    }
    
    // Analyser le pattern actuel
    int pattern_direction = AnalyzeCurrentPattern();
    double pattern_confidence = CalculatePatternConfidence();
    
    // Afficher seulement les flèches dynamiques avec confiance élevée pour annoncer un spike imminent
    if(pattern_direction != 0 && pattern_confidence > 0.9) {
        CreateDynamicArrow(current_time, current_price, pattern_direction, pattern_confidence);
    }
}

//+------------------------------------------------------------------+
//| Analyser le pattern actuel                                      |
//+------------------------------------------------------------------+
int AnalyzeCurrentPattern()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M5, 0, 20, rates) < 20) return 0;
    
    // VÉRIFICATION STRICTE DE TENDANCE M5 ET M1
    int trendM5 = CSignalValidator::GetTrendDirection(PERIOD_M5);
    int trendM1 = CSignalValidator::GetTrendDirection(PERIOD_M1);
    
    // Ne pas analyser si tendances incertaines ou non alignées
    if(trendM5 == 0 || trendM1 == 0) {
        Print("?? Pattern ignoré - Tendance M5 ou M1 incertaine");
        return 0;
    }
    
    if(trendM5 != trendM1) {
        Print("?? Pattern ignoré - Tendance M5 et M1 non alignées");
        return 0;
    }
    
    // DÉTERMINER LA TENDANCE GÉNÉRALE (H1, H4)
    int general_trend = DetermineGeneralTrend();
    
    // Pattern 1: Tendance haussière récente
    if(rates[0].close > rates[2].close && rates[0].close > rates[4].close) {
        // Vérifier que c'est cohérent avec la tendance M5/M1 ET générale
        if(trendM5 > 0 && trendM1 > 0 && general_trend >= 0) {
            return 1; // Haussier
        } else {
            Print("?? Pattern haussier ignoré - Incohérence tendance");
            return 0;
        }
    }
    
    // Pattern 2: Tendance baissière récente
    if(rates[0].close < rates[2].close && rates[0].close < rates[4].close) {
        // Vérifier que c'est cohérent avec la tendance M5/M1 ET générale
        if(trendM5 < 0 && trendM1 < 0 && general_trend <= 0) {
            return -1; // Baissier
        } else {
            Print("?? Pattern baissier ignoré - Incohérence tendance");
            return 0;
        }
    }
    
    return 0; // Pas de pattern clair
}

//+------------------------------------------------------------------+
//| Calculer la confiance du pattern                                |
//+------------------------------------------------------------------+
double CalculatePatternConfidence()
{
    // Calculer la confiance basée sur la cohérence des tendances
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M5, 0, 10, rates) < 10) return 0.0;
    
    // Analyser la cohérence des mouvements récents
    int consistent_moves = 0;
    int total_moves = 0;
    
    for(int i = 0; i < 5; i++) {
        if(rates[i].close > rates[i+1].close) {
            consistent_moves++;
        }
        total_moves++;
    }
    
    double confidence = (double)consistent_moves / total_moves;
    return MathMin(confidence, 1.0);
}

//+------------------------------------------------------------------+
//| Créer une flèche dynamique pour prédiction de spike                |
//+------------------------------------------------------------------+
void CreateDynamicArrow(datetime time, double price, int direction, double confidence)
{
    string obj_name = "DynamicArrow_" + IntegerToString(TimeCurrent());
    color arrow_color = (direction > 0) ? clrLime : clrRed;
    
    if(ObjectCreate(0, obj_name, OBJ_ARROW, 0, time, price)) {
        ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, (direction > 0) ? 233 : 234);
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, arrow_color);
        ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, false);
    }
}

//+------------------------------------------------------------------+
//| Supprimer la flèche dynamique                                   |
//+------------------------------------------------------------------+
void RemoveDynamicArrow()
{
    for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
        string obj_name = ObjectName(0, i, 0, -1);
        if(StringFind(obj_name, "DynamicArrow_") == 0) {
            ObjectDelete(0, obj_name);
        }
    }
}

//+------------------------------------------------------------------+
//| Déterminer la tendance générale                                  |
//+------------------------------------------------------------------+
int DetermineGeneralTrend()
{
    int trendH1 = CSignalValidator::GetTrendDirection(PERIOD_H1);
    int trendH4 = CSignalValidator::GetTrendDirection(PERIOD_H4);
    
    if(trendH1 == trendH4) return trendH1;
    return 0; // Tendance incertaine
}

//+------------------------------------------------------------------+
//| Scanner tous les symboles pour la meilleure opportunité         |
//+------------------------------------------------------------------+
bool ScanAllSymbolsForBestOpportunity(SymbolSignal &best_signal)
{
    // Scanner les symboles disponibles et trouver la meilleure opportunité
    // Pour l'instant, retourner false pour éviter les erreurs
    return false;
}






//+------------------------------------------------------------------+
//| Mise à jour des données API (tous les endpoints)                |
//+------------------------------------------------------------------+
void UpdateAPIData()
{
    static datetime last_trend_update = 0;
    static datetime last_signals_update = 0;
    static datetime last_recommendations_update = 0;
    
    datetime current_time = TimeCurrent();
    
    // 1. Mise à jour de l'analyse de tendance (toutes les 30 secondes)
    if(current_time - last_trend_update >= 30) {
        UpdateTrendAnalysis();
        last_trend_update = current_time;
    }
    
    // 2. Mise à jour des signaux externes (toutes les 15 secondes)
    if(current_time - last_signals_update >= 15) {
        UpdateExternalSignals();
        last_signals_update = current_time;
    }
    
    // 3. Mise à jour des recommandations (toutes les 60 secondes)
    if(current_time - last_recommendations_update >= 60) {
        UpdateRecommendations();
        last_recommendations_update = current_time;
    }
}

//+------------------------------------------------------------------+
//| Mise à jour de l'analyse de tendance                            |
//+------------------------------------------------------------------+
void UpdateTrendAnalysis()
{
    if(!InpUseExternalSignals) return;
    
    string headers = "Accept: application/json";
    string respHeaders = "";
    char resp[];
    uchar emptyPayload[];
    ArrayResize(emptyPayload, 0);
    
    int code = (int)WebRequest("GET", InpTrendAnalysisURL, headers, 3000, emptyPayload, resp, respHeaders);
    
    if(code == 200) {
        string body = CharArrayToString(resp, 0, -1, CP_UTF8);
        Print("?? TREND ANALYSIS - ", StringSubstr(body, 0, 100));
        
        // Parser la réponse JSON pour extraire les données de tendance
        ParseTrendResponse(body);
    } else {
        Print("? Échec analyse de tendance: HTTP ", code);
    }
}

//+------------------------------------------------------------------+
//| Mise à jour des signaux externes                                |
//+------------------------------------------------------------------+
void UpdateExternalSignals()
{
    if(!InpUseExternalSignals) return;
    
    string headers = "Accept: application/json";
    string respHeaders = "";
    char resp[];
    uchar emptyPayload[];
    ArrayResize(emptyPayload, 0);
    
    int code = (int)WebRequest("GET", InpExternalSignalsURL, headers, 3000, emptyPayload, resp, respHeaders);
    
    if(code == 200) {
        string body = CharArrayToString(resp, 0, -1, CP_UTF8);
        Print("?? SIGNALS EXTERNES - ", StringSubstr(body, 0, 100));
        
        // Parser la réponse JSON pour extraire les signaux
        ParseSignalsResponse(body);
    } else {
        Print("? Échec signaux externes: HTTP ", code);
    }
}

//+------------------------------------------------------------------+
//| Mise à jour des recommandations                                 |
//+------------------------------------------------------------------+
void UpdateRecommendations()
{
    if(!InpUseApiRecommendations) return;
    
    string headers = "Accept: application/json";
    string respHeaders = "";
    char resp[];
    uchar emptyPayload[];
    ArrayResize(emptyPayload, 0);
    
    int code = (int)WebRequest("GET", InpRecommendationsURL, headers, 3000, emptyPayload, resp, respHeaders);
    
    if(code == 200) {
        string body = CharArrayToString(resp, 0, -1, CP_UTF8);
        Print("?? RECOMMANDATIONS - ", StringSubstr(body, 0, 100));
        
        // Parser la réponse JSON pour extraire les recommandations
        ParseRecommendationsResponse(body);
    } else {
        Print("? Échec recommandations: HTTP ", code);
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse de tendance                                   |
//+------------------------------------------------------------------+
void ParseTrendResponse(string json_response)
{
    // Rechercher les données de tendance dans le JSON
    if(StringFind(json_response, "\"trend\"") >= 0) {
        Print("? Données de tendance reçues et analysées");
        // Ici on peut extraire et stocker les données de tendance
    }
}

//+------------------------------------------------------------------+
//| FONCTIONS SMC RENFORCÉES - ANGELOFSPIKE V5.0                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Détection avancée d'Order Blocks                                |
//+------------------------------------------------------------------+
OrderBlock FindAdvancedOrderBlock(const string symbol, const int lookback = 50)
{
    OrderBlock ob = {0, 0, 0, false, false, 0, 0, 0.0, true, 0.0};
    MqlRates rates[];
    
    if(CopyRates(symbol, PERIOD_M1, 0, lookback, rates) < lookback) return ob;
    
    // Chercher les Order Blocks haussiers
    for(int i = lookback - 3; i > 2; i--)
    {
        // Condition 1: Bougie baissière (OB potentiel)
        if(rates[i].close < rates[i].open)
        {
            // Condition 2: Bougie suivante casse le plus haut avec forte impulsion
            if(rates[i-1].close > rates[i].high && rates[i-1].close > rates[i-1].open)
            {
                // Condition 3: Validation avec la bougie suivante
                if(rates[i-2].close > rates[i-1].close * 0.5) // Au moins 50% du mouvement conservé
                {
                    ob.high = rates[i].high;
                    ob.low = rates[i].low;
                    ob.entry = rates[i].high - (rates[i].high - rates[i].low) * 0.5; // Entrée au milieu
                    ob.isValid = true;
                    ob.isBullish = true;
                    ob.created_time = rates[i].time;
                    ob.strength = CalculateOBStrength(rates, i);
                    ob.success_rate = 0.75; // Taux de succès par défaut
                    return ob;
                }
            }
        }
        
        // Chercher les Order Blocks baissiers
        if(rates[i].close > rates[i].open)
        {
            // Condition 2: Bougie suivante casse le plus bas avec forte impulsion
            if(rates[i-1].close < rates[i].low && rates[i-1].close < rates[i-1].open)
            {
                // Condition 3: Validation avec la bougie suivante
                if(rates[i-2].close < rates[i-1].close * 1.5) // Au moins 50% du mouvement conservé
                {
                    ob.high = rates[i].high;
                    ob.low = rates[i].low;
                    ob.entry = rates[i].low + (rates[i].high - rates[i].low) * 0.5; // Entrée au milieu
                    ob.isValid = true;
                    ob.isBullish = false;
                    ob.created_time = rates[i].time;
                    ob.strength = CalculateOBStrength(rates, i);
                    ob.success_rate = 0.75; // Taux de succès par défaut
                    return ob;
                }
            }
        }
    }
    
    return ob;
}

//+------------------------------------------------------------------+
//| Calcul de la force d'un Order Block                             |
//+------------------------------------------------------------------+
double CalculateOBStrength(MqlRates &rates[], int ob_index)
{
    double strength = 0.0;
    
    // Facteur 1: Taille du corps de la bougie OB (30%)
    double body_size = MathAbs(rates[ob_index].close - rates[ob_index].open);
    double range_size = rates[ob_index].high - rates[ob_index].low;
    if(range_size > 0) {
        strength += (body_size / range_size) * 0.3;
    }
    
    // Facteur 2: Force de l'impulsion suivante (40%)
    double impulse_size = MathAbs(rates[ob_index-1].close - rates[ob_index-1].open);
    double avg_range = 0.0;
    for(int i = ob_index + 1; i < ob_index + 6; i++) {
        if(i < ArraySize(rates)) {
            avg_range += (rates[i].high - rates[i].low);
        }
    }
    avg_range /= 5.0;
    if(avg_range > 0) {
        strength += (impulse_size / avg_range) * 0.4;
    }
    
    // Facteur 3: Validation avec les bougies suivantes (30%)
    int validation_count = 0;
    for(int i = ob_index - 2; i >= MathMax(0, ob_index - 5); i--) {
        if(rates[i].close > rates[ob_index].high || rates[i].close < rates[ob_index].low) {
            validation_count++;
        }
    }
    strength += (validation_count / 4.0) * 0.3;
    
    return MathMin(strength, 1.0);
}

//+------------------------------------------------------------------+
//| Détection avancée de Fair Value Gaps                            |
//+------------------------------------------------------------------+
FairValueGap FindAdvancedFVG(const string symbol, const int lookback = 30)
{
    FairValueGap fvg = {0, 0, 0, false, false, 0, 0, 0.0, true, 0.0};
    MqlRates rates[];
    
    if(CopyRates(symbol, PERIOD_M1, 0, lookback, rates) < lookback) return fvg;
    
    // Chercher les FVG haussiers
    for(int i = lookback - 3; i > 0; i--)
    {
        // Condition FVG Haussier: Le plus bas de la bougie N-2 est plus haut que le plus haut de la bougie N
        if(rates[i-2].low > rates[i].high)
        {
            fvg.top = rates[i-2].low;
            fvg.bottom = rates[i].high;
            fvg.middle = (fvg.top + fvg.bottom) / 2.0;
            fvg.isValid = true;
            fvg.isBullish = true;
            fvg.created_time = rates[i].time;
            fvg.strength = CalculateFVGStrength(rates, i);
            fvg.success_rate = 0.70; // Taux de succès par défaut
            return fvg;
        }
        
        // Condition FVG Baissier: Le plus haut de la bougie N-2 est plus bas que le plus bas de la bougie N
        if(rates[i-2].high < rates[i].low)
        {
            fvg.top = rates[i].high;
            fvg.bottom = rates[i-2].high;
            fvg.middle = (fvg.top + fvg.bottom) / 2.0;
            fvg.isValid = true;
            fvg.isBullish = false;
            fvg.created_time = rates[i].time;
            fvg.strength = CalculateFVGStrength(rates, i);
            fvg.success_rate = 0.70; // Taux de succès par défaut
            return fvg;
        }
    }
    
    return fvg;
}

//+------------------------------------------------------------------+
//| Calcul de la force d'un Fair Value Gap                          |
//+------------------------------------------------------------------+
double CalculateFVGStrength(MqlRates &rates[], int fvg_index)
{
    double strength = 0.0;
    
    // Facteur 1: Taille du gap (40%)
    double gap_size = rates[fvg_index-2].low - rates[fvg_index].high; // Pour FVG haussier
    if(gap_size <= 0) gap_size = rates[fvg_index].low - rates[fvg_index-2].high; // Pour FVG baissier
    
    double avg_range = 0.0;
    for(int i = fvg_index + 1; i < fvg_index + 6; i++) {
        if(i < ArraySize(rates)) {
            avg_range += (rates[i].high - rates[i].low);
        }
    }
    avg_range /= 5.0;
    
    if(avg_range > 0) {
        strength += (gap_size / avg_range) * 0.4;
    }
    
    // Facteur 2: Force des bougies environnantes (30%)
    double body1 = MathAbs(rates[fvg_index].close - rates[fvg_index].open);
    double body2 = MathAbs(rates[fvg_index-2].close - rates[fvg_index-2].open);
    double total_body = body1 + body2;
    if(total_body > 0) {
        strength += (total_body / (rates[fvg_index].high - rates[fvg_index].low + rates[fvg_index-2].high - rates[fvg_index-2].low)) * 0.3;
    }
    
    // Facteur 3: Validation avec les bougies suivantes (30%)
    int validation_count = 0;
    for(int i = fvg_index - 3; i >= MathMax(0, fvg_index - 6); i--) {
        if(rates[i].close >= rates[fvg_index].high && rates[i].close <= rates[fvg_index-2].low) {
            validation_count++;
        }
    }
    strength += (validation_count / 4.0) * 0.3;
    
    return MathMin(strength, 1.0);
}

//+------------------------------------------------------------------+
//| Détection des pools de liquidité                                |
//+------------------------------------------------------------------+
LiquidityPool FindLiquidityPool(const string symbol, const int lookback = 100)
{
    LiquidityPool lp = {0, false, false, 0, 0, 0.0, true, 0.0};
    MqlRates rates[];
    
    if(CopyRates(symbol, PERIOD_M1, 0, lookback, rates) < lookback) return lp;
    
    // Chercher les niveaux de liquidité (plus hauts et plus bas récents)
    double swing_highs[10], swing_lows[10];
    int high_count = 0, low_count = 0;
    
    // Identifier les swings
    for(int i = 2; i < lookback - 2; i++)
    {
        // Swing High
        if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
           rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
        {
            if(high_count < 10) {
                swing_highs[high_count] = rates[i].high;
                high_count++;
            }
        }
        
        // Swing Low
        if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
           rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
        {
            if(low_count < 10) {
                swing_lows[low_count] = rates[i].low;
                low_count++;
            }
        }
    }
    
    // Trouver le niveau de liquidité le plus récent et le plus fort
    double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double best_level = 0;
    double best_strength = 0;
    bool is_above = false;
    
    // Analyser les swing highs (liquidité au-dessus)
    for(int i = 0; i < high_count; i++)
    {
        if(swing_highs[i] > current_price) {
            double strength = CalculateLiquidityStrength(rates, swing_highs[i], true, lookback);
            if(strength > best_strength) {
                best_strength = strength;
                best_level = swing_highs[i];
                is_above = true;
            }
        }
    }
    
    // Analyser les swing lows (liquidité en-dessous)
    for(int i = 0; i < low_count; i++)
    {
        if(swing_lows[i] < current_price) {
            double strength = CalculateLiquidityStrength(rates, swing_lows[i], false, lookback);
            if(strength > best_strength) {
                best_strength = strength;
                best_level = swing_lows[i];
                is_above = false;
            }
        }
    }
    
    if(best_level > 0) {
        lp.level = best_level;
        lp.isAbove = is_above;
        lp.isValid = true;
        lp.created_time = TimeCurrent();
        lp.strength = best_strength;
        lp.success_rate = 0.65; // Taux de succès par défaut
    }
    
    return lp;
}

//+------------------------------------------------------------------+
//| Calcul de la force d'un pool de liquidité                       |
//+------------------------------------------------------------------+
double CalculateLiquidityStrength(MqlRates &rates[], double level, bool is_above, int lookback)
{
    double strength = 0.0;
    int touch_count = 0;
    
    // Compter les touches du niveau
    for(int i = 0; i < lookback; i++)
    {
        if(is_above) {
            if(rates[i].high >= level * 0.999 && rates[i].high <= level * 1.001) {
                touch_count++;
            }
        } else {
            if(rates[i].low >= level * 0.999 && rates[i].low <= level * 1.001) {
                touch_count++;
            }
        }
    }
    
    // Force basée sur le nombre de touches
    strength = MathMin(touch_count / 5.0, 1.0);
    
    return strength;
}

//+------------------------------------------------------------------+
//| Analyse de la structure de marché                               |
//+------------------------------------------------------------------+
MarketStructure AnalyzeMarketStructure(const string symbol, const int lookback = 50)
{
    MarketStructure ms = {0, 0, false, false, 0, 0, 0.0};
    MqlRates rates[];
    
    if(CopyRates(symbol, PERIOD_M1, 0, lookback, rates) < lookback) return ms;
    
    // Trouver les swings récents
    double recent_high = rates[0].high;
    double recent_low = rates[0].low;
    int high_index = 0, low_index = 0;
    
    for(int i = 1; i < lookback; i++)
    {
        if(rates[i].high > recent_high) {
            recent_high = rates[i].high;
            high_index = i;
        }
        if(rates[i].low < recent_low) {
            recent_low = rates[i].low;
            low_index = i;
        }
    }
    
    ms.swing_high = recent_high;
    ms.swing_low = recent_low;
    
    // Détecter Break of Structure (BOS)
    if(high_index < low_index) {
        // Plus haut récent avant plus bas récent = structure baissière
        ms.structure_type = -1;
        // Chercher BOS haussier (cassure du plus haut récent)
        for(int i = high_index - 1; i >= 0; i--) {
            if(rates[i].high > recent_high) {
                ms.bos_detected = true;
                break;
            }
        }
    } else {
        // Plus bas récent avant plus haut récent = structure haussière
        ms.structure_type = 1;
        // Chercher BOS baissier (cassure du plus bas récent)
        for(int i = low_index - 1; i >= 0; i--) {
            if(rates[i].low < recent_low) {
                ms.bos_detected = true;
                break;
            }
        }
    }
    
    // Détecter Change of Character (CHoCH)
    if(ms.bos_detected) {
        // Si BOS détecté, vérifier si c'est un changement de caractère
        double price_change = recent_high - recent_low;
        double avg_range = 0.0;
        for(int i = 0; i < 10; i++) {
            avg_range += (rates[i].high - rates[i].low);
        }
        avg_range /= 10.0;
        
        if(price_change > avg_range * 2.0) {
            ms.choc_detected = true;
        }
    }
    
    ms.last_update = TimeCurrent();
    ms.strength = CalculateStructureStrength(ms);
    
    return ms;
}

//+------------------------------------------------------------------+
//| Calcul de la force de la structure de marché                    |
//+------------------------------------------------------------------+
double CalculateStructureStrength(MarketStructure &ms)
{
    double strength = 0.0;
    
    // Facteur 1: Clarté de la structure (40%)
    if(ms.structure_type != 0) strength += 0.4;
    
    // Facteur 2: BOS détecté (30%)
    if(ms.bos_detected) strength += 0.3;
    
    // Facteur 3: CHoCH détecté (30%)
    if(ms.choc_detected) strength += 0.3;
    
    return MathMin(strength, 1.0);
}

//+------------------------------------------------------------------+
//| Calcul du score de confluence complet                           |
//+------------------------------------------------------------------+
ConfluenceScore CalculateConfluenceScore(const string symbol)
{
    ConfluenceScore cs = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0.0};
    
    double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Score RSI
    cs.rsi_score = CalculateRSIScore(symbol);
    
    // Score Support/Résistance
    cs.sr_score = CalculateSRScore(symbol, current_price);
    
    // Score Order Block
    cs.ob_score = CalculateOBScore(symbol, current_price);
    
    // Score Fair Value Gap
    cs.fvg_score = CalculateFVGScore(symbol, current_price);
    
    // Score Liquidité
    cs.liquidity_score = CalculateLiquidityScore(symbol, current_price);
    
    // Score Structure
    cs.structure_score = CalculateStructureScore(symbol);
    
    // Score Volume
    cs.volume_score = CalculateVolumeScore(symbol);
    
    // Score Momentum
    cs.momentum_score = CalculateMomentumScore(symbol);
    
    // Calcul du score total pondéré
    cs.total_score = (cs.rsi_score * 0.15) + 
                     (cs.sr_score * 0.20) + 
                     (cs.ob_score * 0.20) + 
                     (cs.fvg_score * 0.15) + 
                     (cs.liquidity_score * 0.10) + 
                     (cs.structure_score * 0.10) + 
                     (cs.volume_score * 0.05) + 
                     (cs.momentum_score * 0.05);
    
    // Déterminer la direction du signal
    int buy_signals = 0, sell_signals = 0;
    if(cs.rsi_score > 0.5) buy_signals++; else if(cs.rsi_score < -0.5) sell_signals++;
    if(cs.sr_score > 0.5) buy_signals++; else if(cs.sr_score < -0.5) sell_signals++;
    if(cs.ob_score > 0.5) buy_signals++; else if(cs.ob_score < -0.5) sell_signals++;
    if(cs.fvg_score > 0.5) buy_signals++; else if(cs.fvg_score < -0.5) sell_signals++;
    if(cs.liquidity_score > 0.5) buy_signals++; else if(cs.liquidity_score < -0.5) sell_signals++;
    if(cs.structure_score > 0.5) buy_signals++; else if(cs.structure_score < -0.5) sell_signals++;
    if(cs.momentum_score > 0.5) buy_signals++; else if(cs.momentum_score < -0.5) sell_signals++;
    
    if(buy_signals > sell_signals) {
        cs.signal_direction = 1;
        cs.confidence = cs.total_score;
    } else if(sell_signals > buy_signals) {
        cs.signal_direction = -1;
        cs.confidence = cs.total_score;
    } else {
        cs.signal_direction = 0;
        cs.confidence = 0.0;
    }
    
    return cs;
}

//+------------------------------------------------------------------+
//| Fonctions de calcul des scores individuels                     |
//+------------------------------------------------------------------+
double CalculateRSIScore(const string symbol)
{
    int rsi_handle = iRSI(symbol, PERIOD_M1, 14, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) return 0.0;
    
    double rsi_values[3];
    if(CopyBuffer(rsi_handle, 0, 0, 3, rsi_values) < 3) {
        IndicatorRelease(rsi_handle);
        return 0.0;
    }
    
    IndicatorRelease(rsi_handle);
    
    // Score basé sur les niveaux RSI
    if(rsi_values[0] < 30 && rsi_values[1] >= 30) return 0.8; // Sortie de survente
    if(rsi_values[0] > 70 && rsi_values[1] <= 70) return -0.8; // Sortie de surachat
    if(rsi_values[0] > 50 && rsi_values[1] <= 50) return 0.3; // Croisement haussier
    if(rsi_values[0] < 50 && rsi_values[1] >= 50) return -0.3; // Croisement baissier
    
    return 0.0;
}

double CalculateSRScore(const string symbol, double price)
{
    double zone_level, zone_strength;
    
    if(IsNearSupportZone(price, zone_level, zone_strength)) {
        return zone_strength; // Score positif pour support
    }
    if(IsNearResistanceZone(price, zone_level, zone_strength)) {
        return -zone_strength; // Score négatif pour résistance
    }
    
    return 0.0;
}

double CalculateOBScore(const string symbol, double price)
{
    OrderBlock ob = FindAdvancedOrderBlock(symbol);
    if(!ob.isValid) return 0.0;
    
    if(price >= ob.low && price <= ob.high) {
        return ob.isBullish ? ob.strength : -ob.strength;
    }
    
    return 0.0;
}

double CalculateFVGScore(const string symbol, double price)
{
    FairValueGap fvg = FindAdvancedFVG(symbol);
    if(!fvg.isValid) return 0.0;
    
    if(price >= fvg.bottom && price <= fvg.top) {
        return fvg.isBullish ? fvg.strength : -fvg.strength;
    }
    
    return 0.0;
}

double CalculateLiquidityScore(const string symbol, double price)
{
    LiquidityPool lp = FindLiquidityPool(symbol);
    if(!lp.isValid) return 0.0;
    
    double distance = MathAbs(price - lp.level);
    double proximity_threshold = SymbolInfoDouble(symbol, SYMBOL_POINT) * 50; // 50 points
    
    if(distance <= proximity_threshold) {
        return lp.isAbove ? -lp.strength : lp.strength;
    }
    
    return 0.0;
}

double CalculateStructureScore(const string symbol)
{
    MarketStructure ms = AnalyzeMarketStructure(symbol);
    
    if(ms.bos_detected) {
        return ms.structure_type * ms.strength;
    }
    
    return 0.0;
}

double CalculateVolumeScore(const string symbol)
{
    // Score basé sur le volume relatif (simplifié)
    MqlRates rates[5];
    if(CopyRates(symbol, PERIOD_M1, 0, 5, rates) < 5) return 0.0;
    
    double current_volume = (double)rates[0].tick_volume;
    double avg_volume = 0.0;
    for(int i = 1; i < 5; i++) {
        avg_volume += (double)rates[i].tick_volume;
    }
    avg_volume /= 4.0;
    
    if(avg_volume > 0) {
        double volume_ratio = current_volume / avg_volume;
        if(volume_ratio > 1.5) return 0.5; // Volume élevé
        if(volume_ratio < 0.5) return -0.5; // Volume faible
    }
    
    return 0.0;
}

double CalculateMomentumScore(const string symbol)
{
    MqlRates rates[3];
    if(CopyRates(symbol, PERIOD_M1, 0, 3, rates) < 3) return 0.0;
    
    double momentum = rates[0].close - rates[2].close;
    double avg_range = 0.0;
    for(int i = 0; i < 3; i++) {
        avg_range += (rates[i].high - rates[i].low);
    }
    avg_range /= 3.0;
    
    if(avg_range > 0) {
        double momentum_ratio = momentum / avg_range;
        if(momentum_ratio > 0.5) return 0.5; // Momentum haussier
        if(momentum_ratio < -0.5) return -0.5; // Momentum baissier
    }
    
    return 0.0;
}

//+------------------------------------------------------------------+
//| Fonction principale de trading avec confluence renforcée       |
//+------------------------------------------------------------------+
bool ExecuteConfluenceTrade(const string symbol)
{
    // Vérifier si une flèche dynamique est présente
    if(ObjectFind(0, "DYNAMIC_PATTERN_ARROW") < 0) {
        if(InpDebug) Print("⚠️ Aucune flèche dynamique détectée - Aucun trade ne sera pris");
        return false;
    }
    
    // Vérifier la direction de la flèche dynamique
    color arrow_color = (color)ObjectGetInteger(0, "DYNAMIC_PATTERN_ARROW", OBJPROP_COLOR);
    int arrow_direction = (arrow_color == clrLime) ? 1 : (arrow_color == clrRed) ? -1 : 0;
    
    if(arrow_direction == 0) {
        if(InpDebug) Print("⚠️ Direction de la flèche dynamique non valide");
        return false;
    }
    
    // Calculer le score de confluence
    ConfluenceScore cs = CalculateConfluenceScore(symbol);
    
    // Vérifier les conditions de confluence
    if(cs.confidence < 0.8) { // Augmentation du seuil de confiance à 80%
        if(InpDebug) Print("🔍 Confiance insuffisante pour trader: ", DoubleToString(cs.confidence * 100, 1), "%");
        return false;
    }
    
    // Déterminer la direction du trade
    int direction = cs.signal_direction;
    
    // Vérifier la cohérence avec la flèche dynamique
    if(direction != arrow_direction) {
        if(InpDebug) Print("⚠️ Incohérence entre la direction du signal et la flèche dynamique");
        return false;
    }
    
    if(direction == 0) return false;
    
    // Vérifier si c'est un trade contre-tendance
    if(IsCounterTrendTrade(symbol, direction)) {
        return false;
    }
    
    // Calculer les niveaux de prix
    double entry_price = (direction == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl_price = 0, tp_price = 0;
    
    // Calculer SL/TP avec valeurs par défaut
    if(!CalculateSLTPWithDefaults(symbol, direction, entry_price, sl_price, tp_price)) {
        Print("❌ ÉCHEC CALCUL SL/TP pour ", symbol);
        return false;
    }
    
    // Exécuter le trade
    CTrade trade;
    trade.SetExpertMagicNumber(InpMagicNumber);
    
    bool result = false;
    ulong ticket = 0;
    
    if(direction == 1) {
        result = trade.Buy(InpLotSize, symbol, entry_price, sl_price, tp_price, "AngelOfSpike Confluence");
    } else {
        result = trade.Sell(InpLotSize, symbol, entry_price, sl_price, tp_price, "AngelOfSpike Confluence");
    }
    
    if(result) {
        ticket = trade.ResultOrder();
        Print("✅ SUCCÈS TRADE CONFLUENCE: ", symbol, " Direction: ", (direction == 1 ? "BUY" : "SELL"), 
              " Confiance: ", DoubleToString(cs.confidence * 100, 1), "%",
              " SL: ", sl_price, " TP: ", tp_price);
        
        // Ajouter le trade au suivi
        AddTradeToTracking(ticket, symbol, direction, entry_price);
        
        return true;
    } else {
        Print("❌ ÉCHEC TRADE CONFLUENCE: ", symbol, " Erreur: ", trade.ResultRetcode());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Calcul de l'ATR pour la gestion du risque                      |
//+------------------------------------------------------------------+
double CalculateATR(const string symbol, int period)
{
    int atr_handle = iATR(symbol, PERIOD_M1, period);
    if(atr_handle == INVALID_HANDLE) return 0.0;
    
    double atr_values[1];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr_values) < 1) {
        IndicatorRelease(atr_handle);
        return 0.0;
    }
    
    IndicatorRelease(atr_handle);
    return atr_values[0];
}

//+------------------------------------------------------------------+
//| Mise à jour des données SMC                                     |
//+------------------------------------------------------------------+
void UpdateSMCData()
{
    string symbol = _Symbol;
    
    // Mettre à jour les Order Blocks
    OrderBlock ob = FindAdvancedOrderBlock(symbol);
    if(ob.isValid) {
        // Stocker le dernier Order Block valide
        if(g_ob_count < ArraySize(g_order_blocks)) {
            g_order_blocks[g_ob_count] = ob;
            g_ob_count++;
        }
    }
    
    // Mettre à jour les Fair Value Gaps
    FairValueGap fvg = FindAdvancedFVG(symbol);
    if(fvg.isValid) {
        // Stocker le dernier FVG valide
        if(g_fvg_count < ArraySize(g_fvg_gaps)) {
            g_fvg_gaps[g_fvg_count] = fvg;
            g_fvg_count++;
        }
    }
    
    // Mettre à jour les pools de liquidité
    LiquidityPool lp = FindLiquidityPool(symbol);
    if(lp.isValid) {
        // Stocker le dernier pool de liquidité valide
        if(g_lp_count < ArraySize(g_liquidity_pools)) {
            g_liquidity_pools[g_lp_count] = lp;
            g_lp_count++;
        }
    }
    
    // Mettre à jour la structure de marché
    g_market_structure = AnalyzeMarketStructure(symbol);
    
    g_last_smc_update = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Vérification du trading par confluence                          |
//+------------------------------------------------------------------+
//| Vérification du trading par confluence avec filtres renforcés    |
//+------------------------------------------------------------------+
void CheckConfluenceTrading()
{
    string symbol = Symbol(); // Utiliser le symbole du graphique actuel
    
    // 1. Vérifications de base
    if(!InpEnableTrading) return;
    if(PositionsTotal() > 0) return; // Ne pas ouvrir de nouvelle position si une est déjà ouverte
    
    // 2. Vérifier la volatilité du marché
    double atr = iATR(symbol, 0, 14);
    double atr_percent = atr / SymbolInfoDouble(symbol, SYMBOL_BID) * 100;
    
    // Éviter les marchés trop calmes ou trop volatils
    if(atr_percent < 0.05 || atr_percent > 2.0) {
        if(InpDebug) Print("🔍 Marché trop calme ou trop volatil pour trader. ATR%: ", DoubleToString(atr_percent, 2));
        return;
    }
    
    // 3. Calculer le score de confluence
    ConfluenceScore cs = CalculateConfluenceScore(symbol);
    
    // 4. Vérifier la qualité minimale du signal
    bool isHighQualitySignal = (cs.rsi_score > 0.7 && cs.sr_score > 0.7 && cs.structure_score > 0.7);
    bool isMediumQualitySignal = (cs.rsi_score > 0.6 && cs.sr_score > 0.6 && cs.fvg_score > 0.6 && cs.confidence > 0.8);
    
    if(!isHighQualitySignal && !isMediumQualitySignal) {
        if(InpDebug) Print("🔍 Signal de qualité insuffisante pour le trading");
        return;
    }
    
    // 5. Vérifier la tendance globale
    int ma_handle = iMA(symbol, PERIOD_CURRENT, 200, 0, MODE_EMA, PRICE_CLOSE);
    double ma200_buffer[1];
    if(CopyBuffer(ma_handle, 0, 0, 1, ma200_buffer) <= 0) {
        Print("Erreur lors de la récupération de la moyenne mobile");
        return;
    }
    double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ma200 = ma200_buffer[0];
    bool isUptrend = (current_price > ma200);
    
    // 6. Vérifier la cohérence du signal avec la tendance
    if((cs.signal_direction > 0 && !isUptrend) || (cs.signal_direction < 0 && isUptrend)) {
        if(InpDebug) Print("⚠️ Signal en opposition avec la tendance principale - Ignoré");
        return;
    }
    
    // 7. Afficher les informations de confluence pour debug
    if(InpDebug) {
        Print("📊 CONFLUENCE SCORE: ", DoubleToString(cs.total_score * 100, 1), "%",
              " | RSI: ", DoubleToString(cs.rsi_score * 100, 1), "%",
              " | S/R: ", DoubleToString(cs.sr_score * 100, 1), "%",
              " | OB: ", DoubleToString(cs.ob_score * 100, 1), "%",
              " | FVG: ", DoubleToString(cs.fvg_score * 100, 1), "%",
              " | Structure: ", DoubleToString(cs.structure_score * 100, 1), "%",
              " | Confiance: ", DoubleToString(cs.confidence * 100, 1), "%",
              " | Tendance: ", (isUptrend ? "Haussière" : "Baissière"));
    }
    
    // 8. Seuils de déclenchement plus stricts
    double minConfidence = isHighQualitySignal ? 0.80 : 0.85; // 80% pour les signaux de haute qualité, 85% pour les autres
    double minScore = isHighQualitySignal ? 0.75 : 0.80; // 75% pour les signaux de haute qualité, 80% pour les autres
    
    if(cs.confidence >= minConfidence && cs.total_score >= minScore) {
        // Vérifier le volume du marché (spread et spread en pips)
        double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
        if(spread > atr * 0.3) { // Spread trop élevé par rapport à la volatilité
            Print("⚠️ Spread trop élevé pour trader: ", DoubleToString(spread, _Digits), " (ATR: ", DoubleToString(atr, _Digits), ")");
            return;
        }
        
        // Vérifier le momentum récent
        int rsi_handle = iRSI(symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
        double rsi[1];
        if(CopyBuffer(rsi_handle, 0, 0, 1, rsi) <= 0) return;
        if((cs.signal_direction > 0 && rsi[0] > 70) || (cs.signal_direction < 0 && rsi[0] < 30)) {
            Print("⚠️ Signal rejeté - Marché en surachat/survente (RSI: ", DoubleToString(rsi[0], 1), ")");
            return;
        }
        
        // Toutes les conditions sont remplies, exécuter le trade
        Print("🎯 CONFLUENCE ÉLEVÉE DÉTECTÉE - Confiance: ", DoubleToString(cs.confidence * 100, 1), "%");
        
        // Exécuter le trade de confluence
        if(ExecuteConfluenceTrade(symbol)) {
            Print("✅ TRADE CONFLUENCE EXÉCUTÉ AVEC SUCCÈS");
        }
    }
}

//+------------------------------------------------------------------+
//| Dessine les éléments de structure de marché                    |
//+------------------------------------------------------------------+
void DrawMarketStructure()
{
    if(!InpShowHUD) return;
    
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 100, rates) < 100) return;
    
    // 1. Afficher les supports et résistances
    if(InpShowSR)
    {
        double atr = iATR(_Symbol, PERIOD_CURRENT, 14);
        double sr_tolerance = atr * 0.1; // 10% de l'ATR comme tolérance
        
        // Détection des niveaux de support/résistance
        for(int i=3; i<ArraySize(rates)-3; i++)
        {
            // Détection des sommets et creux locaux
            if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
               rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
            {
                // C'est une résistance potentielle
                string name = "SR_Resistance_"+IntegerToString(i);
                ObjectCreate(0, name, OBJ_HLINE, 0, 0, rates[i].high);
                ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
                ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, name, OBJPROP_BACK, true);
            }
            
            if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
               rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
            {
                // C'est un support potentiel
                string name = "SR_Support_"+IntegerToString(i);
                ObjectCreate(0, name, OBJ_HLINE, 0, 0, rates[i].low);
                ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
                ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
                ObjectSetInteger(0, name, OBJPROP_BACK, true);
            }
        }
    }
    
    // 2. Afficher les Fair Value Gaps (FVG)
    if(InpShowFVG)
    {
        for(int i=2; i<ArraySize(rates); i++)
        {
            // Détection d'un FVG haussier (bougie actuelle et précédente ne se chevauchent pas vers le haut)
            if(rates[i].low > rates[i-1].high)
            {
                string name = "FVG_Bullish_"+IntegerToString(i);
                ObjectCreate(0, name, OBJ_RECTANGLE, 0, rates[i-1].time, rates[i-1].high, 
                            rates[i].time, rates[i].low);
                ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
                ObjectSetInteger(0, name, OBJPROP_BACK, true);
                ObjectSetInteger(0, name, OBJPROP_FILL, true);
                ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'0,100,255,20');
            }
            
            // Détection d'un FVG baissier (bougie actuelle et précédente ne se chevauchent pas vers le bas)
            if(rates[i].high < rates[i-1].low)
            {
                string name = "FVG_Bearish_"+IntegerToString(i);
                ObjectCreate(0, name, OBJ_RECTANGLE, 0, rates[i-1].time, rates[i-1].low, 
                            rates[i].time, rates[i].high);
                ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrangeRed);
                ObjectSetInteger(0, name, OBJPROP_BACK, true);
                ObjectSetInteger(0, name, OBJPROP_FILL, true);
                ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'255,69,0,20');
            }
        }
    }
    
    // 3. Afficher les zones OTE (Optimal Trade Entry)
    if(InpShowOTE)
    {
        // Logique pour détecter et dessiner les zones OTE
        // (à implémenter selon votre stratégie spécifique)
    }
    
    // 4. Afficher les retracements de Fibonacci
    if(InpShowFibonacci)
    {
        // Trouver le swing high et low récents
        double high = 0, low = EMPTY_VALUE;
        datetime time_high = 0, time_low = 0;
        
        for(int i=0; i<ArraySize(rates); i++)
        {
            if(rates[i].high > high)
            {
                high = rates[i].high;
                time_high = rates[i].time;
            }
            if(rates[i].low < low)
            {
                low = rates[i].low;
                time_low = rates[i].time;
            }
        }
        
        // Dessiner les retracements Fibonacci
        if(high > 0 && low < EMPTY_VALUE && time_high != time_low)
        {
            string fibo_name = "Fibonacci_Retracement";
            ObjectCreate(0, fibo_name, OBJ_FIBO, 0, time_low, low, time_high, high);
            ObjectSetInteger(0, fibo_name, OBJPROP_LEVELCOLOR, clrDodgerBlue);
            ObjectSetInteger(0, fibo_name, OBJPROP_LEVELSTYLE, STYLE_SOLID);
            ObjectSetInteger(0, fibo_name, OBJPROP_LEVELWIDTH, 1);
            
            // Niveaux de retracement standard
            ObjectSetInteger(0, fibo_name, OBJPROP_LEVELS, 7);  // Set number of levels
            
            // Set level values (0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0)
            ObjectSetDouble(0, fibo_name, OBJPROP_LEVELVALUE, 0, 0.0);
            ObjectSetDouble(0, fibo_name, OBJPROP_LEVELVALUE, 1, 0.236);
            ObjectSetDouble(0, fibo_name, OBJPROP_LEVELVALUE, 2, 0.382);
            ObjectSetDouble(0, fibo_name, OBJPROP_LEVELVALUE, 3, 0.5);
            ObjectSetDouble(0, fibo_name, OBJPROP_LEVELVALUE, 4, 0.618);
            ObjectSetDouble(0, fibo_name, OBJPROP_LEVELVALUE, 5, 0.786);
            ObjectSetDouble(0, fibo_name, OBJPROP_LEVELVALUE, 6, 1.0);
            
            // Set level descriptions
            ObjectSetString(0, fibo_name, OBJPROP_LEVELTEXT, 0, "0.0%");
            ObjectSetString(0, fibo_name, OBJPROP_LEVELTEXT, 1, "23.6%");
            ObjectSetString(0, fibo_name, OBJPROP_LEVELTEXT, 2, "38.2%");
            ObjectSetString(0, fibo_name, OBJPROP_LEVELTEXT, 3, "50.0%");
            ObjectSetString(0, fibo_name, OBJPROP_LEVELTEXT, 4, "61.8%");
            ObjectSetString(0, fibo_name, OBJPROP_LEVELTEXT, 5, "78.6%");
            ObjectSetString(0, fibo_name, OBJPROP_LEVELTEXT, 6, "100.0%");
            
            // Set level colors and styles
            for(int i = 0; i < 7; i++) {
                ObjectSetInteger(0, fibo_name, OBJPROP_LEVELCOLOR, i, clrDodgerBlue);
                ObjectSetInteger(0, fibo_name, OBJPROP_LEVELSTYLE, i, STYLE_DOT);
                ObjectSetInteger(0, fibo_name, OBJPROP_LEVELWIDTH, i, 1);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Affichage des informations SMC sur le graphique                |
//+------------------------------------------------------------------+
void DrawSMCInfo()
{
    if(!InpShowHUD) return;
    
    string info_text = "";
    info_text += "=== ANGELOFSPIKE V5.0 - SMC RENFORCÉ ===\n";
    
    // Informations Order Block
    if(g_ob_count > 0) {
        OrderBlock last_ob = g_order_blocks[g_ob_count - 1];
        info_text += "Order Block: " + (last_ob.isBullish ? "HAUSSIER" : "BAISSIER") + 
                     " | Force: " + DoubleToString(last_ob.strength * 100, 1) + "%\n";
    }
    
    // Informations Fair Value Gap
    if(g_fvg_count > 0) {
        FairValueGap last_fvg = g_fvg_gaps[g_fvg_count - 1];
        info_text += "FVG: " + (last_fvg.isBullish ? "HAUSSIER" : "BAISSIER") + 
                     " | Force: " + DoubleToString(last_fvg.strength * 100, 1) + "%\n";
    }
    
    // Informations Structure de marché
    if(g_market_structure.structure_type != 0) {
        string structure_type = (g_market_structure.structure_type == 1) ? "HAUSSIÈRE" : "BAISSIÈRE";
        info_text += "Structure: " + structure_type;
        if(g_market_structure.bos_detected) info_text += " | BOS DÉTECTÉ";
        if(g_market_structure.choc_detected) info_text += " | CHoCH DÉTECTÉ";
        info_text += "\n";
    }
    
    // Informations Confluence
    info_text += "Confluence: " + DoubleToString(g_confluence_score.total_score * 100, 1) + "%";
    if(g_confluence_score.signal_direction != 0) {
        info_text += " | Signal: " + (g_confluence_score.signal_direction == 1 ? "BUY" : "SELL");
    }
    
    // Créer ou mettre à jour l'objet texte
    string obj_name = "SMC_Info_Display";
    if(ObjectFind(0, obj_name) < 0) {
        ObjectCreate(0, obj_name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, 20);
        ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, 100);
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 9);
        ObjectSetString(0, obj_name, OBJPROP_FONT, "Arial");
    }
    
    ObjectSetString(0, obj_name, OBJPROP_TEXT, info_text);
}

//+------------------------------------------------------------------+
//| Validation avancée des conditions de trading                   |
//+------------------------------------------------------------------+
bool ValidateAdvancedTradingConditions(const string symbol)
{
    // Vérification 1: Confluence minimum
    ConfluenceScore cs = CalculateConfluenceScore(symbol);
    if(cs.confidence < 0.70) return false;
    
    // Vérification 2: Structure de marché favorable
    MarketStructure ms = AnalyzeMarketStructure(symbol);
    if(ms.structure_type == 0) return false; // Structure neutre
    
    // Vérification 3: Volatilité suffisante
    double atr = CalculateATR(symbol, 14);
    double avg_atr = CalculateATR(symbol, 50);
    if(atr < avg_atr * 0.8) return false; // Volatilité trop faible
    
    // Vérification 4: Pas de conflit entre les signaux
    int buy_signals = 0, sell_signals = 0;
    if(cs.rsi_score > 0.5) buy_signals++; else if(cs.rsi_score < -0.5) sell_signals++;
    if(cs.sr_score > 0.5) buy_signals++; else if(cs.sr_score < -0.5) sell_signals++;
    if(cs.ob_score > 0.5) buy_signals++; else if(cs.ob_score < -0.5) sell_signals++;
    if(cs.fvg_score > 0.5) buy_signals++; else if(cs.fvg_score < -0.5) sell_signals++;
    
    // Au moins 3 signaux dans la même direction
    if(buy_signals < 3 && sell_signals < 3) return false;
    
    return true;
}

//+------------------------------------------------------------------+
//| Vérifier si le trade est contre-tendance                      |
//+------------------------------------------------------------------+
bool IsCounterTrendTrade(const string symbol, int direction)
{
    if(!InpAntiCounterTrend) return false;
    
    // Pas de SELL sur Boom
    if(StringFind(symbol, "Boom") >= 0 && direction == -1) {
        Print("❌ TRADE CONTRE-TENDANCE BLOQUÉ: SELL sur ", symbol);
        return true;
    }
    
    // Pas de BUY sur Crash
    if(StringFind(symbol, "Crash") >= 0 && direction == 1) {
        Print("❌ TRADE CONTRE-TENDANCE BLOQUÉ: BUY sur ", symbol);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculer SL/TP avec valeurs par défaut                        |
//+------------------------------------------------------------------+
bool CalculateSLTPWithDefaults(const string symbol, int direction, double entry_price, double &sl_price, double &tp_price)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    // Essayer d'abord avec ATR
    double atr = CalculateATR(symbol, 14);
    if(atr > 0) {
        if(direction == 1) {
            sl_price = entry_price - (atr * 2.0);
            tp_price = entry_price + (atr * 4.0); // Ratio 1:2
        } else {
            sl_price = entry_price + (atr * 2.0);
            tp_price = entry_price - (atr * 4.0); // Ratio 1:2
        }
    } else {
        // Utiliser les valeurs par défaut en points
        if(direction == 1) {
            sl_price = entry_price - (InpDefaultSLPoints * point);
            tp_price = entry_price + (InpDefaultTPPoints * point);
        } else {
            sl_price = entry_price + (InpDefaultSLPoints * point);
            tp_price = entry_price - (InpDefaultTPPoints * point);
        }
    }
    
    // Normaliser les prix
    sl_price = NormalizeDouble(sl_price, digits);
    tp_price = NormalizeDouble(tp_price, digits);
    
    // Vérifier la distance minimale
    double stops_level = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    if(MathAbs(entry_price - sl_price) < stops_level) {
        sl_price = (direction == 1) ? entry_price - stops_level : entry_price + stops_level;
        sl_price = NormalizeDouble(sl_price, digits);
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Ajouter un trade à la liste de suivi                          |
//+------------------------------------------------------------------+
void AddTradeToTracking(ulong ticket, const string symbol, int direction, double open_price)
{
    if(g_active_trade_count >= ArraySize(g_active_trades)) return;
    
    g_active_trades[g_active_trade_count].ticket = ticket;
    g_active_trades[g_active_trade_count].open_time = TimeCurrent();
    g_active_trades[g_active_trade_count].open_price = open_price;
    g_active_trades[g_active_trade_count].direction = direction;
    g_active_trades[g_active_trade_count].symbol = symbol;
    g_active_trades[g_active_trade_count].sl_tp_set = false;
    g_active_trades[g_active_trade_count].spike_detected = false;
    g_active_trades[g_active_trade_count].last_spike_check = TimeCurrent();
    
    g_active_trade_count++;
    
    Print("📊 TRADE AJOUTÉ AU SUIVI: ", symbol, " Ticket: ", ticket, " Direction: ", (direction == 1 ? "BUY" : "SELL"));
}

//+------------------------------------------------------------------+
//| Retirer un trade de la liste de suivi                         |
//+------------------------------------------------------------------+
void RemoveTradeFromTracking(ulong ticket)
{
    for(int i = 0; i < g_active_trade_count; i++) {
        if(g_active_trades[i].ticket == ticket) {
            // Déplacer les éléments suivants
            for(int j = i; j < g_active_trade_count - 1; j++) {
                g_active_trades[j] = g_active_trades[j + 1];
            }
            g_active_trade_count--;
            Print("📊 TRADE RETIRÉ DU SUIVI: Ticket ", ticket);
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier et gérer les trades actifs                           |
//+------------------------------------------------------------------+
void ManageActiveTrades()
{
    for(int i = g_active_trade_count - 1; i >= 0; i--) {
        TradeInfo trade = g_active_trades[i];
        
        // Vérifier si le trade existe encore
        if(!PositionSelectByTicket(trade.ticket)) {
            RemoveTradeFromTracking(trade.ticket);
            continue;
        }
        
        // Vérifier si SL/TP sont définis
        if(!trade.sl_tp_set && InpForceSLTPOnEveryTrade) {
            double current_sl = PositionGetDouble(POSITION_SL);
            double current_tp = PositionGetDouble(POSITION_TP);
            
            if(current_sl == 0.0 || current_tp == 0.0) {
                // Définir SL/TP
                double sl_price, tp_price;
                if(CalculateSLTPWithDefaults(trade.symbol, trade.direction, trade.open_price, sl_price, tp_price)) {
                    CTrade trade_obj;
                    trade_obj.SetExpertMagicNumber(InpMagicNumber);
                    
                    if(trade_obj.PositionModify(trade.ticket, sl_price, tp_price)) {
                        trade.sl_tp_set = true;
                        Print("✅ SUCCÈS SL/TP DÉFINIS: ", trade.symbol, " SL: ", sl_price, " TP: ", tp_price);
                    } else {
                        Print("❌ ÉCHEC DÉFINITION SL/TP: ", trade.symbol, " Erreur: ", trade_obj.ResultRetcode());
                    }
                }
            } else {
                trade.sl_tp_set = true;
            }
        }
        
        // Vérifier si le temps d'attente est dépassé
        datetime current_time = TimeCurrent();
        int wait_time_minutes = (int)((current_time - trade.open_time) / 60);
        
        if(wait_time_minutes >= InpMaxWaitTimeMinutes && !trade.spike_detected) {
            Print("⏰ TEMPS D'ATTENTE DÉPASSÉ: ", trade.symbol, " Fermeture anticipée après ", wait_time_minutes, " minutes");
            
            CTrade trade_obj;
            trade_obj.SetExpertMagicNumber(InpMagicNumber);
            
            if(trade_obj.PositionClose(trade.ticket)) {
                Print("✅ SUCCÈS FERMETURE ANTICIPÉE: ", trade.symbol);
                RemoveTradeFromTracking(trade.ticket);
            } else {
                Print("❌ ÉCHEC FERMETURE ANTICIPÉE: ", trade.symbol, " Erreur: ", trade_obj.ResultRetcode());
            }
        }
        
        // Vérifier si un spike a été détecté
        if(DetectSpikeForTrade(trade.symbol, trade.direction)) {
            if(!trade.spike_detected) {
                trade.spike_detected = true;
                Print("🎯 SPIKE DÉTECTÉ POUR: ", trade.symbol, " Direction: ", (trade.direction == 1 ? "BUY" : "SELL"));
                
                // SORTIE IMMÉDIATE DÈS DÉTECTION DU SPIKE (si activé)
                if(InpExitOnSpikeDetection) {
                    Print("🚀 SORTIE IMMÉDIATE - Spike capturé sur ", trade.symbol);
                    
                    CTrade trade_obj;
                    trade_obj.SetExpertMagicNumber(InpMagicNumber);
                    
                    if(trade_obj.PositionClose(trade.ticket)) {
                        Print("✅ SUCCÈS SORTIE SPIKE: ", trade.symbol, " Profit capturé");
                        RemoveTradeFromTracking(trade.ticket);
                    } else {
                        Print("❌ ÉCHEC SORTIE SPIKE: ", trade.symbol, " Erreur: ", trade_obj.ResultRetcode());
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Détecter un spike pour un trade spécifique                     |
//+------------------------------------------------------------------+
bool DetectSpikeForTrade(const string symbol, int direction)
{
    MqlRates rates[5];
    if(CopyRates(symbol, PERIOD_M1, 0, 5, rates) < 5) {
        Print("❌ Échec copie des données M1 pour ", symbol);
        return false;
    }
    
    // Calculer ATR pour référence
    double atr = CalculateATR(symbol, 14);
    if(atr <= 0) {
        Print("❌ ATR invalide pour ", symbol);
        return false;
    }
    
    // Analyser la barre actuelle
    MqlRates current_bar = rates[0];
    double range = current_bar.high - current_bar.low;
    double body = MathAbs(current_bar.close - current_bar.open);
    
    // Calculer la moyenne des ranges des barres précédentes pour comparaison
    double avg_range = 0.0;
    for(int i = 1; i < 4; i++) {
        avg_range += (rates[i].high - rates[i].low);
    }
    avg_range /= 3.0;
    
    // Condition de spike améliorée avec sensibilité ajustable
    bool is_spike = (range >= atr * InpSpikeDetectionSensitivity) && (body >= atr * 0.6);
    
    // Log de diagnostic (limité pour éviter spam)
    static datetime last_log_time = 0;
    if(TimeCurrent() - last_log_time >= 30) { // Log toutes les 30 secondes max
        Print("🔍 DIAGNOSTIC SPIKE: ", symbol, " Range:", DoubleToString(range, 5), 
              " ATR:", DoubleToString(atr, 5), " Avg:", DoubleToString(avg_range, 5),
              " Ratio:", DoubleToString(range/avg_range, 2), " Spike:", is_spike);
        last_log_time = TimeCurrent();
    }
    
    if(is_spike) {
        // Vérifier la direction du spike
        bool spike_up = current_bar.close > current_bar.open;
        bool spike_down = current_bar.close < current_bar.open;
        
        // Pour BUY: chercher spike haussier OU mouvement significatif vers le haut
        if(direction == 1 && (spike_up || (current_bar.close > current_bar.open + atr * 0.3))) {
            Print("🎯 SPIKE HAUSSIER DÉTECTÉ: ", symbol, " Range: ", DoubleToString(range, 5), 
                  " ATR: ", DoubleToString(atr, 5), " Body: ", DoubleToString(body, 5));
            return true;
        }
        
        // Pour SELL: chercher spike baissier OU mouvement significatif vers le bas
        if(direction == -1 && (spike_down || (current_bar.close < current_bar.open - atr * 0.3))) {
            Print("🎯 SPIKE BAISSIER DÉTECTÉ: ", symbol, " Range: ", DoubleToString(range, 5), 
                  " ATR: ", DoubleToString(atr, 5), " Body: ", DoubleToString(body, 5));
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Parser la réponse des signaux                                   |
//+------------------------------------------------------------------+
void ParseSignalsResponse(string json_response)
{
    // Rechercher les signaux dans le JSON
    if(StringFind(json_response, "\"signals\"") >= 0) {
        Print("? Signaux externes reçus et analysés");
        // Ici on peut extraire et traiter les signaux
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse des recommandations                           |
//+------------------------------------------------------------------+
void ParseRecommendationsResponse(string json_response)
{
    // Rechercher les recommandations dans le JSON
    if(StringFind(json_response, "\"recommendations\"") >= 0) {
        Print("? Recommandations reçues et analysées");
        // Ici on peut extraire et traiter les recommandations
    }
}

//+------------------------------------------------------------------+
//| Exécution de trade ultra-précis sur spike confirmé              |
//+------------------------------------------------------------------+
void ExecuteUltraPreciseTrade()
{
    // Vérifier les conditions de base
    if(!g_riskManager.CanOpenTrade()) {
        Print("?? Trade bloqué par gestion des risques");
        return;
    }
    
    // Obtenir les données de marché
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    
    // Déterminer la direction du spike
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) < 1) return;
    
    bool is_bullish_spike = rates[0].close > rates[0].open;
    int direction = is_bullish_spike ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
    
    // Calculer la taille de lot optimale
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * InpMaxRiskPercent / 100.0;
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    // Estimation de la distance SL pour calculer le lot
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    double current_atr = 0;
    if(atr_handle != INVALID_HANDLE && CopyBuffer(atr_handle, 0, 0, 1, atr_buffer) >= 1) {
        current_atr = atr_buffer[0];
        IndicatorRelease(atr_handle);
    }
    
    double estimated_sl_distance = current_atr * InpSL_ATR_Multiplier;
    double lot_size = 0;
    
    if(estimated_sl_distance > 0 && tick_value > 0) {
        lot_size = risk_amount / (estimated_sl_distance / tick_size * tick_value);
    } else {
        lot_size = InpLotSize; // Utiliser le lot par défaut
    }
    
    // Normaliser la taille de lot
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(lot_size, min_lot);
    lot_size = MathMin(lot_size, max_lot);
    lot_size = MathRound(lot_size / lot_step) * lot_step;
    
    if(lot_size <= 0) {
        Print("? Taille de lot invalide: ", lot_size);
        return;
    }
    
    // Calculer SL/TP optimaux
    double sl_price = 0, tp_price = 0;
    double entry_price = is_bullish_spike ? ask : bid;
    CalculateOptimalSLTP(sl_price, tp_price, direction, entry_price);
    
    // Validation finale des prix
    if(sl_price <= 0 || tp_price <= 0) {
        Print("? SL/TP invalides - SL: ", sl_price, " TP: ", tp_price);
        return;
    }
    
    // Exécuter le trade
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot_size;
    request.type = is_bullish_spike ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    request.price = entry_price;
    request.sl = sl_price;
    request.tp = tp_price;
    request.magic = InpMagicNumber;
    request.comment = "UltraPreciseSpike";
    request.deviation = 10;
    
    if(OrderSend(request, result)) {
        Print("?? TRADE ULTRA-PRÉCIS EXÉCUTÉ - Direction: ", (is_bullish_spike ? "BUY" : "SELL"),
              " Lot: ", DoubleToString(lot_size, 2),
              " Prix: ", DoubleToString(entry_price, 5),
              " SL: ", DoubleToString(sl_price, 5),
              " TP: ", DoubleToString(tp_price, 5));
        
        // Ajouter à la liste des trades intelligents
        AddSmartTrade(result.order, entry_price, lot_size, direction, sl_price, tp_price, 95.0);
        
        // Mettre à jour le timestamp du dernier trade
        static datetime last_trade_time = 0;
        last_trade_time = TimeCurrent();
        
        // Envoyer notification
        if(InpSendNotifications) {
            SendNotification("SpikeHunter Ultra-Precis: " + (is_bullish_spike ? "BUY" : "SELL") + " sur " + _Symbol);
        }
    } else {
        Print("ERREUR - Echec execution trade ultra-precis: ", GetLastError(), " - ", result.comment);
    }
}

//+------------------------------------------------------------------+
//| Supprime tous les objets du graphique                           |
//+------------------------------------------------------------------+
void DeleteAllObjects()
{
    for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
        string name = ObjectName(0, i, 0, -1);
        if(StringFind(name, "SR_") == 0 || 
           StringFind(name, "FVG_") == 0 || 
           StringFind(name, "OTE_") == 0 ||
           StringFind(name, "FIBO_") == 0) {
            ObjectDelete(0, name);
        }
    }
}

//+------------------------------------------------------------------+
//| Dessine la structure du marché (S/R, FVG, etc.)                 |
//+------------------------------------------------------------------+
void DrawMarketStructureVisuals()
{
    if(!InpShowSR && !InpShowFVG) return;
    
    // Nettoyer les anciens objets
    DeleteAllObjects();
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(_Symbol, _Period, 0, InpSRPeriods * 2, rates);
    if(copied <= 0) return;
    
    // Détection des points pivots pour S/R
    if(InpShowSR) {
        for(int i = 10; i < copied - 10; i++) {
            // Détection des creux (supports)
            if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low && 
               rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low) {
                string name = "SR_S_" + IntegerToString(i);
                if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, rates[i].low)) {
                    ObjectSetInteger(0, name, OBJPROP_COLOR, InpSupportColor);
                    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
                    ObjectSetInteger(0, name, OBJPROP_WIDTH, InpLineWidth);
                    
                    if(InpShowLabels) {
                        string label = name + "_LBL";
                        if(ObjectCreate(0, label, OBJ_TEXT, 0, TimeCurrent() - (InpLabelShift * PeriodSeconds()), rates[i].low)) {
                            ObjectSetString(0, label, OBJPROP_TEXT, DoubleToString(rates[i].low, _Digits));
                            ObjectSetInteger(0, label, OBJPROP_COLOR, InpSupportColor);
                        }
                    }
                }
            }
            
            // Détection des sommets (résistances)
            if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high && 
               rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high) {
                string name = "SR_R_" + IntegerToString(i);
                if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, rates[i].high)) {
                    ObjectSetInteger(0, name, OBJPROP_COLOR, InpResistanceColor);
                    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
                    ObjectSetInteger(0, name, OBJPROP_WIDTH, InpLineWidth);
                    
                    if(InpShowLabels) {
                        string label = name + "_LBL";
                        if(ObjectCreate(0, label, OBJ_TEXT, 0, TimeCurrent() - (InpLabelShift * PeriodSeconds()), rates[i].high)) {
                            ObjectSetString(0, label, OBJPROP_TEXT, DoubleToString(rates[i].high, _Digits));
                            ObjectSetInteger(0, label, OBJPROP_COLOR, InpResistanceColor);
                        }
                    }
                }
            }
        }
    }
    
    // Détection des Fair Value Gaps
    if(InpShowFVG) {
        for(int i = 2; i < copied; i++) {
            // FVG haussier (trou de bougie)
            if(rates[i-1].low > rates[i+1].high) {
                string fvg_name = "FVG_Bull_" + IntegerToString(i);
                if(ObjectCreate(0, fvg_name, OBJ_RECTANGLE, 0, 
                              rates[i-1].time, rates[i-1].low, 
                              rates[i+1].time, rates[i+1].high)) {
                    ObjectSetInteger(0, fvg_name, OBJPROP_COLOR, clrDodgerBlue);
                    ObjectSetInteger(0, fvg_name, OBJPROP_STYLE, STYLE_SOLID);
                    ObjectSetInteger(0, fvg_name, OBJPROP_WIDTH, 1);
                    ObjectSetInteger(0, fvg_name, OBJPROP_FILL, true);
                    ObjectSetInteger(0, fvg_name, OBJPROP_BACK, true);
                    ObjectSetInteger(0, fvg_name, OBJPROP_SELECTABLE, false);
                }
            }
            
            // FVG baissier (trou de bougie)
            if(rates[i-1].high < rates[i+1].low) {
                string fvg_name = "FVG_Bear_" + IntegerToString(i);
                if(ObjectCreate(0, fvg_name, OBJ_RECTANGLE, 0, 
                              rates[i-1].time, rates[i-1].high, 
                              rates[i+1].time, rates[i+1].low)) {
                    ObjectSetInteger(0, fvg_name, OBJPROP_COLOR, clrCrimson);
                    ObjectSetInteger(0, fvg_name, OBJPROP_STYLE, STYLE_SOLID);
                    ObjectSetInteger(0, fvg_name, OBJPROP_WIDTH, 1);
                    ObjectSetInteger(0, fvg_name, OBJPROP_FILL, true);
                    ObjectSetInteger(0, fvg_name, OBJPROP_BACK, true);
                    ObjectSetInteger(0, fvg_name, OBJPROP_SELECTABLE, false);
                }
            }
        }
    }
    
    // Mise à jour du graphique
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Dessine les zones OTE (Optimal Trade Entry)                     |
//+------------------------------------------------------------------+
void DrawOTEZones()
{
    if(!InpShowOTE) return;
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(_Symbol, _Period, 0, 200, rates);
    if(copied < 100) return;
    
    // Trouver le dernier swing haut et swing bas
    int lastSwingHigh = (int)iHighest(_Symbol, _Period, MODE_HIGH, 50, 0);
    int lastSwingLow = (int)iLowest(_Symbol, _Period, MODE_LOW, 50, 0);
    
    if(lastSwingHigh > 0 && lastSwingLow > 0) {
        double high = rates[lastSwingHigh].high;
        double low = rates[lastSwingLow].low;
        double range = high - low;
        
        // Niveaux OTE pour les positions longues (retracement 61.8% - 79%)
        double oteLongTop = high - (range * 0.61);
        double oteLongBottom = high - (range * 0.79);
        
        // Niveaux OTE pour les positions courtes (retracement 21% - 38.2%)
        double oteShortTop = low + (range * 0.382);
        double oteShortBottom = low + (range * 0.21);
        
        // Dessiner les zones OTE
        string oteLongName = "OTE_Long_Zone";
        if(ObjectCreate(0, oteLongName, OBJ_RECTANGLE, 0, 
                      TimeCurrent() - (PeriodSeconds() * 50), oteLongTop,
                      TimeCurrent() + (PeriodSeconds() * 10), oteLongBottom)) {
            ObjectSetInteger(0, oteLongName, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, oteLongName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, oteLongName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, oteLongName, OBJPROP_FILL, true);
            ObjectSetInteger(0, oteLongName, OBJPROP_BACK, true);
            ObjectSetInteger(0, oteLongName, OBJPROP_SELECTABLE, false);
        }
        
        string oteShortName = "OTE_Short_Zone";
        if(ObjectCreate(0, oteShortName, OBJ_RECTANGLE, 0, 
                      TimeCurrent() - (PeriodSeconds() * 50), oteShortTop,
                      TimeCurrent() + (PeriodSeconds() * 10), oteShortBottom)) {
            ObjectSetInteger(0, oteShortName, OBJPROP_COLOR, clrCrimson);
            ObjectSetInteger(0, oteShortName, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, oteShortName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, oteShortName, OBJPROP_FILL, true);
            ObjectSetInteger(0, oteShortName, OBJPROP_BACK, true);
            ObjectSetInteger(0, oteShortName, OBJPROP_SELECTABLE, false);
        }
    }
    
    // Mise à jour du graphique
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| Affiche les zones de liquidité                                  |
//+------------------------------------------------------------------+
void DrawLiquidityZones()
{
    if(!InpShowLiquidityZones) return;
    
    // Supprimer les anciennes zones de liquidité
    int total_objects = ObjectsTotal(0, -1, -1);
    for(int i = total_objects - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if(StringFind(name, "LIQUIDITY_") == 0)
            ObjectDelete(0, name);
    }
    
    // Obtenir les données de volume et de prix
    MqlRates rates[];
    long volumes[];
    ArraySetAsSeries(rates, true);
    
    int copied = CopyRates(_Symbol, _Period, 0, InpLiquidityZoneLookback, rates);
    CopyTickVolume(_Symbol, _Period, 0, InpLiquidityZoneLookback, volumes);
    
    if(copied <= 0) return;
    
    // Calculer les niveaux de liquidité
    double high_liq_level = 0, low_liq_level = 0;
    double max_volume = 0, min_volume = DBL_MAX;
    
    for(int i = 0; i < copied; i++)
    {
        double current_volume = (double)volumes[i];
        if(current_volume > max_volume)
        {
            max_volume = current_volume;
            high_liq_level = rates[i].close;
        }
        if(current_volume < min_volume && current_volume > 0)
        {
            min_volume = current_volume;
            low_liq_level = rates[i].close;
        }
    }
    
    // Définir les plages de prix pour les zones de liquidité
    double range = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) * 20; // 20 ticks de chaque côté
    
    // Dessiner la zone de haute liquidité (où le volume est le plus élevé)
    if(max_volume > 0)
    {
        string high_liq_name = "LIQUIDITY_HIGH_" + TimeToString(TimeCurrent());
        if(ObjectCreate(0, high_liq_name, OBJ_RECTANGLE, 0, 0, high_liq_level + range, TimeCurrent() + 86400, high_liq_level - range))
        {
            ObjectSetInteger(0, high_liq_name, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, high_liq_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, high_liq_name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, high_liq_name, OBJPROP_FILL, true);
            ObjectSetInteger(0, high_liq_name, OBJPROP_BACK, true);
            ObjectSetInteger(0, high_liq_name, OBJPROP_SELECTABLE, false);
            ObjectSetString(0, high_liq_name, OBJPROP_TOOLTIP, "Zone de Haute Liquidité");
        }
    }
    
    // Dessiner la zone de basse liquidité (où le volume est le plus faible)
    if(min_volume < DBL_MAX)
    {
        string low_liq_name = "LIQUIDITY_LOW_" + TimeToString(TimeCurrent());
        if(ObjectCreate(0, low_liq_name, OBJ_RECTANGLE, 0, 0, low_liq_level + range, TimeCurrent() + 86400, low_liq_level - range))
        {
            ObjectSetInteger(0, low_liq_name, OBJPROP_COLOR, clrOrangeRed);
            ObjectSetInteger(0, low_liq_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, low_liq_name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, low_liq_name, OBJPROP_FILL, true);
            ObjectSetInteger(0, low_liq_name, OBJPROP_BACK, true);
            ObjectSetInteger(0, low_liq_name, OBJPROP_SELECTABLE, false);
            ObjectSetString(0, low_liq_name, OBJPROP_TOOLTIP, "Zone de Basse Liquidité");
        }
    }
}

//+------------------------------------------------------------------+
//| Affiche le profil de volume                                     |
//+------------------------------------------------------------------+
void DrawVolumeProfile()
{
    if(!InpShowVolumeProfile) return;
    
    // Supprimer les anciens profils de volume
    int total_objects = ObjectsTotal(0, -1, -1);
    for(int i = total_objects - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i, -1, -1);
        if(StringFind(name, "VOLPROFILE_") == 0)
            ObjectDelete(0, name);
    }
    
    // Obtenir les données de prix et de volume
    MqlRates rates[];
    long volumes[];
    ArraySetAsSeries(rates, true);
    
    int copied = CopyRates(_Symbol, _Period, 0, InpVolumeProfileLookback, rates);
    CopyTickVolume(_Symbol, _Period, 0, InpVolumeProfileLookback, volumes);
    
    if(copied <= 0) return;
    
    // Créer un tableau pour stocker le volume par niveau de prix
    double price_step = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    
    // Trouver le plus bas et le plus haut
    double min_price = rates[0].low;
    double max_price = rates[0].high;
    for(int i = 1; i < copied; i++) {
        if(rates[i].low < min_price) min_price = rates[i].low;
        if(rates[i].high > max_price) max_price = rates[i].high;
    }
    
    int num_levels = (int)((max_price - min_price) / price_step) + 1;
    if(num_levels <= 0 || num_levels > 1000) return; // Limiter pour éviter les tableaux trop grands
    
    double volume_profile[];
    ArrayResize(volume_profile, num_levels);
    ArrayInitialize(volume_profile, 0);
    
    // Remplir le profil de volume
    for(int i = 0; i < copied; i++)
    {
        int level = (int)MathRound((rates[i].close - min_price) / price_step);
        if(level >= 0 && level < num_levels)
            volume_profile[level] += (double)volumes[i];
    }
    
    // Trouver le volume maximum pour la normalisation
    double max_vol = ArrayMaximum(volume_profile, 0, num_levels);
    if(max_vol <= 0) return;
    
    // Dessiner le profil de volume
    for(int i = 0; i < num_levels; i++)
    {
        if(volume_profile[i] > 0 && volume_profile[i] >= max_vol * InpVolumeProfileThreshold)
        {
            double price = min_price + i * price_step;
            double width = (volume_profile[i] / max_vol) * 50; // Largeur maximale de 50 pixels
            
            string name = "VOLPROFILE_" + IntegerToString(i);
            if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, TimeCurrent(), price + price_step/2, TimeCurrent() + 3600 * 24, price - price_step/2))
            {
                ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
                ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrDodgerBlue);
                ObjectSetInteger(0, name, OBJPROP_WIDTH, (int)width);
                ObjectSetInteger(0, name, OBJPROP_FILL, true);
                ObjectSetInteger(0, name, OBJPROP_BACK, true);
                ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
                ObjectSetString(0, name, OBJPROP_TOOLTIP, StringFormat("Prix: %.5f\nVolume: %.0f", price, volume_profile[i]));
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Dessine les retracements de Fibonacci                          |
//+------------------------------------------------------------------+
void DrawFibonacciRetracements()
{
    if(!InpShowFibonacci) return;
    
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    int copied = CopyRates(_Symbol, _Period, 0, 200, rates); // Augmenté à 200 bougies pour plus de contexte
    if(copied < 50) return; // Augmenté le minimum à 50 bougies pour des signaux plus fiables
    
    // Trouver les swings hauts et bas significatifs
    int lastSwingHigh = (int)iHighest(_Symbol, _Period, MODE_HIGH, 50, 0);
    int lastSwingLow = (int)iLowest(_Symbol, _Period, MODE_LOW, 50, 0);
    
    // S'assurer que le swing high est après le swing low pour une tendance haussière
    if(lastSwingHigh < lastSwingLow) {
        lastSwingHigh = (int)iHighest(_Symbol, _Period, MODE_HIGH, lastSwingLow, 0);
    } 
    // Ou que le swing low est après le swing high pour une tendance baissière
    else if(lastSwingLow < lastSwingHigh) {
        lastSwingLow = (int)iLowest(_Symbol, _Period, MODE_LOW, lastSwingHigh, 0);
    }
    
    if(lastSwingHigh > 0 && lastSwingLow > 0) {
        double high = rates[lastSwingHigh].high;
        double low = rates[lastSwingLow].low;
        
        // Ignorer les mouvements trop petits
        double minMovement = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100; // Au moins 100 points
        if(MathAbs(high - low) < minMovement) return;
        
        string fiboName = "FIBO_Retracement";
        
        // Supprimer l'ancien Fibonacci s'il existe
        ObjectDelete(0, fiboName);
        
        // Créer un nouveau Fibonacci
        if(ObjectCreate(0, fiboName, OBJ_FIBO, 0, 
                       rates[lastSwingHigh].time, high,
                       rates[lastSwingLow].time, low)) {
            
            // Définir les niveaux de retracement
            ObjectSetInteger(0, fiboName, OBJPROP_LEVELS, 9);
            
            // Niveaux de retracement (0%, 23.6%, 38.2%, 50%, 61.8%, 78.6%, 100%, 127.2%, 161.8%)
            double levels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0, 1.272, 1.618};
            color colors[] = {clrRed, clrOrange, clrYellow, clrGreen, clrBlue, clrIndigo, clrViolet, clrGray, clrWhite};
            
            for(int i = 0; i < 9; i++) {
                ObjectSetDouble(0, fiboName, OBJPROP_LEVELVALUE, i, levels[i]);
                ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, i, 
                              StringFormat("%.1f%%", levels[i] * 100));
                ObjectSetInteger(0, fiboName, OBJPROP_LEVELCOLOR, i, colors[i]);
                ObjectSetInteger(0, fiboName, OBJPROP_LEVELWIDTH, i, 1);
                ObjectSetInteger(0, fiboName, OBJPROP_LEVELSTYLE, i, STYLE_SOLID);
            }
            
            // Propriétés de l'objet
            ObjectSetInteger(0, fiboName, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(0, fiboName, OBJPROP_BACK, true);
            ObjectSetInteger(0, fiboName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, fiboName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        }
        // Définir les textes des niveaux
        ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 0, "0.0%");
        ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 1, "23.6%");
        ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 2, "38.2%");
        ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 3, "50.0%");
        ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 4, "61.8%");
        ObjectSetString(0, fiboName, OBJPROP_LEVELTEXT, 5, "100.0%");
    }
    
    // Mise à jour du graphique
    ChartRedraw();
}

//+------------------------------------------------------------------+
//| VÉRIFICATION TENDANCE POUR ÉVITER CONTRE-TENDANCE               |
//+------------------------------------------------------------------+
bool IsTrendAligned(string symbol, int direction)
{
    if(direction == 0) return false;
    
    // Vérifier tendance M1
    int m1_trend = CSignalValidator::GetTrendDirection(PERIOD_M1);
    
    // Vérifier tendance M5
    int m5_trend = CSignalValidator::GetTrendDirection(PERIOD_M5);
    
    // Vérifier tendance H1
    int h1_trend = CSignalValidator::GetTrendDirection(PERIOD_H1);
    
    // BUY signal: doit être dans un marché haussier
    if(direction > 0) {
        // Au moins 2 timeframes haussiers
        int bullish_count = 0;
        if(m1_trend > 0) bullish_count++;
        if(m5_trend > 0) bullish_count++;
        if(h1_trend > 0) bullish_count++;
        
        return (bullish_count >= 2);
    }
    
    // SELL signal: doit être dans un marché baissier
    if(direction < 0) {
        // Au moins 2 timeframes baissiers
        int bearish_count = 0;
        if(m1_trend < 0) bearish_count++;
        if(m5_trend < 0) bearish_count++;
        if(h1_trend < 0) bearish_count++;
        
        return (bearish_count >= 2);
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| CALCULER SL/TP INTELLIGENT POUR SMC                              |
//+------------------------------------------------------------------+
bool CalculateSMCSLTP(string symbol, double entry_price, int action, 
                      double key_level, double &sl, double &tp)
{
    int atr_handle = iATR(symbol, PERIOD_M1, 14);
    if(atr_handle == INVALID_HANDLE) return false;
    
    double atr[];
    if(CopyBuffer(atr_handle, 0, 0, 1, atr) < 1) {
        IndicatorRelease(atr_handle);
        return false;
    }
    IndicatorRelease(atr_handle);
    
    double sl_mult = 2.0;
    double tp_mult = 4.0;
    
    if(action == 1) {  // BUY
        if(key_level > 0 && key_level < entry_price) {
            sl = key_level * 0.9995;
        } else {
            sl = entry_price - (atr[0] * sl_mult);
        }
        tp = entry_price + (atr[0] * tp_mult);
    } else {  // SELL
        if(key_level > 0 && key_level > entry_price) {
            sl = key_level * 1.0005;
        } else {
            sl = entry_price + (atr[0] * sl_mult);
        }
        tp = entry_price - (atr[0] * tp_mult);
    }
    
    // Vérifier ratio R:R minimum 1:2
    double risk = MathAbs(entry_price - sl);
    double reward = MathAbs(tp - entry_price);
    
    if(risk > 0) {
        double rr = reward / risk;
        if(rr < 2.0) {
            if(action == 1) {
                tp = entry_price + (risk * 2.0);
            } else {
                tp = entry_price - (risk * 2.0);
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| PLACER UN ORDRE LIMITE INTELLIGENT                              |
//+------------------------------------------------------------------+
bool PlaceSmartLimitOrder(string symbol, int direction, double entry_price, double sl, double tp, double lot_size)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = symbol;
    request.volume = lot_size;
    request.type = (direction > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
    request.price = entry_price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 20;
    request.magic = InpMagicNumber;
    request.comment = "Smart Limit Order SMC";
    request.type_filling = ORDER_FILLING_IOC;
    
    // Expiration après 60 minutes
    request.expiration = TimeCurrent() + 3600;
    
    if(OrderSend(request, result)) {
        Print("✅ Ordre LIMITE placé: ", 
              (direction > 0 ? "BUY" : "SELL"), 
              " Prix: ", DoubleToString(entry_price, 5),
              " SL: ", DoubleToString(sl, 5),
              " TP: ", DoubleToString(tp, 5));
        return true;
    } else {
        Print("❌ Échec ordre LIMITE: ", GetLastError());
        return false;
    }
}

//+------------------------------------------------------------------+
//| GÉNÉRER SIGNAL SMC AVEC VÉRIFICATION TENDANCE                    |
//+------------------------------------------------------------------+
int GenerateSMCSignalWithTrendCheck(string symbol, double &entry_price, double &sl_price, double &tp_price, double &confidence)
{
    // Éviter contre-tendance
    int direction = 0;
    
    // Détecter signal SMC
    if(InpShowSR) {
        // Vérifier proximité support/résistance
        for(int i = 0; i < g_sr_zone_count; i++) {
            double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
            double distance = MathAbs(current_price - g_sr_zones[i].level) / current_price;
            
            if(distance <= 0.002) {  // Prix proche (0.2%)
                if(g_sr_zones[i].is_support && current_price > g_sr_zones[i].level) {
                    // BUY signal près du support
                    double sl, tp;
                    if(CalculateSMCSLTP(symbol, current_price, 1, g_sr_zones[i].level, sl, tp)) {
                        direction = 1;
                        entry_price = current_price;
                        sl_price = sl;
                        tp_price = tp;
                        confidence = g_sr_zones[i].strength;
                        break;
                    }
                } else if(!g_sr_zones[i].is_support && current_price < g_sr_zones[i].level) {
                    // SELL signal près de la résistance
                    double sl, tp;
                    if(CalculateSMCSLTP(symbol, current_price, -1, g_sr_zones[i].level, sl, tp)) {
                        direction = -1;
                        entry_price = current_price;
                        sl_price = sl;
                        tp_price = tp;
                        confidence = g_sr_zones[i].strength;
                        break;
                    }
                }
            }
        }
    }
    
    // Vérifier alignement tendance
    if(direction != 0 && !IsTrendAligned(symbol, direction)) {
        Print("🚫 Signal BLOQUÉ: Contre-tendance détectée");
        direction = 0;
    }
    
    return direction;
}

//+------------------------------------------------------------------+
//| STRUCTURE POUR SCAN MULTI-SYMBOLES                               |
//+------------------------------------------------------------------+
struct SymbolSignal {
    string symbol;
    int direction;
    double entry_price;
    double sl_price;
    double tp_price;
    double confidence;
    double score;
    string reason;
};

//+------------------------------------------------------------------+
//| SCAN TOUS LES SYMBOLES ET TROUVER LE MEILLEUR SIGNAL             |
//+------------------------------------------------------------------+
bool ScanAllSymbolsForBestOpportunity(SymbolSignal &best_signal)
{
    if(!InpEnableTrading) return false;
    
    // Liste des symboles à scanner (prioriser Boom/Crash + paires majeures)
    string symbols_to_scan[] = {
        "Boom 1000 Index", "Crash 1000 Index",
        "Boom 500 Index", "Crash 500 Index",
        "Boom 300 Index", "Crash 300 Index",
        "EURUSD", "GBPUSD", "USDJPY", "AUDUSD",
        "EURGBP", "NZDUSD", "USDCHF", "USDCAD"
    };
    
    SymbolSignal signals[];
    int signal_count = 0;
    
    for(int i = 0; i < ArraySize(symbols_to_scan); i++) {
        string symbol = symbols_to_scan[i];
        
        // Vérifier si le symbole existe
        if(!SymbolSelect(symbol, true)) {
            Print("⚠️ Symbole introuvable: ", symbol);
            continue;
        }
        
        // Vérifier qu'il n'y a pas déjà de position sur ce symbole
        bool hasPosition = false;
        for(int j = 0; j < PositionsTotal(); j++) {
            ulong tk = PositionGetTicket(j);
            if(!PositionSelectByTicket(tk)) continue;
            if(PositionGetString(POSITION_SYMBOL) == symbol && 
               (int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                hasPosition = true;
                break;
            }
        }
        
        if(hasPosition) {
            if(InpDebug) Print("⏸ Position déjà ouverte sur ", symbol);
            continue;
        }
        
        // Générer un signal SMC pour ce symbole
        double entry_price = 0, sl_price = 0, tp_price = 0, confidence = 0;
        int direction = GenerateSMCSignalWithTrendCheck(symbol, entry_price, sl_price, tp_price, confidence);
        
        if(direction != 0 && confidence >= InpSMCMinStrength) {
            // Valider les SL/TP
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
            double price = (direction > 0) ? ask : bid;
            
            // Valider et ajuster SL/TP si nécessaire
            if(!EnsureValidStops(symbol, direction, price, point, sl_price, tp_price)) {
                Print("❌ SL/TP invalides pour ", symbol);
                continue;
            }
            
            // Calculer un score pour ce signal
            double score = confidence;
            
            // Bonus si c'est un Boom/Crash index
            if(IsBoomCrashIndex(symbol)) {
                score += 0.2;
            }
            
            // Bonus si trend fortement aligné
            if(IsTrendAligned(symbol, direction)) {
                score += 0.3;
            }
            
            // Bonus si haute confluence
            double distance_sr = 0.01; // TODO: calculer distance au S/R
            if(distance_sr <= InpSMCSRTolerance) {
                score += 0.2;
            }
            
            // Ajouter le signal
            ArrayResize(signals, signal_count + 1);
            signals[signal_count].symbol = symbol;
            signals[signal_count].direction = direction;
            signals[signal_count].entry_price = entry_price;
            signals[signal_count].sl_price = sl_price;
            signals[signal_count].tp_price = tp_price;
            signals[signal_count].confidence = confidence;
            signals[signal_count].score = score;
            signals[signal_count].reason = "SMC Signal";
            signal_count++;
            
            if(InpDebug) {
                Print("🎯 Signal trouvé sur ", symbol, 
                      " Direction: ", (direction > 0 ? "BUY" : "SELL"),
                      " Score: ", DoubleToString(score, 2),
                      " Confidence: ", DoubleToString(confidence*100, 1), "%");
            }
        }
    }
    
    if(signal_count == 0) return false;
    
    // Trouver le meilleur signal (score le plus élevé)
    int best_idx = 0;
    double best_score = signals[0].score;
    
    for(int i = 1; i < signal_count; i++) {
        if(signals[i].score > best_score) {
            best_score = signals[i].score;
            best_idx = i;
        }
    }
    
    best_signal = signals[best_idx];
    
    Print("🏆 MEILLEUR SIGNAL TROUVÉ: ", best_signal.symbol,
          " Direction: ", (best_signal.direction > 0 ? "BUY" : "SELL"),
          " Score: ", DoubleToString(best_signal.score, 2),
          " Confiance: ", DoubleToString(best_signal.confidence*100, 1), "%");
    
    return true;
}

//+------------------------------------------------------------------+
//| Gestion des événements du graphique                             |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                 const long &lparam,
                 const double &dparam,
                 const string &sparam)
{
    // Mise à jour des dessins lors du changement de timeframe ou de symbole
    if(id == CHARTEVENT_CHART_CHANGE) {
        // Délai pour s'assurer que le changement est terminé
        EventSetTimer(1);
    }
    
    // Mise à jour des dessins lors d'un clic sur le graphique
    if(id == CHARTEVENT_CLICK) {
        // Redessiner tous les éléments
        DrawMarketStructure();
        DrawOTEZones();
        DrawFibonacciRetracements();
    }
}
