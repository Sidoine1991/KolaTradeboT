//+------------------------------------------------------------------+
//|                                          F_INX_scalper_double.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"
#property strict

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
//| Paramètres d'entrée                                              |
//+------------------------------------------------------------------+
input group "--- CONFIGURATION DE BASE ---"
input int    InpMagicNumber     = 888888;  // Magic Number
input double InitialLotSize     = 0.01;    // Taille de lot initiale
input double MaxLotSize          = 1.0;     // Taille de lot maximale
input double TakeProfitUSD       = 30.0;    // Take Profit en USD (fixe) - Mouvements longs (augmenté pour cibler les grands mouvements)
input double StopLossUSD         = 10.0;    // Stop Loss en USD (fixe) - Ratio 3:1 pour favoriser les mouvements longs
input double ProfitThresholdForDouble = 1.0; // Seuil de profit (USD) pour doubler le lot (1$ comme demandé)
input int    MinPositionLifetimeSec = 5;    // Délai minimum avant modification (secondes)

input group "--- AI AGENT ---"
input bool   UseAI_Agent        = true;    // Activer l'agent IA (via serveur externe)
input string AI_ServerURL       = "http://127.0.0.1:8000/decision"; // URL serveur IA
input bool   UseAdvancedDecisionGemma = false; // Utiliser endpoint decisionGemma (Gemma+Gemini) avec analyse visuelle
input int    AI_Timeout_ms       = 800;     // Timeout WebRequest en millisecondes
input double AI_MinConfidence    = 0.60;    // Confiance minimale IA pour trader (60% - ajusté avec calcul intelligent)
// NOTE: Le serveur IA garantit maintenant 60% minimum si H1 aligné, 70% si H1+H4/D1
// Pour Boom/Crash, le seuil est automatiquement abaissé à 45% dans le code
// pour les tendances fortes (H4/D1 alignés). Le serveur ajoute automatiquement
// des bonus (+25% pour H4+D1 alignés, +10-20% pour alignement multi-TF)
input int    AI_UpdateInterval   = 5;      // Intervalle de mise à jour IA (secondes)
input string AI_AnalysisURL    = "http://127.0.0.1:8000/analysis";  // URL base pour l'analyse complète (structure H1, etc.)
input int    AI_AnalysisIntervalSec = 60;  // Fréquence de rafraîchissement de l'analyse (secondes)
input string AI_TimeWindowsURLBase = "http://127.0.0.1:8000"; // Racine API pour /time_windows
input string TrendAPIURL = "http://127.0.0.1:8000/trend"; // URL API de tendance
input int    MinStabilitySeconds = 3;   // Délai minimum de stabilité avant exécution (secondes) - RÉDUIT pour exécution immédiate

input group "--- ÉLÉMENTS GRAPHIQUES ---"
input bool   DrawAIZones         = true;    // Dessiner les zones BUY/SELL de l'IA
input bool   DrawSupportResistance = true;  // Dessiner support/résistance M5/H1
input bool   DrawTrendlines      = true;    // Dessiner les trendlines
input bool   DrawDerivPatterns   = true;    // Dessiner les patterns Deriv
input bool   DrawSMCZones        = false;   // Dessiner les zones SMC/OrderBlock (DÉSACTIVÉ pour performance)

input group "--- STRATÉGIE US SESSION BREAK & RETEST (PRIORITAIRE) ---"
input bool   UseUSSessionStrategy = true;   // Activer la stratégie US Session (prioritaire)
input double US_RiskReward        = 2.0;    // Risk/Reward ratio pour US Session
input int    US_RetestTolerance   = 30;     // Tolérance retest en points
input bool   US_OneTradePerDay    = true;   // Un seul trade par jour pour US Session

input group "--- GESTION DES RISQUES ---"
input double MaxDailyLoss        = 100.0;   // Perte quotidienne maximale (USD)
input double MaxDailyProfit      = 50.0;    // Profit quotidien net cible (USD) - MODE PRUDENT à 50$
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
input int    Fractal_Period      = 5;       // Période Fractal (pour zones de mouvement)
input bool   ShowLongTrendEMA    = true;    // Afficher EMA 50, 100, 200 sur le graphique (courbes)
input bool   UseTrendAPIAnalysis = true;    // Utiliser l'analyse de tendance API pour affiner les décisions
input double TrendAPIMinConfidence = 70.0;  // Confiance minimum API pour validation (70%)
input bool   TradeOnlyInTrend    = true;    // Trader uniquement en tendance (éviter corrections et ranges)

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
int fractalHandle;  // Handle pour l'indicateur Fractal

// Variables IA
static string   g_lastAIAction    = "";
static double   g_lastAIConfidence = 0.0;
static string   g_lastAIReason    = "";
static string   g_lastAIStyle     = "";   // "scalp" ou "swing" si présent dans la raison IA
static datetime g_lastAITime      = 0;
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

// Prédiction de prix (200 bougies)
static double   g_pricePrediction[];  // Tableau des prix prédits (500 bougies futures)
static double   g_priceHistory[];     // Tableau des prix historiques (200 bougies passées)
static datetime g_predictionStartTime = 0;  // Temps de début de la prédiction
static bool     g_predictionValid = false;  // La prédiction est-elle valide ?
static int      g_predictionBars = 500;     // Nombre de bougies futures à prédire
static int      g_historyBars = 200;        // Nombre de bougies historiques
static datetime g_lastPredictionUpdate = 0; // Dernière mise à jour de la prédiction
const int PREDICTION_UPDATE_INTERVAL = 300; // Mise à jour toutes les 5 minutes (300 secondes)

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
const double MIN_PROFIT_TO_CLOSE = 1.0;      // Profit minimum requis pour fermer un trade (1$)

// Tableau pour suivre le profit max de chaque position
struct PositionProfitTracker {
   ulong ticket;
   double maxProfit;
   datetime lastUpdate;
};

// Structure pour la décision finale consolidée
struct FinalDecisionResult {
   int direction;        // 1 = BUY, -1 = SELL, 0 = NEUTRE
   double confidence;    // Confiance globale (0.0 - 1.0)
   string details;       // Détails de la décision
   bool isValid;         // Si la décision est valide pour trader
};

// Structure pour suivre la stabilité de la décision finale
struct DecisionStability {
   int direction;        // Direction de la décision (1=BUY, -1=SELL, 0=NEUTRE)
   datetime firstSeen;  // Premier moment où cette décision a été vue
   datetime lastSeen;   // Dernier moment où cette décision a été vue
   bool isValid;        // Si la décision est valide
   int stabilitySeconds; // Nombre de secondes que la décision est stable
};

struct TradingSignal {
   string symbol;              // Symbole
   ENUM_ORDER_TYPE orderType;  // Type d'ordre (BUY/SELL)
   double confidence;          // Confiance de la décision finale (0.0 - 1.0)
   datetime timestamp;         // Timestamp du signal
   bool isDuplicate;           // Si c'est un trade dupliqué (ne compte pas dans la limite)
};

static PositionProfitTracker g_profitTrackers[];
static int g_profitTrackersCount = 0;

// Suivi quotidien
static double g_dailyProfit = 0.0;
static double g_dailyLoss = 0.0;
static datetime g_lastDayReset = 0;
static ulong g_processedDeals[];  // Liste des deals déjà traités pour éviter les doubles comptages

// Suivi pour fermeture après spike (Boom/Crash)
static double g_lastBoomCrashPrice = 0.0;  // Prix de référence pour détecter le spike

// Suivi des tentatives de spike et cooldown (Boom/Crash)
static string   g_spikeSymbols[];
static int      g_spikeFailCount[];

// Structure pour stocker les opportunités BUY/SELL
struct TradingOpportunity {
   bool isBuy;           // true = BUY, false = SELL
   double entryPrice;    // Prix d'entrée
   double percentage;    // Pourcentage de gain potentiel
   datetime entryTime;   // Temps d'entrée
   int priority;         // Priorité (plus le gain est élevé, plus la priorité est haute)
};

static TradingOpportunity g_opportunities[];  // Tableau des opportunités
static int g_opportunitiesCount = 0;          // Nombre d'opportunités
static datetime g_spikeCooldown[];

static TradingSignal g_pendingSignals[];  // Tableau des signaux en attente
static int g_pendingSignalsCount = 0;     // Nombre de signaux en attente

// Variables pour suivre la stabilité de la décision finale
static DecisionStability g_currentDecisionStability;
// MIN_STABILITY_SECONDS est maintenant un input (MinStabilitySeconds) - valeur par défaut: 30 secondes

// Déclarations forward des fonctions
bool IsVolatilitySymbol(const string symbol);
bool IsBoomCrashSymbol(const string sym);
double GetTotalLoss();
double NormalizeLotSize(double lot);
void CleanOldGraphicalObjects();
void DrawAIConfidenceAndTrendSummary();
void DrawOpportunitiesPanel();
void DrawLongTrendEMA();
void DeleteEMAObjects(string prefix);
void DrawEMACurveOptimized(string prefix, double &values[], datetime &times[], int count, color clr, int width, int step);
void DrawAIZonesOnChart();
void DrawSupportResistanceLevels();
void DrawTrendlinesOnChart();
void DrawSMCZonesOnChart();
void DeleteSMCZones();
void CheckAndManagePositions();
void SecureDynamicProfits();
void SecureProfitForPosition(ulong ticket, double currentProfit);
void LookForTradingOpportunity();
bool CheckReboundOnTrendline(ENUM_ORDER_TYPE orderType, double &distance);
bool DetectReversalAtFastEMA(ENUM_ORDER_TYPE orderType);
bool CheckAIZoneEntryWithEMA(ENUM_ORDER_TYPE orderType, bool &isInZone, bool &emaConfirmed, bool &isCorrection);
bool CheckTrendAlignment(ENUM_ORDER_TYPE orderType);
bool CheckM1M5Alignment(ENUM_ORDER_TYPE orderType);
bool CheckSuperTrendSignal(ENUM_ORDER_TYPE orderType, double &strength);
bool CheckSupportResistanceRebound(ENUM_ORDER_TYPE orderType, double &reboundStrength);
bool CheckPatternReversal(ENUM_ORDER_TYPE orderType, double &reversalConfidence);
bool IsRealTrendReversal(ulong ticket, ENUM_POSITION_TYPE posType, double currentPrice, double entryPrice);
bool IsTrendStillValid(ENUM_POSITION_TYPE posType);
bool CheckAdvancedEntryConditions(ENUM_ORDER_TYPE orderType, double &entryScore);
void UpdatePricePrediction();
void DrawPricePrediction();
void DetectReversalPoints(int &buyEntries[], int &sellEntries[]);
void UsePredictionForCurrentTrades();
void DetectAndDrawCorrectionZones();
void PlaceLimitOrderOnCorrection();

// Nouvelles fonctions pour amélioration du robot
enum MARKET_STATE
{
   MARKET_TREND_UP,      // Tendance haussière claire
   MARKET_TREND_DOWN,    // Tendance baissière claire
   MARKET_CORRECTION,    // Correction (éviter de trader)
   MARKET_RANGE          // Range (éviter de trader)
};

MARKET_STATE DetectMarketState();
bool IsInClearTrend(ENUM_ORDER_TYPE orderType);
double GetFractalUpperZone();
double GetFractalLowerZone();
bool IsPriceNearFractalZone(double price, double &zonePrice);
void EnhanceSpikePredictionWithHistory();
void DrawEnhancedPredictionTrajectory();

// Stratégie spécifique Boom/Crash pour capturer les spikes
bool DetectBoomCrashSpikeOpportunity(ENUM_ORDER_TYPE &orderType, double &confidence);
bool CheckSpikeEntryWithEMAsAndFractals(ENUM_ORDER_TYPE orderType, double &entryConfidence);
void SendMT5Notification(string message, bool isAlert = true);

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
   // Détecter TOUS les symboles avec "Boom" ou "Crash" (y compris "Vol over Boom/Crash")
   // Tous ces symboles doivent respecter les restrictions:
   // - Boom (y compris Vol over Boom) = BUY uniquement (spike en tendance)
   // - Crash (y compris Vol over Crash) = SELL uniquement (spike en tendance)
   
   // Détecter tous les symboles avec "Boom" ou "Crash" (incluant Vol over)
   bool hasBoom = (StringFind(sym, "Boom") != -1);
   bool hasCrash = (StringFind(sym, "Crash") != -1);
   
   return (hasBoom || hasCrash);
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
//| Obtenir la décision finale basée sur l'analyse actuelle          |
//+------------------------------------------------------------------+
bool GetFinalDecision(FinalDecisionResult &result)
{
   // Initialiser la structure de résultat
   result.direction = 0;
   result.confidence = 0.0;
   result.isValid = false;
   result.details = "Aucune décision valide";
   
   // Vérifier si nous avons une prédiction valide
   if(!g_predictionValid || ArraySize(g_pricePrediction) < 10)
   {
      result.details = "Aucune prédiction valide disponible";
      return false;
   }
   
   // Analyser la tendance des prédictions
   double firstPrice = g_pricePrediction[0];
   double lastPrice = g_pricePrediction[ArraySize(g_pricePrediction)-1];
   double priceChange = lastPrice - firstPrice;
   
   // Calculer la volatilité des prédictions
   double sum = 0.0;
   for(int i = 0; i < ArraySize(g_pricePrediction); i++)
      sum += g_pricePrediction[i];
   double mean = sum / ArraySize(g_pricePrediction);
   
   double variance = 0.0;
   for(int i = 0; i < ArraySize(g_pricePrediction); i++)
      variance += MathPow(g_pricePrediction[i] - mean, 2);
   variance /= ArraySize(g_pricePrediction);
   
   double stdDev = MathSqrt(variance);
   double volatility = stdDev / mean * 100.0; // en pourcentage
   
   // Déterminer la direction et la confiance
   if(MathAbs(priceChange) > 0 && volatility > 0.1) // Seuil de volatilité minimum
   {
      result.direction = (priceChange > 0) ? 1 : -1;
      // La confiance est basée sur la magnitude du mouvement relatif à la volatilité
      result.confidence = MathMin(MathAbs(priceChange) / (stdDev * 2.0), 1.0);
      result.isValid = (result.confidence > 0.6); // Seuil de confiance minimum
      
      if(result.isValid)
      {
         string dirStr = (result.direction > 0) ? "haussière" : "baissière";
         result.details = StringFormat("Tendance %s détectée (Confiance: %.1f%%, Volatilité: %.2f%%)", 
                                     dirStr, result.confidence * 100, volatility);
      }
      else
      {
         result.details = StringFormat("Signal trop faible (Confiance: %.1f%% < 60%%, Volatilité: %.2f%%)", 
                                     result.confidence * 100, volatility);
      }
   }
   else
   {
      result.details = StringFormat("Marché plat ou trop volatile (Mouvement: %.2f, Volatilité: %.2f%%)", 
                                  priceChange, volatility);
   }
   
   return result.isValid;
}

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
   
   // Initialiser les EMA pour tendances longues (50, 100, 200) sur M1
   ema50Handle = iMA(_Symbol, PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema100Handle = iMA(_Symbol, PERIOD_M1, 100, 0, MODE_EMA, PRICE_CLOSE);
   ema200Handle = iMA(_Symbol, PERIOD_M1, 200, 0, MODE_EMA, PRICE_CLOSE);
   
   // Initialiser l'indicateur Fractal pour détecter les zones de mouvement
   fractalHandle = iFractals(_Symbol, PERIOD_M1);
   
   if(emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE || 
      emaFastH1Handle == INVALID_HANDLE || emaSlowH1Handle == INVALID_HANDLE ||
      emaFastM5Handle == INVALID_HANDLE || emaSlowM5Handle == INVALID_HANDLE ||
      ema50Handle == INVALID_HANDLE || ema100Handle == INVALID_HANDLE || ema200Handle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE ||
      atrM5Handle == INVALID_HANDLE || atrH1Handle == INVALID_HANDLE ||
      fractalHandle == INVALID_HANDLE)
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
   
   // Initialiser le suivi de stabilité de la décision finale
   g_currentDecisionStability.direction = 0;
   g_currentDecisionStability.firstSeen = 0;
   g_currentDecisionStability.lastSeen = 0;
   g_currentDecisionStability.isValid = false;
   g_currentDecisionStability.stabilitySeconds = 0;
   
   // Nettoyer tous les objets graphiques au démarrage
   CleanAllGraphicalObjects();
   
   Print("✅ Système de stabilité de décision finale activé (minimum ", MinStabilitySeconds, " secondes)");
   
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
   if(fractalHandle != INVALID_HANDLE) IndicatorRelease(fractalHandle);
   
   Print("Robot Scalper Double arrêté");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Réinitialiser les compteurs quotidiens si nécessaire
   ResetDailyCountersIfNeeded();
   
   // SUPPRIMÉ: Mode prudence basé sur MaxDailyProfit/MaxDailyLoss
   // Le robot doit trader normalement sans restrictions de profit/perte quotidienne
   // Seule protection: perte totale maximale (MaxTotalLoss)
   
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
   
   // Mettre à jour la prédiction de prix toutes les 5 minutes (pas chaque seconde)
   // Cela permet au robot de prendre en compte la prédiction pour améliorer les trades présents
   if(UseAI_Agent && (TimeCurrent() - g_lastPredictionUpdate) >= PREDICTION_UPDATE_INTERVAL)
   {
      UpdatePricePrediction(); // Mettre à jour la prédiction de prix
      g_lastPredictionUpdate = TimeCurrent();
   }
   
   // Dessiner la prédiction de prix (optimisé - seulement toutes les 10 secondes pour éviter la surcharge)
   static datetime lastPredictionDraw = 0;
   if(DrawAIZones && g_predictionValid && (TimeCurrent() - lastPredictionDraw) >= 10)
   {
      DrawPricePrediction();
      lastPredictionDraw = TimeCurrent();
   }
   
   // Utiliser la prédiction pour améliorer les trades présents (ajuster SL/TP)
   // S'exécute seulement si la prédiction est valide et a été mise à jour récemment
   if(g_predictionValid && (TimeCurrent() - g_lastPredictionUpdate) < 600) // Utiliser si prédiction < 10 min
   {
      UsePredictionForCurrentTrades();
   }
   
   // Mettre à jour l'analyse de tendance API si nécessaire
   static datetime lastTrendUpdate = 0;
   if(UseTrendAPIAnalysis && (TimeCurrent() - lastTrendUpdate) >= AI_UpdateInterval)
   {
      UpdateTrendAPIAnalysis();
      lastTrendUpdate = TimeCurrent();
   }
   
   // OPTIMISATION MAXIMALE: Réduire drastiquement la fréquence et les calculs
   static datetime lastDrawUpdate = 0;
   if(TimeCurrent() - lastDrawUpdate >= 30) // Mise à jour toutes les 30 secondes (au lieu de 15)
   {
      // Toujours afficher les labels essentiels (léger)
      DrawAIConfidenceAndTrendSummary();
      
      // Afficher le panneau des opportunités (remplace les labels encombrants)
      DrawOpportunitiesPanel();
      
      // Afficher les zones AI (priorité, léger)
      if(DrawAIZones)
         DrawAIZonesOnChart();
      
      lastDrawUpdate = TimeCurrent();
   }
   
   // OPTIMISATION: Mises à jour très peu fréquentes pour éléments lourds
   static datetime lastHeavyUpdate = 0;
   if(TimeCurrent() - lastHeavyUpdate >= 300) // Mise à jour toutes les 5 minutes (au lieu de 3 min)
   {
      // OPTIMISATION: Nettoyer seulement toutes les 10 minutes (très lourd)
      static datetime lastCleanup = 0;
      if(TimeCurrent() - lastCleanup >= 600)
      {
         CleanOldGraphicalObjects();
         lastCleanup = TimeCurrent();
      }
      
      // Afficher EMA longues (optimisé, très peu fréquent)
      if(ShowLongTrendEMA)
         DrawLongTrendEMA();
      
      // NOUVEAU: Améliorer la prédiction avec données historiques
      EnhanceSpikePredictionWithHistory();
      
      // NOUVEAU: Dessiner la trajectoire de prédiction améliorée
      DrawEnhancedPredictionTrajectory();
      
      // Afficher support/résistance (très peu fréquent)
      if(DrawSupportResistance)
         DrawSupportResistanceLevels();
      
      // Afficher trendlines (très peu fréquent)
      if(DrawTrendlines)
         DrawTrendlinesOnChart();
      
      lastHeavyUpdate = TimeCurrent();
   }
   
   // Deriv patterns (optimisé - beaucoup moins fréquent)
   static datetime lastDerivUpdate = 0;
   if(DrawDerivPatterns && (TimeCurrent() - lastDerivUpdate >= 60)) // Toutes les 60 secondes (au lieu de 10)
   {
      DrawDerivPatternsOnChart();
      UpdateDerivArrowBlink();
      lastDerivUpdate = TimeCurrent();
   }
   
   // OPTIMISATION: Vérifier les positions moins fréquemment
   static datetime lastPositionCheck = 0;
   if(TimeCurrent() - lastPositionCheck >= 1) // Toutes les secondes (au lieu de chaque tick)
   {
      CheckAndManagePositions();
      SecureDynamicProfits();
      lastPositionCheck = TimeCurrent();
   }
   
   // Si pas de position, chercher une opportunité
   if(!g_hasPosition)
   {
      LookForTradingOpportunity();
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

bool IsDealProcessed(ulong dealTicket)
{
   int size = ArraySize(g_processedDeals);
   for(int i = 0; i < size; i++)
   {
      if(g_processedDeals[i] == dealTicket)
         return true;
   }
   return false;
}

void AddProcessedDeal(ulong dealTicket)
{
   int size = ArraySize(g_processedDeals);
   ArrayResize(g_processedDeals, size + 1);
   g_processedDeals[size] = dealTicket;
}

void ResetDailyCounters()
{
   g_dailyProfit = 0.0;
   g_dailyLoss = 0.0;
   ArrayFree(g_processedDeals);  // Réinitialiser la liste des deals traités
   
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
         // g_dailyProfit doit être le profit NET (gains - pertes)
         g_dailyProfit += profit;
         // g_dailyLoss est utilisé pour le mode prudent (somme des pertes absolues)
         if(profit < 0)
            g_dailyLoss += MathAbs(profit);
         
         // Marquer ce deal comme traité
         AddProcessedDeal(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Mettre à jour le profit quotidien après fermeture de position   |
//+------------------------------------------------------------------+
void UpdateDailyProfitFromDeal(ulong dealTicket)
{
   if(dealTicket == 0) return;
   
   // Éviter les doubles comptages
   if(IsDealProcessed(dealTicket))
      return;
   
   // Vérifier si c'est un trade de clôture
   if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
      return;
   
   // Vérifier si c'est notre EA
   if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber)
      return;
   
   // Vérifier si c'est un deal d'aujourd'hui
   datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   MqlDateTime dealDt, todayDt;
   TimeToStruct(dealTime, dealDt);
   TimeToStruct(TimeCurrent(), todayDt);
   
   if(dealDt.day != todayDt.day || dealDt.mon != todayDt.mon || dealDt.year != todayDt.year)
      return; // Ce n'est pas un deal d'aujourd'hui
   
   // Récupérer le profit
   double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
   // g_dailyProfit doit être le profit NET (gains - pertes)
   g_dailyProfit += profit;
   // g_dailyLoss est utilisé pour le mode prudent (somme des pertes absolues)
   if(profit < 0)
      g_dailyLoss += MathAbs(profit);
   
   // Marquer ce deal comme traité
   AddProcessedDeal(dealTicket);
}

//+------------------------------------------------------------------+
//| Fonction appelée lors d'une transaction                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
   // Si c'est une transaction de deal
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      if(dealTicket > 0)
      {
         UpdateDailyProfitFromDeal(dealTicket);
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
   
   // Envoyer la requête
   char result[];
   string headers = "Content-Type: application/json\r\n";
   string result_headers = "";
   
   int res = WebRequest("POST", AI_ServerURL, headers, AI_Timeout_ms, data, result, result_headers);
   
   if(res < 200 || res >= 300)
   {
      int errorCode = GetLastError();
      g_aiConsecutiveFailures++;
      
      if(DebugMode)
         Print("❌ AI WebRequest échec: http=", res, " - Erreur MT5: ", errorCode);
      
      if(g_aiConsecutiveFailures >= AI_FAILURE_THRESHOLD && !g_aiFallbackMode)
      {
         g_aiFallbackMode = true;
         Print("⚠️ MODE DÉGRADÉ ACTIVÉ: Serveur IA indisponible");
      }
      
      if(errorCode == 4060)
      {
         Print("⚠️ ERREUR 4060: URL non autorisée dans MT5!");
         Print("   Allez dans: Outils -> Options -> Expert Advisors");
         Print("   Ajoutez: http://127.0.0.1");
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

   // Détecter le style de trading (scalp / swing) dans la raison IA si présent
   g_lastAIStyle = "";
   if(StringLen(g_lastAIReason) > 0)
   {
      // On recherche un motif du type "Style=scalp" ou "Style=swing"
      int stylePos = StringFind(g_lastAIReason, "Style=");
      if(stylePos >= 0)
      {
         int styleStart = stylePos + 6;
         int styleEnd = StringFind(g_lastAIReason, " ", styleStart);
         if(styleEnd < 0)
            styleEnd = StringLen(g_lastAIReason);
         
         string styleValue = StringSubstr(g_lastAIReason, styleStart, styleEnd - styleStart);
         StringTrimLeft(styleValue);
         StringTrimRight(styleValue);
         StringToLower(styleValue);
         
         if(styleValue == "scalp" || styleValue == "swing")
            g_lastAIStyle = styleValue;
      }
   }
   
      // Extraire les zones BUY/SELL depuis la réponse JSON
      ExtractAIZonesFromResponse(resp);
      
      g_lastAITime = TimeCurrent();
      
      if(DebugMode)
      Print("🤖 IA: ", g_lastAIAction, " (confiance: ", DoubleToString(g_lastAIConfidence, 2), ") [style=", g_lastAIStyle, "] - ", g_lastAIReason);
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
//| Mettre à jour la prédiction de prix depuis le serveur IA         |
//+------------------------------------------------------------------+
void UpdatePricePrediction()
{
   if(!UseAI_Agent || StringLen(AI_ServerURL) == 0)
      return;
   
   // Construire l'URL pour la prédiction (ajouter /prediction à l'URL de base)
   string predictionURL = AI_ServerURL;
   int lastSlash = StringFind(predictionURL, "/", StringFind(predictionURL, "://") + 3);
   if(lastSlash > 0)
   {
      string baseURL = StringSubstr(predictionURL, 0, lastSlash);
      predictionURL = baseURL + "/prediction";
   }
   else
   {
      predictionURL = predictionURL + "/prediction";
   }
   
   // Récupérer les données de marché
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double midPrice = (bid + ask) / 2.0;
   
   // Récupérer les 200 dernières bougies historiques depuis MT5
   double closeHistory[];
   ArraySetAsSeries(closeHistory, true);
   int historyCopied = CopyClose(_Symbol, PERIOD_M1, 1, g_historyBars, closeHistory); // Commencer à 1 (bougie fermée la plus récente)
   
   if(historyCopied < g_historyBars)
   {
      if(DebugMode)
         Print("⚠️ Impossible de récupérer ", g_historyBars, " bougies historiques (reçu: ", historyCopied, ")");
      // Utiliser ce qu'on a
      ArrayResize(g_priceHistory, historyCopied);
      for(int i = 0; i < historyCopied; i++)
         g_priceHistory[i] = closeHistory[i];
   }
   else
   {
      // Stocker les données historiques
      ArrayResize(g_priceHistory, g_historyBars);
      ArrayCopy(g_priceHistory, closeHistory, 0, 0, g_historyBars);
   }
   
   // Construire le JSON pour la prédiction avec les données historiques
   string safeSymbol = _Symbol;
   StringReplace(safeSymbol, "\"", "\\\"");
   
   string payload = "{";
   payload += "\"symbol\":\"" + safeSymbol + "\"";
   payload += ",\"current_price\":" + DoubleToString(midPrice, _Digits);
   payload += ",\"bars_to_predict\":" + IntegerToString(g_predictionBars);
   payload += ",\"history_bars\":" + IntegerToString(g_historyBars);
   payload += ",\"timeframe\":\"M1\"";
   
   // Ajouter les données historiques dans le payload (optionnel, le serveur peut les récupérer lui-même)
   if(ArraySize(g_priceHistory) > 0)
   {
      payload += ",\"history\":[";
      for(int i = 0; i < ArraySize(g_priceHistory); i++)
      {
         if(i > 0) payload += ",";
         payload += DoubleToString(g_priceHistory[i], _Digits);
      }
      payload += "]";
   }
   
   payload += "}";
   
   // Conversion en UTF-8
   int payloadLen = StringLen(payload);
   char data[];
   ArrayResize(data, payloadLen + 1);
   int copied = StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);
   
   if(copied <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur conversion JSON pour prédiction");
      return;
   }
   
   ArrayResize(data, copied - 1);
   
   // Envoyer la requête
   char result[];
   string headers = "Content-Type: application/json\r\n";
   string result_headers = "";
   
   int res = WebRequest("POST", predictionURL, headers, AI_Timeout_ms * 2, data, result, result_headers);
   
   if(res < 200 || res >= 300)
   {
      if(DebugMode)
         Print("⚠️ Erreur prédiction prix: http=", res);
      g_predictionValid = false;
      return;
   }
   
   // Parser la réponse JSON
   string resp = CharArrayToString(result, 0, -1, CP_UTF8);
   
   if(DebugMode)
      Print("📊 Réponse prédiction reçue: ", StringSubstr(resp, 0, 200));
   
   // Extraire le tableau de prédictions
   // Format attendu: {"prediction": [prix1, prix2, ..., prix200]}
   int predStart = StringFind(resp, "\"prediction\"");
   if(predStart < 0)
   {
      predStart = StringFind(resp, "\"prices\"");
      if(predStart < 0)
      {
         if(DebugMode)
            Print("⚠️ Clé 'prediction' ou 'prices' non trouvée dans la réponse");
         g_predictionValid = false;
         return;
      }
   }
   
   // Trouver le début du tableau
   int arrayStart = StringFind(resp, "[", predStart);
   if(arrayStart < 0)
   {
      if(DebugMode)
         Print("⚠️ Tableau de prédiction non trouvé");
      g_predictionValid = false;
      return;
   }
   
   // Trouver la fin du tableau
   int arrayEnd = StringFind(resp, "]", arrayStart);
   if(arrayEnd < 0)
   {
      if(DebugMode)
         Print("⚠️ Fin du tableau de prédiction non trouvée");
      g_predictionValid = false;
      return;
   }
   
   // Extraire le contenu du tableau
   string arrayContent = StringSubstr(resp, arrayStart + 1, arrayEnd - arrayStart - 1);
   
   // Parser les valeurs
   ArrayResize(g_pricePrediction, g_predictionBars);
   ArrayInitialize(g_pricePrediction, 0.0);
   
   int count = 0;
   int pos = 0;
   while(pos < StringLen(arrayContent) && count < g_predictionBars)
   {
      // Trouver la prochaine valeur
      int commaPos = StringFind(arrayContent, ",", pos);
      if(commaPos < 0)
         commaPos = StringLen(arrayContent);
      
      string valueStr = StringSubstr(arrayContent, pos, commaPos - pos);
      StringTrimLeft(valueStr);
      StringTrimRight(valueStr);
      
      if(StringLen(valueStr) > 0)
      {
         g_pricePrediction[count] = StringToDouble(valueStr);
         count++;
      }
      
      pos = commaPos + 1;
   }
   
   if(count > 0)
   {
      ArrayResize(g_pricePrediction, count);
      g_predictionStartTime = TimeCurrent();
      g_predictionValid = true;
      
      if(DebugMode)
         Print("✅ Prédiction de prix mise à jour: ", count, " bougies prédites");
   }
   else
   {
      g_predictionValid = false;
      if(DebugMode)
         Print("⚠️ Aucune prédiction valide extraite");
   }
}

//+------------------------------------------------------------------+
//| Détecter les points de retournement dans les prédictions         |
//| Retourne les indices des points d'entrée BUY (minima) et SELL (maxima) |
//| Filtrer pour ne garder que les mouvements longs                  |
//+------------------------------------------------------------------+
void DetectReversalPoints(int &buyEntries[], int &sellEntries[])
{
   ArrayResize(buyEntries, 0);
   ArrayResize(sellEntries, 0);
   
   if(!g_predictionValid || ArraySize(g_pricePrediction) < 5)
      return;
   
   // NOUVEAU: Ne détecter les points d'entrée QUE pour Boom/Crash et Volatility
   // Ignorer Forex pour éviter les logs inutiles
   bool isBoomCrash = IsBoomCrashSymbol(_Symbol);
   bool isVolatility = IsVolatilitySymbol(_Symbol);
   bool isForex = IsForexSymbol(_Symbol);
   
   // Si c'est du Forex, ne pas détecter de points d'entrée (pas de spike à capturer)
   if(isForex && !isBoomCrash && !isVolatility)
      return;
   
   // Calculer l'ATR pour définir l'amplitude minimale d'un mouvement
   double atr[];
   ArraySetAsSeries(atr, true);
   double minMovement = 0.0;
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
   {
      // Mouvement significatif = au moins 1.5x ATR (réduit pour détecter plus facilement)
      minMovement = atr[0] * 1.5;
   }
   else
   {
      // Fallback: calculer une amplitude minimale basée sur la volatilité des prédictions
      double minPrice = g_pricePrediction[0];
      double maxPrice = g_pricePrediction[0];
      for(int i = 0; i < ArraySize(g_pricePrediction); i++)
      {
         if(g_pricePrediction[i] < minPrice) minPrice = g_pricePrediction[i];
         if(g_pricePrediction[i] > maxPrice) maxPrice = g_pricePrediction[i];
      }
      // Mouvement significatif = au moins 1% de la fourchette de prix (réduit)
      minMovement = (maxPrice - minPrice) * 0.01;
   }
   
   // Si minMovement est toujours trop faible, utiliser une valeur minimale basée sur le prix actuel
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   if(minMovement <= 0 || minMovement < currentPrice * 0.0001) // Au moins 0.01% du prix
      minMovement = currentPrice * 0.0001;
   
   // Fenêtre pour détecter les retournements (chercher un minimum/maximum local)
   int lookbackWindow = 3; // Réduit à 3 points pour détecter plus de points
   
   // Détecter les minima locaux (points d'entrée BUY - retournement haussier)
   for(int i = lookbackWindow; i < ArraySize(g_pricePrediction) - lookbackWindow; i++)
   {
      bool isLocalMin = true;
      double currentPrice = g_pricePrediction[i];
      
      // Vérifier que c'est un minimum local (prix plus bas que les points environnants)
      for(int j = i - lookbackWindow; j <= i + lookbackWindow; j++)
      {
         if(j != i && g_pricePrediction[j] <= currentPrice)
         {
            isLocalMin = false;
            break;
         }
      }
      
      if(isLocalMin)
      {
         // Vérifier que le mouvement suivant est suffisamment long (mouvement haussier)
         // Chercher le prochain maximum local dans un rayon de 20 points
         double maxAfterMin = currentPrice;
         int maxIndex = i;
         for(int k = i + 1; k < MathMin(i + 20, ArraySize(g_pricePrediction)); k++)
         {
            if(g_pricePrediction[k] > maxAfterMin)
            {
               maxAfterMin = g_pricePrediction[k];
               maxIndex = k;
            }
         }
         
         // Le mouvement doit être au moins minMovement
         double movementSize = maxAfterMin - currentPrice;
         if(movementSize >= minMovement)
         {
            int size = ArraySize(buyEntries);
            ArrayResize(buyEntries, size + 1);
            buyEntries[size] = i;
            
            // Ne logger que pour Boom/Crash/Volatility (pas pour Forex)
            if(DebugMode && (isBoomCrash || isVolatility))
               Print("📈 Point d'entrée BUY détecté à l'indice ", i, " prix=", DoubleToString(currentPrice, _Digits), 
                     " mouvement attendu=", DoubleToString(movementSize, _Digits), " (", DoubleToString((movementSize/currentPrice)*100, 2), "%)");
         }
      }
   }
   
   // Détecter les maxima locaux (points d'entrée SELL - retournement baissier)
   for(int i = lookbackWindow; i < ArraySize(g_pricePrediction) - lookbackWindow; i++)
   {
      bool isLocalMax = true;
      double currentPrice = g_pricePrediction[i];
      
      // Vérifier que c'est un maximum local (prix plus haut que les points environnants)
      for(int j = i - lookbackWindow; j <= i + lookbackWindow; j++)
      {
         if(j != i && g_pricePrediction[j] >= currentPrice)
         {
            isLocalMax = false;
            break;
         }
      }
      
      if(isLocalMax)
      {
         // Vérifier que le mouvement suivant est suffisamment long (mouvement baissier)
         // Chercher le prochain minimum local dans un rayon de 20 points
         double minAfterMax = currentPrice;
         int minIndex = i;
         for(int k = i + 1; k < MathMin(i + 20, ArraySize(g_pricePrediction)); k++)
         {
            if(g_pricePrediction[k] < minAfterMax)
            {
               minAfterMax = g_pricePrediction[k];
               minIndex = k;
            }
         }
         
         // Le mouvement doit être au moins minMovement
         double movementSize = currentPrice - minAfterMax;
         if(movementSize >= minMovement)
         {
            int size = ArraySize(sellEntries);
            ArrayResize(sellEntries, size + 1);
            sellEntries[size] = i;
            
            // Ne logger que pour Boom/Crash/Volatility (pas pour Forex)
            if(DebugMode && (isBoomCrash || isVolatility))
               Print("📉 Point d'entrée SELL détecté à l'indice ", i, " prix=", DoubleToString(currentPrice, _Digits), 
                     " mouvement attendu=", DoubleToString(movementSize, _Digits), " (", DoubleToString((movementSize/currentPrice)*100, 2), "%)");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Dessiner la prédiction de prix sur le graphique                  |
//| Canal transparent rempli (vert haussier, rouge baissier)         |
//| 200 bougies historiques + 500 bougies futures                    |
//+------------------------------------------------------------------+
void DrawPricePrediction()
{
   // Réinitialiser le tableau des opportunités au début de chaque mise à jour
   ArrayResize(g_opportunities, 0);
   g_opportunitiesCount = 0;
   
   // Utiliser exactement 200 bougies historiques et 500 bougies futures
   int totalPredictionBars = MathMin(ArraySize(g_pricePrediction), g_predictionBars);
   
   if(totalPredictionBars == 0)
      return; // Pas de prédiction disponible
   
   // OPTIMISATION: Ne supprimer que si nécessaire (éviter ObjectsTotal() à chaque fois)
   string prefix = "PRED_";
   // Ne supprimer que lors de la première création ou si la prédiction a changé
   static bool predictionObjectsCreated = false;
   static datetime lastPredictionTime = 0;
   
   if(!predictionObjectsCreated || g_predictionStartTime != lastPredictionTime)
   {
      // Supprimer les anciens objets seulement si nécessaire
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, prefix) == 0)
            ObjectDelete(0, name);
      }
      predictionObjectsCreated = false;
      lastPredictionTime = g_predictionStartTime;
   }
   
   // Récupérer le timeframe actuel
   ENUM_TIMEFRAMES tf = Period();
   int periodSeconds = PeriodSeconds(tf);
   datetime currentTime = TimeCurrent();
   
   // S'assurer qu'on a bien les 200 bougies historiques disponibles
   int totalHistoryBars = ArraySize(g_priceHistory);
   if(totalHistoryBars < g_historyBars)
   {
      // Récupérer les 200 dernières bougies historiques si nécessaire
      double closeHistory[];
      ArraySetAsSeries(closeHistory, true);
      int historyCopied = CopyClose(_Symbol, PERIOD_M1, 1, g_historyBars, closeHistory);
      if(historyCopied >= g_historyBars)
      {
         ArrayResize(g_priceHistory, g_historyBars);
         ArrayCopy(g_priceHistory, closeHistory, 0, 0, g_historyBars);
         totalHistoryBars = g_historyBars;
      }
      else if(historyCopied > 0)
      {
         // Utiliser ce qu'on a récupéré
         ArrayResize(g_priceHistory, historyCopied);
         ArrayCopy(g_priceHistory, closeHistory, 0, 0, historyCopied);
         totalHistoryBars = historyCopied;
      }
   }
   else
   {
      // Limiter à g_historyBars si on en a plus
      totalHistoryBars = MathMin(totalHistoryBars, g_historyBars);
   }
   
   // Limiter aussi les prédictions à g_predictionBars (500)
   totalPredictionBars = MathMin(totalPredictionBars, g_predictionBars);
   
   // Créer un tableau combiné avec historique (200) + prédiction (500)
   int totalBars = totalHistoryBars + totalPredictionBars;
   double combinedPrices[];
   datetime combinedTimes[];
   ArrayResize(combinedPrices, totalBars);
   ArrayResize(combinedTimes, totalBars);
   
   // Remplir avec les 200 dernières bougies historiques (de la plus ancienne à la plus récente)
   for(int i = 0; i < totalHistoryBars; i++)
   {
      // Les données historiques sont en ordre inverse (ArraySetAsSeries = true)
      // Donc g_priceHistory[0] est la plus récente, g_priceHistory[totalHistoryBars-1] est la plus ancienne
      int histIdx = totalHistoryBars - 1 - i; // Inverser pour avoir l'ordre chronologique
      combinedPrices[i] = g_priceHistory[histIdx];
      combinedTimes[i] = currentTime - (totalHistoryBars - i) * periodSeconds; // Passé
   }
   
   // Remplir avec les 500 bougies futures prédites
   for(int i = 0; i < totalPredictionBars; i++)
   {
      combinedPrices[totalHistoryBars + i] = g_pricePrediction[i];
      combinedTimes[totalHistoryBars + i] = currentTime + (i + 1) * periodSeconds; // Futur
   }
   
   // Déterminer si la prédiction globale est haussière ou baissière
   // Comparer le prix de début (début historique) vs prix de fin (fin prédiction)
   double startPrice = combinedPrices[0]; // Premier prix historique (le plus ancien)
   double endPrice = combinedPrices[totalBars - 1]; // Dernier prix prédit (le plus futur)
   bool isBullish = (endPrice > startPrice);
   
   // Calculer une bande de confiance basée sur ATR pour le canal
   double atr[];
   ArraySetAsSeries(atr, true);
   double confidenceBand = 0.0;
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
   {
      confidenceBand = atr[0] * 1.5; // Bande de confiance = 1.5x ATR
   }
   else
   {
      // Fallback: utiliser une bande basée sur la volatilité des prix
      double minPrice = combinedPrices[0];
      double maxPrice = combinedPrices[0];
      for(int i = 0; i < totalBars; i++)
      {
         if(combinedPrices[i] < minPrice) minPrice = combinedPrices[i];
         if(combinedPrices[i] > maxPrice) maxPrice = combinedPrices[i];
      }
      confidenceBand = (maxPrice - minPrice) * 0.02; // 2% de la fourchette
   }
   
   // Si pas d'historique, commencer depuis le prix actuel
   if(totalHistoryBars == 0)
   {
      // Créer un point de départ au prix actuel
      totalHistoryBars = 1;
      ArrayResize(combinedPrices, totalBars + 1);
      ArrayResize(combinedTimes, totalBars + 1);
      
      // Décaler les prédictions
      for(int i = totalPredictionBars - 1; i >= 0; i--)
      {
         combinedPrices[i + 1] = g_pricePrediction[i];
         combinedTimes[i + 1] = currentTime + (i + 1) * periodSeconds;
      }
      
      // Ajouter le point de départ (prix actuel)
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
      combinedPrices[0] = currentPrice;
      combinedTimes[0] = currentTime;
      
      totalBars = totalPredictionBars + 1;
      startPrice = combinedPrices[0];
      endPrice = combinedPrices[totalBars - 1];
      isBullish = (endPrice > startPrice);
   }
   
   // Créer les tableaux pour les lignes supérieure et inférieure du canal
   double upperPrices[];
   double lowerPrices[];
   ArrayResize(upperPrices, totalBars);
   ArrayResize(lowerPrices, totalBars);
   
   for(int i = 0; i < totalBars; i++)
   {
      upperPrices[i] = combinedPrices[i] + confidenceBand;
      lowerPrices[i] = combinedPrices[i] - confidenceBand;
   }
   
   // OPTIMISATION PERFORMANCE: Dessiner le canal avec un step de 5 au lieu de 1 pour réduire le nombre d'objets
   // Step de 5 = 5x moins d'objets = 5x plus rapide
   int channelStep = 5; // Augmenté de 1 à 5 pour performance
   // Couleurs extrêmement transparentes en filigrane (alpha très faible pour être vraiment transparent, pas saturé)
   // Utiliser des couleurs claires et douces, pas saturées, avec alpha très faible pour l'effet filigrane
   // Utiliser ColorToARGB() pour créer des couleurs avec transparence
   color baseColor;
   uchar alphaValue = 5; // Alpha extrêmement faible (5 sur 255 = très transparent en filigrane) pour effet watermark
   
   if(isBullish)
   {
      // Vert très clair et doux (pas saturé) pour prédiction haussière
      baseColor = C'180,240,180'; // RGB(180, 240, 180) - vert très clair et doux
   }
   else
   {
      // Rouge très clair et doux (pas saturé) pour prédiction baissière
      baseColor = C'240,180,180'; // RGB(240, 180, 180) - rouge très clair et doux
   }
   
   // Créer la couleur ARGB avec transparence maximale
   color channelColor = (color)ColorToARGB(baseColor, alphaValue);
   
   // Dessiner le canal rempli segment par segment avec step optimisé (5x moins d'objets = 5x plus rapide)
   for(int i = 0; i < totalBars - channelStep; i += channelStep)
   {
      int nextIdx = MathMin(i + channelStep, totalBars - 1);
      
      // Créer un rectangle rempli pour ce segment du canal
      string rectName = prefix + "CHANNEL_" + IntegerToString(i) + "_" + _Symbol;
      
      datetime time1 = combinedTimes[i];
      datetime time2 = combinedTimes[nextIdx];
      
      // Calculer les lignes supérieure et inférieure pour chaque extrémité du segment
      double upperPrice1 = upperPrices[i];
      double upperPrice2 = upperPrices[nextIdx];
      double lowerPrice1 = lowerPrices[i];
      double lowerPrice2 = lowerPrices[nextIdx];
      
      // Pour créer un canal continu, utiliser le maximum des prix supérieurs et le minimum des prix inférieurs
      double rectTopPrice = MathMax(upperPrice1, upperPrice2);
      double rectBottomPrice = MathMin(lowerPrice1, lowerPrice2);
      
      // Créer le rectangle rempli transparent (filigrane)
      if(ObjectFind(0, rectName) < 0)
         ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, time1, rectTopPrice, time2, rectBottomPrice);
      else
      {
         ObjectSetInteger(0, rectName, OBJPROP_TIME, 0, time1);
         ObjectSetDouble(0, rectName, OBJPROP_PRICE, 0, rectTopPrice);
         ObjectSetInteger(0, rectName, OBJPROP_TIME, 1, time2);
         ObjectSetDouble(0, rectName, OBJPROP_PRICE, 1, rectBottomPrice);
      }
      
      // Couleur extrêmement transparente en filigrane (ARGB avec alpha = 5 = très transparent en watermark)
      ObjectSetInteger(0, rectName, OBJPROP_COLOR, channelColor);
      ObjectSetInteger(0, rectName, OBJPROP_BGCOLOR, channelColor); // Aussi définir BGCOLOR pour le remplissage
      ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
      ObjectSetInteger(0, rectName, OBJPROP_BACK, true); // En arrière-plan pour ne pas masquer le prix (filigrane)
      ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, rectName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   }
   
   // NE PAS dessiner de ligne médiane - l'utilisateur veut seulement le canal rempli transparent
   
   // Détecter les points de retournement (mouvements longs) - uniquement dans la partie prédiction future
   int buyEntries[];
   int sellEntries[];
   DetectReversalPoints(buyEntries, sellEntries);
   
   // Dessiner les points d'entrée BUY (minima - retournements haussiers) en VERT
   // Les indices dans buyEntries sont relatifs à g_pricePrediction, donc on ajoute totalHistoryBars pour obtenir l'index dans combinedTimes
   for(int b = 0; b < ArraySize(buyEntries); b++)
   {
      int predIdx = buyEntries[b]; // Index dans g_pricePrediction
      if(predIdx >= 0 && predIdx < totalPredictionBars)
      {
         int combinedIdx = totalHistoryBars + predIdx; // Index dans combinedPrices/Times
         if(combinedIdx < totalBars)
         {
            string buyEntryName = prefix + "BUY_ENTRY_" + IntegerToString(predIdx) + "_" + _Symbol;
            if(ObjectFind(0, buyEntryName) < 0)
               ObjectCreate(0, buyEntryName, OBJ_ARROW_UP, 0, combinedTimes[combinedIdx], combinedPrices[combinedIdx]);
            else
            {
               ObjectSetInteger(0, buyEntryName, OBJPROP_TIME, 0, combinedTimes[combinedIdx]);
               ObjectSetDouble(0, buyEntryName, OBJPROP_PRICE, 0, combinedPrices[combinedIdx]);
            }
            
            ObjectSetInteger(0, buyEntryName, OBJPROP_COLOR, clrLime); // Vert pour BUY
            ObjectSetInteger(0, buyEntryName, OBJPROP_ARROWCODE, 233); // Flèche vers le haut
            ObjectSetInteger(0, buyEntryName, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, buyEntryName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, buyEntryName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            ObjectSetString(0, buyEntryName, OBJPROP_TEXT, "ENTRY BUY (Long)");
            
            // Calculer le mouvement attendu pour stocker dans le panneau d'info
            double movementSize = 0.0;
            for(int k = predIdx + 1; k < MathMin(predIdx + 20, totalPredictionBars); k++)
            {
               int kCombinedIdx = totalHistoryBars + k;
               if(kCombinedIdx < totalBars && combinedPrices[kCombinedIdx] > combinedPrices[combinedIdx])
                  movementSize = MathMax(movementSize, combinedPrices[kCombinedIdx] - combinedPrices[combinedIdx]);
            }
            
            // Stocker l'opportunité dans le tableau au lieu d'afficher un label
            if(movementSize > 0)
            {
               int size = ArraySize(g_opportunities);
               ArrayResize(g_opportunities, size + 1);
               g_opportunities[size].isBuy = true;
               g_opportunities[size].entryPrice = combinedPrices[combinedIdx];
               g_opportunities[size].percentage = (movementSize / combinedPrices[combinedIdx]) * 100.0;
               g_opportunities[size].entryTime = combinedTimes[combinedIdx];
               g_opportunities[size].priority = (int)(g_opportunities[size].percentage * 10); // Pour trier
               g_opportunitiesCount++;
               
               // Supprimer l'ancien label s'il existe
               string buyLabelName = prefix + "BUY_LABEL_" + IntegerToString(predIdx) + "_" + _Symbol;
               ObjectDelete(0, buyLabelName);
            }
         }
      }
   }
   
   // Dessiner les points d'entrée SELL (maxima - retournements baissiers) en ROUGE
   for(int s = 0; s < ArraySize(sellEntries); s++)
   {
      int predIdx = sellEntries[s]; // Index dans g_pricePrediction
      if(predIdx >= 0 && predIdx < totalPredictionBars)
      {
         int combinedIdx = totalHistoryBars + predIdx; // Index dans combinedPrices/Times
         if(combinedIdx < totalBars)
         {
            string sellEntryName = prefix + "SELL_ENTRY_" + IntegerToString(predIdx) + "_" + _Symbol;
            if(ObjectFind(0, sellEntryName) < 0)
               ObjectCreate(0, sellEntryName, OBJ_ARROW_DOWN, 0, combinedTimes[combinedIdx], combinedPrices[combinedIdx]);
            else
            {
               ObjectSetInteger(0, sellEntryName, OBJPROP_TIME, 0, combinedTimes[combinedIdx]);
               ObjectSetDouble(0, sellEntryName, OBJPROP_PRICE, 0, combinedPrices[combinedIdx]);
            }
            
            ObjectSetInteger(0, sellEntryName, OBJPROP_COLOR, clrRed); // Rouge pour SELL
            ObjectSetInteger(0, sellEntryName, OBJPROP_ARROWCODE, 234); // Flèche vers le bas
            ObjectSetInteger(0, sellEntryName, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, sellEntryName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, sellEntryName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            ObjectSetString(0, sellEntryName, OBJPROP_TEXT, "ENTRY SELL (Long)");
            
            // Calculer le mouvement attendu pour stocker dans le panneau d'info
            double movementSize = 0.0;
            for(int k = predIdx + 1; k < MathMin(predIdx + 20, totalPredictionBars); k++)
            {
               int kCombinedIdx = totalHistoryBars + k;
               if(kCombinedIdx < totalBars && combinedPrices[kCombinedIdx] < combinedPrices[combinedIdx])
                  movementSize = MathMax(movementSize, combinedPrices[combinedIdx] - combinedPrices[kCombinedIdx]);
            }
            
            // Stocker l'opportunité dans le tableau au lieu d'afficher un label
            if(movementSize > 0)
            {
               int size = ArraySize(g_opportunities);
               ArrayResize(g_opportunities, size + 1);
               g_opportunities[size].isBuy = false;
               g_opportunities[size].entryPrice = combinedPrices[combinedIdx];
               g_opportunities[size].percentage = (movementSize / combinedPrices[combinedIdx]) * 100.0;
               g_opportunities[size].entryTime = combinedTimes[combinedIdx];
               g_opportunities[size].priority = (int)(g_opportunities[size].percentage * 10); // Pour trier
               g_opportunitiesCount++;
               
               // Supprimer l'ancien label s'il existe
               string sellLabelName = prefix + "SELL_LABEL_" + IntegerToString(predIdx) + "_" + _Symbol;
               ObjectDelete(0, sellLabelName);
            }
         }
      }
   }
   
   // OPTIMISATION: Détecter les zones de correction seulement toutes les 30 secondes (très lourd)
   static datetime lastCorrectionCheck = 0;
   if((TimeCurrent() - lastCorrectionCheck) >= 30)
   {
      // Détecter et dessiner les zones de correction
      DetectAndDrawCorrectionZones();
      
      // Placer un ordre limite sur la meilleure zone de correction
      PlaceLimitOrderOnCorrection();
      
      lastCorrectionCheck = TimeCurrent();
      predictionObjectsCreated = true; // Marquer comme créé
   }
   
   // OPTIMISATION: ChartRedraw() seulement toutes les 5 secondes au lieu de chaque fois
   static datetime lastChartRedraw = 0;
   if((TimeCurrent() - lastChartRedraw) >= 5)
   {
      ChartRedraw(0);
      lastChartRedraw = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Structure pour stocker les zones de correction                   |
//+------------------------------------------------------------------+
struct CorrectionZone
{
   int startIdx;        // Index de début de la correction
   int endIdx;          // Index de fin de la correction
   double highPrice;    // Prix le plus haut de la zone
   double lowPrice;     // Prix le plus bas de la zone
   double entryPrice;   // Prix d'entrée recommandé (milieu ou support de la zone)
   bool isBuyZone;      // true = zone d'achat (correction baissière après hausse), false = zone de vente
   double potentialGain; // Gain potentiel estimé
   datetime entryTime;  // Temps d'entrée estimé
};

static CorrectionZone g_bestCorrectionZone;
static bool g_hasBestCorrectionZone = false;

//+------------------------------------------------------------------+
//| Détecter les zones de correction dans la prédiction              |
//| Une correction = retracement après un mouvement                   |
//+------------------------------------------------------------------+
void DetectAndDrawCorrectionZones()
{
   int predSize = ArraySize(g_pricePrediction);
   if(!g_predictionValid || predSize < 20)
   {
      if(DebugMode)
         Print("🔍 DetectAndDrawCorrectionZones: Prédiction invalide (valid=", g_predictionValid ? "true" : "false", ", size=", predSize, ")");
      return;
   }
   
   if(DebugMode)
      Print("🔍 DetectAndDrawCorrectionZones: Démarrage - Prédiction valide, size=", predSize);
   
   // OPTIMISATION: Supprimer les anciennes zones seulement si nécessaire
   string prefix = "PRED_CORRECTION_";
   static datetime lastCorrectionDraw = 0;
   static int lastPredictionSize = 0;
   
   if((TimeCurrent() - lastCorrectionDraw) >= 60 || ArraySize(g_pricePrediction) != lastPredictionSize)
   {
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, prefix) == 0)
            ObjectDelete(0, name);
      }
      lastCorrectionDraw = TimeCurrent();
      lastPredictionSize = ArraySize(g_pricePrediction);
   }
   
   // Récupérer le timeframe actuel
   ENUM_TIMEFRAMES tf = Period();
   int periodSeconds = PeriodSeconds(tf);
   datetime currentTime = TimeCurrent();
   
   // Créer un tableau des zones de correction
   CorrectionZone zones[];
   ArrayResize(zones, 0);
   
   // OPTIMISATION: Analyser seulement une partie de la prédiction (les 100 premières bougies = plus proche)
   // Et utiliser un step plus grand pour réduire les calculs
   int windowSize = 10; // Fenêtre pour détecter un mouvement significatif
   int maxAnalysisBars = MathMin(100, ArraySize(g_pricePrediction) - windowSize); // Limiter à 100 bougies
   int analysisStep = 3; // Analyser 1 point sur 3 pour réduire les calculs
   
   for(int i = windowSize; i < maxAnalysisBars; i += analysisStep)
   {
      // Détecter les mouvements haussiers suivis de corrections baissières (zone d'achat)
      // Chercher un pic (maximum local) suivi d'un retracement
      bool isLocalPeak = true;
      double peakPrice = g_pricePrediction[i];
      
      // OPTIMISATION: Vérifier avec step pour réduire les calculs
      for(int j = i - 5; j <= i + 5; j += 2) // Step de 2
      {
         if(j != i && j >= 0 && j < ArraySize(g_pricePrediction))
         {
            if(g_pricePrediction[j] >= peakPrice)
            {
               isLocalPeak = false;
               break;
            }
         }
      }
      
      if(isLocalPeak)
      {
         // OPTIMISATION: Chercher la correction qui suit avec un step plus grand
         double lowestCorrection = peakPrice;
         int correctionEndIdx = i;
         int correctionStep = 2; // Analyser 1 point sur 2
         
         for(int k = i + 1; k < MathMin(i + 30, ArraySize(g_pricePrediction) - 1); k += correctionStep)
         {
            if(g_pricePrediction[k] < lowestCorrection)
            {
               lowestCorrection = g_pricePrediction[k];
               correctionEndIdx = k;
            }
            // Si le prix remonte après la correction, on a trouvé la fin de la zone
            // OPTIMISATION: Vérifier seulement tous les 2 points
            if(k > i + 5 && (k % 2 == 0) && g_pricePrediction[k] > g_pricePrediction[MathMax(0, k-correctionStep)] && 
               g_pricePrediction[k] > lowestCorrection * 1.001) // Remontée d'au moins 0.1%
            {
               // Vérifier que la correction est significative (au moins 30% du mouvement)
               double movementUp = peakPrice - g_pricePrediction[i - windowSize];
               double correctionDown = peakPrice - lowestCorrection;
               
               if(movementUp > 0 && correctionDown > 0)
               {
                  double correctionPercent = (correctionDown / movementUp) * 100.0;
                  
                  // Correction valide si elle représente 30-70% du mouvement (retracement Fibonacci-like)
                  if(correctionPercent >= 30.0 && correctionPercent <= 70.0)
                  {
                     CorrectionZone zone;
                     zone.startIdx = i;
                     zone.endIdx = k;
                     zone.highPrice = peakPrice;
                     zone.lowPrice = lowestCorrection;
                     zone.entryPrice = lowestCorrection * 1.002; // Entrer légèrement au-dessus du bas (0.2%)
                     zone.isBuyZone = true; // Zone d'achat après correction baissière
                     
                     // OPTIMISATION: Calculer le gain potentiel avec step
                     double potentialHigh = g_pricePrediction[k];
                     for(int m = k; m < MathMin(k + 20, ArraySize(g_pricePrediction)); m += 2)
                     {
                        if(g_pricePrediction[m] > potentialHigh)
                           potentialHigh = g_pricePrediction[m];
                     }
                     zone.potentialGain = ((potentialHigh - zone.entryPrice) / zone.entryPrice) * 100.0;
                     zone.entryTime = currentTime + (i + 1) * periodSeconds;
                     
                     // Ajouter la zone si le gain potentiel est intéressant (> 0.5%)
                     if(zone.potentialGain > 0.5)
                     {
                        int size = ArraySize(zones);
                        ArrayResize(zones, size + 1);
                        zones[size] = zone;
                     }
                  }
               }
               break;
            }
         }
      }
      
      // Détecter les mouvements baissiers suivis de corrections haussières (zone de vente)
      // Chercher un creux (minimum local) suivi d'un retracement
      bool isLocalTrough = true;
      double troughPrice = g_pricePrediction[i];
      
      // OPTIMISATION: Vérifier avec step pour réduire les calculs
      for(int j = i - 5; j <= i + 5; j += 2) // Step de 2
      {
         if(j != i && j >= 0 && j < ArraySize(g_pricePrediction))
         {
            if(g_pricePrediction[j] <= troughPrice)
            {
               isLocalTrough = false;
               break;
            }
         }
      }
      
      if(isLocalTrough)
      {
         // OPTIMISATION: Chercher la correction qui suit avec un step plus grand
         double highestCorrection = troughPrice;
         int correctionEndIdx = i;
         int correctionStep = 2; // Analyser 1 point sur 2
         
         for(int k = i + 1; k < MathMin(i + 30, ArraySize(g_pricePrediction) - 1); k += correctionStep)
         {
            if(g_pricePrediction[k] > highestCorrection)
            {
               highestCorrection = g_pricePrediction[k];
               correctionEndIdx = k;
            }
            // Si le prix redescend après la correction, on a trouvé la fin de la zone
            // OPTIMISATION: Vérifier seulement tous les 2 points
            if(k > i + 5 && (k % 2 == 0) && g_pricePrediction[k] < g_pricePrediction[MathMax(0, k-correctionStep)] && 
               g_pricePrediction[k] < highestCorrection * 0.999) // Descente d'au moins 0.1%
            {
               // Vérifier que la correction est significative (au moins 30% du mouvement)
               double movementDown = g_pricePrediction[i - windowSize] - troughPrice;
               double correctionUp = highestCorrection - troughPrice;
               
               if(movementDown > 0 && correctionUp > 0)
               {
                  double correctionPercent = (correctionUp / movementDown) * 100.0;
                  
                  // Correction valide si elle représente 30-70% du mouvement
                  if(correctionPercent >= 30.0 && correctionPercent <= 70.0)
                  {
                     CorrectionZone zone;
                     zone.startIdx = i;
                     zone.endIdx = k;
                     zone.highPrice = highestCorrection;
                     zone.lowPrice = troughPrice;
                     zone.entryPrice = highestCorrection * 0.998; // Entrer légèrement en-dessous du haut (0.2%)
                     zone.isBuyZone = false; // Zone de vente après correction haussière
                     
                     // OPTIMISATION: Calculer le gain potentiel avec step
                     double potentialLow = g_pricePrediction[k];
                     for(int m = k; m < MathMin(k + 20, ArraySize(g_pricePrediction)); m += 2)
                     {
                        if(g_pricePrediction[m] < potentialLow)
                           potentialLow = g_pricePrediction[m];
                     }
                     zone.potentialGain = ((zone.entryPrice - potentialLow) / zone.entryPrice) * 100.0;
                     zone.entryTime = currentTime + (i + 1) * periodSeconds;
                     
                     // Ajouter la zone si le gain potentiel est intéressant (> 0.5%)
                     if(zone.potentialGain > 0.5)
                     {
                        int size = ArraySize(zones);
                        ArrayResize(zones, size + 1);
                        zones[size] = zone;
                     }
                  }
               }
               break;
            }
         }
      }
   }
   
   // Dessiner les zones de correction détectées
   int totalHistoryBars = ArraySize(g_priceHistory);
   for(int z = 0; z < ArraySize(zones); z++)
   {
      datetime zoneStartTime = currentTime + (zones[z].startIdx + 1) * periodSeconds;
      datetime zoneEndTime = currentTime + (zones[z].endIdx + 1) * periodSeconds;
      
      // Créer un rectangle pour la zone de correction
      string zoneName = prefix + "ZONE_" + IntegerToString(z) + "_" + _Symbol;
      
      if(ObjectFind(0, zoneName) < 0)
         ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, zoneStartTime, zones[z].highPrice, zoneEndTime, zones[z].lowPrice);
      else
      {
         ObjectSetInteger(0, zoneName, OBJPROP_TIME, 0, zoneStartTime);
         ObjectSetDouble(0, zoneName, OBJPROP_PRICE, 0, zones[z].highPrice);
         ObjectSetInteger(0, zoneName, OBJPROP_TIME, 1, zoneEndTime);
         ObjectSetDouble(0, zoneName, OBJPROP_PRICE, 1, zones[z].lowPrice);
      }
      
      // Couleur : jaune/orange pour les zones de correction (visible mais distinct)
      color zoneColor = zones[z].isBuyZone ? C'255,200,0' : C'255,150,0'; // Jaune pour BUY, Orange pour SELL
      color zoneColorARGB = (color)ColorToARGB(zoneColor, 80); // Alpha 80 pour visibilité
      
      ObjectSetInteger(0, zoneName, OBJPROP_COLOR, zoneColorARGB);
      ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, zoneColorARGB);
      ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
      ObjectSetInteger(0, zoneName, OBJPROP_BACK, false); // Au premier plan pour être visible
      ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, zoneName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      
      // Ajouter une ligne horizontale pour le prix d'entrée recommandé
      string entryLineName = prefix + "ENTRY_" + IntegerToString(z) + "_" + _Symbol;
      if(ObjectFind(0, entryLineName) < 0)
         ObjectCreate(0, entryLineName, OBJ_HLINE, 0, 0, zones[z].entryPrice);
      else
         ObjectSetDouble(0, entryLineName, OBJPROP_PRICE, 0, zones[z].entryPrice);
      
      ObjectSetInteger(0, entryLineName, OBJPROP_COLOR, zones[z].isBuyZone ? clrLime : clrRed);
      ObjectSetInteger(0, entryLineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, entryLineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, entryLineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, entryLineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      
      // Stocker l'opportunité dans le tableau au lieu d'afficher un label encombrant
      int size = ArraySize(g_opportunities);
      ArrayResize(g_opportunities, size + 1);
      g_opportunities[size].isBuy = zones[z].isBuyZone;
      g_opportunities[size].entryPrice = zones[z].entryPrice;
      g_opportunities[size].percentage = zones[z].potentialGain;
      g_opportunities[size].entryTime = zoneStartTime;
      g_opportunities[size].priority = (int)(zones[z].potentialGain * 10); // Pour trier
      g_opportunitiesCount++;
      
      // Supprimer l'ancien label s'il existe
      string labelName = prefix + "LABEL_" + IntegerToString(z) + "_" + _Symbol;
      ObjectDelete(0, labelName);
   }
   
   // Trouver la meilleure zone de correction (celle avec le meilleur gain potentiel)
   g_hasBestCorrectionZone = false;
   int zonesCount = ArraySize(zones);
   
   if(DebugMode)
      Print("🔍 DetectAndDrawCorrectionZones: ", zonesCount, " zone(s) détectée(s)");
   
   if(zonesCount > 0)
   {
      int bestZoneIdx = 0;
      double bestGain = zones[0].potentialGain;
      
      for(int z = 1; z < zonesCount; z++)
      {
         if(zones[z].potentialGain > bestGain)
         {
            bestGain = zones[z].potentialGain;
            bestZoneIdx = z;
         }
      }
      
      g_bestCorrectionZone = zones[bestZoneIdx];
      g_hasBestCorrectionZone = true;
      
      Print("✅ Meilleure zone de correction détectée: ", (g_bestCorrectionZone.isBuyZone ? "BUY" : "SELL"), 
            " Entry=", DoubleToString(g_bestCorrectionZone.entryPrice, _Digits), 
            " Gain potentiel=", DoubleToString(g_bestCorrectionZone.potentialGain, 2), "%",
            " StartIdx=", g_bestCorrectionZone.startIdx);
   }
   else
   {
      if(DebugMode)
         Print("⚠️ DetectAndDrawCorrectionZones: Aucune zone de correction détectée");
   }
}

//+------------------------------------------------------------------+
//| Placer un ordre limite sur la meilleure zone de correction       |
//+------------------------------------------------------------------+
void PlaceLimitOrderOnCorrection()
{
   // Vérifier qu'on a des opportunités à évaluer
   if(g_opportunitiesCount == 0)
   {
      if(DebugMode)
         Print("🔍 PlaceLimitOrder: Pas d'opportunités détectées");
      return;
   }
   
   // Ne placer qu'un seul ordre limite à la fois, et seulement si la prédiction a été mise à jour
   int timeSinceUpdate = (int)(TimeCurrent() - g_lastPredictionUpdate);
   if(timeSinceUpdate > 600) // Prédiction trop ancienne (> 10 min)
   {
      if(DebugMode)
         Print("🔍 PlaceLimitOrder: Prédiction trop ancienne (", timeSinceUpdate, "s > 600s)");
      return;
   }
   
   // ===== VÉRIFICATION 1: Confiance IA >= 80% (OBLIGATOIRE) =====
   if(g_lastAIConfidence < 0.80)
   {
      if(DebugMode)
         Print("🚫 PlaceLimitOrder: Confiance IA insuffisante (", DoubleToString(g_lastAIConfidence * 100, 1), "% < 80%)");
      return; // Confiance IA insuffisante
   }
   
   // ===== VÉRIFICATION 2: Déterminer la direction de la prédiction =====
   int predSize = ArraySize(g_pricePrediction);
   if(!g_predictionValid || predSize < 20)
   {
      if(DebugMode)
         Print("🔍 PlaceLimitOrder: Prédiction invalide (valid=", g_predictionValid ? "true" : "false", ", size=", predSize, ")");
      return; // Pas de prédiction valide
   }
   
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   int predictionWindow = MathMin(20, ArraySize(g_pricePrediction)); // Utiliser 20 bougies au lieu de 50
   double predictedPrice = g_pricePrediction[predictionWindow - 1]; // Prix prédit dans 20 bougies
   
   // Déterminer la direction de la prédiction (1 = BUY/haussier, -1 = SELL/baissier, 0 = neutre)
   int predictionDirection = 0;
   double priceMovement = predictedPrice - currentPrice;
   double movementPercent = (MathAbs(priceMovement) / currentPrice) * 100.0;
   
   if(movementPercent > 0.05) // Mouvement significatif (> 0.05%)
   {
      if(priceMovement > 0)
         predictionDirection = 1; // Prédiction haussière (BUY)
      else
         predictionDirection = -1; // Prédiction baissière (SELL)
   }
   
   if(DebugMode)
      Print("🔍 PlaceLimitOrder: Prédiction - Prix actuel=", DoubleToString(currentPrice, _Digits), 
            " Prédit=", DoubleToString(predictedPrice, _Digits), 
            " Mouvement=", DoubleToString(movementPercent, 2), "%",
            " Direction=", predictionDirection == 1 ? "BUY" : (predictionDirection == -1 ? "SELL" : "NEUTRE"));
   
   // ===== VÉRIFICATION 3: Déterminer la direction du marché (IA) =====
   // Déterminer la direction de l'IA
   int aiDirection = 0;
   if(g_lastAIAction == "buy")
      aiDirection = 1;
   else if(g_lastAIAction == "sell")
      aiDirection = -1;
   else if(g_api_trend_direction != 0)
      aiDirection = g_api_trend_direction;
   
   if(DebugMode)
      Print("🔍 PlaceLimitOrder: IA - Action=", g_lastAIAction, 
            " API_Trend=", g_api_trend_direction, 
            " Direction finale=", aiDirection == 1 ? "BUY" : (aiDirection == -1 ? "SELL" : "NEUTRE"),
            " Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%");
   
   // Déterminer la direction du marché basée sur IA et Prédiction
   // RÈGLE: Utiliser la direction si elle est claire, priorité à l'IA si confiance >= 80%
   // Si IA et Prédiction sont en désaccord, utiliser celle qui a le plus de confiance
   int marketDirection = 0;
   
   // Priorité 1: Si IA et Prédiction sont alignées, utiliser cette direction (le plus fiable)
   if(aiDirection != 0 && predictionDirection != 0 && aiDirection == predictionDirection)
   {
      marketDirection = aiDirection; // Direction alignée (le plus fiable)
      if(DebugMode)
         Print("✅ PlaceLimitOrder: IA et Prédiction alignées - Direction=", marketDirection == 1 ? "BUY" : "SELL");
   }
   // Priorité 2: Si l'IA a une direction claire (confiance >= 80%), utiliser l'IA
   else if(aiDirection != 0 && g_lastAIConfidence >= 0.80)
   {
      marketDirection = aiDirection; // Priorité à l'IA si confiance >= 80%
      if(DebugMode)
         Print("✅ PlaceLimitOrder: Utilisation IA (confiance >= 80%) - Direction=", marketDirection == 1 ? "BUY" : "SELL");
   }
   // Priorité 3: Si seulement la prédiction a une direction claire, utiliser la prédiction
   else if(predictionDirection != 0 && aiDirection == 0)
   {
      marketDirection = predictionDirection; // Utiliser la prédiction si IA neutre
   if(DebugMode)
         Print("✅ PlaceLimitOrder: Utilisation Prédiction (IA neutre) - Direction=", marketDirection == 1 ? "BUY" : "SELL");
   }
   // Priorité 4: Si l'IA a une direction (même si < 80%) et prédiction neutre, utiliser l'IA
   else if(aiDirection != 0 && predictionDirection == 0)
   {
      marketDirection = aiDirection; // Utiliser l'IA même si confiance < 80% et prédiction neutre
      if(DebugMode)
         Print("⚠️ PlaceLimitOrder: Utilisation IA (confiance < 80%, prédiction neutre) - Direction=", marketDirection == 1 ? "BUY" : "SELL");
   }
   // Priorité 5: Si IA et Prédiction sont en désaccord et IA < 80%, utiliser la prédiction
   else if(aiDirection != 0 && predictionDirection != 0 && aiDirection != predictionDirection && g_lastAIConfidence < 0.80)
   {
      marketDirection = predictionDirection; // Priorité à la prédiction si IA < 80% et désaccord
      if(DebugMode)
         Print("⚠️ PlaceLimitOrder: IA et Prédiction en désaccord - Utilisation Prédiction (IA < 80%) - Direction=", marketDirection == 1 ? "BUY" : "SELL");
   }
   
   if(marketDirection == 0)
   {
      Print("🚫 PlaceLimitOrder: Pas de direction claire - IA=", aiDirection, " (confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%), Prédiction=", predictionDirection);
      return; // Pas de direction claire
   }
   
   Print("🔍 PlaceLimitOrder: Direction marché déterminée=", marketDirection == 1 ? "BUY" : "SELL",
         " (IA=", aiDirection == 1 ? "BUY" : (aiDirection == -1 ? "SELL" : "NEUTRE"),
         ", Prédiction=", predictionDirection == 1 ? "BUY" : (predictionDirection == -1 ? "SELL" : "NEUTRE"), ")");
   
   // ===== ÉVALUER TOUTES LES OPPORTUNITÉS ET SÉLECTIONNER LA MEILLEURE =====
   TradingOpportunity bestOpportunity;
   bestOpportunity.isBuy = false;           // Initialiser par défaut
   bestOpportunity.entryPrice = 0.0;       // Initialiser par défaut
   bestOpportunity.percentage = 0.0;       // Initialiser par défaut
   bestOpportunity.entryTime = 0;          // Initialiser par défaut
   bestOpportunity.priority = 0;            // Initialiser par défaut
   bool bestFound = false;
   double bestScore = -1.0;
   
   // ===== UTILISER LA DÉCISION FINALE =====
   FinalDecisionResult finalDecision;
   bool hasValidDecision = GetFinalDecision(finalDecision);
   
   if(!hasValidDecision || finalDecision.direction == 0)
   {
      Print("🚫 PlaceLimitOrder: Décision finale invalide ou neutre - Pas d'ordre limit placé");
      Print("📊 Décision finale: Direction=", (finalDecision.direction == 1 ? "BUY" : (finalDecision.direction == -1 ? "SELL" : "NEUTRE")),
            " Confiance=", DoubleToString(finalDecision.confidence * 100, 1), "%",
            " | ", finalDecision.details);
      return;
   }
   
   // Vérifier que la direction de la décision finale correspond à l'opportunité
   bool zoneIsBuy = bestOpportunity.isBuy;
   bool decisionIsBuy = (finalDecision.direction == 1);
   
   if(zoneIsBuy != decisionIsBuy)
   {
      Print("🚫 PlaceLimitOrder: Décision finale (", (decisionIsBuy ? "BUY" : "SELL"), ") ne correspond pas à l'opportunité (", (zoneIsBuy ? "BUY" : "SELL"), ")");
      return;
   }
   
   // Récupérer les valeurs EMA pour ajuster les prix d'entrée
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   bool hasEMA = (CopyBuffer(emaFastHandle, 0, 0, 1, emaFast) > 0 && 
                  CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlow) > 0);
   double emaFastValue = hasEMA ? emaFast[0] : 0;
   double emaSlowValue = hasEMA ? emaSlow[0] : 0;
   
   // Calculer ATR pour définir "proche"
   double atrM5[], atrH1[];
   ArraySetAsSeries(atrM5, true);
   ArraySetAsSeries(atrH1, true);
   double atrValue = 0;
   if(CopyBuffer(atrM5Handle, 0, 0, 1, atrM5) > 0)
      atrValue = atrM5[0];
   else if(CopyBuffer(atrH1Handle, 0, 0, 1, atrH1) > 0)
      atrValue = atrH1[0];
   if(atrValue == 0) atrValue = currentPrice * 0.001; // Fallback: 0.1% du prix
   double maxDistance = atrValue * 1.5; // 1.5 ATR = distance maximale pour "proche"
   
   // PROTECTION: Bloquer SELL_LIMIT sur Boom (y compris Vol over Boom) et BUY_LIMIT sur Crash (y compris Vol over Crash)
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   // Parcourir toutes les opportunités et trouver la meilleure
   Print("🔍 PlaceLimitOrder: Évaluation de ", g_opportunitiesCount, " opportunités - Direction marché=", marketDirection == 1 ? "BUY" : "SELL");
   
   for(int i = 0; i < g_opportunitiesCount; i++)
   {
      TradingOpportunity opp = g_opportunities[i];
      bool zoneIsBuy = opp.isBuy;
      
      if(DebugMode)
         Print("🔍 Opportunité #", i, " - Type=", zoneIsBuy ? "BUY" : "SELL",
               " EntryPrice=", DoubleToString(opp.entryPrice, _Digits),
               " PotentialGain=", DoubleToString(opp.percentage, 2), "%");
      
      // Vérifier les restrictions Boom/Crash
      if(isBoom && !zoneIsBuy)
      {
         if(DebugMode)
            Print("⏸️ Opportunité #", i, " ignorée: SELL sur Boom (BUY uniquement)");
         continue; // Skip SELL sur Boom
      }
      if(isCrash && zoneIsBuy)
      {
         if(DebugMode)
            Print("⏸️ Opportunité #", i, " ignorée: BUY sur Crash (SELL uniquement)");
         continue; // Skip BUY sur Crash
      }
      
      // Vérifier que l'opportunité correspond à la direction du marché/prédiction
      // RÈGLE: Pas de SELL LIMIT si marché/prédiction en BUY, pas de BUY LIMIT si marché/prédiction en SELL
      // Si marché/prédiction = BUY → On veut une zone BUY (correction baissière = opportunité d'achat avec BUY LIMIT)
      // Si marché/prédiction = SELL → On veut une zone SELL (correction haussière = opportunité de vente avec SELL LIMIT)
      bool zoneMatchesDirection = false;
      
      if(marketDirection == 1) // Marché/prédiction en BUY
      {
      if(zoneIsBuy)
            zoneMatchesDirection = true; // BUY LIMIT pour correction baissière (opportunité d'achat)
         // Pas de SELL LIMIT si marché en BUY (skip)
      }
      else if(marketDirection == -1) // Marché/prédiction en SELL
      {
         if(!zoneIsBuy)
            zoneMatchesDirection = true; // SELL LIMIT pour correction haussière (opportunité de vente)
         // Pas de BUY LIMIT si marché en SELL (skip)
      }
      
      if(!zoneMatchesDirection)
      {
         Print("⏸️ Opportunité #", i, " ignorée: Type=", zoneIsBuy ? "BUY" : "SELL", 
               " ne correspond pas à la direction marché (", marketDirection == 1 ? "BUY" : "SELL", ")");
         continue; // Skip cette opportunité, elle ne correspond pas à la direction
      }
      
      // Vérifier que le prix d'entrée est réaliste (pas trop loin du prix actuel)
      double priceDistancePercent = MathAbs(opp.entryPrice - currentPrice) / currentPrice * 100.0;
      double maxDistancePercent = 5.0; // Max 5% du prix actuel
      if(priceDistancePercent > maxDistancePercent)
      {
            if(DebugMode)
            Print("⏸️ Opportunité #", i, " ignorée: Prix trop loin (", DoubleToString(priceDistancePercent, 2), "% > ", DoubleToString(maxDistancePercent, 1), "%)");
         continue; // Skip cette opportunité, prix trop loin
      }
      
      // Calculer un score pour cette opportunité
      // PRIORITÉ 1: Confiance du signal (le plus important) - 60%
      // PRIORITÉ 2: Potentiel de gain - 25%
      // PRIORITÉ 3: Proximité - 15%
      // La confiance est le facteur déterminant : on prend toujours l'ordre avec la confiance la plus élevée
      double confidenceScore = g_lastAIConfidence; // Confiance IA (0-1)
      double proximityScore = 1.0 / (1.0 + priceDistancePercent); // Normalisé entre 0 et 1
      double gainScore = MathMin(opp.percentage / 10.0, 1.0); // Normalisé entre 0 et 1 (max 10%)
      
      // Score pondéré : confiance a le plus de poids (60%), puis gain (25%), puis proximité (15%)
      double score = (confidenceScore * 0.60) + (gainScore * 0.25) + (proximityScore * 0.15);
      
      Print("✅ Opportunité #", i, " VALIDE: Type=", zoneIsBuy ? "BUY" : "SELL",
            " EntryPrice=", DoubleToString(opp.entryPrice, _Digits),
            " PotentialGain=", DoubleToString(opp.percentage, 2), "%",
            " Distance=", DoubleToString(priceDistancePercent, 2), "%",
            " Confiance=", DoubleToString(confidenceScore * 100, 1), "%",
            " Score=", DoubleToString(score, 3));
      
      // Garder la meilleure opportunité (priorité au score le plus élevé)
      // Le score inclut déjà la confiance comme facteur principal (60%)
      // Si deux opportunités ont le même score, on garde la première (ou on pourrait utiliser d'autres critères)
      if(!bestFound || score > bestScore)
      {
         bestOpportunity = opp;
         bestFound = true;
         bestScore = score;
         Print("⭐ Meilleure opportunité mise à jour: Confiance=", DoubleToString(confidenceScore * 100, 1), 
               "%, Score=", DoubleToString(bestScore, 3));
      }
   }
   
   // Vérifier qu'on a trouvé une opportunité valide
   if(!bestFound)
   {
      Print("🚫 PlaceLimitOrder: Aucune opportunité valide trouvée parmi ", g_opportunitiesCount, 
            " opportunités - Direction marché=", marketDirection == 1 ? "BUY" : (marketDirection == -1 ? "SELL" : "NEUTRE"),
            " (IA confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%, Prédiction valide=", g_predictionValid ? "OUI" : "NON", ")");
      return;
   }
   
               if(DebugMode)
      Print("✅ Meilleure opportunité sélectionnée: Type=", bestOpportunity.isBuy ? "BUY" : "SELL",
            " EntryPrice=", DoubleToString(bestOpportunity.entryPrice, _Digits),
            " PotentialGain=", DoubleToString(bestOpportunity.percentage, 2), "%",
            " Score=", DoubleToString(bestScore, 3));
   
   // Utiliser la meilleure opportunité trouvée
   double entryPriceRaw = bestOpportunity.entryPrice;
   
   // ===== PLACER L'ORDRE LIMIT LE PLUS PROCHE POSSIBLE DU PRIX ACTUEL =====
   // Rechercher le meilleur niveau (EMA ou S/R) le plus proche du prix actuel en tenant compte de la direction
   double bestLevel = entryPriceRaw; // Par défaut, utiliser le prix de l'opportunité
   double minDistanceToCurrent = MathAbs(entryPriceRaw - currentPrice);
   bool foundBestLevel = false;
   string bestLevelSource = "Opportunité brute";
   
   // Récupérer toutes les EMA pour trouver le meilleur niveau
   double ema50Value = 0, ema100Value = 0, ema200Value = 0;
   double ema50Array[], ema100Array[], ema200Array[];
   ArraySetAsSeries(ema50Array, true);
   ArraySetAsSeries(ema100Array, true);
   ArraySetAsSeries(ema200Array, true);
   
   bool hasEMA50 = (CopyBuffer(ema50Handle, 0, 0, 1, ema50Array) > 0);
   bool hasEMA100 = (CopyBuffer(ema100Handle, 0, 0, 1, ema100Array) > 0);
   bool hasEMA200 = (CopyBuffer(ema200Handle, 0, 0, 1, ema200Array) > 0);
   
   if(hasEMA50) ema50Value = ema50Array[0];
   if(hasEMA100) ema100Value = ema100Array[0];
   if(hasEMA200) ema200Value = ema200Array[0];
   
   // Structure pour stocker les candidats de niveaux
   struct LevelCandidate {
      double price;
      double distance;
      string source;
   };
   
   // Pour BUY LIMIT: chercher le support le plus proche du prix actuel (en-dessous ou égal)
   if(zoneIsBuy)
   {
      // Vérifier toutes les EMA comme support potentiel (doivent être <= prix actuel pour BUY LIMIT)
      LevelCandidate candidates[];
      int candidateCount = 0;
      
      // EMA Fast
      if(hasEMA && emaFastValue > 0 && emaFastValue <= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = emaFastValue;
         candidates[candidateCount].distance = MathAbs(currentPrice - emaFastValue);
         candidates[candidateCount].source = "EMA Fast";
         candidateCount++;
      }
      
      // EMA Slow
      if(hasEMA && emaSlowValue > 0 && emaSlowValue <= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = emaSlowValue;
         candidates[candidateCount].distance = MathAbs(currentPrice - emaSlowValue);
         candidates[candidateCount].source = "EMA Slow";
         candidateCount++;
      }
      
      // EMA 50
      if(hasEMA50 && ema50Value > 0 && ema50Value <= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = ema50Value;
         candidates[candidateCount].distance = MathAbs(currentPrice - ema50Value);
         candidates[candidateCount].source = "EMA 50";
         candidateCount++;
      }
      
      // EMA 100
      if(hasEMA100 && ema100Value > 0 && ema100Value <= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = ema100Value;
         candidates[candidateCount].distance = MathAbs(currentPrice - ema100Value);
         candidates[candidateCount].source = "EMA 100";
         candidateCount++;
      }
      
      // EMA 200
      if(hasEMA200 && ema200Value > 0 && ema200Value <= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = ema200Value;
         candidates[candidateCount].distance = MathAbs(currentPrice - ema200Value);
         candidates[candidateCount].source = "EMA 200";
         candidateCount++;
      }
      
      // Calculer Support S/R basé sur ATR
      double supportLevel = currentPrice - (1.5 * atrValue);
      if(supportLevel > 0 && supportLevel <= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = supportLevel;
         candidates[candidateCount].distance = MathAbs(currentPrice - supportLevel);
         candidates[candidateCount].source = "Support ATR";
         candidateCount++;
      }
      
      // Trouver le niveau le plus proche du prix actuel (mais toujours <= prix actuel pour BUY LIMIT)
      for(int c = 0; c < candidateCount; c++)
      {
         if(candidates[c].distance < minDistanceToCurrent && candidates[c].price <= currentPrice)
         {
            bestLevel = candidates[c].price;
            minDistanceToCurrent = candidates[c].distance;
            bestLevelSource = candidates[c].source;
            foundBestLevel = true;
         }
      }
      
      // Si aucun niveau trouvé mais qu'on a un prix d'opportunité valide, vérifier s'il est plus proche
      if(entryPriceRaw > 0 && entryPriceRaw <= currentPrice && MathAbs(currentPrice - entryPriceRaw) < minDistanceToCurrent)
      {
         bestLevel = entryPriceRaw;
         bestLevelSource = "Opportunité (le plus proche)";
         foundBestLevel = true;
      }
   }
   else // Pour SELL LIMIT: chercher la résistance la plus proche du prix actuel (au-dessus ou égal)
   {
      // Vérifier toutes les EMA comme résistance potentielle (doivent être >= prix actuel pour SELL LIMIT)
      LevelCandidate candidates[];
      int candidateCount = 0;
      
      // EMA Fast
      if(hasEMA && emaFastValue > 0 && emaFastValue >= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = emaFastValue;
         candidates[candidateCount].distance = MathAbs(emaFastValue - currentPrice);
         candidates[candidateCount].source = "EMA Fast";
         candidateCount++;
      }
      
      // EMA Slow
      if(hasEMA && emaSlowValue > 0 && emaSlowValue >= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = emaSlowValue;
         candidates[candidateCount].distance = MathAbs(emaSlowValue - currentPrice);
         candidates[candidateCount].source = "EMA Slow";
         candidateCount++;
      }
      
      // EMA 50
      if(hasEMA50 && ema50Value > 0 && ema50Value >= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = ema50Value;
         candidates[candidateCount].distance = MathAbs(ema50Value - currentPrice);
         candidates[candidateCount].source = "EMA 50";
         candidateCount++;
      }
      
      // EMA 100
      if(hasEMA100 && ema100Value > 0 && ema100Value >= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = ema100Value;
         candidates[candidateCount].distance = MathAbs(ema100Value - currentPrice);
         candidates[candidateCount].source = "EMA 100";
         candidateCount++;
      }
      
      // EMA 200
      if(hasEMA200 && ema200Value > 0 && ema200Value >= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = ema200Value;
         candidates[candidateCount].distance = MathAbs(ema200Value - currentPrice);
         candidates[candidateCount].source = "EMA 200";
         candidateCount++;
      }
      
      // Calculer Résistance S/R basé sur ATR
      double resistanceLevel = currentPrice + (1.5 * atrValue);
      if(resistanceLevel > 0 && resistanceLevel >= currentPrice)
      {
         ArrayResize(candidates, candidateCount + 1);
         candidates[candidateCount].price = resistanceLevel;
         candidates[candidateCount].distance = MathAbs(resistanceLevel - currentPrice);
         candidates[candidateCount].source = "Résistance ATR";
         candidateCount++;
      }
      
      // Trouver le niveau le plus proche du prix actuel (mais toujours >= prix actuel pour SELL LIMIT)
      for(int c = 0; c < candidateCount; c++)
      {
         if(candidates[c].distance < minDistanceToCurrent && candidates[c].price >= currentPrice)
         {
            bestLevel = candidates[c].price;
            minDistanceToCurrent = candidates[c].distance;
            bestLevelSource = candidates[c].source;
            foundBestLevel = true;
         }
      }
      
      // Si aucun niveau trouvé mais qu'on a un prix d'opportunité valide, vérifier s'il est plus proche
      if(entryPriceRaw > 0 && entryPriceRaw >= currentPrice && MathAbs(entryPriceRaw - currentPrice) < minDistanceToCurrent)
      {
         bestLevel = entryPriceRaw;
         bestLevelSource = "Opportunité (le plus proche)";
         foundBestLevel = true;
      }
   }
   
   // Vérifier que le niveau trouvé est réaliste (pas trop loin du prix actuel - max 3%)
   double distancePercent = (MathAbs(bestLevel - currentPrice) / currentPrice) * 100.0;
   if(distancePercent > 3.0)
   {
      // Si trop loin, utiliser le prix d'opportunité s'il est plus proche, sinon ajuster
      if(MathAbs(entryPriceRaw - currentPrice) < MathAbs(bestLevel - currentPrice) && 
         ((zoneIsBuy && entryPriceRaw <= currentPrice) || (!zoneIsBuy && entryPriceRaw >= currentPrice)))
      {
         bestLevel = entryPriceRaw;
         bestLevelSource = "Opportunité (ajusté)";
         Print("⚠️ Ajustement: Niveau trouvé trop loin (", DoubleToString(distancePercent, 2), "%), utilisation prix opportunité");
      }
      else if(distancePercent > 5.0)
      {
         Print("🚫 Niveau trop loin du prix actuel (", DoubleToString(distancePercent, 2), "% > 5%) - Abandon placement");
      return;
      }
   }
   
   double adjustedEntryPrice = bestLevel;
   
   Print("✅ Prix d'entrée ajusté: ", DoubleToString(adjustedEntryPrice, _Digits), 
         " (source: ", bestLevelSource, ", distance du prix actuel: ", DoubleToString(MathAbs(adjustedEntryPrice - currentPrice), _Digits),
         " / ", DoubleToString(distancePercent, 2), "%)");
   
   if(DebugMode)
      Print("✅ Meilleure opportunité sélectionnée: Type=", zoneIsBuy ? "BUY" : "SELL",
            " EntryPrice=", DoubleToString(adjustedEntryPrice, _Digits),
            " PotentialGain=", DoubleToString(bestOpportunity.percentage, 2), "%",
            " Score=", DoubleToString(bestScore, 3),
            " Niveau optimisé trouvé=", foundBestLevel ? "OUI" : "NON");
   
   // ===== CALCULER SL ET TP BASÉS SUR LE PRIX (POURCENTAGE) =====
   // Pour les ordres LIMIT, utiliser des pourcentages du prix d'entrée plutôt que des montants USD fixes
   // Les SL/TP doivent être plus serrés car l'ordre est déjà placé près du prix actuel
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue = (tickValue / tickSize) * point;
   
   double lotSize = NormalizeLotSize(InitialLotSize);
   double sl = 0, tp = 0;
   
   // Vérifier les niveaux minimums du broker
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * point;
   if(minDistance == 0) minDistance = 10 * point;
   
   // Utiliser le prix ajusté (près des EMA/S/R) pour calculer SL et TP
   double entryPrice = NormalizeDouble(adjustedEntryPrice, _Digits);
   
   // Déterminer le type de symbole pour adapter les pourcentages
   bool isBoomCrash = IsBoomCrashSymbol(_Symbol);
   bool isVolatility = IsVolatilitySymbol(_Symbol);
   bool isForex = IsForexSymbol(_Symbol);
   
   // Définir les pourcentages selon le type de symbole et le fait que c'est un ordre LIMIT
   // Pour les ordres LIMIT, on utilise des pourcentages plus serrés (ordre déjà proche du prix)
   double slPercent = 0.0;
   double tpPercent = 0.0;
   
   if(isBoomCrash)
   {
      // Boom/Crash: volatilité élevée, SL serré (0.3-0.5%), TP plus large (1-2%)
      slPercent = 0.004; // 0.4% du prix d'entrée
      tpPercent = 0.015; // 1.5% du prix d'entrée
   }
   else if(isVolatility)
   {
      // Volatility: SL modéré (0.5-1%), TP modéré (1.5-2.5%)
      slPercent = 0.007; // 0.7% du prix d'entrée
      tpPercent = 0.020; // 2.0% du prix d'entrée
   }
   else if(isForex)
   {
      // Forex: SL et TP plus serrés (pip-based généralement)
      slPercent = 0.003; // 0.3% (environ 30-50 pips selon la paire)
      tpPercent = 0.006; // 0.6% (environ 60-100 pips)
   }
   else
   {
      // Autres (Step Index, etc.): valeurs par défaut modérées
      slPercent = 0.005; // 0.5% du prix d'entrée
      tpPercent = 0.012; // 1.2% du prix d'entrée
   }
   
   // Ajuster selon la distance du prix d'entrée au prix actuel
   // Si l'ordre est très proche du prix actuel (< 0.5%), réduire encore les SL/TP
   double distanceFromCurrent = MathAbs(entryPrice - currentPrice) / currentPrice;
   if(distanceFromCurrent < 0.005) // Moins de 0.5% du prix actuel
   {
      slPercent *= 0.7; // Réduire de 30%
      tpPercent *= 0.8; // Réduire de 20%
      if(DebugMode)
         Print("📍 Ordre très proche du prix actuel (", DoubleToString(distanceFromCurrent * 100, 2), "%) - SL/TP réduits");
   }
   
   // Calculer SL et TP en pourcentage du prix d'entrée
   if(zoneIsBuy)
   {
      // BUY LIMIT: SL en-dessous de l'entrée, TP au-dessus
      sl = NormalizeDouble(entryPrice * (1.0 - slPercent), _Digits);
      tp = NormalizeDouble(entryPrice * (1.0 + tpPercent), _Digits);
      
      // Vérifier que les distances respectent le minimum du broker
      double slDistance = entryPrice - sl;
      double tpDistance = tp - entryPrice;
      
      if(slDistance < minDistance)
         sl = NormalizeDouble(entryPrice - minDistance, _Digits);
      if(tpDistance < minDistance)
         tp = NormalizeDouble(entryPrice + minDistance, _Digits);
      
      // Vérifier que SL n'est pas en-dessous d'un support proche (si détecté)
      // Vérifier que TP n'est pas au-dessus d'une résistance proche (si détecté)
      // Ces vérifications peuvent être ajoutées si on a des niveaux S/R détectés
   }
   else
   {
      // SELL LIMIT: SL au-dessus de l'entrée, TP en-dessous
      sl = NormalizeDouble(entryPrice * (1.0 + slPercent), _Digits);
      tp = NormalizeDouble(entryPrice * (1.0 - tpPercent), _Digits);
      
      // Vérifier que les distances respectent le minimum du broker
      double slDistance = sl - entryPrice;
      double tpDistance = entryPrice - tp;
      
      if(slDistance < minDistance)
         sl = NormalizeDouble(entryPrice + minDistance, _Digits);
      if(tpDistance < minDistance)
         tp = NormalizeDouble(entryPrice - minDistance, _Digits);
      
      // Vérifier que SL n'est pas au-dessus d'une résistance proche (si détecté)
      // Vérifier que TP n'est pas en-dessous d'un support proche (si détecté)
   }
   
   // Afficher les distances calculées
   double slDistancePoints = zoneIsBuy ? (entryPrice - sl) : (sl - entryPrice);
   double tpDistancePoints = zoneIsBuy ? (tp - entryPrice) : (entryPrice - tp);
   double slDistancePercent = (slDistancePoints / entryPrice) * 100.0;
   double tpDistancePercent = (tpDistancePoints / entryPrice) * 100.0;
   
   Print("✅ SL/TP calculés (basés sur prix): Entry=", DoubleToString(entryPrice, _Digits),
         " SL=", DoubleToString(sl, _Digits), " (", DoubleToString(slDistancePercent, 2), "% / ", DoubleToString(slDistancePoints, _Digits), " points)",
         " TP=", DoubleToString(tp, _Digits), " (", DoubleToString(tpDistancePercent, 2), "% / ", DoubleToString(tpDistancePoints, _Digits), " points)");
   
   // Vérifier que SL et TP sont réalistes (pas trop éloignés)
   double maxSLPercent = 0.02; // Max 2% pour SL
   double maxTPPercent = 0.05; // Max 5% pour TP
   
   // Recalculer les distances après vérification des minimums broker
   slDistancePoints = zoneIsBuy ? (entryPrice - sl) : (sl - entryPrice);
   tpDistancePoints = zoneIsBuy ? (tp - entryPrice) : (entryPrice - tp);
   slDistancePercent = (slDistancePoints / entryPrice) * 100.0;
   tpDistancePercent = (tpDistancePoints / entryPrice) * 100.0;
   
   if(slDistancePercent > maxSLPercent)
   {
      Print("⚠️ SL trop éloigné (", DoubleToString(slDistancePercent, 2), "% > ", DoubleToString(maxSLPercent * 100, 0), "%) - Ajustement");
      if(zoneIsBuy)
      {
         sl = NormalizeDouble(entryPrice * (1.0 - maxSLPercent), _Digits);
         // Vérifier que le SL respecte toujours le minimum du broker
         if(entryPrice - sl < minDistance)
            sl = NormalizeDouble(entryPrice - minDistance, _Digits);
      }
      else
      {
         sl = NormalizeDouble(entryPrice * (1.0 + maxSLPercent), _Digits);
      if(sl - entryPrice < minDistance)
         sl = NormalizeDouble(entryPrice + minDistance, _Digits);
      }
      // Recalculer après ajustement
      slDistancePoints = zoneIsBuy ? (entryPrice - sl) : (sl - entryPrice);
      slDistancePercent = (slDistancePoints / entryPrice) * 100.0;
   }
   
   if(tpDistancePercent > maxTPPercent)
   {
      Print("⚠️ TP trop éloigné (", DoubleToString(tpDistancePercent, 2), "% > ", DoubleToString(maxTPPercent * 100, 0), "%) - Ajustement");
      if(zoneIsBuy)
      {
         tp = NormalizeDouble(entryPrice * (1.0 + maxTPPercent), _Digits);
         if(tp - entryPrice < minDistance)
            tp = NormalizeDouble(entryPrice + minDistance, _Digits);
      }
      else
      {
         tp = NormalizeDouble(entryPrice * (1.0 - maxTPPercent), _Digits);
      if(entryPrice - tp < minDistance)
         tp = NormalizeDouble(entryPrice - minDistance, _Digits);
      }
      // Recalculer après ajustement
      tpDistancePoints = zoneIsBuy ? (tp - entryPrice) : (entryPrice - tp);
      tpDistancePercent = (tpDistancePoints / entryPrice) * 100.0;
   }
   
   // Afficher les valeurs finales
   Print("✅ SL/TP FINAUX: Entry=", DoubleToString(entryPrice, _Digits),
         " Distance du prix actuel=", DoubleToString(MathAbs(entryPrice - currentPrice) / currentPrice * 100.0, 2), "%",
         " SL=", DoubleToString(sl, _Digits), " (", DoubleToString(slDistancePercent, 2), "% / ", DoubleToString(slDistancePoints, _Digits), " points)",
         " TP=", DoubleToString(tp, _Digits), " (", DoubleToString(tpDistancePercent, 2), "% / ", DoubleToString(tpDistancePoints, _Digits), " points)");
   
   // ===== UN SEUL ORDRE LIMITE PAR SYMBOLE =====
   // Vérifier s'il existe déjà un ordre limite pour ce symbole
   // Ne remplacer que si la confiance du nouveau signal est plus élevée
   double existingConfidence = 0.0;
   bool hasExistingOrder = false;
   ulong existingTicket = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && orderInfo.SelectByIndex(i))
      {
         if(orderInfo.Symbol() == _Symbol && 
            orderInfo.Magic() == InpMagicNumber)
         {
            ENUM_ORDER_TYPE orderType = orderInfo.OrderType();
            // Vérifier si c'est un ordre en attente (LIMIT) pour ce symbole
            if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT)
            {
               hasExistingOrder = true;
               existingTicket = ticket;
               
               // Extraire la confiance du comment de l'ordre existant
               // Format: "LIMIT_IA_PRED_ALIGNED" ou "LIMIT_CONF:XX.XX"
               string comment = orderInfo.Comment();
               int confPos = StringFind(comment, "CONF:");
               if(confPos >= 0)
               {
                  string confStr = StringSubstr(comment, confPos + 5);
                  existingConfidence = StringToDouble(confStr) / 100.0; // Convertir de % à ratio
               }
               else
               {
                  // Si pas de confiance dans le comment, considérer confiance minimale (0.80)
                  // car tous les ordres placés nécessitent au moins 80% de confiance
                  existingConfidence = 0.80;
               }
               
               Print("🔍 Ordre LIMIT existant trouvé: Ticket=", ticket, 
                     " Confiance existante=", DoubleToString(existingConfidence * 100, 1), "%",
                     " Nouvelle confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%");
               
               break; // Un seul ordre limite par symbole
            }
         }
      }
   }
   
   // Si un ordre existe déjà, vérifier si on doit le remplacer
   // On remplace UNIQUEMENT si la nouvelle confiance est plus élevée
   if(hasExistingOrder)
   {
      if(g_lastAIConfidence <= existingConfidence)
      {
         Print("⏸️ Ordre LIMIT existant conservé: Confiance actuelle (", DoubleToString(existingConfidence * 100, 1), 
               "%) >= Nouvelle confiance (", DoubleToString(g_lastAIConfidence * 100, 1), 
               "%) - Remplacer uniquement si confiance plus élevée");
         return; // Ne pas remplacer, garder l'ordre avec la confiance la plus élevée
      }
      else
      {
         // Nouvelle confiance plus élevée, remplacer l'ancien ordre
         Print("🔄 Remplaçant ordre LIMIT: Nouvelle confiance (", DoubleToString(g_lastAIConfidence * 100, 1), 
               "%) > Confiance existante (", DoubleToString(existingConfidence * 100, 1), "%)");
         
         MqlTradeRequest deleteRequest = {};
         MqlTradeResult deleteResult = {};
         deleteRequest.action = TRADE_ACTION_REMOVE;
         deleteRequest.order = existingTicket;
         
         if(OrderSend(deleteRequest, deleteResult))
         {
            Print("🗑️ Ancien ordre LIMIT supprimé (ticket: ", existingTicket, 
                  ") - Remplacé par ordre avec confiance plus élevée");
         }
         else
         {
            Print("⚠️ Erreur suppression ancien ordre LIMIT: ", deleteResult.retcode, " - ", deleteResult.comment);
            return; // Ne pas continuer si on n'a pas pu supprimer l'ancien
         }
      }
   }
   
   // Créer le nouvel ordre limite (les protections Boom/Crash sont déjà vérifiées dans la boucle d'évaluation)
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = zoneIsBuy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   request.price = entryPrice;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = InpMagicNumber;
   // Stocker la confiance dans le comment pour comparaison future
   request.comment = "LIMIT_CONF:" + DoubleToString(g_lastAIConfidence * 100, 2);
   request.type_filling = ORDER_FILLING_FOK;
   request.type_time = ORDER_TIME_SPECIFIED;
   
   // Calculer l'expiration : au minimum dans 1 heure, au maximum 24h
   datetime expirationTime = bestOpportunity.entryTime + 300; // 5 minutes après l'heure prévue
   datetime minExpiration = TimeCurrent() + 3600; // Minimum 1 heure
   datetime maxExpiration = TimeCurrent() + 86400; // Maximum 24 heures
   
   if(expirationTime < minExpiration)
      expirationTime = minExpiration;
   if(expirationTime > maxExpiration)
      expirationTime = maxExpiration;
   
   request.expiration = expirationTime;
   
   if(DebugMode)
      Print("🔍 PlaceLimitOrder: Expiration calculée - EntryTime=", TimeToString(bestOpportunity.entryTime, TIME_DATE|TIME_MINUTES),
            " Expiration=", TimeToString(expirationTime, TIME_DATE|TIME_MINUTES));
   
   // Log avant placement (toujours affiché, pas seulement en debug)
   string levelInfo = foundBestLevel ? " (optimisé: " + bestLevelSource + ")" : " (prix opportunité)";
   Print("📋 Tentative placement ordre LIMIT (MEILLEURE OPPORTUNITÉ): ", EnumToString(request.type), 
         " Prix=", DoubleToString(entryPrice, _Digits), levelInfo,
         " Distance du prix actuel=", DoubleToString(MathAbs(entryPrice - currentPrice), _Digits),
         " SL=", DoubleToString(sl, _Digits), 
         " TP=", DoubleToString(tp, _Digits),
         " Lot=", DoubleToString(lotSize, 2),
         " Gain potentiel=", DoubleToString(bestOpportunity.percentage, 2), "%",
         " Score=", DoubleToString(bestScore, 3),
         " | Direction marché=", marketDirection == 1 ? "BUY" : "SELL",
         " | IA Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%",
         " | Décision finale: ", finalDecision.details);
   
   // ===== VÉRIFICATION FINALE DE LA FORCE DU SIGNAL AVANT EXÉCUTION =====
   // Vérifier que le signal est toujours fort avant de placer l'ordre limite
   if(g_lastAIConfidence < 0.75) // Confiance IA minimum pour ordres limites
   {
      Print("🚫 ORDRE LIMIT ANNULÉ: Confiance IA trop faible (", DoubleToString(g_lastAIConfidence * 100, 1), "% < 75%)");
      return;
   }
   
   // Vérifier que la décision finale est toujours valide
   if(!finalDecision.isValid || finalDecision.confidence < 0.8)
   {
      Print("🚫 ORDRE LIMIT ANNULÉ: Décision finale invalide ou trop faible (Confiance=", DoubleToString(finalDecision.confidence * 100, 1), "% < 80%)");
      return;
   }
   
   if(OrderSend(request, result))
   {
      Print("✅ Ordre LIMIT placé avec succès - MEILLEURE OPPORTUNITÉ: ", EnumToString(request.type), 
            " Prix=", DoubleToString(entryPrice, _Digits), levelInfo,
            " Distance du prix actuel=", DoubleToString(MathAbs(entryPrice - currentPrice), _Digits),
            " SL=", DoubleToString(sl, _Digits), 
            " TP=", DoubleToString(tp, _Digits),
            " Ticket=", result.order,
            " Gain potentiel=", DoubleToString(bestOpportunity.percentage, 2), "%",
            " Score=", DoubleToString(bestScore, 3),
            " | Direction marché=", marketDirection == 1 ? "BUY" : "SELL");
      static datetime lastOrderPlacement = 0;
      static double lastEntryPrice = 0.0;
      lastOrderPlacement = TimeCurrent();
      lastEntryPrice = entryPrice;
   }
   else
   {
      Print("❌ ERREUR placement ordre LIMIT: Code=", result.retcode, " - ", result.comment,
            " | Prix=", DoubleToString(entryPrice, _Digits),
            " | SL=", DoubleToString(sl, _Digits),
            " | TP=", DoubleToString(tp, _Digits),
            " | Type=", EnumToString(request.type));
   }
}

//+------------------------------------------------------------------+
//| Utiliser la prédiction pour améliorer les trades présents        |
//| Ajuster SL/TP en fonction de la direction prédite du prix        |
//+------------------------------------------------------------------+
void UsePredictionForCurrentTrades()
{
   if(!g_predictionValid || ArraySize(g_pricePrediction) < 10)
      return; // Pas de prédiction valide
   
   // Obtenir la direction prédite sur les prochaines 50 bougies (direction à court terme)
   int predictionWindow = MathMin(50, ArraySize(g_pricePrediction));
   if(predictionWindow < 10)
      return;
   
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   double predictedPrice = g_pricePrediction[predictionWindow - 1]; // Prix prédit dans 50 bougies
   
   // Déterminer la direction prédite
   bool predictionBullish = (predictedPrice > currentPrice);
   double priceMovement = MathAbs(predictedPrice - currentPrice);
   double movementPercent = (priceMovement / currentPrice) * 100.0;
   
   // Ne prendre en compte que les prédictions avec un mouvement significatif (> 0.1%)
   if(movementPercent < 0.1)
      return;
   
   // Parcourir toutes les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;
      
      if(!PositionSelectByTicket(ticket))
         continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double positionProfit = PositionGetDouble(POSITION_PROFIT);
      double lotSize = PositionGetDouble(POSITION_VOLUME);
      
      // Calculer la distance du SL actuel
      double slDistance = 0;
      if(currentSL > 0)
      {
         if(posType == POSITION_TYPE_BUY)
            slDistance = openPrice - currentSL;
         else
            slDistance = currentSL - openPrice;
      }
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = _Symbol;
      bool shouldModify = false;
      double newSL = currentSL;
      double newTP = currentTP;
      
      // Si la prédiction va dans le sens de notre position (favorable)
      bool predictionFavorable = ((posType == POSITION_TYPE_BUY && predictionBullish) || 
                                   (posType == POSITION_TYPE_SELL && !predictionBullish));
      
      if(predictionFavorable)
      {
         // Ajuster le SL pour sécuriser plus de profit si la prédiction est favorable
         // Déplacer le SL vers le break-even ou un peu plus haut si on est en profit
         if(positionProfit > 0 && currentSL > 0)
         {
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double minDistance = stopLevel * point;
            if(minDistance == 0) minDistance = 10 * point;
            
            // Déplacer le SL vers le break-even + un petit profit (0.5$)
            double breakEvenPlus = openPrice;
            if(posType == POSITION_TYPE_BUY)
            {
               // Calculer le prix qui donne 0.5$ de profit
               double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
               double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
               double profitNeeded = 0.5;
               double priceMove = (profitNeeded / (lotSize * (tickValue / tickSize) * point));
               double securePrice = openPrice + priceMove;
               
               if(securePrice < currentPrice - minDistance && securePrice > currentSL)
               {
                  newSL = NormalizeDouble(securePrice, _Digits);
                  shouldModify = true;
                  
                  if(DebugMode)
                     Print("📈 Prédiction favorable (Haussière): Ajustement SL pour sécuriser profit - ", 
                           DoubleToString(currentSL, _Digits), " → ", DoubleToString(newSL, _Digits));
               }
            }
            else // SELL
            {
               double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
               double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
               double profitNeeded = 0.5;
               double priceMove = (profitNeeded / (lotSize * (tickValue / tickSize) * point));
               double securePrice = openPrice - priceMove;
               
               if(securePrice > currentPrice + minDistance && (currentSL == 0 || securePrice < currentSL))
               {
                  newSL = NormalizeDouble(securePrice, _Digits);
                  shouldModify = true;
                  
                  if(DebugMode)
                     Print("📉 Prédiction favorable (Baissière): Ajustement SL pour sécuriser profit - ", 
                           DoubleToString(currentSL, _Digits), " → ", DoubleToString(newSL, _Digits));
               }
            }
         }
         
         // Augmenter le TP si la prédiction montre un mouvement plus important
         if(currentTP > 0 && movementPercent > 0.2) // Si mouvement prédit > 0.2%
         {
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double minDistance = stopLevel * point;
            if(minDistance == 0) minDistance = 10 * point;
            
            // Augmenter le TP de 20% du mouvement prédit supplémentaire
            double tpAdjustment = priceMovement * 0.2;
            
            if(posType == POSITION_TYPE_BUY)
            {
               double proposedTP = currentTP + tpAdjustment;
               if(proposedTP > currentTP && proposedTP > currentPrice + minDistance)
               {
                  newTP = NormalizeDouble(proposedTP, _Digits);
                  shouldModify = true;
                  
                  if(DebugMode)
                     Print("📈 Prédiction favorable: Augmentation TP - ", 
                           DoubleToString(currentTP, _Digits), " → ", DoubleToString(newTP, _Digits));
               }
            }
            else // SELL
            {
               double proposedTP = currentTP - tpAdjustment;
               if(proposedTP < currentTP && proposedTP < currentPrice - minDistance)
               {
                  newTP = NormalizeDouble(proposedTP, _Digits);
                  shouldModify = true;
                  
                  if(DebugMode)
                     Print("📉 Prédiction favorable: Augmentation TP - ", 
                           DoubleToString(currentTP, _Digits), " → ", DoubleToString(newTP, _Digits));
               }
            }
         }
      }
      else
      {
         // Prédiction défavorable - sécuriser le profit plus rapidement
         if(positionProfit > 0 && currentSL > 0)
         {
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double minDistance = stopLevel * point;
            if(minDistance == 0) minDistance = 10 * point;
            
            // Rapprocher le SL du prix actuel pour protéger le profit
            if(posType == POSITION_TYPE_BUY)
            {
               double securePrice = currentPrice - (minDistance * 1.5);
               if(securePrice > currentSL && securePrice > openPrice)
               {
                  newSL = NormalizeDouble(securePrice, _Digits);
                  shouldModify = true;
                  
                  if(DebugMode)
                     Print("⚠️ Prédiction défavorable: Protection profit rapprochée - ", 
                           DoubleToString(currentSL, _Digits), " → ", DoubleToString(newSL, _Digits));
               }
            }
            else // SELL
            {
               double securePrice = currentPrice + (minDistance * 1.5);
               if((currentSL == 0 || securePrice < currentSL) && securePrice < openPrice)
               {
                  newSL = NormalizeDouble(securePrice, _Digits);
                  shouldModify = true;
                  
                  if(DebugMode)
                     Print("⚠️ Prédiction défavorable: Protection profit rapprochée - ", 
                           DoubleToString(currentSL, _Digits), " → ", DoubleToString(newSL, _Digits));
               }
            }
         }
      }
      
      // Modifier la position si nécessaire
      if(shouldModify)
      {
         request.sl = newSL;
         request.tp = newTP;
         
         if(OrderSend(request, result))
         {
            if(DebugMode)
               Print("✅ Position ", ticket, " modifiée selon prédiction: SL=", DoubleToString(newSL, _Digits), 
                     " TP=", DoubleToString(newTP, _Digits));
         }
         else
         {
            if(DebugMode)
               Print("❌ Erreur modification position ", ticket, " selon prédiction: ", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier et gérer les positions existantes                       |
//+------------------------------------------------------------------+
void CheckAndManagePositions()
{
   g_hasPosition = false;

   // Fermeture globale Volatility si perte cumulée dépasse 7$
   CloseVolatilityIfLossExceeded(7.0);
   
   // NOUVEAU: Vérifier TOUTES les positions de volatilité pour la limite de perte de $4
   // Doit être fait AVANT la boucle principale pour vérifier tous les symboles
   // Cette vérification fonctionne même si l'EA est attaché à un autre symbole
   for(int j = PositionsTotal() - 1; j >= 0; j--)
   {
      ulong checkTicket = PositionGetTicket(j);
      if(checkTicket > 0 && positionInfo.SelectByTicket(checkTicket))
      {
         if(positionInfo.Magic() == InpMagicNumber)
         {
            string positionSymbol = positionInfo.Symbol();
            bool isVolatilitySymbol = IsVolatilitySymbol(positionSymbol);
            
            if(isVolatilitySymbol)
            {
               double positionProfit = positionInfo.Profit();
               
               // Log de débogage pour voir toutes les positions de volatilité
               if(DebugMode && positionProfit < 0)
                  Print("🔍 Vérification limite perte: ", positionSymbol, " - Profit: ", DoubleToString(positionProfit, 2), "$");
               
               // Fermer immédiatement si perte dépasse $4
               if(positionProfit <= -4.0)
               {
                  Print("🚨 LIMITE ATTEINTE: ", positionSymbol, " - Profit: ", DoubleToString(positionProfit, 2), "$ - Tentative de fermeture...");
                  if(trade.PositionClose(checkTicket))
                  {
                     Print("✅ Position Volatility/Step Index fermée: ", positionSymbol, 
                           " - Perte max atteinte (", DoubleToString(positionProfit, 2), "$ <= -4.00$)");
                  }
                  else
                  {
                     Print("❌ ERREUR fermeture position (limite perte $4): ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription(), 
                           " - Ticket: ", checkTicket, " Symbol: ", positionSymbol, " Profit: ", DoubleToString(positionProfit, 2), "$");
                  }
               }
            }
         }
      }
   }
   
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
            
            // NOUVEAU: Limite de perte de $4 pour Step Index et autres instruments de volatilité
            // Vérifier le symbole de la position, pas le symbole courant de l'EA
            string positionSymbol = positionInfo.Symbol();
            bool isVolatilitySymbol = IsVolatilitySymbol(positionSymbol);
            if(isVolatilitySymbol && currentProfit <= -4.0)
            {
               if(trade.PositionClose(ticket))
               {
                  Print("🛑 Position Volatility/Step Index fermée: ", positionSymbol, 
                        " - Perte max atteinte (", DoubleToString(currentProfit, 2), "$ <= -4.00$)");
                  continue;
               }
               else
               {
                  Print("❌ Erreur fermeture position (limite perte $4): ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription(), 
                        " - Ticket: ", ticket, " Symbol: ", positionSymbol, " Profit: ", DoubleToString(currentProfit, 2), "$");
               }
            }
            
            // NOUVELLE LOGIQUE: Ne pas sécuriser/fermer une position qui a commencé à rentabiliser après une perte
            // Laisser faire au moins 2$ de gain avant de commencer à sécuriser
            // La sécurisation se fera uniquement si le profit >= 2$ ET que le drawdown atteint 50% du profit max
            
            // NOUVELLE LOGIQUE: Fermer si position ouverte > 5 min et pas de gain (perte persistante)
            datetime openTime = (datetime)positionInfo.Time();
            int positionAge = (int)(TimeCurrent() - openTime);
            if(positionAge >= 300 && currentProfit <= 0) // 300 secondes = 5 minutes
            {
               if(trade.PositionClose(ticket))
               {
                  Print("⏰ Position fermée: Ouverte depuis ", positionAge, "s (>= 5 min) sans gain - Profit=", DoubleToString(currentProfit, 2), "$");
                  continue;
               }
            }
            
            // NE PAS fermer automatiquement à 2$ - laisser la position continuer à prendre profit
            // La fermeture se fera seulement si drawdown de 50% après avoir atteint 2$+
            
            // NOUVELLE LOGIQUE: Fermer si IA change en "hold" ou change de direction
            // UNIQUEMENT pour Boom/Crash (pas pour le forex qui doit attendre SL/TP)
            bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
            if(UseAI_Agent && g_lastAIAction != "" && isBoomCrash)
            {
               ENUM_POSITION_TYPE posType = positionInfo.PositionType();
               bool shouldClose = false;
               
               // Si IA recommande "hold", fermer (Boom/Crash uniquement)
               if(g_lastAIAction == "hold")
               {
                  shouldClose = true;
                  if(DebugMode)
                     Print("🔄 Position Boom/Crash fermée: IA recommande maintenant 'ATTENTE' - Recherche meilleure entrée prochainement");
               }
               // Si IA change de direction (BUY -> SELL ou SELL -> BUY) - Boom/Crash uniquement
               else if((posType == POSITION_TYPE_BUY && g_lastAIAction == "sell") ||
                       (posType == POSITION_TYPE_SELL && g_lastAIAction == "buy"))
               {
                  shouldClose = true;
                  if(DebugMode)
                  {
                     string actionUpper = g_lastAIAction;
                     StringToUpper(actionUpper);
                     Print("🔄 Position Boom/Crash fermée: IA change de direction (position ", (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                           " -> IA recommande ", actionUpper, ") - Recherche meilleure entrée prochainement");
                  }
               }
               
               if(shouldClose)
               {
                  // Ne fermer que si le profit est >= 1$ (MIN_PROFIT_TO_CLOSE) ou si c'est une perte
                  if(currentProfit < 0 || currentProfit >= MIN_PROFIT_TO_CLOSE)
               {
                  if(trade.PositionClose(ticket))
                  {
                     Print("✅ Position Boom/Crash fermée suite changement IA: Profit=", DoubleToString(currentProfit, 2), "$");
                     continue;
                     }
                  }
                  else if(DebugMode)
                  {
                     Print("⏸️ Position Boom/Crash conservée suite changement IA: Profit=", DoubleToString(currentProfit, 2), 
                           "$ < minimum requis (", DoubleToString(MIN_PROFIT_TO_CLOSE, 2), "$) - Attendre au moins 1$");
                  }
               }
            }
            
            // Vérifier si on doit doubler le lot (avec confirmations avancées)
            // Réutiliser positionAge déjà calculé plus haut
            int positionAgeForDouble = (int)(TimeCurrent() - g_positionTracker.openTime);
            
            if(!g_positionTracker.lotDoubled && 
               currentProfit >= ProfitThresholdForDouble &&
               positionAgeForDouble >= MinPositionLifetimeSec)
            {
               // NOUVEAU: Vérifier les conditions de retournement avant de doubler
               ENUM_POSITION_TYPE posType = positionInfo.PositionType();
               ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
               
               // Vérifier SuperTrend et patterns de continuation
               double superTrendStrength = 0.0;
               bool superTrendOk = CheckSuperTrendSignal(orderType, superTrendStrength);
               
               // Vérifier pattern de continuation (pas de retournement)
               double reversalConfidence = 0.0;
               bool hasReversal = CheckPatternReversal((orderType == ORDER_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY, reversalConfidence);
               
               // Doubler seulement si:
               // 1. SuperTrend confirme la direction OU
               // 2. Pas de pattern de retournement opposé ET profit > seuil
               bool shouldDouble = false;
               
               if(superTrendOk && superTrendStrength > 0.4)
               {
                  shouldDouble = true;
                  if(DebugMode)
                     Print("✅ Doublage confirmé: SuperTrend confirme direction (Force=", DoubleToString(superTrendStrength, 2), ")");
               }
               else if(!hasReversal && currentProfit >= ProfitThresholdForDouble * 1.5)
               {
                  // Pas de retournement et profit élevé
                  shouldDouble = true;
                  if(DebugMode)
                     Print("✅ Doublage confirmé: Pas de retournement + Profit élevé (", DoubleToString(currentProfit, 2), "$)");
               }
               else if(DebugMode)
               {
                  Print("⏸️ Doublage reporté: SuperTrend=", superTrendOk ? "OK" : "KO", 
                        " Reversal=", hasReversal ? "Détecté" : "Aucun", 
                        " Profit=", DoubleToString(currentProfit, 2), "$");
               }
               
               if(shouldDouble)
               {
                  DoublePositionLot(ticket);
               }
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
   string objectsToKeep[] = {"AI_CONFIDENCE_", "AI_TREND_SUMMARY_", "EMA_Fast_", "EMA_Slow_", "EMA_50_", "EMA_100_", "EMA_200_", 
                              "AI_BUY_", "AI_SELL_", "SR_", "Trend_", "SMC_OB_", "DERIV_ARROW_",
                              "OPPORTUNITIES_PANEL_", "OPP_", "OPPORTUNITIES_TITLE_"};
   
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
//| Dessiner le panneau d'information des opportunités               |
//+------------------------------------------------------------------+
void DrawOpportunitiesPanel()
{
   // Supprimer les anciens labels BUY/SELL qui pourraient encore exister sur le graphique
   int total = ObjectsTotal(0);
   string prefix1 = "PRED_";
   string prefix2 = "PRED_CORRECTION_";
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(name == "")
         continue;
      
      // Supprimer les anciens labels BUY_LABEL, SELL_LABEL et LABEL_ des zones de correction
      if(StringFind(name, prefix1 + "BUY_LABEL_") == 0 || 
         StringFind(name, prefix1 + "SELL_LABEL_") == 0 ||
         StringFind(name, prefix2 + "LABEL_") == 0)
      {
         ObjectDelete(0, name);
      }
   }
   
   // Ne rien afficher si pas d'opportunités - masquer le panneau
   if(g_opportunitiesCount == 0)
   {
      string panelBgName = "OPPORTUNITIES_PANEL_BG_" + _Symbol;
      ObjectDelete(0, panelBgName);
      string titleName = "OPPORTUNITIES_TITLE_" + _Symbol;
      ObjectDelete(0, titleName);
      for(int i = 0; i < 10; i++)
      {
         string oppName = "OPP_" + IntegerToString(i) + "_" + _Symbol;
         ObjectDelete(0, oppName);
      }
      return;
   }
   
   // Trier les opportunités par priorité (pourcentage décroissant) - simple tri à bulles
   for(int i = 0; i < g_opportunitiesCount - 1; i++)
   {
      for(int j = 0; j < g_opportunitiesCount - i - 1; j++)
      {
         if(g_opportunities[j].priority < g_opportunities[j + 1].priority)
         {
            TradingOpportunity temp = g_opportunities[j];
            g_opportunities[j] = g_opportunities[j + 1];
            g_opportunities[j + 1] = temp;
         }
      }
   }
   
   // Limiter à 5 meilleures opportunités pour ne pas encombrer
   int maxDisplay = MathMin(5, g_opportunitiesCount);
   
   // Dimensions du panneau (augmenté pour afficher les prix)
   int panelX = 10;  // Distance depuis le bord droit (sera ajusté dynamiquement)
   int panelY = 80;  // Distance depuis le haut (sous le panneau IA)
   int lineHeight = 18;
   int panelWidth = 280; // Augmenté pour afficher prix + pourcentage
   int panelHeight = (maxDisplay * lineHeight) + 25;
   
   // Calculer la position X depuis le bord droit
   long chartWidth = (long)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   panelX = (int)(chartWidth - panelWidth - 10);
   
   // Créer un fond rectangle semi-transparent
   string panelBgName = "OPPORTUNITIES_PANEL_BG_" + _Symbol;
   if(ObjectFind(0, panelBgName) < 0)
      ObjectCreate(0, panelBgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, panelBgName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, panelBgName, OBJPROP_XDISTANCE, panelX);
   ObjectSetInteger(0, panelBgName, OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, panelBgName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, panelBgName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, panelBgName, OBJPROP_BGCOLOR, C'20,20,30'); // Fond sombre
   ObjectSetInteger(0, panelBgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panelBgName, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, panelBgName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, panelBgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, panelBgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, panelBgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panelBgName, OBJPROP_HIDDEN, true);
   
   // Titre du panneau
   string titleName = "OPPORTUNITIES_TITLE_" + _Symbol;
   if(ObjectFind(0, titleName) < 0)
      ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, panelX + 5);
   ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, panelY + 5);
   ObjectSetString(0, titleName, OBJPROP_TEXT, "Opportunités (" + IntegerToString(maxDisplay) + ")");
   ObjectSetInteger(0, titleName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, titleName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, titleName, OBJPROP_SELECTABLE, false);
   
   // Afficher les opportunités (format compact)
   for(int i = 0; i < maxDisplay; i++)
   {
      string oppName = "OPP_" + IntegerToString(i) + "_" + _Symbol;
      if(ObjectFind(0, oppName) < 0)
         ObjectCreate(0, oppName, OBJ_LABEL, 0, 0, 0);
      
      int yPos = panelY + 25 + (i * lineHeight);
      color oppColor = g_opportunities[i].isBuy ? clrLime : clrRed;
      
      // Format avec prix : Type + Pourcentage + Prix
      string oppText = (g_opportunities[i].isBuy ? "▲ BUY" : "▼ SELL") + "  +" + 
                       DoubleToString(g_opportunities[i].percentage, 1) + "%" +
                       " @ " + DoubleToString(g_opportunities[i].entryPrice, _Digits);
      
      ObjectSetInteger(0, oppName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, oppName, OBJPROP_XDISTANCE, panelX + 5);
      ObjectSetInteger(0, oppName, OBJPROP_YDISTANCE, yPos);
      ObjectSetString(0, oppName, OBJPROP_TEXT, oppText);
      ObjectSetInteger(0, oppName, OBJPROP_COLOR, oppColor);
      ObjectSetInteger(0, oppName, OBJPROP_FONTSIZE, 8); // Légèrement plus petit pour tout afficher
      ObjectSetString(0, oppName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, oppName, OBJPROP_SELECTABLE, false);
   }
   
   // Supprimer les anciennes opportunités qui ne sont plus affichées
   for(int i = maxDisplay; i < 10; i++) // Supprimer jusqu'à 10 (sécurité)
   {
      string oldOppName = "OPP_" + IntegerToString(i) + "_" + _Symbol;
      ObjectDelete(0, oldOppName);
   }
}

//+------------------------------------------------------------------+
//| Dessiner confiance IA et résumés de tendance par timeframe       |
//+------------------------------------------------------------------+
void DrawAIConfidenceAndTrendSummary()
{
   int yOffset = 50; // Déclarer yOffset au début pour être accessible partout
   
   // Label de confiance IA
   string aiLabelName = "AI_CONFIDENCE_" + _Symbol;
   if(ObjectFind(0, aiLabelName) < 0)
      ObjectCreate(0, aiLabelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, aiLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, aiLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, aiLabelName, OBJPROP_YDISTANCE, 30);
   
   string aiText = "IA " + _Symbol + ": ";
   if(g_lastAIAction == "buy")
      aiText += "ACHAT " + DoubleToString(g_lastAIConfidence * 100, 0) + "%";
   else if(g_lastAIAction == "sell")
      aiText += "VENTE " + DoubleToString(g_lastAIConfidence * 100, 0) + "%";
   else
      aiText += "ATTENTE " + DoubleToString(g_lastAIConfidence * 100, 0) + "%";
   
   ObjectSetString(0, aiLabelName, OBJPROP_TEXT, aiText);
   ObjectSetInteger(0, aiLabelName, OBJPROP_COLOR, (g_lastAIAction == "buy") ? clrLime : (g_lastAIAction == "sell") ? clrRed : clrYellow);
   ObjectSetInteger(0, aiLabelName, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, aiLabelName, OBJPROP_FONT, "Arial Bold");
   
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
   
   // ===== NOUVEAU: AFFICHAGE DÉTAILLÉ DE LA COHÉRENCE DE DÉCISION =====
   
   // Récupérer la décision finale pour afficher les détails
   FinalDecisionResult finalDecision;
   bool hasDecision = GetFinalDecision(finalDecision);
   
   // --- PANNEAU DE COHÉRENCE DÉTAILLÉE ---
   string coherenceTitleName = "COHERENCE_TITLE_" + _Symbol;
   if(ObjectFind(0, coherenceTitleName) < 0)
      ObjectCreate(0, coherenceTitleName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, coherenceTitleName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, coherenceTitleName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, coherenceTitleName, OBJPROP_YDISTANCE, 160);
   ObjectSetString(0, coherenceTitleName, OBJPROP_TEXT, "📊 ANALYSE COHÉRENTE - DÉCISION FINALE");
   ObjectSetInteger(0, coherenceTitleName, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, coherenceTitleName, OBJPROP_FONTSIZE, 11);
   ObjectSetString(0, coherenceTitleName, OBJPROP_FONT, "Arial Bold");
   
   yOffset = 180;
   
   // --- DÉCISION FINALE AVEC SCORE DE COHÉRENCE ---
   string finalDecisionName = "FINAL_DECISION_" + _Symbol;
   if(ObjectFind(0, finalDecisionName) < 0)
      ObjectCreate(0, finalDecisionName, OBJ_LABEL, 0, 0, 0);
   
   string finalText = "";
   color finalColor = clrGray;
   
   if(hasDecision && finalDecision.direction != 0)
   {
      string direction = (finalDecision.direction == 1) ? "🟢 BUY FORT" : "🔴 SELL FORT";
      string confidence = DoubleToString(finalDecision.confidence * 100, 1);
      finalText = "Décision: " + direction + " (" + confidence + "%)";
      finalColor = (finalDecision.confidence >= 0.8) ? clrLime : (finalDecision.confidence >= 0.6) ? clrYellow : clrOrange;
   }
   else
   {
      finalText = "Décision: ⚪ EN ATTENTE";
      finalColor = clrGray;
   }
   
   ObjectSetInteger(0, finalDecisionName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, finalDecisionName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, finalDecisionName, OBJPROP_YDISTANCE, yOffset);
   ObjectSetString(0, finalDecisionName, OBJPROP_TEXT, finalText);
   ObjectSetInteger(0, finalDecisionName, OBJPROP_COLOR, finalColor);
   ObjectSetInteger(0, finalDecisionName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, finalDecisionName, OBJPROP_FONT, "Arial Bold");
   
   yOffset += 15;
   
   // --- STABILITÉ DE LA DÉCISION ---
   string stabilityName = "STABILITY_" + _Symbol;
   if(ObjectFind(0, stabilityName) < 0)
      ObjectCreate(0, stabilityName, OBJ_LABEL, 0, 0, 0);
   
   string stabilityText = "";
   color stabilityColor = clrYellow;
   
   if(g_currentDecisionStability.direction != 0)
   {
      int stabilitySeconds = g_currentDecisionStability.stabilitySeconds;
      int requiredSeconds = MinStabilitySeconds;
      
      if(stabilitySeconds >= requiredSeconds)
      {
         stabilityText = "✅ STABILITÉ: " + IntegerToString(stabilitySeconds) + "s (VALIDÉ)";
         stabilityColor = clrLime;
      }
      else
      {
         stabilityText = "⏳ STABILITÉ: " + IntegerToString(stabilitySeconds) + "s/" + IntegerToString(requiredSeconds) + "s";
         stabilityColor = clrYellow;
      }
   }
   else
   {
      stabilityText = "⏱️ STABILITÉ: EN ATTENTE... (Requis: " + IntegerToString(MinStabilitySeconds) + "s)";
      stabilityColor = clrGray;
   }
   
   ObjectSetInteger(0, stabilityName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, stabilityName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, stabilityName, OBJPROP_YDISTANCE, yOffset);
   ObjectSetString(0, stabilityName, OBJPROP_TEXT, stabilityText);
   ObjectSetInteger(0, stabilityName, OBJPROP_COLOR, stabilityColor);
   ObjectSetInteger(0, stabilityName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, stabilityName, OBJPROP_FONT, "Arial");
   
   yOffset += 12;
   
   // --- DÉTAILS DE LA DÉCISION ---
   string detailsName = "DECISION_DETAILS_" + _Symbol;
   if(ObjectFind(0, detailsName) < 0)
      ObjectCreate(0, detailsName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, detailsName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, detailsName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, detailsName, OBJPROP_YDISTANCE, yOffset);
   ObjectSetString(0, detailsName, OBJPROP_TEXT, finalDecision.details);
   ObjectSetInteger(0, detailsName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, detailsName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, detailsName, OBJPROP_FONT, "Arial");
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
      // NOUVELLE LOGIQUE: Ne pas fermer si le trade est en gain et que la correction n'a pas coûté plus de 2$
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
         
         // Calculer la perte depuis le profit maximum atteint
         double profitMaxReached = g_positionTracker.maxProfitReached;
         double correctionLoss = 0.0;
         if(profitMaxReached > 0 && currentProfit < profitMaxReached)
         {
            correctionLoss = profitMaxReached - currentProfit;
         }
         
         // Si le trade est en gain (currentProfit > 0) et que la correction n'a pas coûté plus de 2$, NE PAS FERMER
         if(currentProfit > 0 && correctionLoss <= 2.0)
         {
            if(DebugMode)
               Print("⏸️ Position BUY conservée malgré correction: En gain (", DoubleToString(currentProfit, 2), "$) et correction <= 2$ (", DoubleToString(correctionLoss, 2), "$) - Laisser rejoindre le mouvement normal");
            return; // Ne pas fermer, laisser continuer
         }
         
         // Fermer si perte <= 2$ (limiter les pertes) OU si correction a coûté plus de 2$ depuis le profit max
         // MAIS uniquement si le profit est >= 1$ (MIN_PROFIT_TO_CLOSE) ou si c'est une perte
         if((currentProfit >= -2.0 || (profitMaxReached > 0 && correctionLoss > 2.0)) && 
            (currentProfit < 0 || currentProfit >= MIN_PROFIT_TO_CLOSE))
         {
            if(trade.PositionClose(ticket))
            {
               string reason = (correctionLoss > 2.0) ? "Correction > 2$ depuis profit max" : (currentProfit < 0 ? "Perte <= 2$" : "Profit >= 1$");
               Print("✅ Position BUY fermée: Prix sorti de zone d'achat [", g_aiBuyZoneLow, "-", g_aiBuyZoneHigh, "] et correction détectée (après ", positionAge, "s) - Profit=", DoubleToString(currentProfit, 2), "$ - ", reason);
            }
            else
            {
               if(DebugMode)
                  Print("❌ Erreur fermeture position BUY: ", trade.ResultRetcodeDescription());
            }
         }
         else if(DebugMode && currentProfit > 0 && currentProfit < MIN_PROFIT_TO_CLOSE)
         {
            Print("⏸️ Position BUY conservée: Profit=", DoubleToString(currentProfit, 2), 
                  "$ < minimum requis (", DoubleToString(MIN_PROFIT_TO_CLOSE, 2), "$) - Attendre au moins 1$");
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
      // NOUVELLE LOGIQUE: Ne pas fermer si le trade est en gain et que la correction n'a pas coûté plus de 2$
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
         
         // Calculer la perte depuis le profit maximum atteint
         double profitMaxReached = g_positionTracker.maxProfitReached;
         double correctionLoss = 0.0;
         if(profitMaxReached > 0 && currentProfit < profitMaxReached)
         {
            correctionLoss = profitMaxReached - currentProfit;
         }
         
         // Si le trade est en gain (currentProfit > 0) et que la correction n'a pas coûté plus de 2$, NE PAS FERMER
         if(currentProfit > 0 && correctionLoss <= 2.0)
         {
            if(DebugMode)
               Print("⏸️ Position SELL conservée malgré correction: En gain (", DoubleToString(currentProfit, 2), "$) et correction <= 2$ (", DoubleToString(correctionLoss, 2), "$) - Laisser rejoindre le mouvement normal");
            return; // Ne pas fermer, laisser continuer
         }
         
         // Fermer si perte <= 2$ (limiter les pertes) OU si correction a coûté plus de 2$ depuis le profit max
         // MAIS uniquement si le profit est >= 1$ (MIN_PROFIT_TO_CLOSE) ou si c'est une perte
         if((currentProfit >= -2.0 || (profitMaxReached > 0 && correctionLoss > 2.0)) && 
            (currentProfit < 0 || currentProfit >= MIN_PROFIT_TO_CLOSE))
         {
            if(trade.PositionClose(ticket))
            {
               string reason = (correctionLoss > 2.0) ? "Correction > 2$ depuis profit max" : (currentProfit < 0 ? "Perte <= 2$" : "Profit >= 1$");
               Print("✅ Position SELL fermée: Prix sorti de zone de vente [", g_aiSellZoneLow, "-", g_aiSellZoneHigh, "] et correction détectée (après ", positionAge, "s) - Profit=", DoubleToString(currentProfit, 2), "$ - ", reason);
            }
            else
            {
               if(DebugMode)
                  Print("❌ Erreur fermeture position SELL: ", trade.ResultRetcodeDescription());
            }
         }
         else if(DebugMode && currentProfit > 0 && currentProfit < MIN_PROFIT_TO_CLOSE)
         {
            Print("⏸️ Position SELL conservée: Profit=", DoubleToString(currentProfit, 2), 
                  "$ < minimum requis (", DoubleToString(MIN_PROFIT_TO_CLOSE, 2), "$) - Attendre au moins 1$");
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
   
   // Détecter le spike par mouvement de prix rapide (AMÉLIORÉ)
   bool spikeDetected = false;
   static double g_entryPrice = 0.0;
   
   // Stocker le prix d'entrée au premier appel
   if(g_entryPrice == 0.0)
   {
      g_entryPrice = positionInfo.PriceOpen();
   }
   
   // Méthode 1: Détection par mouvement rapide depuis dernière vérification
   if(g_lastBoomCrashPrice > 0 && (now - g_lastPriceCheck) <= 3) // Vérifier toutes les 3 secondes (plus rapide)
   {
      double priceChange = MathAbs(currentPrice - g_lastBoomCrashPrice);
      double priceChangePercent = (priceChange / g_lastBoomCrashPrice) * 100.0;
      
      // Seuil réduit à 0.3% pour détecter plus tôt
      if(priceChangePercent > 0.3)
      {
         spikeDetected = true;
         Print("🚨 SPIKE DÉTECTÉ (mouvement rapide): ", _Symbol, " - Changement: ", DoubleToString(priceChangePercent, 2), "% en ", (int)(now - g_lastPriceCheck), "s");
      }
   }
   
   // Méthode 2: Détection par mouvement depuis l'entrée (pour BUY: prix monte, pour SELL: prix baisse)
   double entryPriceChange = 0.0;
   if(positionInfo.PositionType() == POSITION_TYPE_BUY)
   {
      entryPriceChange = currentPrice - g_entryPrice;
      double entryPriceChangePercent = (entryPriceChange / g_entryPrice) * 100.0;
      // Si prix a monté de 0.2% depuis l'entrée = spike haussier
      if(entryPriceChangePercent > 0.2 && currentProfit > 0.0)
      {
         spikeDetected = true;
         Print("🚨 SPIKE HAUSSIER DÉTECTÉ (depuis entrée): ", _Symbol, " - Gain: ", DoubleToString(entryPriceChangePercent, 2), "% | Profit: ", DoubleToString(currentProfit, 2), "$");
      }
   }
   else if(positionInfo.PositionType() == POSITION_TYPE_SELL)
   {
      entryPriceChange = g_entryPrice - currentPrice;
      double entryPriceChangePercent = (entryPriceChange / g_entryPrice) * 100.0;
      // Si prix a baissé de 0.2% depuis l'entrée = spike baissier
      if(entryPriceChangePercent > 0.2 && currentProfit > 0.0)
      {
         spikeDetected = true;
         Print("🚨 SPIKE BAISSIER DÉTECTÉ (depuis entrée): ", _Symbol, " - Gain: ", DoubleToString(entryPriceChangePercent, 2), "% | Profit: ", DoubleToString(currentProfit, 2), "$");
      }
   }
   
   g_lastBoomCrashPrice = currentPrice;
   g_lastPriceCheck = now;
   
   // NOUVEAU: Fermer IMMÉDIATEMENT dès qu'il y a un gain positif (même 0.05$)
   // Priorité 1: Si spike détecté ET profit positif -> FERMER IMMÉDIATEMENT
   // Priorité 2: Si profit >= seuil (BoomCrashSpikeTP) -> FERMER IMMÉDIATEMENT
   // Objectif: Sécuriser le gain avant qu'il ne se transforme en perte
   
   bool shouldClose = false;
   string closeReason = "";
   
   // PRIORITÉ 1: Spike détecté + profit positif = FERMER IMMÉDIATEMENT
   if(spikeDetected && currentProfit > 0.0)
   {
      shouldClose = true;
      closeReason = StringFormat("🚨 SPIKE CAPTURÉ - Fermeture immédiate pour sécuriser gain: %.2f$", currentProfit);
   }
   // PRIORITÉ 2: Profit >= seuil minimum (même petit) = FERMER IMMÉDIATEMENT
   else if(currentProfit >= BoomCrashSpikeTP && currentProfit > 0.0)
   {
      shouldClose = true;
      closeReason = StringFormat("💰 PROFIT SÉCURISÉ - Fermeture immédiate: %.2f$ (seuil: %.2f$)", currentProfit, BoomCrashSpikeTP);
   }
   // PRIORITÉ 3: Même un petit gain positif (0.05$+) = FERMER pour éviter la perte
   else if(currentProfit >= 0.05 && currentProfit > 0.0)
   {
      shouldClose = true;
      closeReason = StringFormat("✅ GAIN MINIMAL SÉCURISÉ - Fermeture préventive: %.2f$ (éviter perte)", currentProfit);
   }
   
   if(shouldClose)
   {
      if(trade.PositionClose(ticket))
      {
         Print("🎯 ", closeReason);
         Print("   └─ Position fermée avec succès - Le robot peut revenir si conditions toujours bonnes");
         
         // Réinitialiser le suivi du prix et du prix d'entrée
         g_lastBoomCrashPrice = 0.0;
         g_lastPriceCheck = 0;
         g_entryPrice = 0.0; // Réinitialiser pour la prochaine position
      }
      else
      {
         Print("❌ Erreur fermeture position Boom/Crash: ", trade.ResultRetcode(), 
               " - ", trade.ResultRetcodeDescription());
      }
   }
   else if(DebugMode && currentProfit < 0.0)
   {
      // En perte, attendre le spike ou le retour en profit
      if(spikeDetected)
         Print("⏳ Spike détecté mais position en perte (", DoubleToString(currentProfit, 2), "$) - Attente retour en profit");
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
      {
         double baseTpPoints = TakeProfitUSD / tpValuePerPoint;
         // Ajuster TP selon le style IA si disponible:
         //  - scalp : TP plus court
         //  - swing : TP plus large
         if(g_lastAIStyle == "scalp")
            tpPoints = baseTpPoints * 0.6;
         else if(g_lastAIStyle == "swing")
            tpPoints = baseTpPoints * 1.8;
         else
            tpPoints = baseTpPoints;
      }
   }
   
   // Si le calcul échoue, utiliser des valeurs par défaut basées sur ATR
   if(slPoints <= 0 || tpPoints <= 0)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         // Utiliser 2x ATR pour SL et factoriser TP selon le style
         slPoints = (2.0 * atr[0]) / point;
         double baseAtrTp = (6.0 * atr[0]) / point; // base mouvements longs (ratio 3:1)
         if(g_lastAIStyle == "scalp")
            tpPoints = baseAtrTp * 0.6;
         else if(g_lastAIStyle == "swing")
            tpPoints = baseAtrTp * 1.8;
         else
            tpPoints = baseAtrTp;
      }
      else
      {
         // Valeurs par défaut
         slPoints = 50;
         double baseDefaultTp = 100;
         if(g_lastAIStyle == "scalp")
            tpPoints = baseDefaultTp * 0.6;
         else if(g_lastAIStyle == "swing")
            tpPoints = baseDefaultTp * 1.8;
         else
            tpPoints = baseDefaultTp;
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
               sl = NormalizeDouble(entryPrice - (2.0 * atr[0]), _Digits);
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
               sl = NormalizeDouble(entryPrice + (2.0 * atr[0]), _Digits);
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
         // Utiliser ATR pour calculer des niveaux sûrs (mouvements longs - ratio 3:1)
         double atrMultiplierSL = 2.0;
         double atrMultiplierTP = 6.0; // Augmenté de 4.0 à 6.0 pour cibler les mouvements longs
         
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
         slPoints = maxLossUSD / slValuePerPoint;
      
      // TP standard
      double tpValuePerPoint = lotSize * pointValue;
      if(tpValuePerPoint > 0)
         tpPoints = TakeProfitUSD / tpValuePerPoint;
   }
   
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
            tpPoints = (6.0 * atr[0]) / point; // Augmenté de 4x à 6x pour cibler les mouvements longs
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
      // Pas encore de gains, utiliser le SL standard
      CalculateSLTPInPointsWithMaxLoss(posType, currentPrice, lotSize, 3.0, sl, tp);
      return;
   }
   
   // TP dynamique basé sur le risk/reward
   double risk = MathAbs(currentPrice - sl);
   if(risk > 0)
   {
      double riskRewardRatio = 2.0; // Risk/Reward de 2:1
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(currentPrice + (risk * riskRewardRatio), _Digits);
      else
         tp = NormalizeDouble(currentPrice - (risk * riskRewardRatio), _Digits);
   }
   else
   {
      // Fallback sur TP standard
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
   
   // PROTECTION: Bloquer SELL sur Boom (y compris Vol over Boom) et BUY sur Crash (y compris Vol over Crash)
   // Tous les symboles avec "Boom" = BUY uniquement (spike en tendance)
   // Tous les symboles avec "Crash" = SELL uniquement (spike en tendance)
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(isBoom && orderType == ORDER_TYPE_SELL)
   {
      if(DebugMode)
         Print("🚫 TRADE US BLOQUÉ: Impossible de trader SELL sur ", _Symbol, " (Boom = BUY uniquement pour capturer les spikes en tendance)");
      return false;
   }
   
   if(isCrash && orderType == ORDER_TYPE_BUY)
   {
      if(DebugMode)
         Print("🚫 TRADE US BLOQUÉ: Impossible de trader BUY sur ", _Symbol, " (Crash = SELL uniquement pour capturer les spikes en tendance)");
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
   // ===== PRIORITÉ ABSOLUE: BOOM/CRASH SPIKE CAPTURE =====
   // Cette stratégie est PRIORITAIRE sur toutes les autres
   // Objectif: Capturer les spikes en utilisant EMAs et fractals
   bool isBoomCrash = IsBoomCrashSymbol(_Symbol);
   bool isVolatility = IsVolatilitySymbol(_Symbol);
   
   // PRIORITÉ 1: Boom/Crash et Volatility Indexes (capture de spike)
   if(isBoomCrash || isVolatility)
   {
      ENUM_ORDER_TYPE spikeOrderType = WRONG_VALUE;
      double spikeConfidence = 0.0;
      
      // Détecter opportunité de spike avec EMAs et fractals
      if(DetectBoomCrashSpikeOpportunity(spikeOrderType, spikeConfidence))
      {
         // Vérifier que le serveur IA confirme (si activé)
         bool serverConfirms = true;
         if(UseAI_Agent)
         {
            // Le serveur doit recommander la même direction
            if(g_lastAIAction == "hold" || g_lastAIAction == "")
            {
               if(DebugMode)
                  Print("⏸️ Spike détecté mais serveur IA recommande HOLD - Attente");
               serverConfirms = false;
            }
            else if((spikeOrderType == ORDER_TYPE_BUY && g_lastAIAction != "buy") ||
                    (spikeOrderType == ORDER_TYPE_SELL && g_lastAIAction != "sell"))
            {
               if(DebugMode)
                  Print("⏸️ Spike détecté mais serveur IA recommande direction différente - Attente");
               serverConfirms = false;
            }
            
            // Vérifier confiance minimale (seuil bas pour Boom/Crash - spikes rapides)
            if(g_lastAIConfidence < 0.45)
            {
               if(DebugMode)
                  Print("⏸️ Spike détecté mais confiance serveur insuffisante (", DoubleToString(g_lastAIConfidence * 100, 1), "% < 45%)");
               serverConfirms = false;
            }
         }
         
         if(serverConfirms)
         {
            string symbolType = isBoomCrash ? "Boom/Crash" : "Volatility";
            string direction = (spikeOrderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
            
            Print("🚀 SPIKE ", symbolType, " DÉTECTÉ: ", _Symbol, " - Direction: ", direction, 
                  " | Confiance: ", DoubleToString(spikeConfidence * 100, 1), "%");
            
            // Envoyer notification MT5
            string notificationMsg = StringFormat("🚀 SPIKE %s: %s %s (Conf: %.1f%%)", 
                                                  symbolType, _Symbol, direction, spikeConfidence * 100);
            SendMT5Notification(notificationMsg, true);
            
            // Exécuter le trade immédiatement
            ExecuteTrade(spikeOrderType);
            return; // Sortie immédiate - stratégie prioritaire
         }
      }
   }
   
   // ===== PRIORITÉ 0 - VÉRIFIER LA DÉCISION FINALE CONSOLIDÉE AVEC STABILITÉ =====
   // Si la décision finale est valide (isValid = true avec >= 5 votes alignés), 
   // vérifier qu'elle est stable depuis au moins le délai configuré avant d'exécuter
   if(UseAI_Agent)
   {
      FinalDecisionResult finalDecision;
      bool hasValidDecision = GetFinalDecision(finalDecision);
      datetime currentTime = TimeCurrent();
      
      // Vérifier si la décision finale est valide et a une direction claire
      if(hasValidDecision && finalDecision.isValid && finalDecision.direction != 0)
      {
         // Vérifier si c'est la même décision que la précédente
         bool isSameDecision = (g_currentDecisionStability.direction == finalDecision.direction && 
                                g_currentDecisionStability.isValid == finalDecision.isValid);
         
         if(isSameDecision)
         {
            // Même décision : mettre à jour le timestamp de dernière vue
            g_currentDecisionStability.lastSeen = currentTime;
            g_currentDecisionStability.stabilitySeconds = (int)(currentTime - g_currentDecisionStability.firstSeen);
         }
         else
         {
            // Nouvelle décision ou décision différente : réinitialiser le suivi
            g_currentDecisionStability.direction = finalDecision.direction;
            g_currentDecisionStability.firstSeen = currentTime;
            g_currentDecisionStability.lastSeen = currentTime;
            g_currentDecisionStability.isValid = finalDecision.isValid;
            g_currentDecisionStability.stabilitySeconds = 0;
            
            if(DebugMode)
               Print("🔄 DÉCISION FINALE CHANGÉE: ", (finalDecision.direction == 1 ? "BUY" : "SELL"),
                     " | Réinitialisation du compteur de stabilité (requis: ", MinStabilitySeconds, "s)");
         }
         
         // Vérifier la stabilité : la décision doit être stable depuis au moins le délai configuré
         // ===== NOUVEAU: EXÉCUTION IMMÉDIATE POUR CONFIANCE TRÈS ÉLEVÉE =====
         // Vérifier aussi la confiance ML dans g_lastAIConfidence
         bool isVeryHighConfidence = (finalDecision.confidence >= 0.80) || (g_lastAIConfidence >= 0.80); // 80%+ = exécution immédiate
         // En mode ML haute confiance, réduire le délai de stabilité à 1 seconde (au lieu de MinStabilitySeconds)
         int requiredStabilitySeconds = isVeryHighConfidence ? 1 : MinStabilitySeconds;
         bool canExecuteImmediately = isVeryHighConfidence || (g_currentDecisionStability.stabilitySeconds >= requiredStabilitySeconds);
         
         if(canExecuteImmediately)
         {
            // La décision est stable et valide - exécuter directement
            ENUM_ORDER_TYPE decisionOrderType = (finalDecision.direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            
            // NOUVEAU: Vérifier que le marché est en tendance claire (si TradeOnlyInTrend est activé)
            if(!IsInClearTrend(decisionOrderType))
            {
               if(DebugMode)
                  Print("⏸️ Trade bloqué: Marché en correction ou range (TradeOnlyInTrend activé)");
               return; // Ne pas trader si on n'est pas en tendance claire
            }
            
            Print("⚡ DÉCISION FINALE STABLE ET VALIDE: ", (finalDecision.direction == 1 ? "BUY FORT" : "SELL FORT"),
                  " | Confiance: ", DoubleToString(finalDecision.confidence * 100, 1), "%",
                  " | Stabilité: ", g_currentDecisionStability.stabilitySeconds, "s (requis: ", MinStabilitySeconds, "s)",
                  " | ", finalDecision.details);
            
            if(isVeryHighConfidence)
            {
               double confToShow = MathMax(finalDecision.confidence, g_lastAIConfidence);
               Print("🚀 EXÉCUTION IMMÉDIATE - Confiance très élevée: ", DoubleToString(confToShow * 100, 1), "% >= 80% (ML haute confiance)");
            }
            else
               Print("🚀 EXÉCUTION DIRECTE basée sur décision finale stable (>= ", requiredStabilitySeconds, "s)");
            
            // Envoyer notification MT5
            string decisionMsg = StringFormat("⚡ DÉCISION SERVEUR: %s %s (Conf: %.1f%%)", 
                                              _Symbol, (decisionOrderType == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                                              finalDecision.confidence * 100);
            SendMT5Notification(decisionMsg, true);
            
            ExecuteTrade(decisionOrderType);
            
            // Réinitialiser le suivi après exécution pour éviter les doublons
            g_currentDecisionStability.direction = 0;
            g_currentDecisionStability.firstSeen = 0;
            g_currentDecisionStability.lastSeen = 0;
            g_currentDecisionStability.isValid = false;
            g_currentDecisionStability.stabilitySeconds = 0;
            
            return; // Trade exécuté, sortir
         }
         else
         {
            // Décision pas encore stable - Afficher le temps restant
            int requiredStabilitySeconds = ((finalDecision.confidence >= 0.80) || (g_lastAIConfidence >= 0.80)) ? 1 : MinStabilitySeconds;
            int remainingSeconds = requiredStabilitySeconds - g_currentDecisionStability.stabilitySeconds;
            static datetime lastStabilityLog = 0;
            if(TimeCurrent() - lastStabilityLog >= 30) // Log toutes les 30 secondes
            {
               Print("⏳ DÉCISION FINALE EN ATTENTE DE STABILITÉ: ", (finalDecision.direction == 1 ? "BUY" : "SELL"),
                     " | Confiance: ", DoubleToString(finalDecision.confidence * 100, 1), "%",
                     " | ML Confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%",
                     " | Stabilité: ", g_currentDecisionStability.stabilitySeconds, "s (requis: ", requiredStabilitySeconds, "s)",
                     " | Restant: ", remainingSeconds, "s");
               lastStabilityLog = TimeCurrent();
            }
         }
      }
   }
   
   // PRIORITÉ 1: STRATÉGIE US SESSION BREAK & RETEST (PRIORITAIRE)
   if(UseUSSessionStrategy)
   {
      DefineUSSessionRange();
      
      if(g_US_RangeDefined && IsAfterUSOpening())
      {
         if(!g_US_BreakoutDone)
         {
            int breakout = DetectUSBreakout();
            if(breakout != 0)
            {
               // Breakout détecté, attendre retest - BLOQUER les autres stratégies
               return;
            }
         }
         else
         {
            // Breakout fait, chercher retest
            if(CheckUSRetestAndEnter())
            {
               // Trade pris, sortir
               return;
            }
            else
            {
               // En attente de retest - BLOQUER les autres stratégies jusqu'au retest
               return;
            }
         }
      }
   }
   
   ENUM_ORDER_TYPE signalType = WRONG_VALUE;
   bool hasSignal = false;
   
   // SUPPRIMÉ: Mode prudence - le robot trade normalement
   // SEUIL ADAPTATIF selon le type de symbole
   // Le serveur IA garantit maintenant :
   // - 60% minimum si H1 aligné
   // - 70% minimum si H1+H4/D1 alignés
   // - 55% minimum si M5+H1 alignés
   double requiredConfidence = 0.65; // 65% normalement (augmenté de 60%)
   
   // Détection des types de symboles
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   bool isStepIndex = (StringFind(_Symbol, "Step") != -1 || StringFind(_Symbol, "Step Index") != -1);
   bool isForexSymbol = IsForexSymbol(_Symbol);
   bool isVolatilitySymbol = IsVolatilitySymbol(_Symbol);
   
   // Pour Boom/Crash, seuil plus bas car les spikes sont rapides (50%)
   if(isBoomCrashSymbol)
   {
      requiredConfidence = 0.50; // 50% pour Boom/Crash
   }
   // Pour Step Index et Volatility, seuil minimum 50%
   else if((isStepIndex || isVolatilitySymbol) && !isBoomCrashSymbol)
   {
      requiredConfidence = 0.50; // 50% minimum pour Step Index et Volatility
      if(DebugMode)
         Print("📊 Seuil Step/Volatility appliqué: ", _Symbol, " requiert ", DoubleToString(requiredConfidence * 100, 0), "% (Confiance actuelle: ", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
   }
   // Pour Forex, seuil encore plus élevé (70%) car on doit attendre SL/TP
   else if(isForexSymbol && !isBoomCrashSymbol && !isStepIndex && !isVolatilitySymbol)
   {
      requiredConfidence = 0.70; // 70% pour Forex (signaux plus sûrs requis)
   }
   
   // RÈGLE STRICTE : Si l'IA est activée, TOUJOURS vérifier la confiance AVANT de trader
   if(UseAI_Agent)
   {
      // Si l'IA a une recommandation mais confiance insuffisante, BLOQUER
      if(g_lastAIAction != "" && g_lastAIAction != "hold" && g_lastAIConfidence < requiredConfidence)
      {
         if(DebugMode)
            Print("🚫 TRADE BLOQUÉ: IA recommande ", g_lastAIAction, " mais confiance insuffisante (", DoubleToString(g_lastAIConfidence * 100, 1), "% < ", DoubleToString(requiredConfidence * 100, 1), "%)");
         return; // BLOQUER si confiance insuffisante
      }
      
      // Si l'IA recommande hold/vide, BLOQUER
      if(g_lastAIAction == "hold" || g_lastAIAction == "")
      {
         if(DebugMode)
            Print("⏸️ IA recommande HOLD/ATTENTE - Pas de trade");
         return;
      }
      
      // Si l'IA est en mode fallback, BLOQUER (ne pas utiliser le fallback technique)
      if(g_aiFallbackMode)
      {
         if(DebugMode)
            Print("⚠️ IA en mode fallback - Pas de trade (attente récupération)");
         return;
      }
      
      // Si on arrive ici, l'IA a une recommandation valide avec confiance suffisante
      if(g_lastAIConfidence >= requiredConfidence)
      {
         // Déterminer le type de signal basé sur l'IA
         if(g_lastAIAction == "buy")
            signalType = ORDER_TYPE_BUY;
         else if(g_lastAIAction == "sell")
            signalType = ORDER_TYPE_SELL;
         
         // NOUVEAU: Mode ML haute confiance (≥80%) peut bypasser certaines conditions strictes
         bool isMLHighConfidence = (g_lastAIConfidence >= 0.80);
         bool trendAligned = CheckTrendAlignment(signalType);
         bool reversalAtEMA = DetectReversalAtFastEMA(signalType);
         
         // OBLIGATOIRE: VÉRIFIER L'ALIGNEMENT DES TROIS TIMEFRAMES M1, M5, H1 AVANT DE TRADER
         // EXCEPTION: Si ML confiance ≥80%, on accepte si au moins M1+M5 alignés (H1 optionnel)
         if(signalType != WRONG_VALUE)
         {
            bool canProceed = false;
            string bypassReason = "";
            
            if(isMLHighConfidence)
            {
               // Mode haute confiance ML: conditions assouplies
               // Vérifier au moins l'alignement M1+M5 (H1 optionnel)
               bool m1M5Aligned = CheckM1M5Alignment(signalType);
               
               if(m1M5Aligned)
               {
                  // M1+M5 alignés -> on peut trader même sans H1 ou retournement EMA strict
                  canProceed = true;
                  bypassReason = "ML haute confiance (≥80%) + M1/M5 alignés";
                  
                  if(DebugMode)
                     Print("🚀 MODE ML HAUTE CONFIANCE: ", EnumToString(signalType), " @ ", DoubleToString(g_lastAIConfidence * 100, 1), 
                           "% - Conditions assouplies (M1/M5 alignés, retournement EMA optionnel)");
               }
               else if(trendAligned && reversalAtEMA)
               {
                  // Conditions complètes remplies même en mode haute confiance
                  canProceed = true;
                  bypassReason = "ML haute confiance + toutes conditions remplies";
               }
            }
            else
            {
               // Mode normal: toutes les conditions obligatoires
               if(trendAligned && reversalAtEMA)
               {
                  canProceed = true;
                  bypassReason = "Conditions normales remplies";
               }
            }
            
            if(!canProceed)
            {
               if(DebugMode)
               {
                  if(isMLHighConfidence)
                     Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Même en mode ML haute confiance, alignement M1/M5 minimum requis");
                  else
                     Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Alignement M1/M5/H1 non confirmé ou retournement EMA manquant");
               }
               return;
            }
            
            // Vérifications supplémentaires (momentum/zone) - assouplies en mode ML haute confiance
            {
               double momentumScore = 0.0;
               double zoneStrength = 0.0;
               double currentPrice = (signalType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
               
               if(AnalyzeMomentumPressureZone(signalType, currentPrice, momentumScore, zoneStrength))
               {
                  // Seuils assouplis en mode ML haute confiance
                  double minMomentum = isMLHighConfidence ? 0.3 : 0.5;
                  double minZoneStrength = isMLHighConfidence ? 0.4 : 0.6;
                  
                  if(momentumScore < minMomentum || zoneStrength < minZoneStrength)
                  {
                     if(DebugMode)
                        Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Critères MCS insuffisants (Momentum: ", DoubleToString(momentumScore, 2), 
                              " < ", DoubleToString(minMomentum, 2), " ou Zone: ", DoubleToString(zoneStrength, 2), " < ", DoubleToString(minZoneStrength, 2), ")");
                     return;
                  }
               }
               else if(!isMLHighConfidence)
               {
                  // En mode normal, momentum obligatoire
                  if(DebugMode)
                     Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Momentum insuffisant");
                  return;
               }
               // En mode ML haute confiance, on peut bypasser l'analyse momentum si elle échoue
            }
            
            hasSignal = true;
            
            if(DebugMode)
            {
               if(isMLHighConfidence)
                  Print("✅ Signal ", EnumToString(signalType), " confirmé en MODE ML HAUTE CONFIANCE: ", bypassReason, 
                        " (Confiance IA: ", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
               else
                  Print("✅ Signal ", EnumToString(signalType), " confirmé: Alignement M1/M5/H1 + Retournement EMA rapide M1 avec bougie ", 
                        (signalType == ORDER_TYPE_BUY ? "verte" : "rouge"), " (Confiance IA: ", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
            }

            // SPIKE Boom/Crash : confiance minimum 60% et retournement sur EMA rapide M5
            if(IsBoomCrashSymbol(_Symbol) && g_lastAIConfidence >= 0.60)
            {
               // Vérifier retournement sur EMA rapide M5 et alignement M5/H1
               if(DetectBoomCrashReversalAtEMA(signalType))
               {
                  if(TrySpikeEntry(signalType))
                     return; // spike tenté, ne pas poursuivre
               }
            }
         }
      }
   }
   else
   {
      // IA désactivée : utiliser les indicateurs techniques (fallback uniquement)
      // Récupérer les indicateurs
      double emaFast[], emaSlow[], rsi[];
      ArraySetAsSeries(emaFast, true);
      ArraySetAsSeries(emaSlow, true);
      ArraySetAsSeries(rsi, true);
      
      if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFast) <= 0 ||
         CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlow) <= 0 ||
         CopyBuffer(rsiHandle, 0, 0, 1, rsi) <= 0)
      {
         return;
      }
      
      // Logique de signal basée sur EMA et RSI (fallback SEULEMENT si IA désactivée)
      if(emaFast[0] > emaSlow[0] && rsi[0] > 50 && rsi[0] < 70)
      {
         signalType = ORDER_TYPE_BUY;
         hasSignal = true;
      }
      else if(emaFast[0] < emaSlow[0] && rsi[0] < 50 && rsi[0] > 30)
      {
         signalType = ORDER_TYPE_SELL;
         hasSignal = true;
      }
   }
   
   if(hasSignal)
   {
      ExecuteTrade(signalType);
   }
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
   // Convertir en majuscules pour comparaison insensible à la casse
   string symbolUpper = symbol;
   StringToUpper(symbolUpper);
   
   return (StringFind(symbolUpper, "VOLATILITY") != -1 || 
           StringFind(symbolUpper, "BOOM") != -1 || 
           StringFind(symbolUpper, "CRASH") != -1 ||
           StringFind(symbolUpper, "STEP") != -1);
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
//| Exécuter un trade                                                |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   // PROTECTION: Vérifier la perte totale maximale (5$ toutes positions)
   double totalLoss = GetTotalLoss();
   if(totalLoss >= MaxTotalLoss)
   {
      Print("🚫 TRADE BLOQUÉ: Perte totale maximale atteinte (", DoubleToString(totalLoss, 2), "$ >= ", DoubleToString(MaxTotalLoss, 2), "$) - Éviter trades perdants");
      return;
   }
   
   // PROTECTION: Bloquer SELL sur Boom (y compris Vol over Boom) et BUY sur Crash (y compris Vol over Crash)
   // Tous les symboles avec "Boom" = BUY uniquement (spike en tendance)
   // Tous les symboles avec "Crash" = SELL uniquement (spike en tendance)
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(isBoom && orderType == ORDER_TYPE_SELL)
   {
      Print("🚫 TRADE BLOQUÉ: Impossible de trader SELL sur ", _Symbol, " (Boom = BUY uniquement pour capturer les spikes en tendance)");
      return;
   }
   
   if(isCrash && orderType == ORDER_TYPE_BUY)
   {
      Print("🚫 TRADE BLOQUÉ: Impossible de trader BUY sur ", _Symbol, " (Crash = SELL uniquement pour capturer les spikes en tendance)");
      return;
   }
   
   // Vérifier le nombre maximum de symboles actifs (3 maximum)
   int activeSymbols = CountActiveSymbols();
   int currentSymbolPositions = CountPositionsForSymbolMagic();
   bool isCurrentSymbolActive = (currentSymbolPositions > 0);
   
   // Si on a déjà 3 symboles actifs et que le symbole actuel n'a pas de position, bloquer
   if(activeSymbols >= 3 && !isCurrentSymbolActive)
   {
      Print("🚫 LIMITE SYMBOLES: ", activeSymbols, " symboles actifs (max 3) - Impossible d'ajouter ", _Symbol);
      return;
   }
   
   // NOUVEAU: Vérifier que le marché est en tendance claire (si TradeOnlyInTrend est activé)
   if(TradeOnlyInTrend && !IsInClearTrend(orderType))
   {
      if(DebugMode)
         Print("🚫 TRADE BLOQUÉ: Marché en correction ou range (TradeOnlyInTrend activé) - Attendre tendance claire");
      return;
   }
   
   // Éviter la duplication de la même position (uniquement pour volatility, step index et forex)
   if(HasDuplicatePosition(orderType))
   {
      Print("🚫 Trade ignoré - Position ", EnumToString(orderType), " déjà ouverte sur ", _Symbol, " - Évite la duplication");
      return;
   }
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Normaliser le lot
   double normalizedLot = NormalizeLotSize(InitialLotSize);
   
   if(normalizedLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      Print("❌ Lot trop petit: ", normalizedLot, " (minimum: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), ")");
      return;
   }
   
   double sl, tp;
   ENUM_POSITION_TYPE posType = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   CalculateSLTPInPoints(posType, price, sl, tp);
   
   // VALIDATION FINALE AVANT OUVERTURE: Vérifier que SL et TP sont valides
   if(sl <= 0 || tp <= 0)
   {
      Print("❌ TRADE BLOQUÉ: SL ou TP invalides (SL=", sl, " TP=", tp, ") - Calcul impossible");
      return;
   }
   
   // Vérifier les distances minimum une dernière fois
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minDistance = MathMax(stopLevel * point, tickSize * 3);
   if(minDistance == 0) minDistance = 5 * point;
   
   double slDist = MathAbs(price - sl);
   double tpDist = MathAbs(tp - price);
   
   if(slDist < minDistance || tpDist < minDistance)
   {
      Print("❌ TRADE BLOQUÉ: Distances SL/TP insuffisantes (SL=", DoubleToString(slDist, _Digits), " TP=", DoubleToString(tpDist, _Digits), " min=", DoubleToString(minDistance, _Digits), ")");
      return;
   }
   
   // Normaliser les prix avant ouverture
   price = NormalizeDouble(price, _Digits);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   if(trade.PositionOpen(_Symbol, orderType, normalizedLot, price, sl, tp, "SCALPER_DOUBLE"))
   {
      Print("✅ Trade ouvert: ", EnumToString(orderType), 
            " Lot: ", normalizedLot, 
            " Prix: ", price,
            " SL: ", sl, 
            " TP: ", tp);
      
      // Mettre à jour le tracker
      g_hasPosition = true;
      g_positionTracker.ticket = trade.ResultOrder();
      g_positionTracker.initialLot = normalizedLot;
      g_positionTracker.currentLot = normalizedLot;
      g_positionTracker.highestProfit = 0.0;
      g_positionTracker.lotDoubled = false;
      g_positionTracker.openTime = TimeCurrent();
   }
   else
   {
      Print("❌ Erreur ouverture trade: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Vérifier l'alignement de tendance M5 et H1                       |
//+------------------------------------------------------------------+
bool CheckTrendAlignment(ENUM_ORDER_TYPE orderType)
{
   // OBLIGATOIRE: Vérifier l'alignement des trois timeframes M1, M5 et H1
   // Aucune exception même avec confiance IA élevée
   
   // NOUVEAU: Vérifier d'abord l'API de tendance si activée
   if(UseTrendAPIAnalysis && g_api_trend_valid)
   {
      // Vérifier si la direction de l'API correspond au signal
      bool apiAligned = false;
      if(orderType == ORDER_TYPE_BUY && g_api_trend_direction == 1)
         apiAligned = true;
      else if(orderType == ORDER_TYPE_SELL && g_api_trend_direction == -1)
         apiAligned = true;
      
      // OBLIGATOIRE: API doit être alignée, aucune exception
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
   
   // Récupérer les EMA pour M1, M5 et H1
   double emaFastM1[], emaSlowM1[], emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFastM1) <= 0 ||
      CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlowM1) <= 0 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 1, emaFastM5) <= 0 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 1, emaSlowM5) <= 0 ||
      CopyBuffer(emaFastH1Handle, 0, 0, 1, emaFastH1) <= 0 ||
      CopyBuffer(emaSlowH1Handle, 0, 0, 1, emaSlowH1) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération indicateurs M1/M5/H1");
      return false;
   }
   
   // Vérifier l'alignement pour BUY - OBLIGATOIRE: M1, M5 et H1 tous alignés
   if(orderType == ORDER_TYPE_BUY)
   {
      bool m1Bullish = (emaFastM1[0] > emaSlowM1[0]);
      bool m5Bullish = (emaFastM5[0] > emaSlowM5[0]);
      bool h1Bullish = (emaFastH1[0] > emaSlowH1[0]);
      
      // OBLIGATOIRE: Les trois timeframes doivent être alignés
      if(m1Bullish && m5Bullish && h1Bullish)
      {
         if(DebugMode)
            Print("✅ Alignement haussier confirmé (M1, M5, H1): M1=", m1Bullish ? "UP" : "DOWN", " M5=", m5Bullish ? "UP" : "DOWN", " H1=", h1Bullish ? "UP" : "DOWN");
         return true;
      }
      else
      {
         if(DebugMode)
            Print("❌ Alignement haussier non confirmé: M1=", m1Bullish ? "UP" : "DOWN", " M5=", m5Bullish ? "UP" : "DOWN", " H1=", h1Bullish ? "UP" : "DOWN", " (OBLIGATOIRE: les 3 timeframes alignés)");
         return false;
      }
   }
   // Vérifier l'alignement pour SELL - OBLIGATOIRE: M1, M5 et H1 tous alignés
   else if(orderType == ORDER_TYPE_SELL)
   {
      bool m1Bearish = (emaFastM1[0] < emaSlowM1[0]);
      bool m5Bearish = (emaFastM5[0] < emaSlowM5[0]);
      bool h1Bearish = (emaFastH1[0] < emaSlowH1[0]);
      
      // OBLIGATOIRE: Les trois timeframes doivent être alignés
      if(m1Bearish && m5Bearish && h1Bearish)
      {
         if(DebugMode)
            Print("✅ Alignement baissier confirmé (M1, M5, H1): M1=", m1Bearish ? "DOWN" : "UP", " M5=", m5Bearish ? "DOWN" : "UP", " H1=", h1Bearish ? "DOWN" : "UP");
         return true;
      }
      else
      {
         if(DebugMode)
            Print("❌ Alignement baissier non confirmé: M1=", m1Bearish ? "DOWN" : "UP", " M5=", m5Bearish ? "DOWN" : "UP", " H1=", h1Bearish ? "DOWN" : "UP", " (OBLIGATOIRE: les 3 timeframes alignés)");
         return false;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier l'alignement de tendance M1 et M5 seulement (sans H1) |
//| Utilisé en mode ML haute confiance (≥80%)                        |
//+------------------------------------------------------------------+
bool CheckM1M5Alignment(ENUM_ORDER_TYPE orderType)
{
   // Vérifier seulement M1 et M5 (H1 optionnel en mode ML haute confiance)
   
   // Récupérer les EMA pour M1 et M5
   double emaFastM1[], emaSlowM1[], emaFastM5[], emaSlowM5[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFastM1) <= 0 ||
      CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlowM1) <= 0 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 1, emaFastM5) <= 0 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 1, emaSlowM5) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération indicateurs M1/M5");
      return false;
   }
   
   // Vérifier l'alignement pour BUY - M1 et M5 seulement
   if(orderType == ORDER_TYPE_BUY)
   {
      bool m1Bullish = (emaFastM1[0] > emaSlowM1[0]);
      bool m5Bullish = (emaFastM5[0] > emaSlowM5[0]);
      
      if(m1Bullish && m5Bullish)
      {
         if(DebugMode)
            Print("✅ Alignement M1/M5 haussier confirmé: M1=UP M5=UP (Mode ML haute confiance)");
         return true;
      }
      else
      {
         if(DebugMode)
            Print("❌ Alignement M1/M5 haussier non confirmé: M1=", m1Bullish ? "UP" : "DOWN", " M5=", m5Bullish ? "UP" : "DOWN");
         return false;
      }
   }
   // Vérifier l'alignement pour SELL - M1 et M5 seulement
   else if(orderType == ORDER_TYPE_SELL)
   {
      bool m1Bearish = (emaFastM1[0] < emaSlowM1[0]);
      bool m5Bearish = (emaFastM5[0] < emaSlowM5[0]);
      
      if(m1Bearish && m5Bearish)
      {
         if(DebugMode)
            Print("✅ Alignement M1/M5 baissier confirmé: M1=DOWN M5=DOWN (Mode ML haute confiance)");
         return true;
      }
      else
      {
         if(DebugMode)
            Print("❌ Alignement M1/M5 baissier non confirmé: M1=", m1Bearish ? "DOWN" : "UP", " M5=", m5Bearish ? "DOWN" : "UP");
         return false;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Dessiner les niveaux de support/résistance M5 et H1             |
//+------------------------------------------------------------------+
void DrawSupportResistanceLevels()
{
   double atrM5[], atrH1[];
   ArraySetAsSeries(atrM5, true);
   ArraySetAsSeries(atrH1, true);
   
   if(CopyBuffer(atrM5Handle, 0, 0, 1, atrM5) <= 0 ||
      CopyBuffer(atrH1Handle, 0, 0, 1, atrH1) <= 0)
      return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Support/Résistance M5
   double supportM5 = currentPrice - (2.0 * atrM5[0]);
   double resistanceM5 = currentPrice + (2.0 * atrM5[0]);
   
   // Support/Résistance H1
   double supportH1 = currentPrice - (2.0 * atrH1[0]);
   double resistanceH1 = currentPrice + (2.0 * atrH1[0]);
   
   // Dessiner support M5
   string supportM5Name = "SR_Support_M5_" + _Symbol;
   if(ObjectFind(0, supportM5Name) < 0)
      ObjectCreate(0, supportM5Name, OBJ_HLINE, 0, 0, supportM5);
   else
      ObjectSetDouble(0, supportM5Name, OBJPROP_PRICE, supportM5);
   ObjectSetInteger(0, supportM5Name, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, supportM5Name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, supportM5Name, OBJPROP_WIDTH, 1);
   ObjectSetString(0, supportM5Name, OBJPROP_TEXT, "Support M5");
   
   // Dessiner résistance M5
   string resistanceM5Name = "SR_Resistance_M5_" + _Symbol;
   if(ObjectFind(0, resistanceM5Name) < 0)
      ObjectCreate(0, resistanceM5Name, OBJ_HLINE, 0, 0, resistanceM5);
   else
      ObjectSetDouble(0, resistanceM5Name, OBJPROP_PRICE, resistanceM5);
   ObjectSetInteger(0, resistanceM5Name, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, resistanceM5Name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, resistanceM5Name, OBJPROP_WIDTH, 1);
   ObjectSetString(0, resistanceM5Name, OBJPROP_TEXT, "Résistance M5");
   
   // Dessiner support H1
   string supportH1Name = "SR_Support_H1_" + _Symbol;
   if(ObjectFind(0, supportH1Name) < 0)
      ObjectCreate(0, supportH1Name, OBJ_HLINE, 0, 0, supportH1);
   else
      ObjectSetDouble(0, supportH1Name, OBJPROP_PRICE, supportH1);
   ObjectSetInteger(0, supportH1Name, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, supportH1Name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, supportH1Name, OBJPROP_WIDTH, 2);
   ObjectSetString(0, supportH1Name, OBJPROP_TEXT, "Support H1");
   
   // Dessiner résistance H1
   string resistanceH1Name = "SR_Resistance_H1_" + _Symbol;
   if(ObjectFind(0, resistanceH1Name) < 0)
      ObjectCreate(0, resistanceH1Name, OBJ_HLINE, 0, 0, resistanceH1);
   else
      ObjectSetDouble(0, resistanceH1Name, OBJPROP_PRICE, resistanceH1);
   ObjectSetInteger(0, resistanceH1Name, OBJPROP_COLOR, clrCrimson);
   ObjectSetInteger(0, resistanceH1Name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, resistanceH1Name, OBJPROP_WIDTH, 2);
   ObjectSetString(0, resistanceH1Name, OBJPROP_TEXT, "Résistance H1");
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
         ObjectSetInteger(0, buyZoneName, OBJPROP_BACK, true);  // En arrière-plan
         ObjectSetInteger(0, buyZoneName, OBJPROP_FILL, true); // REMPLI avec transparence
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
         ObjectSetInteger(0, sellZoneName, OBJPROP_BACK, true);  // En arrière-plan
         ObjectSetInteger(0, sellZoneName, OBJPROP_FILL, true); // REMPLI avec transparence
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
   
   // Récupérer les timestamps M5
   if(CopyTime(_Symbol, PERIOD_M5, 0, countM5, timeM5) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération timestamps M5");
      return;
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
   
   // Récupérer les timestamps H1
   if(CopyTime(_Symbol, PERIOD_H1, 0, countH1, timeH1) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération timestamps H1");
      return;
   }
   
   // Trouver les points de début et fin pour M5
   // Avec ArraySetAsSeries=true, index 0 = la plus récente, index count-1 = la plus ancienne
   int startM5 = -1, endM5 = -1;
   
   // Trouver la première valeur valide (la plus récente, index 0)
   for(int i = 0; i < countM5; i++)
   {
      if(emaFastM5[i] > 0 && emaSlowM5[i] > 0)
      {
         if(endM5 == -1) endM5 = i; // Première valeur valide trouvée (la plus récente)
      }
   }
   
   // Trouver la dernière valeur valide (la plus ancienne)
   for(int i = countM5 - 1; i >= 0; i--)
   {
      if(emaFastM5[i] > 0 && emaSlowM5[i] > 0)
      {
         startM5 = i; // Dernière valeur valide (la plus ancienne)
         break;
      }
   }
   
   // Trouver les points de début et fin pour H1
   int startH1 = -1, endH1 = -1;
   
   // Trouver la première valeur valide (la plus récente)
   for(int i = 0; i < countH1; i++)
   {
      if(emaFastH1[i] > 0 && emaSlowH1[i] > 0)
      {
         if(endH1 == -1) endH1 = i; // Première valeur valide trouvée (la plus récente)
      }
   }
   
   // Trouver la dernière valeur valide (la plus ancienne)
   for(int i = countH1 - 1; i >= 0; i--)
   {
      if(emaFastH1[i] > 0 && emaSlowH1[i] > 0)
      {
         startH1 = i; // Dernière valeur valide (la plus ancienne)
         break;
      }
   }
   
   // Dessiner trendline EMA Fast M5 (du point le plus ancien au plus récent)
   if(startM5 >= 0 && endM5 >= 0 && startM5 < countM5 && endM5 < countM5 && startM5 != endM5)
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
   if(startM5 >= 0 && endM5 >= 0 && startM5 < countM5 && endM5 < countM5 && startM5 != endM5)
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
   if(startH1 >= 0 && endH1 >= 0 && startH1 < countH1 && endH1 < countH1 && startH1 != endH1)
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
   if(startH1 >= 0 && endH1 >= 0 && startH1 < countH1 && endH1 < countH1 && startH1 != endH1)
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
//| Dessiner toutes les EMA (Fast, Slow, 50, 100, 200) sur 1000 bougies |
//+------------------------------------------------------------------+
void DrawLongTrendEMA()
{
   if(!ShowLongTrendEMA)
   {
      // Supprimer tous les segments EMA si désactivé
      DeleteEMAObjects("EMA_Fast_");
      DeleteEMAObjects("EMA_Slow_");
      DeleteEMAObjects("EMA_50_");
      DeleteEMAObjects("EMA_100_");
      DeleteEMAObjects("EMA_200_");
      return;
   }
   
   // Récupérer les valeurs EMA sur 1000 bougies
   double emaFast[], emaSlow[], ema50[], ema100[], ema200[];
   datetime time[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(ema50, true);
   ArraySetAsSeries(ema100, true);
   ArraySetAsSeries(ema200, true);
   ArraySetAsSeries(time, true);
   
   // Tracer sur 1000 bougies
   int count = 1000;
   
   // Récupérer toutes les EMA
   bool hasEMAFast = (CopyBuffer(emaFastHandle, 0, 0, count, emaFast) > 0);
   bool hasEMASlow = (CopyBuffer(emaSlowHandle, 0, 0, count, emaSlow) > 0);
   bool hasEMA50 = (CopyBuffer(ema50Handle, 0, 0, count, ema50) > 0);
   bool hasEMA100 = (CopyBuffer(ema100Handle, 0, 0, count, ema100) > 0);
   bool hasEMA200 = (CopyBuffer(ema200Handle, 0, 0, count, ema200) > 0);
   
   if(!hasEMAFast || !hasEMASlow || !hasEMA50 || !hasEMA100 || !hasEMA200)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA - Fast:", hasEMAFast, " Slow:", hasEMASlow, " 50:", hasEMA50, " 100:", hasEMA100, " 200:", hasEMA200);
      return;
   }
   
   // Récupérer les timestamps
   if(CopyTime(_Symbol, PERIOD_M1, 0, count, time) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération timestamps pour EMA");
      return;
   }
   
   // OPTIMISATION: Ne mettre à jour que si nécessaire (toutes les 5 minutes)
   static datetime lastEMAUpdate = 0;
   bool needUpdate = (TimeCurrent() - lastEMAUpdate > 300); // Mise à jour max toutes les 5 minutes
   
   if(needUpdate)
   {
      // Supprimer les anciens segments EMA
      DeleteEMAObjects("EMA_Fast_");
      DeleteEMAObjects("EMA_Slow_");
      DeleteEMAObjects("EMA_50_");
      DeleteEMAObjects("EMA_100_");
      DeleteEMAObjects("EMA_200_");
      
      // Tracer toutes les EMA sur 1000 bougies avec un step de 50 pour performance (20 segments max par EMA)
      // EMA Fast (9 périodes) - Bleu clair
      DrawEMACurveOptimized("EMA_Fast_", emaFast, time, count, clrAqua, 2, 50);
      
      // EMA Slow (21 périodes) - Bleu foncé
      DrawEMACurveOptimized("EMA_Slow_", emaSlow, time, count, clrBlue, 2, 50);
      
      // EMA 50 - Vert clair
      DrawEMACurveOptimized("EMA_50_", ema50, time, count, clrLime, 2, 50);
      
      // EMA 100 - Jaune
      DrawEMACurveOptimized("EMA_100_", ema100, time, count, clrYellow, 2, 50);
      
      // EMA 200 - Orange
      DrawEMACurveOptimized("EMA_200_", ema200, time, count, clrOrange, 2, 50);
      
      Print("✅ EMA tracées sur 1000 bougies: Fast (", EMA_Fast_Period, "), Slow (", EMA_Slow_Period, "), 50, 100, 200");
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
   // Dessiner une courbe EMA sur 1000 bougies avec un step pour performance
   // Step de 50 = environ 20 segments pour 1000 bougies (performance optimale)
   int segmentsDrawn = 0;
   int maxSegments = (count / step) + 1; // Nombre de segments calculé selon le step
   if(maxSegments > 100) maxSegments = 100; // Limiter à 100 segments max pour éviter surcharge
   
   // Parcourir de la bougie la plus récente à la plus ancienne
   for(int i = count - 1; i >= step && segmentsDrawn < maxSegments; i -= step)
   {
      int prevIdx = i - step;
      if(prevIdx < 0) prevIdx = 0;
      
      // Vérifier que les valeurs sont valides
      if(values[i] > 0 && values[prevIdx] > 0 && times[i] > 0 && times[prevIdx] > 0)
      {
         string segName = prefix + _Symbol + "_" + IntegerToString(segmentsDrawn);
         
         // Créer ou mettre à jour le segment de ligne
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
         ObjectSetInteger(0, segName, OBJPROP_BACK, false); // Devant le graphique
         ObjectSetInteger(0, segName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); // Visible sur tous les timeframes
         
         segmentsDrawn++;
      }
   }
   
   if(DebugMode && segmentsDrawn > 0)
      Print("✅ EMA ", prefix, " tracée: ", segmentsDrawn, " segments sur ", count, " bougies");
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
            ObjectSetInteger(0, obName, OBJPROP_BACK, true);
            ObjectSetInteger(0, obName, OBJPROP_FILL, true);
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
            ObjectSetInteger(0, obName, OBJPROP_BACK, true);
            ObjectSetInteger(0, obName, OBJPROP_FILL, true);
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
   
   // NOUVELLE LOGIQUE: Ne pas sécuriser tant que le profit n'atteint pas au moins 2$
   // Laisser la position faire au moins 2$ de gain avant de commencer à sécuriser
   if(currentProfit < 2.0)
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
   
   // Calculer combien on peut perdre depuis le prix actuel tout en gardant le profit sécurisé
   // Si profit actuel = $5 et on veut sécuriser $2.5, on peut perdre max $2.5 depuis le prix actuel
   double maxDrawdownAllowed = profitToSecure;
   
   double pointsToSecure = 0;
   if(pointValue > 0 && lotSize > 0)
   {
      double profitPerPoint = lotSize * pointValue;
      if(profitPerPoint > 0)
         pointsToSecure = maxDrawdownAllowed / profitPerPoint;
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
               pointsToSecure = maxDrawdownAllowed / profitPerATR * (atr[0] / point);
         }
      }
      
      if(pointsToSecure <= 0)
         return; // Impossible de calculer, abandonner
   }
   
   // Calculer le nouveau SL
   // Le SL doit être placé de manière à sécuriser le profit: si le prix descend/monte jusqu'au SL,
   // on garde au moins le profit sécurisé (50% du profit actuel)
   double newSL = 0.0;
   bool shouldUpdate = false;
   
   if(posType == POSITION_TYPE_BUY)
   {
      // BUY: Le SL doit être en-dessous du prix actuel mais au-dessus du prix d'entrée
      // SL = prix actuel - perte max autorisée (pour garder le profit sécurisé)
      newSL = NormalizeDouble(currentPrice - (pointsToSecure * point), _Digits);
      
      // S'assurer que le SL est au-dessus du prix d'entrée (break-even minimum)
      if(newSL < openPrice)
         newSL = NormalizeDouble(openPrice + (point * 1), _Digits); // Break-even + 1 point pour éviter le slippage
      
      // Le nouveau SL doit être meilleur (plus haut) que l'actuel, ou être défini si aucun SL n'existe
      if(currentSL == 0)
      {
         shouldUpdate = true;
      }
      else if(newSL > currentSL && newSL < currentPrice)
      {
         // Le nouveau SL est meilleur (plus haut) que l'actuel et toujours valide (en-dessous du prix actuel)
         shouldUpdate = true;
      }
   }
   else // SELL
   {
      // SELL: Le SL doit être au-dessus du prix actuel mais en-dessous du prix d'entrée
      // SL = prix actuel + perte max autorisée (pour garder le profit sécurisé)
      newSL = NormalizeDouble(currentPrice + (pointsToSecure * point), _Digits);
      
      // S'assurer que le SL est en-dessous du prix d'entrée (break-even minimum)
      if(newSL > openPrice)
         newSL = NormalizeDouble(openPrice - (point * 1), _Digits); // Break-even - 1 point pour éviter le slippage
      
      // Le nouveau SL doit être meilleur (plus bas) que l'actuel, ou être défini si aucun SL n'existe
      if(currentSL == 0)
      {
         shouldUpdate = true;
      }
      else if(newSL < currentSL && newSL > currentPrice)
      {
         // Le nouveau SL est meilleur (plus bas) que l'actuel et toujours valide (au-dessus du prix actuel)
         shouldUpdate = true;
      }
   }
   
   if(!shouldUpdate)
      return; // SL déjà meilleur ou égal
   
   // Vérifier les niveaux minimums du broker
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * point;
   if(minDistance == 0 || minDistance < tickSize)
      minDistance = MathMax(tickSize * 3, 5 * point);
   if(minDistance == 0)
      minDistance = 10 * point; // Fallback final
   
   // Ajuster le SL pour respecter la distance minimum
   if(posType == POSITION_TYPE_BUY)
   {
      // Pour BUY: SL doit être en-dessous du prix actuel d'au moins minDistance
      double maxSL = currentPrice - minDistance;
      if(newSL >= maxSL)
      {
         newSL = NormalizeDouble(maxSL - (point * 1), _Digits);
      }
      // S'assurer que le SL reste au-dessus du prix d'entrée (break-even minimum)
      if(newSL < openPrice)
      {
         double breakEvenSL = NormalizeDouble(openPrice + (point * 1), _Digits);
         double maxAllowedSL = currentPrice - minDistance;
         if(breakEvenSL < maxAllowedSL)
            newSL = breakEvenSL;
         else
         {
            if(DebugMode)
               Print("⏸️ SL sécurisation trop proche du prix actuel pour respecter minDistance (break-even=", 
                     DoubleToString(breakEvenSL, _Digits), " maxAllowed=", DoubleToString(maxAllowedSL, _Digits), ")");
            return; // Impossible de placer le SL correctement
         }
      }
   }
   else // SELL
   {
      // Pour SELL: SL doit être au-dessus du prix actuel d'au moins minDistance
      double minSL = currentPrice + minDistance;
      if(newSL <= minSL)
      {
         newSL = NormalizeDouble(minSL + (point * 1), _Digits);
      }
      // S'assurer que le SL reste en-dessous du prix d'entrée (break-even minimum)
      if(newSL > openPrice)
      {
         double breakEvenSL = NormalizeDouble(openPrice - (point * 1), _Digits);
         double minAllowedSL = currentPrice + minDistance;
         if(breakEvenSL > minAllowedSL)
            newSL = breakEvenSL;
         else
         {
            if(DebugMode)
               Print("⏸️ SL sécurisation trop proche du prix actuel pour respecter minDistance (break-even=", 
                     DoubleToString(breakEvenSL, _Digits), " minAllowed=", DoubleToString(minAllowedSL, _Digits), ")");
            return; // Impossible de placer le SL correctement
         }
      }
   }
   
   // Validation finale du SL
   bool slValid = false;
   if(posType == POSITION_TYPE_BUY)
   {
      slValid = (newSL > 0 && newSL < currentPrice && newSL >= openPrice && 
                 (currentPrice - newSL) >= minDistance);
   }
   else
   {
      slValid = (newSL > 0 && newSL > currentPrice && newSL <= openPrice && 
                 (newSL - currentPrice) >= minDistance);
   }
   
   if(!slValid)
   {
      if(DebugMode)
         Print("⏸️ SL sécurisation invalide après ajustement: newSL=", DoubleToString(newSL, _Digits), 
               " currentPrice=", DoubleToString(currentPrice, _Digits), " openPrice=", DoubleToString(openPrice, _Digits),
               " minDistance=", DoubleToString(minDistance, _Digits));
      return;
   }
   
   // Mettre à jour le SL
   double tp = positionInfo.TakeProfit();
   if(trade.PositionModify(ticket, newSL, tp))
   {
      Print("🔒 Profit sécurisé: SL déplacé pour sécuriser ", DoubleToString(profitToSecure, 2), "$ (50% de ", DoubleToString(currentProfit, 2), "$) - ", 
            (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"), " - Ancien SL: ", 
            (currentSL == 0 ? "Aucun" : DoubleToString(currentSL, _Digits)), 
            " → Nouveau SL: ", DoubleToString(newSL, _Digits), 
            " (Prix actuel: ", DoubleToString(currentPrice, _Digits), ")");
      if(g_positionTracker.ticket == ticket)
         g_positionTracker.profitSecured = true;
   }
   else
   {
      Print("⚠️ Erreur modification SL dynamique: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription(), 
            " - Ticket: ", ticket, " Type: ", (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"),
            " Prix actuel: ", DoubleToString(currentPrice, _Digits), " Nouveau SL: ", DoubleToString(newSL, _Digits),
            " Ancien SL: ", (currentSL == 0 ? "Aucun" : DoubleToString(currentSL, _Digits)));
   }
}

//+------------------------------------------------------------------+
//| Sécurisation dynamique des profits                                |
//| Active dès que le profit total >= 3$                              |
//+------------------------------------------------------------------+
//| Vérifier si c'est une VRAIE correction ou juste une pause        |
//| Retourne true si le retournement est confirmé (EMA + structure)   |
//+------------------------------------------------------------------+
bool IsRealTrendReversal(ulong ticket, ENUM_POSITION_TYPE posType, double currentPrice, double entryPrice)
{
   // 1. Vérifier si les EMA M1, M5, H1 se sont retournées CONTRE notre position
   double emaFastM1[], emaSlowM1[], emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFastM1) < 3 ||
      CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlowM1) < 3 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 3, emaFastM5) < 3 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 3, emaSlowM5) < 3 ||
      CopyBuffer(emaFastH1Handle, 0, 0, 3, emaFastH1) < 3 ||
      CopyBuffer(emaSlowH1Handle, 0, 0, 3, emaSlowH1) < 3)
   {
      // Si on ne peut pas récupérer les EMA, considérer comme pause (pas de vraie correction confirmée)
      return false;
   }
   
   // Pour BUY: vérifier si les EMA sont devenues baissières (vraie correction)
   if(posType == POSITION_TYPE_BUY)
   {
      // Vérifier si M1 et M5 sont devenus baissiers (correction confirmée court terme)
      bool m1Bearish = (emaFastM1[0] < emaSlowM1[0]) && (emaFastM1[1] < emaSlowM1[1]); // 2 bougies consécutives
      bool m5Bearish = (emaFastM5[0] < emaSlowM5[0]);
      
      // VRAIE correction = M1 ET M5 sont baissiers (pas juste M1)
      // Si seulement M1 est baissier mais M5 toujours haussier, c'est juste une pause
      if(m1Bearish && m5Bearish)
      {
         // Vérifier aussi que le prix a vraiment cassé l'EMA rapide M1 vers le bas
         double close[];
         ArraySetAsSeries(close, true);
         if(CopyClose(_Symbol, PERIOD_M1, 0, 3, close) >= 3)
         {
            // Vérifier que les 2-3 dernières bougies sont sous l'EMA rapide M1
            int candlesBelowEMA = 0;
            for(int i = 0; i < 3; i++)
            {
               if(close[i] < emaFastM1[i])
                  candlesBelowEMA++;
            }
            
            // VRAIE correction si au moins 2 bougies sur 3 sont sous l'EMA
            if(candlesBelowEMA >= 2)
            {
               if(DebugMode)
                  Print("🔴 VRAIE correction BUY détectée: M1+M5 baissiers + ", candlesBelowEMA, "/3 bougies sous EMA rapide M1");
               return true;
            }
         }
      }
      
      // Si M1 baissier mais M5 toujours haussier = pause, pas vraie correction
      if(m1Bearish && !m5Bearish)
      {
         if(DebugMode)
            Print("⏸️ Pause BUY (pas vraie correction): M1 baissier mais M5 toujours haussier - Tendance peut continuer");
         return false;
      }
   }
   // Pour SELL: vérifier si les EMA sont devenues haussières (vraie correction)
   else if(posType == POSITION_TYPE_SELL)
   {
      // Vérifier si M1 et M5 sont devenus haussiers (correction confirmée court terme)
      bool m1Bullish = (emaFastM1[0] > emaSlowM1[0]) && (emaFastM1[1] > emaSlowM1[1]); // 2 bougies consécutives
      bool m5Bullish = (emaFastM5[0] > emaSlowM5[0]);
      
      // VRAIE correction = M1 ET M5 sont haussiers (pas juste M1)
      if(m1Bullish && m5Bullish)
      {
         // Vérifier aussi que le prix a vraiment cassé l'EMA rapide M1 vers le haut
         double close[];
         ArraySetAsSeries(close, true);
         if(CopyClose(_Symbol, PERIOD_M1, 0, 3, close) >= 3)
         {
            // Vérifier que les 2-3 dernières bougies sont au-dessus de l'EMA rapide M1
            int candlesAboveEMA = 0;
            for(int i = 0; i < 3; i++)
            {
               if(close[i] > emaFastM1[i])
                  candlesAboveEMA++;
            }
            
            // VRAIE correction si au moins 2 bougies sur 3 sont au-dessus de l'EMA
            if(candlesAboveEMA >= 2)
            {
               if(DebugMode)
                  Print("🔴 VRAIE correction SELL détectée: M1+M5 haussiers + ", candlesAboveEMA, "/3 bougies au-dessus EMA rapide M1");
               return true;
            }
         }
      }
      
      // Si M1 haussier mais M5 toujours baissier = pause, pas vraie correction
      if(m1Bullish && !m5Bullish)
      {
         if(DebugMode)
            Print("⏸️ Pause SELL (pas vraie correction): M1 haussier mais M5 toujours baissier - Tendance peut continuer");
         return false;
      }
   }
   
   // Par défaut, pas de vraie correction (juste une pause)
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si la tendance continue toujours (EMA M1/M5 alignées)   |
//| Retourne true si la tendance est toujours valide pour notre position |
//+------------------------------------------------------------------+
bool IsTrendStillValid(ENUM_POSITION_TYPE posType)
{
   // Récupérer les EMA M1 et M5 pour vérifier si la tendance continue
   double emaFastM1[], emaSlowM1[], emaFastM5[], emaSlowM5[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFastM1) < 2 ||
      CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlowM1) < 2 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 2, emaFastM5) < 2 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 2, emaSlowM5) < 2)
   {
      // Si on ne peut pas récupérer les EMA, considérer comme non valide (prudence)
      return false;
   }
   
   // Pour BUY: vérifier si M1 et M5 sont toujours haussiers
   if(posType == POSITION_TYPE_BUY)
   {
      bool m1Bullish = (emaFastM1[0] > emaSlowM1[0]) && (emaFastM1[1] > emaSlowM1[1]); // 2 bougies consécutives
      bool m5Bullish = (emaFastM5[0] > emaSlowM5[0]);
      
      // Tendance valide si M1 ET M5 sont toujours haussiers
      return (m1Bullish && m5Bullish);
   }
   // Pour SELL: vérifier si M1 et M5 sont toujours baissiers
   else if(posType == POSITION_TYPE_SELL)
   {
      bool m1Bearish = (emaFastM1[0] < emaSlowM1[0]) && (emaFastM1[1] < emaSlowM1[1]); // 2 bougies consécutives
      bool m5Bearish = (emaFastM5[0] < emaSlowM5[0]);
      
      // Tendance valide si M1 ET M5 sont toujours baissiers
      return (m1Bearish && m5Bearish);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Ferme les positions si profit < 50% du profit max                |
//| Sinon, déplace le SL pour sécuriser les profits                  |
//+------------------------------------------------------------------+
void SecureDynamicProfits()
{
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
               
               // Fermer dès que le profit atteint le seuil rapide ET minimum 1$
               if(profit >= VolatilityQuickTP && profit >= MIN_PROFIT_TO_CLOSE)
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
               else if(DebugMode && profit >= VolatilityQuickTP && profit < MIN_PROFIT_TO_CLOSE)
               {
                  Print("⏸️ Volatility: Position conservée - Profit=", DoubleToString(profit, 2), 
                        "$ < minimum requis (", DoubleToString(MIN_PROFIT_TO_CLOSE, 2), "$)");
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
            
            // NOUVELLE LOGIQUE: Ne pas couper une position qui a commencé à rentabiliser après une perte
            // Laisser faire au moins 2$ de gain d'abord
            // C'est seulement lorsque le prix chute à 50% du gain maximum qu'on coupe pour sauvegarder les 50% restant
            
            // Si profit entre 0$ et 2$ - laisser la position continuer sans intervention
            // Juste tracker le profit max pour référence
            if(currentProfit > 0 && currentProfit < 2.0)
            {
               if(currentProfit > maxProfitForPosition)
                  UpdateMaxProfitForPosition(ticket, currentProfit);
               continue; // Ne pas sécuriser tant qu'on n'a pas atteint 2$
            }
            
            // Si profit >= 2$, on peut maintenant tracker et protéger
            if(currentProfit >= 2.0)
            {
               // La position a atteint au moins 2$ de profit, maintenant on peut tracker et protéger
               // Utiliser le profit actuel OU le profit max (le plus élevé)
               double profitReference = MathMax(currentProfit, maxProfitForPosition);
               
               // Si le profit actuel est supérieur au max enregistré, mettre à jour le max
               if(currentProfit > maxProfitForPosition)
               {
                  UpdateMaxProfitForPosition(ticket, currentProfit);
                  profitReference = currentProfit;
               }
               
               // Calculer le drawdown en pourcentage par rapport au profit maximum atteint
               double drawdownPercent = 0.0;
               if(profitReference >= 2.0) // Seulement si le profit max a atteint au moins 2$
               {
                  drawdownPercent = (profitReference - currentProfit) / profitReference;
                  
                  // Si drawdown > 50% ET profit actuel >= 1$ (MIN_PROFIT_TO_CLOSE), fermer pour sauvegarder les 50% restant
                  if(drawdownPercent > PROFIT_DRAWDOWN_LIMIT && currentProfit >= MIN_PROFIT_TO_CLOSE)
                  {
                     // Fermer immédiatement pour sauvegarder les 50% restant du profit maximum
                     if(trade.PositionClose(ticket))
                     {
                        Print("🔒 Position fermée - Drawdown de 50% après avoir atteint au moins 2$: Profit max=", DoubleToString(profitReference, 2), 
                              "$ Profit actuel=", DoubleToString(currentProfit, 2), "$ Drawdown=", DoubleToString(drawdownPercent * 100, 1), 
                              "% - Sauvegarde des 50% restant");
                        continue; // Passer à la position suivante
                     }
                  }
                  else if(DebugMode && drawdownPercent > PROFIT_DRAWDOWN_LIMIT && currentProfit > 0 && currentProfit < MIN_PROFIT_TO_CLOSE)
                  {
                     Print("⏸️ Position conservée malgré drawdown: Profit=", DoubleToString(currentProfit, 2), 
                           "$ < minimum requis (", DoubleToString(MIN_PROFIT_TO_CLOSE, 2), "$)");
                  }
               }
               
               // Si on arrive ici, le profit >= 2$ et drawdown < 50%, continuer avec la sécurisation normale
               
               // NOUVELLE LOGIQUE: Vérifier si la tendance continue avant de sécuriser
               // Si tendance continue, attendre plus de profit avant de sécuriser agressivement
               bool trendStillValid = IsTrendStillValid(posType);
               double securePercentage = 0.50; // 50% par défaut
               
               if(trendStillValid)
               {
                  // Tendances M1/M5 toujours alignées - mouvement peut continuer
                  // Sécuriser moins agressivement (30% au lieu de 50%) pour laisser le mouvement se développer
                  securePercentage = 0.30;
                  if(DebugMode)
                     Print("✅ Tendance toujours valide - Sécurisation modérée (30% au lieu de 50%) pour laisser le mouvement continuer");
               }
               else
               {
                  // Tendance affaiblie - sécuriser plus agressivement (50%)
                  securePercentage = 0.50;
               }
               
               // SÉCURISATION PROGRESSIVE: Déplacer le SL pour sécuriser un pourcentage du profit actuel
               double profitToSecure = currentProfit * securePercentage;
                     
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
                                       " (sécurise ", DoubleToString(profitToSecure, 2), "$ = ", DoubleToString(securePercentage * 100, 0), 
                                       "% de ", DoubleToString(currentProfit, 2), "$", trendStillValid ? " - Tendance continue" : " - Tendance affaiblie", ")");
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
                                       " (sécurise ", DoubleToString(profitToSecure, 2), "$ = ", DoubleToString(securePercentage * 100, 0), 
                                       "% de ", DoubleToString(currentProfit, 2), "$", trendStillValid ? " - Tendance continue" : " - Tendance affaiblie", ")");
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
   
   // PROTECTION: Bloquer SELL sur Boom (y compris Vol over Boom) et BUY sur Crash (y compris Vol over Crash)
   // Tous les symboles avec "Boom" = BUY uniquement (spike en tendance)
   // Tous les symboles avec "Crash" = SELL uniquement (spike en tendance)
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(isBoom && orderType == ORDER_TYPE_SELL)
   {
      if(DebugMode)
         Print("🚫 Boom/Crash: Impossible de trader SELL sur ", _Symbol, " (Boom = BUY uniquement pour capturer les spikes en tendance)");
      return false;
   }
   
   if(isCrash && orderType == ORDER_TYPE_BUY)
   {
      if(DebugMode)
         Print("🚫 Boom/Crash: Impossible de trader BUY sur ", _Symbol, " (Crash = SELL uniquement pour capturer les spikes en tendance)");
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
   
   // PROTECTION: Bloquer SELL sur Boom (y compris Vol over Boom) et BUY sur Crash (y compris Vol over Crash)
   // Tous les symboles avec "Boom" = BUY uniquement (spike en tendance)
   // Tous les symboles avec "Crash" = SELL uniquement (spike en tendance)
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(isBoom && orderType == ORDER_TYPE_SELL)
   {
      if(DebugMode)
         Print("🚫 TrySpikeEntry: Impossible SELL sur Boom (BUY uniquement pour capturer les spikes en tendance)");
      return false;
   }
   
   if(isCrash && orderType == ORDER_TYPE_BUY)
   {
      if(DebugMode)
         Print("🚫 TrySpikeEntry: Impossible BUY sur Crash (SELL uniquement pour capturer les spikes en tendance)");
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
   
   // Récupérer les prix (open, close, high, low) pour vérifier la bougie
   double open[], close[], high[], low[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   if(CopyOpen(_Symbol, PERIOD_M1, 0, 5, open) < 5 ||
      CopyClose(_Symbol, PERIOD_M1, 0, 5, close) < 5 ||
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
   
   // Calculer une tolérance adaptative basée sur ATR ou un pourcentage du prix
   // Pour les prix élevés (>1000), utiliser un pourcentage plutôt qu'un nombre fixe de points
   double tolerance;
   if(emaFast[0] > 1000.0)
   {
      // Pour les prix élevés, utiliser 0.1% du prix (plus tolérant)
      tolerance = emaFast[0] * 0.001; // 0.1% du prix
   }
   else
   {
      // Pour les prix bas, utiliser une tolérance en points ou basée sur ATR
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         tolerance = atr[0] * 0.5; // 0.5x ATR pour tolérance
      }
      else
      {
         tolerance = 10 * point; // Fallback: 10 points
      }
   }
   
   // OBLIGATOIRE: Le prix doit être au niveau de l'EMA rapide M1
   // Vérifier le prix ACTUEL et aussi la bougie fermée (close[0])
   // La bougie peut toucher l'EMA ou le prix actuel peut être proche de l'EMA
   bool priceAtEMA = (currentPrice >= (emaFast[0] - tolerance) && currentPrice <= (emaFast[0] + tolerance)) || // Prix actuel proche
                     (close[0] >= (emaFast[0] - tolerance) && close[0] <= (emaFast[0] + tolerance)) || // Close proche
                     (low[0] <= emaFast[0] && high[0] >= emaFast[0]) || // La bougie fermée traverse l'EMA
                     (MathAbs(currentPrice - emaFast[0]) <= tolerance); // Distance actuelle acceptable
   
   if(!priceAtEMA)
   {
      double distancePoints = MathAbs(currentPrice - emaFast[0]) / point;
      double distancePercent = (MathAbs(currentPrice - emaFast[0]) / emaFast[0]) * 100.0;
      if(DebugMode)
         Print("⏸️ Prix pas au niveau EMA rapide M1: currentPrice=", DoubleToString(currentPrice, _Digits), 
               " close[0]=", DoubleToString(close[0], _Digits), " EMA=", DoubleToString(emaFast[0], _Digits), 
               " (distance: ", DoubleToString(distancePoints, 1), " points / ", DoubleToString(distancePercent, 3), "%, tolérance: ", DoubleToString(tolerance, _Digits), ")");
      return false;
   }
   
   // Pour BUY: Détecter rebond haussier confirmé par bougie verte
   if(orderType == ORDER_TYPE_BUY)
   {
      // OBLIGATOIRE: La bougie actuelle (bougie 0) doit être VERTE (close > open) OU le prix actuel monte vers l'EMA
      // Si la bougie fermée n'est pas verte mais le prix actuel est au-dessus de l'open et proche de l'EMA, accepter
      bool isGreenCandle = (close[0] > open[0]);
      bool isFormingGreen = (!isGreenCandle && currentPrice > open[0] && currentPrice > close[0]); // Bougie en cours de formation haussière
      
      if(!isGreenCandle && !isFormingGreen)
      {
         if(DebugMode)
            Print("⏸️ Retournement BUY rejeté: Bougie actuelle n'est pas verte (close=", DoubleToString(close[0], _Digits), 
                  " open=", DoubleToString(open[0], _Digits), " currentPrice=", DoubleToString(currentPrice, _Digits), ")");
         return false;
      }
      
      // Vérifier que le prix a baissé puis rebondi (retournement)
      // Les bougies précédentes doivent montrer une baisse vers l'EMA
      bool wasDown = false;
      if(close[1] < emaFast[1] || close[2] < emaFast[2] || low[1] < emaFast[1] || low[2] < emaFast[2])
         wasDown = true;
      
      // La bougie verte doit montrer un rebond (close actuel > close précédent OU la bougie touche l'EMA depuis le bas)
      // OU le prix actuel montre un rebond (currentPrice > close[0] et proche de l'EMA)
      bool isRebounding = (close[0] > close[1]) || (low[0] <= emaFast[0] && close[0] >= emaFast[0]) || 
                         (isFormingGreen && currentPrice > close[0] && currentPrice >= (emaFast[0] - tolerance));
      
      bool candleConfirmed = isGreenCandle || isFormingGreen;
      
      if(wasDown && isRebounding && candleConfirmed && priceAtEMA)
      {
         if(DebugMode)
            Print("✅ Retournement BUY confirmé: ", (isGreenCandle ? "Bougie verte" : "Bougie en formation haussière"), 
                  " au niveau EMA rapide M1 (close=", DoubleToString(close[0], _Digits), " open=", DoubleToString(open[0], _Digits), 
                  " currentPrice=", DoubleToString(currentPrice, _Digits), " EMA=", DoubleToString(emaFast[0], _Digits), ")");
         return true;
      }
      else
      {
         if(DebugMode)
            Print("⏸️ Retournement BUY non confirmé: wasDown=", wasDown, " isRebounding=", isRebounding, 
                  " isGreenCandle=", isGreenCandle, " isFormingGreen=", isFormingGreen, " priceAtEMA=", priceAtEMA);
      }
   }
   // Pour SELL: Détecter rebond baissier confirmé par bougie rouge
   else if(orderType == ORDER_TYPE_SELL)
   {
      // OBLIGATOIRE: La bougie actuelle (bougie 0) doit être ROUGE (close < open) OU le prix actuel descend vers l'EMA
      // Si la bougie fermée n'est pas rouge mais le prix actuel est en-dessous de l'open et proche de l'EMA, accepter
      bool isRedCandle = (close[0] < open[0]);
      bool isFormingRed = (!isRedCandle && currentPrice < open[0] && currentPrice < close[0]); // Bougie en cours de formation baissière
      
      if(!isRedCandle && !isFormingRed)
      {
         if(DebugMode)
            Print("⏸️ Retournement SELL rejeté: Bougie actuelle n'est pas rouge (close=", DoubleToString(close[0], _Digits), 
                  " open=", DoubleToString(open[0], _Digits), " currentPrice=", DoubleToString(currentPrice, _Digits), ")");
         return false;
      }
      
      // Vérifier que le prix a monté puis rebondi à la baisse (retournement)
      // Les bougies précédentes doivent montrer une hausse vers l'EMA
      bool wasUp = false;
      if(close[1] > emaFast[1] || close[2] > emaFast[2] || high[1] > emaFast[1] || high[2] > emaFast[2])
         wasUp = true;
      
      // La bougie rouge doit montrer un rebond baissier (close actuel < close précédent OU la bougie touche l'EMA depuis le haut)
      // OU le prix actuel montre un rebond baissier (currentPrice < close[0] et proche de l'EMA)
      bool isRebounding = (close[0] < close[1]) || (high[0] >= emaFast[0] && close[0] <= emaFast[0]) || 
                         (isFormingRed && currentPrice < close[0] && currentPrice <= (emaFast[0] + tolerance));
      
      bool candleConfirmed = isRedCandle || isFormingRed;
      
      if(wasUp && isRebounding && candleConfirmed && priceAtEMA)
      {
         if(DebugMode)
            Print("✅ Retournement SELL confirmé: ", (isRedCandle ? "Bougie rouge" : "Bougie en formation baissière"), 
                  " au niveau EMA rapide M1 (close=", DoubleToString(close[0], _Digits), " open=", DoubleToString(open[0], _Digits), 
                  " currentPrice=", DoubleToString(currentPrice, _Digits), " EMA=", DoubleToString(emaFast[0], _Digits), ")");
         return true;
      }
      else
      {
         if(DebugMode)
            Print("⏸️ Retournement SELL non confirmé: wasUp=", wasUp, " isRebounding=", isRebounding, 
                  " isRedCandle=", isRedCandle, " isFormingRed=", isFormingRed, " priceAtEMA=", priceAtEMA);
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
//| Calculer le SuperTrend (indicateur de tendance)                  |
//| Retourne: true si signal valide, strength = force du signal (0-1) |
//+------------------------------------------------------------------+
bool CheckSuperTrendSignal(ENUM_ORDER_TYPE orderType, double &strength)
{
   strength = 0.0;
   
   // Récupérer ATR et prix
   double atr[];
   double high[], low[], close[];
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(CopyBuffer(atrHandle, 0, 0, 2, atr) < 2 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 2, high) < 2 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 2, low) < 2 ||
      CopyClose(_Symbol, PERIOD_M1, 0, 2, close) < 2)
      return false;
   
   // Calculer le SuperTrend (méthode simplifiée)
   // Basic Upper Band = (High + Low) / 2 + (Multiplier * ATR)
   // Basic Lower Band = (High + Low) / 2 - (Multiplier * ATR)
   double multiplier = 2.0;
   double hl2 = (high[0] + low[0]) / 2.0;
   double upperBand = hl2 + (multiplier * atr[0]);
   double lowerBand = hl2 - (multiplier * atr[0]);
   
   // Déterminer la tendance
   bool isUptrend = (close[0] > lowerBand);
   bool wasUptrend = (close[1] > (hl2 - (multiplier * atr[1])));
   
   // Vérifier le signal selon l'ordre
   if(orderType == ORDER_TYPE_BUY)
   {
      // Signal BUY: passage de downtrend à uptrend OU uptrend confirmé
      if(isUptrend && (!wasUptrend || close[0] > close[1]))
      {
         // Calculer la force: distance du prix au SuperTrend
         double distance = (close[0] - lowerBand) / atr[0];
         strength = MathMin(distance / 2.0, 1.0); // Normaliser entre 0 et 1
         return true;
      }
   }
   else // SELL
   {
      // Signal SELL: passage de uptrend à downtrend OU downtrend confirmé
      if(!isUptrend && (wasUptrend || close[0] < close[1]))
      {
         // Calculer la force: distance du prix au SuperTrend
         double distance = (upperBand - close[0]) / atr[0];
         strength = MathMin(distance / 2.0, 1.0); // Normaliser entre 0 et 1
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier rebond sur support/résistance                          |
//| Retourne: true si rebond confirmé, reboundStrength = force (0-1) |
//+------------------------------------------------------------------+
bool CheckSupportResistanceRebound(ENUM_ORDER_TYPE orderType, double &reboundStrength)
{
   reboundStrength = 0.0;
   
   // Récupérer les niveaux de support/résistance (basés sur ATR)
   double atrM5[], atrH1[];
   ArraySetAsSeries(atrM5, true);
   ArraySetAsSeries(atrH1, true);
   
   if(CopyBuffer(atrM5Handle, 0, 0, 1, atrM5) <= 0 ||
      CopyBuffer(atrH1Handle, 0, 0, 1, atrH1) <= 0)
      return false;
   
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Calculer les niveaux de support/résistance
   double supportM5 = currentPrice - (2.0 * atrM5[0]);
   double resistanceM5 = currentPrice + (2.0 * atrM5[0]);
   double supportH1 = currentPrice - (2.0 * atrH1[0]);
   double resistanceH1 = currentPrice + (2.0 * atrH1[0]);
   
   // Récupérer les prix historiques pour détecter le rebond
   double close[], low[], high[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(high, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 5, close) < 5 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 5, low) < 5 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 5, high) < 5)
      return false;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      // Pour BUY: vérifier rebond sur support
      // Le prix doit avoir touché le support (M5 ou H1) et rebondir
      double tolerance = 5 * _Point;
      
      // Vérifier rebond sur support M5
      bool touchedSupportM5 = (low[0] <= supportM5 + tolerance || low[1] <= supportM5 + tolerance);
      bool rebounding = (close[0] > close[1] && close[1] > close[2]);
      
      if(touchedSupportM5 && rebounding)
      {
         // Calculer la force: distance du rebond
         double reboundDistance = (close[0] - MathMin(low[0], low[1])) / atrM5[0];
         reboundStrength = MathMin(reboundDistance / 1.5, 1.0);
         return true;
      }
      
      // Vérifier rebond sur support H1 (plus fort)
      bool touchedSupportH1 = (low[0] <= supportH1 + tolerance || low[1] <= supportH1 + tolerance);
      if(touchedSupportH1 && rebounding)
      {
         double reboundDistance = (close[0] - MathMin(low[0], low[1])) / atrH1[0];
         reboundStrength = MathMin(reboundDistance / 1.5, 1.0) * 1.2; // Bonus pour H1
         reboundStrength = MathMin(reboundStrength, 1.0);
         return true;
      }
   }
   else // SELL
   {
      // Pour SELL: vérifier rebond sur résistance
      double tolerance = 5 * _Point;
      
      // Vérifier rebond sur résistance M5
      bool touchedResistanceM5 = (high[0] >= resistanceM5 - tolerance || high[1] >= resistanceM5 - tolerance);
      bool rebounding = (close[0] < close[1] && close[1] < close[2]);
      
      if(touchedResistanceM5 && rebounding)
      {
         double reboundDistance = (MathMax(high[0], high[1]) - close[0]) / atrM5[0];
         reboundStrength = MathMin(reboundDistance / 1.5, 1.0);
         return true;
      }
      
      // Vérifier rebond sur résistance H1 (plus fort)
      bool touchedResistanceH1 = (high[0] >= resistanceH1 - tolerance || high[1] >= resistanceH1 - tolerance);
      if(touchedResistanceH1 && rebounding)
      {
         double reboundDistance = (MathMax(high[0], high[1]) - close[0]) / atrH1[0];
         reboundStrength = MathMin(reboundDistance / 1.5, 1.0) * 1.2; // Bonus pour H1
         reboundStrength = MathMin(reboundStrength, 1.0);
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier retournement de pattern (candlesticks)                 |
//| Retourne: true si pattern de retournement confirmé              |
//+------------------------------------------------------------------+
bool CheckPatternReversal(ENUM_ORDER_TYPE orderType, double &reversalConfidence)
{
   reversalConfidence = 0.0;
   
   // Récupérer les données de bougies
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5)
      return false;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      // Patterns haussiers de retournement
      // 1. Hammer / Doji après baisse
      bool wasFalling = (rates[2].close < rates[3].close && rates[1].close < rates[2].close);
      bool hammer = (rates[0].close > rates[0].open && 
                    (rates[0].close - rates[0].low) > 2 * (rates[0].close - rates[0].open));
      bool doji = (MathAbs(rates[0].close - rates[0].open) < (rates[0].high - rates[0].low) * 0.1);
      
      if(wasFalling && (hammer || doji))
      {
         reversalConfidence = 0.6;
         if(rates[0].close > rates[1].close)
            reversalConfidence = 0.8; // Confirmation avec bougie suivante
         return true;
      }
      
      // 2. Engulfing haussier
      bool bearishPrev = (rates[1].close < rates[1].open);
      bool bullishNow = (rates[0].close > rates[0].open);
      bool engulfing = (rates[0].open < rates[1].close && rates[0].close > rates[1].open);
      
      if(bearishPrev && bullishNow && engulfing)
      {
         reversalConfidence = 0.7;
         if(rates[0].close > rates[1].high)
            reversalConfidence = 0.9; // Fort engulfing
         return true;
      }
      
      // 3. Double bottom (simplifié)
      if(rates[2].low <= rates[3].low && rates[0].low <= rates[1].low &&
         rates[0].close > rates[2].close && rates[0].close > rates[1].close)
      {
         reversalConfidence = 0.75;
         return true;
      }
   }
   else // SELL
   {
      // Patterns baissiers de retournement
      // 1. Shooting Star / Doji après hausse
      bool wasRising = (rates[2].close > rates[3].close && rates[1].close > rates[2].close);
      bool shootingStar = (rates[0].close < rates[0].open && 
                          (rates[0].high - rates[0].close) > 2 * (rates[0].open - rates[0].close));
      bool doji = (MathAbs(rates[0].close - rates[0].open) < (rates[0].high - rates[0].low) * 0.1);
      
      if(wasRising && (shootingStar || doji))
      {
         reversalConfidence = 0.6;
         if(rates[0].close < rates[1].close)
            reversalConfidence = 0.8;
         return true;
      }
      
      // 2. Engulfing baissier
      bool bullishPrev = (rates[1].close > rates[1].open);
      bool bearishNow = (rates[0].close < rates[0].open);
      bool engulfing = (rates[0].open > rates[1].close && rates[0].close < rates[1].open);
      
      if(bullishPrev && bearishNow && engulfing)
      {
         reversalConfidence = 0.7;
         if(rates[0].close < rates[1].low)
            reversalConfidence = 0.9;
         return true;
      }
      
      // 3. Double top (simplifié)
      if(rates[2].high >= rates[3].high && rates[0].high >= rates[1].high &&
         rates[0].close < rates[2].close && rates[0].close < rates[1].close)
      {
         reversalConfidence = 0.75;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier toutes les conditions d'entrée avancées                |
//| Retourne: true si toutes les conditions sont remplies           |
//| entryScore = score global d'entrée (0-1)                        |
//+------------------------------------------------------------------+
bool CheckAdvancedEntryConditions(ENUM_ORDER_TYPE orderType, double &entryScore)
{
   entryScore = 0.0;
   int conditionsMet = 0;
   int totalConditions = 5;
   
   // 1. SuperTrend (obligatoire)
   double superTrendStrength = 0.0;
   bool superTrendOk = CheckSuperTrendSignal(orderType, superTrendStrength);
   if(superTrendOk && superTrendStrength > 0.3)
   {
      conditionsMet++;
      entryScore += superTrendStrength * 0.25; // 25% du score
   }
   else if(DebugMode)
      Print("⏸️ SuperTrend non confirmé pour ", EnumToString(orderType));
   
   // 2. Rebond sur support/résistance (fortement recommandé)
   double reboundStrength = 0.0;
   bool reboundOk = CheckSupportResistanceRebound(orderType, reboundStrength);
   if(reboundOk && reboundStrength > 0.4)
   {
      conditionsMet++;
      entryScore += reboundStrength * 0.25; // 25% du score
   }
   else if(DebugMode)
      Print("⏸️ Rebond S/R non confirmé pour ", EnumToString(orderType));
   
   // 3. Pattern de retournement (recommandé)
   double reversalConfidence = 0.0;
   bool reversalOk = CheckPatternReversal(orderType, reversalConfidence);
   if(reversalOk && reversalConfidence > 0.5)
   {
      conditionsMet++;
      entryScore += reversalConfidence * 0.20; // 20% du score
   }
   else if(DebugMode)
      Print("⏸️ Pattern retournement non confirmé pour ", EnumToString(orderType));
   
   // 4. Rebond sur trendline (amélioration de la fonction existante)
   double trendlineDistance = 0.0;
   bool trendlineOk = CheckReboundOnTrendline(orderType, trendlineDistance);
   if(trendlineOk && trendlineDistance < 10 * _Point)
   {
      conditionsMet++;
      entryScore += (1.0 - (trendlineDistance / (10 * _Point))) * 0.15; // 15% du score
   }
   else if(DebugMode)
      Print("⏸️ Rebond trendline non confirmé pour ", EnumToString(orderType));
   
   // 5. Alignement de tendance M5/H1 (obligatoire)
   bool trendOk = CheckTrendAlignment(orderType);
   if(trendOk)
   {
      conditionsMet++;
      entryScore += 0.15; // 15% du score
   }
   else if(DebugMode)
      Print("⏸️ Alignement tendance non confirmé pour ", EnumToString(orderType));
   
   // Score minimum requis: au moins 3 conditions sur 5 ET score total > 0.6
   bool entryValid = (conditionsMet >= 3 && entryScore >= 0.6);
   
   if(DebugMode && entryValid)
      Print("✅ Conditions d'entrée confirmées: ", conditionsMet, "/", totalConditions, " conditions, Score=", DoubleToString(entryScore, 2));
   
   return entryValid;
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
   
   // 6. VÉRIFICATIONS AVANCÉES: SuperTrend, Support/Résistance, Patterns
   double entryScore = 0.0;
   bool advancedConditionsOk = CheckAdvancedEntryConditions(orderType, entryScore);
   
   if(!advancedConditionsOk)
   {
      if(DebugMode)
         Print("⏸️ ", EnumToString(orderType), " rejeté: Conditions avancées non remplies (Score=", DoubleToString(entryScore, 2), " < 0.6)");
      return false;
   }
   
   // Toutes les conditions sont remplies
   if(DebugMode)
   {
      string rsiInfo = (ArraySize(rsi) > 0) ? " RSI=" + DoubleToString(rsi[0], 1) : "";
      Print("✅ ", EnumToString(orderType), " confirmé: Prix dans zone IA + Entrée depuis bonne direction + EMA M5 confirmé + Pas de correction + Conditions avancées (Score=", DoubleToString(entryScore, 2), ")", rsiInfo);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Détecter l'état du marché (Tendance/Correction/Range)          |
//+------------------------------------------------------------------+
MARKET_STATE DetectMarketState()
{
   // Récupérer les EMA
   double emaFast[], emaSlow[], emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[];
   double ema50[], ema100[], ema200[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   ArraySetAsSeries(ema50, true);
   ArraySetAsSeries(ema100, true);
   ArraySetAsSeries(ema200, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 20, emaFast) < 20 ||
      CopyBuffer(emaSlowHandle, 0, 0, 20, emaSlow) < 20 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 10, emaFastM5) < 10 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 10, emaSlowM5) < 10 ||
      CopyBuffer(emaFastH1Handle, 0, 0, 5, emaFastH1) < 5 ||
      CopyBuffer(emaSlowH1Handle, 0, 0, 5, emaSlowH1) < 5 ||
      CopyBuffer(ema50Handle, 0, 0, 20, ema50) < 20 ||
      CopyBuffer(ema100Handle, 0, 0, 20, ema100) < 20 ||
      CopyBuffer(ema200Handle, 0, 0, 20, ema200) < 20)
   {
      return MARKET_RANGE; // Par défaut si données insuffisantes
   }
   
   // Récupérer les prix
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, PERIOD_M1, 0, 20, close) < 20)
      return MARKET_RANGE;
   
   // Calculer la volatilité récente
   double priceRange = 0;
   for(int i = 0; i < 20; i++)
   {
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      if(CopyHigh(_Symbol, PERIOD_M1, i, 1, high) > 0 && CopyLow(_Symbol, PERIOD_M1, i, 1, low) > 0)
         priceRange += (high[0] - low[0]);
   }
   double avgRange = priceRange / 20.0;
   double currentPrice = close[0];
   double volatility = avgRange / currentPrice;
   
   // Détecter si c'est un range (prix oscille entre deux niveaux)
   double maxPrice = close[0], minPrice = close[0];
   for(int i = 0; i < 20; i++)
   {
      if(close[i] > maxPrice) maxPrice = close[i];
      if(close[i] < minPrice) minPrice = close[i];
   }
   double rangeSize = maxPrice - minPrice;
   double rangePercent = rangeSize / currentPrice;
   
   // Si la variation est très faible (< 0.1%), c'est un range
   if(rangePercent < 0.001 && volatility < 0.0005)
   {
      if(DebugMode)
         Print("📊 État marché: RANGE (variation < 0.1%)");
      return MARKET_RANGE;
   }
   
   // Vérifier l'alignement des EMA sur plusieurs timeframes
   bool m1Bullish = emaFast[0] > emaSlow[0] && ema50[0] > ema100[0] && ema100[0] > ema200[0];
   bool m1Bearish = emaFast[0] < emaSlow[0] && ema50[0] < ema100[0] && ema100[0] < ema200[0];
   bool m5Bullish = emaFastM5[0] > emaSlowM5[0];
   bool m5Bearish = emaFastM5[0] < emaSlowM5[0];
   bool h1Bullish = emaFastH1[0] > emaSlowH1[0];
   bool h1Bearish = emaFastH1[0] < emaSlowH1[0];
   
   // Tendance haussière claire: M1, M5 et H1 alignés haussiers
   if(m1Bullish && m5Bullish && h1Bullish)
   {
      // Vérifier que le prix est au-dessus des EMA (pas en correction)
      if(close[0] > emaFast[0] && close[0] > ema50[0])
      {
         if(DebugMode)
            Print("📊 État marché: TENDANCE HAUSSIÈRE (M1↑ M5↑ H1↑)");
         return MARKET_TREND_UP;
      }
      else
      {
         if(DebugMode)
            Print("📊 État marché: CORRECTION (tendance haussière mais prix sous EMA)");
         return MARKET_CORRECTION;
      }
   }
   
   // Tendance baissière claire: M1, M5 et H1 alignés baissiers
   if(m1Bearish && m5Bearish && h1Bearish)
   {
      // Vérifier que le prix est sous les EMA (pas en correction)
      if(close[0] < emaFast[0] && close[0] < ema50[0])
      {
         if(DebugMode)
            Print("📊 État marché: TENDANCE BAISSIÈRE (M1↓ M5↓ H1↓)");
         return MARKET_TREND_DOWN;
      }
      else
      {
         if(DebugMode)
            Print("📊 État marché: CORRECTION (tendance baissière mais prix au-dessus EMA)");
         return MARKET_CORRECTION;
      }
   }
   
   // Si les timeframes ne sont pas alignés, c'est une correction ou un range
   if(DebugMode)
      Print("📊 État marché: CORRECTION/RANGE (timeframes non alignés)");
   return MARKET_CORRECTION;
}

//+------------------------------------------------------------------+
//| Vérifier si on est dans une tendance claire                     |
//+------------------------------------------------------------------+
bool IsInClearTrend(ENUM_ORDER_TYPE orderType)
{
   if(!TradeOnlyInTrend)
      return true; // Si l'option est désactivée, autoriser tous les trades
   
   MARKET_STATE state = DetectMarketState();
   
   if(orderType == ORDER_TYPE_BUY)
      return (state == MARKET_TREND_UP);
   else if(orderType == ORDER_TYPE_SELL)
      return (state == MARKET_TREND_DOWN);
   
   return false;
}

//+------------------------------------------------------------------+
//| Obtenir la zone supérieure des fractals                         |
//+------------------------------------------------------------------+
double GetFractalUpperZone()
{
   if(fractalHandle == INVALID_HANDLE)
      return 0.0;
   
   double fractalUpper[];
   ArraySetAsSeries(fractalUpper, true);
   
   // Le buffer 0 contient les fractals supérieurs
   if(CopyBuffer(fractalHandle, 0, 0, 50, fractalUpper) < 50)
      return 0.0;
   
   // Trouver le dernier fractal supérieur valide
   for(int i = 0; i < 50; i++)
   {
      if(fractalUpper[i] > 0)
         return fractalUpper[i];
   }
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Obtenir la zone inférieure des fractals                         |
//+------------------------------------------------------------------+
double GetFractalLowerZone()
{
   if(fractalHandle == INVALID_HANDLE)
      return 0.0;
   
   double fractalLower[];
   ArraySetAsSeries(fractalLower, true);
   
   // Le buffer 1 contient les fractals inférieurs
   if(CopyBuffer(fractalHandle, 1, 0, 50, fractalLower) < 50)
      return 0.0;
   
   // Trouver le dernier fractal inférieur valide
   for(int i = 0; i < 50; i++)
   {
      if(fractalLower[i] > 0)
         return fractalLower[i];
   }
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est proche d'une zone fractal               |
//+------------------------------------------------------------------+
bool IsPriceNearFractalZone(double price, double &zonePrice)
{
   double upperZone = GetFractalUpperZone();
   double lowerZone = GetFractalLowerZone();
   
   if(upperZone > 0)
   {
      double distance = MathAbs(price - upperZone);
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         // Si le prix est à moins de 1 ATR du fractal supérieur
         if(distance < atr[0])
         {
            zonePrice = upperZone;
            return true;
         }
      }
   }
   
   if(lowerZone > 0)
   {
      double distance = MathAbs(price - lowerZone);
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         // Si le prix est à moins de 1 ATR du fractal inférieur
         if(distance < atr[0])
         {
            zonePrice = lowerZone;
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Améliorer la prédiction de spike avec données historiques       |
//+------------------------------------------------------------------+
void EnhanceSpikePredictionWithHistory()
{
   // Cette fonction sera appelée pour améliorer les prédictions
   // en analysant les patterns historiques de spikes
   
   if(!g_predictionValid || ArraySize(g_priceHistory) < 50)
      return;
   
   // Analyser les patterns de spikes historiques
   // Chercher des patterns similaires dans l'historique
   // et ajuster la prédiction en conséquence
   
   // Pour l'instant, on utilise les données historiques existantes
   // Cette fonction peut être étendue avec du machine learning
   
   if(DebugMode)
      Print("🔮 Prédiction améliorée avec analyse historique (", ArraySize(g_priceHistory), " bougies)");
}

//+------------------------------------------------------------------+
//| Dessiner la trajectoire de prédiction améliorée                 |
//+------------------------------------------------------------------+
void DrawEnhancedPredictionTrajectory()
{
   if(!g_predictionValid || ArraySize(g_pricePrediction) < 10)
      return;
   
   // Dessiner la trajectoire prédite sur le graphique
   // Utiliser des objets graphiques pour montrer la direction prévue
   
   string objName = "PredictionTrajectory_" + _Symbol;
   ObjectDelete(0, objName);
   
   // Créer une ligne ou des flèches pour montrer la trajectoire
   datetime startTime = TimeCurrent();
   datetime endTime = startTime + (g_predictionBars * PeriodSeconds(PERIOD_M1));
   
   double startPrice = g_pricePrediction[0];
   double endPrice = g_pricePrediction[ArraySize(g_pricePrediction) - 1];
   
   // Dessiner une ligne de prédiction
   if(ObjectCreate(0, objName, OBJ_TREND, 0, startTime, startPrice, endTime, endPrice))
   {
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true);
      ObjectSetString(0, objName, OBJPROP_TEXT, "Prédiction Spike");
   }
}

//+------------------------------------------------------------------+
//| Détecter opportunité de spike Boom/Crash avec EMAs et fractals |
//+------------------------------------------------------------------+
bool DetectBoomCrashSpikeOpportunity(ENUM_ORDER_TYPE &orderType, double &confidence)
{
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(!isBoom && !isCrash)
      return false;
   
   // Récupérer les EMA
   double emaFast[], emaSlow[], emaFastM5[], emaSlowM5[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 5, emaFast) < 5 ||
      CopyBuffer(emaSlowHandle, 0, 0, 5, emaSlow) < 5 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 3, emaFastM5) < 3 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 3, emaSlowM5) < 3)
      return false;
   
   // Récupérer le prix actuel
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double midPrice = (currentPrice + ask) / 2.0;
   
   // Vérifier les fractals
   double fractalZone = 0.0;
   bool nearFractal = IsPriceNearFractalZone(midPrice, fractalZone);
   
   // Vérifier l'état du marché (doit être en tendance)
   MARKET_STATE marketState = DetectMarketState();
   
   // Pour BOOM: Chercher BUY (spike haussier)
   if(isBoom)
   {
      // Conditions pour spike haussier:
      // 1. EMA rapide > EMA lente (tendance haussière)
      // 2. Prix proche d'un fractal inférieur OU prix au-dessus des EMA
      // 3. Marché en tendance haussière
      bool emaBullish = emaFast[0] > emaSlow[0] && emaFastM5[0] > emaSlowM5[0];
      bool priceAboveEMA = midPrice > emaFast[0];
      bool nearLowerFractal = (nearFractal && fractalZone < midPrice);
      
      if(emaBullish && (priceAboveEMA || nearLowerFractal) && marketState == MARKET_TREND_UP)
      {
         // Vérifier avec CheckSpikeEntryWithEMAsAndFractals
         double entryConf = 0.0;
         if(CheckSpikeEntryWithEMAsAndFractals(ORDER_TYPE_BUY, entryConf))
         {
            orderType = ORDER_TYPE_BUY;
            confidence = entryConf;
            return true;
         }
      }
   }
   
   // Pour CRASH: Chercher SELL (spike baissier)
   if(isCrash)
   {
      // Conditions pour spike baissier:
      // 1. EMA rapide < EMA lente (tendance baissière)
      // 2. Prix proche d'un fractal supérieur OU prix sous les EMA
      // 3. Marché en tendance baissière
      bool emaBearish = emaFast[0] < emaSlow[0] && emaFastM5[0] < emaSlowM5[0];
      bool priceBelowEMA = midPrice < emaFast[0];
      bool nearUpperFractal = (nearFractal && fractalZone > midPrice);
      
      if(emaBearish && (priceBelowEMA || nearUpperFractal) && marketState == MARKET_TREND_DOWN)
      {
         // Vérifier avec CheckSpikeEntryWithEMAsAndFractals
         double entryConf = 0.0;
         if(CheckSpikeEntryWithEMAsAndFractals(ORDER_TYPE_SELL, entryConf))
         {
            orderType = ORDER_TYPE_SELL;
            confidence = entryConf;
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier entrée spike avec EMAs et fractals                     |
//+------------------------------------------------------------------+
bool CheckSpikeEntryWithEMAsAndFractals(ENUM_ORDER_TYPE orderType, double &entryConfidence)
{
   // Récupérer les EMA
   double emaFast[], emaSlow[], ema50[], ema100[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(ema50, true);
   ArraySetAsSeries(ema100, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFast) < 3 ||
      CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlow) < 3 ||
      CopyBuffer(ema50Handle, 0, 0, 3, ema50) < 3 ||
      CopyBuffer(ema100Handle, 0, 0, 3, ema100) < 3)
      return false;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double midPrice = (currentPrice + ask) / 2.0;
   
   // Récupérer RSI
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) < 1)
      return false;
   
   // Récupérer ATR
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1)
      return false;
   
   entryConfidence = 0.0;
   int conditionsMet = 0;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      // Conditions pour BUY (spike haussier):
      // 1. EMA rapide > EMA lente
      if(emaFast[0] > emaSlow[0]) conditionsMet++;
      
      // 2. Prix au-dessus de EMA50 ou proche
      if(midPrice >= ema50[0] * 0.998) conditionsMet++;
      
      // 3. EMA50 > EMA100 (tendance haussière)
      if(ema50[0] > ema100[0]) conditionsMet++;
      
      // 4. RSI pas en surachat extrême (< 75)
      if(rsi[0] < 75) conditionsMet++;
      
      // 5. Prix proche d'un fractal inférieur (zone de rebond)
      double fractalZone = 0.0;
      if(IsPriceNearFractalZone(midPrice, fractalZone) && fractalZone < midPrice)
         conditionsMet++;
      
      // 6. Vérifier que le marché est en tendance haussière
      if(IsInClearTrend(ORDER_TYPE_BUY)) conditionsMet++;
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      // Conditions pour SELL (spike baissier):
      // 1. EMA rapide < EMA lente
      if(emaFast[0] < emaSlow[0]) conditionsMet++;
      
      // 2. Prix sous EMA50 ou proche
      if(midPrice <= ema50[0] * 1.002) conditionsMet++;
      
      // 3. EMA50 < EMA100 (tendance baissière)
      if(ema50[0] < ema100[0]) conditionsMet++;
      
      // 4. RSI pas en survente extrême (> 25)
      if(rsi[0] > 25) conditionsMet++;
      
      // 5. Prix proche d'un fractal supérieur (zone de rebond)
      double fractalZone = 0.0;
      if(IsPriceNearFractalZone(midPrice, fractalZone) && fractalZone > midPrice)
         conditionsMet++;
      
      // 6. Vérifier que le marché est en tendance baissière
      if(IsInClearTrend(ORDER_TYPE_SELL)) conditionsMet++;
   }
   
   // Calculer la confiance basée sur les conditions remplies
   entryConfidence = conditionsMet / 6.0; // 6 conditions maximum
   
   // Minimum 4 conditions sur 6 (66%) pour valider
   return (conditionsMet >= 4 && entryConfidence >= 0.60);
}

//+------------------------------------------------------------------+
//| Envoyer notification MT5 (Alert + SendNotification)            |
//+------------------------------------------------------------------+
void SendMT5Notification(string message, bool isAlert = true)
{
   // Envoyer Alert (popup + son)
   if(isAlert)
   {
      Alert(message);
   }
   
   // Envoyer SendNotification (notification push si activée dans MT5)
   SendNotification(message);
   
   // Afficher aussi dans le journal
   Print("📢 NOTIFICATION: ", message);
}
//+------------------------------------------------------------------+

