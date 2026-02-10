//+------------------------------------------------------------------+
//|                     GoldRush_basic.mq5                           |
//|   Version 3.04 – Système intelligent (max profit / sécurisation / anti-perte) |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, User"
#property link      "https://www.mql5.com"
#property version   "3.04"
#property strict

//--- Inclusions nécessaires
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>

//--- Constantes manquantes pour la compatibilité
#ifndef FW_BOLD
#define FW_BOLD 700
#endif
#ifndef FW_NORMAL
#define FW_NORMAL 400
#endif
#ifndef ANCHOR_LEFT_UPPER
#define ANCHOR_LEFT_UPPER 0
#endif
#ifndef ANCHOR_CENTER
#define ANCHOR_CENTER 2
#endif
#ifndef ANCHOR_RIGHT_UPPER
#define ANCHOR_RIGHT_UPPER 3
#endif

//==================== PARAMÈTRES ====================
input double InpLots = 0.01;              // Lot minimum (sera validé par ValidateLotSize)
input int InpStopLoss = 50;               // SL très conservateur (5 pips Forex, adapté Boom/Crash)
input int InpTakeProfit = 100;            // TP raisonnable pour tous symboles
input int InpMagicNum = 123456;
input bool InpUseTrailing = true;
input int InpTrailDist = 20;              // trailing assez serré

//==================== PARAMÈTRES TRAILING STOP SPÉCIAUX ====================
input double BoomCrashTrailDistPips = 35.0;
input double BoomCrashTrailStartPips = 22.0;
input double BoomCrashTrailStepPips = 10.0;

//==================== VOLUMES SPÉCIAUX ====================
input double BoomCrashMinLot = 0.2;

//==================== OPTIMISATION PERFORMANCES ====================
input group "Optimisation Performances"
input bool UseUltraLightMode = true;           // Mode ultra-léger pour éviter le lag
input int DashboardRefreshMin = 5;            // Rafraîchissement minimum dashboard (secondes)
input int AIUpdateIntervalMin = 30;           // Intervalle minimum mise à jour IA (secondes)
input bool DisableHeavyFunctions = true;       // Désactiver fonctions lourdes

//==================== GESTION AVANCÉE DES PROFITS ====================
input group "--- GESTION PROFITS ---"
input bool UseProfitDuplication = true;
input double ProfitThresholdForDuplicate = 1.0;
input double DuplicationLotSize = 0.4;
input double TotalProfitTarget = 5.0;
input bool AutoCloseOnTarget = false;
input bool UseTrailingForProfit = false;        // Désactivé pour performance
input double AutoCloseProfitUSD = 2.0;        // Fermer automatiquement les positions à ce profit (USD)

//==================== PROTECTION CONTRE LES PERTES APRÈS GAINS SUCCESSIFS ====================
input group "--- PROTECTION GAINS SUCCESSIFS ---"
input bool UseSuccessiveGainsProtection = true;    // Activer la protection après gains successifs
input int MaxConsecutiveWins = 3;                // Nombre max de gains successifs avant protection
input double ProtectionRiskReduction = 0.5;       // Réduire le risque de 50% pendant protection
input int ProtectionDurationMinutes = 30;           // Durée de la protection en minutes
input double MinProfitForWin = 0.10;             // Profit minimum pour considérer un gain
input bool UseBreakAfterLosses = true;            // Faire une pause après pertes successives
input int MaxConsecutiveLosses = 2;               // Nombre max de pertes successives avant pause
input int BreakDurationMinutes = 15;               // Durée de la pause après pertes

//==================== PARAMÈTRES IA ====================
input group "--- INTÉGRATION IA ---"
input bool UseAI_Agent = true;
input string AI_ServerURL = "https://kolatradebot.onrender.com/decision";
input string AI_LocalServerURL = "http://localhost:8000/decision";
input bool UseLocalFirst = true;
input double AI_MinConfidence = 0.65;          // Ajusté pour 68% minimum
input int AI_Timeout_ms = 10000;
input int AI_UpdateInterval = 10;

//==================== ENDPOINTS RENDER COMPLETS ====================
input group "--- ENDPOINTS RENDER ---"
input string AI_AnalysisURL = "https://kolatradebot.onrender.com/analysis";
input string TrendAPIURL = "https://kolatradebot.onrender.com/trend";
input string AI_PredictSymbolURL = "https://kolatradebot.onrender.com/predict";
input string AI_CoherentAnalysisURL = "https://kolatradebot.onrender.com/coherent-analysis";
input string AI_MLPredictURL = "https://kolatradebot.onrender.com/ml/predict";
input bool UseAllEndpoints = true;
input double MinEndpointsConfidence = 0.30;

//==================== PARAMÈTRES TECHNIQUES AVANCÉS ====================
input group "--- ANALYSE TECHNIQUE ---"
input bool UseMultiTimeframeEMA = false; // Désactivé pour performance
input bool UseSupertrendIndicator = false; // Désactivé pour performance
input bool UseSupportResistance = false; // Désactivé pour performance
input int EMA_Fast_Period = 12;
input int EMA_Slow_Period = 26;
input int Supertrend_Period = 10;
input double Supertrend_Multiplier = 3.0;
input int SR_LookbackBars = 50;
input bool UseTrendlineDetection = false; // Désactivé pour performance
input int TrendlineLookbackBars = 20;
input double TrendlineMinSlope = 0.5;
input int TrendlineMinTouches = 3;

//==================== PARAMÈTRES AVANCÉS ====================
input group "--- FONCTIONNALITÉS AVANCÉES ---"
input bool UseDerivArrowDetection = false; // Désactivé pour performance
input bool UseStrongSignalValidation = false; // Désactivé pour performance
input bool UseDynamicSLTP = false; // Désactivé pour performance
input bool UseAdvancedDashboard = false; // Désactivé pour performance

//==================== TRADING AVANCÉ - SMC, LIQUIDITÉ, GREEDY MONKEYS ====================
input group "--- TRADING AVANCÉ SMC & LIQUIDITÉ ---"
input bool UseSMCAnalysis = false;             // Désactivé pour performance
input bool ShowLiquidityZones = false;        // Désactivé pour performance
input bool ShowOrderBlocks = false;           // Désactivé pour performance
input bool ShowFVGs = false;                  // Désactivé pour performance
input bool ShowMarketStructure = false;       // Désactivé pour performance
input bool UseGreedyMonkeysStrategy = false;  // Désactivé pour performance
input double LiquiditySensitivity = 0.5;        // Sensibilité de détection des zones de liquidité (0.1-1.0)
input int OrderBlockLookback = 20;              // Nombre de bougies pour chercher les Order Blocks
input int FVGMinPips = 5;                       // Taille minimale des FVG en pips
input bool ShowBreakerBlocks = false;         // Désactivé pour performance
input bool ShowSweepZones = false;             // Désactivé pour performance

//==================== PARAMÈTRES DÉTECTION DE SPIKES ====================
input group "--- DÉTECTION DE SPIKES ---"
input bool UseSpikeDetection = false;          // Désactivé pour performance
input double SpikeThresholdPercent = 0.08;  // Seuil % (Boom/Crash: 0.05 auto si activé)
input int SpikeDetectionWindow = 5;         // Fenêtre pour MA (exclut barre courante)
input double SpikeMinConfidence = 0.03;     // Confiance min 3% pour plus de détections
input bool UseVolumeSpikeDetection = false;     // Désactivé pour performance
input double VolumeSpikeMultiplier = 1.3;   // Volume: 1.3x = spike
input bool UseStandardDeviationSpike = false;  // Désactivé pour performance
input double StdDevSpikeThreshold = 0.7;    // Z-score: 0.7 = plus sensible
input bool UseSpikePatternAnalysis = false;    // Désactivé pour performance
input int SpikePatternLookback = 12;
input bool UseLimitOrdersForSpikes = false;     // Désactivé pour performance
input bool UseBoomCrashSensitiveMode = false;  // Désactivé pour performance
input bool ShowSpikeIndicatorOnChart = false;  // Désactivé pour performance
input int SpikeArrowsRetentionBars = 50;      // Garder les flèches X barres (0=5min)

//==================== GESTION DES RISQUES ====================
input group "--- GESTION DES RISQUES ---"
input double MaxDailyDrawdownPercent = 5.0;
input double MaxPositionDrawdown = 10.0;
input int MaxOpenPositions = 10;              // Augmenté à 10 positions maximum
input bool UseEmergencyStop = true;
input double EmergencyStopDrawdown = 15.0;
input bool UseTimeBasedTrading = false;
input string TradingStartTime = "08:00";
input string TradingEndTime = "22:00";
input bool UseMaxDailyTrades = false;           // Désactivé - trading sans limite quotidienne
input int MaxDailyTrades = 10;
input double RiskPerTrade = 2.0;
input double MinSignalStrength = 0.30;
input int DashboardRefresh = 5;
input bool UseIndexFallback = true;           // Fallback Boom=BUY / Crash=SELL quand IA hold et RSI neutre
input double MaxLossPerTradeUSD = 5.0;         // Perte maximale autorisée par trade en USD (fermeture automatique)
input double MaxDailyLossUSD = 0.0;          // Perte maximale journalière autorisée en USD (0 = désactivé)

input group "GESTION DU RISQUE PAR TRADE"
input double InpRiskPercentPerTrade = 0.8;     // 0.8 % max par trade
input double InpFixedRiskUSD        = 0.0;     // ou mets 2.0 si tu préfères fixe

//==================== PARAMÈTRES STRATÉGIE BOOM/CRACH ====================
input group "--- STRATÉGIE BOOM/CRACH SPÉCIALE"
input double RSI_Oversold_Level = 40.0;     // RSI survente (achat) pour Boom
input double RSI_Overbought_Level = 60.0;    // RSI surachat (vente) pour Crash

//==================== DÉTECTION SPIKE AVANCÉE ====================
input group "--- DÉTECTION SPIKE AVANCÉE"
input bool UseAdvancedSpikeDetection = true;     // Activer détection spike avancée
input double MinATRExpansionRatio = 1.15;   // Ratio expansion ATR pour spike
input int ATR_AverageBars = 20;             // Barres pour moyenne ATR
input double MinCandleBodyATR = 0.35;      // Corps bougie minimum / ATR
input double MinRSISpike = 25.0;            // RSI minimum pour spike Crash
input double MaxRSISpike = 75.0;            // RSI maximum pour spike Boom

//==================== SYSTÈME INTELLIGENT (MAX PROFIT / SÉCURITÉ / ANTI-PERTE) ====================
input group "--- SYSTÈME INTELLIGENT ---"
input bool UseSmartBreakeven = false;          // Désactivé pour performance
input double BreakevenTriggerPips = 15.0;      // Déclencher breakeven après X pips profit
input double BreakevenBufferPips = 2.5;        // Buffer au-dessus du prix d'ouverture
input double LotMultiplier = 1.0;
input bool UsePartialTakeProfit = false;        // Désactivé pour performance
input double PartialCloseAtPips = 30.0;       // Fermer une partie à X pips profit
input double PartialClosePercent = 50.0;        // Pourcentage du volume à fermer (0-100)
input double MaxLossPerTradePercent = 1.5;    // Perte max par trade (% du balance)
input double MinRiskRewardRatio = 1.2;         // Ratio TP/SL minimum pour entrer (ex: 1.2 = TP au moins 1.2x SL)
input bool UseSecureProfitTrail = false;        // Désactivé pour performance
input double SecureProfitTriggerPips = 50.0;   // Au-delà de X pips, trailing sécurisé
input double SecureTrailPips = 15.0;           // Distance du trailing en mode sécurisé
input double DailyProfitTarget = 50.0;         // Objectif de profit journalier (USD) - Devient sélectif après
input double HighConfidenceAfterProfit = 0.70; // Confiance min requise après avoir atteint l'objectif (70%)
input bool UseATRTrailing = false;              // Désactivé pour performance
input double ATRTrailMultiplier = 2.0;         // Multiplicateur ATR pour le trailing
input int MaxScalingPositions = 3;             // Nombre max de positions supplémentaires (pyramidage)
input double ScalingLotDecay = 0.75;           // Facteur de réduction du lot pour chaque nouvelle position

//==================== VARIABLES GLOBALES ====================
// ─────────────────────────────────────
// Variables pour dashboard gauche
// ─────────────────────────────────────
datetime lastDashboardUpdate = 0;
int dashboardX = 10;   // Position gauche
int dashboardY = 20;   // Haut
color colorOK    = clrGreen;
color colorAlert = clrRed;
color colorWarn  = clrYellow;

string LastTradeSignal = "";
double lastPrediction = 0.0;
int lastAISource = 0;
datetime lastDrawTime = 0;
bool g_hasPosition = false;
ulong lastOrderTicket = 0;
double totalSymbolProfit = 0.0;
ulong duplicatedPositionTicket = 0;
string g_lastAIAction = "";
double g_lastAIConfidence = 0.0;
datetime g_lastLocalFilterLog = 0;
double emaFast_H1_val, emaSlow_H1_val;
double emaFast_M15_val, emaSlow_M15_val;
double emaFast_M5_val, emaSlow_M5_val;
double emaFast_M1_val, emaSlow_M1_val;
double supertrend_H1_val, supertrend_H1_dir;
double supertrend_M15_val, supertrend_M15_dir;
double supertrend_M5_val, supertrend_M5_dir;
double supertrend_M1_val, supertrend_M1_dir;
double H1_Support, H1_Resistance;
double M5_Support, M5_Resistance;
bool UsePredictionChannel = true;
bool UseBoomCrashAutoClose = true;
int BoomCrashMinProfitPips = 50;
bool spikeDetected = false;
string spikeType = "";
double spikeIntensity = 0.0;
double spikeConfidence = 0.0;
int spikeCount = 0;
datetime lastSpikeTime = 0;
double spikePriceMA = 0.0;
double spikePriceSTD = 0.0;
double zScore = 0.0;
double volumeMA = 0.0;
double volumeRatio = 0.0;
bool isSupertrendAvailable = true;

//==================== VARIABLES TRENDLINES ====================
double bullishTrendlineSlope = 0.0;
double bearishTrendlineSlope = 0.0;
bool bullishTrendlineValid = false;
bool bearishTrendlineValid = false;
datetime lastTrendlineUpdate = 0;

//==================== VARIABLES OPTIMISATION PERFORMANCE ====================
datetime lastHeavyCalculation = 0;
datetime lastMediumCalculation = 0;
datetime lastLightCalculation = 0;
bool needHeavyUpdate = true;
bool needMediumUpdate = true;

//==================== OBJETS ====================
CTrade trade;

//==================== HANDLES (MULTI-TIMEFRAMES) ====================
int emaFast_H1, emaSlow_H1;
int emaFast_M15, emaSlow_M15;
int emaFast_M5, emaSlow_M5;
int emaFast_M1, emaSlow_M1;
int atr_M1_handle;  // ATR M1 pour filtre anti-spike
int supertrend_H1, supertrend_M15, supertrend_M5, supertrend_M1;
int maFast_M5, maSlow_M5;
int maFast_H1, maSlow_H1;
int rsi_H1, adx_H1, atr_H1;

//==================== CONTRÔLES ====================
datetime lastBarTime = 0;
datetime lastAIUpdate = 0;
string lastDashText = "";
bool derivArrowPresent = false;
int derivArrowType = 0;
datetime lastProfitCheck = 0;
bool hasDuplicated = false;
string lastAnalysisData = "";
string lastTrendData = "";
string lastPredictionData = "";
string lastCoherentData = "";
double endpointsAlignment = 0.0;
datetime lastEndpointUpdate = 0;
datetime lastDerivArrowCheck = 0;

//==================== VARIABLES GAINS SUCCESSIFS ====================
int consecutiveWins = 0;                    // Nombre de gains successifs
int consecutiveLosses = 0;                  // Nombre de pertes successives
datetime lastTradeCloseTime = 0;            // Heure de clôture du dernier trade
bool isProtectionMode = false;              // Mode protection actif
datetime protectionStartTime = 0;            // Heure de début de la protection
bool isBreakMode = false;                   // Mode pause actif
datetime breakStartTime = 0;                // Heure de début de la pause
double originalLotSize = 0.0;              // Taille de lot originale avant protection

//==================== VARIABLES SMC & LIQUIDITÉ ====================
double g_highestHigh = 0.0;                 // Plus haut récent
double g_lowestLow = 999999.0;              // Plus bas récent
datetime g_highestHighTime = 0;             // Temps du plus haut
datetime g_lowestLowTime = 0;               // Temps du plus bas
double g_liquidityHigh = 0.0;               // Niveau de liquidité supérieure
double g_liquidityLow = 0.0;                // Niveau de liquidité inférieure
bool g_liquiditySwept = false;             // Si la liquidité a été sweepée
datetime g_lastSweepTime = 0;               // Dernier sweep de liquidité
double g_orderBlockHigh = 0.0;              // Order Block supérieur
double g_orderBlockLow = 0.0;               // Order Block inférieur
datetime g_orderBlockTime = 0;              // Temps de l'Order Block
bool g_greedyMonkeysActive = false;        // Si stratégie Greedy Monkeys active
double g_fvgHigh = 0.0;                     // Haut du FVG
double g_fvgLow = 0.0;                      // Bas du FVG
datetime g_fvgTime = 0;                     // Temps du FVG
bool g_bullishStructure = false;            // Structure haussière
bool g_bearishStructure = false;            // Structure baissière

//==================== SUIVI DES GAINS MAXIMUMS PAR POSITION ====================
#define MAX_POSITIONS_TRACKED 64
static ulong maxProfitTickets[MAX_POSITIONS_TRACKED];  // Tickets des positions suivies
static double maxProfitValues[MAX_POSITIONS_TRACKED];  // Gains maximums par position
static int maxProfitCount = 0;                     // Nombre de positions suivies
// Suivi système intelligent (breakeven / partial close)
#define MAX_TRACKED_TICKETS 64
ulong g_partialClosedTickets[MAX_TRACKED_TICKETS];
int g_nPartialClosedTickets = 0;
ulong g_breakevenSetTickets[MAX_TRACKED_TICKETS];
int g_nBreakevenSetTickets = 0;
double g_dailyLossTotal = 0.0;                 // Cumul des pertes du jour
datetime g_lastDailyReset = 0;                 // Dernière réinitialisation journalière
int g_scalingCount = 0;                        // Nombre de positions de scaling ouvertes

//+------------------------------------------------------------------+
//| CRÉER UN LABEL                                                   |
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y, color clr, int fontSize = 8,
                bool bold = false, bool center = false, ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER,
                string font = "Arial", bool rectangle = false, color bgColor = clrNONE,
                int borderWidth = 1, bool back = false)
{
   string fullName = "DASH_" + name;
   if(ObjectFind(0, fullName) >= 0)
      ObjectDelete(0, fullName);

   ObjectCreate(0, fullName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, fullName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, fullName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, fullName, OBJPROP_FONT, font);
   ObjectSetInteger(0, fullName, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE, false);

   if(bold)
      ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE, fontSize + 1);
   else
      ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE, fontSize);

   if(center)
   {
      int textWidth = (int)ObjectGetInteger(0, fullName, OBJPROP_XSIZE);
      ObjectSetInteger(0, fullName, OBJPROP_XDISTANCE, x - textWidth/2);
   }

   if(rectangle)
   {
      ObjectSetInteger(0, fullName, OBJPROP_BGCOLOR, bgColor);
      ObjectSetInteger(0, fullName, OBJPROP_BORDER_TYPE, 0);
      ObjectSetInteger(0, fullName, OBJPROP_BORDER_COLOR, clr);
      ObjectSetInteger(0, fullName, OBJPROP_WIDTH, borderWidth);
      ObjectSetInteger(0, fullName, OBJPROP_BACK, back);

      int textWidth = (int)ObjectGetInteger(0, fullName, OBJPROP_XSIZE);
      int textHeight = (int)ObjectGetInteger(0, fullName, OBJPROP_YSIZE);

      int rectX = x;
      if(anchor == ANCHOR_CENTER)
         rectX = x - (textWidth + 20) / 2;
      else if(anchor == ANCHOR_RIGHT_UPPER)
         rectX = x - (textWidth + 20);

      string rectName = fullName + "_BG";
      if(ObjectFind(0, rectName) >= 0)
         ObjectDelete(0, rectName);

      ObjectCreate(0, rectName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, rectName, OBJPROP_XDISTANCE, rectX - 5);
      ObjectSetInteger(0, rectName, OBJPROP_YDISTANCE, y - 2);
      ObjectSetInteger(0, rectName, OBJPROP_XSIZE, textWidth + 10);
      ObjectSetInteger(0, rectName, OBJPROP_YSIZE, textHeight + 4);
      ObjectSetInteger(0, rectName, OBJPROP_BGCOLOR, bgColor);
      ObjectSetInteger(0, rectName, OBJPROP_BORDER_TYPE, 0);
      ObjectSetInteger(0, rectName, OBJPROP_BORDER_COLOR, clr);
      ObjectSetInteger(0, rectName, OBJPROP_WIDTH, borderWidth);
      ObjectSetInteger(0, rectName, OBJPROP_BACK, back);
      ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| CRÉER UNE LIGNE                                                  |
//+------------------------------------------------------------------+
void CreateLine(string name, int x1, int y1, int x2, int y2, color clr, int width = 1, ENUM_LINE_STYLE style = STYLE_SOLID)
{
   string fullName = "DASH_" + name;
   if(ObjectFind(0, fullName) >= 0)
      ObjectDelete(0, fullName);

   ObjectCreate(0, fullName, OBJ_TREND, 0, 0, 0);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, fullName, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, fullName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, fullName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE, false);

   datetime time1 = iTime(_Symbol, PERIOD_CURRENT, 0);
   datetime time2 = iTime(_Symbol, PERIOD_CURRENT, 1);

   double price1 = y1;
   double price2 = y2;

   if(y1 < 0) price1 = 0;
   if(y2 < 0) price2 = 0;

   ObjectSetInteger(0, fullName, OBJPROP_TIME, 0, time1);
   ObjectSetDouble(0, fullName, OBJPROP_PRICE, 0, price1);
   ObjectSetInteger(0, fullName, OBJPROP_TIME, 1, time2);
   ObjectSetDouble(0, fullName, OBJPROP_PRICE, 1, price2);
}

//+------------------------------------------------------------------+
//| Calcule SL/TP adaptatifs selon le type de symbole                |
//+------------------------------------------------------------------+
void GetAdaptiveSLTP(double &sl_points, double &tp_points, double &trail_points)
{
   string symbol = _Symbol;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   
   // Détection du type de symbole
   bool isBoom = (StringFind(symbol, "Boom") >= 0);
   bool isCrash = (StringFind(symbol, "Crash") >= 0);
   bool isVolatility = (StringFind(symbol, "Volatility") >= 0 || StringFind(symbol, "VIX") >= 0);
   bool isStep = (StringFind(symbol, "Step") >= 0);
   bool isGold = (StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0);
   bool isSilver = (StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "SILVER") >= 0);
   bool isForex = (digits == 5 || digits == 3); // Forex typiquement 5 ou 3 digits
   
   // Valeurs par défaut (utilisées si aucune adaptation)
   sl_points = InpStopLoss;
   tp_points = InpTakeProfit;
   trail_points = InpTrailDist;
   
   // Adaptation selon le symbole
   if(isBoom || isCrash)
   {
      // Boom/Crash : SL/TP très serrés car mouvements rapides
      sl_points = 30;   // 30 points
      tp_points = 60;   // 60 points
      trail_points = 20; // 20 points
   }
   else if(isVolatility || isStep)
   {
      // Volatility/Step : Mouvements moyens
      sl_points = 50;
      tp_points = 100;
      trail_points = 30;
   }
   else if(isGold)
   {
      // Gold : Volatilité élevée, besoin d'espace
      sl_points = 150;  // ~15 pips pour Gold
      tp_points = 300;  // ~30 pips
      trail_points = 80; // ~8 pips
   }
   else if(isSilver)
   {
      // Silver : Similaire à Gold mais plus volatile
      sl_points = 200;
      tp_points = 400;
      trail_points = 100;
   }
   else if(isForex)
   {
      // Forex : Valeurs standards en points (pour 5 digits)
      sl_points = 100;  // 10 pips
      tp_points = 200;  // 20 pips
      trail_points = 50; // 5 pips
   }
   
   Print("📊 SL/TP adaptatifs pour ", symbol, " : SL=", sl_points, " TP=", tp_points, " Trail=", trail_points, " points");
}

//+------------------------------------------------------------------+
//| Valide et normalise la taille du lot selon les specs du symbole  |
//+------------------------------------------------------------------+
double ValidateLotSize(double lot)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // TOUJOURS utiliser le lot minimum du symbole (sécurité maximale)
   lot = minLot;
   
   // Arrondir au step le plus proche si nécessaire
   if(stepLot > 0)
      lot = MathRound(lot / stepLot) * stepLot;
   
   // S'assurer qu'on ne dépasse pas le max (normalement impossible avec minLot)
   if(lot > maxLot)
      lot = maxLot;
   
   // Normaliser à 2 décimales
   lot = NormalizeDouble(lot, 2);
   
   static bool firstCall = true;
   if(firstCall)
   {
      Print("✅ ValidateLotSize: Utilisation du lot MINIMUM pour ", _Symbol, " = ", lot);
      firstCall = false;
   }
   
   return lot;
}

//+------------------------------------------------------------------+
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNum);
   trade.SetTypeFillingBySymbol(_Symbol);  // Détecte automatiquement le mode de remplissage du symbole

   emaFast_H1 = iMA(_Symbol, PERIOD_H1, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_H1 = iMA(_Symbol, PERIOD_H1, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaFast_M15 = iMA(_Symbol, PERIOD_M15, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_M15 = iMA(_Symbol, PERIOD_M15, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaFast_M5 = iMA(_Symbol, PERIOD_M5, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_M5 = iMA(_Symbol, PERIOD_M5, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaFast_M1 = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_M1 = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);

   // Handle ATR M1 pour filtre anti-spike
   atr_M1_handle = iATR(_Symbol, PERIOD_M1, 14);
   if(atr_M1_handle == INVALID_HANDLE)
   {
      Print("Erreur lors de la création du handle ATR M1.");
      return(INIT_FAILED);
   }

   if(emaFast_M1 == INVALID_HANDLE || emaSlow_M1 == INVALID_HANDLE)
   {
      Print("ERREUR CRITIQUE : Impossible de créer EMA 9/21 M1");
      return INIT_FAILED;
   }

   supertrend_H1 = iCustom(_Symbol, PERIOD_H1, "Supertrend", Supertrend_Period, Supertrend_Multiplier);
   supertrend_M15 = iCustom(_Symbol, PERIOD_M15, "Supertrend", Supertrend_Period, Supertrend_Multiplier);
   supertrend_M5 = iCustom(_Symbol, PERIOD_M5, "Supertrend", Supertrend_Period, Supertrend_Multiplier);
   supertrend_M1 = iCustom(_Symbol, PERIOD_M1, "Supertrend", Supertrend_Period, Supertrend_Multiplier);

   isSupertrendAvailable = true;
   if(supertrend_H1 == INVALID_HANDLE || supertrend_M15 == INVALID_HANDLE ||
      supertrend_M5 == INVALID_HANDLE || supertrend_M1 == INVALID_HANDLE)
   {
      isSupertrendAvailable = false;
      Print("⚠️ Indicateur Supertrend non disponible pour ce symbole: ", _Symbol);
      Print("   Désactivation temporaire de Supertrend pour ce symbole");
   }

   maFast_M5 = iMA(_Symbol, PERIOD_M5, 12, 0, MODE_EMA, PRICE_CLOSE);
   maSlow_M5 = iMA(_Symbol, PERIOD_M5, 26, 0, MODE_EMA, PRICE_CLOSE);
   maFast_H1 = iMA(_Symbol, PERIOD_H1, 12, 0, MODE_EMA, PRICE_CLOSE);
   maSlow_H1 = iMA(_Symbol, PERIOD_H1, 26, 0, MODE_EMA, PRICE_CLOSE);
   rsi_H1 = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
   adx_H1 = iADX(_Symbol, PERIOD_H1, 14);
   atr_H1 = iATR(_Symbol, PERIOD_H1, 14);

   // Initialisation des variables SMC
   if(UseSMCAnalysis)
   {
      g_highestHigh = 0.0;
      g_lowestLow = 999999.0;
      g_highestHighTime = 0;
      g_lowestLowTime = 0;
      g_liquidityHigh = 0.0;
      g_liquidityLow = 0.0;
      g_liquiditySwept = false;
      g_lastSweepTime = 0;
      g_orderBlockHigh = 0.0;
      g_orderBlockLow = 0.0;
      g_orderBlockTime = 0;
      g_greedyMonkeysActive = false;
      g_fvgHigh = 0.0;
      g_fvgLow = 0.0;
      g_fvgTime = 0;
      g_bullishStructure = false;
      g_bearishStructure = false;
      
      Print("🧠 SMC Analysis initialisé - Smart Money Concepts activés");
   }

   bool hasIndicatorErrors = false;
   bool hasCriticalErrors = false;

   if(emaFast_H1 == INVALID_HANDLE || emaSlow_H1 == INVALID_HANDLE ||
      emaFast_M15 == INVALID_HANDLE || emaSlow_M15 == INVALID_HANDLE ||
      emaFast_M5 == INVALID_HANDLE || emaSlow_M5 == INVALID_HANDLE ||
      emaFast_M1 == INVALID_HANDLE || emaSlow_M1 == INVALID_HANDLE ||
      rsi_H1 == INVALID_HANDLE || adx_H1 == INVALID_HANDLE || atr_H1 == INVALID_HANDLE)
   {
      hasCriticalErrors = true;
      Print("❌ ERREUR CRITIQUE - Indicateurs techniques de base non disponibles");
      Print("   Symbole: ", _Symbol, " - Vérifiez la connexion et les données historiques");
   }

   if(UseSupertrendIndicator && !isSupertrendAvailable)
   {
      hasIndicatorErrors = true;
      Print("⚠️ AVERTISSEMENT - Supertrend désactivé (indicateur non disponible)");
   }

   if(hasCriticalErrors)
   {
      Print("❌ ERREUR CRITIQUE - Arrêt du robot");
      ExpertRemove();
      return INIT_FAILED;
   }

   if(hasIndicatorErrors)
   {
      Print("⚠️ Certains indicateurs multi-timeframes n'ont pas pu être créés");
      Print("   Le robot continuera de fonctionner avec les indicateurs disponibles");
   }

   if(!hasIndicatorErrors)
   {
      Print("✅ Tous les indicateurs multi-timeframes créés avec succès");
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   string reasonText = "";
   switch(reason)
   {
      case REASON_PROGRAM:      reasonText = "Program stopped"; break;
      case REASON_REMOVE:        reasonText = "Program removed from chart"; break;
      case REASON_RECOMPILE:     reasonText = "Program recompiled"; break;
      case REASON_CHARTCHANGE:   reasonText = "Symbol or timeframe changed"; break;
      case REASON_CHARTCLOSE:    reasonText = "Chart closed"; break;
      case REASON_PARAMETERS:    reasonText = "Input parameters changed"; break;
      case REASON_ACCOUNT:       reasonText = "Account changed"; break;
      default:                  reasonText = "Unknown reason"; break;
   }

   Print("🚨 DÉTACHEMENT DU ROBOT - Raison: ", reasonText, " (Code: ", reason, ")");

   if(reason == REASON_PROGRAM || reason == REASON_REMOVE)
   {
      Print("⚠️ Tentative de détachement manuel - Arrêt normal");
   }
   else if(reason == REASON_RECOMPILE)
   {
      Print("🔄 Recompilation du programme - Redémarrage automatique prévu");
   }
   else if(reason == REASON_CHARTCHANGE)
   {
      Print("📊 Changement de symbole/timeframe - Vérification nécessaire");
   }
   else if(reason == REASON_ACCOUNT)
   {
      Print("💰 Changement de compte - Arrêt de sécurité");
   }
   else
   {
      Print("❌ Détachement inattendu - Investigation requise");
   }

   IndicatorRelease(emaFast_H1);
   IndicatorRelease(emaSlow_H1);
   IndicatorRelease(emaFast_M15);
   IndicatorRelease(emaSlow_M15);
   IndicatorRelease(emaFast_M5);
   IndicatorRelease(emaSlow_M5);
   IndicatorRelease(emaFast_M1);
   IndicatorRelease(emaSlow_M1);
   IndicatorRelease(atr_M1_handle);

   if(supertrend_H1 != INVALID_HANDLE) IndicatorRelease(supertrend_H1);
   if(supertrend_M15 != INVALID_HANDLE) IndicatorRelease(supertrend_M15);
   if(supertrend_M5 != INVALID_HANDLE) IndicatorRelease(supertrend_M5);
   if(supertrend_M1 != INVALID_HANDLE) IndicatorRelease(supertrend_M1);

   IndicatorRelease(maFast_M5);
   IndicatorRelease(maSlow_M5);
   IndicatorRelease(maFast_H1);
   IndicatorRelease(maSlow_H1);
   IndicatorRelease(rsi_H1);
   IndicatorRelease(adx_H1);
   IndicatorRelease(atr_H1);

   ObjectsDeleteAll(0,"Prediction_");
   ObjectsDeleteAll(0,"MTF_");
   ObjectDelete(0,"Dashboard");
   ObjectsDeleteAll(0, "DASH_LEFT_");

   Print("🧹 Nettoyage des ressources terminé");
}

//+------------------------------------------------------------------+
//| SURVEILLANCE DE SANTÉ DU ROBOT                                |
//+------------------------------------------------------------------+
void CheckRobotHealth()
{
   static int errorCount = 0;
   static datetime lastErrorTime = 0;

   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      Print("❌ Perte de connexion au serveur détectée");
      errorCount++;
      lastErrorTime = TimeCurrent();
   }

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Print("❌ Trading non autorisé - Vérifier les paramètres MT5");
      errorCount++;
      lastErrorTime = TimeCurrent();
   }

   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("❌ Robot non autorisé à trader - Vérifier les paramètres");
      errorCount++;
      lastErrorTime = TimeCurrent();
   }

   if(errorCount == 0)
   {
      Print("✅ Robot en bonne santé - Connexion: OK - Trading: OK");
   }
   else
   {
      Print("⚠️ Robot avec ", errorCount, " erreurs - Dernière erreur: ", TimeToString(lastErrorTime));

      if(errorCount >= 5)
      {
         Print("🚨 NOMBRE D'ERREURS ÉLEVÉ - Risque de détachement!");
      }
   }

   if(TimeCurrent() - lastErrorTime > 300)
   {
      errorCount = 0;
   }
}

//+------------------------------------------------------------------+
//| FONCTIONS DE GESTION DES RISQUES                                |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   if(!UseTimeBasedTrading) return true;

   datetime now = TimeCurrent();
   MqlDateTime timeStruct;
   TimeToStruct(now, timeStruct);

   string startParts[];
   string endParts[];
   StringSplit(TradingStartTime, ':', startParts);
   StringSplit(TradingEndTime, ':', endParts);

   int startMin = (int)StringToInteger(startParts[0]) * 60 + (int)StringToInteger(startParts[1]);
   int endMin = (int)StringToInteger(endParts[0]) * 60 + (int)StringToInteger(endParts[1]);
   int currentMin = timeStruct.hour * 60 + timeStruct.min;

   return (currentMin >= startMin && currentMin <= endMin);
}

//+------------------------------------------------------------------+
//| VÉRIFICATION DE LA PERTE JOURNALIÈRE (USD)                       |
//+------------------------------------------------------------------+
bool IsDailyLossLimitExceeded()
{
   if(MaxDailyLossUSD <= 0) return false;

   // Réinitialisation journalière
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   
   // Utiliser la variable globale pour la réinitialisation journalière
   if(g_lastDailyReset != now.day)
   {
      g_lastDailyReset = now.day;
      g_dailyLossTotal = 0.0; // Réinitialiser le cumul des pertes
      Print("☀️ Nouvelle journée de trading détectée - Réinitialisation des pertes journalières");
   }

   // Calculer les pertes du jour depuis l'historique (pour être précis)
   double dailyProfit = 0.0;
   datetime startOfDay = iTime(_Symbol, PERIOD_D1, 0);
   
   if(HistorySelect(startOfDay, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      for(int i = 0; i < total; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNum)
            {
               dailyProfit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
               dailyProfit += HistoryDealGetDouble(ticket, DEAL_SWAP);
               dailyProfit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            }
         }
      }
   }

   // Mettre à jour le cumul des pertes
   if(dailyProfit < 0)
      g_dailyLossTotal = MathAbs(dailyProfit);

   if(dailyProfit <= -MaxDailyLossUSD)
   {
      static datetime lastAlert = 0;
      if(TimeCurrent() - lastAlert > 300) // Message toutes les 5 minutes au lieu d'une heure
      {
         Print("⚠️ Limite de perte journalière atteinte: ", DoubleToString(dailyProfit, 2), "$ (Limite: ", DoubleToString(MaxDailyLossUSD, 2), "$)");
         lastAlert = TimeCurrent();
      }
      return true;
   }

   return false;
}

bool IsDailyDrawdownExceeded()
{
   if(MaxDailyDrawdownPercent <= 0) return false;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(balance <= 0) return true;

   double drawdownPercent = ((balance - equity) / balance) * 100;

   if(drawdownPercent >= MaxDailyDrawdownPercent)
   {
      Print("⚠️ Drawdown quotidien de ", DoubleToString(drawdownPercent, 2), "% atteint (limite: ", DoubleToString(MaxDailyDrawdownPercent, 2), "%)");
      return true;
   }

   return false;
}

bool IsMaxPositionsReached()
{
   if(MaxOpenPositions <= 0) return false;

   int totalPositions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
         totalPositions++;
   }

   if(totalPositions >= MaxOpenPositions)
   {
      Print("⚠️ Nombre maximum de positions (", MaxOpenPositions, ") atteint");
      return true;
   }

   return false;
}

double CalculateLotSize(double stopLossPips)
{
   if(stopLossPips <= 0) return InpLots;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPerTrade / 100.0);

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(tickSize == 0 || tickValue == 0 || point == 0)
      return InpLots;

   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double moneyPerLot = (stopLossPips * point * tickValue) / tickSize;
   double lots = NormalizeDouble(riskAmount / moneyPerLot, 2);

   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   return lots;
}

//+------------------------------------------------------------------+
//| FERMETURE AMÉLIORÉE AVEC GESTION DES MODES DE FILLING         |
//+------------------------------------------------------------------+
bool ClosePositionWithFallback(ulong ticket)
{
   CTrade tradeLocal;
   tradeLocal.SetExpertMagicNumber(InpMagicNum);
   
   if(!PositionSelectByTicket(ticket))
   {
      Print("❌ Impossible de sélectionner la position ", ticket);
      return false;
   }
   
   string symbol = PositionGetString(POSITION_SYMBOL);
   
   // Essayer d'abord avec le mode par défaut
   if(tradeLocal.PositionClose(ticket))
   {
      Print("✅ Position fermée: ", ticket, " (mode par défaut)");
      return true;
   }
   
   // Si échec, essayer avec le mode de filling spécifique pour les symboles spéciaux
   bool isSpecialSymbol = (StringFind(symbol, "Step") >= 0 || 
                         StringFind(symbol, "Boom") >= 0 || 
                         StringFind(symbol, "Crash") >= 0 ||
                         StringFind(symbol, "Volatility") >= 0);
   
   if(isSpecialSymbol)
   {
      // Essayer avec ORDER_FILLING_IOC pour les symboles spéciaux
      tradeLocal.SetTypeFilling(ORDER_FILLING_IOC);
      
      if(tradeLocal.PositionClose(ticket))
      {
         Print("✅ Position fermée: ", ticket, " (mode IOC)");
         return true;
      }
      
      // Essayer avec ORDER_FILLING_FOK
      tradeLocal.SetTypeFilling(ORDER_FILLING_FOK);
      
      if(tradeLocal.PositionClose(ticket))
      {
         Print("✅ Position fermée: ", ticket, " (mode FOK)");
         return true;
      }
      
      // Dernier essai: fermeture par ordre de marché inverse
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double price = SymbolInfoDouble(symbol, (posType == POSITION_TYPE_BUY) ? SYMBOL_BID : SYMBOL_ASK);
      
      tradeLocal.SetTypeFilling(ORDER_FILLING_IOC);
      
      if(posType == POSITION_TYPE_BUY)
      {
         if(tradeLocal.Sell(volume, symbol, price, 0, 0, "Fermeture forcée"))
         {
            Print("✅ Position fermée par ordre SELL: ", ticket);
            return true;
         }
      }
      else
      {
         if(tradeLocal.Buy(volume, symbol, price, 0, 0, "Fermeture forcée"))
         {
            Print("✅ Position fermée par ordre BUY: ", ticket);
            return true;
         }
      }
   }
   
   Print("❌ Échec fermeture position ", ticket, " - Erreur: ", tradeLocal.ResultRetcode(), " - ", tradeLocal.ResultRetcodeDescription());
   return false;
}

void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum)
         continue;

      ClosePositionWithFallback(ticket);
   }
}

bool IsEmergencyStopActivated()
{
   if(!UseEmergencyStop) return false;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   if(balance <= 0) return true;

   double drawdownPercent = ((balance - equity) / balance) * 100;

   if(drawdownPercent >= EmergencyStopDrawdown)
   {
      Print("🛑 ARRÊT D'URGENCE: Drawdown de ", DoubleToString(drawdownPercent, 2), "% atteint (limite: ", DoubleToString(EmergencyStopDrawdown, 2), "%)");
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| VÉRIFICATION DU RISQUE MAXIMUM PAR TRADE (5$)                   |
//+------------------------------------------------------------------+
void CheckMaxLossPerTrade()
{
   if(MaxLossPerTradeUSD <= 0) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      string symbol = PositionGetString(POSITION_SYMBOL);
      
      // Fermeture automatique si perte >= 5$
      if(profit <= -MaxLossPerTradeUSD)
      {
         if(ClosePositionWithFallback(ticket))
         {
            Print("🛑 FERMETURE AUTOMATIQUE - Perte de ", DoubleToString(profit, 2), 
                  "$ sur ", symbol, " (limite: ", DoubleToString(MaxLossPerTradeUSD, 2), "$)");
         }
         else
         {
            Print("❌ Erreur fermeture automatique position ", symbol);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| GESTION DES RISQUES - Calcul profit net quotidien                 |
//+------------------------------------------------------------------+
//| Retourne le profit net (profit + swap + commission) réalisé       |
//| aujourd'hui par cet EA (magic number InpMagicNum)                 |
//+------------------------------------------------------------------+
double CalculateDailyNetProfit()
{
   double net_profit = 0.0;
   
   // On prend le début de la journée actuelle
   datetime today_start = iTime(_Symbol, PERIOD_D1, 0);
   
   if(!HistorySelect(today_start, TimeCurrent()))
   {
      Print("CalculateDailyNetProfit → HistorySelect a échoué");
      return 0.0;
   }
   
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNum) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      
      // On ne prend que les deals de type BUY/SELL (pas les dépôts/retraits)
      long entry_type = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry_type != DEAL_ENTRY_IN && entry_type != DEAL_ENTRY_OUT) continue;
      
      double profit     = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      double swap       = HistoryDealGetDouble(ticket, DEAL_SWAP);
      double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      
      net_profit += profit + swap + commission;
   }
   
   return net_profit;
}

//+------------------------------------------------------------------+
//| FILTRE LOCAL DE SÉCURITÉ - Validation technique supplémentaire    |
//+------------------------------------------------------------------+
bool IsLocalFilterValid(string aiDirection, double aiConfidence, string &outReason)
{
   outReason = "";
   
   // Récupération indicateurs (ajuste les shifts si besoin)
   double rsi[1], macd_main[1], macd_sig[1], ema9[1], ema21[1], atr[1];
   
   if(CopyBuffer(rsi_H1,         0, 0, 1, rsi)      !=1 ||
      CopyBuffer(emaFast_M1,0, 0, 1, ema9)   !=1 ||
      CopyBuffer(emaSlow_M1,0, 0, 1, ema21)  !=1 ||
      CopyBuffer(atr_M1_handle,    0, 0, 1, atr)    !=1)
   {
      outReason = "Erreur copie buffers indicateurs";
      return false;
   }
   
   // MACD (tu peux créer le handle dans OnInit si absent)
   int macd_handle = iMACD(_Symbol, PERIOD_M1, 12,26,9, PRICE_CLOSE);
   if(CopyBuffer(macd_handle, 0, 0, 1, macd_main) !=1 ||
      CopyBuffer(macd_handle, 1, 0, 1, macd_sig)  !=1)
   {
      outReason = "Erreur MACD";
      return false;
   }
   
   bool isBuyDirection  = (StringFind(aiDirection,"BUY")>=0 || StringFind(aiDirection,"LONG")>=0);
   bool isSellDirection = (StringFind(aiDirection,"SELL")>=0 || StringFind(aiDirection,"SHORT")>=0);
   
   int conditionsOK = 0;
   
   // Condition 1 : tendance EMA
   if(isBuyDirection  && ema9[0] > ema21[0]) conditionsOK++;
   if(isSellDirection && ema9[0] < ema21[0]) conditionsOK++;
   
   // Condition 2 : RSI pas extrême
   if(isBuyDirection  && rsi[0] < 68.0) conditionsOK++;
   if(isSellDirection && rsi[0] > 32.0) conditionsOK++;
   
   // Condition 3 : MACD haussier/baissier
   if(isBuyDirection  && macd_main[0] > macd_sig[0]) conditionsOK++;
   if(isSellDirection && macd_main[0] < macd_sig[0]) conditionsOK++;
   
   // Condition 4 : volatilité raisonnable (ATR pas trop élevé)
   double atr_avg[1];
   if(CopyBuffer(iATR(_Symbol, PERIOD_M1, 50), 0, 0, 1, atr_avg) > 0 && atr[0] < 1.6 * atr_avg[0]) conditionsOK++;
   
   // Règle finale - ajustée pour le nouveau seuil de 68%
   int requiredConditions = (aiConfidence >= 0.68) ? 2 : 3;
   
   if(conditionsOK >= requiredConditions)
   {
      outReason = StringFormat("Local OK (%d/%d conditions)", conditionsOK, requiredConditions);
      return true;
   }
   
   outReason = StringFormat("Local refusé (%d/%d conditions) - confiance IA=%.2f", 
                            conditionsOK, requiredConditions, aiConfidence);
   return false;
}

//+------------------------------------------------------------------+
//| GESTION DES RISQUES - Calcul taille de lot basée sur le risque     |
//+------------------------------------------------------------------+
double CalculateRiskBasedLotSize(double riskPercent = 1.0, double stopLossPoints = 0.0)
{
   if(riskPercent <= 0.0) return InpLots; // sécurité : fallback valeur input
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(accountBalance <= 0.0) return 0.0;
   
   double riskAmountUSD = accountBalance * (riskPercent / 100.0);
   
   // Valeur monétaire d'un point pour 1 lot
   double tickValue  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(tickValue == 0.0 || tickSize == 0.0 || point == 0.0)
   {
      Print("CalculateRiskBasedLotSize → Impossible de récupérer tickValue/tickSize/point");
      return InpLots; // fallback
   }
   
   double valuePerPointPerLot = tickValue / (tickSize / point);
   
   // Si on n'a pas de SL valide → on utilise une valeur par défaut conservatrice
   double slPoints = (stopLossPoints > 10) ? stopLossPoints : 300.0; // 300 points par défaut pour Boom/Crash
   
   double lotSize = riskAmountUSD / (slPoints * valuePerPointPerLot);
   
   // Respect des contraintes du broker
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   // Arrondi au step le plus proche
   if(lotStep > 0.0)
      lotSize = MathRound(lotSize / lotStep) * lotStep;
   
   lotSize = NormalizeDouble(lotSize, 2);
   
   PrintFormat("CalculateRiskBasedLotSize → Balance=%.2f$ | Risque=%.1f%% | SL=%.0f pts → Lot=%.2f",
               accountBalance, riskPercent, slPoints, lotSize);
   
   return lotSize;
}

//+------------------------------------------------------------------+
//| GESTION TRAILING STOP + BREAKEVEN AUTOMATIQUE                 |
//+------------------------------------------------------------------+
void ManageTrailingAndBreakeven()
{
   if(!InpUseTrailing) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL   = PositionGetDouble(POSITION_SL);
      double currentTP   = PositionGetDouble(POSITION_TP);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double profitPoints = 0.0;
      
      if(posType == POSITION_TYPE_BUY)
         profitPoints = (currentPrice - openPrice) / point;
      else
         profitPoints = (openPrice - currentPrice) / point;
      
      // ───────────────────────────────
      // 1. Breakeven : dès + BreakevenTriggerPips
      // ───────────────────────────────
      static ulong lastBreakevenSet[MAX_TRACKED_TICKETS];
      static int breakevenCount = 0;
      
      bool alreadyBreakeven = false;
      for(int j = 0; j < breakevenCount; j++)
         if(lastBreakevenSet[j] == ticket) { alreadyBreakeven = true; break; }
      
      if(profitPoints >= BreakevenTriggerPips && !alreadyBreakeven)
      {
         double newSL = 0.0;
         if(posType == POSITION_TYPE_BUY)
            newSL = openPrice + BreakevenBufferPips * point;
         else
            newSL = openPrice - BreakevenBufferPips * point;
         
         newSL = NormalizeDouble(newSL, _Digits);
         
         if((posType == POSITION_TYPE_BUY && newSL > currentSL + point) ||
            (posType == POSITION_TYPE_SELL && (currentSL == 0 || newSL < currentSL - point)))
         {
            if(trade.PositionModify(ticket, newSL, currentTP))
            {
               PrintFormat("Breakeven activé ticket %I64u | Profit: %.1f pts | New SL: %.5f", ticket, profitPoints, newSL);
               
               if(breakevenCount < MAX_TRACKED_TICKETS)
                  lastBreakevenSet[breakevenCount++] = ticket;
            }
         }
      }
      
      // ───────────────────────────────
      // 2. Trailing stop normal
      // ───────────────────────────────
      double trailDistance = InpTrailDist * point;
      
      // Mode plus agressif Boom/Crash après un certain profit
      if(profitPoints > BoomCrashTrailStartPips)
      {
         trailDistance = MathMin(trailDistance, BoomCrashTrailDistPips * point);
      }
      
      double newSL = 0.0;
      
      if(posType == POSITION_TYPE_BUY)
      {
         newSL = currentPrice - trailDistance;
         if(newSL > currentSL + point) // on Ne modifie que si meilleur
         {
            newSL = NormalizeDouble(newSL, _Digits);
            if(trade.PositionModify(ticket, newSL, currentTP))
               PrintFormat("Trailing BUY ticket %I64u | Profit: %.1f pts | New SL: %.5f", ticket, profitPoints, newSL);
         }
      }
      else // SELL
      {
         newSL = currentPrice + trailDistance;
         if(currentSL == 0 || newSL < currentSL - point)
         {
            newSL = NormalizeDouble(newSL, _Digits);
            if(trade.PositionModify(ticket, newSL, currentTP))
               PrintFormat("Trailing SELL ticket %I64u | Profit: %.1f pts | New SL: %.5f", ticket, profitPoints, newSL);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| VÉRIFICATION FENÊTRE HORAIRE AUTORISÉE (7h-23h UTC)    |
//+------------------------------------------------------------------+
bool IsTradingTimeAllowed()
{
   MqlDateTime t;
   TimeToStruct(TimeCurrent(), t);
   
   int hourUTC = t.hour;  // TimeCurrent() est déjà en UTC sur la plupart des brokers Deriv
   
   // 7h → 23h UTC = 7:00 à 22:59
   if(hourUTC < 7 || hourUTC >= 23)
   {
      static datetime lastTimeMsg = 0;
      if(TimeCurrent() - lastTimeMsg >= 900) // toutes les 15 min
      {
         Print("Hors fenêtre autorisée (7h-23h UTC) → trading bloqué");
         lastTimeMsg = TimeCurrent();
      }
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| GESTION DES GAINS SUCCESSIFS - Protection contre la surconfiance   |
//+------------------------------------------------------------------+
void ManageSuccessiveGainsProtection()
{
   if(!UseSuccessiveGainsProtection) return;
   
   // Vérifier si le mode protection doit se terminer
   if(isProtectionMode && TimeCurrent() - protectionStartTime > ProtectionDurationMinutes * 60)
   {
      isProtectionMode = false;
      consecutiveWins = 0; // Réinitialiser après protection
      Print("🛡️ FIN MODE PROTECTION - Retour au trading normal");
      SendNotification("GoldRush: Fin du mode protection - Trading normal repris");
   }
   
   // Vérifier si le mode pause doit se terminer
   if(isBreakMode && TimeCurrent() - breakStartTime > BreakDurationMinutes * 60)
   {
      isBreakMode = false;
      consecutiveLosses = 0; // Réinitialiser après pause
      Print("⏸️ FIN MODE PAUSE - Retour au trading normal");
      SendNotification("GoldRush: Fin de la pause - Trading normal repris");
   }
   
   // Analyser les trades récents pour détecter gains/pertes successifs
   static datetime lastAnalysis = 0;
   if(TimeCurrent() - lastAnalysis < 10) return; // Analyser toutes les 10 secondes max
   lastAnalysis = TimeCurrent();
   
   // Parcourir l'historique des trades récents
   if(HistorySelect(0, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      for(int i = total - 1; i >= MathMax(0, total - 10); i--) // Analyser les 10 derniers trades
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         
         datetime closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
         
         // Ne considérer que les trades fermés depuis la dernière analyse
         if(closeTime <= lastTradeCloseTime) continue;
         
         // Ne considérer que les trades de notre symbole et magic number
         string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         if(symbol != _Symbol || magic != InpMagicNum) continue;
         
         // Traiter le trade
         if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
         {
            if(profit >= MinProfitForWin)
            {
               // Gain détecté
               consecutiveWins++;
               consecutiveLosses = 0;
               Print("📈 GAIN DÉTECTÉ: ", DoubleToString(profit, 2), "$ - Gains successifs: ", consecutiveWins);
               
               // Activer le mode protection si trop de gains successifs
               if(consecutiveWins >= MaxConsecutiveWins && !isProtectionMode)
               {
                  isProtectionMode = true;
                  protectionStartTime = TimeCurrent();
                  originalLotSize = InpLots;
                  Print("🛡️ MODE PROTECTION ACTIVÉ - Trop de gains successifs (", consecutiveWins, ")");
                  Print("📉 RISQUE RÉDUIT DE ", DoubleToString(ProtectionRiskReduction * 100, 0), "% PENDANT ", ProtectionDurationMinutes, " MINUTES");
                  SendNotification("GoldRush: Mode protection activé - Trop de gains successifs");
               }
            }
            else if(profit < 0)
            {
               // Perte détectée
               consecutiveLosses++;
               consecutiveWins = 0;
               Print("📉 PERTE DÉTECTÉE: ", DoubleToString(profit, 2), "$ - Pertes successives: ", consecutiveLosses);
               
               // Activer le mode pause si trop de pertes successives
               if(consecutiveLosses >= MaxConsecutiveLosses && !isBreakMode && UseBreakAfterLosses)
               {
                  isBreakMode = true;
                  breakStartTime = TimeCurrent();
                  Print("⏸️ MODE PAUSE ACTIVÉ - Trop de pertes successives (", consecutiveLosses, ")");
                  Print("⏸️ PAUSE DE ", BreakDurationMinutes, " MINUTES POUR ÉVITER LES PERTES");
                  SendNotification("GoldRush: Mode pause activé - Trop de pertes successives");
               }
            }
            
            lastTradeCloseTime = closeTime;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier si le trading est autorisé (protection/pause)          |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
   // Mode pause : aucun trading autorisé
   if(isBreakMode)
   {
      static datetime lastBreakMessage = 0;
      if(TimeCurrent() - lastBreakMessage > 60) // Message toutes les minutes
      {
         int remainingMinutes = BreakDurationMinutes - (int)((TimeCurrent() - breakStartTime) / 60);
         Print("⏸️ MODE PAUSE ACTIF - Trading suspendu (", remainingMinutes, " min restantes)");
         lastBreakMessage = TimeCurrent();
      }
      return false;
   }
   
   // Mode protection : trading autorisé mais avec risque réduit
   if(isProtectionMode)
   {
      static datetime lastProtectionMessage = 0;
      if(TimeCurrent() - lastProtectionMessage > 60) // Message toutes les minutes
      {
         int remainingMinutes = ProtectionDurationMinutes - (int)((TimeCurrent() - protectionStartTime) / 60);
         Print("🛡️ MODE PROTECTION ACTIF - Risque réduit de ", DoubleToString(ProtectionRiskReduction * 100, 0), "% (", remainingMinutes, " min restantes)");
         lastProtectionMessage = TimeCurrent();
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Obtenir la taille de lot ajustée selon le mode de protection       |
//+------------------------------------------------------------------+
double GetAdjustedLotSize()
{
   double adjustedLot = InpLots;
   
   if(isProtectionMode)
   {
      adjustedLot = InpLots * (1.0 - ProtectionRiskReduction);
      Print("📉 Lot ajusté pour mode protection: ", DoubleToString(adjustedLot, 2), " (original: ", DoubleToString(InpLots, 2), ")");
   }
   
   // S'assurer que le lot est valide
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   adjustedLot = MathMax(adjustedLot, minLot);
   adjustedLot = MathMin(adjustedLot, maxLot);
   adjustedLot = MathFloor(adjustedLot / lotStep) * lotStep;
   
   return adjustedLot;
}

//+------------------------------------------------------------------+
//| ON TICK                                                          |
//+------------------------------------------------------------------+
void OnTick()
{
   // Limiter l'exécution à toutes les 5 secondes maximum pour éviter de surcharger MT5
   static datetime lastTickTime = 0;
   static datetime lastLogLocalFilter = 0;
   static datetime lastLocalFilterLog = 0;
   static datetime last_daily_profit_check = 0;
   if(TimeCurrent() - lastTickTime < 5)
      return;
   lastTickTime = TimeCurrent();

   // ────────────────────────────────────────────────
   // Initialisation des variables IA pour le dashboard
   // ────────────────────────────────────────────────
   if(g_lastAIAction == "")
   {
      g_lastAIAction = "hold";
      g_lastAIConfidence = 0.50;
   }

   // ────────────────────────────────────────────────
   // Mise à jour dashboard gauche (toujours exécuté)
   // ────────────────────────────────────────────────
   if(TimeCurrent() - lastDashboardUpdate >= 10)  // Mise à jour toutes les 10 secondes
   {
      UpdateLeftDashboard();
      lastDashboardUpdate = TimeCurrent();
      static int dashboardDebugCounter = 0;
      if(++dashboardDebugCounter % 6 == 0) // Message toutes les 60 secondes
         Print("📊 Dashboard GoldRush actif - Mise à jour toutes les 10 secondes");
   }
   
   // ────────────────────────────────────────────────
   // Nettoyage des objets expirés (toutes les 5 minutes)
   // ────────────────────────────────────────────────
   static datetime lastCleanupTime = 0;
   if(TimeCurrent() - lastCleanupTime >= 300) // Nettoyer toutes les 5 minutes
   {
      CleanExpiredObjects();
      lastCleanupTime = TimeCurrent();
      Print("🧹 Nettoyage des objets graphiques expirés - GoldRush");
   }

   // ────────────────────────────────────────────────
   // Objectif journalier atteint → on arrête de trader aujourd'hui
   // ──────────────────────────
   double current_daily_net = CalculateDailyNetProfit();

   if(current_daily_net >= 50.0)   // Augmenté pour tests (était 10$)
   {
      if(TimeCurrent() - last_daily_profit_check >= 300) // Message toutes les 5 minutes au lieu d'une heure
      {
         PrintFormat("🎯 Objectif journalier NET atteint : +%.2f USD → plus de trades aujourd'hui", current_daily_net);
         last_daily_profit_check = TimeCurrent();
      }
      return;   // ← on sort immédiatement de OnTick()
   }

   // Vérification fenêtre horaire autorisée (7h-23h UTC)
   if(!IsTradingTimeAllowed()) return;

   // ────────────────────────────────────────────────
   // STOP PERTE JOURNALIER STRICT -20 $
   // ────────────────────────────────────────────────
   double dailyNet = CalculateDailyNetProfit();

   if(dailyNet <= -20.0)
   {
      static datetime lastDailyLossMsg = 0;
      if(TimeCurrent() - lastDailyLossMsg >= 300)
      {
         PrintFormat("!!! STOP PERTE JOURNALIER ATTEINT : %.2f $ → aucun trade aujourd'hui", dailyNet);
         lastDailyLossMsg = TimeCurrent();
      }
      return;
   }

   if(IsEmergencyStopActivated())
   {
      Print("🛑 ARRÊT D'URGENCE - Fermeture de toutes les positions");
      CloseAllPositions();
      ExpertRemove();
      return;
   }

   // Gestion des gains successifs - Protection contre la surconfiance
   ManageSuccessiveGainsProtection();
   
   // Vérifier si le trading est autorisé (protection/pause)
   if(!IsTradingAllowed())
   {
      return; // Ne rien faire si en mode pause ou protection
   }

   // Vérification de la limite de perte journalière DÉSACTIVÉE
   // if(IsDailyLossLimitExceeded())
   // {
   //    Print("⚠️ Limite de perte journalière dépassée - Aucun nouveau trade autorisé aujourd'hui");
   //    return;
   // }

   // Vérification du drawdown quotidien DÉSACTIVÉE
   // if(IsDailyDrawdownExceeded())
   // {
   //    Print("⚠️ Drawdown quotidien dépassé - Aucun nouveau trade autorisé aujourd'hui");
   //    return;
   // }

   // Vérification du risque de 5$ par trade
   CheckMaxLossPerTrade();
   
   // Analyse SMC DÉSACTIVÉE pour performance
   // AnalyzeSMC();

   // Restrictions de temps de trading désactivées - trading 24/7
   // if(!IsTradingTime())
   // {
   //    static datetime lastAlert = 0;
   //    if(TimeCurrent() - lastAlert >= 3600)
   //    {
   //       Print("⏱️ Hors des heures de trading - Le trading est désactivé");
   //       lastAlert = TimeCurrent();
   //    }
   //    return;
   // }

   if(IsMaxPositionsReached())
   {
      static datetime lastPosAlert = 0;
      if(TimeCurrent() - lastPosAlert >= 300)
      {
         Print("⚠️ Nombre maximum de positions atteint (", MaxOpenPositions, ")");
         lastPosAlert = TimeCurrent();
      }
      return;
   }

   static datetime lastHealthCheck = 0;
   if(TimeCurrent() - lastHealthCheck >= 60)
   {
      lastHealthCheck = TimeCurrent();
      CheckRobotHealth();
   }

   bool isBoomCrash = (StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0);

   static datetime lastLogTime = 0;
   if(TimeCurrent() - lastLogTime > 60)
   {
      lastLogTime = TimeCurrent();
      Print("🔍 État du trailing stop - Actif: ", InpUseTrailing ? "OUI" : "NON",
            ", Boom/Crash: ", isBoomCrash ? "OUI" : "NON",
            ", UseBoomCrashAutoClose: ", UseBoomCrashAutoClose ? "OUI" : "NON");
   }

   // Système intelligent: breakeven + prise partielle + trailing sécurisé (prioritaire)
   ManageIntelligentStops();

   if(UseBoomCrashAutoClose && isBoomCrash)
   {
      if(TimeCurrent() - lastLogTime > 60)
         Print("🔍 Gestion des positions Boom/Crash active");
      ManageBoomCrashPositions();
   }

   // Trailing stop réactivé pour toutes les positions (mode léger)
   if(InpUseTrailing)
   {
      static datetime lastTrailingUpdate = 0;
      if(TimeCurrent() - lastTrailingUpdate >= 10) // Toutes les 10 secondes max
      {
         lastTrailingUpdate = TimeCurrent();
         
         // Appliquer le trailing stop sur toutes les positions du robot
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket <= 0) continue;
            
            if(!PositionSelectByTicket(ticket)) continue;
            if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            
            // Vérifier si profit >= 2$ et fermer automatiquement
            CheckAndCloseProfitTarget(ticket);
            
            // Appliquer le trailing stop
            ManageTrailingStopForPosition(ticket);
         }
      }
   }

   if(UseProfitDuplication)
      ManageAdvancedProfits();

   if(UseAllEndpoints)
      UpdateAllEndpoints();

   if(UseAI_Agent && TimeCurrent() - lastAIUpdate >= (UseUltraLightMode ? AIUpdateIntervalMin : AI_UpdateInterval))
   {
      UpdateAISignal();
      lastAIUpdate = TimeCurrent();
   }

   // Mise à jour du tableau de bord (recommandations IA, signaux, confiance Render) — visible même sans nouveau bar
   if(UseAdvancedDashboard)
   {
      static datetime lastDashboardUpdate_MT5 = 0;
      int refreshInterval = UseUltraLightMode ? DashboardRefreshMin : DashboardRefresh;
      if(TimeCurrent() - lastDashboardUpdate_MT5 >= MathMax(refreshInterval, 5))
      {
         lastDashboardUpdate_MT5 = TimeCurrent();
         double rsiVal = 50.0, adxVal = 0.0, atrVal = 0.0;
         if(rsi_H1 != INVALID_HANDLE) { double buf[1]; if(CopyBuffer(rsi_H1, 0, 0, 1, buf) > 0) rsiVal = buf[0]; }
         if(adx_H1 != INVALID_HANDLE) { double buf[1]; if(CopyBuffer(adx_H1, 0, 0, 1, buf) > 0) adxVal = buf[0]; }
         if(atr_H1 != INVALID_HANDLE) { double buf[1]; if(CopyBuffer(atr_H1, 0, 0, 1, buf) > 0) atrVal = buf[0]; }
         DrawAdvancedDashboard(rsiVal, adxVal, atrVal);
      }
   }

   // Gestion du trailing stop et breakeven
   static datetime lastTrailCheck = 0;
   if(TimeCurrent() - lastTrailCheck >= 5)
   {
      ManageTrailingAndBreakeven();
      lastTrailCheck = TimeCurrent();
   }

   // Gestion du trailing stop et breakeven
   ManageTrailingAndBreakeven();

   datetime barTime = iTime(_Symbol, PERIOD_M5, 0);
   if(barTime == lastBarTime)
      return;

   lastBarTime = barTime;

   if(PositionsTotal() > 0)
   {
      g_hasPosition = true;
      return;
   }
   else
   {
      g_hasPosition = false;
      hasDuplicated = false;
      duplicatedPositionTicket = 0;
   }

   // Limiter les mises à jour IA à toutes les 30 secondes pour performance
   if(TimeCurrent() - lastAIUpdate < 30)
      return;
   lastAIUpdate = TimeCurrent();

   if(!DisableHeavyFunctions && (UseMultiTimeframeEMA || UseSupertrendIndicator))
      UpdateMultiTimeframeData(); // Seulement si activé et non désactivé

   // === MODE ULTRA-LÉGER : PAS DE MISES À JOUR LOURDES ===
   // Toutes les fonctions lourdes sont désactivées pour performance
   
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if(!IsSymbolAllowedForTrading())
   {
      Print("❌ Trading non autorisé sur ce symbole: ", _Symbol);
      return;
   }

   bool shouldTrade = false;
   ENUM_ORDER_TYPE tradeType = WRONG_VALUE;

   // === LOGIQUE ULTRA-SIMPLE : SEULEMENT SIGNAUX DE BASE + STRATÉGIE BOOM/CRASH ===
   
   // Vérifier le type de symbole
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   
   // Priorité 1: Stratégie Boom/Crash optimisée (BUY sur Boom, SELL sur Crash)
   if(isBoom || isCrash)
   {
      double rsiValue = 50.0;
      if(rsi_H1 != INVALID_HANDLE)
      {
         double rsiBuf[1];
         if(CopyBuffer(rsi_H1, 0, 0, 1, rsiBuf) > 0) 
            rsiValue = rsiBuf[0];
      }
      
      // Stratégie Boom : FORCER BUY si conditions techniques
      if(isBoom)
      {
         // Conditions pour BUY sur Boom : RSI en survente + prix > MA
         if(rsiValue < RSI_Oversold_Level) // RSI < 40 = survente = signal BUY
         {
            shouldTrade = true;
            tradeType = ORDER_TYPE_BUY;
            Print("🚀 BOOM BUY FORCÉ - RSI survente (", DoubleToString(rsiValue, 1), " < ", DoubleToString(RSI_Oversold_Level, 1), ")");
         }
      }
      // Stratégie Crash : FORCER SELL si conditions techniques
      else if(isCrash)
      {
         // Conditions pour SELL sur Crash : RSI en surachat + prix < MA
         if(rsiValue > RSI_Overbought_Level) // RSI > 60 = surachat = signal SELL
         {
            shouldTrade = true;
            tradeType = ORDER_TYPE_SELL;
            Print("🚀 CRASH SELL FORCÉ - RSI surachat (", DoubleToString(rsiValue, 1), " > ", DoubleToString(RSI_Overbought_Level, 1), ")");
         }
      }
   }
   
   // Priorité 2: Stratégie Greedy Monkeys (si active) - seulement pour autres symboles
   if(!shouldTrade && !isBoom && !isCrash && UseGreedyMonkeysStrategy && g_greedyMonkeysActive)
   {
      double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
      
      // Acheter après sweep de liquidité inférieure avec rebond
      if(currentPrice > g_liquidityLow * 1.001 && g_liquidityLow > 0)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_BUY;
         Print("🐵 Greedy Monkeys: ACHAT après sweep liquidité basse");
      }
      // Vendre après sweep de liquidité supérieure avec rebond
      else if(currentPrice < g_liquidityHigh * 0.999 && g_liquidityHigh > 0)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_SELL;
         Print("🐵 Greedy Monkeys: VENTE après sweep liquidité haute");
      }
      
      // Réinitialiser l'état Greedy Monkeys après utilisation
      if(shouldTrade)
      {
         g_greedyMonkeysActive = false;
      }
   }
   
   // Priorité 2: Utiliser les signaux IA si disponibles avec confiance >= seuil configuré
   if(!shouldTrade && UseAI_Agent && HasStrongSignal())
   {
      // ─────────────────────────────────────────────────────────────
      // Filtre local de sécurité – doit être validé EN PLUS de l'IA
      // ─────────────────────────────────────────────────────────────
      string filterReason = "";
      if(!IsLocalFilterValid(g_lastAIAction, g_lastAIConfidence, filterReason))
      {
         if(TimeCurrent() - lastLocalFilterLog > 120) // log toutes les 2 minutes max
         {
            Print("Filtre local → TRADE BLOQUÉ | Raison : ", filterReason);
            lastLocalFilterLog = TimeCurrent();
         }
         return;  // ou continue; selon où tu es exactement dans OnTick()
      }
      else
      {
         Print("Filtre local → VALIDÉ | ", filterReason);
      }

      // Vérifier que la confiance IA est >= seuil configuré (70% par défaut)
      if(g_lastAIConfidence >= AI_MinConfidence)
      {
         if(StringFind(g_lastAIAction, "buy") >= 0)
         {
            shouldTrade = true;
            tradeType = ORDER_TYPE_BUY;
            Print("🎯 Signal IA HAUTE CONFIANCE (", DoubleToString(g_lastAIConfidence * 100, 1), "% >= ", DoubleToString(AI_MinConfidence * 100, 1), "%): ACHAT");
         }
         else if(StringFind(g_lastAIAction, "sell") >= 0)
         {
            shouldTrade = true;
            tradeType = ORDER_TYPE_SELL;
            Print("🎯 Signal IA HAUTE CONFIANCE (", DoubleToString(g_lastAIConfidence * 100, 1), "% >= ", DoubleToString(AI_MinConfidence * 100, 1), "%): VENTE");
         }
      }
      else
      {
         Print("❌ Signal IA rejeté - Confiance trop faible: ", DoubleToString(g_lastAIConfidence * 100, 1), "% < ", DoubleToString(AI_MinConfidence * 100, 1), "%");
      }
   }
   
   // Priorité 3: Signaux SMC forts (si aucun signal IA)
   if(!shouldTrade && HasStrongSMCSignal())
   {
      double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
      
      // Déterminer la direction basée sur les signaux SMC
      if(g_bullishStructure && g_fvgHigh > 0 && currentPrice > g_fvgLow)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_BUY;
         Print("📈 Signal SMC: ACHAT sur structure haussière + FVG");
      }
      else if(g_bearishStructure && g_fvgHigh > 0 && currentPrice < g_fvgHigh)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_SELL;
         Print("📉 Signal SMC: VENTE sur structure baissière + FVG");
      }
   }
   
   // Si aucun signal IA, utiliser fallback simple (UN SEUL CALCUL RSI)
   if(!shouldTrade && PositionsTotal() == 0)
   {
      double rsiValue = 50.0;
      if(rsi_H1 != INVALID_HANDLE)
      {
         double rsiBuf[1];
         if(CopyBuffer(rsi_H1, 0, 0, 1, rsiBuf) > 0) 
            rsiValue = rsiBuf[0];
      }
      
      // Logique très simple : RSI surachat/survente
      if(rsiValue < 30)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_BUY;
         Print("🎯 Fallback RSI: ACHAT (RSI=", DoubleToString(rsiValue, 1), ")");
      }
      else if(rsiValue > 70)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_SELL;
         Print("🎯 Fallback RSI: VENTE (RSI=", DoubleToString(rsiValue, 1), ")");
      }
   }

   if(!shouldTrade)
   {
      Print("❌ Aucun signal de trading valide détecté");
      return;
   }

   // Validation et exécution ultra-simple
   if(ValidateAdvancedEntry(tradeType))
   {
      Print("🚀 EXÉCUTION TRADE - Type: ", tradeType == ORDER_TYPE_BUY ? "BUY" : "SELL");
      
      // Sécurité de base pour Boom/Crash
      if(StringFind(_Symbol, "Boom") >= 0 && tradeType == ORDER_TYPE_SELL)
      {
         Print("🚨 SÉCURITÉ - SELL interdit sur Boom");
         return;
      }
      
      if(StringFind(_Symbol, "Crash") >= 0 && tradeType == ORDER_TYPE_BUY)
      {
         Print("🚨 SÉCURITÉ - BUY interdit sur Crash");
         return;
      }
      
      // Exécution simple
      ExecuteAdvancedTrade(tradeType, ask, bid);
   }
}

//+------------------------------------------------------------------+
//| VÉRIFIER LES SIGNAUX SMC FORTS                                   |
//+------------------------------------------------------------------+
bool HasStrongSMCSignal()
{
   if(!UseSMCAnalysis) return false;
   
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   // Signal haussier fort : FVG haussier non comblé + structure haussière
   if(g_fvgHigh > 0 && g_fvgLow > 0 && g_fvgHigh > g_fvgLow && 
      currentPrice > g_fvgLow && currentPrice < g_fvgHigh &&
      g_bullishStructure)
   {
      Print("📈 Signal SMC haussier fort : FVG + structure haussière");
      return true;
   }
   
   // Signal baissier fort : FVG baissier non comblé + structure baissière
   if(g_fvgHigh > 0 && g_fvgLow > 0 && g_fvgHigh > g_fvgLow && 
      currentPrice < g_fvgHigh && currentPrice > g_fvgLow &&
      g_bearishStructure)
   {
      Print("📉 Signal SMC baissier fort : FVG + structure baissière");
      return true;
   }
   
   // Signal Order Block : prix près d'un Order Block
   if(g_orderBlockHigh > 0 && g_orderBlockLow > 0)
   {
      double orderBlockMid = (g_orderBlockHigh + g_orderBlockLow) / 2;
      double distance = MathAbs(currentPrice - orderBlockMid) / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(distance < 50) // Moins de 50 pips de l'Order Block
      {
         if(currentPrice > orderBlockMid)
         {
            Print("📦 Signal SMC : Réaction Order Block haussier");
            return true;
         }
         else
         {
            Print("📦 Signal SMC : Réaction Order Block baissier");
            return true;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| VALIDATION DES STOPS SPÉCIFIQUE BOOM/CRASH                      |
//+------------------------------------------------------------------+
bool ValidateStopLevels(double price, double sl, double tp, bool isBuy)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;

   double minDistance = MathMax(stopLevel, freezeLevel);

   if(StringFind(_Symbol, "Volatility") >= 0 || StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      // Pour les symboles Volatility/Boom/Crash, utiliser une distance minimum absolue
      double absoluteMinDistance = 2.0; // 2.0 points minimum
      if(StringFind(_Symbol, "Volatility") >= 0)
         absoluteMinDistance = 5.0; // 5.0 points pour Volatility
      
      minDistance = MathMax(minDistance, absoluteMinDistance);
      Print("🔧 SYMBOLE SPÉCIAL - Distance minimum ajustée à: ", absoluteMinDistance);
   }

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   price = NormalizeDouble(price, digits);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   if(isBuy)
   {
      if(sl >= price - minDistance)
      {
         sl = price - minDistance - point;
         sl = NormalizeDouble(sl, digits);
         Print("⚠️ Ajustement du SL pour BUY - Nouveau SL: ", sl, " (Distance: ", price - sl, ")");
      }

      if(tp > 0 && tp <= price + minDistance)
      {
         tp = price + minDistance + point;
         tp = NormalizeDouble(tp, digits);
         Print("⚠️ Ajustement du TP pour BUY - Nouveau TP: ", tp, " (Distance: ", tp - price, ")");
      }

      if(sl >= price)
      {
         Print("❌ SL (", sl, ") doit être inférieur au prix (", price, ")");
         return false;
      }

      if(tp > 0 && tp <= price)
      {
         Print("❌ TP (", tp, ") doit être supérieur au prix (", price, ")");
         return false;
      }
   }
   else // SELL
   {
      if(sl <= price + minDistance)
      {
         sl = price + minDistance + point;
         sl = NormalizeDouble(sl, digits);
         Print("⚠️ Ajustement du SL pour SELL - Nouveau SL: ", sl, " (Distance: ", sl - price, ")");
      }

      if(tp > 0 && tp >= price - minDistance)
      {
         tp = price - minDistance - point;
         tp = NormalizeDouble(tp, digits);
         Print("⚠️ Ajustement du TP pour SELL - Nouveau TP: ", tp, " (Distance: ", price - tp, ")");
      }

      if(sl <= price)
      {
         Print("❌ SL (", sl, ") doit être supérieur au prix (", price, ")");
         return false;
      }

      if(tp > 0 && tp >= price)
      {
         Print("❌ TP (", tp, ") doit être inférieur au prix (", price, ")");
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| VÉRIFICATION DES NIVEAUX DE STOP LOSS                           |
//+------------------------------------------------------------------+
bool CheckStopLoss(string symbol, ENUM_POSITION_TYPE type, double openPrice, double sl, double tp)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;

   double minDistance = MathMax(stopLevel, freezeLevel);

   if(StringFind(symbol, "Volatility") >= 0 || StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0 || StringFind(symbol, "Step") >= 0)
   {
      // Pour les symboles Volatility/Boom/Crash, utiliser une distance minimum absolue
      double absoluteMinDistance = 2.0; // 2.0 points minimum
      if(StringFind(symbol, "Volatility") >= 0)
         absoluteMinDistance = 5.0; // 5.0 points pour Volatility
      
      minDistance = MathMax(minDistance, absoluteMinDistance);
      Print("🔧 CHECK STOP LOSS - Distance minimum ajustée à: ", absoluteMinDistance, " pour ", symbol);
   }

   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double currentPrice = (type == POSITION_TYPE_BUY) ?
      SymbolInfoDouble(symbol, SYMBOL_BID) :
      SymbolInfoDouble(symbol, SYMBOL_ASK);

   openPrice = NormalizeDouble(openPrice, digits);
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   currentPrice = NormalizeDouble(currentPrice, digits);

   if(type == POSITION_TYPE_BUY)
   {
      // Désactivation temporaire des erreurs SL pour Volatility
      if(StringFind(_Symbol, "Volatility") >= 0)
      {
         Print("🔧 SYMBOLE VOLATILITY - Validation SL désactivée");
         return true; // Permettre le trade pour Volatility
      }
      
      if(sl >= currentPrice - minDistance)
      {
         Print("❌ SL trop proche du prix actuel pour BUY. Distance: ", currentPrice - sl, ", Minimum: ", minDistance);
         return false;
      }

      if(sl >= openPrice)
      {
         Print("❌ SL doit être inférieur au prix d'ouverture pour BUY. SL: ", sl, ", Open: ", openPrice);
         return false;
      }

      if(tp > 0 && tp <= currentPrice + minDistance)
      {
         Print("❌ TP trop proche du prix actuel pour BUY. Distance: ", tp - currentPrice, ", Minimum: ", minDistance);
         return false;
      }
   }
   else if(type == POSITION_TYPE_SELL)
   {
      // Désactivation temporaire des erreurs SL pour Volatility
      if(StringFind(_Symbol, "Volatility") >= 0)
      {
         Print("🔧 SYMBOLE VOLATILITY - Validation SL désactivée");
         return true; // Permettre le trade pour Volatility
      }
      
      if(sl <= currentPrice + minDistance)
      {
         Print("❌ SL trop proche du prix actuel pour SELL. Distance: ", sl - currentPrice, ", Minimum: ", minDistance);
         return false;
      }

      if(sl <= openPrice)
      {
         Print("❌ SL doit être supérieur au prix d'ouverture pour SELL. SL: ", sl, ", Open: ", openPrice);
         return false;
      }

      if(tp > 0 && tp >= currentPrice - minDistance)
      {
         Print("❌ TP trop proche du prix actuel pour SELL. Distance: ", currentPrice - tp, ", Minimum: ", minDistance);
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| GESTION DES POSITIONS BOOM/CRASH                                |
//+------------------------------------------------------------------+
void ManageBoomCrashPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol) continue;

      bool isBoom = (StringFind(symbol, "Boom") >= 0);
      bool isCrash = (StringFind(symbol, "Crash") >= 0);

      if(!isBoom && !isCrash) continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      double totalProfit = profit + swap;
      
      // Initialiser le suivi du gain maximum pour cette position
      bool foundTicket = false;
      for(int j = 0; j < maxProfitCount; j++)
      {
         if(maxProfitTickets[j] == ticket)
         {
            foundTicket = true;
            if(totalProfit > maxProfitValues[j])
               maxProfitValues[j] = totalProfit; // Mettre à jour le gain maximum
            break;
         }
      }
      
      if(!foundTicket && maxProfitCount < MAX_POSITIONS_TRACKED)
      {
         maxProfitTickets[maxProfitCount] = ticket;
         maxProfitValues[maxProfitCount] = totalProfit;
         maxProfitCount++;
      }
      
      // Trouver le gain maximum pour cette position
      double maxGain = 0.0;
      for(int j = 0; j < maxProfitCount; j++)
      {
         if(maxProfitTickets[j] == ticket)
         {
            maxGain = maxProfitValues[j];
            break;
         }
      }
      
      // Fermeture automatique si profit minimum atteint (0.50$ par défaut)
      if(totalProfit >= 0.50)
      {
         if(trade.PositionClose(ticket))
         {
            Print("🚀 FERMETURE BOOM/CRASH - Profit: ", DoubleToString(totalProfit, 2), "$ >= 0.50$");
            SendNotification("GoldRush: Position Boom/Crash fermée - Profit réalisé");
            
            // Nettoyer le suivi du gain maximum
            for(int j = 0; j < maxProfitCount; j++)
            {
               if(maxProfitTickets[j] == ticket)
               {
                  maxProfitTickets[j] = maxProfitTickets[maxProfitCount-1];
                  maxProfitValues[j] = maxProfitValues[maxProfitCount-1];
                  maxProfitCount--;
                  break;
               }
            }
            return;
         }
      }

      // Trailing stop spécial Boom/Crash - s'active à 0.5$ et protège 50% du gain max
      if(UseTrailingForProfit && totalProfit >= 0.50) // S'active seulement à 0.5$ de gain
      {
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

         // Calcul du profit en pips
         double profitPips = 0.0;
         if(posType == POSITION_TYPE_BUY)
            profitPips = (currentPrice - openPrice) / point;
         else
            profitPips = (openPrice - currentPrice) / point;

         // Calculer le stop loss pour protéger 50% du gain maximum
         double protectedProfit = maxGain * 0.50; // Protéger 50% du gain max
         
         if(posType == POSITION_TYPE_BUY)
         {
            // Calculer le SL pour garantir au moins 50% du gain maximum
            double maxLossAllowed = maxGain * 0.50; // Perdre maximum 50% du gain max
            double newSL = currentPrice - (maxLossAllowed / point);
            
            // Breakeven rapide après 15 pips de profit
            if(profitPips >= 15.0)
               newSL = MathMax(newSL, openPrice + (2.0 * point));
            
            // S'assurer que le SL protège au moins 50% du gain maximum
            double projectedProfitAtSL = (newSL - openPrice) / point;
            if(projectedProfitAtSL * point >= protectedProfit && newSL > sl && newSL > openPrice)
            {
               if(trade.PositionModify(ticket, newSL, tp))
               {
                  Print("🔄 GoldRush Trailing PROTECTION BUY - SL: ", DoubleToString(newSL, _Digits), 
                        " | Profit actuel: ", DoubleToString(totalProfit, 2), "$",
                        " | Gain max: ", DoubleToString(maxGain, 2), "$",
                        " | Protégé: ", DoubleToString(protectedProfit, 2), "$ (50%)");
               }
            }
         }
         else // POSITION_TYPE_SELL
         {
            // Calculer le SL pour garantir au moins 50% du gain maximum
            double maxLossAllowed = maxGain * 0.50; // Perdre maximum 50% du gain max
            double newSL = currentPrice + (maxLossAllowed / point);
            
            // Breakeven rapide après 15 pips de profit
            if(profitPips >= 15.0)
               newSL = MathMin(newSL, openPrice - (2.0 * point));
            
            // S'assurer que le SL protège au moins 50% du gain maximum
            double projectedProfitAtSL = (openPrice - newSL) / point;
            if(projectedProfitAtSL * point >= protectedProfit && (sl == 0 || newSL < sl) && newSL < openPrice)
            {
               if(trade.PositionModify(ticket, newSL, tp))
               {
                  Print("🔄 GoldRush Trailing PROTECTION SELL - SL: ", DoubleToString(newSL, _Digits),
                        " | Profit actuel: ", DoubleToString(totalProfit, 2), "$",
                        " | Gain max: ", DoubleToString(maxGain, 2), "$",
                        " | Protégé: ", DoubleToString(protectedProfit, 2), "$ (50%)");
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| GESTION AVANCÉE DES POSITIONS (VERSION OPTIMISÉE)               |
//+------------------------------------------------------------------+
void ManagePositionsAdvanced()
{
   // Limiter l'exécution à toutes les 10 secondes pour réduire la charge CPU
   static datetime lastExecution = 0;
   if(TimeCurrent() - lastExecution < 10)
      return;
   lastExecution = TimeCurrent();
   
   // --- GESTION DES PERTES TOTALES ---
   double totalProfit = 0.0;
   int totalPositions = 0;
   int losingPositions = 0;
   
   // Limiter l'analyse aux 10 premières positions pour performance
   int maxPositionsToCheck = MathMin(PositionsTotal(), 10);
   
   for(int i = 0; i < maxPositionsToCheck; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      double positionTotal = profit + swap;
      
      totalProfit += positionTotal;
      totalPositions++;
      
      if(positionTotal < 0)
         losingPositions++;
   }
   
   // --- FERMETURE SI TOUTES LES POSITIONS SONT EN PERTE ---
   if(totalPositions > 0 && losingPositions == totalPositions && totalProfit < -10.0)
   {
      Print("⚠️ Toutes les positions sont en perte - Fermeture d'urgence");
      CloseAllPositions();
      return;
   }
   
   // --- DUPLICATION INTELLIGENTE (LIMITÉE) ---
   if(UseProfitDuplication && totalPositions > 0 && totalPositions < 5) // Limiter à 5 positions max
   {
      for(int i = 0; i < maxPositionsToCheck; i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;

         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
         
         string symbol = PositionGetString(POSITION_SYMBOL);
         if(symbol != _Symbol) continue;
         
         double profit = PositionGetDouble(POSITION_PROFIT);
         double swap = PositionGetDouble(POSITION_SWAP);
         double positionTotal = profit + swap;
         
         // Dupliquer si profit suffisant et pas encore dupliqué
         if(positionTotal >= ProfitThresholdForDuplicate && !hasDuplicated)
         {
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double volume = PositionGetDouble(POSITION_VOLUME);
            
            // Calculer le nouveau volume (plus petit pour sécurité)
            double newVolume = MathMin(DuplicationLotSize, volume * 0.5);
            newVolume = ValidateLotSize(newVolume);
            
            // Ouvrir une position dans la même direction
            if(posType == POSITION_TYPE_BUY)
            {
               double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
               double sl = ask - (InpStopLoss * SymbolInfoDouble(symbol, SYMBOL_POINT));
               double tp = ask + (InpTakeProfit * SymbolInfoDouble(symbol, SYMBOL_POINT));
               
               if(trade.Buy(newVolume, symbol, ask, sl, tp, "Duplication position BUY"))
               {
                  hasDuplicated = true;
                  duplicatedPositionTicket = trade.ResultOrder();
                  Print("🔄 Position dupliquée: BUY ", newVolume, " lots à ", ask);
                  SendNotification("GoldRush: Position dupliquée avec succès");
               }
            }
            else // SELL
            {
               double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
               double sl = bid + (InpStopLoss * SymbolInfoDouble(symbol, SYMBOL_POINT));
               double tp = bid - (InpTakeProfit * SymbolInfoDouble(symbol, SYMBOL_POINT));
               
               if(trade.Sell(newVolume, symbol, bid, sl, tp, "Duplication position SELL"))
               {
                  hasDuplicated = true;
                  duplicatedPositionTicket = trade.ResultOrder();
                  Print("🔄 Position dupliquée: SELL ", newVolume, " lots à ", bid);
                  SendNotification("GoldRush: Position dupliquée avec succès");
               }
            }
            break; // Sortir après une duplication
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ANALYSE SMC - SMART MONEY CONCEPTS                             |
//+------------------------------------------------------------------+
void AnalyzeSMC()
{
   if(!UseSMCAnalysis) return;
   
   // Mettre à jour les plus hauts et plus bas récents
   UpdateMarketStructure();
   
   // Détecter les zones de liquidité
   DetectLiquidityZones();
   
   // Détecter les Order Blocks
   DetectOrderBlocks();
   
   // Détecter les Fair Value Gaps
   DetectFVGs();
   
   // Analyser la stratégie Greedy Monkeys
   AnalyzeGreedyMonkeys();
   
   // Dessiner les éléments sur le graphique
   DrawSMCElements();
}

//+------------------------------------------------------------------+
//| METTRE À JOUR LA STRUCTURE DE MARCHÉ                             |
//+------------------------------------------------------------------+
void UpdateMarketStructure()
{
   if(!ShowMarketStructure) return;
   
   int lookback = 50; // Analyser les 50 dernières bougies
   
   for(int i = 1; i <= lookback; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      datetime time = iTime(_Symbol, PERIOD_CURRENT, i);
      
      // Mettre à jour les plus hauts et plus bas
      if(high > g_highestHigh)
      {
         g_highestHigh = high;
         g_highestHighTime = time;
      }
      
      if(low < g_lowestLow)
      {
         g_lowestLow = low;
         g_lowestLowTime = time;
      }
   }
   
   // Déterminer la structure du marché
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   // Structure haussière : plus hauts et plus bas qui montent
   if(currentPrice > g_highestHigh * 0.98) // Proche du plus haut
   {
      g_bullishStructure = true;
      g_bearishStructure = false;
   }
   // Structure baissière : plus bas et plus hauts qui baissent  
   else if(currentPrice < g_lowestLow * 1.02) // Proche du plus bas
   {
      g_bearishStructure = true;
      g_bullishStructure = false;
   }
}

//+------------------------------------------------------------------+
//| DÉTECTER LES ZONES DE LIQUIDITÉ                                 |
//+------------------------------------------------------------------+
void DetectLiquidityZones()
{
   if(!ShowLiquidityZones) return;
   
   int lookback = 100;
   
   // Chercher les zones de concentration d'ordres
   for(int i = 1; i <= lookback; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      double volume = (double)iVolume(_Symbol, PERIOD_CURRENT, i);
      
      // Zone de liquidité supérieure (plus hauts avec volume élevé)
      if(high > g_liquidityHigh && volume > (double)(5000 * LiquiditySensitivity))
      {
         g_liquidityHigh = high;
      }
      
      // Zone de liquidité inférieure (plus bas avec volume élevé)
      if(low < g_liquidityLow && low > 0 && volume > (double)(5000 * LiquiditySensitivity))
      {
         g_liquidityLow = low;
      }
   }
   
   // Vérifier si la liquidité a été sweepée
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   if(currentPrice > g_liquidityHigh && !g_liquiditySwept)
   {
      g_liquiditySwept = true;
      g_lastSweepTime = TimeCurrent();
      Print("🔄 SWEEP DE LIQUIDITÉ SUPÉRIEURE détecté à : ", DoubleToString(g_liquidityHigh, _Digits));
   }
   else if(currentPrice < g_liquidityLow && !g_liquiditySwept)
   {
      g_liquiditySwept = true;
      g_lastSweepTime = TimeCurrent();
      Print("🔄 SWEEP DE LIQUIDITÉ INFÉRIEURE détecté à : ", DoubleToString(g_liquidityLow, _Digits));
   }
}

//+------------------------------------------------------------------+
//| DÉTECTER LES ORDER BLOCKS SMC                                   |
//+------------------------------------------------------------------+
void DetectOrderBlocks()
{
   if(!ShowOrderBlocks) return;
   
   int lookback = OrderBlockLookback;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = 1; i <= lookback; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      double close = iClose(_Symbol, PERIOD_CURRENT, i);
      double open = iOpen(_Symbol, PERIOD_CURRENT, i);
      datetime time = iTime(_Symbol, PERIOD_CURRENT, i);
      
      // Order Block baissier (fort mouvement baissier)
      if(close < open * (1 - 0.003 * LiquiditySensitivity) && // Bougie baissière forte
         (high - low) > 20 * point) // Range suffisante
      {
         g_orderBlockHigh = high;
         g_orderBlockLow = low;
         g_orderBlockTime = time;
         Print("📦 Order Block baissier détecté à : ", DoubleToString(high, _Digits));
      }
      
      // Order Block haussier (fort mouvement haussier)
      if(close > open * (1 + 0.003 * LiquiditySensitivity) && // Bougie haussière forte
         (high - low) > 20 * point) // Range suffisante
      {
         g_orderBlockHigh = high;
         g_orderBlockLow = low;
         g_orderBlockTime = time;
         Print("📦 Order Block haussier détecté à : ", DoubleToString(low, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| DÉTECTER LES FAIR VALUE GAPS (FVG)                              |
//+------------------------------------------------------------------+
void DetectFVGs()
{
   if(!ShowFVGs) return;
   
   int lookback = 50;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = 2; i <= lookback; i++)
   {
      double high1 = iHigh(_Symbol, PERIOD_CURRENT, i-1);
      double low1 = iLow(_Symbol, PERIOD_CURRENT, i-1);
      double high2 = iHigh(_Symbol, PERIOD_CURRENT, i);
      double low2 = iLow(_Symbol, PERIOD_CURRENT, i);
      
      // FVG haussier : le plus bas de la bougie 2 est supérieur au plus haut de la bougie 1
      if(low2 > high1 && (low2 - high1) > FVGMinPips * point)
      {
         g_fvgLow = high1;
         g_fvgHigh = low2;
         g_fvgTime = iTime(_Symbol, PERIOD_CURRENT, i);
         Print("⬆️ FVG haussier détecté : ", DoubleToString(g_fvgLow, _Digits), " - ", DoubleToString(g_fvgHigh, _Digits));
      }
      
      // FVG baissier : le plus haut de la bougie 2 est inférieur au plus bas de la bougie 1
      if(high2 < low1 && (low1 - high2) > FVGMinPips * point)
      {
         g_fvgLow = high2;
         g_fvgHigh = low1;
         g_fvgTime = iTime(_Symbol, PERIOD_CURRENT, i);
         Print("⬇️ FVG baissier détecté : ", DoubleToString(g_fvgLow, _Digits), " - ", DoubleToString(g_fvgHigh, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| ANALYSER LA STRATÉGIE GREEDY MONKEYS                            |
//+------------------------------------------------------------------+
void AnalyzeGreedyMonkeys()
{
   if(!UseGreedyMonkeysStrategy) return;
   
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   // Stratégie Greedy Monkeys : acheter après un sweep de liquidité inférieure
   if(g_liquiditySwept && (TimeCurrent() - g_lastSweepTime) < 3600) // Dans l'heure du sweep
   {
      if(currentPrice > g_liquidityLow * 1.001) // Prix rebondit au-dessus de la liquidité
      {
         g_greedyMonkeysActive = true;
         Print("🐵 Greedy Monkeys ACTIF - ACHAT après sweep de liquidité");
      }
   }
   
   // Vendre après un sweep de liquidité supérieure
   if(g_liquiditySwept && (TimeCurrent() - g_lastSweepTime) < 3600)
   {
      if(currentPrice < g_liquidityHigh * 0.999) // Prix rebondit en dessous de la liquidité
      {
         g_greedyMonkeysActive = true;
         Print("🐵 Greedy Monkeys ACTIF - VENTE après sweep de liquidité");
      }
   }
}

//+------------------------------------------------------------------+
//| DESSINER LES ÉLÉMENTS SMC SUR LE GRAPHIQUE                       |
//+------------------------------------------------------------------+
void DrawSMCElements()
{
   // Nettoyer les anciens objets SMC
   ObjectsDeleteAll(0, "SMC_");
   
   if(!UseSMCAnalysis) return;
   
   // Dessiner les zones de liquidité
   if(ShowLiquidityZones && g_liquidityHigh > 0)
   {
      DrawRectangle("LIQUID_HIGH", g_liquidityHigh, g_highestHighTime, 
                   g_liquidityHigh + (20 * SymbolInfoDouble(_Symbol, SYMBOL_POINT)), 
                   TimeCurrent(), clrRed, STYLE_SOLID, 1, true);
   }
   
   if(ShowLiquidityZones && g_liquidityLow > 0 && g_liquidityLow < 999999)
   {
      DrawRectangle("LIQUID_LOW", g_liquidityLow, g_lowestLowTime,
                   g_liquidityLow - (20 * SymbolInfoDouble(_Symbol, SYMBOL_POINT)),
                   TimeCurrent(), clrBlue, STYLE_SOLID, 1, true);
   }
   
   // Dessiner les Order Blocks
   if(ShowOrderBlocks && g_orderBlockTime > 0)
   {
      DrawRectangle("ORDER_BLOCK", g_orderBlockLow, g_orderBlockTime,
                   g_orderBlockHigh, g_orderBlockTime + 3600, clrOrange, STYLE_SOLID, 2, false);
   }
   
   // Dessiner les FVGs
   if(ShowFVGs && g_fvgTime > 0)
   {
      DrawRectangle("FVG", g_fvgLow, g_fvgTime, g_fvgHigh, g_fvgTime + 3600, 
                   clrYellow, STYLE_SOLID, 1, true);
   }
   
   // Afficher la structure du marché
   if(ShowMarketStructure)
   {
      string structureText = "";
      color structureColor = clrGray;
      
      if(g_bullishStructure)
      {
         structureText = "📈 STRUCTURE HAUSSIÈRE";
         structureColor = clrGreen;
      }
      else if(g_bearishStructure)
      {
         structureText = "📉 STRUCTURE BAISSIÈRE";
         structureColor = clrRed;
      }
      
      if(structureText != "")
      {
         CreateLabel("STRUCTURE", structureText, 20, 300, structureColor, 10, true);
      }
   }
   
   // Afficher l'état Greedy Monkeys
   if(UseGreedyMonkeysStrategy && g_greedyMonkeysActive)
   {
      CreateLabel("GREEDY_MONKEYS", "🐵 GREEDY MONKEYS ACTIF", 20, 320, clrPurple, 10, true);
   }
}

//+------------------------------------------------------------------+
//| DESSINER UN RECTANGLE                                            |
//+------------------------------------------------------------------+
void DrawRectangle(string name, double price1, datetime time1, double price2, datetime time2, 
                  color clr, ENUM_LINE_STYLE style = STYLE_SOLID, int width = 1, bool back = true)
{
   string fullName = "SMC_" + name;
   if(ObjectFind(0, fullName) >= 0)
      ObjectDelete(0, fullName);
   
   ObjectCreate(0, fullName, OBJ_RECTANGLE, 0, time1, price1, time2, price2);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, fullName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, fullName, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, fullName, OBJPROP_BACK, back);
   ObjectSetInteger(0, fullName, OBJPROP_FILL, true);
   ObjectSetInteger(0, fullName, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, fullName, OBJPROP_BORDER_COLOR, clr);
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| TRAILING STOP AMÉLIORÉ AVEC VALIDATION ET LIMITE DE PERTE      |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(!PositionSelectByTicket(ticket))
      {
         Print("Erreur sélection position ", ticket, ". Code d'erreur: ", GetLastError());
         continue;
      }

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      long posType = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double volume = PositionGetDouble(POSITION_VOLUME);

      MqlTick last_tick;
      if(!SymbolInfoTick(symbol, last_tick))
      {
         Print("Erreur récupération du dernier tick pour ", symbol, ". Code d'erreur: ", GetLastError());
         continue;
      }

      double bid = last_tick.bid;
      double ask = last_tick.ask;
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

      double stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
      double freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;

      stopLevel = MathMax(stopLevel, SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point);
      freezeLevel = MathMax(freezeLevel, SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point);

      double trailDist = InpTrailDist * point;
      double trailStart = 0;
      double trailStep = 0;

      bool isSpecialSymbol = (StringFind(symbol, "Boom") >= 0 ||
                            StringFind(symbol, "Crash") >= 0 ||
                            StringFind(symbol, "Step") >= 0);

      if(isSpecialSymbol)
      {
         trailDist = BoomCrashTrailDistPips * point;
         trailStart = BoomCrashTrailStartPips * point;
         trailStep = BoomCrashTrailStepPips * point;
      }

      trailDist = MathMax(trailDist, stopLevel * 1.5);

      if(posType == POSITION_TYPE_BUY)
      {
         double profit = bid - open;

         if(profit >= trailStart || trailStart == 0)
         {
            double newSL = bid - trailDist;

            if(trailStep > 0)
            {
               double steps = MathFloor(profit / trailStep);
               newSL = open + (steps * trailStep) - trailDist;
            }

            if(newSL > (currentSL == 0 ? -DBL_MAX : currentSL) + stopLevel)
            {
               double minSL = bid - (stopLevel * 2);
               newSL = MathMax(newSL, minSL);
               newSL = MathMax(newSL, open);
               // Ne jamais proposer un SL au-dessus du prix (invalide pour BUY) — évite "SL trop proche" sur symboles MT5
               newSL = MathMin(newSL, bid - stopLevel);
               double distance = bid - newSL;
               if(distance < stopLevel)
                  continue; // SL invalide, passer sans spam

               // Désactivation temporaire des erreurs SL pour Volatility
               if(StringFind(_Symbol, "Volatility") >= 0)
               {
                  newSL = NormalizeDouble(newSL, digits);
                  if(CheckStopLoss(symbol, (ENUM_POSITION_TYPE)posType, open, newSL, currentTP))
                  {
                     trade.SetExpertMagicNumber(InpMagicNum);
                     trade.PositionModify(ticket, newSL, currentTP);
                  }
                  continue;
               }

               newSL = NormalizeDouble(newSL, digits);

               if(CheckStopLoss(symbol, (ENUM_POSITION_TYPE)posType, open, newSL, currentTP))
               {
                  trade.SetExpertMagicNumber(InpMagicNum);

                  if(!trade.PositionModify(ticket, newSL, currentTP))
                  {
                     Print("Erreur modification SL BUY ", symbol, ". Erreur: ", trade.ResultRetcode(),
                           ". SL: ", newSL, " (actuel: ", currentSL, "), TP: ", currentTP);
                  }
                  else
                  {
                     Print("SL BUY mis à jour pour ", symbol, ". Nouveau SL: ", newSL, ", TP: ", currentTP);
                  }
               }
            }
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         double profit = open - ask;

         if(profit >= trailStart || trailStart == 0)
         {
            double newSL = ask + trailDist;

            if(trailStep > 0)
            {
               double steps = MathFloor(profit / trailStep);
               newSL = open - (steps * trailStep) + trailDist;
            }

            if(newSL < (currentSL == 0 ? DBL_MAX : currentSL) - stopLevel || currentSL == 0)
            {
               double maxSL = ask + (stopLevel * 2);
               newSL = MathMin(newSL, maxSL);
               newSL = MathMin(newSL, open);
               // Ne jamais proposer un SL en dessous du prix (invalide pour SELL) — évite "SL trop proche" sur symboles MT5
               newSL = MathMax(newSL, ask + stopLevel);
               double distance = newSL - ask;
               if(distance < stopLevel)
                  continue; // SL invalide, passer sans spam

               // Désactivation temporaire des erreurs SL pour Volatility
               if(StringFind(_Symbol, "Volatility") >= 0)
               {
                  newSL = NormalizeDouble(newSL, digits);
                  if(CheckStopLoss(symbol, (ENUM_POSITION_TYPE)posType, open, newSL, currentTP))
                  {
                     trade.SetExpertMagicNumber(InpMagicNum);
                     trade.PositionModify(ticket, newSL, currentTP);
                  }
                  continue;
               }

               newSL = NormalizeDouble(newSL, digits);

               if(CheckStopLoss(symbol, (ENUM_POSITION_TYPE)posType, open, newSL, currentTP))
               {
                  trade.SetExpertMagicNumber(InpMagicNum);

                  if(!trade.PositionModify(ticket, newSL, currentTP))
                  {
                     Print("Erreur modification SL SELL ", symbol, ". Erreur: ", trade.ResultRetcode(),
                           ". SL: ", newSL, " (actuel: ", currentSL, "), TP: ", currentTP);
                  }
                  else
                  {
                     Print("SL SELL mis à jour pour ", symbol, ". Nouveau SL: ", newSL, ", TP: ", currentTP);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| SYSTÈME INTELLIGENT - Helpers (breakeven / partial close)       |
//+------------------------------------------------------------------+
bool IsTicketPartialClosed(ulong ticket)
{
   for(int i = 0; i < g_nPartialClosedTickets; i++)
      if(g_partialClosedTickets[i] == ticket) return true;
   return false;
}
void MarkTicketPartialClosed(ulong ticket)
{
   if(g_nPartialClosedTickets >= MAX_TRACKED_TICKETS) return;
   g_partialClosedTickets[g_nPartialClosedTickets++] = ticket;
}
bool IsBreakevenSet(ulong ticket)
{
   for(int i = 0; i < g_nBreakevenSetTickets; i++)
      if(g_breakevenSetTickets[i] == ticket) return true;
   return false;
}
void MarkBreakevenSet(ulong ticket)
{
   if(g_nBreakevenSetTickets >= MAX_TRACKED_TICKETS) return;
   g_breakevenSetTickets[g_nBreakevenSetTickets++] = ticket;
}
void RemoveClosedTicketFromTracking(ulong ticket)
{
   for(int i = 0; i < g_nPartialClosedTickets; i++)
   {
      if(g_partialClosedTickets[i] == ticket)
      {
         for(int j = i; j < g_nPartialClosedTickets - 1; j++)
            g_partialClosedTickets[j] = g_partialClosedTickets[j+1];
         g_nPartialClosedTickets--;
         return;
      }
   }
   for(int i = 0; i < g_nBreakevenSetTickets; i++)
   {
      if(g_breakevenSetTickets[i] == ticket)
      {
         for(int j = i; j < g_nBreakevenSetTickets - 1; j++)
            g_breakevenSetTickets[j] = g_breakevenSetTickets[j+1];
         g_nBreakevenSetTickets--;
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| GESTION INTELLIGENTE: Breakeven + Prise partielle + Trailing sécurisé |
//+------------------------------------------------------------------+
void ManageIntelligentStops()
{
   if(!UseSmartBreakeven && !UsePartialTakeProfit && !UseSecureProfitTrail && !UseATRTrailing)
      return;

   // Nettoyer les tickets déjà fermés des listes de suivi
   for(int k = g_nPartialClosedTickets - 1; k >= 0; k--)
   {
      if(!PositionSelectByTicket(g_partialClosedTickets[k]))
      {
         for(int j = k; j < g_nPartialClosedTickets - 1; j++)
            g_partialClosedTickets[j] = g_partialClosedTickets[j+1];
         g_nPartialClosedTickets--;
      }
   }
   for(int k = g_nBreakevenSetTickets - 1; k >= 0; k--)
   {
      if(!PositionSelectByTicket(g_breakevenSetTickets[k]))
      {
         for(int j = k; j < g_nBreakevenSetTickets - 1; j++)
            g_breakevenSetTickets[j] = g_breakevenSetTickets[j+1];
         g_nBreakevenSetTickets--;
      }
   }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   double minDist = MathMax(stopLevel, freezeLevel);
   bool isSpecial = (StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0 || StringFind(_Symbol, "Volatility") >= 0);
   if(isSpecial)
      minDist = MathMax(minDist, 2.0 * point);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double volume = PositionGetDouble(POSITION_VOLUME);
      double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentPrice = (posType == POSITION_TYPE_BUY) ? bid : ask;
      double profitPips = 0.0;
      if(posType == POSITION_TYPE_BUY)
         profitPips = (bid - openPrice) / point;
      else
         profitPips = (openPrice - ask) / point;

      // --- 1) Breakeven ---
      if(UseSmartBreakeven && !IsBreakevenSet(ticket) && profitPips >= BreakevenTriggerPips)
      {
         double newSL = 0.0;
         if(posType == POSITION_TYPE_BUY)
         {
            newSL = openPrice + BreakevenBufferPips * point;
            newSL = NormalizeDouble(newSL, digits);
            if(newSL < bid - minDist && (currentSL == 0 || newSL > currentSL))
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
               {
                  MarkBreakevenSet(ticket);
                  Print("✅ [INTELLIGENT] Breakeven activé #", ticket, " SL=", newSL);
               }
            }
         }
         else
         {
            newSL = openPrice - BreakevenBufferPips * point;
            newSL = NormalizeDouble(newSL, digits);
            if(newSL > ask + minDist && (currentSL == 0 || newSL < currentSL))
            {
               if(trade.PositionModify(ticket, newSL, currentTP))
               {
                  MarkBreakevenSet(ticket);
                  Print("✅ [INTELLIGENT] Breakeven activé #", ticket, " SL=", newSL);
               }
            }
         }
      }

      // --- 2) Prise de profit partielle ---
      if(UsePartialTakeProfit && !IsTicketPartialClosed(ticket) && profitPips >= PartialCloseAtPips)
      {
         double closeVol = NormalizeDouble(volume * (PartialClosePercent / 100.0), 2);
         closeVol = MathFloor(closeVol / volumeStep) * volumeStep;
         if(closeVol >= minLot && closeVol < volume)
         {
            if(trade.PositionClosePartial(ticket, closeVol))
            {
               MarkTicketPartialClosed(ticket);
               Print("✅ [INTELLIGENT] Prise de profit partielle #", ticket, " ", DoubleToString(PartialClosePercent, 0), "% (", closeVol, " lots)");
            }
         }
      }

      // --- 3) Trailing sécurisé (une fois gain important) ---
      if(UseSecureProfitTrail && profitPips >= SecureProfitTriggerPips)
      {
         double newSL = 0.0;
         if(posType == POSITION_TYPE_BUY)
         {
            newSL = bid - SecureTrailPips * point;
            newSL = MathMax(newSL, openPrice);
            newSL = MathMin(newSL, bid - minDist); // jamais au-dessus du prix (symboles MT5)
            newSL = NormalizeDouble(newSL, digits);
            if(newSL > currentSL + minDist && newSL < bid - minDist)
            {
               if(CheckStopLoss(_Symbol, (ENUM_POSITION_TYPE)posType, openPrice, newSL, currentTP))
               {
                  trade.PositionModify(ticket, newSL, currentTP);
               }
            }
         }
         else
         {
            newSL = ask + SecureTrailPips * point;
            newSL = MathMin(newSL, openPrice);
            newSL = MathMax(newSL, ask + minDist); // jamais en dessous du prix (symboles MT5)
            newSL = NormalizeDouble(newSL, digits);
            if((currentSL == 0 || newSL < currentSL - minDist) && newSL > ask + minDist)
            {
               if(CheckStopLoss(_Symbol, (ENUM_POSITION_TYPE)posType, openPrice, newSL, currentTP))
               {
                  trade.PositionModify(ticket, newSL, currentTP);
               }
            }
         }
      }

      // --- 4) Trailing basé sur l'ATR (Continu) ---
      if(UseATRTrailing)
      {
         double atrBuffer[1];
         if(atr_H1 != INVALID_HANDLE && CopyBuffer(atr_H1, 0, 0, 1, atrBuffer) > 0)
         {
            double atrVal = atrBuffer[0];
            double trailDist = atrVal * ATRTrailMultiplier;
            double newSL = 0.0;

            if(posType == POSITION_TYPE_BUY)
            {
               newSL = bid - trailDist;
               newSL = NormalizeDouble(newSL, digits);
               
               // Le SL ne peut que monter
               if((currentSL == 0 || newSL > currentSL + minDist) && newSL < bid - minDist)
               {
                  if(trade.PositionModify(ticket, newSL, currentTP))
                  {
                     // Print("🔄 [ATR TRAIL] BUY SL mis à jour #", ticket, " SL=", newSL);
                  }
               }
            }
            else // SELL
            {
               newSL = ask + trailDist;
               newSL = NormalizeDouble(newSL, digits);
               
               // Le SL ne peut que descendre
               if((currentSL == 0 || newSL < currentSL - minDist) && newSL > ask + minDist)
               {
                  if(trade.PositionModify(ticket, newSL, currentTP))
                  {
                     // Print("🔄 [ATR TRAIL] SELL SL mis à jour #", ticket, " SL=", newSL);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| GESTION AVANCÉE DES PROFITS                                   |
//+------------------------------------------------------------------+
void ManageAdvancedProfits()
{
   if(TimeCurrent() - lastProfitCheck < 1)
      return;

   lastProfitCheck = TimeCurrent();

   static datetime lastDiagnostic = 0;
   if(TimeCurrent() - lastDiagnostic > 30)
   {
      lastDiagnostic = TimeCurrent();
      Print("📊 DIAGNOSTIC PROFITS - Total: ", DoubleToString(totalSymbolProfit, 2), "$ - Positions: ", PositionsTotal(), " - AutoClose: ", AutoCloseOnTarget ? "OUI" : "NON");
   }

   totalSymbolProfit = 0.0;
   double maxPositionProfit = 0.0;
   ulong mostProfitableTicket = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double profit = PositionGetDouble(POSITION_PROFIT);
      totalSymbolProfit += profit;

      if(TimeCurrent() - lastDiagnostic > 30)
      {
         Print("   Position #", ticket, " - Profit: ", DoubleToString(profit, 2), "$");
      }

      if(profit > maxPositionProfit)
      {
         maxPositionProfit = profit;
         mostProfitableTicket = ticket;
      }
   }

   if(AutoCloseOnTarget && totalSymbolProfit >= TotalProfitTarget)
   {
      Print("🚨 FERMETURE AUTOMATIQUE - Profit: ", DoubleToString(totalSymbolProfit, 2), "$ >= Target: ", TotalProfitTarget, "$");
      CloseAllPositionsForSymbol(_Symbol, "Profit target reached: " + DoubleToString(totalSymbolProfit, 2) + "$");
      return;
   }
   else if(totalSymbolProfit >= TotalProfitTarget)
   {
      Print("🎯 Objectif de profit atteint: ", DoubleToString(totalSymbolProfit, 2), "$ - Fermeture automatique désactivée");
   }

   // --- SYSTÈME DE SCALING INTELLIGENT (PYRAMIDAGE) ---
   if(MaxScalingPositions > 0 && maxPositionProfit >= ProfitThresholdForDuplicate)
   {
      // Compter les positions de scaling déjà ouvertes pour ce symbole
      int scalingCount = 0;
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNum && 
               PositionGetString(POSITION_SYMBOL) == _Symbol &&
               StringFind(PositionGetString(POSITION_COMMENT), "Scaling") >= 0)
            {
               scalingCount++;
            }
         }
      }

      if(scalingCount < MaxScalingPositions && HasStrongSignal())
      {
         if(PositionSelectByTicket(mostProfitableTicket))
         {
            long type = PositionGetInteger(POSITION_TYPE);
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            // Calculer le lot dégressif: InpLots * (Decay ^ (scalingCount + 1))
            double lotSize = InpLots * MathPow(ScalingLotDecay, scalingCount + 1);
            
            // S'assurer que le lot est au moins le minimum autorisé
            double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            lotSize = MathMax(lotSize, minLot);
            lotSize = NormalizeDouble(lotSize, 2);

            if(type == POSITION_TYPE_BUY)
            {
               double sl = bid - InpStopLoss * _Point;
               double tp = bid + InpTakeProfit * _Point;

               if(trade.Buy(lotSize, _Symbol, ask, sl, tp, "GoldRush Scaling #" + IntegerToString(scalingCount + 1)))
               {
                  Print("🚀 Scaling ACHAT #", scalingCount + 1, " - Lot: ", lotSize);
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               double sl = ask + InpStopLoss * _Point;
               double tp = ask - InpTakeProfit * _Point;

               if(trade.Sell(lotSize, _Symbol, bid, sl, tp, "GoldRush Scaling #" + IntegerToString(scalingCount + 1)))
               {
                  Print("🚀 Scaling VENTE #", scalingCount + 1, " - Lot: ", lotSize);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| FERMER TOUTES LES POSITIONS POUR UN SYMBOLE                |
//+------------------------------------------------------------------+
void CloseAllPositionsForSymbol(string symbol, string reason)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;

      if(ClosePositionWithFallback(ticket))
         Print("✅ Position fermée - Ticket: ", ticket, " - Raison: ", reason);
   }
}

//+------------------------------------------------------------------+
//| RÉINITIALISER LES VARIABLES DE PROFIT                        |
//+------------------------------------------------------------------+
void ResetProfitVariables()
{
   hasDuplicated = false;
   duplicatedPositionTicket = 0;
   totalSymbolProfit = 0.0;
}

//+------------------------------------------------------------------+
//| OBTENIR LE VOLUME CORRECT POUR LE SYMBOLE                  |
//+------------------------------------------------------------------+
double GetCorrectLotSize()
{
   static string lastLotSymbol = "";
   static datetime lastLotPrintTime = 0;
   bool doLog = (lastLotSymbol != _Symbol || TimeCurrent() - lastLotPrintTime >= 300);
   if(doLog) { lastLotSymbol = _Symbol; lastLotPrintTime = TimeCurrent(); }

   string symbol = _Symbol;
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   // Utiliser la taille ajustée si en mode protection
   double baseLot = UseSuccessiveGainsProtection ? GetAdjustedLotSize() : InpLots;

   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "Gold") >= 0 ||
      StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "Silver") >= 0 ||
      StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0 ||
      StringFind(symbol, "Volatility") >= 0)
   {
      double adjustedLot = MathRound(minLot / stepLot) * stepLot;
      adjustedLot = MathMax(adjustedLot, minLot);
      // Utiliser le lot de base ajusté si nécessaire
      adjustedLot = MathMax(adjustedLot, baseLot);
      if(doLog)
      {
         Print("📊 Symbole à risque: ", symbol, " | Lot min: ", minLot, " max: ", maxLot, " → ajusté: ", adjustedLot);
      }
      return adjustedLot;
   }

   if(StringFind(symbol, "USD") >= 0 || StringFind(symbol, "EUR") >= 0 ||
      StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "JPY") >= 0 ||
      StringFind(symbol, "AUD") >= 0 || StringFind(symbol, "CAD") >= 0 ||
      StringFind(symbol, "CHF") >= 0 || StringFind(symbol, "NZD") >= 0)
   {
      double adjustedLot = MathRound(minLot / stepLot) * stepLot;
      adjustedLot = MathMax(adjustedLot, minLot);
      // Utiliser le lot de base ajusté si nécessaire
      adjustedLot = MathMax(adjustedLot, baseLot);
      if(doLog) Print("📊 Forex: ", symbol, " → lot: ", adjustedLot);
      return adjustedLot;
   }

   double finalLot = MathMax(baseLot, minLot);
   finalLot = MathRound(finalLot / stepLot) * stepLot;
   finalLot = MathMin(finalLot, maxLot);
   if(doLog) Print("📊 Symbole standard: ", symbol, " → lot: ", finalLot);
   return finalLot;
}

//+------------------------------------------------------------------+
//| MISE À JOUR SIGNAL IA                                      |
//+------------------------------------------------------------------+
//| MISE À JOUR SIGNAL IA - VERSION AMÉLIORÉE                        |
//+------------------------------------------------------------------+
void UpdateAISignal()
{
   if(!UseAI_Agent) 
   {
      Print("ℹ️ IA désactivée - Mise à jour du signal ignorée");
      return;
   }

   // Vérifier la connexion Internet
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      Print("❌ Aucune connexion Internet - Impossible de contacter le serveur AI");
      return;
   }

   double ask = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits);
   double bid = NormalizeDouble(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits);

   // Récupération des indicateurs avec gestion d'erreur
   double rsiValue = 50.0;
   double atrValue = 0.0;
   double emaFast = 0.0;
   double emaSlow = 0.0;

   if(rsi_H1 != INVALID_HANDLE)
   {
      double rsiBuffer[1] = {0};
      if(CopyBuffer(rsi_H1, 0, 0, 1, rsiBuffer) > 0 && !MathIsValidNumber(rsiBuffer[0]))
         rsiValue = NormalizeDouble(rsiBuffer[0], 2);
   }

   if(atr_H1 != INVALID_HANDLE)
   {
      double atrBuffer[1] = {0};
      if(CopyBuffer(atr_H1, 0, 0, 1, atrBuffer) > 0 && !MathIsValidNumber(atrBuffer[0]))
         atrValue = NormalizeDouble(atrBuffer[0], _Digits);
   }

   // Construction du payload JSON
   string data = "{" +
                  "\"symbol\":\"" + _Symbol + "\"," +
                  "\"bid\":" + DoubleToString(bid, _Digits) + "," +
                  "\"ask\":" + DoubleToString(ask, _Digits) + "," +
                  "\"rsi\":" + DoubleToString(rsiValue, 2) + "," +
                  "\"atr\":" + DoubleToString(atrValue, _Digits) + "," +
                  "\"ema_fast\":" + DoubleToString(emaFast, _Digits) + "," +
                  "\"ema_slow\":" + DoubleToString(emaSlow, _Digits) + "," +
                  "\"is_spike_mode\":" + (spikeDetected ? "true" : "false") + "," +
                  "\"dir_rule\":0," +
                  "\"supertrend_trend\":0," +
                  "\"volatility_regime\":0," +
                  "\"volatility_ratio\":1.0" +
                  "}";

   Print("📦 Envoi des données au serveur AI...");
   Print("   📊 Données: ", data);

   uchar post_uchar[];
   StringToCharArray(data, post_uchar, 0, StringLen(data), CP_UTF8);

   uchar result[];
   string result_headers;
   string headers = "Content-Type: application/json\r\n" +
                    "User-Agent: MT5-TradBOT/3.0\r\n" +
                    "Accept: application/json\r\n" +
                    "Connection: keep-alive\r\n" +
                    "Accept-Encoding: gzip, deflate\r\n";

   int res = -1;
   string usedURL = "";
   bool requestSuccess = false;
   string response = "";

   // Essayer d'abord le serveur local si activé
   if(UseLocalFirst)
   {
      usedURL = AI_LocalServerURL;
      Print("🌐 Tentative de connexion au serveur local: ", usedURL);
      
      // Réduire le timeout pour le serveur local
      res = WebRequest("POST", usedURL, headers, 3000, post_uchar, result, result_headers);
      
      if(res == 200)
      {
         response = CharArrayToString(result);
         Print("✅ Réponse du serveur local reçue");
         requestSuccess = true;
      }
      else
      {
         Print("❌ Échec de la connexion au serveur local (Code: ", res, ")");
      }
   }

   // Si échec du serveur local ou non utilisé, essayer le serveur distant
   if(!requestSuccess)
   {
      usedURL = AI_ServerURL;
      Print("🌐 Tentative de connexion au serveur distant: ", usedURL);
      
      res = WebRequest("POST", usedURL, headers, AI_Timeout_ms, post_uchar, result, result_headers);
      
      if(res == 200)
      {
         response = CharArrayToString(result);
         Print("✅ Réponse du serveur distant reçue");
         requestSuccess = true;
      }
      else
      {
         Print("❌ Échec de la connexion au serveur distant (Code: ", res, ")");
         g_lastAIAction = "error";
         g_lastAIConfidence = 0.0;
         Print("⚠️ Aucun serveur AI disponible - Utilisation des signaux locaux uniquement");
         return;
      }
   }

   // Traitement de la réponse
   if(requestSuccess && res == 200)
   {
      // Vérifier que la réponse est un JSON valide
      int jsonStart = StringFind(response, "{");
      int jsonEnd = StringFind(response, "}", StringLen(response) - 1);
      
      if(jsonStart >= 0 && jsonEnd > jsonStart)
      {
         response = StringSubstr(response, jsonStart, jsonEnd - jsonStart + 1);
         
         // Extraire l'action et la confiance
         int actionPos = StringFind(response, "\"action\"");
         int confPos = StringFind(response, "\"confidence\"");
         
         if(actionPos > 0)
         {
            int startQuote = StringFind(response, "\"", actionPos + 9) + 1;
            int endQuote = StringFind(response, "\"", startQuote);
            
            if(startQuote > 0 && endQuote > startQuote)
            {
               g_lastAIAction = StringSubstr(response, startQuote, endQuote - startQuote);
               Print("📊 Action AI: ", g_lastAIAction);
            }
         }
         
         if(confPos > 0)
         {
            int colonPos = StringFind(response, ":", confPos);
            int commaPos = StringFind(response, ",", colonPos);
            if(commaPos == -1) commaPos = StringFind(response, "}", colonPos);
            
            if(colonPos > 0 && commaPos > colonPos)
            {
               string confStr = StringSubstr(response, colonPos + 1, commaPos - colonPos - 1);
               g_lastAIConfidence = StringToDouble(confStr);
               Print("📈 Confiance AI: ", DoubleToString(g_lastAIConfidence * 100, 1), "%");
            }
         }
         
         // Mettre à jour la source (pour le dashboard: LOCAL vs RENDER)
         lastAISource = (usedURL == AI_LocalServerURL) ? 0 : 1;
         string serverType = (usedURL == AI_LocalServerURL) ? "Local" : "Distant";
         Print("✅ Signal AI (", serverType, "): ", g_lastAIAction, 
               " (Confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
      }
      else
      {
         Print("❌ Réponse du serveur invalide: ", response);
         g_lastAIAction = "error";
         g_lastAIConfidence = 0.0;
      }
   }
   else
   {
      Print("❌ Erreur lors de la communication avec le serveur AI (Code: ", res, ")");
      g_lastAIAction = "error";
      g_lastAIConfidence = 0.0;
   }
}

//+------------------------------------------------------------------+
//| GÉNÉRER SIGNAL DE SECOURS (FALLBACK)                     |
//+------------------------------------------------------------------+
void GenerateFallbackSignal()
{
   double rsiValue = 50.0;
   double atrValue = 0.0;

   if(rsi_H1 != INVALID_HANDLE)
   {
      double rsiBuffer[1];
      if(CopyBuffer(rsi_H1, 0, 0, 1, rsiBuffer) > 0)
         rsiValue = rsiBuffer[0];
   }

   if(atr_H1 != INVALID_HANDLE)
   {
      double atrBuffer[1];
      if(CopyBuffer(atr_H1, 0, 0, 1, atrBuffer) > 0)
         atrValue = atrBuffer[0];
   }

   if(rsiValue < 30)
   {
      g_lastAIAction = "buy";
      g_lastAIConfidence = 0.65;
      Print("🔄 Signal de secours [FALLBACK]: BUY (RSI: ", DoubleToString(rsiValue, 2), " < 30)");
   }
   else if(rsiValue > 70)
   {
      g_lastAIAction = "sell";
      g_lastAIConfidence = 0.65;
      Print("🔄 Signal de secours [FALLBACK]: SELL (RSI: ", DoubleToString(rsiValue, 2), " > 70)");
   }
   else
   {
      g_lastAIAction = "hold";
      g_lastAIConfidence = 0.50;
      Print("🔄 Signal de secours [FALLBACK]: HOLD (RSI: ", DoubleToString(rsiValue, 2), " neutre)");
   }

   Print("   ⚠️ ModeFallback activé - Confiance réduite à ", g_lastAIConfidence);
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI LE SYMBOLE EST AUTORISÉ POUR LE TRADING       |
//+------------------------------------------------------------------+
bool IsSymbolAllowedForTrading()
{
   string symbol = _Symbol;

   bool isAllowed = (
      StringFind(symbol, "EUR") >= 0 || StringFind(symbol, "USD") >= 0 ||
      StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "JPY") >= 0 ||
      StringFind(symbol, "AUD") >= 0 || StringFind(symbol, "CAD") >= 0 ||
      StringFind(symbol, "CHF") >= 0 || StringFind(symbol, "NZD") >= 0 ||
      StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "Gold") >= 0 ||
      StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "Silver") >= 0 ||
      StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0 ||
      StringFind(symbol, "Step") >= 0 || StringFind(symbol, "Index") >= 0 ||
      StringFind(symbol, "Volatility") >= 0
   );

   if(isAllowed)
   {
      Print("✅ Symbole autorisé pour trading: ", symbol);
   }
   else
   {
      Print("❌ Symbole non autorisé pour trading: ", symbol);
   }

   return isAllowed;
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI SIGNAL FORT PRÉSENT                             |
//+------------------------------------------------------------------+
bool HasStrongSignal()
{
   if(!IsSymbolAllowedForTrading())
   {
      Print("❌ Trading non autorisé sur ce symbole: ", _Symbol);
      return false;
   }

   // --- SYSTÈME DE SCORE PONDÉRÉ ---
   double score = 0.0;
   
   // 1. Confiance de l'IA (Poids 40%) - EXIGER LE SEUIL CONFIGURÉ
   if(g_lastAIConfidence >= AI_MinConfidence) // Utiliser le paramètre configuré
   {
      score += 0.4 * g_lastAIConfidence;
   }
   else
   {
      // Refuser si confiance < seuil configuré
      Print("❌ Confiance IA insuffisante: ", DoubleToString(g_lastAIConfidence * 100, 1), "% < ", DoubleToString(AI_MinConfidence * 100, 1), "%");
      return false;
   }
   
   // 2. Alignement des EMA (Poids 30%)
   bool h1Bullish = emaFast_H1_val > emaSlow_H1_val;
   bool h1Bearish = emaFast_H1_val < emaSlow_H1_val;
   bool m5Bullish = emaFast_M5_val > emaSlow_M5_val;
   bool m5Bearish = emaFast_M5_val < emaSlow_M5_val;
   
   if(StringFind(g_lastAIAction, "buy") >= 0)
   {
      if(h1Bullish) score += 0.15;
      if(m5Bullish) score += 0.15;
   }
   else if(StringFind(g_lastAIAction, "sell") >= 0)
   {
      if(h1Bearish) score += 0.15;
      if(m5Bearish) score += 0.15;
   }
   
   // 3. RSI (Poids 30%)
   double rsiVal = 50.0;
   if(rsi_H1 != INVALID_HANDLE)
   {
      double rsiBuf[1];
      if(CopyBuffer(rsi_H1, 0, 0, 1, rsiBuf) > 0) rsiVal = rsiBuf[0];
   }
   
   if(StringFind(g_lastAIAction, "buy") >= 0 && rsiVal < 70) score += 0.3 * (1.0 - (rsiVal / 100.0));
   else if(StringFind(g_lastAIAction, "sell") >= 0 && rsiVal > 30) score += 0.3 * (rsiVal / 100.0);

   // Validation finale: Score minimum de 0.4 pour un signal fort
   bool isStrong = (score >= 0.4 && (StringFind(g_lastAIAction, "buy") >= 0 || StringFind(g_lastAIAction, "sell") >= 0));
   
   if(isStrong)
   {
      Print("🎯 SIGNAL FORT DÉTECTÉ - Score: ", DoubleToString(score, 2), " | Action: ", g_lastAIAction);
   }
   
   return isStrong;
}

//+------------------------------------------------------------------+
//| MISE À JOUR DÉTECTION DERIV ARROW                          |
//+------------------------------------------------------------------+
void UpdateDerivArrowDetection()
{
   if(TimeCurrent() - lastDerivArrowCheck < 5)
      return;

   lastDerivArrowCheck = TimeCurrent();

   derivArrowPresent = false;
   derivArrowType = 0;

   for(int i = 0; i < ObjectsTotal(0); i++)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "DERIV") >= 0 || StringFind(objName, "ARROW") >= 0)
      {
         long arrowCode = ObjectGetInteger(0, objName, OBJPROP_ARROWCODE);
         if(arrowCode == 241)
         {
            derivArrowPresent = true;
            derivArrowType = 1;
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
         }
         else if(arrowCode == 242)
         {
            derivArrowPresent = true;
            derivArrowType = 2;
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| MISE À JOUR DES DONNÉES MULTI-TIMEFRAMES                    |
//+------------------------------------------------------------------+
void UpdateMultiTimeframeData()
{
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 10)
      return;

   lastUpdate = TimeCurrent();

   if(UseMultiTimeframeEMA)
   {
      double fastBuffer[1], slowBuffer[1];

      if(emaFast_H1 != INVALID_HANDLE && emaSlow_H1 != INVALID_HANDLE)
      {
         if(CopyBuffer(emaFast_H1, 0, 0, 1, fastBuffer) > 0)
            emaFast_H1_val = fastBuffer[0];
         if(CopyBuffer(emaSlow_H1, 0, 0, 1, slowBuffer) > 0)
            emaSlow_H1_val = slowBuffer[0];
      }

      if(emaFast_M15 != INVALID_HANDLE && emaSlow_M15 != INVALID_HANDLE)
      {
         if(CopyBuffer(emaFast_M15, 0, 0, 1, fastBuffer) > 0)
            emaFast_M15_val = fastBuffer[0];
         if(CopyBuffer(emaSlow_M15, 0, 0, 1, slowBuffer) > 0)
            emaSlow_M15_val = slowBuffer[0];
      }

      if(emaFast_M5 != INVALID_HANDLE && emaSlow_M5 != INVALID_HANDLE)
      {
         if(CopyBuffer(emaFast_M5, 0, 0, 1, fastBuffer) > 0)
            emaFast_M5_val = fastBuffer[0];
         if(CopyBuffer(emaSlow_M5, 0, 0, 1, slowBuffer) > 0)
            emaSlow_M5_val = slowBuffer[0];
      }

      if(emaFast_M1 != INVALID_HANDLE && emaSlow_M1 != INVALID_HANDLE)
      {
         if(CopyBuffer(emaFast_M1, 0, 0, 1, fastBuffer) > 0)
            emaFast_M1_val = fastBuffer[0];
         if(CopyBuffer(emaSlow_M1, 0, 0, 1, slowBuffer) > 0)
            emaSlow_M1_val = slowBuffer[0];
      }
   }

   if(UseSupertrendIndicator)
   {
      double valueBuffer[1], dirBuffer[1];

      if(supertrend_H1 != INVALID_HANDLE)
      {
         if(CopyBuffer(supertrend_H1, 0, 0, 1, valueBuffer) > 0)
            supertrend_H1_val = valueBuffer[0];
         if(CopyBuffer(supertrend_H1, 1, 0, 1, dirBuffer) > 0)
            supertrend_H1_dir = dirBuffer[0];
      }

      if(supertrend_M15 != INVALID_HANDLE)
      {
         if(CopyBuffer(supertrend_M15, 0, 0, 1, valueBuffer) > 0)
            supertrend_M15_val = valueBuffer[0];
         if(CopyBuffer(supertrend_M15, 1, 0, 1, dirBuffer) > 0)
            supertrend_M15_dir = dirBuffer[0];
      }

      if(supertrend_M5 != INVALID_HANDLE)
      {
         if(CopyBuffer(supertrend_M5, 0, 0, 1, valueBuffer) > 0)
            supertrend_M5_val = valueBuffer[0];
         if(CopyBuffer(supertrend_M5, 1, 0, 1, dirBuffer) > 0)
            supertrend_M5_dir = dirBuffer[0];
      }

      if(supertrend_M1 != INVALID_HANDLE)
      {
         if(CopyBuffer(supertrend_M1, 0, 0, 1, valueBuffer) > 0)
            supertrend_M1_val = valueBuffer[0];
         if(CopyBuffer(supertrend_M1, 1, 0, 1, dirBuffer) > 0)
            supertrend_M1_dir = dirBuffer[0];
      }
   }

   if(UseSupportResistance)
      CalculateSupportResistance();
}

//+------------------------------------------------------------------+
//| CALCULER SUPPORT ET RÉSISTANCE                              |
//+------------------------------------------------------------------+
void CalculateSupportResistance()
{
   // Limiter la fréquence de mise à jour
   static datetime lastSRUpdate = 0;
   if(TimeCurrent() - lastSRUpdate < 1800) return; // Toutes les 30 minutes max
   lastSRUpdate = TimeCurrent();
   
   int lookback = MathMin(SR_LookbackBars, 40); // Limiter à 40 barres maximum
   double high_H1[], low_H1[];
   ArraySetAsSeries(high_H1, true);
   ArraySetAsSeries(low_H1, true);

   if(CopyHigh(_Symbol, PERIOD_H1, 0, lookback, high_H1) <= 0 ||
      CopyLow(_Symbol, PERIOD_H1, 0, lookback, low_H1) <= 0)
   {
      Print("❌ Erreur récupération données Support/Résistance");
      return;
   }
   
   // === MÉTHODE SIMPLIFIÉE ET OPTIMISÉE ===
   
   // Utiliser l'algorithme simple par défaut pour économiser CPU
   H1_Resistance = high_H1[ArrayMaximum(high_H1, 0, lookback)];
   H1_Support = low_H1[ArrayMinimum(low_H1, 0, lookback)];
   
   // Validation rapide: compter les touches seulement si nécessaire
   if(UseSupportResistance && StringFind(_Symbol, "Boom") < 0 && StringFind(_Symbol, "Crash") < 0)
   {
      int supportTouches = 0;
      int resistanceTouches = 0;
      double tolerance = 30 * _Point; // 30 pips de tolérance
      
      // Compter les touches (limité à 20 itérations pour performance)
      for(int i = 0; i < MathMin(20, lookback); i++)
      {
         if(MathAbs(low_H1[i] - H1_Support) < tolerance) supportTouches++;
         if(MathAbs(high_H1[i] - H1_Resistance) < tolerance) resistanceTouches++;
      }
      
      // Garder seulement les niveaux avec au moins 2 touches
      if(supportTouches < 2)
      {
         // Chercher le deuxième meilleur support
         double secondBest = low_H1[0];
         for(int i = 1; i < lookback; i++)
         {
            if(low_H1[i] > H1_Support && low_H1[i] < secondBest)
               secondBest = low_H1[i];
         }
         if(secondBest > H1_Support) H1_Support = secondBest;
      }
      
      if(resistanceTouches < 2)
      {
         // Chercher la deuxième meilleure résistance
         double secondBest = high_H1[0];
         for(int i = 1; i < lookback; i++)
         {
            if(high_H1[i] < H1_Resistance && high_H1[i] > secondBest)
               secondBest = high_H1[i];
         }
         if(secondBest < H1_Resistance) H1_Resistance = secondBest;
      }
   }

   // M5 - calcul simple sans validation complexe
   double high_M5[], low_M5[];
   ArraySetAsSeries(high_M5, true);
   ArraySetAsSeries(low_M5, true);
   int m5Lookback = MathMin(lookback, 30);

   if(CopyHigh(_Symbol, PERIOD_M5, 0, m5Lookback, high_M5) > 0 &&
      CopyLow(_Symbol, PERIOD_M5, 0, m5Lookback, low_M5) > 0)
   {
      M5_Resistance = high_M5[ArrayMaximum(high_M5, 0, m5Lookback)];
      M5_Support = low_M5[ArrayMinimum(low_M5, 0, m5Lookback)];
   }
   
   Print("🎯 S/R optimisés - H1: S=", DoubleToString(H1_Support, 5), 
         " R=", DoubleToString(H1_Resistance, 5), 
         " | M5: S=", DoubleToString(M5_Support, 5), 
         " R=", DoubleToString(M5_Resistance, 5));
}

//+------------------------------------------------------------------+
//| EXÉCUTION AVANCÉE DES TRADES                              |
//+------------------------------------------------------------------+
void ExecuteAdvancedTrade(ENUM_ORDER_TYPE orderType, double ask, double bid)
{
   double sl, tp;
   double point = _Point;
   double stopLossPips = InpStopLoss;
   double takeProfitPips = InpTakeProfit;

   if(StringFind(_Symbol, "Volatility") >= 0)
   {
      point = 0.01;
      stopLossPips = MathMax(stopLossPips, 200);
      takeProfitPips = MathMax(takeProfitPips, 300);
      Print("🔧 SYMBOLE VOLATILITY - Point ajusté à: ", point, " - SL: ", stopLossPips, " - TP: ", takeProfitPips);
   }

   if(UseDynamicSLTP)
   {
      double atrValue[1];
      if(CopyBuffer(atr_H1, 0, 0, 1, atrValue) > 0)
      {
         double atrMultiplier = 2.0;
         if(orderType == ORDER_TYPE_BUY)
         {
            sl = bid - atrValue[0] * atrMultiplier;
            tp = bid + atrValue[0] * atrMultiplier * 1.5;
         }
         else
         {
            sl = ask + atrValue[0] * atrMultiplier;
            tp = ask - atrValue[0] * atrMultiplier * 1.5;
         }
         stopLossPips = (orderType == ORDER_TYPE_BUY) ? (bid - sl) / point : (sl - ask) / point;
         takeProfitPips = (orderType == ORDER_TYPE_BUY) ? (tp - bid) / point : (ask - tp) / point;
         Print("📊 Stops dynamiques ATR - SL: ", sl, " - TP: ", tp);
      }
      else
      {
         if(orderType == ORDER_TYPE_BUY) { sl = bid - stopLossPips * point; tp = bid + takeProfitPips * point; }
         else { sl = ask + stopLossPips * point; tp = ask - takeProfitPips * point; }
         Print("📊 Stops fixes (fallback) - SL: ", sl, " - TP: ", tp);
      }
   }
   else
   {
      if(orderType == ORDER_TYPE_BUY) { sl = bid - stopLossPips * point; tp = bid + takeProfitPips * point; }
      else { sl = ask + stopLossPips * point; tp = ask - takeProfitPips * point; }
      Print("📊 Stops par défaut - SL: ", sl, " - TP: ", tp);
   }

   // Lot basé sur le risque (RiskPerTrade) et plafonné par MaxLossPerTradePercent
   double tradeRiskPercent = InpRiskPercentPerTrade;
   if(InpFixedRiskUSD > 0.0)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      tradeRiskPercent = (InpFixedRiskUSD / balance) * 100.0;
   }

   // On utilise déjà stopLossPips calculé précédemment
   double correctLotSize = CalculateRiskBasedLotSize(tradeRiskPercent, stopLossPips);

   // Sécurité ultime
   if(correctLotSize < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
   {
      Print("Lot trop petit → trade annulé");
      return;
   }

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxLossMoney = balance * (MaxLossPerTradePercent / 100.0);
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(MaxLossPerTradePercent > 0 && balance > 0 && tickSize > 0 && tickVal > 0)
   {
      double slDist = (orderType == ORDER_TYPE_BUY) ? (bid - sl) : (sl - ask);
      double lossPerLot = (slDist / tickSize) * tickVal;
      if(lossPerLot > 0)
      {
         double maxLotByLoss = MathFloor((maxLossMoney / lossPerLot) / SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)) * SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         maxLotByLoss = MathMax(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), maxLotByLoss));
         if(correctLotSize > maxLotByLoss)
         {
            correctLotSize = maxLotByLoss;
            Print("📊 [INTELLIGENT] Lot plafonné à ", correctLotSize, " (max perte ", DoubleToString(MaxLossPerTradePercent, 1), "%)");
         }
      }
   }
   correctLotSize = MathMax(correctLotSize, GetCorrectLotSize()); // au moins le minimum sécurisé pour le symbole

   double currentPrice = (orderType == ORDER_TYPE_BUY) ? ask : bid;
   Print("🔍 DIAGNOSTIC TRADE - Type: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL", " - Lot: ", correctLotSize, " - SL: ", sl, " - TP: ", tp);

   if(orderType == ORDER_TYPE_BUY)
   {
      if(trade.Buy(correctLotSize, _Symbol, ask, sl, tp, "GoldRush AI Buy"))
      {
         Print("✅ Trade ACHAT exécuté - Lot: ", correctLotSize, " - SL: ", sl, " TP: ", tp);
         Print("🔄 Trailing stop ACTIVÉ automatiquement pour cette position");
      }
      else
         Print("❌ Échec ACHAT - Erreur: ", trade.ResultRetcode());
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(trade.Sell(correctLotSize, _Symbol, bid, sl, tp, "GoldRush AI Sell"))
      {
         Print("✅ Trade VENTE exécuté - Lot: ", correctLotSize, " - SL: ", sl, " TP: ", tp);
         Print("🔄 Trailing stop ACTIVÉ automatiquement pour cette position");
      }
      else
         Print("❌ Échec VENTE - Erreur: ", trade.ResultRetcode());
   }
   
   // Forcer l'activation du trailing stop pour toutes les positions après chaque trade
   if(InpUseTrailing)
   {
      // Attendre un peu que la position soit bien enregistrée
      Sleep(1000);
      
      // Appliquer le trailing stop sur toutes les positions du robot
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;
         
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         
         // Appliquer le trailing stop immédiatement
         ManageTrailingStopForPosition(ticket);
         Print("🔄 Trailing stop appliqué à la position ", ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| GÉRER LE TRAILING STOP POUR UNE POSITION SPÉCIFIQUE        |
//+------------------------------------------------------------------+
void ManageTrailingStopForPosition(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double currentPrice = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                      SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentSL = PositionGetDouble(POSITION_SL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double trailingDistance = InpTrailDist * point;
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      // Trailing pour position BUY
      double newSL = currentPrice - trailingDistance;
      
      // Ne déplacer le SL que si le nouveau SL est plus haut que l'actuel
      if(newSL > currentSL || currentSL == 0)
      {
         // Vérifier la distance minimale autorisée
         double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
         if(currentPrice - newSL >= minDistance)
         {
            if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
            {
               Print("🔄 Trailing BUY - SL déplacé à: ", DoubleToString(newSL, _Digits));
            }
         }
      }
   }
   else // SELL
   {
      // Trailing pour position SELL
      double newSL = currentPrice + trailingDistance;
      
      // Ne déplacer le SL que si le nouveau SL est plus bas que l'actuel
      if(newSL < currentSL || currentSL == 0)
      {
         // Vérifier la distance minimale autorisée
         double minDistance = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
         if(newSL - currentPrice >= minDistance)
         {
            if(trade.PositionModify(ticket, newSL, PositionGetDouble(POSITION_TP)))
            {
               Print("🔄 Trailing SELL - SL déplacé à: ", DoubleToString(newSL, _Digits));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| VÉRIFIER ET FERMER LES POSITIONS ATTEIGNANT L'OBJECTIF PROFIT |
//+------------------------------------------------------------------+
void CheckAndCloseProfitTarget(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return;
   
   double profit = PositionGetDouble(POSITION_PROFIT);
   double swap = PositionGetDouble(POSITION_SWAP);
   double totalProfit = profit + swap;
   
   // Fermer si profit >= seuil configuré (2$ par défaut)
   if(totalProfit >= AutoCloseProfitUSD)
   {
      string positionType = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      double volume = PositionGetDouble(POSITION_VOLUME);
      
      Print("💰 OBJECTIF PROFIT ATTEINT - Fermeture position ", positionType, 
            " | Profit: ", DoubleToString(totalProfit, 2), "$ >= ", DoubleToString(AutoCloseProfitUSD, 2), "$ | Volume: ", volume);
      
      // Fermer la position
      if(trade.PositionClose(ticket))
      {
         Print("✅ Position fermée avec succès - Profit réalisé: ", DoubleToString(totalProfit, 2), "$");
         SendNotification("GoldRush: Position fermée - Profit " + DoubleToString(totalProfit, 2) + "$");
      }
      else
      {
         Print("❌ Échec fermeture position - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultComment());
      }
   }
}

//+------------------------------------------------------------------+
//| Supprime les objets obsolètes du tableau de bord GoldRush          |
//+------------------------------------------------------------------+
void CleanOldDashboardObjects()
{
   string prefix = "DASH_";
   int total = ObjectsTotal(0, 0, -1);
   
   for(int i = total-1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0) // Si le nom commence par le préfixe
      {
         datetime createTime = (datetime)ObjectGetInteger(0, name, OBJPROP_CREATETIME);
         if(TimeCurrent() - createTime > 300) // Supprimer les objets de plus de 5 minutes
         {
            ObjectDelete(0, name);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DASHBOARD AVANCÉ AVEC INFOS IA ET TRADING                     |
//+------------------------------------------------------------------+
void DrawAdvancedDashboard(double rsi, double adx, double atr)
{
   if(!UseAdvancedDashboard)
   {
      return;
   }

   // Nettoyer les objets obsolètes avant de créer le nouveau dashboard
   static datetime s_lastCleanup = 0;
   if(TimeCurrent() - s_lastCleanup > 60)
   {
      CleanOldDashboardObjects();
      s_lastCleanup = TimeCurrent();
   }

   ObjectsDeleteAll(0, "DASH_");

   // Vérifier le rafraîchissement
   if(TimeCurrent() - lastDrawTime < DashboardRefresh && lastDrawTime != 0)
   {
      // Ne pas bloquer l'affichage du dashboard
      // Print("Rafraîchissement du tableau de bord trop fréquent - Attente de ", DashboardRefresh, " secondes");
      // return;
   }
   lastDrawTime = TimeCurrent();

   color colorBull = clrLimeGreen;
   color colorBear = clrCrimson;
   color colorNeutral = clrGold;

   string text = "";

   text += "🤖 GOLDRUSH AI TRADING BOT\n";
   text += "══════════════════════════\n";
   text += "📊 " + _Symbol + " | " + EnumToString(Period()) + " | " + TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES) + "\n";
   text += "══════════════════════════\n\n";

   // --- DÉCISION FINALE ET LOGIQUE ---
   text += "🧠 DÉCISION FINALE\n";
   text += "────────────────────\n";
   
   string finalDecision = "✋ ATTENTE (HOLD)";
   color decisionColor = colorNeutral;
   string logicSummary = "Aucun signal fort détecté.";
   
   if(IsDailyLossLimitExceeded())
   {
      finalDecision = "🚫 STOP TRADING (Limite Pertes)";
      decisionColor = colorBear;
      logicSummary = "La limite de perte journalière est atteinte.";
   }
   else if(HasStrongSignal())
   {
      if(StringFind(g_lastAIAction, "buy") >= 0)
      {
         finalDecision = "🚀 ACHAT (BUY)";
         decisionColor = colorBull;
         logicSummary = "IA + Indicateurs alignés à l'achat.";
      }
      else if(StringFind(g_lastAIAction, "sell") >= 0)
      {
         finalDecision = "💥 VENTE (SELL)";
         decisionColor = colorBear;
         logicSummary = "IA + Indicateurs alignés à la vente.";
      }
   }
   
   text += "ACTION: " + finalDecision + "\n";
   text += "LOGIQUE: " + logicSummary + "\n";
   text += "────────────────────\n\n";

   text += "📊 STATUT DU TRADING\n";
   text += "────────────────────\n";

   int totalPositions = PositionsTotal();
   int buyPos = 0, sellPos = 0;
   double totalProf = 0.0;

   for(int i = 0; i < totalPositions; i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) buyPos++;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) sellPos++;
         totalProf += PositionGetDouble(POSITION_PROFIT);
      }
   }

   text += "Positions: " + IntegerToString(totalPositions) + " (" +
           IntegerToString(buyPos) + "▲ " + IntegerToString(sellPos) + "▼)\n";
   text += "Profit: " + DoubleToString(totalProf, 2) + " " + AccountInfoString(ACCOUNT_CURRENCY) + "\n";

   if(LastTradeSignal != "")
   {
      color signalColor = StringFind(LastTradeSignal, "ACHAT") >= 0 ? colorBull :
                         (StringFind(LastTradeSignal, "VENTE") >= 0 ? colorBear : colorNeutral);
      text += "Dernier signal: " + LastTradeSignal + "\n";
   }

   // ----- RECOMMANDATIONS IA / RENDER (toujours visibles) -----
   text += "\n🎯 RECOMMANDATIONS IA (RENDER/LOCAL)\n";
   text += "────────────────────\n";
   if(UseAI_Agent)
   {
      string recSignal = (g_lastAIAction == "" || g_lastAIAction == "error") ? "—" : g_lastAIAction;
      StringToUpper(recSignal);
      text += "Signal: " + recSignal + "\n";
      text += "Confiance: " + DoubleToString(g_lastAIConfidence * 100, 1) + "%\n";
      text += "Source: " + (lastAISource == 0 ? "🖥️ LOCAL" : "☁️ RENDER") + "\n";
      if(g_lastAIAction == "buy")
         text += "→ Recommandation: ACHAT\n";
      else if(g_lastAIAction == "sell")
         text += "→ Recommandation: VENTE\n";
      else if(g_lastAIAction == "hold")
         text += "→ Recommandation: NE PAS TRADER (hold)\n";
      else
         text += "→ En attente réponse serveur\n";
   }
   else
      text += "IA désactivée\n";
   text += "────────────────────\n";

   text += "\n📈 ANALYSE TECHNIQUE\n";
   text += "────────────────────\n";

   string rsiColor = "";
   if(rsi > 70) rsiColor = " (SURACHETÉ)";
   else if(rsi < 30) rsiColor = " (SURVENDU)";
   text += "RSI H1: " + DoubleToString(rsi, 1) + rsiColor + "\n";

   string adxStrength = "";
   if(adx > 25) adxStrength = " (FORT)";
   else if(adx > 15) adxStrength = " (MOYEN)";
   else adxStrength = " (FAIBLE)";
   text += "ADX H1: " + DoubleToString(adx, 1) + adxStrength + "\n";

   text += "ATR H1: " + DoubleToString(atr, 5) + " (Volatilité " + (atr > 0.001 ? "ÉLEVÉE" : "FAIBLE") + ")\n";

   if(UseMultiTimeframeEMA)
   {
      text += "\n⏱️ ANALYSE MULTI-TIMEFRAME\n";
      text += "────────────────────\n";

      bool emaH1Bullish = emaFast_H1_val > emaSlow_H1_val;
      text += "EMA H1: " + (emaH1Bullish ? "🟢 HAUSSIER" : "🔴 BAISSIER") + "\n";

      bool emaM5Bullish = emaFast_M5_val > emaSlow_M5_val;
      text += "EMA M5: " + (emaM5Bullish ? "🟢 HAUSSIER" : "🔴 BAISSIER") + "\n";

      bool emaM1Bullish = emaFast_M1_val > emaSlow_M1_val;
      text += "EMA M1: " + (emaM1Bullish ? "🟢 HAUSSIER" : "🔴 BAISSIER") + "\n";

      if(emaH1Bullish == emaM5Bullish && emaM5Bullish == emaM1Bullish)
      {
         text += "🎯 ALIGNEMENT: " + (emaH1Bullish ? "TENDANCE HAUSSIÈRE FORTE" : "TENDANCE BAISSIÈRE FORTE") + "\n";
      }
   }

   if(UseSpikeDetection)
   {
      text += "\n⚡ DÉTECTION DE SPIKES\n";
      text += "────────────────────\n";

      if(spikeDetected)
      {
         string spikeIcon = (spikeType == "BOOM") ? "🚀" : "💥";
         string spikeColor = (spikeType == "BOOM") ? "🟢" : "🔴";
         text += spikeIcon + " SPIKE DÉTECTÉ!\n";
         text += "Type: " + spikeColor + " " + spikeType + "\n";
         text += "Intensité: " + DoubleToString(spikeIntensity, 3) + "\n";
         text += "Confiance: " + DoubleToString(spikeConfidence * 100, 1) + "%\n";
         text += "Total spikes: " + IntegerToString(spikeCount) + "\n";
      }
      else
      {
         text += "⚪ Aucun spike détecté\n";
         text += "Total spikes: " + IntegerToString(spikeCount) + "\n";
      }
   }

   text += "\n══════════════════════════\n";

   text += "\n🧠 INTELLIGENCE ARTIFICIELLE\n";
   text += "────────────────────\n";

   text += "Source: " + (lastAISource == 0 ? "🖥️ LOCAL" : "☁️ RENDER") + "\n";

   if(lastPrediction != 0)
   {
      string predictionText = "Dernière prédiction: ";
      if(lastPrediction > 0.7) predictionText += "🟢 FORT ACHAT";
      else if(lastPrediction > 0.3) predictionText += "🟡 ACHAT";
      else if(lastPrediction < -0.7) predictionText += "🔴 FORTE VENTE";
      else if(lastPrediction < -0.3) predictionText += "🟠 VENTE";
      else predictionText += "⚪ NEUTRE";

      text += predictionText + " (" + DoubleToString(lastPrediction, 2) + ")\n";
   }

   if(UsePredictionChannel)
   {
      double upper[], lower[], close[];
      ArraySetAsSeries(upper, true);
      ArraySetAsSeries(lower, true);
      ArraySetAsSeries(close, true);

      int bands_handle = iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2, PRICE_CLOSE);
      if(bands_handle != INVALID_HANDLE)
      {
         if(CopyBuffer(bands_handle, 1, 0, 1, upper) > 0 &&
            CopyBuffer(bands_handle, 2, 0, 1, lower) > 0 &&
            CopyClose(_Symbol, PERIOD_CURRENT, 0, 1, close) > 0)
         {
            double current = close[0];
            string channelPos = "";
            if(current > upper[0] * 0.99) channelPos = " (PRÈS DE LA RÉSISTANCE)";
            else if(current < lower[0] * 1.01) channelPos = " (PRÈS DU SUPPORT)";

            text += "Canal: " + DoubleToString(lower[0], (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
                    " - " + DoubleToString(upper[0], (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) +
                    channelPos + "\n";
         }
         IndicatorRelease(bands_handle);
      }
   }

   text += "\n🎯 OPPORTUNITÉS\n";
   text += "────────────────────\n";

   if(emaFast_H1_val > emaSlow_H1_val && rsi < 40 && lastPrediction > 0.3)
      text += "🟢 POTENTIEL ACHAT: Tendance haussière avec RSI bas\n";
   else if(emaFast_H1_val < emaSlow_H1_val && rsi > 60 && lastPrediction < -0.3)
      text += "🔴 POTENTIELLE VENTE: Tendance baissière avec RSI haut\n";
   else
      text += "⚪ ATTENTE: Aucun signal fort détecté\n";

   text += "\n══════════════════════════\n";
   text += "🔄 Dernière mise à jour: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n";
   text += "⚙️ Lot: " + DoubleToString(GetCorrectLotSize(), 2) + " | Multiplicateur: " + DoubleToString(LotMultiplier, 1) + "\n";

   if(UseSupertrendIndicator)
   {
      text += "\n📊 ANALYSE SUPERTREND\n";
      text += "────────────────────\n";

      if(supertrend_H1 == INVALID_HANDLE && supertrend_M5 == INVALID_HANDLE)
      {
         text += "⚠️ Supertrend non disponible pour ce symbole\n";
         text += "   (Indicateur personnalisé manquant)\n";
      }
      else
      {
         if(supertrend_H1 != INVALID_HANDLE)
         {
            text += "H1: " + (supertrend_H1_dir > 0.0 ? "🟢 HAUSSIER" : "🔴 BAISSIER") + " (" +
                    DoubleToString(supertrend_H1_val, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) + ")\n";
         }
         else
         {
            text += "H1: ⚪ INDISPONIBLE\n";
         }

         if(supertrend_M5 != INVALID_HANDLE)
         {
            text += "M5: " + (supertrend_M5_dir > 0.0 ? "🟢 HAUSSIER" : "🔴 BAISSIER") + " (" +
                    DoubleToString(supertrend_M5_val, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) + ")\n";
         }
         else
         {
            text += "M5: ⚪ INDISPONIBLE\n";
         }

         if(supertrend_H1 != INVALID_HANDLE && supertrend_M5 != INVALID_HANDLE)
         {
            string decision = "⚪ NEUTRE";
            if(supertrend_H1_dir > 0 && supertrend_M5_dir > 0) decision = "🟢 FORT ACHAT";
            else if(supertrend_H1_dir < 0 && supertrend_M5_dir < 0) decision = "🔴 FORTE VENTE";
            else if(supertrend_H1_dir > 0 || supertrend_M5_dir > 0) decision = "🟡 ACHAT FAIBLE";
            else if(supertrend_H1_dir < 0 || supertrend_M5_dir < 0) decision = "🟠 VENTE FAIBLE";

            text += "DÉCISION: " + decision + "\n";
         }

         text += "Paramètres (Période: " + IntegerToString(Supertrend_Period) +
                 ", Multiplicateur: " + DoubleToString(Supertrend_Multiplier, 1) + ")\n";
      }
   }

   if(UseSupportResistance)
   {
      text += "═══════════════════\n";
      text += "🎯 NIVEAUX SR:\n";
      text += "RÉSIST H1: " + DoubleToString(H1_Resistance, 5) + "\n";
      text += "SUPPORT H1: " + DoubleToString(H1_Support, 5) + "\n";
      text += "RÉSIST M5: " + DoubleToString(M5_Resistance, 5) + "\n";
      text += "SUPPORT M5: " + DoubleToString(M5_Support, 5) + "\n";
   }

   text += "═══════════════════\n";

   if(UseAI_Agent)
   {
      text += "🤖 INTELLIGENCE ARTIFICIELLE:\n";
      string actionUpper = g_lastAIAction;
      StringToUpper(actionUpper);
      text += "Signal: " + actionUpper + "\n";
      text += "Confiance: " + DoubleToString(g_lastAIConfidence * 100, 1) + "%\n";

      string serverType = "INCONNU";
      if(StringFind(g_lastAIAction, "LOCAL") >= 0)
         serverType = "🏠 LOCAL";
      else if(StringFind(g_lastAIAction, "RENDER") >= 0)
         serverType = "☁️ RENDER";
      else if(g_lastAIAction != "")
         serverType = "🤖 IA";

      text += "Serveur: " + serverType + "\n";

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if(g_lastAIAction == "buy")
      {
         text += "🟢 ZONE D'ACHAT:\n";
         text += "Entrée: " + DoubleToString(ask, 5) + "\n";
         text += "Stop: " + DoubleToString(ask - InpStopLoss * _Point, 5) + "\n";
         text += "Target: " + DoubleToString(ask + InpTakeProfit * _Point, 5) + "\n";
      }
      else if(g_lastAIAction == "sell")
      {
         text += "🔴 ZONE DE VENTE:\n";
         text += "Entrée: " + DoubleToString(bid, 5) + "\n";
         text += "Stop: " + DoubleToString(bid + InpStopLoss * _Point, 5) + "\n";
         text += "Target: " + DoubleToString(bid - InpTakeProfit * _Point, 5) + "\n";
      }
   }

   text += "═══════════════════\n";
   text += "📊 CANAL DE PRÉDICTION:\n";
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2;
   double channelWidth = atr * 2;

   text += "Prix Actuel: " + DoubleToString(currentPrice, 5) + "\n";
   text += "Haut Canal: " + DoubleToString(currentPrice + channelWidth, 5) + "\n";
   text += "Bas Canal: " + DoubleToString(currentPrice - channelWidth, 5) + "\n";
   text += "Largeur: " + DoubleToString(channelWidth, 5) + " (" + DoubleToString(channelWidth/_Point, 0) + " pts)\n";

   if(currentPrice > (currentPrice + channelWidth * 0.8))
      text += "Position: 🔴 HAUT DU CANAL\n";
   else if(currentPrice < (currentPrice - channelWidth * 0.8))
      text += "Position: 🟢 BAS DU CANAL\n";
   else
      text += "Position: 🟡 CENTRE DU CANAL\n";

   text += "═══════════════════\n";

   text += "💼 TRADING:\n";
   double currentLot = GetCorrectLotSize();
   text += "Lot Size: " + DoubleToString(currentLot, 2) + "\n";
   text += "Position: " + (g_hasPosition ? "🟢 OUVERTE" : "🔴 AUCUNE") + "\n";

   if(UseDerivArrowDetection)
   {
      text += "DERIV Arrow: " + (derivArrowPresent ? "✅ OUI" : "❌ NON") + "\n";
      if(derivArrowPresent)
         text += "Arrow Type: " + (derivArrowType == 1 ? "🟢 BUY" : "🔴 SELL") + "\n";
   }

   if(UseProfitDuplication && g_hasPosition)
   {
      text += "═══════════════════\n";
      text += "💰 GESTION PROFITS:\n";
      text += "Profit Total: " + DoubleToString(totalSymbolProfit, 2) + "$\n";
      text += "Dupliqué: " + (hasDuplicated ? "✅ OUI" : "❌ NON") + "\n";
      if(hasDuplicated)
         text += "Ticket Dup: " + IntegerToString(duplicatedPositionTicket) + "\n";
   }

   text += "═══════════════════\n";
   text += "🎯 OPPORTUNITÉS:\n";

   bool opportunityBuy = false;
   bool opportunitySell = false;
   string opportunityReason = "";

   if(UseMultiTimeframeEMA)
   {
      bool emaBullish = (emaFast_H1_val > emaSlow_H1_val &&
                        emaFast_M5_val > emaSlow_M5_val &&
                        emaFast_M1_val > emaSlow_M1_val);
      bool emaBearish = (emaFast_H1_val < emaSlow_H1_val &&
                        emaFast_M5_val < emaSlow_M5_val &&
                        emaFast_M1_val < emaSlow_M1_val);

      if(emaBullish && rsi < 70)
      {
         opportunityBuy = true;
         opportunityReason += "🟢 EMA HAUSSIÈRE + RSI<" + DoubleToString(70, 0) + " ";
      }

      if(emaBearish && rsi > 30)
      {
         opportunitySell = true;
         opportunityReason += "🔴 EMA BAISSIÈRE + RSI>" + DoubleToString(30, 0) + " ";
      }
   }

   if(UseSupertrendIndicator)
   {
      if(supertrend_H1_dir > 0 && rsi < 70)
      {
         opportunityBuy = true;
         opportunityReason += "🟢 SUPERTREND ACHAT ";
      }

      if(supertrend_H1_dir < 0 && rsi > 30)
      {
         opportunitySell = true;
         opportunityReason += "🔴 SUPERTREND VENTE ";
      }
   }

   if(UseAI_Agent && g_lastAIConfidence >= AI_MinConfidence)
   {
      if(g_lastAIAction == "buy")
      {
         opportunityBuy = true;
         opportunityReason += "🤖 IA CONFIANCE " + DoubleToString(g_lastAIConfidence * 100, 0) + "% ";
      }
      else if(g_lastAIAction == "sell")
      {
         opportunitySell = true;
         opportunityReason += "🤖 IA CONFIANCE " + DoubleToString(g_lastAIConfidence * 100, 0) + "% ";
      }
   }

   if(opportunityBuy || opportunitySell)
   {
      text += "🎯 OPPORTUNITÉS DÉTECTÉES!\n";
      text += opportunityReason + "\n";

      if(opportunityBuy)
         text += "🟢 OPPORTUNITÉ D'ACHAT\n";
      if(opportunitySell)
         text += "🔴 OPPORTUNITÉ DE VENTE\n";
   }
   else
   {
      text += "⏳ ATTENTE SIGNAL\n";
      text += "Conditions non remplies\n";
   }

   if(text == lastDashText) return;
   lastDashText = text;

   if(ObjectFind(0,"Dashboard")==-1)
   {
      Print("Création de l'objet Dashboard");
      if(!ObjectCreate(0,"Dashboard",OBJ_LABEL,0,0,0))
         Print("Erreur lors de la création de l'objet Dashboard:", GetLastError());
   }

   ObjectSetInteger(0,"Dashboard",OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,"Dashboard",OBJPROP_XDISTANCE,10);
   ObjectSetInteger(0,"Dashboard",OBJPROP_YDISTANCE,20);
   ObjectSetInteger(0,"Dashboard",OBJPROP_FONTSIZE,9);
   ObjectSetInteger(0,"Dashboard",OBJPROP_COLOR,clrWhite);
   ObjectSetString(0,"Dashboard",OBJPROP_TEXT,text);
}

//+------------------------------------------------------------------+
//| VÉRIFIER LES SIGNAUX TECHNIQUES AVANCÉS                     |
//+------------------------------------------------------------------+
bool CheckAdvancedTechnicalSignal()
{
   bool emaSignal = false;
   bool supertrendSignal = false;
   bool srSignal = false;

   if(UseMultiTimeframeEMA)
   {
      bool h1Bullish = emaFast_H1_val > emaSlow_H1_val;
      bool h1Bearish = emaFast_H1_val < emaSlow_H1_val;
      bool m5Bullish = emaFast_M5_val > emaSlow_M5_val;
      bool m5Bearish = emaFast_M5_val < emaSlow_M5_val;
      bool m1Bullish = emaFast_M1_val > emaSlow_M1_val;
      bool m1Bearish = emaFast_M1_val < emaSlow_M1_val;

      if(h1Bullish && m5Bullish && m1Bullish)
      {
         emaSignal = true;
         Print("📈 EMA Signal: HAUSSIER (H1+M5+M1 alignés)");
      }
      else if(h1Bearish && m5Bearish && m1Bearish)
      {
         emaSignal = true;
         Print("📉 EMA Signal: BAISSIER (H1+M5+M1 alignés)");
      }
   }

   if(UseSupertrendIndicator)
   {
      bool h1STBullish = supertrend_H1_dir > 0;
      bool h1STBearish = supertrend_H1_dir < 0;
      bool m5STBullish = supertrend_M5_dir > 0;
      bool m5STBearish = supertrend_M5_dir < 0;

      if(h1STBullish && m5STBullish)
      {
         supertrendSignal = true;
         Print("📈 Supertrend Signal: HAUSSIER");
      }
      else if(h1STBearish && m5STBearish)
      {
         supertrendSignal = true;
         Print("📉 Supertrend Signal: BAISSIER");
      }
   }

   if(UseSupportResistance)
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      if(currentPrice >= H1_Resistance * 0.998 && currentPrice <= H1_Resistance * 1.002)
      {
         srSignal = true;
         Print("🎯 Support/Résistance: PROCHE RÉSISTANCE H1");
      }
      else if(currentPrice >= H1_Support * 0.998 && currentPrice <= H1_Support * 1.002)
      {
         srSignal = true;
         Print("🎯 Support/Résistance: PROCHE SUPPORT H1");
      }
   }

   return (emaSignal || supertrendSignal || srSignal);
}

//+------------------------------------------------------------------+
//| OBTENIR LA DIRECTION DU SIGNAL AVANCÉ                       |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetAdvancedSignalDirection()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(UseMultiTimeframeEMA)
   {
      if(emaFast_H1_val > emaSlow_H1_val &&
         emaFast_M5_val > emaSlow_M5_val &&
         emaFast_M1_val > emaSlow_M1_val)
         return ORDER_TYPE_BUY;
      else if(emaFast_H1_val < emaSlow_H1_val &&
              emaFast_M5_val < emaSlow_M5_val &&
              emaFast_M1_val < emaSlow_M1_val)
         return ORDER_TYPE_SELL;
   }

   if(UseSupertrendIndicator)
   {
      if(supertrend_H1_dir > 0 && supertrend_M5_dir > 0)
         return ORDER_TYPE_BUY;
      else if(supertrend_H1_dir < 0 && supertrend_M5_dir < 0)
         return ORDER_TYPE_SELL;
   }

   if(UseSupportResistance)
   {
      if(currentPrice >= H1_Support * 0.998 && currentPrice <= H1_Support * 1.002)
         return ORDER_TYPE_BUY;
      else if(currentPrice >= H1_Resistance * 0.998 && currentPrice <= H1_Resistance * 1.002)
         return ORDER_TYPE_SELL;
   }

   return WRONG_VALUE;
}

//+------------------------------------------------------------------+
//| VALIDER L'ENTRÉE AVANCÉE                                   |
//+------------------------------------------------------------------+
bool ValidateAdvancedEntry(ENUM_ORDER_TYPE orderType)
{
   // === MODE ULTRA-SIMPLE : PAS DE VALIDATIONS COMPLEXES ===
   
   // Seulement vérifier le ratio risque/récompense de base
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double slDist = (InpStopLoss > 0) ? (InpStopLoss * point) : (100 * point);
   double tpDist = (InpTakeProfit > 0) ? (InpTakeProfit * point) : (150 * point);
   double rrRatio = (slDist > 0) ? (tpDist / slDist) : 1.0;
   
   if(MinRiskRewardRatio > 0 && rrRatio < MinRiskRewardRatio)
   {
      Print("❌ R:R insuffisant: ", DoubleToString(rrRatio, 2));
      return false;
   }

   // Pas d'autres validations pour performance maximale
   Print("✅ Entrée validée (mode ultra-simple)");
   return true;
}

//+------------------------------------------------------------------+
//| DÉTECTION DE TRENDLINES                                        |
//+------------------------------------------------------------------+
void UpdateTrendlineDetection()
{
   if(!UseTrendlineDetection) return;
   
   // Mettre à jour seulement toutes les 4 heures (au lieu de 1 heure)
   if(TimeCurrent() - lastTrendlineUpdate < 14400) return;
   lastTrendlineUpdate = TimeCurrent();
   
   int lookback = MathMin(TrendlineLookbackBars, 30); // Limiter à 30 barres max
   if(lookback <= 0) lookback = 20;
   
   // Récupérer les données de prix une seule fois
   double high[], low[];
   datetime time[];
   
   ArrayResize(high, lookback);
   ArrayResize(low, lookback);
   ArrayResize(time, lookback);
   
   if(CopyHigh(_Symbol, PERIOD_H1, 0, lookback, high) <= 0 ||
      CopyLow(_Symbol, PERIOD_H1, 0, lookback, low) <= 0 ||
      CopyTime(_Symbol, PERIOD_H1, 0, lookback, time) <= 0)
   {
      Print("❌ Erreur récupération données pour trendlines");
      return;
   }
   
   // Simplification: utiliser seulement les points les plus significatifs
   bullishTrendlineValid = false;
   bearishTrendlineValid = false;
   
   // Détecter trendline haussière simplifiée
   int bullishPoints = 0;
   double bullishSlope = 0.0;
   
   // Chercher seulement 2 points bas significatifs
   for(int i = lookback - 5; i >= 5; i -= 3) // Réduire les itérations
   {
      if(low[i] <= low[i-1] && low[i] <= low[i+1] && 
         low[i] <= low[i-2] && low[i] <= low[i+2])
      {
         if(bullishPoints == 0)
         {
            // Premier point bas
            bullishSlope = low[i];
            bullishPoints = 1;
         }
         else if(bullishPoints == 1 && i < lookback - 10)
         {
            // Deuxième point bas - calculer pente
            double firstPoint = bullishSlope;
            bullishSlope = (low[i] - firstPoint) / (lookback - i);
            
            if(bullishSlope > TrendlineMinSlope * _Point)
            {
               bullishTrendlineValid = true;
               bullishTrendlineSlope = bullishSlope;
            }
            break; // Sortir après avoir trouvé 2 points
         }
      }
   }
   
   // Détecter trendline baissière simplifiée
   int bearishPoints = 0;
   double bearishSlope = 0.0;
   
   for(int i = lookback - 5; i >= 5; i -= 3) // Réduire les itérations
   {
      if(high[i] >= high[i-1] && high[i] >= high[i+1] && 
         high[i] >= high[i-2] && high[i] >= high[i+2])
      {
         if(bearishPoints == 0)
         {
            // Premier point haut
            bearishSlope = high[i];
            bearishPoints = 1;
         }
         else if(bearishPoints == 1 && i < lookback - 10)
         {
            // Deuxième point haut - calculer pente
            double firstPoint = bearishSlope;
            bearishSlope = (high[i] - firstPoint) / (lookback - i);
            
            if(bearishSlope < -TrendlineMinSlope * _Point)
            {
               bearishTrendlineValid = true;
               bearishTrendlineSlope = bearishSlope;
            }
            break; // Sortir après avoir trouvé 2 points
         }
      }
   }
   
   Print("🔍 Trendlines optimisées - Haussière: ", bullishTrendlineValid ? "OUI" : "NON", 
         " (pente: ", DoubleToString(bullishTrendlineSlope/_Point, 2), " pips/barre)");
   Print("🔍 Trendlines optimisées - Baissière: ", bearishTrendlineValid ? "OUI" : "NON", 
         " (pente: ", DoubleToString(bearishTrendlineSlope/_Point, 2), " pips/barre)");
}

//+------------------------------------------------------------------+
//| DESSINER LES INDICATEURS MULTI-TIMEFRAMES                   |
//+------------------------------------------------------------------+
void DrawMultiTimeframeIndicators()
{
   ObjectsDeleteAll(0, "MTF_");

   if(UseMultiTimeframeEMA)
   {
      ObjectCreate(0, "MTF_EMA_H1_FAST", OBJ_HLINE, 0, 0, emaFast_H1_val);
      ObjectSetInteger(0, "MTF_EMA_H1_FAST", OBJPROP_COLOR, clrBlue);
      ObjectSetInteger(0, "MTF_EMA_H1_FAST", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "MTF_EMA_H1_FAST", OBJPROP_WIDTH, 2);

      ObjectCreate(0, "MTF_EMA_H1_SLOW", OBJ_HLINE, 0, 0, emaSlow_H1_val);
      ObjectSetInteger(0, "MTF_EMA_H1_SLOW", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "MTF_EMA_H1_SLOW", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "MTF_EMA_H1_SLOW", OBJPROP_WIDTH, 2);

      ObjectCreate(0, "MTF_EMA_M5_FAST", OBJ_HLINE, 0, 0, emaFast_M5_val);
      ObjectSetInteger(0, "MTF_EMA_M5_FAST", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "MTF_EMA_M5_FAST", OBJPROP_STYLE, STYLE_DASH);

      ObjectCreate(0, "MTF_EMA_M5_SLOW", OBJ_HLINE, 0, 0, emaSlow_M5_val);
      ObjectSetInteger(0, "MTF_EMA_M5_SLOW", OBJPROP_COLOR, clrIndianRed);
      ObjectSetInteger(0, "MTF_EMA_M5_SLOW", OBJPROP_STYLE, STYLE_DASH);
   }

   if(UseSupertrendIndicator)
   {
      ObjectCreate(0, "MTF_SUPERTREND_H1", OBJ_HLINE, 0, 0, supertrend_H1_val);
      ObjectSetInteger(0, "MTF_SUPERTREND_H1", OBJPROP_COLOR, supertrend_H1_dir > 0 ? clrLime : clrOrangeRed);
      ObjectSetInteger(0, "MTF_SUPERTREND_H1", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "MTF_SUPERTREND_H1", OBJPROP_WIDTH, 3);
   }

   if(UseSupportResistance)
   {
      ObjectCreate(0, "MTF_H1_RESISTANCE", OBJ_HLINE, 0, 0, H1_Resistance);
      ObjectSetInteger(0, "MTF_H1_RESISTANCE", OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, "MTF_H1_RESISTANCE", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "MTF_H1_RESISTANCE", OBJPROP_WIDTH, 2);

      ObjectCreate(0, "MTF_H1_SUPPORT", OBJ_HLINE, 0, 0, H1_Support);
      ObjectSetInteger(0, "MTF_H1_SUPPORT", OBJPROP_COLOR, clrAqua);
      ObjectSetInteger(0, "MTF_H1_SUPPORT", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, "MTF_H1_SUPPORT", OBJPROP_WIDTH, 2);
   }
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
      lastAnalysisData = analysis;

   string trend = UpdateTrendEndpoint();
   if(trend != "")
      lastTrendData = trend;

   string prediction = UpdatePredictionEndpoint();
   if(prediction != "")
      lastPredictionData = prediction;

   string coherent = UpdateCoherentEndpoint();
   if(coherent != "")
      lastCoherentData = coherent;

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
      }
      else
         Print("❌ Erreur Prediction endpoint - GET:", responseCode, " POST:", responseCode);
   }
   else
      Print("❌ Erreur lors de la mise à jour du prediction endpoint - Code:", responseCode);

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
//| FONCTIONS DE DÉTECTION DE SPIKES                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Vérifier si symbole Boom/Crash (seuils plus sensibles)           |
//+------------------------------------------------------------------+
bool IsBoomCrashSymbol()
{
   string sym = _Symbol;
   return (StringFind(sym, "Boom") >= 0 || StringFind(sym, "Crash") >= 0 || 
           StringFind(sym, "Volatility") >= 0 || StringFind(sym, "Step Index") >= 0);
}

//+------------------------------------------------------------------+
//| DÉTECTION DE SPIKE PAR POURCENTAGE                              |
//| Utilise les barres PRÉCÉDENTES pour la MA (exclut barre courante)|
//+------------------------------------------------------------------+
bool DetectPercentageSpike(double currentPrice, double &priceMA, double &priceSTD, double &intensity, double &confidence)
{
   double prices[];
   ArraySetAsSeries(prices, true);

   // Besoin de Window+1 barres: [0]=courant, [1..Window]=pour la MA
   int barsNeeded = SpikeDetectionWindow + 1;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, barsNeeded, prices) < barsNeeded)
      return false;

   // MA sur les barres PRÉCÉDENTES uniquement (pas la barre courante)
   priceMA = 0;
   for(int i = 1; i <= SpikeDetectionWindow; i++)
      priceMA += prices[i];
   priceMA /= SpikeDetectionWindow;

   priceSTD = 0;
   for(int i = 1; i <= SpikeDetectionWindow; i++)
      priceSTD += MathPow(prices[i] - priceMA, 2);
   priceSTD = MathSqrt(priceSTD / SpikeDetectionWindow);

   double priceChangePct = (priceMA != 0) ? ((currentPrice - priceMA) / priceMA) * 100 : 0;

   // Seuil plus bas pour Boom/Crash
   double threshold = SpikeThresholdPercent;
   if(UseBoomCrashSensitiveMode && IsBoomCrashSymbol())
      threshold = MathMin(SpikeThresholdPercent, 0.05);

   bool isSpike = MathAbs(priceChangePct) > threshold;

   if(isSpike)
   {
      intensity = MathAbs(priceChangePct);

      double pctMA = 0;
      double pctSTD = 0;
      double pctChanges[];

      for(int i = 1; i < SpikeDetectionWindow; i++)
      {
         if(prices[i+1] > 0)
            pctMA += ((prices[i] - prices[i+1]) / prices[i+1]) * 100;
      }

      if(SpikeDetectionWindow > 1)
      {
         pctMA /= (SpikeDetectionWindow - 1);
         for(int i = 1; i < SpikeDetectionWindow; i++)
         {
            double pctCh = (prices[i+1] > 0) ? ((prices[i] - prices[i+1]) / prices[i+1]) * 100 : 0;
            pctSTD += MathPow(pctCh - pctMA, 2);
         }
         pctSTD = MathSqrt(pctSTD / (SpikeDetectionWindow - 1));
      }

      if(pctSTD > 0)
         confidence = MathMin(MathAbs(priceChangePct) / (MathAbs(pctMA) + 0.5 * pctSTD), 1.0);
      else
         confidence = MathMin(intensity / threshold, 1.0);

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| DÉTECTION DE SPIKE PAR ÉCART-TYPE (Z-SCORE)                     |
//| MA sur barres précédentes, compare à prix courant                |
//+------------------------------------------------------------------+
bool DetectStandardDeviationSpike(double currentPrice, double &priceMA, double &priceSTD, double &spikeZScore, double &intensity, double &confidence)
{
   double prices[];
   ArraySetAsSeries(prices, true);

   int barsNeeded = SpikeDetectionWindow + 1;
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, barsNeeded, prices) < barsNeeded)
      return false;

   priceMA = 0;
   for(int i = 1; i <= SpikeDetectionWindow; i++)
      priceMA += prices[i];
   priceMA /= SpikeDetectionWindow;

   priceSTD = 0;
   for(int i = 1; i <= SpikeDetectionWindow; i++)
      priceSTD += MathPow(prices[i] - priceMA, 2);
   priceSTD = MathSqrt(priceSTD / SpikeDetectionWindow);

   if(priceSTD > 0)
      spikeZScore = MathAbs(currentPrice - priceMA) / priceSTD;
   else
      spikeZScore = 0;

   double threshold = StdDevSpikeThreshold;
   if(UseBoomCrashSensitiveMode && IsBoomCrashSymbol())
      threshold = MathMin(StdDevSpikeThreshold, 0.6);

   bool isSpike = spikeZScore > threshold;

   if(isSpike)
   {
      intensity = spikeZScore;
      confidence = MathMin(spikeZScore / threshold, 1.0);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| DÉTECTION DE SPIKE PAR VOLUME                                   |
//+------------------------------------------------------------------+
bool DetectVolumeSpike(double currentVolume, double &spikeVolumeMA, double &spikeVolumeRatio, double &intensity, double &confidence)
{
   long volumes[];
   ArraySetAsSeries(volumes, true);

   if(CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, SpikeDetectionWindow, volumes) < SpikeDetectionWindow)
      return false;

   spikeVolumeMA = 0.0;
   for(int i = 0; i < SpikeDetectionWindow; i++)
      spikeVolumeMA += (double)volumes[i];
   spikeVolumeMA /= SpikeDetectionWindow;

   if(spikeVolumeMA > 0)
      spikeVolumeRatio = currentVolume / spikeVolumeMA;
   else
      spikeVolumeRatio = 1.0;

   bool isVolumeSpike = spikeVolumeRatio > VolumeSpikeMultiplier;

   if(isVolumeSpike)
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double prevPrice = iClose(_Symbol, PERIOD_CURRENT, 1);

      if(prevPrice > 0)
      {
         double priceChange = MathAbs((currentPrice - prevPrice) / prevPrice) * 100;

         if(priceChange > 0.005)
         {
            intensity = spikeVolumeRatio;
            confidence = MathMin(spikeVolumeRatio / VolumeSpikeMultiplier, 1.0);
            return true;
         }
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE LA DÉTECTION DE SPIKES                          |
//+------------------------------------------------------------------+
void UpdateSpikeDetection()
{
   if(!UseSpikeDetection)
      return;

   spikeDetected = false;
   spikeType = "";
   spikeIntensity = 0.0;
   spikeConfidence = 0.0;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentVolume = (double)iVolume(_Symbol, PERIOD_CURRENT, 0);

   if(currentPrice <= 0)
      return;

   bool pctSpike = false;
   if(SpikeThresholdPercent > 0)
   {
      pctSpike = DetectPercentageSpike(currentPrice, spikePriceMA, spikePriceSTD, spikeIntensity, spikeConfidence);
   }

   bool stdSpike = false;
   if(UseStandardDeviationSpike && StdDevSpikeThreshold > 0)
   {
      double stdIntensity = 0.0, stdConfidence = 0.0, stdZScore = 0.0;
      stdSpike = DetectStandardDeviationSpike(currentPrice, spikePriceMA, spikePriceSTD, stdZScore, stdIntensity, stdConfidence);

      if(stdSpike && stdConfidence > spikeConfidence)
      {
         spikeIntensity = stdIntensity;
         spikeConfidence = stdConfidence;
         zScore = stdZScore;
      }
   }

   bool volSpike = false;
   if(UseVolumeSpikeDetection && VolumeSpikeMultiplier > 0)
   {
      double volIntensity = 0.0, volConfidence = 0.0, volVolumeMA = 0.0, volVolumeRatio = 0.0;
      volSpike = DetectVolumeSpike(currentVolume, volVolumeMA, volVolumeRatio, volIntensity, volConfidence);

      if(volSpike && volConfidence > spikeConfidence)
      {
         spikeIntensity = volIntensity;
         spikeConfidence = volConfidence;
         volumeMA = volVolumeMA;
         volumeRatio = volVolumeRatio;
      }
   }

   spikeDetected = (pctSpike || stdSpike || volSpike) && spikeConfidence >= SpikeMinConfidence;

   if(spikeDetected)
   {
      double prevPrice = iClose(_Symbol, PERIOD_CURRENT, 1);
      if(prevPrice > 0)
      {
         if(currentPrice > prevPrice)
            spikeType = "BOOM";
         else
            spikeType = "CRASH";
      }
      else
      {
         spikeType = "UNKNOWN";
      }

      lastSpikeTime = TimeCurrent();
      spikeCount++;

      Print("🚨 SPIKE DÉTECTÉ - Type: ", spikeType,
            ", Intensité: ", DoubleToString(spikeIntensity, 3),
            ", Confiance: ", DoubleToString(spikeConfidence * 100, 1), "%");
      
      // Dessiner une flèche dynamique pour le spike détecté
      DrawSpikeArrows(spikeType, currentPrice, spikeIntensity, spikeConfidence);
   }
   else
   {
      // Nettoyer les anciennes flèches si aucun spike n'est détecté
      CleanupOldSpikeArrows();
   }
}

//+------------------------------------------------------------------+
//| VÉRIFIER SI UN SPIKE EST DÉTECTÉ                               |
//+------------------------------------------------------------------+
bool IsSpikeDetected()
{
   return spikeDetected;
}

//+------------------------------------------------------------------+
//| OBTENIR LE TYPE DE SPIKE                                        |
//+------------------------------------------------------------------+
string GetSpikeType()
{
   return spikeType;
}

//+------------------------------------------------------------------+
//| OBTENIR L'INTENSITÉ DU SPIKE                                    |
//+------------------------------------------------------------------+
double GetSpikeIntensity()
{
   return spikeIntensity;
}

//+------------------------------------------------------------------+
//| OBTENIR LA CONFIANCE DU SPIKE                                   |
//+------------------------------------------------------------------+
double GetSpikeConfidence()
{
   return spikeConfidence;
}

//+------------------------------------------------------------------+
//| ANALYSER LES PATTERNS DE SPIKES                                 |
//+------------------------------------------------------------------+
void AnalyzeSpikePattern()
{
   if(!UseSpikePatternAnalysis || spikeCount < 2)
      return;

   static datetime lastPatternAnalysis = 0;
   if(TimeCurrent() - lastPatternAnalysis < 3600)
      return;

   lastPatternAnalysis = TimeCurrent();
   Print("📊 Analyse de pattern de spikes - Total: ", spikeCount, " spikes détectés");
}

//+------------------------------------------------------------------+
//| VALIDER L'ENTRÉE POUR UN TRADE DE SPIKE                         |
//+------------------------------------------------------------------+
bool ValidateSpikeEntry(ENUM_ORDER_TYPE tradeType)
{
   if(!spikeDetected || spikeConfidence < SpikeMinConfidence)
      return false;

   if(StringFind(_Symbol, "Boom") >= 0 && tradeType == ORDER_TYPE_SELL)
   {
      Print("🚨 SÉCURITÉ - Positions SELL interdites sur Boom avec spike: ", _Symbol);
      return false;
   }

   if(StringFind(_Symbol, "Crash") >= 0 && tradeType == ORDER_TYPE_BUY)
   {
      Print("🚨 SÉCURITÉ - Positions BUY interdites sur Crash avec spike: ", _Symbol);
      return false;
   }

   if(spikeType == "BOOM" && tradeType != ORDER_TYPE_BUY)
   {
      Print("⚠️ Incompatibilité - Spike BOOM détecté mais trade SELL demandé");
      return false;
   }

   if(spikeType == "CRASH" && tradeType != ORDER_TYPE_SELL)
   {
      Print("⚠️ Incompatibilité - Spike CRASH détecté mais trade BUY demandé");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| EXÉCUTER UN TRADE DE SPIKE                                      |
//+------------------------------------------------------------------+
void ExecuteSpikeTrade(ENUM_ORDER_TYPE tradeType, double ask, double bid)
{
   if(!ValidateSpikeEntry(tradeType))
      return;

   double lotSize = GetCorrectLotSize();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopLoss = 0;
   double takeProfit = 0;
   double entryPrice = 0;

   if(tradeType == ORDER_TYPE_BUY)
   {
      entryPrice = ask;
      stopLoss = bid - (SpikeDetectionWindow * 10 * point);
      takeProfit = ask + (SpikeDetectionWindow * 20 * point);
   }
   else
   {
      entryPrice = bid;
      stopLoss = ask + (SpikeDetectionWindow * 10 * point);
      takeProfit = bid - (SpikeDetectionWindow * 20 * point);
   }

   // Désactivation temporaire de la validation des stops pour les spikes
   // if(!ValidateStopLevels(tradeType == ORDER_TYPE_BUY ? ask : bid, stopLoss, takeProfit, tradeType == ORDER_TYPE_BUY))
   // {
   //    Print("❌ Niveaux SL/TP invalides pour le trade de spike");
   //    return;
   // }

   if(tradeType == ORDER_TYPE_BUY)
   {
      if(UseLimitOrdersForSpikes)
      {
         double limitPrice = ask + (SpikeDetectionWindow * 2 * point);
         if(trade.Buy(lotSize, _Symbol, limitPrice, stopLoss, takeProfit, "Spike BOOM LIMIT"))
         {
            Print("🚀 Trade SPIKE BUY LIMIT exécuté - Lot: ", lotSize,
                  ", Prix: ", limitPrice, ", SL: ", stopLoss, ", TP: ", takeProfit);
         }
      }
      else
      {
         if(trade.Buy(lotSize, _Symbol, ask, stopLoss, takeProfit, "Spike BOOM"))
         {
            Print("🚀 Trade SPIKE BUY MARKET exécuté - Lot: ", lotSize,
                  ", SL: ", stopLoss, ", TP: ", takeProfit);
         }
      }
   }
   else
   {
      if(UseLimitOrdersForSpikes)
      {
         double limitPrice = bid - (SpikeDetectionWindow * 2 * point);
         if(trade.Sell(lotSize, _Symbol, limitPrice, stopLoss, takeProfit, "Spike CRASH LIMIT"))
         {
            Print("🚀 Trade SPIKE SELL LIMIT exécuté - Lot: ", lotSize,
                  ", Prix: ", limitPrice, ", SL: ", stopLoss, ", TP: ", takeProfit);
         }
      }
      else
      {
         if(trade.Sell(lotSize, _Symbol, bid, stopLoss, takeProfit, "Spike CRASH"))
         {
            Print("🚀 Trade SPIKE SELL MARKET exécuté - Lot: ", lotSize,
                  ", SL: ", stopLoss, ", TP: ", takeProfit);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| DESSINER DES FLÈCHES DYNAMIQUES POUR LES SPIKES                |
//+------------------------------------------------------------------+
void DrawSpikeArrows(string spikeTypeValue, double price, double intensity, double confidence)
{
   datetime currentTime = TimeCurrent();
   string arrowName = "SpikeArrow_" + IntegerToString(currentTime);
   
   // Déterminer la couleur et le code de la flèche selon le type de spike
   color arrowColor;
   int arrowCode;
   string description;
   
   if(spikeTypeValue == "BOOM")
   {
      arrowColor = clrLime;      // Vert pour les spikes haussiers
      arrowCode = 233;           // Flèche vers le haut
      description = "🚀 BOOM SPIKE";
   }
   else if(spikeTypeValue == "CRASH")
   {
      arrowColor = clrRed;       // Rouge pour les spikes baissiers
      arrowCode = 234;           // Flèche vers le bas
      description = "💥 CRASH SPIKE";
   }
   else
   {
      arrowColor = clrYellow;    // Jaune pour les spikes inconnus
      arrowCode = 159;          // Point d'interrogation
      description = "❓ UNKNOWN SPIKE";
   }
   
   // Ajuster la taille de la flèche selon l'intensité du spike
   int arrowSize = (int)MathRound(3 + intensity * 5); // Taille entre 3 et 8
   if(arrowSize > 8) arrowSize = 8;
   if(arrowSize < 3) arrowSize = 3;
   
   // Créer la flèche principale
   if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, currentTime, price))
   {
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, (int)arrowSize);
      ObjectSetInteger(0, arrowName, OBJPROP_BACK, 0);
      ObjectSetString(0, arrowName, OBJPROP_TOOLTIP, description + 
                     " | Intensité: " + DoubleToString(intensity, 3) + 
                     " | Confiance: " + DoubleToString(confidence * 100, 1) + "%");
   }
   
   // Ajouter une étiquette descriptive au-dessus de la flèche
   string labelName = "SpikeLabel_" + IntegerToString(currentTime);
   double labelPrice = spikeTypeValue == "BOOM" ? price + (20 * _Point) : price - (20 * _Point);
   
   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, labelPrice))
   {
      ObjectSetString(0, labelName, OBJPROP_TEXT, description);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, spikeTypeValue == "BOOM" ? ANCHOR_LEFT_UPPER : ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
   }
   
   // Ajouter un cercle d'alerte autour du spike pour plus de visibilité
   string circleName = "SpikeCircle_" + IntegerToString(currentTime);
   if(ObjectCreate(0, circleName, OBJ_RECTANGLE, 0, currentTime - 60, price - (10 * _Point), currentTime + 60, price + (10 * _Point)))
   {
      ObjectSetInteger(0, circleName, OBJPROP_COLOR, arrowColor);
      ObjectSetInteger(0, circleName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, circleName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, circleName, OBJPROP_BACK, true);
      ObjectSetInteger(0, circleName, OBJPROP_FILL, false);
   }
   
   Print("🎯 Flèche de spike dessinée: ", description, " à ", DoubleToString(price, _Digits));
}

//+------------------------------------------------------------------+
//| NETTOYER LES ANCIENNES FLÈCHES DE SPIKES                        |
//+------------------------------------------------------------------+
void CleanupOldSpikeArrows()
{
   static datetime lastCleanup = 0;
   
   // Nettoyer seulement toutes les 30 secondes pour éviter la surcharge
   if(TimeCurrent() - lastCleanup < 30)
      return;
   
   lastCleanup = TimeCurrent();
   
   // Supprimer les anciennes flèches (plus de 5 minutes)
   datetime cutoffTime = TimeCurrent() - 300; // 5 minutes
   
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, -1);
      
      if(StringFind(objName, "SpikeArrow_") == 0 || 
         StringFind(objName, "SpikeLabel_") == 0 || 
         StringFind(objName, "SpikeCircle_") == 0)
      {
         // Extraire le timestamp du nom de l'objet
         string timestampStr = StringSubstr(objName, StringFind(objName, "_") + 1);
         datetime objTime = (datetime)StringToInteger(timestampStr);
         
         if(objTime < cutoffTime)
         {
            ObjectDelete(0, objName);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Fonction helper pour créer les labels du dashboard               |
//+------------------------------------------------------------------+
void CreateDashboardLabel(string name, string text, int x, int y, color clr, int fontSize=10)
{
   string objName = "DASH_LEFT_" + name;
   if(ObjectFind(0, objName) >= 0) ObjectDelete(0, objName);
   
   ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Fonction de mise à jour du dashboard gauche                      |
//+------------------------------------------------------------------+
void UpdateLeftDashboard()
{
   // Calculs pour dashboard (basés sur étapes 1–3D)
   double dailyNetProfit = CalculateDailyNetProfit();  // Étape 1
   string profitStatus = (dailyNetProfit >= 10.0) ? "ATTEINT (stop trades)" : StringFormat("%.2f $ / 10.0 $", dailyNetProfit);
   color profitColor = (dailyNetProfit >= 10.0) ? colorOK : (dailyNetProfit > 0 ? colorWarn : colorAlert);
   
   double lotExample = CalculateRiskBasedLotSize(InpRiskPercentPerTrade, InpStopLoss);  // Étape 2
   string riskStatus = StringFormat("Risque/trade: %.1f %% → Lot: %.2f", InpRiskPercentPerTrade, lotExample);
   
   // Étape 3A/D : filtre local
   string filterReason = "";
   bool filterValid = IsLocalFilterValid(g_lastAIAction, g_lastAIConfidence, filterReason);  // Utilise ta fonction renforcée
   string filterStatus = filterValid ? "VALIDÉ" : "REFUSÉ";
   color filterColor = filterValid ? colorOK : colorAlert;
   
   // Étape 3B : statut breakeven/trailing
   int openPositions = PositionsTotal();
   string trailStatus = (openPositions > 0) ? StringFormat("%d positions ouvertes (trailing actif)", openPositions) : "Aucune position (breakeven prêt)";
   
   // Confiance IA (étape 3D fallback)
   string aiStatus = StringFormat("Confiance IA: %.2f %% (%s)", g_lastAIConfidence * 100, (g_lastAIConfidence >= 0.68) ? "OK" : "Fallback renforcé");
   color aiColor = (g_lastAIConfidence >= 0.68) ? colorOK : colorWarn;
   
   // ────────────────────────────────
   // Création des labels (coin gauche)
   // ────────────────────────────────
   int lineY = dashboardY;  // Commence en haut gauche
   
   CreateDashboardLabel("Dash_Profit", "Profit Net Jour: " + profitStatus, dashboardX, lineY, profitColor);
   lineY += 20;
   
   CreateDashboardLabel("Dash_Risk", riskStatus, dashboardX, lineY, clrWhite);
   lineY += 20;
   
   CreateDashboardLabel("Dash_FilterLocal", "Filtre Local: " + filterStatus + " (" + filterReason + ")", dashboardX, lineY, filterColor);
   lineY += 20;
   
   CreateDashboardLabel("Dash_TrailBE", "Breakeven/Trailing: " + trailStatus, dashboardX, lineY, clrWhite);
   lineY += 20;
   
   CreateDashboardLabel("Dash_AI", aiStatus, dashboardX, lineY, aiColor);
   lineY += 20;
}

//+------------------------------------------------------------------+
//| Nettoyer tous les objets graphiques expirés                      |
//+------------------------------------------------------------------+
void CleanExpiredObjects()
{
    datetime currentTime = TimeCurrent();
    datetime cutoffTime = currentTime - 3600; // Supprimer les objets de plus d'1 heure
    
    for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i, -1, -1);
        
        // Vérifier si c'est un objet de nos robots
        if(StringFind(objName, "GoldRush_") >= 0 || 
           StringFind(objName, "DASH_") >= 0 ||
           StringFind(objName, "SpikeArrow_") >= 0 ||
           StringFind(objName, "Prediction_") >= 0 ||
           StringFind(objName, "SMC_") >= 0 ||
           StringFind(objName, "MTF_") >= 0)
        {
            datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME);
            
            // Si l'objet est trop ancien ou a une date future, le supprimer
            if(objTime < cutoffTime || objTime > currentTime)
            {
                ObjectDelete(0, objName);
            }
        }
    }
}
