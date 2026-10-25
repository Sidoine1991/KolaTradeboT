//+------------------------------------------------------------------+
//| Fx_robot_pred_v3.1 - Spike catcher prédictif                     |
//| - BUY uniquement sur "Boom" symbols                              |
//| - SELL uniquement sur "Crash" symbols                            |
//| - Signaux autorisés sur: Boom/Crash, Volatilités et paires Forex|
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
#include <Arrays\ArrayString.mqh>
#include <Trade\PositionInfo.mqh>

CTrade trade;
CPositionInfo positionInfo;

// Nom de l'algorithme et concepteur
string g_algorithmName = "kola_moneytradbot";
string g_algorithmCreator = "YEBADOKPO Sidoine";

// Fonction pour générer l'en-tête de l'algorithme
string GetAlgorithmHeader()
{
   return "═══════════════════════════════════════════════════════\n" +
          "🤖 " + g_algorithmName + "\n" +
          "👨‍💻 Concepteur: " + g_algorithmCreator + "\n" +
          "═══════════════════════════════════════════════════════";
}

// Séparateur entre les blocs de signaux
string GetSignalSeparator()
{
   return "───────────────────────────────────────────────────────";
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
//| Vérifie si un symbole est une paire forex                       |
//+------------------------------------------------------------------+
bool IsForexPair(string symbol)
{
   // Liste des codes de devises courants
   string currencies[] = {"USD", "EUR", "GBP", "JPY", "CHF", "AUD", "CAD", "NZD", 
                          "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "TRY", "ZAR", 
                          "MXN", "BRL", "RUB", "CNY", "HKD", "SGD", "THB", "INR", "KRW"};
   
   // Vérifier si le symbole fait 6 caractères (format standard: EURUSD)
   if(StringLen(symbol) == 6)
   {
      string base = StringSubstr(symbol, 0, 3);
      string quote = StringSubstr(symbol, 3, 3);
      
      bool baseFound = false, quoteFound = false;
      for(int i = 0; i < ArraySize(currencies); i++)
      {
         if(base == currencies[i]) baseFound = true;
         if(quote == currencies[i]) quoteFound = true;
      }
      
      if(baseFound && quoteFound && base != quote)
         return true;
   }
   
   // Vérifier aussi les formats avec séparateur (EUR/USD, EUR-USD, etc.)
   if(StringFind(symbol, "/") >= 0 || StringFind(symbol, "-") >= 0)
   {
      // Extraire les deux parties
      string parts[];
      int count = StringSplit(symbol, StringFind(symbol, "/") >= 0 ? "/" : "-", parts);
      if(count == 2)
      {
         bool part1Found = false, part2Found = false;
         for(int i = 0; i < ArraySize(currencies); i++)
         {
            if(StringFind(parts[0], currencies[i]) >= 0) part1Found = true;
            if(StringFind(parts[1], currencies[i]) >= 0) part2Found = true;
         }
         if(part1Found && part2Found)
            return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Détecte automatiquement tous les symboles de trading disponibles |
//| (Boom/Crash, Volatilités et paires Forex)                        |
//+------------------------------------------------------------------+
void AutoDetectBoomCrashSymbols()
{
   ArrayResize(g_symbolsToWatch, 0);
   
   // Parcourir tous les symboles disponibles dans Market Watch
   int totalSymbols = SymbolsTotal(true); // true = seulement Market Watch
   
   Print("🔍 Recherche automatique des symboles de trading (Boom/Crash, Volatilités, Forex)...");
   
   int boomCrashCount = 0;
   int volatilityCount = 0;
   int forexCount = 0;
   
   for(int i = 0; i < totalSymbols; i++)
   {
      string symbolName = SymbolName(i, true); // true = Market Watch
      bool shouldAdd = false;
      string symbolType = "";
      
      // Vérifier si c'est un symbole Boom ou Crash
      if(StringFind(symbolName, "Boom", 0) >= 0 || StringFind(symbolName, "Crash", 0) >= 0)
      {
         shouldAdd = true;
         symbolType = "Boom/Crash";
         boomCrashCount++;
      }
      // Vérifier si c'est un symbole de volatilité
      else if(StringFind(symbolName, "Volatility", 0) >= 0 || 
              (StringFind(symbolName, "Index", 0) >= 0 && StringFind(symbolName, "Step", 0) >= 0))
      {
         shouldAdd = true;
         symbolType = "Volatilité";
         volatilityCount++;
      }
      // Vérifier si c'est une paire forex
      else if(IsForexPair(symbolName))
      {
         shouldAdd = true;
         symbolType = "Forex";
         forexCount++;
      }
      
      if(shouldAdd)
      {
         // Ajouter le symbole à la liste
         int size = ArraySize(g_symbolsToWatch);
         ArrayResize(g_symbolsToWatch, size + 1);
         g_symbolsToWatch[size] = symbolName;
         
         PrintFormat("✅ Symbole détecté [%s]: %s", symbolType, symbolName);
         
         // S'assurer que le symbole est sélectionné pour le trading
         SymbolSelect(symbolName, true);
      }
   }
   
   int detectedCount = ArraySize(g_symbolsToWatch);
   PrintFormat("🎯 %d symboles détectés automatiquement:", detectedCount);
   PrintFormat("   - %d symboles Boom/Crash", boomCrashCount);
   PrintFormat("   - %d symboles de volatilité", volatilityCount);
   PrintFormat("   - %d paires Forex", forexCount);
   
   // Si aucun symbole trouvé, ajouter les symboles par défaut
   if(detectedCount == 0)
   {
      Print("⚠️ Aucun symbole détecté - Utilisation des symboles par défaut");
      string defaultSymbols[] = {"Boom 1000 Index", "Crash 1000 Index", "Boom 500 Index", 
                                 "Crash 500 Index", "Boom 300 Index", "Crash 300 Index",
                                 "EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD"};
      
      for(int i = 0; i < ArraySize(defaultSymbols); i++)
      {
         string symbol = defaultSymbols[i];
         if(SymbolSelect(symbol, true))
         {
            int size = ArraySize(g_symbolsToWatch);
            ArrayResize(g_symbolsToWatch, size + 1);
            g_symbolsToWatch[size] = symbol;
            PrintFormat("✅ Symbole par défaut ajouté: %s", symbol);
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
input int      InpMaxConcurrentTrades   = 1;       // Nombre maximum de trades simultanés

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
   PrintFormat("📌 Suivi position prédictive: %s ticket=%llu dir=%s entry=%.5f target=%.5f",
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
               PrintFormat("⏳ Fermeture par timeout: %s ticket=%llu après %d petites bougies sans spike",
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
//| Vérifie si un symbole est un symbole Boom                        |
//+------------------------------------------------------------------+
bool IsSymbolBoom(string symbol)
{
   if(StringFind(symbol, "Boom", 0) >= 0) return true;
   if(StringFind(symbol, "BOOM", 0) >= 0) return true;
   if(StringFind(symbol, "boom", 0) >= 0) return true;
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si un symbole est un symbole Crash                       |
//+------------------------------------------------------------------+
bool IsSymbolCrash(string symbol)
{
   if(StringFind(symbol, "Crash", 0) >= 0) return true;
   if(StringFind(symbol, "CRASH", 0) >= 0) return true;
   if(StringFind(symbol, "crash", 0) >= 0) return true;
   return false;
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
         PrintFormat("⚠️ %s: En attente d'un spike avant de trader (pertes: %d)", 
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
   
   PrintFormat("💔 %s: Perte enregistrée (%.2f $) - Pertes consécutives: %d", 
               symbol, lossAmount, g_lossTrackers[index].consecutiveLosses);
   
   // Si on atteint 2 pertes, activer l'attente de spike
   if(g_lossTrackers[index].consecutiveLosses >= g_lossTrackers[index].maxConsecutiveLosses)
   {
      g_lossTrackers[index].waitingForSpike = true;
      g_lossTrackers[index].spikeWaitStartTime = TimeCurrent();
      PrintFormat("🚫 %s: ATTENTE SPIKE ACTIVÉE - Plus de trades jusqu'au prochain spike", symbol);
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
      PrintFormat("✅ %s: Gain enregistré (%.2f $) - Réinitialisation des pertes consécutives (%d -> 0)", 
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
      
      PrintFormat("🚀 %s: SPIKE DÉTECTÉ - Trading réactivé!", symbol);
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
   double globalScore = CalculateGlobalPerformanceScore();
   string scoreText = StringFormat("Score Performance: %.1f/100", globalScore);
   color scoreColor = clrGray;
   if(globalScore >= 70) scoreColor = clrLime;
   else if(globalScore >= 50) scoreColor = clrYellow;
   else if(globalScore >= 30) scoreColor = clrOrange;
   else scoreColor = clrRed;
   CreateLabel(prefix+"Score", scoreText, x, y, scoreColor, 10, "Arial Bold");
   y += lineHeight;
   
   // Séparateur
   CreateLabel(prefix+"Sep", "─────────────────────────", x, y, clrGray, 8);
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
         trendText = StringFormat("%s: ▲ HAUSSIER (%.0f%%)", tfNames[i], strength);
         trendColor = clrLime;
      }
      else if(trend < 0)
      {
         trendText = StringFormat("%s: ▼ BAISSIER (%.0f%%)", tfNames[i], strength);
         trendColor = clrRed;
      }
      else
      {
         trendText = StringFormat("%s: ● NEUTRE (%.0f%%)", tfNames[i], strength);
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

        PrintFormat("🎯 SPIKE CONFIRMÉ DÉTECTÉ - Z-Score: %.2f, Move: %.5f (avg: %.5f), Body: %.1f%%, Volume: %s, Direction: %s",
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
            PrintFormat("🔥 SUCCESSION DE SPIKE CONFIRMÉE: %d spikes, Direction: %s (%.0f%%), Force: %.1f%%",
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
            PrintFormat("✅ SPIKE HAUSSIER RÉALISÉ - Prédit: %.5f, Atteint: %.5f",
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
            PrintFormat("✅ SPIKE BAISSIER RÉALISÉ - Prédit: %.5f, Atteint: %.5f",
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
                  RecordSignalResult(ticket, totalPnL, true, 0.0);
                  
                  // Forcer la mise à jour du panneau de performance
                  UpdatePerformancePanel();
                  
                  string symbolType = IsSymbolVolatility(symbol) ? "VOLATILITÉ" : "CLASSIQUE";
                  PrintFormat("✅ Position en gain fermée (%s): %s %s, Ticket: %llu, Profit: %.2f $ (seuil: %.2f $)",
                              symbolType, symbol, (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                              ticket, totalPnL, profitThreshold);
               }
               else
               {
                  PrintFormat("❌ Échec fermeture position: %llu, Erreur: %d", ticket, GetLastError());
               }
            }
         }
      }
   }
   
   if(closedCount > 0)
   {
      PrintFormat("💰 %d position(s) en gain fermée(s) après détection du spike - Profit total: %.2f %s",
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
      PrintFormat("🛑 %d position(s) fermée(s) sur %s après spike confirmé", closed, symbol);
}

//+------------------------------------------------------------------+
//| Vérifie si un trade est déjà ouvert sur un symbole donné         |
//+------------------------------------------------------------------+
bool IsTradeOpenForSymbol(string symbol, ulong &ticket = 0)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() == symbol && positionInfo.Magic() == InpMagicNumber)
         {
            ticket = positionInfo.Ticket();
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si le nombre de petites bougies depuis l'ouverture du trade |
//| a atteint le seuil de 10 bougies                                  |
//+------------------------------------------------------------------+
bool HasReachedCandleSL(string symbol, ENUM_TIMEFRAMES tf, double openPrice, double currentPrice, double atr)
{
   int countSmallCandles = 0;
   int maxSmallCandles = 10; // Nombre maximum de petites bougies autorisées
   
   // Taille maximale d'une petite bougie (en ATR)
   double smallCandleSize = atr * 0.5; // Ajustez ce multiplicateur selon votre définition de "petite" bougie
   
   // Vérifier les bougies depuis l'ouverture du trade
   MqlRates rates[];
   int copied = CopyRates(symbol, tf, 0, maxSmallCandles * 2, rates); // Prendre le double pour être sûr
   
   if(copied <= 0) return false;
   
   // Parcourir les bougies depuis la plus récente
   for(int i = 0; i < copied - 1; i++)
   {
      double candleSize = MathAbs(rates[i].high - rates[i].low);
      
      // Si la bougie est plus petite que le seuil, l'incrémenter
      if(candleSize < smallCandleSize)
      {
         countSmallCandles++;
         
         // Si on a atteint le nombre maximum de petites bougies
         if(countSmallCandles >= maxSmallCandles)
            return true;
      }
      else
      {
         // Réinitialiser le compteur si on trouve une grande bougie
         countSmallCandles = 0;
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
   
   if(positionInfo.PositionType() == POSITION_TYPE_BUY)
   {
      priceMove = currentPrice - openPrice;
      
      // Si le prix a suffisamment monté, on ferme avec profit
      if(priceMove >= spikeThreshold)
      {
         trade.PositionClose(ticket);
         PrintFormat("Position #%d fermée avec succès après un spike haussier de %.2f points", ticket, priceMove);
         return true;
      }
   }
   else if(positionInfo.PositionType() == POSITION_TYPE_SELL)
   {
      priceMove = openPrice - currentPrice;
      
      // Si le prix a suffisamment baissé, on ferme avec profit
      if(priceMove >= spikeThreshold)
      {
         trade.PositionClose(ticket);
         PrintFormat("Position #%d fermée avec succès après un spike baissier de %.2f points", ticket, priceMove);
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si un nouveau signal peut être traité pour un symbole    |
//+------------------------------------------------------------------+
bool CanProcessNewSignal(string symbol, ENUM_ORDER_TYPE orderType, double &lastSignalTime)
{
   // Vérifier le nombre total de positions ouvertes
   int totalPositions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i) && positionInfo.Magic() == InpMagicNumber)
      {
         totalPositions++;
         // Si on a déjà 2 positions, on ne peut pas en ouvrir de nouvelle
         if(totalPositions >= 2)
         {
            PrintFormat("⚠️ Limite de 2 positions atteinte - Impossible d'ouvrir un nouveau trade");
            return false;
         }
      }
   }

   // Vérifier si un trade est déjà ouvert sur ce symbole
   ulong existingTicket = 0;
   if(IsTradeOpenForSymbol(symbol, existingTicket))
   {
      // Si un trade est déjà ouvert, vérifier s'il a atteint le SL des 10 bougies
      if(positionInfo.SelectByTicket(existingTicket))
      {
         double openPrice = positionInfo.PriceOpen();
         double currentPrice = positionInfo.PriceCurrent();
         double atr = iATR(symbol, InpSpikeTimeframe, InpATR_Period, 0);
         
         // Vérifier si le SL des 10 bougies est atteint
         if(!HasReachedCandleSL(symbol, InpSpikeTimeframe, openPrice, currentPrice, atr))
         {
            // Si le SL n'est pas atteint, ne pas prendre de nouveau trade
            PrintFormat("⚠️ Trade déjà ouvert sur %s - Attente du SL des 10 bougies", symbol);
            return false;
         }
         else
         {
            // Si le SL est atteint, fermer le trade existant
            trade.PositionClose(existingTicket);
            PrintFormat("🔴 Trade existant sur %s fermé - SL des 10 bougies atteint", symbol);
         }
      }
   }
   
   // Vérifier le temps écoulé depuis le dernier signal
   datetime currentTime = TimeCurrent();
   if(currentTime - lastSignalTime < 60) // 1 minute entre les signaux
   {
      PrintFormat("⏱️ Attente de 1 minute entre les signaux pour %s", symbol);
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
         PrintFormat("✅ ACHAT exécuté sur %s - Lot: %.2f, Prix: %.5f, SL: %.5f, TP: %.5f",
                    symbol, lotSize, price, sl, tp);
      }
      else
      {
         PrintFormat("❌ Échec ACHAT sur %s - Erreur: %d", symbol, GetLastError());
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(trade.Sell(lotSize, symbol, 0, sl, tp, "Signal de vente - Spike détecté"))
      {
         PrintFormat("✅ VENTE exécutée sur %s - Lot: %.2f, Prix: %.5f, SL: %.5f, TP: %.5f",
                    symbol, lotSize, price, sl, tp);
      }
      else
      {
         PrintFormat("❌ Échec VENTE sur %s - Erreur: %d", symbol, GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
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
         double atr = iATR(symbol, InpSpikeTimeframe, InpATR_Period, 0);
         
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
      return(INIT_FAILED);
   }
   
   // Timer pour vérifier nouvelle bougie (1s)
   if(!EventSetTimer(1))
   {
      Print("ERREUR: Impossible de créer le timer");
      return(INIT_FAILED);
   }
   
   // Nettoyer visuels précédents liés à ce EA sur ce graphique
   if(InpShowVisuals) DeleteAllEAObjects();
   
   Print("Initialisation terminée avec succès - Robot prêt");
   return(INIT_SUCCEEDED);
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
   
   PrintFormat("📊 Résultat enregistré: Ticket=%llu, Profit=%.2f, Spike=%s", 
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
      Print("⚠️ Pas assez de données historiques pour l'analyse (Signaux: %d, Résultats: %d)", 
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
   PrintFormat("📊 ANALYSE HISTORIQUE: %d patterns analysés", g_patternScoresCount);
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
   
   PrintFormat("✅ Poids adaptatifs mis à jour: ZScore=%.1f%%, Volume=%.1f%%, Scissor=%.1f%%",
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
      
      CreateLabel(prefix+"NoData", "📊 Performance: Pas encore de données", x, y, clrGray, 9);
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
   CreateLabel(prefix+"Title", "📊 Performance par Symbole", x, y, clrYellow, 10, "Arial Bold");
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
        PrintFormat("⚠️ Rebond EMA détecté mais confiance insuffisante: %.1f%% < %.1f%% (cible)",
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

    PrintFormat("🎯 SPIKE DÉTECTÉ PAR REBOND EMA%d - Direction: %s, Confiance: %.1f%%, Entry: %.5f, SL: %.5f, TP: %.5f",
                bestBounce.emaLevel,
                (direction > 0 ? "BUY" : "SELL"),
                confidence,
                entryPrice, sl, tp);

    PrintFormat("   📊 Multi-TF: TrendStrength=%.1f%%, Aligned=%s, Touches=%d, Volume=%s, PriceAction=%s",
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
    
    PrintFormat("🔍 Analyse de %d symboles détectés...", totalSymbols);
    
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
        PrintFormat("📊 Statistiques: %d symboles analysés (%d Boom/Crash)", totalSymbols, boomCrashCount);
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
      PrintFormat("🔍 PRÉDICTION: Direction=%s, Confiance=%.1f%%, Entry=%.5f, SL=%.5f, TP=%.5f",
                  (prediction.direction > 0 ? "BUY" : "SELL"),
                  prediction.confidence,
                  prediction.entryPrice,
                  prediction.stopLoss,
                  prediction.takeProfit);
   }

   // Exécution automatique quand flèche PRÉDICTIVE est affichée: placer un ordre au marché
   // et notifier l'utilisateur.
   // Autoriser les signaux sur Boom/Crash, Volatilités et paires Forex
   bool isTradableSymbol = (IsSymbolBoom(_Symbol) || IsSymbolCrash(_Symbol) || 
                            IsSymbolVolatility(_Symbol) || IsForexPair(_Symbol));
   bool alreadyPosition = HasOpenPosition();
   if(isTradableSymbol && InpAutoTradeOnPredictiveArrow && prediction.direction != 0 && prediction.confidence >= 30.0 && !alreadyPosition && CanPlaceNewOrder() && IsTradeAllowedForSymbol(_Symbol))
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
         CancelAllPendingOrders(); // respecter la r