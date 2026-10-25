//+------------------------------------------------------------------+
//| Properties & Includes                                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Professional Trading EA"
#property link      "https://www.mql5.com"
#property version   "3.00"
#property description "Spike Hunter - Trading professionnel et sécurisé"

//--- Includes
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Structures pour Support/Résistance et Trendlines               |
//+------------------------------------------------------------------+

// Structure pour une zone de support/résistance
struct SRZone {
    double level;                    // Niveau de prix
    double strength;                 // Force de la zone (0-1)
    int touch_count;                 // Nombre de touches
    datetime first_touch;            // Première touche
    datetime last_touch;             // Dernière touche
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


// Variables pour stabilité de confiance
double g_confidence_history[10];     // Historique des confiances
int g_confidence_index = 0;          // Index actuel
datetime g_last_confidence_check = 0; // Dernière vérification
double g_min_stable_confidence = 0.95; // Confiance minimum stable (95%)

//--- Forward declarations for functions used before their definitions
double SnapToDerivBoomCrashLots(const double desired);
bool IsBoomCrashIndex(string symbol);
double SnapLotToSymbol(const string symbol, const double desired);
void   EnsureValidStops(const string symbol, const int direction, const double price, const double point, double &sl_price, double &tp_price);

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
    if(h2>h3 && h3>h4) score += 15; // lower-highs → biais vendeur
    if(l2<l3 && l3<l4) score += 15; // higher-lows → biais acheteur
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
    int bScore = DetectICTStructureScore(r);         // 0..30 → cap 20
    if(bScore > 20) bScore = 20;
    int tScore = DetectICTTrendScore();              // 0..15 → cap 10
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
input group "=== CONFIGURATION GÉNÉRALE ==="
input bool     InpEnableTrading        = true;     // Activer le trading
input int      InpMagicNumber          = 123456;   // Magic number
input double   InpLotSize              = 0.2;      // Taille du lot par défaut
input int      InpStopLoss             = 15;       // Stop Loss (points)
input int      InpTakeProfit           = 25;       // Take Profit (points)

input group "=== GESTION DES RISQUES ==="
input double   InpMaxRiskPercent       = 1.0;      // Risque maximum par trade (%)
input double   InpMaxDailyLoss         = 10.0;     // Perte max journalière ($)
input int      InpMaxTrades            = 2;        // Nombre max de trades
input int      InpCooldownMinutes      = 5;        // Cooldown entre trades (min)
input bool     InpStrictSinglePosition = false;    // Une seule position à la fois
input bool     InpEnableSpikeReentry   = true;     // Ré-entrée après spike
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_H1; // Timeframe pour tendance
input int      InpMaxGlobalSimultaneousTrades = 2; // Nombre max de trades simultanés global

input group "=== TRADING INTELLIGENT (FAIBLE PERTE, MAX GAIN) ==="
input bool     InpUseSmartTrading       = true;     // Activer le trading intelligent
input double   InpMaxRiskPerTrade       = 0.5;      // Risque max par trade (0.5% du capital)
input double   InpMinRiskRewardRatio   = 2.0;      // Ratio risque/récompense minimum (1:2)
input double   InpMinConfidenceThreshold = 90.0;    // Seuil de confiance minimum (90%)
input bool     InpSpikeOnlyMode         = true;     // N'entrer que si probabilité de spike élevée (≥90%, pré-signal)
input bool     InpValidateTradeWin      = true;     // Valider que le trade est gagnant en 1 min
input bool     InpVerifySpikeBeforeSignal = true;   // Vérifier le spike avant d'annoncer
input bool     InpEnableEarlyDetection  = true;     // Activer la détection précoce
input int      InpLookbackPeriod        = 20;       // Période de lookback pour détection
input double   InpConsolidationThreshold = 0.7;     // Seuil de consolidation (0.7 = 70%)
input double   InpWickRatioThreshold    = 2.0;      // Seuil de ratio de mèche (2.0 = 200%)
input bool     InpUseMultiTimeframe     = false;    // Utiliser la validation multi-timeframe
input bool     InpUseSupportResistance  = false;    // Utiliser la validation support/résistance
input int      InpMinConfidence         = 50;       // Confiance minimum pour validation
input double   InpVolatilityThreshold   = 1.3;      // Seuil d'augmentation de volatilité (1.3 = 130%)
input double   InpSRProximityPercent    = 0.5;      // Proximité S/R en pourcentage (0.5%)
input bool     InpUseDynamicTP          = true;     // Take Profit dynamique basé sur volatilité
input bool     InpUseAdaptiveSL         = true;     // Stop Loss adaptatif
input bool     InpUsePartialClose       = true;     // Fermeture partielle des positions
input double   InpPartialClosePercent   = 50.0;     // Pourcentage de fermeture partielle
input int      InpPartialCloseAtProfit  = 6;       // Fermeture partielle à X points de profit
input bool     InpUseTrailingStopSmart  = true;    // Trailing stop intelligent
input int      InpTrailingStartPoints   = 4;       // Démarrage trailing stop (points)
input int      InpTrailingStepPoints    = 2;       // Pas du trailing stop (points)

input group "=== API CONNEXION ==="
input string   InpAPIUrl               = "http://127.0.0.1:8001"; // URL API Python
input int      InpAPITimeout           = 3000;     // Timeout API (ms)
input bool     InpUseAPIPredictions    = true;     // Utiliser prédictions API

input group "=== NOTIFICATIONS ==="
input bool     InpSendNotifications    = true;     // Envoyer notifications
input bool     InpPlaySounds           = false;    // Alertes sonores (désactivées)
input string   InpSoundFile            = "alert.wav"; // Fichier son pour alertes
input bool     InpNotifyRawSignals     = false;    // Notifier les pré-signaux (désactivé)
input bool     InpDrawPreSignalArrows  = false;    // Dessiner flèches pré-signal (désactivé)
input int      InpNotificationCooldownSec = 30;    // Cooldown notifications (sec)

input group "=== ICT STRATEGY (BOS, COS, OTE, FIB, PA) ==="
input bool     InpEnableICT            = true;     // Activer filtres ICT
input int      InpICTMinScore          = 40;       // Score ICT minimum (0-100)
input bool     InpICTUseBOSCOS         = true;     // Utiliser BOS/COS (Break/Change of Structure)
input bool     InpICTUseOTE            = true;     // Utiliser OTE (Optimal Trade Entry) 62-79%
input bool     InpICTUseFibonacci      = true;     // Utiliser confluence niveaux Fibonacci
input bool     InpICTUsePriceAction    = true;     // Rejets, mèches longues, FVG simple
input bool     InpICTUseTrendMTF       = true;     // Tendance MTF alignée
input bool     InpICTAnnouncePreSpike  = true;     // Annoncer le spike 1 minute avant (flèche unique)
input bool     InpAlwaysDrawSpikeZones = false;    // Dessiner zones (OTE/BOS/COS/Compression) en continu

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
input bool     InpUseExternalSignals   = true;     // Consommer des signaux via API externe
input string   InpExternalSignalsURL   = "http://localhost:8001/signals"; // Endpoint /signals
input string   InpTrendAnalysisURL     = "http://localhost:8001/trend"; // Endpoint /trend
input int      InpExtSigMinConfidence  = 70;       // Confiance minimale API (%)
input bool     InpExtSigAsHardFilter   = false;    // Exiger accord API sur signaux locaux
input int      InpExtSigTTLSeconds     = 5;        // Durée de vie du cache (s)
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
input bool     InpImmediateCloseAfterSpike = true; // Fermeture immédiate après capture
input double   InpQuickGainThreshold   = 0.5;      // Seuil de gain rapide pour fermeture ($)
input double   InpUltraHighConfidence  = 98.0;     // Confiance minimum ultra-élevée (%) - Plus strict
input double   InpStableConfidenceMin  = 98.0;     // Confiance minimum stable pour trading (%) - Plus strict
input double   InpConfidenceStabilityMax = 2.0;    // Écart-type maximum pour stabilité (%) - Plus strict
input bool     InpSingleTradeOnly      = false;    // Un seul trade à la fois
input int      InpMaxSimultaneousTrades = 2;       // Nombre maximum de trades simultanés
input int      InpMinTradeIntervalSeconds = 300;   // Intervalle minimum entre trades (sec)
input double   InpMaxLossPerTradeUSD   = 2.0;      // Perte maximale par trade ($)

input group "=== SIGNALS BOOM/CRASH S/R ==="
input bool     InpEnableBoomCrashSignals = true;   // Activer signaux Boom/Crash basés S/R
input double   InpSupportBoomThreshold = 60.0;     // Seuil support pour signal BUY (60%)
input double   InpResistanceCrashThreshold = 50.0; // Seuil résistance pour signal SELL (50%)
input double   InpSRProximityTolerance = 0.0003;   // Tolérance proximité S/R (en prix)
input bool     InpCloseImmediatelyAfterSpike = true; // Fermeture immédiate après spike

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
input double   InpMaxLossUSDPerTrade   = 2.0;      // Perte max $ par trade
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
input double   InpPerTradeLossCloseUSD = 1.5;       // Fermer une position si perte ≥ $1.5 - MODIFIÉ
input int      InpReentryCooldownMin   = 5;         // Attendre N minutes avant reprise après perte
input double   InpPerTradeProfitCloseUSD = 2.0;     // Fermer une position si gain ≥ $2
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
input int      InpEMATouchLookaheadMin = 1;         // Horizon minutes pour approche EMA10
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

input group "=== AFFICHAGE MTF (BOS/COS/OTE/OB) ==="
input bool     InpDrawMTFStructures     = true;     // Tracer BOS/COS/OTE/OB sur H4,H1,M30,M15,M5
input int      InpMTFUpdateSec          = 30;       // Fréquence de mise à jour (secondes)
input color    InpColH4                 = clrViolet;
input color    InpColH1                 = clrDodgerBlue;
input color    InpColM30                = clrSeaGreen;
input color    InpColM15                = clrDarkOrange;
input color    InpColM5                 = clrDimGray;

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

        // Lot
        double lotRaw = (IsBoomCrashIndex(symbol))? 0.20 : CalculateSmartLotSize(symbol, price, sl_price);
        double lotSize = SnapLotToSymbol(symbol, lotRaw);
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
            Print("🚫 Un seul trade autorisé - Trade existant détecté");
            return false;
        }
        
        if(current_trades >= InpMaxSimultaneousTrades) {
            Print("🚫 Limite de trades simultanés atteinte: ", current_trades, "/", InpMaxSimultaneousTrades);
            return false;
        }
        
        // Vérifier l'intervalle minimum entre les trades
        static datetime last_trade_time = 0;
        if(last_trade_time > 0 && TimeCurrent() - last_trade_time < InpMinTradeIntervalSeconds) {
            Print("🚫 Intervalle minimum entre trades non respecté (", InpMinTradeIntervalSeconds, " sec)");
            return false;
        }
        
        // Vérifier les trades ouverts par symbole
        int openTradesSymbol = 0;
        // Vérifier les trades ouverts global (même magic)
        int openTradesGlobal = 0;
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong tk = PositionGetTicket(i);
            if(!PositionSelectByTicket(tk)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            openTradesGlobal++;
            if(PositionGetString(POSITION_SYMBOL) == _Symbol) openTradesSymbol++;
        }
        
        if(openTradesSymbol >= InpMaxSimultaneousTrades) return false;
        if(openTradesGlobal >= InpMaxGlobalSimultaneousTrades) return false;
        
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
        if(InpEnablePreSpike && IsBoomCrashIndex(_Symbol))
        {
            int dir = 0; int conf = 0;
            if(DetectPreSpike(rates, dir, conf))
            {
                if(InpAPlusMode && !IsAPlusEnvironment(dir)) return 0;
                g_isEarlySignal = true;
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
            Print("🎯 SIGNAL: Consolidation détectée");
            int d = AnalyzeDirection(rates);
            if(InpAPlusMode && d!=0 && !IsAPlusEnvironment(d)) d = 0;
            // Exécuter en M5/M1 selon tendance long-terme (éviter contre-tendance Boom/Crash)
            d = EnforceBoomCrashDirection(d);
            return d;
        }
        
        // 2. Détection de mèches longues
        if(HasLongWicks(rates)) {
            Print("🎯 SIGNAL: Mèches longues détectées");
            {
                int d = AnalyzeDirection(rates);
                if(InpAPlusMode && d!=0 && !IsAPlusEnvironment(d)) d = 0;
                return d;
            }
        }
        
        // 3. Détection de volatilité croissante
        if(IsVolatilityIncreasing(rates)) {
            Print("🎯 SIGNAL: Volatilité croissante");
            {
                int d = AnalyzeDirection(rates);
                if(InpAPlusMode && d!=0 && !IsAPlusEnvironment(d)) d = 0;
                return d;
            }
        }
        
        return 0;
    }
    
private:
    bool IsAPlusEnvironment(const int direction)
    {
        if(direction==0) return false;
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
        
        return dir; // 1 ou -1
    }
    
    //+------------------------------------------------------------------+
    //| Obtenir la confiance du signal                                  |
    //+------------------------------------------------------------------+
public:
    double GetSignalConfidence() {
        if(!InpEnableEarlyDetection) return 0.0;
        
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
        if(atrH!=INVALID_HANDLE){ double arr[180]; int n=CopyBuffer(atrH,0,0,MathMin(look+1,ArraySize(arr)),arr); IndicatorRelease(atrH); if(n>=look){ double now=arr[0]; double avg=0; for(int i=1;i<look;i++) avg+=arr[i]; avg/=MathMax(1,look-1); if(now >= InpGodATRBoostMin * MathMax(1e-8, avg)) score += 10; } }

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
                Print("❌ Echec LIMIT IA: ", GetLastError(), " / ", rs.comment);
                return false;
            }
            Print("✅ LIMIT IA placé: ", (direction>0?"BUY_LIMIT":"SELL_LIMIT"), " @ ", DoubleToString(rq.price,digits),
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
        double lotSize = CalculateValidLotSize();
        double lotRaw = lotSize;
        if(IsBoomCrashIndex(_Symbol)) lotRaw = 0.20; else if(InpUseSmartTrading) lotRaw = CalculateSmartLotSize(_Symbol, price, sl_price);
        lotSize = SnapLotToSymbol(_Symbol, lotRaw);
        
        if(lotSize <= 0) {
            Print("❌ Lot size invalide: ", lotSize);
            return false;
        }
        
        // Calculer le Take Profit dynamique
        double tp_points = CalculateDynamicTakeProfit(_Symbol, price, direction, sl_price);
        double tp_price = (direction > 0) ? price + (tp_points * point) : price - (tp_points * point);
        
        // Vérifier le ratio risque/récompense
        double risk_reward_ratio = tp_points / sl_points;
        if(risk_reward_ratio < InpMinRiskRewardRatio) {
            Print("⚠️ Ratio risque/récompense insuffisant: ", DoubleToString(risk_reward_ratio, 2), " < ", DoubleToString(InpMinRiskRewardRatio, 2));
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
            Print("⚠️ Échec envoi ordre (retcode=", err, ") → tentative d'ajustement.");
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
            
            Print("🧠 TRADE INTELLIGENT EXÉCUTÉ: ", (direction > 0 ? "BUY" : "SELL"),
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
            Print("❌ ÉCHEC TRADE: ", m_trade.ResultRetcode(), " - ", m_trade.ResultComment());
        }
        
        return result;
    }
    
    bool ExecuteTradeOnSymbol(const string symbol, const int direction)
    {
        if(direction==0) return false;
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

        // Si Boom/Crash, aligner explicitement sur l'échelle Deriv
        if(IsBoomCrashIndex(_Symbol))
            lotSize = SnapToDerivBoomCrashLots(0.20);
        
        // Normaliser selon le step
        if(lotStep > 0.0)
            lotSize = MathFloor(lotSize / lotStep) * lotStep;
        
        // Bornes broker
        if(lotSize < minLot) lotSize = minLot;
        if(lotSize > maxLot) lotSize = maxLot;
        
        // Vérification finale
        if(lotSize < minLot || lotSize > maxLot) {
            Print("❌ Lot size invalide après normalisation: ", lotSize,
                  " MinBroker:", minLot, " MaxBroker:", maxLot, " Step:", lotStep);
            return 0;
        }
        
        return NormalizeDouble(lotSize, 2);
    }
};

//--- Variables globales
CRiskManager* g_riskManager = NULL;
CSignalDetector* g_signalDetector = NULL;
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

// --- Cache signaux externes API
static int      g_extLastDir = 0;         // 1 BUY, -1 SELL, 0 neutre
static int      g_extLastConf = 0;        // 0..100
static datetime g_extLastUpdate = 0;      // timestamp

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🤖 SPIKE HUNTER PROFESSIONNEL - Version 3.0 Corrigée");
    Print("   ✅ Architecture modulaire et sécurisée");
    Print("   ✅ Gestion des risques professionnelle");
    Print("   ✅ Validation des signaux rigoureuse");
    Print("   ✅ Performance optimisée");
    
    // Initialiser les gestionnaires
    g_riskManager = new CRiskManager();
    g_signalDetector = new CSignalDetector();
    g_tradeExecutor = new CTradeExecutor();
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🤖 SPIKE HUNTER - Arrêt du trading");
    
    // Nettoyer les ressources
    if(g_riskManager != NULL) {
        delete g_riskManager;
        g_riskManager = NULL;
    }
    if(g_signalDetector != NULL) {
        delete g_signalDetector;
        g_signalDetector = NULL;
    }
    if(g_tradeExecutor != NULL) {
        delete g_tradeExecutor;
        g_tradeExecutor = NULL;
    }
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
    
    Print("🧠 LOT INTELLIGENT: Risque: $", DoubleToString(risk_amount, 2), 
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
    
    Print("🎯 TP DYNAMIQUE: SL: ", DoubleToString(sl_distance_points, 1), 
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
    
    Print("🛡️ SL ADAPTATIF: ATR: ", DoubleToString(atr_points, 1), 
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
        
        // Vérifier la fermeture automatique après spike (seulement si en gain)
        if(InpImmediateCloseAfterSpike && DetectSpikeForClose() && current_profit > 0.0) {
            string symbol = PositionGetString(POSITION_SYMBOL);
            int type = (int)PositionGetInteger(POSITION_TYPE);
            
            Print("🚨 SPIKE DÉTECTÉ + GAIN - Fermeture immédiate du trade ", smart_trades[i].ticket, 
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
            request.comment = "SpikeCloseGain";
            
            if(OrderSend(request, result)) {
                Print("✅ Trade fermé automatiquement après spike + gain - Profit final: $", DoubleToString(current_profit, 2));
                smart_trades[i].ticket = 0;
                continue;
            } else {
                Print("❌ Échec fermeture automatique après spike: ", GetLastError());
            }
        }
        
        // Fermeture immédiate si profit > seuil configuré (capture rapide des gains)
        // Pour les indices Boom/Crash, fermer dès le premier centime de profit
        double quick_threshold = InpQuickGainThreshold;
        string symbol = PositionGetString(POSITION_SYMBOL);
        if(StringFind(symbol, "Crash") >= 0 || StringFind(symbol, "Boom") >= 0) {
            quick_threshold = 0.01; // Fermer dès 1 centime de profit pour les indices
        }
        
        if(current_profit > quick_threshold) {
            int type = (int)PositionGetInteger(POSITION_TYPE);
            
            Print("💰 GAIN RAPIDE - Fermeture immédiate du trade ", smart_trades[i].ticket, 
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
                Print("✅ Trade fermé pour gain rapide - Profit final: $", DoubleToString(current_profit, 2));
                smart_trades[i].ticket = 0;
                continue;
            } else {
                Print("❌ Échec fermeture pour gain rapide: ", GetLastError());
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
                Print("💰 FERMETURE PARTIELLE: ", DoubleToString(InpPartialClosePercent, 0), "% à ", DoubleToString(profit_points, 1), " pts de profit");
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
                Print("✅ Fermeture immédiate en gain: ", DoubleToString(current_profit,2), " USD");
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
        Print("🎯 TRAILING STOP ACTIVÉ: ", DoubleToString(profit_points, 1), " pts de profit");
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
        Print("✅ FERMETURE PARTIELLE: ", DoubleToString(close_volume, 2), " lots fermés");
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
        Print("🔄 SL MODIFIÉ: ", DoubleToString(new_sl, _Digits));
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
    
    Print("🧠 TRADE INTELLIGENT AJOUTÉ: Ticket ", ticket, " | Lot: ", DoubleToString(lot_size, 2), 
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
    
    Print("⏳ SIGNAL EN ATTENTE: Direction ", (direction > 0 ? "BUY" : "SELL"), 
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
    
    if(direction > 0) {
        // Pour BUY, vérifier que le prix a monté
        return (current_price > entry_price && price_movement >= min_spike_points);
    } else {
        // Pour SELL, vérifier que le prix a baissé
        return (current_price < entry_price && price_movement >= min_spike_points);
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
            Print("✅ TRADE VALIDÉ GAGNANT: Ticket ", ticket, " | Profit: ", DoubleToString(current_profit, 2), 
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
            Print("⏰ SIGNAL EXPIRÉ: Direction ", (pending_signals[i].direction > 0 ? "BUY" : "SELL"));
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
                Print("🎯 SPIKE VÉRIFIÉ: Direction ", (pending_signals[i].direction > 0 ? "BUY" : "SELL"));
            }
        }
        
        // Si le spike est vérifié, on peut exécuter le trade
        if(pending_signals[i].spike_verified && !pending_signals[i].trade_validated) {
            if(g_riskManager.CanOpenTrade()) {
                // Exécuter le trade avec la confiance
                if(g_tradeExecutor.ExecuteTrade(pending_signals[i].direction)) {
                    pending_signals[i].trade_validated = true;
                    Print("🚀 TRADE EXÉCUTÉ APRÈS VALIDATION: Direction ", (pending_signals[i].direction > 0 ? "BUY" : "SELL"), 
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
                            NotifyOnce(StringFormat("✅ Signal validé %s (≥ %.0f%%) sur %s", sidev, InpMinConfidenceThreshold, _Symbol));
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
    
    // Mise à jour dynamique des patterns en temps réel
    UpdateDynamicPatterns();
    
    // Mise à jour des données API (tous les endpoints)
    UpdateAPIData();
    
    // FORCER LA MISE À JOUR DES ZONES S/R (pour test)
    static datetime last_force_update = 0;
    if(TimeCurrent() - last_force_update >= 300) { // Toutes les 5 minutes
        Print("🔄 FORÇAGE MISE À JOUR ZONES S/R");
        UpdateSRZones();
        last_force_update = TimeCurrent();
    }
    
    
    // PRÉDICTION DE SPIKE IMMINENT
    static datetime last_prediction = 0;
    if(TimeCurrent() - last_prediction >= 10) { // Vérification toutes les 10 secondes
        double confidence = 0;
        int direction = 0;
        
        if(PredictImminentSpike(confidence, direction)) {
            Print("🔮 SPIKE IMMINENT DÉTECTÉ - Confiance: ", DoubleToString(confidence, 1), "%",
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
            Print("⚠️ Confiance instable - Trade bloqué");
        }
    }
    
    // Vérifier que les objets sont initialisés
    if(g_riskManager == NULL || g_signalDetector == NULL || g_tradeExecutor == NULL) {
        Print("❌ Objets non initialisés");
        return;
    }
    
    // Reset journalier
    MqlDateTime currentTime;
    TimeToStruct(TimeCurrent(), currentTime);
    if(g_lastDay != currentTime.day) {
        g_lastDay = currentTime.day;
        g_riskManager.ResetDaily();
        Print("📅 Nouveau jour - Reset des compteurs");
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
        // Interroger l'endpoint /trend pour le symbole courant
        string headers = "Accept: application/json";
        string respHeaders = ""; char resp[]; ResetLastError();
        uchar payload[]; ArrayResize(payload,0);
        string trendUrl = InpTrendAnalysisURL + "?symbol=" + _Symbol + "&timeframe=M1";
        int code = WebRequest("GET", trendUrl, headers, 4000, payload, resp, respHeaders);
        if(code==200)
        {
            string body = CharArrayToString(resp, 0, -1, CP_UTF8);
            // Extraire la direction/force/confiance de la tendance
            int pDir = StringFind(body, "\"direction\"");
            int pStr = StringFind(body, "\"strength\"");
            int pConf= StringFind(body, "\"confidence\"");
            string sdir="NEUTRE"; int sstr=0; int sconf=0;
            if(pDir>=0){ int cd=StringFind(body,":",pDir); if(cd>=0){ string seg=StringSubstr(body,cd+1,16); if(StringFind(seg,"BUY")>=0) sdir="BUY"; else if(StringFind(seg,"SELL")>=0) sdir="SELL"; }}
            if(pStr>=0){ int cs=StringFind(body,":",pStr); if(cs>=0){ string seg=StringSubstr(body,cs+1,6); sstr=(int)StringToInteger(seg);} }
            if(pConf>=0){ int cc=StringFind(body,":",pConf); if(cc>=0){ string seg=StringSubstr(body,cc+1,6); sconf=(int)StringToInteger(seg);} }
            // Afficher aussi l'analyse de tendance via helper
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
                Print("💰 TP panier atteint (", DoubleToString(totalProfit,2), " >= ", DoubleToString(InpBasketProfitCloseUSD,2), ") -> Fermeture TOTALE de toutes les positions avec magic ", InpMagicNumber);
                // Close all positions with the magic number
                CloseAllPositions(InpMagicNumber);
                // Stop the day (disable re-entry for the day)
                g_dailyHalted = true;
            }
            // Check against basket loss limit
            else if((-totalLoss) >= InpBasketLossCloseUSD) // totalLoss is negative, so -totalLoss is positive loss
            {
                Print("🛑 Perte panier atteinte (", DoubleToString(-totalLoss,2), " >= ", DoubleToString(InpBasketLossCloseUSD,2), ") -> Fermeture TOTALE de toutes les positions avec magic ", InpMagicNumber);
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
                    Print("🛑 Perte par trade atteinte (", DoubleToString(-p,2), ") sur ", psym, " -> fermeture et cooldown.");
                    // Arm re-entry cooldown if a loss occurred
                    SetSymbolCooldown(psym, InpReentryCooldownMin * 60); // Cooldown for this symbol
                // Count consecutive loss for symbol and potentially trigger 5-min cooldown after two consecutive losses
                IncrementConsecutiveLoss(psym);
                int lidx = FindLossIndex(psym);
                if(lidx>=0 && g_lossCounts[lidx] >= 2)
                {
                    Print("⏳ Deux pertes consécutives sur ", psym, " → cooldown 5 minutes");
                    SetSymbolCooldown(psym, 5 * 60);
                }
                }
                else // closeForProfit
                {
                    Print("✅ Gain par trade atteint (", DoubleToString(p,2), ") sur ", psym, " -> sécurisation.");
                    // If Boom/Crash and re-entry enabled, arm it after a quick TP
                    if(IsBoomCrashIndex(psym) && InpEnableSpikeReentry)
                        g_bcReentryArmedTime = TimeCurrent(); // Arm the general re-entry timer
                // Reset consecutive loss counters on profit
                ResetConsecutiveLoss(psym);
                }
            }
            else
            {
                Print("❌ Échec fermeture per-trade (", psym, "): ", GetLastError(), " - ", rs.comment);
            }
        }
    }

    // Global cooldown check: if any trade was closed due to loss, enforce global cooldown
    // A simple way to implement this is to check if any position was closed for loss in the last loop
    // and then prevent further trades. For simplicity, we rely on individual symbol cooldowns and the general risk manager cooldown.
    // If you need a global cooldown *after* any loss, you'd need a separate timer.

    // Vérifier si on peut trader (basé sur les règles du Risk Manager)
    if(!g_riskManager.CanOpenTrade()) return;

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
                Print("🛑 Perte agrégée par symbole atteinte (", symbols[k], ") = ", DoubleToString(lossBySymbol[k],2), " ≤ -$", DoubleToString(perSymbolCap,2), " → fermeture de sécurité");
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
            Print("🛑 Seuil global de perte atteint (", DoubleToString(totalOpenPnl,2), ") → fermeture de sécurité");
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
                    Print("❌ Échec fermeture globale: ", GetLastError());
                }
            }
            g_globalCooldownUntil = TimeCurrent() + InpGlobalCooldownMin*60;
            return;
        }
    }
    
    // Détecter les signaux
    int signal = g_signalDetector.DetectSignal();
    
    // Filtre de tendance: trader seulement dans le sens de la tendance
    if(InpUseTrendOnly)
    {
        int trend = CTradeExecutor::GetTrendDirection(InpTrendTF);
        if(trend==0) signal = 0; // pas de trade si tendance incertaine
        else if(signal*trend < 0) signal = 0; // bloquer contre-tendance
    }
    
    // Calculer la confiance du signal
    double signal_confidence = g_signalDetector.GetSignalConfidence();
    
    // Vérifier le seuil de confiance minimum
    if(signal != 0 && !IsSignalConfidenceValid(signal_confidence)) {
        Print("❌ Signal rejeté: Confiance insuffisante (", DoubleToString(signal_confidence, 1), "% < ", DoubleToString(InpMinConfidenceThreshold, 1), "%)");
        signal = 0; // Annuler le signal
    }
    // SpikeOnly: exiger un pré-signal spike et confiance ≥ 90%
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
        Print("✅ Signal détecté: Direction ", (signal > 0 ? "BUY" : "SELL"), " | Confiance: ", DoubleToString(signal_confidence, 1), "%");
    }

    // 0) Analyse de tendance API: validation préalable
    int apiTrend=0, apiStrength=0; bool hasTrend = GetTrendAnalysis(_Symbol, apiTrend, apiStrength);
    if(hasTrend && InpExtSigAsHardFilter)
    {
        // Si l'API indique une tendance forte, l'utiliser comme filtre
        if(apiStrength >= 80 && signal != 0 && signal != apiTrend)
        {
            Print("❌ Signal rejeté: Contre-tendance API (API:", apiTrend, " vs Local:", signal, ")");
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
        NotifyOnce(StringFormat("📡 Pré-signal détecté: %s %s", _Symbol, side0));
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
                NotifyOnce(StringFormat("📣 Pré-spike attendu dans ~1 min: %s %s", _Symbol, sideAnn));
            }
        }
        // Suppressed ICT drawings (BOS/COS/OTE)
        AddPendingSignal(signal, signal_confidence, entry_price);
        return;
    }

    // Bloquer contre-tendance M1+M5 et règles Boom/Crash demandées
    if(InpEnforceM1Trend && !CSignalValidator::IsAlignedWithM1M5(signal))
    {
        Print("❌ Signal rejeté: Contre-tendance M1/M5 détectée.");
        return;
    }
    
    // Valider le signal
    if(!g_isEarlySignal)
    {
    if(!CSignalValidator::ValidateSignal(signal)) {
            Print("❌ Signal rejeté par validation (Confiance=", CSignalValidator::ComputeGodScore(signal), ")");
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
            NotifyOnce(StringFormat("✅ Trade %s exécuté sur %s", side, _Symbol));
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
            NotifyOnce(StringFormat("🕒 Ordre %s placé @ %s (SL=%s, TP=%s)%s", s2, DoubleToString(g_aiLastEntry,digits), (slp>0?DoubleToString(slp,digits):"0"), (tpp>0?DoubleToString(tpp,digits):"0"), explain));
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
            Print("❌ Échec fermeture panier (", psym, "): ", GetLastError(), " - ", rs.comment);
        }
        else
        {
            Print("✅ Fermeture position ", psym, " (", (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL"), ", ", DoubleToString(vol, 2), ")");
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
            Print("❌ Échec fermeture symbole (", symbol, "): ", GetLastError(), " - ", rs.comment);
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
    Print("⏳ Cooldown armé sur ", symbol, " jusqu'à ", (long)until);
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
        for(int i=0;i<ArraySize(g_lossSymbols);i++)
        {
            if(g_lossSymbols[i] == "") { g_lossSymbols[i] = symbol; g_lossCounts[i] = 1; break; }
        }
    }
    else
    {
        g_lossCounts[idx]++;
    }
    g_consecutiveLossesGlobal++;
}

void ResetConsecutiveLoss(const string symbol)
{
    int idx = FindLossIndex(symbol);
    if(idx >= 0) g_lossCounts[idx] = 0;
    g_consecutiveLossesGlobal = 0;
}

// Check if the current symbol is a Boom or Crash index.
bool IsBoomCrashIndex(string symbol)
{
    return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
}

// Trader spikes uniquement: BUY sur Boom*, SELL sur Crash*
int EnforceBoomCrashDirection(int desiredDirection)
{
    if(!IsBoomCrashIndex(_Symbol)) return desiredDirection; // No restriction on non-Boom/Crash symbols
    
    bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
    bool isCrash= (StringFind(_Symbol, "Crash")>= 0);

    if(desiredDirection == 0) return 0; // No signal to enforce

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

// Validate SL/TP against stops level and freeze levels
void EnsureValidStops(const string symbol, const int direction, const double price, const double point, double &sl_price, double &tp_price)
{
    int stops = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    int freeze= (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
    int minPts = MathMax(1, stops + MathMax(0, InpStopsBufferPoints));
    double minDist = minPts * point;
    if(direction>0)
    {
        if(sl_price>0 && price - sl_price < minDist) sl_price = price - minDist;
        if(tp_price>0 && tp_price - price < minDist) tp_price = price + minDist;
    }
    else
    {
        if(sl_price>0 && sl_price - price < minDist) sl_price = price + minDist;
        if(tp_price>0 && price - tp_price < minDist) tp_price = price - minDist;
    }
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
        DrawLabel(lbl, StringFormat("Pré-signal %s (≈1m)", side), 12, 82, c);
    }
}

// Simple dashboard panel
void UpdateDashboard()
{
    if(!InpShowDashboard) return;
    string name = "DASH_PANEL";
    string txt = "SpikeHunter Dashboard\n";
    txt += StringFormat("Symbol: %s\n", _Symbol);
    txt += StringFormat("Open positions: %d\n", PositionsTotal());
    txt += StringFormat("Cooldown: %s\n", IsSymbolInCooldown(_Symbol)? "ON" : "OFF");
    txt += StringFormat("TrendTF(%d): %d\n", (int)InpTrendTF, (int)CTradeExecutor::GetTrendDirection(InpTrendTF));
    if(ObjectFind(0, name) < 0)
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, InpDashCorner);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpDashX);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpDashY);
    ObjectSetString(0, name, OBJPROP_TEXT, txt);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
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
                    Print("❌ Range insuffisant: ", DoubleToString(current_range, 5), " vs ", DoubleToString(range_threshold, 5));
                    return false;
                }
                
                // 2. Range actuel > ATR * multiplicateur minimum (plus strict)
                if(current_range <= current_atr * InpMinSpikeStrength) {
                    Print("❌ Force spike insuffisante: ", DoubleToString(current_range, 5), " vs ", DoubleToString(current_atr * InpMinSpikeStrength, 5));
                    return false;
                }
                
                // 3. Corps significatif (plus strict - 60% minimum)
                if(current_body <= current_range * 0.6) {
                    Print("❌ Corps insuffisant: ", DoubleToString(current_body, 5), " vs ", DoubleToString(current_range * 0.6, 5));
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
                    Print("❌ Momentum insuffisant: ", DoubleToString(momentum, 5), " vs ", DoubleToString(avg_momentum * 1.5, 5));
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
                        Print("🚀 SIGNAL BOOM CONFIRMÉ - BUY près du support - Range: ", DoubleToString(current_range, 5), 
                              " vs Moyenne: ", DoubleToString(avg_range, 5), 
                              " vs ATR: ", DoubleToString(current_atr, 5),
                              " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
                              " Support: ", DoubleToString(zone_level, 5), " Force: ", DoubleToString(zone_strength*100, 1), "%");
                        return true;
                    } else {
                        Print("⚠️ SIGNAL BOOM DÉTECTÉ MAIS CONFIANCE INSTABLE - Trade bloqué");
                        return false;
                    }
                } else {
                    Print("⚠️ SIGNAL BOOM DÉTECTÉ MAIS CONTRE TENDANCE GÉNÉRALE - Trade bloqué");
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
                        Print("💥 SIGNAL CRASH CONFIRMÉ - SELL près de la résistance - Range: ", DoubleToString(current_range, 5), 
                              " vs Moyenne: ", DoubleToString(avg_range, 5), 
                              " vs ATR: ", DoubleToString(current_atr, 5),
                              " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
                              " Résistance: ", DoubleToString(zone_level, 5), " Force: ", DoubleToString(zone_strength*100, 1), "%");
                        return true;
                    } else {
                        Print("⚠️ SIGNAL CRASH DÉTECTÉ MAIS CONFIANCE INSTABLE - Trade bloqué");
                        return false;
                    }
                } else {
                    Print("⚠️ SIGNAL CRASH DÉTECTÉ MAIS CONTRE TENDANCE GÉNÉRALE - Trade bloqué");
                    return false;
                }
            }
        }
        
        Print("⚠️ SPIKE DÉTECTÉ MAIS CONDITIONS BOOM/CRASH NON REMPLIES - Attente d'une meilleure opportunité");
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
                    Print("🎯 SPIKE CONFIRMÉ DANS ZONE S/R - Range: ", DoubleToString(current_range, 5), 
                          " vs Moyenne: ", DoubleToString(avg_range, 5), 
                          " vs ATR: ", DoubleToString(current_atr, 5),
                          " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
                          " Direction: ", (bullish_spike ? "HAUSSIER" : "BAISSIER"),
                          " Zone: ", DoubleToString(zone_level, 5), " Force: ", DoubleToString(zone_strength*100, 1), "%");
                    return true;
                } else {
                    Print("⚠️ SPIKE DANS ZONE S/R MAIS CONFIANCE INSTABLE - Trade bloqué");
                    return false;
                }
            } else {
                Print("⚠️ SPIKE DANS ZONE S/R MAIS CONTRE TENDANCE GÉNÉRALE - Trade bloqué");
                return false;
            }
        } else {
            Print("⚠️ SPIKE DÉTECTÉ MAIS HORS ZONE S/R - Attente d'une meilleure opportunité");
            return false;
        }
    }
    
    Print("🎯 SPIKE CONFIRMÉ POUR ENTRÉE - Range: ", DoubleToString(current_range, 5), 
          " vs Moyenne: ", DoubleToString(avg_range, 5), 
          " vs ATR: ", DoubleToString(current_atr, 5),
          " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)",
          " Direction: ", (bullish_spike ? "HAUSSIER" : "BAISSIER"));
    
    return true;
}

//+------------------------------------------------------------------+
//| Détection de spike pour fermeture immédiate                     |
//+------------------------------------------------------------------+
bool DetectSpikeForClose()
{
    if(!InpCloseImmediatelyAfterSpike) return false;
    
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 10, rates) < 10) return false;
    
    // Analyser la barre actuelle
    MqlRates current_bar = rates[0];
    double current_range = current_bar.high - current_bar.low;
    double current_body = MathAbs(current_bar.close - current_bar.open);
    
    // Calculer la moyenne des ranges des 5 barres précédentes
    double avg_range = 0.0;
    for(int i = 1; i < 6; i++) {
        avg_range += (rates[i].high - rates[i].low);
    }
    avg_range /= 5.0;
    
    // DEBUG: Afficher les valeurs pour diagnostic
    static datetime last_debug_time = 0;
    if(TimeCurrent() - last_debug_time >= 10) { // Debug toutes les 10 secondes
        Print("🔍 DEBUG SPIKE - Range actuel: ", DoubleToString(current_range, 5), 
              " Moyenne: ", DoubleToString(avg_range, 5),
              " Ratio: ", DoubleToString(current_range/avg_range, 3),
              " Corps: ", DoubleToString(current_body, 5),
              " Corps%: ", DoubleToString(current_body/current_range*100, 1), "%");
        last_debug_time = TimeCurrent();
    }
    
    // Vérification spéciale pour les indices (Crash 300, Boom 300, etc.)
    string symbol_name = _Symbol;
    if(StringFind(symbol_name, "Crash") >= 0 || StringFind(symbol_name, "Boom") >= 0) {
        // Pour les indices, utiliser une détection plus agressive
        // Spike détecté si range actuel > 1.5x la moyenne ET corps > 20% du range
        if(current_range > avg_range * 1.5 && current_body > current_range * 0.2) {
            Print("🚨 SPIKE INDEX DÉTECTÉ - Range: ", DoubleToString(current_range, 5), 
                  " vs Moyenne: ", DoubleToString(avg_range, 5), 
                  " (+", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%)");
            return true;
        }
        
        // Alternative: fermeture si profit > 0$ ET mouvement significatif (peu importe le montant)
        for(int i = 0; i < PositionsTotal(); i++) {
            ulong ticket = PositionGetTicket(i);
            if(!PositionSelectByTicket(ticket)) continue;
            if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
                double profit = PositionGetDouble(POSITION_PROFIT);
                if(profit > 0.0 && current_range > avg_range * 1.2) {
                    Print("💰 SPIKE INDEX + GAIN POSITIF - Fermeture immédiate: $", DoubleToString(profit, 2), 
                          " Range: +", DoubleToString((current_range/avg_range-1.0)*100.0, 1), "%");
                    return true;
                }
            }
        }
    }
    
    // Fermeture immédiate si profit > 0$ (capture rapide dès le gain)
    // Pour les indices Boom/Crash, fermer dès le premier centime
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if((int)PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            double profit = PositionGetDouble(POSITION_PROFIT);
            string pos_symbol = PositionGetString(POSITION_SYMBOL);
            
            // Pour les indices, fermer dès le premier centime de profit
            if(StringFind(pos_symbol, "Crash") >= 0 || StringFind(pos_symbol, "Boom") >= 0) {
                if(profit > 0.01) {
                    Print("💰 SPIKE INDEX - Fermeture immédiate dès le gain: $", DoubleToString(profit, 2));
                    return true;
                }
            } else {
                // Pour les autres symboles, garder le seuil normal
                if(profit > 0.0) {
                    Print("💰 PROFIT DÉTECTÉ - Fermeture immédiate: $", DoubleToString(profit, 2));
                    return true;
                }
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calcul des SL/TP optimaux basés sur ATR et volatilité           |
//+------------------------------------------------------------------+
void CalculateOptimalSLTP(double &sl_price, double &tp_price, int direction, double entry_price)
{
    if(!InpUseOptimalSLTP) return;
    
    // Obtenir ATR actuel
    int atr_handle = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
    if(atr_handle == INVALID_HANDLE) return;
    
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    if(CopyBuffer(atr_handle, 0, 0, 3, atr_buffer) < 3) {
        IndicatorRelease(atr_handle);
        return;
    }
    
    double current_atr = atr_buffer[0];
    IndicatorRelease(atr_handle);
    
    // Calculer la taille de lot pour respecter la perte maximale de 2$
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double lot_size = InpLotSize; // Utiliser le lot par défaut pour le calcul
    
    // Calculer la distance SL basée sur la perte maximale de 2$
    double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    
    double max_loss_usd = InpMaxLossPerTradeUSD;
    double sl_distance = 0;
    
    if(tick_size > 0 && tick_value > 0 && lot_size > 0) {
        // Calculer la distance SL pour respecter la perte maximale
        double ticks_for_max_loss = max_loss_usd / (lot_size * tick_value);
        sl_distance = ticks_for_max_loss * tick_size;
        
        // Limiter la distance SL à 2x l'ATR maximum
        double max_atr_distance = current_atr * 2.0;
        if(sl_distance > max_atr_distance) {
            sl_distance = max_atr_distance;
            Print("⚠️ SL limité par ATR - Distance: ", DoubleToString(sl_distance, 5));
        }
    } else {
        // Fallback: utiliser ATR
        sl_distance = current_atr * InpSL_ATR_Multiplier;
    }
    
    // TP plus conservateur (1.5:1 ratio)
    double tp_distance = sl_distance * 1.5;
    
    // Calculer les prix SL/TP
    if(direction == POSITION_TYPE_BUY) {
        sl_price = entry_price - sl_distance;
        tp_price = entry_price + tp_distance;
    } else {
        sl_price = entry_price + sl_distance;
        tp_price = entry_price - tp_distance;
    }
    
    // Normaliser selon les ticks du symbole
    if(tick_size > 0) {
        sl_price = MathRound(sl_price / tick_size) * tick_size;
        tp_price = MathRound(tp_price / tick_size) * tick_size;
    }
    
    Print("📊 SL/TP ULTRA-CONSERVATEUR - Perte max: $", DoubleToString(max_loss_usd, 2),
              " SL Distance: ", DoubleToString(sl_distance, 5),
              " TP Distance: ", DoubleToString(tp_distance, 5),
              " SL: ", DoubleToString(sl_price, 5), " TP: ", DoubleToString(tp_price, 5));
}

//+------------------------------------------------------------------+
//| Détection des zones Support/Résistance multi-timeframe         |
//+------------------------------------------------------------------+
void UpdateSRZones()
{
    if(!InpEnableSRDetection) {
        Print("⚠️ Détection S/R désactivée");
        return;
    }
    
    Print("🔄 MISE À JOUR ZONES S/R - Début analyse");
    Print("📊 Paramètres S/R - Tolérance: ", InpSRZoneTolerance, " Min touches: ", InpSRMinTouches, " Confiance min: ", InpSRMinConfidence, "%");
    
    // Réinitialiser le compteur pour forcer la détection
    g_sr_zone_count = 0;
    
    // Timeframes à analyser (H4, H1, M30, M15, M5)
    ENUM_TIMEFRAMES timeframes[] = {PERIOD_H4, PERIOD_H1, PERIOD_M30, PERIOD_M15, PERIOD_M5};
    
    for(int tf = 0; tf < 5; tf++) {
        Print("📊 Analyse timeframe: ", EnumToString(timeframes[tf]));
        DetectSRZonesForTimeframe(timeframes[tf]);
    }
    
    Print("📈 Total zones détectées: ", g_sr_zone_count);
    
    // Dessiner les zones sur le graphique
    if(InpDrawSRZones) {
        Print("🎨 Dessin des zones S/R...");
        DrawSRZones();
    } else {
        Print("⚠️ Dessin S/R désactivé");
    }
    
    g_last_sr_update = TimeCurrent();
    Print("✅ MISE À JOUR ZONES S/R TERMINÉE");
}

//+------------------------------------------------------------------+
//| Détection S/R pour un timeframe spécifique                      |
//+------------------------------------------------------------------+
void DetectSRZonesForTimeframe(ENUM_TIMEFRAMES timeframe)
{
    MqlRates rates[];
    if(CopyRates(_Symbol, timeframe, 0, InpSRLookbackBars, rates) < InpSRLookbackBars) {
        Print("❌ Échec copie des données pour timeframe: ", EnumToString(timeframe));
        return;
    }
    
    Print("🔍 ANALYSE S/R - Timeframe: ", EnumToString(timeframe), " Barres: ", ArraySize(rates));
    
    int pivots_found = 0;
    
    // Trouver les pivots (hauts et bas) avec critères plus souples
    for(int i = 3; i < InpSRLookbackBars - 3; i++) {
        // Pivot haut (résistance potentielle) - critères plus souples
        bool is_pivot_high = true;
        for(int j = 1; j <= 2; j++) {
            if(rates[i].high <= rates[i-j].high || rates[i].high <= rates[i+j].high) {
                is_pivot_high = false;
                break;
            }
        }
        
        if(is_pivot_high) {
            AddSRZone(rates[i].high, false, rates[i].time, timeframe);
            pivots_found++;
            Print("📈 PIVOT HAUT DÉTECTÉ - Prix: ", DoubleToString(rates[i].high, 5), 
                  " Time: ", TimeToString(rates[i].time), " TF: ", EnumToString(timeframe));
        }
        
        // Pivot bas (support potentiel) - critères plus souples
        bool is_pivot_low = true;
        for(int j = 1; j <= 2; j++) {
            if(rates[i].low >= rates[i-j].low || rates[i].low >= rates[i+j].low) {
                is_pivot_low = false;
                break;
            }
        }
        
        if(is_pivot_low) {
            AddSRZone(rates[i].low, true, rates[i].time, timeframe);
            pivots_found++;
            Print("📉 PIVOT BAS DÉTECTÉ - Prix: ", DoubleToString(rates[i].low, 5), 
                  " Time: ", TimeToString(rates[i].time), " TF: ", EnumToString(timeframe));
        }
    }
    
    Print("✅ PIVOTS DÉTECTÉS - Timeframe: ", EnumToString(timeframe), " Nombre: ", pivots_found);
}

//+------------------------------------------------------------------+
//| Ajouter une zone S/R                                           |
//+------------------------------------------------------------------+
void AddSRZone(double level, bool is_support, datetime touch_time, ENUM_TIMEFRAMES timeframe)
{
    // Vérifier si une zone similaire existe déjà
    for(int i = 0; i < g_sr_zone_count; i++) {
        if(MathAbs(g_sr_zones[i].level - level) <= InpSRZoneTolerance &&
           g_sr_zones[i].is_support == is_support &&
           g_sr_zones[i].timeframe == timeframe) {
            
                        // Mettre à jour la zone existante
                        g_sr_zones[i].touch_count++;
                        g_sr_zones[i].last_touch = touch_time;
                        // Force atteint 100% après 3 touches (au lieu de 5)
                        g_sr_zones[i].strength = MathMin(1.0, g_sr_zones[i].touch_count / 3.0);
                        return;
        }
    }
    
    // Ajouter une nouvelle zone si on a de la place
    if(g_sr_zone_count < 50) {
        g_sr_zones[g_sr_zone_count].level = level;
        g_sr_zones[g_sr_zone_count].is_support = is_support;
        g_sr_zones[g_sr_zone_count].touch_count = 1;
        g_sr_zones[g_sr_zone_count].first_touch = touch_time;
        g_sr_zones[g_sr_zone_count].last_touch = touch_time;
        g_sr_zones[g_sr_zone_count].timeframe = timeframe;
                    g_sr_zones[g_sr_zone_count].is_active = true;
                    g_sr_zones[g_sr_zone_count].strength = 0.33; // 33% après 1 touche, 66% après 2, 100% après 3
        g_sr_zones[g_sr_zone_count].created_time = TimeCurrent();
        g_sr_zones[g_sr_zone_count].success_rate = 0.0;
        g_sr_zones[g_sr_zone_count].total_trades = 0;
        g_sr_zones[g_sr_zone_count].winning_trades = 0;
        g_sr_zones[g_sr_zone_count].avg_profit = 0.0;
        g_sr_zones[g_sr_zone_count].avg_loss = 0.0;
        g_sr_zones[g_sr_zone_count].profit_factor = 0.0;
        
        g_sr_zone_count++;
        
        Print("📍 NOUVELLE ZONE S/R - ", (is_support ? "SUPPORT" : "RÉSISTANCE"), 
              " Niveau: ", DoubleToString(level, 5), 
              " TF: ", EnumToString(timeframe));
    }
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est proche d'une zone S/R                  |
//+------------------------------------------------------------------+
bool IsNearSRZone(double price, bool is_support, double &zone_level, double &zone_strength)
{
    if(!InpPrioritizeSREntries) return false;
    
    for(int i = 0; i < g_sr_zone_count; i++) {
        if(!g_sr_zones[i].is_active) continue;
        if(g_sr_zones[i].is_support != is_support) continue;
        if(g_sr_zones[i].touch_count < InpSRMinTouches) continue;
        
        double distance = MathAbs(g_sr_zones[i].level - price);
        if(distance <= InpSRZoneTolerance) {
            zone_level = g_sr_zones[i].level;
            zone_strength = g_sr_zones[i].strength;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est proche d'une zone de support           |
//+------------------------------------------------------------------+
bool IsNearSupportZone(double price, double &zone_level, double &zone_strength)
{
    if(!InpEnableBoomCrashSignals) return false;
    
    for(int i = 0; i < g_sr_zone_count; i++) {
        if(!g_sr_zones[i].is_active) continue;
        if(!g_sr_zones[i].is_support) continue; // Seulement les supports
        if(g_sr_zones[i].touch_count < InpSRMinTouches) continue;
        
        double distance = MathAbs(g_sr_zones[i].level - price);
        if(distance <= InpSRProximityTolerance) {
            zone_level = g_sr_zones[i].level;
            zone_strength = g_sr_zones[i].strength;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est proche d'une zone de résistance        |
//+------------------------------------------------------------------+
bool IsNearResistanceZone(double price, double &zone_level, double &zone_strength)
{
    if(!InpEnableBoomCrashSignals) return false;
    
    for(int i = 0; i < g_sr_zone_count; i++) {
        if(!g_sr_zones[i].is_active) continue;
        if(g_sr_zones[i].is_support) continue; // Seulement les résistances
        if(g_sr_zones[i].touch_count < InpSRMinTouches) continue;
        
        double distance = MathAbs(g_sr_zones[i].level - price);
        if(distance <= InpSRProximityTolerance) {
            zone_level = g_sr_zones[i].level;
            zone_strength = g_sr_zones[i].strength;
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Prédiction de spike imminent                                   |
//+------------------------------------------------------------------+
bool PredictImminentSpike(double &confidence, int &direction)
{
    if(!InpEnableSpikePrediction) return false;
    
    confidence = 0.0;
    direction = 0;
    
    // 1. Compression volumétrique
    double volume_score = DetectVolumeCompression();
    if(volume_score) confidence += 20.0;
    
    // 2. Convergence des moyennes
    double ma_score = DetectMAConvergence();
    if(ma_score) confidence += 25.0;
    
    // 3. Compression de volatilité
    double atr_score = DetectATRCompression();
    if(atr_score) confidence += 20.0;
    
    // 4. Déséquilibre de pression
    double pressure_score = DetectPressureImbalance();
    if(pressure_score) confidence += 15.0;
    
    // 5. Momentum caché
    double momentum_score = DetectHiddenMomentum();
    if(momentum_score) confidence += 20.0;
    
    // Déterminer la direction probable
    if(DetectBullishPressure()) direction = 1;  // BUY
    else if(DetectBearishPressure()) direction = -1;  // SELL
    
    bool prediction = (confidence >= InpPredictionConfidenceMin);
    
    if(prediction) {
        Print("🔮 SPIKE IMMINENT PRÉDIT - Confiance: ", DoubleToString(confidence, 1), "%",
              " Direction: ", (direction > 0 ? "BUY" : "SELL"));
    }
    
    return prediction;
}

//+------------------------------------------------------------------+
//| Détection de compression volumétrique                          |
//+------------------------------------------------------------------+
bool DetectVolumeCompression()
{
    double current_volume = (double)iVolume(_Symbol, PERIOD_M1, 0);
    double avg_volume = 0;
    
    for(int i = 1; i <= 20; i++) {
        avg_volume += (double)iVolume(_Symbol, PERIOD_M1, i);
    }
    avg_volume /= 20.0;
    
    bool compressed = (current_volume < avg_volume * InpVolumeCompressionThreshold);
    
    if(compressed) {
        Print("📊 COMPRESSION VOLUME - Actuel: ", DoubleToString(current_volume, 0),
              " vs Moyenne: ", DoubleToString(avg_volume, 0));
    }
    
    return compressed;
}

//+------------------------------------------------------------------+
//| Détection de convergence des moyennes                          |
//+------------------------------------------------------------------+
bool DetectMAConvergence()
{
    int ema_fast = iMA(_Symbol, PERIOD_M1, 5, 0, MODE_EMA, PRICE_CLOSE);
    int ema_slow = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
    
    if(ema_fast == INVALID_HANDLE || ema_slow == INVALID_HANDLE) return false;
    
    double fast_buffer[], slow_buffer[];
    ArraySetAsSeries(fast_buffer, true);
    ArraySetAsSeries(slow_buffer, true);
    
    if(CopyBuffer(ema_fast, 0, 0, 3, fast_buffer) < 3 ||
       CopyBuffer(ema_slow, 0, 0, 3, slow_buffer) < 3) {
        IndicatorRelease(ema_fast);
        IndicatorRelease(ema_slow);
        return false;
    }
    
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double gap = MathAbs(fast_buffer[0] - slow_buffer[0]) / price;
    
    IndicatorRelease(ema_fast);
    IndicatorRelease(ema_slow);
    
    bool converged = (gap < InpMAConvergenceThreshold);
    
    if(converged) {
        Print("📈 CONVERGENCE MA - Gap: ", DoubleToString(gap * 100, 3), "%");
    }
    
    return converged;
}

//+------------------------------------------------------------------+
//| Détection de compression ATR                                  |
//+------------------------------------------------------------------+
bool DetectATRCompression()
{
    int atr_handle = iATR(_Symbol, PERIOD_M1, 14);
    if(atr_handle == INVALID_HANDLE) return false;
    
    double atr_buffer[];
    ArraySetAsSeries(atr_buffer, true);
    if(CopyBuffer(atr_handle, 0, 0, 10, atr_buffer) < 10) {
        IndicatorRelease(atr_handle);
        return false;
    }
    
    double current_atr = atr_buffer[0];
    double avg_atr = 0;
    for(int i = 1; i < 10; i++) {
        avg_atr += atr_buffer[i];
    }
    avg_atr /= 9.0;
    
    IndicatorRelease(atr_handle);
    
    bool compressed = (current_atr < avg_atr * InpATRCompressionThreshold);
    
    if(compressed) {
        Print("⚡ COMPRESSION ATR - Actuel: ", DoubleToString(current_atr, 5),
              " vs Moyenne: ", DoubleToString(avg_atr, 5));
    }
    
    return compressed;
}

//+------------------------------------------------------------------+
//| Détection de déséquilibre de pression                          |
//+------------------------------------------------------------------+
bool DetectPressureImbalance()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 10, rates) < 10) return false;
    
    double buy_pressure = 0, sell_pressure = 0;
    
    for(int i = 0; i < 10; i++) {
        double body = MathAbs(rates[i].close - rates[i].open);
        double upper_wick = rates[i].high - MathMax(rates[i].open, rates[i].close);
        double lower_wick = MathMin(rates[i].open, rates[i].close) - rates[i].low;
        
        if(rates[i].close > rates[i].open) {
            buy_pressure += body + lower_wick;
        } else {
            sell_pressure += body + upper_wick;
        }
    }
    
    double ratio = 0;
    if(sell_pressure > 0) ratio = buy_pressure / sell_pressure;
    else if(buy_pressure > 0) ratio = sell_pressure / buy_pressure;
    
    bool imbalanced = (ratio > InpPressureImbalanceThreshold);
    
    if(imbalanced) {
        Print("💪 DÉSÉQUILIBRE PRESSION - Ratio: ", DoubleToString(ratio, 2));
    }
    
    return imbalanced;
}

//+------------------------------------------------------------------+
//| Détection de momentum caché                                    |
//+------------------------------------------------------------------+
bool DetectHiddenMomentum()
{
    int rsi_handle = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
    int macd_handle = iMACD(_Symbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE);
    
    if(rsi_handle == INVALID_HANDLE || macd_handle == INVALID_HANDLE) return false;
    
    double rsi_buffer[], macd_main[], macd_signal[];
    ArraySetAsSeries(rsi_buffer, true);
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    
    if(CopyBuffer(rsi_handle, 0, 0, 3, rsi_buffer) < 3 ||
       CopyBuffer(macd_handle, 0, 0, 3, macd_main) < 3 ||
       CopyBuffer(macd_handle, 1, 0, 3, macd_signal) < 3) {
        IndicatorRelease(rsi_handle);
        IndicatorRelease(macd_handle);
        return false;
    }
    
    bool rsi_neutral = (rsi_buffer[0] > 40 && rsi_buffer[0] < 60);
    bool macd_preparing = (macd_main[0] > macd_signal[0] && macd_main[1] <= macd_signal[1]);
    
    IndicatorRelease(rsi_handle);
    IndicatorRelease(macd_handle);
    
    bool hidden_momentum = (rsi_neutral && macd_preparing);
    
    if(hidden_momentum) {
        Print("🎯 MOMENTUM CACHÉ - RSI: ", DoubleToString(rsi_buffer[0], 1));
    }
    
    return hidden_momentum;
}

//+------------------------------------------------------------------+
//| Détection de pression haussière                               |
//+------------------------------------------------------------------+
bool DetectBullishPressure()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5) return false;
    
    int bullish_count = 0;
    for(int i = 0; i < 5; i++) {
        if(rates[i].close > rates[i].open) bullish_count++;
    }
    
    return (bullish_count >= 3); // 3/5 bougies haussières
}

//+------------------------------------------------------------------+
//| Détection de pression baissière                                |
//+------------------------------------------------------------------+
bool DetectBearishPressure()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5) return false;
    
    int bearish_count = 0;
    for(int i = 0; i < 5; i++) {
        if(rates[i].close < rates[i].open) bearish_count++;
    }
    
    return (bearish_count >= 3); // 3/5 bougies baissières
}

//+------------------------------------------------------------------+
//| Préparer l'entrée anticipée                                     |
//+------------------------------------------------------------------+
void PrepareAnticipatedEntry(int direction, double confidence)
{
    if(!g_riskManager.CanOpenTrade()) {
        Print("🚫 Entrée anticipée bloquée par gestion des risques");
        return;
    }
    
    // Calculer la taille de lot basée sur la confiance
    double base_lot = InpLotSize;
    double confidence_multiplier = confidence / 100.0;
    double lot_size = base_lot * confidence_multiplier;
    
    // Normaliser la taille de lot
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(lot_size, min_lot);
    lot_size = MathMin(lot_size, max_lot);
    lot_size = MathRound(lot_size / lot_step) * lot_step;
    
    Print("🎯 ENTRÉE ANTICIPÉE PRÉPARÉE - Direction: ", (direction > 0 ? "BUY" : "SELL"),
          " Lot: ", DoubleToString(lot_size, 2),
          " Confiance: ", DoubleToString(confidence, 1), "%");
    
    // Stocker les paramètres pour exécution immédiate au prochain tick
    // (Cette fonction prépare mais n'exécute pas encore)
}

//+------------------------------------------------------------------+
//| Dessiner les zones S/R sur le graphique                        |
//+------------------------------------------------------------------+
void DrawSRZones()
{
    if(!InpDrawSRZones) return;
    
    Print("🎨 DESSIN DES ZONES S/R - Nombre de zones: ", g_sr_zone_count);
    
    // Supprimer les anciens objets S/R
    for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--) {
        string obj_name = ObjectName(0, i, 0, -1);
        if(StringFind(obj_name, "SR_") == 0) {
            ObjectDelete(0, obj_name);
        }
    }
    
    // DEBUG: Afficher toutes les zones détectées
    Print("🔍 DEBUG - Zones détectées:");
    for(int i = 0; i < g_sr_zone_count; i++) {
        if(g_sr_zones[i].is_active) {
            Print("  Zone ", i, ": ", (g_sr_zones[i].is_support ? "SUPPORT" : "RÉSISTANCE"),
                  " Niveau: ", DoubleToString(g_sr_zones[i].level, 5),
                  " Touches: ", g_sr_zones[i].touch_count,
                  " Force: ", DoubleToString(g_sr_zones[i].strength * 100, 1), "%");
        }
    }
    
    // Dessiner les zones avec le seuil configuré
    int drawn_count = 0;
    double confidence_threshold = InpSRMinConfidence / 100.0;
    Print("🎯 Seuil de confiance requis: ", DoubleToString(confidence_threshold * 100, 1), "%");
    
    for(int i = 0; i < g_sr_zone_count; i++) {
        if(!g_sr_zones[i].is_active) {
            Print("  Zone ", i, " inactive - ignorée");
            continue;
        }
        if(g_sr_zones[i].touch_count < InpSRMinTouches) {
            Print("  Zone ", i, " touches insuffisantes (", g_sr_zones[i].touch_count, " < ", InpSRMinTouches, ") - ignorée");
            continue;
        }
        
        // TEMPORAIRE: Seuil très bas pour debug
        if(g_sr_zones[i].strength < 0.1) { // 10% minimum pour debug
            Print("  Zone ", i, " confiance insuffisante (", DoubleToString(g_sr_zones[i].strength * 100, 1), "% < 10%) - ignorée");
            continue;
        }
        
        string obj_name = StringFormat("SR_%d_%s", i, (g_sr_zones[i].is_support ? "SUPPORT" : "RESISTANCE"));
        color zone_color = g_sr_zones[i].is_support ? InpSRSupportColor : InpSRResistanceColor;
        
        // Créer une ligne horizontale
        if(ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, g_sr_zones[i].level)) {
            ObjectSetInteger(0, obj_name, OBJPROP_COLOR, zone_color);
            ObjectSetInteger(0, obj_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, true);
            ObjectSetInteger(0, obj_name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, false);
            
            drawn_count++;
            Print("✅ ZONE S/R DESSINÉE - ", (g_sr_zones[i].is_support ? "SUPPORT" : "RÉSISTANCE"), 
                  " Niveau: ", DoubleToString(g_sr_zones[i].level, 5), 
                  " Touches: ", g_sr_zones[i].touch_count,
                  " Force: ", DoubleToString(g_sr_zones[i].strength * 100, 1), "%");
        } else {
            Print("❌ Échec création objet S/R: ", GetLastError());
        }
    }
    
    Print("✅ ZONES S/R DESSINÉES: ", drawn_count, " zones (seuil: ", DoubleToString(InpSRMinConfidence, 0), "%)");
}





//+------------------------------------------------------------------+
//| Mise à jour dynamique des patterns en temps réel               |
//+------------------------------------------------------------------+
void UpdateDynamicPatterns()
{
    // Obtenir le prix actuel
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    datetime current_time = TimeCurrent();
    
    // Analyser le pattern actuel
    int pattern_direction = AnalyzeCurrentPattern();
    double pattern_confidence = CalculatePatternConfidence();
    
    // Afficher seulement les flèches dynamiques avec confiance élevée
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
    
    // DÉTERMINER LA TENDANCE GÉNÉRALE (H1, H4)
    int general_trend = DetermineGeneralTrend();
    
    // Pattern 1: Tendance haussière récente
    if(rates[0].close > rates[2].close && rates[0].close > rates[4].close) {
        // Vérifier que c'est cohérent avec la tendance générale
        if(general_trend >= 0) { // Tendance haussière ou neutre
            return 1; // Haussier
        } else {
            Print("⚠️ Pattern haussier détecté mais contre tendance générale - Ignoré");
            return 0;
        }
    }
    
    // Pattern 2: Tendance baissière récente
    if(rates[0].close < rates[2].close && rates[0].close < rates[4].close) {
        // Vérifier que c'est cohérent avec la tendance générale
        if(general_trend <= 0) { // Tendance baissière ou neutre
            return -1; // Baissier
        } else {
            Print("⚠️ Pattern baissier détecté mais contre tendance générale - Ignoré");
            return 0;
        }
    }
    
    // Pattern 3: Doji actuel
    double body_size = MathAbs(rates[0].close - rates[0].open);
    double total_range = rates[0].high - rates[0].low;
    if(total_range > 0 && body_size / total_range < 0.1) {
        // Direction basée sur la tendance générale, pas locale
        if(general_trend > 0) return 1; // Tendance haussière générale
        if(general_trend < 0) return -1; // Tendance baissière générale
        return 0; // Tendance neutre
    }
    
    // Pattern 4: Hammer actuel
    double body = MathAbs(rates[0].close - rates[0].open);
    double lower_shadow = MathMin(rates[0].close, rates[0].open) - rates[0].low;
    double upper_shadow = rates[0].high - MathMax(rates[0].close, rates[0].open);
    
    if(total_range > 0 && lower_shadow > body * 2 && upper_shadow < body) {
        // Hammer seulement si tendance générale haussière ou neutre
        if(general_trend >= 0) {
            return 1; // Hammer haussier
        } else {
            Print("⚠️ Hammer détecté mais contre tendance générale - Ignoré");
            return 0;
        }
    }
    
    // Pattern 5: Shooting Star actuel
    if(total_range > 0 && upper_shadow > body * 2 && lower_shadow < body) {
        // Shooting Star seulement si tendance générale baissière ou neutre
        if(general_trend <= 0) {
            return -1; // Shooting Star baissier
        } else {
            Print("⚠️ Shooting Star détecté mais contre tendance générale - Ignoré");
            return 0;
        }
    }
    
    return 0; // Aucun pattern clair ou cohérent
}

//+------------------------------------------------------------------+
//| Déterminer la tendance générale (H1, H4)                        |
//+------------------------------------------------------------------+
int DetermineGeneralTrend()
{
    // Analyser H4 (tendance principale)
    MqlRates h4_rates[];
    if(CopyRates(_Symbol, PERIOD_H4, 0, 10, h4_rates) < 10) return 0;
    
    // Analyser H1 (tendance secondaire)
    MqlRates h1_rates[];
    if(CopyRates(_Symbol, PERIOD_H1, 0, 10, h1_rates) < 10) return 0;
    
    // Calculer tendance H4 (EMA 20 vs EMA 50)
    double h4_ema20 = CalculateEMAForTrend(h4_rates, 0, 20);
    double h4_ema50 = CalculateEMAForTrend(h4_rates, 0, 50);
    
    // Calculer tendance H1 (EMA 20 vs EMA 50)
    double h1_ema20 = CalculateEMAForTrend(h1_rates, 0, 20);
    double h1_ema50 = CalculateEMAForTrend(h1_rates, 0, 50);
    
    // Score de tendance (H4 a plus de poids)
    int h4_trend = 0;
    int h1_trend = 0;
    
    if(h4_ema20 > h4_ema50) h4_trend = 1;      // H4 haussier
    else if(h4_ema20 < h4_ema50) h4_trend = -1; // H4 baissier
    
    if(h1_ema20 > h1_ema50) h1_trend = 1;      // H1 haussier
    else if(h1_ema20 < h1_ema50) h1_trend = -1; // H1 baissier
    
    // Calculer le score final (H4 a 70% de poids, H1 a 30%)
    double trend_score = (h4_trend * 0.7) + (h1_trend * 0.3);
    
    // Vérifier la cohérence des prix
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    bool price_above_h4_ema = current_price > h4_ema20;
    bool price_above_h1_ema = current_price > h1_ema20;
    
    // Ajuster le score selon la position du prix
    if(price_above_h4_ema && h4_trend > 0) trend_score += 0.2;
    if(price_above_h1_ema && h1_trend > 0) trend_score += 0.1;
    if(!price_above_h4_ema && h4_trend < 0) trend_score -= 0.2;
    if(!price_above_h1_ema && h1_trend < 0) trend_score -= 0.1;
    
    // Déterminer la tendance finale
    int final_trend = 0;
    if(trend_score > 0.3) final_trend = 1;      // Tendance haussière
    else if(trend_score < -0.3) final_trend = -1; // Tendance baissière
    // Sinon final_trend = 0 (neutre)
    
    Print("📊 TENDANCE GÉNÉRALE - H4: ", (h4_trend > 0 ? "HAUSSIER" : (h4_trend < 0 ? "BAISSIER" : "NEUTRE")),
          " H1: ", (h1_trend > 0 ? "HAUSSIER" : (h1_trend < 0 ? "BAISSIER" : "NEUTRE")),
          " Score: ", DoubleToString(trend_score, 2),
          " Final: ", (final_trend > 0 ? "HAUSSIER" : (final_trend < 0 ? "BAISSIER" : "NEUTRE")));
    
    return final_trend;
}

//+------------------------------------------------------------------+
//| Calculer EMA pour un tableau de rates (version 2)              |
//+------------------------------------------------------------------+
double CalculateEMAForTrend(MqlRates &rates[], int index, int period)
{
    if(index < period - 1) return 0;
    
    double sum = 0;
    for(int i = 0; i < period; i++) {
        sum += rates[index - i].close;
    }
    
    return sum / period;
}

//+------------------------------------------------------------------+
//| Calculer la confiance du pattern actuel                         |
//+------------------------------------------------------------------+
double CalculatePatternConfidence()
{
    MqlRates rates[];
    if(CopyRates(_Symbol, PERIOD_M5, 0, 10, rates) < 10) return 0.0;
    
    double confidence = 0.0;
    
    // Confiance basée sur la force du mouvement (plus généreux)
    double price_change = MathAbs(rates[0].close - rates[4].close);
    double avg_range = 0;
    for(int i = 0; i < 5; i++) {
        avg_range += (rates[i].high - rates[i].low);
    }
    avg_range /= 5.0;
    
    if(avg_range > 0) {
        confidence += MathMin(0.5, price_change / avg_range * 2.0); // Plus généreux
    }
    
    // Confiance basée sur la cohérence de la tendance (plus généreux)
    int bullish_bars = 0;
    for(int i = 0; i < 5; i++) {
        if(rates[i].close > rates[i].open) bullish_bars++;
    }
    
    if(bullish_bars >= 4) confidence += 0.4; // Tendance haussière forte
    else if(bullish_bars <= 1) confidence += 0.4; // Tendance baissière forte
    else if(bullish_bars == 3) confidence += 0.2; // Tendance modérée
    
    // Confiance basée sur le volume (plus généreux)
    double volume_ratio = 1.0;
    if(rates[0].tick_volume > 0) {
        double avg_volume = 0;
        for(int i = 1; i < 5; i++) {
            avg_volume += (double)rates[i].tick_volume;
        }
        avg_volume /= 4.0;
        if(avg_volume > 0) {
            volume_ratio = rates[0].tick_volume / avg_volume;
        }
    }
    
    if(volume_ratio > 1.2) confidence += 0.3; // Volume élevé (seuil plus bas)
    else if(volume_ratio > 0.8) confidence += 0.1; // Volume normal
    
    // Bonus pour patterns spécifiques
    double body_size = MathAbs(rates[0].close - rates[0].open);
    double total_range = rates[0].high - rates[0].low;
    
    // Doji (indécision forte)
    if(total_range > 0 && body_size / total_range < 0.05) {
        confidence += 0.2;
    }
    
    // Hammer/Shooting Star
    if(total_range > 0) {
        double lower_shadow = MathMin(rates[0].close, rates[0].open) - rates[0].low;
        double upper_shadow = rates[0].high - MathMax(rates[0].close, rates[0].open);
        
        if(lower_shadow > body_size * 2 && upper_shadow < body_size) {
            confidence += 0.3; // Hammer
        }
        if(upper_shadow > body_size * 2 && lower_shadow < body_size) {
            confidence += 0.3; // Shooting Star
        }
    }
    
    return MathMin(1.0, confidence);
}

//+------------------------------------------------------------------+
//| Vérifier la stabilité de la confiance                          |
//+------------------------------------------------------------------+
bool IsConfidenceStable()
{
    // Vérifier toutes les 5 secondes seulement
    if(TimeCurrent() - g_last_confidence_check < 5) {
        return false; // Attendre
    }
    
    // Calculer la confiance actuelle
    double current_confidence = CalculatePatternConfidence();
    
    // Ajouter à l'historique
    g_confidence_history[g_confidence_index] = current_confidence;
    g_confidence_index = (g_confidence_index + 1) % 10;
    
    g_last_confidence_check = TimeCurrent();
    
    // Vérifier si on a assez d'historique
    int valid_entries = 0;
    for(int i = 0; i < 10; i++) {
        if(g_confidence_history[i] > 0) valid_entries++;
    }
    
    if(valid_entries < 5) {
        Print("📊 Pas assez d'historique de confiance (", valid_entries, "/5)");
        return false;
    }
    
    // Calculer la moyenne et la variance
    double sum = 0;
    for(int i = 0; i < 10; i++) {
        if(g_confidence_history[i] > 0) {
            sum += g_confidence_history[i];
        }
    }
    double average = sum / valid_entries;
    
    // Calculer la variance
    double variance = 0;
    for(int i = 0; i < 10; i++) {
        if(g_confidence_history[i] > 0) {
            double diff = g_confidence_history[i] - average;
            variance += diff * diff;
        }
    }
    variance /= valid_entries;
    double std_deviation = MathSqrt(variance);
    
    // Critères de stabilité (utiliser les paramètres d'entrée)
    double min_confidence = InpStableConfidenceMin / 100.0;
    double max_deviation = InpConfidenceStabilityMax / 100.0;
    bool is_stable = (average >= min_confidence) && (std_deviation <= max_deviation);
    
    Print("📊 STABILITÉ CONFIANCE - Moyenne: ", DoubleToString(average * 100, 1), 
          "% Écart-type: ", DoubleToString(std_deviation * 100, 1), 
          "% Stable: ", (is_stable ? "OUI" : "NON"));
    
    return is_stable;
}

//+------------------------------------------------------------------+
//| Créer une flèche dynamique                                      |
//+------------------------------------------------------------------+
void CreateDynamicArrow(datetime time, double price, int direction, double confidence)
{
    string arrow_name = "DYNAMIC_PATTERN_ARROW";
    color arrow_color = direction > 0 ? clrBlue : clrRed; // Bleu haussier, Rouge baissier
    int arrow_code = direction > 0 ? 233 : 234; // Flèches haut/bas
    
    // Supprimer l'ancienne flèche
    ObjectDelete(0, arrow_name);
    
    // Créer la nouvelle flèche
    if(ObjectCreate(0, arrow_name, OBJ_ARROW, 0, time, price)) {
        ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, arrow_color);
        ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 5); // Plus épaisse
        ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, arrow_code);
        ObjectSetInteger(0, arrow_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, arrow_name, OBJPROP_SELECTABLE, true);
        
        Print("🎯 FLÈCHE DYNAMIQUE - Direction: ", (direction > 0 ? "HAUSSIER" : "BAISSIER"),
              " Confiance: ", DoubleToString(confidence * 100, 1), "%",
              " Prix: ", DoubleToString(price, 5));
    }
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
        Print("📈 TREND ANALYSIS - ", StringSubstr(body, 0, 100));
        
        // Parser la réponse JSON pour extraire les données de tendance
        ParseTrendResponse(body);
    } else {
        Print("❌ Échec analyse de tendance: HTTP ", code);
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
        Print("📡 SIGNALS EXTERNES - ", StringSubstr(body, 0, 100));
        
        // Parser la réponse JSON pour extraire les signaux
        ParseSignalsResponse(body);
    } else {
        Print("❌ Échec signaux externes: HTTP ", code);
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
    
    // Remplacer /recommendations par /trend
    string trendUrl = InpTrendAnalysisURL + "?symbol=" + _Symbol + "&timeframe=M1";
    int code = (int)WebRequest("GET", trendUrl, headers, 3000, emptyPayload, resp, respHeaders);
    
    if(code == 200) {
        string body = CharArrayToString(resp, 0, -1, CP_UTF8);
        Print("📈 TREND - ", StringSubstr(body, 0, 100));
        
        // Parser la tendance pour mise à jour
        ParseTrendResponse(body);
    } else {
        Print("❌ Échec trend: HTTP ", code);
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse de tendance                                   |
//+------------------------------------------------------------------+
void ParseTrendResponse(string json_response)
{
    // Rechercher les données de tendance dans le JSON
    if(StringFind(json_response, "\"trend\"") >= 0) {
        Print("✅ Données de tendance reçues et analysées");
        // Ici on peut extraire et stocker les données de tendance
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse des signaux                                   |
//+------------------------------------------------------------------+
void ParseSignalsResponse(string json_response)
{
    // Rechercher les signaux dans le JSON
    if(StringFind(json_response, "\"signals\"") >= 0) {
        Print("✅ Signaux externes reçus et analysés");
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
        Print("✅ Recommandations reçues et analysées");
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
        Print("🚫 Trade bloqué par gestion des risques");
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
        Print("❌ Taille de lot invalide: ", lot_size);
        return;
    }
    
    // Calculer SL/TP optimaux
    double sl_price = 0, tp_price = 0;
    double entry_price = is_bullish_spike ? ask : bid;
    CalculateOptimalSLTP(sl_price, tp_price, direction, entry_price);
    
    // Validation finale des prix
    if(sl_price <= 0 || tp_price <= 0) {
        Print("❌ SL/TP invalides - SL: ", sl_price, " TP: ", tp_price);
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
        Print("🎯 TRADE ULTRA-PRÉCIS EXÉCUTÉ - Direction: ", (is_bullish_spike ? "BUY" : "SELL"),
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
        Print("❌ Échec exécution trade ultra-précis: ", GetLastError(), " - ", result.comment);
    }
}