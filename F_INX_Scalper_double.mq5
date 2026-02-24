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

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES POUR OPTIMISATION PERFORMANCE              |
//+------------------------------------------------------------------+

// Cache des informations de symbole (évite les appels SymbolInfoDouble coûteux)
double g_cachedPoint = 0.0;
double g_cachedAsk = 0.0;
double g_cachedBid = 0.0;
double g_cachedTickValue = 0.0;
double g_cachedTickSize = 0.0;
double g_cachedMinLot = 0.0;
double g_cachedMaxLot = 0.0;
double g_cachedLotStep = 0.0;
datetime g_lastSymbolCacheUpdate = 0;
const int SYMBOL_CACHE_INTERVAL = 5; // Mettre à jour cache toutes les 5 secondes

// Paramètres de performance
bool g_highPerformanceMode = true;
bool g_ultraPerformanceMode = false; // Désactivé pour permettre l'affichage
int g_positionCheckInterval = 30; // secondes (plus fréquent pour les graphiques)
int g_graphicsUpdateInterval = 60; // secondes (1 minute pour les graphiques)
bool g_disableAllGraphics = false; // Activé pour voir le tableau de bord et les dessins

// Structure pour les décisions finales IA
struct DecisionStruct {
  string action;
  double final_confidence;
  string reasoning;
};

// Fonction d'optimisation: mettre à jour le cache des infos symbole
void UpdateSymbolCache()
{
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastSymbolCacheUpdate < SYMBOL_CACHE_INTERVAL)
      return; // Utiliser le cache existant
   
   g_cachedPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_cachedAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   g_cachedBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_cachedTickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   g_cachedTickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_cachedMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   g_cachedMaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   g_cachedLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   g_lastSymbolCacheUpdate = currentTime;
}

//+------------------------------------------------------------------+
//| Constantes pour les codes de retour trade (si non définies)      |
//+------------------------------------------------------------------+
#ifndef TRADE_RETCODE_NO_CONNECTION
#define TRADE_RETCODE_NO_CONNECTION      10006
#endif

#ifndef TRADE_RETCODE_SERVER_BUSY
#define TRADE_RETCODE_SERVER_BUSY        10007
#endif

#ifndef TRADE_RETCODE_TIMEOUT
#define TRADE_RETCODE_TIMEOUT            10008
#endif

#ifndef TRADE_RETCODE_INVALID_STOPS
#define TRADE_RETCODE_INVALID_STOPS      10012
#endif

// Inclusions des bibliothèques Windows nécessaires
#include <WinAPI\errhandlingapi.mqh>
#include <WinAPI\sysinfoapi.mqh>
#include <WinAPI\processenv.mqh>
#include <WinAPI\libloaderapi.mqh>
#include <WinAPI\memoryapi.mqh>

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\TerminalInfo.mqh>

// Inclusions des interprétations dynamiques
#include "dynamic_interpretations.mqh"

// Inclure les fonctions d'analyse avancée
// #include "advanced_analysis_functions.mq5" // Désactivé temporairement

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

// Variable globale pour la décision finale
FinalDecisionData g_finalDecision;

// Couleurs atténuées pour meilleure lisibilité (moins vives)
#define MUTED_LIME    (color)C'70,140,70'
#define MUTED_RED     (color)C'160,80,80'
#define MUTED_YELLOW  (color)C'180,160,70'
#define MUTED_ORANGE  (color)C'180,120,60'
#define MUTED_GREEN   (color)C'60,120,60'
#define MUTED_BLUE    (color)C'70,100,140'
#define MUTED_PURPLE  (color)C'100,80,120'
#define MUTED_CYAN    (color)C'70,140,140'
#define MUTED_WHITE   (color)C'200,200,200'
#define TEXT_LABEL_COLOR  clrWhite
#define TEXT_FONT_SIZE    11
#define TEXT_FONT_SIZE_SM 10

// Variables globales pour le dashboard
AISignalData g_aiSignal;
TrendAlignmentData g_trendAlignment;
CoherentAnalysisData g_coherentAnalysis;

// Variables globales pour Machine Learning
struct MLRecommendationData
{
   string recommendation;      // BUY/SELL/HOLD
   double confidence;          // Confiance 0-1
   double accuracy;            // Accuracy du modèle
   double f1_score;           // F1 score du modèle
   int models_trained;        // Nombre de modèles entraînés
   string key_features;       // Features importantes
   bool is_valid;            // Validité de la prédiction
};
MLRecommendationData g_mlRecommendation;

// Prédictions de swing points ML
struct SwingPointPrediction
{
   datetime time;             // Timestamp du swing point
   double price;             // Prix du swing point
   bool is_high;            // True = swing high, False = swing low
   double confidence;         // Confiance de la prédiction ML
   int future_bars;         // Nombre de bougies dans le futur
};
SwingPointPrediction g_swingPredictions[];  // Tableau des prédictions de swing points

// Prédictions de trendlines et supports/résistances ML
struct TrendLinePrediction
{
   datetime start_time;       // Timestamp de début
   double start_price;       // Prix de début
   datetime end_time;         // Timestamp de fin
   double end_price;         // Prix de fin
   double slope;             // Pente de la trendline
   double confidence;         // Confiance de la prédiction ML
   string type;             // "support", "resistance", "trendline"
   color line_color;         // Couleur de la ligne
   int width;               // Largeur de la ligne
   int style;               // Style de la ligne
};
TrendLinePrediction g_trendLinePredictions[];  // Tableau des prédictions de trendlines

// Variables globales FVG_Kill intégrées
int fvg_ema50H, fvg_ema200H, fvg_atrH, fvg_fractalH;
bool fvg_IsBoom, fvg_IsCrash;
bool fvg_UseFVGKill = true;

// Variables globales pour la stabilité anti-détachement
datetime g_lastHeartbeat = 0;
int g_reconnectAttempts = 0;
const int MAX_RECONNECT_ATTEMPTS = 5;
bool g_isStable = true;

//+------------------------------------------------------------------+
//| DÉCLARATIONS DES FONCTIONS                                         |
//+------------------------------------------------------------------+
void UpdateAdvancedDashboard();
void CleanupDashboard();
void CleanupDashboardLabels();
void ResetDailyCounters();
void ResetDailyCountersIfNeeded();
void CleanAllGraphicalObjects();
void CalculateLocalTrends();
void CalculateLocalCoherence();
void DrawEMAOnAllTimeframes();
void ExecuteOrderLogic();
void ExecuteMarketOrder(string direction);
void ExecuteLimitOrder(string direction);
void ExecuteAutoLimitOrder();
void CalculateSupportResistance(double &support, double &resistance);
void CalculateSLTP(string direction, double entryPrice, double &stopLoss, double &takeProfit);
void DrawEMAOnTimeframe(ENUM_TIMEFRAMES tf, int handle, string name, color clr, int width);
bool GetAISignalData();

// Fonctions Boom/Crash manquantes - ajoutées pour corriger les erreurs de compilation
bool IsDerivArrowPresent();
bool HasStrongSignal();
void ExecuteTrade(ENUM_ORDER_TYPE signalType, double entryPrice = 0);
string GenerateLocalFallbackTrend();
string GenerateLocalFallbackAnalysis();
string GenerateLocalFallbackPrediction();
string GenerateLocalFallbackCoherent();
void UpdateAllGraphics();

// Nouvelles fonctions pour détection de spikes Boom/Crash
bool DetectExtremeSpike();
bool AnalyzeSuddenMomentum();
bool CheckPreSpikePatterns();
void CalculateSpikePrediction();
bool GetTrendAlignmentData();
bool GetCoherentAnalysisData();
bool GetMLRecommendationData();
bool GetMLSwingPointPredictions();
bool GetMLTrendLinePredictions();
void DrawMLSwingPointPredictions();
void DrawMLTrendLines();
void CalculateFinalDecision();
void CalculateOptimalEntryLevels();

double CalculateOptimalLotSize();
void ManagePositionDuplication();
void DuplicatePosition(ulong originalTicket);
void InitializePositionTracker();
void UpdatePositionTracker();

// Fonctions FVG_Kill intégrées
void FVG_InitializeIndicators();
bool FVG_IsKillZone();
bool FVG_DetectLiquiditySweep(string direction);
bool FVG_IsBoomCrashMode();
bool FVG_ShouldTrade(string direction);
void FVG_ExecuteBuyWithAI();
void FVG_ExecuteSellWithAI();
void FVG_ManageTrailingStructure();
bool FVG_SendOrderWithVolume(string orderType, double volume, double stopLoss, double takeProfit);

//+------------------------------------------------------------------+
// Nouvelles fonctions d'analyse technique avancée
//+------------------------------------------------------------------+
void DrawEMACurves()
{
   if(!ShowDashboard) return;
   // Limiter à 12 segments pour réduire la charge MT5 (au lieu de 50)
   const int maxSegments = 12;
   const int step = 4;  // un point tous les 4 bars
   double emaFast[];
   ArraySetAsSeries(emaFast, true);
   if(CopyBuffer(emaFastHandle, 0, 0, 50, emaFast) <= 0) return;
   color curveColor = UseMutedColors ? MUTED_LIME : clrLime;
   for(int idx = 0, i = 49; i >= 0 && idx < maxSegments; i -= step, idx++)
   {
      datetime time[];
      ArraySetAsSeries(time, true);
      if(CopyTime(_Symbol, PERIOD_M1, i, 1, time) > 0)
      {
         string curveName = "EMA_Fast_Curve_" + IntegerToString(idx);
         ObjectCreate(0, curveName, OBJ_TREND, 0, time[0], emaFast[i]);
         ObjectSetInteger(0, curveName, OBJPROP_COLOR, curveColor);
         ObjectSetInteger(0, curveName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, curveName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, curveName, OBJPROP_RAY_RIGHT, false);
      }
   }
}

void DrawFibonacciRetracements() 
{
   if(!ShowDashboard) return;
   
   double high[], low[];
   datetime time[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   
   ENUM_TIMEFRAMES tf = PERIOD_H1;
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 50, high) <= 0 || 
      CopyLow(_Symbol, PERIOD_H1, 0, 50, low) <= 0 ||
      CopyTime(_Symbol, PERIOD_H1, 0, 50, time) <= 0)
   {
      tf = _Period;
      int n = MathMin(50, Bars(_Symbol, tf));
      if(n < 10 || CopyHigh(_Symbol, tf, 0, n, high) <= 0 || 
         CopyLow(_Symbol, tf, 0, n, low) <= 0 ||
         CopyTime(_Symbol, tf, 0, n, time) <= 0)
         return;
   }
   
   int cnt = ArraySize(high);
   if(cnt < 5) return;
   // Trouver le plus haut et le plus bas sur la période
   int highestBar = ArrayMaximum(high, 0, cnt);
   int lowestBar = ArrayMinimum(low, 0, cnt);
   
   if(highestBar >= 0 && lowestBar >= 0)
   {
      double highestPrice = high[highestBar];
      double lowestPrice = low[lowestBar];
      datetime highestTime = time[highestBar];
      datetime lowestTime = time[lowestBar];
      
      // Dessiner les niveaux Fibonacci
      double fibLevels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
      color fibColors[7];
      fibColors[0] = UseMutedColors ? MUTED_BLUE : clrBlue;
      fibColors[1] = UseMutedColors ? MUTED_BLUE : clrDodgerBlue;
      fibColors[2] = clrAqua;
      fibColors[3] = UseMutedColors ? MUTED_YELLOW : clrYellow;
      fibColors[4] = UseMutedColors ? MUTED_ORANGE : clrOrange;
      fibColors[5] = UseMutedColors ? MUTED_RED : clrRed;
      fibColors[6] = UseMutedColors ? MUTED_PURPLE : clrMagenta;
      
      for(int i = 0; i < ArraySize(fibLevels); i++)
      {
         double levelPrice = lowestPrice + (highestPrice - lowestPrice) * fibLevels[i];
         string fibName = "FIB_" + DoubleToString(fibLevels[i], 3);
         
         ObjectCreate(0, fibName, OBJ_HLINE, 0, 0, levelPrice);
         ObjectSetInteger(0, fibName, OBJPROP_COLOR, fibColors[i]);
         ObjectSetInteger(0, fibName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, fibName, OBJPROP_WIDTH, 1);
         ObjectSetString(0, fibName, OBJPROP_TOOLTIP, "Fibo " + DoubleToString(fibLevels[i]*100, 1) + "%");
      }
   }
}

void DrawLiquiditySquid() 
{
   if(!ShowDashboard) return;
   
   // Identifier les zones de liquidité basées sur les highs/lows récents
   double high[], low[];
   datetime time[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   
   if(CopyHigh(_Symbol, PERIOD_M15, 0, 100, high) <= 0 || 
      CopyLow(_Symbol, PERIOD_M15, 0, 100, low) <= 0 ||
      CopyTime(_Symbol, PERIOD_M15, 0, 100, time) <= 0)
      return;
   
   // Identifier les zones de concentration de liquidité (limité à 8 objets max pour réduire charge CPU)
   int maxLiquidityZones = 8;
   int liquidityCount = 0;
   for(int i = 10; i < 90 && liquidityCount < maxLiquidityZones; i += 30) // Sauter plus de bougies (30 au lieu de 20)
   {
      double zoneHigh = high[ArrayMaximum(high, i, 20)];
      double zoneLow = low[ArrayMinimum(low, i, 20)];
      datetime zoneTime = time[i + 10];
      
      if(zoneHigh - zoneLow > g_cachedPoint * 5) // Zone significative
      {
         string squidName = "LIQUIDITY_" + IntegerToString(i);
         
         ObjectCreate(0, squidName, OBJ_RECTANGLE, 0, 
                   zoneTime, zoneLow, 
                   time[i], zoneHigh);
         ObjectSetInteger(0, squidName, OBJPROP_COLOR, UseMutedColors ? MUTED_PURPLE : clrPurple);
         ObjectSetInteger(0, squidName, OBJPROP_BACK, true);
         ObjectSetInteger(0, squidName, OBJPROP_FILL, false); // PAS DE REMPLISSAGE
         ObjectSetInteger(0, squidName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, squidName, OBJPROP_WIDTH, 1);
         liquidityCount++;
      }
   }
}
void DrawFVG() 
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 100;
   ENUM_TIMEFRAMES tf = PERIOD_M5;
   if(CopyRates(_Symbol, PERIOD_M5, 0, bars, rates) < bars)
   {
      tf = _Period;
      bars = MathMin(100, Bars(_Symbol, tf));
      if(CopyRates(_Symbol, tf, 0, bars, rates) < bars)
         return;
   }
   
   // Parcourir les bougies pour identifier les Fair Value Gaps (limité à 20 objets max pour réduire charge CPU)
   int maxFVG = 20;
   int fvgCount = 0;
   for(int i = 2; i < bars - 2 && fvgCount < maxFVG; i += 2) // Sauter une bougie sur deux
   {
      // FVG Bullish: Bougie haussière avec un gap entre le haut de la bougie i-1 et le bas de la bougie i+1
      if(rates[i].close > rates[i].open && // Bougie i haussière
         rates[i+1].high < rates[i-1].low) // Gap entre haut i+1 et bas i-1
      {
         double fvgTop = rates[i+1].high;
         double fvgBottom = rates[i-1].low;
         datetime time1 = rates[i+1].time;
         datetime time2 = TimeCurrent() + PeriodSeconds(tf) * 30;
         
         string fvgName = "FVG_Bull_" + _Symbol + "_" + IntegerToString(i);
         
         if(ObjectFind(0, fvgName) < 0)
            ObjectCreate(0, fvgName, OBJ_RECTANGLE, 0, time1, fvgBottom, time2, fvgTop);
         else
         {
            ObjectSetInteger(0, fvgName, OBJPROP_TIME, 0, time1);
            ObjectSetDouble(0, fvgName, OBJPROP_PRICE, 0, fvgTop);
            ObjectSetInteger(0, fvgName, OBJPROP_TIME, 1, time2);
            ObjectSetDouble(0, fvgName, OBJPROP_PRICE, 1, fvgBottom);
         }
         
         ObjectSetInteger(0, fvgName, OBJPROP_COLOR, UseMutedColors ? MUTED_GREEN : clrGreen);
         ObjectSetInteger(0, fvgName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, fvgName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, fvgName, OBJPROP_BACK, 0);
         ObjectSetInteger(0, fvgName, OBJPROP_FILL, 0); // PAS DE REMPLISSAGE
         fvgCount++;
      }
      
      // FVG Bearish: Bougie baissière avec un gap entre le bas de la bougie i-1 et le haut de la bougie i+1
      if(rates[i].close < rates[i].open && // Bougie i baissière
         rates[i+1].low > rates[i-1].high) // Gap entre bas i+1 et haut i-1
      {
         double fvgTop = rates[i-1].high;
         double fvgBottom = rates[i+1].low;
         datetime time1 = rates[i+1].time;
         datetime time2 = TimeCurrent() + PeriodSeconds(tf) * 30;
         
         string fvgName = "FVG_Bear_" + _Symbol + "_" + IntegerToString(i);
         
         if(ObjectFind(0, fvgName) < 0)
            ObjectCreate(0, fvgName, OBJ_RECTANGLE, 0, time1, fvgBottom, time2, fvgTop);
         else
         {
            ObjectSetInteger(0, fvgName, OBJPROP_TIME, 0, time1);
            ObjectSetDouble(0, fvgName, OBJPROP_PRICE, 0, fvgTop);
            ObjectSetInteger(0, fvgName, OBJPROP_TIME, 1, time2);
            ObjectSetDouble(0, fvgName, OBJPROP_PRICE, 1, fvgBottom);
         }
         
         ObjectSetInteger(0, fvgName, OBJPROP_COLOR, UseMutedColors ? MUTED_RED : clrRed);
         ObjectSetInteger(0, fvgName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, fvgName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, fvgName, OBJPROP_BACK, 0);
         ObjectSetInteger(0, fvgName, OBJPROP_FILL, 0); // PAS DE REMPLISSAGE
         fvgCount++;
      }
   }
}
void DrawOrderBlocks() 
{
   // Récupérer les données de prix récentes pour identifier les Order Blocks
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 100; // Analyser les 100 dernières bougies
   
   if(CopyRates(_Symbol, PERIOD_M5, 0, bars, rates) < bars)
      return;
   
   // Parcourir les bougies pour identifier les Order Blocks
   for(int i = 3; i < bars - 3; i++)
   {
      // Order Block Bullish: Bougie baissière forte suivie d'un renversement haussier
      if(rates[i].close < rates[i].open && // Bougie i baissière
         rates[i-1].close < rates[i-1].open && // Bougie précédente aussi baissière
         rates[i+1].close > rates[i+1].open && // Bougie suivante haussière
         rates[i+2].close > rates[i+2].open) // Bougie i+2 aussi haussière
      {
         // Vérifier si le prix a fortement rebondi après cette bougie
         double moveSize = (rates[i+1].high - rates[i].low) / g_cachedPoint;
         if(moveSize > 20) // Mouvement significatif (>20 pips)
         {
            datetime time1 = rates[i].time;
            datetime time2 = TimeCurrent() + PeriodSeconds(PERIOD_M5) * 40; // Étendre 40 bougies vers le futur
            
            string obName = "OB_Bull_" + _Symbol + "_" + IntegerToString(i);
            
            if(ObjectFind(0, obName) < 0)
               ObjectCreate(0, obName, OBJ_RECTANGLE, 0, time1, rates[i].low, time2, rates[i].high);
            else
            {
               ObjectSetInteger(0, obName, OBJPROP_TIME, 0, time1);
               ObjectSetDouble(0, obName, OBJPROP_PRICE, 0, rates[i].high);
               ObjectSetInteger(0, obName, OBJPROP_TIME, 1, time2);
               ObjectSetDouble(0, obName, OBJPROP_PRICE, 1, rates[i].low);
            }
            
            ObjectSetInteger(0, obName, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, obName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, obName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, obName, OBJPROP_BACK, 1);
            ObjectSetInteger(0, obName, OBJPROP_FILL, 0); // PAS DE REMPLISSAGE
         }
      }
      
      // Order Block Bearish: Bougie haussière forte suivie d'un renversement baissier
      if(rates[i].close > rates[i].open && // Bougie i haussière
         rates[i-1].close > rates[i-1].open && // Bougie précédente aussi haussière
         rates[i+1].close < rates[i+1].open && // Bougie suivante baissière
         rates[i+2].close < rates[i+2].open) // Bougie i+2 aussi baissière
      {
         // Vérifier si le prix a fortement baissé après cette bougie
         double moveSize = (rates[i].high - rates[i+1].low) / g_cachedPoint;
         if(moveSize > 20) // Mouvement significatif (>20 pips)
         {
            datetime time1 = rates[i].time;
            datetime time2 = TimeCurrent() + PeriodSeconds(PERIOD_M5) * 40; // Étendre 40 bougies vers le futur
            
            string obName = "OB_Bear_" + _Symbol + "_" + IntegerToString(i);
            
            if(ObjectFind(0, obName) < 0)
               ObjectCreate(0, obName, OBJ_RECTANGLE, 0, time1, rates[i].low, time2, rates[i].high);
            else
            {
               ObjectSetInteger(0, obName, OBJPROP_TIME, 0, time1);
               ObjectSetDouble(0, obName, OBJPROP_PRICE, 0, rates[i].high);
               ObjectSetInteger(0, obName, OBJPROP_TIME, 1, time2);
               ObjectSetDouble(0, obName, OBJPROP_PRICE, 1, rates[i].low);
            }
            
            ObjectSetInteger(0, obName, OBJPROP_COLOR, clrCrimson);
            ObjectSetInteger(0, obName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, obName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, obName, OBJPROP_BACK, 1);
            ObjectSetInteger(0, obName, OBJPROP_FILL, 0); // PAS DE REMPLISSAGE
         }
      }
   }
}

// Fonctions de stabilité anti-détachement
void CheckRobotStability()
{
   datetime currentTime = TimeCurrent();
   
   // Heartbeat toutes les 30 secondes
   if(currentTime - g_lastHeartbeat > 30)
   {
      g_lastHeartbeat = currentTime;
      
      // Vérifier si le robot est toujours attaché
      if(TerminalInfoInteger(TERMINAL_CONNECTED))
      {
         Print("💓 HEARTBEAT: Robot stable - ", TimeToString(currentTime));
         g_reconnectAttempts = 0;
         g_isStable = true;
      }
      else
      {
         Print("⚠️ CONNEXION PERDUE: Tentative de reconnexion...");
         g_isStable = false;
      }
   }
}

void AutoRecoverySystem()
{
   if(!g_isStable && g_reconnectAttempts < MAX_RECONNECT_ATTEMPTS)
   {
      g_reconnectAttempts++;
      
      Print("🔄 TENTATIVE DE RÉCUPÉRATION #", g_reconnectAttempts, "/", MAX_RECONNECT_ATTEMPTS);
      
      // Pause de 5 secondes entre tentatives
      Sleep(5000);
      
      // Vérifier si la récupération a réussi
      if(TerminalInfoInteger(TERMINAL_CONNECTED))
      {
         Print("✅ RÉCUPÉRATION RÉUSSIE: Robot reconnecté !");
         g_isStable = true;
         g_reconnectAttempts = 0;
      }
   }
   else if(g_reconnectAttempts >= MAX_RECONNECT_ATTEMPTS)
   {
      Print("❌ ÉCHEC DE RÉCUPÉRATION: Arrêt du robot pour éviter les dommages");
      ExpertRemove(); // Détacher proprement
   }
}

// Fonction utilitaire pour vérifier l'existence d'une position
bool PositionExists(ulong ticket)
{
   if(ticket == 0) return false;
   
   // Parcourir toutes les positions pour trouver le ticket
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) == ticket)
      {
         return PositionSelectByTicket(ticket);
      }
   }
   return false;
}
string ExtractJSONValue(string json, string key);

//+------------------------------------------------------------------+
//| Paramètres d'entrée                                              |
//+------------------------------------------------------------------+
input group "--- CONFIGURATION DE BASE ---"
input int    InpMagicNumber     = 888888;  // Magic Number
input double InitialLotSize     = 0.01;    // Taille de lot initiale
input double MaxLotSize          = 1.0;     // Taille de lot maximale
input double TakeProfitUSD       = 15.0;    // Take Profit en USD (fixe) - augmenté de 50 points
input double StopLossUSD         = 5.0;     // Stop Loss en USD - perte admise (laisser le prix bouger normalement)
input double MaxLossPerPosition  = 5.0;     // Perte maximale par position (USD) - maintenu à 5$
input double ProfitThresholdForDouble = 0.5; // Seuil de profit (USD) pour doubler le lot
input int    MinPositionLifetimeSec = 5;    // Délai minimum avant modification (secondes)

input group "--- OPTIMISATION PERFORMANCE ---"
input bool   HighPerformanceMode = true; // Mode haute performance (réduit charge CPU)
input bool   UltraPerformanceMode = false; // Mode ultra performance - DÉSACTIVÉ pour voir les données IA
input int    PositionCheckInterval = 600; // Intervalle vérification positions (secondes) - 10 minutes pour charge minimale absolue
input int    GraphicsUpdateInterval = 60;  // Intervalle mise à jour graphiques (secondes) - 1 minute pour voir le dashboard
input bool   DisableAllGraphics = false; // Désactiver tous les graphiques - RÉACTIVÉ pour voir le dashboard
input bool   ShowInfoOnChart = true; // Afficher les infos IA directement sur le graphique - RÉACTIVÉ pour voir les prédictions
input bool   UseMutedColors = true;   // Couleurs atténuées pour mieux lire les infos sur le graphique
input bool   DisableNotifications = true; // Désactiver les notifications (réduction du bruit) - ACTIVÉ par défaut

input group "--- AI AGENT ---"
input bool   UseAI_Agent        = true;    // Activer l'agent IA (via serveur externe)
input string AI_ServerURL       = "http://localhost:8000/decision"; // URL serveur IA - FORCAGE LOCAL
input string AI_LocalServerURL  = "http://localhost:8000/decision"; // URL serveur IA local (fallback)
input bool   UseLocalFallback   = true;    // Activer fallback vers serveur local si Render échoue
input bool   UseAdvancedDecisionGemma = false; // Utiliser endpoint decisionGemma (Gemma+Gemini) avec analyse visuelle
input int    AI_Timeout_ms       = 800;     // Timeout WebRequest en millisecondes
input double AI_MinConfidence    = 0.75;    // Confiance minimale IA pour trader (75% - réduction du bruit)
// NOTE: Le serveur IA garantit maintenant 60% minimum si H1 aligné, 70% si H1+H4/D1
// Pour Boom/Crash, le seuil est automatiquement abaissé à 45% dans le code
// pour les tendances fortes (H4/D1 alignés). Le serveur ajoute automatiquement
// des bonus (+25% pour H4+D1 alignés, +10-20% pour alignement multi-TF)
input int    AI_UpdateInterval   = 60;     // Intervalle de mise à jour IA (secondes) - fortement réduit
input int    AI_AnalysisIntervalSec = 180;  // Fréquence de rafraîchissement de l'analyse (secondes) - fortement réduit
input int    GlobalTradeCooldownMinutes = 5; // Cooldown global entre tous les trades (anti-bruit)
input string AI_TimeWindowsURLBase = "https://kolatradebot.onrender.com"; // Racine API pour /time_windows
input string AI_AnalysisURL = "https://kolatradebot.onrender.com/analysis";
input string AI_LocalAnalysisURL = "http://localhost:8000/analysis";
input string TrendAPIURL = "https://kolatradebot.onrender.com/trend";
input string TrendLocalURL = "http://localhost:8000/trend";
input string AI_PredictSymbolURL = "https://kolatradebot.onrender.com/predict";
input string AI_LocalPredictURL = "http://localhost:8000/predict";
input string AI_CoherentAnalysisURL = "https://kolatradebot.onrender.com/coherent-analysis";
input string AI_LocalCoherentURL = "http://localhost:8000/coherent-analysis";
input string AI_MLPredictURL = "https://kolatradebot.onrender.com/ml/predict";
input string AI_LocalMLURL = "http://localhost:8001/ml/predict";
input bool UseAllEndpoints = true;
input double MinEndpointsConfidence = 0.30;

input group "--- TABLEAU DE BORD IA ---"
input bool   ShowDashboard = true; // Afficher le tableau de bord IA - RÉACTIVÉ pour voir les prédictions
input color  DashboardBGColor = clrBlack; // Couleur de fond du dashboard
input color  TextColor = clrWhite;       // Couleur du texte

input group "--- INTEGRATION IA AVANCÉE ---"
input bool UseAdvancedValidation = true;        // Activer validation multi-couches pour les trades IA
input bool RequireAllEndpointsAlignment = false;   // Exiger alignement de TOUS les endpoints IA avant trading
input double MinAllEndpointsConfidence = 0.70; // Confiance minimale pour alignement de tous les endpoints
input bool UseDynamicTPCalculation = true;      // Calculer TP dynamique au prochain Support/Résistance
input bool UseImmediatePredictionCheck = true;    // Vérifier direction immédiate de la prédiction avant trade
input bool UseStrongReversalValidation = true; // Exiger retournement franc après touche EMA/Support/Résistance

input group "--- INTEGRATION MACHINE LEARNING ---"
input bool UseMLIntegration = true;             // Intégrer les prédictions ML dans les décisions de trading
input bool ShowMLRecommendations = true;        // Afficher les recommandations ML sur le graphique
input bool UseMLForFinalDecision = true;        // Utiliser ML comme facteur décisif dans la décision finale
input double MLDecisionWeight = 0.35;           // Poids des prédictions ML dans la décision finale (35%)
input bool ShowMLMetricsOnChart = true;         // Afficher les métriques ML (accuracy, F1) sur le graphique

input group "--- EXECUTION & SEUILS (RECOMMANDÉ) ---"
input bool   AllowTradingWhenNotificationsDisabled = true; // Si true: désactiver notifs ne bloque plus le trading
input double AI_MinConfidence_Default = 0.55;  // Seuil par défaut - BAISÉ pour permettre le trading
input double MinConfidenceToEvaluate = 0.38;  // Confiance min pour évaluer un trade (38% - était 50% en dur)
input double MinAIConfidenceForLimitOrder = 0.55;  // Confiance IA min pour ordre limite auto (55% - était 70%)
input double AI_MinConfidence_Volatility = 0.55; // Volatility - BAISÉ pour permettre le trading
input double AI_MinConfidence_Forex = 0.80;    // Forex: seuil plus élevé
input double AI_MinConfidence_Cautious = 0.85; // Mode prudent (perte quotidienne élevée)
input double AI_MarketExecutionConfidence = 0.95; // Si signal très fort: exécution marché possible (hors Boom/Crash)
input int    LimitEntryOffsetPoints = 5;       // BUY LIMIT au-dessus support / SELL LIMIT sous résistance
input int    LimitSLOffsetPoints = 10;         // SL sous support / au-dessus résistance
input double LimitRR = 2.0;                    // TP = RR * risque

input group "--- VISUEL PRÉDICTIONS (PLUS RÉALISTE) ---"
input bool   UseHistoricalCandleProfile = true; // Bougies futures calquées sur l'historique récent - ACTIVÉ pour voir les prédictions
input int    CandleProfileLookback = 120;       // Nombre de bougies historiques pour calibrer (TF courant)
input double PredictionMaxDriftATR = 1.2;       // Drift max (en ATR) sur l'horizon dessiné

input group "--- ÉLÉMENTS GRAPHIQUES ---"
input bool   DrawAIZonesEnabled  = true;    // Dessiner les zones BUY/SELL de l'IA - ACTIVÉ pour voir le canal de prédiction
input bool   DrawSupportResistance = false;  // Dessiner support/résistance M5/H1 - DÉSACTIVÉ pour performance
input bool   DrawTrendlinesEnabled = false;    // Dessiner les trendlines - DÉSACTIVÉ pour performance
input bool   DrawDerivPatterns   = false;    // Dessiner les patterns Deriv - DÉSACTIVÉ pour performance
input bool   DrawSMCZones        = false;    // Dessiner les zones SMC/OrderBlock - DÉSACTIVÉ pour performance

input group "--- STRATÉGIE US SESSION BREAK & RETEST (PRIORITAIRE) ---"
input bool   UseUSSessionStrategy = false;   // Activer la stratégie US Session (prioritaire) - DÉSACTIVÉ pour permettre trading normal
input double US_RiskReward        = 2.0;    // Risk/Reward ratio pour US Session
input int    US_RetestTolerance   = 30;     // Tolérance retest en points
input bool   US_OneTradePerDay    = true;   // Un seul trade par jour pour US Session

input group "--- GESTION DES RISQUES ---"
input double MaxDailyLoss        = 100.0;   // Perte quotidienne maximale (USD)
input double MaxDailyProfit      = 200.0;   // Profit quotidien maximale (USD)
input double MaxTotalLoss        = 4.0;     // Perte totale maximale toutes positions (USD)
input bool   UseTrailingStop     = true;   // Utiliser trailing stop (ACTIVÉ pour sécuriser les profits)

input group "--- STRATÉGIE FVG_KILL INTÉGRÉE ---"
input bool   UseFVGKillStrategy = true;      // Activer la stratégie FVG_Kill
input bool   UseFVGKillSessions = true;     // Activer les sessions FVG_Kill
input bool   UseFVGKillLiquiditySweep = true; // Activer détection liquidity sweep FVG
input bool   UseFVGKillTrailing = true;   // Activer trailing structure FVG
input bool   UseFVGKillBoomCrashMode = true; // Activer mode Boom/Crash FVG
input ENUM_TIMEFRAMES FVG_HTF = PERIOD_H4; // Timeframe haute FVG_Kill
input ENUM_TIMEFRAMES FVG_LTF = PERIOD_M15; // Timeframe basse FVG_Kill
input int    FVG_EMA50 = 50;               // EMA 50 FVG_Kill
input int    FVG_EMA200 = 200;             // EMA 200 FVG_Kill
input int    FVG_ATR_Period = 14;          // Période ATR FVG_Kill
input double FVG_ATR_Mult = 1.8;           // Multiplicateur ATR FVG_Kill
input int    FVG_MaxPositions = 3;           // Positions maximales FVG_Kill
input int    FVG_LondonStart = 8;            // Début session London FVG
input int    FVG_LondonEnd = 11;             // Fin session London FVG
input int    FVG_NYStart = 13;               // Début session NY FVG
input int    FVG_NYEnd = 16;                 // Fin session NY FVG

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
input double TrendAPIMinConfidence = 85.0;  // Confiance minimum API pour validation (85% - réduction du bruit)

input group "--- DEBUG ---"
input bool   DebugMode           = false;    // Mode debug (logs détaillés) - DÉSACTIVÉ pour réduire le bruit

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
int macdHandle;
int stochHandle;

// Variables pour les endpoints Render
static string g_lastAnalysisData = "";
static string g_lastTrendData = "";
static string g_lastPredictionData = "";
static string g_lastCoherentData = "";
static double g_endpointsAlignment = 0.0;
static datetime g_lastEndpointUpdate = 0;

// Variable pour suivre la dernière direction de prédiction utilisée
static string g_lastExecutedDirection = "";
static int g_lastAISource = 0; // 0 = Local, 1 = Render

// Variables pour le tableau de bord
string g_dashboardName = "AI_Trading_Dashboard_";
string g_alignmentStatus[4]; // Statut de chaque endpoint
color g_alignmentColors[4];  // Couleurs pour chaque indicateur
string g_endpointNames[4] = {"Analyse", "Trend", "Prediction", "Coherent"};

// Cache pour les données de position (optimisation OnTick)
static datetime lastPositionCheck = 0;
static bool cachedHasPosition = false;
static int cachedPositionCount = 0;

// Variables pour les tableaux de chaînes
string tfNames[];

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

// Fonctions cache performance
double GetCachedPoint();
double GetCachedAsk();
double GetCachedBid();
void   UpdateSymbolCache();
bool   GetCachedHasPosition();
int    GetCachedPositionCount();

// Fonctions universelles SL/TP (solution professionnelle)
bool   CalculateSLTP(ENUM_ORDER_TYPE orderType, double &sl, double &tp, int extraPoints);
void   OpenBuyBoomCrash(double lot, string comment);
void   OpenSellBoomCrash(double lot, string comment);

// Variables pour suivre les ordres déjà exécutés (anti-doublon)
static string g_executedOrdersSymbols = ""; // Liste des symboles avec ordres déjà exécutés
static datetime g_lastOrderExecutionTime = 0;
static datetime g_lastGlobalTradeTime = 0; // Dernier trade global (pour cooldown anti-bruit)
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

//+------------------------------------------------------------------+
//| Cache des indicateurs pour optimiser les performances          |
//+------------------------------------------------------------------+
struct IndicatorCache
{
   datetime lastUpdate;
   double emaFastM1, emaSlowM1;
   double emaFastM5, emaSlowM5;
   double emaFastH1, emaSlowH1;
   double rsiM1, atrM1;
   bool isValid;
   
   IndicatorCache() : lastUpdate(0), isValid(false) {}
   
   void Reset()
   {
      lastUpdate = 0;
      isValid = false;
   }
};

IndicatorCache g_indicatorCache;

//+------------------------------------------------------------------+
//| Fonction optimisée pour récupérer les indicateurs avec cache     |
//+------------------------------------------------------------------+
bool GetCachedIndicators()
{
   datetime currentTime = TimeCurrent();
   
   // Si le cache est valide et récent (moins de 15 secondes au lieu de 5)
   if(g_indicatorCache.isValid && (currentTime - g_indicatorCache.lastUpdate) < 15)
      return true;
   
   // Récupérer les valeurs depuis MT5
   double emaFastM1[1], emaSlowM1[1], emaFastM5[1], emaSlowM5[1];
   double emaFastH1[1], emaSlowH1[1], rsiM1[1], atrM1[1];
   
   bool success = true;
   success &= (CopyBuffer(emaFastHandle, 0, 0, 1, emaFastM1) > 0);
   success &= (CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlowM1) > 0);
   success &= (CopyBuffer(emaFastM5Handle, 0, 0, 1, emaFastM5) > 0);
   success &= (CopyBuffer(emaSlowM5Handle, 0, 0, 1, emaSlowM5) > 0);
   success &= (CopyBuffer(emaFastH1Handle, 0, 0, 1, emaFastH1) > 0);
   success &= (CopyBuffer(emaSlowH1Handle, 0, 0, 1, emaSlowH1) > 0);
   success &= (CopyBuffer(rsiHandle, 0, 0, 1, rsiM1) > 0);
   success &= (CopyBuffer(atrHandle, 0, 0, 1, atrM1) > 0);
   
   if(success)
   {
      g_indicatorCache.emaFastM1 = emaFastM1[0];
      g_indicatorCache.emaSlowM1 = emaSlowM1[0];
      g_indicatorCache.emaFastM5 = emaFastM5[0];
      g_indicatorCache.emaSlowM5 = emaSlowM5[0];
      g_indicatorCache.emaFastH1 = emaFastH1[0];
      g_indicatorCache.emaSlowH1 = emaSlowH1[0];
      g_indicatorCache.rsiM1 = rsiM1[0];
      g_indicatorCache.atrM1 = atrM1[0];
      g_indicatorCache.lastUpdate = currentTime;
      g_indicatorCache.isValid = true;
   }
   
   return success;
}

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

// Variables pour la détection de corrections de prix
static bool g_isPriceInCorrection = false;
static datetime g_lastCorrectionCheck = 0;
static double g_trendDirection = 0; // 1=uptrend, -1=downtrend, 0=neutral
static double g_correctionStrength = 0.0; // Force de la correction (0-100%)

// Variables pour le système de prédiction de spikes Boom/Crash
static bool g_spikePredicted = false;
static datetime g_spikePredictionTime = 0;
static string g_spikeArrowName = "";
static bool g_spikeArrowVisible = false;
static datetime g_spikeArrowBlinkTime = 0;
static int g_spikeBlinkState = 0; // 0=caché, 1=visible

// Variables pour les points clignotants sur bougies de spike
static string g_spikePointName = "";
static bool g_spikePointVisible = false;
static datetime g_spikePointBlinkTime = 0;
static int g_spikePointBlinkState = 0; // 0=caché, 1=visible
static datetime g_spikeCandleTime = 0; // Temps de la bougie où le spike a été détecté
static ENUM_ORDER_TYPE g_spikeDirection = WRONG_VALUE; // Direction du spike

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
void ValidateAndAdjustStops(double price, double &stopLoss, double &takeProfit, int orderType);
void CleanOldGraphicalObjects();
void DrawAIConfidenceAndTrendSummary();
void DrawRenderEndpointsStatus();
void DrawLongTrendEMA();
void DeleteEMAObjects(string prefix);
void DrawEMACurveOptimized(string prefix, double &values[], datetime &times[], int count, color clr, int width, int step);
void DrawAIZonesOnChart();
void DrawFVG();
void DrawSupportResistanceLevels();
void DrawTrendlinesOnChart();
void DrawSMCZonesOnChart();
void DeleteSMCZones();
void DrawPredictionsOnChart(string predictionData);
void CheckAndManagePositions();

//+------------------------------------------------------------------+
//| Fonctions universelles SL/TP (implémentation)                     |
//+------------------------------------------------------------------+
void OpenBuyBoomCrash(double lot, string comment)
{
   // EXÉCUTION SANS SL/TP - Boom/Crash sans stops
   if(trade.Buy(lot, _Symbol, 0, 0, 0, comment))
   {
      MarkGlobalTradeExecuted(); // Cooldown anti-bruit
      Print("✅ BUY Boom/Crash exécuté SANS SL/TP - Lot: ", lot);
   }
   else
   {
      Print("❌ Échec BUY Boom/Crash - Vérifiez les logs MT5 pour les détails");
   }
}

//+------------------------------------------------------------------+
void OpenSellBoomCrash(double lot, string comment)
{
   // EXÉCUTION SANS SL/TP - Boom/Crash sans stops
   if(trade.Sell(lot, _Symbol, 0, 0, 0, comment))
   {
      MarkGlobalTradeExecuted(); // Cooldown anti-bruit
      Print("✅ SELL Boom/Crash exécuté SANS SL/TP - Lot: ", lot);
   }
   else
   {
      Print("❌ Échec SELL Boom/Crash - Vérifiez les logs MT5 pour les détails");
   }
}
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

// Nouvelles fonctions de détection et prédiction
bool DetectPriceCorrection();
bool IsPriceInCorrection();
void UpdateSpikePrediction();
void DrawSpikePredictionArrow();
void HideSpikePredictionArrow();
bool PredictBoomCrashSpike();

// Nouvelles fonctions pour points clignotants sur bougies de spike
void DrawSpikePointOnCandle(ENUM_ORDER_TYPE direction);
void UpdateSpikePointBlink();
void HideSpikePoint();
void SendSpikeNotification(ENUM_ORDER_TYPE direction);

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
//| FONCTIONS CACHE PERFORMANCE (IMPLÉMENTATION)                    |
//+------------------------------------------------------------------+

// Obtenir Point avec cache
double GetCachedPoint()
{
   UpdateSymbolCache();
   return g_cachedPoint;
}

// Obtenir Ask avec cache
double GetCachedAsk()
{
   UpdateSymbolCache();
   return g_cachedAsk;
}

// Obtenir Bid avec cache
double GetCachedBid()
{
   UpdateSymbolCache();
   return g_cachedBid;
}

//+------------------------------------------------------------------+
//| FONCTIONS CACHE POSITION (OPTIMISATION ONTICK)                 |
//+------------------------------------------------------------------+

// Vérifier si on a une position (avec cache pour optimiser OnTick)
bool GetCachedHasPosition()
{
   datetime currentTime = TimeCurrent();
   
   // Mettre à jour le cache toutes les 2 secondes maximum
   if(currentTime - lastPositionCheck >= 2)
   {
      cachedHasPosition = (PositionsTotal() > 0);
      cachedPositionCount = PositionsTotal();
      lastPositionCheck = currentTime;
   }
   
   return cachedHasPosition;
}

// Obtenir le nombre de positions (avec cache)
int GetCachedPositionCount()
{
   GetCachedHasPosition(); // Force la mise à jour du cache si nécessaire
   return cachedPositionCount;
}

//+------------------------------------------------------------------+
//| Seuil confiance requis selon symbole & mode                       |
//+------------------------------------------------------------------+
double GetRequiredConfidenceForSymbol(const string symbol, const bool cautiousMode)
{
   if(cautiousMode)
      return AI_MinConfidence_Cautious;

   bool isBoomCrashSymbol = (StringFind(symbol, "Boom", 0) != -1 || StringFind(symbol, "Crash", 0) != -1);
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
//| DÉTECTION DE CORRECTIONS DE PRIX                                |
//+------------------------------------------------------------------+

// Détecter si le prix est en correction
bool DetectPriceCorrection()
{
   datetime currentTime = TimeCurrent();
   
   // Mettre à jour la détection toutes les 10 secondes
   if(currentTime - g_lastCorrectionCheck < 10)
      return g_isPriceInCorrection;
   
   g_lastCorrectionCheck = currentTime;
   
   // Obtenir les EMA pour déterminer la tendance
   double emaFast[1], emaSlow[1], ema50[1];
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFast) <= 0 ||
      CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlow) <= 0 ||
      CopyBuffer(ema50Handle, 0, 0, 1, ema50) <= 0)
   {
      return g_isPriceInCorrection; // Garder l'état précédent si erreur
   }
   
   double currentPrice = GetCachedBid();
   double emaFastVal = emaFast[0];
   double emaSlowVal = emaSlow[0];
   double ema50Val = ema50[0];
   
   // Déterminer la direction de la tendance principale
   if(emaFastVal > emaSlowVal && emaSlowVal > ema50Val)
   {
      g_trendDirection = 1; // Uptrend
   }
   else if(emaFastVal < emaSlowVal && emaSlowVal < ema50Val)
   {
      g_trendDirection = -1; // Downtrend
   }
   else
   {
      g_trendDirection = 0; // Neutral
   }
   
   // Détecter les signaux de correction
   bool isCorrection = false;
   double correctionStrength = 0.0;
   
   if(g_trendDirection == 1) // Uptrend - chercher correction baissière
   {
      // Le prix est sous l'EMA rapide alors que la tendance est haussière
      if(currentPrice < emaFastVal)
      {
         isCorrection = true;
         // Calculer la force de la correction
         double distanceFromEMA = (emaFastVal - currentPrice) / GetCachedPoint();
         correctionStrength = MathMin(100.0, distanceFromEMA / 10.0); // Normaliser 0-100
      }
      // EMA rapide croise sous l'EMA lente
      else if(emaFastVal < emaSlowVal)
      {
         isCorrection = true;
         correctionStrength = 30.0; // Correction modérée
      }
   }
   else if(g_trendDirection == -1) // Downtrend - chercher correction haussière
   {
      // Le prix est au-dessus de l'EMA rapide alors que la tendance est baissière
      if(currentPrice > emaFastVal)
      {
         isCorrection = true;
         // Calculer la force de la correction
         double distanceFromEMA = (currentPrice - emaFastVal) / GetCachedPoint();
         correctionStrength = MathMin(100.0, distanceFromEMA / 10.0);
      }
      // EMA rapide croise au-dessus de l'EMA lente
      else if(emaFastVal > emaSlowVal)
      {
         isCorrection = true;
         correctionStrength = 30.0;
      }
   }
   
   g_isPriceInCorrection = isCorrection;
   g_correctionStrength = correctionStrength;
   
   if(DebugMode && isCorrection)
   {
      Print("🔄 Correction détectée - Force: ", correctionStrength, "% - Trend: ", g_trendDirection);
   }
   
   return isCorrection;
}

// Vérifier si le prix est en correction
bool IsPriceInCorrection()
{
   return DetectPriceCorrection();
}

//+------------------------------------------------------------------+
//| SYSTÈME DE PRÉDICTION DE SPIKES BOOM/CRASH                      |
//+------------------------------------------------------------------+

// Prédire l'arrivée imminente d'un spike Boom/Crash
bool PredictBoomCrashSpike()
{
   if(!IsBoomCrashSymbol(_Symbol))
      return false;
   
   datetime currentTime = TimeCurrent();
   
   // Analyser toutes les 30 secondes
   if(currentTime - g_spikePredictionTime < 30)
      return g_spikePredicted;
   
   g_spikePredictionTime = currentTime;
   
   // Obtenir les données récentes
   double prices[10]; // 10 dernières bougies
   long volumes[10];
   if(CopyClose(_Symbol, PERIOD_M1, 1, 10, prices) < 10 ||
      CopyTickVolume(_Symbol, PERIOD_M1, 1, 10, volumes) < 10)
   {
      return false;
   }
   
   // OPTIMISATION: Cache pour les calculs de volatilité et volume
   static datetime lastVolatilityCalc = 0;
   static double cachedVolatility = 0.0;
   static double cachedAvgVolume = 0.0;
   
   if(TimeCurrent() - lastVolatilityCalc >= 5) // Recalculer toutes les 5 secondes
   {
      // Calculer la volatilité récente
      cachedVolatility = 0.0;
      for(int i = 1; i < 10; i++)
      {
         double change = MathAbs(prices[i] - prices[i-1]);
         cachedVolatility += change;
      }
      cachedVolatility /= 9.0;
      
      // Calculer le volume moyen
      cachedAvgVolume = 0.0;
      for(int i = 0; i < 10; i++)
      {
         cachedAvgVolume += (double)volumes[i];
      }
      cachedAvgVolume /= 10.0;
      
      lastVolatilityCalc = TimeCurrent();
   }
   
   double volatility = cachedVolatility;
   double avgVolume = cachedAvgVolume;
   
   // Détecter les signaux précurseurs de spike
   bool spikePredicted = false;
   double currentPrice = prices[9];
   
   // Signaux de prédiction:
   // 1. Faible volatilité prolongée (calme avant la tempête)
   bool lowVolatility = volatility < (GetCachedPoint() * 5); // Moins de 5 points de variation moyenne
   
   // 2. Volume anormalement bas
   bool lowVolume = avgVolume < 50; // Volume très faible
   
   // 3. Consolidation (prix dans une plage étroite)
   double priceRange = 0.0;
   double minPrice = prices[0], maxPrice = prices[0];
   for(int i = 0; i < 10; i++)
   {
      if(prices[i] < minPrice) minPrice = prices[i];
      if(prices[i] > maxPrice) maxPrice = prices[i];
   }
   priceRange = maxPrice - minPrice;
   bool consolidation = priceRange < (GetCachedPoint() * 10); // Moins de 10 points de range
   
   // 4. Pattern de compression (les bougies deviennent plus petites)
   bool compression = true;
   for(int i = 2; i < 10; i++)
   {
      double range = MathAbs(prices[i] - prices[i-1]);
      if(range > (GetCachedPoint() * 3)) // Si une bougie a plus de 3 points
      {
         compression = false;
         break;
      }
   }
   
   // Score de prédiction
   int predictionScore = 0;
   if(lowVolatility) predictionScore += 25;
   if(lowVolume) predictionScore += 25;
   if(consolidation) predictionScore += 25;
   if(compression) predictionScore += 25;
   
   spikePredicted = (predictionScore >= 75); // Au moins 3/4 des conditions
   
   if(spikePredicted && !g_spikePredicted)
   {
      g_spikePredicted = true;
      g_spikeArrowVisible = true;
      g_spikeArrowBlinkTime = currentTime;
      
      // Détecter la direction du spike (basé sur la tendance actuelle)
      ENUM_ORDER_TYPE spikeDirection = ORDER_TYPE_BUY; // Par défaut BOOM
      
      // Analyser la direction probable du spike
      double currentPrice = prices[9];
      double priceChange = currentPrice - prices[8]; // Changement par rapport à la bougie précédente
      
      if(priceChange < 0)
         spikeDirection = ORDER_TYPE_SELL; // CRASH
      
      // Créer le point clignotant sur la bougie
      DrawSpikePointOnCandle(spikeDirection);
      
      // Envoyer la notification
      SendSpikeNotification(spikeDirection);
      
      Print("🚨 SPIKE PREDICTED - Score: ", predictionScore, "% - Spike imminent!");
   }
   else if(!spikePredicted && g_spikePredicted)
   {
      g_spikePredicted = false;
      HideSpikePredictionArrow();
      HideSpikePoint(); // Cacher le point aussi
   }
   
   return spikePredicted;
}

// Dessiner la flèche de prédiction de spike
void DrawSpikePredictionArrow()
{
   if(!g_spikePredicted || !g_spikeArrowVisible)
      return;
   
   datetime currentTime = TimeCurrent();
   
   // Effacer l'ancienne flèche
   ObjectDelete(0, g_spikeArrowName);
   
   // Clignotement toutes les 500ms
   if(currentTime - g_spikeArrowBlinkTime >= 500)
   {
      g_spikeBlinkState = (g_spikeBlinkState == 0) ? 1 : 0;
      g_spikeArrowBlinkTime = currentTime;
   }
   
   if(g_spikeBlinkState == 0)
      return; // Ne pas afficher pendant le "off" du clignotement
   
   double currentPrice = GetCachedBid();
   datetime arrowTime = TimeCurrent();
   
   // Créer le nom unique
   g_spikeArrowName = "SpikePrediction_" + IntegerToString(currentTime);
   
   // Créer la flèche
   if(ObjectCreate(0, g_spikeArrowName, OBJ_ARROW, 0, arrowTime, currentPrice))
   {
      ObjectSetInteger(0, g_spikeArrowName, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, g_spikeArrowName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, g_spikeArrowName, OBJPROP_WIDTH, 5);
      ObjectSetInteger(0, g_spikeArrowName, OBJPROP_ARROWCODE, 233); // Flèche vers le haut
      ObjectSetInteger(0, g_spikeArrowName, OBJPROP_BACK, false);
      ObjectSetInteger(0, g_spikeArrowName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, g_spikeArrowName, OBJPROP_SELECTED, false);
   }
}

// Cacher la flèche de prédiction
void HideSpikePredictionArrow()
{
   ObjectDelete(0, g_spikeArrowName);
   g_spikeArrowVisible = false;
   g_spikeBlinkState = 0;
}

// Mettre à jour le système de prédiction de spike
void UpdateSpikePrediction()
{
   if(!IsBoomCrashSymbol(_Symbol))
      return;
   
   // Prédire le spike
   PredictBoomCrashSpike();
   
   // Dessiner la flèche si prédit
   if(g_spikePredicted)
   {
      DrawSpikePredictionArrow();
   }
   
   // Mettre à jour le point clignotant sur la bougie
   UpdateSpikePointBlink();
}

//+------------------------------------------------------------------+
//| Dessiner un point clignotant sur la bougie de spike            |
//+------------------------------------------------------------------+
void DrawSpikePointOnCandle(ENUM_ORDER_TYPE direction)
{
   datetime currentTime = TimeCurrent();
   
   // Obtenir le temps de la bougie précédente (bougie récente)
   datetime candleTime = iTime(_Symbol, PERIOD_CURRENT, 1); // Bougie précédente
   if(candleTime == 0)
      candleTime = TimeCurrent(); // Fallback si pas de bougie précédente
   
   // Créer le nom unique
   g_spikePointName = "SpikePoint_" + IntegerToString((int)currentTime);
   
   // Effacer l'ancien point
   ObjectDelete(0, g_spikePointName);
   
   // Déterminer la couleur selon la direction
   color pointColor = (direction == ORDER_TYPE_BUY) ? clrLime : clrRed;
   
   // Obtenir le prix de la bougie (close de la bougie précédente)
   double candlePrice = iClose(_Symbol, PERIOD_CURRENT, 1);
   if(candlePrice == 0)
      candlePrice = GetCachedBid(); // Fallback
   
   // Créer le point
   if(ObjectCreate(0, g_spikePointName, OBJ_ARROW, 0, candleTime, candlePrice))
   {
      ObjectSetInteger(0, g_spikePointName, OBJPROP_COLOR, pointColor);
      ObjectSetInteger(0, g_spikePointName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, g_spikePointName, OBJPROP_WIDTH, 4);
      ObjectSetInteger(0, g_spikePointName, OBJPROP_ARROWCODE, 159); // Point (cercle)
      ObjectSetInteger(0, g_spikePointName, OBJPROP_BACK, false);
      ObjectSetInteger(0, g_spikePointName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, g_spikePointName, OBJPROP_SELECTED, false);
      
      g_spikePointVisible = true;
      g_spikePointBlinkTime = currentTime;
      g_spikeCandleTime = candleTime;
      g_spikeDirection = direction;
      
      Print("🎯 Point clignotant créé sur bougie - Direction: ", (direction == ORDER_TYPE_BUY) ? "BUY (vert)" : "SELL (rouge)");
   }
}

//+------------------------------------------------------------------+
//| Mettre à jour le clignotement du point sur bougie               |
//+------------------------------------------------------------------+
void UpdateSpikePointBlink()
{
   if(!g_spikePointVisible)
      return;
   
   datetime currentTime = TimeCurrent();
   
   // Clignotement toutes les 400ms (plus rapide que la flèche)
   if(currentTime - g_spikePointBlinkTime >= 400)
   {
      g_spikePointBlinkState = (g_spikePointBlinkState == 0) ? 1 : 0;
      g_spikePointBlinkTime = currentTime;
      
      if(g_spikePointBlinkState == 0)
      {
         // Cacher le point
         ObjectSetInteger(0, g_spikePointName, OBJPROP_TIME, 0);
      }
      else
      {
         // Réafficher le point à la bonne position
         ObjectSetInteger(0, g_spikePointName, OBJPROP_TIME, g_spikeCandleTime);
      }
   }
}

//+------------------------------------------------------------------+
//| Cacher le point clignotant                                       |
//+------------------------------------------------------------------+
void HideSpikePoint()
{
   ObjectDelete(0, g_spikePointName);
   g_spikePointVisible = false;
   g_spikePointBlinkState = 0;
}

//+------------------------------------------------------------------+
//| Envoyer une notification pour le spike                           |
//+------------------------------------------------------------------+
void SendSpikeNotification(ENUM_ORDER_TYPE direction)
{
   string directionText = (direction == ORDER_TYPE_BUY) ? "BUY (BOOM)" : "SELL (CRASH)";
   string symbol = _Symbol;
   double currentPrice = GetCachedBid();
   
   string message = "🚨 SPIKE DÉTECTÉ - " + directionText + "\n" +
                   "Symbole: " + symbol + "\n" +
                   "Prix: " + DoubleToString(currentPrice, _Digits) + "\n" +
                   "Heure: " + TimeToString(TimeCurrent()) + "\n" +
                   "⚡ Préparez-vous pour le spike!";
   
   // Envoyer la notification MT5
   SendNotification(message);
   
   // Log dans le journal
   Print("📱 NOTIFICATION SPIKE ENVOYÉE: ", message);
}

//+------------------------------------------------------------------+
//| Valide/Ajuste distances SL/TP vs contraintes broker               |
//+------------------------------------------------------------------+
bool EnsureStopsDistanceValid(double entryPrice, ENUM_ORDER_TYPE pendingType, double &sl, double &tp)
{
   double point = GetCachedPoint();
   long stopLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevelPoints * point;
   if(minDistance < 5 * point) minDistance = 5 * point;

   // Pour certains symboles synthétiques, on force un peu plus d'écart
   if(IsDerivSyntheticIndex(_Symbol))
      minDistance = MathMax(minDistance, 300 * point); // 300 pips pour Boom/Crash
   
   // Pour les symboles Forex, utiliser des distances plus grandes
   if(StringFind(_Symbol, "AUD") >= 0 || StringFind(_Symbol, "EUR") >= 0 || StringFind(_Symbol, "GBP") >= 0 || StringFind(_Symbol, "USD") >= 0)
      minDistance = MathMax(minDistance, 15 * point); // 15 pips minimum pour Forex

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
   
   double currentPrice = g_cachedBid;
   double point = g_cachedPoint;
   
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
//| Vérifier si le cooldown global est respecté (anti-bruit)        |
//+------------------------------------------------------------------+
bool IsGlobalCooldownActive()
{
   if(GlobalTradeCooldownMinutes <= 0)
      return false; // Cooldown désactivé
      
   datetime currentTime = TimeCurrent();
   int cooldownSeconds = GlobalTradeCooldownMinutes * 60;
   
   return (currentTime - g_lastGlobalTradeTime) < cooldownSeconds;
}

//+------------------------------------------------------------------+
//| Marquer un trade comme exécuté (pour cooldown anti-bruit)       |
//+------------------------------------------------------------------+
void MarkGlobalTradeExecuted()
{
   g_lastGlobalTradeTime = TimeCurrent();
   if(DebugMode)
      Print("🕐 Cooldown global activé pour ", GlobalTradeCooldownMinutes, " minutes");
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
   double currentPrice = (signalType == ORDER_TYPE_BUY) ? GetCachedAsk() : GetCachedBid();
   
   // VÉRIFICATION ANTI-CORRECTION: Éviter de trader Boom/Crash pendant les corrections
   if(IsPriceInCorrection())
   {
      if(DebugMode)
         Print("🚫 Boom/Crash: Trade annulé - Correction de prix détectée (force: ", g_correctionStrength, "%)");
      return false;
   }
   
   // VÉRIFICATION SPIKE: Ne trader que si un spike est prédit ou si confiance très élevée
   if(!g_spikePredicted && g_lastAIConfidence < 0.90)
   {
      if(DebugMode)
         Print("🚫 Boom/Crash: Trade annulé - Aucun spike prédit et confiance < 90%");
      return false;
   }
   
   // POUR BOOM/CRASH: PAS DE SL/TP - trade sans stops pour capturer les spikes
   double stopLoss = 0;
   double takeProfit = 0;
   
   // TOUJOURS utiliser le lot minimal du broker
   double lotSize = NormalizeLotSize(InitialLotSize);
   
   if(DebugMode)
      Print("🚨 Boom/Crash: EXÉCUTION SANS SL/TP - lot minimal utilisé: ", DoubleToString(lotSize, 2));
   
   string orderComment = "Boom/Crash IMMEDIATE - " + EnumToString(signalType) + " (conf: " + DoubleToString(g_lastAIConfidence*100, 1) + "%)";
   
   bool success = false;
   if(signalType == ORDER_TYPE_BUY)
   {
      success = trade.Buy(lotSize, _Symbol, 0, 0, 0, orderComment);
   }
   else // SELL
   {
      success = trade.Sell(lotSize, _Symbol, 0, 0, 0, orderComment);
   }
   
   if(success)
   {
      MarkGlobalTradeExecuted(); // Cooldown anti-bruit
      Print("🚀 TRADE BOOM/CRASH EXÉCUTÉ IMMÉDIATEMENT:");
      Print("   📈 Type: ", EnumToString(signalType));
      Print("   💰 Entrée: ", DoubleToString(currentPrice, _Digits));
      Print("   🛡️ SL: AUCUN (trade sans stops)");
      Print("   🎯 TP: AUCUN (trade sans stops)");
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

//+------------------------------------------------------------------+
//| Fermer automatiquement toutes les positions perdantes si perte > 4$ |
//+------------------------------------------------------------------+
void CloseAllLosingPositionsIfLossExceeded(double lossLimit)
{
   double totalLoss = GetTotalLoss();
   
   // Si perte totale dépasse la limite, fermer toutes les positions perdantes
   if(totalLoss >= lossLimit)
   {
      if(DebugMode)
         Print("🚨 PERTE TOTALE DÉPASSÉE: ", DoubleToString(totalLoss, 2), "$ >= ", DoubleToString(lossLimit, 2), "$ - Fermeture automatique des positions perdantes");
      
      int positionsClosed = 0;
      double totalLossClosed = 0.0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && positionInfo.SelectByTicket(ticket))
         {
            if(positionInfo.Magic() == InpMagicNumber)
            {
               double profit = positionInfo.Profit();
               string symbol = positionInfo.Symbol();
               
               // Fermer uniquement les positions perdantes
               if(profit < 0)
               {
                  if(trade.PositionClose(ticket))
                  {
                     positionsClosed++;
                     totalLossClosed += MathAbs(profit);
                     
                     if(DebugMode)
                        Print("🛑 Position perdante fermée - Ticket=", ticket, " Symbole=", symbol, " Perte=", DoubleToString(profit, 2), "$");
                  }
                  else if(DebugMode)
                  {
                     Print("❌ Erreur fermeture position perdante ticket=", ticket, " Erreur=", trade.ResultRetcode());
                  }
               }
            }
         }
      }
      
      if(positionsClosed > 0)
      {
         Print("✅ FERMETURE AUTOMATIQUE TERMINÉE: ", positionsClosed, " position(s) perdante(s) fermée(s), perte totale=", DoubleToString(totalLossClosed, 2), "$");
         
         // Envoyer notification
         if(!DisableNotifications)
         {
            string notificationText = "🚨 FERMETURE AUTOMATIQUE\n" + 
                                     DoubleToString(positionsClosed) + " position(s) perdante(s)\n" +
                                     "Perte totale: " + DoubleToString(totalLossClosed, 2) + "$\n" +
                                     "Limite: " + DoubleToString(lossLimit, 2) + "$";
            SendNotification(notificationText);
            Alert(notificationText);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Fermer toutes les positions Volatility si la perte totale dépasse un seuil |
//+------------------------------------------------------------------+
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
   macdHandle = iMACD(_Symbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE);
   stochHandle = iStochastic(_Symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   
   // Initialiser les indicateurs FVG_Kill
   if(UseFVGKillStrategy)
   {
      FVG_InitializeIndicators();
   }
   
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
   
   // Initialiser les variables du tableau de bord
   g_aiSignal.recommendation = "WAITING";
   g_aiSignal.confidence = 0.5;
   g_trendAlignment.m1_trend = "NEUTRAL";
   g_trendAlignment.h1_trend = "NEUTRAL";
   g_trendAlignment.alignment_score = 50.0;
   g_trendAlignment.is_aligned = false;
   g_coherentAnalysis.direction = "NEUTRAL";
   g_coherentAnalysis.coherence_score = 50.0;
   g_finalDecision.action = "WAIT";
   g_finalDecision.final_confidence = 0.5;
   g_lastAIAction = "WAITING";
   
   // Initialiser les données ML
   g_mlRecommendation.recommendation = "HOLD";
   g_mlRecommendation.confidence = 0.5;
   g_mlRecommendation.accuracy = 0.0;
   g_mlRecommendation.f1_score = 0.0;
   g_mlRecommendation.models_trained = 0;
   g_mlRecommendation.key_features = "";
   g_mlRecommendation.is_valid = false;
   g_lastAIConfidence = 0.5;
   
   Print("🔧 Variables du tableau de bord initialisées:");
   Print("   IA: ", g_aiSignal.recommendation, " (", g_aiSignal.confidence * 100, "%)");
   Print("   Tendance: ", g_trendAlignment.m1_trend, "/", g_trendAlignment.h1_trend);
   Print("   Cohérence: ", g_coherentAnalysis.direction, " (", g_coherentAnalysis.coherence_score, "%)");
   Print("   Décision: ", g_finalDecision.action, " (", g_finalDecision.final_confidence * 100, "%)");
   
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
//| FONCTION UNIVERSELLE DE CALCUL SL/TP (OBLIGATOIRE)               |
//| Évite 100% des Invalid stops - Solution professionnelle          |
//+------------------------------------------------------------------+
bool CalculateSLTP(
   ENUM_ORDER_TYPE orderType,
   double &sl,
   double &tp,
   int extraPoints   // marge de sécurité
)
{
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   if(stopLevel <= 0)
      stopLevel = 10; // sécurité minimale

   // MARGE DE SÉCURITÉ SPÉCIALE POUR BOOM/CRASH
   if(IsDerivSyntheticIndex(_Symbol))
   {
      extraPoints = MathMax(extraPoints, 300); // Minimum 300 points pour Boom/Crash
      if(DebugMode)
         Print("🔧 Boom/Crash détecté: marge de sécurité augmentée à ", extraPoints, " points");
   }

   double distance = (stopLevel + extraPoints) * point;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(orderType == ORDER_TYPE_BUY)
   {
      sl = ask - distance;
      tp = ask + distance;
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      sl = bid + distance;
      tp = bid - distance;
   }
   else
      return false;

   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);

   if(DebugMode)
   {
      Print("🎯 SL/TP Universel: ", EnumToString(orderType));
      Print("   StopLevel: ", stopLevel, " pts");
      Print("   ExtraPoints: ", extraPoints, " pts");
      Print("   Distance totale: ", (stopLevel + extraPoints), " pts (", DoubleToString(distance/point, 0), " pips)");
      Print("   SL: ", DoubleToString(sl, digits));
      Print("   TP: ", DoubleToString(tp, digits));
   }

   return true;
}

//+------------------------------------------------------------------+
//| Déclarations de fonctions                                        |
//+------------------------------------------------------------------+
void CheckAndCloseBoomCrashPositions();
void OnTick()
{
   // OPTIMISATION: Mettre à jour le cache des infos symbole (évite les appels SymbolInfoDouble coûteux)
   UpdateSymbolCache();
   
   // THROTTLING GLOBAL: Limiter l'exécution à toutes les 5 secondes maximum (mode ultra performance)
   static datetime lastTickExecution = 0;
   datetime currentTime = TimeCurrent();
   
   if(UltraPerformanceMode && (currentTime - lastTickExecution) < 5)
      return; // Skip ce tick pour économiser CPU
   
   lastTickExecution = currentTime;
   
   // Variables statiques pour éviter les calculs répétitifs
   static datetime lastDailyReset = 0;
   static datetime lastTotalLossCheck = 0;
   static double cachedTotalLoss = 0.0;
   static datetime lastDashboardUpdate = 0;
   static datetime lastGraphicsUpdate = 0; // Déplacé ici pour éviter l'erreur de déclaration
   
   // FORCER l'initialisation du dashboard au premier tick
   static bool firstTick = true;
   if(firstTick)
   {
      lastDashboardUpdate = 0; // Forcer la mise à jour immédiate
      firstTick = false;
   }
   
   // Réinitialiser les compteurs quotidiens seulement si nécessaire (vérification toutes les minutes)
   if(currentTime - lastDailyReset >= 60)
   {
      ResetDailyCountersIfNeeded();
      lastDailyReset = currentTime;
   }
   
   // Logique FVG_Kill intégrée
   if(UseFVGKillStrategy)
   {
      // Détecter mode Boom/Crash
      fvg_IsBoom = FVG_IsBoomCrashMode();
      fvg_IsCrash = !fvg_IsBoom && FVG_IsBoomCrashMode();
      
      // Gérer le trailing structure
      if(UseFVGKillTrailing)
      {
         FVG_ManageTrailingStructure();
      }
   }
   
   // Une fois après 5 s : remplir les zones IA si vides (fallback local, hors chemin graphique pour ne pas détacher)
   static datetime firstTickTime = 0;
   if(firstTickTime == 0) firstTickTime = currentTime;
   static bool zonesInitDone = false;
   if(!zonesInitDone && (currentTime - firstTickTime >= 3))
   {
      // Toujours initialiser les zones IA après 3 secondes
      if(g_aiBuyZoneLow == 0 && g_aiBuyZoneHigh == 0 && g_aiSellZoneLow == 0 && g_aiSellZoneHigh == 0)
      {
         InitializeDefaultAIZones();
      }
      
      // Essayer d'obtenir les données de tendance si disponible
      if(g_lastTrendData == "")
      {
         g_lastTrendData = GenerateLocalFallbackTrend();
         ExtractAIZonesFromResponse(g_lastTrendData);
      }
      
      zonesInitDone = true;
      
      // FORCER un appel immédiat des graphiques pour afficher les zones
      if(!DisableAllGraphics)
      {
         UpdateAllGraphics();
         lastGraphicsUpdate = currentTime;
         
         // TEST: Créer manuellement une zone de test pour vérifier
         if(DebugMode)
         {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            datetime testTime = TimeCurrent();
            
            // Zone de test BUY
            ObjectCreate(0, "TEST_BUY_ZONE", OBJ_RECTANGLE, 0, testTime - 1800, currentPrice - 50 * _Point, testTime, currentPrice - 10 * _Point);
            ObjectSetInteger(0, "TEST_BUY_ZONE", OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, "TEST_BUY_ZONE", OBJPROP_BACK, true);
            ObjectSetInteger(0, "TEST_BUY_ZONE", OBJPROP_FILL, true);
            ObjectSetInteger(0, "TEST_BUY_ZONE", OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, "TEST_BUY_ZONE", OBJPROP_WIDTH, 2);
            
            // Zone de test SELL
            ObjectCreate(0, "TEST_SELL_ZONE", OBJ_RECTANGLE, 0, testTime - 1800, currentPrice + 10 * _Point, testTime, currentPrice + 50 * _Point);
            ObjectSetInteger(0, "TEST_SELL_ZONE", OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, "TEST_SELL_ZONE", OBJPROP_BACK, true);
            ObjectSetInteger(0, "TEST_SELL_ZONE", OBJPROP_FILL, true);
            ObjectSetInteger(0, "TEST_SELL_ZONE", OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, "TEST_SELL_ZONE", OBJPROP_WIDTH, 2);
            
            Print("🧪 Zones de test créées manuellement - BUY: ", currentPrice - 50 * _Point, "-", currentPrice - 10 * _Point, " SELL: ", currentPrice + 10 * _Point, "-", currentPrice + 50 * _Point);
         }
      }
   }
   
   // OPTIMISATION: Mettre à jour les graphiques beaucoup moins souvent
   int graphicsInterval = 60; // 1 minute pour charge minimale
   
   if(UltraPerformanceMode)
      graphicsInterval = 300; // 5 minutes en mode ultra (charge minimale absolue)
   else if(HighPerformanceMode)
      graphicsInterval = 120; // 2 minutes en mode haute perf
   
   if(ShowDashboard && (currentTime - lastDashboardUpdate >= 60))
   {
      UpdateAdvancedDashboard();
      lastDashboardUpdate = currentTime;
   }
   
   if(!DisableAllGraphics && (TimeCurrent() - lastGraphicsUpdate) >= graphicsInterval)
   {
      UpdateAllGraphics();
      lastGraphicsUpdate = TimeCurrent();
   }
   
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
   
   // Vérifier la perte totale maximale (toutes positions actives) - avec cache
   if(currentTime - lastTotalLossCheck >= 5) // Vérifier toutes les 5 secondes
   {
      cachedTotalLoss = GetTotalLoss();
      lastTotalLossCheck = currentTime;
   }
   
   if(cachedTotalLoss >= MaxTotalLoss)
   {
      if(DebugMode)
         Print("🛑 Perte totale maximale atteinte: ", DoubleToString(cachedTotalLoss, 2), " USD (limite: ", DoubleToString(MaxTotalLoss, 2), " USD) - Blocage de tous les nouveaux trades");
      return;
   }
   
   // Mettre à jour l'IA si nécessaire (optimisé)
   static datetime lastAIUpdate = 0;
   int aiInterval = AI_UpdateInterval;
   if(UltraPerformanceMode)
      aiInterval *= 8; // x8 en mode ultra (60s → 480s = 8 minutes)
   else if(HighPerformanceMode)
      aiInterval *= 4; // x4 en mode haute perf (60s → 240s = 4 minutes)
   
   if(UseAI_Agent && (TimeCurrent() - lastAIUpdate) >= aiInterval)
   {
      UpdateAIDecision();
      lastAIUpdate = TimeCurrent();
   }
   
   // Mettre à jour l'analyse de tendance API si nécessaire
   static datetime lastTrendUpdate = 0;
   int trendInterval = AI_UpdateInterval;
   if(UltraPerformanceMode)
      trendInterval *= 8; // x8 en mode ultra (8 minutes)
   else if(HighPerformanceMode)
      trendInterval *= 4; // x4 en mode haute perf (4 minutes)
   
   if(UseTrendAPIAnalysis && (TimeCurrent() - lastTrendUpdate) >= trendInterval)
   {
      UpdateTrendAPIAnalysis();
      lastTrendUpdate = TimeCurrent();
   }
   
   // Mettre à jour les données des endpoints Render (RÉACTIVÉ POUR PRÉDICTIONS)
   static datetime lastEndpointUpdate = 0;
   int endpointInterval = 300; // 5 minutes en normal (augmenté)
   
   if(UltraPerformanceMode)
      endpointInterval = 1800; // 30 minutes en mode ultra (augmenté)
   else if(HighPerformanceMode)
      endpointInterval = 900; // 15 minutes en mode haute perf (augmenté)
   
   // MODE ULTRA PERFORMANCE: Réduire drastiquement les appels API
   bool useEndpoints = UseAllEndpoints;
   if(UltraPerformanceMode)
   {
      endpointInterval = 2400; // 40 minutes seulement en mode ultra
      // Désactiver les endpoints non critiques en mode ultra
      useEndpoints = false;
   }
   
   if(useEndpoints && (TimeCurrent() - lastEndpointUpdate) >= endpointInterval)
   {
      if(!UltraPerformanceMode)
      {
         g_lastAnalysisData = UpdateAnalysisEndpoint();
         string trend = UpdateTrendEndpoint();
         if(trend != "")
            g_lastTrendData = trend;
         else
            g_lastTrendData = GenerateLocalFallbackTrend();
         ExtractAIZonesFromResponse(g_lastTrendData);
         g_lastPredictionData = UpdatePredictionEndpoint();
         g_lastCoherentData = UpdateCoherentEndpoint();
      }
      else
      {
         // Mode ultra: seulement l'IA principale
         UpdateAIDecision();
      }
      g_lastEndpointUpdate = TimeCurrent();
      
      if(DebugMode)
      {
         if(UltraPerformanceMode)
         {
            Print("🚀 Mode Ultra Performance: IA principale mise à jour (10 min)");
         }
         else
         {
            Print("🔁 Données endpoints mises à jour (prédiction activée):");
            Print("   Analyse: ", (g_lastAnalysisData != "") ? "✅" : "❌");
            Print("   Tendance: ", (g_lastTrendData != "") ? "✅" : "❌");
            Print("   Prédiction: ", (g_lastPredictionData != "") ? "✅" : "❌");
            Print("   Cohérent: ", (g_lastCoherentData != "") ? "✅" : "❌");
         }
      }
      
      // MODE ULTRA PERFORMANCE: Désactiver les graphiques
      if(!UltraPerformanceMode)
      {
         // Dessiner les prédictions sur le graphique
         if(g_lastPredictionData != "")
         {
            DrawPredictionsOnChart(g_lastPredictionData);
         }
         
         // Détecter et afficher les corrections vers résistances/supports
         DetectAndDisplayCorrections();
      }
      
      // Forcer la mise à jour du tableau de bord
      if(ShowDashboard && ShowInfoOnChart && g_lastAIAction != "")
      {
         ENUM_ORDER_TYPE dummyType = (g_lastAIAction == "buy") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         CheckAllEndpointsAlignment(dummyType);
      }
      
      // Récupérer les données ML si l'intégration est activée
      if(UseMLIntegration)
      {
         GetMLRecommendationData();
         GetMLSwingPointPredictions();
         GetMLTrendLinePredictions();
      }
   }
   
   // OPTIMISATION: Diagnostics très peu fréquents (désactivé si mode silencieux ou ultra performance)
   static datetime lastDiagnostic = 0;
   if(DebugMode && !DisableNotifications && !UltraPerformanceMode && (TimeCurrent() - lastDiagnostic) >= 1800) // Toutes les 30 minutes (réduit)
   {
      Print("\n=== DIAGNOSTIC ROBOT (optimisé) ===");
      Print("Mode haute performance: ", HighPerformanceMode ? "✅ ACTIVÉ" : "❌ DÉSACTIVÉ");
      Print("Mode ultra performance: ", UltraPerformanceMode ? "✅ ACTIVÉ" : "❌ DÉSACTIVÉ");
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
   
   // MODE ULTRA PERFORMANCE: Désactiver complètement les graphiques ET les diagnostics
   if(UltraPerformanceMode || HighPerformanceMode)
   {
      return; // Sortir immédiatement - pas de graphiques du tout
   }
   
   // MISE À JOUR DES INDICATEURS GRAPHIQUES - DÉSACTIVÉ EN MODE ULTRA
   static datetime lastHeavyUpdate = 0;
   if(!UltraPerformanceMode && !HighPerformanceMode && (TimeCurrent() - lastHeavyUpdate >= 7200)) // Toutes les 2 heures seulement
   {
      // Nettoyer seulement les objets obsolètes
      CleanOldGraphicalObjects();
      
      // Afficher EMA longues (optimisé, très peu fréquent)
      if(ShowLongTrendEMA)
         DrawLongTrendEMA();
      
      // Dessiner les swing points ML prédits
      if(UseMLIntegration && ShowMLRecommendations)
         DrawMLSwingPointPredictions();
      
      // Dessiner les trendlines ML prédites
      if(UseMLIntegration && ShowMLRecommendations)
         DrawMLTrendLines();
      
      // FORCER: Afficher support/résistance TOUJOURS (très important) - optimisé
      static datetime lastSRUpdate = 0;
      if(TimeCurrent() - lastSRUpdate >= 1800) // Toutes les 30 minutes
      {
         DrawSupportResistanceLevels();
         lastSRUpdate = TimeCurrent();
      }
      
      // NOUVEAU: Dessiner les bougies futures adaptées au timeframe (optimisé)
      static datetime lastFutureCandlesUpdate = 0;
      if(TimeCurrent() - lastFutureCandlesUpdate >= 120) // Toutes les 2 minutes pour voir les prédictions
      {
         DrawFutureCandlesAdaptive();
         lastFutureCandlesUpdate = TimeCurrent();
      }
      
      // Afficher trendlines (très peu fréquent)
      if(DrawTrendlinesEnabled)
         DrawTrendlinesOnChart();
      
      // Afficher les zones SMC/OrderBlocks (si activé) - très peu fréquent
      if(DrawSMCZones)
         DrawSMCZonesOnChart();
      
      // Afficher les FVG et Order Blocks (très peu fréquent - toutes les 2 heures)
      static datetime lastFVGUpdate = 0;
      if(TimeCurrent() - lastFVGUpdate >= 7200) // Toutes les 2 heures
      {
         DrawFVG();
         lastFVGUpdate = TimeCurrent();
      }
      
      lastHeavyUpdate = TimeCurrent();
   }
   
   // SÉCURISATION DES PROFITS: Optimisé - appelé seulement dans la gestion des positions
   // Éviter l'appel direct ici pour réduire la charge CPU
   
   // Patterns Deriv - DÉSACTIVÉ EN MODE ULTRA PERFORMANCE
   if(!DisableAllGraphics && !UltraPerformanceMode && !HighPerformanceMode && DrawDerivPatterns)
   {
      static datetime lastDerivUpdate = 0;
      int derivInterval = UltraPerformanceMode ? 120 : 60; // Toutes les 2 minutes en mode haute perf, 1 minute normal
      if(TimeCurrent() - lastDerivUpdate >= derivInterval)
      {
         DrawDerivPatternsOnChart();
         UpdateDerivArrowBlink();
         lastDerivUpdate = TimeCurrent();
      }
   }
   
   // OPTIMISATION: Vérifier les positions moins fréquemment (ULTRA DRASTIQUE)
   static datetime lastPositionCheckLocal = 0;
   int checkInterval = 300; // 5 minutes par défaut
   
   // MODE ULTRA PERFORMANCE: Intervalles beaucoup plus longs
   if(UltraPerformanceMode)
   {
      checkInterval = 600; // Toutes les 10 minutes
   }
   else if(HighPerformanceMode)
   {
      checkInterval = 300; // Toutes les 5 minutes
   }
   
   if(TimeCurrent() - lastPositionCheckLocal >= checkInterval)
   {
      CheckAndManagePositions();
      SecureDynamicProfits(); // RÉACTIVÉ - trailing stop opérationnel
      
      // Activer le trailing stop pour TOUS les symboles pour sécuriser les profits (ULTRA RARE)
      static datetime lastTrailingUpdate = 0;
      int trailingInterval = UltraPerformanceMode ? 300 : 180; // 3-5 minutes
      if(UseTrailingStop && (TimeCurrent() - lastTrailingUpdate >= trailingInterval))
      {
         ActivateTrailingStop();
         lastTrailingUpdate = TimeCurrent();
      }
      
      lastPositionCheckLocal = TimeCurrent();
   }
   
   // Mettre à jour le tracker de positions pour la stratégie avancée (ULTRA RARE)
   static datetime lastTrackerUpdate = 0;
   int trackerInterval = UltraPerformanceMode ? 300 : 180; // 3-5 minutes au lieu de 30-60
   if(TimeCurrent() - lastTrackerUpdate >= trackerInterval)
   {
      UpdatePositionTracker();
      lastTrackerUpdate = TimeCurrent();
   }
   
   // Si pas de position, chercher une opportunité (ULTRA RARE)
   static datetime lastOpportunityCheck = 0;
   int opportunityInterval = 120; // 2 minutes par défaut
   
   // MODE ULTRA PERFORMANCE: Opportunités ultra rares
   if(UltraPerformanceMode)
   {
      opportunityInterval = 300; // Toutes les 5 minutes
   }
   else if(HighPerformanceMode)
   {
      opportunityInterval = 180; // Toutes les 3 minutes
   }
   
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
   // Initialiser les zones par défaut si elles sont à 0
   if(g_aiBuyZoneLow == 0 && g_aiBuyZoneHigh == 0 && g_aiSellZoneLow == 0 && g_aiSellZoneHigh == 0)
   {
      InitializeDefaultAIZones();
   }
   
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
//| Initialiser les zones IA par défaut basées sur le prix actuel      |
//+------------------------------------------------------------------+
void InitializeDefaultAIZones()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[];
   ArraySetAsSeries(atr, true);
   double atrValue = 0.0;
   
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
      atrValue = atr[0];
   else
      atrValue = currentPrice * 0.001; // 0.1% par défaut
   
   // Créer des zones à ±2 ATR du prix actuel
   double zoneWidth = atrValue * 2.0;
   
   g_aiBuyZoneLow = currentPrice - zoneWidth * 2.0; // Zone BUY en dessous
   g_aiBuyZoneHigh = currentPrice - zoneWidth * 0.5;
   
   g_aiSellZoneLow = currentPrice + zoneWidth * 0.5; // Zone SELL au dessus
   g_aiSellZoneHigh = currentPrice + zoneWidth * 2.0;
   
   if(DebugMode)
      Print("📍 Zones IA initialisées par défaut - BUY: ", DoubleToString(g_aiBuyZoneLow, 5), "-", DoubleToString(g_aiBuyZoneHigh, 5), " SELL: ", DoubleToString(g_aiSellZoneLow, 5), "-", DoubleToString(g_aiSellZoneHigh, 5));
}

//+------------------------------------------------------------------+
//| Vérifier et gérer les positions existantes                       |
//+------------------------------------------------------------------+
void CheckAndManagePositions()
{
   g_hasPosition = false;

   // Fermeture automatique des positions perdantes si perte dépasse 4$
   CloseAllLosingPositionsIfLossExceeded(MaxTotalLoss);
   
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
            
            // OPTIMISATION: Vérifier les spikes Boom/Crash ici pour éviter une boucle séparée
            bool isBoomCrash = (StringFind(_Symbol, "Boom", 0) != -1 || StringFind(_Symbol, "Crash", 0) != -1);
            if(isBoomCrash)
            {
               double currentProfit = positionInfo.Profit();
               CloseBoomCrashAfterSpike(ticket, currentProfit);
            }
            
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
            
            // NOUVELLE LOGIQUE: Fermer la position si la prédiction IA change de sens
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)positionInfo.PositionType();
            string currentDirection = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            
            // Vérifier si la prédiction actuelle est opposée à la position en cours
            bool predictionChanged = false;
            string reason = "";
            
            // Seulement vérifier le changement si on a une dernière direction enregistrée
            if(g_lastExecutedDirection != "")
            {
               if(posType == POSITION_TYPE_BUY && g_finalDecision.action == "SELL" && g_lastExecutedDirection == "BUY")
               {
                  predictionChanged = true;
                  reason = "Prédiction IA passée de BUY à SELL";
               }
               else if(posType == POSITION_TYPE_SELL && g_finalDecision.action == "BUY" && g_lastExecutedDirection == "SELL")
               {
                  predictionChanged = true;
                  reason = "Prédiction IA passée de SELL à BUY";
               }
            }
            
            // Fermer la position si la prédiction a changé avec confiance élevée
            if(predictionChanged && g_finalDecision.final_confidence >= 0.65)
            {
               Print("🔄 CHANGEMENT DE PRÉDICTION IA - FERMETURE POSITION:");
               Print("   📍 Position actuelle: ", currentDirection);
               Print("   🧠 Nouvelle prédiction: ", g_finalDecision.action);
               Print("   📊 Confiance: ", DoubleToString(g_finalDecision.final_confidence * 100, 1), "%");
               Print("   📝 Raison: ", reason);
               Print("   💰 Profit/Perte: ", DoubleToString(currentProfit, 2), "$");
               
               if(trade.PositionClose(ticket))
               {
                  Print("✅ Position fermée suite au changement de prédiction IA");
                  g_hasPosition = false;
                  g_lastExecutedDirection = ""; // Réinitialiser pour prochaine entrée
                  continue; // Passer à la position suivante
               }
               else
               {
                  Print("❌ Erreur fermeture position: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
               }
            }
            
            // Vérifier que la position existe toujours avant de continuer
            if(!PositionSelectByTicket(ticket))
            {
               if(DebugMode)
                  Print("⚠️ Position ", ticket, " n'existe plus, passage à la suivante");
               continue;
            }
            
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
               else
               {
                  // Vérifier si la position existe encore après échec de fermeture
                  if(!PositionSelectByTicket(ticket))
                  {
                     if(DebugMode)
                        Print("⚠️ Position ", ticket, " n'existe plus après échec de fermeture MaxLoss");
                     continue;
                  }
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
               else
               {
                  // Vérifier si la position existe encore après échec de fermeture
                  if(!PositionSelectByTicket(ticket))
                  {
                     if(DebugMode)
                        Print("⚠️ Position ", ticket, " n'existe plus après échec de fermeture 2$");
                     continue;
                  }
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
            
            // PROTECTION UNIVERSELLE: Fermer les positions avec grosses pertes même en mode WAITING
            if(currentProfit <= -5.0) // Seuil de perte critique de 5$
            {
               if(trade.PositionClose(ticket))
               {
                  Print("🚨 FERMETURE URGENTE: Position fermée - Perte critique de ", DoubleToString(currentProfit, 2), "$");
                  RemoveSymbolFromExecutedList(_Symbol);
                  return; // Sortir de la boucle après fermeture
               }
               else
               {
                  Print("❌ Erreur fermeture position critique: ", trade.ResultRetcode());
               }
            }
            
            // PROTECTION MODE WAITING: Fermer les positions perdantes modérées après 30 secondes
            if((g_finalDecision.action == "WAIT" || g_finalDecision.action == "HOLD") && currentProfit <= -2.0)
            {
               datetime openTime = (datetime)positionInfo.Time();
               int positionAge = (int)(TimeCurrent() - openTime);
               
               if(positionAge >= 30) // Attendre au moins 30 secondes
               {
                  if(trade.PositionClose(ticket))
                  {
                     Print("⏰ FERMETURE WAITING: Position fermée après ", positionAge, "s - Perte: ", DoubleToString(currentProfit, 2), "$");
                     RemoveSymbolFromExecutedList(_Symbol);
                     return; // Sortir de la boucle après fermeture
                  }
                  else
                  {
                     Print("❌ Erreur fermeture position waiting: ", trade.ResultRetcode());
                  }
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
                              "AI_BUY_", "AI_SELL_", "SR_", "Trend_", "SMC_OB_", "DERIV_ARROW_", 
                              "FIB_", "LIQUIDITY_", "FVG_", "EMA_Fast_Curve_"};
   
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
   ObjectSetInteger(0, trendLabelName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, trendLabelName, OBJPROP_FONTSIZE, TEXT_FONT_SIZE);
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
   ObjectSetInteger(0, endpointsLabelName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, endpointsLabelName, OBJPROP_FONTSIZE, TEXT_FONT_SIZE);
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
   ObjectSetInteger(0, alignName, OBJPROP_COLOR, UseMutedColors ? MUTED_YELLOW : clrYellow);
   ObjectSetInteger(0, alignName, OBJPROP_FONTSIZE, TEXT_FONT_SIZE_SM);
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
      ObjectSetInteger(0, endpointName, OBJPROP_FONTSIZE, TEXT_FONT_SIZE_SM);
      ObjectSetString(0, endpointName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, endpointName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, endpointName, OBJPROP_BACK, 0);
   }
   
   // Ligne 7: Informations de correction et spike (Boom/Crash)
   string infoText = "";
   if(g_isPriceInCorrection)
   {
      infoText = "🔄 Correction: " + DoubleToString(g_correctionStrength, 0) + "%";
   }
   else if(g_spikePredicted)
   {
      infoText = "🚨 Spike Prédit!";
   }
   
   if(infoText != "")
   {
      string infoName = g_dashboardName + "Info";
      ObjectCreate(0, infoName, OBJ_TEXT, 0, currentTime, currentPrice - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 180));
      ObjectSetString(0, infoName, OBJPROP_TEXT, infoText);
      ObjectSetInteger(0, infoName, OBJPROP_COLOR, g_isPriceInCorrection ? clrOrange : clrYellow);
      ObjectSetInteger(0, infoName, OBJPROP_FONTSIZE, TEXT_FONT_SIZE_SM);
      ObjectSetString(0, infoName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, infoName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, infoName, OBJPROP_BACK, 0);
   }
}

//+------------------------------------------------------------------+
//| Nettoie les objets du tableau de bord                            |
//+------------------------------------------------------------------+
void CleanupDashboard()
{
   // Nettoyer les anciens objets du tableau de bord
   ObjectDelete(0, g_dashboardName + "Panel");
   ObjectDelete(0, g_dashboardName + "Title");
   ObjectDelete(0, g_dashboardName + "Score");
   ObjectDelete(0, g_dashboardName + "Signal");
   ObjectDelete(0, g_dashboardName + "Trend");
   ObjectDelete(0, g_dashboardName + "Coherent");
   ObjectDelete(0, g_dashboardName + "Decision");
   ObjectDelete(0, g_dashboardName + "_Text");
   ObjectDelete(0, "Advanced_Trading_Dashboard");
   
   // Nettoyer les nouveaux labels directs sur le graphique
   CleanupDashboardLabels();
}

//+------------------------------------------------------------------+
//| Nettoie les labels du dashboard affichés directement sur graphique|
//+------------------------------------------------------------------+
void CleanupDashboardLabels()
{
   ObjectDelete(0, "AI_IA_Signal");
   ObjectDelete(0, "AI_Trend_Alignment");
   ObjectDelete(0, "AI_Coherent_Analysis");
   ObjectDelete(0, "AI_Final_Decision");
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
   
   // Vérifier si c'est un spike (mouvement rapide de prix) - PLUS SENSIBLE pour Boom/Crash
   bool spikeDetected = false;
   if(g_lastBoomCrashPrice > 0 && (now - g_lastPriceCheck) <= 3) // Vérifier toutes les 3 secondes pour plus de réactivité
   {
      double priceChange = MathAbs(currentPrice - g_lastBoomCrashPrice);
      double priceChangePercent = (priceChange / g_lastBoomCrashPrice) * 100.0;
      
      // Seuil PLUS BAS pour Boom/Crash: 0.3% au lieu de 0.5% pour détecter plus de spikes
      if(priceChangePercent > 0.3)
      {
         spikeDetected = true;
         if(DebugMode)
            Print("🚨 SPIKE BOOM/CRASH DÉTECTÉ: ", _Symbol, " - Changement: ", DoubleToString(priceChangePercent, 2), "%");
      }
   }
   
   g_lastBoomCrashPrice = currentPrice;
   g_lastPriceCheck = now;
   
   // Pour Boom/Crash: FERMER TOUJOURS juste après le spike (même avec petit profit ou perte)
   // Le spike est le moment optimal pour sortir sur Boom/Crash
   if(spikeDetected || currentProfit >= BoomCrashSpikeTP)
   {
      if(trade.PositionClose(ticket))
      {
         string reason = spikeDetected ? "Spike détecté - FERMETURE IMMÉDIATE" : "Profit seuil atteint";
         Print("🚀 Position Boom/Crash FERMÉE: ", reason, " - Profit=", DoubleToString(currentProfit, 2), "$");
         
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
//| Vérification rapide des spikes Boom/Crash - OPTIMISÉE             |
//+------------------------------------------------------------------+
void CheckAndCloseBoomCrashPositions()
{
   // OPTIMISATION: Utiliser les données déjà chargées si disponibles
   // Éviter une boucle supplémentaire PositionsTotal()
   
   // Cette fonction sera appelée depuis la boucle principale de positions
   // pour éviter les boucles multiples et améliorer les performances
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
   double tickValue = g_cachedTickValue;
   double tickSize = g_cachedTickSize;
   double point = g_cachedPoint;
   
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
   
   // AJOUT: Augmenter le SL et le TP selon le type de symbole
   int slAddPoints = 30;  // Valeur par défaut
   int tpAddPoints = 50;  // Valeur par défaut
   
   if(IsDerivSyntheticIndex(_Symbol))
   {
      slAddPoints = 300;  // 300 points pour Boom/Crash
      tpAddPoints = 600;  // 600 points pour Boom/Crash
      if(DebugMode)
         Print("🔧 Mode synthétique: augmentation SL/TP à ", slAddPoints, "/", tpAddPoints, " points");
   }
   
   slPoints += slAddPoints;
   tpPoints += tpAddPoints;
   
   if(DebugMode)
      Print("🎯 SL/TP ajustés: SL+", slAddPoints, "pts, TP+", tpAddPoints, "pts (SL=", DoubleToString(slPoints, 1), "pts, TP=", DoubleToString(tpPoints, 1), "pts)");
   
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
   
   // AJOUT: Augmenter le SL et le TP selon le type de symbole
   int slAddPoints = 100;  // Valeur par défaut augmentée pour autres marchés
   int tpAddPoints = 200;  // Valeur par défaut augmentée pour autres marchés
   
   if(IsDerivSyntheticIndex(_Symbol))
   {
      slAddPoints = 300;  // 300 points pour Boom/Crash
      tpAddPoints = 600;  // 600 points pour Boom/Crash
      if(DebugMode)
         Print("🔧 Mode synthétique (max loss): augmentation SL/TP à ", slAddPoints, "/", tpAddPoints, " points");
   }
   
   slPoints += slAddPoints;
   tpPoints += tpAddPoints;
   
   if(DebugMode)
      Print("🎯 SL/TP ajustés (max loss): SL+", slAddPoints, "pts, TP+", tpAddPoints, "pts (SL=", DoubleToString(slPoints, 1), "pts, TP=", DoubleToString(tpPoints, 1), "pts)");
   
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
   
   // PROTECTION: Autoriser SELL sur Boom (suivre les recommandations IA)
   bool isBoom = (StringFind(_Symbol, "Boom", 0) != -1);
   bool isCrash = (StringFind(_Symbol, "Crash", 0) != -1);
   
   if(isBoom && orderType == ORDER_TYPE_SELL)
   {
      if(DebugMode)
         Print("✅ SELL autorisé sur Boom - Signal IA présent");
      return true; // Autoriser SELL sur Boom
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
   
   // VÉRIFICATION ANTI-CORRECTION: Éviter de trader pendant les corrections
   if(IsPriceInCorrection())
   {
      if(DebugMode)
         Print("🔄 Trading suspendu - Correction de prix détectée (force: ", g_correctionStrength, "%)");
      
      // Si la correction est forte (>70%), ne même pas chercher d'opportunités
      if(g_correctionStrength > 70.0)
         return;
      
      // Si correction modérée (30-70%), réduire la confiance IA
      if(g_correctionStrength > 30.0 && g_lastAIConfidence > 0.5)
      {
         g_lastAIConfidence *= 0.7; // Réduire la confiance de 30%
         if(DebugMode)
            Print("🔄 Confiance IA réduite à ", g_lastAIConfidence * 100, "% à cause de la correction");
      }
   }
   
   // Mettre à jour la prédiction de spike pour Boom/Crash
   UpdateSpikePrediction();
   
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
         // VÉRIFICATION ANTI-CORRECTION: Éviter de trader pendant les corrections fortes
         if(IsPriceInCorrection() && g_correctionStrength > 50.0)
         {
            if(DebugMode)
               Print("🚫 Trade IA annulé - Correction forte détectée (", g_correctionStrength, "%)");
            return; // Annuler le trade si correction forte
         }
         
         if(DebugMode)
            Print("✅ Signal IA validé - exécution du trade...");
         // DÉTERMINER LE TYPE DE SIGNAL BASÉ SUR L'IA
         ENUM_ORDER_TYPE signalType = WRONG_VALUE;
         if(StringCompare(g_lastAIAction, "buy") == 0)
            signalType = ORDER_TYPE_BUY;
         else if(StringCompare(g_lastAIAction, "sell") == 0)
            signalType = ORDER_TYPE_SELL;
         
         // RÈGLE BOOM/CRASH: autoriser SELL sur Boom (suivre IA)
         bool isCrashSymbol = (StringFind(_Symbol, "Crash", 0) != -1);
         bool isBoomSymbol = (StringFind(_Symbol, "Boom", 0) != -1);
         if(isCrashSymbol && signalType == ORDER_TYPE_BUY)
         {
            if(DebugMode) Print("🚫 BLOQUÉ: pas de BUY sur Crash - attente signal SELL");
            return;
         }
         if(isBoomSymbol && signalType == ORDER_TYPE_SELL)
         {
            if(DebugMode) Print("✅ SELL autorisé sur Boom - Signal IA présent");
            // Continuer vers l'exécution
         }
         
         // SI ON A UN SIGNAL VALIDE, ENVOYER NOTIFICATION ET ATTENDRE ENTRÉE PROMETTEUSE
         if(signalType != WRONG_VALUE)
         {
            // Vérifier si la flèche DERIV est présente (condition requise)
            bool hasDerivArrow = IsDerivArrowPresent();
            
            if(hasDerivArrow)
            {
               // Vérifier si on a un signal fort (pour Boom/Crash)
               bool hasStrongSignal = HasStrongSignal();
               
               // Pour Boom/Crash: exécuter immédiatement si signal fort
               bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom", 0) != -1 || StringFind(_Symbol, "Crash", 0) != -1);
               
               if(isBoomCrashSymbol && hasStrongSignal)
               {
                  if(DebugMode)
                     Print("🚀 Boom/Crash + Flèche DERIV + Signal Fort = Exécution IMMÉDIATE");
                  
                  // Réinitialiser la liste des ordres exécutés si nécessaire
                  ResetExecutedOrdersList();
                  
                  // Vérifier si un ordre a déjà été exécuté pour ce symbole
                  if(HasOrderAlreadyExecuted(_Symbol))
                  {
                     if(DebugMode)
                        Print("⏳ Ordre déjà exécuté pour ", _Symbol, " - attente nouvelle opportunité");
                     return;
                  }
                  
                  // Exécuter immédiatement le trade Boom/Crash
                  bool marketSuccess = ExecuteImmediateBoomCrashTrade(signalType);
                  
                  if(marketSuccess)
                  {
                     MarkOrderAsExecuted(_Symbol);
                     if(DebugMode)
                        Print("✅ Trade Boom/Crash exécuté immédiatement - Type: ", EnumToString(signalType));
                  }
                  else
                  {
                     if(DebugMode)
                        Print("❌ Échec exécution Boom/Crash");
                  }
                  
                  return; // Sortir après traitement Boom/Crash
               }
               
               // Pour les autres symboles ou signaux moins forts: logique normale
               
               // Réinitialiser la liste des ordres exécutés si nécessaire
               ResetExecutedOrdersList();
               
               // Vérifier si un ordre a déjà été exécuté pour ce symbole
               if(HasOrderAlreadyExecuted(_Symbol))
               {
                  if(DebugMode)
                     Print("⏳ Ordre déjà exécuté pour ", _Symbol, " - attente nouvelle opportunité");
                  return;
               }
               
               // Pour les symboles non Boom/Crash: exécution marché si confiance très élevée
               bool allowMarket = false;
               if(!isBoomCrashSymbol && g_lastAIConfidence >= AI_MarketExecutionConfidence)
                  allowMarket = true;

               if(allowMarket)
               {
                  if(DebugMode)
                     Print("🚀 Signal fort - Exécution IMMÉDIATE au marché (", DoubleToString(g_lastAIConfidence*100, 1), "%)");
                  
                  double price = SymbolInfoDouble(_Symbol, (signalType == ORDER_TYPE_BUY) ? SYMBOL_ASK : SYMBOL_BID);
                  double sl=0, tp=0;
                  // Utiliser ATR pour un SL/TP raisonnable
                  double atr[];
                  ArraySetAsSeries(atr, true);
                  double atrVal = 0;
                  if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0) atrVal = atr[0];
                  if(atrVal <= 0) atrVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50;

                  bool marketSuccess = false;
                  if(signalType == ORDER_TYPE_BUY)
                  {
                     sl = NormalizeDouble(price - 1.2 * atrVal, _Digits);
                     tp = NormalizeDouble(price + 2.4 * atrVal, _Digits);
                     ValidateAndAdjustStops(price, sl, tp, ORDER_TYPE_BUY);
                     marketSuccess = trade.Buy(NormalizeLotSize(InitialLotSize), _Symbol, price, sl, tp,
                                              "AI STRONG MARKET (conf: " + DoubleToString(g_lastAIConfidence*100,1) + "%)");
                  }
                  else
                  {
                     sl = NormalizeDouble(price + 1.2 * atrVal, _Digits);
                     tp = NormalizeDouble(price - 2.4 * atrVal, _Digits);
                     ValidateAndAdjustStops(price, sl, tp, ORDER_TYPE_SELL);
                     marketSuccess = trade.Sell(NormalizeLotSize(InitialLotSize), _Symbol, price, sl, tp,
                                               "AI STRONG MARKET (conf: " + DoubleToString(g_lastAIConfidence*100,1) + "%)");
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
                        Print("❌ Échec exécution immédiate - fallback vers ordre LIMIT");
                     
                     // Fallback LIMIT
                     if(PlaceLimitOrderOnArrow(signalType))
                        MarkOrderAsExecuted(_Symbol);
                  }
               }
               else
               {
                  // Pour les autres cas: ordre LIMIT normal
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
   
   // TOUJOURS utiliser le lot minimal du broker pour tous les symboles (forex, volatility, métaux, etc.)
   double finalLot = minLot;
   
   // Normaliser selon le step
   finalLot = MathFloor(finalLot / lotStep) * lotStep;
   
   // S'assurer que le lot est valide
   finalLot = MathMax(minLot, MathMin(maxLot, finalLot));
   
   if(DebugMode && finalLot != minLot)
      Print("🔧 Lot ajusté: demandé=", DoubleToString(lot, 2), " → final=", DoubleToString(finalLot, 2), " (min=", DoubleToString(minLot, 2), ")");
   
   return finalLot;
}

//+------------------------------------------------------------------+
//| Valide et ajuste SL/TP pour éviter les "Invalid stops"          |
//+------------------------------------------------------------------+
void ValidateAndAdjustStops(double price, double &stopLoss, double &takeProfit, int orderType)
{
   if(price <= 0 || stopLoss <= 0 || takeProfit <= 0) return; // Valeurs invalides
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   long stopsLevelPts = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopLevel = stopsLevelPts * point;
   
   // Valeur par défaut si broker ne renvoie pas de stop level
   double defaultMinDistance = 50 * point;
   if(IsDerivSyntheticIndex(_Symbol))
      defaultMinDistance = 500 * point;
   
   if(minStopLevel <= 0)
      minStopLevel = defaultMinDistance;
   
   double minDistance = MathMax(minStopLevel, defaultMinDistance);
   
   // Boom/Crash / indices : marge minimale élevée (beaucoup de brokers exigent 100–2000 pts)
   if(StringFind(_Symbol, "Boom", 0) >= 0 || StringFind(_Symbol, "Crash", 0) >= 0 ||
      StringFind(_Symbol, "Index", 0) >= 0)
   {
      double brokerMin = (stopsLevelPts > 0) ? (double)stopsLevelPts * point : 0;
      double fallbackMin = 2000 * point; // au moins 2000 pts si broker ne donne pas
      minDistance = MathMax(minDistance, MathMax(brokerMin, fallbackMin));
      if(DebugMode)
         Print("🛡️ Indice/Boom: distance min SL/TP = ", DoubleToString(minDistance/point, 0), " pts (broker ", (int)stopsLevelPts, " pts)");
   }
   
   // Vérifier les limites de prix du broker
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(orderType == ORDER_TYPE_BUY)
   {
      // Pour BUY: SL < price < TP
      // Utiliser ASK comme référence pour les ordres BUY
      double refPrice = (price == ask || price == bid) ? ask : price;
      
      // Vérifier et corriger SL
      if(stopLoss >= refPrice)
         stopLoss = refPrice - minDistance;
      else if((refPrice - stopLoss) < minDistance)
         stopLoss = refPrice - minDistance;
      
      // Vérifier et corriger TP
      if(takeProfit <= refPrice)
         takeProfit = refPrice + minDistance;
      else if((takeProfit - refPrice) < minDistance)
         takeProfit = refPrice + minDistance;
      
      // S'assurer que SL < TP
      if(stopLoss >= takeProfit)
      {
         stopLoss = refPrice - minDistance;
         takeProfit = refPrice + (minDistance * 2.0);
      }
   }
   else // ORDER_TYPE_SELL
   {
      // Pour SELL: TP < price < SL
      // Utiliser BID comme référence pour les ordres SELL
      double refPrice = (price == ask || price == bid) ? bid : price;
      
      // Vérifier et corriger SL
      if(stopLoss <= refPrice)
         stopLoss = refPrice + minDistance;
      else if((stopLoss - refPrice) < minDistance)
         stopLoss = refPrice + minDistance;
      
      // Vérifier et corriger TP
      if(takeProfit >= refPrice)
         takeProfit = refPrice - minDistance;
      else if((refPrice - takeProfit) < minDistance)
         takeProfit = refPrice - minDistance;
      
      // S'assurer que TP < SL
      if(takeProfit >= stopLoss)
      {
         stopLoss = refPrice + minDistance;
         takeProfit = refPrice - (minDistance * 2.0);
      }
   }
   
   // Normaliser avec tickSize si disponible
   if(tickSize > 0)
   {
      stopLoss = MathRound(stopLoss / tickSize) * tickSize;
      takeProfit = MathRound(takeProfit / tickSize) * tickSize;
   }
   
   stopLoss = NormalizeDouble(stopLoss, digits);
   takeProfit = NormalizeDouble(takeProfit, digits);
   
   // Vérification finale: s'assurer que les valeurs sont valides
   if(stopLoss <= 0 || takeProfit <= 0 || stopLoss == takeProfit)
   {
      Print("⚠️ ERREUR ValidateAndAdjustStops: valeurs invalides - price=", price, " SL=", stopLoss, " TP=", takeProfit);
      // Fallback: utiliser des valeurs sûres basées sur ATR
      double atr[];
      if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
      {
         double safeDistance = atr[0] * 3.0;
         if(orderType == ORDER_TYPE_BUY)
         {
            stopLoss = price - safeDistance;
            takeProfit = price + (safeDistance * 2.0);
         }
         else
         {
            stopLoss = price + safeDistance;
            takeProfit = price - (safeDistance * 2.0);
         }
         stopLoss = NormalizeDouble(stopLoss, digits);
         takeProfit = NormalizeDouble(takeProfit, digits);
      }
   }
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
//| Compte les positions pour le symbole actuel - OPTIMISÉ           |
//+------------------------------------------------------------------+
int CountPositionsForSymbolMagic()
{
   // OPTIMISATION: Utiliser le cache pour éviter les boucles répétées
   static int cachedCount = 0;
   static datetime lastCacheUpdate = 0;
   static string lastSymbol = "";
   
   datetime currentTime = TimeCurrent();
   if(currentTime - lastCacheUpdate >= 2 || _Symbol != lastSymbol) // Mettre à jour toutes les 2 secondes ou si symbole changé
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
      cachedCount = cnt;
      lastCacheUpdate = currentTime;
      lastSymbol = _Symbol;
   }
   
   return cachedCount;
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
   bool isBoomCrash = (StringFind(_Symbol, "Boom", 0) != -1 || StringFind(_Symbol, "Crash", 0) != -1);
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
//| Calculer la perte totale de toutes les positions actives - OPTIMISÉ |
//+------------------------------------------------------------------+
double GetTotalLoss()
{
   // OPTIMISATION: Utiliser le cache déjà calculé dans OnTick()
   // Éviter une boucle PositionsTotal() supplémentaire
   static double cachedTotalLossValue = 0.0;
   static datetime lastCacheUpdate = 0;
   
   datetime currentTime = TimeCurrent();
   if(currentTime - lastCacheUpdate >= 3) // Mettre à jour toutes les 3 secondes maximum
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
      cachedTotalLossValue = totalLoss;
      lastCacheUpdate = currentTime;
   }
   
   return cachedTotalLossValue;
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
//| Déterminer le type de zone (premium/discount/neutre)              |
//+------------------------------------------------------------------+
enum ZONE_TYPE
{
    ZONE_PREMIUM,    // Zone cher (résistance forte)
    ZONE_DISCOUNT,   // Zone bon marché (support fort) 
    ZONE_NEUTRAL     // Zone neutre
};

// Fonction pour déterminer si une zone est premium, discount ou neutre
ZONE_TYPE DetermineZoneType(double zoneLow, double zoneHigh, bool isBuyZone)
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[];
   CopyBuffer(atrM1Handle, 0, 0, 1, atr);
   double atrValue = atr[0];
   
   // Calculer la distance par rapport au prix actuel
   double distanceToZone = 0.0;
   if(isBuyZone)
   {
      // Zone BUY: si très en dessous du prix = discount (bon marché)
      distanceToZone = currentPrice - zoneHigh;
   }
   else
   {
      // Zone SELL: si très au dessus du prix = premium (cher)
      distanceToZone = zoneLow - currentPrice;
   }
   
   // Déterminer le type de zone selon la distance en ATR
   double distanceInATR = distanceToZone / atrValue;
   
   if(isBuyZone)
   {
      // Zone BUY
      if(distanceInATR > 3.0)        // Plus de 3 ATR en dessous = très discount
         return ZONE_DISCOUNT;
      else if(distanceInATR < 1.0)   // Moins de 1 ATR en dessous = neutre
         return ZONE_NEUTRAL;
      else                           // Entre 1-3 ATR = premium pour BUY
         return ZONE_PREMIUM;
   }
   else
   {
      // Zone SELL
      if(distanceInATR > 3.0)        // Plus de 3 ATR au dessus = très premium
         return ZONE_PREMIUM;
      else if(distanceInATR < 1.0)   // Moins de 1 ATR au dessus = neutre
         return ZONE_NEUTRAL;
      else                           // Entre 1-3 ATR = discount pour SELL
         return ZONE_DISCOUNT;
   }
}

// Obtenir la couleur selon le type de zone
color GetZoneColor(ZONE_TYPE zoneType, bool isBuyZone)
{
   if(isBuyZone)
   {
      // Zones BUY
      switch(zoneType)
      {
         case ZONE_DISCOUNT: return C'0,200,0,80';   // Vert foncé (très bon marché)
         case ZONE_PREMIUM:   return C'255,255,0,80'; // Jaune (cher pour BUY)
         case ZONE_NEUTRAL:   return C'0,255,0,60';   // Vert normal
      }
   }
   else
   {
      // Zones SELL
      switch(zoneType)
      {
         case ZONE_PREMIUM:   return C'255,0,0,80';   // Rouge foncé (très cher)
         case ZONE_DISCOUNT:  return C'255,255,0,80'; // Jaune (bon marché pour SELL)
         case ZONE_NEUTRAL:   return C'255,0,0,60';   // Rouge normal
      }
   }
   
   return isBuyZone ? C'0,255,0,60' : C'255,0,0,60';
}

//+------------------------------------------------------------------+
//| Dessiner les zones BUY/SELL de l'IA (rectangles non remplis)     |
//+------------------------------------------------------------------+
void DrawAIZonesOnChart()
{
   if(!DrawAIZonesEnabled)
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
   
   // Timeframes à tracer: H8, H1, M5
   ENUM_TIMEFRAMES timeframes[];
   ArrayResize(timeframes, 3);
   timeframes[0] = PERIOD_H8;
   timeframes[1] = PERIOD_H1;
   timeframes[2] = PERIOD_M5;
   
   string localTfNames[];
   ArrayResize(localTfNames, 3);
   localTfNames[0] = "H8";
   localTfNames[1] = "H1";
   localTfNames[2] = "M5";
   
   // Tracer les zones pour chaque timeframe
   for(int tfIdx = 0; tfIdx < ArraySize(timeframes); tfIdx++)
   {
      ENUM_TIMEFRAMES tf = timeframes[tfIdx];
      string tfName = localTfNames[tfIdx];
      
      // Calculer les limites temporelles selon le timeframe
      int periodSeconds = PeriodSeconds(tf);
      datetime past = now - (200 * periodSeconds);   // 200 bougies en arrière
      datetime future = now + (50 * periodSeconds);  // 50 bougies en avant
      
      // Zone BUY - Rectangle avec couleur selon type (premium/discount/neutre)
      string buyZoneName = "AI_BUY_ZONE_" + tfName + "_" + _Symbol;
      if(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 && g_aiBuyZoneHigh > g_aiBuyZoneLow)
      {
         // Déterminer le type de zone
         ZONE_TYPE buyZoneType = DetermineZoneType(g_aiBuyZoneLow, g_aiBuyZoneHigh, true);
         color buyColor = GetZoneColor(buyZoneType, true);
         
         if(ObjectFind(0, buyZoneName) < 0)
            ObjectCreate(0, buyZoneName, OBJ_RECTANGLE, 0, past, g_aiBuyZoneHigh, future, g_aiBuyZoneLow);
         else
         {
            ObjectSetDouble(0, buyZoneName, OBJPROP_PRICE, 0, g_aiBuyZoneHigh);
            ObjectSetDouble(0, buyZoneName, OBJPROP_PRICE, 1, g_aiBuyZoneLow);
            ObjectSetInteger(0, buyZoneName, OBJPROP_TIME, 0, past);
            ObjectSetInteger(0, buyZoneName, OBJPROP_TIME, 1, future);
         }
         
         // Appliquer la couleur selon le type de zone
         ObjectSetInteger(0, buyZoneName, OBJPROP_COLOR, buyColor);
         ObjectSetInteger(0, buyZoneName, OBJPROP_BACK, 1);  // En arrière-plan
         ObjectSetInteger(0, buyZoneName, OBJPROP_FILL, 0); // PAS DE REMPLISSAGE
         ObjectSetInteger(0, buyZoneName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, buyZoneName, OBJPROP_WIDTH, 3); // Bord plus visible pour distinguer
         ObjectSetInteger(0, buyZoneName, OBJPROP_SELECTABLE, false);
         // Afficher uniquement sur le timeframe correspondant
         ObjectSetInteger(0, buyZoneName, OBJPROP_TIMEFRAMES, (1 << (int)tf));
         
         // Ajouter un label pour le type de zone
         string buyLabelName = "AI_BUY_LABEL_" + tfName + "_" + _Symbol;
         string zoneTypeText = "";
         switch(buyZoneType)
         {
            case ZONE_DISCOUNT: zoneTypeText = "BUY DISCOUNT"; break;
            case ZONE_PREMIUM:   zoneTypeText = "BUY PREMIUM"; break;
            case ZONE_NEUTRAL:   zoneTypeText = "BUY NEUTRAL"; break;
         }
         
         if(ObjectFind(0, buyLabelName) < 0)
            ObjectCreate(0, buyLabelName, OBJ_LABEL, 0, 0, 0);
         
         ObjectSetString(0, buyLabelName, OBJPROP_TEXT, zoneTypeText);
         ObjectSetInteger(0, buyLabelName, OBJPROP_XDISTANCE, 50);
         ObjectSetInteger(0, buyLabelName, OBJPROP_YDISTANCE, 50 + (tfIdx * 25));
         ObjectSetInteger(0, buyLabelName, OBJPROP_COLOR, buyColor);
         ObjectSetString(0, buyLabelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, buyLabelName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, buyLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, buyLabelName, OBJPROP_TIMEFRAMES, (1 << (int)tf));
      }
      else
      {
         ObjectDelete(0, buyZoneName);
         ObjectDelete(0, "AI_BUY_LABEL_" + tfName + "_" + _Symbol);
      }
      
      // Zone SELL - Rectangle avec couleur selon type (premium/discount/neutre)
      string sellZoneName = "AI_SELL_ZONE_" + tfName + "_" + _Symbol;
      if(g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0 && g_aiSellZoneHigh > g_aiSellZoneLow)
      {
         // Déterminer le type de zone
         ZONE_TYPE sellZoneType = DetermineZoneType(g_aiSellZoneLow, g_aiSellZoneHigh, false);
         color sellColor = GetZoneColor(sellZoneType, false);
         
         if(ObjectFind(0, sellZoneName) < 0)
            ObjectCreate(0, sellZoneName, OBJ_RECTANGLE, 0, past, g_aiSellZoneHigh, future, g_aiSellZoneLow);
         else
         {
            ObjectSetDouble(0, sellZoneName, OBJPROP_PRICE, 0, g_aiSellZoneHigh);
            ObjectSetDouble(0, sellZoneName, OBJPROP_PRICE, 1, g_aiSellZoneLow);
            ObjectSetInteger(0, sellZoneName, OBJPROP_TIME, 0, past);
            ObjectSetInteger(0, sellZoneName, OBJPROP_TIME, 1, future);
         }
         
         // Appliquer la couleur selon le type de zone
         ObjectSetInteger(0, sellZoneName, OBJPROP_COLOR, sellColor);
         ObjectSetInteger(0, sellZoneName, OBJPROP_BACK, 1);  // En arrière-plan
         ObjectSetInteger(0, sellZoneName, OBJPROP_FILL, 0); // PAS DE REMPLISSAGE
         ObjectSetInteger(0, sellZoneName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, sellZoneName, OBJPROP_WIDTH, 3); // Bord plus visible pour distinguer
         ObjectSetInteger(0, sellZoneName, OBJPROP_SELECTABLE, false);
         // Afficher uniquement sur le timeframe correspondant
         ObjectSetInteger(0, sellZoneName, OBJPROP_TIMEFRAMES, (1 << (int)tf));
         
         // Ajouter un label pour le type de zone
         string sellLabelName = "AI_SELL_LABEL_" + tfName + "_" + _Symbol;
         string zoneTypeText = "";
         switch(sellZoneType)
         {
            case ZONE_PREMIUM:   zoneTypeText = "SELL PREMIUM"; break;
            case ZONE_DISCOUNT:  zoneTypeText = "SELL DISCOUNT"; break;
            case ZONE_NEUTRAL:   zoneTypeText = "SELL NEUTRAL"; break;
         }
         
         if(ObjectFind(0, sellLabelName) < 0)
            ObjectCreate(0, sellLabelName, OBJ_LABEL, 0, 0, 0);
         
         ObjectSetString(0, sellLabelName, OBJPROP_TEXT, zoneTypeText);
         ObjectSetInteger(0, sellLabelName, OBJPROP_XDISTANCE, 50);
         ObjectSetInteger(0, sellLabelName, OBJPROP_YDISTANCE, 125 + (tfIdx * 25)); // Décalé pour ne pas chevaucher les BUY
         ObjectSetInteger(0, sellLabelName, OBJPROP_COLOR, sellColor);
         ObjectSetString(0, sellLabelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, sellLabelName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, sellLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, sellLabelName, OBJPROP_TIMEFRAMES, (1 << (int)tf));
      }
      else
      {
         ObjectDelete(0, sellZoneName);
         ObjectDelete(0, "AI_SELL_LABEL_" + tfName + "_" + _Symbol);
      }
   }
}

//+------------------------------------------------------------------+
//| Dessiner les trendlines basées sur les EMA M5 et H1              |
//| Depuis l'historique de 1000 bougies                              |
//+------------------------------------------------------------------+
void DrawTrendlinesOnChart()
{
   if(!DrawTrendlinesEnabled)
      return;
   
   // Version simplifiée et fonctionnelle pour éviter les erreurs
   static datetime lastDraw = 0;
   if(TimeCurrent() - lastDraw < 60) // Une fois par minute
      return;
   
   lastDraw = TimeCurrent();
   
   // Détecter le timeframe actuel
   ENUM_TIMEFRAMES tf = Period();
   
   // Utiliser les EMA du timeframe actuel
   double emaFast[1], emaSlow[1];
   int fastHandle, slowHandle;
   
   switch(tf)
   {
      case PERIOD_M1:
      case PERIOD_M5:
         fastHandle = emaFastM5Handle;
         slowHandle = emaSlowM5Handle;
         break;
      case PERIOD_M15:
         fastHandle = emaFastHandle;
         slowHandle = emaSlowHandle;
         break;
      case PERIOD_M30:
         fastHandle = emaFastHandle;
         slowHandle = emaSlowHandle;
         break;
      case PERIOD_H1:
         fastHandle = emaFastH1Handle;
         slowHandle = emaSlowH1Handle;
         break;
      default:
         fastHandle = emaFastHandle;
         slowHandle = emaSlowHandle;
         break;
   }
   
   // Copier les valeurs EMA
   if(CopyBuffer(fastHandle, 0, 0, 1, emaFast) > 0 &&
      CopyBuffer(slowHandle, 0, 0, 1, emaSlow) > 0)
   {
      datetime currentTime = TimeCurrent();
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // Définir une longueur fixe pour toutes les trendlines (100 barres dans le futur)
      datetime futureTime = currentTime + (PeriodSeconds(tf) * 100);
      
      // Détecter le croisement
      string trendlineName = "";
      color trendColor = clrYellow;
      
      if(emaFast[0] > emaSlow[0])
      {
         // Trend haussier - ligne de support
         trendlineName = "TRENDLINE_SUPPORT_" + IntegerToString((int)currentTime);
         trendColor = clrLime;
      }
      else if(emaFast[0] < emaSlow[0])
      {
         // Trend baissier - ligne de résistance
         trendlineName = "TRENDLINE_RESISTANCE_" + IntegerToString((int)currentTime);
         trendColor = clrRed;
      }
      
      // Dessiner la trendline avec longueur fixe
      if(trendlineName != "")
      {
         // Supprimer l'ancienne trendline du même type
         ObjectDelete(0, trendlineName);
         
         if(ObjectCreate(0, trendlineName, OBJ_TREND, 0, currentTime, currentPrice, futureTime, currentPrice))
         {
            ObjectSetInteger(0, trendlineName, OBJPROP_COLOR, trendColor);
            ObjectSetInteger(0, trendlineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, trendlineName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, trendlineName, OBJPROP_RAY_RIGHT, false); // Pas de ray pour longueur fixe
            ObjectSetString(0, trendlineName, OBJPROP_TEXT, emaFast[0] > emaSlow[0] ? "SUPPORT" : "RESISTANCE");
            ObjectSetInteger(0, trendlineName, OBJPROP_BACK, false);
         }
      }
      
      // AJOUT: Indiquer les points futurs de log buy/sell
      DrawFutureLogPoints(currentTime, futureTime, currentPrice, emaFast[0] > emaSlow[0]);
      
      if(DebugMode)
         Print("📈 Trendline dessinée: ", emaFast[0] > emaSlow[0] ? "SUPPORT" : "RESISTANCE", 
               " | EMA Fast: ", DoubleToString(emaFast[0], _Digits),
               " | EMA Slow: ", DoubleToString(emaSlow[0], _Digits));
   }
}

//+------------------------------------------------------------------+
//| Dessiner les points futurs de log buy/sell sur les trendlines    |
//+------------------------------------------------------------------+
void DrawFutureLogPoints(datetime startTime, datetime endTime, double basePrice, bool isUptrend)
{
   // Calculer 3 points futurs où des log buy/sell pourraient se produire
   int numPoints = 3;
   datetime timeInterval = (endTime - startTime) / (numPoints + 1);
   
   for(int i = 1; i <= numPoints; i++)
   {
      datetime pointTime = startTime + (timeInterval * i);
      double pointPrice = basePrice;
      
      // Ajuster le prix selon la tendance et le type de point
      string pointName = "";
      string labelText = "";
      color pointColor = clrWhite;
      
      if(isUptrend)
      {
         // En tendance haussière: chercher des points de log buy sur les replis
         if(i % 2 == 1) // Points impairs = log buy
         {
            pointPrice = basePrice - (i * 0.001); // Légèrement en dessous
            pointName = "FUTURE_LOG_BUY_" + IntegerToString((int)pointTime);
            labelText = "🟢 LOG BUY";
            pointColor = clrLime;
         }
         else // Points pairs = log sell (prise de profit)
         {
            pointPrice = basePrice + (i * 0.001); // Légèrement au-dessus
            pointName = "FUTURE_LOG_SELL_" + IntegerToString((int)pointTime);
            labelText = "🔴 LOG SELL";
            pointColor = clrRed;
         }
      }
      else
      {
         // En tendance baissière: chercher des points de log sell sur les rebonds
         if(i % 2 == 1) // Points impairs = log sell
         {
            pointPrice = basePrice + (i * 0.001); // Légèrement au-dessus
            pointName = "FUTURE_LOG_SELL_" + IntegerToString((int)pointTime);
            labelText = "🔴 LOG SELL";
            pointColor = clrRed;
         }
         else // Points pairs = log buy (prise de profit)
         {
            pointPrice = basePrice - (i * 0.001); // Légèrement en dessous
            pointName = "FUTURE_LOG_BUY_" + IntegerToString((int)pointTime);
            labelText = "🟢 LOG BUY";
            pointColor = clrLime;
         }
      }
      
      // Dessiner le point futur
      string arrowName = pointName + "_ARROW";
      if(ObjectFind(0, arrowName) < 0)
      {
         ObjectCreate(0, arrowName, OBJ_ARROW, 0, pointTime, pointPrice);
         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, pointColor);
         ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, isUptrend ? 233 : 234); // Flèche haut/bas
         ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      }
      else
      {
         ObjectSetInteger(0, arrowName, OBJPROP_TIME, pointTime);
         ObjectSetDouble(0, arrowName, OBJPROP_PRICE, pointPrice);
      }
      
      // Ajouter un label text
      string labelName = pointName + "_LABEL";
      if(ObjectFind(0, labelName) < 0)
      {
         ObjectCreate(0, labelName, OBJ_TEXT, 0, pointTime, pointPrice);
         ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, pointColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, isUptrend ? ANCHOR_TOP : ANCHOR_BOTTOM);
         ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
      }
      else
      {
         ObjectSetInteger(0, labelName, OBJPROP_TIME, pointTime);
         ObjectSetDouble(0, labelName, OBJPROP_PRICE, pointPrice);
      }
   }
   
   if(DebugMode)
      Print("🎯 Points futurs log buy/sell dessinés: ", numPoints, " points pour tendance ", isUptrend ? "haussière" : "baissière");
}

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
   
   // OPTIMISATION: Cache pour les EMA longues tendances
   static datetime lastEMAUpdate = 0;
   static double cachedEma50[], cachedEma100[], cachedEma200[];
   static datetime cachedTime[];
   static bool emaCacheInitialized = false;
   
   // Initialiser le cache une seule fois
   if(!emaCacheInitialized)
   {
      ArrayResize(cachedEma50, 2000);
      ArrayResize(cachedEma100, 2000);
      ArrayResize(cachedEma200, 2000);
      ArrayResize(cachedTime, 2000);
      ArraySetAsSeries(cachedEma50, true);
      ArraySetAsSeries(cachedEma100, true);
      ArraySetAsSeries(cachedEma200, true);
      ArraySetAsSeries(cachedTime, true);
      emaCacheInitialized = true;
   }
   
   datetime currentTime = TimeCurrent();
   double ema50[], ema100[], ema200[];
   datetime time[];
   ArraySetAsSeries(ema50, true);
   ArraySetAsSeries(ema100, true);
   ArraySetAsSeries(ema200, true);
   ArraySetAsSeries(time, true);
   
   // Mettre à jour le cache seulement toutes les 30 secondes
   if(currentTime - lastEMAUpdate >= 30)
   {
      
      // OPTIMISATION: Limiter à 500 bougies passées + 500 futures en mode haute perf
      int count = (HighPerformanceMode ? 500 : 1000);
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
      
      // Bougies passées
      if(CopyTime(_Symbol, PERIOD_M1, 0, count, timePast) <= 0)
      {
         if(DebugMode)
            Print("⚠️ Erreur récupération timestamps passés pour EMA longues");
         return;
      }
      
      // Créer timestamps futurs (projection)
      datetime lastTime = timePast[count-1];
      ArrayResize(timeFuture, count);
      for(int i = 0; i < count; i++)
      {
         timeFuture[i] = lastTime + (i+1) * PeriodSeconds(PERIOD_M1);
      }
      
      // Combiner les deux arrays
      ArrayResize(time, count * 2);
      for(int i = 0; i < count; i++)
         time[i] = timePast[i];
      for(int i = 0; i < count; i++)
         time[count + i] = timeFuture[i];
      
      // Mettre en cache
      ArrayCopy(cachedEma50, ema50, 0, 0, count);
      ArrayCopy(cachedEma100, ema100, 0, 0, count);
      ArrayCopy(cachedEma200, ema200, 0, 0, count);
      ArrayCopy(cachedTime, time, 0, 0, count * 2);
      
      lastEMAUpdate = currentTime;
   }
   
   // Utiliser les données en cache
   ArrayResize(ema50, ArraySize(cachedEma50));
   ArrayResize(ema100, ArraySize(cachedEma100));
   ArrayResize(ema200, ArraySize(cachedEma200));
   ArrayResize(time, ArraySize(cachedTime));
   ArrayCopy(ema50, cachedEma50);
   ArrayCopy(ema100, cachedEma100);
   ArrayCopy(ema200, cachedEma200);
   ArrayCopy(time, cachedTime);
   
   // OPTIMISATION MAXIMALE: Ne supprimer et recréer que si nécessaire (vérifier timestamp)
   bool needUpdate = (TimeCurrent() - lastEMAUpdate > 300); // Mise à jour max toutes les 5 minutes (au lieu de 2)
   
   if(needUpdate)
   {
      // Supprimer les anciens segments seulement si nécessaire
      DeleteEMAObjects("EMA_50_");
      DeleteEMAObjects("EMA_100_");
      DeleteEMAObjects("EMA_200_");
      
      // OPTIMISATION MAXIMALE: Créer des courbes avec 1000 bougies passées + 1000 futures
      // Étendre les arrays EMA pour inclure les projections futures
      int currentSize = ArraySize(ema50);
      if(currentSize < 1000)
      {
         if(DebugMode)
            Print("⚠️ Pas assez de données EMA pour projection (", currentSize, " < 1000)");
         return;
      }
      
      ArrayResize(ema50, 2000);
      ArrayResize(ema100, 2000);
      ArrayResize(ema200, 2000);
      
      // Projeter les EMA dans le futur (extrapolation simple)
      double ema50Slope = (ema50[999] - ema50[900]) / 100.0; // Pente sur 100 dernières bougies
      double ema100Slope = (ema100[999] - ema100[900]) / 100.0;
      double ema200Slope = (ema200[999] - ema200[900]) / 100.0;
      
      // OPTIMISATION: Réduire les itérations de 1000 à 500 pour économiser CPU
      for(int i = 1000; i < 1500; i++) // 500 au lieu de 1000
      {
         ema50[i] = ema50[999] + (i - 999) * ema50Slope;
         ema100[i] = ema100[999] + (i - 999) * ema100Slope;
         ema200[i] = ema200[999] + (i - 999) * ema200Slope;
      }
      
      // Réduire aussi les points dessinés de 2000 à 1500
      DrawEMACurveOptimized("EMA_50_", ema50, time, 1500, clrLime, 1, 20);
      DrawEMACurveOptimized("EMA_100_", ema100, time, 1500, clrYellow, 1, 20);
      DrawEMACurveOptimized("EMA_200_", ema200, time, 1500, clrOrange, 1, 20);
      
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
   
   // OPTIMISATION: Réduire la plage de bougies analysées
   int maxBars = MathMin(bars - 5, 50); // Limiter à 50 bougies max
   for(int i = 5; i < maxBars; i++)
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
            ObjectSetInteger(0, obName, OBJPROP_FILL, 0); // PAS DE REMPLISSAGE
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
            ObjectSetInteger(0, obName, OBJPROP_FILL, 0); // PAS DE REMPLISSAGE
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
   
   // Nettoyer SEULEMENT les anciennes prédictions (garder la zone permanente)
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      // Nettoyer UNIQUEMENT les anciennes prédictions (garder la zone permanente)
      if(StringFind(name, "PREDICTION_") == 0)
      {
         // Garder la zone de prédiction permanente - ne pas supprimer
         if(StringFind(name, "ZONE") >= 0)
         {
            // Garder les zones permanentes
            continue;
         }
         // Supprimer seulement les prédictions temporaires
         ObjectDelete(0, name);
      }
      // Nettoyer les autres objets temporaires
      else if(StringFind(name, "FUTURE_CANDLES_") == 0 ||
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
   
   // NOUVEAU: Analyser la tendance récente pour adapter la prédiction
   double recentTrend = 0.0;
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, PERIOD_M1, 0, 20, close) >= 20)
   {
      // Calculer la pente des 20 dernières bougies
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for(int j = 0; j < 20; j++)
      {
         sumX += j;
         sumY += close[j];
         sumXY += j * close[j];
         sumX2 += j * j;
      }
      // Formule de régression linéaire: pente = (n*sumXY - sumX*sumY) / (n*sumX2 - sumX*sumX)
      recentTrend = (20 * sumXY - sumX * sumY) / (20 * sumX2 - sumX * sumX);
      recentTrend = recentTrend / currentPrice; // Normaliser en pourcentage
   }
   
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
      
      // NOUVEAU: Adapter la prédiction à la tendance récente
      double trendAdjustment = recentTrend * currentPrice * progress * 0.5; // 50% de la tendance récente progressivement
      
      // Appliquer l'accélération progressive et l'ajustement de tendance
      double priceMove = baseMove * accelerationFactor + trendAdjustment;
      
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
   
   // Dessiner le canal de prédiction avec zone remplie et niveaux upper/lower visibles
   string channelHighName = "PREDICTION_CHANNEL_HIGH_" + _Symbol;
   string channelLowName = "PREDICTION_CHANNEL_LOW_" + _Symbol;
   string channelZoneName = "PREDICTION_CHANNEL_ZONE_" + _Symbol;
   
   // Canal supérieur (ligne upper) - plus visible
   if(ObjectCreate(0, channelHighName, OBJ_TREND, 0, futureTime[0], channelHigh[0], futureTime[999], channelHigh[999]))
   {
      color upperColor = StringCompare(direction, "buy") == 0 ? (UseMutedColors ? MUTED_BLUE : clrDodgerBlue) : (UseMutedColors ? MUTED_RED : clrOrangeRed);
      ObjectSetInteger(0, channelHighName, OBJPROP_COLOR, upperColor);
      ObjectSetInteger(0, channelHighName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, channelHighName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, channelHighName, OBJPROP_BACK, false);
      ObjectSetString(0, channelHighName, OBJPROP_TEXT, "Upper Level");
   }
   
   // Canal inférieur (ligne lower) - plus visible
   if(ObjectCreate(0, channelLowName, OBJ_TREND, 0, futureTime[0], channelLow[0], futureTime[999], channelLow[999]))
   {
      color lowerColor = StringCompare(direction, "buy") == 0 ? (UseMutedColors ? MUTED_BLUE : clrDodgerBlue) : (UseMutedColors ? MUTED_RED : clrOrangeRed);
      ObjectSetInteger(0, channelLowName, OBJPROP_COLOR, lowerColor);
      ObjectSetInteger(0, channelLowName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, channelLowName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, channelLowName, OBJPROP_BACK, false);
      ObjectSetString(0, channelLowName, OBJPROP_TEXT, "Lower Level");
   }
   
   // Zone remplie du canal (rectangle pour visualiser la zone entre upper et lower)
   // Dessiner plusieurs rectangles pour créer une zone remplie progressive
   int zoneSegments = 50; // Nombre de segments pour la zone
   for(int seg = 0; seg < zoneSegments; seg++)
   {
      int idx1 = (seg * 1000) / zoneSegments;
      int idx2 = ((seg + 1) * 1000) / zoneSegments;
      if(idx2 >= 1000) idx2 = 999;
      
      string zoneSegName = channelZoneName + "_SEG_" + IntegerToString(seg);
      if(ObjectCreate(0, zoneSegName, OBJ_RECTANGLE, 0, futureTime[idx1], channelHigh[idx1], futureTime[idx2], channelLow[idx1]))
      {
         color zoneColor = StringCompare(direction, "buy") == 0 ? (UseMutedColors ? MUTED_BLUE : clrLightBlue) : (UseMutedColors ? MUTED_RED : clrLightPink);
         ObjectSetInteger(0, zoneSegName, OBJPROP_COLOR, zoneColor);
         ObjectSetInteger(0, zoneSegName, OBJPROP_BACK, true);
         ObjectSetInteger(0, zoneSegName, OBJPROP_FILL, false); // PAS DE REMPLISSAGE
         ObjectSetInteger(0, zoneSegName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, zoneSegName, OBJPROP_WIDTH, 1);
      }
   }
   
   // Labels pour les niveaux upper et lower
   string upperLabelName = "PREDICTION_UPPER_LABEL_" + _Symbol;
   string lowerLabelName = "PREDICTION_LOWER_LABEL_" + _Symbol;
   
   // Label niveau upper (milieu du canal)
   int midIdx = 500;
   if(ObjectCreate(0, upperLabelName, OBJ_TEXT, 0, futureTime[midIdx], channelHigh[midIdx]))
   {
      ObjectSetString(0, upperLabelName, OBJPROP_TEXT, "Upper: " + DoubleToString(channelHigh[midIdx], _Digits));
      ObjectSetInteger(0, upperLabelName, OBJPROP_COLOR, StringCompare(direction, "buy") == 0 ? (UseMutedColors ? MUTED_BLUE : clrDodgerBlue) : (UseMutedColors ? MUTED_RED : clrOrangeRed));
      ObjectSetInteger(0, upperLabelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, upperLabelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, upperLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   
   // Label niveau lower (milieu du canal)
   if(ObjectCreate(0, lowerLabelName, OBJ_TEXT, 0, futureTime[midIdx], channelLow[midIdx]))
   {
      ObjectSetString(0, lowerLabelName, OBJPROP_TEXT, "Lower: " + DoubleToString(channelLow[midIdx], _Digits));
      ObjectSetInteger(0, lowerLabelName, OBJPROP_COLOR, StringCompare(direction, "buy") == 0 ? (UseMutedColors ? MUTED_BLUE : clrDodgerBlue) : (UseMutedColors ? MUTED_RED : clrOrangeRed));
      ObjectSetInteger(0, lowerLabelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, lowerLabelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, lowerLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
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
   
   // NOUVEAU: Analyser la tendance récente pour adapter les bougies futures
   double recentTrend = 0.0;
   double close[];
   ArraySetAsSeries(close, true);
   if(CopyClose(_Symbol, currentTF, 0, 20, close) >= 20)
   {
      // Calculer la pente des 20 dernières bougies
      double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
      for(int j = 0; j < 20; j++)
      {
         sumX += j;
         sumY += close[j];
         sumXY += j * close[j];
         sumX2 += j * j;
      }
      // Formule de régression linéaire: pente = (n*sumXY - sumX*sumY) / (n*sumX2 - sumX*sumX)
      recentTrend = (20 * sumXY - sumX * sumY) / (20 * sumX2 - sumX * sumX);
      recentTrend = recentTrend / currentPrice; // Normaliser en pourcentage
   }
   
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
      
      // NOUVEAU: Adapter la prédiction à la tendance récente
      double trendAdjustment = recentTrend * currentPrice * progress * 0.3; // 30% de la tendance récente progressivement
      
      // Cycles de marché: amplitude proportionnelle au range moyen
      double marketCycle = MathSin(progress * 3.14159265359 * 3.0) * avgRange * 0.35;
      
      // Prix de prédiction central avec ajustement de tendance
      predictionPrices[i] = currentPrice + baseMove + marketCycle + trendAdjustment;
      
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
      bool isBoomSymbol = (StringFind(_Symbol, "Boom", 0) != -1);
      bool isCrashSymbol = (StringFind(_Symbol, "Crash", 0) != -1);
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
   
   // CANAL VISUEL AVEC ZONE REMPLIE ET NIVEAUX UPPER/LOWER
   string channelHighName = "FUTURE_CANDLES_CHANNEL_HIGH_" + _Symbol;
   string channelLowName = "FUTURE_CANDLES_CHANNEL_LOW_" + _Symbol;
   string channelZoneName = "FUTURE_CANDLES_CHANNEL_ZONE_" + _Symbol;
   
   color channelColor = StringCompare(direction, "buy") == 0 ? 
                        (UseMutedColors ? MUTED_BLUE : clrDodgerBlue) : 
                        (UseMutedColors ? MUTED_RED : clrOrangeRed);
   
   // Canal supérieur (ligne upper) - plus visible
   if(ObjectCreate(0, channelHighName, OBJ_TREND, 0, predictionTimes[0], channelHighs[0], predictionTimes[candleCount-1], channelHighs[candleCount-1]))
   {
      ObjectSetInteger(0, channelHighName, OBJPROP_COLOR, channelColor);
      ObjectSetInteger(0, channelHighName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, channelHighName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, channelHighName, OBJPROP_BACK, false);
      ObjectSetString(0, channelHighName, OBJPROP_TEXT, "Upper Level");
   }
   
   // Canal inférieur (ligne lower) - plus visible
   if(ObjectCreate(0, channelLowName, OBJ_TREND, 0, predictionTimes[0], channelLows[0], predictionTimes[candleCount-1], channelLows[candleCount-1]))
   {
      ObjectSetInteger(0, channelLowName, OBJPROP_COLOR, channelColor);
      ObjectSetInteger(0, channelLowName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, channelLowName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, channelLowName, OBJPROP_BACK, false);
      ObjectSetString(0, channelLowName, OBJPROP_TEXT, "Lower Level");
   }
   
   // Zone remplie du canal (limiter à 15 segments pour réduire charge CPU)
   int zoneSegments = MathMin(15, candleCount / 2); // Moins de segments = moins de charge
   for(int seg = 0; seg < zoneSegments; seg++)
   {
      int idx1 = (seg * candleCount) / zoneSegments;
      int idx2 = ((seg + 1) * candleCount) / zoneSegments;
      if(idx2 >= candleCount) idx2 = candleCount - 1;
      
      string zoneSegName = channelZoneName + "_SEG_" + IntegerToString(seg);
      datetime segStart = predictionTimes[idx1];
      datetime segEnd = predictionTimes[idx2];
      
      // Utiliser les prix moyens du segment pour créer un rectangle
      double segHigh = MathMax(channelHighs[idx1], channelHighs[idx2]);
      double segLow = MathMin(channelLows[idx1], channelLows[idx2]);
      
      if(ObjectCreate(0, zoneSegName, OBJ_RECTANGLE, 0, segStart, segHigh, segEnd, segLow))
      {
         color zoneFillColor = StringCompare(direction, "buy") == 0 ? 
                              (UseMutedColors ? (color)C'30,60,90' : clrLightBlue) : 
                              (UseMutedColors ? (color)C'90,60,30' : clrLightPink);
         ObjectSetInteger(0, zoneSegName, OBJPROP_COLOR, zoneFillColor);
         ObjectSetInteger(0, zoneSegName, OBJPROP_BACK, true);
         ObjectSetInteger(0, zoneSegName, OBJPROP_FILL, false); // PAS DE REMPLISSAGE
         ObjectSetInteger(0, zoneSegName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, zoneSegName, OBJPROP_WIDTH, 1);
      }
   }
   
   // Labels pour les niveaux upper et lower (milieu du canal)
   int midIdx = candleCount / 2;
   string upperLabelName = "FUTURE_CANDLES_UPPER_LABEL_" + _Symbol;
   string lowerLabelName = "FUTURE_CANDLES_LOWER_LABEL_" + _Symbol;
   
   // Label niveau upper
   if(ObjectCreate(0, upperLabelName, OBJ_TEXT, 0, predictionTimes[midIdx], channelHighs[midIdx]))
   {
      ObjectSetString(0, upperLabelName, OBJPROP_TEXT, "Upper: " + DoubleToString(channelHighs[midIdx], _Digits));
      ObjectSetInteger(0, upperLabelName, OBJPROP_COLOR, channelColor);
      ObjectSetInteger(0, upperLabelName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, upperLabelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, upperLabelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, upperLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
   }
   
   // Label niveau lower
   if(ObjectCreate(0, lowerLabelName, OBJ_TEXT, 0, predictionTimes[midIdx], channelLows[midIdx]))
   {
      ObjectSetString(0, lowerLabelName, OBJPROP_TEXT, "Lower: " + DoubleToString(channelLows[midIdx], _Digits));
      ObjectSetInteger(0, lowerLabelName, OBJPROP_COLOR, channelColor);
      ObjectSetInteger(0, lowerLabelName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, lowerLabelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, lowerLabelName, OBJPROP_BACK, false);
      ObjectSetInteger(0, lowerLabelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
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
      bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom", 0) != -1 || StringFind(_Symbol, "Crash", 0) != -1);
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
   // NOUVEAU: Une seule position par symbole (ordre limite ou marché)
   bool hasPositionOnCurrentSymbol = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Magic() == InpMagicNumber && positionInfo.Symbol() == _Symbol)
         {
            hasPositionOnCurrentSymbol = true;
            break;
         }
      }
   }
   
   // Si déjà une position sur ce symbole, ne pas trader
   if(hasPositionOnCurrentSymbol)
   {
      if(DebugMode)
         Print("🚫 POSITION EXISTANTE: déjà une position sur ", _Symbol, " - trade future candles annulé");
      return;
   }
   
   // NOUVEAU: Limiter à 3 symboles maximum simultanément
   int activeSymbols = CountActiveSymbols();
   if(activeSymbols >= 3)
   {
      if(DebugMode)
         Print("🚫 LIMITE ATTEINTE: ", activeSymbols, "/3 symboles actifs - trade future candles annulé sur ", _Symbol);
      return;
   }
   
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
   
   // TOUJOURS utiliser le lot minimal du broker
   double lotSize = NormalizeLotSize(InitialLotSize);
   
   if(DebugMode)
      Print("🔧 Future Candles: lot minimal utilisé: ", DoubleToString(lotSize, 2), " (confiance: ", DoubleToString(confidence*100, 1), "%)");
   
   // Valider SL/TP avec prix d'exécution réel (ASK/BID) pour éviter "Invalid stops"
   double execPrice = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   ValidateAndAdjustStops(execPrice, stopLoss, takeProfit, orderType);
   
   string orderComment = "Future Candles AI - " + (direction == "buy" ? "BUY" : "SELL") + " (conf: " + DoubleToString(confidence*100, 1) + "%)";
   
   if(orderType == ORDER_TYPE_BUY)
   {
      if(!DisableNotifications)
      {
         string notificationText = "🚀 BUY Future Candles AI\n" + _Symbol + " @ " + DoubleToString(currentPrice, _Digits) + "\nConfiance: " + DoubleToString(confidence*100, 1) + "%\n🎯 Position OUVERTE IMMÉDIATEMENT";
         SendNotification(notificationText);
         Alert(notificationText);
      }
      
      if(trade.Buy(lotSize, _Symbol, 0, stopLoss, takeProfit, orderComment))
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
      
      if(trade.Sell(lotSize, _Symbol, 0, stopLoss, takeProfit, orderComment))
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
   
   // Vérification supplémentaire que la position existe toujours
   if(!PositionSelectByTicket(ticket))
   {
      if(DebugMode)
         Print("⚠️ SecureProfit: Position ", ticket, " n'existe plus");
      return;
   }
   
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
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
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
                              trade.SetExpertMagicNumber(InpMagicNumber);
                              trade.SetMarginMode();
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
                              trade.SetExpertMagicNumber(InpMagicNumber);
                              trade.SetMarginMode();
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
   bool isBoom = (StringFind(_Symbol, "Boom", 0) != -1);
   bool isCrash = (StringFind(_Symbol, "Crash", 0) != -1);
   
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
   bool isBoom = (StringFind(_Symbol, "Boom", 0) != -1);
   bool isCrash = (StringFind(_Symbol, "Crash", 0) != -1);
   
   // Obtenir le prix actuel pour l'exécution
   double currentPrice = SymbolInfoDouble(_Symbol, (orderType == ORDER_TYPE_BUY) ? SYMBOL_ASK : SYMBOL_BID);
   
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
   
   ExecuteTrade(orderType, currentPrice);

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
//| VALIDATION D'ENTRÉE DANS UNE ZONE IA                              |
//+------------------------------------------------------------------+
bool ZoneEntryValidation(ENUM_ORDER_TYPE orderType, double currentPrice)
{
   bool isInZone = false;
   
   // Récupérer les prix récents pour analyser l'entrée dans la zone
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
         else if(currentPrice <= (g_aiBuyZoneLow + 5 * _Point) && currentPrice > g_aiBuyZoneLow)
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
   
   // Toutes les conditions sont remplies
   if(DebugMode)
   {
      Print("✅ ", EnumToString(orderType), " confirmé: Prix dans zone IA + Entrée depuis bonne direction");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| FONCTION AMÉLIORÉE POUR REQUÊTES HTTP AVEC RETRY                |
//+------------------------------------------------------------------+
string MakeHTTPRequest(string url, string method, string data = "", int maxRetries = 2)
{
   string headers = "Content-Type: application/json\r\n";
   uchar post_data[];
   string result = "";
   
   if(data != "")
      StringToCharArray(data, post_data);
   
   // Retry avec backoff exponentiel
   for(int attempt = 0; attempt <= maxRetries; attempt++)
   {
      if(attempt > 0)
      {
         // Backoff exponentiel: 1s, 2s, 4s...
         int waitTime = (int)MathPow(2, attempt - 1) * 1000;
         if(DebugMode)
            Print("🔄 Retry ", attempt, "/", maxRetries, " - Attente ", waitTime, "ms pour ", url);
         
         Sleep(waitTime);
      }
      
      uchar result_data[];
      string result_headers;
      int responseCode = WebRequest(method, url, headers, 5000, post_data, result_data, result_headers);
      
      if(responseCode == 200)
      {
         result = CharArrayToString(result_data);
         if(DebugMode && attempt > 0)
            Print("✅ Succès au retry ", attempt, " pour ", url);
         return result;
      }
      else if(responseCode == 422 || responseCode == 500 || responseCode == 502 || responseCode == 503)
      {
         if(DebugMode)
            Print("⚠️ Erreur ", responseCode, " - Tentative ", attempt + 1, "/", maxRetries + 1, " pour ", url);
         
         // Si c'est le dernier retry et que c'est une URL Render, essayer le fallback local
         if(attempt == maxRetries && UseLocalFallback && StringFind(url, "onrender.com", 0) != -1)
         {
            string localURL = GetLocalFallbackURL(url);
            if(localURL != "")
            {
               Print("🔄 Render échoué - Tentative fallback vers local: ", localURL);
               string localResult = MakeHTTPRequest(localURL, method, data, 1); // 1 seul retry pour local
               if(localResult != "")
               {
                  Print("✅ Fallback local réussi pour ", url);
                  return localResult;
               }
               else
               {
                  Print("❌ Fallback local échoué aussi");
               }
            }
         }
         
         // Si c'est le dernier retry, retourner une chaîne vide
         if(attempt == maxRetries)
         {
            Print("❌ Échec total après ", maxRetries + 1, " tentatives pour ", url, " (Code: ", responseCode, ")");
            return "";
         }
      }
      else
      {
         // Erreurs non réessayables (404, 401, etc.)
         Print("❌ Erreur fatale ", responseCode, " pour ", url);
         return "";
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| OBTENIR L'URL DE FALLBACK LOCAL CORRESPONDANTE                   |
//+------------------------------------------------------------------+
string GetLocalFallbackURL(string renderURL)
{
   // Mapper les URLs Render vers les URLs locales
   if(StringFind(renderURL, "/decision", 0) != -1)
      return AI_LocalServerURL;
   else if(StringFind(renderURL, "/analysis", 0) != -1)
      return AI_LocalAnalysisURL;
   else if(StringFind(renderURL, "/trend", 0) != -1)
      return TrendLocalURL;
   else if(StringFind(renderURL, "/predict", 0) != -1)
      return AI_LocalPredictURL;
   else if(StringFind(renderURL, "/coherent-analysis", 0) != -1)
      return AI_LocalCoherentURL;
   else if(StringFind(renderURL, "/ml/predict", 0) != -1)
      return AI_LocalMLURL;
   
   return "";
}

//+------------------------------------------------------------------+
//| DESSINER LES INDICATEURS TECHNIQUES                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| DESSINER LES TRENDLINES                                          |
//+------------------------------------------------------------------+
bool DrawTrendlinesGraphics()
{
   if(DisableAllGraphics || !DrawTrendlinesEnabled) return true;
   
   ObjectsDeleteAll(0, "TRENDLINE_");
   
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   ENUM_TIMEFRAMES tf = PERIOD_H1;
   int nBars = 50;
   if(CopyHigh(_Symbol, PERIOD_H1, 0, nBars, high) < nBars ||
      CopyLow(_Symbol, PERIOD_H1, 0, nBars, low) < nBars ||
      CopyClose(_Symbol, PERIOD_H1, 0, nBars, close) < nBars)
   {
      tf = _Period;
      nBars = MathMin(50, Bars(_Symbol, tf));
      if(nBars < 20 || CopyHigh(_Symbol, tf, 0, nBars, high) < nBars ||
         CopyLow(_Symbol, tf, 0, nBars, low) < nBars ||
         CopyClose(_Symbol, tf, 0, nBars, close) < nBars)
         return true; // pas de données = on skip sans erreur
   }
   
   int supportLow1 = -1, supportLow2 = -1;
   double lowestLow = DBL_MAX;
   int lim1 = MathMin(30, nBars - 5);
   for(int i = 5; i < lim1; i++)
   {
      if(low[i] < lowestLow)
      {
         lowestLow = low[i];
         supportLow1 = i;
      }
   }
   
   if(supportLow1 != -1)
   {
      lowestLow = DBL_MAX;
      int lim2 = MathMin(45, nBars - 1);
      for(int i = supportLow1 + 5; i < lim2; i++)
      {
         if(low[i] < lowestLow)
         {
            lowestLow = low[i];
            supportLow2 = i;
         }
      }
   }
   
   if(supportLow1 != -1 && supportLow2 != -1)
   {
      datetime time1 = iTime(_Symbol, tf, supportLow1);
      datetime time2 = iTime(_Symbol, tf, supportLow2);
      
      ObjectCreate(0, "TRENDLINE_SUPPORT", OBJ_TREND, 0, time1, low[supportLow1], time2, low[supportLow2]);
      ObjectSetInteger(0, "TRENDLINE_SUPPORT", OBJPROP_COLOR, UseMutedColors ? MUTED_GREEN : clrGreen);
      ObjectSetInteger(0, "TRENDLINE_SUPPORT", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "TRENDLINE_SUPPORT", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "TRENDLINE_SUPPORT", OBJPROP_RAY_RIGHT, true);
   }
   
   // Dessiner trendline de résistance (connecter les highs les plus hauts)
   int resistanceHigh1 = -1, resistanceHigh2 = -1;
   double highestHigh = DBL_MIN;
   
   for(int i = 5; i < 30; i++)
   {
      if(high[i] > highestHigh)
      {
         highestHigh = high[i];
         resistanceHigh1 = i;
      }
   }
   
   if(resistanceHigh1 != -1)
   {
      highestHigh = DBL_MIN;
      int lim3 = MathMin(45, nBars - 1);
      for(int i = resistanceHigh1 + 5; i < lim3; i++)
      {
         if(high[i] > highestHigh)
         {
            highestHigh = high[i];
            resistanceHigh2 = i;
         }
      }
   }
   
   if(resistanceHigh1 != -1 && resistanceHigh2 != -1)
   {
      datetime time1 = iTime(_Symbol, tf, resistanceHigh1);
      datetime time2 = iTime(_Symbol, tf, resistanceHigh2);
      
      ObjectCreate(0, "TRENDLINE_RESISTANCE", OBJ_TREND, 0, time1, high[resistanceHigh1], time2, high[resistanceHigh2]);
      ObjectSetInteger(0, "TRENDLINE_RESISTANCE", OBJPROP_COLOR, UseMutedColors ? MUTED_RED : clrRed);
      ObjectSetInteger(0, "TRENDLINE_RESISTANCE", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "TRENDLINE_RESISTANCE", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "TRENDLINE_RESISTANCE", OBJPROP_RAY_RIGHT, true);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| DESSINER LES ZONES IA                                            |
//+------------------------------------------------------------------+
/*
bool DrawAIZonesGraphics()
{
   if(DisableAllGraphics || !DrawAIZonesEnabled) return true;
   
   // DEBUG: Afficher l'état des zones
   if(DebugMode)
      Print("DEBUG DrawAIZonesGraphics - BUY Zone: ", g_aiBuyZoneLow, "-", g_aiBuyZoneHigh, " SELL Zone: ", g_aiSellZoneLow, "-", g_aiSellZoneHigh, " DrawAIZonesEnabled: ", DrawAIZonesEnabled);
   
   // Ne PAS supprimer les zones existantes - les rendre persistantes
   // ObjectsDeleteAll(0, "AI_ZONE_");  // COMMENTÉ pour rendre les zones persistantes
   
   // Dessiner zone BUY IA seulement si elle n'existe pas déjà
   if(g_aiBuyZoneLow > 0 && g_aiBuyZoneHigh > 0)
   {
      if(ObjectFind(0, "AI_ZONE_BUY") < 0)
      {
         datetime currentTime = TimeCurrent();
         datetime startTime = currentTime - 3600; // 1 heure en arrière
         
         ObjectCreate(0, "AI_ZONE_BUY", OBJ_RECTANGLE, 0, startTime, g_aiBuyZoneLow, currentTime, g_aiBuyZoneHigh);
         ObjectSetInteger(0, "AI_ZONE_BUY", OBJPROP_COLOR, UseMutedColors ? MUTED_GREEN : clrGreen);
         ObjectSetInteger(0, "AI_ZONE_BUY", OBJPROP_BACK, true);
         ObjectSetInteger(0, "AI_ZONE_BUY", OBJPROP_FILL, true); // REMPLISSAGE RÉACTIVÉ
         ObjectSetInteger(0, "AI_ZONE_BUY", OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, "AI_ZONE_BUY", OBJPROP_WIDTH, 1);
         
         // Ajouter label
         ObjectCreate(0, "AI_ZONE_BUY_LABEL", OBJ_TEXT, 0, currentTime - 1800, (g_aiBuyZoneLow + g_aiBuyZoneHigh) / 2);
         ObjectSetString(0, "AI_ZONE_BUY_LABEL", OBJPROP_TEXT, "BUY IA ZONE");
         ObjectSetInteger(0, "AI_ZONE_BUY_LABEL", OBJPROP_COLOR, TEXT_LABEL_COLOR);
         ObjectSetInteger(0, "AI_ZONE_BUY_LABEL", OBJPROP_FONTSIZE, TEXT_FONT_SIZE_SM);
         
         if(DebugMode)
            Print("Zone BUY IA dessinee avec succes");
      }
      else
      {
         // Mettre à jour la zone BUY existante
         datetime currentTime = TimeCurrent();
         datetime startTime = currentTime - 3600; // 1 heure en arrière
         
         ObjectSetDouble(0, "AI_ZONE_BUY", OBJPROP_PRICE, 0, g_aiBuyZoneHigh);
         ObjectSetDouble(0, "AI_ZONE_BUY", OBJPROP_PRICE, 1, g_aiBuyZoneLow);
         ObjectSetInteger(0, "AI_ZONE_BUY", OBJPROP_TIME, 1, currentTime);
      }
   }
   else
   {
      if(DebugMode)
         Print("Zone BUY IA non dessinee - valeurs: ", g_aiBuyZoneLow, "-", g_aiBuyZoneHigh);
   }
   
   // Dessiner zone SELL IA seulement si elle n'existe pas déjà
   if(g_aiSellZoneLow > 0 && g_aiSellZoneHigh > 0)
   {
      if(ObjectFind(0, "AI_ZONE_SELL") < 0)
      {
         datetime currentTime = TimeCurrent();
         datetime startTime = currentTime - 3600; // 1 heure en arrière
         
         ObjectCreate(0, "AI_ZONE_SELL", OBJ_RECTANGLE, 0, startTime, g_aiSellZoneLow, currentTime, g_aiSellZoneHigh);
         ObjectSetInteger(0, "AI_ZONE_SELL", OBJPROP_COLOR, UseMutedColors ? MUTED_RED : clrRed);
         ObjectSetInteger(0, "AI_ZONE_SELL", OBJPROP_BACK, true);
         ObjectSetInteger(0, "AI_ZONE_SELL", OBJPROP_FILL, true); // REMPLISSAGE RÉACTIVÉ
         ObjectSetInteger(0, "AI_ZONE_SELL", OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, "AI_ZONE_SELL", OBJPROP_WIDTH, 1);
         
         // Ajouter label
         ObjectCreate(0, "AI_ZONE_SELL_LABEL", OBJ_TEXT, 0, currentTime - 1800, (g_aiSellZoneLow + g_aiSellZoneHigh) / 2);
         ObjectSetString(0, "AI_ZONE_SELL_LABEL", OBJPROP_TEXT, "SELL IA ZONE");
         ObjectSetInteger(0, "AI_ZONE_SELL_LABEL", OBJPROP_COLOR, TEXT_LABEL_COLOR);
         ObjectSetInteger(0, "AI_ZONE_SELL_LABEL", OBJPROP_FONTSIZE, TEXT_FONT_SIZE_SM);
         
         if(DebugMode)
            Print("Zone SELL IA dessinee avec succes");
      }
      else
      {
         // Mettre à jour la zone SELL existante
         datetime currentTime = TimeCurrent();
         datetime startTime = currentTime - 3600; // 1 heure en arrière
         
         ObjectSetDouble(0, "AI_ZONE_SELL", OBJPROP_PRICE, 0, g_aiSellZoneHigh);
         ObjectSetDouble(0, "AI_ZONE_SELL", OBJPROP_PRICE, 1, g_aiSellZoneLow);
         ObjectSetInteger(0, "AI_ZONE_SELL", OBJPROP_TIME, 1, currentTime);
      }
   }
   else
   {
      if(DebugMode)
         Print("Zone SELL IA non dessinee - valeurs: ", g_aiSellZoneLow, "-", g_aiSellZoneHigh);
   }
   
   return true;
}
*/

bool DrawAIZonesGraphics()
{
   return true; // Temporary fix for compilation
}

//+------------------------------------------------------------------+
//| DESSINER LES ORDER BLOCKS                                        |
//+------------------------------------------------------------------+
bool DrawOrderBlocksGraphics()
{
   if(DisableAllGraphics) return true;
   
   ObjectsDeleteAll(0, "OB_");
   
   double high[], low[], close[];
   long volume[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(volume, true);
   
   ENUM_TIMEFRAMES tf = PERIOD_M15;
   int n = 100;
   if(CopyHigh(_Symbol, PERIOD_M15, 0, n, high) < n ||
      CopyLow(_Symbol, PERIOD_M15, 0, n, low) < n ||
      CopyClose(_Symbol, PERIOD_M15, 0, n, close) < n ||
      CopyTickVolume(_Symbol, PERIOD_M15, 0, n, volume) < n)
   {
      tf = _Period;
      n = MathMin(100, Bars(_Symbol, tf));
      if(n < 20 || CopyHigh(_Symbol, tf, 0, n, high) < n ||
         CopyLow(_Symbol, tf, 0, n, low) < n ||
         CopyClose(_Symbol, tf, 0, n, close) < n ||
         CopyTickVolume(_Symbol, tf, 0, n, volume) < n)
         return true; // pas de données = skip sans erreur
   }
   
   // Identifier les Order Blocks (bougies fortes avec volume élevé)
   for(int i = 10; i < 80; i++)
   {
      double range = high[i] - low[i];
      double avgRange = 0;
      
      // Calculer la range moyenne des 10 bougies précédentes
      for(int j = i + 1; j < i + 11; j++)
      {
         avgRange += high[j] - low[j];
      }
      avgRange /= 10;
      
      // Order Block bullish (forte bougie descendante suivie d'un retournement)
      if(close[i] < close[i+1] && range > avgRange * 1.5 && volume[i] > volume[i+1] * 1.2)
      {
         if(close[i-1] > close[i] && close[i-2] > close[i-1]) // Retournement haussier
         {
            datetime time = iTime(_Symbol, tf, i);
            string objName = "OB_BULLISH_" + IntegerToString(i);
            
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time - 900, low[i], time + 900, high[i]);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            ObjectSetInteger(0, objName, OBJPROP_FILL, false); // PAS DE REMPLISSAGE
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         }
      }
      
      // Order Block bearish (forte bougie ascendante suivie d'un retournement)
      if(close[i] > close[i+1] && range > avgRange * 1.5 && volume[i] > volume[i+1] * 1.2)
      {
         if(close[i-1] < close[i] && close[i-2] < close[i-1]) // Retournement baissier
         {
            datetime time = iTime(_Symbol, tf, i);
            string objName = "OB_BEARISH_" + IntegerToString(i);
            
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time - 900, low[i], time + 900, high[i]);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            ObjectSetInteger(0, objName, OBJPROP_FILL, false); // PAS DE REMPLISSAGE
            ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         }
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| DESSINER LES CONCEPTS SMC                                        |
//+------------------------------------------------------------------+
bool DrawSMCConcepts()
{
   if(DisableAllGraphics) return true;
   
   ObjectsDeleteAll(0, "SMC_");
   
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   ENUM_TIMEFRAMES tf = PERIOD_H1;
   int n = 100;
   if(CopyHigh(_Symbol, PERIOD_H1, 0, n, high) < n ||
      CopyLow(_Symbol, PERIOD_H1, 0, n, low) < n ||
      CopyClose(_Symbol, PERIOD_H1, 0, n, close) < n)
   {
      tf = _Period;
      n = MathMin(100, Bars(_Symbol, tf));
      if(n < 25 || CopyHigh(_Symbol, tf, 0, n, high) < n ||
         CopyLow(_Symbol, tf, 0, n, low) < n ||
         CopyClose(_Symbol, tf, 0, n, close) < n)
         return true;
   }
   
   int maxI = MathMin(90, n - 3);
   for(int i = 5; i < maxI; i++)
   {
      // Swing High
      if(high[i] > high[i-1] && high[i] > high[i-2] && 
         high[i] > high[i+1] && high[i] > high[i+2])
      {
         datetime time = iTime(_Symbol, tf, i);
         string objName = "SMC_SWING_HIGH_" + IntegerToString(i);
         
         ObjectCreate(0, objName, OBJ_ARROW_DOWN, 0, time, high[i]);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
         
         // Ajouter label
         ObjectCreate(0, objName + "_LABEL", OBJ_TEXT, 0, time, high[i] + 50 * _Point);
         ObjectSetString(0, objName + "_LABEL", OBJPROP_TEXT, "Swing High");
         ObjectSetInteger(0, objName + "_LABEL", OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, objName + "_LABEL", OBJPROP_FONTSIZE, 7);
      }
      
      // Swing Low
      if(low[i] < low[i-1] && low[i] < low[i-2] && 
         low[i] < low[i+1] && low[i] < low[i+2])
      {
         datetime time = iTime(_Symbol, tf, i);
         string objName = "SMC_SWING_LOW_" + IntegerToString(i);
         
         ObjectCreate(0, objName, OBJ_ARROW_UP, 0, time, low[i]);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
         
         // Ajouter label
         ObjectCreate(0, objName + "_LABEL", OBJ_TEXT, 0, time, low[i] - 50 * _Point);
         ObjectSetString(0, objName + "_LABEL", OBJPROP_TEXT, "Swing Low");
         ObjectSetInteger(0, objName + "_LABEL", OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, objName + "_LABEL", OBJPROP_FONTSIZE, 7);
      }
   }
   
   // Dessiner les Market Structure Breaks (MSB)
   DrawMarketStructureBreaks();
   
   return true;
}

//+------------------------------------------------------------------+
//| DESSINER LES MARKET STRUCTURE BREAKS                             |
//+------------------------------------------------------------------+
void DrawMarketStructureBreaks()
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   if(CopyHigh(_Symbol, PERIOD_H4, 0, 50, high) < 50 ||
      CopyLow(_Symbol, PERIOD_H4, 0, 50, low) < 50 ||
      CopyClose(_Symbol, PERIOD_H4, 0, 50, close) < 50)
      return;
   
   // Identifier les breaks de structure
   double lastHigh = 0, lastLow = DBL_MAX;
   int lastHighIndex = -1, lastLowIndex = -1;
   
   for(int i = 5; i < 40; i++)
   {
      // Détecter un nouveau swing high
      if(high[i] > lastHigh)
      {
         lastHigh = high[i];
         lastHighIndex = i;
      }
      
      // Détecter un nouveau swing low
      if(low[i] < lastLow)
      {
         lastLow = low[i];
         lastLowIndex = i;
      }
      
      // Market Structure Break bullish (break du dernier swing low)
      if(lastLowIndex != -1 && i < lastLowIndex && close[i] > lastLow)
      {
         datetime time = iTime(_Symbol, PERIOD_H4, i);
         string objName = "SMC_MSB_BULLISH_" + IntegerToString(i);
         
         ObjectCreate(0, objName, OBJ_ARROW, 0, time, lastLow);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 4);
         
         // Ligne horizontale pour montrer le break
         ObjectCreate(0, objName + "_LINE", OBJ_HLINE, 0, 0, lastLow);
         ObjectSetInteger(0, objName + "_LINE", OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, objName + "_LINE", OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, objName + "_LINE", OBJPROP_WIDTH, 1);
      }
      
      // Market Structure Break bearish (break du dernier swing high)
      if(lastHighIndex != -1 && i < lastHighIndex && close[i] < lastHigh)
      {
         datetime time = iTime(_Symbol, PERIOD_H4, i);
         string objName = "SMC_MSB_BEARISH_" + IntegerToString(i);
         
         ObjectCreate(0, objName, OBJ_ARROW, 0, time, lastHigh);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 4);
         
         // Ligne horizontale pour montrer le break
         ObjectCreate(0, objName + "_LINE", OBJ_HLINE, 0, 0, lastHigh);
         ObjectSetInteger(0, objName + "_LINE", OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, objName + "_LINE", OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, objName + "_LINE", OBJPROP_WIDTH, 1);
      }
   }
}

//+------------------------------------------------------------------+
//| DESSINER LES CONCEPTS ICT FX PRO                                 |
//+------------------------------------------------------------------+
bool DrawICTConcepts()
{
   if(DisableAllGraphics) return false;
   if(IsStopped()) return true;
   
   // Nettoyer les anciens concepts ICT (limité pour éviter blocage)
   ObjectsDeleteAll(0, "ICT_");
   
   // Dessiner un par un pour limiter la charge et éviter le détachement
   DrawPremiumDiscountZones();
   if(IsStopped()) return true;
   
   DrawLiquidityZones();
   
   return true;
}

//+------------------------------------------------------------------+
//| DESSINER LES PREMIUM/DISCOUNT ZONES                              |
//+------------------------------------------------------------------+
void DrawPremiumDiscountZones()
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   ENUM_TIMEFRAMES tf = PERIOD_H1;
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 100, high) < 100 ||
      CopyLow(_Symbol, PERIOD_H1, 0, 100, low) < 100 ||
      CopyClose(_Symbol, PERIOD_H1, 0, 100, close) < 100)
   {
      tf = _Period;
      if(CopyHigh(_Symbol, tf, 0, 100, high) < 100 ||
         CopyLow(_Symbol, tf, 0, 100, low) < 100 ||
         CopyClose(_Symbol, tf, 0, 100, close) < 100)
         return;
   }
   
   // Calculer la moyenne mobile simple sur 20 périodes
   double sma20[];
   ArraySetAsSeries(sma20, true);
   ArrayResize(sma20, 100); // IMPORTANT: Redimensionner le tableau !
   
   // Limiter la boucle pour éviter le dépassement de tableau
   int maxCalculableIndex = 100 - 20; // On peut calculer SMA seulement jusqu'à l'index 80
   
   for(int i = 0; i < maxCalculableIndex; i++)
   {
      double sum = 0;
      for(int j = 0; j < 20; j++)
      {
         sum += close[i + j];
      }
      sma20[i] = sum / 20;
   }
   
   // Pour les indices restants, utiliser la dernière valeur calculée
   for(int i = maxCalculableIndex; i < 100; i++)
   {
      sma20[i] = sma20[maxCalculableIndex - 1];
   }
   
   // Vérification de sécurité pour s'assurer que sma20[0] existe
   if(ArraySize(sma20) == 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur: sma20 array vide dans DrawPremiumDiscountZones");
      return;
   }
   
   // Dessiner les zones Premium (au-dessus de la SMA) et Discount (en dessous)
   datetime currentTime = TimeCurrent();
   datetime startTime = currentTime - 7200; // 2 heures en arrière
   
   // Zone Premium
   double premiumHigh = high[0];
   double premiumLow = sma20[0];
   
   ObjectCreate(0, "ICT_PREMIUM_ZONE", OBJ_RECTANGLE, 0, startTime, premiumLow, currentTime, premiumHigh);
   ObjectSetInteger(0, "ICT_PREMIUM_ZONE", OBJPROP_COLOR, UseMutedColors ? MUTED_ORANGE : clrOrange);
   ObjectSetInteger(0, "ICT_PREMIUM_ZONE", OBJPROP_BACK, true);
   ObjectSetInteger(0, "ICT_PREMIUM_ZONE", OBJPROP_FILL, true); // REMPLISSAGE ACTIVÉ
   ObjectSetInteger(0, "ICT_PREMIUM_ZONE", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "ICT_PREMIUM_ZONE", OBJPROP_WIDTH, 1);
   
   // Label Premium (position temps décalée pour ne pas chevaucher Discount)
   double premiumMid = (premiumLow + premiumHigh) / 2;
   ObjectCreate(0, "ICT_PREMIUM_LABEL", OBJ_TEXT, 0, startTime + 600, premiumMid);
   ObjectSetString(0, "ICT_PREMIUM_LABEL", OBJPROP_TEXT, "Premium (vente)");
   ObjectSetInteger(0, "ICT_PREMIUM_LABEL", OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, "ICT_PREMIUM_LABEL", OBJPROP_FONTSIZE, TEXT_FONT_SIZE_SM);
   ObjectSetInteger(0, "ICT_PREMIUM_LABEL", OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, "ICT_PREMIUM_LABEL", OBJPROP_BACK, false); // Mettre au premier plan
   
   // Zone Discount
   double discountHigh = sma20[0];
   double discountLow = low[0];
   
   ObjectCreate(0, "ICT_DISCOUNT_ZONE", OBJ_RECTANGLE, 0, startTime, discountLow, currentTime, discountHigh);
   ObjectSetInteger(0, "ICT_DISCOUNT_ZONE", OBJPROP_COLOR, UseMutedColors ? MUTED_BLUE : clrDodgerBlue);
   ObjectSetInteger(0, "ICT_DISCOUNT_ZONE", OBJPROP_BACK, true);
   ObjectSetInteger(0, "ICT_DISCOUNT_ZONE", OBJPROP_FILL, true); // REMPLISSAGE ACTIVÉ
   ObjectSetInteger(0, "ICT_DISCOUNT_ZONE", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "ICT_DISCOUNT_ZONE", OBJPROP_WIDTH, 1);
   
   // Label Discount (position temps décalée pour ne pas chevaucher Premium)
   double discountMid = (discountLow + discountHigh) / 2;
   ObjectCreate(0, "ICT_DISCOUNT_LABEL", OBJ_TEXT, 0, startTime + 1800, discountMid);
   ObjectSetString(0, "ICT_DISCOUNT_LABEL", OBJPROP_TEXT, "Discount (achat)");
   ObjectSetInteger(0, "ICT_DISCOUNT_LABEL", OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, "ICT_DISCOUNT_LABEL", OBJPROP_FONTSIZE, TEXT_FONT_SIZE_SM);
   ObjectSetInteger(0, "ICT_DISCOUNT_LABEL", OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(0, "ICT_DISCOUNT_LABEL", OBJPROP_BACK, false); // Mettre au premier plan
}

//+------------------------------------------------------------------+
//| DESSINER LES LIQUIDITY ZONES                                     |
//+------------------------------------------------------------------+
void DrawLiquidityZones()
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   ENUM_TIMEFRAMES tf = PERIOD_H1;
   int bars = 200;
   if(CopyHigh(_Symbol, PERIOD_H1, 0, bars, high) < bars ||
      CopyLow(_Symbol, PERIOD_H1, 0, bars, low) < bars ||
      CopyClose(_Symbol, PERIOD_H1, 0, bars, close) < bars)
   {
      tf = _Period;
      bars = MathMin(100, Bars(_Symbol, tf));
      if(bars < 20 || CopyHigh(_Symbol, tf, 0, bars, high) < bars ||
         CopyLow(_Symbol, tf, 0, bars, low) < bars ||
         CopyClose(_Symbol, tf, 0, bars, close) < bars)
         return;
   }
   
   // Limiter le nombre d'objets pour éviter surcharge et détachement du robot
   int maxI = MathMin(25, bars - 3);
   if(maxI < 12) return;
   for(int i = 10; i < maxI; i++)
   {
      if(i < 2 || i + 2 >= bars) continue;
      // Swing High (liquité au-dessus)
      if(high[i] > high[i-1] && high[i] > high[i-2] && 
         high[i] > high[i+1] && high[i] > high[i+2])
      {
         datetime time = iTime(_Symbol, tf, i);
         string objName = "ICT_LIQ_HIGH_" + IntegerToString(i);
         
         // Zone de liquidité au-dessus du swing high (ZONE DE VENTE)
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time - 1800, high[i], time + 1800, high[i] + 100 * _Point);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, UseMutedColors ? MUTED_RED : clrRed);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, true); // REMPLISSAGE ACTIVÉ pour meilleure visibilité
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         
         // Label
         ObjectCreate(0, objName + "_LABEL", OBJ_TEXT, 0, time, high[i] + 50 * _Point);
         ObjectSetString(0, objName + "_LABEL", OBJPROP_TEXT, "HIGH LIQUIDITY");
         ObjectSetInteger(0, objName + "_LABEL", OBJPROP_COLOR, UseMutedColors ? MUTED_WHITE : clrWhite);
         ObjectSetInteger(0, objName + "_LABEL", OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, objName + "_LABEL", OBJPROP_ANCHOR, ANCHOR_CENTER);
      }
      
      // Swing Low (liquidité en dessous)
      if(low[i] < low[i-1] && low[i] < low[i-2] && 
         low[i] < low[i+1] && low[i] < low[i+2])
      {
         datetime time = iTime(_Symbol, tf, i);
         string objName = "ICT_LIQ_LOW_" + IntegerToString(i);
         
         // Zone de liquidité en dessous du swing low (ZONE D'ACHAT)
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time - 1800, low[i] - 100 * _Point, time + 1800, low[i]);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, UseMutedColors ? MUTED_GREEN : clrGreen);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
         ObjectSetInteger(0, objName, OBJPROP_FILL, true); // REMPLISSAGE ACTIVÉ pour meilleure visibilité
         ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         
         // Label
         ObjectCreate(0, objName + "_LABEL", OBJ_TEXT, 0, time, low[i] - 50 * _Point);
         ObjectSetString(0, objName + "_LABEL", OBJPROP_TEXT, "LOW LIQUIDITY");
         ObjectSetInteger(0, objName + "_LABEL", OBJPROP_COLOR, UseMutedColors ? MUTED_WHITE : clrWhite);
         ObjectSetInteger(0, objName + "_LABEL", OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, objName + "_LABEL", OBJPROP_ANCHOR, ANCHOR_CENTER);
      }
   }
}

//+------------------------------------------------------------------+
//| DESSINE LA LÉGENDE DES ZONES EN BAS À DROITE DU GRAPHIQUE        |
//+------------------------------------------------------------------+
void DrawZonesLegend()
{
   if(!ShowDashboard) return;
   
   // Position en bas à droite du graphique
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   
   // Coordonnées pour la légende (bas à droite)
   int startX = chartWidth - 200; // 200 pixels depuis la droite
   int startY = chartHeight - 20; // 20 pixels depuis le bas
   int lineHeight = 16;
   int boxWidth = 15;
   int boxHeight = 12;
   int spacing = 2;
   
   // Nettoyer l'ancienne légende
   ObjectsDeleteAll(0, "LEGEND_ZONE_");
   
   int yPos = startY;
   int itemCount = 0;
   
   // 1. Zone AI BUY (Discount)
   if(g_aiBuyZoneLow > 0 && g_aiBuyZoneHigh > 0)
   {
      string boxName = "LEGEND_ZONE_BUY_BOX";
      string textName = "LEGEND_ZONE_BUY_TEXT";
      ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, startX);
      ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, boxName, OBJPROP_XSIZE, boxWidth);
      ObjectSetInteger(0, boxName, OBJPROP_YSIZE, boxHeight);
      ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, UseMutedColors ? MUTED_GREEN : clrGreen);
      ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
      
      ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, startX - boxWidth - spacing - 5);
      ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, yPos + 2);
      ObjectSetString(0, textName, OBJPROP_TEXT, "AI BUY (Discount)");
      ObjectSetInteger(0, textName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      yPos -= lineHeight;
      itemCount++;
   }
   
   // 2. Zone AI SELL (Premium)
   if(g_aiSellZoneLow > 0 && g_aiSellZoneHigh > 0)
   {
      string boxName = "LEGEND_ZONE_SELL_BOX";
      string textName = "LEGEND_ZONE_SELL_TEXT";
      ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, startX);
      ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, boxName, OBJPROP_XSIZE, boxWidth);
      ObjectSetInteger(0, boxName, OBJPROP_YSIZE, boxHeight);
      ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, UseMutedColors ? MUTED_RED : clrRed);
      ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
      
      ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, startX - boxWidth - spacing - 5);
      ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, yPos + 2);
      ObjectSetString(0, textName, OBJPROP_TEXT, "AI SELL (Premium)");
      ObjectSetInteger(0, textName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      yPos -= lineHeight;
      itemCount++;
   }
   
   // 3. FVG Bullish (Green)
   string boxName = "LEGEND_ZONE_FVG_BUY_BOX";
   string textName = "LEGEND_ZONE_FVG_BUY_TEXT";
   ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, boxName, OBJPROP_XSIZE, boxWidth);
   ObjectSetInteger(0, boxName, OBJPROP_YSIZE, boxHeight);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, UseMutedColors ? MUTED_GREEN : clrGreen);
   ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
   
   ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, startX - boxWidth - spacing - 5);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, yPos + 2);
   ObjectSetString(0, textName, OBJPROP_TEXT, "FVG Bullish");
   ObjectSetInteger(0, textName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   yPos -= lineHeight;
   itemCount++;
   
   // 4. FVG Bearish (Red)
   boxName = "LEGEND_ZONE_FVG_SELL_BOX";
   textName = "LEGEND_ZONE_FVG_SELL_TEXT";
   ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, boxName, OBJPROP_XSIZE, boxWidth);
   ObjectSetInteger(0, boxName, OBJPROP_YSIZE, boxHeight);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, UseMutedColors ? MUTED_RED : clrRed);
   ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
   
   ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, startX - boxWidth - spacing - 5);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, yPos + 2);
   ObjectSetString(0, textName, OBJPROP_TEXT, "FVG Bearish");
   ObjectSetInteger(0, textName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   yPos -= lineHeight;
   itemCount++;
   
   // 5. ICT Premium (Orange)
   boxName = "LEGEND_ZONE_PREMIUM_BOX";
   textName = "LEGEND_ZONE_PREMIUM_TEXT";
   ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, boxName, OBJPROP_XSIZE, boxWidth);
   ObjectSetInteger(0, boxName, OBJPROP_YSIZE, boxHeight);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, UseMutedColors ? MUTED_ORANGE : clrOrange);
   ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
   
   ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, startX - boxWidth - spacing - 5);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, yPos + 2);
   ObjectSetString(0, textName, OBJPROP_TEXT, "ICT Premium");
   ObjectSetInteger(0, textName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   yPos -= lineHeight;
   itemCount++;
   
   // 6. ICT Discount (Blue)
   boxName = "LEGEND_ZONE_DISCOUNT_BOX";
   textName = "LEGEND_ZONE_DISCOUNT_TEXT";
   ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, boxName, OBJPROP_XSIZE, boxWidth);
   ObjectSetInteger(0, boxName, OBJPROP_YSIZE, boxHeight);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, UseMutedColors ? MUTED_BLUE : clrDodgerBlue);
   ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
   
   ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, startX - boxWidth - spacing - 5);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, yPos + 2);
   ObjectSetString(0, textName, OBJPROP_TEXT, "ICT Discount");
   ObjectSetInteger(0, textName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   yPos -= lineHeight;
   itemCount++;
   
   // 7. High Liquidity (Red - Zone de vente)
   boxName = "LEGEND_ZONE_LIQUIDITY_HIGH_BOX";
   textName = "LEGEND_ZONE_LIQUIDITY_HIGH_TEXT";
   ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, boxName, OBJPROP_XSIZE, boxWidth);
   ObjectSetInteger(0, boxName, OBJPROP_YSIZE, boxHeight);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, UseMutedColors ? MUTED_RED : clrRed);
   ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
   
   ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, startX - boxWidth - spacing - 5);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, yPos + 2);
   ObjectSetString(0, textName, OBJPROP_TEXT, "High Liquidity (Vente)");
   ObjectSetInteger(0, textName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   yPos -= lineHeight;
   itemCount++;
   
   // 8. Low Liquidity (Green - Zone d'achat)
   boxName = "LEGEND_ZONE_LIQUIDITY_LOW_BOX";
   textName = "LEGEND_ZONE_LIQUIDITY_LOW_TEXT";
   ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, boxName, OBJPROP_XSIZE, boxWidth);
   ObjectSetInteger(0, boxName, OBJPROP_YSIZE, boxHeight);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, UseMutedColors ? MUTED_GREEN : clrGreen);
   ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
   
   ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, startX - boxWidth - spacing - 5);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, yPos + 2);
   ObjectSetString(0, textName, OBJPROP_TEXT, "Low Liquidity (Achat)");
   ObjectSetInteger(0, textName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   yPos -= lineHeight;
   itemCount++;
   
   // 9. Order Blocks (Blue/Crimson selon direction)
   boxName = "LEGEND_ZONE_OB_BOX";
   textName = "LEGEND_ZONE_OB_TEXT";
   ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, boxName, OBJPROP_XSIZE, boxWidth);
   ObjectSetInteger(0, boxName, OBJPROP_YSIZE, boxHeight);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, UseMutedColors ? MUTED_BLUE : clrDodgerBlue);
   ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
   
   ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, startX - boxWidth - spacing - 5);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, yPos + 2);
   ObjectSetString(0, textName, OBJPROP_TEXT, "Order Blocks");
   ObjectSetInteger(0, textName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   yPos -= lineHeight;
   itemCount++;
   
   // 9. Fibonacci (lignes horizontales colorées)
   boxName = "LEGEND_ZONE_FIBO_BOX";
   textName = "LEGEND_ZONE_FIBO_TEXT";
   ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, yPos);
   ObjectSetInteger(0, boxName, OBJPROP_XSIZE, boxWidth);
   ObjectSetInteger(0, boxName, OBJPROP_YSIZE, boxHeight);
   ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, UseMutedColors ? MUTED_YELLOW : clrYellow);
   ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
   
   ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, startX - boxWidth - spacing - 5);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, yPos + 2);
   ObjectSetString(0, textName, OBJPROP_TEXT, "Fibonacci");
   ObjectSetInteger(0, textName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   yPos -= lineHeight;
   itemCount++;
   
   // Titre de la légende
   if(itemCount > 0)
   {
      string titleName = "LEGEND_ZONE_TITLE";
      ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, startX - 10);
      ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, yPos - 5);
      ObjectSetString(0, titleName, OBJPROP_TEXT, "LÉGENDE ZONES");
      ObjectSetInteger(0, titleName, OBJPROP_COLOR, TEXT_LABEL_COLOR);
      ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, titleName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   }
}

//+------------------------------------------------------------------+
//| METTRE À JOUR TOUS LES GRAPHIQUES                                |
//+------------------------------------------------------------------+
void UpdateAllGraphics()
{
   if(DisableAllGraphics) return;
   
   static bool graphicsDisabled = false;
   if(graphicsDisabled) return;
   
   // Ne pas appeler GenerateLocalFallbackTrend ici (indicateurs lourds = risque de détachement)
   // Les zones sont remplies par UpdateTrendEndpoint/fallback dans OnTick
   
   static datetime lastUpdate = 0;
   static bool firstDraw = true;
   if(firstDraw) { lastUpdate = 0; firstDraw = false; }
   if(TimeCurrent() - lastUpdate < GraphicsUpdateInterval)
      return;
   
   lastUpdate = TimeCurrent();
   
   // Utiliser un compteur d'erreurs simple pour éviter les crashes
   static int errorCount = 0;
   
   // Tenter de mettre à jour les graphiques (une étape à la fois pour éviter surcharge/détachement)
   bool success = true;
   if(IsStopped()) return;
   
   if(!DrawTrendlinesGraphics()) success = false;
   if(IsStopped()) return;
   
   if(!DrawAIZonesGraphics()) success = false;
   if(IsStopped()) return;
   
   if(!DrawOrderBlocksGraphics()) success = false;
   if(IsStopped()) return;
   
   if(!DrawSMCConcepts()) success = false;
   if(IsStopped()) return;
   
   if(!DrawICTConcepts()) success = false;
   if(IsStopped()) return;
   
   if(!DrawDynamicInterpretations()) success = false;
   
   // Dessiner la légende des zones en bas à droite
   DrawZonesLegend();
   
   if(success)
   {
      if(DebugMode)
         Print("📊 Graphiques techniques mis à jour");
      errorCount = 0; // Reset du compteur en cas de succès
   }
   else
   {
      errorCount++;
      if(DebugMode)
         Print("❌ Erreur graphiques (", errorCount, "/10)");
      // Désactiver seulement après 10 échecs consécutifs (évite coupure pour symboles sans H1/M15)
      if(errorCount > 10)
      {
         graphicsDisabled = true;
         Print("🚨 Graphiques désactivés après 10 erreurs - Redémarrez le robot pour réactiver");
      }
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
      g_lastAnalysisData = analysis;
   else
      g_lastAnalysisData = GenerateLocalFallbackAnalysis();

   string trend = UpdateTrendEndpoint();
   if(trend != "")
      g_lastTrendData = trend;
   else
      g_lastTrendData = GenerateLocalFallbackTrend();
   ExtractAIZonesFromResponse(g_lastTrendData);

   string prediction = UpdatePredictionEndpoint();
   if(prediction != "")
      g_lastPredictionData = prediction;
   else
      g_lastPredictionData = GenerateLocalFallbackPrediction();

   string coherent = UpdateCoherentEndpoint();
   if(coherent != "")
      g_lastCoherentData = coherent;
   else
      g_lastCoherentData = GenerateLocalFallbackCoherent();

   Print("Tous les endpoints ont été mis à jour");
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT ANALYSIS                              |
//+------------------------------------------------------------------+
string UpdateAnalysisEndpoint()
{
   string url = AI_AnalysisURL;
   string result = "";
   
   // Essayer GET d'abord
   result = MakeHTTPRequest(url, "GET", "", 2);
   
   if(result != "")
   {
      Print("✅ Analysis endpoint mis à jour: ", result);
      return result;
   }
   
   // Si GET échoue, essayer POST
   string data = "{\"symbol\":\"" + _Symbol + "\"}";
   result = MakeHTTPRequest(url, "POST", data, 2);
   
   if(result != "")
   {
      Print("✅ Analysis endpoint mis à jour (POST): ", result);
      return result;
   }
   
   // Si tout échoue
   Print("❌ Erreur Analysis endpoint - GET et POST échoués");
   return "";
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT DE TENDANCE (AVEC RETRY)               |
//+------------------------------------------------------------------+
string UpdateTrendEndpoint()
{
   string url = TrendAPIURL;
   string result = "";
   
   // Essayer GET d'abord avec le symbole en paramètre
   string urlWithSymbol = url + "?symbol=" + _Symbol;
   result = MakeHTTPRequest(urlWithSymbol, "GET", "", 2);
   
   if(result != "")
   {
      Print("✅ Trend endpoint mis à jour: ", result);
      return result;
   }
   
   // Si GET échoue, essayer POST
   string data = "{\"symbol\":\"" + _Symbol + "\"}";
   result = MakeHTTPRequest(url, "POST", data, 2);
   
   if(result != "")
   {
      Print("✅ Trend endpoint mis à jour (POST): ", result);
      return result;
   }
   
   // Si tout échoue
   Print("❌ Erreur Trend endpoint - GET et POST échoués");
   return "";
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT DE PRÉDICTION (AVEC RETRY)             |
//+------------------------------------------------------------------+
string UpdatePredictionEndpoint()
{
   string url = AI_PredictSymbolURL + "/" + _Symbol;
   if(DebugMode)
      Print("🔮 DEBUG - Appel endpoint prédiction: ", url);
   
   string result = "";
   
   // Essayer GET d'abord
   result = MakeHTTPRequest(url, "GET", "", 2);
   
   if(result != "")
   {
      Print("✅ Prediction endpoint mis à jour: ", result);
      if(DebugMode)
         Print("🔮 DEBUG - Données brutes reçues: ", result);
      return result;
   }
   
   // Si GET échoue, essayer POST
   string data = "{\"symbol\":\"" + _Symbol + "\"}";
   result = MakeHTTPRequest(url, "POST", data, 2);
   
   if(result != "")
   {
      Print("✅ Prediction endpoint mis à jour (POST): ", result);
      if(DebugMode)
         Print("🔮 DEBUG - Données brutes reçues (POST): ", result);
      return result;
   }
   
   // Si tout échoue
   Print("❌ Erreur Prediction endpoint - GET et POST échoués");
   if(DebugMode)
      Print("🔮 DEBUG - Échec total pour: ", url);
   return "";
}

//+------------------------------------------------------------------+
//| MISE À JOUR DE L'ENDPOINT D'ANALYSE COHÉRENTE (AVEC RETRY)       |
//+------------------------------------------------------------------+
string UpdateCoherentEndpoint()
{
   string url = AI_CoherentAnalysisURL;
   string result = "";
   
   // Essayer GET d'abord avec le symbole en paramètre
   string urlWithSymbol = url + "?symbol=" + _Symbol;
   result = MakeHTTPRequest(urlWithSymbol, "GET", "", 2);
   
   if(result != "")
   {
      Print("✅ Coherent endpoint mis à jour: ", result);
      return result;
   }
   
   // Si GET échoue, essayer POST
   string data = "{\"symbol\":\"" + _Symbol + "\"}";
   result = MakeHTTPRequest(url, "POST", data, 2);
   
   if(result != "")
   {
      Print("✅ Coherent endpoint mis à jour (POST): ", result);
      return result;
   }
   
   // Si tout échoue
   Print("❌ Erreur Coherent endpoint - GET et POST échoués");
   return "";
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
   
   color okColor = UseMutedColors ? MUTED_LIME : clrLime;
   color koColor = UseMutedColors ? MUTED_RED : clrRed;
   g_alignmentColors[0] = analysisAligned ? okColor : koColor;
   g_alignmentColors[1] = trendAligned ? okColor : koColor;
   g_alignmentColors[2] = predictionAligned ? okColor : koColor;
   g_alignmentColors[3] = coherentAligned ? okColor : koColor;
   
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
void ExecuteTrade(ENUM_ORDER_TYPE signalType, double entryPrice = 0)
{
   double currentPrice = (entryPrice > 0) ? entryPrice : SymbolInfoDouble(_Symbol, (signalType == ORDER_TYPE_BUY) ? SYMBOL_ASK : SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopLoss = 0.0;
   double takeProfit = 0.0;
   
   // TOUJOURS utiliser le lot minimal du broker pour tous les calculs
   double lotSize = NormalizeLotSize(InitialLotSize);
   
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
         stopLoss = currentPrice - (StopLossUSD / (lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)));
      }
      
      // TP: Ratio risque/récompense de 1:2 ou 1:3
      double riskAmount = currentPrice - stopLoss;
      takeProfit = currentPrice + (riskAmount * 2.5); // Ratio 1:2.5
      
      // Vérifier que le TP n'est pas trop proche (minimum 2$)
      double potentialProfit = (takeProfit - currentPrice) * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(potentialProfit < 2.0)
         takeProfit = currentPrice + (2.0 / (lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)));
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
         stopLoss = currentPrice + (StopLossUSD / (lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)));
      }
      
      // TP: Ratio risque/récompense de 1:2 ou 1:3
      double riskAmount = stopLoss - currentPrice;
      takeProfit = currentPrice - (riskAmount * 2.5); // Ratio 1:2.5
      
      // Vérifier que le TP n'est pas trop proche (minimum 2$)
      double potentialProfit = (currentPrice - takeProfit) * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(potentialProfit < 2.0)
         takeProfit = currentPrice - (2.0 / (lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE)));
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
   if(trade.PositionOpen(_Symbol, signalType, lotSize, currentPrice, stopLoss, takeProfit, "AI Signal + Rebound Entry"))
   {
      string signalStr = (signalType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      double riskUSD = MathAbs(currentPrice - stopLoss) * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double rewardUSD = MathAbs(takeProfit - currentPrice) * lotSize * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      
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
      if(StringFind(_Symbol, "Crash", 0) >= 0 && signalType == ORDER_TYPE_BUY) return false;
      if(StringFind(_Symbol, "Boom", 0) >= 0 && signalType == ORDER_TYPE_SELL) return false;
      
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
         ActivateTrailingStop(); // RÉACTIVÉ - trailing stop opérationnel
         
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
//| Activer le trailing stop pour toutes les positions (Forex/Volatility) |
//+------------------------------------------------------------------+
void ActivateTrailingStop()
{
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Magic() != InpMagicNumber) continue; // Seulement nos positions
         
         string symbol = positionInfo.Symbol();
         // ACTIVÉ pour TOUS les symboles maintenant
         
         double currentSL = positionInfo.StopLoss();
         double currentTP = positionInfo.TakeProfit();
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         double currentProfit = positionInfo.Profit();
         double currentPrice = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 
                              SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
         
         // TRAILING STOP: Ne déplacer le SL que si le profit est positif (sécuriser les gains)
         if(currentProfit > 0)
         {
            // Trailing stop dynamique basé sur l'ATR
            double atr[];
            ArraySetAsSeries(atr, true);
            if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
            {
               double trailingDistance = atr[0] * 2.0; // 2.0x ATR pour trailing plus réactif
               
               if(positionInfo.PositionType() == POSITION_TYPE_BUY)
               {
                  double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
                  double newSL = bid - trailingDistance;
                  
                  // Déplacer le SL seulement si :
                  // 1. Le nouveau SL est meilleur (plus haut) que l'actuel
                  // 2. Le nouveau SL est en dessous du prix actuel
                  if(newSL > currentSL + point * 5 && newSL < bid)
                  {
                     trade.SetExpertMagicNumber(InpMagicNumber);
                     trade.SetMarginMode();
                     if(trade.PositionModify(ticket, newSL, currentTP))
                     {
                        if(DebugMode)
                           Print("🔄 Trailing BUY ", symbol, ": SL déplacé de ", DoubleToString(currentSL, _Digits), 
                                 " à ", DoubleToString(newSL, _Digits), " (profit: ", DoubleToString(currentProfit, 2), "$)");
                     }
                     else
                     {
                        if(DebugMode)
                           Print("❌ Erreur trailing BUY ", symbol, ": ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
                     }
                  }
               }
               else // SELL
               {
                  double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
                  double newSL = ask + trailingDistance;
                  
                  // Déplacer le SL seulement si :
                  // 1. Le nouveau SL est meilleur (plus bas) que l'actuel
                  // 2. Le nouveau SL est au-dessus du prix actuel
                  if(newSL < currentSL - point * 5 && newSL > ask)
                  {
                     trade.SetExpertMagicNumber(InpMagicNumber);
                     trade.SetMarginMode();
                     if(trade.PositionModify(ticket, newSL, currentTP))
                     {
                        if(DebugMode)
                           Print("🔄 Trailing SELL ", symbol, ": SL déplacé de ", DoubleToString(currentSL, _Digits), 
                                 " à ", DoubleToString(newSL, _Digits), " (profit: ", DoubleToString(currentProfit, 2), "$)");
                     }
                     else
                     {
                        if(DebugMode)
                           Print("❌ Erreur trailing SELL ", symbol, ": ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
                     }
                  }
               }
            }
         }
         
         // TP DYNAMIQUE: Ajuster le Take Profit selon le profit actuel
         if(currentProfit > 1.0) // Seulement si profit > 1$
         {
            double newTP = 0.0;
            bool shouldModify = false;
            
            if(positionInfo.PositionType() == POSITION_TYPE_BUY)
            {
               // Pour BUY: Monter le TP si le prix monte
               double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
               double potentialTP = bid + (bid - currentSL) * 1.5; // RR 1:1.5 depuis le nouveau SL
               
               if(potentialTP > currentTP + point * 10) // Seulement si amélioration significative
               {
                  newTP = potentialTP;
                  shouldModify = true;
               }
            }
            else // SELL
            {
               // Pour SELL: Baisser le TP si le prix baisse
               double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
               double potentialTP = ask - (currentSL - ask) * 1.5; // RR 1:1.5 depuis le nouveau SL
               
               if(potentialTP < currentTP - point * 10) // Seulement si amélioration significative
               {
                  newTP = potentialTP;
                  shouldModify = true;
               }
            }
            
            if(shouldModify)
            {
               trade.SetExpertMagicNumber(InpMagicNumber);
               trade.SetMarginMode();
               if(trade.PositionModify(ticket, currentSL, newTP))
               {
                  if(DebugMode)
                     Print("🎯 TP Dynamique ", symbol, ": TP déplacé de ", DoubleToString(currentTP, _Digits), 
                           " à ", DoubleToString(newTP, _Digits), " (profit: ", DoubleToString(currentProfit, 2), "$)");
               }
               else if(DebugMode)
               {
                  Print("❌ Erreur TP Dynamique ", symbol, ": ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Détecter si la flèche DERIV ARROW est présente sur le chart      |
//+------------------------------------------------------------------+
bool IsDerivArrowPresent()
{
   string arrowName = "DERIV_ARROW_" + _Symbol;
   
   // Vérifier si l'objet flèche existe sur le chart
   if(ObjectFind(0, arrowName) >= 0)
   {
      // Vérifier si c'est bien une flèche (OBJ_ARROW_UP ou OBJ_ARROW_DOWN)
      int objectType = (int)ObjectGetInteger(0, arrowName, OBJPROP_TYPE);
      if(objectType == OBJ_ARROW_UP || objectType == OBJ_ARROW_DOWN)
      {
         if(DebugMode)
            Print("✅ Flèche DERIV détectée sur le chart: ", arrowName);
         return true;
      }
   }
   
   if(DebugMode)
      Print("❌ Flèche DERIV NON détectée sur le chart");
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier si le signal est fort (ACHAT FORT ou VENTE FORTE)       |
//+------------------------------------------------------------------+
bool HasStrongSignal()
{
   // Vérifier la confiance IA
   if(g_lastAIConfidence < 0.70) // Seuil minimum 70%
   {
      if(DebugMode)
         Print("❌ Confiance IA insuffisante: ", DoubleToString(g_lastAIConfidence*100, 1), "% < 70%");
      return false;
   }
   
   // Vérifier l'action IA
   if(StringCompare(g_lastAIAction, "buy") != 0 && StringCompare(g_lastAIAction, "sell") != 0)
   {
      if(DebugMode)
         Print("❌ Action IA invalide: ", g_lastAIAction);
      return false;
   }
   
   if(DebugMode)
      Print("✅ Signal fort détecté: ", g_lastAIAction, " (confiance: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
   return true;
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
   if(pendingType == ORDER_TYPE_BUY_LIMIT && entryPrice >= askPrice)
   {
      double minDistance = MathMax(10 * point, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point);
      // Pour les symboles Forex, utiliser une distance plus grande
      if(StringFind(_Symbol, "AUD") >= 0 || StringFind(_Symbol, "EUR") >= 0 || StringFind(_Symbol, "GBP") >= 0 || StringFind(_Symbol, "USD") >= 0)
         minDistance = MathMax(minDistance, 20 * point); // 20 pips minimum pour Forex
      entryPrice = NormalizeDouble(askPrice - minDistance, _Digits);
      Print("🔧 BUY_LIMIT price adjusted from ", askPrice, " to ", entryPrice, " (minimum distance: ", DoubleToString(minDistance, _Digits), ")");
   }
   if(pendingType == ORDER_TYPE_SELL_LIMIT && entryPrice <= currentPrice)
   {
      double minDistance = MathMax(10 * point, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point);
      // Pour les symboles Forex, utiliser une distance plus grande
      if(StringFind(_Symbol, "AUD") >= 0 || StringFind(_Symbol, "EUR") >= 0 || StringFind(_Symbol, "GBP") >= 0 || StringFind(_Symbol, "USD") >= 0)
         minDistance = MathMax(minDistance, 20 * point); // 20 pips minimum pour Forex
      entryPrice = NormalizeDouble(currentPrice + minDistance, _Digits);
      Print("🔧 SELL_LIMIT price adjusted from ", currentPrice, " to ", entryPrice, " (minimum distance: ", DoubleToString(minDistance, _Digits), ")");
   }

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
      minDistance = MathMax(minDistance, 300 * point); // 300 pips pour Boom/Crash
   
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

   // VALIDATION FINALE: Vérifier que les prix respectent toutes les contraintes
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Pour BUY_LIMIT: entryPrice doit être < Ask et respecter la distance minimale
   if(pendingType == ORDER_TYPE_BUY_LIMIT)
   {
      if(entryPrice >= currentAsk)
      {
         double minDist = MathMax(20 * point, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point);
         entryPrice = NormalizeDouble(currentAsk - minDist, _Digits);
         stopLoss = NormalizeDouble(entryPrice - MathMax(15 * point, minDist), _Digits);
         takeProfit = NormalizeDouble(entryPrice + LimitRR * (entryPrice - stopLoss), _Digits);
         Print("🔧 Final BUY_LIMIT adjustment - Entry: ", DoubleToString(entryPrice, _Digits), " SL: ", DoubleToString(stopLoss, _Digits));
      }
   }
   
   // Pour SELL_LIMIT: entryPrice doit être > Bid et respecter la distance minimale  
   if(pendingType == ORDER_TYPE_SELL_LIMIT)
   {
      if(entryPrice <= currentBid)
      {
         double minDist = MathMax(20 * point, SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point);
         entryPrice = NormalizeDouble(currentBid + minDist, _Digits);
         stopLoss = NormalizeDouble(entryPrice + MathMax(15 * point, minDist), _Digits);
         takeProfit = NormalizeDouble(entryPrice - LimitRR * (stopLoss - entryPrice), _Digits);
         Print("🔧 Final SELL_LIMIT adjustment - Entry: ", DoubleToString(entryPrice, _Digits), " SL: ", DoubleToString(stopLoss, _Digits));
      }
   }

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
   static datetime lastAPICall = 0;
   static string lastCachedResponse = "";
   
   datetime currentTime = TimeCurrent();
   
   // Cache API: éviter les appels trop fréquents (toutes les 5 secondes pour mise à jour rapide)
   if((currentTime - lastAPICall) < 5 && lastCachedResponse != "")
   {
      // Utiliser la réponse en cache
      if(StringFind(lastCachedResponse, "\"action\":") >= 0)
      {
         int actionStart = StringFind(lastCachedResponse, "\"action\":");
         actionStart = StringFind(lastCachedResponse, "\"", actionStart + 9) + 1;
         int actionEnd = StringFind(lastCachedResponse, "\"", actionStart);
         if(actionEnd > actionStart)
         {
            g_aiSignal.recommendation = StringSubstr(lastCachedResponse, actionStart, actionEnd - actionStart);
            return true;
         }
      }
   }
   
   string url = AI_ServerURL;
   string headers = "Content-Type: application/json\r\n";
   char post[];
   uchar response[];
   
   // Utiliser le cache d'indicateurs au lieu d'appels directs
   if(!GetCachedIndicators())
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération indicateurs pour IA");
      return false;
   }
   
   // Utiliser les valeurs du cache + prix actuel
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double rsi = g_indicatorCache.rsiM1;
   double emaFast = g_indicatorCache.emaFastM1;
   double emaSlow = g_indicatorCache.emaSlowM1;
   double atr = g_indicatorCache.atrM1;
   
   string jsonRequest = StringFormat("{\"symbol\":\"%s\",\"bid\":%.5f,\"ask\":%.5f,\"rsi\":%.2f,\"ema_fast\":%.5f,\"ema_slow\":%.5f,\"atr\":%.5f,\"timestamp\":\"%s\"}",
      _Symbol, bid, ask, rsi, emaFast, emaSlow, atr, TimeToString(TimeCurrent()));
   
   Print("📦 Debug IA: JSON envoyé=", jsonRequest);
   
   StringToCharArray(jsonRequest, post);
   
   int res = WebRequest("POST", url, headers, AI_Timeout_ms, post, response, headers);
   
   Print("🌐 Debug IA: WebRequest result=", res);
   
   if(res == 200)
   {
      string jsonResponse = CharArrayToString(response);
      Print("📥 Debug IA: Réponse JSON=", jsonResponse);
      
      // Mettre à jour le cache
      lastAPICall = currentTime;
      lastCachedResponse = jsonResponse;
      
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
   
   return false;
}

// Récupérer les données de tendance depuis l'API
bool GetTrendAlignmentData()
{
   static datetime lastTrendCall = 0;
   static string lastTrendResponse = "";
   
   datetime currentTime = TimeCurrent();
   
   // Cache API: éviter les appels trop fréquents (toutes les 60 secondes minimum)
   if((currentTime - lastTrendCall) < 60 && lastTrendResponse != "")
   {
      // Utiliser la réponse en cache
      g_trendAlignment.m1_trend = ExtractJSONValue(lastTrendResponse, "m1_trend");
      g_trendAlignment.h1_trend = ExtractJSONValue(lastTrendResponse, "h1_trend");
      g_trendAlignment.h4_trend = ExtractJSONValue(lastTrendResponse, "h4_trend");
      g_trendAlignment.d1_trend = ExtractJSONValue(lastTrendResponse, "d1_trend");
      
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
      return true;
   }
   
   string url = TrendLocalURL + "?symbol=" + _Symbol;
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
      
      // Mettre à jour le cache
      lastTrendCall = currentTime;
      lastTrendResponse = jsonResponse;
      
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

//+------------------------------------------------------------------+
//| Récupérer les prédictions de trendlines ML                        |
//+------------------------------------------------------------------+
bool GetMLTrendLinePredictions()
{
   if(!UseMLIntegration) return false;
   
   static datetime lastTrendCall = 0;
   static string lastTrendResponse = "";
   
   datetime currentTime = TimeCurrent();
   
   // Cache API: éviter les appels trop fréquents (toutes les 60 secondes)
   if((currentTime - lastTrendCall) < 60 && lastTrendResponse != "")
   {
      // Parser la réponse en cache et remplir le tableau
      ParseTrendLinePredictions(lastTrendResponse);
      return true;
   }
   
   string url = AI_LocalMLURL + "?symbol=" + _Symbol + "&type=trendlines&future_bars=1000";
   string headers = "Content-Type: application/json\r\n";
   char post[];
   uchar response[];
   
   Print("🔍 Debug ML Trendlines: URL=", url);
   
   int res = WebRequest("GET", url, headers, AI_Timeout_ms, post, response, headers);
   
   Print("🌐 Debug ML Trendlines: WebRequest result=", res);
   
   if(res == 200)
   {
      string jsonResponse = CharArrayToString(response);
      lastTrendCall = currentTime;
      lastTrendResponse = jsonResponse;
      
      // Parser la réponse et remplir le tableau
      ParseTrendLinePredictions(jsonResponse);
      
      Print("✅ Debug ML Trendlines: ", ArraySize(g_trendLinePredictions), " trendlines prédites");
      
      return true;
   }
   else
   {
      Print("❌ Debug ML Trendlines: Erreur WebRequest ", res);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Parser les prédictions de trendlines JSON                           |
//+------------------------------------------------------------------+
void ParseTrendLinePredictions(string json)
{
   // Vider le tableau existant
   ArrayResize(g_trendLinePredictions, 0);
   
   // Parser simple du JSON pour extraire les trendlines
   // Format attendu: {"trendlines": [{"start_time": 1234567890, "start_price": 1234.5, "end_time": 1234567890, "end_price": 1234.5, "slope": 0.001, "confidence": 0.85, "type": "support"}, ...]}
   
   int trendlinesStart = StringFind(json, "\"trendlines\"");
   if(trendlinesStart < 0) return;
   
   int arrayStart = StringFind(json, "[", trendlinesStart);
   int arrayEnd = StringFind(json, "]", arrayStart);
   if(arrayStart < 0 || arrayEnd < 0) return;
   
   string trendArray = StringSubstr(json, arrayStart + 1, arrayEnd - arrayStart - 1);
   
   // Parser chaque objet trendline
   int count = 0;
   int pos = 0;
   
   while(pos < StringLen(trendArray))
   {
      int objStart = StringFind(trendArray, "{", pos);
      if(objStart < 0) break;
      
      int objEnd = StringFind(trendArray, "}", objStart);
      if(objEnd < 0) break;
      
      string trendObj = StringSubstr(trendArray, objStart, objEnd - objStart + 1);
      
      // Extraire les valeurs
      TrendLinePrediction trend;
      trend.start_time = StringToTime(ExtractJSONValue(trendObj, "start_time"));
      trend.start_price = StringToDouble(ExtractJSONValue(trendObj, "start_price"));
      trend.end_time = StringToTime(ExtractJSONValue(trendObj, "end_time"));
      trend.end_price = StringToDouble(ExtractJSONValue(trendObj, "end_price"));
      trend.slope = StringToDouble(ExtractJSONValue(trendObj, "slope"));
      trend.confidence = StringToDouble(ExtractJSONValue(trendObj, "confidence"));
      trend.type = ExtractJSONValue(trendObj, "type");
      
      // Déterminer la couleur et le style selon le type
      if(trend.type == "support")
      {
         trend.line_color = UseMutedColors ? MUTED_GREEN : clrGreen;
         trend.width = 2;
         trend.style = STYLE_SOLID;
      }
      else if(trend.type == "resistance")
      {
         trend.line_color = UseMutedColors ? MUTED_RED : clrRed;
         trend.width = 2;
         trend.style = STYLE_SOLID;
      }
      else // trendline
      {
         trend.line_color = UseMutedColors ? MUTED_BLUE : clrBlue;
         trend.width = 1;
         trend.style = STYLE_DOT;
      }
      
      // Ajouter au tableau
      ArrayResize(g_trendLinePredictions, count + 1);
      g_trendLinePredictions[count] = trend;
      count++;
      
      pos = objEnd + 1;
   }
}

// Récupérer les données d'analyse cohérente
bool GetCoherentAnalysisData()
{
   static datetime lastCoherentCall = 0;
   static string lastCoherentResponse = "";
   
   datetime currentTime = TimeCurrent();
   
   // Cache API: éviter les appels trop fréquents (toutes les 45 secondes minimum)
   if((currentTime - lastCoherentCall) < 45 && lastCoherentResponse != "")
   {
      // Utiliser la réponse en cache
      g_coherentAnalysis.direction = ExtractJSONValue(lastCoherentResponse, "direction");
      g_coherentAnalysis.coherence_score = StringToDouble(ExtractJSONValue(lastCoherentResponse, "coherence_score"));
      g_coherentAnalysis.key_factors = ExtractJSONValue(lastCoherentResponse, "key_factors");
      g_coherentAnalysis.is_valid = (g_coherentAnalysis.coherence_score >= 70.0);
      return true;
   }
   
   string url = AI_LocalCoherentURL + "?symbol=" + _Symbol;
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
      
      // Mettre à jour le cache
      lastCoherentCall = currentTime;
      lastCoherentResponse = jsonResponse;
      
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

//+------------------------------------------------------------------+
//| Récupérer les données de recommandation ML                      |
//+------------------------------------------------------------------+
bool GetMLRecommendationData()
{
   if(!UseMLIntegration) return false;
   
   static datetime lastMLCall = 0;
   static string lastMLResponse = "";
   
   datetime currentTime = TimeCurrent();
   
   // Cache API: éviter les appels trop fréquents (toutes les 30 secondes)
   if((currentTime - lastMLCall) < 30 && lastMLResponse != "")
   {
      // Utiliser la réponse en cache
      g_mlRecommendation.recommendation = ExtractJSONValue(lastMLResponse, "recommendation");
      g_mlRecommendation.confidence = StringToDouble(ExtractJSONValue(lastMLResponse, "confidence"));
      g_mlRecommendation.accuracy = StringToDouble(ExtractJSONValue(lastMLResponse, "accuracy"));
      g_mlRecommendation.f1_score = StringToDouble(ExtractJSONValue(lastMLResponse, "f1_score"));
      g_mlRecommendation.models_trained = (int)StringToDouble(ExtractJSONValue(lastMLResponse, "models_trained"));
      g_mlRecommendation.key_features = ExtractJSONValue(lastMLResponse, "key_features");
      g_mlRecommendation.is_valid = (g_mlRecommendation.confidence >= 0.60);
      return true;
   }
   
   string url = AI_LocalMLURL + "?symbol=" + _Symbol;
   string headers = "Content-Type: application/json\r\n";
   char post[];
   uchar response[];
   
   Print("🔍 Debug ML: URL=", url);
   
   int res = WebRequest("GET", url, headers, AI_Timeout_ms, post, response, headers);
   
   Print("🌐 Debug ML: WebRequest result=", res);
   
   if(res == 200)
   {
      string jsonResponse = CharArrayToString(response);
      lastMLCall = currentTime;
      lastMLResponse = jsonResponse;
      
      g_mlRecommendation.recommendation = ExtractJSONValue(jsonResponse, "recommendation");
      g_mlRecommendation.confidence = StringToDouble(ExtractJSONValue(jsonResponse, "confidence"));
      g_mlRecommendation.accuracy = StringToDouble(ExtractJSONValue(jsonResponse, "accuracy"));
      g_mlRecommendation.f1_score = StringToDouble(ExtractJSONValue(jsonResponse, "f1_score"));
      g_mlRecommendation.models_trained = (int)StringToDouble(ExtractJSONValue(jsonResponse, "models_trained"));
      g_mlRecommendation.key_features = ExtractJSONValue(jsonResponse, "key_features");
      g_mlRecommendation.is_valid = (g_mlRecommendation.confidence >= 0.60);
      
      Print("✅ Debug ML: Rec=", g_mlRecommendation.recommendation, " Conf=", g_mlRecommendation.confidence, 
            " Acc=", g_mlRecommendation.accuracy, " Models=", g_mlRecommendation.models_trained);
      
      return true;
   }
   else
   {
      Print("❌ Debug ML: Erreur WebRequest ", res);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Récupérer les prédictions de swing points ML                     |
//+------------------------------------------------------------------+
bool GetMLSwingPointPredictions()
{
   if(!UseMLIntegration) return false;
   
   static datetime lastSwingCall = 0;
   static string lastSwingResponse = "";
   
   datetime currentTime = TimeCurrent();
   
   // Cache API: éviter les appels trop fréquents (toutes les 60 secondes)
   if((currentTime - lastSwingCall) < 60 && lastSwingResponse != "")
   {
      // Parser la réponse en cache et remplir le tableau
      ParseSwingPredictions(lastSwingResponse);
      return true;
   }
   
   string url = AI_LocalMLURL + "?symbol=" + _Symbol + "&type=swing_points&future_bars=1000";
   string headers = "Content-Type: application/json\r\n";
   char post[];
   uchar response[];
   
   Print("🔍 Debug ML Swing: URL=", url);
   
   int res = WebRequest("GET", url, headers, AI_Timeout_ms, post, response, headers);
   
   Print("🌐 Debug ML Swing: WebRequest result=", res);
   
   if(res == 200)
   {
      string jsonResponse = CharArrayToString(response);
      lastSwingCall = currentTime;
      lastSwingResponse = jsonResponse;
      
      // Parser la réponse et remplir le tableau
      ParseSwingPredictions(jsonResponse);
      
      Print("✅ Debug ML Swing: ", ArraySize(g_swingPredictions), " swing points prédits");
      
      return true;
   }
   else
   {
      Print("❌ Debug ML Swing: Erreur WebRequest ", res);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Parser les prédictions de swing points JSON                         |
//+------------------------------------------------------------------+
void ParseSwingPredictions(string json)
{
   // Vider le tableau existant
   ArrayResize(g_swingPredictions, 0);
   
   // Parser simple du JSON pour extraire les swing points
   // Format attendu: {"swing_points": [{"time": 1234567890, "price": 1234.5, "is_high": true, "confidence": 0.85, "future_bars": 50}, ...]}
   
   int swingPointsStart = StringFind(json, "\"swing_points\"");
   if(swingPointsStart < 0) return;
   
   int arrayStart = StringFind(json, "[", swingPointsStart);
   int arrayEnd = StringFind(json, "]", arrayStart);
   if(arrayStart < 0 || arrayEnd < 0) return;
   
   string swingArray = StringSubstr(json, arrayStart + 1, arrayEnd - arrayStart - 1);
   
   // Parser chaque objet swing point
   int count = 0;
   int pos = 0;
   
   while(pos < StringLen(swingArray))
   {
      int objStart = StringFind(swingArray, "{", pos);
      if(objStart < 0) break;
      
      int objEnd = StringFind(swingArray, "}", objStart);
      if(objEnd < 0) break;
      
      string swingObj = StringSubstr(swingArray, objStart, objEnd - objStart + 1);
      
      // Extraire les valeurs
      SwingPointPrediction swing;
      swing.time = StringToTime(ExtractJSONValue(swingObj, "time"));
      swing.price = StringToDouble(ExtractJSONValue(swingObj, "price"));
      swing.is_high = (ExtractJSONValue(swingObj, "is_high") == "true");
      swing.confidence = StringToDouble(ExtractJSONValue(swingObj, "confidence"));
      swing.future_bars = (int)StringToDouble(ExtractJSONValue(swingObj, "future_bars"));
      
      // Ajouter au tableau
      ArrayResize(g_swingPredictions, count + 1);
      g_swingPredictions[count] = swing;
      count++;
      
      pos = objEnd + 1;
   }
}

//+------------------------------------------------------------------+
//| Dessiner les prédictions de swing points ML sur le graphique        |
//+------------------------------------------------------------------+
void DrawMLSwingPointPredictions()
{
   if(!ShowMLRecommendations || ArraySize(g_swingPredictions) == 0) return;
   
   // Nettoyer les anciens objets de swing points ML
   ObjectsDeleteAll(0, "ML_Swing_");
   
   datetime currentTime = TimeCurrent();
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int i = 0; i < ArraySize(g_swingPredictions); i++)
   {
      SwingPointPrediction swing = g_swingPredictions[i];
      
      // Ne dessiner que les swing points dans le futur (prochaines 1000 bougies)
      if(swing.time <= currentTime) continue;
      
      // Limiter l'affichage aux 50 prochains swing points pour éviter la surcharge
      if(i >= 50) break;
      
      string objName = "ML_Swing_" + IntegerToString(i);
      
      // Calculer la position X sur le graphique
      int shift = iBarShift(_Symbol, PERIOD_M1, swing.time);
      if(shift < 0) continue; // Pas encore visible sur le graphique
      
      // Dessiner le swing point
      ObjectCreate(0, objName, OBJ_ARROW, 0, swing.time, swing.price);
      
      // Couleur et style selon le type et la confiance
      color swingColor;
      if(swing.is_high)
      {
         // Swing High - Rouge pour haute confiance, Orange pour moyenne
         swingColor = (swing.confidence >= 0.8) ? (UseMutedColors ? MUTED_RED : clrRed) : 
                     (swing.confidence >= 0.6) ? (UseMutedColors ? MUTED_ORANGE : clrOrange) : 
                     (UseMutedColors ? MUTED_YELLOW : clrYellow);
         ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 159); // Cercle
      }
      else
      {
         // Swing Low - Vert pour haute confiance, Cyan pour moyenne
         swingColor = (swing.confidence >= 0.8) ? (UseMutedColors ? MUTED_GREEN : clrGreen) : 
                     (swing.confidence >= 0.6) ? (UseMutedColors ? MUTED_CYAN : clrCyan) : 
                     (UseMutedColors ? MUTED_BLUE : clrBlue);
         ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 159); // Cercle
      }
      
      ObjectSetInteger(0, objName, OBJPROP_COLOR, swingColor);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      
      // Ajouter une étiquette avec la confiance
      string labelName = "ML_Swing_Label_" + IntegerToString(i);
      ObjectCreate(0, labelName, OBJ_TEXT, 0, swing.time, swing.price);
      
      string labelText = DoubleToString(swing.confidence * 100, 0) + "%";
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, swingColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, swing.is_high ? ANCHOR_UPPER : ANCHOR_LOWER);
      
      // Ajuster la position de l'étiquette
      double labelOffset = 20 * point;
      if(swing.is_high)
      {
         ObjectSetDouble(0, labelName, OBJPROP_PRICE, swing.price + labelOffset);
      }
      else
      {
         ObjectSetDouble(0, labelName, OBJPROP_PRICE, swing.price - labelOffset);
      }
      
      // Ajouter une ligne horizontale pour les swing points de haute confiance
      if(swing.confidence >= 0.75)
      {
         string lineName = "ML_Swing_Line_" + IntegerToString(i);
         ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, swing.price);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, swingColor);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      }
   }
   
   Print("🎯 ML Swing Points: ", ArraySize(g_swingPredictions), " prédictions dessinées");
}

//+------------------------------------------------------------------+
//| Dessiner les trendlines ML prédites sur le graphique              |
//+------------------------------------------------------------------+
void DrawMLTrendLines()
{
   if(!ShowMLRecommendations || ArraySize(g_trendLinePredictions) == 0) return;
   
   // Nettoyer les anciens objets de trendlines ML
   ObjectsDeleteAll(0, "ML_Trend_");
   
   datetime currentTime = TimeCurrent();
   
   for(int i = 0; i < ArraySize(g_trendLinePredictions); i++)
   {
      TrendLinePrediction trend = g_trendLinePredictions[i];
      
      // Ne dessiner que les trendlines dans le futur (prochaines 1000 bougies)
      if(trend.end_time <= currentTime) continue;
      
      // Limiter l'affichage aux 20 prochaines trendlines pour éviter la surcharge
      if(i >= 20) break;
      
      string objName = "ML_Trend_" + IntegerToString(i);
      
      // Créer la trendline
      ObjectCreate(0, objName, OBJ_TREND, 0, trend.start_time, trend.start_price, trend.end_time, trend.end_price);
      
      // Appliquer les propriétés visuelles
      ObjectSetInteger(0, objName, OBJPROP_COLOR, trend.line_color);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, trend.width);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, trend.style);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true); // En arrière-plan
      ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, true); // Prolonger à droite
      
      // Ajouter une étiquette avec la confiance et le type
      string labelName = "ML_Trend_Label_" + IntegerToString(i);
      ObjectCreate(0, labelName, OBJ_TEXT, 0, trend.start_time, trend.start_price);
      
      string labelText = trend.type + " " + DoubleToString(trend.confidence * 100, 0) + "%";
      ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, trend.line_color);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      
      // Ajuster la position de l'étiquette pour éviter la superposition
      double labelOffset = 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(trend.type == "resistance")
      {
         ObjectSetDouble(0, labelName, OBJPROP_PRICE, trend.start_price + labelOffset);
      }
      else
      {
         ObjectSetDouble(0, labelName, OBJPROP_PRICE, trend.start_price - labelOffset);
      }
      
      // Pour les trendlines de haute confiance, ajouter une ligne horizontale aux points clés
      if(trend.confidence >= 0.80)
      {
         string hlineName = "ML_Trend_HLine_" + IntegerToString(i);
         ObjectCreate(0, hlineName, OBJ_HLINE, 0, 0, trend.end_price);
         ObjectSetInteger(0, hlineName, OBJPROP_COLOR, trend.line_color);
         ObjectSetInteger(0, hlineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, hlineName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, hlineName, OBJPROP_BACK, true);
      }
   }
   
   Print("📈 ML Trendlines: ", ArraySize(g_trendLinePredictions), " trendlines dessinées");
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
   // Conserver les valeurs par défaut
   string defaultAction = "HOLD";
   double defaultConfidence = 0.0;
   
   g_finalDecision.action = defaultAction;
   g_finalDecision.final_confidence = defaultConfidence;
   g_finalDecision.execution_type = "NONE";
   g_finalDecision.entry_price = 0.0;
   g_finalDecision.stop_loss = 0.0;
   g_finalDecision.take_profit = 0.0;
   g_finalDecision.reasoning = "";
   
   // Utiliser les variables réellement mises à jour
   string actualAction = (g_lastAIAction != "") ? g_lastAIAction : g_aiSignal.recommendation;
   double actualConfidence = (g_lastAIConfidence > 0) ? g_lastAIConfidence : g_aiSignal.confidence;
   
   // NOUVEAU: Si pas de signal IA, utiliser le mouvement de prix comme repli
   if(actualAction == "" || actualAction == "WAITING" || actualConfidence <= 0.0)
   {
      // Détecter le mouvement de prix récent
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      static double lastPrice = 0.0;
      static datetime lastPriceTime = 0;
      
      if(lastPrice > 0 && (TimeCurrent() - lastPriceTime) <= 60) // Dans la dernière minute
      {
         double priceChange = currentPrice - lastPrice;
         double changePercent = MathAbs(priceChange / lastPrice) * 100.0;
         
         if(changePercent > 0.1) // Mouvement significatif de 0.1%
         {
            if(priceChange > 0)
            {
               actualAction = "BUY";
               actualConfidence = 0.6; // Confiance modérée basée sur le prix
            }
            else
            {
               actualAction = "SELL";
               actualConfidence = 0.6; // Confiance modérée basée sur le prix
            }
            
            g_lastAIAction = actualAction;
            g_lastAIConfidence = actualConfidence;
            
            Print("🔄 REPLI PRIX: Mouvement détecté - ", actualAction, " (", DoubleToString(changePercent, 2), "%)");
         }
      }
      
      lastPrice = currentPrice;
      lastPriceTime = TimeCurrent();
   }
   
   // Debug: Afficher les valeurs brutes
   Print("🔍 Debug Decision: IA (ancien) action=", g_lastAIAction, " confidence=", g_lastAIConfidence);
   Print("🔍 Debug Decision: IA (nouveau) recommendation=", g_aiSignal.recommendation, " confidence=", g_aiSignal.confidence);
   Print("🔍 Debug Decision: Utilisé - action=", actualAction, " confidence=", actualConfidence);
   Print("🔍 Debug Decision: Trend alignment=", g_trendAlignment.is_aligned, " Score=", g_trendAlignment.alignment_score);
   Print("🔍 Debug Decision: Coherent score=", g_coherentAnalysis.coherence_score, " Valid=", g_coherentAnalysis.is_valid);
   
   // Calculer une décision même si les conditions strictes ne sont pas remplies
   if(actualConfidence > 0.0) // Si on a au moins une donnée IA
   {
      // Utiliser le signal IA comme base
      g_finalDecision.action = actualAction;
      
      // Calculer une confiance pondérée même si conditions non remplies
      double iaWeight = 0.45;
      double trendWeight = 0.25;
      double coherentWeight = 0.20;
      double mlWeight = (UseMLIntegration && UseMLForFinalDecision) ? MLDecisionWeight : 0.0;
      
      double trendContribution = (g_trendAlignment.alignment_score / 100.0) * trendWeight;
      double coherentContribution = (g_coherentAnalysis.coherence_score / 100.0) * coherentWeight;
      double iaContribution = actualConfidence * iaWeight;
      double mlContribution = 0.0;
      
      // Ajouter la contribution ML si activée
      if(UseMLIntegration && UseMLForFinalDecision && g_mlRecommendation.is_valid)
      {
         mlContribution = g_mlRecommendation.confidence * mlWeight;
         Print("🤖 ML Integration: Rec=", g_mlRecommendation.recommendation, 
               " Conf=", g_mlRecommendation.confidence, " Acc=", g_mlRecommendation.accuracy);
      }
      
      // Normaliser les poids si ML est activé
      double totalWeight = iaWeight + trendWeight + coherentWeight + mlWeight;
      g_finalDecision.final_confidence = (iaContribution + trendContribution + coherentContribution + mlContribution) / totalWeight;
      
      // Scénario affiché: ne pas prendre position si tendance ou cohérence contredit le signal IA
      bool trendSaysBuy  = (g_trendAlignment.m1_trend == "UP" || g_trendAlignment.h1_trend == "UP");
      bool trendSaysSell = (g_trendAlignment.m1_trend == "DOWN" || g_trendAlignment.h1_trend == "DOWN");
      bool coherentSaysBuy  = (g_coherentAnalysis.direction == "BUY" || g_coherentAnalysis.direction == "UP");
      bool coherentSaysSell = (g_coherentAnalysis.direction == "SELL" || g_coherentAnalysis.direction == "DOWN");
      if(g_finalDecision.action == "BUY" && (trendSaysSell || coherentSaysSell))
      {
         g_finalDecision.final_confidence = MathMin(g_finalDecision.final_confidence, 0.45);
         if(g_finalDecision.final_confidence < 0.5) g_finalDecision.action = "HOLD";
         if(DebugMode) Print("📉 Scénario défavorable pour BUY: trend ou cohérent en baisse -> confiance réduite ou HOLD");
      }
      else if(g_finalDecision.action == "SELL" && (trendSaysBuy || coherentSaysBuy))
      {
         g_finalDecision.final_confidence = MathMin(g_finalDecision.final_confidence, 0.45);
         if(g_finalDecision.final_confidence < 0.5) g_finalDecision.action = "HOLD";
         if(DebugMode) Print("📈 Scénario défavorable pour SELL: trend ou cohérent en hausse -> confiance réduite ou HOLD");
      }
      
      // Si la confiance est trop faible, rester en HOLD
      if(g_finalDecision.final_confidence < 0.3)
      {
         g_finalDecision.action = "HOLD";
         g_finalDecision.final_confidence = MathMax(g_finalDecision.final_confidence, 0.1); // Montrer au minimum 10%
      }
      
      // Déterminer le type d'exécution
      if(g_finalDecision.action != "HOLD")
      {
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
      }
      
      g_finalDecision.reasoning = "Signal IA (" + DoubleToString(actualConfidence * 100, 1) + 
                                 "%) + Alignement (" + DoubleToString(g_trendAlignment.alignment_score, 1) + 
                                 "%) + Cohérence (" + DoubleToString(g_coherentAnalysis.coherence_score, 1) + "%)";
   }
   
   Print("⚡ Debug Decision Final: Action=", g_finalDecision.action, " Confiance=", g_finalDecision.final_confidence);
}

// Calculer les niveaux optimaux d'entrée
void CalculateOptimalEntryLevels()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double lotSize = CalculateOptimalLotSize();
   
   // Calculer la distance SL en points pour une perte de StopLossUSD (5$ par défaut)
   // SL distance = StopLossUSD / (lotSize * valeur_du_tick_par_point)
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointsPerDollar = (tickSize > 0) ? (tickValue / tickSize) : 0;
   
   // Si pointsPerDollar est 0 ou invalide, utiliser une estimation basée sur le point
   if(pointsPerDollar <= 0 || lotSize <= 0)
   {
      // Fallback: utiliser ATR ou distance minimale broker
      double atr[];
      if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
         pointsPerDollar = atr[0] / point / 2.0; // Estimation conservatrice
      else
         pointsPerDollar = 100; // Fallback: 100 points par dollar
   }
   
   // Distance SL en points pour StopLossUSD de perte
   double slDistancePoints = (StopLossUSD / (lotSize * pointsPerDollar)) * point;
   
      // Minimum: respecter les exigences du broker (via ValidateAndAdjustStops)
      // Augmenter la distance SL pour laisser le prix bouger normalement (minimum 3x ATR)
      double atr[];
      if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
      {
         double atrBasedSL = atr[0] * 3.0; // 3x ATR minimum pour plus de marge
         slDistancePoints = MathMax(slDistancePoints, atrBasedSL);
      }
      
      // Multiplier par 1.5 pour augmenter encore la distance SL
      slDistancePoints = slDistancePoints * 1.5;
   
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
      
      // SL basé sur la perte admise (5$) - laisser le prix bouger normalement
      g_finalDecision.stop_loss = g_finalDecision.entry_price - slDistancePoints;
      
      // TP: 2x SL pour un ratio 1:2
      if(g_finalDecision.execution_type == "SCALP_VOLATILITY")
      {
         g_finalDecision.take_profit = g_finalDecision.entry_price + 5.0; // 5$ pour Volatility
      }
      else
      {
         g_finalDecision.take_profit = g_finalDecision.entry_price + (slDistancePoints * 2.0);
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
      
      // SL basé sur la perte admise (5$) - laisser le prix bouger normalement
      g_finalDecision.stop_loss = g_finalDecision.entry_price + slDistancePoints;
      
      // TP: 2x SL pour un ratio 1:2
      if(g_finalDecision.execution_type == "SCALP_VOLATILITY")
      {
         g_finalDecision.take_profit = g_finalDecision.entry_price - 5.0; // 5$ pour Volatility
      }
      else
      {
         g_finalDecision.take_profit = g_finalDecision.entry_price - (slDistancePoints * 2.0);
      }
   }
}

//+------------------------------------------------------------------+
//| DÉTECTE UN REBOND DEPUIS UNE ZONE AI BUY/SELL APRÈS CORRECTION    |
//+------------------------------------------------------------------+
bool DetectAIZoneRebound(string &detectedAction, double &entryPrice, double &confidenceBoost)
{
   detectedAction = "";
   entryPrice = 0.0;
   confidenceBoost = 0.0;
   
   if(g_aiBuyZoneLow <= 0 || g_aiBuyZoneHigh <= 0 || g_aiSellZoneLow <= 0 || g_aiSellZoneHigh <= 0)
      return false; // Zones AI non disponibles
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Récupérer les dernières bougies pour détecter la correction et le rebond
   double close[], high[], low[];
   datetime time[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(time, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 10, close) < 10 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, 10, high) < 10 ||
      CopyLow(_Symbol, PERIOD_M1, 0, 10, low) < 10)
      return false;
   
   // DÉTECTION REBOND DEPUIS ZONE AI BUY (après correction dans trend BUY)
   bool trendIsBuy = (g_trendAlignment.m1_trend == "UP" || g_trendAlignment.h1_trend == "UP" ||
                      g_lastAIAction == "BUY" || g_aiSignal.recommendation == "BUY");
   
   if(trendIsBuy && currentPrice >= g_aiBuyZoneLow && currentPrice <= g_aiBuyZoneHigh)
   {
      // Vérifier qu'il y a eu une correction (prix était au-dessus de la zone avant)
      bool hadCorrection = false;
      for(int i = 3; i < 8; i++)
      {
         if(high[i] > g_aiBuyZoneHigh)
         {
            hadCorrection = true;
            break;
         }
      }
      
      // Vérifier le rebond: les dernières bougies montrent une remontée
      bool isRebounding = false;
      if(hadCorrection)
      {
         // Le prix a touché ou est entré dans la zone (correction terminée)
         bool touchedZone = (low[1] <= g_aiBuyZoneHigh || low[2] <= g_aiBuyZoneHigh);
         
         // Rebond détecté: les dernières bougies montent (close actuel > close précédent)
         if(touchedZone && close[0] > close[1] && close[1] > close[2])
         {
            isRebounding = true;
         }
         // Ou rebond immédiat: bougie actuelle haussière (close > low) après avoir touché la zone
         else if(touchedZone && close[0] > low[0] && low[0] <= g_aiBuyZoneHigh && close[0] > close[1])
         {
            isRebounding = true;
         }
      }
      
      if(hadCorrection && isRebounding)
      {
         detectedAction = "BUY";
         entryPrice = currentPrice;
         confidenceBoost = 0.15; // Boost de confiance pour rebond zone AI
         if(DebugMode)
            Print("🎯 REBOND ZONE AI BUY DÉTECTÉ: Trend BUY + Correction + Rebond depuis zone [", 
                  g_aiBuyZoneLow, "-", g_aiBuyZoneHigh, "]");
         return true;
      }
   }
   
   // DÉTECTION REBOND DEPUIS ZONE AI SELL (après correction dans trend SELL)
   bool trendIsSell = (g_trendAlignment.m1_trend == "DOWN" || g_trendAlignment.h1_trend == "DOWN" ||
                       g_lastAIAction == "SELL" || g_aiSignal.recommendation == "SELL");
   
   if(trendIsSell && currentPrice >= g_aiSellZoneLow && currentPrice <= g_aiSellZoneHigh)
   {
      // Vérifier qu'il y a eu une correction (prix était en-dessous de la zone avant)
      bool hadCorrection = false;
      for(int i = 3; i < 8; i++)
      {
         if(low[i] < g_aiSellZoneLow)
         {
            hadCorrection = true;
            break;
         }
      }
      
      // Vérifier le rebond: les dernières bougies montrent une baisse
      bool isRebounding = false;
      if(hadCorrection)
      {
         // Le prix a touché ou est entré dans la zone (correction terminée)
         bool touchedZone = (high[1] >= g_aiSellZoneLow || high[2] >= g_aiSellZoneLow);
         
         // Rebond détecté: les dernières bougies baissent (close actuel < close précédent)
         if(touchedZone && close[0] < close[1] && close[1] < close[2])
         {
            isRebounding = true;
         }
         // Ou rebond immédiat: bougie actuelle baissière (close < high) après avoir touché la zone
         else if(touchedZone && close[0] < high[0] && high[0] >= g_aiSellZoneLow && close[0] < close[1])
         {
            isRebounding = true;
         }
      }
      
      if(hadCorrection && isRebounding)
      {
         detectedAction = "SELL";
         entryPrice = currentPrice;
         confidenceBoost = 0.15; // Boost de confiance pour rebond zone AI
         if(DebugMode)
            Print("🎯 REBOND ZONE AI SELL DÉTECTÉ: Trend SELL + Correction + Rebond depuis zone [", 
                  g_aiSellZoneLow, "-", g_aiSellZoneHigh, "]");
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| FONCTION D'EXÉCUTION DE LA STRATÉGIE AVANCÉE                      |
//+------------------------------------------------------------------+
void ExecuteOrderLogic()
{
   // NOUVEAU: Vérifier le cooldown global anti-bruit
   if(IsGlobalCooldownActive())
   {
      if(DebugMode)
         Print("🕐 COOLDOWN GLOBAL ACTIF: attente de ", GlobalTradeCooldownMinutes, " minutes avant nouveau trade");
      return;
   }
   
   // NOUVEAU: Une seule position par symbole (ordre limite ou marché)
   bool hasPositionOnCurrentSymbol = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Magic() == InpMagicNumber && positionInfo.Symbol() == _Symbol)
         {
            hasPositionOnCurrentSymbol = true;
            break;
         }
      }
   }
   
   // Si déjà une position sur ce symbole, ne pas trader
   if(hasPositionOnCurrentSymbol)
   {
      if(DebugMode)
         Print("🚫 POSITION EXISTANTE: déjà une position sur ", _Symbol, " - pas de nouvel ordre");
      return;
   }
   
   // NOUVEAU: Limiter à 3 symboles maximum simultanément
   int activeSymbols = CountActiveSymbols();
   if(activeSymbols >= 3)
   {
      if(DebugMode)
         Print("🚫 LIMITE ATTEINTE: ", activeSymbols, "/3 symboles actifs - pas d'ordre sur ", _Symbol);
      return;
   }
   
   // PRIORITÉ 1: Vérifier les rebonds depuis les zones AI BUY/SELL
   string reboundAction;
   double reboundEntry;
   double reboundBoost;
   if(DetectAIZoneRebound(reboundAction, reboundEntry, reboundBoost))
   {
      Print("🚀 REBOND ZONE AI DÉTECTÉ - PRIORITÉ D'ENTRÉE!");
      Print("   Action: ", reboundAction, " @ ", DoubleToString(reboundEntry, _Digits));
      Print("   Boost confiance: +", DoubleToString(reboundBoost * 100, 1), "%");
      
      // Ajuster la décision finale pour le rebond
      g_finalDecision.action = reboundAction;
      g_finalDecision.entry_price = reboundEntry;
      g_finalDecision.final_confidence = MathMin(0.95, g_finalDecision.final_confidence + reboundBoost);
      
      // Recalculer les niveaux SL/TP pour cette entrée optimale
      CalculateOptimalEntryLevels();
      
      // Exécuter l'ordre immédiatement au rebond
      double lotSize = CalculateOptimalLotSize();
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(reboundAction == "BUY")
      {
         double execAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double sl = g_finalDecision.stop_loss;
         double tp = g_finalDecision.take_profit;
         ValidateAndAdjustStops(execAsk, sl, tp, ORDER_TYPE_BUY);
         
         if(trade.Buy(lotSize, _Symbol, 0, sl, tp, "REBOND ZONE AI BUY - " + g_finalDecision.reasoning))
         {
            Print("✅ ORDRE BUY EXÉCUTÉ AU REBOND ZONE AI");
            Print("   Prix: ", DoubleToString(execAsk, _Digits));
            Print("   SL: ", DoubleToString(sl, _Digits), " TP: ", DoubleToString(tp, _Digits));
            Print("   Confiance: ", DoubleToString(g_finalDecision.final_confidence * 100, 1), "%");
         }
      }
      else if(reboundAction == "SELL")
      {
         // VÉRIFICATION CRITIQUE: Interdire les SELL sur Boom
         if(StringFind(_Symbol, "Boom", 0) != -1)
         {
            Print("🚫 BLOQUÉ: Rebond SELL détecté sur ", _Symbol, " mais Boom = BUY uniquement - Ordre annulé");
            return;
         }
         
         double execBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double sl = g_finalDecision.stop_loss;
         double tp = g_finalDecision.take_profit;
         
         // Vérification critique: pour SELL, SL doit être > prix et TP < prix
         if(sl <= execBid || tp >= execBid)
         {
            Print("⚠️ SL/TP invalides pour SELL - Recalcul...");
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double atr[];
            if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
            {
               double safeDistance = atr[0] * 3.0;
               sl = execBid + safeDistance;
               tp = execBid - (safeDistance * 2.0);
            }
            else
            {
               sl = execBid + (2000 * point);
               tp = execBid - (4000 * point);
            }
         }
         
         ValidateAndAdjustStops(execBid, sl, tp, ORDER_TYPE_SELL);
         
         // Vérification finale avant exécution
         if(sl <= execBid || tp >= execBid || sl <= tp)
         {
            Print("❌ ERREUR: SL/TP toujours invalides après validation - SELL annulé");
            Print("   Prix: ", execBid, " SL: ", sl, " TP: ", tp);
            return;
         }
         
         if(trade.Sell(lotSize, _Symbol, 0, sl, tp, "REBOND ZONE AI SELL - " + g_finalDecision.reasoning))
         {
            Print("✅ ORDRE SELL EXÉCUTÉ AU REBOND ZONE AI");
            Print("   Prix: ", DoubleToString(execBid, _Digits));
            Print("   SL: ", DoubleToString(sl, _Digits), " TP: ", DoubleToString(tp, _Digits));
            Print("   Confiance: ", DoubleToString(g_finalDecision.final_confidence * 100, 1), "%");
         }
      }
      
      return; // Sortir après avoir traité le rebond
   }
   
   // Si pas de décision claire, ne rien faire (seuil configurable)
   if(g_finalDecision.action == "HOLD" || g_finalDecision.final_confidence < MinConfidenceToEvaluate)
      return;
   
   // CONDITIONS SPÉCIFIQUES POUR BOOM: très sélectif
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   
   if(isBoom)
   {
      // Vérifier si les conditions sont vraiment favorables pour BUY sur Boom
      bool coherenceUp = (g_coherentAnalysis.direction == "UP" || g_coherentAnalysis.direction == "BUY");
      bool iaBuy = (g_lastAIAction == "BUY" || g_aiSignal.recommendation == "BUY");
      
      // Vérifier si les dérivés sont devenus verts (indicateur de momentum haussier)
      bool derivativesGreen = CheckDerivativesColor(); // Vérifier la couleur des dérivés
      
      // Conditions strictes pour BUY sur Boom
      if(g_finalDecision.action == "BUY")
      {
         if(!coherenceUp && !iaBuy)
         {
            Print("❌ BOOM: Conditions non favorables - Cohérence=", g_coherentAnalysis.direction, 
                  " IA=", (iaBuy ? "BUY" : "NON-BUY"), " - ATTENTE");
            return; // Ne pas trader si conditions non favorables
         }
         
         if(!derivativesGreen && g_finalDecision.final_confidence < 0.65)
         {
            Print("❌ BOOM: Dérivés pas verts ET confiance<65% - ATTENTE");
            return; // Exiger dérivés verts seulement si confiance < 65%
         }
         
         Print("✅ BOOM: Conditions favorables - Cohérence UP/IA BUY", derivativesGreen ? " + Dérivés verts" : " (dérivés bypass si confiance>=65%)");
      }
      else if(g_finalDecision.action == "SELL")
      {
         Print("✅ BOOM: SELL autorisé - Signal IA présent");
         // Continuer vers l'exécution du trade SELL
      }
   }
   
   // Vérifier si la confiance IA dépasse le seuil et la décision finale est alignée
   bool aiHighConfidence = (g_lastAIConfidence >= MinAIConfidenceForLimitOrder);
   bool decisionAligned = false;
   
   if(g_finalDecision.action == "BUY")
   {
      decisionAligned = (g_lastAIAction == "BUY" || g_aiSignal.recommendation == "BUY");
   }
   else if(g_finalDecision.action == "SELL")
   {
      decisionAligned = (g_lastAIAction == "SELL" || g_aiSignal.recommendation == "SELL");
   }
   
   // Si confiance IA > 70% et décision alignée: ordre limite automatique au support/résistance M1
   if(aiHighConfidence && decisionAligned)
   {
      Print("🎯 CONFIANCE IA ÉLEVÉE (>=", DoubleToString(MinAIConfidenceForLimitOrder*100,0), "%) + DÉCISION ALIGNÉE - ORDRE LIMITE AUTOMATIQUE");
      ExecuteAutoLimitOrder();
      return; // Exécuter l'ordre limite et sortir
   }
   
   // NOUVEAU: Permettre les ordres limites même en WAITING si flèche DERIV présente - DÉSACTIVÉ pour performance
   /*if(g_finalDecision.action == "WAIT" || g_finalDecision.action == "HOLD")
   {
      bool hasDerivArrow = IsDerivArrowPresent();
      
      if(hasDerivArrow)
      {
         Print("🔄 MODE WAITING MAIS FLÈCHE DERIV DÉTECTÉE - ORDRE LIMITE AUTORISÉ");
         Print("   📍 DÉCISION: ", g_finalDecision.action);
         Print("   🏹 Flèche DERIV présente: OUI");
         Print("   🧠 Confiance IA: ", DoubleToString(g_lastAIConfidence * 100, 1), "%");
         Print("   📊 Action IA: ", g_lastAIAction);
         
         // Exécuter un ordre limite basé sur la direction de la flèche DERIV
         ExecuteAutoLimitOrder();
         return; // Exécuter et sortir
      }
   }*/
   else
      {
         if(DebugMode)
            Print("⏸️ Mode WAITING - Pas de flèche DERIV détectée, attente...");
      }
   
   // Placer des ORDRES LIMIT au-dessus du support le plus proche
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lotSize = CalculateOptimalLotSize();
   
   // Vérifier si la stratégie FVG_Kill doit être utilisée
   if(UseFVGKillStrategy && FVG_ShouldTrade("BUY"))
   {
      Print("🔥 FVG_Kill: Conditions BUY détectées - Exécution avec IA");
      FVG_ExecuteBuyWithAI();
      return;
   }
   
   if(UseFVGKillStrategy && FVG_ShouldTrade("SELL"))
   {
      Print("🔥 FVG_Kill: Conditions SELL détectées - Exécution avec IA");
      FVG_ExecuteSellWithAI();
      return;
   }
   
   // Calculer les niveaux de support/résistance
   double support, resistance;
   CalculateSupportResistance(support, resistance);
   
   if(g_finalDecision.action == "BUY")
   {
      // Pour BUY: vérifier si le prix s'approche d'un support confirmé
      double distanceToSupport = currentPrice - support;
      bool nearSupport = (distanceToSupport <= 30 * SymbolInfoDouble(_Symbol, SYMBOL_POINT)); // 30 pips du support
      
      // CONDITIONS TRÈS FAVORABLES: ACHAT IMMÉDIAT
      bool veryFavorable = (g_finalDecision.final_confidence >= 0.75); // Très haute confiance
      bool trendUp = (g_trendAlignment.m1_trend == "UP" || g_trendAlignment.h1_trend == "UP");
      
      if(isBoom && (veryFavorable || trendUp || nearSupport))
      {
         // BOOM: PRENDRE BUY IMMÉDIATEMENT - conditions très favorables
         string reason = "IMMÉDIAT";
         if(veryFavorable) reason += " - Confiance élevée";
         if(trendUp) reason += " - Trend UP";
         if(nearSupport) reason += " - Près support";
         
         Print("🚀 BOOM: Conditions très favorables - ", reason, " - BUY IMMÉDIAT !");
         
         // EXÉCUTION SANS SL/TP - Boom/Crash sans stops
         if(trade.Buy(lotSize, _Symbol, 0, 0, 0, "BOOM IMMEDIATE BUY - " + reason + " - " + g_finalDecision.reasoning))
         {
            Print("💎 BOOM BUY IMMÉDIAT EXÉCUTÉ SANS SL/TP @ ", DoubleToString(currentPrice, _Digits));
            Print("📊 Support: ", DoubleToString(support, _Digits));
            Print("💰 Prix d'entrée: ", DoubleToString(currentPrice, _Digits));
            Print("🎯 Confiance: ", DoubleToString(g_finalDecision.final_confidence * 100, 1), "%");
            Print("📈 Trend: M1=", g_trendAlignment.m1_trend, " H1=", g_trendAlignment.h1_trend);
            Print("⚠️ SL/TP: DÉSACTIVÉS (Boom/Crash sans stops)");
         }
      }
      else
      {
         // Normal: placer ordre LIMIT au-dessus du support le plus proche
         double limitPrice = support + (20 * SymbolInfoDouble(_Symbol, SYMBOL_POINT)); // 20 pips au-dessus du support
         
         // S'assurer que le prix limite est en dessous du prix actuel
         if(limitPrice >= currentPrice)
         {
            limitPrice = currentPrice - (10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT)); // 10 pips en dessous du prix
         }
         
         // Placer ordre LIMIT BUY
         string commentBuy = "LIMIT ORDER @ Support+20pips - " + (string)g_finalDecision.reasoning;
         
         // EXÉCUTION SANS SL/TP - Boom/Crash sans stops
         if(trade.BuyLimit(lotSize, limitPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, commentBuy))
         {
            Print("🎯 ORDRE LIMIT BUY PLACÉ SANS SL/TP @ ", DoubleToString(limitPrice, _Digits));
            Print("📊 Support le plus proche: ", DoubleToString(support, _Digits));
            Print("📍 Prix limite: ", DoubleToString(limitPrice, _Digits), " (+20 pips)");
            Print("💰 Prix actuel: ", DoubleToString(currentPrice, _Digits));
            Print("🎯 Confiance: ", DoubleToString(g_finalDecision.final_confidence * 100, 1), "%");
            Print("⚠️ SL/TP: DÉSACTIVÉS (Boom/Crash sans stops)");
            
            // Enregistrer la direction exécutée pour le suivi des changements
            g_lastExecutedDirection = "BUY";
         }
      }
   }
   else if(g_finalDecision.action == "SELL")
   {
      // Pour SELL: placer ordre LIMIT au-dessous de la résistance la plus proche
      double limitPrice = resistance - (20 * SymbolInfoDouble(_Symbol, SYMBOL_POINT)); // 20 pips en dessous de la résistance
      
      // S'assurer que le prix limite est au-dessus du prix actuel
      if(limitPrice <= currentPrice)
      {
         limitPrice = currentPrice + (10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT)); // 10 pips au-dessus du prix
      }
      
      // Placer ordre LIMIT SELL
      string commentSell = "LIMIT ORDER @ Resistance-20pips - " + (string)g_finalDecision.reasoning;
      
      // EXÉCUTION SANS SL/TP - Boom/Crash sans stops
      if(trade.SellLimit(lotSize, limitPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, commentSell))
      {
         Print("🎯 ORDRE LIMIT SELL PLACÉ SANS SL/TP @ ", DoubleToString(limitPrice, _Digits));
         Print("📊 Résistance la plus proche: ", DoubleToString(resistance, _Digits));
         Print("📍 Prix limite: ", DoubleToString(limitPrice, _Digits), " (-20 pips)");
         Print("💰 Prix actuel: ", DoubleToString(currentPrice, _Digits));
         Print("🎯 Confiance: ", DoubleToString(g_finalDecision.final_confidence * 100, 1), "%");
         Print("⚠️ SL/TP: DÉSACTIVÉS (Boom/Crash sans stops)");
         
         // Enregistrer la direction exécutée pour le suivi des changements
         g_lastExecutedDirection = "SELL";
      }
   }
}

//+------------------------------------------------------------------+
//| Calcul de la taille de lot optimale                               |
//+------------------------------------------------------------------+
double CalculateOptimalLotSize()
{
   // TOUJOURS utiliser le lot minimum autorisé pour tous les symboles
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   double lotSize = minLot; // Toujours le minimum
   
   // Arrondir selon le step du symbole
   if(lotStep > 0)
   {
      lotSize = MathRound(lotSize / lotStep) * lotStep;
   }
   
   // S'assurer que le lot est dans les limites
   lotSize = MathMax(lotSize, minLot);
   lotSize = MathMin(lotSize, maxLot);
   
   if(DebugMode)
   {
      Print("📊 LOT MINIMUM: Lot=", DoubleToString(lotSize, 2), 
            " (Min=", DoubleToString(minLot, 2), 
            " Max=", DoubleToString(maxLot, 2), 
            " Step=", DoubleToString(lotStep, 2), ")");
   }
   
   return NormalizeDouble(lotSize, 2);
}
void UpdateAdvancedDashboard()
{
   if(!ShowDashboard) return;
   
   datetime currentTime = TimeCurrent();
   // Pas de vérification de temps ici, gérée dans OnTick()
   
   // Initialiser les données si vides
   if(g_aiSignal.recommendation == "")
   {
      g_aiSignal.recommendation = "WAITING";
      g_aiSignal.confidence = 0.5;
   }
   
   if(g_trendAlignment.m1_trend == "")
   {
      g_trendAlignment.m1_trend = "NEUTRAL";
      g_trendAlignment.h1_trend = "NEUTRAL";
      g_trendAlignment.alignment_score = 50.0;
      g_trendAlignment.is_aligned = false;
   }
   
   if(g_coherentAnalysis.direction == "")
   {
      g_coherentAnalysis.direction = "NEUTRAL";
      g_coherentAnalysis.coherence_score = 50.0;
   }
   
   if(g_finalDecision.action == "")
   {
      g_finalDecision.action = "WAIT";
      g_finalDecision.final_confidence = 0.5;
   }
   
   // Récupérer les données IA (API) - optimisé selon mode performance
   static int callCounter = 0;
   bool iaSuccess = false;
   int apiCallFrequency = (UltraPerformanceMode ? 100 : (HighPerformanceMode ? 10 : 3)); // Appels API ultra réduits = charge minimale absolue
   if(callCounter % apiCallFrequency == 0) // Appeler l'API moins souvent
   {
      iaSuccess = GetAISignalData();
   }
   callCounter++;
   
   // Calculer les tendances localement avec les EMA (plus fiable que les API) - DÉSACTIVÉ pour performance
   // CalculateLocalTrends();
   
   // Calculer la cohérence localement - DÉSACTIVÉ pour performance
   // CalculateLocalCoherence();
   
   // Détecter les spikes pour Boom/Crash (NOUVEAU) - DÉSACTIVÉ pour performance
   // CalculateSpikePrediction();
   
   string iaStatus = iaSuccess ? "true" : "false";
   string scientificStatus = "false"; // Simplifié - plus de prédiction scientifique
   
   // Afficher les valeurs brutes pour debug (une fois sur 3)
   if(callCounter % 3 == 0)
   {
      Print("🔍 Debug Dashboard - Valeurs brutes:");
      Print("   IA (ancien système): action='" + g_lastAIAction + "' confidence=" + DoubleToString(g_lastAIConfidence, 3));
      Print("   Trend: M1='" + g_trendAlignment.m1_trend + "' H1='" + g_trendAlignment.h1_trend + "' score=" + DoubleToString(g_trendAlignment.alignment_score, 1));
      Print("   Coherent: direction='" + g_coherentAnalysis.direction + "' score=" + DoubleToString(g_coherentAnalysis.coherence_score, 1));
   }
   
   CalculateFinalDecision();
   
   // Nettoyer les anciens labels (une fois sur 5)
   if(callCounter % 5 == 0)
   {
      CleanupDashboardLabels();
   }
   
   // Position des labels sur le graphique
   int startX = 20;
   int startY = 30;
   int lineHeight = 20;
   
   // 1. Recommandation IA avec confiance (utiliser les variables réellement mises à jour)
   string iaLabel = "AI_IA_Signal";
   ObjectCreate(0, iaLabel, OBJ_LABEL, 0, 0, 0);
   
   // Utiliser les variables qui sont réellement mises à jour
   string actualAction = (g_lastAIAction != "") ? g_lastAIAction : g_aiSignal.recommendation;
   double actualConfidence = (g_lastAIConfidence > 0) ? g_lastAIConfidence : g_aiSignal.confidence;
   
   string iaText = "🤖 IA: " + (actualAction != "" ? actualAction : "NO DATA") + 
                  " (" + DoubleToString(actualConfidence * 100, 1) + "%)";
   ObjectSetString(0, iaLabel, OBJPROP_TEXT, iaText);
   ObjectSetInteger(0, iaLabel, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, iaLabel, OBJPROP_YDISTANCE, startY);
   color iaClr = actualConfidence >= 0.7 ? (UseMutedColors ? MUTED_GREEN : clrGreen) : (actualConfidence >= 0.5 ? (UseMutedColors ? MUTED_YELLOW : clrYellow) : (UseMutedColors ? MUTED_RED : clrRed));
   ObjectSetInteger(0, iaLabel, OBJPROP_COLOR, iaClr);
   ObjectSetString(0, iaLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, iaLabel, OBJPROP_FONTSIZE, TEXT_FONT_SIZE);
   ObjectSetInteger(0, iaLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   // 2. Alignement des tendances (calculé localement)
   string trendLabel = "AI_Trend_Alignment";
   ObjectCreate(0, trendLabel, OBJ_LABEL, 0, 0, 0);
   string trendText = "📊 Tendances: M1=" + (g_trendAlignment.m1_trend != "" ? g_trendAlignment.m1_trend : "N/A") + 
                      " H1=" + (g_trendAlignment.h1_trend != "" ? g_trendAlignment.h1_trend : "N/A") + " | ";
   trendText += "Alignement: " + (g_trendAlignment.is_aligned ? "✅" : "❌") + 
                " (" + DoubleToString(g_trendAlignment.alignment_score, 1) + "%)";
   ObjectSetString(0, trendLabel, OBJPROP_TEXT, trendText);
   ObjectSetInteger(0, trendLabel, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, trendLabel, OBJPROP_YDISTANCE, startY + lineHeight);
   color trClr = g_trendAlignment.alignment_score >= 75 ? (UseMutedColors ? MUTED_GREEN : clrGreen) : (g_trendAlignment.alignment_score >= 50 ? (UseMutedColors ? MUTED_YELLOW : clrYellow) : (UseMutedColors ? MUTED_ORANGE : clrOrange));
   ObjectSetInteger(0, trendLabel, OBJPROP_COLOR, trClr);
   ObjectSetString(0, trendLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, trendLabel, OBJPROP_FONTSIZE, TEXT_FONT_SIZE);
   ObjectSetInteger(0, trendLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   // 3. Analyse cohérente (calculée localement)
   string coherentLabel = "AI_Coherent_Analysis";
   ObjectCreate(0, coherentLabel, OBJ_LABEL, 0, 0, 0);
   string coherentText = "🔍 Cohérence: " + (g_coherentAnalysis.direction != "" ? g_coherentAnalysis.direction : "N/A") + 
                        " (" + DoubleToString(g_coherentAnalysis.coherence_score, 1) + "%)";
   ObjectSetString(0, coherentLabel, OBJPROP_TEXT, coherentText);
   ObjectSetInteger(0, coherentLabel, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, coherentLabel, OBJPROP_YDISTANCE, startY + lineHeight * 2);
   color coClr = g_coherentAnalysis.coherence_score >= 70 ? (UseMutedColors ? MUTED_GREEN : clrGreen) : (g_coherentAnalysis.coherence_score >= 50 ? (UseMutedColors ? MUTED_YELLOW : clrYellow) : (UseMutedColors ? MUTED_RED : clrRed));
   ObjectSetInteger(0, coherentLabel, OBJPROP_COLOR, coClr);
   ObjectSetString(0, coherentLabel, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, coherentLabel, OBJPROP_FONTSIZE, TEXT_FONT_SIZE);
   ObjectSetInteger(0, coherentLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   // 4. Décision finale (afficher même si 0)
   string decisionLabel = "AI_Final_Decision";
   ObjectCreate(0, decisionLabel, OBJ_LABEL, 0, 0, 0);
   string decisionText = "⚡ DÉCISION: " + g_finalDecision.action + 
                        " (" + DoubleToString(g_finalDecision.final_confidence * 100, 1) + "%)";
   ObjectSetString(0, decisionLabel, OBJPROP_TEXT, decisionText);
   ObjectSetInteger(0, decisionLabel, OBJPROP_XDISTANCE, startX);
   ObjectSetInteger(0, decisionLabel, OBJPROP_YDISTANCE, startY + lineHeight * 3);
   color decClr = g_finalDecision.final_confidence >= 0.7 ? (UseMutedColors ? MUTED_GREEN : clrGreen) : (g_finalDecision.final_confidence >= 0.5 ? (UseMutedColors ? MUTED_YELLOW : clrYellow) : (UseMutedColors ? MUTED_RED : clrRed));
   ObjectSetInteger(0, decisionLabel, OBJPROP_COLOR, decClr);
   ObjectSetString(0, decisionLabel, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, decisionLabel, OBJPROP_FONTSIZE, TEXT_FONT_SIZE);
   ObjectSetInteger(0, decisionLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   // 5. Recommandations ML (si activé)
   if(UseMLIntegration && ShowMLRecommendations && g_mlRecommendation.is_valid)
   {
      string mlLabel = "AI_ML_Recommendation";
      ObjectCreate(0, mlLabel, OBJ_LABEL, 0, 0, 0);
      string mlText = "🤖 ML: " + g_mlRecommendation.recommendation + 
                     " (" + DoubleToString(g_mlRecommendation.confidence * 100, 1) + "%) " +
                     "Acc: " + DoubleToString(g_mlRecommendation.accuracy * 100, 1) + "%";
      ObjectSetString(0, mlLabel, OBJPROP_TEXT, mlText);
      ObjectSetInteger(0, mlLabel, OBJPROP_XDISTANCE, startX);
      ObjectSetInteger(0, mlLabel, OBJPROP_YDISTANCE, startY + lineHeight * 4);
      color mlClr = (g_mlRecommendation.recommendation == "BUY") ? (UseMutedColors ? MUTED_GREEN : clrGreen) : 
                    (g_mlRecommendation.recommendation == "SELL") ? (UseMutedColors ? MUTED_RED : clrRed) : 
                    (UseMutedColors ? MUTED_YELLOW : clrYellow);
      ObjectSetInteger(0, mlLabel, OBJPROP_COLOR, mlClr);
      ObjectSetString(0, mlLabel, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, mlLabel, OBJPROP_FONTSIZE, TEXT_FONT_SIZE_SM);
      ObjectSetInteger(0, mlLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      
      // Afficher les métriques ML si activé
      if(ShowMLMetricsOnChart && g_mlRecommendation.models_trained > 0)
      {
         string mlMetricsLabel = "AI_ML_Metrics";
         ObjectCreate(0, mlMetricsLabel, OBJ_LABEL, 0, 0, 0);
         string mlMetricsText = "📊 ML: " + IntegerToString(g_mlRecommendation.models_trained) + " modèles | F1: " + 
                               DoubleToString(g_mlRecommendation.f1_score * 100, 1) + "%";
         ObjectSetString(0, mlMetricsLabel, OBJPROP_TEXT, mlMetricsText);
         ObjectSetInteger(0, mlMetricsLabel, OBJPROP_XDISTANCE, startX);
         ObjectSetInteger(0, mlMetricsLabel, OBJPROP_YDISTANCE, startY + lineHeight * 5);
         ObjectSetInteger(0, mlMetricsLabel, OBJPROP_COLOR, UseMutedColors ? MUTED_CYAN : clrCyan);
         ObjectSetString(0, mlMetricsLabel, OBJPROP_FONT, "Arial");
         ObjectSetInteger(0, mlMetricsLabel, OBJPROP_FONTSIZE, TEXT_FONT_SIZE_SM);
         ObjectSetInteger(0, mlMetricsLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         
         // Afficher les swing points ML prédits
         if(ArraySize(g_swingPredictions) > 0)
         {
            string swingLabel = "AI_ML_Swings";
            ObjectCreate(0, swingLabel, OBJ_LABEL, 0, 0, 0);
            
            int swingHighs = 0, swingLows = 0;
            double avgConfidence = 0;
            for(int i = 0; i < ArraySize(g_swingPredictions); i++)
            {
               if(g_swingPredictions[i].is_high) swingHighs++;
               else swingLows++;
               avgConfidence += g_swingPredictions[i].confidence;
            }
            avgConfidence /= ArraySize(g_swingPredictions);
            
            string swingText = "🎯 Swing ML: " + IntegerToString(ArraySize(g_swingPredictions)) + " points | " +
                              "H:" + IntegerToString(swingHighs) + " L:" + IntegerToString(swingLows) + " | " +
                              "Conf: " + DoubleToString(avgConfidence * 100, 1) + "%";
            ObjectSetString(0, swingLabel, OBJPROP_TEXT, swingText);
            ObjectSetInteger(0, swingLabel, OBJPROP_XDISTANCE, startX);
            ObjectSetInteger(0, swingLabel, OBJPROP_YDISTANCE, startY + lineHeight * 6);
            ObjectSetInteger(0, swingLabel, OBJPROP_COLOR, UseMutedColors ? MUTED_PURPLE : clrPurple);
            ObjectSetString(0, swingLabel, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, swingLabel, OBJPROP_FONTSIZE, TEXT_FONT_SIZE_SM);
            ObjectSetInteger(0, swingLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         }
         
         // Afficher les trendlines ML prédites
         if(ArraySize(g_trendLinePredictions) > 0)
         {
            string trendLabel = "AI_ML_Trends";
            ObjectCreate(0, trendLabel, OBJ_LABEL, 0, 0, 0);
            
            int supports = 0, resistances = 0, trendlines = 0;
            double avgTrendConfidence = 0;
            for(int i = 0; i < ArraySize(g_trendLinePredictions); i++)
            {
               if(g_trendLinePredictions[i].type == "support") supports++;
               else if(g_trendLinePredictions[i].type == "resistance") resistances++;
               else trendlines++;
               avgTrendConfidence += g_trendLinePredictions[i].confidence;
            }
            avgTrendConfidence /= ArraySize(g_trendLinePredictions);
            
            string trendText = "📈 Trend ML: " + IntegerToString(ArraySize(g_trendLinePredictions)) + " lignes | " +
                             "S:" + IntegerToString(supports) + " R:" + IntegerToString(resistances) + " T:" + IntegerToString(trendlines) + " | " +
                             "Conf: " + DoubleToString(avgTrendConfidence * 100, 1) + "%";
            ObjectSetString(0, trendLabel, OBJPROP_TEXT, trendText);
            ObjectSetInteger(0, trendLabel, OBJPROP_XDISTANCE, startX);
            ObjectSetInteger(0, trendLabel, OBJPROP_YDISTANCE, startY + lineHeight * 7);
            ObjectSetInteger(0, trendLabel, OBJPROP_COLOR, UseMutedColors ? MUTED_ORANGE : clrOrange);
            ObjectSetString(0, trendLabel, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, trendLabel, OBJPROP_FONTSIZE, TEXT_FONT_SIZE_SM);
            ObjectSetInteger(0, trendLabel, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         }
      }
   }
   
   // DÉSACTIVÉ: Les EMA causent le détachement du robot
   // Tracer les EMA sur les 3 timeframes (une fois sur 10)
   // if(callCounter % 10 == 0)
   // {
   //    DrawEMAOnAllTimeframes();
   // }
   
   // Exécuter les ordres selon la logique demandée
   ExecuteOrderLogic();
   
   // Dessiner les outils d'analyse technique (Fibo, FVG, liquidité, OB) - toutes les 3 mises à jour dashboard
   // Dessins lourds moins souvent pour ne pas faire ramer MT5 (toutes les 5 mises à jour)
   if(callCounter % 5 == 0)
   {
      DrawEMACurves();
      DrawFibonacciRetracements();
      DrawLiquiditySquid();
      DrawFVG();
      DrawOrderBlocks();
   }
   
   callCounter++;
}

//+------------------------------------------------------------------+
//| FONCTIONS DE GESTION DES POSITIONS POUR STRATÉGIE AVANCÉE         |
//+------------------------------------------------------------------+

// Gérer la duplication des positions selon la stratégie (simplifié)
void ManagePositionDuplication()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i) && positionInfo.Magic() == InpMagicNumber)
      {
         double currentProfit = positionInfo.Profit();
         
         // Conditions pour duplication (réactivé)
         bool canDuplicate = (currentProfit >= 1.0 && 
                           !g_positionTracker.lotDoubled &&
                           g_lastAIConfidence >= 0.90 &&
                           g_finalDecision.final_confidence >= 0.80);
         
         // Vérifier si la direction correspond
         if(canDuplicate)
         {
            ENUM_POSITION_TYPE posType = positionInfo.PositionType();
            string predictionDirection = (g_lastAIAction != "") ? g_lastAIAction : g_aiSignal.recommendation;
            
            bool sameDirection = (posType == POSITION_TYPE_BUY && (predictionDirection == "BUY" || predictionDirection == "buy")) ||
                               (posType == POSITION_TYPE_SELL && (predictionDirection == "SELL" || predictionDirection == "sell"));
            
            if(sameDirection)
            {
               Print("🔄 Duplication position: profit=", DoubleToString(currentProfit, 2), "$");
               DuplicatePosition(positionInfo.Ticket());
            }
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
      
      // Valider et ajuster SL/TP pour éviter les "Invalid stops"
      ValidateAndAdjustStops(entryPrice, newStopLoss, newTakeProfit, ORDER_TYPE_BUY);
      
      if(trade.Buy(newLot, _Symbol, entryPrice, newStopLoss, newTakeProfit, "Duplication @ 1$ profit"))
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
      
      // Valider et ajuster SL/TP pour éviter les "Invalid stops"
      ValidateAndAdjustStops(entryPrice, newStopLoss, newTakeProfit, ORDER_TYPE_SELL);
      
      if(trade.Sell(newLot, _Symbol, entryPrice, newStopLoss, newTakeProfit, "Duplication @ 1$ profit"))
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
//| CALCULER LES TENDANCES LOCALEMENT AVEC LES EMA                     |
//+------------------------------------------------------------------+
void CalculateLocalTrends()
{
   // Récupérer les EMA pour M1 et H1
   double emaFastM1[], emaSlowM1[], emaFastH1[], emaSlowH1[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   
   // FORCER la mise à jour même si les handles sont invalides
   bool hasValidData = false;
   
   if(emaFastHandle != INVALID_HANDLE && emaSlowHandle != INVALID_HANDLE && 
      CopyBuffer(emaFastHandle, 0, 0, 1, emaFastM1) > 0 &&
      CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlowM1) > 0)
   {
      // Déterminer la tendance M1
      g_trendAlignment.m1_trend = (emaFastM1[0] > emaSlowM1[0]) ? "UP" : "DOWN";
      hasValidData = true;
   }
   else
   {
      // REPLI: Utiliser le mouvement de prix pour M1
      static double lastM1Price = 0.0;
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(lastM1Price > 0)
      {
         g_trendAlignment.m1_trend = (currentPrice > lastM1Price) ? "UP" : "DOWN";
         hasValidData = true;
      }
      lastM1Price = currentPrice;
   }
   
   if(emaFastH1Handle != INVALID_HANDLE && emaSlowH1Handle != INVALID_HANDLE &&
      CopyBuffer(emaFastH1Handle, 0, 0, 1, emaFastH1) > 0 &&
      CopyBuffer(emaSlowH1Handle, 0, 0, 1, emaSlowH1) > 0)
   {
      // Déterminer la tendance H1
      g_trendAlignment.h1_trend = (emaFastH1[0] > emaSlowH1[0]) ? "UP" : "DOWN";
      hasValidData = true;
   }
   else
   {
      // REPLI: Utiliser la tendance M1 pour H1 aussi
      g_trendAlignment.h1_trend = g_trendAlignment.m1_trend;
      hasValidData = true;
   }
   
   if(hasValidData)
   {
      // Calculer l'alignement
      string trend = g_trendAlignment.m1_trend;
      g_trendAlignment.is_aligned = (g_trendAlignment.h1_trend == trend);
      
      // Calculer le score d'alignement
      int alignedCount = 0;
      if(g_trendAlignment.m1_trend == trend) alignedCount++;
      if(g_trendAlignment.h1_trend == trend) alignedCount++;
      
      g_trendAlignment.alignment_score = (alignedCount / 2.0) * 100.0;
      
      Print("📈 Tendances locales: M1=", g_trendAlignment.m1_trend, " H1=", g_trendAlignment.h1_trend, 
            " Alignement=", g_trendAlignment.is_aligned, " Score=", g_trendAlignment.alignment_score);
   }
   else
   {
      Print("❌ Erreur récupération EMA pour tendances - utilisation valeurs par défaut");
      // Valeurs par défaut pour éviter le blocage
      g_trendAlignment.m1_trend = "UP";
      g_trendAlignment.h1_trend = "UP";
      g_trendAlignment.is_aligned = true;
      g_trendAlignment.alignment_score = 75.0;
   }
}

//+------------------------------------------------------------------+
//| CALCULER LA COHÉRENCE LOCALEMENT                                   |
//+------------------------------------------------------------------+
void CalculateLocalCoherence()
{
   // Utiliser les variables IA déjà disponibles
   string actualAction = (g_lastAIAction != "") ? g_lastAIAction : g_aiSignal.recommendation;
   double actualConfidence = (g_lastAIConfidence > 0) ? g_lastAIConfidence : g_aiSignal.confidence;
   
   if(actualAction != "" && actualConfidence > 0)
   {
      // Convertir l'action en direction
      if(actualAction == "buy" || actualAction == "BUY")
         g_coherentAnalysis.direction = "UP";
      else if(actualAction == "sell" || actualAction == "SELL")
         g_coherentAnalysis.direction = "DOWN";
      else
         g_coherentAnalysis.direction = actualAction;
      
      // Calculer la cohérence basée sur l'alignement des tendances
      if(g_trendAlignment.is_aligned)
      {
         // Si tendances alignées, haute cohérence
         g_coherentAnalysis.coherence_score = actualConfidence * 100;
      }
      else
      {
         // Si tendances non alignées, cohérence réduite
         g_coherentAnalysis.coherence_score = actualConfidence * 50;
      }
      
      g_coherentAnalysis.is_valid = (g_coherentAnalysis.coherence_score >= 50.0);
      
      Print("🔍 Cohérence locale: direction=", g_coherentAnalysis.direction, 
            " score=", g_coherentAnalysis.coherence_score, " valid=", g_coherentAnalysis.is_valid);
   }
   else
   {
      g_coherentAnalysis.direction = "NEUTRAL";
      g_coherentAnalysis.coherence_score = 0.0;
      g_coherentAnalysis.is_valid = false;
   }
}

//+------------------------------------------------------------------+
//| DESSINER LES EMA SUR LES 3 TIMEFRAMES                           |
//+------------------------------------------------------------------+
void DrawEMAOnAllTimeframes()
{
   // Dessiner les EMA M1 sur le graphique courant (seulement 2 lignes)
   DrawEMAOnTimeframe(PERIOD_M1, emaFastHandle, "EMA_Fast_M1", clrBlue, 2);
   DrawEMAOnTimeframe(PERIOD_M1, emaSlowHandle, "EMA_Slow_M1", clrRed, 2);
   
   // Dessiner les EMA M5 (une fois sur 2 pour économiser CPU)
   static int m5Counter = 0;
   if(m5Counter % 2 == 0)
   {
      DrawEMAOnTimeframe(PERIOD_M5, emaFastM5Handle, "EMA_Fast_M5", clrDodgerBlue, 2);
      DrawEMAOnTimeframe(PERIOD_M5, emaSlowM5Handle, "EMA_Slow_M5", clrOrange, 2);
   }
   
   // Dessiner les EMA H1 (une fois sur 3 pour économiser CPU)
   static int h1Counter = 0;
   if(h1Counter % 3 == 0)
   {
      DrawEMAOnTimeframe(PERIOD_H1, emaFastH1Handle, "EMA_Fast_H1", clrAqua, 3);
      DrawEMAOnTimeframe(PERIOD_H1, emaSlowH1Handle, "EMA_Slow_H1", clrMagenta, 3);
   }
   
   m5Counter++;
   h1Counter++;
}

//+------------------------------------------------------------------+
//| DESSINER LES EMA POUR UN TIMEFRAME SPÉCIFIQUE                    |
//+------------------------------------------------------------------+
void DrawEMAOnTimeframe(ENUM_TIMEFRAMES tf, int handle, string name, color clr, int width)
{
   if(handle == INVALID_HANDLE) return;
   
   double ema[];
   ArraySetAsSeries(ema, true);
   
   // Utiliser seulement 100 points au lieu de 500 pour économiser CPU
   if(CopyBuffer(handle, 0, 0, 100, ema) > 0)
   {
      string lineName = name + "_" + EnumToString(tf);
      
      // Supprimer l'ancienne ligne
      ObjectDelete(0, lineName);
      
      // Récupérer les temps et prix (réduit à 100 points)
      datetime times[];
      ArraySetAsSeries(times, true);
      
      if(CopyTime(_Symbol, tf, 0, 100, times) > 0)
      {
         // Créer la ligne de tendance avec les premiers et derniers points
         if(ObjectCreate(0, lineName, OBJ_TREND, 0, 0, 0))
         {
            // Point de départ (première donnée)
            ObjectSetInteger(0, lineName, OBJPROP_TIME, 0, times[ArraySize(times)-1]);
            ObjectSetDouble(0, lineName, OBJPROP_PRICE, 0, ema[ArraySize(ema)-1]);
            
            // Point d'arrivée (dernière donnée)
            ObjectSetInteger(0, lineName, OBJPROP_TIME, 1, times[0]);
            ObjectSetDouble(0, lineName, OBJPROP_PRICE, 1, ema[0]);
            
            ObjectSetInteger(0, lineName, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, lineName, OBJPROP_WIDTH, width);
            ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, lineName, OBJPROP_RAY_LEFT, false);
            ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
            ObjectSetString(0, lineName, OBJPROP_TEXT, name);
            ObjectSetInteger(0, lineName, OBJPROP_BACK, 0);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| LOGIQUE D'EXÉCUTION DES ORDRES                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| EXÉCUTER UN ORDRE AU MARCHÉ                                      |
//+------------------------------------------------------------------+
void ExecuteMarketOrder(string direction)
{
   // NOUVEAU: Une seule position par symbole (ordre limite ou marché)
   bool hasPositionOnCurrentSymbol = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Magic() == InpMagicNumber && positionInfo.Symbol() == _Symbol)
         {
            hasPositionOnCurrentSymbol = true;
            break;
         }
      }
   }
   
   // Si déjà une position sur ce symbole, ne pas trader
   if(hasPositionOnCurrentSymbol)
   {
      if(DebugMode)
         Print("🚫 POSITION EXISTANTE: déjà une position sur ", _Symbol, " - ordre market annulé");
      return;
   }
   
   // NOUVEAU: Limiter à 3 symboles maximum simultanément
   int activeSymbols = CountActiveSymbols();
   if(activeSymbols >= 3)
   {
      if(DebugMode)
         Print("🚫 LIMITE ATTEINTE: ", activeSymbols, "/3 symboles actifs - ordre market annulé sur ", _Symbol);
      return;
   }
   
   // VÉRIFICATION CRITIQUE: Interdire les SELL sur Boom
   if((direction == "sell" || direction == "SELL") && StringFind(_Symbol, "Boom", 0) != -1)
   {
      Print("🚫 BLOQUÉ: Ordre SELL refusé sur ", _Symbol, " (Boom = BUY uniquement)");
      return;
   }
   
   double emaFastM1[];
   ArraySetAsSeries(emaFastM1, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFastM1) > 0)
   {
      double entryPrice = emaFastM1[0]; // Utiliser l'EMA rapide M1 comme niveau d'entrée
      double lotSize = CalculateOptimalLotSize();
      
      double stopLoss, takeProfit;
      CalculateSLTP(direction, entryPrice, stopLoss, takeProfit);
      
      // Valider SL/TP avec le prix d'exécution réel (ASK pour buy, BID pour sell) pour éviter "Invalid stops"
      int orderType = (direction == "buy" || direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      double execPrice = (orderType == ORDER_TYPE_BUY) ? GetCachedAsk() : GetCachedBid();
      ValidateAndAdjustStops(execPrice, stopLoss, takeProfit, orderType);
      
      // Vérification supplémentaire pour SELL: SL > prix et TP < prix
      if(direction == "sell" || direction == "SELL")
      {
         double execBid = GetCachedBid();
         if(stopLoss <= execBid || takeProfit >= execBid || stopLoss <= takeProfit)
         {
            Print("⚠️ SL/TP invalides pour SELL Market Order - Recalcul...");
            double point = GetCachedPoint();
            double atr[];
            if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
            {
               double safeDistance = atr[0] * 3.0;
               stopLoss = execBid + safeDistance;
               takeProfit = execBid - (safeDistance * 2.0);
            }
            else
            {
               stopLoss = execBid + (2000 * point);
               takeProfit = execBid - (4000 * point);
            }
            ValidateAndAdjustStops(execBid, stopLoss, takeProfit, ORDER_TYPE_SELL);
            
            // Vérification finale
            if(stopLoss <= execBid || takeProfit >= execBid || stopLoss <= takeProfit)
            {
               Print("❌ ERREUR: SL/TP toujours invalides - SELL Market Order annulé");
               Print("   Prix: ", execBid, " SL: ", stopLoss, " TP: ", takeProfit);
               return;
            }
         }
      }
      
      bool success = false;
      if(direction == "buy" || direction == "BUY")
      {
         success = trade.Buy(lotSize, _Symbol, 0, stopLoss, takeProfit, "Market Order IA " + DoubleToString(g_lastAIConfidence * 100, 1) + "%");
      }
      else if(direction == "sell" || direction == "SELL")
      {
         success = trade.Sell(lotSize, _Symbol, 0, stopLoss, takeProfit, "Market Order IA " + DoubleToString(g_lastAIConfidence * 100, 1) + "%");
      }
      
      if(success)
      {
         Print("✅ Ordre au marché exécuté: ", direction, " @ ", DoubleToString(entryPrice, _Digits), 
               " Lot=", lotSize, " SL=", DoubleToString(stopLoss, _Digits), " TP=", DoubleToString(takeProfit, _Digits));
         
         // Enregistrer la direction exécutée pour le suivi des changements
         g_lastExecutedDirection = (direction == "buy" || direction == "BUY") ? "BUY" : "SELL";
      }
      else
      {
         Print("❌ Erreur ordre au marché: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else
   {
      Print("❌ Erreur récupération EMA rapide M1 pour ordre au marché");
   }
}

//+------------------------------------------------------------------+
//| EXÉCUTER UN ORDRE LIMITÉ                                          |
//+------------------------------------------------------------------+
void ExecuteLimitOrder(string direction)
{
   // NOUVEAU: Une seule position par symbole (ordre limite ou marché)
   bool hasPositionOnCurrentSymbol = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(positionInfo.SelectByIndex(i))
      {
         if(positionInfo.Magic() == InpMagicNumber && positionInfo.Symbol() == _Symbol)
         {
            hasPositionOnCurrentSymbol = true;
            break;
         }
      }
   }
   
   // Si déjà une position sur ce symbole, ne pas trader
   if(hasPositionOnCurrentSymbol)
   {
      if(DebugMode)
         Print("🚫 POSITION EXISTANTE: déjà une position sur ", _Symbol, " - ordre limite annulé");
      return;
   }
   
   // NOUVEAU: Limiter à 3 symboles maximum simultanément
   int activeSymbols = CountActiveSymbols();
   if(activeSymbols >= 3)
   {
      if(DebugMode)
         Print("🚫 LIMITE ATTEINTE: ", activeSymbols, "/3 symboles actifs - ordre limite annulé sur ", _Symbol);
      return;
   }
   
   // VÉRIFICATION CRITIQUE: Interdire les SELL sur Boom
   if((direction == "sell" || direction == "SELL") && StringFind(_Symbol, "Boom", 0) != -1)
   {
      Print("🚫 BLOQUÉ: Ordre SELL LIMIT refusé sur ", _Symbol, " (Boom = BUY uniquement)");
      return;
   }
   
   double lotSize = CalculateOptimalLotSize();
   
   // S'assurer que les niveaux d'entrée, SL et TP sont calculés
   CalculateOptimalEntryLevels();
   
   // Calculer les niveaux de support/résistance
   double support = 0, resistance = 0;
   CalculateSupportResistance(support, resistance);
   
   double entryPrice, stopLoss, takeProfit;
   
   if(direction == "buy" || direction == "BUY")
   {
      entryPrice = support; // Ordre BUY LIMIT sur le support
      stopLoss = entryPrice - (GetCachedAsk() - GetCachedBid()) * 2;
      takeProfit = entryPrice + (resistance - support) * 0.8;
   }
   else if(direction == "sell" || direction == "SELL")
   {
      entryPrice = resistance; // Ordre SELL LIMIT sur la résistance
      stopLoss = entryPrice + (GetCachedAsk() - GetCachedBid()) * 2;
      takeProfit = entryPrice - (resistance - support) * 0.8;
   }
   else
   {
      return;
   }
   
   bool success = false;
   if(direction == "buy" || direction == "BUY")
   {
      string comment1 = "Limit Order IA " + DoubleToString(g_lastAIConfidence * 100.0, 1) + "%";
      success = trade.BuyLimit(lotSize, entryPrice, _Symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, comment1);
   }
   else if(direction == "sell" || direction == "SELL")
   {
      string comment2 = "Limit Order IA " + DoubleToString(g_lastAIConfidence * 100.0, 1) + "%";
      success = trade.SellLimit(lotSize, entryPrice, _Symbol, stopLoss, takeProfit, ORDER_TIME_GTC, 0, comment2);
   }
   
   if(success)
   {
      Print("✅ Ordre limité placé: ", direction, " @ ", DoubleToString(entryPrice, _Digits), 
            " Lot=", lotSize, " SL=", DoubleToString(stopLoss, _Digits), " TP=", DoubleToString(takeProfit, _Digits));
   }
   else
   {
      Print("❌ Erreur ordre limité: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| CALCULER SUPPORTS ET RÉSISTANCES                                   |
//+------------------------------------------------------------------+
void CalculateSupportResistance(double &support, double &resistance)
{
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 50, high) > 0 && 
      CopyLow(_Symbol, PERIOD_H1, 0, 50, low) > 0)
   {
      double maxHigh = high[ArrayMaximum(high, 0, 50)];
      double minLow = low[ArrayMinimum(low, 0, 50)];
      
      double currentPrice = GetCachedBid();
      
      // Calculer support et résistance dynamiques
      resistance = maxHigh;
      support = minLow;
      
      // Ajuster selon le prix actuel
      if(currentPrice > (maxHigh + minLow) / 2)
      {
         resistance = maxHigh;
         support = (maxHigh + minLow) / 2;
      }
      else
      {
         resistance = (maxHigh + minLow) / 2;
         support = minLow;
      }
   }
   else
   {
      // Fallback: utiliser le prix actuel
      double currentPrice = GetCachedBid();
      double point = GetCachedPoint();
      support = currentPrice - (100 * point);
      resistance = currentPrice + (100 * point);
   }
}

//+------------------------------------------------------------------+
//| CALCULER SL ET TP                                                  |
//+------------------------------------------------------------------+
void CalculateSLTP(string direction, double entryPrice, double &stopLoss, double &takeProfit)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   
   // Adapter les distances selon le type de symbole
   double slMultiplier, tpMultiplier;
   
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      // Pour Boom/Crash: distances beaucoup plus grandes et fixes
      slMultiplier = 10.0;  // 10x ATR pour SL
      tpMultiplier = 15.0; // 15x ATR pour TP
   }
   else if(StringFind(_Symbol, "Volatility") >= 0)
   {
      // Pour Volatility: distances moyennes
      slMultiplier = 3.0;  // 3x ATR pour SL
      tpMultiplier = 5.0;  // 5x ATR pour TP
   }
   else
   {
      // Pour autres symboles: distances plus larges pour éviter les sorties prématurées
      slMultiplier = 4.0;  // 4x ATR pour SL (augmenté de 2x)
      tpMultiplier = 8.0;  // 8x ATR pour TP (augmenté de ~2.7x)
   }
   
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
   {
      double atrValue = atr[0];
      
      if(direction == "buy" || direction == "BUY")
      {
         stopLoss = entryPrice - (atrValue * slMultiplier);
         takeProfit = entryPrice + (atrValue * tpMultiplier);
      }
      else if(direction == "sell" || direction == "SELL")
      {
         stopLoss = entryPrice + (atrValue * slMultiplier);
         takeProfit = entryPrice - (atrValue * tpMultiplier);
      }
   }
   else
   {
      // Fallback: utiliser des points fixes selon le symbole
      double point = GetCachedPoint();
      double slPoints, tpPoints;
      
      if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
      {
         slPoints = 500;  // 500 points pour Boom/Crash (beaucoup plus)
         tpPoints = 1000; // 1000 points pour Boom/Crash
      }
      else if(StringFind(_Symbol, "Volatility") >= 0)
      {
         slPoints = 100;  // 100 points pour Volatility
         tpPoints = 200;  // 200 points pour Volatility
      }
      else
      {
         slPoints = 150;   // 150 points pour autres (augmenté de 3x)
         tpPoints = 300;  // 300 points pour autres (augmenté de 3x)
      }
      
      if(direction == "buy" || direction == "BUY")
      {
         stopLoss = entryPrice - (slPoints * point);
         takeProfit = entryPrice + (tpPoints * point);
      }
      else if(direction == "sell" || direction == "SELL")
      {
         stopLoss = entryPrice + (slPoints * point);
         takeProfit = entryPrice - (tpPoints * point);
      }
   }
   
   // Valider et normaliser les SL/TP avec distances minimales
   double minStopLevel = GetCachedPoint() * 50; // Minimum 50 points
   
   // S'assurer que SL/TP sont valides et éloignés
   if(direction == "buy" || direction == "BUY")
   {
      if(stopLoss >= entryPrice) stopLoss = entryPrice - minStopLevel;
      if(takeProfit <= entryPrice) takeProfit = entryPrice + (minStopLevel * 2);
   }
   else if(direction == "sell" || direction == "SELL")
   {
      if(stopLoss <= entryPrice) stopLoss = entryPrice + minStopLevel;
      if(takeProfit >= entryPrice) takeProfit = entryPrice - (minStopLevel * 2);
   }
}

//+------------------------------------------------------------------+
//| DÉTECTION DE SPIKES AMÉLIORÉE POUR BOOM/CRASH               |
//+------------------------------------------------------------------+

// Détecter les spikes extrêmes basés sur la volatilité
bool DetectExtremeSpike()
{
   if(StringFind(_Symbol, "Boom", 0) < 0 && StringFind(_Symbol, "Crash", 0) < 0)
      return false; // Seulement pour Boom/Crash
   
   double atr[];
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(atrHandle, 0, 0, 20, atr) < 20)
      return false;
   
   // Calculer la moyenne ATR récente
   double avgATR = 0;
   for(int i = 0; i < 20; i++)
   {
      avgATR += atr[i];
   }
   avgATR /= 20;
   
   // Détecter si l'ATR actuel est extrêment élevé
   double currentATR = atr[0];
   double spikeThreshold = avgATR * 3.0; // 3x la moyenne normale
   
   bool isSpike = (currentATR > spikeThreshold);
   
   if(isSpike && DebugMode)
   {
      Print("🚨 SPIKE EXTRÊME DÉTECTÉ: ATR actuel=", DoubleToString(currentATR, _Digits), 
            " (moyenne=", DoubleToString(avgATR, _Digits), 
            " seuil=", DoubleToString(spikeThreshold, _Digits), ")");
   }
   
   return isSpike;
}

// Analyser le momentum soudain
bool AnalyzeSuddenMomentum()
{
   if(StringFind(_Symbol, "Boom", 0) < 0 && StringFind(_Symbol, "Crash", 0) < 0)
      return false;
   
   double close[];
   ArraySetAsSeries(close, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 10, close) < 10)
      return false;
   
   // Calculer les variations de prix sur 3 périodes
   double change1 = (close[0] - close[1]) / close[1] * 100;
   double change2 = (close[1] - close[2]) / close[2] * 100;
   double change3 = (close[2] - close[3]) / close[3] * 100;
   
   double avgChange = (MathAbs(change1) + MathAbs(change2) + MathAbs(change3)) / 3;
   
   // Détecter un momentum soudain (>5% de variation moyenne)
   bool suddenMomentum = (avgChange > 5.0);
   
   if(suddenMomentum && DebugMode)
   {
      Print("⚡ MOMENTUM SOUDAIN: Variation moyenne=", DoubleToString(avgChange, 2), 
            "% | Changements: ", DoubleToString(change1, 2), "%, ", 
            DoubleToString(change2, 2), "%, ", DoubleToString(change3, 2), "%");
   }
   
   return suddenMomentum;
}

//+------------------------------------------------------------------+
//| VÉRIFIER LA COULEUR DES DÉRIVÉS (indicateur de momentum)          |
//+------------------------------------------------------------------+
bool CheckDerivativesColor()
{
   // Vérifier si les dérivés (autres indices) sont verts
   // C'est un indicateur de momentum haussier sur le marché
   
   // Pour Boom: vérifier Crash (ils sont souvent corrélés inversement)
   string crashSymbol = "Crash 1000 Index";
   
   // Obtenir le prix actuel du Crash
   double crashPrice = SymbolInfoDouble(crashSymbol, SYMBOL_BID);
   if(crashPrice <= 0)
   {
      // Si pas de données Crash, utiliser une logique alternative
      // Vérifier si le marché est globalement haussier
      double rsi[1];
      if(rsiHandle != INVALID_HANDLE && CopyBuffer(rsiHandle, 0, 0, 1, rsi) > 0)
      {
         // Si RSI > 50, considérer que les dérivés sont "verts"
         return (rsi[0] > 50);
      }
      return false; // Par défaut, pas de momentum haussier
   }
   
   // Logique simple: si Crash baisse (ou monte lentement), Boom monte (dérivés "verts")
   // On peut aussi vérifier d'autres indices pour confirmation
   double rsiCrash[1];
   if(rsiHandle != INVALID_HANDLE && CopyBuffer(rsiHandle, 0, 0, 1, rsiCrash) > 0)
   {
      // Si RSI du Crash < 50, considérer que les dérivés sont "verts" pour Boom
      return (rsiCrash[0] < 50);
   }
   
   return false; // Par défaut, pas de momentum haussier
}

// Vérifier les patterns pré-spike
bool CheckPreSpikePatterns()
{
   if(StringFind(_Symbol, "Boom", 0) < 0 && StringFind(_Symbol, "Crash", 0) < 0)
      return false;
   
   double rsi[];
   ArraySetAsSeries(rsi, true);
   
   if(CopyBuffer(rsiHandle, 0, 0, 5, rsi) < 5)
      return false;
   
   // Pattern pré-spike: RSI en zone de survente/surachat puis soudain changement
   bool rsiOversold = (rsi[1] < 30); // Période précédente en survente
   bool rsiOverbought = (rsi[1] > 70); // Période précédente en surachat
   bool rsiBreakout = (rsi[0] > 50); // RSI actuel sort de la zone extrême
   
   bool preSpikePattern = (rsiOversold || rsiOverbought) && rsiBreakout;
   
   if(preSpikePattern && DebugMode)
   {
      Print("🎯 PATTERN PRÉ-SPIKE: RSI précédent=", DoubleToString(rsi[1], 1), 
            " | RSI actuel=", DoubleToString(rsi[0], 1), 
            " | Pattern=", preSpikePattern ? "DÉTECTÉ" : "NON");
   }
   
   return preSpikePattern;
}

// Calculer prédiction améliorée pour spikes
void CalculateSpikePrediction()
{
   if(StringFind(_Symbol, "Boom", 0) < 0 && StringFind(_Symbol, "Crash", 0) < 0)
      return;
   
   bool hasSpike = DetectExtremeSpike();
   bool hasMomentum = AnalyzeSuddenMomentum();
   bool hasPattern = CheckPreSpikePatterns();
   
   // Logique de prédiction pour spikes
   if(hasSpike || hasMomentum || hasPattern)
   {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double atr[];
      ArraySetAsSeries(atr, true);
      CopyBuffer(atrHandle, 0, 0, 1, atr);
      
      // Déterminer la direction basée sur le type de spike
      string spikeDirection = "NEUTRAL";
      double spikeConfidence = 0.0;
      
      if(StringFind(_Symbol, "Boom") >= 0)
      {
         // Pour Boom: SEULEMENT des spikes haussiers (BUY)
         spikeDirection = "buy";
         spikeConfidence = 0.85; // Haute confiance pour spikes Boom
      }
      else if(StringFind(_Symbol, "Crash") >= 0)
      {
         // Pour Crash: SEULEMENT des spikes baissiers (SELL)
         spikeDirection = "sell";
         spikeConfidence = 0.85; // Haute confiance pour spikes Crash
      }
      
      // Ajuster la confiance selon les confirmations
      int confirmations = 0;
      if(hasSpike) confirmations++;
      if(hasMomentum) confirmations++;
      if(hasPattern) confirmations++;
      
      spikeConfidence *= (confirmations / 3.0); // Ajuster selon nombre de confirmations
      
      // Mettre à jour les variables IA avec les données de spike
      if(spikeConfidence > 0.7) // Seulement si confiance élevée
      {
         g_lastAIAction = spikeDirection;
         g_lastAIConfidence = spikeConfidence;
         
         if(DebugMode)
         {
            Print("🚀 PRÉDICTION SPIKE AMÉLIORÉE:");
            Print("   Symbole: ", _Symbol);
            Print("   Direction: ", spikeDirection, " (RÈGLE: BUY sur Boom, SELL sur Crash)");
            Print("   Confiance: ", DoubleToString(spikeConfidence * 100, 1), "%");
            Print("   Confirmations: ", confirmations, "/3");
            Print("   Prix actuel: ", DoubleToString(currentPrice, _Digits));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| EXÉCUTION AUTOMATIQUE D'ORDRE LIMITE AU SUPPORT/RÉSISTANCE M1    |
//+------------------------------------------------------------------+
void ExecuteAutoLimitOrder()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lotSize = CalculateOptimalLotSize();
   
   // UTILISER LES ZONES IA DIRECTEMENT au lieu des supports/résistances M1
   double buyZoneLow = g_aiBuyZoneLow;
   double buyZoneHigh = g_aiBuyZoneHigh;
   double sellZoneLow = g_aiSellZoneLow;
   double sellZoneHigh = g_aiSellZoneHigh;
   
   // DÉTERMINER LA DIRECTION À UTILISER
   string directionToUse = g_finalDecision.action;
   
   // Si on est en mode WAITING/HOLD, utiliser la direction de la flèche DERIV
   if(g_finalDecision.action == "WAIT" || g_finalDecision.action == "HOLD")
   {
      directionToUse = g_lastAIAction; // Utilise la direction de la flèche DERIV
      Print("🔄 Mode WAITING - Utilisation direction flèche DERIV: ", directionToUse);
   }
   
   // Fallback: si zones IA vides, utiliser Support/Résistance M1 avec offsets réduits
   if((directionToUse == "BUY" || directionToUse == "buy") && (buyZoneLow <= 0 || buyZoneHigh <= 0))
   {
      double support, resistance;
      CalculateM1SupportResistance(support, resistance);
      if(support > 0)
      {
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double distanceToSupport = currentBid - support;
         
         // Si le support est proche (< 15 pips), placer ordre juste en dessous du prix actuel
         if(distanceToSupport < 15 * point)
         {
            buyZoneLow = currentBid - (10 * point);
            buyZoneHigh = currentBid - (5 * point);
            Print("⚠️ Support proche - Ordre BUY près du prix: ", DoubleToString(buyZoneLow, 5), "-", DoubleToString(buyZoneHigh, 5));
         }
         // Si le support est à distance raisonnable (15-40 pips), l'utiliser
         else if(distanceToSupport <= 40 * point)
         {
            buyZoneLow = support + (2 * point);
            buyZoneHigh = support + (8 * point);
            Print("⚠️ Support raisonnable - Utilisation Support M1: ", DoubleToString(buyZoneLow, 5), "-", DoubleToString(buyZoneHigh, 5));
         }
         // Si le support est trop loin (> 40 pips), ignorer et placer près du prix
         else
         {
            buyZoneLow = currentBid - (15 * point);
            buyZoneHigh = currentBid - (8 * point);
            Print("⚠️ Support trop loin - Ordre BUY près du prix: ", DoubleToString(buyZoneLow, 5), "-", DoubleToString(buyZoneHigh, 5));
         }
      }
      else
      {
         Print("❌ Zone BUY non disponible (ni IA ni Support M1)");
         return;
      }
   }
   
   if((directionToUse == "SELL" || directionToUse == "sell") && (sellZoneLow <= 0 || sellZoneHigh <= 0))
   {
      double support, resistance;
      CalculateM1SupportResistance(support, resistance);
      if(resistance > 0)
      {
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double distanceToResistance = resistance - currentAsk;
         
         // Si la résistance est proche (< 15 pips), placer ordre juste au-dessus du prix actuel
         if(distanceToResistance < 15 * point)
         {
            sellZoneLow = currentAsk + (5 * point);
            sellZoneHigh = currentAsk + (10 * point);
            Print("⚠️ Résistance proche - Ordre SELL près du prix: ", DoubleToString(sellZoneLow, 5), "-", DoubleToString(sellZoneHigh, 5));
         }
         // Si la résistance est à distance raisonnable (15-40 pips), l'utiliser
         else if(distanceToResistance <= 40 * point)
         {
            sellZoneLow = resistance - (8 * point);
            sellZoneHigh = resistance - (2 * point);
            Print("⚠️ Résistance raisonnable - Utilisation Résistance M1: ", DoubleToString(sellZoneLow, 5), "-", DoubleToString(sellZoneHigh, 5));
         }
         // Si la résistance est trop loin (> 40 pips), ignorer et placer près du prix
         else
         {
            sellZoneLow = currentAsk + (8 * point);
            sellZoneHigh = currentAsk + (15 * point);
            Print("⚠️ Résistance trop loin - Ordre SELL près du prix: ", DoubleToString(sellZoneLow, 5), "-", DoubleToString(sellZoneHigh, 5));
         }
      }
      else
      {
         Print("❌ Zone SELL non disponible (ni IA ni Résistance M1)");
         return;
      }
   }
   
   // VÉRIFICATION CRITIQUE: Interdire les SELL sur Boom
   if(StringFind(_Symbol, "Boom", 0) != -1)
   {
      if(directionToUse == "SELL" || directionToUse == "sell")
      {
         Print("🚫 BLOQUÉ: Ordre SELL LIMIT refusé sur ", _Symbol, " (Boom = BUY uniquement)");
         return;
      }
   }
   
   if(directionToUse == "BUY")
   {
      // Placer ordre LIMIT BUY dans la zone BUY IA
      if(buyZoneLow > 0 && buyZoneHigh > 0)
      {
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double distanceToZone = currentBid - buyZoneLow;
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         
         // Vérifier si la zone IA est raisonnablement proche du prix actuel
         if(distanceToZone > 50 * point)
         {
            Print("⚠️ Zone BUY IA trop loin (", DoubleToString(distanceToZone/point, 0), " pips) - Utilisation logique adaptée");
            
            // Utiliser la logique de proximité comme fallback
            double support, resistance;
            CalculateM1SupportResistance(support, resistance);
            if(support > 0)
            {
               double distanceToSupport = currentBid - support;
               
               // Si le support est proche (< 15 pips), placer ordre juste en dessous du prix actuel
               if(distanceToSupport < 15 * point)
               {
                  buyZoneLow = currentBid - (10 * point);
                  buyZoneHigh = currentBid - (5 * point);
                  Print("📍 Support proche - Ordre BUY près du prix: ", DoubleToString(buyZoneLow, 5), "-", DoubleToString(buyZoneHigh, 5));
               }
               // Si le support est à distance raisonnable (15-40 pips), l'utiliser
               else if(distanceToSupport <= 40 * point)
               {
                  buyZoneLow = support + (2 * point);
                  buyZoneHigh = support + (8 * point);
                  Print("📍 Support raisonnable - Utilisation Support M1: ", DoubleToString(buyZoneLow, 5), "-", DoubleToString(buyZoneHigh, 5));
               }
               // Sinon placer près du prix
               else
               {
                  buyZoneLow = currentBid - (15 * point);
                  buyZoneHigh = currentBid - (8 * point);
                  Print("📍 Support loin - Ordre BUY près du prix: ", DoubleToString(buyZoneLow, 5), "-", DoubleToString(buyZoneHigh, 5));
               }
            }
            else
            {
               // Dernier recours: placer ordre à 15 pips sous le prix
               buyZoneLow = currentBid - (15 * point);
               buyZoneHigh = currentBid - (8 * point);
               Print("📍 Pas de support - Ordre BUY près du prix: ", DoubleToString(buyZoneLow, 5), "-", DoubleToString(buyZoneHigh, 5));
            }
         }
         
         // Placer au milieu de la zone BUY IA pour plus de chances d'exécution
         double limitPrice = (buyZoneLow + buyZoneHigh) / 2.0;
         
         Print("🎯 Ordre LIMIT BUY sur zone: ", DoubleToString(limitPrice, 5), " (Zone: ", DoubleToString(buyZoneLow, 5), "-", DoubleToString(buyZoneHigh, 5), ")");
      
      // Calculer SL/TP basés sur la perte admise (5$) - laisser le prix bouger normalement
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(minStopLevel == 0)
      {
         minStopLevel = 30 * point; // Valeur par défaut si échec
         Print("⚠️ Impossible d'obtenir SYMBOL_TRADE_STOPS_LEVEL, utilisation valeur par défaut");
      }
      
      // Calculer distance SL pour perte de StopLossUSD (5$)
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double pointsPerDollar = (tickSize > 0 && tickValue > 0) ? (tickValue / tickSize) : 0;
      
      double slDistancePoints = 0;
      if(pointsPerDollar > 0 && lotSize > 0)
      {
         slDistancePoints = (StopLossUSD / (lotSize * pointsPerDollar)) * point;
      }
      else
      {
         // Fallback: utiliser ATR x 2
         double atr[];
         // Utiliser la variable globale atrHandle
         if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
            slDistancePoints = atr[0] * 2.0;
         else
            slDistancePoints = 200 * point; // Fallback conservateur
      }
      
      // Minimum: respecter les exigences du broker
      slDistancePoints = MathMax(slDistancePoints, minStopLevel);
      
      // Augmenter la distance SL (multiplier par 1.5 pour plus de marge)
      slDistancePoints = slDistancePoints * 1.5;
      
      double stopLoss = limitPrice - slDistancePoints;
      double takeProfit = limitPrice + (slDistancePoints * 2.0); // Ratio 1:2
      
      // Validation finale pour s'assurer que les distances sont valides
      double slDistance = MathAbs(limitPrice - stopLoss);
      double tpDistance = MathAbs(takeProfit - limitPrice);
      
      if(slDistance < minStopLevel)
      {
         stopLoss = limitPrice - minStopLevel;
         Print("🛡️ SL ajusté pour respecter la distance minimale du courtier");
      }
      
      if(tpDistance < minStopLevel)
      {
         takeProfit = limitPrice + minStopLevel;
         Print("🎯 TP ajusté pour respecter la distance minimale du courtier");
      }
      
      // Tenter de placer l'ordre limite avec gestion des erreurs de connexion
      string commentAutoBuy = "AUTO LIMIT BUY - IA>70% - Support M1 - " + (string)g_finalDecision.reasoning;
      bool orderSuccess = false;
      int retryCount = 0;
      int maxRetries = 3;
      
      // Valider le prix limite avant de placer l'ordre
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double minPrice = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxPrice = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      
      // Pour BUY Limit: le prix doit être en-dessous du prix actuel
      if(limitPrice >= currentAsk)
      {
         limitPrice = currentBid - (10 * point); // 10 points en-dessous du BID
         Print("⚠️ Prix limite ajusté pour BUY: ", DoubleToString(limitPrice, _Digits));
      }
      
      // Valider les stops AVANT de placer l'ordre
      ValidateAndAdjustStops(limitPrice, stopLoss, takeProfit, ORDER_TYPE_BUY);
      
      while(!orderSuccess && retryCount < maxRetries)
      {
         ResetLastError();
         orderSuccess = trade.BuyLimit(lotSize, limitPrice, _Symbol, stopLoss, takeProfit, 
                                    ORDER_TIME_GTC, 0, commentAutoBuy);
         
         if(orderSuccess)
         {
            Print("🎯 ORDRE LIMIT BUY AUTOMATIQUE PLACÉ:");
            Print("   📍 Prix limite: ", DoubleToString(limitPrice, _Digits));
            Print("   📊 Zone BUY IA: ", DoubleToString(buyZoneLow, _Digits), "-", DoubleToString(buyZoneHigh, _Digits));
            Print("   💰 Prix actuel: ", DoubleToString(currentPrice, _Digits));
            Print("   🧠 Confiance IA: ", DoubleToString(g_lastAIConfidence * 100, 1), "%");
            Print("   🎯 Confiance finale: ", DoubleToString(g_finalDecision.final_confidence * 100, 1), "%");
            Print("   🛡️ SL: ", DoubleToString(stopLoss, _Digits));
            Print("   🎯 TP: ", DoubleToString(takeProfit, _Digits));
            Print("   📝 Raison: ", g_finalDecision.reasoning);
            Print("   🔄 Tentative: ", retryCount + 1, "/", maxRetries);
            break;
         }
         else
         {
            retryCount++;
            uint error = trade.ResultRetcode();
            string errorMsg = trade.ResultRetcodeDescription();
            
            Print("❌ ÉCHEC ORDRE LIMIT BUY (Tentative ", retryCount, "/", maxRetries, "):");
            Print("   Code erreur: ", error, " - ", errorMsg);
            Print("   Dernière erreur système: ", GetLastError());
            
            // Si c'est une erreur de réseau, attendre avant de réessayer
            if(error == TRADE_RETCODE_NO_CONNECTION || 
               error == TRADE_RETCODE_SERVER_BUSY ||
               error == TRADE_RETCODE_TIMEOUT ||
               error == TRADE_RETCODE_INVALID_STOPS ||
               StringFind(errorMsg, "network") >= 0 ||
               StringFind(errorMsg, "connection") >= 0)
            {
               Print("🌐 Erreur de connexion détectée - Attente de ", (retryCount * 2), " secondes avant retry...");
               Sleep(retryCount * 2000); // Attendre 2s, 4s, 6s
            }
            else
            {
               // Pour les autres erreurs, ne pas réessayer
               Print("⚠️ Erreur non liée à la connexion - Abandon de l'ordre");
               break;
            }
         }
      }
      
      if(!orderSuccess)
      {
         Print("🚨 ORDRE LIMIT BUY ABANDONNÉ après ", maxRetries, " tentatives");
         double execAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         ValidateAndAdjustStops(execAsk, stopLoss, takeProfit, ORDER_TYPE_BUY);
         if(trade.Buy(lotSize, _Symbol, 0, stopLoss, takeProfit, "AUTO MARKET BUY - FALLBACK"))
            Print("🔄 Ordre MARKET BUY exécuté en remplacement (fallback)");
         // Placer au milieu de la zone SELL IA pour plus de chances d'exécution
         double limitPrice = (sellZoneLow + sellZoneHigh) / 2.0;
         
         Print("🎯 Ordre LIMIT SELL sur zone: ", DoubleToString(limitPrice, 5), " (Zone: ", DoubleToString(sellZoneLow, 5), "-", DoubleToString(sellZoneHigh, 5), ")");
      
      // Calculer SL/TP basés sur la perte admise (5$) - laisser le prix bouger normalement
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double minStopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
      if(minStopLevel == 0)
      {
         minStopLevel = 30 * point; // Valeur par défaut si échec
         Print("⚠️ Impossible d'obtenir SYMBOL_TRADE_STOPS_LEVEL, utilisation valeur par défaut");
      }
      
      // Calculer distance SL pour perte de StopLossUSD (5$)
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double pointsPerDollar = (tickSize > 0 && tickValue > 0) ? (tickValue / tickSize) : 0;
      
      double slDistancePoints = 0;
      if(pointsPerDollar > 0 && lotSize > 0)
      {
         slDistancePoints = (StopLossUSD / (lotSize * pointsPerDollar)) * point;
      }
      else
      {
         // Fallback: utiliser ATR x 2
         double atr[];
         // Utiliser la variable globale atrHandle
         if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
            slDistancePoints = atr[0] * 2.0;
         else
            slDistancePoints = 200 * point; // Fallback conservateur
      }
      
      // Minimum: respecter les exigences du broker
      slDistancePoints = MathMax(slDistancePoints, minStopLevel);
      
      // Augmenter la distance SL (multiplier par 1.5 pour plus de marge)
      slDistancePoints = slDistancePoints * 1.5;
      
      double stopLoss = limitPrice + slDistancePoints;
      double takeProfit = limitPrice - (slDistancePoints * 2.0); // Ratio 1:2
      
      // Validation finale pour s'assurer que les distances sont valides
      double slDistance = MathAbs(stopLoss - limitPrice);
      double tpDistance = MathAbs(limitPrice - takeProfit);
      
      if(slDistance < minStopLevel)
      {
         stopLoss = limitPrice + minStopLevel;
         Print("🛡️ SL ajusté pour respecter la distance minimale du courtier");
      }
      
      if(tpDistance < minStopLevel)
      {
         takeProfit = limitPrice - minStopLevel;
         Print("🎯 TP ajusté pour respecter la distance minimale du courtier");
      }
      
      // Tenter de placer l'ordre limite avec gestion des erreurs de connexion
      string commentAutoSell = "AUTO LIMIT SELL - IA>70% - Résistance M1 - " + (string)g_finalDecision.reasoning;
      bool orderSuccess = false;
      int retryCount = 0;
      int maxRetries = 3;
      
      // Valider le prix limite avant de placer l'ordre
      double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      // Pour SELL Limit: le prix doit être au-dessus du prix actuel
      if(limitPrice <= currentBid)
      {
         limitPrice = currentAsk + (10 * point); // 10 points au-dessus de l'ASK
         Print("⚠️ Prix limite ajusté pour SELL: ", DoubleToString(limitPrice, _Digits));
      }
      
      // Valider les stops AVANT de placer l'ordre
      ValidateAndAdjustStops(limitPrice, stopLoss, takeProfit, ORDER_TYPE_SELL);
      
      while(!orderSuccess && retryCount < maxRetries)
      {
         ResetLastError();
         orderSuccess = trade.SellLimit(lotSize, limitPrice, _Symbol, stopLoss, takeProfit, 
                                     ORDER_TIME_GTC, 0, commentAutoSell);
         
         if(orderSuccess)
         {
            Print("🎯 ORDRE LIMIT SELL AUTOMATIQUE PLACÉ:");
            Print("   📍 Prix limite: ", DoubleToString(limitPrice, _Digits));
            Print("   📊 Zone SELL IA: ", DoubleToString(sellZoneLow, _Digits), "-", DoubleToString(sellZoneHigh, _Digits));
            Print("   💰 Prix actuel: ", DoubleToString(currentPrice, _Digits));
            Print("   🧠 Confiance IA: ", DoubleToString(g_lastAIConfidence * 100, 1), "%");
            Print("   🎯 Confiance finale: ", DoubleToString(g_finalDecision.final_confidence * 100, 1), "%");
            Print("   🛡️ SL: ", DoubleToString(stopLoss, _Digits));
            Print("   🎯 TP: ", DoubleToString(takeProfit, _Digits));
            Print("   📝 Raison: ", g_finalDecision.reasoning);
            Print("   🔄 Tentative: ", retryCount + 1, "/", maxRetries);
            break;
         }
         else
         {
            retryCount++;
            uint error = trade.ResultRetcode();
            string errorMsg = trade.ResultRetcodeDescription();
            
            Print("❌ ÉCHEC ORDRE LIMIT SELL (Tentative ", retryCount, "/", maxRetries, "):");
            Print("   Code erreur: ", error, " - ", errorMsg);
            Print("   Dernière erreur système: ", GetLastError());
            
            // Si c'est une erreur de réseau, attendre avant de réessayer
            if(error == TRADE_RETCODE_NO_CONNECTION || 
               error == TRADE_RETCODE_SERVER_BUSY ||
               error == TRADE_RETCODE_TIMEOUT ||
               error == TRADE_RETCODE_INVALID_STOPS ||
               StringFind(errorMsg, "network") >= 0 ||
               StringFind(errorMsg, "connection") >= 0)
            {
               Print("🌐 Erreur de connexion détectée - Attente de ", (retryCount * 2), " secondes avant retry...");
               Sleep(retryCount * 2000); // Attendre 2s, 4s, 6s
            }
            else
            {
               // Pour les autres erreurs, ne pas réessayer
               Print("⚠️ Erreur non liée à la connexion - Abandon de l'ordre");
               break;
            }
         }
      }
      
      if(!orderSuccess)
      {
         Print("🚨 ORDRE LIMIT SELL ABANDONNÉ après ", maxRetries, " tentatives");
         double execBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         // Vérification critique avant validation
         if(stopLoss <= execBid || takeProfit >= execBid)
         {
            Print("⚠️ SL/TP invalides pour SELL Fallback - Recalcul...");
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double atr[];
            // Utiliser la variable globale atrHandle
            if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
            {
               double safeDistance = atr[0] * 3.0;
               stopLoss = execBid + safeDistance;
               takeProfit = execBid - (safeDistance * 2.0);
            }
            else
            {
               stopLoss = execBid + (2000 * point);
               takeProfit = execBid - (4000 * point);
            }
         }
         
         ValidateAndAdjustStops(execBid, stopLoss, takeProfit, ORDER_TYPE_SELL);
         
         // Vérification finale
         if(stopLoss <= execBid || takeProfit >= execBid || stopLoss <= takeProfit)
         {
            Print("❌ ERREUR: SL/TP toujours invalides - SELL Fallback annulé");
            Print("   Prix: ", execBid, " SL: ", stopLoss, " TP: ", takeProfit);
            return;
         }
         
         if(trade.Sell(lotSize, _Symbol, 0, stopLoss, takeProfit, "AUTO MARKET SELL - FALLBACK"))
            Print("🔄 Ordre MARKET SELL exécuté en remplacement (fallback)");
         else
            Print("❌ ÉCHEC TOTAL: Impossible de placer l'ordre MARKET SELL en fallback");
      }
      }
   }
}

//+------------------------------------------------------------------+
//| CALCULER SUPPORT/RÉSISTANCE M1 LE PLUS PROCHE                    |
//+------------------------------------------------------------------+
void CalculateM1SupportResistance(double &support, double &resistance)
{
   support = 0.0;
   resistance = 0.0;
   
   // Obtenir les données M1
   int barsToCheck = 50; // Analyser les 50 dernières bougies M1
   double low[], high[], close[];
   
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(close, true);
   
   if(CopyLow(_Symbol, PERIOD_M1, 0, barsToCheck, low) <= 0 ||
      CopyHigh(_Symbol, PERIOD_M1, 0, barsToCheck, high) <= 0 ||
      CopyClose(_Symbol, PERIOD_M1, 0, barsToCheck, close) <= 0)
   {
      Print("❌ Erreur: Impossible de copier les données M1 pour support/résistance");
      return;
   }
   
   // Chercher les niveaux de support (bas significatifs)
   double currentLow = 0.0;
   int lowCount = 0;
   
   for(int i = 1; i < barsToCheck - 1; i++)
   {
      // Support potentiel: bougie avec un bas plus bas que les bougies adjacentes
      if(low[i] < low[i-1] && low[i] < low[i+1])
      {
         currentLow += low[i];
         lowCount++;
      }
   }
   
   if(lowCount > 0)
   {
      support = currentLow / lowCount; // Moyenne des supports identifiés
   }
   
   // Chercher les niveaux de résistance (hauts significatifs)
   double currentHigh = 0.0;
   int highCount = 0;
   
   for(int i = 1; i < barsToCheck - 1; i++)
   {
      // Résistance potentielle: bougie avec un haut plus haut que les bougies adjacentes
      if(high[i] > high[i-1] && high[i] > high[i+1])
      {
         currentHigh += high[i];
         highCount++;
      }
   }
   
   if(highCount > 0)
   {
      resistance = currentHigh / highCount; // Moyenne des résistances identifiés
   }
   
   // Si aucun support/résistance trouvé, utiliser les min/max récents
   if(support == 0.0)
   {
      support = low[ArrayMinimum(low)];
   }
   
   if(resistance == 0.0)
   {
      resistance = high[ArrayMaximum(high)];
   }
   
   Print("📊 Support/Résistance M1 calculés:");
   Print("   Support: ", DoubleToString(support, _Digits));
   Print("   Résistance: ", DoubleToString(resistance, _Digits));
}

//+------------------------------------------------------------------+
//| Obtenir la taille moyenne d'une bougie M1                           |
//+------------------------------------------------------------------+
double GetM1CandleSize()
{
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(_Symbol, PERIOD_M1, 0, 10, high) <= 0 || 
      CopyLow(_Symbol, PERIOD_M1, 0, 10, low) <= 0)
   {
      Print("⚠️ Erreur récupération bougies M1 pour taille moyenne");
      return SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10; // Fallback 10 pips
   }
   
   double totalSize = 0;
   int count = MathMin(10, ArraySize(high));
   
   for(int i = 0; i < count; i++)
   {
      totalSize += high[i] - low[i];
   }
   
   double avgSize = totalSize / count;
   return avgSize;
}

//+------------------------------------------------------------------+
//| FONCTIONS DE FALLBACK LOCAL QUAND LES ENDPOINTS ÉCHOUENT           |
//+------------------------------------------------------------------+

// Générer une analyse locale basée sur les indicateurs techniques
string GenerateLocalFallbackAnalysis()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFast) < 2 ||
      CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlow) < 2)
      return "";
   
   string direction = (emaFast[0] > emaSlow[0]) ? "BUY" : "SELL";
   double confidence = MathAbs(emaFast[0] - emaSlow[0]) / currentPrice * 100;
   
   string analysis = "{\"recommendation\":\"" + direction + "\",\"confidence\":" + 
                   DoubleToString(MathMin(0.7, confidence), 3) + 
                   ",\"reasoning\":\"Local fallback - EMA analysis\"}";
   
   if(DebugMode)
      Print("🔧 Fallback local généré pour Analysis: ", direction, " (", DoubleToString(confidence*100, 1), "%)");
   
   return analysis;
}

// Générer une tendance locale basée sur les EMA multi-timeframes + zones BUY/SELL pour affichage
string GenerateLocalFallbackTrend()
{
   string trend = "";
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrVal = 0;
   // Utiliser un handle local différent pour éviter les conflits
   int localAtrHandle = iATR(_Symbol, _Period, 14);
   if(localAtrHandle != INVALID_HANDLE)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(localAtrHandle, 0, 0, 1, atr) > 0) atrVal = atr[0];
      IndicatorRelease(localAtrHandle);
   }
   if(atrVal <= 0) atrVal = price * 0.002;
   double zoneHeight = atrVal * 1.5;
   double buyLow  = price - zoneHeight * 2;
   double buyHigh = price - zoneHeight;
   double sellLow = price + zoneHeight;
   double sellHigh = price + zoneHeight * 2;
   
   // Analyser M1
   string m1Trend = GetTrendOnTimeframe(PERIOD_M1);
   trend += "\"trend_m1\":{\"direction\":\"" + m1Trend + "\"},";
   
   // Analyser M5 (ou M1 si M5 indisponible pour indices type Boom)
   ENUM_TIMEFRAMES tfM5 = PERIOD_M5;
   double testClose[];
   if(CopyClose(_Symbol, PERIOD_M5, 0, 1, testClose) <= 0) tfM5 = _Period;
   string m5Trend = GetTrendOnTimeframe(tfM5);
   trend += "\"trend_m5\":{\"direction\":\"" + m5Trend + "\"},";
   
   // Analyser H1 (ou période courante si H1 indisponible)
   ENUM_TIMEFRAMES tfH1 = PERIOD_H1;
   if(CopyClose(_Symbol, PERIOD_H1, 0, 1, testClose) <= 0) tfH1 = _Period;
   string h1Trend = GetTrendOnTimeframe(tfH1);
   trend += "\"trend_h1\":{\"direction\":\"" + h1Trend + "\"},";
   
   // Consensus simple
   int uptrendCount = 0;
   if(StringFind(m1Trend, "UP") >= 0) uptrendCount++;
   if(StringFind(m5Trend, "UP") >= 0) uptrendCount++;
   if(StringFind(h1Trend, "UP") >= 0) uptrendCount++;
   
   string consensus = (uptrendCount >= 2) ? "STRONG_UPTREND" : (uptrendCount <= 1 && (StringFind(m1Trend, "DOWN") >= 0 || StringFind(m5Trend, "DOWN") >= 0)) ? "STRONG_DOWNTREND" : "NEUTRAL";
   double confidence = uptrendCount / 3.0;
   
   // Zones BUY/SELL pour affichage graphique (même quand l'API trend échoue)
   trend += "\"buy_zone_low\":" + DoubleToString(buyLow, _Digits) + ",\"buy_zone_high\":" + DoubleToString(buyHigh, _Digits) + ",";
   trend += "\"sell_zone_low\":" + DoubleToString(sellLow, _Digits) + ",\"sell_zone_high\":" + DoubleToString(sellHigh, _Digits) + ",";
   
   string fullTrend = "{\"symbol\":\"" + _Symbol + "\",\"timeframe\":\"M1\",\"timestamp\":\"" + 
                     TimeToString(TimeCurrent()) + "\"," + trend +
                     "\"consensus\":{\"direction\":\"" + consensus + "\",\"confidence\":" + 
                     DoubleToString(confidence, 2) + ",\"uptrend_count\":" + IntegerToString(uptrendCount) + 
                     ",\"downtrend_count\":" + IntegerToString(3-uptrendCount) + "}}";
   
   if(DebugMode)
      Print("🔧 Fallback local généré pour Trend: ", consensus, " (", DoubleToString(confidence*100, 0), "%) zones BUY/SELL calculées");
   
   return fullTrend;
}

// Générer une prédiction locale basée sur l'analyse technique
string GenerateLocalFallbackPrediction()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[];
   ArraySetAsSeries(atr, true);
   
   double atrValue = 0;
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
      atrValue = atr[0];
   else
      atrValue = currentPrice * 0.001; // 0.1% fallback
   
   // Direction basée sur EMA
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   string direction = "NEUTRAL";
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFast) >= 2 &&
      CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlow) >= 2)
   {
      direction = (emaFast[0] > emaSlow[0]) ? "UP" : "DOWN";
   }
   
   // Calculer SL/TP basés sur ATR
   double stopLoss = (direction == "UP") ? currentPrice - (atrValue * 2) : currentPrice + (atrValue * 2);
   double takeProfit = (direction == "UP") ? currentPrice + (atrValue * 3) : currentPrice - (atrValue * 3);
   
   string prediction = "{\"symbol\":\"" + _Symbol + "\",\"timeframe\":\"M1\",\"timestamp\":\"" + 
                     TimeToString(TimeCurrent()) + "\",\"prediction\":{\"direction\":\"" + direction + 
                     "\",\"confidence\":" + DoubleToString(0.6, 2) + ",\"price_target\":" + 
                     DoubleToString(takeProfit, 2) + ",\"stop_loss\":" + DoubleToString(stopLoss, 2) + 
                     ",\"take_profit\":" + DoubleToString(takeProfit, 2) + ",\"time_horizon\":\"1h\"},\"analysis\":{\"trend_strength\":65,\"volatility\":50,\"volume\":55,\"rsi\":50,\"macd\":\"NEUTRAL\"},\"source\":\"local_fallback\"}";
   
   if(DebugMode)
      Print("🔧 Fallback local généré pour Prediction: ", direction, " (60% confiance)");
   
   return prediction;
}

// Générer une analyse cohérente locale
string GenerateLocalFallbackCoherent()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Analyse simple basée sur la position actuelle vs moyennes mobiles
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   string direction = "NEUTRAL";
   double strength = 50.0;
   
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFast) >= 2 &&
      CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlow) >= 2)
   {
      if(emaFast[0] > emaSlow[0])
      {
         direction = "UP";
         strength = 60.0 + (emaFast[0] - emaSlow[0]) / currentPrice * 1000;
      }
      else
      {
         direction = "DOWN";
         strength = 60.0 + (emaSlow[0] - emaFast[0]) / currentPrice * 1000;
      }
   }
   
   strength = MathMax(40.0, MathMin(80.0, strength));
   string coherent = "{\"symbol\":\"" + _Symbol + "\",\"timeframe\":\"M1\",\"timestamp\":\"" + 
                     TimeToString(TimeCurrent()) + "\",\"direction\":\"" + direction + 
                     "\",\"coherence_score\":" + DoubleToString(strength/100, 2) + 
                     ",\"trend_alignment\":" + DoubleToString(strength, 1) + 
                     ",\"key_factors\":\"EMA alignment, RSI confirmation\"}";
   
   string url = "http://localhost:8000/api/coherent";
   string headers = "Content-Type: application/json\r\n";
   uchar data[];
   StringToCharArray(coherent, data);
   uchar result[];
   string result_headers;
   WebRequest("POST", url, headers, 5000, data, result, result_headers);
   return DoubleToString(strength/100, 2);
}

//+------------------------------------------------------------------+
//| FONCTIONS FVG_KILL INTÉGRÉES                                    |
//+------------------------------------------------------------------+

void FVG_InitializeIndicators()
{
   fvg_ema50H = iMA(_Symbol, FVG_HTF, FVG_EMA50, 0, MODE_EMA, PRICE_CLOSE);
   fvg_ema200H = iMA(_Symbol, FVG_HTF, FVG_EMA200, 0, MODE_EMA, PRICE_CLOSE);
   fvg_atrH = iATR(_Symbol, FVG_HTF, FVG_ATR_Period);
   fvg_fractalH = iFractals(_Symbol, FVG_HTF);
   
   if(fvg_ema50H == INVALID_HANDLE || fvg_ema200H == INVALID_HANDLE || 
      fvg_atrH == INVALID_HANDLE || fvg_fractalH == INVALID_HANDLE)
   {
      Print("❌ Erreur initialisation indicateurs FVG_Kill");
      fvg_UseFVGKill = false;
   }
   else
   {
      Print("✅ Indicateurs FVG_Kill initialisés avec succès");
   }
}

bool FVG_IsKillZone()
{
   if(!UseFVGKillSessions) return false;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   
   // Session London: 8h-11h
   if(hour >= FVG_LondonStart && hour <= FVG_LondonEnd)
      return true;
   
   // Session NY: 13h-16h
   if(hour >= FVG_NYStart && hour <= FVG_NYEnd)
      return true;
   
   return false;
}

bool FVG_DetectLiquiditySweep(string direction)
{
   if(!UseFVGKillLiquiditySweep) return false;
   
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   
   if(CopyHigh(_Symbol, FVG_LTF, 0, 20, high) <= 0 || 
      CopyLow(_Symbol, FVG_LTF, 0, 20, low) <= 0)
      return false;
   
   // Détecter un sweep des highs/lows récents
   double recentHigh = high[ArrayMaximum(high, 1, 10)];
   double recentLow = low[ArrayMinimum(low, 1, 10)];
   
   double currentHigh = high[0];
   double currentLow = low[0];
   
   if(direction == "BUY" && currentLow < recentLow)
      return true; // Sweep des lows
   
   if(direction == "SELL" && currentHigh > recentHigh)
      return true; // Sweep des highs
   
   return false;
}

bool FVG_IsBoomCrashMode()
{
   if(!UseFVGKillBoomCrashMode) return false;
   
   string symbol = _Symbol;
   if(StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0)
      return true;
   
   // Détecter les mouvements extrêmes
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(fvg_atrH, 0, 0, 5, atr) <= 0) return false;
   
   double currentATR = atr[0];
   double avgATR = 0;
   for(int i = 1; i < 5; i++) avgATR += atr[i];
   avgATR /= 4;
   
   return currentATR > avgATR * 2.0;
}

bool FVG_ShouldTrade(string direction)
{
   if(!fvg_UseFVGKill) return false;
   
   // Vérifier si on est en kill zone
   if(!FVG_IsKillZone()) return false;
   
   // Vérifier le nombre de positions
   int positions = PositionsTotal();
   if(positions >= FVG_MaxPositions) return false;
   
   // Détecter le liquidity sweep
   if(!FVG_DetectLiquiditySweep(direction)) return false;
   
   // Vérifier l'alignement EMA
   double ema50[], ema200[];
   ArraySetAsSeries(ema50, true);
   ArraySetAsSeries(ema200, true);
   
   if(CopyBuffer(fvg_ema50H, 0, 0, 3, ema50) <= 0 || 
      CopyBuffer(fvg_ema200H, 0, 0, 3, ema200) <= 0)
      return false;
   
   if(direction == "BUY")
   {
      return ema50[0] > ema200[0] && ema50[1] <= ema200[1];
   }
   else // SELL
   {
      return ema50[0] < ema200[0] && ema50[1] >= ema200[1];
   }
}

void FVG_ExecuteBuyWithAI()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(fvg_atrH, 0, 0, 1, atr);
   
   double stopLoss = ask - atr[0] * FVG_ATR_Mult;
   double takeProfit = ask + atr[0] * FVG_ATR_Mult * 2.0;
   
   double volume = CalculateOptimalLotSize();
   
   if(FVG_SendOrderWithVolume("BUY", volume, stopLoss, takeProfit))
   {
      Print("🔥 FVG_Kill BUY exécuté @ ", DoubleToString(ask, _Digits));
      Print("   SL: ", DoubleToString(stopLoss, _Digits));
      Print("   TP: ", DoubleToString(takeProfit, _Digits));
   }
}

void FVG_ExecuteSellWithAI()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[];
   ArraySetAsSeries(atr, true);
   CopyBuffer(fvg_atrH, 0, 0, 1, atr);
   
   double stopLoss = bid + atr[0] * FVG_ATR_Mult;
   double takeProfit = bid - atr[0] * FVG_ATR_Mult * 2.0;
   
   double volume = CalculateOptimalLotSize();
   
   if(FVG_SendOrderWithVolume("SELL", volume, stopLoss, takeProfit))
   {
      Print("🔥 FVG_Kill SELL exécuté @ ", DoubleToString(bid, _Digits));
      Print("   SL: ", DoubleToString(stopLoss, _Digits));
      Print("   TP: ", DoubleToString(takeProfit, _Digits));
   }
}

void FVG_ManageTrailingStructure()
{
   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         CPositionInfo pos;
         if(pos.SelectByTicket(ticket))
         {
            if(pos.Symbol() == _Symbol && pos.Magic() == InpMagicNumber)
            {
               double currentPrice = pos.PositionType() == POSITION_TYPE_BUY ? 
                                    SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                    SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               
               double openPrice = pos.PriceOpen();
               double stopLoss = pos.StopLoss();
               
               double atr[];
               ArraySetAsSeries(atr, true);
               if(CopyBuffer(fvg_atrH, 0, 0, 1, atr) <= 0) continue;
               
               double newStopLoss = 0;
               
               if(pos.PositionType() == POSITION_TYPE_BUY)
               {
                  newStopLoss = currentPrice - atr[0] * FVG_ATR_Mult;
                  if(newStopLoss > stopLoss && newStopLoss > openPrice)
                  {
                     trade.PositionModify(ticket, newStopLoss, pos.TakeProfit());
                  }
               }
               else
               {
                  newStopLoss = currentPrice + atr[0] * FVG_ATR_Mult;
                  if(newStopLoss < stopLoss && newStopLoss < openPrice)
                  {
                     trade.PositionModify(ticket, newStopLoss, pos.TakeProfit());
                  }
               }
            }
         }
      }
   }
}

bool FVG_SendOrderWithVolume(string orderType, double volume, double stopLoss, double takeProfit)
{
   if(orderType == "BUY")
   {
      return trade.Buy(volume, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), stopLoss, takeProfit, "FVG_Kill BUY");
   }
   else if(orderType == "SELL")
   {
      return trade.Sell(volume, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), stopLoss, takeProfit, "FVG_Kill SELL");
   }

   return false;
}

//+------------------------------------------------------------------+
//| END OF PROGRAM                                                  |
//+------------------------------------------------------------------+