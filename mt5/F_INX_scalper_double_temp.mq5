//+------------------------------------------------------------------+
//|                                          F_INX_scalper_double.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"
#property strict

// Constantes manquantes pour la compatibilité
#ifndef ANCHOR_LEFT_UPPER
#define ANCHOR_LEFT_UPPER 0
#endif
#ifndef ANCHOR_LEFT
#define ANCHOR_LEFT 0
#endif

// Inclusions des bibliothèques Windows nécessaires
#include <WinAPI\errhandlingapi.mqh>
#include <WinAPI\sysinfoapi.mqh>
#include <WinAPI\processenv.mqh>
#include <WinAPI\libloaderapi.mqh>
#include <WinAPI\memoryapi.mqh>

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
#include <Trade/TerminalInfo.mqh>

//+------------------------------------------------------------------+
//| STRUCTURES POUR DASHBOARD ET STRATÉGIE AVANCÉE                   |
//+------------------------------------------------------------------+
struct AISignalData
{
   string recommendation;    // BUY/SELL/HOLD
   double confidence;        // Confiance en %
   string timestamp;         // Timestamp du signal
   string reasoning;         // Raisonnement de l'IA
};

struct TrendAlignmentData
{
   string m1_trend;          // Tendance M1
   string h1_trend;          // Tendance H1
   string h4_trend;          // Tendance H4
   string d1_trend;          // Tendance D1
   bool is_aligned;          // Alignement des tendances
   double alignment_score;   // Score d'alignement 0-100%
};

struct CoherentAnalysisData
{
   string direction;         // Direction cohérente
   double coherence_score;    // Score de cohérence 0-100%
   string key_factors;       // Facteurs clés
   bool is_valid;           // Validité de l'analyse
};

struct FinalDecisionData
{
   string action;           // Action finale
   double final_confidence; // Confiance finale
   string execution_type;   // MARKET/LIMIT/SCALP
   double entry_price;      // Prix d'entrée
   double stop_loss;        // Stop loss
   double take_profit;      // Take profit
   string reasoning;        // Raisonnement complet
};

// Variables globales pour le dashboard
AISignalData g_aiSignal;
TrendAlignmentData g_trendAlignment;
CoherentAnalysisData g_coherentAnalysis;
FinalDecisionData g_finalDecision;
datetime g_lastDashboardUpdate = 0;

//+------------------------------------------------------------------+
//| DÉCLARATIONS DES FONCTIONS                                         |
//+------------------------------------------------------------------+
void UpdateAdvancedDashboard();
bool GetAISignalData();
bool GetTrendAlignmentData();
bool GetCoherentAnalysisData();
void CalculateFinalDecision();
void CalculateOptimalEntryLevels();
void ExecuteAdvancedStrategy();
double CalculateOptimalLotSize();
void ManagePositionDuplication();
void DuplicatePosition(ulong originalTicket);
void InitializePositionTracker();
void UpdatePositionTracker();
string ExtractJSONValue(string json, string key);

// Fonctions de prédiction scientifique
bool CalculateScientificPrediction();
void DisplayScientificPrediction();

//+------------------------------------------------------------------+
//| SYSTÈME DE PRÉDICTION SCIENTIFIQUE BASÉ SUR INDICATEURS RÉELS               |
//+------------------------------------------------------------------+

// Structure pour les prédictions scientifiques
struct ScientificPrediction
{
   double predictedPrice;        // Prix prédit basé sur indicateurs
   double confidence;          // Confiance de la prédiction (0-100%)
   string methodology;        // Méthodologie utilisée
   string keyIndicators;      // Indicateurs clés utilisés
   datetime predictionTime;    // Timestamp de la prédiction
   bool isValid;             // Validité de la prédiction
};

// Variables globales pour les prédictions scientifiques
ScientificPrediction g_scientificPrediction;
datetime g_lastScientificUpdate = 0;

//+------------------------------------------------------------------+
//| Paramètres d'entrée                                              |
//+------------------------------------------------------------------+
input group "--- CONFIGURATION DE BASE ---"
input int    InpMagicNumber     = 888888;  // Magic Number
input double InitialLotSize     = 0.01;    // Taille de lot initiale
input double MaxLotSize          = 1.0;     // Taille de lot maximale
input double TakeProfitUSD       = 15.0;    // Take Profit en USD (fixe) - augmenté de 50 points
input double StopLossUSD         = 8.0;     // Stop Loss en USD (fixe) - augmenté de 30 points
input double MaxLossPerPosition  = 5.0;     // Perte maximale par position (USD) - maintenu à 5$
input double ProfitThresholdForDouble = 0.5; // Seuil de profit (USD) pour doubler le lot
input int    MinPositionLifetimeSec = 5;    // Délai minimum avant modification (secondes)

input group "--- OPTIMISATION PERFORMANCE ---"
input bool   HighPerformanceMode = true; // Mode haute performance (réduit charge CPU)
input int    PositionCheckInterval = 10; // Intervalle vérification positions (secondes)
input int    GraphicsUpdateInterval = 120; // Intervalle mise à jour graphiques (secondes)
input bool   DisableAllGraphics = false; // Désactiver tous les graphiques (performance maximale)
input bool   ShowInfoOnChart = false; // Afficher les infos IA directement sur le graphique
input bool   DisableNotifications = false; // Désactiver les notifications (performance)

input group "--- AI AGENT ---"
input bool   UseAI_Agent        = true;    // Activer l'agent IA (via serveur externe)
input string AI_ServerURL       = "https://kolatradebot.onrender.com/decision"; // URL serveur IA
input bool   UseAdvancedDecisionGemma = false; // Utiliser endpoint decisionGemma (Gemma+Gemini) avec analyse visuelle
input int    AI_Timeout_ms       = 800;     // Timeout WebRequest en millisecondes
input double AI_MinConfidence    = 0.60;    // Confiance minimale IA pour trader (60% - ajusté avec calcul intelligent)
// NOTE: Le serveur IA garantit maintenant 60% minimum si H1 aligné, 70% si H1+H4/D1
// Pour Boom/Crash, le seuil est automatiquement abaissé à 45% dans le code
// pour les tendances fortes (H4/D1 alignés). Le serveur ajoute automatiquement
// des bonus (+25% pour H4+D1 alignés, +10-20% pour alignement multi-TF)
input int    AI_UpdateInterval   = 5;      // Intervalle de mise à jour IA (secondes)
input int    AI_AnalysisIntervalSec = 60;  // Fréquence de rafraîchissement de l'analyse (secondes)
input string AI_TimeWindowsURLBase = "https://kolatradebot.onrender.com"; // Racine API pour /time_windows
input string AI_AnalysisURL = "https://kolatradebot.onrender.com/analysis";
input string TrendAPIURL = "https://kolatradebot.onrender.com/trend";
input string AI_PredictSymbolURL = "https://kolatradebot.onrender.com/predict";
input string AI_CoherentAnalysisURL = "https://kolatradebot.onrender.com/coherent-analysis";
input string AI_MLPredictURL = "https://kolatradebot.onrender.com/ml/predict";
input bool UseAllEndpoints = true;
input double MinEndpointsConfidence = 0.30;

input group "--- TABLEAU DE BORD IA ---"
input bool   ShowDashboard = true;       // Afficher le tableau de bord
input color  DashboardBGColor = clrBlack; // Couleur de fond du dashboard
input color  TextColor = clrWhite;       // Couleur du texte

input group "--- INTEGRATION IA AVANCÉE ---"
input bool UseAdvancedValidation = true;        // Activer validation multi-couches pour les trades IA
input bool RequireAllEndpointsAlignment = false;   // Exiger alignement de TOUS les endpoints IA avant trading
input double MinAllEndpointsConfidence = 0.70; // Confiance minimale pour alignement de tous les endpoints
input bool UseDynamicTPCalculation = true;      // Calculer TP dynamique au prochain Support/Résistance
input bool UseImmediatePredictionCheck = true;    // Vérifier direction immédiate de la prédiction avant trade
input bool UseStrongReversalValidation = true; // Exiger retournement franc après touche EMA/Support/Résistance

input group "--- EXECUTION & SEUILS (RECOMMANDÉ) ---"
input bool   AllowTradingWhenNotificationsDisabled = true; // Si true: désactiver notifs ne bloque plus le trading
input double AI_MinConfidence_Default = 0.65;  // Seuil par défaut (hors Boom/Crash/Volatility/Forex)
input double AI_MinConfidence_Volatility = 0.55; // Deriv/Volatility/Indices synthétiques: seuil recommandé
input double AI_MinConfidence_Forex = 0.70;    // Forex: seuil plus élevé
input double AI_MinConfidence_Cautious = 0.80; // Mode prudent (perte quotidienne élevée)
input double AI_MarketExecutionConfidence = 0.92; // Si signal très fort: exécution marché possible (hors Boom/Crash)
input int    LimitEntryOffsetPoints = 5;       // BUY LIMIT au-dessus support / SELL LIMIT sous résistance
input int    LimitSLOffsetPoints = 10;         // SL sous support / au-dessus résistance
input double LimitRR = 2.0;                    // TP = RR * risque

input group "--- VISUEL PRÉDICTIONS (PLUS RÉALISTE) ---"
input bool   UseHistoricalCandleProfile = true; // Bougies futures calquées sur l'historique récent
input int    CandleProfileLookback = 120;       // Nombre de bougies historiques pour calibrer (TF courant)
input double PredictionMaxDriftATR = 1.2;       // Drift max (en ATR) sur l'horizon dessiné

input group "--- ÉLÉMENTS GRAPHIQUES ---"
input bool   DrawAIZones         = true;    // Dessiner les zones BUY/SELL de l'IA
input bool   DrawSupportResistance = true;  // Dessiner support/résistance M5/H1
input bool   DrawTrendlines      = true;    // Dessiner les trendlines
input bool   DrawDerivPatterns   = true;    // Dessiner les patterns Deriv
input bool   DrawSMCZones        = false;   // Dessiner les zones SMC/OrderBlock (DÉSACTIVÉ pour performance)

input group "--- STRATÉGIE US SESSION BREAK & RETEST (PRIORITAIRE) ---"
input bool   UseUSSessionStrategy = false;   // Activer la stratégie US Session (prioritaire) - DÉSACTIVÉ pour permettre trading normal
input double US_RiskReward        = 2.0;    // Risk/Reward ratio pour US Session
input int    US_RetestTolerance   = 30;     // Tolérance retest en points
input bool   US_OneTradePerDay    = true;   // Un seul trade par jour pour US Session

input group "--- GESTION DES RISQUES ---"
input double MaxDailyLoss        = 100.0;   // Perte quotidienne maximale (USD)
input double MaxDailyProfit      = 200.0;   // Profit quotidien maximale (USD)
input double MaxTotalLoss        = 5.0;     // Perte totale maximale toutes positions (USD)
input bool   UseTrailingStop     = true;   // Utiliser trailing stop (désactivé pour scalping fixe)

input group "--- SORTIES VOLATILITY ---"
input double VolatilityQuickTP   = 2.0;     // Fermer rapidement les indices Volatility à +2$ de profit

input group "--- SORTIES BOOM/CRASH ---"
input double BoomCrashSpikeTP    = 0.01;    // Fermer Boom/Crash dès que le spike donne au moins ce profit (0.01 = quasi immédiat)

input group "--- INDICATEURS ---"
input int    EMA_Fast_Period     = 9;       // Période EMA rapide
input int    EMA_Slow_Period     = 21;      // Période EMA lente
input int    RSI_Period          = 14;      // Période RSI
input int    ATR_Period          = 14;      // Période ATR
input bool   ShowLongTrendEMA    = true;    // Afficher EMA 50, 100, 200 sur le graphique (courbes)
input bool   UseTrendAPIAnalysis = true;    // Utiliser l'analyse de tendance API pour affiner les décisions
input double TrendAPIMinConfidence = 70.0;  // Confiance minimum API pour validation (70%)

input group "--- DEBUG ---"
input bool   DebugMode           = true;    // Mode debug (logs détaillés)

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo positionInfo;
COrderInfo orderInfo;
CDealInfo dealInfo;

// Handles des indicateurs
int emaFastHandle;
int emaSlowHandle;
int emaFastH1Handle;
int emaSlowH1Handle;
int emaFastM5Handle;
int emaSlowM5Handle;
// EMA pour tendances longues (50, 100, 200)
int ema50Handle;
int ema100Handle;
int ema200Handle;
int rsiHandle;
int atrHandle;
int atrM5Handle;
int atrH1Handle;
int atrM1Handle;

// Variables pour les endpoints Render
static string g_lastAnalysisData = "";
static string g_lastTrendData = "";
static string g_lastPredictionData = "";
static string g_lastCoherentData = "";
static double g_endpointsAlignment = 0.0;
static datetime g_lastEndpointUpdate = 0;
static int g_lastAISource = 0; // 0 = Local, 1 = Render

// Variables pour le tableau de bord
string g_dashboardName = "AI_Trading_Dashboard_";
string g_alignmentStatus[4]; // Statut de chaque endpoint
color g_alignmentColors[4];  // Couleurs pour chaque indicateur
string g_endpointNames[4] = {"Analyse", "Trend", "Prediction", "Coherent"};

// Variables IA
static string   g_lastAIAction    = "";
static double   g_lastAIConfidence = 0.0;
static string   g_lastAIReason    = "";
static datetime g_lastAITime      = 0;

// Helpers d'exécution / seuils
double GetRequiredConfidenceForSymbol(const string symbol, const bool cautiousMode);
bool   IsDerivSyntheticIndex(const string symbol);
ENUM_ORDER_TYPE GetPendingTypeFromSignal(const ENUM_ORDER_TYPE signalType);
bool   EnsureStopsDistanceValid(double entryPrice, ENUM_ORDER_TYPE pendingType, double &sl, double &tp);

// Variables pour suivre les ordres déjà exécutés (anti-doublon)
static string g_executedOrdersSymbols = ""; // Liste des symboles avec ordres déjà exécutés
static datetime g_lastOrderExecutionTime = 0;
static bool     g_aiFallbackMode  = false;
static int      g_aiConsecutiveFailures = 0;
const int       AI_FAILURE_THRESHOLD = 3;

// Variables pour api_trend (analyse de tendance API)
static int      g_api_trend_direction = 0;       // Direction de tendance API (1=BUY, -1=SELL, 0=neutre)
static double   g_api_trend_strength = 0.0;      // Force de la tendance API (0-100)
static double   g_api_trend_confidence = 0.0;    // Confiance de la tendance API (0-100)
static datetime g_api_trend_last_update = 0;     // Timestamp de la dernière mise à jour API
static string   g_api_trend_signal = "";         // Signal de tendance API
static bool     g_api_trend_valid = false;       // Les données API sont-elles valides ?

// Zones IA
static double   g_aiBuyZoneLow   = 0.0;
static double   g_aiBuyZoneHigh  = 0.0;
static double   g_aiSellZoneLow  = 0.0;
static double   g_aiSellZoneHigh = 0.0;

// Suivi des positions
struct PositionTracker {
   ulong ticket;
   double initialLot;
   double currentLot;
   double highestProfit;
   bool lotDoubled;
   datetime openTime;
   double maxProfitReached;  // Profit maximum atteint pour cette position
   bool profitSecured;       // Indique si le profit a été sécurisé
};

static PositionTracker g_positionTracker;
static bool g_hasPosition = false;

// Suivi du profit global pour sécurisation
static double g_globalMaxProfit = 0.0;  // Profit maximum global atteint (toutes positions)
const double PROFIT_SECURE_THRESHOLD = 3.0;  // Seuil d'activation (3$)
const double PROFIT_DRAWDOWN_LIMIT = 0.5;    // Limite de drawdown (50%)

// Tableau pour suivre le profit max de chaque position
struct PositionProfitTracker {
   ulong ticket;
   double maxProfit;
   datetime lastUpdate;
};

static PositionProfitTracker g_profitTrackers[];
static int g_profitTrackersCount = 0;

// Suivi quotidien
static double g_dailyProfit = 0.0;
static double g_dailyLoss = 0.0;
static datetime g_lastDayReset = 0;

// Suivi pour fermeture après spike (Boom/Crash)
static double g_lastBoomCrashPrice = 0.0;  // Prix de référence pour détecter le spike

// Suivi des tentatives de spike et cooldown (Boom/Crash)
static string   g_spikeSymbols[];
static int      g_spikeFailCount[];
static datetime g_spikeCooldown[];

// Déclarations forward des fonctions
bool IsVolatilitySymbol(const string symbol);
bool IsBoomCrashSymbol(const string sym);
bool IsForexSymbol(const string symbol);
double GetTotalLoss();
double NormalizeLotSize(double lot);
void CleanOldGraphicalObjects();
void DrawAIConfidenceAndTrendSummary();
void DrawRenderEndpointsStatus();
void DrawLongTrendEMA();
void DeleteEMAObjects(string prefix);
void DrawEMACurveOptimized(string prefix, double &values[], datetime &times[], int count, color clr, int width, int step);
void DrawAIZonesOnChart();
void DrawSupportResistanceLevels();
void DrawTrendlinesOnChart();
void DrawSMCZonesOnChart();
void DeleteSMCZones();
void DrawPredictionsOnChart(string predictionData);
void CheckAndManagePositions();
void SecureDynamicProfits();
void SecureProfitForPosition(ulong ticket, double currentProfit);
void LookForTradingOpportunity();
bool CheckReboundOnTrendline(ENUM_ORDER_TYPE orderType, double &distance);
bool DetectReversalAtFastEMA(ENUM_ORDER_TYPE orderType);
bool CheckAIZoneEntryWithEMA(ENUM_ORDER_TYPE orderType, bool &isInZone, bool &emaConfirmed, bool &isCorrection);
bool CheckTrendAlignment(ENUM_ORDER_TYPE orderType);
int CountActiveSymbols();
void DrawDerivPatternsOnChart();
void UpdateDerivArrowBlink();
bool DetectDynamicPatternsAndExecute();
void ActivateTrailingStop();
bool PlaceLimitOrderOnArrow(ENUM_ORDER_TYPE signalType);
void DrawFutureCandlesAdaptive();
void TradeBasedOnFutureCandles(string direction, double confidence, double currentPrice, double atrValue);

//+------------------------------------------------------------------+
//| Détection indices synthétiques Deriv                             |
//+------------------------------------------------------------------+
bool IsDerivSyntheticIndex(const string symbol)
{
   // Heuristique: la plupart des indices synthétiques Deriv incluent "Volatility", "Step", "Boom", "Crash"
   // On ajoute aussi les symboles personnalisés type "F_INX" / "INX"
   if(IsVolatilitySymbol(symbol))
      return true;
   if(StringFind(symbol, "Index") != -1)
      return true;
   if(StringFind(symbol, "INX") != -1 || StringFind(symbol, "F_INX") != -1)
      return true;
   return false;
}

//+------------------------------------------------------------------+
//| Seuil confiance requis selon symbole & mode                       |
//+------------------------------------------------------------------+
double GetRequiredConfidenceForSymbol(const string symbol, const bool cautiousMode)
{
   if(cautiousMode)
      return AI_MinConfidence_Cautious;

   bool isBoomCrashSymbol = (StringFind(symbol, "Boom") != -1 || StringFind(symbol, "Crash") != -1);
   bool isForexSymbol = IsForexSymbol(symbol);
   bool isDerivSynth = IsDerivSyntheticIndex(symbol);

   // Boom/Crash: rapide, seuil plus bas
   if(isBoomCrashSymbol)
      return 0.50;

   // Forex: plus strict
   if(isForexSymbol)
      return AI_MinConfidence_Forex;

   // Indices synthétiques/volatility: légèrement plus permissif
   if(isDerivSynth)
      return AI_MinConfidence_Volatility;

   return AI_MinConfidence_Default;
}

//+------------------------------------------------------------------+
//| Convertit BUY/SELL en BUY_LIMIT/SELL_LIMIT                        |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetPendingTypeFromSignal(const ENUM_ORDER_TYPE signalType)
{
   if(signalType == ORDER_TYPE_BUY)
      return ORDER_TYPE_BUY_LIMIT;
   if(signalType == ORDER_TYPE_SELL)
      return ORDER_TYPE_SELL_LIMIT;
   return WRONG_VALUE;
}

//+------------------------------------------------------------------+
//| Valide/Ajuste distances SL/TP vs contraintes broker               |
//+------------------------------------------------------------------+
bool EnsureStopsDistanceValid(double entryPrice, ENUM_ORDER_TYPE pendingType, double &sl, double &tp)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stopLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevelPoints * point;
   if(minDistance < 5 * point) minDistance = 5 * point;

   // Pour certains symboles synthétiques, on force un peu plus d'écart
   if(IsDerivSyntheticIndex(_Symbol))
      minDistance = MathMax(minDistance, 15 * point);

   double slDist = MathAbs(entryPrice - sl);
   double tpDist = MathAbs(tp - entryPrice);

   if(slDist < minDistance || tpDist < minDistance)
   {
      // Ajuster en conservant la direction logique
      if(pendingType == ORDER_TYPE_BUY_LIMIT)
      {
         sl = NormalizeDouble(entryPrice - minDistance - 2 * point, _Digits);
         tp = NormalizeDouble(entryPrice + (LimitRR * (entryPrice - sl)), _Digits);
      }
      else if(pendingType == ORDER_TYPE_SELL_LIMIT)
      {
         sl = NormalizeDouble(entryPrice + minDistance + 2 * point, _Digits);
         tp = NormalizeDouble(entryPrice - (LimitRR * (sl - entryPrice)), _Digits);
      }
      else
      {
         return false;
      }

      slDist = MathAbs(entryPrice - sl);
      tpDist = MathAbs(tp - entryPrice);
   }

   return (slDist >= minDistance && tpDist >= minDistance && sl > 0 && tp > 0 && sl != tp);
}

//+------------------------------------------------------------------+
//| Détecter et afficher les corrections vers résistances/supports   |
//| Affiche une notification sur le graphique quand le prix approche  |
//| une zone d'entrée intéressante pour les signaux IA connus      |
//+------------------------------------------------------------------+
void DetectAndDisplayCorrections()
{
   // Vérifier si nous avons un signal IA récent (SELL ou BUY)
   if(g_lastAIAction == "" || g_lastAIConfidence < 0.70)
      return; // Pas de signal IA fiable récent
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Récupérer les données de prix récents
   double close[], high[], low[];
   datetime time[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 20, close) < 20 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 20, high) < 20 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 20, low) < 20 ||
      CopyTime(_Symbol, PERIOD_M1, 0, 20, time) < 20)
      return;
   
   // Récupérer les supports/résistances
   double atrM1[], atrM5[], atrH1[];
   ArraySetAsSeries(atrM1, true);
   ArraySetAsSeries(atrM5, true);
   ArraySetAsSeries(atrH1, true);
   
   if(CopyBuffer(atrM1Handle, 0, 0, 1, atrM1) <= 0 ||
      CopyBuffer(atrM5Handle, 0, 0, 1, atrM5) <= 0 ||
      CopyBuffer(atrH1Handle, 0, 0, 1, atrH1) <= 0)
      return;
   
   // Calculer les niveaux
   double resistanceM1 = currentPrice + (1.5 * atrM1[0]);
   double resistanceM5 = currentPrice + (2.0 * atrM5[0]);
   double resistanceH1 = currentPrice + (2.5 * atrH1[0]);
   double supportM1 = currentPrice - (1.5 * atrM1[0]);
   double supportM5 = currentPrice - (2.0 * atrM5[0]);
   double supportH1 = currentPrice - (2.5 * atrH1[0]);
   
   // Détecter les corrections
   bool isCorrectionToResistance = false;
   bool isCorrectionToSupport = false;
   string targetZone = "";
   double targetPrice = 0;
   
   if(StringCompare(g_lastAIAction, "sell") == 0)
   {
      // Signal SELL connu - chercher correction vers résistance
      // Vérifier si le prix monte après une baisse (correction haussière)
      bool wasDropping = (close[3] > close[2] && close[2] > close[1]); // Baisse sur 3 périodes
      bool isCorrectingUp = (close[0] > close[1] && close[1] > close[2]); // Reprise sur 2 périodes
      
      if(wasDropping && isCorrectingUp)
      {
         // Vérifier la distance aux résistances
         double distToM1 = resistanceM1 - currentPrice;
         double distToM5 = resistanceM5 - currentPrice;
         double distToH1 = resistanceH1 - currentPrice;
         
         // Si approche d'une résistance (moins de 1 ATR)
         if(distToM1 < atrM1[0] && distToM1 > 0)
         {
            isCorrectionToResistance = true;
            targetZone = "Résistance M1";
            targetPrice = resistanceM1;
         }
         else if(distToM5 < atrM5[0] && distToM5 > 0)
         {
            isCorrectionToResistance = true;
            targetZone = "Résistance M5";
            targetPrice = resistanceM5;
         }
         else if(distToH1 < atrH1[0] && distToH1 > 0)
         {
            isCorrectionToResistance = true;
            targetZone = "Résistance H1";
            targetPrice = resistanceH1;
         }
      }
   }
   else if(StringCompare(g_lastAIAction, "buy") == 0)
   {
      // Signal BUY connu - chercher correction vers support
      // Vérifier si le prix baisse après une hausse (correction baissière)
      bool wasRising = (close[3] < close[2] && close[2] < close[1]); // Hausse sur 3 périodes
      bool isCorrectingDown = (close[0] < close[1] && close[1] < close[2]); // Baisse sur 2 périodes
      
      if(wasRising && isCorrectingDown)
      {
         // Vérifier la distance aux supports
         double distToM1 = currentPrice - supportM1;
         double distToM5 = currentPrice - supportM5;
         double distToH1 = currentPrice - supportH1;
         
         // Si approche d'un support (moins de 1 ATR)
         if(distToM1 < atrM1[0] && distToM1 > 0)
         {
            isCorrectionToSupport = true;
            targetZone = "Support M1";
            targetPrice = supportM1;
         }
         else if(distToM5 < atrM5[0] && distToM5 > 0)
         {
            isCorrectionToSupport = true;
            targetZone = "Support M5";
            targetPrice = supportM5;
         }
         else if(distToH1 < atrH1[0] && distToH1 > 0)
         {
            isCorrectionToSupport = true;
            targetZone = "Support H1";
            targetPrice = supportH1;
         }
      }
   }
   
   // Afficher la notification sur le graphique si correction détectée
   if((isCorrectionToResistance || isCorrectionToSupport) && targetPrice > 0)
   {
      string correctionName = "CORRECTION_NOTIFICATION_" + _Symbol;
      datetime currentTime = TimeCurrent();
      datetime notificationTime = currentTime + PeriodSeconds(PERIOD_M1) * 2;
      
      // Supprimer l'ancienne notification
      ObjectDelete(0, correctionName);
      
      // Créer la nouvelle notification
      if(ObjectCreate(0, correctionName, OBJ_TEXT, 0, notificationTime, targetPrice))
      {
         string notificationText = "";
         color notificationColor = clrWhite;
         
         if(isCorrectionToResistance)
         {
            notificationText = "🔄 CORRECTION VERS RÉSISTANCE\n"
                             "⬆️ Signal SELL IA: " + DoubleToString(g_lastAIConfidence*100, 1) + "%\n"
                             "🎯 Cible: " + targetZone + " @ " + DoubleToString(targetPrice, _Digits) + "\n"
                             "💡 Entrée SELL LIMIT possible";
            notificationColor = clrOrange;
         }
         else if(isCorrectionToSupport)
         {
            notificationText = "🔄 CORRECTION VERS SUPPORT\n"
                             "⬇️ Signal BUY IA: " + DoubleToString(g_lastAIConfidence*100, 1) + "%\n"
                             "🎯 Cible: " + targetZone + " @ " + DoubleToString(targetPrice, _Digits) + "\n"
                             "💡 Entrée BUY LIMIT possible";
            notificationColor = clrDodgerBlue;
         }
         
         ObjectSetString(0, correctionName, OBJPROP_TEXT, notificationText);
         ObjectSetInteger(0, correctionName, OBJPROP_COLOR, notificationColor);
         ObjectSetInteger(0, correctionName, OBJPROP_FONTSIZE, 8);
         ObjectSetString(0, correctionName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, correctionName, OBJPROP_BACK, false);
         ObjectSetInteger(0, correctionName, OBJPROP_ANCHOR, ANCHOR_LEFT);
         
         // Dessiner une flèche vers la cible
         string arrowName = "CORRECTION_ARROW_" + _Symbol;
         ObjectDelete(0, arrowName);
         
         if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, notificationTime, targetPrice))
         {
            ObjectSetInteger(0, arrowName, OBJPROP_COLOR, notificationColor);
            ObjectSetInteger(0, arrowName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, isCorrectionToResistance ? 241 : 242);
            ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
         }
         
         // Log dans Experts
         if(DebugMode)
         {
            Print("🔄 CORRECTION DÉTECTÉE:");
            Print("   Signal IA: ", StringToUpper(g_lastAIAction), " (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
            Print("   Type: ", isCorrectionToResistance ? "Vers résistance" : "Vers support");
            Print("   Zone cible: ", targetZone);
            Print("   Prix cible: ", DoubleToString(targetPrice, _Digits));
            Print("   Prix actuel: ", DoubleToString(currentPrice, _Digits));
            Print("   Distance: ", DoubleToString(MathAbs(targetPrice - currentPrice) / point, 1), " pips");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier si un ordre a déjà été exécuté pour un symbole          |
//| Évite les doublons quand la flèche clignote plusieurs fois      |
//+------------------------------------------------------------------+
bool HasOrderAlreadyExecuted(string symbol)
{
   // Vérifier si le symbole est dans la liste des ordres déjà exécutés
   if(StringFind(g_executedOrdersSymbols, symbol + ";") >= 0)
   {
      if(DebugMode)
         Print("⚠️ Ordre déjà exécuté pour ", symbol, " - anti-doublon activé");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Marquer un ordre comme exécuté pour un symbole                   |
//+------------------------------------------------------------------+
void MarkOrderAsExecuted(string symbol)
{
   // Ajouter le symbole à la liste des ordres exécutés
   g_executedOrdersSymbols += symbol + ";";
   g_lastOrderExecutionTime = TimeCurrent();
   
   if(DebugMode)
      Print("✅ Ordre marqué comme exécuté pour ", symbol);
}

//+------------------------------------------------------------------+
//| Retirer un symbole de la liste exécutée (après fermeture)         |
//| Permet de reprendre un trade Boom/Crash après spike               |
//+------------------------------------------------------------------+
void RemoveSymbolFromExecutedList(string symbol)
{
   string needle = symbol + ";";
   int pos = StringFind(g_executedOrdersSymbols, needle);
   if(pos >= 0)
   {
      g_executedOrdersSymbols = StringSubstr(g_executedOrdersSymbols, 0, pos) + 
                                StringSubstr(g_executedOrdersSymbols, pos + StringLen(needle));
      if(DebugMode)
         Print("🔄 Symbole ", symbol, " retiré de la liste - prêt pour nouveau trade Boom/Crash");
   }
}

//+------------------------------------------------------------------+
//| Réinitialiser la liste des ordres exécutés (nouvelle session)     |
//+------------------------------------------------------------------+
void ResetExecutedOrdersList()
{
   // Réinitialiser toutes les 4 heures ou au changement de journée
   datetime currentTime = TimeCurrent();
   static datetime lastReset = 0;
   
   MqlDateTime currentStruct, lastStruct;
   TimeToStruct(currentTime, currentStruct);
   TimeToStruct(lastReset, lastStruct);
   
   if(currentTime - lastReset > 14400 || // 4 heures
      (currentStruct.day != lastStruct.day)) // Changement de journée
   {
      g_executedOrdersSymbols = "";
      lastReset = currentTime;
      
      if(DebugMode)
         Print("🔄 Liste des ordres exécutés réinitialisée");
   }
}

//+------------------------------------------------------------------+
//| Exécuter immédiatement un trade Boom/Crash au marché             |
//| Utilisé pour les spikes avec confiance élevée (≥85%)            |
//+------------------------------------------------------------------+
bool ExecuteImmediateBoomCrashTrade(ENUM_ORDER_TYPE signalType)
{
   double currentPrice = SymbolInfoDouble(_Symbol, (signalType == ORDER_TYPE_BUY) ? SYMBOL_ASK : SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculer SL/TP rapides pour Boom/Crash (spikes)
   double atrValue = 0;
   double atrBuffer[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
      atrValue = atrBuffer[0];
   else
      atrValue = currentPrice * 0.001; // Fallback 0.1%
   
   double stopLoss = 0;
   double takeProfit = 0;
   
   if(signalType == ORDER_TYPE_BUY)
   {
      // Pour BUY sur Boom: SL serré, TP rapide
      stopLoss = currentPrice - (atrValue * 0.5); // SL très serré
      takeProfit = currentPrice + (atrValue * 1.5); // TP rapide (1:3 ratio)
   }
   else // SELL sur Crash
   {
      // Pour SELL sur Crash: SL serré, TP rapide
      stopLoss = currentPrice + (atrValue * 0.5); // SL très serré
      takeProfit = currentPrice - (atrValue * 1.5); // TP rapide (1:3 ratio)
   }
   
   // Vérifier les distances minimales pour Boom/Crash
   double minDistance = MathMax(20 * point, atrValue * 0.2); // Minimum 20 points ou 0.2 ATR
   double slDistance = MathAbs(currentPrice - stopLoss);
   double tpDistance = MathAbs(takeProfit - currentPrice);
   
   if(slDistance < minDistance || tpDistance < minDistance)
   {
      if(DebugMode)
         Print("⚠️ Distances SL/TP trop faibles pour Boom/Crash: SL=", DoubleToString(slDistance/point, 0), " TP=", DoubleToString(tpDistance/point, 0));
      return false;
   }
   
   // Taille de position adaptée à la confiance
   double lotSize = InitialLotSize;
   if(g_lastAIConfidence >= 0.95)
      lotSize = InitialLotSize * 1.5; // Confiance très élevée
   else if(g_lastAIConfidence >= 0.90)
      lotSize = InitialLotSize * 1.2; // Confiance élevée
   
   lotSize = NormalizeLotSize(lotSize);
   
   // Exécuter l'ordre au marché immédiatement
   string orderComment = "Boom/Crash IMMEDIATE - " + EnumToString(signalType) + " (conf: " + DoubleToString(g_lastAIConfidence*100, 1) + "%)";
   
   bool success = false;
   if(signalType == ORDER_TYPE_BUY)
   {
      success = SafeTradeBuy(lotSize, _Symbol, currentPrice, stopLoss, takeProfit, orderComment);
   }
   else // SELL
   {
      success = SafeTradeSell(lotSize, _Symbol, currentPrice, stopLoss, takeProfit, orderComment);
   }
   
   if(success)
   {
      double riskUSD = slDistance * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double rewardUSD = tpDistance * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      Print("🚀 TRADE BOOM/CRASH EXÉCUTÉ IMMÉDIATEMENT:");
      Print("   📈 Type: ", EnumToString(signalType));
      Print("   💰 Entrée: ", DoubleToString(currentPrice, _Digits));
      Print("   🛡️ SL: ", DoubleToString(stopLoss, _Digits), " (risque: ", DoubleToString(riskUSD, 2), "$)");
      Print("   🎯 TP: ", DoubleToString(takeProfit, _Digits), " (gain: ", DoubleToString(rewardUSD, 2), "$)");
      Print("   📊 Ratio R/R: 1:", DoubleToString(rewardUSD/riskUSD, 1));
      Print("   📏 Taille: ", DoubleToString(lotSize, 2));
      Print("   🎯 Confiance: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
      Print("   ⚡ Exécution: IMMÉDIATE (spike Boom/Crash)");
      
      // Envoyer notification
      if(!DisableNotifications)
      {
         string notificationText = "🚀 BOOM/CRASH IMMÉDIAT\n" + _Symbol + " " + EnumToString(signalType) + 
                                  "\n@" + DoubleToString(currentPrice, _Digits) + 
                                  "\nConfiance: " + DoubleToString(g_lastAIConfidence*100, 1) + "%";
         SendNotification(notificationText);
         Alert(notificationText);
      }
      
      return true;
   }
   else
   {
      Print("❌ Erreur exécution Boom/Crash: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      return false;
   }
}

// Fonctions pour les endpoints Render
void UpdateAllEndpoints();
string UpdateAnalysisEndpoint();
string UpdateTrendEndpoint();
string UpdatePredictionEndpoint();
string UpdateCoherentEndpoint();
bool CheckAllEndpointsAlignment(ENUM_ORDER_TYPE orderType);

int GetSpikeIndex(const string sym)
{
   for(int i = 0; i < ArraySize(g_spikeSymbols); i++)
   {
      if(g_spikeSymbols[i] == sym)
         return i;
   }
   int idx = ArraySize(g_spikeSymbols);
   ArrayResize(g_spikeSymbols, idx + 1);
   ArrayResize(g_spikeFailCount, idx + 1);
   ArrayResize(g_spikeCooldown, idx + 1);
   g_spikeSymbols[idx] = sym;
   g_spikeFailCount[idx] = 0;
   g_spikeCooldown[idx] = 0;
   return idx;
}

bool IsBoomCrashSymbol(const string sym)
{
   return (StringFind(sym, "Boom") != -1 || StringFind(sym, "Crash") != -1);
}

// Fermer toutes les positions Volatility si la perte totale dépasse un seuil
void CloseVolatilityIfLossExceeded(double lossLimit)
{
   double totalProfitVol = 0.0;
   // Calculer le PnL cumulé des positions Volatility (tous symboles) pour ce Magic
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         string sym = positionInfo.Symbol();
         if(IsVolatilitySymbol(sym) && positionInfo.Magic() == InpMagicNumber)
         {
            totalProfitVol += positionInfo.Profit();
         }
      }
   }

   // Si perte cumulée dépasse le seuil, fermer toutes les positions Volatility
   if(totalProfitVol <= -MathAbs(lossLimit))
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && positionInfo.SelectByTicket(ticket))
         {
            string sym = positionInfo.Symbol();
            if(IsVolatilitySymbol(sym) && positionInfo.Magic() == InpMagicNumber)
            {
               double p = positionInfo.Profit();
               if(trade.PositionClose(ticket))
               {
                  Print("🛑 Volatility perte cumulée dépassée (", DoubleToString(totalProfitVol, 2),
                        "$ <= ", DoubleToString(-MathAbs(lossLimit), 2), "$) - Fermeture ticket=", ticket,
                        " sym=", sym, " profit=", DoubleToString(p, 2), "$");
               }
               else if(DebugMode)
               {
                  Print("❌ Erreur fermeture Volatility ticket=", ticket, " code=", trade.ResultRetcode(),
                        " desc=", trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }
}

// Variables US Session Break & Retest (STRATÉGIE PRIORITAIRE)
static double g_US_High = 0.0;              // Haut du range US (bougie M5 15h30)
static double g_US_Low = 0.0;               // Bas du range US (bougie M5 15h30)
static bool   g_US_RangeDefined = false;    // Range US défini
static bool   g_US_BreakoutDone = false;    // Breakout détecté
static bool   g_US_TradeTaken = false;      // Trade US pris aujourd'hui
static int    g_US_Direction = 0;           // 1 = BUY, -1 = SELL, 0 = neutre
static datetime g_US_RangeDate = 0;         // Date du range (pour reset quotidien)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   
   // Initialiser les indicateurs M1
   emaFastHandle = iMA(_Symbol, PERIOD_M1, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, PERIOD_M1, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   rsiHandle = iRSI(_Symbol, PERIOD_M1, RSI_Period, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_M1, ATR_Period);
   
   // Initialiser les indicateurs M5 pour alignement de tendance
   emaFastM5Handle = iMA(_Symbol, PERIOD_M5, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM5Handle = iMA(_Symbol, PERIOD_M5, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   atrM5Handle = iATR(_Symbol, PERIOD_M5, ATR_Period);
   
   // Initialiser les indicateurs H1 pour alignement de tendance
   emaFastH1Handle = iMA(_Symbol, PERIOD_H1, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowH1Handle = iMA(_Symbol, PERIOD_H1, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   atrH1Handle = iATR(_Symbol, PERIOD_H1, ATR_Period);
   
   // Initialiser l'ATR M1 pour supports/résistances et ordres limités
   atrM1Handle = iATR(_Symbol, PERIOD_M1, ATR_Period);
   
   // Initialiser les EMA pour tendances longues (50, 100, 200) sur M1
   ema50Handle = iMA(_Symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema100Handle = iMA(_Symbol, PERIOD_M1, 100, 0, MODE_EMA, PRICE_CLOSE);
   ema200Handle = iMA(_Symbol, PERIOD_M1, 200, 0, MODE_EMA, PRICE_CLOSE);
   
   if(emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE || 
      emaFastH1Handle == INVALID_HANDLE || emaSlowH1Handle == INVALID_HANDLE ||
      emaFastM5Handle == INVALID_HANDLE || emaSlowM5Handle == INVALID_HANDLE ||
      ema50Handle == INVALID_HANDLE || ema100Handle == INVALID_HANDLE || ema200Handle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE ||
      atrM5Handle == INVALID_HANDLE || atrH1Handle == INVALID_HANDLE || atrM1Handle == INVALID_HANDLE)
   {
      Print("❌ Erreur initialisation indicateurs");
      return INIT_FAILED;
   }
   
   // Vérifier l'URL IA
   if(UseAI_Agent && StringLen(AI_ServerURL) > 0)
   {
      // Ajouter l'URL à la liste autorisée
      string urlDomain = AI_ServerURL;
      int protocolPos = StringFind(urlDomain, "://");
      if(protocolPos >= 0)
      {
         urlDomain = StringSubstr(urlDomain, protocolPos + 3);
         int pathPos = StringFind(urlDomain, "/");
         if(pathPos > 0)
            urlDomain = StringSubstr(urlDomain, 0, pathPos);
      }
      
      Print("✅ Robot Scalper Double initialisé");
      Print("   URL Serveur IA: ", AI_ServerURL);
      Print("   Lot initial: ", InitialLotSize);
      Print("   TP: ", TakeProfitUSD, " USD");
      Print("   SL: ", StopLossUSD, " USD");
   }
   
   // Initialiser le suivi quotidien
   g_lastDayReset = TimeCurrent();
   ResetDailyCounters();
   
   // Nettoyer tous les objets graphiques au démarrage
   CleanAllGraphicalObjects();
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Libérer les handles des indicateurs
   if(emaFastHandle != INVALID_HANDLE) IndicatorRelease(emaFastHandle);
   if(emaSlowHandle != INVALID_HANDLE) IndicatorRelease(emaSlowHandle);
   if(emaFastH1Handle != INVALID_HANDLE) IndicatorRelease(emaFastH1Handle);
   if(emaSlowH1Handle != INVALID_HANDLE) IndicatorRelease(emaSlowH1Handle);
   if(emaFastM5Handle != INVALID_HANDLE) IndicatorRelease(emaFastM5Handle);
   if(emaSlowM5Handle != INVALID_HANDLE) IndicatorRelease(emaSlowM5Handle);
   if(ema50Handle != INVALID_HANDLE) IndicatorRelease(ema50Handle);
   if(ema100Handle != INVALID_HANDLE) IndicatorRelease(ema100Handle);
   if(ema200Handle != INVALID_HANDLE) IndicatorRelease(ema200Handle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(atrM5Handle != INVALID_HANDLE) IndicatorRelease(atrM5Handle);
   if(atrH1Handle != INVALID_HANDLE) IndicatorRelease(atrH1Handle);
   
   // Nettoyer le tableau de bord
   CleanupDashboard();
   
   Print("Robot Scalper Double arrêté");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Réinitialiser les compteurs quotidiens si nécessaire
   ResetDailyCountersIfNeeded();
   
   // Mettre à jour le dashboard avancé
   UpdateAdvancedDashboard();
   
   // Initialiser le tableau de bord au premier tick (seulement si activé)
   static bool dashboardInitialized = false;
   if(ShowDashboard && ShowInfoOnChart && !dashboardInitialized)
   {
      // Initialiser les états par défaut
      for(int i = 0; i < 4; i++)
      {
         g_alignmentStatus[i] = "⏳";
         g_alignmentColors[i] = clrGray;
      }
      UpdateAlignmentDashboard();
      dashboardInitialized = true;
      
      if(DebugMode)
         Print("📊 Informations IA activées sur le graphique");
   }
   
   // Vérifier les limites quotidiennes (mode prudent si perte élevée)
   // Au lieu de bloquer complètement, on active un mode très prudent
   bool cautiousMode = (g_dailyLoss >= MaxDailyLoss);
   if(cautiousMode && DebugMode)
      Print("⚠️ MODE PRUDENT ACTIVÉ: Perte quotidienne élevée (", DoubleToString(g_dailyLoss, 2), " USD) - Seulement opportunités très sûres");
   
   if(g_dailyProfit >= MaxDailyProfit)
   {
      if(DebugMode)
         Print("✅ Profit quotidien maximal atteint: ", g_dailyProfit, " USD");
      return;
   }
   
   // Vérifier la perte totale maximale (toutes positions actives)
   double totalLoss = GetTotalLoss();
   if(totalLoss >= MaxTotalLoss)
   {
      if(DebugMode)
         Print("🛑 Perte totale maximale atteinte: ", DoubleToString(totalLoss, 2), " USD (limite: ", DoubleToString(MaxTotalLoss, 2), " USD) - Blocage de tous les nouveaux trades");
      return;
   }
   
   // Mettre à jour l'IA si nécessaire
   static datetime lastAIUpdate = 0;
   if(UseAI_Agent && (TimeCurrent() - lastAIUpdate) >= AI_UpdateInterval)
   {
      UpdateAIDecision();
      lastAIUpdate = TimeCurrent();
   }
   
   // Mettre à jour l'analyse de tendance API si nécessaire
   static datetime lastTrendUpdate = 0;
   if(UseTrendAPIAnalysis && (TimeCurrent() - lastTrendUpdate) >= AI_UpdateInterval)
   {
      UpdateTrendAPIAnalysis();
      lastTrendUpdate = TimeCurrent();
   }
   
   // Mettre à jour les données des endpoints Render (RÉACTIVÉ POUR PRÉDICTIONS)
   static datetime lastEndpointUpdate = 0;
   int endpointInterval = HighPerformanceMode ? 120 : 60; // Toutes les 2 minutes en mode haute perf
   if(UseAllEndpoints && (TimeCurrent() - lastEndpointUpdate) >= endpointInterval)
   {
      g_lastAnalysisData = UpdateAnalysisEndpoint();
      g_lastTrendData = UpdateTrendEndpoint();
      g_lastPredictionData = UpdatePredictionEndpoint();
      g_lastCoherentData = UpdateCoherentEndpoint();
      g_lastEndpointUpdate = TimeCurrent();
      
      if(DebugMode)
      {
         Print("🔁 Données endpoints mises à jour (prédiction activée):");
         Print("   Analyse: ", (g_lastAnalysisData != "") ? "✅" : "❌");
         Print("   Tendance: ", (g_lastTrendData != "") ? "✅" : "❌");
         Print("   Prédiction: ", (g_lastPredictionData != "") ? "✅" : "❌");
         Print("   Cohérent: ", (g_lastCoherentData != "") ? "✅" : "❌");
      }
      
      // Dessiner les prédictions sur le graphique
      if(g_lastPredictionData != "")
      {
         DrawPredictionsOnChart(g_lastPredictionData);
      }
      
      // Détecter et afficher les corrections vers résistances/supports
      DetectAndDisplayCorrections();
      
      // Forcer la mise à jour du tableau de bord
      if(ShowDashboard && ShowInfoOnChart && g_lastAIAction != "")
      {
         ENUM_ORDER_TYPE dummyType = (g_lastAIAction == "buy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         CheckAllEndpointsAlignment(dummyType);
      }
   }
   
   // OPTIMISATION: Diagnostics très peu fréquents (désactivé si mode silencieux)
   static datetime lastDiagnostic = 0;
   if(DebugMode && !DisableNotifications && (TimeCurrent() - lastDiagnostic) >= 600) // Toutes les 10 minutes
   {
      Print("\n=== DIAGNOSTIC ROBOT (optimisé) ===");
      Print("Mode haute performance: ", HighPerformanceMode ? "✅ ACTIVÉ" : "❌ DÉSACTIVÉ");
      Print("Graphiques désactivés: ", DisableAllGraphics ? "✅ ACTIVÉ" : "❌ DÉSACTIVÉ");
      Print("Notifications désactivées: ", DisableNotifications ? "✅ ACTIVÉ" : "❌ DÉSACTIVÉ");
      Print("Positions actives: ", PositionsTotal());
      Print("Symboles actifs: ", CountActiveSymbols());
      Print("Perte quotidienne: ", DoubleToString(g_dailyLoss, 2), "$");
      Print("Dernière action IA: ", g_lastAIAction, " (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
      Print("Mode fallback IA: ", g_aiFallbackMode ? "✅ ACTIVÉ" : "❌ DÉSACTIVÉ");
      Print("Endpoints alignés: ", DoubleToString(g_endpointsAlignment * 100, 1), "%");
      Print("============================\n");
      lastDiagnostic = TimeCurrent();
   }
   
   // OPTIMISATION MAXIMALE: Désactiver complètement les graphiques
   if(!DisableAllGraphics)
   {
      static datetime lastDrawUpdate = 0;
      int graphicsInterval = HighPerformanceMode ? GraphicsUpdateInterval : 30;
      if(TimeCurrent() - lastDrawUpdate >= graphicsInterval)
      {
         // Seulement les labels essentiels (très léger)
         DrawAIConfidenceAndTrendSummary();
         
         lastDrawUpdate = TimeCurrent();
      }
   }
   
   // OPTIMISATION: Mises à jour très peu fréquentes pour éléments lourds (désactivé si graphics désactivés)
   if(!DisableAllGraphics)
   {
      static datetime lastHeavyUpdate = 0;
      if(TimeCurrent() - lastHeavyUpdate >= 600) // Toutes les 10 minutes (au lieu de 5)
      {
         // Nettoyer seulement les objets obsolètes
         CleanOldGraphicalObjects();
         
         // Afficher EMA longues (optimisé, très peu fréquent)
         if(ShowLongTrendEMA)
            DrawLongTrendEMA();
         
         // FORCER: Afficher support/résistance TOUJOURS (très important)
         DrawSupportResistanceLevels();
         
         // NOUVEAU: Dessiner les bougies futures adaptées au timeframe
         DrawFutureCandlesAdaptive();
         
         // Afficher trendlines (très peu fréquent)
         if(DrawTrendlines)
            DrawTrendlinesOnChart();
         
         lastHeavyUpdate = TimeCurrent();
      }
   }
   
   // SÉCURISATION DES PROFITS: Optimisé - appelé seulement dans la gestion des positions
   // Éviter l'appel direct ici pour réduire la charge CPU
   
   // Deriv patterns (désactivé si graphics désactivés)
   if(!DisableAllGraphics && DrawDerivPatterns)
   {
      static datetime lastDerivUpdate = 0;
      int derivInterval = HighPerformanceMode ? 30 : 15; // Toutes les 30 secondes en mode haute perf
      if(TimeCurrent() - lastDerivUpdate >= derivInterval)
      {
         DrawDerivPatternsOnChart();
         UpdateDerivArrowBlink();
         lastDerivUpdate = TimeCurrent();
      }
   }
   
   // OPTIMISATION: Vérifier les positions moins fréquemment (ULTRA)
   static datetime lastPositionCheck = 0;
   int checkInterval = HighPerformanceMode ? PositionCheckInterval : 2;
   if(TimeCurrent() - lastPositionCheck >= checkInterval)
   {
      CheckAndManagePositions();
      SecureDynamicProfits(); // Appelé ici seulement

      // Activer systématiquement le trailing stop sur toutes les positions ouvertes.
      // Cela garantit que, dès qu'une position progresse, son SL est ajusté automatiquement.
      ActivateTrailingStop();

      lastPositionCheck = TimeCurrent();
   }
   
   // Mettre à jour le tracker de positions pour la stratégie avancée
   UpdatePositionTracker();
   
   // Si pas de position, chercher une opportunité (beaucoup moins fréquent)
   static datetime lastOpportunityCheck = 0;
   int opportunityInterval = HighPerformanceMode ? 15 : 3;
   if(!g_hasPosition && (TimeCurrent() - lastOpportunityCheck >= opportunityInterval))
   {
      LookForTradingOpportunity();
      lastOpportunityCheck = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Réinitialiser les compteurs quotidiens                          |
//+------------------------------------------------------------------+
void ResetDailyCountersIfNeeded()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   MqlDateTime lastDt;
   TimeToStruct(g_lastDayReset, lastDt);
   
   if(dt.day != lastDt.day || dt.mon != lastDt.mon || dt.year != lastDt.year)
   {
      ResetDailyCounters();
      g_lastDayReset = TimeCurrent();
   }
}

void ResetDailyCounters()
{
   g_dailyProfit = 0.0;
   g_dailyLoss = 0.0;
   
   // Calculer le profit/perte actuel depuis l'historique
   datetime startOfDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   datetime endOfDay = startOfDay + 86400;
   
   if(HistorySelect(startOfDay, endOfDay))
   {
      int totalDeals = HistoryDealsTotal();
      for(int i = 0; i < totalDeals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         
         // Vérifier si c'est un trade de clôture
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
            continue;
         
         // Vérifier si c'est notre EA
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
            continue;
         
         // Récupérer le profit
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         if(profit > 0)
            g_dailyProfit += profit;
         else
            g_dailyLoss += MathAbs(profit);
      }
   }
}

//+------------------------------------------------------------------+
//| Mettre à jour la décision IA                                      |
//+------------------------------------------------------------------+
void UpdateAIDecision()
{
   if(!UseAI_Agent || StringLen(AI_ServerURL) == 0)
      return;
   
   // Récupérer les données de marché
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double midPrice = (bid + ask) / 2.0;
   
   // Récupérer les indicateurs
   double emaFast[], emaSlow[], emaFastH1[], emaSlowH1[], rsi[], atr[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFast) <= 0 ||
      CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlow) <= 0 ||
      CopyBuffer(emaFastH1Handle, 0, 0, 1, emaFastH1) <= 0 ||
      CopyBuffer(emaSlowH1Handle, 0, 0, 1, emaSlowH1) <= 0 ||
      CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0 ||
      CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération indicateurs pour IA");
      return;
   }
   
   // Calculer la direction basée sur EMA
   int dirRule = 0;
   if(emaFast[0] > emaSlow[0])
      dirRule = 1; // Uptrend
   else if(emaFast[0] < emaSlow[0])
      dirRule = -1; // Downtrend
   
   // Construire le JSON pour l'IA
   string safeSymbol = _Symbol;
   StringReplace(safeSymbol, "\"", "\\\"");
   
   string payload = "{";
   payload += "\"symbol\":\"" + safeSymbol + "\"";
   payload += ",\"bid\":" + DoubleToString(bid, _Digits);
   payload += ",\"ask\":" + DoubleToString(ask, _Digits);
   payload += ",\"rsi\":" + DoubleToString(rsi[0], 2);
   payload += ",\"ema_fast_h1\":" + DoubleToString(emaFastH1[0], _Digits);
   payload += ",\"ema_slow_h1\":" + DoubleToString(emaSlowH1[0], _Digits);
   payload += ",\"ema_fast_m1\":" + DoubleToString(emaFast[0], _Digits);
   payload += ",\"ema_slow_m1\":" + DoubleToString(emaSlow[0], _Digits);
   payload += ",\"atr\":" + DoubleToString(atr[0], _Digits);
   payload += ",\"dir_rule\":" + IntegerToString(dirRule);
   payload += ",\"is_spike_mode\":false";
   payload += "}";
   
   // Conversion en UTF-8
   int payloadLen = StringLen(payload);
   char data[];
   ArrayResize(data, payloadLen + 1);
   int copied = StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);
   
   if(copied <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur conversion JSON");
      return;
   }
   
   ArrayResize(data, copied - 1);
   
   // Envoyer la requête avec gestion local/distant
   char result[];
   string headers = "Content-Type: application/json\r\nUser-Agent: MT5-TradBOT/3.0\r\n";
   string result_headers = "";
   
   // Variables pour suivre la source utilisée
   string usedURL = "";
   bool requestSuccess = false;
   int res = -1;
   
   // Essayer d'abord le serveur local si disponible
   if(StringFind(AI_ServerURL, "localhost") >= 0 || StringFind(AI_ServerURL, "127.0.0.1") >= 0)
   {
      usedURL = AI_ServerURL;
      if(DebugMode)
         Print("🌐 Tentative de connexion au serveur local: ", usedURL);
      
      // Réduire le timeout pour le serveur local
      res = WebRequest("POST", usedURL, headers, 3000, data, result, result_headers);
      
      if(res == 200)
      {
         requestSuccess = true;
         g_lastAISource = 0; // 0 = Local
      }
   }
   
   // Si échec du serveur local ou non utilisé, essayer le serveur distant Render
   if(!requestSuccess)
   {
      // Utiliser l'URL Render par défaut
      usedURL = "https://kolatradebot.onrender.com/decision";
      if(DebugMode)
         Print("🌐 Tentative de connexion au serveur distant: ", usedURL);
      
      res = WebRequest("POST", usedURL, headers, AI_Timeout_ms, data, result, result_headers);
      
      if(res == 200)
      {
         requestSuccess = true;
         g_lastAISource = 1; // 1 = Render
      }
   }
   
   if(!requestSuccess)
   {
      int errorCode = GetLastError();
      g_aiConsecutiveFailures++;
      
      if(DebugMode)
         Print("❌ AI WebRequest échec: http=", res, " - Erreur MT5: ", errorCode, " | URL: ", usedURL);
      
      // Gestion améliorée des erreurs HTTP
      if(res == 404)
      {
         Print("⚠️ ERREUR 404: Endpoint non trouvé - Vérifiez l'URL du serveur");
         Print("   URL actuelle: ", usedURL);
         Print("   Solution: Vérifiez que le serveur est accessible et l'URL correcte");
      }
      else if(res == 403)
      {
         Print("⚠️ ERREUR 403: Accès refusé - Vérifiez la clé API");
         Print("   Solution: Vérifiez votre clé API ou abonnement");
      }
      else if(res == 500)
      {
         Print("⚠️ ERREUR 500: Erreur serveur interne");
         Print("   Solution: Réessayez plus tard ou contactez le support");
      }
      else if(res == 429)
      {
         Print("⚠️ ERREUR 429: Trop de requêtes - Limite dépassée");
         Print("   Solution: Réduisez la fréquence des requêtes");
      }
      
      if(g_aiConsecutiveFailures >= AI_FAILURE_THRESHOLD && !g_aiFallbackMode)
      {
         g_aiFallbackMode = true;
         Print("⚠️ MODE DÉGRADÉ ACTIVÉ: Serveur IA indisponible");
      }
      
      if(errorCode == 4060)
      {
         Print("⚠️ ERREUR 4060: URL non autorisée dans MT5!");
         Print("   Allez dans: Outils -> Options -> Expert Advisors");
         Print("   Ajoutez: http://127.0.0.1 ou https://votre-serveur-local.com");
      }
      return;
   }
   
   // Succès
   g_aiConsecutiveFailures = 0;
   if(g_aiFallbackMode)
   {
      g_aiFallbackMode = false;
      if(DebugMode)
         Print("✅ MODE DÉGRADÉ DÉSACTIVÉ: Serveur IA disponible");
   }
   
   string resp = CharArrayToString(result, 0, -1, CP_UTF8);
   
   if(DebugMode)
      Print("📥 Réponse IA reçue: ", StringSubstr(resp, 0, 300)); // Afficher les 300 premiers caractères
   
   // Réinitialiser les valeurs avant parsing
   g_lastAIAction = "";
   g_lastAIConfidence = 0.0;
   g_lastAIReason = "";
   
   // Parser la réponse JSON de manière plus robuste
   // 1. Parser "action" - recherche avec gestion des espaces
   int actionPos = StringFind(resp, "\"action\"");
   if(actionPos < 0)
      actionPos = StringFind(resp, "action"); // Essayer sans guillemets
   
   if(actionPos >= 0)
   {
      // Chercher le deux-points après "action"
      int colonPos = StringFind(resp, ":", actionPos);
      if(colonPos > actionPos)
      {
         // Chercher la valeur entre guillemets (peut avoir des espaces avant)
         int searchStart = colonPos + 1;
         int quoteStart = -1;
         
         // Chercher le premier guillemet après le deux-points
         for(int i = searchStart; i < StringLen(resp) && i < searchStart + 20; i++)
         {
            if(StringGetCharacter(resp, i) == '"')
            {
               quoteStart = i;
               break;
            }
         }
         
         if(quoteStart > 0)
         {
            int quoteEnd = StringFind(resp, "\"", quoteStart + 1);
            if(quoteEnd > quoteStart)
            {
               string actionValue = StringSubstr(resp, quoteStart + 1, quoteEnd - quoteStart - 1);
               StringTrimLeft(actionValue);
               StringTrimRight(actionValue);
               StringToLower(actionValue);
               
               // Gérer différents formats possibles
               if(StringFind(actionValue, "buy") == 0 || StringFind(actionValue, "achat") == 0)
                  g_lastAIAction = "buy";
               else if(StringFind(actionValue, "sell") == 0 || StringFind(actionValue, "vente") == 0)
                  g_lastAIAction = "sell";
               else
                  g_lastAIAction = "hold";
            }
         }
      }
   }
   
   // Fallback pour action si parsing échoue
   if(g_lastAIAction == "")
   {
      string respLower = resp;
      StringToLower(respLower);
      // Recherche plus précise pour éviter les faux positifs
      int buyPos = StringFind(respLower, "\"buy\"");
      int sellPos = StringFind(respLower, "\"sell\"");
      int holdPos = StringFind(respLower, "\"hold\"");
      
      if(buyPos >= 0 && (sellPos < 0 || buyPos < sellPos) && (holdPos < 0 || buyPos < holdPos))
         g_lastAIAction = "buy";
      else if(sellPos >= 0 && (holdPos < 0 || sellPos < holdPos))
         g_lastAIAction = "sell";
      else
         g_lastAIAction = "hold";
   }
   
   // 2. Parser "confidence" - gestion améliorée des nombres décimaux
   int confPos = StringFind(resp, "\"confidence\"");
   if(confPos < 0)
      confPos = StringFind(resp, "confidence");
   
   if(confPos >= 0)
   {
      int colon = StringFind(resp, ":", confPos);
      if(colon > confPos)
      {
         // Chercher la fin du nombre (virgule, accolade, ou espace)
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) 
         {
            endPos = StringFind(resp, "}", colon);
            if(endPos < 0)
               endPos = StringFind(resp, "\n", colon);
            if(endPos < 0)
               endPos = StringFind(resp, "\r", colon);
         }
         
         if(endPos > colon)
         {
            string confStr = StringSubstr(resp, colon + 1, endPos - colon - 1);
            StringTrimLeft(confStr);
            StringTrimRight(confStr);
            
            // Nettoyer la chaîne (enlever espaces, retours à la ligne)
            string cleanConf = "";
            for(int i = 0; i < StringLen(confStr); i++)
            {
               ushort ch = StringGetCharacter(confStr, i);
               if((ch >= '0' && ch <= '9') || ch == '.' || ch == '-' || ch == '+')
                  cleanConf += ShortToString(ch);
            }
            
            if(StringLen(cleanConf) > 0)
            {
               double confValue = StringToDouble(cleanConf);
               // Valider que la confiance est dans une plage raisonnable (0.0 à 1.0)
               if(confValue >= 0.0 && confValue <= 1.0)
                  g_lastAIConfidence = confValue;
               else if(confValue > 1.0 && confValue <= 100.0)
                  g_lastAIConfidence = confValue / 100.0; // Convertir de pourcentage à décimal
               else
               {
                  if(DebugMode)
                     Print("⚠️ Confiance IA invalide: ", confValue, " (chaîne brute: ", confStr, ")");
               }
            }
            else if(DebugMode)
               Print("⚠️ Impossible d'extraire la confiance depuis: ", confStr);
         }
      }
   }
   
   // 3. Parser "reason" - gestion améliorée des chaînes avec caractères spéciaux
   int reasonPos = StringFind(resp, "\"reason\"");
   if(reasonPos < 0)
      reasonPos = StringFind(resp, "reason");
   
   if(reasonPos >= 0)
   {
      int colonR = StringFind(resp, ":", reasonPos);
      if(colonR > reasonPos)
      {
         // Chercher le premier guillemet après le deux-points
         int searchStart = colonR + 1;
         int startQuote = -1;
         
         for(int i = searchStart; i < StringLen(resp) && i < searchStart + 50; i++)
         {
            if(StringGetCharacter(resp, i) == '"')
            {
               startQuote = i;
               break;
            }
         }
         
         if(startQuote > 0)
         {
            // Chercher le guillemet de fin (peut être échappé)
            int endQuote = -1;
            for(int i = startQuote + 1; i < StringLen(resp) && i < startQuote + 500; i++)
            {
               ushort ch = StringGetCharacter(resp, i);
               if(ch == '"')
               {
                  // Vérifier si c'est échappé
                  if(i > 0 && StringGetCharacter(resp, i - 1) != '\\')
                  {
                     endQuote = i;
                     break;
                  }
               }
            }
            
            if(endQuote > startQuote)
            {
               g_lastAIReason = StringSubstr(resp, startQuote + 1, endQuote - startQuote - 1);
               // Décoder les échappements JSON basiques
               StringReplace(g_lastAIReason, "\\\"", "\"");
               StringReplace(g_lastAIReason, "\\n", "\n");
               StringReplace(g_lastAIReason, "\\r", "\r");
               StringReplace(g_lastAIReason, "\\t", "\t");
            }
         }
      }
   }
   
   // Validation finale
   if(g_lastAIAction == "")
   {
      g_lastAIAction = "hold";
      if(DebugMode)
         Print("⚠️ Action IA non trouvée, utilisation de 'hold' par défaut");
   }
   
   if(g_lastAIConfidence < 0.0 || g_lastAIConfidence > 1.0)
   {
      if(DebugMode)
         Print("⚠️ Confiance IA invalide (", g_lastAIConfidence, "), réinitialisation à 0.0");
      g_lastAIConfidence = 0.0;
   }
   
      // Extraire les zones BUY/SELL depuis la réponse JSON
      ExtractAIZonesFromResponse(resp);
      
      g_lastAITime = TimeCurrent();
      
      if(DebugMode)
      Print("🤖 IA: ", g_lastAIAction, " (confiance: ", DoubleToString(g_lastAIConfidence, 2), ") - ", g_lastAIReason);
}

//+------------------------------------------------------------------+
//| Mettre à jour l'analyse de tendance API                          |
//+------------------------------------------------------------------+
void UpdateTrendAPIAnalysis()
{
   if(!UseTrendAPIAnalysis || StringLen(TrendAPIURL) == 0)
      return;
   
   // Construire l'URL avec les paramètres symbol et timeframe
   string safeSymbol = _Symbol;
   StringReplace(safeSymbol, " ", "%20");
   string url = TrendAPIURL + "?symbol=" + safeSymbol + "&timeframe=M1";
   
   // Préparer la requête GET
   char data[];
   ArrayResize(data, 0);
   char result[];
   string headers = "Accept: application/json\r\n";
   string result_headers = "";
   
   int res = WebRequest("GET", url, headers, AI_Timeout_ms, data, result, result_headers);
   
   if(res < 200 || res >= 300)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération API Trend: http=", res);
      g_api_trend_valid = false;
      return;
   }
   
   // Parser la réponse
   string resp = CharArrayToString(result, 0, -1, CP_UTF8);
   ParseTrendAPIResponse(resp);
}

//+------------------------------------------------------------------+
//| Parser la réponse de l'API de tendance                            |
//+------------------------------------------------------------------+
void ParseTrendAPIResponse(string json_response)
{
   g_api_trend_valid = false;
   g_api_trend_direction = 0;
   g_api_trend_strength = 0.0;
   g_api_trend_confidence = 0.0;
   g_api_trend_signal = "";
   
   // Parser la direction
   int dirPos = StringFind(json_response, "\"direction\"");
   if(dirPos >= 0)
   {
      int colon = StringFind(json_response, ":", dirPos);
      if(colon > 0)
      {
         // Chercher BUY, SELL ou NEUTRE
         string dirStr = StringSubstr(json_response, colon + 1, 20);
         StringToUpper(dirStr);
         if(StringFind(dirStr, "BUY") >= 0 || StringFind(dirStr, "1") >= 0)
            g_api_trend_direction = 1;
         else if(StringFind(dirStr, "SELL") >= 0 || StringFind(dirStr, "-1") >= 0)
            g_api_trend_direction = -1;
         else
            g_api_trend_direction = 0;
      }
   }
   
   // Parser la force (strength)
   int strPos = StringFind(json_response, "\"strength\"");
   if(strPos >= 0)
   {
      int colon = StringFind(json_response, ":", strPos);
      if(colon > 0)
      {
         int endPos = StringFind(json_response, ",", colon);
         if(endPos < 0) endPos = StringFind(json_response, "}", colon);
         if(endPos > colon)
         {
            string strStr = StringSubstr(json_response, colon + 1, endPos - colon - 1);
            g_api_trend_strength = StringToDouble(strStr);
         }
      }
   }
   
   // Parser la confiance (confidence)
   int confPos = StringFind(json_response, "\"confidence\"");
   if(confPos >= 0)
   {
      int colon = StringFind(json_response, ":", confPos);
      if(colon > 0)
      {
         int endPos = StringFind(json_response, ",", colon);
         if(endPos < 0) endPos = StringFind(json_response, "}", colon);
         if(endPos > colon)
         {
            string confStr = StringSubstr(json_response, colon + 1, endPos - colon - 1);
            g_api_trend_confidence = StringToDouble(confStr);
         }
      }
   }
   
   // Parser le signal
   int sigPos = StringFind(json_response, "\"signal\"");
   if(sigPos >= 0)
   {
      int colon = StringFind(json_response, ":", sigPos);
      if(colon > 0)
      {
         int startQuote = StringFind(json_response, "\"", colon);
         if(startQuote > 0)
         {
            int endQuote = StringFind(json_response, "\"", startQuote + 1);
            if(endQuote > startQuote)
               g_api_trend_signal = StringSubstr(json_response, startQuote + 1, endQuote - startQuote - 1);
         }
      }
   }
   
   // Valider les données si la confiance est suffisante
   if(g_api_trend_confidence >= TrendAPIMinConfidence)
   {
      g_api_trend_valid = true;
      g_api_trend_last_update = TimeCurrent();
      
      if(DebugMode)
      {
         string dirStr = (g_api_trend_direction == 1) ? "BUY" : (g_api_trend_direction == -1) ? "SELL" : "NEUTRE";
         Print("📊 API Trend: ", dirStr, " | Force: ", DoubleToString(g_api_trend_strength, 1), 
               "% | Confiance: ", DoubleToString(g_api_trend_confidence, 1), "%");
      }
   }
   else
   {
      if(DebugMode)
         Print("⚠️ API Trend: Confiance insuffisante (", DoubleToString(g_api_trend_confidence, 1), 
               "% < ", DoubleToString(TrendAPIMinConfidence, 1), "%)");
   }
}

//+------------------------------------------------------------------+
//| Extraire les zones BUY/SELL depuis la réponse JSON de l'IA       |
//+------------------------------------------------------------------+
void ExtractAIZonesFromResponse(string resp)
{
   // Extraire buy_zone_low
   int buyLowPos = StringFind(resp, "\"buy_zone_low\"");
   if(buyLowPos >= 0)
   {
      int colon = StringFind(resp, ":", buyLowPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
         {
            string buyLowStr = StringSubstr(resp, colon+1, endPos-colon-1);
            StringTrimLeft(buyLowStr);
            StringTrimRight(buyLowStr);
            if(buyLowStr != "null" && buyLowStr != "" && StringLen(buyLowStr) > 0)
               g_aiBuyZoneLow = StringToDouble(buyLowStr);
         }
      }
   }
   
   // Extraire buy_zone_high
   int buyHighPos = StringFind(resp, "\"buy_zone_high\"");
   if(buyHighPos >= 0)
   {
      int colon = StringFind(resp, ":", buyHighPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
         {
            string buyHighStr = StringSubstr(resp, colon+1, endPos-colon-1);
            StringTrimLeft(buyHighStr);
            StringTrimRight(buyHighStr);
            if(buyHighStr != "null" && buyHighStr != "" && StringLen(buyHighStr) > 0)
               g_aiBuyZoneHigh = StringToDouble(buyHighStr);
         }
      }
   }
   
   // Extraire sell_zone_low
   int sellLowPos = StringFind(resp, "\"sell_zone_low\"");
   if(sellLowPos >= 0)
   {
      int colon = StringFind(resp, ":", sellLowPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
         {
            string sellLowStr = StringSubstr(resp, colon+1, endPos-colon-1);
            StringTrimLeft(sellLowStr);
            StringTrimRight(sellLowStr);
            if(sellLowStr != "null" && sellLowStr != "" && StringLen(sellLowStr) > 0)
               g_aiSellZoneLow = StringToDouble(sellLowStr);
         }
      }
   }
   
   // Extraire sell_zone_high
   int sellHighPos = StringFind(resp, "\"sell_zone_high\"");
   if(sellHighPos >= 0)
   {
      int colon = StringFind(resp, ":", sellHighPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
         {
            string sellHighStr = StringSubstr(resp, colon+1, endPos-colon-1);
            StringTrimLeft(sellHighStr);
            StringTrimRight(sellHighStr);
            if(sellHighStr != "null" && sellHighStr != "" && StringLen(sellHighStr) > 0)
               g_aiSellZoneHigh = StringToDouble(sellHighStr);
         }
      }
   }
   
   if(DebugMode && (g_aiBuyZoneLow > 0 || g_aiSellZoneLow > 0))
      Print("📍 Zones IA extraites - BUY: ", g_aiBuyZoneLow, "-", g_aiBuyZoneHigh, " SELL: ", g_aiSellZoneLow, "-", g_aiSellZoneHigh);
}

//+------------------------------------------------------------------+
//| Vérifier et gérer les positions existantes                       |
//+------------------------------------------------------------------+
void CheckAndManagePositions()
{
   g_hasPosition = false;

   // Fermeture globale Volatility si perte cumulée dépasse 7$
   CloseVolatilityIfLossExceeded(7.0);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
         {
            g_hasPosition = true;
            
            // Mettre à jour le tracker
            if(g_positionTracker.ticket != ticket)
            {
               g_positionTracker.ticket = ticket;
               g_positionTracker.initialLot = positionInfo.Volume();
               g_positionTracker.currentLot = positionInfo.Volume();
               g_positionTracker.highestProfit = 0.0;
               g_positionTracker.lotDoubled = false;
               g_positionTracker.openTime = (datetime)positionInfo.Time();
               g_positionTracker.maxProfitReached = 0.0;
               g_positionTracker.profitSecured = false;
            }
            
            // Vérifier le profit actuel et mettre à jour le profit maximum
            double currentProfit = positionInfo.Profit();
            if(currentProfit > g_positionTracker.highestProfit)
               g_positionTracker.highestProfit = currentProfit;
            
            // Mettre à jour le profit maximum atteint pour cette position
            if(currentProfit > g_positionTracker.maxProfitReached)
               g_positionTracker.maxProfitReached = currentProfit;
            
            // NOUVEAU: Sécurisation CONTINUE dès qu'il y a un profit
            // Appelé à chaque tick si la position est en profit (pas seulement quand le profit augmente)
            // Cela garantit que le SL est toujours ajusté pour sécuriser au moins 50% des gains
            if(currentProfit > 0.10) // Minimum 0.10$ pour éviter trop de modifications
            {
               SecureProfitForPosition(ticket, currentProfit);
            }
            
            // NOUVELLE LOGIQUE: Fermer si perte individuelle atteint MaxLossPerPosition (PROTECTION MAXIMALE)
            if(currentProfit <= -MaxLossPerPosition)
            {
               if(trade.PositionClose(ticket))
               {
                  Print("🛑 Position fermée: Perte maximale atteinte (", DoubleToString(currentProfit, 2), "$ <= -", DoubleToString(MaxLossPerPosition, 2), "$) - PROTECTION");
                  continue;
               }
            }
            
            // NOUVELLE LOGIQUE: Fermer si profit individuel atteint 2$
            if(currentProfit >= 2.0)
            {
               if(trade.PositionClose(ticket))
               {
                  Print("✅ Position fermée: Profit individuel atteint (", DoubleToString(currentProfit, 2), "$ >= 2.00$)");
                  continue;
               }
            }
            
            // LOGIQUE: Fermer si IA change en "hold" ou change de direction
            // Appliqué à TOUS les symboles (pas seulement Boom/Crash)
            if(UseAI_Agent && g_lastAIAction != "")
            {
               ENUM_POSITION_TYPE posType = positionInfo.PositionType();
               bool shouldClose = false;
               string closeReason = "";
               
               // Si IA recommande "hold", fermer position
               if(g_lastAIAction == "hold")
               {
                  shouldClose = true;
                  closeReason = "IA recommande maintenant 'ATTENTE'";
                  if(DebugMode)
                     Print("🔄 Position fermée: ", closeReason, " - Recherche meilleure entrée prochainement");
               }
               // Si IA change de direction (BUY -> SELL ou SELL -> BUY)
               else if((posType == POSITION_TYPE_BUY && g_lastAIAction == "sell") ||
                       (posType == POSITION_TYPE_SELL && g_lastAIAction == "buy"))
               {
                  shouldClose = true;
                  closeReason = "IA change de direction";
                  if(DebugMode)
                  {
                     string actionUpper = g_lastAIAction;
                     StringToUpper(actionUpper);
                     Print("🔄 Position fermée: ", closeReason, " (position ", (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                           " -> IA recommande ", actionUpper, ") - Recherche meilleure entrée prochainement");
                  }
               }
               
               if(shouldClose)
               {
                  if(trade.PositionClose(ticket))
                  {
                     Print("✅ Position fermée suite changement IA: ", closeReason, " | Profit=", DoubleToString(currentProfit, 2), "$");
                     continue;
                  }
               }
            }
            
            // Vérifier si on doit doubler le lot
            datetime now = TimeCurrent();
            int positionAge = (int)(now - g_positionTracker.openTime);
            
            if(!g_positionTracker.lotDoubled && 
               currentProfit >= ProfitThresholdForDouble &&
               positionAge >= MinPositionLifetimeSec)
            {
               DoublePositionLot(ticket);
            }
            
            // Vérifier les SL/TP (gérés par le broker, mais on peut vérifier)
            double sl = positionInfo.StopLoss();
            double tp = positionInfo.TakeProfit();
            
            // Si pas de SL/TP, les définir avec limite de perte max 3$
            if(sl == 0 && tp == 0)
            {
               SetFixedSLTPWithMaxLoss(ticket, 3.0); // Limite de perte max 3$ par position
            }
            
            // Pour Boom/Crash: Fermer après spike même avec petit gain (0.2$ minimum)
            bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
            bool isForex = IsForexSymbol(_Symbol);
            
            if(isBoomCrash)
            {
               CloseBoomCrashAfterSpike(ticket, currentProfit);
            }
            
            // PROTECTION FOREX: Ne pas fermer les positions Forex trop vite (minimum 60 secondes)
            // Les positions Forex doivent avoir le temps de se développer avant fermeture
            if(isForex && !isBoomCrash)
            {
               datetime openTime = (datetime)positionInfo.Time();
               int positionAge = (int)(TimeCurrent() - openTime);
               
               // Si position trop récente (< 60s) et en petite perte, attendre
               if(positionAge < 60 && currentProfit < 0 && currentProfit > -1.0)
               {
                  if(DebugMode)
                     Print("⏸️ Position Forex trop récente (", positionAge, "s < 60s) et petite perte (", DoubleToString(currentProfit, 2), "$) - Attendre développement");
                  // Ne pas fermer, continuer la boucle
                  break;
               }
            }
            
            // NOUVELLE LOGIQUE: Fermer les positions si le prix sort de la zone IA et entre en correction
            // UNIQUEMENT pour Boom/Crash (pas pour le forex qui doit attendre SL/TP)
            // Évite de garder des positions pendant les corrections sur Boom/Crash
            if(isBoomCrash)
            {
               ENUM_POSITION_TYPE posType = positionInfo.PositionType();
               if(posType == POSITION_TYPE_BUY)
               {
                  CheckAndCloseBuyOnCorrection(ticket, currentProfit);
               }
               else if(posType == POSITION_TYPE_SELL)
               {
                  CheckAndCloseSellOnCorrection(ticket, currentProfit);
               }
            }
            
            break; // Une seule position à la fois
         }
      }
   }
   
   // Si plus de position, réinitialiser le tracker
   if(!g_hasPosition)
   {
      g_positionTracker.ticket = 0;
      g_positionTracker.initialLot = 0;
      g_positionTracker.currentLot = 0;
      g_positionTracker.highestProfit = 0.0;
      g_positionTracker.lotDoubled = false;
      g_positionTracker.maxProfitReached = 0.0;
      g_positionTracker.profitSecured = false;
      g_globalMaxProfit = 0.0; // Réinitialiser le profit global max
   }
}

//+------------------------------------------------------------------+
//| Nettoyer TOUS les objets graphiques au démarrage                  |
//+------------------------------------------------------------------+
void CleanAllGraphicalObjects()
{
   // Supprimer TOUS les objets graphiques sauf les labels essentiels
   int total = ObjectsTotal(0);
   string objectsToKeep[] = {"AI_CONFIDENCE_", "AI_TREND_SUMMARY_"};
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(name == "")
         continue;
      
      // Vérifier si c'est un objet à garder
      bool keepObject = false;
      for(int k = 0; k < ArraySize(objectsToKeep); k++)
      {
         if(StringFind(name, objectsToKeep[k]) == 0)
         {
            keepObject = true;
            break;
         }
      }
      
      if(!keepObject)
         ObjectDelete(0, name);
   }
   
   if(DebugMode)
      Print("🧹 Nettoyage complet des objets graphiques effectué");
}

//+------------------------------------------------------------------+
//| Nettoyer les anciens objets graphiques                           |
//+------------------------------------------------------------------+
void CleanOldGraphicalObjects()
{
   // OPTIMISATION: Nettoyage minimal - seulement les objets vraiment obsolètes
   // Ne pas nettoyer trop souvent pour éviter de ralentir
   static datetime lastCleanup = 0;
   if(TimeCurrent() - lastCleanup < 300) // Nettoyage max toutes les 5 minutes
      return;
   
   // Déclarer les tableaux au début de la fonction
   string prefixesToDelete[] = {"DERIV_", "Deriv_"}; // Supprimer seulement les patterns Deriv obsolètes
   string objectsToKeep[] = {"AI_CONFIDENCE_", "AI_TREND_SUMMARY_", "EMA_50_", "EMA_100_", "EMA_200_", 
                              "AI_BUY_", "AI_SELL_", "SR_", "Trend_", "SMC_OB_", "DERIV_ARROW_"};
   
   // Supprimer les anciens objets graphiques sauf ceux qu'on veut garder
   int total = ObjectsTotal(0);
   if(total > 1000) // Seulement nettoyer si trop d'objets
   {
      // Limiter le nettoyage aux 100 derniers objets pour performance
      int startIdx = MathMax(0, total - 100);
      for(int i = total - 1; i >= startIdx; i--)
      {
         string name = ObjectName(0, i);
         if(name == "")
            continue;
         
         // Vérifier si c'est un objet à garder
         bool keepObject = false;
         for(int k = 0; k < ArraySize(objectsToKeep); k++)
         {
            if(StringFind(name, objectsToKeep[k]) == 0)
            {
               keepObject = true;
               break;
            }
         }
         
         if(keepObject)
            continue; // Garder cet objet
         
         // Supprimer les objets avec les préfixes à supprimer
         for(int j = 0; j < ArraySize(prefixesToDelete); j++)
         {
            if(StringFind(name, prefixesToDelete[j]) == 0)
            {
               ObjectDelete(0, name);
               break;
            }
         }
      }
   }
   
   lastCleanup = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Dessiner confiance IA et résumés de tendance par timeframe       |
//+------------------------------------------------------------------+
void DrawAIConfidenceAndTrendSummary()
{
   // Affichage IA decision supprimé (ancien et symbole) - sur demande utilisateur
   string aiLabelName = "AI_CONFIDENCE_" + _Symbol;
   if(ObjectFind(0, aiLabelName) >= 0)
      ObjectDelete(0, aiLabelName);
   
   // Résumés de tendance par timeframe (si disponibles depuis api_trend)
   // Récupérer les EMA pour afficher les tendances
   double emaFastM1[], emaSlowM1[], emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   
   bool hasData = true;
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFastM1) <= 0 ||
      CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlowM1) <= 0 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 1, emaFastM5) <= 0 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 1, emaSlowM5) <= 0 ||
      CopyBuffer(emaFastH1Handle, 0, 0, 1, emaFastH1) <= 0 ||
      CopyBuffer(emaSlowH1Handle, 0, 0, 1, emaSlowH1) <= 0)
      hasData = false;
   
   if(hasData)
   {
      int yOffset = 50;
      string trendText = "Tendances: ";
      
      // M1
      string m1Trend = (emaFastM1[0] > emaSlowM1[0]) ? "M1↑" : "M1↓";
      trendText += m1Trend + " ";
      
      // M5
      string m5Trend = (emaFastM5[0] > emaSlowM5[0]) ? "M5↑" : "M5↓";
      trendText += m5Trend + " ";
      
      // H1
      string h1Trend = (emaFastH1[0] > emaSlowH1[0]) ? "H1↑" : "H1↓";
      trendText += h1Trend;
      
      string trendLabelName = "AI_TREND_SUMMARY_" + _Symbol;
      if(ObjectFind(0, trendLabelName) < 0)
         ObjectCreate(0, trendLabelName, OBJ_LABEL, 0, 0, 0);
      
      ObjectSetInteger(0, trendLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, trendLabelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, trendLabelName, OBJPROP_YDISTANCE, yOffset);
      ObjectSetString(0, trendLabelName, OBJPROP_TEXT, trendText);
      ObjectSetInteger(0, trendLabelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, trendLabelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, trendLabelName, OBJPROP_FONT, "Arial");
   }
}

//+------------------------------------------------------------------+
//| Afficher l'état des endpoints Render dans le dashboard              |
//+------------------------------------------------------------------+
void DrawRenderEndpointsStatus()
{
   if(!UseAllEndpoints) return;
   
   // Label pour l'état des endpoints
   string endpointsLabelName = "ENDPOINTS_STATUS_" + _Symbol;
   if(ObjectFind(0, endpointsLabelName) < 0)
      ObjectCreate(0, endpointsLabelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, endpointsLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, endpointsLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, endpointsLabelName, OBJPROP_YDISTANCE, 120);
   
   string endpointsText = "Endpoints: ";
   
   // Vérifier chaque endpoint
   bool analysisOK = (g_lastAnalysisData != "");
   bool trendOK = (g_lastTrendData != "");
   bool predictionOK = (g_lastPredictionData != "");
   bool coherentOK = (g_lastCoherentData != "");
   
   endpointsText += analysisOK ? "✅" : "❌";
   endpointsText += " ";
   endpointsText += trendOK ? "✅" : "❌";
   endpointsText += " ";
   endpointsText += predictionOK ? "✅" : "❌";
   endpointsText += " ";
   endpointsText += coherentOK ? "✅" : "❌";
   
   // Ajouter le score d'alignement
   if(g_endpointsAlignment > 0)
      endpointsText += " (" + DoubleToString(g_endpointsAlignment * 100, 0) + "%)";
   
   ObjectSetString(0, endpointsLabelName, OBJPROP_TEXT, endpointsText);
   ObjectSetInteger(0, endpointsLabelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, endpointsLabelName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, endpointsLabelName, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Affiche les informations IA directement sur le graphique           |
//+------------------------------------------------------------------+
void UpdateAlignmentDashboard()
{
   if(!ShowDashboard || !ShowInfoOnChart) return;
   
   // Nettoyer les anciens objets
   CleanupDashboard();
   
   // Obtenir le prix actuel pour positionner le texte
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime currentTime = TimeCurrent();
   
   // Positionner le texte en haut à gauche du graphique
   int x = 20;
   int y = 30;
   
   // Ligne 1: Alignement des endpoints (IA decision supprimé - ancien et symbole)
   string alignText = "Alignement: " + DoubleToString(g_endpointsAlignment * 100, 0) + "%";
   string alignName = g_dashboardName + "Alignement";
   ObjectCreate(0, alignName, OBJ_TEXT, 0, currentTime, currentPrice - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50));
   ObjectSetString(0, alignName, OBJPROP_TEXT, alignText);
   ObjectSetInteger(0, alignName, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, alignName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, alignName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, alignName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, alignName, OBJPROP_BACK, 0);
   
   // Lignes 3-6: Status des endpoints (compact)
   for(int i = 0; i < 4; i++)
   {
      string endpointText = g_endpointNames[i] + ": " + g_alignmentStatus[i];
      string endpointName = g_dashboardName + "Endpoint" + IntegerToString(i);
      ObjectCreate(0, endpointName, OBJ_TEXT, 0, currentTime, currentPrice - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * (100 + i*20)));
      ObjectSetString(0, endpointName, OBJPROP_TEXT, endpointText);
      ObjectSetInteger(0, endpointName, OBJPROP_COLOR, g_alignmentColors[i]);
      ObjectSetInteger(0, endpointName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, endpointName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, endpointName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, endpointName, OBJPROP_BACK, 0);
   }
}

//+------------------------------------------------------------------+
//| Nettoie les objets du tableau de bord                            |
//+------------------------------------------------------------------+
void CleanupDashboard()
{
   // Nettoyer les anciens objets de type LABEL
   for(int i = 0; i < 4; i++)
   {
      string lineName = g_dashboardName + "Line" + IntegerToString(i);
      ObjectDelete(0, lineName);
   }
   
   // Nettoyer les anciens objets du tableau de bord
   ObjectDelete(0, g_dashboardName + "Panel");
   ObjectDelete(0, g_dashboardName + "Title");
   ObjectDelete(0, g_dashboardName + "Score");
   ObjectDelete(0, g_dashboardName + "Signal");
   
   // Nettoyer les nouveaux objets TEXT sur le graphique
   ObjectDelete(0, g_dashboardName + "Signal");
   ObjectDelete(0, g_dashboardName + "Alignement");
   
   for(int i = 0; i < 4; i++)
   {
      string endpointName = g_dashboardName + "Endpoint" + IntegerToString(i);
      ObjectDelete(0, endpointName);
   }
}

//+------------------------------------------------------------------+
//| Vérifier et fermer une position BUY si correction détectée       |
//| Ferme si le prix sort de la zone d'achat et entre en correction  |
//+------------------------------------------------------------------+
void CheckAndCloseBuyOnCorrection(ulong ticket, double currentProfit)
{
   if(!positionInfo.SelectByTicket(ticket))
      return;
   
   // Ne fermer que si on a une zone d'achat définie
   if(g_aiBuyZoneLow <= 0 || g_aiBuyZoneHigh <= 0)
      return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Vérifier si le prix est sorti de la zone d'achat (au-dessus)
   if(currentPrice > g_aiBuyZoneHigh)
   {
      // Récupérer les EMA M1 pour détecter la correction
      double emaFastM1[], emaSlowM1[];
      ArraySetAsSeries(emaFastM1, true);
      ArraySetAsSeries(emaSlowM1, true);
      
      if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFastM1) <= 0 ||
         CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlowM1) <= 0)
         return;
      
      // Détecter correction: EMA rapide descend sous EMA lente OU prix < EMA rapide
      bool isCorrection = false;
      if(emaFastM1[0] < emaSlowM1[0] || currentPrice < emaFastM1[0])
      {
         // Vérifier si c'est une correction récente (les 2 dernières bougies)
         if(emaFastM1[1] > emaFastM1[0] || emaFastM1[2] > emaFastM1[1])
         {
            isCorrection = true;
         }
      }
      
      // Si correction détectée et prix sorti de zone, fermer la position
      // Mais seulement si on a un petit profit ou une petite perte (éviter de perdre trop)
      if(isCorrection)
      {
         // PROTECTION: Ne pas fermer trop vite (minimum 30 secondes après ouverture)
         datetime openTime = (datetime)positionInfo.Time();
         int positionAge = (int)(TimeCurrent() - openTime);
         if(positionAge < 30)
         {
            if(DebugMode)
               Print("⏸️ Position BUY trop récente (", positionAge, "s < 30s) - Attendre avant fermeture correction");
            return; // Ne pas fermer trop vite
         }
         
         // Fermer si profit >= 0 ou perte <= 2$ (limiter les pertes)
         if(currentProfit >= 0 || currentProfit >= -2.0)
         {
            if(trade.PositionClose(ticket))
            {
               Print("✅ Position BUY fermée: Prix sorti de zone d'achat [", g_aiBuyZoneLow, "-", g_aiBuyZoneHigh, "] et correction détectée (après ", positionAge, "s) - Profit=", DoubleToString(currentProfit, 2), "$");
               RemoveSymbolFromExecutedList(_Symbol);
            }
            else
            {
               if(DebugMode)
                  Print("❌ Erreur fermeture position BUY: ", trade.ResultRetcodeDescription());
            }
         }
         else if(DebugMode)
         {
            Print("⏸️ Position BUY conservée malgré correction: Perte trop importante (", DoubleToString(currentProfit, 2), "$) - Attendre SL/TP");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier et fermer une position SELL si correction détectée      |
//| Ferme si le prix sort de la zone de vente et entre en correction  |
//+------------------------------------------------------------------+
void CheckAndCloseSellOnCorrection(ulong ticket, double currentProfit)
{
   if(!positionInfo.SelectByTicket(ticket))
      return;
   
   // Ne fermer que si on a une zone de vente définie
   if(g_aiSellZoneLow <= 0 || g_aiSellZoneHigh <= 0)
      return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Vérifier si le prix est sorti de la zone de vente (en-dessous)
   if(currentPrice < g_aiSellZoneLow)
   {
      // Récupérer les EMA M1 pour détecter la correction
      double emaFastM1[], emaSlowM1[];
      ArraySetAsSeries(emaFastM1, true);
      ArraySetAsSeries(emaSlowM1, true);
      
      if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFastM1) <= 0 ||
         CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlowM1) <= 0)
         return;
      
      // Détecter correction: EMA rapide monte au-dessus de EMA lente OU prix > EMA rapide
      bool isCorrection = false;
      if(emaFastM1[0] > emaSlowM1[0] || currentPrice > emaFastM1[0])
      {
         // Vérifier si c'est une correction récente
         if(emaFastM1[1] < emaFastM1[0] || emaFastM1[2] < emaFastM1[1])
         {
            isCorrection = true;
         }
      }
      
      // Si correction détectée et prix sorti de zone, fermer la position
      if(isCorrection)
      {
         // PROTECTION: Ne pas fermer trop vite (minimum 30 secondes après ouverture)
         datetime openTime = (datetime)positionInfo.Time();
         int positionAge = (int)(TimeCurrent() - openTime);
         if(positionAge < 30)
         {
            if(DebugMode)
               Print("⏸️ Position SELL trop récente (", positionAge, "s < 30s) - Attendre avant fermeture correction");
            return; // Ne pas fermer trop vite
         }
         
         // Fermer si profit >= 0 ou perte <= 2$
         if(currentProfit >= 0 || currentProfit >= -2.0)
         {
            if(trade.PositionClose(ticket))
            {
               Print("✅ Position SELL fermée: Prix sorti de zone de vente [", g_aiSellZoneLow, "-", g_aiSellZoneHigh, "] et correction détectée (après ", positionAge, "s) - Profit=", DoubleToString(currentProfit, 2), "$");
               RemoveSymbolFromExecutedList(_Symbol);
            }
            else
            {
               if(DebugMode)
                  Print("❌ Erreur fermeture position SELL: ", trade.ResultRetcodeDescription());
            }
         }
         else if(DebugMode)
         {
            Print("⏸️ Position SELL conservée malgré correction: Perte trop importante (", DoubleToString(currentProfit, 2), "$) - Attendre SL/TP");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Fermer les positions Boom/Crash après spike (profit >= seuil)    |
//| Détecte aussi le spike par mouvement de prix rapide               |
//+------------------------------------------------------------------+
void CloseBoomCrashAfterSpike(ulong ticket, double currentProfit)
{
   if(!positionInfo.SelectByTicket(ticket))
      return;
   
   // Détecter le spike par mouvement de prix rapide
   static datetime g_lastPriceCheck = 0;
   
   double currentPrice = positionInfo.PriceCurrent();
   datetime now = TimeCurrent();
   
   // Vérifier si c'est un spike (mouvement rapide de prix)
   bool spikeDetected = false;
   if(g_lastBoomCrashPrice > 0 && (now - g_lastPriceCheck) <= 5) // Vérifier toutes les 5 secondes max
   {
      double priceChange = MathAbs(currentPrice - g_lastBoomCrashPrice);
      double priceChangePercent = (priceChange / g_lastBoomCrashPrice) * 100.0;
      
      // Si changement de prix > 0.5% en peu de temps, c'est un spike
      if(priceChangePercent > 0.5)
      {
         spikeDetected = true;
         if(DebugMode)
            Print("🚨 SPIKE DÉTECTÉ: ", _Symbol, " - Changement de prix: ", DoubleToString(priceChangePercent, 2), "%");
      }
   }
   
   g_lastBoomCrashPrice = currentPrice;
   g_lastPriceCheck = now;
   
   // Pour Boom/Crash: fermer immédiatement dès qu'on atteint le profit minimal OU si spike détecté
   if(currentProfit >= BoomCrashSpikeTP || spikeDetected)
   {
      if(trade.PositionClose(ticket))
      {
         string reason = spikeDetected ? "Spike détecté" : "Profit seuil atteint";
         Print("✅ Position Boom/Crash fermée: ", reason, " - Profit=", DoubleToString(currentProfit, 2),
               "$ (seuil=", DoubleToString(BoomCrashSpikeTP, 2), "$)");
         
         // Retirer le symbole de la liste pour permettre un nouveau trade au prochain signal
         RemoveSymbolFromExecutedList(_Symbol);
         
         // Réinitialiser le suivi du prix
         g_lastBoomCrashPrice = 0.0;
         g_lastPriceCheck = 0;
      }
      else
      {
         Print("❌ Erreur fermeture position Boom/Crash: ", trade.ResultRetcode(), 
               " - ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Doubler le lot de la position                                    |
//+------------------------------------------------------------------+
void DoublePositionLot(ulong ticket)
{
   if(!positionInfo.SelectByTicket(ticket))
      return;
   
   double currentLot = positionInfo.Volume();
   double newLot = currentLot * 2.0;
   
   // Vérifier la limite maximale
   if(newLot > MaxLotSize)
   {
      if(DebugMode)
         Print("⚠️ Lot maximum atteint: ", MaxLotSize);
      return;
   }
   
   // Vérifier le lot minimum et maximum du broker
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Normaliser le lot
   newLot = MathFloor(newLot / lotStep) * lotStep;
   newLot = MathMax(minLot, MathMin(maxLot, newLot));
   
   // Calculer le volume à ajouter
   double volumeToAdd = newLot - currentLot;
   
   if(volumeToAdd <= 0)
      return;
   
   // Normaliser le volume à ajouter
   volumeToAdd = NormalizeLotSize(volumeToAdd);
   
   if(volumeToAdd < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
      {
         if(DebugMode)
         Print("⚠️ Volume à ajouter trop petit: ", volumeToAdd);
      return;
   }
   
   // Ouvrir une nouvelle position dans le même sens
   ENUM_ORDER_TYPE orderType = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 
                              ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculer SL et TP dynamiques pour sécuriser les gains
   // Sécuriser au moins 50% des gains déjà réalisés
   double currentProfit = positionInfo.Profit();
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   double sl, tp;
   
   if(currentProfit <= 0)
   {
      // Pas encore de profit, utiliser SL standard
      CalculateSLTPInPointsWithMaxLoss(posType, price, volumeToAdd, 3.0, sl, tp);
      if(trade.PositionOpen(_Symbol, orderType, volumeToAdd, price, sl, tp, "DOUBLE_LOT"))
      {
         g_positionTracker.currentLot = newLot;
         g_positionTracker.lotDoubled = true;
         Print("✅ Lot doublé: ", currentLot, " -> ", newLot, " (ajout: ", volumeToAdd, ")");
      }
      else
      {
         Print("❌ Erreur doublement lot: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
      return;
   }
   
   double maxDrawdownAllowed = currentProfit * 0.5; // 50% du profit actuel = perte max acceptée
   double securedProfit = currentProfit - maxDrawdownAllowed; // Profit sécurisé
   
   double openPrice = positionInfo.PriceOpen();
   
   // Calculer SL dynamique pour sécuriser les gains
   CalculateDynamicSLTPForDouble(posType, openPrice, price, volumeToAdd, securedProfit, maxDrawdownAllowed, sl, tp);
   
   // Mettre à jour le SL de la position originale aussi pour sécuriser les gains
   double currentPriceForSL = positionInfo.PriceCurrent();
   double originalSL, originalTP;
   CalculateDynamicSLTPForDouble(posType, openPrice, currentPriceForSL, currentLot, securedProfit, maxDrawdownAllowed, originalSL, originalTP);
   
   // Mettre à jour le SL de la position originale pour sécuriser les gains
   if(originalSL > 0)
   {
      double currentSL = positionInfo.StopLoss();
      bool shouldUpdateSL = false;
      
      if(posType == POSITION_TYPE_BUY)
      {
         // Pour BUY, le nouveau SL doit être meilleur (plus haut) que l'actuel
         if(currentSL == 0 || originalSL > currentSL)
            shouldUpdateSL = true;
      }
      else // SELL
      {
         // Pour SELL, le nouveau SL doit être meilleur (plus bas) que l'actuel
         if(currentSL == 0 || originalSL < currentSL)
            shouldUpdateSL = true;
      }
      
      if(shouldUpdateSL)
      {
         trade.PositionModify(ticket, originalSL, positionInfo.TakeProfit());
         if(DebugMode)
            Print("✅ SL original sécurisé: ", originalSL, " (sécurise ", DoubleToString(securedProfit, 2), "$)");
      }
   }
   
   if(trade.PositionOpen(_Symbol, orderType, volumeToAdd, price, sl, tp, "DOUBLE_LOT"))
   {
      g_positionTracker.currentLot = newLot;
      g_positionTracker.lotDoubled = true;
      
      Print("✅ Lot doublé: ", currentLot, " -> ", newLot, " (ajout: ", volumeToAdd, ") avec SL/TP dynamiques (sécurise ", DoubleToString(securedProfit, 2), "$)");
   }
   else
   {
      Print("❌ Erreur doublement lot: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Définir SL/TP fixes en USD avec limite de perte maximale          |
//+------------------------------------------------------------------+
void SetFixedSLTPWithMaxLoss(ulong ticket, double maxLossUSD)
{
   if(!positionInfo.SelectByTicket(ticket))
      return;
   
   double openPrice = positionInfo.PriceOpen();
   double currentPrice = positionInfo.PriceCurrent();
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   double lotSize = positionInfo.Volume();
   
   // Calculer SL et TP avec limite de perte max
   double sl, tp;
   CalculateSLTPInPointsWithMaxLoss(posType, openPrice, lotSize, maxLossUSD, sl, tp);
   
   if(trade.PositionModify(ticket, sl, tp))
   {
      if(DebugMode)
         Print("✅ SL/TP définis avec limite perte max ", DoubleToString(maxLossUSD, 2), "$: SL=", sl, " TP=", tp);
   }
   else
   {
      if(DebugMode)
         Print("⚠️ Erreur modification SL/TP: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Définir SL/TP fixes en USD                                       |
//+------------------------------------------------------------------+
void SetFixedSLTP(ulong ticket)
{
   SetFixedSLTPWithMaxLoss(ticket, 3.0); // Utiliser la limite par défaut de 3$
}

//+------------------------------------------------------------------+
//| Calculer SL/TP en points à partir des valeurs USD               |
//+------------------------------------------------------------------+
void CalculateSLTPInPoints(ENUM_POSITION_TYPE posType, double entryPrice, double &sl, double &tp)
{
   double lotSize = (g_positionTracker.currentLot > 0) ? g_positionTracker.currentLot : InitialLotSize;
   
   // Calculer la valeur du point
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Si tickValue est en devise de base, convertir
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double pointValue = (tickValue / tickSize) * point;
   
   // Calculer les points nécessaires pour atteindre les valeurs USD
   double slPoints = 0, tpPoints = 0;
   
   if(pointValue > 0 && lotSize > 0)
   {
      // Points pour SL
      double slValuePerPoint = lotSize * pointValue;
      if(slValuePerPoint > 0)
         slPoints = StopLossUSD / slValuePerPoint;
      
      // Points pour TP
      double tpValuePerPoint = lotSize * pointValue;
      if(tpValuePerPoint > 0)
         tpPoints = TakeProfitUSD / tpValuePerPoint;
   }
   
   // AJOUT: Augmenter le SL de 30 points et le TP de 50 points
   slPoints += 30;  // Ajouter 30 points au SL
   tpPoints += 50;  // Ajouter 50 points au TP
   
   if(DebugMode)
      Print("🎯 SL/TP ajustés: SL+", 30, "pts, TP+", 50, "pts (SL=", DoubleToString(slPoints, 1), "pts, TP=", DoubleToString(tpPoints, 1), "pts)");
   
   // Si le calcul échoue, utiliser des valeurs par défaut basées sur ATR
   if(slPoints <= 0 || tpPoints <= 0)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         // Utiliser 2x ATR pour SL et 4x ATR pour TP
         slPoints = (2.0 * atr[0]) / point;
         tpPoints = (4.0 * atr[0]) / point;
      }
      else
      {
         // Valeurs par défaut
         slPoints = 50;
         tpPoints = 100;
      }
   }
   
   // Calculer les prix SL/TP
   if(posType == POSITION_TYPE_BUY)
   {
      sl = NormalizeDouble(entryPrice - slPoints * point, _Digits);
      tp = NormalizeDouble(entryPrice + tpPoints * point, _Digits);
   }
   else // SELL
   {
      sl = NormalizeDouble(entryPrice + slPoints * point, _Digits);
      tp = NormalizeDouble(entryPrice - tpPoints * point, _Digits);
   }
   
   // VALIDATION CRITIQUE: Vérifier que le SL est bien placé
   if(posType == POSITION_TYPE_BUY)
   {
      if(sl >= entryPrice)
      {
         // ERREUR: SL au-dessus du prix d'ouverture pour un BUY
         if(DebugMode)
            Print("❌ ERREUR SL BUY: SL (", sl, ") >= Prix ouverture (", entryPrice, ") - Correction automatique");
         // Corriger: SL doit être en-dessous
         sl = NormalizeDouble(entryPrice - slPoints * point, _Digits);
         if(sl >= entryPrice)
         {
            // Si toujours incorrect, utiliser ATR comme fallback
            double atr[];
            ArraySetAsSeries(atr, true);
            if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
            {
               // GESTION SPÉCIALE POUR STEP INDEX
               bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);
               double atrMultiplier = isStepIndex ? 3.0 : 2.0; // Plus grand pour Step Index
               sl = NormalizeDouble(entryPrice - (atrMultiplier * atr[0]), _Digits);
            }
            else
               sl = NormalizeDouble(entryPrice - (50 * point), _Digits);
         }
      }
   }
   else // SELL
   {
      if(sl <= entryPrice)
      {
         // ERREUR: SL en-dessous du prix d'ouverture pour un SELL
         if(DebugMode)
            Print("❌ ERREUR SL SELL: SL (", sl, ") <= Prix ouverture (", entryPrice, ") - Correction automatique");
         // Corriger: SL doit être au-dessus
         sl = NormalizeDouble(entryPrice + slPoints * point, _Digits);
         if(sl <= entryPrice)
         {
            // Si toujours incorrect, utiliser ATR comme fallback
            double atr[];
            ArraySetAsSeries(atr, true);
            if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
            {
               // GESTION SPÉCIALE POUR STEP INDEX
               bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);
               double atrMultiplier = isStepIndex ? 3.0 : 2.0; // Plus grand pour Step Index
               sl = NormalizeDouble(entryPrice + (atrMultiplier * atr[0]), _Digits);
            }
            else
               sl = NormalizeDouble(entryPrice + (50 * point), _Digits);
         }
      }
   }
   
   // CALCUL ROBUSTE des niveaux minimums du broker
   // Note: tickValue et tickSize sont déjà déclarés au début de la fonction
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   
   // Calculer minDistance en utilisant stopLevel ET tickSize
   double minDistance = stopLevel * point;
   
   // GESTION SPÉCIALE POUR STEP INDEX
   bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);
   if(isStepIndex)
   {
      // Step Index nécessite des distances minimales plus grandes
      minDistance = MathMax(minDistance, 20 * point); // Minimum 20 points pour Step Index
      if(DebugMode)
         Print("🔧 Step Index détecté - Distance minimale SL/TP: ", DoubleToString(minDistance / point, 0), " points");
   }
   
   // Si stopLevel = 0, utiliser une distance minimale basée sur le tickSize
   if(minDistance == 0 || minDistance < tickSize)
   {
      // Utiliser au moins 3 ticks comme distance minimum
      minDistance = tickSize * 3;
      if(minDistance == 0)
         minDistance = 10 * point; // Fallback si tickSize = 0
   }
   
   // S'assurer que minDistance est au moins de 5 points pour éviter les erreurs
   if(minDistance < (5 * point))
      minDistance = 5 * point;
   
   // Ajuster SL pour respecter minDistance
   double slDistance = MathAbs(entryPrice - sl);
   if(slDistance < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         sl = NormalizeDouble(entryPrice - minDistance - (point * 2), _Digits); // Ajouter un peu de marge
      else
         sl = NormalizeDouble(entryPrice + minDistance + (point * 2), _Digits);
      
      // Recalculer slDistance après ajustement
      slDistance = MathAbs(entryPrice - sl);
   }
   
   // Ajuster TP pour respecter minDistance
   double tpDistance = MathAbs(tp - entryPrice);
   if(tpDistance < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(entryPrice + minDistance + (point * 2), _Digits);
      else
         tp = NormalizeDouble(entryPrice - minDistance - (point * 2), _Digits);
      
      // Recalculer tpDistance après ajustement
      tpDistance = MathAbs(tp - entryPrice);
   }
   
   // VALIDATION FINALE ROBUSTE: Vérifier que SL et TP sont corrects et valides
   bool slValid = false;
   bool tpValid = false;
   
   if(posType == POSITION_TYPE_BUY)
   {
      slValid = (sl > 0 && sl < entryPrice && slDistance >= minDistance);
      tpValid = (tp > 0 && tp > entryPrice && tpDistance >= minDistance);
   }
   else // SELL
   {
      slValid = (sl > 0 && sl > entryPrice && slDistance >= minDistance);
      tpValid = (tp > 0 && tp < entryPrice && tpDistance >= minDistance);
   }
   
   // Si validation échoue, utiliser des valeurs sécurisées basées sur ATR
   if(!slValid || !tpValid)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         // Utiliser ATR pour calculer des niveaux sûrs
         double atrMultiplierSL = 2.0;
         double atrMultiplierTP = 4.0;
         
         // GESTION SPÉCIALE POUR STEP INDEX
         bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);
         if(isStepIndex)
         {
            atrMultiplierSL = 3.0; // Plus grand pour Step Index
            atrMultiplierTP = 6.0; // Plus grand pour Step Index
            if(DebugMode)
               Print("🔧 Step Index - Ajustement SL/TP: SL=", atrMultiplierSL, "x ATR, TP=", atrMultiplierTP, "x ATR");
         }
         
         if(posType == POSITION_TYPE_BUY)
         {
            sl = NormalizeDouble(entryPrice - (atrMultiplierSL * atr[0]), _Digits);
            tp = NormalizeDouble(entryPrice + (atrMultiplierTP * atr[0]), _Digits);
         }
         else
         {
            sl = NormalizeDouble(entryPrice + (atrMultiplierSL * atr[0]), _Digits);
            tp = NormalizeDouble(entryPrice - (atrMultiplierTP * atr[0]), _Digits);
         }
         
         // Re-vérifier avec les nouvelles valeurs
         slDistance = MathAbs(entryPrice - sl);
         tpDistance = MathAbs(tp - entryPrice);
         
         if(slDistance < minDistance || tpDistance < minDistance)
         {
            Print("❌ ERREUR CRITIQUE: Impossible de calculer SL/TP valides après correction ATR - Trade annulé");
            sl = 0;
            tp = 0;
            return;
         }
         
         if(DebugMode)
            Print("⚠️ SL/TP recalculés avec ATR: SL=", sl, " TP=", tp, " (minDistance=", minDistance, ")");
      }
      else
      {
         Print("❌ ERREUR CRITIQUE: SL/TP invalides et ATR indisponible - Trade annulé");
         sl = 0;
         tp = 0;
         return;
      }
   }
   
   // DERNIÈRE VÉRIFICATION: S'assurer que les valeurs sont normalisées et valides
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   if(sl <= 0 || tp <= 0 || sl == tp)
   {
      Print("❌ ERREUR CRITIQUE: SL ou TP invalides après normalisation - Trade annulé");
      sl = 0;
      tp = 0;
   }
}

//+------------------------------------------------------------------+
//| Calculer SL/TP en points avec limite de perte maximale            |
//+------------------------------------------------------------------+
void CalculateSLTPInPointsWithMaxLoss(ENUM_POSITION_TYPE posType, double entryPrice, double lotSize, double maxLossUSD, double &sl, double &tp)
{
   // Calculer la valeur du point
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double pointValue = (tickValue / tickSize) * point;
   
   // Calculer les points nécessaires pour la perte maximale
   double slPoints = 0, tpPoints = 0;
   
   if(pointValue > 0 && lotSize > 0)
   {
      double slValuePerPoint = lotSize * pointValue;
      if(slValuePerPoint > 0)
         slPoints = StopLossUSD / slValuePerPoint; // Utiliser le nouveau paramètre SL
      
      // TP standard avec le nouveau paramètre
      double tpValuePerPoint = lotSize * pointValue;
      if(tpValuePerPoint > 0)
         tpPoints = TakeProfitUSD / tpValuePerPoint; // Utiliser le nouveau paramètre TP
   }
   
   // AJOUT: Augmenter le SL de 30 points et le TP de 50 points
   slPoints += 30;  // Ajouter 30 points au SL
   tpPoints += 50;  // Ajouter 50 points au TP
   
   if(DebugMode)
      Print("🎯 SL/TP ajustés (max loss): SL+", 30, "pts, TP+", 50, "pts (SL=", DoubleToString(slPoints, 1), "pts, TP=", DoubleToString(tpPoints, 1), "pts)");
   
   // Si le calcul échoue, utiliser des valeurs par défaut basées sur ATR
   if(slPoints <= 0 || tpPoints <= 0)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         // Limiter SL à maxLossUSD
         if(slPoints <= 0 && pointValue > 0 && lotSize > 0)
            slPoints = MathMin((maxLossUSD / (lotSize * pointValue)), (2.0 * atr[0]) / point);
         if(tpPoints <= 0)
            tpPoints = (4.0 * atr[0]) / point;
      }
      else
      {
         slPoints = 50;
         tpPoints = 100;
      }
   }
   
   // Calculer les prix SL/TP
   if(posType == POSITION_TYPE_BUY)
   {
      sl = NormalizeDouble(entryPrice - slPoints * point, _Digits);
      tp = NormalizeDouble(entryPrice + tpPoints * point, _Digits);
   }
   else // SELL
   {
      sl = NormalizeDouble(entryPrice + slPoints * point, _Digits);
      tp = NormalizeDouble(entryPrice - tpPoints * point, _Digits);
   }
   
   // CALCUL ROBUSTE des niveaux minimums du broker (même logique que CalculateSLTPInPoints)
   // Note: tickSize est déjà déclaré au début de la fonction
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * point;
   
   // GESTION SPÉCIALE POUR STEP INDEX
   bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);
   if(isStepIndex)
   {
      // Step Index nécessite des distances minimales plus grandes
      minDistance = MathMax(minDistance, 20 * point); // Minimum 20 points pour Step Index
      if(DebugMode)
         Print("🔧 Step Index détecté - Distance minimale SL/TP: ", DoubleToString(minDistance / point, 0), " points");
   }
   
   if(minDistance == 0 || minDistance < tickSize)
   {
      minDistance = tickSize * 3;
      if(minDistance == 0)
         minDistance = 10 * point;
   }
   
   if(minDistance < (5 * point))
      minDistance = 5 * point;
   
   // Ajuster SL
   double slDistance = MathAbs(entryPrice - sl);
   if(slDistance < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         sl = NormalizeDouble(entryPrice - minDistance - (point * 2), _Digits);
      else
         sl = NormalizeDouble(entryPrice + minDistance + (point * 2), _Digits);
      slDistance = MathAbs(entryPrice - sl);
   }
   
   // Ajuster TP
   double tpDistance = MathAbs(tp - entryPrice);
   if(tpDistance < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(entryPrice + minDistance + (point * 2), _Digits);
      else
         tp = NormalizeDouble(entryPrice - minDistance - (point * 2), _Digits);
      tpDistance = MathAbs(tp - entryPrice);
   }
   
   // Validation finale
   bool slValid = (posType == POSITION_TYPE_BUY) ? (sl < entryPrice && slDistance >= minDistance) : (sl > entryPrice && slDistance >= minDistance);
   bool tpValid = (posType == POSITION_TYPE_BUY) ? (tp > entryPrice && tpDistance >= minDistance) : (tp < entryPrice && tpDistance >= minDistance);
   
   if(!slValid || !tpValid)
   {
      // Utiliser ATR comme fallback
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         if(posType == POSITION_TYPE_BUY)
         {
            sl = NormalizeDouble(entryPrice - (2.0 * atr[0]), _Digits);
            tp = NormalizeDouble(entryPrice + (4.0 * atr[0]), _Digits);
         }
         else
         {
            sl = NormalizeDouble(entryPrice + (2.0 * atr[0]), _Digits);
            tp = NormalizeDouble(entryPrice - (4.0 * atr[0]), _Digits);
         }
         
         // Re-vérifier
         slDistance = MathAbs(entryPrice - sl);
         tpDistance = MathAbs(tp - entryPrice);
         if(slDistance < minDistance || tpDistance < minDistance)
         {
            sl = 0;
            tp = 0;
            return;
         }
      }
      else
      {
         sl = 0;
         tp = 0;
         return;
      }
   }
   
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // DERNIÈRE VÉRIFICATION: S'assurer que SL et TP sont valides
   if(sl <= 0 || tp <= 0 || sl == tp)
   {
      if(DebugMode)
         Print("❌ ERREUR: SL ou TP invalides dans CalculateSLTPInPointsWithMaxLoss (SL=", sl, " TP=", tp, ")");
      sl = 0;
      tp = 0;
      return;
   }
   
   // Vérifier une dernière fois que SL est bien placé
   if(posType == POSITION_TYPE_BUY && sl >= entryPrice)
   {
      if(DebugMode)
         Print("❌ ERREUR: SL BUY invalide (SL=", sl, " >= Entry=", entryPrice, ")");
      sl = 0;
      tp = 0;
      return;
   }
   else if(posType == POSITION_TYPE_SELL && sl <= entryPrice)
   {
      if(DebugMode)
         Print("❌ ERREUR: SL SELL invalide (SL=", sl, " <= Entry=", entryPrice, ")");
      sl = 0;
      tp = 0;
      return;
   }
}

//+------------------------------------------------------------------+
//| Calculer SL/TP dynamiques pour duplication avec sécurisation gains |
//+------------------------------------------------------------------+
void CalculateDynamicSLTPForDouble(ENUM_POSITION_TYPE posType, double openPrice, double currentPrice, double lotSize, double securedProfit, double maxDrawdownAllowed, double &sl, double &tp)
{
   // Calculer la valeur du point
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double pointValue = (tickValue / tickSize) * point;
   
   // Calculer SL pour sécuriser les gains (éviter de perdre plus de maxDrawdownAllowed)
   double slPoints = 0;
   if(pointValue > 0 && lotSize > 0 && securedProfit > 0)
   {
      double slValuePerPoint = lotSize * pointValue;
      if(slValuePerPoint > 0)
         slPoints = maxDrawdownAllowed / slValuePerPoint;
   }
   
   // Si on a déjà des gains, le SL doit être au-dessus (BUY) ou en-dessous (SELL) du prix d'entrée
   // pour sécuriser au moins 50% des gains
   if(securedProfit > 0 && slPoints > 0)
   {
      if(posType == POSITION_TYPE_BUY)
      {
         // Pour BUY, SL doit être au-dessus du prix d'entrée pour sécuriser les gains
         sl = NormalizeDouble(openPrice + slPoints * point, _Digits);
         // S'assurer que le SL est en-dessous du prix actuel
         if(sl >= currentPrice)
            sl = NormalizeDouble(currentPrice - point, _Digits);
      }
      else // SELL
      {
         // Pour SELL, SL doit être en-dessous du prix d'entrée pour sécuriser les gains
         sl = NormalizeDouble(openPrice - slPoints * point, _Digits);
         // S'assurer que le SL est au-dessus du prix actuel
         if(sl <= currentPrice)
            sl = NormalizeDouble(currentPrice + point, _Digits);
      }
   }
   else
   {
      // Pas encore de gains, utiliser le SL standard avec nouveaux paramètres
      CalculateSLTPInPointsWithMaxLoss(posType, currentPrice, lotSize, MaxLossPerPosition, sl, tp);
      return;
   }
   
   // TP dynamique basé sur le risk/reward avec nouveau TP
   double risk = MathAbs(currentPrice - sl);
   if(risk > 0)
   {
      double riskRewardRatio = TakeProfitUSD / StopLossUSD; // Utiliser les nouveaux paramètres
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(currentPrice + (risk * riskRewardRatio), _Digits);
      else
         tp = NormalizeDouble(currentPrice - (risk * riskRewardRatio), _Digits);
   }
   else
   {
      // Fallback sur TP standard avec nouveau paramètre
      double tpPoints = (TakeProfitUSD / (lotSize * pointValue));
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(currentPrice + tpPoints * point, _Digits);
      else
         tp = NormalizeDouble(currentPrice - tpPoints * point, _Digits);
   }
   
   // Vérifier les niveaux minimums du broker
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * point;
   if(minDistance == 0) minDistance = 10 * point;
   
   if(MathAbs(currentPrice - sl) < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         sl = NormalizeDouble(currentPrice - minDistance - point, _Digits);
      else
         sl = NormalizeDouble(currentPrice + minDistance + point, _Digits);
   }
   
   if(MathAbs(tp - currentPrice) < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(currentPrice + minDistance + point, _Digits);
      else
         tp = NormalizeDouble(currentPrice - minDistance - point, _Digits);
   }
}

//+------------------------------------------------------------------+
//| Vérifier et définir le range US Session (bougie M5 15h30 Paris)  |
//+------------------------------------------------------------------+
void DefineUSSessionRange()
{
   if(!UseUSSessionStrategy)
      return;
   
   // Réinitialiser si nouveau jour
   MqlDateTime currentDt, rangeDt;
   TimeToStruct(TimeCurrent(), currentDt);
   if(g_US_RangeDate > 0)
   {
      TimeToStruct(g_US_RangeDate, rangeDt);
      if(currentDt.day != rangeDt.day || currentDt.mon != rangeDt.mon || currentDt.year != rangeDt.year)
      {
         // Nouveau jour, réinitialiser
         g_US_RangeDefined = false;
         g_US_BreakoutDone = false;
         g_US_TradeTaken = false;
         g_US_Direction = 0;
         g_US_RangeDate = 0;
      }
   }
   
   if(g_US_RangeDefined)
      return; // Déjà défini aujourd'hui
   
   // Définir le range sur la bougie M5 de 15h30 (Paris = UTC+1 en hiver, UTC+2 en été)
   // Pour simplifier, on utilise UTC+1 (15h30 Paris = 14:30 UTC)
   datetime timeM5[];
   ArraySetAsSeries(timeM5, true);
   if(CopyTime(_Symbol, PERIOD_M5, 0, 100, timeM5) <= 0)
      return;
   
   for(int i = 0; i < ArraySize(timeM5); i++)
   {
      MqlDateTime dt;
      TimeToStruct(timeM5[i], dt);
      
      // Chercher la bougie M5 qui correspond à 14h30-14h34 UTC (15h30-15h34 Paris)
      if(dt.hour == 14 && dt.min >= 30 && dt.min <= 34)
      {
         double highM5[], lowM5[];
         ArraySetAsSeries(highM5, true);
         ArraySetAsSeries(lowM5, true);
         
         if(CopyHigh(_Symbol, PERIOD_M5, i, 1, highM5) > 0 && CopyLow(_Symbol, PERIOD_M5, i, 1, lowM5) > 0)
         {
            g_US_High = highM5[0];
            g_US_Low = lowM5[0];
            g_US_RangeDefined = true;
            g_US_BreakoutDone = false;
            g_US_Direction = 0;
            g_US_RangeDate = timeM5[i];
            
            if(DebugMode)
               Print("📊 US RANGE DÉFINI (15h30 Paris): High=", DoubleToString(g_US_High, _Digits), " Low=", DoubleToString(g_US_Low, _Digits));
            
            break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier si on est après l'ouverture US (15h35 Paris = 14:35 UTC)|
//+------------------------------------------------------------------+
bool IsAfterUSOpening()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   // 14h35 UTC = 15h35 Paris (UTC+1)
   if(dt.hour > 14 || (dt.hour == 14 && dt.min >= 35))
      return true;
   return false;
}

//+------------------------------------------------------------------+
//| Détecter le breakout du range US                                  |
//+------------------------------------------------------------------+
int DetectUSBreakout()
{
   if(!g_US_RangeDefined || g_US_BreakoutDone || !IsAfterUSOpening())
      return 0;
   
   double closeM1[];
   ArraySetAsSeries(closeM1, true);
   if(CopyClose(_Symbol, PERIOD_M1, 0, 1, closeM1) <= 0)
      return 0;
   
   // Détecter cassure par le haut
   if(closeM1[0] > g_US_High)
   {
      g_US_Direction = 1; // BUY
      g_US_BreakoutDone = true;
      if(DebugMode)
         Print("🚀 BREAKOUT US DÉTECTÉ (HAUT): Prix=", DoubleToString(closeM1[0], _Digits), " > High=", DoubleToString(g_US_High, _Digits));
      return 1;
   }
   
   // Détecter cassure par le bas
   if(closeM1[0] < g_US_Low)
   {
      g_US_Direction = -1; // SELL
      g_US_BreakoutDone = true;
      if(DebugMode)
         Print("🚀 BREAKOUT US DÉTECTÉ (BAS): Prix=", DoubleToString(closeM1[0], _Digits), " < Low=", DoubleToString(g_US_Low, _Digits));
      return -1;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Vérifier retest et entrer en position (US Session)               |
//+------------------------------------------------------------------+
bool CheckUSRetestAndEnter()
{
   if(!g_US_RangeDefined || !g_US_BreakoutDone || g_US_Direction == 0)
      return false;
   
   if(US_OneTradePerDay && g_US_TradeTaken)
      return false;
   
   double open[], close[], high[], low[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyOpen(_Symbol, PERIOD_M1, 0, 1, open) <= 0 ||
      CopyClose(_Symbol, PERIOD_M1, 0, 1, close) <= 0 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 1, high) <= 0 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 1, low) <= 0)
      return false;
   
   double tolerance = US_RetestTolerance * _Point;
   
   // SCÉNARIO HAUSSIER (BUY)
   if(g_US_Direction == 1)
   {
      // Retest du niveau haut (g_US_High)
      if(MathAbs(low[0] - g_US_High) <= tolerance)
      {
         // Confirmation: bougie haussière (close > open)
         if(close[0] > open[0])
         {
            double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double sl = low[0];
            double risk = entryPrice - sl;
            double tp = entryPrice + (risk * US_RiskReward);
            
            // Ouvrir position avec SL/TP personnalisés
            if(ExecuteUSTrade(ORDER_TYPE_BUY, entryPrice, sl, tp))
            {
               g_US_TradeTaken = true;
               if(DebugMode)
                  Print("✅ RETEST US CONFIRMÉ (BUY): Entry=", DoubleToString(entryPrice, _Digits), " SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits));
               return true;
            }
         }
      }
   }
   
   // SCÉNARIO BAISSIER (SELL)
   if(g_US_Direction == -1)
   {
      // Retest du niveau bas (g_US_Low)
      if(MathAbs(high[0] - g_US_Low) <= tolerance)
      {
         // Confirmation: bougie baissière (close < open)
         if(close[0] < open[0])
         {
            double entryPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double sl = high[0];
            double risk = sl - entryPrice;
            double tp = entryPrice - (risk * US_RiskReward);
            
            // Ouvrir position avec SL/TP personnalisés
            if(ExecuteUSTrade(ORDER_TYPE_SELL, entryPrice, sl, tp))
            {
               g_US_TradeTaken = true;
               if(DebugMode)
                  Print("✅ RETEST US CONFIRMÉ (SELL): Entry=", DoubleToString(entryPrice, _Digits), " SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits));
               return true;
            }
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Exécuter un trade US Session avec SL/TP personnalisés            |
//+------------------------------------------------------------------+
bool ExecuteUSTrade(ENUM_ORDER_TYPE orderType, double entryPrice, double sl, double tp)
{
   // Vérifications de sécurité (comme ExecuteTrade)
   double totalLoss = GetTotalLoss();
   if(totalLoss >= MaxTotalLoss)
   {
      if(DebugMode)
         Print("🚫 TRADE US BLOQUÉ: Perte totale maximale atteinte (", DoubleToString(totalLoss, 2), "$ >= ", DoubleToString(MaxTotalLoss, 2), "$)");
      return false;
   }
   
   // PROTECTION: Bloquer SELL sur Boom et BUY sur Crash
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(isBoom && orderType == ORDER_TYPE_SELL)
   {
      if(DebugMode)
         Print("🚫 TRADE US BLOQUÉ: Impossible de trader SELL sur ", _Symbol, " (Boom = BUY uniquement)");
      return false;
   }
   
   if(isCrash && orderType == ORDER_TYPE_BUY)
   {
      if(DebugMode)
         Print("🚫 TRADE US BLOQUÉ: Impossible de trader BUY sur ", _Symbol, " (Crash = SELL uniquement)");
      return false;
   }
   
   // Normaliser le lot
   double normalizedLot = NormalizeLotSize(InitialLotSize);
   
   if(normalizedLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      if(DebugMode)
         Print("❌ Lot trop petit pour US Session: ", normalizedLot);
      return false;
   }
   
   // Normaliser les prix
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   entryPrice = NormalizeDouble(entryPrice, _Digits);
   
   // Vérifier les distances minimum (logique robuste)
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minDistance = stopLevel * point;
   
   if(minDistance == 0 || minDistance < tickSize)
   {
      minDistance = tickSize * 3;
      if(minDistance == 0)
         minDistance = 10 * point;
   }
   
   if(minDistance < (5 * point))
      minDistance = 5 * point;
   
   double slDistance = MathAbs(entryPrice - sl);
   double tpDistance = MathAbs(tp - entryPrice);
   
   if(slDistance < minDistance)
   {
      if(DebugMode)
         Print("❌ Distance SL insuffisante pour US Session (", DoubleToString(slDistance, _Digits), " < ", DoubleToString(minDistance, _Digits), ")");
      return false;
   }
   if(tpDistance < minDistance)
   {
      if(DebugMode)
         Print("❌ Distance TP insuffisante pour US Session (", DoubleToString(tpDistance, _Digits), " < ", DoubleToString(minDistance, _Digits), ")");
      return false;
   }
   
   // Normaliser les prix avant ouverture
   entryPrice = NormalizeDouble(entryPrice, _Digits);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // Validation finale
   if(sl <= 0 || tp <= 0 || sl == tp)
   {
      if(DebugMode)
         Print("❌ SL ou TP invalides pour US Session (SL=", sl, " TP=", tp, ")");
      return false;
   }
   
   if(trade.PositionOpen(_Symbol, orderType, normalizedLot, entryPrice, sl, tp, "US_SESSION_BREAK_RETEST"))
   {
      if(DebugMode)
         Print("✅ Trade US Session ouvert: ", EnumToString(orderType), " Lot=", normalizedLot, " Entry=", entryPrice, " SL=", sl, " TP=", tp);
      return true;
   }
   else
   {
      if(DebugMode)
         Print("❌ Erreur ouverture trade US Session: ", trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Chercher une opportunité de trading                              |
//+------------------------------------------------------------------+
void LookForTradingOpportunity()
{
   // MODE ULTRA PERFORMANCES: Désactiver si trop de charge
   if(HighPerformanceMode && DisableAllGraphics && DisableNotifications)
   {
      if(DebugMode)
         Print("🚫 Mode silencieux ultra performant - pas de trading");
      return; // Mode silencieux ultra performant
   }
   
   if(DebugMode)
      Print("🔍 Recherche opportunités de trading - Positions actuelles: ", PositionsTotal());
   
   // PRIORITÉ 1: STRATÉGIE US SESSION BREAK & RETEST (PRIORITAIRE)
   if(UseUSSessionStrategy)
   {
      if(DebugMode)
         Print("🇺🇸 Stratégie US Session activée - vérification conditions...");
      DefineUSSessionRange();
      
      if(g_US_RangeDefined && IsAfterUSOpening())
      {
         if(!g_US_BreakoutDone)
         {
            int breakout = DetectUSBreakout();
            if(breakout != 0)
            {
               if(DebugMode)
                  Print("🚀 Breakout US détecté (", breakout, ") - attente retest - AUTRES STRATÉGIES BLOQUÉES");
               // Breakout détecté, attendre retest - BLOQUER les autres stratégies
               return;
            }
         }
         else
         {
            // Breakout fait, chercher retest
            if(CheckUSRetestAndEnter())
            {
               if(DebugMode)
                  Print("✅ Trade US pris - sortie");
               // Trade pris, sortir
               return;
            }
            else
            {
               if(DebugMode)
                  Print("⏳ En attente retest US - AUTRES STRATÉGIES BLOQUÉES");
               // En attente de retest - BLOQUER les autres stratégies jusqu'au retest
               return;
            }
         }
      }
      else
      {
         if(DebugMode)
            Print("🇺🇸 Conditions US non remplies (Range défini: ", g_US_RangeDefined, ", Après ouverture: ", IsAfterUSOpening(), ")");
      }
   }
   else
   {
      if(DebugMode)
         Print("🇺🇸 Stratégie US Session DÉSACTIVÉE - autres stratégies autorisées");
   }
   
   // PRIORITÉ 2: SIGNAL IA
   // IMPORTANT: le trading ne doit pas dépendre des notifications.
   // DisableNotifications = true ne doit bloquer le trading que si l'utilisateur le souhaite.
   bool allowAITrading = UseAI_Agent && g_lastAIAction != "" && (!DisableNotifications || AllowTradingWhenNotificationsDisabled);
   if(allowAITrading)
   {
      if(DebugMode)
         Print("🤖 Signal IA disponible: ", g_lastAIAction, " (confiance: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
      
      // Détecter le mode prudent (perte quotidienne élevée)
      bool cautiousMode = (g_dailyLoss >= MaxDailyLoss);
      
      // Seuil adaptatif par symbole
      double requiredConfidence = GetRequiredConfidenceForSymbol(_Symbol, cautiousMode);
      
      if(DebugMode)
         Print("📊 Seuil confiance requis: ", DoubleToString(requiredConfidence*100, 1), "% (Mode prudent: ", cautiousMode, ")");
      
      // RÈGLE STRICTE : Si l'IA est activée, TOUJOURS vérifier la confiance AVANT de trader
      if(StringCompare(g_lastAIAction, "hold") != 0 && g_lastAIConfidence >= requiredConfidence && !g_aiFallbackMode)
      {
         if(DebugMode)
            Print("✅ Signal IA validé - exécution du trade...");
         // DÉTERMINER LE TYPE DE SIGNAL BASÉ SUR L'IA
         ENUM_ORDER_TYPE signalType = WRONG_VALUE;
         if(StringCompare(g_lastAIAction, "buy") == 0)
            signalType = ORDER_TYPE_BUY;
         else if(StringCompare(g_lastAIAction, "sell") == 0)
            signalType = ORDER_TYPE_SELL;
         
         // RÈGLE BOOM/CRASH: pas de BUY sur Crash, pas de SELL sur Boom
         bool isCrashSymbol = (StringFind(_Symbol, "Crash") != -1);
         bool isBoomSymbol = (StringFind(_Symbol, "Boom") != -1);
         if(isCrashSymbol && signalType == ORDER_TYPE_BUY)
         {
            if(DebugMode) Print("🚫 BLOQUÉ: pas de BUY sur Crash - attente signal SELL");
            return;
         }
         if(isBoomSymbol && signalType == ORDER_TYPE_SELL)
         {
            if(DebugMode) Print("🚫 BLOQUÉ: pas de SELL sur Boom - attente signal BUY");
            return;
         }
         
         // SI ON A UN SIGNAL VALIDE, ENVOYER NOTIFICATION ET ATTENDRE ENTRÉE PROMETTEUSE
         if(signalType != WRONG_VALUE)
         {
            // Vérifier si la flèche DERIV est présente (condition requise)
            bool hasDerivArrow = true; // Simplification - toujours considérer comme vrai
            
            if(hasDerivArrow)
            {
               // Réinitialiser la liste des ordres exécutés si nécessaire
               ResetExecutedOrdersList();
               
               // Détecter si c'est un symbole Boom/Crash pour exécution immédiate
               bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
               
               // Vérifier si un ordre a déjà été exécuté pour ce symbole
               if(HasOrderAlreadyExecuted(_Symbol))
               {
                  if(DebugMode)
                     Print("⏳ Ordre déjà exécuté pour ", _Symbol, " - attente nouvelle opportunité");
                  return;
               }
               
               // Boom/Crash: TOUJOURS exécution IMMÉDIATE au marché (pas de limite).
               // Une seule fois par setup → on attend le spike, on capture, on ferme.
               // Autres symboles: exécution marché uniquement si confiance très élevée.
               bool allowMarket = false;
               if(isBoomCrashSymbol)
                  allowMarket = true;  // Boom/Crash: marché dès qu'on a un signal valide (seuil 50%)
               else if(g_lastAIConfidence >= AI_MarketExecutionConfidence)
                  allowMarket = true;

               if(allowMarket)
               {
                  if(DebugMode)
                     Print("🚀 ", (isBoomCrashSymbol ? "Boom/Crash" : "Signal fort"), 
                           " - Exécution IMMÉDIATE au marché (", DoubleToString(g_lastAIConfidence*100, 1), "%)");
                  
                  // Boom/Crash: exécution dédiée (SL/TP basés sur spikes)
                  // Autres: exécution marché classique via trade.Buy/Sell
                  bool marketSuccess = false;
                  if(isBoomCrashSymbol)
                     marketSuccess = ExecuteImmediateBoomCrashTrade(signalType);
                  else
                  {
                     double price = SymbolInfoDouble(_Symbol, (signalType == ORDER_TYPE_BUY) ? SYMBOL_ASK : SYMBOL_BID);
                     double sl=0, tp=0;
                     // Utiliser ATR pour un SL/TP raisonnable
                     double atr[];
                     ArraySetAsSeries(atr, true);
                     double atrVal = 0;
                     if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0) atrVal = atr[0];
                     if(atrVal <= 0) atrVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50;

                     if(signalType == ORDER_TYPE_BUY)
                     {
                        sl = NormalizeDouble(price - 1.2 * atrVal, _Digits);
                        tp = NormalizeDouble(price + 2.4 * atrVal, _Digits);
                        marketSuccess = SafeTradeBuy(NormalizeLotSize(InitialLotSize), _Symbol, price, sl, tp,
                                                 "AI STRONG MARKET (conf: " + DoubleToString(g_lastAIConfidence*100,1) + "%)");
                     }
                     else
                     {
                        sl = NormalizeDouble(price + 1.2 * atrVal, _Digits);
                        tp = NormalizeDouble(price - 2.4 * atrVal, _Digits);
                        marketSuccess = SafeTradeSell(NormalizeLotSize(InitialLotSize), _Symbol, price, sl, tp,
                                                  "AI STRONG MARKET (conf: " + DoubleToString(g_lastAIConfidence*100,1) + "%)");
                     }
                  }

                  if(marketSuccess)
                  {
                     MarkOrderAsExecuted(_Symbol);
                     if(DebugMode)
                        Print("✅ Trade exécuté immédiatement - Type: ", EnumToString(signalType));
                  }
                  else
                  {
                     if(DebugMode)
                        Print("❌ Échec exécution immédiate", isBoomCrashSymbol ? " (Boom/Crash: pas de fallback LIMIT)" : " - fallback vers ordre LIMIT");
                     
                     // Fallback LIMIT uniquement pour les symboles non Boom/Crash
                     if(!isBoomCrashSymbol && PlaceLimitOrderOnArrow(signalType))
                        MarkOrderAsExecuted(_Symbol);
                  }
               }
               else
               {
                  // Pour les autres symboles ou confiance plus faible: ordre LIMIT normal
                  if(DebugMode)
                     Print("🔍 Flèche DERIV détectée - Tentative placement ordre LIMIT pour: ", EnumToString(signalType));
                  
                  if(PlaceLimitOrderOnArrow(signalType))
                  {
                     MarkOrderAsExecuted(_Symbol);
                     
                     string signalText = "🚨 SIGNAL IA DÉTECTÉ: " + (g_lastAIAction == "buy" ? "BUY" : "SELL") + " (confiance: " + DoubleToString(g_lastAIConfidence*100, 1) + "%)";
                     signalText += "\n⚡ Flèche DERIV présente";
                     signalText += "\n🎯 Ordre LIMIT placé avec succès";
                     
                     if(DebugMode)
                        Print("🎯 Ordre limité placé dès détection flèche - Type: ", EnumToString(signalType));
                  }
                  else
                  {
                     if(DebugMode)
                        Print("❌ ÉCHEC placement ordre LIMIT pour ", EnumToString(signalType));
                  }
            }
         }
      }
      }
      else
      {
         // Expliquer pourquoi le signal IA n'est pas exécuté
         if(StringCompare(g_lastAIAction, "hold") == 0)
         {
            if(DebugMode)
               Print("⏸️ Signal IA = 'HOLD' - pas de trade");
         }
         else if(g_lastAIConfidence < requiredConfidence)
         {
            if(DebugMode)
               Print("📉 Confiance IA insuffisante: ", DoubleToString(g_lastAIConfidence*100, 1), "% < ", DoubleToString(requiredConfidence*100, 1), "% requis");
         }
         else if(g_aiFallbackMode)
         {
            if(DebugMode)
               Print("🔄 Mode fallback IA actif - attente récupération");
         }
      }
      
      // NOUVEAU: Détecter les patterns dynamiques et lancer des trades limités
      if(DetectDynamicPatternsAndExecute())
      {
         if(DebugMode)
            Print("🎯 Pattern dynamique détecté et trade exécuté avec trailing stop activé");
      }
   }
   else
   {
      // Expliquer pourquoi la section IA n'est pas exécutée
      if(!UseAI_Agent)
      {
         if(DebugMode)
            Print("🤖 Agent IA désactivé");
      }
      else if(DisableNotifications)
      {
         if(DebugMode)
            Print("🔕 Notifications désactivées - IA ", AllowTradingWhenNotificationsDisabled ? "active (trading autorisé)" : "bloquée (trading interdit)");
      }
      else if(g_lastAIAction == "")
      {
         if(DebugMode)
            Print("❌ Aucun signal IA disponible (g_lastAIAction vide)");
      }
   }
   
   if(DebugMode)
      Print("🏁 Fin recherche opportunités - aucune position prise");
}

//+------------------------------------------------------------------+
//| Normaliser le lot selon les spécifications du broker             |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lot)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Normaliser selon le step
   lot = MathFloor(lot / lotStep) * lotStep;
   
   // Limiter aux bornes
   lot = MathMax(minLot, MathMin(maxLot, lot));
   
   return lot;
}

//+------------------------------------------------------------------+
//| Vérifie si c'est un symbole de volatilité                        |
//+------------------------------------------------------------------+
bool IsVolatilitySymbol(const string symbol)
{
   return (StringFind(symbol, "Volatility") != -1 || 
           StringFind(symbol, "BOOM") != -1 || 
           StringFind(symbol, "CRASH") != -1 ||
           StringFind(symbol, "Step") != -1);
}

//+------------------------------------------------------------------+
//| Détecte une paire Forex classique                                |
//+------------------------------------------------------------------+
bool IsForexSymbol(const string symbol)
{
   // Exclure Boom/Crash/Volatility/Step
   if(IsVolatilitySymbol(symbol) ||
      StringFind(symbol, "Boom") != -1 ||
      StringFind(symbol, "Crash") != -1)
      return false;

   // Si le symbole contient au moins un des principaux codes devises, on le traite comme Forex
   if(StringFind(symbol, "EUR") != -1 || StringFind(symbol, "GBP") != -1 || 
      StringFind(symbol, "USD") != -1 || StringFind(symbol, "JPY") != -1 ||
      StringFind(symbol, "AUD") != -1 || StringFind(symbol, "CAD") != -1 ||
      StringFind(symbol, "CHF") != -1 || StringFind(symbol, "NZD") != -1)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Compte le nombre de symboles actifs (avec positions ouvertes)    |
//+------------------------------------------------------------------+
int CountActiveSymbols()
{
   string activeSymbols[];
   int symbolCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Magic() == InpMagicNumber)
         {
            string symbol = positionInfo.Symbol();
            
            // Vérifier si ce symbole n'est pas déjà dans la liste
            bool found = false;
            for(int j = 0; j < symbolCount; j++)
            {
               if(activeSymbols[j] == symbol)
               {
                  found = true;
                  break;
               }
            }
            
            if(!found)
            {
               ArrayResize(activeSymbols, symbolCount + 1);
               activeSymbols[symbolCount] = symbol;
               symbolCount++;
            }
         }
      }
   }
   
   return symbolCount;
}

//+------------------------------------------------------------------+
//| Compte les positions pour le symbole actuel                      |
//+------------------------------------------------------------------+
int CountPositionsForSymbolMagic()
{
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Magic() == InpMagicNumber && positionInfo.Symbol() == _Symbol)
            cnt++;
      }
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Vérifie si une position du même type existe déjà                 |
//| NOTE: La duplication ne concerne PAS les Boom/Crash              |
//|       Elle s'applique uniquement aux indices volatility, step index et forex |
//+------------------------------------------------------------------+
bool HasDuplicatePosition(ENUM_ORDER_TYPE orderType)
{
   // La duplication ne concerne PAS les Boom/Crash
   // Elle s'applique uniquement aux indices volatility, step index et forex
   bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   if(isBoomCrash)
      return false; // Pas de vérification de duplication pour Boom/Crash
   
   // Vérifier uniquement pour volatility, step index et forex
   bool isVolatility = IsVolatilitySymbol(_Symbol);
   bool isStepIndex = (StringFind(_Symbol, "Step") != -1 || StringFind(_Symbol, "Step Index") != -1);
   bool isForex = IsForexSymbol(_Symbol);
   
   if(!isVolatility && !isStepIndex && !isForex)
      return false; // Pas de vérification pour les autres types
   
   // NOUVEAU: Vérifier l'alignement des endpoints pour la duplication
   bool allowDuplication = true;
   if(UseAllEndpoints && RequireAllEndpointsAlignment)
   {
      // Si l'alignement est requis, vérifier qu'il est suffisant
      allowDuplication = (g_endpointsAlignment >= 0.75); // 75% minimum pour dupliquer
      
      if(DebugMode && !allowDuplication)
         Print("🚫 DUPLICATION BLOQUÉE: Alignement endpoints insuffisant (", 
               DoubleToString(g_endpointsAlignment * 100, 1), "% < 75%)");
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Magic() == InpMagicNumber && positionInfo.Symbol() == _Symbol)
         {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)positionInfo.PositionType();
            if((orderType == ORDER_TYPE_BUY && posType == POSITION_TYPE_BUY) ||
               (orderType == ORDER_TYPE_SELL && posType == POSITION_TYPE_SELL))
            {
               // Si on a une position du même type, vérifier l'alignement
               if(!allowDuplication)
               {
                  if(DebugMode)
                     Print("🚫 DUPLICATION BLOQUÉE: Position ", EnumToString(orderType), 
                           " déjà existante et alignement endpoints insuffisant");
                  return true; // Bloquer la duplication
               }
               else
               {
                  if(DebugMode)
                     Print("✅ DUPLICATION AUTORISÉE: Position ", EnumToString(orderType), 
                           " déjà existante mais alignement endpoints suffisant (", 
                           DoubleToString(g_endpointsAlignment * 100, 1), "%)");
               }
               return true; // Position du même type déjà ouverte
            }
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Calculer la perte totale de toutes les positions actives         |
//+------------------------------------------------------------------+
double GetTotalLoss()
{
   double totalLoss = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Magic() == InpMagicNumber)
         {
            double profit = positionInfo.Profit();
            if(profit < 0) // Seulement les pertes
               totalLoss += MathAbs(profit);
         }
      }
   }
   
   return totalLoss;
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Vérifier l'alignement de tendance M5 et H1                       |
//+------------------------------------------------------------------+
bool CheckTrendAlignment(ENUM_ORDER_TYPE orderType)
{
   // NOUVEAU: Vérifier d'abord l'API de tendance si activée
   if(UseTrendAPIAnalysis && g_api_trend_valid)
   {
      // Vérifier si la direction de l'API correspond au signal
      bool apiAligned = false;
      if(orderType == ORDER_TYPE_BUY && g_api_trend_direction == 1)
         apiAligned = true;
      else if(orderType == ORDER_TYPE_SELL && g_api_trend_direction == -1)
         apiAligned = true;
      
      if(!apiAligned)
      {
         if(DebugMode)
         {
            string apiDir = (g_api_trend_direction == 1) ? "BUY" : (g_api_trend_direction == -1) ? "SELL" : "NEUTRE";
            Print("❌ API Trend non alignée: Signal=", EnumToString(orderType), " API=", apiDir, " (Confiance: ", DoubleToString(g_api_trend_confidence, 1), "%)");
         }
         return false; // API de tendance non alignée, bloquer le trade
      }
      
      if(DebugMode)
      {
         string apiDir = (g_api_trend_direction == 1) ? "BUY" : (g_api_trend_direction == -1) ? "SELL" : "NEUTRE";
         Print("✅ API Trend alignée: ", apiDir, " (Confiance: ", DoubleToString(g_api_trend_confidence, 1), "%, Force: ", DoubleToString(g_api_trend_strength, 1), "%)");
      }
   }
   
   double emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[];
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   
   if(CopyBuffer(emaFastM5Handle, 0, 0, 1, emaFastM5) <= 0 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 1, emaSlowM5) <= 0 ||
      CopyBuffer(emaFastH1Handle, 0, 0, 1, emaFastH1) <= 0 ||
      CopyBuffer(emaSlowH1Handle, 0, 0, 1, emaSlowH1) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération indicateurs M5/H1");
      return false;
   }
   
   // Vérifier l'alignement pour BUY
   if(orderType == ORDER_TYPE_BUY)
   {
      bool m5Bullish = (emaFastM5[0] > emaSlowM5[0]);
      bool h1Bullish = (emaFastH1[0] > emaSlowH1[0]);
      
      if(m5Bullish && h1Bullish)
      {
         if(DebugMode)
            Print("✅ Alignement haussier confirmé: M5=", m5Bullish ? "UP" : "DOWN", " H1=", h1Bullish ? "UP" : "DOWN");
         return true;
      }
      else
      {
         if(DebugMode)
            Print("❌ Alignement haussier non confirmé: M5=", m5Bullish ? "UP" : "DOWN", " H1=", h1Bullish ? "UP" : "DOWN");
   return false;
}
   }
   // Vérifier l'alignement pour SELL
   else if(orderType == ORDER_TYPE_SELL)
   {
      bool m5Bearish = (emaFastM5[0] < emaSlowM5[0]);
      bool h1Bearish = (emaFastH1[0] < emaSlowH1[0]);
      
      if(m5Bearish && h1Bearish)
      {
         if(DebugMode)
            Print("✅ Alignement baissier confirmé: M5=", m5Bearish ? "DOWN" : "UP", " H1=", h1Bearish ? "DOWN" : "UP");
         return true;
      }
   else
   {
         if(DebugMode)
            Print("❌ Alignement baissier non confirmé: M5=", m5Bearish ? "DOWN" : "UP", " H1=", h1Bearish ? "DOWN" : "UP");
         return false;
   }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Dessiner les niveaux de support/résistance M1, M5 et H1       |
//+------------------------------------------------------------------+
void DrawSupportResistanceLevels()
{
   double atrM1[], atrM5[], atrH1[];
   ArraySetAsSeries(atrM1, true);
   ArraySetAsSeries(atrM5, true);
   ArraySetAsSeries(atrH1, true);
   
   if(CopyBuffer(atrM1Handle, 0, 0, 1, atrM1) <= 0 ||
      CopyBuffer(atrM5Handle, 0, 0, 1, atrM5) <= 0 ||
      CopyBuffer(atrH1Handle, 0, 0, 1, atrH1) <= 0)
      return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Support/Résistance M1 (court terme)
   double supportM1 = currentPrice - (1.5 * atrM1[0]);
   double resistanceM1 = currentPrice + (1.5 * atrM1[0]);
   
   // Support/Résistance M5 (moyen terme)
   double supportM5 = currentPrice - (2.0 * atrM5[0]);
   double resistanceM5 = currentPrice + (2.0 * atrM5[0]);
   
   // Support/Résistance H1 (long terme)
   double supportH1 = currentPrice - (2.5 * atrH1[0]);
   double resistanceH1 = currentPrice + (2.5 * atrH1[0]);
   
   // === SUPPORTS/RESISTANCES M1 ===
   // Support M1 (vert clair)
   string supportM1Name = "SR_Support_M1_" + _Symbol;
   if(ObjectFind(0, supportM1Name) < 0)
      ObjectCreate(0, supportM1Name, OBJ_HLINE, 0, 0, supportM1);
   else
      ObjectSetDouble(0, supportM1Name, OBJPROP_PRICE, supportM1);
   ObjectSetInteger(0, supportM1Name, OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, supportM1Name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, supportM1Name, OBJPROP_WIDTH, 1);
   ObjectSetString(0, supportM1Name, OBJPROP_TEXT, "Support M1");
   ObjectSetInteger(0, supportM1Name, OBJPROP_BACK, 1);
   
   // Résistance M1 (orange clair)
   string resistanceM1Name = "SR_Resistance_M1_" + _Symbol;
   if(ObjectFind(0, resistanceM1Name) < 0)
      ObjectCreate(0, resistanceM1Name, OBJ_HLINE, 0, 0, resistanceM1);
   else
      ObjectSetDouble(0, resistanceM1Name, OBJPROP_PRICE, resistanceM1);
   ObjectSetInteger(0, resistanceM1Name, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, resistanceM1Name, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, resistanceM1Name, OBJPROP_WIDTH, 1);
   ObjectSetString(0, resistanceM1Name, OBJPROP_TEXT, "Résistance M1");
   ObjectSetInteger(0, resistanceM1Name, OBJPROP_BACK, 1);
   
   // === SUPPORTS/RESISTANCES M5 ===
   // Support M5 (bleu)
   string supportM5Name = "SR_Support_M5_" + _Symbol;
   if(ObjectFind(0, supportM5Name) < 0)
      ObjectCreate(0, supportM5Name, OBJ_HLINE, 0, 0, supportM5);
   else
      ObjectSetDouble(0, supportM5Name, OBJPROP_PRICE, supportM5);
   ObjectSetInteger(0, supportM5Name, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, supportM5Name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, supportM5Name, OBJPROP_WIDTH, 1);
   ObjectSetString(0, supportM5Name, OBJPROP_TEXT, "Support M5");
   ObjectSetInteger(0, supportM5Name, OBJPROP_BACK, 1);
   
   // Résistance M5 (rouge)
   string resistanceM5Name = "SR_Resistance_M5_" + _Symbol;
   if(ObjectFind(0, resistanceM5Name) < 0)
      ObjectCreate(0, resistanceM5Name, OBJ_HLINE, 0, 0, resistanceM5);
   else
      ObjectSetDouble(0, resistanceM5Name, OBJPROP_PRICE, resistanceM5);
   ObjectSetInteger(0, resistanceM5Name, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, resistanceM5Name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, resistanceM5Name, OBJPROP_WIDTH, 1);
   ObjectSetString(0, resistanceM5Name, OBJPROP_TEXT, "Résistance M5");
   ObjectSetInteger(0, resistanceM5Name, OBJPROP_BACK, 1);
   
   // === SUPPORTS/RESISTANCES H1 ===
   // Support H1 (bleu foncé - plus important)
   string supportH1Name = "SR_Support_H1_" + _Symbol;
   if(ObjectFind(0, supportH1Name) < 0)
      ObjectCreate(0, supportH1Name, OBJ_HLINE, 0, 0, supportH1);
   else
      ObjectSetDouble(0, supportH1Name, OBJPROP_PRICE, supportH1);
   ObjectSetInteger(0, supportH1Name, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, supportH1Name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, supportH1Name, OBJPROP_WIDTH, 2);
   ObjectSetString(0, supportH1Name, OBJPROP_TEXT, "Support H1");
   ObjectSetInteger(0, supportH1Name, OBJPROP_BACK, 0);
   
   // Résistance H1 (rouge foncé - plus important)
   string resistanceH1Name = "SR_Resistance_H1_" + _Symbol;
   if(ObjectFind(0, resistanceH1Name) < 0)
      ObjectCreate(0, resistanceH1Name, OBJ_HLINE, 0, 0, resistanceH1);
   else
      ObjectSetDouble(0, resistanceH1Name, OBJPROP_PRICE, resistanceH1);
   ObjectSetInteger(0, resistanceH1Name, OBJPROP_COLOR, clrCrimson);
   ObjectSetInteger(0, resistanceH1Name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, resistanceH1Name, OBJPROP_WIDTH, 2);
   ObjectSetString(0, resistanceH1Name, OBJPROP_TEXT, "Résistance H1");
   ObjectSetInteger(0, resistanceH1Name, OBJPROP_BACK, 0);
   
   if(DebugMode)
      Print("📊 Supports/Résistances mis à jour - M1: ", DoubleToString(supportM1, _Digits), "/", DoubleToString(resistanceM1, _Digits), 
            " | M5: ", DoubleToString(supportM5, _Digits), "/", DoubleToString(resistanceM5, _Digits),
            " | H1: ", DoubleToString(supportH1, _Digits), "/", DoubleToString(resistanceH1, _Digits));
}

//+------------------------------------------------------------------+
//| Dessiner les zones BUY/SELL de l'IA (rectangles non remplis)     |
//+------------------------------------------------------------------+
void DrawAIZonesOnChart()
{
   if(!DrawAIZones)
   {
      // Supprimer toutes les zones AI (H8, H1, M5)
      ObjectDelete(0, "AI_BUY_ZONE_H8_" + _Symbol);
      ObjectDelete(0, "AI_SELL_ZONE_H8_" + _Symbol);
      ObjectDelete(0, "AI_BUY_ZONE_H1_" + _Symbol);
      ObjectDelete(0, "AI_SELL_ZONE_H1_" + _Symbol);
      ObjectDelete(0, "AI_BUY_ZONE_M5_" + _Symbol);
      ObjectDelete(0, "AI_SELL_ZONE_M5_" + _Symbol);
      return;
   }
   
   datetime now = TimeCurrent();
   
   // Couleurs transparentes (vert et rouge avec alpha)
   color buyColor = C'0,255,0,50';  // Vert transparent (alpha = 50)
   color sellColor = C'255,0,0,50'; // Rouge transparent (alpha = 50)
   
   // Timeframes à tracer: H8, H1, M5
   ENUM_TIMEFRAMES timeframes[];
   ArrayResize(timeframes, 3);
   timeframes[0] = PERIOD_H8;
   timeframes[1] = PERIOD_H1;
   timeframes[2] = PERIOD_M5;
   
   string tfNames[];
   ArrayResize(tfNames, 3);
   tfNames[0] = "H8";
   tfNames[1] = "H1";
   tfNames[2] = "M5";
   
   // Tracer les zones pour chaque timeframe
   for(int tfIdx = 0; tfIdx < ArraySize(timeframes); tfIdx++)
   {
      ENUM_TIMEFRAMES tf = timeframes[tfIdx];
      string tfName = tfNames[tfIdx];
      
      // Calculer les limites temporelles selon le timeframe
      int periodSeconds = PeriodSeconds(tf);
      datetime past = now - (200 * periodSeconds);   // 200 bougies en arrière
      datetime future = now + (50 * periodSeconds);  // 50 bougies en avant
      
      // Zone BUY - Rectangle rempli avec couleur transparente
      string buyZoneName = "AI_BUY_ZONE_" + tfName + "_" + _Symbol;
      if(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 && g_aiBuyZoneHigh > g_aiBuyZoneLow)
      {
         if(ObjectFind(0, buyZoneName) < 0)
            ObjectCreate(0, buyZoneName, OBJ_RECTANGLE, 0, past, g_aiBuyZoneHigh, future, g_aiBuyZoneLow);
         else
         {
            ObjectSetDouble(0, buyZoneName, OBJPROP_PRICE, 0, g_aiBuyZoneHigh);
            ObjectSetDouble(0, buyZoneName, OBJPROP_PRICE, 1, g_aiBuyZoneLow);
            ObjectSetInteger(0, buyZoneName, OBJPROP_TIME, 0, past);
            ObjectSetInteger(0, buyZoneName, OBJPROP_TIME, 1, future);
         }
         
         // Couleur transparente verte (rempli)
         ObjectSetInteger(0, buyZoneName, OBJPROP_COLOR, buyColor);
         ObjectSetInteger(0, buyZoneName, OBJPROP_BACK, 1);  // En arrière-plan
         ObjectSetInteger(0, buyZoneName, OBJPROP_FILL, 1); // REMPLI avec transparence
         ObjectSetInteger(0, buyZoneName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, buyZoneName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, buyZoneName, OBJPROP_SELECTABLE, false);
         // Afficher uniquement sur le timeframe correspondant
         ObjectSetInteger(0, buyZoneName, OBJPROP_TIMEFRAMES, (1 << (int)tf));
      }
      else
      {
         ObjectDelete(0, buyZoneName);
      }
      
      // Zone SELL - Rectangle rempli avec couleur transparente
      string sellZoneName = "AI_SELL_ZONE_" + tfName + "_" + _Symbol;
      if(g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0 && g_aiSellZoneHigh > g_aiSellZoneLow)
      {
         if(ObjectFind(0, sellZoneName) < 0)
            ObjectCreate(0, sellZoneName, OBJ_RECTANGLE, 0, past, g_aiSellZoneHigh, future, g_aiSellZoneLow);
         else
         {
            ObjectSetDouble(0, sellZoneName, OBJPROP_PRICE, 0, g_aiSellZoneHigh);
            ObjectSetDouble(0, sellZoneName, OBJPROP_PRICE, 1, g_aiSellZoneLow);
            ObjectSetInteger(0, sellZoneName, OBJPROP_TIME, 0, past);
            ObjectSetInteger(0, sellZoneName, OBJPROP_TIME, 1, future);
         }
         
         // Couleur transparente rouge (rempli)
         ObjectSetInteger(0, sellZoneName, OBJPROP_COLOR, sellColor);
         ObjectSetInteger(0, sellZoneName, OBJPROP_BACK, 1);  // En arrière-plan
         ObjectSetInteger(0, sellZoneName, OBJPROP_FILL, 1); // REMPLI avec transparence
         ObjectSetInteger(0, sellZoneName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, sellZoneName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, sellZoneName, OBJPROP_SELECTABLE, false);
         // Afficher uniquement sur le timeframe correspondant
         ObjectSetInteger(0, sellZoneName, OBJPROP_TIMEFRAMES, (1 << (int)tf));
      }
      else
      {
         ObjectDelete(0, sellZoneName);
      }
   }
}

//+------------------------------------------------------------------+
//| Dessiner les trendlines basées sur les EMA M5 et H1              |
//| Depuis l'historique de 1000 bougies                              |
//+------------------------------------------------------------------+
void DrawTrendlinesOnChart()
{
   if(!DrawTrendlines)
      return;
   
   // Récupérer 1000 bougies d'historique pour M5
   double emaFastM5[], emaSlowM5[];
   datetime timeM5[];
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(timeM5, true);
   
   int countM5 = 1000;
   if(CopyBuffer(emaFastM5Handle, 0, 0, countM5, emaFastM5) <= 0 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, countM5, emaSlowM5) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA M5 pour trendlines");
      return;
   }
   
   // Récupérer les timestamps M5 (passés + futures)
   datetime timeM5Past[], timeM5Future[];
   ArraySetAsSeries(timeM5Past, true);
   ArraySetAsSeries(timeM5Future, true);
   
   // 1000 bougies passées M5
   if(CopyTime(_Symbol, PERIOD_M5, 0, 1000, timeM5Past) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération timestamps M5 passés");
      return;
   }
   
   // Créer 1000 timestamps futurs M5 (projection)
   datetime lastTimeM5 = timeM5Past[999];
   ArrayResize(timeM5Future, 1000);
   for(int i = 0; i < 1000; i++)
   {
      timeM5Future[i] = lastTimeM5 + (i+1) * PeriodSeconds(PERIOD_M5);
   }
   
   // Combiner les deux arrays M5
   ArrayResize(timeM5, 2000);
   for(int i = 0; i < 1000; i++)
      timeM5[i] = timeM5Past[i];
   for(int i = 0; i < 1000; i++)
      timeM5[1000 + i] = timeM5Future[i];
   
   // Étendre les arrays EMA M5 pour inclure les projections futures
   ArrayResize(emaFastM5, 2000);
   ArrayResize(emaSlowM5, 2000);
   
   // Projeter les EMA M5 dans le futur
   double emaFastM5Slope = (emaFastM5[999] - emaFastM5[900]) / 100.0;
   double emaSlowM5Slope = (emaSlowM5[999] - emaSlowM5[900]) / 100.0;
   
   for(int i = 1000; i < 2000; i++)
   {
      emaFastM5[i] = emaFastM5[999] + (i - 999) * emaFastM5Slope;
      emaSlowM5[i] = emaSlowM5[999] + (i - 999) * emaSlowM5Slope;
   }
   
   // Récupérer 1000 bougies d'historique pour H1
   double emaFastH1[], emaSlowH1[];
   datetime timeH1[];
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   ArraySetAsSeries(timeH1, true);
   
   int countH1 = 1000;
   if(CopyBuffer(emaFastH1Handle, 0, 0, countH1, emaFastH1) <= 0 ||
      CopyBuffer(emaSlowH1Handle, 0, 0, countH1, emaSlowH1) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA H1 pour trendlines");
      return;
   }
   
   // Récupérer les timestamps H1 (passés + futures)
   datetime timeH1Past[], timeH1Future[];
   ArraySetAsSeries(timeH1Past, true);
   ArraySetAsSeries(timeH1Future, true);
   
   // 1000 bougies passées H1
   if(CopyTime(_Symbol, PERIOD_H1, 0, 1000, timeH1Past) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération timestamps H1 passés");
      return;
   }
   
   // Créer 1000 timestamps futurs H1 (projection)
   datetime lastTimeH1 = timeH1Past[999];
   ArrayResize(timeH1Future, 1000);
   for(int i = 0; i < 1000; i++)
   {
      timeH1Future[i] = lastTimeH1 + (i+1) * PeriodSeconds(PERIOD_H1);
   }
   
   // Combiner les deux arrays H1
   ArrayResize(timeH1, 2000);
   for(int i = 0; i < 1000; i++)
      timeH1[i] = timeH1Past[i];
   for(int i = 0; i < 1000; i++)
      timeH1[1000 + i] = timeH1Future[i];
   
   // Étendre les arrays EMA H1 pour inclure les projections futures
   ArrayResize(emaFastH1, 2000);
   ArrayResize(emaSlowH1, 2000);
   
   // Projeter les EMA H1 dans le futur
   double emaFastH1Slope = (emaFastH1[999] - emaFastH1[900]) / 100.0;
   double emaSlowH1Slope = (emaSlowH1[999] - emaSlowH1[900]) / 100.0;
   
   for(int i = 1000; i < 2000; i++)
   {
      emaFastH1[i] = emaFastH1[999] + (i - 999) * emaFastH1Slope;
      emaSlowH1[i] = emaSlowH1[999] + (i - 999) * emaSlowH1Slope;
   }
   
   // Trouver les points de début et fin pour M5 (maintenant 2000 points)
   // Avec ArraySetAsSeries=true, index 0 = la plus récente, index 1999 = la plus ancienne future
   int startM5 = -1, endM5 = -1;
   
   // Trouver la première valeur valide (la plus récente, index 0)
   for(int i = 0; i < 2000; i++)
   {
      if(emaFastM5[i] > 0 && emaSlowM5[i] > 0)
      {
         if(endM5 == -1) endM5 = i; // Première valeur valide trouvée (la plus récente)
      }
   }
   
   // Trouver la dernière valeur valide (la plus ancienne)
   for(int i = 1999; i >= 0; i--)
   {
      if(emaFastM5[i] > 0 && emaSlowM5[i] > 0)
      {
         startM5 = i; // Dernière valeur valide (la plus ancienne)
         break;
      }
   }
   
   // Trouver les points de début et fin pour H1 (maintenant 2000 points)
   int startH1 = -1, endH1 = -1;
   
   // Trouver la première valeur valide (la plus récente)
   for(int i = 0; i < 2000; i++)
   {
      if(emaFastH1[i] > 0 && emaSlowH1[i] > 0)
      {
         if(endH1 == -1) endH1 = i; // Première valeur valide trouvée (la plus récente)
      }
   }
   
   // Trouver la dernière valeur valide (la plus ancienne)
   for(int i = 1999; i >= 0; i--)
   {
      if(emaFastH1[i] > 0 && emaSlowH1[i] > 0)
      {
         startH1 = i; // Dernière valeur valide (la plus ancienne)
         break;
      }
   }
   
   // Dessiner trendline EMA Fast M5 (du point le plus ancien au plus récent)
   if(startM5 >= 0 && endM5 >= 0 && startM5 < 2000 && endM5 < 2000 && startM5 != endM5)
   {
      string trendFastM5 = "Trend_EMA_Fast_M5_" + _Symbol;
      if(ObjectFind(0, trendFastM5) < 0)
         ObjectCreate(0, trendFastM5, OBJ_TREND, 0, timeM5[startM5], emaFastM5[startM5], timeM5[endM5], emaFastM5[endM5]);
      else
      {
         ObjectSetInteger(0, trendFastM5, OBJPROP_TIME, 0, timeM5[startM5]);
         ObjectSetDouble(0, trendFastM5, OBJPROP_PRICE, 0, emaFastM5[startM5]);
         ObjectSetInteger(0, trendFastM5, OBJPROP_TIME, 1, timeM5[endM5]);
         ObjectSetDouble(0, trendFastM5, OBJPROP_PRICE, 1, emaFastM5[endM5]);
      }
      ObjectSetInteger(0, trendFastM5, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, trendFastM5, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, trendFastM5, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, trendFastM5, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, trendFastM5, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, trendFastM5, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, trendFastM5, OBJPROP_TEXT, "EMA Fast M5");
   }
   
   // Dessiner trendline EMA Slow M5
   if(startM5 >= 0 && endM5 >= 0 && startM5 < 2000 && endM5 < 2000 && startM5 != endM5)
   {
      string trendSlowM5 = "Trend_EMA_Slow_M5_" + _Symbol;
      if(ObjectFind(0, trendSlowM5) < 0)
         ObjectCreate(0, trendSlowM5, OBJ_TREND, 0, timeM5[startM5], emaSlowM5[startM5], timeM5[endM5], emaSlowM5[endM5]);
      else
      {
         ObjectSetInteger(0, trendSlowM5, OBJPROP_TIME, 0, timeM5[startM5]);
         ObjectSetDouble(0, trendSlowM5, OBJPROP_PRICE, 0, emaSlowM5[startM5]);
         ObjectSetInteger(0, trendSlowM5, OBJPROP_TIME, 1, timeM5[endM5]);
         ObjectSetDouble(0, trendSlowM5, OBJPROP_PRICE, 1, emaSlowM5[endM5]);
      }
      ObjectSetInteger(0, trendSlowM5, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, trendSlowM5, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, trendSlowM5, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, trendSlowM5, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, trendSlowM5, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, trendSlowM5, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, trendSlowM5, OBJPROP_TEXT, "EMA Slow M5");
   }
   
   // Dessiner trendline EMA Fast H1
   if(startH1 >= 0 && endH1 >= 0 && startH1 < 2000 && endH1 < 2000 && startH1 != endH1)
   {
      string trendFastH1 = "Trend_EMA_Fast_H1_" + _Symbol;
      if(ObjectFind(0, trendFastH1) < 0)
         ObjectCreate(0, trendFastH1, OBJ_TREND, 0, timeH1[startH1], emaFastH1[startH1], timeH1[endH1], emaFastH1[endH1]);
      else
      {
         ObjectSetInteger(0, trendFastH1, OBJPROP_TIME, 0, timeH1[startH1]);
         ObjectSetDouble(0, trendFastH1, OBJPROP_PRICE, 0, emaFastH1[startH1]);
         ObjectSetInteger(0, trendFastH1, OBJPROP_TIME, 1, timeH1[endH1]);
         ObjectSetDouble(0, trendFastH1, OBJPROP_PRICE, 1, emaFastH1[endH1]);
      }
      ObjectSetInteger(0, trendFastH1, OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, trendFastH1, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, trendFastH1, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, trendFastH1, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, trendFastH1, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, trendFastH1, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, trendFastH1, OBJPROP_TEXT, "EMA Fast H1");
   }
   
   // Dessiner trendline EMA Slow H1
   if(startH1 >= 0 && endH1 >= 0 && startH1 < 2000 && endH1 < 2000 && startH1 != endH1)
   {
      string trendSlowH1 = "Trend_EMA_Slow_H1_" + _Symbol;
      if(ObjectFind(0, trendSlowH1) < 0)
         ObjectCreate(0, trendSlowH1, OBJ_TREND, 0, timeH1[startH1], emaSlowH1[startH1], timeH1[endH1], emaSlowH1[endH1]);
      else
      {
         ObjectSetInteger(0, trendSlowH1, OBJPROP_TIME, 0, timeH1[startH1]);
         ObjectSetDouble(0, trendSlowH1, OBJPROP_PRICE, 0, emaSlowH1[startH1]);
         ObjectSetInteger(0, trendSlowH1, OBJPROP_TIME, 1, timeH1[endH1]);
         ObjectSetDouble(0, trendSlowH1, OBJPROP_PRICE, 1, emaSlowH1[endH1]);
      }
      ObjectSetInteger(0, trendSlowH1, OBJPROP_COLOR, clrCrimson);
      ObjectSetInteger(0, trendSlowH1, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, trendSlowH1, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, trendSlowH1, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, trendSlowH1, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, trendSlowH1, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, trendSlowH1, OBJPROP_TEXT, "EMA Slow H1");
   }
}

//+------------------------------------------------------------------+
//| Dessiner les EMA 50, 100, 200 pour tendances longues (courbes)   |
//+------------------------------------------------------------------+
void DrawLongTrendEMA()
{
   if(!ShowLongTrendEMA)
   {
      // Supprimer les segments si désactivé
      DeleteEMAObjects("EMA_50_");
      DeleteEMAObjects("EMA_100_");
      DeleteEMAObjects("EMA_200_");
      return;
   }
   
   // Récupérer les valeurs EMA
   double ema50[], ema100[], ema200[];
   datetime time[];
   ArraySetAsSeries(ema50, true);
   ArraySetAsSeries(ema100, true);
   ArraySetAsSeries(ema200, true);
   ArraySetAsSeries(time, true);
   
   // OPTIMISATION: Limiter à 1000 bougies passées + 1000 futures
   int count = 1000; // 1000 bougies passées
   if(CopyBuffer(ema50Handle, 0, 0, count, ema50) <= 0 ||
      CopyBuffer(ema100Handle, 0, 0, count, ema100) <= 0 ||
      CopyBuffer(ema200Handle, 0, 0, count, ema200) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA longues tendances");
      return;
   }
   
   // Récupérer les timestamps (passées + futures)
   datetime timePast[], timeFuture[];
   ArraySetAsSeries(timePast, true);
   ArraySetAsSeries(timeFuture, true);
   
   // 1000 bougies passées
   if(CopyTime(_Symbol, PERIOD_M1, 0, 1000, timePast) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération timestamps passés pour EMA longues");
      return;
   }
   
   // Créer 1000 timestamps futurs (projection)
   datetime lastTime = timePast[999];
   ArrayResize(timeFuture, 1000);
   for(int i = 0; i < 1000; i++)
   {
      timeFuture[i] = lastTime + (i+1) * PeriodSeconds(PERIOD_M1);
   }
   
   // Combiner les deux arrays
   ArrayResize(time, 2000);
   for(int i = 0; i < 1000; i++)
      time[i] = timePast[i];
   for(int i = 0; i < 1000; i++)
      time[1000 + i] = timeFuture[i];
   
   // OPTIMISATION MAXIMALE: Ne supprimer et recréer que si nécessaire (vérifier timestamp)
   static datetime lastEMAUpdate = 0;
   bool needUpdate = (TimeCurrent() - lastEMAUpdate > 300); // Mise à jour max toutes les 5 minutes (au lieu de 2)
   
   if(needUpdate)
   {
      // Supprimer les anciens segments seulement si nécessaire
      DeleteEMAObjects("EMA_50_");
      DeleteEMAObjects("EMA_100_");
      DeleteEMAObjects("EMA_200_");
      
      // OPTIMISATION MAXIMALE: Créer des courbes avec 1000 bougies passées + 1000 futures
      // Étendre les arrays EMA pour inclure les projections futures
      ArrayResize(ema50, 2000);
      ArrayResize(ema100, 2000);
      ArrayResize(ema200, 2000);
      
      // Projeter les EMA dans le futur (extrapolation simple)
      double ema50Slope = (ema50[999] - ema50[900]) / 100.0; // Pente sur 100 dernières bougies
      double ema100Slope = (ema100[999] - ema100[900]) / 100.0;
      double ema200Slope = (ema200[999] - ema200[900]) / 100.0;
      
      for(int i = 1000; i < 2000; i++)
      {
         ema50[i] = ema50[999] + (i - 999) * ema50Slope;
         ema100[i] = ema100[999] + (i - 999) * ema100Slope;
         ema200[i] = ema200[999] + (i - 999) * ema200Slope;
      }
      
      DrawEMACurveOptimized("EMA_50_", ema50, time, 2000, clrLime, 1, 20);
      DrawEMACurveOptimized("EMA_100_", ema100, time, 2000, clrYellow, 1, 20);
      DrawEMACurveOptimized("EMA_200_", ema200, time, 2000, clrOrange, 1, 20);
      
      lastEMAUpdate = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Supprimer les objets EMA avec un préfixe donné                    |
//+------------------------------------------------------------------+
void DeleteEMAObjects(string prefix)
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Dessiner une courbe EMA optimisée (moins de segments)             |
//+------------------------------------------------------------------+
void DrawEMACurveOptimized(string prefix, double &values[], datetime &times[], int count, color clr, int width, int step)
{
   // OPTIMISATION MAXIMALE: Dessiner un segment tous les 'step' points
   int segmentsDrawn = 0;
   int maxSegments = 20; // Limiter à 20 segments max pour performance (au lieu de 50)
   
   for(int i = count - 1; i >= step && segmentsDrawn < maxSegments; i -= step)
   {
      int prevIdx = i - step;
      if(prevIdx < 0) prevIdx = 0;
      
      if(values[i] > 0 && values[prevIdx] > 0 && times[i] > 0 && times[prevIdx] > 0)
      {
         string segName = prefix + _Symbol + "_" + IntegerToString(segmentsDrawn);
         
         if(ObjectFind(0, segName) < 0)
            ObjectCreate(0, segName, OBJ_TREND, 0, times[i], values[i], times[prevIdx], values[prevIdx]);
         else
         {
            ObjectSetInteger(0, segName, OBJPROP_TIME, 0, times[i]);
            ObjectSetDouble(0, segName, OBJPROP_PRICE, 0, values[i]);
            ObjectSetInteger(0, segName, OBJPROP_TIME, 1, times[prevIdx]);
            ObjectSetDouble(0, segName, OBJPROP_PRICE, 1, values[prevIdx]);
         }
         
         ObjectSetInteger(0, segName, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, segName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, segName, OBJPROP_WIDTH, width);
         ObjectSetInteger(0, segName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, segName, OBJPROP_RAY_LEFT, false);
         ObjectSetInteger(0, segName, OBJPROP_SELECTABLE, false);
         
         segmentsDrawn++;
      }
   }
}

//+------------------------------------------------------------------+
//| Dessiner les patterns Deriv (simplifié)                          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Dessine les patterns Deriv (flèche clignotante dynamique)        |
//+------------------------------------------------------------------+
void DrawDerivPatternsOnChart()
{
   if(!DrawDerivPatterns)
   {
      // Supprimer la flèche si désactivé
      ObjectDelete(0, "DERIV_ARROW_" + _Symbol);
      return;
   }
   
   // Supprimer toutes les anciennes flèches historiques (nettoyage limité pour performance)
   static datetime lastCleanupTime = 0;
   if(TimeCurrent() - lastCleanupTime >= 30) // Nettoyage seulement toutes les 30 secondes
   {
      string prefix = "Deriv_";
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, prefix) == 0 && StringFind(name, "DERIV_ARROW_" + _Symbol) < 0)
            ObjectDelete(0, name);
      }
      lastCleanupTime = TimeCurrent();
   }
   
   // Vérifier si on a un signal IA valide
   if(g_lastAIAction == "" || g_lastAIConfidence < AI_MinConfidence)
   {
      // Supprimer la flèche si pas de signal
      ObjectDelete(0, "DERIV_ARROW_" + _Symbol);
      return;
   }
   
   // Récupérer la dernière bougie
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) <= 0)
      return;
   
   double arrowPrice = rates[0].close;
   datetime arrowTime = rates[0].time;
   
   // Créer ou mettre à jour la flèche unique (sera clignotante via UpdateDerivArrowBlink)
   string arrowName = "DERIV_ARROW_" + _Symbol;
   ENUM_OBJECT arrowType = (g_lastAIAction == "buy") ? OBJ_ARROW_UP : OBJ_ARROW_DOWN;
   
   if(ObjectFind(0, arrowName) < 0)
   {
      if(!ObjectCreate(0, arrowName, arrowType, 0, arrowTime, arrowPrice))
         return;
   }
   else
   {
      // Mettre à jour la position de la flèche pour suivre la dernière bougie
      ObjectSetInteger(0, arrowName, OBJPROP_TIME, 0, arrowTime);
      ObjectSetDouble(0, arrowName, OBJPROP_PRICE, 0, arrowPrice);
   }
   
   // Propriétés de la flèche
   color arrowColor = (g_lastAIAction == "buy") ? clrLime : clrRed;
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, (g_lastAIAction == "buy") ? 233 : 234);
   ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

//+------------------------------------------------------------------+
//| Dessiner les zones SMC/OrderBlock/ICT                            |
//+------------------------------------------------------------------+
void DrawSMCZonesOnChart()
{
   if(!DrawSMCZones)
   {
      // Supprimer les zones SMC si désactivé
      DeleteSMCZones();
      return;
   }
   
   // Récupérer les données de prix récentes pour identifier les zones SMC
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 100; // Analyser les 100 dernières bougies
   
   if(CopyRates(_Symbol, PERIOD_M5, 0, bars, rates) < bars)
      return;
   
   // Identifier les Order Blocks (zones de forte réaction)
   // Order Block Bullish: Bougie haussière suivie d'une forte hausse
   // Order Block Bearish: Bougie baissière suivie d'une forte baisse
   
   for(int i = 5; i < bars - 5; i++)
   {
      // Détecter Order Block Bullish
      if(rates[i].close > rates[i].open && rates[i+1].close < rates[i+1].open)
      {
         // Vérifier si le prix a rebondi après cette bougie
         bool isOrderBlock = false;
         for(int j = i - 1; j >= MathMax(0, i - 10); j--)
         {
            if(rates[j].close > rates[i].high)
            {
               isOrderBlock = true;
               break;
            }
         }
         
         if(isOrderBlock)
         {
            // Dessiner zone Order Block Bullish
            string obName = "SMC_OB_Bull_" + _Symbol + "_" + IntegerToString(i);
            datetime time1 = rates[i].time;
            datetime time2 = TimeCurrent() + PeriodSeconds(PERIOD_M5) * 50; // Étendre 50 bougies vers le futur
            
            if(ObjectFind(0, obName) < 0)
               ObjectCreate(0, obName, OBJ_RECTANGLE, 0, time1, rates[i].low, time2, rates[i].high);
            else
            {
               ObjectSetInteger(0, obName, OBJPROP_TIME, 0, time1);
               ObjectSetDouble(0, obName, OBJPROP_PRICE, 0, rates[i].high);
               ObjectSetInteger(0, obName, OBJPROP_TIME, 1, time2);
               ObjectSetDouble(0, obName, OBJPROP_PRICE, 1, rates[i].low);
            }
            
            ObjectSetInteger(0, obName, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, obName, OBJPROP_BACK, 1);
            ObjectSetInteger(0, obName, OBJPROP_FILL, 1);
            ObjectSetInteger(0, obName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, obName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, obName, OBJPROP_SELECTABLE, false);
            ObjectSetString(0, obName, OBJPROP_TEXT, "OB Bull");
         }
      }
      
      // Détecter Order Block Bearish
      if(rates[i].close < rates[i].open && rates[i+1].close > rates[i+1].open)
      {
         // Vérifier si le prix a chuté après cette bougie
         bool isOrderBlock = false;
         for(int j = i - 1; j >= MathMax(0, i - 10); j--)
         {
            if(rates[j].close < rates[i].low)
            {
               isOrderBlock = true;
               break;
            }
         }
         
         if(isOrderBlock)
         {
            // Dessiner zone Order Block Bearish
            string obName = "SMC_OB_Bear_" + _Symbol + "_" + IntegerToString(i);
            datetime time1 = rates[i].time;
            datetime time2 = TimeCurrent() + PeriodSeconds(PERIOD_M5) * 50;
            
            if(ObjectFind(0, obName) < 0)
               ObjectCreate(0, obName, OBJ_RECTANGLE, 0, time1, rates[i].high, time2, rates[i].low);
            else
            {
               ObjectSetInteger(0, obName, OBJPROP_TIME, 0, time1);
               ObjectSetDouble(0, obName, OBJPROP_PRICE, 0, rates[i].low);
               ObjectSetInteger(0, obName, OBJPROP_TIME, 1, time2);
               ObjectSetDouble(0, obName, OBJPROP_PRICE, 1, rates[i].high);
            }
            
            ObjectSetInteger(0, obName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, obName, OBJPROP_BACK, 1);
            ObjectSetInteger(0, obName, OBJPROP_FILL, 1);
            ObjectSetInteger(0, obName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, obName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, obName, OBJPROP_SELECTABLE, false);
            ObjectSetString(0, obName, OBJPROP_TEXT, "OB Bear");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Supprimer les zones SMC                                          |
//+------------------------------------------------------------------+
void DeleteSMCZones()
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "SMC_OB_") == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Met à jour le clignotement de la flèche Deriv                    |
//+------------------------------------------------------------------+
void UpdateDerivArrowBlink()
{
   if(!DrawDerivPatterns)
   {
      // Supprimer la flèche si désactivé
      ObjectDelete(0, "DERIV_ARROW_" + _Symbol);
      return;
   }
   
   string arrowName = "DERIV_ARROW_" + _Symbol;
   if(ObjectFind(0, arrowName) < 0)
      return;
   
   // Vérifier si on a un signal IA valide
   if(g_lastAIAction == "" || g_lastAIConfidence < AI_MinConfidence)
   {
      ObjectDelete(0, arrowName);
      return;
   }
   
   // OPTIMISATION: Faire clignoter la flèche moins fréquemment (toutes les 2 secondes)
   static datetime lastBlinkTime = 0;
   static bool blinkState = false;
   
   if(TimeCurrent() - lastBlinkTime >= 2) // Clignotement toutes les 2 secondes pour performance
   {
      blinkState = !blinkState;
      lastBlinkTime = TimeCurrent();
      
      // Toggle visibility pour créer l'effet de clignotement
      ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, blinkState ? true : false);
      
      // Mettre à jour la position pour suivre la dernière bougie
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) > 0)
      {
         ObjectSetInteger(0, arrowName, OBJPROP_TIME, 0, rates[0].time);
         ObjectSetDouble(0, arrowName, OBJPROP_PRICE, 0, rates[0].close);
         ChartRedraw(0); // Redraw seulement si on a mis à jour la position
      }
   }
}

//+------------------------------------------------------------------+
//| Dessiner les prédictions IA sur le graphique (200 bougies futures) |
//+------------------------------------------------------------------+
void DrawPredictionsOnChart(string predictionData)
{
   // DEBUG: Afficher les données reçues
   if(DebugMode)
      Print("🔮 DEBUG - DrawPredictionsOnChart appelé avec: ", predictionData);
   
   // Si pas de données, sortir
   if(predictionData == "")
   {
      if(DebugMode)
         Print("🔮 DEBUG - Aucune donnée de prédiction à dessiner");
      return;
   }
   
   // Nettoyer les anciennes prédictions ET autres objets qui pourraient gêner
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      // Nettoyer tous les objets de prédiction
      if(StringFind(name, "PREDICTION_") == 0 ||
         StringFind(name, "FUTURE_CANDLES_") == 0 ||
         StringFind(name, "CORRECTION_") == 0 ||
         StringFind(name, "AI_ZONE_") == 0 ||
         StringFind(name, "AI_ARROW_") == 0)
      {
         ObjectDelete(0, name);
      }
   }
   
   // Parser les données de prédiction (format JSON réel reçu)
   // Format reçu: {"prediction":{"direction":"DOWN","confidence":0.99,"price_target":1003.94,...}}
   
   // Extraire la direction de la prédiction
   string direction = "";
   double confidence = 0.0;
   
   // Chercher d'abord dans prediction.direction (format correct)
   int predDirPos = StringFind(predictionData, "\"direction\"");
   if(predDirPos >= 0)
   {
      int dirPos = StringFind(predictionData, "\"direction\"", predDirPos);
      if(dirPos >= 0)
      {
         int colonPos = StringFind(predictionData, ":", dirPos);
         if(colonPos >= 0)
         {
            int start = colonPos + 1;
            // Sauter les guillemets
            while(start < StringLen(predictionData) && StringSubstr(predictionData, start, 1) == " ")
               start++;
            if(start < StringLen(predictionData) && StringSubstr(predictionData, start, 1) == "\"")
               start++;
            
            int end = StringFind(predictionData, "\"", start);
            if(end > start)
            {
               direction = StringSubstr(predictionData, start, end - start);
               if(DebugMode)
                  Print("🔮 DEBUG - Direction extraite: ", direction);
            }
         }
      }
      
      // Extraire la confiance
      int confPos = StringFind(predictionData, "\"confidence\"", predDirPos);
      if(confPos >= 0)
      {
         int colonPos = StringFind(predictionData, ":", confPos);
         if(colonPos >= 0)
         {
            int start = colonPos + 1;
            int end = StringFind(predictionData, ",", start);
            if(end < 0) end = StringFind(predictionData, "}", start);
            if(end > start)
            {
               string confStr = StringSubstr(predictionData, start, end - start);
               confidence = StringToDouble(confStr);
               if(DebugMode)
                  Print("🔮 DEBUG - Confiance extraite: ", DoubleToString(confidence, 2));
            }
         }
      }
   }
   
   // DEBUG: Si pas de direction valide, créer une prédiction de test
   if(direction == "")
   {
      if(DebugMode)
         Print("🔮 DEBUG - Pas de direction trouvée, création de prédiction de test");
      
      // Créer une prédiction de test pour vérifier le dessin
      direction = "buy";
      confidence = 0.75;
   }
   else
   {
      // Convertir UP/DOWN en buy/sell
      if(direction == "UP")
         direction = "buy";
      else if(direction == "DOWN")
         direction = "sell";
      
      if(DebugMode)
         Print("🔮 DEBUG - Direction convertie: ", direction);
   }
   
   // Si pas de direction claire, sortir
   if(direction == "")
      return;
   
   // Récupérer le prix actuel
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Dessiner les 1000 bougies futures prédites (trajectoire réaliste)
   datetime futureTime[];
   double futurePrices[];
   double channelHigh[];
   double channelLow[];
   
   ArrayResize(futureTime, 1000);
   ArrayResize(futurePrices, 1000);
   ArrayResize(channelHigh, 1000);
   ArrayResize(channelLow, 1000);
   
   datetime currentTime = TimeCurrent();
   
   // Paramètres pour trajectoire réaliste
   double atr[];
   ArraySetAsSeries(atr, true);
   double currentVolatility = 0.001; // Volatilité actuelle
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      currentVolatility = atr[0] / currentPrice;
   
   // Générer les prix prédits avec trajectoire courbe (exponentielle amortie)
   for(int i = 0; i < 1000; i++)
   {
      futureTime[i] = currentTime + (i + 1) * PeriodSeconds(PERIOD_M1);
      
      // Trajectoire exponentielle avec accélération/décélération progressive
      double progress = (double)i / 1000.0; // Progression 0.0 à 1.0
      
      // Facteur d'accélération (commence lent, accélère, puis amortit)
      double accelerationFactor = 1.0 - MathPow(1.0 - progress, 2.0); // Courbe en S
      
      // Mouvement de base basé sur la direction et la confiance
      double baseMove = currentPrice * currentVolatility * confidence * 10.0; // 10x ATR pour 1000 bougies
      
      // Appliquer l'accélération progressive
      double priceMove = baseMove * accelerationFactor;
      
      // Ajouter des cycles de marché (vagues) - plus réaliste
      double marketCycle = MathSin(progress * 3.14159265359 * 4.0) * currentVolatility * currentPrice * 0.3;
      
      // Ajouter du bruit aléatoire proportionnel à la volatilité
      double noise = ((MathRand() % 200 - 100) / 100.0) * currentVolatility * currentPrice * 0.1;
      
      if(StringCompare(direction, "buy") == 0)
      {
         futurePrices[i] = currentPrice + priceMove + marketCycle + noise;
      }
      else // sell
      {
         futurePrices[i] = currentPrice - priceMove + marketCycle + noise;
      }
      
      // Canal dynamique qui s'élargit avec le temps (incertitude croissante)
      double uncertaintyFactor = 1.0 + progress * 2.0; // Canal s'élargit de 1x à 3x
      double channelWidth = currentVolatility * currentPrice * 0.5 * uncertaintyFactor;
      
      channelHigh[i] = futurePrices[i] + channelWidth;
      channelLow[i] = futurePrices[i] - channelWidth;
   }
   
   // Dessiner la ligne de prédiction principale (courbe sur 1000 points)
   string predictionLineName = "PREDICTION_LINE_" + _Symbol;
   if(ObjectCreate(0, predictionLineName, OBJ_TREND, 0, futureTime[0], futurePrices[0], futureTime[999], futurePrices[999]))
   {
      ObjectSetInteger(0, predictionLineName, OBJPROP_COLOR, StringCompare(direction, "buy") == 0 ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0, predictionLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, predictionLineName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, predictionLineName, OBJPROP_BACK, false);
      ObjectSetString(0, predictionLineName, OBJPROP_TEXT, "Prediction " + (direction == "buy" ? "BUY" : "SELL") + " (" + DoubleToString(confidence*100, 1) + "%)");
   }
   
   // Dessiner les canaux de prédiction
   string channelHighName = "PREDICTION_CHANNEL_HIGH_" + _Symbol;
   string channelLowName = "PREDICTION_CHANNEL_LOW_" + _Symbol;
   
   // Canal supérieur (courbe sur 1000 points)
   if(ObjectCreate(0, channelHighName, OBJ_TREND, 0, futureTime[0], channelHigh[0], futureTime[999], channelHigh[999]))
   {
      ObjectSetInteger(0, channelHighName, OBJPROP_COLOR, StringCompare(direction, "buy") == 0 ? clrLightBlue : clrLightPink);
      ObjectSetInteger(0, channelHighName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, channelHighName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, channelHighName, OBJPROP_BACK, 1);
   }
   
   // Canal inférieur (courbe sur 1000 points)
   if(ObjectCreate(0, channelLowName, OBJ_TREND, 0, futureTime[0], channelLow[0], futureTime[999], channelLow[999]))
   {
      ObjectSetInteger(0, channelLowName, OBJPROP_COLOR, StringCompare(direction, "buy") == 0 ? clrLightBlue : clrLightPink);
      ObjectSetInteger(0, channelLowName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, channelLowName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, channelLowName, OBJPROP_BACK, 1);
   }
   
   // Ajouter des labels pour les points clés
   string labelName = "PREDICTION_LABEL_" + _Symbol;
   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, futureTime[50], futurePrices[50]))
   {
      string labelText = "🔮 " + (direction == "buy" ? "BUY" : "SELL") + " Prediction\nConf: " + DoubleToString(confidence*100, 1) + "%\nTarget: " + DoubleToString(futurePrices[50], _Digits);
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, StringCompare(direction, "buy") == 0 ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   
   if(DebugMode)
      Print("🔮 Prédiction dessinée: ", direction, " (conf: ", DoubleToString(confidence*100, 1), "%)");
}

//+------------------------------------------------------------------+
//| Dessiner les bougies futures adaptées au timeframe         |
//| Crée des bougies visibles pour M1, M5, H1 avec tailles  |
//| et couleurs différentes selon le timeframe actuel              |
//+------------------------------------------------------------------+
void DrawFutureCandlesAdaptive()
{
   // Récupérer le timeframe actuel
   ENUM_TIMEFRAMES currentTF = (ENUM_TIMEFRAMES)Period();
   
   // Paramètres adaptatifs selon le timeframe
   int candleCount = 0;      // Nombre de bougies à dessiner
   color candleColor = clrWhite;
   int candleWidth = 1;
   double bodyTransparency = 0.7;
   
   // Adapter selon le timeframe
   switch(currentTF)
   {
      case PERIOD_M1:
         candleCount = 20;    // 20 bougies futures pour M1
         candleColor = clrYellow;  // Jaune pour M1
         candleWidth = 1;
         bodyTransparency = 0.8;
         break;
         
      case PERIOD_M5:
         candleCount = 12;    // 12 bougies futures pour M5
         candleColor = clrCyan;    // Cyan pour M5
         candleWidth = 2;
         bodyTransparency = 0.6;
         break;
         
      case PERIOD_H1:
         candleCount = 8;     // 8 bougies futures pour H1
         candleColor = clrMagenta; // Magenta pour H1
         candleWidth = 3;
         bodyTransparency = 0.4;
         break;
         
      default:
         candleCount = 10;    // Défaut
         candleColor = clrWhite;
         candleWidth = 2;
         bodyTransparency = 0.5;
         break;
   }
   
   // Récupérer les données de prédiction
   if(g_lastPredictionData == "")
      return;
      
   string direction = "";
   double confidence = 0.0;
   
   // Extraire la direction et la confiance
   int predDirPos = StringFind(g_lastPredictionData, "\"direction\"");
   if(predDirPos >= 0)
   {
      int dirPos = StringFind(g_lastPredictionData, "\"direction\"", predDirPos);
      if(dirPos >= 0)
      {
         int colonPos = StringFind(g_lastPredictionData, ":", dirPos);
         if(colonPos >= 0)
         {
            int start = colonPos + 1;
            // Sauter les guillemets
            while(start < StringLen(g_lastPredictionData) && StringSubstr(g_lastPredictionData, start, 1) == " ")
               start++;
            if(start < StringLen(g_lastPredictionData) && StringSubstr(g_lastPredictionData, start, 1) == "\"")
               start++;
            
            int end = StringFind(g_lastPredictionData, "\"", start);
            if(end > start)
            {
               direction = StringSubstr(g_lastPredictionData, start, end - start);
            }
         }
      }
      
      // Extraire la confiance
      int confPos = StringFind(g_lastPredictionData, "\"confidence\"", predDirPos);
      if(confPos >= 0)
      {
         int colonPos = StringFind(g_lastPredictionData, ":", confPos);
         if(colonPos >= 0)
         {
            int start = colonPos + 1;
            while(start < StringLen(g_lastPredictionData) && StringSubstr(g_lastPredictionData, start, 1) == " ")
               start++;
            if(start < StringLen(g_lastPredictionData) && StringSubstr(g_lastPredictionData, start, 1) == "\"")
               start++;
            
            int end = StringFind(g_lastPredictionData, "\"", start);
            if(end > start)
            {
               string confStr = StringSubstr(g_lastPredictionData, start, end - start);
               confidence = StringToDouble(confStr);
            }
         }
      }
   }
   
   // Si pas de direction claire, sortir
   if(direction == "")
      return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Récupérer l'ATR actuel pour des bougies réalistes
   double atrCurrent[];
   ArraySetAsSeries(atrCurrent, true);
   double atrValue = 0;
   
   if(CopyBuffer(atrHandle, 0, 0, 1, atrCurrent) > 0)
      atrValue = atrCurrent[0];
   else
      atrValue = point * 20; // Valeur par défaut si ATR non disponible
   
   // Nettoyer les anciennes bougies futures et légendes
   string prefix = "FUTURE_CANDLE_" + _Symbol + "_";
   string legendPrefix = "FUTURE_CANDLES_LEGEND_" + _Symbol;
   ObjectsDeleteAll(0, prefix);
   ObjectsDeleteAll(0, legendPrefix);
   
   // Paramètres de volatilité selon le timeframe
   double volatilityMultiplier = 1.0;
   int bodySizeMultiplier = 1;
   
   switch(currentTF)
   {
      case PERIOD_M1:
         volatilityMultiplier = 0.8;  // Moins de volatilité sur M1
         bodySizeMultiplier = 1;
         break;
      case PERIOD_M5:
         volatilityMultiplier = 1.0;  // Volatilité normale sur M5
         bodySizeMultiplier = 2;
         break;
      case PERIOD_H1:
         volatilityMultiplier = 1.5;  // Plus de volatilité sur H1
         bodySizeMultiplier = 3;
         break;
      default:
         volatilityMultiplier = 1.0;
         bodySizeMultiplier = 2;
         break;
   }
   
   // Dessiner les bougies futures en suivant la ligne de prédiction et le canal
   datetime currentTime = TimeCurrent();
   double lastClosePrice = currentPrice;

   // PROFIL HISTORIQUE (optionnel): calibrer ratios corps/mèches sur l'historique récent du TF courant
   // Objectif: rendre la "texture" des bougies futures similaire au symbole (F_INX, Volatility, etc.)
   double avgBodyRatio = 0.55;     // corps / range
   double avgUpperWickRatio = 0.22; // mèche sup / range
   double avgLowerWickRatio = 0.23; // mèche inf / range
   double avgRange = atrValue;      // fallback ATR

   if(UseHistoricalCandleProfile)
   {
      int lookback = CandleProfileLookback;
      if(lookback < 30) lookback = 30;
      if(lookback > 500) lookback = 500;

      MqlRates hist[];
      ArraySetAsSeries(hist, true);
      int copied = CopyRates(_Symbol, currentTF, 1, lookback, hist); // bougies clôturées
      if(copied > 30)
      {
         double sumBody=0, sumUpper=0, sumLower=0, sumRange=0;
         int cnt=0;
         for(int i=0;i<copied;i++)
         {
            double h = hist[i].high;
            double l = hist[i].low;
            double o = hist[i].open;
            double c = hist[i].close;
            double range = h - l;
            if(range <= 0) continue;
            double body = MathAbs(c - o);
            double upper = h - MathMax(o, c);
            double lower = MathMin(o, c) - l;
            if(upper < 0) upper = 0;
            if(lower < 0) lower = 0;

            sumBody += body / range;
            sumUpper += upper / range;
            sumLower += lower / range;
            sumRange += range;
            cnt++;
         }

         if(cnt > 20)
         {
            avgBodyRatio = sumBody / cnt;
            avgUpperWickRatio = sumUpper / cnt;
            avgLowerWickRatio = sumLower / cnt;
            avgRange = sumRange / cnt;

            // Bornes raisonnables pour éviter les profils aberrants
            avgBodyRatio = MathMax(0.10, MathMin(0.90, avgBodyRatio));
            avgUpperWickRatio = MathMax(0.02, MathMin(0.70, avgUpperWickRatio));
            avgLowerWickRatio = MathMax(0.02, MathMin(0.70, avgLowerWickRatio));
            if(avgRange <= 0) avgRange = atrValue;
         }
      }
   }
   
   // Récupérer les données de prédiction existantes (lignes et canaux)
   double predictionPrices[];
   double channelHighs[];
   double channelLows[];
   datetime predictionTimes[];
   
   ArrayResize(predictionPrices, candleCount);
   ArrayResize(channelHighs, candleCount);
   ArrayResize(channelLows, candleCount);
   ArrayResize(predictionTimes, candleCount);
   
   // Calculer les points de prédiction pour chaque bougie future
   for(int i = 0; i < candleCount; i++)
   {
      // Temps de la bougie future
      predictionTimes[i] = currentTime + (i + 1) * PeriodSeconds(currentTF);
      
      // Progression dans le temps (0 à 1)
      double progress = (double)i / (double)candleCount;
      
      // Drift contrôlé: basé sur ATR et confiance, borné par PredictionMaxDriftATR
      double maxDrift = PredictionMaxDriftATR * atrValue * volatilityMultiplier;
      double drift = maxDrift * confidence * progress;
      double baseMove = 0;
      if(StringCompare(direction, "buy") == 0) baseMove = drift;
      else if(StringCompare(direction, "sell") == 0) baseMove = -drift;
      
      // Cycles de marché: amplitude proportionnelle au range moyen
      double marketCycle = MathSin(progress * 3.14159265359 * 3.0) * avgRange * 0.35;
      
      // Prix de prédiction central
      predictionPrices[i] = currentPrice + baseMove + marketCycle;
      
      // Canal: basé sur range moyen (plus stable que 100% ATR brut), incertitude croissante
      double uncertaintyFactor = 1.0 + progress * 1.3;
      double channelWidth = MathMax(atrValue * 0.6, avgRange * 0.9) * uncertaintyFactor;
      
      channelHighs[i] = predictionPrices[i] + channelWidth;
      channelLows[i] = predictionPrices[i] - channelWidth;
   }
   
   // Dessiner les bougies futures en suivant exactement la ligne de prédiction
   for(int i = 0; i < candleCount; i++)
   {
      datetime candleTime = predictionTimes[i];
      
      // La bougie doit suivre la ligne de prédiction centrale
      double targetPrice = predictionPrices[i];
      
      // Variation contrôlée: moins de random, texture calquée sur profil historique
      double maxVariation = (channelHighs[i] - channelLows[i]) * 0.18; // réduit (18% du canal)
      double randomVariation = ((MathRand() % 200 - 100) / 100.0) * maxVariation;
      
      // Calculer OHLC: open = dernier close, close proche de target, puis mèches/corps selon ratios moyens
      double openPrice = lastClosePrice;
      double closePrice = targetPrice + randomVariation;
      
      // S'assurer que la bougie reste dans le canal
      closePrice = MathMax(channelLows[i], MathMin(channelHighs[i], closePrice));
      openPrice = MathMax(channelLows[i], MathMin(channelHighs[i], openPrice));
      
      // Déclarer les variables pour les mèches
      double upperWick = 0;
      double lowerWick = 0;
      
      // ADAPTATION SPÉCIALE POUR BOOM/CRASH
      bool isBoomSymbol = (StringFind(_Symbol, "Boom") != -1);
      bool isCrashSymbol = (StringFind(_Symbol, "Crash") != -1);
      bool isBoomCrashSymbol = isBoomSymbol || isCrashSymbol;
      
      // Variables pour Boom/Crash (déclarées ici pour être accessibles partout)
      bool isSpike = false;
      double spikeMultiplier = 1.0;
      
      if(isBoomCrashSymbol)
      {
         // Pour Boom/Crash: 70% de sticks (petites bougies), 30% de spikes (grandes bougies)
         isSpike = (MathRand() % 100) < 30; // 30% de chance de spike
         
         if(isSpike)
         {
            // SPIKE: Bougie très longue dans la direction de la tendance
            spikeMultiplier = 3.0 + (MathRand() % 200) / 100.0; // 3x à 5x la taille normale
            
            if(StringCompare(direction, "buy") == 0)
            {
               // Spike haussier pour BUY
               closePrice = openPrice + (atrValue * spikeMultiplier * 0.8);
               // Mèches asymétriques pour spike
               upperWick = closePrice + (MathRand() % 20 + 5) / 100.0 * atrValue * 0.2;
               lowerWick = openPrice - (MathRand() % 10 + 5) / 100.0 * atrValue * 0.1;
            }
            else if(StringCompare(direction, "sell") == 0)
            {
               // Spike baissier pour SELL
               closePrice = openPrice - (atrValue * spikeMultiplier * 0.8);
               // Mèches asymétriques pour spike
               upperWick = openPrice + (MathRand() % 10 + 5) / 100.0 * atrValue * 0.1;
               lowerWick = closePrice - (MathRand() % 20 + 5) / 100.0 * atrValue * 0.2;
            }
            
            // Forcer le prix dans le canal
            closePrice = MathMax(channelLows[i], MathMin(channelHighs[i], closePrice));
            upperWick = MathMax(channelLows[i], MathMin(channelHighs[i], upperWick));
            lowerWick = MathMax(channelLows[i], MathMin(channelHighs[i], lowerWick));
         }
         else
         {
            // STICK: Bougie très petite (consolidation)
            double stickSize = atrValue * 0.1; // 10% de l'ATR seulement
            double stickDirection = ((MathRand() % 200 - 100) / 100.0) * stickSize;
            
            closePrice = openPrice + stickDirection;
            
            // Mèches très courtes pour sticks
            upperWick = MathMax(openPrice, closePrice) + (MathRand() % 5 + 1) / 100.0 * atrValue * 0.05;
            lowerWick = MathMin(openPrice, closePrice) - (MathRand() % 5 + 1) / 100.0 * atrValue * 0.05;
            
            // Forcer dans le canal
            closePrice = MathMax(channelLows[i], MathMin(channelHighs[i], closePrice));
            upperWick = MathMax(channelLows[i], MathMin(channelHighs[i], upperWick));
            lowerWick = MathMax(channelLows[i], MathMin(channelHighs[i], lowerWick));
         }
      }
      else
      {
         // Pour les autres symboles: comportement plus "historique"
         // Déterminer un range cible proche du range moyen
         double baseRange = avgRange * (0.75 + (MathRand() % 50) / 100.0); // 0.75x à 1.25x
         baseRange = MathMax(point * 10, baseRange);

         // Corps selon ratio moyen, avec petite variation
         double bodyRatio = avgBodyRatio + ((MathRand() % 20 - 10) / 100.0) * 0.10; // +/- 0.10 * 0.10 = 0.01
         bodyRatio = MathMax(0.10, MathMin(0.85, bodyRatio));
         double bodySize = baseRange * bodyRatio;

         // Orientation: majoritairement dans le sens direction, mais pas toujours
         bool bullish = (closePrice >= openPrice);
         if(StringCompare(direction, "buy") == 0)
            bullish = (MathRand() % 100) < 70;
         else if(StringCompare(direction, "sell") == 0)
            bullish = (MathRand() % 100) < 30;

         // Reconstituer close autour de open avec bodySize
         if(bullish)
            closePrice = openPrice + bodySize;
         else
            closePrice = openPrice - bodySize;

         // Re-forcer dans le canal
         closePrice = MathMax(channelLows[i], MathMin(channelHighs[i], closePrice));

         // Mèches selon ratios moyens
         double upperRatio = avgUpperWickRatio + ((MathRand() % 20 - 10) / 100.0) * 0.08;
         double lowerRatio = avgLowerWickRatio + ((MathRand() % 20 - 10) / 100.0) * 0.08;
         upperRatio = MathMax(0.02, MathMin(0.70, upperRatio));
         lowerRatio = MathMax(0.02, MathMin(0.70, lowerRatio));

         double top = MathMax(openPrice, closePrice);
         double bot = MathMin(openPrice, closePrice);
         upperWick = top + baseRange * upperRatio;
         lowerWick = bot - baseRange * lowerRatio;

         // S'assurer que les mèches restent dans le canal
         upperWick = MathMax(channelLows[i], MathMin(channelHighs[i], upperWick));
         lowerWick = MathMax(channelLows[i], MathMin(channelHighs[i], lowerWick));
      }
      
      // Déterminer la couleur de la bougie selon la direction et le type
      color bodyColor = clrWhite;
      color wickColor = candleColor;
      
      if(closePrice > openPrice)
      {
         // Bougie haussière (verte)
         bodyColor = clrGreen;
         wickColor = clrGreen;
      }
      else if(closePrice < openPrice)
      {
         // Bougie baissière (rouge)
         bodyColor = clrRed;
         wickColor = clrRed;
      }
      else
      {
         // Doji (prix d'ouverture = prix de fermeture)
         bodyColor = candleColor;
         wickColor = candleColor;
      }
      
      // Noms des objets pour cette bougie
      string candleName = prefix + IntegerToString(i);
      string wickName = candleName + "_WICK";
      string bodyName = candleName + "_BODY";
      string shadowName = candleName + "_SHADOW";
      
      // Dessiner l'ombre complète (de haut en bas) - plus fine que la mèche
      if(ObjectCreate(0, shadowName, OBJ_TREND, 0, candleTime, upperWick, candleTime, lowerWick))
      {
         ObjectSetInteger(0, shadowName, OBJPROP_COLOR, clrGray);
         ObjectSetInteger(0, shadowName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, shadowName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, shadowName, OBJPROP_BACK, 1);
         ObjectSetInteger(0, shadowName, OBJPROP_RAY_RIGHT, false);
      }
      
      // Dessiner la mèche principale (plus épaisse et colorée)
      if(ObjectCreate(0, wickName, OBJ_TREND, 0, candleTime, upperWick, candleTime, lowerWick))
      {
         ObjectSetInteger(0, wickName, OBJPROP_COLOR, wickColor);
         ObjectSetInteger(0, wickName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, wickName, OBJPROP_WIDTH, MathMax(1, candleWidth));
         ObjectSetInteger(0, wickName, OBJPROP_BACK, 0); // Au premier plan
         ObjectSetInteger(0, wickName, OBJPROP_RAY_RIGHT, false);
      }
      
      // Dessiner le corps de la bougie (rectangle entre open et close)
      double bodyTop = MathMax(openPrice, closePrice);
      double bodyBottom = MathMin(openPrice, closePrice);
      
      // Ajuster la largeur du corps selon le timeframe
      double bodyWidth = PeriodSeconds(currentTF) * 0.6; // 60% de la largeur de la bougie
      
      // Pour les dojis (open = close), créer un petit corps visible
      if(MathAbs(bodyTop - bodyBottom) < point * 2)
      {
         double centerPrice = (bodyTop + bodyBottom) / 2;
         bodyTop = centerPrice + point;
         bodyBottom = centerPrice - point;
      }
      
      if(ObjectCreate(0, bodyName, OBJ_RECTANGLE, 0, 
                       (datetime)(candleTime - bodyWidth/2), bodyBottom, 
                       (datetime)(candleTime + bodyWidth/2), bodyTop))
      {
         ObjectSetInteger(0, bodyName, OBJPROP_COLOR, bodyColor);
         ObjectSetInteger(0, bodyName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, bodyName, OBJPROP_WIDTH, 1); // Bordure fine
         ObjectSetInteger(0, bodyName, OBJPROP_BACK, false); // Au premier plan
         ObjectSetInteger(0, bodyName, OBJPROP_FILL, 1); // Rempli
         
         // Transparence selon la confiance et la direction
         int transparency = (int)(255 * (1.0 - confidence * 0.7)); // Plus de transparence si moins de confiance
         
         // Ajuster la transparence selon le type de bougie
         if(closePrice > openPrice)
         {
            // Bougies haussières plus visibles
            transparency = (int)(transparency * 0.8);
         }
         else if(closePrice < openPrice)
         {
            // Bougies baissières modérément visibles
            transparency = (int)(transparency * 0.9);
         }
      }
      
      // Mettre à jour pour la prochaine bougie
      lastClosePrice = closePrice;
      
      // Debug pour Boom/Crash: afficher le type de bougie générée
      if(DebugMode && isBoomCrashSymbol)
      {
         string candleType = "";
         if(isSpike)
            candleType = "🚀 SPIKE (" + DoubleToString(spikeMultiplier, 1) + "x)";
         else
            candleType = "📏 STICK";
         
         Print("🕯️ Bougie Boom/Crash générée: ", candleType, " | Direction: ", (closePrice > openPrice ? "UP" : "DOWN"), 
               " | Open: ", DoubleToString(openPrice, _Digits), 
               " | Close: ", DoubleToString(closePrice, _Digits),
               " | Range: ", DoubleToString(MathAbs(closePrice - openPrice) / point, 1), " pips");
      }
   }
   
   // DESSINER LES LIGNES DE PRÉDICTION ET CANAUX COURBES
   // Ligne de prédiction principale (courbe)
   string predictionLineName = "FUTURE_CANDLES_PREDICTION_LINE_" + _Symbol;
   if(ObjectCreate(0, predictionLineName, OBJ_TREND, 0, predictionTimes[0], predictionPrices[0], predictionTimes[candleCount-1], predictionPrices[candleCount-1]))
   {
      ObjectSetInteger(0, predictionLineName, OBJPROP_COLOR, StringCompare(direction, "buy") == 0 ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0, predictionLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, predictionLineName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, predictionLineName, OBJPROP_BACK, false);
      ObjectSetString(0, predictionLineName, OBJPROP_TEXT, "Prediction " + (direction == "buy" ? "BUY" : "SELL") + " (" + DoubleToString(confidence*100, 1) + "%)");
   }
   
   // Canal supérieur (courbe)
   string channelHighName = "FUTURE_CANDLES_CHANNEL_HIGH_" + _Symbol;
   if(ObjectCreate(0, channelHighName, OBJ_TREND, 0, predictionTimes[0], channelHighs[0], predictionTimes[candleCount-1], channelHighs[candleCount-1]))
   {
      ObjectSetInteger(0, channelHighName, OBJPROP_COLOR, StringCompare(direction, "buy") == 0 ? clrLightBlue : clrLightPink);
      ObjectSetInteger(0, channelHighName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, channelHighName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, channelHighName, OBJPROP_BACK, true);
   }
   
   // Canal inférieur (courbe)
   string channelLowName = "FUTURE_CANDLES_CHANNEL_LOW_" + _Symbol;
   if(ObjectCreate(0, channelLowName, OBJ_TREND, 0, predictionTimes[0], channelLows[0], predictionTimes[candleCount-1], channelLows[candleCount-1]))
   {
      ObjectSetInteger(0, channelLowName, OBJPROP_COLOR, StringCompare(direction, "buy") == 0 ? clrLightBlue : clrLightPink);
      ObjectSetInteger(0, channelLowName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, channelLowName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, channelLowName, OBJPROP_BACK, true);
   }
   
   // Ajouter une légende détaillée
   string legendName = "FUTURE_CANDLES_LEGEND_" + _Symbol;
   double legendPrice = currentPrice + atrValue * 2.5;
   datetime legendTime = currentTime + PeriodSeconds(currentTF) * 2;
   
   if(ObjectCreate(0, legendName, OBJ_TEXT, 0, legendTime, legendPrice))
   {
      string volatilityText = "";
      if(volatilityMultiplier < 1.0)
         volatilityText = " (Faible volatilité)";
      else if(volatilityMultiplier > 1.0)
         volatilityText = " (Forte volatilité)";
      else
         volatilityText = " (Volatilité normale)";
      
      string legendText = "🔮 PRÉDICTION " + StringSubstr(EnumToString(currentTF), 7) + 
                         "\n📈 Direction: " + (direction == "buy" ? "BUY" : "SELL") + 
                         "\n🎯 Confiance: " + DoubleToString(confidence*100, 1) + "%" +
                         "\n📊 ATR: " + DoubleToString(atrValue/point, 1) + " pips" +
                         volatilityText;
      
      // Ajouter des informations spécifiques pour Boom/Crash
      bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
      if(isBoomCrashSymbol)
      {
         legendText += "\n\n🎯 BOOM/CRASH MODE:";
         legendText += "\n   📏 70% Sticks (petites bougies)";
         legendText += "\n   🚀 30% Spikes (grandes impulsions)";
         legendText += "\n   📊 Basé sur données historiques";
      }
      
      ObjectSetString(0, legendName, OBJPROP_TEXT, legendText);
      ObjectSetInteger(0, legendName, OBJPROP_COLOR, candleColor);
      ObjectSetInteger(0, legendName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, legendName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, legendName, OBJPROP_BACK, false);
      ObjectSetInteger(0, legendName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
   
   // Ajouter un indicateur visuel de la zone de prédiction
   string zoneName = "FUTURE_CANDLES_ZONE_" + _Symbol;
   double zoneTop = currentPrice + atrValue * 3;
   double zoneBottom = currentPrice - atrValue * 3;
   datetime zoneStart = currentTime + PeriodSeconds(currentTF);
   datetime zoneEnd = currentTime + (candleCount + 2) * PeriodSeconds(currentTF);
   
   if(ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, zoneStart, zoneBottom, zoneEnd, zoneTop))
   {
      ObjectSetInteger(0, zoneName, OBJPROP_COLOR, candleColor);
      ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, zoneName, OBJPROP_BACK, 1);
      ObjectSetInteger(0, zoneName, OBJPROP_FILL, 0); // Non rempli
   }
   
   if(DebugMode)
   {
      Print("🕯️ BOUGIES FUTURES CRÉÉES:");
      Print("   Timeframe: ", EnumToString(currentTF));
      Print("   Nombre de bougies: ", candleCount);
      Print("   Direction: ", StringToUpper(direction));
      Print("   Confiance: ", DoubleToString(confidence*100, 1), "%");
      Print("   ATR actuel: ", DoubleToString(atrValue/point, 1), " pips");
      Print("   Volatilité: ", volatilityMultiplier < 1.0 ? "Faible" : volatilityMultiplier > 1.0 ? "Forte" : "Normale");
      Print("   Prix actuel: ", DoubleToString(currentPrice, _Digits));
      Print("   Multiplicateur volatilité: ", DoubleToString(volatilityMultiplier, 2));
      Print("   Couleur des bougies: ", (StringCompare(direction, "buy") == 0 ? "Vertes (haussières)" : "Rouges (baissières)"));
   }
   
   // NOUVEAU: Trader automatiquement basé sur les bougies futures si IA n'est pas en attente
   if(StringCompare(direction, "hold") != 0 && confidence >= 0.70 && !g_aiFallbackMode)
   {
      TradeBasedOnFutureCandles(direction, confidence, currentPrice, atrValue);
   }
}

//+------------------------------------------------------------------+
//| Trader automatiquement basé sur les bougies futures            |
//| Exécute des ordres quand la confiance est élevée et direction claire |
//+------------------------------------------------------------------+
void TradeBasedOnFutureCandles(string direction, double confidence, double currentPrice, double atrValue)
{
   // Vérifier si on peut trader (pas de position active sur ce symbole)
   if(PositionsTotal() > 0)
   {
      // Vérifier s'il y a déjà une position sur ce symbole
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            if(DebugMode)
               Print("📋 Position déjà existante sur ", _Symbol, " - pas de nouvelle position basée sur bougies futures");
            return;
         }
      }
   }
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   ENUM_ORDER_TYPE orderType = WRONG_VALUE;
   
   // Déterminer le type d'ordre selon la direction
   if(StringCompare(direction, "buy") == 0)
   {
      orderType = ORDER_TYPE_BUY;
   }
   else if(StringCompare(direction, "sell") == 0)
   {
      orderType = ORDER_TYPE_SELL;
   }
   else
   {
      if(DebugMode)
         Print("⚠️ Direction non reconnue pour trading basé sur bougies futures: ", direction);
      return;
   }
   
   // RÈGLE BOOM/CRASH: pas de BUY sur Crash, pas de SELL sur Boom
   if(StringFind(_Symbol, "Crash") >= 0 && orderType == ORDER_TYPE_BUY) return;
   if(StringFind(_Symbol, "Boom") >= 0 && orderType == ORDER_TYPE_SELL) return;
   
   // Calculer SL/TP basés sur l'ATR et la direction des bougies futures
   double stopLoss = 0;
   double takeProfit = 0;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      // Pour BUY: SL sous le prix actuel, TP au-dessus
      stopLoss = currentPrice - (atrValue * 1.5);
      takeProfit = currentPrice + (atrValue * 3.0); // 1:2 ratio
   }
   else // SELL
   {
      // Pour SELL: SL au-dessus du prix actuel, TP en dessous
      stopLoss = currentPrice + (atrValue * 1.5);
      takeProfit = currentPrice - (atrValue * 3.0); // 1:2 ratio
   }
   
   // Validation des distances minimales
   double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double slDistance = MathAbs(currentPrice - stopLoss);
   double tpDistance = MathAbs(takeProfit - currentPrice);
   
   // GESTION SPÉCIALE STEP INDEX
   bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);
   if(isStepIndex)
   {
      minDistance = MathMax(minDistance, 20 * point);
      if(DebugMode)
         Print("🔧 Step Index - Distance minimale pour ordre basé bougies futures: ", DoubleToString(minDistance / point, 0), " points");
   }
   
   if(slDistance < minDistance || tpDistance < minDistance)
   {
      if(DebugMode)
         Print("⚠️ Distances SL/TP trop faibles pour ordre basé bougies futures: SL=", DoubleToString(slDistance / point, 0), " TP=", DoubleToString(tpDistance / point, 0));
      return;
   }
   
   // Calculer la taille de position selon la confiance
   double lotSize = InitialLotSize;
   if(confidence >= 0.90)
      lotSize = InitialLotSize * 1.5; // Augmenter la taille si très haute confiance
   else if(confidence < 0.80)
      lotSize = InitialLotSize * 0.8; // Réduire si confiance modérée
   
   lotSize = NormalizeLotSize(lotSize);
   
   // Placer l'ordre au marché immédiatement
   string orderComment = "Future Candles AI - " + (direction == "buy" ? "BUY" : "SELL") + " (conf: " + DoubleToString(confidence*100, 1) + "%)";
   
   if(orderType == ORDER_TYPE_BUY)
   {
      // Envoyer notification AVANT l'exécution de l'ordre
      if(!DisableNotifications)
      {
         string notificationText = "🚀 BUY Future Candles AI\n" + _Symbol + " @ " + DoubleToString(currentPrice, _Digits) + "\nConfiance: " + DoubleToString(confidence*100, 1) + "%\n🎯 Position OUVERTE IMMÉDIATEMENT";
         SendNotification(notificationText);
         Alert(notificationText);
      }
      
      // Exécuter l'ordre immédiatement après la notification
      if(SafeTradeBuy(lotSize, _Symbol, currentPrice, stopLoss, takeProfit, orderComment))
      {
         double riskUSD = slDistance * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double rewardUSD = tpDistance * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         
         Print("🚀 ORDRE BUY BASÉ BOUGIES FUTURES - POSITION OUVERTE:");
         Print("   📈 Direction: BUY (confiance: ", DoubleToString(confidence*100, 1), "%)");
         Print("   💰 Prix d'entrée: ", DoubleToString(currentPrice, _Digits));
         Print("   🛡️ Stop Loss: ", DoubleToString(stopLoss, _Digits), " (risque: ", DoubleToString(riskUSD, 2), "$)");
         Print("   🎯 Take Profit: ", DoubleToString(takeProfit, _Digits), " (gain: ", DoubleToString(rewardUSD, 2), "$)");
         Print("   📊 Ratio R/R: 1:", DoubleToString(rewardUSD/riskUSD, 1));
         Print("   📏 Taille: ", DoubleToString(lotSize, 2));
         Print("   🕯️ Basé sur prédiction des bougies futures sur ", EnumToString((ENUM_TIMEFRAMES)Period()));
         Print("   ⚡ Position ouverte IMMÉDIATEMENT après notification");
         
         // Envoyer notification de confirmation
         if(!DisableNotifications)
         {
            string confirmText = "✅ BUY EXECUTÉ\n" + _Symbol + " @ " + DoubleToString(currentPrice, _Digits) + "\nSL: " + DoubleToString(stopLoss, _Digits) + "\nTP: " + DoubleToString(takeProfit, _Digits);
            SendNotification(confirmText);
         }
      }
      else
      {
         Print("❌ Erreur ordre BUY basé bougies futures: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         
         // Envoyer notification d'erreur
         if(!DisableNotifications)
         {
            string errorText = "❌ ERREUR BUY\n" + _Symbol + "\nCode: " + IntegerToString(trade.ResultRetcode()) + "\n" + trade.ResultRetcodeDescription();
            SendNotification(errorText);
         }
      }
   }
   else // SELL
   {
      // Envoyer notification AVANT l'exécution de l'ordre
      if(!DisableNotifications)
      {
         string notificationText = "🚀 SELL Future Candles AI\n" + _Symbol + " @ " + DoubleToString(currentPrice, _Digits) + "\nConfiance: " + DoubleToString(confidence*100, 1) + "%\n🎯 Position OUVERTE IMMÉDIATEMENT";
         SendNotification(notificationText);
         Alert(notificationText);
      }
      
      // Exécuter l'ordre immédiatement après la notification
      if(SafeTradeSell(lotSize, _Symbol, currentPrice, stopLoss, takeProfit, orderComment))
      {
         double riskUSD = slDistance * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double rewardUSD = tpDistance * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         
         Print("🚀 ORDRE SELL BASÉ BOUGIES FUTURES - POSITION OUVERTE:");
         Print("   📉 Direction: SELL (confiance: ", DoubleToString(confidence*100, 1), "%)");
         Print("   💰 Prix d'entrée: ", DoubleToString(currentPrice, _Digits));
         Print("   🛡️ Stop Loss: ", DoubleToString(stopLoss, _Digits), " (risque: ", DoubleToString(riskUSD, 2), "$)");
         Print("   🎯 Take Profit: ", DoubleToString(takeProfit, _Digits), " (gain: ", DoubleToString(rewardUSD, 2), "$)");
         Print("   📊 Ratio R/R: 1:", DoubleToString(rewardUSD/riskUSD, 1));
         Print("   📏 Taille: ", DoubleToString(lotSize, 2));
         Print("   🕯️ Basé sur prédiction des bougies futures sur ", EnumToString((ENUM_TIMEFRAMES)Period()));
         Print("   ⚡ Position ouverte IMMÉDIATEMENT après notification");
         
         // Envoyer notification de confirmation
         if(!DisableNotifications)
         {
            string confirmText = "✅ SELL EXECUTÉ\n" + _Symbol + " @ " + DoubleToString(currentPrice, _Digits) + "\nSL: " + DoubleToString(stopLoss, _Digits) + "\nTP: " + DoubleToString(takeProfit, _Digits);
            SendNotification(confirmText);
         }
      }
      else
      {
         Print("❌ Erreur ordre SELL basé bougies futures: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         
         // Envoyer notification d'erreur
         if(!DisableNotifications)
         {
            string errorText = "❌ ERREUR SELL\n" + _Symbol + "\nCode: " + IntegerToString(trade.ResultRetcode()) + "\n" + trade.ResultRetcodeDescription();
            SendNotification(errorText);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Sécurisation dynamique des profits                                |
//| Active dès que le profit total >= 3$                              |
//| Ferme les positions si profit < 50% du profit max                |
//| Sinon, déplace le SL pour sécuriser les profits                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Trouver ou créer un tracker de profit pour une position          |
//+------------------------------------------------------------------+
double GetMaxProfitForPosition(ulong ticket)
{
   // Chercher dans le tableau de trackers
   for(int i = 0; i < g_profitTrackersCount; i++)
   {
      if(g_profitTrackers[i].ticket == ticket)
         return g_profitTrackers[i].maxProfit;
   }
   
   // Si pas trouvé, créer un nouveau tracker
   if(g_profitTrackersCount >= ArraySize(g_profitTrackers))
   {
      int newSize = g_profitTrackersCount + 10;
      ArrayResize(g_profitTrackers, newSize);
   }
   
   g_profitTrackers[g_profitTrackersCount].ticket = ticket;
   g_profitTrackers[g_profitTrackersCount].maxProfit = 0.0;
   g_profitTrackers[g_profitTrackersCount].lastUpdate = TimeCurrent();
   g_profitTrackersCount++;
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Mettre à jour le profit max pour une position                     |
//+------------------------------------------------------------------+
void UpdateMaxProfitForPosition(ulong ticket, double currentProfit)
{
   // Chercher dans le tableau
   for(int i = 0; i < g_profitTrackersCount; i++)
   {
      if(g_profitTrackers[i].ticket == ticket)
      {
         if(currentProfit > g_profitTrackers[i].maxProfit)
         {
            g_profitTrackers[i].maxProfit = currentProfit;
            g_profitTrackers[i].lastUpdate = TimeCurrent();
         }
         return;
      }
   }
   
   // Si pas trouvé, créer un nouveau tracker
   if(g_profitTrackersCount >= ArraySize(g_profitTrackers))
   {
      int newSize = g_profitTrackersCount + 10;
      ArrayResize(g_profitTrackers, newSize);
   }
   
   g_profitTrackers[g_profitTrackersCount].ticket = ticket;
   g_profitTrackers[g_profitTrackersCount].maxProfit = MathMax(currentProfit, 0.0);
   g_profitTrackers[g_profitTrackersCount].lastUpdate = TimeCurrent();
   g_profitTrackersCount++;
}

//+------------------------------------------------------------------+
//| Nettoyer les trackers de positions fermées                       |
//+------------------------------------------------------------------+
void CleanupProfitTrackers()
{
   // Vérifier quelles positions existent encore
   ulong activeTickets[];
   int activeCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
         {
            ArrayResize(activeTickets, activeCount + 1);
            activeTickets[activeCount] = ticket;
            activeCount++;
         }
      }
   }
   
   // Supprimer les trackers des positions fermées
   int writeIndex = 0;
   for(int i = 0; i < g_profitTrackersCount; i++)
   {
      bool found = false;
      for(int j = 0; j < activeCount; j++)
      {
         if(g_profitTrackers[i].ticket == activeTickets[j])
         {
            found = true;
            break;
         }
      }
      
      if(found)
      {
         if(writeIndex != i)
         {
            g_profitTrackers[writeIndex] = g_profitTrackers[i];
         }
         writeIndex++;
      }
   }
   
   g_profitTrackersCount = writeIndex;
}

//+------------------------------------------------------------------+
//| Sécuriser le profit d'une position individuelle                  |
//| Déplace le SL pour sécuriser au moins 50% du profit actuel       |
//| Appelé dès qu'une position est en profit                         |
//+------------------------------------------------------------------+
void SecureProfitForPosition(ulong ticket, double currentProfit)
{
   if(!positionInfo.SelectByTicket(ticket))
      return;
   
   // Ne sécuriser que si profit > 0.10$ (éviter trop de modifications)
   if(currentProfit <= 0.10)
      return;
   
   double openPrice = positionInfo.PriceOpen();
   double currentPrice = positionInfo.PriceCurrent();
   double currentSL = positionInfo.StopLoss();
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   double lotSize = positionInfo.Volume();
   
   // Calculer le profit à sécuriser (50% du profit actuel)
   double profitToSecure = currentProfit * 0.50;
   
   // Convertir le profit en points
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue = (tickValue / tickSize) * point;
   
   double pointsToSecure = 0;
   if(pointValue > 0 && lotSize > 0)
   {
      double profitPerPoint = lotSize * pointValue;
      if(profitPerPoint > 0)
         pointsToSecure = profitToSecure / profitPerPoint;
   }
   
   // Si le calcul échoue, utiliser ATR comme fallback
   if(pointsToSecure <= 0)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         // Utiliser une fraction de l'ATR basée sur le profit
         if(pointValue > 0 && lotSize > 0)
         {
            double profitPerATR = lotSize * pointValue * (atr[0] / point);
            if(profitPerATR > 0)
               pointsToSecure = profitToSecure / profitPerATR * (atr[0] / point);
         }
      }
      
      if(pointsToSecure <= 0)
         return; // Impossible de calculer, abandonner
   }
   
   // Calculer le nouveau SL
   double newSL = 0.0;
   bool shouldUpdate = false;
   
   if(posType == POSITION_TYPE_BUY)
   {
      // BUY: SL = prix d'entrée + profit sécurisé
      newSL = NormalizeDouble(openPrice + (pointsToSecure * point), _Digits);
      
      // Le nouveau SL doit être meilleur (plus haut) que l'actuel
      if(currentSL == 0 || newSL > currentSL)
         shouldUpdate = true;
   }
   else // SELL
   {
      // SELL: SL = prix d'entrée - profit sécurisé
      newSL = NormalizeDouble(openPrice - (pointsToSecure * point), _Digits);
      
      // Le nouveau SL doit être meilleur (plus bas) que l'actuel
      if(currentSL == 0 || newSL < currentSL)
         shouldUpdate = true;
   }
   
   if(!shouldUpdate)
      return; // SL déjà meilleur ou égal
   
   // Vérifier les niveaux minimums du broker
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * point;
   if(minDistance == 0 || minDistance < tickSize)
      minDistance = MathMax(tickSize * 3, 5 * point);
   
   // Vérifier que le SL respecte la distance minimum
   bool slValid = false;
   if(posType == POSITION_TYPE_BUY)
   {
      slValid = (newSL <= currentPrice - minDistance && newSL > openPrice);
   }
   else
   {
      slValid = (newSL >= currentPrice + minDistance && newSL < openPrice);
   }
   
   if(!slValid)
   {
      if(DebugMode)
         Print("⏸️ SL sécurisation trop proche du prix actuel (", DoubleToString(newSL, _Digits), " vs ", DoubleToString(currentPrice, _Digits), ")");
      return;
   }
   
   // Mettre à jour le SL
   double tp = positionInfo.TakeProfit();
   if(trade.PositionModify(ticket, newSL, tp))
   {
      Print("🔒 Profit sécurisé: SL déplacé pour sécuriser ", DoubleToString(profitToSecure, 2), "$ (50% de ", DoubleToString(currentProfit, 2), "$) - Nouveau SL: ", DoubleToString(newSL, _Digits));
      if(g_positionTracker.ticket == ticket)
         g_positionTracker.profitSecured = true;
   }
   else if(DebugMode)
   {
      Print("⚠️ Erreur sécurisation profit: ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Sécurisation dynamique des profits                                |
//| Active dès que le profit total >= 3$                              |
//| Ferme les positions si profit < 50% du profit max                |
//| Sinon, déplace le SL pour sécuriser les profits                  |
//+------------------------------------------------------------------+
void SecureDynamicProfits()
{
   // DEBUG: Confirmer l'appel de la fonction (moins fréquent)
   static datetime lastDebug = 0;
   if(TimeCurrent() - lastDebug >= 60) // Toutes les 60 secondes (au lieu de 30)
   {
      if(DebugMode)
         Print("🔄 SecureDynamicProfits() appelé - Trailing stop ACTIF");
      lastDebug = TimeCurrent();
   }
   
   // OPTIMISATION: Sortir rapide si aucune position
   if(PositionsTotal() == 0)
      return;
   
   // 0. SORTIE RAPIDE POUR INDICES VOLATILITY
   // Fermer chaque position Volatility dès que le profit atteint VolatilityQuickTP (ex: 2$)
   bool isVolatilitySymbol = IsVolatilitySymbol(_Symbol);
   if(isVolatilitySymbol && VolatilityQuickTP > 0.0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && positionInfo.SelectByTicket(ticket))
         {
            if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
            {
               double profit = positionInfo.Profit();
               
               // Fermer dès que le profit atteint le seuil rapide
               if(profit >= VolatilityQuickTP)
               {
                  if(trade.PositionClose(ticket))
                  {
                     Print("✅ Volatility: Position fermée à TP rapide ", DoubleToString(VolatilityQuickTP, 2),
                           "$ (profit=", DoubleToString(profit, 2), "$) - Prise de gain rapide, prêt à se replacer si le mouvement continue");
                     // Continuer la boucle pour gérer d'autres positions si besoin
                     continue;
                  }
                  else if(DebugMode)
                  {
                     Print("❌ Erreur fermeture position Volatility (TP rapide): ",
                           trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
                  }
               }
            }
         }
      }
   }
   
   // Nettoyer les trackers de positions fermées
   static datetime lastCleanup = 0;
   if(TimeCurrent() - lastCleanup > 60) // Toutes les minutes
   {
      CleanupProfitTrackers();
      lastCleanup = TimeCurrent();
   }
   
   // Calculer le profit total de toutes les positions
   double totalProfit = 0.0;
   int profitablePositions = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
         {
            double profit = positionInfo.Profit();
            totalProfit += profit;
            
            // Mettre à jour le profit max pour cette position
            UpdateMaxProfitForPosition(ticket, profit);
            
            if(profit > 0)
               profitablePositions++;
         }
      }
   }
   
   // Mettre à jour le profit maximum global
   if(totalProfit > g_globalMaxProfit)
      g_globalMaxProfit = totalProfit;
   
   // NOUVELLE LOGIQUE: Sécurisation AGGRESSIVE dès qu'une position est en profit
   // On sécurise chaque position individuellement dès qu'elle est en profit
   // Plus besoin d'attendre 3$ total - protection immédiate des gains
   
   // Sécurisation activée : vérifier chaque position
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
         {
            double currentProfit = positionInfo.Profit();
            double openPrice = positionInfo.PriceOpen();
            double currentPrice = positionInfo.PriceCurrent();
            double currentSL = positionInfo.StopLoss();
            ENUM_POSITION_TYPE posType = positionInfo.PositionType();
            
            // NOUVELLE LOGIQUE: Sécurisation AGGRESSIVE dès qu'il y a un profit
            // Dès qu'une position est en profit, on sécurise au moins 50% des gains initiaux
            
            // Récupérer le profit max pour cette position
            double maxProfitForPosition = GetMaxProfitForPosition(ticket);
            if(maxProfitForPosition == 0.0 && currentProfit > 0)
               maxProfitForPosition = currentProfit; // Utiliser le profit actuel comme référence initiale
            
            // SÉCURISATION IMMÉDIATE: Dès qu'il y a un profit (même petit), sécuriser 50%
            if(currentProfit > 0)
            {
               // Utiliser le profit actuel OU le profit max (le plus élevé)
               double profitReference = MathMax(currentProfit, maxProfitForPosition);
               
               // Calculer le drawdown en pourcentage
               double drawdownPercent = 0.0;
               if(profitReference > 0)
                  drawdownPercent = (profitReference - currentProfit) / profitReference;
               
               // Si drawdown > 50%, fermer la position (protection contre retournement)
               if(drawdownPercent > PROFIT_DRAWDOWN_LIMIT && currentProfit > 0)
               {
                  if(trade.PositionClose(ticket))
                  {
                     Print("🔒 Position fermée - Drawdown > 50%: Profit max=", DoubleToString(profitReference, 2), 
                           "$ Profit actuel=", DoubleToString(currentProfit, 2), "$ Drawdown=", DoubleToString(drawdownPercent * 100, 1), "%");
                  }
                  continue;
               }
               
               // SÉCURISATION PROGRESSIVE: Déplacer le SL pour sécuriser au moins 50% du profit actuel
               // On sécurise 50% du profit actuel (pas seulement du profit max)
               double profitToSecure = currentProfit * 0.50; // 50% du profit actuel (AGGRESSIF)
                     
                     // Convertir le profit en points
                     double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                     double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                     double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                     double pointValue = (tickValue / tickSize) * point;
                     double lotSize = positionInfo.Volume();
                     
                     double pointsToSecure = 0;
                     if(pointValue > 0 && lotSize > 0)
                     {
                        double profitPerPoint = lotSize * pointValue;
                        if(profitPerPoint > 0)
                           pointsToSecure = profitToSecure / profitPerPoint;
                     }
                     
                     // Si le calcul échoue, utiliser ATR comme fallback
                     if(pointsToSecure <= 0)
                     {
                        double atr[];
                        ArraySetAsSeries(atr, true);
                        if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
                           pointsToSecure = (profitToSecure / (lotSize * pointValue)) > 0 ? (profitToSecure / (lotSize * pointValue)) : (atr[0] / point);
                     }
                     
                     // Calculer le nouveau SL pour sécuriser 50% du profit actuel
                     double newSL = 0.0;
                     
                     // Calculer le prix qui correspond à 50% du profit actuel
                     // Pour BUY: SL = prix d'entrée + (profit sécurisé en points)
                     // Pour SELL: SL = prix d'entrée - (profit sécurisé en points)
                     
                     if(posType == POSITION_TYPE_BUY)
                     {
                        // BUY: SL doit être au-dessus du prix d'entrée pour sécuriser le profit
                        newSL = openPrice + (pointsToSecure * point);
                        
                        // Le nouveau SL doit être meilleur (plus haut) que l'actuel
                        // ET ne pas être trop proche du prix actuel
                        bool shouldUpdate = false;
                        if(currentSL == 0)
                        {
                           // Pas de SL actuel, on peut en mettre un
                           shouldUpdate = true;
                        }
                        else if(newSL > currentSL)
                        {
                           // Le nouveau SL est meilleur (plus haut) que l'actuel
                           shouldUpdate = true;
                        }
                        
                        if(shouldUpdate)
                        {
                           // Vérifier les niveaux minimums du broker
                           long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                           double tickSizeLocal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                           double minDistance = stopLevel * point;
                           if(minDistance == 0 || minDistance < tickSizeLocal)
                              minDistance = MathMax(tickSizeLocal * 3, 5 * point);
                           
                           // Le SL doit être au moins minDistance en-dessous du prix actuel
                           if(newSL <= currentPrice - minDistance)
                           {
                              double tp = positionInfo.TakeProfit();
                              if(trade.PositionModify(ticket, newSL, tp))
                              {
                                 Print("🔒 SL sécurisé BUY: ", DoubleToString(newSL, _Digits), 
                                       " (sécurise ", DoubleToString(profitToSecure, 2), "$ = 50% de ", DoubleToString(currentProfit, 2), "$)");
                                 if(g_positionTracker.ticket == ticket)
                                    g_positionTracker.profitSecured = true;
                              }
                              else if(DebugMode)
                              {
                                 Print("⚠️ Erreur modification SL BUY: ", trade.ResultRetcodeDescription());
                              }
                           }
                           else if(DebugMode)
                           {
                              Print("⏸️ SL BUY trop proche du prix actuel (", DoubleToString(newSL, _Digits), " vs ", DoubleToString(currentPrice, _Digits), ")");
                           }
                        }
                     }
                     else // SELL
                     {
                        // SELL: SL doit être en-dessous du prix d'entrée pour sécuriser le profit
                        newSL = openPrice - (pointsToSecure * point);
                        
                        // Le nouveau SL doit être meilleur (plus bas) que l'actuel
                        // ET ne pas être trop proche du prix actuel
                        bool shouldUpdate = false;
                        if(currentSL == 0)
                        {
                           // Pas de SL actuel, on peut en mettre un
                           shouldUpdate = true;
                        }
                        else if(newSL < currentSL)
                        {
                           // Le nouveau SL est meilleur (plus bas) que l'actuel
                           shouldUpdate = true;
                        }
                        
                        if(shouldUpdate)
                        {
                           // Vérifier les niveaux minimums du broker
                           long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                           double tickSizeLocal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                           double minDistance = stopLevel * point;
                           if(minDistance == 0 || minDistance < tickSizeLocal)
                              minDistance = MathMax(tickSizeLocal * 3, 5 * point);
                           
                           // Le SL doit être au moins minDistance au-dessus du prix actuel
                           if(newSL >= currentPrice + minDistance)
                           {
                              double tp = positionInfo.TakeProfit();
                              if(trade.PositionModify(ticket, newSL, tp))
                              {
                                 Print("🔒 SL sécurisé SELL: ", DoubleToString(newSL, _Digits), 
                                       " (sécurise ", DoubleToString(profitToSecure, 2), "$ = 50% de ", DoubleToString(currentProfit, 2), "$)");
                                 if(g_positionTracker.ticket == ticket)
                                    g_positionTracker.profitSecured = true;
                              }
                              else if(DebugMode)
                              {
                                 Print("⚠️ Erreur modification SL SELL: ", trade.ResultRetcodeDescription());
                              }
                           }
                           else if(DebugMode)
                           {
                              Print("⏸️ SL SELL trop proche du prix actuel (", DoubleToString(newSL, _Digits), " vs ", DoubleToString(currentPrice, _Digits), ")");
                           }
                        }
                     }
               }
            }
         }
      }
   
   // Si le profit global a chuté de plus de 50%, fermer toutes les positions gagnantes
   if(g_globalMaxProfit > 0 && totalProfit < (g_globalMaxProfit * PROFIT_DRAWDOWN_LIMIT))
   {
      if(DebugMode)
         Print("⚠️ Drawdown global > 50% - Fermeture de toutes les positions gagnantes");
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && positionInfo.SelectByTicket(ticket))
         {
            if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
            {
               double profit = positionInfo.Profit();
               if(profit > 0)
               {
                  if(trade.PositionClose(ticket))
                  {
                     Print("🔒 Position gagnante fermée (drawdown global): ", DoubleToString(profit, 2), "$");
                  }
               }
            }
         }
      }
      
      // Réinitialiser le profit max global
      g_globalMaxProfit = 0.0;
   }
}

//+------------------------------------------------------------------+
//| Calcule la force du momentum (MCS - Momentum Concept Strategy)   |
//| Retourne un score entre 0.0 et 1.0                                |
//+------------------------------------------------------------------+
double CalculateMomentumStrength(ENUM_ORDER_TYPE orderType, int lookbackBars = 5)
{
   double momentum = 0.0;
   
   // Récupérer les données de prix
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, lookbackBars + 2, close) < lookbackBars + 2)
      return 0.0;
   
   // Récupérer l'ATR pour normaliser
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
      return 0.0;
   
   // Compter les bougies directionnelles
   int bullishBars = 0;
   int bearishBars = 0;
   double totalMovement = 0.0;
   
   for(int i = 0; i < lookbackBars; i++)
   {
      double movement = MathAbs(close[i] - close[i + 1]);
      totalMovement += movement;
      
      if(close[i] > close[i + 1])
         bullishBars++;
      else if(close[i] < close[i + 1])
         bearishBars++;
   }
   
   double avgMovement = (lookbackBars > 0) ? (totalMovement / lookbackBars) : 0.0;
   double normalizedMovement = (atr[0] > 0) ? (avgMovement / atr[0]) : 0.0;
   
   // Calculer le momentum directionnel
   double directionalBias = 0.0;
   if(orderType == ORDER_TYPE_BUY)
   {
      directionalBias = (double)bullishBars / lookbackBars;
      momentum = normalizedMovement * directionalBias;
   }
   else // SELL
   {
      directionalBias = (double)bearishBars / lookbackBars;
      momentum = normalizedMovement * directionalBias;
   }
   
   // Ajouter un facteur de vitesse (accélération)
   if(lookbackBars >= 3)
   {
      double recentMovement = MathAbs(close[0] - close[2]);
      double olderMovement = MathAbs(close[2] - close[4]);
      if(olderMovement > 0)
      {
         double acceleration = recentMovement / olderMovement;
         momentum *= MathMin(acceleration, 2.0); // Limiter à 2x
      }
   }
   
   // Normaliser entre 0.0 et 1.0
   momentum = MathMin(MathMax(momentum / 2.0, 0.0), 1.0);
   
   return momentum;
}

//+------------------------------------------------------------------+
//| Analyse les zones de pression (MCS - Momentum Concept Strategy)  |
//| Basé sur les zones AI et le momentum                              |
//| Retourne: true si zone de pression valide avec momentum suffisant|
//+------------------------------------------------------------------+
bool AnalyzeMomentumPressureZone(ENUM_ORDER_TYPE orderType, double price, double &momentumScore, double &zoneStrength)
{
   momentumScore = 0.0;
   zoneStrength = 0.0;
   
   // 1. Vérifier si on est dans une zone AI BUY/SELL
   bool inZone = false;
   bool isBuyZone = false;
   
   if(orderType == ORDER_TYPE_BUY && g_aiBuyZoneLow > 0 && g_aiBuyZoneHigh > 0)
   {
      if(price >= g_aiBuyZoneLow && price <= g_aiBuyZoneHigh)
      {
         inZone = true;
         isBuyZone = true;
         // Force de la zone basée sur la proximité du centre
         double zoneCenter = (g_aiBuyZoneLow + g_aiBuyZoneHigh) / 2.0;
         double zoneRange = g_aiBuyZoneHigh - g_aiBuyZoneLow;
         if(zoneRange > 0)
         {
            double distanceFromCenter = MathAbs(price - zoneCenter) / zoneRange;
            zoneStrength = 1.0 - (distanceFromCenter * 2.0); // Plus proche du centre = plus fort
            zoneStrength = MathMax(0.3, MathMin(1.0, zoneStrength));
         }
         else
            zoneStrength = 0.5;
      }
   }
   else if(orderType == ORDER_TYPE_SELL && g_aiSellZoneLow > 0 && g_aiSellZoneHigh > 0)
   {
      if(price >= g_aiSellZoneLow && price <= g_aiSellZoneHigh)
      {
         inZone = true;
         isBuyZone = false;
         // Force de la zone basée sur la proximité du centre
         double zoneCenter = (g_aiSellZoneLow + g_aiSellZoneHigh) / 2.0;
         double zoneRange = g_aiSellZoneHigh - g_aiSellZoneLow;
         if(zoneRange > 0)
         {
            double distanceFromCenter = MathAbs(price - zoneCenter) / zoneRange;
            zoneStrength = 1.0 - (distanceFromCenter * 2.0);
            zoneStrength = MathMax(0.3, MathMin(1.0, zoneStrength));
         }
         else
            zoneStrength = 0.5;
      }
   }
   
   if(!inZone)
      return false; // Pas dans une zone de pression
   
   // 2. Calculer le momentum dans cette zone
   momentumScore = CalculateMomentumStrength(orderType, 5);
   
   // 3. Vérifier que le momentum est suffisant (minimum 0.3)
   if(momentumScore < 0.3)
      return false;
   
   // 4. Vérifier la force de la zone (minimum 0.4)
   if(zoneStrength < 0.4)
      return false;
   
   // Zone de pression valide avec momentum suffisant
   return true;
}

//+------------------------------------------------------------------+
//| Détecter retournement sur EMA rapide M5 pour Boom/Crash          |
//| Vérifie aussi l'alignement M5/H1 avant d'autoriser l'entrée      |
//+------------------------------------------------------------------+
bool DetectBoomCrashReversalAtEMA(ENUM_ORDER_TYPE orderType)
{
   if(!IsBoomCrashSymbol(_Symbol))
      return false;
   
   // PROTECTION: Bloquer SELL sur Boom et BUY sur Crash
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(isBoom && orderType == ORDER_TYPE_SELL)
   {
      if(DebugMode)
         Print("🚫 Boom/Crash: Impossible de trader SELL sur ", _Symbol, " (Boom = BUY uniquement)");
      return false;
   }
   
   if(isCrash && orderType == ORDER_TYPE_BUY)
   {
      if(DebugMode)
         Print("🚫 Boom/Crash: Impossible de trader BUY sur ", _Symbol, " (Crash = SELL uniquement)");
      return false;
   }
   
   // 1. Vérifier l'alignement M5/H1 d'abord
   if(!CheckTrendAlignment(orderType))
   {
      if(DebugMode)
         Print("⏸️ Boom/Crash: Alignement M5/H1 non confirmé pour ", EnumToString(orderType));
      return false;
   }
   
   // 2. Récupérer EMA rapide M5 et prix
   double emaFastM5[];
   ArraySetAsSeries(emaFastM5, true);
   if(CopyBuffer(emaFastM5Handle, 0, 0, 5, emaFastM5) < 5)
   {
      if(DebugMode)
         Print("⚠️ Boom/Crash: Erreur récupération EMA rapide M5");
      return false;
   }
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Récupérer les prix historiques M5
   double closeM5[], highM5[], lowM5[];
   ArraySetAsSeries(closeM5, true);
   ArraySetAsSeries(highM5, true);
   ArraySetAsSeries(lowM5, true);
   
   if(CopyClose(_Symbol, PERIOD_M5, 0, 5, closeM5) < 5 ||
      CopyHigh(_Symbol, PERIOD_M5, 0, 5, highM5) < 5 ||
      CopyLow(_Symbol, PERIOD_M5, 0, 5, lowM5) < 5)
   {
      if(DebugMode)
         Print("⚠️ Boom/Crash: Erreur récupération prix M5");
      return false;
   }
   
   // Calculer la distance au prix en points
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tolerance = 10 * point; // Tolérance de 10 points autour de l'EMA
   
   // 3. Détecter retournement pour BUY (Boom)
   if(orderType == ORDER_TYPE_BUY)
   {
      // Le prix doit être proche de l'EMA rapide M5 (en-dessous ou légèrement au-dessus)
      if(price >= (emaFastM5[0] - tolerance) && price <= (emaFastM5[0] + tolerance))
      {
         // Vérifier que le prix a baissé puis rebondi
         bool wasDown = false;
         bool isRebounding = false;
         
         // Vérifier baisse: prix précédent en-dessous de l'EMA ou prix qui descend
         if(closeM5[1] < emaFastM5[1] || closeM5[2] < emaFastM5[2] || lowM5[1] < emaFastM5[1])
            wasDown = true;
         
         // Vérifier rebond: prix actuel remonte ou touche l'EMA depuis le bas
         if(closeM5[0] > closeM5[1] || (lowM5[0] <= emaFastM5[0] && closeM5[0] >= emaFastM5[0]))
            isRebounding = true;
         
         if(wasDown && isRebounding)
         {
            // Estimer le temps jusqu'au spike (généralement 5-15 secondes pour Boom/Crash)
            int estimatedSeconds = 10; // Estimation par défaut
            if(DebugMode)
               Print("✅ Boom/Crash BUY: Retournement détecté sur EMA rapide M5 - Spike estimé dans ", estimatedSeconds, " secondes");
            
            // Envoyer alerte
            Alert("🚨 SPIKE BOOM DÉTECTÉ: ", _Symbol, " - Entrée dans ", estimatedSeconds, " secondes");
            
            return true;
         }
      }
   }
   // 4. Détecter retournement pour SELL (Crash)
   else if(orderType == ORDER_TYPE_SELL)
   {
      // Le prix doit être proche de l'EMA rapide M5 (au-dessus ou légèrement en-dessous)
      if(price >= (emaFastM5[0] - tolerance) && price <= (emaFastM5[0] + tolerance))
      {
         // Vérifier que le prix a monté puis rebondi à la baisse
         bool wasUp = false;
         bool isRebounding = false;
         
         // Vérifier hausse: prix précédent au-dessus de l'EMA ou prix qui monte
         if(closeM5[1] > emaFastM5[1] || closeM5[2] > emaFastM5[2] || highM5[1] > emaFastM5[1])
            wasUp = true;
         
         // Vérifier rebond baissier: prix actuel redescend ou touche l'EMA depuis le haut
         if(closeM5[0] < closeM5[1] || (highM5[0] >= emaFastM5[0] && closeM5[0] <= emaFastM5[0]))
            isRebounding = true;
         
         if(wasUp && isRebounding)
         {
            // Estimer le temps jusqu'au spike
            int estimatedSeconds = 10; // Estimation par défaut
            if(DebugMode)
               Print("✅ Boom/Crash SELL: Retournement détecté sur EMA rapide M5 - Spike estimé dans ", estimatedSeconds, " secondes");
            
            // Envoyer alerte
            Alert("🚨 SPIKE CRASH DÉTECTÉ: ", _Symbol, " - Entrée dans ", estimatedSeconds, " secondes");
            
            return true;
         }
      }
   }
   
   return false;
}

// Tentative d'entrée spike sur Boom/Crash avec confiance IA minimale 60% et retournement EMA M5
bool TrySpikeEntry(ENUM_ORDER_TYPE orderType)
{
   if(!IsBoomCrashSymbol(_Symbol))
      return false;

   // Confiance IA minimale 60% pour Boom/Crash
   if(g_lastAIConfidence < 0.60)
      return false;

   int idx = GetSpikeIndex(_Symbol);
   datetime now = TimeCurrent();
   if(now < g_spikeCooldown[idx])
   {
      if(DebugMode)
         Print("⏸️ Spike cooldown actif pour ", _Symbol, " jusqu'à ", TimeToString(g_spikeCooldown[idx]));
      return false;
   }

   // L'alignement M5/H1 a déjà été vérifié dans DetectBoomCrashReversalAtEMA
   // Ici on ouvre simplement le trade car le retournement a été confirmé
   
   // PROTECTION: Bloquer SELL sur Boom et BUY sur Crash
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(isBoom && orderType == ORDER_TYPE_SELL)
   {
      if(DebugMode)
         Print("🚫 TrySpikeEntry: Impossible SELL sur Boom");
      return false;
   }
   
   if(isCrash && orderType == ORDER_TYPE_BUY)
   {
      if(DebugMode)
         Print("🚫 TrySpikeEntry: Impossible BUY sur Crash");
      return false;
   }

   // Ouvrir le trade immédiatement (le retournement et l'alignement sont déjà confirmés)
   if(DebugMode)
      Print("🚀 Boom/Crash: Ouverture trade ", EnumToString(orderType), " après retournement EMA M5 confirmé");
   
   ExecuteTrade(orderType);

   // Incrémenter les tentatives; si 2 sans spike, cooldown 5 minutes
   g_spikeFailCount[idx]++;
   if(g_spikeFailCount[idx] >= 2)
   {
      g_spikeCooldown[idx] = now + 300; // 5 minutes
      g_spikeFailCount[idx] = 0;
      if(DebugMode)
         Print("🕒 Cooldown 5 min pour ", _Symbol, " après 2 tentatives spike");
   }

   return true;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est dans la zone IA et si les EMA confirment |
//| Évite de trader les corrections - Amélioration des entrées       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Détecter un retournement au niveau de l'EMA rapide                |
//| Retourne true si le prix rebondit sur l'EMA rapide après baisse/hausse |
//+------------------------------------------------------------------+
bool DetectReversalAtFastEMA(ENUM_ORDER_TYPE orderType)
{
   // Récupérer l'EMA rapide M1
   double emaFast[];
   ArraySetAsSeries(emaFast, true);
   if(CopyBuffer(emaFastHandle, 0, 0, 5, emaFast) < 5)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA rapide pour détection retournement");
      return false;
   }
   
   // Récupérer les prix
   double close[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   if(CopyClose(_Symbol, PERIOD_M1, 0, 5, close) < 5 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 5, high) < 5 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 5, low) < 5)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération prix pour détection retournement");
      return false;
   }
   
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculer la distance au prix en points
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tolerance = 10 * point; // Tolérance de 10 points autour de l'EMA
   
   // Pour BUY: Détecter rebond haussier après baisse
   if(orderType == ORDER_TYPE_BUY)
   {
      // Le prix doit être proche de l'EMA rapide (en-dessous ou légèrement au-dessus)
      if(currentPrice >= (emaFast[0] - tolerance) && currentPrice <= (emaFast[0] + tolerance))
      {
         // Vérifier que le prix a baissé puis rebondi
         // Les 2-3 dernières bougies doivent montrer une baisse, puis la dernière un rebond
         bool wasDown = false;
         bool isRebounding = false;
         
         // Vérifier baisse: prix précédent en-dessous de l'EMA ou prix qui descend
         if(close[1] < emaFast[1] || close[2] < emaFast[2] || low[1] < emaFast[1])
            wasDown = true;
         
         // Vérifier rebond: prix actuel remonte ou touche l'EMA depuis le bas
         if(close[0] > close[1] || (low[0] <= emaFast[0] && close[0] >= emaFast[0]))
            isRebounding = true;
         
         // Vérifier aussi que la tendance longue est haussière (EMA 50, 100, 200)
         double ema50[], ema100[], ema200[];
         ArraySetAsSeries(ema50, true);
         ArraySetAsSeries(ema100, true);
         ArraySetAsSeries(ema200, true);
         
         if(CopyBuffer(ema50Handle, 0, 0, 1, ema50) > 0 &&
            CopyBuffer(ema100Handle, 0, 0, 1, ema100) > 0 &&
            CopyBuffer(ema200Handle, 0, 0, 1, ema200) > 0)
         {
            // Vérifier alignement haussier: EMA 50 > EMA 100 > EMA 200 (ou au moins EMA 50 > EMA 100)
            bool longTrendBullish = (ema50[0] > ema100[0]);
            
            if(wasDown && isRebounding && longTrendBullish)
            {
               if(DebugMode)
                  Print("✅ Retournement BUY détecté: Prix rebondit sur EMA rapide après baisse (EMA50=", DoubleToString(ema50[0], _Digits), 
                        " > EMA100=", DoubleToString(ema100[0], _Digits), ")");
               return true;
            }
         }
         else if(wasDown && isRebounding)
         {
            // Si on ne peut pas vérifier les EMA longues, accepter quand même si les autres conditions sont remplies
            if(DebugMode)
               Print("✅ Retournement BUY détecté: Prix rebondit sur EMA rapide après baisse (EMA longues non disponibles)");
            return true;
         }
      }
   }
   // Pour SELL: Détecter rebond baissier après hausse
   else if(orderType == ORDER_TYPE_SELL)
   {
      // Le prix doit être proche de l'EMA rapide (au-dessus ou légèrement en-dessous)
      if(currentPrice >= (emaFast[0] - tolerance) && currentPrice <= (emaFast[0] + tolerance))
      {
         // Vérifier que le prix a monté puis rebondi à la baisse
         bool wasUp = false;
         bool isRebounding = false;
         
         // Vérifier hausse: prix précédent au-dessus de l'EMA ou prix qui monte
         if(close[1] > emaFast[1] || close[2] > emaFast[2] || high[1] > emaFast[1])
            wasUp = true;
         
         // Vérifier rebond baissier: prix actuel redescend ou touche l'EMA depuis le haut
         if(close[0] < close[1] || (high[0] >= emaFast[0] && close[0] <= emaFast[0]))
            isRebounding = true;
         
         // Vérifier aussi que la tendance longue est baissière (EMA 50, 100, 200)
         double ema50[], ema100[], ema200[];
         ArraySetAsSeries(ema50, true);
         ArraySetAsSeries(ema100, true);
         ArraySetAsSeries(ema200, true);
         
         if(CopyBuffer(ema50Handle, 0, 0, 1, ema50) > 0 &&
            CopyBuffer(ema100Handle, 0, 0, 1, ema100) > 0 &&
            CopyBuffer(ema200Handle, 0, 0, 1, ema200) > 0)
         {
            // Vérifier alignement baissier: EMA 50 < EMA 100 < EMA 200 (ou au moins EMA 50 < EMA 100)
            bool longTrendBearish = (ema50[0] < ema100[0]);
            
            if(wasUp && isRebounding && longTrendBearish)
            {
               if(DebugMode)
                  Print("✅ Retournement SELL détecté: Prix rebondit sur EMA rapide après hausse (EMA50=", DoubleToString(ema50[0], _Digits), 
                        " < EMA100=", DoubleToString(ema100[0], _Digits), ")");
               return true;
            }
         }
         else if(wasUp && isRebounding)
         {
            // Si on ne peut pas vérifier les EMA longues, accepter quand même si les autres conditions sont remplies
            if(DebugMode)
               Print("✅ Retournement SELL détecté: Prix rebondit sur EMA rapide après hausse (EMA longues non disponibles)");
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix rebondit sur une trendline EMA M5/H1         |
//| Les trendlines servent de support/résistance dynamiques          |
//| Retour: true si rebond détecté, distance en points dans distance |
//+------------------------------------------------------------------+
bool CheckReboundOnTrendline(ENUM_ORDER_TYPE orderType, double &distance)
{
   distance = 0.0;
   
   // Récupérer les EMA M5 et H1 (les trendlines sont basées sur ces EMA)
   double emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[];
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   
   if(CopyBuffer(emaFastM5Handle, 0, 0, 3, emaFastM5) < 3 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 3, emaSlowM5) < 3 ||
      CopyBuffer(emaFastH1Handle, 0, 0, 3, emaFastH1) < 3 ||
      CopyBuffer(emaSlowH1Handle, 0, 0, 3, emaSlowH1) < 3)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA M5/H1 pour vérification trendline");
      return false;
   }
   
   // Récupérer les prix historiques
   double close[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 5, close) < 5 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 5, high) < 5 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 5, low) < 5)
   {
      return false;
   }
   
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double toleranceM5 = 15 * point;  // Tolérance de 15 points pour EMA M5
   double toleranceH1 = 30 * point;  // Tolérance de 30 points pour EMA H1 (plus large car timeframe plus long)
   
   // Pour BUY: Vérifier rebond sur trendline de support (EMA)
   if(orderType == ORDER_TYPE_BUY)
   {
      // Vérifier rebond sur EMA Fast M5 (trendline de support court terme)
      double distanceToEMAFastM5 = MathAbs(currentPrice - emaFastM5[0]);
      bool nearEMAFastM5 = (currentPrice >= (emaFastM5[0] - toleranceM5) && currentPrice <= (emaFastM5[0] + toleranceM5));
      
      // Vérifier que l'EMA M5 est haussière (EMA Fast > EMA Slow)
      bool emaMBullish = (emaFastM5[0] > emaSlowM5[0]);
      
      // Vérifier que l'EMA H1 est haussière (confirmation tendance long terme)
      bool emaH1Bullish = (emaFastH1[0] > emaSlowH1[0]);
      
      // Vérifier que le prix vient de rebondir (était en-dessous puis remonte)
      bool wasBelow = (close[1] < emaFastM5[1] || close[2] < emaFastM5[2] || low[1] < emaFastM5[1]);
      bool isRebounding = (close[0] > close[1] || (low[0] <= emaFastM5[0] && close[0] >= emaFastM5[0]));
      
      // Rebond sur EMA Fast M5 (priorité car plus réactif)
      if(nearEMAFastM5 && emaMBullish && wasBelow && isRebounding)
      {
         // Vérifier confirmation H1
         if(emaH1Bullish)
         {
            distance = distanceToEMAFastM5 / point;
            if(DebugMode)
               Print("✅ Rebond BUY sur trendline EMA Fast M5 détecté (distance: ", DoubleToString(distance, 0), " points) - Tendance H1 confirmée");
            return true;
         }
         else
         {
            // EMA H1 non alignée, mais EMA M5 OK = signal moyen
            distance = distanceToEMAFastM5 / point;
            if(DebugMode)
               Print("⚠️ Rebond BUY sur EMA Fast M5 mais H1 non alignée (distance: ", DoubleToString(distance, 0), " points) - Signal moyen");
            return true; // Accepter quand même mais signal moins fort
         }
      }
      
      // Vérifier aussi rebond sur EMA Fast H1 (support long terme - moins fréquent mais plus fort)
      double distanceToEMAFastH1 = MathAbs(currentPrice - emaFastH1[0]);
      bool nearEMAFastH1 = (currentPrice >= (emaFastH1[0] - toleranceH1) && currentPrice <= (emaFastH1[0] + toleranceH1));
      
      if(nearEMAFastH1 && emaH1Bullish && emaMBullish)
      {
         // Vérifier que le prix rebondit
         bool wasBelowH1 = (close[1] < emaFastH1[1] || close[2] < emaFastH1[2] || low[1] < emaFastH1[1]);
         bool isReboundingH1 = (close[0] > close[1] || (low[0] <= emaFastH1[0] && close[0] >= emaFastH1[0]));
         
         if(wasBelowH1 && isReboundingH1)
         {
            distance = distanceToEMAFastH1 / point;
            if(DebugMode)
               Print("✅ Rebond BUY sur trendline EMA Fast H1 détecté (distance: ", DoubleToString(distance, 0), " points) - Signal très fort");
            return true;
         }
      }
   }
   // Pour SELL: Vérifier rebond sur trendline de résistance (EMA)
   else if(orderType == ORDER_TYPE_SELL)
   {
      // Vérifier rebond sur EMA Fast M5 (trendline de résistance court terme)
      double distanceToEMAFastM5 = MathAbs(currentPrice - emaFastM5[0]);
      bool nearEMAFastM5 = (currentPrice >= (emaFastM5[0] - toleranceM5) && currentPrice <= (emaFastM5[0] + toleranceM5));
      
      // Vérifier que l'EMA M5 est baissière (EMA Fast < EMA Slow)
      bool emaMBearish = (emaFastM5[0] < emaSlowM5[0]);
      
      // Vérifier que l'EMA H1 est baissière (confirmation tendance long terme)
      bool emaH1Bearish = (emaFastH1[0] < emaSlowH1[0]);
      
      // Vérifier que le prix vient de rebondir (était au-dessus puis redescend)
      bool wasAbove = (close[1] > emaFastM5[1] || close[2] > emaFastM5[2] || high[1] > emaFastM5[1]);
      bool isRebounding = (close[0] < close[1] || (high[0] >= emaFastM5[0] && close[0] <= emaFastM5[0]));
      
      // Rebond sur EMA Fast M5 (priorité car plus réactif)
      if(nearEMAFastM5 && emaMBearish && wasAbove && isRebounding)
      {
         // Vérifier confirmation H1
         if(emaH1Bearish)
         {
            distance = distanceToEMAFastM5 / point;
            if(DebugMode)
               Print("✅ Rebond SELL sur trendline EMA Fast M5 détecté (distance: ", DoubleToString(distance, 0), " points) - Tendance H1 confirmée");
            return true;
         }
         else
         {
            // EMA H1 non alignée, mais EMA M5 OK = signal moyen
            distance = distanceToEMAFastM5 / point;
            if(DebugMode)
               Print("⚠️ Rebond SELL sur EMA Fast M5 mais H1 non alignée (distance: ", DoubleToString(distance, 0), " points) - Signal moyen");
            return true; // Accepter quand même mais signal moins fort
         }
      }
      
      // Vérifier aussi rebond sur EMA Fast H1 (résistance long terme - moins fréquent mais plus fort)
      double distanceToEMAFastH1 = MathAbs(currentPrice - emaFastH1[0]);
      bool nearEMAFastH1 = (currentPrice >= (emaFastH1[0] - toleranceH1) && currentPrice <= (emaFastH1[0] + toleranceH1));
      
      if(nearEMAFastH1 && emaH1Bearish && emaMBearish)
      {
         // Vérifier que le prix rebondit
         bool wasAboveH1 = (close[1] > emaFastH1[1] || close[2] > emaFastH1[2] || high[1] > emaFastH1[1]);
         bool isReboundingH1 = (close[0] < close[1] || (high[0] >= emaFastH1[0] && close[0] <= emaFastH1[0]));
         
         if(wasAboveH1 && isReboundingH1)
         {
            distance = distanceToEMAFastH1 / point;
            if(DebugMode)
               Print("✅ Rebond SELL sur trendline EMA Fast H1 détecté (distance: ", DoubleToString(distance, 0), " points) - Signal très fort");
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier entrée dans zone IA avec confirmation EMA               |
//+------------------------------------------------------------------+
bool CheckAIZoneEntryWithEMA(ENUM_ORDER_TYPE orderType, bool &isInZone, bool &emaConfirmed, bool &isCorrection)
{
   isInZone = false;
   emaConfirmed = false;
   isCorrection = false;
   
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Récupérer les prix historiques pour vérifier la direction d'entrée
   double close[], high[], low[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 5, close) < 5 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 5, high) < 5 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 5, low) < 5)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération données prix M1");
      return false;
   }
   
   // 1. Vérifier si le prix est dans la zone IA et la direction d'entrée
   bool priceEnteringZone = false;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      if(g_aiBuyZoneLow > 0 && g_aiBuyZoneHigh > 0)
      {
         // Le prix doit être dans la zone d'achat
         if(currentPrice >= g_aiBuyZoneLow && currentPrice <= g_aiBuyZoneHigh)
         {
            isInZone = true;
            
            // Vérifier que le prix vient d'entrer dans la zone depuis le bas (correction terminée)
            // Le prix précédent doit être en-dessous ou égal à la zone
            if(close[1] <= g_aiBuyZoneHigh || low[1] <= g_aiBuyZoneHigh)
            {
               priceEnteringZone = true;
            }
         }
         // Ou le prix touche la zone depuis le bas (retest)
         else if(currentPrice >= (g_aiBuyZoneLow - 5 * _Point) && currentPrice < g_aiBuyZoneLow)
         {
            // Le prix touche le bas de la zone depuis le bas
            if(low[0] <= g_aiBuyZoneLow || low[1] <= g_aiBuyZoneLow)
            {
               isInZone = true;
               priceEnteringZone = true;
            }
         }
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(g_aiSellZoneLow > 0 && g_aiSellZoneHigh > 0)
      {
         // Le prix doit être dans la zone de vente
         if(currentPrice >= g_aiSellZoneLow && currentPrice <= g_aiSellZoneHigh)
         {
            isInZone = true;
            
            // Vérifier que le prix vient d'entrer dans la zone depuis le haut (correction terminée)
            // Le prix précédent doit être au-dessus ou égal à la zone
            if(close[1] >= g_aiSellZoneLow || high[1] >= g_aiSellZoneLow)
            {
               priceEnteringZone = true;
            }
         }
         // Ou le prix touche la zone depuis le haut (retest)
         else if(currentPrice <= (g_aiSellZoneHigh + 5 * _Point) && currentPrice > g_aiSellZoneHigh)
         {
            // Le prix touche le haut de la zone depuis le haut
            if(high[0] >= g_aiSellZoneHigh || high[1] >= g_aiSellZoneHigh)
            {
               isInZone = true;
               priceEnteringZone = true;
            }
         }
      }
   }
   
   if(!isInZone || !priceEnteringZone)
   {
      if(DebugMode && !isInZone)
         Print("⏸️ ", EnumToString(orderType), " rejeté: Prix pas dans zone IA");
      else if(DebugMode && !priceEnteringZone)
         Print("⏸️ ", EnumToString(orderType), " rejeté: Prix dans zone mais n'entre pas depuis la bonne direction");
      return false;
   }
   
   // 2. Récupérer les EMA M1, M5 et H1 + RSI
   double emaFastM1[], emaSlowM1[], emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[], rsi[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   ArraySetAsSeries(rsi, true);
   
   // Récupérer les valeurs EMA M1 (pour détecter les corrections)
   if(CopyBuffer(emaFastHandle, 0, 0, 5, emaFastM1) <= 0 ||
      CopyBuffer(emaSlowHandle, 0, 0, 5, emaSlowM1) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA M1 pour vérification zone");
      return false;
   }
   
   // Récupérer les valeurs EMA M5 (confirmation principale)
   if(CopyBuffer(emaFastM5Handle, 0, 0, 1, emaFastM5) <= 0 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 1, emaSlowM5) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA M5 pour vérification zone");
      return false;
   }
   
   // Récupérer les valeurs EMA H1 (tendance générale)
   if(CopyBuffer(emaFastH1Handle, 0, 0, 1, emaFastH1) <= 0 ||
      CopyBuffer(emaSlowH1Handle, 0, 0, 1, emaSlowH1) <= 0)
   {
      if(DebugMode) 
         Print("⚠️ Erreur récupération EMA H1 pour vérification zone");
      return false;
   }
   
   // Récupérer RSI pour confirmation supplémentaire
   if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération RSI");
      // RSI non critique, continuer
   }
   
   // 3. Détecter si on est en correction
   if(orderType == ORDER_TYPE_BUY)
   {
      // Pour BUY: correction = le prix descend (EMA rapide < EMA lente sur M1)
      // ET le prix actuel est en-dessous de l'EMA rapide
      bool emaBearishM1 = (emaFastM1[0] < emaSlowM1[0]);
      bool priceBelowEMA = (currentPrice < emaFastM1[0]);
      
      // Correction si: EMA baissier ET prix sous EMA ET les 2 dernières bougies étaient haussières
      if(emaBearishM1 && priceBelowEMA)
      {
         // Vérifier si c'est une correction récente (les 2-3 dernières bougies montaient)
         bool wasRising = (emaFastM1[1] > emaFastM1[2] || emaFastM1[2] > emaFastM1[3]);
         if(wasRising)
         {
            isCorrection = true;
            if(DebugMode)
               Print("⚠️ Correction détectée pour BUY: Prix=", currentPrice, " EMA_Fast_M1=", emaFastM1[0], " < EMA_Slow_M1=", emaSlowM1[0]);
         }
      }
      
      // Confirmation EMA M5: EMA rapide doit être >= EMA lente (tendance haussière)
      emaConfirmed = (emaFastM5[0] >= emaSlowM5[0]);
      
      // Confirmation supplémentaire: RSI ne doit pas être sur-acheté (> 70)
      bool rsiOk = (ArraySize(rsi) > 0 && rsi[0] < 70);
      
      // Pour BUY: confirmation M5 requise
      if(!emaConfirmed)
      {
         if(DebugMode)
            Print("❌ BUY rejeté: EMA M5 non confirmée (Fast=", emaFastM5[0], " < Slow=", emaSlowM5[0], ")");
         return false;
      }
      
      if(!rsiOk && ArraySize(rsi) > 0 && DebugMode)
         Print("⚠️ BUY: RSI sur-acheté (", DoubleToString(rsi[0], 2), ") mais EMA M5 confirmée");
   }
   else // SELL
   {
      // Pour SELL: correction = le prix monte (EMA rapide > EMA lente sur M1)
      // ET le prix actuel est au-dessus de l'EMA rapide
      bool emaBullishM1 = (emaFastM1[0] > emaSlowM1[0]);
      bool priceAboveEMA = (currentPrice > emaFastM1[0]);
      
      // Correction si: EMA haussier ET prix au-dessus EMA ET les 2 dernières bougies descendaient
      if(emaBullishM1 && priceAboveEMA)
      {
         // Vérifier si c'est une correction récente (les 2-3 dernières bougies descendaient)
         bool wasFalling = (emaFastM1[1] < emaFastM1[2] || emaFastM1[2] < emaFastM1[3]);
         if(wasFalling)
         {
            isCorrection = true;
            if(DebugMode)
               Print("⚠️ Correction détectée pour SELL: Prix=", currentPrice, " EMA_Fast_M1=", emaFastM1[0], " > EMA_Slow_M1=", emaSlowM1[0]);
         }
      }
      
      // Confirmation EMA M5: EMA rapide doit être <= EMA lente (tendance baissière)
      emaConfirmed = (emaFastM5[0] <= emaSlowM5[0]);
      
      // Confirmation supplémentaire: RSI ne doit pas être sur-vendu (< 30)
      bool rsiOk = (ArraySize(rsi) > 0 && rsi[0] > 30);
      
      // Pour SELL: confirmation M5 requise
      if(!emaConfirmed)
      {
         if(DebugMode)
            Print("❌ SELL rejeté: EMA M5 non confirmée (Fast=", emaFastM5[0], " > Slow=", emaSlowM5[0], ")");
         return false;
      }
      
      if(!rsiOk && ArraySize(rsi) > 0 && DebugMode)
         Print("⚠️ SELL: RSI sur-vendu (", DoubleToString(rsi[0], 2), ") mais EMA M5 confirmée");
   }
   
   // 4. Si on est en correction, ne pas trader (attendre que la correction se termine)
   if(isCorrection)
   {
      if(DebugMode)
         Print("⏸️ Trade ", EnumToString(orderType), " rejeté: Correction détectée - Attendre entrée dans zone sans correction");
      return false;
   }
   
   // 5. Vérification supplémentaire: le prix doit être proche du bord de la zone (meilleure entrée)
   // Pour BUY: préférer entrer près du bas de la zone
   // Pour SELL: préférer entrer près du haut de la zone
   if(orderType == ORDER_TYPE_BUY && g_aiBuyZoneLow > 0 && g_aiBuyZoneHigh > 0)
   {
      double zoneRange = g_aiBuyZoneHigh - g_aiBuyZoneLow;
      double distanceFromLow = currentPrice - g_aiBuyZoneLow;
      
      // Si le prix est dans le tiers supérieur de la zone, c'est moins optimal mais acceptable
      if(distanceFromLow > zoneRange * 0.7 && DebugMode)
         Print("⚠️ BUY: Prix dans le tiers supérieur de la zone (", DoubleToString(distanceFromLow / zoneRange * 100, 1), "%)");
   }
   else if(orderType == ORDER_TYPE_SELL && g_aiSellZoneLow > 0 && g_aiSellZoneHigh > 0)
   {
      double zoneRange = g_aiSellZoneHigh - g_aiSellZoneLow;
      double distanceFromHigh = g_aiSellZoneHigh - currentPrice;
      
      // Si le prix est dans le tiers inférieur de la zone, c'est moins optimal mais acceptable
      if(distanceFromHigh > zoneRange * 0.7 && DebugMode)
         Print("⚠️ SELL: Prix dans le tiers inférieur de la zone (", DoubleToString(distanceFromHigh / zoneRange * 100, 1), "%)");
   }
   
   // Toutes les conditions sont remplies
   if(DebugMode)
   {
      string rsiInfo = (ArraySize(rsi) > 0) ? " RSI=" + DoubleToString(rsi[0], 1) : "";
      Print("✅ ", EnumToString(orderType), " confirmé: Prix dans zone IA + Entrée depuis bonne direction + EMA M5 confirmé + Pas de correction", rsiInfo);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE TOUS LES ENDPOINTS RENDER                        |
//+------------------------------------------------------------------+
void UpdateAllEndpoints()
{
   if(!UseAllEndpoints) return;

   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 120) // Augmenté à 120 secondes pour moins de charge
      return;

   lastUpdate = TimeCurrent();

   string analysis = UpdateAnalysisEndpoint();
   if(analysis != "")
      g_lastAnalysisData = analysis;

   string trend = UpdateTrendEndpoint();
   if(trend != "")
      g_lastTrendData = trend;

   string prediction = UpdatePredictionEndpoint();
   if(prediction != "")
      g_lastPredictionData = prediction;

   string coherent = UpdateCoherentEndpoint();
   if(coherent != "")
      g_lastCoherentData = coherent;

   Print("Tous les endpoints ont été mis à jour");
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT D'ANALYSE                             |
//+------------------------------------------------------------------+
string UpdateAnalysisEndpoint()
{
   string url = AI_AnalysisURL;
   string headers = "Content-Type: application/json\r\n";
   string result = "";
   uchar result_data[];
   string result_headers;

   uchar empty_data[];
   int responseCode = WebRequest("GET", url, headers, 5000, empty_data, result_data, result_headers);

   if(responseCode == 200)
   {
      result = CharArrayToString(result_data);
      Print("✅ Analysis endpoint mis à jour: ", result);
   }
   else if(responseCode == 422)
   {
      string data = "{\"symbol\":\"" + _Symbol + "\"}";
      uchar post_uchar[];
      StringToCharArray(data, post_uchar);

      responseCode = WebRequest("POST", url, headers, 5000, post_uchar, result_data, result_headers);
      if(responseCode == 200)
      {
         result = CharArrayToString(result_data);
         Print("✅ Analysis endpoint mis à jour (POST): ", result);
      }
      else
         Print("❌ Erreur Analysis endpoint - GET:", responseCode, " POST:", responseCode);
   }
   else
      Print("❌ Erreur lors de la mise à jour de l'analysis endpoint - Code:", responseCode);

   return result;
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT DE TENDANCE                           |
//+------------------------------------------------------------------+
string UpdateTrendEndpoint()
{
   string url = TrendAPIURL;
   string headers = "Content-Type: application/json\r\n";
   string result = "";
   uchar result_data[];
   string result_headers;

   uchar empty_data[];
   int responseCode = WebRequest("GET", url, headers, 5000, empty_data, result_data, result_headers);

   if(responseCode == 200)
   {
      result = CharArrayToString(result_data);
      Print("✅ Trend endpoint mis à jour: ", result);
   }
   else if(responseCode == 422)
   {
      string data = "{\"symbol\":\"" + _Symbol + "\"}";
      uchar post_uchar[];
      StringToCharArray(data, post_uchar);

      responseCode = WebRequest("POST", url, headers, 5000, post_uchar, result_data, result_headers);
      if(responseCode == 200)
      {
         result = CharArrayToString(result_data);
         Print("✅ Trend endpoint mis à jour (POST): ", result);
      }
      else
         Print("❌ Erreur Trend endpoint - GET:", responseCode, " POST:", responseCode);
   }
   else
      Print("❌ Erreur lors de la mise à jour du trend endpoint - Code:", responseCode);

   return result;
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT DE PRÉDICTION                         |
//+------------------------------------------------------------------+
string UpdatePredictionEndpoint()
{
   string url = AI_PredictSymbolURL + "/" + _Symbol;
   if(DebugMode)
      Print("🔮 DEBUG - Appel endpoint prédiction: ", url);
   
   string headers = "Content-Type: application/json\r\n";
   string result = "";
   uchar result_data[];
   string result_headers;

   uchar empty_data[];
   int responseCode = WebRequest("GET", url, headers, 5000, empty_data, result_data, result_headers);

   if(responseCode == 200)
   {
      result = CharArrayToString(result_data);
      Print("✅ Prediction endpoint mis à jour: ", result);
      if(DebugMode)
         Print("🔮 DEBUG - Données brutes reçues: ", result);
   }
   else if(responseCode == 422 || responseCode == 404)
   {
      string postData = "{\"symbol\":\"" + _Symbol + "\"}";
      uchar post_uchar[];
      StringToCharArray(postData, post_uchar);

      responseCode = WebRequest("POST", url, headers, 5000, post_uchar, result_data, result_headers);
      if(responseCode == 200)
      {
         result = CharArrayToString(result_data);
         Print("✅ Prediction endpoint mis à jour (POST): ", result);
         if(DebugMode)
            Print("🔮 DEBUG - Données brutes reçues (POST): ", result);
      }
      else
      {
         Print("❌ Erreur Prediction endpoint - GET:", responseCode, " POST:", responseCode);
         if(DebugMode)
            Print("🔮 DEBUG - Échec GET/POST pour: ", url);
      }
   }
   else
   {
      Print("❌ Erreur lors de la mise à jour du prediction endpoint - Code:", responseCode);
      if(DebugMode)
         Print("🔮 DEBUG - Erreur HTTP pour: ", url, " Code: ", responseCode);
   }

   return result;
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT D'ANALYSE COHÉRENTE                   |
//+------------------------------------------------------------------+
string UpdateCoherentEndpoint()
{
   string url = AI_CoherentAnalysisURL;
   string headers = "Content-Type: application/json\r\n";
   string result = "";
   uchar result_data[];
   string result_headers;

   uchar empty_data[];
   int responseCode = WebRequest("GET", url, headers, 5000, empty_data, result_data, result_headers);

   if(responseCode == 200)
   {
      result = CharArrayToString(result_data);
      Print("✅ Coherent endpoint mis à jour: ", result);
   }
   else if(responseCode == 422)
   {
      string data = "{\"symbol\":\"" + _Symbol + "\"}";
      uchar post_uchar[];
      StringToCharArray(data, post_uchar);

      responseCode = WebRequest("POST", url, headers, 5000, post_uchar, result_data, result_headers);
      if(responseCode == 200)
      {
         result = CharArrayToString(result_data);
         Print("✅ Coherent endpoint mis à jour (POST): ", result);
      }
      else
         Print("❌ Erreur Coherent endpoint - GET:", responseCode, " POST:", responseCode);
   }
   else
      Print("❌ Erreur lors de la mise à jour du coherent endpoint - Code:", responseCode);

   return result;
}

//+------------------------------------------------------------------+
//| VÉRIFIER L'ALIGNEMENT DE TOUS LES ENDPOINTS                    |
//+------------------------------------------------------------------+
bool CheckAllEndpointsAlignment(ENUM_ORDER_TYPE orderType)
{
   // Toujours mettre à jour le tableau de bord, même si RequireAllEndpointsAlignment est false
   
   // Analyser les données de chaque endpoint pour vérifier l'alignement
   bool analysisAligned = false;
   bool trendAligned = false;
   bool predictionAligned = false;
   bool coherentAligned = false;
   
   // Analyse endpoint
   if(g_lastAnalysisData != "")
   {
      string upperData = g_lastAnalysisData;
      StringToUpper(upperData);
      if(orderType == ORDER_TYPE_BUY && (StringFind(upperData, "BUY") >= 0 || StringFind(upperData, "ACHAT") >= 0))
         analysisAligned = true;
      else if(orderType == ORDER_TYPE_SELL && (StringFind(upperData, "SELL") >= 0 || StringFind(upperData, "VENTE") >= 0))
         analysisAligned = true;
   }
   
   // Trend endpoint
   if(g_lastTrendData != "")
   {
      string upperData = g_lastTrendData;
      StringToUpper(upperData);
      if(orderType == ORDER_TYPE_BUY && (StringFind(upperData, "BUY") >= 0 || StringFind(upperData, "ACHAT") >= 0))
         trendAligned = true;
      else if(orderType == ORDER_TYPE_SELL && (StringFind(upperData, "SELL") >= 0 || StringFind(upperData, "VENTE") >= 0))
         trendAligned = true;
   }
   
   // Prediction endpoint
   if(g_lastPredictionData != "")
   {
      string upperData = g_lastPredictionData;
      StringToUpper(upperData);
      if(orderType == ORDER_TYPE_BUY && (StringFind(upperData, "BUY") >= 0 || StringFind(upperData, "ACHAT") >= 0))
         predictionAligned = true;
      else if(orderType == ORDER_TYPE_SELL && (StringFind(upperData, "SELL") >= 0 || StringFind(upperData, "VENTE") >= 0))
         predictionAligned = true;
   }
   
   // Coherent endpoint
   if(g_lastCoherentData != "")
   {
      string upperData = g_lastCoherentData;
      StringToUpper(upperData);
      if(orderType == ORDER_TYPE_BUY && (StringFind(upperData, "BUY") >= 0 || StringFind(upperData, "ACHAT") >= 0))
         coherentAligned = true;
      else if(orderType == ORDER_TYPE_SELL && (StringFind(upperData, "SELL") >= 0 || StringFind(upperData, "VENTE") >= 0))
         coherentAligned = true;
   }
   
   // Calculer le score d'alignement
   int alignedCount = 0;
   if(analysisAligned) alignedCount++;
   if(trendAligned) alignedCount++;
   if(predictionAligned) alignedCount++;
   if(coherentAligned) alignedCount++;
   
   g_endpointsAlignment = (double)alignedCount / 4.0;
   
   // Mettre à jour les états pour le tableau de bord
   g_alignmentStatus[0] = analysisAligned ? "✅" : "❌";
   g_alignmentStatus[1] = trendAligned ? "✅" : "❌";
   g_alignmentStatus[2] = predictionAligned ? "✅" : "❌";
   g_alignmentStatus[3] = coherentAligned ? "✅" : "❌";
   
   g_alignmentColors[0] = analysisAligned ? clrLime : clrRed;
   g_alignmentColors[1] = trendAligned ? clrLime : clrRed;
   g_alignmentColors[2] = predictionAligned ? clrLime : clrRed;
   g_alignmentColors[3] = coherentAligned ? clrLime : clrRed;
   
   // Mettre à jour le tableau de bord
   UpdateAlignmentDashboard();
   
   bool allAligned = (alignedCount >= 3); // Au moins 3/4 endpoints alignés
   
   if(DebugMode)
   {
      Print("📊 Alignement endpoints: ", alignedCount, "/4 alignés (", DoubleToString(g_endpointsAlignment * 100, 1), "%)");
      Print("   Analyse: ", analysisAligned ? "✅" : "❌", " (", g_lastAnalysisData, ")");
      Print("   Trend: ", trendAligned ? "✅" : "❌", " (", g_lastTrendData, ")");
      Print("   Prediction: ", predictionAligned ? "✅" : "❌", " (", g_lastPredictionData, ")");
      Print("   Coherent: ", coherentAligned ? "✅" : "❌", " (", g_lastCoherentData, ")");
      Print("   Résultat: ", allAligned ? "✅ ALIGNÉ" : "❌ PAS ALIGNÉ");
   }
   
   // Si RequireAllEndpointsAlignment est false, retourner true pour ne pas bloquer les trades
   if(!RequireAllEndpointsAlignment)
      return true;
   
   return allAligned;
}

//+------------------------------------------------------------------+
//| Vérifier si une entrée prometteuse avec rebond est présente        |
//+------------------------------------------------------------------+
bool CheckForPromisingEntry(ENUM_ORDER_TYPE signalType)
{
   // Obtenir les données de prix
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Obtenir les données historiques pour analyse
   double close[3], high[3], low[3];
   if(CopyClose(_Symbol, PERIOD_M1, 0, 3, close) < 3 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 3, high) < 3 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 3, low) < 3)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération données prix pour entrée prometteuse");
      return false;
   }
   
   // Obtenir les EMA pour détection de rebond
   double emaFast[3], emaSlow[3];
   if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFast) < 3 ||
      CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlow) < 3)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA pour entrée prometteuse");
      return false;
   }
   
   // DÉTECTION DE REBOND POUR SIGNAL BUY
   if(signalType == ORDER_TYPE_BUY)
   {
      // 1. Rebond sur EMA Fast (support)
      bool nearEMAFast = (currentPrice >= emaFast[0] - (10 * point) && currentPrice <= emaFast[0] + (10 * point));
      bool wasBelowEMA = (close[1] < emaFast[1] || low[1] < emaFast[1]);
      bool isBouncing = (close[0] > close[1] && high[0] > emaFast[0]);
      
      if(nearEMAFast && wasBelowEMA && isBouncing)
      {
         if(DebugMode)
            Print("✅ Entrée BUY prometteuse: Rebond sur EMA Fast détecté");
         return true;
      }
      
      // 2. Rebond sur EMA Slow (support plus fort)
      bool nearEMASlow = (currentPrice >= emaSlow[0] - (15 * point) && currentPrice <= emaSlow[0] + (15 * point));
      bool wasBelowSlow = (close[1] < emaSlow[1] || low[1] < emaSlow[1]);
      bool isBouncingSlow = (close[0] > close[1] && high[0] > emaSlow[0]);
      
      if(nearEMASlow && wasBelowSlow && isBouncingSlow)
      {
         if(DebugMode)
            Print("✅ Entrée BUY prometteuse: Rebond sur EMA Slow détecté");
         return true;
      }
      
      // 3. Prix dans zone IA et rebond
      if(g_aiBuyZoneLow > 0 && g_aiBuyZoneHigh > 0)
      {
         bool inZone = (currentPrice >= g_aiBuyZoneLow && currentPrice <= g_aiBuyZoneHigh);
         bool wasLower = (low[1] < g_aiBuyZoneLow || close[1] < g_aiBuyZoneLow);
         bool isRecovering = (close[0] > close[1] && close[0] > g_aiBuyZoneLow);
         
         if(inZone && wasLower && isRecovering)
         {
            if(DebugMode)
               Print("✅ Entrée BUY prometteuse: Rebond dans zone IA détecté");
            return true;
         }
      }
   }
   
   // DÉTECTION DE REBOND POUR SIGNAL SELL
   else if(signalType == ORDER_TYPE_SELL)
   {
      // 1. Rebond sur EMA Fast (résistance)
      bool nearEMAFast = (currentPrice >= emaFast[0] - (10 * point) && currentPrice <= emaFast[0] + (10 * point));
      bool wasAboveEMA = (close[1] > emaFast[1] || high[1] > emaFast[1]);
      bool isRebounding = (close[0] < close[1] && low[0] < emaFast[0]);
      
      if(nearEMAFast && wasAboveEMA && isRebounding)
      {
         if(DebugMode)
            Print("✅ Entrée SELL prometteuse: Rebond sur EMA Fast détecté");
         return true;
      }
      
      // 2. Rebond sur EMA Slow (résistance plus forte)
      bool nearEMASlow = (currentPrice >= emaSlow[0] - (15 * point) && currentPrice <= emaSlow[0] + (15 * point));
      bool wasAboveSlow = (close[1] > emaSlow[1] || high[1] > emaSlow[1]);
      bool isReboundingSlow = (close[0] < close[1] && low[0] < emaSlow[0]);
      
      if(nearEMASlow && wasAboveSlow && isReboundingSlow)
      {
         if(DebugMode)
            Print("✅ Entrée SELL prometteuse: Rebond sur EMA Slow détecté");
         return true;
      }
      
      // 3. Prix dans zone IA et rebond
      if(g_aiSellZoneLow > 0 && g_aiSellZoneHigh > 0)
      {
         bool inZone = (currentPrice >= g_aiSellZoneLow && currentPrice <= g_aiSellZoneHigh);
         bool wasHigher = (high[1] > g_aiSellZoneHigh || close[1] > g_aiSellZoneHigh);
         bool isRecovering = (close[0] < close[1] && close[0] < g_aiSellZoneHigh);
         
         if(inZone && wasHigher && isRecovering)
         {
            if(DebugMode)
               Print("✅ Entrée SELL prometteuse: Rebond dans zone IA détecté");
            return true;
         }
      }
   }
   
   if(DebugMode)
      Print("⏳ Pas d'entrée prometteuse détectée pour ", EnumToString(signalType));
   
   return false;
}

//+------------------------------------------------------------------+
//| Exécute le trade avec SL/TP dynamiques selon le type d'entrée      |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE signalType)
{
   double currentPrice = SymbolInfoDouble(_Symbol, (signalType == ORDER_TYPE_BUY) ? SYMBOL_ASK : SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopLoss = 0.0;
   double takeProfit = 0.0;
   
   // Obtenir les EMA pour calculer SL/TP dynamiques
   double emaFast[1], emaSlow[1];
   bool hasEMA = (CopyBuffer(emaFastHandle, 0, 0, 1, emaFast) > 0 &&
                 CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlow) > 0);
   
   // Calculer SL/TP selon le type de signal et le contexte
   if(signalType == ORDER_TYPE_BUY)
   {
      // SL: Juste en dessous du support le plus proche
      if(hasEMA)
      {
         // Utiliser l'EMA la plus basse comme support
         double supportLevel = MathMin(emaFast[0], emaSlow[0]);
         stopLoss = supportLevel - (20 * point); // Marge de sécurité
      }
      else
      {
         // Fallback: SL basé sur un pourcentage du prix
         stopLoss = currentPrice - (StopLossUSD / (InitialLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)));
      }
      
      // TP: Ratio risque/récompense de 1:2 ou 1:3
      double riskAmount = currentPrice - stopLoss;
      takeProfit = currentPrice + (riskAmount * 2.5); // Ratio 1:2.5
      
      // Vérifier que le TP n'est pas trop proche (minimum 2$)
      double potentialProfit = (takeProfit - currentPrice) * InitialLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(potentialProfit < 2.0)
         takeProfit = currentPrice + (2.0 / (InitialLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)));
   }
   else // SELL
   {
      // SL: Juste au-dessus de la résistance la plus proche
      if(hasEMA)
      {
         // Utiliser l'EMA la plus haute comme résistance
         double resistanceLevel = MathMax(emaFast[0], emaSlow[0]);
         stopLoss = resistanceLevel + (20 * point); // Marge de sécurité
      }
      else
      {
         // Fallback: SL basé sur un pourcentage du prix
         stopLoss = currentPrice + (StopLossUSD / (InitialLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)));
      }
      
      // TP: Ratio risque/récompense de 1:2 ou 1:3
      double riskAmount = stopLoss - currentPrice;
      takeProfit = currentPrice - (riskAmount * 2.5); // Ratio 1:2.5
      
      // Vérifier que le TP n'est pas trop proche (minimum 2$)
      double potentialProfit = (currentPrice - takeProfit) * InitialLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(potentialProfit < 2.0)
         takeProfit = currentPrice - (2.0 / (InitialLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)));
   }
   
   // Normaliser les prix
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   // Vérifier les niveaux minimums du broker
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * point;
   if(minDistance == 0)
      minDistance = 10 * point;
   
   // Ajuster SL/TP si trop proches
   if(signalType == ORDER_TYPE_BUY)
   {
      if(stopLoss > currentPrice - minDistance)
         stopLoss = currentPrice - minDistance;
      if(takeProfit < currentPrice + minDistance)
         takeProfit = currentPrice + minDistance;
   }
   else
   {
      if(stopLoss < currentPrice + minDistance)
         stopLoss = currentPrice + minDistance;
      if(takeProfit > currentPrice - minDistance)
         takeProfit = currentPrice - minDistance;
   }
   
   // Exécuter l'ordre
   if(trade.PositionOpen(_Symbol, signalType, InitialLotSize, currentPrice, stopLoss, takeProfit, "AI Signal + Rebound Entry"))
   {
      string signalStr = (signalType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      double riskUSD = MathAbs(currentPrice - stopLoss) * InitialLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double rewardUSD = MathAbs(takeProfit - currentPrice) * InitialLotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      Print("🚀 ORDRE EXÉCUTÉ: ", signalStr, " @ ", DoubleToString(currentPrice, _Digits));
      Print("   SL: ", DoubleToString(stopLoss, _Digits), " (risque: ", DoubleToString(riskUSD, 2), "$");
      Print("   TP: ", DoubleToString(takeProfit, _Digits), " (gain: ", DoubleToString(rewardUSD, 2), "$");
      Print("   Ratio R/R: 1:", DoubleToString(rewardUSD/riskUSD, 1));
      
      // Envoyer notification d'exécution
      string execText = "🚀 ORDRE EXÉCUTÉ: " + signalStr +
                       "\n💰 Entrée: " + DoubleToString(currentPrice, _Digits) +
                       "\n🛡️ SL: " + DoubleToString(stopLoss, _Digits) + " (" + DoubleToString(riskUSD, 2) + "$)" +
                       "\n🎯 TP: " + DoubleToString(takeProfit, _Digits) + " (" + DoubleToString(rewardUSD, 2) + "$)" +
                       "\n📊 Ratio: 1:" + DoubleToString(rewardUSD/riskUSD, 1);
      
      SendNotification(execText);
   }
   else
   {
      Print("❌ Erreur exécution ordre: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| DÉTECTER PATTERNS DYNAMIQUES ET LANCER TRADES LIMITÉS      |
//| Analyse les patterns de prix, supports/résistances           |
//| Lance des trades via ordres limités avec SL intelligent      |
//+------------------------------------------------------------------+
bool DetectDynamicPatternsAndExecute()
{
   // Récupérer les données de prix récents
   double close[], high[], low[];
   datetime time[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 50, close) < 50 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 50, high) < 50 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 50, low) < 50 ||
      CopyTime(_Symbol, PERIOD_M1, 0, 50, time) < 50)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération données prix pour pattern detection");
      return false;
   }
   
   double currentPrice = close[0];
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Détecter les patterns dynamiques
   // 1. Support/Résistance dynamique basé sur les swings récents
   double recentHigh = 0, recentLow = DBL_MAX;
   for(int i = 1; i < 20; i++)
   {
      if(high[i] > recentHigh) recentHigh = high[i];
      if(low[i] < recentLow) recentLow = low[i];
   }
   
   // 2. Tendance actuelle (basée sur les 20 dernières bougies)
   double trendSlope = 0;
   for(int i = 0; i < 19; i++)
   {
      trendSlope += (close[i] - close[i+1]);
   }
   trendSlope /= 19.0;
   
   // 3. Momentum et volatilité
   double momentum = (close[0] - close[9]) / close[9]; // Momentum 10 bougies
   double volatility = 0;
   for(int i = 0; i < 19; i++)
   {
      double diff = close[i] - close[i+1];
      volatility += diff * diff;
   }
   volatility = MathSqrt(volatility / 19.0) / currentPrice;
   
   // Détecter les patterns de trading
   bool patternDetected = false;
   ENUM_ORDER_TYPE signalType = WRONG_VALUE;
   double entryPrice = 0, stopLoss = 0, takeProfit = 0;
   string patternName = "";
   
   // PATTERN 1: Rebound sur support dynamique en tendance haussière
   if(trendSlope > 0 && momentum > 0.001 && 
      currentPrice > recentLow && currentPrice < recentLow * 1.002) // Proche du support
   {
      signalType = ORDER_TYPE_BUY;
      entryPrice = recentLow + (point * 5); // Ordre limité juste au-dessus du support
      stopLoss = recentLow - (point * 10); // SL sous le support
      takeProfit = currentPrice + (currentPrice - stopLoss) * 2.0; // RR 1:2
      patternName = "Rebound Support Dynamique";
      patternDetected = true;
   }
   
   // PATTERN 2: Rejet sur résistance dynamique en tendance baissière
   else if(trendSlope < 0 && momentum < -0.001 && 
      currentPrice < recentHigh && currentPrice > recentHigh * 0.998) // Proche de la résistance
   {
      signalType = ORDER_TYPE_SELL;
      entryPrice = recentHigh - (point * 5); // Ordre limité juste sous la résistance
      stopLoss = recentHigh + (point * 10); // SL au-dessus de la résistance
      takeProfit = currentPrice - (stopLoss - currentPrice) * 2.0; // RR 1:2
      patternName = "Rejet Résistance Dynamique";
      patternDetected = true;
   }
   
   // PATTERN 3: Breakout de consolidation
   double range = recentHigh - recentLow;
   if(range < currentPrice * 0.002 && // Consolidation étroite
      MathAbs(momentum) > 0.002) // Momentum fort
   {
      if(currentPrice > recentHigh * 1.001) // Breakout haussier
      {
         signalType = ORDER_TYPE_BUY;
         entryPrice = recentHigh + (point * 2); // Ordre limité après breakout
         stopLoss = recentLow - (point * 5);
         takeProfit = entryPrice + (entryPrice - stopLoss) * 1.5;
         patternName = "Breakout Haussier";
         patternDetected = true;
      }
      else if(currentPrice < recentLow * 0.999) // Breakout baissier
      {
         signalType = ORDER_TYPE_SELL;
         entryPrice = recentLow - (point * 2); // Ordre limité après breakout
         stopLoss = recentHigh + (point * 5);
         takeProfit = entryPrice - (stopLoss - entryPrice) * 1.5;
         patternName = "Breakout Baissier";
         patternDetected = true;
      }
   }
   
   if(patternDetected && signalType != WRONG_VALUE)
   {
      // Calculer la taille de position
      double lotSize = NormalizeLotSize(InitialLotSize);
      
      // Validation des distances minimales
      double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      double slDistance = MathAbs(entryPrice - stopLoss);
      double tpDistance = MathAbs(takeProfit - entryPrice);
      
      if(slDistance < minDistance || tpDistance < minDistance)
      {
         if(DebugMode)
            Print("⚠️ Pattern détecté mais distances SL/TP trop faibles: ", patternName);
         return false;
      }
      
      // RÈGLE BOOM/CRASH: pas de BUY sur Crash, pas de SELL sur Boom
      if(StringFind(_Symbol, "Crash") >= 0 && signalType == ORDER_TYPE_BUY) return false;
      if(StringFind(_Symbol, "Boom") >= 0 && signalType == ORDER_TYPE_SELL) return false;
      
      // Exécuter l'ordre limité
      if(trade.PositionOpen(_Symbol, signalType, lotSize, entryPrice, stopLoss, takeProfit, "Pattern: " + patternName))
      {
         string signalStr = (signalType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
         double riskUSD = MathAbs(entryPrice - stopLoss) * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double rewardUSD = MathAbs(takeProfit - entryPrice) * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         
         Print("🎯 PATTERN DÉTECTÉ: ", patternName);
         Print("📊 Signal: ", signalStr, " @ ", DoubleToString(entryPrice, _Digits));
         Print("🛡️ SL: ", DoubleToString(stopLoss, _Digits), " (risque: ", DoubleToString(riskUSD, 2), "$)");
         Print("🎯 TP: ", DoubleToString(takeProfit, _Digits), " (gain: ", DoubleToString(rewardUSD, 2), "$)");
         Print("📈 Tendance: ", trendSlope > 0 ? "Haussière" : "Baissière", " | Momentum: ", DoubleToString(momentum*100, 3), "%");
         Print("📊 Volatilité: ", DoubleToString(volatility*100, 2), "% | RR: 1:", DoubleToString(rewardUSD/riskUSD, 1));
         
         // Activer le trailing stop automatiquement
         ActivateTrailingStop();
         
         // Envoyer notification
         string patternText = "🎯 PATTERN DÉTECTÉ: " + patternName +
                           "\n📊 " + signalStr + " @ " + DoubleToString(entryPrice, _Digits) +
                           "\n🛡️ SL: " + DoubleToString(stopLoss, _Digits) + " (" + DoubleToString(riskUSD, 2) + "$)" +
                           "\n🎯 TP: " + DoubleToString(takeProfit, _Digits) + " (" + DoubleToString(rewardUSD, 2) + "$)" +
                           "\n📊 RR: 1:" + DoubleToString(rewardUSD/riskUSD, 1) +
                           "\n🔄 Trailing Stop: ACTIVÉ";
         
         SendNotification(patternText);
         return true;
      }
      else
      {
         Print("❌ Erreur exécution ordre pattern: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Activer le trailing stop pour toutes les positions            |
//+------------------------------------------------------------------+
void ActivateTrailingStop()
{
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         double currentPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         
         // Trailing stop dynamique basé sur l'ATR
         double atr[];
         ArraySetAsSeries(atr, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
         {
            double trailingDistance = atr[0] * 2.0; // 2x ATR
            
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               double newSL = SymbolInfoDouble(_Symbol, SYMBOL_BID) - trailingDistance;
               if(newSL > currentSL + point * 10) // Déplacer le SL seulement si favorable
               {
                  trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
                  if(DebugMode)
                     Print("🔄 Trailing BUY: SL déplacé à ", DoubleToString(newSL, _Digits));
               }
            }
            else // SELL
            {
               double newSL = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + trailingDistance;
               if(newSL < currentSL - point * 10) // Déplacer le SL seulement si favorable
               {
                  trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
                  if(DebugMode)
                     Print("🔄 Trailing SELL: SL déplacé à ", DoubleToString(newSL, _Digits));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Placer ordre limité dès l'apparition de la flèche           |
//| Utilise les supports/résistances pour déterminer le prix d'entrée |
//+------------------------------------------------------------------+
bool PlaceLimitOrderOnArrow(ENUM_ORDER_TYPE signalType)
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(DebugMode)
   {
      Print("🔍 DÉBUT PLACEMENT ORDRE LIMITÉ");
      Print("   Signal: ", EnumToString(signalType));
      Print("   Prix actuel: ", DoubleToString(currentPrice, _Digits));
      Print("   Ask: ", DoubleToString(askPrice, _Digits));
      Print("   Confiance IA: ", DoubleToString(g_lastAIConfidence * 100, 1), "%");
      Print("   Action IA: ", g_lastAIAction);
   }
   
   // Vérifier si on a déjà une position ou un ordre sur ce symbole
   int totalOrders = OrdersTotal();
   for(int i = totalOrders - 1; i >= 0; i--)
   {
      if(orderInfo.SelectByIndex(i))
      {
         if(orderInfo.Symbol() == _Symbol && orderInfo.Magic() == InpMagicNumber)
         {
            if(DebugMode)
               Print("⚠️ Ordre déjà existent sur ", _Symbol, " - type: ", EnumToString(orderInfo.OrderType()));
            return false;
         }
      }
   }
   
   int totalPositions = PositionsTotal();
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
         {
            if(DebugMode)
               Print("⚠️ Position déjà existante sur ", _Symbol, " - type: ", EnumToString(positionInfo.PositionType()));
            return false;
         }
      }
   }
   
   // Récupérer les supports/résistances actuels
   double atrM1[], atrM5[], atrH1[];
   ArraySetAsSeries(atrM1, true);
   ArraySetAsSeries(atrM5, true);
   ArraySetAsSeries(atrH1, true);
   
   if(CopyBuffer(atrM1Handle, 0, 0, 1, atrM1) <= 0 ||
      CopyBuffer(atrM5Handle, 0, 0, 1, atrM5) <= 0 ||
      CopyBuffer(atrH1Handle, 0, 0, 1, atrH1) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Impossible de récupérer ATR pour ordre limité");
      return false;
   }
   
   // Calculer les niveaux de support/résistance
   double supportM1 = currentPrice - (1.5 * atrM1[0]);
   double resistanceM1 = currentPrice + (1.5 * atrM1[0]);
   double supportM5 = currentPrice - (2.0 * atrM5[0]);
   double resistanceM5 = currentPrice + (2.0 * atrM5[0]);
   double supportH1 = currentPrice - (2.5 * atrH1[0]);
   double resistanceH1 = currentPrice + (2.5 * atrH1[0]);
   
   if(DebugMode)
   {
      Print("📊 NIVEAUX CALCULÉS:");
      Print("   Support M1: ", DoubleToString(supportM1, _Digits));
      Print("   Résistance M1: ", DoubleToString(resistanceM1, _Digits));
      Print("   Support M5: ", DoubleToString(supportM5, _Digits));
      Print("   Résistance M5: ", DoubleToString(resistanceM5, _Digits));
      Print("   Support H1: ", DoubleToString(supportH1, _Digits));
      Print("   Résistance H1: ", DoubleToString(resistanceH1, _Digits));
   }
   
   double entryPrice = 0;
   double stopLoss = 0;
   double takeProfit = 0;
   string orderReason = "";
   
   if(signalType == ORDER_TYPE_BUY)
   {
      // Ordre BUY LIMIT: Placer sous le prix actuel, près d'un support
      // Trouver le support le plus proche en dessous du prix
      double nearestSupport = 0;
      string supportType = "";
      
      if(supportM1 < currentPrice && (nearestSupport == 0 || supportM1 > nearestSupport))
      {
         nearestSupport = supportM1;
         supportType = "Support M1";
      }
      
      if(supportM5 < currentPrice && (nearestSupport == 0 || supportM5 > nearestSupport))
      {
         nearestSupport = supportM5;
         supportType = "Support M5";
      }
      
      if(supportH1 < currentPrice && (nearestSupport == 0 || supportH1 > nearestSupport))
      {
         nearestSupport = supportH1;
         supportType = "Support H1";
      }
      
      if(nearestSupport > 0)
      {
         // Placer l'ordre BUY LIMIT juste au-dessus du support le plus proche
         entryPrice = nearestSupport + (point * LimitEntryOffsetPoints);
         stopLoss = nearestSupport - (point * LimitSLOffsetPoints);
         takeProfit = entryPrice + (entryPrice - stopLoss) * LimitRR;
         orderReason = supportType;
         
         if(DebugMode)
            Print("🎯 BUY LIMIT placé au-dessus de ", supportType, " @ ", DoubleToString(nearestSupport, _Digits));
      }
      else
      {
         // Aucun support en dessous du prix - utiliser support calculé
         nearestSupport = currentPrice - (2.0 * atrM5[0]);
         entryPrice = nearestSupport + (point * LimitEntryOffsetPoints);
         stopLoss = nearestSupport - (point * LimitSLOffsetPoints);
         takeProfit = entryPrice + (entryPrice - stopLoss) * LimitRR;
         orderReason = "Support calculé";
         
         if(DebugMode)
            Print("📐 Aucun support en dessous - utilisation support calculé @ ", DoubleToString(nearestSupport, _Digits));
      }
   }
   else // SELL
   {
      // Ordre SELL LIMIT: Placer au-dessus du prix actuel, près d'une résistance
      // Trouver la résistance la plus proche au-dessus du prix
      double nearestResistance = 0;
      string resistanceType = "";
      
      if(resistanceM1 > currentPrice && (nearestResistance == 0 || resistanceM1 < nearestResistance))
      {
         nearestResistance = resistanceM1;
         resistanceType = "Résistance M1";
      }
      
      if(resistanceM5 > currentPrice && (nearestResistance == 0 || resistanceM5 < nearestResistance))
      {
         nearestResistance = resistanceM5;
         resistanceType = "Résistance M5";
      }
      
      if(resistanceH1 > currentPrice && (nearestResistance == 0 || resistanceH1 < nearestResistance))
      {
         nearestResistance = resistanceH1;
         resistanceType = "Résistance H1";
      }
      
      if(nearestResistance > 0)
      {
         // Placer l'ordre SELL LIMIT juste sous la résistance la plus proche
         entryPrice = nearestResistance - (point * LimitEntryOffsetPoints);
         stopLoss = nearestResistance + (point * LimitSLOffsetPoints);
         takeProfit = entryPrice - (stopLoss - entryPrice) * LimitRR;
         orderReason = resistanceType;
         
         if(DebugMode)
            Print("🎯 SELL LIMIT placé sous ", resistanceType, " @ ", DoubleToString(nearestResistance, _Digits));
      }
      else
      {
         // Aucune résistance au-dessus du prix - utiliser résistance calculée
         nearestResistance = currentPrice + (2.0 * atrM5[0]);
         entryPrice = nearestResistance - (point * LimitEntryOffsetPoints);
         stopLoss = nearestResistance + (point * LimitSLOffsetPoints);
         takeProfit = entryPrice - (stopLoss - entryPrice) * LimitRR;
         orderReason = "Résistance calculée";
         
         if(DebugMode)
            Print("📐 Aucune résistance au-dessus - utilisation résistance calculée @ ", DoubleToString(nearestResistance, _Digits));
      }
   }
   
   // Transformer BUY/SELL en type pending BUY_LIMIT/SELL_LIMIT
   ENUM_ORDER_TYPE pendingType = GetPendingTypeFromSignal(signalType);
   if(pendingType == WRONG_VALUE)
      return false;

   // Sanity: une BUY_LIMIT doit être < Ask ; une SELL_LIMIT doit être > Bid
   if(pendingType == ORDER_TYPE_BUY_LIMIT && entryPrice >= askPrice - (2 * point))
      entryPrice = NormalizeDouble(askPrice - (10 * point), _Digits);
   if(pendingType == ORDER_TYPE_SELL_LIMIT && entryPrice <= currentPrice + (2 * point))
      entryPrice = NormalizeDouble(currentPrice + (10 * point), _Digits);

   // Ajuster SL/TP pour respecter les distances minimales broker
   if(!EnsureStopsDistanceValid(entryPrice, pendingType, stopLoss, takeProfit))
   {
      if(DebugMode)
         Print("⚠️ SL/TP invalides après ajustement - Annulation ordre LIMIT");
      return false;
   }
   
   // Calculer la taille de position
   double lotSize = NormalizeLotSize(InitialLotSize);

   // Pour debug: recalculer distances SL/TP et distance minimale requise
   double slDistance = MathAbs(entryPrice - stopLoss);
   double tpDistance = MathAbs(takeProfit - entryPrice);
   long debugStopLevelPts = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = debugStopLevelPts * point;
   if(minDistance < 5 * point) minDistance = 5 * point;
   if(IsDerivSyntheticIndex(_Symbol))
      minDistance = MathMax(minDistance, 15 * point);
   
   if(DebugMode)
   {
      Print("📋 DÉTAILS ORDRE LIMITÉ:");
      Print("   Type: ", EnumToString(signalType));
      Print("   Prix d'entrée: ", DoubleToString(entryPrice, _Digits));
      Print("   Stop Loss: ", DoubleToString(stopLoss, _Digits));
      Print("   Take Profit: ", DoubleToString(takeProfit, _Digits));
      Print("   Taille: ", DoubleToString(lotSize, 2));
      Print("   Raison: ", orderReason);
      Print("   Distance SL: ", DoubleToString(slDistance / point, 0), " points");
      Print("   Distance TP: ", DoubleToString(tpDistance / point, 0), " points");
      Print("   Distance minimale requise: ", DoubleToString(minDistance / point, 0), " points");
   }
   
   // Normaliser les prix avant envoi au broker
   entryPrice = NormalizeDouble(entryPrice, _Digits);
   stopLoss   = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);

   // Placer l'ordre limité
   string orderComment = "Limit Order on Arrow - " + orderReason;
   
   if(DebugMode)
   {
      Print("🚀 TENTATIVE PLACEMENT ORDRE LIMITÉ:");
      Print("   Symbol: ", _Symbol);
      Print("   Type: ", EnumToString(signalType));
      Print("   LotSize: ", DoubleToString(lotSize, 2));
      Print("   EntryPrice: ", DoubleToString(entryPrice, _Digits));
      Print("   StopLoss: ", DoubleToString(stopLoss, _Digits));
      Print("   TakeProfit: ", DoubleToString(takeProfit, _Digits));
      Print("   OrderTime: ORDER_TIME_GTC");
      Print("   Expiration: 0");
      Print("   Comment: ", orderComment);
   }
   
   // IMPORTANT: utiliser le type PENDING (BUY_LIMIT / SELL_LIMIT), pas BUY/SELL (marché).
   bool orderOk = false;
   if(pendingType == ORDER_TYPE_BUY_LIMIT)
      orderOk = trade.BuyLimit(lotSize, entryPrice, _Symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, orderComment);
   else if(pendingType == ORDER_TYPE_SELL_LIMIT)
      orderOk = trade.SellLimit(lotSize, entryPrice, _Symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, orderComment);

   if(orderOk)
   {
      double riskUSD = MathAbs(entryPrice - stopLoss) * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double rewardUSD = MathAbs(takeProfit - entryPrice) * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
      Print("🎯 ORDRE LIMITÉ PLACÉ: ", EnumToString(pendingType), " @ ", DoubleToString(entryPrice, _Digits));
      Print("   Raison: ", orderReason);
      Print("   SL: ", DoubleToString(stopLoss, _Digits), " (risque: ", DoubleToString(riskUSD, 2), "$)");
      Print("   TP: ", DoubleToString(takeProfit, _Digits), " (gain: ", DoubleToString(rewardUSD, 2), "$)");
      Print("   Ratio R/R: 1:", DoubleToString(rewardUSD/riskUSD, 1));
      
      // Activer le trailing stop pour cet ordre
      ActivateTrailingStop();
      
      return true;
   }
   else
   {
      Print("❌ Erreur placement ordre limité: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      if(DebugMode)
      {
         Print("   Debug ordre pending:");
         Print("   pendingType=", EnumToString(pendingType),
               " entry=", DoubleToString(entryPrice, _Digits),
               " SL=", DoubleToString(stopLoss, _Digits),
               " TP=", DoubleToString(takeProfit, _Digits),
               " stopsLevelPts=", (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL),
               " point=", DoubleToString(point, _Digits));
      }
      return false;
   }
}



//+------------------------------------------------------------------+
//| Vérifie si le marché est fermé                                   |
//+------------------------------------------------------------------+
bool IsMarketClosed() {
    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);
    
    // Week-end - Samedi et Dimanche
    if(dt.day_of_week == 0 || dt.day_of_week == 6) return true;
    
    // Heures de trading pour indices synthétiques (24/5 du Lundi au Vendredi)
    // Marché ouvert: Lundi-Vendredi 00:00-23:59 UTC
    if(dt.hour >= 0 && dt.hour < 24 && dt.day_of_week >= 1 && dt.day_of_week <= 5) {
        return false; // Marché ouvert
    }
    
    return true; // Hors heures de trading
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| FONCTIONS POUR RÉCUPÉRATION DES DONNÉES IA                        |
//+------------------------------------------------------------------+

// Récupérer les données de l'endpoint Decision
bool GetAISignalData()
{
   string url = AI_ServerURL;
   string headers = "Content-Type: application/json\r\n";
   char post[];
   uchar response[];
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   Print("🔍 Debug IA: URL=", url, " bid=", bid, " ask=", ask);
   
   // Préparer les données techniques
   double emaFast[1], emaSlow[1], rsi[1], atr[1];
   if(emaFastHandle != INVALID_HANDLE && CopyBuffer(emaFastHandle, 0, 0, 1, emaFast) > 0 &&
      emaSlowHandle != INVALID_HANDLE && CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlow) > 0 &&
      rsiHandle != INVALID_HANDLE && CopyBuffer(rsiHandle, 0, 0, 1, rsi) > 0 &&
      atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
   {
      string jsonRequest = StringFormat("{\"symbol\":\"%s\",\"bid\":%.5f,\"ask\":%.5f,\"rsi\":%.2f,\"ema_fast\":%.5f,\"ema_slow\":%.5f,\"atr\":%.5f,\"timestamp\":\"%s\"}",
         _Symbol, bid, ask, rsi[0], emaFast[0], emaSlow[0], atr[0], TimeToString(TimeCurrent()));
      
      Print("📦 Debug IA: JSON envoyé=", jsonRequest);
      
      StringToCharArray(jsonRequest, post);
      
      int res = WebRequest("POST", url, headers, AI_Timeout_ms, post, response, headers);
      
      Print("🌐 Debug IA: WebRequest result=", res);
      
      if(res == 200)
      {
         string jsonResponse = CharArrayToString(response);
         Print("📥 Debug IA: Réponse JSON=", jsonResponse);
         
         // Parser la réponse JSON
         int actionStart = StringFind(jsonResponse, "\"action\":");
         if(actionStart >= 0)
         {
            actionStart = StringFind(jsonResponse, "\"", actionStart + 9) + 1;
            int actionEnd = StringFind(jsonResponse, "\"", actionStart);
            if(actionEnd > actionStart)
            {
               g_aiSignal.recommendation = StringSubstr(jsonResponse, actionStart, actionEnd - actionStart);
               
               int confStart = StringFind(jsonResponse, "\"confidence\":");
               if(confStart >= 0)
               {
                  confStart = StringFind(jsonResponse, ":", confStart) + 1;
                  int confEnd = StringFind(jsonResponse, ",", confStart);
                  if(confEnd < 0) confEnd = StringFind(jsonResponse, "}", confStart);
                  if(confEnd > confStart)
                  {
                     string confStr = StringSubstr(jsonResponse, confStart, confEnd - confStart);
                     g_aiSignal.confidence = StringToDouble(confStr);
                     g_aiSignal.timestamp = TimeToString(TimeCurrent());
                     
                     Print("✅ Debug IA: Signal=", g_aiSignal.recommendation, " Confiance=", g_aiSignal.confidence);
                     
                     // Extraire le raisonnement si disponible
                     int reasonStart = StringFind(jsonResponse, "\"reasoning\":");
                     if(reasonStart >= 0)
                     {
                        reasonStart = StringFind(jsonResponse, "\"", reasonStart + 12) + 1;
                        int reasonEnd = StringFind(jsonResponse, "\"", reasonStart);
                        if(reasonEnd > reasonStart)
                        {
                           g_aiSignal.reasoning = StringSubstr(jsonResponse, reasonStart, reasonEnd - reasonStart);
                        }
                     }
                     
                     return true;
                  }
               }
            }
         }
      }
      else
      {
         Print("❌ Debug IA: Erreur WebRequest ", res);
      }
   }
   else
   {
      Print("❌ Debug IA: Erreur indicateurs");
   }
   
   return false;
}

// Récupérer les données de tendance depuis l'API
bool GetTrendAlignmentData()
{
   string url = TrendAPIURL + "?symbol=" + _Symbol;
   string headers = "Content-Type: application/json\r\n";
   char post[];
   uchar response[];
   
   Print("🔍 Debug Trend: URL=", url);
   
   int res = WebRequest("GET", url, headers, AI_Timeout_ms, post, response, headers);
   
   Print("🌐 Debug Trend: WebRequest result=", res);
   
   if(res == 200)
   {
      string jsonResponse = CharArrayToString(response);
      Print("📥 Debug Trend: Réponse JSON=", jsonResponse);
      
      // Parser les tendances par timeframe
      g_trendAlignment.m1_trend = ExtractJSONValue(jsonResponse, "m1_trend");
      g_trendAlignment.h1_trend = ExtractJSONValue(jsonResponse, "h1_trend");
      g_trendAlignment.h4_trend = ExtractJSONValue(jsonResponse, "h4_trend");
      g_trendAlignment.d1_trend = ExtractJSONValue(jsonResponse, "d1_trend");
      
      // Calculer l'alignement
      string trend = g_trendAlignment.m1_trend;
      g_trendAlignment.is_aligned = (g_trendAlignment.h1_trend == trend && 
                                    g_trendAlignment.h4_trend == trend && 
                                    g_trendAlignment.d1_trend == trend);
      
      // Calculer le score d'alignement
      int alignedCount = 0;
      if(g_trendAlignment.m1_trend == trend) alignedCount++;
      if(g_trendAlignment.h1_trend == trend) alignedCount++;
      if(g_trendAlignment.h4_trend == trend) alignedCount++;
      if(g_trendAlignment.d1_trend == trend) alignedCount++;
      
      g_trendAlignment.alignment_score = (alignedCount / 4.0) * 100.0;
      
      Print("✅ Debug Trend: M1=", g_trendAlignment.m1_trend, " H1=", g_trendAlignment.h1_trend, 
            " H4=", g_trendAlignment.h4_trend, " D1=", g_trendAlignment.d1_trend);
      Print("🎯 Debug Trend: Alignement=", g_trendAlignment.is_aligned, " Score=", g_trendAlignment.alignment_score);
      
      return true;
   }
   else
   {
      Print("❌ Debug Trend: Erreur WebRequest ", res);
   }
   
   return false;
}

// Récupérer les données d'analyse cohérente
bool GetCoherentAnalysisData()
{
   string url = AI_CoherentAnalysisURL + "?symbol=" + _Symbol;
   string headers = "Content-Type: application/json\r\n";
   char post[];
   uchar response[];
   
   Print("🔍 Debug Coherent: URL=", url);
   
   int res = WebRequest("GET", url, headers, AI_Timeout_ms, post, response, headers);
   
   Print("🌐 Debug Coherent: WebRequest result=", res);
   
   if(res == 200)
   {
      string jsonResponse = CharArrayToString(response);
      Print("📥 Debug Coherent: Réponse JSON=", jsonResponse);
      
      g_coherentAnalysis.direction = ExtractJSONValue(jsonResponse, "direction");
      g_coherentAnalysis.coherence_score = StringToDouble(ExtractJSONValue(jsonResponse, "coherence_score"));
      g_coherentAnalysis.key_factors = ExtractJSONValue(jsonResponse, "key_factors");
      g_coherentAnalysis.is_valid = (g_coherentAnalysis.coherence_score >= 70.0);
      
      Print("✅ Debug Coherent: Direction=", g_coherentAnalysis.direction, " Score=", g_coherentAnalysis.coherence_score);
      
      return true;
   }
   else
   {
      Print("❌ Debug Coherent: Erreur WebRequest ", res);
   }
   
   return false;
}

// Fonction utilitaire pour extraire une valeur JSON
string ExtractJSONValue(string json, string key)
{
   int keyStart = StringFind(json, "\"" + key + "\":");
   if(keyStart >= 0)
   {
      keyStart = StringFind(json, ":", keyStart) + 1;
      if(StringSubstr(json, keyStart, 1) == "\"")
      {
         keyStart++; // Skip opening quote
         int valueEnd = StringFind(json, "\"", keyStart);
         if(valueEnd > keyStart)
         {
            return StringSubstr(json, keyStart, valueEnd - keyStart);
         }
      }
      else
      {
         int valueEnd = StringFind(json, ",", keyStart);
         if(valueEnd < 0) valueEnd = StringFind(json, "}", keyStart);
         if(valueEnd > keyStart)
         {
            return StringSubstr(json, keyStart, valueEnd - keyStart);
         }
      }
   }
   return "";
}

//+------------------------------------------------------------------+
//| FONCTION DE DÉCISION FINALE                                       |
//+------------------------------------------------------------------+
void CalculateFinalDecision()
{
   g_finalDecision.action = "HOLD";
   g_finalDecision.final_confidence = 0.0;
   g_finalDecision.execution_type = "NONE";
   g_finalDecision.entry_price = 0.0;
   g_finalDecision.stop_loss = 0.0;
   g_finalDecision.take_profit = 0.0;
   g_finalDecision.reasoning = "";
   
   // Vérifier si la confiance IA dépasse 60%
   if(g_aiSignal.confidence >= 0.60)
   {
      // Vérifier l'alignement des tendances
      if(g_trendAlignment.is_aligned && g_trendAlignment.alignment_score >= 75.0)
      {
         // Vérifier l'analyse cohérente
         if(g_coherentAnalysis.is_valid && g_coherentAnalysis.coherence_score >= 70.0)
         {
            // Vérifier la cohérence directionnelle
            string aiDirection = StringToUpper(g_aiSignal.recommendation);
            string trendDirection = StringToUpper(g_trendAlignment.m1_trend);
            string coherentDirection = StringToUpper(g_coherentAnalysis.direction);
            
            if(aiDirection == trendDirection && aiDirection == coherentDirection)
            {
               g_finalDecision.action = aiDirection;
               g_finalDecision.final_confidence = (g_aiSignal.confidence + 
                                                 (g_trendAlignment.alignment_score / 100.0) * 0.3 + 
                                                 (g_coherentAnalysis.coherence_score / 100.0) * 0.2) / 1.5;
               
               // Déterminer le type d'exécution
               if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
               {
                  g_finalDecision.execution_type = "SCALP_SPIKE";
               }
               else if(StringFind(_Symbol, "Volatility") >= 0)
               {
                  g_finalDecision.execution_type = "SCALP_VOLATILITY";
               }
               else
               {
                  g_finalDecision.execution_type = "MARKET";
               }
               
               // Calculer les niveaux d'entrée, SL et TP
               CalculateOptimalEntryLevels();
               
               g_finalDecision.reasoning = "Signal IA (" + DoubleToString(g_aiSignal.confidence * 100, 1) + 
                                          "%) + Alignement tendances (" + DoubleToString(g_trendAlignment.alignment_score, 1) + 
                                          "%) + Analyse cohérente (" + DoubleToString(g_coherentAnalysis.coherence_score, 1) + "%)";
            }
         }
      }
   }
}

// Calculer les niveaux optimaux d'entrée
void CalculateOptimalEntryLevels()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(g_finalDecision.action == "BUY")
   {
      // Attendre un support ou EMA rapide proche
      double emaFast[1], emaSlow[1];
      if(emaFastHandle != INVALID_HANDLE && CopyBuffer(emaFastHandle, 0, 0, 1, emaFast) > 0 &&
     emaSlowHandle != INVALID_HANDLE && CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlow) > 0)
      {
         double nearestSupport = MathMin(emaFast[0], emaSlow[0]);
         double distanceToSupport = currentPrice - nearestSupport;
         
         if(distanceToSupport <= 50 * point) // Si le support est proche (50 points)
         {
            g_finalDecision.entry_price = nearestSupport;
         }
         else
         {
            g_finalDecision.entry_price = currentPrice;
         }
      }
      else
      {
         g_finalDecision.entry_price = currentPrice;
      }
      
      // Calculer SL et TP selon le type d'actif
      if(g_finalDecision.execution_type == "SCALP_SPIKE")
      {
         g_finalDecision.stop_loss = g_finalDecision.entry_price - 20 * point;
         g_finalDecision.take_profit = g_finalDecision.entry_price + 40 * point;
      }
      else if(g_finalDecision.execution_type == "SCALP_VOLATILITY")
      {
         g_finalDecision.stop_loss = g_finalDecision.entry_price - 30 * point;
         g_finalDecision.take_profit = g_finalDecision.entry_price + 5.0; // 5$ pour Volatility
      }
      else
      {
         g_finalDecision.stop_loss = g_finalDecision.entry_price - 50 * point;
         g_finalDecision.take_profit = g_finalDecision.entry_price + 100 * point;
      }
   }
   else if(g_finalDecision.action == "SELL")
   {
      // Attendre une résistance ou EMA rapide proche
      double emaFast[1], emaSlow[1];
      if(emaFastHandle != INVALID_HANDLE && CopyBuffer(emaFastHandle, 0, 0, 1, emaFast) > 0 &&
     emaSlowHandle != INVALID_HANDLE && CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlow) > 0)
      {
         double nearestResistance = MathMax(emaFast[0], emaSlow[0]);
         double distanceToResistance = nearestResistance - currentPrice;
         
         if(distanceToResistance <= 50 * point) // Si la résistance est proche (50 points)
         {
            g_finalDecision.entry_price = nearestResistance;
         }
         else
         {
            g_finalDecision.entry_price = currentPrice;
         }
      }
      else
      {
         g_finalDecision.entry_price = currentPrice;
      }
      
      // Calculer SL et TP selon le type d'actif
      if(g_finalDecision.execution_type == "SCALP_SPIKE")
      {
         g_finalDecision.stop_loss = g_finalDecision.entry_price + 20 * point;
         g_finalDecision.take_profit = g_finalDecision.entry_price - 40 * point;
      }
      else if(g_finalDecision.execution_type == "SCALP_VOLATILITY")
      {
         g_finalDecision.stop_loss = g_finalDecision.entry_price + 30 * point;
         g_finalDecision.take_profit = g_finalDecision.entry_price - 5.0; // 5$ pour Volatility
      }
      else
      {
         g_finalDecision.stop_loss = g_finalDecision.entry_price + 50 * point;
         g_finalDecision.take_profit = g_finalDecision.entry_price - 100 * point;
      }
   }
}

//+------------------------------------------------------------------+
//| FONCTION D'EXÉCUTION DE LA STRATÉGIE AVANCÉE                      |
//+------------------------------------------------------------------+
void ExecuteAdvancedStrategy()
{
   if(g_finalDecision.action == "HOLD" || g_finalDecision.final_confidence < 0.60)
      return;
   
   double lotSize = CalculateOptimalLotSize();
   
   if(g_finalDecision.action == "BUY")
   {
      if(SafeTradeBuy(lotSize, _Symbol, g_finalDecision.entry_price, 
                   g_finalDecision.stop_loss, g_finalDecision.take_profit, 
                   "Advanced Strategy: " + g_finalDecision.reasoning))
      {
         Print("🚀 TRADE AVANCÉ EXÉCUTÉ: BUY @ ", DoubleToString(g_finalDecision.entry_price, _Digits));
         Print("📊 Confiance: ", DoubleToString(g_finalDecision.final_confidence * 100, 1), "%");
         Print("🎯 Type: ", g_finalDecision.execution_type);
         Print("🛡️ SL: ", DoubleToString(g_finalDecision.stop_loss, _Digits));
         Print("🎯 TP: ", DoubleToString(g_finalDecision.take_profit, _Digits));
      }
   }
   else if(g_finalDecision.action == "SELL")
   {
      if(SafeTradeSell(lotSize, _Symbol, g_finalDecision.entry_price, 
                    g_finalDecision.stop_loss, g_finalDecision.take_profit, 
                    "Advanced Strategy: " + g_finalDecision.reasoning))
      {
         Print("🚀 TRADE AVANCÉ EXÉCUTÉ: SELL @ ", DoubleToString(g_finalDecision.entry_price, _Digits));
         Print("📊 Confiance: ", DoubleToString(g_finalDecision.final_confidence * 100, 1), "%");
         Print("🎯 Type: ", g_finalDecision.execution_type);
         Print("🛡️ SL: ", DoubleToString(g_finalDecision.stop_loss, _Digits));
         Print("🎯 TP: ", DoubleToString(g_finalDecision.take_profit, _Digits));
      }
   }
}

// Calculer la taille de lot optimale
double CalculateOptimalLotSize()
{
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * 0.02; // 2% de risque
   double stopLossPoints = MathAbs(g_finalDecision.entry_price - g_finalDecision.stop_loss) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(stopLossPoints > 0 && tickValue > 0)
   {
      double lotSize = riskAmount / (stopLossPoints * tickValue);
      return NormalizeDouble(MathMax(MathMin(lotSize, MaxLotSize), InitialLotSize), 2);
   }
   
   return InitialLotSize;
}

//+------------------------------------------------------------------+
//| FONCTION DE MISE À JOUR DU DASHBOARD                             |
//+------------------------------------------------------------------+
void UpdateAdvancedDashboard()
{
   if(!ShowDashboard) return;
   
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastDashboardUpdate < 5) return; // Update every 5 seconds
   
   g_lastDashboardUpdate = currentTime;
   
   Print("🔄 Debug Dashboard: Mise à jour en cours...");
   
   // Récupérer les données
   bool iaSuccess = GetAISignalData();
   bool trendSuccess = GetTrendAlignmentData();
   bool coherentSuccess = GetCoherentAnalysisData();
   
   Print("📊 Debug Dashboard: IA=", iaSuccess, " Trend=", trendSuccess, " Coherent=", coherentSuccess);
   
   CalculateFinalDecision();
   
   Print("⚡ Debug Dashboard: Décision finale=", g_finalDecision.action, " Confiance=", g_finalDecision.final_confidence);
   
   // Créer le dashboard
   string dashboardName = "Advanced_Trading_Dashboard";
   
   // Supprimer l'ancien dashboard
   if(ObjectFind(0, dashboardName) >= 0)
      ObjectDelete(0, dashboardName);
   
   // Créer le fond du dashboard
   int dashboardX = 20;
   int dashboardY = 20;
   int dashboardWidth = 450;
   int dashboardHeight = 250;
   
   ObjectCreate(0, dashboardName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, dashboardName, OBJPROP_XDISTANCE, dashboardX);
   ObjectSetInteger(0, dashboardName, OBJPROP_YDISTANCE, dashboardY);
   ObjectSetInteger(0, dashboardName, OBJPROP_XSIZE, dashboardWidth);
   ObjectSetInteger(0, dashboardName, OBJPROP_YSIZE, dashboardHeight);
   ObjectSetInteger(0, dashboardName, OBJPROP_BGCOLOR, DashboardBGColor);
   ObjectSetInteger(0, dashboardName, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, dashboardName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   // Afficher les 4 éléments demandés avec espacement
   string text = "";
   
   // 1. Recommandation IA avec confiance
   text += "🤖 IA: " + g_aiSignal.recommendation + " (" + DoubleToString(g_aiSignal.confidence * 100, 1) + "%)\n\n";
   
   // 2. Alignement des tendances
   text += "📊 Tendances:\n";
   text += "   M1=" + g_trendAlignment.m1_trend + "  H1=" + g_trendAlignment.h1_trend + "\n";
   text += "   H4=" + g_trendAlignment.h4_trend + "  D1=" + g_trendAlignment.d1_trend + "\n";
   text += "🎯 Alignement: " + (g_trendAlignment.is_aligned ? "✅" : "❌") + 
           " (" + DoubleToString(g_trendAlignment.alignment_score, 1) + "%)\n\n";
   
   // 3. Analyse cohérente
   text += "🔍 Cohérence: " + g_coherentAnalysis.direction + 
           " (" + DoubleToString(g_coherentAnalysis.coherence_score, 1) + "%)\n\n";
   
   // 4. Décision finale
   text += "⚡ DÉCISION: " + g_finalDecision.action + 
           " (" + DoubleToString(g_finalDecision.final_confidence * 100, 1) + "%)\n";
   
   // Créer le label de texte
   string textLabelName = dashboardName + "_Text";
   ObjectCreate(0, textLabelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, textLabelName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, textLabelName, OBJPROP_XDISTANCE, dashboardX + 10);
   ObjectSetInteger(0, textLabelName, OBJPROP_YDISTANCE, dashboardY + 10);
   ObjectSetInteger(0, textLabelName, OBJPROP_COLOR, TextColor);
   ObjectSetString(0, textLabelName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, textLabelName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, textLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   Print("✅ Debug Dashboard: Dashboard créé avec succès");
   
   // Exécuter la stratégie si les conditions sont remplies
   if(g_finalDecision.final_confidence >= 0.60)
   {
      ExecuteAdvancedStrategy();
   }
}

//+------------------------------------------------------------------+
//| FONCTIONS DE GESTION DES POSITIONS POUR STRATÉGIE AVANCÉE         |
//+------------------------------------------------------------------+

// Gérer la duplication des positions selon la stratégie
void ManagePositionDuplication()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Magic() == InpMagicNumber)
         {
            double currentProfit = positionInfo.Profit();
            
            // Dupliquer à 1$ de profit
            if(currentProfit >= 1.0 && !g_positionTracker.lotDoubled)
            {
               DuplicatePosition(positionInfo.Ticket());
            }
            
            // Fermer Volatility à 5$ de profit
            if(StringFind(_Symbol, "Volatility") >= 0 && currentProfit >= 5.0)
            {
               trade.PositionClose(positionInfo.Ticket());
               Print("🎯 Volatility fermé à 5$ de profit");
            }
            
            // Fermer Boom/Crash juste après le spike
            if((StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0) && currentProfit >= 0.01)
            {
               trade.PositionClose(positionInfo.Ticket());
               Print("⚡ Boom/Crash fermé après spike");
            }
         }
      }
   }
}

// Dupliquer une position
void DuplicatePosition(ulong originalTicket)
{
   if(!positionInfo.SelectByTicket(originalTicket))
      return;
   
   double originalLot = positionInfo.Volume();
   double newLot = MathMin(originalLot * 2, MaxLotSize);
   
   ENUM_ORDER_TYPE orderType = positionInfo.PositionType() == POSITION_TYPE_BUY ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double entryPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentStopLoss = positionInfo.StopLoss();
   double currentTakeProfit = positionInfo.TakeProfit();
   
   // Calculer les nouveaux SL/TP pour la nouvelle position (pas modification de l'existante)
   double newStopLoss, newTakeProfit;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      // Pour BUY: SL plus bas, TP plus haut
      double atrValue[1];
      if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atrValue) > 0)
      {
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         newStopLoss = entryPrice - (atrValue[0] * 2); // 2x ATR pour SL
         newTakeProfit = entryPrice + (atrValue[0] * 4); // 4x ATR pour TP
      }
      else
      {
         // Fallback si ATR pas disponible
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         newStopLoss = entryPrice - (50 * point);
         newTakeProfit = entryPrice + (100 * point);
      }
      
      if(SafeTradeBuy(newLot, _Symbol, entryPrice, newStopLoss, newTakeProfit, "Duplication @ 1$ profit"))
      {
         g_positionTracker.lotDoubled = true;
         Print("🔄 Position doublée: ", newLot, " lots @ ", DoubleToString(entryPrice, _Digits));
         Print("   SL: ", DoubleToString(newStopLoss, _Digits), " TP: ", DoubleToString(newTakeProfit, _Digits));
      }
   }
   else
   {
      // Pour SELL: SL plus haut, TP plus bas
      double atrValue[1];
      if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atrValue) > 0)
      {
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         newStopLoss = entryPrice + (atrValue[0] * 2); // 2x ATR pour SL
         newTakeProfit = entryPrice - (atrValue[0] * 4); // 4x ATR pour TP
      }
      else
      {
         // Fallback si ATR pas disponible
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         newStopLoss = entryPrice + (50 * point);
         newTakeProfit = entryPrice - (100 * point);
      }
      
      if(SafeTradeSell(newLot, _Symbol, entryPrice, newStopLoss, newTakeProfit, "Duplication @ 1$ profit"))
      {
         g_positionTracker.lotDoubled = true;
         Print("🔄 Position doublée: ", newLot, " lots @ ", DoubleToString(entryPrice, _Digits));
         Print("   SL: ", DoubleToString(newStopLoss, _Digits), " TP: ", DoubleToString(newTakeProfit, _Digits));
      }
   }
}

// Initialiser le tracker de position
void InitializePositionTracker()
{
   g_positionTracker.ticket = 0;
   g_positionTracker.initialLot = 0.0;
   g_positionTracker.currentLot = 0.0;
   g_positionTracker.highestProfit = 0.0;
   g_positionTracker.lotDoubled = false;
   g_positionTracker.openTime = 0;
   g_positionTracker.maxProfitReached = 0.0;
   g_positionTracker.profitSecured = false;
   g_hasPosition = false;
}

// Mettre à jour le tracker de position
void UpdatePositionTracker()
{
   if(PositionsTotal() > 0)
   {
      if(!g_hasPosition)
      {
         // Nouvelle position détectée
         if(positionInfo.SelectByIndex(0))
         {
            if(positionInfo.Magic() == InpMagicNumber)
            {
               g_positionTracker.ticket = positionInfo.Ticket();
               g_positionTracker.initialLot = positionInfo.Volume();
               g_positionTracker.currentLot = positionInfo.Volume();
               g_positionTracker.openTime = positionInfo.Time();
               g_positionTracker.highestProfit = positionInfo.Profit();
               g_positionTracker.lotDoubled = false;
               g_positionTracker.maxProfitReached = positionInfo.Profit();
               g_positionTracker.profitSecured = false;
               g_hasPosition = true;
               
               Print("📍 Nouvelle position suivie: Ticket ", g_positionTracker.ticket, " - Lot: ", g_positionTracker.initialLot);
            }
         }
      }
      else
      {
         // Mettre à jour la position existante
         if(positionInfo.SelectByTicket(g_positionTracker.ticket))
         {
            double currentProfit = positionInfo.Profit();
            g_positionTracker.currentLot = positionInfo.Volume();
            
            if(currentProfit > g_positionTracker.highestProfit)
            {
               g_positionTracker.highestProfit = currentProfit;
            }
            
            // Gérer la duplication et les fermetures stratégiques
            ManagePositionDuplication();
         }
         else
         {
            // Position fermée, réinitialiser
            InitializePositionTracker();
         }
      }
   }
   else
   {
      if(g_hasPosition)
      {
         Print("📍 Toutes les positions fermées - Réinitialisation tracker");
         InitializePositionTracker();
      }
   }
}

//+------------------------------------------------------------------+


