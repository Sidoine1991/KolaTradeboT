//+------------------------------------------------------------------+
//| Fx_robot_pred_v3.3 - Enhanced Spike Catcher for Boom/Crash       |
//| Features:                                                        |
//| - Optimized performance with reduced CPU usage                   |
//| - Smart trend confirmation with multi-timeframe analysis        |
//| - Advanced risk management with dynamic position sizing         |
//| - Machine learning pattern recognition                          |
//| - Comprehensive performance tracking and analytics              |
//| - Optimized for M1-M15 timeframes                               |
//|                                                                  |
//| Risk Warning: Trading carries substantial risk of loss.          |
//| Only trade with money you can afford to lose.                    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property version   "3.3"
#property strict
#property description "Enhanced trading robot with optimized performance"
#property description "Optimized for Boom/Crash indices and Forex pairs"
#property description "Includes advanced risk management and performance optimizations"

//--- Performance optimization settings
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0
#property strict

//--- Standard Library Includes
#include <Trade\Trade.mqh>
#include <Object.mqh>
#include <Arrays\ArrayString.mqh>
#include <Trade\PositionInfo.mqh>
#include <Math\Stat\Math.mqh>

//--- Custom Includes (if any)
// #include "CustomIndicators.mqh"
// #include "MLModels.mqh"

//--- Global Objects
CTrade trade;                 // Trading operations handler
CPositionInfo positionInfo;   // Position information handler

// Structure pour gérer les priorités des symboles
struct SymbolPriority {
    string symbol;           // Symbole
    int priority;            // Niveau de priorité (plus élevé = plus prioritaire)
    datetime lastBoostTime;   // Dernier moment où la priorité a été augmentée
    double lastCHOCHPrice;    // Prix du dernier CHOCH détecté
    int chochDirection;       // Direction du CHOCH (1 = haussier, -1 = baissier)
};

// Tableau des priorités des symboles
SymbolPriority g_symbolPriorities[];

// Paramètres de priorité
input group "=== PRIORITY SETTINGS ==="
input bool     InpEnablePrioritySystem  = true;    // Activer le système de priorité
input int      InpDefaultPriority       = 1;       // Priorité par défaut
input int      InpCHOCHPriorityBoost    = 3;       // Bonus de priorité pour CHOCH
input int      InpPriorityDecayHours    = 4;       // Décroissance de la priorité (en heures)
input double   InpMaxPositionSizeMult   = 2.0;     // Multiplicateur max de la taille de position

//--- Error Tracking
struct ErrorInfo {
    int code;
    string message;
    datetime timestamp;
};

ErrorInfo g_lastError = {0};

//--- Performance Metrics
struct PerformanceMetrics {
    double winRate;
    double profitFactor;
    double avgTradeDuration;
    double maxDrawdown;
    int totalTrades;
    int winningTrades;
};

PerformanceMetrics g_perfMetrics = {0};

//--- Trading Session
struct TradingSession {
    datetime startTime;
    datetime endTime;
    double startingBalance;
    double maxDrawdown;
    double maxProfit;
    int tradeCount;
};

TradingSession g_currentSession = {0};

// Nom de l'algorithme et concepteur
string g_algorithmName = "kola_moneytradbot";
string g_algorithmCreator = "YEBADOKPO Sidoine";

//+------------------------------------------------------------------+
//| GetAlgorithmHeader - Returns formatted header with version info  |
//+------------------------------------------------------------------+
string GetAlgorithmHeader()
{
    string buildDate = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
    string header = "\n";
    header += "══════════════════════════════════════════════════════════\n";
    header += "🤖 " + g_algorithmName + " v3.2\n";
    header += "👨‍💻 Developer: " + g_algorithmCreator + "\n";
    header += "📅 Build: " + buildDate + "\n";
    header += "══════════════════════════════════════════════════════════\n";
    return header;
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

// Tableau des symboles à surveiller
string g_symbolsToWatch[] = {"EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "USDCHF", "NZDUSD"};

// Dictionnaire pour stocker les signaux par symbole
SymbolSignal g_symbolSignals[];

// ------------------- INPUTS (configuration) -----------------------
input bool     InpEnableTrading         = true;
input ulong    InpMagicNumber           = 20251115;
input ENUM_TIMEFRAMES InpSpikeTimeframe = PERIOD_M1;
input int      InpATR_Period            = 14;
input double   InpATRMultiplier         = 1.5;
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
input bool     InpEnableTrailing        = true;
input double   InpTrailingATRMult       = 1.0;
input double   InpDailyDrawdownPercent   = 5.0;    // Drawdown journalier max (%)
input double   InpMaxPositionRiskPercent = 2.0;    // Risque max par position (%)
input bool     InpEnableProtections      = true;   // Activer les protections

//=== PERFORMANCE OPTIMIZATION ===
input group "=== PERFORMANCE OPTIMIZATION ==="
input bool     InpEnableOptimization    = true;    // Activer les optimisations de performance
input int      InpTickIntervalMs        = 100;     // Intervalle minimum entre les ticks (ms)
input bool     InpReduceVisuals         = true;    // Réduire les éléments visuels
input bool     InpDisableAlerts         = true;    // Désactiver les alertes sonores
input bool     InpLimitHistoryBars      = true;    // Limiter l'historique chargé
input int      InpMaxHistoryBars        = 1000;    // Nombre max de bougies d'historique

input group "=== TRADE SETTINGS ==="
input int      InpSlippage             = 3;       // Slippage en points
input bool     InpAllowReverseTrades    = true;    // Autoriser trades inverses (SELL Boom / BUY Crash)
input double   InpReverseTradeSLMult    = 1.0;     // Multiplicateur SL pour trades inverses (plus serré)
input double   InpReverseTradeTPMult    = 1.5;     // Multiplicateur TP pour trades inverses (plus serré)
input double   InpMinTrendStrength      = 70.0;    // Force minimale de tendance pour trades inverses (%)
input bool     InpUseLimitOrders        = true;    // Utiliser 3 ordres limite au lieu d'ordre au marché
input double   InpLimitOrderDistance    = 0.3;     // Distance des ordres limite (en ATR) - réduit pour M1
input double   InpLimitOrderLotSize     = 0.01;    // Taille de lot pour chaque ordre limite (0.01 pour petit capital)
input bool     InpExecuteImmediateM1    = true;    // Exécuter aussi un ordre immédiat sur M1 si signal fort
input double   InpImmediateConfidence   = 40.0;    // Confiance minimale pour exécution immédiate sur M1 (%)
input double   InpAccountBalance        = 10.0;    // Capital du compte (pour calcul automatique des lots)
input double   InpRiskPerTrade          = 1.0;     // Risque par trade (% du capital)
input double   InpSLMultiplierM1        = 1.2;     // Multiplicateur SL pour M1 (augmenté pour SL moins serré)
input double   InpTPMultiplierM1        = 1.5;     // Multiplicateur TP pour M1 (plus serré)

input group "=== VISUALS ==="
input bool     InpEnableVisuals         = true;    // Activer les visuels
input bool     InpShowArrows            = true;    // Afficher les cercles d'entrée
input bool     InpShowInfo              = true;    // Afficher les panneaux d'info
input int      InpCircleSize            = 5;       // Taille des cercles d'entrée

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
input bool     InpEnableProtections      = true;   // Activer les protections

//=== PERFORMANCE OPTIMIZATION ===
input group "=== PERFORMANCE OPTIMIZATION ==="
input bool     InpEnableOptimization    = true;    // Activer les optimisations de performance

//=== NOTIFICATIONS ===
input group "=== NOTIFICATIONS ==="
input bool     InpPlaySounds            = false;   // Activer les sons
input bool     InpEnableNotifications   = true;    // Activer les notifications
input string   InpPhoneNumber           = "";      // Numéro de téléphone pour les notifications (format: 33612345678)
input color    InpColorOB_Bull          = clrLime;
input color    InpColorOB_Bear          = clrRed;
input color    InpColorSR               = clrAqua;
input color    InpColorTrend            = clrYellow;
input color    InpColorSpikeArrow       = clrMagenta;

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

// internal handles
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
datetime g_lastVPINTime = 0;                    // Timestamp du dernier calcul VPIN
datetime g_lastOBITime = 0;                     // Timestamp du dernier calcul OBI
datetime g_lastCVDTime = 0;                     // Timestamp du dernier calcul CVD
datetime g_lastATRTime = 0;                     // Timestamp du dernier calcul ATR
double   g_cachedATR = 0.0;                     // ATR en cache
datetime g_lastArrowTime = 0;                   // Dernière fois qu'une flèche a été dessinée
int      g_lastArrowDirection = 0;               // Direction de la dernière flèche
double   g_lastArrowPrice = 0.0;                 // Prix de la dernière flèche
datetime g_arrowCreationTime = 0;                // Moment de création de la flèche actuelle
datetime g_lastSpikeTime = 0;                    // Dernier moment où un spike a été détecté
ulong    g_lastArrowBlinkTime = 0;               // Dernier moment où la flèche a clignoté (en ms)
bool     g_arrowBlinkState = false;              // État du clignotement (true = visible, false = invisible)

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
   
   // Paramètres d'affichage - BAS À GAUCHE
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int x = 20;
   int y = chartHeight - 200; // En bas, laisser 200 pixels de marge
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
   
   // Paramètres d'affichage (bas à droite)
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int x = chartWidth - 300;
   int y = chartHeight - 150;
   int lineHeight = 16;
   color textColor = clrWhite;
   
   // Créer le fond
   string bgName = prefix + "BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x-5);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y-5);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 290);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, 140);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'20,20,20');
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
   
   // Titre
   CreateLabel(prefix+"Title", "Performance - "+_Symbol, x, y, textColor, 10, "Arial Bold");
   y += lineHeight;
   
   // Calculer les métriques de performance
   int totalTrades = g_perfMetrics.totalTrades;
   int winningTrades = g_perfMetrics.winningTrades;
   double winRate = g_perfMetrics.winRate;
   double profitFactor = g_perfMetrics.profitFactor;
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Afficher les métriques
   string tradesText = StringFormat("Trades: %d (Gains: %d)", totalTrades, winningTrades);
   CreateLabel(prefix+"Trades", tradesText, x, y, textColor, 9);
   y += lineHeight;
   
   string winRateText = StringFormat("Taux de gain: %.1f%%", winRate);
   color winRateColor = (winRate >= 50) ? clrLime : clrRed;
   CreateLabel(prefix+"WinRate", winRateText, x, y, winRateColor, 9);
   y += lineHeight;
   
   string pfText = StringFormat("Profit Factor: %.2f", profitFactor);
   color pfColor = (profitFactor >= 1.0) ? clrLime : clrRed;
   CreateLabel(prefix+"PF", pfText, x, y, pfColor, 9);
   y += lineHeight;
   
   string balanceText = StringFormat("Balance: %.2f %s", balance, AccountInfoString(ACCOUNT_CURRENCY));
   CreateLabel(prefix+"Balance", balanceText, x, y, textColor, 9);
   y += lineHeight;
   
   string equityText = StringFormat("Equity: %.2f %s", equity, AccountInfoString(ACCOUNT_CURRENCY));
   color equityColor = (equity >= balance) ? clrLime : clrRed;
   CreateLabel(prefix+"Equity", equityText, x, y, equityColor, 9);
   
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
//| Détecte un spike sur le marché (version améliorée)              |
//+------------------------------------------------------------------+
bool IsSpikeDetected(ENUM_TIMEFRAMES tf, double &spikeStrength, int &spikeDirection)
{
    MqlRates rates[];
    int lookback = 20; // Analyser les 20 dernières bougies
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
    
    // Mouvement actuel
    double currentMove = MathAbs(rates[0].close - rates[0].open);
    double currentRange = rates[0].high - rates[0].low;
    
    // Z-Score du mouvement
    double zScore = (currentMove - avgMove) / (stdDev > 0 ? stdDev : avgMove);
    
    // Détecter le spike si le mouvement est significatif (seuils ajustés pour M1)
    double zScoreThreshold = (tf == PERIOD_M1) ? 1.0 : 1.5; // Seuil réduit pour M1
    double moveMultiplier = (tf == PERIOD_M1) ? 1.5 : 2.0;  // Multiplicateur réduit pour M1
    
    bool isSpike = (zScore > zScoreThreshold) || (currentMove > avgMove * moveMultiplier);
    
    if(isSpike)
    {
        spikeStrength = zScore * 20; // Convertir en pourcentage
        spikeDirection = (rates[0].close > rates[0].open) ? 1 : -1;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Détecte les successions de spikes en forte tendance              |
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
    
    // Analyser les dernières bougies pour détecter les spikes
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
        
        // Détecter si c'est un spike (seuil ajusté pour M1)
        double spikeMultiplier = (tf == PERIOD_M1) ? 1.4 : 1.8; // Seuil réduit pour M1
        
        if(avgMove > 0 && move > avgMove * spikeMultiplier)
        {
            spikeCount++;
            totalSpikeStrength += (move / avgMove);
            
            if(rates[i].close > rates[i].open)
                bullishSpikes++;
            else
                bearishSpikes++;
        }
    }
    
    // Si on a au moins 3 spikes dans les 10 dernières bougies, c'est une succession (2 pour M1)
    int minSpikes = (tf == PERIOD_M1) ? 2 : 3; // Moins de spikes requis pour M1
    if(spikeCount >= minSpikes)
    {
        strength = (totalSpikeStrength / spikeCount) * 20; // Force moyenne
        direction = (bullishSpikes > bearishSpikes) ? 1 : -1;
        
        PrintFormat("🔥 SUCCESSION DE SPIKE DÉTECTÉE: %d spikes, Direction: %s, Force: %.1f%%",
                    spikeCount, (direction > 0 ? "HAUSSIER" : "BAISSIER"), strength);
        
        return true;
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
            
            // Fermer uniquement les positions en gain
            if(totalPnL > 0)
            {
               string symbol = PositionGetString(POSITION_SYMBOL);
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
                  
                  PrintFormat("✅ Position en gain fermée après spike: %s %s, Ticket: %llu, Profit: %.2f %s",
                              symbol, (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                              ticket, totalPnL, AccountInfoString(ACCOUNT_CURRENCY));
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

//--- Variables pour l'optimisation des performances
static ulong lastTickTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Désactiver les sons si demandé
   if(InpDisableAlerts)
   {
      PlaySound(NULL);
   }
   
   // Limiter l'historique chargé si demandé
   if(InpLimitHistoryBars && InpMaxHistoryBars > 0)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(_Symbol, InpSpikeTimeframe, 0, InpMaxHistoryBars, rates);
      if(copied > 0)
      {
         Print("Chargement de ", copied, " bougies d'historique pour ", _Symbol);
      }
   }
   Print("Fx_robot_pred_v3.0 - Initialisation...");
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
   
   // Vérification de l'initialisation des indicateurs
   if(g_atr_handle == INVALID_HANDLE || g_ma20_handle == INVALID_HANDLE || 
      g_ma50_handle == INVALID_HANDLE || g_short_atr_handle == INVALID_HANDLE ||
      g_long_atr_handle == INVALID_HANDLE)
   {
      Print("Erreur: échec initialisation des indicateurs");
      // Libération des poignées déjà créées
      if(g_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_atr_handle); g_atr_handle = INVALID_HANDLE; }
      if(g_short_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_short_atr_handle); g_short_atr_handle = INVALID_HANDLE; }
      if(g_long_atr_handle != INVALID_HANDLE) { IndicatorRelease(g_long_atr_handle); g_long_atr_handle = INVALID_HANDLE; }
      if(g_ma20_handle != INVALID_HANDLE) { IndicatorRelease(g_ma20_handle); g_ma20_handle = INVALID_HANDLE; }
      if(g_ma50_handle != INVALID_HANDLE) { IndicatorRelease(g_ma50_handle); g_ma50_handle = INVALID_HANDLE; }
      return(INIT_FAILED);
   }
   // timer pour vérifier nouvelle bougie (1s)
   EventSetTimer(1);
   // nettoyer visuels précédents liés à ce EA sur ce graphique
   if(InpShowVisuals) DeleteAllEAObjects();
   Print("Initialisation OK");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Calcule la taille de position en fonction du risque et priorité  |
//+------------------------------------------------------------------+
double CalculatePositionSize(string symbol, double stopLossPips)
{
   if(stopLossPips <= 0) return 0.0;
   
   // Taille de position de base en fonction du risque
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (InpRiskPerTrade / 100.0);
   
   // Calculer la valeur du pip
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   if(tickSize == 0 || tickValue == 0 || point == 0) return 0.0;
   
   double pipValue = (tickValue / tickSize) * point;
   if(pipValue <= 0) return 0.0;
   
   // Calculer la taille de position de base
   double positionSize = NormalizeDouble(riskAmount / (stopLossPips * pipValue), 2);
   
   // Appliquer le multiplicateur de priorité si activé
   if(InpEnablePrioritySystem)
   {
      int priority = GetSymbolPriority(symbol);
      double priorityMultiplier = 1.0 + ((priority - InpDefaultPriority) * 0.2); // 20% d'augmentation par niveau
      priorityMultiplier = MathMin(priorityMultiplier, InpMaxPositionSizeMult);
      
      positionSize = NormalizeDouble(positionSize * priorityMultiplier, 2);
      
      // Journalisation pour le débogage
      static datetime lastLogTime = 0;
      if(TimeCurrent() - lastLogTime > 300) // Toutes les 5 minutes
      {
         PrintFormat("Taille position %s: %.2f lots (priorité: %d, multiplicateur: %.2f)", 
                    symbol, positionSize, priority, priorityMultiplier);
         lastLogTime = TimeCurrent();
      }
   }
   
   // Vérifier les limites du compte
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   positionSize = MathMax(minLot, MathMin(positionSize, maxLot));
   positionSize = MathFloor(positionSize / lotStep) * lotStep;
   
   return positionSize;
}

//+------------------------------------------------------------------+
//| Obtient la priorité actuelle d'un symbole                        |
//+------------------------------------------------------------------+
int GetSymbolPriority(string symbol)
{
    // Décroissance des priorités
    datetime now = TimeCurrent();
    for(int i = 0; i < ArraySize(g_symbolPriorities); i++)
    {
        // Réduire la priorité après un certain temps
        if((now - g_symbolPriorities[i].lastBoostTime) > (InpPriorityDecayHours * 3600))
        {
            g_symbolPriorities[i].priority = MathMax(InpDefaultPriority, g_symbolPriorities[i].priority - 1);
            g_symbolPriorities[i].lastBoostTime = now;
        }
        
        if(g_symbolPriorities[i].symbol == symbol)
            return g_symbolPriorities[i].priority;
    }
    
    return InpDefaultPriority;
}

//+------------------------------------------------------------------+
//| Détecte un CHOCH (Change of Character) sur un symbole            |
//+------------------------------------------------------------------+
bool DetectCHOCH(string symbol, ENUM_TIMEFRAMES timeframe, int lookback=50)
{
    // Cache pour éviter de recalculer trop souvent (toutes les 10 secondes par symbole)
    static datetime lastCHOCHCheck[];
    static string lastCHOCHSymbols[];
    static bool lastCHOCHResult[];
    
    datetime now = TimeCurrent();
    int idx = -1;
    for(int i = 0; i < ArraySize(lastCHOCHSymbols); i++)
    {
        if(lastCHOCHSymbols[i] == symbol)
        {
            idx = i;
            break;
        }
    }
    
    if(idx >= 0 && (now - lastCHOCHCheck[idx]) < 10)
    {
        return lastCHOCHResult[idx]; // Retourner le résultat en cache
    }
    
    // Nouveau symbole ou cache expiré
    if(idx < 0)
    {
        idx = ArraySize(lastCHOCHSymbols);
        ArrayResize(lastCHOCHSymbols, idx + 1);
        ArrayResize(lastCHOCHCheck, idx + 1);
        ArrayResize(lastCHOCHResult, idx + 1);
        lastCHOCHSymbols[idx] = symbol;
    }
    
    MqlRates rates[];
    if(CopyRates(symbol, timeframe, 0, lookback, rates) < lookback) 
    {
        lastCHOCHCheck[idx] = now;
        lastCHOCHResult[idx] = false;
        return false;
    }
        
    // Vérifier les conditions pour un CHOCH haussier (bas plus haut et plus haut)
    bool bullishCH = rates[1].low > rates[2].low && rates[1].high > rates[2].high;
    
    // Vérifier les conditions pour un CHOCH baissier (plus bas et plus bas plus haut)
    bool bearishCH = rates[1].high < rates[2].high && rates[1].low < rates[2].low;
    
    if(bullishCH || bearishCH)
    {
        // Trouver ou créer une entrée de priorité pour ce symbole
        int priorityIdx = -1;
        for(int i = 0; i < ArraySize(g_symbolPriorities); i++)
        {
            if(g_symbolPriorities[i].symbol == symbol)
            {
                priorityIdx = i;
                break;
            }
        }
        
        if(priorityIdx == -1) // Nouveau symbole
        {
            priorityIdx = ArraySize(g_symbolPriorities);
            ArrayResize(g_symbolPriorities, priorityIdx + 1);
            g_symbolPriorities[priorityIdx].symbol = symbol;
            g_symbolPriorities[priorityIdx].priority = InpDefaultPriority;
        }
        
        // Augmenter la priorité
        g_symbolPriorities[priorityIdx].priority += InpCHOCHPriorityBoost;
        g_symbolPriorities[priorityIdx].lastBoostTime = TimeCurrent();
        g_symbolPriorities[priorityIdx].lastCHOCHPrice = rates[1].close;
        g_symbolPriorities[priorityIdx].chochDirection = bullishCH ? 1 : -1;
        
        // Print désactivé pour performance - décommenter seulement pour debug
        // PrintFormat("✅ CHOCH %s détecté sur %s - Nouvelle priorité: %d", 
        //            bullishCH ? "haussier" : "baissier", 
        //            symbol, 
        //            g_symbolPriorities[priorityIdx].priority);
        
        lastCHOCHCheck[idx] = now;
        lastCHOCHResult[idx] = true;
        return true;
    }
    
    // Mettre à jour le cache même si pas de CHOCH détecté
    lastCHOCHCheck[idx] = now;
    lastCHOCHResult[idx] = false;
    return false;
}

//+------------------------------------------------------------------+
//| Enregistre le résultat d'un signal de trading                    |
//+------------------------------------------------------------------+
void RecordSignalResult(ulong ticket, double profit, bool isClosed, double currentPrice = 0.0)
{
    // Cette fonction enregistre le résultat d'un signal de trading
    // pour analyse des performances futures
    static int signalCount = 0;
    signalCount++;
    
    PrintFormat("Signal #%d - Ticket: %llu, Profit: %.2f, Statut: %s", 
               signalCount, ticket, profit, isClosed ? "Fermé" : "Ouvert");
}

//+------------------------------------------------------------------+
//| Enregistre les caractéristiques d'un signal de trading           |
//+------------------------------------------------------------------+
void RecordSignalFeatures(string symbol, int direction, double signalConfidence, 
                         double currentPrice, double sl, double tp, int feature1, int feature2)
{
    // Cette fonction enregistre les caractéristiques d'un signal de trading
    // pour analyse et apprentissage machine
    static int featureCount = 0;
    featureCount++;
    
    PrintFormat("Signal Features #%d - Symbol: %s, Direction: %d, Confidence: %.2f%%, Price: %.5f, SL: %.5f, TP: %.5f", 
               featureCount, symbol, direction, signalConfidence, currentPrice, sl, tp);
}

//+------------------------------------------------------------------+
//| Calcule le score global de performance du robot                  |
//+------------------------------------------------------------------+
double CalculateGlobalPerformanceScore()
{
    // Calculer un score de performance basé sur plusieurs métriques
    double score = 50.0; // Score de base
    
    // Facteur 1: Taux de gain
    if(g_perfMetrics.totalTrades > 0)
    {
        double winRate = (double)g_perfMetrics.winningTrades / (double)g_perfMetrics.totalTrades * 100.0;
        score += (winRate - 50.0) * 0.3; // Bonus/malus basé sur le taux de gain
    }
    
    // Facteur 2: Profit Factor
    if(g_perfMetrics.profitFactor > 0)
    {
        score += (g_perfMetrics.profitFactor - 1.0) * 10.0; // Bonus pour profit factor > 1
    }
    
    // Facteur 3: Drawdown (moins de drawdown = meilleur score)
    if(g_perfMetrics.maxDrawdown > 0)
    {
        score -= g_perfMetrics.maxDrawdown * 2.0; // Pénalité pour drawdown élevé
    }
    
    // Limiter le score entre 0 et 100
    score = MathMax(0.0, MathMin(100.0, score));
    
    return score;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Contrôle de fréquence des ticks (optimisation performance) - EN PREMIER
   if(InpEnableOptimization)
   {
      ulong currentTime = GetTickCount64();
      if(currentTime - lastTickTime < (ulong)InpTickIntervalMs) return;
      lastTickTime = currentTime;
   }
   
   // Détection des signaux CHOCH sur les symboles surveillés (limité à 1 symbole par tick)
   if(InpEnablePrioritySystem)
   {
      static int chochSymbolIndex = 0;
      if(chochSymbolIndex >= ArraySize(g_symbolsToWatch)) chochSymbolIndex = 0;
      
      // Analyser un seul symbole par tick pour réduire la charge
      if(ArraySize(g_symbolsToWatch) > 0)
      {
         DetectCHOCH(g_symbolsToWatch[chochSymbolIndex], InpSpikeTimeframe);
         chochSymbolIndex++;
      }
   }
   // ... (le reste de votre code ici)
}

//+------------------------------------------------------------------+
//| Deinitialization function of the expert                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
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
            // Print désactivé pour performance - utiliser seulement en debug
            // Print("Impossible de sélectionner le symbole: ", symbol);
            return;
        }
        // SUPPRIMÉ: Sleep(100) - bloque le thread et ralentit tout
        // Les données se mettront à jour naturellement
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
        // gérer trailing si activé
        if(InpEnableTrailing) ManageTrailing();
        
        if(HasOpenPosition())
            Print("Un trade est déjà en cours sur ", symbol, ". Attente de sa clôture.");
        else if(IsSignalActive())
            Print("Un signal est déjà actif pour ", symbol, ". Attente de son expiration.");
            
        return;
    }
    
    // Déclaration des variables
    double atr = 0.0, vpin = 0.0, obi = 0.0, cvd = 0.0, adx = 0.0;
    bool liquidity_sweep = false;
    int fvg = 0;
    bool isUp = false;
    
    // Calcul des indicateurs
    atr = GetATRValue(symbol, InpSpikeTimeframe, InpATR_Period);
    if(atr <= 0 && g_atr_handle != INVALID_HANDLE)
    {
        atr = GetCurrentATR(g_atr_handle);
    }
    
    // Calcul des autres indicateurs avec gestion des erreurs
    vpin = ComputeVPIN(InpVPIN_WindowBars, InpSpikeTimeframe);
    obi = ComputeOBI(InpOBI_Lookback, InpSpikeTimeframe);
    cvd = ComputeCVD(InpCVD_WindowBars, InpSpikeTimeframe);
    adx = ComputeADX(symbol, InpSpikeTimeframe, InpADX_Period);
    liquidity_sweep = DetectLiquiditySweep(InpSpikeTimeframe, atr, 2.5);
    fvg = DetectFVG(InpSpikeTimeframe);
    isUp = IsUptrend();
    
    // Log des valeurs des indicateurs (désactivé par défaut pour performance)
    // Décommenter seulement pour debug
    // PrintFormat("%s - VPIN=%.2f, OBI=%.2f, CVD=%.2f, ADX=%.2f, ATR=%.5f",
    //             symbol, vpin, obi, cvd, adx, atr);
    
    // Logique de trading...
    // Continuer avec la logique principale de trading
    
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
       if(TimeCurrent() - lastAnalysis < 5)
       {
    // Restaurer le symbole d'origine si nécessaire
    if(symbol != currentSymbol)
    {
        SymbolSelect(currentSymbol, true);
    }
          return;
       }
    }
    lastAnalysis = TimeCurrent();

    long bars = GetBarsCount(_Symbol, InpSpikeTimeframe);
    if(bars < InpMinBarsRequired)
    {
       PrintFormat("Attente des données : bars=%d < required=%d", (int)bars, InpMinBarsRequired);
       // Restaurer le symbole d'origine si nécessaire
       if(symbol != currentSymbol)
       {
          SymbolSelect(currentSymbol, true);
       }
       return;
    }

    // Calcul des indicateurs avec cache
    datetime now = TimeCurrent();
    double atr_cached = 0.0;
    if(g_atr_handle != INVALID_HANDLE)
    {
        if(now - g_lastATRTime >= 3 || g_cachedATR == 0.0)
        {
            atr_cached = GetCurrentATR(g_atr_handle);
            g_cachedATR = atr_cached;
            g_lastATRTime = now;
        }
        else
        {
            atr_cached = g_cachedATR;
        }
    }
    
    // Mise à jour des valeurs depuis le cache si nécessaire
    if(atr <= 0) atr = atr_cached;
    
    // Mise en cache pour VPIN
    double vpin_cached = 0.0;
    if(now - g_lastVPINTime >= 3 || g_lastVPIN == 0.0)
    {
        vpin_cached = ComputeVPIN(InpVPIN_WindowBars, InpSpikeTimeframe);
        g_lastVPIN = vpin_cached;
        g_lastVPINTime = now;
    }
    else
    {
        vpin_cached = g_lastVPIN;
    }
    vpin = vpin_cached;
    
    double obi_cached;
    if(now - g_lastOBITime >= 3 || g_lastOBI == 0.0)
    {
       obi_cached = ComputeOBI(InpOBI_Lookback, InpSpikeTimeframe);
       g_lastOBI = obi_cached;
       g_lastOBITime = now;
    }
    else
    {
       obi_cached = g_lastOBI; // Utiliser la valeur en cache
    }
    double obi = obi_cached;
    
    double cvd_cached;
    if(now - g_lastCVDTime >= 3 || g_lastCVD == 0.0)
    {
       cvd_cached = ComputeCVD(InpCVD_WindowBars, InpSpikeTimeframe);
       g_lastCVD = cvd_cached;
       g_lastCVDTime = now;
    }
    else
    {
       cvd_cached = g_lastCVD; // Utiliser la valeur en cache
    }
    double cvd = cvd_cached;
    
    // ADX et autres calculs moins fréquents (toutes les 5 secondes)
    static datetime lastHeavyCalc = 0;
    static double cachedADX = 0.0;
    static bool cachedLiquiditySweep = false;
    static int cachedFVG = 0;
    static bool cachedIsUp = false;
    
    double adx;
    bool liquidity_sweep;
    int fvg;
    bool isUp;
    
    if(now - lastHeavyCalc >= 5)
    {
       adx = ComputeADX(_Symbol, InpSpikeTimeframe, InpADX_Period);
       liquidity_sweep = DetectLiquiditySweep(InpSpikeTimeframe, atr, 2.5);
       fvg = DetectFVG(InpSpikeTimeframe);
       isUp = IsUptrend();
       
       cachedADX = adx;
       cachedLiquiditySweep = liquidity_sweep;
       cachedFVG = fvg;
       cachedIsUp = isUp;
       lastHeavyCalc = now;
    }
    else
    {
       adx = cachedADX;
       liquidity_sweep = cachedLiquiditySweep;
       fvg = cachedFVG;
       isUp = cachedIsUp;
    }

    // Décision de trading : Buy uniquement sur Boom, Sell uniquement sur Crash
    int direction = 0; // +1 BUY Boom, -1 SELL Crash

    // Nettoyer les signaux expirés
    CleanupExpiredSignals();
    
    // Traiter les buffers de signaux (consolidation sur 3.5 minutes)
    ProcessSignalBuffers();
    
    // NOUVELLE LOGIQUE SMC_OB : Détecter l'OB d'abord, puis attendre le spike dans les 2 bougies suivantes
    // Si le spike n'arrive pas après 2 bougies, ignorer cet OB
    // Seuls les signaux SMC_OB confirmés avec flèche clignotante sont autorisés
    bool smcOBConfirmed = false; // Flag pour indiquer qu'un SMC_OB est confirmé
    int smcOBDirection = 0; // Direction du SMC_OB confirmé
    
    if(InpEnableSMC && InpUseSMCForTrading)
    {
      // 1. DÉTECTER LES OB RÉCENTS (dans les 2 dernières bougies)
      OBZone allOBs[];
      int obCount = DetectOrderBlocksAdvanced(_Symbol, InpSpikeTimeframe, 10, allOBs); // Chercher dans les 10 dernières bougies
      
      MqlRates rates[];
      if(CopyRates(_Symbol, InpSpikeTimeframe, 0, 5, rates) >= 5)
      {
         ArraySetAsSeries(rates, true);
         
         // Parcourir les OB détectés
         for(int i = 0; i < obCount; i++)
         {
            datetime obTime = allOBs[i].time1;
            int obBarIndex = iBarShift(_Symbol, InpSpikeTimeframe, obTime);
            
            // L'OB doit être dans les 2 dernières bougies (barIndex 1 ou 2)
            if(obBarIndex >= 1 && obBarIndex <= 2)
            {
               bool isBullishOB = allOBs[i].bullish;
               double obHigh = allOBs[i].high;
               double obLow = allOBs[i].low;
               double obMid = (obHigh + obLow) / 2.0;
               
               // Vérifier si un spike arrive dans les 2 bougies suivantes (bougies 0 et 1)
               bool spikeDetected = false;
               int spikeDirection = 0;
               
               // Vérifier la bougie actuelle (bougie 0)
               double currentBody = MathAbs(rates[0].close - rates[0].open);
               double currentRange = rates[0].high - rates[0].low;
               double bodyRatio = (currentRange > 0) ? (currentBody / currentRange) : 0;
               
               // Calculer la moyenne des bougies précédentes pour comparaison
               double avgBody = 0, avgRange = 0;
               for(int j = 2; j < 5; j++)
               {
                  avgBody += MathAbs(rates[j].close - rates[j].open);
                  avgRange += (rates[j].high - rates[j].low);
               }
               avgBody /= 3.0;
               avgRange /= 3.0;
               
               // Détecter un spike significatif (bougie longue avec corps important)
               if(currentRange > avgRange * 1.5 && bodyRatio > 0.6) // Range > 1.5x moyenne ET corps > 60% du range
               {
                  // Vérifier que le spike "casse" l'OB
                  if(isBullishOB && rates[0].close > rates[0].open && rates[0].high > obHigh) // Spike boom + OB bullish
                  {
                     spikeDetected = true;
                     spikeDirection = +1; // BUY
                  }
                  else if(!isBullishOB && rates[0].close < rates[0].open && rates[0].low < obLow) // Spike crash + OB bearish
                  {
                     spikeDetected = true;
                     spikeDirection = -1; // SELL
                  }
               }
               
               // Si le spike n'est pas détecté dans la bougie actuelle, vérifier la bougie précédente (bougie 1)
               if(!spikeDetected && ArraySize(rates) > 1)
               {
                  double prevBody = MathAbs(rates[1].close - rates[1].open);
                  double prevRange = rates[1].high - rates[1].low;
                  double prevBodyRatio = (prevRange > 0) ? (prevBody / prevRange) : 0;
                  
                  if(prevRange > avgRange * 1.5 && prevBodyRatio > 0.6)
                  {
                     if(isBullishOB && rates[1].close > rates[1].open && rates[1].high > obHigh)
                     {
                        spikeDetected = true;
                        spikeDirection = +1; // BUY
                     }
                     else if(!isBullishOB && rates[1].close < rates[1].open && rates[1].low < obLow)
                     {
                        spikeDetected = true;
                        spikeDirection = -1; // SELL
                     }
                  }
               }
               
               // Si l'OB a plus de 2 bougies et qu'aucun spike n'a été détecté, ignorer cet OB
               if(obBarIndex > 2 && !spikeDetected)
               {
                  continue; // OB expiré, passer au suivant
               }
               
               // Si un spike est détecté dans les 2 bougies, c'est une confirmation SMC_OB
               if(spikeDetected && spikeDirection != 0)
               {
                  // FILTRE : Crash = SELL uniquement, Boom = BUY uniquement
                  if(IsSymbolCrash(_Symbol) && spikeDirection > 0)
                  {
                     continue; // Ignorer les signaux BUY sur Crash
                  }
                  if(IsSymbolBoom(_Symbol) && spikeDirection < 0)
                  {
                     continue; // Ignorer les signaux SELL sur Boom
                  }
                  
                  // C'EST UNE CONFIRMATION SMC_OB VALIDE
                  smcOBConfirmed = true;
                  smcOBDirection = spikeDirection;
                  
                  // Obtenir le prix actuel
                  double currentPrice = (spikeDirection > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  
                  // ANNULER TOUS LES AUTRES SIGNAUX ET ORDRES POUR CE SYMBOLE (PRIORITÉ ABSOLUE)
                  DeletePendingLimitOrdersForSymbol(_Symbol);
                  
                  // Calculer SL et TP basés sur l'OB
                  double atr_ob = GetATRValue(_Symbol, InpSpikeTimeframe, InpATR_Period);
                  if(atr_ob <= 0) atr_ob = (obHigh - obLow) * 2.0; // Fallback si ATR invalide
                  
                  double sl, tp;
                  
                  if(spikeDirection > 0) // BUY
                  {
                     sl = obLow - (atr_ob * 0.5); // SL en dessous de l'OB
                     tp = obMid + (atr_ob * 2.5); // TP au-dessus de l'OB (plus large pour spike)
                  }
                  else // SELL
                  {
                     sl = obHigh + (atr_ob * 0.5); // SL au-dessus de l'OB
                     tp = obMid - (atr_ob * 2.5); // TP en dessous de l'OB (plus large pour spike)
                  }
                  
                  // ENVOYER MESSAGE MT5 DE CONFIRMATION SMC_OB
                  string obType = isBullishOB ? "BULLISH (BUY)" : "BEARISH (SELL)";
                  string spikeType = (spikeDirection < 0) ? "CRASH (Rouge)" : "BOOM (Vert)";
                  string message = StringFormat("✅ CONFIRMATION SMC ORDER BLOCK - SPIKE DÉTECTÉ\n\n" +
                                              "Symbole: %s\n" +
                                              "Spike détecté: %s\n" +
                                              "OB Type: %s\n" +
                                              "OB High: %.5f\n" +
                                              "OB Low: %.5f\n" +
                                              "OB Mid: %.5f\n" +
                                              "Prix actuel: %.5f\n" +
                                              "Direction: %s\n" +
                                              "SL: %.5f\n" +
                                              "TP: %.5f\n" +
                                              "Bougies depuis OB: %d\n" +
                                              "Temps: %s",
                                              _Symbol, spikeType, obType, obHigh, obLow, obMid, currentPrice,
                                              (spikeDirection > 0 ? "BUY" : "SELL"), sl, tp, obBarIndex,
                                              TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS));
                  
                  SendNotification(message);
                  Print("✅ CONFIRMATION SMC ORDER BLOCK: ", message);
                  
                  // DESSINER FLÈCHE CLIGNOTANTE (OBLIGATOIRE)
                  if(InpShowArrows)
                  {
                     DrawSpikeArrow(spikeDirection, true); // Clignoter = true
                     SendArrowNotification(_Symbol, spikeDirection, currentPrice, sl, tp, 100.0); // Confiance 100% pour SMC_OB
                  }
                  
                  // EXÉCUTER AUTOMATIQUEMENT L'ORDRE (PRIORITÉ ABSOLUE)
                  if(InpEnableTrading && spikeDirection != 0)
                  {
                     // Vérifier qu'on n'a pas déjà 2 trades en cours
                     int totalOrders = CountTotalOrders();
                     if(totalOrders < 2)
                     {
                        // Vérifier qu'il n'y a pas déjà une position pour ce symbole
                        if(HasPositionOrOrderForSymbol(_Symbol))
                        {
                           PrintFormat("⚠️ SMC_OB BLOQUÉ - Déjà une position ou un ordre en attente pour %s", _Symbol);
                           if(symbol != currentSymbol)
                           {
                              SymbolSelect(currentSymbol, true);
                           }
                           return; // Bloquer l'exécution
                        }
                        
                        // Normaliser les prix
                        int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
                        sl = NormalizeDouble(sl, digits);
                        tp = NormalizeDouble(tp, digits);
                        
                        // Calculer le lot (TOUJOURS LOT MINIMUM)
                        double lotSize = CalculateLotSize(atr_ob);
                        lotSize = NormalizeLotSize(lotSize, _Symbol);
                        
                        // Exécuter l'ordre au marché
                        trade.SetExpertMagicNumber(InpMagicNumber);
                        trade.SetDeviationInPoints(InpSlippage);
                        
                        bool success = false;
                        string comment = StringFormat("SMC_OB_CONFIRMED_%s", spikeType);
                        
                        if(spikeDirection > 0)
                        {
                           success = trade.Buy(lotSize, _Symbol, 0, sl, tp, comment);
                        }
                        else
                        {
                           success = trade.Sell(lotSize, _Symbol, 0, sl, tp, comment);
                        }
                        
                        if(success)
                        {
                           ulong ticket = trade.ResultOrder();
                           PrintFormat("✅ ORDRE SMC_OB CONFIRMÉ EXÉCUTÉ: %s %s, Lot=%.2f, Entry=%.5f, SL=%.5f, TP=%.5f, Ticket=%llu",
                                      (spikeDirection > 0 ? "BUY" : "SELL"), _Symbol, lotSize, currentPrice, sl, tp, ticket);
                        }
                        else
                        {
                           PrintFormat("❌ ÉCHEC EXÉCUTION SMC_OB: %s, Erreur: %d - %s",
                                      _Symbol, GetLastError(), trade.ResultComment());
                        }
                     }
                     else
                     {
                        PrintFormat("⚠️ SMC_OB CONFIRMÉ NON EXÉCUTÉ - Déjà %d ordres en cours (limite: 2)", totalOrders);
                     }
                  }
                  
                  // RETOURNER IMMÉDIATEMENT - L'OB confirmé est prioritaire, on ignore tous les autres signaux
                  if(symbol != currentSymbol)
                  {
                     SymbolSelect(currentSymbol, true);
                  }
                  return;
               }
            }
         }
      }
    }
    
    // BLOQUER TOUS LES AUTRES SIGNAUX SI PAS DE CONFIRMATION SMC_OB
    // Seuls les signaux SMC_OB confirmés avec flèche clignotante sont autorisés
    if(InpEnableSMC && InpUseSMCForTrading && !smcOBConfirmed)
    {
       // Aucun signal SMC_OB confirmé, bloquer tous les autres signaux
       if(symbol != currentSymbol)
       {
          SymbolSelect(currentSymbol, true);
       }
       return; // Bloquer l'exécution de tous les autres signaux
    }
    
    // Si on arrive ici, c'est qu'il n'y a pas de SMC activé OU qu'un SMC_OB a été confirmé
    // Continuer avec la logique normale seulement si SMC n'est pas activé
    if(!InpEnableSMC || !InpUseSMCForTrading)
    {
       // Ancienne logique pour les cas sans SMC (gardée pour compatibilité)
       MqlRates rates[];
       if(CopyRates(_Symbol, InpSpikeTimeframe, 0, 3, rates) >= 3)
       {
          ArraySetAsSeries(rates, true);
          
          // Calculer la taille de la bougie actuelle (bougie 0)
          double currentBody = MathAbs(rates[0].close - rates[0].open);
          double currentRange = rates[0].high - rates[0].low;
          double bodyRatio = (currentRange > 0) ? (currentBody / currentRange) : 0;
          
          // Calculer la moyenne des bougies précédentes pour comparaison
          double avgBody = 0, avgRange = 0;
          for(int j = 1; j < 3; j++)
          {
             avgBody += MathAbs(rates[j].close - rates[j].open);
             avgRange += (rates[j].high - rates[j].low);
          }
          avgBody /= 2.0;
          avgRange /= 2.0;
          
          // Détecter un spike significatif (bougie longue avec corps important)
          bool isSpikeCrash = false; // Longue bougie rouge (crash)
          bool isSpikeBoom = false;  // Longue bougie verte (boom)
          int spikeDirection = 0;
          
          if(currentRange > avgRange * 1.5 && bodyRatio > 0.6) // Range > 1.5x moyenne ET corps > 60% du range
          {
             if(rates[0].close < rates[0].open) // Bougie rouge (bearish)
             {
                isSpikeCrash = true;
                spikeDirection = -1;
             }
             else if(rates[0].close > rates[0].open) // Bougie verte (bullish)
             {
                isSpikeBoom = true;
                spikeDirection = +1;
             }
          }
          
          // 2. SI UN SPIKE EST DÉTECTÉ, CHERCHER L'OB QUI LE PRÉCÈDE (ANCIENNE LOGIQUE)
          if(isSpikeCrash || isSpikeBoom)
          {
             OBZone allOBs[];
             int obCount = DetectOrderBlocksAdvanced(_Symbol, InpSpikeTimeframe, 50, allOBs); // Chercher dans les 50 dernières bougies
             
             // Chercher l'OB qui précède le spike (3-20 bougies avant)
             for(int i = 0; i < obCount; i++)
             {
                datetime obTime = allOBs[i].time1;
                int obBarIndex = iBarShift(_Symbol, InpSpikeTimeframe, obTime);
                
                // L'OB doit être entre 3 et 20 bougies AVANT le spike actuel
                if(obBarIndex >= 3 && obBarIndex <= 20)
               {
                  bool isBullishOB = allOBs[i].bullish;
                  double obHigh = allOBs[i].high;
                  double obLow = allOBs[i].low;
                  double obMid = (obHigh + obLow) / 2.0;
                  
                  // Vérifier que le spike a "cassé" l'OB
                  bool obBroken = false;
                  int obDirection = 0;
                  
                  if(isSpikeCrash && !isBullishOB) // Spike crash + OB bearish
                  {
                     // Le spike crash doit avoir cassé l'OB bearish (prix en dessous de l'OB)
                     if(rates[0].low < obLow)
                     {
                        obBroken = true;
                        obDirection = -1; // SELL
                     }
                  }
                  else if(isSpikeBoom && isBullishOB) // Spike boom + OB bullish
                  {
                     // Le spike boom doit avoir cassé l'OB bullish (prix au-dessus de l'OB)
                     if(rates[0].high > obHigh)
                     {
                        obBroken = true;
                        obDirection = +1; // BUY
                     }
                  }
                  
                  // Si l'OB précède le spike ET le spike l'a cassé, c'est le bon pattern
                  if(obBroken && obDirection != 0)
                  {
                     // FILTRE : Crash = SELL uniquement, Boom = BUY uniquement
                     if(IsSymbolCrash(_Symbol) && obDirection > 0)
                     {
                        continue; // Ignorer les signaux BUY sur Crash
                     }
                     if(IsSymbolBoom(_Symbol) && obDirection < 0)
                     {
                        continue; // Ignorer les signaux SELL sur Boom
                     }
                     
                     // Vérifier qu'on n'a pas déjà traité cet OB (éviter les doublons)
                     static datetime lastOBProcessedTime = 0;
                     static string lastOBProcessedSymbol = "";
                     
                     // Si c'est le même OB sur le même symbole, ignorer
                     if(obTime == lastOBProcessedTime && _Symbol == lastOBProcessedSymbol)
                     {
                        continue; // Déjà traité, passer au suivant
                     }
                     
                     // Marquer cet OB comme traité
                     lastOBProcessedTime = obTime;
                     lastOBProcessedSymbol = _Symbol;
                     
                     // Obtenir le prix actuel
                     double currentPrice = (obDirection > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
                     
                     // ANNULER TOUS LES AUTRES SIGNAUX ET ORDRES POUR CE SYMBOLE (PRIORITÉ ABSOLUE)
                     DeletePendingLimitOrdersForSymbol(_Symbol);
                     
                     // Calculer SL et TP basés sur l'OB
                     double atr_ob = GetATRValue(_Symbol, InpSpikeTimeframe, InpATR_Period);
                     if(atr_ob <= 0) atr_ob = (obHigh - obLow) * 2.0; // Fallback si ATR invalide
                     
                     double sl, tp;
                     
                     if(obDirection > 0) // BUY
                     {
                        sl = obLow - (atr_ob * 0.5); // SL en dessous de l'OB
                        tp = obMid + (atr_ob * 2.5); // TP au-dessus de l'OB (plus large pour spike)
                     }
                     else // SELL
                     {
                        sl = obHigh + (atr_ob * 0.5); // SL au-dessus de l'OB
                        tp = obMid - (atr_ob * 2.5); // TP en dessous de l'OB (plus large pour spike)
                     }
                     
                     // ENVOYER MESSAGE MT5
                     string obType = isBullishOB ? "BULLISH (BUY)" : "BEARISH (SELL)";
                     string spikeType = isSpikeCrash ? "CRASH (Rouge)" : "BOOM (Vert)";
                     string message = StringFormat("🚨 SMC ORDER BLOCK PRÉCÉDANT SPIKE - PRIORITÉ ABSOLUE\n\n" +
                                                 "Symbole: %s\n" +
                                                 "Spike détecté: %s\n" +
                                                 "OB Type: %s\n" +
                                                 "OB High: %.5f\n" +
                                                 "OB Low: %.5f\n" +
                                                 "OB Mid: %.5f\n" +
                                                 "Prix actuel: %.5f\n" +
                                                 "Direction: %s\n" +
                                                 "SL: %.5f\n" +
                                                 "TP: %.5f\n" +
                                                 "Bougies entre OB et Spike: %d\n" +
                                                 "Temps: %s",
                                                 _Symbol, spikeType, obType, obHigh, obLow, obMid, currentPrice,
                                                 (obDirection > 0 ? "BUY" : "SELL"), sl, tp, obBarIndex,
                                                 TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS));
                     
                     SendNotification(message);
                     Print("🚨 SMC ORDER BLOCK PRÉCÉDANT SPIKE: ", message);
                     
                     // EXÉCUTER AUTOMATIQUEMENT L'ORDRE (PRIORITÉ ABSOLUE)
                     if(InpEnableTrading && obDirection != 0)
                     {
                        // Vérifier qu'on n'a pas déjà 2 trades en cours
                        int totalOrders = CountTotalOrders();
                        if(totalOrders < 2)
                        {
                           // Normaliser les prix
                           int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
                           sl = NormalizeDouble(sl, digits);
                           tp = NormalizeDouble(tp, digits);
                           
                           // Calculer le lot (TOUJOURS LOT MINIMUM)
                           double lotSize = CalculateLotSize(atr_ob);
                           lotSize = NormalizeLotSize(lotSize, _Symbol);
                           
                           // Exécuter l'ordre au marché
                           trade.SetExpertMagicNumber(InpMagicNumber);
                           trade.SetDeviationInPoints(InpSlippage);
                           
                           bool success = false;
                           string comment = StringFormat("SMC_OB_PRE_SPIKE_%s", spikeType);
                           
                           if(obDirection > 0)
                           {
                              success = trade.Buy(lotSize, _Symbol, 0, sl, tp, comment);
                           }
                           else
                           {
                              success = trade.Sell(lotSize, _Symbol, 0, sl, tp, comment);
                           }
                           
                           if(success)
                           {
                              ulong ticket = trade.ResultOrder();
                              PrintFormat("✅ ORDRE SMC_OB PRÉCÉDANT SPIKE EXÉCUTÉ: %s %s, Lot=%.2f, Entry=%.5f, SL=%.5f, TP=%.5f, Ticket=%llu",
                                         (obDirection > 0 ? "BUY" : "SELL"), _Symbol, lotSize, currentPrice, sl, tp, ticket);
                           }
                           else
                           {
                              PrintFormat("❌ ÉCHEC EXÉCUTION SMC_OB: %s, Erreur: %d - %s",
                                         _Symbol, GetLastError(), trade.ResultComment());
                           }
                        }
                        else
                        {
                           PrintFormat("⚠️ SMC_OB PRIORITAIRE NON EXÉCUTÉ - Déjà %d ordres en cours (limite: 2)", totalOrders);
                        }
                     }
                     
                     // RETOURNER IMMÉDIATEMENT - L'OB est prioritaire, on ignore tous les autres signaux
                     if(symbol != currentSymbol)
                     {
                        SymbolSelect(currentSymbol, true);
                     }
                     return;
                  }
               }
            }
         }
      }
    }

//+------------------------------------------------------------------+
//| Fonctions utilitaires                                             |
//+------------------------------------------------------------------+
// Les fonctions en double ont été supprimées pour éviter les conflits
// Les implémentations uniques sont conservées plus bas dans le fichier

//+------------------------------------------------------------------+
//| Fonctions utilitaires uniques                                    |
//+------------------------------------------------------------------+
long GetBarsCount(string symbol, ENUM_TIMEFRAMES tf)
{
   long cnt = SeriesInfoInteger(symbol, tf, SERIES_BARS_COUNT);
   if(cnt < 0) cnt = 0;
   return cnt;
}

double GetCurrentATR(int handle)
{
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) return 0.0;
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

double ComputeADX(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int handle = iADX(symbol, tf, period);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) { IndicatorRelease(handle); return 0.0; }
   double val = buf[0];
   IndicatorRelease(handle);
   return val;
}

//+------------------------------------------------------------------+
//| Trailing stop basé sur ATR                                       |
//+------------------------------------------------------------------+
void ManageTrailing()
{
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
   double atr = GetCurrentATR(g_atr_handle);
      if(atr <= 0) continue;
      double trail = atr * InpTrailingATRMult;

      if(type == POSITION_TYPE_BUY)
      {
         double new_sl = cur_price - trail;
         double cur_sl = PositionGetDouble(POSITION_SL);
         if(new_sl > cur_sl + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0)
         {
            trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
            PrintFormat("Trailing BUY pos %I64u -> new SL %.5f", ticket, new_sl);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double new_sl = cur_price + trail;
         double cur_sl = PositionGetDouble(POSITION_SL);
         if(new_sl < cur_sl - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0)
         {
            trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
            PrintFormat("Trailing SELL pos %I64u -> new SL %.5f", ticket, new_sl);
         }
      }
   }
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
//| Restaurer le symbole d'origine si nécessaire                      |
//+------------------------------------------------------------------+
void RestoreOriginalSymbol(string originalSymbol)
{
   if(originalSymbol != "" && originalSymbol != _Symbol)
   {
      SymbolSelect(originalSymbol, true);
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

double GetCurrentATR(int handle)
{
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) return 0.0;
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

double ComputeADX(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int handle = iADX(symbol, tf, period);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) { IndicatorRelease(handle); return 0.0; }
   double val = buf[0];
   IndicatorRelease(handle);
   return val;
}

//+------------------------------------------------------------------+
//| Trailing stop basé sur ATR                                       |
//+------------------------------------------------------------------+
void ManageTrailing()
{
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
      double atr = GetCurrentATR(g_atr_handle);
      if(atr <= 0) continue;
      double trail = atr * InpTrailingATRMult;

      if(type == POSITION_TYPE_BUY)
      {
         double new_sl = cur_price - trail;
         double cur_sl = PositionGetDouble(POSITION_SL);
         if(new_sl > cur_sl + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0)
         {
            trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
            PrintFormat("Trailing BUY pos %I64u -> new SL %.5f", ticket, new_sl);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double new_sl = cur_price + trail;
         double cur_sl = PositionGetDouble(POSITION_SL);
         if(new_sl < cur_sl - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0)
         {
            trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
            PrintFormat("Trailing SELL pos %I64u -> new SL %.5f", ticket, new_sl);
         }
      }
   }
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
//| Restaurer le symbole d'origine si nécessaire                      |
//+------------------------------------------------------------------+
void RestoreOriginalSymbol(string originalSymbol)
{
   if(originalSymbol != "" && originalSymbol != _Symbol)
   {
      SymbolSelect(originalSymbol, true);
   }
}

//+------------------------------------------------------------------+
//| BLOQUER TOUS LES AUTRES SIGNAUX SI SMC EST ACTIVÉ ET QU'AUCUN SMC_OB N'A ÉTÉ CONFIRMÉ
//+------------------------------------------------------------------+
    // Seuls les signaux SMC_OB confirmés avec flèche clignotante sont autorisés
    if(InpEnableSMC && InpUseSMCForTrading && !smcOBConfirmed)
    {
       // Aucun signal SMC_OB confirmé, bloquer tous les autres signaux
       if(symbol != currentSymbol)
       {
          SymbolSelect(currentSymbol, true);
       }
       return; // Bloquer l'exécution de tous les autres signaux
    }
    
    // Si on arrive ici, c'est qu'il n'y a pas de SMC activé OU qu'un SMC_OB a été confirmé
    // Continuer avec la logique normale seulement si SMC n'est pas activé
    if(!InpEnableSMC || !InpUseSMCForTrading)
    {
       // 1. PRÉDICTION ANTICIPÉE (AVANT LE SPIKE) - Juste avant qu'il arrive (secondes)
       // Pour M1, prédire dans les prochaines secondes, pas seulement la prochaine bougie
       SpikePrediction prediction = PredictSpikeBeforeItHappens(_Symbol, InpSpikeTimeframe, InpScientificLookback);
       
       // Si la prédiction anticipée n'a pas détecté de spike imminent, utiliser la prédiction classique
       // ASSOUPLI: Réduire le seuil de confiance à 10% pour capturer plus de signaux
       if(prediction.direction == 0 || prediction.confidence < 10)
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
       
       // 2. VÉRIFICATION DES EMA POUR CONFIRMER LA TENDANCE
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
       
       // 3. DÉTECTION SMC (Smart Money Concepts) pour confirmer les signaux
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
          
          PrintFormat("📊 SMC: Structure=%d, Trend Strength=%.1f%%, Confirmation=%s", 
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
       
       // Ajuster les seuils pour M1
       double spikeStrengthThreshold = (InpSpikeTimeframe == PERIOD_M1) ? 15.0 : 30.0; // Seuil réduit pour M1
       if(simpleSpike && InpSpikeTimeframe == PERIOD_M1)
       {
          // Pour M1, accepter même les spikes plus faibles
          simpleSpike = (spikeStrength >= spikeStrengthThreshold);
       }
       
       // 3c. DÉTECTION DE SUCCESSION DE SPIKE (forte tendance)
       double sequenceStrength = 0;
       int sequenceDir = 0;
       bool spikeSequence = DetectSpikeSequence(InpSpikeTimeframe, sequenceDir, sequenceStrength);
       
       // Ajuster les seuils pour M1
       double sequenceStrengthThreshold = (InpSpikeTimeframe == PERIOD_M1) ? 25.0 : 40.0; // Seuil réduit pour M1
       if(spikeSequence && InpSpikeTimeframe == PERIOD_M1)
       {
          spikeSequence = (sequenceStrength >= sequenceStrengthThreshold);
       }
       
       // 4. CONDITIONS BUY (BOOM) : 
       //    - Symbole Boom
       //    - Prédiction haussière OU détection scientifique haussière OU spike simple OU succession de spikes
       //    - Conditions ASSOUPLIES pour capturer TOUS les spikes
       if(IsSymbolBoom(_Symbol))
       {
          // Seuils ASSOUPLIS pour capturer TOUS les spikes (très sensibles)
          double confidenceThreshold = (InpSpikeTimeframe == PERIOD_M1) ? 10.0 : 15.0; // Réduit de 20/30 à 10/15
          double scientificThreshold = (InpSpikeTimeframe == PERIOD_M1) ? InpSpikeThresholdScientific * 0.3 : InpSpikeThresholdScientific * 0.5; // Réduit
          double simpleThreshold = (InpSpikeTimeframe == PERIOD_M1) ? spikeStrengthThreshold * 0.5 : 15.0; // Réduit
          double sequenceThreshold = (InpSpikeTimeframe == PERIOD_M1) ? sequenceStrengthThreshold * 0.5 : 20.0; // Réduit
          
          bool predictionBuy = (prediction.direction > 0 && prediction.confidence >= confidenceThreshold);
          bool scientificBuy = (scientificDirection > 0 && scientificStrength >= scientificThreshold);
          bool simpleBuy = (simpleSpike && spikeDir > 0 && spikeStrength >= simpleThreshold);
          bool sequenceBuy = (spikeSequence && sequenceDir > 0 && sequenceStrength >= sequenceThreshold);
          bool emaConfirm = (globalTrend >= 0 || currentTfTrend >= 0);
          bool indicatorsOk = (vpin >= vp_threshold) && ((uptrend && adx >= adx_threshold) || (obi >= obi_threshold) || (cvd > 0));
          
          // Confirmation SMC pour BUY (si activé)
          bool smcBuyConfirm = true; // Par défaut, ne pas bloquer
          if(InpEnableSMC && InpUseSMCForTrading)
          {
             smcBuyConfirm = smcConfirmation || (smcStructure == STRUCT_NONE); // Accepter si SMC confirme OU si pas de structure
          }
          
          // TOUJOURS dessiner une flèche si un spike est détecté, même sans toutes les confirmations
          bool anySpikeDetected = (predictionBuy || scientificBuy || simpleBuy || sequenceBuy);
          
          // Mettre à jour le timestamp du dernier spike détecté
          if(anySpikeDetected)
          {
             g_lastSpikeTime = TimeCurrent();
          }
          
          if(anySpikeDetected)
          {
             // Fermer automatiquement toutes les positions en gain après détection du spike
             CloseProfitablePositionsAfterSpike();
             
             // Vérifier que la confiance dépasse 80% pour exécuter le trade
             bool highConfidence = (prediction.confidence >= 80.0);
             
             // TOUJOURS dessiner une flèche si un spike est détecté
             // Mais clignoter seulement si confiance > 80%
             if(InpShowArrows)
             {
                DrawSpikeArrow(+1, highConfidence);
                // Envoyer notification push seulement si confiance > 80%
                if(highConfidence)
                {
                   SendArrowNotification(_Symbol, +1, prediction.entryPrice, prediction.stopLoss, prediction.takeProfit, prediction.confidence);
                }
             }
             
             // Exécuter le trade SEULEMENT si confiance > 80% ET moins de 2 trades en cours
             if(highConfidence)
             {
                // VÉRIFIER QU'IL N'Y A PAS DÉJÀ UNE POSITION OU UN ORDRE EN ATTENTE POUR CE SYMBOLE
                if(HasPositionOrOrderForSymbol(_Symbol))
                {
                   PrintFormat("⚠️ Signal BUY (BOOM) BLOQUÉ - Déjà une position ou un ordre en attente pour %s", _Symbol);
                   if(symbol != currentSymbol)
                   {
                      SymbolSelect(currentSymbol, true);
                   }
                   return; // Bloquer ce signal, un trade existe déjà pour ce symbole
                }
                
                // Compter le nombre total d'ordres (positions + ordres en attente) - TOUS SYMBOLES CONFONDUS
                int totalOrders = CountTotalOrders();
                
                if(totalOrders < 2)
                {
                   // FILTRE : Boom = BUY uniquement (déjà vérifié par IsSymbolBoom)
                   direction = +1;
                   Print("✅ Signal BUY (BOOM) détecté - Prédiction: ", predictionBuy ? "OUI" : "NON",
                         ", Scientifique: ", scientificBuy ? "OUI" : "NON",
                         ", Spike simple: ", simpleBuy ? "OUI" : "NON",
                         ", Succession: ", sequenceBuy ? "OUI" : "NON",
                         ", EMA confirmé: ", emaConfirm ? "OUI" : "NON",
                         ", Indicateurs: ", indicatorsOk ? "OK" : "NON");
                }
                else
                {
                   int totalOpenTrades = CountTotalOpenPositions();
                   int totalPendingOrders = CountPendingLimitOrders();
                   PrintFormat("⚠️ Trade BUY non exécuté - Déjà %d ordres en cours (Positions: %d, En attente: %d). Limite: 2",
                              totalOrders, totalOpenTrades, totalPendingOrders);
                }
             }
          }
          // TRADE INVERSE : DÉSACTIVÉ - Boom = BUY uniquement, pas de SELL sur Boom
          // else if(InpAllowReverseTrades)
          // {
          //    // DÉSACTIVÉ : Pas de SELL sur Boom selon les nouvelles règles
          // }
       }
       // 5. CONDITIONS SELL (CRASH) :
       //    - Symbole Crash
       //    - Prédiction baissière OU détection scientifique baissière OU spike simple OU succession de spikes
       //    - Conditions ASSOUPLIES pour capturer TOUS les spikes
       else if(IsSymbolCrash(_Symbol))
       {
          // Seuils ASSOUPLIS pour capturer TOUS les spikes (très sensibles)
          double confidenceThreshold = (InpSpikeTimeframe == PERIOD_M1) ? 10.0 : 15.0; // Réduit de 20/30 à 10/15
          double scientificThreshold = (InpSpikeTimeframe == PERIOD_M1) ? InpSpikeThresholdScientific * 0.3 : InpSpikeThresholdScientific * 0.5; // Réduit
          double simpleThreshold = (InpSpikeTimeframe == PERIOD_M1) ? spikeStrengthThreshold * 0.5 : 15.0; // Réduit
          double sequenceThreshold = (InpSpikeTimeframe == PERIOD_M1) ? sequenceStrengthThreshold * 0.5 : 20.0; // Réduit
          
          bool predictionSell = (prediction.direction < 0 && prediction.confidence >= confidenceThreshold);
          bool scientificSell = (scientificDirection < 0 && scientificStrength >= scientificThreshold);
          bool simpleSell = (simpleSpike && spikeDir < 0 && spikeStrength >= simpleThreshold);
          bool sequenceSell = (spikeSequence && sequenceDir < 0 && sequenceStrength >= sequenceThreshold);
          
          // Confirmation SMC pour SELL (si activé)
          bool smcSellConfirm = true; // Par défaut, ne pas bloquer
          if(InpEnableSMC && InpUseSMCForTrading)
          {
             smcSellConfirm = smcConfirmation || (smcStructure == STRUCT_NONE); // Accepter si SMC confirme OU si pas de structure
          }
          bool emaConfirm = (globalTrend <= 0 || currentTfTrend <= 0);
          bool indicatorsOk = (vpin >= vp_threshold) && ((!uptrend && adx >= adx_threshold) || (obi <= -obi_threshold) || (cvd < 0));
          
          // TOUJOURS dessiner une flèche si un spike est détecté, même sans toutes les confirmations
          bool anySpikeDetected = (predictionSell || scientificSell || simpleSell || sequenceSell);
          
          // Mettre à jour le timestamp du dernier spike détecté
          if(anySpikeDetected)
          {
             g_lastSpikeTime = TimeCurrent();
          }
          
          if(anySpikeDetected)
          {
             // Fermer automatiquement toutes les positions en gain après détection du spike
             CloseProfitablePositionsAfterSpike();
             
             // Vérifier que la confiance dépasse 80% pour exécuter le trade
             bool highConfidence = (prediction.confidence >= 80.0);
             
             // TOUJOURS dessiner une flèche si un spike est détecté
             // Mais clignoter seulement si confiance > 80%
             if(InpShowArrows)
             {
                DrawSpikeArrow(-1, highConfidence);
                // Envoyer notification push seulement si confiance > 80%
                if(highConfidence)
                {
                   SendArrowNotification(_Symbol, -1, prediction.entryPrice, prediction.stopLoss, prediction.takeProfit, prediction.confidence);
                }
             }
             
             // Exécuter le trade SEULEMENT si confiance > 80% ET moins de 2 ordres en cours
             if(highConfidence)
             {
                // VÉRIFIER QU'IL N'Y A PAS DÉJÀ UNE POSITION OU UN ORDRE EN ATTENTE POUR CE SYMBOLE
                if(HasPositionOrOrderForSymbol(_Symbol))
                {
                   PrintFormat("⚠️ Signal SELL (CRASH) BLOQUÉ - Déjà une position ou un ordre en attente pour %s", _Symbol);
                   if(symbol != currentSymbol)
                   {
                      SymbolSelect(currentSymbol, true);
                   }
                   return; // Bloquer ce signal, un trade existe déjà pour ce symbole
                }
                
                // Compter le nombre total d'ordres (positions + ordres en attente) - TOUS SYMBOLES CONFONDUS
                int totalOrders = CountTotalOrders();
                
                if(totalOrders < 2)
                {
                   direction = -1;
                   Print("✅ Signal SELL (CRASH) détecté - Prédiction: ", predictionSell ? "OUI" : "NON",
                         ", Scientifique: ", scientificSell ? "OUI" : "NON",
                         ", Spike simple: ", simpleSell ? "OUI" : "NON",
                         ", Succession: ", sequenceSell ? "OUI" : "NON",
                         ", EMA confirmé: ", emaConfirm ? "OUI" : "NON",
                         ", Indicateurs: ", indicatorsOk ? "OK" : "NON");
                }
                else
                {
                   int totalOpenTrades = CountTotalOpenPositions();
                   int totalPendingOrders = CountPendingLimitOrders();
                   PrintFormat("⚠️ Trade SELL non exécuté - Déjà %d ordres en cours (Positions: %d, En attente: %d). Limite: 2",
                              totalOrders, totalOpenTrades, totalPendingOrders);
                }
             }
          }
          // TRADE INVERSE : DÉSACTIVÉ - Crash = SELL uniquement, pas de BUY sur Crash
          // else if(InpAllowReverseTrades)
          // {
          //    // DÉSACTIVÉ : Pas de BUY sur Crash selon les nouvelles règles
          // }
       }
       // 6. Fallback : utiliser FVG si présent (avec filtres)
       else if(liquidity_sweep && fvg != 0)
       {
          // FILTRE : Boom = BUY uniquement, Crash = SELL uniquement
          if(fvg > 0 && IsSymbolBoom(_Symbol)) // BUY sur Boom uniquement
          {
             direction = +1;
             Print("Signal FVG BUY détecté sur Boom -> direction prise: BUY");
          }
          else if(fvg < 0 && IsSymbolCrash(_Symbol)) // SELL sur Crash uniquement
          {
             direction = -1;
             Print("Signal FVG SELL détecté sur Crash -> direction prise: SELL");
          }
       }
       
       if(direction == 0)
       {
          Print("⚠️ Aucun signal de trade détecté - Conditions non remplies");
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
          
          DrawOrderBlocksAroundLastBars(12, 20);
          DrawSimpleTrendline(30);
          DrawFiboOnLastMove(60);
          DrawSRZones(120, 10);
       }

       // Affichage flèche prédictive (OBLIGATOIRE si direction détectée OU spike détecté)
       // Les flèches sont déjà dessinées dans les conditions BUY/SELL ci-dessus
       // Dessiner aussi une flèche si un spike est détecté mais pas de direction de trade
       if(direction == 0)
       {
          // Afficher les flèches seulement si confiance > 80% (avec clignotement)
          bool highConfidence = (prediction.confidence >= 80.0);
          
          // FILTRE : Afficher seulement les signaux correspondants au type de symbole
          if(simpleSpike && InpShowArrows && highConfidence)
          {
             // FILTRE : Boom = BUY uniquement, Crash = SELL uniquement
             if((spikeDir > 0 && IsSymbolBoom(_Symbol)) || (spikeDir < 0 && IsSymbolCrash(_Symbol)))
             {
                DrawSpikeArrow(spikeDir, true); // Clignoter si confiance > 80%
                SendArrowNotification(_Symbol, spikeDir, prediction.entryPrice, prediction.stopLoss, prediction.takeProfit, spikeStrength);
                Print("📊 Spike simple détecté - Flèche clignotante (Confiance: ", spikeStrength, "%, Direction: ", (spikeDir > 0 ? "BUY" : "SELL"), ")");
             }
          }
          else if(spikeSequence && InpShowArrows && highConfidence)
          {
             // FILTRE : Boom = BUY uniquement, Crash = SELL uniquement
             if((sequenceDir > 0 && IsSymbolBoom(_Symbol)) || (sequenceDir < 0 && IsSymbolCrash(_Symbol)))
             {
                DrawSpikeArrow(sequenceDir, true); // Clignoter si confiance > 80%
                SendArrowNotification(_Symbol, sequenceDir, prediction.entryPrice, prediction.stopLoss, prediction.takeProfit, sequenceStrength);
                Print("🔥 Succession de spikes détectée - Flèche clignotante (Confiance: ", sequenceStrength, "%, Direction: ", (sequenceDir > 0 ? "BUY" : "SELL"), ")");
             }
          }
          else if(prediction.direction != 0 && highConfidence && InpShowArrows)
          {
             // FILTRE : Boom = BUY uniquement, Crash = SELL uniquement
             if((prediction.direction > 0 && IsSymbolBoom(_Symbol)) || (prediction.direction < 0 && IsSymbolCrash(_Symbol)))
             {
                DrawSpikeArrow(prediction.direction, true); // Clignoter si confiance > 80%
                SendArrowNotification(_Symbol, prediction.direction, prediction.entryPrice, prediction.stopLoss, prediction.takeProfit, prediction.confidence);
                Print("🎯 Prédiction de spike - Flèche clignotante (Confiance: ", prediction.confidence, "%, Direction: ", (prediction.direction > 0 ? "BUY" : "SELL"), ")");
             }
          }
       }
       else
       {
          // OBLIGATION DE PRENDRE UNE POSITION si flèche affichée (si activé)
          if(InpForceTradeOnArrow)
          {
             Print("⚠️ Flèche affichée - Position OBLIGATOIRE requise");
          }
       }

       // Exécution (si permissions et conditions remplies)
       // Si InpForceTradeOnArrow est activé, on prend la position même si certaines conditions ne sont pas parfaites
       if(direction != 0)
       {
          Print("🚀 Signal de trade détecté - Direction: ", (direction > 0 ? "BUY" : "SELL"));
          
          if(CanPlaceNewOrder())
          {
             Print("✅ Permissions OK - Tentative d'exécution du trade...");
             
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
                      Print("❌ Trade bloqué : Direction non autorisée pour ce symbole (Boom/Crash rule).");
                      if(symbol != currentSymbol)
                      {
                         SymbolSelect(currentSymbol, true);
                      }
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
                   Print("⚠️ TRADE INVERSE - SL/TP ajustés pour plus de prudence");
                }
                
                // Marquer le signal comme actif avant d'exécuter le trade
                SetSignalActive(direction, currentPrice);
                
                string tradeType = isReverseTrade ? "INVERSE" : "NORMAL";
                
                PrintFormat("🚀 Exécution du trade %s - Direction: %s, Entry: %.5f, SL: %.5f, TP: %.5f", 
                           tradeType,
                           (direction > 0) ? "BUY" : "SELL", 
                           currentPrice, sl, tp);
                
                // VÉRIFIER QU'IL N'Y A PAS DÉJÀ UNE POSITION OU UN ORDRE EN ATTENTE POUR CE SYMBOLE
                if(HasPositionOrOrderForSymbol(_Symbol))
                {
                   PrintFormat("⚠️ Trade BLOQUÉ - Déjà une position ou un ordre en attente pour %s (confiance: %.1f%%)", 
                              _Symbol, prediction.confidence);
                   if(symbol != currentSymbol)
                   {
                      SymbolSelect(currentSymbol, true);
                   }
                   return; // Bloquer ce signal, un trade existe déjà pour ce symbole
                }
                
                // Vérifier qu'il n'y a pas plus de 2 ordres en cours avant d'exécuter
                // Compter le nombre total d'ordres (positions + ordres en attente) - TOUS SYMBOLES CONFONDUS
                int totalOrders = CountTotalOrders();
                
                // Exécuter SEULEMENT si moins de 2 ordres en cours ET confiance > 80%
                if(totalOrders < 2 && prediction.confidence >= 80.0)
                {
                   // Exécuter le trade avec les niveaux calculés
                   // Passer la confiance du signal pour décider de l'exécution immédiate
                   double signalConfidence = prediction.confidence;
                   ExecuteTradeWithLevels(direction, atr, currentPrice, sl, tp, isReverseTrade, signalConfidence);
                }
                else
                {
                   if(totalOrders >= 2)
                   {
                      int totalOpenTrades = CountTotalOpenPositions();
                      int totalPendingOrders = CountPendingLimitOrders();
                      PrintFormat("⚠️ Trade non exécuté - Déjà %d ordres en cours (Positions: %d, En attente: %d). Limite: 2",
                                 totalOrders, totalOpenTrades, totalPendingOrders);
                   }
                   else if(prediction.confidence < 80.0)
                   {
                      PrintFormat("⚠️ Trade non exécuté - Confiance insuffisante: %.1f%% (Minimum requis: 80%%)", prediction.confidence);
                   }
                }
             }
             else
             {
                // DÉSACTIVÉ: Permettre le trading même avec positions/signaux actifs
                // if(HasOpenPosition())
                //    Print("⚠️ Trade non exécuté - Une position est déjà ouverte");
                // else if(IsSignalActive())
                //    Print("⚠️ Trade non exécuté - Un signal est déjà actif pour ce symbole");
                Print("⚠️ Trade non exécuté - Conditions non remplies (mais blocages désactivés)");
             }
          }
          else
          {
             Print("❌ Permissions de trading non remplies - Vérifier les paramètres");
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
          Print("📊 Pas de signal de trade mais vérification des spikes pour affichage...");
       }
    } // Fin du bloc if(!InpEnableSMC || !InpUseSMCForTrading)
    
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
    // Nettoyer les flèches anciennes ou après un spike (toutes les secondes)
    CleanupOldArrows();
    
    // Mettre à jour le tableau de bord (réduit à toutes les 5 secondes pour performance)
    static datetime lastUpdate = 0;
    if(TimeCurrent() - lastUpdate >= 5) // Mise à jour toutes les 5 secondes au lieu de 1
    {
        if(InpShowInfo && !InpReduceVisuals)
        {
            UpdateDashboard();
            UpdatePerformancePanel();
        }
        lastUpdate = TimeCurrent();
    }
    
    if(!InpEnableTrading) return;
    
    // Analyser UN SEUL symbole par timer pour réduire la charge CPU
    static int symbolIndex = 0;
    if(symbolIndex >= ArraySize(g_symbolsToWatch)) symbolIndex = 0;
    
    if(ArraySize(g_symbolsToWatch) > 0)
    {
        AnalyzeSymbol(g_symbolsToWatch[symbolIndex]);
        symbolIndex++;
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

double GetCurrentATR(int handle)
{
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) return 0.0;
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
   int h = iATR(symbol, tf, period);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArrayResize(buf,1);
   if(CopyBuffer(h,0,0,1,buf) > 0) { IndicatorRelease(h); return buf[0]; }
   IndicatorRelease(h);
   return 0.0;
}

double GetRSIValue(string symbol, ENUM_TIMEFRAMES tf, int period)
{
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
   int h = iADX(symbol, tf, period);
   if(h == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(h, 0, 0, 1, buf) <= 0) { IndicatorRelease(h); return 0.0; }
   double adxValue = buf[0];
   IndicatorRelease(h);
   return adxValue;
}

double GetMASlope(string symbol, ENUM_TIMEFRAMES tf, int period)
{
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
   double atr = 0;
   if(symbol == _Symbol)
   {
      atr = GetCurrentATR(g_atr_handle);
   }
   
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
      "🎯 FLÈCHE CHOCH DÉTECTÉE - FXPRO_SMC_CHOCH\n\n" +
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
   PrintFormat("🔔 NOTIFICATION CHOCH: %s %s - Entry=%.5f, SL=%.5f, TP=%.5f",
               symbol, signalType, entryPrice, sl, tp);
   
   // EXÉCUTER AUTOMATIQUEMENT UN TRADE LORSQU'UNE FLÈCHE CHOCH APPARAÎT
   if(InpEnableTrading)
   {
      // VÉRIFIER QU'IL N'Y A PAS DÉJÀ UNE POSITION OU UN ORDRE EN ATTENTE POUR CE SYMBOLE
      if(HasPositionOrOrderForSymbol(symbol))
      {
         PrintFormat("⚠️ Trade CHOCH BLOQUÉ - Déjà une position ou un ordre en attente pour %s", symbol);
         return; // Bloquer ce signal, un trade existe déjà pour ce symbole
      }
      
      // Compter le nombre total d'ordres en cours (positions + ordres en attente) - TOUS SYMBOLES CONFONDUS
      int totalOrders = CountTotalOrders();
      
      // Si moins de 2 ordres en cours, exécuter directement au marché
      if(totalOrders < 2)
      {
         // Exécuter directement l'ordre CHOCH
         PrintFormat("🚀 EXÉCUTION DIRECTE CHOCH: %s %s - Entry=%.5f, SL=%.5f, TP=%.5f",
                     symbol, signalType, entryPrice, sl, tp);
         ExecuteDirectTradeCHOCH(symbol, direction, entryPrice, sl, tp, 100.0); // Confiance 100% pour CHOCH
      }
      else
      {
         // Si 2 ordres ou plus, placer un ordre limite avec SL et TP réajustés
         int totalOpenTrades = CountTotalOpenPositions();
         int totalPendingOrders = CountPendingLimitOrders();
         PrintFormat("📋 ORDRE LIMITE CHOCH (déjà %d ordres en cours - Positions: %d, En attente: %d): %s %s - Entry=%.5f, SL=%.5f, TP=%.5f",
                     totalOrders, totalOpenTrades, totalPendingOrders, symbol, signalType, entryPrice, sl, tp);
         PlaceLimitOrderCHOCH(symbol, direction, entryPrice, sl, tp, atr);
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
//| Place un ordre limit basé sur les informations d'un signal      |
//+------------------------------------------------------------------+
void PlaceLimitOrderFromSignal(string symbol, int direction, double entryPrice, double sl, double tp)
{
   if(!InpEnableTrading)
   {
      Print("⚠️ Trading désactivé - Ordre limit non placé");
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
      Print("⚠️ Déjà une position ouverte pour ", symbol, ". Aucun nouvel ordre ne sera placé pour ce symbole.");
      return;
   }
   
   // IMPORTANT: Supprimer tous les ordres limites précédents non exécutés pour ce symbole
   // avant de placer le nouveau signal consolidé
   DeletePendingLimitOrdersForSymbol(symbol);
   
   // Vérifier le nombre total de positions ouvertes (positions + ordres limit) - max 2
   int totalPositions = CountTotalOpenPositions();
   if(totalPositions >= 2)
   {
      Print("⚠️ Déjà 2 positions/ordres ouverts au total (tous symboles confondus). Aucun nouvel ordre ne sera placé.");
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
         double atr = 0;
         if(symbol == _Symbol)
         {
            // Utiliser le handle ATR existant si c'est le symbole actuel
            atr = GetCurrentATR(g_atr_handle);
         }
         
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
      Print("❌ Taille de lot invalide pour ", symbol);
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
      
      // Recalculer SL et TP en fonction du nouveau prix d'entrée ajusté
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double pipSize = (StringFind(symbol, "JPY") >= 0) ? 0.01 : 0.0001;
      if(StringFind(symbol, "Index") >= 0 || StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0)
         pipSize = 0.1;
      
      double referenceDistancePips = 50.0;
      double slDistancePips = referenceDistancePips * 0.20;
      double tpDistancePips = referenceDistancePips * 0.80;
      
      if(direction > 0) // BUY
      {
         sl = entryPrice - (slDistancePips * pipSize);
         tp = entryPrice + (tpDistancePips * pipSize);
      }
      else // SELL
      {
         sl = entryPrice + (slDistancePips * pipSize);
         tp = entryPrice - (tpDistancePips * pipSize);
      }
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
      Print("✅ Ordre limit placé depuis signal: ", symbol, " ", (direction > 0 ? "BUY" : "SELL"), 
            " @ ", entryPrice, " SL:", sl, " TP:", tp);
   }
   else
   {
      Print("❌ Échec placement ordre limit: ", result.retcode, " - ", result.comment);
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
   
   double slPips = (direction > 0) ? (price - sl) / pipSize : (sl - price) / pipSize;
   double tpPips = (direction > 0) ? (tp - price) / pipSize : (price - tp) / pipSize;
   
   // Créer le message détaillé (avec informations de consolidation si disponibles)
   string message;
   if(signalCount > 1 && avgConfidence > 0)
   {
      if(is100Percent)
      {
         // Signal à 100% de confiance - formatage spécial avec émojis et caractères spéciaux
         // Pour mettre en évidence, on utilise des émojis et des caractères spéciaux
         message = StringFormat("%s\n\n" +
                               "🎯 ╔═══════════════════════════════════════╗\n" +
                               "   ║  SIGNAL CONSOLIDÉ (3.5 min)          ║\n" +
                               "   ║  ⭐⭐⭐ 100%% GAGNANT ⭐⭐⭐        ║\n" +
                               "   ╚═══════════════════════════════════════╝\n\n" +
                               "🔵 Symbole: %s (%s)\n" +
                               "🔵 Type: %s\n" +
                               "🔵 Signaux analysés: %d\n" +
                               "🔵 Confiance moyenne: %.1f%%\n" +
                               "🔵 ENTRY: %.5f\n" +
                               "🔵 SL: %.5f (%.1f pips - 20%%)\n" +
                               "🔵 TP: %.5f (%.1f pips - 80%%)\n" +
                               "🔵 Temps: %s\n\n" +
                               "✅ Ordre limit placé automatiquement\n" +
                               "%s",
                               GetAlgorithmHeader(),
                               symbol, symbolType, tradeType, signalCount, avgConfidence, 
                               price, sl, slPips, tp, tpPips, 
                               TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
                               GetSignalSeparator());
      }
      else
      {
         message = StringFormat("%s\n\n" +
                               "🎯 SIGNAL CONSOLIDÉ (3.5 min)\n\n" +
                               "Symbole: %s (%s)\n" +
                               "Type: %s\n" +
                               "Signaux analysés: %d\n" +
                               "Confiance moyenne: %.1f%%\n" +
                               "ENTRY: %.5f\n" +
                               "SL: %.5f (%.1f pips - 20%%)\n" +
                               "TP: %.5f (%.1f pips - 80%%)\n" +
                               "Temps: %s\n\n" +
                               "✅ Ordre limit placé automatiquement\n" +
                               "%s",
                               GetAlgorithmHeader(),
                               symbol, symbolType, tradeType, signalCount, avgConfidence, 
                               price, sl, slPips, tp, tpPips, 
                               TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
                               GetSignalSeparator());
      }
   }
   else
   {
      message = StringFormat("%s\n\n" +
                            "🎯 SIGNAL SPIKE DÉTECTÉ\n\n" +
                            "Symbole: %s (%s)\n" +
                            "Type: %s\n" +
                            "ENTRY: %.5f\n" +
                            "SL: %.5f (%.1f pips - 20%%)\n" +
                            "TP: %.5f (%.1f pips - 80%%)\n" +
                            "Temps: %s\n\n" +
                            "✅ Ordre limit placé automatiquement\n" +
                            "%s",
                            GetAlgorithmHeader(),
                            symbol, symbolType, tradeType, price, sl, slPips, tp, tpPips, 
                            TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES),
                            GetSignalSeparator());
   }
   
   // Envoyer la notification MT5
   SendNotification(message);
   
   // Afficher aussi dans le journal
   Print("📢 NOTIFICATION MT5: ", message);
}

//+------------------------------------------------------------------+
//| Envoie une notification push pour une flèche détectée            |
//+------------------------------------------------------------------+
void SendArrowNotification(string symbol, int direction, double entryPrice, double sl, double tp, double confidence)
{
   if(!InpEnableNotifications) 
      return;
   
   string arrowColor = (direction > 0) ? "VERT" : "ROUGE";
   string directionText = (direction > 0) ? "BUY" : "SELL";
   string symbolType = IsSymbolBoom(symbol) ? "BOOM" : (IsSymbolCrash(symbol) ? "CRASH" : "NORMAL");
   
   // Message push court et clair
   string pushMessage = StringFormat("🚀 FLÈCHE %s DÉTECTÉE\n\n" +
                                    "Symbole: %s (%s)\n" +
                                    "Direction: %s\n" +
                                    "Couleur: %s\n" +
                                    "Confiance: %.1f%%\n" +
                                    "Entry: %.5f\n" +
                                    "SL: %.5f\n" +
                                    "TP: %.5f\n" +
                                    "Temps: %s",
                                    arrowColor, symbol, symbolType, directionText, arrowColor, 
                                    confidence, entryPrice, sl, tp,
                                    TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS));
   
   // Envoyer la notification MT5
   SendNotification(pushMessage);
   
   // Afficher dans le journal
   Print("📢 NOTIFICATION FLÈCHE: ", pushMessage);
   
   // Si un numéro de téléphone est configuré, envoyer aussi par SMS
   if(InpPhoneNumber != "")
   {
      string smsMessage = StringFormat("Fleche %s %s - %s Entry:%.5f SL:%.5f TP:%.5f", 
                                       arrowColor, directionText, symbol, entryPrice, sl, tp);
   
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
   double currentATR = GetCurrentATR(g_atr_handle);
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
   double atr = GetCurrentATR(g_atr_handle);
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
   
   PrintFormat("🎯 PRÉDICTION SPIKE: Prix actuel=%.5f, Prix prédit=%.5f, Direction=%s, Confiance=%.1f%%",
               currentPrice, prediction.predictedPrice, 
               (prediction.direction > 0 ? "HAUSSIER" : "BAISSIER"), 
               prediction.confidence);
   
   return prediction;
}

//+------------------------------------------------------------------+
//| Vérifie si on doit dessiner une flèche (évite les doublons)     |
//| Ne dessine que si le spike est imminent (quelques secondes avant)|
//+------------------------------------------------------------------+
bool ShouldDrawArrow(int direction, double entryPrice)
{
   datetime currentTime = TimeCurrent();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double priceTolerance = point * 100; // Tolérance de 100 points
   
   // Obtenir la prédiction pour vérifier si le spike est imminent
   SpikePrediction prediction = PredictSpikeBeforeItHappens(_Symbol, InpSpikeTimeframe, InpScientificLookback);
   
   // Vérifier si un spike vient d'être détecté (dans les 5 dernières secondes)
   // Si oui, ne pas afficher de nouvelle flèche (le spike est déjà arrivé)
   if((currentTime - g_lastSpikeTime) < 5)
   {
      return false; // Spike déjà détecté, ne pas afficher de flèche
   }
   
   // Ne dessiner la flèche que si :
   // 1. La prédiction indique un spike imminent (dans les 30 prochaines secondes)
   // 2. OU si la confiance est très élevée (>70%) et le spike est prévu dans la minute
   bool spikeImminent = false;
   if(prediction.direction != 0 && prediction.predictedTime > 0)
   {
      int secondsToSpike = (int)(prediction.predictedTime - currentTime);
      // Afficher seulement si le spike est prévu dans les 5-30 prochaines secondes
      spikeImminent = (secondsToSpike >= 5 && secondsToSpike <= 30);
      
      // OU si confiance très élevée et spike dans la minute
      if(!spikeImminent && prediction.confidence >= 70 && secondsToSpike > 0 && secondsToSpike <= 60)
      {
         spikeImminent = true;
      }
   }
   
   // Si le spike n'est pas imminent, ne pas afficher de flèche
   if(!spikeImminent && prediction.direction == 0)
   {
      return false;
   }
   
   // Si c'est la même direction et le même prix (à 100 points près) dans les 10 dernières secondes, ne pas redessiner
   if(g_lastArrowDirection == direction && 
      MathAbs(g_lastArrowPrice - entryPrice) < priceTolerance &&
      (currentTime - g_lastArrowTime) < 10) // Réduit à 10 secondes
   {
      return false; // Ne pas redessiner
   }
   
   // Mettre à jour les variables globales
   g_lastArrowTime = currentTime;
   g_lastArrowDirection = direction;
   g_lastArrowPrice = entryPrice;
   
   return true; // Dessiner la flèche
}

//+------------------------------------------------------------------+
//| Dessine un cercle d'entrée avec les niveaux d'entrée, SL, TP    |
//+------------------------------------------------------------------+
void DrawSpikeArrow(int direction, bool shouldBlink = false)
{
   string symbol = _Symbol;
   double price = iClose(symbol, InpSpikeTimeframe, 0);
   datetime t = iTime(symbol, InpSpikeTimeframe, 0);
   
   // Obtenir la prédiction de spike AVANT qu'il arrive (une bougie avant)
   SpikePrediction prediction = PredictSpikeBeforeItHappens(symbol, InpSpikeTimeframe, InpScientificLookback);
   
   // Si la prédiction anticipée n'a pas détecté de spike, utiliser la prédiction classique
   if(prediction.direction == 0)
   {
      prediction = PredictSpikePrice(symbol, InpSpikeTimeframe, InpScientificLookback);
   }
   
   // Si la prédiction n'est pas valide, utiliser les valeurs par défaut
   if(prediction.direction == 0)
   {
      prediction.direction = direction;
      prediction.entryPrice = price;
      double atr = GetCurrentATR(g_atr_handle);
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
   
   // SUPPRIMÉ: Ne plus dessiner les cercles et points d'entrée sur le graphique
   // Seulement la flèche de signal
   
   // Couleurs: Vert pour BUY, Rouge pour SELL
   color arrowColor;
   if(isReverseTrade)
   {
      arrowColor = (direction > 0) ? clrOrange : clrMagenta; // Orange pour BUY inverse, Magenta pour SELL inverse
   }
   else
   {
      arrowColor = (direction > 0) ? clrLime : clrRed; // Vert pour BUY, Rouge pour SELL
   }
   
   // DESSINER UNE SEULE FLÈCHE TEMPORAIRE (qui disparaît après le spike)
   string arrowName = "FXPRO_" + (string)InpMagicNumber + "_DYNAMIC_ARROW";
   datetime currentTime = TimeCurrent();
   
   // Vérifier si un spike vient d'être détecté - supprimer la flèche immédiatement
   bool spikeJustDetected = false;
   if(prediction.direction != 0)
   {
      // Vérifier si le prix a bougé de manière significative (spike détecté)
      double currentPrice = iClose(symbol, InpSpikeTimeframe, 0);
      double priceChange = MathAbs(currentPrice - prediction.entryPrice);
      double atr = GetCurrentATR(g_atr_handle);
      if(atr > 0 && priceChange > atr * 2.0) // Mouvement > 2 ATR = spike probable
      {
         spikeJustDetected = true;
         g_lastSpikeTime = currentTime;
      }
   }
   
   // Si un spike vient d'être détecté, supprimer la flèche
   if(spikeJustDetected && ObjectFind(0, arrowName) >= 0)
   {
      ObjectDelete(0, arrowName);
      ChartRedraw();
      return; // Ne pas créer de nouvelle flèche
   }
   
   // Vérifier l'âge de la flèche existante - supprimer si > 60 secondes
   if(ObjectFind(0, arrowName) >= 0)
   {
      if((currentTime - g_arrowCreationTime) > 60) // Flèche trop ancienne (>60s)
      {
         ObjectDelete(0, arrowName);
         g_arrowCreationTime = 0;
      }
   }
   
   // Gérer le clignotement si confiance > 80%
   if(shouldBlink)
   {
      ulong currentTimeMs = GetTickCount64();
      // Clignoter toutes les 500ms (0.5 seconde)
      if(g_lastArrowBlinkTime == 0 || (currentTimeMs - g_lastArrowBlinkTime) >= 500)
      {
         g_arrowBlinkState = !g_arrowBlinkState;
         g_lastArrowBlinkTime = currentTimeMs;
         
         // Bip sonore lors du clignotement (seulement quand la flèche devient visible)
         if(g_arrowBlinkState)
         {
            PlaySound("alert.wav"); // Bip sonore pour signaler le clignotement
         }
      }
      
      // Si clignotement activé, alterner entre couleur normale et transparente
      if(g_arrowBlinkState)
      {
         // Flèche visible avec couleur normale
         arrowColor = (direction > 0) ? clrLime : clrRed;
         if(isReverseTrade)
         {
            arrowColor = (direction > 0) ? clrOrange : clrMagenta;
         }
      }
      else
      {
         // Flèche invisible (transparente) pour effet de clignotement
         arrowColor = (direction > 0) ? C'0,255,0,100' : C'255,0,0,100'; // Vert/Rouge avec transparence
         if(isReverseTrade)
         {
            arrowColor = (direction > 0) ? C'255,165,0,100' : C'255,0,255,100'; // Orange/Magenta avec transparence
         }
      }
   }
   
   // Vérifier si la flèche existe déjà, sinon la créer
   if(ObjectFind(0, arrowName) < 0)
   {
      // Créer la flèche pour la première fois
      if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, t, price))
      {
         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
         ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, (direction>0)?233:234); // Flèche vers le haut/bas
         ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, shouldBlink ? 4 : 3); // Plus large si clignote
         ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, InpSpikeTimeframe);
         ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
         ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
         g_arrowCreationTime = currentTime; // Enregistrer le moment de création
      }
   }
   else
   {
      // Mettre à jour la position et les propriétés de la flèche existante
      ObjectSetInteger(0, arrowName, OBJPROP_TIME, t);
      ObjectSetDouble(0, arrowName, OBJPROP_PRICE, price);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, (direction>0)?233:234);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, shouldBlink ? 4 : 3); // Plus large si clignote
   }
   
   // SUPPRIMÉ: Ne plus dessiner les lignes ENTRY, SL, TP sur le graphique
   // Les niveaux seront inclus dans les notifications uniquement
   
   // Ajouter le signal au buffer (consolidation sur 3.5 minutes)
   AddSignalToBuffer(symbol, direction, prediction.confidence, prediction.entryPrice, prediction.stopLoss, prediction.takeProfit);
   
   // Print désactivé pour performance
   // PrintFormat("📍 Flèche dessinée: Direction=%s, Entry=%.5f, SL=%.5f, TP=%.5f, Confiance=%.1f%%",
   //             (direction > 0 ? "BUY" : "SELL"), 
   //             prediction.entryPrice, prediction.stopLoss, prediction.takeProfit, prediction.confidence);
   
   // NOTE: Les signaux individuels ne sont PAS envoyés en notification
   // Seuls les 3 meilleurs signaux consolidés (3.5 min) seront envoyés et exécutés
   // Les signaux individuels sont seulement collectés dans les buffers pour consolidation
   
   // Forcer le rafraîchissement du graphique
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Nettoie les flèches anciennes ou après un spike                 |
//+------------------------------------------------------------------+
void CleanupOldArrows()
{
   string arrowName = "FXPRO_" + (string)InpMagicNumber + "_DYNAMIC_ARROW";
   datetime currentTime = TimeCurrent();
   
   // Si la flèche existe
   if(ObjectFind(0, arrowName) >= 0)
   {
      // Supprimer si :
      // 1. Un spike vient d'être détecté (dans les 5 dernières secondes)
      if((currentTime - g_lastSpikeTime) < 5 && g_lastSpikeTime > 0)
      {
         ObjectDelete(0, arrowName);
         g_arrowCreationTime = 0;
         ChartRedraw();
         return;
      }
      
      // 2. La flèche est trop ancienne (>60 secondes)
      if(g_arrowCreationTime > 0 && (currentTime - g_arrowCreationTime) > 60)
      {
         ObjectDelete(0, arrowName);
         g_arrowCreationTime = 0;
         ChartRedraw();
         return;
      }
      
      // 3. Vérifier si le prix a bougé de manière significative (spike détecté)
      double currentPrice = iClose(_Symbol, InpSpikeTimeframe, 0);
      double priceChange = MathAbs(currentPrice - g_lastArrowPrice);
      double atr = GetCurrentATR(g_atr_handle);
      if(atr > 0 && priceChange > atr * 2.0) // Mouvement > 2 ATR = spike probable
      {
         ObjectDelete(0, arrowName);
         g_arrowCreationTime = 0;
         g_lastSpikeTime = currentTime;
         ChartRedraw();
         return;
      }
   }
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
   
   PrintFormat("📊 Signal ajouté au buffer [%s]: Direction=%s, Confiance=%.1f%%, Total signaux=%d",
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
      PrintFormat("🏆 Top symbole %d: %s avec %d signaux", i + 1, symbols[i], signalCounts[i]);
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
            PrintFormat("🚫 Signal consolidé pour %s IGNORÉ: seulement %d signaux analysés (< %d minimum requis) - Signal NON envoyé",
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
            PrintFormat("⚠️ Signal consolidé pour %s IGNORÉ: direction indéterminée - Signal NON envoyé", currentSymbol);
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
                  PrintFormat("⚠️ Signal consolidé pour %s IGNORÉ: timing non respecté (dernier signal envoyé il y a moins de 3.5 min) - Signal NON envoyé",
                              currentSymbol);
                  break;
               }
            }
         }
         
         // ENVOYER IMMÉDIATEMENT si le signal est valide
         if(canSend && finalDirection != 0 && signalCount >= MIN_SIGNAL_COUNT)
         {
            PrintFormat("🚀 ENVOI IMMÉDIAT du signal consolidé pour %s: %s, Confiance=%.1f%%, Signaux=%d, Entry=%.5f, SL=%.5f, TP=%.5f",
                        currentSymbol, (finalDirection > 0 ? "BUY" : "SELL"), avgConfidence, signalCount, avgEntry, avgSL, avgTP);
            
            // Envoyer la notification immédiatement
            if(InpEnableNotifications)
            {
               bool is100Percent = (avgConfidence >= 99.9);
               SendTradingNotification(currentSymbol, finalDirection, avgEntry, avgSL, avgTP, signalCount, avgConfidence, is100Percent);
               
               string signalMsg = StringFormat(
                  "🎯 SIGNAL CONSOLIDÉ [%s] (3.5 min)\n" +
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
                        PrintFormat("⚠️ Déjà une position ouverte pour %s. Signal consolidé NON exécuté pour ce symbole.", currentSymbol);
                        break;
                     }
                  }
               }
               
               if(!hasPositionForSymbol)
               {
                  PrintFormat("🚀 EXÉCUTION DIRECTE du trade consolidé: %s %s, Entry=%.5f, SL=%.5f, TP=%.5f",
                              (finalDirection > 0 ? "BUY" : "SELL"), currentSymbol, avgEntry, avgSL, avgTP);
                  PrintFormat("✅ Signal validé: %d signaux analysés (>= %d minimum requis)", signalCount, MIN_SIGNAL_COUNT);
                  
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
         PrintFormat("🚫 FILTRÉ - Signal consolidé pour %s (%d signaux analysés) - Seuil minimum de %d signaux non atteint - Signal NON envoyé", 
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
      PrintFormat("📊 FILTRAGE: Total signaux consolidés prêts (>= %d signaux): %d", MIN_SIGNAL_COUNT, ArraySize(readySignals));
      for(int i = 0; i < ArraySize(readySignals); i++)
      {
         PrintFormat("   Signal #%d: %s - Confiance: %.1f%%, Signaux: %d", 
                     i + 1, readySignals[i].symbol, readySignals[i].avgConfidence, readySignals[i].signalCount);
      }
      PrintFormat("✅ Seuls les TOP %d (confiance la plus élevée) seront exécutés - Les autres seront BLOQUÉS", topCount);
   }
   
   // Vérifier que topCount > 0 avant de traiter (double vérification)
   if(topCount == 0)
   {
      PrintFormat("⚠️ Aucun signal valide disponible après filtrage - Aucune notification envoyée");
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
      
      PrintFormat("🏆 Traitement du signal consolidé #%d: %s - Confiance: %.1f%%, Signaux: %d", 
                  idx + 1, currentSymbol, avgConfidence, signalCount);
      
      // VÉRIFICATION CRITIQUE: Le signal doit avoir au moins 20 signaux analysés
      if(signalCount < MIN_SIGNAL_COUNT)
      {
         PrintFormat("⚠️ Signal consolidé pour %s IGNORÉ: seulement %d signaux analysés (< %d minimum requis) - Aucune notification envoyée",
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
               PrintFormat("⚠️ Signal consolidé pour %s IGNORÉ: timing non respecté (dernier signal envoyé il y a moins de 3.5 min) - Aucune notification envoyée",
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
                  "%s🎯 **SIGNAL CONSOLIDÉ [%s] (3.5 min) - TOP %d - ⭐ 100%% GAGNANT ⭐**\n" +
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
                  "%s🎯 SIGNAL CONSOLIDÉ [%s] (3.5 min) - TOP %d\n" +
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
         
         PrintFormat("✅ Signal consolidé TOP %d envoyé pour %s: %s, Confiance=%.1f%%, Entry=%.5f, SL=%.5f, TP=%.5f",
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
                     PrintFormat("⚠️ Déjà une position ouverte pour %s. Signal consolidé TOP %d NON exécuté pour ce symbole.",
                                 currentSymbol, idx + 1);
                     break;
                  }
               }
            }
            
            if(!hasPositionForSymbol)
            {
               PrintFormat("🚀 EXÉCUTION DIRECTE du trade consolidé TOP %d: %s %s, Entry=%.5f, SL=%.5f, TP=%.5f",
                           idx + 1, (finalDirection > 0 ? "BUY" : "SELL"), currentSymbol, avgEntry, avgSL, avgTP);
               PrintFormat("✅ Signal validé: %d signaux analysés (>= %d minimum requis)", signalCount, MIN_SIGNAL_COUNT);
               
               // Exécuter directement le trade (sans limite de nombre de positions)
               ExecuteDirectTrade(currentSymbol, finalDirection, avgEntry, avgSL, avgTP, avgConfidence);
            }
         }
         else if(InpEnableTrading && signalCount < MIN_SIGNAL_COUNT)
         {
            PrintFormat("⚠️ Signal consolidé TOP %d IGNORÉ: seulement %d signaux analysés (< %d minimum requis) - Trade NON exécuté",
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
               PrintFormat("🚫 BLOQUÉ - Signal consolidé pour %s (%d signaux analysés) - Seuil minimum de %d signaux non atteint - Signal NON envoyé et NON exécuté", 
                           g_signalBuffers[i].symbol, g_signalBuffers[i].signalCount, MIN_SIGNAL_COUNT);
            }
            else
            {
               PrintFormat("🚫 BLOQUÉ - Signal consolidé pour %s (%d signaux analysés) - Pas dans les TOP 3 - Signal NON envoyé et NON exécuté", 
                           g_signalBuffers[i].symbol, g_signalBuffers[i].signalCount);
            }
            ArrayRemove(g_signalBuffers, i, 1);
         }
      }
   }
   
   // Message récapitulatif
   if(ArraySize(readySignals) > topCount)
   {
      PrintFormat("📋 RÉSUMÉ: %d signal(s) consolidé(s) envoyé(s) sur %d disponible(s) - %d signal(s) bloqué(s)", 
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
      
      // Créer un handle pour l'EMA
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
   // TOUJOURS UTILISER LE LOT MINIMUM POUR CHAQUE SYMBOLE
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Retourner directement le lot minimum normalisé
   double steps = MathFloor(min_lot / lot_step + 0.5);
   double lot = steps * lot_step;
   if(lot < min_lot) lot = min_lot;
   
   return NormalizeDouble(lot, 2);
   
   // CODE ORIGINAL DÉSACTIVÉ - Utilisation du lot minimum uniquement
   /*
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

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
   if(g_ma20_handle == INVALID_HANDLE || g_ma50_handle == INVALID_HANDLE)
      return false;

   double ma20[], ma50[];
   ArraySetAsSeries(ma20, true);
   ArraySetAsSeries(ma50, true);

   if(CopyBuffer(g_ma20_handle, 0, 0, 1, ma20) <= 0 ||
      CopyBuffer(g_ma50_handle, 0, 0, 1, ma50) <= 0)
   {
      Print("Erreur lecture MA20/MA50");
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
//+------------------------------------------------------------------+
//| Compte uniquement les positions ouvertes (tous symboles)        |
//+------------------------------------------------------------------+
int CountTotalOpenPositions()
{
   int count = 0;
   
   // Compter les positions ouvertes (TOUS SYMBOLES CONFONDUS)
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
   
   return count;
}

//+------------------------------------------------------------------+
//| Compte le nombre total d'ordres (positions + ordres en attente) |
//| TOUS SYMBOLES CONFONDUS                                          |
//+------------------------------------------------------------------+
int CountTotalOrders()
{
   int totalPositions = CountTotalOpenPositions();
   int totalPendingOrders = CountPendingLimitOrders();
   return totalPositions + totalPendingOrders;
}

//+------------------------------------------------------------------+
//| Vérifie s'il existe déjà une position ou un ordre en attente    |
//| pour un symbole spécifique                                       |
//| Retourne true si une position ou un ordre existe déjà           |
//+------------------------------------------------------------------+
bool HasPositionOrOrderForSymbol(string symbol)
{
   // Vérifier les positions ouvertes pour ce symbole
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
            PositionGetString(POSITION_SYMBOL) == symbol)
         {
            return true; // Une position existe déjà pour ce symbole
         }
      }
   }
   
   // Vérifier les ordres en attente pour ce symbole
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
            OrderGetString(ORDER_SYMBOL) == symbol)
         {
            ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT)
            {
               return true; // Un ordre en attente existe déjà pour ce symbole
            }
         }
      }
   }
   
   return false; // Aucune position ni ordre en attente pour ce symbole
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
               PrintFormat("🗑️ Ordre limit #%d supprimé pour %s (remplacé par nouveau signal consolidé)", ticket, symbol);
            }
            else
            {
               PrintFormat("❌ Erreur lors de la suppression de l'ordre limit #%d: %s", ticket, trade.ResultComment());
            }
         }
      }
   }
   if(deletedCount > 0)
   {
      PrintFormat("✅ %d ordre(s) limit supprimé(s) pour %s", deletedCount, symbol);
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
            PrintFormat("📊 Ajustement prix BUY: %.5f -> %.5f (proche du support %.5f)", 
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
            PrintFormat("📊 Ajustement prix SELL: %.5f -> %.5f (proche de la résistance %.5f)", 
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
   
   // VÉRIFIER LA LIMITE DE 2 TRADES EN COURS (positions + ordres en attente) - TOUS SYMBOLES CONFONDUS
   int totalOrders = CountTotalOrders();
   
   if(totalOrders >= 2)
   {
      int totalOpenTrades = CountTotalOpenPositions();
      int totalPendingOrders = CountPendingLimitOrders();
      PrintFormat("⚠️ Trade direct NON exécuté - Déjà %d ordres en cours (Positions: %d, En attente: %d). Limite: 2",
                 totalOrders, totalOpenTrades, totalPendingOrders);
      return;
   }
   
   // VÉRIFIER QU'IL N'Y A PAS DÉJÀ UNE POSITION OU UN ORDRE EN ATTENTE POUR CE SYMBOLE
   if(HasPositionOrOrderForSymbol(symbol))
   {
      PrintFormat("⚠️ Trade direct BLOQUÉ - Déjà une position ou un ordre en attente pour %s", symbol);
      return; // Bloquer ce signal, un trade existe déjà pour ce symbole
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
      Print("❌ Taille de lot invalide pour ", symbol);
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
      PrintFormat("✅ Trade direct exécuté: %s %s, Lot=%.2f, Entry=%.5f, SL=%.5f, TP=%.5f, Ticket=%llu",
                  tradeType, symbol, lotSize, currentPrice, sl, tp, ticket);
      
      // Enregistrer le signal pour l'apprentissage
      RecordSignalFeatures(symbol, direction, signalConfidence, currentPrice, sl, tp, 1, 1);
   }
   else
   {
      PrintFormat("❌ Échec exécution trade direct: %s %s, Erreur: %d - %s",
                  tradeType, symbol, GetLastError(), trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Exécute un trade direct pour CHOCH (sans vérifier position existante)|
//+------------------------------------------------------------------+
void ExecuteDirectTradeCHOCH(string symbol, int direction, double entryPrice, double sl, double tp, double signalConfidence = 100.0)
{
   if(direction == 0 || !InpEnableTrading) return;
   
   // VÉRIFIER QU'IL N'Y A PAS DÉJÀ UNE POSITION OU UN ORDRE EN ATTENTE POUR CE SYMBOLE
   if(HasPositionOrOrderForSymbol(symbol))
   {
      PrintFormat("⚠️ Trade CHOCH BLOQUÉ - Déjà une position ou un ordre en attente pour %s", symbol);
      return; // Bloquer ce signal, un trade existe déjà pour ce symbole
   }
   
   // VÉRIFIER LA LIMITE DE 2 TRADES EN COURS (positions + ordres en attente) - TOUS SYMBOLES CONFONDUS
   int totalOrders = CountTotalOrders();
   
   if(totalOrders >= 2)
   {
      int totalOpenTrades = CountTotalOpenPositions();
      int totalPendingOrders = CountPendingLimitOrders();
      PrintFormat("⚠️ Trade CHOCH NON exécuté - Déjà %d ordres en cours (Positions: %d, En attente: %d). Limite: 2",
                 totalOrders, totalOpenTrades, totalPendingOrders);
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
      Print("❌ Taille de lot invalide pour ", symbol);
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
   
   // Exécuter le trade au marché IMMÉDIATEMENT pour CHOCH
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   bool success = false;
   string tradeType = (direction > 0) ? "BUY" : "SELL";
   string comment = StringFormat("CHOCH %s", tradeType);
   
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
      PrintFormat("✅ Trade CHOCH exécuté: %s %s, Lot=%.2f, Entry=%.5f, SL=%.5f, TP=%.5f, Ticket=%llu",
                  tradeType, symbol, lotSize, currentPrice, sl, tp, ticket);
   }
   else
   {
      PrintFormat("❌ Échec exécution trade CHOCH: %s %s, Erreur: %d - %s",
                  tradeType, symbol, GetLastError(), trade.ResultComment());
   }
}

//+------------------------------------------------------------------+
//| Place un ordre limite pour CHOCH avec SL et TP réajustés        |
//+------------------------------------------------------------------+
void PlaceLimitOrderCHOCH(string symbol, int direction, double entryPrice, double sl, double tp, double atr)
{
   if(direction == 0 || !InpEnableTrading) return;
   
   // VÉRIFIER LA LIMITE DE 2 TRADES EN COURS (positions + ordres en attente) - TOUS SYMBOLES CONFONDUS
   int totalOrders = CountTotalOrders();
   
   if(totalOrders >= 2)
   {
      int totalOpenTrades = CountTotalOpenPositions();
      int totalPendingOrders = CountPendingLimitOrders();
      PrintFormat("⚠️ Ordre limite CHOCH NON placé - Déjà %d ordres en cours (Positions: %d, En attente: %d). Limite: 2",
                 totalOrders, totalOpenTrades, totalPendingOrders);
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
         if(atr <= 0)
         {
            MqlRates rates[];
            if(CopyRates(symbol, InpSpikeTimeframe, 0, 1, rates) > 0)
               atr = rates[0].high - rates[0].low;
         }
         if(atr <= 0)
         {
            double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
            atr = point * 100;
         }
         lotSize = CalculateLotSize(atr);
      }
   }
   
   // Normaliser le lot
   lotSize = NormalizeLotSize(lotSize, symbol);
   if(!IsValidLotSize(lotSize, symbol))
   {
      Print("❌ Taille de lot invalide pour ", symbol);
      return;
   }
   
   // Normaliser les prix
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   entryPrice = NormalizeDouble(entryPrice, digits);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   // Réajuster SL et TP pour ordre limite (plus serrés)
   double slAdjustment = atr * 0.2; // Réduire SL de 20%
   double tpAdjustment = atr * 0.3; // Réduire TP de 30%
   
   if(direction > 0)
   {
      sl = sl + slAdjustment;
      tp = tp - tpAdjustment;
   }
   else
   {
      sl = sl - slAdjustment;
      tp = tp + tpAdjustment;
   }
   
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   // Obtenir le prix actuel
   double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   // Placer l'ordre limite
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   bool success = false;
   string tradeType = (direction > 0) ? "BUY" : "SELL";
   string comment = StringFormat("CHOCH Limit %s", tradeType);
   
   // Pour M1, placer l'ordre très proche du prix actuel
   double limitDistance = (InpSpikeTimeframe == PERIOD_M1) ? atr * 0.15 : atr * 0.3;
   double limitPrice;
   
   if(direction > 0)
   {
      limitPrice = currentBid - limitDistance;
      limitPrice = NormalizeDouble(limitPrice, digits);
      if(limitPrice >= currentBid) limitPrice = currentBid - (atr * 0.1);
      success = trade.BuyLimit(lotSize, limitPrice, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
   }
   else
   {
      limitPrice = currentAsk + limitDistance;
      limitPrice = NormalizeDouble(limitPrice, digits);
      if(limitPrice <= currentAsk) limitPrice = currentAsk + (atr * 0.1);
      success = trade.SellLimit(lotSize, limitPrice, symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
   }
   
   if(success)
   {
      ulong ticket = trade.ResultOrder();
      PrintFormat("✅ Ordre limite CHOCH placé: %s %s, Lot=%.2f, Limit=%.5f, SL=%.5f, TP=%.5f, Ticket=%llu",
                  tradeType, symbol, lotSize, limitPrice, sl, tp, ticket);
   }
   else
   {
      PrintFormat("❌ Échec ordre limite CHOCH: %s %s, Erreur: %d - %s",
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
   
   // VÉRIFIER LA LIMITE DE 2 TRADES EN COURS (positions + ordres en attente) - TOUS SYMBOLES CONFONDUS
   int totalOrders = CountTotalOrders();
   
   if(totalOrders >= 2)
   {
      int totalOpenTrades = CountTotalOpenPositions();
      int totalPendingOrders = CountPendingLimitOrders();
      PrintFormat("⚠️ Trade avec niveaux NON exécuté - Déjà %d ordres en cours (Positions: %d, En attente: %d). Limite: 2",
                 totalOrders, totalOpenTrades, totalPendingOrders);
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
      Print("⚠️ Trade inverse détecté - Lot réduit à ", lotPerOrder, " pour plus de prudence");
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
   Print("⚠️ Perte potentielle: ", DoubleToString(potentialLoss, 2), " $ (vérification désactivée pour permettre trading)");
   
   string comment = isReverseTrade ? "Spike REVERSE " : "Spike ";
   
   // NOUVELLE LOGIQUE: Vérifier le nombre de trades ouverts
   int totalOpenTrades = CountTotalOpenPositions();
   
   // Si moins de 2 trades ouverts, exécuter directement au marché
   if(totalOpenTrades < 2)
   {
      // Exécution directe au marché
      double currentPrice = (direction > 0) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
      
      // Réajuster SL et TP pour l'exécution directe (plus serrés)
      double adjustedSL = sl;
      double adjustedTP = tp;
      
      // Ajuster SL et TP en fonction de la confiance et de l'ATR
      if(signalConfidence >= 70)
      {
         // Confiance élevée: SL et TP normaux
         adjustedSL = sl;
         adjustedTP = tp;
      }
      else if(signalConfidence >= 50)
      {
         // Confiance moyenne: SL un peu plus serré, TP un peu plus proche
         double slAdjustment = atr_val * 0.2;
         double tpAdjustment = atr_val * 0.3;
         if(direction > 0)
         {
            adjustedSL = sl + slAdjustment;
            adjustedTP = tp - tpAdjustment;
         }
         else
         {
            adjustedSL = sl - slAdjustment;
            adjustedTP = tp + tpAdjustment;
         }
      }
      else
      {
         // Confiance faible: SL plus serré, TP plus proche
         double slAdjustment = atr_val * 0.3;
         double tpAdjustment = atr_val * 0.5;
         if(direction > 0)
         {
            adjustedSL = sl + slAdjustment;
            adjustedTP = tp - tpAdjustment;
         }
         else
         {
            adjustedSL = sl - slAdjustment;
            adjustedTP = tp + tpAdjustment;
         }
      }
      
      // Normaliser les prix ajustés
      adjustedSL = NormalizeDouble(adjustedSL, digits);
      adjustedTP = NormalizeDouble(adjustedTP, digits);
      
      // Exécuter le trade au marché
      bool result = false;
      if(direction > 0)
      {
         result = trade.Buy(lotPerOrder, symbol, currentPrice, adjustedSL, adjustedTP, comment);
      }
      else
      {
         result = trade.Sell(lotPerOrder, symbol, currentPrice, adjustedSL, adjustedTP, comment);
      }
      
      if(result)
      {
         PrintFormat("✅ Trade exécuté directement au marché: %s %s, Lot: %.2f, Entry: %.5f, SL: %.5f, TP: %.5f",
                    direction > 0 ? "BUY" : "SELL", symbol, lotPerOrder, currentPrice, adjustedSL, adjustedTP);
      }
      else
      {
         PrintFormat("❌ Échec exécution trade direct: %s %s, Erreur: %d - %s",
                    direction > 0 ? "BUY" : "SELL", symbol, GetLastError(), trade.ResultComment());
      }
      
      return; // Sortir après exécution directe
   }
   
   // Si 2 trades ou plus, placer un ordre limite avec SL et TP réajustés
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
            // 2 ordres limite en dessous du prix actuel (très proches pour M1 - PRÉCIS POUR CAPTURER LE SPIKE)
            if(InpSpikeTimeframe == PERIOD_M1)
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
               Print("⚠️ Ordre limite ", i+1, " ignoré: prix limite (", limitPrice, ") >= prix actuel (", currentBid, ")");
               continue;
            }
            
            // Calculer SL et TP pour cet ordre (ajustés selon la confiance et M1)
            double slMult = (InpSpikeTimeframe == PERIOD_M1) ? InpSLMultiplierM1 : 1.5;
            double tpMult = (InpSpikeTimeframe == PERIOD_M1) ? InpTPMultiplierM1 : 3.0;
            
            // Réajuster SL et TP selon la confiance du signal
            if(signalConfidence >= 70)
            {
               // Confiance élevée: SL et TP normaux
               // Pas d'ajustement
            }
            else if(signalConfidence >= 50)
            {
               // Confiance moyenne: SL un peu plus serré, TP un peu plus proche
               slMult *= 0.9; // Réduire SL de 10%
               tpMult *= 0.85; // Réduire TP de 15%
            }
            else
            {
               // Confiance faible: SL plus serré, TP plus proche
               slMult *= 0.8; // Réduire SL de 20%
               tpMult *= 0.7; // Réduire TP de 30%
            }
            
            double orderSL = limitPrice - (atr_val * slMult);
            double orderTP = limitPrice + (atr_val * tpMult);
            orderSL = NormalizeDouble(orderSL, digits);
            orderTP = NormalizeDouble(orderTP, digits);
            
            if(trade.BuyLimit(lotPerOrder, limitPrice, symbol, orderSL, orderTP, ORDER_TIME_GTC, 0, comment + "BUY_L" + IntegerToString(i+1)))
            {
               ordersPlaced++;
               Print("✅ Ordre limite BUY ", i+1, " placé: Prix=", limitPrice, ", Lot=", lotPerOrder, ", SL=", orderSL, ", TP=", orderTP);
            }
            else
            {
               Print("❌ Échec ordre limite BUY ", i+1, ". Erreur: ", GetLastError(), " - ", trade.ResultComment());
            }
         }
         else // SELL
         {
            // 2 ordres limite au-dessus du prix actuel (très proches pour M1 - PRÉCIS POUR CAPTURER LE SPIKE)
            if(InpSpikeTimeframe == PERIOD_M1)
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
               Print("⚠️ Ordre limite ", i+1, " ignoré: prix limite (", limitPrice, ") <= prix actuel (", currentAsk, ")");
               continue;
            }
            
            // Calculer SL et TP pour cet ordre (ajustés selon la confiance et M1)
            double slMult = (InpSpikeTimeframe == PERIOD_M1) ? InpSLMultiplierM1 : 1.5;
            double tpMult = (InpSpikeTimeframe == PERIOD_M1) ? InpTPMultiplierM1 : 3.0;
            
            // Réajuster SL et TP selon la confiance du signal
            if(signalConfidence >= 70)
            {
               // Confiance élevée: SL et TP normaux
               // Pas d'ajustement
            }
            else if(signalConfidence >= 50)
            {
               // Confiance moyenne: SL un peu plus serré, TP un peu plus proche
               slMult *= 0.9; // Réduire SL de 10%
               tpMult *= 0.85; // Réduire TP de 15%
            }
            else
            {
               // Confiance faible: SL plus serré, TP plus proche
               slMult *= 0.8; // Réduire SL de 20%
               tpMult *= 0.7; // Réduire TP de 30%
            }
            
            double orderSL = limitPrice + (atr_val * slMult);
            double orderTP = limitPrice - (atr_val * tpMult);
            orderSL = NormalizeDouble(orderSL, digits);
            orderTP = NormalizeDouble(orderTP, digits);
            
            if(trade.SellLimit(lotPerOrder, limitPrice, symbol, orderSL, orderTP, ORDER_TIME_GTC, 0, comment + "SELL_L" + IntegerToString(i+1)))
            {
               ordersPlaced++;
               Print("✅ Ordre limite SELL ", i+1, " placé: Prix=", limitPrice, ", Lot=", lotPerOrder, ", SL=", orderSL, ", TP=", orderTP);
            }
            else
            {
               Print("❌ Échec ordre limite SELL ", i+1, ". Erreur: ", GetLastError(), " - ", trade.ResultComment());
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
               Print("✅ Ordre IMMÉDIAT exécuté (M1) - Direction: ", (direction > 0 ? "BUY" : "SELL"),
                     ", Lot: ", immediateLot, ", Entry: ", DoubleToString(entryPrice, digits));
            }
            else
            {
               Print("⚠️ Échec ordre immédiat. Erreur: ", GetLastError(), " - ", trade.ResultComment());
            }
         }
      }
      
      if(ordersPlaced > 0)
      {
         string tradeType = isReverseTrade ? "INVERSE" : "NORMAL";
         Print("✅ ", ordersPlaced, " ordre(s) limite ", tradeType, " placé(s) avec succès");
      }
      else
      {
         Print("❌ Aucun ordre limite n'a pu être placé");
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
         Print("❌ Échec de l'ordre. Erreur: ", GetLastError(), " - ", trade.ResultComment());
      }
      else
      {
         string tradeType = isReverseTrade ? "INVERSE" : "NORMAL";
         Print("✅ Ordre ", tradeType, " exécuté avec succès - Direction: ", (direction > 0 ? "BUY" : "SELL"),
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
   
   // VÉRIFIER LA LIMITE DE 2 TRADES EN COURS (positions + ordres en attente) - TOUS SYMBOLES CONFONDUS
   int totalOrders = CountTotalOrders();
   
   if(totalOrders >= 2)
   {
      int totalOpenTrades = CountTotalOpenPositions();
      int totalPendingOrders = CountPendingLimitOrders();
      PrintFormat("⚠️ Trade NON exécuté - Déjà %d ordres en cours (Positions: %d, En attente: %d). Limite: 2",
                 totalOrders, totalOpenTrades, totalPendingOrders);
      return;
   }
   
   // Calcul des paramètres du trade
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double entry = (direction > 0) ? ask : bid;
   double sl = 0, tp = 0;
   
   // Définir le lot à 0.2 pour les symboles Boom/Crash
   double lot = 0.2;
   
   // Vérifier que le lot est valide
   if(!IsValidLotSize(lot, symbol))
   {
      Print("Erreur: Taille de lot invalide pour ", symbol, ". Lot demandé: ", lot);
      return;
   }
   
   // Normaliser le lot selon les spécifications du symbole
   lot = NormalizeLotSize(lot, symbol);
   
   // Calcul des niveaux de SL/TP basés sur l'ATR
   if(direction > 0) // Achat
   {
      sl = ask - (atr_val * 2); // SL à 2 ATR sous l'entrée
      tp = ask + (atr_val * 4); // TP à 4 ATR au-dessus (ratio 1:2)
   }
   else // Vente
   {
      sl = bid + (atr_val * 2); // SL à 2 ATR au-dessus de l'entrée
      tp = bid - (atr_val * 4); // TP à 4 ATR en dessous (ratio 1:2)
   }
   
   // Arrondir les prix selon les spécifications du symbole
   sl = NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   tp = NormalizeDouble(tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   
   // Pour les ordres limites, diviser le lot par 2 (minimum 0.1)
   if(isLimitOrder)
   {
      lot = MathMax(0.1, lot * 0.5);
      lot = NormalizeLotSize(lot, symbol);
   }
   
   // Vérifier à nouveau que le lot est valide après ajustement
   if(!IsValidLotSize(lot, symbol))
   {
      Print("Erreur: Taille de lot invalide après ajustement. Lot: ", lot);
      return;
   }
   
   // Annuler tous les ordres en attente avant d'exécuter un ordre au marché
   if(!isLimitOrder) CancelAllPendingOrders();
   
   // Exécution du trade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   // Calculer le stop loss en pips pour la vérification du risque
   double stopLossPips = (direction > 0) ? (entry - sl) / point : (sl - entry) / point;
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double potentialLoss = (lot * stopLossPips * point * tickValue) / tickSize;
   
   // Vérifier si la perte potentielle est acceptable (max 3$)
   if(potentialLoss > 3.0)
   {
      Print("Perte potentielle trop élevée: ", DoubleToString(potentialLoss, 2), " $");
      return;
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
   
   // VÉRIFIER LA LIMITE DE 2 TRADES EN COURS (positions + ordres en attente) - TOUS SYMBOLES CONFONDUS
   int totalOrders = CountTotalOrders();
   
   if(totalOrders >= 2)
   {
      int totalOpenTrades = CountTotalOpenPositions();
      int totalPendingOrders = CountPendingLimitOrders();
      PrintFormat("⚠️ Trade prédictif NON exécuté - Déjà %d ordres en cours (Positions: %d, En attente: %d). Limite: 2",
                 totalOrders, totalOpenTrades, totalPendingOrders);
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
               
               PrintFormat("📊 Position fermée détectée: Ticket=%llu, Profit=%.2f", positionTicket, totalProfit);
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
   int handle = iADX(symbol, tf, period);
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) { IndicatorRelease(handle); return 0.0; }
   double val = buf[0];
   IndicatorRelease(handle);
   return val;
}

//+------------------------------------------------------------------+
//| Trailing stop basé sur ATR                                       |
//+------------------------------------------------------------------+
void ManageTrailing()
{
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
      double atr = GetCurrentATR(g_atr_handle);
      if(atr <= 0) continue;
      double trail = atr * InpTrailingATRMult;

      if(type == POSITION_TYPE_BUY)
      {
         double new_sl = cur_price - trail;
         double cur_sl = PositionGetDouble(POSITION_SL);
         if(new_sl > cur_sl + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0)
         {
            trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
            PrintFormat("Trailing BUY pos %I64u -> new SL %.5f", ticket, new_sl);
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         double new_sl = cur_price + trail;
         double cur_sl = PositionGetDouble(POSITION_SL);
         if(new_sl < cur_sl - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2.0)
         {
            trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP));
            PrintFormat("Trailing SELL pos %I64u -> new SL %.5f", ticket, new_sl);
         }
      }
   }
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
    MqlRates rates[];
    if(CopyRates(symbol, tf, 0, period, rates) < period) return false;
    
    // Vérifier les croisements haussiers/baissiers rapides
    int crosses = 0;
    for(int i = 1; i < period; i++)
    {
        bool current_up = rates[i].close > rates[i].open;
        bool prev_up = rates[i-1].close > rates[i-1].open;
        
        if(current_up != prev_up) crosses++;
    }
    
    return (crosses >= period / 3); // Au moins 1/3 de changements
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
    
    // Calcul du signal_strength combiné avec pondération
    double signal_strength = 0.0;
    
    // Poids Z-Score (30%)
    if(MathAbs(stats.zscore_current) > InpZScoreThreshold)
        signal_strength += 30.0;
    else if(MathAbs(stats.zscore_current) > 1.5)
        signal_strength += 20.0;
    
    // Poids Skewness (15%)
    if(MathAbs(stats.skewness) > 0.5)
        signal_strength += 15.0;
    
    // Poids Kurtosis (15%)
    if(stats.kurtosis > 3.0 || stats.kurtosis < 2.0)
        signal_strength += 15.0;
    
    // Poids Ciseaux (10%)
    if(scissor_pattern)
        signal_strength += 10.0;
    
    // Poids Fractal (10%)
    if(fractal_spike)
        signal_strength += 10.0;
    
    // Poids Volume (10%)
    if(volume_ratio > InpVolumeMultiplier)
        signal_strength += 10.0;
    else if(volume_ratio > 1.5)
        signal_strength += 5.0;
    
    // Poids Patterns (bonus)
    if(hammer_pattern) signal_strength += 5.0;
    if(engulfing_pattern) signal_strength += 8.0;
    if(gap_detected) signal_strength += 7.0;
    if(bb_breakout) signal_strength += 10.0;
    
    // BONUS pour volatilité élevée
    if(atr_ratio > 1.5)
        signal_strength += MathMin(10, (atr_ratio - 1.0) * 5);
    
    // DÉTERMINATION DE LA DIRECTION - Logique spécifique Boom/Crash
    if(IsSymbolBoom(symbol))
    {
        // Pour Boom: BUY sur spikes haussiers
        bool zscore_buy = stats.zscore_current > InpZScoreThreshold;
        bool volume_buy = volume_ratio > InpVolumeMultiplier;
        bool trend_buy = atr_ratio > 1.2;
        
        direction = (zscore_buy || volume_buy || trend_buy) ? 1 : 0;
        
        if(direction > 0)
        {
            PrintFormat("🔬 BOOM: Z-Score=%.2f (seuil %.2f), Volume=%.2fx (seuil %.2fx), ATR=%.2fx", 
                       stats.zscore_current, InpZScoreThreshold, volume_ratio, InpVolumeMultiplier, atr_ratio);
        }
    }
    else if(IsSymbolCrash(symbol))
    {
        // Pour Crash: SELL sur spikes baissiers
        bool zscore_sell = stats.zscore_current < -InpZScoreThreshold;
        bool volume_sell = volume_ratio > InpVolumeMultiplier;
        bool trend_sell = atr_ratio > 1.2;
        
        direction = (zscore_sell || volume_sell || trend_sell) ? -1 : 0;
        
        if(direction < 0)
        {
            PrintFormat("🔬 CRASH: Z-Score=%.2f (seuil -%.2f), Volume=%.2fx (seuil %.2fx), ATR=%.2fx", 
                       stats.zscore_current, InpZScoreThreshold, volume_ratio, InpVolumeMultiplier, atr_ratio);
        }
    }
    else
    {
        // Pour les autres symboles: utiliser la direction du Z-score
        direction = (stats.zscore_current > 0) ? 1 : -1;
    }
    
    strength = MathMin(100, signal_strength);
    
    // Afficher les détails de détection
    PrintFormat("🔬 Détection Scientifique %s:", symbol);
    PrintFormat("   Z-Score: %.2f, Skewness: %.3f, Kurtosis: %.3f", 
                stats.zscore_current, stats.skewness, stats.kurtosis);
    PrintFormat("   Ciseaux: %s, Fractal: %s, Volume Ratio: %.2f", 
                scissor_pattern ? "OUI" : "NON", 
                fractal_spike ? "OUI" : "NON", 
                volume_ratio);
    PrintFormat("   Patterns: Hammer=%s, Engulfing=%s, Gap=%s", 
                hammer_pattern ? "OUI" : "NON",
                engulfing_pattern ? "OUI" : "NON",
                gap_detected ? "OUI" : "NON");
    PrintFormat("   Force finale: %.1f%%, Direction: %s", 
                strength, 
                direction > 0 ? "ACHAT" : "VENTE");
    
    return (strength >= InpSpikeThresholdScientific && direction != 0);
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialisation des indicateurs
   g_atr_handle = iATR(_Symbol, InpSpikeTimeframe, 14);
   g_ma20_handle = iMA(_Symbol, InpSpikeTimeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   g_ma50_handle = iMA(_Symbol, InpSpikeTimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   // Vérification des handles
   if(g_atr_handle == INVALID_HANDLE || g_ma20_handle == INVALID_HANDLE || g_ma50_handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création des indicateurs");
      return(INIT_FAILED);
   }
   
   // Initialisation du timer pour l'analyse périodique
   EventSetTimer(1);
   
   // Initialisation du panneau de performance
   InitializePerformancePanel();
   
   Print("Expert Advisor initialisé avec succès");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Libération des indicateurs
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_ma20_handle != INVALID_HANDLE) IndicatorRelease(g_ma20_handle);
   if(g_ma50_handle != INVALID_HANDLE) IndicatorRelease(g_ma50_handle);
   
   // Nettoyage des objets graphiques
   ObjectsDeleteAll(0, "FXPRO_" + (string)InpMagicNumber + "_");
   
   // Arrêt du timer
   EventKillTimer();
   
   Print("Expert Advisor désinitialisé");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Ne traiter que les nouveaux ticks
   static datetime last_tick_time = 0;
   datetime current_time = TimeCurrent();
   if(last_tick_time == current_time) return;
   last_tick_time = current_time;
   
   // Vérifier les conditions de trading
   if(!CanPlaceNewOrder()) return;
   
   // Gérer le trailing stop
   if(InpUseTrailing) ManageTrailing();
   
   // Analyser le symbole actuel
   AnalyzeSymbol(_Symbol);
   
   // Traiter les signaux consolidés
   ProcessSignalBuffers();
   
   // Mettre à jour le panneau de performance
   UpdatePerformancePanel();
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Nettoyer les flèches et signaux anciens
   CleanupOldArrows();
   CleanupOldSignals();
   
   // Mettre à jour le dashboard
   UpdateDashboard();
}

//+------------------------------------------------------------------+

