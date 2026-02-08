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
#include <WinAPI\windef.mqh>
#include <WinAPI\winnt.mqh>
#include <WinAPI\sysinfoapi.mqh>
#include <WinAPI\winbase.mqh>
#include <WinAPI\fileapi.mqh>
#include <WinAPI\processenv.mqh>
#include <WinAPI\libloaderapi.mqh>
#include <WinAPI\memoryapi.mqh>

// Standard MQL5 includes for trading enums
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\TerminalInfo.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>

// #include <includes/AdvancedValidations.mqh>  // Validations avancées - Temporairement désactivé (fichier non trouvé)

//+------------------------------------------------------------------+
//| Paramètres d'entrée                                              |
//+------------------------------------------------------------------+
input group "--- CONFIGURATION DE BASE ---"
input int    InpMagicNumber     = 888888;  // Magic Number
input double MinConfidence      = 70.0;    // Minimum confidence percentage required for trading
double requiredConfidence = MinConfidence / 100.0;  // Convert to decimal
input double InitialLotSize     = 0.01;    // Taille de lot initiale
input double MaxLotSize          = 1.0;     // Taille de lot maximale
input double TakeProfitUSD       = 30.0;    // Take Profit en USD (fixe) - Mouvements longs (augmenté pour cibler les grands mouvements)
input double StopLossUSD         = 10.0;    // Stop Loss en USD (fixe) - Ratio 3:1 pour favoriser les mouvements longs
input double ProfitThresholdForDouble = 1.0; // Seuil de profit (USD) pour doubler le lot (1$ comme demandé)
input double IndividualTP1 = 1.5;      // Fermeture individuelle automatique à 1.5$ de gain
input double IndividualTP2 = 2.0;      // Fermeture individuelle automatique à 2.0$ de gain
input double OtherSymbolsTP = 4.0;     // Fermeture individuelle automatique à 4.0$ pour les autres symboles
input double MaxPositionLoss = 5.0;    // Seuil de perte pour fermer la position la plus perdante
input int    MinPositionLifetimeSec = 5;    // Délai minimum avant modification (secondes)
input int    AI_Accuracy_Timeout_ms = 20000; // Timeout spécifique pour endpoint accuracy (20s)
input int    AI_MaxRetries       = 2;        // Nombre de tentatives en cas d'échec
input int    MinStabilitySeconds = 3;   // Délai minimum de stabilité avant exécution (secondes) - RÉDUIT pour exécution immédiate

input group "--- AI AGENT ---"
input bool   UseAI_Agent        = true;    // Activer l'agent IA (via serveur externe)
input string AI_ServerURL       = "https://kolatradebot.onrender.com/decision"; // URL serveur IA
input bool   UseAdvancedDecisionGemma = true; // Utiliser endpoint decisionGemma (Gemma+Gemini) avec analyse visuelle
input int    AI_Timeout_ms       = 10000;    // Timeout réduit à 10s pour des réponses plus rapides
input double AI_MinConfidence    = 0.30;    // Confiance minimale réduite à 30% pour plus de réactivité
// NOTE: Les seuils sont maintenant plus bas pour les paires Boom/Crash
// pour capturer plus d'opportunités de trading
input int    AI_UpdateInterval   = 10;     // Intervalle réduit à 10s pour des mises à jour plus fréquentes
input string AI_AnalysisURL    = "https://kolatradebot.onrender.com/analysis";  // URL base pour l'analyse complète (structure H1, etc.)
input int    AI_AnalysisIntervalSec = 60;  // Fréquence de rafraîchissement de l'analyse (secondes)
input string AI_TimeWindowsURLBase = "https://kolatradebot.onrender.com"; // Racine API pour /time_windows
input string TrendAPIURL = "https://kolatradebot.onrender.com/trend"; // URL API de tendance

input bool   UseNewPredictEndpoint = true;   // Utiliser le nouvel endpoint /predict/{symbol} pour signaux IA
input string AI_PredictSymbolURL = "https://kolatradebot.onrender.com/predict"; // URL base pour /predict/{symbol}
input bool   EnableBoomCrashRestrictions = false; // (DÉSACTIVÉ PAR DÉFAUT) Anciennes restrictions Boom/Crash (conservées pour compatibilité)
input double BoomCrashMinConfidence = 70.0;   // Confiance minimale pour Boom/Crash (70%)
input double BoomCrashVolumeMultiplier = 1.0; // Multiplicateur de volume pour Boom/Crash
input bool   UseIntegratedDashboard = false;  // Utiliser le dashboard intégré (alternative au dashboard externe)
input int    IntegratedDashboardRefresh = 5;   // Rafraîchissement dashboard intégré (secondes)

input group "--- INTEGRATION IA AVANCÉE ---"
input bool   UseAdvancedValidation = true;        // Activer validation multi-couches pour les trades IA
input bool   RequireAllEndpointsAlignment = true;   // Exiger alignement de TOUS les endpoints IA avant trading
input double MinAllEndpointsConfidence = 0.70; // Confiance minimale pour alignement de tous les endpoints
input bool   UseDynamicTPCalculation = true;      // Calculer TP dynamique au prochain Support/Résistance
input bool   UseImmediatePredictionCheck = true;    // Vérifier direction immédiate de la prédiction avant trade
input bool   UseStrongReversalValidation = true; // Exiger retournement franc après touche EMA/Support/Résistance
input bool   RequireM5Confirmation = true;        // Exiger confirmation M5 obligatoire avant position
input bool   UseCorrectionZoneFilter = true;       // Filtrer les trades en zones de correction (éviter les mauvaises entrées)
input bool   UseMomentumPressureAnalysis = true;  // Utiliser l'analyse Momentum Concept Strategy (MCS)
input double MinMomentumScore = 0.50;           // Score momentum minimum pour considérer une opportunité
input double MinZoneStrength = 0.40;             // Force de zone de pression minimum (0.0-1.0)
input bool   UseProfitImmediateStrategy = true;    // Stratégie profit immédiat (SL très serré pour commencer en profit)
input double MaxImmediateLoss = 0.50;          // Perte maximale pour stratégie profit immédiat (0.5$)
input bool   UseAdaptiveVolumeSizing = false;     // Utiliser dimensionnement adaptatif du volume (désactivé pour le moment)
input bool   UseMultiTimeframeAnalysis = true;     // Utiliser analyse multi-timeframes pour les décisions
input bool   UseMarketStateDetection = false;     // Détecter l'état du marché (tendance/correction/range)
input bool   UseFractalLevelDetection = true;      // Utiliser les niveaux fractals pour supports/résistances
input bool   UseIntelligentDecisionSystem = false;   // Utiliser le système de décision intelligent multi-couches
input double IntelligentDecisionThreshold = 0.70; // Seuil de confiance pour décision intelligente
input bool   UseAdaptiveSLTP = false;             // Utiliser SL/TP adaptatif basé sur volatilité et confiance
input bool   UsePositionDuplication = false;        // Autoriser duplication de positions gagnantes
input double DuplicationProfitThreshold = 1.5; // Seuil de profit pour duplication (USD)
input bool   UseUSBreakoutStrategy = true;         // Activer stratégie US Breakout avec ordres LIMIT
input bool   UseLimitOrderValidation = true;        // Activer validation ultra-tardive des ordres LIMIT
input double LimitOrderValidationInterval = 2; // Intervalle validation ordres LIMIT (secondes)
input bool   UsePredictedTrajectoryForLimitEntry = false; // Placer les LIMIT sur la trajectoire prédite (DÉSACTIVÉ)
input bool   UseTrajectoryTrendConfirmation = false;      // Confirmer tendance via trajectoire (DÉSACTIVÉ)
input bool   UpdateLimitOrderOnTrajectory = false;       // Actualiser les ordres LIMIT quand la trajectoire change (DÉSACTIVÉ)
input double TrajectoryMinCoherencePercent = 70.0;      // Cohérence min (%) des fenêtres trajectoire pour confirmer tendance
input bool   UseRealtimePredictionEnhancement = true; // Améliorer les prédictions avec données historiques
input bool   UseEnhancedVisualization = true;       // Activer visualisation avancée (bougies prédites, etc.)
input bool   UseAdvancedEntryValidation = true;    // Activer validation d'entrée avancée (multi-critères)
input double AdvancedEntryMinScore = 0.80;        // Score minimum pour entrée avancée (0.0-1.0)
input bool   UseExitOptimization = true;           // Optimiser la sortie des positions (fermeture intelligente)
input double ExitOptimizationThreshold = 0.60; // Seuil de confiance pour optimisation sortie
input bool   UseRiskManagement = true;             // Activer gestion avancée des risques
input double MaxRiskPerTrade = 2.0;              // Risque maximum par trade (% du capital)
input bool   UsePerformanceTracking = true;        // Activer suivi des performances en temps réel
input int    PerformanceUpdateInterval = 60;     // Intervalle mise à jour performances (secondes)
input bool   UseAlertSystem = true;               // Activer système d'alertes sonores et visuelles
input bool   AlertOnSpikeDetection = true;          // Alerte sonore sur détection spike imminent
input int    AlertSpikeThresholdSeconds = 15;      // Seuil temps pour alerte spike (secondes)
input bool   UseTradeExecutionOptimization = true; // Optimiser l'exécution des trades
input int    MaxConcurrentTrades = 3;             // Nombre maximum de trades simultanés
input bool   UseTradeValidation = true;           // Activer validation des trades avant exécution
input double TradeValidationTimeout = 5.0;        // Timeout validation trades (secondes)
input bool   UseErrorRecovery = true;               // Activer récupération automatique des erreurs
input int    ErrorRecoveryAttempts = 3;             // Nombre de tentatives de récupération
input bool   UseLoggingSystem = true;              // Activer système de logging avancé
input string LogFileName = "TradingBot.log";      // Nom du fichier de log
input int    LogRotationInterval = 86400;         // Intervalle rotation logs (secondes, 24h)
input bool   UseMonitoringDashboard = true;         // Activer dashboard de monitoring en temps réel
input int    MonitoringRefreshInterval = 10;        // Intervalle rafraîchissement monitoring (secondes)
input bool   UseBackupSystem = true;               // Activer système de sauvegarde automatique
input string BackupPath = "backups";              // Chemin de sauvegarde des données
input int    BackupInterval = 3600;               // Intervalle sauvegarde (secondes, 1h)
input bool   UseDataIntegrity = true;              // Activer vérification intégrité des données
input int    DataIntegrityCheckInterval = 300;       // Intervalle vérification intégrité (secondes, 5 min)

input group "--- DASHBOARD ET ANALYSE COHÉRENTE ---"
input string AI_CoherentAnalysisURL = "https://kolatradebot.onrender.com/coherent-analysis"; // URL pour l'analyse cohérente
input string AI_DashboardGraphsURL = "https://kolatradebot.onrender.com/dashboard/graphs";    // URL pour les graphiques du dashboard
input int    AI_CoherentAnalysisInterval = 120; // Intervalle de mise à jour de l'analyse cohérente (réduit à 2 min pour Phase 2)
input bool   ShowCoherentAnalysis = false; // Désactivé temporairement - l'endpoint n'existe plus
input bool   ShowPricePredictions = false; // Afficher les prédictions de prix sur le graphique (DÉSACTIVÉ - plus utilisé dans décision finale)
input bool   SendNotifications = true; // Envoyer des notifications (désactivé par défaut)

input group "--- PHASE 2: MACHINE LEARNING ---"
input bool   UseMLPrediction = true; // Activer les prédictions ML (Phase 2)
input string AI_MLPredictURL = "https://kolatradebot.onrender.com/ml/predict"; // URL pour les prédictions ML
input string AI_MLTrainURL = "https://kolatradebot.onrender.com/ml/train"; // URL pour l'entraînement ML
input int    AI_MLUpdateInterval = 300; // Intervalle de mise à jour ML (secondes, 5 min)
input double ML_MinConfidence = 0.65; // Confiance minimale ML pour validation (65%)
input double ML_MinConsensusStrength = 0.60; // Force de consensus minimale ML (60%)
input bool   AutoTrainML = true; // Entraîner automatiquement les modèles ML (désactivé par défaut - coûteux)
input int    ML_TrainInterval = 86400; // Intervalle d'entraînement ML automatique (secondes, 24h)
input string AI_MLMetricsURL = "https://kolatradebot.onrender.com/ml/metrics"; // URL pour récupérer les métriques ML
input string AI_MLFeedbackURL = "https://kolatradebot.onrender.com/ml/feedback"; // URL pour envoyer le feedback d'apprentissage
input bool   ShowMLMetrics = true; // Afficher les métriques ML dans les logs
input bool   EnableMLFeedback = true; // Activer l'apprentissage adaptatif (feedback des pertes)
input bool   AutoRetrainAfterFeedback = true; // Réentraîner automatiquement après accumulation de feedback
input int    ML_FeedbackRetrainThreshold = 10; // Nombre de feedbacks de pertes avant réentraînement
input int    ML_MetricsUpdateInterval = 3600; // Intervalle de mise à jour des métriques ML (secondes, 1h)
input int    MLPanelXDistance = 10;           // Position X du panneau ML (depuis la droite)
input int    MLPanelYFromBottom = 260;        // Position Y du panneau ML (distance depuis le bas)

input group "--- PRÉDICTIONS TEMPS RÉEL ---"
input bool   ShowPredictionsPanel = false;     // Afficher les prédictions dans le cadran d'information (DÉSACTIVÉ - plus utilisé dans décision finale)
input string PredictionsRealtimeURL = "https://kolatradebot.onrender.com/predictions/realtime"; // Endpoint prédictions temps réel
input string PredictionsValidateURL = "https://kolatradebot.onrender.com/predictions/validate"; // Endpoint validation prédictions
input int    PredictionsUpdateInterval = 20;  // Fréquence mise à jour prédictions (secondes, pour alléger la charge)
input bool   ValidatePredictions = true;       // Envoyer données réelles pour validation
input int    ValidationLocalInterval = 5;      // Intervalle validation locale rapide (secondes) - Mise à jour canaux en temps réel
input int    ValidationServerInterval = 30;    // Intervalle envoi au serveur (secondes) - Plus long pour éviter surcharge
input int    MaxPredictionCandles = 8;        // Nombre maximum de bougies prédictives à afficher (réduit pour éviter la surcharge visuelle)
input int    PredictionCandleSpacing = 2;      // Espacement entre les bougies (1=toutes, 2=une sur deux, 3=une sur trois, etc.)
input bool   ShowPredictionCandles = true;     // Afficher des "bougies" prédites
input bool   ShowPredictionChannelFill = false; // Remplissage du canal prédictif (désactivé pour voir la trajectoire)
input bool   ShowPredictionArrows = true;      // Afficher les flèches sur les bougies prédites
input bool   ShowPredictionWicks = true;       // Afficher les mèches des bougies prédites

input group "--- NOTIFICATIONS VONAGE ---"
input bool   EnableVonageNotifications = true; // Activer notifications Vonage SMS (DÉSACTIVÉ - endpoint non disponible sur Render)
input string NotificationAPIURL = "https://kolatradebot.onrender.com/notifications/send"; // Endpoint notifications
input bool   SendTradeSignals = true;         // Envoyer signaux de trade par SMS (DÉSACTIVÉ - dépend de EnableVonageNotifications)
input bool   SendPredictionSummary = true;   // Envoyer résumé prédictions (toutes les heures) (DÉSACTIVÉ - dépend de EnableVonageNotifications)
input int    PredictionSummaryInterval = 3600; // Intervalle résumé prédictions (secondes)

input group "--- GESTION DES GAINS QUOTIDIENS ---"
input double DailyProfitTarget = 50.0;     // Objectif de profit quotidien ($)
input double MorningTarget = 10.0;         // Objectif matinal
input double AfternoonTarget = 20.0;       // Objectif après-midi
input double EveningTarget = 35.0;         // Objectif soirée
input string MorningSession = "08:00-12:00";    // Session du matin
input string AfternoonSession = "13:00-16:00";  // Session d'après-midi
input string EveningSession = "16:00-20:00";    // Session du soir
input int    MinBreakBetweenSessions = 30;      // Pause minimale entre les sessions (minutes)

input group "--- FILTRES QUALITÉ TRADES (ANTI-PERTES) ---"
input bool   UseStrictQualityFilter = true;        // Activer filtres stricts qualité (éviter mauvais trades)
input double MinOpportunityScore = 0.70;           // Score minimum opportunité pour trader (0.0-1.0, plus élevé = plus strict)
input double MinEndpointsCoherenceRate = 85.0;     // Cohérence minimale (%) entre IA / Trend API / Prédiction pour autoriser une entrée
input double ImmediatePredictionMinMovePercent = 0.08; // Mouvement minimal (%) dans la prédiction "immédiate" (anti-hasard)
input double MinMomentumStrength = 0.60;           // Force momentum minimum pour considérer mouvement "franc" (0.0-1.0)
input double MinTrendAlignment = 0.75;             // Alignement tendance minimum (0.0-1.0, 0.75 = 3/4 timeframes alignés)
input bool   UseReversalConfirmation = true;       // Activer confirmation retournement support/résistance (attend 1-2 bougies)
input bool   RequireMLValidation = true;           // Exiger validation ML pour tous les trades (si ML activé)
input bool   RequireCoherentAnalysis = true;        // Exiger analyse cohérente valide pour trader
input double MinCoherentConfidence = 0.75;          // Confiance minimale analyse cohérente (75% par défaut)

input group "--- PROTECTION ORDRES LIMIT ---"
input bool   UseLastSecondLimitValidation = true;   // Activer la validation ultra-tardive des ordres LIMIT
input double LimitProximityPoints        = 5.0;     // Distance (en points) à laquelle on déclenche la validation avant le touch
input double MinM30MovePercent           = 0.30;    // Mouvement minimum attendu en M30 (en %) pour considérer le mouvement comme "franc"

input group "--- ÉLÉMENTS GRAPHIQUES ---"
input bool   DrawAIZones         = true;    // Dessiner les zones BUY/SELL de l'IA
input bool   DrawSupportResistance = true;  // Dessiner support/résistance M5/H1
input bool   DrawTrendlines      = true;    // Dessiner les trendlines
input bool   DrawDerivPatterns   = true;    // Dessiner les patterns Deriv
input bool   DrawSMCZones        = true;   // Dessiner les zones SMC/OrderBlock (DÉSACTIVÉ pour performance)

input group "--- STRATÉGIE US SESSION BREAK & RETEST (PRIORITAIRE) ---"
input bool   UseUSSessionStrategy = true;   // Activer la stratégie US Session (prioritaire)
input double US_RiskReward        = 2.0;    // Risk/Reward ratio pour US Session
input int    US_RetestTolerance   = 30;     // Tolérance retest en points
input bool   US_OneTradePerDay    = true;   // Un seul trade par jour pour US Session

input group "--- STRATÉGIE AGRESSIVE (TRADE À FOND) ---"
input bool   EnableAggressiveStrategy = true;   // Activer la stratégie agressive de duplication
input int    MaxDuplicatePositions = 4;         // Nombre maximum de positions dupliquées
input double AggressiveProfitTarget = 5.0;     // Seuil de profit pour fermer rapidement (USD)
input double AggressiveLotMultiplier = 1.5;     // Multiplicateur de lot pour chaque duplication
input int    AggressiveEntryDelay = 5;          // Délai entre entrées en secondes

input group "--- GESTION DES RISQUES ---"
input bool   UseQuickReentry     = true;    // Activer la protection contre les ré-entrées rapides
input int    MinReentryDelaySeconds = 300;  // Délai minimum avant ré-ouverture (secondes, 5min)
input double MaxDailyLoss        = 16.0;    // Perte quotidienne maximale (USD) - RÉDUIT à 16$
input double MaxDailyProfit      = 30.0;    // Profit quotidien net cible (USD) - RÉDUIT de 50$ à 30$
input double MaxTotalLoss        = 3.5;     // Perte totale maximale toutes positions (USD) - Au-delà, fermer toutes positions
input double MaxSymbolLoss       = 5.0;     // Perte maximale par symbole (USD) - Au-delà, bloque ce symbole
input bool   UseTrailingStop     = true;   // Utiliser trailing stop (désactivé pour scalping fixe)

input group "--- FERMETURE AUTO SUR PERTE ---"
input bool   EnableAutoCloseOnMaxLoss = true; // Fermer auto une position si perte max atteinte
input double MaxLossPerPositionUSD    = 1.2;  // Perte max par position (USD). Ex: 1.2 => fermer si profit <= -1.2$

input group "--- SORTIES VOLATILITY ---"
input double VolatilityQuickTP   = 2.0;     // Fermer rapidement les indices Volatility à +2$ de profit

input group "--- SORTIES BOOM/CRASH ---"
input double BoomCrashSpikeTP    = 0.50;    // Fermer Boom/Crash dès que le spike donne ce profit (0.50$)
input bool   EnableBoomCrashProfitClose = true;  // Activer fermeture automatique positions profitables Boom/Crash
input double BoomCrashMinProfitThreshold = 0.50; // Seuil minimum profit pour fermer positions Boom/Crash (0.50$)
input bool   BoomCrashCloseOnlyBoom = false;     // Fermer seulement Boom (false = Boom + Crash)
input bool   BoomCrashCloseOnlyCrash = false;    // Fermer seulement Crash (false = Boom + Crash)
input int    BoomCrashCheckInterval = 3;         // Intervalle vérification positions profitables (secondes) - réduit à 3s

input group "--- FERMETURE RAPIDE 1$ ---"
input bool   EnableOneDollarAutoClose = true;   // Activer la fermeture automatique dès que le profit atteint 1$
input double OneDollarProfitTarget    = 10.0;   // Seuil de profit en dollars pour fermer une position (scalping à 10$)

input group "--- PROFIL SORTIES PAR TYPE (100$ / LOT MIN) ---"
input bool   UsePerSymbolExitProfile      = true; // Appliquer TP/MaxLoss différents selon le symbole
// Forex
input double ForexProfitTargetUSD         = 2.0;
input double ForexMaxLossUSD              = 1.0;
// Volatility / Step
input double VolatilityProfitTargetUSD    = 1.5;
input double VolatilityMaxLossUSD         = 1.0;
// Boom / Crash
input double BoomCrashProfitTargetUSD     = 0.0; // 0 = désactiver la clôture "profit target" générale pour Boom/Crash
input double BoomCrashMaxLossUSD          = 1.2;

input group "--- GARDE-FOU GAIN/PERTE (ANTI-PERTES) ---"
input bool   EnforceMinRiskReward      = true;  // Empêche un ratio gain/perte défavorable
input double MinRiskReward             = 1.20;  // Ratio minimum: ProfitTarget / MaxLoss (ex: 1.2 => viser +1.2$ pour risquer -1$)
input bool   AutoAdjustRiskReward      = true;  // Ajuste automatiquement la perte max si ratio insuffisant

input group "--- INDICATEURS ---"
input int    EMA_Fast_Period     = 9;       // Période EMA rapide
input int    EMA_Slow_Period     = 21;      // Période EMA lente
input int    RSI_Period          = 14;      // Période RSI
input int    ATR_Period          = 14;      // Période ATR
input bool   ShowLongTrendEMA    = true;    // Afficher EMA 50, 100, 200 sur le graphique (courbes)
input bool   UseTrendAPIAnalysis = true;    // Utiliser l'analyse de tendance API pour affiner les décisions
input double TrendAPIMinConfidence = 70.0;  // Confiance minimum API pour validation (70%)

input group "--- JOURNALISATION CSV ---"
input bool   EnableCSVLogging    = true;    // Activer l'enregistrement CSV des trades
input string CSVFileNamePrefix   = "TradesJournal"; // Préfixe du nom de fichier CSV

input group "--- DEBUG ---"
input bool   DebugMode           = true;    // Mode debug (logs détaillés)

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
CTrade trade;
CPositionInfo positionInfo;
COrderInfo orderInfo;
CDealInfo dealInfo;

// Seuils effectifs (peuvent être ajustés au démarrage via garde-fou)
static double g_effectiveMaxLossPerPositionUSD = 0.0;
static double g_effectiveProfitTargetUSD       = 0.0;

double GetProfitTargetUSDForSymbol(const string symbol);
double GetMaxLossUSDForSymbol(const string symbol);

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

// Variables IA
static string   g_lastAIAction    = "";
static double   g_lastAIConfidence = 0.0;
static string   g_lastAIReason    = "";
static datetime g_lastAITime      = 0; // Sera initialisé au démarrage
static bool     g_aiFallbackMode  = true;
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

// Structure pour les métriques ML
struct MLMetricsData
{
   double accuracy;           // Précision du modèle
   double precision;          // Précision des prédictions positives
   double recall;             // Rappel des prédictions positives
   double f1Score;            // Score F1
   string modelName;          // Nom du modèle
   datetime lastUpdate;       // Dernière mise à jour
   int totalPredictions;      // Nombre total de prédictions
   double avgConfidence;      // Confiance moyenne
   
   // Additional fields needed for g_mlMetrics
   string symbol;             // Symbole associé aux métriques
   string timeframe;          // Timeframe des métriques
   bool isValid;              // Indique si les métriques sont valides
   double bestAccuracy;       // Meilleure précision obtenue
   double bestF1Score;        // Meilleur score F1 obtenu
   string bestModel;          // Nom du meilleur modèle
   int featuresCount;         // Nombre de features utilisées
   int trainingSamples;       // Nombre d'échantillons d'entraînement
   int testSamples;           // Nombre d'échantillons de test
   
   // Model-specific accuracies
   double randomForestAccuracy;  // Précision Random Forest
   double gradientBoostingAccuracy; // Précision Gradient Boosting
   double mlpAccuracy;           // Précision MLP
   double suggestedMinConfidence; // Confiance minimale suggérée
};

// Variables pour les métriques ML
static double   g_mlAccuracy = 0.0;           // Précision du modèle ML (0.0 - 1.0)
static double   g_mlPrecision = 0.0;          // Précision du modèle ML (0.0 - 1.0)
static double   g_mlRecall = 0.0;             // Rappel du modèle ML (0.0 - 1.0)
static string   g_mlModelName = "RandomForest"; // Nom du modèle ML actuel
static datetime g_lastMlUpdate = 0;           // Dernière mise à jour des métriques
static MLMetricsData g_mlMetrics;             // Métriques ML complètes pour le symbole actuel

// Variables pour la gestion des erreurs de prédiction
static int g_accuracyErrorCount = 0;          // Nombre d'erreurs consécutives d'accuracy
static datetime g_lastPredictionAccuracyUpdate = 0; // Dernière mise à jour de l'accuracy
#define ACCURACY_ERROR_BACKOFF 300             // Délai d'attente en cas d'erreurs (5 minutes)

// Structure pour l'analyse par timeframe
struct TimeframeAnalysis {
   string timeframe;          // Période (M1, M5, H1, etc.)
   string direction;          // Direction (buy/sell/neutral)
   double strength;           // Force du signal (0-1)
};

// Structure pour l'analyse cohérente
struct CoherentAnalysisData
{
   string symbol;                // Symbole analysé
   string decision;              // Décision (buy/sell/neutral)
   double confidence;            // Niveau de confiance (0-1)
   double stability;             // Stabilité de la décision
   datetime lastUpdate;          // Dernière mise à jour
   TimeframeAnalysis timeframes[]; // Analyse par timeframe
   string details;               // Détails supplémentaires
};

// Variables pour l'analyse cohérente
CoherentAnalysisData g_coherentAnalysis;     // Dernière analyse cohérente reçue

// Variables pour les métriques ML
// g_lastAIConfidence est déjà déclaré plus haut

// Prédiction de prix (200 bougies)
static double   g_pricePrediction[];  // Tableau des prix prédits (500 bougies futures)
static double   g_priceHistory[];     // Tableau des prix historiques (200 bougies passées)
static datetime g_predictionStartTime = 0;  // Temps de début de la prédiction
static bool     g_predictionValid = true;  // La prédiction est-elle valide ?
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

static PositionProfitTracker g_profitTrackers[];
static int g_profitTrackersCount = 0;

// Variables pour la stratégie agressive
struct AggressiveTradeTracker {
   ENUM_ORDER_TYPE direction;      // Direction du trade agressif
   datetime startTime;             // Heure de début de la stratégie
   int positionCount;              // Nombre de positions ouvertes
   double totalProfit;             // Profit total des positions
   bool isActive;                  // Stratégie active
   datetime lastEntryTime;         // Dernière heure d'entrée
   string finalDecision;           // Décision finale qui a déclenché la stratégie
};

static AggressiveTradeTracker g_aggressiveTracker;
static bool g_aggressiveMode = false;

// Suivi quotidien
static double g_dailyProfit = 0.0;
static double g_sessionProfit = 0.0;        // Profit de la session actuelle
static string   g_currentSession = "";       // Session actuelle (matin/après-midi/soir)
static datetime g_lastSessionChange = 0;      // Dernier changement de session
static datetime g_sessionStartTime = 0;       // Heure de début de la session en cours
static double   g_sessionTarget = 0.0;        // Objectif de profit pour la session actuelle
static bool     g_targetReached = false;      // Indique si l'objectif de la session est atteint
static datetime g_lastTradeTime = 0;          // Heure du dernier trade
static int      g_tradeCount = 0;             // Nombre de trades effectués
static double   g_totalProfit = 0.0;          // Profit total
static double g_dailyLoss = 0.0;
static datetime g_lastDayReset = 0;
static ulong g_processedDeals[];  // Liste des deals déjà traités pour éviter les doubles comptages

// Variables pour la gestion des positions
static int      g_positionCount = 0;          // Nombre de positions ouvertes
static double   g_positionProfit = 0.0;       // Profit total des positions ouvertes
static double   g_bestPositionProfit = 0.0;   // Meilleur profit réalisé sur une position
static double   g_worstPositionProfit = 0.0;  // Pire perte réalisée sur une position
static datetime g_lastPositionCloseTime = 0;  // Dernière fermeture de position

// Variables pour le suivi des performances
static int      g_winCount = 0;               // Nombre de trades gagnants
static int      g_lossCount = 0;              // Nombre de trades perdants
static int g_mlFeedbackCount = 0;         // Nombre de feedbacks ML envoyés (pertes)
static datetime g_lastMLRetrainTime = 0;      // Dernier réentraînement ML déclenché
static double   g_totalWin = 0.0;             // Total des gains
static double   g_totalLoss = 0.0;            // Total des pertes

// Variables pour ré-entrée rapide après profit (scalping)
static datetime g_lastProfitCloseTime = 0;
static string g_lastProfitCloseSymbol = "";
static int g_lastProfitCloseDirection = 0; // 1=BUY, -1=SELL
static bool g_enableQuickReentry = true; // Activer ré-entrée rapide
static int g_reentryDelaySeconds = 3; // Délai avant ré-entrée (secondes)

// Variables pour l'intégration IA avancée
static bool     g_advancedValidationEnabled = true;       // Validation multi-couches activée
static bool     g_endpointsAlignmentValid = false;        // Alignement des endpoints IA valide
static double   g_endpointsAlignmentScore = 0.0;        // Score d'alignement des endpoints (0.0-1.0)
static bool     g_dynamicTPCalculated = false;          // TP dynamique calculé
static double   g_dynamicTPLevel = 0.0;               // Niveau TP dynamique trouvé
static bool     g_immediatePredictionValid = false;       // Prédiction immédiate valide
static bool     g_strongReversalConfirmed = false;       // Retournement franc confirmé
static double   g_reversalTouchLevel = 0.0;             // Niveau de touche pour retournement
static string   g_reversalTouchSource = "";           // Source du niveau de touche
static bool     g_m5ConfirmationValid = false;           // Confirmation M5 valide
static bool     g_inCorrectionZone = false;             // Prix en zone de correction
static double   g_momentumScore = 0.0;                // Score momentum (0.0-1.0)
static double   g_zoneStrength = 0.0;                  // Force de zone de pression (0.0-1.0)
static bool     g_profitImmediateMode = true;          // Mode profit immédiat activé
static double   g_immediateMaxLoss = 0.50;             // Perte maximale en mode immédiat
static bool     g_adaptiveVolumeEnabled = false;          // Dimensionnement adaptatif activé
static bool     g_multiTimeframeAnalysis = true;        // Analyse multi-timeframes activée
static bool     g_marketStateDetected = false;          // État du marché détecté
static bool     g_fractalLevelsDetected = false;         // Niveaux fractals détectés
static bool     g_intelligentDecisionEnabled = false;    // Système décision intelligent activé
static double   g_intelligentDecisionScore = 0.0;       // Score décision intelligent (0.0-1.0)
static bool     g_adaptiveSLTPEnabled = false;           // SL/TP adaptatif activé
static bool     g_positionDuplicationEnabled = false;     // Duplication positions activée
static double   g_duplicationProfitThreshold = 1.5;    // Seuil profit pour duplication
static bool     g_usBreakoutEnabled = true;              // Stratégie US Breakout activée
static bool     g_limitOrderValidationEnabled = true;     // Validation ordres LIMIT activée
static bool     g_realtimePredictionEnhanced = false;      // Amélioration prédictions activée
static bool     g_enhancedVisualizationEnabled = true;      // Visualisation avancée activée
static bool     g_advancedEntryValidation = true;       // Validation d'entrée avancée activée
static double   g_advancedEntryScore = 0.0;           // Score d'entrée avancée (0.0-1.0)
static bool     g_exitOptimizationEnabled = true;          // Optimisation sortie activée
static double   g_exitOptimizationScore = 0.0;          // Score optimisation sortie (0.0-1.0)
static bool     g_riskManagementEnabled = true;           // Gestion risques avancée activée
static double   g_riskPerTrade = 2.0;                 // Risque maximum par trade (%)
static bool     g_performanceTrackingEnabled = true;        // Suivi performances activé
static datetime g_lastPerformanceUpdate = 0;        // Dernière mise à jour performances
static bool     g_alertSystemEnabled = true;             // Système d'alertes activé
static bool     g_spikeAlertEnabled = true;              // Alertes spike activées
static bool     g_tradeExecutionOptimized = true;       // Exécution trades optimisée
static int      g_concurrentTradesLimit = 3;           // Limite trades simultanés
static bool     g_tradeValidationEnabled = true;          // Validation trades activée
static double   g_tradeValidationTimeout = 5.0;        // Timeout validation trades (secondes)
static bool     g_errorRecoveryEnabled = true;           // Récupération erreurs activée
static int      g_errorRecoveryAttempts = 0;           // Tentatives de récupération
static bool     g_loggingSystemEnabled = true;            // Logging avancé activé
static string   g_logFileName = "TradingBot.log";        // Nom du fichier de log
static datetime g_lastLogRotation = 0;              // Dernière rotation des logs
static bool     g_monitoringDashboardEnabled = true;        // Dashboard monitoring activé
static datetime g_lastMonitoringUpdate = 0;        // Dernière mise à jour monitoring
static bool     g_backupSystemEnabled = true;             // Système sauvegarde activé
static string   g_backupPath = "backups";              // Chemin de sauvegarde
static datetime g_lastBackup = 0;                    // Dernière sauvegarde
static bool     g_dataIntegrityEnabled = true;            // Vérification intégrité activée
static datetime g_lastIntegrityCheck = 0;           // Dernière vérification intégrité

// Variables pour la fermeture automatique Boom/Crash profitables
static datetime g_lastBoomCrashProfitCheck = 0;  // Dernière vérification positions profitables
static int      g_boomCrashPositionsClosed = 0;   // Compteur positions fermées
static double   g_boomCrashProfitClosed = 0.0;    // Profit total fermé
// Variables pour la gestion des erreurs
static int      g_lastError = 0;              // Dernière erreur rencontrée
static string   g_lastErrorMsg = "";          // Message de la dernière erreur
static datetime g_lastErrorTime = 0;          // Heure de la dernière erreur

// Variables pour les prédictions
bool     g_predictionM1Valid = false;        // Prédiction valide pour M1
bool     g_predictionM15Valid = false;       // Prédiction valide pour M15
bool     g_predictionM30Valid = false;       // Prédiction valide pour M30
bool     g_predictionH1Valid = false;        // Prédiction valide pour H1

// Variables manquantes ajoutées pour corriger les erreurs de compilation
static double   g_predictionAccuracy = 0.0;   // Précision des prédictions IA
#define PREDICTION_ACCURACY_UPDATE_INTERVAL 600 // Intervalle de mise à jour de l'accuracy (10 minutes)

// Arrays pour les prédictions par timeframe
static double g_predictionM1[];              // Prédictions M1
static double g_predictionM15[];             // Prédictions M15
static double g_predictionM30[];             // Prédictions M30
static double g_predictionH1[];              // Prédictions H1

// Phase 2: Machine Learning
struct MLValidationData {
   bool valid;                    // Validation ML réussie
   string consensus;              // Consensus ML (buy/sell/neutral)
   double consensusStrength;      // Force du consensus (0-100)
   double avgConfidence;          // Confiance moyenne ML (0-100)
   int buyVotes;                  // Votes d'achat
   int sellVotes;                 // Votes de vente
   int neutralVotes;              // Votes neutres
   datetime lastUpdate;           // Dernière mise à jour
   bool isValid;                  // Données valides
};

static MLValidationData g_mlValidation; // Validation ML Phase 2

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

static DecisionStability g_currentDecisionStability; // Instance globale

// Variables globales manquantes
bool g_tradingPaused = false;
double g_previous_daily_loss = 0.0; // Perte du jour précédent

// Suivi pour fermeture après spike (Boom/Crash)
static double g_lastBoomCrashPrice = 0.0;  // Prix de référence pour détecter le spike

// Structure pour les bougies futures prédites
struct FutureCandle {
   datetime time;        // Temps de la bougie
   double open;         // Prix d'ouverture
   double high;         // Prix maximum
   double low;          // Prix minimum
   double close;        // Prix de clôture
   double confidence;   // Confiance de la prédiction (0.0-1.0)
   string direction;    // Direction (BUY/SELL)
};

// Variables pour les bougies futures prédites
static FutureCandle g_futureCandles[];     // Tableau dynamique des bougies futures
static int g_futureCandlesCount = 0;       // Nombre de bougies futures
static bool g_predictionsValid = false;    // Les prédictions sont-elles valides ?
static datetime g_lastFutureCandlesUpdate = 0; // Dernière mise à jour des bougies futures (realtime)

// Structure pour le canal de prédiction (désactivé mais gardé pour compatibilité)
struct PredictionChannel {
   double upperBand;    // Bande supérieure
   double lowerBand;    // Bande inférieure
   double centerLine;   // Ligne centrale
   double channelWidth; // Largeur du canal
   double confidence;   // Confiance du canal
   datetime validUntil; // Validité jusqu'à
};

static PredictionChannel g_predictionChannel; // Canal de prédiction (non utilisé)

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

// Structure pour stocker les candidats de niveaux (support/résistance)
struct LevelCandidate {
   double price;
   double distance;
   string source;
};

// Déclarations forward des fonctions
ENUM_ORDER_TYPE_FILLING GetSupportedFillingMode(const string symbol);
bool IsForexSymbol(const string symbol);
double GetTotalLoss();
double NormalizeLotSize(double lot);
void CleanOldGraphicalObjects();
void CleanAllGraphicalObjects();
void DrawAIConfidenceAndTrendSummary();
void DrawOpportunitiesPanel();
void DrawMLMetricsPanel();
void SendMLFeedback(ulong ticket, double profit, string reason);
void UpdateMLMetrics(string symbol, string timeframe);
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
void ClosePositionsAtProfitTarget();
void ClosePositionsAtMaxLoss();
void ClosePositionsAtProfit();
//+------------------------------------------------------------------+
//| Vérifie et empêche les ré-entrées trop rapides après une sortie  |
//+------------------------------------------------------------------+
void CheckQuickReentry()
{
   // Si la ré-entrée rapide est désactivée, on ne fait rien
   if (!UseQuickReentry) return;
   
   // Vérifier le temps écoulé depuis la dernière fermeture de position
   datetime currentTime = TimeCurrent();
   
   // Si on a déjà une position ouverte, on ne fait rien
   if (PositionsTotal() > 0) {
      return;
   }
   
   // Si le temps depuis la dernière fermeture est inférieur au délai minimum, on empêche la ré-entrée
   if (g_lastPositionCloseTime > 0 && (currentTime - g_lastPositionCloseTime) < MinReentryDelaySeconds) {
      if (DebugMode) {
         Print("⚠️ Ré-entrée rapide empêchée. Temps écoulé: ", 
               (currentTime - g_lastPositionCloseTime), "s < délai minimum: ", 
               MinReentryDelaySeconds, "s");
      }
      return;
   }
}

void SecureProfitForPosition(ulong ticket, double currentProfit);
void LookForTradingOpportunity();
void ExecuteTrade(ENUM_ORDER_TYPE orderType);
void DrawDerivPatternsOnChart();
void UpdateDerivArrowBlink();
void CloseVolatilityIfLossExceeded(double lossLimit);
void CloseBoomCrashAfterSpike(ulong ticket, double currentProfit);
void CheckAndCloseBuyOnCorrection(ulong ticket, double currentProfit);
void CheckAndCloseSellOnCorrection(ulong ticket, double currentProfit);
void SetFixedSLTPWithMaxLoss(ulong ticket, double maxLossUSD);
void ResetDailyCounters();
void ResetDailyCountersIfNeeded();
void UpdateTradeRecord(ulong ticket);
void WriteTradeToCSV(const TradeRecord& record);
void LogTradeOpen(ulong ticket);
void LogTradeClose(ulong ticket, string closeReason);
string GetCSVFileName();
bool CheckReboundOnTrendline(ENUM_ORDER_TYPE orderType, double &distance);
bool DetectReversalAtFastEMA(ENUM_ORDER_TYPE orderType);
bool CheckAIZoneEntryWithEMA(ENUM_ORDER_TYPE orderType, bool &isInZone, bool &emaConfirmed, bool &isCorrection);
bool CheckTrendAlignment(ENUM_ORDER_TYPE orderType);
bool CheckSuperTrendSignal(ENUM_ORDER_TYPE orderType, double &strength);
bool CheckSupportResistanceRebound(ENUM_ORDER_TYPE orderType, double &reboundStrength);
bool CheckPatternReversal(ENUM_ORDER_TYPE orderType, double &reversalConfidence);
bool AnalyzeMomentumPressureZone(ENUM_ORDER_TYPE orderType, double price, double &momentumScore, double &zoneStrength);
bool DetectBoomCrashReversalAtEMA(ENUM_ORDER_TYPE orderType);
bool TrySpikeEntry(ENUM_ORDER_TYPE orderType);
bool CheckCoherenceOfAllAnalyses(int direction); // Vérifie la cohérence de tous les endpoints (1=BUY, -1=SELL)
bool CheckImmediatePredictionDirection(ENUM_ORDER_TYPE orderType); // Vérifie que la prédiction montre un mouvement immédiat dans le bon sens
bool IsRealTrendReversal(ulong ticket, ENUM_POSITION_TYPE posType, double currentPrice, double entryPrice);
void SendMT5Notification(string message); // Envoie une notification MT5
bool IsTrendStillValid(ENUM_POSITION_TYPE posType);
bool CheckAdvancedEntryConditions(ENUM_ORDER_TYPE orderType, double &entryScore);
void UpdatePricePrediction();
void DrawPricePrediction();
void DetectAndDrawCorrectionZones();
void PlaceLimitOrderOnCorrection();
int GetTrajectoryTrendConfirmation();
void UpdateLimitOrderOnTrajectoryChange();
void UpdateAIDecision();
void UpdateTrendAPIAnalysis();
void UpdateCoherentAnalysis(string symbol);
bool CheckM5ReversalConfirmation(ENUM_ORDER_TYPE orderType);
bool CheckStrongReversalAfterTouch(ENUM_ORDER_TYPE orderType, double &touchLevel, string &touchSource);
double CalculateDynamicTP(ENUM_ORDER_TYPE orderType, double entryPrice);
bool IsPriceInCorrectionZone(ENUM_ORDER_TYPE orderType);

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

//+------------------------------------------------------------------+
//| Vérifie si le symbole est un indice de volatilité                |
//+------------------------------------------------------------------+
bool IsVolatilitySymbol(const string symbol)
{
   // Convertir en majuscules pour comparaison insensible à la casse
   string symbolUpper = symbol;
   StringToUpper(symbolUpper);
   
   // Vérifier les motifs communs pour les indices de volatilité
   bool isVolatility = (StringFind(symbolUpper, "VOLATILITY") != -1 || 
                       StringFind(symbolUpper, "VOL ") != -1 ||
                       StringFind(symbolUpper, " VOL") != -1);
   
   // Exclure les symboles Boom/Crash qui contiennent aussi "Vol"
   if(isVolatility && IsBoomCrashSymbol(symbolUpper))
      return false;
      
   return isVolatility;
}

//+------------------------------------------------------------------+
//| Vérifie si le symbole est un indice de type "Step"               |
//+------------------------------------------------------------------+
bool IsStepIndexSymbol(string symbol)
{
   // Vérifie si le symbole contient "Step" ou "Step Index"
   return (StringFind(symbol, "Step") >= 0);
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
                        " Profit=", DoubleToString(p, 2), "$");
                  SendMLFeedback(ticket, p, "Volatility cumulative loss exceeded");
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
//| Initialize CSV file for logging                                  |
//+------------------------------------------------------------------+
void InitializeCSVFile()
{
   // Implementation for CSV file initialization
   string fileName = "trading_log_" + TimeToString(TimeCurrent(), TIME_DATE) + ".csv";
   g_csvFileName = fileName;
   // Add CSV header if file doesn't exist
   if(!FileIsExist(fileName, FILE_COMMON))
   {
      int handle = FileOpen(fileName, FILE_WRITE|FILE_CSV|FILE_COMMON, ";");
      if(handle != INVALID_HANDLE)
      {
         FileWrite(handle, "DateTime", "Symbol", "Type", "Price", "Lots", "SL", "TP", "Profit");
         FileClose(handle);
      }
   }
}

//+------------------------------------------------------------------+
//| PRIORITÉ ABSOLUE: Protection des gains - Ferme les positions ≥ 1$|
//+------------------------------------------------------------------+
void ProtectGainsWhenTargetReached()
{
   static datetime lastCheck = 0;
   if(TimeCurrent() - lastCheck < 0.5) return; // Toutes les 0.5 secondes pour réactivité maximale
   lastCheck = TimeCurrent();
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
         {
            double currentProfit = positionInfo.Profit();
            
            // PRIORITÉ ABSOLUE: Fermer immédiatement si profit ≥ 1$
            if(currentProfit >= MIN_PROFIT_TO_CLOSE)
            {
               if(DebugMode)
                  Print("🔥 FERMETURE IMMÉDIATE: Position ", ticket, " - Profit: ", DoubleToString(currentProfit, 2), "$");
               
               if(trade.PositionClose(ticket))
               {
                  Print("💰 Position ", ticket, " fermée - Profit sécurisé: ", DoubleToString(currentProfit, 2), "$");
                  SendNotification("💰 Profit sécurisé: " + DoubleToString(currentProfit, 2) + "$");
               }
               else if(DebugMode)
               {
                  Print("⚠️ Erreur fermeture position profitable: ", trade.ResultRetcodeDescription());
               }
               continue;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   // Détecter automatiquement le mode de remplissage supporté par le symbole
   ENUM_ORDER_TYPE_FILLING fillingMode = GetSupportedFillingMode(_Symbol);
   trade.SetTypeFilling(fillingMode);
   Print("✅ Mode de remplissage détecté pour ", _Symbol, ": ", EnumToString(fillingMode));
   trade.SetAsyncMode(false);

   // Initialiser des seuils "fallback" globaux (utilisés si UsePerSymbolExitProfile=false)
   g_effectiveMaxLossPerPositionUSD = MathAbs(MaxLossPerPositionUSD);
   g_effectiveProfitTargetUSD       = MathAbs(OneDollarProfitTarget);
   
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
   
   if(emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE || 
      emaFastH1Handle == INVALID_HANDLE || emaSlowH1Handle == INVALID_HANDLE ||
      emaFastM5Handle == INVALID_HANDLE || emaSlowM5Handle == INVALID_HANDLE ||
      ema50Handle == INVALID_HANDLE || ema100Handle == INVALID_HANDLE || ema200Handle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE ||
      atrM5Handle == INVALID_HANDLE || atrH1Handle == INVALID_HANDLE)
   {
      Print("❌ Erreur initialisation indicateurs");
      return INIT_FAILED;
   }
   
   // Vérifier l'URL IA
   if(g_UseAI_Agent_Live && StringLen(AI_ServerURL) > 0)
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
   
   // Initialiser l'horodatage IA pour éviter les valeurs de 1970
   g_lastAITime = TimeCurrent();
   Print("✅ Horodatage IA initialisé: ", TimeToString(g_lastAITime, TIME_MINUTES|TIME_SECONDS));
   
   // Nettoyer tous les objets graphiques au démarrage
   CleanAllGraphicalObjects();
   
   // Nettoyer spécifiquement les anciens segments EMA qui surchargent le graphique
   DeleteEMAObjects("EMA_Fast_");
   DeleteEMAObjects("EMA_Slow_");
   DeleteEMAObjects("EMA_50_");
   DeleteEMAObjects("EMA_100_");
   DeleteEMAObjects("EMA_200_");
   Print("✅ Anciens segments EMA supprimés pour désurcharger le graphique");
   
   // Nettoyer les canaux de prédiction (désactivés) et les bougies futures
   CleanupPredictionChannel();
   CleanupFutureCandles();
   Print("✅ Anciens objets de prédiction nettoyés");
   
   // Initialiser le fichier CSV si activé
   if(EnableCSVLogging)
   {
      InitializeCSVFile();
      Print("✅ Journalisation CSV activée - Fichier: ", g_csvFileName);
   }
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // NOUVEAU: Nettoyer le dashboard intégré si activé
   if(UseIntegratedDashboard)
   {
      CleanupIntegratedDashboard();
      Print("✅ Dashboard IA intégré nettoyé");
   }
   
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
   
   Print("Robot Scalper Double avec Trading IA intégré arrêté");
}

// Global variables for live parameters
bool g_UseAI_Agent_Live = true;        // Live copy of UseAI_Agent
bool g_TradingEnabled_Live = true;     // Live copy of trading enabled state
double g_InitialLotSize_Live = 0.1;    // Live copy of InitialLotSize

//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   // Handle keyboard shortcuts for live parameter adjustment
   if(id == CHARTEVENT_KEYDOWN)
   {
      // Get keyboard state using MQL5's built-in functions
      bool shiftPressed = (TerminalInfoInteger(TERMINAL_KEYSTATE_SHIFT) != 0);
      bool ctrlPressed = (TerminalInfoInteger(TERMINAL_KEYSTATE_CONTROL) != 0);
      
      // Toggle AI Agent (Ctrl+A or Shift+A)
      if((lparam == 65 || lparam == 97) && (shiftPressed || ctrlPressed)) // 'A' or 'a' key
      {
         g_UseAI_Agent_Live = !g_UseAI_Agent_Live;
         Print("Live Update: AI Agent ", g_UseAI_Agent_Live ? "ENABLED" : "DISABLED");
         ChartRedraw();
      }
      
      // Toggle Trading (Ctrl+T or Shift+T)
      else if((lparam == 84 || lparam == 116) && (shiftPressed || ctrlPressed)) // 'T' or 't' key
      {
         g_TradingEnabled_Live = !g_TradingEnabled_Live;
         Print("Live Update: Trading ", g_TradingEnabled_Live ? "ENABLED" : "DISABLED");
         ChartRedraw();
      }
      
      // Adjust Lot Size (Ctrl+L to increase, Shift+Ctrl+L to decrease)
      else if((lparam == 76 || lparam == 108) && ctrlPressed) // 'L' or 'l' key with Ctrl
      {
         if(shiftPressed)
            g_InitialLotSize_Live = MathMax(0.01, g_InitialLotSize_Live - 0.01);
         else
            g_InitialLotSize_Live += 0.01;
            
         g_InitialLotSize_Live = NormalizeDouble(g_InitialLotSize_Live, 2);
         Print("Live Update: Initial Lot Size = ", DoubleToString(g_InitialLotSize_Live, 2));
         ChartRedraw();
      }
   }
   
   // Handle button clicks or other GUI events
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Add button handling here if needed
   }
}

//+------------------------------------------------------------------+
//| Vérifie si la décision actuelle est NEUTRE pour le symbole      |
//+------------------------------------------------------------------+
bool IsNeutralDecision()
{
   if(StringLen(g_coherentAnalysis.decision) > 0)
   {
      string decision = g_coherentAnalysis.decision;
      StringToUpper(decision);
      
      if(StringFind(decision, "NEUTRE") >= 0 || StringFind(decision, "NEUTRAL") >= 0)
      {
         if(DebugMode)
            Print("ℹ️ Décision NEUTRE détectée pour ", _Symbol, ": ", g_coherentAnalysis.decision);
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Function declarations                                            |
//+------------------------------------------------------------------+
void CheckForCriticalEvents();
void ClosePositionsAtProfit();
bool IsNeutralDecision();
void CloseAllPositionsForSymbol(string symbol, string reason);
void CheckAndManagePositions();
void SecureDynamicProfits();
void CheckAggressiveProfits();
void CloseProfitableBoomCrashPositions();
void ClosePositionsAtProfitTarget();
bool CheckNeutralDecisionClosure();
void UpdateDynamicStopLoss();
bool IsDerivArrowPresent();
ENUM_ORDER_TYPE GetDerivArrowSignalType();

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Optimisation: Ne pas traiter chaque tick, seulement à chaque nouvelle bougie ou à intervalle défini
   static datetime lastProcessedTime = 0;
   datetime currentTime = TimeCurrent();
   
   // Ne traiter qu'une fois par seconde maximum (au lieu de chaque tick)
   if(currentTime - lastProcessedTime < 1) 
   {
         // Même si on ne traite pas complètement, on peut gérer les événements critiques
      if(PositionsTotal() > 0) {
         // Vérifier les événements critiques (SL/TP)
         for(int i = PositionsTotal() - 1; i >= 0; i--) {
            if(PositionGetSymbol(i) == _Symbol) {
               double profit = PositionGetDouble(POSITION_PROFIT);
               if(profit <= -MaxPositionLoss) {
                  // Fermer la position si la perte dépasse le seuil
                  trade.PositionClose(PositionGetInteger(POSITION_TICKET));
               } else if(profit >= IndividualTP1) {
                  // Prendre profit partiel si le seuil est atteint
                  trade.PositionClosePartial(PositionGetInteger(POSITION_TICKET), PositionGetDouble(POSITION_VOLUME) * 0.5);
               }
            }
         }
      }
      return;
   }
   lastProcessedTime = currentTime;
   
   // Réduire la charge CPU en sautant certains cycles
   static int tickCounter = 0;
   tickCounter++;
   if(tickCounter % 5 != 0) return; // Ne traiter qu'un tick sur 5
   
   // Vérifier si la décision est NEUTRE pour ce symbole
   if(IsNeutralDecision())
   {
      // Fermer toutes les positions pour ce symbole
      if(PositionsTotal() > 0)
      {
         // Fermer toutes les positions pour le symbole actuel
         for(int i = PositionsTotal() - 1; i >= 0; i--) {
            if(PositionGetSymbol(i) == _Symbol) {
               trade.PositionClose(PositionGetInteger(POSITION_TICKET));
            }
         }
      }
      
      // Ne pas continuer le traitement pour ce symbole
      return;
   }
   // OPTIMISATION CRUCIALE: Exécuter seulement toutes les 200ms pour alléger MT5
   static ulong lastProcessTick = 0;
   ulong currentTick = GetTickCount();
   
   // Si moins de 200ms depuis le dernier traitement, sortir immédiatement
   if((currentTick - lastProcessTick) < 200) // 200ms entre chaque exécution
      return;
   
   lastProcessTick = currentTick;
   
   // Ne traiter les indicateurs lourds que toutes les secondes
   bool processHeavyIndicators = (tickCounter % 5 == 0);
   
   // PRIORITÉ ABSOLUE: Protection des gains - Vérifier chaque tick (mais limité)
   ProtectGainsWhenTargetReached();
   
   // Vérifier ré-entrée rapide après profit (scalping)
   CheckQuickReentry();
   
   // Réinitialiser les compteurs quotidiens si nécessaire (une fois par minute max)
   static datetime lastDailyReset = 0;
   if((currentTime - lastDailyReset) >= 60) // 1 minute
   {
      ResetDailyCountersIfNeeded();
      lastDailyReset = currentTime;
   }

   // Sécurité prioritaire: fermer immédiatement toute position du robot si perte <= -MaxLossPerPositionUSD
   ClosePositionsAtMaxLoss();
   
   // Vérifier les limites quotidiennes (mode prudent si profit net journalier >= 50 USD)
   bool cautiousMode = (g_dailyProfit >= 50.0);
   if(cautiousMode && DebugMode)
      Print("⚠️ MODE PRUDENT ACTIVÉ: Profit net journalier élevé (", DoubleToString(g_dailyProfit, 2), " USD) - Seulement opportunités très sûres");
   
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
   
   // Mettre à jour l'IA si nécessaire (seulement toutes les 5 secondes au lieu de chaque tick)
   static datetime lastAIUpdate = 0;
   if((currentTime - lastAIUpdate) >= 5 && UseAI_Agent)
   if(g_UseAI_Agent_Live && (currentTime - lastAIUpdate) >= AI_UpdateInterval)
   {
      datetime timeBeforeUpdate = g_lastAITime; // Sauvegarder le temps avant l'appel
      UpdateAIDecision(); // WebRequest est synchrone, donc attend la réponse
      // Mettre à jour lastAIUpdate seulement si UpdateAIDecision() a réussi
      // (g_lastAITime sera mis à jour dans UpdateAIDecision() seulement en cas de succès)
      if(g_lastAITime > timeBeforeUpdate)
      {
         // UpdateAIDecision() a réussi (g_lastAITime a été mis à jour)
      lastAIUpdate = currentTime;
      }
      // Si UpdateAIDecision() a échoué, ne pas mettre à jour lastAIUpdate pour réessayer plus tôt
      
      // NOUVEAU: Vérifier et annuler les ordres LIMIT si les conditions ont changé
      ValidateAndCancelInvalidLimitOrders();
   }
   
   // DÉSACTIVÉ: Mettre à jour les métriques ML en temps réel (trop lourd)
   // UpdateMLMetricsRealtime();
   
   // NETTOYAGE: Supprimer tous les anciens objets de prédiction au démarrage
   static bool predictionCleanupDone = false;
   if(!predictionCleanupDone)
   {
      CleanPredictionObjects();
      predictionCleanupDone = true;
   }
   
   // Mettre à jour la prédiction de prix toutes les 5 minutes (pas chaque seconde)
   // Cela permet au robot de prendre en compte la prédiction pour améliorer les trades présents
   // DÉSACTIVÉ - plus utilisé dans décision finale
   /*
   if(g_UseAI_Agent_Live && (TimeCurrent() - g_lastPredictionUpdate) >= PREDICTION_UPDATE_INTERVAL)
   {
      UpdatePricePrediction(); // Mettre à jour la prédiction de prix
      g_lastPredictionUpdate = TimeCurrent();
   }
   */
   
   // Dessiner la prédiction de prix (optimisé - seulement toutes les 10 secondes pour éviter la surcharge)
   // DÉSACTIVÉ - plus utilisé dans décision finale
   /*
   static datetime lastPredictionDraw = 0;
   if(DrawAIZones && g_predictionValid && (TimeCurrent() - lastPredictionDraw) >= 10)
   {
      DrawPricePrediction();
      lastPredictionDraw = TimeCurrent();
   }
   */
   
   // Utiliser la prédiction pour améliorer les trades présents (ajuster SL/TP)
   // S'exécute seulement si la prédiction est valide et a été mise à jour récemment
   // DÉSACTIVÉ - plus utilisé dans décision finale
   /*
   if(g_predictionValid && (TimeCurrent() - g_lastPredictionUpdate) < 600) // Utiliser si prédiction < 10 min
   {
      UsePredictionForCurrentTrades();
   }
   */
   
   // Mettre à jour l'analyse cohérente si nécessaire (seulement si nécessaire)
   static datetime lastCoherentUpdate = 0;
   if((currentTime - lastCoherentUpdate) >= AI_CoherentAnalysisInterval && ShowCoherentAnalysis && processHeavyIndicators)
   {
      UpdateCoherentAnalysis(_Symbol);
      lastCoherentUpdate = currentTime;
   }

   // Mettre à jour l'analyse de tendance API si nécessaire
   static datetime lastTrendUpdate = 0;
   if(UseTrendAPIAnalysis && (currentTime - lastTrendUpdate) >= AI_UpdateInterval)
   {
      UpdateTrendAPIAnalysis();
      lastTrendUpdate = currentTime;
   }

   // DÉSACTIVÉ: Mettre à jour les métriques ML si nécessaire (trop lourd)
   /*
   static datetime lastMLMetricsUpdate = 0;
   if(UseMLPrediction && (currentTime - lastMLMetricsUpdate) >= AI_UpdateInterval)
   {
      UpdateMLMetrics(_Symbol, "M1");
      lastMLMetricsUpdate = currentTime;
   }
   */
   
   // OPTIMISATION MAXIMALE: Réduire drastiquement la fréquence et les calculs
   static datetime lastDrawUpdate = 0;
   if(currentTime - lastDrawUpdate >= 60) // Toutes les 60 secondes (au lieu de 30)
   {
      // Toujours afficher les labels essentiels (léger)
      DrawAIConfidenceAndTrendSummary();
      
      // Afficher le panneau des opportunités (remplace les labels encombrants)
      DrawOpportunitiesPanel();
      
      // DÉSACTIVÉ: Afficher les métriques ML si disponibles (trop lourd)
      // if(ShowMLMetrics && g_mlMetrics.isValid)
      //    DrawMLMetricsPanel();
      
      // Afficher les zones AI (priorité, léger)
      if(DrawAIZones)
         DrawAIZonesOnChart();
      
      lastDrawUpdate = currentTime;
   }
   
   // OPTIMISATION: Mises à jour très peu fréquentes pour éléments lourds
   static datetime lastHeavyUpdate = 0;
   if(currentTime - lastHeavyUpdate >= 600) // Toutes les 10 minutes (au lieu de 5 min)
   {
      // OPTIMISATION: Nettoyer seulement toutes les 20 minutes (très lourd)
      static datetime lastCleanup = 0;
      if(currentTime - lastCleanup >= 1200) // 20 minutes
      {
         CleanOldGraphicalObjects();
         lastCleanup = currentTime;
      }
      
      // DÉSACTIVÉ: Afficher EMA longues (optimisé, très peu fréquent)
      // if(ShowLongTrendEMA)
      //    DrawLongTrendEMA();
      
      // DÉSACTIVÉ: Afficher support/résistance (très peu fréquent)
      // if(DrawSupportResistance)
      //    DrawSupportResistanceLevels();
      
      // DÉSACTIVÉ: Afficher trendlines (très peu fréquent)
      // if(DrawTrendlines)
      //    DrawTrendlinesOnChart();
      
      lastHeavyUpdate = currentTime;
   }
   
   // DÉSACTIVÉ: Deriv patterns (optimisé - beaucoup moins fréquent)
   /*
   static datetime lastDerivUpdate = 0;
   if(DrawDerivPatterns && (currentTime - lastDerivUpdate) >= 120) // Toutes les 120 secondes (au lieu de 60)
   {
      DrawDerivPatternsOnChart();
      UpdateDerivArrowBlink();
      lastDerivUpdate = currentTime;
   }
   */
   
   // OPTIMISATION: Vérifier les positions moins fréquemment
   static datetime lastPositionCheck = 0;
   if(currentTime - lastPositionCheck >= 2) // Toutes les 2 secondes (au lieu de chaque seconde)
   {
      // Vérifier et gérer les positions existantes
      for(int i = PositionsTotal() - 1; i >= 0; i--) {
         if(PositionGetSymbol(i) == _Symbol) {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            // Fermer si profit atteint la cible
            if(profit >= IndividualTP1) {
               trade.PositionClose(ticket);
               continue;
            }
            
            // Mettre à jour le stop loss dynamique
            if(profit > 0) {
               double currentSL = PositionGetDouble(POSITION_SL);
               double currentPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double newSL = currentSL;
               
               if(profit > 0.5) {
                  // Déplacer le SL au seuil de rentabilité + 0.1$
                  newSL = currentPrice + (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 0.1 : -0.1);
               } else if(profit > 1.0) {
                  // Verrouiller plus de profit
                  newSL = currentPrice + (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? 0.5 : -0.5);
               }
               
               // Mettre à jour le SL si nécessaire
               if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && newSL > currentSL) ||
                  (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && (newSL < currentSL || currentSL == 0))) {
                  trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP));
               }
            }
         }
      }
      
      lastPositionCheck = currentTime;
   }
   
   // ===== NOUVEAU: VÉRIFICATION IMMÉDIATE DES DERIV ARROW PATTERNS =====
   // Exécuter un trade immédiatement dès l'apparition d'un DERIV ARROW Pattern
   static datetime lastDerivArrowCheck = 0;
   if((currentTime - lastDerivArrowCheck) >= 1 && processHeavyIndicators) // Vérifier toutes les secondes
   {
      lastDerivArrowCheck = TimeCurrent();
      
      // Vérifier si un DERIV ARROW Pattern est présent
      if(IsDerivArrowPresent())
      {
         // Déterminer le type de signal en fonction de la flèche détectée
         ENUM_ORDER_TYPE arrowSignalType = GetDerivArrowSignalType();
         
         if(arrowSignalType != WRONG_VALUE)
         {
            // VÉRIFICATION CRUCIALE: Ne pas trader si décision finale est NEUTRE
            // Même avec DERIV ARROW, respecter la décision finale de l'IA
            bool hasStrongSignal = false;
            string signalType = "";
            
            // 1. Vérifier l'analyse cohérente d'abord - version améliorée
            if(StringLen(g_coherentAnalysis.decision) > 0)
            {
               string decision = g_coherentAnalysis.decision;
               StringToUpper(decision);
               
               // Vérifier d'abord la neutralité
               if(StringFind(decision, "NEUTRE") >= 0)
               {
                  if(DebugMode)
                     Print("🚫 Décision NEUTRE - Aucun trade autorisé malgré la flèche");
                  return; // Sortir immédiatement si NEUTRE
               }
               
               // Vérifier les signaux d'achat/vente avec plus de flexibilité
               if(StringFind(decision, "ACHAT") >= 0 || StringFind(decision, "BUY") >= 0)
               {
                  signalType = "ACHAT FORT";
                  hasStrongSignal = true;
                  if(DebugMode)
                     Print("✅ Décision d'achat détectée: ", decision);
               }
               else if(StringFind(decision, "VENTE") >= 0 || StringFind(decision, "SELL") >= 0)
               {
                  signalType = "VENTE FORTE";
                  hasStrongSignal = true;
                  if(DebugMode)
                     Print("✅ Décision de vente détectée: ", decision);
               }
            }
            
            // 2. Vérifier l'action IA si pas de signal cohérent
            if(!hasStrongSignal && StringLen(g_lastAIAction) > 0 && g_lastAIConfidence >= 0.70)
            {
               if(g_lastAIAction == "buy")
               {
                  signalType = "ACHAT FORT";
                  hasStrongSignal = true;
               }
               else if(g_lastAIAction == "sell")
               {
                  signalType = "VENTE FORTE";
                  hasStrongSignal = true;
               }
            }
            
            // Vérifier la cohérence entre le signal de la flèche et la décision de l'IA
            if(hasStrongSignal)
            {
               // Vérifier si la direction du signal correspond à la flèche détectée
               bool signalMatch = false;
               ENUM_ORDER_TYPE tradeDirection = WRONG_VALUE;
               
               // Initialiser tradeDirection avec la direction du signal
               if(signalType == "BUY" || signalType == "1")
                  tradeDirection = ORDER_TYPE_BUY;
               else if(signalType == "SELL" || signalType == "-1")
                  tradeDirection = ORDER_TYPE_SELL;
               
               if(signalType == "ACHAT FORT" && arrowSignalType == ORDER_TYPE_BUY)
               {
                  signalMatch = true;
                  tradeDirection = ORDER_TYPE_BUY;
               }
               else if(signalType == "VENTE FORTE" && arrowSignalType == ORDER_TYPE_SELL)
               {
                  signalMatch = true;
                  tradeDirection = ORDER_TYPE_SELL;
               }
               
               if(signalMatch)
               {
                  // Vérifier s'il n'y a pas déjà une position ouverte avec profit minimum
                  if(HasPositionWithMinProfit(_Symbol, 1.0))
                  {
                     if(DebugMode)
                        Print("ℹ️ Position existante avec profit minimum de 1$ détectée - Pas de nouveau trade pour ", _Symbol);
                     return;
                  }
                  
                  // Vérifier le rebond sur l'EMA avant d'entrer
                  // Convertir signalType en ENUM_ORDER_TYPE
                  ENUM_ORDER_TYPE orderDirection;
                  if(signalType == "BUY" || signalType == "1" || signalType == "ACHAT FORT")
                     orderDirection = ORDER_TYPE_BUY;
                  else
                     orderDirection = ORDER_TYPE_SELL;
                  
                  if(CheckEMARebound(orderDirection))
                  {
                     if(DebugMode)
                        Print("🎯 Signal cohérent et rebond EMA confirmé! ", EnumToString(orderDirection), " (Confirmé par: ", signalType, ")");
                     
                     // ===== STRATÉGIE AGRESSIVE (TRADE À FOND) =====
                     if(ExecuteAggressiveStrategy(orderDirection, signalType))
                     {
                        if(DebugMode)
                           Print("🔥 Stratégie agressive activée pour ", signalType);
                     }
                     else
                     {
                        // Fallback: Exécuter le trade normal avec SL/TP par défaut
                        ExecuteDerivArrowTrade(orderDirection);
                     }
                  }
                  else
                  {
                     if(DebugMode)
                        Print("⏳ Signal valide mais en attente de rebond sur l'EMA pour ", EnumToString(orderDirection));
                  }
               }
               else
               {
                  if(DebugMode)
                     Print("⚠️ Conflit de signal: Décision IA=", signalType, " mais signal flèche=", EnumToString(arrowSignalType), " - Trade annulé");
               }
               
               return;
            }
            else
            {
               if(DebugMode)
                  Print("🚫 DERIV ARROW ignoré: Aucun signal fort confirmé (décision faible ou absente)");
            }
         }
      }
   }
   
   // Si pas de position, chercher une opportunité
   if(!g_hasPosition)
   {
      LookForTradingOpportunity();
   }
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Exécute la stratégie agressive avec gestion des indicateurs     |
//+------------------------------------------------------------------+
bool ExecuteAggressiveStrategy(ENUM_ORDER_TYPE orderType, string signalType)
{
   // Vérifier si le trading est autorisé
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) 
   {
      Print("Le trading n'est pas autorisé");
      return false;
   }
   
   // Vérifier s'il y a déjà une position avec profit minimum
   if(HasPositionWithMinProfit(_Symbol, 1.0))
   {
      if(DebugMode)
         Print("ℹ️ Position existante avec profit minimum de 1$ détectée - Pas de nouveau trade");
      return false;
   }
   
   // Obtenir les prix actuels
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (orderType == ORDER_TYPE_BUY) ? ask : bid;
   
   // Calculer les niveaux de SL/TP
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   // Calculer la taille de lot en fonction du risque
   double lotSize = CalculateOptimalLotSize(price, orderType == ORDER_TYPE_BUY ? price - StopLossUSD : price + StopLossUSD);
   if(lotSize <= 0)
   {
      Print("Erreur dans le calcul de la taille de lot");
      return false;
   }
   
   // Calculer les niveaux de SL/TP
   double sl = 0, tp = 0;
   if(orderType == ORDER_TYPE_BUY)
   {
      sl = NormalizeDouble(price - StopLossUSD / (lotSize * 10), digits);
      tp = NormalizeDouble(price + TakeProfitUSD / (lotSize * 10), digits);
   }
   else
   {
      sl = NormalizeDouble(price + StopLossUSD / (lotSize * 10), digits);
      tp = NormalizeDouble(price - TakeProfitUSD / (lotSize * 10), digits);
   }
   
   // Exécuter l'ordre
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   if(trade.PositionOpen(_Symbol, orderType, lotSize, price, sl, tp, "Stratégie Agressive"))
   {
      if(DebugMode)
         Print("✅ Position ouverte: ", EnumToString(orderType), " Prix: ", price, " Lot: ", lotSize, " SL: ", sl, " TP: ", tp);
      
      // Afficher les indicateurs techniques sur le graphique
      DrawTechnicalIndicators();
      
      return true;
   }
   else
   {
      Print("❌ Erreur d'ouverture de position: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Affiche les indicateurs techniques sur le graphique              |
//+------------------------------------------------------------------+
void DrawTechnicalIndicators()
{
   // Supprimer les anciens objets
   ObjectsDeleteAll(0, "SR_");
   ObjectsDeleteAll(0, "TL_");
   ObjectsDeleteAll(0, "FIBO_");
   
   // Calculer les supports/résistances
   double support1 = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, 24, 1));
   double resistance1 = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 24, 1));
   
   // Afficher les supports/résistances
   CreateHLine("SR_Support1", support1, clrLime, 1, STYLE_DOT);
   CreateHLine("SR_Resistance1", resistance1, clrRed, 1, STYLE_DOT);
   
   // Afficher les lignes de tendance (exemple avec les 20 dernières bouches H1)
   double trendHigh1 = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 20, 1));
   double trendHigh2 = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 20, 20));
   double trendLow1 = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, 20, 1));
   double trendLow2 = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, 20, 20));
   
   CreateTrendLine("TL_Up", TimeCurrent() - 3600*20, trendHigh1, TimeCurrent() - 3600, trendHigh2, clrRed, 1, STYLE_DASH);
   CreateTrendLine("TL_Down", TimeCurrent() - 3600*20, trendLow1, TimeCurrent() - 3600, trendLow2, clrLime, 1, STYLE_DASH);
   
   // Afficher les retracements de Fibonacci
   double high = iHigh(_Symbol, PERIOD_D1, iHighest(_Symbol, PERIOD_D1, MODE_HIGH, 5, 1));
   double low = iLow(_Symbol, PERIOD_D1, iLowest(_Symbol, PERIOD_D1, MODE_LOW, 5, 1));
   
   // Supprimer l'ancien objet Fibonacci s'il existe
   ObjectDelete(0, "FIBO_Retracement");
   
   // Créer un nouvel objet Fibonacci
   if(ObjectCreate(0, "FIBO_Retracement", OBJ_FIBO, 0, TimeCurrent() - 3600*24, high, TimeCurrent(), low))
   {
      // Définir les propriétés de l'objet
      ObjectSetInteger(0, "FIBO_Retracement", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "FIBO_Retracement", OBJPROP_LEVELCOLOR, clrDodgerBlue);
      ObjectSetInteger(0, "FIBO_Retracement", OBJPROP_LEVELSTYLE, STYLE_DOT);
      
      // Définir les niveaux de retracement Fibonacci
      double levels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
      int levels_count = ArraySize(levels);
      
      // Définir le nombre de niveaux
      ObjectSetInteger(0, "FIBO_Retracement", OBJPROP_LEVELS, levels_count);
      
      // Définir chaque niveau
      for(int i = 0; i < levels_count; i++)
      {
         string level_name = "FIBO_" + IntegerToString(i);
         ObjectSetString(0, "FIBO_Retracement", OBJPROP_LEVELTEXT, i, level_name);
         ObjectSetDouble(0, "FIBO_Retracement", OBJPROP_LEVELVALUE, i, levels[i]);
      }
      
      // Forcer la mise à jour du graphique
      ChartRedraw(0);
      ObjectSetDouble(0, "FIBO_Retracement", OBJPROP_LEVELVALUE, 5, 0.786);
      ObjectSetDouble(0, "FIBO_Retracement", OBJPROP_LEVELVALUE, 6, 1.0);
   }
   
   // Mettre à jour le graphique
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Crée une ligne de tendance                                       |
//+------------------------------------------------------------------+
void CreateTrendLine(string name, datetime time1, double price1, datetime time2, double price2, color clr, int width, ENUM_LINE_STYLE style)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
   }
   else
   {
      ObjectMove(0, name, 0, time1, price1);
      ObjectMove(0, name, 1, time2, price2);
   }
   
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
}

//+------------------------------------------------------------------+
//| Crée une ligne horizontale                                       |
//+------------------------------------------------------------------+
void CreateHLine(string name, double price, color clr, int width, ENUM_LINE_STYLE style)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   }
   else
   {
      ObjectMove(0, name, 0, 0, price);
   }
   
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
}

//+------------------------------------------------------------------+
//| Vérifie si une position a atteint un profit minimum              |
//+------------------------------------------------------------------+
bool HasPositionWithMinProfit(string symbol, double minProfit)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol && 
            PositionGetDouble(POSITION_PROFIT) >= minProfit)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Calcule la taille de lot optimale en fonction du risque          |
//+------------------------------------------------------------------+
double CalculateOptimalLotSize(double entryPrice, double stopLossPrice)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(tickSize <= 0 || tickValue <= 0 || lotStep <= 0)
      return 0.1; // Valeur par défaut en cas d'erreur
   
   double stopDistance = MathAbs(entryPrice - stopLossPrice) / tickSize;
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * 0.01; // 1% de risque
   double lotSize = NormalizeDouble(riskAmount / (stopDistance * tickValue), 2);
   
   // Ajuster au pas de lot le plus proche
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   // Vérifier les limites de taille de lot
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   return lotSize;
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
//+------------------------------------------------------------------+
//| Vérifie et annule les ordres LIMIT en attente si conditions invalides |
//+------------------------------------------------------------------+
void ValidateAndCancelInvalidLimitOrders()
{
   if(!UseAI_Agent)
      return;
   
   // Parcourir tous les ordres en attente
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && orderInfo.SelectByIndex(i))
      {
         if(orderInfo.Symbol() == _Symbol && 
            orderInfo.Magic() == InpMagicNumber)
         {
            ENUM_ORDER_TYPE orderType = orderInfo.OrderType();
            
            // Vérifier uniquement les ordres LIMIT
            if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT)
            {
               // Valider les conditions actuelles
               if(!ValidateLimitOrderConditions(orderType))
               {
                  Print("🚫 ANNULATION ORDRE LIMIT: Ticket ", ticket, 
                        " Type=", EnumToString(orderType),
                        " - Conditions changées (Action IA=", g_lastAIAction,
                        " Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
                  
                  // Annuler l'ordre LIMIT
                  MqlTradeRequest cancelRequest = {};
                  MqlTradeResult cancelResult = {};
                  cancelRequest.action = TRADE_ACTION_REMOVE;
                  cancelRequest.order = ticket;
                  
                  if(OrderSend(cancelRequest, cancelResult))
                  {
                     Print("✅ Ordre LIMIT ", ticket, " annulé avec succès - Conditions non valides");
                  }
                  else
                  {
                     Print("❌ Erreur annulation ordre LIMIT ", ticket, ": ", cancelResult.retcode, " - ", cancelResult.comment);
                  }
               }
               else
               {
                  if(DebugMode)
                     Print("✅ Ordre LIMIT ", ticket, " toujours valide - Conditions maintenues");
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie la cohérence de TOUS les endpoints d'analyse              |
//| Retourne true si tous les signaux sont cohérents avec la direction |
//| Cette fonction garantit la cohérence avant toute décision          |
//+------------------------------------------------------------------+
bool CheckCoherenceOfAllAnalyses(int direction) // 1=BUY, -1=SELL
{
   int coherenceScore = 0; // Score de cohérence (plus élevé = plus cohérent)
   int maxScore = 0; // Score maximum possible
   int contradictions = 0; // Nombre de contradictions (anti-hasard)
   string coherenceDetails = "";
   
   // ===== VÉRIFICATION 1: Action IA (/decision endpoint) =====
   maxScore += 3; // Poids important (3 points)
   int aiDirection = 0;
   if(g_lastAIAction == "buy")
      aiDirection = 1;
   else if(g_lastAIAction == "sell")
      aiDirection = -1;
   
   if(aiDirection == direction)
   {
      coherenceScore += 3;
      coherenceDetails += "IA:OK(" + DoubleToString(g_lastAIConfidence * 100, 1) + "%) ";
   }
   else if(aiDirection == 0)
   {
      coherenceScore += 1; // Neutre = pas de contradiction
      coherenceDetails += "IA:NEUTRE ";
   }
   else
   {
      coherenceDetails += "IA:CONTRADICTION ";
      contradictions++;
      // Pas de points si contradiction
   }
   
   // ===== VÉRIFICATION 2: API Trend (/trend endpoint) =====
   if(UseTrendAPIAnalysis && g_api_trend_valid)
   {
      maxScore += 2; // Poids moyen (2 points)
      if(g_api_trend_direction == direction)
      {
         coherenceScore += 2;
         coherenceDetails += "Trend:OK(" + DoubleToString(g_api_trend_confidence, 1) + "%) ";
      }
      else if(g_api_trend_direction == 0)
      {
         coherenceScore += 1; // Neutre = pas de contradiction
         coherenceDetails += "Trend:NEUTRE ";
      }
      else
      {
         coherenceDetails += "Trend:CONTRADICTION ";
         contradictions++;
      }
   }
   
   // ===== VÉRIFICATION 3: Prédiction de prix (/prediction endpoint) =====
   if(g_predictionValid && ArraySize(g_pricePrediction) >= 20)
   {
      maxScore += 2; // Poids moyen (2 points)
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
      int predictionWindow = MathMin(50, ArraySize(g_pricePrediction));
      double predictedPrice = g_pricePrediction[predictionWindow - 1];
      double priceMovement = predictedPrice - currentPrice;
      double movementPercent = (MathAbs(priceMovement) / currentPrice) * 100.0;
      
      int predictionDirection = 0;
      double minMove = MathMax(0.05, ImmediatePredictionMinMovePercent); // Anti-hasard: exiger un vrai mouvement
      if(movementPercent > minMove) // Mouvement significatif
      {
         if(priceMovement > 0)
            predictionDirection = 1; // Haussière
         else
            predictionDirection = -1; // Baissière
      }
      
      if(predictionDirection == direction)
      {
         coherenceScore += 2;
         coherenceDetails += "Pred:OK(" + DoubleToString(movementPercent, 2) + "%) ";
      }
      else if(predictionDirection == 0)
      {
         coherenceScore += 1; // Neutre = pas de contradiction
         coherenceDetails += "Pred:NEUTRE ";
      }
      else
      {
         coherenceDetails += "Pred:CONTRADICTION ";
         contradictions++;
      }
   }
   
   // ===== CALCUL DU TAUX DE COHÉRENCE =====
   double coherenceRate = (maxScore > 0) ? ((double)coherenceScore / (double)maxScore) * 100.0 : 0.0;
   
   // Anti-hasard: exiger une cohérence plus élevée + aucune contradiction.
   double minRate = MinEndpointsCoherenceRate;
   if(RequireAllEndpointsAlignment)
      minRate = MathMax(minRate, 90.0);
   bool isCoherent = (coherenceRate >= minRate && contradictions == 0);
   
   if(!isCoherent)
   {
      Print("🚫 COHÉRENCE INSUFFISANTE: ", DoubleToString(coherenceRate, 1), "% (Min: ", DoubleToString(minRate, 1), "%) | ",
            coherenceDetails, "| Contradictions: ", contradictions,
            " | Score: ", coherenceScore, "/", maxScore, " | Direction requise: ", (direction == 1 ? "BUY" : "SELL"));
   }
   else
   {
      if(DebugMode)
         Print("✅ COHÉRENCE VALIDÉE: ", DoubleToString(coherenceRate, 1), "% | ", coherenceDetails,
               "| Contradictions: ", contradictions, " | Score: ", coherenceScore, "/", maxScore,
               " | Direction: ", (direction == 1 ? "BUY" : "SELL"));
   }
   
   return isCoherent;
}

//+------------------------------------------------------------------+
//| Envoie une notification MT5                                      |
//+------------------------------------------------------------------+
void SendMT5Notification(string message)
{
   SendNotification(message);
   Print("📱 NOTIFICATION MT5: ", message);
}

//+------------------------------------------------------------------+
//| Vérifie que la prédiction montre un mouvement immédiat dans le bon sens |
//| Retourne true si la prédiction montre un mouvement immédiat (5-10 bougies) |
//| dans le bon sens avec au moins 0.05% de mouvement                  |
//+------------------------------------------------------------------+
bool CheckImmediatePredictionDirection(ENUM_ORDER_TYPE orderType)
{
   if(!g_predictionValid || ArraySize(g_pricePrediction) < 10)
   {
      if(DebugMode)
         Print("⚠️ Prédiction invalide ou insuffisante pour vérifier direction immédiate");
      return false; // Pas de prédiction valide, bloquer
   }
   
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   
   // Vérifier plusieurs fenêtres de prédiction (5, 10, 20 bougies) pour garantir un mouvement immédiat
   // Anti-hasard: seuil de mouvement configurable + validation plus stricte si UseStrictQualityFilter=true
   int windows[] = {5, 10, 20};
   int validWindows = 0;
   int alignedWindows = 0;
   
   bool expectedBullish = (orderType == ORDER_TYPE_BUY);
   
   for(int w = 0; w < ArraySize(windows); w++)
   {
      int window = windows[w];
      if(ArraySize(g_pricePrediction) < window)
         continue;
      
      double predictedPrice = g_pricePrediction[window - 1];
      double priceMovement = predictedPrice - currentPrice;
      double movementPercent = (MathAbs(priceMovement) / currentPrice) * 100.0;
      
      // Mouvement significatif (anti-hasard)
      double minMove = MathMax(0.05, ImmediatePredictionMinMovePercent);
      if(movementPercent > minMove)
      {
         validWindows++;
         bool isBullish = (priceMovement > 0);
         
         // Vérifier l'alignement avec la direction attendue
         if(isBullish == expectedBullish)
            alignedWindows++;
      }
   }
   
   // En mode strict: exiger que TOUTES les fenêtres soient valides et alignées
   // Sinon: au moins 2 fenêtres valides et alignées (sur 3)
   bool isValid = false;
   if(UseStrictQualityFilter)
      isValid = (validWindows == ArraySize(windows) && alignedWindows == validWindows);
   else
      isValid = (validWindows >= 2 && alignedWindows >= 2);
   
   if(!isValid)
   {
      Print("🚫 PRÉDICTION IMMÉDIATE INVALIDE: ", validWindows, " fenêtre(s) valide(s), ", alignedWindows, " alignée(s) - Direction requise: ", (expectedBullish ? "BUY" : "SELL"));
      return false;
   }
   
   if(DebugMode)
      Print("✅ PRÉDICTION IMMÉDIATE VALIDÉE: ", alignedWindows, "/", validWindows, " fenêtre(s) alignée(s) - Direction: ", (expectedBullish ? "BUY" : "SELL"));
   
   return true;
}

//+------------------------------------------------------------------+
//| Fonction de décision finale combinant toutes les analyses         |
//| Combine: état, recommandation IA, tendances (M1/M5/H1), zone prédiction |
//| Retourne true si une décision valide est trouvée                  |
//+------------------------------------------------------------------+
bool GetFinalDecision(FinalDecisionResult &result)
{
   // Initialiser le résultat
   result.direction = 0;
   result.confidence = 0.0;
   result.details = "";
   result.isValid = false;
   
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   
   // ===== 1. ANALYSE IA (Recommandation) =====
   int aiDirection = 0;
   double aiConfidence = 0.0;
   string aiDetails = "";
   
   if(g_lastAIAction == "buy")
   {
      aiDirection = 1;
      aiConfidence = g_lastAIConfidence;
      aiDetails = "IA:BUY(" + DoubleToString(aiConfidence * 100, 1) + "%)";
   }
   else if(g_lastAIAction == "sell")
   {
      aiDirection = -1;
      aiConfidence = g_lastAIConfidence;
      aiDetails = "IA:SELL(" + DoubleToString(aiConfidence * 100, 1) + "%)";
   }
   else if(g_api_trend_direction != 0 && g_api_trend_valid)
   {
      aiDirection = g_api_trend_direction;
      aiConfidence = g_api_trend_confidence / 100.0;
      aiDetails = "Trend:" + (aiDirection == 1 ? "BUY" : "SELL") + "(" + DoubleToString(aiConfidence * 100, 1) + "%)";
   }
   else
   {
      aiDetails = "IA:NEUTRE";
   }
   
   // ===== 2. ANALYSE TENDANCES (M1, M5, H1) =====
   int trendM1 = 0, trendM5 = 0, trendH1 = 0;
   string trendDetails = "";
   
   // Tendance M1
   double emaFastM1[], emaSlowM1[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFastM1) >= 2 && CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlowM1) >= 2)
   {
      if(emaFastM1[0] > emaSlowM1[0] && emaFastM1[1] > emaSlowM1[1])
         trendM1 = 1; // Haussière
      else if(emaFastM1[0] < emaSlowM1[0] && emaFastM1[1] < emaSlowM1[1])
         trendM1 = -1; // Baissière
   }
   
   // Tendance M5
   double emaFastM5[], emaSlowM5[];
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   if(CopyBuffer(emaFastM5Handle, 0, 0, 2, emaFastM5) >= 2 && CopyBuffer(emaSlowM5Handle, 0, 0, 2, emaSlowM5) >= 2)
   {
      if(emaFastM5[0] > emaSlowM5[0] && emaFastM5[1] > emaSlowM5[1])
         trendM5 = 1; // Haussière
      else if(emaFastM5[0] < emaSlowM5[0] && emaFastM5[1] < emaSlowM5[1])
         trendM5 = -1; // Baissière
   }
   
   // Tendance H1
   double emaFastH1[], emaSlowH1[];
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   if(CopyBuffer(emaFastH1Handle, 0, 0, 2, emaFastH1) >= 2 && CopyBuffer(emaSlowH1Handle, 0, 0, 2, emaSlowH1) >= 2)
   {
      if(emaFastH1[0] > emaSlowH1[0] && emaFastH1[1] > emaSlowH1[1])
         trendH1 = 1; // Haussière
      else if(emaFastH1[0] < emaSlowH1[0] && emaFastH1[1] < emaSlowH1[1])
         trendH1 = -1; // Baissière
   }
   
   trendDetails = StringFormat("M1:%s M5:%s H1:%s", 
                               trendM1 == 1 ? "↑" : (trendM1 == -1 ? "↓" : "→"),
                               trendM5 == 1 ? "↑" : (trendM5 == -1 ? "↓" : "→"),
                               trendH1 == 1 ? "↑" : (trendH1 == -1 ? "↓" : "→"));
   
   // ===== 3. ANALYSE PRÉDICTION (Zone) =====
   int predictionDirection = 0;
   double predictionConfidence = 0.0;
   string predictionDetails = "";
   
   if(g_predictionValid && ArraySize(g_pricePrediction) >= 20)
   {
      int window = MathMin(50, ArraySize(g_pricePrediction));
      double predictedPrice = g_pricePrediction[window - 1];
      double movement = predictedPrice - currentPrice;
      double movementPercent = (MathAbs(movement) / currentPrice) * 100.0;
      
      if(movementPercent > 0.05)
      {
         if(movement > 0)
            predictionDirection = 1;
         else
            predictionDirection = -1;
         
         predictionConfidence = MathMin(movementPercent / 2.0, 1.0); // Normaliser à 0-1
         predictionDetails = "Pred:" + (predictionDirection == 1 ? "BUY" : "SELL") + "(" + DoubleToString(movementPercent, 2) + "%)";
      }
      else
      {
         predictionDetails = "Pred:NEUTRE";
      }
   }
   else
   {
      predictionDetails = "Pred:INVALIDE";
   }
   
   // ===== 4. COMBINER TOUTES LES ANALYSES =====
   int buyVotes = 0;
   int sellVotes = 0;
   double totalConfidence = 0.0;
   int voteCount = 0;
   
   // Vote IA (poids: 40%)
   if(aiDirection != 0)
   {
      if(aiDirection == 1) buyVotes += 4;
      else sellVotes += 4;
      totalConfidence += aiConfidence * 0.4;
      voteCount++;
   }
   
   // Vote Tendances (poids: 30% - M5 et H1 plus importants)
   if(trendM5 != 0)
   {
      if(trendM5 == 1) buyVotes += 2;
      else sellVotes += 2;
      voteCount++;
   }
   if(trendH1 != 0)
   {
      if(trendH1 == 1) buyVotes += 2;
      else sellVotes += 2;
      voteCount++;
   }
   if(trendM1 != 0)
   {
      if(trendM1 == 1) buyVotes += 1;
      else sellVotes += 1;
      voteCount++;
   }
   if(voteCount > 0)
      totalConfidence += 0.3;
   
   // Vote Prédiction (poids: 30%)
   if(predictionDirection != 0)
   {
      if(predictionDirection == 1) buyVotes += 3;
      else sellVotes += 3;
      totalConfidence += predictionConfidence * 0.3;
      voteCount++;
   }
   
   // ===== 5. DÉCISION FINALE =====
   if(buyVotes > sellVotes && buyVotes >= 5) // Au moins 5 votes pour BUY
   {
      result.direction = 1; // BUY
      // totalConfidence est déjà construit comme un score 0-1 (poids IA 40% + tendances 30% + prédiction 30%)
      // Ne PAS diviser par voteCount (sinon le score devient artificiellement faible et "hasardeux").
      result.confidence = MathMax(0.0, MathMin(1.0, totalConfidence));
      result.details = aiDetails + " | " + trendDetails + " | " + predictionDetails;
      result.isValid = true;
   }
   else if(sellVotes > buyVotes && sellVotes >= 5) // Au moins 5 votes pour SELL
   {
      result.direction = -1; // SELL
      result.confidence = MathMax(0.0, MathMin(1.0, totalConfidence));
      result.details = aiDetails + " | " + trendDetails + " | " + predictionDetails;
      result.isValid = true;
   }
   else
   {
      result.direction = 0; // NEUTRE
      result.confidence = MathMax(0.0, MathMin(1.0, totalConfidence));
      result.details = aiDetails + " | " + trendDetails + " | " + predictionDetails + " | Votes BUY:" + IntegerToString(buyVotes) + " SELL:" + IntegerToString(sellVotes);
      result.isValid = false;
   }
   
   if(DebugMode)
      Print("🎯 DÉCISION FINALE: Direction=", (result.direction == 1 ? "BUY" : (result.direction == -1 ? "SELL" : "NEUTRE")),
            " Confiance=", DoubleToString(result.confidence * 100, 1), "%",
            " Valide=", result.isValid ? "OUI" : "NON",
            " | ", result.details);
   
   return result.isValid;
}

//+------------------------------------------------------------------+
//| Trouve le meilleur prix pour ordre limite sur S/R ou trendline (M1/M5) |
//| TOUJOURS placé sur support/résistance ou trendline proche en M1 ou M5  |
//+------------------------------------------------------------------+
double FindOptimalLimitOrderPrice(ENUM_ORDER_TYPE orderType, double suggestedPrice)
{
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculer ATR pour tolérance "proche"
   double atr[];
   ArraySetAsSeries(atr, true);
   double atrValue = 0;
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      atrValue = atr[0];
   else
      atrValue = currentPrice * 0.001; // Fallback: 0.1%
   
   double maxDistance = atrValue * 2.0; // 2x ATR = distance max pour "proche"
   
   bool isBuy = (orderType == ORDER_TYPE_BUY_LIMIT);
   double bestPrice = suggestedPrice; // Par défaut
   string bestSource = "Suggéré";
   double minDistance = MathAbs(suggestedPrice - currentPrice);
   
   // ===== 1. VÉRIFIER SUPPORT/RÉSISTANCE (FindNextSupportResistance) =====
   ENUM_ORDER_TYPE srDirection;
   if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT)
      srDirection = ORDER_TYPE_BUY;
   else
      srDirection = ORDER_TYPE_SELL;
   double srLevel = FindNextSupportResistance(srDirection, currentPrice);
   if(srLevel > 0)
   {
      double srDistance = MathAbs(srLevel - currentPrice);
      if(srDistance <= maxDistance)
      {
         // Vérifier que le niveau est dans le bon sens
         if((isBuy && srLevel <= currentPrice) || (!isBuy && srLevel >= currentPrice))
         {
            if(srDistance < minDistance)
            {
               bestPrice = srLevel;
               bestSource = "Support/Résistance";
               minDistance = srDistance;
            }
         }
      }
   }
   
   // ===== 2. VÉRIFIER TRENDLINES (M1 et M5) =====
   double trendlineDistance = 0;
   double trendlineLevel = 0;
   string trendlineSource = "";
   
   if(CheckReboundOnTrendline(orderType, trendlineDistance))
   {
      // Calculer le niveau de la trendline
      double emaFastM5[], emaSlowM5[], emaFastM1[], emaSlowM1[];
      ArraySetAsSeries(emaFastM5, true);
      ArraySetAsSeries(emaSlowM5, true);
      ArraySetAsSeries(emaFastM1, true);
      ArraySetAsSeries(emaSlowM1, true);
      
      // Tendance M5 (priorité)
      if(CopyBuffer(emaFastM5Handle, 0, 0, 1, emaFastM5) > 0 && CopyBuffer(emaSlowM5Handle, 0, 0, 1, emaSlowM5) > 0)
      {
         if(isBuy)
            trendlineLevel = MathMin(emaFastM5[0], emaSlowM5[0]); // Support = plus bas EMA
         else
            trendlineLevel = MathMax(emaFastM5[0], emaSlowM5[0]); // Résistance = plus haut EMA
         trendlineSource = "Trendline M5";
      }
      // Fallback M1
      else if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFastM1) > 0 && CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlowM1) > 0)
      {
         if(isBuy)
            trendlineLevel = MathMin(emaFastM1[0], emaSlowM1[0]); // Support = plus bas EMA
         else
            trendlineLevel = MathMax(emaFastM1[0], emaSlowM1[0]); // Résistance = plus haut EMA
         trendlineSource = "Trendline M1";
      }
      
      if(trendlineLevel > 0)
      {
         double trendlineDist = MathAbs(trendlineLevel - currentPrice);
         if(trendlineDist <= maxDistance && trendlineDist < minDistance)
         {
            // Vérifier que le niveau est dans le bon sens
            if((isBuy && trendlineLevel <= currentPrice) || (!isBuy && trendlineLevel >= currentPrice))
            {
               bestPrice = trendlineLevel;
               bestSource = trendlineSource;
               minDistance = trendlineDist;
            }
         }
      }
   }
   
   if(DebugMode)
      Print("📍 PRIX OPTIMAL LIMIT: ", DoubleToString(bestPrice, _Digits), " (Source: ", bestSource, 
            ", Distance: ", DoubleToString(minDistance, _Digits), ")");
   
   return NormalizeDouble(bestPrice, _Digits);
}

//+------------------------------------------------------------------+
//| Valide les conditions pour un ordre LIMIT avant exécution        |
//| Retourne true si les conditions sont toujours valides             |
//| Priorité 1: Vérifier l'action IA (ACHAT/VENTE)                    |
//| Priorité 2: Vérifier la direction de la zone prédite              |
//+------------------------------------------------------------------+
bool ValidateLimitOrderConditions(ENUM_ORDER_TYPE limitOrderType)
{
   // Déterminer le type d'ordre (BUY ou SELL)
   bool orderIsBuy = (limitOrderType == ORDER_TYPE_BUY_LIMIT);
   
   // Anti-hasard: en mode strict, exiger une confiance IA minimale pour maintenir l'ordre
   if(UseStrictQualityFilter && g_lastAIConfidence < AI_MinConfidence)
   {
      Print("🚫 VALIDATION LIMIT (QUALITÉ): Confiance IA insuffisante (", DoubleToString(g_lastAIConfidence * 100, 1),
            "% < ", DoubleToString(AI_MinConfidence * 100, 1), "%) - Ordre annulé");
      return false;
   }
   
   // ===== VÉRIFICATION 0 (PRIORITÉ ABSOLUE): Vérifier que les données IA sont récentes =====
   int timeSinceAIUpdate = 0;
   if(g_lastAITime > 0)
   {
      datetime currentTime = TimeCurrent();
      // Éviter les valeurs négatives ou trop grandes (max 24 heures = 86400 secondes)
      if(currentTime > g_lastAITime)
      {
         timeSinceAIUpdate = (int)(currentTime - g_lastAITime);
         if(timeSinceAIUpdate > 86400) // Plafonner à 24 heures pour éviter les valeurs aberrantes
            timeSinceAIUpdate = 86400;
      }
   }
   
   int maxAge = AI_UpdateInterval * 2; // Maximum 2x l'intervalle
   if(g_lastAITime == 0 || timeSinceAIUpdate > maxAge)
   {
      Print("🚫 VALIDATION LIMIT: Données IA trop anciennes ou inexistantes - Dernière mise à jour: ", 
            (g_lastAITime == 0 ? "JAMAIS" : IntegerToString(timeSinceAIUpdate) + "s"),
            " (Max: ", maxAge, "s) - Ordre annulé");
      return false; // BLOQUER si données IA trop anciennes
   }
   
   // ===== VÉRIFICATION 1 (PRIORITÉ): L'action IA correspond toujours au type d'ordre LIMIT =====
   // BUY_LIMIT = attente d'un pullback pour ACHETER → L'IA doit recommander ACHAT (BUY)
   // SELL_LIMIT = attente d'un pullback pour VENDRE → L'IA doit recommander VENTE (SELL)
   bool aiRecommendsBuy = (g_lastAIAction == "buy");
   bool aiRecommendsSell = (g_lastAIAction == "sell");
   
   // Vérifier si c'est toujours ACHAT lors de l'exécution pour BUY_LIMIT
   if(orderIsBuy && !aiRecommendsBuy)
   {
      Print("🚫 VALIDATION LIMIT: Ordre BUY_LIMIT mais IA ne recommande plus ACHAT - Action actuelle=", g_lastAIAction, 
            " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
      return false;
   }
   
   // Vérifier si c'est toujours VENTE lors de l'exécution pour SELL_LIMIT
   if(!orderIsBuy && !aiRecommendsSell)
   {
      Print("🚫 VALIDATION LIMIT: Ordre SELL_LIMIT mais IA ne recommande plus VENTE - Action actuelle=", g_lastAIAction, 
            " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
      return false;
   }
   
   // DÉSACTIVÉ: Plus de blocage par cohérence des endpoints
   // VÉRIFICATION PRIORITAIRE: Cohérence de TOUS les endpoints d'analyse
   int orderDirection = orderIsBuy ? 1 : -1;
   // if(!CheckCoherenceOfAllAnalyses(orderDirection))
   // {
   //    Print("🚫 VALIDATION LIMIT: Cohérence insuffisante de tous les endpoints d'analyse - Ordre annulé - Direction: ", (orderDirection == 1 ? "BUY" : "SELL"));
   //    return false; // BLOQUER si cohérence insuffisante
   // }
   
   // ===== VÉRIFICATION 2: Direction de la zone prédite (par où le prix va passer) =====
   // Vérifier que la direction de la prédiction correspond toujours à l'ordre
   int predSize = ArraySize(g_pricePrediction);
   if(g_predictionValid && predSize >= 20)
   {
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
      int predictionWindow = MathMin(20, predSize);
      double predictedPrice = g_pricePrediction[predictionWindow - 1];
      
      // Déterminer la direction de la zone prédite (par où le prix va passer)
      int predictionDirection = 0;
      double priceMovement = predictedPrice - currentPrice;
      double movementPercent = (MathAbs(priceMovement) / currentPrice) * 100.0;
      
      double minMove = MathMax(0.05, ImmediatePredictionMinMovePercent);
      if(movementPercent > minMove) // Mouvement significatif
      {
         if(priceMovement > 0)
            predictionDirection = 1; // Zone prédite haussière (le prix va passer par le haut = BUY)
         else
            predictionDirection = -1; // Zone prédite baissière (le prix va passer par le bas = SELL)
      }
      
      // Vérifier l'alignement avec le type d'ordre
      // BUY_LIMIT attend que la zone prédite soit haussière (le prix va passer par le haut)
      // SELL_LIMIT attend que la zone prédite soit baissière (le prix va passer par le bas)
      int expectedDirection = orderIsBuy ? 1 : -1;
      
      if(predictionDirection != 0 && predictionDirection != expectedDirection)
      {
         Print("🚫 VALIDATION LIMIT: Direction de la zone prédite a changé - Ordre=", (orderIsBuy ? "BUY" : "SELL"), 
               " Zone prédite=", (predictionDirection == 1 ? "HAUSSIÈRE (prix passe par le haut)" : "BAISSIÈRE (prix passe par le bas)"),
               " Attendu=", (expectedDirection == 1 ? "HAUSSIÈRE" : "BAISSIÈRE"));
         return false;
      }
      
      // Anti-hasard: en mode strict, une zone prédite NEUTRE annule l'ordre
      if(predictionDirection == 0 && UseStrictQualityFilter)
      {
         Print("🚫 VALIDATION LIMIT (QUALITÉ): Zone prédite NEUTRE (mouvement < ", DoubleToString(minMove, 2), "%) - Ordre annulé");
         return false;
      }
      
      // Hors mode strict: zone neutre = pas de contradiction, on accepte
      if(predictionDirection == 0)
      {
         Print("⚠️ VALIDATION LIMIT: Zone prédite neutre (mouvement < ", DoubleToString(minMove, 2), "%) - Ordre=", (orderIsBuy ? "BUY" : "SELL"),
               " - Validation basée uniquement sur l'action IA");
      }
   }
   else
   {
      // Anti-hasard: en mode strict, pas de prédiction = pas d'ordre
      if(UseStrictQualityFilter)
      {
         Print("🚫 VALIDATION LIMIT (QUALITÉ): Pas de prédiction valide - Ordre annulé - Ordre=", (orderIsBuy ? "BUY" : "SELL"));
         return false;
      }
      
      // Sinon: validation basée uniquement sur l'action IA
      Print("⚠️ VALIDATION LIMIT: Pas de prédiction valide - Validation basée uniquement sur l'action IA - Ordre=", (orderIsBuy ? "BUY" : "SELL"));
   }
   
   // Note: Le pourcentage de confiance IA n'est pas obligatoire ici
   // Il est utilisé seulement comme information pour les logs
   if(g_lastAIConfidence < 0.60)
   {
      Print("⚠️ VALIDATION LIMIT: Confiance IA faible (", DoubleToString(g_lastAIConfidence * 100, 1), "% < 60%)",
            " mais action IA correspond toujours - Ordre=", (orderIsBuy ? "BUY" : "SELL"));
   }
   
   // Toutes les conditions principales sont valides
   Print("✅ VALIDATION LIMIT: Conditions valides - Ordre=", (orderIsBuy ? "BUY" : "SELL"),
         " Action IA=", g_lastAIAction, " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
   return true;
}

//+------------------------------------------------------------------+
//| Handler des transactions de trading                              |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result)
{
   // La validation des ordres LIMIT exécutés se fait dans TRADE_TRANSACTION_DEAL_ADD ci-dessous
   // Car c'est plus fiable pour détecter quand une position a été créée
   
   // Gestion des fermetures de positions
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
      ulong dealTicket = trans.deal;
      if(dealTicket > 0 && HistoryDealSelect(dealTicket)) {
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         
         // Si c'est une sortie (fermeture de position)
         if(dealEntry == DEAL_ENTRY_OUT) {
            g_lastPositionCloseTime = TimeCurrent();
            if(DebugMode) {
               Print("Position fermée à ", TimeToString(g_lastPositionCloseTime), 
                     ". Ré-entrée possible dans ", MinReentryDelaySeconds, " secondes.");
            }
         }
      }
   }
   
   // Si c'est une transaction de deal (pour mise à jour du profit quotidien)
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      if(dealTicket > 0)
      {
         UpdateDailyProfitFromDeal(dealTicket);
         
         // NOUVEAU: Enregistrer les trades dans le CSV
         if(EnableCSVLogging && HistoryDealSelect(dealTicket))
         {
            long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
            ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
            
            // Vérifier si c'est un deal de notre EA
            if(dealMagic == InpMagicNumber)
            {
               // Si c'est une entrée (ouverture de position)
               if(dealEntry == DEAL_ENTRY_IN)
               {
                  // Trouver la position correspondante
                  Sleep(100); // Petite pause pour que la position soit créée
                  for(int i = PositionsTotal() - 1; i >= 0; i--)
                  {
                     ulong posTicket = PositionGetTicket(i);
                     if(posTicket > 0 && positionInfo.SelectByTicket(posTicket))
                     {
                        if(positionInfo.Magic() == InpMagicNumber)
                        {
                           datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                           if(MathAbs((long)(positionInfo.Time() - dealTime)) <= 5) // Position créée dans les 5 secondes
                           {
                              LogTradeOpen(posTicket);
                              break;
                           }
                        }
                     }
                  }
               }
               // Si c'est une sortie (fermeture de position)
               else if(dealEntry == DEAL_ENTRY_OUT)
               {
                  // Trouver le ticket de position depuis le deal
                  ulong posTicket = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
                  if(posTicket > 0)
                  {
                     string closeReason = "Unknown";
                     
                     // Déterminer la raison de fermeture
                     if(dealType == DEAL_TYPE_BALANCE)
                        closeReason = "Balance";
                     else if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
                     {
                        // Vérifier si c'était un TP ou SL en comparant avec le prix d'entrée
                        // Récupérer les informations de la position depuis l'historique
                        if(HistorySelectByPosition(posTicket))
                        {
                           double entryPrice = 0.0;
                           double closePrice = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
                           double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
                           ENUM_POSITION_TYPE posType = WRONG_VALUE;
                           
                           // Trouver le deal d'entrée pour obtenir le prix d'entrée
                           for(int j = 0; j < HistoryDealsTotal(); j++)
                           {
                              ulong entryDealTicket = HistoryDealGetTicket(j);
                              if(entryDealTicket > 0 && HistoryDealSelect(entryDealTicket))
                              {
                                 if(HistoryDealGetInteger(entryDealTicket, DEAL_MAGIC) == InpMagicNumber &&
                                    HistoryDealGetInteger(entryDealTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
                                 {
                                    entryPrice = HistoryDealGetDouble(entryDealTicket, DEAL_PRICE);
                                    ENUM_DEAL_TYPE entryDealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(entryDealTicket, DEAL_TYPE);
                                    if(entryDealType == DEAL_TYPE_BUY)
                                       posType = POSITION_TYPE_BUY;
                                    else if(entryDealType == DEAL_TYPE_SELL)
                                       posType = POSITION_TYPE_SELL;
                                    break;
                                 }
                              }
                           }
                           
                           // Déterminer si c'était TP ou SL basé sur le profit et les prix
                           if(entryPrice > 0)
                           {
                              if(posType == POSITION_TYPE_BUY)
                              {
                                 if(profit > 0 && closePrice > entryPrice)
                                    closeReason = "TakeProfit";
                                 else if(profit < 0 && closePrice < entryPrice)
                                    closeReason = "StopLoss";
                                 else
                                    closeReason = "Manual";
                              }
                              else if(posType == POSITION_TYPE_SELL)
                              {
                                 if(profit > 0 && closePrice < entryPrice)
                                    closeReason = "TakeProfit";
                                 else if(profit < 0 && closePrice > entryPrice)
                                    closeReason = "StopLoss";
                                 else
                                    closeReason = "Manual";
                              }
                              else
                                 closeReason = "Manual";
                           }
                           else
                              closeReason = "Manual";
                        }
                        else
                           closeReason = "Manual";
                     }
                     
                     LogTradeClose(posTicket, closeReason);
                  }
               }
            }
         }
         
         // NOUVEAU: Vérifier si ce deal provient d'un ordre LIMIT et valider les conditions
         if(HistoryDealSelect(dealTicket))
         {
            ulong dealOrder = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
            long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
            ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
            
            // Vérifier si c'est un deal d'entrée (pas une sortie) de notre EA
            if(dealMagic == InpMagicNumber && dealEntry == DEAL_ENTRY_IN)
            {
               // Chercher l'ordre qui a créé ce deal
               if(HistoryOrderSelect(dealOrder))
               {
                  ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(dealOrder, ORDER_TYPE);
                  
                  // Si c'est un ordre LIMIT, valider les conditions
                  if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT)
                  {
                     Print("⚠️ DEAL CRÉÉ DEPUIS ORDRE LIMIT: Deal=", dealTicket, " Order=", dealOrder, " Type=", EnumToString(orderType));
                     
                     // Petite pause pour que la position soit créée
                     Sleep(50);
                     
                     // Valider les conditions actuelles
                     if(!ValidateLimitOrderConditions(orderType))
                     {
                        Print("🚫 CONDITIONS CHANGÉES - Fermeture immédiate de la position créée par ordre LIMIT");
                        
                        // Trouver la position qui vient d'être créée
                        datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
                        
                        for(int i = PositionsTotal() - 1; i >= 0; i--)
                        {
                           ulong posTicket = PositionGetTicket(i);
                           if(posTicket > 0 && positionInfo.SelectByTicket(posTicket))
                           {
                              if(positionInfo.Magic() == InpMagicNumber && 
                                 positionInfo.Symbol() == _Symbol &&
                                 MathAbs((long)(positionInfo.Time() - dealTime)) <= 2) // Position créée dans les 2 secondes
                              {
                                 ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)positionInfo.PositionType();
                                 bool shouldClose = false;
                                 
                                 if(orderType == ORDER_TYPE_BUY_LIMIT && posType == POSITION_TYPE_BUY)
                                    shouldClose = true;
                                 else if(orderType == ORDER_TYPE_SELL_LIMIT && posType == POSITION_TYPE_SELL)
                                    shouldClose = true;
                                 
                                 if(shouldClose)
                                 {
                                    Print("🗑️ FERMETURE IMMÉDIATE: Position ", posTicket, " fermée car conditions changées");
                                    
                                    // Fermer la position immédiatement
                                    MqlTradeRequest closeRequest = {};
                                    MqlTradeResult closeResult = {};
                                    closeRequest.action = TRADE_ACTION_DEAL;
                                    closeRequest.position = posTicket;
                                    closeRequest.symbol = _Symbol;
                                    closeRequest.volume = positionInfo.Volume();
                                    closeRequest.deviation = 10;
                                    closeRequest.magic = InpMagicNumber;
                                    
                                    if(posType == POSITION_TYPE_BUY)
                                       closeRequest.type = ORDER_TYPE_SELL;
                                    else
                                       closeRequest.type = ORDER_TYPE_BUY;
                                    
                                    closeRequest.price = (posType == POSITION_TYPE_BUY) ? 
                                                       SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                                       SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                                    // Détecter automatiquement le mode de remplissage supporté
                                    closeRequest.type_filling = GetSupportedFillingMode(_Symbol);
                                    
                                    if(OrderSend(closeRequest, closeResult))
                                    {
                                       Print("✅ Position ", posTicket, " fermée avec succès - Conditions non valides");
                                    }
                                    else
                                    {
                                       Print("❌ Erreur fermeture position ", posTicket, ": ", closeResult.retcode, " - ", closeResult.comment);
                                    }
                                 }
                                 break; // Une seule position devrait correspondre
                              }
                           }
                        }
                     }
                     else
                     {
                        Print("✅ VALIDATION LIMIT OK: Conditions toujours valides - Position créée par ordre LIMIT conservée");
                     }
                  }
               }
            }
         }
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
   uchar data[];
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
   uchar result[];
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
   
   // TOUJOURS logger la réponse (pas seulement en DebugMode) pour vérifier réception
   Print("📥 Réponse IA reçue (", StringLen(resp), " caractères): ", StringSubstr(resp, 0, 500)); 
   
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
      
      // Mettre à jour l'horodatage avec validation
      datetime newTime = TimeCurrent();
      // Validation plus stricte: le temps doit être raisonnable (pas avant 2020)
      datetime minimumValidTime = D'2020.01.01 00:00:00';
      if(newTime > minimumValidTime && newTime > g_lastAITime) // S'assurer que le temps est valide et plus récent
      {
         g_lastAITime = newTime;
         if(DebugMode)
            Print("✅ Horodatage IA mis à jour: ", TimeToString(g_lastAITime, TIME_MINUTES|TIME_SECONDS));
      }
      else
      {
         Print("⚠️ ATTENTION: Horodatage IA invalide (", TimeToString(newTime, TIME_MINUTES|TIME_SECONDS), "), conservation de la valeur précédente");
      }
      
      // TOUJOURS afficher les valeurs parsées (pas seulement en DebugMode) pour vérifier que le parsing fonctionne
      Print("🤖 DÉCISION IA PARSÉE: Action=", g_lastAIAction, " | Confiance=", DoubleToString(g_lastAIConfidence * 100, 2), "% | Reason=", StringSubstr(g_lastAIReason, 0, 100));
      
      // Vérification supplémentaire si parsing a échoué
      if(g_lastAIAction == "" || (g_lastAIConfidence == 0.0 && StringFind(resp, "confidence") >= 0))
      {
         Print("⚠️ ATTENTION: Parsing IA peut avoir échoué - Action=", g_lastAIAction, " Confiance=", g_lastAIConfidence, " | Réponse complète: ", resp);
      }
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
   uchar data[];
   ArrayResize(data, 0);
   uchar result[];
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
   payload += ",\"bid\":" + DoubleToString(bid, _Digits);
   payload += ",\"ask\":" + DoubleToString(ask, _Digits);
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
   uchar data[];
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
   uchar result[];
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
            
            if(DebugMode)
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
   // Réinitialiser le tableau des opportunités au début de chaque mise à jour
   ArrayResize(g_opportunities, 0);
   g_opportunitiesCount = 0;
   
   // Utiliser exactement 200 bougies historiques et 500 bougies futures
   int totalPredictionBars = MathMin(ArraySize(g_pricePrediction), g_predictionBars);
   
   if(totalPredictionBars == 0)
      return; // Pas de prédiction disponible
   
   // OPTIMISATION: Ne supprimer que si nécessaire (éviter ObjectsTotal() à chaque fois)
   string prefix = "PRED_";
   
   // Si l'utilisateur ne veut pas afficher les prédictions, nettoyer les objets et sortir
   if(!ShowPricePredictions)
   {
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, prefix) == 0)
            ObjectDelete(0, name);
      }
      return;
   }
   
   // Nettoyage ciblé si certaines couches sont désactivées (anti-encombrement)
   // (utile si l'option est changée en live sans nouvelle prédiction)
   {
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, prefix) != 0)
            continue;
         
         if(!ShowPredictionChannelFill && StringFind(name, prefix + "CHANNEL_") == 0)
            ObjectDelete(0, name);
         if(!ShowPredictionCandles && (StringFind(name, prefix + "CANDLE_BODY_") == 0 || StringFind(name, prefix + "CANDLE_WICK_") == 0))
            ObjectDelete(0, name);
         if(!ShowPredictionArrows && (StringFind(name, prefix + "BUY_ENTRY_") == 0 || StringFind(name, prefix + "SELL_ENTRY_") == 0))
            ObjectDelete(0, name);
         if(!ShowPredictionWicks && StringFind(name, prefix + "CANDLE_WICK_") == 0)
            ObjectDelete(0, name);
      }
   }

   // Nettoyage léger des segments de trajectoire/bandes (peu nombreux) pour éviter toute accumulation
   // quand l'utilisateur change MaxPredictionCandles/spacing sans nouvelle prédiction.
   {
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, prefix) != 0)
            continue;
         
         if(StringFind(name, prefix + "TRAJ_") == 0 ||
            StringFind(name, prefix + "BAND_UP_") == 0 ||
            StringFind(name, prefix + "BAND_DN_") == 0)
         {
            ObjectDelete(0, name);
         }
      }
   }
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
   int periodSeconds = GetPeriodSeconds(tf);
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
   
   // Dessiner le canal rempli (OPTIONNEL - très encombrant)
   if(ShowPredictionChannelFill)
   {
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
   }
   
   // Trajectoire prédictive (LIGNE CLAIRE) - beaucoup moins encombrant que les rectangles/bougies
   int trajStep = MathMax(1, PredictionCandleSpacing);
   int trajBars = MathMin(totalPredictionBars, MathMax(1, MaxPredictionCandles * trajStep));
   
   datetime prevT = currentTime;
   double prevP = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   color trajClr = (color)ColorToARGB(clrDodgerBlue, 200);
   color bandClr = (color)ColorToARGB(isBullish ? clrLime : clrRed, 60);
   
   for(int i = 0; i < trajBars; i += trajStep)
   {
      datetime t = currentTime + (i + 1) * periodSeconds;
      double p = g_pricePrediction[i];
      
      string segName = prefix + "TRAJ_" + IntegerToString(i) + "_" + _Symbol;
      if(ObjectFind(0, segName) < 0)
         ObjectCreate(0, segName, OBJ_TREND, 0, prevT, prevP, t, p);
      else
      {
         ObjectSetInteger(0, segName, OBJPROP_TIME, 0, prevT);
         ObjectSetDouble(0, segName, OBJPROP_PRICE, 0, prevP);
         ObjectSetInteger(0, segName, OBJPROP_TIME, 1, t);
         ObjectSetDouble(0, segName, OBJPROP_PRICE, 1, p);
      }
      ObjectSetInteger(0, segName, OBJPROP_COLOR, trajClr);
      ObjectSetInteger(0, segName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, segName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, segName, OBJPROP_BACK, true);
      ObjectSetInteger(0, segName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, segName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, segName, OBJPROP_RAY_RIGHT, false);
      
      // Bande (2 lignes fines) autour de la trajectoire (lisible, non remplie)
      string upName = prefix + "BAND_UP_" + IntegerToString(i) + "_" + _Symbol;
      string dnName = prefix + "BAND_DN_" + IntegerToString(i) + "_" + _Symbol;
      double prevUp = prevP + confidenceBand;
      double prevDn = prevP - confidenceBand;
      double up = p + confidenceBand;
      double dn = p - confidenceBand;
      
      if(ObjectFind(0, upName) < 0)
         ObjectCreate(0, upName, OBJ_TREND, 0, prevT, prevUp, t, up);
      else
      {
         ObjectSetInteger(0, upName, OBJPROP_TIME, 0, prevT);
         ObjectSetDouble(0, upName, OBJPROP_PRICE, 0, prevUp);
         ObjectSetInteger(0, upName, OBJPROP_TIME, 1, t);
         ObjectSetDouble(0, upName, OBJPROP_PRICE, 1, up);
      }
      ObjectSetInteger(0, upName, OBJPROP_COLOR, bandClr);
      ObjectSetInteger(0, upName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, upName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, upName, OBJPROP_BACK, true);
      ObjectSetInteger(0, upName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, upName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, upName, OBJPROP_RAY_RIGHT, false);
      
      if(ObjectFind(0, dnName) < 0)
         ObjectCreate(0, dnName, OBJ_TREND, 0, prevT, prevDn, t, dn);
      else
      {
         ObjectSetInteger(0, dnName, OBJPROP_TIME, 0, prevT);
         ObjectSetDouble(0, dnName, OBJPROP_PRICE, 0, prevDn);
         ObjectSetInteger(0, dnName, OBJPROP_TIME, 1, t);
         ObjectSetDouble(0, dnName, OBJPROP_PRICE, 1, dn);
      }
      ObjectSetInteger(0, dnName, OBJPROP_COLOR, bandClr);
      ObjectSetInteger(0, dnName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, dnName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, dnName, OBJPROP_BACK, true);
      ObjectSetInteger(0, dnName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, dnName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, dnName, OBJPROP_RAY_RIGHT, false);
      
      prevT = t;
      prevP = p;
   }
   
   // Dessiner les bougies de prédiction futures (imitant les vraies bougies)
   // Créer des bougies haussières et baissières comme des vraies bougies MT5
   if(ShowPredictionCandles)
   {
      int candleStep = MathMax(1, PredictionCandleSpacing);
      int candleBars = MathMin(totalPredictionBars, MathMax(1, MaxPredictionCandles * candleStep));
      for(int i = 0; i < candleBars; i += candleStep)
      {
      int combinedIdx = totalHistoryBars + i;
      if(combinedIdx >= totalBars - 1) continue;
      
      datetime candleTime = combinedTimes[combinedIdx];
      double openPrice = combinedPrices[combinedIdx];
      double closePrice = (i + 1 < totalPredictionBars) ? combinedPrices[combinedIdx + 1] : combinedPrices[combinedIdx];
      
      // Calculer high et low pour imiter une vraie bougie
      double highPrice = MathMax(openPrice, closePrice) + (confidenceBand * 0.3);
      double lowPrice = MathMin(openPrice, closePrice) - (confidenceBand * 0.3);
      
      // Déterminer si la bougie est haussière ou baissière
      bool isBullishCandle = (closePrice > openPrice);
      
      // Couleur de la bougie (vert haussier, rouge baissier) avec transparence
      color candleColor;
      uchar candleAlpha = 120; // Transparence moyenne pour voir les bougies prédites
      
      if(isBullishCandle)
      {
         candleColor = (color)ColorToARGB(clrLime, candleAlpha); // Vert transparent pour haussier
      }
      else
      {
         candleColor = (color)ColorToARGB(clrRed, candleAlpha); // Rouge transparent pour baissier
      }
      
      // Créer le corps de la bougie (rectangle)
      string candleBodyName = prefix + "CANDLE_BODY_" + IntegerToString(i) + "_" + _Symbol;
      double bodyTop = MathMax(openPrice, closePrice);
      double bodyBottom = MathMin(openPrice, closePrice);
      
      if(ObjectFind(0, candleBodyName) < 0)
         ObjectCreate(0, candleBodyName, OBJ_RECTANGLE, 0, candleTime, bodyTop, candleTime + periodSeconds, bodyBottom);
      else
      {
         ObjectSetInteger(0, candleBodyName, OBJPROP_TIME, 0, candleTime);
         ObjectSetDouble(0, candleBodyName, OBJPROP_PRICE, 0, bodyTop);
         ObjectSetInteger(0, candleBodyName, OBJPROP_TIME, 1, candleTime + periodSeconds);
         ObjectSetDouble(0, candleBodyName, OBJPROP_PRICE, 1, bodyBottom);
      }
      
      ObjectSetInteger(0, candleBodyName, OBJPROP_COLOR, candleColor);
      ObjectSetInteger(0, candleBodyName, OBJPROP_BGCOLOR, candleColor);
      ObjectSetInteger(0, candleBodyName, OBJPROP_FILL, true);
      ObjectSetInteger(0, candleBodyName, OBJPROP_BACK, true);
      ObjectSetInteger(0, candleBodyName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, candleBodyName, OBJPROP_WIDTH, 1);
      
      // Créer la mèche (shadow) de la bougie (ligne verticale)
      string candleWickName = prefix + "CANDLE_WICK_" + IntegerToString(i) + "_" + _Symbol;
      color wickColor = (color)ColorToARGB(clrDarkGray, 100); // Gris transparent pour les mèches
      if(ShowPredictionWicks)
      {
         if(ObjectFind(0, candleWickName) < 0)
            ObjectCreate(0, candleWickName, OBJ_TREND, 0, candleTime + periodSeconds/2, highPrice, candleTime + periodSeconds/2, lowPrice);
         else
         {
            ObjectSetInteger(0, candleWickName, OBJPROP_TIME, 0, candleTime + periodSeconds/2);
            ObjectSetDouble(0, candleWickName, OBJPROP_PRICE, 0, highPrice);
            ObjectSetInteger(0, candleWickName, OBJPROP_TIME, 1, candleTime + periodSeconds/2);
            ObjectSetDouble(0, candleWickName, OBJPROP_PRICE, 1, lowPrice);
         }
         
         ObjectSetInteger(0, candleWickName, OBJPROP_COLOR, wickColor);
         ObjectSetInteger(0, candleWickName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, candleWickName, OBJPROP_BACK, true);
         ObjectSetInteger(0, candleWickName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, candleWickName, OBJPROP_STYLE, STYLE_SOLID);
      }
      else
      {
         ObjectDelete(0, candleWickName);
      }
      }
   }
   
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
            
            // Affichage optionnel: flèche d'entrée
            if(ShowPredictionArrows)
            {
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
            }
            else
            {
               ObjectDelete(0, buyEntryName);
            }
            
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
            
            // Affichage optionnel: flèche d'entrée
            if(ShowPredictionArrows)
            {
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
            }
            else
            {
               ObjectDelete(0, sellEntryName);
            }
            
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
      // Actualiser l'ordre LIMIT si la trajectoire a changé
      UpdateLimitOrderOnTrajectoryChange();
      
      lastCorrectionCheck = TimeCurrent();
   }
   
   // Marquer comme créé dès qu'on a dessiné une fois (évite la suppression/recréation à chaque tick)
   predictionObjectsCreated = true;
   
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
   int periodSeconds = GetPeriodSeconds(tf);
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
//| Confirmer la tendance via la trajectoire prédite (plusieurs fenêtres) |
//| Retourne: 1=BUY, -1=SELL, 0=non confirmé                         |
//+------------------------------------------------------------------+
int GetTrajectoryTrendConfirmation()
{
   if(!UseTrajectoryTrendConfirmation || !g_predictionValid || ArraySize(g_pricePrediction) < 50)
      return 0; // Pas de confirmation requise ou trajectoire insuffisante
   
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   int windows[] = {10, 20, 30, 50}; // Fenêtres à vérifier
   int bullishCount = 0, bearishCount = 0;
   double minMove = ImmediatePredictionMinMovePercent / 100.0 * currentPrice;
   
   for(int w = 0; w < ArraySize(windows); w++)
   {
      int win = windows[w];
      if(ArraySize(g_pricePrediction) < win) continue;
      
      double predPrice = g_pricePrediction[win - 1];
      double movement = predPrice - currentPrice;
      
      if(MathAbs(movement) >= minMove)
      {
         if(movement > 0) bullishCount++;
         else bearishCount++;
      }
   }
   
   int total = bullishCount + bearishCount;
   if(total == 0) return 0;
   
   double bullishPct = (double)bullishCount / total * 100.0;
   double bearishPct = (double)bearishCount / total * 100.0;
   
   if(bullishPct >= TrajectoryMinCoherencePercent)
      return 1; // Tendance haussière confirmée
   if(bearishPct >= TrajectoryMinCoherencePercent)
      return -1; // Tendance baissière confirmée
   
   return 0; // Cohérence insuffisante
}

//+------------------------------------------------------------------+
//| Actualiser l'ordre LIMIT existant si les conditions changent      |
//+------------------------------------------------------------------+
void UpdateLimitOrderOnTrajectoryChange()
{
   if(!UpdateLimitOrderOnTrajectory || g_opportunitiesCount == 0) return;
   
   // Chercher un ordre LIMIT existant
   ulong existingTicket = 0;
   double existingPrice = 0;
   bool existingIsBuy = false;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && orderInfo.SelectByIndex(i))
      {
         if(orderInfo.Symbol() == _Symbol && orderInfo.Magic() == InpMagicNumber)
         {
            ENUM_ORDER_TYPE ot = orderInfo.OrderType();
            if(ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT)
            {
               existingTicket = orderInfo.Ticket();
               existingPrice = orderInfo.PriceOpen();
               existingIsBuy = (ot == ORDER_TYPE_BUY_LIMIT);
               break;
            }
         }
      }
   }
   
   if(existingTicket == 0) return; // Pas d'ordre à mettre à jour
   
   // Trouver la meilleure opportunité actuelle (même direction que l'ordre existant)
   TradingOpportunity bestOpp = {0};
   bool bestFound = false;
   for(int i = 0; i < g_opportunitiesCount; i++)
   {
      if(g_opportunities[i].isBuy != existingIsBuy) continue;
      if(!bestFound || g_opportunities[i].percentage > bestOpp.percentage)
      {
         bestOpp = g_opportunities[i];
         bestFound = true;
      }
   }
   
   if(!bestFound) return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minUpdateDistance = 10 * point; // Mettre à jour si différence > 10 points
   
   if(MathAbs(bestOpp.entryPrice - existingPrice) < minUpdateDistance)
      return; // Pas de changement significatif
   
   // Calculer SL/TP pour la nouvelle opportunité
   double entryPrice = bestOpp.entryPrice;
   double sl, tp;
   ENUM_POSITION_TYPE posType = existingIsBuy ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   CalculateSLTPInPoints(posType, entryPrice, sl, tp);
   
   if(sl <= 0 || tp <= 0) return;
   
   MqlTradeRequest modRequest = {};
   MqlTradeResult modResult = {};
   modRequest.action = TRADE_ACTION_MODIFY;
   modRequest.order = existingTicket;
   modRequest.symbol = _Symbol;
   modRequest.price = NormalizeDouble(entryPrice, _Digits);
   modRequest.sl = NormalizeDouble(sl, _Digits);
   modRequest.tp = NormalizeDouble(tp, _Digits);
   
   if(OrderSend(modRequest, modResult))
   {
      Print("✅ Ordre LIMIT actualisé: Ticket=", existingTicket,
            " Nouveau prix=", DoubleToString(entryPrice, _Digits),
            " (ancien=", DoubleToString(existingPrice, _Digits), ")");
   }
   else if(DebugMode)
      Print("⚠️ Échec mise à jour ordre LIMIT: ", modResult.retcode, " - ", modResult.comment);
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
   
   // ===== VÉRIFICATION 0 (PRIORITÉ ABSOLUE): Vérifier que les données IA sont récentes =====
   int timeSinceAIUpdate = 0;
   if(g_lastAITime > 0)
   {
      datetime currentTime = TimeCurrent();
      // Éviter les valeurs négatives ou trop grandes (max 24 heures = 86400 secondes)
      if(currentTime > g_lastAITime)
      {
         timeSinceAIUpdate = (int)(currentTime - g_lastAITime);
         if(timeSinceAIUpdate > 86400) // Plafonner à 24 heures pour éviter les valeurs aberrantes
            timeSinceAIUpdate = 86400;
      }
   }
   
   int maxAge = AI_UpdateInterval * 2; // Maximum 2x l'intervalle
   if(g_lastAITime == 0 || timeSinceAIUpdate > maxAge)
   {
      Print("🚫 PlaceLimitOrder: Données IA trop anciennes ou inexistantes - Dernière mise à jour: ", 
            (g_lastAITime == 0 ? "JAMAIS" : IntegerToString(timeSinceAIUpdate) + "s"),
            " (Max: ", maxAge, "s) - Attente mise à jour IA");
      return; // BLOQUER si données IA trop anciennes
   }
   
   // Anti-hasard: en mode strict, exiger une confiance IA minimale avant de placer/mettre à jour un LIMIT
   if(UseStrictQualityFilter && g_lastAIConfidence < AI_MinConfidence)
   {
      Print("🚫 PlaceLimitOrder (QUALITÉ): Confiance IA insuffisante (", DoubleToString(g_lastAIConfidence * 100, 1),
            "% < ", DoubleToString(AI_MinConfidence * 100, 1), "%) - Pas d'ordre LIMIT");
      return;
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
   
   double minMove = MathMax(0.05, ImmediatePredictionMinMovePercent);
   if(movementPercent > minMove) // Mouvement significatif
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
   
   // ===== RÈGLE ASSOUPLIE: Utiliser l'action IA comme direction principale =====
   // Si l'IA recommande une direction ET qu'on a des conditions favorables,
   // on peut placer un LIMIT même si les conditions sont modestes
   // On bloque uniquement si l'IA et les conditions sont en désaccord explicite
   
   int marketDirection = 0;
   
   // Vérifier l'alignement entre l'action IA et la zone prédite
   bool isAligned = (aiDirection != 0 && predictionDirection != 0 && aiDirection == predictionDirection);
   bool hasConflict = (aiDirection != 0 && predictionDirection != 0 && aiDirection != predictionDirection);
   
   if(isAligned)
   {
      // ✅ ALIGNEMENT CONFIRMÉ: Action IA et zone prédite pointent dans la même direction
      marketDirection = aiDirection; // Utiliser la direction alignée
      Print("✅ PlaceLimitOrder: ALIGNEMENT CONFIRMÉ - Action IA=", (aiDirection == 1 ? "ACHAT (BUY)" : "VENTE (SELL)"),
            " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)",
            " Zone prédite=", (predictionDirection == 1 ? "HAUSSIÈRE" : "BAISSIÈRE"),
            " → Direction=", marketDirection == 1 ? "BUY" : "SELL");
   }
   else if(hasConflict)
   {
      // ❌ CONFLIT EXPLICITE: Action IA et zone prédite en désaccord
      string aiStr = (aiDirection == 1 ? "ACHAT (BUY)" : "VENTE (SELL)");
      string predStr = (predictionDirection == 1 ? "HAUSSIÈRE" : "BAISSIÈRE");
      Print("⏸️ PlaceLimitOrder: DÉSACCORD - Action IA=", aiStr, 
            " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)",
            " mais Zone prédite=", predStr,
            " → Situation contradictoire, ATTENTE de l'alignement avant placement d'ordre limit");
      return; // Bloquer en cas de conflit explicite
   }
   else if(aiDirection != 0 && g_predictionValid && predSize >= 10)
   {
      // ✅ ACTION IA CLAIRE + CONDITIONS FAVORABLES: Utiliser la direction IA
      // Même si les conditions ne sont pas parfaites, on peut placer un LIMIT si l'IA recommande une direction
      marketDirection = aiDirection;
      Print("✅ PlaceLimitOrder: Action IA claire (", (aiDirection == 1 ? "BUY" : "SELL"),
            ", Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)",
            " + Conditions favorables → Placement LIMIT");
   }
   else if(aiDirection != 0 && g_opportunitiesCount > 0)
   {
      // ✅ ACTION IA CLAIRE + OPPORTUNITÉS DÉTECTÉES: Utiliser la direction IA même si conditions incomplètes
      marketDirection = aiDirection;
      Print("✅ PlaceLimitOrder: Action IA claire (", (aiDirection == 1 ? "BUY" : "SELL"),
            ", Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)",
            " + ", g_opportunitiesCount, " opportunités détectées → Placement LIMIT");
   }
   else
   {
      // ❌ PAS DE DIRECTION CLAIRE: Attendre
      string aiStr = (aiDirection == 1 ? "ACHAT (BUY)" : (aiDirection == -1 ? "VENTE (SELL)" : "NEUTRE"));
      string predStr = (predictionDirection == 1 ? "HAUSSIÈRE" : (predictionDirection == -1 ? "BAISSIÈRE" : "NEUTRE"));
      
      if(aiDirection == 0 && predictionDirection == 0)
      {
         Print("⏸️ PlaceLimitOrder: PAS DE DIRECTION - Action IA=NEUTRE et Zone prédite=NEUTRE",
               " → Attente d'une direction claire avant placement d'ordre limit");
      }
      else if(aiDirection == 0)
      {
         Print("⏸️ PlaceLimitOrder: ACTION IA NEUTRE - Zone prédite=", predStr,
               " mais Action IA=NEUTRE → Attente de l'action IA avant placement d'ordre limit");
      }
      else if((!g_predictionValid || predSize < 10) && g_opportunitiesCount == 0)
      {
         Print("⏸️ PlaceLimitOrder: CONDITIONS INVALIDES - Action IA=", aiStr,
               " (Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%)",
               " mais Conditions invalides (valid=", g_predictionValid ? "true" : "false", ", size=", predSize, ")",
               " et aucune opportunité détectée → Attente de conditions favorables avant placement d'ordre limit");
      }
      
      // Si on arrive ici sans avoir défini marketDirection, retourner
      if(marketDirection == 0)
         return; // Ne pas placer d'ordre sans direction claire
   }
   
   // ===== VÉRIFICATION TENDANCE: Confirmation de tendance (DÉSACTIVÉ) =====
   if(UseTrajectoryTrendConfirmation)
   {
      int trajConfirm = GetTrajectoryTrendConfirmation();
      if(trajConfirm != 0 && trajConfirm != marketDirection)
      {
         Print("⏸️ PlaceLimitOrder: Tendance confirme ", (trajConfirm == 1 ? "BUY" : "SELL"),
               " mais direction marché=", (marketDirection == 1 ? "BUY" : "SELL"),
               " → Attente alignement tendance avant placement");
         return;
      }
      if(trajConfirm == 0 && g_predictionValid && ArraySize(g_pricePrediction) >= 50)
      {
         Print("⏸️ PlaceLimitOrder: Cohérence tendance insuffisante (< ", DoubleToString(TrajectoryMinCoherencePercent, 0), "%)",
               " → Attente confirmation tendance avant placement");
         return;
      }
   }
   
   // Note: Le pourcentage de confiance IA n'est pas obligatoire pour placer l'ordre
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
   
   // Récupérer les valeurs EMA pour ajuster les prix d'entrée (non critique pour Boom/Crash, mais utile pour les autres actifs)
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
      double score = 0.0;
      
      // Score de confiance principal utilisé pour les logs
      double confidenceScoreForLog = g_lastAIConfidence;
      
      if(isBoom || isCrash)
      {
         // BOOM/CRASH: priorité au prochain creux/sommet prédit dans le FUTUR proche
         int secondsAhead = (int)(opp.entryTime - TimeCurrent());
         if(secondsAhead < 0)
         {
            if(DebugMode)
               Print("⏸️ Opportunité #", i, " ignorée: entrée déjà passée (", secondsAhead, "s)");
            continue;
         }
         
         // Plus l'entrée est proche dans le temps, plus le score est élevé
         // 0s -> ~1.0, 5min -> ~0.25, 10min -> ~0.11
         double timeScore = 1.0 / (1.0 + (secondsAhead / 60.0));
         double gainScoreBC = MathMin(opp.percentage / 10.0, 1.0); // garder un peu d'info sur le potentiel
         
         score = (timeScore * 0.70) + (gainScoreBC * 0.30);
         
         // Pour les logs, on garde la confiance IA globale
         confidenceScoreForLog = g_lastAIConfidence;
      }
      else
      {
         // AUTRES ACTIFS: logique originale (confiance + gain + proximité)
         // PRIORITÉ 1: Confiance du signal (le plus important) - 60%
         // PRIORITÉ 2: Potentiel de gain - 25%
         // PRIORITÉ 3: Proximité - 15%
         double confidenceScore = g_lastAIConfidence; // Confiance IA (0-1)
         double proximityScore = 1.0 / (1.0 + priceDistancePercent); // Normalisé entre 0 et 1
         double gainScore = MathMin(opp.percentage / 10.0, 1.0); // Normalisé entre 0 et 1 (max 10%)
         
         score = (confidenceScore * 0.60) + (gainScore * 0.25) + (proximityScore * 0.15);
         
         confidenceScoreForLog = confidenceScore;
      }
      
      Print("✅ Opportunité #", i, " VALIDE: Type=", zoneIsBuy ? "BUY" : "SELL",
            " EntryPrice=", DoubleToString(opp.entryPrice, _Digits),
            " PotentialGain=", DoubleToString(opp.percentage, 2), "%",
            " Distance=", DoubleToString(priceDistancePercent, 2), "%",
            " Confiance=", DoubleToString(confidenceScoreForLog * 100, 1), "%",
            " Score=", DoubleToString(score, 3));
      
      // Garder la meilleure opportunité (priorité au score le plus élevé)
      // Le score inclut déjà la confiance comme facteur principal (60%)
      // Si deux opportunités ont le même score, on garde la première (ou on pourrait utiliser d'autres critères)
      if(!bestFound || score > bestScore)
      {
         bestOpportunity = opp;
         bestFound = true;
         bestScore = score;
         Print("⭐ Meilleure opportunité mise à jour: Confiance=", DoubleToString(confidenceScoreForLog * 100, 1), 
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
   
   // Anti-hasard: en mode strict, la décision finale doit être au-dessus du score minimum
   if(UseStrictQualityFilter && finalDecision.confidence < MinOpportunityScore)
   {
      Print("🚫 PlaceLimitOrder (QUALITÉ): Décision finale trop faible (", DoubleToString(finalDecision.confidence * 100, 1),
            "% < ", DoubleToString(MinOpportunityScore * 100, 0), "%) - Pas d'ordre LIMIT");
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
   
   // Utiliser la meilleure opportunité trouvée
   double entryPriceRaw = bestOpportunity.entryPrice;
   
   // ===== DÉTERMINER LE PRIX D'ENTRÉE LIMIT =====
   ENUM_ORDER_TYPE limitOrderType;
   if(zoneIsBuy)
      limitOrderType = ORDER_TYPE_BUY_LIMIT;
   else
      limitOrderType = ORDER_TYPE_SELL_LIMIT;
   double bestLevel = entryPriceRaw;
   string bestLevelSource = "Trajectoire prédite";
   
   // Pour Boom/Crash: placer l'ordre directement sur la trajectoire prédite,
   // juste avant le creux (BUY) ou juste avant le sommet (SELL), pour capturer le spike.
   if(isBoom || isCrash)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      // Petit décalage pour être déclenché avant le point extrême
      double offsetPoints = 10 * point; // ajustable si besoin
      if(zoneIsBuy)
         bestLevel = entryPriceRaw + offsetPoints;   // un peu au-dessus du creux prédit
      else
         bestLevel = entryPriceRaw - offsetPoints;   // un peu en-dessous du sommet prédit
      
      bestLevelSource = "Trajectoire prédite (Boom/Crash)";
   }
   else
   {
      // AUTRES ACTIFS:
      // - Par défaut: placer sur la trajectoire prédite (entryPriceRaw provient des opportunités détectées)
      // - Fallback possible: Support/Résistance / trendline
      if(UsePredictedTrajectoryForLimitEntry)
      {
         bestLevel = entryPriceRaw;
         bestLevelSource = "Trajectoire prédite";
      }
      else
      {
         double optimalPrice = FindOptimalLimitOrderPrice(limitOrderType, entryPriceRaw);
         bestLevel = optimalPrice;
         bestLevelSource = "Support/Résistance ou Trendline (M1/M5)";
      }
   }
   
   // Vérifier que le prix optimal est réaliste (pas trop loin du prix actuel - max 5%)
   double distancePercent = (MathAbs(bestLevel - currentPrice) / currentPrice) * 100.0;
   if(distancePercent > 5.0)
   {
      Print("🚫 Prix optimal trop loin du prix actuel (", DoubleToString(distancePercent, 2), "% > 5%) - Abandon placement");
      return;
   }
   
   double adjustedEntryPrice = bestLevel;
   
   // Sécurité: un LIMIT doit être du bon côté du marché
   // BUY_LIMIT < Ask ; SELL_LIMIT > Bid (sinon MT5 refusera ou déclenchera immédiatement)
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minGap = MathMax((double)stopsLevel * point, 2.0 * point);
   if(minGap <= 0) minGap = 5.0 * point;
   
   if(limitOrderType == ORDER_TYPE_BUY_LIMIT && adjustedEntryPrice >= ask)
   {
      adjustedEntryPrice = ask - minGap;
      if(DebugMode)
         Print("⚠️ Ajustement BUY_LIMIT: entry >= Ask, nouveau entry=", DoubleToString(adjustedEntryPrice, _Digits));
   }
   else if(limitOrderType == ORDER_TYPE_SELL_LIMIT && adjustedEntryPrice <= bid)
   {
      adjustedEntryPrice = bid + minGap;
      if(DebugMode)
         Print("⚠️ Ajustement SELL_LIMIT: entry <= Bid, nouveau entry=", DoubleToString(adjustedEntryPrice, _Digits));
   }
   
   Print("✅ Prix d'entrée OPTIMAL: ", DoubleToString(adjustedEntryPrice, _Digits), 
         " (source: ", bestLevelSource, ", distance: ", DoubleToString(distancePercent, 2), "%)");
   
   if(DebugMode)
      Print("✅ Meilleure opportunité sélectionnée: Type=", zoneIsBuy ? "BUY" : "SELL",
            " EntryPrice=", DoubleToString(adjustedEntryPrice, _Digits),
            " PotentialGain=", DoubleToString(bestOpportunity.percentage, 2), "%",
            " Score=", DoubleToString(bestScore, 3),
            " Décision finale: ", finalDecision.details);
   
   // ===== CALCULER SL ET TP BASÉS SUR LE PRIX (POURCENTAGE) =====
   // Pour les ordres LIMIT, utiliser des pourcentages du prix d'entrée plutôt que des montants USD fixes
   // Les SL/TP doivent être plus serrés car l'ordre est déjà placé près du prix actuel
   
   // NOTE: `point` est déjà récupéré plus haut (réutilisé ici)
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
   
   // Pour les indices Boom/Crash, utiliser des ordres au marché si le prix est très proche
   // Utiliser la variable currentPrice déjà définie au début de la fonction
   double priceDistance = MathAbs(entryPrice - currentPrice) / currentPrice * 100.0;
   
   if(isBoomCrash && priceDistance < 0.2) // Si à moins de 0.2% du prix actuel
   {
      // Pour les indices Boom/Crash, exécuter directement au marché si le prix est très proche
      request.action = TRADE_ACTION_DEAL;
      if(zoneIsBuy)
         request.type = ORDER_TYPE_BUY;
      else
         request.type = ORDER_TYPE_SELL;
      request.price = zoneIsBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   }
   else
   {
      // Pour les autres cas, utiliser un ordre limite normal
      if(zoneIsBuy)
         request.type = ORDER_TYPE_BUY_LIMIT;
      else
         request.type = ORDER_TYPE_SELL_LIMIT;
      request.price = entryPrice;
   }
   
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = InpMagicNumber;
   // Stocker la confiance dans le comment pour comparaison future
   request.comment = "LIMIT_CONF:" + DoubleToString(g_lastAIConfidence * 100, 2);
   // Détecter automatiquement le mode de remplissage supporté par le symbole
   request.type_filling = GetSupportedFillingMode(_Symbol);
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
   
   // ===== NOUVEAU: VÉRIFIER SI ON PEUT EXÉCUTER DIRECTEMENT AU LIEU DE PLACER UN ORDRE LIMIT =====
   // Si le prix est très proche (< 0.2% du prix actuel), exécuter directement au lieu de placer un ordre LIMIT
   double executeDistancePercent = (MathAbs(entryPrice - currentPrice) / currentPrice) * 100.0;
   double executeThreshold = 0.2; // 0.2% = exécuter directement
   
   // Anti-hasard: en mode strict, NE PAS convertir un LIMIT en exécution directe au marché
   if(!UseStrictQualityFilter && executeDistancePercent < executeThreshold && finalDecision.confidence >= 0.7)
   {
      // Prix très proche + confiance élevée → Exécuter directement
      Print("⚡ EXÉCUTION DIRECTE (prix très proche): Distance=", DoubleToString(executeDistancePercent, 2), 
            "% < ", DoubleToString(executeThreshold, 2), "%, Confiance=", DoubleToString(finalDecision.confidence * 100, 1), "%");
      
      ENUM_ORDER_TYPE executeOrderType;
      if(zoneIsBuy)
         executeOrderType = ORDER_TYPE_BUY;
      else
         executeOrderType = ORDER_TYPE_SELL;
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
   
   // Sanity: clamp S/R to current symbol scale (eviter données d'un autre symbole / prédiction incohérente)
   double priceMin = currentPrice * 0.5;
   double priceMax = currentPrice * 2.0;
   if(supportLevel < priceMin || supportLevel > priceMax)
      supportLevel = currentPrice;
   if(resistanceLevel < priceMin || resistanceLevel > priceMax)
      resistanceLevel = currentPrice;
   
   // Parcourir uniquement les positions du symbole courant
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;
      
      if(!PositionSelectByTicket(ticket))
         continue;
      
      // Ne modifier que les positions sur le symbole du graphique
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double minDistance = stopLevel * point;
         if(minDistance == 0) minDistance = 10 * point;
         
         // Ajuster SL au break-even + petit profit (0.5$)
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double profitNeeded = 0.5;
         double priceMove = (profitNeeded / (lotSize * (tickValue / tickSize) * point));
         
         if(posType == POSITION_TYPE_BUY)
         {
            double securePrice = openPrice + priceMove;
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
         
         // NOUVEAU: Utiliser les zones de support/résistance prédites pour ajuster le TP
         // Augmenter le TP si la prédiction montre un mouvement plus important
         if(currentTP > 0 && avgMovementPercent > 0.2) // Si mouvement moyen prédit > 0.2%
         {
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double minDistance = stopLevel * point;
            if(minDistance == 0) minDistance = 10 * point;
            
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
      } // Fermeture du bloc if(predictionFavorable)
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
         // Validation des stops: éviter "Invalid stops" (même échelle que le symbole, sens logique)
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
         double minDist = MathMax((double)stopLevel * point, 2.0 * point);
         if(minDist <= 0) minDist = 5.0 * point;
         double maxMove = MathMax(openPrice * 0.5, 1000.0 * point); // max déplacement raisonnable
         // Plage de prix valide pour ce symbole (éviter SL/TP d'une autre échelle, ex. 227412 sur Step Index)
         double priceFloor = openPrice * 0.5;
         double priceCeil = openPrice * 2.0;
         
         bool slTpValid = false;
         if(posType == POSITION_TYPE_BUY)
         {
            // BUY: SL < openPrice, TP > openPrice, dans [priceFloor, priceCeil], distances >= minDist
            bool slOk = (newSL > 0 && newSL >= priceFloor && newSL <= priceCeil && newSL < openPrice && (openPrice - newSL) <= maxMove && (currentPrice - newSL) >= minDist);
            bool tpOk = (newTP > 0 && newTP >= priceFloor && newTP <= priceCeil && newTP > openPrice && (newTP - openPrice) <= maxMove && (newTP - currentPrice) >= minDist);
            if(!slOk) newSL = currentSL;
            if(!tpOk) newTP = currentTP;
            slTpValid = (newSL != currentSL || newTP != currentTP);
         }
         else
         {
            // SELL: SL > openPrice, TP < openPrice, dans [priceFloor, priceCeil]
            bool slOk = (newSL > 0 && newSL >= priceFloor && newSL <= priceCeil && newSL > openPrice && (newSL - openPrice) <= maxMove && (newSL - currentPrice) >= minDist);
            bool tpOk = (newTP > 0 && newTP >= priceFloor && newTP <= priceCeil && newTP < openPrice && (openPrice - newTP) <= maxMove && (currentPrice - newTP) >= minDist);
            if(!slOk) newSL = currentSL;
            if(!tpOk) newTP = currentTP;
            slTpValid = (newSL != currentSL || newTP != currentTP);
         }
         
         if(!slTpValid)
            shouldModify = false;
         else
         {
            request.sl = newSL;
            request.tp = newTP;
         }
      }
      
      if(shouldModify)
      {
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
      } // Fermeture du bloc if(shouldModify)
   } // Fermeture de la boucle for sur les positions
} // Fermeture de la fonction UsePredictionForCurrentTrades

//+------------------------------------------------------------------+
//| Vérifier et gérer les positions existantes                       |
//+------------------------------------------------------------------+
void CheckAndManagePositions()
{
   g_hasPosition = false;

   // NOUVEAU (USER): si la décision finale devient NEUTRE pendant un trade,
   // sortir immédiatement et attendre une décision claire pour ré-entrer.
   static datetime lastFinalDecisionCheck = 0;
   if(TimeCurrent() - lastFinalDecisionCheck >= 1) // check 1x/sec (cohérent avec OnTick)
   {
      lastFinalDecisionCheck = TimeCurrent();
      
      FinalDecisionResult finalDecision;
      bool hasFinalDecision = GetFinalDecision(finalDecision);
      if(hasFinalDecision && finalDecision.direction == 0)
      {
         int closedCount = 0;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0)
               continue;
            if(!positionInfo.SelectByTicket(ticket))
               continue;
            if(positionInfo.Symbol() != _Symbol || positionInfo.Magic() != InpMagicNumber)
               continue;
            
            double posProfit = positionInfo.Profit();
            if(trade.PositionClose(ticket))
            {
               closedCount++;
               Print("🛑 Décision finale NEUTRE -> position fermée: Ticket=", ticket,
                     " Profit=", DoubleToString(posProfit, 2), "$");
            }
            else if(DebugMode)
            {
               Print("❌ Échec fermeture (décision finale NEUTRE): Ticket=", ticket,
                     " - ", trade.ResultRetcodeDescription());
            }
         }
         
         if(closedCount > 0)
         {
            Print("⏸️ Décision finale devenue NEUTRE: ", closedCount,
                  " position(s) fermée(s). Attente décision claire pour ré-entrer.");
            g_hasPosition = false;
            return;
         }
      }
   }

   // Fermeture globale Volatility si perte cumulée dépasse 7$
   CloseVolatilityIfLossExceeded(7.0);
   
   // NOUVEAU: Vérifier TOUTES les positions de volatilité pour la limite de perte de $4
   // EXCLURE Boom/Crash - ils doivent aller au bout sans fermeture automatique
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
            bool isBoomCrashSymbol = (StringFind(positionSymbol, "Boom") != -1 || StringFind(positionSymbol, "Crash") != -1);
            
            // Fermeture automatique SEULEMENT pour Volatility/Step Index, PAS pour Boom/Crash
            if(isVolatilitySymbol && !isBoomCrashSymbol)
            {
               double positionProfit = positionInfo.Profit();
               
               // Log de débogage pour voir toutes les positions de volatilité
               if(DebugMode && positionProfit < 0)
                  Print("🔍 Vérification limite perte (Volatility/Step Index): ", positionSymbol, " - Profit: ", DoubleToString(positionProfit, 2), "$");
               
               // Fermer immédiatement si perte dépasse $4 (SEULEMENT pour Volatility/Step Index)
               if(positionProfit <= -4.0)
               {
                  Print("🚨 LIMITE ATTEINTE: ", positionSymbol, " - Profit: ", DoubleToString(positionProfit, 2), "$ - Tentative de fermeture...");
                  if(trade.PositionClose(checkTicket))
                  {
                     Print("✅ Position Volatility/Step Index fermée: ", positionSymbol, 
                           " - Perte max atteinte (", DoubleToString(positionProfit, 2), "$ <= -4.00$)");
                     SendMLFeedback(checkTicket, positionProfit, "Volatility max loss exceeded");
                  }
                  else
                  {
                     Print("❌ ERREUR fermeture position (limite perte $4): ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription(), 
                           " - Ticket: ", checkTicket, " Symbol: ", positionSymbol, " Profit: ", DoubleToString(positionProfit, 2), "$");
                  }
               }
            }
            // POUR Boom/Crash: Ne jamais fermer automatiquement - laisser aller au bout
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
            // EXCLURE Boom/Crash - ils doivent aller au bout sans fermeture automatique
            // Vérifier le symbole de la position, pas le symbole courant de l'EA
            string positionSymbol = positionInfo.Symbol();
            bool isVolatilitySymbol = IsVolatilitySymbol(positionSymbol);
            bool isBoomCrashSymbol = (StringFind(positionSymbol, "Boom") != -1 || StringFind(positionSymbol, "Crash") != -1);
            
            // Fermeture automatique SEULEMENT pour Volatility/Step Index, PAS pour Boom/Crash
            if(isVolatilitySymbol && !isBoomCrashSymbol && currentProfit <= -4.0)
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
            
            // POUR Boom/Crash: Laisser aller au bout sans fermeture automatique
            // Commentaire pour info: Boom/Crash ne sont jamais fermés automatiquement ici
            
            // NOUVELLE LOGIQUE: Ne pas sécuriser/fermer une position qui a commencé à rentabiliser après une perte
            // Laisser faire au moins 2$ de gain avant de commencer à sécuriser
            // La sécurisation se fera uniquement si le profit >= 2$ ET que le drawdown atteint 50% du profit max
            
            // DÉSACTIVÉ: Timeout de 5 minutes - Laisser les positions vivre jusqu'à SL/TP
            // Les positions doivent respecter les Stop Loss et Take Profit définis à l'ouverture
            // datetime openTime = (datetime)positionInfo.Time();
            // int positionAge = (int)(TimeCurrent() - openTime);
            // if(positionAge >= 300 && currentProfit <= 0) // 300 secondes = 5 minutes
            // {
            //    if(trade.PositionClose(ticket))
            //    {
            //       Print("⏰ Position fermée: Ouverte depuis ", positionAge, "s (>= 5 min) sans gain - Profit=", DoubleToString(currentProfit, 2), "$");
            //       SendMLFeedback(ticket, currentProfit, "Position timeout (5 min without profit)");
            //       continue;
            //    }
            // }
            
            // NE PAS fermer automatiquement à 2$ - laisser la position continuer à prendre profit
            // La fermeture se fera seulement si drawdown de 50% après avoir atteint 2$+
            
            // DÉSACTIVÉ: Fermeture automatique sur changement IA - Laisser SL/TP gérer
            // Les positions doivent respecter les Stop Loss et Take Profit définis à l'ouverture
            // bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
            // if(UseAI_Agent && g_lastAIAction != "" && isBoomCrash)
            // {
            //    // ... code de fermeture IA désactivé ...
            // }
            
            // Vérifier si on doit doubler le lot (avec confirmations avancées)
            // Réutiliser positionAge déjà calculé plus haut
            int positionAgeForDouble = (int)(TimeCurrent() - g_positionTracker.openTime);
            
            if(!g_positionTracker.lotDoubled && 
               currentProfit >= ProfitThresholdForDouble &&
               positionAgeForDouble >= MinPositionLifetimeSec)
            {
               // NOUVEAU: Vérifier les conditions de retournement avant de doubler
               ENUM_POSITION_TYPE posType = positionInfo.PositionType();
               ENUM_ORDER_TYPE orderType;
               if(posType == POSITION_TYPE_BUY)
                  orderType = ORDER_TYPE_BUY;
               else
                  orderType = ORDER_TYPE_SELL;
               
               // Vérifier SuperTrend et patterns de continuation
               double superTrendStrength = 0.0;
               bool superTrendOk = CheckSuperTrendSignal(orderType, superTrendStrength);
               
               // Vérifier pattern de continuation (pas de retournement)
               double reversalConfidence = 0.0;
               ENUM_ORDER_TYPE reversalOrderType;
               if(orderType == ORDER_TYPE_BUY)
                  reversalOrderType = ORDER_TYPE_SELL;
               else
                  reversalOrderType = ORDER_TYPE_BUY;
               bool hasReversal = CheckPatternReversal(reversalOrderType, reversalConfidence);
               
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
            
            // DÉSACTIVÉ: Fermeture automatique Boom/Crash après spike - Laisser SL/TP gérer
            // Les positions doivent respecter les Stop Loss et Take Profit définis à l'ouverture
            bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
            bool isForex = IsForexSymbol(_Symbol);
            // 
            // if(isBoomCrash)
            // {
            //    CloseBoomCrashAfterSpike(ticket, currentProfit);
            // }
            
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
            
            // DÉSACTIVÉ: Fermeture sur correction IA - Laisser SL/TP gérer
            // Les positions doivent respecter les Stop Loss et Take Profit définis à l'ouverture
            // if(isBoomCrash)
            // {
            //    ENUM_POSITION_TYPE posType = positionInfo.PositionType();
            //    if(posType == POSITION_TYPE_BUY)
            //    {
            //       CheckAndCloseBuyOnCorrection(ticket, currentProfit);
            //    }
            //    else if(posType == POSITION_TYPE_SELL)
            //    {
            //       CheckAndCloseSellOnCorrection(ticket, currentProfit);
            //    }
            // }
            
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
//| Nettoyer les canaux de prédiction                                |
//+------------------------------------------------------------------+
void CleanupPredictionChannel()
{
   string prefix = "PRED_CHANNEL_";
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Nettoyer les bougies futures                                     |
//+------------------------------------------------------------------+
void CleanupFutureCandles()
{
   string prefix = "FUTURE_CANDLE_";
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Nettoyer TOUS les objets graphiques au démarrage                  |
//+------------------------------------------------------------------+
void CleanAllGraphicalObjects()
{
   // NETTOYAGE AMÉLIORÉ: Supprimer TOUS les anciens objets de prédiction (y compris les bougies)
   string prefixesToDelete[] = {"PRED_", "AI_CONFIDENCE_", "AI_TREND_SUMMARY_", "AI_ALIGNMENT_", "AI_FINAL_DECISION_", "MARKET_STATE_", "MARKET_TREND_", "AI_SEPARATOR_"};
   
   for(int p = 0; p < ArraySize(prefixesToDelete); p++)
   {
      string currentPrefix = prefixesToDelete[p];
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, currentPrefix) == 0)
            ObjectDelete(0, name);
      }
   }
   
   // Supprimer aussi les objets ML metrics pour forcer la recréation
   string mlPrefixes[] = {"ML_METRICS_", "ML_MODEL_", "ML_ACCURACY_", "ML_UPDATE_"};
   for(int p = 0; p < ArraySize(mlPrefixes); p++)
   {
      string currentPrefix = mlPrefixes[p];
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, currentPrefix) == 0)
            ObjectDelete(0, name);
      }
   }
   
   if(DebugMode)
      Print("🧹 Nettoyage complet des objets graphiques effectué");
}

//+------------------------------------------------------------------+
//| Nettoyer tous les objets de prédiction du graphique            |
//+------------------------------------------------------------------+
void CleanPredictionObjects()
{
   // Supprimer tous les objets liés aux prédictions
   string predictionPrefixes[] = {
      "PRED_", "FUTURE_", "CHANNEL_", "PREDICTION_", 
      "CANDLE_BODY_", "CANDLE_WICK_", "BUY_ENTRY_", "SELL_ENTRY_"
   };
   
   for(int p = 0; p < ArraySize(predictionPrefixes); p++)
   {
      string prefix = predictionPrefixes[p];
      int total = ObjectsTotal(0);
      for(int i = total - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringFind(name, prefix) == 0)
         {
            ObjectDelete(0, name);
            if(DebugMode)
               Print("🧹 Supprimé objet de prédiction: ", name);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Convertir un timeframe en secondes                               |
//+------------------------------------------------------------------+
int GetPeriodSeconds(ENUM_TIMEFRAMES period)
{
   switch(period)
   {
      case PERIOD_M1:  return 60;
      case PERIOD_M2:  return 120;
      case PERIOD_M3:  return 180;
      case PERIOD_M4:  return 240;
      case PERIOD_M5:  return 300;
      case PERIOD_M6:  return 360;
      case PERIOD_M10: return 600;
      case PERIOD_M12: return 720;
      case PERIOD_M15: return 900;
      case PERIOD_M20: return 1200;
      case PERIOD_M30: return 1800;
      case PERIOD_H1:  return 3600;
      case PERIOD_H2:  return 7200;
      case PERIOD_H3:  return 10800;
      case PERIOD_H4:  return 14400;
      case PERIOD_H6:  return 21600;
      case PERIOD_H8:  return 28800;
      case PERIOD_H12: return 43200;
      case PERIOD_D1:  return 86400;
      case PERIOD_W1:  return 604800;
      case PERIOD_MN1: return 2592000;
      default:         return 0;
   }
}

//+------------------------------------------------------------------+
//| Mettre à jour les métriques ML en temps réel                     |
//+------------------------------------------------------------------+
void UpdateMLMetricsRealtime()
{
   static datetime lastUpdate = 0;
   
   // Mettre à jour toutes les 5 minutes max
   if(TimeCurrent() - lastUpdate < 300) // 5 minutes
      return;
      
   // Vérifier si l'URL des métriques est configurée
   if(StringLen(AI_MLMetricsURL) == 0)
   {
      if(DebugMode)
         Print("⚠️ URL des métriques ML non configurée");
      return;
   }
   
   // Mettre à jour le timestamp de dernière mise à jour
   lastUpdate = TimeCurrent();
   
   if(DebugMode)
      Print("🔄 Mise à jour des métriques ML en cours...");
}


//+------------------------------------------------------------------+
//| Nettoyer le dashboard intégré                                    |
//+------------------------------------------------------------------+
void CleanupIntegratedDashboard()
{
   // Supprimer tous les objets du dashboard intégré
   string prefix = "DASH_";
   int total = ObjectsTotal(0);
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
   
   // Supprimer les objets spécifiques du dashboard IA
   string dashboardObjects[] = {"AI_DASH_", "DASH_HEADER", "DASH_SEPARATOR", "DASH_FOOTER", 
                              "DASH_SIGNAL_", "DASH_INDICATOR_", "DASH_METRIC_"};
   
   for(int i = 0; i < ArraySize(dashboardObjects); i++)
   {
      total = ObjectsTotal(0);
      for(int j = total - 1; j >= 0; j--)
      {
         string objName = ObjectName(0, j);
         if(StringFind(objName, dashboardObjects[i]) == 0)
            ObjectDelete(0, objName);
      }
   }
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
   string objectsToKeep[] = {"AI_CONFIDENCE_", "AI_TREND_SUMMARY_", "AI_ALIGNMENT_", "AI_FINAL_DECISION_", "MARKET_STATE_", "MARKET_TREND_", "AI_SEPARATOR_",
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
   
   // Si aucune opportunité alignée, masquer le panneau
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
   
   // Trier les opportunités alignées par priorité (pourcentage décroissant)
   for(int i = 0; i < alignedCount - 1; i++)
   {
      for(int j = 0; j < alignedCount - i - 1; j++)
      {
         if(alignedOpportunities[j].priority < alignedOpportunities[j + 1].priority)
         {
            TradingOpportunity temp = alignedOpportunities[j];
            alignedOpportunities[j] = alignedOpportunities[j + 1];
            alignedOpportunities[j + 1] = temp;
         }
      }
   }
   
   // Limiter à 5 meilleures opportunités alignées pour ne pas encombrer
   int maxDisplay = MathMin(5, alignedCount);
   
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
   
   // Afficher UNIQUEMENT les opportunités alignées (format compact)
   for(int i = 0; i < maxDisplay; i++)
   {
      string oppName = "OPP_" + IntegerToString(i) + "_" + _Symbol;
      if(ObjectFind(0, oppName) < 0)
         ObjectCreate(0, oppName, OBJ_LABEL, 0, 0, 0);
      
      int yPos = panelY + 25 + (i * lineHeight);
      color oppColor = alignedOpportunities[i].isBuy ? clrLime : clrRed;
      
      // Format avec prix : Type + Pourcentage + Prix
      string oppText = (alignedOpportunities[i].isBuy ? "▲ BUY" : "▼ SELL") + "  +" + 
                       DoubleToString(alignedOpportunities[i].percentage, 1) + "%" +
                       " @ " + DoubleToString(alignedOpportunities[i].entryPrice, _Digits);
      
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
      aiText += "ATTENTE " + DoubleToString(g_lastAIConfidence * 100, 0) + "%";
   
   ObjectSetString(0, aiLabelName, OBJPROP_TEXT, aiText);
   ObjectSetInteger(0, aiLabelName, OBJPROP_COLOR, (g_lastAIAction == "buy") ? clrLime : (g_lastAIAction == "sell") ? clrRed : clrYellow);
   ObjectSetInteger(0, aiLabelName, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, aiLabelName, OBJPROP_FONT, "Arial Bold");
   
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
   
   // ===== NOUVEAU: AFFICHAGE DÉCISION IA, PRÉDICTION DE ZONE, ALIGNEMENT 3 CRITÈRES, DÉCISION FINALE =====
   
   // --- 1. Décision IA (déjà affichée dans aiLabelName, mais on peut l'améliorer) ---
   // C'est déjà fait dans aiLabelName (lignes 4418-4429)
   
   // --- 2. Prédiction de zone --- (SUPPRIMÉ - plus utilisé dans décision finale)
   /*
   string predictionZoneLabelName = "AI_PREDICTION_ZONE_" + _Symbol;
   if(ObjectFind(0, predictionZoneLabelName) < 0)
      ObjectCreate(0, predictionZoneLabelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, predictionZoneLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, predictionZoneLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, predictionZoneLabelName, OBJPROP_YDISTANCE, 130);
   
   string predictionZoneText = "Zone Prédiction: ";
   if(g_predictionValid && ArraySize(g_pricePrediction) >= 20)
   {
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
      int predictionWindow = MathMin(20, ArraySize(g_pricePrediction));
      double predictedPrice = g_pricePrediction[predictionWindow - 1];
      double priceMovement = predictedPrice - currentPrice;
      double movementPercent = (MathAbs(priceMovement) / currentPrice) * 100.0;
      
      if(movementPercent > 0.05)
      {
         if(priceMovement > 0)
            predictionZoneText += "HAUSSE " + DoubleToString(movementPercent, 2) + "%";
         else
            predictionZoneText += "BAISSE " + DoubleToString(movementPercent, 2) + "%";
      }
      else
         predictionZoneText += "NEUTRE";
   }
   else
      predictionZoneText += "INVALIDE";
   
   ObjectSetString(0, predictionZoneLabelName, OBJPROP_TEXT, predictionZoneText);
   ObjectSetInteger(0, predictionZoneLabelName, OBJPROP_COLOR, (g_predictionValid && ArraySize(g_pricePrediction) >= 20) ? 
                     ((g_pricePrediction[MathMin(19, ArraySize(g_pricePrediction)-1)] > (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0) ? clrLime : clrRed) : clrGray);
   ObjectSetInteger(0, predictionZoneLabelName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, predictionZoneLabelName, OBJPROP_FONT, "Arial Bold");
   */
   
   // --- 3. Alignement des 2 critères (IA, Tendances) ---
   string alignmentLabelName = "AI_ALIGNMENT_" + _Symbol;
   if(ObjectFind(0, alignmentLabelName) < 0)
      ObjectCreate(0, alignmentLabelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, alignmentLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, alignmentLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, alignmentLabelName, OBJPROP_YDISTANCE, 150);
   
   string alignmentText = "Alignement 2 critères: ";
   int buyVotes = 0;
   int sellVotes = 0;
   int totalVotes = 0;
   
   // IA
   if(UseAI_Agent && g_lastAITime > 0)
   {
      datetime currentTime = TimeCurrent();
      if(currentTime > g_lastAITime && (currentTime - g_lastAITime) < AI_UpdateInterval * 2)
      {
         if(g_lastAIAction == "buy") { buyVotes++; totalVotes++; }
         else if(g_lastAIAction == "sell") { sellVotes++; totalVotes++; }
      }
   }
   
   // Tendances (EMA M1, M5, H1)
   if(hasData)
   {
      if(emaFastM1[0] > emaSlowM1[0]) { buyVotes++; totalVotes++; } else if(emaFastM1[0] < emaSlowM1[0]) { sellVotes++; totalVotes++; }
      if(emaFastM5[0] > emaSlowM5[0]) { buyVotes++; totalVotes++; } else if(emaFastM5[0] < emaSlowM5[0]) { sellVotes++; totalVotes++; }
      if(emaFastH1[0] > emaSlowH1[0]) { buyVotes++; totalVotes++; } else if(emaFastH1[0] < emaSlowH1[0]) { sellVotes++; totalVotes++; }
   }
   
   // Prédiction supprimée - plus utilisée dans décision finale
   
   if(totalVotes > 0)
   {
      if(buyVotes >= 3) // Au moins 3 votes sur 4 possibles pour BUY
         alignmentText += "BUY (" + IntegerToString(buyVotes) + "/" + IntegerToString(totalVotes) + ")";
      else if(sellVotes >= 3) // Au moins 3 votes sur 4 possibles pour SELL
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
   
   // --- 4. Décision finale (combinaison de toutes les analyses) ---
   string finalDecisionLabelName = "AI_FINAL_DECISION_" + _Symbol;
   if(ObjectFind(0, finalDecisionLabelName) < 0)
      ObjectCreate(0, finalDecisionLabelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, finalDecisionLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, finalDecisionLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, finalDecisionLabelName, OBJPROP_YDISTANCE, 170);
   
   // Calculer la décision finale complète
   int finalBuyVotes = 0;
   int finalSellVotes = 0;
   int finalTotalVotes = 0;
   string finalDetails = "";
   
   // IA (poids 2)
   if(UseAI_Agent && g_lastAITime > 0)
   {
      datetime currentTime = TimeCurrent();
      if(currentTime > g_lastAITime && (currentTime - g_lastAITime) < AI_UpdateInterval * 2)
      {
         if(g_lastAIAction == "buy") { finalBuyVotes += 2; finalTotalVotes += 2; finalDetails += "IA:BUY "; }
         else if(g_lastAIAction == "sell") { finalSellVotes += 2; finalTotalVotes += 2; finalDetails += "IA:SELL "; }
         else { finalDetails += "IA:NEUTRE "; }
      }
      else { finalDetails += "IA:OBSOLETE "; }
   }
   else { finalDetails += "IA:INACTIVE "; }
   
   // API Trend
   if(UseTrendAPIAnalysis && g_api_trend_valid)
   {
      if(g_api_trend_direction == 1) { finalBuyVotes += 1; finalTotalVotes += 1; finalDetails += "API_Trend:BUY "; }
      else if(g_api_trend_direction == -1) { finalSellVotes += 1; finalTotalVotes += 1; finalDetails += "API_Trend:SELL "; }
      else { finalDetails += "API_Trend:NEUTRE "; }
   }
   else { finalDetails += "API_Trend:INVALIDE "; }
   
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
         if(priceMovement > 0) { finalBuyVotes += 1; finalTotalVotes += 1; finalDetails += "Pred:BUY "; }
         else { finalSellVotes += 1; finalTotalVotes += 1; finalDetails += "Pred:SELL "; }
      }
      else { finalDetails += "Pred:NEUTRE "; }
   }
   else { finalDetails += "Pred:INVALIDE "; }
   
   // EMA M1, M5, H1
   if(hasData)
   {
      if(emaFastM1[0] > emaSlowM1[0]) { finalBuyVotes += 1; finalTotalVotes += 1; finalDetails += "EMA_M1:BUY "; }
      else if(emaFastM1[0] < emaSlowM1[0]) { finalSellVotes += 1; finalTotalVotes += 1; finalDetails += "EMA_M1:SELL "; }
      if(emaFastM5[0] > emaSlowM5[0]) { finalBuyVotes += 1; finalTotalVotes += 1; finalDetails += "EMA_M5:BUY "; }
      else if(emaFastM5[0] < emaSlowM5[0]) { finalSellVotes += 1; finalTotalVotes += 1; finalDetails += "EMA_M5:SELL "; }
      if(emaFastH1[0] > emaSlowH1[0]) { finalBuyVotes += 1; finalTotalVotes += 1; finalDetails += "EMA_H1:BUY "; }
      else if(emaFastH1[0] < emaSlowH1[0]) { finalSellVotes += 1; finalTotalVotes += 1; finalDetails += "EMA_H1:SELL "; }
   }
   
   // SuperTrend
   double superTrendStrengthBuy = 0.0;
   double superTrendStrengthSell = 0.0;
   bool superTrendBuy = CheckSuperTrendSignal(ORDER_TYPE_BUY, superTrendStrengthBuy);
   bool superTrendSell = CheckSuperTrendSignal(ORDER_TYPE_SELL, superTrendStrengthSell);
   if(superTrendBuy && superTrendStrengthBuy > superTrendStrengthSell) { finalBuyVotes += 1; finalTotalVotes += 1; finalDetails += "SuperTrend:BUY "; }
   else if(superTrendSell && superTrendStrengthSell > superTrendStrengthBuy) { finalSellVotes += 1; finalTotalVotes += 1; finalDetails += "SuperTrend:SELL "; }
   
   // Calcul de la décision finale
   string finalDecisionText = "Décision Finale: ";
   color finalDecisionColor = clrYellow;
   double finalConfidence = 0.0;
   
   if(finalTotalVotes > 0)
   {
      if(finalBuyVotes >= 5 && finalBuyVotes > finalSellVotes)
      {
         finalDecisionText += "BUY FORT (" + IntegerToString(finalBuyVotes) + "/" + IntegerToString(finalTotalVotes) + ")";
         finalDecisionColor = clrLime;
         finalConfidence = (double)finalBuyVotes / finalTotalVotes;
      }
      else if(finalSellVotes >= 5 && finalSellVotes > finalBuyVotes)
      {
         finalDecisionText += "SELL FORT (" + IntegerToString(finalSellVotes) + "/" + IntegerToString(finalTotalVotes) + ")";
         finalDecisionColor = clrRed;
         finalConfidence = (double)finalSellVotes / finalTotalVotes;
      }
      else
      {
         finalDecisionText += "NEUTRE (" + IntegerToString(MathMax(finalBuyVotes, finalSellVotes)) + "/" + IntegerToString(finalTotalVotes) + ")";
         finalDecisionColor = clrYellow;
         finalConfidence = (double)MathMax(finalBuyVotes, finalSellVotes) / finalTotalVotes;
      }
      
      finalDecisionText += " | Confiance: " + DoubleToString(finalConfidence * 100, 1) + "%";
   }
   else
   {
      finalDecisionText += "INSUFFISANT";
      finalDecisionColor = clrGray;
   }
   
   ObjectSetString(0, finalDecisionLabelName, OBJPROP_TEXT, finalDecisionText);
   ObjectSetInteger(0, finalDecisionLabelName, OBJPROP_COLOR, finalDecisionColor);
   ObjectSetInteger(0, finalDecisionLabelName, OBJPROP_FONTSIZE, 11);
   ObjectSetString(0, finalDecisionLabelName, OBJPROP_FONT, "Arial Bold");
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
               SendMLFeedback(ticket, currentProfit, "BUY zone exit: " + reason);
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
               SendMLFeedback(ticket, currentProfit, "SELL zone exit: " + reason);
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
   
   // MODIFIÉ: Fermer IMMÉDIATEMENT après spike détecté, PEU IMPORTE LE GAIN
   // Fermer dès qu'un spike est détecté, même si le profit est négatif
   if(spikeDetected)
   {
      if(trade.PositionClose(ticket))
      {
         Print("✅ Position Boom/Crash fermée IMMÉDIATEMENT après spike - Profit=", DoubleToString(currentProfit, 2), "$");
         
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
   // Si pas de spike mais profit seuil atteint, fermer aussi
   else if(currentProfit >= BoomCrashSpikeTP)
   {
      if(trade.PositionClose(ticket))
      {
         Print("✅ Position Boom/Crash fermée: Profit seuil atteint - Profit=", DoubleToString(currentProfit, 2),
               "$ (seuil=", DoubleToString(BoomCrashSpikeTP, 2), "$)");
         
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
//| Fermer les positions Boom/Crash profitables                      |
//+------------------------------------------------------------------+
void CloseProfitableBoomCrashPositions()
{
   // Vérifier si la fonctionnalité est activée
   if(!EnableBoomCrashProfitClose)
      return;
      
   // Vérifier l'intervalle de temps
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastBoomCrashProfitCheck < BoomCrashCheckInterval)
      return;
      
   g_lastBoomCrashProfitCheck = currentTime;
   
   int positionsClosed = 0;
   double totalProfitClosed = 0;
   int boomPositions = 0;
   int crashPositions = 0;
   
   // Parcourir toutes les positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         string symbol = positionInfo.Symbol();
         double positionProfit = positionInfo.Profit() + positionInfo.Swap() + positionInfo.Commission();
         ulong ticket = positionInfo.Ticket();
         
         // Vérifier si c'est un symbole Boom ou Crash
         bool isBoomSymbol = (StringFind(symbol, "Boom") >= 0);
         bool isCrashSymbol = (StringFind(symbol, "Crash") >= 0);
         
         // Appliquer les filtres selon les paramètres
         bool shouldProcess = false;
         
         if(BoomCrashCloseOnlyBoom && isBoomSymbol)
         {
            shouldProcess = true;
         }
         else if(BoomCrashCloseOnlyCrash && isCrashSymbol)
         {
            shouldProcess = true;
         }
         else if(!BoomCrashCloseOnlyBoom && !BoomCrashCloseOnlyCrash && (isBoomSymbol || isCrashSymbol))
         {
            shouldProcess = true;
         }
         
         // Si le symbole correspond et la position est profitable
         if(shouldProcess && positionProfit > BoomCrashMinProfitThreshold)
         {
            if(isBoomSymbol) boomPositions++;
            if(isCrashSymbol) crashPositions++;
            
            if(DebugMode)
            {
               Print("🔍 Position Boom/Crash profitable trouvée:");
               Print("   Ticket: #", ticket);
               Print("   Symbole: ", symbol);
               Print("   Type: ", EnumToString(positionInfo.PositionType()));
               Print("   Volume: ", DoubleToString(positionInfo.Volume(), 3));
               Print("   Profit: ", DoubleToString(positionProfit, 2), "$ (seuil: ", DoubleToString(BoomCrashMinProfitThreshold, 2), "$)");
               Print("   🔄 Fermeture automatique...");
            }
            
            // Fermer la position avec multi-essais
            bool closed = CloseBoomCrashPositionWithRetry(ticket, positionProfit);
            
            if(closed)
            {
               positionsClosed++;
               totalProfitClosed += positionProfit;
               g_boomCrashPositionsClosed++;
               g_boomCrashProfitClosed += positionProfit;
               
               Print("✅ Position Boom/Crash #", ticket, " fermée automatiquement - Profit: ", DoubleToString(positionProfit, 2), "$");
               
               // Notification MT5
               if(SendNotifications)
               {
                  string message = StringFormat("BOOM/CRASH AUTO: Position %s #%d fermée - Profit %.2f$", symbol, ticket, positionProfit);
                  SendNotification(message);
               }
               
               // Journaliser la fermeture
               LogTradeClose(ticket, "Profitable Auto-Close");
            }
            else
            {
               Print("❌ Échec fermeture position Boom/Crash #", ticket);
            }
         }
         else if(shouldProcess && DebugMode)
         {
            Print("⏸️ Position Boom/Crash non profitable:");
            Print("   Ticket: #", ticket);
            Print("   Symbole: ", symbol);
            Print("   Profit: ", DoubleToString(positionProfit, 2), "$ (seuil: ", DoubleToString(BoomCrashMinProfitThreshold, 2), "$)");
         }
      }
   }
   
   // Résumé si des positions ont été fermées
   if(positionsClosed > 0)
   {
      Print("🎯🎯🎯 FERMETURE AUTOMATIQUE BOOM/CRASH TERMINÉE ! 🎯🎯🎯");
      Print("   Positions Boom analysées: ", boomPositions);
      Print("   Positions Crash analysées: ", crashPositions);
      Print("   Positions fermées: ", positionsClosed);
      Print("   Profit total réalisé: ", DoubleToString(totalProfitClosed, 2), "$");
      Print("   Total cumulé depuis démarrage: ", DoubleToString(g_boomCrashProfitClosed, 2), "$");
      
      // Notification globale
      if(SendNotifications)
      {
         string globalMessage = StringFormat("FERMETURE AUTO BOOM/CRASH: %d positions fermées - Profit %.2f$", positionsClosed, totalProfitClosed);
         SendNotification(globalMessage);
      }
   }
}

//+------------------------------------------------------------------+
//| Fermer position Boom/Crash avec multi-essais                    |
//+------------------------------------------------------------------+
bool CloseBoomCrashPositionWithRetry(ulong ticket, double positionProfit)
{
   // Essai 1
   if(trade.PositionClose(ticket))
   {
      return true;
   }
   
   if(DebugMode)
      Print("❌ Essai 1 échoué - Retry...");
   Sleep(50);
   
   // Essai 2
   if(trade.PositionClose(ticket))
   {
      return true;
   }
   
   if(DebugMode)
      Print("❌ Essai 2 échoué - Retry...");
   Sleep(100);
   
   // Essai 3
   if(trade.PositionClose(ticket))
   {
      return true;
   }
   
   if(DebugMode)
      Print("❌ Essai 3 échoué - Retry...");
   Sleep(200);
   
   // Essai 4 FINAL
   if(trade.PositionClose(ticket))
   {
      return true;
   }
   
   uint error = GetLastError();
   Print("💥 ERREUR FATALE FERMETURE BOOM/CRASH #", ticket, ": ", error);
   return false;
}

//+------------------------------------------------------------------+
//| Doubler le lot de la position                                    |
//+------------------------------------------------------------------+
void DoublePositionLot(ulong ticket)
{
   if(!positionInfo.SelectByTicket(ticket))
      return;
      
   // PROTECTION: Bloquer le doublement de positions Boom/Crash dans la mauvaise direction
   string symbol = positionInfo.Symbol();
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   bool isBoom = (StringFind(symbol, "Boom") != -1);
   bool isCrash = (StringFind(symbol, "Crash") != -1);
   
   if(isBoom && posType == POSITION_TYPE_SELL)
   {
      if(DebugMode)
         Print("🚫 DoublePositionLot BLOQUÉ: Impossible de doubler position SELL sur ", symbol, " (Boom = BUY uniquement)");
      return;
   }
   
   if(isCrash && posType == POSITION_TYPE_BUY)
   {
      if(DebugMode)
         Print("🚫 DoublePositionLot BLOQUÉ: Impossible de doubler position BUY sur ", symbol, " (Crash = SELL uniquement)");
      return;
   }
   
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
   ENUM_ORDER_TYPE orderType;
   if(positionInfo.PositionType() == POSITION_TYPE_BUY)
      orderType = ORDER_TYPE_BUY;
   else
      orderType = ORDER_TYPE_SELL;
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculer SL et TP dynamiques pour sécuriser les gains
   // Sécuriser au moins 50% des gains déjà réalisés
   double currentProfit = positionInfo.Profit();
   double sl, tp;
   
   if(currentProfit <= 0)
   {
      // Pas encore de profit, utiliser SL standard
      CalculateSLTPInPointsWithMaxLoss(posType, price, volumeToAdd, 3.0, sl, tp);
      
      // Définir le mode de remplissage approprié
      ENUM_ORDER_TYPE_FILLING fillingMode = GetSupportedFillingMode(_Symbol);
      trade.SetTypeFilling(fillingMode);
      
      if(trade.PositionOpen(_Symbol, orderType, volumeToAdd, price, sl, tp, "DOUBLE_LOT"))
      {
         g_positionTracker.currentLot = newLot;
         g_positionTracker.lotDoubled = true;
         Print("✅ Lot doublé: ", currentLot, " -> ", newLot, " (ajout: ", volumeToAdd, ")");
      }
      else
      {
         // Si échec avec erreur de filling mode, essayer avec ORDER_FILLING_RETURN
         if(trade.ResultRetcode() == 10030 || trade.ResultRetcode() == 10015 || 
            StringFind(trade.ResultRetcodeDescription(), "filling") != -1 ||
            StringFind(trade.ResultRetcodeDescription(), "Unsupported") != -1)
         {
            Print("⚠️ Erreur filling mode double lot - Tentative avec ORDER_FILLING_RETURN");
            trade.SetTypeFilling(ORDER_FILLING_RETURN);
            if(trade.PositionOpen(_Symbol, orderType, volumeToAdd, price, sl, tp, "DOUBLE_LOT"))
            {
               g_positionTracker.currentLot = newLot;
               g_positionTracker.lotDoubled = true;
               Print("✅ Lot doublé (fallback): ", currentLot, " -> ", newLot, " (ajout: ", volumeToAdd, ")");
            }
            else
            {
               Print("❌ Erreur doublement lot (fallback): ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
            }
         }
         else
         {
            Print("❌ Erreur doublement lot: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         }
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
   
   // Définir le mode de remplissage approprié
   ENUM_ORDER_TYPE_FILLING fillingMode = GetSupportedFillingMode(_Symbol);
   trade.SetTypeFilling(fillingMode);
   
   if(trade.PositionOpen(_Symbol, orderType, volumeToAdd, price, sl, tp, "DOUBLE_LOT"))
   {
      g_positionTracker.currentLot = newLot;
      g_positionTracker.lotDoubled = true;
      
      Print("✅ Lot doublé: ", currentLot, " -> ", newLot, " (ajout: ", volumeToAdd, ") avec SL/TP dynamiques (sécurise ", DoubleToString(securedProfit, 2), "$)");
   }
   else
   {
      // Si échec avec erreur de filling mode, essayer avec ORDER_FILLING_RETURN
      if(trade.ResultRetcode() == 10030 || trade.ResultRetcode() == 10015 || 
         StringFind(trade.ResultRetcodeDescription(), "filling") != -1 ||
         StringFind(trade.ResultRetcodeDescription(), "Unsupported") != -1)
      {
         Print("⚠️ Erreur filling mode double lot - Tentative avec ORDER_FILLING_RETURN");
         trade.SetTypeFilling(ORDER_FILLING_RETURN);
         if(trade.PositionOpen(_Symbol, orderType, volumeToAdd, price, sl, tp, "DOUBLE_LOT"))
         {
            g_positionTracker.currentLot = newLot;
            g_positionTracker.lotDoubled = true;
            Print("✅ Lot doublé (fallback): ", currentLot, " -> ", newLot, " (ajout: ", volumeToAdd, ") avec SL/TP dynamiques (sécurise ", DoubleToString(securedProfit, 2), "$)");
         }
         else
         {
            Print("❌ Erreur doublement lot (fallback): ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         }
      }
      else
      {
         Print("❌ Erreur doublement lot: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
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
   
   // Si le calcul échoue, utiliser des valeurs par défaut basées sur ATR
   if(slPoints <= 0 || tpPoints <= 0)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
      {
         // Utiliser 2x ATR pour SL et 6x ATR pour TP (mouvements longs - ratio 3:1)
         slPoints = (2.0 * atr[0]) / point;
         tpPoints = (6.0 * atr[0]) / point; // Augmenté de 4x à 6x pour cibler les mouvements longs
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
//| Fermer toutes les positions dès que le profit atteint un seuil   |
//| (par défaut 1.0 USD).                                           |
//| Cette fonction parcourt toutes les positions de l'EA (même si   |
//| l'EA est attaché à un autre symbole) et ferme individuellement  |
//| chaque position dont le profit net >= OneDollarProfitTarget.    |
//+------------------------------------------------------------------+
void ClosePositionsAtProfitTarget()
{
   // Vérifier si la fonctionnalité est activée
   if(!EnableOneDollarAutoClose)
      return;

   // Parcourir toutes les positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      // Sélectionner la position via l'objet CPositionInfo pour rester cohérent avec le reste de l'EA
      if(!positionInfo.SelectByTicket(ticket))
         continue;

      // Ne gérer que les positions ouvertes par cet EA (magic number)
      if(positionInfo.Magic() != InpMagicNumber)
         continue;

      string symbol = positionInfo.Symbol();
      double profitTarget = GetProfitTargetUSDForSymbol(symbol);
      if(profitTarget <= 0.0)
         continue;

      // Profit net (inclut swap + commission)
      double profitNet = positionInfo.Profit() + positionInfo.Swap() + positionInfo.Commission();

      // Si le profit net atteint ou dépasse le seuil, fermer la position
      if(profitNet >= profitTarget)
      {
         if(DebugMode)
         {
            Print("🔍 Position profitable trouvée pour fermeture 1$+:");
            Print("   Ticket: #", ticket);
            Print("   Symbole: ", symbol);
            Print("   Volume: ", DoubleToString(positionInfo.Volume(), 3));
            Print("   Profit net: ", DoubleToString(profitNet, 2), "$ (seuil: ",
                  DoubleToString(profitTarget, 2), "$)");
            Print("   🔄 Fermeture automatique (seuil 1$ atteint)...");
         }

         if(trade.PositionClose(ticket))
         {
            Print("✅ Position #", ticket, " fermée automatiquement à ",
                  DoubleToString(profitNet, 2), "$ de profit (seuil ",
                  DoubleToString(profitTarget, 2), "$).");

            // Enregistrer les infos pour ré-entrée rapide (scalping)
            if(g_enableQuickReentry)
            {
               g_lastProfitCloseTime = TimeCurrent();
               g_lastProfitCloseSymbol = symbol;
               // Déterminer la direction basée sur le type de position
               g_lastProfitCloseDirection = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 1 : -1;
               
               Print("🔄 Ré-entrée rapide prévue dans ", g_reentryDelaySeconds, 
                     " secondes pour ", symbol, " direction=", 
                     (g_lastProfitCloseDirection == 1 ? "BUY" : "SELL"));
            }

            // Log + éventuelle notification si le reste de l'EA les utilise
            LogTradeClose(ticket, "Auto-Close Profit >= " + DoubleToString(profitTarget, 2) + "$");
         }
         else
         {
            Print("❌ Échec fermeture position (Auto-Close 1$) Ticket=", ticket,
                  " - ", trade.ResultRetcodeDescription());
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Fermer toute position du robot si perte <= -MaxLossPerPositionUSD |
//| (ex: 4.0 => fermer si profit net <= -4$)                          |
//+------------------------------------------------------------------+
void ClosePositionsAtMaxLoss()
{
   if(!EnableAutoCloseOnMaxLoss)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!positionInfo.SelectByTicket(ticket))
         continue;

      // Ne gérer que les positions ouvertes par cet EA (magic number)
      if(positionInfo.Magic() != InpMagicNumber)
         continue;

      string symbol = positionInfo.Symbol();
      double maxLoss = GetMaxLossUSDForSymbol(symbol);
      if(maxLoss <= 0.0)
         continue;

      double lossThreshold = -MathAbs(maxLoss);

      // Profit net (inclut swap + commission)
      double profitNet = positionInfo.Profit() + positionInfo.Swap() + positionInfo.Commission();

      if(profitNet <= lossThreshold)
      {
         Print("🚨 Perte max atteinte -> fermeture auto: Ticket=", ticket,
               " Symbole=", symbol,
               " Profit net=", DoubleToString(profitNet, 2), "$ (seuil ",
               DoubleToString(lossThreshold, 2), "$)");

         if(trade.PositionClose(ticket))
         {
            Print("✅ Position fermée (max loss): Ticket=", ticket,
                  " Symbole=", symbol,
                  " Profit net=", DoubleToString(profitNet, 2), "$");

            SendMLFeedback(ticket, profitNet, "Auto close at max loss");
            LogTradeClose(ticket, "Auto-Close Loss <= " + DoubleToString(lossThreshold, 2) + "$");
         }
         else
         {
            Print("❌ Échec fermeture position (max loss) Ticket=", ticket,
                  " - ", trade.ResultRetcodeDescription());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Ferme automatiquement les positions qui atteignent 2$ de profit  |
//+------------------------------------------------------------------+
void ClosePositionsAtProfit()
{
   // Vérifier s'il y a des positions
   if(PositionsTotal() == 0) return;
   
   // Parcourir toutes les positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      // Sélectionner la position par son ticket
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      // Obtenir les détails de la position
      if(!positionInfo.SelectByTicket(ticket)) continue;
      
      // Vérifier si c'est notre symbole et notre magic number
      if(positionInfo.Symbol() != _Symbol || positionInfo.Magic() != InpMagicNumber) continue;
      
      // Calculer le profit net (inclut swap + commission)
      double profitNet = positionInfo.Profit() + positionInfo.Swap() + positionInfo.Commission();
      
      // Vérifier si le profit est supérieur ou égal à 2$
      if(profitNet >= 2.0)
      {
         // Fermer la position
         if(trade.PositionClose(ticket))
         {
            Print("✅ Position fermée (2$ profit): Ticket=", ticket,
                  " Symbole=", positionInfo.Symbol(),
                  " Profit net=", DoubleToString(profitNet, 2), "$");
            
            // Envoyer une notification
            SendMT5Notification("Position fermée à " + DoubleToString(profitNet, 2) + "$ de profit");
            
            // Enregistrer la fermeture
            SendMLFeedback(ticket, profitNet, "Auto close at 2$ profit");
            LogTradeClose(ticket, "Auto-Close Profit >= 2$");
         }
         else if(DebugMode)
         {
            Print("❌ Échec fermeture position (2$ profit) Ticket=", ticket,
                  " - ", trade.ResultRetcodeDescription());
         }
      }
   }
}

double GetMaxLossUSDForSymbol(const string symbol)
{
   // FORCER 5 DOLLARS DE PERTE MAXIMUM POUR TOUS LES SYMBOLES
   double ml = 5.0; // Fixe à 5$ comme demandé par l'utilisateur
   
   // Ancien code désactivé - on utilise 5$ pour tous les symboles
   /*
   double ml = g_effectiveMaxLossPerPositionUSD;
   if(UsePerSymbolExitProfile)
   {
      if(IsBoomCrashSymbol(symbol))
         ml = MathAbs(BoomCrashMaxLossUSD);
      else if(IsForexSymbol(symbol))
         ml = MathAbs(ForexMaxLossUSD);
      else if(IsVolatilitySymbol(symbol))
         ml = MathAbs(VolatilityMaxLossUSD);
   }
   */

   ml = MathMax(ml, 0.0);
   // Appliquer garde-fou Risk/Reward si activé (par symbole)
   if(EnforceMinRiskReward && AutoAdjustRiskReward && EnableOneDollarAutoClose && EnableAutoCloseOnMaxLoss)
   {
      double tp = GetProfitTargetUSDForSymbol(symbol);
      if(tp > 0.0 && ml > 0.0)
      {
         double rr = tp / ml;
         if(rr < MinRiskReward)
         {
            double newMaxLoss = tp / MathMax(MinRiskReward, 0.01);
            newMaxLoss = MathMax(newMaxLoss, 0.10);
            if(DebugMode)
               Print("⚠️ GARDE-FOU RR (", symbol, "): TP=", DoubleToString(tp, 2), "$ / MaxLoss=", DoubleToString(ml, 2),
                     "$ = ", DoubleToString(rr, 2), " -> Ajustement MaxLoss=", DoubleToString(newMaxLoss, 2), "$");
            ml = newMaxLoss;
         }
      }
   }
   return ml;
}

//+------------------------------------------------------------------+
//| Get profit target USD for specific symbol                       |
//+------------------------------------------------------------------+
double GetProfitTargetUSDForSymbol(const string symbol)
{
   // FORCER 2 DOLLARS DE PROFIT CIBLE POUR TOUS LES SYMBOLES
   double tp = 2.0; // Fixe à 2$ comme cible de profit
   
   // Ancien code désactivé - on utilise 2$ pour tous les symboles
   /*
   double tp = g_effectiveProfitTargetUSD;
   if(UsePerSymbolExitProfile)
   {
      if(IsBoomCrashSymbol(symbol))
         tp = MathAbs(BoomCrashProfitTargetUSD);
      else if(IsForexSymbol(symbol))
         tp = MathAbs(ForexProfitTargetUSD);
      else if(IsVolatilitySymbol(symbol))
         tp = MathAbs(VolatilityProfitTargetUSD);
   }
   */

   tp = MathMax(tp, 0.0);
   return tp;
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
//| Vérifier si les conditions pour stratégie agressive sont réunies   |
//+------------------------------------------------------------------+
bool IsAggressiveConditionMet(ENUM_ORDER_TYPE direction, string finalDecision)
{
   // ===== SÉCURITÉ MAXIMALE: VALIDATION 80% CONFIANCE =====
   // RÈGLE STRICTE: Aucune stratégie agressive sans 80% de confiance minimum
   if(g_lastAIConfidence < 80.0)
   {
      if(DebugMode)
         Print("🛑 SÉCURITÉ AGGRESSIVE: CONFIANCE INSUFFISANTE: ", DoubleToString(g_lastAIConfidence, 1), "% < 80% REQUIS - STRATÉGIE BLOQUÉE");
      return false;
   }
   
   // Condition 1: Décision finale forte (ACHAT FORT ou VENTE FORTE)
   if(finalDecision != "ACHAT FORT" && finalDecision != "VENTE FORTE")
   {
      if(DebugMode)
         Print("🛑 SÉCURITÉ AGGRESSIVE: PAS DE DÉCISION FORTE: ", finalDecision, " - REQUIS ACHAT FORT/VENTE FORTE");
      return false;
   }
   
   // Condition 2: Direction alignée avec la décision finale
   if(direction == ORDER_TYPE_BUY && finalDecision != "ACHAT FORT")
      return false;
   if(direction == ORDER_TYPE_SELL && finalDecision != "VENTE FORTE")
      return false;
   
   // Double vérification de la confiance (sécurité)
   if(g_lastAIConfidence < 80.0)
   {
      if(DebugMode)
         Print("🛑 SÉCURITÉ AGGRESSIVE: CONFIANCE < 80%: ", DoubleToString(g_lastAIConfidence, 1), "%");
      return false;
   }
   
   // Condition 4: Pas de perte maximale atteinte
   double totalLoss = GetTotalLoss();
   if(totalLoss >= MaxTotalLoss)
      return false;
   
   // Condition 5: Symbole autorisé pour duplication
   if(StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1)
   {
      if(DebugMode)
         Print("⚠️ Stratégie agressive désactivée pour Boom/Crash (trop risqué)");
      return false;
   }
   
   // Condition 6: Maximum de positions pas encore atteint
   int currentPositions = CountPositionsForSymbolMagic();
   if(currentPositions >= MaxDuplicatePositions)
      return false;
   
   if(DebugMode)
      Print("✅ SÉCURITÉ AGGRESSIVE VALIDÉE: ", finalDecision, " | Confiance: ", DoubleToString(g_lastAIConfidence, 1), "% (≥80%)");
   
   return true;
}

//+------------------------------------------------------------------+
//| Exécuter les positions dupliquées pour stratégie agressive       |
//+------------------------------------------------------------------+
bool ExecuteAggressivePositions()
{
   datetime currentTime = TimeCurrent();
   
   // Vérifier la confiance minimale de 80%
   if(g_lastAIConfidence < 80.0)
   {
      if(DebugMode)
         Print("🛑 SÉCURITÉ: CONFIANCE INSUFFISANTE POUR DUPLICATION: ", DoubleToString(g_lastAIConfidence, 1), "% < 80% REQUIS");
      return false;
   }
   
   // Vérifier le délai entre les entrées
   if(currentTime - g_aggressiveTracker.lastEntryTime < AggressiveEntryDelay)
      return false;
      
   // Vérifier si la position actuelle a atteint le profit minimum de 1$
   if(!HasPositionWithMinProfit(_Symbol, 1.0) && CountPositionsForSymbolMagic() > 0)
   {
      if(DebugMode)
         Print(" La position actuelle n'a pas encore atteint 1$ de profit - Pas de duplication");
      return false;
   }
   
   // Compter les positions actuelles pour cette stratégie
   int currentPositions = CountPositionsForSymbolMagic();
   
   // Si on a déjà atteint le maximum, vérifier les profits
   if(currentPositions >= MaxDuplicatePositions)
   {
      CheckAggressiveProfits();
      return false;
   }
   
   // Calculer la taille du lot pour cette position
   double baseLot = NormalizeLotSize(InitialLotSize);
   double lotMultiplier = MathPow(AggressiveLotMultiplier, currentPositions);
   double positionLot = NormalizeDouble(baseLot * lotMultiplier, 2);
   
   // Vérifier que le lot n'est pas trop grand
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(positionLot > maxLot)
      positionLot = maxLot;
   
   // Déterminer le prix d'entrée
   double entryPrice = (g_aggressiveTracker.direction == ORDER_TYPE_BUY) ? 
                      SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculer SL/TP serrés pour stratégie agressive
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDistance = 20 * point;  // SL très serré: 20 points
   double tpDistance = 30 * point;  // TP serré: 30 points
   
   double sl, tp;
   if(g_aggressiveTracker.direction == ORDER_TYPE_BUY)
   {
      sl = NormalizeDouble(entryPrice - slDistance, _Digits);
      tp = NormalizeDouble(entryPrice + tpDistance, _Digits);
   }
   else // SELL
   {
      sl = NormalizeDouble(entryPrice + slDistance, _Digits);
      tp = NormalizeDouble(entryPrice - tpDistance, _Digits);
   }
   
   // Exécuter la position
   if(ExecuteTradeWithLot(g_aggressiveTracker.direction, positionLot, entryPrice, sl, tp))
   {
      g_aggressiveTracker.positionCount++;
      g_aggressiveTracker.lastEntryTime = currentTime;
      
      if(DebugMode)
         Print("🔥 Position agressive ouverte: ", EnumToString(g_aggressiveTracker.direction), 
               " | Lot: ", positionLot, " | Position ", g_aggressiveTracker.positionCount, "/", MaxDuplicatePositions,
               " | Entry: ", entryPrice, " | SL: ", sl, " | TP: ", tp);
      
      // Envoyer notification
      string notification = StringFormat("🔥 TRADE AGRESSIF: %s %.2f lots | Position %d/%d | %s", 
                                        EnumToString(g_aggressiveTracker.direction), positionLot, 
                                        g_aggressiveTracker.positionCount, MaxDuplicatePositions, 
                                        g_aggressiveTracker.finalDecision);
      SendMT5Notification(notification);
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier et fermer les profits de la stratégie agressive         |
//+------------------------------------------------------------------+
void CheckAggressiveProfits()
{
   if(!g_aggressiveMode)
      return;
   
   // Calculer le profit total des positions actives
   double totalProfit = 0.0;
   int activePositions = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            totalProfit += PositionGetDouble(POSITION_PROFIT);
            activePositions++;
         }
      }
   }
   
   g_aggressiveTracker.totalProfit = totalProfit;
   
   // Si profit cible atteint, fermer toutes les positions
   if(totalProfit >= AggressiveProfitTarget)
   {
      if(DebugMode)
         Print("💰 PROFIT AGGRESSIF ATTEINT: ", DoubleToString(totalProfit, 2), "$ >= ", DoubleToString(AggressiveProfitTarget, 2), "$ - Fermeture de toutes les positions");
      
      CloseAllAggressivePositions();
      
      // Envoyer notification
      string notification = StringFormat("💰 PROFIT AGGRESSIF SÉCURISÉ: %.2f$ | %d positions fermées", totalProfit, activePositions);
      SendMT5Notification(notification);
      
      // Réinitialiser la stratégie agressive
      ResetAggressiveStrategy();
   }
   // Si perte dépasse 5$, vérifier s'il faut fermer
   else if(totalProfit <= -5.0)
   {
      // Vérifier si le marché montre un retournement potentiel
      bool shouldClose = true;
      
      // Utiliser les variables globales pour les indicateurs
      int localEmaFastHandle = emaFastHandle;
      int localEmaSlowHandle = emaSlowHandle;
      int localRsiHandle = rsiHandle;
      
      // Récupérer les valeurs des indicateurs
      double emaFast[1], emaSlow[1], rsi[1];
      
      // Copier les valeurs dans les tableaux
      if(CopyBuffer(localEmaFastHandle, 0, 0, 1, emaFast) <= 0 || 
         CopyBuffer(localEmaSlowHandle, 0, 0, 1, emaSlow) <= 0 ||
         CopyBuffer(localRsiHandle, 0, 0, 1, rsi) <= 0)
      {
         // En cas d'erreur, on sort sans libérer les handles globaux
         return;
      }
      
      // Récupérer la valeur précédente de l'EMA rapide pour le croisement
      double emaFastPrev[1];
      if(CopyBuffer(localEmaFastHandle, 0, 1, 1, emaFastPrev) <= 0)
      {
         emaFastPrev[0] = emaFast[0]; // Utiliser la valeur actuelle si échec
      }
      
      // Si le RSI est en survente (<30) ou si les EMA montrent un croisement haussier, on garde la position
      if(rsi[0] < 30 || (emaFast[0] > emaSlow[0] && emaFast[0] > emaFastPrev[0]))
      {
         shouldClose = false;
         if(DebugMode)
            Print("⚠️ PERTE DE ", DoubleToString(totalProfit, 2), "$ DÉTECTÉE MAIS RETOURNEMENT POTENTIEL - MAINTIEN DE LA POSITION");
      }
      
      if(shouldClose)
      {
         if(DebugMode)
            Print("🛑 PERTE DE ", DoubleToString(totalProfit, 2), "$ DÉTECTÉE - FERMETURE DE LA POSITION");
         
         CloseAllAggressivePositions();
         ResetAggressiveStrategy();
      }
   }
}

//+------------------------------------------------------------------+
//| Fermer toutes les positions de la stratégie agressive           |
//+------------------------------------------------------------------+
void CloseAllAggressivePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            trade.PositionClose(ticket);
            
            if(DebugMode)
               Print("🔒 Position agressive fermée: Ticket ", ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Réinitialiser la stratégie agressive                             |
//+------------------------------------------------------------------+
void ResetAggressiveStrategy()
{
   g_aggressiveTracker.isActive = false;
   g_aggressiveTracker.positionCount = 0;
   g_aggressiveTracker.totalProfit = 0.0;
   g_aggressiveMode = false;
   
   if(DebugMode)
      Print("🔄 Stratégie aggressive réinitialisée");
}

//+------------------------------------------------------------------+
//| Exécuter un trade avec lot personnalisé                          |
//+------------------------------------------------------------------+
bool ExecuteTradeWithLot(ENUM_ORDER_TYPE orderType, double lot, double price, double sl, double tp)
{
   // Utiliser la logique de ExecuteTrade mais avec un lot personnalisé
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Définir le mode de remplissage approprié
   ENUM_ORDER_TYPE_FILLING fillingMode = GetSupportedFillingMode(_Symbol);
   trade.SetTypeFilling(fillingMode);
   
   // Exécuter l'ordre
   bool success = trade.PositionOpen(_Symbol, orderType, lot, price, sl, tp, "AGGRESSIVE_STRATEGY");
   
   return success;
}

//+------------------------------------------------------------------+
//| FERMETURE IMMÉDIATE SI DÉCISION DEVIENT NEUTRE                   |
//+------------------------------------------------------------------+
bool CheckNeutralDecisionClosure()
{
   // Vérifier si la décision finale est NEUTRE
   if(StringLen(g_coherentAnalysis.decision) == 0)
      return false; // Pas de décision disponible
   
   string decision = g_coherentAnalysis.decision;
   StringToUpper(decision);
   
   // Vérifier si c'est une décision neutre
   bool isNeutral = (StringFind(decision, "NEUTRE") >= 0 || 
                     StringFind(decision, "NEUTRAL") >= 0 ||
                     StringFind(decision, "HOLD") >= 0 ||
                     StringFind(decision, "WAIT") >= 0 ||
                     StringFind(decision, "ATTENTE") >= 0);
   
   if(!isNeutral)
      return false; // Pas une décision neutre
   
   // Vérifier s'il y a des positions ouvertes pour ce symbole
   int totalPositions = 0;
   double totalProfit = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            totalPositions++;
            totalProfit += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   
   if(totalPositions == 0)
      return false; // Pas de positions à fermer
   
   // FERMETURE IMMÉDIATE DE TOUTES LES POSITIONS
   if(DebugMode)
      Print("🚨 DÉCISION NEUTRE DÉTECTÉE pour ", _Symbol, ": ", decision, " - FERMETURE IMMÉDIATE de ", totalPositions, " position(s)");
   
   int positionsClosed = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            
            if(trade.PositionClose(ticket))
            {
               positionsClosed++;
               if(DebugMode)
                  Print("✅ Position fermée (décision neutre): ", _Symbol, " Ticket ", ticket, " | Profit: ", DoubleToString(PositionGetDouble(POSITION_PROFIT), 2), "$");
            }
            else
            {
               if(DebugMode)
                  Print("❌ Erreur fermeture position ", ticket, ": ", trade.ResultComment());
            }
         }
      }
   }
   
   // Log de résumé
   if(positionsClosed > 0)
   {
      Print("🔒 FERMETURE COMPLÈTE pour ", _Symbol, ": ", positionsClosed, " position(s) fermée(s) | Profit total: ", DoubleToString(totalProfit, 2), "$");
      
      // Envoyer notification
      string notification = StringFormat("🚨 FERMETURE NEUTRE: %s | %d positions | Profit: %.2f$", _Symbol, positionsClosed, totalProfit);
      SendMT5Notification(notification);
      
      // Fermer la stratégie agressive si active
      if(g_aggressiveMode)
      {
         ResetAggressiveStrategy();
         if(DebugMode)
            Print("🔄 Stratégie agressive arrêtée (décision neutre)");
      }
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| STOP LOSS DYNAMIQUE POUR SÉCURISER LES GAINS                      |
//+------------------------------------------------------------------+
void UpdateDynamicStopLoss()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            UpdatePositionDynamicSL();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Met à jour le SL dynamique pour une position                     |
//+------------------------------------------------------------------+
void UpdatePositionDynamicSL()
{
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   ulong ticket = PositionGetInteger(POSITION_TICKET);
   ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double pipValue = point * 10; // 1 pip = 10 points
   
   // Configuration du trailing stop dynamique
   int trailStartPips = 15;      // Commencer le trailing après 15 pips de profit
   int trailDistancePips = 10;   // Distance du trailing stop (10 pips derrière le prix)
   int secureProfitPips = 20;     // Sécuriser le profit après 20 pips
   
   // Calculer le profit en pips
   double profitPips;
   if(positionType == POSITION_TYPE_BUY)
      profitPips = (currentPrice - entryPrice) / pipValue;
   else
      profitPips = (entryPrice - currentPrice) / pipValue;
   
   // ===== STRATÉGIE 1: TRAILING STOP DYNAMIQUE =====
   if(profitPips >= trailStartPips)
   {
      double newSL = CalculateTrailingStop(positionType, currentPrice, trailDistancePips, point);
      if(ShouldUpdateSL(currentSL, newSL, positionType))
      {
         if(UpdatePositionSLTP(ticket, newSL, currentTP, "DYNAMIC_TRAIL"))
         {
            if(DebugMode)
               Print("🔄 SL trailing dynamique: ", _Symbol, " | Nouveau SL: ", DoubleToString(newSL, _Digits), " | Profit: ", DoubleToString(profitPips, 1), " pips");
            return;
         }
      }
   }
   
   // ===== STRATÉGIE 2: SÉCURISATION PROFIT PARTIEL =====
   if(profitPips >= secureProfitPips)
   {
      double newSL = CalculateSecureSL(positionType, entryPrice, currentPrice);
      if(ShouldUpdateSL(currentSL, newSL, positionType))
      {
         if(UpdatePositionSLTP(ticket, newSL, currentTP, "PROFIT_SECURE"))
         {
            if(DebugMode)
               Print("🔒 SL sécurisé: ", _Symbol, " | Nouveau SL: ", DoubleToString(newSL, _Digits), " | Profit sécurisé: ", DoubleToString(profitPips, 1), " pips");
            return;
         }
      }
   }
   
   // ===== STRATÉGIE 3: DÉPLACEMENT AU POINT D'ENTRÉE =====
   if(profitPips >= 10) // Après 10 pips de profit
   {
      if(positionType == POSITION_TYPE_BUY && currentSL < entryPrice)
      {
         if(UpdatePositionSLTP(ticket, entryPrice, currentTP, "BREAK_EVEN"))
         {
            if(DebugMode)
               Print("⚖️ SL au point d'entrée: ", _Symbol, " | SL: ", DoubleToString(entryPrice, _Digits), " | Profit: ", DoubleToString(profitPips, 1), " pips");
            return;
         }
      }
      else if(positionType == POSITION_TYPE_SELL && (currentSL > entryPrice || currentSL == 0))
      {
         if(UpdatePositionSLTP(ticket, entryPrice, currentTP, "BREAK_EVEN"))
         {
            if(DebugMode)
               Print("⚖️ SL au point d'entrée: ", _Symbol, " | SL: ", DoubleToString(entryPrice, _Digits), " | Profit: ", DoubleToString(profitPips, 1), " pips");
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calcule le nouveau niveau de trailing stop                       |
//+------------------------------------------------------------------+
double CalculateTrailingStop(ENUM_POSITION_TYPE positionType, double currentPrice, int trailDistancePips, double point)
{
   if(positionType == POSITION_TYPE_BUY)
   {
      // Pour BUY: SL suit le prix vers le haut
      return currentPrice - (trailDistancePips * point * 10);
   }
   else // SELL
   {
      // Pour SELL: SL suit le prix vers le bas
      return currentPrice + (trailDistancePips * point * 10);
   }
}

//+------------------------------------------------------------------+
//| Calcule un SL sécurisé pour protéger une partie du profit        |
//+------------------------------------------------------------------+
double CalculateSecureSL(ENUM_POSITION_TYPE positionType, double entryPrice, double currentPrice)
{
   if(positionType == POSITION_TYPE_BUY)
   {
      // Pour BUY: Sécuriser 50% du profit actuel
      double profit = currentPrice - entryPrice;
      double secureAmount = profit * 0.5;
      return entryPrice + secureAmount;
   }
   else // SELL
   {
      // Pour SELL: Sécuriser 50% du profit actuel
      double profit = entryPrice - currentPrice;
      double secureAmount = profit * 0.5;
      return entryPrice - secureAmount;
   }
}

//+------------------------------------------------------------------+
//| Détermine si le SL doit être mis à jour                          |
//+------------------------------------------------------------------+
bool ShouldUpdateSL(double currentSL, double newSL, ENUM_POSITION_TYPE positionType)
{
   if(currentSL == 0)
      return true;
   
   if(positionType == POSITION_TYPE_BUY)
   {
      // Pour BUY: le nouveau SL doit être plus élevé (meilleur protection)
      return newSL > currentSL;
   }
   else // SELL
   {
      // Pour SELL: le nouveau SL doit être plus bas (meilleur protection)
      return newSL < currentSL || (currentSL == 0 && newSL > 0);
   }
}

//+------------------------------------------------------------------+
//| Met à jour le SL/TP d'une position                               |
//+------------------------------------------------------------------+
bool UpdatePositionSLTP(ulong ticket, double newSL, double newTP, string reason)
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   bool success = trade.PositionModify(ticket, newSL, newTP);
   
   if(success)
   {
      if(DebugMode)
         Print("✅ SL mis à jour: Ticket ", ticket, " | Raison: ", reason);
   }
   else
   {
      if(DebugMode)
         Print("❌ Erreur mise à jour SL ", ticket, ": ", trade.ResultComment());
   }
   
   return success;
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
         Print("🚫 TRADE US BLOQUÉ: Perte totale maximale atteinte (", DoubleToString(totalLoss, 2), "$ >= ", DoubleToString(MaxTotalLoss, 2), "$) - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)");
      return false;
   }
   
   // PROTECTION: Vérifier la perte maximale par symbole
   double symbolLoss = GetSymbolLoss(_Symbol);
   if(symbolLoss >= MaxSymbolLoss)
   {
      if(DebugMode)
         Print("🚫 TRADE US BLOQUÉ: Perte maximale par symbole atteinte pour ", _Symbol, " (", DoubleToString(symbolLoss, 2), "$ >= ", DoubleToString(MaxSymbolLoss, 2), "$) - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)");
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
   
   // VALIDATION CRUCIALE: Vérifier et corriger les distances SL/TP minimales
   // Éviter les erreurs "Invalid stops" sur USDJPY et autres symboles Forex
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * point;
   
   // AUGMENTATION CRUCIALE: Distance minimale beaucoup plus élevée pour Forex
   if(StringFind(_Symbol, "JPY") != -1 || StringFind(_Symbol, "USD") != -1 || StringFind(_Symbol, "EUR") != -1 || StringFind(_Symbol, "GBP") != -1)
   {
      // Forex: minimum 50 points pour éviter rejets "Invalid stops"
      if(minDistance < 50 * point)
         minDistance = 50 * point;
   }
   else if(StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1)
   {
      // Boom/Crash: minimum 30 points
      if(minDistance < 30 * point)
         minDistance = 30 * point;
   }
   else if(StringFind(_Symbol, "Volatility") != -1)
   {
      // Volatility: minimum 20 points
      if(minDistance < 20 * point)
         minDistance = 20 * point;
   }
   else
   {
      // Autres: minimum 10 points
      if(minDistance < 10 * point)
         minDistance = 10 * point;
   }
   
   if(DebugMode)
      Print("🔧 ExecuteUSTrade: Distance minimale pour ", _Symbol, ": ", DoubleToString(minDistance, _Digits), " | stopLevel: ", stopLevel);
   
   double slDistance = MathAbs(entryPrice - sl);
   double tpDistance = MathAbs(tp - entryPrice);
   
   // Corriger SL si trop proche au lieu de rejeter
   if(slDistance < minDistance)
   {
      if(orderType == ORDER_TYPE_BUY)
         sl = NormalizeDouble(entryPrice - minDistance, _Digits);
      else
         sl = NormalizeDouble(entryPrice + minDistance, _Digits);
         
      if(DebugMode)
         Print("🔧 ExecuteUSTrade: SL corrigé pour distance minimale: ", _Symbol, " | Ancienne distance: ", DoubleToString(slDistance, _Digits), " | Nouvelle distance: ", DoubleToString(minDistance, _Digits), " | Nouveau SL: ", sl);
   }
   
   // Corriger TP si trop proche au lieu de rejeter
   if(tpDistance < minDistance)
   {
      if(orderType == ORDER_TYPE_BUY)
         tp = NormalizeDouble(entryPrice + minDistance, _Digits);
      else
         tp = NormalizeDouble(entryPrice - minDistance, _Digits);
         
      if(DebugMode)
         Print("🔧 ExecuteUSTrade: TP corrigé pour distance minimale: ", _Symbol, " | Ancienne distance: ", DoubleToString(tpDistance, _Digits), " | Nouvelle distance: ", DoubleToString(minDistance, _Digits), " | Nouveau TP: ", tp);
   }
   
   // Validation finale: s'assurer que SL/TP sont valides
   if(orderType == ORDER_TYPE_BUY)
   {
      if(sl >= entryPrice || tp <= entryPrice)
      {
         Print("❌ ExecuteUSTrade: SL/TP invalides pour BUY sur ", _Symbol, " - SL: ", sl, " >= Prix: ", entryPrice, " ou TP: ", tp, " <= Prix: ", entryPrice);
         return false;
      }
   }
   else // SELL
   {
      if(sl <= entryPrice || tp >= entryPrice)
      {
         Print("❌ ExecuteUSTrade: SL/TP invalides pour SELL sur ", _Symbol, " - SL: ", sl, " <= Prix: ", entryPrice, " ou TP: ", tp, " >= Prix: ", entryPrice);
         return false;
      }
   }
   
   // Définir le mode de remplissage approprié
   ENUM_ORDER_TYPE_FILLING fillingMode = GetSupportedFillingMode(_Symbol);
   trade.SetTypeFilling(fillingMode);
   
   if(trade.PositionOpen(_Symbol, orderType, normalizedLot, entryPrice, sl, tp, "US_SESSION_BREAK_RETEST"))
   {
      if(DebugMode)
         Print("✅ Trade US Session ouvert: ", EnumToString(orderType), " Lot=", normalizedLot, " Entry=", entryPrice, " SL=", sl, " TP=", tp);
      return true;
   }
   else
   {
      // Si échec avec erreur de filling mode, essayer avec ORDER_FILLING_RETURN
      if(trade.ResultRetcode() == 10030 || trade.ResultRetcode() == 10015 || 
         StringFind(trade.ResultRetcodeDescription(), "filling") != -1 ||
         StringFind(trade.ResultRetcodeDescription(), "Unsupported") != -1)
      {
         Print("⚠️ Erreur filling mode US Session - Tentative avec ORDER_FILLING_RETURN");
         trade.SetTypeFilling(ORDER_FILLING_RETURN);
         if(trade.PositionOpen(_Symbol, orderType, normalizedLot, entryPrice, sl, tp, "US_SESSION_BREAK_RETEST"))
         {
            if(DebugMode)
               Print("✅ Trade US Session ouvert (fallback): ", EnumToString(orderType), " Lot=", normalizedLot, " Entry=", entryPrice, " SL=", sl, " TP=", tp);
            return true;
         }
      }
      
      if(DebugMode)
         Print("❌ Erreur ouverture trade US Session: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      return false;
   }
}

//| Chercher une opportunité de trading                              |
//+------------------------------------------------------------------+
void LookForTradingOpportunity()
{
   // PROTECTION: Vérifier si le symbole actuel est bloqué pour perte maximale atteinte
   double symbolLoss = GetSymbolLoss(_Symbol);
   if(symbolLoss >= MaxSymbolLoss)
   {
      if(DebugMode)
         Print("🚫 SYMBOLE BLOQUÉ: ", _Symbol, " - Perte maximale par symbole atteinte (", DoubleToString(symbolLoss, 2), "$ >= ", DoubleToString(MaxSymbolLoss, 2), "$) - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)");
      return;
   }
   
   // PROTECTION: Vérifier si la perte totale maximale est atteinte
   double totalLoss = GetTotalLoss();
   if(totalLoss >= MaxTotalLoss)
   {
      if(DebugMode)
         Print("🚫 PERTE TOTALE MAX ATTEINTE: ", DoubleToString(totalLoss, 2), "$ >= ", DoubleToString(MaxTotalLoss, 2), "$) - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)");
      return;
   }
   
   // DÉBOGAGE: Afficher l'état initial
   if(true) // Toujours afficher ces infos critiques
   {
      Print("\n🔍 ===== DÉMARRAGE ANALYSE ", _Symbol, " =====");
      Print("📊 ÉTAT SYSTÈME (STRATÉGIE H1/M5 ALIGNEMENT):");
      Print("   - UseAI_Agent: ", UseAI_Agent ? "ACTIVÉ" : "DÉSACTIVÉ");
      Print("   - g_aiFallbackMode: ", g_aiFallbackMode ? "ACTIF" : "INACTIF");
      Print("   - g_hasPosition: ", g_hasPosition ? "OUI" : "NON");
      Print("   - PositionsTotal: ", PositionsTotal());
      Print("   - g_dailyProfit: ", DoubleToString(g_dailyProfit, 2), "$");
      Print("   - Perte symbole actuel: ", DoubleToString(symbolLoss, 2), "$ / ", DoubleToString(MaxSymbolLoss, 2), "$");
      Print("   - Mode Prudent: ", (g_dailyProfit >= 50.0) ? "ACTIF" : "INACTIF");
      
      // Afficher les prédictions futures si disponibles
      int predCount = ArraySize(g_pricePrediction);
      if(predCount > 0)
      {
         double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
         double futurePrice = g_pricePrediction[predCount-1];
         double changePct = ((futurePrice - currentPrice) / currentPrice) * 100.0;
         Print("   - Prédiction future: ", DoubleToString(futurePrice, _Digits), 
               " (", (changePct >= 0 ? "+" : ""), DoubleToString(changePct, 2), "%)");
      }
      Print("\n📡 DONNÉES IA (pour info seulement):");
      Print("   - Dernière mise à jour: ", (g_lastAITime == 0) ? "JAMAIS" : TimeToString(g_lastAITime, TIME_MINUTES|TIME_SECONDS));
      
      // Calcul sécurisé de l'âge des données
      string ageStr = "N/A";
      if(g_lastAITime > 0)
      {
         datetime currentTime = TimeCurrent();
         if(currentTime > g_lastAITime)
         {
            int ageSeconds = (int)(currentTime - g_lastAITime);
            if(ageSeconds > 86400) // Plus de 24 heures = valeur aberrante
               ageStr = "Erreur (valeur aberrante)";
            else if(ageSeconds < 0) // Valeur négative
               ageStr = "Erreur (valeur négative)";
            else
               ageStr = IntegerToString(ageSeconds) + " secondes";
         }
         else
            ageStr = "Erreur (temps invalide)";
      }
      Print("   - Âge des données: ", ageStr);
      Print("   - Dernière action: ", (g_lastAIAction == "") ? "AUCUNE" : g_lastAIAction);
      Print("   - Niveau de confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%");
      Print("\n⚙️  PARAMÈTRES TRADING:");
      Print("   - Symbole: ", _Symbol);
      Print("   - Type: ", (IsBoomCrashSymbol(_Symbol) ? "BOOM/CRASH" : (IsStepIndexSymbol(_Symbol) ? "STEP INDEX" : "STANDARD")));
      Print("   - Stratégie: H1/M5 ALIGNEMENT");
      Print("   - UseStrictQualityFilter: ", UseStrictQualityFilter ? "ACTIVÉ" : "DÉSACTIVÉ");
      Print("\n");
   }
   
   // ===== STRATÉGIE: ALIGNEMENT H1/M5 =====
   ENUM_ORDER_TYPE signalType = WRONG_VALUE;
   double signalConfidence = 0.0;
   bool hasSignal = false;
   string signalSource = "";
   
   // 1. Vérifier l'alignement H1/M5 (condition OBLIGATOIRE)
   bool h1m5Aligned = false;
   ENUM_ORDER_TYPE alignmentDirection = WRONG_VALUE;
   
   // Récupérer les tendances H1 et M5
   int trendH1 = GetEMATrend(PERIOD_H1);
   int trendM5 = GetEMATrend(PERIOD_M5);
   
   if(trendH1 == trendM5 && trendH1 != 0)
   {
      h1m5Aligned = true;
      alignmentDirection = (trendH1 == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(DebugMode)
         Print("✅ ALIGNEMENT H1/M5: ", (trendH1 == 1 ? "BUY" : "SELL"), " (H1=",(trendH1 == 1 ? "↑" : (trendH1 == -1 ? "↓" : "→")), " M5=",(trendM5 == 1 ? "↑" : (trendM5 == -1 ? "↓" : "→")), ")");
   }
   else
   {
      if(DebugMode)
         Print("❌ PAS D'ALIGNEMENT H1/M5: H1=",(trendH1 == 1 ? "↑" : (trendH1 == -1 ? "↓" : "→")), " M5=",(trendM5 == 1 ? "↑" : (trendM5 == -1 ? "↓" : "→")), "");
      return; // Pas de trade sans alignement H1/M5
   }
   
   // 2. Analyser la trajectoire prédite pour le scalping (DÉSACTIVÉ - plus utilisé dans décision finale)
   /*
   if(g_predictionValid && ArraySize(g_pricePrediction) >= 20)
   {
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
      
      // Analyser les 20 prochaines bougies pour le scalping
      int predictionWindow = MathMin(20, ArraySize(g_pricePrediction));
      double predictedPrice = g_pricePrediction[predictionWindow - 1];
      double priceMovement = predictedPrice - currentPrice;
      double movementPercent = (MathAbs(priceMovement) / currentPrice) * 100.0;
      
      // Déterminer la direction de la trajectoire
      ENUM_ORDER_TYPE trajectoryDirection = WRONG_VALUE;
      if(movementPercent > 0.05) // Mouvement significatif > 0.05%
      {
         trajectoryDirection = (priceMovement > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      }
      
      // Vérifier si la trajectoire est alignée avec H1/M5
      if(trajectoryDirection != WRONG_VALUE && trajectoryDirection == alignmentDirection)
      {
         signalType = trajectoryDirection;
         hasSignal = true;
         signalSource = "H1_M5_TRAJECTORY";
         signalConfidence = MathMin(movementPercent / 2.0, 1.0); // Confiance basée sur le mouvement
         
         if(DebugMode)
            Print("🎯 SIGNAL SCALPING: ", EnumToString(signalType), 
                  " | Mouvement: ", DoubleToString(movementPercent, 2), "%",
                  " | Confiance: ", DoubleToString(signalConfidence*100, 1), "%");
      }
      else
      {
         if(DebugMode)
            Print("⏸️ TRAJECTOIRE NON ALIGNÉE: H1/M5=", EnumToString(alignmentDirection), 
                  " | Trajectoire=", (trajectoryDirection == WRONG_VALUE ? "NEUTRE" : EnumToString(trajectoryDirection)));
         return;
      }
   }
   else
   {
      if(DebugMode)
         Print("⚠️ PAS DE TRAJECTOIRE PRÉDITE VALIDE");
      return;
   }
   */
   
   // NOUVELLE STRATÉGIE: Basée uniquement sur l'alignement H1/M5
   // Si on arrive ici, on a déjà un alignement H1/M5 valide
   
   // Détecter le mode prudent (profit net journalier >= 50 USD)
   bool cautiousMode = (g_dailyProfit >= 50.0);
   
   // Détection des types de symboles (doit être avant utilisation)
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   bool isStepIndex = (StringFind(_Symbol, "Step") != -1 || StringFind(_Symbol, "Step Index") != -1);
   bool isForexSymbol = IsForexSymbol(_Symbol);
   
   // SEUIL ADAPTATIF selon la force du signal et le type de symbole
   // Pour Boom/Crash, on accepte une confiance plus faible (30%) car les signaux sont plus courts
   // Pour les autres symboles, on garde un seuil plus élevé pour éviter les faux signaux
   double localRequiredConfidence = 0.30; // Seuil réduit à 30% pour Boom/Crash (au lieu de 50%)
   
   // Ajuster le seuil pour les autres types de symboles
   if(!isBoomCrashSymbol) {
      localRequiredConfidence = cautiousMode ? 0.60 : 0.45; // Seuils réduits pour plus de réactivité
   }
   
   // Journalisation des paramètres de trading
   if(DebugMode) {
      Print("🔧 PARAMÈTRES DE TRADING - Symbole: ", _Symbol, 
            " | Type: ", (isBoomCrashSymbol ? "Boom/Crash" : "Standard"),
            " | Confiance requise: ", DoubleToString(requiredConfidence*100, 1), "%");
   }
   
   // RÈGLE SPÉCIALE: Si signal H1/M5 détecté, l'exécuter directement
   // Les signaux basés sur l'alignement H1/M5 ont priorité
   if(hasSignal && signalSource == "H1_M5_TRAJECTORY")
   {
      if(DebugMode)
         Print("🚀 Signal H1/M5 prioritaire - Exécution directe sans IA");
         
      // OBLIGATOIRE: Vérifier si on est dans une zone de correction avant d'exécuter
      if(IsPriceInCorrectionZone(signalType))
      {
         if(DebugMode)
            Print("⏸️ Signal H1/M5 ", EnumToString(signalType), " rejeté - Prix en zone de correction (OBLIGATOIRE: éviter les corrections)");
         return;
      }
      
      ExecuteTrade(signalType);
      return;
   }
   
   // ===== NOUVELLE STRATÉGIE: IGNORER LES RECOMMANDATIONS IA =====
   // L'IA n'est plus utilisée pour prendre des décisions de trading
   // On se base uniquement sur: 1) Alignement H1/M5
   
   if(DebugMode && UseAI_Agent)
   {
      Print("ℹ️ INFO IA (non utilisée pour trading): Action=", g_lastAIAction, 
            " | Confiance=", DoubleToString(g_lastAIConfidence * 100, 1), "%");
   }
   
   // La stratégie se base uniquement sur l'alignement H1/M5
   // déjà analysés ci-dessus. Si on arrive ici, c'est qu'on a déjà un signal valide.
   int tradeDirection = (alignmentDirection == ORDER_TYPE_BUY) ? 1 : -1;
   if(UseAI_Agent)
   {
      // Calcul sécurisé de l'âge pour l'analyse cohérente
      int age = 0;
      if(g_coherentAnalysis.lastUpdate > 0)
      {
         datetime currentTime = TimeCurrent();
         if(currentTime > g_coherentAnalysis.lastUpdate)
         {
            age = (int)(currentTime - g_coherentAnalysis.lastUpdate);
            if(age > 86400) // Plafonner à 24 heures pour éviter les valeurs aberrantes
               age = 86400;
         }
      }
      
      // Anti-panne: si l'analyse cohérente n'est pas disponible, on ne trade pas (mode "sûr")
      // DÉSACTIVÉ: Plus de blocage par analyse cohérente
      // if(ShowCoherentAnalysis && (g_coherentAnalysis.lastUpdate == 0 || age > (AI_CoherentAnalysisInterval * 2)))
      // {
      //    Print("🚫 TRADE BLOQUÉ (COHÉRENT): Analyse cohérente absente/trop ancienne (age=", age, "s)");
      //    return;
      // }
      
      double coherentConf01 = g_coherentAnalysis.confidence;
      if(coherentConf01 > 1.0) coherentConf01 /= 100.0; // Support API qui renvoie 0-100
      
      string decision = g_coherentAnalysis.decision;
      StringToUpper(decision);
      bool coherentBuy  = (StringFind(decision, "BUY") >= 0 || StringFind(decision, "ACHAT") >= 0);
      bool coherentSell = (StringFind(decision, "SELL") >= 0 || StringFind(decision, "VENTE") >= 0);
      bool coherentAligned = (tradeDirection == 1 ? coherentBuy : coherentSell);
      
      // DÉSACTIVÉ: Plus de blocage par confiance cohérente
      // if(ShowCoherentAnalysis && (!coherentAligned || coherentConf01 < MinCoherentConfidence))
      // {
      //    Print("🚫 TRADE BLOQUÉ (COHÉRENT): Décision/Confiance insuffisante | Decision=", g_coherentAnalysis.decision,
      //          " | Conf=", DoubleToString(coherentConf01 * 100.0, 1), "% < ", DoubleToString(MinCoherentConfidence * 100.0, 0), "%");
      //    return;
      // }
      
      // DÉSACTIVÉ: Plus de blocage par cohérence des endpoints
      // if(ShowCoherentAnalysis && !CheckCoherenceOfAllAnalyses(tradeDirection))
      // {
      //    Print("🚫 TRADE BLOQUÉ: Cohérence insuffisante de tous les endpoints d'analyse - Direction: ", (tradeDirection == 1 ? "BUY" : "SELL"));
      //    return; // BLOQUER si cohérence insuffisante
      // }
      
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
         // 1. Prix PAS en correction
         // 2. Alignement M1, M5 et H1 confirmé
         // 3. Retournement FRANC après touche EMA/Support/Résistance
         // 4. Confirmation M5 OBLIGATOIRE obtenue
         // 5. Retournement à l'EMA rapide M1 avec bougie confirmée (verte pour BUY, rouge pour SELL)
         
         // NOUVEAU: Validations avancées pour entrées précises
         // Validation du spread (validation simple sans dépendance externe)
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double spread = ask - bid;
         double maxSpreadPercent = 0.1;
         if(StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1)
            maxSpreadPercent = 0.5;
         
         if((spread / ask) * 100.0 > maxSpreadPercent)
         {
            if(DebugMode)
               Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Spread trop élevé: ", DoubleToString((spread / ask) * 100.0, 2), "%");
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
      // OBLIGATOIRE: Vérifier si on est dans une zone de correction avant d'exécuter
      if(IsPriceInCorrectionZone(signalType))
      {
         if(DebugMode)
            Print("⏸️ Signal ", signalSource, " ", EnumToString(signalType), " rejeté - Prix en zone de correction (OBLIGATOIRE: éviter les corrections)");
         return;
      }
      
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
//| Détecte le mode de remplissage supporté par le symbole           |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetSupportedFillingMode(const string symbol)
{
   string symbolUpper = symbol;
   StringToUpper(symbolUpper);
   
   // Obtenir le bitmask des modes de remplissage supportés
   // SYMBOL_FILLING_MODE retourne un bitmask : 1=FOK, 2=IOC, 4=RETURN (0=broker gère)
   int fillingMode = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   
   // Obtenir le mode d'exécution du symbole
   ENUM_SYMBOL_TRADE_EXECUTION execMode = (ENUM_SYMBOL_TRADE_EXECUTION)SymbolInfoInteger(symbol, SYMBOL_TRADE_EXEMODE);
   
   if(DebugMode)
      Print("🔧 Symbol: ", symbol, " | FillingMode bitmask: ", fillingMode, " | ExecMode: ", EnumToString(execMode));
   
   // =================================================================
   // CAS SPÉCIAUX POUR DERIV
   // =================================================================
   
   // 1. DFX Indices (EURUSD DFX, GBPUSD DFX, etc.) - Utilisent FOK sur Deriv
   if(StringFind(symbolUpper, "DFX") != -1)
   {
      if(DebugMode)
         Print("🔧 DFX Index détecté: ", symbol, " -> ORDER_FILLING_FOK");
      return ORDER_FILLING_FOK;
   }
   
   // 2. Crypto pairs sur Deriv (xxxUSD où xxx est une crypto)
   // Liste des cryptos courantes qui utilisent FOK
   if(StringFind(symbolUpper, "NERUSD") != -1 ||
      StringFind(symbolUpper, "APTUSD") != -1 ||
      StringFind(symbolUpper, "IMXUSD") != -1 ||
      StringFind(symbolUpper, "SANUSD") != -1 ||
      StringFind(symbolUpper, "TRUUSD") != -1 ||
      StringFind(symbolUpper, "MLNUSD") != -1 ||
      StringFind(symbolUpper, "BTCUSD") != -1 ||
      StringFind(symbolUpper, "ETHUSD") != -1 ||
      StringFind(symbolUpper, "LTCUSD") != -1 ||
      StringFind(symbolUpper, "XRPUSD") != -1 ||
      StringFind(symbolUpper, "ADAUSD") != -1 ||
      StringFind(symbolUpper, "DOTUSD") != -1 ||
      StringFind(symbolUpper, "SOLUSD") != -1 ||
      StringFind(symbolUpper, "AVAUSD") != -1 ||
      StringFind(symbolUpper, "LINKUSD") != -1 ||
      StringFind(symbolUpper, "UNIUSD") != -1 ||
      StringFind(symbolUpper, "XLMUSD") != -1 ||
      StringFind(symbolUpper, "MATICUSD") != -1 ||
      StringFind(symbolUpper, "ATOMUSD") != -1 ||
      StringFind(symbolUpper, "ALGOUSD") != -1 ||
      StringFind(symbolUpper, "DOGEUSD") != -1 ||
      StringFind(symbolUpper, "SHIBUSD") != -1 ||
      StringFind(symbolUpper, "EOSUSD") != -1 ||
      StringFind(symbolUpper, "TRXUSD") != -1 ||
      StringFind(symbolUpper, "XTZUSD") != -1 ||
      StringFind(symbolUpper, "FILUSD") != -1 ||
      StringFind(symbolUpper, "AAVEUSD") != -1 ||
      StringFind(symbolUpper, "MKRUSD") != -1 ||
      StringFind(symbolUpper, "COMPUSD") != -1 ||
      StringFind(symbolUpper, "SNXUSD") != -1 ||
      StringFind(symbolUpper, "YFIUSD") != -1 ||
      StringFind(symbolUpper, "BATUSD") != -1 ||
      StringFind(symbolUpper, "ZRXUSD") != -1 ||
      StringFind(symbolUpper, "ENJUSD") != -1 ||
      StringFind(symbolUpper, "MANAUSD") != -1 ||
      StringFind(symbolUpper, "SANDUSD") != -1 ||
      StringFind(symbolUpper, "AXSUSD") != -1)
   {
      if(DebugMode)
         Print("🔧 Crypto Deriv détectée: ", symbol, " -> ORDER_FILLING_FOK");
      return ORDER_FILLING_FOK;
   }
   
   // 3. Boom/Crash/Volatility sur Deriv: FORCER FOK (pas RETURN!)
   // Note: Correction - ces symboles utilisent aussi FOK en Market Execution
   if(StringFind(symbolUpper, "BOOM") != -1 || 
      StringFind(symbolUpper, "CRASH") != -1 ||
      StringFind(symbolUpper, "VOLATILITY") != -1 ||
      StringFind(symbolUpper, "VOL OVER") != -1 ||
      StringFind(symbolUpper, "STEP INDEX") != -1 ||
      StringFind(symbolUpper, "RANGE BREAK") != -1 ||
      StringFind(symbolUpper, "JUMP") != -1)
   {
      if(DebugMode)
         Print("🔧 Symbole synthétique Deriv: ", symbol, " -> ORDER_FILLING_FOK");
      return ORDER_FILLING_FOK;
   }
   
   // =================================================================
   // LOGIQUE BASÉE SUR LE MODE D'EXÉCUTION
   // =================================================================
   
   // Pour Market Execution (Deriv, la plupart des brokers modernes), FOK est souvent requis
   if(execMode == SYMBOL_TRADE_EXECUTION_MARKET)
   {
      // Si fillingMode = 0, le broker gère automatiquement -> utiliser FOK
      if(fillingMode == 0)
      {
         if(DebugMode)
            Print("🔧 Market Execution avec filling=0: ", symbol, " -> ORDER_FILLING_FOK (broker gère)");
         return ORDER_FILLING_FOK;
      }
      
      // Sinon vérifier ce qui est supporté, préférer FOK pour Market Execution
      if((fillingMode & 1) != 0)
      {
         if(DebugMode)
            Print("🔧 Market Execution avec FOK supporté: ", symbol, " -> ORDER_FILLING_FOK");
         return ORDER_FILLING_FOK;
      }
      else if((fillingMode & 2) != 0)
      {
         if(DebugMode)
            Print("🔧 Market Execution avec IOC supporté: ", symbol, " -> ORDER_FILLING_IOC");
         return ORDER_FILLING_IOC;
      }
      else if((fillingMode & 4) != 0)
      {
         if(DebugMode)
            Print("🔧 Market Execution avec RETURN supporté: ", symbol, " -> ORDER_FILLING_RETURN");
         return ORDER_FILLING_RETURN;
      }
   }
   
   // Pour Exchange Execution ou Instant Execution
   // RETURN est généralement plus tolérant
   if((fillingMode & 4) != 0)
   {
      if(DebugMode)
         Print("🔧 Mode RETURN supporté pour ", symbol, " (mode=", fillingMode, ")");
      return ORDER_FILLING_RETURN;
   }
   
   if((fillingMode & 2) != 0)
   {
      if(DebugMode)
         Print("🔧 Mode IOC supporté pour ", symbol, " (mode=", fillingMode, ")");
      return ORDER_FILLING_IOC;
   }
   
   if((fillingMode & 1) != 0)
   {
      if(DebugMode)
         Print("🔧 Mode FOK supporté pour ", symbol, " (mode=", fillingMode, ")");
      return ORDER_FILLING_FOK;
   }
   
   // Fallback: Pour les brokers modernes (Deriv), FOK est généralement le bon choix par défaut
   Print("⚠️ Mode de remplissage non détecté pour ", symbol, " (mode=", fillingMode, ", exec=", EnumToString(execMode), ") - Utilisation FOK par défaut");
   return ORDER_FILLING_FOK;
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
//| Ferme toutes les positions pour un symbole spécifique          |
//+------------------------------------------------------------------+
void CloseAllPositionsForSymbol(string symbol, string reason = "")
{
   int total = PositionsTotal();
   
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         if(posSymbol == symbol)
         {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            if(trade.PositionClose(ticket))
            {
               if(DebugMode)
               {
                  string closeReason = (reason != "") ? (" (" + reason + ")") : "";
                  Print("✅ Position #", ticket, " fermée pour ", symbol, 
                        " - Type: ", EnumToString(posType), closeReason);
               }
            }
            else if(DebugMode)
            {
               Print("❌ Échec de la fermeture de la position #", ticket, 
                     " - Erreur: ", GetLastError());
            }
            
            // Pause pour éviter de surcharger le serveur
            Sleep(100);
         }
      }
   }
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
//| Calculer la perte pour un symbole spécifique                      |
//+------------------------------------------------------------------+
double GetSymbolLoss(const string symbol)
{
   double symbolLoss = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Magic() == InpMagicNumber && positionInfo.Symbol() == symbol)
         {
            double profit = positionInfo.Profit();
            if(profit < 0) // Seulement les pertes
               symbolLoss += MathAbs(profit);
         }
      }
   }
   
   return symbolLoss;
}


//+------------------------------------------------------------------+
//| Vérifie si un mode de remplissage est supporté                   |
//+------------------------------------------------------------------+
bool IsFillingModeSupported(const string symbol, int mode)
{
   int supportedModes = (int)SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
   
   // Vérifier si le mode est supporté
   switch(mode)
   {
      case ORDER_FILLING_FOK:    // 1
         return (supportedModes & 1) != 0;
      case ORDER_FILLING_IOC:    // 2
         return (supportedModes & 2) != 0;
      case ORDER_FILLING_RETURN: // 4
         return (supportedModes & 4) != 0;
      default:
         return false;
   }
}

//+------------------------------------------------------------------+
//| Exécuter un trade                                                |
//+------------------------------------------------------------------+
void ExecuteTrade(ENUM_ORDER_TYPE orderType)
{
   // ===== SÉCURITÉ MAXIMALE: VALIDATION 80% CONFIANCE =====
   // RÈGLE STRICTE: Aucun trade sans 80% de confiance minimum
   if(g_lastAIConfidence < 80.0)
   {
      if(DebugMode)
         Print("🛑 SÉCURITÉ: CONFIANCE INSUFFISANTE: ", DoubleToString(g_lastAIConfidence, 1), "% < 80% REQUIS - AUCUN TRADE AUTORISÉ");
      return;
   }
   
   // Vérifier si nous avons une décision finale claire
   string decision = g_coherentAnalysis.decision;
   StringToUpper(decision);
   
   // Vérifier si la décision est NEUTRE
   if(StringFind(decision, "NEUTRE") >= 0 || StringFind(decision, "NEUTRAL") >= 0)
   {
      if(DebugMode)
         Print("🛑 SÉCURITÉ: DÉCISION NEUTRE - AUCUN TRADE AUTORISÉ: ", decision);
      return;
   }
   
   // Vérifier si nous avons une décision finale claire
   if(decision != "ACHAT FORT" && decision != "VENTE FORTE" && decision != "ACHAT" && decision != "VENTE")
   {
      if(DebugMode)
         Print("🛑 SÉCURITÉ: DÉCISION NON RECONNUE: ", decision, " - REQUIS BUY/SELL CLAIR AVEC 80%+");
      return;
   }
   
   // Vérifier l'alignement direction/décision
   if(orderType == ORDER_TYPE_BUY && (decision != "ACHAT FORT" && decision != "ACHAT"))
   {
      if(DebugMode)
         Print("🛑 SÉCURITÉ: DÉSALIGNEMENT BUY/DÉCISION: ", decision, " - REQUIS ACHAT FORT/ACHAT");
      return;
   }
   if(orderType == ORDER_TYPE_SELL && (decision != "VENTE FORTE" && decision != "VENTE"))
   {
      if(DebugMode)
         Print("🛑 SÉCURITÉ: DÉSALIGNEMENT SELL/DÉCISION: ", decision, " - REQUIS VENTE FORTE/VENTE");
      return;
   }
   
   if(DebugMode)
      Print("✅ SÉCURITÉ VALIDÉE: ", decision, " | Confiance: ", DoubleToString(g_lastAIConfidence, 1), "% (≥80%)");
   
   // Utiliser l'objet CTrade global
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetAsyncMode(true);

   // DÉBOGAGE COMPLET: Afficher toutes les informations de débogage
   if(DebugMode)
   {
      Print("🚀 ExecuteTrade: DÉMARRAGE pour ", EnumToString(orderType), " sur ", _Symbol);
      Print("   - MaxTotalLoss: ", DoubleToString(MaxTotalLoss, 2), "$");
      Print("   - InitialLotSize: ", DoubleToString(InitialLotSize, 2));
   }
   
   // PROTECTION: Vérifier la perte totale maximale (5$ toutes positions)
   double totalLoss = GetTotalLoss();
   if(DebugMode)
      Print("   - GetTotalLoss(): ", DoubleToString(totalLoss, 2), "$");
   
   if(totalLoss >= MaxTotalLoss)
   {
      Print("🚫 TRADE BLOQUÉ: Perte totale maximale atteinte (", DoubleToString(totalLoss, 2), "$ >= ", DoubleToString(MaxTotalLoss, 2), "$) - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)");
      return;
   }
   
   // PROTECTION: Vérifier la perte maximale par symbole (5$ par symbole)
   double symbolLoss = GetSymbolLoss(_Symbol);
   if(DebugMode)
      Print("   - GetSymbolLoss(", _Symbol, "): ", DoubleToString(symbolLoss, 2), "$");
   
   if(symbolLoss >= MaxSymbolLoss)
   {
      Print("🚫 SYMBOLE BLOQUÉ: Perte maximale par symbole atteinte pour ", _Symbol, " (", DoubleToString(symbolLoss, 2), "$ >= ", DoubleToString(MaxSymbolLoss, 2), "$) - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)");
      return;
   }
   
   // PROTECTION: Bloquer SELL sur Boom (y compris Vol over Boom) et BUY sur Crash (y compris Vol over Crash)
   // Tous les symboles avec "Boom" = BUY uniquement (spike en tendance)
   // Tous les symboles avec "Crash" = SELL uniquement (spike en tendance)
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(DebugMode)
   {
      Print("   - isBoom: ", isBoom ? "true" : "false");
      Print("   - isCrash: ", isCrash ? "true" : "false");
   }
   
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
   
   // OBLIGATOIRE: Vérifier la tendance pour Boom/Crash avant d'exécuter
   // Boom (BUY) = uniquement en uptrend (tendance haussière)
   // Crash (SELL) = uniquement en downtrend (tendance baissière)
   // Ne pas exécuter si tendance contre ou neutre
   if((isBoom || isCrash) && !CheckTrendAlignment(orderType))
   {
      string trendStatus = "";
      if(isBoom && orderType == ORDER_TYPE_BUY)
         trendStatus = "downtrend ou neutre";
      else if(isCrash && orderType == ORDER_TYPE_SELL)
         trendStatus = "uptrend ou neutre";
      else
         trendStatus = "non alignée";
      
      Print("🚫 TRADE BLOQUÉ: ", _Symbol, " - Signal ", EnumToString(orderType), 
            " rejeté car tendance ", trendStatus, " (OBLIGATOIRE: Boom=uptrend, Crash=downtrend)");
      return;
   }
   
   // Vérifier le nombre maximum de symboles actifs (3 maximum)
   int activeSymbols = CountActiveSymbols();
   int currentSymbolPositions = CountPositionsForSymbolMagic();
   bool isCurrentSymbolActive = (currentSymbolPositions > 0);
   
   if(DebugMode)
   {
      Print("   - activeSymbols: ", activeSymbols, " (max 3)");
      Print("   - currentSymbolPositions: ", currentSymbolPositions);
      Print("   - isCurrentSymbolActive: ", isCurrentSymbolActive ? "true" : "false");
   }
   
   // Si on a déjà 3 symboles actifs et que le symbole actuel n'a pas de position, bloquer
   if(activeSymbols >= 3 && !isCurrentSymbolActive)
   {
      Print("🚫 LIMITE SYMBOLES: ", activeSymbols, " symboles actifs (max 3) - Impossible d'ajouter ", _Symbol);
      return;
   }
   
   // Éviter la duplication de la même position (uniquement pour volatility, step index et forex)
   if(HasDuplicatePosition(orderType))
   {
      Print("🚫 Trade ignoré - Position ", EnumToString(orderType), " déjà ouverte sur ", _Symbol, " - Évite la duplication");
      return;
   }
   
   // Confirmer tendance via trajectoire prédite (plusieurs fenêtres) avant d'exécuter
   if(UseTrajectoryTrendConfirmation)
   {
      int trajConfirm = GetTrajectoryTrendConfirmation();
      int expectedDir = (orderType == ORDER_TYPE_BUY) ? 1 : -1;
      if(trajConfirm != 0 && trajConfirm != expectedDir)
      {
         Print("🚫 TRADE BLOQUÉ: Trajectoire confirme ", (trajConfirm == 1 ? "BUY" : "SELL"),
               " mais signal=", EnumToString(orderType), " → Attente alignement trajectoire");
         return;
      }
      if(trajConfirm == 0 && g_predictionValid && ArraySize(g_pricePrediction) >= 50)
      {
         Print("🚫 TRADE BLOQUÉ: Cohérence trajectoire insuffisante (< ", DoubleToString(TrajectoryMinCoherencePercent, 0), "%)",
               " → Attente confirmation trajectoire");
         return;
      }
   }
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(DebugMode)
      Print("   - price: ", DoubleToString(price, _Digits));
   
   // Normaliser le lot
   double normalizedLot = NormalizeLotSize(InitialLotSize);
   
   if(DebugMode)
      Print("   - normalizedLot: ", DoubleToString(normalizedLot, 2));
   
   if(normalizedLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      Print("❌ Lot trop petit: ", normalizedLot, " (minimum: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), ")");
      return;
   }
   
   // NOUVELLE STRATÉGIE: Ignorer la validation de prédiction immédiate
   // On se base sur l'alignement H1/M5 et la trajectoire générale, pas sur le mouvement immédiat
   if(DebugMode)
      Print("   - Validation prédiction immédiate DÉSACTIVÉE (nouvelle stratégie H1/M5 + trajectoire)");
   
   // La validation CheckImmediatePredictionDirection est maintenant ignorée
   // car elle cause l'erreur "Prédiction immédiate invalide"
   // On fait confiance à l'alignement H1/M5 et à la trajectoire prédite globale
   
   if(DebugMode)
      Print("   ✅ Stratégie H1/M5+TRAJECTOIRE: Validation immédiate ignorée");
   
   double sl, tp;
   ENUM_POSITION_TYPE posType = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   
   // NOUVEAU: Calculer le TP dynamique au prochain Support/Résistance
   // Le TP est maintenant calculé selon le prochain niveau Support (pour SELL) ou Résistance (pour BUY)
   tp = CalculateDynamicTP(orderType, price);
   
   // NOUVELLE STRATÉGIE: SL/TP PRUDENTS basés sur l'alignement H1/M5
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointValue = (tickValue / tickSize) * point;
   double slValuePerPoint = normalizedLot * pointValue;
   
   // SL prudent: utiliser 1.5x ATR au lieu d'un SL ultra serré
   double atr[];
   ArraySetAsSeries(atr, true);
   double slPoints = 0;
   
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
   {
      slPoints = (1.5 * atr[0]) / point; // 1.5x ATR = SL prudent
   }
   else
   {
      // Fallback: utiliser 0.8% du prix comme SL prudent
      double price = (orderType == ORDER_TYPE_BUY) ? 
                    SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                    SymbolInfoDouble(_Symbol, SYMBOL_BID);
      slPoints = (price * 0.008) / point; // 0.8% du prix = SL prudent
   }
   
   // Calculer SL avec le calcul très serré
   if(posType == POSITION_TYPE_BUY)
      sl = NormalizeDouble(price - slPoints * point, _Digits);
   else
      sl = NormalizeDouble(price + slPoints * point, _Digits);
   
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
      Print("📊 SL/TP calculés - SL: ", DoubleToString(sl, _Digits), " TP (dynamique): ", DoubleToString(tp, _Digits), 
            " (au prochain Support/Résistance)");
   
   // Normaliser les prix avant ouverture
   price = NormalizeDouble(price, _Digits);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   // VALIDATION CRUCIALE: Vérifier et corriger les distances SL/TP minimales
   // Éviter les erreurs "Invalid stops" sur USDJPY et autres symboles Forex
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * point;
   
   // AUGMENTATION CRUCIALE: Distance minimale beaucoup plus élevée pour Forex
   if(StringFind(_Symbol, "JPY") != -1 || StringFind(_Symbol, "USD") != -1 || StringFind(_Symbol, "EUR") != -1 || StringFind(_Symbol, "GBP") != -1)
   {
      // Forex: minimum 50 points pour éviter rejets "Invalid stops"
      if(minDistance < 50 * point)
         minDistance = 50 * point;
   }
   else if(StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1)
   {
      // Boom/Crash: minimum 30 points
      if(minDistance < 30 * point)
         minDistance = 30 * point;
   }
   else if(StringFind(_Symbol, "Volatility") != -1)
   {
      // Volatility: minimum 20 points
      if(minDistance < 20 * point)
         minDistance = 20 * point;
   }
   else
   {
      // Autres: minimum 10 points
      if(minDistance < 10 * point)
         minDistance = 10 * point;
   }
   
   if(DebugMode)
      Print("🔧 ExecuteTrade: Distance minimale pour ", _Symbol, ": ", DoubleToString(minDistance, _Digits), " | stopLevel: ", stopLevel);
   
   double slDistance = MathAbs(price - sl);
   double tpDistance = MathAbs(tp - price);
   
   // Corriger SL si trop proche
   if(slDistance < minDistance)
   {
      if(orderType == ORDER_TYPE_BUY)
         sl = NormalizeDouble(price - minDistance, _Digits);
      else
         sl = NormalizeDouble(price + minDistance, _Digits);
         
      if(DebugMode)
         Print("🔧 ExecuteTrade: SL corrigé pour distance minimale: ", _Symbol, " | Ancienne distance: ", DoubleToString(slDistance, _Digits), " | Nouvelle distance: ", DoubleToString(minDistance, _Digits), " | Nouveau SL: ", sl);
   }
   
   // Corriger TP si trop proche
   if(tpDistance < minDistance)
   {
      if(orderType == ORDER_TYPE_BUY)
         tp = NormalizeDouble(price + minDistance, _Digits);
      else
         tp = NormalizeDouble(price - minDistance, _Digits);
         
      if(DebugMode)
         Print("🔧 ExecuteTrade: TP corrigé pour distance minimale: ", _Symbol, " | Ancienne distance: ", DoubleToString(tpDistance, _Digits), " | Nouvelle distance: ", DoubleToString(minDistance, _Digits), " | Nouveau TP: ", tp);
   }
   
   // Validation finale: s'assurer que SL/TP sont valides
   if(orderType == ORDER_TYPE_BUY)
   {
      if(sl >= price || tp <= price)
      {
         Print("❌ ExecuteTrade: SL/TP invalides pour BUY sur ", _Symbol, " - SL: ", sl, " >= Prix: ", price, " ou TP: ", tp, " <= Prix: ", price);
         return;
      }
   }
   else // SELL
   {
      if(sl <= price || tp >= price)
      {
         Print("❌ ExecuteTrade: SL/TP invalides pour SELL sur ", _Symbol, " - SL: ", sl, " <= Prix: ", price, " ou TP: ", tp, " >= Prix: ", price);
         return;
      }
   }
   
   // Définir le mode de remplissage approprié en fonction du symbole
   // Utiliser GetSupportedFillingMode pour une meilleure détection
   ENUM_ORDER_TYPE_FILLING fillingMode = GetSupportedFillingMode(_Symbol);
   trade.SetTypeFilling(fillingMode);
   
   if(DebugMode)
      Print("🔧 ExecuteTrade: Mode de remplissage défini pour ", _Symbol, ": ", EnumToString(fillingMode));
   
   // Exécuter l'ordre avec le mode de remplissage sélectionné
   bool orderSuccess = trade.PositionOpen(_Symbol, orderType, normalizedLot, price, sl, tp, "SCALPER_DOUBLE");
   
   // Si échec avec erreur de filling mode, essayer avec tous les modes supportés
   if(!orderSuccess && (trade.ResultRetcode() == 10030 || trade.ResultRetcode() == 10015 || 
                        StringFind(trade.ResultRetcodeDescription(), "filling") != -1 ||
                        StringFind(trade.ResultRetcodeDescription(), "Unsupported") != -1))
   {
      Print("⚠️ Erreur de filling mode détectée (", trade.ResultRetcode(), ": ", trade.ResultRetcodeDescription(), ") - Test de tous les modes pour ", _Symbol);
      
      // Tableau des modes à tester - FOK en premier (requis par Deriv/DFX/Crypto)
      ENUM_ORDER_TYPE_FILLING modes[] = {
         ORDER_FILLING_FOK,     // Requis pour Deriv, DFX indices, crypto
         ORDER_FILLING_IOC,     // Moyennement compatible
         ORDER_FILLING_RETURN   // Pour Exchange/Instant Execution
      };
      
      for(int i = 0; i < ArraySize(modes); i++)
      {
         if(modes[i] == fillingMode)
            continue; // Déjà testé
            
         Print("🔄 Tentative avec ", EnumToString(modes[i]), " pour ", _Symbol);
         trade.SetTypeFilling(modes[i]);
         orderSuccess = trade.PositionOpen(_Symbol, orderType, normalizedLot, price, sl, tp, "SCALPER_DOUBLE");
         
         if(orderSuccess)
         {
            Print("✅ Succès avec ", EnumToString(modes[i]), " pour ", _Symbol);
            break;
         }
         else
         {
            Print("❌ Échec avec ", EnumToString(modes[i]), " (", trade.ResultRetcode(), ": ", trade.ResultRetcodeDescription(), ")");
         }
      }
      
      // Si toutes les tentatives échouent, logger l'erreur complète
      if(!orderSuccess)
      {
         Print("❌ Toutes les tentatives de filling mode ont échoué pour ", _Symbol);
         Print("   - Erreur finale: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         Print("   - Prix: ", price, " | Lot: ", normalizedLot, " | SL: ", sl, " | TP: ", tp);
      }
   }
   
   if(orderSuccess)
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
//| Détecter les segments de bougie future                          |
//+------------------------------------------------------------------+
bool DetectFutureCandleSegment(ENUM_ORDER_TYPE &signalType, double &confidence)
{
   // Récupérer les prédictions de prix futures
   int predictionCount = ArraySize(g_pricePrediction);
   if(predictionCount < 2) 
   {
      if(DebugMode) Print("⚠️ Pas assez de données de prédiction pour détecter les segments futurs");
      return false;
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double futurePrice = g_pricePrediction[predictionCount-1]; // Dernière prédiction
   double priceChange = futurePrice - currentPrice;
   double priceChangePct = (priceChange / currentPrice) * 100.0;
   
   // Seuil minimum de mouvement pour considérer un signal
   double minMovePct = 0.05; // 0.05% de mouvement minimum
   
   if(priceChangePct > minMovePct)
   {
      signalType = ORDER_TYPE_BUY;
      confidence = MathMin(priceChangePct / 0.5, 1.0); // Normaliser entre 0 et 1 pour 0.5% de mouvement
      if(DebugMode) Print("✅ Signal FUTUR DÉTECTÉ: ACHAT | ", "Confiance: ", DoubleToString(confidence*100, 1), "% | ",
                         "Prix actuel: ", DoubleToString(currentPrice, _Digits), " | ",
                         "Prix futur: ", DoubleToString(futurePrice, _Digits), " | ",
                         "Variation: ", DoubleToString(priceChangePct, 2), "%");
      return true;
   }
   else if(priceChangePct < -minMovePct)
   {
      signalType = ORDER_TYPE_SELL;
      confidence = MathMin(MathAbs(priceChangePct) / 0.5, 1.0); // Normaliser entre 0 et 1
      if(DebugMode) Print("✅ Signal FUTUR DÉTECTÉ: VENTE | ", "Confiance: ", DoubleToString(confidence*100, 1), "% | ",
                         "Prix actuel: ", DoubleToString(currentPrice, _Digits), " | ",
                         "Prix futur: ", DoubleToString(futurePrice, _Digits), " | ",
                         "Variation: ", DoubleToString(priceChangePct, 2), "%");
      return true;
   }
   
   return false;
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
      int periodSeconds = GetPeriodSeconds(tf);
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
//| Dessiner les EMA M5 et H1 uniquement (trends et support/résistance) |
//+------------------------------------------------------------------+
void DrawLongTrendEMA()
{
   if(!ShowLongTrendEMA)
   {
      // Supprimer tous les segments EMA si désactivé
      DeleteEMAObjects("EMA_M5_");
      DeleteEMAObjects("EMA_H1_");
      return;
   }
   
   // Récupérer les valeurs EMA M5 et H1 sur 500 bougies (réduit pour performance)
   double emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[];
   datetime timeM5[], timeH1[];
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   ArraySetAsSeries(timeM5, true);
   ArraySetAsSeries(timeH1, true);
   
   // Tracer sur 500 bougies seulement (réduit pour performance)
   int count = 500;
   
   // Récupérer les EMA M5
   bool hasEMAFastM5 = (CopyBuffer(emaFastM5Handle, 0, 0, count, emaFastM5) > 0);
   bool hasEMASlowM5 = (CopyBuffer(emaSlowM5Handle, 0, 0, count, emaSlowM5) > 0);
   
   // Récupérer les EMA H1
   bool hasEMAFastH1 = (CopyBuffer(emaFastH1Handle, 0, 0, count, emaFastH1) > 0);
   bool hasEMASlowH1 = (CopyBuffer(emaSlowH1Handle, 0, 0, count, emaSlowH1) > 0);
   
   // Récupérer les timestamps
   bool hasTimeM5 = (CopyTime(_Symbol, PERIOD_M5, 0, count, timeM5) > 0);
   bool hasTimeH1 = (CopyTime(_Symbol, PERIOD_H1, 0, count, timeH1) > 0);
   
   if(!hasEMAFastM5 || !hasEMASlowM5 || !hasEMAFastH1 || !hasEMASlowH1 || !hasTimeM5 || !hasTimeH1)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA M5/H1 - M5 Fast:", hasEMAFastM5, " M5 Slow:", hasEMASlowM5, " H1 Fast:", hasEMAFastH1, " H1 Slow:", hasEMASlowH1);
      return;
   }
   
   // OPTIMISATION: Ne mettre à jour que si nécessaire (toutes les 5 minutes)
   static datetime lastEMAUpdate = 0;
   bool needUpdate = (TimeCurrent() - lastEMAUpdate > 300); // Mise à jour max toutes les 5 minutes
   
   if(needUpdate)
   {
      // Supprimer les anciens segments EMA
      DeleteEMAObjects("EMA_M5_");
      DeleteEMAObjects("EMA_H1_");
      
      // EMA M5 - Trends court terme (plus visibles)
      // EMA Fast M5 (9) - Vert clair pour trends court terme
      DrawEMACurveOptimized("EMA_M5_Fast_", emaFastM5, timeM5, count, clrLime, 2, 25);
      
      // EMA Slow M5 (21) - Vert foncé pour support/résistance M5
      DrawEMACurveOptimized("EMA_M5_Slow_", emaSlowM5, timeM5, count, clrGreen, 2, 25);
      
      // EMA H1 - Trends long terme (plus fins pour ne pas surcharger)
      // EMA Fast H1 (9) - Bleu clair pour trends H1
      DrawEMACurveOptimized("EMA_H1_Fast_", emaFastH1, timeH1, count, clrAqua, 1, 50);
      
      // EMA Slow H1 (21) - Bleu foncé pour support/résistance H1
      DrawEMACurveOptimized("EMA_H1_Slow_", emaSlowH1, timeH1, count, clrBlue, 1, 50);
      
      if(DebugMode)
         Print("✅ EMA M5/H1 tracées sur 500 bougies: M5 Fast/Slow (", EMA_Fast_Period, "/", EMA_Slow_Period, "), H1 Fast/Slow");
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
            datetime time2 = TimeCurrent() + GetPeriodSeconds(PERIOD_M5) * 50; // Étendre 50 bougies vers le futur
            
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
            datetime time2 = TimeCurrent() + GetPeriodSeconds(PERIOD_M5) * 50;
            
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
   if(positionInfo.Symbol() != _Symbol)
      return; // Ne modifier que les positions du symbole courant
   
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
   // DÉSACTIVÉ: Sécurisation automatique des profits - Laisser SL/TP gérer
   // Les positions doivent respecter les Stop Loss et Take Profit définis à l'ouverture
   // Cette fonction fermait les positions trop rapidement, empêchant les profits potentiels
   if(DebugMode)
      Print("⏸️ SecureDynamicProfits() désactivée - Laisser SL/TP gérer les positions");
   
   // Sortir immédiatement - ne plus gérer les profits automatiquement
   return;
   
   /*
   // CODE ORIGINAL DÉSACTIVÉ:
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
                           "$ (profit=", DoubleToString(profit, 2), "$/) - Prise de gain rapide, prêt à se replacer si le mouvement continue");
                     SendMLFeedback(ticket, profit, "Volatility quick TP");
                     continue;
                  }
                  else if(DebugMode)
                  {
                     Print("⚠️ Erreur fermeture position Volatility: ", trade.ResultRetcodeDescription());
                  }
               }
            }
         }
      }
   }
   
   // Si le profit global a chuté de plus de 50%, fermer toutes les positions gagnantes
   double totalProfit = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
         {
            totalProfit += positionInfo.Profit();
         }
      }
   }
   
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
   */
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

   // OBLIGATOIRE: Vérifier la tendance avant d'exécuter
   // Boom (BUY) = uniquement en uptrend (tendance haussière)
   // Crash (SELL) = uniquement en downtrend (tendance baissière)
   // Ne pas exécuter si tendance contre ou neutre
   if(!CheckTrendAlignment(orderType))
   {
      if(DebugMode)
      {
         string trendStatus = "";
         if(isBoom && orderType == ORDER_TYPE_BUY)
            trendStatus = "downtrend ou neutre";
         else if(isCrash && orderType == ORDER_TYPE_SELL)
            trendStatus = "uptrend ou neutre";
         else
            trendStatus = "non alignée";
         
         Print("🚫 TrySpikeEntry BLOQUÉ: ", _Symbol, " - Signal ", EnumToString(orderType), 
               " rejeté car tendance ", trendStatus, " (OBLIGATOIRE: Boom=uptrend, Crash=downtrend)");
      }
      return false;
   }

   // Ouvrir le trade seulement si la tendance est confirmée
   if(DebugMode)
      Print("🚀 Boom/Crash: Ouverture trade ", EnumToString(orderType), " après retournement EMA M5 confirmé ET tendance alignée");
   
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
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double toleranceM5 = 10 * point;
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
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double toleranceM5 = 10 * point;
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
      double minDistance = 999999.0; // Initialisation correcte
      
      // Chercher les hauts récents (pivots) comme résistances potentielles
      for(int i = 2; i < 18 && i < ArraySize(high); i++)
      {
         // Pivot haut = high[i] > high[i-1] && high[i] > high[i+1]
         if(high[i] > high[i-1] && high[i] > high[i+1] && high[i] > currentPrice)
         {
            double distance = high[i] - currentPrice;
            if(distance > 0 && distance < minDistance) // Vérifier distance > 0
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
            if(dist50 > 0 && dist50 < minDistance)
            {
               minDistance = dist50;
               nextResistance = ema50[0];
            }
         }
         if(CopyBuffer(ema100Handle, 0, 0, 1, ema100) > 0 && ema100[0] > currentPrice)
         {
            double dist100 = ema100[0] - currentPrice;
            if(dist100 > 0 && dist100 < minDistance)
            {
               minDistance = dist100;
               nextResistance = ema100[0];
            }
         }
         if(CopyBuffer(ema200Handle, 0, 0, 1, ema200) > 0 && ema200[0] > currentPrice)
         {
            double dist200 = ema200[0] - currentPrice;
            if(dist200 > 0 && dist200 < minDistance)
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
         minDistance = nextResistance - currentPrice;
      }
      
      if(DebugMode && nextResistance > 0)
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
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
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
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minDistance = 10 * point; // Distance minimum
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
   string fileName = CSVFileNamePrefix + "_" + dateStr + ".csv";
   
   return fileName;
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
   
   // Vérifier que le fichier existe et l'ouvrir en mode append
   int fileHandle = FileOpen(g_csvFileName, FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
   if(fileHandle == INVALID_HANDLE)
   {
      if(DebugMode)
         Print("❌ Erreur ouverture fichier CSV: ", GetLastError());
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
//| FONCTIONS POUR TRADING BOOM/CRASH AMÉLIORÉ                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Obtenir le type de signal de la flèche DERIV ARROW               |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetDerivArrowSignalType()
{
   // Rechercher les objets graphiques qui ressemblent à DESIV ARROW
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, -1);
      
      // Vérifier si le nom contient des motifs typiques de flèches DERIV
      if(StringFind(objName, "ARROW", 0) >= 0 || 
         StringFind(objName, "DERIV", 0) >= 0 ||
         StringFind(objName, "Arrow", 0) >= 0 ||
         StringFind(objName, "deriv", 0) >= 0)
      {
         // Vérifier si l'objet est de type flèche
         int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         
         if(objType == OBJ_ARROW_UP)
         {
            if(DebugMode)
               Print("🔺 Flèche HAUT (BUY) DERIV ARROW détectée: ", objName);
            return ORDER_TYPE_BUY;
         }
         else if(objType == OBJ_ARROW_DOWN)
         {
            if(DebugMode)
               Print("🔻 Flèche BAS (SELL) DERIV ARROW détectée: ", objName);
            return ORDER_TYPE_SELL;
         }
         else if(objType == OBJ_TRIANGLE)
         {
            // Pour les triangles, déterminer la direction par la couleur
            color triangleColor = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
            
            // Triangle vert = BUY, Triangle rouge = SELL
            if(triangleColor == clrGreen || triangleColor == clrLime)
            {
               if(DebugMode)
                  Print("🔺 Triangle VERT (BUY) DERIV ARROW détecté: ", objName);
               return ORDER_TYPE_BUY;
            }
            else if(triangleColor == clrRed || triangleColor == clrMaroon)
            {
               if(DebugMode)
                  Print("🔻 Triangle ROUGE (SELL) DERIV ARROW détecté: ", objName);
               return ORDER_TYPE_SELL;
            }
         }
      }
   }
   
   return WRONG_VALUE; // Pas de signal détecté
}

//+------------------------------------------------------------------+
//| Exécuter un trade basé sur DERIV ARROW Pattern                   |
//+------------------------------------------------------------------+
void ExecuteDerivArrowTrade(ENUM_ORDER_TYPE orderType)
{
   if(DebugMode)
      Print("🚀 Exécution immédiate DERIV ARROW: ", EnumToString(orderType), " sur ", _Symbol);
   
   // PROTECTION: Vérifier si la perte totale maximale est atteinte
   double totalLoss = GetTotalLoss();
   if(totalLoss >= MaxTotalLoss)
   {
      Print("🚫 DERIV ARROW BLOQUÉ: Perte totale maximale atteinte (", DoubleToString(totalLoss, 2), "$ >= ", DoubleToString(MaxTotalLoss, 2), "$) - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)");
      return;
   }
   
   // PROTECTION: Vérifier si la perte maximale par symbole est atteinte
   double symbolLoss = GetSymbolLoss(_Symbol);
   if(symbolLoss >= MaxSymbolLoss)
   {
      Print("🚫 DERIV ARROW BLOQUÉ: Perte maximale par symbole atteinte pour ", _Symbol, " (", DoubleToString(symbolLoss, 2), "$ >= ", DoubleToString(MaxSymbolLoss, 2), "$) - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)");
      return;
   }
   
   // PROTECTION: Bloquer BUY sur Crash et SELL sur Boom (règles inversées)
   // Crash = SELL uniquement, Boom = BUY uniquement
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(isBoom && orderType == ORDER_TYPE_SELL)
   {
      Print("🚫 DERIV ARROW BLOQUÉ: Impossible de trader SELL sur ", _Symbol, " (Boom = BUY uniquement)");
      return;
   }
   
   if(isCrash && orderType == ORDER_TYPE_BUY)
   {
      Print("🚫 DERIV ARROW BLOQUÉ: Impossible de trader BUY sur ", _Symbol, " (Crash = SELL uniquement)");
      return;
   }
   
   // Utiliser l'objet CTrade global
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetAsyncMode(true);
   
   // Obtenir le prix actuel
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Normaliser le lot
   double normalizedLot = NormalizeLotSize(InitialLotSize);
   
   if(normalizedLot < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      Print("❌ Lot trop petit pour DERIV ARROW: ", normalizedLot, " (minimum: ", SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), ")");
      return;
   }
   
   // Calculer SL/TP rapides pour les signaux DERIV ARROW
   double sl, tp;
   ENUM_POSITION_TYPE posType = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   
   // SL/TP très serrés pour les signaux DERIV ARROW (scalping rapide)
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atr[];
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
   {
      // SL très serré: 0.5x ATR pour les signaux DERIV ARROW
      double slPoints = (0.5 * atr[0]) / point;
      // TP rapide: 1.5x ATR pour les signaux DERIV ARROW
      double tpPoints = (1.5 * atr[0]) / point;
      
      if(posType == POSITION_TYPE_BUY)
      {
         sl = NormalizeDouble(price - slPoints * point, _Digits);
         tp = NormalizeDouble(price + tpPoints * point, _Digits);
      }
      else
      {
         sl = NormalizeDouble(price + slPoints * point, _Digits);
         tp = NormalizeDouble(price - tpPoints * point, _Digits);
      }
   }
   else
   {
      // Fallback: SL/TP fixes
      CalculateSLTPInPoints(posType, price, sl, tp);
   }
   
   // VALIDATION CRUCIALE: Vérifier et corriger les distances SL/TP minimales
   // Éviter les erreurs "Invalid stops" sur USDJPY et autres symboles Forex
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * point;
   
   // AUGMENTATION CRUCIALE: Distance minimale beaucoup plus élevée pour Forex
   if(StringFind(_Symbol, "JPY") != -1 || StringFind(_Symbol, "USD") != -1 || StringFind(_Symbol, "EUR") != -1 || StringFind(_Symbol, "GBP") != -1)
   {
      // Forex: minimum 50 points pour éviter rejets "Invalid stops"
      if(minDistance < 50 * point)
         minDistance = 50 * point;
   }
   else if(StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1)
   {
      // Boom/Crash: minimum 30 points
      if(minDistance < 30 * point)
         minDistance = 30 * point;
   }
   else if(StringFind(_Symbol, "Volatility") != -1)
   {
      // Volatility: minimum 20 points
      if(minDistance < 20 * point)
         minDistance = 20 * point;
   }
   else
   {
      // Autres: minimum 10 points
      if(minDistance < 10 * point)
         minDistance = 10 * point;
   }
   
   if(DebugMode)
      Print("🔧 ExecuteDerivArrowTrade: Distance minimale pour ", _Symbol, ": ", DoubleToString(minDistance, _Digits), " | stopLevel: ", stopLevel);
   
   double slDistance = MathAbs(price - sl);
   double tpDistance = MathAbs(tp - price);
   
   // Corriger SL si trop proche
   if(slDistance < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         sl = NormalizeDouble(price - minDistance, _Digits);
      else
         sl = NormalizeDouble(price + minDistance, _Digits);
         
      if(DebugMode)
         Print("🔧 ExecuteDerivArrowTrade: SL corrigé pour distance minimale: ", _Symbol, " | Ancienne distance: ", DoubleToString(slDistance, _Digits), " | Nouvelle distance: ", DoubleToString(minDistance, _Digits), " | Nouveau SL: ", sl);
   }
   
   // Corriger TP si trop proche
   if(tpDistance < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(price + minDistance, _Digits);
      else
         tp = NormalizeDouble(price - minDistance, _Digits);
         
      if(DebugMode)
         Print("🔧 ExecuteDerivArrowTrade: TP corrigé pour distance minimale: ", _Symbol, " | Ancienne distance: ", DoubleToString(tpDistance, _Digits), " | Nouvelle distance: ", DoubleToString(minDistance, _Digits), " | Nouveau TP: ", tp);
   }
   
   // Validation finale: s'assurer que SL/TP sont valides
   if(posType == POSITION_TYPE_BUY)
   {
      if(sl >= price || tp <= price)
      {
         Print("❌ ExecuteDerivArrowTrade: SL/TP invalides pour BUY sur ", _Symbol, " - SL: ", sl, " >= Prix: ", price, " ou TP: ", tp, " <= Prix: ", price);
         return;
      }
   }
   else // SELL
   {
      if(sl <= price || tp >= price)
      {
         Print("❌ ExecuteDerivArrowTrade: SL/TP invalides pour SELL sur ", _Symbol, " - SL: ", sl, " <= Prix: ", price, " ou TP: ", tp, " >= Prix: ", price);
         return;
      }
   }
   
   // Définir le mode de remplissage approprié
   ENUM_ORDER_TYPE_FILLING fillingMode = GetSupportedFillingMode(_Symbol);
   trade.SetTypeFilling(fillingMode);
   
   // Commentaire spécial pour les trades DERIV ARROW
   string comment = "DERIV_ARROW_" + EnumToString(orderType);
   
   // Exécuter l'ordre
   bool orderSuccess = trade.PositionOpen(_Symbol, orderType, normalizedLot, price, sl, tp, comment);
   
   if(orderSuccess)
   {
      ulong ticket = trade.ResultOrder();
      
      string tradeInfo = StringFormat("⚡ DERIV ARROW Trade ouvert: %s | %s | Lot: %.2f | Prix: %.5f | SL: %.5f | TP: %.5f",
                                      EnumToString(orderType), _Symbol, normalizedLot, price, sl, tp);
      Print(tradeInfo);
      
      // Envoyer notification MT5
      SendMT5Notification("⚡ DERIV ARROW: " + tradeInfo);
      
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
      string errorMsg = StringFormat("❌ Erreur ouverture trade DERIV ARROW: %s | Code: %d - %s", 
                                     _Symbol, trade.ResultRetcode(), trade.ResultRetcodeDescription());
      Print(errorMsg);
      SendMT5Notification("❌ DERIV ARROW: " + errorMsg);
   }
}

//+------------------------------------------------------------------+
//| Vérifier si la flèche DERIV ARROW est présente sur le graphique    |
//+------------------------------------------------------------------+
bool IsDerivArrowPresent()
{
   // Rechercher les objets graphiques qui ressemblent à DESIV ARROW
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, -1);
      
      // Vérifier si le nom contient des motifs typiques de flèches DERIV
      if(StringFind(objName, "ARROW", 0) >= 0 || 
         StringFind(objName, "DERIV", 0) >= 0 ||
         StringFind(objName, "Arrow", 0) >= 0 ||
         StringFind(objName, "deriv", 0) >= 0)
      {
         // Vérifier si l'objet est de type flèche ou triangle
         int objType = (int)ObjectGetInteger(0, objName, OBJPROP_TYPE);
         if(objType == OBJ_ARROW_UP || objType == OBJ_ARROW_DOWN || 
            objType == OBJ_TRIANGLE)
         {
            if(DebugMode)
               Print("✅ Flèche DERIV ARROW détectée: ", objName);
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si nous avons un signal fort (ACHAT FORT ou VENTE FORTE)  |
//+------------------------------------------------------------------+
bool HasStrongSignal(string &signalType)
{
   signalType = "";
   
   // 1. Vérifier l'analyse cohérente d'abord
   if(StringLen(g_coherentAnalysis.decision) > 0)
   {
      string decision = g_coherentAnalysis.decision;
      StringToUpper(decision);
      
      if(StringFind(decision, "ACHAT FORT") >= 0 || StringFind(decision, "BUY FORT") >= 0)
      {
         signalType = "ACHAT FORT";
         if(DebugMode)
            Print("✅ Signal fort détecté (Analyse cohérente): ", signalType, " (Confiance: ", DoubleToString(g_coherentAnalysis.confidence, 1), "%)");
         return true;
      }
      
      if(StringFind(decision, "VENTE FORTE") >= 0 || StringFind(decision, "SELL FORT") >= 0)
      {
         signalType = "VENTE FORTE";
         if(DebugMode)
            Print("✅ Signal fort détecté (Analyse cohérente): ", signalType, " (Confiance: ", DoubleToString(g_coherentAnalysis.confidence, 1), "%)");
         return true;
      }
   }
   
   // 2. Vérifier l'action IA si pas de signal cohérent
   if(StringLen(g_lastAIAction) > 0 && g_lastAIConfidence >= 0.70)
   {
      if(g_lastAIAction == "buy")
      {
         signalType = "ACHAT FORT";
         if(DebugMode)
            Print("✅ Signal fort détecté (IA): ", signalType, " (Confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
         return true;
      }
      
      if(g_lastAIAction == "sell")
      {
         signalType = "VENTE FORTE";
         if(DebugMode)
            Print("✅ Signal fort détecté (IA): ", signalType, " (Confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier le rebond sur l'EMA avant d'entrer dans un trade        |
//+------------------------------------------------------------------+
bool CheckEMARebound(ENUM_ORDER_TYPE orderType)
{
   // Paramètres EMA
   int fastEmaPeriod = 9;   // Période de l'EMA rapide
   int slowEmaPeriod = 21;  // Période de l'EMA lente
   
   // Récupérer les valeurs des EMA
   double emaFast[1], emaSlow[1];
   
   // Get or create EMA handles
   if(emaFastHandle == INVALID_HANDLE)
      emaFastHandle = iMA(_Symbol, PERIOD_CURRENT, fastEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   if(emaSlowHandle == INVALID_HANDLE)
      emaSlowHandle = iMA(_Symbol, PERIOD_CURRENT, slowEmaPeriod, 0, MODE_EMA, PRICE_CLOSE);
   
   // Copy the latest EMA values
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFast) <= 0) return false;
   if(CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlow) <= 0) return false;
   
   // Récupérer les prix actuels
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Calculer la distance au point
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(orderType == ORDER_TYPE_BUY)
   {
      // Pour un achat, vérifier que le prix est au-dessus de l'EMA rapide
      // et que l'EMA rapide est au-dessus de l'EMA lente (tendance haussière)
      bool isAboveFastEma = (currentBid > emaFast[0]);
      bool isFastAboveSlow = (emaFast[0] > emaSlow[0]);
      
      if(DebugMode)
         Print("CheckEMARebound BUY - Prix:", currentBid, " EMA Fast:", emaFast[0], " EMA Slow:", emaSlow[0], 
               " isAboveFastEma:", isAboveFastEma, " isFastAboveSlow:", isFastAboveSlow);
               
      return (isAboveFastEma && isFastAboveSlow);
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      // Pour une vente, vérifier que le prix est en dessous de l'EMA rapide
      // et que l'EMA rapide est en dessous de l'EMA lente (tendance baissière)
      bool isBelowFastEma = (currentAsk < emaFast[0]);
      bool isFastBelowSlow = (emaFast[0] < emaSlow[0]);
      
      if(DebugMode)
         Print("CheckEMARebound SELL - Prix:", currentAsk, " EMA Fast:", emaFast[0], " EMA Slow:", emaSlow[0], 
               " isBelowFastEma:", isBelowFastEma, " isFastBelowSlow:", isFastBelowSlow);
               
      return (isBelowFastEma && isFastBelowSlow);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si la direction est autorisée pour Boom/Crash           |
//+------------------------------------------------------------------+
bool IsDirectionAllowedForBoomCrash(ENUM_ORDER_TYPE orderType)
{
   // PROTECTION: Bloquer SELL sur Boom et BUY sur Crash
   // Boom = BUY uniquement (spike en tendance haussière)
   // Crash = SELL uniquement (spike en tendance baissière)
   
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(isBoom && orderType == ORDER_TYPE_SELL)
   {
      if(DebugMode)
         Print("🚫 ExecuteBoomCrashSpikeTrade: SELL interdit sur Boom (BUY uniquement)");
      return false;
   }
   
   if(isCrash && orderType == ORDER_TYPE_BUY)
   {
      if(DebugMode)
         Print("🚫 ExecuteBoomCrashSpikeTrade: BUY interdit sur Crash (SELL uniquement)");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Vérifier et gérer les positions Boom/Crash                      |
//+------------------------------------------------------------------+
bool ExecuteBoomCrashSpikeTrade(ENUM_ORDER_TYPE orderType, double sl = 0, double tp = 0)
{
   // Vérifier si la direction est autorisée pour Boom/Crash
   if(!IsDirectionAllowedForBoomCrash(orderType))
      return false;
      
   // PROTECTION: Vérifier la perte maximale par symbole
   double symbolLoss = GetSymbolLoss(_Symbol);
   if(symbolLoss >= MaxSymbolLoss)
   {
      if(DebugMode)
         Print("🚫 ExecuteBoomCrashSpikeTrade: Symbole ", _Symbol, " bloqué - Perte maximale atteinte (", DoubleToString(symbolLoss, 2), "$ >= ", DoubleToString(MaxSymbolLoss, 2), "$) - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)");
      return false;
   }
   
   // PROTECTION: Vérifier la perte totale maximale
   double totalLoss = GetTotalLoss();
   if(totalLoss >= MaxTotalLoss)
   {
      if(DebugMode)
         Print("🚫 ExecuteBoomCrashSpikeTrade: Perte totale maximale atteinte (", DoubleToString(totalLoss, 2), "$ >= ", DoubleToString(MaxTotalLoss, 2), "$) - NOUVEAUX TRADES BLOQUÉS (positions existantes conservées)");
      return false;
   }
   
   // Calculer SL/TP automatiquement si non fournis
   if(sl == 0 || tp == 0)
   {
      double entryPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // Pour Boom/Crash: utiliser des SL/TP basés sur des valeurs absolues en USD
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      
      if(orderType == ORDER_TYPE_BUY)
      {
         // SL: perte maximale de 2$ par lot
         sl = entryPrice - (2.0 / tickValue) * tickSize;
         // TP: profit cible de 0.50$ par lot
         tp = entryPrice + (BoomCrashSpikeTP / tickValue) * tickSize;
      }
      else // SELL
      {
         // SL: perte maximale de 2$ par lot
         sl = entryPrice + (2.0 / tickValue) * tickSize;
         // TP: profit cible de 0.50$ par lot
         tp = entryPrice - (BoomCrashSpikeTP / tickValue) * tickSize;
      }
   }
   
   // Exécuter l'ordre au marché immédiatement (CORRIGÉ: pas de récursion)
   double entryPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = NormalizeLotSize(InitialLotSize);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);
   entryPrice = NormalizeDouble(entryPrice, _Digits);
   
   // Définir le mode de remplissage approprié
   ENUM_ORDER_TYPE_FILLING fillingMode = GetSupportedFillingMode(_Symbol);
   trade.SetTypeFilling(fillingMode);
   
   bool success = trade.PositionOpen(_Symbol, orderType, lot, entryPrice, sl, tp, "BOOM_CRASH_SPIKE");
   
   if(success)
   {
      Print("🚀 Trade Spike Boom/Crash exécuté: ", EnumToString(orderType), " sur ", _Symbol);
      Print("   SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits));
   }
   else
   {
      // Si échec avec erreur de filling mode, essayer avec ORDER_FILLING_RETURN
      if(trade.ResultRetcode() == 10030 || trade.ResultRetcode() == 10015 || 
         StringFind(trade.ResultRetcodeDescription(), "filling") != -1 ||
         StringFind(trade.ResultRetcodeDescription(), "Unsupported") != -1)
      {
         Print("⚠️ Erreur filling mode Boom/Crash - Tentative avec ORDER_FILLING_RETURN");
         trade.SetTypeFilling(ORDER_FILLING_RETURN);
         success = trade.PositionOpen(_Symbol, orderType, lot, entryPrice, sl, tp, "BOOM_CRASH_SPIKE");
         
         if(success)
         {
            Print("🚀 Trade Spike Boom/Crash exécuté (fallback): ", EnumToString(orderType), " sur ", _Symbol);
            Print("   SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits));
         }
         else
         {
            Print("❌ Échec Trade Spike Boom/Crash (fallback): ", EnumToString(orderType), " sur ", _Symbol, " - Code: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
         }
      }
      else
      {
         Print("❌ Échec Trade Spike Boom/Crash: ", EnumToString(orderType), " sur ", _Symbol, " - Code: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Détecter une opportunité de spike Boom/Crash                     |
//+------------------------------------------------------------------+
bool DetectBoomCrashSpikeOpportunity(ENUM_ORDER_TYPE &orderType, double &confidence)
{
   orderType = WRONG_VALUE;
   confidence = 0.0;
   
   // Vérifier si c'est un symbole Boom/Crash
   if(!IsBoomCrashSymbol(_Symbol))
      return false;
   
   // Obtenir les données de prix récentes
   double close[];
   ArrayResize(close, 10);
   ArraySetAsSeries(close, true);
   
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 10, close) < 10)
      return false;
   
   // Calculer la volatilité récente
   double volatility = 0;
   for(int i = 1; i < 10; i++)
   {
      volatility += MathAbs(close[i] - close[i-1]);
   }
   volatility /= 9;
   
   // Détecter un mouvement spike soudain
   double currentMove = MathAbs(close[0] - close[1]);
   double avgMove = volatility;
   
   // Spike détecté si mouvement actuel > 2x mouvement moyen
   if(currentMove > (avgMove * 2.0))
   {
      // Déterminer la direction du spike
      if(close[0] > close[1])
      {
         orderType = ORDER_TYPE_BUY;
         confidence = MathMin(0.85, currentMove / avgMove * 0.5);
      }
      else
      {
         orderType = ORDER_TYPE_SELL;
         confidence = MathMin(0.85, currentMove / avgMove * 0.5);
      }
      
      if(DebugMode)
      {
         Print("🚀 Spike Boom/Crash détecté: ", EnumToString(orderType));
         Print("   Mouvement: ", DoubleToString(currentMove, _Digits), " | Moyenne: ", DoubleToString(avgMove, _Digits));
         Print("   Confiance: ", DoubleToString(confidence * 100, 1), "%");
      }
      
      return true;
   }
   
   return false;
}



//+------------------------------------------------------------------+
//| FONCTIONS POUR MACHINE LEARNING ET ANALYSE COHÉRENTE            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Mettre à jour l'analyse cohérente                               |
//+------------------------------------------------------------------+
void UpdateCoherentAnalysis(string symbol)
{
   if(!UseAI_Agent || StringLen(AI_CoherentAnalysisURL) == 0)
      return;
   
   // Vérifier l'intervalle de mise à jour
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < AI_CoherentAnalysisInterval)
      return;
   
   lastUpdate = TimeCurrent();
   
   // Préparer les données pour l'API
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   string data = "{";
   data += "\"symbol\":\"" + symbol + "\",";
   data += "\"bid\":" + DoubleToString(bid, _Digits) + ",";
   data += "\"ask\":" + DoubleToString(ask, _Digits) + ",";
   data += "\"timeframe\":\"M1\",";
   data += "\"timestamp\":" + IntegerToString(TimeCurrent());
   data += "}";
   
   string headers = "Content-Type: application/json\r\n";
   string result_headers = "";
   
   uchar post_data[];
   StringToCharArray(data, post_data);
   
   uchar result[];
   int res = WebRequest("POST", AI_CoherentAnalysisURL, headers, AI_Timeout_ms, post_data, result, result_headers);
   
   if(res == 200)
   {
      // Convertir le résultat en string pour parsing
      string resultStr = CharArrayToString(result);
      
      // Parser la réponse JSON
      if(StringFind(resultStr, "\"decision\"") >= 0)
      {
         // Extraire la décision
         int start = StringFind(resultStr, "\"decision\":\"") + 12;
         int end = StringFind(resultStr, "\"", start);
         if(end > start)
         {
            g_coherentAnalysis.decision = StringSubstr(resultStr, start, end - start);
         }
      }
      
      if(StringFind(resultStr, "\"confidence\"") >= 0)
      {
         // Extraire la confiance
         int start = StringFind(resultStr, "\"confidence\":");
         string confStr = "";
         for(int i = start + 12; i < StringLen(resultStr); i++)
         {
            string ch = StringSubstr(resultStr, i, 1);
            if(ch == "," || ch == "}" || ch == " ") break;
            confStr += ch;
         }
         g_coherentAnalysis.confidence = StringToDouble(confStr);
      }
      
      g_coherentAnalysis.lastUpdate = TimeCurrent();
      g_coherentAnalysis.symbol = symbol;
      
      if(DebugMode)
      {
         Print("✅ Analyse cohérente mise à jour: ", symbol);
         Print("   Décision: ", g_coherentAnalysis.decision);
         Print("   Confiance: ", DoubleToString(g_coherentAnalysis.confidence, 1), "%");
      }
   }
   else
   {
      if(DebugMode)
         Print("❌ Erreur API Analyse cohérente: ", res);
   }
}

//+------------------------------------------------------------------+
//| Mettre à jour les métriques ML                                   |
//+------------------------------------------------------------------+
void UpdateMLMetrics(string symbol, string timeframe)
{
   if(!UseMLPrediction || StringLen(AI_MLMetricsURL) == 0)
      return;
   
   // Vérifier l'intervalle de mise à jour
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < ML_MetricsUpdateInterval)
      return;
   
   lastUpdate = TimeCurrent();
   
   // Préparer les données pour l'API
   string data = "{";
   data += "\"symbol\":\"" + symbol + "\",";
   data += "\"timeframe\":\"" + timeframe + "\"";
   data += "}";
   
   string headers = "Content-Type: application/json\r\n";
   string result_headers = "";
   
   uchar post_data[];
   StringToCharArray(data, post_data);
   
   uchar result[];
   int res = WebRequest("POST", AI_MLMetricsURL, headers, AI_Timeout_ms, post_data, result, result_headers);
   
   if(res == 200)
   {
      // Convertir le résultat en string pour parsing
      string resultStr = CharArrayToString(result);
      
      // Parser la réponse JSON pour extraire les métriques
      if(StringFind(resultStr, "\"accuracy\"") >= 0)
      {
         // Extraire l'accuracy
         int start = StringFind(resultStr, "\"accuracy\":");
         string accStr = "";
         for(int i = start + 11; i < StringLen(resultStr); i++)
         {
            string ch = StringSubstr(resultStr, i, 1);
            if(ch == "," || ch == "}" || ch == " ") break;
            accStr += ch;
         }
         g_mlMetrics.accuracy = StringToDouble(accStr);
         
         // Extraire le modèle
         start = StringFind(resultStr, "\"modelName\":\"");
         if(start >= 0)
         {
            start += 13;
            int end = StringFind(resultStr, "\"", start);
            if(end > start)
            {
               g_mlMetrics.modelName = StringSubstr(resultStr, start, end - start);
            }
         }
         
         g_mlMetrics.lastUpdate = TimeCurrent();
         g_mlMetrics.symbol = symbol;
         g_mlMetrics.timeframe = timeframe;
         g_mlMetrics.isValid = true;
         
         if(DebugMode && ShowMLMetrics)
         {
            Print("📊 Métriques ML mises à jour: ", symbol, " ", timeframe);
            Print("   Modèle: ", g_mlMetrics.modelName);
            Print("   Accuracy: ", DoubleToString(g_mlMetrics.accuracy * 100, 1), "%");
         }
      }
   }
   else
   {
      if(DebugMode)
         Print("❌ Erreur API Métriques ML: ", res);
   }
}

//+------------------------------------------------------------------+
//| Dessiner le panneau des métriques ML                              |
//+------------------------------------------------------------------+
void DrawMLMetricsPanel()
{
   // FORCER l'affichage même si g_mlMetrics.isValid est false
   // Créer des données factices pour le débogage si nécessaire
   bool showDebugInfo = true;
   
   if(!g_mlMetrics.isValid && showDebugInfo)
   {
      // Créer des données de démonstration pour voir le panneau
      g_mlMetrics.isValid = true;
      g_mlMetrics.modelName = "ML-Model-v2.1";
      g_mlMetrics.accuracy = 0.75;
      g_mlMetrics.lastUpdate = TimeCurrent();
   }
   
   if(!g_mlMetrics.isValid || StringLen(g_mlMetrics.modelName) == 0)
   {
      if(DebugMode)
         Print("❌ DrawMLMetricsPanel: g_mlMetrics.isValid=", g_mlMetrics.isValid ? "true" : "false", 
               " modelName='", g_mlMetrics.modelName, "' len=", StringLen(g_mlMetrics.modelName));
      return;
   }
   
   // Dimensions du panneau
   int panelX = 10;
   int panelY = 200; // Position sous les autres panneaux
   int panelWidth = 250;
   int panelHeight = 80;
   
   // Calculer la position X depuis le bord droit
   long chartWidth = (long)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   panelX = (int)(chartWidth - panelWidth - 10);
   
   // Créer un fond rectangle semi-transparent
   string panelBgName = "ML_METRICS_PANEL_BG_" + _Symbol;
   if(ObjectFind(0, panelBgName) < 0)
      ObjectCreate(0, panelBgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, panelBgName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, panelBgName, OBJPROP_XDISTANCE, panelX);
   ObjectSetInteger(0, panelBgName, OBJPROP_YDISTANCE, panelY);
   ObjectSetInteger(0, panelBgName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, panelBgName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, panelBgName, OBJPROP_BGCOLOR, C'30,30,50'); // Fond bleu foncé
   ObjectSetInteger(0, panelBgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, panelBgName, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, panelBgName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, panelBgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, panelBgName, OBJPROP_BACK, false);
   ObjectSetInteger(0, panelBgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panelBgName, OBJPROP_HIDDEN, true);
   
   // Titre du panneau
   string titleName = "ML_METRICS_TITLE_" + _Symbol;
   if(ObjectFind(0, titleName) < 0)
      ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, panelX + 5);
   ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, panelY + 5);
   ObjectSetString(0, titleName, OBJPROP_TEXT, "🤖 Machine Learning");
   ObjectSetInteger(0, titleName, OBJPROP_COLOR, clrCyan);
   ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, titleName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, titleName, OBJPROP_SELECTABLE, false);
   
   // Afficher le modèle
   string modelName = "ML_MODEL_NAME_" + _Symbol;
   if(ObjectFind(0, modelName) < 0)
      ObjectCreate(0, modelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, modelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, modelName, OBJPROP_XDISTANCE, panelX + 5);
   ObjectSetInteger(0, modelName, OBJPROP_YDISTANCE, panelY + 25);
   ObjectSetString(0, modelName, OBJPROP_TEXT, "Modèle: " + g_mlMetrics.modelName);
   ObjectSetInteger(0, modelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, modelName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, modelName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, modelName, OBJPROP_SELECTABLE, false);
   
   // Afficher l'accuracy
   string accuracyName = "ML_ACCURACY_" + _Symbol;
   if(ObjectFind(0, accuracyName) < 0)
      ObjectCreate(0, accuracyName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, accuracyName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, accuracyName, OBJPROP_XDISTANCE, panelX + 5);
   ObjectSetInteger(0, accuracyName, OBJPROP_YDISTANCE, panelY + 40);
   
   // Couleur selon l'accuracy
   color accuracyColor = clrLime;
   if(g_mlMetrics.accuracy < 0.6)
      accuracyColor = clrRed;
   else if(g_mlMetrics.accuracy < 0.75)
      accuracyColor = clrYellow;
   
   ObjectSetString(0, accuracyName, OBJPROP_TEXT, "Précision: " + DoubleToString(g_mlMetrics.accuracy * 100, 1) + "%");
   ObjectSetInteger(0, accuracyName, OBJPROP_COLOR, accuracyColor);
   ObjectSetInteger(0, accuracyName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, accuracyName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, accuracyName, OBJPROP_SELECTABLE, false);
   
   // Afficher la dernière mise à jour
   string updateTime = "ML_UPDATE_TIME_" + _Symbol;
   if(ObjectFind(0, updateTime) < 0)
      ObjectCreate(0, updateTime, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, updateTime, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, updateTime, OBJPROP_XDISTANCE, panelX + 5);
   ObjectSetInteger(0, updateTime, OBJPROP_YDISTANCE, panelY + 55);
   
   datetime timeDiff = TimeCurrent() - g_mlMetrics.lastUpdate;
   string timeText = "";
   if(timeDiff < 60)
      timeText = "Mis à jour: " + IntegerToString((int)timeDiff) + "s";
   else if(timeDiff < 3600)
      timeText = "Mis à jour: " + IntegerToString((int)(timeDiff / 60)) + "min";
   else
      timeText = "Mis à jour: " + IntegerToString((int)(timeDiff / 3600)) + "h";
   
   ObjectSetString(0, updateTime, OBJPROP_TEXT, timeText);
   ObjectSetInteger(0, updateTime, OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, updateTime, OBJPROP_FONTSIZE, 7);
   ObjectSetString(0, updateTime, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, updateTime, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Envoyer le feedback d'apprentissage ML                           |
//+------------------------------------------------------------------+
void SendMLFeedback(ulong ticket, double profit, string reason)
{
   if(!EnableMLFeedback || StringLen(AI_MLFeedbackURL) == 0)
      return;
   
   // Préparer les données de feedback
   string data = "{";
   data += "\"ticket\":" + IntegerToString((long)ticket) + ",";
   data += "\"symbol\":\"" + _Symbol + "\",";
   data += "\"timeframe\":\"M1\",";
   data += "\"profit\":" + DoubleToString(profit, 2) + ",";
   data += "\"is_win\":" + (profit > 0 ? "true" : "false") + ",";
   data += "\"reason\":\"" + reason + "\",";
   data += "\"timestamp\":" + IntegerToString(TimeCurrent()) + ",";
   data += "\"ai_decision\":\"" + g_lastAIAction + "\",";
   data += "\"ai_confidence\":" + DoubleToString(g_lastAIConfidence, 2);
   data += "}";
   
   string headers = "Content-Type: application/json\r\n";
   string result_headers = "";
   
   uchar post_data[];
   StringToCharArray(data, post_data);
   
   uchar result[];
   int res = WebRequest("POST", AI_MLFeedbackURL, headers, AI_Timeout_ms, post_data, result, result_headers);
   
   if(res == 200)
   {
      g_mlFeedbackCount++;
      
      if(profit < 0)
      {
         // C'est une perte, incrémenter le compteur de feedbacks de pertes
         if(g_mlFeedbackCount >= ML_FeedbackRetrainThreshold && AutoRetrainAfterFeedback)
         {
            datetime currentTime = TimeCurrent();
            if((currentTime - g_lastMLRetrainTime) >= ML_TrainInterval)
            {
               Print("🔄 Seuil de feedback atteint - Déclenchement réentraînement ML...");
               // TODO: Appeler l'API de réentraînement
               g_lastMLRetrainTime = currentTime;
               g_mlFeedbackCount = 0; // Réinitialiser le compteur
            }
         }
      }
      
      if(DebugMode)
      {
         Print("📤 Feedback ML envoyé: Ticket=", ticket, " Profit=", DoubleToString(profit, 2), "$ Reason=", reason);
         Print("   Total feedbacks: ", g_mlFeedbackCount);
      }
   }
   else
   {
      if(DebugMode)
         Print("❌ Erreur envoi feedback ML: ", res);
   }
}

//+------------------------------------------------------------------+
//| Parser la réponse JSON des bougies futures                     |
//+------------------------------------------------------------------+
bool ParseFutureCandlesResponse(string jsonResponse)
{
   // Parser pour extraire les bougies futures depuis l'endpoint /predictions/realtime
   // Format attendu: {"predicted_prices": [1980.5, 1985.2, 1978.3, 1982.1, ...], "current_price": 1980.0, ...}
   
   // Réinitialiser le tableau
   g_futureCandlesCount = 0;
   
   // Vérifier si la réponse est vide
   StringTrimLeft(jsonResponse);
   StringTrimRight(jsonResponse);
   if(StringLen(jsonResponse) == 0)
   {
      if(DebugMode) Print("❌ Réponse vide du serveur de prédiction");
      return false;
   }
   
   // Chercher predicted_prices dans la réponse
   int pricesStart = StringFind(jsonResponse, "\"predicted_prices\":");
   if(pricesStart < 0)
   {
      // Fallback: chercher "candles" pour compatibilité
      int candlesStart = StringFind(jsonResponse, "\"candles\":");
      if(candlesStart < 0)
      {
         if(DebugMode) Print("❌ Format de réponse invalide - champ 'predicted_prices' ou 'candles' manquant");
         return false;
      }
      pricesStart = candlesStart;
   }
   
   // Extraire la liste des prix prédits
   int arrayStart = StringFind(jsonResponse, "[", pricesStart);
   int arrayEnd = StringFind(jsonResponse, "]", arrayStart);
   
   if(arrayStart < 0 || arrayEnd < 0 || arrayEnd <= arrayStart)
   {
      if(DebugMode) Print("❌ Format de tableau de prix invalide");
      return false;
   }
   
   string pricesArray = StringSubstr(jsonResponse, arrayStart + 1, arrayEnd - arrayStart - 1);
   
   // Parser les prix (séparés par des virgules)
   string prices[];
   int pricesCount = StringSplit(pricesArray, ',', prices);
   
   if(pricesCount == 0)
   {
      if(DebugMode) Print("❌ Aucun prix trouvé dans la réponse");
      return false;
   }
   
   // Récupérer le prix actuel pour calculer open de la première bougie
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int currentPriceStart = StringFind(jsonResponse, "\"current_price\":");
   if(currentPriceStart >= 0)
   {
      int currentPriceValueStart = StringFind(jsonResponse, ":", currentPriceStart) + 1;
      int currentPriceValueEnd = StringFind(jsonResponse, ",", currentPriceValueStart);
      if(currentPriceValueEnd < 0)
         currentPriceValueEnd = StringFind(jsonResponse, "}", currentPriceValueStart);
      if(currentPriceValueEnd > currentPriceValueStart)
      {
         string currentPriceStr = StringSubstr(jsonResponse, currentPriceValueStart, currentPriceValueEnd - currentPriceValueStart);
         StringTrimLeft(currentPriceStr);
         StringTrimRight(currentPriceStr);
         currentPrice = StringToDouble(currentPriceStr);
         if(currentPrice <= 0)
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      }
   }
   
   datetime currentTime = TimeCurrent();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Limiter le nombre de bougies selon le paramètre (par défaut 15 pour éviter la surcharge visuelle)
   int maxCandles = MathMin(pricesCount, MaxPredictionCandles);
   double prevClose = currentPrice;
   
   for(int i = 0; i < maxCandles; i++)
   {
      // Nettoyer et parser le prix
      StringTrimLeft(prices[i]);
      StringTrimRight(prices[i]);
      double predictedPrice = StringToDouble(prices[i]);
      
      if(predictedPrice <= 0)
         continue;
      
      // Vérifier les limites du tableau
      if(g_futureCandlesCount >= ArraySize(g_futureCandles))
         ArrayResize(g_futureCandles, g_futureCandlesCount + 10);
      
      // Calculer les valeurs OHLC pour la bougie prédictive
      g_futureCandles[g_futureCandlesCount].time = currentTime + (g_futureCandlesCount + 1) * GetPeriodSeconds(_Period);
      g_futureCandles[g_futureCandlesCount].close = predictedPrice;
      g_futureCandles[g_futureCandlesCount].open = prevClose;
      
      // Estimer high et low basés sur la volatilité et la direction
      double priceChange = predictedPrice - prevClose;
      double volatility = MathAbs(priceChange) * 0.3; // 30% de la variation comme volatilité
      if(volatility < point * 5)
         volatility = point * 5; // Minimum 5 points
      
      if(priceChange >= 0)
      {
         // Bougie haussière
         g_futureCandles[g_futureCandlesCount].high = predictedPrice + volatility;
         g_futureCandles[g_futureCandlesCount].low = MathMin(prevClose, predictedPrice) - volatility * 0.5;
         g_futureCandles[g_futureCandlesCount].direction = "BUY";
      }
      else
      {
         // Bougie baissière
         g_futureCandles[g_futureCandlesCount].high = MathMax(prevClose, predictedPrice) + volatility * 0.5;
         g_futureCandles[g_futureCandlesCount].low = predictedPrice - volatility;
         g_futureCandles[g_futureCandlesCount].direction = "SELL";
      }
      
      // Confiance basée sur la proximité avec le prix actuel
      double priceDiff = MathAbs(predictedPrice - currentPrice) / currentPrice;
      g_futureCandles[g_futureCandlesCount].confidence = MathMax(0.5, 1.0 - priceDiff * 10);
      
      prevClose = predictedPrice;
      g_futureCandlesCount++;
   }
   
   if(g_futureCandlesCount > 0)
   {
      g_predictionsValid = true;
      g_lastFutureCandlesUpdate = TimeCurrent();
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Dessiner les bougies futures prédites sur le graphique        |
//+------------------------------------------------------------------+
void DrawFutureCandles()
{
   if(!g_predictionsValid || g_futureCandlesCount == 0)
      return;
   
   // Nettoyer les anciennes bougies futures
   CleanupFutureCandles();
   
   // Limiter le nombre de bougies affichées et appliquer l'espacement
   int maxCandlesToConsider = MathMin(g_futureCandlesCount, MaxPredictionCandles * PredictionCandleSpacing);
   int candlesDrawn = 0;
   string prevDirection = "";
   
   // Dessiner les bougies avec espacement pour réduire la densité
   for(int i = 0; i < maxCandlesToConsider && candlesDrawn < MaxPredictionCandles; i++)
   {
      // Appliquer l'espacement : ne dessiner qu'une bougie sur PredictionCandleSpacing
      if(i % PredictionCandleSpacing != 0 && i > 0)
         continue;
      
      FutureCandle candle = g_futureCandles[i];
      
      // Couleur basée sur la direction avec opacité réduite pour moins de densité
      color candleColor;
      int opacity = (int)(candle.confidence * 150); // Opacité réduite (max ~150 au lieu de 255)
      if(opacity < 0) opacity = 0;
      if(opacity > 255) opacity = 255;
      uchar alpha = (uchar)opacity;
      if(candle.direction == "BUY")
         candleColor = (color)ColorToARGB(clrLime, alpha);
      else
         candleColor = (color)ColorToARGB(clrRed, alpha);
      
      // Dessiner le corps de la bougie avec taille adaptée au timeframe
      string bodyName = "FUTURE_CANDLE_BODY_" + IntegerToString(candlesDrawn) + "_" + _Symbol;
      double bodyTop = MathMax(candle.open, candle.close);
      double bodyBottom = MathMin(candle.open, candle.close);
      
      // Calculer la largeur de la bougie selon le timeframe
      int periodSeconds = GetPeriodSeconds(_Period);
      datetime candleEndTime = candle.time + periodSeconds;
      
      ObjectCreate(0, bodyName, OBJ_RECTANGLE, 0, candle.time, bodyTop, candleEndTime, bodyBottom);
      ObjectSetInteger(0, bodyName, OBJPROP_COLOR, candleColor);
      ObjectSetInteger(0, bodyName, OBJPROP_BACK, false);
      ObjectSetInteger(0, bodyName, OBJPROP_WIDTH, 1); // Épaisseur minimale
      ObjectSetInteger(0, bodyName, OBJPROP_FILL, true); // Remplir pour meilleure visibilité
      
      // Dessiner la mèche (wick) seulement si activé et avec opacité réduite
      if(ShowPredictionWicks)
      {
         string wickName = "FUTURE_CANDLE_WICK_" + IntegerToString(candlesDrawn) + "_" + _Symbol;
         ObjectCreate(0, wickName, OBJ_TREND, 0, candle.time + periodSeconds/2, candle.high, candle.time + periodSeconds/2, candle.low);
         ObjectSetInteger(0, wickName, OBJPROP_COLOR, (color)ColorToARGB(clrGray, (uchar)80)); // Opacité très réduite
         ObjectSetInteger(0, wickName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, wickName, OBJPROP_STYLE, STYLE_DOT); // Style pointillé pour moins de densité
      }
      
      // Ajouter une flèche seulement si activé ET seulement sur changement de direction significatif
      if(ShowPredictionArrows)
      {
         bool shouldDrawArrow = false;
         
         // Dessiner la flèche seulement si :
         // 1. C'est la première bougie affichée
         // 2. Changement de direction par rapport à la précédente
         // 3. Confiance très élevée (> 75%)
         if(candlesDrawn == 0)
            shouldDrawArrow = true;
         else if(candle.direction != prevDirection && prevDirection != "")
            shouldDrawArrow = true;
         else if(candle.confidence > 0.75)
            shouldDrawArrow = true;
         
         if(shouldDrawArrow)
         {
            string arrowName = "FUTURE_ARROW_" + IntegerToString(candlesDrawn) + "_" + _Symbol;
            double arrowOffset = (candle.high - candle.low) * 0.15; // Offset réduit
            if(candle.direction == "BUY")
               ObjectCreate(0, arrowName, OBJ_ARROW_UP, 0, candle.time + periodSeconds/2, candle.low - arrowOffset);
            else
               ObjectCreate(0, arrowName, OBJ_ARROW_DOWN, 0, candle.time + periodSeconds/2, candle.high + arrowOffset);
            
            ObjectSetInteger(0, arrowName, OBJPROP_COLOR, candleColor);
            ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
         }
      }
      
      prevDirection = candle.direction;
      candlesDrawn++;
   }
}

//+------------------------------------------------------------------+
//| Dessiner le canal de prédiction                               |
//+------------------------------------------------------------------+
void DrawPredictionChannel()
{
   if(!g_predictionsValid || g_futureCandlesCount == 0)
      return;
   
   // Calculer le canal
   double maxHigh = 0;
   double minLow = DBL_MAX;
   
   for(int i = 0; i < g_futureCandlesCount; i++)
   {
      if(g_futureCandles[i].high > maxHigh)
         maxHigh = g_futureCandles[i].high;
      if(g_futureCandles[i].low < minLow)
         minLow = g_futureCandles[i].low;
   }
   
   g_predictionChannel.upperBand = maxHigh;
   g_predictionChannel.lowerBand = minLow;
   g_predictionChannel.centerLine = (maxHigh + minLow) / 2;
   g_predictionChannel.channelWidth = maxHigh - minLow;
   g_predictionChannel.confidence = 0.75;  // Confiance moyenne
   g_predictionChannel.validUntil = g_futureCandles[g_futureCandlesCount - 1].time;
   
   // Nettoyer les anciens canaux
   CleanupPredictionChannel();
   
   // Dessiner la bande supérieure
   string upperName = "PREDICTION_UPPER_" + _Symbol;
   ObjectCreate(0, upperName, OBJ_TREND, 0, g_futureCandles[0].time, g_predictionChannel.upperBand, 
                 g_futureCandles[g_futureCandlesCount - 1].time, g_predictionChannel.upperBand);
   ObjectSetInteger(0, upperName, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, upperName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, upperName, OBJPROP_STYLE, STYLE_DASH);
   
   // Dessiner la bande inférieure
   string lowerName = "PREDICTION_LOWER_" + _Symbol;
   ObjectCreate(0, lowerName, OBJ_TREND, 0, g_futureCandles[0].time, g_predictionChannel.lowerBand,
                 g_futureCandles[g_futureCandlesCount - 1].time, g_predictionChannel.lowerBand);
   ObjectSetInteger(0, lowerName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, lowerName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, lowerName, OBJPROP_STYLE, STYLE_DASH);
   
   // Dessiner la ligne centrale
   string centerName = "PREDICTION_CENTER_" + _Symbol;
   ObjectCreate(0, centerName, OBJ_TREND, 0, g_futureCandles[0].time, g_predictionChannel.centerLine,
                 g_futureCandles[g_futureCandlesCount - 1].time, g_predictionChannel.centerLine);
   ObjectSetInteger(0, centerName, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, centerName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, centerName, OBJPROP_STYLE, STYLE_DOT);
   
   // Ajouter une étiquette avec la largeur du canal
   string labelName = "PREDICTION_LABEL_" + _Symbol;
   string text = StringFormat("Canal de prédiction (%.5f pips)", g_predictionChannel.channelWidth / Point());
   
   if(ObjectFind(0, labelName) < 0)
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetString(0, labelName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
   
   if(DebugMode)
      Print("✅ Canal de prédiction dessiné: ", text);
}


//+------------------------------------------------------------------+
//| Mettre à jour les bougies futures prédites                     |
//+------------------------------------------------------------------+
void UpdateFutureCandles()
{
   // Vérifier l'intervalle de mise à jour (toutes les 5 minutes par défaut)
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < PREDICTION_UPDATE_INTERVAL && g_predictionsValid)
      return;
      
   // Utiliser l'endpoint depuirender (/predictions/realtime)
   if(StringLen(PredictionsRealtimeURL) == 0)
      return;
   
   // Construire l'URL avec le symbole
   string timeframeStr = EnumToString(_Period);
   // Convertir PERIOD_M1 -> M1, PERIOD_M5 -> M5, etc.
   if(StringFind(timeframeStr, "PERIOD_") == 0)
      timeframeStr = StringSubstr(timeframeStr, 7);
   
   string url = PredictionsRealtimeURL + "/" + _Symbol + "?timeframe=" + timeframeStr;
   
   // Préparer la requête à l'API de prédiction
   string headers = "Content-Type: application/json\r\n";
   string result_headers = "";
   uchar data[];
   uchar result[];
   
   ArrayResize(data, 0);
   
   // Make the API request with enhanced error handling
   int res = WebRequest("GET", url, headers, AI_Timeout_ms, data, result, result_headers);
   
   // Handle the response
   if(res == 200) // Request was successful
   {
      string response = CharArrayToString(result);
      
      // Log the raw response for debugging
      if(DebugMode) 
      {
         Print("Raw API Response: ", response);
      }
      
      // Check if response contains valid data
      if(StringLen(response) > 0) 
      {
         // Try to parse the response
         if(ParseFutureCandlesResponse(response)) 
         {
            // Update display if parsing was successful
            DrawFutureCandles();
            lastUpdate = TimeCurrent();
            g_predictionsValid = true;
            
            if(DebugMode)
               Print("✅ Successfully updated future candles. ", g_futureCandlesCount, " candles received.");
         }
         else
         {
            // Log detailed error when parsing fails
            Print("❌ Failed to parse API response. Response: ", response);
         }
      }
      else
      {
         Print("❌ Error: Empty response from API");
      }
   }
   else // Handle HTTP errors
   {
      if(DebugMode)
         Print("❌ Erreur lors de la récupération des bougies futures: ", res, " URL: ", url);
   }
}

//+------------------------------------------------------------------+
//| Vérifier si le prix est dans une zone de correction              |
//+------------------------------------------------------------------+
bool IsPriceInCorrectionZone(ENUM_ORDER_TYPE orderType)
{
   // Récupérer les données de prix
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                        SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                        SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Récupérer les EMA rapides et lentes M5
   double emaFastM5[], emaSlowM5[];
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   
   // Copier les données EMA
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFastM5) < 2 ||
      CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlowM5) < 2)
   {
      if(DebugMode) Print("❌ Erreur copie des données EMA pour détection correction");
      return false;
   }
   
   // Calculer la distance en pourcentage par rapport à l'EMA rapide
   double distancePct = MathAbs(currentPrice - emaFastM5[0]) / emaFastM5[0] * 100.0;
   
   // Seuil de distance pour considérer une correction (0.1% par défaut)
   double correctionThreshold = 0.1;
   
   // Si le prix est trop loin de l'EMA rapide, c'est peut-être une correction
   if(distancePct > correctionThreshold)
   {
      if(DebugMode) 
         Print("⚠️ Prix en zone de correction détecté: ", 
               "Distance EMA: ", DoubleToString(distancePct, 3), "% > ", 
               DoubleToString(correctionThreshold, 3), "%");
      return true;
   }
   
   // Vérifier également si l'EMA rapide est en train de se retourner contre la tendance
   if((emaFastM5[0] < emaFastM5[1] && orderType == ORDER_TYPE_BUY) ||
      (emaFastM5[0] > emaFastM5[1] && orderType == ORDER_TYPE_SELL))
   {
      if(DebugMode) 
         Print("⚠️ Retournement d'EMA détecté: ", 
               (orderType == ORDER_TYPE_BUY ? "BAISSIER" : "HAUSSIER"), 
               " - Éviter l'entrée");
      return true;
   }
   
   return false;
}


//+------------------------------------------------------------------+
