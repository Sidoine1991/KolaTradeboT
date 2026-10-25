//+------------------------------------------------------------------+
//| Fx_robot_pred_v3.1 - Spike catcher prédictif Boom/Crash          |
//| - BUY uniquement sur "Boom" symbols                              |
//| - SELL uniquement sur "Crash" symbols                            |
//| - 1 trade max (par magic+symbole)                                |

//| - Confirmations: MA trend, ADX, VPIN, OBI, CVD, optional FVG     |
//| - Protection contre le drawdown                                  |
//| Auteur: Adaptation pour l'utilisateur                            |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "3.00"
#property strict

#include <Trade\Trade.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Arrays\Array.mqh>
#include <Arrays\ArrayString.mqh>

//--- Paramètres des zones d'entrée
input int      InpZoneATRPeriod = 14;          // Période ATR pour les zones
input double   InpZoneMultiplier = 2.0;        // Multiplicateur ATR pour la largeur des zones
input color    InpZoneBuyColor = clrDodgerBlue; // Couleur zone d'achat
input color    InpZoneSellColor = clrCrimson;  // Couleur zone de vente
input int      InpZoneWidth = 2;               // Largeur des lignes de zone
input int      InpZoneStyle = 2;               // Style des lignes (0=solid, 1=dash, 2=dot, etc.)
input int      InpZoneOpacity = 10;            // Opacité des zones (0-100)

//--- Variables globales pour les zones
datetime lastZoneUpdate = 0;
int zoneCount = 0;
string zoneNames[3];
double zoneHigh[3];
double zoneLow[3];
ENUM_POSITION_TYPE zoneType[3];

CTrade trade;
CPositionInfo positionInfo;

// Nom de l'algorithme et concepteur
string g_algorithmName = "kola_moneytradbot";
string g_algorithmCreator = "YEBADOKPO Sidoine";

// Fonction pour générer l'en-tête de l'algorithme
string GetAlgorithmHeader()
{
   return "???????????????????????????????????????????????????????\n" +
          "?? " + g_algorithmName + "\n" +
          "????? Concepteur: " + g_algorithmCreator + "\n" +
          "???????????????????????????????????????????????????????";
}

// Séparateur entre les blocs de signaux
string GetSignalSeparator()
{
   return "???????????????????????????????????????????????????????";
}

// Structure pour stocker les informations de signal par symbole 
struct SymbolSignal 
{
    datetime lastSignalTime;
    double lastPrice;
    double lastSL;
    double lastTP;
    bool hasPosition;
};

// Tableau des symboles à surveiller (sera rempli automatiquement)
string g_symbolsToWatch[];

//+------------------------------------------------------------------+
//| Détecte automatiquement tous les symboles Boom/Crash disponibles   |
//+------------------------------------------------------------------+
void AutoDetectBoomCrashSymbols()
{
   ArrayResize(g_symbolsToWatch, 0);
   
   // Parcourir tous les symboles disponibles dans Market Watch
   int totalSymbols = SymbolsTotal(true); // true = seulement Market Watch
   
   Print("?? Recherche automatique des symboles Boom/Crash...");
   
   for(int i = 0; i < totalSymbols; i++)
   {
      string symbolName = SymbolName(i, true); // true = Market Watch
      
      // Vérifier si c'est un symbole Boom ou Crash
      if(StringFind(symbolName, "Boom", 0) >= 0 || StringFind(symbolName, "Crash", 0) >= 0)
      {
         // Ajouter le symbole à la liste
         int size = ArraySize(g_symbolsToWatch);
         ArrayResize(g_symbolsToWatch, size + 1);
         g_symbolsToWatch[size] = symbolName;
         
         PrintFormat("? Symbole détecté: %s", symbolName);
         
         // S'assurer que le symbole est sélectionné pour le trading
         SymbolSelect(symbolName, true);
      }
   }
   
   int detectedCount = ArraySize(g_symbolsToWatch);
   PrintFormat("?? %d symboles Boom/Crash détectés automatiquement", detectedCount);
   
   // Si aucun symbole Boom/Crash trouvé, ajouter les symboles forex par défaut
   if(detectedCount == 0)
   {
      Print("?? Aucun symbole Boom/Crash trouvé - Utilisation des symboles forex par défaut");
      string defaultSymbols[] = {"Boom 1000 Index", "Crash 1000 Index", "Boom 500 Index", "Crash 500 Index", "Boom 300 Index", "Crash 300 Index"};
      
      for(int i = 0; i < ArraySize(defaultSymbols); i++)
      {
         string symbol = defaultSymbols[i];
         if(SymbolSelect(symbol, true))
         {
            int size = ArraySize(g_symbolsToWatch);
            ArrayResize(g_symbolsToWatch, size + 1);
            g_symbolsToWatch[size] = symbol;
            PrintFormat("? Symbole par défaut ajouté: %s", symbol);
         }
      }
   }
}

// Dictionnaire pour stocker les signaux par symbole
SymbolSignal g_symbolSignals[];

// ------------------- INPUTS (configuration) -----------------------
input bool     InpEnableTrading         = true;
input ulong    InpMagicNumber           = 20251115;
input ENUM_TIMEFRAMES InpSpikeTimeframe = PERIOD_M5;
input int      InpATR_Period            = 14;
input double   InpATRMultiplier         = 1.8;
input int      InpVPIN_WindowBars       = 500;
input int      InpOBI_Lookback          = 300;
input int      InpCVD_WindowBars        = 500;
input int      InpADX_Period            = 14;
input double   InpADX_Threshold         = 18.0;
input double   InpVPIN_Threshold        = 0.60;
input double   InpOBI_Threshold         = 0.55;
input double   InpRiskPercent           = 1.0;
input double   InpLotFixed              = 0.0;
input int      InpMinBarsRequired       = 600;
input bool     InpEnableTrailing        = false;
input double   InpTrailingATRMult       = 1.0;
input double   InpDailyDrawdownPercent   = 5.0;    // Drawdown journalier max (%)
input double   InpMaxPositionRiskPercent = 2.0;    // Risque max par position (%)
input bool     InpEnableProtections      = true;   // Activer les protections

input group "=== TRADE SETTINGS ==="
input int      InpSlippage             = 3;       // Slippage en points
input bool     InpAllowReverseTrades    = true;    // Autoriser trades inverses (SELL Boom / BUY Crash)
input double   InpReverseTradeSLMult    = 1.2;     // Multiplicateur SL pour trades inverses (plus serré)
input double   InpReverseTradeTPMult    = 1.8;     // Multiplicateur TP pour trades inverses (plus serré)
input double   InpMinTrendStrength      = 70.0;    // Force minimale de tendance pour trades inverses (%)
input bool     InpUseLimitOrders        = true;    // Utiliser 3 ordres limite au lieu d'ordre au marché
input double   InpLimitOrderDistance    = 0.3;     // Distance des ordres limite (en ATR) - réduit pour M1
input double   InpLimitOrderLotSize     = 0.01;    // Taille de lot pour chaque ordre limite (0.01 pour petit capital)
input bool     InpExecuteImmediateM1    = true;    // Exécuter aussi un ordre immédiat sur M1 si signal fort
input bool     InpExecuteImmediateM5    = true;    // Exécuter aussi un ordre immédiat sur M5 si signal fort
input double   InpImmediateConfidence   = 35.0;    // Confiance minimale pour exécution immédiate sur M5 (%)
input double   InpAccountBalance        = 10.0;    // Capital du compte (pour calcul automatique des lots)
input double   InpRiskPerTrade          = 1.0;     // Risque par trade (% du capital)
input double   InpSLMultiplierM1        = 1.8;     // Multiplicateur SL pour M1/M5 (augmenté pour SL moins serré)
input double   InpTPMultiplierM1        = 2.0;     // Multiplicateur TP pour M1/M5 (plus optimisé)

input group "=== VISUALS ==="
input bool     InpEnableVisuals         = true;    // Activer les visuels
input bool     InpShowArrows            = true;    // Afficher les cercles d'entrée
input bool     InpShowInfo              = true;    // Afficher les panneaux d'info
input int      InpCircleSize            = 5;       // Taille des cercles d'entrée
input bool     InpShowSpikeZones        = true;    // Afficher les zones de spike prédictives
input int      InpZoneLookbackBars      = 200;     // Nombre de bougies à scanner pour les zones
input int      InpZoneForwardBars       = 10;      // Nombre de bougies futures à couvrir
input double   InpZoneATRMult           = 1.0;     // Hauteur de zone en multiples d'ATR
input int      InpZoneAlpha             = 60;      // Transparence (0-255)
input int      InpZoneExpirySeconds     = 60;      // Expiration auto des zones (secondes)
input double   InpSmallCandleATRMult    = 0.30;    // Définition d'une petite bougie (en ATR)
input int      InpSmallCandleMaxCount   = 10;      // Fermer après N petites bougies si aucun spike

input group "=== PREDICTED ARROW EXECUTION ==="
input bool     InpAutoTradeOnPredictiveArrow   = true; // Exécuter le trade à l'apparition de la flèche prédictive
input int      InpPredictTimeoutBars           = 10;   // Fermer après 10 petites bougies (SL temporel)
input bool     InpPredictTimeoutUseSmallCandles = true;  // Compter uniquement les petites bougies (SL=10 petites bougies)
input bool     InpArrowsOnlyPredConfirm  = true;  // N'afficher que les flèches PRÉDITE et CONFIRMÉE
input bool     InpEnableScissorTrades    = true;  // Exploiter les mouvements en ciseaux (haussiers)

input group "=== GESTION DU RISQUE - MOINS DE VOLATILITÉ ==="
input double   InpMinProfitDollars      = 1.0;     // Gain minimum en dollars avant fermeture
input double   InpVolatilityProfitTarget = 0.30;    // Gain cible pour les symboles de volatilité ($)
input double   InpStopLossPercent       = 20.0;    // Pourcentage de perte pour SL (20%)
input double   InpTakeProfitPercent     = 80.0;    // Pourcentage de profit pour TP (80%)
input bool     InpEnableAutoClose       = true;    // Fermer automatiquement au gain minimum
input double   InpMaxRiskPercent        = 2.0;     // Risque maximum par trade (2% du compte)
input int      InpMaxConcurrentTrades   = 2;       // Nombre maximum de trades simultanés

input group "=== SPIKE DETECTION SCIENTIFIQUE ==="
input bool     InpEnableScientificDetection = true;   // Activer détection scientifique
input double   InpSpikeThresholdScientific   = 30.0;   // Seuil de détection scientifique
input int      InpScientificLookback         = 1000;   // Période d'analyse statistique (1000 bougies)
input double   InpZScoreThreshold           = 1.5;    // Seuil Z-Score sensible
input bool     InpEnableScissorDetection     = true;   // Détecter mouvements en ciseaux
input bool     InpEnableFractalDetection     = true;   // Détecter patterns fractals
input double   InpVolumeMultiplier           = 2.0;    // Multiplicateur volume anormal
input bool     InpForceTradeOnArrow          = true;   // Prendre position obligatoirement sur flèche
input bool     InpShowVisuals           = true;   // Afficher les éléments visuels
input bool     InpPlaySounds            = false;  // Activer les sons
input bool     InpEnableNotifications   = true;   // Activer les notifications
input string   InpPhoneNumber           = "";     // Numéro de téléphone pour les notifications (format: 33612345678)
input color    InpColorOB_Bull          = clrLime;
input color    InpColorOB_Bear          = clrRed;
input color    InpColorSR               = clrAqua;
input color    InpColorTrend            = clrYellow;
input color    InpColorSpikeArrow       = clrMagenta;

input group "=== STRATÉGIE SPIKE AVANCÉE - EMA REBONDS ==="
input bool     InpEnableEMABounceStrategy    = true;    // Activer stratégie rebonds EMA
input int      InpEMA10Period                = 10;      // Période EMA 10
input int      InpEMA20Period                = 20;      // Période EMA 20
input int      InpEMA50Period                = 50;      // Période EMA 50
input double   InpEMABounceDistance          = 0.5;     // Distance max du rebond (en ATR)
input int      InpMinTouchesForBounce        = 2;       // Nombre min de touches sur EMA
input bool     InpRequireMultiTFConfirmation = true;    // Exiger confirmation 3 timeframes
input double   InpMinTrendConfidence         = 70.0;    // Confiance min tendance multi-TF (%)
input bool     InpUsePriceActionFilter       = true;    // Utiliser filtres price action
input bool     InpUseVolumeConfirmation      = true;    // Confirmer avec volume
input double   InpMinVolumeRatio             = 1.3;     // Ratio volume min pour confirmation
input bool     InpDetectEMAAlignment         = true;    // Détecter alignement parfait EMAs
input double   InpSpikeReliabilityTarget     = 90.0;    // Cible fiabilité détection (%)

input group "=== SMC (Smart Money Concepts) 2025 ==="
input bool     InpEnableSMC             = true;    // Activer les indicateurs SMC modernes
input bool     InpShowBOS               = true;    // Afficher Break of Structure (BOS)
input bool     InpShowCHOCH             = true;    // Afficher Change of Character (CHOCH)
input bool     InpShowOrderBlocks       = true;    // Afficher les Order Blocks
input bool     InpShowFVG               = true;    // Afficher Fair Value Gaps
input bool     InpShowLiquidityZones    = true;    // Afficher les zones de liquidité
input bool     InpShowMarketStructure   = true;    // Afficher la structure du marché
input int      InpSMCLookback           = 200;     // Lookback pour détection SMC
input int      InpSwingWindow          = 5;        // Fenêtre pour détection swings
input double   InpMinFVGSizePips        = 1.0;     // Taille minimale FVG en pips
input int      InpMaxOBLookback         = 50;      // Lookback max pour Order Blocks
input bool     InpUseSMCForTrading      = true;    // Utiliser SMC pour confirmer les trades

input group "=== NOUVELLE STRATÉGIE SPIKE MULTI-SYMBOLES ==="
input bool     InpEnableNewSpikeStrategy = true;    // Activer la nouvelle stratégie spike (PRINCIPALE)
input int      InpMaxSymbolsToTrade      = 2;       // Nombre max de symboles à trader (2)
input int      InpMaxPositionsPerSymbol  = 3;       // Nombre max de positions par symbole (2-3)
input int      InpStopLossCandles        = 10;      // Stop loss en nombre de bougies (10)
input ENUM_TIMEFRAMES InpGlobalTrendTF = PERIOD_H4; // Timeframe pour tendance globale (H4)
input int      InpMA30Period            = 30;      // Période MA30 pour M5
input int      InpMA10Period            = 10;      // Période MA10 pour M1
input double   InpMATouchDistance        = 0.2;     // Distance pour considérer "touch" MA (en ATR)
input double   InpSpikeCaptureProfit    = 0.5;     // Profit minimum pour capturer spike ($)

// Liste des symboles prioritaires (gardée pour compatibilité)
const string PRIORITY_SYMBOLS[] = {
   "Volatility 10 Index", "Volatility 25 Index", "Volatility 50 Index",
   "Volatility 75 Index", "Volatility 100 Index", "Volatility 10 (1s) Index",
   "Volatility 25 (1s) Index", "Volatility 50 (1s) Index", "Volatility 75 (1s) Index",
   "Volatility 100 (1s) Index", "Volatility 150 (2s) Index", "Volatility 250 (2s) Index",
   "Boom 300 Index", "Boom 500 Index", "Boom 600 Index", "Boom 900 Index", "Boom 1000 Index",
   "Crash 150 Index", "Crash 300 Index", "Crash 500 Index", "Crash 600 Index", "Crash 900 Index",
   "Crash 1000 Index", "Step Index 1", "Step Index 2", "Step Index 3", "Step Index 4", "Step Index 5"
};

// Structure pour stocker les handles d'indicateurs par symbole
struct SymbolIndicatorHandles
{
    int atr_handle;
    int ma20_handle;
    int ma50_handle;
    int short_atr_handle;
    int long_atr_handle;
    
    // Constructeur pour initialiser les handles
    SymbolIndicatorHandles()
    {
        atr_handle = INVALID_HANDLE;
        ma20_handle = INVALID_HANDLE;
        ma50_handle = INVALID_HANDLE;
        short_atr_handle = INVALID_HANDLE;
        long_atr_handle = INVALID_HANDLE;
    }
    
    // Méthode pour nettoyer tous les handles
    void ReleaseAll()
    {
        if(atr_handle != INVALID_HANDLE) { IndicatorRelease(atr_handle); atr_handle = INVALID_HANDLE; }
        if(ma20_handle != INVALID_HANDLE) { IndicatorRelease(ma20_handle); ma20_handle = INVALID_HANDLE; }
        if(ma50_handle != INVALID_HANDLE) { IndicatorRelease(ma50_handle); ma50_handle = INVALID_HANDLE; }
        if(short_atr_handle != INVALID_HANDLE) { IndicatorRelease(short_atr_handle); short_atr_handle = INVALID_HANDLE; }
        if(long_atr_handle != INVALID_HANDLE) { IndicatorRelease(long_atr_handle); long_atr_handle = INVALID_HANDLE; }
    }
};

// Tableau des handles par symbole
SymbolIndicatorHandles g_symbolHandles[];

// Garder les handles globaux pour compatibilité (utilisés uniquement pour _Symbol)
int g_atr_handle = INVALID_HANDLE;
int g_ma20_handle = INVALID_HANDLE;
int g_ma50_handle = INVALID_HANDLE;
int g_short_atr_handle = INVALID_HANDLE;
int g_long_atr_handle = INVALID_HANDLE;

// Handles pour les EMA multi-timeframe
struct EMAHandles {
    int ema200;
    int ema50;
    int ema34;
    int ema20;
    int ema10;
};

// Stockage des handles EMA par timeframe
EMAHandles g_emaHandles[];
ENUM_TIMEFRAMES g_timeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};

// Structure pour stocker les informations de rebond EMA
struct EMABounceInfo {
    bool isBouncing;           // Si un rebond est détecté
    int emaLevel;              // Niveau EMA (10, 20, 50)
    int direction;             // Direction du rebond (1=haussier, -1=baissier)
    double bouncePrice;        // Prix du rebond
    double confidence;         // Confiance du rebond (0-100)
    int touchCount;            // Nombre de touches sur l'EMA
    bool volumeConfirmed;      // Volume confirme le rebond
    bool priceActionConfirmed; // Price action confirme le rebond
};

// Structure pour la confirmation multi-timeframe
struct MultiTFConfirmation {
    bool tf1Bullish;           // TF1 haussier
    bool tf2Bullish;           // TF2 haussier
    bool tf3Bullish;           // TF3 haussier
    bool tf1Bearish;           // TF1 baissier
    bool tf2Bearish;           // TF2 baissier
    bool tf3Bearish;           // TF3 baissier
    double trendStrength;      // Force de la tendance (0-100)
    bool emaAligned;           // EMAs alignées
    int confirmedDirection;    // Direction confirmée (1, -1, 0)
};

// Structure pour la prédiction de spike
struct SpikePrediction {
    double predictedPrice;
    double confidence;
    int direction;
    datetime predictedTime;
    double entryPrice;
    double stopLoss;
    double takeProfit;
};

// global state
int      g_drawCount   = 0;                     // Compteur pour les objets graphiques
datetime g_lastBarTime = 0;                     // Dernière bougie traitée
datetime g_lastDayChecked = 0;                  // Dernier jour vérifié pour le drawdown
double   g_dailyStartingBalance = 0.0;          // Solde de départ de la journée
double   g_maxDailyDrawdown = 0.0;              // Drawdown maximum autorisé
double   g_lastVPIN    = 0.0;                   // Dernière valeur VPIN calculée
double   g_lastOBI     = 0.0;                   // Dernière valeur OBI calculée
double   g_lastCVD     = 0.0;                   // Dernière valeur CVD calculée
datetime g_lastArrowTime = 0;                   // Dernière fois qu'une flèche a été dessinée
int      g_lastArrowDirection = 0;               // Direction de la dernière flèche
double   g_lastArrowPrice = 0.0;                 // Prix de la dernière flèche
string   g_currentArrowName = "";                // Nom de la flèche actuelle pour suppression
bool     g_spikeConfirmed = false;               // Si le spike prédit a été confirmé
datetime g_spikeConfirmTime = 0;                 // Temps de confirmation du spike

// Structure pour consolider les signaux sur 3.5 minutes
struct SignalBuffer
{
   string symbol;
   datetime windowStart;          // Début de la fenêtre de 3.5 minutes
   int signalCount;               // Nombre de signaux dans la fenêtre
   double totalConfidence;        // Somme des confidences
   int totalDirection;            // Somme des directions (positif = BUY, négatif = SELL)
   double avgEntryPrice;          // Prix d'entrée moyen
   double avgSL;                  // Stop Loss moyen
   double avgTP;                  // Take Profit moyen
   double maxConfidence;          // Confiance maximale
   int bestDirection;             // Direction du signal le plus fort
};

SignalBuffer g_signalBuffers[];  // Buffer par symbole
string g_lastSignalSentSymbols[];  // Liste des symboles avec leur dernier signal
datetime g_lastSignalSentTimes[];  // Dernier signal envoyé par symbole

// Structure pour suivre les pertes consécutives par symbole
struct SymbolLossTracker
{
   string symbol;
   int consecutiveLosses;       // Nombre de pertes consécutives
   datetime lastLossTime;       // Dernière perte
   bool waitingForSpike;        // En attente d'un spike
   datetime spikeWaitStartTime; // Début de l'attente de spike
   int maxConsecutiveLosses;     // Maximum de pertes autorisées (2)
   
   SymbolLossTracker()
   {
      symbol = "";
      consecutiveLosses = 0;
      lastLossTime = 0;
      waitingForSpike = false;
      spikeWaitStartTime = 0;
      maxConsecutiveLosses = 2;
   }
};

// Structure pour stocker les signaux consolidés
struct ConsolidatedSignal
{
   string symbol;
   int signalCount;
   double avgConfidence;
   double avgEntry;
   double avgSL;
   double avgTP;
   int finalDirection;
   int bufferIndex;
};

// ========== SYSTÈME D'APPRENTISSAGE ADAPTATIF BASÉ SUR L'HISTORIQUE ==========
// Structure pour stocker les caractéristiques d'un signal
struct SignalFeatures
{
   datetime timestamp;
   string symbol;
   int direction;              // 1 = BUY, -1 = SELL
   double confidence;          // Confiance du signal
   double zscore;             // Z-Score au moment du signal
   double skewness;            // Skewness
   double kurtosis;           // Kurtosis
   double volumeRatio;         // Ratio de volume
   double atrRatio;           // Ratio ATR
   bool hasScissorPattern;    // Pattern ciseaux détecté
   bool hasFractalPattern;    // Pattern fractal détecté
   bool hasHammerPattern;      // Pattern marteau
   bool hasEngulfingPattern;   // Pattern englobant
   bool hasGap;               // Gap détecté
   bool hasBBBreakout;        // Breakout Bollinger Bands
   double entryPrice;         // Prix d'entrée
   double stopLoss;           // Stop Loss
   double takeProfit;         // Take Profit
   int signalType;            // Type de signal (0=prédiction, 1=consolidé, 2=CHOCH)
   int signalCount;           // Nombre de signaux consolidés (si applicable)
};

// Structure pour stocker le résultat d'un signal
struct SignalResult
{
   datetime signalTime;
   string symbol;
   ulong ticket;              // Ticket de la position
   double profit;             // Profit/perte final
   bool spikeCaptured;        // True si un spike a été capturé
   double spikeMagnitude;     // Amplitude du spike capturé
   bool reachedTP;            // True si TP atteint
   bool hitSL;                // True si SL touché
   datetime closeTime;         // Temps de fermeture
   double maxProfit;           // Profit maximum atteint
   double maxDrawdown;         // Drawdown maximum
};

// Structure pour le score de performance d'un pattern
struct PatternPerformance
{
   string patternName;
   int totalSignals;          // Nombre total de signaux avec ce pattern
   int successfulSignals;      // Nombre de signaux réussis
   double totalProfit;         // Profit total
   double avgProfit;          // Profit moyen
   double winRate;            // Taux de réussite (%)
   double profitFactor;       // Facteur de profit
   double avgConfidence;      // Confiance moyenne des signaux réussis
};

// Historique des signaux (max 1000 entrées)
SignalFeatures g_signalHistory[];
SignalResult g_resultHistory[];
int g_signalHistoryCount = 0;
int g_resultHistoryCount = 0;

// Trackers des pertes consécutives par symbole
SymbolLossTracker g_lossTrackers[];

// Scores de performance par pattern
PatternPerformance g_patternScores[];
int g_patternScoresCount = 0;

// Poids adaptatifs pour les facteurs de signal
struct AdaptiveWeights
{
   double zscoreWeight;       // Poids Z-Score (initial: 30%)
   double skewnessWeight;     // Poids Skewness (initial: 15%)
   double kurtosisWeight;     // Poids Kurtosis (initial: 15%)
   double volumeWeight;        // Poids Volume (initial: 10%)
   double scissorWeight;      // Poids Pattern Ciseaux (initial: 10%)
   double fractalWeight;      // Poids Pattern Fractal (initial: 10%)
   double hammerWeight;       // Poids Pattern Marteau (initial: 5%)
   double engulfingWeight;     // Poids Pattern Englobant (initial: 8%)
   double gapWeight;          // Poids Gap (initial: 7%)
   double bbBreakoutWeight;   // Poids BB Breakout (initial: 10%)
   double atrWeight;         // Poids ATR (initial: 5%)
};

AdaptiveWeights g_adaptiveWeights = {
   30.0,  // zscoreWeight
   15.0,  // skewnessWeight
   15.0,  // kurtosisWeight
   10.0,  // volumeWeight
   10.0,  // scissorWeight
   10.0,  // fractalWeight
   5.0,   // hammerWeight
   8.0,   // engulfingWeight
   7.0,   // gapWeight
   10.0,  // bbBreakoutWeight
   5.0    // atrWeight
};

// Structure pour les statistiques du marché (utilisée par le système d'apprentissage)
struct MarketStats
{
   double zscore_current;
   double skewness;
   double kurtosis;
};

// ========== FIN SYSTÈME D'APPRENTISSAGE ==========

// Structures SMC (Smart Money Concepts) 2025
struct SwingPoint 
{ 
   int index; 
   double price; 
   bool isHigh; 
};

struct FVGZone 
{ 
   int bar_time_index; 
   double top; 
   double bottom; 
   ENUM_TIMEFRAMES tf; 
   datetime time;
   bool bullish;
};

struct OBZone 
{
   datetime time1;      // Temps de début
   datetime time2;      // Temps de fin
   double high;         // Niveau haut
   double low;          // Niveau bas
   ENUM_TIMEFRAMES tf;  // Timeframe
   bool bullish;       // Direction haussière ou baissière
};

enum ENUM_STRUCT 
{ 
   STRUCT_NONE=0, 
   STRUCT_BOS_UP=1, 
   STRUCT_BOS_DOWN=2, 
   STRUCT_CHOCH_UP=3, 
   STRUCT_CHOCH_DOWN=4 
};

// Suivi des signaux actifs par symbole
struct ActiveSignal {
   string  symbol;       // Symbole du signal
   bool    isActive;     // Si un signal est actif
   int     direction;    // Direction du signal (1 pour achat, -1 pour vente)
   double  entryLevel;   // Niveau d'entrée du signal
   datetime lastSignalTime; // Dernier moment où le signal a été émis
};

// Tableau pour stocker les signaux actifs par symbole
ActiveSignal g_activeSignals[];

// Suivi des positions ouvertes à la suite d'une flèche PRÉDICTIVE
struct PredictedPositionTracker
{
   string   symbol;
   ulong    ticket;
   int      direction;          // 1 BUY, -1 SELL
   datetime openTime;
   double   entryPrice;
   double   predictedTarget;    // prix cible de spike prédit
   int      smallCount;         // nombre de petites bougies depuis l'ouverture
   datetime lastCountBarTime;   // dernière bougie prise en compte
   bool     closedByTimeout;
};

PredictedPositionTracker g_predictedPositions[];

int FindPredictedTrackerIndexByTicket(ulong ticket)
{
   for(int i=0;i<ArraySize(g_predictedPositions);i++)
      if(g_predictedPositions[i].ticket == ticket)
         return i;
   return -1;
}

void RegisterPredictedTrade(string symbol, ulong ticket, int direction, double entryPrice, double predictedTarget)
{
   int sz = ArraySize(g_predictedPositions);
   ArrayResize(g_predictedPositions, sz+1);
   g_predictedPositions[sz].symbol = symbol;
   g_predictedPositions[sz].ticket = ticket;
   g_predictedPositions[sz].direction = direction;
   g_predictedPositions[sz].openTime = TimeCurrent();
   g_predictedPositions[sz].entryPrice = entryPrice;
   g_predictedPositions[sz].predictedTarget = predictedTarget;
   g_predictedPositions[sz].smallCount = 0;
   g_predictedPositions[sz].lastCountBarTime = 0;
   g_predictedPositions[sz].closedByTimeout = false;
   PrintFormat("?? Suivi position prédictive: %s ticket=%llu dir=%s entry=%.5f target=%.5f",
               symbol, ticket, (direction>0?"BUY":"SELL"), entryPrice, predictedTarget);
}

ulong FindLatestMagicPositionTicket(string symbol)
{
   datetime bestTime = 0;
   ulong bestTicket = 0;
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk>0 && PositionSelectByTicket(tk))
      {
         if(PositionGetInteger(POSITION_MAGIC)==InpMagicNumber && PositionGetString(POSITION_SYMBOL)==symbol)
         {
            datetime t = (datetime)PositionGetInteger(POSITION_TIME);
            if(t >= bestTime) { bestTime=t; bestTicket=tk; }
         }
      }
   }
   return bestTicket;
}

void MonitorPredictedTrades()
{
   // Comptage seulement à la clôture d'une nouvelle bougie
   datetime barTime = iTime(_Symbol, InpSpikeTimeframe, 0);
   datetime lastClosedBarTime = iTime(_Symbol, InpSpikeTimeframe, 1);

   for(int i=ArraySize(g_predictedPositions)-1; i>=0; i--)
   {
      ulong ticket = g_predictedPositions[i].ticket;
      string sym = g_predictedPositions[i].symbol;

      // Si la position n'existe plus, retirer le tracker
      if(!PositionSelectByTicket(ticket))
      {
         ArrayRemove(g_predictedPositions, i, 1);
         continue;
      }

      // Si on a déjà compté cette bougie, passer
      if(g_predictedPositions[i].lastCountBarTime == lastClosedBarTime)
         continue;

      // Vérifier si un spike est survenu (atteinte de la cible prédite)
      bool spikeOk = CheckSpikeRealization(g_predictedPositions[i].direction,
                                           g_predictedPositions[i].predictedTarget,
                                           (double)g_predictedPositions[i].openTime);
      if(spikeOk)
      {
         // La logique générale de fermeture après spike s'occupe déjà de fermer.
         // On libère le tracker.
         ArrayRemove(g_predictedPositions, i, 1);
         continue;
      }

      // Compter la bougie [1] tout juste close (toutes les bougies ou uniquement petites selon réglage)
      double atr = GetCurrentATR(sym);
      if(atr <= 0.0)
      {
         MqlRates rr[]; if(CopyRates(sym, InpSpikeTimeframe, 1, 1, rr)>0) atr = rr[0].high-rr[0].low;
      }
      MqlRates r1[]; if(CopyRates(sym, InpSpikeTimeframe, 1, 1, r1) < 1) continue;
      double range1 = r1[0].high - r1[0].low;
      bool small = (atr>0.0 && range1 <= atr * InpSmallCandleATRMult);
      bool countThisBar = InpPredictTimeoutUseSmallCandles ? small : true;

      if(countThisBar)
      {
         g_predictedPositions[i].smallCount++;
         g_predictedPositions[i].lastCountBarTime = lastClosedBarTime;

         int maxBars = InpPredictTimeoutBars;
         if(g_predictedPositions[i].smallCount >= maxBars)
         {
            // Fermer la position par timeout
            if(trade.PositionClose(ticket))
            {
               PrintFormat("? Fermeture par timeout: %s ticket=%llu après %d petites bougies sans spike",
                           sym, ticket, g_predictedPositions[i].smallCount);
            }
            ArrayRemove(g_predictedPositions, i, 1);
         }
      }
      else
      {
         // Réinitialiser le marquage de bougie traitée pour ne pas recompter tant que la bougie change
         g_predictedPositions[i].lastCountBarTime = lastClosedBarTime;
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie si un signal de trading est actif pour le symbole courant |
//+------------------------------------------------------------------+
bool IsSignalActive(int checkDirection = 0)
{
   string symbol = _Symbol;
   
   // Parcourir le tableau des signaux actifs
   for(int i = 0; i < ArraySize(g_activeSignals); i++)
   {
      if(g_activeSignals[i].isActive && g_activeSignals[i].symbol == symbol)
      {
         // Si on vérifie une direction spécifique
         if(checkDirection != 0 && g_activeSignals[i].direction != checkDirection)
            return false;
            
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Marque un signal comme actif pour le symbole courant             |
//+------------------------------------------------------------------+
void SetSignalActive(int direction, double entryLevel)
{
   string symbol = _Symbol;
   bool found = false;
   
   // Vérifier si le symbole a déjà un signal actif
   for(int i = 0; i < ArraySize(g_activeSignals); i++)
   {
      if(g_activeSignals[i].symbol == symbol)
      {
         // Mettre à jour le signal existant
         g_activeSignals[i].isActive = true;
         g_activeSignals[i].direction = direction;
         g_activeSignals[i].entryLevel = entryLevel;
         g_activeSignals[i].lastSignalTime = TimeCurrent();
         found = true;
         break;
      }
   }
   
   // Si pas trouvé, ajouter un nouveau signal
   if(!found)
   {
      int size = ArraySize(g_activeSignals);
      ArrayResize(g_activeSignals, size + 1);
      g_activeSignals[size].symbol = symbol;
      g_activeSignals[size].isActive = true;
      g_activeSignals[size].direction = direction;
      g_activeSignals[size].entryLevel = entryLevel;
      g_activeSignals[size].lastSignalTime = TimeCurrent();
   }
   
   Print("Signal actif pour ", symbol, " - Direction: ", (direction > 0 ? "Achat" : "Vente"), 
         " à ", DoubleToString(entryLevel, _Digits));
}

//+------------------------------------------------------------------+
//| Vérifie et nettoie les signaux expirés                          |
//+------------------------------------------------------------------+
void CleanupExpiredSignals()
{
   datetime currentTime = TimeCurrent();
   
   for(int i = ArraySize(g_activeSignals) - 1; i >= 0; i--)
   {
      // Supprimer les signaux de plus de 24h
      if(currentTime - g_activeSignals[i].lastSignalTime > 86400) // 24 heures en secondes
      {
         Print("Suppression du signal expiré pour ", g_activeSignals[i].symbol);
         ArrayRemove(g_activeSignals, i, 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Calcule la tendance globale basée sur les EMA multi-timeframe   |
//+------------------------------------------------------------------+
int CalculateGlobalTrend()
{
   int bullishCount = 0;
   int bearishCount = 0;
   
   for(int tf = 0; tf < ArraySize(g_timeframes); tf++)
   {
      int trend = GetTrendFromEMA(g_timeframes[tf]);
      if(trend > 0) bullishCount++;
      else if(trend < 0) bearishCount++;
   }
   
   if(bullishCount > bearishCount) return 1;
   if(bearishCount > bullishCount) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Calcule la force de la tendance globale en pourcentage          |
//+------------------------------------------------------------------+
double CalculateTrendStrength()
{
   double totalStrength = 0;
   int validTimeframes = 0;
   
   for(int tf = 0; tf < ArraySize(g_timeframes); tf++)
   {
      int trend = GetTrendFromEMA(g_timeframes[tf]);
      if(trend != 0)
      {
         // Calculer la force pour ce timeframe
         int ema10 = iMA(_Symbol, g_timeframes[tf], 10, 0, MODE_EMA, PRICE_CLOSE);
         int ema200 = iMA(_Symbol, g_timeframes[tf], 200, 0, MODE_EMA, PRICE_CLOSE);
         int atrHandle = iATR(_Symbol, g_timeframes[tf], 14);
         
         if(ema10 != INVALID_HANDLE && ema200 != INVALID_HANDLE && atrHandle != INVALID_HANDLE)
         {
            double ema10_val[], ema200_val[], atr_val[];
            ArraySetAsSeries(ema10_val, true);
            ArraySetAsSeries(ema200_val, true);
            ArraySetAsSeries(atr_val, true);
            
            if(CopyBuffer(ema10, 0, 0, 1, ema10_val) > 0 &&
               CopyBuffer(ema200, 0, 0, 1, ema200_val) > 0 &&
               CopyBuffer(atrHandle, 0, 0, 1, atr_val) > 0)
            {
               if(atr_val[0] > 0)
               {
                  double strength = MathAbs(ema10_val[0] - ema200_val[0]) / atr_val[0] * 10;
                  strength = MathMin(MathMax(strength, 0), 100);
                  totalStrength += strength;
                  validTimeframes++;
               }
            }
            
            IndicatorRelease(ema10);
            IndicatorRelease(ema200);
            IndicatorRelease(atrHandle);
         }
      }
   }
   
   if(validTimeframes > 0)
      return totalStrength / validTimeframes;
   return 0;
}

//+------------------------------------------------------------------+
//| Vérifie si la tendance est suffisamment claire pour un trade inverse |
//+------------------------------------------------------------------+
bool IsTrendClearForReverse(int requiredDirection)
{
   if(!InpAllowReverseTrades) return false;
   
   int globalTrend = CalculateGlobalTrend();
   double trendStrength = CalculateTrendStrength();
   
   // La tendance doit être claire et forte
   if(trendStrength < InpMinTrendStrength) return false;
   
   // La tendance globale doit être dans le sens opposé au symbole
   // Si on veut SELL sur Boom, la tendance doit être baissière (globalTrend < 0)
   // Si on veut BUY sur Crash, la tendance doit être haussière (globalTrend > 0)
   if(requiredDirection > 0) // BUY sur Crash
   {
      return (globalTrend > 0 && trendStrength >= InpMinTrendStrength);
   }
   else // SELL sur Boom
   {
      return (globalTrend < 0 && trendStrength >= InpMinTrendStrength);
   }
}

//+------------------------------------------------------------------+
//| Obtient la tendance d'un timeframe basée sur les EMA            |
//+------------------------------------------------------------------+
int GetTrendFromEMA(ENUM_TIMEFRAMES tf)
{
   int ema10 = iMA(_Symbol, tf, 10, 0, MODE_EMA, PRICE_CLOSE);
   int ema20 = iMA(_Symbol, tf, 20, 0, MODE_EMA, PRICE_CLOSE);
   int ema34 = iMA(_Symbol, tf, 34, 0, MODE_EMA, PRICE_CLOSE);
   int ema50 = iMA(_Symbol, tf, 50, 0, MODE_EMA, PRICE_CLOSE);
   int ema200 = iMA(_Symbol, tf, 200, 0, MODE_EMA, PRICE_CLOSE);
   
   if(ema10 == INVALID_HANDLE || ema20 == INVALID_HANDLE || ema34 == INVALID_HANDLE || 
      ema50 == INVALID_HANDLE || ema200 == INVALID_HANDLE)
   {
      if(ema10 != INVALID_HANDLE) IndicatorRelease(ema10);
      if(ema20 != INVALID_HANDLE) IndicatorRelease(ema20);
      if(ema34 != INVALID_HANDLE) IndicatorRelease(ema34);
      if(ema50 != INVALID_HANDLE) IndicatorRelease(ema50);
      if(ema200 != INVALID_HANDLE) IndicatorRelease(ema200);
      return 0;
   }
   
   double ema10_val[], ema20_val[], ema34_val[], ema50_val[], ema200_val[];
   ArraySetAsSeries(ema10_val, true);
   ArraySetAsSeries(ema20_val, true);
   ArraySetAsSeries(ema34_val, true);
   ArraySetAsSeries(ema50_val, true);
   ArraySetAsSeries(ema200_val, true);
   
   if(CopyBuffer(ema10, 0, 0, 1, ema10_val) <= 0 ||
      CopyBuffer(ema20, 0, 0, 1, ema20_val) <= 0 ||
      CopyBuffer(ema34, 0, 0, 1, ema34_val) <= 0 ||
      CopyBuffer(ema50, 0, 0, 1, ema50_val) <= 0 ||
      CopyBuffer(ema200, 0, 0, 1, ema200_val) <= 0)
   {
      IndicatorRelease(ema10);
      IndicatorRelease(ema20);
      IndicatorRelease(ema34);
      IndicatorRelease(ema50);
      IndicatorRelease(ema200);
      return 0;
   }
   
   // Tendance haussière: EMA10 > EMA20 > EMA34 > EMA50 > EMA200
   bool bullish = (ema10_val[0] > ema20_val[0] && ema20_val[0] > ema34_val[0] && 
                   ema34_val[0] > ema50_val[0] && ema50_val[0] > ema200_val[0]);
   
   // Tendance baissière: EMA10 < EMA20 < EMA34 < EMA50 < EMA200
   bool bearish = (ema10_val[0] < ema20_val[0] && ema20_val[0] < ema34_val[0] && 
                   ema34_val[0] < ema50_val[0] && ema50_val[0] < ema200_val[0]);
   
   IndicatorRelease(ema10);
   IndicatorRelease(ema20);
   IndicatorRelease(ema34);
   IndicatorRelease(ema50);
   IndicatorRelease(ema200);
   
   if(bullish) return 1;
   if(bearish) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| Vérifie si un symbole est un symbole de volatilité               |
//+------------------------------------------------------------------+
bool IsSymbolVolatility(string symbol)
{
   // Vérifier si le nom du symbole contient "Volatility" ou "Index"
   if(StringFind(symbol, "Volatility", 0) >= 0 || StringFind(symbol, "Index", 0) >= 0)
      return true;
   
   // Vérifier aussi pour les symboles Boom/Crash/Step
   if(StringFind(symbol, "Boom", 0) >= 0 || StringFind(symbol, "Crash", 0) >= 0 || StringFind(symbol, "Step", 0) >= 0)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Obtient l'index du tracker de pertes pour un symbole                 |
//+------------------------------------------------------------------+
int GetLossTrackerIndex(string symbol)
{
   for(int i = 0; i < ArraySize(g_lossTrackers); i++)
   {
      if(g_lossTrackers[i].symbol == symbol)
         return i;
   }
   
   // Créer un nouveau tracker si non trouvé
   int size = ArraySize(g_lossTrackers);
   ArrayResize(g_lossTrackers, size + 1);
   g_lossTrackers[size].symbol = symbol;
   return size;
}

//+------------------------------------------------------------------+
//| Vérifie si un nouveau trade est autorisé pour le symbole          |
//+------------------------------------------------------------------+
bool IsTradeAllowedForSymbol(string symbol)
{
   int index = GetLossTrackerIndex(symbol);
   SymbolLossTracker tracker = g_lossTrackers[index];
   
   // Si 2 pertes consécutives ou plus, vérifier si on attend un spike
   if(tracker.consecutiveLosses >= tracker.maxConsecutiveLosses)
   {
      if(tracker.waitingForSpike)
      {
         PrintFormat("?? %s: En attente d'un spike avant de trader (pertes: %d)", 
                     symbol, tracker.consecutiveLosses);
         return false; // En attente de spike
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Enregistre une perte pour le symbole                              |
//+------------------------------------------------------------------+
void RecordLossForSymbol(string symbol, double lossAmount)
{
   int index = GetLossTrackerIndex(symbol);
   
   g_lossTrackers[index].consecutiveLosses++;
   g_lossTrackers[index].lastLossTime = TimeCurrent();
   
   PrintFormat("?? %s: Perte enregistrée (%.2f $) - Pertes consécutives: %d", 
               symbol, lossAmount, g_lossTrackers[index].consecutiveLosses);
   
   // Si on atteint 2 pertes, activer l'attente de spike
   if(g_lossTrackers[index].consecutiveLosses >= g_lossTrackers[index].maxConsecutiveLosses)
   {
      g_lossTrackers[index].waitingForSpike = true;
      g_lossTrackers[index].spikeWaitStartTime = TimeCurrent();
      PrintFormat("?? %s: ATTENTE SPIKE ACTIVÉE - Plus de trades jusqu'au prochain spike", symbol);
   }
}

//+------------------------------------------------------------------+
//| Enregistre un gain pour le symbole (réinitialise les pertes)       |
//+------------------------------------------------------------------+
void RecordProfitForSymbol(string symbol, double profitAmount)
{
   int index = GetLossTrackerIndex(symbol);
   
   if(g_lossTrackers[index].consecutiveLosses > 0)
   {
      PrintFormat("? %s: Gain enregistré (%.2f $) - Réinitialisation des pertes consécutives (%d -> 0)", 
                  symbol, profitAmount, g_lossTrackers[index].consecutiveLosses);
   }
   
   g_lossTrackers[index].consecutiveLosses = 0;
   g_lossTrackers[index].waitingForSpike = false;
   g_lossTrackers[index].spikeWaitStartTime = 0;
}

//+------------------------------------------------------------------+
//| Détecte un spike et réactive le trading si nécessaire               |
//+------------------------------------------------------------------+
void CheckForSpikeAndReactivate(string symbol)
{
   int index = GetLossTrackerIndex(symbol);
   
   if(!g_lossTrackers[index].waitingForSpike) return;
   
   // Détecter un spike sur le symbole
   int direction = 0;
   double strength = 0;
   if(DetectSpikeSequence(InpSpikeTimeframe, direction, strength))
   {
      g_lossTrackers[index].waitingForSpike = false;
      g_lossTrackers[index].consecutiveLosses = 0; // Réinitialiser après spike
      g_lossTrackers[index].spikeWaitStartTime = 0;
      
      PrintFormat("?? %s: SPIKE DÉTECTÉ - Trading réactivé!", symbol);
   }
}

//+------------------------------------------------------------------+
//| Affiche le tableau de bord amélioré avec les tendances          |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   string prefix = "Dashboard_";
   
   // Supprimer les anciens objets
   for(int i = ObjectsTotal(0, 0, -1)-1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
   
   if(!InpShowInfo) return;
   
   // Paramètres d'affichage
   int x = 20;
   int y = 20;
   int lineHeight = 18;
   color textColor = clrWhite;
   
   // Créer le fond
   string bgName = prefix + "BG";
   int numTimeframes = ArraySize(g_timeframes);
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x-5);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y-5);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 350);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, lineHeight * (numTimeframes + 4) + 10); // +4 au lieu de +3 pour inclure le score
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'20,20,20');
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   
   // Titre
   CreateLabel(prefix+"Title", "Tableau de bord - "+_Symbol, x, y, textColor, 11, "Arial Bold");
   y += lineHeight;
   
   // Tendance globale
   int globalTrend = CalculateGlobalTrend();
   string globalTrendText = "Tendance globale: ";
   color globalTrendColor = clrGray;
   if(globalTrend > 0) { globalTrendText += "HAUSSIÈRE"; globalTrendColor = clrLime; }
   else if(globalTrend < 0) { globalTrendText += "BAISSIÈRE"; globalTrendColor = clrRed; }
   else { globalTrendText += "NEUTRE"; }
   CreateLabel(prefix+"Global", globalTrendText, x, y, globalTrendColor, 10, "Arial Bold");
   y += lineHeight;
   
   // Score global de performance du robot
   double globalScore = 0.0;
   if(PositionsTotal() > 0) {
      // Calcul simple du score basé sur le profit total
      double totalProfit = 0.0;
      for(int i = 0; i < PositionsTotal(); i++) {
         if(positionInfo.SelectByIndex(i)) {
            totalProfit += positionInfo.Profit();
         }
      }
      globalScore = MathMin(100.0, MathMax(0.0, 50.0 + (totalProfit / 10.0)));
   }
   string scoreText = StringFormat("Score Performance: %.1f/100", globalScore);
   color scoreColor = clrGray;
   if(globalScore >= 70) scoreColor = clrLime;
   else if(globalScore >= 50) scoreColor = clrYellow;
   else if(globalScore >= 30) scoreColor = clrOrange;
   else scoreColor = clrRed;
   CreateLabel(prefix+"Score", scoreText, x, y, scoreColor, 10, "Arial Bold");
   y += lineHeight;
   
   // Séparateur
   CreateLabel(prefix+"Sep", "?????????????????????????", x, y, clrGray, 8);
   y += lineHeight;
   
   // Afficher la tendance pour chaque timeframe
   string tfNames[] = {"M1", "M5", "M15", "H1", "H4", "D1"};
   
   for(int i = 0; i < ArraySize(g_timeframes); i++)
   {
      int trend = GetTrendFromEMA(g_timeframes[i]);
      double price = iClose(_Symbol, g_timeframes[i], 0);
      
      string trendText = "";
      color trendColor = clrGray;
      double strength = 0;
      
      // Calculer la force de la tendance
      int ema10 = iMA(_Symbol, g_timeframes[i], 10, 0, MODE_EMA, PRICE_CLOSE);
      int ema200 = iMA(_Symbol, g_timeframes[i], 200, 0, MODE_EMA, PRICE_CLOSE);
      int atrHandle = iATR(_Symbol, g_timeframes[i], 14);
      
      if(ema10 != INVALID_HANDLE && ema200 != INVALID_HANDLE && atrHandle != INVALID_HANDLE)
      {
         double ema10_val[], ema200_val[], atr_val[];
         ArraySetAsSeries(ema10_val, true);
         ArraySetAsSeries(ema200_val, true);
         ArraySetAsSeries(atr_val, true);
         
         if(CopyBuffer(ema10, 0, 0, 1, ema10_val) > 0 &&
            CopyBuffer(ema200, 0, 0, 1, ema200_val) > 0 &&
            CopyBuffer(atrHandle, 0, 0, 1, atr_val) > 0)
         {
            if(atr_val[0] > 0)
            {
               strength = MathAbs(ema10_val[0] - ema200_val[0]) / atr_val[0] * 10;
               strength = MathMin(MathMax(strength, 0), 100);
            }
         }
         
         IndicatorRelease(ema10);
         IndicatorRelease(ema200);
         IndicatorRelease(atrHandle);
      }
      
      if(trend > 0)
      {
         trendText = StringFormat("%s: ? HAUSSIER (%.0f%%)", tfNames[i], strength);
         trendColor = clrLime;
      }
      else if(trend < 0)
      {
         trendText = StringFormat("%s: ? BAISSIER (%.0f%%)", tfNames[i], strength);
         trendColor = clrRed;
      }
      else
      {
         trendText = StringFormat("%s: ? NEUTRE (%.0f%%)", tfNames[i], strength);
         trendColor = clrYellow;
      }
      
      CreateLabel(prefix+"TF_"+tfNames[i], trendText, x, y, trendColor, 9);
      y += lineHeight;
   }
   
   // Rafraîchir le graphique
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Crée un label sur le graphique                                   |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize=8, string font="Arial")
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
}

//+------------------------------------------------------------------+
//| Détecte un spike CONFIRMÉ sur le marché (version renforcée pour scalping) |
//+------------------------------------------------------------------+
bool IsSpikeDetected(ENUM_TIMEFRAMES tf, double &spikeStrength, int &spikeDirection)
{
    MqlRates rates[];
    int lookback = 50; // Analyser plus de bougies pour meilleure statistique
    if(CopyRates(_Symbol, tf, 0, lookback, rates) < lookback) return false;
    
    // Calculer la moyenne et l'écart-type des mouvements
    double moves[];
    ArrayResize(moves, lookback - 1);
    double sumMoves = 0;
    
    for(int i = 0; i < lookback - 1; i++)
    {
        moves[i] = MathAbs(rates[i].close - rates[i+1].close);
        sumMoves += moves[i];
    }
    
    double avgMove = sumMoves / (lookback - 1);
    if(avgMove <= 0) return false;
    
    // Calculer l'écart-type
    double variance = 0;
    for(int i = 0; i < lookback - 1; i++)
    {
        variance += MathPow(moves[i] - avgMove, 2);
    }
    double stdDev = MathSqrt(variance / (lookback - 1));

    // Mouvement actuel (bougie fermée - plus fiable)
    double currentMove = MathAbs(rates[0].close - rates[0].open);
    double currentRange = rates[0].high - rates[0].low;

    // CRITÈRES STRICTS POUR SCALPING AVEC PETIT CAPITAL
    // 1. Z-Score significatif (spike statistiquement anormal)
    double zScore = (currentMove - avgMove) / (stdDev > 0 ? stdDev : avgMove);

    // Seuils plus stricts pour éviter faux signaux avec petit capital
    double zScoreThreshold = (tf == PERIOD_M5) ? 2.0 : 2.5; // Plus strict pour M5
    double moveMultiplier = (tf == PERIOD_M5) ? 2.5 : 3.0;  // Mouvement doit être 2.5x la moyenne

    // 2. Le corps de la bougie doit être dominant (pas de mèche excessive)
    double bodyRatio = (currentRange > 0) ? (currentMove / currentRange) : 0;
    bool strongBody = (bodyRatio >= 0.6); // Corps >= 60% de la range

    // 3. Volume anormalement élevé
    bool volumeSpike = false;
    if(lookback >= 10)
    {
        double avgVolume = 0;
        for(int i = 1; i < 10; i++)
        {
            avgVolume += (double)rates[i].tick_volume;
        }
        avgVolume /= 9;

        double currentVolume = (double)rates[0].tick_volume;
        volumeSpike = (currentVolume > avgVolume * 1.5); // Volume 50% au-dessus de la moyenne
    }

    // 4. Mouvement directionnel clair (pas d'indécision)
    double wickRatio = 0;
    if(currentRange > 0)
    {
        double upperWick = rates[0].high - MathMax(rates[0].open, rates[0].close);
        double lowerWick = MathMin(rates[0].open, rates[0].close) - rates[0].low;
        wickRatio = MathMax(upperWick, lowerWick) / currentRange;
    }
    bool clearDirection = (wickRatio < 0.3); // Mèches < 30%

    // SPIKE CONFIRMÉ si TOUS les critères sont remplis (approche stricte pour scalping)
    bool isSpike = (zScore >= zScoreThreshold) &&
                   (currentMove >= avgMove * moveMultiplier) &&
                   strongBody &&
                   volumeSpike &&
                   clearDirection;

    if(isSpike)
    {
        spikeStrength = zScore * 20; // Convertir en pourcentage
        spikeDirection = (rates[0].close > rates[0].open) ? 1 : -1;

        PrintFormat("?? SPIKE CONFIRMÉ DÉTECTÉ - Z-Score: %.2f, Move: %.5f (avg: %.5f), Body: %.1f%%, Volume: %s, Direction: %s",
                    zScore, currentMove, avgMove, bodyRatio * 100, volumeSpike ? "OUI" : "NON",
                    (spikeDirection > 0 ? "BUY" : "SELL"));

        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Détecte les successions de spikes en forte tendance (version stricte) |
//+------------------------------------------------------------------+
bool DetectSpikeSequence(ENUM_TIMEFRAMES tf, int &direction, double &strength)
{
    MqlRates rates[];
    int lookback = 50; // Analyser les 50 dernières bougies
    if(CopyRates(_Symbol, tf, 0, lookback, rates) < lookback) return false;
    
    int spikeCount = 0;
    int bullishSpikes = 0;
    int bearishSpikes = 0;
    double totalSpikeStrength = 0;

    // Analyser les dernières bougies pour détecter les spikes CONFIRMÉS
    for(int i = 0; i < 10; i++) // Dernières 10 bougies
    {
        double move = MathAbs(rates[i].close - rates[i].open);
        double range = rates[i].high - rates[i].low;
        
        // Calculer la moyenne des mouvements précédents
        double avgMove = 0;
        int count = 0;
        for(int j = i + 1; j < MathMin(i + 10, lookback); j++)
        {
            avgMove += MathAbs(rates[j].close - rates[j].open);
            count++;
        }
        if(count > 0) avgMove /= count;

        // Seuils plus stricts pour détecter une vraie succession
        double spikeMultiplier = (tf == PERIOD_M5) ? 2.0 : 2.5; // Plus strict

        // Vérifier aussi le volume et le corps de bougie
        bool validSpike = false;
        if(avgMove > 0 && move > avgMove * spikeMultiplier)
        {
            double bodyRatio = (range > 0) ? (move / range) : 0;
            if(bodyRatio >= 0.6) // Corps dominant
            {
                validSpike = true;
            }
        }

        if(validSpike)
        {
            spikeCount++;
            totalSpikeStrength += (move / avgMove);
            
            if(rates[i].close > rates[i].open)
                bullishSpikes++;
            else
                bearishSpikes++;
        }
    }

    // Succession détectée uniquement si au moins 3 spikes confirmés (strict pour scalping)
    int minSpikes = 3;
    if(spikeCount >= minSpikes)
    {
        strength = (totalSpikeStrength / spikeCount) * 20; // Force moyenne
        direction = (bullishSpikes > bearishSpikes) ? 1 : -1;

        // Vérifier que la direction est claire (au moins 70% dans un sens)
        int totalDirectional = bullishSpikes + bearishSpikes;
        double directionRatio = (direction > 0) ? ((double)bullishSpikes / totalDirectional) : ((double)bearishSpikes / totalDirectional);

        if(directionRatio >= 0.7) // 70% des spikes dans la même direction
        {
            PrintFormat("?? SUCCESSION DE SPIKE CONFIRMÉE: %d spikes, Direction: %s (%.0f%%), Force: %.1f%%",
                        spikeCount, (direction > 0 ? "HAUSSIER" : "BAISSIER"), directionRatio * 100, strength);
            return true;
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Vérifie si un spike s'est réalisé après une prédiction          |
//+------------------------------------------------------------------+
bool CheckSpikeRealization(int predictedDirection, double predictedPrice, double predictionTime)
{
    // Vérifier si le spike prédit s'est effectivement produit dans les 2 bougies suivantes
    MqlRates rates[];
    if(CopyRates(_Symbol, InpSpikeTimeframe, 0, 3, rates) < 3) return false;

    double currentPrice = rates[0].close;

    // Pour un spike haussier prédit
    if(predictedDirection > 0)
    {
        // Le prix a-t-il atteint ou dépassé le prix prédit ?
        if(rates[0].high >= predictedPrice || rates[1].high >= predictedPrice)
        {
            PrintFormat("? SPIKE HAUSSIER RÉALISÉ - Prédit: %.5f, Atteint: %.5f",
                        predictedPrice, MathMax(rates[0].high, rates[1].high));
            return true;
        }
    }
    // Pour un spike baissier prédit
    else if(predictedDirection < 0)
    {
        // Le prix a-t-il atteint ou dépassé le prix prédit ?
        if(rates[0].low <= predictedPrice || rates[1].low <= predictedPrice)
        {
            PrintFormat("? SPIKE BAISSIER RÉALISÉ - Prédit: %.5f, Atteint: %.5f",
                        predictedPrice, MathMin(rates[0].low, rates[1].low));
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Ferme toutes les positions ouvertes                              |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && positionInfo.SelectByTicket(ticket))
        {
            if(positionInfo.Magic() == InpMagicNumber)
            {
                trade.PositionClose(ticket);
                Print("Position fermée suite à la détection d'un spike");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Ferme automatiquement toutes les positions en gain après spike  |
//+------------------------------------------------------------------+
void CloseProfitablePositionsAfterSpike()
{
   int closedCount = 0;
   double totalProfit = 0.0;
   
   // Parcourir toutes les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         // Vérifier si c'est une position de notre robot
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
            double swap = PositionGetDouble(POSITION_SWAP);
            double totalPnL = profit + swap;
            
            // Déterminer le seuil de profit selon le type de symbole
            double profitThreshold = InpMinProfitDollars; // Seuil par défaut
            string symbol = PositionGetString(POSITION_SYMBOL);
            
            // Si c'est un symbole de volatilité, utiliser le seuil spécifique
            if(IsSymbolVolatility(symbol))
            {
               profitThreshold = InpVolatilityProfitTarget; // 0.30$ pour les volatilités
            }
            
            // Fermer uniquement les positions en gain dépassant le seuil
            if(totalPnL >= profitThreshold)
            {
               double volume = PositionGetDouble(POSITION_VOLUME);
               ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
               
               trade.SetExpertMagicNumber(InpMagicNumber);
               if(trade.PositionClose(ticket))
               {
                  closedCount++;
                  totalProfit += totalPnL;
                  
                  // Enregistrer le résultat pour le calcul des performances
                  // Note: La fonction RecordSignalResult n'est pas définie, nous la commentons pour l'instant
                  // RecordSignalResult(ticket, totalPnL, true, 0.0);
                  
                  // Forcer la mise à jour du panneau de performance
                  UpdatePerformancePanel();
                  
                  string symbolType = IsSymbolVolatility(symbol) ? "VOLATILITÉ" : "CLASSIQUE";
                  PrintFormat("? Position en gain fermée (%s): %s %s, Ticket: %llu, Profit: %.2f $ (seuil: %.2f $)",
                              symbolType, symbol, (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                              ticket, totalPnL, profitThreshold);
               }
               else
               {
                  PrintFormat("? Échec fermeture position: %llu, Erreur: %d", ticket, GetLastError());
               }
            }
         }
      }
   }
   
   if(closedCount > 0)
   {
      PrintFormat("?? %d position(s) en gain fermée(s) après détection du spike - Profit total: %.2f %s",
                  closedCount, totalProfit, AccountInfoString(ACCOUNT_CURRENCY));
   }
}

//+------------------------------------------------------------------+
//| Ferme toutes les positions (du robot) pour un symbole donné      |
//+------------------------------------------------------------------+
void CloseAllPositionsForSymbol(string symbol)
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
            PositionGetString(POSITION_SYMBOL) == symbol)
         {
            if(trade.PositionClose(ticket))
               closed++;
         }
      }
   }
   if(closed > 0)
      PrintFormat("?? %d position(s) fermée(s) sur %s après spike confirmé", closed, symbol);
}

//+------------------------------------------------------------------+
//| Vérifie si une position est déjà ouverte sur le compte         |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   // Vérifier d'abord les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         return true; // Position trouvée pour ce symbole et ce magic number
      }
   }
   
   // Vérifier également les ordres en attente
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == _Symbol && OrderMagicNumber() == InpMagicNumber)
         {
            return true; // Ordre en attente trouvé pour ce symbole et ce magic number
         }
      }
   }
   
   return false; // Aucune position ou ordre en attente trouvé
}

//+------------------------------------------------------------------+
//| Vérifie si le nombre de petites bougies depuis l'ouverture du trade |
//| a atteint le seuil de 10 bougies                                  |
//+------------------------------------------------------------------+
bool HasReachedCandleSL(string symbol, ENUM_TIMEFRAMES tf, double openPrice, double currentPrice, double atr)
{
   int countSmallCandles = 0;
   int maxSmallCandles = 10; // Nombre maximum de petites bougies autorisées
   static datetime lastAlertTime = 0;
   
   // Taille maximale d'une petite bougie (en ATR)
   double smallCandleSize = atr * 0.5;
   
   // Vérifier les bougies depuis l'ouverture du trade
   MqlRates rates[];
   int copied = CopyRates(symbol, tf, 0, maxSmallCandles * 2, rates);
   
   if(copied <= 0) return false;
   
   // Parcourir les bougies depuis la plus récente
   for(int i = 0; i < copied - 1; i++)
   {
      double candleSize = MathAbs(rates[i].high - rates[i].low);
      
      if(candleSize < smallCandleSize)
      {
         countSmallCandles++;
         
         // Afficher un message toutes les 10 secondes pour le suivi
         datetime currentTime = TimeCurrent();
         if(currentTime - lastAlertTime >= 10)
         {
            PrintFormat("Bougie %d/%d - Taille: %.5f (seuil: %.5f)", 
                       countSmallCandles, maxSmallCandles, candleSize, smallCandleSize);
            lastAlertTime = currentTime;
         }
         
         // Dessiner une flèche sur le graphique pour matérialiser la bougie
         string objName = StringFormat("Candle_%d_%d", i, (int)currentTime);
         if(!ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, rates[i].time, rates[i].high + 10 * _Point))
         {
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         }
         
         if(countSmallCandles >= maxSmallCandles)
         {
            PrintFormat("SL de 10 bougies atteint pour %s - Fermeture de la position", symbol);
            return true;
         }
      }
      else
      {
         countSmallCandles = 0; // Réinitialiser le compteur si on trouve une grande bougie
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Ferme une position après un mouvement de prix significatif       |
//+------------------------------------------------------------------+
bool CloseOnSpike(ulong ticket, string symbol, double currentPrice, double openPrice, double atr)
{
   if(!positionInfo.SelectByTicket(ticket))
      return false;
   
   // Calculer le mouvement depuis l'ouverture
   double priceMove = 0;
   double spikeThreshold = atr * 2.0; // Seuil de spike (2 ATR)
   static datetime lastAlertTime = 0;
   
   if(positionInfo.PositionType() == POSITION_TYPE_BUY)
   {
      priceMove = currentPrice - openPrice;
      
      // Si le prix a suffisamment monté, on ferme avec profit
      if(priceMove >= spikeThreshold)
      {
         // Vérifier si la position n'est pas déjà en cours de clôture
         if(!positionInfo.SelectByTicket(ticket) || positionInfo.Ticket() != ticket)
            return false;
            
         // Fermer la position
         if(trade.PositionClose(ticket))
         {
            PrintFormat("✅ Position #%d fermée avec succès après un spike haussier de %.2f points", ticket, priceMove);
            
            // Ajouter une flèche verte sur le graphique pour marquer la fermeture
            string objName = StringFormat("CloseBuy_%d", ticket);
            if(!ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, TimeCurrent(), currentPrice + 10 * _Point))
            {
               ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
               ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 242); // Flèche vers le bas
            }
            
            return true;
         }
         else
         {
            PrintFormat("❌ Échec de la fermeture de la position #%d. Erreur: %d", ticket, GetLastError());
            return false;
         }
      }
   }
   else if(positionInfo.PositionType() == POSITION_TYPE_SELL)
   {
      priceMove = openPrice - currentPrice;
      
      // Si le prix a suffisamment baissé, on ferme avec profit
      if(priceMove >= spikeThreshold)
      {
         // Vérifier si la position n'est pas déjà en cours de clôture
         if(!positionInfo.SelectByTicket(ticket) || positionInfo.Ticket() != ticket)
            return false;
            
         // Fermer la position
         if(trade.PositionClose(ticket))
         {
            PrintFormat("✅ Position #%d fermée avec succès après un spike baissier de %.2f points", ticket, priceMove);
            
            // Ajouter une flèche rouge sur le graphique pour marquer la fermeture
            string objName = StringFormat("CloseSell_%d", ticket);
            if(!ObjectCreate(0, objName, OBJ_ARROW_UP, 0, TimeCurrent(), currentPrice - 10 * _Point))
            {
               ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
               ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 241); // Flèche vers le haut
            }
            
            return true;
         }
         else
         {
            PrintFormat("❌ Échec de la fermeture de la position #%d. Erreur: %d", ticket, GetLastError());
            return false;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si un nouveau signal peut être traité pour un symbole    |
//+------------------------------------------------------------------+
bool CanProcessNewSignal(string symbol, ENUM_ORDER_TYPE orderType, datetime &lastSignalTime)
{
   // Vérifier le nombre total de positions ouvertes par le robot
   int totalPositions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i) && positionInfo.Magic() == InpMagicNumber)
      {
         totalPositions++;
      }
   }

   // Respecter la limite globale de positions simultanées
   if(totalPositions >= InpMaxConcurrentTrades)
   {
      static datetime lastAlert = 0;
      if(TimeCurrent() - lastAlert > 60) // Afficher le message maximum toutes les minutes
      {
         PrintFormat("❌ Limite de %d positions atteinte - Impossible d'ouvrir un nouveau trade", InpMaxConcurrentTrades);
         lastAlert = TimeCurrent();
      }
      return false;
   }
   
   // Vérifier si un trade est déjà ouvert sur ce symbole
   ulong existingTicket = 0;
   if(IsTradeOpenForSymbol(symbol, existingTicket))
   {
      // Si un trade est déjà ouvert sur ce symbole, ne pas en ouvrir un nouveau
      PrintFormat("❌ Trade déjà ouvert sur %s - Un seul trade par symbole autorisé", symbol);
      return false;
   }
   
   // Vérifier le temps écoulé depuis le dernier signal
   datetime currentTime = TimeCurrent();
   if(lastSignalTime > 0 && currentTime - lastSignalTime < 60) // 1 minute entre les signaux
   {
      PrintFormat("?? Attente de 1 minute entre les signaux pour %s", symbol);
      return false;
   }
   
   // Mettre à jour le temps du dernier signal
   lastSignalTime = currentTime;
   return true;
}

//+------------------------------------------------------------------+
//| Traite un nouveau signal de trading                              |
//+------------------------------------------------------------------+
void ProcessNewSignal(string symbol, ENUM_ORDER_TYPE orderType, double price, double sl, double tp, double lotSize)
{
   // Vérifier si on peut traiter ce nouveau signal
   static datetime lastSignalTime = 0;
   if(!CanProcessNewSignal(symbol, orderType, lastSignalTime))
      return;
   
   // Préparer la requête de trading
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   // Exécuter l'ordre
   if(orderType == ORDER_TYPE_BUY)
   {
      if(trade.Buy(lotSize, symbol, 0, sl, tp, "Signal d'achat - Spike détecté"))
      {
         PrintFormat("? ACHAT exécuté sur %s - Lot: %.2f, Prix: %.5f, SL: %.5f, TP: %.5f",
                    symbol, lotSize, price, sl, tp);
      }
      else
      {
         PrintFormat("? Échec ACHAT sur %s - Erreur: %d", symbol, GetLastError());
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(trade.Sell(lotSize, symbol, 0, sl, tp, "Signal de vente - Spike détecté"))
      {
         PrintFormat("? VENTE exécutée sur %s - Lot: %.2f, Prix: %.5f, SL: %.5f, TP: %.5f",
                    symbol, lotSize, price, sl, tp);
      }
      else
      {
         PrintFormat("? Échec VENTE sur %s - Erreur: %d", symbol, GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Met à jour les zones d'entrée sur le graphique                   |
//+------------------------------------------------------------------+
void UpdateZones(string symbol, ENUM_TIMEFRAMES timeframe)
{
   // Mettre à jour les zones toutes les 10 secondes maximum
   if(TimeCurrent() - lastZoneUpdate < 10) return;
   
   // Obtenir les données ATR
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   int atr_handle = iATR(symbol, timeframe, InpZoneATRPeriod);
   if(CopyBuffer(atr_handle, 0, 0, 1, atrBuffer) <= 0) return;
   
   double atr = atrBuffer[0];
   double zoneSize = atr * InpZoneMultiplier;
   
   // Supprimer les anciennes zones
   for(int i = 0; i < 3; i++)
   {
      if(zoneNames[i] != "")
         ObjectDelete(0, zoneNames[i]);
   }
   
   // Réinitialiser le compteur de zones
   zoneCount = 0;
   
   // Ajouter une zone d'achat (niveau de support)
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   // Zone d'achat (support)
   string buyZoneName = StringFormat("BuyZone_%s", symbol);
   zoneNames[zoneCount] = buyZoneName;
   zoneHigh[zoneCount] = bid + zoneSize;
   zoneLow[zoneCount] = bid - zoneSize;
   zoneType[zoneCount] = POSITION_TYPE_BUY;
   
   ObjectCreate(0, buyZoneName, OBJ_RECTANGLE, 0, TimeCurrent() - PeriodSeconds(timeframe) * 50, zoneHigh[zoneCount], 
               TimeCurrent() + PeriodSeconds(timeframe) * 100, zoneLow[zoneCount]);
   ObjectSetInteger(0, buyZoneName, OBJPROP_COLOR, InpZoneBuyColor);
   ObjectSetInteger(0, buyZoneName, OBJPROP_WIDTH, InpZoneWidth);
   ObjectSetInteger(0, buyZoneName, OBJPROP_STYLE, InpZoneStyle);
   ObjectSetInteger(0, buyZoneName, OBJPROP_BACK, true);
   ObjectSetInteger(0, buyZoneName, OBJPROP_FILL, true);
   ObjectSetInteger(0, buyZoneName, OBJPROP_BGCOLOR, InpZoneBuyColor);
   ObjectSetInteger(0, buyZoneName, OBJPROP_BACK, false);
   ObjectSetInteger(0, buyZoneName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, buyZoneName, OBJPROP_HIDDEN, true);
   
   // Ajuster l'opacité
   color bgColor = (color)ObjectGetInteger(0, buyZoneName, OBJPROP_BGCOLOR);
   ObjectSetInteger(0, buyZoneName, OBJPROP_BGCOLOR, ColorToARGB(bgColor, (uchar)InpZoneOpacity));
   
   zoneCount++;
   
   // Zone de vente (résistance)
   string sellZoneName = StringFormat("SellZone_%s", symbol);
   zoneNames[zoneCount] = sellZoneName;
   zoneHigh[zoneCount] = ask + zoneSize;
   zoneLow[zoneCount] = ask - zoneSize;
   zoneType[zoneCount] = POSITION_TYPE_SELL;
   
   ObjectCreate(0, sellZoneName, OBJ_RECTANGLE, 0, TimeCurrent() - PeriodSeconds(timeframe) * 50, zoneHigh[zoneCount], 
               TimeCurrent() + PeriodSeconds(timeframe) * 100, zoneLow[zoneCount]);
   ObjectSetInteger(0, sellZoneName, OBJPROP_COLOR, InpZoneSellColor);
   ObjectSetInteger(0, sellZoneName, OBJPROP_WIDTH, InpZoneWidth);
   ObjectSetInteger(0, sellZoneName, OBJPROP_STYLE, InpZoneStyle);
   ObjectSetInteger(0, sellZoneName, OBJPROP_BACK, true);
   ObjectSetInteger(0, sellZoneName, OBJPROP_FILL, true);
   ObjectSetInteger(0, sellZoneName, OBJPROP_BGCOLOR, InpZoneSellColor);
   ObjectSetInteger(0, sellZoneName, OBJPROP_BACK, false);
   ObjectSetInteger(0, sellZoneName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, sellZoneName, OBJPROP_HIDDEN, true);
   
   // Ajuster l'opacité
   bgColor = (color)ObjectGetInteger(0, sellZoneName, OBJPROP_BGCOLOR);
   ObjectSetInteger(0, sellZoneName, OBJPROP_BGCOLOR, ColorToARGB(bgColor, (uchar)InpZoneOpacity));
   
   zoneCount++;
   
   // Mettre à jour l'horodatage de la dernière mise à jour
   lastZoneUpdate = TimeCurrent();
   
   // Afficher un message de débogage
   PrintFormat("Zones mises à jour - Achat: [%.5f - %.5f], Vente: [%.5f - %.5f]", 
               zoneLow[0], zoneHigh[0], zoneLow[1], zoneHigh[1]);
}

//+------------------------------------------------------------------+
//| Vérifie si le prix est dans une zone d'entrée                    |
//+------------------------------------------------------------------+
bool IsInEntryZone(string symbol, double price, ENUM_POSITION_TYPE &zoneTypeOut)
{
   for(int i = 0; i < zoneCount; i++)
   {
      if(price >= zoneLow[i] && price <= zoneHigh[i])
      {
         zoneTypeOut = zoneType[i];
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| STRUCTURES POUR NOUVELLE STRATÉGIE SPIKE MULTI-SYMBOLES          |
//+------------------------------------------------------------------+

// Structure pour stocker les informations d'opportunité de spike par symbole
struct SpikeOpportunity
{
   string symbol;
   double score;              // Score d'opportunité (plus élevé = meilleur)
   bool isBoom;               // true = Boom, false = Crash
   int globalTrend;           // 1 = haussier, -1 = baissier, 0 = neutre
   bool h1Confirmed;          // Tendance H1 confirmée
   bool m5MA30Ready;          // Prêt pour entrée M5 (prix proche MA30)
   datetime lastScanTime;     // Dernière fois que ce symbole a été scanné
};

// Structure pour tracker les positions M1 scalping
struct M1ScalpPosition
{
   string symbol;
   ulong ticket;
   ENUM_POSITION_TYPE type;   // POSITION_TYPE_BUY ou POSITION_TYPE_SELL
   datetime openTime;
   double openPrice;
   int candleCount;            // Nombre de bougies depuis ouverture (pour SL 10 bougies)
   bool spikeCaptured;         // Spike capturé
};

// Tableaux globaux pour la nouvelle stratégie
SpikeOpportunity g_spikeOpportunities[];
M1ScalpPosition g_m1Positions[];
int g_activeSymbolCount = 0;  // Nombre de symboles actifs (max 2)

//+------------------------------------------------------------------+
//| Scanne tous les symboles attachés aux graphiques MT5            |
//+------------------------------------------------------------------+
void ScanAllChartSymbols(string &symbols[])
{
   ArrayResize(symbols, 0);
   
   // Obtenir tous les symboles du Market Watch
   int totalSymbols = SymbolsTotal(true);
   
   Print("🔍 Scan de tous les symboles attachés aux graphiques MT5...");
   
   for(int i = 0; i < totalSymbols; i++)
   {
      string symbolName = SymbolName(i, true);
      
      // Vérifier si c'est un symbole Boom ou Crash
      if(StringFind(symbolName, "Boom", 0) >= 0 || StringFind(symbolName, "Crash", 0) >= 0)
      {
         // Vérifier que le symbole est tradable
         if(SymbolSelect(symbolName, true))
         {
            int size = ArraySize(symbols);
            ArrayResize(symbols, size + 1);
            symbols[size] = symbolName;
            PrintFormat("✅ Symbole détecté: %s", symbolName);
         }
      }
   }
   
   PrintFormat("📊 Total symboles Boom/Crash trouvés: %d", ArraySize(symbols));
}

//+------------------------------------------------------------------+
//| Calcule le score d'opportunité de spike pour un symbole          |
//+------------------------------------------------------------------+
double CalculateSpikeOpportunityScore(string symbol)
{
   double score = 0.0;
   
   // Obtenir les données de prix récentes
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Analyser sur M5 pour détecter la volatilité
   if(CopyRates(symbol, PERIOD_M5, 0, 50, rates) < 50) return 0.0;
   
   // Calculer la volatilité récente (ATR)
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   int atrHandle = iATR(symbol, PERIOD_M5, 14);
   if(atrHandle == INVALID_HANDLE || CopyBuffer(atrHandle, 0, 0, 20, atrBuffer) < 20)
   {
      IndicatorRelease(atrHandle);
      return 0.0;
   }
   
   double currentATR = atrBuffer[0];
   double avgATR = 0;
   for(int i = 0; i < 20; i++) avgATR += atrBuffer[i];
   avgATR /= 20.0;
   
   // Score basé sur volatilité élevée
   if(currentATR > 0 && avgATR > 0)
   {
      double volatilityRatio = currentATR / avgATR;
      score += volatilityRatio * 30.0; // Max 30 points pour volatilité
   }
   
   // Analyser les mouvements récents (spikes potentiels)
   double maxMove = 0;
   for(int i = 0; i < 10; i++)
   {
      double move = MathAbs(rates[i].close - rates[i].open);
      if(move > maxMove) maxMove = move;
   }
   
   if(currentATR > 0)
   {
      double moveRatio = maxMove / currentATR;
      score += moveRatio * 20.0; // Max 20 points pour mouvements
   }
   
   // Analyser le volume (si disponible)
   long volumes[];
   ArraySetAsSeries(volumes, true);
   if(CopyTickVolume(symbol, PERIOD_M5, 0, 20, volumes) >= 20)
   {
      long currentVol = volumes[0];
      long avgVol = 0;
      for(int i = 1; i < 20; i++) avgVol += volumes[i];
      avgVol /= 19;
      
      if(avgVol > 0)
      {
         double volumeRatio = (double)currentVol / (double)avgVol;
         score += volumeRatio * 25.0; // Max 25 points pour volume
      }
   }
   
   // Bonus pour symboles Boom/Crash (plus volatils)
   if(StringFind(symbol, "Boom", 0) >= 0 || StringFind(symbol, "Crash", 0) >= 0)
   {
      score += 25.0; // Bonus 25 points
   }
   
   IndicatorRelease(atrHandle);
   return score;
}

//+------------------------------------------------------------------+
//| Trouve les 2 meilleurs symboles avec opportunités de spike        |
//+------------------------------------------------------------------+
void FindTopSpikeOpportunities(SpikeOpportunity &topOpportunities[])
{
   ArrayResize(topOpportunities, 0);
   
   // Scanner tous les symboles
   string allSymbols[];
   ScanAllChartSymbols(allSymbols);
   
   if(ArraySize(allSymbols) == 0) return;
   
   // Calculer le score pour chaque symbole
   SpikeOpportunity opportunities[];
   ArrayResize(opportunities, ArraySize(allSymbols));
   
   for(int i = 0; i < ArraySize(allSymbols); i++)
   {
      opportunities[i].symbol = allSymbols[i];
      opportunities[i].score = CalculateSpikeOpportunityScore(allSymbols[i]);
      opportunities[i].isBoom = (StringFind(allSymbols[i], "Boom", 0) >= 0);
      opportunities[i].lastScanTime = TimeCurrent();
   }
   
   // Trier par score décroissant
   for(int i = 0; i < ArraySize(opportunities) - 1; i++)
   {
      for(int j = i + 1; j < ArraySize(opportunities); j++)
      {
         if(opportunities[j].score > opportunities[i].score)
         {
            SpikeOpportunity temp = opportunities[i];
            opportunities[i] = opportunities[j];
            opportunities[j] = temp;
         }
      }
   }
   
   // Prendre les 2 meilleurs
   int count = MathMin(InpMaxSymbolsToTrade, ArraySize(opportunities));
   ArrayResize(topOpportunities, count);
   
   for(int i = 0; i < count; i++)
   {
      topOpportunities[i] = opportunities[i];
      PrintFormat("🏆 Top %d: %s (Score: %.2f)", i+1, opportunities[i].symbol, opportunities[i].score);
   }
}

//+------------------------------------------------------------------+
//| Vérifie la tendance globale sur un timeframe supérieur            |
//+------------------------------------------------------------------+
int CheckGlobalTrend(string symbol, ENUM_TIMEFRAMES tf)
{
   // Utiliser MA50 et MA200 pour déterminer la tendance
   int ma50Handle = iMA(symbol, tf, 50, 0, MODE_EMA, PRICE_CLOSE);
   int ma200Handle = iMA(symbol, tf, 200, 0, MODE_EMA, PRICE_CLOSE);
   
   if(ma50Handle == INVALID_HANDLE || ma200Handle == INVALID_HANDLE)
   {
      if(ma50Handle != INVALID_HANDLE) IndicatorRelease(ma50Handle);
      if(ma200Handle != INVALID_HANDLE) IndicatorRelease(ma200Handle);
      return 0;
   }
   
   double ma50[], ma200[];
   ArraySetAsSeries(ma50, true);
   ArraySetAsSeries(ma200, true);
   
   if(CopyBuffer(ma50Handle, 0, 0, 3, ma50) < 3 || CopyBuffer(ma200Handle, 0, 0, 3, ma200) < 3)
   {
      IndicatorRelease(ma50Handle);
      IndicatorRelease(ma200Handle);
      return 0;
   }
   
   IndicatorRelease(ma50Handle);
   IndicatorRelease(ma200Handle);
   
   // Tendance haussière: MA50 > MA200 et MA50 monte
   if(ma50[0] > ma200[0] && ma50[0] > ma50[1])
      return 1;
   
   // Tendance baissière: MA50 < MA200 et MA50 descend
   if(ma50[0] < ma200[0] && ma50[0] < ma50[1])
      return -1;
   
   return 0; // Neutre
}

//+------------------------------------------------------------------+
//| Vérifie la tendance H1                                           |
//+------------------------------------------------------------------+
bool CheckH1Trend(string symbol, int expectedTrend)
{
   int h1Trend = CheckGlobalTrend(symbol, PERIOD_H1);
   return (h1Trend == expectedTrend);
}

//+------------------------------------------------------------------+
//| Vérifie si le prix touche MA30 sur M5                            |
//+------------------------------------------------------------------+
bool CheckM5MA30Touch(string symbol, bool isBoom)
{
   int ma30Handle = iMA(symbol, PERIOD_M5, InpMA30Period, 0, MODE_EMA, PRICE_CLOSE);
   if(ma30Handle == INVALID_HANDLE) return false;
   
   double ma30[];
   ArraySetAsSeries(ma30, true);
   if(CopyBuffer(ma30Handle, 0, 0, 1, ma30) < 1)
   {
      IndicatorRelease(ma30Handle);
      return false;
   }
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double atr = GetCurrentATR(symbol);
   if(atr <= 0)
   {
      IndicatorRelease(ma30Handle);
      return false;
   }
   
   double touchDistance = atr * InpMATouchDistance;
   bool isTouching = (MathAbs(currentPrice - ma30[0]) <= touchDistance);
   
   IndicatorRelease(ma30Handle);
   
   // Pour Boom: prix doit être proche ou au-dessus de MA30
   // Pour Crash: prix doit être proche ou en-dessous de MA30
   if(isBoom)
      return isTouching && (currentPrice >= ma30[0] - touchDistance);
   else
      return isTouching && (currentPrice <= ma30[0] + touchDistance);
}

//+------------------------------------------------------------------+
//| Vérifie si le prix touche MA10 sur M1                            |
//+------------------------------------------------------------------+
bool CheckM1MA10Touch(string symbol, bool isBoom)
{
   int ma10Handle = iMA(symbol, PERIOD_M1, InpMA10Period, 0, MODE_EMA, PRICE_CLOSE);
   if(ma10Handle == INVALID_HANDLE) return false;
   
   double ma10[];
   ArraySetAsSeries(ma10, true);
   if(CopyBuffer(ma10Handle, 0, 0, 1, ma10) < 1)
   {
      IndicatorRelease(ma10Handle);
      return false;
   }
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double atr = GetCurrentATR(symbol);
   if(atr <= 0)
   {
      IndicatorRelease(ma10Handle);
      return false;
   }
   
   double touchDistance = atr * InpMATouchDistance;
   bool isTouching = (MathAbs(currentPrice - ma10[0]) <= touchDistance);
   
   IndicatorRelease(ma10Handle);
   
   // Pour Boom: prix doit être proche ou au-dessus de MA10
   // Pour Crash: prix doit être proche ou en-dessous de MA10
   if(isBoom)
      return isTouching && (currentPrice >= ma10[0] - touchDistance);
   else
      return isTouching && (currentPrice <= ma10[0] + touchDistance);
}

//+------------------------------------------------------------------+
//| Obtient le nombre de positions actives pour un symbole           |
//+------------------------------------------------------------------+
int GetPositionCountForSymbol(string symbol)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() == symbol && positionInfo.Magic() == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Obtient le nombre total de positions actives                     |
//+------------------------------------------------------------------+
int GetTotalActivePositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Magic() == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Vérifie si une position a atteint le SL de 10 bougies            |
//+------------------------------------------------------------------+
bool HasReachedCandleStopLoss(ulong ticket, string symbol, ENUM_TIMEFRAMES tf)
{
   if(!positionInfo.SelectByTicket(ticket)) return false;
   
   datetime openTime = positionInfo.Time();
   double openPrice = positionInfo.PriceOpen();
   double currentPrice = positionInfo.PriceCurrent();
   
   // Compter toutes les bougies depuis l'ouverture (pas seulement les petites)
   int barsSinceOpen = 0;
   int totalBars = iBars(symbol, tf);
   int openBarIndex = iBarShift(symbol, tf, openTime);
   
   if(openBarIndex < 0) openBarIndex = totalBars;
   
   // Nombre de bougies depuis l'ouverture
   barsSinceOpen = totalBars - openBarIndex;
   
   // Si 10 bougies ou plus se sont écoulées depuis l'ouverture
   if(barsSinceOpen >= InpStopLossCandles)
   {
      // Vérifier si le spike (SPAC) est arrivé (profit atteint)
      double profit = positionInfo.Profit();
      bool spikeArrived = (profit >= InpSpikeCaptureProfit);
      
      if(!spikeArrived)
      {
         // 10 bougies passées et le spike n'est pas arrivé -> fermer la position
         PrintFormat("⏰ Position #%llu - 10 bougies passées sans spike (profit: %.2f) - Fermeture", 
                     ticket, profit);
         return true;
      }
      else
      {
         // Le spike est arrivé, on garde la position ouverte
         PrintFormat("✅ Position #%llu - 10 bougies passées MAIS spike arrivé (profit: %.2f) - Position maintenue", 
                     ticket, profit);
         return false;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si un spike a été capturé (profit minimum atteint)       |
//+------------------------------------------------------------------+
bool IsSpikeCaptured(ulong ticket)
{
   if(!positionInfo.SelectByTicket(ticket)) return false;
   
   double profit = positionInfo.Profit();
   return (profit >= InpSpikeCaptureProfit);
}

//+------------------------------------------------------------------+
//| Prend une position M1 scalping                                    |
//+------------------------------------------------------------------+
bool TakeM1ScalpPosition(string symbol, bool isBoom)
{
   // Vérifier le nombre total de positions
   if(GetTotalActivePositions() >= InpMaxSymbolsToTrade)
   {
      Print("❌ Nombre maximum de positions atteint (", InpMaxSymbolsToTrade, ")");
      return false;
   }
   
   // Vérifier le nombre de positions pour ce symbole
   if(GetPositionCountForSymbol(symbol) >= InpMaxPositionsPerSymbol)
   {
      PrintFormat("❌ Nombre maximum de positions pour %s atteint (%d)", symbol, InpMaxPositionsPerSymbol);
      return false;
   }
   
   // Calculer le lot
   double lotSize = InpLotFixed;
   if(lotSize <= 0)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * (InpRiskPerTrade / 100.0);
      double atr = GetCurrentATR(symbol);
      if(atr > 0)
      {
         double slDistance = atr * 1.5; // SL à 1.5 ATR
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         if(tickValue > 0)
         {
            lotSize = riskAmount / (slDistance / SymbolInfoDouble(symbol, SYMBOL_POINT) * tickValue);
            lotSize = MathFloor(lotSize / SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE)) * SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
            if(lotSize < SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN))
               lotSize = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            if(lotSize > SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX))
               lotSize = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
         }
      }
   }
   
   if(lotSize <= 0) lotSize = 0.01;
   
   // Calculer SL et TP
   double price = isBoom ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   double atr = GetCurrentATR(symbol);
   if(atr <= 0) atr = price * 0.001; // Fallback
   
   double sl, tp;
   if(isBoom)
   {
      sl = price - atr * 1.5;
      tp = price + atr * 2.0;
   }
   else
   {
      sl = price + atr * 1.5;
      tp = price - atr * 2.0;
   }
   
   // Normaliser les prix
   sl = NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   tp = NormalizeDouble(tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   
   // Ouvrir la position
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   bool result = false;
   if(isBoom)
      result = trade.Buy(lotSize, symbol, price, sl, tp, "M1 Scalp Boom");
   else
      result = trade.Sell(lotSize, symbol, price, sl, tp, "M1 Scalp Crash");
   
   if(result)
   {
      PrintFormat("✅ Position M1 ouverte: %s %s @ %.5f (SL: %.5f, TP: %.5f)", 
                  symbol, isBoom ? "BUY" : "SELL", price, sl, tp);
      return true;
   }
   else
   {
      PrintFormat("❌ Échec ouverture position M1: %s (Erreur: %d)", symbol, GetLastError());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Gère les positions M1 scalping (fermeture sur spike ou SL)       |
//+------------------------------------------------------------------+
void ManageM1ScalpPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Magic() != InpMagicNumber) continue;
         
         string symbol = positionInfo.Symbol();
         ulong ticket = positionInfo.Ticket();
         
         // Vérifier SL de 10 bougies
         if(HasReachedCandleStopLoss(ticket, symbol, PERIOD_M1))
         {
            trade.PositionClose(ticket);
            PrintFormat("🛑 Position #%llu fermée - SL 10 bougies atteint", ticket);
            continue;
         }
         
         // Vérifier si spike capturé
         if(IsSpikeCaptured(ticket))
         {
            trade.PositionClose(ticket);
            PrintFormat("🎯 Position #%llu fermée - Spike capturé (Profit: %.2f)", 
                       ticket, positionInfo.Profit());
            continue;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Exécute la nouvelle stratégie spike multi-symboles               |
//+------------------------------------------------------------------+
void ExecuteNewSpikeStrategy()
{
   if(!InpEnableNewSpikeStrategy) return;
   
   // 1. Gérer les positions existantes (fermer sur spike ou SL 10 bougies)
   ManageM1ScalpPositions();
   
   // 2. BLOQUER TOUS LES MULTIPLES TRADES - Maximum 2 positions totales
   int totalPositions = GetTotalActivePositions();
   if(totalPositions >= InpMaxSymbolsToTrade)
   {
      // Si on a déjà 2 positions, attendre qu'elles se ferment (spike ou SL)
      // Ne pas chercher de nouvelles opportunités
      return;
   }
   
   // 3. Trouver les meilleures opportunités (max 2 symboles)
   SpikeOpportunity topOpportunities[];
   FindTopSpikeOpportunities(topOpportunities);
   
   if(ArraySize(topOpportunities) == 0) return;
   
   // 4. Traiter chaque opportunité (max 2 symboles, max 2 positions totales)
   for(int i = 0; i < ArraySize(topOpportunities) && GetTotalActivePositions() < InpMaxSymbolsToTrade; i++)
   {
      // Accéder directement à l'élément du tableau (pas de référence en MQL5)
      string symbol = topOpportunities[i].symbol;
      bool isBoom = topOpportunities[i].isBoom;
      
      // Vérifier qu'on n'a pas déjà une position pour ce symbole
      // (on veut max 1 symbole à la fois pour éviter la surcharge)
      if(GetPositionCountForSymbol(symbol) > 0)
      {
         // Si on a déjà une position pour ce symbole, continuer avec le prochain
         continue;
      }
      
      // Vérifier la tendance globale
      int globalTrend = CheckGlobalTrend(symbol, InpGlobalTrendTF);
      if(globalTrend == 0) continue; // Pas de tendance claire
      
      // Pour Boom: tendance doit être haussière
      // Pour Crash: tendance doit être baissière
      if(isBoom && globalTrend != 1) continue;
      if(!isBoom && globalTrend != -1) continue;
      
      topOpportunities[i].globalTrend = globalTrend;
      
      // Vérifier H1 - la tendance H1 doit confirmer la tendance globale
      if(!CheckH1Trend(symbol, globalTrend)) continue;
      topOpportunities[i].h1Confirmed = true;
      
      // Vérifier M5 MA30 touch - le prix doit toucher MA30 sur M5
      if(!CheckM5MA30Touch(symbol, isBoom)) continue;
      topOpportunities[i].m5MA30Ready = true;
      
      // Vérifier M1 MA10 touch et prendre position
      // Le robot prend 2-3 positions quand le prix touche MA10 plusieurs fois
      if(CheckM1MA10Touch(symbol, isBoom))
      {
         // Vérifier qu'on n'a pas déjà atteint la limite de positions (MAX 2)
         if(GetTotalActivePositions() >= InpMaxSymbolsToTrade)
         {
            Print("❌ Limite de positions atteinte (2 max) - Signal rejeté");
            return; // Rejeter le signal - BLOQUER LE 3ÈME TRADE
         }
         
         // Pour chaque symbole, on peut prendre 2-3 positions scalping
         // mais le total ne doit jamais dépasser 2 positions
         int currentPositionsForSymbol = GetPositionCountForSymbol(symbol);
         int totalPositions = GetTotalActivePositions();
         
         // Si on a déjà 2 positions totales, ne pas prendre de nouvelle position
         if(totalPositions >= InpMaxSymbolsToTrade)
         {
            Print("❌ Maximum 2 positions atteint - Attendre fermeture avant nouveau trade");
            return;
         }
         
         // Si on peut prendre une position (total < 2)
         if(totalPositions < InpMaxSymbolsToTrade && currentPositionsForSymbol < InpMaxPositionsPerSymbol)
         {
            if(TakeM1ScalpPosition(symbol, isBoom))
            {
               PrintFormat("🎯 Position M1 scalping #%d ouverte pour %s (Total: %d/%d)", 
                          currentPositionsForSymbol + 1, symbol, GetTotalActivePositions(), InpMaxSymbolsToTrade);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // ========== EXÉCUTION AUTOMATIQUE IMMÉDIATE (Robot 3) ==========
   // Exécuter automatiquement les trades quand le prix touche l'EMA 10
   if(InpEnableTrading)
   {
      ExecuteAutoTradeStrategy();
   }
   
   // ========== NOUVELLE STRATÉGIE SPIKE MULTI-SYMBOLES (PRINCIPALE) ==========
   // Cette stratégie est maintenant la stratégie principale
   ExecuteNewSpikeStrategy();
   
   // Si la nouvelle stratégie est activée, ne pas exécuter l'ancienne stratégie
   if(InpEnableNewSpikeStrategy)
   {
      return; // Sortir tôt pour éviter l'exécution de l'ancienne stratégie
   }
   
   // ========== ANCIENNE STRATÉGIE (désactivée si nouvelle stratégie active) ==========
   // Mettre à jour les zones d'entrée
   UpdateZones(_Symbol, (ENUM_TIMEFRAMES)Period());
   
   // Vérifier d'abord les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         string symbol = positionInfo.Symbol();
         ulong ticket = positionInfo.Ticket();
         double openPrice = positionInfo.PriceOpen();
         double currentPrice = positionInfo.PriceCurrent();
         
         // Calculer l'ATR pour ce symbole
         double atrBuffer[];
         ArraySetAsSeries(atrBuffer, true);
         int atr_handle = iATR(symbol, InpSpikeTimeframe, InpATR_Period);
         if(CopyBuffer(atr_handle, 0, 0, 1, atrBuffer) <= 0) continue;
         double atr = atrBuffer[0];
         
         // Vérifier si on doit fermer la position à cause du SL des 10 bougies
         if(HasReachedCandleSL(symbol, InpSpikeTimeframe, openPrice, currentPrice, atr))
         {
            trade.PositionClose(ticket);
            PrintFormat("Position #%d fermée - SL de 10 petites bougies atteint", ticket);
            continue;
         }
         
         // Vérifier si on doit fermer à cause d'un spike de prix
         CloseOnSpike(ticket, symbol, currentPrice, openPrice, atr);
      }
   }
   Print("Fx_robot_pred_v3.0 - Initialisation...");
   
   // DÉTECTER AUTOMATIQUEMENT TOUS LES SYMBOLES BOOM/CRASH DISPONIBLES
   AutoDetectBoomCrashSymbols();
   
   // Initialisation des poignées d'indicateurs
   g_atr_handle = iATR(_Symbol, InpSpikeTimeframe, InpATR_Period);
   g_ma20_handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
   g_ma50_handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
   g_short_atr_handle = iATR(_Symbol, InpSpikeTimeframe, 14);
   g_long_atr_handle = iATR(_Symbol, InpSpikeTimeframe, 100);
   
   // Initialisation des variables de suivi journalier
   g_lastDayChecked = TimeCurrent();
   g_dailyStartingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_maxDailyDrawdown = g_dailyStartingBalance * (InpDailyDrawdownPercent / 100.0);
   
   // Initialiser les handles d'indicateurs pour tous les symboles surveillés
   // Version sécurisée qui ne bloque pas l'initialisation
   InitializeAllSymbolHandles();
   
   // Vérification de l'initialisation des indicateurs principaux seulement
   if(g_atr_handle == INVALID_HANDLE)
   {
      Print("ERREUR: Impossible de créer l'handle ATR principal");
      return;
   }
   
   // Timer pour vérifier nouvelle bougie (1s)
   if(!EventSetTimer(1))
   {
      Print("ERREUR: Impossible de créer le timer");
      return;
   }
   
   // Nettoyer visuels précédents liés à ce EA sur ce graphique
   if(InpShowVisuals) DeleteAllEAObjects();
   
   Print("Initialisation terminée avec succès - Robot prêt");
   return;
}

//+------------------------------------------------------------------+
//| ========== SYSTÈME D'APPRENTISSAGE ADAPTATIF ==========          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Enregistre un signal avec ses caractéristiques                   |
//+------------------------------------------------------------------+
void RecordSignalFeatures(string symbol, int direction, double confidence, double entryPrice, 
                         double sl, double tp, int signalType = 0, int signalCount = 1)
{
   // Limiter la taille de l'historique à 1000 entrées
   if(g_signalHistoryCount >= 1000)
   {
      // Décaler les entrées (FIFO)
      for(int i = 0; i < 999; i++)
         g_signalHistory[i] = g_signalHistory[i+1];
      g_signalHistoryCount = 999;
   }
   
   // Obtenir les caractéristiques actuelles du marché
   ENUM_TIMEFRAMES tf = InpSpikeTimeframe;
   
   // Calculer les statistiques du marché (simplifié - valeurs par défaut si non disponibles)
   MarketStats stats;
   stats.zscore_current = 0;
   stats.skewness = 0;
   stats.kurtosis = 0;
   
   // Essayer de calculer les stats si possible (sera amélioré plus tard)
   // Pour l'instant, utiliser des valeurs par défaut
   
   // Détecter les patterns
   bool scissor = InpEnableScissorDetection ? DetectScissorPattern(symbol, tf, 20) : false;
   bool fractal = InpEnableFractalDetection ? DetectFractalSpike(symbol, tf, 1.2) : false;
   bool hammer = DetectHammerPattern(symbol, tf);
   bool engulfing = DetectEngulfingPattern(symbol, tf);
   bool gap = DetectPriceGap(symbol, tf);
   bool bbBreakout = DetectBollingerBreakout(symbol, tf);
   
   // Calculer les ratios
   double volumeRatio = 1.0;
   double current_volume = (double)iVolume(symbol, tf, 0);
   double volume_ma[];
   ArraySetAsSeries(volume_ma, true);
   int volume_handle = iMA(symbol, tf, 20, 0, MODE_SMA, VOLUME_TICK);
   if(volume_handle != INVALID_HANDLE && CopyBuffer(volume_handle, 0, 0, 1, volume_ma) > 0)
      volumeRatio = (volume_ma[0] > 0) ? current_volume / volume_ma[0] : 1.0;
   IndicatorRelease(volume_handle);
   
   double atrRatio = 1.0;
   double current_atr = GetCurrentATR(symbol);
   if(current_atr > 0)
   {
      double atr_ma[];
      ArraySetAsSeries(atr_ma, true);
      int atr_ma_handle = iMA(symbol, tf, 20, 0, MODE_SMA, PRICE_CLOSE);
      if(atr_ma_handle != INVALID_HANDLE && CopyBuffer(atr_ma_handle, 0, 0, 20, atr_ma) > 0)
      {
         double avg_atr = 0;
         for(int i = 0; i < 20; i++) avg_atr += atr_ma[i];
         avg_atr /= 20;
         atrRatio = (avg_atr > 0) ? current_atr / avg_atr : 1.0;
      }
      IndicatorRelease(atr_ma_handle);
   }
   
   // Créer l'entrée
   SignalFeatures features;
   features.timestamp = TimeCurrent();
   features.symbol = symbol;
   features.direction = direction;
   features.confidence = confidence;
   features.zscore = stats.zscore_current;
   features.skewness = stats.skewness;
   features.kurtosis = stats.kurtosis;
   features.volumeRatio = volumeRatio;
   features.atrRatio = atrRatio;
   features.hasScissorPattern = scissor;
   features.hasFractalPattern = fractal;
   features.hasHammerPattern = hammer;
   features.hasEngulfingPattern = engulfing;
   features.hasGap = gap;
   features.hasBBBreakout = bbBreakout;
   features.entryPrice = entryPrice;
   features.stopLoss = sl;
   features.takeProfit = tp;
   features.signalType = signalType;
   features.signalCount = signalCount;
   
   // Ajouter à l'historique
   ArrayResize(g_signalHistory, g_signalHistoryCount + 1);
   g_signalHistory[g_signalHistoryCount] = features;
   g_signalHistoryCount++;
}

//+------------------------------------------------------------------+
//| Enregistre le résultat d'un signal (appelé quand position fermée)|
//+------------------------------------------------------------------+
void RecordSignalResult(ulong ticket, double profit, bool spikeCaptured = false, double spikeMagnitude = 0.0)
{
   // Trouver le signal correspondant dans l'historique
   // On cherche le signal le plus récent qui correspond à ce ticket
   int signalIdx = -1;
   datetime signalTime = 0;
   
   // Parcourir l'historique des résultats pour trouver le ticket
   for(int i = g_resultHistoryCount - 1; i >= 0; i--)
   {
      if(g_resultHistory[i].ticket == ticket)
      {
         // Mettre à jour le résultat existant
         g_resultHistory[i].profit = profit;
         g_resultHistory[i].spikeCaptured = spikeCaptured;
         g_resultHistory[i].spikeMagnitude = spikeMagnitude;
         g_resultHistory[i].closeTime = TimeCurrent();
         return;
      }
   }
   
   // Si pas trouvé, chercher dans l'historique des signaux le plus récent
   for(int i = g_signalHistoryCount - 1; i >= 0; i--)
   {
      // Vérifier si ce signal a été exécuté récemment (dans les 4 dernières minutes)
      if(TimeCurrent() - g_signalHistory[i].timestamp < 240)
      {
         signalIdx = i;
         signalTime = g_signalHistory[i].timestamp;
         break;
      }
   }
   
   if(signalIdx < 0) return; // Pas de signal correspondant trouvé
   
   // Créer le résultat
   SignalResult result;
   result.signalTime = signalTime;
   result.symbol = g_signalHistory[signalIdx].symbol;
   result.ticket = ticket;
   result.profit = profit;
   result.spikeCaptured = spikeCaptured;
   result.spikeMagnitude = spikeMagnitude;
   result.reachedTP = (profit > 0 && spikeCaptured); // Approximation
   result.hitSL = (profit < 0); // Approximation
   result.closeTime = TimeCurrent();
   result.maxProfit = (profit > 0) ? profit : 0;
   result.maxDrawdown = (profit < 0) ? MathAbs(profit) : 0;
   
   // Ajouter à l'historique des résultats
   if(g_resultHistoryCount >= 1000)
   {
      for(int i = 0; i < 999; i++)
         g_resultHistory[i] = g_resultHistory[i+1];
      g_resultHistoryCount = 999;
   }
   
   ArrayResize(g_resultHistory, g_resultHistoryCount + 1);
   g_resultHistory[g_resultHistoryCount] = result;
   g_resultHistoryCount++;
   
   PrintFormat("?? Résultat enregistré: Ticket=%llu, Profit=%.2f, Spike=%s", 
               ticket, profit, (spikeCaptured ? "OUI" : "NON"));
   
   // ENREGISTRER LE GAIN/PERTE POUR LE SYMBOLE
   if(profit > 0)
   {
      RecordProfitForSymbol(result.symbol, profit);
   }
   else if(profit < 0)
   {
      RecordLossForSymbol(result.symbol, MathAbs(profit));
   }
   
   // Forcer la mise à jour immédiate du panneau de performance
   UpdatePerformancePanel();
}

//+------------------------------------------------------------------+
//| Analyse l'historique et calcule les scores de performance        |
//+------------------------------------------------------------------+
void AnalyzeSignalHistory()
{
   if(g_signalHistoryCount < 10 || g_resultHistoryCount < 5)
   {
      Print("?? Pas assez de données historiques pour l'analyse (Signaux: %d, Résultats: %d)", 
            g_signalHistoryCount, g_resultHistoryCount);
      return;
   }
   
   // Réinitialiser les scores
   ArrayResize(g_patternScores, 0);
   g_patternScoresCount = 0;
   
   // Analyser chaque pattern
   string patterns[] = {"ZScore", "Skewness", "Kurtosis", "Volume", "Scissor", 
                        "Fractal", "Hammer", "Engulfing", "Gap", "BBBreakout", "ATR"};
   int patternCount = ArraySize(patterns);
   
   for(int p = 0; p < patternCount; p++)
   {
      PatternPerformance perf;
      perf.patternName = patterns[p];
      perf.totalSignals = 0;
      perf.successfulSignals = 0;
      perf.totalProfit = 0;
      perf.avgProfit = 0;
      perf.winRate = 0;
      perf.profitFactor = 0;
      perf.avgConfidence = 0;
      
      double totalConfidence = 0;
      double totalWins = 0;
      double totalLosses = 0;
      
      // Parcourir l'historique pour ce pattern
      for(int i = 0; i < g_signalHistoryCount; i++)
      {
         bool hasPattern = false;
         
         // Vérifier si ce signal a ce pattern
         if(patterns[p] == "ZScore" && MathAbs(g_signalHistory[i].zscore) > InpZScoreThreshold)
            hasPattern = true;
         else if(patterns[p] == "Skewness" && MathAbs(g_signalHistory[i].skewness) > 0.5)
            hasPattern = true;
         else if(patterns[p] == "Kurtosis" && (g_signalHistory[i].kurtosis > 3.0 || g_signalHistory[i].kurtosis < 2.0))
            hasPattern = true;
         else if(patterns[p] == "Volume" && g_signalHistory[i].volumeRatio > InpVolumeMultiplier)
            hasPattern = true;
         else if(patterns[p] == "Scissor" && g_signalHistory[i].hasScissorPattern)
            hasPattern = true;
         else if(patterns[p] == "Fractal" && g_signalHistory[i].hasFractalPattern)
            hasPattern = true;
         else if(patterns[p] == "Hammer" && g_signalHistory[i].hasHammerPattern)
            hasPattern = true;
         else if(patterns[p] == "Engulfing" && g_signalHistory[i].hasEngulfingPattern)
            hasPattern = true;
         else if(patterns[p] == "Gap" && g_signalHistory[i].hasGap)
            hasPattern = true;
         else if(patterns[p] == "BBBreakout" && g_signalHistory[i].hasBBBreakout)
            hasPattern = true;
         else if(patterns[p] == "ATR" && g_signalHistory[i].atrRatio > 1.5)
            hasPattern = true;
         
         if(hasPattern)
         {
            perf.totalSignals++;
            totalConfidence += g_signalHistory[i].confidence;
            
            // Chercher le résultat correspondant
            for(int j = 0; j < g_resultHistoryCount; j++)
            {
               if(g_resultHistory[j].signalTime == g_signalHistory[i].timestamp &&
                  g_resultHistory[j].symbol == g_signalHistory[i].symbol)
               {
                  double profit = g_resultHistory[j].profit;
                  perf.totalProfit += profit;
                  
                  if(profit > 0)
                  {
                     perf.successfulSignals++;
                     totalWins += profit;
                  }
                  else
                  {
                     totalLosses += MathAbs(profit);
                  }
                  break;
               }
            }
         }
      }
      
      if(perf.totalSignals > 0)
      {
         perf.avgProfit = perf.totalProfit / perf.totalSignals;
         perf.winRate = (perf.totalSignals > 0) ? (perf.successfulSignals * 100.0 / perf.totalSignals) : 0;
         perf.profitFactor = (totalLosses > 0) ? (totalWins / totalLosses) : (totalWins > 0 ? 999 : 0);
         perf.avgConfidence = totalConfidence / perf.totalSignals;
         
         // Ajouter au tableau des scores
         ArrayResize(g_patternScores, g_patternScoresCount + 1);
         g_patternScores[g_patternScoresCount] = perf;
         g_patternScoresCount++;
      }
   }
   
   // Afficher les résultats
   PrintFormat("?? ANALYSE HISTORIQUE: %d patterns analysés", g_patternScoresCount);
   for(int i = 0; i < g_patternScoresCount; i++)
   {
      PrintFormat("  %s: WinRate=%.1f%%, ProfitFactor=%.2f, AvgProfit=%.2f, Signaux=%d",
                  g_patternScores[i].patternName,
                  g_patternScores[i].winRate,
                  g_patternScores[i].profitFactor,
                  g_patternScores[i].avgProfit,
                  g_patternScores[i].totalSignals);
   }
}

//+------------------------------------------------------------------+
//| Ajuste les poids adaptatifs en fonction de la performance        |
//+------------------------------------------------------------------+
void UpdateAdaptiveWeights()
{
   if(g_patternScoresCount == 0)
   {
      AnalyzeSignalHistory();
   }
   
   if(g_patternScoresCount == 0) return;
   
   // Calculer les nouveaux poids basés sur la performance
   double totalScore = 0;
   double scores[];
   ArrayResize(scores, 11);
   
   // Calculer un score pour chaque pattern (basé sur winRate et profitFactor)
   for(int i = 0; i < g_patternScoresCount; i++)
   {
      double score = (g_patternScores[i].winRate / 100.0) * 0.6 + 
                     MathMin(g_patternScores[i].profitFactor / 2.0, 1.0) * 0.4;
      scores[i] = score;
      totalScore += score;
   }
   
   if(totalScore == 0) return;
   
   // Normaliser et ajuster les poids (garder la somme totale constante)
   double baseTotal = g_adaptiveWeights.zscoreWeight + g_adaptiveWeights.skewnessWeight +
                      g_adaptiveWeights.kurtosisWeight + g_adaptiveWeights.volumeWeight +
                      g_adaptiveWeights.scissorWeight + g_adaptiveWeights.fractalWeight +
                      g_adaptiveWeights.hammerWeight + g_adaptiveWeights.engulfingWeight +
                      g_adaptiveWeights.gapWeight + g_adaptiveWeights.bbBreakoutWeight +
                      g_adaptiveWeights.atrWeight;
   
   // Ajuster les poids proportionnellement aux scores
   for(int i = 0; i < g_patternScoresCount; i++)
   {
      double newWeight = (scores[i] / totalScore) * baseTotal;
      
      if(g_patternScores[i].patternName == "ZScore")
         g_adaptiveWeights.zscoreWeight = newWeight;
      else if(g_patternScores[i].patternName == "Skewness")
         g_adaptiveWeights.skewnessWeight = newWeight;
      else if(g_patternScores[i].patternName == "Kurtosis")
         g_adaptiveWeights.kurtosisWeight = newWeight;
      else if(g_patternScores[i].patternName == "Volume")
         g_adaptiveWeights.volumeWeight = newWeight;
      else if(g_patternScores[i].patternName == "Scissor")
         g_adaptiveWeights.scissorWeight = newWeight;
      else if(g_patternScores[i].patternName == "Fractal")
         g_adaptiveWeights.fractalWeight = newWeight;
      else if(g_patternScores[i].patternName == "Hammer")
         g_adaptiveWeights.hammerWeight = newWeight;
      else if(g_patternScores[i].patternName == "Engulfing")
         g_adaptiveWeights.engulfingWeight = newWeight;
      else if(g_patternScores[i].patternName == "Gap")
         g_adaptiveWeights.gapWeight = newWeight;
      else if(g_patternScores[i].patternName == "BBBreakout")
         g_adaptiveWeights.bbBreakoutWeight = newWeight;
      else if(g_patternScores[i].patternName == "ATR")
         g_adaptiveWeights.atrWeight = newWeight;
   }
   
   PrintFormat("? Poids adaptatifs mis à jour: ZScore=%.1f%%, Volume=%.1f%%, Scissor=%.1f%%",
               g_adaptiveWeights.zscoreWeight, g_adaptiveWeights.volumeWeight, g_adaptiveWeights.scissorWeight);
}

//+------------------------------------------------------------------+
//| Calcule un score amélioré pour un signal en utilisant les poids adaptatifs |
//+------------------------------------------------------------------+
double CalculateAdaptiveSignalStrength(string symbol, ENUM_TIMEFRAMES tf, MarketStats &stats,
                                       bool scissor, bool fractal, bool hammer, bool engulfing,
                                       bool gap, bool bbBreakout, double volumeRatio, double atrRatio)
{
   double strength = 0.0;
   
   // Utiliser les poids adaptatifs au lieu des poids fixes
   if(MathAbs(stats.zscore_current) > InpZScoreThreshold)
      strength += g_adaptiveWeights.zscoreWeight;
   else if(MathAbs(stats.zscore_current) > 1.5)
      strength += g_adaptiveWeights.zscoreWeight * 0.6;
   
   if(MathAbs(stats.skewness) > 0.5)
      strength += g_adaptiveWeights.skewnessWeight;
   
   if(stats.kurtosis > 3.0 || stats.kurtosis < 2.0)
      strength += g_adaptiveWeights.kurtosisWeight;
   
   if(scissor)
      strength += g_adaptiveWeights.scissorWeight;
   
   if(fractal)
      strength += g_adaptiveWeights.fractalWeight;
   
   if(volumeRatio > InpVolumeMultiplier)
      strength += g_adaptiveWeights.volumeWeight;
   else if(volumeRatio > 1.5)
      strength += g_adaptiveWeights.volumeWeight * 0.5;
   
   if(hammer)
      strength += g_adaptiveWeights.hammerWeight;
   
   if(engulfing)
      strength += g_adaptiveWeights.engulfingWeight;
   
   if(gap)
      strength += g_adaptiveWeights.gapWeight;
   
   if(bbBreakout)
      strength += g_adaptiveWeights.bbBreakoutWeight;
   
   if(atrRatio > 1.5)
      strength += g_adaptiveWeights.atrWeight * MathMin((atrRatio - 1.0) * 2, 1.0);
   
   return strength;
}

//+------------------------------------------------------------------+
//| Calcule le score global de performance du robot                  |
//| Utilise toutes les performances disponibles de tous les symboles |
//+------------------------------------------------------------------+
double CalculateGlobalPerformanceScore()
{
   // Collecter tous les symboles uniques de l'historique (comme dans UpdatePerformancePanel)
   string symbols[];
   int symbolCount = 0;
   
   for(int i = 0; i < g_signalHistoryCount; i++)
   {
      bool found = false;
      for(int j = 0; j < symbolCount; j++)
      {
         if(symbols[j] == g_signalHistory[i].symbol)
         {
            found = true;
            break;
         }
      }
      if(!found && symbolCount < 100)
      {
         ArrayResize(symbols, symbolCount + 1);
         symbols[symbolCount] = g_signalHistory[i].symbol;
         symbolCount++;
      }
   }
   
   if(symbolCount == 0) return 0.0;
   
   // Calculer les statistiques globales en utilisant toutes les performances
   int globalTotal = 0, globalSuccess = 0;
   double globalProfit = 0, totalWins = 0, totalLosses = 0;
   
   // Parcourir tous les symboles et calculer leurs performances
   for(int i = 0; i < symbolCount; i++)
   {
      int totalSignals, successfulSignals;
      double totalProfit, winRate, avgProfit, profitFactor;
      
      CalculateSymbolPerformance(symbols[i], totalSignals, successfulSignals, 
                                 totalProfit, winRate, avgProfit, profitFactor);
      
      globalTotal += totalSignals;
      globalSuccess += successfulSignals;
      globalProfit += totalProfit;
   }
   
   // Calculer aussi les wins/losses totaux depuis l'historique des résultats
   for(int j = 0; j < g_resultHistoryCount; j++)
   {
      if(g_resultHistory[j].profit > 0)
         totalWins += g_resultHistory[j].profit;
      else
         totalLosses += MathAbs(g_resultHistory[j].profit);
   }
   
   if(globalTotal == 0) return 0.0;
   
   // Calculer WinRate et Profit Factor
   double globalWR = (globalSuccess * 100.0) / globalTotal;
   double globalPF = (totalLosses > 0) ? (totalWins / totalLosses) : (totalWins > 0 ? 999 : 0);
   
   // Normaliser le profit (sur une échelle de 0-100)
   // On suppose qu'un profit de 1000 = score de 100
   double normalizedProfit = MathMin(MathMax(globalProfit / 10.0, 0), 100);
   
   // Calculer le score composite (0-100)
   // WinRate: 40%, Profit Factor: 40%, Profit normalisé: 20%
   double wrScore = MathMin(globalWR, 100.0); // WinRate déjà en %
   double pfScore = MathMin((globalPF / 2.0) * 100.0, 100.0); // PF de 2.0 = 100%
   
   double globalScore = (wrScore * 0.4) + (pfScore * 0.4) + (normalizedProfit * 0.2);
   return MathMin(MathMax(globalScore, 0), 100);
}

//+------------------------------------------------------------------+
//| Calcule les statistiques de performance par symbole              |
//+------------------------------------------------------------------+
void CalculateSymbolPerformance(string symbol, int &totalSignals, int &successfulSignals, 
                                double &totalProfit, double &winRate, double &avgProfit, double &profitFactor)
{
   totalSignals = 0;
   successfulSignals = 0;
   totalProfit = 0;
   winRate = 0;
   avgProfit = 0;
   profitFactor = 0;
   
   double totalWins = 0;
   double totalLosses = 0;
   
   // Parcourir l'historique des signaux pour ce symbole
   for(int i = 0; i < g_signalHistoryCount; i++)
   {
      if(g_signalHistory[i].symbol == symbol)
      {
         totalSignals++;
         
         // Chercher le résultat correspondant
         for(int j = 0; j < g_resultHistoryCount; j++)
         {
            if(g_resultHistory[j].signalTime == g_signalHistory[i].timestamp &&
               g_resultHistory[j].symbol == symbol)
            {
               double profit = g_resultHistory[j].profit;
               totalProfit += profit;
               
               if(profit > 0)
               {
                  successfulSignals++;
                  totalWins += profit;
               }
               else
               {
                  totalLosses += MathAbs(profit);
               }
               break;
            }
         }
      }
   }
   
   if(totalSignals > 0)
   {
      winRate = (successfulSignals * 100.0) / totalSignals;
      avgProfit = totalProfit / totalSignals;
      profitFactor = (totalLosses > 0) ? (totalWins / totalLosses) : (totalWins > 0 ? 999 : 0);
   }
}

//+------------------------------------------------------------------+
//| Affiche le panneau de performance par symbole en bas à droite   |
//+------------------------------------------------------------------+
void UpdatePerformancePanel()
{
   if(!InpShowInfo) return;
   
   string prefix = "PerfPanel_";
   
   // Supprimer les anciens objets
   for(int i = ObjectsTotal(0, 0, -1)-1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
   
   // Obtenir la taille du graphique
   long chartWidth = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   long chartHeight = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   // Position en bas à droite
   int x = (int)chartWidth - 400; // Largeur du panneau: 400 pixels
   int y = (int)chartHeight - 250; // Hauteur du panneau: 250 pixels
   int lineHeight = 16;
   
   // Collecter tous les symboles uniques de l'historique
   string symbols[];
   int symbolCount = 0;
   
   for(int i = 0; i < g_signalHistoryCount; i++)
   {
      bool found = false;
      for(int j = 0; j < symbolCount; j++)
      {
         if(symbols[j] == g_signalHistory[i].symbol)
         {
            found = true;
            break;
         }
      }
      if(!found && symbolCount < 20)
      {
         ArrayResize(symbols, symbolCount + 1);
         symbols[symbolCount] = g_signalHistory[i].symbol;
         symbolCount++;
      }
   }
   
   if(symbolCount == 0)
   {
      // Afficher un message si pas de données
      string bgName = prefix + "BG";
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x-5);
      ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y-5);
      ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 390);
      ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 50);
      ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'20,20,20');
      ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
      
      CreateLabel(prefix+"NoData", "?? Performance: Pas encore de données", x, y, clrGray, 9);
      ChartRedraw();
      return;
   }
   
   // Calculer la hauteur nécessaire
   int panelHeight = lineHeight * (symbolCount + 3) + 10; // +3 pour titre et en-têtes
   
   // Créer le fond
   string bgName = prefix + "BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x-5);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y-5);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 390);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'20,20,20');
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   
   // Titre
   CreateLabel(prefix+"Title", "?? Performance par Symbole", x, y, clrYellow, 10, "Arial Bold");
   y += lineHeight;
   
   // En-têtes
   CreateLabel(prefix+"Header1", "Symbole", x, y, clrWhite, 8, "Arial Bold");
   CreateLabel(prefix+"Header2", "Signaux", x+80, y, clrWhite, 8, "Arial Bold");
   CreateLabel(prefix+"Header3", "WinRate", x+140, y, clrWhite, 8, "Arial Bold");
   CreateLabel(prefix+"Header4", "Profit", x+200, y, clrWhite, 8, "Arial Bold");
   CreateLabel(prefix+"Header5", "PF", x+270, y, clrWhite, 8, "Arial Bold");
   y += lineHeight;
   
   // Ligne de séparation
   string sepName = prefix + "Sep";
   ObjectCreate(0, sepName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, sepName, OBJPROP_XDISTANCE, x-5);
   ObjectSetInteger(0, sepName, OBJPROP_YDISTANCE, y-2);
   ObjectSetInteger(0, sepName, OBJPROP_XSIZE, 390);
   ObjectSetInteger(0, sepName, OBJPROP_YSIZE, 1);
   ObjectSetInteger(0, sepName, OBJPROP_BGCOLOR, clrDimGray);
   ObjectSetInteger(0, sepName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, sepName, OBJPROP_COLOR, clrDimGray);
   y += 3;
   
   // Afficher les statistiques pour chaque symbole
   for(int i = 0; i < symbolCount; i++)
   {
      int totalSignals, successfulSignals;
      double totalProfit, winRate, avgProfit, profitFactor;
      
      CalculateSymbolPerformance(symbols[i], totalSignals, successfulSignals, 
                                 totalProfit, winRate, avgProfit, profitFactor);
      
      if(totalSignals > 0)
      {
         // Couleur selon la performance
         color symbolColor = clrWhite;
         if(winRate >= 60 && profitFactor >= 1.5)
            symbolColor = clrLime;
         else if(winRate >= 50 && profitFactor >= 1.2)
            symbolColor = clrYellow;
         else if(winRate < 40 || profitFactor < 1.0)
            symbolColor = clrRed;
         
         // Symbole
         CreateLabel(prefix+"Sym_"+IntegerToString(i), symbols[i], x, y, symbolColor, 8);
         
         // Nombre de signaux
         CreateLabel(prefix+"Count_"+IntegerToString(i), IntegerToString(totalSignals), x+80, y, symbolColor, 8);
         
         // Win Rate
         string winRateText = StringFormat("%.1f%%", winRate);
         CreateLabel(prefix+"WR_"+IntegerToString(i), winRateText, x+140, y, symbolColor, 8);
         
         // Profit total
         string profitText = StringFormat("%.2f", totalProfit);
         color profitColor = (totalProfit >= 0) ? clrLime : clrRed;
         CreateLabel(prefix+"Profit_"+IntegerToString(i), profitText, x+200, y, profitColor, 8);
         
         // Profit Factor
         string pfText = StringFormat("%.2f", profitFactor);
         color pfColor = (profitFactor >= 1.5) ? clrLime : ((profitFactor >= 1.2) ? clrYellow : clrRed);
         CreateLabel(prefix+"PF_"+IntegerToString(i), pfText, x+270, y, pfColor, 8);
         
         y += lineHeight;
      }
   }
   
   // Statistiques globales
   y += 5;
   int globalTotal = 0, globalSuccess = 0;
   double globalProfit = 0, globalWR = 0, globalPF = 0;
   
   for(int i = 0; i < symbolCount; i++)
   {
      int totalSignals, successfulSignals;
      double totalProfit, winRate, avgProfit, profitFactor;
      
      CalculateSymbolPerformance(symbols[i], totalSignals, successfulSignals, 
                                 totalProfit, winRate, avgProfit, profitFactor);
      
      globalTotal += totalSignals;
      globalSuccess += successfulSignals;
      globalProfit += totalProfit;
   }
   
   if(globalTotal > 0)
   {
      globalWR = (globalSuccess * 100.0) / globalTotal;
      
      double totalWins = 0, totalLosses = 0;
      for(int j = 0; j < g_resultHistoryCount; j++)
      {
         if(g_resultHistory[j].profit > 0)
            totalWins += g_resultHistory[j].profit;
         else
            totalLosses += MathAbs(g_resultHistory[j].profit);
      }
      globalPF = (totalLosses > 0) ? (totalWins / totalLosses) : (totalWins > 0 ? 999 : 0);
      
      // Ligne de séparation
      string sep2Name = prefix + "Sep2";
      ObjectCreate(0, sep2Name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, sep2Name, OBJPROP_XDISTANCE, x-5);
      ObjectSetInteger(0, sep2Name, OBJPROP_YDISTANCE, y-2);
      ObjectSetInteger(0, sep2Name, OBJPROP_XSIZE, 390);
      ObjectSetInteger(0, sep2Name, OBJPROP_YSIZE, 1);
      ObjectSetInteger(0, sep2Name, OBJPROP_BGCOLOR, clrDimGray);
      ObjectSetInteger(0, sep2Name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, sep2Name, OBJPROP_COLOR, clrDimGray);
      y += 3;
      
      // Total global
      CreateLabel(prefix+"Total", "TOTAL", x, y, clrCyan, 9, "Arial Bold");
      CreateLabel(prefix+"TotalCount", IntegerToString(globalTotal), x+80, y, clrCyan, 9, "Arial Bold");
      CreateLabel(prefix+"TotalWR", StringFormat("%.1f%%", globalWR), x+140, y, clrCyan, 9, "Arial Bold");
      
      color globalProfitColor = (globalProfit >= 0) ? clrLime : clrRed;
      CreateLabel(prefix+"TotalProfit", StringFormat("%.2f", globalProfit), x+200, y, globalProfitColor, 9, "Arial Bold");
      
      color globalPFColor = (globalPF >= 1.5) ? clrLime : ((globalPF >= 1.2) ? clrYellow : clrRed);
      CreateLabel(prefix+"TotalPF", StringFormat("%.2f", globalPF), x+270, y, globalPFColor, 9, "Arial Bold");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| ========== STRATÉGIE AVANCÉE: DÉTECTION SPIKE PAR REBOND EMA ========== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Détecte un rebond sur une EMA spécifique                         |
//+------------------------------------------------------------------+
EMABounceInfo DetectEMABounce(string symbol, ENUM_TIMEFRAMES tf, int emaPeriod)
{
    EMABounceInfo bounce;
    bounce.isBouncing = false;
    bounce.emaLevel = emaPeriod;
    bounce.direction = 0;
    bounce.bouncePrice = 0;
    bounce.confidence = 0;
    bounce.touchCount = 0;
    bounce.volumeConfirmed = false;
    bounce.priceActionConfirmed = false;

    if(!InpEnableEMABounceStrategy) return bounce;

    // Créer handle EMA
    int emaHandle = iMA(symbol, tf, emaPeriod, 0, MODE_EMA, PRICE_CLOSE);
    if(emaHandle == INVALID_HANDLE) return bounce;

    // Récupérer les valeurs EMA et prix
    double emaValues[], closes[], highs[], lows[], opens[];
    long volumes[];
    ArraySetAsSeries(emaValues, true);
    ArraySetAsSeries(closes, true);
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);
    ArraySetAsSeries(opens, true);
    ArraySetAsSeries(volumes, true);

    if(CopyBuffer(emaHandle, 0, 0, 20, emaValues) < 20 ||
       CopyClose(symbol, tf, 0, 20, closes) < 20 ||
       CopyHigh(symbol, tf, 0, 20, highs) < 20 ||
       CopyLow(symbol, tf, 0, 20, lows) < 20 ||
       CopyOpen(symbol, tf, 0, 20, opens) < 20 ||
       CopyTickVolume(symbol, tf, 0, 20, volumes) < 20)
    {
        IndicatorRelease(emaHandle);
        return bounce;
    }

    // Calculer ATR pour la distance de rebond
    double atr = GetCurrentATR(symbol);
    if(atr <= 0) atr = (highs[0] - lows[0]);

    double maxBounceDistance = atr * InpEMABounceDistance;

    // Vérifier si le prix touche ou rebondit sur l'EMA
    double currentPrice = closes[0];
    double currentEMA = emaValues[0];
    double distanceToEMA = MathAbs(currentPrice - currentEMA);

    // Compter les touches récentes sur l'EMA
    int touchCount = 0;
    for(int i = 0; i < 10; i++)
    {
        double dist = MathAbs(closes[i] - emaValues[i]);
        if(dist <= maxBounceDistance)
        {
            touchCount++;
        }
    }

    bounce.touchCount = touchCount;

    // Vérifier si on est proche de l'EMA maintenant
    if(distanceToEMA <= maxBounceDistance && touchCount >= InpMinTouchesForBounce)
    {
        // Déterminer la direction du rebond
        // Rebond haussier: prix au-dessus de l'EMA et en hausse
        // Rebond baissier: prix en-dessous de l'EMA et en baisse

        bool bullishBounce = false;
        bool bearishBounce = false;

        // Vérifier le pattern de rebond (prix touche EMA puis repart)
        if(lows[1] <= emaValues[1] && closes[0] > emaValues[0] && closes[0] > opens[0])
        {
            // Prix a touché l'EMA par le bas et repart à la hausse
            bullishBounce = true;
            bounce.direction = 1;
        }
        else if(highs[1] >= emaValues[1] && closes[0] < emaValues[0] && closes[0] < opens[0])
        {
            // Prix a touché l'EMA par le haut et repart à la baisse
            bearishBounce = true;
            bounce.direction = -1;
        }

        if(bullishBounce || bearishBounce)
        {
            bounce.isBouncing = true;
            bounce.bouncePrice = currentPrice;

            // Calculer la confiance du rebond
            double confidence = 50.0; // Base

            // Bonus pour nombre de touches
            confidence += (touchCount - InpMinTouchesForBounce) * 5.0;

            // Bonus pour proximité de l'EMA
            double proximityRatio = 1.0 - (distanceToEMA / maxBounceDistance);
            confidence += proximityRatio * 20.0;

            // Vérifier la confirmation par le volume
            if(InpUseVolumeConfirmation)
            {
                double avgVolume = 0;
                for(int i = 1; i < 10; i++)
                {
                    avgVolume += (double)volumes[i];
                }
                avgVolume /= 9;

                double currentVolume = (double)volumes[0];
                if(currentVolume > avgVolume * InpMinVolumeRatio)
                {
                    bounce.volumeConfirmed = true;
                    confidence += 15.0;
                }
            }

            // Vérifier la confirmation par price action
            if(InpUsePriceActionFilter)
            {
                double bodySize = MathAbs(closes[0] - opens[0]);
                double candleRange = highs[0] - lows[0];

                // Bougie forte (body > 60% de la range)
                if(candleRange > 0 && bodySize > candleRange * 0.6)
                {
                    bounce.priceActionConfirmed = true;
                    confidence += 10.0;
                }
            }

            bounce.confidence = MathMin(100.0, confidence);
        }
    }

    IndicatorRelease(emaHandle);
    return bounce;
}

//+------------------------------------------------------------------+
//| Vérifie l'alignement des EMAs (10 > 20 > 50 ou 10 < 20 < 50)    |
//+------------------------------------------------------------------+
bool CheckEMAAlignment(string symbol, ENUM_TIMEFRAMES tf, int &alignmentDirection)
{
    alignmentDirection = 0;

    if(!InpDetectEMAAlignment) return false;

    // Créer handles pour les 3 EMAs
    int ema10Handle = iMA(symbol, tf, InpEMA10Period, 0, MODE_EMA, PRICE_CLOSE);
    int ema20Handle = iMA(symbol, tf, InpEMA20Period, 0, MODE_EMA, PRICE_CLOSE);
    int ema50Handle = iMA(symbol, tf, InpEMA50Period, 0, MODE_EMA, PRICE_CLOSE);

    if(ema10Handle == INVALID_HANDLE || ema20Handle == INVALID_HANDLE || ema50Handle == INVALID_HANDLE)
    {
        if(ema10Handle != INVALID_HANDLE) IndicatorRelease(ema10Handle);
        if(ema20Handle != INVALID_HANDLE) IndicatorRelease(ema20Handle);
        if(ema50Handle != INVALID_HANDLE) IndicatorRelease(ema50Handle);
        return false;
    }

    double ema10[], ema20[], ema50[];
    ArraySetAsSeries(ema10, true);
    ArraySetAsSeries(ema20, true);
    ArraySetAsSeries(ema50, true);

    if(CopyBuffer(ema10Handle, 0, 0, 1, ema10) < 1 ||
       CopyBuffer(ema20Handle, 0, 0, 1, ema20) < 1 ||
       CopyBuffer(ema50Handle, 0, 0, 1, ema50) < 1)
    {
        IndicatorRelease(ema10Handle);
        IndicatorRelease(ema20Handle);
        IndicatorRelease(ema50Handle);
        return false;
    }

    // Vérifier l'alignement haussier: EMA10 > EMA20 > EMA50
    bool bullishAlignment = (ema10[0] > ema20[0] && ema20[0] > ema50[0]);

    // Vérifier l'alignement baissier: EMA10 < EMA20 < EMA50
    bool bearishAlignment = (ema10[0] < ema20[0] && ema20[0] < ema50[0]);

    IndicatorRelease(ema10Handle);
    IndicatorRelease(ema20Handle);
    IndicatorRelease(ema50Handle);

    if(bullishAlignment)
    {
        alignmentDirection = 1;
        return true;
    }
    else if(bearishAlignment)
    {
        alignmentDirection = -1;
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Confirmation multi-timeframe (3 TF les plus proches)             |
//+------------------------------------------------------------------+
MultiTFConfirmation GetMultiTimeframeConfirmation(string symbol, ENUM_TIMEFRAMES baseTF)
{
    MultiTFConfirmation confirmation;
    confirmation.tf1Bullish = false;
    confirmation.tf2Bullish = false;
    confirmation.tf3Bullish = false;
    confirmation.tf1Bearish = false;
    confirmation.tf2Bearish = false;
    confirmation.tf3Bearish = false;
    confirmation.trendStrength = 0;
    confirmation.emaAligned = false;
    confirmation.confirmedDirection = 0;

    if(!InpRequireMultiTFConfirmation)
    {
        // Si pas de confirmation requise, retourner une confirmation neutre
        return confirmation;
    }

    // Déterminer les 3 timeframes les plus proches
    ENUM_TIMEFRAMES tf1, tf2, tf3;

    if(baseTF == PERIOD_M1)
    {
        tf1 = PERIOD_M1;
        tf2 = PERIOD_M5;
        tf3 = PERIOD_M15;
    }
    else if(baseTF == PERIOD_M5)
    {
        tf1 = PERIOD_M5;
        tf2 = PERIOD_M15;
        tf3 = PERIOD_H1;
    }
    else if(baseTF == PERIOD_M15)
    {
        tf1 = PERIOD_M15;
        tf2 = PERIOD_H1;
        tf3 = PERIOD_H4;
    }
    else if(baseTF == PERIOD_H1)
    {
        tf1 = PERIOD_H1;
        tf2 = PERIOD_H4;
        tf3 = PERIOD_D1;
    }
    else
    {
        tf1 = PERIOD_H4;
        tf2 = PERIOD_D1;
        tf3 = PERIOD_W1;
    }

    // Vérifier la tendance sur chaque timeframe
    int align1 = 0, align2 = 0, align3 = 0;
    bool aligned1 = CheckEMAAlignment(symbol, tf1, align1);
    bool aligned2 = CheckEMAAlignment(symbol, tf2, align2);
    bool aligned3 = CheckEMAAlignment(symbol, tf3, align3);

    confirmation.tf1Bullish = (align1 > 0);
    confirmation.tf2Bullish = (align2 > 0);
    confirmation.tf3Bullish = (align3 > 0);
    confirmation.tf1Bearish = (align1 < 0);
    confirmation.tf2Bearish = (align2 < 0);
    confirmation.tf3Bearish = (align3 < 0);

    // Compter les confirmations
    int bullishCount = 0;
    int bearishCount = 0;

    if(confirmation.tf1Bullish) bullishCount++;
    if(confirmation.tf2Bullish) bullishCount++;
    if(confirmation.tf3Bullish) bullishCount++;
    if(confirmation.tf1Bearish) bearishCount++;
    if(confirmation.tf2Bearish) bearishCount++;
    if(confirmation.tf3Bearish) bearishCount++;

    // Calculer la force de la tendance
    if(bullishCount >= 2)
    {
        confirmation.confirmedDirection = 1;
        confirmation.trendStrength = (bullishCount / 3.0) * 100.0;
        confirmation.emaAligned = (bullishCount == 3);
    }
    else if(bearishCount >= 2)
    {
        confirmation.confirmedDirection = -1;
        confirmation.trendStrength = (bearishCount / 3.0) * 100.0;
        confirmation.emaAligned = (bearishCount == 3);
    }

    return confirmation;
}

//+------------------------------------------------------------------+
//| Détection de spike avec stratégie EMA avancée (fiabilité ~90%)   |
//+------------------------------------------------------------------+
bool DetectSpikeWithEMAStrategy(string symbol, ENUM_TIMEFRAMES tf, int &direction, double &confidence, double &entryPrice, double &sl, double &tp)
{
    direction = 0;
    confidence = 0;
    entryPrice = 0;
    sl = 0;
    tp = 0;

    if(!InpEnableEMABounceStrategy) return false;

    // 1. Détecter les rebonds sur chaque EMA
    EMABounceInfo bounce10 = DetectEMABounce(symbol, tf, InpEMA10Period);
    EMABounceInfo bounce20 = DetectEMABounce(symbol, tf, InpEMA20Period);
    EMABounceInfo bounce50 = DetectEMABounce(symbol, tf, InpEMA50Period);

    // 2. Obtenir la confirmation multi-timeframe
    MultiTFConfirmation mtfConfirm = GetMultiTimeframeConfirmation(symbol, tf);

    // 3. Vérifier si au moins un rebond est détecté
    bool hasValidBounce = false;
    EMABounceInfo bestBounce;
    bestBounce.confidence = 0;

    if(bounce10.isBouncing && bounce10.confidence > bestBounce.confidence)
    {
        bestBounce = bounce10;
        hasValidBounce = true;
    }
    if(bounce20.isBouncing && bounce20.confidence > bestBounce.confidence)
    {
        bestBounce = bounce20;
        hasValidBounce = true;
    }
    if(bounce50.isBouncing && bounce50.confidence > bestBounce.confidence)
    {
        bestBounce = bounce50;
        hasValidBounce = true;
    }

    if(!hasValidBounce) return false;

    // 4. Vérifier la cohérence avec la confirmation multi-timeframe
    bool mtfConfirmed = false;

    if(InpRequireMultiTFConfirmation)
    {
        // La direction du rebond doit correspondre à la tendance multi-TF
        if(bestBounce.direction > 0 && mtfConfirm.confirmedDirection > 0)
        {
            mtfConfirmed = true;
        }
        else if(bestBounce.direction < 0 && mtfConfirm.confirmedDirection < 0)
        {
            mtfConfirmed = true;
        }

        // Si la tendance multi-TF n'est pas assez forte, rejeter
        if(mtfConfirm.trendStrength < InpMinTrendConfidence)
        {
            mtfConfirmed = false;
        }
    }
    else
    {
        mtfConfirmed = true; // Pas de confirmation requise
    }

    if(!mtfConfirmed) return false;

    // 5. Calculer la confiance finale (combinaison de tous les facteurs)
    double finalConfidence = bestBounce.confidence;

    // Bonus pour confirmation multi-TF
    if(mtfConfirm.emaAligned)
    {
        finalConfidence += 15.0; // Bonus si les 3 TF sont alignés
    }
    else if(mtfConfirm.trendStrength >= InpMinTrendConfidence)
    {
        finalConfidence += 10.0; // Bonus si au moins 2 TF sont alignés
    }

    // Bonus pour volume confirmé
    if(bestBounce.volumeConfirmed)
    {
        finalConfidence += 5.0;
    }

    // Bonus pour price action confirmée
    if(bestBounce.priceActionConfirmed)
    {
        finalConfidence += 5.0;
    }

    // Bonus pour rebond sur EMA50 (plus fiable)
    if(bestBounce.emaLevel == InpEMA50Period)
    {
        finalConfidence += 10.0;
    }
    else if(bestBounce.emaLevel == InpEMA20Period)
    {
        finalConfidence += 5.0;
    }

    finalConfidence = MathMin(100.0, finalConfidence);

    // 6. Vérifier si la confiance atteint la cible de fiabilité
    if(finalConfidence < InpSpikeReliabilityTarget)
    {
        PrintFormat("?? Rebond EMA détecté mais confiance insuffisante: %.1f%% < %.1f%% (cible)",
                    finalConfidence, InpSpikeReliabilityTarget);
        return false;
    }

    // 7. Calculer les niveaux d'entrée, SL et TP
    direction = bestBounce.direction;
    confidence = finalConfidence;
    entryPrice = bestBounce.bouncePrice;

    double atr = GetCurrentATR(symbol);
    if(atr <= 0)
    {
        MqlRates rates[];
        if(CopyRates(symbol, tf, 0, 1, rates) > 0)
            atr = rates[0].high - rates[0].low;
        else
            atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 100;
    }

    // SL et TP basés sur l'EMA et l'ATR
    if(direction > 0) // BUY
    {
        // SL sous l'EMA du rebond
        int emaHandle = iMA(symbol, tf, bestBounce.emaLevel, 0, MODE_EMA, PRICE_CLOSE);
        if(emaHandle != INVALID_HANDLE)
        {
            double emaVal[];
            ArraySetAsSeries(emaVal, true);
            if(CopyBuffer(emaHandle, 0, 0, 1, emaVal) > 0)
            {
                sl = emaVal[0] - atr * 0.5; // SL 0.5 ATR sous l'EMA
            }
            IndicatorRelease(emaHandle);
        }

        if(sl == 0) sl = entryPrice - atr * 1.5;

        // TP basé sur le ratio risque/récompense
        double slDistance = entryPrice - sl;
        tp = entryPrice + slDistance * 3.0; // Ratio 1:3
    }
    else // SELL
    {
        // SL au-dessus l'EMA du rebond
        int emaHandle = iMA(symbol, tf, bestBounce.emaLevel, 0, MODE_EMA, PRICE_CLOSE);
        if(emaHandle != INVALID_HANDLE)
        {
            double emaVal[];
            ArraySetAsSeries(emaVal, true);
            if(CopyBuffer(emaHandle, 0, 0, 1, emaVal) > 0)
            {
                sl = emaVal[0] + atr * 0.5; // SL 0.5 ATR au-dessus l'EMA
            }
            IndicatorRelease(emaHandle);
        }

        if(sl == 0) sl = entryPrice + atr * 1.5;

        // TP basé sur le ratio risque/récompense
        double slDistance = sl - entryPrice;
        tp = entryPrice - slDistance * 3.0; // Ratio 1:3
    }

    // Normaliser les prix
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    entryPrice = NormalizeDouble(entryPrice, digits);
    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);

    PrintFormat("?? SPIKE DÉTECTÉ PAR REBOND EMA%d - Direction: %s, Confiance: %.1f%%, Entry: %.5f, SL: %.5f, TP: %.5f",
                bestBounce.emaLevel,
                (direction > 0 ? "BUY" : "SELL"),
                confidence,
                entryPrice, sl, tp);

    PrintFormat("   ?? Multi-TF: TrendStrength=%.1f%%, Aligned=%s, Touches=%d, Volume=%s, PriceAction=%s",
                mtfConfirm.trendStrength,
                mtfConfirm.emaAligned ? "OUI" : "NON",
                bestBounce.touchCount,
                bestBounce.volumeConfirmed ? "OUI" : "NON",
                bestBounce.priceActionConfirmed ? "OUI" : "NON");

    return true;
}

//+------------------------------------------------------------------+
//| Vérifie si un signal est similaire aux signaux réussis           |
//+------------------------------------------------------------------+
bool IsSignalSimilarToSuccessfulOnes(SignalFeatures &signal)
{
   if(g_resultHistoryCount < 5) return true; // Pas assez de données
   
   int similarCount = 0;
   int successfulCount = 0;
   
   // Parcourir les signaux réussis (profit > 0)
   for(int i = 0; i < g_signalHistoryCount; i++)
   {
      // Vérifier si ce signal a eu un résultat positif
      bool wasSuccessful = false;
      for(int j = 0; j < g_resultHistoryCount; j++)
      {
         if(g_resultHistory[j].signalTime == g_signalHistory[i].timestamp &&
            g_resultHistory[j].symbol == g_signalHistory[i].symbol &&
            g_resultHistory[j].profit > 0)
         {
            wasSuccessful = true;
            break;
         }
      }
      
      if(wasSuccessful)
      {
         successfulCount++;
         
         // Vérifier la similarité (même direction, patterns similaires)
         if(signal.direction == g_signalHistory[i].direction)
         {
            int matchingPatterns = 0;
            if(signal.hasScissorPattern == g_signalHistory[i].hasScissorPattern) matchingPatterns++;
            if(signal.hasFractalPattern == g_signalHistory[i].hasFractalPattern) matchingPatterns++;
            if(signal.hasHammerPattern == g_signalHistory[i].hasHammerPattern) matchingPatterns++;
            if(signal.hasEngulfingPattern == g_signalHistory[i].hasEngulfingPattern) matchingPatterns++;
            if(signal.hasGap == g_signalHistory[i].hasGap) matchingPatterns++;
            if(signal.hasBBBreakout == g_signalHistory[i].hasBBBreakout) matchingPatterns++;
            
            // Si au moins 3 patterns correspondent, considérer comme similaire
            if(matchingPatterns >= 3)
               similarCount++;
         }
      }
   }
   
   // Si au moins 30% des signaux réussis sont similaires, accepter
   return (successfulCount > 0 && (similarCount * 100.0 / successfulCount) >= 30.0);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Libérer tous les handles d'indicateurs par symbole
   ReleaseAllSymbolHandles();
   
   if(g_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_atr_handle); g_atr_handle = INVALID_HANDLE; }
   if(g_short_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_short_atr_handle); g_short_atr_handle = INVALID_HANDLE; }
   if(g_long_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_long_atr_handle); g_long_atr_handle = INVALID_HANDLE; }
   if(g_ma20_handle != INVALID_HANDLE) { IndicatorRelease(g_ma20_handle); g_ma20_handle = INVALID_HANDLE; }
   if(g_ma50_handle != INVALID_HANDLE) { IndicatorRelease(g_ma50_handle); g_ma50_handle = INVALID_HANDLE; }
   EventKillTimer();
   if(InpShowVisuals) DeleteAllEAObjects();
   Print("Fx_robot_pred - Deinit");
}

//+------------------------------------------------------------------+
//| Analyse un symbole spécifique                                    |
//+------------------------------------------------------------------+
void AnalyzeSymbol(string symbol)
{
    // Sauvegarder le symbole actuel
    string currentSymbol = _Symbol;
    
    // Changer de symbole si nécessaire
    if(symbol != currentSymbol)
    {
        if(!SymbolSelect(symbol, true))
        {
            Print("Impossible de sélectionner le symbole: ", symbol);
            return;
        }
        // Attendre un court instant pour que les données se mettent à jour
        Sleep(100);
    }
    
    // Vérifier si le symbole est dans la liste des priorités (optionnel)
    if(!IsPrioritySymbol())
    {
        static datetime lastWarningTime = 0;
        if(TimeCurrent() - lastWarningTime > 60) // affiche max toutes les 60s
        {
            Print("Attention: Le symbole ", symbol, " n'est pas dans la liste des symboles prioritaires.");
            lastWarningTime = TimeCurrent();
        }
        return;
    }
    
    // Vérifier si une analyse est nécessaire (toutes les 5 secondes par défaut)
    static datetime lastAnalysisTime = 0;
    if(TimeCurrent() - lastAnalysisTime < 5)
        return;
        
    lastAnalysisTime = TimeCurrent();
    
    // Vérifier si un trade est déjà en cours ou si un signal est actif
    // DÉSACTIVÉ: Permettre l'analyse même avec positions/signaux actifs
    // if(HasOpenPosition() || IsSignalActive())
    bool shouldSkip = false; // Ne plus bloquer
    if(shouldSkip)
    {
        // trailing stop désactivé - SL/TP fixes
        
        if(HasOpenPosition())
            Print("Un trade est déjà en cours sur ", symbol, ". Attente de sa clôture.");
        else if(IsSignalActive())
            Print("Un signal est déjà actif pour ", symbol, ". Attente de son expiration.");
            
        return;
    }
    
    // Calcul des indicateurs
    double atr = GetCurrentATR(symbol);
    double vpin = ComputeVPIN(InpVPIN_WindowBars, InpSpikeTimeframe);
    double obi = ComputeOBI(InpOBI_Lookback, InpSpikeTimeframe);
    double cvd = ComputeCVD(InpCVD_WindowBars, InpSpikeTimeframe);
    double adx = ComputeADX(symbol, InpSpikeTimeframe, InpADX_Period);
    bool liquidity_sweep = DetectLiquiditySweep(InpSpikeTimeframe, atr, 2.5);
    int fvg = DetectFVG(InpSpikeTimeframe);
    bool isUp = IsUptrend();
    
    // Log des valeurs des indicateurs
    PrintFormat("%s - VPIN=%.2f, OBI=%.2f, CVD=%.2f, ADX=%.2f, ATR=%.5f",
                symbol, vpin, obi, cvd, adx, atr);
    
    // Logique de trading...
    // ... (le reste de votre logique de trading ici)
    
    // Restaurer le symbole d'origine si nécessaire
    if(symbol != currentSymbol)
    {
        SymbolSelect(currentSymbol, true);
    }
}

//+------------------------------------------------------------------+
//| OnTimer - main loop (chaque seconde)                             |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Mettre à jour le tableau de bord
    static datetime lastUpdate = 0;
    if(TimeCurrent() - lastUpdate >= 1) // Mise à jour toutes les secondes
    {
        UpdateDashboard();
        UpdatePerformancePanel();
        lastUpdate = TimeCurrent();
    }
    
    if(!InpEnableTrading) return;
    
    // Gestion du risque désactivée - SL/TP fixes
    // if(InpEnableTrailing) ManageLowVolatilityRisk();
    
    // Analyser chaque symbole de la liste
    int totalSymbols = ArraySize(g_symbolsToWatch);
    int boomCrashCount = 0;
    
    PrintFormat("?? Analyse de %d symboles détectés...", totalSymbols);
    
    for(int i = 0; i < totalSymbols; i++)
    {
        string symbol = g_symbolsToWatch[i];
        
        // Compter les symboles Boom/Crash
        if(StringFind(symbol, "Boom", 0) >= 0 || StringFind(symbol, "Crash", 0) >= 0)
            boomCrashCount++;
        
        // VÉRIFIER LES SPIKES POUR RÉACTIVER LE TRADING SI NÉCESSAIRE
        CheckForSpikeAndReactivate(symbol);
        
        // Analyser le symbole
        static datetime lastAnalysisTime[];
        ArrayResize(lastAnalysisTime, totalSymbols);
        
        // Limiter l'analyse à une fois par seconde par symbole pour éviter la surcharge
        if(TimeCurrent() - lastAnalysisTime[i] >= 1)
        {
            AnalyzeSymbol(symbol);
            lastAnalysisTime[i] = TimeCurrent();
        }
    }
    
    // Afficher des statistiques toutes les 30 secondes
    static datetime lastStats = 0;
    if(TimeCurrent() - lastStats >= 30)
    {
        PrintFormat("?? Statistiques: %d symboles analysés (%d Boom/Crash)", totalSymbols, boomCrashCount);
        lastStats = TimeCurrent();
    }

   // Trader en continu (24/7) - ne pas attendre seulement les nouvelles bougies
   datetime t = iTime(_Symbol, InpSpikeTimeframe, 0);
   bool isNewBar = (t != g_lastBarTime);
   if(isNewBar) g_lastBarTime = t;
   
   // Pour M1, analyser toutes les secondes, pas seulement sur nouvelles bougies
   // Pour autres timeframes, analyser sur nouvelles bougies ET toutes les 5 secondes
   static datetime lastAnalysis = 0;
   if(!isNewBar && InpSpikeTimeframe != PERIOD_M1)
   {
      // Pour timeframes > M1, analyser toutes les 5 secondes même sans nouvelle bougie
      if(TimeCurrent() - lastAnalysis < 5) return;
   }
   lastAnalysis = TimeCurrent();

   long bars = GetBarsCount(_Symbol, InpSpikeTimeframe);
   if(bars < InpMinBarsRequired)
   {
      PrintFormat("Attente des données : bars=%d < required=%d", (int)bars, InpMinBarsRequired);
      return;
   }

   // Calcul des indicateurs/proxies institutionnels
   double atr = GetCurrentATR(_Symbol);
   double vpin = ComputeVPIN(InpVPIN_WindowBars, InpSpikeTimeframe);
   double obi  = ComputeOBI(InpOBI_Lookback, InpSpikeTimeframe);
   double cvd  = ComputeCVD(InpCVD_WindowBars, InpSpikeTimeframe);
   double adx  = ComputeADX(_Symbol, InpSpikeTimeframe, InpADX_Period);
   bool liquidity_sweep = DetectLiquiditySweep(InpSpikeTimeframe, atr, 2.5);
   int fvg = DetectFVG(InpSpikeTimeframe);
   bool isUp = IsUptrend();
   g_lastVPIN = vpin; g_lastOBI = obi; g_lastCVD = cvd;

   // Décision de trading : Buy uniquement sur Boom, Sell uniquement sur Crash
   int direction = 0; // +1 BUY Boom, -1 SELL Crash

   // Log des valeurs des indicateurs
   PrintFormat("VPIN=%.2f (Seuil: %.2f), OBI=%.2f (Seuil: ±%.2f), CVD=%.2f, ADX=%.2f, ATR=%.5f",
               vpin, InpVPIN_Threshold, obi, InpOBI_Threshold, cvd, adx, atr);

   // Nettoyer les signaux expirés
   CleanupExpiredSignals();
   
   // Traiter les buffers de signaux (consolidation sur 3.5 minutes)
   ProcessSignalBuffers();
   
   // Mettre à jour le panneau de performance (toutes les 5 secondes)
   static datetime lastPerfUpdate = 0;
   if(TimeCurrent() - lastPerfUpdate >= 5)
   {
      UpdatePerformancePanel();
      lastPerfUpdate = TimeCurrent();
   }

   // 1. PRÉDICTION ANTICIPÉE (AVANT LE SPIKE) - Juste avant qu'il arrive (secondes)
   // Pour M1, prédire dans les prochaines secondes, pas seulement la prochaine bougie
   SpikePrediction prediction = PredictSpikeBeforeItHappens(_Symbol, InpSpikeTimeframe, MathMax(200, InpScientificLookback));
   
   // Si la prédiction anticipée n'a pas détecté de spike imminent, utiliser la prédiction classique
   if(prediction.direction == 0 || prediction.confidence < 20)
   {
      prediction = PredictSpikePrice(_Symbol, InpSpikeTimeframe, InpScientificLookback);
   }
   
   // Pour M1, ajuster le temps prédit pour être dans les prochaines secondes (pas la prochaine bougie)
   if(InpSpikeTimeframe == PERIOD_M1 && prediction.direction != 0)
   {
      // Prédire le spike dans les 5-30 secondes qui suivent
      int secondsUntilSpike = 5 + (int)(prediction.confidence / 10); // 5-15 secondes selon confiance
      if(secondsUntilSpike > 30) secondsUntilSpike = 30; // Max 30 secondes
      prediction.predictedTime = TimeCurrent() + secondsUntilSpike;
   }
   
   // Log de la prédiction pour débogage
   if(prediction.direction != 0)
   {
      PrintFormat("?? PRÉDICTION: Direction=%s, Confiance=%.1f%%, Entry=%.5f, SL=%.5f, TP=%.5f",
                  (prediction.direction > 0 ? "BUY" : "SELL"),
                  prediction.confidence,
                  prediction.entryPrice,
                  prediction.stopLoss,
                  prediction.takeProfit);
   }

   // Exécution automatique quand flèche PRÉDICTIVE est affichée: placer un ordre au marché
   // et notifier l'utilisateur.
   bool boomOrCrash = (IsSymbolBoom(_Symbol) || IsSymbolCrash(_Symbol));
   if(boomOrCrash && InpAutoTradeOnPredictiveArrow && prediction.direction != 0 && prediction.confidence >= 30.0 && CanPlaceNewOrder() && IsTradeAllowedForSymbol(_Symbol))
   {
      // Dessiner la flèche prédictive (couleur atténuée)
      if(InpShowArrows && ShouldDrawArrow(prediction.direction, prediction.entryPrice, true))
      {
         DrawSpikeArrow(prediction.direction, false);

        // Calcul des niveaux de protection (SL géré par timeout 10 petites bougies)
        double useSL = 0.0;
        double useTP = prediction.takeProfit;
         double atr_now = atr;
         double price_now = (prediction.direction>0)?SymbolInfoDouble(_Symbol, SYMBOL_ASK):SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if(useTP == 0)
        {
           double tpMult = (InpSpikeTimeframe == PERIOD_M1) ? InpTPMultiplierM1 : 4.0;
           if(prediction.direction>0){ useTP = price_now + atr_now*tpMult; }
           else { useTP = price_now - atr_now*tpMult; }
        }

         // Ajuster SL/TP par les supports/résistances proches
         double ns=0.0, nr=0.0;
         if(FindNearestSupportResistance(_Symbol, InpSpikeTimeframe, price_now, ns, nr))
         {
            if(prediction.direction>0) { // BUY
               if(nr>0) useTP = MathMax(useTP, nr);
            } else {    // SELL
               if(ns>0) useTP = MathMin(useTP, ns);
            }
         }

        // Exécuter le trade (marché immédiat sur symbole Boom/Crash)
        int dir = prediction.direction;
        double conf = prediction.confidence;

         trade.SetExpertMagicNumber(InpMagicNumber);
         CancelAllPendingOrders(); // respecter la règle 1 trade par symbole
         double immediateLot = InpLimitOrderLotSize;
         if(immediateLot <= 0)
         {
            immediateLot = CalculateLotSize(atr_now);
            if(immediateLot <= 0) immediateLot = 0.2;
         }
         immediateLot = NormalizeLotSize(immediateLot, _Symbol);
         if(!IsValidLotSize(immediateLot, _Symbol))
         {
            PrintFormat("? Lot immédiat invalide pour trade prédictif: %.2f", immediateLot);
            return;
         }

         bool ok = (dir>0) ? trade.Buy(immediateLot, _Symbol, 0, useSL, useTP, "Predictive BUY")
                           : trade.Sell(immediateLot, _Symbol, 0, useSL, useTP, "Predictive SELL");
         if(!ok)
         {
            PrintFormat("? Échec trade prédictif auto: err=%d %s", GetLastError(), trade.ResultComment());
         }
         else
         {
            PrintFormat("?? Trade prédictif auto exécuté - dir=%s lot=%.2f price=%.5f TP=%.5f", (dir>0?"BUY":"SELL"), immediateLot, price_now, useTP);
         }

         // Récupérer le ticket le plus récent et l'enregistrer pour le timeout 10 petites bougies
         ulong ticket = FindLatestMagicPositionTicket(_Symbol);
         if(ticket>0)
            RegisterPredictedTrade(_Symbol, ticket, dir, price_now, (prediction.predictedPrice>0?prediction.predictedPrice:useTP));

         // Notifier
         SendTradingNotification(_Symbol, dir, price_now, useSL, useTP, 1, conf, false);
      }
   }

   // 2. VÉRIFICATION DES EMA POUR CONFIRMER LA TENDANCE (entrées basées EMA10 M1, EMA30 M5)
   int globalTrend = CalculateGlobalTrend();
   int currentTfTrend = GetTrendFromEMA(InpSpikeTimeframe);

   // Conditions de trading simplifiées pour permettre plus de signaux
   bool uptrend = IsUptrend();
   
   // Seuils assouplis
   double vp_threshold = InpVPIN_Threshold * 0.7; // Seuil VPIN réduit
   double obi_threshold = InpOBI_Threshold * 0.8; // Seuil OBI réduit
   double adx_threshold = InpADX_Threshold * 0.8; // Seuil ADX réduit
   
   // Log des conditions
   PrintFormat("Vérification des conditions - VPIN: %.2f (Seuil: %.2f), OBI: %.2f (Seuil: ±%.2f), ADX: %.2f (Seuil: %.2f)",
               vpin, vp_threshold, obi, obi_threshold, adx, adx_threshold);
   PrintFormat("Tendance globale: %s, Tendance TF actuel: %s, Prédiction confiance: %.1f%%",
               (globalTrend > 0 ? "HAUSSIÈRE" : (globalTrend < 0 ? "BAISSIÈRE" : "NEUTRE")),
               (currentTfTrend > 0 ? "HAUSSIÈRE" : (currentTfTrend < 0 ? "BAISSIÈRE" : "NEUTRE")),
               prediction.confidence);

   // Filtre EMA multi-TF pour scalping: EMA10 (M1) et EMA30 (M5)
   int ema10_m1 = iMA(_Symbol, PERIOD_M1, 10, 0, MODE_EMA, PRICE_CLOSE);
   int ema30_m5 = iMA(_Symbol, PERIOD_M5, 30, 0, MODE_EMA, PRICE_CLOSE);
   double e10[], e30[]; 
   ArraySetAsSeries(e10, true); 
   ArraySetAsSeries(e30, true);
   bool emaOk = false;
   double price_m1 = 0, price_m5 = 0;
   if(ema10_m1 != INVALID_HANDLE && ema30_m5 != INVALID_HANDLE &&
      CopyBuffer(ema10_m1,0,0,1,e10)>0 && CopyBuffer(ema30_m5,0,0,1,e30)>0)
   {
      price_m1 = iClose(_Symbol, PERIOD_M1, 0);
      // Pour BUY Boom: prix M1 au-dessus EMA10 et EMA30 M5 en dessous du prix M5
      price_m5 = iClose(_Symbol, PERIOD_M5, 0);
      bool buyFilter  = (price_m1 > e10[0] && price_m5 > e30[0]);
      bool sellFilter = (price_m1 < e10[0] && price_m5 < e30[0]);
      emaOk = buyFilter || sellFilter;
   }
   
   // NOUVEAU: Détection automatique quand le prix approche EMA10 (M1) ou EMA30 (M5) près de support/résistance
   // Cette détection doit déclencher un trade automatiquement
   if(ema10_m1 != INVALID_HANDLE && ema30_m5 != INVALID_HANDLE && price_m1 > 0 && price_m5 > 0)
   {
      // Calculer la distance au prix actuel
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double atr = GetCurrentATR(_Symbol);
      if(atr <= 0) atr = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100;
      
      // Distance maximale pour considérer que le prix "approche" l'EMA (1.5 ATR)
      double maxApproachDistance = atr * 1.5;
      
      // Vérifier si le prix approche EMA10 (M1)
      double distanceToEMA10_M1 = MathAbs(price_m1 - e10[0]);
      bool approachingEMA10_M1 = (distanceToEMA10_M1 <= maxApproachDistance);
      
      // Vérifier si le prix approche EMA30 (M5)
      double distanceToEMA30_M5 = MathAbs(price_m5 - e30[0]);
      bool approachingEMA30_M5 = (distanceToEMA30_M5 <= maxApproachDistance);
      
      // Détecter support/résistance proches
      double nearestSupport = 0, nearestResistance = 0;
      bool nearSR = FindNearestSupportResistance(_Symbol, InpSpikeTimeframe, currentPrice, nearestSupport, nearestResistance);
      
      // Distance maximale pour considérer "près" de S/R (1 ATR)
      double maxSRDistance = atr * 1.0;
      bool nearSupport = (nearestSupport > 0 && MathAbs(currentPrice - nearestSupport) <= maxSRDistance);
      bool nearResistance = (nearestResistance > 0 && MathAbs(currentPrice - nearestResistance) <= maxSRDistance);
      
      // Si le prix approche EMA10 (M1) ou EMA30 (M5) ET est près d'un support/résistance
      if((approachingEMA10_M1 || approachingEMA30_M5) && (nearSupport || nearResistance))
      {
         // Déterminer la direction du trade
         int tradeDirection = 0;
         double entryPrice = currentPrice;
         double sl = 0, tp = 0;
         
         // Logique: Si près d'un support -> BUY, Si près d'une résistance -> SELL
         // Pour BOOM: BUY près d'un support, SELL près d'une résistance (si trades inverses autorisés)
         // Pour CRASH: SELL près d'une résistance, BUY près d'un support (si trades inverses autorisés)
         
         if(nearSupport)
         {
            // Prix approche EMA et est près d'un support -> Signal BUY
            // BUY autorisé pour Boom, ou pour Crash si trades inverses autorisés
            if(IsSymbolBoom(_Symbol) || (IsSymbolCrash(_Symbol) && InpAllowReverseTrades))
            {
               tradeDirection = 1;
               entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               sl = entryPrice - atr * 1.5;
               tp = entryPrice + atr * 3.0;
               
               PrintFormat("🚀 SIGNAL AUTOMATIQUE: Prix approche EMA%s près d'un SUPPORT - BUY", 
                           approachingEMA10_M1 ? "10 (M1)" : "30 (M5)");
               PrintFormat("   Prix: %.5f, EMA: %.5f, Support: %.5f, Distance EMA: %.5f", 
                           currentPrice, approachingEMA10_M1 ? e10[0] : e30[0], nearestSupport, 
                           approachingEMA10_M1 ? distanceToEMA10_M1 : distanceToEMA30_M5);
            }
         }
         else if(nearResistance)
         {
            // Prix approche EMA et est près d'une résistance -> Signal SELL
            // SELL autorisé pour Crash, ou pour Boom si trades inverses autorisés
            if(IsSymbolCrash(_Symbol) || (IsSymbolBoom(_Symbol) && InpAllowReverseTrades))
            {
               tradeDirection = -1;
               entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               sl = entryPrice + atr * 1.5;
               tp = entryPrice - atr * 3.0;
               
               PrintFormat("🚀 SIGNAL AUTOMATIQUE: Prix approche EMA%s près d'une RÉSISTANCE - SELL", 
                           approachingEMA10_M1 ? "10 (M1)" : "30 (M5)");
               PrintFormat("   Prix: %.5f, EMA: %.5f, Résistance: %.5f, Distance EMA: %.5f", 
                           currentPrice, approachingEMA10_M1 ? e10[0] : e30[0], nearestResistance, 
                           approachingEMA10_M1 ? distanceToEMA10_M1 : distanceToEMA30_M5);
            }
         }
         
         // EXÉCUTER LE TRADE AUTOMATIQUEMENT si signal détecté
         if(tradeDirection != 0 && CanPlaceNewOrder() && IsTradeAllowedForSymbol(_Symbol) && InpEnableTrading)
         {
            // Normaliser les prix
            int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            entryPrice = NormalizeDouble(entryPrice, digits);
            sl = NormalizeDouble(sl, digits);
            tp = NormalizeDouble(tp, digits);
            
            PrintFormat("✅ EXÉCUTION AUTOMATIQUE DU TRADE - Direction: %s, Entry: %.5f, SL: %.5f, TP: %.5f",
                        (tradeDirection > 0 ? "BUY" : "SELL"), entryPrice, sl, tp);
            
            // Marquer le signal comme actif
            SetSignalActive(tradeDirection, entryPrice);
            
            // Exécuter le trade immédiatement
            ExecuteTradeWithLevels(tradeDirection, atr, entryPrice, sl, tp, false, 85.0); // Confiance 85% pour approche EMA
            
            // Récupérer le ticket du trade exécuté et l'enregistrer pour le monitoring 10 bougies
            ulong executedTicket = FindLatestMagicPositionTicket(_Symbol);
            if(executedTicket > 0)
            {
               // Enregistrer pour le monitoring du timeout 10 bougies
               RegisterPredictedTrade(_Symbol, executedTicket, tradeDirection, entryPrice, tp);
               PrintFormat("📝 Trade enregistré pour monitoring - Ticket: %llu, Timeout: 10 bougies", executedTicket);
            }
            
            // Dessiner la flèche
            if(InpShowArrows && ShouldDrawArrow(tradeDirection, entryPrice))
            {
               DrawSpikeArrow(tradeDirection);
               Print("✅ Flèche affichée - Trade automatique exécuté");
            }
            
            // Libérer les handles et retourner (trade exécuté)
            if(ema10_m1 != INVALID_HANDLE) IndicatorRelease(ema10_m1);
            if(ema30_m5 != INVALID_HANDLE) IndicatorRelease(ema30_m5);
            return; // Sortir immédiatement après exécution
         }
      }
   }
   
   if(ema10_m1 != INVALID_HANDLE) IndicatorRelease(ema10_m1);
   if(ema30_m5 != INVALID_HANDLE) IndicatorRelease(ema30_m5);

   // 3. DÉTECTION SPIKE AVEC STRATÉGIE EMA AVANCÉE (PRIORITAIRE)
   int emaDirection = 0;
   double emaConfidence = 0;
   double emaEntry = 0, emaSL = 0, emaTP = 0;
   bool emaSpikeDetected = DetectSpikeWithEMAStrategy(_Symbol, InpSpikeTimeframe, emaDirection, emaConfidence, emaEntry, emaSL, emaTP);

   // Si un spike est détecté par la stratégie EMA avec haute confiance, l'utiliser en priorité
   if(emaSpikeDetected && emaConfidence >= InpSpikeReliabilityTarget)
   {
      PrintFormat("?? SPIKE EMA HAUTE CONFIANCE DÉTECTÉ: Direction=%s, Confiance=%.1f%%, Entry=%.5f",
                  (emaDirection > 0 ? "BUY" : "SELL"), emaConfidence, emaEntry);

      // Utiliser ce signal en priorité
      direction = emaDirection;

      // Dessiner la flèche si activé (désactivable si on ne veut que prédite/confirmée)
      if(!InpArrowsOnlyPredConfirm && InpShowArrows && ShouldDrawArrow(direction, emaEntry))
      {
         DrawSpikeArrow(direction);
         Print("?? Flèche EMA affichée - Spike haute confiance détecté");
      }

      // Passer directement à l'exécution du trade
      if(CanPlaceNewOrder() && IsTradeAllowedForSymbol(_Symbol))
      {
         PrintFormat("?? Exécution immédiate du trade EMA - Direction: %s, Entry: %.5f, SL: %.5f, TP: %.5f",
                     (direction > 0) ? "BUY" : "SELL", emaEntry, emaSL, emaTP);

         // Marquer le signal comme actif
         SetSignalActive(direction, emaEntry);

         // Exécuter le trade avec les niveaux EMA
         ExecuteTradeWithLevels(direction, atr, emaEntry, emaSL, emaTP, false, emaConfidence);
      }

      // Retourner pour éviter les autres détections
      return;
   }

   // 3b. DÉTECTION SMC (Smart Money Concepts) pour confirmer les signaux
   ENUM_STRUCT smcStructure = STRUCT_NONE;
   double trendStrength = 0;
   bool smcConfirmation = false;
   
   if(InpEnableSMC && InpUseSMCForTrading)
   {
      smcStructure = DetectSMCStructure(_Symbol, InpSpikeTimeframe);
      trendStrength = ComputeTrendStrength(_Symbol, InpSpikeTimeframe);
      
      // Confirmation SMC: BOS/CHOCH haussier pour BUY, BOS/CHOCH baissier pour SELL
      if(IsSymbolBoom(_Symbol))
      {
         smcConfirmation = (smcStructure == STRUCT_BOS_UP || smcStructure == STRUCT_CHOCH_UP) && trendStrength >= 50;
      }
      else if(IsSymbolCrash(_Symbol))
      {
         smcConfirmation = (smcStructure == STRUCT_BOS_DOWN || smcStructure == STRUCT_CHOCH_DOWN) && trendStrength >= 50;
      }

      PrintFormat("?? SMC: Structure=%d, Trend Strength=%.1f%%, Confirmation=%s",
                  smcStructure, trendStrength, smcConfirmation ? "OUI" : "NON");
   }

   // 3. DÉTECTION SCIENTIFIQUE DE SPIKE
   double scientificStrength = 0;
   int scientificDirection = 0;
   bool scientificSpike = ScientificSpikeDetection(_Symbol, InpSpikeTimeframe, scientificStrength, scientificDirection);
   
   // 3b. DÉTECTION DE SPIKE SIMPLE (pour capturer tous les spikes)
   // Pour M1, seuils plus bas pour détecter plus de signaux
   double spikeStrength = 0;
   int spikeDir = 0;
   bool simpleSpike = IsSpikeDetected(InpSpikeTimeframe, spikeStrength, spikeDir);
   
   // Ajuster les seuils pour M5 (optimisés pour entrées sniper)
   double spikeStrengthThreshold = (InpSpikeTimeframe == PERIOD_M5) ? 18.0 : 30.0; // Seuil optimisé pour M5
   if(simpleSpike && InpSpikeTimeframe == PERIOD_M1)
   {
      // Pour M1, accepter même les spikes plus faibles
      simpleSpike = (spikeStrength >= spikeStrengthThreshold);
   }
   
   // 3c. DÉTECTION DE SUCCESSION DE SPIKE (forte tendance)
   double sequenceStrength = 0;
   int sequenceDir = 0;
   bool spikeSequence = DetectSpikeSequence(InpSpikeTimeframe, sequenceDir, sequenceStrength);
   
   // Ajuster les seuils pour M5 (optimisés pour entrées sniper)
   double sequenceStrengthThreshold = (InpSpikeTimeframe == PERIOD_M5) ? 28.0 : 40.0; // Seuil optimisé pour M5
   if(spikeSequence && InpSpikeTimeframe == PERIOD_M1)
   {
      spikeSequence = (sequenceStrength >= sequenceStrengthThreshold);
   }
   
   // 4. CONDITIONS BUY (BOOM) : logique d'entrée simplifiée -> UNIQUEMENT flèche PRÉDICTIVE ou CONFIRMÉE
   if(IsSymbolBoom(_Symbol))
   {
      // Seuils ajustés pour M5 (entrées sniper optimisées)
      double confidenceThreshold = (InpSpikeTimeframe == PERIOD_M5) ? 25.0 : 30.0;
      double scientificThreshold = (InpSpikeTimeframe == PERIOD_M5) ? InpSpikeThresholdScientific * 0.6 : InpSpikeThresholdScientific * 0.7;
      double simpleThreshold = (InpSpikeTimeframe == PERIOD_M5) ? spikeStrengthThreshold : 20.0;
      double sequenceThreshold = (InpSpikeTimeframe == PERIOD_M5) ? sequenceStrengthThreshold : 30.0;
      
      bool predictionBuy = (prediction.direction > 0 && prediction.confidence >= confidenceThreshold);
      bool scientificBuy = false; // désactivé
      bool simpleBuy = false;     // désactivé
      bool sequenceBuy = false;   // désactivé
      bool emaBuy = (emaSpikeDetected && emaDirection > 0 && emaConfidence >= 70.0); // EMA avec confiance >= 70%
      bool emaConfirm = (globalTrend >= 0 || currentTfTrend >= 0);
      bool indicatorsOk = (vpin >= vp_threshold) && ((uptrend && adx >= adx_threshold) || (obi >= obi_threshold) || (cvd > 0));
      
      // Confirmation SMC pour BUY (si activé)
      bool smcBuyConfirm = true; // Par défaut, ne pas bloquer
      if(InpEnableSMC && InpUseSMCForTrading)
      {
         smcBuyConfirm = smcConfirmation || (smcStructure == STRUCT_NONE); // Accepter si SMC confirme OU si pas de structure
      }
      
      // Détecter les PRÉDICTIONS de spike (avant qu'il arrive)
      bool predictionDetected = (predictionBuy || emaBuy);

      // Détecter les SPIKES CONFIRMÉS (déjà arrivés)
      bool confirmedSpikeDetected = (scientificBuy || simpleBuy || sequenceBuy);

      // 1. Si SPIKE CONFIRMÉ détecté -> Flèche vive + Trade
      if(confirmedSpikeDetected)
      {
         // Fermer toutes les positions du robot sur ce symbole après spike confirmé
         CloseAllPositionsForSymbol(_Symbol);

         // Dessiner flèche de CONFIRMATION (couleur vive)
         if(InpShowArrows && ShouldDrawArrow(+1, prediction.entryPrice, false))
         {
            DrawSpikeArrow(+1, true); // true = spike confirmé
            Print("? Flèche BUY CONFIRMÉE affichée - Spike réalisé");
         }

         // TRADE AUTORISÉ sur spike confirmé si conditions OK
         if((emaConfirm || indicatorsOk) || InpForceTradeOnArrow)
         {
            direction = +1;
            Print("?? Signal BUY (BOOM) CONFIRMÉ - Scientifique: ", scientificBuy ? "OUI" : "NON",
                  ", Spike simple: ", simpleBuy ? "OUI" : "NON",
                  ", Succession: ", sequenceBuy ? "OUI" : "NON");
         }
      }
      // 2. Sinon si PRÉDICTION détectée -> Flèche atténuée (exécution auto déjà gérée plus haut)
      else if(predictionDetected)
      {
         // Dessiner flèche de PRÉDICTION (couleur atténuée)
         if(InpShowArrows && ShouldDrawArrow(+1, prediction.entryPrice, true))
         {
            DrawSpikeArrow(+1, false); // false = spike prédit
            Print("?? Flèche BUY PRÉDITE affichée - Spike à venir (confiance: ", prediction.confidence, "%)");
         }
      }
      // TRADE INVERSE : SELL sur Boom si tendance baissière claire
      else if(InpAllowReverseTrades)
      {
         bool predictionSell = (prediction.direction < 0 && prediction.confidence >= 50);
         bool scientificSell = (scientificDirection < 0 && scientificStrength >= InpSpikeThresholdScientific);
         bool trendClearForReverse = IsTrendClearForReverse(-1); // SELL sur Boom
         bool indicatorsOkReverse = (vpin >= vp_threshold) && ((!uptrend && adx >= adx_threshold) || (obi <= -obi_threshold) || (cvd < 0));
         
         if((predictionSell || scientificSell) && trendClearForReverse && indicatorsOkReverse)
      {
         direction = -1;
            Print("?? Signal SELL INVERSE (BOOM) détecté - Tendance baissière claire détectée");
            Print("   Prédiction: ", predictionSell ? "OUI" : "NON",
                  ", Scientifique: ", scientificSell ? "OUI" : "NON",
                  ", Tendance claire: ", trendClearForReverse ? "OUI" : "NON",
                  ", Indicateurs: ", indicatorsOkReverse ? "OK" : "NON");
         }
      }
   }
   // 5. CONDITIONS SELL (CRASH) : logique d'entrée simplifiée -> UNIQUEMENT flèche PRÉDICTIVE ou CONFIRMÉE
   else if(IsSymbolCrash(_Symbol))
   {
      // Seuils ajustés pour M5 (entrées sniper optimisées)
      double confidenceThreshold = (InpSpikeTimeframe == PERIOD_M5) ? 25.0 : 30.0;
      double scientificThreshold = (InpSpikeTimeframe == PERIOD_M5) ? InpSpikeThresholdScientific * 0.6 : InpSpikeThresholdScientific * 0.7;
      double simpleThreshold = (InpSpikeTimeframe == PERIOD_M5) ? spikeStrengthThreshold : 20.0;
      double sequenceThreshold = (InpSpikeTimeframe == PERIOD_M5) ? sequenceStrengthThreshold : 30.0;
      
      bool predictionSell = (prediction.direction < 0 && prediction.confidence >= confidenceThreshold);
      bool scientificSell = false; // désactivé
      bool simpleSell = false;     // désactivé
      bool sequenceSell = false;   // désactivé
      bool emaSell = (emaSpikeDetected && emaDirection < 0 && emaConfidence >= 70.0); // EMA avec confiance >= 70%

      // Confirmation SMC pour SELL (si activé)
      bool smcSellConfirm = true; // Par défaut, ne pas bloquer
      if(InpEnableSMC && InpUseSMCForTrading)
      {
         smcSellConfirm = smcConfirmation || (smcStructure == STRUCT_NONE); // Accepter si SMC confirme OU si pas de structure
      }
      bool emaConfirm = (globalTrend <= 0 || currentTfTrend <= 0);
      bool indicatorsOk = (vpin >= vp_threshold) && ((!uptrend && adx >= adx_threshold) || (obi <= -obi_threshold) || (cvd < 0));
      
      // Détecter les PRÉDICTIONS de spike (avant qu'il arrive)
      bool predictionDetected = (predictionSell || emaSell);

      // Détecter les SPIKES CONFIRMÉS (déjà arrivés)
      bool confirmedSpikeDetected = (scientificSell || simpleSell || sequenceSell);

      // 1. Si SPIKE CONFIRMÉ détecté -> Flèche vive + Trade
      if(confirmedSpikeDetected)
      {
         // Fermer toutes les positions du robot sur ce symbole après spike confirmé
         CloseAllPositionsForSymbol(_Symbol);

         // Dessiner flèche de CONFIRMATION (couleur vive)
         if(InpShowArrows && ShouldDrawArrow(-1, prediction.entryPrice, false))
         {
            DrawSpikeArrow(-1, true); // true = spike confirmé
            Print("? Flèche SELL CONFIRMÉE affichée - Spike réalisé");
         }

         // TRADE AUTORISÉ sur spike confirmé si conditions OK
         if(((emaConfirm || indicatorsOk) && smcSellConfirm) || InpForceTradeOnArrow)
         {
            direction = -1;
            Print("?? Signal SELL (CRASH) CONFIRMÉ - Scientifique: ", scientificSell ? "OUI" : "NON",
                  ", Spike simple: ", simpleSell ? "OUI" : "NON",
                  ", Succession: ", sequenceSell ? "OUI" : "NON");
         }
      }
      // 2. Sinon si PRÉDICTION détectée -> Flèche atténuée (exécution auto déjà gérée plus haut)
      else if(predictionDetected)
      {
         // Dessiner flèche de PRÉDICTION (couleur atténuée)
         if(InpShowArrows && ShouldDrawArrow(-1, prediction.entryPrice, true))
         {
            DrawSpikeArrow(-1, false); // false = spike prédit
            Print("?? Flèche SELL PRÉDITE affichée - Spike à venir (confiance: ", prediction.confidence, "%)");
         }
      }
      // TRADE INVERSE : BUY sur Crash si tendance haussière claire
      else if(InpAllowReverseTrades)
      {
         bool predictionBuy = (prediction.direction > 0 && prediction.confidence >= 50);
         bool scientificBuy = (scientificDirection > 0 && scientificStrength >= InpSpikeThresholdScientific);
         bool trendClearForReverse = IsTrendClearForReverse(+1); // BUY sur Crash
         bool indicatorsOkReverse = (vpin >= vp_threshold) && ((uptrend && adx >= adx_threshold) || (obi >= obi_threshold) || (cvd > 0));
         
         if((predictionBuy || scientificBuy) && trendClearForReverse && indicatorsOkReverse)
         {
            direction = +1;
            Print("?? Signal BUY INVERSE (CRASH) détecté - Tendance haussière claire détectée");
            Print("   Prédiction: ", predictionBuy ? "OUI" : "NON",
                  ", Scientifique: ", scientificBuy ? "OUI" : "NON",
                  ", Tendance claire: ", trendClearForReverse ? "OUI" : "NON",
                  ", Indicateurs: ", indicatorsOkReverse ? "OK" : "NON");
         }
      }
   }
   // 6. Fallback : utiliser FVG si présent
   else if(liquidity_sweep && fvg != 0)
   {
      if((fvg > 0 && IsSymbolBoom(_Symbol)) || (fvg < 0 && IsSymbolCrash(_Symbol)))
      {
         direction = fvg;
         Print("Signal FVG détecté -> direction prise: ", (direction>0) ? "BUY" : "SELL");
      }
   }
   
   if(direction == 0)
   {
      Print("?? Aucun signal de trade détecté - Conditions non remplies");
      PrintFormat("   Détails: Prédiction dir=%d conf=%.1f%%, SimpleSpike=%s, Sequence=%s, VPIN=%.2f, ADX=%.2f",
                  prediction.direction, prediction.confidence,
                  simpleSpike ? "OUI" : "NON",
                  spikeSequence ? "OUI" : "NON",
                  vpin, adx);
   }

   // Dessins si activés
   if(InpShowVisuals)
   {
      // Mettre à jour les EMA à chaque nouvelle bougie
      static datetime lastEMADraw = 0;
      if(t != lastEMADraw)
      {
         DrawEMAOnChart(); // Dessiner les EMA sur le graphique
         lastEMADraw = t;
      }
      
      // Afficher les indicateurs SMC modernes 2025
      if(InpEnableSMC)
      {
         DrawSMCIndicators();
      }
      
      // Dessiner les zones de pré-spike (visualisation prédictive)
      if(InpShowSpikeZones)
      {
         CleanupExpiredSpikeZones();
         DrawPreSpikeZonesForSymbol(_Symbol, InpSpikeTimeframe);
      }

      DrawOrderBlocksAroundLastBars(12, 20);
      DrawSimpleTrendline(30);
      DrawFiboOnLastMove(60);
      DrawSRZones(120, 10);
   }

   // Surveiller les positions ouvertes suite à une flèche prédictive
   MonitorPredictedTrades();

   // Gestion des flèches lorsqu'aucune direction de trade n'est déterminée
   // DISTINCTION: Spike confirmé vs prédiction
   if(direction == 0)
   {
      // 1. Vérifier si un SPIKE CONFIRMÉ a été détecté (mais pas de trade autorisé)
      bool confirmedSpikeNoTrade = (simpleSpike || spikeSequence);

      if(confirmedSpikeNoTrade)
      {
         int confirmedDir = simpleSpike ? spikeDir : sequenceDir;

         // Afficher flèche de CONFIRMATION (couleur vive) même sans trade
         if(InpShowArrows && ShouldDrawArrow(confirmedDir, prediction.entryPrice, false))
         {
            DrawSpikeArrow(confirmedDir, true); // true = spike confirmé
            Print("? Spike CONFIRMÉ détecté mais trade non autorisé (conditions manquantes)");
         }

         // Fermer toutes les positions du robot sur ce symbole après spike confirmé
         CloseAllPositionsForSymbol(_Symbol);
      }
      // 2. Sinon, si PRÉDICTION de spike détectée
      else if(prediction.direction != 0 && prediction.confidence >= 30)
      {
         // Afficher flèche de PRÉDICTION (couleur atténuée)
         if(InpShowArrows && ShouldDrawArrow(prediction.direction, prediction.entryPrice, true))
         {
            DrawSpikeArrow(prediction.direction, false); // false = spike prédit
            Print("?? Spike PRÉDIT (confiance: ", prediction.confidence, "%) - En attente de confirmation");
         }
      }
   }
   else
   {
      // Une direction de trade a été déterminée
      // Les flèches ont déjà été dessinées dans les conditions BUY/SELL ci-dessus
      if(InpForceTradeOnArrow)
      {
         Print("?? Signal de trade validé - Exécution prévue");
      }
   }

   // Exécution (si permissions et conditions remplies)
   // Si InpForceTradeOnArrow est activé, on prend la position même si certaines conditions ne sont pas parfaites
   if(direction != 0)
   {
      Print("?? Signal de trade détecté - Direction: ", (direction > 0 ? "BUY" : "SELL"));
      
      if(CanPlaceNewOrder())
      {
         Print("? Permissions OK - Tentative d'exécution du trade...");
      
      // DÉSACTIVÉ: Permettre le trading même avec des positions ouvertes ou signaux actifs
      // if(!HasOpenPosition() && !IsSignalActive())
      // Permettre le trading en continu pour capturer tous les spikes
      bool allowTrading = true;
      if(allowTrading)
      {
         // Vérifier si c'est un trade inverse (SELL sur Boom ou BUY sur Crash)
         bool isReverseTrade = false;
         if((direction > 0 && IsSymbolCrash(_Symbol)) || (direction < 0 && IsSymbolBoom(_Symbol)))
         {
            isReverseTrade = true;
         }
         // Vérifier que la direction est autorisée (sauf si trade inverse autorisé)
         else if((direction > 0 && !IsSymbolBoom(_Symbol)) || (direction < 0 && !IsSymbolCrash(_Symbol)))
         {
            if(!isReverseTrade || !InpAllowReverseTrades)
            {
               Print("? Trade bloqué : Direction non autorisée pour ce symbole (Boom/Crash rule).");
            return;
            }
         }
         
         // Vérifier si le prix a suffisamment bougé depuis le dernier signal
         double currentPrice = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         // Utiliser les niveaux de la prédiction si disponibles
         double sl = prediction.stopLoss;
         double tp = prediction.takeProfit;
         
         // Si la prédiction n'a pas de niveaux valides, utiliser les valeurs par défaut basées sur ATR
         // Ajuster pour M1 avec distances plus courtes
         double slMult = (InpSpikeTimeframe == PERIOD_M1) ? InpSLMultiplierM1 : 2.0;
         double tpMult = (InpSpikeTimeframe == PERIOD_M1) ? InpTPMultiplierM1 : 4.0;
         
         if(sl == 0 || tp == 0)
         {
            if(direction > 0)
            {
               // Pour les trades inverses, utiliser des SL/TP plus serrés
               if(isReverseTrade)
               {
                  sl = currentPrice - atr * InpReverseTradeSLMult;
                  tp = currentPrice + atr * InpReverseTradeTPMult;
               }
               else
               {
                  sl = currentPrice - atr * slMult; // Ajusté pour M1
                  tp = currentPrice + atr * tpMult;  // Ajusté pour M1
               }
            }
            else
            {
               // Pour les trades inverses, utiliser des SL/TP plus serrés
               if(isReverseTrade)
               {
                  sl = currentPrice + atr * InpReverseTradeSLMult;
                  tp = currentPrice - atr * InpReverseTradeTPMult;
               }
               else
               {
                  sl = currentPrice + atr * slMult; // Ajusté pour M1
                  tp = currentPrice - atr * tpMult;  // Ajusté pour M1
               }
            }
         }
         else if(isReverseTrade)
         {
            // Ajuster les niveaux de la prédiction pour les trades inverses (plus serrés)
            double slDistance = MathAbs(currentPrice - sl);
            double tpDistance = MathAbs(tp - currentPrice);
            
            if(direction > 0)
            {
               sl = currentPrice - (slDistance * InpReverseTradeSLMult / 2.0);
               tp = currentPrice + (tpDistance * InpReverseTradeTPMult / 4.0);
            }
            else
            {
               sl = currentPrice + (slDistance * InpReverseTradeSLMult / 2.0);
               tp = currentPrice - (tpDistance * InpReverseTradeTPMult / 4.0);
            }
         }
         
         if(isReverseTrade)
         {
            Print("?? TRADE INVERSE - SL/TP ajustés pour plus de prudence");
         }
         
         // Marquer le signal comme actif avant d'exécuter le trade
         SetSignalActive(direction, currentPrice);
         
         string tradeType = isReverseTrade ? "INVERSE" : "NORMAL";
         
         PrintFormat("?? Exécution du trade %s - Direction: %s, Entry: %.5f, SL: %.5f, TP: %.5f", 
                     tradeType,
                     (direction > 0) ? "BUY" : "SELL", 
                     currentPrice, sl, tp);
         
         // Exécuter le trade avec les niveaux calculés
         // Passer la confiance du signal pour décider de l'exécution immédiate
         double signalConfidence = prediction.confidence;
         ExecuteTradeWithLevels(direction, atr, currentPrice, sl, tp, isReverseTrade, signalConfidence);
      }
      else
      {
         // DÉSACTIVÉ: Permettre le trading même avec positions/signaux actifs
         // if(HasOpenPosition())
         //    Print("?? Trade non exécuté - Une position est déjà ouverte");
         // else if(IsSignalActive())
         //    Print("?? Trade non exécuté - Un signal est déjà actif pour ce symbole");
         Print("?? Trade non exécuté - Conditions non remplies (mais blocages désactivés)");
      }
      }
      else
      {
         Print("? Permissions de trading non remplies - Vérifier les paramètres");
         string debugMsg = "Raisons possibles:\n";
         if(!InpEnableTrading) debugMsg += "- Trading désactivé dans les paramètres\n";
         if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) debugMsg += "- Trading non autorisé par le terminal\n";
         if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) debugMsg += "- Trading non autorisé pour ce compte\n";
         if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) debugMsg += "- Trading automatisé non autorisé\n";
         if(!TerminalInfoInteger(TERMINAL_CONNECTED)) debugMsg += "- Pas de connexion au serveur\n";
         Print(debugMsg);
      }
   }
   else if(InpShowArrows)
   {
      // Même sans signal de trade, afficher les flèches si des spikes sont détectés
      Print("?? Pas de signal de trade mais vérification des spikes pour affichage...");
   }
}

//+------------------------------------------------------------------+
//| Helpers: identification Boom/Crash                               |
//+------------------------------------------------------------------+
bool IsSymbolBoom(string s)
{
   if(StringFind(s,"Boom",0) != -1) return true;
   if(StringFind(s,"BOOM",0) != -1) return true;
   if(StringFind(s,"boom",0) != -1) return true;
   return false;
}
bool IsSymbolCrash(string s)
{
   if(StringFind(s,"Crash",0) != -1) return true;
   if(StringFind(s,"CRASH",0) != -1) return true;
   if(StringFind(s,"crash",0) != -1) return true;
   return false;
}

//+------------------------------------------------------------------+
//| Ajoute une zone de volume au graphique                           |
//+------------------------------------------------------------------+
void AddVolumeProfile()
{
   string vpName = "FXPRO_" + (string)InpMagicNumber + "_VP";
   ObjectDelete(0, vpName);
   datetime end = TimeCurrent();
   datetime start = end - PeriodSeconds(PERIOD_D1) * 5; // 5 jours
   double high = iHigh(_Symbol, PERIOD_D1, iHighest(_Symbol, PERIOD_D1, MODE_HIGH, 5, 0));
   double low = iLow(_Symbol, PERIOD_D1, iLowest(_Symbol, PERIOD_D1, MODE_LOW, 5, 0));
   if(!ObjectCreate(0, vpName, OBJ_RECTANGLE, 0, start, high, end, low))
   {
      Print("Erreur création zone de volume: ", GetLastError());
      return;
   }
   ObjectSetInteger(0, vpName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, vpName, OBJPROP_BACK, true);
   ObjectSetInteger(0, vpName, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, vpName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, vpName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, vpName, OBJPROP_BGCOLOR, clrDodgerBlue);
   ObjectSetInteger(0, vpName, OBJPROP_FILL, true);
   ObjectSetInteger(0, vpName, OBJPROP_SELECTABLE, false);
   Print("Zone de volume ajoutée du ", TimeToString(start), " au ", TimeToString(end));
}

//+------------------------------------------------------------------+
//| Fonctions utilitaires                                            |
//+------------------------------------------------------------------+
long GetBarsCount(string symbol, ENUM_TIMEFRAMES tf)
{
   long cnt = SeriesInfoInteger(symbol, tf, SERIES_BARS_COUNT);
   if(cnt < 0) cnt = 0;
   return cnt;
}

double GetCurrentATR(string symbol)
{
   // Obtenir l'index des handles pour le symbole spécifié
   int index = GetSymbolHandleIndex(symbol);
   if(index < 0 || g_symbolHandles[index].atr_handle == INVALID_HANDLE)
   {
      // Si le handle n'existe pas, essayer de le créer temporairement
      int tempHandle = iATR(symbol, InpSpikeTimeframe, 14);
      if(tempHandle == INVALID_HANDLE) return 0.0;
      
      double buf[];
      if(CopyBuffer(tempHandle, 0, 0, 1, buf) <= 0)
      {
         IndicatorRelease(tempHandle);
         return 0.0;
      }
      
      double atr = buf[0];
      IndicatorRelease(tempHandle);
      return atr;
   }
   
   double buf[];
   if(CopyBuffer(g_symbolHandles[index].atr_handle, 0, 0, 1, buf) <= 0) return 0.0;
   return buf[0];
}

// VPIN proxy
double ComputeVPIN(int windowBars, ENUM_TIMEFRAMES tf)
{
   if(windowBars <= 10) return 0.0;
   MqlRates rates[];
   int copied = CopyRates(_Symbol, tf, 1, windowBars, rates);
   if(copied <= 0) return 0.0;
   double buyVol=0.0, sellVol=0.0, totalVol=0.0;
   for(int i=0; i<copied; i++)
   {
      long tv = rates[i].tick_volume;
      totalVol += (double)tv;
      if(rates[i].close > rates[i].open) buyVol += (double)tv;
      else if(rates[i].close < rates[i].open) sellVol += (double)tv;
      else { buyVol += (double)tv*0.5; sellVol += (double)tv*0.5; }
   }
   if(totalVol <= 0.0) return 0.0;
   return MathAbs(buyVol - sellVol) / totalVol;
}

// OBI proxy
double ComputeOBI(int lookbackBars, ENUM_TIMEFRAMES tf)
{
   if(lookbackBars <= 10) return 0.0;
   MqlRates rates[];
   int copied = CopyRates(_Symbol, tf, 1, lookbackBars, rates);
   if(copied <= 0) return 0.0;
   double buyVol=0.0, sellVol=0.0;
   for(int i=0; i<copied; i++)
   {
      long tv = rates[i].tick_volume;
      if(rates[i].close > rates[i].open) buyVol += (double)tv;
      else if(rates[i].close < rates[i].open) sellVol += (double)tv;
   }
   double total = buyVol + sellVol;
   if(total <= 0.0) return 0.0;
   return (buyVol - sellVol) / total;
}

// CVD proxy
double ComputeCVD(int windowBars, ENUM_TIMEFRAMES tf)
{
   if(windowBars <= 5) return 0.0;
   MqlRates rates[];
   int copied = CopyRates(_Symbol, tf, 1, windowBars, rates);
   if(copied <= 0) return 0.0;
   double cvd = 0.0;
   for(int i=0; i<copied; i++)
   {
      double sign = 0.0;
      if(rates[i].close > rates[i].open) sign = 1.0;
      else if(rates[i].close < rates[i].open) sign = -1.0;
      cvd += sign * (double)rates[i].tick_volume;
   }
   return cvd;
}

bool DetectLiquiditySweep(ENUM_TIMEFRAMES tf, double atr_val, double wickMult)
{
   if(atr_val <= 0.0) return false;
   MqlRates r[];
   if(CopyRates(_Symbol, tf, 1, 2, r) < 2) return false;
   double high = r[0].high, low = r[0].low, open = r[0].open, close = r[0].close;
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   if(upperWick > wickMult * atr_val || lowerWick > wickMult * atr_val) return true;
   return false;
}

int DetectFVG(ENUM_TIMEFRAMES tf)
{
   MqlRates r[];
   if(CopyRates(_Symbol, tf, 1, 3, r) < 3) return 0;
   double prevClose = r[1].close;
   double curOpen   = r[0].open;
   if(curOpen - prevClose > 0.0) return +1;
   if(prevClose - curOpen > 0.0) return -1;
   return 0;
}

//+------------------------------------------------------------------+
//| ========== SMC (Smart Money Concepts) 2025 - FONCTIONS MODERNES ========== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Détection des swings (hauts/bas locaux)                          |
//+------------------------------------------------------------------+
int DetectSwings(string symbol, ENUM_TIMEFRAMES tf, int bars, int window, SwingPoint &swings[])
{
   double highs[], lows[];
   ArrayResize(highs, bars);
   ArrayResize(lows, bars);
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   int ch = CopyHigh(symbol, tf, 0, bars, highs);
   int cl = CopyLow(symbol, tf, 0, bars, lows);
   if(ch <= 0 || cl <= 0) return 0;

   int count = 0;
   for(int i = window; i < bars - window; i++)
   {
      bool isHigh=false, isLow=false;
      double valH = highs[i];
      double valL = lows[i];
      
      // Détection swing high
      bool higher=true;
      for(int k=1;k<=window;k++) 
         if(highs[i-k] >= valH || highs[i+k] >= valH) { higher=false; break; }
      if(higher) isHigh=true;
      
      // Détection swing low
      bool lower=true;
      for(int k=1;k<=window;k++) 
         if(lows[i-k] <= valL || lows[i+k] <= valL) { lower=false; break; }
      if(lower) isLow=true;

      if(isHigh)
      {
         ArrayResize(swings, count+1);
         swings[count].index = i;
         swings[count].price = valH;
         swings[count].isHigh = true;
         count++;
      }
      if(isLow)
      {
         ArrayResize(swings, count+1);
         swings[count].index = i;
         swings[count].price = valL;
         swings[count].isHigh = false;
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Détection BOS/CHOCH (Break of Structure / Change of Character)   |
//+------------------------------------------------------------------+
ENUM_STRUCT DetectSMCStructure(string symbol, ENUM_TIMEFRAMES tf)
{
   SwingPoint swings[];
   int n = DetectSwings(symbol, tf, InpSMCLookback, InpSwingWindow, swings);
   if(n < 4) return STRUCT_NONE;

   // Trouver les deux derniers swing highs et lows
   double lastHigh = -1, prevHigh = -1, lastLow = -1, prevLow = -1;
   for(int i = n-1; i>=0; i--)
   {
      if(swings[i].isHigh)
      {
         if(lastHigh < 0) lastHigh = swings[i].price;
         else if(prevHigh < 0) { prevHigh = swings[i].price; }
      }
      if(swings[i].isHigh && lastHigh>=0 && prevHigh>=0) break;
   }
   for(int i = n-1; i>=0; i--)
   {
      if(!swings[i].isHigh)
      {
         if(lastLow < 0) lastLow = swings[i].price;
         else if(prevLow < 0) { prevLow = swings[i].price; }
      }
      if(lastLow>=0 && prevLow>=0) break;
   }

   // Prix actuel
   double price_buf[];
   ArrayResize(price_buf,1);
   if(CopyClose(symbol, tf, 0, 1, price_buf) <= 0) return STRUCT_NONE;
   double price = price_buf[0];

   // BOS UP: prix casse au-dessus du swing high précédent
   if(prevHigh > 0 && price > prevHigh)
   {
      if(lastLow > 0 && price < lastLow) return STRUCT_CHOCH_UP;
      return STRUCT_BOS_UP;
   }
   // BOS DOWN: prix casse en dessous du swing low précédent
   if(prevLow > 0 && price < prevLow)
   {
      if(lastHigh > 0 && price > lastHigh) return STRUCT_CHOCH_DOWN;
      return STRUCT_BOS_DOWN;
   }
   return STRUCT_NONE;
}

//+------------------------------------------------------------------+
//| Détection FVG améliorée (Fair Value Gaps)                        |
//+------------------------------------------------------------------+
int DetectFVGAdvanced(string symbol, ENUM_TIMEFRAMES tf, int lookback, FVGZone &zones[])
{
   int bars = MathMin(lookback, 200);
   double opens[], highs[], lows[], closes[];
   ArraySetAsSeries(opens,true); ArraySetAsSeries(highs,true); 
   ArraySetAsSeries(lows,true); ArraySetAsSeries(closes,true);
   if(CopyOpen(symbol, tf, 0, bars, opens) <= 0) return 0;
   CopyHigh(symbol, tf, 0, bars, highs);
   CopyLow(symbol, tf, 0, bars, lows);
   CopyClose(symbol, tf, 0, bars, closes);

   int count = 0;
   double minFVGSize = InpMinFVGSizePips * _Point;
   
   for(int i = 0; i < bars - 2; i++)
   {
      // Bullish FVG: low[i+2] > high[i] (gap vers le haut)
      if(highs[i] < lows[i+2] - minFVGSize)
      {
         ArrayResize(zones, count+1);
         zones[count].bar_time_index = i;
         zones[count].top = lows[i+2];
         zones[count].bottom = highs[i];
         zones[count].tf = tf;
         zones[count].time = iTime(symbol, tf, i);
         zones[count].bullish = true;
         count++;
      }
      // Bearish FVG: high[i+2] < low[i] (gap vers le bas)
      else if(lows[i] > highs[i+2] + minFVGSize)
      {
         ArrayResize(zones, count+1);
         zones[count].bar_time_index = i;
         zones[count].top = lows[i];
         zones[count].bottom = highs[i+2];
         zones[count].tf = tf;
         zones[count].time = iTime(symbol, tf, i);
         zones[count].bullish = false;
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Détection Order Blocks améliorée                                 |
//+------------------------------------------------------------------+
int DetectOrderBlocksAdvanced(string symbol, ENUM_TIMEFRAMES tf, int lookback, OBZone &obs[])
{
   int bars = MathMin(lookback, 200);
   double opens[], highs[], lows[], closes[];
   ArraySetAsSeries(opens,true); ArraySetAsSeries(highs,true); 
   ArraySetAsSeries(lows,true); ArraySetAsSeries(closes,true);
   if(CopyOpen(symbol, tf, 0, bars, opens) <= 0) return 0;
   CopyHigh(symbol, tf, 0, bars, highs);
   CopyLow(symbol, tf, 0, bars, lows);
   CopyClose(symbol, tf, 0, bars, closes);
   
   int count = 0;
   double atr = GetATRValue(symbol, tf, InpATR_Period);
   
   for(int i = 3; i < bars-3; i++)
   {
      // Candle i est un OB potentiel si body petit et mouvement fort après
      double body_i = MathAbs(opens[i]-closes[i]);
      double range_next = MathAbs(closes[i-2] - closes[i+1]);
      
      if(body_i < (atr * 0.5) && range_next > (atr * 1.2))
      {
         // Bullish OB si mouvement suivant vers le haut
         if(closes[i-1] < closes[i+1])
         {
            ArrayResize(obs, count+1);
            obs[count].time1 = iTime(symbol, tf, i+1);
            obs[count].time2 = iTime(symbol, tf, i-1);
            obs[count].high = highs[i];
            obs[count].low  = lows[i];
            obs[count].tf = tf;
            obs[count].bullish = true;
            count++;
         }
         // Bearish OB si mouvement suivant vers le bas
         else if(closes[i-1] > closes[i+1])
         {
            ArrayResize(obs, count+1);
            obs[count].time1 = iTime(symbol, tf, i+1);
            obs[count].time2 = iTime(symbol, tf, i-1);
            obs[count].high = highs[i];
            obs[count].low  = lows[i];
            obs[count].tf = tf;
            obs[count].bullish = false;
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calcul de Trend Strength (force de tendance)                     |
//+------------------------------------------------------------------+
double ComputeTrendStrength(string symbol, ENUM_TIMEFRAMES tf)
{
   // ADX
   double adx = GetADXValue(symbol, tf, InpADX_Period);
   double adx_s = NormalizeTo100(adx, 10, 50);
   
   // RSI
   double rsi = GetRSIValue(symbol, tf, 14);
   double rsi_s = MathAbs(rsi - 50.0) * 2.0;
   
   // MA Slope
   double slope = GetMASlope(symbol, tf, 34);
   double price_buf[];
   ArrayResize(price_buf, 2);
   if(CopyClose(symbol, tf, 0, 2, price_buf) <= 1) return 0;
   double price = price_buf[0];
   double max_slope = price * 0.001;
   double slope_s = 0;
   if(max_slope > 0) 
      slope_s = NormalizeTo100(MathAbs(slope), 0, max_slope);
   
   // ATR
   double atr = GetATRValue(symbol, tf, InpATR_Period);
   double max_atr = price * 0.003;
   double atr_s = 0;
   if(max_atr > 0)
      atr_s = NormalizeTo100(atr, 0, max_atr);
   
   // Score pondéré
   double score = (adx_s * 0.40) + (rsi_s * 0.30) + (slope_s * 0.20) + (atr_s * 0.10);
   return MathMax(0, MathMin(100, score));
}

//+------------------------------------------------------------------+
//| Fonctions utilitaires pour SMC                                   |
//+------------------------------------------------------------------+
double GetATRValue(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   // Obtenir l'index des handles pour le symbole spécifique
   int index = GetSymbolHandleIndex(symbol);
   if(index < 0 || g_symbolHandles[index].atr_handle == INVALID_HANDLE)
   {
      // Si le handle n'existe pas, créer un handle temporaire
      int h = iATR(symbol, tf, period);
      if(h == INVALID_HANDLE) return 0.0;
      double buf[];
      ArrayResize(buf,1);
      if(CopyBuffer(h,0,0,1,buf) > 0) { IndicatorRelease(h); return buf[0]; }
      IndicatorRelease(h);
      return 0.0;
   }
   
   // Utiliser le handle existant
   double buf[];
   ArrayResize(buf,1);
   if(CopyBuffer(g_symbolHandles[index].atr_handle,0,0,1,buf) > 0) return buf[0];
   return 0.0;
}

double GetRSIValue(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   // Créer un handle RSI temporaire (non optimisé pour le moment)
   int h = iRSI(symbol, tf, period, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArrayResize(buf,1);
   if(CopyBuffer(h,0,0,1,buf) > 0) { IndicatorRelease(h); return buf[0]; }
   IndicatorRelease(h);
   return 0.0;
}

double GetADXValue(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   // Utiliser ComputeADX qui est déjà optimisé
   return ComputeADX(symbol, tf, period);
}

double GetMASlope(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   // Obtenir l'index des handles pour le symbole spécifié
   int index = GetSymbolHandleIndex(symbol);
   if(index < 0)
   {
      // Si le handle n'existe pas, créer un handle temporaire
      int h = iMA(symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
      if(h == INVALID_HANDLE) return 0.0;
      double buf[];
      ArrayResize(buf, 3);
      if(CopyBuffer(h, 0, 0, 3, buf) < 2) { IndicatorRelease(h); return 0.0; }
      double slope = buf[0] - buf[1];
      IndicatorRelease(h);
      return slope;
   }
   
   // Créer un handle MA temporaire pour le calcul de pente
   int h = iMA(symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArrayResize(buf, 3);
   if(CopyBuffer(h, 0, 0, 3, buf) < 2) { IndicatorRelease(h); return 0.0; }
   double slope = buf[0] - buf[1];
   IndicatorRelease(h);
   return slope;
}

double NormalizeTo100(double value, double minv, double maxv)
{
   if(maxv == minv) return 0;
   double res = (value - minv) / (maxv - minv) * 100.0;
   if(res < 0) res = 0;
   if(res > 100) res = 100;
   return res;
}

int FindLastSwingIndex(string symbol, ENUM_TIMEFRAMES tf, bool wantHigh, int lookback)
{
   SwingPoint swings[];
   int n = DetectSwings(symbol, tf, lookback, InpSwingWindow, swings);
   for(int i = n-1; i>=0; i--)
      if(swings[i].isHigh == wantHigh) return swings[i].index;
   return -1;
}

//+------------------------------------------------------------------+
//| ========== FONCTIONS DE DESSIN SMC 2025 ========== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Dessine un FVG sur le graphique                                   |
//+------------------------------------------------------------------+
void DrawFVGRectangle(string baseName, ENUM_TIMEFRAMES tf, double top, double bottom, int idx, bool bullish)
{
   string nm = baseName + "_FVG_" + EnumToString(tf) + "_" + IntegerToString(idx);
   datetime time1 = iTime(_Symbol, tf, idx);
   datetime time2 = time1 + PeriodSeconds(tf) * 20; // Étendre sur 20 bougies
   
   if(ObjectFind(0,nm) < 0)
      ObjectCreate(0, nm, OBJ_RECTANGLE, 0, time1, top, time2, bottom);
   
   color clr = bullish ? clrMediumPurple : clrMediumOrchid;
   ObjectSetInteger(0, nm, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nm, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, top);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, bottom);
}

//+------------------------------------------------------------------+
//| Dessine un Order Block sur le graphique                          |
//+------------------------------------------------------------------+
void DrawOBRectangle(string baseName, const OBZone &ob, int idx)
{
   string nm = baseName + "_OB_" + IntegerToString(ob.tf) + "_" + IntegerToString(idx);
   
   if(ObjectFind(0, nm) < 0)
   {
      if(!ObjectCreate(0, nm, OBJ_RECTANGLE, 0, ob.time1, ob.high, ob.time2, ob.low))
      {
         Print("Erreur création rectangle OB: ", GetLastError());
         return;
      }
   }
   
   color c = ob.bullish ? clrDodgerBlue : clrOrangeRed;
   ObjectSetInteger(0, nm, OBJPROP_COLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, c);
   ObjectSetInteger(0, nm, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, nm, OBJPROP_BACK, true);
   ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, nm, OBJPROP_FILL, true);
   ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nm, OBJPROP_TIME, 0, ob.time1);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 0, ob.high);
   ObjectSetInteger(0, nm, OBJPROP_TIME, 1, ob.time2);
   ObjectSetDouble(0, nm, OBJPROP_PRICE, 1, ob.low);
}

//+------------------------------------------------------------------+
//| Dessine une ligne BOS (Break of Structure)                        |
//+------------------------------------------------------------------+
void DrawBOSLine(string baseName, ENUM_TIMEFRAMES tf, double price, bool up, int idx)
{
   string nm = baseName + "_BOS_" + EnumToString(tf) + "_" + IntegerToString(idx);
   if(ObjectFind(0,nm) < 0)
      ObjectCreate(0,nm,OBJ_HLINE,0,0,price);
   ObjectSetInteger(0,nm,OBJPROP_COLOR, up ? clrLime : clrRed);
   ObjectSetInteger(0,nm,OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Dessine un marqueur CHOCH (Change of Character)                   |
//+------------------------------------------------------------------+
void DrawCHOCHMarker(string baseName, ENUM_TIMEFRAMES tf, double price, bool up, int idx)
{
   string nm = baseName + "_CHOCH_" + EnumToString(tf) + "_" + IntegerToString(idx);
   datetime time = iTime(_Symbol, tf, 0);
   bool isNewArrow = (ObjectFind(0,nm) < 0);
   
   if(isNewArrow)
      ObjectCreate(0,nm,OBJ_ARROW,0,time,price);
   
   ObjectSetInteger(0,nm,OBJPROP_ARROWCODE, up ? 233 : 234);
   ObjectSetInteger(0,nm,OBJPROP_COLOR, up ? clrBlue : clrMagenta);
   ObjectSetInteger(0,nm,OBJPROP_WIDTH,3);
   ObjectSetInteger(0,nm,OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0,nm,OBJPROP_SELECTABLE, false);
   
   // Si c'est une nouvelle flèche CHOCH, envoyer une notification
   if(isNewArrow)
   {
      NotifyCHOCHSignal(_Symbol, tf, price, up);
   }
}

//+------------------------------------------------------------------+
//| Notifie l'apparition d'une flèche CHOCH avec les détails du signal |
//+------------------------------------------------------------------+
void NotifyCHOCHSignal(string symbol, ENUM_TIMEFRAMES tf, double price, bool isUp)
{
   if(!InpEnableNotifications)
      return;
   
   // Déterminer la direction du signal
   int direction = isUp ? 1 : -1; // 1 = BUY, -1 = SELL
   string signalType = isUp ? "BUY (LONG)" : "SELL (SHORT)";
   
   // Obtenir le prix actuel
   double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double currentPrice = (direction > 0) ? currentBid : currentAsk;
   
   // Calculer les pips pour SL et TP
   double pipSize = (StringFind(symbol, "JPY") >= 0) ? 0.01 : 0.0001;
   if(StringFind(symbol, "Index") >= 0 || StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0)
      pipSize = 0.1;
   
   // Calculer l'ATR pour déterminer les distances SL/TP
   double atr = GetCurrentATR(symbol);
   
   // Si ATR non disponible, calculer depuis les rates ou créer un handle temporaire
   if(atr <= 0)
   {
      // Essayer de créer un handle ATR pour ce symbole
      int tempATRHandle = iATR(symbol, tf, InpATR_Period);
      if(tempATRHandle != INVALID_HANDLE)
      {
         double buf[];
         if(CopyBuffer(tempATRHandle, 0, 0, 1, buf) > 0)
            atr = buf[0];
         IndicatorRelease(tempATRHandle);
      }
   }
   
   // Si ATR toujours 0, utiliser la plage de la dernière bougie
   if(atr <= 0)
   {
      MqlRates rates[];
      if(CopyRates(symbol, tf, 0, 1, rates) > 0)
         atr = rates[0].high - rates[0].low;
   }
   
   // Si ATR toujours 0, utiliser une valeur par défaut
   if(atr <= 0)
   {
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      atr = point * 100; // Valeur par défaut
   }
   
   // Calculer les niveaux SL et TP
   // Pour CHOCH, utiliser des ratios basés sur l'ATR
   double slDistance = atr * 1.5;  // SL à 1.5 ATR
   double tpDistance = atr * 3.0;   // TP à 3.0 ATR (ratio 1:2)
   
   double entryPrice = price;
   double sl, tp;
   
   if(direction > 0) // BUY
   {
      // Pour BUY, SL en dessous et TP au-dessus
      sl = entryPrice - slDistance;
      tp = entryPrice + tpDistance;
   }
   else // SELL
   {
      // Pour SELL, SL au-dessus et TP en dessous
      sl = entryPrice + slDistance;
      tp = entryPrice - tpDistance;
   }
   
   // Normaliser les prix
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   entryPrice = NormalizeDouble(entryPrice, digits);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   // Calculer les distances en pips
   double slPips = (direction > 0) ? (entryPrice - sl) / pipSize : (sl - entryPrice) / pipSize;
   double tpPips = (direction > 0) ? (tp - entryPrice) / pipSize : (entryPrice - tp) / pipSize;
   
   // Créer le message de notification
   string message = StringFormat(
      "%s\n\n" +
      "?? FLÈCHE CHOCH DÉTECTÉE - FXPRO_SMC_CHOCH\n\n" +
      "Symbole: %s\n" +
      "Timeframe: %s\n" +
      "Signal: %s\n" +
      "Prix d'entrée: %.5f\n" +
      "Stop Loss: %.5f (%.1f pips)\n" +
      "Take Profit: %.5f (%.1f pips)\n" +
      "Ratio R/R: 1:%.1f\n" +
      "Temps: %s\n" +
      "%s",
      GetAlgorithmHeader(),
      symbol,
      EnumToString(tf),
      signalType,
      entryPrice,
      sl,
      slPips,
      tp,
      tpPips,
      (tpPips / slPips),
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
      GetSignalSeparator()
   );
   
   // Envoyer la notification MT5
   SendNotification(message);
   
   // Afficher dans le journal
   PrintFormat("?? NOTIFICATION CHOCH: %s %s - Entry=%.5f, SL=%.5f, TP=%.5f",
               symbol, signalType, entryPrice, sl, tp);
   
   // Exécuter automatiquement l'ordre le plus confiant (direct) ou placer en limite
   if(InpEnableTrading)
   {
      // Compter le nombre de positions ouvertes (directes)
      int openPositions = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && PositionSelectByTicket(ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               openPositions++;
            }
         }
      }
      
      // Si on a moins de 2 positions directes, exécuter directement l'ordre le plus confiant
      // Sinon, placer un ordre limite
      if(openPositions < 2)
      {
         // Exécuter directement l'ordre le plus confiant
         PrintFormat("?? EXÉCUTION DIRECTE CHOCH: %s %s - Entry=%.5f, SL=%.5f, TP=%.5f",
                     symbol, signalType, entryPrice, sl, tp);
         ExecuteDirectTrade(symbol, direction, entryPrice, sl, tp, 100.0); // Confiance 100% pour CHOCH
      }
      else
      {
         // Placer un ordre limite car on a déjà 2 positions directes
         PrintFormat("?? ORDRE LIMITE CHOCH (déjà %d positions directes): %s %s - Entry=%.5f, SL=%.5f, TP=%.5f",
                     openPositions, symbol, signalType, entryPrice, sl, tp);
         PlaceLimitOrderFromSignal(symbol, direction, entryPrice, sl, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Nettoie les objets SMC précédents                                 |
//+------------------------------------------------------------------+
void ClearSMCObjects()
{
   int total = ObjectsTotal(0);
   for(int i=total-1;i>=0;i--)
   {
      string nm = ObjectName(0,i);
      if(StringFind(nm,"SMC_")==0 || StringFind(nm,"FXPRO_SMC_")==0)
         ObjectDelete(0,nm);
   }
}

//+------------------------------------------------------------------+
//| Affiche tous les indicateurs SMC sur le graphique                 |
//+------------------------------------------------------------------+
void DrawSMCIndicators()
{
   if(!InpEnableSMC) return;
   
   string symbol = _Symbol;
   ENUM_TIMEFRAMES tf = InpSpikeTimeframe;
   
   // Détecter et afficher BOS/CHOCH
   if(InpShowBOS || InpShowCHOCH)
   {
      ENUM_STRUCT structure = DetectSMCStructure(symbol, tf);
      
      if(structure == STRUCT_BOS_UP && InpShowBOS)
      {
         int idx = FindLastSwingIndex(symbol, tf, true, InpSMCLookback);
         if(idx > 0)
         {
            double price_buf[];
            ArrayResize(price_buf,1);
            if(CopyHigh(symbol, tf, idx, 1, price_buf) > 0)
               DrawBOSLine("FXPRO_SMC", tf, price_buf[0], true, 0);
         }
      }
      else if(structure == STRUCT_BOS_DOWN && InpShowBOS)
      {
         int idx = FindLastSwingIndex(symbol, tf, false, InpSMCLookback);
         if(idx > 0)
         {
            double price_buf[];
            ArrayResize(price_buf,1);
            if(CopyLow(symbol, tf, idx, 1, price_buf) > 0)
               DrawBOSLine("FXPRO_SMC", tf, price_buf[0], false, 0);
         }
      }
      else if((structure == STRUCT_CHOCH_UP || structure == STRUCT_CHOCH_DOWN) && InpShowCHOCH)
      {
         double price_buf[];
         ArrayResize(price_buf,1);
         if(CopyClose(symbol, tf, 0, 1, price_buf) > 0)
            DrawCHOCHMarker("FXPRO_SMC", tf, price_buf[0], structure==STRUCT_CHOCH_UP, 0);
      }
   }
   
   // Détecter et afficher FVG
   if(InpShowFVG)
   {
      FVGZone fvg[];
      int nf = DetectFVGAdvanced(symbol, tf, 120, fvg);
      for(int j=0;j<MathMin(nf,5);j++) // Afficher max 5 FVG
         DrawFVGRectangle("FXPRO_SMC", tf, fvg[j].top, fvg[j].bottom, fvg[j].bar_time_index, fvg[j].bullish);
   }
   
   // Détecter et afficher Order Blocks
   if(InpShowOrderBlocks)
   {
      OBZone obs[];
      int no = DetectOrderBlocksAdvanced(symbol, tf, InpMaxOBLookback, obs);
      for(int j=0;j<MathMin(no,3);j++) // Afficher max 3 OB
         DrawOBRectangle("FXPRO_SMC", obs[j], j);
   }
}

// ------------------ Visuals (OB, Trend, Fibo, SR, Flèches) ------------------
void DeleteAllEAObjects()
{
   string prefix = "FXPRO_" + (string)InpMagicNumber + "_";
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0) ObjectDelete(0, name);
   }
}

void DrawOrderBlocksAroundLastBars(int lookbackBars, int widthBars)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);

   if(CopyRates(_Symbol, InpSpikeTimeframe, 0, lookbackBars, r) < lookbackBars) return;

   string prefix = "FXPRO_" + (string)InpMagicNumber + "_OB_";
   for(int i=0; i<lookbackBars-1; i++)
   {
      double body = MathAbs(r[i].close - r[i].open);
      double range = r[i].high - r[i].low;
      if(range <= 0) continue;
      if(body >= 0.6 * range)
      {
         datetime t_high = r[i].time;
         double price_high = r[i].high;
         double price_low  = r[i].low;
         string name = prefix + IntegerToString((int)t_high);
         if(ObjectFind(0, name) == -1)
         {
            datetime t2 = t_high + (datetime)(widthBars * PeriodSeconds(InpSpikeTimeframe));
            if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t_high, price_high, t2, price_low))
               Print("ObjectCreate OB failed: ", GetLastError());
            color clr = (r[i].close > r[i].open) ? InpColorOB_Bull : InpColorOB_Bear;
            ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }
      }
   }
}

void DrawSimpleTrendline(int lookback)
{
   MqlRates r[];
   if(CopyRates(_Symbol, InpSpikeTimeframe, 1, lookback, r) <= 0) return;
   double maxv = -1e12; int idxMax = -1;
   double minv = 1e12;  int idxMin = -1;
   for(int i=0; i<lookback; i++)
   {
      if(r[i].high > maxv) { maxv = r[i].high; idxMax = i; }
      if(r[i].low  < minv) { minv = r[i].low;  idxMin = i; }
   }
   if(idxMax >= 0 && idxMin >= 0)
   {
      datetime t1 = r[idxMax].time; double p1 = r[idxMax].high;
      datetime t2 = r[idxMin].time; double p2 = r[idxMin].low;
      string name = "FXPRO_" + (string)InpMagicNumber + "_TREND";
      if(ObjectFind(0, name) != -1) ObjectDelete(0, name);
      if(!ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2))
         Print("ObjectCreate TREND failed: ", GetLastError());
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorTrend);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, InpSpikeTimeframe);
   }
}

void DrawFiboOnLastMove(int lookback)
{
   MqlRates r[];
   if(CopyRates(_Symbol, InpSpikeTimeframe, 1, lookback, r) <= 0) return;
   double maxv = -1e12; int imax = -1;
   double minv = 1e12;  int imin = -1;
   for(int i=0; i<lookback; i++)
   {
      if(r[i].high > maxv) { maxv = r[i].high; imax = i; }
      if(r[i].low  < minv) { minv = r[i].low; imin = i; }
   }
   if(imax < 0 || imin < 0) return;
   datetime t_high = r[imax].time; datetime t_low = r[imin].time;
   double price_high = r[imax].high; double price_low = r[imin].low;
   string name = "FXPRO_" + (string)InpMagicNumber + "_FIBO";
   if(ObjectFind(0, name) != -1) ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_FIBO, 0, t_low, price_low, t_high, price_high))
      Print("ObjectCreate FIBO failed: ", GetLastError());
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, InpSpikeTimeframe);
}

void DrawSRZones(int lookback, double zonePips)
{
   MqlRates r[];
   if(CopyRates(_Symbol, PERIOD_H4, 0, lookback, r) < lookback) return;
   int buckets = 40;
   double high = r[0].high, low = r[0].low;
   for(int i=1; i<lookback; i++) { if(r[i].high > high) high = r[i].high; if(r[i].low < low) low = r[i].low; }
   double range = high - low;
   if(range <= 0.0) return;
   double step = range / buckets;
   double freq[];
   ArrayResize(freq, buckets);
   for(int i=0; i<buckets; i++) freq[i] = 0.0;
   for(int i=0; i<lookback; i++)
   {
      int idx = (int)((r[i].close - low) / step);
      if(idx < 0) idx = 0; if(idx >= buckets) idx = buckets - 1;
      freq[idx] += 1.0;
   }
   for(int i=0; i<buckets; i++)
   {
      if(freq[i] >= 3.0)
      {
         double price_center = low + (i + 0.5) * step;
         string name = "FXPRO_" + (string)InpMagicNumber + "_SR_" + IntegerToString(i);
         double top = price_center + zonePips * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double bot = price_center - zonePips * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(ObjectFind(0, name) != -1) ObjectDelete(0, name);
         datetime t0 = TimeCurrent();
         datetime t1 = t0 + (datetime)(PeriodSeconds(PERIOD_H4) * 10);
         if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t0, top, t1, bot))
            Print("ObjectCreate SR failed: ", GetLastError());
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorSR);
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, InpColorSR);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      }
   }
}

//+------------------------------------------------------------------+
//| Utils: Couleur ARGB                                              |
//+------------------------------------------------------------------+
uint MakeARGB(color base, int alpha)
{
   if(alpha < 0) alpha = 0; if(alpha > 255) alpha = 255;
   return ColorToARGB(base, (uchar)alpha);
}

//+------------------------------------------------------------------+
//| Dessine des zones de pré-spike (bull/bear) pour un symbole       |
//+------------------------------------------------------------------+
void DrawPreSpikeZonesForSymbol(string symbol, ENUM_TIMEFRAMES tf)
{
   int lookback = MathMax(50, InpZoneLookbackBars);
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, tf, 0, lookback, r) < MathMin(lookback, 50)) return;

   double atr = GetCurrentATR(symbol);
   if(atr <= 0.0) atr = (r[0].high - r[0].low);

   // Préparer nommage et limites
   string prefix = "FXPRO_" + (string)InpMagicNumber + "_ZONE_";
   int drawn = 0;
   int maxZones = 4; // éviter le sur-draw
   int fwd = MathMax(3, InpZoneForwardBars);

   // Moyennes mobiles simples de range pour compression
   double rngAvg20 = 0.0, rngAvg10 = 0.0;
   int rngCount20 = MathMin(20, ArraySize(r)-1), rngCount10 = MathMin(10, ArraySize(r)-1);
   for(int k=1;k<=rngCount20;k++) rngAvg20 += (r[k].high - r[k].low);
   if(rngCount20>0) rngAvg20 /= rngCount20;
   for(int k=1;k<=rngCount10;k++) rngAvg10 += (r[k].high - r[k].low);
   if(rngCount10>0) rngAvg10 /= rngCount10;

   // Scanner quelques barres récentes (hors bougie courante index 0)
   for(int i=1; i<MathMin(lookback-2, 80); i++)
   {
      if(drawn >= maxZones) break;

      double range_i = (r[i].high - r[i].low);
      bool compression = (rngAvg20>0 && range_i < rngAvg20 * 0.7) || (rngAvg10>0 && range_i < rngAvg10 * 0.7);

      // Égalités de H/L proches (liquidité)
      bool eqLows = (MathAbs(r[i].low - r[i+1].low) <= atr * 0.3) || (MathAbs(r[i].low - r[i+2].low) <= atr * 0.3);
      bool eqHighs = (MathAbs(r[i].high - r[i+1].high) <= atr * 0.3) || (MathAbs(r[i].high - r[i+2].high) <= atr * 0.3);

      // Mèches de balayage
      double upperWick = r[i].high - MathMax(r[i].open, r[i].close);
      double lowerWick = MathMin(r[i].open, r[i].close) - r[i].low;
      bool sweepDown = (lowerWick >= atr * 0.8);
      bool sweepUp   = (upperWick >= atr * 0.8);

      // Reclaim + bougie à corps fort
      double body = MathAbs(r[i].close - r[i].open);
      bool bodyStrong = (range_i>0 && body >= range_i * 0.6);

      // Direction probable
      bool bullishSetup = compression && eqLows && sweepDown && bodyStrong && (r[i].close > r[i].open);
      bool bearishSetup = compression && eqHighs && sweepUp   && bodyStrong && (r[i].close < r[i].open);

      if(!bullishSetup && !bearishSetup) continue;

      // Déterminer centre de zone et bornes
      double center = r[i].close;
      double halfH  = MathMax(atr * InpZoneATRMult * 0.5, (r[i].high - r[i].low)*0.4);
      double top = center + halfH;
      double bot = center - halfH;
      datetime t1 = r[i].time;
      datetime t2 = t1 + (datetime)(PeriodSeconds(tf) * fwd);

      int dir = bullishSetup ? +1 : -1;
      string nm = prefix + symbol + "_" + IntegerToString((int)tf) + "_" + IntegerToString((int)t1) + "_" + IntegerToString(dir);
      if(ObjectFind(0, nm) >= 0) continue; // déjà dessinée

      if(ObjectCreate(0, nm, OBJ_RECTANGLE, 0, t1, top, t2, bot))
      {
         color base = (dir>0) ? clrLime : clrRed;
         uint argb = MakeARGB(base, InpZoneAlpha);
         ObjectSetInteger(0, nm, OBJPROP_COLOR, base);
         ObjectSetInteger(0, nm, OBJPROP_BGCOLOR, (color)argb);
         ObjectSetInteger(0, nm, OBJPROP_FILL, true);
         ObjectSetInteger(0, nm, OBJPROP_BACK, true);
         ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, nm, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
         drawn++;
      }
   }
}

//+------------------------------------------------------------------+
//| Nettoie les zones de pré-spike expirées                          |
//+------------------------------------------------------------------+
void CleanupExpiredSpikeZones()
{
   string prefix = "FXPRO_" + (string)InpMagicNumber + "_ZONE_";
   datetime nowt = TimeCurrent();
   for(int i = ObjectsTotal(0, 0, -1)-1; i >= 0; i--)
   {
      string nm = ObjectName(0, i, 0, -1);
      if(StringFind(nm, prefix) != 0) continue;

      // Extraire timestamp depuis le nom: ..._<time>_<dir>
      int posLastUnd = StringFind(nm, "_", StringLen(prefix));
      if(posLastUnd < 0) continue;
      // Trouver la fin de <symbol>_<tf>_ et récupérer <time>
      // On cherche le dernier '_' puis l'avant-dernier
      int lastUnd = StringFind(nm, "_", posLastUnd+1);
      while(lastUnd >= 0)
      {
         posLastUnd = lastUnd;
         lastUnd = StringFind(nm, "_", posLastUnd+1);
      }
      // posLastUnd est avant <dir>. Chercher l'underscore précédent pour isoler <time>
      int prevUnd = StringFind(nm, "_", 0);
      int findFrom = 0;
      int lastBefore = -1;
      while(true)
      {
         int p = StringFind(nm, "_", findFrom);
         if(p < 0 || p >= posLastUnd) break;
         lastBefore = p;
         findFrom = p + 1;
      }
      if(lastBefore < 0) continue;
      // Extraire sous-chaîne entre lastBefore+1 et posLastUnd-1 -> time
      string timeStr = StringSubstr(nm, lastBefore+1, posLastUnd - (lastBefore+1));
      long tval = (long)StringToInteger(timeStr);

      // Expiration par secondes
      if(nowt - (datetime)tval > InpZoneExpirySeconds)
      {
         ObjectDelete(0, nm);
      }
   }
}

//+------------------------------------------------------------------+
//| Calcule SL et TP en respectant strictement la règle 80%            |
//+------------------------------------------------------------------+
void CalculateStrictRatioSLTP(string symbol, double entryPrice, int direction, double &sl, double &tp)
{
   double atr = GetCurrentATR(symbol);
   if(atr <= 0) 
   {
      // Utiliser la dernière bougie si ATR non disponible
      MqlRates rates[];
      if(CopyRates(symbol, InpSpikeTimeframe, 0, 1, rates) > 0)
         atr = rates[0].high - rates[0].low;
      else
         atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 100.0; // Valeur par défaut
   }
   
   // Pour les symboles Boom/Crash, augmenter les distances
   double slMultiplier = atr;
   double tpMultiplier = atr;
   
   if(IsSymbolBoom(symbol) || IsSymbolCrash(symbol))
   {
      slMultiplier = atr * 2.0;  // SL plus large pour Boom/Crash
      tpMultiplier = atr * 8.0;  // TP beaucoup plus large pour Boom/Crash (ratio 4:1)
   }
   else
   {
      slMultiplier = atr * 1.5;  // SL standard pour autres symboles
      tpMultiplier = atr * 6.0;  // TP standard (ratio 4:1)
   }
   
   // Calculer SL et TP
   if(direction > 0) // BUY
   {
      sl = entryPrice - slMultiplier;
      tp = entryPrice + tpMultiplier;
   }
   else // SELL
   {
      sl = entryPrice + slMultiplier;
      tp = entryPrice - tpMultiplier;
   }
   
   // Normaliser les prix
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   // Vérifier et garantir le ratio 80%
   double slDistance = MathAbs(entryPrice - sl);
   double tpDistance = MathAbs(tp - entryPrice);
   double currentRatio = (tpDistance / slDistance) * 100.0;
   
   // Ajuster TP pour garantir exactement 80%
   if(currentRatio < 80.0)
   {
      double requiredTPDistance = (slDistance * 80.0) / 100.0;
      if(direction > 0) // BUY
         tp = entryPrice + requiredTPDistance;
      else // SELL
         tp = entryPrice - requiredTPDistance;
      tp = NormalizeDouble(tp, digits);
   }
   
   string symbolType = (IsSymbolBoom(symbol) || IsSymbolCrash(symbol)) ? "BOOM/CRASH" : "CLASSIQUE";
   PrintFormat("?? SL/TP STRICTS (%s) - Entry: %.5f, SL: %.5f, TP: %.5f, Ratio: %.1f%%", 
               symbolType, entryPrice, sl, tp, (tpDistance / slDistance) * 100.0);
}

//+------------------------------------------------------------------+
//| Calcule SL et TP avec ratios 20%/80% pour moins de volatilité      |
//+------------------------------------------------------------------+
void CalculateLowVolatilitySLTP(string symbol, double entryPrice, int direction, double &sl, double &tp)
{
   double atr = GetCurrentATR(symbol);
   if(atr <= 0) 
   {
      // Utiliser la dernière bougie si ATR non disponible
      MqlRates rates[];
      if(CopyRates(symbol, InpSpikeTimeframe, 0, 1, rates) > 0)
         atr = rates[0].high - rates[0].low;
      else
         atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 100; // Valeur par défaut
   }
   
   // Calculer la distance basée sur le risque de 20% du compte
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (InpMaxRiskPercent / 100.0);
   
   // Calculer la taille de position pour le risque
   double lotSize = CalculateLotSize(atr);
   double pipValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE) * lotSize;
   
   if(pipValue <= 0) 
   {
      pipValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      if(pipValue <= 0) pipValue = 0.01;
   }
   
   // Distance en pips pour le risque de 20%
   double slDistancePips = riskAmount / pipValue;
   double tpDistancePips = slDistancePips * (InpTakeProfitPercent / InpStopLossPercent); // Ratio 4:1
   
   // Convertir en prix
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double slDistancePrice = slDistancePips * point;
   double tpDistancePrice = tpDistancePips * point;
   
   // Calculer SL et TP
   if(direction > 0) // BUY
   {
      sl = entryPrice - slDistancePrice;
      tp = entryPrice + tpDistancePrice;
   }
   else // SELL
   {
      sl = entryPrice + slDistancePrice;
      tp = entryPrice - tpDistancePrice;
   }
   
   // Normaliser les prix
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   PrintFormat("?? SL/TP calculés pour %s - SL: %.5f, TP: %.5f (Ratio %.0f%%/%.0f%%)", 
               symbol, sl, tp, InpStopLossPercent, InpTakeProfitPercent);
}

//+------------------------------------------------------------------+
//| Place un ordre limit basé sur les informations d'un signal      |
//+------------------------------------------------------------------+
void PlaceLimitOrderFromSignal(string symbol, int direction, double entryPrice, double sl, double tp)
{
   if(!InpEnableTrading)
   {
      Print("?? Trading désactivé - Ordre limit non placé");
      return;
   }
   
   // Vérifier s'il existe déjà une position ouverte pour ce symbole
   bool hasPositionForSymbol = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
            PositionGetString(POSITION_SYMBOL) == symbol)
         {
            hasPositionForSymbol = true;
            break;
         }
      }
   }
   
   if(hasPositionForSymbol)
   {
      Print("?? Déjà une position ouverte pour ", symbol, ". Aucun nouvel ordre ne sera placé pour ce symbole.");
      return;
   }
   
   // IMPORTANT: Supprimer tous les ordres limites précédents non exécutés pour ce symbole
   // avant de placer le nouveau signal consolidé
   DeletePendingLimitOrdersForSymbol(symbol);
   
   // Vérifier le nombre total de positions ouvertes (positions + ordres limit) - max 2
   int totalPositions = CountTotalOpenPositions();
   if(totalPositions >= 2)
   {
      Print("?? Déjà 2 positions/ordres ouverts au total (tous symboles confondus). Aucun nouvel ordre ne sera placé.");
      return;
   }
   
   // Calculer le lot
   double lotSize = InpLimitOrderLotSize;
   if(lotSize <= 0)
   {
      double accountBalance = (InpAccountBalance > 0) ? InpAccountBalance : AccountInfoDouble(ACCOUNT_BALANCE);
      if(accountBalance <= 10.0)
         lotSize = 0.01;
      else
      {
         // Calculer l'ATR pour le symbole spécifié
         double atr = GetCurrentATR(symbol);
         
         // Si ATR non disponible, calculer depuis les rates
         if(atr <= 0)
         {
            MqlRates rates[];
            if(CopyRates(symbol, InpSpikeTimeframe, 0, 1, rates) > 0)
               atr = rates[0].high - rates[0].low;
            
            // Si toujours 0, utiliser une valeur par défaut basée sur le point
            if(atr <= 0)
            {
               double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
               atr = point * 100; // Valeur par défaut
            }
         }
         lotSize = CalculateLotSize(atr);
      }
   }
   
   // Normaliser le lot
   lotSize = NormalizeLotSize(lotSize, symbol);
   if(!IsValidLotSize(lotSize, symbol))
   {
      Print("? Taille de lot invalide pour ", symbol);
      return;
   }
   
   // Obtenir le prix actuel
   double currentPrice = (direction > 0) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   // Trouver les supports/résistances les plus proches et ajuster le prix d'entrée
   double nearestSupport = 0;
   double nearestResistance = 0;
   if(FindNearestSupportResistance(symbol, InpSpikeTimeframe, currentPrice, nearestSupport, nearestResistance))
   {
      entryPrice = AdjustEntryPriceToSR(symbol, direction, entryPrice, nearestSupport, nearestResistance, currentPrice);
      
      // Recalculer SL et TP avec les nouveaux ratios 20%/80%
      CalculateLowVolatilitySLTP(symbol, entryPrice, direction, sl, tp);
   }
   else
   {
      // Si pas de support/résistance trouvé, utiliser les ratios par défaut
      CalculateLowVolatilitySLTP(symbol, entryPrice, direction, sl, tp);
   }
   
   // Normaliser les prix
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   entryPrice = NormalizeDouble(entryPrice, digits);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   // Créer l'ordre limit
   MqlTradeRequest request;
   MqlTradeResult result;
   ZeroMemory(request);
   ZeroMemory(result);
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = symbol;
   request.volume = lotSize;
   request.price = entryPrice;
   request.sl = sl;
   request.tp = tp;
   request.deviation = InpSlippage;
   request.type = (direction > 0) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   request.magic = InpMagicNumber;
   request.comment = "Signal Limit " + (string)TimeCurrent();
   request.expiration = TimeCurrent() + 3600; // Expire dans 1 heure
   request.type_time = ORDER_TIME_SPECIFIED;
   
   // Envoyer l'ordre
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   if(trade.OrderSend(request, result))
   {
      Print("? Ordre limit placé depuis signal: ", symbol, " ", (direction > 0 ? "BUY" : "SELL"), 
            " @ ", entryPrice, " SL:", sl, " TP:", tp);
   }
   else
   {
      Print("? Échec placement ordre limit: ", result.retcode, " - ", result.comment);
   }
}

//+------------------------------------------------------------------+
//| Envoie une notification MT5 avec les détails du signal          |
//+------------------------------------------------------------------+
void SendTradingNotification(string symbol, int direction, double price, double sl, double tp, int signalCount = 1, double avgConfidence = 0.0, bool is100Percent = false)
{
   if(!InpEnableNotifications) 
      return;
   
   string tradeType = (direction > 0) ? "BUY" : "SELL";
   string symbolType = IsSymbolBoom(symbol) ? "BOOM" : (IsSymbolCrash(symbol) ? "CRASH" : "NORMAL");
   
   // Calculer les pips pour SL et TP
   double pipSize = (StringFind(symbol, "JPY") >= 0) ? 0.01 : 0.0001;
   if(StringFind(symbol, "Index") >= 0 || StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0)
      pipSize = 0.1;
   
   double slPips = 0.0;
   double tpPips = 0.0;
   if(sl != 0.0)
      slPips = (direction > 0) ? (price - sl) / pipSize : (sl - price) / pipSize;
   if(tp != 0.0)
      tpPips = (direction > 0) ? (tp - price) / pipSize : (price - tp) / pipSize;

   string divider = "========================================";
   string signalTitle;
   if(signalCount > 1)
   {
      signalTitle = is100Percent ? "Consolidated Spike Signal (100% Match)" : "Consolidated Spike Signal";
   }
   else
   {
      signalTitle = "Spike Signal";
   }

   double slPipsAbs = MathAbs(slPips);
   double tpPipsAbs = MathAbs(tpPips);

   string slLine = (sl != 0.0)
      ? StringFormat("Stop Loss: %.5f (%.1f pips)\n", sl, slPipsAbs)
      : "Stop Loss: not set\n";
   string tpLine = (tp != 0.0)
      ? StringFormat("Take Profit: %.5f (%.1f pips)\n", tp, tpPipsAbs)
      : "Take Profit: not set\n";

   string executionInfo = "Execution: automatic order placement per strategy\n";

   string consolidationInfo = "";
   if(signalCount > 1)
   {
      consolidationInfo = StringFormat("Signals Consolidated: %d (3.5 min window)\n", signalCount);
      if(avgConfidence > 0.0)
         consolidationInfo += StringFormat("Confidence: %.1f%%\n", avgConfidence);
      if(is100Percent)
         consolidationInfo += "Confidence Status: 100% match\n";
   }

   string message = StringFormat(
      "%s\n%s\n%s\n%s\n"
      "Symbol: %s (%s)\n"
      "Direction: %s\n"
      "Entry Price: %.5f\n"
      "%s"
      "%s"
      "%s"
      "%s"
      "Timestamp: %s\n"
      "%s\n%s",
      GetAlgorithmHeader(),
      divider,
      signalTitle,
      divider,
      symbol, symbolType,
      tradeType,
      price,
      slLine,
      tpLine,
      executionInfo,
      consolidationInfo,
      TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
      divider,
      GetSignalSeparator()
   );
   
   // Envoyer la notification MT5
   SendNotification(message);
   
   // Afficher aussi dans le journal
   Print("?? NOTIFICATION MT5: ", message);
   
   // Si un numéro de téléphone est configuré, envoyer aussi par SMS
   if(InpPhoneNumber != "")
   {
      string smsMessage = StringFormat("Signal %s %s - Entry:%.5f SL:%.5f TP:%.5f", 
                                       tradeType, symbol, price, sl, tp);
   
   // Envoi de la notification via l'API REST
   string headers = "Content-Type: application/json";
   string request = StringFormat("{\"phone\":\"%s\",\"message\":\"%s\"}", 
                                   InpPhoneNumber, smsMessage);
   
   // URL de l'API de notification (à remplacer par votre endpoint)
   string url = "https://votre-api-de-notification.com/send";
   
   // Envoi de la requête HTTP POST
   char post[], result[];
   string result_headers;
   StringToCharArray(request, post, 0, StringLen(request), CP_UTF8);
   
   int res = WebRequest("POST", url, headers, 10000, post, result, result_headers);
   
   if(res == -1)
   {
         Print("Erreur WebRequest SMS. Erreur: ", GetLastError());
   }
   else if(res == 200)
   {
         Print("Notification SMS envoyée: ", smsMessage);
   }
   else
   {
         Print("Erreur d'envoi de notification SMS. Code: ", res);
      }
   }
}

//+------------------------------------------------------------------+
//| Prédit le spike AVANT qu'il arrive (une bougie avant)           |
//+------------------------------------------------------------------+
SpikePrediction PredictSpikeBeforeItHappens(string symbol, ENUM_TIMEFRAMES tf, int lookback = 1000)
{
   SpikePrediction prediction = {0};
   prediction.confidence = 0.0;
   prediction.direction = 0;
   
   MqlRates rates[];
   if(CopyRates(symbol, tf, 0, lookback, rates) < lookback)
   {
      return prediction;
   }
   
   // Analyser les patterns AVANT les spikes historiques
   // Chercher les signes avant-coureurs d'un spike
   
   // 1. Compression de volatilité (squeeze) - souvent précédent un spike
   double currentATR = GetCurrentATR(symbol);
   if(currentATR <= 0) currentATR = (rates[0].high - rates[0].low);
   
   double avgATR = 0;
   for(int i = 1; i < 20 && i < lookback; i++)
   {
      avgATR += (rates[i].high - rates[i].low);
   }
   avgATR /= 19;
   
   bool volatilitySqueeze = (currentATR < avgATR * 0.7); // Volatilité compressée
   
   // 2. Accumulation de volume avant spike
   double currentVolume = (double)rates[0].tick_volume;
   double avgVolume = 0;
   for(int i = 1; i < 20 && i < lookback; i++)
   {
      avgVolume += (double)rates[i].tick_volume;
   }
   avgVolume /= 19;
   
   bool volumeAccumulation = (currentVolume > avgVolume * 1.3); // Volume en accumulation
   
   // 3. Pattern de consolidation avant explosion
   double priceRange = rates[0].high - rates[0].low;
   double avgRange = 0;
   for(int i = 1; i < 10 && i < lookback; i++)
   {
      avgRange += (rates[i].high - rates[i].low);
   }
   avgRange /= 9;
   
   bool consolidation = (priceRange < avgRange * 0.6); // Consolidation détectée
   
   // 4. Momentum qui s'accélère
   double momentum1 = rates[0].close - rates[2].close; // Momentum sur 2 bougies
   double momentum2 = rates[2].close - rates[4].close; // Momentum précédent
   
   bool momentumAcceleration = (MathAbs(momentum1) > MathAbs(momentum2) * 1.2);
   
   // 5. Analyse des patterns de chandelier avant spike
   bool bullishPattern = false;
   bool bearishPattern = false;
   
   if(lookback >= 3)
   {
      // Hammer ou Doji avant spike haussier
      double body = MathAbs(rates[0].close - rates[0].open);
      double range = rates[0].high - rates[0].low;
      double lowerShadow = MathMin(rates[0].open, rates[0].close) - rates[0].low;
      
      if(range > 0 && body < range * 0.3 && lowerShadow > body * 2)
      {
         bullishPattern = true;
      }
      
      // Shooting star ou Doji avant spike baissier
      double upperShadow = rates[0].high - MathMax(rates[0].open, rates[0].close);
      if(range > 0 && body < range * 0.3 && upperShadow > body * 2)
      {
         bearishPattern = true;
      }
   }
   
   // 6. Calculer la probabilité de spike imminent (seuils assouplis)
   double spikeProbability = 0;
   if(volatilitySqueeze) spikeProbability += 30; // Augmenté
   if(volumeAccumulation) spikeProbability += 25; // Augmenté
   if(consolidation) spikeProbability += 25; // Augmenté
   if(momentumAcceleration) spikeProbability += 20; // Augmenté
   if(bullishPattern || bearishPattern) spikeProbability += 25; // Augmenté
   
   // Bonus si plusieurs conditions sont remplies
   int conditionsMet = 0;
   if(volatilitySqueeze) conditionsMet++;
   if(volumeAccumulation) conditionsMet++;
   if(consolidation) conditionsMet++;
   if(momentumAcceleration) conditionsMet++;
   if(bullishPattern || bearishPattern) conditionsMet++;
   
   if(conditionsMet >= 2) spikeProbability += 10; // Bonus pour plusieurs conditions
   if(conditionsMet >= 3) spikeProbability += 15; // Bonus supplémentaire
   
   // 7. Déterminer la direction probable
   double currentPrice = rates[0].close;
   double atr = currentATR;
   
   // Analyser la tendance récente
   double recentTrend = 0;
   for(int i = 0; i < 5 && i < lookback; i++)
   {
      recentTrend += (rates[i].close - rates[i+1].close);
   }
   recentTrend /= 5;
   
   // Pour Boom: prédire spike haussier si conditions remplies (seuil réduit à 30%)
   if(IsSymbolBoom(symbol))
   {
      if(spikeProbability >= 30 && (recentTrend >= 0 || bullishPattern || volumeAccumulation))
      {
         prediction.direction = 1;
         prediction.confidence = MathMin(100, spikeProbability);
         prediction.predictedPrice = currentPrice + atr * 2.0;
      }
      // Même avec moins de conditions, si volume élevé, prédire un spike
      else if(volumeAccumulation && spikeProbability >= 20)
      {
         prediction.direction = 1;
         prediction.confidence = MathMin(100, spikeProbability);
         prediction.predictedPrice = currentPrice + atr * 1.5;
      }
   }
   // Pour Crash: prédire spike baissier si conditions remplies (seuil réduit à 30%)
   else if(IsSymbolCrash(symbol))
   {
      if(spikeProbability >= 30 && (recentTrend <= 0 || bearishPattern || volumeAccumulation))
      {
         prediction.direction = -1;
         prediction.confidence = MathMin(100, spikeProbability);
         prediction.predictedPrice = currentPrice - atr * 2.0;
      }
      // Même avec moins de conditions, si volume élevé, prédire un spike
      else if(volumeAccumulation && spikeProbability >= 20)
      {
         prediction.direction = -1;
         prediction.confidence = MathMin(100, spikeProbability);
         prediction.predictedPrice = currentPrice - atr * 1.5;
      }
   }
   
   // 8. Calculer les niveaux d'entrée sniper
   if(prediction.direction != 0)
   {
      // Entrée au prix actuel (avant le spike)
      prediction.entryPrice = currentPrice;
      
      if(prediction.direction > 0)
      {
         prediction.stopLoss = currentPrice - atr * 1.5;
         prediction.takeProfit = prediction.predictedPrice;
      }
      else
      {
         prediction.stopLoss = currentPrice + atr * 1.5;
         prediction.takeProfit = prediction.predictedPrice;
      }
      
      // Pour M1, prédire dans les prochaines secondes (5-30 secondes), pas la prochaine bougie
      if(tf == PERIOD_M1)
      {
         int secondsUntilSpike = 5 + (int)(prediction.confidence / 10); // 5-15 secondes selon confiance
         if(secondsUntilSpike > 30) secondsUntilSpike = 30; // Max 30 secondes
         prediction.predictedTime = TimeCurrent() + secondsUntilSpike;
      }
      else
      {
         prediction.predictedTime = TimeCurrent() + PeriodSeconds(tf); // Prochaine bougie
      }
   }
   
   return prediction;
}

//+------------------------------------------------------------------+
//| Prédit le prix de spike basé sur l'analyse des 1000 bougies     |
//+------------------------------------------------------------------+
SpikePrediction PredictSpikePrice(string symbol, ENUM_TIMEFRAMES tf, int lookback = 1000)
{
   SpikePrediction prediction = {0};
   prediction.confidence = 0.0;
   prediction.direction = 0;
   
   MqlRates rates[];
   if(CopyRates(symbol, tf, 0, lookback, rates) < lookback)
   {
      Print("Erreur: Impossible de copier ", lookback, " bougies pour la prédiction");
      return prediction;
   }
   
   // 1. Analyse statistique des mouvements de prix
   double priceChanges[];
   ArrayResize(priceChanges, lookback - 1);
   double sumChanges = 0;
   
   for(int i = 0; i < lookback - 1; i++)
   {
      priceChanges[i] = rates[i].close - rates[i+1].close;
      sumChanges += priceChanges[i];
   }
   
   double meanChange = sumChanges / (lookback - 1);
   
   // 2. Calcul de l'écart-type
   double variance = 0;
   for(int i = 0; i < lookback - 1; i++)
   {
      variance += MathPow(priceChanges[i] - meanChange, 2);
   }
   double stdDev = MathSqrt(variance / (lookback - 1));
   
   // 3. Détection des patterns de spike historiques
   int spikeCount = 0;
   double spikeMagnitudes[];
   ArrayResize(spikeMagnitudes, 0);
   
   for(int i = 0; i < lookback - 5; i++)
   {
      double move = MathAbs(rates[i].close - rates[i+1].close);
      double avgMove = 0;
      for(int j = i+1; j < i+5 && j < lookback; j++)
      {
         avgMove += MathAbs(rates[j].close - rates[j+1].close);
      }
      avgMove /= 4;
      
      if(avgMove > 0 && move > avgMove * 2.5) // Spike détecté
      {
         spikeCount++;
         ArrayResize(spikeMagnitudes, spikeCount);
         spikeMagnitudes[spikeCount-1] = move;
      }
   }
   
   // 4. Calcul de la probabilité de spike
   double spikeProbability = (double)spikeCount / (lookback - 5);
   
   // 5. Prédiction du prix de spike
   double currentPrice = rates[0].close;
   double atr = GetCurrentATR(symbol);
   if(atr <= 0) atr = (rates[0].high - rates[0].low);
   
   // Calculer la magnitude moyenne des spikes historiques
   double avgSpikeMagnitude = 0;
   if(spikeCount > 0)
   {
      for(int i = 0; i < spikeCount; i++)
      {
         avgSpikeMagnitude += spikeMagnitudes[i];
      }
      avgSpikeMagnitude /= spikeCount;
   }
   else
   {
      avgSpikeMagnitude = atr * 2.0; // Valeur par défaut
   }
   
   // 6. Déterminer la direction probable
   double recentMomentum = 0;
   for(int i = 0; i < 20 && i < lookback; i++)
   {
      recentMomentum += (rates[i].close - rates[i+1].close);
   }
   recentMomentum /= 20;
   
   // 7. Vérifier les EMA pour confirmer la direction
   int globalTrend = CalculateGlobalTrend();
   
   // 8. Prédiction finale (ajustée pour M1)
   double spikeMagnitudeMult = (tf == PERIOD_M1) ? 0.5 : 0.8; // Pour M1, prédire des spikes plus petits
   
   if(IsSymbolBoom(symbol))
   {
      // Pour Boom: prédire un spike haussier
      prediction.direction = 1;
      prediction.predictedPrice = currentPrice + avgSpikeMagnitude * spikeMagnitudeMult;
      prediction.confidence = MathMin(100, spikeProbability * 100 + (globalTrend > 0 ? 20 : 0));
   }
   else if(IsSymbolCrash(symbol))
   {
      // Pour Crash: prédire un spike baissier
      prediction.direction = -1;
      prediction.predictedPrice = currentPrice - avgSpikeMagnitude * spikeMagnitudeMult;
      prediction.confidence = MathMin(100, spikeProbability * 100 + (globalTrend < 0 ? 20 : 0));
   }
   else
   {
      // Pour les autres symboles: utiliser le momentum
      if(recentMomentum > 0 && globalTrend >= 0)
      {
         prediction.direction = 1;
         prediction.predictedPrice = currentPrice + avgSpikeMagnitude * 0.6;
      }
      else if(recentMomentum < 0 && globalTrend <= 0)
      {
         prediction.direction = -1;
         prediction.predictedPrice = currentPrice - avgSpikeMagnitude * 0.6;
      }
      prediction.confidence = MathMin(100, spikeProbability * 80);
   }
   
   // 9. Calculer les niveaux d'entrée SNIPER (précision maximale) - PROCHES DU PRIX ACTUEL pour M1
   if(prediction.direction != 0)
   {
      // Pour M1, utiliser le prix actuel ou très proche pour des signaux plus proches
      double optimalEntry = currentPrice;
      double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      if(tf == PERIOD_M1)
      {
         // Sur M1, entrer TRÈS PRÉCIS pour capturer le spike (0.01-0.02 ATR max)
         if(prediction.direction > 0)
         {
            // BUY: entrer au prix actuel ou légèrement en dessous (ENTRÉE SNIPER)
            optimalEntry = currentBid - (atr * 0.01); // Très précis: 0.01 ATR en dessous
            // S'assurer que l'entrée est valide
            if(optimalEntry < currentBid * 0.9995) optimalEntry = currentBid * 0.9998; // Très proche mais valide
         }
         else
         {
            // SELL: entrer au prix actuel ou légèrement au-dessus (ENTRÉE SNIPER)
            optimalEntry = currentAsk + (atr * 0.01); // Très précis: 0.01 ATR au-dessus
            // S'assurer que l'entrée est valide
            if(optimalEntry > currentAsk * 1.0005) optimalEntry = currentAsk * 1.0002; // Très proche mais valide
         }
      }
      else
      {
         // Pour autres timeframes, analyser les dernières bougies
         MqlRates recentRates[];
         if(CopyRates(symbol, tf, 0, 5, recentRates) >= 5)
         {
            // Pour BUY: entrer au plus bas récent
            if(prediction.direction > 0)
            {
               double lowest = recentRates[0].low;
               for(int i = 1; i < 5; i++)
               {
                  if(recentRates[i].low < lowest) lowest = recentRates[i].low;
               }
               // Entrer légèrement au-dessus du plus bas pour éviter les faux signaux
               optimalEntry = lowest + atr * 0.1;
            }
            // Pour SELL: entrer au plus haut récent
            else
            {
               double highest = recentRates[0].high;
               for(int i = 1; i < 5; i++)
               {
                  if(recentRates[i].high > highest) highest = recentRates[i].high;
               }
               // Entrer légèrement en dessous du plus haut pour éviter les faux signaux
               optimalEntry = highest - atr * 0.1;
            }
         }
      }
      
      prediction.entryPrice = optimalEntry;
      
      // Calculer SL et TP avec précision (ajustés pour M1 et petit capital)
      double slMult = (tf == PERIOD_M1) ? InpSLMultiplierM1 : 1.5;
      double tpMult = (tf == PERIOD_M1) ? InpTPMultiplierM1 : 3.0;
      
      if(prediction.direction > 0)
      {
         // BUY: SL en dessous du plus bas récent, TP au prix prédit
         prediction.stopLoss = optimalEntry - atr * slMult; // SL ajusté pour M1
         // Pour M1, TP plus proche pour capturer les petits mouvements
         if(tf == PERIOD_M1)
         {
            prediction.takeProfit = optimalEntry + atr * tpMult; // TP proche pour M1
         }
         else
         {
            prediction.takeProfit = prediction.predictedPrice;
         }
      }
      else
      {
         // SELL: SL au-dessus du plus haut récent, TP au prix prédit
         prediction.stopLoss = optimalEntry + atr * slMult; // SL ajusté pour M1
         // Pour M1, TP plus proche pour capturer les petits mouvements
         if(tf == PERIOD_M1)
         {
            prediction.takeProfit = optimalEntry - atr * tpMult; // TP proche pour M1
         }
         else
         {
            prediction.takeProfit = prediction.predictedPrice;
         }
      }
      
   // Pour M1, prédire dans les prochaines secondes (5-30 secondes), pas la prochaine bougie
   if(tf == PERIOD_M1 && prediction.direction != 0)
   {
      int secondsUntilSpike = 5 + (int)(prediction.confidence / 10); // 5-15 secondes selon confiance
      if(secondsUntilSpike > 30) secondsUntilSpike = 30; // Max 30 secondes
      prediction.predictedTime = TimeCurrent() + secondsUntilSpike;
   }
   else if(prediction.direction != 0)
   {
      prediction.predictedTime = TimeCurrent() + PeriodSeconds(tf); // Prédiction pour la prochaine bougie
   }
   }
   
   PrintFormat("?? PRÉDICTION SPIKE: Prix actuel=%.5f, Prix prédit=%.5f, Direction=%s, Confiance=%.1f%%",
               currentPrice, prediction.predictedPrice, 
               (prediction.direction > 0 ? "HAUSSIER" : "BAISSIER"), 
               prediction.confidence);
   
   return prediction;
}

//+------------------------------------------------------------------+
//| Supprime la flèche de prédiction après confirmation du spike    |
//+------------------------------------------------------------------+
void RemovePredictionArrow()
{
   if(g_currentArrowName != "")
   {
      if(ObjectFind(0, g_currentArrowName) >= 0)
      {
         ObjectDelete(0, g_currentArrowName);
         PrintFormat("??? Flèche de prédiction supprimée: %s (Spike confirmé)", g_currentArrowName);
      }
      g_currentArrowName = "";
      g_spikeConfirmed = false;
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Vérifie si on doit dessiner une flèche (évite les doublons et contrôle strict) |
//+------------------------------------------------------------------+
bool ShouldDrawArrow(int direction, double entryPrice, bool isPrediction = true)
{
   datetime currentTime = TimeCurrent();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double priceTolerance = point * 50; // Tolérance réduite à 50 points (plus strict)

   // Si une flèche existe déjà et que le spike n'a pas encore été confirmé, ne pas en créer une nouvelle
   if(g_currentArrowName != "" && !g_spikeConfirmed)
   {
      // Vérifier si c'est dans la même direction et proche du même prix
      if(g_lastArrowDirection == direction &&
         MathAbs(g_lastArrowPrice - entryPrice) < priceTolerance)
      {
         return false; // Ne pas redessiner - attendre la confirmation du spike actuel
      }
   }

   // Si c'est une prédiction et qu'on a déjà une flèche récente (moins de 2 minutes)
   if(isPrediction && (currentTime - g_lastArrowTime) < 120) // 2 minutes
   {
      if(g_lastArrowDirection == direction &&
         MathAbs(g_lastArrowPrice - entryPrice) < priceTolerance)
      {
         return false; // Ne pas créer de doublon de prédiction
      }
   }
   
   // Mettre à jour les variables globales
   g_lastArrowTime = currentTime;
   g_lastArrowDirection = direction;
   g_lastArrowPrice = entryPrice;
   
   return true; // Dessiner la flèche
}

//+------------------------------------------------------------------+
//| Dessine une flèche de prédiction de spike (disparaît après confirmation) |
//+------------------------------------------------------------------+
void DrawSpikeArrow(int direction, bool isConfirmedSpike = false)
{
   string symbol = _Symbol;
   double price = iClose(symbol, InpSpikeTimeframe, 0);
   datetime t = iTime(symbol, InpSpikeTimeframe, 0);

   // VÉRIFIER SI UN SPIKE S'EST RÉALISÉ (pour supprimer la flèche de prédiction)
   if(g_currentArrowName != "" && !g_spikeConfirmed)
   {
      // Vérifier si le spike prédit s'est réalisé
      if(CheckSpikeRealization(g_lastArrowDirection, g_lastArrowPrice, (double)g_lastArrowTime))
      {
         g_spikeConfirmed = true;
         g_spikeConfirmTime = TimeCurrent();

         // Supprimer la flèche de prédiction après 5 secondes
         Sleep(5000);
         RemovePredictionArrow();

         PrintFormat("? SPIKE RÉALISÉ - Flèche de prédiction va disparaître");
      }
   }

   // Obtenir la prédiction de spike
   SpikePrediction prediction = PredictSpikeBeforeItHappens(symbol, InpSpikeTimeframe, InpScientificLookback);
   
   // Si la prédiction anticipée n'a pas détecté de spike, utiliser la prédiction classique
   if(prediction.direction == 0 || prediction.confidence < 30)
   {
      prediction = PredictSpikePrice(symbol, InpSpikeTimeframe, InpScientificLookback);
   }
   
   // Si la prédiction n'est pas valide, utiliser les valeurs par défaut
   if(prediction.direction == 0)
   {
      prediction.direction = direction;
      prediction.entryPrice = price;
      double atr = GetCurrentATR(symbol);
      if(atr <= 0) atr = (iHigh(symbol, InpSpikeTimeframe, 0) - iLow(symbol, InpSpikeTimeframe, 0));
      
      if(direction > 0)
      {
         prediction.stopLoss = price - atr * 1.5;
         prediction.takeProfit = price + atr * 3.0;
      }
      else
      {
         prediction.stopLoss = price + atr * 1.5;
         prediction.takeProfit = price - atr * 3.0;
      }
   }
   
   // Vérifier si c'est un trade inverse
   bool isReverseTrade = ((direction > 0 && IsSymbolCrash(_Symbol)) || (direction < 0 && IsSymbolBoom(_Symbol)));

   // Couleurs différentes pour prédiction vs confirmation
   color arrowColor;
   if(isConfirmedSpike)
   {
      // Spike CONFIRMÉ - couleurs vives
      if(isReverseTrade)
      {
         arrowColor = (direction > 0) ? clrOrange : clrMagenta;
      }
      else
      {
         arrowColor = (direction > 0) ? clrLime : clrRed;
      }
   }
   else
   {
      // Spike PRÉDIT - couleurs atténuées (transparentes)
      if(isReverseTrade)
      {
         arrowColor = (direction > 0) ? clrGoldenrod : clrViolet;
      }
      else
      {
         arrowColor = (direction > 0) ? clrYellowGreen : clrOrangeRed;
      }
   }

   // Créer un nom de flèche unique basé sur le type (prédiction ou confirmation)
   string arrowPrefix = isConfirmedSpike ? "CONFIRMED" : "PREDICTED";
   string arrowName = "FXPRO_" + (string)InpMagicNumber + "_" + arrowPrefix + "_ARROW_" + (string)t;

   // Stocker le nom de la flèche actuelle
   if(!isConfirmedSpike)
   {
      g_currentArrowName = arrowName;
   }

   // Créer la flèche
   if(ObjectFind(0, arrowName) < 0)
   {
      if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, t, price))
      {
         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
         ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, (direction>0)?233:234); // Flèche vers le haut/bas
         ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, isConfirmedSpike ? 4 : 3); // Plus large si confirmé
         ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, InpSpikeTimeframe);
         ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
         ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
      }
   }

   // Ajouter le signal au buffer (consolidation sur 3.5 minutes)
   AddSignalToBuffer(symbol, direction, prediction.confidence, prediction.entryPrice, prediction.stopLoss, prediction.takeProfit);

   string spikeType = isConfirmedSpike ? "CONFIRMÉ" : "PRÉDIT";
   PrintFormat("?? Flèche %s dessinée: Direction=%s, Entry=%.5f, SL=%.5f, TP=%.5f, Confiance=%.1f%%",
               spikeType,
               (direction > 0 ? "BUY" : "SELL"),
               prediction.entryPrice, prediction.stopLoss, prediction.takeProfit, prediction.confidence);

   // Forcer le rafraîchissement du graphique
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| ========== GESTION DES SIGNAUX CONSOLIDÉS (3.5 MINUTES) ========== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Trouve ou crée un buffer pour un symbole                         |
//+------------------------------------------------------------------+
int GetOrCreateBuffer(string symbol)
{
   datetime currentTime = TimeCurrent();
   datetime windowStart = currentTime - (currentTime % 210); // Arrondir à 3.5 minutes (210 secondes = 3.5 min)
   
   // Chercher un buffer existant pour ce symbole dans la fenêtre actuelle
   for(int i = 0; i < ArraySize(g_signalBuffers); i++)
   {
      if(g_signalBuffers[i].symbol == symbol && g_signalBuffers[i].windowStart == windowStart)
      {
         return i;
      }
   }
   
   // Créer un nouveau buffer
   int size = ArraySize(g_signalBuffers);
   ArrayResize(g_signalBuffers, size + 1);
   g_signalBuffers[size].symbol = symbol;
   g_signalBuffers[size].windowStart = windowStart;
   g_signalBuffers[size].signalCount = 0;
   g_signalBuffers[size].totalConfidence = 0.0;
   g_signalBuffers[size].totalDirection = 0;
   g_signalBuffers[size].avgEntryPrice = 0.0;
   g_signalBuffers[size].avgSL = 0.0;
   g_signalBuffers[size].avgTP = 0.0;
   g_signalBuffers[size].maxConfidence = 0.0;
   g_signalBuffers[size].bestDirection = 0;
   
   return size;
}

//+------------------------------------------------------------------+
//| Ajoute un signal au buffer (consolidation sur 5 minutes)         |
//+------------------------------------------------------------------+
void AddSignalToBuffer(string symbol, int direction, double confidence, double entryPrice, double sl, double tp)
{
   if(direction == 0) return;
   
   int bufferIdx = GetOrCreateBuffer(symbol);
   
   // Ajouter le signal au buffer (accès direct sans référence)
   g_signalBuffers[bufferIdx].signalCount++;
   g_signalBuffers[bufferIdx].totalConfidence += confidence;
   g_signalBuffers[bufferIdx].totalDirection += direction;
   g_signalBuffers[bufferIdx].avgEntryPrice += entryPrice;
   g_signalBuffers[bufferIdx].avgSL += sl;
   g_signalBuffers[bufferIdx].avgTP += tp;
   
   // Garder le signal avec la meilleure confiance
   if(confidence > g_signalBuffers[bufferIdx].maxConfidence)
   {
      g_signalBuffers[bufferIdx].maxConfidence = confidence;
      g_signalBuffers[bufferIdx].bestDirection = direction;
   }
   
   PrintFormat("?? Signal ajouté au buffer [%s]: Direction=%s, Confiance=%.1f%%, Total signaux=%d",
               symbol, (direction > 0 ? "BUY" : "SELL"), confidence, g_signalBuffers[bufferIdx].signalCount);
}

//+------------------------------------------------------------------+
//| Identifie les 2 symboles avec le plus grand nombre de signaux    |
//+------------------------------------------------------------------+
void GetTop2SymbolsBySignalCount(string &topSymbols[])
{
   ArrayResize(topSymbols, 0);
   
   // Créer un tableau pour stocker les symboles et leurs compteurs
   string symbols[];
   int signalCounts[];
   
   // Parcourir tous les buffers et compter les signaux par symbole
   for(int i = 0; i < ArraySize(g_signalBuffers); i++)
   {
      if(g_signalBuffers[i].signalCount > 0)
      {
         string symbol = g_signalBuffers[i].symbol;
         int count = g_signalBuffers[i].signalCount;
         
         // Chercher si le symbole existe déjà
         int idx = -1;
         for(int j = 0; j < ArraySize(symbols); j++)
         {
            if(symbols[j] == symbol)
            {
               idx = j;
               break;
            }
         }
         
         if(idx >= 0)
         {
            // Ajouter au compteur existant
            signalCounts[idx] += count;
         }
         else
         {
            // Ajouter un nouveau symbole
            int size = ArraySize(symbols);
            ArrayResize(symbols, size + 1);
            ArrayResize(signalCounts, size + 1);
            symbols[size] = symbol;
            signalCounts[size] = count;
         }
      }
   }
   
   // Trier par nombre de signaux (tri à bulles simple)
   for(int i = 0; i < ArraySize(symbols) - 1; i++)
   {
      for(int j = i + 1; j < ArraySize(symbols); j++)
      {
         if(signalCounts[j] > signalCounts[i])
         {
            // Échanger
            int tempCount = signalCounts[i];
            signalCounts[i] = signalCounts[j];
            signalCounts[j] = tempCount;
            
            string tempSymbol = symbols[i];
            symbols[i] = symbols[j];
            symbols[j] = tempSymbol;
         }
      }
   }
   
   // Prendre les 2 premiers
   int topSymbolCount = MathMin(2, ArraySize(symbols));
   ArrayResize(topSymbols, topSymbolCount);
   for(int i = 0; i < topSymbolCount; i++)
   {
      topSymbols[i] = symbols[i];
      PrintFormat("?? Top symbole %d: %s avec %d signaux", i + 1, symbols[i], signalCounts[i]);
   }
}

//+------------------------------------------------------------------+
//| Vérifie si un symbole est dans les top 3                         |
//+------------------------------------------------------------------+
bool IsTopSymbol(string symbol)
{
   string topSymbols[];
   GetTop2SymbolsBySignalCount(topSymbols);
   
   for(int i = 0; i < ArraySize(topSymbols); i++)
   {
      if(topSymbols[i] == symbol)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Traite les buffers et envoie les signaux consolidés              |
//| Ne traite que les 2 signaux consolidés avec la confiance         |
//| la plus élevée (tri par confiance moyenne)                       |
//+------------------------------------------------------------------+
void ProcessSignalBuffers()
{
   datetime currentTime = TimeCurrent();
   const int MIN_SIGNAL_COUNT = 20;
   
   // NOUVELLE LOGIQUE: Traiter chaque signal individuellement dès qu'il est prêt
   // Ne pas attendre que tous les signaux soient prêts - envoyer immédiatement pour éviter de manquer les spikes
   
   // Parcourir tous les buffers et traiter ceux qui sont prêts IMMÉDIATEMENT
   for(int i = ArraySize(g_signalBuffers) - 1; i >= 0; i--)
   {
      datetime windowEnd = g_signalBuffers[i].windowStart + 210; // 3.5 minutes = 210 secondes
      
      // Vérifier si ce buffer est prêt (timing respecté)
      if(currentTime >= windowEnd && g_signalBuffers[i].signalCount > 0)
      {
         string currentSymbol = g_signalBuffers[i].symbol;
         int signalCount = g_signalBuffers[i].signalCount;
         
         // VÉRIFICATION: Le signal doit avoir au moins 20 signaux analysés
         if(signalCount < MIN_SIGNAL_COUNT)
         {
            PrintFormat("?? Signal consolidé pour %s IGNORÉ: seulement %d signaux analysés (< %d minimum requis) - Signal NON envoyé",
                        currentSymbol, signalCount, MIN_SIGNAL_COUNT);
            ArrayRemove(g_signalBuffers, i, 1);
            continue;
         }
         
         // Calculer les moyennes
         double avgConfidence = g_signalBuffers[i].totalConfidence / signalCount;
         double avgEntry = g_signalBuffers[i].avgEntryPrice / signalCount;
         
         // Déterminer la direction finale
         int finalDirection = (g_signalBuffers[i].totalDirection > 0) ? 1 : ((g_signalBuffers[i].totalDirection < 0) ? -1 : g_signalBuffers[i].bestDirection);
         
         if(finalDirection == 0)
         {
            PrintFormat("?? Signal consolidé pour %s IGNORÉ: direction indéterminée - Signal NON envoyé", currentSymbol);
            ArrayRemove(g_signalBuffers, i, 1);
            continue;
         }
         
         // Calculer SL/TP avec 20% de perte et 80% de profit en pips
         double point = SymbolInfoDouble(currentSymbol, SYMBOL_POINT);
         double pipSize = (StringFind(currentSymbol, "JPY") >= 0) ? 0.01 : 0.0001;
         if(StringFind(currentSymbol, "Index") >= 0 || StringFind(currentSymbol, "Boom") >= 0 || StringFind(currentSymbol, "Crash") >= 0)
            pipSize = 0.1;
         
         double referenceDistancePips = 50.0;
         double slDistancePips = referenceDistancePips * 0.30;  // Augmenté de 20% à 30% pour SL moins serré
         double tpDistancePips = referenceDistancePips * 0.80;
         
         double avgSL, avgTP;
         if(finalDirection > 0) // BUY
         {
            avgSL = avgEntry - (slDistancePips * pipSize);
            avgTP = avgEntry + (tpDistancePips * pipSize);
         }
         else // SELL
         {
            avgSL = avgEntry + (slDistancePips * pipSize);
            avgTP = avgEntry - (tpDistancePips * pipSize);
         }
         
         int digits = (int)SymbolInfoInteger(currentSymbol, SYMBOL_DIGITS);
         avgSL = NormalizeDouble(avgSL, digits);
         avgTP = NormalizeDouble(avgTP, digits);
         
         // Vérifier si on peut envoyer le signal (un seul par symbole toutes les 3.5 minutes)
         bool canSend = true;
         int lastSentIdx = -1;
         
         for(int j = 0; j < ArraySize(g_lastSignalSentSymbols); j++)
         {
            if(g_lastSignalSentSymbols[j] == currentSymbol)
            {
               lastSentIdx = j;
               if((currentTime - g_lastSignalSentTimes[j]) < 210)
               {
                  canSend = false;
                  PrintFormat("?? Signal consolidé pour %s IGNORÉ: timing non respecté (dernier signal envoyé il y a moins de 3.5 min) - Signal NON envoyé",
                              currentSymbol);
                  break;
               }
            }
         }
         
         // ENVOYER IMMÉDIATEMENT si le signal est valide
         if(canSend && finalDirection != 0 && signalCount >= MIN_SIGNAL_COUNT)
         {
            PrintFormat("?? ENVOI IMMÉDIAT du signal consolidé pour %s: %s, Confiance=%.1f%%, Signaux=%d, Entry=%.5f, SL=%.5f, TP=%.5f",
                        currentSymbol, (finalDirection > 0 ? "BUY" : "SELL"), avgConfidence, signalCount, avgEntry, avgSL, avgTP);
            
            // Envoyer la notification immédiatement
            if(InpEnableNotifications)
            {
               bool is100Percent = (avgConfidence >= 99.9);
               SendTradingNotification(currentSymbol, finalDirection, avgEntry, avgSL, avgTP, signalCount, avgConfidence, is100Percent);
               
               string signalMsg = StringFormat(
                  "?? SIGNAL CONSOLIDÉ [%s] (3.5 min)\n" +
                  "Type: %s\n" +
                  "Confiance moyenne: %.1f%%\n" +
                  "Nombre de signaux analysés: %d\n" +
                  "ENTRY: %.5f\n" +
                  "SL: %.5f\n" +
                  "TP: %.5f\n" +
                  "Timestamp: %s",
                  currentSymbol,
                  (finalDirection > 0 ? "BUY" : "SELL"),
                  avgConfidence,
                  signalCount,
                  avgEntry,
                  avgSL,
                  avgTP,
                  TimeToString(currentTime, TIME_DATE|TIME_SECONDS)
               );
               Print(signalMsg);
            }
            
            // Mettre à jour le dernier signal envoyé
            if(lastSentIdx >= 0)
            {
               g_lastSignalSentTimes[lastSentIdx] = currentTime;
            }
            else
            {
               int size = ArraySize(g_lastSignalSentSymbols);
               ArrayResize(g_lastSignalSentSymbols, size + 1);
               ArrayResize(g_lastSignalSentTimes, size + 1);
               g_lastSignalSentSymbols[size] = currentSymbol;
               g_lastSignalSentTimes[size] = currentTime;
            }
            
            // EXÉCUTER DIRECTEMENT LE TRADE
            if(InpEnableTrading && signalCount >= MIN_SIGNAL_COUNT)
            {
               // Vérifier s'il existe déjà une position ouverte pour ce symbole spécifique
               bool hasPositionForSymbol = false;
               for(int k = PositionsTotal() - 1; k >= 0; k--)
               {
                  ulong ticket = PositionGetTicket(k);
                  if(ticket > 0 && PositionSelectByTicket(ticket))
                  {
                     if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
                        PositionGetString(POSITION_SYMBOL) == currentSymbol)
                     {
                        hasPositionForSymbol = true;
                        PrintFormat("?? Déjà une position ouverte pour %s. Signal consolidé NON exécuté pour ce symbole.", currentSymbol);
                        break;
                     }
                  }
               }
               
               if(!hasPositionForSymbol)
               {
                  PrintFormat("?? EXÉCUTION DIRECTE du trade consolidé: %s %s, Entry=%.5f, SL=%.5f, TP=%.5f",
                              (finalDirection > 0 ? "BUY" : "SELL"), currentSymbol, avgEntry, avgSL, avgTP);
                  PrintFormat("? Signal validé: %d signaux analysés (>= %d minimum requis)", signalCount, MIN_SIGNAL_COUNT);
                  
                  // Exécuter directement le trade (sans limite de nombre de positions)
                  ExecuteDirectTrade(currentSymbol, finalDirection, avgEntry, avgSL, avgTP, avgConfidence);
               }
            }
            
            // Supprimer le buffer traité
            ArrayRemove(g_signalBuffers, i, 1);
         }
         else
         {
            // Signal non envoyé - supprimer le buffer
            ArrayRemove(g_signalBuffers, i, 1);
         }
      }
   }
   
   // Chaque signal est maintenant traité individuellement dès qu'il est prêt
   // Cela permet d'envoyer les notifications immédiatement sans attendre que tous les signaux soient prêts
}

//+------------------------------------------------------------------+
//| Crée un label de prix sur le graphique                          |
//+------------------------------------------------------------------+
void CreatePriceLabel(string name, string text, datetime time, double price, color clr)
{
   if(ObjectCreate(0, name, OBJ_TEXT, 0, time, price))
   {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, InpSpikeTimeframe);
   }
}

//+------------------------------------------------------------------+
//| Traite et filtre les signaux consolidés                          |
//+------------------------------------------------------------------+
void ProcessFilteredSignals()
{
   datetime currentTime = TimeCurrent();
   const int MIN_SIGNAL_COUNT = 20;
   
   // Déclarer le tableau filteredSignals
   ConsolidatedSignal readySignals[];
   ConsolidatedSignal filteredSignals[];
   
   // Étape 1: Construire readySignals à partir des buffers prêts
   for(int i = ArraySize(g_signalBuffers) - 1; i >= 0; i--)
   {
      datetime windowEnd = g_signalBuffers[i].windowStart + 210;
      if(currentTime >= windowEnd && g_signalBuffers[i].signalCount > 0)
      {
         int size = ArraySize(readySignals);
         ArrayResize(readySignals, size + 1);
         
         readySignals[size].symbol = g_signalBuffers[i].symbol;
         readySignals[size].signalCount = g_signalBuffers[i].signalCount;
         readySignals[size].avgConfidence = g_signalBuffers[i].totalConfidence / readySignals[size].signalCount;
         readySignals[size].avgEntry = g_signalBuffers[i].avgEntryPrice / readySignals[size].signalCount;
         readySignals[size].finalDirection = (g_signalBuffers[i].totalDirection > 0) ? 1 : ((g_signalBuffers[i].totalDirection < 0) ? -1 : g_signalBuffers[i].bestDirection);
         readySignals[size].bufferIndex = i;
         
         // Calculer SL/TP
         double point = SymbolInfoDouble(readySignals[size].symbol, SYMBOL_POINT);
         double pipSize = (StringFind(readySignals[size].symbol, "JPY") >= 0) ? 0.01 : 0.0001;
         if(StringFind(readySignals[size].symbol, "Index") >= 0 || StringFind(readySignals[size].symbol, "Boom") >= 0 || StringFind(readySignals[size].symbol, "Crash") >= 0)
            pipSize = 0.1;
         
         double referenceDistancePips = 50.0;
         double slDistancePips = referenceDistancePips * 0.30;  // Augmenté de 20% à 30% pour SL moins serré
         double tpDistancePips = referenceDistancePips * 0.80;
         
         if(readySignals[size].finalDirection > 0)
         {
            readySignals[size].avgSL = readySignals[size].avgEntry - (slDistancePips * pipSize);
            readySignals[size].avgTP = readySignals[size].avgEntry + (tpDistancePips * pipSize);
         }
         else
         {
            readySignals[size].avgSL = readySignals[size].avgEntry + (slDistancePips * pipSize);
            readySignals[size].avgTP = readySignals[size].avgEntry - (tpDistancePips * pipSize);
         }
         
         int digits = (int)SymbolInfoInteger(readySignals[size].symbol, SYMBOL_DIGITS);
         readySignals[size].avgSL = NormalizeDouble(readySignals[size].avgSL, digits);
         readySignals[size].avgTP = NormalizeDouble(readySignals[size].avgTP, digits);
      }
   }
   
   // Étape 2: Filtrer les signaux (>= MIN_SIGNAL_COUNT)
   ArrayResize(filteredSignals, 0);
   for(int i = 0; i < ArraySize(readySignals); i++)
   {
      if(readySignals[i].signalCount >= MIN_SIGNAL_COUNT)
      {
         int size = ArraySize(filteredSignals);
         ArrayResize(filteredSignals, size + 1);
         filteredSignals[size] = readySignals[i];
      }
      else
      {
         PrintFormat("?? FILTRÉ - Signal consolidé pour %s (%d signaux analysés) - Seuil minimum de %d signaux non atteint - Signal NON envoyé", 
                     readySignals[i].symbol, readySignals[i].signalCount, MIN_SIGNAL_COUNT);
      }
   }
   
   // Remplacer readySignals par filteredSignals
   ArrayResize(readySignals, 0);
   for(int i = 0; i < ArraySize(filteredSignals); i++)
   {
      int size = ArraySize(readySignals);
      ArrayResize(readySignals, size + 1);
      readySignals[size] = filteredSignals[i];
   }
   
   // Étape 3: Trier les signaux consolidés par confiance moyenne (décroissant)
   // PRIORITÉ: Les signaux avec la confiance la plus élevée sont exécutés en premier
   // Tri à bulles amélioré pour garantir l'ordre correct
   for(int i = 0; i < ArraySize(readySignals) - 1; i++)
   {
      for(int j = i + 1; j < ArraySize(readySignals); j++)
      {
         // Trier par confiance moyenne (priorité principale)
         // En cas d'égalité, utiliser le nombre de signaux comme critère secondaire
         bool shouldSwap = false;
         
         if(readySignals[j].avgConfidence > readySignals[i].avgConfidence)
         {
            shouldSwap = true;
         }
         else if(readySignals[j].avgConfidence == readySignals[i].avgConfidence)
         {
            // En cas d'égalité de confiance, privilégier celui avec plus de signaux
            if(readySignals[j].signalCount > readySignals[i].signalCount)
            {
               shouldSwap = true;
            }
         }
         
         if(shouldSwap)
         {
            // Échanger
            ConsolidatedSignal temp = readySignals[i];
            readySignals[i] = readySignals[j];
            readySignals[j] = temp;
         }
      }
   }
   
   // Étape 4: FILTRER STRICTEMENT - Traiter UNIQUEMENT les 3 premiers (ceux avec la confiance la plus élevée)
   // Tous les autres signaux consolidés seront BLOQUÉS et ne seront JAMAIS envoyés
   int topCount = MathMin(3, ArraySize(readySignals));
   
   // VÉRIFICATION CRITIQUE: Ne rien faire si aucun signal valide n'est disponible
   // Respecter le timing: attendre les signaux valides avant d'envoyer des notifications
   if(ArraySize(readySignals) == 0)
   {
      // Aucun signal valide disponible - ne pas envoyer de notification
      // Le timing est respecté mais aucun signal ne répond aux critères (>= 20 signaux)
      // On attend le prochain cycle de 3.5 minutes pour vérifier à nouveau
      return;
   }
   
   if(ArraySize(readySignals) > 0)
   {
      PrintFormat("?? FILTRAGE: Total signaux consolidés prêts (>= %d signaux): %d", MIN_SIGNAL_COUNT, ArraySize(readySignals));
      for(int i = 0; i < ArraySize(readySignals); i++)
      {
         PrintFormat("   Signal #%d: %s - Confiance: %.1f%%, Signaux: %d", 
                     i + 1, readySignals[i].symbol, readySignals[i].avgConfidence, readySignals[i].signalCount);
      }
      PrintFormat("? Seuls les TOP %d (confiance la plus élevée) seront exécutés - Les autres seront BLOQUÉS", topCount);
   }
   
   // Vérifier que topCount > 0 avant de traiter (double vérification)
   if(topCount == 0)
   {
      PrintFormat("?? Aucun signal valide disponible après filtrage - Aucune notification envoyée");
      return;
   }
   
   for(int idx = 0; idx < topCount; idx++)
   {
      string currentSymbol = readySignals[idx].symbol;
      int signalCount = readySignals[idx].signalCount;
      double avgConfidence = readySignals[idx].avgConfidence;
      double avgEntry = readySignals[idx].avgEntry;
      double avgSL = readySignals[idx].avgSL;
      double avgTP = readySignals[idx].avgTP;
      int finalDirection = readySignals[idx].finalDirection;
      int bufferIndex = readySignals[idx].bufferIndex;
      
      PrintFormat("?? Traitement du signal consolidé #%d: %s - Confiance: %.1f%%, Signaux: %d", 
                  idx + 1, currentSymbol, avgConfidence, signalCount);
      
      // VÉRIFICATION CRITIQUE: Le signal doit avoir au moins 20 signaux analysés
      if(signalCount < MIN_SIGNAL_COUNT)
      {
         PrintFormat("?? Signal consolidé pour %s IGNORÉ: seulement %d signaux analysés (< %d minimum requis) - Aucune notification envoyée",
                     currentSymbol, signalCount, MIN_SIGNAL_COUNT);
         continue; // Passer au signal suivant sans envoyer de notification
      }
      
      // Vérifier si on peut envoyer le signal (un seul par symbole toutes les 3.5 minutes)
      bool canSend = true;
      int lastSentIdx = -1;
      
      for(int j = 0; j < ArraySize(g_lastSignalSentSymbols); j++)
      {
         if(g_lastSignalSentSymbols[j] == currentSymbol)
         {
            lastSentIdx = j;
            if((currentTime - g_lastSignalSentTimes[j]) < 210)
            {
               canSend = false;
               PrintFormat("?? Signal consolidé pour %s IGNORÉ: timing non respecté (dernier signal envoyé il y a moins de 3.5 min) - Aucune notification envoyée",
                           currentSymbol);
               break;
            }
         }
      }
      
      // VÉRIFICATION FINALE: Timing respecté ET signal valide (>= 20 signaux) ET direction valide
      if(canSend && finalDirection != 0 && signalCount >= MIN_SIGNAL_COUNT)
      {
         // ENVOYER UNIQUEMENT les 3 premiers signaux consolidés (TOP 1, TOP 2 et TOP 3)
         // Les autres sont automatiquement bloqués par la boucle (topCount = 3 max)
         // VÉRIFICATION: Le signal doit avoir au moins 20 signaux analysés ET respecter le timing (3.5 min)
         if(InpEnableNotifications)
         {
            // Ajouter l'en-tête seulement pour le premier signal
            string header = (idx == 0) ? GetAlgorithmHeader() + "\n\n" : "";
            string separator = (idx < topCount - 1) ? "\n" + GetSignalSeparator() : "";
            
            // Formater le message avec mise en forme spéciale pour signaux à 100% de confiance
            string signalMsg;
            bool is100Percent = (avgConfidence >= 99.9); // Signal à 100% de confiance
            
            if(is100Percent)
            {
               // Signal à 100% - en gras et bleu (formatage spécial)
               signalMsg = StringFormat(
                  "%s?? **SIGNAL CONSOLIDÉ [%s] (3.5 min) - TOP %d - ? 100%% GAGNANT ?**\n" +
                  "**Type: %s**\n" +
                  "**Confiance moyenne: %.1f%%**\n" +
                  "**Nombre de signaux analysés: %d**\n" +
                  "**ENTRY: %.5f**\n" +
                  "**SL: %.5f**\n" +
                  "**TP: %.5f**\n" +
                  "**Timestamp: %s**%s",
                  header,
                  currentSymbol,
                  idx + 1,
                  (finalDirection > 0 ? "BUY" : "SELL"),
                  avgConfidence,
                  signalCount,
                  avgEntry,
                  avgSL,
                  avgTP,
                  TimeToString(currentTime, TIME_DATE|TIME_SECONDS),
                  separator
               );
            }
            else
            {
               signalMsg = StringFormat(
                  "%s?? SIGNAL CONSOLIDÉ [%s] (3.5 min) - TOP %d\n" +
                  "Type: %s\n" +
                  "Confiance moyenne: %.1f%%\n" +
                  "Nombre de signaux analysés: %d\n" +
                  "ENTRY: %.5f\n" +
                  "SL: %.5f\n" +
                  "TP: %.5f\n" +
                  "Timestamp: %s%s",
                  header,
                  currentSymbol,
                  idx + 1,
                  (finalDirection > 0 ? "BUY" : "SELL"),
                  avgConfidence,
                  signalCount,
                  avgEntry,
                  avgSL,
                  avgTP,
                  TimeToString(currentTime, TIME_DATE|TIME_SECONDS),
                  separator
               );
            }
            
            SendTradingNotification(currentSymbol, finalDirection, avgEntry, avgSL, avgTP, signalCount, avgConfidence, is100Percent);
            Print(signalMsg);
         }
         
         // Mettre à jour le dernier signal envoyé
         if(lastSentIdx >= 0)
         {
            g_lastSignalSentTimes[lastSentIdx] = currentTime;
         }
         else
         {
            int size = ArraySize(g_lastSignalSentSymbols);
            ArrayResize(g_lastSignalSentSymbols, size + 1);
            ArrayResize(g_lastSignalSentTimes, size + 1);
            g_lastSignalSentSymbols[size] = currentSymbol;
            g_lastSignalSentTimes[size] = currentTime;
         }
         
         PrintFormat("? Signal consolidé TOP %d envoyé pour %s: %s, Confiance=%.1f%%, Entry=%.5f, SL=%.5f, TP=%.5f",
                     idx + 1, currentSymbol, (finalDirection > 0 ? "BUY" : "SELL"), 
                     avgConfidence, avgEntry, avgSL, avgTP);
         
         // EXÉCUTER DIRECTEMENT LE TRADE pour les 3 meilleurs signaux consolidés (SANS LIMITE)
         // VÉRIFICATION: S'assurer que le signal a bien au moins 20 signaux analysés
         if(InpEnableTrading && signalCount >= MIN_SIGNAL_COUNT)
         {
            // Vérifier s'il existe déjà une position ouverte pour ce symbole spécifique
            bool hasPositionForSymbol = false;
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
               ulong ticket = PositionGetTicket(i);
               if(ticket > 0 && PositionSelectByTicket(ticket))
               {
                  if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
                     PositionGetString(POSITION_SYMBOL) == currentSymbol)
                  {
                     hasPositionForSymbol = true;
                     PrintFormat("?? Déjà une position ouverte pour %s. Signal consolidé TOP %d NON exécuté pour ce symbole.",
                                 currentSymbol, idx + 1);
                     break;
                  }
               }
            }
            
            if(!hasPositionForSymbol)
            {
               PrintFormat("?? EXÉCUTION DIRECTE du trade consolidé TOP %d: %s %s, Entry=%.5f, SL=%.5f, TP=%.5f",
                           idx + 1, (finalDirection > 0 ? "BUY" : "SELL"), currentSymbol, avgEntry, avgSL, avgTP);
               PrintFormat("? Signal validé: %d signaux analysés (>= %d minimum requis)", signalCount, MIN_SIGNAL_COUNT);
               
               // Exécuter directement le trade (sans limite de nombre de positions)
               ExecuteDirectTrade(currentSymbol, finalDirection, avgEntry, avgSL, avgTP, avgConfidence);
            }
         }
         else if(InpEnableTrading && signalCount < MIN_SIGNAL_COUNT)
         {
            PrintFormat("?? Signal consolidé TOP %d IGNORÉ: seulement %d signaux analysés (< %d minimum requis) - Trade NON exécuté",
                        idx + 1, signalCount, MIN_SIGNAL_COUNT);
         }
      }
      
      // Supprimer le buffer traité
      ArrayRemove(g_signalBuffers, bufferIndex, 1);
   }
   
   // Supprimer TOUS les autres buffers non traités (ceux qui ne sont pas dans les top 3)
   // Ces signaux sont BLOQUÉS et ne seront JAMAIS envoyés
   for(int i = ArraySize(g_signalBuffers) - 1; i >= 0; i--)
   {
      datetime windowEnd = g_signalBuffers[i].windowStart + 210;
      if(currentTime >= windowEnd && g_signalBuffers[i].signalCount > 0)
      {
         bool wasProcessed = false;
         // Vérifier si ce buffer a été traité (fait partie des top 3)
         for(int idx = 0; idx < topCount; idx++)
         {
            if(idx < ArraySize(readySignals) && readySignals[idx].symbol == g_signalBuffers[i].symbol)
            {
               wasProcessed = true;
               break;
            }
         }
         
         if(!wasProcessed)
         {
            if(g_signalBuffers[i].signalCount < MIN_SIGNAL_COUNT)
            {
               PrintFormat("?? BLOQUÉ - Signal consolidé pour %s (%d signaux analysés) - Seuil minimum de %d signaux non atteint - Signal NON envoyé et NON exécuté", 
                           g_signalBuffers[i].symbol, g_signalBuffers[i].signalCount, MIN_SIGNAL_COUNT);
            }
            else
            {
               PrintFormat("?? BLOQUÉ - Signal consolidé pour %s (%d signaux analysés) - Pas dans les TOP 3 - Signal NON envoyé et NON exécuté", 
                           g_signalBuffers[i].symbol, g_signalBuffers[i].signalCount);
            }
            ArrayRemove(g_signalBuffers, i, 1);
         }
      }
   }
   
   // Message récapitulatif
   if(ArraySize(readySignals) > topCount)
   {
      PrintFormat("?? RÉSUMÉ: %d signal(s) consolidé(s) envoyé(s) sur %d disponible(s) - %d signal(s) bloqué(s)", 
                  topCount, ArraySize(readySignals), ArraySize(readySignals) - topCount);
   }
}

//+------------------------------------------------------------------+
//| Dessine les EMA sur le graphique avec différentes couleurs       |
//+------------------------------------------------------------------+
void DrawEMAOnChart()
{
   if(!InpShowVisuals) return;
   
   string prefix = "EMA_" + (string)InpMagicNumber + "_";
   ENUM_TIMEFRAMES tf = InpSpikeTimeframe;
   int barsToDraw = 200; // Nombre de bougies à dessiner
   
   // Périodes et couleurs des EMA
   struct EMASetting {
      int period;
      color clr;
      int width;
      string name;
   };
   
   EMASetting emaSettings[] = {
      {10, clrLime, 2, "EMA10"},
      {20, clrYellow, 2, "EMA20"},
      {34, clrOrange, 2, "EMA34"},
      {50, clrDodgerBlue, 2, "EMA50"},
      {200, clrMagenta, 3, "EMA200"}
   };
   
   // Obtenir les données de prix
   MqlRates rates[];
   if(CopyRates(_Symbol, tf, 0, barsToDraw, rates) < barsToDraw)
   {
      Print("Erreur lors de la copie des données pour dessiner les EMA");
      return;
   }
   
   // Dessiner chaque EMA
   for(int i = 0; i < ArraySize(emaSettings); i++)
   {
      int period = emaSettings[i].period;
      string emaName = prefix + emaSettings[i].name;
      
      // Créer un handle pour l'EMA (uniquement pour le dessin)
      int emaHandle = iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
      if(emaHandle == INVALID_HANDLE)
      {
         Print("Erreur création EMA", period, ": ", GetLastError());
         continue;
      }
      
      // Copier les valeurs de l'EMA
      double emaValues[];
      ArraySetAsSeries(emaValues, true);
      if(CopyBuffer(emaHandle, 0, 0, barsToDraw, emaValues) <= 0)
      {
         Print("Erreur copie des données EMA", period);
         IndicatorRelease(emaHandle);
         continue;
      }
      
      // Supprimer l'ancienne ligne si elle existe
      ObjectDelete(0, emaName);
      
      // Créer la ligne EMA point par point
      for(int j = 1; j < barsToDraw && j < ArraySize(emaValues); j++)
      {
         string segmentName = emaName + "_" + IntegerToString(j);
         
         // Supprimer l'ancien segment
         ObjectDelete(0, segmentName);
         
         // Créer un nouveau segment de ligne
         if(ObjectCreate(0, segmentName, OBJ_TREND, 0, rates[j].time, emaValues[j], rates[j-1].time, emaValues[j-1]))
         {
            ObjectSetInteger(0, segmentName, OBJPROP_COLOR, emaSettings[i].clr);
            ObjectSetInteger(0, segmentName, OBJPROP_WIDTH, emaSettings[i].width);
            ObjectSetInteger(0, segmentName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, segmentName, OBJPROP_RAY_LEFT, false);
            ObjectSetInteger(0, segmentName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, segmentName, OBJPROP_BACK, false);
            ObjectSetInteger(0, segmentName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, segmentName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
         }
      }
      
      // Ajouter un label pour identifier l'EMA
      string labelName = emaName + "_LABEL";
      ObjectDelete(0, labelName);
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, rates[0].time, emaValues[0]))
      {
         ObjectSetString(0, labelName, OBJPROP_TEXT, "EMA" + IntegerToString(period));
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, emaSettings[i].clr);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         ObjectSetInteger(0, labelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      }
      
      // Libérer le handle EMA
      IndicatorRelease(emaHandle);
   }
   
   ChartRedraw();
   Print("EMA dessinées sur le graphique");
}

// ------------------ Gestion des trades ------------------
//+------------------------------------------------------------------+
//| Vérifie si un nouvel ordre peut être placé                       |
//+------------------------------------------------------------------+
bool CanPlaceNewOrder()
{
   string debugMsg = "Vérification des conditions de trading:\n";
   bool allConditions = true;
   
   if(!InpEnableTrading)
   {
      debugMsg += "- Le trading est désactivé dans les paramètres\n";
      allConditions = false;
   }
   
   // Vérifier les permissions de trading
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      debugMsg += "- Le trading n'est pas autorisé par le terminal\n";
      allConditions = false;
   }
   
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED))
   {
      debugMsg += "- Le trading n'est pas autorisé pour ce compte\n";
      allConditions = false;
   }
   
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      debugMsg += "- Le trading automatisé n'est pas autorisé\n";
      allConditions = false;
   }
   
   // Vérifier la connexion
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      debugMsg += "- Pas de connexion au serveur de trading\n";
      allConditions = false;
   }
   
   // Vérifier les permissions du symbole
   int tradeMode = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(tradeMode != SYMBOL_TRADE_MODE_FULL)
   {
      debugMsg += "- Le trading n'est pas autorisé pour ce symbole. Mode: " + IntegerToString(tradeMode) + "\n";
      allConditions = false;
   }
   
   // Vérifier le drawdown journalier
   if(InpEnableProtections && !CheckDailyDrawdown())
   {
      debugMsg += "- Le drawdown journalier maximum a été atteint\n";
      allConditions = false;
   }
   
   // Afficher le message de débogage si une condition n'est pas remplie
   if(!allConditions)
   {
      Print(debugMsg);
   }
   else
   {
      Print("Toutes les conditions de trading sont remplies");
   }
   
   return allConditions;
}

//+------------------------------------------------------------------+
//| Vérifie le drawdown journalier                                   |
//+------------------------------------------------------------------+
bool CheckDailyDrawdown()
{
   if(!InpEnableProtections) return true;
   
   datetime currentTime = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   
   // Réinitialiser au début d'une nouvelle journée
   MqlDateTime lastCheckedStruct;
   TimeToStruct(g_lastDayChecked, lastCheckedStruct);
   
   if(lastCheckedStruct.day != timeStruct.day || 
      lastCheckedStruct.mon != timeStruct.mon ||
      lastCheckedStruct.year != timeStruct.year)
   {
      g_dailyStartingBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_maxDailyDrawdown = g_dailyStartingBalance * (InpDailyDrawdownPercent / 100.0);
      g_lastDayChecked = currentTime;
      PrintFormat("Nouveau jour détecté. Solde de départ: %.2f, Drawdown max: %.2f", 
                 g_dailyStartingBalance, g_maxDailyDrawdown);
   }
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drawdown = g_dailyStartingBalance - currentEquity;
   
   if(drawdown > g_maxDailyDrawdown)
   {
      PrintFormat("Drawdown journalier dépassé: %.2f > %.2f (max)", 
                 drawdown, g_maxDailyDrawdown);
      return false;
   }
   
   return true;
}

// Compter positions ouvertes selon direction (filtre magic)
int CountOpenPositions(int direction)
{
   int count = 0;
   int total = PositionsTotal();

   for(int i=0; i<total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      long posType = PositionGetInteger(POSITION_TYPE);
      if(symbol == _Symbol && magic == (long)InpMagicNumber)
      {
         if(direction > 0 && posType == POSITION_TYPE_BUY) count++;
         if(direction < 0 && posType == POSITION_TYPE_SELL) count++;
      }
   }
   return count;
}

double CalculateLotSize(double atr_val)
{
   // si InpLotFixed > 0: utiliser it
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(InpLotFixed > 0.0)
   {
      double steps = MathFloor(InpLotFixed/lot_step + 0.5);
      double lot = steps * lot_step;
      if(lot < min_lot) lot = min_lot;
      if(lot > max_lot) lot = max_lot;
      return NormalizeDouble(lot,2);
   }

   // Calcul automatique basé sur le capital et le risque
   double accountBalance = (InpAccountBalance > 0) ? InpAccountBalance : AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (InpRiskPerTrade / 100.0);
   
   // Pour M1, utiliser des lots plus petits
   if(InpSpikeTimeframe == PERIOD_M1)
   {
      // Calculer le lot basé sur le risque et le SL
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      // SL en ATR pour M1 (plus serré)
      double slDistance = atr_val * InpSLMultiplierM1;
      double slPips = slDistance / point;
      
      if(slPips > 0 && tickValue > 0 && tickSize > 0)
      {
         // Calculer le lot pour risquer exactement riskAmount
         double lot = (riskAmount * tickSize) / (slPips * point * tickValue);
         lot = MathFloor(lot / lot_step) * lot_step;
         
         // Limiter aux bornes
         if(lot < min_lot) lot = min_lot;
         if(lot > max_lot) lot = max_lot;
         
         // Pour un capital de 10$, limiter à 0.01-0.05 max
         if(accountBalance <= 10.0 && lot > 0.05) lot = 0.05;
         
         return NormalizeDouble(lot, 2);
      }
   }

   // Sinon option basique: utiliser lot min (sécurisé)
   return NormalizeDouble(min_lot,2);
}

//+------------------------------------------------------------------+
//| Vérifie si on est en tendance haussière (true) ou baissière (false) |
//+------------------------------------------------------------------+
bool IsUptrend()
{
   // Obtenir l'index des handles pour le symbole actuel
   int index = GetSymbolHandleIndex(_Symbol);
   if(index < 0 || g_symbolHandles[index].ma20_handle == INVALID_HANDLE || g_symbolHandles[index].ma50_handle == INVALID_HANDLE)
      return false;

   double ma20[], ma50[];
   ArraySetAsSeries(ma20, true);
   ArraySetAsSeries(ma50, true);

   if(CopyBuffer(g_symbolHandles[index].ma20_handle, 0, 0, 1, ma20) <= 0 ||
      CopyBuffer(g_symbolHandles[index].ma50_handle, 0, 0, 1, ma50) <= 0)
   {
      Print("Erreur lecture MA20/MA50 pour ", _Symbol);
      return false;
   }

   return (ma20[0] > ma50[0]);
}

//+------------------------------------------------------------------+
//| Vérifie et gère les positions et ordres existants                |
//| - Limite à 1 position ouverte par symbole                        |
//| - Gère les ordres en attente existants                           |
//| Retourne true si une position est déjà ouverte sur ce symbole    |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   bool hasPosition = false;
   
   // Vérifier les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
            PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            hasPosition = true;
            break;
         }
      }
   }
   
   // Si une position est ouverte, annuler tous les ordres en attente
   if(hasPosition)
   {
      CancelAllPendingOrders();
      Print("Position déjà ouverte sur ", _Symbol, ". Tous les ordres en attente annulés.");
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Annule tous les ordres en attente pour le symbole actuel         |
//+------------------------------------------------------------------+
void CancelAllPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
            OrderGetString(ORDER_SYMBOL) == _Symbol)
         {
            trade.OrderDelete(ticket);
            Print("Ordre en attente #", ticket, " annulé.");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie si le lot est valide pour le trading                     |
//+------------------------------------------------------------------+
bool IsValidLotSize(double lot, string symbol)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Arrondir le lot selon le pas du broker
   lot = MathFloor(lot / stepLot) * stepLot;
   
   // Vérifier les limites
   if(lot < minLot || lot > maxLot)
      return false;
      
   // Pour les symboles Boom/Crash sur M1 avec petit capital, permettre des lots plus petits
   double accountBalance = (InpAccountBalance > 0) ? InpAccountBalance : AccountInfoDouble(ACCOUNT_BALANCE);
   double minLotBoomCrash = (InpSpikeTimeframe == PERIOD_M1 && accountBalance <= 10.0) ? 0.01 : 0.2;
   
   if((StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0) && lot < minLotBoomCrash)
      return false;
      
   return true;
}

//+------------------------------------------------------------------+
//| Normalise le lot selon les spécifications du symbole             |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lot, string symbol)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Pour les symboles Boom/Crash sur M1 avec petit capital, permettre des lots plus petits
   double accountBalance = (InpAccountBalance > 0) ? InpAccountBalance : AccountInfoDouble(ACCOUNT_BALANCE);
   double minLotBoomCrash = (InpSpikeTimeframe == PERIOD_M1 && accountBalance <= 10.0) ? 0.01 : 0.2;
   
   if(StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0)
      lot = MathMax(minLotBoomCrash, lot);
   
   // Arrondir selon le pas du broker
   lot = MathFloor(lot / stepLot) * stepLot;
   
   // Respecter les limites
   lot = MathMax(minLot, MathMin(maxLot, lot));
   
   return lot;
}

//+------------------------------------------------------------------+
//| Vérifie s'il y a un ordre en attente similaire                  |
//+------------------------------------------------------------------+
bool HasSimilarPendingOrder(ENUM_ORDER_TYPE orderType, double price, double sl, double tp)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double priceDiff = point * 10; // Tolérance de 10 points
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
            OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_TYPE) == orderType)
         {
            double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
            double orderSL = OrderGetDouble(ORDER_SL);
            double orderTP = OrderGetDouble(ORDER_TP);
            
            // Vérifier si l'ordre est similaire (même type et prix proches)
            if(MathAbs(orderPrice - price) <= priceDiff &&
               MathAbs(orderSL - sl) <= priceDiff &&
               MathAbs(orderTP - tp) <= priceDiff)
            {
               return true;
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si le symbole actuel est dans la liste des prioritaires  |
//+------------------------------------------------------------------+
bool IsPrioritySymbol()
{
   string currentSymbol = _Symbol;
   for(int i = 0; i < ArraySize(PRIORITY_SYMBOLS); i++)
   {
      if(currentSymbol == PRIORITY_SYMBOLS[i])
         return true;
   }
   // si tu veux ignorer ce check, retourne true ici
   Print("Symbole ", currentSymbol, " n'est pas dans la liste des symboles prioritaires");
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si la perte potentielle est acceptable                  |
//+------------------------------------------------------------------+
bool IsLossAcceptable(double lotSize, double stopLossPips, double maxLoss = 3.0)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tickValue <= 0 || tickSize <= 0 || point <= 0)
   {
      Print("Erreur: Impossible de calculer la perte potentielle");
      return false;
   }
   
   double lossInAccountCurrency = (lotSize * stopLossPips * point * tickValue) / tickSize;
   return (lossInAccountCurrency <= maxLoss);
}

//+------------------------------------------------------------------+
//| Compte le nombre d'ordres limites actifs pour un symbole        |
//+------------------------------------------------------------------+
int CountPendingLimitOrdersForSymbol(string symbol)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if((orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) &&
            OrderGetString(ORDER_SYMBOL) == symbol &&
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Compte le nombre d'ordres limites actifs (tous symboles)        |
//+------------------------------------------------------------------+
int CountPendingLimitOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if((orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) &&
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Compte le nombre total de positions ouvertes (tous symboles)    |
//+------------------------------------------------------------------+
int CountTotalOpenPositions()
{
   int count = 0;
   
   // Compter les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   
   // Compter les ordres limit en attente
   count += CountPendingLimitOrders();
   
   return count;
}

//+------------------------------------------------------------------+
//| Supprime tous les ordres limites non exécutés pour un symbole   |
//+------------------------------------------------------------------+
void DeletePendingLimitOrdersForSymbol(string symbol)
{
   int deletedCount = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if((orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) &&
            OrderGetString(ORDER_SYMBOL) == symbol &&
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            if(trade.OrderDelete(ticket))
            {
               deletedCount++;
               PrintFormat("??? Ordre limit #%d supprimé pour %s (remplacé par nouveau signal consolidé)", ticket, symbol);
            }
            else
            {
               PrintFormat("? Erreur lors de la suppression de l'ordre limit #%d: %s", ticket, trade.ResultComment());
            }
         }
      }
   }
   if(deletedCount > 0)
   {
      PrintFormat("? %d ordre(s) limit supprimé(s) pour %s", deletedCount, symbol);
   }
}

//+------------------------------------------------------------------+
//| Trouve les supports/résistances les plus proches du prix actuel |
//+------------------------------------------------------------------+
bool FindNearestSupportResistance(string symbol, ENUM_TIMEFRAMES tf, double currentPrice, double &nearestSupport, double &nearestResistance)
{
   nearestSupport = 0;
   nearestResistance = 0;
   
   // Détecter les swings pour trouver supports/résistances
   SwingPoint swings[];
   int swingCount = DetectSwings(symbol, tf, 200, 5, swings);
   
   if(swingCount < 2)
   {
      // Si pas assez de swings, utiliser les prix récents comme fallback
      MqlRates rates[];
      if(CopyRates(symbol, tf, 0, 50, rates) > 0)
      {
         double minLow = rates[0].low;
         double maxHigh = rates[0].high;
         for(int i = 1; i < ArraySize(rates); i++)
         {
            if(rates[i].low < minLow) minLow = rates[i].low;
            if(rates[i].high > maxHigh) maxHigh = rates[i].high;
         }
         nearestSupport = minLow;
         nearestResistance = maxHigh;
         return true;
      }
      return false;
   }
   
   // Trouver le support le plus proche (swing low) en dessous du prix actuel
   double closestSupport = 0;
   double supportDistance = DBL_MAX;
   
   // Trouver la résistance la plus proche (swing high) au-dessus du prix actuel
   double closestResistance = 0;
   double resistanceDistance = DBL_MAX;
   
   for(int i = 0; i < swingCount; i++)
   {
      if(!swings[i].isHigh) // Support (swing low)
      {
         if(swings[i].price < currentPrice)
         {
            double dist = currentPrice - swings[i].price;
            if(dist < supportDistance)
            {
               supportDistance = dist;
               closestSupport = swings[i].price;
            }
         }
      }
      else // Résistance (swing high)
      {
         if(swings[i].price > currentPrice)
         {
            double dist = swings[i].price - currentPrice;
            if(dist < resistanceDistance)
            {
               resistanceDistance = dist;
               closestResistance = swings[i].price;
            }
         }
      }
   }
   
   nearestSupport = closestSupport;
   nearestResistance = closestResistance;
   
   return (nearestSupport > 0 || nearestResistance > 0);
}

//+------------------------------------------------------------------+
//| Ajuste le prix d'entrée pour qu'il soit proche des S/R          |
//+------------------------------------------------------------------+
double AdjustEntryPriceToSR(string symbol, int direction, double proposedEntry, double nearestSupport, double nearestResistance, double currentPrice)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tolerance = point * 50; // Tolérance de 50 points
   
   if(direction > 0) // BUY - doit être proche d'un support
   {
      if(nearestSupport > 0)
      {
         double distanceToSupport = MathAbs(proposedEntry - nearestSupport);
         if(distanceToSupport > tolerance)
         {
            // Ajuster pour être plus proche du support
            double adjustedEntry = nearestSupport + (point * 10); // 10 points au-dessus du support
            PrintFormat("?? Ajustement prix BUY: %.5f -> %.5f (proche du support %.5f)", 
                        proposedEntry, adjustedEntry, nearestSupport);
            return NormalizeDouble(adjustedEntry, digits);
         }
      }
   }
   else // SELL - doit être proche d'une résistance
   {
      if(nearestResistance > 0)
      {
         double distanceToResistance = MathAbs(proposedEntry - nearestResistance);
         if(distanceToResistance > tolerance)
         {
            // Ajuster pour être plus proche de la résistance
            double adjustedEntry = nearestResistance - (point * 10); // 10 points en dessous de la résistance
            PrintFormat("?? Ajustement prix SELL: %.5f -> %.5f (proche de la résistance %.5f)", 
                        proposedEntry, adjustedEntry, nearestResistance);
            return NormalizeDouble(adjustedEntry, digits);
         }
      }
   }
   
   return NormalizeDouble(proposedEntry, digits);
}

//+------------------------------------------------------------------+
//| Exécute directement un trade au marché pour un symbole donné     |
//+------------------------------------------------------------------+
void ExecuteDirectTrade(string symbol, int direction, double entryPrice, double sl, double tp, double signalConfidence = 0.0)
{
   if(direction == 0 || !InpEnableTrading) return;
   
   // VÉRIFIER SI LE TRADING EST AUTORISÉ POUR CE SYMBOLE
   if(!IsTradeAllowedForSymbol(symbol))
   {
      PrintFormat("?? %s: Trading non autorisé - En attente d'un spike", symbol);
      return;
   }
   
   // Vérifier s'il existe déjà une position ouverte pour ce symbole
   bool hasPositionForSymbol = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
            PositionGetString(POSITION_SYMBOL) == symbol)
         {
            hasPositionForSymbol = true;
            PrintFormat("?? Déjà une position ouverte pour %s. Trade direct NON exécuté.", symbol);
            break;
         }
      }
   }
   
   if(hasPositionForSymbol) return;
   
   // UTILISER LA NOUVELLE FONCTION POUR CALCULER SL/TP AVEC RATIO 80% GARANTI
   CalculateStrictRatioSLTP(symbol, entryPrice, direction, sl, tp);
   
   // Calculer le lot
   double lotSize = InpLimitOrderLotSize;
   if(lotSize <= 0)
   {
      double accountBalance = (InpAccountBalance > 0) ? InpAccountBalance : AccountInfoDouble(ACCOUNT_BALANCE);
      if(accountBalance <= 10.0)
         lotSize = 0.01;
      else
      {
         // Calculer l'ATR pour le symbole
         double atr = 0;
         MqlRates rates[];
         if(CopyRates(symbol, InpSpikeTimeframe, 0, 1, rates) > 0)
            atr = rates[0].high - rates[0].low;
         
         if(atr <= 0)
         {
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            atr = point * 100; // Valeur par défaut
         }
         lotSize = CalculateLotSize(atr);
      }
   }
   
   // Normaliser le lot
   lotSize = NormalizeLotSize(lotSize, symbol);
   if(!IsValidLotSize(lotSize, symbol))
   {
      Print("? Taille de lot invalide pour ", symbol);
      return;
   }
   
   // Normaliser les prix
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   // Obtenir le prix actuel pour l'entrée
   double currentPrice = (direction > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Vérifier si c'est un trade inverse
   bool isReverseTrade = ((direction > 0 && IsSymbolCrash(symbol)) || 
                         (direction < 0 && IsSymbolBoom(symbol)));
   
   if(isReverseTrade)
   {
      lotSize *= 0.75; // Réduire le lot pour les trades inverses
      lotSize = NormalizeLotSize(lotSize, symbol);
   }
   
   // Exécuter le trade au marché IMMÉDIATEMENT (ENTRÉE SNIPER)
   // Les signaux consolidés sont exécutés aussitôt qu'un spike est capté
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   bool success = false;
   string tradeType = (direction > 0) ? "BUY" : "SELL";
   string comment = StringFormat("Signal Direct SNIPER %s", tradeType);
   
   if(direction > 0)
   {
      success = trade.Buy(lotSize, symbol, 0, sl, tp, comment);
   }
   else
   {
      success = trade.Sell(lotSize, symbol, 0, sl, tp, comment);
   }
   
   if(success)
   {
      ulong ticket = trade.ResultOrder();
      PrintFormat("? Trade direct exécuté: %s %s, Lot=%.2f, Entry=%.5f, SL=%.5f, TP=%.5f, Ticket=%llu",
                  tradeType, symbol, lotSize, currentPrice, sl, tp, ticket);
      
      // Enregistrer le signal pour l'apprentissage
      RecordSignalFeatures(symbol, direction, signalConfidence, currentPrice, sl, tp, 1, 1);
   }
   else
   {
      PrintFormat("? Échec exécution trade direct: %s %s, Erreur: %d - %s",
                  tradeType, symbol, GetLastError(), trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Fonction d'exécution des trades avec niveaux spécifiques        |
//| Place 3 ordres limite si activé, sinon ordre au marché          |
//| Pour M1: exécute aussi un ordre immédiat si signal fort          |
//+------------------------------------------------------------------+
void ExecuteTradeWithLevels(int direction, double atr_val, double entryPrice, double sl, double tp, bool isReverseTrade = false, double signalConfidence = 0.0)
{
   if(direction == 0) return;
   
   string symbol = _Symbol;
   
   // DÉSACTIVÉ: Permettre plusieurs positions pour capturer plus de spikes
   // if(HasOpenPosition())
   // {
   //    Print("Position déjà ouverte sur ", symbol, ". Aucun nouveau trade ne sera pris.");
   //    return;
   // }
   
   // Vérifier le nombre d'ordres limite existants (MAXIMUM 2)
   int existingLimits = CountPendingLimitOrders();
   if(existingLimits >= 2)
   {
      Print("Déjà 2 ordres limite en attente. Aucun nouvel ordre ne sera placé.");
      return;
   }
   
   // Calculer le lot pour chaque ordre (ajusté pour M1 et petit capital)
   double lotPerOrder = InpLimitOrderLotSize;
   if(lotPerOrder <= 0)
   {
      // Calculer automatiquement le lot pour M1 et petit capital
      if(InpSpikeTimeframe == PERIOD_M1)
      {
         double accountBalance = (InpAccountBalance > 0) ? InpAccountBalance : AccountInfoDouble(ACCOUNT_BALANCE);
         if(accountBalance <= 10.0)
         {
            lotPerOrder = 0.01; // Lot minimum pour capital de 10$
         }
         else
         {
            lotPerOrder = CalculateLotSize(atr_val); // Calcul automatique
         }
      }
      else
      {
         lotPerOrder = 0.1; // Valeur par défaut pour autres timeframes
      }
   }
   
   // Pour les trades inverses, réduire légèrement le lot pour plus de prudence
   if(isReverseTrade)
   {
      lotPerOrder *= 0.75; // Lot réduit de 25% pour les trades inverses
      Print("?? Trade inverse détecté - Lot réduit à ", lotPerOrder, " pour plus de prudence");
   }
   
   // Vérifier que le lot est valide
   if(!IsValidLotSize(lotPerOrder, symbol))
   {
      Print("Erreur: Taille de lot invalide pour ", symbol, ". Lot demandé: ", lotPerOrder);
      return;
   }
   
   // Normaliser le lot selon les spécifications du symbole
   lotPerOrder = NormalizeLotSize(lotPerOrder, symbol);
   
   // Arrondir les prix selon les spécifications du symbole
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   entryPrice = NormalizeDouble(entryPrice, digits);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   // Exécution du trade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   // Calculer le stop loss en pips pour la vérification du risque
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double stopLossPips = (direction > 0) ? (entryPrice - sl) / point : (sl - entryPrice) / point;
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double potentialLoss = (lotPerOrder * stopLossPips * point * tickValue) / tickSize;
   
   // DÉSACTIVÉ: Permettre des trades même si perte potentielle élevée (pour capturer les spikes)
   // Pour les trades inverses, limite de perte plus stricte (max 2$ au lieu de 3$)
   // double maxLoss = isReverseTrade ? 2.0 : 3.0;
   // if(potentialLoss > maxLoss)
   // {
   //    Print("Perte potentielle trop élevée: ", DoubleToString(potentialLoss, 2), " $ (max: ", maxLoss, " $)");
   //    return;
   // }
   Print("?? Perte potentielle: ", DoubleToString(potentialLoss, 2), " $ (vérification désactivée pour permettre trading)");
   
   string comment = isReverseTrade ? "Spike REVERSE " : "Spike ";
   
   // PLACER 2 ORDRES LIMITE MAXIMUM si activé (PROCHES DU PRIX ACTUEL pour M1)
   if(InpUseLimitOrders)
   {
      // Pour M1, réduire la distance des ordres limite pour qu'ils soient plus proches
      double limitDistanceMult = (InpSpikeTimeframe == PERIOD_M1) ? 0.15 : InpLimitOrderDistance; // 0.15 ATR pour M1
      double limitDistance = atr_val * limitDistanceMult;
      int ordersPlaced = 0;
      
      // Obtenir le prix actuel
      double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      for(int i = 0; i < 2; i++) // MAXIMUM 2 ordres limite
      {
         double limitPrice;
         
         if(direction > 0) // BUY
         {
            // 2 ordres limite en dessous du prix actuel (optimisés pour M5 - ENTRÉES SNIPER)
            if(InpSpikeTimeframe == PERIOD_M5)
            {
               // Pour M5, placer les ordres PRÉCIS: 0.03, 0.06 ATR en dessous (entrées sniper optimisées)
               limitPrice = currentBid - (atr_val * (0.03 + (i * 0.03)));
            }
            else if(InpSpikeTimeframe == PERIOD_M1)
            {
               // Pour M1, placer les ordres TRÈS PRÉCIS: 0.02, 0.04 ATR en dessous (entrées sniper)
               limitPrice = currentBid - (atr_val * (0.02 + (i * 0.02)));
            }
            else
            {
               limitPrice = entryPrice - (limitDistance * (i + 1));
            }
            limitPrice = NormalizeDouble(limitPrice, digits);
            
            // Vérifier que le prix limite est valide
            if(limitPrice >= currentBid)
            {
               Print("?? Ordre limite ", i+1, " ignoré: prix limite (", limitPrice, ") >= prix actuel (", currentBid, ")");
               continue;
            }
            
            // Calculer SL et TP pour cet ordre (ajustés pour M1)
            double slMult = (InpSpikeTimeframe == PERIOD_M1) ? InpSLMultiplierM1 : 1.5;
            double tpMult = (InpSpikeTimeframe == PERIOD_M1) ? InpTPMultiplierM1 : 3.0;
            double orderSL = limitPrice - (atr_val * slMult);  // SL augmenté via InpSLMultiplierM1
            double orderTP = limitPrice + (atr_val * tpMult);
            orderSL = NormalizeDouble(orderSL, digits);
            orderTP = NormalizeDouble(orderTP, digits);
            
            if(trade.BuyLimit(lotPerOrder, limitPrice, symbol, orderSL, orderTP, ORDER_TIME_GTC, 0, comment + "BUY_L" + IntegerToString(i+1)))
            {
               ordersPlaced++;
               Print("? Ordre limite BUY ", i+1, " placé: Prix=", limitPrice, ", Lot=", lotPerOrder, ", SL=", orderSL, ", TP=", orderTP);
            }
            else
            {
               Print("? Échec ordre limite BUY ", i+1, ". Erreur: ", GetLastError(), " - ", trade.ResultComment());
            }
         }
         else // SELL
         {
            // 2 ordres limite au-dessus du prix actuel (optimisés pour M5 - ENTRÉES SNIPER)
            if(InpSpikeTimeframe == PERIOD_M5)
            {
               // Pour M5, placer les ordres PRÉCIS: 0.03, 0.06 ATR au-dessus (entrées sniper optimisées)
               limitPrice = currentAsk + (atr_val * (0.03 + (i * 0.03)));
            }
            else if(InpSpikeTimeframe == PERIOD_M1)
            {
               // Pour M1, placer les ordres TRÈS PRÉCIS: 0.02, 0.04 ATR au-dessus (entrées sniper)
               limitPrice = currentAsk + (atr_val * (0.02 + (i * 0.02)));
            }
            else
            {
               limitPrice = entryPrice + (limitDistance * (i + 1));
            }
            limitPrice = NormalizeDouble(limitPrice, digits);
            
            // Vérifier que le prix limite est valide
            if(limitPrice <= currentAsk)
            {
               Print("?? Ordre limite ", i+1, " ignoré: prix limite (", limitPrice, ") <= prix actuel (", currentAsk, ")");
               continue;
            }
            
            // Calculer SL et TP pour cet ordre (ajustés pour M1)
            double slMult = (InpSpikeTimeframe == PERIOD_M1) ? InpSLMultiplierM1 : 1.5;
            double tpMult = (InpSpikeTimeframe == PERIOD_M1) ? InpTPMultiplierM1 : 3.0;
            double orderSL = limitPrice + (atr_val * slMult);  // SL augmenté via InpSLMultiplierM1
            double orderTP = limitPrice - (atr_val * tpMult);
            orderSL = NormalizeDouble(orderSL, digits);
            orderTP = NormalizeDouble(orderTP, digits);
            
            if(trade.SellLimit(lotPerOrder, limitPrice, symbol, orderSL, orderTP, ORDER_TIME_GTC, 0, comment + "SELL_L" + IntegerToString(i+1)))
            {
               ordersPlaced++;
               Print("? Ordre limite SELL ", i+1, " placé: Prix=", limitPrice, ", Lot=", lotPerOrder, ", SL=", orderSL, ", TP=", orderTP);
            }
            else
            {
               Print("? Échec ordre limite SELL ", i+1, ". Erreur: ", GetLastError(), " - ", trade.ResultComment());
            }
         }
      }
      
      // POUR M5: Exécuter aussi un ordre au marché si le signal est fort (ENTRÉE SNIPER IMMÉDIATE)
      if(InpSpikeTimeframe == PERIOD_M5 && InpExecuteImmediateM5)
      {
         // Vérifier la force du signal pour décider si on exécute immédiatement
         bool executeImmediate = false;
         
         if(signalConfidence >= InpImmediateConfidence || ordersPlaced >= 1)
         {
            executeImmediate = true;
         }
         
         if(executeImmediate)
         {
            // Exécuter un ordre au marché avec un lot réduit (60% du lot des ordres limite pour M5)
            double immediateLot = lotPerOrder * 0.6;
            if(immediateLot < SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN))
               immediateLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            immediateLot = NormalizeLotSize(immediateLot, symbol);
            
            bool ok = false;
            if(direction > 0)
            {
               ok = trade.Buy(immediateLot, symbol, 0, sl, tp, comment + "BUY_IMMEDIATE_M5");
            }
            else
            {
               ok = trade.Sell(immediateLot, symbol, 0, sl, tp, comment + "SELL_IMMEDIATE_M5");
            }
            
            if(ok)
            {
               Print("? Ordre IMMÉDIAT exécuté (M5) - Direction: ", (direction > 0 ? "BUY" : "SELL"),
                     ", Lot: ", immediateLot, ", Entry: ", DoubleToString(entryPrice, digits));
            }
            else
            {
               Print("?? Échec ordre immédiat M5. Erreur: ", GetLastError(), " - ", trade.ResultComment());
            }
         }
      }
      
      // POUR M1: Exécuter aussi un ordre au marché si le signal est fort (ENTRÉE SNIPER IMMÉDIATE)
      // Les entrées doivent être précises et immédiates dès qu'un spike est détecté
      if(InpSpikeTimeframe == PERIOD_M1 && InpExecuteImmediateM1)
      {
         // Vérifier la force du signal pour décider si on exécute immédiatement
         // Exécuter immédiatement si:
         // - Confiance >= InpImmediateConfidence OU
         // - Au moins 1 ordre limite placé avec succès (réduit de 2 à 1 pour entrée plus rapide)
         bool executeImmediate = false;
         
         if(signalConfidence >= InpImmediateConfidence || ordersPlaced >= 1)
         {
            executeImmediate = true;
         }
         
         if(executeImmediate)
         {
            // Exécuter un ordre au marché avec un lot réduit (50% du lot des ordres limite)
            double immediateLot = lotPerOrder * 0.5;
            if(immediateLot < SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN))
               immediateLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
            immediateLot = NormalizeLotSize(immediateLot, symbol);
            
            bool ok = false;
            if(direction > 0)
            {
               ok = trade.Buy(immediateLot, symbol, 0, sl, tp, comment + "BUY_IMMEDIATE");
            }
            else
            {
               ok = trade.Sell(immediateLot, symbol, 0, sl, tp, comment + "SELL_IMMEDIATE");
            }
            
            if(ok)
            {
               Print("? Ordre IMMÉDIAT exécuté (M1) - Direction: ", (direction > 0 ? "BUY" : "SELL"),
                     ", Lot: ", immediateLot, ", Entry: ", DoubleToString(entryPrice, digits));
            }
            else
            {
               Print("?? Échec ordre immédiat. Erreur: ", GetLastError(), " - ", trade.ResultComment());
            }
         }
      }
      
      if(ordersPlaced > 0)
      {
         string tradeType = isReverseTrade ? "INVERSE" : "NORMAL";
         Print("? ", ordersPlaced, " ordre(s) limite ", tradeType, " placé(s) avec succès");
      }
      else
      {
         Print("? Aucun ordre limite n'a pu être placé");
      }
   }
   else
   {
      // Ordre au marché classique (si ordres limite désactivés)
      bool ok = false;
      if(direction > 0)
      {
         ok = trade.Buy(lotPerOrder, symbol, 0, sl, tp, comment + "BUY");
      }
      else
      {
         ok = trade.Sell(lotPerOrder, symbol, 0, sl, tp, comment + "SELL");
      }
      
      if(!ok)
      {
         Print("? Échec de l'ordre. Erreur: ", GetLastError(), " - ", trade.ResultComment());
      }
      else
      {
         string tradeType = isReverseTrade ? "INVERSE" : "NORMAL";
         Print("? Ordre ", tradeType, " exécuté avec succès - Direction: ", (direction > 0 ? "BUY" : "SELL"),
               ", Lot: ", lotPerOrder,
               ", Entry: ", DoubleToString(entryPrice, digits),
               ", SL: ", DoubleToString(sl, digits),
               ", TP: ", DoubleToString(tp, digits));
      }
   }
}

//+------------------------------------------------------------------+
//| Fonction d'exécution des trades                                 |
//+------------------------------------------------------------------+
void ExecuteTrade(int direction, double atr_val, bool isLimitOrder = false, double limitPrice = 0.0)
{
   if(direction == 0) return;
   
   string symbol = _Symbol;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double entry = (direction > 0) ? ask : bid;
   
   // RÈGLE: Un seul trade à la fois sur le compte
   if(HasOpenPosition())
   {
      Print("❌ Trade bloqué - Une position est déjà ouverte sur le compte");
      return;
   }
   
   // RÈGLE: Vérifier si un spike est détecté pour ce symbole
   if(IsSpikeDetectedForSymbol(symbol, PERIOD_M1))
   {
      Print("❌ Trade bloqué - Spike détecté sur ", symbol, ". Attente de la fin du mouvement.");
      return;
   }
   
   // Calcul de la taille de lot pour respecter la perte maximale de 3$
   double sl = 0, tp = 0;
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // Calcul du SL basé sur la volatilité (1.5 ATR pour une entrée sniper)
   double slDistance = atr_val * 1.5;
   
   if(direction > 0) // Achat
   {
      sl = NormalizeDouble(ask - slDistance, digits);
      tp = NormalizeDouble(ask + (slDistance * 2), digits); // Ratio 1:2
   }
   else // Vente
   {
      sl = NormalizeDouble(bid + slDistance, digits);
      tp = NormalizeDouble(bid - (slDistance * 2), digits); // Ratio 1:2
   }
   
   // Calcul du lot pour respecter la perte maximale de 3$
   double stopLossPips = (direction > 0) ? (entry - sl) / point : (sl - entry) / point;
   double lot = 0.1; // Lot par défaut
   
   if(tickValue > 0 && tickSize > 0 && stopLossPips > 0)
   {
      lot = (3.0 * tickSize) / (stopLossPips * point * tickValue);
      lot = MathMin(maxLot, MathMax(minLot, lot));
      lot = MathFloor(lot / lotStep) * lotStep; // Arrondir au lotStep le plus proche
   }
   
   // Vérification finale du lot
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   // Calcul de la perte potentielle
   double potentialLoss = (lot * stopLossPips * point * tickValue) / tickSize;
   
   // VÉRIFICATION CRITIQUE: La perte potentielle ne doit pas dépasser 3$
   if(potentialLoss > 3.0)
   {
      // Ajuster le lot pour respecter la limite de 3$
      double maxAllowedLot = (3.0 * tickSize) / (stopLossPips * point * tickValue);
      maxAllowedLot = MathFloor(maxAllowedLot / lotStep) * lotStep;
      
      if(maxAllowedLot >= minLot)
      {
         lot = maxAllowedLot;
         Print("⚠️ Lot ajusté à ", lot, " pour respecter la limite de perte maximale");
      }
      else
      {
         Print("❌ Trade annulé - Le lot minimum ", minLot, " dépasse la limite de perte de 3$");
         return;
      }
   }
   
   // Annuler tous les ordres en attente avant d'exécuter un ordre au marché
   if(!isLimitOrder) 
   {
      CancelAllPendingOrders();
      Print("🗑️ Tous les ordres en attente ont été annulés");
   }
   
   if(direction > 0)
   {
      if(isLimitOrder)
      {
         if(!trade.BuyLimit(lot, limitPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "SMC Buy Limit"))
         {
            Print("Échec de l'ordre d'achat limite. Erreur: ", GetLastError(), 
                  " - ", trade.ResultComment());
         }
         else
         {
            Print("Ordre d'achat limite placé à ", DoubleToString(limitPrice, _Digits), 
                  " Lot: ", lot,
                  " SL: ", DoubleToString(sl, _Digits), 
                  " TP: ", DoubleToString(tp, _Digits));
         }
      }
      else
      {
         if(!trade.Buy(lot, _Symbol, 0, sl, tp, "SMC Buy Signal"))
         {
            Print("Échec de l'ordre d'achat. Erreur: ", GetLastError(), 
                  " - ", trade.ResultComment());
         }
         else
         {
            Print("Ordre d'achat exécuté à ", DoubleToString(ask, _Digits), 
                  " Lot: ", lot,
                  " SL: ", DoubleToString(sl, _Digits), 
                  " TP: ", DoubleToString(tp, _Digits));
         }
      }
   }
   else
   {
      if(isLimitOrder)
      {
         if(!trade.SellLimit(lot, limitPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "SMC Sell Limit"))
         {
            Print("Échec de l'ordre de vente limite. Erreur: ", GetLastError(),
                  " - ", trade.ResultComment());
         }
         else
         {
            Print("Ordre de vente limite placé à ", DoubleToString(limitPrice, _Digits),
                  " Lot: ", lot,
                  " SL: ", DoubleToString(sl, _Digits),
                  " TP: ", DoubleToString(tp, _Digits));
         }
      }
      else
      {
         if(!trade.Sell(lot, _Symbol, 0, sl, tp, "SMC Sell Signal"))
         {
            Print("Échec de l'ordre de vente. Erreur: ", GetLastError(),
                  " - ", trade.ResultComment());
         }
         else
         {
            Print("Ordre de vente exécuté à ", DoubleToString(bid, _Digits),
                  " Lot: ", lot,
                  " SL: ", DoubleToString(sl, _Digits),
                  " TP: ", DoubleToString(tp, _Digits));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Exécution trade pour logique prédictive (ATR-based SL/TP) avec gestion des positions uniques
//+------------------------------------------------------------------+
void ExecuteTradePredictive(int direction, double atrVal)
{
   if(direction == 0) return;
   
   if(HasOpenPosition())
   {
      Print("?? Trade prédictif ignoré - position déjà ouverte sur ", _Symbol);
      return;
   }

   bool isUp = IsUptrend();
   if((direction > 0 && !isUp) || (direction < 0 && isUp))
   {
      Print("Rejet trade prédictif : contre-tendance détectée");
      return;
   }

   double lot = CalculateLotSize(atrVal);
   if(lot <= 0) 
   { 
      Print("Erreur: Taille de lot invalide: ", lot); 
      return; 
   }

   // Calcul des prix d'entrée, SL et TP
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (direction > 0) ? ask : bid;
   double sl, tp;
   double sl_distance = atrVal * InpATRMultiplier;
   double tp_distance = atrVal * (InpATRMultiplier * 2.5);
   double limit_distance = atrVal * 0.5; // Distance pour les ordres limites

   // 1. Exécution de l'ordre au marché principal
   if(direction > 0)
   {
      sl = price - sl_distance;
      tp = price + tp_distance;
   }
   else
   {
      sl = price + sl_distance;
      tp = price - tp_distance;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   bool ok = false;
   if(direction > 0) 
      ok = trade.Buy(lot, _Symbol, price, sl, tp, "FxPro_PRED_BUY");
   else 
      ok = trade.Sell(lot, _Symbol, price, sl, tp, "FxPro_PRED_SELL");

   if(!ok) 
   {
      Print("Erreur execution trade prédictif: ", GetLastError());
      return;
   }
   else 
   {
      PrintFormat("Trade prédictif exécuté dir=%d lot=%.2f price=%.5f sl=%.5f tp=%.5f", 
                 direction, lot, price, sl, tp);
   }

   // 2. Ajout des ordres limites
   double limit_price1, limit_price2;
   double limit_lot = lot * 0.5; // Taille réduite pour les ordres limites

   if(direction > 0)
   {
      // Ordre d'achat limite 1 (en dessous du prix actuel)
      limit_price1 = price - limit_distance;
      sl = limit_price1 - sl_distance;
      tp = limit_price1 + tp_distance;
      ok = trade.BuyLimit(limit_lot, limit_price1, _Symbol, sl, tp, 
                         ORDER_TIME_GTC, 0, "FxPro_LIMIT_BUY_1");
      PrintFormat("Ordre d'achat limite 1: lot=%.2f price=%.5f %s", 
                 limit_lot, limit_price1, ok ? "placé" : "échoué");

      // Ordre d'achat limite 2 (encore plus bas)
      limit_price2 = limit_price1 - limit_distance;
      sl = limit_price2 - sl_distance;
      tp = limit_price2 + tp_distance;
      ok = trade.BuyLimit(limit_lot, limit_price2, _Symbol, sl, tp, 
                         ORDER_TIME_GTC, 0, "FxPro_LIMIT_BUY_2");
      PrintFormat("Ordre d'achat limite 2: lot=%.2f price=%.5f %s", 
                 limit_lot, limit_price2, ok ? "placé" : "échoué");
   }
   else
   {
      // Ordre de vente limite 1 (au-dessus du prix actuel)
      limit_price1 = price + limit_distance;
      sl = limit_price1 + sl_distance;
      tp = limit_price1 - tp_distance;
      ok = trade.SellLimit(limit_lot, limit_price1, _Symbol, sl, tp, 
                          ORDER_TIME_GTC, 0, "FxPro_LIMIT_SELL_1");
      PrintFormat("Ordre de vente limite 1: lot=%.2f price=%.5f %s", 
                 limit_lot, limit_price1, ok ? "placé" : "échoué");

      // Ordre de vente limite 2 (encore plus haut)
      limit_price2 = limit_price1 + limit_distance;
      sl = limit_price2 + sl_distance;
      tp = limit_price2 - tp_distance;
      ok = trade.SellLimit(limit_lot, limit_price2, _Symbol, sl, tp, 
                          ORDER_TIME_GTC, 0, "FxPro_LIMIT_SELL_2");
      PrintFormat("Ordre de vente limite 2: lot=%.2f price=%.5f %s", 
                 limit_lot, limit_price2, ok ? "placé" : "échoué");
   }
}

//+------------------------------------------------------------------+
//| Gestionnaire d'événements de trading                             |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Vérifier si une nouvelle position a été ouverte ou fermée
   datetime checkStart = TimeCurrent() - 60; // Vérifier les 60 dernières secondes
   if(HistorySelect(checkStart, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      if(total > 0)
      {
         // Parcourir les derniers deals pour détecter ouvertures et fermetures
         for(int i = total - 1; i >= MathMax(0, total - 10); i--)
         {
            ulong ticket = HistoryDealGetTicket(i);
            if(ticket <= 0) continue;
            
            long dealEntry = HistoryDealGetInteger(ticket, DEAL_ENTRY);
            long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
            long dealMagic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
            
            // Vérifier si c'est une position de notre robot
            if(dealMagic != InpMagicNumber) continue;
            
            if(dealEntry == DEAL_ENTRY_IN)
            {
               // Nouvelle position ouverte - Annuler tous les ordres en attente
               int ord_total = OrdersTotal();
               for(int j = ord_total-1; j >= 0; j--)
               {
                  ulong ord_ticket = OrderGetTicket(j);
                  if(ord_ticket > 0 && OrderGetString(ORDER_SYMBOL) == _Symbol)
                  {
                     trade.OrderDelete(ord_ticket);
                  }
               }
            }
            else if(dealEntry == DEAL_ENTRY_OUT)
            {
               // Position fermée - Enregistrer le résultat
               double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
               double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
               double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
               double totalProfit = profit + swap + commission;
               
               // Trouver le ticket de position correspondant
               ulong positionTicket = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
               
               // Enregistrer le résultat pour le calcul des performances
               RecordSignalResult(positionTicket, totalProfit, false, 0.0);
               
               // Forcer la mise à jour du panneau de performance
               UpdatePerformancePanel();
               
               PrintFormat("?? Position fermée détectée: Ticket=%llu, Profit=%.2f", positionTicket, totalProfit);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ADX compute                                                       |
//+------------------------------------------------------------------+
double ComputeADX(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   // Obtenir l'index des handles pour le symbole spécifié
   int index = GetSymbolHandleIndex(symbol);
   if(index < 0)
   {
      // Si le handle n'existe pas, créer un handle temporaire
      int tempHandle = iADX(symbol, tf, period);
      if(tempHandle == INVALID_HANDLE) return 0.0;
      
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(tempHandle, 0, 0, 1, buf) <= 0)
      {
         IndicatorRelease(tempHandle);
         return 0.0;
      }
      
      double val = buf[0];
      IndicatorRelease(tempHandle);
      return val;
   }
   
   // Créer un handle ADX temporaire pour ce symbole
   int adxHandle = iADX(symbol, tf, period);
   if(adxHandle == INVALID_HANDLE) return 0.0;
   
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(adxHandle, 0, 0, 1, buf) <= 0)
   {
      IndicatorRelease(adxHandle);
      return 0.0;
   }
   
   double val = buf[0];
   IndicatorRelease(adxHandle);
   return val;
}

//+------------------------------------------------------------------+
//| Gestion du risque avec moins de volatilité - DÉSACTIVÉ           |
//| SL/TP fixes - aucune modification après ouverture               |
//+------------------------------------------------------------------+
void ManageLowVolatilityRisk()
{
   // FONCTION DÉSACTIVÉE - Les SL/TP restent fixes après l'ouverture
   // Plus aucune modification de stop loss ou take profit
   return;
   
   /* Code original désactivé
   int total = PositionsTotal();
   for(int i=0; i<total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket==0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      long magic = (long)PositionGetInteger(POSITION_MAGIC);
      string sym = PositionGetString(POSITION_SYMBOL);
      if(magic != (long)InpMagicNumber || sym != _Symbol) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double cur_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double cur_sl = PositionGetDouble(POSITION_SL);
      double cur_tp = PositionGetDouble(POSITION_TP);
      double profit = PositionGetDouble(POSITION_PROFIT);
      
      // 1. Vérifier si le gain minimum de 1$ est atteint
      if(InpEnableAutoClose && profit >= InpMinProfitDollars)
      {
         // Fermer la position si le gain minimum est atteint
         if(trade.PositionClose(ticket))
         {
            PrintFormat("? Position fermée - Gain minimum atteint: %.2f$", profit);
            continue;
         }
      }
      
      // 2. Calculer SL et TP basés sur les pourcentages (20% perte, 80% profit)
      double atr = GetCurrentATR(_Symbol);
      if(atr <= 0) continue;
      
      // Calculer la distance en pips basée sur le risque
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = accountBalance * (InpMaxRiskPercent / 100.0);
      double lotSize = PositionGetDouble(POSITION_VOLUME);
      double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * lotSize;
      
      if(pipValue <= 0) continue;
      
      // Distance en pips pour le risque de 20%
      double slDistancePips = riskAmount / pipValue;
      double tpDistancePips = slDistancePips * (InpTakeProfitPercent / InpStopLossPercent); // Ratio 4:1
      
      // Convertir en prix
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double slDistancePrice = slDistancePips * point;
      double tpDistancePrice = tpDistancePips * point;
      
      // 3. Ajuster le Stop Loss
      double new_sl = 0;
      if(type == POSITION_TYPE_BUY)
      {
         new_sl = cur_price - slDistancePrice;
         // Trailing stop: déplacer le SL vers le haut si le prix monte
         if(new_sl > cur_sl + point * 2.0)
         {
            if(trade.PositionModify(ticket, new_sl, cur_tp))
            {
               PrintFormat("?? SL ajusté BUY - Ticket: %llu, Nouveau SL: %.5f", ticket, new_sl);
            }
         }
      }
      else // SELL
      {
         new_sl = cur_price + slDistancePrice;
         // Trailing stop: déplacer le SL vers le bas si le prix baisse
         if(new_sl < cur_sl - point * 2.0)
         {
            if(trade.PositionModify(ticket, new_sl, cur_tp))
            {
               PrintFormat("?? SL ajusté SELL - Ticket: %llu, Nouveau SL: %.5f", ticket, new_sl);
            }
         }
      }
      
      // 4. Ajuster le Take Profit si nécessaire
      double new_tp = 0;
      if(type == POSITION_TYPE_BUY)
      {
         new_tp = open_price + tpDistancePrice;
         if(MathAbs(new_tp - cur_tp) > point * 5.0) // Ajuster seulement si différence significative
         {
            if(trade.PositionModify(ticket, cur_sl, new_tp))
            {
               PrintFormat("?? TP ajusté BUY - Ticket: %llu, Nouveau TP: %.5f", ticket, new_tp);
            }
         }
      }
      else // SELL
      {
         new_tp = open_price - tpDistancePrice;
         if(MathAbs(new_tp - cur_tp) > point * 5.0)
         {
            if(trade.PositionModify(ticket, cur_sl, new_tp))
            {
               PrintFormat("?? TP ajusté SELL - Ticket: %llu, Nouveau TP: %.5f", ticket, new_tp);
            }
         }
      }
   }
   */
}
//+------------------------------------------------------------------+
//| STRUCTURES POUR L'ANALYSE STATISTIQUE                             |
//+------------------------------------------------------------------+
struct SpikeStatistics
{
    double mean;
    double stddev;
    double zscore_current;
    double skewness;
    double kurtosis;
    double min_price;
    double max_price;
};

//+------------------------------------------------------------------+
//| Calcule les statistiques avancées pour la détection de spikes      |
//+------------------------------------------------------------------+
SpikeStatistics CalculateAdvancedStatistics(string symbol, ENUM_TIMEFRAMES tf, int lookback)
{
    SpikeStatistics stats = {0};
    
    MqlRates rates[];
    if(CopyRates(symbol, tf, 0, lookback, rates) < lookback) return stats;
    
    // Calculer la moyenne
    double sum = 0;
    for(int i = 0; i < lookback; i++)
    {
        sum += rates[i].close;
    }
    stats.mean = sum / lookback;
    
    // Calculer l'écart-type
    double variance = 0;
    for(int i = 0; i < lookback; i++)
    {
        variance += MathPow(rates[i].close - stats.mean, 2);
    }
    stats.stddev = MathSqrt(variance / (lookback - 1));
    
    // Z-Score actuel
    if(stats.stddev > 0)
        stats.zscore_current = (rates[0].close - stats.mean) / stats.stddev;
    
    // Skewness et Kurtosis
    double sum3 = 0, sum4 = 0;
    for(int i = 0; i < lookback; i++)
    {
        double z = (rates[i].close - stats.mean) / stats.stddev;
        sum3 += MathPow(z, 3);
        sum4 += MathPow(z, 4);
    }
    stats.skewness = sum3 / lookback;
    stats.kurtosis = sum4 / lookback;
    
    // Prix min/max
    stats.min_price = rates[0].low;
    stats.max_price = rates[0].high;
    for(int i = 1; i < lookback; i++)
    {
        if(rates[i].low < stats.min_price) stats.min_price = rates[i].low;
        if(rates[i].high > stats.max_price) stats.max_price = rates[i].high;
    }
    
    return stats;
}

//+------------------------------------------------------------------+
//| Détecte les mouvements en ciseaux                                 |
//+------------------------------------------------------------------+
bool DetectScissorPattern(string symbol, ENUM_TIMEFRAMES tf, int period)
{
    if(!InpEnableScissorTrades) return false;
    MqlRates rates[];
    if(CopyRates(symbol, tf, 0, period, rates) < period) return false;
    
    // Détection d'un motif haussier en ciseaux: alternances de petites corrections
    // et d'impulsions haussières fortes avec structure HL/HH dominante
    int impulses = 0, corrections = 0, swings = 0;
    for(int i = 1; i < period-1; i++)
    {
        double body = MathAbs(rates[i].close - rates[i].open);
        double range = rates[i].high - rates[i].low;
        if(range <= 0) continue;
        bool bullish = (rates[i].close > rates[i].open);
        bool strong  = (body >= range * 0.6);
        if(bullish && strong) impulses++;
        else if(!strong) corrections++;
        if(rates[i].low > rates[i+1].low && rates[i].high > rates[i+1].high) swings++;
    }
    // Conditions minimales
    return (impulses >= 3 && swings >= 3);
}

//+------------------------------------------------------------------+
//| Détecte les patterns fractals                                     |
//+------------------------------------------------------------------+
bool DetectFractalSpike(string symbol, ENUM_TIMEFRAMES tf, double threshold)
{
    MqlRates rates[];
    if(CopyRates(symbol, tf, 0, 5, rates) < 5) return false;
    
    // Vérifier si la bougie du milieu est un fractal
    double middle = rates[2].close;
    double range = rates[2].high - rates[2].low;
    
    if(range == 0) return false;
    
    // Variation des prix sur différentes échelles
    double scale1 = MathAbs(rates[0].close - rates[4].close);
    double scale2 = MathAbs(rates[1].close - rates[3].close);
    double scale3 = MathAbs(rates[2].close - rates[2].open);
    
    // Ratio de variation (indicateur fractal)
    double fractal_ratio = (scale1 + scale2 + scale3) / (3 * range);
    
    return (fractal_ratio > threshold);
}

//+------------------------------------------------------------------+
//| Détecte les gaps de prix                                          |
//+------------------------------------------------------------------+
bool DetectPriceGap(string symbol, ENUM_TIMEFRAMES tf)
{
    MqlRates rates[];
    if(CopyRates(symbol, tf, 0, 2, rates) < 2) return false;
    
    double gap_size = MathAbs(rates[1].close - rates[0].open);
    double avg_range = (rates[1].high - rates[1].low + rates[0].high - rates[0].low) / 2;
    
    return (gap_size > avg_range * 0.5);
}

//+------------------------------------------------------------------+
//| Détecte le pattern Hammer                                         |
//+------------------------------------------------------------------+
bool DetectHammerPattern(string symbol, ENUM_TIMEFRAMES tf)
{
    MqlRates rates[];
    if(CopyRates(symbol, tf, 0, 1, rates) < 1) return false;
    
    double body_size = MathAbs(rates[0].close - rates[0].open);
    double upper_shadow = rates[0].high - MathMax(rates[0].open, rates[0].close);
    double lower_shadow = MathMin(rates[0].open, rates[0].close) - rates[0].low;
    
    return (body_size < (rates[0].high - rates[0].low) * 0.3 && 
            lower_shadow > body_size * 2 && 
            upper_shadow < body_size * 0.5);
}

//+------------------------------------------------------------------+
//| Détecte le pattern Engulfing                                     |
//+------------------------------------------------------------------+
bool DetectEngulfingPattern(string symbol, ENUM_TIMEFRAMES tf)
{
    MqlRates rates[];
    if(CopyRates(symbol, tf, 0, 2, rates) < 2) return false;
    
    bool bullish_engulfing = (rates[1].close < rates[1].open &&  // Rouge précédent
                             rates[0].close > rates[0].open &&  // Vert actuel
                             rates[0].open < rates[1].close &&   // Open below previous close
                             rates[0].close > rates[1].open);   // Close above previous open
    
    bool bearish_engulfing = (rates[1].close > rates[1].open &&  // Vert précédent
                             rates[0].close < rates[0].open &&  // Rouge actuel
                             rates[0].open > rates[1].close &&   // Open above previous close
                             rates[0].close < rates[1].open);   // Close below previous open
    
    return bullish_engulfing || bearish_engulfing;
}

//+------------------------------------------------------------------+
//| Détecte le squeeze des bandes de Bollinger                        |
//+------------------------------------------------------------------+
bool DetectBollingerSqueeze(string symbol, ENUM_TIMEFRAMES tf)
{
    int bb_handle = iBands(symbol, tf, 20, 0, 2.0, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE) return false;
    
    double upper[], lower[], middle[];
    ArraySetAsSeries(upper, true);
    ArraySetAsSeries(lower, true);
    ArraySetAsSeries(middle, true);
    
    if(CopyBuffer(bb_handle, 0, 0, 2, upper) < 2 ||
       CopyBuffer(bb_handle, 1, 0, 2, lower) < 2 ||
       CopyBuffer(bb_handle, 2, 0, 2, middle) < 2)
    {
        IndicatorRelease(bb_handle);
        return false;
    }
    
    double band_width = upper[0] - lower[0];
    double avg_width = (upper[1] - lower[1] + band_width) / 2;
    
    IndicatorRelease(bb_handle);
    return (band_width < avg_width * 0.8);
}

//+------------------------------------------------------------------+
//| Détecte le breakout des bandes de Bollinger                      |
//+------------------------------------------------------------------+
bool DetectBollingerBreakout(string symbol, ENUM_TIMEFRAMES tf)
{
    int bb_handle = iBands(symbol, tf, 20, 0, 2.0, PRICE_CLOSE);
    if(bb_handle == INVALID_HANDLE) return false;
    
    double upper[], lower[];
    ArraySetAsSeries(upper, true);
    ArraySetAsSeries(lower, true);
    
    if(CopyBuffer(bb_handle, 0, 0, 2, upper) < 2 ||
       CopyBuffer(bb_handle, 1, 0, 2, lower) < 2)
    {
        IndicatorRelease(bb_handle);
        return false;
    }
    
    MqlRates rates[];
    if(CopyRates(symbol, tf, 0, 1, rates) < 1)
    {
        IndicatorRelease(bb_handle);
        return false;
    }
    
    bool breakout_up = rates[0].close > upper[0];
    bool breakout_down = rates[0].close < lower[0];
    
    IndicatorRelease(bb_handle);
    return breakout_up || breakout_down;
}

//+------------------------------------------------------------------+
//| Obtient la valeur RSI                                            |
//+------------------------------------------------------------------+
double GetRSI(string symbol, ENUM_TIMEFRAMES tf, int period = 14)
{
    int rsi_handle = iRSI(symbol, tf, period, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) return 50.0;
    
    double rsi[];
    ArraySetAsSeries(rsi, true);
    
    if(CopyBuffer(rsi_handle, 0, 0, 1, rsi) < 1)
    {
        IndicatorRelease(rsi_handle);
        return 50.0;
    }
    
    IndicatorRelease(rsi_handle);
    return rsi[0];
}

//+------------------------------------------------------------------+
//| Obtient le signal MACD                                           |
//+------------------------------------------------------------------+
double GetMACDSignal(string symbol, ENUM_TIMEFRAMES tf)
{
    int macd_handle = iMACD(symbol, tf, 12, 26, 9, PRICE_CLOSE);
    if(macd_handle == INVALID_HANDLE) return 0.0;
    
    double macd_main[], macd_signal[];
    ArraySetAsSeries(macd_main, true);
    ArraySetAsSeries(macd_signal, true);
    
    if(CopyBuffer(macd_handle, 0, 0, 1, macd_main) < 1 ||
       CopyBuffer(macd_handle, 1, 0, 1, macd_signal) < 1)
    {
        IndicatorRelease(macd_handle);
        return 0.0;
    }
    
    double signal = macd_main[0] - macd_signal[0];
    IndicatorRelease(macd_handle);
    return signal;
}

//+------------------------------------------------------------------+
//| Système principal de détection de spikes scientifique             |
//+------------------------------------------------------------------+
bool ScientificSpikeDetection(string symbol, ENUM_TIMEFRAMES tf, double &strength, int &direction)
{
    strength = 0.0;
    direction = 0;
    
    if(!InpEnableScientificDetection) return false;
    
    // 1. Analyse statistique avancée
    SpikeStatistics stats = CalculateAdvancedStatistics(symbol, tf, InpScientificLookback);
    
    // 2. Détection des mouvements en ciseaux
    bool scissor_pattern = InpEnableScissorDetection ? DetectScissorPattern(symbol, tf, 20) : false;
    
    // 3. Analyse fractale
    bool fractal_spike = InpEnableFractalDetection ? DetectFractalSpike(symbol, tf, 1.2) : false;
    
    // 4. Volume anormal
    double current_volume = (double)iVolume(symbol, tf, 0);
    double volume_ma[];
    ArraySetAsSeries(volume_ma, true);
    int volume_handle = iMA(symbol, tf, 20, 0, MODE_SMA, VOLUME_TICK);
    
    double volume_ratio = 1.0;
    if(volume_handle != INVALID_HANDLE && CopyBuffer(volume_handle, 0, 0, 1, volume_ma) > 0)
    {
        volume_ratio = (volume_ma[0] > 0) ? current_volume / volume_ma[0] : 1.0;
    }
    
    // 5. Détection des gaps
    bool gap_detected = DetectPriceGap(symbol, tf);
    
    // 6. Détection des patterns de chandelier
    bool hammer_pattern = DetectHammerPattern(symbol, tf);
    bool engulfing_pattern = DetectEngulfingPattern(symbol, tf);
    
    // 7. Analyse des bandes de Bollinger
    bool bb_squeeze = DetectBollingerSqueeze(symbol, tf);
    bool bb_breakout = DetectBollingerBreakout(symbol, tf);
    
    // 8. Analyse du momentum
    double rsi_value = GetRSI(symbol, tf, 14);
    double macd_signal = GetMACDSignal(symbol, tf);
    
    // 9. Calcul de l'ATR ratio pour la volatilité
    double current_atr = iATR(symbol, tf, 14);
    double atr_ma[];
    ArraySetAsSeries(atr_ma, true);
    int atr_handle = iMA(symbol, tf, 20, 0, MODE_SMA, PRICE_CLOSE);
    double atr_ratio = 1.0;
    if(atr_handle != INVALID_HANDLE && CopyBuffer(atr_handle, 0, 0, 20, atr_ma) > 0)
    {
        double avg_atr = 0;
        for(int i = 0; i < 20; i++) avg_atr += atr_ma[i];
        avg_atr /= 20;
        atr_ratio = (avg_atr > 0) ? current_atr / avg_atr : 1.0;
    }
    
    // CALCUL STRICT DU SIGNAL STRENGTH POUR SCALPING AVEC PETIT CAPITAL
    // Approche conservatrice: plusieurs critères doivent être remplis simultanément

    double signal_strength = 0.0;
    int criteriaCount = 0; // Nombre de critères remplis

    // CRITÈRE 1: Z-Score significatif (OBLIGATOIRE pour scalping)
    bool zscoreCriteria = false;
    if(MathAbs(stats.zscore_current) > InpZScoreThreshold * 1.3) // Seuil plus strict: 1.3x
    {
        signal_strength += 35.0;
        zscoreCriteria = true;
        criteriaCount++;
    }

    // CRITÈRE 2: Volume anormal élevé (OBLIGATOIRE pour scalping)
    bool volumeCriteria = false;
    if(volume_ratio > InpVolumeMultiplier * 1.2) // Seuil plus strict: 1.2x
    {
        signal_strength += 25.0;
        volumeCriteria = true;
        criteriaCount++;
    }

    // CRITÈRE 3: Patterns de chandelier confirmant (AU MOINS UN)
    bool patternCriteria = false;
    if(hammer_pattern || engulfing_pattern)
    {
        signal_strength += 15.0;
        patternCriteria = true;
        criteriaCount++;
    }

    // CRITÈRE 4: Breakout ou gap (bonus)
    if(bb_breakout || gap_detected)
    {
        signal_strength += 10.0;
        criteriaCount++;
    }

    // CRITÈRE 5: Patterns avancés (ciseaux ou fractal)
    if(scissor_pattern || fractal_spike)
    {
        signal_strength += 10.0;
        criteriaCount++;
    }

    // CRITÈRE 6: Volatilité élevée confirmée
    if(atr_ratio > 1.5)
    {
        signal_strength += 5.0;
        criteriaCount++;
    }

    // DÉTERMINATION DE LA DIRECTION - APPROCHE STRICTE
    // Pour scalping: TOUS les critères obligatoires doivent être remplis
    bool mandatoryCriteriaOK = (zscoreCriteria && volumeCriteria && patternCriteria);

    if(!mandatoryCriteriaOK)
    {
        // Critères obligatoires non remplis - pas de signal
        PrintFormat("?? Spike scientifique NON validé pour scalping - Critères manquants (Z-Score: %s, Volume: %s, Pattern: %s)",
                    zscoreCriteria ? "OK" : "NON", volumeCriteria ? "OK" : "NON", patternCriteria ? "OK" : "NON");
        return false;
    }

    if(IsSymbolBoom(symbol))
    {
        // Pour Boom: BUY uniquement si spike haussier confirmé
        bool zscore_buy = stats.zscore_current > InpZScoreThreshold * 1.3;
        bool volume_buy = volume_ratio > InpVolumeMultiplier * 1.2;
        bool pattern_buy = (hammer_pattern || engulfing_pattern || bb_breakout);

        // TOUS les critères doivent être vrais
        if(zscore_buy && volume_buy && pattern_buy)
        {
            direction = 1;
            PrintFormat("? BOOM: SPIKE SCIENTIFIQUE VALIDÉ - Z-Score=%.2f, Volume=%.2fx, Patterns confirmés",
                       stats.zscore_current, volume_ratio);
        }
        else
        {
            direction = 0;
        }
    }
    else if(IsSymbolCrash(symbol))
    {
        // Pour Crash: SELL uniquement si spike baissier confirmé
        bool zscore_sell = stats.zscore_current < -InpZScoreThreshold * 1.3;
        bool volume_sell = volume_ratio > InpVolumeMultiplier * 1.2;
        bool pattern_sell = (hammer_pattern || engulfing_pattern || bb_breakout);

        // TOUS les critères doivent être vrais
        if(zscore_sell && volume_sell && pattern_sell)
        {
            direction = -1;
            PrintFormat("? CRASH: SPIKE SCIENTIFIQUE VALIDÉ - Z-Score=%.2f, Volume=%.2fx, Patterns confirmés",
                       stats.zscore_current, volume_ratio);
        }
        else
        {
            direction = 0;
        }
    }
    else
    {
        // Pour les autres symboles: approche stricte aussi
        direction = 0;
    }
    
    strength = MathMin(100, signal_strength);

    // Afficher les détails de détection uniquement si validé
    if(direction != 0)
    {
        PrintFormat("?? SPIKE SCIENTIFIQUE CONFIRMÉ %s:", symbol);
        PrintFormat("   ? Z-Score: %.2f (seuil: %.2f)", stats.zscore_current, InpZScoreThreshold * 1.3);
        PrintFormat("   ? Volume: %.2fx (seuil: %.2fx)", volume_ratio, InpVolumeMultiplier * 1.2);
        PrintFormat("   ? Patterns: Hammer=%s, Engulfing=%s, Breakout=%s",
                    hammer_pattern ? "OUI" : "NON",
                    engulfing_pattern ? "OUI" : "NON",
                    bb_breakout ? "OUI" : "NON");
        PrintFormat("   ?? Critères validés: %d/6, Force: %.1f%%, Direction: %s",
                    criteriaCount, strength, direction > 0 ? "ACHAT" : "VENTE");
    }

    // Retourner true uniquement si force >= seuil ET direction définie ET critères obligatoires OK
    return (strength >= InpSpikeThresholdScientific && direction != 0 && mandatoryCriteriaOK);
}

//+------------------------------------------------------------------+
//| Obtient l'index des handles d'indicateurs pour un symbole spécifique |
//+------------------------------------------------------------------+
int GetSymbolHandleIndex(string symbol)
{
   // Rechercher le symbole dans le tableau
   for(int i = 0; i < ArraySize(g_symbolHandles); i++)
   {
      // Vérifier si les handles sont valides pour ce symbole
      if(g_symbolHandles[i].atr_handle != INVALID_HANDLE)
      {
         double testValue[];
         if(CopyBuffer(g_symbolHandles[i].atr_handle, 0, 0, 1, testValue) > 0)
         {
            // Handles valides, retourner l'index
            return i;
         }
      }
   }
   
   // Si non trouvé, créer un nouveau jeu de handles pour ce symbole
   int size = ArraySize(g_symbolHandles);
   ArrayResize(g_symbolHandles, size + 1);
   
   // Initialiser les handles pour le symbole
   g_symbolHandles[size].atr_handle = iATR(symbol, InpSpikeTimeframe, 14);
   g_symbolHandles[size].ma20_handle = iMA(symbol, InpSpikeTimeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   g_symbolHandles[size].ma50_handle = iMA(symbol, InpSpikeTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   g_symbolHandles[size].short_atr_handle = iATR(symbol, InpSpikeTimeframe, 5);
   g_symbolHandles[size].long_atr_handle = iATR(symbol, InpSpikeTimeframe, 50);
   
   Print("Handles d'indicateurs créés pour ", symbol);
   return size;
}

//+------------------------------------------------------------------+
//| Initialise les handles pour tous les symboles surveillés           |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Initialise les handles pour tous les symboles surveillés (version sécurisée) |
//+------------------------------------------------------------------+
void InitializeAllSymbolHandles()
{
   ArrayResize(g_symbolHandles, 0);
   
   // Utiliser les symboles PRIORITY_SYMBOLS au lieu de g_symbolsToWatch
   Print("Initialisation des handles pour ", ArraySize(PRIORITY_SYMBOLS), " symboles prioritaires...");
   
   int successCount = 0;
   int totalCount = ArraySize(PRIORITY_SYMBOLS);
   
   for(int i = 0; i < totalCount; i++)
   {
      string symbol = PRIORITY_SYMBOLS[i];
      
      // Vérifier si le symbole est disponible avant de créer les handles
      if(!SymbolSelect(symbol, true))
      {
         Print("Symbole non disponible: ", symbol, " - ignoré");
         continue;
      }
      
      // Créer les handles
      int handleIndex = GetSymbolHandleIndex(symbol);
      if(handleIndex >= 0)
      {
         successCount++;
         Print("Handles créés avec succès pour: ", symbol);
      }
      else
      {
         Print("Échec création handles pour: ", symbol, " - continuation");
      }
   }
   
   Print("Initialisation terminée: ", successCount, "/", totalCount, " symboles avec handles");
}

//+------------------------------------------------------------------+
//| Libère tous les handles d'indicateurs                             |
//+------------------------------------------------------------------+
void ReleaseAllSymbolHandles()
{
   for(int i = 0; i < ArraySize(g_symbolHandles); i++)
   {
      g_symbolHandles[i].ReleaseAll();
   }
   ArrayResize(g_symbolHandles, 0);
   
   // Libérer aussi les handles globaux
   if(g_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_atr_handle); g_atr_handle = INVALID_HANDLE; }
   if(g_ma20_handle != INVALID_HANDLE) { IndicatorRelease(g_ma20_handle); g_ma20_handle = INVALID_HANDLE; }
   if(g_ma50_handle != INVALID_HANDLE) { IndicatorRelease(g_ma50_handle); g_ma50_handle = INVALID_HANDLE; }
   if(g_short_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_short_atr_handle); g_short_atr_handle = INVALID_HANDLE; }
   if(g_long_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_long_atr_handle); g_long_atr_handle = INVALID_HANDLE; }
}

//+------------------------------------------------------------------+
//| Exécuter la stratégie de trade automatique (Robot 3)             |
//| Déclenche automatiquement les trades quand le prix touche EMA 10 |
//+------------------------------------------------------------------+
void ExecuteAutoTradeStrategy()
{
   // Scanner TOUS les symboles attachés au robot et détecter quand le prix touche l'EMA 10
   // Exécuter automatiquement BUY pour Boom, SELL pour Crash quand le prix touche EMA 10
   
   string allSymbols[];
   ScanAllChartSymbols(allSymbols);
   
   if(ArraySize(allSymbols) == 0) return;
   
   // Scanner tous les symboles Boom/Crash
   for(int s = 0; s < ArraySize(allSymbols); s++)
   {
      string symbol = allSymbols[s];
      bool isBoom = (StringFind(symbol, "Boom", 0) >= 0);
      bool isCrash = (StringFind(symbol, "Crash", 0) >= 0);
      
      if(!isBoom && !isCrash) continue;
      
      // Vérifier qu'on n'a pas déjà une position pour ce symbole
      if(GetPositionCountForSymbol(symbol) > 0) continue;
      
      // Vérifier qu'on n'a pas atteint le maximum de positions
      if(GetTotalActivePositions() >= InpMaxSymbolsToTrade) break;
      
      // DÉTECTER QUAND LE PRIX TOUCHE L'EMA 10
      // Utiliser le timeframe M1 pour EMA 10 (comme demandé)
      int ema10_handle = iMA(symbol, PERIOD_M1, InpMA10Period, 0, MODE_EMA, PRICE_CLOSE);
      
      if(ema10_handle != INVALID_HANDLE)
      {
         double ema10[];
         ArraySetAsSeries(ema10, true);
         
         if(CopyBuffer(ema10_handle, 0, 0, 3, ema10) >= 3)
         {
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            double askPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double atr = GetATRValue(symbol, PERIOD_M1, InpATR_Period);
            if(atr <= 0) atr = SymbolInfoDouble(symbol, SYMBOL_POINT) * 100;
            
            // Distance pour considérer que le prix "touche" l'EMA 10 (plus permissif pour détecter plus d'opportunités)
            double touchDistance = atr * InpMATouchDistance; // Utiliser le paramètre configurable
            if(touchDistance <= 0) touchDistance = atr * 1.0; // Fallback si paramètre trop petit
            double distanceToEMA = MathAbs(currentPrice - ema10[0]);
            bool isTouchingEMA = (distanceToEMA <= touchDistance);
            
            // Obtenir le prix précédent pour voir la direction
            MqlRates rates[];
            ArraySetAsSeries(rates, true);
            if(CopyRates(symbol, PERIOD_M1, 0, 3, rates) >= 3)
            {
               double prevPrice = rates[1].close;
               
               // Vérifier si le prix évolue vers l'EMA 10 (veut toucher)
               bool approachingEMA = false;
               
               if(isBoom)
               {
                  // Pour Boom: prix monte vers l'EMA 10 (en dessous et monte, OU au-dessus et très proche)
                  // Le prix doit être en train de se rapprocher de l'EMA
                  bool priceBelowEMA = (currentPrice < ema10[0]);
                  bool priceRising = (currentPrice > prevPrice);
                  bool gettingCloser = (MathAbs(currentPrice - ema10[0]) < MathAbs(prevPrice - ema10[1]));
                  
                  approachingEMA = (isTouchingEMA || 
                                    (priceBelowEMA && priceRising && gettingCloser) ||
                                    (priceBelowEMA && distanceToEMA <= atr * 1.5)); // Dans 1.5 ATR en dessous (plus permissif)
               }
               else if(isCrash)
               {
                  // Pour Crash: prix descend vers l'EMA 10 (au-dessus et descend, OU en dessous et très proche)
                  bool priceAboveEMA = (currentPrice > ema10[0]);
                  bool priceFalling = (currentPrice < prevPrice);
                  bool gettingCloser = (MathAbs(currentPrice - ema10[0]) < MathAbs(prevPrice - ema10[1]));
                  
                  approachingEMA = (isTouchingEMA || 
                                    (priceAboveEMA && priceFalling && gettingCloser) ||
                                    (priceAboveEMA && distanceToEMA <= atr * 1.5)); // Dans 1.5 ATR au-dessus (plus permissif)
               }
               
               // Si le prix touche ou veut toucher (évolue vers) l'EMA 10 -> EXÉCUTER LE TRADE AUTOMATIQUEMENT
               if(isTouchingEMA || approachingEMA)
               {
                  int tradeDirection = 0;
                  double entryPrice = 0;
                  double sl = 0, tp = 0;
               
                  if(isBoom)
                  {
                     // BOOM -> BUY quand le prix touche EMA 10
                     tradeDirection = 1;
                     entryPrice = askPrice;
                     sl = entryPrice - atr * 1.5;
                     tp = entryPrice + atr * 3.0;
                     
                     PrintFormat("🚀 SIGNAL EMA 10: %s - Prix touche EMA 10 (M1) -> BUY", symbol);
                     PrintFormat("   Prix: %.5f, EMA 10: %.5f, Distance: %.5f", 
                                 currentPrice, ema10[0], distanceToEMA);
                  }
                  else if(isCrash)
                  {
                     // CRASH -> SELL quand le prix touche EMA 10
                     tradeDirection = -1;
                     entryPrice = currentPrice;
                     sl = entryPrice + atr * 1.5;
                     tp = entryPrice - atr * 3.0;
                     
                     PrintFormat("🚀 SIGNAL EMA 10: %s - Prix touche EMA 10 (M1) -> SELL", symbol);
                     PrintFormat("   Prix: %.5f, EMA 10: %.5f, Distance: %.5f", 
                                 currentPrice, ema10[0], distanceToEMA);
                  }
                  
                  // EXÉCUTER LE TRADE AUTOMATIQUEMENT - Vérifier les conditions
                  if(tradeDirection != 0 && InpEnableTrading && GetTotalActivePositions() < InpMaxSymbolsToTrade)
                  {
                     // Normaliser les prix
                     int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
                     entryPrice = NormalizeDouble(entryPrice, digits);
                     sl = NormalizeDouble(sl, digits);
                     tp = NormalizeDouble(tp, digits);
                     
                     PrintFormat("✅ EXÉCUTION AUTOMATIQUE - %s %s @ %.5f (SL: %.5f, TP: %.5f)",
                                 symbol, (tradeDirection > 0 ? "BUY" : "SELL"), entryPrice, sl, tp);
                     
                     // Calculer le lot
                     double lotSize = InpLotFixed;
                     if(lotSize <= 0)
                     {
                        double balance = AccountInfoDouble(ACCOUNT_BALANCE);
                        double riskAmount = balance * InpRiskPerTrade / 100.0;
                        double slDistance = MathAbs(entryPrice - sl);
                        double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
                        double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
                        if(slDistance > 0 && tickValue > 0 && tickSize > 0)
                        {
                           lotSize = (riskAmount / slDistance) * (tickSize / tickValue);
                           lotSize = NormalizeDouble(lotSize, 2);
                           double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
                           double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
                           if(lotSize < minLot) lotSize = minLot;
                           if(lotSize > maxLot) lotSize = maxLot;
                        }
                        else
                        {
                           lotSize = 0.01;
                        }
                     }
                     
                     // Exécuter le trade
                     bool tradeResult = false;
                     if(tradeDirection > 0)
                     {
                        tradeResult = trade.Buy(lotSize, symbol, 0, sl, tp, "Auto EMA10 BUY");
                     }
                     else
                     {
                        tradeResult = trade.Sell(lotSize, symbol, 0, sl, tp, "Auto EMA10 SELL");
                     }
                     
                     if(tradeResult)
                     {
                        PrintFormat("✅ Trade EMA 10 exécuté avec succès - %s %s, Ticket: %llu", 
                                    symbol, (tradeDirection > 0 ? "BUY" : "SELL"), trade.ResultOrder());
                        
                        // Libérer le handle et continuer avec le symbole suivant
                        IndicatorRelease(ema10_handle);
                        continue; // Passer au symbole suivant
                     }
                     else
                     {
                        PrintFormat("❌ Échec exécution trade EMA 10: %d - %s", 
                                   GetLastError(), trade.ResultComment());
                     }
                  }
               }
            }
         }
         
         IndicatorRelease(ema10_handle);
      }
   }
}

//+------------------------------------------------------------------+
in editing , integre stp