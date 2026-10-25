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
// #include <includes/AdvancedValidations.mqh>  // Validations avancées - Temporairement désactivé (fichier non trouvé)

//+------------------------------------------------------------------+
//| Paramètres d'entrée                                              |
//+------------------------------------------------------------------+
input group "--- CONFIGURATION DE BASE ---"
input int    InpMagicNumber     = 888888;  // Magic Number
input double InitialLotSize     = 0.01;    // Taille de lot initiale
input double MaxLotSize          = 1.0;     // Taille de lot maximale
input double TakeProfitUSD       = 30.0;    // Take Profit en USD (fixe) - Mouvements longs (augmenté pour cibler les grands mouvements)
input double StopLossUSD         = 10.0;    // Stop Loss en USD (fixe) - Ratio 3:1 pour favoriser les mouvements longs
input double ProfitThresholdForDouble = 0.5; // Seuil de profit (USD) pour doubler le lot
input int    MinPositionLifetimeSec = 5;    // Délai minimum avant modification (secondes)

input group "--- AI AGENT ---"
input bool   UseAI_Agent        = true;    // Activer l'agent IA (via serveur externe)
input string AI_ServerURL       = "http://127.0.0.1:8000/decision"; // URL serveur IA
input bool   UseAdvancedDecisionGemma = false; // Utiliser endsymbolPoint decisionGemma (Gemma+Gemini) avec analyse visuelle
input int    AI_Timeout_ms       = 800;     // Timeout WebRequest en millisecondes
input double AI_MinConfidence    = 0.50;    // Confiance minimale IA pour trader (50% - RÉDUIT pour exécution plus rapide)
// NOTE: Le serveur IA garantit maintenant 60% minimum si H1 aligné, 70% si H1+H4/D1
// Pour Boom/Crash, le seuil est automatiquement abaissé à 45% dans le code
// pour les tendances fortes (H4/D1 alignés). Le serveur ajoute automatiquement
// des bonus (+25% pour H4+D1 alignés, +10-20% pour alignement multi-TF)
input int    AI_UpdateInterval   = 3;      // Intervalle de mise à jour IA (secondes) - RÉDUIT pour réactivité maximale
input string AI_AnalysisURL    = "http://127.0.0.1:8000/analysis";  // URL base pour l'analyse complète (structure H1, etc.)
input int    AI_AnalysisIntervalSec = 60;  // Fréquence de rafraîchissement de l'analyse (secondes)
input string AI_TimeWindowsURLBase = "http://127.0.0.1:8000"; // Racine API pour /time_windows
input string TrendAPIURL = "http://127.0.0.1:8000/trend"; // URL API de tendance
input int    MinStabilitySeconds = 3;   // Délai minimum de stabilité avant exécution (secondes) - RÉDUIT pour exécution immédiate

input group "--- ÉLÉMENTS GRAPHIQUES ---"
input bool   DrawAIZones         = true;    // Dessiner les zones BUY/SELL de l'IA
input bool   DrawSupportResistance = false; // Dessiner support/résistance M5/H1 (DÉSACTIVÉ par défaut pour performance)
input bool   DrawTrendlines      = false;   // Dessiner les trendlines (DÉSACTIVÉ par défaut pour performance)
input bool   DrawDerivPatterns   = false;   // Dessiner les patterns Deriv (DÉSACTIVÉ par défaut pour performance)
input bool   DrawSMCZones        = false;   // Dessiner les zones SMC/OrderBlock (DÉSACTIVÉ pour performance)
input bool   DrawFractals        = true;    // Dessiner les fractales (triangles aux sommets/bas des bougies)

input group "--- STRATÉGIE US SESSION BREAK & RETEST (PRIORITAIRE) ---"
input bool   UseUSSessionStrategy = true;   // Activer la stratégie US Session (prioritaire)
input double US_RiskReward        = 2.0;    // Risk/Reward ratio pour US Session
input int    US_RetestTolerance   = 30;     // Tolérance retest en symbolPoints
input bool   US_OneTradePerDay    = true;   // Un seul trade par jour pour US Session

input group "--- GESTION DES RISQUES ---"
input double MaxDailyLoss        = 100.0;   // Perte quotidienne maximale (USD)
input double MaxDailyProfit      = 200.0;   // Profit quotidien maximale (USD)
input double MaxTotalLoss        = 5.0;     // Perte totale maximale toutes positions (USD)
input bool   UseTrailingStop     = true;   // Utiliser trailing stop (désactivé pour scalping fixe)

input group "--- SORTIES VOLATILITY ---"
input double VolatilityQuickTP   = 2.0;     // Fermer rapidement les indices Volatility à +2$ de profit
input double SyntheticForexTP    = 2.0;     // Fermer les synthétiques/forex/or à +2$ de profit (TOUJOURS)

input group "--- SORTIES BOOM/CRASH ---"
input double BoomCrashSpikeTP    = 0.01;    // Fermer Boom/Crash dès que le spike donne au moins ce profit (0.01 = quasi immédiat)

input group "--- INDICATEURS ---"
input int    EMA_Fast_Period     = 9;       // Période EMA rapide
input int    EMA_Slow_Period     = 21;      // Période EMA lente
input int    RSI_Period          = 14;      // Période RSI
input int    ATR_Period          = 14;      // Période ATR
input bool   ShowLongTrendEMA    = false;   // Afficher EMA 50, 100, 200 sur le graphique (DÉSACTIVÉ par défaut pour performance)
input bool   UseTrendAPIAnalysis = true;    // Utiliser l'analyse de tendance API pour affiner les décisions
input double TrendAPIMinConfidence = 60.0;  // Confiance minimum API pour validation (60% - RÉDUIT pour exécution rapide)

input group "--- JOURNALISATION CSV ---"
input bool   EnableCSVLogging    = true;    // Activer l'enregistrement CSV des trades
input string CSVFileNamePrefix   = "TradesJournal"; // Préfixe du nom de fichier CSV
input bool   EnablePredictionCSVExport = true; // Activer l'export CSV des prédictions
input string PredictionCSVFileNamePrefix = "Predictions"; // Préfixe du nom de fichier CSV des prédictions

input group "--- DEBUG ---"
input bool   DebugMode           = false;   // Mode debug (logs détaillés) - DÉSACTIVÉ par défaut pour performance

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
int fractalsHandle;

// Variables IA
static string   g_lastAIAction    = "";
static double   g_lastAIConfidence = 0.0;
static string   g_lastAIReason    = "";
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
static double   g_pricePrediction[];   // Tableau des prix prédits (500 bougies futures)
static double   g_priceHistory[];      // Tableau des prix historiques (200 bougies passées)
static datetime g_predictionStartTime = 0;  // Temps de début de la prédiction
static bool     g_predictionValid = false;  // La prédiction est-elle valide ?

// Variables pour les fractales
static double   g_upperFractals[];    // Fractales supérieures
static double   g_lowerFractals[];    // Fractales inférieures
static bool     g_fractalsValid = false;  // Les fractales sont-elles valides ?
static int      g_predictionBars = 500;     // Nombre de bougies futures à prédire
static int      g_historyBars = 100;        // Nombre de bougies historiques (réduit pour vitesse)
static datetime g_lastPredictionUpdate = 0; // Dernière mise à jour de la prédiction
const int PREDICTION_UPDATE_INTERVAL = 10; // Mise à jour toutes les 10 secondes (plus rapide)

// ===== SYSTÈME DE VALIDATION ET CALIBRATION DES PRÉDICTIONS =====
// Structure pour stocker les prédictions passées avec leur timestamp
struct HistoricalPrediction {
   datetime predictionTime;      // Quand la prédiction a été faite
   double predictedPrices[];     // Prix prédits pour chaque bougie future
   int barsPredicted;            // Nombre de bougies prédites
   double accuracyScore;          // Score de précision calculé (0.0 - 1.0)
   bool isValidated;              // Si la validation a été effectuée
   datetime lastValidation;       // Dernière validation
};

static HistoricalPrediction g_historicalPredictions[];  // Historique des prédictions
static int g_historicalPredictionsCount = 0;             // Nombre de prédictions stockées
static double g_predictionAccuracyScore = 0.0;           // Score de précision global (0.0 - 1.0)
static int g_predictionValidationCount = 0;              // Nombre de validations effectuées
static double g_predictionConfidenceMultiplier = 1.0;    // Multiplicateur de confiance basé sur la précision
const int MAX_HISTORICAL_PREDICTIONS = 50;               // Maximum 50 prédictions stockées
const int MIN_VALIDATION_BARS = 10;                      // Minimum 10 bougies pour valider
const double MIN_ACCURACY_THRESHOLD = 0.60;             // Seuil minimum de précision (60%)

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

// Cache pour GetTotalLoss() (optimisation performance)
static double g_cachedTotalLoss = 0.0;
static datetime g_lastTotalLossUpdate = 0;
const int TOTAL_LOSS_CACHE_INTERVAL = 1;  // Mise à jour du cache toutes les secondes

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
static ulong g_processedDeals[];  // Liste des deals déjà traités pour éviter les doubles comptages

// Suivi pour fermeture après spike (Boom/Crash)
static double g_lastBoomCrashPrice = 0.0;  // Prix de référence pour détecter le spike

// Suivi des tentatives de spike et cooldown (Boom/Crash)
static string   g_spikeSymbols[];
static int      g_spikeFailCount[];

// Suivi des pertes consécutives par symbole (pour bloquer après 2 pertes)
struct SymbolLossTracker {
   string symbol;           // Symbole
   int consecutiveLosses;   // Nombre de pertes consécutives
   int lastDirection;       // Dernière direction tradée (1=BUY, -1=SELL, 0=aucune)
   datetime lastLossTime;   // Dernière perte
};
static SymbolLossTracker g_symbolLossTrackers[];

// Structure pour stocker les opportunités BUY/SELL
struct TradingOpportunity {
   bool isBuy;           // true = BUY, false = SELL
   double entryPrice;    // Prix d'entrée
   double percentage;    // Pourcentage de gain potentiel
   datetime entryTime;   // Temps d'entrée
   int priority;         // Priorité (plus le gain est élevé, plus la priorité est haute)
};

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
   bool isValid;         // Si la décision est valide
   int stabilitySeconds; // Durée de stabilité en secondes
};

static TradingOpportunity g_opportunities[];  // Tableau des opportunités
static int g_opportunitiesCount = 0;          // Nombre d'opportunités
static datetime g_spikeCooldown[];

// Structure pour stocker les signaux de trading avec confiance
struct TradingSignal {
   string symbol;              // Symbole
   ENUM_ORDER_TYPE orderType;  // Type d'ordre (BUY/SELL)
   double confidence;          // Confiance de la décision finale (0.0 - 1.0)
   datetime timestamp;         // Timestamp du signal
   bool isDuplicate;           // Si c'est un trade dupliqué (ne compte pas dans la limite)
};

static TradingSignal g_pendingSignals[];  // Tableau des signaux en attente
static int g_pendingSignalsCount = 0;     // Nombre de signaux en attente

// Variables pour suivre la stabilité de la décision finale
static DecisionStability g_currentDecisionStability;
// MIN_STABILITY_SECONDS est maintenant un input (MinStabilitySeconds) - valeur par défaut: 30 secondes

// Suivi CSV pour journalisation des trades
struct TradeRecord {
   ulong ticket;              // Ticket de la position
   string symbol;             // Symbole tradé
   ENUM_POSITION_TYPE type;   // Type de position (BUY/SELL)
   datetime openTime;         // Heure d'ouverture
   datetime closeTime;        // Heure de fermeture
   double openPrice;         // Prix d'ouverture
   double closePrice;        // Prix de fermeture
   double lotSize;            // Taille du lot
   double stopLoss;           // Stop Loss
   double takeProfit;         // Take Profit
   double profit;             // Profit en USD
   double swap;               // Swap
   double commission;         // Commission
   string comment;            // Commentaire
   bool isClosed;             // Position fermée ou non
   double maxProfit;          // Profit maximum atteint
   double maxDrawdown;        // Drawdown maximum
   int durationSeconds;       // Durée en secondes
   string closeReason;        // Raison de fermeture (TP/SL/Manual/etc)
   double aiConfidence;       // Confiance IA au moment de l'ouverture
   string aiAction;           // Action IA (buy/sell/hold)
};

static TradeRecord g_tradeRecords[];  // Tableau des enregistrements de trades
static int g_tradeRecordsCount = 0;   // Nombre d'enregistrements
static string g_csvFileName = "";     // Nom du fichier CSV actuel
static datetime g_csvFileDate = 0;     // Date du fichier CSV (pour changement quotidien)
static string g_predictionCSVFileName = "";     // Nom du fichier CSV des prédictions
static datetime g_predictionCSVFileDate = 0;     // Date du fichier CSV des prédictions

// Structure pour stocker les candidats de niveaux (support/résistance)
struct LevelCandidate {
   double price;
   double distance;
   string source;
};

// Déclarations forward des fonctions
bool IsVolatilitySymbol(const string symbol);
bool IsBoomCrashSymbol(const string sym);
bool IsSyntheticForexOrGold(const string symbol);
bool IsMarketInCorrectionOrRange();
double GetTotalLoss();
double NormalizeLotSize(double lot);
int CountActivePositionsExcludingDuplicates(); // Compte les positions actives sans compter les duplications
void CleanOldGraphicalObjects();
void DrawAIConfidenceAndTrendSummary();
void DrawOpportunitiesPanel();
void DrawLongTrendEMA();
void DeleteEMAObjects(string prefix);
void ClearAllDisplayObjects(); // Nouvelle fonction pour nettoyer tous les objets d'affichage
bool IsCryptoSymbol(const string symbol); // Détecte si un symbole est une crypto
bool ValidateStops(const string symbol, const double entry, const double sl, const double tp); // Valide les niveaux de stop
bool CalculateOptimalStops(const string symbol, const double entry, double &sl, double &tp, const double riskReward = 2.0); // Calcule les stops optimaux
void DrawEMACurveOptimized(string prefix, double &values[], datetime &times[], int count, color clr, int width, int step);
void DrawAIZonesOnChart();
void DrawSupportResistanceLevels();
void DrawTrendlinesOnChart();
void DrawSMCZonesOnChart();
void DeleteSMCZones();
void CheckAndManagePositions();
void SecureDynamicProfits();
void SecureProfitForPosition(ulong ticket, double currentProfit);
void CloseAllBoomCrashAfterSpike(); // Fermer positions Boom/Crash après spike (même gain faible)
void CloseDuplicatePositionsIfProfitReached(string symbol, double profitThreshold = 2.0); // Fermer positions dupliquées si profit total >= 2 USD
void RecordSymbolLoss(string symbol, int direction, double profit); // Enregistrer une perte pour un symbole
bool HasConsecutiveLosses(string symbol, int maxLosses = 2); // Vérifier si un symbole a eu des pertes consécutives
void ResetSymbolLossTracker(string symbol, int newDirection); // Réinitialiser le tracker si nouvelle direction
int GetLastTwoTradesStatus(); // Vérifier l'état des deux derniers trades fermés (1=2 wins, -1=2 losses, 0=autre)
double ApplyTradeMotivation(double baseConfidence, int &maxActivePositions); // Appliquer récompense/sanction basée sur les derniers trades
void LookForTradingOpportunity();
bool CheckReboundOnTrendline(ENUM_ORDER_TYPE orderType, double &distance);
bool DetectReversalAtFastEMA(ENUM_ORDER_TYPE orderType);
bool CheckAIZoneEntryWithEMA(ENUM_ORDER_TYPE orderType, bool &isInZone, bool &emaConfirmed, bool &isCorrection);
bool CheckTrendAlignment(ENUM_ORDER_TYPE orderType);
bool CheckSuperTrendSignal(ENUM_ORDER_TYPE orderType, double &strength);
void CleanAllObsoleteInfoTraces(); // Nettoyer toutes les traces d'informations obsolètes
bool CheckSupportResistanceRebound(ENUM_ORDER_TYPE orderType, double &reboundStrength);
bool CheckPatternReversal(ENUM_ORDER_TYPE orderType, double &reversalConfidence);
bool CheckCoherenceOfAllAnalyses(int direction); // Vérifie la cohérence de tous les endsymbolPoints (1=BUY, -1=SELL)
bool CheckImmediatePredictionDirection(ENUM_ORDER_TYPE orderType); // Vérifie que la prédiction montre un mouvement immédiat dans le bon sens
bool IsRealTrendReversal(ulong ticket, ENUM_POSITION_TYPE posType, double currentPrice, double entryPrice);
void SendMT5Notification(string message); // Envoie une notification MT5
double FindOptimalLimitOrderPrice(ENUM_ORDER_TYPE orderType, double suggestedPrice); // Trouve le meilleur prix pour ordre limite sur S/R ou trendline (M1/M5)
bool IsTrendStillValid(ENUM_POSITION_TYPE posType);
bool CheckAdvancedEntryConditions(ENUM_ORDER_TYPE orderType, double &entryScore);
void UpdatePricePrediction();
void DrawPricePrediction();
void ValidateHistoricalPredictions(); // Valide les prédictions passées contre les prix réels
void StoreCurrentPrediction(); // Stocke la prédiction actuelle pour validation future
double CalculatePredictionAccuracy(double &predictedPrices[], int barsPredicted, datetime predictionTime); // Calcule la précision d'une prédiction
void UpdatePredictionConfidenceMultiplier(); // Met à jour le multiplicateur de confiance basé sur la précision
void DetectReversalPoints(int &buyEntries[], int &sellEntries[]);
void UsePredictionForCurrentTrades();
void DetectAndDrawCorrectionZones();
void PlaceLimitOrderOnCorrection();
bool CheckM5ReversalConfirmation(ENUM_ORDER_TYPE orderType);
bool RefineEntryWithM5EMA(ENUM_ORDER_TYPE orderType); // Affine l'entrée avec EMA rapide et moyen sur M5
bool CheckStrongReversalAfterTouch(ENUM_ORDER_TYPE orderType, double &touchLevel, string &touchSource);
double CalculateDynamicTP(ENUM_ORDER_TYPE orderType, double entryPrice);
bool IsPriceInCorrectionZone(ENUM_ORDER_TYPE orderType);
double FindNextSupportResistance(ENUM_ORDER_TYPE orderType, double currentPrice);
void InitializeCSVFile();
void WriteTradeToCSV(const TradeRecord& record);
void LogTradeOpen(ulong ticket);
void LogTradeClose(ulong ticket, string closeReason);
void UpdateTradeRecord(ulong ticket);
string GetCSVFileName();
void ExportPredictionData(string symbol); // Exporte les données de prédiction par symbole
string GetPredictionCSVFileName(string symbol); // Obtient le nom du fichier CSV pour un symbole donné
void InitializePredictionCSVFile(string symbol); // Initialise le fichier CSV des prédictions pour un symbole
void SynchronizeCSVWithHistory(); // Synchronise le CSV avec l'historique réel de MT5

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
//| Réinitialiser les compteurs quotidiens                           |
//+------------------------------------------------------------------+
void ResetDailyCounters()
{
   g_dailyProfit = 0.0;
   g_dailyLoss = 0.0;
   ArrayResize(g_processedDeals, 0);
   
   if(DebugMode)
      Print("📅 Compteurs quotidiens réinitialisés");
}

//+------------------------------------------------------------------+
//| Diagnostiquer la connexion au serveur IA                          |
//+------------------------------------------------------------------+
void DiagnoseServerConnection()
{
   if(!UseAI_Agent || StringLen(AI_ServerURL) == 0)
   {
      Print("❌ Diagnostic: IA désactivée ou URL vide");
      return;
   }
   
   Print("🔍 Diagnostic de connexion au serveur IA...");
   Print("   URL: ", AI_ServerURL);
   Print("   Timeout: ", AI_Timeout_ms, "ms");
   
   // Test simple avec une requête GET
   uchar result[];
   string headers = "";
   string result_headers = "";
   uchar data[]; // Paramètre data requis mais vide pour GET
   
   uint testStart = GetTickCount();
   int res = WebRequest("GET", AI_ServerURL + "/health", headers, 2000, data, result, result_headers);
   uint testDuration = GetTickCount() - testStart;
   
   if(res >= 200 && res < 300)
   {
      Print("✅ Diagnostic: Serveur répond correctement (", testDuration, "ms)");
      Print("   Status: ", res);
      Print("   Response: ", CharArrayToString(result));
   }
   else
   {
      Print("❌ Diagnostic: Échec de connexion (", testDuration, "ms)");
      Print("   Erreur HTTP: ", res);
      
      // Analyser l'erreur
      if(res == 1001)
         Print("   Cause probable: Serveur non démarré ou firewall bloquant");
      else if(res == 1002)
         Print("   Cause probable: Timeout - serveur trop lent");
      else if(res == 1003)
         Print("   Cause probable: DNS - nom d'hôte incorrect");
      else
         Print("   Cause probable: Erreur serveur HTTP");
   }
}

//+------------------------------------------------------------------+
//| Réinitialiser les prédictions et forcer une récupération          |
//+------------------------------------------------------------------+
void ForcePredictionReset()
{
   g_predictionValid = false;
   ArrayResize(g_pricePrediction, 0);
   
   if(DebugMode)
      Print("🔄 Reset forcé des prédictions - prochaine tentative immédiate");
   
   // Forcer une mise à jour immédiate
   UpdatePricePrediction();
}

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
   fractalsHandle = iFractals(_Symbol, PERIOD_M1);
   
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
   
   if(emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE || 
      emaFastH1Handle == INVALID_HANDLE || emaSlowH1Handle == INVALID_HANDLE ||
      emaFastM5Handle == INVALID_HANDLE || emaSlowM5Handle == INVALID_HANDLE ||
      ema50Handle == INVALID_HANDLE || ema100Handle == INVALID_HANDLE || ema200Handle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE ||
      atrM5Handle == INVALID_HANDLE || atrH1Handle == INVALID_HANDLE ||
      fractalsHandle == INVALID_HANDLE)
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
   
   // Initialiser le fichier CSV si activé
   if(EnableCSVLogging)
   {
      // S'assurer que le dossier Files existe dès le démarrage
      EnsureFilesDirectoryExists();
      InitializeCSVFile();
      Print("✅ Journalisation CSV activée - Fichier: ", g_csvFileName);
   }
   
   Print("✅ Système de stabilité de décision finale activé (minimum ", MinStabilitySeconds, " secondes)");
   
   // Initialiser le fichier CSV des prédictions si activé (par symbole)
   if(EnablePredictionCSVExport)
   {
      InitializePredictionCSVFile(_Symbol);
      string fileName = GetPredictionCSVFileName(_Symbol);
      Print("✅ Export CSV des prédictions activé - Fichier: ", fileName, " (un fichier par symbole dans Files\\)");
   }
   
   // Synchroniser le CSV avec l'historique réel de MT5 au démarrage
   if(EnableCSVLogging)
   {
      SynchronizeCSVWithHistory();
      Print("✅ Synchronisation CSV avec historique MT5 effectuée");
   }
   
   // Nettoyer les anciens objets d'affichage au démarrage
   ClearAllDisplayObjects();
   
   // Essayer de charger les prédictions sauvegardées
   if(!LoadPredictions())
   {
      // Si le chargement a échoué, forcer une mise à jour
      if(DebugMode)
         Print("ℹ️ Mise à jour des prédictions nécessaire");
      
      // Mettre à jour les prédictions immédiatement
      UpdatePricePrediction();
   }
   else
   {
      // Mettre à jour l'affichage avec les données chargées
      if(DebugMode)
         Print("ℹ️ Affichage des prédictions chargées");
      
      // Afficher les informations sur le graphique avec les données chargées
      DrawAIConfidenceAndTrendSummary();
      DrawOpportunitiesPanel();
      
      // Planifier une mise à jour en arrière-plan
      EventSetTimer(5); // Vérifier les mises à jour après 5 secondes
   }
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Gestionnaire d'événements de temporisation                       |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Désactiver le minuteur temporairement
   EventKillTimer();
   
   // Vérifier si une mise à jour est nécessaire
   static datetime lastUpdateTime = 0;
   static datetime lastRetryTime = 0;
   datetime currentTime = TimeCurrent();
   
   // Stratégie de mise à jour adaptative
   bool forceUpdate = false;
   int updateInterval = 300; // 5 minutes par défaut
   
   // Si les prédictions ne sont pas valides, essayer plus souvent
   if(!g_predictionValid)
   {
      updateInterval = 60; // 1 minute si invalide
      forceUpdate = true;
      
      if(DebugMode)
         Print("🔄 Prédictions invalides - tentative de récupération accélérée");
   }
   
   // Mettre à jour les prédictions si nécessaire
   if(forceUpdate || (currentTime - lastUpdateTime) >= updateInterval)
   {
      if(DebugMode)
         Print("🔄 Mise à jour des prédictions (intervalle: ", updateInterval, "s)");
      
      // Mettre à jour les prédictions
      UpdatePricePrediction();
      lastUpdateTime = currentTime;
   }
   
   // Reprogrammer la vérification avec intervalle adaptatif
   int nextCheckInterval = 60; // 1 minute par défaut
   if(!g_predictionValid)
      nextCheckInterval = 30; // 30 secondes si invalide
   
   EventSetTimer(nextCheckInterval);
   
   if(DebugMode && !g_predictionValid)
      Print("⏱️ Prochaine vérification dans ", nextCheckInterval, " secondes");
}

// Définition de la constante FILE_COMMON si elle n'existe pas
#ifndef FILE_COMMON
   #define FILE_COMMON 0
#endif

//+------------------------------------------------------------------+
//| Fonction de chargement des prédictions depuis un fichier binaire |
//+------------------------------------------------------------------+
bool LoadPredictions()
{
   string filename = "predictions_" + _Symbol + ".bin";
   int handle = FileOpen(filename, FILE_READ | FILE_BIN | FILE_COMMON);
   
   if(handle != INVALID_HANDLE)
   {
      // Vérifier si les données sont trop anciennes (plus de 1 heure)
      datetime savedTime = (datetime)FileReadLong(handle);
      if(TimeCurrent() - savedTime > 3600) // 1 heure en secondes
      {
         FileClose(handle);
         if(DebugMode)
            Print("ℹ️ Données de prédiction trop anciennes, rechargement nécessaire");
         return false;
      }
      
      // Charger les données historiques
      int historySize = FileReadInteger(handle);
      ArrayResize(g_priceHistory, historySize);
      FileReadArray(handle, g_priceHistory);
      
      // Charger les prédictions
      g_predictionBars = FileReadInteger(handle);
      ArrayResize(g_pricePrediction, g_predictionBars);
      FileReadArray(handle, g_pricePrediction);
      
      FileClose(handle);
      
      if(DebugMode)
         Print("✅ Prédictions chargées depuis le fichier: ", filename);
      
      return true;
   }
   
   if(DebugMode)
      Print("ℹ️ Aucune donnée de prédiction sauvegardée trouvée");
   
   return false;
}

//+------------------------------------------------------------------+
//| Mettre à jour les prédictions de prix                            |
//+------------------------------------------------------------------+
void UpdatePricePrediction()
{
   // Variables statiques pour le suivi des erreurs
   static int consecutiveErrors = 0;
   static int jsonErrorCount = 0;
   static datetime lastHttpError = 0;
   static datetime lastRetryTime = 0;
   static bool serverDown = false;
   
   if(!UseAI_Agent || StringLen(AI_ServerURL) == 0)
   {
      if(DebugMode)
         Print("⚠️ UpdatePricePrediction: IA désactivée ou URL vide - UseAI_Agent=", UseAI_Agent, " URL_len=", StringLen(AI_ServerURL));
      return;
   }
   
   if(DebugMode)
   {
      Print("🔄 UpdatePricePrediction: Mise à jour des prédictions depuis ", AI_ServerURL);
      Print("🔍 Paramètres - g_predictionBars=", g_predictionBars, " g_historyBars=", g_historyBars);
   }
   
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
   
   // Envoyer la requête avec timeout adaptatif
   uchar result[];
   string headers = "Content-Type: application/json\r\n";
   string result_headers = "";
   
   // Adapter le timeout en fonction du nombre d'erreurs
   int adaptiveTimeout = AI_Timeout_ms;
   if(consecutiveErrors > 0)
      adaptiveTimeout = MathMin(AI_Timeout_ms * (1 + consecutiveErrors), 5000); // Max 5 secondes
   
   if(DebugMode && consecutiveErrors > 0)
      Print("🔄 Timeout adaptatif: ", adaptiveTimeout, "ms (erreurs=", consecutiveErrors, ")");
   
   int res = WebRequest("POST", predictionURL, headers, adaptiveTimeout, data, result, result_headers);
   
   if(res < 200 || res >= 300)
   {
      lastHttpError = TimeCurrent();
      consecutiveErrors++;
      
      // Analyser le type d'erreur
      string errorType = "";
      if(res == 1001) errorType = "Connexion refusée (serveur down?)";
      else if(res == 1002) errorType = "Timeout";
      else if(res == 1003) errorType = "DNS résolution échouée";
      else if(res >= 500) errorType = "Erreur serveur HTTP ";
      else if(res >= 400) errorType = "Erreur client HTTP ";
      else errorType = "Erreur HTTP ";
      
      if(DebugMode)
         Print("⚠️ Erreur prédiction prix: ", errorType, res, " - Tentative de récupération automatique");
      
      // Si le serveur semble down, marquer comme tel
      if(res == 1001 && consecutiveErrors >= 3)
         serverDown = true;
      
      // Stratégie de récupération adaptative
      if(consecutiveErrors <= 2)
      {
         if(DebugMode)
            Print("🔄 Erreur #", consecutiveErrors, " - Maintien de la prédiction existante pour récupération");
         return; // Garder la prédiction existante
      }
      else if(consecutiveErrors <= 5)
      {
         if(DebugMode)
            Print("⚠️ Erreur #", consecutiveErrors, " - Invalidation temporaire, tentative de retry");
         g_predictionValid = false; // Invalider temporairement
         
         // Programmer un retry plus rapide si le serveur n'est pas down
         if(!serverDown && (TimeCurrent() - lastRetryTime) > 30)
         {
            EventSetTimer(15); // Retry dans 15 secondes
            lastRetryTime = TimeCurrent();
         }
         return;
      }
      else
      {
         if(DebugMode)
            Print("❌ Erreur #", consecutiveErrors, " - Trop d'erreurs consécutives, invalidation complète");
         g_predictionValid = false;
         
         // Reset complet après 10 erreurs pour permettre récupération
         if(consecutiveErrors >= 10)
         {
            consecutiveErrors = 0;
            serverDown = false; // Reset du statut du serveur
            if(DebugMode)
               Print("🔄 Reset des compteurs d'erreur pour tentative de récupération");
         }
         return;
      }
   }
   else
   {
      // Succès - reset du compteur d'erreurs et statut du serveur
      if(consecutiveErrors > 0 || serverDown)
      {
         if(DebugMode)
            Print("✅ Connexion rétablie après ", consecutiveErrors, " erreurs");
      }
      consecutiveErrors = 0;
      serverDown = false;
   }
   
   // Parser la réponse JSON
   string resp = CharArrayToString(result, 0, -1, CP_UTF8);
   
   if(DebugMode)
   {
      Print("📊 Réponse prédiction reçue: ", StringSubstr(resp, 0, 500));
      Print("🔍 Taille de la réponse: ", StringLen(resp), " caractères");
   }
   
   // Extraire le tableau de prédictions
   // Format attendu: {"prediction": [prix1, prix2, ..., prix200]}
   int predStart = StringFind(resp, "\"prediction\"");
   if(predStart < 0)
   {
      predStart = StringFind(resp, "\"prices\"");
      if(predStart < 0)
      {
         if(DebugMode)
         {
            Print("⚠️ Clé 'prediction' ou 'prices' non trouvée dans la réponse");
            Print("🔍 Réponse complète: ", StringSubstr(resp, 0, 200));
         }
         
         // ===== NOUVEAU: TENTER RÉCUPÉRATION AVANT INVALIDATION =====
         jsonErrorCount++;
         
         if(jsonErrorCount <= 3)
         {
            if(DebugMode)
               Print("🔄 Erreur JSON #", jsonErrorCount, " - Maintien de la prédiction existante");
            return; // Garder la prédiction existante
         }
         else
         {
            if(DebugMode)
               Print("❌ Trop d'erreurs JSON consécutives - Invalidation de la prédiction");
            g_predictionValid = false;
            jsonErrorCount = 0; // Reset pour récupération future
            return;
         }
      }
      else
      {
         if(DebugMode)
            Print("✅ Clé 'prices' trouvée à la position: ", predStart);
      }
   }
   else
   {
      if(DebugMode)
         Print("✅ Clé 'prediction' trouvée à la position: ", predStart);
   }
   
   // Trouver le début du tableau
   int arrayStart = StringFind(resp, "[", predStart);
   if(arrayStart < 0)
   {
      if(DebugMode)
         Print("⚠️ Tableau de prédiction non trouvé après la clé");
      g_predictionValid = false;
      return;
   }
   else
   {
      if(DebugMode)
         Print("✅ Début du tableau trouvé à la position: ", arrayStart);
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
   else
   {
      if(DebugMode)
         Print("✅ Fin du tableau trouvée à la position: ", arrayEnd);
   }
   
   // Extraire le contenu du tableau
   string arrayContent = StringSubstr(resp, arrayStart + 1, arrayEnd - arrayStart - 1);
   
   if(DebugMode)
   {
      Print("🔍 Contenu du tableau: ", StringSubstr(arrayContent, 0, 200));
      Print("🔍 Longueur du contenu: ", StringLen(arrayContent));
   }
   
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
      {
         Print("✅ Prédiction parsée avec succès - count=", count, " valeurs");
         Print("🔍 Première valeur: ", DoubleToString(g_pricePrediction[0], _Digits));
         Print("🔍 Dernière valeur: ", DoubleToString(g_pricePrediction[count-1], _Digits));
         Print("🔍 g_predictionValid mis à: ", g_predictionValid ? "true" : "false");
      }
      
      // ===== NOUVEAU: Stocker la prédiction pour validation future =====
      StoreCurrentPrediction();
      
      // ===== EXPORTER les données de prédiction par symbole =====
      ExportPredictionData(_Symbol);
      
      if(DebugMode)
         Print("✅ Prédiction de prix mise à jour: ", count, " bougies prédites | Précision historique: ", 
               DoubleToString(g_predictionAccuracyScore * 100, 1), "% | Multiplicateur confiance: ", 
               DoubleToString(g_predictionConfidenceMultiplier, 2));
   }
   else
   {
      g_predictionValid = false;
      if(DebugMode)
      {
         Print("⚠️ Aucune prédiction valide extraite - count=0");
         Print("🔍 arrayContent: '", arrayContent, "'");
         Print("🔍 StringLen(arrayContent): ", StringLen(arrayContent));
         
         // ===== NOUVEAU: DIAGNOSTIC APPROFONDI =====
         Print("🔍 DIAGNOSTIC PRÉDICTION:");
         Print("   - UseAI_Agent: ", UseAI_Agent ? "OUI" : "NON");
         Print("   - AI_ServerURL: '", AI_ServerURL, "'");
         Print("   - g_predictionBars: ", g_predictionBars);
         Print("   - g_historyBars: ", g_historyBars);
         Print("   - Taille réponse: ", StringLen(resp));
         Print("   - Réponse (premiers 300 chars): ", StringSubstr(resp, 0, 300));
         
         // Tenter de voir si c'est une erreur de format
         if(StringFind(resp, "error") >= 0 || StringFind(resp, "Error") >= 0 || StringFind(resp, "ERROR") >= 0)
         {
            Print("❌ ERREUR SERVEUR DÉTECTÉE dans la réponse");
         }
         else if(StringFind(resp, "null") >= 0)
         {
            Print("⚠️ RÉPONSE NULL détectée - Possible erreur serveur");
         }
         else if(StringLen(resp) < 50)
         {
            Print("⚠️ RÉPONSE TROP COURTE - Possible erreur de connexion");
         }
      }
   }
   
   // ===== NOUVEAU: Valider les prédictions passées =====
   ValidateHistoricalPredictions();
}

//+------------------------------------------------------------------+
//| Détecter les symbolPoints de retournement dans les prédictions         |
//| Retourne les indices des symbolPoints d'entrée BUY (minima) et SELL (maxima) |
//| Filtrer pour ne garder que les mouvements longs                  |
//+------------------------------------------------------------------+
void DetectReversalPoints(int &buyEntries[], int &sellEntries[])
{
   ArrayResize(buyEntries, 0);
   ArrayResize(sellEntries, 0);
   
   if(!g_predictionValid || ArraySize(g_pricePrediction) < 5)
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
   int lookbackWindow = 3; // Réduit à 3 symbolPoints pour détecter plus de symbolPoints
   
   // Détecter les minima locaux (symbolPoints d'entrée BUY - retournement haussier)
   for(int i = lookbackWindow; i < ArraySize(g_pricePrediction) - lookbackWindow; i++)
   {
      bool isLocalMin = true;
      double currentPrice = g_pricePrediction[i];
      
      // Vérifier que c'est un minimum local (prix plus bas que les symbolPoints environnants)
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
         // Chercher le prochain maximum local dans un rayon de 20 symbolPoints
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
            
            if(DebugMode)
               Print("📈 Point d'entrée BUY détecté à l'indice ", i, " prix=", DoubleToString(currentPrice, _Digits), 
                     " mouvement attendu=", DoubleToString(movementSize, _Digits), " (", DoubleToString((movementSize/currentPrice)*100, 2), "%)");
         }
      }
   }
   
   // Détecter les maxima locaux (symbolPoints d'entrée SELL - retournement baissier)
   for(int i = lookbackWindow; i < ArraySize(g_pricePrediction) - lookbackWindow; i++)
   {
      bool isLocalMax = true;
      double currentPrice = g_pricePrediction[i];
      
      // Vérifier que c'est un maximum local (prix plus haut que les symbolPoints environnants)
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
         // Chercher le prochain minimum local dans un rayon de 20 symbolPoints
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
            
            if(DebugMode)
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
   // Messages de debug pour diagnostiquer
   if(DebugMode)
   {
      Print("🔍 DrawPricePrediction appelé - DrawAIZones=", DrawAIZones, " g_predictionValid=", g_predictionValid, 
            " ArraySize(g_pricePrediction)=", ArraySize(g_pricePrediction),
            " g_predictionStartTime=", TimeToString(g_predictionStartTime));
   }
   
   // Réinitialiser le tableau des opportunités au début de chaque mise à jour
   ArrayResize(g_opportunities, 0);
   g_opportunitiesCount = 0;
   
   // Utiliser exactement 200 bougies historiques et 500 bougies futures
   int totalPredictionBars = MathMin(ArraySize(g_pricePrediction), g_predictionBars);
   
   if(totalPredictionBars == 0)
   {
      if(DebugMode)
         Print("⚠️ DrawPricePrediction: Aucune prédiction disponible (totalPredictionBars=0) - Affichage du statut");
      
      // ===== NOUVEAU: AFFICHER LE STATUT MÊME SANS PRÉDICTION =====
      // Pour que l'utilisateur voie pourquoi les zones ne s'affichent pas
      string statusText = "";
      if(!UseAI_Agent)
         statusText = "IA DÉSACTIVÉE";
      else if(StringLen(AI_ServerURL) == 0)
         statusText = "URL IA VIDE";
      else if(!g_predictionValid)
         statusText = "PRÉDICTION INVALIDE";
      else
         statusText = "DONNÉES INSUFFISANTES";
      
      // Créer un objet texte pour afficher le statut
      string statusObjName = "PRED_STATUS_" + _Symbol;
      if(ObjectFind(0, statusObjName) < 0)
      {
         ObjectCreate(0, statusObjName, OBJ_LABEL, 0, 0, 0);
         ObjectSetString(0, statusObjName, OBJPROP_TEXT, "Zone Prédiction: " + statusText);
         ObjectSetInteger(0, statusObjName, OBJPROP_XDISTANCE, 20);
         ObjectSetInteger(0, statusObjName, OBJPROP_YDISTANCE, 100);
         ObjectSetInteger(0, statusObjName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, statusObjName, OBJPROP_FONTSIZE, 12);
         ObjectSetInteger(0, statusObjName, OBJPROP_BGCOLOR, clrWhite);
      }
      else
      {
         ObjectSetString(0, statusObjName, OBJPROP_TEXT, "Zone Prédiction: " + statusText);
      }
      
      return; // Pas de prédiction disponible mais statut affiché
   }
   
   if(DebugMode)
      Print("✅ DrawPricePrediction: totalPredictionBars=", totalPredictionBars, " - Début du dessin");
   
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
      // Créer un symbolPoint de départ au prix actuel
      totalHistoryBars = 1;
      ArrayResize(combinedPrices, totalBars + 1);
      ArrayResize(combinedTimes, totalBars + 1);
      
      // Décaler les prédictions
      for(int i = totalPredictionBars - 1; i >= 0; i--)
      {
         combinedPrices[i + 1] = g_pricePrediction[i];
         combinedTimes[i + 1] = currentTime + (i + 1) * periodSeconds;
      }
      
      // Ajouter le symbolPoint de départ (prix actuel)
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
   
   // Détecter les symbolPoints de retournement (mouvements longs) - uniquement dans la partie prédiction future
   int buyEntries[];
   int sellEntries[];
   DetectReversalPoints(buyEntries, sellEntries);
   
   // ===== NE PLUS AFFICHER LES FLÈCHES D'ENTRÉE =====
   // Les flèches sont remplacées par le panneau d'opportunité unique
   // Supprimer toutes les flèches d'entrée existantes
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix + "BUY_ENTRY_") == 0 || StringFind(name, prefix + "SELL_ENTRY_") == 0)
         ObjectDelete(0, name);
   }
   
   // Dessiner les symbolPoints d'entrée BUY (minima - retournements haussiers) en VERT
   for(int b = 0; b < ArraySize(buyEntries); b++)
   {
      int predIdx = buyEntries[b]; // Index dans g_pricePrediction
      if(predIdx >= 0 && predIdx < totalPredictionBars)
      {
         int combinedIdx = totalHistoryBars + predIdx; // Index dans combinedPrices/Times
         if(combinedIdx < totalBars)
         {
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
            // ===== PLUS DE FLÈCHE - JUSTE STOCKER L'OPPORTUNITÉ =====
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
   
   if(DebugMode)
      Print("✅ DrawPricePrediction terminé - Zones IA dessinées avec succès");
}

//+------------------------------------------------------------------+
//| Valider les prédictions passées contre les prix réels           |
//+------------------------------------------------------------------+
void ValidateHistoricalPredictions()
{
   if(g_historicalPredictionsCount == 0)
      return; // Aucune prédiction à valider
   
   datetime currentTime = TimeCurrent();
   
   // Parcourir toutes les prédictions stockées
   for(int i = 0; i < g_historicalPredictionsCount; i++)
   {
      HistoricalPrediction pred = g_historicalPredictions[i];
      
      // Vérifier si on peut valider cette prédiction (assez de temps écoulé)
      int barsSincePrediction = (int)((currentTime - pred.predictionTime) / PeriodSeconds(PERIOD_M1));
      
      if(barsSincePrediction < MIN_VALIDATION_BARS)
         continue; // Pas assez de données encore
      
      // Si déjà validée récemment (dans les dernières 5 minutes), skip
      if(pred.isValidated && (currentTime - pred.lastValidation) < 300)
         continue;
      
      // Calculer la précision de cette prédiction
      double accuracy = CalculatePredictionAccuracy(pred.predictedPrices, pred.barsPredicted, pred.predictionTime);
      
      if(accuracy >= 0.0)
      {
         pred.accuracyScore = accuracy;
         pred.isValidated = true;
         pred.lastValidation = currentTime;
         
         // Mettre à jour le score global de précision
         if(g_predictionValidationCount == 0)
         {
            g_predictionAccuracyScore = accuracy;
         }
         else
         {
            // Moyenne pondérée (plus récentes = plus de poids)
            g_predictionAccuracyScore = (g_predictionAccuracyScore * g_predictionValidationCount + accuracy) / (g_predictionValidationCount + 1);
         }
         g_predictionValidationCount++;
         
         // Mettre à jour le multiplicateur de confiance
         UpdatePredictionConfidenceMultiplier();
         
         if(DebugMode)
            Print("📊 Prédiction validée #", i, " - Précision: ", DoubleToString(accuracy * 100, 2), 
                  "% | Précision globale: ", DoubleToString(g_predictionAccuracyScore * 100, 2), "%");
      }
   }
   
   // Nettoyer les anciennes prédictions (garder seulement les MAX_HISTORICAL_PREDICTIONS plus récentes)
   if(g_historicalPredictionsCount > MAX_HISTORICAL_PREDICTIONS)
   {
      // Supprimer les plus anciennes
      int toRemove = g_historicalPredictionsCount - MAX_HISTORICAL_PREDICTIONS;
      for(int i = 0; i < toRemove; i++)
      {
         // Décaler toutes les prédictions vers la gauche
         for(int j = 0; j < g_historicalPredictionsCount - 1; j++)
         {
            g_historicalPredictions[j] = g_historicalPredictions[j + 1];
         }
      }
      g_historicalPredictionsCount = MAX_HISTORICAL_PREDICTIONS;
   }
}

//+------------------------------------------------------------------+
//| Calcule la précision d'une prédiction                            |
//| Compare les prix prédits avec les prix réels                     |
//| Retourne un score de 0.0 à 1.0 (1.0 = parfait)                  |
//+------------------------------------------------------------------+
double CalculatePredictionAccuracy(double &predictedPrices[], int barsPredicted, datetime predictionTime)
{
   if(barsPredicted <= 0 || ArraySize(predictedPrices) < MIN_VALIDATION_BARS)
      return -1.0; // Données insuffisantes
   
   int validationBars = MathMin(barsPredicted, MathMin(ArraySize(predictedPrices), MIN_VALIDATION_BARS));
   if(validationBars < MIN_VALIDATION_BARS)
      return -1.0;
   
   // Récupérer les prix réels depuis MT5
   double actualPrices[];
   ArraySetAsSeries(actualPrices, true);
   
   // Calculer combien de bougies sont passées depuis la prédiction
   datetime currentTime = TimeCurrent();
   int periodSeconds = PeriodSeconds(PERIOD_M1);
   int barsSincePrediction = (int)((currentTime - predictionTime) / periodSeconds);
   
   if(barsSincePrediction < MIN_VALIDATION_BARS)
      return -1.0; // Pas encore assez de données
   
   // IMPORTANT: Les prédictions commencent à la première bougie FUTURE après predictionTime
   // predictedPrices[0] = prix prédit pour la bougie qui s'est fermée à predictionTime + 1 période
   // predictedPrices[1] = prix prédit pour la bougie qui s'est fermée à predictionTime + 2 périodes
   // etc.
   
   // On doit copier suffisamment de bougies pour couvrir les validationBars premières prédictions
   // Avec ArraySetAsSeries=true: actualPrices[0] = bougie la plus récente, actualPrices[N] = bougie la plus ancienne
   // Si barsSincePrediction = N, alors:
   // - predictedPrices[0] (première prédiction) devrait correspondre à la bougie qui s'est fermée il y a (N-1) bougies
   // - predictedPrices[i] devrait correspondre à actualPrices[barsSincePrediction - 1 - i]
   
   int barsToCopy = barsSincePrediction; // Copier toutes les bougies depuis la prédiction
   if(barsToCopy < validationBars)
      return -1.0; // Pas assez de données
   
   int copied = CopyClose(_Symbol, PERIOD_M1, 1, barsToCopy, actualPrices);
   
   if(copied < validationBars)
      return -1.0; // Pas assez de données historiques
   
   // Comparer les prix prédits avec les prix réels en alignant correctement
   // predictedPrices[i] correspond à la bougie qui s'est fermée à predictionTime + (i+1) périodes
   // actualPrices[barsSincePrediction - 1 - i] est la bougie qui s'est fermée il y a (barsSincePrediction - 1 - i) bougies
   // Si barsSincePrediction = N, alors actualPrices[N-1-i] correspond à la bougie fermée à predictionTime + (i+1) périodes
   
   double totalError = 0.0;
   double totalPrice = 0.0;
   int validComparisons = 0;
   
   for(int i = 0; i < validationBars && i < ArraySize(predictedPrices); i++)
   {
      // Index dans actualPrices qui correspond à predictedPrices[i]
      int actualIndex = barsSincePrediction - 1 - i;
      
      if(actualIndex >= 0 && actualIndex < copied && predictedPrices[i] > 0.0 && actualPrices[actualIndex] > 0.0)
      {
         double error = MathAbs(predictedPrices[i] - actualPrices[actualIndex]);
         double relativeError = error / actualPrices[actualIndex]; // Erreur relative en %
         
         totalError += relativeError;
         totalPrice += actualPrices[actualIndex];
         validComparisons++;
      }
   }
   
   if(validComparisons < MIN_VALIDATION_BARS)
      return -1.0;
   
   // Score de précision basé sur l'erreur relative moyenne
   // Si erreur moyenne < 1%, score = 1.0
   // Si erreur moyenne = 10%, score = 0.5
   // Formule: score = 1.0 - (erreur_moyenne * 10), avec min = 0.0
   double avgRelativeError = totalError / validComparisons;
   double accuracyScore = MathMax(0.0, 1.0 - (avgRelativeError * 10.0));
   
   return accuracyScore;
}

//+------------------------------------------------------------------+
//| Stocke la prédiction actuelle pour validation future            |
//+------------------------------------------------------------------+
void StoreCurrentPrediction()
{
   if(!g_predictionValid || ArraySize(g_pricePrediction) == 0)
      return; // Pas de prédiction valide à stocker
   
   // Vérifier si on n'a pas déjà atteint la limite
   if(g_historicalPredictionsCount >= MAX_HISTORICAL_PREDICTIONS)
   {
      // Décaler les prédictions (supprimer la plus ancienne)
      for(int i = 0; i < MAX_HISTORICAL_PREDICTIONS - 1; i++)
      {
         g_historicalPredictions[i] = g_historicalPredictions[i + 1];
      }
      g_historicalPredictionsCount = MAX_HISTORICAL_PREDICTIONS - 1;
   }
   
   // Créer une nouvelle entrée de prédiction
   int idx = g_historicalPredictionsCount;
   ArrayResize(g_historicalPredictions, idx + 1);
   
   HistoricalPrediction newPred = g_historicalPredictions[idx];
   newPred.predictionTime = g_predictionStartTime;
   newPred.barsPredicted = ArraySize(g_pricePrediction);
   newPred.accuracyScore = -1.0; // Pas encore validé
   newPred.isValidated = false;
   newPred.lastValidation = 0;
   
   // Copier les prix prédits
   ArrayResize(newPred.predictedPrices, newPred.barsPredicted);
   ArrayCopy(newPred.predictedPrices, g_pricePrediction, 0, 0, newPred.barsPredicted);
   
   g_historicalPredictionsCount++;
   
   if(DebugMode)
      Print("💾 Prédiction stockée #", idx, " - ", newPred.barsPredicted, " bougies prédites à ", TimeToString(newPred.predictionTime));
}

//+------------------------------------------------------------------+
//| Met à jour le multiplicateur de confiance basé sur la précision |
//| Plus la précision est élevée, plus le multiplicateur est élevé  |
//+------------------------------------------------------------------+
void UpdatePredictionConfidenceMultiplier()
{
   if(g_predictionValidationCount == 0 || g_predictionAccuracyScore < 0.0)
   {
      // Pas encore de données de validation, utiliser la valeur par défaut
      g_predictionConfidenceMultiplier = 1.0;
      return;
   }
   
   // Ajuster le multiplicateur basé sur la précision
   // Si précision >= 0.8 (80%), multiplicateur = 1.2 (boost de confiance)
   // Si précision >= 0.6 (60%), multiplicateur = 1.0 (neutre)
   // Si précision < 0.6 (60%), multiplicateur = 0.8 (réduction de confiance)
   // Si précision < 0.4 (40%), multiplicateur = 0.5 (forte réduction)
   
   if(g_predictionAccuracyScore >= 0.8)
      g_predictionConfidenceMultiplier = 1.2;
   else if(g_predictionAccuracyScore >= 0.6)
      g_predictionConfidenceMultiplier = 1.0;
   else if(g_predictionAccuracyScore >= 0.4)
      g_predictionConfidenceMultiplier = 0.8;
   else
      g_predictionConfidenceMultiplier = 0.5;
   
   if(DebugMode)
      Print("📈 Multiplicateur de confiance mis à jour: ", DoubleToString(g_predictionConfidenceMultiplier, 2), 
            " (précision: ", DoubleToString(g_predictionAccuracyScore * 100, 2), "%)");
}

//+------------------------------------------------------------------+
//| Mettre à jour les fractales                                       |
//+------------------------------------------------------------------+
void UpdateFractals()
{
   // Récupérer les données des fractales (derniers 100 bars)
   int barsToCopy = 100;
   
   // Préparer les tableaux pour les fractales supérieures et inférieures
   ArrayResize(g_upperFractals, barsToCopy);
   ArrayResize(g_lowerFractals, barsToCopy);
   ArraySetAsSeries(g_upperFractals, true);
   ArraySetAsSeries(g_lowerFractals, true);
   
   // Copier les données des fractales
   int upperCopied = CopyBuffer(fractalsHandle, 0, 0, barsToCopy, g_upperFractals);
   int lowerCopied = CopyBuffer(fractalsHandle, 1, 0, barsToCopy, g_lowerFractals);
   
   if(upperCopied > 0 && lowerCopied > 0)
   {
      g_fractalsValid = true;
      
      if(DebugMode)
         Print("✅ Fractales mises à jour: ", upperCopied, " supérieures, ", lowerCopied, " inférieures");
   }
   else
   {
      g_fractalsValid = false;
      
      if(DebugMode)
         Print("⚠️ Erreur récupération données fractales");
   }
}

//+------------------------------------------------------------------+
//| Dessiner les fractales sur le graphique                          |
//+------------------------------------------------------------------+
void DrawFractalsOnChart()
{
   if(!g_fractalsValid)
      return;
   
   // Supprimer les anciennes fractales
   ObjectsDeleteAll(0, "FRACTAL_");
   
   // Nombre de fractales à dessiner (50 dernières)
   int barsToDraw = 50;
   int actualBars = MathMin(barsToDraw, ArraySize(g_upperFractals));
   
   for(int i = 0; i < actualBars; i++)
   {
      datetime barTime[];
      ArraySetAsSeries(barTime, true);
      
      if(CopyTime(_Symbol, PERIOD_M1, i, 1, barTime) > 0)
      {
         // Dessiner fractale supérieure (triangle vers le haut)
         if(g_upperFractals[i] > 0)
         {
            string fractalName = "FRACTAL_UP_" + IntegerToString(i) + "_" + _Symbol;
            
            if(ObjectFind(0, fractalName) < 0)
               ObjectCreate(0, fractalName, OBJ_ARROW_UP, 0, barTime[0], g_upperFractals[i]);
            else
            {
               ObjectSetInteger(0, fractalName, OBJPROP_TIME, 0, barTime[0]);
               ObjectSetDouble(0, fractalName, OBJPROP_PRICE, 0, g_upperFractals[i]);
            }
            
            // Style de la fractale supérieure
            ObjectSetInteger(0, fractalName, OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(0, fractalName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, fractalName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, fractalName, OBJPROP_BACK, false);
         }
         
         // Dessiner fractale inférieure (triangle vers le bas)
         if(g_lowerFractals[i] > 0)
         {
            string fractalName = "FRACTAL_DOWN_" + IntegerToString(i) + "_" + _Symbol;
            
            if(ObjectFind(0, fractalName) < 0)
               ObjectCreate(0, fractalName, OBJ_ARROW_DOWN, 0, barTime[0], g_lowerFractals[i]);
            else
            {
               ObjectSetInteger(0, fractalName, OBJPROP_TIME, 0, barTime[0]);
               ObjectSetDouble(0, fractalName, OBJPROP_PRICE, 0, g_lowerFractals[i]);
            }
            
            // Style de la fractale inférieure
            ObjectSetInteger(0, fractalName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, fractalName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, fractalName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, fractalName, OBJPROP_BACK, false);
         }
      }
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
   int analysisStep = 3; // Analyser 1 symbolPoint sur 3 pour réduire les calculs
   
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
         int correctionStep = 2; // Analyser 1 symbolPoint sur 2
         
         for(int k = i + 1; k < MathMin(i + 30, ArraySize(g_pricePrediction) - 1); k += correctionStep)
         {
            if(g_pricePrediction[k] < lowestCorrection)
            {
               lowestCorrection = g_pricePrediction[k];
               correctionEndIdx = k;
            }
            // Si le prix remonte après la correction, on a trouvé la fin de la zone
            // OPTIMISATION: Vérifier seulement tous les 2 symbolPoints
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
         int correctionStep = 2; // Analyser 1 symbolPoint sur 2
         
         for(int k = i + 1; k < MathMin(i + 30, ArraySize(g_pricePrediction) - 1); k += correctionStep)
         {
            if(g_pricePrediction[k] > highestCorrection)
            {
               highestCorrection = g_pricePrediction[k];
               correctionEndIdx = k;
            }
            // Si le prix redescend après la correction, on a trouvé la fin de la zone
            // OPTIMISATION: Vérifier seulement tous les 2 symbolPoints
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
//| Obtenir la tendance EMA pour un timeframe donné                  |
//+------------------------------------------------------------------+
int GetEMATrend(ENUM_TIMEFRAMES timeframe)
{
   int handleFast = INVALID_HANDLE;
   int handleSlow = INVALID_HANDLE;
   
   if(timeframe == PERIOD_M1)
   {
      handleFast = emaFastHandle;
      handleSlow = emaSlowHandle;
   }
   else if(timeframe == PERIOD_M5)
   {
      handleFast = emaFastM5Handle;
      handleSlow = emaSlowM5Handle;
   }
   else if(timeframe == PERIOD_H1)
   {
      handleFast = emaFastH1Handle;
      handleSlow = emaSlowH1Handle;
   }
   else
   {
      return 0; // Timeframe non supporté
   }
   
   if(handleFast == INVALID_HANDLE || handleSlow == INVALID_HANDLE)
      return 0;
   
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   if(CopyBuffer(handleFast, 0, 0, 1, emaFast) <= 0 || CopyBuffer(handleSlow, 0, 0, 1, emaSlow) <= 0)
      return 0;
   
   if(emaFast[0] > emaSlow[0])
      return 1; // Tendance haussière
   else if(emaFast[0] < emaSlow[0])
      return -1; // Tendance baissière
   else
      return 0; // Neutre
}

//+------------------------------------------------------------------+
//| Détecte si le symbole actuel est un métal, crypto ou Forex       |
//+------------------------------------------------------------------+
bool IsMetalCryptoOrForexSymbol()
{
   string symbol = _Symbol;
   
   // Vérifier les métaux précieux
   if(StringFind(symbol, "XAU") != -1 || StringFind(symbol, "XAG") != -1 || StringFind(symbol, "XPD") != -1 ||
      StringFind(symbol, "GOLD") != -1 || StringFind(symbol, "SILVER") != -1 ||
      StringFind(symbol, "COPPER") != -1 || StringFind(symbol, "PLATINUM") != -1)
   {
      return true;
   }
   
   // Vérifier les crypto-monnaies
   if(StringFind(symbol, "BTC") != -1 || StringFind(symbol, "ETH") != -1 ||
      StringFind(symbol, "USDT") != -1 || StringFind(symbol, "USDC") != -1 ||
      StringFind(symbol, "BNB") != -1 || StringFind(symbol, "ADA") != -1 ||
      StringFind(symbol, "DOT") != -1 || StringFind(symbol, "SOL") != -1 ||
      StringFind(symbol, "MATIC") != -1 || StringFind(symbol, "AVAX") != -1 ||
      StringFind(symbol, "LINK") != -1 || StringFind(symbol, "UNI") != -1)
   {
      return true;
   }
   
   // Vérifier les paires Forex (toutes les paires sauf indices et Boom/Crash)
   if(StringFind(symbol, "EUR") != -1 || StringFind(symbol, "USD") != -1 ||
      StringFind(symbol, "GBP") != -1 || StringFind(symbol, "JPY") != -1 ||
      StringFind(symbol, "CHF") != -1 || StringFind(symbol, "CAD") != -1 ||
      StringFind(symbol, "AUD") != -1 || StringFind(symbol, "NZD") != -1 ||
      StringFind(symbol, "NOK") != -1 || StringFind(symbol, "SEK") != -1)
   {
      // Exclure les indices et Boom/Crash
      if(StringFind(symbol, "Boom") == -1 && StringFind(symbol, "Crash") == -1 &&
         StringFind(symbol, "Volatility") == -1 && StringFind(symbol, "Step") == -1 &&
         StringFind(symbol, "Jump") == -1 && StringFind(symbol, "Range") == -1)
      {
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Détecte si le symbole est une crypto-monnaie                     |
//+------------------------------------------------------------------+
bool IsCryptoSymbol(const string symbol)
{
   string cryptos[] = {"BTC", "ETH", "XRP", "LTC", "BCH", "XLM", "EOS", "BNB", "XMR", "DASH", "DOGE", "SOL", "DOT", "AVAX", "MATIC", "LINK", "UNI"};
   for(int i = 0; i < ArraySize(cryptos); i++) {
      if(StringFind(symbol, cryptos[i]) != -1) {
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si les niveaux de stop sont valides pour le symbole      |
//+------------------------------------------------------------------+
bool ValidateStops(const string symbol, const double entry, const double sl, const double tp)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int stopLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStop = stopLevel * point;
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;
   
   // Pour les cryptos, augmenter la distance minimale
   if(IsCryptoSymbol(symbol)) {
      minStop = MathMax(minStop, 10 * point); // Au moins 10 points pour les cryptos
   }
   
   // Ajouter le spread à la distance minimale pour le SL
   minStop += spread;
   
   double slDistance = MathAbs(entry - sl);
   double tpDistance = MathAbs(tp - entry);
   
   if(slDistance < minStop) {
      Print("Erreur: Distance SL trop petite pour ", symbol, 
            " - Min=", minStop, " Actuel=", slDistance, 
            " (Prix=", entry, " SL=", sl, " TP=", tp, ")");
      return false;
   }
   
   if(tpDistance < minStop) {
      Print("Erreur: Distance TP trop petite pour ", symbol, 
            " - Min=", minStop, " Actuel=", tpDistance,
            " (Prix=", entry, " SL=", sl, " TP=", tp, ")");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calcule les niveaux de stop optimaux                             |
//+------------------------------------------------------------------+
bool CalculateOptimalStops(const string symbol, const double entry, double &sl, double &tp, const double riskReward = 2.0)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int stopLevel = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStop = stopLevel * point;
   double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * point;
   
   // Pour les cryptos, augmenter la distance minimale
   if(IsCryptoSymbol(symbol)) {
      minStop = MathMax(minStop, 10 * point);
   }
   
   // Ajouter le spread à la distance minimale
   minStop += spread;
   
   // Calculer la distance SL
   double slDistance = MathAbs(entry - sl);
   
   // S'assurer que la distance SL est suffisante
   if(slDistance < minStop) {
      sl = (sl < entry) ? 
           NormalizeDouble(entry - minStop, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) : 
           NormalizeDouble(entry + minStop, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      slDistance = minStop;
      Print("Ajustement SL - Nouvelle valeur: ", sl);
   }
   
   // Calculer le TP en fonction du risque/rendement
   tp = (entry > sl) ? 
        NormalizeDouble(entry + (slDistance * riskReward), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) : 
        NormalizeDouble(entry - (slDistance * riskReward), (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
   
   // Vérifier que le TP est à une distance suffisante
   double tpDistance = MathAbs(tp - entry);
   if(tpDistance < minStop) {
      tp = (tp > entry) ? 
           NormalizeDouble(entry + minStop, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)) : 
           NormalizeDouble(entry - minStop, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
      Print("Ajustement TP - Nouvelle valeur: ", tp);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Placer un ordre limite sur la meilleure zone de correction       |
//+------------------------------------------------------------------+
void PlaceLimitOrderOnCorrection()
{
   // ===== NOUVEAU: BLOQUER LES ORDRES LIMITES POUR MÉTAUX, CRYPTO ET FOREX =====
   if(IsMetalCryptoOrForexSymbol())
   {
      if(DebugMode)
         Print("🚫 PlaceLimitOrder: BLOQUÉ - Symbole ", _Symbol, " est un métal, crypto ou Forex - Ordres limites non autorisés");
      return;
   }
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
   
   // ===== VÉRIFICATION 0 (PRIORITÉ ABSOLUE): Vérifier que les données IA sont récentes =====
   int timeSinceAIUpdate = (int)(TimeCurrent() - g_lastAITime);
   int maxAge = AI_UpdateInterval * 2; // Maximum 2x l'intervalle
   if(g_lastAITime == 0 || timeSinceAIUpdate > maxAge)
   {
      Print("🚫 PlaceLimitOrder: Données IA trop anciennes ou inexistantes - Dernière mise à jour: ", 
            (g_lastAITime == 0 ? "JAMAIS" : IntegerToString(timeSinceAIUpdate) + "s"),
            " (Max: ", maxAge, "s) - Attente mise à jour IA");
      return; // BLOQUER si données IA trop anciennes
   }
   
   // ===== VÉRIFICATION 1 (PRIORITÉ): L'action IA (ACHAT/VENTE) =====
   // Vérifier d'abord si l'IA recommande ACHAT ou VENTE avant le placement de l'ordre
   // BUY_LIMIT nécessite que l'IA recommande ACHAT (buy)
   // SELL_LIMIT nécessite que l'IA recommande VENTE (sell)
   int aiDirection = 0;
   if(g_lastAIAction == "buy")
      aiDirection = 1; // IA recommande ACHAT
   else if(g_lastAIAction == "sell")
      aiDirection = -1; // IA recommande VENTE
   else if(g_api_trend_direction != 0)
      aiDirection = g_api_trend_direction; // Fallback sur API trend
   
   if(aiDirection == 0)
   {
      Print("🚫 PlaceLimitOrder: Pas d'action IA claire - Action=", g_lastAIAction, 
            " API_Trend=", g_api_trend_direction,
            " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
      return; // Pas d'action IA claire
   }
   
      if(DebugMode)
      Print("🔍 PlaceLimitOrder: Action IA vérifiée - Action=", g_lastAIAction, 
            " Direction=", aiDirection == 1 ? "ACHAT (BUY)" : "VENTE (SELL)",
            " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
   
   // Déclarer currentPrice au début pour être utilisé partout
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   
   // ===== VÉRIFICATION 2: Direction de la zone prédite (par où le prix va passer) =====
   int predSize = ArraySize(g_pricePrediction);
   int predictionDirection = 0;
   
   if(g_predictionValid && predSize >= 20)
   {
      int predictionWindow = MathMin(20, ArraySize(g_pricePrediction)); // Utiliser 20 bougies
      double predictedPrice = g_pricePrediction[predictionWindow - 1]; // Prix prédit dans 20 bougies
      
      // Déterminer la direction de la zone prédite (par où le prix va passer)
   double priceMovement = predictedPrice - currentPrice;
   double movementPercent = (MathAbs(priceMovement) / currentPrice) * 100.0;
   
   if(movementPercent > 0.05) // Mouvement significatif (> 0.05%)
   {
      if(priceMovement > 0)
            predictionDirection = 1; // Zone prédite haussière (le prix va passer par le haut = BUY)
      else
            predictionDirection = -1; // Zone prédite baissière (le prix va passer par le bas = SELL)
   }
   
   if(DebugMode)
         Print("🔍 PlaceLimitOrder: Zone prédite - Prix actuel=", DoubleToString(currentPrice, _Digits), 
            " Prédit=", DoubleToString(predictedPrice, _Digits), 
            " Mouvement=", DoubleToString(movementPercent, 2), "%",
               " Direction zone=", predictionDirection == 1 ? "HAUSSIÈRE (prix passe par le haut)" : 
                                  (predictionDirection == -1 ? "BAISSIÈRE (prix passe par le bas)" : "NEUTRE"));
   }
   else
   {
   if(DebugMode)
         Print("⚠️ PlaceLimitOrder: Prédiction invalide ou absente (valid=", g_predictionValid ? "true" : "false", 
               ", size=", predSize, ") - Validation basée uniquement sur l'action IA");
   }
   
   // ===== RÈGLE STRICTE: ALIGNEMENT OBLIGATOIRE ENTRE ACTION IA ET ZONE PRÉDITE =====
   // On ne place un ordre limit QUE si l'action IA et la direction de la zone prédite sont alignées
   // Si elles ne sont pas alignées, on attend l'alignement avant de placer un ordre
   
   int marketDirection = 0;
   
   // Vérifier l'alignement entre l'action IA et la zone prédite
   bool isAligned = (aiDirection != 0 && predictionDirection != 0 && aiDirection == predictionDirection);
   
   if(isAligned)
   {
      // ✅ ALIGNEMENT CONFIRMÉ: Action IA et zone prédite symbolPointent dans la même direction
      marketDirection = aiDirection; // Utiliser la direction alignée
      Print("✅ PlaceLimitOrder: ALIGNEMENT CONFIRMÉ - Action IA=", (aiDirection == 1 ? "ACHAT (BUY)" : "VENTE (SELL)"),
            " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)",
            " Zone prédite=", (predictionDirection == 1 ? "HAUSSIÈRE" : "BAISSIÈRE"),
            " → Direction=", marketDirection == 1 ? "BUY" : "SELL");
   }
   else
   {
      // ❌ PAS D'ALIGNEMENT: Situation pas encore claire, attendre l'alignement
      string aiStr = (aiDirection == 1 ? "ACHAT (BUY)" : (aiDirection == -1 ? "VENTE (SELL)" : "NEUTRE"));
      string predStr = (predictionDirection == 1 ? "HAUSSIÈRE" : (predictionDirection == -1 ? "BAISSIÈRE" : "NEUTRE"));
      
      if(aiDirection != 0 && predictionDirection != 0 && aiDirection != predictionDirection)
      {
         // Cas 1: Action IA et zone prédite en désaccord
         Print("⏸️ PlaceLimitOrder: DÉSACCORD - Action IA=", aiStr, 
               " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)",
               " mais Zone prédite=", predStr,
               " → Situation pas encore claire, ATTENTE de l'alignement avant placement d'ordre limit");
      }
      else if(aiDirection == 0 && predictionDirection == 0)
      {
         // Cas 2: Les deux sont neutres
         Print("⏸️ PlaceLimitOrder: PAS DE DIRECTION - Action IA=NEUTRE et Zone prédite=NEUTRE",
               " → Attente d'une direction claire avant placement d'ordre limit");
      }
      else if(aiDirection == 0)
      {
         // Cas 3: Action IA neutre mais zone prédite claire
         Print("⏸️ PlaceLimitOrder: ACTION IA NEUTRE - Zone prédite=", predStr,
               " mais Action IA=NEUTRE → Attente de l'action IA avant placement d'ordre limit");
      }
      else if(predictionDirection == 0)
      {
         // Cas 4: Zone prédite neutre mais action IA claire
         Print("⏸️ PlaceLimitOrder: ZONE PRÉDITE NEUTRE - Action IA=", aiStr,
               " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)",
               " mais Zone prédite=NEUTRE → Attente de la direction de la zone prédite avant placement d'ordre limit");
      }
      
      return; // Ne pas placer d'ordre, attendre l'alignement
   }
   
   // ===== VÉRIFICATION SPÉCIALE POUR SYMBOLES VOLATILES =====
   // Pour Volatility 100, Step Index et autres symboles volatiles
   // EXIGER au moins 85% de confiance même avec un signal buy/sell fort
   // AUCUN ordre LIMIT ne doit être placé si confiance < 85%
   bool isVolatilitySymbol = IsVolatilitySymbol(_Symbol);
   string symbolUpper = _Symbol;
   StringToUpper(symbolUpper);
   bool isStepIndex = (StringFind(symbolUpper, "STEP") != -1);
   
   if((isVolatilitySymbol || isStepIndex) && g_lastAIConfidence < 0.85)
   {
      Print("🚫 ORDRE LIMIT BLOQUÉ (SYMBOLES VOLATILES): ", _Symbol, " - Confiance insuffisante: ", 
            DoubleToString(g_lastAIConfidence * 100, 2), "% < 85% requis - Aucun ordre LIMIT autorisé pour symboles volatiles");
      return;
   }
   
   // Note: Le pourcentage de confiance IA n'est pas obligatoire pour placer l'ordre
   // Il est utilisé seulement comme information (avertissement si < 60%)
   if(g_lastAIConfidence < 0.60)
   {
      Print("⚠️ PlaceLimitOrder: Confiance IA faible (", DoubleToString(g_lastAIConfidence * 100, 1), "% < 60%)",
            " mais action IA valide - Direction=", marketDirection == 1 ? "BUY" : "SELL");
   }
   
   // Le message d'alignement a déjà été affiché ci-dessus, pas besoin de le répéter
   Print("📋 RÈGLE STRICTE: Seules les opportunités ", (marketDirection == 1 ? "BUY" : "SELL"), 
         " seront acceptées pour les ordres limit (alignement IA + Zone prédite requis)");
   
   // ===== ÉVALUER TOUTES LES OPPORTUNITÉS ET SÉLECTIONNER LA MEILLEURE =====
   TradingOpportunity bestOpportunity = {0};
   bool bestFound = false;
   double bestScore = -1.0;
   
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
      
      // ===== FILTRAGE STRICT: L'opportunité DOIT correspondre à la direction IA/prédiction =====
      // RÈGLE ABSOLUE: 
      // - Si IA recommande VENTE (SELL) et prédiction baissière → marketDirection = -1 → On garde UNIQUEMENT les opportunités SELL
      // - Si IA recommande ACHAT (BUY) et prédiction haussière → marketDirection = 1 → On garde UNIQUEMENT les opportunités BUY
      // - Si direction neutre (marketDirection == 0), on ne place pas d'ordre limit
      
      bool zoneMatchesDirection = false;
      
      if(marketDirection == 1) // IA recommande ACHAT (BUY) et prédiction haussière
      {
         // On garde UNIQUEMENT les opportunités BUY (zones d'achat)
      if(zoneIsBuy)
         {
            zoneMatchesDirection = true; // BUY LIMIT pour correction baissière (opportunité d'achat)
         }
         else
         {
            // Opportunité SELL rejetée car direction est BUY
            Print("🚫 Opportunité #", i, " REJETÉE: Type=SELL mais direction marché=BUY (IA=", g_lastAIAction, 
                  " Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
            continue;
         }
      }
      else if(marketDirection == -1) // IA recommande VENTE (SELL) et prédiction baissière
      {
         // On garde UNIQUEMENT les opportunités SELL (zones de vente)
         if(!zoneIsBuy)
         {
            zoneMatchesDirection = true; // SELL LIMIT pour correction haussière (opportunité de vente)
         }
         else
         {
            // Opportunité BUY rejetée car direction est SELL
            Print("🚫 Opportunité #", i, " REJETÉE: Type=BUY mais direction marché=SELL (IA=", g_lastAIAction, 
                  " Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
            continue;
         }
      }
      else // marketDirection == 0 (direction neutre)
      {
         Print("🚫 Opportunité #", i, " REJETÉE: Direction marché neutre - Pas d'ordre limit placé");
         continue; // Pas de direction claire, on ne place pas d'ordre
      }
      
      // Double vérification de sécurité
      if(!zoneMatchesDirection)
      {
         Print("🚫 Opportunité #", i, " REJETÉE: Ne correspond pas à la direction marché (Type=", zoneIsBuy ? "BUY" : "SELL", 
               " Direction=", marketDirection == 1 ? "BUY" : (marketDirection == -1 ? "SELL" : "NEUTRE"), ")");
         continue;
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
      string directionStr = marketDirection == 1 ? "BUY" : (marketDirection == -1 ? "SELL" : "NEUTRE");
      string aiActionStr = (aiDirection == 1 ? "ACHAT (BUY)" : (aiDirection == -1 ? "VENTE (SELL)" : "NEUTRE"));
      Print("🚫 PlaceLimitOrder: Aucune opportunité valide trouvée parmi ", g_opportunitiesCount, 
            " opportunités - Direction marché=", directionStr,
            " | Action IA=", aiActionStr, " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)",
            " | Zone prédite=", (predictionDirection == 1 ? "HAUSSIÈRE" : (predictionDirection == -1 ? "BAISSIÈRE" : "NEUTRE")),
            " | Prédiction valide=", g_predictionValid ? "OUI" : "NON");
      Print("💡 Explication: Les opportunités doivent correspondre à la direction IA/prédiction. ",
            "Si direction=", directionStr, ", seules les opportunités ", directionStr, " sont acceptées.");
      return;
   }
   
   if(DebugMode)
      Print("✅ Meilleure opportunité sélectionnée: Type=", bestOpportunity.isBuy ? "BUY" : "SELL",
            " EntryPrice=", DoubleToString(bestOpportunity.entryPrice, _Digits),
            " PotentialGain=", DoubleToString(bestOpportunity.percentage, 2), "%",
            " Score=", DoubleToString(bestScore, 3));
   
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
   
   // NOUVEAU: Vérifier si le symbole a eu 2 pertes consécutives dans la même direction
   int currentDirection = zoneIsBuy ? 1 : -1;
   if(HasConsecutiveLosses(_Symbol, 2))
   {
      Print("🚫 PlaceLimitOrder: 2 pertes consécutives détectées sur ", _Symbol, 
            " - Attente d'un nouveau signal (direction différente) avant de replacer un ordre LIMIT");
      return;
   }
   
   // Utiliser la meilleure opportunité trouvée
   double entryPriceRaw = bestOpportunity.entryPrice;
   
   // ===== TOUJOURS PLACER SUR SUPPORT/RÉSISTANCE OU TRENDLINE (M1/M5) =====
   ENUM_ORDER_TYPE limitOrderType = zoneIsBuy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   double optimalPrice = FindOptimalLimitOrderPrice(limitOrderType, entryPriceRaw);
   
   double bestLevel = optimalPrice;
   string bestLevelSource = "Support/Résistance ou Trendline (M1/M5)";
   
   // Vérifier que le prix optimal est réaliste (pas trop loin du prix actuel - max 5%)
   double distancePercent = (MathAbs(bestLevel - currentPrice) / currentPrice) * 100.0;
   if(distancePercent > 5.0)
   {
      Print("🚫 Prix optimal trop loin du prix actuel (", DoubleToString(distancePercent, 2), "% > 5%) - Abandon placement");
      return;
   }
   
   double adjustedEntryPrice = bestLevel;
   
   Print("✅ Prix d'entrée OPTIMAL (S/R ou Trendline M1/M5): ", DoubleToString(adjustedEntryPrice, _Digits), 
         " (source: ", bestLevelSource, ", distance: ", DoubleToString(distancePercent, 2), "%)");
   
   if(DebugMode)
      Print("✅ Meilleure opportunité sélectionnée: Type=", zoneIsBuy ? "BUY" : "SELL",
            " EntryPrice=", DoubleToString(adjustedEntryPrice, _Digits),
            " PotentialGain=", DoubleToString(bestOpportunity.percentage, 2), "%",
            " Score=", DoubleToString(bestScore, 3),
            " Décision finale: ", finalDecision.details);
   
   // ===== CALCULER SL ET TP BASÉS SUR DES POINTS FIXES (PLUS FIABLE) =====
   // Pour les ordres LIMIT, utiliser des symbolPoints fixes au lieu de pourcentages
   // Les pourcentages génèrent des prix invalides pour les symboles volatiles
   
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double lotSize = NormalizeLotSize(InitialLotSize);
   double sl = 0, tp = 0;
   
   // Vérifier les niveaux minimums du broker
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * symbolPoint;
   if(minDistance == 0) minDistance = 10 * symbolPoint;
   
   // Utiliser le prix ajusté (près des EMA/S/R) pour calculer SL et TP
   double entryPrice = NormalizeDouble(adjustedEntryPrice, _Digits);
   
   // Déterminer le type de symbole pour les calculs SL/TP
   bool isBoomCrash = IsBoomCrashSymbol(_Symbol);
   bool isVolatility = IsVolatilitySymbol(_Symbol);
   
   // Définir les SL/TP en utilisant les VALEURS DU BROKER (PLUS FIABLE)
   double slPoints = 0, tpPoints = 0;
   
   // Récupérer les vraies valeurs du broker
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   // Calculer les distances minimales selon les règles du broker
   double minSlPoints = 0, minTpPoints = 0;
   
   if(isBoomCrash)
   {
      // Boom/Crash: utiliser des distances en points fixes basées sur l'expérience
      minSlPoints = 300;  // 300 points pour Boom/Crash
      minTpPoints = 600;  // 600 points pour Boom/Crash
   }
   else if(isVolatility)
   {
      // Volatility: adapter selon le type exact
      if(StringFind(_Symbol, "15") != -1)      // Volatility 15
      {
         minSlPoints = 150; // 150 points pour Vol 15
         minTpPoints = 300; // 300 points pour Vol 15
      }
      else if(StringFind(_Symbol, "50") != -1) // Volatility 50
      {
         minSlPoints = 100; // 100 points pour Vol 50
         minTpPoints = 200; // 200 points pour Vol 50
      }
      else if(StringFind(_Symbol, "75") != -1) // Volatility 75
      {
         minSlPoints = 120; // 120 points pour Vol 75
         minTpPoints = 240; // 240 points pour Vol 75
      }
      else if(StringFind(_Symbol, "100") != -1) // Volatility 100
      {
         minSlPoints = 200; // 200 points pour Vol 100
         minTpPoints = 400; // 400 points pour Vol 100
      }
      else // Autres Volatility
      {
         minSlPoints = 150; // 150 points par défaut
         minTpPoints = 300; // 300 points par défaut
      }
   }
   else if(StringFind(_Symbol, "Step") != -1)
   {
      // Step Index: très sensible aux règles du broker
      if(StringFind(_Symbol, "200") != -1)
      {
         minSlPoints = 50;  // 50 points pour Step 200
         minTpPoints = 100; // 100 points pour Step 200
      }
      else if(StringFind(_Symbol, "400") != -1)
      {
         minSlPoints = 80;  // 80 points pour Step 400
         minTpPoints = 160; // 160 points pour Step 400
      }
      else // Autres Step
      {
         minSlPoints = 60;  // 60 points par défaut
         minTpPoints = 120; // 120 points par défaut
      }
   }
   else if(StringFind(_Symbol, "Jump") != -1)
   {
      // Jump Index: utiliser des distances plus grandes
      minSlPoints = 500;  // 500 points pour Jump
      minTpPoints = 1000; // 1000 points pour Jump
   }
   else if(StringFind(_Symbol, "DEX") != -1)
   {
      // DEX Index: distances modérées
      minSlPoints = 300;  // 300 points pour DEX
      minTpPoints = 600;  // 600 points pour DEX
   }
   else
   {
      // Autres symboles (Forex, etc.)
      minSlPoints = 200;  // 200 points par défaut
      minTpPoints = 400;  // 400 points par défaut
   }
   
   // Utiliser les valeurs minimales valides par le broker
   slPoints = minSlPoints;
   tpPoints = minTpPoints;
   
   // S'assurer que les symbolPoints respectent le minimum du broker
   double brokerMinSlPoints = minDistance / symbolPoint;
   double brokerMinTpPoints = minDistance / symbolPoint;
   
   if(slPoints < brokerMinSlPoints) slPoints = brokerMinSlPoints;
   if(tpPoints < brokerMinTpPoints) tpPoints = brokerMinTpPoints;
   
   // Calculer SL et TP en symbolPoints fixes
   if(zoneIsBuy)
   {
      // BUY LIMIT: SL en-dessous de l'entrée, TP au-dessus
      sl = NormalizeDouble(entryPrice - slPoints * symbolPoint, _Digits);
      tp = NormalizeDouble(entryPrice + tpPoints * symbolPoint, _Digits);
   }
   else
   {
      // SELL LIMIT: SL au-dessus de l'entrée, TP en-dessous
      sl = NormalizeDouble(entryPrice + slPoints * symbolPoint, _Digits);
      tp = NormalizeDouble(entryPrice - tpPoints * symbolPoint, _Digits);
   }
   
   // Afficher les calculs pour debug
   Print("🔧 SL/TP BROKER VALUES: Entry=", DoubleToString(entryPrice, _Digits),
         " SL=", DoubleToString(sl, _Digits), " (", DoubleToString(slPoints, 1), " symbolPoints)",
         " TP=", DoubleToString(tp, _Digits), " (", DoubleToString(tpPoints, 1), " symbolPoints)",
         " | Symbole: ", _Symbol,
         " | TickSize: ", DoubleToString(tickSize, _Digits),
         " | Point: ", DoubleToString(symbolPoint, _Digits),
         " | MinDistance: ", DoubleToString(minDistance, _Digits));
   
   // ===== VALIDATION SUPPLÉMENTAIRE POUR ÉVITER LES PRIX INVALIDES =====
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // ===== VALIDATION SPÉCIFIQUE PAR SYMBOLE =====
   bool pricesValid = true;
   string validationError = "";
   
   // Vérifications générales
   if(sl <= 0 || tp <= 0)
   {
      pricesValid = false;
      validationError = "SL ou TP <= 0";
   }
   else if(sl == tp)
   {
      pricesValid = false;
      validationError = "SL == TP";
   }
   
   // Validation stricte pour BUY LIMIT
   if(zoneIsBuy)
   {
      // SL doit être < entryPrice et TP doit être > entryPrice
      if(sl >= entryPrice)
      {
         pricesValid = false;
         validationError = "SL >= EntryPrice (BUY LIMIT)";
         sl = NormalizeDouble(entryPrice - MathMax(minDistance, 10 * symbolPoint), _Digits);
      }
      if(tp <= entryPrice)
      {
         pricesValid = false;
         validationError += (validationError != "" ? ", " : "") + "TP <= EntryPrice (BUY LIMIT)";
         tp = NormalizeDouble(entryPrice + MathMax(minDistance, 15 * symbolPoint), _Digits);
      }
      
      // Vérification finale avec ask price
      if(sl >= ask)
      {
         pricesValid = false;
         validationError += (validationError != "" ? ", " : "") + "SL >= Ask";
         sl = NormalizeDouble(ask - MathMax(minDistance, 10 * symbolPoint), _Digits);
      }
   }
   // Validation stricte pour SELL LIMIT
   else
   {
      // SL doit être > entryPrice et TP doit être < entryPrice
      if(sl <= entryPrice)
      {
         pricesValid = false;
         validationError = "SL <= EntryPrice (SELL LIMIT)";
         sl = NormalizeDouble(entryPrice + MathMax(minDistance, 10 * symbolPoint), _Digits);
      }
      if(tp >= entryPrice)
      {
         pricesValid = false;
         validationError += (validationError != "" ? ", " : "") + "TP >= EntryPrice (SELL LIMIT)";
         tp = NormalizeDouble(entryPrice - MathMax(minDistance, 15 * symbolPoint), _Digits);
      }
      
      // Vérification finale avec bid price
      if(sl <= bid)
      {
         pricesValid = false;
         validationError += (validationError != "" ? ", " : "") + "SL <= Bid";
         sl = NormalizeDouble(bid + MathMax(minDistance, 10 * symbolPoint), _Digits);
      }
   }
   
   // ===== VÉRIFICATIONS SPÉCIFIQUES POUR SYMBOLES VOLATILES =====
   if(isBoomCrash || isVolatility || StringFind(_Symbol, "Step") != -1 || StringFind(_Symbol, "Jump") != -1)
   {
      double priceRange = MathAbs(ask - bid);
      double slDistance = MathAbs(sl - entryPrice);
      double tpDistance = MathAbs(tp - entryPrice);
      
      // Vérifier que les distances ne sont pas trop petites (minimum 3x le spread)
      if(slDistance < priceRange * 3)
      {
         pricesValid = false;
         validationError += (validationError != "" ? ", " : "") + "SL trop proche";
         
         // Ajuster SL
         if(zoneIsBuy)
            sl = NormalizeDouble(entryPrice - priceRange * 5, _Digits);
         else
            sl = NormalizeDouble(entryPrice + priceRange * 5, _Digits);
      }
      
      if(tpDistance < priceRange * 3)
      {
         pricesValid = false;
         validationError += (validationError != "" ? ", " : "") + "TP trop proche";
         
         // Ajuster TP
         if(zoneIsBuy)
            tp = NormalizeDouble(entryPrice + priceRange * 10, _Digits);
         else
            tp = NormalizeDouble(entryPrice - priceRange * 10, _Digits);
      }
   }
   
   // Afficher les erreurs de validation
   if(!pricesValid)
   {
      Print("❌ VALIDATION SL/TP CORRIGÉE: ", validationError);
      Print("🔧 Nouveaux SL/TP: SL=", DoubleToString(sl, _Digits), " TP=", DoubleToString(tp, _Digits));
   }
   
   // ===== VALIDATION FINALE AVANT ENVOI =====
   // Vérification ultime pour éviter les "Invalid price"
   bool finalValidation = true;
   string finalError = "";
   
   if(zoneIsBuy)
   {
      if(sl >= entryPrice || sl >= ask || tp <= entryPrice)
      {
         finalValidation = false;
         finalError = "BUY LIMIT: SL/TP invalides après correction";
      }
   }
   else
   {
      if(sl <= entryPrice || sl <= bid || tp >= entryPrice)
      {
         finalValidation = false;
         finalError = "SELL LIMIT: SL/TP invalides après correction";
      }
   }
   
   if(!finalValidation)
   {
      Print("🚫 VALIDATION FINALE ÉCHOUÉE: ", finalError);
      Print("🔍 Détails: Entry=", DoubleToString(entryPrice, _Digits), 
            " SL=", DoubleToString(sl, _Digits), 
            " TP=", DoubleToString(tp, _Digits),
            " Ask=", DoubleToString(ask, _Digits),
            " Bid=", DoubleToString(bid, _Digits));
      return; // Bloquer l'ordre si la validation finale échoue
   }
   
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
         
         if(SafeOrderSend(deleteRequest, deleteResult))
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
   // NOUVEAU: Vérifier que le prix de l'ordre LIMIT est valide selon les règles du broker
   // BUY_LIMIT doit être < prix actuel (ASK), SELL_LIMIT doit être > prix actuel (BID)
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(zoneIsBuy && entryPrice >= askPrice)
   {
      Print("❌ ERREUR: Prix BUY_LIMIT invalide - ", DoubleToString(entryPrice, _Digits), " >= ASK ", DoubleToString(askPrice, _Digits), 
            " (BUY_LIMIT doit être < prix actuel)");
      // Ajuster le prix à 0.1% en dessous du prix actuel
      entryPrice = NormalizeDouble(askPrice * 0.999, _Digits);
      Print("🔧 Prix ajusté à: ", DoubleToString(entryPrice, _Digits));
   }
   else if(!zoneIsBuy && entryPrice <= bidPrice)
   {
      Print("⚠️ Prix SELL_LIMIT ajusté - ", DoubleToString(entryPrice, _Digits), " <= BID ", DoubleToString(bidPrice, _Digits), 
            " -> Ajustement à ", DoubleToString(bidPrice * 1.001, _Digits));
      // Ajuster le prix à 0.1% au-dessus du prix actuel
      entryPrice = NormalizeDouble(bidPrice * 1.001, _Digits);
      Print("🔧 Prix ajusté à: ", DoubleToString(entryPrice, _Digits));
   }
   
   request.type = zoneIsBuy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   request.price = entryPrice;
   request.sl = sl;
   request.tp = tp;
   
   // ===== VALIDATION COMPLÈTE AVANT ENVOI =====
   // 1. Vérifier le volume
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lotSize < minLot || lotSize > maxLot)
   {
      Print("❌ Ordre LIMIT BLOQUÉ: Volume invalide ", _Symbol, " | Volume: ", lotSize, " (Min: ", minLot, " Max: ", maxLot, ")");
      return;
   }
   
   // 2. Vérifier le prix selon le type d'ordre
   if(zoneIsBuy && entryPrice >= askPrice)
   {
      Print("❌ Ordre LIMIT BLOQUÉ: Prix BUY_LIMIT invalide ", _Symbol, " | Prix: ", entryPrice, " >= ASK: ", askPrice);
      return;
   }
   
   // 3. Vérifier les stops
   if(sl > 0 && tp > 0)
   {
      double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minDistance = MathMax(stopLevel * symbolPoint, symbolPoint * 5);
      
      if(zoneIsBuy)
      {
         // BUY_LIMIT: SL doit être < entryPrice, TP doit être > entryPrice
         if(sl >= entryPrice)
         {
            Print("❌ Ordre LIMIT BLOQUÉ: SL invalide BUY ", _Symbol, " | SL: ", sl, " >= Prix: ", entryPrice);
            return;
         }
         if(tp <= entryPrice)
         {
            Print("❌ Ordre LIMIT BLOQUÉ: TP invalide BUY ", _Symbol, " | TP: ", tp, " <= Prix: ", entryPrice);
            return;
         }
         if(MathAbs(entryPrice - sl) < minDistance)
         {
            Print("❌ Ordre LIMIT BLOQUÉ: Distance SL insuffisante BUY ", _Symbol, " | Distance: ", MathAbs(entryPrice - sl), " < Min: ", minDistance);
            return;
         }
         if(MathAbs(tp - entryPrice) < minDistance)
         {
            Print("❌ Ordre LIMIT BLOQUÉ: Distance TP insuffisante BUY ", _Symbol, " | Distance: ", MathAbs(tp - entryPrice), " < Min: ", minDistance);
            return;
         }
      }
      else
      {
         // SELL_LIMIT: SL doit être > entryPrice, TP doit être < entryPrice
         if(sl <= entryPrice)
         {
            Print("❌ Ordre LIMIT BLOQUÉ: SL invalide SELL ", _Symbol, " | SL: ", sl, " <= Prix: ", entryPrice);
            return;
         }
         if(tp >= entryPrice)
         {
            Print("❌ Ordre LIMIT BLOQUÉ: TP invalide SELL ", _Symbol, " | TP: ", tp, " >= Prix: ", entryPrice);
            return;
         }
         if(MathAbs(sl - entryPrice) < minDistance)
         {
            Print("❌ Ordre LIMIT BLOQUÉ: Distance SL insuffisante SELL ", _Symbol, " | Distance: ", MathAbs(sl - entryPrice), " < Min: ", minDistance);
            return;
         }
         if(MathAbs(entryPrice - tp) < minDistance)
         {
            Print("❌ Ordre LIMIT BLOQUÉ: Distance TP insuffisante SELL ", _Symbol, " | Distance: ", MathAbs(entryPrice - tp), " < Min: ", minDistance);
            return;
         }
      }
   }
   
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
   
   // ===== PRIORITÉ 1: EXÉCUTION DIRECTE POUR DÉCISION FORTE (SELL FORT / BUY FORT à 100%) AVEC REBOND EMA =====
   // Si la décision finale est forte (confiance = 100%) ET le prix a touché l'EMA et rebondi, exécuter directement
   if(finalDecision.confidence >= 1.0 && finalDecision.isValid && finalDecision.direction != 0)
   {
      // Vérifier si le prix a touché l'EMA rapide et rebondi dans la direction du signal
      double emaFast[], emaSlow[], close[], high[], low[];
      ArraySetAsSeries(emaFast, true);
      ArraySetAsSeries(emaSlow, true);
      ArraySetAsSeries(close, true);
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      
      bool hasEmaData = (CopyBuffer(emaFastHandle, 0, 0, 3, emaFast) > 0 &&
                         CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlow) > 0 &&
                         CopyClose(_Symbol, PERIOD_M1, 0, 3, close) > 0 &&
                         CopyHigh(_Symbol, PERIOD_M1, 0, 3, high) > 0 &&
                         CopyLow(_Symbol, PERIOD_M1, 0, 3, low) > 0);
      
      if(hasEmaData)
      {
         bool emaTouched = false;
         bool reboundConfirmed = false;
         double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double tolerance = emaFast[0] * 0.001; // Tolérance de 0.1%
         
         // Vérifier si le prix a touché l'EMA rapide dans les 3 dernières bougies
         for(int j = 0; j < 3; j++)
         {
            if(finalDecision.direction == 1) // BUY FORT
            {
               // Pour BUY: prix a touché l'EMA si low[j] <= emaFast[j] (avec tolérance)
               if(low[j] <= emaFast[j] + tolerance)
               {
                  emaTouched = true;
                  // Vérifier le rebond vers le haut: prix remonte après avoir touché l'EMA
                  if(j < 2 && close[j+1] > emaFast[j+1] && close[j+1] > close[j])
                  {
                     reboundConfirmed = true;
                     Print("✅ BUY: EMA touchée à la bougie ", j, " (low=", DoubleToString(low[j], _Digits), " <= EMA=", DoubleToString(emaFast[j], _Digits), ")");
                     Print("✅ BUY: Rebond confirmé à la bougie ", j+1, " (close=", DoubleToString(close[j+1], _Digits), " > EMA=", DoubleToString(emaFast[j+1], _Digits), ")");
                     break;
                  }
               }
            }
            else if(finalDecision.direction == -1) // SELL FORT
            {
               // Pour SELL: prix a touché l'EMA si high[j] >= emaFast[j] (avec tolérance)
               if(high[j] >= emaFast[j] - tolerance)
               {
                  emaTouched = true;
                  // Vérifier le rebond vers le bas: prix redescend après avoir touché l'EMA
                  if(j < 2 && close[j+1] < emaFast[j+1] && close[j+1] < close[j])
                  {
                     reboundConfirmed = true;
                     Print("✅ SELL: EMA touchée à la bougie ", j, " (high=", DoubleToString(high[j], _Digits), " >= EMA=", DoubleToString(emaFast[j], _Digits), ")");
                     Print("✅ SELL: Rebond confirmé à la bougie ", j+1, " (close=", DoubleToString(close[j+1], _Digits), " < EMA=", DoubleToString(emaFast[j+1], _Digits), ")");
                     break;
                  }
               }
            }
         }
         
         // Si EMA touchée et rebond confirmé, exécuter directement
         if(emaTouched && reboundConfirmed)
         {
            string decisionType = (finalDecision.direction == 1) ? "BUY FORT" : "SELL FORT";
            Print("⚡ EXÉCUTION DIRECTE (Décision forte + Rebond EMA): ", decisionType,
                  " | Confiance: ", DoubleToString(finalDecision.confidence * 100, 1), "%",
                  " | Prix a touché EMA et rebondi dans la direction du signal");
            
            ENUM_ORDER_TYPE executeOrderType = (finalDecision.direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            ExecuteTrade(executeOrderType);
            return; // Sortir, le trade a été exécuté
         }
         else
         {
            if(DebugMode)
            {
               if(!emaTouched)
                  Print("⏸️ Décision forte mais EMA pas encore touchée - Placement ordre LIMIT à la place");
               else if(!reboundConfirmed)
                  Print("⏸️ EMA touchée mais rebond non confirmé - Placement ordre LIMIT à la place");
            }
         }
      }
   }
   
   // ===== PRIORITÉ 2: VÉRIFIER SI ON PEUT EXÉCUTER DIRECTEMENT SI PRIX TRÈS PROCHE =====
   // Si le prix est très proche (< 0.2% du prix actuel), exécuter directement au lieu de placer un ordre LIMIT
   double executeDistancePercent = (MathAbs(entryPrice - currentPrice) / currentPrice) * 100.0;
   double executeThreshold = 0.2; // 0.2% = exécuter directement
   
   if(executeDistancePercent < executeThreshold && finalDecision.confidence >= 0.7)
   {
      // Prix très proche + confiance élevée → Exécuter directement
      Print("⚡ EXÉCUTION DIRECTE (prix très proche): Distance=", DoubleToString(executeDistancePercent, 2), 
            "% < ", DoubleToString(executeThreshold, 2), "%, Confiance=", DoubleToString(finalDecision.confidence * 100, 1), "%");
      
      ENUM_ORDER_TYPE executeOrderType = zoneIsBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      ExecuteTrade(executeOrderType);
      return; // Sortir, le trade a été exécuté
   }
   
   // Log avant placement (toujours affiché, pas seulement en debug)
   string levelInfo = " (optimisé: " + bestLevelSource + ")";
   Print("📋 Tentative placement ordre LIMIT (MEILLEURE OPPORTUNITÉ): ", EnumToString(request.type), 
         " Prix=", DoubleToString(entryPrice, _Digits), levelInfo,
         " Distance du prix actuel=", DoubleToString(MathAbs(entryPrice - currentPrice), _Digits),
         " (", DoubleToString(distancePercent, 2), "%)",
         " SL=", DoubleToString(sl, _Digits), 
         " TP=", DoubleToString(tp, _Digits),
         " Lot=", DoubleToString(lotSize, 2),
         " Gain potentiel=", DoubleToString(bestOpportunity.percentage, 2), "%",
         " Score=", DoubleToString(bestScore, 3),
         " | Direction marché=", marketDirection == 1 ? "BUY" : "SELL",
         " | IA Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%",
         " | Décision finale: Confiance=", DoubleToString(finalDecision.confidence * 100, 1), "%");
   
   // ===== VÉRIFICATION FINALE DE LA FORCE DU SIGNAL AVANT EXÉCUTION =====
   // Vérifier que le signal est toujours fort avant de placer l'ordre limite
   if(g_lastAIConfidence < 0.8) // Seuil de confiance minimal de 80%
   {
      Print("🚫 ORDRE LIMIT ANNULÉ: Signal devenu trop faible (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "% < 80%)");
      return;
   }
   
   // Vérifier que la décision finale est toujours valide
   if(!finalDecision.isValid || finalDecision.confidence < 0.8)
   {
      Print("🚫 ORDRE LIMIT ANNULÉ: Décision finale invalide ou trop faible (Confiance=", DoubleToString(finalDecision.confidence * 100, 1), "% < 80%)");
      return;
   }
   
   // Vérifier la limite de 3 positions maximum
   int activePositions = CountActivePositionsExcludingDuplicates();
   if(activePositions >= 3)
   {
      Print("🚫 ORDRE LIMIT ANNULÉ: Limite de 3 positions atteinte (", activePositions, " >= 3) - Aucun nouvel ordre ne sera placé");
      return;
   }
   
   // Vérifier que la direction du marché est toujours cohérente
   if(marketDirection == 0)
   {
      Print("🚫 ORDRE LIMIT ANNULÉ: Direction du marché non définie");
      return;
   }
   
   // Vérifier que la prédiction est toujours valide
   // SAUF si la décision IA est très forte (>=95%) pour ne pas manquer les opportunités
   bool isPredictionValid = g_predictionValid && ArraySize(g_pricePrediction) > 0;
   bool isStrongAISignal = (UseAI_Agent && g_lastAIAction != "" && g_lastAIConfidence >= 0.95);
   
   if(!isPredictionValid && !isStrongAISignal)
   {
      Print("🚫 ORDRE LIMIT ANNULÉ: Prédiction invalide ou absente et IA pas assez forte");
      return;
   }
   else if(!isPredictionValid && isStrongAISignal)
   {
      Print("⚠️ ORDRE LIMIT AUTORISÉ (EXCEPTION): Prédiction invalide mais IA très forte (", 
            DoubleToString(g_lastAIConfidence * 100, 1), "%) - Ordre autorisé");
   }
   
   // Vérifier que les données IA sont toujours récentes
   int timeSinceAIUpdateFinal = (g_lastAITime > 0) ? (int)(TimeCurrent() - g_lastAITime) : 9999;
   if(timeSinceAIUpdateFinal > AI_UpdateInterval * 2) // Plus de 2x l'intervalle
   {
      Print("🚫 ORDRE LIMIT ANNULÉ: Données IA trop anciennes (", timeSinceAIUpdateFinal, "s > ", AI_UpdateInterval * 2, "s)");
      return;
   }
   
   // Vérifier l'alignement final entre IA et prédiction
   int currentPredictionDirection = 0;
   if(g_predictionValid && ArraySize(g_pricePrediction) > 0)
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double predictedPrice = g_pricePrediction[ArraySize(g_pricePrediction)-1];
      double movementPercent = ((predictedPrice / currentPrice) - 1.0) * 100.0;
      
      if(movementPercent > 0.5) currentPredictionDirection = 1;
      else if(movementPercent < -0.5) currentPredictionDirection = -1;
   }
   
   int currentAIDirection = 0;
   if(g_lastAIAction == "BUY" && g_lastAIConfidence >= 0.5) currentAIDirection = 1;
   else if(g_lastAIAction == "SELL" && g_lastAIConfidence >= 0.5) currentAIDirection = -1;
   
   if(currentAIDirection != currentPredictionDirection)
   {
      Print("🚫 ORDRE LIMIT ANNULÉ: Désalignement final entre IA (", currentAIDirection == 1 ? "BUY" : (currentAIDirection == -1 ? "SELL" : "NEUTRE"), 
            ") et prédiction (", currentPredictionDirection == 1 ? "BUY" : (currentPredictionDirection == -1 ? "SELL" : "NEUTRE"), ")");
      return;
   }
   
   Print("✅ Vérifications finales passées - Signal toujours fort, placement de l'ordre LIMIT...");
   
   if(SafeOrderSend(request, result))
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
//| Utilise plusieurs fenêtres de prédiction (court, moyen, long terme) |
//| et les zones de support/résistance prédites                      |
//+------------------------------------------------------------------+
void UsePredictionForCurrentTrades()
{
   if(!g_predictionValid || ArraySize(g_pricePrediction) < 10)
      return; // Pas de prédiction valide
   
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   
   // ANALYSER PLUSIEURS FENÊTRES DE PRÉDICTION (court, moyen, long terme)
   int windows[] = {5, 10, 20, 50, 100}; // Fenêtres court, moyen, long terme
   double predictedPrices[];
   ArrayResize(predictedPrices, ArraySize(windows));
   double movements[];
   ArrayResize(movements, ArraySize(windows));
   int validWindows = 0;
   double avgMovement = 0.0;
   bool avgBullish = false;
   
   for(int w = 0; w < ArraySize(windows); w++)
   {
      int window = windows[w];
      if(ArraySize(g_pricePrediction) < window)
         continue;
      
      double predPrice = g_pricePrediction[window - 1];
      double movement = predPrice - currentPrice;
      double movementPercent = (MathAbs(movement) / currentPrice) * 100.0;
      
      if(movementPercent > 0.05) // Mouvement significatif (> 0.05%)
      {
         predictedPrices[validWindows] = predPrice;
         movements[validWindows] = movement;
         avgMovement += movement;
         validWindows++;
      }
   }
   
   if(validWindows < 2) // Au moins 2 fenêtres valides
      return;
   
   avgMovement = avgMovement / validWindows;
   avgBullish = (avgMovement > 0);
   
   // DÉTECTER LES ZONES DE SUPPORT/RÉSISTANCE DANS LA PRÉDICTION
   double supportLevel = currentPrice;
   double resistanceLevel = currentPrice;
   
   if(ArraySize(g_pricePrediction) >= 50)
   {
      // Trouver les niveaux de support/résistance dans les 50 prochaines bougies
      double minPrice = currentPrice;
      double maxPrice = currentPrice;
      
      int checkWindow = MathMin(50, ArraySize(g_pricePrediction));
      for(int i = 0; i < checkWindow; i++)
      {
         if(g_pricePrediction[i] < minPrice)
            minPrice = g_pricePrediction[i];
         if(g_pricePrediction[i] > maxPrice)
            maxPrice = g_pricePrediction[i];
      }
      
      supportLevel = minPrice;
      resistanceLevel = maxPrice;
   }
   
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
      bool predictionFavorable = ((posType == POSITION_TYPE_BUY && avgBullish) || 
                                   (posType == POSITION_TYPE_SELL && !avgBullish));
      
      // Calculer le mouvement moyen en pourcentage
      double avgMovementPercent = (MathAbs(avgMovement) / currentPrice) * 100.0;
      
      // NOUVEAU: Ajuster le SL au break-even rapidement si profit >= 0.5$
      // Cela garantit que les trades commencent en profit rapidement
      if(positionProfit >= 0.5 && currentSL > 0)
      {
         double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double minDistance = stopLevel * symbolPoint;
         if(minDistance == 0) minDistance = 10 * symbolPoint;
         
         // Ajuster SL au break-even + petit profit (0.5$)
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double profitNeeded = 0.5;
         
         // VALIDATION: Vérifier que les valeurs sont valides
         if(tickSize <= 0 || symbolPoint <= 0 || lotSize <= 0)
         {
            if(DebugMode)
               Print("❌ Break-even rapide: Valeurs invalides (tickSize=", tickSize, " symbolPoint=", symbolPoint, " lotSize=", lotSize, ")");
            return; // Abandonner cette modification
         }
         
         double symbolPointValue = (tickValue / tickSize) * symbolPoint;
         if(symbolPointValue <= 0)
         {
            if(DebugMode)
               Print("❌ Break-even rapide: symbolPointValue invalide (", symbolPointValue, ")");
            return; // Abandonner cette modification
         }
         
         double profitPerPoint = lotSize * symbolPointValue;
         if(profitPerPoint <= 0)
         {
            if(DebugMode)
               Print("❌ Break-even rapide: profitPerPoint invalide (", profitPerPoint, ")");
            return; // Abandonner cette modification
         }
         
         double priceMove = profitNeeded / profitPerPoint;
         
         // VALIDATION CRITIQUE: Vérifier que priceMove est raisonnable (max 5% du prix)
         double maxPriceMove = currentPrice * 0.05;
         if(priceMove <= 0 || priceMove > maxPriceMove)
         {
            if(DebugMode)
               Print("❌ Break-even rapide: priceMove invalide (", DoubleToString(priceMove, _Digits), 
                     " > max ", DoubleToString(maxPriceMove, _Digits), ")");
            return; // Abandonner cette modification
         }
         
         if(posType == POSITION_TYPE_BUY)
         {
            double securePrice = openPrice + priceMove;
            
            // VALIDATION: Vérifier que securePrice est valide
            if(securePrice <= openPrice || securePrice >= currentPrice || securePrice > currentPrice * 1.05)
            {
               if(DebugMode)
                  Print("❌ Break-even rapide BUY: securePrice invalide (", DoubleToString(securePrice, _Digits), 
                        " openPrice=", DoubleToString(openPrice, _Digits), 
                        " currentPrice=", DoubleToString(currentPrice, _Digits), ")");
               return; // Abandonner cette modification
            }
            
            if(securePrice < currentPrice - minDistance && (currentSL == 0 || securePrice > currentSL))
            {
               newSL = NormalizeDouble(securePrice, _Digits);
               shouldModify = true;
               
               if(DebugMode)
                  Print("✅ Break-even rapide activé (BUY): SL ajusté à ", DoubleToString(newSL, _Digits), 
                        " (profit sécurisé: 0.5$)");
            }
         }
         else // SELL
         {
            double securePrice = openPrice - priceMove;
            
            // VALIDATION: Vérifier que securePrice est valide
            if(securePrice >= openPrice || securePrice <= currentPrice || securePrice < currentPrice * 0.95)
            {
               if(DebugMode)
                  Print("❌ Break-even rapide SELL: securePrice invalide (", DoubleToString(securePrice, _Digits), 
                        " openPrice=", DoubleToString(openPrice, _Digits), 
                        " currentPrice=", DoubleToString(currentPrice, _Digits), ")");
               return; // Abandonner cette modification
            }
            
            if(securePrice > currentPrice + minDistance && (currentSL == 0 || securePrice < currentSL))
            {
               newSL = NormalizeDouble(securePrice, _Digits);
               shouldModify = true;
               
               if(DebugMode)
                  Print("✅ Break-even rapide activé (SELL): SL ajusté à ", DoubleToString(newSL, _Digits), 
                        " (profit sécurisé: 0.5$)");
            }
         }
      }
      
      if(predictionFavorable)
      {
         // Ajuster le SL pour sécuriser plus de profit si la prédiction est favorable
         // Déplacer le SL vers le break-even ou un peu plus haut si on est en profit
         if(positionProfit > 0 && currentSL > 0)
         {
            double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double minDistance = stopLevel * symbolPoint;
            if(minDistance == 0) minDistance = 10 * symbolPoint;
            
            // Déplacer le SL vers le break-even + un petit profit (0.5$)
            double breakEvenPlus = openPrice;
            if(posType == POSITION_TYPE_BUY)
            {
               // Calculer le prix qui donne 0.5$ de profit
               double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
               double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
               double profitNeeded = 0.5;
               
               // VALIDATION: Vérifier que les valeurs sont valides
               if(tickSize <= 0 || symbolPoint <= 0 || lotSize <= 0)
               {
                  if(DebugMode)
                     Print("❌ Prédiction favorable BUY: Valeurs invalides");
                  continue; // Passer au suivant
               }
               
               double symbolPointValue = (tickValue / tickSize) * symbolPoint;
               if(symbolPointValue <= 0)
                  continue; // Passer au suivant
               
               double profitPerPoint = lotSize * symbolPointValue;
               if(profitPerPoint <= 0)
                  continue; // Passer au suivant
               
               double priceMove = profitNeeded / profitPerPoint;
               
               // VALIDATION CRITIQUE: Vérifier que priceMove est raisonnable
               double maxPriceMove = currentPrice * 0.05;
               if(priceMove <= 0 || priceMove > maxPriceMove)
                  continue; // Passer au suivant
               
               double securePrice = openPrice + priceMove;
               
               // VALIDATION: Vérifier que securePrice est valide
               if(securePrice <= openPrice || securePrice >= currentPrice || securePrice > currentPrice * 1.05)
                  continue; // Passer au suivant
               
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
               
               // VALIDATION: Vérifier que les valeurs sont valides
               if(tickSize <= 0 || symbolPoint <= 0 || lotSize <= 0)
               {
                  if(DebugMode)
                     Print("❌ Prédiction favorable SELL: Valeurs invalides");
                  continue; // Passer au suivant
               }
               
               double symbolPointValue = (tickValue / tickSize) * symbolPoint;
               if(symbolPointValue <= 0)
                  continue; // Passer au suivant
               
               double profitPerPoint = lotSize * symbolPointValue;
               if(profitPerPoint <= 0)
                  continue; // Passer au suivant
               
               double priceMove = profitNeeded / profitPerPoint;
               
               // VALIDATION CRITIQUE: Vérifier que priceMove est raisonnable
               double maxPriceMove = currentPrice * 0.05;
               if(priceMove <= 0 || priceMove > maxPriceMove)
                  continue; // Passer au suivant
               
               double securePrice = openPrice - priceMove;
               
               // VALIDATION: Vérifier que securePrice est valide
               if(securePrice >= openPrice || securePrice <= currentPrice || securePrice < currentPrice * 0.95)
                  continue; // Passer au suivant
               
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
         
         // NOUVEAU: Utiliser les zones de support/résistance prédites pour ajuster le TP
         // Augmenter le TP si la prédiction montre un mouvement plus important
         if(currentTP > 0 && avgMovementPercent > 0.2) // Si mouvement moyen prédit > 0.2%
         {
            double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double minDistance = stopLevel * symbolPoint;
            if(minDistance == 0) minDistance = 10 * symbolPoint;
            
            // Utiliser les zones de support/résistance prédites pour ajuster le TP
            double tpAdjustment = 0.0;
            if(posType == POSITION_TYPE_BUY && resistanceLevel > currentPrice)
            {
               // Pour BUY, utiliser la résistance prédite comme TP amélioré
               tpAdjustment = (resistanceLevel - currentTP) * 0.3; // 30% de la distance vers la résistance
            }
            else if(posType == POSITION_TYPE_SELL && supportLevel < currentPrice)
            {
               // Pour SELL, utiliser le support prédit comme TP amélioré
               tpAdjustment = (currentTP - supportLevel) * 0.3; // 30% de la distance vers le support
            }
            else
            {
               // Fallback: augmenter le TP de 20% du mouvement moyen prédit
               tpAdjustment = MathAbs(avgMovement) * 0.2;
            }
            
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
            double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double minDistance = stopLevel * symbolPoint;
            if(minDistance == 0) minDistance = 10 * symbolPoint;
            
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
         
         if(SafeOrderSend(request, result))
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
   
   // ===== NOUVEAU: Vérification périodique de l'état du serveur IA =====
   static datetime lastServerCheck = 0;
   datetime currentTime = TimeCurrent();
   
   // Vérifier le serveur toutes les 2 minutes si les prédictions sont invalides
   if(!g_predictionValid && (currentTime - lastServerCheck) >= 120)
   {
      if(DebugMode)
         Print("🔍 Vérification périodique du serveur IA...");
      DiagnoseServerConnection();
      lastServerCheck = currentTime;
   }

   // ===== PRIORITÉ ABSOLUE: Fermer automatiquement toutes les positions qui atteignent 1$ de profit net par symbole =====
   // Cette vérification doit être faite en premier pour permettre de rentrer à nouveau immédiatement
   string processedSymbols[];
   ArrayResize(processedSymbols, 0);
   
   for(int p = PositionsTotal() - 1; p >= 0; p--)
   {
      ulong profitTicket = PositionGetTicket(p);
      if(profitTicket > 0 && positionInfo.SelectByTicket(profitTicket))
      {
         if(positionInfo.Magic() == InpMagicNumber)
         {
            string symbol = positionInfo.Symbol();
            
            // Vérifier si ce symbole a déjà été traité
            bool alreadyProcessed = false;
            for(int ps = 0; ps < ArraySize(processedSymbols); ps++)
            {
               if(processedSymbols[ps] == symbol)
               {
                  alreadyProcessed = true;
                  break;
               }
            }
            
            if(!alreadyProcessed)
            {
               // Ajouter à la liste des symboles traités
               int size = ArraySize(processedSymbols);
               ArrayResize(processedSymbols, size + 1);
               processedSymbols[size] = symbol;
               
               // Calculer le profit net total pour ce symbole (toutes positions confondues)
               double totalProfitForSymbol = 0.0;
               ulong ticketsToClose[];
               ArrayResize(ticketsToClose, 0);
               
               for(int q = PositionsTotal() - 1; q >= 0; q--)
               {
                  ulong checkTicket = PositionGetTicket(q);
                  if(checkTicket > 0 && positionInfo.SelectByTicket(checkTicket))
                  {
                     if(positionInfo.Magic() == InpMagicNumber && positionInfo.Symbol() == symbol)
                     {
                        double positionProfit = positionInfo.Profit();
                        totalProfitForSymbol += positionProfit;
                        
                        // Ajouter le ticket à la liste de fermeture
                        int ticketSize = ArraySize(ticketsToClose);
                        ArrayResize(ticketsToClose, ticketSize + 1);
                        ticketsToClose[ticketSize] = checkTicket;
                     }
                  }
               }
               
               // Si le profit net total pour ce symbole atteint ou dépasse 1$, fermer toutes les positions
               if(totalProfitForSymbol >= 1.0)
               {
                  Print("💰 PROFIT NET ATTEINT: ", symbol, " - Profit net total: ", DoubleToString(totalProfitForSymbol, 2), "$ >= 1.00$ - Fermeture de toutes les positions");
                  
                  // Fermer toutes les positions de ce symbole (une seule fois par position)
                  for(int t = 0; t < ArraySize(ticketsToClose); t++)
                  {
                     ulong ticketToClose = ticketsToClose[t];
                     
                     // Vérifier que la position existe encore avant de tenter de la fermer
                     if(!positionInfo.SelectByTicket(ticketToClose))
                     {
                        if(DebugMode)
                           Print("⏸️ Position déjà fermée ou inexistante: Ticket ", ticketToClose);
                        continue; // Position déjà fermée, passer à la suivante
                     }
                     
                     double individualProfit = positionInfo.Profit();
                     
                     // Tentative unique de fermeture
                     if(trade.PositionClose(ticketToClose))
                     {
                        Print("✅ Position fermée (profit net 1$): ", symbol, " - Ticket: ", ticketToClose, 
                              " - Profit individuel: ", DoubleToString(individualProfit, 2), "$");
                        // Petite pause pour éviter les conflits
                        Sleep(50);
                     }
                     else
                     {
                        uint retcode = trade.ResultRetcode();
                        string retdesc = trade.ResultRetcodeDescription();
                        
                        // Ignorer l'erreur si la position est déjà en cours de fermeture
                        if(retcode == TRADE_RETCODE_REQUOTE || 
                           StringFind(retdesc, "already exists") >= 0 ||
                           StringFind(retdesc, "Position doesn't exist") >= 0)
                        {
                           if(DebugMode)
                              Print("⏸️ Position déjà en cours de fermeture ou inexistante: Ticket ", ticketToClose, " - ", retdesc);
                        }
                        else
                        {
                           Print("❌ Erreur fermeture position (profit net 1$): ", retcode, " - ", 
                                 retdesc, " - Ticket: ", ticketToClose, " Symbol: ", symbol);
                        }
                     }
                  }
                  
                  Print("🎯 Toutes les positions de ", symbol, " ont été fermées. Prêt pour nouvelle entrée.");
               }
            }
         }
      }
   }

   // NOUVEAU: Fermer les positions Boom/Crash après spike (même gain faible) si aucun autre spike immédiat
   CloseAllBoomCrashAfterSpike();
   
   // NOUVEAU: Vérifier toutes les positions dupliquées par symbole et fermer si profit total >= 2 USD
   string checkedSymbols[];
   ArrayResize(checkedSymbols, 0);
   
   for(int k = PositionsTotal() - 1; k >= 0; k--)
   {
      ulong checkTicket = PositionGetTicket(k);
      if(checkTicket > 0 && positionInfo.SelectByTicket(checkTicket))
      {
         if(positionInfo.Magic() == InpMagicNumber)
         {
            string posSymbol = positionInfo.Symbol();
            
            // Vérifier si ce symbole a déjà été vérifié
            bool alreadyChecked = false;
            for(int s = 0; s < ArraySize(checkedSymbols); s++)
            {
               if(checkedSymbols[s] == posSymbol)
               {
                  alreadyChecked = true;
                  break;
               }
            }
            
            if(!alreadyChecked)
            {
               // Ajouter à la liste des symboles vérifiés
               int size = ArraySize(checkedSymbols);
               ArrayResize(checkedSymbols, size + 1);
               checkedSymbols[size] = posSymbol;
               
               // Vérifier et fermer si profit total >= 2 USD
               CloseDuplicatePositionsIfProfitReached(posSymbol, 2.0);
            }
         }
      }
   }

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
            
            // Mettre à jour l'enregistrement CSV si activé
            if(EnableCSVLogging)
               UpdateTradeRecord(ticket);
            
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
//| Nettoyer toutes les traces d'informations obsolètes sur le graphique |
//+------------------------------------------------------------------+
void CleanAllObsoleteInfoTraces()
{
   // Supprimer TOUS les objets graphiques d'information obsolètes
   int total = ObjectsTotal(0);
   int deletedCount = 0;
   
   // Préfixes des objets à supprimer (toutes les anciennes traces)
   string obsoletePrefixes[] = {
      "AI_CONFIDENCE_", "AI_TREND_SUMMARY_", "AI_PREDICTION_ZONE_", 
      "AI_ALIGNMENT_", "AI_FINAL_DECISION_", "MARKET_STATE_", 
      "MARKET_TREND_", "AI_SEPARATOR_", "COHERENCE_PANEL_",
      "COHERENCE_TITLE_", "AI_ANALYSIS_", "GLOBAL_TREND_",
      "M5_TREND_", "PREDICTION_", "STABILITY_", "AI_ZONE_",
      "OPPORTUNITY_", "EMA_Fast_", "EMA_Slow_", "EMA_50_",
      "EMA_100_", "FRACTAL_", "DERIV_", "SUPPORT_", 
      "RESISTANCE_", "SMC_", "TRENDLINE_", "ARROW_",
      "SIGNAL_", "LEVEL_", "ZONE_", "PANEL_"
   };
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(name == "")
         continue;
      
      // Vérifier si c'est un objet obsolète à supprimer
      bool deleteObject = false;
      for(int k = 0; k < ArraySize(obsoletePrefixes); k++)
      {
         if(StringFind(name, obsoletePrefixes[k]) >= 0)
         {
            deleteObject = true;
            break;
         }
      }
      
      if(deleteObject)
      {
         ObjectDelete(0, name);
         deletedCount++;
      }
   }
   
   if(DebugMode || deletedCount > 0)
      Print("🧹 Nettoyage des traces obsolètes: ", deletedCount, " objets supprimés");
}

//+------------------------------------------------------------------+
//| Nettoyer TOUS les objets graphiques au démarrage                  |
//+------------------------------------------------------------------+
void CleanAllGraphicalObjects()
{
   // Utiliser la nouvelle fonction de nettoyage améliorée
   CleanAllObsoleteInfoTraces();
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
   string objectsToKeep[] = {"AI_CONFIDENCE_", "AI_TREND_SUMMARY_", "AI_PREDICTION_ZONE_", "AI_ALIGNMENT_", "AI_FINAL_DECISION_", "MARKET_STATE_", "MARKET_TREND_", "AI_SEPARATOR_",
                              "EMA_Fast_", "EMA_Slow_", "EMA_50_", "EMA_100_", "EMA_200_", 
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
//| Affiche UNIQUEMENT les opportunités alignées avec IA + Prédiction |
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
   
   // ===== VÉRIFIER L'ALIGNEMENT IA + PRÉDICTION AVANT D'AFFICHER =====
   // Déterminer la direction IA
   int aiDirection = 0;
   if(g_lastAIAction == "buy")
      aiDirection = 1; // IA recommande ACHAT
   else if(g_lastAIAction == "sell")
      aiDirection = -1; // IA recommande VENTE
   else if(g_api_trend_direction != 0)
      aiDirection = g_api_trend_direction;
   
   // Déterminer la direction de la zone prédite
   int predictionDirection = 0;
   int predSize = ArraySize(g_pricePrediction);
   if(g_predictionValid && predSize >= 20)
   {
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
      int predictionWindow = MathMin(20, predSize);
      double predictedPrice = g_pricePrediction[predictionWindow - 1];
      double priceMovement = predictedPrice - currentPrice;
      double movementPercent = (MathAbs(priceMovement) / currentPrice) * 100.0;
      
      if(movementPercent > 0.05) // Mouvement significatif
      {
         if(priceMovement > 0)
            predictionDirection = 1; // Zone prédite haussière
         else
            predictionDirection = -1; // Zone prédite baissière
      }
   }
   
   // Vérifier l'alignement : les deux doivent être alignés pour afficher des opportunités
   bool isAligned = (aiDirection != 0 && predictionDirection != 0 && aiDirection == predictionDirection);
   int alignedDirection = isAligned ? aiDirection : 0;
   
   // Si pas d'alignement, masquer le panneau et ne rien afficher
   if(!isAligned)
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
      // Ne rien afficher si pas d'alignement
      return;
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
   
   // ===== FILTRER LES OPPORTUNITÉS SELON L'ALIGNEMENT =====
   // Créer un tableau temporaire pour les opportunités alignées
   TradingOpportunity alignedOpportunities[];
   int alignedCount = 0;
   
   for(int i = 0; i < g_opportunitiesCount; i++)
   {
      bool zoneIsBuy = g_opportunities[i].isBuy;
      
      // Ne garder que les opportunités qui correspondent à la direction alignée
      if((alignedDirection == 1 && zoneIsBuy) || (alignedDirection == -1 && !zoneIsBuy))
      {
         int size = ArraySize(alignedOpportunities);
         ArrayResize(alignedOpportunities, size + 1);
         alignedOpportunities[size] = g_opportunities[i];
         alignedCount++;
      }
   }
   
   // ===== AFFICHER SEULEMENT L'OPPORTUNITÉ LA PLUS CONFIANTE =====
   if(alignedCount == 0)
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
   
   // Trouver l'opportunité avec la plus haute confiance
   TradingOpportunity bestOpp = {0}; // Initialiser pour éviter l'erreur
   double bestConfidence = 0.0;
   int bestIndex = -1;
   
   for(int i = 0; i < alignedCount; i++)
   {
      double confidence = alignedOpportunities[i].priority; // priority = confiance
      if(confidence > bestConfidence)
      {
         bestConfidence = confidence;
         bestOpp = alignedOpportunities[i];
         bestIndex = i;
      }
   }
   
   // Si toujours pas de meilleure opportunité, masquer le panneau
   if(bestIndex == -1)
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
   
   // Dimensions du panneau (compact pour une seule opportunité)
   int panelX = 10;  // Distance depuis le bord droit (sera ajusté dynamiquement)
   int panelY = 80;  // Distance depuis le haut (sous le panneau IA)
   int panelWidth = 250; // Largeur compacte
   int panelHeight = 45; // Hauteur pour une seule ligne + marge
   
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
   ObjectSetString(0, titleName, OBJPROP_TEXT, "🎯 MEILLEURE OPPORTUNITÉ");
   ObjectSetInteger(0, titleName, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, titleName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, titleName, OBJPROP_SELECTABLE, false);
   
   // Afficher UNIQUEMENT la meilleure opportunité
   string oppName = "OPP_BEST_" + _Symbol;
   if(ObjectFind(0, oppName) < 0)
      ObjectCreate(0, oppName, OBJ_LABEL, 0, 0, 0);
   
   int yPos = panelY + 25;
   color oppColor = bestOpp.isBuy ? clrLime : clrRed;
   
   // Format amélioré pour la meilleure opportunité
   string directionText = bestOpp.isBuy ? "🟢 BUY" : "🔴 SELL";
   string confidenceText = "Confiance: " + DoubleToString(bestConfidence * 100, 1) + "%";
   string priceText = "Prix: " + DoubleToString(bestOpp.entryPrice, _Digits);
   string gainText = "Gain: +" + DoubleToString(bestOpp.percentage, 1) + "%";
   
   string oppText = directionText + " | " + confidenceText + " | " + gainText + " | " + priceText;
   
   ObjectSetInteger(0, oppName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, oppName, OBJPROP_XDISTANCE, panelX + 5);
   ObjectSetInteger(0, oppName, OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, oppName, OBJPROP_TEXT, oppText);
   ObjectSetInteger(0, oppName, OBJPROP_COLOR, oppColor);
   ObjectSetInteger(0, oppName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, oppName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, oppName, OBJPROP_SELECTABLE, false);
   
   // Supprimer les anciennes opportunités multiples
   for(int i = 0; i < 10; i++)
   {
      string oldOppName = "OPP_" + IntegerToString(i) + "_" + _Symbol;
      ObjectDelete(0, oldOppName);
   }
}

//+------------------------------------------------------------------+
//| Dessiner confiance IA, état du marché et résumés de tendance    |
//+------------------------------------------------------------------+
void DrawAIConfidenceAndTrendSummary()
{
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
   {
      // Message plus informatif quand l'IA n'a pas encore répondu
      if(g_lastAITime == 0)
         aiText += "INITIALISATION...";
      else if(TimeCurrent() - g_lastAITime > AI_UpdateInterval * 3)
         aiText += "CONNEXION PERDUE (" + IntegerToString((int)(TimeCurrent() - g_lastAITime)) + "s)";
      else if(!UseAI_Agent)
         aiText += "IA DÉSACTIVÉE";
      else
         aiText += "ATTENTE " + DoubleToString(g_lastAIConfidence * 100, 0) + "%";
   }
   
   ObjectSetString(0, aiLabelName, OBJPROP_TEXT, aiText);
   ObjectSetInteger(0, aiLabelName, OBJPROP_COLOR, (g_lastAIAction == "buy") ? clrLime : (g_lastAIAction == "sell") ? clrRed : clrYellow);
   ObjectSetInteger(0, aiLabelName, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, aiLabelName, OBJPROP_FONT, "Arial Bold");
   
   // ===== NOUVEAU: Afficher l'état de connexion au serveur IA =====
   string connLabelName = "CONNECTION_STATUS_" + _Symbol;
   if(ObjectFind(0, connLabelName) < 0)
      ObjectCreate(0, connLabelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, connLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, connLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, connLabelName, OBJPROP_YDISTANCE, 50);
   
   string connText = "🌐 Connexion: ";
   color connColor = clrYellow;
   
   if(!UseAI_Agent || StringLen(AI_ServerURL) == 0)
   {
      connText += "IA DÉSACTIVÉE";
      connColor = clrGray;
   }
   else if(!g_predictionValid)
   {
      connText += "ERREUR (récupération...)";
      connColor = clrOrange;
   }
   else if(TimeCurrent() - g_lastAITime > AI_UpdateInterval * 3)
   {
      connText += "PERDUE (" + IntegerToString((int)(TimeCurrent() - g_lastAITime)) + "s)";
      connColor = clrRed;
   }
   else
   {
      connText += "OK (" + IntegerToString((int)(TimeCurrent() - g_lastAITime)) + "s)";
      connColor = clrLime;
   }
   
   ObjectSetString(0, connLabelName, OBJPROP_TEXT, connText);
   ObjectSetInteger(0, connLabelName, OBJPROP_COLOR, connColor);
   ObjectSetInteger(0, connLabelName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, connLabelName, OBJPROP_FONT, "Arial");
   
   // État du marché depuis l'API
   string marketStateText = "CHARGEMENT...";
   string marketTrendText = "EN COURS";
   color marketStateColor = clrYellow;
   
   // Log de débogage pour voir si la fonction est appelée
   Print("[HUD] Mise à jour état du marché pour ", _Symbol, " - UseTrendAPIAnalysis: ", UseTrendAPIAnalysis ? "true" : "false");
   
   // Récupérer l'état du marché depuis l'API
   if(UseTrendAPIAnalysis)
   {
      // Construire l'URL correcte pour l'état du marché
      string baseURL = AI_ServerURL;
      // Enlever /decision si présent pour utiliser /market-state
      if(StringFind(baseURL, "/decision") >= 0)
      {
         baseURL = StringSubstr(baseURL, 0, StringLen(baseURL) - 9); // Enlever "/decision"
      }
      // S'assurer qu'il n'y a pas de double slash
      if(StringSubstr(baseURL, StringLen(baseURL) - 1) == "/")
      {
         baseURL = StringSubstr(baseURL, 0, StringLen(baseURL) - 1); // Enlever le slash final
      }
      string marketStateURL = baseURL + "/market-state?symbol=" + _Symbol + "&timeframe=M1";
      string response = "";
      string headers = "";
      uchar data[];          // Vide pour GET
      uchar result[];         // Résultat
      string result_headers = "";  // En-têtes de réponse
      
      // Log de débogage pour l'URL
      Print("[HUD] URL état du marché: ", marketStateURL);
      
      // Utiliser la signature correcte de WebRequest
      int webResult = WebRequest("GET", marketStateURL, "", 5000, data, result, result_headers);
      
      Print("[HUD] WebRequest résultat: ", webResult, " pour ", _Symbol);
      
      if(webResult == 200)
      {
         // Convertir le résultat en chaîne de caractères
         response = CharArrayToString(result);
         // Parser simple de la réponse JSON pour extraire market_state et market_trend
         string stateKey = "\"market_state\":\"";
         string trendKey = "\"market_trend\":\"";
         
         int statePos = StringFind(response, stateKey);
         int trendPos = StringFind(response, trendKey);
         
         if(statePos >= 0)
         {
            int stateStart = statePos + StringLen(stateKey);
            int stateEnd = StringFind(response, "\"", stateStart);
            if(stateEnd > stateStart)
            {
               marketStateText = StringSubstr(response, stateStart, stateEnd - stateStart);
               
               // Couleur selon l'état
               if(StringFind(marketStateText, "TENDANCE_HAUSSIERE") >= 0)
                  marketStateColor = clrLime;
               else if(StringFind(marketStateText, "TENDANCE_BAISSIERE") >= 0)
                  marketStateColor = clrRed;
               else if(StringFind(marketStateText, "RANGE") >= 0)
                  marketStateColor = clrYellow;
               else if(StringFind(marketStateText, "CORRECTION") >= 0)
                  marketStateColor = clrOrange;
               else
                  marketStateColor = clrGray;
            }
         }
         
         if(trendPos >= 0)
         {
            int trendStart = trendPos + StringLen(trendKey);
            int trendEnd = StringFind(response, "\"", trendStart);
            if(trendEnd > trendStart)
            {
               marketTrendText = StringSubstr(response, trendStart, trendEnd - trendStart);
            }
         }
         
         // Log des valeurs extraites
         Print("[HUD] État extrait: '", marketStateText, "' - Tendance: '", marketTrendText, "' pour ", _Symbol);
      }
      else
      {
         // Erreur API - afficher message clair
         marketStateText = "ERREUR API " + IntegerToString(webResult);
         marketTrendText = "CODE: " + IntegerToString(webResult);
         marketStateColor = clrRed;
         
         // Log de l'erreur pour débogage
         Print("[ERREUR] État du marché API - Code: ", webResult, " - URL: ", marketStateURL);
      }
   }
   else
   {
      marketStateText = "API DÉSACTIVÉE";
      marketStateColor = clrGray;
   }
   
   // Afficher l'état du marché
   string marketStateLabelName = "MARKET_STATE_" + _Symbol;
   if(ObjectFind(0, marketStateLabelName) < 0)
      ObjectCreate(0, marketStateLabelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, marketStateLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, marketStateLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, marketStateLabelName, OBJPROP_YDISTANCE, 55);
   ObjectSetString(0, marketStateLabelName, OBJPROP_TEXT, "État: " + marketStateText);
   ObjectSetInteger(0, marketStateLabelName, OBJPROP_COLOR, marketStateColor);
   ObjectSetInteger(0, marketStateLabelName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, marketStateLabelName, OBJPROP_FONT, "Arial Bold");
   
   // Afficher la tendance du marché (seconde ligne)
   string marketTrendLabelName = "MARKET_TREND_" + _Symbol;
   if(ObjectFind(0, marketTrendLabelName) < 0)
      ObjectCreate(0, marketTrendLabelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, marketTrendLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, marketTrendLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, marketTrendLabelName, OBJPROP_YDISTANCE, 75);
   ObjectSetString(0, marketTrendLabelName, OBJPROP_TEXT, "Tendance: " + marketTrendText);
   ObjectSetInteger(0, marketTrendLabelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, marketTrendLabelName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, marketTrendLabelName, OBJPROP_FONT, "Arial");
   
   // Ajouter un séparateur visuel
   string separatorName = "AI_SEPARATOR_" + _Symbol;
   if(ObjectFind(0, separatorName) < 0)
      ObjectCreate(0, separatorName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, separatorName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, separatorName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, separatorName, OBJPROP_YDISTANCE, 95);
   ObjectSetString(0, separatorName, OBJPROP_TEXT, "━━━━━━━━━━━━━━━━━━━━━━");
   ObjectSetInteger(0, separatorName, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, separatorName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, separatorName, OBJPROP_FONT, "Arial");
   
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
      int yOffset = 110;  // Ajusté pour tenir compte de l'état du marché
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
   string coherencePanelName = "COHERENCE_PANEL_" + _Symbol;
   if(ObjectFind(0, coherencePanelName) < 0)
      ObjectCreate(0, coherencePanelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, coherencePanelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, coherencePanelName, OBJPROP_XDISTANCE, 5);
   ObjectSetInteger(0, coherencePanelName, OBJPROP_YDISTANCE, 155);
   ObjectSetInteger(0, coherencePanelName, OBJPROP_XSIZE, 380);
   ObjectSetInteger(0, coherencePanelName, OBJPROP_YSIZE, 180);
   ObjectSetInteger(0, coherencePanelName, OBJPROP_COLOR, clrNONE);
   ObjectSetInteger(0, coherencePanelName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, coherencePanelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, coherencePanelName, OBJPROP_BORDER_COLOR, clrDarkGray);
   ObjectSetInteger(0, coherencePanelName, OBJPROP_BACK, true);
   
   // Titre du panneau
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
   
   // --- DÉTAILS PAR ÉLÉMENT D'ANALYSE ---
   int yOffset = 180;
   
   // 1. Analyse IA avec poids
   string iaAnalysisName = "IA_ANALYSIS_" + _Symbol;
   if(ObjectFind(0, iaAnalysisName) < 0)
      ObjectCreate(0, iaAnalysisName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, iaAnalysisName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, iaAnalysisName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, iaAnalysisName, OBJPROP_YDISTANCE, yOffset);
   
   string iaText = "";
   if(g_lastAIAction == "buy")
   {
      iaText = "🤖 IA: BUY [" + DoubleToString(g_lastAIConfidence * 100, 1) + "%] ⚖️ POIDS: 40%";
      ObjectSetInteger(0, iaAnalysisName, OBJPROP_COLOR, clrLime);
   }
   else if(g_lastAIAction == "sell")
   {
      iaText = "🤖 IA: SELL [" + DoubleToString(g_lastAIConfidence * 100, 1) + "%] ⚖️ POIDS: 40%";
      ObjectSetInteger(0, iaAnalysisName, OBJPROP_COLOR, clrRed);
   }
   else
   {
      iaText = "🤖 IA: NEUTRE ⚖️ POIDS: 40%";
      ObjectSetInteger(0, iaAnalysisName, OBJPROP_COLOR, clrYellow);
   }
   
   ObjectSetString(0, iaAnalysisName, OBJPROP_TEXT, iaText);
   ObjectSetInteger(0, iaAnalysisName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, iaAnalysisName, OBJPROP_FONT, "Arial");
   
   yOffset += 15;
   
   // 2. Tendance Globale H1 avec poids
   string globalTrendName = "GLOBAL_TREND_" + _Symbol;
   if(ObjectFind(0, globalTrendName) < 0)
      ObjectCreate(0, globalTrendName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, globalTrendName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, globalTrendName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, globalTrendName, OBJPROP_YDISTANCE, yOffset);
   
   string globalTrendText = "";
   color globalTrendColor = clrYellow;
   
   // Calculer la tendance H1 avec plus de détails (réutiliser les variables déjà déclarées)
   if(CopyBuffer(emaFastH1Handle, 0, 0, 8, emaFastH1) >= 8 && CopyBuffer(emaSlowH1Handle, 0, 0, 8, emaSlowH1) >= 8)
   {
      int bullishCount = 0;
      int bearishCount = 0;
      
      for(int i = 0; i < 8; i++)
      {
         if(emaFastH1[i] > emaSlowH1[i])
            bullishCount++;
         else
            bearishCount++;
      }
      
      double h1Confidence = (bullishCount > bearishCount) ? bullishCount / 8.0 : bearishCount / 8.0;
      
      if(bullishCount >= 6)
      {
         globalTrendText = "🌍 GLOBAL H1: BUY [" + DoubleToString(h1Confidence * 100, 0) + "%] ⚖️ POIDS: 35%";
         globalTrendColor = clrLime;
      }
      else if(bearishCount >= 6)
      {
         globalTrendText = "🌍 GLOBAL H1: SELL [" + DoubleToString(h1Confidence * 100, 0) + "%] ⚖️ POIDS: 35%";
         globalTrendColor = clrRed;
      }
      else
      {
         globalTrendText = "🌍 GLOBAL H1: NEUTRE [" + DoubleToString(h1Confidence * 100, 0) + "%] ⚖️ POIDS: 35%";
         globalTrendColor = clrYellow;
      }
   }
   else
   {
      globalTrendText = "🌍 GLOBAL H1: EN CHARGEMENT... ⚖️ POIDS: 35%";
      globalTrendColor = clrGray;
   }
   
   ObjectSetString(0, globalTrendName, OBJPROP_TEXT, globalTrendText);
   ObjectSetInteger(0, globalTrendName, OBJPROP_COLOR, globalTrendColor);
   ObjectSetInteger(0, globalTrendName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, globalTrendName, OBJPROP_FONT, "Arial");
   
   yOffset += 15;
   
   // 3. Tendance M5 (timeframe de trading) avec poids
   string m5TrendName = "M5_TREND_" + _Symbol;
   if(ObjectFind(0, m5TrendName) < 0)
      ObjectCreate(0, m5TrendName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, m5TrendName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, m5TrendName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, m5TrendName, OBJPROP_YDISTANCE, yOffset);
   
   string m5TrendText = "";
   color m5TrendColor = clrYellow;
   
   // Calculer la tendance M5 (réutiliser les variables déjà déclarées)
   if(CopyBuffer(emaFastM5Handle, 0, 0, 12, emaFastM5) >= 12 && CopyBuffer(emaSlowM5Handle, 0, 0, 12, emaSlowM5) >= 12)
   {
      int m5BullishCount = 0;
      int m5BearishCount = 0;
      double angleSum = 0.0;
      
      for(int i = 0; i < 12; i++)
      {
         if(emaFastM5[i] > emaSlowM5[i])
            m5BullishCount++;
         else
            m5BearishCount++;
         
         if(i > 0)
         {
            double fastDiff = emaFastM5[i] - emaFastM5[i-1];
            double slowDiff = emaSlowM5[i] - emaSlowM5[i-1];
            angleSum += (fastDiff - slowDiff);
         }
      }
      
      double m5Confidence = (m5BullishCount > m5BearishCount) ? m5BullishCount / 12.0 : m5BearishCount / 12.0;
      
      if(m5BullishCount >= 8 && angleSum > 0)
      {
         m5TrendText = "⚡ M5 TRADING: BUY [" + DoubleToString(m5Confidence * 100, 0) + "%] ⚖️ POIDS: 25%";
         m5TrendColor = clrLime;
      }
      else if(m5BearishCount >= 8 && angleSum < 0)
      {
         m5TrendText = "⚡ M5 TRADING: SELL [" + DoubleToString(m5Confidence * 100, 0) + "%] ⚖️ POIDS: 25%";
         m5TrendColor = clrRed;
      }
      else if(m5BullishCount >= 8)
      {
         m5TrendText = "⚡ M5 TRADING: BUY [" + DoubleToString(m5Confidence * 100, 0) + "%] ⚖️ POIDS: 25%";
         m5TrendColor = clrLime;
      }
      else if(m5BearishCount >= 8)
      {
         m5TrendText = "⚡ M5 TRADING: SELL [" + DoubleToString(m5Confidence * 100, 0) + "%] ⚖️ POIDS: 25%";
         m5TrendColor = clrRed;
      }
      else
      {
         m5TrendText = "⚡ M5 TRADING: NEUTRE [" + DoubleToString(m5Confidence * 100, 0) + "%] ⚖️ POIDS: 25%";
         m5TrendColor = clrYellow;
      }
   }
   else
   {
      m5TrendText = "⚡ M5 TRADING: EN CHARGEMENT... ⚖️ POIDS: 25%";
      m5TrendColor = clrGray;
   }
   
   ObjectSetString(0, m5TrendName, OBJPROP_TEXT, m5TrendText);
   ObjectSetInteger(0, m5TrendName, OBJPROP_COLOR, m5TrendColor);
   ObjectSetInteger(0, m5TrendName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, m5TrendName, OBJPROP_FONT, "Arial");
   
   yOffset += 15;
   
   // 4. Validation de prédiction avec poids
   string predictionValidationName = "PREDICTION_VALIDATION_" + _Symbol;
   if(ObjectFind(0, predictionValidationName) < 0)
      ObjectCreate(0, predictionValidationName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, predictionValidationName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, predictionValidationName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, predictionValidationName, OBJPROP_YDISTANCE, yOffset);
   
   string predictionText = "";
   color predictionColor = clrYellow;
   
   if(g_predictionValid && ArraySize(g_pricePrediction) >= 20)
   {
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
      int window = MathMin(30, ArraySize(g_pricePrediction));
      double predictedPrice = g_pricePrediction[window - 1];
      double movement = predictedPrice - currentPrice;
      double movementPercent = (MathAbs(movement) / currentPrice) * 100.0;
      
      if(movementPercent > 0.03)
      {
         string direction = (movement > 0) ? "BUY" : "SELL";
         double predConfidence = MathMin(movementPercent / 1.5, 1.0);
         predictionText = "🔮 PRÉDICTION: " + direction + " [" + DoubleToString(predConfidence * 100, 1) + "%] ⚖️ BONUS: 10%";
         predictionColor = (movement > 0) ? clrLime : clrRed;
      }
      else
      {
         predictionText = "🔮 PRÉDICTION: NEUTRE [0%] ⚖️ BONUS: 0%";
         predictionColor = clrYellow;
      }
   }
   else
   {
      predictionText = "🔮 PRÉDICTION: EN ATTENTE... ⚖️ BONUS: 0%";
      predictionColor = clrGray;
   }
   
   ObjectSetString(0, predictionValidationName, OBJPROP_TEXT, predictionText);
   ObjectSetInteger(0, predictionValidationName, OBJPROP_COLOR, predictionColor);
   ObjectSetInteger(0, predictionValidationName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, predictionValidationName, OBJPROP_FONT, "Arial");
   
   yOffset += 20;
   
   // --- LIGNE DE SÉPARATION ---
   string separator2Name = "COHERENCE_SEPARATOR_" + _Symbol;
   if(ObjectFind(0, separator2Name) < 0)
      ObjectCreate(0, separator2Name, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, separator2Name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, separator2Name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, separator2Name, OBJPROP_YDISTANCE, yOffset);
   ObjectSetString(0, separator2Name, OBJPROP_TEXT, "─────────────────────────────────");
   ObjectSetInteger(0, separator2Name, OBJPROP_COLOR, clrDarkGray);
   ObjectSetInteger(0, separator2Name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, separator2Name, OBJPROP_FONT, "Arial");
   
   yOffset += 12;
   
   // --- DÉCISION FINALE AVEC SCORE DE COHÉRENCE ---
   string finalDecisionName = "FINAL_DECISION_" + _Symbol;
   if(ObjectFind(0, finalDecisionName) < 0)
      ObjectCreate(0, finalDecisionName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, finalDecisionName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, finalDecisionName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, finalDecisionName, OBJPROP_YDISTANCE, yOffset);
   
   string finalText = "";
   color finalColor = clrYellow;
   
   if(hasDecision && finalDecision.direction != 0)
   {
      string direction = (finalDecision.direction == 1) ? "BUY" : "SELL";
      double score = finalDecision.confidence;
      
      // Calculer le score de cohérence
      double coherenceScore = 0.0;
      string coherenceStatus = "";
      
      if(finalDecision.isValid)
      {
         coherenceScore = score;
         coherenceStatus = "✅ COHÉRENT";
         finalColor = (finalDecision.direction == 1) ? clrLime : clrRed;
      }
      else
      {
         coherenceStatus = "⚠️ INCOHÉRENT";
         finalColor = clrOrange;
      }
      
      finalText = "🎯 DÉCISION: " + direction + " [" + DoubleToString(score * 100, 1) + "%] " + coherenceStatus;
   }
   else
   {
      finalText = "🎯 DÉCISION: EN ANALYSE... [0%] ⏳";
      finalColor = clrYellow;
   }
   
   ObjectSetString(0, finalDecisionName, OBJPROP_TEXT, finalText);
   ObjectSetInteger(0, finalDecisionName, OBJPROP_COLOR, finalColor);
   ObjectSetInteger(0, finalDecisionName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, finalDecisionName, OBJPROP_FONT, "Arial Bold");
   
   yOffset += 15;
   
   // --- DÉTAILS DE LA DÉCISION ---
   string decisionDetailsName = "DECISION_DETAILS_" + _Symbol;
   if(ObjectFind(0, decisionDetailsName) < 0)
      ObjectCreate(0, decisionDetailsName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, decisionDetailsName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, decisionDetailsName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, decisionDetailsName, OBJPROP_YDISTANCE, yOffset);
   
   string detailsText = "";
   if(hasDecision && StringLen(finalDecision.details) > 0)
   {
      // Formatter les détails pour plus de lisibilité
      detailsText = "📋 " + finalDecision.details;
   }
   else
   {
      detailsText = "📋 Analyse en cours...";
   }
   
   ObjectSetString(0, decisionDetailsName, OBJPROP_TEXT, detailsText);
   ObjectSetInteger(0, decisionDetailsName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, decisionDetailsName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, decisionDetailsName, OBJPROP_FONT, "Arial");
   
   yOffset += 12;
   
   // --- INDICATEUR DE STABILITÉ ---
   string stabilityName = "STABILITY_INDICATOR_" + _Symbol;
   if(ObjectFind(0, stabilityName) < 0)
      ObjectCreate(0, stabilityName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, stabilityName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, stabilityName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, stabilityName, OBJPROP_YDISTANCE, yOffset);
   
   string stabilityText = "";
   color stabilityColor = clrYellow;
   
   if(g_currentDecisionStability.direction != 0)
   {
      int stabilitySeconds = g_currentDecisionStability.stabilitySeconds;
      int requiredSeconds = MinStabilitySeconds;
      
      if(stabilitySeconds >= requiredSeconds)
      {
         stabilityText = "⏱️ STABILITÉ: " + IntegerToString(stabilitySeconds) + "s ✅ (Requis: " + IntegerToString(requiredSeconds) + "s)";
         stabilityColor = clrLime;
      }
      else
      {
         stabilityText = "⏱️ STABILITÉ: " + IntegerToString(stabilitySeconds) + "s ⏳ (Requis: " + IntegerToString(requiredSeconds) + "s)";
         stabilityColor = clrYellow;
      }
   }
   else
   {
      stabilityText = "⏱️ STABILITÉ: EN ATTENTE... (Requis: " + IntegerToString(MinStabilitySeconds) + "s)";
      stabilityColor = clrGray;
   }
   
   ObjectSetString(0, stabilityName, OBJPROP_TEXT, stabilityText);
   ObjectSetInteger(0, stabilityName, OBJPROP_COLOR, stabilityColor);
   ObjectSetInteger(0, stabilityName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, stabilityName, OBJPROP_FONT, "Arial");
   
   // --- 3. Alignement des 3 critères (IA, Tendances, Prédiction) ---
   string alignmentLabelName = "AI_ALIGNMENT_" + _Symbol;
   if(ObjectFind(0, alignmentLabelName) < 0)
      ObjectCreate(0, alignmentLabelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, alignmentLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, alignmentLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, alignmentLabelName, OBJPROP_YDISTANCE, 150);
   
   string alignmentText = "Alignement 3 critères: ";
   int buyVotes = 0;
   int sellVotes = 0;
   int totalVotes = 0;
   
   // IA
   if(UseAI_Agent && g_lastAITime > 0 && (TimeCurrent() - g_lastAITime) < AI_UpdateInterval * 2)
   {
      if(g_lastAIAction == "buy") { buyVotes++; totalVotes++; }
      else if(g_lastAIAction == "sell") { sellVotes++; totalVotes++; }
   }
   
   // Tendances (EMA M1, M5, H1)
   if(hasData)
   {
      if(emaFastM1[0] > emaSlowM1[0]) { buyVotes++; totalVotes++; } else if(emaFastM1[0] < emaSlowM1[0]) { sellVotes++; totalVotes++; }
      if(emaFastM5[0] > emaSlowM5[0]) { buyVotes++; totalVotes++; } else if(emaFastM5[0] < emaSlowM5[0]) { sellVotes++; totalVotes++; }
      if(emaFastH1[0] > emaSlowH1[0]) { buyVotes++; totalVotes++; } else if(emaFastH1[0] < emaSlowH1[0]) { sellVotes++; totalVotes++; }
   }
   
   // Prédiction
   if(g_predictionValid && ArraySize(g_pricePrediction) >= 20)
   {
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
      int predictionWindow = MathMin(20, ArraySize(g_pricePrediction));
      double predictedPrice = g_pricePrediction[predictionWindow - 1];
      double priceMovement = predictedPrice - currentPrice;
      double movementPercent = (MathAbs(priceMovement) / currentPrice) * 100.0;
      
      if(movementPercent > 0.05)
      {
         if(priceMovement > 0) { buyVotes++; totalVotes++; }
         else { sellVotes++; totalVotes++; }
      }
   }
   
   if(totalVotes > 0)
   {
      if(buyVotes >= 3)
         alignmentText += "BUY (" + IntegerToString(buyVotes) + "/" + IntegerToString(totalVotes) + ")";
      else if(sellVotes >= 3)
         alignmentText += "SELL (" + IntegerToString(sellVotes) + "/" + IntegerToString(totalVotes) + ")";
      else
         alignmentText += "NEUTRE (" + IntegerToString(MathMax(buyVotes, sellVotes)) + "/" + IntegerToString(totalVotes) + ")";
   }
   else
      alignmentText += "INSUFFISANT";
   
   ObjectSetString(0, alignmentLabelName, OBJPROP_TEXT, alignmentText);
   ObjectSetInteger(0, alignmentLabelName, OBJPROP_COLOR, (buyVotes >= 3) ? clrLime : (sellVotes >= 3) ? clrRed : clrYellow);
   ObjectSetInteger(0, alignmentLabelName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, alignmentLabelName, OBJPROP_FONT, "Arial Bold");
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
   // MAIS uniquement si le profit est >= 1$ (MIN_PROFIT_TO_CLOSE)
   if((currentProfit >= BoomCrashSpikeTP || spikeDetected) && currentProfit >= MIN_PROFIT_TO_CLOSE)
   {
      if(trade.PositionClose(ticket))
      {
         string reason = spikeDetected ? "Spike détecté" : "Profit seuil atteint";
         Print("✅ Position Boom/Crash fermée: ", reason, " - Profit=", DoubleToString(currentProfit, 2),
               "$ (seuil=", DoubleToString(BoomCrashSpikeTP, 2), "$, minimum=", DoubleToString(MIN_PROFIT_TO_CLOSE, 2), "$)");
         
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
   else if(DebugMode && (currentProfit >= BoomCrashSpikeTP || spikeDetected) && currentProfit < MIN_PROFIT_TO_CLOSE)
   {
      Print("⏸️ Position Boom/Crash conservée: Profit=", DoubleToString(currentProfit, 2), 
            "$ < minimum requis (", DoubleToString(MIN_PROFIT_TO_CLOSE, 2), "$) - Attendre au moins 1$");
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
//| Calculer SL/TP en symbolPoints à partir des valeurs USD               |
//+------------------------------------------------------------------+
void CalculateSLTPInPoints(ENUM_POSITION_TYPE posType, double entryPrice, double &sl, double &tp)
{
   double lotSize = (g_positionTracker.currentLot > 0) ? g_positionTracker.currentLot : InitialLotSize;
   
   // Calculer la valeur du symbolPoint
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Si tickValue est en devise de base, convertir
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double symbolPointValue = (tickValue / tickSize) * symbolPoint;
   
   // Calculer les symbolPoints nécessaires pour atteindre les valeurs USD
   double slPoints = 0, tpPoints = 0;
   
   if(symbolPointValue > 0 && lotSize > 0)
   {
      // Points pour SL
      double slValuePerPoint = lotSize * symbolPointValue;
      if(slValuePerPoint > 0)
         slPoints = StopLossUSD / slValuePerPoint;
      
      // Points pour TP
      double tpValuePerPoint = lotSize * symbolPointValue;
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
         // Utiliser 2x ATR pour SL et 6x ATR pour TP (mouvements longs - ratio 3:1)
         slPoints = (2.0 * atr[0]) / symbolPoint;
         tpPoints = (6.0 * atr[0]) / symbolPoint; // Augmenté de 4x à 6x pour cibler les mouvements longs
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
      sl = NormalizeDouble(entryPrice - slPoints * symbolPoint, _Digits);
      tp = NormalizeDouble(entryPrice + tpPoints * symbolPoint, _Digits);
   }
   else // SELL
   {
      sl = NormalizeDouble(entryPrice + slPoints * symbolPoint, _Digits);
      tp = NormalizeDouble(entryPrice - tpPoints * symbolPoint, _Digits);
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
         sl = NormalizeDouble(entryPrice - slPoints * symbolPoint, _Digits);
         if(sl >= entryPrice)
         {
            // Si toujours incorrect, utiliser ATR comme fallback
            double atr[];
            ArraySetAsSeries(atr, true);
            if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
               sl = NormalizeDouble(entryPrice - (2.0 * atr[0]), _Digits);
            else
               sl = NormalizeDouble(entryPrice - (50 * symbolPoint), _Digits);
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
         sl = NormalizeDouble(entryPrice + slPoints * symbolPoint, _Digits);
         if(sl <= entryPrice)
         {
            // Si toujours incorrect, utiliser ATR comme fallback
            double atr[];
            ArraySetAsSeries(atr, true);
            if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
               sl = NormalizeDouble(entryPrice + (2.0 * atr[0]), _Digits);
            else
               sl = NormalizeDouble(entryPrice + (50 * symbolPoint), _Digits);
         }
      }
   }
   
   // CALCUL ROBUSTE des niveaux minimums du broker
   // Note: tickValue et tickSize sont déjà déclarés au début de la fonction
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   
   // Calculer minDistance en utilisant stopLevel ET tickSize
   double minDistance = stopLevel * symbolPoint;
   
   // Si stopLevel = 0, utiliser une distance minimale basée sur le tickSize
   if(minDistance == 0 || minDistance < tickSize)
   {
      // Utiliser au moins 3 ticks comme distance minimum
      minDistance = tickSize * 3;
      if(minDistance == 0)
         minDistance = 10 * symbolPoint; // Fallback si tickSize = 0
   }
   
   // S'assurer que minDistance est au moins de 5 symbolPoints pour éviter les erreurs
   if(minDistance < (5 * symbolPoint))
      minDistance = 5 * symbolPoint;
   
   // Ajuster SL pour respecter minDistance
   double slDistance = MathAbs(entryPrice - sl);
   if(slDistance < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         sl = NormalizeDouble(entryPrice - minDistance - (symbolPoint * 2), _Digits); // Ajouter un peu de marge
      else
         sl = NormalizeDouble(entryPrice + minDistance + (symbolPoint * 2), _Digits);
      
      // Recalculer slDistance après ajustement
      slDistance = MathAbs(entryPrice - sl);
   }
   
   // Ajuster TP pour respecter minDistance
   double tpDistance = MathAbs(tp - entryPrice);
   if(tpDistance < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(entryPrice + minDistance + (symbolPoint * 2), _Digits);
      else
         tp = NormalizeDouble(entryPrice - minDistance - (symbolPoint * 2), _Digits);
      
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
//| Calculer SL/TP en symbolPoints avec limite de perte maximale            |
//+------------------------------------------------------------------+
void CalculateSLTPInPointsWithMaxLoss(ENUM_POSITION_TYPE posType, double entryPrice, double lotSize, double maxLossUSD, double &sl, double &tp)
{
   // Calculer la valeur du symbolPoint
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double symbolPointValue = (tickValue / tickSize) * symbolPoint;
   
   // Calculer les symbolPoints nécessaires pour la perte maximale
   double slPoints = 0, tpPoints = 0;
   
   if(symbolPointValue > 0 && lotSize > 0)
   {
      double slValuePerPoint = lotSize * symbolPointValue;
      if(slValuePerPoint > 0)
         slPoints = maxLossUSD / slValuePerPoint;
      
      // TP standard
      double tpValuePerPoint = lotSize * symbolPointValue;
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
         if(slPoints <= 0 && symbolPointValue > 0 && lotSize > 0)
            slPoints = MathMin((maxLossUSD / (lotSize * symbolPointValue)), (2.0 * atr[0]) / symbolPoint);
         if(tpPoints <= 0)
            tpPoints = (6.0 * atr[0]) / symbolPoint; // Augmenté de 4x à 6x pour cibler les mouvements longs
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
      sl = NormalizeDouble(entryPrice - slPoints * symbolPoint, _Digits);
      tp = NormalizeDouble(entryPrice + tpPoints * symbolPoint, _Digits);
   }
   else // SELL
   {
      sl = NormalizeDouble(entryPrice + slPoints * symbolPoint, _Digits);
      tp = NormalizeDouble(entryPrice - tpPoints * symbolPoint, _Digits);
   }
   
   // CALCUL ROBUSTE des niveaux minimums du broker (même logique que CalculateSLTPInPoints)
   // Note: tickSize est déjà déclaré au début de la fonction
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * symbolPoint;
   
   if(minDistance == 0 || minDistance < tickSize)
   {
      minDistance = tickSize * 3;
      if(minDistance == 0)
         minDistance = 10 * symbolPoint;
   }
   
   if(minDistance < (5 * symbolPoint))
      minDistance = 5 * symbolPoint;
   
   // Ajuster SL
   double slDistance = MathAbs(entryPrice - sl);
   if(slDistance < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         sl = NormalizeDouble(entryPrice - minDistance - (symbolPoint * 2), _Digits);
      else
         sl = NormalizeDouble(entryPrice + minDistance + (symbolPoint * 2), _Digits);
      slDistance = MathAbs(entryPrice - sl);
   }
   
   // Ajuster TP
   double tpDistance = MathAbs(tp - entryPrice);
   if(tpDistance < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(entryPrice + minDistance + (symbolPoint * 2), _Digits);
      else
         tp = NormalizeDouble(entryPrice - minDistance - (symbolPoint * 2), _Digits);
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
   // Calculer la valeur du symbolPoint
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // VALIDATION: Vérifier que les valeurs sont valides
   if(tickSize <= 0 || symbolPoint <= 0 || currentPrice <= 0 || openPrice <= 0)
   {
      if(DebugMode)
         Print("❌ CalculateDynamicSLTPForDouble: Valeurs invalides - tickSize=", tickSize, " symbolPoint=", symbolPoint, " currentPrice=", currentPrice, " openPrice=", openPrice);
      CalculateSLTPInPointsWithMaxLoss(posType, currentPrice, lotSize, 3.0, sl, tp);
      return;
   }
   
   double symbolPointValue = (tickValue / tickSize) * symbolPoint;
   
   // Calculer SL pour sécuriser les gains (éviter de perdre plus de maxDrawdownAllowed)
   double slPoints = 0;
   if(symbolPointValue > 0 && lotSize > 0 && securedProfit > 0)
   {
      double slValuePerPoint = lotSize * symbolPointValue;
      if(slValuePerPoint > 0)
         slPoints = maxDrawdownAllowed / slValuePerPoint;
   }
   
   // VALIDATION: Vérifier que slPoints est raisonnable (max 10% du prix actuel)
   double maxSlPoints = (currentPrice * 0.10) / symbolPoint; // Maximum 10% du prix en symbolPoints
   if(slPoints > maxSlPoints || slPoints <= 0)
   {
      if(DebugMode)
         Print("⚠️ CalculateDynamicSLTPForDouble: slPoints invalide (", slPoints, " > max ", maxSlPoints, ") - Utilisation SL standard");
      CalculateSLTPInPointsWithMaxLoss(posType, currentPrice, lotSize, 3.0, sl, tp);
      return;
   }
   
   // Si on a déjà des gains, le SL doit être au-dessus (BUY) ou en-dessous (SELL) du prix d'entrée
   // pour sécuriser au moins 50% des gains
   if(securedProfit > 0 && slPoints > 0)
   {
      if(posType == POSITION_TYPE_BUY)
      {
         // Pour BUY, SL doit être au-dessus du prix d'entrée pour sécuriser les gains
         sl = NormalizeDouble(openPrice + slPoints * symbolPoint, _Digits);
         
         // VALIDATION: Vérifier que le SL est valide (en-dessous du prix actuel et au-dessus du prix d'entrée)
         if(sl >= currentPrice)
            sl = NormalizeDouble(currentPrice - symbolPoint, _Digits);
         if(sl < openPrice)
            sl = NormalizeDouble(openPrice + symbolPoint, _Digits);
            
         // VALIDATION FINALE: Vérifier que le SL n'est pas aberrant (max 5% du prix)
         if(sl > currentPrice * 1.05 || sl < openPrice)
         {
            if(DebugMode)
               Print("❌ CalculateDynamicSLTPForDouble: SL BUY invalide (", sl, ") - Utilisation SL standard");
            CalculateSLTPInPointsWithMaxLoss(posType, currentPrice, lotSize, 3.0, sl, tp);
            return;
         }
      }
      else // SELL
      {
         // Pour SELL, SL doit être en-dessous du prix d'entrée pour sécuriser les gains
         sl = NormalizeDouble(openPrice - slPoints * symbolPoint, _Digits);
         
         // VALIDATION: Vérifier que le SL est valide (au-dessus du prix actuel et en-dessous du prix d'entrée)
         if(sl <= currentPrice)
            sl = NormalizeDouble(currentPrice + symbolPoint, _Digits);
         if(sl > openPrice)
            sl = NormalizeDouble(openPrice - symbolPoint, _Digits);
            
         // VALIDATION FINALE: Vérifier que le SL n'est pas aberrant (max 5% du prix)
         if(sl < currentPrice * 0.95 || sl > openPrice)
         {
            if(DebugMode)
               Print("❌ CalculateDynamicSLTPForDouble: SL SELL invalide (", sl, ") - Utilisation SL standard");
            CalculateSLTPInPointsWithMaxLoss(posType, currentPrice, lotSize, 3.0, sl, tp);
            return;
         }
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
      double tpPoints = (TakeProfitUSD / (lotSize * symbolPointValue));
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(currentPrice + tpPoints * symbolPoint, _Digits);
      else
         tp = NormalizeDouble(currentPrice - tpPoints * symbolPoint, _Digits);
   }
   
   // Vérifier les niveaux minimums du broker
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * symbolPoint;
   if(minDistance == 0) minDistance = 10 * symbolPoint;
   
   if(MathAbs(currentPrice - sl) < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         sl = NormalizeDouble(currentPrice - minDistance - symbolPoint, _Digits);
      else
         sl = NormalizeDouble(currentPrice + minDistance + symbolPoint, _Digits);
   }
   
   if(MathAbs(tp - currentPrice) < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(currentPrice + minDistance + symbolPoint, _Digits);
      else
         tp = NormalizeDouble(currentPrice - minDistance - symbolPoint, _Digits);
   }
}

//+------------------------------------------------------------------+
//| Enregistrer une perte pour un symbole                           |
//+------------------------------------------------------------------+
void RecordSymbolLoss(string symbol, int direction, double profit)
{
   // Si profit >= 0, ce n'est pas une perte, réinitialiser le tracker
   if(profit >= 0)
   {
      ResetSymbolLossTracker(symbol, direction);
      return;
   }
   
   // Trouver ou créer le tracker pour ce symbole
   int trackerIndex = -1;
   for(int i = 0; i < ArraySize(g_symbolLossTrackers); i++)
   {
      if(g_symbolLossTrackers[i].symbol == symbol)
      {
         trackerIndex = i;
         break;
      }
   }
   
   if(trackerIndex < 0)
   {
      // Créer un nouveau tracker
      int size = ArraySize(g_symbolLossTrackers);
      ArrayResize(g_symbolLossTrackers, size + 1);
      trackerIndex = size;
      g_symbolLossTrackers[trackerIndex].symbol = symbol;
      g_symbolLossTrackers[trackerIndex].consecutiveLosses = 0;
      g_symbolLossTrackers[trackerIndex].lastDirection = 0;
      g_symbolLossTrackers[trackerIndex].lastLossTime = 0;
   }
   
   // Vérifier si c'est la même direction que la dernière perte
   if(g_symbolLossTrackers[trackerIndex].lastDirection == direction)
   {
      // Même direction : incrémenter le compteur de pertes consécutives
      g_symbolLossTrackers[trackerIndex].consecutiveLosses++;
      g_symbolLossTrackers[trackerIndex].lastLossTime = TimeCurrent();
      
      Print("📉 Perte enregistrée pour ", symbol, " - Direction: ", (direction == 1 ? "BUY" : "SELL"),
            " | Perte: ", DoubleToString(profit, 2), " USD",
            " | Pertes consécutives: ", g_symbolLossTrackers[trackerIndex].consecutiveLosses);
   }
   else
   {
      // Direction différente : réinitialiser le compteur
      g_symbolLossTrackers[trackerIndex].consecutiveLosses = 1;
      g_symbolLossTrackers[trackerIndex].lastDirection = direction;
      g_symbolLossTrackers[trackerIndex].lastLossTime = TimeCurrent();
      
      Print("📉 Nouvelle perte pour ", symbol, " - Direction: ", (direction == 1 ? "BUY" : "SELL"),
            " | Perte: ", DoubleToString(profit, 2), " USD",
            " | Compteur réinitialisé (nouvelle direction)");
   }
}

//+------------------------------------------------------------------+
//| Vérifier si un symbole a eu des pertes consécutives             |
//+------------------------------------------------------------------+
bool HasConsecutiveLosses(string symbol, int maxLosses = 2)
{
   for(int i = 0; i < ArraySize(g_symbolLossTrackers); i++)
   {
      if(g_symbolLossTrackers[i].symbol == symbol)
      {
         if(g_symbolLossTrackers[i].consecutiveLosses >= maxLosses)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Réinitialiser le tracker si nouvelle direction                   |
//+------------------------------------------------------------------+
void ResetSymbolLossTracker(string symbol, int newDirection)
{
   for(int i = 0; i < ArraySize(g_symbolLossTrackers); i++)
   {
      if(g_symbolLossTrackers[i].symbol == symbol)
      {
         // Si la direction change, réinitialiser le compteur
         if(g_symbolLossTrackers[i].lastDirection != 0 && g_symbolLossTrackers[i].lastDirection != newDirection)
         {
            g_symbolLossTrackers[i].consecutiveLosses = 0;
            g_symbolLossTrackers[i].lastDirection = newDirection;
            
            if(DebugMode)
               Print("🔄 Tracker réinitialisé pour ", symbol, " - Nouvelle direction: ", (newDirection == 1 ? "BUY" : "SELL"));
         }
         else if(g_symbolLossTrackers[i].lastDirection == 0)
         {
            // Première fois : initialiser
            g_symbolLossTrackers[i].lastDirection = newDirection;
            g_symbolLossTrackers[i].consecutiveLosses = 0;
         }
         // Si même direction et profit positif, réinitialiser aussi
         else if(g_symbolLossTrackers[i].lastDirection == newDirection)
         {
            g_symbolLossTrackers[i].consecutiveLosses = 0;
         }
         return;
      }
   }
   
   // Si le tracker n'existe pas encore, le créer
   int size = ArraySize(g_symbolLossTrackers);
   ArrayResize(g_symbolLossTrackers, size + 1);
   g_symbolLossTrackers[size].symbol = symbol;
   g_symbolLossTrackers[size].consecutiveLosses = 0;
   g_symbolLossTrackers[size].lastDirection = newDirection;
   g_symbolLossTrackers[size].lastLossTime = 0;
}

//+------------------------------------------------------------------+
//| Vérifier l'état des deux derniers trades fermés                  |
//| Retourne: 1 = 2 trades gagnants successifs, -1 = 2 trades perdants successifs, 0 = autre |
//+------------------------------------------------------------------+
int GetLastTwoTradesStatus()
{
   // Trouver les deux trades fermés avec les closeTime les plus récents
   TradeRecord lastTwoTrades[2];
   datetime maxCloseTime1 = 0;
   datetime maxCloseTime2 = 0;
   int index1 = -1;
   int index2 = -1;
   
   // Parcourir tous les trades pour trouver les deux plus récents
   for(int i = 0; i < g_tradeRecordsCount; i++)
   {
      if(g_tradeRecords[i].isClosed && g_tradeRecords[i].closeTime > 0)
      {
         if(g_tradeRecords[i].closeTime > maxCloseTime1)
         {
            // Nouveau trade le plus récent
            maxCloseTime2 = maxCloseTime1;
            index2 = index1;
            maxCloseTime1 = g_tradeRecords[i].closeTime;
            index1 = i;
         }
         else if(g_tradeRecords[i].closeTime > maxCloseTime2)
         {
            // Nouveau deuxième plus récent
            maxCloseTime2 = g_tradeRecords[i].closeTime;
            index2 = i;
         }
      }
   }
   
   // Si on n'a pas au moins 2 trades fermés, retourner 0 (état neutre)
   if(index1 < 0 || index2 < 0)
   {
      if(DebugMode)
         Print("🔍 GetLastTwoTradesStatus: Moins de 2 trades fermés trouvés - État neutre");
      return 0;
   }
   
   // Récupérer les deux trades les plus récents (le plus récent en premier)
   lastTwoTrades[0] = g_tradeRecords[index1]; // Le plus récent
   lastTwoTrades[1] = g_tradeRecords[index2]; // Le deuxième plus récent
   
   // Vérifier les deux derniers trades
   bool firstTradeWon = (lastTwoTrades[0].profit > 0);
   bool secondTradeWon = (lastTwoTrades[1].profit > 0);
   
   // Deux trades gagnants successifs
   if(firstTradeWon && secondTradeWon)
   {
      if(DebugMode)
         Print("🎉 GetLastTwoTradesStatus: 2 trades gagnants successifs détectés - Récompense activée | Trade 1: ", 
               DoubleToString(lastTwoTrades[0].profit, 2), " USD | Trade 2: ", 
               DoubleToString(lastTwoTrades[1].profit, 2), " USD");
      return 1; // Récompense
   }
   
   // Deux trades perdants successifs
   if(!firstTradeWon && !secondTradeWon)
   {
      if(DebugMode)
         Print("⚠️ GetLastTwoTradesStatus: 2 trades perdants successifs détectés - Sanction activée | Trade 1: ", 
               DoubleToString(lastTwoTrades[0].profit, 2), " USD | Trade 2: ", 
               DoubleToString(lastTwoTrades[1].profit, 2), " USD");
      return -1; // Sanction
   }
   
   // Cas mixte (un gagnant, un perdant) - état neutre
   if(DebugMode)
      Print("🔍 GetLastTwoTradesStatus: Trades mixtes - État neutre | Trade 1: ", 
            DoubleToString(lastTwoTrades[0].profit, 2), " USD | Trade 2: ", 
            DoubleToString(lastTwoTrades[1].profit, 2), " USD");
   return 0;
}

//+------------------------------------------------------------------+
//| Appliquer récompense ou sanction basée sur les derniers trades  |
//| Retourne: confiance ajustée, modifie maxActivePositions si nécessaire |
//+------------------------------------------------------------------+
double ApplyTradeMotivation(double baseConfidence, int &maxActivePositions)
{
   int status = GetLastTwoTradesStatus();
   double adjustedConfidence = baseConfidence;
   int originalMaxPositions = maxActivePositions;
   
   if(status == 1)
   {
      // RÉCOMPENSE: 2 trades gagnants successifs
      // Réduire légèrement le seuil de confiance requis (bonus de 5%)
      adjustedConfidence = baseConfidence - 0.05;
      if(adjustedConfidence < 0.50) adjustedConfidence = 0.50; // Minimum 50%
      
      // Augmenter légèrement le nombre max de positions (bonus de +1 position)
      maxActivePositions = originalMaxPositions + 1;
      
      if(DebugMode)
         Print("🎁 RÉCOMPENSE APPLIQUÉE: Confiance requise réduite de ", 
               DoubleToString(baseConfidence * 100, 1), "% à ", 
               DoubleToString(adjustedConfidence * 100, 1), "% | Max positions: ", 
               originalMaxPositions, " → ", maxActivePositions);
   }
   else if(status == -1)
   {
      // SANCTION: 2 trades perdants successifs
      // Augmenter le seuil de confiance requis (pénalité de 10%)
      adjustedConfidence = baseConfidence + 0.10;
      if(adjustedConfidence > 1.0) adjustedConfidence = 1.0; // Maximum 100%
      
      // Réduire le nombre max de positions (pénalité de -1 position, minimum 1)
      maxActivePositions = originalMaxPositions - 1;
      if(maxActivePositions < 1) maxActivePositions = 1;
      
      if(DebugMode)
         Print("🔒 SANCTION APPLIQUÉE: Confiance requise augmentée de ", 
               DoubleToString(baseConfidence * 100, 1), "% à ", 
               DoubleToString(adjustedConfidence * 100, 1), "% | Max positions: ", 
               originalMaxPositions, " → ", maxActivePositions);
   }
   else
   {
      // État neutre - pas de modification
      adjustedConfidence = baseConfidence;
      maxActivePositions = originalMaxPositions;
   }
   
   return adjustedConfidence;
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
   // ===== BLOQUER LES ORDRES LIMITES POUR MÉTAUX, CRYPTO ET FOREX =====
   if((orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) && IsMetalCryptoOrForexSymbol())
   {
      if(DebugMode)
         Print("🚫 ExecuteUSTrade: BLOQUÉ - Ordre limite non autorisé pour symbole ", _Symbol, " (métal, crypto ou Forex)");
      return false;
   }
   
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
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minDistance = stopLevel * symbolPoint;
   
   if(minDistance == 0 || minDistance < tickSize)
   {
      minDistance = tickSize * 3;
      if(minDistance == 0)
         minDistance = 10 * symbolPoint;
   }
   
   if(minDistance < (5 * symbolPoint))
      minDistance = 5 * symbolPoint;
   
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
   // ===== NOUVEAU: PRIORITÉ 0 - VÉRIFIER LA DÉCISION FINALE CONSOLIDÉE AVEC STABILITÉ =====
   // Si la décision finale est valide (isValid = true avec >= 5 votes alignés), 
   // vérifier qu'elle est stable depuis au moins 5 minutes avant d'exécuter
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
         bool isVeryHighConfidence = (finalDecision.confidence >= 0.80); // 80%+ = exécution immédiate
         bool canExecuteImmediately = isVeryHighConfidence || (g_currentDecisionStability.stabilitySeconds >= MinStabilitySeconds);
         
         if(canExecuteImmediately)
         {
            // Décision stable ou confiance très élevée - Vérifier qu'on n'est pas déjà en position
            bool hasOpenPosition = false;
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
               ulong ticket = PositionGetTicket(i);
               if(ticket > 0 && positionInfo.SelectByTicket(ticket))
               {
                  if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
                  {
                     hasOpenPosition = true;
                     break;
                  }
               }
            }
            
            if(!hasOpenPosition)
            {
               ENUM_ORDER_TYPE decisionOrderType = (finalDecision.direction == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
               
               Print("⚡ DÉCISION FINALE STABLE ET VALIDE: ", (finalDecision.direction == 1 ? "BUY FORT" : "SELL FORT"),
                     " | Confiance: ", DoubleToString(finalDecision.confidence * 100, 1), "%",
                     " | Stabilité: ", g_currentDecisionStability.stabilitySeconds, "s (requis: ", MinStabilitySeconds, "s)",
                     " | ", finalDecision.details);
               
               if(isVeryHighConfidence)
                  Print("🚀 EXÉCUTION IMMÉDIATE - Confiance très élevée: ", DoubleToString(finalDecision.confidence * 100, 1), "% >= 80%");
               else
                  Print("🚀 EXÉCUTION DIRECTE basée sur décision finale stable (>= ", MinStabilitySeconds, "s)");
               
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
               if(DebugMode)
                  Print("⏸️ Décision finale stable mais position déjà ouverte - Pas de nouveau trade");
            }
         }
         else
         {
            // Décision pas encore stable - Afficher le temps restant
            int remainingSeconds = MinStabilitySeconds - g_currentDecisionStability.stabilitySeconds;
            static datetime lastStabilityLog = 0;
            if(TimeCurrent() - lastStabilityLog >= 30) // Log toutes les 30 secondes
            {
               Print("⏳ DÉCISION FINALE EN ATTENTE DE STABILITÉ: ", (finalDecision.direction == 1 ? "BUY" : "SELL"),
                     " | Stabilité actuelle: ", g_currentDecisionStability.stabilitySeconds, "s / ", MinStabilitySeconds, "s",
                     " | Temps restant: ", remainingSeconds, "s",
                     " | ", finalDecision.details);
               lastStabilityLog = TimeCurrent();
            }
         }
      }
      else
      {
         // Décision invalide ou neutre : réinitialiser le suivi
         if(g_currentDecisionStability.direction != 0 || g_currentDecisionStability.isValid)
         {
            if(DebugMode)
               Print("🔄 DÉCISION FINALE DEVENUE INVALIDE/NEUTRE - Réinitialisation du suivi de stabilité");
            g_currentDecisionStability.direction = 0;
            g_currentDecisionStability.firstSeen = 0;
            g_currentDecisionStability.lastSeen = 0;
            g_currentDecisionStability.isValid = false;
            g_currentDecisionStability.stabilitySeconds = 0;
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
   
   // Détecter le mode prudent (profit net journalier >= 50 USD)
   bool cautiousMode = (g_dailyProfit >= 50.0);
   
   // SEUIL ADAPTATIF selon la force du signal
   // Le serveur IA garantit maintenant :
   // - 60% minimum si H1 aligné
   // - 70% minimum si H1+H4/D1 alignés
   // - 55% minimum si M5+H1 alignés
   // IMPORTANT: Augmenter le seuil pour éviter les trades avec signaux faibles
   double requiredConfidence = cautiousMode ? 0.80 : 0.65; // 80% en mode prudent, 65% normalement (augmenté de 60%)
   
   // Détection des types de symboles
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   bool isStepIndex = (StringFind(_Symbol, "Step") != -1 || StringFind(_Symbol, "Step Index") != -1);
   bool isForexSymbol = IsForexSymbol(_Symbol);
   bool isVolatilitySymbol = IsVolatilitySymbol(_Symbol);
   
   // Pour Boom/Crash, seuil plus bas car les spikes sont rapides (50%)
   if(isBoomCrashSymbol && !cautiousMode)
   {
      requiredConfidence = 0.50; // 50% pour Boom/Crash
   }
   // Pour Step Index et Volatility, seuil minimum 50% (CRITIQUE pour éviter trades avec 32%)
   else if((isStepIndex || isVolatilitySymbol) && !isBoomCrashSymbol && !cautiousMode)
   {
      requiredConfidence = 0.50; // 50% minimum pour Step Index et Volatility (IMPORTANT!)
      if(DebugMode)
         Print("📊 Seuil Step/Volatility appliqué: ", _Symbol, " requiert ", DoubleToString(requiredConfidence * 100, 0), "% (Confiance actuelle: ", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
   }
   // Pour Forex, seuil encore plus élevé (70%) car on doit attendre SL/TP
   else if(isForexSymbol && !isBoomCrashSymbol && !isStepIndex && !isVolatilitySymbol && !cautiousMode)
   {
      requiredConfidence = 0.70; // 70% pour Forex (signaux plus sûrs requis)
   }
   

   // RÈGLE STRICTE : Si l'IA est activée, TOUJOURS vérifier la confiance AVANT de trader
   if(UseAI_Agent)
   {
      // VÉRIFICATION PRIORITAIRE: Vérifier que les données IA sont récentes (moins de 2x l'intervalle)
      int timeSinceAIUpdate = (int)(TimeCurrent() - g_lastAITime);
      int maxAge = AI_UpdateInterval * 2; // Maximum 2x l'intervalle (ex: 10s si intervalle=5s)
      if(g_lastAITime == 0 || timeSinceAIUpdate > maxAge)
      {
         static datetime lastAgeLog = 0;
         if(TimeCurrent() - lastAgeLog >= 30) // Log toutes les 30 secondes
         {
            Print("⏸️ TRADE BLOQUÉ: Données IA trop anciennes ou inexistantes - Dernière mise à jour: ", 
                  (g_lastAITime == 0 ? "JAMAIS" : IntegerToString(timeSinceAIUpdate) + "s"),
                  " (Max: ", maxAge, "s) - Attente mise à jour IA");
            lastAgeLog = TimeCurrent();
         }
         return; // BLOQUER si données IA trop anciennes
      }
      
      // TOUJOURS afficher l'état de la décision IA (pour vérifier réception)
      static datetime lastLogTime = 0;
      if(TimeCurrent() - lastLogTime >= 10) // Log toutes les 10 secondes pour éviter spam
      {
         Print("📊 ÉTAT IA: Action=", g_lastAIAction, " | Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "% | Requis=", DoubleToString(requiredConfidence * 100, 1), "% | Fallback=", (g_aiFallbackMode ? "OUI" : "NON"), " | Age=", timeSinceAIUpdate, "s");
         lastLogTime = TimeCurrent();
      }
      
      // Si l'IA a une recommandation mais confiance insuffisante, BLOQUER
      if(g_lastAIAction != "" && g_lastAIAction != "hold" && g_lastAIConfidence < requiredConfidence)
      {
         Print("🚫 TRADE BLOQUÉ: IA recommande ", g_lastAIAction, " mais confiance insuffisante (", DoubleToString(g_lastAIConfidence * 100, 1), "% < ", DoubleToString(requiredConfidence * 100, 1), "%)", cautiousMode ? " [MODE PRUDENT]" : "");
         return; // BLOQUER si confiance insuffisante
      }
      
      // Si l'IA recommande hold/vide, BLOQUER
      if(g_lastAIAction == "hold" || g_lastAIAction == "")
      {
         // Ne loguer que périodiquement pour éviter spam
         static datetime lastHoldLog = 0;
         if(TimeCurrent() - lastHoldLog >= 30) // Log toutes les 30 secondes
         {
            Print("⏸️ IA recommande HOLD/ATTENTE - Pas de trade (Action=", g_lastAIAction, " Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
            lastHoldLog = TimeCurrent();
         }
         return;
      }
      
      // Si l'IA est en mode fallback, BLOQUER (ne pas utiliser le fallback technique)
      if(g_aiFallbackMode)
      {
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
         
            // OBLIGATOIRE: VÉRIFIER L'ALIGNEMENT DES TROIS TIMEFRAMES M1, M5, H1 AVANT DE TRADER
            if(signalType != WRONG_VALUE)
            {
               // VÉRIFICATION PRIORITAIRE: Cohérence de TOUS les endsymbolPoints d'analyse
               int tradeDirection = (signalType == ORDER_TYPE_BUY) ? 1 : -1;
               if(!CheckCoherenceOfAllAnalyses(tradeDirection))
               {
                  Print("🚫 TRADE BLOQUÉ: Cohérence insuffisante de tous les endsymbolPoints d'analyse - Direction: ", (tradeDirection == 1 ? "BUY" : "SELL"));
                  return; // BLOQUER si cohérence insuffisante
               }
               
               // NOUVEAU OBLIGATOIRE 0: Vérifier qu'on n'est PAS dans une zone de correction
               if(IsPriceInCorrectionZone(signalType))
               {
                  if(DebugMode)
                     Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Prix en zone de correction (OBLIGATOIRE: éviter les corrections)");
                  return;
               }
               
               // OBLIGATOIRE 1: Alignement M1, M5 et H1 (aucune exception même avec confiance IA élevée)
               if(CheckTrendAlignment(signalType))
               {
                  // OBLIGATOIRE 2: Retournement FRANC confirmé après avoir touché EMA/Support/Résistance
                  // Vérifier que le prix a bien touché un niveau ET rebondi franchement
                  double touchLevel = 0.0;
                  string touchSource = "";
                  bool isStrongReversal = CheckStrongReversalAfterTouch(signalType, touchLevel, touchSource);
                  
                  if(!isStrongReversal)
                  {
                     if(DebugMode)
                        Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Retournement franc après touche non confirmé (OBLIGATOIRE)");
                     return;
                  }
                  
                  // OBLIGATOIRE 3: Confirmation M5 OBLIGATOIRE avant de prendre position
                  // Le retournement doit être confirmé par une bougie M5 dans la bonne direction
                  bool m5Confirmed = CheckM5ReversalConfirmation(signalType);
                  
                  if(!m5Confirmed)
                  {
                     if(DebugMode)
                        Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Confirmation M5 non obtenue (OBLIGATOIRE: attendre confirmation M5 avant position)");
                     return;
                  }
                  
                  // OBLIGATOIRE 4: Retournement confirmé par bougie verte (BUY) ou rouge (SELL) au niveau EMA rapide M1
                  // Vérification supplémentaire pour plus de sécurité
                  bool isReversalAtEMA = DetectReversalAtFastEMA(signalType);
                  
                  if(!isReversalAtEMA)
                  {
                     // Pas de retournement confirmé par bougie, rejeter le trade
                     if(DebugMode)
                        Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Retournement EMA rapide M1 non confirmé par bougie ", 
                              (signalType == ORDER_TYPE_BUY ? "verte" : "rouge"), " (OBLIGATOIRE même avec confiance IA élevée)");
                     return;
                  }
                  
                  // Si on arrive ici, on a:
                  // 1. ✅ Prix PAS en correction
                  // 2. ✅ Alignement M1, M5 et H1 confirmé
                  // 3. ✅ Retournement FRANC après touche EMA/Support/Résistance
                  // 4. ✅ Confirmation M5 OBLIGATOIRE obtenue
                  // 5. ✅ Retournement à l'EMA rapide M1 avec bougie confirmée (verte pour BUY, rouge pour SELL)
               
               // NOUVEAU: Validations avancées pour entrées précises
               // Validation du spread (validation simple sans dépendance externe)
               double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               double spread = ask - bid;
               double spreadPercent = (spread / ask) * 100.0;
               double maxSpreadPercent = 0.1;
               if(StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1)
                  maxSpreadPercent = 0.5;
               
               if(spreadPercent > maxSpreadPercent)
               {
                  if(DebugMode)
                     Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Spread trop élevé: ", DoubleToString(spreadPercent, 2), "%");
                  return;
               }
               
               // Vérifications supplémentaires en mode prudent
               if(cautiousMode)
               {
                  // En mode prudent, vérifier aussi le momentum
                  double momentumScore = 0.0;
                  double zoneStrength = 0.0;
                  double currentPrice = (signalType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  
                  if(AnalyzeMomentumPressureZone(signalType, currentPrice, momentumScore, zoneStrength))
                  {
                     double minMomentum = 0.5;
                     double minZoneStrength = 0.6;
                     
                     if(momentumScore < minMomentum || zoneStrength < minZoneStrength)
                     {
                        if(DebugMode)
                           Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Critères MCS insuffisants en mode prudent (Momentum: ", DoubleToString(momentumScore, 2), " < ", DoubleToString(minMomentum, 2), " ou Zone: ", DoubleToString(zoneStrength, 2), " < ", DoubleToString(minZoneStrength, 2), ")");
                        return;
                     }
                  }
                  else
                  {
                     if(DebugMode)
                        Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Momentum insuffisant en mode prudent");
                     return;
                  }
               }
               
               hasSignal = true;
               
               if(DebugMode)
                  Print("✅ Signal ", EnumToString(signalType), " confirmé: Alignement M1/M5/H1 + Retournement EMA rapide M1 avec bougie ", 
                        (signalType == ORDER_TYPE_BUY ? "verte" : "rouge"), " (Confiance IA: ", DoubleToString(g_lastAIConfidence * 100, 1), "%)", 
                        cautiousMode ? " [MODE PRUDENT]" : "");

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
            else
            {
               // Alignement M1/M5/H1 non confirmé, rejeter
               if(DebugMode)
                  Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Alignement M1/M5/H1 non confirmé (OBLIGATOIRE)");
               return;
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
   // VALIDATION: Vérifier que le lot est valide
   if(lot <= 0)
   {
      if(DebugMode)
         Print("❌ NormalizeLotSize: Lot invalide (", lot, ") - Utilisation du minimum");
      lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   }
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // VALIDATION: Vérifier que les valeurs du broker sont valides
   if(minLot <= 0 || maxLot <= 0 || lotStep <= 0)
   {
      if(DebugMode)
         Print("❌ NormalizeLotSize: Valeurs broker invalides - minLot=", minLot, " maxLot=", maxLot, " lotStep=", lotStep);
      // Utiliser des valeurs par défaut sécurisées
      minLot = 0.01;
      maxLot = 100.0;
      lotStep = 0.01;
   }
   
   // Normaliser selon le step
   if(lotStep > 0)
   lot = MathFloor(lot / lotStep) * lotStep;
   
   // Limiter aux bornes
   lot = MathMax(minLot, MathMin(maxLot, lot));
   
   // VALIDATION FINALE: Vérifier que le lot normalisé est valide
   if(lot < minLot || lot > maxLot)
   {
      if(DebugMode)
         Print("❌ NormalizeLotSize: Lot normalisé invalide (", lot, ") - Forcer au minimum");
      lot = minLot;
   }
   
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
//| Détecte si c'est un synthétique, forex ou or                  |
//+------------------------------------------------------------------+
bool IsSyntheticForexOrGold(const string symbol)
{
   // Convertir en majuscules pour comparaison insensible à la casse
   string symbolUpper = symbol;
   StringToUpper(symbolUpper);
   
   // Détecter les indices synthétiques
   if(StringFind(symbolUpper, "INDEX") != -1 ||
      StringFind(symbolUpper, "STEP") != -1 ||
      StringFind(symbolUpper, "JUMP") != -1 ||
      StringFind(symbolUpper, "RANGE") != -1)
      return true;
   
   // Détecter les paires forex classiques
   if(StringFind(symbolUpper, "EUR") != -1 || StringFind(symbolUpper, "GBP") != -1 || 
      StringFind(symbolUpper, "USD") != -1 || StringFind(symbolUpper, "JPY") != -1 ||
      StringFind(symbolUpper, "AUD") != -1 || StringFind(symbolUpper, "CAD") != -1 ||
      StringFind(symbolUpper, "CHF") != -1 || StringFind(symbolUpper, "NZD") != -1)
      return true;
   
   // Détecter l'or et métaux précieux
   if(StringFind(symbolUpper, "XAU") != -1 || StringFind(symbolUpper, "GOLD") != -1 ||
      StringFind(symbolUpper, "XAG") != -1 || StringFind(symbolUpper, "SILVER") != -1)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Détecte si le marché est en correction ou en range              |
//+------------------------------------------------------------------+
bool IsMarketInCorrectionOrRange()
{
   double emaFast[], emaSlow[], close[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   ArraySetAsSeries(close, true);
   
   int copied = CopyBuffer(emaFastHandle, 0, 0, 50, emaFast);
   copied += CopyBuffer(emaSlowHandle, 0, 0, 50, emaSlow);
   copied += CopyClose(_Symbol, PERIOD_M15, 0, 50, close);
   
   if(copied < 150) return false;
   
   // Vérifier si les EMA sont parallèles (range)
   double emaDiff = MathAbs(emaFast[0] - emaSlow[0]);
   double avgDiff = 0;
   for(int i = 0; i < 20; i++) {
      avgDiff += MathAbs(emaFast[i] - emaSlow[i]);
   }
   avgDiff /= 20;
   
   // Range: EMA très proches et parallèles (seuil assoupli de 0.3 à 0.15)
   if(emaDiff < avgDiff * 0.15) return true;
   
   // Correction: EMA rapide descend plus vite que EMA lente
   double fastSlope = (emaFast[0] - emaFast[10]) / 10;
   double slowSlope = (emaSlow[0] - emaSlow[10]) / 10;
   
   // Correction: EMA rapide descend plus vite que EMA lente (seuil assoupli de 0.7 à 0.4)
   if(fastSlope < slowSlope * 0.4 && fastSlope < 0) return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Nettoyer le nom du symbole pour un nom de fichier valide          |
//+------------------------------------------------------------------+
string SanitizeFileName(string symbol)
{
   string cleanName = symbol;
   // Remplacer les caractères invalides pour les noms de fichiers
   StringReplace(cleanName, " ", "_");
   StringReplace(cleanName, "(", "");
   StringReplace(cleanName, ")", "");
   StringReplace(cleanName, "[", "");
   StringReplace(cleanName, "]", "");
   StringReplace(cleanName, "{", "");
   StringReplace(cleanName, "}", "");
   StringReplace(cleanName, "/", "_");
   StringReplace(cleanName, "\\", "_");
   StringReplace(cleanName, ":", "_");
   StringReplace(cleanName, "*", "_");
   StringReplace(cleanName, "?", "_");
   StringReplace(cleanName, "\"", "_");
   StringReplace(cleanName, "<", "_");
   StringReplace(cleanName, ">", "_");
   StringReplace(cleanName, "|", "_");
   // Limiter la longueur du nom (Windows limite à 255 caractères, mais on garde raisonnable)
   if(StringLen(cleanName) > 100)
      cleanName = StringSubstr(cleanName, 0, 100);
   
   return cleanName;
}

//| Créer le dossier Files s'il n'existe pas                         |
//+------------------------------------------------------------------+
void EnsureFilesDirectoryExists()
{
   // Essayer d'abord dans le dossier commun du terminal
   string filesPath = "Files";
   
   // Le dossier Files est généralement créé automatiquement par MT5
   // On essaie simplement de créer un fichier test pour vérifier l'accès
   string testFile = filesPath + "\\test_" + _Symbol + ".tmp";
   int testHandle = FileOpen(testFile, FILE_WRITE | FILE_TXT | FILE_COMMON);
   if(testHandle != INVALID_HANDLE)
   {
      FileClose(testHandle);
      FileDelete(testFile);
      if(DebugMode)
         Print("✅ Dossier Files accessible: ", filesPath);
   }
   else
   {
      // Si échec, essayer avec le chemin complet du terminal
      string terminalPath = TerminalInfoString(TERMINAL_DATA_PATH);
      string fullPath = terminalPath + "\\MQL5\\Files";
      
      testFile = fullPath + "\\test_" + _Symbol + ".tmp";
      testHandle = FileOpen(testFile, FILE_WRITE | FILE_TXT, 0);
      if(testHandle != INVALID_HANDLE)
      {
         FileClose(testHandle);
         FileDelete(testFile);
         filesPath = fullPath;
         if(DebugMode)
            Print("✅ Dossier Files créé dans: ", fullPath);
      }
      else
      {
         Print("❌ Impossible d'accéder au dossier Files pour le CSV - Chemins testés:");
         Print("   - Files (FILE_COMMON): ", filesPath);
         Print("   - Terminal Data Path: ", fullPath);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Obtenir le nom du fichier CSV pour les prédictions par symbole   |
//| Sauvegarde dans: Terminal\Common\Files\Files\Predictions_SYMBOL_YYYYMMDD.csv |
//+------------------------------------------------------------------+
string GetPredictionCSVFileName(string symbol)
{
   datetime currentDate = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentDate, dt);
   
   string dateStr = StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
   // Nettoyer le nom du symbole pour éviter les caractères invalides
   string cleanSymbol = SanitizeFileName(symbol);
   // Créer un nom de fichier dans le sous-dossier "Files" : Files\Predictions_SYMBOL_YYYYMMDD.csv
   string fileName = "Files\\" + PredictionCSVFileNamePrefix + "_" + cleanSymbol + "_" + dateStr + ".csv";
   
   return fileName;
}

//+------------------------------------------------------------------+
//| Initialiser le fichier CSV des prédictions pour un symbole       |
//| Crée un fichier séparé pour chaque symbole dans Files\           |
//+------------------------------------------------------------------+
void InitializePredictionCSVFile(string symbol)
{
   if(!EnablePredictionCSVExport)
      return;
   
   // S'assurer que le dossier Files existe
   EnsureFilesDirectoryExists();
   
   // Obtenir le nom du fichier pour ce symbole
   string fileName = GetPredictionCSVFileName(symbol);
   
   // Toujours vérifier si le fichier a un en-tête
   int fileHandle = FileOpen(fileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON, ',');
   bool fileExists = (fileHandle != INVALID_HANDLE);
   bool hasHeader = false;
   
   if(fileHandle != INVALID_HANDLE)
   {
      // Vérifier si le fichier a un en-tête
      ulong fileSize = FileSize(fileHandle);
      if(fileSize > 0)
      {
         // Lire la première colonne pour vérifier si c'est l'en-tête
         FileSeek(fileHandle, 0, SEEK_SET);
         string firstColumn = FileReadString(fileHandle);
         
         // Vérifier si la première colonne est "Timestamp"
         if(firstColumn == "Timestamp")
         {
            hasHeader = true; // L'en-tête existe déjà
         }
      }
      FileClose(fileHandle);
   }
   
   // Si le fichier n'existe pas ou n'a pas d'en-tête, créer/écrire l'en-tête
   if(!fileExists || !hasHeader)
   {
      // Si le fichier existe mais n'a pas d'en-tête, on va le réécrire avec l'en-tête
      // (ATTENTION: cela écrasera les données existantes, mais c'est nécessaire pour avoir un format correct)
      fileHandle = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_COMMON, ',');
      if(fileHandle != INVALID_HANDLE)
      {
         // Écrire l'en-tête CSV
         FileWrite(fileHandle, 
                  "Timestamp",
                  "Symbol",
                  "PredictionTime",
                  "CurrentPrice",
                  "Bid",
                  "Ask",
                  "BarsPredicted",
                  "HistoryBars",
                  "AIAction",
                  "AIConfidence",
                  "AccuracyScore",
                  "PredictedPrices");
         
         FileClose(fileHandle);
         
         if(DebugMode)
         {
            if(!fileExists)
               Print("✅ Fichier CSV prédictions créé avec en-tête pour ", symbol, ": ", fileName);
            else
               Print("⚠️ En-tête CSV ajouté au fichier existant (données existantes écrasées) pour ", symbol, ": ", fileName);
         }
      }
      else
      {
         int error = GetLastError();
         string errorMsg = (error == 5004) ? "FILE_NOT_TOWRITE (fichier verrouillé ou dossier inexistant)" : 
                           (error == 5002) ? "FILE_NOT_FOUND" : 
                           (error == 5001) ? "FILE_NOT_EXIST" : 
                           "Code: " + IntegerToString(error);
         Print("❌ Erreur création fichier CSV prédictions pour ", symbol, " (", fileName, "): ", errorMsg);
      }
   }
}

//+------------------------------------------------------------------+
//| Exporter les données de prédiction en CSV                        |
//+------------------------------------------------------------------+
void ExportPredictionData(string symbol)
{
   if(!EnablePredictionCSVExport)
      return;
   
   if(!g_predictionValid || ArraySize(g_pricePrediction) == 0)
   {
      if(DebugMode)
         Print("⚠️ ExportPredictionData: Pas de prédiction valide pour ", symbol);
      return;
   }
   
   // Obtenir le nom du fichier pour ce symbole
   string fileName = GetPredictionCSVFileName(symbol);
   
   // S'assurer que le dossier Files existe AVANT d'ouvrir le fichier
   EnsureFilesDirectoryExists();
   
   // Initialiser le fichier CSV si nécessaire
   InitializePredictionCSVFile(symbol);
   
   // Ouvrir le fichier en mode append
   int fileHandle = FileOpen(fileName, FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON, ',');
   
   if(fileHandle == INVALID_HANDLE)
   {
      int error = GetLastError();
      string errorMsg = (error == 5004) ? "FILE_NOT_TOWRITE (fichier verrouillé ou dossier inexistant)" : 
                        (error == 5002) ? "FILE_NOT_FOUND" : 
                        (error == 5001) ? "FILE_NOT_EXIST" : 
                        "Code: " + IntegerToString(error);
      Print("❌ ExportPredictionData: Erreur ouverture fichier ", fileName, " - ", errorMsg);
      // Réessayer en s'assurant que le dossier existe
      EnsureFilesDirectoryExists();
      fileHandle = FileOpen(fileName, FILE_WRITE|FILE_READ|FILE_CSV|FILE_COMMON, ',');
      if(fileHandle == INVALID_HANDLE)
      {
         Print("❌ ExportPredictionData: Échec après réessai - Code: ", IntegerToString(GetLastError()));
         return;
      }
   }
   
   // Aller à la fin du fichier pour ajouter les données
   FileSeek(fileHandle, 0, SEEK_END);
   
   datetime currentTime = TimeCurrent();
   double currentPrice = (SymbolInfoDouble(symbol, SYMBOL_BID) + SymbolInfoDouble(symbol, SYMBOL_ASK)) / 2.0;
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   // Convertir les prix prédits en chaîne CSV
   string predictedPricesStr = "";
   int predSize = ArraySize(g_pricePrediction);
   for(int i = 0; i < predSize; i++)
   {
      if(i > 0) predictedPricesStr += ";";
      predictedPricesStr += DoubleToString(g_pricePrediction[i], _Digits);
   }
   
   // Écrire la ligne de données
   FileWrite(fileHandle,
            TimeToString(currentTime, TIME_DATE|TIME_SECONDS),
            symbol,
            TimeToString(g_predictionStartTime, TIME_DATE|TIME_SECONDS),
            DoubleToString(currentPrice, _Digits),
            DoubleToString(bid, _Digits),
            DoubleToString(ask, _Digits),
            IntegerToString(predSize),
            IntegerToString(ArraySize(g_priceHistory)),
            g_lastAIAction,
            DoubleToString(g_lastAIConfidence * 100, 2),
            DoubleToString(g_predictionAccuracyScore * 100, 2),
            predictedPricesStr);
   
   // Fermer le fichier
   FileClose(fileHandle);
   
   if(DebugMode)
      Print("✅ Données de prédiction exportées dans CSV: ", fileName, " (", predSize, " prix prédits)");
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
//| Compte les positions actives (sans compter les duplications)     |
//| Les positions dupliquées ne comptent pas dans la limite de 3      |
//| OPTIMISÉ: Pré-allocation mémoire pour éviter ArrayResize fréquent |
//+------------------------------------------------------------------+
int CountActivePositionsExcludingDuplicates()
{
   int totalPositions = PositionsTotal();
   if(totalPositions <= 0)
      return 0;
   
   int count = 0;
   string processedSymbols[];
   // Pré-allouer à 32 symboles (suffisant pour la plupart des cas)
   ArrayResize(processedSymbols, 32);
   int actualCount = 0;
   
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Magic() == InpMagicNumber)
         {
            string symbol = positionInfo.Symbol();
            
            // Vérifier si c'est un symbole déjà traité
            bool found = false;
            for(int j = 0; j < actualCount; j++)
            {
               if(processedSymbols[j] == symbol)
               {
                  found = true;
                  break;
               }
            }
            
            if(!found)
            {
               // Nouveau symbole : compter comme 1 position
               if(actualCount >= ArraySize(processedSymbols))
               {
                  // Réallocation seulement si nécessaire (cas rare)
                  ArrayResize(processedSymbols, ArraySize(processedSymbols) + 16);
               }
               processedSymbols[actualCount] = symbol;
               actualCount++;
               count++;
            }
            // Si symbole déjà trouvé, c'est une duplication - ne pas compter
         }
      }
   }
   
   return count;
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
   
   // Vérifier d'abord si une position du même type existe
   bool hasExistingPosition = false;
   ulong existingTicket = 0;
   
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
               hasExistingPosition = true;
               existingTicket = ticket;
               break;
            }
         }
      }
   }
   
   // Si pas de position existante, pas de duplication
   if(!hasExistingPosition)
      return false;
   
   // NOUVELLE CONDITION: Vérifier si le prix touche l'EMA et reprend sa tendance normale
   // Dans ce cas, la position existante se duplique
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   // Récupérer les EMA M1
   if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFast) >= 3 && CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlow) >= 3)
   {
      double emaFastCurrent = emaFast[0];
      double emaSlowCurrent = emaSlow[0];
      double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tolerance = 5.0 * symbolPoint; // Tolérance de 5 symbolPoints pour "toucher" l'EMA
      
      // Vérifier si le prix a touché l'EMA rapide récemment (dans les 2 dernières bougies)
      bool touchedEMA = false;
      for(int i = 0; i < 2; i++)
      {
         double high[], low[];
         ArraySetAsSeries(high, true);
         ArraySetAsSeries(low, true);
         if(CopyHigh(_Symbol, PERIOD_M1, i, 1, high) > 0 && CopyLow(_Symbol, PERIOD_M1, i, 1, low) > 0)
         {
            // Prix a touché l'EMA si le high ou le low est proche de l'EMA
            if(MathAbs(high[0] - emaFastCurrent) <= tolerance || MathAbs(low[0] - emaFastCurrent) <= tolerance ||
               (high[0] >= emaFastCurrent && low[0] <= emaFastCurrent))
            {
               touchedEMA = true;
               break;
            }
         }
      }
      
      if(touchedEMA)
      {
         // Vérifier si la tendance normale a repris
         // Pour BUY: EMA Fast > EMA Slow et prix > EMA Fast
         // Pour SELL: EMA Fast < EMA Slow et prix < EMA Fast
         bool trendResumed = false;
         if(orderType == ORDER_TYPE_BUY)
         {
            trendResumed = (emaFastCurrent > emaSlowCurrent && currentPrice > emaFastCurrent);
         }
         else // SELL
         {
            trendResumed = (emaFastCurrent < emaSlowCurrent && currentPrice < emaFastCurrent);
         }
         
         if(trendResumed)
         {
            if(DebugMode)
               Print("✅ DUPLICATION AUTORISÉE: Prix a touché l'EMA et tendance normale reprise - ", 
                     (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " (EMA Fast=", DoubleToString(emaFastCurrent, _Digits),
                     " EMA Slow=", DoubleToString(emaSlowCurrent, _Digits), " Prix=", DoubleToString(currentPrice, _Digits), ")");
            return true; // Autoriser la duplication
         }
      }
   }
   
   // Si les conditions EMA ne sont pas remplies, pas de duplication (comportement original)
   return false;
}

//+------------------------------------------------------------------+
//| Calculer la perte totale de toutes les positions actives         |
//| OPTIMISÉ: Utilise un cache pour éviter recalcul à chaque tick    |
//+------------------------------------------------------------------+
double GetTotalLoss()
{
   datetime currentTime = TimeCurrent();
   
   // Utiliser le cache si récent (moins de 1 seconde)
   if(g_lastTotalLossUpdate > 0 && (currentTime - g_lastTotalLossUpdate) < TOTAL_LOSS_CACHE_INTERVAL)
   {
      return g_cachedTotalLoss;
   }
   
   // Recalculer la perte totale
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
   
   // Mettre à jour le cache
   g_cachedTotalLoss = totalLoss;
   g_lastTotalLossUpdate = currentTime;
   
   return totalLoss;
}

//+------------------------------------------------------------------+
//| Fermer les positions Boom/Crash après spike (même gain faible)  |
//| si aucun autre spike immédiat n'est prévu                        |
//+------------------------------------------------------------------+
void CloseAllBoomCrashAfterSpike()
{
   bool isBoomCrash = IsBoomCrashSymbol(_Symbol);
   if(!isBoomCrash)
      return; // Uniquement pour Boom/Crash
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;
      
      if(!positionInfo.SelectByTicket(ticket))
         continue;
      
      if(positionInfo.Symbol() != _Symbol || positionInfo.Magic() != InpMagicNumber)
         continue;
      
      double currentProfit = positionInfo.Profit();
      datetime openTime = (datetime)positionInfo.Time();
      int positionAge = (int)(TimeCurrent() - openTime);
      
      // Détecter si un spike a eu lieu récemment
      bool spikeDetected = false;
      static double g_lastSpikePrice = 0.0;
      static datetime g_lastSpikeTime = 0;
      
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
      double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      // Vérifier le mouvement de prix sur les 2 dernières bougies M1
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, PERIOD_M1, 0, 3, rates) >= 3)
      {
         // Calculer le mouvement de prix
         double priceChange1 = MathAbs(rates[0].close - rates[1].close);
         double priceChange2 = MathAbs(rates[1].close - rates[2].close);
         double spikeThreshold = 20.0 * symbolPoint; // Seuil pour détecter un spike
         
         if(priceChange1 >= spikeThreshold || priceChange2 >= spikeThreshold)
         {
            spikeDetected = true;
            g_lastSpikePrice = currentPrice;
            g_lastSpikeTime = TimeCurrent();
            
            if(DebugMode)
               Print("🚨 SPIKE DÉTECTÉ sur ", _Symbol, " - Changement: ", DoubleToString(priceChange1 / symbolPoint, 1), " symbolPoints");
         }
      }
      
      // Vérifier si on est convaincu qu'un autre spike n'est pas immédiatement après
      bool anotherSpikeExpected = false;
      if(g_lastSpikeTime > 0)
      {
         int timeSinceLastSpike = (int)(TimeCurrent() - g_lastSpikeTime);
         
         // Si le dernier spike était il y a moins de 10 secondes, un autre spike pourrait arriver
         if(timeSinceLastSpike < 10)
         {
            anotherSpikeExpected = true;
         }
         
         // Vérifier aussi via la détection Boom/Crash si un spike est attendu
         ENUM_ORDER_TYPE orderType = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         if(DetectBoomCrashReversalAtEMA(orderType))
         {
            anotherSpikeExpected = true;
         }
      }
      
      // Si un spike a été détecté et qu'aucun autre spike n'est attendu immédiatement
      // ET que la position a au moins un profit (même minime), fermer
      if(spikeDetected && !anotherSpikeExpected && currentProfit > 0)
      {
         if(trade.PositionClose(ticket))
         {
            Print("✅ Position Boom/Crash fermée après spike: ", _Symbol,
                  " | Profit: ", DoubleToString(currentProfit, 2), " USD",
                  " | Durée: ", positionAge, "s",
                  " | Aucun autre spike immédiat prévu");
            SendMT5Notification("🔔 Position Boom/Crash fermée: " + _Symbol + " (profit: " + DoubleToString(currentProfit, 2) + " USD)");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Fermer toutes les positions dupliquées d'un symbole si profit   |
//| total >= 2 USD                                                   |
//+------------------------------------------------------------------+
void CloseDuplicatePositionsIfProfitReached(string symbol, double profitThreshold = 2.0)
{
   double totalProfit = 0.0;
   ulong tickets[];
   ArrayResize(tickets, 0);
   
   // Calculer le profit total de toutes les positions du même symbole
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;
      
      if(!positionInfo.SelectByTicket(ticket))
         continue;
      
      if(positionInfo.Symbol() == symbol && positionInfo.Magic() == InpMagicNumber)
      {
         double profit = positionInfo.Profit();
         totalProfit += profit;
         
         // Ajouter le ticket à la liste
         int size = ArraySize(tickets);
         ArrayResize(tickets, size + 1);
         tickets[size] = ticket;
      }
   }
   
   // Si le profit total atteint le seuil (2 USD), fermer toutes les positions
   if(totalProfit >= profitThreshold && ArraySize(tickets) > 0)
   {
      Print("💰 PROFIT TOTAL ATTEINT (", DoubleToString(totalProfit, 2), " USD >= ", DoubleToString(profitThreshold, 2), " USD) - Fermeture de ", ArraySize(tickets), " position(s) dupliquée(s) sur ", symbol);
      
      for(int i = 0; i < ArraySize(tickets); i++)
      {
         if(positionInfo.SelectByTicket(tickets[i]))
         {
            double profit = positionInfo.Profit();
            if(trade.PositionClose(tickets[i]))
            {
               Print("✅ Position dupliquée fermée: ", symbol,
                     " | Ticket: ", tickets[i],
                     " | Profit individuel: ", DoubleToString(profit, 2), " USD");
            }
            else
            {
               Print("❌ Erreur fermeture position ", tickets[i], ": ", trade.ResultRetcodeDescription());
            }
         }
      }
      
      SendMT5Notification("💰 Positions dupliquées fermées: " + symbol + " (profit total: " + DoubleToString(totalProfit, 2) + " USD)");
   }
}

//+------------------------------------------------------------------+
//| Exécuter un trade                                                |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   // ===== BLOQUER LES ORDRES LIMITES POUR MÉTAUX, CRYPTO ET FOREX =====
   if((orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) && IsMetalCryptoOrForexSymbol())
   {
      Print("🚫 ExecuteTrade: BLOQUÉ - Ordre limite non autorisé pour symbole ", _Symbol, " (métal, crypto ou Forex)");
      return;
   }
   
   // ===== VÉRIFICATION DE LIMITE DE 5 POSITIONS MAXIMUM (augmenté) =====
   // Permettre plus de positions simultanées
   int currentActivePositions = CountActivePositionsExcludingDuplicates();
   if(currentActivePositions >= 5) // Augmenté de 3 à 5
   {
      Print("🚫 TRADE BLOQUÉ (LIMITE POSITIONS): ", currentActivePositions, " positions déjà actives (limite = 5) - Aucun nouveau trade autorisé");
      return;
   }
   
   // ===== VÉRIFICATION DE MARCHÉ EN CORRECTION OU RANGE (assouplie) =====
   // Permettre le trading même en correction avec une confiance raisonnable
   bool isMarketCorrectionRange = IsMarketInCorrectionOrRange();
   if(isMarketCorrectionRange)
   {
      // Exception: autoriser si décision IA raisonnable (réduit de 95% à 80%)
      bool isReasonableAISignal = (UseAI_Agent && g_lastAIAction != "" && g_lastAIConfidence >= 0.80);
      if(!isReasonableAISignal)
      {
         Print("⚠️ TRADE LIMITÉ (MARCHÉ EN CORRECTION/RANGE): Marché en correction/range - Confiance IA insuffisante (<80%)");
         // Ne pas bloquer complètement, juste avertir
      }
      else
      {
         Print("✅ TRADE AUTORISÉ: Marché en correction/range mais confiance IA acceptable (", 
               DoubleToString(g_lastAIConfidence * 100, 1), "%)");
      }
   }
   
   // ===== VÉRIFICATION ABSOLUE PRIORITAIRE: DÉCISION FINALE =====
   // La décision finale de l'API est la stratégie la plus prioritaire
   // AUCUN trade ne doit être exécuté si la décision finale ne correspond pas
   if(UseAI_Agent && g_lastAIAction != "")
   {
      // Vérifier que les données IA sont récentes
      int timeSinceAIUpdate = (int)(TimeCurrent() - g_lastAITime);
      int maxAge = AI_UpdateInterval * 3; // Maximum 3x l'intervalle
      if(g_lastAITime == 0 || timeSinceAIUpdate > maxAge)
      {
         Print("🚫 TRADE BLOQUÉ (DÉCISION FINALE): Données IA trop anciennes ou inexistantes - Dernière mise à jour: ", 
               (g_lastAITime == 0 ? "JAMAIS" : IntegerToString(timeSinceAIUpdate) + "s"),
               " (Max: ", maxAge, "s) - Aucun trade autorisé");
         return;
      }
      
      // Vérifier que la décision finale correspond au type de trade
      bool isBuyOrder = (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP);
      bool isSellOrderTrade = (orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP);
      
      if(isBuyOrder && g_lastAIAction != "buy")
      {
         Print("🚫 TRADE BLOQUÉ (DÉCISION FINALE PRIORITAIRE): Ordre BUY rejeté - Décision finale = ", g_lastAIAction, 
               " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%) - La décision finale est la stratégie la plus prioritaire");
         return;
      }
      
      if(isSellOrderTrade && g_lastAIAction != "sell")
      {
         Print("🚫 TRADE BLOQUÉ (DÉCISION FINALE PRIORITAIRE): Ordre SELL rejeté - Décision finale = ", g_lastAIAction, 
               " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%) - La décision finale est la stratégie la plus prioritaire");
         return;
      }
      
      // Si la décision finale est "hold", bloquer tous les trades
      if(g_lastAIAction == "hold")
      {
         Print("🚫 TRADE BLOQUÉ (DÉCISION FINALE PRIORITAIRE): Décision finale = HOLD - Aucun trade autorisé (Confiance=", 
               DoubleToString(g_lastAIConfidence * 100, 1), "%)");
         return;
      }
      
      // ===== RESTRICTION IMPORTANTE : PAS DE SELL SUR CERTAINS SYMBOLES =====
      // Interdire les trades SELL sur crypto, forex, volatility, boom et crash
      // Ces symboles ne doivent trader que des mouvements haussiers (BUY)
      
      if(isSellOrderTrade)
      {
         // Détecter les types de symboles à restreindre
         bool isCryptoSymbol = IsCryptoSymbol(_Symbol);
         
         bool isForexSymbol = (StringFind(_Symbol, "EUR") != -1 || StringFind(_Symbol, "USD") != -1 ||
                              StringFind(_Symbol, "GBP") != -1 || StringFind(_Symbol, "JPY") != -1 ||
                              StringFind(_Symbol, "CHF") != -1 || StringFind(_Symbol, "CAD") != -1 ||
                              StringFind(_Symbol, "AUD") != -1 || StringFind(_Symbol, "NZD") != -1);
         
         bool isVolatilitySymbol = (StringFind(_Symbol, "Volatility") != -1 || StringFind(_Symbol, "VOL") != -1);
         
         bool isBoomCrashSymbol = IsBoomCrashSymbol(_Symbol);
         
         // Si le symbole est dans une des catégories restreintes
         if(isCryptoSymbol || isForexSymbol || isVolatilitySymbol || isBoomCrashSymbol)
         {
            string symbolType = "";
            if(isCryptoSymbol) symbolType = "Crypto";
            else if(isForexSymbol) symbolType = "Forex";
            else if(isVolatilitySymbol) symbolType = "Volatility";
            else if(isBoomCrashSymbol) symbolType = "Boom/Crash";
            
            Print("🚫 TRADE BLOQUÉ (RESTRICTION SYMBOLE): Ordre SELL interdit sur ", symbolType, " - Symbole: ", _Symbol,
                  " | Seuls les trades BUY sont autorisés sur ce type de symbole");
            return;
         }
      }
      
      // ===== VÉRIFICATION SPÉCIALE POUR SYMBOLES VOLATILES (assouplie) =====
      // Pour Volatility 100, Step Index et autres symboles volatiles
      // Exiger 85% de confiance au lieu de 98%
      bool isVolatilitySymbol = IsVolatilitySymbol(_Symbol);
      string symbolUpper = _Symbol;
      StringToUpper(symbolUpper);
      bool isStepIndex = (StringFind(symbolUpper, "STEP") != -1);
      
      if((isVolatilitySymbol || isStepIndex) && g_lastAIConfidence < 0.85) // Réduit de 0.98 à 0.85
      {
         Print("⚠️ TRADE LIMITÉ (SYMBOLES VOLATILES): ", _Symbol, " - Confiance: ", 
               DoubleToString(g_lastAIConfidence * 100, 2), "% < 85% requis - Trade limité pour symboles volatiles");
         // Ne pas bloquer complètement, juste avertir
      }
   }
   else if(UseAI_Agent)
   {
      // Si l'IA est activée mais aucune décision n'est disponible, bloquer les trades
      Print("🚫 TRADE BLOQUÉ (DÉCISION FINALE PRIORITAIRE): Aucune décision finale disponible - Aucun trade autorisé");
      return;
   }
   
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
   
   // ===== NOUVELLE LOGIQUE: GESTION DES 3 MEILLEURS SIGNAUX (>= 100% confiance) =====
   // Compter les positions actives (sans compter les duplications)
   int totalActivePositions = CountActivePositionsExcludingDuplicates();
   int currentSymbolPositions = CountPositionsForSymbolMagic();
   bool isCurrentSymbolActive = (currentSymbolPositions > 0);
   bool isDuplicateTrade = HasDuplicatePosition(orderType);
   
   // Vérifier la confiance de la décision finale
   double signalConfidence = g_lastAIConfidence;
   bool shouldExecuteMarket = false;
   bool shouldPlaceLimit = false;
   
   // ===== APPLIQUER RÉCOMPENSE/SANCTION BASÉE SUR LES DEUX DERNIERS TRADES =====
   int maxActivePositions = 3; // Nombre maximum de positions par défaut
   double adjustedConfidence = ApplyTradeMotivation(1.0, maxActivePositions); // Seuil de confiance par défaut: 100% (1.0)
   
   // Les trades dupliqués sont toujours autorisés (ne comptent pas dans la limite)
   if(isDuplicateTrade)
   {
      shouldExecuteMarket = true; // Duplication autorisée
   }
   else
   {
      // Vérifier que la confiance est >= seuil ajusté (par défaut 100% mais peut être réduit en récompense ou augmenté en sanction)
      if(signalConfidence >= adjustedConfidence)
      {
         // Confiance >= seuil ajusté - Vérifier si on peut exécuter au marché (max positions ajusté)
         if(totalActivePositions < maxActivePositions || isCurrentSymbolActive)
         {
            // On a moins de 3 positions OU le symbole actuel a déjà une position
            shouldExecuteMarket = true;
         }
         else
         {
            // On a déjà le maximum de positions - Mettre en ordre LIMIT
            shouldPlaceLimit = true;
            Print("📋 LIMITE ", maxActivePositions, " POSITIONS: ", totalActivePositions, " positions actives (max ", maxActivePositions, ") - Confiance: ", 
                  DoubleToString(signalConfidence * 100, 2), "% (seuil ajusté: ", DoubleToString(adjustedConfidence * 100, 1), "%) - Signal mis en ordre LIMIT");
         }
      }
      else
      {
         // Confiance < 100% - Toujours mettre en ordre LIMIT
         shouldPlaceLimit = true;
         if(DebugMode)
            Print("📋 Signal avec confiance ", DoubleToString(signalConfidence * 100, 2), "% < 100% - Mise en ordre LIMIT");
      }
   }
   
   // Si on doit placer un ordre LIMIT au lieu d'exécuter au marché
   if(shouldPlaceLimit)
   {
      // ===== BLOQUER LES ORDRES LIMITES POUR MÉTAUX, CRYPTO ET FOREX =====
      if(IsMetalCryptoOrForexSymbol())
      {
         Print("🚫 ExecuteTrade: BLOQUÉ - Ordre limite non autorisé pour symbole ", _Symbol, " (métal, crypto ou Forex)");
         return;
      }
      
      double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double limitPrice = FindOptimalLimitOrderPrice(orderType, currentPrice);
      
      double sl, tp;
      ENUM_POSITION_TYPE posType = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      CalculateSLTPInPoints(posType, limitPrice, sl, tp);
      
      double normalizedLot = NormalizeLotSize(InitialLotSize);
      ENUM_ORDER_TYPE limitOrderType = (orderType == ORDER_TYPE_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = normalizedLot;
      request.type = limitOrderType;
      request.price = limitPrice;
      request.sl = sl;
      request.tp = tp;
      
      // ===== VALIDATION COMPLÈTE AVANT ENVOI =====
      // 1. Vérifier le volume
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      if(normalizedLot < minLot || normalizedLot > maxLot)
      {
         Print("❌ Ordre LIMIT BLOQUÉ: Volume invalide ", _Symbol, " | Volume: ", normalizedLot, " (Min: ", minLot, " Max: ", maxLot, ")");
         return;
      }
      
      // 2. Vérifier le prix selon le type d'ordre
      double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool isBuyLimit = (limitOrderType == ORDER_TYPE_BUY_LIMIT);
      
      if(isBuyLimit && limitPrice >= askPrice)
      {
         Print("⚠️ Prix BUY_LIMIT ajusté - ", DoubleToString(limitPrice, _Digits), " >= ASK ", DoubleToString(askPrice, _Digits), 
               " -> Ajustement à ", DoubleToString(askPrice * 0.999, _Digits));
         limitPrice = NormalizeDouble(askPrice * 0.999, _Digits);
         Print("🔧 Prix ajusté à: ", DoubleToString(limitPrice, _Digits));
      }
      if(!isBuyLimit && limitPrice <= bidPrice)
      {
         Print("⚠️ Prix SELL_LIMIT ajusté - ", DoubleToString(limitPrice, _Digits), " <= BID ", DoubleToString(bidPrice, _Digits), 
               " -> Ajustement à ", DoubleToString(bidPrice * 1.001, _Digits));
         limitPrice = NormalizeDouble(bidPrice * 1.001, _Digits);
         Print("🔧 Prix ajusté à: ", DoubleToString(limitPrice, _Digits));
      }
      
      // 3. Vérifier les stops
      if(sl > 0 && tp > 0)
      {
         double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double minDistance = MathMax(stopLevel * symbolPoint, symbolPoint * 5);
         
         if(isBuyLimit)
         {
            // BUY_LIMIT: SL doit être < limitPrice, TP doit être > limitPrice
            if(sl >= limitPrice || tp <= limitPrice)
            {
               Print("❌ Ordre LIMIT BLOQUÉ: SL/TP invalides BUY ", _Symbol, " | Prix: ", limitPrice, " SL: ", sl, " TP: ", tp);
               return;
            }
            if(MathAbs(limitPrice - sl) < minDistance || MathAbs(tp - limitPrice) < minDistance)
            {
               Print("❌ Ordre LIMIT BLOQUÉ: Distance SL/TP insuffisante BUY ", _Symbol, " | Min: ", minDistance);
               return;
            }
         }
         else
         {
            // SELL_LIMIT: SL doit être > limitPrice, TP doit être < limitPrice
            if(sl <= limitPrice || tp >= limitPrice)
            {
               Print("❌ Ordre LIMIT BLOQUÉ: SL/TP invalides SELL ", _Symbol, " | Prix: ", limitPrice, " SL: ", sl, " TP: ", tp);
               return;
            }
            if(MathAbs(sl - limitPrice) < minDistance || MathAbs(limitPrice - tp) < minDistance)
            {
               Print("❌ Ordre LIMIT BLOQUÉ: Distance SL/TP insuffisante SELL ", _Symbol, " | Min: ", minDistance);
               return;
            }
         }
      }
      
      request.magic = InpMagicNumber;
      request.comment = "LIMIT_" + DoubleToString(signalConfidence * 100, 1) + "%";
      request.deviation = 10;
      request.type_filling = ORDER_FILLING_FOK;
      
      if(SafeOrderSend(request, result))
      {
         Print("📋 Ordre LIMIT placé: ", EnumToString(limitOrderType), " ", _Symbol, 
               " à ", DoubleToString(limitPrice, _Digits), 
               " (Confiance: ", DoubleToString(signalConfidence * 100, 2), "%)");
      }
      else
      {
         Print("❌ Erreur placement ordre LIMIT: ", result.retcode, " - ", result.comment);
      }
      
      return; // Ordre LIMIT placé, ne pas exécuter au marché
   }
   
   // Si on ne doit pas exécuter au marché, sortir
   if(!shouldExecuteMarket)
   {
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
   
   // ===== NOUVELLE VÉRIFICATION PRIORITAIRE: AFFINER L'ENTRÉE AVEC M5 ET EMA RAPIDE/MOYEN =====
   // Tous les trades doivent utiliser la décision finale appliquée au timeframe M5
   // et utiliser les EMA rapide et moyen sur M5 pour affiner les entrées
   // ASSOUPLISSEMENT: Pour symboles volatiles avec confiance 100%, passer cette vérification
   bool isVolatilitySymbol = IsVolatilitySymbol(_Symbol);
   bool skipM5Check = (isVolatilitySymbol && signalConfidence >= 1.0);
   
   if(!skipM5Check && !RefineEntryWithM5EMA(orderType))
   {
      Print("🚫 TRADE BLOQUÉ: Conditions d'entrée M5 non remplies - Entrée affinée avec EMA rapide/moyen M5 requise");
      if(DebugMode)
         SendMT5Notification("🚫 Trade bloqué: " + _Symbol + " - Conditions M5 EMA non remplies");
      return; // BLOQUER si conditions M5 EMA non remplies
   }
   else if(skipM5Check && !RefineEntryWithM5EMA(orderType))
   {
      Print("⚠️ Conditions M5 EMA non remplies mais ASSOUPLIES pour symbole volatil avec 100% confiance");
   }
   
   // ===== VALIDATION FINALE AVANT ENTRÉE: GARANTIR TIMING OPTIMAL =====
   // Cette section garantit que le trade commence en profit immédiatement
   
   // 1. VÉRIFICATION PRIORITAIRE: Prédiction montre mouvement immédiat dans le bon sens
   if(!skipM5Check && !CheckImmediatePredictionDirection(orderType))
   {
      Print("🚫 TRADE BLOQUÉ: La prédiction ne montre pas de mouvement immédiat dans le bon sens - Signal douteux évité");
      SendMT5Notification("🚫 Trade bloqué: " + _Symbol + " - Prédiction immédiate invalide");
      return; // BLOQUER si prédiction immédiate invalide
   }
   else if(skipM5Check && !CheckImmediatePredictionDirection(orderType))
   {
      Print("⚠️ Prédiction immédiate non validée mais ASSOUPLIE pour symbole volatil avec 100% confiance");
   }
   
   // 2. VÉRIFICATION MOMENTUM: Le momentum doit être favorable immédiatement
   double momentumStrength = CalculateMomentumStrength(orderType, 5);
   double minMomentum = 0.4; // Minimum 40% de momentum favorable
   if(momentumStrength < minMomentum)
   {
      Print("🚫 TRADE BLOQUÉ: Momentum insuffisant (", DoubleToString(momentumStrength * 100, 1), "% < ", DoubleToString(minMomentum * 100, 1), "%) - Timing non optimal");
      if(DebugMode)
         SendMT5Notification("🚫 Trade bloqué: " + _Symbol + " - Momentum insuffisant");
      return;
   }
   
   // 3. VÉRIFICATION PRIX ACTION: Les 3 dernières bougies doivent confirmer la direction
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 3, rates) >= 3)
   {
      int confirmBars = 0;
      for(int i = 0; i < 2; i++) // Vérifier les 2 dernières bougies fermées
      {
         if(orderType == ORDER_TYPE_BUY)
         {
            // Pour BUY: les bougies doivent être haussières (close > open)
            if(rates[i].close > rates[i].open)
               confirmBars++;
         }
         else // SELL
         {
            // Pour SELL: les bougies doivent être baissières (close < open)
            if(rates[i].close < rates[i].open)
               confirmBars++;
         }
      }
      
      // Exiger au moins 1 bougie confirmante sur 2 (50%)
      if(confirmBars < 1)
      {
         Print("🚫 TRADE BLOQUÉ: Prix action non confirmant (", confirmBars, "/2 bougies) - Timing non optimal");
         if(DebugMode)
            SendMT5Notification("🚫 Trade bloqué: " + _Symbol + " - Prix action non confirmant");
         return;
      }
   }
   
   // 4. VÉRIFICATION SPREAD: Le spread ne doit pas être trop élevé
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spread = ask - bid;
   double spreadPercent = (spread / ask) * 100.0;
   double maxSpreadPercent = 0.15; // Maximum 0.15% de spread
   if(StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1)
      maxSpreadPercent = 0.5; // Plus tolérant pour Boom/Crash
   
   if(spreadPercent > maxSpreadPercent)
   {
      Print("🚫 TRADE BLOQUÉ: Spread trop élevé (", DoubleToString(spreadPercent, 2), "% > ", DoubleToString(maxSpreadPercent, 2), "%) - Conditions non optimales");
      if(DebugMode)
         SendMT5Notification("🚫 Trade bloqué: " + _Symbol + " - Spread trop élevé");
      return;
   }
   
   // 5. VÉRIFICATION RATIO RISK/REWARD: Le TP doit être au moins 2x le SL
   // (Cette vérification sera faite après calcul du SL/TP, mais on peut pré-vérifier)
   
   if(DebugMode)
      Print("✅ VALIDATION FINALE PASSÉE: Momentum=", DoubleToString(momentumStrength * 100, 1), "% | Prédiction OK | Prix action OK | Spread OK");
   
   double sl, tp;
   ENUM_POSITION_TYPE posType = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   
   // NOUVEAU: Calculer le TP dynamique au prochain Support/Résistance
   // Le TP est maintenant calculé selon le prochain niveau Support (pour SELL) ou Résistance (pour BUY)
   tp = CalculateDynamicTP(orderType, price);
   
   // STRATÉGIE PROFIT IMMÉDIAT: Utiliser un SL très serré (break-even rapide, max 0.5$ de perte)
   // Cela garantit que le trade commence en profit rapidement sans faire de pertes énormes
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double symbolPointValue = (tickValue / tickSize) * symbolPoint;
   double slValuePerPoint = normalizedLot * symbolPointValue;
   
   // Calculer SL pour max 0.5$ de perte (très serré pour commencer en profit rapidement)
   double maxLossUSD = 0.5; // Maximum 0.5$ de perte
   double slPoints = 0;
   if(slValuePerPoint > 0)
   {
      slPoints = maxLossUSD / slValuePerPoint;
   }
   else
   {
      // Fallback: utiliser ATR si calcul impossible
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
         slPoints = (1.0 * atr[0]) / symbolPoint; // 1x ATR = SL très serré
      else
         slPoints = 30; // Fallback: 30 symbolPoints
   }
   
   // Calculer SL avec le calcul très serré
   if(posType == POSITION_TYPE_BUY)
      sl = NormalizeDouble(price - slPoints * symbolPoint, _Digits);
   else
      sl = NormalizeDouble(price + slPoints * symbolPoint, _Digits);
   
   // Calculer TP normal pour référence
   double slTemp, tpTemp;
   CalculateSLTPInPoints(posType, price, slTemp, tpTemp);
   
   // Si le TP dynamique n'a pas pu être calculé, utiliser le TP fixe en fallback
   if(tp <= 0)
   {
      if(DebugMode)
         Print("⚠️ TP dynamique invalide, utilisation TP fixe en fallback");
      tp = tpTemp; // Utiliser le TP fixe
   }
   
   // VALIDATION FINALE AVANT OUVERTURE: Vérifier que SL et TP sont valides
   if(sl <= 0 || tp <= 0)
   {
      Print("❌ TRADE BLOQUÉ: SL ou TP invalides (SL=", sl, " TP=", tp, ") - Calcul impossible");
      return;
   }
   
   // Vérifier que le TP dynamique est valide (doit être dans le bon sens)
   if(orderType == ORDER_TYPE_BUY && tp <= price)
   {
      if(DebugMode)
         Print("⚠️ TP dynamique BUY invalide (TP <= prix), utilisation TP fixe");
      tp = tpTemp;
   }
   else if(orderType == ORDER_TYPE_SELL && tp >= price)
   {
      if(DebugMode)
         Print("⚠️ TP dynamique SELL invalide (TP >= prix), utilisation TP fixe");
      tp = tpTemp;
   }
   
   // ===== VALIDATION CRITIQUE: RATIO RISK/REWARD MINIMUM 2:1 =====
   // Garantir que le trade est rentable avec un ratio minimum
   double slDist = MathAbs(price - sl);
   double tpDist = MathAbs(tp - price);
   
   if(slDist > 0)
   {
      double riskRewardRatio = tpDist / slDist;
      double minRiskReward = 2.0; // Minimum 2:1 (gain potentiel = 2x la perte potentielle)
      
      if(riskRewardRatio < minRiskReward)
      {
         Print("🚫 TRADE BLOQUÉ: Ratio Risk/Reward insuffisant (", DoubleToString(riskRewardRatio, 2), ":1 < ", DoubleToString(minRiskReward, 1), ":1) - Trade non rentable");
         if(DebugMode)
         {
            Print("   SL distance: ", DoubleToString(slDist, _Digits), " | TP distance: ", DoubleToString(tpDist, _Digits));
            SendMT5Notification("🚫 Trade bloqué: " + _Symbol + " - Ratio R/R insuffisant (" + DoubleToString(riskRewardRatio, 2) + ":1)");
         }
         return; // BLOQUER si ratio insuffisant
      }
      
      if(DebugMode)
         Print("✅ Ratio Risk/Reward validé: ", DoubleToString(riskRewardRatio, 2), ":1 (Minimum: ", DoubleToString(minRiskReward, 1), ":1)");
   }
   
   if(DebugMode)
      Print("📊 SL/TP calculés - SL: ", DoubleToString(sl, _Digits), " TP (dynamique): ", DoubleToString(tp, _Digits), 
            " (au prochain Support/Résistance) | R/R: ", DoubleToString(tpDist / slDist, 2), ":1");
   
   // Vérifier les distances minimum une dernière fois
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = MathMax(stopLevel * symbolPoint, tickSize * 3);
   if(minDistance == 0) minDistance = 5 * symbolPoint;
   
   if(slDist < minDistance || tpDist < minDistance)
   {
      Print("❌ TRADE BLOQUÉ: Distances SL/TP insuffisantes (SL=", DoubleToString(slDist, _Digits), " TP=", DoubleToString(tpDist, _Digits), " min=", DoubleToString(minDistance, _Digits), ")");
      return;
   }
   
   // Normaliser les prix avant ouverture
   price = NormalizeDouble(price, _Digits);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   
   // ===== NOUVELLE VALIDATION DES STOPS =====
   // Calculer et valider les stops optimaux avant d'exécuter
   if(!CalculateOptimalStops(_Symbol, price, sl, tp, 2.0))
   {
      Print("❌ TRADE BLOQUÉ: Impossible de calculer les niveaux de stop optimaux");
      return;
   }
   
   // Valider les niveaux de stop avant d'exécuter
   if(!ValidateStops(_Symbol, price, sl, tp))
   {
      Print("❌ TRADE BLOQUÉ: Niveaux SL/TP invalides pour ", _Symbol, 
            " - Prix=", price, " SL=", sl, " TP=", tp);
      return;
   }
   
   // ===== VALIDATION FINALE AVANT OUVERTURE =====
   // Vérifier le volume une dernière fois
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(normalizedLot < minLot || normalizedLot > maxLot)
   {
      string errorMsg = StringFormat("❌ TRADE BLOQUÉ: Volume invalide %s | Lot: %.5f (Min: %.5f, Max: %.5f)", 
                                     _Symbol, normalizedLot, minLot, maxLot);
      Print(errorMsg);
      SendMT5Notification(errorMsg);
      return;
   }
   
   // Vérifier que les prix sont valides (positifs et non nuls)
   if(price <= 0)
   {
      string errorMsg = StringFormat("❌ TRADE BLOQUÉ: Prix invalide %s | Type: %s | Prix: %.5f", 
                                     _Symbol, EnumToString(orderType), price);
      Print(errorMsg);
      SendMT5Notification(errorMsg);
      return;
   }
   
   // Vérifier que SL et TP sont dans le bon sens et valides
   if(sl <= 0 || tp <= 0 || sl == tp)
   {
      string errorMsg = StringFormat("❌ TRADE BLOQUÉ: SL/TP invalides %s | SL: %.5f | TP: %.5f", 
                                     _Symbol, sl, tp);
      Print(errorMsg);
      SendMT5Notification(errorMsg);
      return;
   }
   
   // Vérifier les distances SL/TP par rapport au prix
   if((orderType == ORDER_TYPE_BUY && (sl >= price || tp <= price)) ||
      (orderType == ORDER_TYPE_SELL && (sl <= price || tp >= price)))
   {
      string errorMsg = StringFormat("❌ TRADE BLOQUÉ: SL/TP dans mauvais sens %s | Prix: %.5f | SL: %.5f | TP: %.5f", 
                                     _Symbol, price, sl, tp);
      Print(errorMsg);
      SendMT5Notification(errorMsg);
      return;
   }
   
   if(trade.PositionOpen(_Symbol, orderType, normalizedLot, price, sl, tp, "SCALPER_DOUBLE"))
   {
      ulong ticket = trade.ResultOrder();
      
      string tradeInfo = StringFormat("✅ Trade ouvert: %s | %s | Lot: %.2f | Prix: %.5f | SL: %.5f | TP: %.5f",
                                      EnumToString(orderType), _Symbol, normalizedLot, price, sl, tp);
      Print(tradeInfo);
      
      // Envoyer notification MT5
      SendMT5Notification(tradeInfo);
      
      // Mettre à jour le tracker
      g_hasPosition = true;
      g_positionTracker.ticket = ticket;
      g_positionTracker.initialLot = normalizedLot;
      g_positionTracker.currentLot = normalizedLot;
      g_positionTracker.highestProfit = 0.0;
      g_positionTracker.lotDoubled = false;
      g_positionTracker.openTime = TimeCurrent();
      
      // Enregistrer dans le CSV si activé
      if(EnableCSVLogging)
      {
         Sleep(100); // Petite pause pour que la position soit complètement créée
         LogTradeOpen(ticket);
      }
   }
   else
   {
      string errorMsg = StringFormat("❌ Erreur ouverture trade: %s | Code: %d - %s", 
                                     _Symbol, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      Print(errorMsg);
      SendMT5Notification(errorMsg);
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
   
   // Trouver les symbolPoints de début et fin pour M5
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
   
   // Trouver les symbolPoints de début et fin pour H1
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
   
   // Dessiner trendline EMA Fast M5 (du symbolPoint le plus ancien au plus récent)
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
//| Sauvegarder les prédictions dans un fichier                     |
//+------------------------------------------------------------------+
void SavePredictions()
{
   string filename = "predictions_" + _Symbol + ".bin";
   int handle = FileOpen(filename, FILE_WRITE | FILE_BIN | FILE_COMMON);
   
   if(handle != INVALID_HANDLE)
   {
      // Sauvegarder l'horodatage actuel
      datetime currentTime = TimeCurrent();
      FileWriteLong(handle, currentTime);
      
      // Sauvegarder les données de prédiction
      FileWriteInteger(handle, ArraySize(g_priceHistory));
      FileWriteArray(handle, g_priceHistory);
      
      // Sauvegarder les prédictions actuelles
      FileWriteInteger(handle, g_predictionBars);
      FileWriteArray(handle, g_pricePrediction);
      
      FileClose(handle);
      
      if(DebugMode)
         Print("✅ Prédictions sauvegardées avec succès: ", filename);
   }
   else
   {
      if(DebugMode)
         Print("⚠️ Erreur lors de la sauvegarde des prédictions: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Nettoyer tous les objets d'affichage anciens                     |
//+------------------------------------------------------------------+
void ClearAllDisplayObjects()
{
   // Supprimer tous les objets avec préfixes spécifiques pour éviter l'accumulation
   string prefixes[] = {
      "FRACTAL_", "EMA_Fast_", "EMA_Slow_", "EMA_50_", "EMA_100_", "EMA_200_", 
      "AI_ZONE_", "SUPPORT_", "RESISTANCE_", "TRENDLINE_", "SMC_", "Trend_EMA_",
      "PREDICTION_", "SIGNAL_", "ARROW_", "TREND_EMA_FAST_", "TREND_EMA_SLOW_"
   };
   
   // Trier les préfixes par ordre alphabétique pour une meilleure performance de cache
   ArraySort(prefixes);
   
   // Obtenir le nombre total d'objets une seule fois
   int totalObjects = ObjectsTotal(0);
   
   // Parcourir tous les objets une seule fois
   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      
      // Vérifier si l'objet correspond à l'un de nos préfixes
      for(int p = 0; p < ArraySize(prefixes); p++)
      {
         if(StringFind(name, prefixes[p]) == 0)
         {
            ObjectDelete(0, name);
            break; // Passer à l'objet suivant
         }
      }
   }
   
   // Effacer également les objets par type pour être sûr de tout nettoyer
   string symbol = _Symbol;
   string objNames[] = {
      "Trend_EMA_Fast_H1_" + symbol,
      "Trend_EMA_Slow_H1_" + symbol,
      "Trend_EMA_Fast_M15_" + symbol,
      "Trend_EMA_Slow_M15_" + symbol,
      "Trend_EMA_Fast_M5_" + symbol,
      "Trend_EMA_Slow_M5_" + symbol
   };
   
   for(int j = 0; j < ArraySize(objNames); j++)
   {
      if(ObjectFind(0, objNames[j]) >= 0)
         ObjectDelete(0, objNames[j]);
   }
   
   // Forcer le rafraîchissement du graphique
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Dessiner une courbe EMA optimisée (moins de segments)             |
//+------------------------------------------------------------------+
void DrawEMACurveOptimized(string prefix, double &values[], datetime &times[], int count, color clr, int width, int step)
{
   // Dessiner une courbe EMA sur 1000 bougies avec un step pour performance
   // Note: Arrays en mode ArraySetAsSeries, donc index 0 = bougie la plus récente (actuelle)
   // Step de 50 = environ 20 segments pour 1000 bougies (performance optimale)
   int segmentsDrawn = 0;
   int maxSegments = (count / step) + 2; // +2 pour inclure le segment final jusqu'au prix actuel
   if(maxSegments > 100) maxSegments = 100; // Limiter à 100 segments max pour éviter surcharge
   
   // D'abord, dessiner le segment qui va de step vers 0 (bougie actuelle)
   // Cela garantit que l'EMA va jusqu'au prix actuel avec un rayon vers la droite
   if(count > step && values[0] > 0 && values[step] > 0 && times[0] > 0 && times[step] > 0)
   {
      string lastSegName = prefix + _Symbol + "_LAST";
      
      // Créer ou mettre à jour le segment final jusqu'au prix actuel
      // times[step] est plus ancien, times[0] est le plus récent (bougie actuelle)
      if(ObjectFind(0, lastSegName) < 0)
         ObjectCreate(0, lastSegName, OBJ_TREND, 0, times[step], values[step], times[0], values[0]);
      else
      {
         ObjectSetInteger(0, lastSegName, OBJPROP_TIME, 0, times[step]);
         ObjectSetDouble(0, lastSegName, OBJPROP_PRICE, 0, values[step]);
         ObjectSetInteger(0, lastSegName, OBJPROP_TIME, 1, times[0]);
         ObjectSetDouble(0, lastSegName, OBJPROP_PRICE, 1, values[0]);
      }
      
      ObjectSetInteger(0, lastSegName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lastSegName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lastSegName, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, lastSegName, OBJPROP_RAY_RIGHT, true); // Rayon vers la droite pour continuer visuellement
      ObjectSetInteger(0, lastSegName, OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, lastSegName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lastSegName, OBJPROP_BACK, false); // Devant le graphique
      ObjectSetInteger(0, lastSegName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); // Visible sur tous les timeframes
      
      segmentsDrawn++;
   }
   
   // Parcourir du plus récent vers le plus ancien (de count-1 vers step)
   // On commence à count-1 (le plus ancien) et on remonte jusqu'à step
   for(int i = count - 1; i >= step && segmentsDrawn < maxSegments; i -= step)
   {
      int prevIdx = i - step;
      if(prevIdx < step) prevIdx = step; // Ne pas aller au-delà de step (déjà couvert par le segment final)
      
      // Vérifier que les valeurs sont valides
      if(values[i] > 0 && values[prevIdx] > 0 && times[i] > 0 && times[prevIdx] > 0)
      {
         string segName = prefix + _Symbol + "_" + IntegerToString(segmentsDrawn);
         
         // Créer ou mettre à jour le segment de ligne (prevIdx est plus récent que i car ArraySetAsSeries)
         // prevIdx < i en termes d'index mais prevIdx est plus récent en temps
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
      Print("✅ EMA ", prefix, " tracée: ", segmentsDrawn, " segments sur ", count, " bougies (jusqu'au prix actuel)");
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
   
   // Convertir le profit en symbolPoints
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double symbolPointValue = (tickValue / tickSize) * symbolPoint;
   
   // Calculer combien on peut perdre depuis le prix actuel tout en gardant le profit sécurisé
   // Si profit actuel = $5 et on veut sécuriser $2.5, on peut perdre max $2.5 depuis le prix actuel
   double maxDrawdownAllowed = profitToSecure;
   
   double symbolPointsToSecure = 0;
   if(symbolPointValue > 0 && lotSize > 0)
   {
      double profitPerPoint = lotSize * symbolPointValue;
      if(profitPerPoint > 0)
         symbolPointsToSecure = maxDrawdownAllowed / profitPerPoint;
   }
   
   // Si le calcul échoue, utiliser ATR comme fallback
   if(symbolPointsToSecure <= 0)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         // Utiliser une fraction de l'ATR basée sur le profit
         if(symbolPointValue > 0 && lotSize > 0)
         {
            double profitPerATR = lotSize * symbolPointValue * (atr[0] / symbolPoint);
            if(profitPerATR > 0)
               symbolPointsToSecure = maxDrawdownAllowed / profitPerATR * (atr[0] / symbolPoint);
         }
      }
      
      if(symbolPointsToSecure <= 0)
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
      newSL = NormalizeDouble(currentPrice - (symbolPointsToSecure * symbolPoint), _Digits);
      
      // S'assurer que le SL est au-dessus du prix d'entrée (break-even minimum)
      if(newSL < openPrice)
         newSL = NormalizeDouble(openPrice + (symbolPoint * 1), _Digits); // Break-even + 1 symbolPoint pour éviter le slippage
      
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
      newSL = NormalizeDouble(currentPrice + (symbolPointsToSecure * symbolPoint), _Digits);
      
      // S'assurer que le SL est en-dessous du prix d'entrée (break-even minimum)
      if(newSL > openPrice)
         newSL = NormalizeDouble(openPrice - (symbolPoint * 1), _Digits); // Break-even - 1 symbolPoint pour éviter le slippage
      
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
   double minDistance = stopLevel * symbolPoint;
   if(minDistance == 0 || minDistance < tickSize)
      minDistance = MathMax(tickSize * 3, 5 * symbolPoint);
   if(minDistance == 0)
      minDistance = 10 * symbolPoint; // Fallback final
   
   // Ajuster le SL pour respecter la distance minimum
   if(posType == POSITION_TYPE_BUY)
   {
      // Pour BUY: SL doit être en-dessous du prix actuel d'au moins minDistance
      double maxSL = currentPrice - minDistance;
      if(newSL >= maxSL)
      {
         newSL = NormalizeDouble(maxSL - (symbolPoint * 1), _Digits);
      }
      // S'assurer que le SL reste au-dessus du prix d'entrée (break-even minimum)
      if(newSL < openPrice)
      {
         double breakEvenSL = NormalizeDouble(openPrice + (symbolPoint * 1), _Digits);
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
         newSL = NormalizeDouble(minSL + (symbolPoint * 1), _Digits);
      }
      // S'assurer que le SL reste en-dessous du prix d'entrée (break-even minimum)
      if(newSL > openPrice)
      {
         double breakEvenSL = NormalizeDouble(openPrice - (symbolPoint * 1), _Digits);
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
   
   // Validation finale du SL avec vérification de valeurs aberrantes
   bool slValid = false;
   if(posType == POSITION_TYPE_BUY)
   {
      slValid = (newSL > 0 && newSL < currentPrice && newSL >= openPrice && 
                 (currentPrice - newSL) >= minDistance);
      // VALIDATION: Vérifier que le SL n'est pas aberrant (max 5% du prix actuel)
      if(slValid && (newSL > currentPrice * 1.05 || newSL < openPrice || newSL < currentPrice * 0.95))
      {
         slValid = false;
         if(DebugMode)
            Print("❌ SecureProfitForPosition: SL BUY aberrant (", DoubleToString(newSL, _Digits), 
                  " vs currentPrice=", DoubleToString(currentPrice, _Digits), ")");
      }
   }
   else
   {
      slValid = (newSL > 0 && newSL > currentPrice && newSL <= openPrice && 
                 (newSL - currentPrice) >= minDistance);
      // VALIDATION: Vérifier que le SL n'est pas aberrant (max 5% du prix actuel)
      if(slValid && (newSL < currentPrice * 0.95 || newSL > openPrice || newSL > currentPrice * 1.05))
      {
         slValid = false;
         if(DebugMode)
            Print("❌ SecureProfitForPosition: SL SELL aberrant (", DoubleToString(newSL, _Digits), 
                  " vs currentPrice=", DoubleToString(currentPrice, _Digits), ")");
      }
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
   
   // 1. SORTIE RAPIDE POUR SYNTÉTIQUES/FORX/OR
   // Fermer chaque position synthétique/forex/or dès que le profit atteint SyntheticForexTP (ex: 2$)
   bool isSyntheticForexOrGold = IsSyntheticForexOrGold(_Symbol);
   if(isSyntheticForexOrGold && SyntheticForexTP > 0.0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && positionInfo.SelectByTicket(ticket))
         {
            if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
            {
               double profit = positionInfo.Profit();
               
               // Fermer dès que le profit atteint 2$ ET minimum 1$
               if(profit >= SyntheticForexTP && profit >= MIN_PROFIT_TO_CLOSE)
               {
                  if(trade.PositionClose(ticket))
                  {
                     Print("✅ Synthétique/Forex/Or: Position fermée à TP 2$ (profit=", DoubleToString(profit, 2),
                           "$) - Prise de gain systématique sur ce type de symbole");
                     // Continuer la boucle pour gérer d'autres positions si besoin
                     continue;
                  }
                  else if(DebugMode)
                  {
                     Print("❌ Erreur fermeture position Synthétique/Forex/Or (TP 2$): ",
                           trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
                  }
               }
               else if(DebugMode && profit >= SyntheticForexTP && profit < MIN_PROFIT_TO_CLOSE)
               {
                  Print("⏸️ Synthétique/Forex/Or: Position conservée - Profit=", DoubleToString(profit, 2), 
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
            
               // ===== SPÉCIAL POUR CRYPTOS: Fermer à 0.5$ =====
               bool isCrypto = IsCryptoSymbol(_Symbol);
               double cryptoCloseThreshold = 0.5; // Fermer à 0.5$ pour cryptos
               
               if(isCrypto && currentProfit >= cryptoCloseThreshold)
               {
                  // Fermer immédiatement pour les cryptos à 0.5$
                  if(trade.PositionClose(ticket))
                  {
                     Print("✅ Position CRYPTO fermée à 0.5$: ", _Symbol, " | Profit: ", DoubleToString(currentProfit, 2), "$");
                     continue; // Passer à la position suivante
                  }
                  else if(DebugMode)
                  {
                     Print("⚠️ Erreur fermeture position CRYPTO: ", trade.ResultRetcodeDescription());
                  }
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
                     
                     // Convertir le profit en symbolPoints
                     double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                     double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                     double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                     double symbolPointValue = (tickValue / tickSize) * symbolPoint;
                     double lotSize = positionInfo.Volume();
                     
                     double symbolPointsToSecure = 0;
                     if(symbolPointValue > 0 && lotSize > 0)
                     {
                        double profitPerPoint = lotSize * symbolPointValue;
                        if(profitPerPoint > 0)
                           symbolPointsToSecure = profitToSecure / profitPerPoint;
                     }
                     
                     // Si le calcul échoue, utiliser ATR comme fallback
                     if(symbolPointsToSecure <= 0)
                     {
                        double atr[];
                        ArraySetAsSeries(atr, true);
                        if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
                           symbolPointsToSecure = (profitToSecure / (lotSize * symbolPointValue)) > 0 ? (profitToSecure / (lotSize * symbolPointValue)) : (atr[0] / symbolPoint);
                     }
                     
                     // VALIDATION CRITIQUE: Vérifier que symbolPointsToSecure est raisonnable
                     // Maximum 5% du prix actuel en symbolPoints (sécurité absolue)
                     double maxPointsAllowed = (currentPrice * 0.05) / symbolPoint;
                     if(symbolPointsToSecure <= 0 || symbolPointsToSecure > maxPointsAllowed)
                     {
                        if(DebugMode)
                           Print("❌ SecureDynamicProfits: symbolPointsToSecure invalide (", DoubleToString(symbolPointsToSecure, 2), 
                                 " > max ", DoubleToString(maxPointsAllowed, 2), ") - Abandon modification SL");
                        continue; // Abandonner cette modification
                     }
                     
                     // Calculer le nouveau SL pour sécuriser 50% du profit actuel
                     double newSL = 0.0;
                     
                     // Calculer le prix qui correspond à 50% du profit actuel
                     // Pour BUY: SL = prix d'entrée + (profit sécurisé en symbolPoints)
                     // Pour SELL: SL = prix d'entrée - (profit sécurisé en symbolPoints)
                     
                     if(posType == POSITION_TYPE_BUY)
                     {
                        // BUY: SL doit être au-dessus du prix d'entrée pour sécuriser le profit
                        newSL = openPrice + (symbolPointsToSecure * symbolPoint);
                        
                        // VALIDATION IMMÉDIATE: Vérifier que newSL est raisonnable AVANT toute autre logique
                        if(newSL <= openPrice || newSL >= currentPrice || newSL > currentPrice * 1.05)
                        {
                           if(DebugMode)
                              Print("❌ SecureDynamicProfits: newSL BUY invalide calculé (", DoubleToString(newSL, _Digits), 
                                    " openPrice=", DoubleToString(openPrice, _Digits), 
                                    " currentPrice=", DoubleToString(currentPrice, _Digits), ") - Abandon");
                           continue; // Abandonner cette modification
                        }
                        
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
                           double minDistance = stopLevel * symbolPoint;
                           if(minDistance == 0 || minDistance < tickSizeLocal)
                              minDistance = MathMax(tickSizeLocal * 3, 5 * symbolPoint);
                           
                           // VALIDATION: Vérifier que newSL n'est pas aberrant (max 5% du prix)
                           if(newSL > currentPrice * 1.05 || newSL < openPrice)
                           {
                              if(DebugMode)
                                 Print("❌ SecureDynamicProfits: SL BUY aberrant (", DoubleToString(newSL, _Digits), 
                                       " vs currentPrice=", DoubleToString(currentPrice, _Digits), ") - Abandon");
                              continue;
                           }
                           
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
                        newSL = openPrice - (symbolPointsToSecure * symbolPoint);
                        
                        // VALIDATION IMMÉDIATE: Vérifier que newSL est raisonnable AVANT toute autre logique
                        if(newSL >= openPrice || newSL <= currentPrice || newSL < currentPrice * 0.95)
                        {
                           if(DebugMode)
                              Print("❌ SecureDynamicProfits: newSL SELL invalide calculé (", DoubleToString(newSL, _Digits), 
                                    " openPrice=", DoubleToString(openPrice, _Digits), 
                                    " currentPrice=", DoubleToString(currentPrice, _Digits), ") - Abandon");
                           continue; // Abandonner cette modification
                        }
                        
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
                           double minDistance = stopLevel * symbolPoint;
                           if(minDistance == 0 || minDistance < tickSizeLocal)
                              minDistance = MathMax(tickSizeLocal * 3, 5 * symbolPoint);
                           
                           // VALIDATION: Vérifier que newSL n'est pas aberrant (max 5% du prix)
                           if(newSL < currentPrice * 0.95 || newSL > openPrice)
                           {
                              if(DebugMode)
                                 Print("❌ SecureDynamicProfits: SL SELL aberrant (", DoubleToString(newSL, _Digits), 
                                       " vs currentPrice=", DoubleToString(currentPrice, _Digits), ") - Abandon");
                              continue;
                           }
                           
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
   
   // Calculer la distance au prix en symbolPoints
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tolerance = 10 * symbolPoint; // Tolérance de 10 symbolPoints autour de l'EMA
   
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
            
            // Alerte sonore si spike attendu dans l'immédiat (< 15 secondes)
            if(estimatedSeconds <= 15)
            {
               PlaySound("alert.wav"); // Alerte sonore MT5 par défaut
               SendNotification("🚨 SPIKE BOOM IMMÉDIAT: " + _Symbol + " dans " + IntegerToString(estimatedSeconds) + "s");
            }
            
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
            
            // Alerte sonore si spike attendu dans l'immédiat (< 15 secondes)
            if(estimatedSeconds <= 15)
            {
               PlaySound("alert.wav"); // Alerte sonore MT5 par défaut
               SendNotification("🚨 SPIKE CRASH IMMÉDIAT: " + _Symbol + " dans " + IntegerToString(estimatedSeconds) + "s");
            }
            
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
   
   // Calculer la distance au prix en symbolPoints
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculer une tolérance adaptative basée sur ATR ou un pourcentage du prix
   // Pour les prix élevés (>1000), utiliser un pourcentage plutôt qu'un nombre fixe de symbolPoints
   double tolerance;
   if(emaFast[0] > 1000.0)
   {
      // Pour les prix élevés, utiliser 0.1% du prix (plus tolérant)
      tolerance = emaFast[0] * 0.001; // 0.1% du prix
   }
   else
   {
      // Pour les prix bas, utiliser une tolérance en symbolPoints ou basée sur ATR
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         tolerance = atr[0] * 0.5; // 0.5x ATR pour tolérance
      }
      else
      {
         tolerance = 10 * symbolPoint; // Fallback: 10 symbolPoints
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
      double distancePoints = MathAbs(currentPrice - emaFast[0]) / symbolPoint;
      double distancePercent = (MathAbs(currentPrice - emaFast[0]) / emaFast[0]) * 100.0;
      if(DebugMode)
         Print("⏸️ Prix pas au niveau EMA rapide M1: currentPrice=", DoubleToString(currentPrice, _Digits), 
               " close[0]=", DoubleToString(close[0], _Digits), " EMA=", DoubleToString(emaFast[0], _Digits), 
               " (distance: ", DoubleToString(distancePoints, 1), " symbolPoints / ", DoubleToString(distancePercent, 3), "%, tolérance: ", DoubleToString(tolerance, _Digits), ")");
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
//| Retour: true si rebond détecté, distance en symbolPoints dans distance |
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
   
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double toleranceM5 = 15 * symbolPoint;  // Tolérance de 15 symbolPoints pour EMA M5
   double toleranceH1 = 30 * symbolPoint;  // Tolérance de 30 symbolPoints pour EMA H1 (plus large car timeframe plus long)
   
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
            distance = distanceToEMAFastM5 / symbolPoint;
            if(DebugMode)
               Print("✅ Rebond BUY sur trendline EMA Fast M5 détecté (distance: ", DoubleToString(distance, 0), " symbolPoints) - Tendance H1 confirmée");
            return true;
         }
         else
         {
            // EMA H1 non alignée, mais EMA M5 OK = signal moyen
            distance = distanceToEMAFastM5 / symbolPoint;
            if(DebugMode)
               Print("⚠️ Rebond BUY sur EMA Fast M5 mais H1 non alignée (distance: ", DoubleToString(distance, 0), " symbolPoints) - Signal moyen");
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
            distance = distanceToEMAFastH1 / symbolPoint;
            if(DebugMode)
               Print("✅ Rebond BUY sur trendline EMA Fast H1 détecté (distance: ", DoubleToString(distance, 0), " symbolPoints) - Signal très fort");
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
            distance = distanceToEMAFastM5 / symbolPoint;
            if(DebugMode)
               Print("✅ Rebond SELL sur trendline EMA Fast M5 détecté (distance: ", DoubleToString(distance, 0), " symbolPoints) - Tendance H1 confirmée");
            return true;
         }
         else
         {
            // EMA H1 non alignée, mais EMA M5 OK = signal moyen
            distance = distanceToEMAFastM5 / symbolPoint;
            if(DebugMode)
               Print("⚠️ Rebond SELL sur EMA Fast M5 mais H1 non alignée (distance: ", DoubleToString(distance, 0), " symbolPoints) - Signal moyen");
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
            distance = distanceToEMAFastH1 / symbolPoint;
            if(DebugMode)
               Print("✅ Rebond SELL sur trendline EMA Fast H1 détecté (distance: ", DoubleToString(distance, 0), " symbolPoints) - Signal très fort");
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
   
   // 3. Détecter si on est en correction - Utiliser la nouvelle fonction améliorée
   // Cette fonction vérifie plusieurs critères pour détecter les corrections
   isCorrection = IsPriceInCorrectionZone(orderType);
   
   // Vérification supplémentaire: si on est dans une zone de correction M1
   if(!isCorrection)
   {
      // Vérifier aussi avec les EMA M1 pour plus de sécurité
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
                  Print("⚠️ Correction détectée pour BUY (EMA M1): Prix=", currentPrice, " EMA_Fast_M1=", emaFastM1[0], " < EMA_Slow_M1=", emaSlowM1[0]);
            }
         }
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
                  Print("⚠️ Correction détectée pour SELL (EMA M1): Prix=", currentPrice, " EMA_Fast_M1=", emaFastM1[0], " > EMA_Slow_M1=", emaSlowM1[0]);
            }
         }
      }
   }
   
   // 4. Confirmation EMA M5 selon le type d'ordre
   if(orderType == ORDER_TYPE_BUY)
   {
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
//| Vérifier si le prix est dans une zone de correction               |
//| Retourne true si le prix est en correction (ne pas trader)       |
//+------------------------------------------------------------------+
bool IsPriceInCorrectionZone(ENUM_ORDER_TYPE orderType)
{
   // Récupérer les prix et EMA M1
   double close[], emaFast[], emaSlow[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 10, close) < 10 ||
      CopyBuffer(emaFastHandle, 0, 0, 10, emaFast) < 10 ||
      CopyBuffer(emaSlowHandle, 0, 0, 10, emaSlow) < 10)
   {
      return false; // En cas d'erreur, ne pas bloquer
   }
   
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Pour BUY: correction = prix qui descend vers/depuis un support
   // Détection: les 3-5 dernières bougies montrent une baisse OU
   // le prix est en-dessous de l'EMA rapide ET l'EMA rapide descend
   if(orderType == ORDER_TYPE_BUY)
   {
      // Vérifier si les dernières bougies descendent
      bool isDescending = true;
      int descendingCount = 0;
      for(int i = 0; i < 5 && i < ArraySize(close) - 1; i++)
      {
         if(close[i] < close[i + 1])
            descendingCount++;
      }
      
      // Si 3+ bougies sur 5 descendent, c'est une correction
      if(descendingCount >= 3)
      {
         if(DebugMode)
            Print("⚠️ BUY: Correction détectée - ", descendingCount, "/5 dernières bougies descendent");
         return true;
      }
      
      // Vérifier si prix est sous EMA rapide ET EMA rapide descend
      bool priceBelowEMA = (currentPrice < emaFast[0]);
      bool emaDescending = (emaFast[0] < emaFast[1] && emaFast[1] < emaFast[2]);
      
      if(priceBelowEMA && emaDescending)
      {
         if(DebugMode)
            Print("⚠️ BUY: Correction détectée - Prix sous EMA rapide ET EMA descend");
         return true;
      }
   }
   // Pour SELL: correction = prix qui monte vers/depuis une résistance
   else if(orderType == ORDER_TYPE_SELL)
   {
      // Vérifier si les dernières bougies montent
      int ascendingCount = 0;
      for(int i = 0; i < 5 && i < ArraySize(close) - 1; i++)
      {
         if(close[i] > close[i + 1])
            ascendingCount++;
      }
      
      // Si 3+ bougies sur 5 montent, c'est une correction
      if(ascendingCount >= 3)
      {
         if(DebugMode)
            Print("⚠️ SELL: Correction détectée - ", ascendingCount, "/5 dernières bougies montent");
         return true;
      }
      
      // Vérifier si prix est au-dessus EMA rapide ET EMA rapide monte
      bool priceAboveEMA = (currentPrice > emaFast[0]);
      bool emaAscending = (emaFast[0] > emaFast[1] && emaFast[1] > emaFast[2]);
      
      if(priceAboveEMA && emaAscending)
      {
         if(DebugMode)
            Print("⚠️ SELL: Correction détectée - Prix au-dessus EMA rapide ET EMA monte");
         return true;
      }
   }
   
   return false; // Pas de correction détectée
}

//+------------------------------------------------------------------+
//| Vérifier un retournement franc après avoir touché EMA/Support/Résistance |
//| Retourne true si le prix a bien rebondi franchement              |
//+------------------------------------------------------------------+
bool CheckStrongReversalAfterTouch(ENUM_ORDER_TYPE orderType, double &touchLevel, string &touchSource)
{
   touchLevel = 0.0;
   touchSource = "";
   
   // Récupérer les données M1 et M5
   double closeM1[], highM1[], lowM1[], closeM5[], highM5[], lowM5[];
   double emaFastM1[], emaSlowM1[], emaFastM5[], emaSlowM5[];
   ArraySetAsSeries(closeM1, true);
   ArraySetAsSeries(highM1, true);
   ArraySetAsSeries(lowM1, true);
   ArraySetAsSeries(closeM5, true);
   ArraySetAsSeries(highM5, true);
   ArraySetAsSeries(lowM5, true);
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 10, closeM1) < 10 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 10, highM1) < 10 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 10, lowM1) < 10 ||
      CopyClose(_Symbol, PERIOD_M5, 0, 5, closeM5) < 5 ||
      CopyHigh(_Symbol, PERIOD_M5, 0, 5, highM5) < 5 ||
      CopyLow(_Symbol, PERIOD_M5, 0, 5, lowM5) < 5 ||
      CopyBuffer(emaFastHandle, 0, 0, 10, emaFastM1) < 10 ||
      CopyBuffer(emaSlowHandle, 0, 0, 10, emaSlowM1) < 10 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 5, emaFastM5) < 5 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 5, emaSlowM5) < 5)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération données pour vérification retournement franc");
      return false;
   }
   
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Calculer ATR pour tolérance
   double atr[];
   ArraySetAsSeries(atr, true);
   double tolerance = 0.0;
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      tolerance = atr[0] * 0.3; // 0.3x ATR pour tolérance
   else
      tolerance = currentPrice * 0.001; // Fallback: 0.1% du prix
   
   // Pour BUY: vérifier si le prix a touché un support (EMA ou bas récent) et rebondi
   if(orderType == ORDER_TYPE_BUY)
   {
      // Vérifier touche de l'EMA rapide M1
      bool touchedEMA = false;
      for(int i = 1; i < 5 && i < ArraySize(lowM1); i++)
      {
         if(lowM1[i] <= (emaFastM1[i] + tolerance) && lowM1[i] >= (emaFastM1[i] - tolerance))
         {
            touchLevel = emaFastM1[i];
            touchSource = "EMA Fast M1";
            touchedEMA = true;
            break;
         }
      }
      
      // Si pas d'EMA touchée, vérifier support bas récent
      if(!touchedEMA)
      {
         // Trouver le bas le plus récent des 5 dernières bougies M1
         double lowestLow = lowM1[0];
         int lowestIdx = 0;
         for(int i = 1; i < 5 && i < ArraySize(lowM1); i++)
         {
            if(lowM1[i] < lowestLow)
            {
               lowestLow = lowM1[i];
               lowestIdx = i;
            }
         }
         
         // Vérifier si le prix actuel est revenu au-dessus de ce bas (retournement)
         if(currentPrice > lowestLow + tolerance && closeM1[0] > lowM1[lowestIdx])
         {
            touchLevel = lowestLow;
            touchSource = "Support bas récent";
            touchedEMA = true;
         }
      }
      
      if(!touchedEMA)
      {
         if(DebugMode)
            Print("⏸️ BUY: Pas de touche de support détectée");
         return false;
      }
      
      // Vérifier que le prix a rebondi FRANCHEMENT après la touche
      // Conditions: 
      // 1. La bougie après la touche est verte (close > open)
      // 2. Le prix actuel est nettement au-dessus du niveau touché
      // 3. Au moins 2 bougies vertes consécutives après la touche
      int greenCandlesAfterTouch = 0;
      double touchPrice = touchLevel;
      
      // Compter les bougies vertes après la touche
      for(int i = 0; i < 4 && i < ArraySize(closeM1) - 1; i++)
      {
         if(lowM1[i] <= touchPrice + tolerance || 
            (i > 0 && lowM1[i-1] <= touchPrice + tolerance))
         {
            // Après la touche, vérifier les bougies suivantes
            for(int j = i - 1; j >= 0 && j >= 0; j--)
            {
               if(closeM1[j] > (closeM1[j+1] + tolerance)) // Bougie verte
                  greenCandlesAfterTouch++;
            }
            break;
         }
      }
      
      // Vérifier aussi la bougie actuelle
      if(closeM1[0] > closeM1[1])
         greenCandlesAfterTouch++;
      
      // Vérifier que le prix actuel est bien au-dessus du niveau touché
      double bounceDistance = currentPrice - touchPrice;
      double minBouncePercent = 0.05; // Minimum 0.05% de rebond
      bool strongBounce = (bounceDistance >= touchPrice * minBouncePercent / 100.0);
      
      // Retournement franc = au moins 2 bougies vertes + rebond clair
      if(greenCandlesAfterTouch >= 2 && strongBounce)
      {
         if(DebugMode)
            Print("✅ BUY: Retournement franc confirmé - Touché ", touchSource, " à ", DoubleToString(touchPrice, _Digits), 
                  " puis ", greenCandlesAfterTouch, " bougies vertes, rebond ", DoubleToString(bounceDistance, _Digits));
         return true;
      }
      else
      {
         if(DebugMode)
            Print("⏸️ BUY: Retournement pas assez franc - Bougies vertes: ", greenCandlesAfterTouch, 
                  " Rebond: ", DoubleToString(bounceDistance, _Digits));
         return false;
      }
   }
   // Pour SELL: vérifier si le prix a touché une résistance (EMA ou haut récent) et rebondi
   else if(orderType == ORDER_TYPE_SELL)
   {
      // Vérifier touche de l'EMA rapide M1
      bool touchedEMA = false;
      for(int i = 1; i < 5 && i < ArraySize(highM1); i++)
      {
         if(highM1[i] >= (emaFastM1[i] - tolerance) && highM1[i] <= (emaFastM1[i] + tolerance))
         {
            touchLevel = emaFastM1[i];
            touchSource = "EMA Fast M1";
            touchedEMA = true;
            break;
         }
      }
      
      // Si pas d'EMA touchée, vérifier résistance haut récent
      if(!touchedEMA)
      {
         // Trouver le haut le plus récent des 5 dernières bougies M1
         double highestHigh = highM1[0];
         int highestIdx = 0;
         for(int i = 1; i < 5 && i < ArraySize(highM1); i++)
         {
            if(highM1[i] > highestHigh)
            {
               highestHigh = highM1[i];
               highestIdx = i;
            }
         }
         
         // Vérifier si le prix actuel est redescendu sous ce haut (retournement)
         if(currentPrice < highestHigh - tolerance && closeM1[0] < highM1[highestIdx])
         {
            touchLevel = highestHigh;
            touchSource = "Résistance haut récent";
            touchedEMA = true;
         }
      }
      
      if(!touchedEMA)
      {
         if(DebugMode)
            Print("⏸️ SELL: Pas de touche de résistance détectée");
         return false;
      }
      
      // Vérifier que le prix a rebondi FRANCHEMENT à la baisse après la touche
      // Conditions:
      // 1. La bougie après la touche est rouge (close < open)
      // 2. Le prix actuel est nettement sous le niveau touché
      // 3. Au moins 2 bougies rouges consécutives après la touche
      int redCandlesAfterTouch = 0;
      double touchPrice = touchLevel;
      
      // Compter les bougies rouges après la touche
      for(int i = 0; i < 4 && i < ArraySize(closeM1) - 1; i++)
      {
         if(highM1[i] >= touchPrice - tolerance || 
            (i > 0 && highM1[i-1] >= touchPrice - tolerance))
         {
            // Après la touche, vérifier les bougies suivantes
            for(int j = i - 1; j >= 0 && j >= 0; j--)
            {
               if(closeM1[j] < (closeM1[j+1] - tolerance)) // Bougie rouge
                  redCandlesAfterTouch++;
            }
            break;
         }
      }
      
      // Vérifier aussi la bougie actuelle
      if(closeM1[0] < closeM1[1])
         redCandlesAfterTouch++;
      
      // Vérifier que le prix actuel est bien sous le niveau touché
      double bounceDistance = touchPrice - currentPrice;
      double minBouncePercent = 0.05; // Minimum 0.05% de rebond
      bool strongBounce = (bounceDistance >= touchPrice * minBouncePercent / 100.0);
      
      // Retournement franc = au moins 2 bougies rouges + rebond clair
      if(redCandlesAfterTouch >= 2 && strongBounce)
      {
         if(DebugMode)
            Print("✅ SELL: Retournement franc confirmé - Touché ", touchSource, " à ", DoubleToString(touchPrice, _Digits), 
                  " puis ", redCandlesAfterTouch, " bougies rouges, rebond ", DoubleToString(bounceDistance, _Digits));
         return true;
      }
      else
      {
         if(DebugMode)
            Print("⏸️ SELL: Retournement pas assez franc - Bougies rouges: ", redCandlesAfterTouch, 
                  " Rebond: ", DoubleToString(bounceDistance, _Digits));
         return false;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier la confirmation M5 du retournement                       |
//| OBLIGATOIRE avant de prendre position                             |
//+------------------------------------------------------------------+
bool CheckM5ReversalConfirmation(ENUM_ORDER_TYPE orderType)
{
   // Récupérer les données M5
   double closeM5[], highM5[], lowM5[], openM5[];
   double emaFastM5[], emaSlowM5[];
   ArraySetAsSeries(closeM5, true);
   ArraySetAsSeries(highM5, true);
   ArraySetAsSeries(lowM5, true);
   ArraySetAsSeries(openM5, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   
   if(CopyClose(_Symbol, PERIOD_M5, 0, 5, closeM5) < 5 ||
      CopyHigh(_Symbol, PERIOD_M5, 0, 5, highM5) < 5 ||
      CopyLow(_Symbol, PERIOD_M5, 0, 5, lowM5) < 5 ||
      CopyOpen(_Symbol, PERIOD_M5, 0, 5, openM5) < 5 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 5, emaFastM5) < 5 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 5, emaSlowM5) < 5)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération données M5 pour confirmation");
      return false;
   }
   
   // Pour BUY: confirmation M5 = bougie verte ET EMA M5 haussière
   if(orderType == ORDER_TYPE_BUY)
   {
      // La bougie M5 actuelle doit être verte (close > open)
      bool isGreenM5 = (closeM5[0] > openM5[0]);
      
      // L'EMA M5 doit être haussière (Fast >= Slow)
      bool emaBullishM5 = (emaFastM5[0] >= emaSlowM5[0]);
      
      // Vérifier aussi que la bougie précédente M5 confirme (au moins une bougie verte récente)
      bool previousGreenM5 = (closeM5[1] > openM5[1]);
      
      // Le prix M5 doit être au-dessus ou proche de l'EMA rapide M5
      double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double toleranceM5 = 10 * symbolPoint;
      bool priceNearEMA = (closeM5[0] >= (emaFastM5[0] - toleranceM5));
      
      // Confirmation M5 = bougie verte + EMA haussière + prix proche EMA
      if(isGreenM5 && emaBullishM5 && priceNearEMA)
      {
         if(DebugMode)
            Print("✅ BUY: Confirmation M5 OK - Bougie verte, EMA haussière (Fast=", DoubleToString(emaFastM5[0], _Digits), 
                  " >= Slow=", DoubleToString(emaSlowM5[0], _Digits), "), Prix proche EMA");
         return true;
      }
      else
      {
         if(DebugMode)
            Print("❌ BUY: Confirmation M5 échouée - Bougie verte: ", isGreenM5, " EMA haussière: ", emaBullishM5, 
                  " Prix proche EMA: ", priceNearEMA);
         return false;
      }
   }
   // Pour SELL: confirmation M5 = bougie rouge ET EMA M5 baissière
   else if(orderType == ORDER_TYPE_SELL)
   {
      // La bougie M5 actuelle doit être rouge (close < open)
      bool isRedM5 = (closeM5[0] < openM5[0]);
      
      // L'EMA M5 doit être baissière (Fast <= Slow)
      bool emaBearishM5 = (emaFastM5[0] <= emaSlowM5[0]);
      
      // Le prix M5 doit être sous ou proche de l'EMA rapide M5
      double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double toleranceM5 = 10 * symbolPoint;
      bool priceNearEMA = (closeM5[0] <= (emaFastM5[0] + toleranceM5));
      
      // Confirmation M5 = bougie rouge + EMA baissière + prix proche EMA
      if(isRedM5 && emaBearishM5 && priceNearEMA)
      {
         if(DebugMode)
            Print("✅ SELL: Confirmation M5 OK - Bougie rouge, EMA baissière (Fast=", DoubleToString(emaFastM5[0], _Digits), 
                  " <= Slow=", DoubleToString(emaSlowM5[0], _Digits), "), Prix proche EMA");
         return true;
      }
      else
      {
         if(DebugMode)
            Print("❌ SELL: Confirmation M5 échouée - Bougie rouge: ", isRedM5, " EMA baissière: ", emaBearishM5, 
                  " Prix proche EMA: ", priceNearEMA);
         return false;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Trouver le prochain Support ou Résistance                        |
//| Retourne le niveau le plus proche dans la direction du trade     |
//+------------------------------------------------------------------+
double FindNextSupportResistance(ENUM_ORDER_TYPE orderType, double currentPrice)
{
   // Récupérer les données pour calculer les niveaux S/R
   double atrM5[], atrH1[];
   double ema50[], ema100[], ema200[], emaFastM5[], emaSlowM5[];
   ArraySetAsSeries(atrM5, true);
   ArraySetAsSeries(atrH1, true);
   ArraySetAsSeries(ema50, true);
   ArraySetAsSeries(ema100, true);
   ArraySetAsSeries(ema200, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   
   // Récupérer les historiques de prix pour trouver les pivots
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 20, high) < 20 ||
      CopyLow(_Symbol, PERIOD_H1, 0, 20, low) < 20 ||
      CopyClose(_Symbol, PERIOD_H1, 0, 20, close) < 20)
   {
      // Fallback: utiliser ATR si pas assez de données
      if(CopyBuffer(atrH1Handle, 0, 0, 1, atrH1) > 0 && atrH1[0] > 0)
      {
         if(orderType == ORDER_TYPE_BUY)
            return currentPrice + (2.0 * atrH1[0]); // Résistance estimée
         else
            return currentPrice - (2.0 * atrH1[0]); // Support estimé
      }
      return 0.0; // Pas de données
   }
   
   // Pour BUY: chercher la prochaine résistance (au-dessus du prix actuel)
   if(orderType == ORDER_TYPE_BUY)
   {
      double nextResistance = 0.0;
      double minDistance = DBL_MAX;
      
      // Chercher les hauts récents (pivots) comme résistances potentielles
      for(int i = 2; i < 18 && i < ArraySize(high); i++)
      {
         // Pivot haut = high[i] > high[i-1] && high[i] > high[i+1]
         if(high[i] > high[i-1] && high[i] > high[i+1] && high[i] > currentPrice)
         {
            double distance = high[i] - currentPrice;
            if(distance < minDistance)
            {
               minDistance = distance;
               nextResistance = high[i];
            }
         }
      }
      
      // Si pas de pivot trouvé, chercher les EMA comme résistances
      if(nextResistance == 0.0)
      {
         if(CopyBuffer(ema50Handle, 0, 0, 1, ema50) > 0 && ema50[0] > currentPrice)
         {
            double dist50 = ema50[0] - currentPrice;
            if(dist50 < minDistance)
            {
               minDistance = dist50;
               nextResistance = ema50[0];
            }
         }
         if(CopyBuffer(ema100Handle, 0, 0, 1, ema100) > 0 && ema100[0] > currentPrice)
         {
            double dist100 = ema100[0] - currentPrice;
            if(dist100 < minDistance)
            {
               minDistance = dist100;
               nextResistance = ema100[0];
            }
         }
         if(CopyBuffer(ema200Handle, 0, 0, 1, ema200) > 0 && ema200[0] > currentPrice)
         {
            double dist200 = ema200[0] - currentPrice;
            if(dist200 < minDistance)
            {
               minDistance = dist200;
               nextResistance = ema200[0];
            }
         }
      }
      
      // Si toujours rien, utiliser ATR pour estimer
      if(nextResistance == 0.0)
      {
         if(CopyBuffer(atrH1Handle, 0, 0, 1, atrH1) > 0 && atrH1[0] > 0)
            nextResistance = currentPrice + (2.0 * atrH1[0]);
         else
            nextResistance = currentPrice * 1.01; // Fallback: 1% au-dessus
      }
      
      if(DebugMode)
         Print("📊 Prochaine résistance trouvée: ", DoubleToString(nextResistance, _Digits), " (distance: ", DoubleToString(minDistance, _Digits), ")");
      
      return nextResistance;
   }
   // Pour SELL: chercher le prochain support (sous le prix actuel)
   else if(orderType == ORDER_TYPE_SELL)
   {
      double nextSupport = 0.0;
      double minDistance = DBL_MAX;
      
      // Chercher les bas récents (pivots) comme supports potentiels
      for(int i = 2; i < 18 && i < ArraySize(low); i++)
      {
         // Pivot bas = low[i] < low[i-1] && low[i] < low[i+1]
         if(low[i] < low[i-1] && low[i] < low[i+1] && low[i] < currentPrice)
         {
            double distance = currentPrice - low[i];
            if(distance < minDistance)
            {
               minDistance = distance;
               nextSupport = low[i];
            }
         }
      }
      
      // Si pas de pivot trouvé, chercher les EMA comme supports
      if(nextSupport == 0.0)
      {
         if(CopyBuffer(ema50Handle, 0, 0, 1, ema50) > 0 && ema50[0] < currentPrice)
         {
            double dist50 = currentPrice - ema50[0];
            if(dist50 < minDistance)
            {
               minDistance = dist50;
               nextSupport = ema50[0];
            }
         }
         if(CopyBuffer(ema100Handle, 0, 0, 1, ema100) > 0 && ema100[0] < currentPrice)
         {
            double dist100 = currentPrice - ema100[0];
            if(dist100 < minDistance)
            {
               minDistance = dist100;
               nextSupport = ema100[0];
            }
         }
         if(CopyBuffer(ema200Handle, 0, 0, 1, ema200) > 0 && ema200[0] < currentPrice)
         {
            double dist200 = currentPrice - ema200[0];
            if(dist200 < minDistance)
            {
               minDistance = dist200;
               nextSupport = ema200[0];
            }
         }
      }
      
      // Si toujours rien, utiliser ATR pour estimer
      if(nextSupport == 0.0)
      {
         if(CopyBuffer(atrH1Handle, 0, 0, 1, atrH1) > 0 && atrH1[0] > 0)
            nextSupport = currentPrice - (2.0 * atrH1[0]);
         else
            nextSupport = currentPrice * 0.99; // Fallback: 1% sous
      }
      
      if(DebugMode)
         Print("📊 Prochain support trouvé: ", DoubleToString(nextSupport, _Digits), " (distance: ", DoubleToString(minDistance, _Digits), ")");
      
      return nextSupport;
   }
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Calculer le TP dynamique au prochain Support/Résistance          |
//| Utilise FindNextSupportResistance pour déterminer le TP          |
//+------------------------------------------------------------------+
double CalculateDynamicTP(ENUM_ORDER_TYPE orderType, double entryPrice)
{
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Trouver le prochain niveau Support/Résistance
   double nextLevel = FindNextSupportResistance(orderType, currentPrice);
   
   if(nextLevel == 0.0)
   {
      // Fallback: utiliser le TP fixe si pas de niveau trouvé
      if(DebugMode)
         Print("⚠️ TP dynamique: Pas de niveau S/R trouvé, utilisation TP fixe");
      
      // Calculer TP fixe basé sur TakeProfitUSD
      double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double lotSize = NormalizeLotSize(InitialLotSize);
      
      if(tickValue > 0 && tickSize > 0)
      {
         double tpDistance = (TakeProfitUSD / (lotSize * tickValue / tickSize));
         if(orderType == ORDER_TYPE_BUY)
            return NormalizeDouble(entryPrice + tpDistance, _Digits);
         else
            return NormalizeDouble(entryPrice - tpDistance, _Digits);
      }
      
      // Fallback ultime: pourcentage du prix
      if(orderType == ORDER_TYPE_BUY)
         return NormalizeDouble(entryPrice * 1.01, _Digits); // 1% au-dessus
      else
         return NormalizeDouble(entryPrice * 0.99, _Digits); // 1% sous
   }
   
   // Vérifier que le niveau trouvé est valide et raisonnable
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDistance = 10 * symbolPoint; // Distance minimum
   double maxDistancePercent = 0.05; // Maximum 5% du prix
   
   if(orderType == ORDER_TYPE_BUY)
   {
      double distance = nextLevel - entryPrice;
      if(distance < minDistance)
      {
         // TP trop proche, utiliser un minimum
         nextLevel = entryPrice + minDistance;
      }
      else if(distance > (entryPrice * maxDistancePercent))
      {
         // TP trop loin, limiter à maxDistancePercent
         nextLevel = entryPrice * (1.0 + maxDistancePercent);
      }
      
      if(DebugMode)
         Print("✅ TP dynamique BUY: ", DoubleToString(nextLevel, _Digits), " (distance: ", DoubleToString(distance, _Digits), ")");
      
      return NormalizeDouble(nextLevel, _Digits);
   }
   else // SELL
   {
      double distance = entryPrice - nextLevel;
      if(distance < minDistance)
      {
         // TP trop proche, utiliser un minimum
         nextLevel = entryPrice - minDistance;
      }
      else if(distance > (entryPrice * maxDistancePercent))
      {
         // TP trop loin, limiter à maxDistancePercent
         nextLevel = entryPrice * (1.0 - maxDistancePercent);
      }
      
      if(DebugMode)
         Print("✅ TP dynamique SELL: ", DoubleToString(nextLevel, _Digits), " (distance: ", DoubleToString(distance, _Digits), ")");
      
      return NormalizeDouble(nextLevel, _Digits);
   }
   
   return 0.0;
}

//+------------------------------------------------------------------+
//| Obtenir le nom du fichier CSV basé sur la date                    |
//+------------------------------------------------------------------+
string GetCSVFileName()
{
   datetime currentDate = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentDate, dt);
   
   string dateStr = StringFormat("%04d%02d%02d", dt.year, dt.mon, dt.day);
   string fileName = "Files\\" + CSVFileNamePrefix + "_" + dateStr + ".csv";
   
   return fileName;
}

//+------------------------------------------------------------------+
//| Initialiser le fichier CSV avec l'en-tête                         |
//+------------------------------------------------------------------+
void InitializeCSVFile()
{
   // Vérifier si on doit créer un nouveau fichier (changement de jour)
   datetime currentDate = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentDate, dt);
   datetime todayStart = StructToTime(dt);
   
   // Si c'est un nouveau jour ou le fichier n'existe pas encore
   if(g_csvFileDate == 0 || todayStart > g_csvFileDate)
   {
      g_csvFileName = GetCSVFileName();
      g_csvFileDate = todayStart;
      
      // S'assurer que le dossier Files existe AVANT d'ouvrir le fichier
      EnsureFilesDirectoryExists();
      
      // Vérifier si le fichier existe déjà
      int fileHandle = FileOpen(g_csvFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
      bool fileExists = (fileHandle != INVALID_HANDLE);
      
      if(fileHandle != INVALID_HANDLE)
         FileClose(fileHandle);
      
      // Si le fichier n'existe pas, créer l'en-tête
      if(!fileExists)
      {
         fileHandle = FileOpen(g_csvFileName, FILE_WRITE|FILE_CSV|FILE_COMMON);
         if(fileHandle != INVALID_HANDLE)
         {
            // Écrire l'en-tête CSV
            FileWrite(fileHandle, 
                     "Date_Heure_Ouverture",
                     "Date_Heure_Fermeture",
                     "Ticket",
                     "Symbole",
                     "Type",
                     "Lot",
                     "Prix_Entree",
                     "Prix_Sortie",
                     "Stop_Loss",
                     "Take_Profit",
                     "Profit_USD",
                     "Swap",
                     "Commission",
                     "Duree_Secondes",
                     "Duree_Formatee",
                     "Raison_Fermeture",
                     "Profit_Max_Atteint",
                     "Drawdown_Max",
                     "Confiance_IA",
                     "Action_IA",
                     "Commentaire");
            
            FileClose(fileHandle);
            
            if(DebugMode)
               Print("✅ Fichier CSV créé: ", g_csvFileName);
         }
         else
         {
            int error = GetLastError();
            string errorMsg = (error == 5004) ? "FILE_NOT_TOWRITE (fichier verrouillé ou dossier inexistant)" : 
                              (error == 5002) ? "FILE_NOT_FOUND" : 
                              (error == 5001) ? "FILE_NOT_EXIST" : 
                              "Code: " + IntegerToString(error);
            Print("❌ Erreur création fichier CSV (", g_csvFileName, "): ", errorMsg);
         }
      }
      else
      {
         if(DebugMode)
            Print("📄 Fichier CSV existant trouvé: ", g_csvFileName);
      }
   }
}

//+------------------------------------------------------------------+
//| Enregistrer l'ouverture d'un trade dans le CSV                    |
//+------------------------------------------------------------------+
void LogTradeOpen(ulong ticket)
{
   if(!EnableCSVLogging || ticket == 0)
      return;
   
   // Vérifier que le fichier CSV est initialisé
   if(g_csvFileName == "")
      InitializeCSVFile();
   
   // Sélectionner la position
   if(!positionInfo.SelectByTicket(ticket))
   {
      if(DebugMode)
         Print("⚠️ LogTradeOpen: Impossible de sélectionner la position ", ticket);
      return;
   }
   
   // Vérifier que c'est notre position
   if(positionInfo.Magic() != InpMagicNumber)
      return;
   
   // Vérifier si ce trade n'est pas déjà enregistré
   for(int i = 0; i < g_tradeRecordsCount; i++)
   {
      if(g_tradeRecords[i].ticket == ticket && !g_tradeRecords[i].isClosed)
      {
         // Trade déjà enregistré
         return;
      }
   }
   
   // Créer un nouvel enregistrement
   TradeRecord record;
   record.ticket = ticket;
   record.symbol = positionInfo.Symbol();
   record.type = (ENUM_POSITION_TYPE)positionInfo.PositionType();
   record.openTime = (datetime)positionInfo.Time();
   record.closeTime = 0;
   record.openPrice = positionInfo.PriceOpen();
   record.closePrice = 0.0;
   record.lotSize = positionInfo.Volume();
   record.stopLoss = positionInfo.StopLoss();
   record.takeProfit = positionInfo.TakeProfit();
   record.profit = 0.0;
   record.swap = 0.0;
   record.commission = 0.0;
   record.comment = positionInfo.Comment();
   record.isClosed = false;
   record.maxProfit = 0.0;
   record.maxDrawdown = 0.0;
   record.durationSeconds = 0;
   record.closeReason = "";
   record.aiConfidence = g_lastAIConfidence;
   record.aiAction = g_lastAIAction;
   
   // Ajouter au tableau
   int idx = g_tradeRecordsCount;
   ArrayResize(g_tradeRecords, idx + 1);
   g_tradeRecords[idx] = record;
   g_tradeRecordsCount++;
   
   if(DebugMode)
      Print("📝 Trade ouvert enregistré dans CSV: Ticket=", ticket, " Symbole=", record.symbol, " Type=", EnumToString(record.type));
}

//+------------------------------------------------------------------+
//| Enregistrer la fermeture d'un trade dans le CSV                   |
//+------------------------------------------------------------------+
void LogTradeClose(ulong ticket, string closeReason)
{
   if(!EnableCSVLogging || ticket == 0)
      return;
   
   // Vérifier que le fichier CSV est initialisé
   if(g_csvFileName == "")
      InitializeCSVFile();
   
   // Trouver l'enregistrement correspondant
   int recordIdx = -1;
   for(int i = 0; i < g_tradeRecordsCount; i++)
   {
      if(g_tradeRecords[i].ticket == ticket && !g_tradeRecords[i].isClosed)
      {
         recordIdx = i;
         break;
      }
   }
   
   // Si pas trouvé, essayer de créer un enregistrement depuis l'historique
   if(recordIdx == -1)
   {
      // Chercher dans l'historique des positions fermées
      if(HistorySelectByPosition(ticket))
      {
         int totalDeals = HistoryDealsTotal();
         if(totalDeals > 0)
         {
            // Créer un enregistrement depuis l'historique
            TradeRecord record;
            record.ticket = ticket;
            
            // Trouver le deal d'entrée et de sortie
            double totalProfit = 0.0;
            double totalSwap = 0.0;
            double totalCommission = 0.0;
            datetime openTime = 0;
            datetime closeTime = 0;
            double openPrice = 0.0;
            double closePrice = 0.0;
            double lotSize = 0.0;
            double sl = 0.0;
            double tp = 0.0;
            string symbol = "";
            ENUM_POSITION_TYPE posType = WRONG_VALUE;
            
            for(int i = 0; i < totalDeals; i++)
            {
               ulong dealTicket = HistoryDealGetTicket(i);
               if(dealTicket > 0 && HistoryDealSelect(dealTicket))
               {
                  if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber)
                  {
                     ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
                     
                     if(dealEntry == DEAL_ENTRY_IN)
                     {
                        openTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                        openPrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                        lotSize = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
                        symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
                        ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
                        if(dealType == DEAL_TYPE_BUY)
                           posType = POSITION_TYPE_BUY;
                        else if(dealType == DEAL_TYPE_SELL)
                           posType = POSITION_TYPE_SELL;
                     }
                     else if(dealEntry == DEAL_ENTRY_OUT)
                     {
                        closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                        closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                        totalProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                        totalSwap += HistoryDealGetDouble(dealTicket, DEAL_SWAP);
                        totalCommission += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
                     }
                  }
               }
            }
            
            if(openTime > 0 && closeTime > 0)
            {
               record.symbol = symbol;
               record.type = posType;
               record.openTime = openTime;
               record.closeTime = closeTime;
               record.openPrice = openPrice;
               record.closePrice = closePrice;
               record.lotSize = lotSize;
               record.stopLoss = sl;
               record.takeProfit = tp;
               record.profit = totalProfit;
               record.swap = totalSwap;
               record.commission = totalCommission;
               record.comment = "";
               record.isClosed = true;
               record.maxProfit = totalProfit; // Approximation
               record.maxDrawdown = 0.0;
               record.durationSeconds = (int)(closeTime - openTime);
               record.closeReason = closeReason;
               record.aiConfidence = 0.0;
               record.aiAction = "";
               
               // Ajouter au tableau
               recordIdx = g_tradeRecordsCount;
               ArrayResize(g_tradeRecords, recordIdx + 1);
               g_tradeRecords[recordIdx] = record;
               g_tradeRecordsCount++;
            }
         }
      }
   }
   
   // Si toujours pas trouvé, retourner
   if(recordIdx == -1)
   {
      if(DebugMode)
         Print("⚠️ LogTradeClose: Trade ", ticket, " non trouvé dans les enregistrements");
      return;
   }
   
   // Mettre à jour l'enregistrement avec les informations de fermeture
   TradeRecord record = g_tradeRecords[recordIdx];
   
   // Récupérer les informations depuis l'historique
   if(HistorySelectByPosition(ticket))
   {
      int totalDeals = HistoryDealsTotal();
      double totalProfit = 0.0;
      double totalSwap = 0.0;
      double totalCommission = 0.0;
      datetime closeTime = 0;
      double closePrice = 0.0;
      
      for(int i = 0; i < totalDeals; i++)
      {
         ulong dealTicket = HistoryDealGetTicket(i);
         if(dealTicket > 0 && HistoryDealSelect(dealTicket))
         {
            if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagicNumber)
            {
               ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
               
               if(dealEntry == DEAL_ENTRY_OUT)
               {
                  closeTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                  closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                  totalProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                  totalSwap += HistoryDealGetDouble(dealTicket, DEAL_SWAP);
                  totalCommission += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
               }
            }
         }
      }
      
      record.closeTime = closeTime;
      record.closePrice = closePrice;
      record.profit = totalProfit;
      record.swap = totalSwap;
      record.commission = totalCommission;
      record.isClosed = true;
      record.durationSeconds = (int)(closeTime - record.openTime);
      record.closeReason = closeReason;
   }
   
   // Écrire dans le CSV
   WriteTradeToCSV(record);
   
   // NOUVEAU: Enregistrer la perte pour suivi des pertes consécutives
   if(record.profit < 0)
   {
      int direction = (record.type == POSITION_TYPE_BUY) ? 1 : -1;
      RecordSymbolLoss(record.symbol, direction, record.profit);
   }
   else if(record.profit > 0)
   {
      // Profit positif : réinitialiser le tracker pour ce symbole
      int direction = (record.type == POSITION_TYPE_BUY) ? 1 : -1;
      ResetSymbolLossTracker(record.symbol, direction);
   }
   
   if(DebugMode)
      Print("📝 Trade fermé enregistré dans CSV: Ticket=", ticket, " Profit=", DoubleToString(record.profit, 2), " USD");
}

//+------------------------------------------------------------------+
//| Mettre à jour un enregistrement de trade (pour profit max, etc.) |
//+------------------------------------------------------------------+
void UpdateTradeRecord(ulong ticket)
{
   if(!EnableCSVLogging || ticket == 0)
      return;
   
   // Trouver l'enregistrement
   for(int i = 0; i < g_tradeRecordsCount; i++)
   {
      if(g_tradeRecords[i].ticket == ticket && !g_tradeRecords[i].isClosed)
      {
         if(positionInfo.SelectByTicket(ticket))
         {
            double currentProfit = positionInfo.Profit();
            
            // Mettre à jour le profit maximum
            if(currentProfit > g_tradeRecords[i].maxProfit)
               g_tradeRecords[i].maxProfit = currentProfit;
            
            // Calculer le drawdown maximum
            if(g_tradeRecords[i].maxProfit > 0)
            {
               double currentDrawdown = g_tradeRecords[i].maxProfit - currentProfit;
               if(currentDrawdown > g_tradeRecords[i].maxDrawdown)
                  g_tradeRecords[i].maxDrawdown = currentDrawdown;
            }
         }
         break;
      }
   }
}

//+------------------------------------------------------------------+
//| Écrire un trade dans le fichier CSV                              |
//+------------------------------------------------------------------+
void WriteTradeToCSV(const TradeRecord& record)
{
   if(!EnableCSVLogging || g_csvFileName == "")
      return;
   
   // S'assurer que le dossier Files existe AVANT d'ouvrir le fichier
   EnsureFilesDirectoryExists();
   
   // Vérifier que le fichier existe et l'ouvrir en mode append
   int fileHandle = FileOpen(g_csvFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
   if(fileHandle == INVALID_HANDLE)
   {
      int error = GetLastError();
      string errorMsg = (error == 5004) ? "FILE_NOT_TOWRITE (fichier verrouillé ou dossier inexistant)" : 
                        (error == 5002) ? "FILE_NOT_FOUND" : 
                        (error == 5001) ? "FILE_NOT_EXIST" : 
                        "Code: " + IntegerToString(error);
      if(DebugMode)
         Print("❌ Erreur ouverture fichier CSV (", g_csvFileName, "): ", errorMsg);
      return;
   }
   
   // Aller à la fin du fichier
   FileSeek(fileHandle, 0, SEEK_END);
   
   // Formater la date/heure d'ouverture
   MqlDateTime dtOpen;
   TimeToStruct(record.openTime, dtOpen);
   string openTimeStr = StringFormat("%04d-%02d-%02d %02d:%02d:%02d", 
                                    dtOpen.year, dtOpen.mon, dtOpen.day,
                                    dtOpen.hour, dtOpen.min, dtOpen.sec);
   
   // Formater la date/heure de fermeture
   string closeTimeStr = "";
   if(record.closeTime > 0)
   {
      MqlDateTime dtClose;
      TimeToStruct(record.closeTime, dtClose);
      closeTimeStr = StringFormat("%04d-%02d-%02d %02d:%02d:%02d", 
                                  dtClose.year, dtClose.mon, dtClose.day,
                                  dtClose.hour, dtClose.min, dtClose.sec);
   }
   
   // Formater la durée
   string durationFormatted = "";
   if(record.durationSeconds > 0)
   {
      int hours = record.durationSeconds / 3600;
      int minutes = (record.durationSeconds % 3600) / 60;
      int seconds = record.durationSeconds % 60;
      durationFormatted = StringFormat("%02d:%02d:%02d", hours, minutes, seconds);
   }
   
   // Type de position
   string typeStr = (record.type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   
   // Écrire la ligne CSV
   FileWrite(fileHandle,
            openTimeStr,
            closeTimeStr,
            IntegerToString(record.ticket),
            record.symbol,
            typeStr,
            DoubleToString(record.lotSize, 2),
            DoubleToString(record.openPrice, _Digits),
            DoubleToString(record.closePrice, _Digits),
            DoubleToString(record.stopLoss, _Digits),
            DoubleToString(record.takeProfit, _Digits),
            DoubleToString(record.profit, 2),
            DoubleToString(record.swap, 2),
            DoubleToString(record.commission, 2),
            IntegerToString(record.durationSeconds),
            durationFormatted,
            record.closeReason,
            DoubleToString(record.maxProfit, 2),
            DoubleToString(record.maxDrawdown, 2),
            DoubleToString(record.aiConfidence * 100, 2),
            record.aiAction,
            record.comment);
   
   FileClose(fileHandle);
}

//+------------------------------------------------------------------+
//| Synchronise le CSV avec l'historique réel de MT5                 |
//| Vérifie tous les deals fermés et s'assure qu'ils sont dans le CSV|
//+------------------------------------------------------------------+
void SynchronizeCSVWithHistory()
{
   if(!EnableCSVLogging)
      return;
   
   // Initialiser le fichier CSV si nécessaire
   if(g_csvFileName == "")
      InitializeCSVFile();
   
   // Sélectionner l'historique complet (derniers 30 jours pour éviter de surcharger)
   datetime startDate = TimeCurrent() - 30 * 86400; // 30 jours
   datetime endDate = TimeCurrent();
   
   if(!HistorySelect(startDate, endDate))
   {
      if(DebugMode)
         Print("⚠️ SynchronizeCSVWithHistory: Impossible de sélectionner l'historique");
      return;
   }
   
   int totalDeals = HistoryDealsTotal();
   if(DebugMode)
      Print("📊 Synchronisation CSV: ", totalDeals, " deals trouvés dans l'historique");
   
   // Lire le CSV existant pour éviter les doublons
   string existingTickets[];
   int existingCount = 0;
   
   int fileHandle = FileOpen(g_csvFileName, FILE_READ|FILE_CSV|FILE_COMMON, ',');
   if(fileHandle != INVALID_HANDLE)
   {
      // Lire l'en-tête (première ligne) - 22 colonnes
      for(int h = 0; h < 22; h++)
         FileReadString(fileHandle);
      
      // Lire toutes les lignes existantes pour extraire les tickets (position ID)
      while(!FileIsEnding(fileHandle))
      {
         // Lire toutes les colonnes de la ligne
         string col1 = FileReadString(fileHandle); // Date_Heure_Ouverture
         string col2 = FileReadString(fileHandle); // Date_Heure_Fermeture
         string col3 = FileReadString(fileHandle); // Ticket (Position ID)
         
         if(StringLen(col3) > 0)
         {
            ulong ticket = (ulong)StringToInteger(col3);
            if(ticket > 0)
            {
               ArrayResize(existingTickets, existingCount + 1);
               existingTickets[existingCount] = col3;
               existingCount++;
            }
         }
         
         // Lire les colonnes restantes pour passer à la ligne suivante (19 colonnes restantes)
         for(int skip = 0; skip < 19; skip++)
            FileReadString(fileHandle);
      }
      FileClose(fileHandle);
   }
   
   // Parcourir tous les deals de l'historique
   int newTradesAdded = 0;
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      // Vérifier si c'est notre EA
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber)
         continue;
      
      // Vérifier si c'est un deal de fermeture (sortie)
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;
      
      // Obtenir le position ID pour identifier le trade
      ulong positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      
      // Vérifier si ce trade est déjà dans le CSV
      bool alreadyExists = false;
      string positionIdStr = IntegerToString(positionId);
      for(int j = 0; j < existingCount; j++)
      {
         if(existingTickets[j] == positionIdStr)
         {
            alreadyExists = true;
            break;
         }
      }
      
      if(alreadyExists)
         continue; // Déjà dans le CSV
      
      // Trouver tous les deals de cette position
      ulong entryDealTicket = 0;
      double totalProfit = 0.0;
      double totalSwap = 0.0;
      double totalCommission = 0.0;
      datetime openTime = 0;
      datetime closeTime = 0;
      double openPrice = 0.0;
      double closePrice = 0.0;
      double lotSize = 0.0;
      string symbol = "";
      ENUM_POSITION_TYPE posType = WRONG_VALUE;
      
      // Chercher tous les deals de cette position
      for(int j = 0; j < totalDeals; j++)
      {
         ulong checkDeal = HistoryDealGetTicket(j);
         if(checkDeal == 0) continue;
         
         if(HistoryDealGetInteger(checkDeal, DEAL_MAGIC) == InpMagicNumber &&
            HistoryDealGetInteger(checkDeal, DEAL_POSITION_ID) == positionId)
         {
            ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(checkDeal, DEAL_ENTRY);
            
            if(dealEntry == DEAL_ENTRY_IN)
            {
               entryDealTicket = checkDeal;
               openTime = (datetime)HistoryDealGetInteger(checkDeal, DEAL_TIME);
               openPrice = HistoryDealGetDouble(checkDeal, DEAL_PRICE);
               lotSize = HistoryDealGetDouble(checkDeal, DEAL_VOLUME);
               symbol = HistoryDealGetString(checkDeal, DEAL_SYMBOL);
               ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(checkDeal, DEAL_TYPE);
               if(dealType == DEAL_TYPE_BUY)
                  posType = POSITION_TYPE_BUY;
               else if(dealType == DEAL_TYPE_SELL)
                  posType = POSITION_TYPE_SELL;
            }
            else if(dealEntry == DEAL_ENTRY_OUT)
            {
               closeTime = (datetime)HistoryDealGetInteger(checkDeal, DEAL_TIME);
               closePrice = HistoryDealGetDouble(checkDeal, DEAL_PRICE);
               totalProfit += HistoryDealGetDouble(checkDeal, DEAL_PROFIT);
               totalSwap += HistoryDealGetDouble(checkDeal, DEAL_SWAP);
               totalCommission += HistoryDealGetDouble(checkDeal, DEAL_COMMISSION);
            }
         }
      }
      
      if(openTime == 0 || closeTime == 0)
         continue; // Données incomplètes
      
      // Créer l'enregistrement du trade
      TradeRecord record;
      record.ticket = positionId;
      record.symbol = symbol;
      record.type = posType;
      record.openTime = openTime;
      record.closeTime = closeTime;
      record.openPrice = openPrice;
      record.closePrice = closePrice;
      record.lotSize = lotSize;
      record.profit = totalProfit;
      record.swap = totalSwap;
      record.commission = totalCommission;
      record.isClosed = true;
      record.durationSeconds = (int)(closeTime - openTime);
      record.closeReason = "Synchronisé depuis historique MT5";
      
      // Récupérer SL/TP depuis l'historique des ordres
      if(entryDealTicket > 0)
      {
         ulong dealOrder = HistoryDealGetInteger(entryDealTicket, DEAL_ORDER);
         if(HistoryOrderSelect(dealOrder))
         {
            record.stopLoss = HistoryOrderGetDouble(dealOrder, ORDER_SL);
            record.takeProfit = HistoryOrderGetDouble(dealOrder, ORDER_TP);
         }
         else
         {
            record.stopLoss = 0.0;
            record.takeProfit = 0.0;
         }
      }
      else
      {
         record.stopLoss = 0.0;
         record.takeProfit = 0.0;
      }
      
      // Calculer profit max et drawdown (approximation)
      record.maxProfit = MathMax(record.profit, 0.0);
      record.maxDrawdown = 0.0; // Ne peut pas être calculé depuis l'historique
      
      // Récupérer les infos IA depuis le commentaire si disponible
      string dealComment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
      record.comment = dealComment;
      record.aiConfidence = 0.0;
      record.aiAction = "";
      
      // Écrire dans le CSV
      WriteTradeToCSV(record);
      newTradesAdded++;
   }
   
   if(newTradesAdded > 0)
      Print("✅ Synchronisation CSV: ", newTradesAdded, " nouveau(x) trade(s) ajouté(s) depuis l'historique MT5");
   else if(DebugMode)
      Print("✅ Synchronisation CSV: Aucun nouveau trade à ajouter");
}

//+------------------------------------------------------------------+
//| Affine l'entrée avec EMA rapide et moyen sur M5                 |
//| Tous les trades doivent utiliser la décision finale appliquée   |
//| au timeframe M5 et utiliser les EMA rapide/moyen pour affiner   |
//+------------------------------------------------------------------+
bool RefineEntryWithM5EMA(ENUM_ORDER_TYPE orderType)
{
   // 1. Vérifier que la décision finale est disponible et correspond au type d'ordre
   if(!UseAI_Agent || g_lastAIAction == "" || g_lastAIAction == "hold")
   {
      if(DebugMode)
         Print("⏸️ RefineEntryWithM5EMA: Pas de décision finale valide (Action=", g_lastAIAction, ")");
      return false;
   }
   
   // Vérifier que la décision finale correspond au type d'ordre
   bool isBuyOrder = (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP);
   bool isSellOrder = (orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP);
   
   if(isBuyOrder && g_lastAIAction != "buy")
   {
      if(DebugMode)
         Print("⏸️ RefineEntryWithM5EMA: Décision finale (", g_lastAIAction, ") ne correspond pas à BUY");
      return false;
   }
   
   if(isSellOrder && g_lastAIAction != "sell")
   {
      if(DebugMode)
         Print("⏸️ RefineEntryWithM5EMA: Décision finale (", g_lastAIAction, ") ne correspond pas à SELL");
      return false;
   }
   
   // 2. Récupérer les EMA rapide et moyen sur M5
   double emaFastM5[], emaSlowM5[];
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   
   if(CopyBuffer(emaFastM5Handle, 0, 0, 3, emaFastM5) < 3 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 3, emaSlowM5) < 3)
   {
      if(DebugMode)
         Print("⚠️ RefineEntryWithM5EMA: Erreur récupération EMA M5");
      return false;
   }
   
   // 3. Récupérer les données M5 (bougies)
   MqlRates ratesM5[];
   ArraySetAsSeries(ratesM5, true);
   if(CopyRates(_Symbol, PERIOD_M5, 0, 3, ratesM5) < 3)
   {
      if(DebugMode)
         Print("⚠️ RefineEntryWithM5EMA: Erreur récupération données M5");
      return false;
   }
   
   // 4. Récupérer le prix actuel
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atrM5[];
   ArraySetAsSeries(atrM5, true);
   double tolerance = 0.0;
   if(CopyBuffer(atrM5Handle, 0, 0, 1, atrM5) > 0 && atrM5[0] > 0)
   {
      tolerance = atrM5[0] * 0.3; // Tolérance de 0.3x ATR M5
   }
   else
   {
      tolerance = 5 * symbolPoint; // Fallback: 5 symbolPoints
   }
   
   // 5. Vérifier les conditions d'entrée affinées avec EMA M5
   if(orderType == ORDER_TYPE_BUY)
   {
      // Pour BUY sur M5:
      // - EMA rapide M5 doit être au-dessus de l'EMA moyen M5 (tendance haussière)
      // - Le prix doit être proche ou au-dessus de l'EMA rapide M5
      // - La bougie M5 actuelle doit être verte ou en formation haussière
      
      bool emaBullishM5 = (emaFastM5[0] > emaSlowM5[0]);
      bool priceNearOrAboveEMA = (currentPrice >= (emaFastM5[0] - tolerance));
      bool isGreenCandleM5 = (ratesM5[0].close > ratesM5[0].open);
      
      // Vérifier aussi que la tendance M5 est stable (les 2 dernières bougies confirment)
      bool previousBullishM5 = (emaFastM5[1] > emaSlowM5[1]);
      
      if(emaBullishM5 && priceNearOrAboveEMA && (isGreenCandleM5 || previousBullishM5))
      {
         if(DebugMode)
            Print("✅ RefineEntryWithM5EMA BUY: EMA Fast M5=", DoubleToString(emaFastM5[0], _Digits), 
                  " > EMA Slow M5=", DoubleToString(emaSlowM5[0], _Digits), 
                  " | Prix=", DoubleToString(currentPrice, _Digits), " proche EMA Fast | Bougie verte: ", isGreenCandleM5);
         return true;
      }
      else
      {
         if(DebugMode)
            Print("❌ RefineEntryWithM5EMA BUY rejeté: EMA haussière=", emaBullishM5, 
                  " Prix proche EMA=", priceNearOrAboveEMA, " Bougie verte=", isGreenCandleM5,
                  " | EMA Fast=", DoubleToString(emaFastM5[0], _Digits), 
                  " EMA Slow=", DoubleToString(emaSlowM5[0], _Digits), " Prix=", DoubleToString(currentPrice, _Digits));
         return false;
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      // Pour SELL sur M5:
      // - EMA rapide M5 doit être en-dessous de l'EMA moyen M5 (tendance baissière)
      // - Le prix doit être proche ou en-dessous de l'EMA rapide M5
      // - La bougie M5 actuelle doit être rouge ou en formation baissière
      
      bool emaBearishM5 = (emaFastM5[0] < emaSlowM5[0]);
      bool priceNearOrBelowEMA = (currentPrice <= (emaFastM5[0] + tolerance));
      bool isRedCandleM5 = (ratesM5[0].close < ratesM5[0].open);
      
      // Vérifier aussi que la tendance M5 est stable (les 2 dernières bougies confirment)
      bool previousBearishM5 = (emaFastM5[1] < emaSlowM5[1]);
      
      if(emaBearishM5 && priceNearOrBelowEMA && (isRedCandleM5 || previousBearishM5))
      {
         if(DebugMode)
            Print("✅ RefineEntryWithM5EMA SELL: EMA Fast M5=", DoubleToString(emaFastM5[0], _Digits), 
                  " < EMA Slow M5=", DoubleToString(emaSlowM5[0], _Digits), 
                  " | Prix=", DoubleToString(currentPrice, _Digits), " proche EMA Fast | Bougie rouge: ", isRedCandleM5);
         return true;
      }
      else
      {
         if(DebugMode)
            Print("❌ RefineEntryWithM5EMA SELL rejeté: EMA baissière=", emaBearishM5, 
                  " Prix proche EMA=", priceNearOrBelowEMA, " Bougie rouge=", isRedCandleM5,
                  " | EMA Fast=", DoubleToString(emaFastM5[0], _Digits), 
                  " EMA Slow=", DoubleToString(emaSlowM5[0], _Digits), " Prix=", DoubleToString(currentPrice, _Digits));
         return false;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Sauvegarder les prédictions actuelles
   SavePredictions();
   
   // Arrêter le minuteur
   EventKillTimer();
   
   // Nettoyer les objets graphiques
   ClearAllDisplayObjects();
   
   // Afficher un message de confirmation
   Print("✅ Expert Advisor arrêté. Raison: ", GetUninitReasonText(reason));
}

//+------------------------------------------------------------------+
//| Retourne une description lisible de la raison de la désinitialisation |
//+------------------------------------------------------------------+
string GetUninitReasonText(int reasonCode)
{
   string text = "";
   //---
   switch(reasonCode)
   {
      case REASON_ACCOUNT:
         text = "Le compte a été changé";
         break;
      case REASON_CHARTCHANGE:
         text = "Paramètres ou symbole/période du graphique modifiés";
         break;
      case REASON_CHARTCLOSE:
         text = "Le graphique a été fermé";
         break;
      case REASON_PARAMETERS:
         text = "Les paramètres d'entrée ont été modifiés";
         break;
      case REASON_RECOMPILE:
         text = "Le programme a été recompilé";
         break;
      case REASON_REMOVE:
         text = "Le programme a été supprimé du graphique";
         break;
      case REASON_TEMPLATE:
         text = "Un nouveau modèle a été appliqué ou la conversion en modèle a échoué";
         break;
      case REASON_CLOSE:
         text = "La plateforme a été fermée";
         break;
      default:
         text = "Raison inconnue: " + IntegerToString(reasonCode);
   }
   //---
   return text;
}

//+------------------------------------------------------------------+
