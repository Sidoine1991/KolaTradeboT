//+------------------------------------------------------------------+
//|                                                      F_INX_robot4.mq5 |
//|                                      Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"
#property strict

// Inclusions des bibliothèques Windows nécessaires
#include <WinAPI\errhandlingapi.mqh>
#include <WinAPI\sysinfoapi.mqh>
#include <WinAPI\processenv.mqh>
#include <WinAPI\libloaderapi.mqh>
#include <WinAPI\memoryapi.mqh>

// Variables pour le suivi des profits par position

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\ArrayString.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>
#include <WinAPI/winapi.mqh>

//+------------------------------------------------------------------+
//| Constantes pour les timeframes                                    |
//+------------------------------------------------------------------+
// Note: TF_Entry et TF_Trend sont déclarés comme inputs plus bas dans le fichier

// Enum for trend direction
enum ENUM_TREND_DIR 
{
   TREND_NEUTRAL = 0,
   TREND_UP = 1,
   TREND_DOWN = -1
};

// Structure for multi-timeframe analysis
struct SMultiTimeframeAnalysis 
{
   ENUM_TREND_DIR h1_trend;
   ENUM_TREND_DIR m5_trend;
   double h1_ema_fast;
   double h1_ema_slow;
   double m5_ema_fast;
   double m5_ema_slow;
   double h1_atr;
   double m5_atr;
   double price_vs_h1_ema;
   double price_vs_m5_ema;
   bool is_h1_uptrend;
   bool is_m5_uptrend;
   bool is_h1_downtrend;
   bool is_m5_downtrend;
   double h1_support;
   double h1_resistance;
   double m5_support;
   double m5_resistance;
   string decision;
   string reason;
   double entry_price;
   double stop_loss;
   double take_profit;
   double risk_reward_ratio;
   double confidence;
   
   // Constructeur par défaut
   SMultiTimeframeAnalysis() :
      h1_trend(TREND_NEUTRAL),
      m5_trend(TREND_NEUTRAL),
      h1_ema_fast(0),
      h1_ema_slow(0),
      m5_ema_fast(0),
      m5_ema_slow(0),
      h1_atr(0),
      m5_atr(0),
      price_vs_h1_ema(0),
      price_vs_m5_ema(0),
      is_h1_uptrend(false),
      is_m5_uptrend(false),
      is_h1_downtrend(false),
      is_m5_downtrend(false),
      h1_support(0),
      h1_resistance(0),
      m5_support(0),
      m5_resistance(0),
      decision("HOLD"),
      reason("No analysis performed"),
      entry_price(0),
      stop_loss(0),
      take_profit(0),
      risk_reward_ratio(0),
      confidence(0)
   {
   }
};

// Structure pour le suivi des positions dynamiques
struct DynamicPositionState {
   ulong ticket;               // Ticket de la position
   double initialLot;         // Taille de lot initiale
   double currentLot;         // Taille de lot actuelle
   double highestProfit;      // Plus haut profit atteint
   bool trendConfirmed;       // La tendance est confirmée
   datetime lastAdjustmentTime; // Dernier ajustement
   double highestPrice;       // Plus haut prix atteint (pour les positions d'achat)
   double lowestPrice;        // Plus bas prix atteint (pour les positions de vente)
   int slModifyCount;         // Nombre de modifications SL (limité à 4 pour Boom/Crash)
   double initialSL;          // SL initial au moment de l'ouverture
   double initialTP;          // TP initial au moment de l'ouverture
   double atrAtOpen;          // Valeur ATR au moment de l'ouverture
   bool trailingActive;       // Indique si le trailing stop est activé
   double partialClose1Done;  // Niveau 1 de prise de profit partielle effectué
   double partialClose2Done;  // Niveau 2 de prise de profit partielle effectué
};

// Forward declarations
void DisplaySpikeAlert();
void UpdateSpikeAlertDisplay();
void CheckBasicEmaSignals();
void DrawBasicPredictionArrow(bool isBuy,double price,string reason);
int GetSupertrendDir();
double GetTodayProfitUSD();
void ManageTrade();

// Missing function declarations
int AllowedDirectionFromSymbol(string sym);
int AI_GetDecision(double rsi, double atr, double emaFastH1, double emaSlowH1, double emaFastM1, double emaSlowM1, double ask, double bid, int dirRule, bool spikeMode);
void DrawAIRecommendation(string action, double confidence, string reason, double price);
void DrawAIZones();
void CheckAIZoneAlerts();
void AI_UpdateAnalysis();
void DrawTimeWindowsPanel();
bool SMC_UpdateZones();
void AI_UpdateTimeWindows();
bool IsTradingTimeAllowed();
bool IsDrawdownExceeded();
bool SMC_GenerateSignal(bool &isBuy, double &entry, double &sl, double &tp, string &reason, double &atr);
bool IsSymbolLossCooldownActive(int cooldownSec = 180);
void StartSymbolLossCooldown();
void ExtendSymbolLossCooldownForSymbol(string symbol, int additionalMinutes);
int CountAllPositionsForMagic();
bool CanOpenNewPosition(ENUM_ORDER_TYPE orderType, double price, bool bypassCooldown = false);
int CountPendingOrdersForSymbol();
bool ExecuteClosestPendingOrder();
void ManagePendingOrders();
double GetMinLotFloorBySymbol(string sym);
bool ValidateAndAdjustStops(string symbol, ENUM_ORDER_TYPE type, double &executionPrice, double &sl, double &tp);
bool ExecuteTradeWithATR(ENUM_ORDER_TYPE orderType, double atr, double price, string comment, double confidence = 1.0, bool isSpikePriority = false, bool bypassCooldown = false);
double CalculateDynamicSL(ENUM_ORDER_TYPE orderType, double atr, double price, double volatilityRatio);
double CalculateDynamicTP(ENUM_ORDER_TYPE orderType, double atr, double price, double volatilityRatio);
void ApplyTrailingStop(ulong ticket, double currentATR, double volatilityRatio);
void ApplyPartialProfitTaking(ulong ticket, double currentProfit);
double GetVolatilityRatio(double atr, double price);
void InitializeDynamicPositionState(ulong ticket, double sl, double tp, double atr);
DynamicPositionState GetDynamicPositionState(ulong ticket);
SMultiTimeframeAnalysis AnalyzeMultiTimeframeSignals(void);
void SendAISummaryIfDue();
void EvaluateAIZoneBounceStrategy();
void CheckAITrendlineTouchAndTrade(); // Détection automatique des touches de trendlines/supports/résistances
void EvaluateBoomCrashZoneScalps();
void EvaluateAIZoneEMAScalps();
void ClearSpikeSignal();
void AttachChartIndicators();
bool SMC_Init();
void CloseSpikePositionAfterMove();
void DrawAIBlockLabel(string symbol, string text, string reason);
bool IsTradeAllowed(int direction, string symbol = NULL);
bool PredictSpikeFromSMCOB(double &spikePrice, bool &isBuySpike, double &confidence);
bool IsInSMCOBZone(double price, double &zoneStrength, bool &isBuyZone, double &zoneWidth);
bool CanTradeBoomCrashWithTrend(ENUM_ORDER_TYPE orderType);

// Déclarations pour les fonctions d'aide
void InitMultiTimeframeIndicators()
{
   // Initialisation des handles d'indicateurs pour différents timeframes
   // Ces handles sont utilisés pour accéder aux données des indicateurs dans les autres fonctions
   
   // Indicateurs pour le timeframe d'entrée (M1 par défaut)
   int atr_period = 14;
   int rsi_period = 14;
   int ema_fast = 9;
   int ema_slow = 21;
   
   // Initialisation des indicateurs pour le timeframe d'entrée (TF_Entry)
   atrHandle = iATR(_Symbol, TF_Entry, atr_period);
   rsiHandle = iRSI(_Symbol, TF_Entry, rsi_period, PRICE_CLOSE);
   emaFastHandle = iMA(_Symbol, TF_Entry, ema_fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, TF_Entry, ema_slow, 0, MODE_EMA, PRICE_CLOSE);
   
   // Initialisation des indicateurs pour le timeframe de tendance (TF_Trend)
   emaFastTrendHandle = iMA(_Symbol, TF_Trend, ema_fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowTrendHandle = iMA(_Symbol, TF_Trend, ema_slow, 0, MODE_EMA, PRICE_CLOSE);
   
   // Vérification que tous les indicateurs ont été correctement initialisés
   if(atrHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || 
      emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE ||
      emaFastTrendHandle == INVALID_HANDLE || emaSlowTrendHandle == INVALID_HANDLE)
   {
      Print("Erreur lors de l'initialisation des indicateurs multi-timeframe");
      return;
   }
   
   Print("Indicateurs multi-timeframe initialisés avec succès");
}
//+------------------------------------------------------------------+
//| Libération des ressources des indicateurs multi-timeframe        |
//+------------------------------------------------------------------+
void ReleaseMultiTimeframeIndicators()
{
   // Libération des handles des indicateurs de tendance
   if(emaFastTrendHandle != INVALID_HANDLE)
   {
      IndicatorRelease(emaFastTrendHandle);
      emaFastTrendHandle = INVALID_HANDLE;
   }
   
   if(emaSlowTrendHandle != INVALID_HANDLE)
   {
      IndicatorRelease(emaSlowTrendHandle);
      emaSlowTrendHandle = INVALID_HANDLE;
   }
   
   // Libération des autres handles d'indicateurs si nécessaire
   if(atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(atrHandle);
      atrHandle = INVALID_HANDLE;
   }
   
   if(rsiHandle != INVALID_HANDLE)
   {
      IndicatorRelease(rsiHandle);
      rsiHandle = INVALID_HANDLE;
   }
   
   if(emaFastHandle != INVALID_HANDLE)
   {
      IndicatorRelease(emaFastHandle);
      emaFastHandle = INVALID_HANDLE;
   }
   
   if(emaSlowHandle != INVALID_HANDLE)
   {
      IndicatorRelease(emaSlowHandle);
      emaSlowHandle = INVALID_HANDLE;
   }
   
   Print("Indicateurs multi-timeframe libérés avec succès");
}
//+------------------------------------------------------------------+
//| Calcule la taille de position en fonction du risque et du stop    |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopDistance)
{
   // Vérification de la distance de stop
   if(stopDistance <= 0)
   {
      Print("Erreur: Distance de stop invalide (", stopDistance, "). Utilisation du lot fixe: ", FixedLotSize);
      return FixedLotSize;
   }
   
   // Vérification du pourcentage de risque
   double riskPct = MathMin(MathMax(RiskPercent, 0.1), 10.0); // Limite entre 0.1% et 10%
   if(RiskPercent != riskPct)
   {
      Print("Avertissement: Le risque a été ajusté de ", RiskPercent, "% à ", riskPct, "% pour des raisons de sécurité");
   }
   
   // Récupération des informations du compte et du symbole avec vérification des erreurs
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0)
   {
      Print("Erreur: Solde du compte invalide: ", balance);
      return FixedLotSize;
   }
   
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), MaxLotSize); // Limite supérieure stricte
   
   if(tickSize <= 0 || tickValue <= 0 || lotStep <= 0 || minLot <= 0)
   {
      Print("Erreur: Paramètres du symbole invalides - tickSize:", tickSize, " tickValue:", tickValue, " lotStep:", lotStep, " minLot:", minLot);
      return FixedLotSize;
   }
   
   // Calcul du risque en devise (avec vérification du solde)
   double riskAmount = balance * (riskPct / 100.0);
   riskAmount = MathMin(riskAmount, balance * 0.1); // Pas plus de 10% du solde en risque
   
   // Conversion de la distance de stop en points
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0)
   {
      Print("Erreur: Point size invalide: ", point);
      return FixedLotSize;
   }
   
   double stopPoints = stopDistance / point;
   if(stopPoints <= 0)
   {
      Print("Erreur: Stop en points invalide: ", stopPoints);
      return FixedLotSize;
   }
   
   // Calcul du lot en fonction du risque
   double lotSize = (riskAmount / (stopPoints * tickValue)) * (tickSize / point);
   
   // Arrondi au pas de lot le plus proche
   lotSize = NormalizeDouble(MathFloor(lotSize / lotStep) * lotStep, 2);
   
   // Journalisation des paramètres de calcul
   if(DebugLotCalculation)
   {
      Print("Calcul du lot - ",
            "Balance: ", balance, " ",
            "Risque: ", riskPct, "% ",
            "Stop: ", stopPoints, "pts ",
            "Lot calculé: ", lotSize);
   }
   
   // Application des limites
   double finalLot = MathMax(minLot, MathMin(MathMin(lotSize, maxLot), MaxLotSize));
   finalLot = NormalizeDouble(MathFloor(finalLot / lotStep) * lotStep, 2);
   
   // Vérification finale de la marge disponible
   double margin = 0;
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   if(OrderCalcMargin(ORDER_TYPE_BUY, _Symbol, finalLot, 0, margin) && margin > 0)
   {
      double marginRatio = freeMargin / margin;
      if(marginRatio < 1.0) // Si la marge est insuffisante
      {
         // Réduction du lot pour respecter la marge disponible (avec une marge de sécurité)
         finalLot = NormalizeDouble(MathFloor((freeMargin * 0.95 / margin) * finalLot / lotStep) * lotStep, 2);
         Print("Ajustement du lot à ", finalLot, " pour respecter la marge disponible");
      }
   }
   
   // Règles spécifiques pour Boom/Crash - APPLIQUÉES EN DERNIER (priment sur tout)
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);
   
   if(isBoom || isCrash)
   {
      // Utiliser le lot minimum réel du symbole
      finalLot = MathMax(finalLot, minLot);
      
      // Limiter strictement pour Boom/Crash - PAS DE GRANDS LOTS
      double maxBoomCrashLot = 0.5; // Maximum 0.5 lot pour Boom/Crash
      finalLot = MathMin(finalLot, maxBoomCrashLot);
      
      if(DebugLotCalculation)
         Print("Boom/Crash - Lot ajusté à ", finalLot, " (min broker: ", minLot, ")");
   }
   else if(isStepIndex)
   {
      // Step Index : calcul basé sur le risque avec limites raisonnables
      finalLot = MathMax(finalLot, minLot);
      // Limite maximum pour Step Index : 0.5 lot
      double maxStepIndexLot = 0.5;
      finalLot = MathMin(finalLot, maxStepIndexLot);
      
      if(DebugLotCalculation)
         Print("Step Index - Lot ajusté à ", finalLot, " (min: ", minLot, ", max: ", maxStepIndexLot, ")");
   }
   else if(StringFind(_Symbol, "EUR") >= 0 || StringFind(_Symbol, "GBP") >= 0 || 
           StringFind(_Symbol, "USD") >= 0 || StringFind(_Symbol, "JPY") >= 0 ||
           StringFind(_Symbol, "AUD") >= 0 || StringFind(_Symbol, "CAD") >= 0 ||
           StringFind(_Symbol, "CHF") >= 0 || StringFind(_Symbol, "NZD") >= 0)
   {
      // Forex : limiter à 0.01 maximum
      finalLot = MathMin(finalLot, 0.01);
      if(DebugLotCalculation)
         Print("Forex - Lot limité à ", finalLot, " (max 0.01)");
   }
   
   // Dernière vérification des limites
   if(finalLot < minLot)
   {
      Print("Attention: Lot final (", finalLot, ") inférieur au minimum autorisé (", minLot, ")");
      return 0.0;
   }
   
   if(finalLot > maxLot)
   {
      Print("Avertissement: Lot final (", finalLot, ") supérieur au maximum autorisé (", maxLot, "). Limité à ", maxLot);
      finalLot = maxLot;
   }
   
   if(DebugLotCalculation)
   {
      Print("Lot final: ", finalLot, " (Min:", minLot, " Max:", maxLot, " Step:", lotStep, ")");
   }
   
   return finalLot;
}
int CountPositionsForSymbolMagic();
void ExecuteTrade(ENUM_ORDER_TYPE orderType, double lot, double price, string comment, double confidence);
void DisplayAnalysisResults(const SMultiTimeframeAnalysis &analysis);
void CreateLabel(string name, string text, int x, int y, color clr);

// Déclarations pour l'analyse multi-timeframe

// Handles pour les indicateurs multi-timeframe
int h1_ema_fast_handle = INVALID_HANDLE;
int h1_ema_slow_handle = INVALID_HANDLE;
int h1_atr_handle = INVALID_HANDLE;
int m5_ema_fast_handle = INVALID_HANDLE;
int m5_ema_slow_handle = INVALID_HANDLE;
int m5_atr_handle = INVALID_HANDLE;
// Variables pour le suivi des positions dynamiques
double g_lotMultiplier = 1.0;
bool g_trendConfirmed = false;
datetime g_lastTrendCheck = 0;

// Tableau pour suivre l'état des positions dynamiques
DynamicPositionState g_dynamicPosStates[];

// Structure pour tracker le nombre de modifications SL par position (Boom/Crash)
struct PositionSLModifyCount {
   ulong ticket;
   int modifyCount;  // Nombre de modifications SL effectuées
   datetime lastModifyTime;
};

// Tableau pour tracker les modifications SL (max 4 pour Boom/Crash)
PositionSLModifyCount g_slModifyTracker[100];
int g_slModifyTrackerCount = 0;

// Inclure le module SMC après la déclaration des structures pour éviter les redéfinitions
#define SMC_OB_PARAMS_DECLARED
#include "D:\\Dev\\TradBOT\\mt5\\SMC_OB_signals.mqh"

//========================= GLOBALS ==================================
int rsiHandle, atrHandle, emaFastHandle, emaSlowHandle;
int emaFastEntryHandle, emaSlowEntryHandle;
// EMA multi-timeframe pour alignement M5 / H1
int emaFastM4Handle, emaSlowM4Handle;
int emaFastM15Handle, emaSlowM15Handle;
int emaFastM5Handle, emaSlowM5Handle;  // M5 pour confirmation tendance
int emaScalpEntryHandle;        // EMA 10 M1 pour scalping/sniper
static datetime lastAutoTradeTime = 0;
int emaFastQuickHandle = INVALID_HANDLE;  // EMA 9 M1
int emaSlowQuickHandle = INVALID_HANDLE;  // EMA 21 M1
int stHandle = INVALID_HANDLE;        // Supertrend M5
static datetime g_lastBasicSignalTime = 0;
const int BASIC_SIGNAL_COOLDOWN_SEC = 60;
static double   accountStartBalance = 0.0;

// Handles pour indicateurs de tendance
int emaFastTrendHandle = INVALID_HANDLE;
int emaSlowTrendHandle = INVALID_HANDLE;

// Variables pour l'analyse multi-timeframe
double h1_ema_fast[], h1_ema_slow[], h1_atr[];
double m5_ema_fast[], m5_ema_slow[], m5_atr[];

// Paramètres du position sizing dynamique - DÉSACTIVÉ
input group "=== Dynamic Position Sizing ==="
input bool   UseDynamicPositionSizing = false;   // DÉSACTIVÉ - Ne pas doubler le lot
double DynamicLotMultiplier = 1.0;               // Désactivé
double MaxLotMultiplier = 1.0;                   // Désactivé
int MinBarsForAdjustment = 5;                    // Nombre minimum de bougies avant ajustement
int AdjustmentIntervalSeconds = 300;              // Intervalle minimum entre les ajustements (5 minutes)
// Simple JSON parsing functions
#include <Arrays\ArrayString.mqh>

// Simple JSON parsing functions
string getJsonString(string json, string key, string defaultValue = "")
{
   int start = StringFind(json, "\"" + key + "\"");
   if(start < 0) return defaultValue;
   
   int valueStart = StringFind(json, ":", start);
   if(valueStart < 0) return defaultValue;
   
   int quote1 = StringFind(json, "\"", valueStart + 1);
   if(quote1 < 0) return defaultValue;
   
   int quote2 = StringFind(json, "\"", quote1 + 1);
   if(quote2 < 0) return defaultValue;
   
   return StringSubstr(json, quote1 + 1, quote2 - quote1 - 1);
}

double getJsonDouble(string json, string key, double defaultValue = 0.0)
{
   int start = StringFind(json, "\"" + key + "\"");
   if(start < 0) return defaultValue;
   
   int valueStart = StringFind(json, ":", start);
   if(valueStart < 0) return defaultValue;
   
   int valueEnd = StringFind(json, ",", valueStart + 1);
   if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart + 1);
   if(valueEnd < 0) return defaultValue;
   
   string valueStr = StringSubstr(json, valueStart + 1, valueEnd - valueStart - 1);
   StringTrimLeft(valueStr);
   StringTrimRight(valueStr);
   
   return StringToDouble(valueStr);
}

bool getJsonBool(string json, string key, bool defaultValue = false)
{
   int start = StringFind(json, "\"" + key + "\"");
   if(start < 0) return defaultValue;
   
   int valueStart = StringFind(json, ":", start);
   if(valueStart < 0) return defaultValue;
   
   int valueEnd = StringFind(json, ",", valueStart + 1);
   if(valueEnd < 0) valueEnd = StringFind(json, "}", valueStart + 1);
   if(valueEnd < 0) return defaultValue;
   
   string valueStr = StringSubstr(json, valueStart + 1, valueEnd - valueStart - 1);
   StringTrimLeft(valueStr);
   StringTrimRight(valueStr);
   
   return (valueStr == "true" || valueStr == "1");
}

// Helper function to parse JSON arrays
string getJsonArrayItem(string json, int index)
{
   int bracket1 = StringFind(json, "[");
   if(bracket1 < 0) return "";
   
   int bracket2 = StringFind(json, "]", bracket1 + 1);
   if(bracket2 < 0) return "";
   
   string arrayStr = StringSubstr(json, bracket1 + 1, bracket2 - bracket1 - 1);
   
   int count = 0;
   int start = 0;
   int end = 0;
   
   for(int i = 0; i < StringLen(arrayStr); i++)
   {
      if(StringGetCharacter(arrayStr, i) == ',' && count == 0)
      {
         if(index == 0)
         {
            end = i;
            return StringSubstr(arrayStr, start, end - start);
         }
         else
         {
            index--;
            start = i + 1;
         }
      }
      else if(StringGetCharacter(arrayStr, i) == '{')
      {
         count++;
      }
      else if(StringGetCharacter(arrayStr, i) == '}')
      {
         count--;
      }
   }
   
   if(index == 0)
   {
      return StringSubstr(arrayStr, start);
   }
   
   return "";
}

CTrade trade;

//========================= INPUTS ===================================
input group "--- RISK MANAGEMENT ---"
input double RiskPercent     = 1.0;      // Risk réduit à 1% par trade
input double FixedLotSize    = 0.2;      // Lot fixe réduit si RiskPercent = 0 (adapté pour Boom 1000)
input double MaxLotSize      = 1.0;      // Plafond absolu de taille de lot
input bool   DebugLotCalculation = true; // Afficher les logs détaillés du calcul des lots
input int    MaxSpreadPoints = 100000;   // Spread max autorisé (filtre assoupli)
input int    MaxSimultaneousSymbols = 2; // Nombre maximum de symboles tradés en même temps
input bool   UseGlobalLossStop = false;   // Stop global sur pertes cumulées
input double GlobalLossLimit   = -3.0;    // Perte max cumulée avant clôture de toutes les positions (en $, si activé)
input double LossCutDollars    = 2.0;     // Coupure max pour la position principale (en $)
input double ProfitSecureDollars = 2.0;   // Gain à sécuriser (en $) par position
input double GlobalProfitSecure = 4.0;    // Gain total à sécuriser (en $) pour toutes les positions
input int    MinPositionLifetimeSec = 60; // Délai minimum avant fermeture (secondes) - évite ouvertures/fermetures trop rapides

// --- AJOUT: INPUTS DE SÉCURITÉ ---
input int    InpMagicNumber = 123456;          // Magic number pour identifier les trades de cet EA
input bool   EnableTrading = true;            // Master switch: activer/désactiver le trading
input double MinEquityForTrading = 100.0;     // Equity minimale pour ouvrir une position
input int    MaxConsecutiveLosses = 3;        // Stop après X pertes consécutives
input bool   EnableAutoAI = false;            // Désactiver exécutions AI automatiques si pertinent
input double MaxDailyLossPercent = 2.0;       // Perte journalière max en %
input bool   LogTradeDecisions = true;        // Activer logs supplémentaires

input group "--- GESTION DES PERTES ---"
input bool   UseEquityProtection = true;     // Activer la protection par équité
input double MaxEquityDrawdownPercent = 5.0;  // Pourcentage max de drawdown sur l'équité
input double MaxDailyLoss = 50.0;             // Perte quotidienne maximale globale ($) - 50$ pour Boom/Crash
input double MaxSymbolLoss = 4.0;             // Perte maximale par symbole ($)
input bool   EnableRecoveryMode = true;       // Activer le mode de récupération après grosse perte
input int    RecoveryCooldown = 3600;         // Délai avant reprise après grosse perte (secondes)

input group "--- MARTINGALE ---"
input bool   UseMartingale   = false;    // Désactivé pour éviter l'augmentation du risque
input double MartingaleMult  = 1.3;      // Multiplicateur réduit si activé
input int    MartingaleSteps = 2;        // Nombre max réduit de coups perdants consécutifs

input group "--- PARAMETRES DES INDICATEURS ---"
input int    RSI_Period = 14;                // Période du RSI
input int    ATR_Period = 14;                // Période de l'ATR
input int    EMA_Fast = 9;                   // Période de l'EMA rapide
input int    EMA_Slow = 21;                  // Période de l'EMA lente
input color  EMA_Fast_Color = clrDodgerBlue;  // Couleur de l'EMA rapide
input color  EMA_Slow_Color = clrOrange;      // Couleur de l'EMA lente
input int    EMA_Scalp_M1    = 10;       // EMA 10 pour scalping M1

input double TP_ATR_Mult     = 3.0;      // Multiplicateur ATR pour le Take Profit (ratio 1:2)
input double SL_ATR_Mult     = 2.5;      // Multiplicateur ATR pour le Stop Loss (augmenté pour Boom/Crash)

input bool   UseBreakEven    = true;
input double BE_ATR_Mult     = 0.8;      // Distance pour activer le BE
input double BE_Offset       = 10;       // Profit sécurisé en points (au-dessus du prix d'entrée)

input bool   UseTrailing     = true;
input double Trail_ATR_Mult  = 0.6;
input double Trail_Volatility_Mult = 1.2;  // Multiplicateur de volatilité pour trailing
input int    Trail_Activation_ATR = 1.0;   // ATR minimum pour activer trailing
input bool   UseDynamicATR   = true;      // Ajuster SL/TP selon volatilité
input double Volatility_Low_Mult = 0.8;    // Multiplicateur ATR si faible volatilité
input double Volatility_High_Mult = 1.5;   // Multiplicateur ATR si forte volatilité
input double Volatility_Threshold   = 0.3;   // Seuil de volatilité (ratio ATR/prix)

input group "--- PARTIAL CLOSE ---"
input double PartialClose1_Percent  = 50;        // % à fermer au premier TP partiel
input int    TakeProfit1_Pips       = 30;        // Niveau du premier TP partiel en pips

input group "--- ORDRES BACKUP (LIMIT) ---"
input bool   UseBackupLimit       = true;    // Placer un limit si le marché échoue
input double BackupLimitAtrMult   = 0.5;     // Distance en ATR pour le prix du limit
input int    BackupLimitMinPoints = 50;      // Distance mini en points si ATR faible
input int    BackupLimitExpirySec = 300;     // Expiration du limit (0 = GTC)
input int    MaxLimitOrdersPerSymbol = 2;    // Nombre maximum d'ordres limit par symbole
input bool   ExecuteClosestLimitForScalping = true; // Exécuter l'ordre limit le plus proche en scalping

input group "--- SÉCURITÉ AVANCÉE ---"
input double MaxDrawdownPercent = 5.0;    // Stop global si perte > X% (optimisé à 5% pour plus de flexibilité)
input int    MaxPositionsTotal  = 3;       // Nombre maximum de positions ouvertes simultanées (3 max pour volatilités)
input bool   UseTimeFilter      = false;  // Filtrer par heures de trading
input string TradingHoursStart  = "00:00";// Heure début (HH:MM, heure serveur)
input string TradingHoursEnd    = "23:59";// Heure fin   (HH:MM, heure serveur)
input double MaxLotPerSymbol    = 1.0;    // Lot maximum cumulé par symbole
input bool   UsePartialClose    = false;  // Activer la fermeture partielle
input double PartialCloseRatio  = 0.5;    // % du volume à fermer (0.5 = 50%)
input double BoomCrashProfitCut = 0.30;   // Clôture Boom/Crash dès profit >= X$ (0 pour désactiver)
input bool   UseVolumeFilter    = true;   // Activer le filtre de volume M1
input double VolumeMinMultiplier = 2.0;   // Volume actuel >= moyenne * X
input bool   UseSpikeSpeedFilter = true;  // Activer le filtre de vitesse des spikes
input double SpikeSpeedMinPoints = 5.0;   // Vitesse minimale en points/secondes

input group "--- RÈGLES DE TRADING AVANCÉES ---"
input bool   UseFixedTPSL       = true;    // Utiliser TP/SL fixes en dollars
input double FixedTPAmount      = 3.0;     // TP fixe à 3 dollars
input double FixedSLAmount      = 2.0;     // SL fixe à 2 dollars
input bool   UseFibonacciLevels = true;    // Utiliser les niveaux de Fibonacci pour entrées
input bool   UseEMAConfirmation  = false;    // Confirmer les entrées avec EMA
input bool   UseIAConfirmation   = false;    // Confirmer les entrées avec décisions IA

input group "--- ENTRY FILTERS ---"
input ENUM_TIMEFRAMES TF_Trend = PERIOD_H1;
input ENUM_TIMEFRAMES TF_Entry = PERIOD_M1;
input bool   AutoTradeStrongM1 = true;   // Ouvrir auto si tendance M1 marquée
input int    AutoCooldownSec   = 90;     // Délai min entre deux autos
input int    AfterLossCooldownSec = 0;    // Patience après un SL touché (0 = pas de cooldown)
input double MinMAGapPoints    = 10;     // Ecart min MA rapide/lente
input bool   AllowContraAuto   = false;  // Bloquer BUY sur Crash et SELL sur Boom
input bool   DebugBlocks       = true;   // Logs détaillés

// Indicateurs techniques additionnels (aident l'IA)
input group "--- INDICATEURS SUPPLÉMENTAIRES ---"
input bool   UseExtraIndicators = true;
input int    MACD_Fast          = 12;
input int    MACD_Slow          = 26;
input int    MACD_Signal        = 9;
input int    BB_Period          = 20;
input double BB_Deviation       = 2.0;
input int    Stoch_K            = 14;
input int    Stoch_D            = 3;
input int    Stoch_Slowing      = 3;

input group "--- BROKER LIMITS ---"
input int    MinStopPointsOverride = 0;  // 0 = utiliser StopsLevel broker, >0 = forcer ce minimum (en points)

input group "--- AI AGENT ---"
input bool   UseAI_Agent       = true;               // Activer l'agent IA (via serveur externe)
input string AI_ServerURL      = "http://127.0.0.1:8000/decision"; // URL serveur IA (FastAPI / autre)
input bool   UseAdvancedDecisionGemma = false;        // Utiliser endpoint decisionGemma (Gemma+Gemini) avec analyse visuelle
input int    AI_Timeout_ms     = 800;                // Timeout WebRequest en millisecondes
input bool   AI_CanBlockTrades = false;              // Si true, l'IA peut bloquer des entrées (false = guide seulement)
input double AI_MinConfidence  = 0.6;                // Confiance minimale IA pour influencer/autoriser les décisions (0.0-1.0) - RECOMMANDÉ: 0.6+
input bool   AI_UseNotifications = true;             // Envoyer notifications pour signaux consolidés
input bool   AI_AutoExecuteTrades = true;             // Exécuter automatiquement les trades IA (true = actif par défaut)
input bool   AI_PredictSpikes   = true;              // Prédire les zones de spike Boom/Crash avec flèches
input int    SignalValidationMinScore = 75;           // Score minimum de validation (0-100) - OPTIMISÉ: 75 pour plus d'opportunités
input string AI_AnalysisURL    = "http://127.0.0.1:8000/analysis";  // URL base pour l'analyse complète (structure H1, etc.)
input int    AI_AnalysisIntervalSec = 60;                           // Fréquence de rafraîchissement de l'analyse (secondes)
input bool   AI_DrawH1Structure = true;                             // Tracer la structure H1 (trendlines, ETE) sur le graphique
input string AI_TimeWindowsURLBase = "http://127.0.0.1:8000";       // Racine API pour /time_windows
input group "--- AI ZONE STRATEGY ---"
input bool   UseAIZoneBounceStrategy   = true;       // Utiliser la stratégie de rebond entre zones BUY/SELL
input int    AIZoneConfirmBarsM5       = 2;          // Nombre de bougies M5 pour confirmer le rebond
input int    AIZoneScalpEMAPeriodM5    = 50;         // EMA utilisée pour les scalps de pullback (par défaut 50)
input int    AIZoneScalpCooldownSec    = 60;         // Délai minimum entre deux scalps sur le même symbole
input double AIZoneScalpEMAToleranceP  = 5.0;        // Tolérance en points autour de l'EMA pour considérer un contact
input group "--- BOOM/CRASH ZONE SCALPS ---"
input bool   UseBoomCrashZoneScalps    = true;       // Boom/Crash: rebond simple dans zone = scalp agressif
input int    BC_TP_Points              = 300;        // TP fixe en points (par défaut ~300 points)
input int    BC_SL_Points              = 200;        // SL fixe en points (augmenté pour plus de marge)
input ENUM_TIMEFRAMES BC_ConfirmTF     = PERIOD_M15; // TF de confirmation du rebond (ex: M15 sur Boom 1000)
input int    BC_ConfirmBars            = 1;          // Nombre de bougies de confirmation dans le sens du rebond

// Note: Les paramètres de gestion dynamique du risque sont déjà définis plus haut dans le fichier

input group "--- SUPERTREND ---"
input bool   UseSupertrendFilter   = true;  // Activer filtre Supertrend
input int    ST_Period             = 10;
input double ST_Multiplier         = 3.0;

input group "--- DAILY PROFIT ---"
input double DailyProfitTargetUSD  = 50.0;

input group "--- SMC / OrderBlock ---"
input bool   Use_SMC_OB_Filter      = true;     // SMC valide ou bloque les signaux existants
input bool   Use_SMC_OB_Entries     = false;    // SMC peut déclencher un trade (MM inchangé)
input ENUM_TIMEFRAMES SMC_HTF       = PERIOD_M15;
input ENUM_TIMEFRAMES SMC_LTF       = PERIOD_M1;
input double SMC_OB_ATR_Tolerance   = 0.6;      // distance max (en ATR HTF) au support/résistance
input double SMC_OB_SL_ATR          = 0.8;      // SL multiplié par ATR HTF
input double SMC_OB_TP_ATR          = 2.5;      // TP multiplié par ATR HTF
input bool   SMC_DrawZones          = true;     // dessiner les niveaux SMC sur le graphique

//========================= ETAT IA ==================================

// Etat IA (facultatif, pour debug / affichage)
static string   g_lastAIAction    = "";
static double   g_lastAIConfidence = 0.0;
static string   g_lastAIReason    = "";
static string   g_lastAIAnalysis   = "";  // 🆕 Analyse complète Gemma+Gemini
static datetime g_lastAITime      = 0;
static double   g_lastAIStopLoss  = 0.0;     // Dernier stop loss défini par l'IA
static double   g_lastAITakeProfit = 0.0;    // Dernier take profit défini par l'IA
static bool     g_resetAPIErrors  = false;   // 🆕 Flag pour réinitialiser les erreurs API

// Prédictions de spike IA
static bool     g_aiSpikePredicted = false;
static double   g_aiSpikeZonePrice = 0.0;
static bool     g_aiSpikeDirection = true; // true=BUY, false=SELL
static datetime g_aiSpikePredictionTime = 0;
static bool     g_aiSpikeExecuted  = false;
static datetime g_aiSpikeExecTime  = 0;
static bool     g_aiSpikePendingPlaced = false; // Un ordre stop/limit pré-spike déjà placé
// Pré‑alerte de spike (warning anticipé, sans exécution auto)
static bool     g_aiEarlySpikeWarning   = false;
static double   g_aiEarlySpikeZonePrice = 0.0;
static bool     g_aiEarlySpikeDirection = true;
static bool     g_aiStrongSpike         = false; // true si spike_prediction (signal fort), false si seulement pré‑alerte
// Zones IA H1 confirmées M5
static double   g_aiBuyZoneLow   = 0.0;
static double   g_aiBuyZoneHigh  = 0.0;
static double   g_aiSellZoneLow  = 0.0;
static double   g_aiSellZoneHigh = 0.0;
static bool     g_aiZoneAlertBuy  = false;
static bool     g_aiZoneAlertSell = false;
static datetime g_aiLastZoneAlert = 0;
static datetime g_lastAISummaryTime = 0;
// Stratégie de rebond sur zones IA : armement quand le prix touche la zone
static bool     g_aiBuyZoneArmed      = false;
static bool     g_aiSellZoneArmed     = false;
static datetime g_aiBuyZoneTouchTime  = 0;
static datetime g_aiSellZoneTouchTime = 0;
// Contexte de tendance après rebond / cassure pour scalping EMA50
static bool     g_aiBuyTrendActive    = false;
static bool     g_aiSellTrendActive   = false;
static datetime g_aiLastScalpTime     = 0;
// Tolérance de cassure de trendline pour validations (en points)
input int       AIZoneTrendlineBreakTolerance = 5;
// Cooldown après un trade spike (évite ré-entrées immédiates)
static datetime g_lastSpikeBlockTime = 0;
// Cooldown après pertes consécutives sur un symbole :
// - après 2 pertes consécutives : pause courte (3 minutes)
// - après 3 pertes consécutives : pause longue "primordiale" (30 minutes minimum)
static datetime g_lastSymbolLossTime = 0;
// Cooldown spécifique Boom 300 après 2 pertes impliquant ce symbole
static datetime g_boom300CooldownUntil = 0;
// Trades pris malgré le cooldown (pour durcir le cooldown si échec)
struct TradeBypassCooldown
{
   ulong ticket;
   string symbol;
   string comment;
   datetime openTime;
};
static TradeBypassCooldown g_tradesBypassCooldown[50];
static int g_tradesBypassCooldownCount = 0;
// Dernière raison de validation bloquée (pour affichage/notification)
static string   g_lastValidationReason = "";
static string   g_lastAIJson       = "";   // Dernière réponse JSON brute du serveur IA (pour affichage)

// Mise à jour des indicateurs IA
static datetime g_lastAIIndicatorsUpdate = 0;
#define AI_INDICATORS_UPDATE_INTERVAL 300  // 5 minutes

// Notifications (éviter spam)
static datetime g_lastNotificationTime = 0;
static string   g_lastNotificationSignal = "";

// Détection des spikes
static datetime g_aiSpikeDetectedTime = 0; // Heure à laquelle le dernier spike a été détecté
static datetime g_lastSpikeAlertNotifTime = 0; // Dernière notification sonore spike envoyée

// Compteur d'échecs de spike et cooldown par symbole
static int      g_spikeFailCount      = 0;  // Nombre de tentatives de spike sans exécution
static datetime g_spikeCooldownUntil  = 0;  // Si > maintenant: on ignore les nouveaux spikes

// Structure pour suivre les pertes consécutives par symbole
struct SymbolLossTracker
{
   string symbol;
   int consecutiveLosses;
   datetime cooldownUntil;
   double totalGainRealized;  // Gain total réalisé sur ce symbole (historique)
};

// Suivi des pertes par symbole et globales
static double   g_symbolLoss = 0.0;         // Perte cumulée pour le symbole actuel
static double   g_globalLoss = 0.0;         // Perte cumulée globale
static double   g_globalProfit = 0.0;       // Gain cumulé global (pour sécurisation à +6$)
static datetime g_lastLossTime = 0;         // Dernière perte enregistrée
static bool     g_inRecoveryMode = false;   // Mode récupération activé
static datetime g_recoveryUntil = 0;        // Fin du mode récupération
static datetime g_lastDailyReset = 0;       // Dernière réinitialisation quotidienne
static bool     g_dailyTradingHalted = false; // Arrêt du trading pour la journée (perte >= 50$)

// Tableau pour suivre les pertes consécutives par symbole
static SymbolLossTracker g_symbolLossTrackers[50];
static int g_symbolLossTrackersCount = 0;

// Timing d'entrée pré-spike
static datetime g_spikeEntryTime      = 0;  // Heure prévue d'entrée (dernière bougie avant spike)

// Réinitialiser les compteurs quotidiens si nouveau jour
void ResetDailyCountersIfNeeded()
{
   datetime now = TimeCurrent();
   MqlDateTime now_dt, last_dt;
   TimeToStruct(now, now_dt);
   
   if(g_lastDailyReset > 0)
   {
      TimeToStruct(g_lastDailyReset, last_dt);
      // Si nouveau jour (jour, mois ou année différent)
      if(now_dt.day != last_dt.day || now_dt.mon != last_dt.mon || now_dt.year != last_dt.year)
      {
         g_symbolLoss = 0.0;
         g_globalLoss = 0.0;
         g_dailyTradingHalted = false;
         g_inRecoveryMode = false;
         g_lastDailyReset = now;
         Print("🔄 Reset quotidien - Nouveau jour. Compteurs de pertes réinitialisés.");
      }
   }
   else
   {
      g_lastDailyReset = now;
   }
}

// Trouver ou créer un tracker de pertes pour un symbole
int FindOrCreateSymbolTracker(string symbol)
{
   for(int i = 0; i < g_symbolLossTrackersCount; i++)
   {
      if(g_symbolLossTrackers[i].symbol == symbol)
         return i;
   }
   
   // Créer un nouveau tracker
   if(g_symbolLossTrackersCount >= 50) return -1; // Limite atteinte
   
   int idx = g_symbolLossTrackersCount++;
   g_symbolLossTrackers[idx].symbol = symbol;
   g_symbolLossTrackers[idx].consecutiveLosses = 0;
   g_symbolLossTrackers[idx].cooldownUntil = 0;
   g_symbolLossTrackers[idx].totalGainRealized = 0.0;
   return idx;
}

// Vérifier si un symbole est en cooldown après 3 pertes consécutives
bool IsSymbolInCooldownAfterLosses(string symbol)
{
   int idx = FindOrCreateSymbolTracker(symbol);
   if(idx < 0) return false;
   
   // Si 3 pertes consécutives ou plus, vérifier le cooldown de 3 minutes
   if(g_symbolLossTrackers[idx].consecutiveLosses >= 3)
   {
      if(TimeCurrent() < g_symbolLossTrackers[idx].cooldownUntil)
      {
         int remaining = (int)((g_symbolLossTrackers[idx].cooldownUntil - TimeCurrent()) / 60) + 1;
         static datetime lastMsg = 0;
         if(TimeCurrent() - lastMsg >= 60) // Message toutes les minutes
         {
            Print("⏸️ COOLDOWN ACTIF: ", symbol, " - ", remaining, " minute(s) restante(s) après 3 pertes consécutives");
            lastMsg = TimeCurrent();
         }
         return true;
      }
      else
      {
         // Cooldown terminé, réinitialiser
         g_symbolLossTrackers[idx].consecutiveLosses = 0;
         g_symbolLossTrackers[idx].cooldownUntil = 0;
         Print("✅ Cooldown terminé pour ", symbol, " - Prêt pour nouveaux trades");
      }
   }
   return false;
}

// Mettre à jour le suivi des pertes
void UpdateLossTracking(double profitLoss, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   
   datetime now = TimeCurrent();
   
   // Réinitialiser les compteurs si nouveau jour
   ResetDailyCountersIfNeeded();
   
   // Mettre à jour les compteurs de pertes
   if(profitLoss < 0) {
      g_symbolLoss += MathAbs(profitLoss);
      g_globalLoss += MathAbs(profitLoss);
      g_lastLossTime = now;
      
      // Mettre à jour les pertes consécutives par symbole
      int idx = FindOrCreateSymbolTracker(symbol);
      if(idx >= 0)
      {
         g_symbolLossTrackers[idx].consecutiveLosses++;
         
         // Si 3 pertes consécutives, activer cooldown de 3 minutes
         if(g_symbolLossTrackers[idx].consecutiveLosses >= 3)
         {
            g_symbolLossTrackers[idx].cooldownUntil = now + (3 * 60); // 3 minutes
            Print("🛑 LOSS KILLER: ", symbol, " - 3 pertes consécutives détectées. Pause de 3 minutes activée.");
         }
      }
      
      // Pour Boom/Crash: arrêter le trading pour la journée si perte >= 50$
      bool isBoomCrash = (StringFind(symbol, "Boom") != -1 || StringFind(symbol, "Crash") != -1);
      if(isBoomCrash && g_globalLoss >= 50.0 && !g_dailyTradingHalted)
      {
         g_dailyTradingHalted = true;
         CloseAllPositions();
         CancelAllPendingOrders();
         Print("🛑 ARRÊT DU TRADING POUR LA JOURNÉE - Perte quotidienne atteinte: $", 
               DoubleToString(g_globalLoss, 2), " (limite: $50.00)");
         Print("⏸️ Le robot reprendra automatiquement demain.");
      }
      
      // Vérifier si on dépasse les seuils
      if(g_symbolLoss >= MaxSymbolLoss || g_globalLoss >= MaxDailyLoss) {
         // Activer le mode récupération
         g_inRecoveryMode = true;
         g_recoveryUntil = now + RecoveryCooldown;
         
         // Fermer toutes les positions
         CloseAllPositions();
         
         // Annuler tous les ordres en attente
         CancelAllPendingOrders();
         
         Print("⚠️ Mode récupération activé - Perte maximale atteinte (Symbole: $", 
               g_symbolLoss, " / Global: $", g_globalLoss, ")");
      }
   }
   else if(profitLoss > 0)
   {
      // Gain réalisé - réinitialiser les pertes consécutives pour ce symbole
      int idx = FindOrCreateSymbolTracker(symbol);
      if(idx >= 0)
      {
         if(g_symbolLossTrackers[idx].consecutiveLosses > 0)
         {
            Print("✅ Gain réalisé sur ", symbol, " - Réinitialisation des pertes consécutives (était: ", 
                  g_symbolLossTrackers[idx].consecutiveLosses, ")");
         }
         g_symbolLossTrackers[idx].consecutiveLosses = 0;
         g_symbolLossTrackers[idx].cooldownUntil = 0;
         g_symbolLossTrackers[idx].totalGainRealized += profitLoss; // Accumuler le gain total
      }
      
      g_globalProfit += profitLoss;
   }
   
   // Vérifier si on peut sortir du mode récupération
   if(g_inRecoveryMode && now >= g_recoveryUntil) {
      g_inRecoveryMode = false;
      g_symbolLoss = 0.0; // Réinitialiser la perte du symbole
      Print("✅ Fin du mode récupération - Prêt pour de nouveaux trades");
   }
}

// Vérifier si le lot est valide pour le symbole
bool IsValidLotSize(double lot, string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   
   // Vérifier si c'est une paire de volatilité
   bool isVolatility = (StringFind(symbol, "Volatility") != -1);
   
   // Pour les paires de volatilité, lot max = 0.1
   if(isVolatility && lot > 0.1) {
      Print("❌ Lot trop élevé pour ", symbol, ": ", lot, " (max 0.1 pour les paires de volatilité)");
      return false;
   }
   
   // Vérifier les limites du courtier
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   if(lot < minLot || lot > maxLot) {
      Print("❌ Lot ", lot, " en dehors des limites pour ", symbol, ": ", minLot, " - ", maxLot);
      return false;
   }
   
   // Vérifier que le lot est un multiple du pas
   if(MathAbs(MathRound(lot / lotStep) * lotStep - lot) > 0.0001) {
      Print("❌ Lot ", lot, " n'est pas un multiple du pas pour ", symbol, ": ", lotStep);
      return false;
   }
   
   return true;
}

// Vérifier si on peut trader en fonction des pertes
bool CanTradeBasedOnLoss()
{
   // Réinitialiser les compteurs si nouveau jour
   ResetDailyCountersIfNeeded();
   
   // Si trading arrêté pour la journée (perte >= 50$ sur Boom/Crash)
   if(g_dailyTradingHalted)
   {
      return false;
   }
   
   // Vérifier le cooldown après 3 pertes consécutives sur ce symbole
   if(IsSymbolInCooldownAfterLosses(_Symbol))
   {
      return false; // En cooldown, ne pas trader
   }
   
   // Si on est en mode récupération, on ne trade pas
   if(g_inRecoveryMode) {
      if(TimeCurrent() >= g_recoveryUntil) {
         g_inRecoveryMode = false;
         g_symbolLoss = 0.0;
         Print("✅ Fin du mode récupération - Prêt pour de nouveaux trades");
      } else {
         return false;
      }
   }
   
   // Vérifier les limites de pertes
   if(g_symbolLoss >= MaxSymbolLoss) {
      Print("❌ Limite de perte atteinte pour ce symbole: $", g_symbolLoss);
      return false;
   }
   
   if(g_globalLoss >= MaxDailyLoss) {
      Print("❌ Limite de perte quotidienne atteinte: $", g_globalLoss);
      return false;
   }
   
   return true;
}

// Fermer toutes les positions
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) {
            
            // Utiliser la variable globale trade
            trade.PositionClose(ticket);
         }
      }
   }
}

// Annuler tous les ordres en attente
void CancelAllPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket)) {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && 
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber) {
            
            // Utiliser la variable globale trade
            trade.OrderDelete(ticket);
         }
      }
   }
}

// Helper: réinitialiser complètement l'état de signal de spike
void ClearSpikeSignal()
{
   bool wasExecuted = g_aiSpikeExecuted;

   g_aiSpikePredicted        = false;
   g_aiEarlySpikeWarning     = false;
   g_aiStrongSpike           = false;
   g_aiSpikeZonePrice        = 0.0;
   g_aiSpikeExecuted         = false;
   g_aiSpikePendingPlaced    = false;
   g_aiSpikeDetectedTime     = 0;
   g_lastSpikeAlertNotifTime = 0;
   g_spikeEntryTime          = 0;

   string arrowName = "SPIKE_ARROW_" + _Symbol;
   ObjectDelete(0, arrowName);
   string labelName = "SPIKE_COUNTDOWN_" + _Symbol;
   ObjectDelete(0, labelName);

   // Gestion des tentatives ratées: si aucun trade spike n'a été exécuté
   // avant l'annulation du signal, incrémenter le compteur d'échecs.
   if(!wasExecuted)
   {
      g_spikeFailCount++;
      if(g_spikeFailCount >= 3)
      {
         g_spikeCooldownUntil = TimeCurrent() + 10 * 60; // 10 minutes de cooldown
         g_spikeFailCount = 0;
         Print("⏸ Cooldown spike 10 minutes sur ", _Symbol, " après 3 tentatives sans spike.");
      }
   }
   else
   {
      // Sur un spike réussi, on remet à zéro le compteur et le cooldown
      g_spikeFailCount     = 0;
      g_spikeCooldownUntil = 0;
   }
}

// Structure pour les zones SMC_OB (Order Blocks)
struct SMC_OB_Zone {
   double price;           // Niveau de prix de la zone
   bool isBuyZone;         // true = zone d'achat (verte), false = zone de vente (rouge)
   datetime time;          // Heure de création de la zone
   double strength;        // Force de la zone (0-1)
   double width;           // Largeur de la zone en points
   bool isActive;          // Si la zone est toujours active
};

// Tableau des zones SMC_OB détectées
SMC_OB_Zone g_smcZones[50];
int g_smcZonesCount = 0;   // Nombre de zones actives

// Paramètres de détection des zones SMC_OB
input group "=== Paramètres SMC_OB ==="
input int SMC_OB_Lookback = 50;           // Nombre de bougies à analyser
input int SMC_OB_MinCandles = 3;          // Nombre minimum de bougies pour former une zone
input double SMC_OB_ZoneWidth = 0.0002;   // Largeur de la zone (en pourcentage du prix)
input int SMC_OB_ExpiryBars = 20;         // Nombre de bougies avant expiration d'une zone
input bool SMC_OB_UseForSpikes = true;    // Utiliser les zones SMC_OB pour la détection des spikes

// Fenêtres horaires optimales (24 heures, indexées 0-23) - spécifiques au symbole
bool g_hourPreferred[24];

// Variables pour le suivi des pertes sur Boom 1000
int g_boom1000LossStreak = 0;         // Compteur de pertes consécutives
datetime g_boom1000CooldownUntil = 0;  // Timestamp de fin du cooldown
const int BOOM1000_COOLDOWN_MINUTES = 15;  // Durée du cooldown en minutes
bool g_hourForbidden[24];
static datetime g_lastTimeWindowsUpdate = 0;
static string   g_timeWindowsSymbol = ""; // Symbole pour lequel les fenêtres ont été récupérées

// Structure H1 (trendlines, ETE) récupérée via /analysis
static datetime g_lastAIAnalysisTime   = 0;
static double   g_h1BullStartPrice    = 0.0;
static double   g_h1BullEndPrice      = 0.0;
static datetime g_h1BullStartTime     = 0;
static datetime g_h1BullEndTime       = 0;
static double   g_h1BearStartPrice    = 0.0;
static double   g_h1BearEndPrice      = 0.0;
static datetime g_h1BearStartTime     = 0;
static datetime g_h1BearEndTime       = 0;
static bool     g_h1ETEFound          = false;
static double   g_h1ETEHeadPrice      = 0.0;
static datetime g_h1ETEHeadTime       = 0;

// Trendlines supplémentaires pour H4 et M15 (même logique que H1)
static double   g_h4BullStartPrice    = 0.0;
static double   g_h4BullEndPrice      = 0.0;
static datetime g_h4BullStartTime     = 0;
static datetime g_h4BullEndTime       = 0;
static double   g_h4BearStartPrice    = 0.0;
static double   g_h4BearEndPrice      = 0.0;
static datetime g_h4BearStartTime     = 0;
static datetime g_h4BearEndTime       = 0;

static double   g_m15BullStartPrice   = 0.0;
static double   g_m15BullEndPrice     = 0.0;
static datetime g_m15BullStartTime    = 0;
static datetime g_m15BullEndTime      = 0;
static double   g_m15BearStartPrice   = 0.0;
static double   g_m15BearEndPrice     = 0.0;
static datetime g_m15BearStartTime    = 0;
static datetime g_m15BearEndTime      = 0;

// Stats volume & vitesse
static datetime lastVolumeCheck = 0;
static double   volumeAvg       = 0.0;
static double   prevSpeedPrice  = 0.0;
static datetime prevSpeedTime   = 0;
static datetime g_lastTradeAttemptTime = 0;

//-------------------- STRUCTURE INTERNE H1 (swings/creux/sommets) ----------------
struct H1SwingPoint
{
   int      index;
   datetime time;
   double   price;
   bool     isHigh;  // true = swing high, false = swing low
};

//-------------------- SÉCURITÉ AVANCÉE ------------------------------

// Vérifie si l'heure actuelle est dans la plage autorisée
bool IsTradingTimeAllowed()
{
   if(!UseTimeFilter) return true;

   datetime now = TimeCurrent();
   MqlDateTime ts;
   TimeToStruct(now, ts);
   int curHour = ts.hour;
   int curHM   = ts.hour*100 + ts.min;

   // 1) Exploiter d'abord les fenêtres horaires IA spécifiques au symbole
   //    (g_hourPreferred / g_hourForbidden remplis par AI_UpdateTimeWindows).
   if(g_timeWindowsSymbol == _Symbol) // Fenêtres valides pour ce symbole
   {
      if(curHour >= 0 && curHour < 24)
      {
         // Heures explicitement interdites par l'IA -> on bloque toujours
         if(g_hourForbidden[curHour])
            return false;

         // S'il existe au moins une heure "preferred" pour ce symbole,
         // on ne trade que dans ces heures-là (les autres sont ignorées).
         bool hasPreferred = false;
         for(int h=0; h<24; h++)
         {
            if(g_hourPreferred[h]) { hasPreferred = true; break; }
         }
         if(hasPreferred && !g_hourPreferred[curHour])
            return false;
      }
   }

   // 2) Appliquer ensuite, en complément, la plage horaire manuelle TradingHoursStart/End
   int sh = (int)StringToInteger(StringSubstr(TradingHoursStart,0,2));
   int sm = (int)StringToInteger(StringSubstr(TradingHoursStart,3,2));
   int eh = (int)StringToInteger(StringSubstr(TradingHoursEnd,0,2));
   int em = (int)StringToInteger(StringSubstr(TradingHoursEnd,3,2));
   int start = sh*100 + sm;
   int end   = eh*100 + em;

   // Plage simple dans la même journée
   return (curHM >= start && curHM <= end);
}

// Stoppe les nouvelles entrées si drawdown global trop élevé
bool IsDrawdownExceeded()
{
   if(MaxDrawdownPercent <= 0.0) return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(accountStartBalance <= 0.0)
   {
      accountStartBalance = equity;
      return false;
   }

   double dd = (accountStartBalance - equity) / accountStartBalance * 100.0;
   if(dd >= MaxDrawdownPercent)
   {
      PrintFormat("SECURITY: Drawdown %.2f%% >= %.2f%%, blocage des nouvelles entrées", dd, MaxDrawdownPercent);
      return true;
   }
   return false;
}

// Journalisation avancée dans un fichier + Journal
void LogError(string msg)
{
   if(DebugBlocks)
   {
      int h = FileOpen("F_INX_robot4_log.txt", FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_READ);
      if(h != INVALID_HANDLE)
      {
         FileSeek(h, 0, SEEK_END);
         FileWrite(h, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), " ", msg);
         FileClose(h);
      }
   }
   Print(msg);
}

// Filtre: volume suffisant sur M1
bool IsVolumeSufficient()
{
   if(!UseVolumeFilter) return true;

   // Recalcule la moyenne toutes les 5 minutes
   if(TimeCurrent() - lastVolumeCheck > 300)
   {
      long buf[];
      if(CopyTickVolume(_Symbol, TF_Entry, 0, 20, buf) > 0)
      {
         double sum = 0.0;
         int cnt = ArraySize(buf);
         for(int i=0;i<cnt;i++) sum += (double)buf[i];
         volumeAvg = (cnt>0) ? sum/cnt : 0.0;
         g_lastAIIndicatorsUpdate = TimeCurrent();
      }
      lastVolumeCheck = TimeCurrent();
   }

   long curBuf[];
   if(CopyTickVolume(_Symbol, TF_Entry, 0, 1, curBuf) > 0)
   {
      if(volumeAvg <= 0.0) return true;
      double cur = (double)curBuf[0];
      return cur >= volumeAvg * VolumeMinMultiplier;
   }
   return true;
}

// Filtre: spike trop rapide (utilisé avant d'entrer)
bool IsSpikeTooFast(double currentPrice)
{
   if(!UseSpikeSpeedFilter) return false;

   datetime now = TimeCurrent();
   if(prevSpeedTime == 0 || prevSpeedPrice <= 0.0)
   {
      prevSpeedTime  = now;
      prevSpeedPrice = currentPrice;
      return false;
   }

   double dtMin = (now - prevSpeedTime) / 60.0;
   if(dtMin <= 0.0)
      return false;

   double dpPoints = MathAbs(currentPrice - prevSpeedPrice) / _Point;
   double speed    = dpPoints / dtMin; // points / minute

   prevSpeedTime  = now;
   prevSpeedPrice = currentPrice;

   return (speed >= SpikeSpeedMinPoints);
}

// Fermeture partielle simple
void PartialClose(ulong ticket, double ratio)
{
   if(!UsePartialClose || ratio <= 0.0 || ratio >= 1.0) return;
   if(!PositionSelectByTicket(ticket)) return;

   double vol = PositionGetDouble(POSITION_VOLUME);
   double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double closeVol = vol * ratio;
   // Ajuster au pas et au min
   closeVol = MathMax(minVol, MathFloor(closeVol/step)*step);
   if(closeVol < minVol || closeVol >= vol) return;

   if(!trade.PositionClosePartial(ticket, closeVol))
      LogError("PartialClose échoué, retcode=" + IntegerToString(trade.ResultRetcode()));
}

// Affiche tous les indicateurs techniques sur le graphique
void AttachChartIndicators()
{
   // Créer les EMA sur le graphique
   string fastEmaName = "EMA" + IntegerToString(EMA_Fast);
   string slowEmaName = "EMA" + IntegerToString(EMA_Slow);
   
   // Supprimer les anciennes EMA si elles existent
   if(ObjectFind(0, fastEmaName) >= 0) ObjectDelete(0, fastEmaName);
   if(ObjectFind(0, slowEmaName) >= 0) ObjectDelete(0, slowEmaName);
   
   // Créer l'EMA rapide avec rendu courbe
   if(ObjectCreate(0, fastEmaName, OBJ_TRENDBYANGLE, 0, 0, 0))
   {
      ObjectSetInteger(0, fastEmaName, OBJPROP_COLOR, EMA_Fast_Color);
      ObjectSetInteger(0, fastEmaName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, fastEmaName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, fastEmaName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, fastEmaName, OBJPROP_BACK, false);
      ObjectSetInteger(0, fastEmaName, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, fastEmaName, OBJPROP_TOOLTIP, "EMA " + IntegerToString(EMA_Fast));
      
      // Mettre à jour la position de l'EMA rapide
      int emaFastHandleLocal = iMA(_Symbol, PERIOD_CURRENT, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
      double emaFast[1];
      if (CopyBuffer(emaFastHandleLocal, 0, 0, 1, emaFast) > 0) {
         ObjectSetDouble(0, fastEmaName, OBJPROP_PRICE, 0, emaFast[0]);
         ObjectSetDouble(0, fastEmaName, OBJPROP_PRICE, 1, emaFast[0]);
         ObjectSetInteger(0, fastEmaName, OBJPROP_TIME, 0, TimeCurrent() - PeriodSeconds() * 10);
         ObjectSetInteger(0, fastEmaName, OBJPROP_TIME, 1, TimeCurrent() + PeriodSeconds() * 10);
      }
   }
   
   // Créer l'EMA lente avec rendu courbe
   if(ObjectCreate(0, slowEmaName, OBJ_TRENDBYANGLE, 0, 0, 0))
   {
      ObjectSetInteger(0, slowEmaName, OBJPROP_COLOR, EMA_Slow_Color);
      ObjectSetInteger(0, slowEmaName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, slowEmaName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, slowEmaName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, slowEmaName, OBJPROP_BACK, false);
      ObjectSetInteger(0, slowEmaName, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, slowEmaName, OBJPROP_TOOLTIP, "EMA " + IntegerToString(EMA_Slow));
      
      // Mettre à jour la position de l'EMA lente
      int emaSlowHandleLocal = iMA(_Symbol, PERIOD_CURRENT, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
      double emaSlow[1];
      if (CopyBuffer(emaSlowHandleLocal, 0, 0, 1, emaSlow) > 0) {
         ObjectSetDouble(0, slowEmaName, OBJPROP_PRICE, 0, emaSlow[0]);
         ObjectSetDouble(0, slowEmaName, OBJPROP_PRICE, 1, emaSlow[0]);
         ObjectSetInteger(0, slowEmaName, OBJPROP_TIME, 0, TimeCurrent() - PeriodSeconds() * 10);
         ObjectSetInteger(0, slowEmaName, OBJPROP_TIME, 1, TimeCurrent() + PeriodSeconds() * 10);
      }
   }
   
   // Mettre à jour l'affichage
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Analyze multiple timeframes for trading signals                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Vérifie si le prix est proche d'un niveau de support/résistance  |
//+------------------------------------------------------------------+
bool IsNearKeyLevel(double price, double atr, double &level, double tolerance = 0.3)
{
   // Récupérer les points de données historiques pour les supports/résistances
   double highs[], lows[], closes[];
   ArraySetAsSeries(highs, true);
   ArraySetAsSeries(lows, true);
   ArraySetAsSeries(closes, true);
   
   // Récupérer les données des chandeliers
   if(CopyHigh(_Symbol, PERIOD_M5, 0, 50, highs) <= 0 || 
      CopyLow(_Symbol, PERIOD_M5, 0, 50, lows) <= 0 ||
      CopyClose(_Symbol, PERIOD_M5, 0, 50, closes) <= 0)
   {
      Print("Erreur lors de la récupération des données historiques");
      return false;
   }
   
   // Vérifier les niveaux de support (bas des chandeliers)
   for(int i = 1; i < 10; i++)
   {
      if(MathAbs(price - lows[i]) < atr * tolerance)
      {
         level = lows[i];
         return true;
      }
   }
   
   // Vérifier les niveaux de résistance (hauts des chandeliers)
   for(int i = 1; i < 10; i++)
   {
      if(MathAbs(price - highs[i]) < atr * tolerance)
      {
         level = highs[i];
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si le prix a rebondi sur un niveau clé                   |
//+------------------------------------------------------------------+
bool IsPriceBouncing(double currentPrice, double emaFast, double emaSlow, double atr, double &bounceLevel)
{
   // Vérifier si on est dans une tendance haussière
   if(emaFast > emaSlow)
   {
      // Vérifier si le prix est proche d'un niveau de support
      double supportLevel = emaSlow - (atr * 0.5);
      if(currentPrice <= emaSlow && currentPrice >= supportLevel)
      {
         bounceLevel = supportLevel;
         return true;
      }
   }
   // Vérifier si on est dans une tendance baissière
   else if(emaFast < emaSlow)
   {
      // Vérifier si le prix est proche d'un niveau de résistance
      double resistanceLevel = emaSlow + (atr * 0.5);
      if(currentPrice >= emaSlow && currentPrice <= resistanceLevel)
      {
         bounceLevel = resistanceLevel;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Analyse les signaux multi-timeframe avec vérification des rebonds |
//+------------------------------------------------------------------+
SMultiTimeframeAnalysis AnalyzeMultiTimeframeSignals(void)
{
   SMultiTimeframeAnalysis analysis;
   
   // Récupérer les valeurs des indicateurs H1
   double h1_ema_fast_val[3], h1_ema_slow_val[3], h1_atr_val[3];
   double m5_ema_fast_val[3], m5_ema_slow_val[3], m5_atr_val[3];
   
   // Récupérer les valeurs des moyennes mobiles H1 (3 dernières bougies)
   if(CopyBuffer(h1_ema_fast_handle, 0, 0, 3, h1_ema_fast_val) <= 0 ||
      CopyBuffer(h1_ema_slow_handle, 0, 0, 3, h1_ema_slow_val) <= 0 ||
      CopyBuffer(h1_atr_handle, 0, 0, 3, h1_atr_val) <= 0)
   {
      analysis.reason = "Erreur lors de la récupération des indicateurs H1";
      return analysis;
   }
   
   // Récupérer les valeurs des moyennes mobiles M5 (3 dernières bougies)
   if(CopyBuffer(m5_ema_fast_handle, 0, 0, 3, m5_ema_fast_val) <= 0 ||
      CopyBuffer(m5_ema_slow_handle, 0, 0, 3, m5_ema_slow_val) <= 0 ||
      CopyBuffer(m5_atr_handle, 0, 0, 3, m5_atr_val) <= 0)
   {
      analysis.reason = "Erreur lors de la récupération des indicateurs M5";
      return analysis;
   }
   
   // Récupérer le prix actuel et les prix des bougies précédentes
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M5, 0, 5, rates) <= 0)
   {
      analysis.reason = "Erreur lors de la récupération des prix";
      return analysis;
   }
   
   double current_price = rates[0].close;
   double previous_close = rates[1].close;
   double previous_low = rates[1].low;
   double previous_high = rates[1].high;
   
   // Déterminer la tendance H1
   analysis.h1_trend = (h1_ema_fast_val[0] > h1_ema_slow_val[0]) ? TREND_UP : 
                      (h1_ema_fast_val[0] < h1_ema_slow_val[0]) ? TREND_DOWN : TREND_NEUTRAL;
   
   // Déterminer la tendance M5
   analysis.m5_trend = (m5_ema_fast_val[0] > m5_ema_slow_val[0]) ? TREND_UP : 
                      (m5_ema_fast_val[0] < m5_ema_slow_val[0]) ? TREND_DOWN : TREND_NEUTRAL;
   
   // Stocker les valeurs des indicateurs
   analysis.h1_ema_fast = h1_ema_fast_val[0];
   analysis.h1_ema_slow = h1_ema_slow_val[0];
   analysis.h1_atr = h1_atr_val[0];
   analysis.m5_ema_fast = m5_ema_fast_val[0];
   analysis.m5_ema_slow = m5_ema_slow_val[0];
   analysis.m5_atr = m5_atr_val[0];
   
   // Calculer les niveaux de support/résistance
   analysis.h1_support = current_price - h1_atr_val[0];
   analysis.h1_resistance = current_price + h1_atr_val[0];
   analysis.m5_support = current_price - m5_atr_val[0];
   analysis.m5_resistance = current_price + m5_atr_val[0];
   
   // Vérifier si on est proche d'un niveau clé
   double keyLevel = 0;
   bool isNearKeyLevel = IsNearKeyLevel(current_price, m5_atr_val[0], keyLevel);
   
   // Vérifier si le prix a rebondi sur un niveau clé
   double bounceLevel = 0;
   bool hasBounced = IsPriceBouncing(current_price, m5_ema_fast_val[0], m5_ema_slow_val[0], m5_atr_val[0], bounceLevel);
   
   // Logique de décision améliorée avec vérification des rebonds
   if(analysis.h1_trend == TREND_UP && analysis.m5_trend == TREND_UP)
   {
      // Vérifier les conditions d'achat avec rebond
      if(hasBounced && current_price > previous_close && current_price > rates[0].open)
      {
         analysis.decision = "BUY";
         analysis.reason = "Rebond haussier confirmé sur niveau clé ";
         if(isNearKeyLevel) analysis.reason += StringFormat(" (Niveau: %.5f)", keyLevel);
         
         // Ajuster les niveaux de stop loss et take profit
         analysis.entry_price = current_price;
         analysis.stop_loss = MathMin(current_price - (1.5 * m5_atr_val[0]), rates[0].low);
         analysis.take_profit = current_price + (3 * m5_atr_val[0]);
         analysis.risk_reward_ratio = 2.0;
         analysis.confidence = 0.85;
      }
      else
      {
         analysis.decision = "HOLD";
         analysis.reason = "Tendance haussière mais pas de rebond confirmé";
         analysis.confidence = 0.4;
      }
   }
   else if(analysis.h1_trend == TREND_DOWN && analysis.m5_trend == TREND_DOWN)
   {
      // Vérifier les conditions de vente avec rebond
      if(hasBounced && current_price < previous_close && current_price < rates[0].open)
      {
         analysis.decision = "SELL";
         analysis.reason = "Rebond baissier confirmé sur niveau clé ";
         if(isNearKeyLevel) analysis.reason += StringFormat(" (Niveau: %.5f)", keyLevel);
         
         // Ajuster les niveaux de stop loss et take profit
         analysis.entry_price = current_price;
         analysis.stop_loss = MathMax(current_price + (1.5 * m5_atr_val[0]), rates[0].high);
         analysis.take_profit = current_price - (3 * m5_atr_val[0]);
         analysis.risk_reward_ratio = 2.0;
         analysis.confidence = 0.85;
      }
      else
      {
         analysis.decision = "HOLD";
         analysis.reason = "Tendance baissière mais pas de rebond confirmé";
         analysis.confidence = 0.4;
      }
   }
   else
   {
      analysis.decision = "HOLD";
      analysis.reason = "Pas de tendance claire ou de configuration de trading favorable";
      analysis.confidence = 0.2;
   }
   
   // Journalisation des décisions
   if(analysis.decision != "HOLD")
   {
      Print("Signal ", analysis.decision, " - ", analysis.reason, 
            " | Entrée: ", DoubleToString(analysis.entry_price, _Digits),
            " SL: ", DoubleToString(analysis.stop_loss, _Digits),
            " TP: ", DoubleToString(analysis.take_profit, _Digits));
   }

   return analysis;
}


//+------------------------------------------------------------------+
//| ONINIT - Fonction d'initialisation de l'expert advisor            |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialisation des indicateurs de base
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   emaFastHandle = iMA(_Symbol, TF_Trend, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowHandle = iMA(_Symbol, TF_Trend, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   emaFastEntryHandle = iMA(_Symbol, TF_Entry, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowEntryHandle = iMA(_Symbol, TF_Entry, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   emaScalpEntryHandle = iMA(_Symbol, TF_Entry, EMA_Scalp_M1, 0, MODE_EMA, PRICE_CLOSE);
   emaFastQuickHandle = iMA(_Symbol, PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowQuickHandle = iMA(_Symbol, PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   // Supertrend M5
   stHandle = iCustom(_Symbol, PERIOD_M5, "SuperTrend", ST_Period, ST_Multiplier);
   if(stHandle == INVALID_HANDLE)
      Print("Erreur création handle Supertrend");

   // EMA multi-timeframe pour Forex / Volatilités : M5 / H1
   emaFastM4Handle = iMA(_Symbol, PERIOD_M4, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM4Handle = iMA(_Symbol, PERIOD_M4, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   emaFastM15Handle = iMA(_Symbol, PERIOD_M15, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM15Handle = iMA(_Symbol, PERIOD_M15, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   emaFastM5Handle = iMA(_Symbol, PERIOD_M5, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM5Handle = iMA(_Symbol, PERIOD_M5, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   // Initialisation des handles pour l'analyse multi-timeframe H1 et M5
   h1_ema_fast_handle = iMA(_Symbol, PERIOD_H1, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   h1_ema_slow_handle = iMA(_Symbol, PERIOD_H1, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   h1_atr_handle = iATR(_Symbol, PERIOD_H1, ATR_Period);
   m5_ema_fast_handle = iMA(_Symbol, PERIOD_M5, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   m5_ema_slow_handle = iMA(_Symbol, PERIOD_M5, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   m5_atr_handle = iATR(_Symbol, PERIOD_M5, ATR_Period);

   // Indicateurs de base obligatoires
   if(rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE || 
      emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE ||
      emaScalpEntryHandle == INVALID_HANDLE ||
      emaFastM4Handle == INVALID_HANDLE || emaSlowM4Handle == INVALID_HANDLE ||
      emaFastM15Handle == INVALID_HANDLE || emaSlowM15Handle == INVALID_HANDLE ||
      emaFastM5Handle == INVALID_HANDLE || emaSlowM5Handle == INVALID_HANDLE ||
      h1_ema_fast_handle == INVALID_HANDLE || h1_ema_slow_handle == INVALID_HANDLE ||
      h1_atr_handle == INVALID_HANDLE || m5_ema_fast_handle == INVALID_HANDLE ||
      m5_ema_slow_handle == INVALID_HANDLE || m5_atr_handle == INVALID_HANDLE)
   {
      Print("Erreur création indicateurs de base (RSI/ATR/MA)");
      return INIT_FAILED;
   }

   // Vérifier EMA rapides M1 (9/21)
   if(emaFastQuickHandle == INVALID_HANDLE || emaSlowQuickHandle == INVALID_HANDLE)
   {
      Print("Erreur création EMA rapides M1 (9/21)");
      return INIT_FAILED;
   }
   
   // Initialisation des indicateurs multi-timeframe
   InitMultiTimeframeIndicators();

   // Sauvegarder le capital de départ pour le suivi du drawdown
   accountStartBalance = AccountInfoDouble(ACCOUNT_EQUITY);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);
   
   // Vérification WebRequest pour l'IA
   if(UseAI_Agent && StringLen(AI_ServerURL) > 0)
   {
      // Extraire le domaine de l'URL pour vérifier s'il est autorisé
      string urlDomain = AI_ServerURL;
      int protocolPos = StringFind(urlDomain, "://");
      if(protocolPos >= 0)
      {
         urlDomain = StringSubstr(urlDomain, protocolPos + 3);
         int pathPos = StringFind(urlDomain, "/");
         if(pathPos >= 0)
            urlDomain = StringSubstr(urlDomain, 0, pathPos);
      }
      
      Print("========================================");
      Print("CONFIGURATION IA:");
      Print("URL Serveur: ", AI_ServerURL);
      Print("IMPORTANT: Assurez-vous que l'URL suivante est autorisée dans MT5:");
      Print("  Outils -> Options -> Expert Advisors -> Autoriser les WebRequest pour:");
      Print("  ", urlDomain);
      Print("  OU ajoutez: http://127.0.0.1");
      Print("========================================");
   }
   
   // Afficher les limites de volume et positions
   Print("========================================");
   Print("LIMITES DE TRADING:");
   Print("  - Forex: Maximum 0.01 lot");
   Print("  - Indices (Boom/Crash/Volatility): Maximum 0.5 lot");
   Print("  - Maximum 2 positions ouvertes simultanément");
   Print("  - Les autres signaux seront placés en ordres limit");
   Print("========================================");
   
   Comment("F_INX_robot4 v2 Running...");
   // Init SMC OB (ne bloque pas le robot en cas d'échec)
   if(!SMC_Init())
      Print("SMC_OB: init partielle (handles manquants), le filtre SMC sera ignoré si indisponible");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| ONTICK - Fonction principale appelée à chaque tick              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Réinitialiser les erreurs API toutes les 30 secondes pour éviter le blocage
   static datetime lastReset = 0;
   if(TimeCurrent() - lastReset >= 30) {
      ResetAPIErrors();
      lastReset = TimeCurrent();
   }
   
   // Gérer les positions ouvertes (trailing stop, break even, etc.)
   ManageTrade();
   
   // Gérer les trailing stops pour sécuriser les gains
   ManageTrailingStops();
   
   // Mettre à jour les supports/résistances toutes les 5 secondes
   static datetime lastSRUpdate = 0;
   if(TimeCurrent() - lastSRUpdate >= 5) {
      DrawSupportResistance();
      lastSRUpdate = TimeCurrent();
   }
   
   // Exécuter l'analyse multi-timeframe toutes les 5 secondes
   static datetime lastMtfAnalysis = 0;
   if(TimeCurrent() - lastMtfAnalysis >= 5) {
      SMultiTimeframeAnalysis mtfAnalysis = AnalyzeMultiTimeframeSignals();
      lastMtfAnalysis = TimeCurrent();
      
      // Utiliser l'analyse pour prendre des décisions de trading
      if(mtfAnalysis.confidence > 0.7) { // Seulement si la confiance est élevée
         if(mtfAnalysis.decision == "BUY" && CountPositionsForSymbolMagic() == 0) {
            double lot = FixedLotSize;
            if(lot > 0) {
               ExecuteTradeWithATR(ORDER_TYPE_BUY, lot, mtfAnalysis.entry_price, "MTF_BUY", mtfAnalysis.confidence);
            }
         }
         else if(mtfAnalysis.decision == "SELL" && CountPositionsForSymbolMagic() == 0) {
            double lot = FixedLotSize;
            if(lot > 0) {
               ExecuteTradeWithATR(ORDER_TYPE_SELL, lot, mtfAnalysis.entry_price, "MTF_SELL", mtfAnalysis.confidence);
            }
         }
      }
   }
   
   // Si l'IA est activée, envoyer une requête périodiquement
   if(UseAI_Agent && StringLen(AI_ServerURL) > 0)
   {
      static datetime lastAIRequest = 0;
      static int aiRequestInterval = 15; // Envoyer une requête toutes les 15 secondes (réduit de 5s pour éviter les requêtes trop fréquentes)
      
      // Vérifier si assez de temps s'est écoulé depuis la dernière requête
      if(TimeCurrent() - lastAIRequest >= aiRequestInterval)
      {
         // Récupérer les données des indicateurs
         double rsi[], atr[], emaFastH1[], emaSlowH1[], emaFastM1[], emaSlowM1[];
         
         if(CopyBuffer(rsiHandle, 0, 0, 1, rsi) > 0 &&
            CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 &&
            CopyBuffer(emaFastHandle, 0, 0, 1, emaFastH1) > 0 &&
            CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlowH1) > 0 &&
            CopyBuffer(emaFastEntryHandle, 0, 0, 1, emaFastM1) > 0 &&
            CopyBuffer(emaSlowEntryHandle, 0, 0, 1, emaSlowM1) > 0)
         {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            // Déterminer les règles de direction selon le symbole
            int dirRule = AllowedDirectionFromSymbol(_Symbol);
            bool spikeMode = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
            
            // Appeler l'IA pour obtenir une décision (sans capture d'écran)
            int aiDecision = AI_GetDecision(rsi[0], atr[0],
                                           emaFastH1[0], emaSlowH1[0],
                                           emaFastM1[0], emaSlowM1[0],
                                           ask, bid,
                                           dirRule, spikeMode);
            
            // Mettre à jour le timestamp de la dernière requête
            lastAIRequest = TimeCurrent();
            
            // Appliquer un filtre de zones extrêmes à la décision IA (éviter BUY en pleine SELL zone, etc.)
            double midPrice = (ask + bid) / 2.0;
            if(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
               midPrice >= g_aiSellZoneLow && midPrice <= g_aiSellZoneHigh)
            {
               // Prix dans la SELL zone -> neutraliser les signaux BUY trop agressifs
               string actUpper = g_lastAIAction;
               StringToUpper(actUpper);
               if(actUpper == "BUY" || actUpper == "ACHAT")
               {
                  g_lastAIAction = "hold";
                  if(g_lastAIConfidence > 0.5) g_lastAIConfidence = 0.5;
                  g_lastAIReason = "Prix dans zone VENTE IA - BUY neutralisé";
               }
            }
            else if(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
                    midPrice >= g_aiBuyZoneLow && midPrice <= g_aiBuyZoneHigh)
            {
               // Prix dans la BUY zone -> neutraliser les signaux SELL agressifs
               string actUpper2 = g_lastAIAction;
               StringToUpper(actUpper2);
               if(actUpper2 == "SELL" || actUpper2 == "VENTE")
               {
                  g_lastAIAction = "hold";
                  if(g_lastAIConfidence > 0.5) g_lastAIConfidence = 0.5;
                  g_lastAIReason = "Prix dans zone ACHAT IA - SELL neutralisé";
               }
            }

            // Afficher la décision IA si disponible
            if(DebugBlocks && g_lastAIAction != "")
            {
               Print("IA Decision: ", g_lastAIAction, " (Confiance: ", DoubleToString(g_lastAIConfidence, 2), ") - ", g_lastAIReason);
            }

            // Affichage sur le graphique de la décision IA (action / confiance / raison)
            if(g_lastAIAction != "")
            {
               DrawAIRecommendation(g_lastAIAction, g_lastAIConfidence, g_lastAIReason, ask);
            }
            
            // Traiter la décision IA pour exécuter les trades automatiquement
            if(g_lastAIAction != "" && g_lastAIConfidence >= AI_MinConfidence)
            {
               AI_ProcessSignal(g_lastAIAction, g_lastAIConfidence, g_lastAIReason);
            }
            
            // Afficher l'alerte de spike si prédit
            if(g_aiSpikePredicted)
            {
               DisplaySpikeAlert();
            }
         }
      }
   }
   
   // Mettre à jour l'affichage clignotant des alertes de spike
   UpdateSpikeAlertDisplay();
   
   // Fermeture automatique des positions spike après le mouvement
   CloseSpikePositionAfterMove();
   
   DrawAIZones();
   CheckAIZoneAlerts();

   // Détection Boom/Crash pour activer la variante spéciale de scalp de zone
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);

   if(UseAIZoneBounceStrategy)
   {
      // Sur Boom/Crash, si activé, on utilise une logique plus agressive:
      // tout rebond propre dans la zone BUY/SELL ouvre un scalp avec TP fixe.
      if(isBoomCrashSymbol && UseBoomCrashZoneScalps)
         EvaluateBoomCrashZoneScalps();
      else
      EvaluateAIZoneBounceStrategy();
   }
   SendAISummaryIfDue();
   // Vérifier les trades bypass cooldown fermés et durcir le cooldown si perte
   CheckBypassCooldownTrades();
   // Rafraîchir périodiquement la structure H1 (trendlines, ETE) et la tracer
   AI_UpdateAnalysis();
   // Vérifier les touches de trendlines/supports/résistances et trader automatiquement
   CheckAITrendlineTouchAndTrade();
   // Signaux basiques EMA + Zones
   CheckBasicEmaSignals();

   // Rafraîchir les zones SMC sur le graphique (~10s)
   static datetime lastSmcZoneUpdate = 0;
   if(TimeCurrent() - lastSmcZoneUpdate >= 10)
   {
      lastSmcZoneUpdate = TimeCurrent();
      SMC_UpdateZones();
   }

   // Mise à jour périodique des fenêtres horaires + affichage mini bas-gauche
   AI_UpdateTimeWindows();
   DrawTimeWindowsPanel();

   // Entrées autonomes SMC (optionnel, non bloquant)
   if(Use_SMC_OB_Entries && IsTradingTimeAllowed() && !IsDrawdownExceeded() && CountPositionsForSymbolMagic() == 0)
   {
      static datetime lastSmcEntryCheck = 0;
      if(TimeCurrent() - lastSmcEntryCheck >= 10) // throttle 10s
      {
         lastSmcEntryCheck = TimeCurrent();
         bool smcIsBuy = false;
         double smcEntry = 0, smcSL = 0, smcTP = 0, smcAtr = 0;
         string smcReason = "";
         if(SMC_GenerateSignal(smcIsBuy, smcEntry, smcSL, smcTP, smcReason, smcAtr))
         {
            ENUM_ORDER_TYPE orderType = smcIsBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            double price = smcIsBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
            string comment = "SMC_OB";
            if(StringLen(smcReason) > 0) comment += "_" + smcReason;
            ExecuteTradeWithATR(orderType, smcAtr, price, comment, 1.0, false);
         }
      }
   }

   // Scalp EMA50 sur mouvement en cours (après rebond / cassure zones IA)
   // Désactivé pour Boom/Crash quand la variante spéciale de scalp de zone est active,
   // afin d'éviter des doublons de trades.
   if(UseAIZoneBounceStrategy && AI_AutoExecuteTrades)
   {
      if(!(isBoomCrashSymbol && UseBoomCrashZoneScalps))
      EvaluateAIZoneEMAScalps();
   }
}

//+------------------------------------------------------------------+
//| Get allowed trading direction based on symbol name               |
//+------------------------------------------------------------------+
// La fonction AllowedDirectionFromSymbol est définie plus bas dans le fichier

// La fonction AI_GetDecision est définie plus bas dans le fichier

//+------------------------------------------------------------------+
//| Structure pour stocker les tendances multi-timeframe               |
//+------------------------------------------------------------------+
struct TrendAnalysis
{
   double h1_confidence;
   string h1_direction;
   bool is_valid;
};

//+------------------------------------------------------------------+
//| Réinitialiser les compteurs d'erreurs API                       |
//+------------------------------------------------------------------+
void ResetAPIErrors()
{
   g_resetAPIErrors = true;
   Print("🔄 Demande de réinitialisation des erreurs API");
}

//+------------------------------------------------------------------+
//| Analyse les tendances multi-timeframe depuis l'endpoint /trend      |
//+------------------------------------------------------------------+
TrendAnalysis GetMultiTimeframeTrendAnalysis()
{
   static datetime lastErrorTime = 0;
   static int consecutiveErrors = 0;
   const int MAX_CONSECUTIVE_ERRORS = 3;
   const int ERROR_COOLDOWN = 300; // 5 minutes en secondes
   
   TrendAnalysis analysisResult = {0.0, "", false};
   
   // Si trop d'erreurs consécutives, retourner neutre pour éviter de surcharger
   if(consecutiveErrors > 5 && (TimeCurrent() - lastErrorTime) < 300)
   {
      if(DebugBlocks)
         Print(" API trend en pause (trop d'erreurs), retour neutre");
      analysisResult.h1_direction = "neutral";
      analysisResult.h1_confidence = 50.0;
      analysisResult.is_valid = true;
      return analysisResult;
   }
   
   // Réinitialiser le compteur si 5 minutes se sont écoulées OU si demandé
   if((TimeCurrent() - lastErrorTime) > 300 || consecutiveErrors > 3 || g_resetAPIErrors)
   {
      consecutiveErrors = 0;
      lastErrorTime = 0;
      g_resetAPIErrors = false;
      if(DebugBlocks && consecutiveErrors > 3)
         Print(" Réinitialisation forcée des erreurs API");
   }
   
   // Construire l'URL avec les paramètres dans la query string
   string serverURL = StringFormat("http://127.0.0.1:8000/trend?symbol=%s&timeframe=H1", _Symbol);
   uchar response_data[];
   string response_headers;
   
   // Envoyer une requête GET avec les paramètres dans l'URL
   uchar data[];
   int res = WebRequest("GET", serverURL, "", 10000, data, response_data, response_headers);
   string response = CharArrayToString(response_data);
   
   if(res == 200)
   {
      // Extraire la tendance H1 et sa confiance
      int h1Pos = StringFind(response, "\"H1\"");
      if(h1Pos >= 0)
      {
         int dirPos = StringFind(response, "\"direction\"", h1Pos);
         if(dirPos >= 0)
         {
            int colon = StringFind(response, ":", dirPos);
            if(colon > 0)
            {
               int endPos = StringFind(response, ",", colon);
               if(endPos < 0) endPos = StringFind(response, "}", colon);
               if(endPos > colon)
               {
                  string dir = StringSubstr(response, colon + 1, endPos - colon - 1);
                  StringTrimLeft(dir);
                  StringTrimRight(dir);
                  analysisResult.h1_direction = dir;
               }
            }
         }
         
         int confPos = StringFind(response, "\"confidence\"", h1Pos);
         if(confPos >= 0)
         {
            int colon = StringFind(response, ":", confPos);
            if(colon > 0)
            {
               int endPos = StringFind(response, ",", colon);
               if(endPos < 0) endPos = StringFind(response, "}", colon);
               if(endPos > colon)
               {
                  string confStr = StringSubstr(response, colon+1, endPos-colon-1);
                  analysisResult.h1_confidence = StringToDouble(confStr);
               }
            }
         }
         
         analysisResult.is_valid = (analysisResult.h1_confidence > 0.0 && StringLen(analysisResult.h1_direction) > 0);
         
         if(analysisResult.is_valid)
         {
            consecutiveErrors = 0; // Réinitialiser en cas de succès
            if(DebugBlocks)
               Print(" Analyse tendance H1: ", analysisResult.h1_direction, " (confiance: ", analysisResult.h1_confidence, "%)");
         }
      }
   }
   else
   {
      consecutiveErrors++;
      lastErrorTime = TimeCurrent();
      Print(" Erreur appel API trend: ", res, " (erreurs consécutives: ", consecutiveErrors, ")");
      
      // En cas d'erreur, retourner une tendance neutre pour éviter de bloquer les trades
      analysisResult.h1_direction = "neutral";
      analysisResult.h1_confidence = 50.0;
      analysisResult.is_valid = true;
   }
   
   return analysisResult;
}

//+------------------------------------------------------------------+
//| Validation avancée avec Fibonacci, EMA et IA                     |
//+------------------------------------------------------------------+
bool ValidateAdvancedEntry(ENUM_ORDER_TYPE orderType, double price)
{
   // 1. Validation avec niveaux de Fibonacci
   if(UseFibonacciLevels)
   {
      if(!ValidateFibonacciLevels(orderType, price))
      {
         if(DebugBlocks)
            Print("🚫 Entrée refusée : Niveaux Fibonacci non valides");
         return false;
      }
   }
   
   // 2. Confirmation avec EMA
   if(UseEMAConfirmation)
   {
      if(!ValidateEMAConfirmation(orderType))
      {
         if(DebugBlocks)
            Print("🚫 Entrée refusée : Confirmation EMA négative");
         return false;
      }
   }
   
   // 3. Confirmation avec IA
   if(UseIAConfirmation)
   {
      if(!ValidateIAConfirmation(orderType))
      {
         if(DebugBlocks)
            Print("🚫 Entrée refusée : Confirmation IA négative");
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Validation des niveaux de Fibonacci                             |
//+------------------------------------------------------------------+
bool ValidateFibonacciLevels(ENUM_ORDER_TYPE orderType, double price)
{
   // Récupérer les données de prix pour calculer les niveaux de Fibonacci
   MqlRates rates[];
   int copied = CopyRates(_Symbol, PERIOD_H1, 0, 100, rates);
   if(copied < 50)
   {
      if(DebugBlocks)
         Print("⚠️ Données insuffisantes pour calcul Fibonacci");
      return true; // Autoriser si pas assez de données
   }
   
   // Trouver le plus haut et le plus bas récents
   double highest = rates[0].high;
   double lowest = rates[0].low;
   int highestBar = 0;
   int lowestBar = 0;
   
   for(int i = 1; i < copied; i++)
   {
      if(rates[i].high > highest)
      {
         highest = rates[i].high;
         highestBar = i;
      }
      if(rates[i].low < lowest)
      {
         lowest = rates[i].low;
         lowestBar = i;
      }
   }
   
   // Calculer les niveaux de Fibonacci
   double diff = highest - lowest;
   double fib236 = lowest + diff * 0.236;
   double fib382 = lowest + diff * 0.382;
   double fib500 = lowest + diff * 0.500;
   double fib618 = lowest + diff * 0.618;
   double fib786 = lowest + diff * 0.786;
   
   // Vérifier si le prix actuel est près d'un niveau de Fibonacci important
   double tolerance = diff * 0.01; // 1% de tolérance
   
   bool nearFibLevel = false;
   string fibLevel = "";
   
   if(MathAbs(price - fib236) <= tolerance) { nearFibLevel = true; fibLevel = "23.6%"; }
   if(MathAbs(price - fib382) <= tolerance) { nearFibLevel = true; fibLevel = "38.2%"; }
   if(MathAbs(price - fib500) <= tolerance) { nearFibLevel = true; fibLevel = "50.0%"; }
   if(MathAbs(price - fib618) <= tolerance) { nearFibLevel = true; fibLevel = "61.8%"; }
   if(MathAbs(price - fib786) <= tolerance) { nearFibLevel = true; fibLevel = "78.6%"; }
   
   if(nearFibLevel)
   {
      if(DebugBlocks)
         Print("✅ Prix près du niveau Fibonacci ", fibLevel, " (", DoubleToString(price, _Digits), ")");
      return true;
   }
   
   // Si pas près d'un niveau, vérifier si le prix est dans une zone favorable
   if(orderType == ORDER_TYPE_BUY)
   {
      // Pour BUY: chercher un support Fibonacci
      if(price >= fib382 && price <= fib618)
      {
         if(DebugBlocks)
            Print("✅ BUY dans zone support Fibonacci (38.2%-61.8%)");
         return true;
      }
      
      // Zones plus larges pour plus de flexibilité
      if(price >= fib236 && price <= fib786)
      {
         if(DebugBlocks)
            Print("✅ BUY dans zone élargie Fibonacci (23.6%-78.6%)");
         return true;
      }
   }
   else // SELL
   {
      // Pour SELL: chercher une résistance Fibonacci
      if(price >= fib382 && price <= fib618)
      {
         if(DebugBlocks)
            Print("✅ SELL dans zone résistance Fibonacci (38.2%-61.8%)");
         return true;
      }
      
      // Zones plus larges pour plus de flexibilité
      if(price >= fib236 && price <= fib786)
      {
         if(DebugBlocks)
            Print("✅ SELL dans zone élargie Fibonacci (23.6%-78.6%)");
         return true;
      }
   }
   
   // Si vraiment pas dans une zone Fibonacci, autoriser quand même avec un avertissement
   if(DebugBlocks)
      Print("⚠️ Prix hors zones Fibonacci mais autorisé (price: ", DoubleToString(price, _Digits), ")");
   return true; // Autoriser pour éviter de bloquer les trades
}

//+------------------------------------------------------------------+
//| Confirmation avec EMA                                            |
//+------------------------------------------------------------------+
bool ValidateEMAConfirmation(ENUM_ORDER_TYPE orderType)
{
   double emaFast[], emaSlow[];
   
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFast) < 2 ||
      CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlow) < 2)
   {
      if(DebugBlocks)
         Print("⚠️ Données EMA insuffisantes");
      return true; // Autoriser si pas assez de données
   }
   
   // Vérifier l'alignement des EMA
   bool emaBullish = (emaFast[0] > emaSlow[0] && emaFast[1] > emaSlow[1]);
   bool emaBearish = (emaFast[0] < emaSlow[0] && emaFast[1] < emaSlow[1]);
   
   // Vérifier la pente des EMA
   double emaFastSlope = emaFast[0] - emaFast[1];
   double emaSlowSlope = emaSlow[0] - emaSlow[1];
   
   if(orderType == ORDER_TYPE_BUY)
   {
      if(emaBullish && emaFastSlope > 0 && emaSlowSlope > 0)
      {
         if(DebugBlocks)
            Print("✅ Confirmation EMA BUY: EMA alignées haussières");
         return true;
      }
      else if(emaBullish)
      {
         if(DebugBlocks)
            Print("⚠️ EMA BUY partiellement validé (pente faible)");
         return true; // Autoriser quand même mais avec avertissement
      }
   }
   else // SELL
   {
      if(emaBearish && emaFastSlope < 0 && emaSlowSlope < 0)
      {
         if(DebugBlocks)
            Print("✅ Confirmation EMA SELL: EMA alignées baissières");
         return true;
      }
      else if(emaBearish)
      {
         if(DebugBlocks)
            Print("⚠️ EMA SELL partiellement validé (pente faible)");
         return true; // Autoriser quand même mais avec avertissement
      }
   }
   
   return false; // Refuser si EMA ne confirment pas
}

//+------------------------------------------------------------------+
//| Confirmation avec IA                                             |
//+------------------------------------------------------------------+
bool ValidateIAConfirmation(ENUM_ORDER_TYPE orderType)
{
   if(!UseAI_Agent || StringLen(g_lastAIAction) == 0)
   {
      if(DebugBlocks)
         Print("⚠️ IA non disponible ou pas de décision récente");
      return true; // Autoriser si IA pas disponible
   }
   
   // Vérifier si la décision IA est récente (moins de 30 secondes)
   if(TimeCurrent() - g_lastAITime > 30)
   {
      if(DebugBlocks)
         Print("⚠️ Décision IA trop ancienne (", TimeCurrent() - g_lastAITime, "s)");
      return true; // Autoriser si décision trop ancienne
   }
   
   // Vérifier la confiance IA
   if(g_lastAIConfidence < AI_MinConfidence)
   {
      if(DebugBlocks)
         Print("🚫 Confiance IA insuffisante: ", g_lastAIConfidence, " < ", AI_MinConfidence);
      return false;
   }
   
   // Vérifier la cohérence de direction
   string aiAction = g_lastAIAction;
   StringToUpper(aiAction);
   
   if(orderType == ORDER_TYPE_BUY)
   {
      if(aiAction == "BUY" || aiAction == "ACHAT" || aiAction == "LONG")
      {
         if(DebugBlocks)
            Print("✅ Confirmation IA BUY: ", aiAction, " (confiance: ", g_lastAIConfidence, ")");
         return true;
      }
      else if(aiAction == "HOLD" || aiAction == "ATTENTE")
      {
         if(DebugBlocks)
            Print("⚠️ IA neutre, autorisation BUY conditionnelle");
         return true; // Autoriser mais avec prudence
      }
   }
   else // SELL
   {
      if(aiAction == "SELL" || aiAction == "VENTE" || aiAction == "SHORT")
      {
         if(DebugBlocks)
            Print("✅ Confirmation IA SELL: ", aiAction, " (confiance: ", g_lastAIConfidence, ")");
         return true;
      }
      else if(aiAction == "HOLD" || aiAction == "ATTENTE")
      {
         if(DebugBlocks)
            Print("⚠️ IA neutre, autorisation SELL conditionnelle");
         return true; // Autoriser mais avec prudence
      }
   }
   
   // Si IA est opposée à la direction, refuser
   if(DebugBlocks)
      Print("🚫 IA opposée à la direction: ", aiAction, " vs ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"));
   return false;
}

//+------------------------------------------------------------------+
//| Gestion intelligente des entrées pour éviter les désordres         |
//+------------------------------------------------------------------+
static datetime g_lastEntryTime = 0;
static string g_lastEntryType = "";
static double g_lastEntryPrice = 0.0;

// Variables globales pour la gestion des trades
int g_lastOrderTicket = 0;
datetime g_lastOrderTime = 0;
double g_lastOrderPrice = 0.0;

// Variables globales pour le suivi des profits par position
double g_maxProfit[];      // Tableau pour stocker le profit maximum par position
ulong g_trackedTickets[];  // Tableau pour stocker les tickets suivis
int g_trackedCount = 0;    // Nombre de positions suivies
bool g_tradingAllowed = true; // Variable pour contrôler si le trading est autorisé
double g_maxLossPerTrade = 6.0; // Perte maximale de 6$ par trade
int g_losingPositionCloseDelay = 5; // Délai en secondes avant de fermer une position perdante

bool CanEnterNewPosition(ENUM_ORDER_TYPE orderType, double price)
{
   datetime now = TimeCurrent();
   string currentType = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   
   // Récupérer l'ATR actuel pour les calculs de distance
   double currentAtr[];
   if(CopyBuffer(atrHandle, 0, 0, 1, currentAtr) <= 0)
   {
      if(DebugBlocks)
         Print("⚠️ Impossible de récupérer l'ATR pour validation d'entrée");
      return true; // Autoriser si pas d'ATR disponible
   }
   double atr = currentAtr[0];
   
   // Vérifier si la dernière entrée était très récente
   if(g_lastEntryTime > 0)
   {
      int timeSinceLastEntry = (int)(now - g_lastEntryTime);
      
      // Si même type d'entrée, cooldown plus long
      if(g_lastEntryType == currentType)
      {
         if(timeSinceLastEntry < 300) // 5 minutes minimum pour même type
         {
            if(DebugBlocks)
               Print("🚫 Entrée ", currentType, " bloquée: cooldown de 5min après dernière entrée ", g_lastEntryType);
            return false;
         }
      }
      else
      {
         // Si type différent, cooldown plus court mais vérifier la distance de prix
         if(timeSinceLastEntry < 120) // 2 minutes minimum pour type différent
         {
            if(DebugBlocks)
               Print("🚫 Entrée ", currentType, " bloquée: cooldown de 2min après entrée opposée");
            return false;
         }
         
         // Vérifier si le prix n'est pas trop proche de la dernière entrée
         double priceDistance = MathAbs(price - g_lastEntryPrice);
         double atrDistance = atr * 0.5; // Distance minimale de 0.5 ATR
         
         if(priceDistance < atrDistance)
         {
            if(DebugBlocks)
               Print("🚫 Entrée ", currentType, " bloquée: prix trop proche de dernière entrée (", 
                     DoubleToString(priceDistance, _Digits), " < ", DoubleToString(atrDistance, _Digits), ")");
            return false;
         }
      }
   }
   
   // Vérifier si le marché est dans une condition de forte volatilité
   if(atr > 0)
   {
      double volatilityRatio = atr / price;
      if(volatilityRatio > 0.01) // Volatilité > 1%
      {
         // En forte volatilité, augmenter le cooldown
         if(g_lastEntryTime > 0 && (now - g_lastEntryTime) < 180) // 3 minutes minimum
         {
            if(DebugBlocks)
               Print("🚫 Entrée bloquée: forte volatilité détectée, cooldown étendu");
            return false;
         }
      }
   }
   
   return true;
}

void RecordEntry(ENUM_ORDER_TYPE orderType, double price)
{
   g_lastEntryTime = TimeCurrent();
   g_lastEntryType = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   g_lastEntryPrice = price;
   
   if(DebugBlocks)
      Print("📝 Entrée enregistrée: ", g_lastEntryType, " à ", DoubleToString(price, _Digits), 
            " (", TimeToString(g_lastEntryTime), ")");
}

//+------------------------------------------------------------------+
//| Execute trade with ATR-based stop loss and take profit           |
//| isSpikePriority=true : permet à un trade spike de passer devant  |
//| la limite globale de 2 positions/ordres pour ne pas louper le    |
//| mouvement, tout en respectant le max 2 positions par symbole.    |
//+------------------------------------------------------------------+
static datetime g_lastExecuteTime = 0;

//+------------------------------------------------------------------+
//| Exécute un trade avec gestion ATR et priorité spike              |
//+------------------------------------------------------------------+
bool ExecuteTradeWithATR(ENUM_ORDER_TYPE orderType, double atr, double price, string comment, double confidence = 1.0, bool isSpikePriority = false, bool bypassCooldown = false)
{
   // Vérifier le cooldown Boom 1000
   if(!bypassCooldown && IsBoom1000InCooldown())
   {
      Print("⏳ Trade ignoré - Cooldown Boom 1000 actif");
      return false;
   }
   
   // Vérifier s'il y a déjà une position ouverte sur ce symbole
   if(CountPositionsForSymbolMagic() > 0) {
      Print("⚠️ Impossible d'ouvrir une nouvelle position - Une position est déjà ouverte sur ", _Symbol);
      return false;
   }
   
   // Vérifier si on peut ouvrir une nouvelle position (avec bypass du cooldown si demandé et en transmettant la confiance)
   if(!isSpikePriority && !CanOpenNewPosition(orderType, price, bypassCooldown, confidence)) {
      if(confidence >= 0.8) {
         Print("⚠️ Trade haute confiance bloqué malgré la confiance élevée. Vérifier les logs pour plus de détails.");
      }
      return false;
   }
   
   // Déclarer toutes les variables une seule fois au début
   double lot, sl = 0, tp = 0;
   double entryPrice;
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   bool success = false;
   
   // Calculer la taille du lot
   lot = CalculateLotSize(atr);
   
   // Vérifier si le lot est valide pour ce symbole
   if(!IsValidLotSize(lot)) {
      return false;
   }
   
   // Détection des symboles Boom/Crash
   bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   
   // Pour Boom/Crash: vérifier que le spike est réellement en cours (pas trop tôt)
   if(isBoomCrash && isSpikePriority)
   {
      // Vérifier la vitesse du mouvement (spike actif = mouvement rapide)
      static double g_lastPriceCheck = 0.0;
      static datetime g_lastPriceCheckTime = 0;
      datetime now = TimeCurrent();
      double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                           SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                           SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      if(g_lastPriceCheckTime > 0 && (now - g_lastPriceCheckTime) <= 3) // Vérifier sur 3 secondes
      {
         double priceChange = MathAbs(currentPrice - g_lastPriceCheck);
         double timeDiff = (double)(now - g_lastPriceCheckTime);
         double speed = (timeDiff > 0) ? (priceChange / timeDiff) : 0.0;
         
         // Si vitesse < 0.3 points/seconde, le spike n'est pas encore actif - attendre
         if(speed < 0.3)
         {
            Print("⏳ Boom/Crash: Spike pas encore actif (vitesse: ", DoubleToString(speed, 3), " pts/s < 0.3) - Attente...");
            return false;
         }
         else
         {
            Print("✅ Boom/Crash: Spike actif détecté (vitesse: ", DoubleToString(speed, 3), " pts/s) - Entrée autorisée");
         }
      }
      
      g_lastPriceCheck = currentPrice;
      g_lastPriceCheckTime = now;
   }
   
   // Calcul des niveaux de stop loss et take profit
   entryPrice = (orderType == ORDER_TYPE_BUY) ? 
                SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Ajuster les stops pour les paires Boom/Crash
   if(isBoomCrash) {
      // Multiplicateur plus élevé pour les stops sur Boom/Crash
      double multiplier = 2.0; // Augmenter le multiplicateur pour plus de marge
      sl = (orderType == ORDER_TYPE_BUY) ? 
           entryPrice - (atr * multiplier) : 
           entryPrice + (atr * multiplier);
   } else {
      // Stops normaux pour les autres paires
      sl = (orderType == ORDER_TYPE_BUY) ? 
           entryPrice - (atr * 1.5) : 
           entryPrice + (atr * 1.5);
   }
   
   // Prendre des bénéfices partiels
   double tp1 = (orderType == ORDER_TYPE_BUY) ? 
               entryPrice + (atr * 1.0) : 
               entryPrice - (atr * 1.0);
   double tp2 = (orderType == ORDER_TYPE_BUY) ? 
               entryPrice + (atr * 2.0) : 
               entryPrice - (atr * 2.0);
   
   // Préparer la requête de trading
   // Les variables request et result sont déjà déclarées au début
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = CalculateLotSize(atr);
   request.type = orderType;
   request.price = entryPrice;
   request.sl = sl;
   request.tp = tp2; // TP final plus éloigné
   request.deviation = 10;
   request.magic = InpMagicNumber;
   request.comment = comment;
   // Le type de filling est géré automatiquement par trade.SetTypeFillingBySymbol() dans OnInit()
   
   // Envoyer l'ordre
   success = OrderSend(request, result);
   
   if(success && result.retcode == TRADE_RETCODE_DONE) {
      Print("✅ Ordre exécuté avec succès - Ticket: ", result.order, 
            " | Prix: ", entryPrice, 
            " | SL: ", sl, 
            " | TP: ", tp2,
            " | Lot: ", request.volume);
      
      // Si c'est une position spike, marquer comme exécutée
      if(isSpikePriority) {
         g_aiSpikeExecuted = true;
      }
      
      // Validation avancée avec Fibonacci, EMA et IA
      if(!ValidateAdvancedEntry(orderType, price))
      {
         return false;
      }
      
      // Vérification de la tendance H1 avant de prendre une position
      TrendAnalysis trendAnalysis = GetMultiTimeframeTrendAnalysis();
      
      // Activer le filtre H1 pour s'assurer que le trade est dans le sens de la tendance
      // Réduire le seuil de confiance pour permettre plus d'entrées (40% au lieu de 60%)
      if(trendAnalysis.is_valid)
      {
         // Vérifier la confiance minimale de 40% (réduit de 60% pour plus de flexibilité)
         if(trendAnalysis.h1_confidence < 40.0)
         {
            Print("❌ Tendance H1 non valide (confiance trop faible: ", trendAnalysis.h1_confidence, "% < 40%)");
            return false;
         }
         
         // Vérifier que la direction du trade correspond à la tendance H1
         string expectedDirection = (orderType == ORDER_TYPE_BUY) ? "buy" : "sell";
         StringToLower(expectedDirection);
         StringToLower(trendAnalysis.h1_direction);
         
         if(trendAnalysis.h1_direction != expectedDirection)
         {
            Print("❌ Direction du trade non alignée avec la tendance H1 (", trendAnalysis.h1_direction, " vs ", expectedDirection, ")");
            return false;
         }
         
         Print("✅ Validation H1 OK : ", trendAnalysis.h1_direction, " avec confiance ", trendAnalysis.h1_confidence, "%");
      }
      else
      {
         // Permettre les trades sans validation M1 temporairement
         if(DebugBlocks)
            Print("⚠️ Validation M1 désactivée temporairement - Trade autorisé");
      }
      
      // Trade exécuté avec succès, enregistrer et retourner
      RecordEntry(orderType, entryPrice);
      g_lastExecuteTime = TimeCurrent();
      
      // Initialiser l'état dynamique de la position
      if(result.retcode == TRADE_RETCODE_DONE && atr > 0)
      {
         ulong ticket = result.order;
         if(ticket > 0)
         {
            InitializeDynamicPositionState(ticket, sl, tp2, atr);
            Print("État dynamique initialisé pour le ticket ", ticket);
            
            // Enregistrer le trade si c'est un bypass du cooldown
            if(bypassCooldown)
            {
               if(g_tradesBypassCooldownCount < 50)
               {
                  g_tradesBypassCooldown[g_tradesBypassCooldownCount].ticket = ticket;
                  g_tradesBypassCooldown[g_tradesBypassCooldownCount].symbol = _Symbol;
                  g_tradesBypassCooldown[g_tradesBypassCooldownCount].comment = comment;
                  g_tradesBypassCooldown[g_tradesBypassCooldownCount].openTime = TimeCurrent();
                  g_tradesBypassCooldownCount++;
                  Print("📝 Trade bypass cooldown enregistré - Ticket: ", ticket, " | Symbole: ", _Symbol);
               }
            }
         }
      }
      
      return true;
   }
   
   // Si le trade n'a pas été exécuté dans le bloc précédent, continuer avec la logique complète
   // Détection Boom/Crash pour adapter les garde-fous (plus agressif)
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   bool isBoom300Symbol = (StringFind(_Symbol, "Boom 300") != -1);
   
   // Vérification stricte des directions autorisées
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   // Bloquer les achats sur Crash et les ventes sur Boom
   if((orderType == ORDER_TYPE_BUY && isCrash) || (orderType == ORDER_TYPE_SELL && isBoom))
   {
      Print("⚠️ Trade bloqué : ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " non autorisé sur ", _Symbol);
      return false;
   }
   
   // Récupérer les informations du symbole
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
   
   // entryPrice est déjà déclaré au début de la fonction
   entryPrice = (orderType == ORDER_TYPE_BUY) ? ask : bid;
   
   // 1. VALIDATION DU LOT
   // lot est déjà déclaré au début de la fonction
   
   // Règles spécifiques pour Boom/Crash
   if(isBoomCrashSymbol)
   {
      // Pour Boom/Crash, utiliser le lot minimum du broker
      lot = minLot; // Utiliser le lot minimum réel du symbole
      
      // Afficher le lot utilisé pour debug
      if(DebugBlocks)
      {
         Print("🎯 Boom/Crash - Lot minimum utilisé: ", lot, " pour ", _Symbol);
      }
   }
   
   // Arrondir au pas de lot le plus proche
   if(lotStep > 0)
      lot = MathFloor(lot / lotStep) * lotStep;
   
   // Vérifier les limites du lot
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   // Vérification finale du lot
   if(lot < minLot || lot > maxLot)
   {
      Print("❌ Lot invalide: ", lot, " (Min: ", minLot, ", Max: ", maxLot, ", Step: ", lotStep, ")");
      return false;
   }
   
   // 2. CALCUL ET VALIDATION DES STOPS
   // sl, tp et entryPrice sont déjà déclarés au début
   // entryPrice est déjà calculé plus haut
   
   // Utiliser TP/SL fixes si activé, sinon calcul ATR
   if(UseFixedTPSL)
   {
      // Calculer le TP/SL en dollars fixes
      // tickValue et tickSize sont déjà déclarés plus haut
      
      if(tickValue > 0 && tickSize > 0)
      {
         // Convertir les dollars en points
         double slPoints = FixedSLAmount / tickValue * tickSize;
         double tpPoints = FixedTPAmount / tickValue * tickSize;
         
         if(orderType == ORDER_TYPE_BUY)
         {
            sl = entryPrice - slPoints;
            tp = entryPrice + tpPoints;
         }
         else // SELL
         {
            sl = entryPrice + slPoints;
            tp = entryPrice - tpPoints;
         }
         
         if(DebugBlocks)
            Print("📏 TP/SL fixes: SL=", FixedSLAmount, "$ (", DoubleToString(slPoints, _Digits), " points), TP=", FixedTPAmount, "$ (", DoubleToString(tpPoints, _Digits), " points)");
      }
      else
      {
         Print("❌ Impossible de calculer TP/SL fixes - tickValue/tickSize invalides");
         return false;
      }
   }
   else
   {
      // Calcul des stops basés sur l'ATR (ancienne méthode)
      if(orderType == ORDER_TYPE_BUY)
      {
         sl = entryPrice - (atr * SL_ATR_Mult);
         tp = entryPrice + (atr * TP_ATR_Mult);
         
         // Validation spéciale Boom/Crash : distances minimales
         if(isBoomCrashSymbol)
         {
            double minDistance = atr * 2.0; // Minimum 2x ATR pour Boom/Crash
            if(entryPrice - sl < minDistance) sl = entryPrice - minDistance;
            if(tp - entryPrice < minDistance) tp = entryPrice + minDistance;
         }
      }
      else // SELL
      {
         sl = entryPrice + (atr * SL_ATR_Mult);
         tp = entryPrice - (atr * TP_ATR_Mult);
         
         // Validation spéciale Boom/Crash : distances minimales
         if(isBoomCrashSymbol)
         {
            double minDistance = atr * 2.0; // Minimum 2x ATR pour Boom/Crash
            if(sl - entryPrice < minDistance) sl = entryPrice + minDistance;
            if(entryPrice - tp < minDistance) tp = entryPrice - minDistance;
         }
      }
   }
   
   // Normaliser les prix
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   // Vérifier la validité des niveaux de stop
   double minStopDistance = stopLevel + freezeLevel + spread;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      double minSl = entryPrice - minStopDistance;
      if(sl >= minSl)
      {
         sl = minSl - point; // Ajuster légèrement en dessous
         Print("Ajustement SL BUY à ", sl, " (distance minimale requise: ", minStopDistance, ")");
      }
   }
   else // SELL
   {
      double minSl = entryPrice + minStopDistance;
      if(sl <= minSl)
      {
         sl = minSl + point; // Ajuster légèrement au-dessus
         Print("Ajustement SL SELL à ", sl, " (distance minimale requise: ", minStopDistance, ")");
      }
   }
   
   // Vérifier les niveaux de stop par rapport au prix actuel
   if(orderType == ORDER_TYPE_BUY && (sl >= entryPrice || tp <= entryPrice))
   {
      Print("❌ Niveaux de stop invalides pour BUY - SL: ", sl, ", TP: ", tp, ", Prix: ", entryPrice);
      return false;
   }
   if(orderType == ORDER_TYPE_SELL && (sl <= entryPrice || tp >= entryPrice))
   {
      Print("❌ Niveaux de stop invalides pour SELL - SL: ", sl, ", TP: ", tp, ", Prix: ", entryPrice);
      return false;
   }
   
   // Vérifier le free margin
   double margin = 0;
   if(!OrderCalcMargin(orderType, _Symbol, lot, entryPrice, margin) || margin <= 0)
   {
      Print("❌ Erreur calcul marge: ", GetLastError());
      return false;
   }
   
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(margin > freeMargin)
   {
      Print("❌ Marge insuffisante: ", margin, " (disponible: ", freeMargin, ")");
      return false;
   }
   
   // Vérifier l'anti-spam
   int totalPositions = CountAllPositionsForMagic();
   bool noOpenPositions = (totalPositions == 0);
   int antiSpamSec = isBoomCrashSymbol ? 15 : 60;
   if(TimeCurrent() - g_lastExecuteTime < antiSpamSec && !(isSpikePriority && noOpenPositions))
   {
      Print("⏳ Anti-spam actif - Attente de ", antiSpamSec, " secondes entre les trades");
      return false;
   }
   
   // 3. EXÉCUTION DU TRADE
   // request, result et success sont déjà déclarés au début
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = orderType;
   request.price = entryPrice;
   request.sl = sl;
   request.tp = tp;
   request.deviation = 10;
   request.magic = InpMagicNumber;
   request.comment = comment;
   // Le type de filling est géré automatiquement par trade.SetTypeFillingBySymbol() dans OnInit()
   
   // Envoyer l'ordre
   ResetLastError();
   success = OrderSend(request, result);
   
   if(!success || result.retcode != TRADE_RETCODE_DONE)
   {
      Print("❌ Erreur d'exécution: ", result.comment, " (", result.retcode, ") - Erreur: ", GetLastError());
      return false;
   }
   
   Print("✅ Trade exécuté: ", EnumToString(orderType), " ", lot, " lots @ ", entryPrice, 
         " SL: ", sl, " TP: ", tp, " (Ticket: ", result.order, ")");
   
   // Enregistrer l'entrée pour éviter les désordres
   RecordEntry(orderType, entryPrice);
   
   // Mettre à jour le temps du dernier trade
   g_lastExecuteTime = TimeCurrent();
   
   // Initialiser l'état dynamique de la position
   if(result.retcode == TRADE_RETCODE_DONE && atr > 0)
   {
      ulong ticket = result.order;
      if(ticket > 0)
      {
         InitializeDynamicPositionState(ticket, sl, tp, atr);
         Print("État dynamique initialisé pour le ticket ", ticket);
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Gestion des risques                                             |
//+------------------------------------------------------------------+
void ManageRiskControl()
{
   double totalProfit = 0;
   double totalVolume = 0;
   int totalPositions = 0;
   
   // Parcourir toutes les positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
      {
         totalProfit += PositionGetDouble(POSITION_PROFIT);
         totalVolume += PositionGetDouble(POSITION_VOLUME);
         totalPositions++;
      }
   }
   
   // Si perte totale dépasse 6$, fermer les positions gagnantes
   if(totalProfit < -g_maxLossPerTrade)
   {
      CloseAllProfitablePositions();
   }
   
   // Fermer les positions perdantes après un certain délai
   CloseLosingPositionsAfterDelay();
   
   // Bloquer les nouveaux trades si perte maximale atteinte
   if(totalProfit < -g_maxLossPerTrade)
   {
      g_tradingAllowed = false;
      Print("Trading bloqué : perte maximale de ", g_maxLossPerTrade, " $" + AccountInfoString(ACCOUNT_CURRENCY) + " atteinte");
   }
}

//+------------------------------------------------------------------+
//| Ferme toutes les positions gagnantes                            |
//+------------------------------------------------------------------+
void CloseAllProfitablePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(profit > 0)
         {
            // Fermer la position gagnante
            trade.PositionClose(ticket);
            Print("Fermeture position gagnante : +", profit, " ", AccountInfoString(ACCOUNT_CURRENCY));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Ferme les positions perdantes après un délai                    |
//+------------------------------------------------------------------+
void CloseLosingPositionsAfterDelay()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(profit < 0)
         {
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
            if(TimeCurrent() - openTime > g_losingPositionCloseDelay)
            {
               // Fermer la position perdante
               trade.PositionClose(ticket);
               Print("Fermeture position perdante après délai : ", profit, " ", AccountInfoString(ACCOUNT_CURRENCY));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie les conditions du marché                                |
//+------------------------------------------------------------------+
bool CheckMarketConditions()
{
   // Vérifier la tendance des EMA
   int localEmaFastHandle = iMA(_Symbol, PERIOD_M15, 9, 0, MODE_EMA, PRICE_CLOSE);
   int localEmaSlowHandle = iMA(_Symbol, PERIOD_M15, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   double emaFast[1], emaSlow[1];
   
   // Copier les valeurs des EMA
   if(CopyBuffer(localEmaFastHandle, 0, 0, 1, emaFast) <= 0 || 
      CopyBuffer(localEmaSlowHandle, 0, 0, 1, emaSlow) <= 0)
   {
      IndicatorRelease(localEmaFastHandle);
      IndicatorRelease(localEmaSlowHandle);
      return false;
   }
   
   // Libérer les handles
   IndicatorRelease(localEmaFastHandle);
   IndicatorRelease(localEmaSlowHandle);
   
   // Si les EMA sont alignées dans le même sens avec un écart minimum
   if(MathAbs(emaFast[0] - emaSlow[0]) > 10 * _Point)
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| DEINIT                                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Logger la raison du détachement
   string reasonStr = "";
   switch(reason)
   {
      case REASON_PROGRAM:      reasonStr = "Program stopped"; break;
      case REASON_REMOVE:       reasonStr = "Program removed from chart"; break;
      case REASON_RECOMPILE:   reasonStr = "Program recompiled"; break;
      case REASON_CHARTCHANGE: reasonStr = "Symbol or timeframe changed"; break;
      case REASON_CHARTCLOSE:  reasonStr = "Chart closed"; break;
      case REASON_PARAMETERS:  reasonStr = "Input parameters changed"; break;
      case REASON_ACCOUNT:     reasonStr = "Account changed"; break;
      default:                reasonStr = "Unknown reason " + IntegerToString(reason); break;
   }
   
   Print("🔴 DÉTACHEMENT ROBOT - Raison: ", reasonStr);
   
   // Libération des indicateurs multi-timeframe
   ReleaseMultiTimeframeIndicators();
   
   // Libération des autres indicateurs
   IndicatorRelease(rsiHandle);
   IndicatorRelease(atrHandle);
   IndicatorRelease(emaFastHandle);
   IndicatorRelease(emaSlowHandle);
   IndicatorRelease(emaFastEntryHandle);
   IndicatorRelease(emaSlowEntryHandle);
   IndicatorRelease(emaScalpEntryHandle);
   IndicatorRelease(emaFastQuickHandle);
   IndicatorRelease(emaSlowQuickHandle);
   if(stHandle!=INVALID_HANDLE) IndicatorRelease(stHandle);
   
   // Libération des handles multi-timeframe
   if(h1_ema_fast_handle != INVALID_HANDLE) IndicatorRelease(h1_ema_fast_handle);
   if(h1_ema_slow_handle != INVALID_HANDLE) IndicatorRelease(h1_ema_slow_handle);
   if(h1_atr_handle != INVALID_HANDLE) IndicatorRelease(h1_atr_handle);
   if(m5_ema_fast_handle != INVALID_HANDLE) IndicatorRelease(m5_ema_fast_handle);
   if(m5_ema_slow_handle != INVALID_HANDLE) IndicatorRelease(m5_ema_slow_handle);
   if(m5_atr_handle != INVALID_HANDLE) IndicatorRelease(m5_atr_handle);
   
   // Nettoyer TOUS les objets graphiques créés par le robot
   ObjectsDeleteAll(0, "AI_PANEL_");
   ObjectsDeleteAll(0, "AI_BLOCK_LABEL_");
   ObjectsDeleteAll(0, "BASIC_PRED_");
   ObjectsDeleteAll(0, "SPIKE_ARROW_");
   ObjectsDeleteAll(0, "AI_SPIKE_");
   ObjectsDeleteAll(0, "TIMEWINDOWS_");
   ObjectsDeleteAll(0, "SMC_");
   
   Print("🧹 Nettoyage des objets graphiques terminé");
   
   // Libérer SMC
   SMC_Deinit();

   Comment("");
}

//+------------------------------------------------------------------+
//| Envoi d'une notification MT5 formatée                           |
//+------------------------------------------------------------------+
void SendTradingSignal(string symbol, string signal, string timeframe, 
                      double price, double sl, double tp, string comment = "")
{
   // Vérifier si on a déjà envoyé ce signal récemment (éviter le spam)
   static datetime lastSignalTime = 0;
   static string lastSignal = "";
   
   string signalKey = StringFormat("%s_%s_%s_%.5f", symbol, signal, timeframe, NormalizeDouble(price, 5));
   
   if(TimeCurrent() - lastSignalTime < 300 && lastSignal == signalKey) // 5 minutes entre chaque signal identique
      return;
   
   // Créer un message formaté
   string msg = StringFormat("SIGNAL %s - %s %s\n", symbol, signal, timeframe);
   msg += StringFormat("Prix: %.5f\n", price);
   msg += StringFormat("SL: %.5f  TP: %.5f\n", sl, tp);
   if(comment != "") 
      msg += "Note: " + comment;
   
   // Envoyer la notification
   if(!SendNotification(msg))
      Print("Erreur envoi notification: ", GetLastError());
   else
   {
      lastSignalTime = TimeCurrent();
      lastSignal = signalKey;
   }
}

// Variables pour la gestion de la volatilité
double MinATR = 0.0005;  // Ajustez selon votre stratégie
double MaxATR = 0.0050;  // Ajustez selon votre stratégie

//+------------------------------------------------------------------+
//| Traitement des signaux IA et exécution des trades                |
//+------------------------------------------------------------------+
void AI_ProcessSignal(string signalType, double confidence, string reason = "")
{
   // Blocage strict: en dessous de 80% (ou AI_MinConfidence si plus élevé), on ne déclenche pas
   double minRequiredConf = MathMax(0.80, AI_MinConfidence);
   if(confidence < minRequiredConf)
   {
      Print("Signal IA ignoré (confiance < seuil): ", signalType, " conf=", DoubleToString(confidence, 2), " seuil=", DoubleToString(minRequiredConf, 2));
      g_lastValidationReason = "Confiance IA trop faible";
      return;
   }
   
   // Vérifier si le signal est valide et cohérent avec l'IA
   ENUM_ORDER_TYPE orderType = WRONG_VALUE;
   if(signalType == "BUY" || signalType == "ACHAT")
   {
      orderType = ORDER_TYPE_BUY;
   }
   else if(signalType == "SELL" || signalType == "VENTE")
   {
      orderType = ORDER_TYPE_SELL;
   }
   
   if(orderType == WRONG_VALUE) return;
   
   // Filtre directionnel M1 strict : ne jamais trader contre une tendance M1 marquée
   double emaFastM1_now[], emaSlowM1_now[];
   bool m1FilterOK = true;
   if(CopyBuffer(emaFastEntryHandle, 0, 0, 1, emaFastM1_now) > 0 &&
      CopyBuffer(emaSlowEntryHandle, 0, 0, 1, emaSlowM1_now) > 0)
   {
      bool m1Up   = (emaFastM1_now[0] > emaSlowM1_now[0]);
      bool m1Down = (emaFastM1_now[0] < emaSlowM1_now[0]);
      if(orderType == ORDER_TYPE_BUY && m1Down)
      {
         g_lastValidationReason = "Refus BUY: downtrend fort en M1 (faux signal IA)";
         Print(g_lastValidationReason);
         return;
      }
      if(orderType == ORDER_TYPE_SELL && m1Up)
      {
         g_lastValidationReason = "Refus SELL: uptrend fort en M1 (faux signal IA)";
         Print(g_lastValidationReason);
         return;
      }
   }
   
   if(!IsValidSignal(orderType, confidence))
   {
      Print("Signal IA ignoré: non valide ou non cohérent");
      if(AI_UseNotifications && g_lastValidationReason != "")
      {
         string msg = StringFormat("IA %s BLOQUÉ sur %s\nRaison: %s", (orderType==ORDER_TYPE_BUY?"BUY":"SELL"), _Symbol, g_lastValidationReason);
         SendNotification(msg);
         DrawAIBlockLabel(_Symbol, orderType==ORDER_TYPE_BUY ? "BUY BLOQUÉ" : "SELL BLOQUÉ", g_lastValidationReason);
      }
      return;
   }
   
   // Envoyer une notification du signal
   if(AI_UseNotifications)
   {
      string direction = (orderType == ORDER_TYPE_BUY) ? "ACHAT" : "VENTE";
      AI_SendNotification("IA_SIGNAL", direction, confidence, reason);
   }
   
   // Sécurité : si auto-exec est désactivé, on s'arrête (par défaut activé)
   if(!AI_AutoExecuteTrades)
      return;
   
   // Récupérer les données du marché
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) return;
   
   // Déterminer le type de trade et le prix d'entrée
   double entryPrice = 0;
   
   if(signalType == "BUY" || signalType == "ACHAT")
   {
      entryPrice = ask;
   }
   else if(signalType == "SELL" || signalType == "VENTE")
   {
      entryPrice = bid;
   }
   
   // Vérifier si une position est déjà ouverte sur ce symbole
   if(CountPositionsForSymbolMagic() > 0)
   {
      Print("IA: Trade ignoré - position déjà en cours sur ", _Symbol);
      return;
   }
   
   // Exécuter le trade
   string comment = "IA_";
   if(StringLen(reason) > 0) comment += reason;
   else comment += signalType;

   if(ExecuteTradeWithATR(orderType, atr[0], entryPrice, comment, 1.0, false))
   {
      Print("Trade exécuté par IA: ", signalType, " à ", DoubleToString(entryPrice, _Digits), " (confiance: ", DoubleToString(confidence, 2), ")");
      
      // Envoyer une notification de confirmation d'exécution
      if(AI_UseNotifications)
      {
         string msg = StringFormat("TRADE EXECUTE: %s à %s (Confiance: %.1f%%)\n%s", 
                                 signalType, 
                                 DoubleToString(entryPrice, _Digits),
                                 confidence * 100.0,
                                 reason);
         SendNotification(msg);
      }
   }
   else
   {
      Print("Échec de l'exécution du trade IA: ", signalType, " - Erreur: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Dessine les zones IA (H1 validées M5) sur le graphique            |
//| Les zones restent PERMANENTES jusqu'à nouvelle zone du backend   |
//+------------------------------------------------------------------+
// Variables statiques pour mémoriser les dernières zones valides
static double g_lastBuyZoneLow = 0, g_lastBuyZoneHigh = 0;
static double g_lastSellZoneLow = 0, g_lastSellZoneHigh = 0;

void DrawAIZones()
{
   datetime now    = TimeCurrent();
   datetime past   = now - 24 * 60 * 60;   // historique 24h
   datetime future = now + 24 * 60 * 60;   // projection 24h

   // ------------------------------------------------------------------
   // Objectif : dessiner les zones IA non seulement sur le graphique
   // courant, mais aussi sur les graphiques H1 et H4 du même symbole.
   // ------------------------------------------------------------------

   // ---------------------------
   // Normalisation de la largeur
   // ---------------------------
   // Pour éviter des zones trop fines ou trop larges, on applique
   // un min / max en POINTS autour du centre de la zone IA.
   double point = _Point;
   // Largeurs mini / maxi en points (valeurs raisonnables par défaut)
   int minWidthPoints = 50;     // ~ 50 points mini
   int maxWidthPoints = 5000;   // ~ 5000 points maxi

   // Normaliser zone d'achat
   if(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > g_aiBuyZoneLow)
   {
      double centerBuy   = (g_aiBuyZoneLow + g_aiBuyZoneHigh) / 2.0;
      double widthBuyPts = (g_aiBuyZoneHigh - g_aiBuyZoneLow) / point;

      if(widthBuyPts < minWidthPoints)
         widthBuyPts = minWidthPoints;
      else if(widthBuyPts > maxWidthPoints)
         widthBuyPts = maxWidthPoints;

      double halfBuy = (widthBuyPts * point) / 2.0;
      g_aiBuyZoneLow  = centerBuy - halfBuy;
      g_aiBuyZoneHigh = centerBuy + halfBuy;
   }

   // Normaliser zone de vente
   if(g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > g_aiSellZoneLow)
   {
      double centerSell   = (g_aiSellZoneLow + g_aiSellZoneHigh) / 2.0;
      double widthSellPts = (g_aiSellZoneHigh - g_aiSellZoneLow) / point;

      if(widthSellPts < minWidthPoints)
         widthSellPts = minWidthPoints;
      else if(widthSellPts > maxWidthPoints)
         widthSellPts = maxWidthPoints;

      double halfSell = (widthSellPts * point) / 2.0;
      g_aiSellZoneLow  = centerSell - halfSell;
      g_aiSellZoneHigh = centerSell + halfSell;
   }

   // Zone d'achat - Ne supprimer QUE si nouvelle zone reçue
   string buyName = "AI_ZONE_BUY_" + _Symbol;
   if(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 && g_aiBuyZoneHigh > g_aiBuyZoneLow)
   {
      // Nouvelle zone reçue du backend - mettre à jour
      if(g_aiBuyZoneLow != g_lastBuyZoneLow || g_aiBuyZoneHigh != g_lastBuyZoneHigh)
      {
         g_lastBuyZoneLow  = g_aiBuyZoneLow;
         g_lastBuyZoneHigh = g_aiBuyZoneHigh;

         long chart_id = ChartFirst();
         while(chart_id >= 0)
         {
            string sym = ChartSymbol(chart_id);
            ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)ChartPeriod(chart_id);

            // Dessiner sur M5, H1 et H4 pour ce symbole
            if(sym == _Symbol && (tf == PERIOD_M5 || tf == PERIOD_H1 || tf == PERIOD_H4))
            {
               ObjectDelete(chart_id, buyName);
               if(ObjectCreate(chart_id, buyName, OBJ_RECTANGLE, 0, past, g_aiBuyZoneHigh, future, g_aiBuyZoneLow))
               {
                  color buyColor = (color)ColorToARGB(clrLime, 60); // vert semi-transparent
                  ObjectSetInteger(chart_id, buyName, OBJPROP_COLOR, buyColor);
                  ObjectSetInteger(chart_id, buyName, OBJPROP_BACK, true);
                  ObjectSetInteger(chart_id, buyName, OBJPROP_FILL, true);
                  ObjectSetInteger(chart_id, buyName, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(chart_id, buyName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                  ObjectSetString(chart_id, buyName, OBJPROP_TEXT, "Zone Achat IA");
               }
            }

            chart_id = ChartNext(chart_id);
         }

         Print("📍 Nouvelle zone ACHAT affichée: ", g_aiBuyZoneLow, " - ", g_aiBuyZoneHigh);
      }
   }
   // NE PAS supprimer si pas de nouvelle zone - garder l'ancienne visible

   // Zone de vente - Ne supprimer QUE si nouvelle zone reçue
   string sellName = "AI_ZONE_SELL_" + _Symbol;
   if(g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0 && g_aiSellZoneHigh > g_aiSellZoneLow)
   {
      // Nouvelle zone reçue du backend - mettre à jour
      if(g_aiSellZoneLow != g_lastSellZoneLow || g_aiSellZoneHigh != g_lastSellZoneHigh)
      {
         g_lastSellZoneLow  = g_aiSellZoneLow;
         g_lastSellZoneHigh = g_aiSellZoneHigh;

         long chart_id = ChartFirst();
         while(chart_id >= 0)
         {
            string sym = ChartSymbol(chart_id);
            ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)ChartPeriod(chart_id);

            // Dessiner sur M5, H1 et H4 pour ce symbole
            if(sym == _Symbol && (tf == PERIOD_M5 || tf == PERIOD_H1 || tf == PERIOD_H4))
            {
               ObjectDelete(chart_id, sellName);
               if(ObjectCreate(chart_id, sellName, OBJ_RECTANGLE, 0, past, g_aiSellZoneHigh, future, g_aiSellZoneLow))
               {
                  color sellColor = (color)ColorToARGB(clrRed, 60); // rouge semi-transparent
                  ObjectSetInteger(chart_id, sellName, OBJPROP_COLOR, sellColor);
                  ObjectSetInteger(chart_id, sellName, OBJPROP_BACK, true);
                  ObjectSetInteger(chart_id, sellName, OBJPROP_FILL, true);
                  ObjectSetInteger(chart_id, sellName, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(chart_id, sellName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                  ObjectSetString(chart_id, sellName, OBJPROP_TEXT, "Zone Vente IA");
               }
            }

            chart_id = ChartNext(chart_id);
         }

         // Log seulement si DebugBlocks est activé ou si c'est vraiment une nouvelle zone
         if(DebugBlocks)
            Print("📍 Nouvelle zone VENTE affichée: ", g_aiSellZoneLow, " - ", g_aiSellZoneHigh);
      }
   }
   // NE PAS supprimer si pas de nouvelle zone - garder l'ancienne visible
}

//+------------------------------------------------------------------+
//| Notification périodique des analyses IA                          |
//+------------------------------------------------------------------+
void SendAISummaryIfDue()
{
   if(!AI_UseNotifications) return;
   int intervalSec = 600; // 10 minutes
   datetime now = TimeCurrent();
   if(g_lastAISummaryTime > 0 && (now - g_lastAISummaryTime) < intervalSec)
      return;

   // Construire un résumé compact
   string msg = StringFormat("IA RÉSUMÉ %s\nAction: %s (conf %.1f%%)\nRaison: %s",
                             _Symbol,
                             g_lastAIAction,
                             g_lastAIConfidence * 100.0,
                             g_lastAIReason);

   // Ajouter zones si disponibles
   if(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0)
      msg += StringFormat("\nZone Achat H1/M5: %.5f - %.5f", g_aiBuyZoneLow, g_aiBuyZoneHigh);
   if(g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0)
      msg += StringFormat("\nZone Vente H1/M5: %.5f - %.5f", g_aiSellZoneLow, g_aiSellZoneHigh);

   // Spike info
   if(g_aiSpikePredicted && g_aiSpikeZonePrice > 0.0)
   {
      msg += StringFormat("\nSpike prévu: %s zone %.5f", (g_aiSpikeDirection ? "BUY" : "SELL"), g_aiSpikeZonePrice);
   }

   SendNotification(msg);
   g_lastAISummaryTime = now;
}

//+------------------------------------------------------------------+
//| Notification quand le prix entre dans une zone IA                 |
//+------------------------------------------------------------------+
void CheckAIZoneAlerts()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = (bid + ask) / 2.0;
   datetime now = TimeCurrent();

   int alertCooldown = 60; // 1 minute anti-spam

   // BUY zone
   bool inBuyZone = (g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
                     price >= g_aiBuyZoneLow && price <= g_aiBuyZoneHigh);
   if(inBuyZone && !g_aiZoneAlertBuy && (now - g_aiLastZoneAlert > alertCooldown))
   {
      g_aiZoneAlertBuy = true;
      g_aiLastZoneAlert = now;
      string msg = StringFormat("Zone ACHAT (H1/M5) touchée sur %s : %.5f-%.5f | Prix %.5f (attente rebond M5, %d bougie(s))",
                                _Symbol, g_aiBuyZoneLow, g_aiBuyZoneHigh, price, AIZoneConfirmBarsM5);
      Print(msg);
      if(AI_UseNotifications)
         SendNotification(msg);

      // Armer la stratégie de rebond BUY (le trade sera déclenché après confirmation M5)
      g_aiBuyZoneArmed     = true;
      g_aiBuyZoneTouchTime = now;
   }
   if(!inBuyZone)
   {
      g_aiZoneAlertBuy = false;
      g_aiBuyZoneArmed = false;
   }

   // SELL zone
   bool inSellZone = (g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0 &&
                      price >= g_aiSellZoneLow && price <= g_aiSellZoneHigh);
   if(inSellZone && !g_aiZoneAlertSell && (now - g_aiLastZoneAlert > alertCooldown))
   {
      g_aiZoneAlertSell = true;
      g_aiLastZoneAlert = now;
      string msg = StringFormat("Zone VENTE (H1/M5) touchée sur %s : %.5f-%.5f | Prix %.5f (attente rebond M5, %d bougie(s))",
                                _Symbol, g_aiSellZoneLow, g_aiSellZoneHigh, price, AIZoneConfirmBarsM5);
      Print(msg);
      if(AI_UseNotifications)
         SendNotification(msg);

      // Armer la stratégie de rebond SELL
      g_aiSellZoneArmed     = true;
      g_aiSellZoneTouchTime = now;
   }
   if(!inSellZone)
   {
      g_aiZoneAlertSell = false;
      g_aiSellZoneArmed = false;
   }
}

//+------------------------------------------------------------------+
//| Détection automatique des touches de trendlines/supports/résistances |
//| et exécution automatique des trades quand le serveur AI le signale |
//+------------------------------------------------------------------+
void CheckAITrendlineTouchAndTrade()
{
   if(!AI_AutoExecuteTrades || !UseAI_Agent)
      return;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (ask + bid) / 2.0;
   if(ask <= 0 || bid <= 0) return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atr[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) return;
   
   // Tolérance pour considérer qu'on "touche" une trendline (en ATR)
   double touchTolerance = atr[0] * 0.1; // 10% de l'ATR
   
   static datetime lastTrendlineCheck = 0;
   static datetime lastTradeTime = 0;
   datetime now = TimeCurrent();
   
   // Vérifier toutes les 5 secondes pour éviter trop de calculs
   if(now - lastTrendlineCheck < 5) return;
   lastTrendlineCheck = now;
   
   // Anti-spam: ne pas trader trop souvent (minimum 30 secondes entre trades)
   if(now - lastTradeTime < 30) return;
   
   // 1. Vérifier les touches de trendlines H1
   double bullH1 = 0.0, bearH1 = 0.0;
   if(ObjectFind(0, "AI_H1_BULL_TL") >= 0)
      bullH1 = ObjectGetValueByTime(0, "AI_H1_BULL_TL", TimeCurrent(), 0);
   if(ObjectFind(0, "AI_H1_BEAR_TL") >= 0)
      bearH1 = ObjectGetValueByTime(0, "AI_H1_BEAR_TL", TimeCurrent(), 0);
   
   // 2. Vérifier les touches de trendlines M15
   double bullM15 = 0.0, bearM15 = 0.0;
   if(ObjectFind(0, "AI_M15_BULL_TL") >= 0)
      bullM15 = ObjectGetValueByTime(0, "AI_M15_BULL_TL", TimeCurrent(), 0);
   if(ObjectFind(0, "AI_M15_BEAR_TL") >= 0)
      bearM15 = ObjectGetValueByTime(0, "AI_M15_BEAR_TL", TimeCurrent(), 0);
   
   // 3. Vérifier les touches de supports/résistances (zones AI)
   bool nearSupport = false;
   bool nearResistance = false;
   if(g_aiBuyZoneLow > 0 && g_aiBuyZoneHigh > 0)
   {
      // Support = zone BUY (bas)
      double supportCenter = (g_aiBuyZoneLow + g_aiBuyZoneHigh) / 2.0;
      if(MathAbs(price - supportCenter) <= touchTolerance)
         nearSupport = true;
   }
   if(g_aiSellZoneLow > 0 && g_aiSellZoneHigh > 0)
   {
      // Résistance = zone SELL (haut)
      double resistanceCenter = (g_aiSellZoneLow + g_aiSellZoneHigh) / 2.0;
      if(MathAbs(price - resistanceCenter) <= touchTolerance)
         nearResistance = true;
   }
   
   // 4. Détecter les touches de trendlines haussières (support) -> BUY
   bool touchBullH1 = (bullH1 > 0 && MathAbs(price - bullH1) <= touchTolerance);
   bool touchBullM15 = (bullM15 > 0 && MathAbs(price - bullM15) <= touchTolerance);
   
   // 5. Détecter les touches de trendlines baissières (résistance) -> SELL
   bool touchBearH1 = (bearH1 > 0 && MathAbs(price - bearH1) <= touchTolerance);
   bool touchBearM15 = (bearM15 > 0 && MathAbs(price - bearM15) <= touchTolerance);
   
   // 6. Vérifier la direction autorisée pour ce symbole
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);
   
   // 6.5. Détecter si une touche importante est détectée (pour bypass du cooldown)
   bool hasImportantTouch = (touchBullH1 || touchBullM15 || touchBearH1 || touchBearM15 || nearSupport || nearResistance);
   
   // 7. Exécuter BUY si touche de support/trendline haussière
   if((touchBullH1 || touchBullM15 || nearSupport) && (isBoom || isStepIndex))
   {
      // Vérifier que la tendance est haussière (M15 et H1 alignés)
      double emaFastH1[], emaSlowH1[];
      double emaFastM15[], emaSlowM15[];
      bool h1Uptrend = false;
      bool m15Uptrend = false;
      
      if(h1_ema_fast_handle != INVALID_HANDLE && h1_ema_slow_handle != INVALID_HANDLE)
      {
         if(CopyBuffer(h1_ema_fast_handle, 0, 0, 2, emaFastH1) >= 2 &&
            CopyBuffer(h1_ema_slow_handle, 0, 0, 2, emaSlowH1) >= 2)
         {
            h1Uptrend = (emaFastH1[0] > emaSlowH1[0] && emaFastH1[1] > emaSlowH1[1]);
         }
      }
      
      if(emaFastM15Handle != INVALID_HANDLE && emaSlowM15Handle != INVALID_HANDLE)
      {
         if(CopyBuffer(emaFastM15Handle, 0, 0, 2, emaFastM15) >= 2 &&
            CopyBuffer(emaSlowM15Handle, 0, 0, 2, emaSlowM15) >= 2)
         {
            m15Uptrend = (emaFastM15[0] > emaSlowM15[0] && emaFastM15[1] > emaSlowM15[1]);
         }
      }
      
      // Trader seulement si les deux timeframes sont alignés haussiers
      if(h1Uptrend && m15Uptrend)
      {
         // Vérifier si on peut trader (avec bypass du cooldown si touche importante)
         double confidence = hasImportantTouch ? 0.9 : 0.8;
         bool canTrade = CanOpenNewPosition(ORDER_TYPE_BUY, ask, hasImportantTouch, confidence);
         if(!canTrade && !hasImportantTouch)
            return; // Pas de touche importante, respecter le cooldown
         
         string comment = "AUTO_TRENDLINE_BUY";
         if(touchBullH1) comment += "_H1";
         if(touchBullM15) comment += "_M15";
         if(nearSupport) comment += "_SUPPORT";
         if(hasImportantTouch && IsSymbolLossCooldownActive(1800))
            comment += "_BYPASS_COOLDOWN";
         
         Print("🚀 TOUCHE TRENDLINE/SUPPORT DÉTECTÉE - BUY automatique (confiance: ", DoubleToString(confidence*100,0), "%)", 
               (hasImportantTouch && IsSymbolLossCooldownActive(1800)) ? " (BYPASS COOLDOWN)" : "");
         if(ExecuteTradeWithATR(ORDER_TYPE_BUY, atr[0], ask, comment, confidence, false, hasImportantTouch && IsSymbolLossCooldownActive(1800)))
         {
            lastTradeTime = now;
            if(AI_UseNotifications)
            {
               string msg = StringFormat("Trade BUY automatique: Touche %s à %.5f", 
                                        (touchBullH1 ? "trendline H1" : (touchBullM15 ? "trendline M15" : "support")), price);
               SendNotification(msg);
            }
         }
      }
   }
   
   // 8. Exécuter SELL si touche de résistance/trendline baissière
   if((touchBearH1 || touchBearM15 || nearResistance) && (isCrash || isStepIndex))
   {
      // Vérifier que la tendance est baissière (M15 et H1 alignés)
      double emaFastH1[], emaSlowH1[];
      double emaFastM15[], emaSlowM15[];
      bool h1Downtrend = false;
      bool m15Downtrend = false;
      
      if(h1_ema_fast_handle != INVALID_HANDLE && h1_ema_slow_handle != INVALID_HANDLE)
      {
         if(CopyBuffer(h1_ema_fast_handle, 0, 0, 2, emaFastH1) >= 2 &&
            CopyBuffer(h1_ema_slow_handle, 0, 0, 2, emaSlowH1) >= 2)
         {
            h1Downtrend = (emaFastH1[0] < emaSlowH1[0] && emaFastH1[1] < emaSlowH1[1]);
         }
      }
      
      if(emaFastM15Handle != INVALID_HANDLE && emaSlowM15Handle != INVALID_HANDLE)
      {
         if(CopyBuffer(emaFastM15Handle, 0, 0, 2, emaFastM15) >= 2 &&
            CopyBuffer(emaSlowM15Handle, 0, 0, 2, emaSlowM15) >= 2)
         {
            m15Downtrend = (emaFastM15[0] < emaSlowM15[0] && emaFastM15[1] < emaSlowM15[1]);
         }
      }
      
      // Trader seulement si les deux timeframes sont alignés baissiers
      if(h1Downtrend && m15Downtrend)
      {
         // Vérifier si on peut trader (avec bypass du cooldown si touche importante)
         double confidence = hasImportantTouch ? 0.9 : 0.8;
         bool canTrade = CanOpenNewPosition(ORDER_TYPE_SELL, bid, hasImportantTouch, confidence);
         if(!canTrade && !hasImportantTouch)
            return; // Pas de touche importante, respecter le cooldown
         
         string comment = "AUTO_TRENDLINE_SELL";
         if(touchBearH1) comment += "_H1";
         if(touchBearM15) comment += "_M15";
         if(nearResistance) comment += "_RESISTANCE";
         if(hasImportantTouch && IsSymbolLossCooldownActive(1800))
            comment += "_BYPASS_COOLDOWN";
         
         Print("🚀 TOUCHE TRENDLINE/RÉSISTANCE DÉTECTÉE - SELL automatique (confiance: ", DoubleToString(confidence*100,0), "%)",
               (hasImportantTouch && IsSymbolLossCooldownActive(1800)) ? " (BYPASS COOLDOWN)" : "");
         if(ExecuteTradeWithATR(ORDER_TYPE_SELL, atr[0], bid, comment, confidence, false, hasImportantTouch && IsSymbolLossCooldownActive(1800)))
         {
            lastTradeTime = now;
            if(AI_UseNotifications)
            {
               string msg = StringFormat("Trade SELL automatique: Touche %s à %.5f", 
                                        (touchBearH1 ? "trendline H1" : (touchBearM15 ? "trendline M15" : "résistance")), price);
               SendNotification(msg);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Stratégie de rebond entre zones IA BUY/SELL                      |
//| - Attend que le prix touche une zone (CheckAIZoneAlerts)        |
//| - Puis confirme le rebond avec des bougies M5                    |
//| - Ouvre un trade vers le milieu entre les deux zones             |
//+------------------------------------------------------------------+
void EvaluateAIZoneBounceStrategy()
{
   if(!UseAIZoneBounceStrategy || !AI_AutoExecuteTrades)
      return;

   // Sécurité globale : limite dynamique selon le type de symbole
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   int maxPerSymbol = isBoomCrashSymbol ? 3 : 2;
   if(!CanOpenNewPosition(ORDER_TYPE_SELL, SymbolInfoDouble(_Symbol, SYMBOL_BID), false, 0.7) || CountPositionsForSymbolMagic() >= maxPerSymbol)
      return;

   // S'assurer que les deux zones sont définies pour pouvoir calculer le milieu
   if(!(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
        g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0))
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0)
      return;
   double price = (bid + ask) / 2.0;

   // Charger les bougies M5 pour détecter le rebond
   // On exige au moins 3 bougies pour une structure de retournement plus fiable
   int neededBars = MathMax(3, AIZoneConfirmBarsM5);
   MqlRates ratesM5[];
   if(CopyRates(_Symbol, PERIOD_M5, 0, neededBars + 1, ratesM5) <= neededBars)
      return;

   // Helper local pour tester "rebond haussier" / "rebond baissier"
   bool bullishConfirm = true;
   bool bearishConfirm = true;
   for(int i = 0; i < neededBars; i++)
   {
      // i=0 => bougie la plus récente
      double o = ratesM5[i].open;
      double c = ratesM5[i].close;
      if(!(c > o))
         bullishConfirm = false;
      if(!(c < o))
         bearishConfirm = false;
   }

   // EMA M5 pour filtrer les faux rebonds (éviter de trader une simple correction)
   double emaM5Buf[];
   if(CopyBuffer(emaFastM5Handle, 0, 0, 1, emaM5Buf) <= 0)
      return;
   double emaM5 = emaM5Buf[0];

   // Filtre cassure de trendlines H1/M15
   double tlTolerance = AIZoneTrendlineBreakTolerance * _Point;

   // Récupérer la valeur des trendlines H1 au prix courant
   double bullH1 = 0.0, bearH1 = 0.0;
   if(ObjectFind(0, "AI_H1_BULL_TL") >= 0)
      bullH1 = ObjectGetValueByTime(0, "AI_H1_BULL_TL", TimeCurrent(), 0);
   if(ObjectFind(0, "AI_H1_BEAR_TL") >= 0)
      bearH1 = ObjectGetValueByTime(0, "AI_H1_BEAR_TL", TimeCurrent(), 0);

   // Trendlines M15 optionnelles (si tu les ajoutes plus tard)
   double bullM15 = 0.0, bearM15 = 0.0;
   if(ObjectFind(0, "AI_M15_BULL_TL") >= 0)
      bullM15 = ObjectGetValueByTime(0, "AI_M15_BULL_TL", TimeCurrent(), 0);
   if(ObjectFind(0, "AI_M15_BEAR_TL") >= 0)
      bearM15 = ObjectGetValueByTime(0, "AI_M15_BEAR_TL", TimeCurrent(), 0);

   bool buyTrendlineBroken = false;
   bool sellTrendlineBroken = false;

   // Cassure baissière des trendlines haussières (pour SELL)
   if(bullH1 > 0 && price < bullH1 - tlTolerance) sellTrendlineBroken = true;
   if(bullM15 > 0 && price < bullM15 - tlTolerance) sellTrendlineBroken = true;

   // Cassure haussière des trendlines baissières (pour BUY)
   if(bearH1 > 0 && price > bearH1 + tlTolerance) buyTrendlineBroken = true;
   if(bearM15 > 0 && price > bearM15 + tlTolerance) buyTrendlineBroken = true;

   // Centres des zones et cible au milieu
   double buyCenter  = (g_aiBuyZoneLow  + g_aiBuyZoneHigh)  * 0.5;
   double sellCenter = (g_aiSellZoneLow + g_aiSellZoneHigh) * 0.5;
   double midTarget  = (buyCenter + sellCenter) * 0.5;

   double atr[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
      return;

   // BUY après rebond dans la BUY zone (le prix repart vers le haut)
   // Conditions supplémentaires :
   //  - dernière bougie M5 clôture au-dessus du milieu de la BUY zone
   //  - prix actuel proche de la limite inférieure de la BUY zone
   midTarget = (g_aiBuyZoneLow + g_aiSellZoneHigh) * 0.5;
   if(bid > midTarget && bid < g_aiBuyZoneLow + (g_aiBuyZoneHigh - g_aiBuyZoneLow) * 0.2)
   {
      if(AI_UseNotifications)
      {
         string msg = StringFormat("AI BUY ZONE BOUNCE sur %s\nPrix: %.5f\nSL: %.5f\nTP: %.5f", 
                     _Symbol, ask, g_aiBuyZoneLow, midTarget);
         SendNotification(msg);
      }
      
      // Ouvrir position BUY avec SL/TP basés sur les zones
      double stopDistance = ask - g_aiBuyZoneLow;
      double lot = CalculateLotSize(stopDistance);
      if(lot > 0 && ExecuteTrade(ORDER_TYPE_BUY, lot, 0, 0, "AI_BUY_ZONE_BOUNCE"))
      {
         // Modifier SL/TP de la position ouverte
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket))
            {
               if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
               {
                  double slLevel = NormalizeDouble(g_aiBuyZoneLow, _Digits);   // bord inférieur rectangle vert
                  double tpLevel = NormalizeDouble(midTarget, _Digits);        // milieu entre BUY et SELL zones
                  trade.PositionModify(ticket, slLevel, tpLevel);
               }
            }
            g_aiBuyTrendActive  = true;
            g_aiSellTrendActive = false;
         }
      }
      g_aiBuyZoneArmed = false;
   }

   // SELL après rebond dans la SELL zone (le prix repart vers le bas)
   // Conditions supplémentaires :
   //  - dernière bougie M5 clôture en-dessous du milieu de la SELL zone
   //  - prix actuel proche de la limite supérieure de la SELL zone
   if(ask < midTarget && ask > g_aiSellZoneHigh - (g_aiSellZoneHigh - g_aiSellZoneLow) * 0.2)
   {
      if(AI_UseNotifications)
      {
         string msg = StringFormat("AI SELL ZONE BOUNCE sur %s\nPrix: %.5f\nSL: %.5f\nTP: %.5f", 
                     _Symbol, bid, g_aiSellZoneHigh, midTarget);
         SendNotification(msg);
      }
      
      // Ouvrir position SELL avec SL/TP basés sur les zones
      double stopDistance = g_aiSellZoneHigh - bid;
      double lot = CalculateLotSize(stopDistance);
      if(lot > 0 && ExecuteTrade(ORDER_TYPE_SELL, lot, 0, 0, "AI_SELL_ZONE_BOUNCE"))
      {
         // Modifier SL/TP de la position ouverte
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionSelectByTicket(ticket))
            {
               if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
               {
                  double slLevel = NormalizeDouble(g_aiSellZoneHigh, _Digits); // bord supérieur rectangle rouge
                  double tpLevel = NormalizeDouble(midTarget, _Digits);
                  trade.PositionModify(ticket, slLevel, tpLevel);
               }
            }
            g_aiBuyTrendActive  = false;
            g_aiSellTrendActive = true;
         }
      }
      g_aiSellZoneArmed = false;
   }

   // SELL après rebond dans la SELL zone (le prix repart vers le bas)
   // Conditions supplémentaires :
   //  - dernière bougie M5 clôture en-dessous du milieu de la SELL zone
   //  - dernière clôture en-dessous de l'EMA M5
   //  - cassure des trendlines haussières H1/M15 avec tolérance
   if(g_aiSellZoneArmed && bearishConfirm &&
      price < g_aiSellZoneHigh && price >= g_aiSellZoneLow &&
      ratesM5[0].close < sellCenter &&
      ratesM5[0].close < emaM5 &&
      sellTrendlineBroken)
   {
      if(IsTradingTimeAllowed() && !IsDrawdownExceeded())
      {
         string comment = "AIZONE_SELL_BOUNCE";
         if(ExecuteTradeWithATR(ORDER_TYPE_SELL, atr[0], bid, comment, 1.0, false))
         {
            // Ajuster TP au milieu des zones et SL au bord supérieur de la SELL zone
            for(int j = PositionsTotal() - 1; j >= 0; j--)
            {
               ulong ticket = PositionGetTicket(j);
               if(ticket > 0 && PositionSelectByTicket(ticket))
               {
                  if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                  {
                     double slLevel = NormalizeDouble(g_aiSellZoneHigh, _Digits); // bord supérieur rectangle rouge
                     double tpLevel = NormalizeDouble(midTarget, _Digits);
                     trade.PositionModify(ticket, slLevel, tpLevel);
                     break; // Sortir après avoir modifié la première position trouvée
                  }
               }
            }

            if(AI_UseNotifications)
            {
               string msg = StringFormat("AI SELL ZONE: rebond confirmé (%d bougies M5). Trade SELL ouvert, TP au milieu des zones: %.5f",
                                         neededBars, midTarget);
               SendNotification(msg);
            }
            g_aiSellTrendActive = true;
            g_aiBuyTrendActive  = false;
         }
      }
      g_aiSellZoneArmed = false;
   }

   // -----------------------------------------------------------------
   // Cas 2 : Cassure franche de la zone -> trade dans le sens tendance
   // -----------------------------------------------------------------

   // Cassure BAISSIÈRE de la BUY zone => SELL de continuation (scalping)
   if(g_aiBuyZoneArmed && bearishConfirm && price < g_aiBuyZoneLow)
   {
      if(IsTradingTimeAllowed() && !IsDrawdownExceeded())
      {
         string comment = "AIZONE_BUY_BREAK_SELL";
         if(ExecuteTradeWithATR(ORDER_TYPE_SELL, atr[0], bid, comment, 1.0, false))
         {
            // SL au-dessus du bord inférieur de la BUY zone, TP au milieu
            for(int j = PositionsTotal() - 1; j >= 0; j--)
            {
               ulong ticket = PositionGetTicket(j);
               if(ticket > 0 && PositionSelectByTicket(ticket))
               {
                  if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                  {
                     double slLevel = NormalizeDouble(g_aiBuyZoneLow, _Digits);   // quelques points au-dessus seront ajustés par ValidateAndAdjustStops
                     double tpLevel = NormalizeDouble(midTarget, _Digits);
                     trade.PositionModify(ticket, slLevel, tpLevel);
                     break; // Sortir après avoir modifié la première position trouvée
                  }
               }
            }

            if(AI_UseNotifications)
            {
               string msg = StringFormat("AI BUY ZONE cassée à la baisse. Rebond absent, SELL de tendance ouvert (scalping). Prix: %.5f",
                                         price);
               SendNotification(msg);
            }
            g_aiSellTrendActive = true;
            g_aiBuyTrendActive  = false;
         }
      }
      g_aiBuyZoneArmed = false;
   }

   // Cassure HAUSSIÈRE de la SELL zone => BUY de continuation
   if(g_aiSellZoneArmed && bullishConfirm && price > g_aiSellZoneHigh)
   {
      if(IsTradingTimeAllowed() && !IsDrawdownExceeded())
      {
         string comment = "AIZONE_SELL_BREAK_BUY";
         if(ExecuteTradeWithATR(ORDER_TYPE_BUY, atr[0], ask, comment, 1.0, false))
         {
            // SL en dessous du bord supérieur de la SELL zone, TP au milieu
            for(int j = PositionsTotal() - 1; j >= 0; j--)
            {
               ulong ticket = PositionGetTicket(j);
               if(ticket > 0 && PositionSelectByTicket(ticket))
               {
                  if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                  {
                     double slLevel = NormalizeDouble(g_aiSellZoneHigh, _Digits);
                     double tpLevel = NormalizeDouble(midTarget, _Digits);
                     trade.PositionModify(ticket, slLevel, tpLevel);
                     break; // Sortir après avoir modifié la première position trouvée
                  }
               }
            }

            if(AI_UseNotifications)
            {
               string msg = StringFormat("AI SELL ZONE cassée à la hausse. Rebond absent, BUY de tendance ouvert (scalping). Prix: %.5f",
                                         price);
               SendNotification(msg);
            }
            g_aiBuyTrendActive  = true;
            g_aiSellTrendActive = false;
         }
      }
      g_aiSellZoneArmed = false;
   }
}

//+------------------------------------------------------------------+
//| BOOM/CRASH : scalp agressif sur rebond propre en zone IA         |
//| - S'applique uniquement aux symboles Boom/Crash                   |
//| - Ne demande PAS que les deux zones (BUY & SELL) soient définies |
//| - Confirmation simple : X bougies dans le sens du rebond sur TF  |
//|   configurable (par défaut M15, adapté à Boom 1000 M15)          |
//| - TP / SL fixes en points, indépendants de l'ATR                 |
//+------------------------------------------------------------------+
void EvaluateBoomCrashZoneScalps()
{
   if(!UseBoomCrashZoneScalps || !AI_AutoExecuteTrades)
      return;

   // Uniquement pour Boom/Crash
   bool isBoom  = (StringFind(_Symbol, "Boom")  != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   if(!isBoom && !isCrash)
      return;

   // Respecter les limites globales (3 positions max pour Boom/Crash)
   int maxPerSymbol = 3;
   if(!CanOpenNewPosition(ORDER_TYPE_SELL, SymbolInfoDouble(_Symbol, SYMBOL_BID), false, 0.7) || CountPositionsForSymbolMagic() >= maxPerSymbol)
      return;
   if(!IsTradingTimeAllowed() || IsDrawdownExceeded())
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0)
      return;
   double price = (bid + ask) * 0.5;

   // Charger les bougies sur le TF de confirmation (par défaut M15)
   int neededBars = MathMax(1, BC_ConfirmBars);
   MqlRates ratesConf[];
   if(CopyRates(_Symbol, BC_ConfirmTF, 0, neededBars + 1, ratesConf) <= neededBars)
      return;

   // Helpers : confirmation haussière / baissière simple
   bool bullishConfirm = true;
   bool bearishConfirm = true;
   for(int i = 0; i < neededBars; i++)
   {
      double o = ratesConf[i].open;
      double c = ratesConf[i].close;
      if(!(c > o))
         bullishConfirm = false;
      if(!(c < o))
         bearishConfirm = false;
   }

   // Récupérer ATR pour la taille de lot (mais TP/SL seront fixes)
   double atrBuf[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) <= 0)
      return;
   double atr = atrBuf[0];

   // Taille fixe SL/TP en points
   double tpDist = BC_TP_Points * _Point;
   double slDist = BC_SL_Points * _Point;

   // -------------------------- BUY SCALP ---------------------------
   // - Rebond propre dans BUY zone
   // - Pour Boom : BUY uniquement
   bool inBuyZone = (g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
                     price >= g_aiBuyZoneLow && price <= g_aiBuyZoneHigh);

   if(inBuyZone && g_aiBuyZoneArmed && bullishConfirm && isBoom && (!UseSupertrendFilter || GetSupertrendDir()==1))
   {
      // Vérifier la confirmation M5 pour les marchés Boom
      if(!CanBuyWithM5Confirmation(_Symbol))
         return;
         
      // Vérifier s'il n'y a pas déjà une position ouverte sur ce symbole
      if(CountPositionsForSymbolMagic() > 0)
      {
         Print("Position déjà ouverte sur ", _Symbol, " - Achat Boom annulé");
         return;
      }
      
      ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
      double entryPrice = ask;

      if(ExecuteTradeWithATR(orderType, atr, entryPrice, "BC_ZONE_BUY_SCALP", 1.0, false))
      {
         // Ajuster TP/SL immédiatement après ouverture: TP/SL FIXES
         for(int j = PositionsTotal() - 1; j >= 0; j--)
         {
            ulong ticket = PositionGetTicket(j);
            if(ticket > 0 && PositionSelectByTicket(ticket))
            {
               if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
               {
                  double sl = NormalizeDouble(entryPrice - slDist, _Digits);
                  double tp = NormalizeDouble(entryPrice + tpDist, _Digits);
                  trade.PositionModify(ticket, sl, tp);
                  break; // Sortir après avoir modifié la première position trouvée
               }
            }
         }

         if(AI_UseNotifications)
         {
            string msg = StringFormat("Boom BUY zone scalp: rebond confirmé (%d bougie(s) %s). TP fixe: +%d pts",
                                      neededBars,
                                      EnumToString(BC_ConfirmTF),
                                      BC_TP_Points);
            SendNotification(msg);
         }

         // On désarme la zone pour éviter les doublons
         g_aiBuyZoneArmed = false;
      }
   }

   // -------------------------- SELL SCALP --------------------------
   // - Rebond propre dans SELL zone
   // - Pour Crash : SELL uniquement
   bool inSellZone = (g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0 &&
                      price >= g_aiSellZoneLow && price <= g_aiSellZoneHigh);

   if(inSellZone && g_aiSellZoneArmed && bearishConfirm && isCrash && (!UseSupertrendFilter || GetSupertrendDir()==-1))
   {
      ENUM_ORDER_TYPE orderType = ORDER_TYPE_SELL;
      double entryPrice = bid;

      if(ExecuteTradeWithATR(orderType, atr, entryPrice, "BC_ZONE_SELL_SCALP", 1.0, false))
      {
         for(int j = PositionsTotal() - 1; j >= 0; j--)
         {
            ulong ticket = PositionGetTicket(j);
            if(ticket > 0 && PositionSelectByTicket(ticket))
            {
               if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
               {
                  double sl = NormalizeDouble(entryPrice + slDist, _Digits);
                  double tp = NormalizeDouble(entryPrice - tpDist, _Digits);
                  trade.PositionModify(ticket, sl, tp);
                  break; // Sortir après avoir modifié la première position trouvée
               }
            }
         }

         if(AI_UseNotifications)
         {
            string msg = StringFormat("Crash SELL zone scalp: rebond confirmé (%d bougie(s) %s). TP fixe: +%d pts",
                                      neededBars,
                                      EnumToString(BC_ConfirmTF),
                                      BC_TP_Points);
            SendNotification(msg);
         }

         g_aiSellZoneArmed = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Scalping EMA50 sur mouvement en cours                           |
//| - Après rebond/cassure, utilise les retours vers l'EMA M5       |
//+------------------------------------------------------------------+
void EvaluateAIZoneEMAScalps()
{
   if(!UseAIZoneBounceStrategy || !AI_AutoExecuteTrades)
      return;

   // Contexte : tendance active (BUY ou SELL)
   if(!g_aiBuyTrendActive && !g_aiSellTrendActive)
      return;

   // Respecter limites globales et par symbole
   if(!CanOpenNewPosition(ORDER_TYPE_BUY, SymbolInfoDouble(_Symbol, SYMBOL_ASK), false, 0.7) || CountPositionsForSymbolMagic() >= 2)
      return;

   // Cooldown entre deux scalps
   if(g_aiLastScalpTime != 0 && (TimeCurrent() - g_aiLastScalpTime) < AIZoneScalpCooldownSec)
      return;

   // Zones nécessaires pour calculer TP/SL
   if(!(g_aiBuyZoneLow > 0.0 && g_aiBuyZoneHigh > 0.0 &&
        g_aiSellZoneLow > 0.0 && g_aiSellZoneHigh > 0.0))
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0)
      return;
   double price = (bid + ask) / 2.0;

   // EMA M5 (période configurable, par défaut 50)
   double emaBuf[];
   int handle = emaFastM5Handle;
   if(AIZoneScalpEMAPeriodM5 != EMA_Fast)
      handle = iMA(_Symbol, PERIOD_M5, AIZoneScalpEMAPeriodM5, 0, MODE_EMA, PRICE_CLOSE);

   if(handle == INVALID_HANDLE || CopyBuffer(handle, 0, 0, 1, emaBuf) <= 0)
      return;

   double ema = emaBuf[0];
   double tolerance = AIZoneScalpEMAToleranceP * _Point;

   // Cible commune : milieu des deux zones
   double buyCenter  = (g_aiBuyZoneLow  + g_aiBuyZoneHigh)  * 0.5;
   double sellCenter = (g_aiSellZoneLow + g_aiSellZoneHigh) * 0.5;
   double midTarget  = (buyCenter + sellCenter) * 0.5;

   double atr[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
      return;

   // BUY scalp : tendance haussière active + pullback vers EMA
   if(g_aiBuyTrendActive && MathAbs(price - ema) <= tolerance && (!UseSupertrendFilter || GetSupertrendDir()==1))
   {
      // Vérifier la confirmation M5 pour les marchés Boom
      if(!CanBuyWithM5Confirmation(_Symbol))
         return;
         
      if(IsTradingTimeAllowed() && !IsDrawdownExceeded())
      {
         string comment = "AIZONE_EMA_BUY_SCALP";
         if(ExecuteTradeWithATR(ORDER_TYPE_BUY, atr[0], ask, comment, 1.0, false))
         {
            for(int j = PositionsTotal() - 1; j >= 0; j--)
            {
               ulong ticket = PositionGetTicket(j);
               if(ticket > 0 && PositionSelectByTicket(ticket))
               {
                  if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                  {
                     double slLevel = NormalizeDouble(g_aiBuyZoneLow, _Digits);
                     double tpLevel = NormalizeDouble(midTarget, _Digits);
                     trade.PositionModify(ticket, slLevel, tpLevel);
                     break; // Sortir après avoir modifié la première position trouvée
                  }
               }
            }
            g_aiLastScalpTime = TimeCurrent();
         }
      }
   }

   // SELL scalp : tendance baissière active + pullback vers EMA
   if(g_aiSellTrendActive && MathAbs(price - ema) <= tolerance && (!UseSupertrendFilter || GetSupertrendDir()==-1))
   {
      if(IsTradingTimeAllowed() && !IsDrawdownExceeded())
      {
         string comment = "AIZONE_EMA_SELL_SCALP";
         if(ExecuteTradeWithATR(ORDER_TYPE_SELL, atr[0], bid, comment, 1.0, false))
         {
            for(int j = PositionsTotal() - 1; j >= 0; j--)
            {
               ulong ticket = PositionGetTicket(j);
               if(ticket > 0 && PositionSelectByTicket(ticket))
               {
                  if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                  {
                     double slLevel = NormalizeDouble(g_aiSellZoneHigh, _Digits);
                     double tpLevel = NormalizeDouble(midTarget, _Digits);
                     trade.PositionModify(ticket, slLevel, tpLevel);
                     break; // Sortir après avoir modifié la première position trouvée
                  }
               }
            }
            g_aiLastScalpTime = TimeCurrent();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie si un signal d'entrée est valide et cohérent avec l'IA   |
//| VALIDATION RENFORCÉE : Signaux vérifiés et validés à 100%        |
//+------------------------------------------------------------------+
bool IsValidSignal(ENUM_ORDER_TYPE type, double confidence = 1.0)
{
   g_lastValidationReason = "";
   int validationScore = 0;  // Score de validation (doit atteindre 100 pour valider)
   int maxScore = 100;
   string rejectionReasons = "";
   bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   
   // AUDIT: Ajuster le seuil dynamiquement pour Boom/Crash (plus réactif)
   int effectiveMinScore = SignalValidationMinScore;
   if(isBoomCrash) effectiveMinScore = 70;  // Plus permissif pour capter les spikes
   
   // ========== VALIDATION 1: COHÉRENCE IA (20 points) ==========
   if(UseAI_Agent)
   {
      if(g_lastAIAction == "")
      {
         rejectionReasons += "IA non disponible; ";
         g_lastValidationReason = rejectionReasons;
         return false; // Rejet immédiat si IA activée mais pas de réponse
      }
      
      bool aiAgrees = false;
      string aiActionUpper = g_lastAIAction;
      StringToUpper(aiActionUpper);
      
      if((type == ORDER_TYPE_BUY && (aiActionUpper == "BUY" || aiActionUpper == "ACHAT")) ||
         (type == ORDER_TYPE_SELL && (aiActionUpper == "SELL" || aiActionUpper == "VENTE")))
      {
         aiAgrees = true;
         validationScore += 10; // +10 si direction cohérente
      }
      else
      {
         rejectionReasons += "IA en désaccord (" + g_lastAIAction + "); ";
         // Pour Boom/Crash on bloque, pour le reste (Forex, indices) on laisse passer si AI_CanBlockTrades=false
         if(isBoomCrash || AI_CanBlockTrades)
         {
            g_lastValidationReason = rejectionReasons;
            return false; // Rejet si IA n'est pas d'accord
         }
      }
      
      // Confiance IA élevée requise (minimum 0.7 pour validation complète)
      if(g_lastAIConfidence >= 0.7)
      {
         validationScore += 10; // +10 si confiance élevée
      }
      else if(g_lastAIConfidence < AI_MinConfidence)
      {
         rejectionReasons += "Confiance IA trop faible (" + DoubleToString(g_lastAIConfidence, 2) + "); ";
         // Pour Boom/Crash ou si AI_CanBlockTrades=true, on bloque ; sinon on laisse passer mais avec moins de points
         if(isBoomCrash || AI_CanBlockTrades)
         {
            g_lastValidationReason = rejectionReasons;
            return false; // Rejet si confiance trop faible
         }
      }
      else
      {
         validationScore += 5; // +5 si confiance moyenne
      }
   }
   else
   {
      validationScore += 20; // Si IA désactivée, on donne les points
   }
   
   // ========== VALIDATION 2: CONDITIONS DE MARCHÉ (15 points) ==========
   // Vérifier le spread
   double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
   if(spread > MaxSpreadPoints * _Point)
   {
      rejectionReasons += "Spread trop élevé (" + DoubleToString(spread, 5) + "); ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   validationScore += 5; // Spread acceptable
   
   // Vérifier la volatilité
   double atr[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1)
   {
      rejectionReasons += "ATR indisponible; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   if(atr[0] >= MinATR && atr[0] <= MaxATR)
   {
      validationScore += 10; // Volatilité dans la plage optimale
   }
   else
   {
      rejectionReasons += "Volatilité hors plage (ATR=" + DoubleToString(atr[0], 5) + "); ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // ========== VALIDATION 3: INDICATEURS MULTI-TIMEFRAME ADAPTATIF (25 points) ==========
   // MODE ADAPTATIF: Si IA haute confiance (>80%), on se base principalement sur H1
   // MODE STRICT: H1 + M5 doivent être alignés, puis on vérifie M1 pour l'entrée
   double rsi[], rsiM1[];
   double emaFastH1[], emaSlowH1[];
   double emaFastM5[], emaSlowM5[];
   double emaFastM1[], emaSlowM1[];
   
   // Récupérer RSI
   if(CopyBuffer(rsiHandle, 0, 0, 3, rsi) < 3 ||
      CopyBuffer(rsiHandle, 0, 0, 3, rsiM1) < 3)
   {
      rejectionReasons += "RSI indisponible; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // Récupérer EMA H1, M5 et M1
   if(CopyBuffer(emaFastHandle,   0, 0, 3, emaFastH1)  < 3 ||
      CopyBuffer(emaSlowHandle,   0, 0, 3, emaSlowH1)  < 3 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 3, emaFastM5)  < 3 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 3, emaSlowM5)  < 3 ||
      CopyBuffer(emaFastEntryHandle,0,0,3, emaFastM1)  < 3 ||
      CopyBuffer(emaSlowEntryHandle,0,0,3, emaSlowM1)  < 3)
   {
      rejectionReasons += "EMA H1/M5/M1 indisponibles; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // DÉTECTION DE TENDANCE: H1 donne la direction principale
   // H1: tendance de fond (DOIT être claire à 100%)
   bool h1TrendUp   = emaFastH1[0] > emaSlowH1[0] && emaFastH1[1] > emaSlowH1[1] && emaFastH1[2] > emaSlowH1[2];
   bool h1TrendDown = emaFastH1[0] < emaSlowH1[0] && emaFastH1[1] < emaSlowH1[1] && emaFastH1[2] < emaSlowH1[2];
   
   // M5: confirmation intermédiaire
   bool m5TrendUp   = emaFastM5[0] > emaSlowM5[0] && emaFastM5[1] > emaSlowM5[1] && emaFastM5[2] > emaSlowM5[2];
   bool m5TrendDown = emaFastM5[0] < emaSlowM5[0] && emaFastM5[1] < emaSlowM5[1] && emaFastM5[2] < emaSlowM5[2];
   
   // M1: entrée (plus flexible)
   bool m1TrendUp   = emaFastM1[0] > emaSlowM1[0];
   bool m1TrendDown = emaFastM1[0] < emaSlowM1[0];
   
   // BLOCAGE STRICT: Si H1 n'a pas de tendance claire, on ne trade PAS
   if(!h1TrendUp && !h1TrendDown)
   {
      rejectionReasons += "PAS DE TENDANCE CLAIRE EN H1 - ON SE CALME; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // MODE HAUTE CONFIANCE IA: Si confiance > 80%, on se base principalement sur H1
   bool highConfidenceAI = (confidence >= 0.80);
   
   if(highConfidenceAI)
   {
      // MODE HAUTE CONFIANCE: On vérifie seulement H1 et M1 (M5 optionnel)
      if(type == ORDER_TYPE_BUY)
      {
         if(!h1TrendUp)
         {
            rejectionReasons += "INTERDIT: BUY contre tendance H1 baissière (haute confiance IA); ";
            g_lastValidationReason = rejectionReasons;
            return false;
         }
         
         // M1 doit être en accord ou neutre (pas contre-tendance forte)
         if(m1TrendDown)
         {
            rejectionReasons += "M1 contre tendance H1 (haute confiance IA) - ATTENTE; ";
            g_lastValidationReason = rejectionReasons;
            return false;
         }
         
         validationScore += 25; // H1 confirmé + M1 neutre/aligné
      }
      else // SELL
      {
         if(!h1TrendDown)
         {
            rejectionReasons += "INTERDIT: SELL contre tendance H1 haussière (haute confiance IA); ";
            g_lastValidationReason = rejectionReasons;
            return false;
         }
         
         // M1 doit être en accord ou neutre
         if(m1TrendUp)
         {
            rejectionReasons += "M1 contre tendance H1 (haute confiance IA) - ATTENTE; ";
            g_lastValidationReason = rejectionReasons;
            return false;
         }
         
         validationScore += 25; // H1 confirmé + M1 neutre/aligné
      }
   }
   else
   {
      // MODE STANDARD: H1 + M5 doivent être alignés, M1 pour l'entrée
      // BLOCAGE STRICT: Si M5 n'est pas aligné avec H1, on ne trade PAS
      if(h1TrendUp && !m5TrendUp)
      {
         rejectionReasons += "M5 NON ALIGNÉ AVEC H1 (haussier) - ON SE CALME; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      if(h1TrendDown && !m5TrendDown)
      {
         rejectionReasons += "M5 NON ALIGNÉ AVEC H1 (baissier) - ON SE CALME; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      
      // RÈGLE ANTI-CONTRE-TENDANCE: Ne JAMAIS trader contre H1
      if(type == ORDER_TYPE_BUY && h1TrendDown)
      {
         rejectionReasons += "INTERDIT: BUY contre tendance H1 baissière; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      if(type == ORDER_TYPE_SELL && h1TrendUp)
      {
         rejectionReasons += "INTERDIT: SELL contre tendance H1 haussière; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      
      // Validation finale: H1 + M5 + M1 tous alignés
      if(type == ORDER_TYPE_BUY)
      {
         if(!(h1TrendUp && m5TrendUp && m1TrendUp))
         {
            rejectionReasons += "Tendances non 100% alignées (BUY) sur H1/M5/M1 - ON SE CALME; ";
            g_lastValidationReason = rejectionReasons;
            return false;
         }
         validationScore += 25; // Tendances parfaitement alignées
      }
      else // SELL
      {
         if(!(h1TrendDown && m5TrendDown && m1TrendDown))
         {
            rejectionReasons += "Tendances non 100% alignées (SELL) sur H1/M5/M1 - ON SE CALME; ";
            g_lastValidationReason = rejectionReasons;
            return false;
         }
         validationScore += 25; // Tendances parfaitement alignées
      }
   }
   
   // ========== VALIDATION 4: SMC / ORDER BLOCK (20 points) ==========
   if(Use_SMC_OB_Filter)
   {
      bool smcIsBuy = false;
      double smcEntry = 0, smcSL = 0, smcTP = 0, smcAtr = 0;
      string smcReason = "";
      if(!SMC_GenerateSignal(smcIsBuy, smcEntry, smcSL, smcTP, smcReason, smcAtr))
      {
         rejectionReasons += "Pas de setup SMC; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      if((type == ORDER_TYPE_BUY && !smcIsBuy) || (type == ORDER_TYPE_SELL && smcIsBuy))
      {
         rejectionReasons += "SMC oppose la direction; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      validationScore += 20;
   }
   
   // ========== VALIDATION 5: MOMENTUM ET CONVERGENCE (20 points) ==========
   // Vérifier que le momentum est fort (EMA rapide s'éloigne de la lente)
   double emaGapH1 = MathAbs(emaFastH1[0] - emaSlowH1[0]);
   double emaGapM1 = MathAbs(emaFastM1[0] - emaSlowM1[0]);
   double priceH1  = (emaFastH1[0] + emaSlowH1[0]) / 2.0;
   double priceM1  = (emaFastM1[0] + emaSlowM1[0]) / 2.0;
   
   // Le gap doit être significatif (au moins 0.1% du prix)
   double minGapH1 = priceH1 * 0.001;
   double minGapM1 = priceM1 * 0.001;
   
   if(emaGapH1 >= minGapH1 && emaGapM1 >= minGapM1)
   {
      validationScore += 10; // Momentum fort
   }
   else
   {
      rejectionReasons += "Momentum insuffisant (gap EMA trop faible); ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // Vérifier la convergence des indicateurs (tous doivent pointer dans la même direction)
   bool rsiConfirm = (type == ORDER_TYPE_BUY && rsi[0] > 50 && rsiM1[0] > 50) ||
                     (type == ORDER_TYPE_SELL && rsi[0] < 50 && rsiM1[0] < 50);
   
   if(rsiConfirm)
   {
      validationScore += 10; // RSI confirme la direction
   }
   else
   {
      rejectionReasons += "RSI ne confirme pas la direction; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   
   // ========== VALIDATION 5: CONDITIONS TEMPORELLES ET SÉCURITÉ (10 points) ==========
   if(!IsTradingTimeAllowed())
   {
      rejectionReasons += "Hors heures de trading; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   validationScore += 5;
   
   // Vérifier qu'on n'a pas déjà une position ouverte
   if(CountPositionsForSymbolMagic() > 0)
   {
      rejectionReasons += "Position déjà ouverte; ";
      g_lastValidationReason = rejectionReasons;
      return false;
   }
   // Gestion des pertes consécutives sur ce marché (symbole)
   int consecLoss = GetConsecutiveLosses();
   // Règle primordiale: après 3 pertes consécutives, rester loin de ce marché pendant 30 minutes minimum
   if(consecLoss >= 3)
   {
      // Démarrer un cooldown long si pas déjà actif
      if(!IsSymbolLossCooldownActive(1800))
         StartSymbolLossCooldown();
      
      if(IsSymbolLossCooldownActive(1800))
      {
         rejectionReasons += "Cooldown après 3 pertes consécutives (30 min); ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
   }
   // Protection intermédiaire: après au moins 2 pertes consécutives, courte pause de 3 minutes
   else if(consecLoss >= 2)
   {
      if(!IsSymbolLossCooldownActive(180))
         StartSymbolLossCooldown();
      
      if(IsSymbolLossCooldownActive(180))
      {
         rejectionReasons += "Cooldown après pertes (3 min); ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
   }
   validationScore += 5;
   
   // ========== VALIDATION 6: VOLUME ET LIQUIDITÉ (10 points) ==========
   // Vérifier le volume si le filtre est activé
   if(UseVolumeFilter)
   {
      if(!IsVolumeSufficient())
      {
         rejectionReasons += "Volume insuffisant; ";
         g_lastValidationReason = rejectionReasons;
         return false;
      }
      validationScore += 10;
   }
   else
   {
      validationScore += 10; // Si filtre désactivé, on donne les points
   }
   
   // ========== VALIDATION FINALE ==========
   // Le score doit atteindre le seuil minimum (ajusté pour Boom/Crash)
   if(validationScore >= effectiveMinScore)
   {
      Print("✅ SIGNAL VALIDÉ - Score: ", validationScore, "/", maxScore, " (Seuil: ", effectiveMinScore, ") - Type: ", EnumToString(type), 
            " - Confiance IA: ", DoubleToString(g_lastAIConfidence, 2));
      return true;
   }
   else
   {
      g_lastValidationReason = rejectionReasons;
      Print("❌ Signal rejeté - Score: ", validationScore, "/", maxScore, " (Seuil: ", effectiveMinScore, ") - Raisons: ", rejectionReasons);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Vérifie si un stop loss est valide selon les règles du broker    |
//+------------------------------------------------------------------+
bool IsValidStopLoss(string symbol, double entry, double sl, bool isBuy)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   long digits = (long)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   long stopLevel = (long)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = stopLevel * point * 1.5; // Marge de sécurité 50%
   
   double distance = MathAbs(entry - sl);
   
   if(distance < minStopDistance)
   {
      Print("Stop Loss invalide: ", DoubleToString(distance, (int)digits), 
            " (min: ", DoubleToString(minStopDistance, (int)digits), ")");
      return false;
   }
   
   // Vérifier que le stop n'est pas trop éloigné (plus de 5x la distance minimale)
   if(distance > (minStopDistance * 5))
   {
      Print("Stop Loss trop éloigné: ", DoubleToString(distance, (int)digits));
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Compte le nombre d'ordres en attente pour le symbole courant     |
//+------------------------------------------------------------------+
int CountPendingOrdersForSymbol()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket > 0 && OrderSelect(ticket))
      {
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if((orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) &&
            OrderGetString(ORDER_SYMBOL) == _Symbol &&
            OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

// Compte tous les ordres en attente (tous symboles) pour ce Magic
int CountAllPendingOrdersForMagic()
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
//| Trouve l'ordre limit le plus proche du prix actuel               |
//+------------------------------------------------------------------+
ulong FindClosestPendingOrder(double &closestPrice)
{
   ulong closestTicket = 0;
   double minDistance = DBL_MAX;
   double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2.0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket)) continue;
      
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if((orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT) ||
         OrderGetString(ORDER_SYMBOL) != _Symbol ||
         OrderGetInteger(ORDER_MAGIC) != InpMagicNumber)
         continue;
      
      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double distance = MathAbs(orderPrice - currentPrice);
      
      if(distance < minDistance)
      {
         minDistance = distance;
         closestTicket = ticket;
         closestPrice = orderPrice;
      }
   }
   
   return closestTicket;
}

//+------------------------------------------------------------------+
//| Exécute l'ordre limit le plus proche en scalping                  |
//+------------------------------------------------------------------+
bool ExecuteTrade(ENUM_ORDER_TYPE orderType, double lotSize, double sl = 0.0, double tp = 0.0, string comment = "", bool isBoomCrash = false, bool isVol = false, bool isSpike = false)
{
      // Vérification stricte pour Boom 1000
   bool isBoom1000 = (StringFind(_Symbol, "Boom 1000") != -1);
   
   // Vérifier s'il existe déjà une position sur ce symbole
   int existingPositions = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            existingPositions++;
            
            // Pour Boom 1000, on ne veut JAMAIS de doublons
            if(isBoom1000)
            {
               Print("⚠️ Boom 1000: Une position existe déjà - Prévention des doublons activée");
               return false;
            }
            
            // Vérifier si la position existante est dans la même direction
            if((orderType == ORDER_TYPE_BUY && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) ||
               (orderType == ORDER_TYPE_SELL && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY))
            {
               // Fermer la position existante avant d'en ouvrir une nouvelle dans la direction opposée
               CTrade localTrade;
               if(ticket > 0)
               {
                  localTrade.PositionClose(ticket);
                  Print("Fermeture de la position opposée #", ticket, " avant d'ouvrir une nouvelle position");
                  // Attendre un court instant pour que la fermeture soit traitée
                  Sleep(500);
               }
            }
            else
            {
               // Une position dans la même direction existe déjà
               Print("Une position ", EnumToString((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)), " existe déjà sur ", _Symbol);
               return false;
            }
         }
      }
   }
   
   // Log supplémentaire pour le débogage
   Print("Vérification des positions - ", _Symbol, ": ", existingPositions, " position(s) trouvée(s)");
   
   // Pour Boom 1000, on s'assure qu'il n'y a vraiment aucune position
   if(isBoom1000 && existingPositions > 0)
   {
      Print("❌ Boom 1000: Position déjà ouverte - Nouveau trade bloqué");
      return false;
   }
   
   // Vérifier si on peut ouvrir une nouvelle position
   double closestPrice = 0.0;
   ulong closestTicket = FindClosestPendingOrder(closestPrice);
   
   if(closestTicket == 0)
   {
      Print("Aucun ordre en attente trouvé");
      return false;
   }
   
   if(!OrderSelect(closestTicket))
   {
      Print("Échec de la sélection de l'ordre ", closestTicket);
      return false;
   }
   
   // Récupérer les paramètres de l'ordre
   ENUM_ORDER_TYPE currentOrderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   double orderLot = OrderGetDouble(ORDER_VOLUME_CURRENT);
   double orderSl = OrderGetDouble(ORDER_SL);
   double orderTp = OrderGetDouble(ORDER_TP);
   string orderComment = OrderGetString(ORDER_COMMENT);
   
   // Supprimer l'ordre limit
   // Utiliser l'objet trade global pour supprimer l'ordre
   if(!trade.OrderDelete(closestTicket))
   {
      Print("Erreur suppression ordre limit le plus proche: ", GetLastError());
      return false;
   }
   
   // VÉRIFIER LA LIMITE DE POSITIONS AVANT D'OUVRIR (GLOBALE + PAR SYMBOLE)
   // Limite globale: 2 par défaut, 3 pour Boom/Crash
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   int maxPerSymbol = isBoomCrashSymbol ? 3 : 2;
   if(!CanOpenNewPosition(ORDER_TYPE_BUY, SymbolInfoDouble(_Symbol, SYMBOL_ASK), false, 0.7))
   {
      Print("❌ Scalping bloqué: limite globale de positions atteinte");
      return false;
   }

   // Limite par symbole: dynamique selon Boom/Crash ou non
   if(CountPositionsForSymbolMagic() >= maxPerSymbol)
   {
      Print("🛑 Scalping bloqué: ", maxPerSymbol, " positions déjà ouvertes sur ", _Symbol);
      return false;
   }
   
   // Exécuter au marché immédiatement
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool result = false;
   
   if(currentOrderType == ORDER_TYPE_BUY_LIMIT || currentOrderType == ORDER_TYPE_BUY)
   {
      result = trade.Buy(orderLot, _Symbol, ask, orderSl, orderTp, orderComment + "_SCALP");
   }
   else if(currentOrderType == ORDER_TYPE_SELL_LIMIT || currentOrderType == ORDER_TYPE_SELL)
   {
      result = trade.Sell(orderLot, _Symbol, bid, orderSl, orderTp, orderComment + "_SCALP");
   }
   
   if(result)
   {
      Print("Ordre limit le plus proche exécuté en scalping: ", closestTicket, " Prix: ", closestPrice);
   }
   else
   {
      Print("Erreur exécution ordre limit le plus proche: ", trade.ResultRetcode());
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Gère les ordres limit: exécute le plus proche, garde les autres  |
//+------------------------------------------------------------------+
void ManagePendingOrders()
{
   // Ne pas gérer si on a déjà une position ouverte (laisser finir)
   if(CountPositionsForSymbolMagic() > 0)
      return;
   
   int pendingCount = CountPendingOrdersForSymbol();
   
   // Si on a plus de 2 ordres limit, supprimer les plus éloignés
   if(pendingCount > MaxLimitOrdersPerSymbol)
   {
      // Créer un tableau pour stocker les tickets et distances
      ulong tickets[];
      double distances[];
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2.0;
      
      ArrayResize(tickets, pendingCount);
      ArrayResize(distances, pendingCount);
      int idx = 0;
      
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0 || !OrderSelect(ticket)) continue;
         
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if((orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT) ||
            OrderGetString(ORDER_SYMBOL) != _Symbol ||
            OrderGetInteger(ORDER_MAGIC) != InpMagicNumber)
            continue;
         
         double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         tickets[idx] = ticket;
         distances[idx] = MathAbs(orderPrice - currentPrice);
         idx++;
      }
      
      // Trier par distance (tri à bulles simple)
      for(int i = 0; i < idx - 1; i++)
      {
         for(int j = 0; j < idx - i - 1; j++)
         {
            if(distances[j] > distances[j + 1])
            {
               // Échanger distances
               double tempDist = distances[j];
               distances[j] = distances[j + 1];
               distances[j + 1] = tempDist;
               
               // Échanger tickets
               ulong tempTicket = tickets[j];
               tickets[j] = tickets[j + 1];
               tickets[j + 1] = tempTicket;
            }
         }
      }
      
      // Supprimer les ordres les plus éloignés (garder seulement les 2 plus proches)
      for(int i = MaxLimitOrdersPerSymbol; i < idx; i++)
      {
         trade.OrderDelete(tickets[i]);
         Print("Ordre limit éloigné supprimé (max ", MaxLimitOrdersPerSymbol, "): ", tickets[i]);
      }
   }
   
   // Si on a exactement 2 ordres limit et que l'option scalping est activée, exécuter le plus proche
   if(pendingCount == MaxLimitOrdersPerSymbol && ExecuteClosestLimitForScalping)
   {
      ExecuteClosestPendingOrder();
   }
}

//+------------------------------------------------------------------+
//| Exécute l'ordre en attente le plus proche du prix actuel        |
//+------------------------------------------------------------------+
bool ExecuteClosestPendingOrder()
{
   double closestPrice = 0.0;
   ulong closestTicket = FindClosestPendingOrder(closestPrice);
   
   if(closestTicket == 0)
   {
      Print("Aucun ordre en attente trouvé pour exécution");
      return false;
   }
   
   if(!OrderSelect(closestTicket))
   {
      Print("Échec de la sélection de l'ordre ", closestTicket);
      return false;
   }
   
   // Récupérer les paramètres de l'ordre
   ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   double orderLot = OrderGetDouble(ORDER_VOLUME_CURRENT);
   double orderSl = OrderGetDouble(ORDER_SL);
   double orderTp = OrderGetDouble(ORDER_TP);
   string orderComment = OrderGetString(ORDER_COMMENT);
   
   // Supprimer l'ordre en attente
   // Utiliser l'objet trade global pour supprimer l'ordre
   if(!trade.OrderDelete(closestTicket))
   {
      Print("Erreur lors de la suppression de l'ordre ", closestTicket, ": ", GetLastError());
      return false;
   }
   
   // VÉRIFIER LA LIMITE DE POSITIONS AVANT D'OUVRIR (GLOBALE + PAR SYMBOLE)
   // Limite globale: 2 par défaut, 3 pour Boom/Crash
   bool isBoomCrashSymbol = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   int maxPerSymbol = isBoomCrashSymbol ? 3 : 2;
   if(!CanOpenNewPosition(ORDER_TYPE_BUY, SymbolInfoDouble(_Symbol, SYMBOL_ASK), false, 0.7))
   {
      Print("❌ Scalping bloqué: limite globale de positions atteinte");
      return false;
   }

   // Limite par symbole: dynamique selon Boom/Crash ou non
   if(CountPositionsForSymbolMagic() >= maxPerSymbol)
   {
      Print("🛑 Scalping bloqué: ", maxPerSymbol, " positions déjà ouvertes sur ", _Symbol);
      return false;
   }
   
   // Exécuter au marché immédiatement
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool result = false;
   
   if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY)
   {
      result = trade.Buy(orderLot, _Symbol, ask, orderSl, orderTp, orderComment + "_EXECUTED");
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL)
   {
      result = trade.Sell(orderLot, _Symbol, bid, orderSl, orderTp, orderComment + "_EXECUTED");
   }
   
   if(result)
   {
      Print("Ordre en attente exécuté: ", closestTicket, " Type: ", EnumToString(orderType), " Prix: ", closestPrice);
   }
   else
   {
      Print("Échec de l'exécution de l'ordre ", closestTicket, ": ", trade.ResultRetcode());
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Valide et ajuste les SL/TP selon les distances minimales du broker |
//+------------------------------------------------------------------+
bool ValidateAndAdjustStops(string symbol, ENUM_ORDER_TYPE type, double &executionPrice, double &sl, double &tp)
{
   // Récupérer les paramètres de distance minimale du broker
   long stopLevel   = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long freezeLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   
   // Distance minimale plus robuste
   long minPoints = stopLevel;
   if(minPoints < freezeLevel) minPoints = freezeLevel;
   minPoints += 5; // Marge de sécurité supplémentaire
   if(minPoints < 1) minPoints = 1; // Minimum 1 point
   
   // Gestion spécifique pour le Step Index
   bool isStepIndex = (StringFind(symbol, "Step Index") != -1);
   if(isStepIndex)
   {
      // Pour le Step Index, nous utilisons une distance minimale plus précise
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double minStep = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      
      // Vérification des valeurs de point et minStep
      if(point > 0 && minStep > 0)
      {
         double stepIndexMinPoints = minStep / point;
         if(minPoints < stepIndexMinPoints) 
         {
            minPoints = (long)MathCeil(stepIndexMinPoints);
            Print("🔧 Step Index : distance stop minimale ajustée à ", minPoints, " points (", minStep, ")");
         }
         
         // Pour le Step Index, nous forçons une marge de sécurité supplémentaire
         minPoints = (long)MathMax(minPoints, 10); // Au moins 10 points
      }
      else
      {
         // Valeurs par défaut si les informations du symbole ne sont pas disponibles
         minPoints = (long)MathMax(minPoints, 10);
         Print("⚠️ Step Index : utilisation de la distance minimale par défaut (", minPoints, " points)");
      }
   }
   
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minDist = minPoints * point;
   
   // Récupérer les prix de marché actuels pour validation
   double curAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double curBid = SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Prix de référence pour la validation (prix d'exécution ou prix de marché)
   double refPrice = executionPrice;
   if(refPrice <= 0.0)
   {
      // Si pas de prix d'exécution spécifié, utiliser le prix de marché
      refPrice = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT) ? curAsk : curBid;
   }
   
   // Prix de marché actuel pour validation
   double marketRefPrice = (type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT) ? curAsk : curBid;
   
   // Normaliser le prix de référence
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   refPrice = NormalizeDouble(refPrice, digits);
   marketRefPrice = NormalizeDouble(marketRefPrice, digits);
   
   bool isValid = true;
   
   // Valider et ajuster le SL
   if(sl != 0.0)
   {
      double slDistance = MathAbs(refPrice - sl);
      
      if(slDistance < minDist)
      {
         // Ajuster le SL pour respecter la distance minimale
         if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
         {
            sl = NormalizeDouble(refPrice - minDist, digits);
         }
         else // SELL ou SELL_LIMIT
         {
            sl = NormalizeDouble(refPrice + minDist, digits);
         }
         
         if(marketRefPrice > 0.0)
         {
            double slDistFromMarket = MathAbs(marketRefPrice - sl);
            if(slDistFromMarket < minDist)
            {
               if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
                  sl = NormalizeDouble(marketRefPrice - minDist, digits);
               else
                  sl = NormalizeDouble(marketRefPrice + minDist, digits);
            }
         }
      }
      
      // Vérification finale : le SL ne doit pas être au-delà du prix d'exécution pour BUY
      // ou en-deçà pour SELL
      if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
      {
         if(sl >= refPrice || sl >= marketRefPrice)
         {
            sl = NormalizeDouble(MathMin(refPrice, marketRefPrice) - minDist, digits);
         }
      }
      else
      {
         if(sl <= refPrice || sl <= marketRefPrice)
         {
            sl = NormalizeDouble(MathMax(refPrice, marketRefPrice) + minDist, digits);
         }
      }
   }
   
   // Valider et ajuster le TP
   if(tp != 0.0)
   {
      double tpDistance = MathAbs(refPrice - tp);
      
      if(tpDistance < minDist)
      {
         // Ajuster le TP pour respecter la distance minimale
         if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
         {
            tp = NormalizeDouble(refPrice + minDist, digits);
         }
         else // SELL ou SELL_LIMIT
         {
            tp = NormalizeDouble(refPrice - minDist, digits);
         }
         
         if(marketRefPrice > 0.0)
         {
            double tpDistFromMarket = MathAbs(marketRefPrice - tp);
            if(tpDistFromMarket < minDist)
            {
               if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
                  tp = NormalizeDouble(marketRefPrice + minDist, digits);
               else
                  tp = NormalizeDouble(marketRefPrice - minDist, digits);
            }
         }
      }
      
      // Vérification finale pour TP
      if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT)
      {
         if(tp <= refPrice || tp <= marketRefPrice)
         {
            tp = NormalizeDouble(MathMax(refPrice, marketRefPrice) + minDist, digits);
         }
      }
      else
      {
         if(tp >= refPrice || tp >= marketRefPrice)
         {
            tp = NormalizeDouble(MathMin(refPrice, marketRefPrice) - minDist, digits);
         }
      }
   }
   
   return isValid;
}

//+------------------------------------------------------------------+
//| Analyse et envoi du signal IA (appelé toutes les 5 minutes)     |
//+------------------------------------------------------------------+
void CheckAndSendAISignal()
{
   if(!AI_UseNotifications) return;
   
   // Récupérer les données des indicateurs
   double rsi[], atr[], emaFast[], emaSlow[], emaFastEntry[], emaSlowEntry[];
   
   if(CopyBuffer(rsiHandle, 0, 0, 2, rsi) <= 0) return;
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) return;
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFast) <= 0) return;
   if(CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlow) <= 0) return;
   if(CopyBuffer(emaFastEntryHandle, 0, 0, 1, emaFastEntry) <= 0) return;
   if(CopyBuffer(emaSlowEntryHandle, 0, 0, 1, emaSlowEntry) <= 0) return;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Analyse de tendance
   bool trendUp = emaFast[0] > emaSlow[0];
   bool trendDown = emaFast[0] < emaSlow[0];
   
   // Calcul des niveaux de stop loss et take profit
   double sl = 0, tp = 0;
   double atrValue = atr[0];

   // Déterminer le signal
   string signal = "NEUTRE";
   string timeframe = "M1";
   string comment = "";
   
   if(trendUp && rsi[0] > 50 && rsi[0] < 70)
   {
      signal = "ACHAT";
      sl = bid - (atrValue * SL_ATR_Mult);
      tp = ask + (atrValue * TP_ATR_Mult);
      comment = StringFormat("Tendance haussière, RSI: %.1f", rsi[0]);
   }
   else if(trendDown && rsi[0] < 50 && rsi[0] > 30)
   {
      signal = "VENTE";
      sl = ask + (atrValue * SL_ATR_Mult);
      tp = bid - (atrValue * TP_ATR_Mult);
      comment = StringFormat("Tendance baissière, RSI: %.1f", rsi[0]);
   }
   
   // Vérifier si on a un signal valide
   if(signal != "NEUTRE")
   {
      // Envoyer la notification
      double price = (signal == "ACHAT") ? ask : bid;
      SendTradingSignal(_Symbol, signal, timeframe, price, sl, tp, comment);
      
      // Afficher le signal sur le graphique
      string objName = "SIGNAL_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
      ObjectCreate(0, objName, OBJ_ARROW, 0, TimeCurrent(), price);
      
      // Journaliser le signal
      PrintFormat("Signal %s à %.5f - %s", signal, price, comment);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, (signal == "ACHAT") ? 233 : 234);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, signal + " " + comment);
      
      // Supprimer les anciens signaux (garder les 5 derniers)
      CleanOldSignals();
   }
}

//+------------------------------------------------------------------+
//| Nettoyage des anciens signaux graphiques                         |
//+------------------------------------------------------------------+
void CleanOldSignals()
{
   string prefix = "SIGNAL_";
   int total = ObjectsTotal(0, 0, -1);
   string names[];
   ArrayResize(names, total);
   
   // Récupérer tous les noms d'objets
   for(int i = 0; i < total; i++)
      names[i] = ObjectName(0, i);
   
   // Trier par date (du plus ancien au plus récent)
   ArraySort(names);
   
   // Supprimer les anciens signaux (en gardant les 5 plus récents)
   int count = 0;
   for(int i = 0; i < total; i++)
   {
      if(StringFind(names[i], prefix) == 0) // Si le nom commence par "SIGNAL_"
      {
         count++;
         if(count > 5) // Garder uniquement les 5 signaux les plus récents
            ObjectDelete(0, names[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| Gère la taille dynamique des positions                           |
//+------------------------------------------------------------------+
void ManageDynamicPositionSizing()
{
   if(!UseDynamicPositionSizing) return;
   
   datetime now = TimeCurrent();
   if(now - g_lastTrendCheck < AdjustmentIntervalSeconds) return;
   
   g_lastTrendCheck = now;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentProfit = PositionGetDouble(POSITION_PROFIT);
      double lotSize = PositionGetDouble(POSITION_VOLUME);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Initialiser l'état de la position si nécessaire
      if(ArraySize(g_dynamicPosStates) <= i)
      {
         ArrayResize(g_dynamicPosStates, i + 1);
         g_dynamicPosStates[i].initialLot = lotSize;
         g_dynamicPosStates[i].currentLot = lotSize;
         g_dynamicPosStates[i].highestProfit = 0;
         g_dynamicPosStates[i].trendConfirmed = false;
         g_dynamicPosStates[i].lastAdjustmentTime = 0;
         g_dynamicPosStates[i].highestPrice = (posType == POSITION_TYPE_BUY) ? currentPrice : 0;
         g_dynamicPosStates[i].lowestPrice = (posType == POSITION_TYPE_SELL) ? currentPrice : 999999;
      }
      
      // Mettre à jour les prix extrêmes
      if(posType == POSITION_TYPE_BUY)
      {
         g_dynamicPosStates[i].highestPrice = MathMax(g_dynamicPosStates[i].highestPrice, currentPrice);
         g_dynamicPosStates[i].lowestPrice = MathMin(g_dynamicPosStates[i].lowestPrice, currentPrice);
      }
      else
      {
         g_dynamicPosStates[i].lowestPrice = MathMin(g_dynamicPosStates[i].lowestPrice, currentPrice);
         g_dynamicPosStates[i].highestPrice = MathMax(g_dynamicPosStates[i].highestPrice, currentPrice);
      }
      
      // Vérifier la tendance
      bool isUptrend = (posType == POSITION_TYPE_BUY && currentPrice > openPrice) || 
                      (posType == POSITION_TYPE_SELL && currentPrice < openPrice);
      
      // Calculer le mouvement depuis l'ouverture
      double priceMove = (posType == POSITION_TYPE_BUY) ? 
                        (currentPrice - openPrice) / _Point : 
                        (openPrice - currentPrice) / _Point;
      
      // Si le profit est positif et la tendance est favorable
      if(currentProfit > g_dynamicPosStates[i].highestProfit && isUptrend)
      {
         g_dynamicPosStates[i].highestProfit = currentProfit;
         // NE PAS AUGMENTER LE LOT - Désactivé
      }
      // Si la tendance s'inverse ou que le profit commence à baisser
      else if((!isUptrend || currentProfit < g_dynamicPosStates[i].highestProfit * 0.7) && 
              g_dynamicPosStates[i].trendConfirmed)
      {
         // Revenir progressivement au lot initial
         if(lotSize > g_dynamicPosStates[i].initialLot * 1.1)
         {
            double newLot = MathMax(lotSize * 0.8, g_dynamicPosStates[i].initialLot);
            newLot = NormalizeLotSize(symbol, newLot);
            
            if(ModifyPositionSize(ticket, newLot, symbol))
            {
               g_dynamicPosStates[i].currentLot = newLot;
               g_dynamicPosStates[i].lastAdjustmentTime = now;
               Print("Position ", ticket, " réduite à ", newLot, " lots (Changement de tendance)");
               
               if(MathAbs(newLot - g_dynamicPosStates[i].initialLot) < 0.01)
               {
                  g_dynamicPosStates[i].trendConfirmed = false;
                  g_dynamicPosStates[i].highestProfit = 0;
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Modifie la taille d'une position existante                       |
//+------------------------------------------------------------------+
bool ModifyPositionSize(ulong ticket, double newLot, string symbol)
{
   if(!PositionSelectByTicket(ticket)) return false;
   
   double currentLot = PositionGetDouble(POSITION_VOLUME);
   if(MathAbs(currentLot - newLot) < 0.01) return true; // Aucun changement nécessaire
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = PositionGetDouble(POSITION_SL);
   double tp = PositionGetDouble(POSITION_TP);
   
   // Fermer la position existante en utilisant l'objet global trade
   if(!trade.PositionClose(ticket))
   {
      Print("Erreur fermeture position: ", GetLastError());
      return false;
   }
   
   // Rouvrir avec le nouveau lot
   double price = (posType == POSITION_TYPE_BUY) ? 
                 SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                 SymbolInfoDouble(symbol, SYMBOL_BID);
   
   // Récupérer le commentaire original pour le conserver
   string comment = PositionGetString(POSITION_COMMENT);
   
   // Convertir le type de position en type d'ordre
   ENUM_ORDER_TYPE orderType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   if(!trade.PositionOpen(symbol, orderType, newLot, price, sl, tp, comment))
   {
      Print("Erreur réouverture position: ", GetLastError());
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Normalise la taille du lot selon les règles du broker            |
//+------------------------------------------------------------------+
double NormalizeLotSize(string symbol, double lot)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = MathMax(minLot, MathMin(lot, maxLot));
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| CLÔTURE IMMÉDIATE DÈS QU'UN PROFIT EST DÉTECTÉ                   |
//| Ferme toute position en profit (même 0.01$) pour sécuriser gains |
//+------------------------------------------------------------------+
void ClosePositionsInProfit()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      double totalProfit = profit + swap;
      
      // Si le profit total est positif (même 0.01$), on ferme immédiatement
      if(totalProfit > 0.0)
      {
         double lot = PositionGetDouble(POSITION_VOLUME);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         Print("💰 PROFIT DÉTECTÉ: ", DoubleToString(totalProfit, 2), "$ - Fermeture immédiate!");
         
         if(posType == POSITION_TYPE_BUY)
         {
            if(trade.Sell(lot, _Symbol, 0, 0, 0, "PROFIT_SECURE"))
               Print("✅ Position BUY fermée avec profit: ", DoubleToString(totalProfit, 2), "$");
         }
         else if(posType == POSITION_TYPE_SELL)
         {
            if(trade.Buy(lot, _Symbol, 0, 0, 0, "PROFIT_SECURE"))
               Print("✅ Position SELL fermée avec profit: ", DoubleToString(totalProfit, 2), "$");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gestion des Positions (Trailing + BE)                            |
//+------------------------------------------------------------------+
void ManageTrade()
{
   // Mettre à jour les indicateurs sur le graphique
   AttachChartIndicators();
   
   // Gérer les ordres limit: exécuter le plus proche si scalping activé, garder les autres en attente
   ManagePendingOrders();
   
   // Gestion des positions ouvertes
   if(IsTradeAllowed(0, _Symbol) && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED)) {
      // Sécurisation des profits - s'applique à tous les symboles
      SecureProfits();
   }
   
   // Gestion des positions ouvertes avec SL/TP dynamiques
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      
      // Ne gérer que les positions de ce symbole et de ce magic number
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || 
         PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) 
         continue;
         
      // Récupérer les données de la position
      double atrBuffer[];
      double currentATR = 0;
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0)
         currentATR = atrBuffer[0];
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double profit = PositionGetDouble(POSITION_PROFIT);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Calculer le ratio de volatilité
      double volatilityRatio = GetVolatilityRatio(currentATR, currentPrice);
      
      // Appliquer le trailing stop si activé
      if(UseTrailing)
         ApplyTrailingStop(ticket, currentATR, volatilityRatio);
         
      // Gérer la prise de profit partielle si activée
      if(PartialClose1_Percent > 0 && profit > 0)
         ApplyPartialProfitTaking(ticket, profit);
         
      // Gestion du break-even si activé
      if(UseBreakEven && sl != 0)
      {
         // Calculer la distance actuelle en pips
         double distanceToBE = MathAbs(currentPrice - openPrice) / _Point;
         
         // Vérifier si on peut activer le break-even
         if(distanceToBE > TakeProfit1_Pips && 
            ((posType == POSITION_TYPE_BUY && sl < openPrice) || 
             (posType == POSITION_TYPE_SELL && (sl > openPrice || sl == 0))))
         {
            // Calculer le nouveau SL (niveau de break-even)
            double newSL = openPrice;
            
            // Ajustement pour le spread et les frais
            if(posType == POSITION_TYPE_SELL) 
               newSL += 10 * _Point;
                
            // Récupérer les niveaux de stop minimums du broker
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
            double freezeLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
            double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * point;
            
            // Calculer la distance minimale en tenant compte du spread et d'une marge de sécurité
            double minStopDistance = MathMax(stopLevel, freezeLevel) + (spread * 2) + (10 * point);
            
            // S'assurer que la distance minimale est d'au moins 15 points
            minStopDistance = MathMax(minStopDistance, 15 * point);
            
            // Ajuster en fonction de la volatilité du marché
            double atr[1];
            int atr_handle = iATR(_Symbol, PERIOD_CURRENT, 14);
            if(CopyBuffer(atr_handle, 0, 0, 1, atr) == 1)
            {
               // Prendre 20% de l'ATR comme distance minimale additionnelle
               double atrAdjustment = atr[0] * 0.2;
               minStopDistance = MathMax(minStopDistance, atrAdjustment);
            }
            
            // Calculer la distance minimale requise
            double minAllowedSL = 0;
            if(posType == POSITION_TYPE_BUY)
               minAllowedSL = currentPrice - minStopDistance;
            else
               minAllowedSL = currentPrice + minStopDistance;
                
            // Ajuster le SL pour respecter les règles du broker
            bool needAdjustment = (posType == POSITION_TYPE_BUY && newSL > minAllowedSL) ||
                                 (posType == POSITION_TYPE_SELL && newSL < minAllowedSL);
                                 
            if(needAdjustment)
            {
               Print("Ajustement nécessaire pour le break-even. Niveau initial: ", DoubleToString(newSL, _Digits), 
                     " Niveau minimum autorisé: ", DoubleToString(minAllowedSL, _Digits));
               
               // Ajuster le SL au niveau minimum autorisé avec une marge de sécurité
               if(posType == POSITION_TYPE_BUY)
                  newSL = minAllowedSL - 5 * point; // Marge de sécurité de 5 points
               else
                  newSL = minAllowedSL + 5 * point; // Marge de sécurité de 5 points
                    
               Print("Nouveau SL après ajustement: ", DoubleToString(newSL, _Digits));
            }
            
            // Vérifier à nouveau la validité du SL après ajustement
            bool isValidSL = true;
            if(posType == POSITION_TYPE_BUY)
               isValidSL = (newSL < currentPrice - minStopDistance);
            else
               isValidSL = (newSL > currentPrice + minStopDistance);
                
            if(!isValidSL)
            {
               Print("Erreur: Impossible de définir un SL valide pour le break-even. Distance minimale requise: ", 
                     DoubleToString(minStopDistance / point, 1), " points");
               return; // Ne pas essayer de modifier la position avec un SL invalide
            }
            
            // Essayer de modifier la position avec le nouveau SL
            if(trade.PositionModify(ticket, newSL, tp))
            {
               Print("Break-even activé pour le ticket ", ticket, " au prix ", DoubleToString(newSL, _Digits), 
                     " (Prix actuel: ", DoubleToString(currentPrice, _Digits), ")");
            }
            else
            {
               int errCode = GetLastError();
               string errDesc = "";
               switch(errCode)
               {
                  case 1: errDesc = "No error"; break;
                  case 2: errDesc = "Common error"; break;
                  case 3: errDesc = "Invalid trade parameters"; break;
                  case 4: errDesc = "Trade server is busy"; break;
                  case 5: errDesc = "Old version of the client terminal"; break;
                  case 6: errDesc = "No connection with trade server"; break;
                  case 7: errDesc = "Not enough rights"; break;
                  case 8: errDesc = "Too frequent requests"; break;
                  case 9: errDesc = "Malfunctional trade operation"; break;
                  case 64: errDesc = "Account disabled"; break;
                  case 65: errDesc = "Invalid account"; break;
                  case 128: errDesc = "Trade timeout"; break;
                  case 129: errDesc = "Invalid price"; break;
                  case 130: errDesc = "Invalid stops"; break;
                  case 131: errDesc = "Invalid trade volume"; break;
                  case 132: errDesc = "Market is closed"; break;
                  case 133: errDesc = "Trade is disabled"; break;
                  case 134: errDesc = "Not enough money"; break;
                  case 135: errDesc = "Price changed"; break;
                  case 136: errDesc = "Off quotes"; break;
                  case 137: errDesc = "Broker is busy"; break;
                  case 138: errDesc = "Requote"; break;
                  case 139: errDesc = "Order is locked"; break;
                  case 140: errDesc = "Long positions only allowed"; break;
                  case 141: errDesc = "Too many requests"; break;
                  case 145: errDesc = "Modification denied because order is too close to market"; break;
                  case 146: errDesc = "Trading context is busy"; break;
                  case 147: errDesc = "Expirations are denied by broker"; break;
                  case 148: errDesc = "Too many open and pending orders"; break;
                  case 149: errDesc = "Hedging is prohibited"; break;
                  case 150: errDesc = "Prohibited by FIFO rules"; break;
                  default:  errDesc = "Unknown error";
               }
               
               Print("Erreur break-even [", errCode, "]: ", errDesc, 
                     " - SL: ", DoubleToString(newSL, _Digits), 
                     " Prix: ", DoubleToString(currentPrice, _Digits),
                     " Distance: ", DoubleToString(MathAbs(currentPrice - newSL) / point, 1), " points");
                     
               // En cas d'échec, essayer avec un SL plus éloigné basé sur le spread et la volatilité
               double adjustmentFactor = 2.0; // Commencer avec un facteur de 2x
               
               // Augmenter le facteur si le spread est important
               if(spread > 5 * point)
                  adjustmentFactor = 3.0;
                  
               // Ajuster en fonction du type de position
               if(posType == POSITION_TYPE_BUY)
               {
                  newSL = currentPrice - (minStopDistance * adjustmentFactor);
                  // S'assurer que le SL n'est pas trop éloigné (pas plus de 2x la distance initiale)
                  if(MathAbs(newSL - openPrice) > (2 * MathAbs(currentPrice - openPrice)))
                     newSL = openPrice - (minStopDistance * 1.5);
               }
               else
               {
                  newSL = currentPrice + (minStopDistance * adjustmentFactor);
                  // S'assurer que le SL n'est pas trop éloigné (pas plus de 2x la distance initiale)
                  if(MathAbs(newSL - openPrice) > (2 * MathAbs(currentPrice - openPrice)))
                     newSL = openPrice + (minStopDistance * 1.5);
               }
               
               Print("Tentative de correction avec un SL plus éloigné: ", DoubleToString(newSL, _Digits), 
                     " (facteur d'ajustement: ", adjustmentFactor, ")");
                   
               if(trade.PositionModify(ticket, newSL, tp))
               {
                  Print("Break-even de secours activé à ", DoubleToString(newSL, _Digits));
               }
               else
               {
                  int lastErr = GetLastError();
                  string lastErrDesc = "";
                  switch(lastErr)
                  {
                     case 1: lastErrDesc = "No error"; break;
                     case 130: lastErrDesc = "Invalid stops"; break;
                     case 131: lastErrDesc = "Invalid trade volume"; break;
                     case 132: lastErrDesc = "Market is closed"; break;
                     case 4901: lastErrDesc = "Unknown symbol"; break;
                     case 4903: lastErrDesc = "Trade is not allowed"; break;
                     default:  lastErrDesc = "Error " + IntegerToString(lastErr);
                  }
                  Print("Échec critique du break-even après ajustement. Dernière erreur: ", 
                        lastErr, " - ", lastErrDesc);
               }
            }
         }
      }
   }
   
   // ========== CLÔTURE IMMÉDIATE DÈS PROFIT DÉTECTÉ (OPTIONNELLE) ==========
   // Fermer toute position en profit (même 0.01$) pour sécuriser les gains
   // Désactivé par défaut car peut entraîner de multiples ré-entrées en série
   if(false) // Désactivé - UseInstantProfitClose non défini
      ClosePositionsInProfit();
   
   // Vérifier si une position de spike doit être fermée
   // (fermeture gérée dans UpdateSpikeAlertDisplay pour éviter la sortie immédiate)
   
   double atr[];
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0) return;
   double currentATR = atr[0];

   // Distance minimale broker (stops + freeze) éventuellement surchargée
   double stopLevel, freezeLevel;
   stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   freezeLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   long minPoints   = (long)stopLevel + (long)freezeLevel + 2;
   if(MinStopPointsOverride > 0 && MinStopPointsOverride > minPoints)
      minPoints = MinStopPointsOverride;
   double minDist   = minPoints * _Point;

   // Identifier la position principale (la plus ancienne) pour appliquer la coupure monétaire
   ulong mainTicket = 0;
   datetime mainOpenTime = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      datetime ot = (datetime)PositionGetInteger(POSITION_TIME);
      if(mainTicket == 0 || ot < mainOpenTime)
      {
         mainTicket = tk;
         mainOpenTime = ot;
      }
   }

   bool closedMainForLoss = false;

   // --- GESTION PROFIT/PERTE GLOBALS (optionnel) ---
   // Calculer la somme nette (gains - pertes) de toutes les positions
   int    totalPosMagic = 0;
   double totalLossMagic  = 0.0;
   double totalProfitMagic = 0.0;
   for(int j = PositionsTotal()-1; j >= 0; j--)
   {
      ulong tk = PositionGetTicket(j);
      if(tk == 0 || !PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      totalPosMagic++;
      double p = PositionGetDouble(POSITION_PROFIT);
      if(p < 0) totalLossMagic += MathAbs(p);
      else totalProfitMagic += p;
   }
   
   double netPnL = totalProfitMagic - totalLossMagic; // Somme nette
   
   // ========== SÉCURITÉ NIVEAU 2 : Arrêt à -6$ ou +6$ ==========
   // Si perte nette dépasse 6$, fermer TOUTES les positions pour sécuriser
   if(netPnL <= -6.0)
   {
      for(int j = PositionsTotal()-1; j >= 0; j--)
      {
         ulong tk = PositionGetTicket(j);
         if(tk == 0 || !PositionSelectByTicket(tk)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         trade.PositionClose(tk);
      }
      Print("🛑 SÉCURITÉ NIVEAU 2: Perte nette de ", DoubleToString(MathAbs(netPnL), 2), "$ - Fermeture de toutes les positions");
      return;
   }
   
   // Si gain net dépasse 6$, fermer TOUTES les positions en gain pour sécuriser
   if(netPnL >= 6.0)
   {
      for(int j = PositionsTotal()-1; j >= 0; j--)
      {
         ulong tk = PositionGetTicket(j);
         if(tk == 0 || !PositionSelectByTicket(tk)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         double p = PositionGetDouble(POSITION_PROFIT);
         if(p > 0) // Fermer uniquement les positions en gain
         {
            trade.PositionClose(tk);
            Print("💰 SÉCURITÉ NIVEAU 2: Gain net de ", DoubleToString(netPnL, 2), "$ - Position ", tk, " fermée (profit: ", DoubleToString(p, 2), "$)");
         }
      }
      Print("✅ SÉCURITÉ NIVEAU 2: Gain net de ", DoubleToString(netPnL, 2), "$ - Toutes les positions en gain sécurisées");
      return;
   }
   
   // Ancienne logique (si activée)
   if(UseGlobalLossStop || GlobalProfitSecure > 0)
   {
      // Stop global si perte totale <= limite (protection critique, ferme même si récent)
      if(UseGlobalLossStop && totalLossMagic >= MathAbs(GlobalLossLimit))
      {
         for(int j = PositionsTotal()-1; j >= 0; j--)
         {
            ulong tk = PositionGetTicket(j);
            if(tk == 0 || !PositionSelectByTicket(tk)) continue;
            if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            // Protection critique : ferme même si position récente pour éviter perte majeure
            trade.PositionClose(tk);
         }
         Print("🛑 STOP GLOBAL PERTES: Fermeture de toutes les positions (perte: ", DoubleToString(totalLossMagic, 2), "$)");
         return;
      }
      
      // Sécurisation des profits par symbole
      if(GlobalProfitSecure > 0)
      {
         // Tableau pour suivre les symboles déjà traités
         string processedSymbols[];
         
         for(int j = PositionsTotal()-1; j >= 0; j--)
         {
            ulong tk = PositionGetTicket(j);
            if(tk == 0 || !PositionSelectByTicket(tk)) continue;
            if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
            
            string symbol = PositionGetString(POSITION_SYMBOL);
            
            // Vérifier si on a déjà traité ce symbole
            bool alreadyProcessed = false;
            for(int k = 0; k < ArraySize(processedSymbols); k++)
            {
               if(processedSymbols[k] == symbol)
               {
                  alreadyProcessed = true;
                  break;
               }
            }
            if(alreadyProcessed) continue;
            
            // Calculer le profit total pour ce symbole
            double symbolProfit = 0;
            for(int k = PositionsTotal()-1; k >= 0; k--)
            {
               ulong posTicket = PositionGetTicket(k);
               if(posTicket == 0 || !PositionSelectByTicket(posTicket)) continue;
               if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
               if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
               
               symbolProfit += PositionGetDouble(POSITION_PROFIT);
            }
            
            // Si le profit pour ce symbole dépasse le seuil, fermer ses positions
            if(symbolProfit >= GlobalProfitSecure)
            {
               for(int k = PositionsTotal()-1; k >= 0; k--)
               {
                  ulong posTicket = PositionGetTicket(k);
                  if(posTicket == 0 || !PositionSelectByTicket(posTicket)) continue;
                  if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
                  if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
                  
                  trade.PositionClose(posTicket);
               }
               Print("💰 PROFIT SÉCURISÉ: Fermeture des positions sur ", symbol, 
                     " (profit: ", DoubleToString(symbolProfit, 2), "$)");
            }
            
            // Marquer ce symbole comme traité
            int size = ArraySize(processedSymbols);
            ArrayResize(processedSymbols, size + 1);
            processedSymbols[size] = symbol;
         }
         return;
         return;
      }
   }
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      string psym = PositionGetString(POSITION_SYMBOL);
      if(psym != _Symbol) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curPrice  = PositionGetDouble(POSITION_PRICE_CURRENT);
      double curSL     = PositionGetDouble(POSITION_SL);
      double curTP     = PositionGetDouble(POSITION_TP);
      double profit    = PositionGetDouble(POSITION_PROFIT);
      long posType     = PositionGetInteger(POSITION_TYPE);
      bool isMainPosition = (ticket == mainTicket);
      
      // Détecter si c'est une position Boom/Crash (défini tôt pour être utilisé partout)
      bool isBoomCrashPos = (StringFind(psym, "Boom") != -1 || StringFind(psym, "Crash") != -1);
      
      double point = _Point;
      double volume = PositionGetDouble(POSITION_VOLUME);
      double tickSize = SymbolInfoDouble(psym, SYMBOL_TRADE_TICK_SIZE);
      double tickValue= SymbolInfoDouble(psym, SYMBOL_TRADE_TICK_VALUE);

      // ========== SÉCURISATION INDIVIDUELLE : Si perte > 50% du gain déjà réalisé sur ce symbole ==========
      // Vérifier si la tendance a changé (pour couper rapidement)
      bool trendChanged = false;
      double emaFast[], emaSlow[];
      if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFast) > 0 && CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlow) > 0)
      {
         bool wasUptrend = (emaFast[1] > emaSlow[1]);
         bool isUptrend = (emaFast[0] > emaSlow[0]);
         bool wasDowntrend = (emaFast[1] < emaSlow[1]);
         bool isDowntrend = (emaFast[0] < emaSlow[0]);
         
         // Détecter changement de tendance
         if((posType == POSITION_TYPE_BUY && wasUptrend && isDowntrend) ||
            (posType == POSITION_TYPE_SELL && wasDowntrend && isUptrend))
         {
            trendChanged = true;
         }
      }
      
      int symbolIdx = FindOrCreateSymbolTracker(psym);
      if(symbolIdx >= 0 && g_symbolLossTrackers[symbolIdx].totalGainRealized > 0)
      {
         double totalGainRealized = g_symbolLossTrackers[symbolIdx].totalGainRealized;
         double currentLoss = (profit < 0) ? MathAbs(profit) : 0.0;
         
         // Si la tendance change ET la perte actuelle dépasse 50% du gain total réalisé sur ce symbole, couper rapidement
         if(trendChanged && currentLoss > (totalGainRealized * 0.5))
         {
            if(trade.PositionClose(ticket))
            {
               Print("🛑 COUPE RAPIDE: Position ", ticket, " fermée - Tendance changée + Perte (", DoubleToString(currentLoss, 2), "$) > 50% du gain réalisé (", 
                     DoubleToString(totalGainRealized, 2), "$) sur ", psym);
               continue;
            }
         }
      }

      // ========== SÉCURITÉ NIVEAU 1 : Modifier SL pour sécuriser 50% du gain ==========
      // Si la position est en gain, modifier le SL pour sécuriser 50% du gain
      if(profit > 0 && curSL != 0.0)
      {
         double profitToSecure = profit * 0.5; // 50% du gain
         double newSL = 0.0;
         
         if(posType == POSITION_TYPE_BUY)
         {
            // Pour BUY: SL = prix actuel - 50% du gain
            newSL = curPrice - (profitToSecure / (tickValue * volume)) * tickSize;
            if(newSL > curSL && newSL < curPrice) // Améliorer le SL seulement
            {
               if(trade.PositionModify(ticket, newSL, curTP))
               {
                  Print("🔒 SÉCURITÉ NIVEAU 1: SL modifié pour sécuriser 50% du gain (", DoubleToString(profitToSecure, 2), "$) sur position ", ticket);
               }
            }
         }
         else // SELL
         {
            // Pour SELL: SL = prix actuel + 50% du gain
            newSL = curPrice + (profitToSecure / (tickValue * volume)) * tickSize;
            if(newSL < curSL && newSL > curPrice) // Améliorer le SL seulement
            {
               if(trade.PositionModify(ticket, newSL, curTP))
               {
                  Print("🔒 SÉCURITÉ NIVEAU 1: SL modifié pour sécuriser 50% du gain (", DoubleToString(profitToSecure, 2), "$) sur position ", ticket);
               }
            }
         }
      }

      // Sécurisation individuelle des profits (2$ par position)
      // Pour Boom/Crash: utiliser BoomCrashProfitCut (0.30$ par défaut) au lieu de ProfitSecureDollars
      double profitThreshold = ProfitSecureDollars;
      if(isBoomCrashPos && BoomCrashProfitCut > 0)
      {
         profitThreshold = BoomCrashProfitCut;
      }
      
      if(profitThreshold > 0 && profit >= profitThreshold)
      {
         if(trade.PositionClose(ticket))
         {
            Print("💵 PROFIT SÉCURISÉ: Position ", ticket, " fermée (profit: ", DoubleToString(profit, 2), "$)");
            if(isBoomCrashPos)
            {
               Print("🎯 Boom/Crash: Position fermée dès profit >= ", DoubleToString(BoomCrashProfitCut, 2), "$ pour sécuriser les gains");
            }
            continue; // Passer à la position suivante
         }
      }
      double lossPriceStep = 0.0;
      double profitPriceStep = 0.0;
      if(tickSize > 0.0 && tickValue > 0.0 && volume > 0.0)
      {
         lossPriceStep   = (LossCutDollars / (tickValue * volume)) * tickSize;
         profitPriceStep = (ProfitSecureDollars / (tickValue * volume)) * tickSize;
      }
      // Fallback ATR si conversion monétaire impossible
      if(lossPriceStep <= 0.0 && currentATR > 0.0)
         lossPriceStep = currentATR * SL_ATR_Mult;
      if(profitPriceStep <= 0.0 && currentATR > 0.0)
         profitPriceStep = currentATR * TP_ATR_Mult;

      // Pour Boom/Crash, toujours utiliser une logique ATR (les conversions $ peuvent donner des stops trop serrés)
      // Note: isBoomCrashPos est déjà défini plus haut
      if(isBoomCrashPos && currentATR > 0.0)
      {
         lossPriceStep   = currentATR * SL_ATR_Mult;
         profitPriceStep = currentATR * TP_ATR_Mult;
      }
      
      // Placer / ajuster SL/TP s'ils sont manquants pour sécuriser systématiquement la position
      if(curSL == 0.0 && lossPriceStep > 0.0)
      {
         double newSL = (posType == POSITION_TYPE_BUY) ? openPrice - lossPriceStep : openPrice + lossPriceStep;
         if(MathAbs(curPrice - newSL) < minDist)
            newSL = (posType == POSITION_TYPE_BUY) ? curPrice - minDist : curPrice + minDist;
         // Sécuriser la validité broker (StopsLevel / FreezeLevel) avant modification
         ENUM_ORDER_TYPE ordType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         double execPrice = curPrice;
         ValidateAndAdjustStops(psym, ordType, execPrice, newSL, curTP);
         if(trade.PositionModify(ticket, newSL, curTP))
            curSL = newSL;
      }

      if(curTP == 0.0 && profitPriceStep > 0.0)
      {
         double newTP = (posType == POSITION_TYPE_BUY) ? openPrice + profitPriceStep : openPrice - profitPriceStep;
         if(MathAbs(curPrice - newTP) < minDist)
            newTP = (posType == POSITION_TYPE_BUY) ? curPrice + minDist : curPrice - minDist;
         // Sécuriser la validité broker avant modification
         ENUM_ORDER_TYPE ordType2 = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         double execPrice2 = curPrice;
         ValidateAndAdjustStops(psym, ordType2, execPrice2, curSL, newTP);
         if(trade.PositionModify(ticket, curSL, newTP))
            curTP = newTP;
      }

      // Si la position principale tolère une perte supérieure au seuil, resserrer le SL
      // LIMITATION: Max 4 modifications SL pour Boom/Crash (sécurisation des gains)
      if(isMainPosition && lossPriceStep > 0.0 && curSL != 0.0)
      {
         // Vérifier le compteur de modifications SL pour Boom/Crash
         int slModifyCount = 0;
         bool isBoomCrashModify = isBoomCrashPos;
         
         if(isBoomCrashModify)
         {
            // Trouver le compteur existant pour ce ticket
            for(int t = 0; t < g_slModifyTrackerCount; t++)
            {
               if(g_slModifyTracker[t].ticket == ticket)
               {
                  slModifyCount = g_slModifyTracker[t].modifyCount;
                  break;
               }
            }
            
            // Si déjà 4 modifications, ne plus modifier le SL
            if(slModifyCount >= 4)
            {
               if(DebugBlocks)
                  Print("🛑 Position ", ticket, " (Boom/Crash): Limite de 4 modifications SL atteinte - SL laissé intact");
               continue; // Passer à la position suivante
            }
         }
         
         double distanceToSL = (posType == POSITION_TYPE_BUY) ? (openPrice - curSL) : (curSL - openPrice);
         if(distanceToSL > lossPriceStep)
         {
            double tightenSL = (posType == POSITION_TYPE_BUY) ? openPrice - lossPriceStep : openPrice + lossPriceStep;
            if(MathAbs(curPrice - tightenSL) < minDist)
               tightenSL = (posType == POSITION_TYPE_BUY) ? curPrice - minDist : curPrice + minDist;
            // Sécuriser la validité broker avant modification
            ENUM_ORDER_TYPE ordType3 = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            double execPrice3 = curPrice;
            ValidateAndAdjustStops(psym, ordType3, execPrice3, tightenSL, curTP);
            if(trade.PositionModify(ticket, tightenSL, curTP))
            {
               curSL = tightenSL;
               
               // Incrémenter le compteur pour Boom/Crash
               if(isBoomCrashModify)
               {
                  bool found = false;
                  for(int t = 0; t < g_slModifyTrackerCount; t++)
                  {
                     if(g_slModifyTracker[t].ticket == ticket)
                     {
                        g_slModifyTracker[t].modifyCount++;
                        g_slModifyTracker[t].lastModifyTime = TimeCurrent();
                        found = true;
                        if(DebugBlocks)
                           Print("📍 SL modifié #", g_slModifyTracker[t].modifyCount, "/4 pour position ", ticket, " (Boom/Crash)");
                        break;
                     }
                  }
                  if(!found && g_slModifyTrackerCount < 100)
                  {
                     g_slModifyTracker[g_slModifyTrackerCount].ticket = ticket;
                     g_slModifyTracker[g_slModifyTrackerCount].modifyCount = 1;
                     g_slModifyTracker[g_slModifyTrackerCount].lastModifyTime = TimeCurrent();
                     g_slModifyTrackerCount++;
                     if(DebugBlocks)
                        Print("📍 Première modification SL pour position ", ticket, " (Boom/Crash)");
                  }
               }
            }
         }
      }
      
      // Nettoyer les tickets qui n'existent plus (positions fermées)
      if(isBoomCrashPos)
      {
         for(int t = g_slModifyTrackerCount - 1; t >= 0; t--)
         {
            if(!PositionSelectByTicket(g_slModifyTracker[t].ticket))
            {
               // Décaler les éléments suivants
               for(int j = t; j < g_slModifyTrackerCount - 1; j++)
                  g_slModifyTracker[j] = g_slModifyTracker[j + 1];
               g_slModifyTrackerCount--;
            }
         }
      }
   }

   // Si la position principale a été fermée sur perte, promouvoir une limite en attente
   if(closedMainForLoss && CountPositionsForSymbolMagic() == 0)
      ExecuteClosestPendingOrder();

   // Si aucune position n'est ouverte, tenter d'exécuter un ordre en attente
   if(CountPositionsForSymbolMagic() == 0)
      ManagePendingOrders();
}

// Minimum de lot imposé par type d'instrument (Forex / Volatility / Boom/Crash)
double GetFloorLot(string sym)
{
   double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   
   // Utiliser le lot minimum du broker pour tous les symboles
   double floorLot = minLot;
   
   // Afficher le lot minimum pour debug
   if(DebugLotCalculation)
   {
      Print("GetFloorLot - ", sym, " : lot minimum = ", floorLot);
   }
   
   return floorLot;
}

//+------------------------------------------------------------------+
//| Calcul de Lot Intelligent (MM + Martingale)                      |
//+------------------------------------------------------------------+
double CalculateLot(double atr)
{
   double lot = FixedLotSize;
   bool isForex = (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_CALC_MODE) == SYMBOL_CALC_MODE_FOREX);
   bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);

   // 1. Calcul basé sur le risque % si activé (pour tous sauf Boom/Crash)
   if(RiskPercent > 0 && atr > 0 && !isBoomCrash)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * RiskPercent / 100.0;
      double slPoints = (atr * SL_ATR_Mult) / _Point;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      // Ajustement spécifique pour le Forex
      if(isForex)
      {
         // Récupérer le lot minimum autorisé par le broker pour ce symbole
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         // Valeur par défaut sécurisée pour le Forex : utiliser minimum broker
         lot = minLot;
         
         if(slPoints > 0 && tickValue > 0 && tickSize > 0 && point > 0)
         {
            // Calcul plus précis pour le Forex
            double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
            double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            if(contractSize > 0 && price > 0)
            {
               double riskPerLot = slPoints * tickValue * point / tickSize;
               if(riskPerLot > 0)
                  lot = riskMoney / riskPerLot;
            }
         }
      }
      else if(slPoints > 0 && tickValue > 0)
      {
         // Calcul normal pour Step Index et autres symboles (hors Forex et Boom/Crash)
         lot = riskMoney / (slPoints * tickValue);
      }
   }

   // 2. Martingale (Vérifier le dernier trade clos) - désactivé pour Boom/Crash (lots fixes)
   if(UseMartingale && !isBoomCrash)
   {
      double lastLot;
      double lastProfit;
      if(GetLastHistoryTrade(lastLot, lastProfit))
      {
         if(lastProfit < 0) // Si perte
         {
            lot = lastLot * MartingaleMult;
            // Limite martingale steps
            if(MartingaleSteps > 0)
            {
               int lossStreak = GetConsecutiveLosses();
               if(lossStreak >= MartingaleSteps)
                  lot = lastLot; // Ne pas augmenter plus après le nombre max d'étapes
            }
         }
      }
   }

   // 3. Vérification des limites du broker
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Arrondir au step le plus proche
   if(lotStep > 0)
   {
      // Pour le Step Index, forcer un arrondi plus strict
      if(isStepIndex)
      {
         lot = NormalizeDouble(MathFloor(lot / lotStep) * lotStep, 2);
         // S'assurer que le lot ne soit pas inférieur au minimum
         if(lot < minLot) lot = minLot;
      }
      else
      {
         lot = MathFloor(lot / lotStep) * lotStep;
      }
   }
   
   // Appliquer les limites
   lot = MathMax(lot, minLot);
   lot = MathMin(lot, maxLot);
   
   // Log détaillé pour le Step Index
   if(isStepIndex && DebugLotCalculation)
   {
      Print("Step Index - Calcul du lot:",
            "\n  - Lot calculé: ", lot,
            "\n  - Min lot: ", minLot,
            "\n  - Max lot: ", maxLot,
            "\n  - Lot step: ", lotStep);
   }
   
   // Limite spécifique selon le type d'instrument
   bool isVol = (!isForex &&
                 (StringFind(_Symbol, "Volatility") != -1 ||
                  StringFind(_Symbol, "VOLATILITY") != -1 ||
                  StringFind(_Symbol, "volatility") != -1));
   bool isIndex = (isVol || isBoomCrash);

   // --- Règle spécifique Step Index : calcul basé sur le risque avec limites ---
   if(isStepIndex)
   {
      // S'assurer que le lot calculé respecte les limites min/max
      lot = MathMax(lot, minLot);
      // Limite maximum pour Step Index : 0.5 lot (ajustable si nécessaire)
      double maxStepIndexLot = 0.5;
      lot = MathMin(lot, maxStepIndexLot);
      
      if(DebugLotCalculation)
         Print("CalculateLot - Step Index lot final: ", lot, " (min: ", minLot, ", max: ", maxStepIndexLot, ")");
   }

   // --- Lots pour Boom/Crash : utiliser le lot minimum du broker ---
   if(isBoomCrash)
   {
      // Appliquer les limites broker d'abord
      lot = MathMax(lot, minLot);
      lot = MathMin(lot, maxLot);
      
      // Lots spécifiques selon le type de Boom
      if(StringFind(_Symbol, "Boom 1000") != -1)
      {
         lot = 0.2; // Lot fixe pour Boom 1000
      }
      else if(StringFind(_Symbol, "Boom 300") != -1)
      {
         lot = 0.5; // Lot fixe pour Boom 300
      }
      else
      {
         lot = MathMin(lot, 0.5); // Limite générale pour autres Boom/Crash
      }
      
      if(DebugLotCalculation)
         Print("CalculateLot - Boom/Crash lot final: ", lot, " (min broker: ", minLot, ")");
   }
   else if(isForex)
   {
      // Forex : utiliser le minimum du broker (généralement 0.01)
      lot = MathMax(lot, minLot);
      // Maximum 0.01 lot pour le Forex
      double maxForexLot = 0.01;
      lot = MathMin(lot, maxForexLot);
   }
   else if(isIndex)
   {
      // Indices de volatilité : utiliser le minimum du broker, max 0.2
      lot = MathMax(lot, minLot);
      double maxIndexLot = 0.2;
      lot = MathMin(lot, maxIndexLot);
   }
   
   // Cap utilisateur global - RÉDUIT DE 5.0 À 1.0
   lot = MathMin(lot, 1.0);
   
   // Dernier arrondi et vérification
   if(lot > 0.0)
   {
      // S'assurer que le lot est un multiple du pas minimum
      if(lotStep > 0)
      {
         if(isStepIndex)
         {
            // Pour le Step Index, utiliser NormalizeDouble pour plus de précision
            lot = NormalizeDouble(MathFloor(lot / lotStep) * lotStep, 2);
         }
         else
         {
            lot = MathFloor(lot / lotStep) * lotStep;
         }
      }
         
      // Vérifier que le lot n'est pas en dessous du minimum
      if(lot < minLot)
         lot = minLot;
         
      // Vérifier que le lot ne dépasse pas le maximum
      lot = MathMin(lot, maxLot);
      
      // Log final pour le Step Index
      if(isStepIndex && DebugLotCalculation)
      {
         Print("Step Index - Lot final: ", lot, 
               " (min: ", minLot, 
               ", max: ", maxLot, 
               ", step: ", lotStep, ")");
      }
   }
   
   return (lot > 0.0) ? NormalizeDouble(lot, 2) : 0.0;
}

//+------------------------------------------------------------------+
//| Récupère info dernier trade fermé (Pour Martingale)              |
//+------------------------------------------------------------------+
bool GetLastHistoryTrade(double &lastLot, double &lastProfit)
{
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   
   for(int i = total-1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      // Vérifier si c'est un trade de clôture
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) 
         continue;
         
      // Vérifier si c'est notre EA
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) 
         continue;
         
      // Vérifier que c'est bien le même symbole
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) 
         continue;
         
      // Récupérer le volume et le profit
      lastLot = HistoryDealGetDouble(ticket, DEAL_VOLUME);
      lastProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie les trades bypass cooldown fermés et durcit le cooldown si perte |
//+------------------------------------------------------------------+
void CheckBypassCooldownTrades()
{
   static datetime lastCheck = 0;
   datetime now = TimeCurrent();
   
   // Vérifier toutes les 10 secondes pour éviter trop de calculs
   if(now - lastCheck < 10)
      return;
   lastCheck = now;
   
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   
   // Parcourir les deals récents (derniers 50)
   for(int i = total - 1; i >= 0 && i >= total - 50; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      // Vérifier si c'est un trade de clôture
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;
      
      // Vérifier si c'est notre EA
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber)
         continue;
      
      string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      ulong positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      
      // Chercher dans la liste des trades bypass (par position ID ou symbole + temps)
      for(int j = g_tradesBypassCooldownCount - 1; j >= 0; j--)
      {
         if(g_tradesBypassCooldown[j].symbol == dealSymbol)
         {
            // Vérifier si c'est une perte
            if(dealProfit < 0)
            {
               // Durcir le cooldown de 10 minutes supplémentaires
               ExtendSymbolLossCooldownForSymbol(dealSymbol, 10);
               
               Print("⏰ Trade bypass cooldown échoué - Cooldown durci de +10 min sur ", dealSymbol, " (profit: ", dealProfit, ")");
               
               // Retirer de la liste (pour éviter de le traiter plusieurs fois)
               for(int k = j; k < g_tradesBypassCooldownCount - 1; k++)
               {
                  g_tradesBypassCooldown[k] = g_tradesBypassCooldown[k + 1];
               }
               g_tradesBypassCooldownCount--;
               break;
            }
            else if(dealProfit > 0)
            {
               // Trade gagnant, retirer de la liste sans durcir
               for(int k = j; k < g_tradesBypassCooldownCount - 1; k++)
               {
                  g_tradesBypassCooldown[k] = g_tradesBypassCooldown[k + 1];
               }
               g_tradesBypassCooldownCount--;
               break;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Compte le nombre de pertes consécutives sur CE symbole          |
//| (du plus récent vers l'ancien)                                  |
//+------------------------------------------------------------------+
int GetConsecutiveLosses()
{
   int consecutiveLosses = 0;
   static int boom300RecentLosses = 0;
   HistorySelect(0, TimeCurrent());
   
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      // Vérifier si c'est un trade de clôture
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      
      // Vérifier si c'est notre EA
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;

      // Vérifier que c'est bien le même symbole (ce "marché")
      string sym = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(sym != _Symbol) continue;
      
      // Vérifier le profit
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      
      if(profit < 0.0)
         consecutiveLosses++;
      else
         break; // On s'arrête au premier trade gagnant
   }
   // Mettre à jour le compteur spécifique Boom 300 (nombre de pertes consécutives)
   if(StringFind(_Symbol, "Boom 300") != -1)
   {
      boom300RecentLosses = consecutiveLosses;
      if(boom300RecentLosses >= 2)
      {
         // Démarre un cooldown minimum de 10 minutes sur Boom 300
         if(g_boom300CooldownUntil < TimeCurrent())
         {
            g_boom300CooldownUntil = TimeCurrent() + 10 * 60;
            Print(" Cooldown Boom 300: pause 10 minutes après ", boom300RecentLosses, " pertes consécutives.");
         }
      }
   }
   
   return consecutiveLosses;
}

//+------------------------------------------------------------------+
//| GetSupertrendDir() - Get current Supertrend direction (1=bullish, -1=bearish, 0=neutral/not used) |
//+------------------------------------------------------------------+
int GetSupertrendDir()
{
   if(!UseSupertrendFilter || stHandle == INVALID_HANDLE) 
      return 0;
      
   double up[1], dn[1];
   
   // Get the latest Supertrend values
   if(CopyBuffer(stHandle, 0, 0, 1, up) <= 0) return 0; // Up buffer
   if(CopyBuffer(stHandle, 1, 0, 1, dn) <= 0) return 0; // Down buffer
   
   // Determine trend direction based on buffer values
   if(up[0] != 0.0 && dn[0] == 0.0) return 1;   // Bullish trend
   if(dn[0] != 0.0 && up[0] == 0.0) return -1;  // Bearish trend
   
   return 0;  // No clear trend or error
}

//+------------------------------------------------------------------+
//| GetTodayProfitUSD() - Calculate today's profit in USD            |
//+------------------------------------------------------------------+
double GetTodayProfitUSD()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   datetime dayStart = StructToTime(dt);
   
   double profit = 0.0;
   
   // Get total number of deals in history
   int deals = HistoryDealsTotal();
   
   // Loop through deals from newest to oldest
   for(int i = deals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      // Check if deal is from today
      datetime dealTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(dealTime < dayStart) 
         break;  // No need to check older deals
         
      // Only consider BUY and SELL deals (not deposits/withdrawals)
      ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
      {
         profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
      }
   }
   
   return profit;
}

// Dernière perte (pour cooldown après SL)
bool GetLastLoss(datetime &lossTime, double &lossProfit)
{
   HistorySelect(0, TimeCurrent());
   int total = HistoryDealsTotal();
   
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue; // On veut la sortie

      lossProfit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
      lossTime   = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      return (lossProfit < 0);
   }
   return false;
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
void CleanPendingOrders()
{
   bool hasPosition = (CountPositionsForSymbolMagic() > 0);
   
   // Si on a une position ouverte, ne pas toucher aux ordres limit (laisser finir)
   if(hasPosition)
   {
      // Gérer les ordres limit: s'assurer qu'on ne dépasse pas le maximum
      ManagePendingOrders();
      return;
   }
   
   // Gérer les ordres limit: exécuter le plus proche si scalping activé
   ManagePendingOrders();
   
   // Supprimer les ordres trop vieux (> 30 min)
   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT)
         continue;
      
      // Supprimer si trop vieux (> 30 min)
      long setupTime = OrderGetInteger(ORDER_TIME_SETUP);
      if(TimeCurrent() - setupTime > 1800) // 30 minutes
         trade.OrderDelete(ticket);
   }
}

//+------------------------------------------------------------------+
//| Affiche les supports et résistances sur M5 et H1                 |
//+------------------------------------------------------------------+
void DrawSupportResistance()
{
   // Supprimer les anciens objets
   string prefix = "SR_";
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
   
   // Définir les timeframes à analyser
   ENUM_TIMEFRAMES timeframes[2] = {PERIOD_M5, PERIOD_H1};
   color colors[2] = {clrDodgerBlue, clrOrange};
   
   for(int t = 0; t < 2; t++)
   {
      ENUM_TIMEFRAMES tf = timeframes[t];
      color tfColor = colors[t];
      
      // Récupérer les données de prix
      double high[], low[];
      ArraySetAsSeries(high, true);
      ArraySetAsSeries(low, true);
      
      int copied = CopyHigh(_Symbol, tf, 0, 100, high);
      if(copied <= 0) continue;
      
      copied = CopyLow(_Symbol, tf, 0, 100, low);
      if(copied <= 0) continue;
      
      // Trouver les points hauts et bas significatifs
      double resistance1 = high[ArrayMaximum(high, 10, 0)];
      double support1 = low[ArrayMinimum(low, 10, 0)];
      
      // Afficher les lignes de support/résistance
      string resName = StringFormat("%sRES_%d_%d", prefix, tf, 1);
      string supName = StringFormat("%sSUP_%d_%d", prefix, tf, 1);
      
      // Ligne de résistance
      ObjectCreate(0, resName, OBJ_HLINE, 0, 0, resistance1);
      ObjectSetInteger(0, resName, OBJPROP_COLOR, tfColor);
      ObjectSetInteger(0, resName, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, resName, OBJPROP_WIDTH, 2);
      ObjectSetString(0, resName, OBJPROP_TEXT, StringFormat("Résistance %s", EnumToString(tf)));
      
      // Ligne de support
      ObjectCreate(0, supName, OBJ_HLINE, 0, 0, support1);
      ObjectSetInteger(0, supName, OBJPROP_COLOR, tfColor);
      ObjectSetInteger(0, supName, OBJPROP_STYLE, STYLE_DASHDOT);
      ObjectSetInteger(0, supName, OBJPROP_WIDTH, 2);
      ObjectSetString(0, supName, OBJPROP_TEXT, StringFormat("Support %s", EnumToString(tf)));
      
      // Ajouter des étiquettes
      string labelName = StringFormat("%sLABEL_%d", prefix, t);
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 20 + t * 20);
      ObjectSetString(0, labelName, OBJPROP_TEXT, StringFormat("%s: S=%.5f  R=%.5f", 
                     EnumToString(tf), support1, resistance1));
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, tfColor);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Vérifie la tendance sur le timeframe M5 (retourne 1 haussier, -1 baissier, 0 neutre) |
//+------------------------------------------------------------------+
int CheckM5Trend(string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   
   int emaFast = iMA(symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   int emaSlow = iMA(symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   double emaFast0 = iMA(symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   double emaFast1 = iMA(symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   double emaSlow0 = iMA(symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   double emaFast0Val[1], emaFast1Val[1], emaSlow0Val[1];
   
   // Copier les valeurs des indicateurs
   if(CopyBuffer(emaFast, 0, 0, 1, emaFast0Val) <= 0) return 0;
   if(CopyBuffer(emaFast, 0, 1, 1, emaFast1Val) <= 0) return 0;
   if(CopyBuffer(emaSlow, 0, 0, 1, emaSlow0Val) <= 0) return 0;
   
   // Libérer les handles des indicateurs
   IndicatorRelease(emaFast);
   IndicatorRelease(emaSlow);
   
   if(emaFast0 > emaSlow0 && emaFast1 > emaSlow0) // Tendance haussière
      return 1;
   else if(emaFast0 < emaSlow0 && emaFast1 < emaSlow0) // Tendance baissière
      return -1;
   
   return 0; // Tendance neutre
}

//+------------------------------------------------------------------+
//| Vérifie si un rebond est confirmé sur M5                         |
//+------------------------------------------------------------------+
bool IsBounceConfirmed(string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   
   // Vérifier si la bougie actuelle est haussière après une bougie baissière
   double open1 = iOpen(symbol, PERIOD_M5, 1);
   double close1 = iClose(symbol, PERIOD_M5, 1);
   double open0 = iOpen(symbol, PERIOD_M5, 0);
   double close0 = iClose(symbol, PERIOD_M5, 0);
   
   // La bougie précédente était baissière et la courante est haussière
   if(close1 < open1 && close0 > open0 && close0 > open1)
   {
      // Vérifier que le volume est supérieur à la moyenne
      double vol0 = (double)iVolume(symbol, PERIOD_M5, 0);
      
      // Créer un handle pour la moyenne mobile du volume
      int volMaHandle = iMA(symbol, PERIOD_M5, 20, 0, MODE_SMA, VOLUME_TICK);
      double volAvgVal[1];
      
      // Copier la valeur de la moyenne mobile du volume
      if(CopyBuffer(volMaHandle, 0, 0, 1, volAvgVal) <= 0) 
      {
         IndicatorRelease(volMaHandle);
         return false;
      }
      
      double volAvg = volAvgVal[0];
      IndicatorRelease(volMaHandle);
      
      if(vol0 > volAvg * 0.8) // Volume supérieur à 80% de la moyenne
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si on peut acheter en fonction de la tendance M5         |
//+------------------------------------------------------------------+
bool CanBuyWithM5Confirmation(string symbol = NULL)
{
   if(symbol == NULL) symbol = _Symbol;
   
   // Vérifier si c'est un symbole Boom
   bool isBoom = (StringFind(symbol, "Boom") != -1);
   
   // Pour les symboles Boom, vérifier la tendance M5 et le rebond
   if(isBoom)
   {
      int m5Trend = CheckM5Trend(symbol);
      
      // Si tendance baissière, vérifier le rebond
      if(m5Trend < 0)
      {
         if(!IsBounceConfirmed(symbol))
         {
            Print("Achat sur Boom refusé : attente d'un rebond confirmé sur M5");
            return false;
         }
         Print("Achat sur Boom autorisé : rebond confirmé sur M5 malgré tendance baissière");
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Compte le nombre de positions ouvertes pour le symbole et magic  |
//+------------------------------------------------------------------+
int CountPositionsForSymbolMagic()
{
   int cnt = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(PositionGetTicket(i) > 0 && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && 
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         cnt++;
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Vérifie si le cooldown est actif pour Boom 1000                 |
//+------------------------------------------------------------------+
bool IsBoom1000InCooldown()
{
   if(StringFind(_Symbol, "Boom 1000") == -1)
      return false;  // Pas un Boom 1000, pas de cooldown
      
   if(g_boom1000LossStreak < 3)
      return false;  // Moins de 3 pertes consécutives
      
   if(TimeCurrent() >= g_boom1000CooldownUntil)
   {
      // Fin du cooldown
      if(g_boom1000CooldownUntil > 0)
         Print("✅ Fin du cooldown Boom 1000 après 3 pertes consécutives");
      g_boom1000CooldownUntil = 0;
      return false;
   }
   
   // Afficher un message toutes les minutes pendant le cooldown
   static datetime lastMessage = 0;
   if(TimeCurrent() - lastMessage >= 60)
   {
      int remaining = (int)((g_boom1000CooldownUntil - TimeCurrent()) / 60) + 1;
      Print("⏳ Cooldown Boom 1000 actif - ", remaining, " minute(s) restante(s)");
      lastMessage = TimeCurrent();
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Met à jour le compteur de pertes pour Boom 1000                 |
//+------------------------------------------------------------------+
void UpdateBoom1000LossStreak(double profit)
{
   if(StringFind(_Symbol, "Boom 1000") == -1)
      return;  // Pas un Boom 1000
      
   if(profit < 0)
   {
      g_boom1000LossStreak++;
      Print("📉 Perte sur Boom 1000 - Série de pertes: ", g_boom1000LossStreak, "/3");
      
      if(g_boom1000LossStreak >= 3)
      {
         g_boom1000CooldownUntil = TimeCurrent() + (BOOM1000_COOLDOWN_MINUTES * 60);
         Print("⚠️ Cooldown de ", BOOM1000_COOLDOWN_MINUTES, 
               " minutes activé pour Boom 1000 après 3 pertes consécutives");
      }
   }
   else if(profit > 0)
   {
      // Réinitialiser le compteur si un trade est gagnant
      if(g_boom1000LossStreak > 0)
      {
         Print("✅ Trade gagnant sur Boom 1000 - Réinitialisation du compteur de pertes");
         g_boom1000LossStreak = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifie si une nouvelle position peut être ouverte               |
//| bypassCooldown: true pour contourner le cooldown (touches de niveaux importants) |
//| confidence: niveau de confiance du signal (0.0 à 1.0)            |
//+------------------------------------------------------------------+
bool CanOpenNewPosition(ENUM_ORDER_TYPE orderType, double price, bool bypassCooldown = false, double confidence = 0.0)
{
   // Vérifier le nombre maximum de positions (3 max)
   if(CountPositionsForSymbolMagic() >= 3) {
      Print("⚠️ Nombre maximum de positions atteint (3)");
      return false;
   }
   
   // Si la confiance est très élevée (>80%), on passe outre certaines restrictions
   bool highConfidenceSignal = (confidence >= 0.8);
   
   // Vérifier les autres conditions (trading autorisé, pas de drawdown, etc.)
   // Utilisation de 0 comme direction neutre car cette vérification est générique
   if((!IsTradeAllowed(0) || IsStopped()) && !highConfidenceSignal) {
      // Log seulement une fois par minute pour éviter le spam
      static datetime lastTradeBlockedLog = 0;
      static string lastTradeBlockedSymbol = "";
      datetime now = TimeCurrent();
      if(now - lastTradeBlockedLog >= 60 || lastTradeBlockedSymbol != _Symbol)
      {
         Print("⚠️ Trading non autorisé ou contexte occupé");
         lastTradeBlockedLog = now;
         lastTradeBlockedSymbol = _Symbol;
      }
      return false;
   }
   
   // Vérifier si le contexte de trading est occupé
   if((!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED)) && !highConfidenceSignal) {
      // Log seulement une fois par minute
      static datetime lastTerminalBlockedLog = 0;
      if(TimeCurrent() - lastTerminalBlockedLog >= 60)
      {
         Print("⚠️ Trading non autorisé par le terminal");
         lastTerminalBlockedLog = TimeCurrent();
      }
      return false;
   }
   
   // Ne pas vérifier le drawdown pour les signaux de haute confiance
   if(IsDrawdownExceeded() && !highConfidenceSignal) {
      Print("⚠️ Drawdown maximum atteint");
      return false;
   }
   
   // Vérifier les heures de trading (sauf pour les signaux de haute confiance)
   if(!IsTradingTimeAllowed() && !highConfidenceSignal) {
      Print("⚠️ Hors des heures de trading autorisées");
      return false;
   }
   
   // Si on arrive ici, le trade est autorisé
   if(highConfidenceSignal) {
      Print("✅ Trade haute confiance autorisé (confiance: ", DoubleToString(confidence*100,1), "%)");
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Nettoyage des positions suivies qui n'existent plus              |
//+------------------------------------------------------------------+
void CleanupProfitTracking()
{
   for(int i = g_trackedCount - 1; i >= 0; i--)
   {
      bool positionExists = false;
      for(int j = 0; j < PositionsTotal(); j++)
      {
         ulong ticket = PositionGetTicket(j);
         if(ticket == g_trackedTickets[i])
         {
            positionExists = true;
            break;
         }
      }
      
      if(!positionExists)
      {
         // Déplacer tous les éléments suivants d'une case vers la gauche
         for(int j = i; j < g_trackedCount - 1; j++)
         {
            g_trackedTickets[j] = g_trackedTickets[j + 1];
            g_maxProfit[j] = g_maxProfit[j + 1];
         }
         g_trackedCount--;
      }
   }
   
   // Redimensionner les tableaux si nécessaire
   if(g_trackedCount < ArraySize(g_trackedTickets) / 2 && g_trackedCount > 10)
   {
      ArrayResize(g_trackedTickets, g_trackedCount + 10);
      ArrayResize(g_maxProfit, g_trackedCount + 10);
   }
}

//+------------------------------------------------------------------+
//| Sécurisation des profits - Suit le profit max et ferme à -50%    |
//+------------------------------------------------------------------+
void SecureProfits()
{
   // Nettoyer périodiquement les positions suivies qui n'existent plus
   static datetime lastCleanup = 0;
   if(TimeCurrent() - lastCleanup > 300) // Toutes les 5 minutes
   {
      CleanupProfitTracking();
      lastCleanup = TimeCurrent();
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) 
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionSelectByTicket(ticket) && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber) 
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         double currentProfit = PositionGetDouble(POSITION_PROFIT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double currentSL = PositionGetDouble(POSITION_SL);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         
         // Rechercher ou initialiser le profit max pour ce ticket
         int idx = -1;
         for(int j = 0; j < g_trackedCount; j++)
         {
            if(g_trackedTickets[j] == ticket)
            {
               idx = j;
               break;
            }
         }
         
         // Si nouvelle position, l'ajouter au suivi
         if(idx == -1)
         {
            // Vérifier si on a de la place dans le tableau
            if(g_trackedCount >= ArraySize(g_trackedTickets))
            {
               int newSize = g_trackedCount + 10;
               ArrayResize(g_trackedTickets, newSize);
               ArrayResize(g_maxProfit, newSize);
            }
            
            idx = g_trackedCount;
            g_trackedTickets[idx] = ticket;
            g_maxProfit[idx] = currentProfit;
            g_trackedCount++;
            
            Print("📊 Nouvelle position suivie: ", symbol, 
                  " (Ticket: ", ticket, 
                  ", Profit initial: ", DoubleToString(currentProfit, 2), ")");
         }
         
         // Mettre à jour le profit maximum atteint
         if(currentProfit > g_maxProfit[idx])
         {
            g_maxProfit[idx] = currentProfit;
            Print("📈 Mise à jour profit max pour ", symbol, 
                  " (Ticket: ", ticket, 
                  ", Nouveau max: ", DoubleToString(g_maxProfit[idx], 2), ")");
         }
         
         // Vérifier si on doit fermer la position (50% de drawdown)
         if(g_maxProfit[idx] > 0 && currentProfit < g_maxProfit[idx] * 0.5)
         {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = symbol;
            request.volume = PositionGetDouble(POSITION_VOLUME);
            request.deviation = 5;
            
            if(posType == POSITION_TYPE_BUY)
            {
               request.price = bid;
               request.type = ORDER_TYPE_SELL;
            }
            else
            {
               request.price = ask;
               request.type = ORDER_TYPE_BUY;
            }
            
            if(OrderSend(request, result))
            {
               Print("✅ Sécurisation des profits - Fermeture position: ", symbol, 
                     " | Ticket: ", ticket, 
                     " | Profit max: ", DoubleToString(g_maxProfit[idx], 2), 
                     " | Profit actuel: ", DoubleToString(currentProfit, 2));
               
               // Supprimer ce ticket du suivi
               for(int j = idx; j < g_trackedCount-1; j++)
               {
                  g_trackedTickets[j] = g_trackedTickets[j+1];
                  g_maxProfit[j] = g_maxProfit[j+1];
               }
               g_trackedCount--;
            }
            continue;
         }
         
         // Sécurisation classique - déplacer le SL à 50% du profit
         if(currentProfit >= 1.0) 
         {
            double profitToSecure = currentProfit * 0.5; // 50% du profit
            double pointValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
            double pointSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
            
            if(pointValue > 0 && pointSize > 0) 
            {
               double profitInPoints = profitToSecure / (PositionGetDouble(POSITION_VOLUME) * pointValue);
               double newSL = 0.0;
               
               if(posType == POSITION_TYPE_BUY) 
               {
                  newSL = currentPrice - profitInPoints * pointSize;
                  // Ne déplacer le SL que s'il est plus élevé que le SL actuel
                  if((currentSL == 0 || newSL > currentSL) && newSL < currentPrice)
                  {
                     MqlTradeRequest request = {};
                     MqlTradeResult result = {};
                     
                     request.action = TRADE_ACTION_SLTP;
                     request.position = ticket;
                     request.symbol = symbol;
                     request.sl = newSL;
                     request.tp = PositionGetDouble(POSITION_TP);
                     
                     if(OrderSend(request, result))
                     {
                        Print("🔒 Sécurisation des profits - Ticket: ", ticket, 
                              " | Symbole: ", symbol,
                              " | Ancien SL: ", currentSL, 
                              " | Nouveau SL: ", newSL,
                              " | Profit sécurisé: $", DoubleToString(profitToSecure, 2));
                     }
                  }
               } 
               else // POSITION_TYPE_SELL
               {
                  newSL = currentPrice + profitInPoints * pointSize;
                  // Ne déplacer le SL que s'il est plus bas que le SL actuel
                  if((currentSL == 0 || newSL < currentSL) && newSL > currentPrice)
                  {
                     MqlTradeRequest request = {};
                     MqlTradeResult result = {};
                     
                     request.action = TRADE_ACTION_SLTP;
                     request.position = ticket;
                     request.symbol = symbol;
                     request.sl = newSL;
                     request.tp = PositionGetDouble(POSITION_TP);
                     
                     if(OrderSend(request, result))
                     {
                        Print("🔒 Sécurisation des profits - Ticket: ", ticket, 
                              " | Symbole: ", symbol,
                              " | Ancien SL: ", currentSL, 
                              " | Nouveau SL: ", newSL,
                              " | Profit sécurisé: $", DoubleToString(profitToSecure, 2));
                     }
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gestion du trailing stop pour sécuriser les gains                |
//+------------------------------------------------------------------+
void ManageTrailingStops()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      
      if(PositionSelectByTicket(ticket) && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol) {
         
         double currentProfit = PositionGetDouble(POSITION_PROFIT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double currentSL = PositionGetDouble(POSITION_SL);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
         
         // Calculer le nouveau stop loss en fonction du type de position
         double newSL = currentSL;
         int localAtrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
         double atr[];
         double atrValue = 0;
         if(localAtrHandle != INVALID_HANDLE && CopyBuffer(localAtrHandle, 0, 0, 1, atr) > 0) {
            atrValue = atr[0];
         }
         if(localAtrHandle != INVALID_HANDLE) IndicatorRelease(localAtrHandle);
         
         if(atrValue > 0) {
            if(posType == POSITION_TYPE_BUY) {
               // Pour les positions d'achat, le SL est en dessous du prix
               double trailLevel = currentPrice - (atrValue * (isBoomCrash ? 2.0 : 1.5));
               if(trailLevel > currentSL && trailLevel < currentPrice) {
                  newSL = trailLevel;
               }
            } else if(posType == POSITION_TYPE_SELL) {
               // Pour les positions de vente, le SL est au-dessus du prix
               double trailLevel = currentPrice + (atrValue * (isBoomCrash ? 2.0 : 1.5));
               if((currentSL == 0 || trailLevel < currentSL) && trailLevel > currentPrice) {
                  newSL = trailLevel;
               }
            }
         }
         
         // Mettre à jour le stop loss si nécessaire
         if(newSL != currentSL) {
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_SLTP;
            request.position = ticket;
            request.symbol = _Symbol;
            request.sl = newSL;
            request.tp = PositionGetDouble(POSITION_TP); // Garder le même TP
            
            if(!OrderSend(request, result)) {
               Print("Erreur de mise à jour du SL: ", GetLastError());
            } else {
               Print("SL mis à jour pour le ticket ", ticket, " à ", newSL);
            }
         }
         
         // Prendre des bénéfices partiels
         if(currentProfit > 0 && atrValue > 0) {
            double takeProfit1 = openPrice + (posType == POSITION_TYPE_BUY ? atrValue * 1.0 : -atrValue * 1.0);
            double takeProfit2 = openPrice + (posType == POSITION_TYPE_BUY ? atrValue * 2.0 : -atrValue * 2.0);
            
            // Vérifier si on doit prendre des bénéfices partiels
            if((posType == POSITION_TYPE_BUY && currentPrice >= takeProfit1 && currentSL < openPrice) ||
               (posType == POSITION_TYPE_SELL && currentPrice <= takeProfit1 && (currentSL > openPrice || currentSL == 0))) {
               
               // Fermer la moitié de la position
               double volume = PositionGetDouble(POSITION_VOLUME) / 2.0;
               
               MqlTradeRequest closeRequest = {};
               MqlTradeResult closeResult = {};
               
               closeRequest.action = TRADE_ACTION_DEAL;
               closeRequest.position = ticket;
               closeRequest.symbol = _Symbol;
               closeRequest.volume = volume;
               closeRequest.price = currentPrice;
               closeRequest.deviation = 10;
               closeRequest.magic = InpMagicNumber;
               closeRequest.comment = "Prise de bénéfices partiels";
               closeRequest.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
               // Le type de filling est géré automatiquement par trade.SetTypeFillingBySymbol() dans OnInit()
               
               if(OrderSend(closeRequest, closeResult)) {
                  Print("Prise de bénéfices partiels réussie pour le ticket ", ticket);
               } else {
                  Print("Erreur lors de la prise de bénéfices partiels: ", GetLastError());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| LIMITE: MAXIMUM 2 POSITIONS OUVERTES TOUS SYMBOLES CONFONDUS     |
//| NOTE: cette limite est GLOBALE, elle compte toutes les positions |
//|      du compte, quel que soit le symbole ou le magic number.     |
//| bypassCooldown: true pour contourner le cooldown (touches de niveaux importants) |
//+------------------------------------------------------------------+
bool CanOpenNewPosition(bool bypassCooldown = false)
{
   // Utiliser le compteur global pour toutes les positions ouvertes
   int count = CountAllPositionsForMagic();
   
   // Limite GLOBALE: maximum 3 positions ouvertes en même temps (tous symboles confondus)
   int maxGlobal = 3;

   // Vérifier les pertes consécutives sur ce symbole (sauf si bypass activé)
   if(!bypassCooldown)
   {
      int consecLoss = GetConsecutiveLosses();
      if(consecLoss >= 3)
      {
         // Démarrer un cooldown long si pas déjà actif
         if(!IsSymbolLossCooldownActive(1800))
            StartSymbolLossCooldown();
         
         if(IsSymbolLossCooldownActive(1800))
         {
            // Log seulement une fois par minute pour éviter le spam
            static datetime lastCooldownLog = 0;
            static string lastCooldownSymbol = "";
            datetime now = TimeCurrent();
            if(now - lastCooldownLog >= 60 || lastCooldownSymbol != _Symbol)
            {
               Print("🛑 COOLDOWN: 3 pertes consécutives sur ", _Symbol, " - pause 30 minutes");
               lastCooldownLog = now;
               lastCooldownSymbol = _Symbol;
            }
            return false;
         }
      }
      // Protection intermédiaire: après au moins 2 pertes consécutives, courte pause de 3 minutes
      else if(consecLoss >= 2)
      {
         if(!IsSymbolLossCooldownActive(180))
            StartSymbolLossCooldown();
         
         if(IsSymbolLossCooldownActive(180))
         {
            Print("⏸️ COOLDOWN: ", consecLoss, " pertes consécutives sur ", _Symbol, " - pause 3 minutes");
            return false;
         }
      }
   }

   // Limite de profit quotidien
   if(DailyProfitTargetUSD > 0 && GetTodayProfitUSD() >= DailyProfitTargetUSD)
   {
      Print("✅ Objectif de profit journalier atteint: ", DoubleToString(GetTodayProfitUSD(), 2), " USD. Nouvelles positions bloquées.");
      return false;
   }

   if(count >= maxGlobal)
   {
      Print("❌ PROTECTION: ", count, " positions déjà ouvertes. Maximum ", maxGlobal, " positions autorisées.");
      return false;
   }
   
   return true;
}

// Cooldown après 2 pertes consécutives sur ce symbole (3 minutes par défaut)
bool IsSymbolLossCooldownActive(int cooldownSec = 180)
{
   if(g_lastSymbolLossTime == 0) return false;
   return (TimeCurrent() - g_lastSymbolLossTime) < cooldownSec;
}

void StartSymbolLossCooldown()
{
   g_lastSymbolLossTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Extend the cooldown period for a specific symbol                |
//+------------------------------------------------------------------+
void ExtendSymbolLossCooldownForSymbol(string symbol, int additionalMinutes)
{
   // For now, we'll extend the global cooldown since the current implementation
   // only tracks cooldown globally. In a future update, we could implement
   // per-symbol cooldown tracking if needed.
   
   datetime now = TimeCurrent();
   if(g_lastSymbolLossTime == 0)
   {
      // If no cooldown is active, start one with the additional minutes
      g_lastSymbolLossTime = now - (additionalMinutes * 60);
      Print("⏰ Cooldown started for ", symbol, " for ", additionalMinutes, " minutes");
   }
   else
   {
      // Extend the existing cooldown by the additional minutes
      g_lastSymbolLossTime = g_lastSymbolLossTime - (additionalMinutes * 60);
      Print("⏰ Cooldown extended for ", symbol, " by ", additionalMinutes, " minutes");
   }
}

//+------------------------------------------------------------------+
//| Étend le cooldown de 10 minutes supplémentaires                  |
//+------------------------------------------------------------------+
void ExtendSymbolLossCooldown(int additionalMinutes = 10)
{
   datetime now = TimeCurrent();
   
   if(g_lastSymbolLossTime == 0)
   {
      // Si pas de cooldown actif, en démarrer un de 30 minutes + les minutes supplémentaires
      // On recule le temps de début pour que le cooldown dure (30 + additionalMinutes) minutes
      g_lastSymbolLossTime = now - (1800 + additionalMinutes * 60);
      Print("⏰ COOLDOWN DURCI: ", (1800 + additionalMinutes * 60) / 60, " minutes sur ", _Symbol, " (trade échoué malgré bypass)");
   }
   else
   {
      // Étendre le cooldown existant de 10 minutes supplémentaires
      datetime currentCooldownEnd = g_lastSymbolLossTime + 1800; // 30 minutes par défaut
      if(now < currentCooldownEnd)
      {
         // Le cooldown est encore actif, l'étendre en reculant le temps de début
         int remainingSeconds = (int)(currentCooldownEnd - now);
         g_lastSymbolLossTime = now - (remainingSeconds + (additionalMinutes * 60));
         Print("⏰ COOLDOWN DURCI: +", additionalMinutes, " minutes supplémentaires sur ", _Symbol, " (trade échoué malgré bypass)");
      }
      else
      {
         // Le cooldown est terminé, en démarrer un nouveau de 30 + 10 minutes
         g_lastSymbolLossTime = now - (1800 + additionalMinutes * 60);
         Print("⏰ COOLDOWN DURCI: ", (1800 + additionalMinutes * 60) / 60, " minutes sur ", _Symbol, " (trade échoué malgré bypass)");
      }
   }
}

// ------------------------------------------------------------------
// Gestion des fenêtres horaires envoyées par le serveur IA
// ------------------------------------------------------------------

int ParseInt(string s)
{
   StringTrimLeft(s);
   StringTrimRight(s);
   if(StringLen(s) == 0) return 0;
   return (int)StringToInteger(s);
}

void AI_UpdateTimeWindows()
{
   if(!UseAI_Agent || StringLen(AI_TimeWindowsURLBase) == 0)
      return;

   datetime now = TimeCurrent();
   // Mise à jour toutes les 4 heures OU si le symbole a changé
   bool symbolChanged = (g_timeWindowsSymbol != _Symbol);
   if(!symbolChanged && g_lastTimeWindowsUpdate != 0 && (now - g_lastTimeWindowsUpdate) < (4 * 3600))
      return;

   string url = AI_TimeWindowsURLBase;
   // S'assurer qu'on n'a pas déjà le suffixe
   if(StringSubstr(url, StringLen(url)-1, 1) == "/")
      url = StringSubstr(url, 0, StringLen(url)-1);
   url += "/time_windows/" + _Symbol;

   char data[];
   char result[];
   string headers = "";
   string result_headers = "";

   int res = WebRequest("GET", url, headers, AI_Timeout_ms, data, result, result_headers);
   if(res < 200 || res >= 300)
   {
      Print("AI_TimeWindows: WebRequest échec http=", res, " err=", GetLastError());
      return;
   }

   string resp = CharArrayToString(result, 0, -1, CP_UTF8);

   // Initialiser les tableaux à false
   ArrayInitialize(g_hourPreferred, false);
   ArrayInitialize(g_hourForbidden, false);

   // Parsing simple des tableaux preferred_hours et forbidden_hours (valeurs int séparées par virgules)
   int prefPos = StringFind(resp, "\"preferred_hours\"");
   if(prefPos >= 0)
   {
      int bracket1 = StringFind(resp, "[", prefPos);
      int bracket2 = StringFind(resp, "]", bracket1+1);
      if(bracket1 >= 0 && bracket2 > bracket1)
      {
         string arr = StringSubstr(resp, bracket1+1, bracket2-bracket1-1);
         int idx = 0;
         while(true)
         {
            string item = getJsonArrayItem("[" + arr + "]", idx);
            if(StringLen(item) == 0) break;
            int h = ParseInt(item);
            if(h >= 0 && h < 24) g_hourPreferred[h] = true;
            idx++;
         }
      }
   }

   int forbPos = StringFind(resp, "\"forbidden_hours\"");
   if(forbPos >= 0)
   {
      int bracket1 = StringFind(resp, "[", forbPos);
      int bracket2 = StringFind(resp, "]", bracket1+1);
      if(bracket1 >= 0 && bracket2 > bracket1)
      {
         string arr = StringSubstr(resp, bracket1+1, bracket2-bracket1-1);
         int idx = 0;
         while(true)
         {
            string item = getJsonArrayItem("[" + arr + "]", idx);
            if(StringLen(item) == 0) break;
            int h = ParseInt(item);
            if(h >= 0 && h < 24) g_hourForbidden[h] = true;
            idx++;
         }
      }
   }

   g_lastTimeWindowsUpdate = now;
   g_timeWindowsSymbol = _Symbol; // Mémoriser le symbole pour lequel les fenêtres ont été récupérées
}

void DrawTimeWindowsPanel()
{
   // Marqueur visuel en bas à gauche avec résumé des heures
   string name = "TIME_WINDOWS_PANEL";
   int corner = CORNER_LEFT_LOWER;

   // Vérifier que les fenêtres horaires correspondent au symbole actuel
   if(g_timeWindowsSymbol != _Symbol && StringLen(g_timeWindowsSymbol) > 0)
   {
      // Les fenêtres ne correspondent pas au symbole actuel
      string txt = "TimeWindows\nSymbol mismatch!\nCurrent: " + _Symbol + "\nWindows: " + g_timeWindowsSymbol;
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
         ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 5);
         ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 5);
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
      }
      ObjectSetString(0, name, OBJPROP_TEXT, txt);
      return;
   }

   MqlDateTime td;
   TimeCurrent(td);
   int hNow = td.hour;
   string status = "NEUTRAL";
   if(hNow >= 0 && hNow < 24)
   {
      if(g_hourForbidden[hNow]) status = "FORBIDDEN";
      else if(g_hourPreferred[hNow]) status = "PREFERRED";
   }

   // Construire un petit texte compact
   string txt = "TimeWindows\nNow: " + status + " (h=" + IntegerToString(hNow) + ")\nPref: ";
   bool first = true;
   for(int h=0; h<24; h++)
   {
      if(g_hourPreferred[h])
      {
         if(!first) txt += ",";
         txt += IntegerToString(h);
         first = false;
      }
   }

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, corner);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 5);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 5);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
}

// Vérifie si une position peut être fermée (respecte le délai minimum)
bool CanClosePosition(ulong ticket)
{
   if(ticket == 0 || !PositionSelectByTicket(ticket))
      return false;
   
   // Si le délai minimum est désactivé (0), on peut toujours fermer
   if(MinPositionLifetimeSec <= 0)
      return true;
   
   // Récupérer le temps d'ouverture de la position
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   datetime now = TimeCurrent();
   int ageSeconds = (int)(now - openTime);
   
   // Vérifier si la position est assez ancienne
   if(ageSeconds < MinPositionLifetimeSec)
   {
      Print("⚠️ Fermeture bloquée: position ", ticket, " trop récente (", ageSeconds, "s < ", MinPositionLifetimeSec, "s)");
      return false;
   }
   
   return true;
}

// Ferme toutes les positions ouvertes pour ce symbole/magic, quel que soit le gain/perte
void CloseAllPositionsForSymbolMagic()
{
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      // Vérifier le délai minimum avant fermeture
      if(!CanClosePosition(ticket))
         continue;

      double vol = PositionGetDouble(POSITION_VOLUME);
      if(ticket > 0 && vol > 0)
      {
         Print("Clôture position spike sur ", _Symbol, " ticket=", ticket, " volume=", DoubleToString(vol, 2));
         trade.PositionClose(ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Compte toutes les positions ouvertes (tous symboles confondus)  |
//| Cette fonction NE FILTRE PLUS sur le magic number :              |
//| elle renvoie le nombre total de positions du compte.            |
//+------------------------------------------------------------------+
int CountAllPositionsForMagic()
{
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
         cnt++;
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| Détermine la direction de trading autorisée selon le symbole     |
//+------------------------------------------------------------------+
//| Retourne :                                                       |
//|   1  = Achat uniquement (Boom)                                   |
//|  -1  = Vente uniquement (Crash)                                  |
//|   0  = Les deux directions sont autorisées                       |
//+------------------------------------------------------------------+
int AllowedDirectionFromSymbol(string sym)
{
   // Vérifier d'abord si c'est un marché Boom ou Crash
   bool isBoom = (StringFind(sym, "Boom") != -1);
   bool isCrash = (StringFind(sym, "Crash") != -1);
   bool isStepIndex = (StringFind(sym, "Step Index") != -1);
   
   // Règles de trading strictes pour Boom/Crash
   if(isBoom) return 1;    // Seulement des achats sur Boom
   if(isCrash) return -1;  // Seulement des ventes sur Crash
   
   // Pour Step Index: autoriser les deux directions MAIS avec logique de tendance
   if(isStepIndex) 
   {
      // Step Index peut être acheté ou vendu, MAIS doit suivre la tendance
      // Retourne 0 pour permettre les deux directions avec logique EMA dans CheckBasicEmaSignals
      return 0;
   }
   
   // Pour les autres symboles, les deux directions sont autorisées
   return 0;
}

//+------------------------------------------------------------------+
//| Vérifie si une direction de trading est autorisée pour le symbole|
//+------------------------------------------------------------------+
//| Retourne true si le trade est autorisé, false sinon              |
//+------------------------------------------------------------------+
bool IsTradeAllowed(int direction, string symbol = NULL)
{
   // Si aucun symbole n'est spécifié, utiliser le symbole actuel
   if(symbol == NULL) symbol = _Symbol;
   
   // Récupérer la direction autorisée pour ce symbole
   int allowedDir = AllowedDirectionFromSymbol(symbol);
   
   // Si aucune restriction (allowedDir = 0), le trade est autorisé
   if(allowedDir == 0) return true;
   
   // Vérifier si la direction demandée est autorisée
   return (direction == allowedDir);
}

// Dessine une flèche de spike Boom/Crash
void DrawSpikeArrow(bool isBuySpike, double price)
{
   string prefix = isBuySpike ? "SPIKE_BUY_" : "SPIKE_SELL_";
   string name   = prefix + TimeToString(TimeCurrent(), TIME_SECONDS) + "_" + IntegerToString(MathRand());

   // Nettoyer éventuellement un ancien objet avec le même nom (très improbable mais sûr)
   ObjectDelete(0, name);

   ENUM_OBJECT arrowType = isBuySpike ? OBJ_ARROW_BUY : OBJ_ARROW_SELL;
   if(!ObjectCreate(0, name, arrowType, 0, TimeCurrent(), price))
      return;

   color clr = isBuySpike ? clrLime : clrRed;
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
}

// -------------------------------------------------------------------
// IA : Appel serveur externe via WebRequest
// -------------------------------------------------------------------

int AI_GetDecision(double rsi, double atr,
                   double emaFastH1, double emaSlowH1,
                   double emaFastM1, double emaSlowM1,
                   double ask, double bid,
                   int dirRule, bool spikeMode)
{
   g_lastAIAction     = "";
   g_lastAIConfidence = 0.0;
   g_lastAIReason     = "";
   g_lastAIAnalysis   = "";  // 🆕 Réinitialiser l'analyse complète
   g_aiBuyZoneLow     = 0.0;
   g_aiBuyZoneHigh    = 0.0;
   g_aiSellZoneLow    = 0.0;
   g_aiSellZoneHigh   = 0.0;

   // Temporary flag added to satisfy volatility calculation block
   bool mt5_initialized = true;

   // Sécurité : si URL vide, on n'appelle pas
   if(StringLen(AI_ServerURL) == 0)
      return 0;

   // Validation des valeurs numériques (éviter NaN/Infinity)
   if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || 
      !MathIsValidNumber(rsi) || !MathIsValidNumber(atr) ||
      !MathIsValidNumber(emaFastH1) || !MathIsValidNumber(emaSlowH1) ||
      !MathIsValidNumber(emaFastM1) || !MathIsValidNumber(emaSlowM1))
   {
      if(DebugBlocks)
         Print("AI: valeurs invalides (NaN/Inf), skip WebRequest");
      return 0;
   }

   // Normalisation des valeurs pour éviter les problèmes de précision
   double safeBid = NormalizeDouble(bid, _Digits);
   double safeAsk = NormalizeDouble(ask, _Digits);
   double midPrice = (safeBid + safeAsk) / 2.0;
   double safeRsi = NormalizeDouble(rsi, 2);
   double safeAtr = NormalizeDouble(atr, _Digits);
   double safeEmaFastH1 = NormalizeDouble(emaFastH1, _Digits);
   double safeEmaSlowH1 = NormalizeDouble(emaSlowH1, _Digits);
   double safeEmaFastM1 = NormalizeDouble(emaFastM1, _Digits);
   double safeEmaSlowM1 = NormalizeDouble(emaSlowM1, _Digits);

   // Volatility calculation (simplified)
   double volatilityRatio = 0.0;
   int volatilityRegime = 0; // 0 = Normal, 1 = High Vol, -1 = Low Vol
   if(mt5_initialized)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      int copied = CopyRates(_Symbol, PERIOD_M1, 0, 200, rates);
      if(copied >= 100)
      {
         // ATR court (10) vs ATR long (50)
         double atrShort[], atrLong[];
         ArraySetAsSeries(atrShort, true);
         ArraySetAsSeries(atrLong, true);
         int atrShortHandle = iATR(_Symbol, PERIOD_M1, 10);
         int atrLongHandle = iATR(_Symbol, PERIOD_M1, 50);
         if(atrShortHandle != INVALID_HANDLE && atrLongHandle != INVALID_HANDLE)
         {
            if(CopyBuffer(atrShortHandle, 0, 0, 1, atrShort) > 0 &&
               CopyBuffer(atrLongHandle, 0, 0, 1, atrLong) > 0 &&
               atrLong[0] > 0.0)
            {
               volatilityRatio = atrShort[0] / atrLong[0];
               if(volatilityRatio > 1.5)
                  volatilityRegime = 1; // High Vol
               else if(volatilityRatio < 0.7)
                  volatilityRegime = -1; // Low Vol
            }
            IndicatorRelease(atrShortHandle);
            IndicatorRelease(atrLongHandle);
         }
      }
   }

   // Construction JSON sécurisée (échappement du symbole)
   string safeSymbol = _Symbol;
   StringReplace(safeSymbol, "\"", "\\\""); // Échapper les guillemets
   StringReplace(safeSymbol, "\\", "\\\\"); // Échapper les backslashes
   
   string payload = "{";
   payload += "\"symbol\":\"" + safeSymbol + "\"";
   payload += ",\"bid\":" + DoubleToString(safeBid, _Digits);
   payload += ",\"ask\":" + DoubleToString(safeAsk, _Digits);
   payload += ",\"rsi\":" + DoubleToString(safeRsi, 2);
   payload += ",\"ema_fast_h1\":" + DoubleToString(safeEmaFastH1, _Digits);
   payload += ",\"ema_slow_h1\":" + DoubleToString(safeEmaSlowH1, _Digits);
   payload += ",\"ema_fast_m1\":" + DoubleToString(safeEmaFastM1, _Digits);
   payload += ",\"ema_slow_m1\":" + DoubleToString(safeEmaSlowM1, _Digits);
   payload += ",\"atr\":" + DoubleToString(safeAtr, _Digits);
   payload += ",\"dir_rule\":" + IntegerToString(dirRule);
   payload += ",\"is_spike_mode\":" + (spikeMode ? "true" : "false");
   payload += ",\"volatility_regime\":" + IntegerToString(volatilityRegime);
   payload += ",\"volatility_ratio\":" + DoubleToString(volatilityRatio, 4);

   payload += "}";

   // Conversion en UTF-8 avec dimensionnement correct du tableau
   int payloadLen = StringLen(payload);
   char data[];
   ArrayResize(data, payloadLen + 1);
   int copied = StringToCharArray(payload, data, 0, WHOLE_ARRAY, CP_UTF8);
   
   // Vérification que la conversion a réussi
   if(copied <= 0 || copied > payloadLen + 1)
   {
      if(DebugBlocks)
         Print("AI: erreur conversion JSON en UTF-8, skip WebRequest");
      return 0;
   }
   
   // Ajuster la taille du tableau pour correspondre exactement aux données
   ArrayResize(data, copied - 1); // -1 car StringToCharArray ajoute un \0 terminal

   // Debug: vérifier le JSON complet (optionnel, peut être désactivé)
   if(DebugBlocks && StringLen(payload) > 200)
   {
      Print("AI JSON (preview): ", StringSubstr(payload, 0, 100), "...", StringSubstr(payload, StringLen(payload) - 50));
   }

   char result[];
   string headers = "Content-Type: application/json\r\n";
   string result_headers = "";

   // Utiliser l'endpoint decisionGemma si l'option est activée
   string decisionURL = AI_ServerURL;
   if(UseAdvancedDecisionGemma)
   {
      // Remplacer /decision par /decisionGemma
      StringReplace(decisionURL, "/decision", "/decisionGemma");
      if(DebugBlocks)
         Print("🤖 Utilisation endpoint decisionGemma avec analyse visuelle");
   }

   int res = WebRequest("POST", decisionURL, headers, AI_Timeout_ms, data, result, result_headers);

   // WebRequest renvoie directement le code HTTP (200, 404, etc.) ou -1 en cas d'erreur
   if(res < 200 || res >= 300)
   {
      int errorCode = GetLastError();
      Print("❌ AI WebRequest échec: http=", res, " - Erreur MT5: ", errorCode);
      if(errorCode == 4060)
      {
         Print("⚠️ ERREUR 4060: URL non autorisée dans MT5!");
         Print("   Allez dans: Outils -> Options -> Expert Advisors");
         Print("   Cochez 'Autoriser les WebRequest pour les URL listées'");
         Print("   Ajoutez: http://127.0.0.1");
      }
      return 0;
   }
   
   // Succès
   if(DebugBlocks)
      Print("✅ AI WebRequest réussi: http=", res);

   string resp = CharArrayToString(result, 0, -1, CP_UTF8);
   g_lastAIJson = resp; // Stocker la réponse brute pour affichage sur le graphique

   // Parsing minimaliste du JSON pour récupérer "action" et "confidence"
   int actionPos = StringFind(resp, "\"action\"");
   if(actionPos >= 0)
   {
      // Chercher "buy" ou "sell"
      if(StringFind(resp, "\"buy\"", actionPos) >= 0)
      {
         g_lastAIAction = "buy";
      }
      else if(StringFind(resp, "\"sell\"", actionPos) >= 0)
      {
         g_lastAIAction = "sell";
      }
      else
      {
         g_lastAIAction = "hold";
      }
   }

   int confPos = StringFind(resp, "\"confidence\"");
   if(confPos >= 0)
   {
      int colon = StringFind(resp, ":", confPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
         {
            string confStr = StringSubstr(resp, colon+1, endPos-colon-1);
            g_lastAIConfidence = StringToDouble(confStr);
         }
      }
   }

   // Extraire la raison (reason)
   g_lastAIReason = "";
   int reasonPos = StringFind(resp, "\"reason\"");
   if(reasonPos >= 0)
   {
      int colonR = StringFind(resp, ":", reasonPos);
      if(colonR > 0)
      {
         // Chercher le début de la chaîne (après ": ")
         int startQuote = StringFind(resp, "\"", colonR);
         if(startQuote > 0)
         {
            int endQuote = StringFind(resp, "\"", startQuote + 1);
            if(endQuote > startQuote)
            {
               g_lastAIReason = StringSubstr(resp, startQuote + 1, endQuote - startQuote - 1);
            }
         }
      }
   }

   // 🆕 Extraire l'analyse complète Gemma+Gemini (gemma_analysis)
   g_lastAIAnalysis = "";
   int analysisPos = StringFind(resp, "\"gemma_analysis\"");
   if(analysisPos >= 0)
   {
      int colonA = StringFind(resp, ":", analysisPos);
      if(colonA > 0)
      {
         // Chercher le début de la chaîne
         int startQuoteA = StringFind(resp, "\"", colonA);
         if(startQuoteA > 0)
         {
            int endQuoteA = StringFind(resp, "\"", startQuoteA + 1);
            if(endQuoteA > startQuoteA)
            {
               g_lastAIAnalysis = StringSubstr(resp, startQuoteA + 1, endQuoteA - startQuoteA - 1);
               // Si l'analyse Gemma est vide, utiliser le modèle utilisé
               if(StringLen(g_lastAIAnalysis) == 0)
               {
                  int modelPos = StringFind(resp, "\"model_used\"");
                  if(modelPos >= 0)
                  {
                     int colonM = StringFind(resp, ":", modelPos);
                     if(colonM > 0)
                     {
                        int startQuoteM = StringFind(resp, "\"", colonM);
                        if(startQuoteM > 0)
                        {
                           int endQuoteM = StringFind(resp, "\"", startQuoteM + 1);
                           if(endQuoteM > startQuoteM)
                           {
                              string modelUsed = StringSubstr(resp, startQuoteM + 1, endQuoteM - startQuoteM - 1);
                              g_lastAIAnalysis = "Modèle utilisé: " + modelUsed;
                           }
                        }
                     }
                  }
               }
            }
         }
      }
   }

   // Extraire prédiction de spike (spike_prediction) et pré‑alerte (early_spike_warning)
   g_aiSpikePredicted      = false;
   g_aiSpikeZonePrice      = 0.0;
   g_aiSpikeDirection      = true;
   g_aiStrongSpike         = false;
   g_aiEarlySpikeWarning   = false;
   g_aiEarlySpikeZonePrice = 0.0;
   g_aiEarlySpikeDirection = true;
   int spikePredPos = StringFind(resp, "\"spike_prediction\"");
   if(spikePredPos >= 0)
   {
      int colonSP = StringFind(resp, ":", spikePredPos);
      if(colonSP > 0)
      {
         // Chercher true/false
         if(StringFind(resp, "true", colonSP) >= 0)
         {
            g_aiSpikePredicted = true;
            g_aiStrongSpike    = true;
            // Chercher spike_zone_price
            int zonePos = StringFind(resp, "\"spike_zone_price\"");
            if(zonePos >= 0)
            {
               int colonZ = StringFind(resp, ":", zonePos);
               if(colonZ > 0)
               {
                  int endZ = StringFind(resp, ",", colonZ);
                  if(endZ < 0) endZ = StringFind(resp, "}", colonZ);
                  if(endZ > colonZ)
                  {
                     string zoneStr = StringSubstr(resp, colonZ+1, endZ-colonZ-1);
                     g_aiSpikeZonePrice = StringToDouble(zoneStr);
                  }
               }
            }
            // Chercher spike_direction (true=BUY, false=SELL)
            int dirPos = StringFind(resp, "\"spike_direction\"");
            if(dirPos >= 0)
            {
               int colonD = StringFind(resp, ":", dirPos);
               if(colonD > 0)
               {
                  if(StringFind(resp, "true", colonD) >= 0)
                     g_aiSpikeDirection = true; // BUY
                  else if(StringFind(resp, "false", colonD) >= 0)
                     g_aiSpikeDirection = false; // SELL
               }
            }
         }
      }
   }

   // Pré‑alerte de spike (early_spike_warning)
   int earlyPos = StringFind(resp, "\"early_spike_warning\"");
   if(earlyPos >= 0)
   {
      int colonE = StringFind(resp, ":", earlyPos);
      if(colonE > 0)
      {
         if(StringFind(resp, "true", colonE) >= 0)
         {
            g_aiEarlySpikeWarning = true;
            // Zone de pré‑spike
            int zonePosE = StringFind(resp, "\"early_spike_zone_price\"");
            if(zonePosE >= 0)
            {
               int colonZE = StringFind(resp, ":", zonePosE);
               if(colonZE > 0)
               {
                  int endZE = StringFind(resp, ",", colonZE);
                  if(endZE < 0) endZE = StringFind(resp, "}", colonZE);
                  if(endZE > colonZE)
                  {
                     string zoneStrE = StringSubstr(resp, colonZE+1, endZE-colonZE-1);
                     g_aiEarlySpikeZonePrice = StringToDouble(zoneStrE);
                  }
               }
            }
            // Direction early_spike_direction
            int dirPosE = StringFind(resp, "\"early_spike_direction\"");
            if(dirPosE >= 0)
            {
               int colonDE = StringFind(resp, ":", dirPosE);
               if(colonDE > 0)
               {
                  if(StringFind(resp, "true", colonDE) >= 0)
                     g_aiEarlySpikeDirection = true;
                  else if(StringFind(resp, "false", colonDE) >= 0)
                     g_aiEarlySpikeDirection = false;
               }
            }

            // Si aucun spike "fort" n'est encore détecté, utiliser la pré‑alerte pour l'affichage
            if(!g_aiStrongSpike)
            {
               g_aiSpikePredicted = true;
               g_aiSpikeZonePrice = g_aiEarlySpikeZonePrice;
               g_aiSpikeDirection = g_aiEarlySpikeDirection;
            }
         }
      }
   }

   // Extraire les zones H1 confirmées M5
   int zoneBuyLowPos = StringFind(resp, "\"buy_zone_low\"");
   if(zoneBuyLowPos >= 0)
   {
      int colon = StringFind(resp, ":", zoneBuyLowPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
         {
            string buyLowStr = StringSubstr(resp, colon+1, endPos-colon-1);
            StringTrimLeft(buyLowStr);
            StringTrimRight(buyLowStr);
            
            // Vérifier si la valeur est "null" ou vide
            if(buyLowStr == "null" || buyLowStr == "" || StringLen(buyLowStr) == 0)
            {
               // Calculer une valeur par défaut basée sur l'ATR
               double atr[1];
               double atrValue = 10; // Valeur par défaut
               if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
               {
                  atrValue = atr[0];
               }
               
               double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               g_aiBuyZoneLow = currentPrice - (atrValue * 0.5); // 0.5 ATR en dessous du prix
               // Log seulement si DebugBlocks est activé
               if(DebugBlocks)
                  PrintFormat("Zone ACHAT basse calculée (null): %s -> %f (basé sur ATR=%.2f)", buyLowStr, g_aiBuyZoneLow, atrValue);
            }
            else
            {
               double newBuyZoneLow = StringToDouble(buyLowStr);
               // Log seulement si la valeur a changé
               if(MathAbs(newBuyZoneLow - g_aiBuyZoneLow) > 0.01)
               {
                  g_aiBuyZoneLow = newBuyZoneLow;
                  if(DebugBlocks)
                     PrintFormat("Zone ACHAT basse extraite: %s -> %f", buyLowStr, g_aiBuyZoneLow);
               }
               else
               {
                  g_aiBuyZoneLow = newBuyZoneLow;
               }
            }
         }
      }
   }
   else
   {
      // Log seulement si DebugBlocks est activé
      if(DebugBlocks)
         Print("Avertissement: Champ 'buy_zone_low' non trouvé dans la réponse");
   }
   
   int zoneBuyHighPos = StringFind(resp, "\"buy_zone_high\"");
   if(zoneBuyHighPos >= 0)
   {
      int colon = StringFind(resp, ":", zoneBuyHighPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
         {
            string buyHighStr = StringSubstr(resp, colon+1, endPos-colon-1);
            StringTrimLeft(buyHighStr);
            StringTrimRight(buyHighStr);
            
            // Vérifier si la valeur est "null" ou vide
            if(buyHighStr == "null" || buyHighStr == "" || StringLen(buyHighStr) == 0)
            {
               // Calculer une valeur par défaut basée sur l'ATR
               double atr[1];
               double atrValue = 10; // Valeur par défaut
               if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
               {
                  atrValue = atr[0];
               }
               
               double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               g_aiBuyZoneHigh = currentPrice - (atrValue * 0.2); // 0.2 ATR en dessous du prix
               if(DebugBlocks)
                  PrintFormat("Zone ACHAT haute calculée (null): %s -> %f (basé sur ATR=%.2f)", buyHighStr, g_aiBuyZoneHigh, atrValue);
            }
            else
            {
               double newBuyZoneHigh = StringToDouble(buyHighStr);
               if(MathAbs(newBuyZoneHigh - g_aiBuyZoneHigh) > 0.01)
               {
                  g_aiBuyZoneHigh = newBuyZoneHigh;
                  if(DebugBlocks)
                     PrintFormat("Zone ACHAT haute extraite: %s -> %f", buyHighStr, g_aiBuyZoneHigh);
               }
               else
               {
                  g_aiBuyZoneHigh = newBuyZoneHigh;
               }
            }
         }
      }
   }
   else
   {
      if(DebugBlocks)
         Print("Avertissement: Champ 'buy_zone_high' non trouvé dans la réponse");
   }
   
   int zoneSellLowPos = StringFind(resp, "\"sell_zone_low\"");
   if(zoneSellLowPos >= 0)
   {
      int colon = StringFind(resp, ":", zoneSellLowPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
         {
            string sellLowStr = StringSubstr(resp, colon+1, endPos-colon-1);
            StringTrimLeft(sellLowStr);
            StringTrimRight(sellLowStr);
            
            // Vérifier si la valeur est "null" ou vide
            if(sellLowStr == "null" || sellLowStr == "" || StringLen(sellLowStr) == 0)
            {
               // Calculer une valeur par défaut basée sur l'ATR
               double atr[1];
               double atrValue = 10; // Valeur par défaut
               if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
               {
                  atrValue = atr[0];
               }
               
               double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               g_aiSellZoneLow = currentPrice + (atrValue * 0.2); // 0.2 ATR au-dessus du prix
               if(DebugBlocks)
                  PrintFormat("Zone VENTE basse calculée (null): %s -> %f (basé sur ATR=%.2f)", sellLowStr, g_aiSellZoneLow, atrValue);
            }
            else
            {
               double newSellZoneLow = StringToDouble(sellLowStr);
               if(MathAbs(newSellZoneLow - g_aiSellZoneLow) > 0.01)
               {
                  g_aiSellZoneLow = newSellZoneLow;
                  if(DebugBlocks)
                     PrintFormat("Zone VENTE basse extraite: %s -> %f", sellLowStr, g_aiSellZoneLow);
               }
               else
               {
                  g_aiSellZoneLow = newSellZoneLow;
               }
            }
         }
      }
   }
   else
   {
      if(DebugBlocks)
         Print("Avertissement: Champ 'sell_zone_low' non trouvé dans la réponse");
   }
   
   int zoneSellHighPos = StringFind(resp, "\"sell_zone_high\"");
   if(zoneSellHighPos >= 0)
   {
      int colon = StringFind(resp, ":", zoneSellHighPos);
      if(colon > 0)
      {
         int endPos = StringFind(resp, ",", colon);
         if(endPos < 0) endPos = StringFind(resp, "}", colon);
         if(endPos > colon)
         {
            string sellHighStr = StringSubstr(resp, colon+1, endPos-colon-1);
            StringTrimLeft(sellHighStr);
            StringTrimRight(sellHighStr);
            
            // Vérifier si la valeur est "null" ou vide
            if(sellHighStr == "null" || sellHighStr == "" || StringLen(sellHighStr) == 0)
            {
               // Calculer une valeur par défaut basée sur l'ATR
               double atr[1];
               double atrValue = 10; // Valeur par défaut
               if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
               {
                  atrValue = atr[0];
               }
               
               double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               g_aiSellZoneHigh = currentPrice + (atrValue * 0.5); // 0.5 ATR au-dessus du prix
               if(DebugBlocks)
                  PrintFormat("Zone VENTE haute calculée (null): %s -> %f (basé sur ATR=%.2f)", sellHighStr, g_aiSellZoneHigh, atrValue);
            }
            else
            {
               double newSellZoneHigh = StringToDouble(sellHighStr);
               if(MathAbs(newSellZoneHigh - g_aiSellZoneHigh) > 0.01)
               {
                  g_aiSellZoneHigh = newSellZoneHigh;
                  if(DebugBlocks)
                     PrintFormat("Zone VENTE haute extraite: %s -> %f", sellHighStr, g_aiSellZoneHigh);
               }
               else
               {
                  g_aiSellZoneHigh = newSellZoneHigh;
               }
            }
         }
      }
   }
   else
   {
      if(DebugBlocks)
         Print("Avertissement: Champ 'sell_zone_high' non trouvé dans la réponse");
   }
   
   // Vérification des zones extraites
   bool buyZoneValid = (g_aiBuyZoneLow > 0 && g_aiBuyZoneHigh > g_aiBuyZoneLow);
   bool sellZoneValid = (g_aiSellZoneLow > 0 && g_aiSellZoneHigh > g_aiSellZoneLow);
   
   if(buyZoneValid)
   {
      // Log seulement si DebugBlocks est activé
      if(DebugBlocks)
         Print("✅ Zone ACHAT valide: ", g_aiBuyZoneLow, " - ", g_aiBuyZoneHigh);
   }
   else
   {
      // Ne pas afficher d'avertissement si les deux zones sont à 0 (normal quand l'IA ne fournit pas de zones)
      if(g_aiBuyZoneLow != 0.0 || g_aiBuyZoneHigh != 0.0)
         Print("⚠️ Zone ACHAT invalide (low: ", g_aiBuyZoneLow, ", high: ", g_aiBuyZoneHigh, ")");
   }
   
   if(sellZoneValid)
   {
      // Log seulement si DebugBlocks est activé
      if(DebugBlocks)
         Print("✅ Zone VENTE valide: ", g_aiSellZoneLow, " - ", g_aiSellZoneHigh);
   }
   else
   {
      // Ne pas afficher d'avertissement si les deux zones sont à 0 (normal quand l'IA ne fournit pas de zones)
      if(g_aiSellZoneLow != 0.0 || g_aiSellZoneHigh != 0.0)
         Print("⚠️ Zone VENTE invalide (low: ", g_aiSellZoneLow, ", high: ", g_aiSellZoneHigh, ")");
   }
   
   // Afficher l'alerte de spike si prédit
   if(g_aiSpikePredicted)
   {
      DisplaySpikeAlert();
   }

   // Extract SL/TP
   g_lastAIStopLoss = AI_ExtractJsonDouble(resp, "stop_loss", 0);
   g_lastAITakeProfit = AI_ExtractJsonDouble(resp, "take_profit", 0);
   
   if(g_lastAIStopLoss > 0 || g_lastAITakeProfit > 0)
   {
      PrintFormat("🎯 AI Target Level: SL=%.5f TP=%.5f", g_lastAIStopLoss, g_lastAITakeProfit);
   }

   if(g_lastAIAction == "buy")
      return 1;
   if(g_lastAIAction == "sell")
      return -1;
   return 0; // hold / inconnu
}

// -------------------------------------------------------------------
//  IA - Analyse complète /analysis : structure H1 (trendlines, ETE)
// -------------------------------------------------------------------

// Helper interne : récupère un double après "\"key\":" à partir d'une position
double AI_ExtractJsonDouble(string &json, string key, int start_pos)
{
   int pos = StringFind(json, "\"" + key + "\"", start_pos);
   if(pos < 0) return 0.0;
   int colon = StringFind(json, ":", pos);
   if(colon < 0) return 0.0;
   int endPos = StringFind(json, ",", colon);
   if(endPos < 0) endPos = StringFind(json, "}", colon);
   if(endPos <= colon) return 0.0;
   string val = StringSubstr(json, colon+1, endPos-colon-1);
   StringTrimLeft(val);
   StringTrimRight(val);
   return StringToDouble(val);
}

// Helper : extrait deux paires (time, price) à partir d'un bloc trendline
void AI_ParseTrendlineBlock(string &json, int block_start,
                            double &start_price, datetime &start_time,
                            double &end_price, datetime &end_time)
{
   start_price = 0.0;
   end_price   = 0.0;
   start_time  = 0;
   end_time    = 0;

   if(block_start < 0) return;

   // Limiter la recherche au bloc courant (jusqu'à la prochaine trendline ou fin)
   int block_end = StringFind(json, "\"bearish\"", block_start+1);
   if(block_end < 0)
      block_end = StringFind(json, "}", block_start+1);
   if(block_end < 0)
      block_end = StringLen(json);

   int pos = block_start;
   // start.time
   int time1_pos = StringFind(json, "\"time\"", pos);
   if(time1_pos >= 0 && time1_pos < block_end)
   {
      start_time = (datetime)AI_ExtractJsonDouble(json, "time", time1_pos);
      int price1_pos = StringFind(json, "\"price\"", time1_pos);
      if(price1_pos >= 0 && price1_pos < block_end)
         start_price = AI_ExtractJsonDouble(json, "price", price1_pos);
      pos = price1_pos + 1;
   }
   // end.time
   int time2_pos = StringFind(json, "\"time\"", pos);
   if(time2_pos >= 0 && time2_pos < block_end)
   {
      end_time = (datetime)AI_ExtractJsonDouble(json, "time", time2_pos);
      int price2_pos = StringFind(json, "\"price\"", time2_pos);
      if(price2_pos >= 0 && price2_pos < block_end)
         end_price = AI_ExtractJsonDouble(json, "price", price2_pos);
   }
}

void DrawH1Structure()
{
   if(!AI_DrawH1Structure)
      return;

   // Nettoyer anciens objets
   ObjectDelete(0, "AI_H1_BULL_TL");
   ObjectDelete(0, "AI_H1_BEAR_TL");
   ObjectDelete(0, "AI_H1_ETE_HEAD");
   ObjectDelete(0, "AI_H4_BULL_TL");
   ObjectDelete(0, "AI_H4_BEAR_TL");
   ObjectDelete(0, "AI_M15_BULL_TL");
   ObjectDelete(0, "AI_M15_BEAR_TL");

   // Trendline haussière H1
   if(g_h1BullStartTime > 0 && g_h1BullEndTime > 0 &&
      g_h1BullStartPrice > 0 && g_h1BullEndPrice > 0)
   {
      ObjectCreate(0, "AI_H1_BULL_TL", OBJ_TREND, 0,
                   g_h1BullStartTime, g_h1BullStartPrice,
                   g_h1BullEndTime,   g_h1BullEndPrice);
      ObjectSetInteger(0, "AI_H1_BULL_TL", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, "AI_H1_BULL_TL", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "AI_H1_BULL_TL", OBJPROP_RAY_RIGHT, true);
   }

   // Trendline baissière H1
   if(g_h1BearStartTime > 0 && g_h1BearEndTime > 0 &&
      g_h1BearStartPrice > 0 && g_h1BearEndPrice > 0)
   {
      ObjectCreate(0, "AI_H1_BEAR_TL", OBJ_TREND, 0,
                   g_h1BearStartTime, g_h1BearStartPrice,
                   g_h1BearEndTime,   g_h1BearEndPrice);
      ObjectSetInteger(0, "AI_H1_BEAR_TL", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "AI_H1_BEAR_TL", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "AI_H1_BEAR_TL", OBJPROP_RAY_RIGHT, true);
   }

   // Trendline haussière H4
   if(g_h4BullStartTime > 0 && g_h4BullEndTime > 0 &&
      g_h4BullStartPrice > 0 && g_h4BullEndPrice > 0)
   {
      ObjectCreate(0, "AI_H4_BULL_TL", OBJ_TREND, 0,
                   g_h4BullStartTime, g_h4BullStartPrice,
                   g_h4BullEndTime,   g_h4BullEndPrice);
      ObjectSetInteger(0, "AI_H4_BULL_TL", OBJPROP_COLOR, clrForestGreen);
      ObjectSetInteger(0, "AI_H4_BULL_TL", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "AI_H4_BULL_TL", OBJPROP_RAY_RIGHT, true);
   }

   // Trendline baissière H4
   if(g_h4BearStartTime > 0 && g_h4BearEndTime > 0 &&
      g_h4BearStartPrice > 0 && g_h4BearEndPrice > 0)
   {
      ObjectCreate(0, "AI_H4_BEAR_TL", OBJ_TREND, 0,
                   g_h4BearStartTime, g_h4BearStartPrice,
                   g_h4BearEndTime,   g_h4BearEndPrice);
      ObjectSetInteger(0, "AI_H4_BEAR_TL", OBJPROP_COLOR, clrMaroon);
      ObjectSetInteger(0, "AI_H4_BEAR_TL", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "AI_H4_BEAR_TL", OBJPROP_RAY_RIGHT, true);
   }

   // Trendline haussière M15
   if(g_m15BullStartTime > 0 && g_m15BullEndTime > 0 &&
      g_m15BullStartPrice > 0 && g_m15BullEndPrice > 0)
   {
      ObjectCreate(0, "AI_M15_BULL_TL", OBJ_TREND, 0,
                   g_m15BullStartTime, g_m15BullStartPrice,
                   g_m15BullEndTime,   g_m15BullEndPrice);
      ObjectSetInteger(0, "AI_M15_BULL_TL", OBJPROP_COLOR, clrDarkOliveGreen);
      ObjectSetInteger(0, "AI_M15_BULL_TL", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "AI_M15_BULL_TL", OBJPROP_RAY_RIGHT, true);
   }

   // Trendline baissière M15
   if(g_m15BearStartTime > 0 && g_m15BearEndTime > 0 &&
      g_m15BearStartPrice > 0 && g_m15BearEndPrice > 0)
   {
      ObjectCreate(0, "AI_M15_BEAR_TL", OBJ_TREND, 0,
                   g_m15BearStartTime, g_m15BearStartPrice,
                   g_m15BearEndTime,   g_m15BearEndPrice);
      ObjectSetInteger(0, "AI_M15_BEAR_TL", OBJPROP_COLOR, clrFireBrick);
      ObjectSetInteger(0, "AI_M15_BEAR_TL", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "AI_M15_BEAR_TL", OBJPROP_RAY_RIGHT, true);
   }

   // Tête de la figure ETE (si présente)
   if(g_h1ETEFound && g_h1ETEHeadTime > 0 && g_h1ETEHeadPrice > 0)
   {
      ObjectCreate(0, "AI_H1_ETE_HEAD", OBJ_ARROW_DOWN, 0,
                   g_h1ETEHeadTime, g_h1ETEHeadPrice);
      ObjectSetInteger(0, "AI_H1_ETE_HEAD", OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, "AI_H1_ETE_HEAD", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "AI_H1_ETE_HEAD", OBJPROP_ARROWCODE, 234);
   }
}

void AI_UpdateAnalysis()
{
   if(!AI_DrawH1Structure)
      return;
   
   datetime now = TimeCurrent();
   if(now - g_lastAIAnalysisTime < AI_AnalysisIntervalSec)
      return;

   g_lastAIAnalysisTime = now;

   // Récupérer les données H1 locales
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_H1, 0, 400, rates);
   if(copied <= 0)
      return;

   ArraySetAsSeries(rates, false); // 0 = plus ancien

   // Détecter les swings H1
   H1SwingPoint swings[];
   int total = 0;

   int lookback   = 3;  // fenêtre de détection des swings (peut être ajustée)
   int minSpacing = 3;  // espacement minimum entre deux swings
   if(lookback < 1) lookback = 1;
   if(minSpacing < 1) minSpacing = 1;

   for(int i = lookback; i < copied - lookback; i++)
   {
      double hi = rates[i].high;
      double lo = rates[i].low;

      bool isHigh = true;
      bool isLow  = true;

      for(int j = i - lookback; j <= i + lookback; j++)
      {
         if(j == i) continue;
         if(rates[j].high >= hi) isHigh = false;
         if(rates[j].low  <= lo) isLow  = false;
         if(!isHigh && !isLow) break;
      }

      if(isHigh || isLow)
      {
         if(total > 0 && (i - swings[total-1].index) < minSpacing)
            continue;

         H1SwingPoint sp;
         sp.index  = i;
         sp.time   = rates[i].time;
         sp.price  = isHigh ? hi : lo;
         sp.isHigh = isHigh;

         ArrayResize(swings, total + 1);
         swings[total] = sp;
         total++;
      }
   }

   // Réinitialiser structure H1
   g_h1BullStartPrice = g_h1BullEndPrice = 0.0;
   g_h1BullStartTime  = g_h1BullEndTime  = 0;
   g_h1BearStartPrice = g_h1BearEndPrice = 0.0;
   g_h1BearStartTime  = g_h1BearEndTime  = 0;

   // Trendline haussière (deux derniers creux ascendants)
   H1SwingPoint lows[];
   int lowCount = 0;
   for(int k = 0; k < total; k++)
   {
      if(!swings[k].isHigh)
      {
         ArrayResize(lows, lowCount + 1);
         lows[lowCount] = swings[k];
         lowCount++;
      }
   }
   if(lowCount >= 2)
   {
      H1SwingPoint l1 = lows[lowCount-2];
      H1SwingPoint l2 = lows[lowCount-1];
      if(l2.price > l1.price)
      {
         g_h1BullStartPrice = l1.price;
         g_h1BullEndPrice   = l2.price;
         g_h1BullStartTime  = l1.time;
         g_h1BullEndTime    = l2.time;
      }
   }

   // Trendline baissière (deux derniers sommets descendants)
   H1SwingPoint highs[];
   int highCount = 0;
   for(int k = 0; k < total; k++)
   {
      if(swings[k].isHigh)
      {
         ArrayResize(highs, highCount + 1);
         highs[highCount] = swings[k];
         highCount++;
      }
   }
   if(highCount >= 2)
   {
      H1SwingPoint h1 = highs[highCount-2];
      H1SwingPoint h2 = highs[highCount-1];
      if(h2.price < h1.price)
      {
         g_h1BearStartPrice = h1.price;
         g_h1BearEndPrice   = h2.price;
         g_h1BearStartTime  = h1.time;
         g_h1BearEndTime    = h2.time;
      }
   }

   //======================= H4 & M15 TRENDLINES =======================
   // Même logique de swings que pour H1, appliquée à H4 puis M15.

   // --- H4 ---
   MqlRates ratesH4[];
   ArraySetAsSeries(ratesH4, true);
   int copiedH4 = CopyRates(_Symbol, PERIOD_H4, 0, 400, ratesH4);
   if(copiedH4 > 0)
   {
      ArraySetAsSeries(ratesH4, false);

      H1SwingPoint swingsH4[];
      int totalH4 = 0;
      for(int i4 = lookback; i4 < copiedH4 - lookback; i4++)
      {
         double hi4 = ratesH4[i4].high;
         double lo4 = ratesH4[i4].low;
         bool isHigh4 = true;
         bool isLow4  = true;
         for(int j4 = i4 - lookback; j4 <= i4 + lookback; j4++)
         {
            if(j4 == i4) continue;
            if(ratesH4[j4].high >= hi4) isHigh4 = false;
            if(ratesH4[j4].low  <= lo4) isLow4  = false;
            if(!isHigh4 && !isLow4) break;
         }
         if(isHigh4 || isLow4)
         {
            if(totalH4 > 0 && (i4 - swingsH4[totalH4-1].index) < minSpacing)
               continue;
            H1SwingPoint sp4;
            sp4.index  = i4;
            sp4.time   = ratesH4[i4].time;
            sp4.price  = isHigh4 ? hi4 : lo4;
            sp4.isHigh = isHigh4;
            ArrayResize(swingsH4, totalH4 + 1);
            swingsH4[totalH4] = sp4;
            totalH4++;
         }
      }

      // Reset H4
      g_h4BullStartPrice = g_h4BullEndPrice = 0.0;
      g_h4BullStartTime  = g_h4BullEndTime  = 0;
      g_h4BearStartPrice = g_h4BearEndPrice = 0.0;
      g_h4BearStartTime  = g_h4BearEndTime  = 0;

      // Trendline haussière H4
      H1SwingPoint lowsH4[];
      int lowH4Count = 0;
      for(int k4 = 0; k4 < totalH4; k4++)
      {
         if(!swingsH4[k4].isHigh)
         {
            ArrayResize(lowsH4, lowH4Count + 1);
            lowsH4[lowH4Count] = swingsH4[k4];
            lowH4Count++;
         }
      }
      if(lowH4Count >= 2)
      {
         H1SwingPoint l14 = lowsH4[lowH4Count-2];
         H1SwingPoint l24 = lowsH4[lowH4Count-1];
         if(l24.price > l14.price)
         {
            g_h4BullStartPrice = l14.price;
            g_h4BullEndPrice   = l24.price;
            g_h4BullStartTime  = l14.time;
            g_h4BullEndTime    = l24.time;
         }
      }

      // Trendline baissière H4
      H1SwingPoint highsH4[];
      int highH4Count = 0;
      for(int k4 = 0; k4 < totalH4; k4++)
      {
         if(swingsH4[k4].isHigh)
         {
            ArrayResize(highsH4, highH4Count + 1);
            highsH4[highH4Count] = swingsH4[k4];
            highH4Count++;
         }
      }
      if(highH4Count >= 2)
      {
         H1SwingPoint h14 = highsH4[highH4Count-2];
         H1SwingPoint h24 = highsH4[highH4Count-1];
         if(h24.price < h14.price)
         {
            g_h4BearStartPrice = h14.price;
            g_h4BearEndPrice   = h24.price;
            g_h4BearStartTime  = h14.time;
            g_h4BearEndTime    = h24.time;
         }
      }
   }

   // --- M15 ---
   MqlRates ratesM15[];
   ArraySetAsSeries(ratesM15, true);
   int copiedM15 = CopyRates(_Symbol, PERIOD_M15, 0, 400, ratesM15);
   if(copiedM15 > 0)
   {
      ArraySetAsSeries(ratesM15, false);

      H1SwingPoint swingsM15[];
      int totalM15 = 0;
      for(int i15 = lookback; i15 < copiedM15 - lookback; i15++)
      {
         double hi15 = ratesM15[i15].high;
         double lo15 = ratesM15[i15].low;
         bool isHigh15 = true;
         bool isLow15  = true;
         for(int j15 = i15 - lookback; j15 <= i15 + lookback; j15++)
         {
            if(j15 == i15) continue;
            if(ratesM15[j15].high >= hi15) isHigh15 = false;
            if(ratesM15[j15].low  <= lo15) isLow15  = false;
            if(!isHigh15 && !isLow15) break;
         }
         if(isHigh15 || isLow15)
         {
            if(totalM15 > 0 && (i15 - swingsM15[totalM15-1].index) < minSpacing)
               continue;
            H1SwingPoint sp15;
            sp15.index  = i15;
            sp15.time   = ratesM15[i15].time;
            sp15.price  = isHigh15 ? hi15 : lo15;
            sp15.isHigh = isHigh15;
            ArrayResize(swingsM15, totalM15 + 1);
            swingsM15[totalM15] = sp15;
            totalM15++;
         }
      }

      // Reset M15
      g_m15BullStartPrice = g_m15BullEndPrice = 0.0;
      g_m15BullStartTime  = g_m15BullEndTime  = 0;
      g_m15BearStartPrice = g_m15BearEndPrice = 0.0;
      g_m15BearStartTime  = g_m15BearEndTime  = 0;

      // Trendline haussière M15
      H1SwingPoint lowsM15[];
      int lowM15Count = 0;
      for(int k15 = 0; k15 < totalM15; k15++)
      {
         if(!swingsM15[k15].isHigh)
         {
            ArrayResize(lowsM15, lowM15Count + 1);
            lowsM15[lowM15Count] = swingsM15[k15];
            lowM15Count++;
         }
      }
      if(lowM15Count >= 2)
      {
         H1SwingPoint l115 = lowsM15[lowM15Count-2];
         H1SwingPoint l215 = lowsM15[lowM15Count-1];
         if(l215.price > l115.price)
         {
            g_m15BullStartPrice = l115.price;
            g_m15BullEndPrice   = l215.price;
            g_m15BullStartTime  = l115.time;
            g_m15BullEndTime    = l215.time;
         }
      }

      // Trendline baissière M15
      H1SwingPoint highsM15[];
      int highM15Count = 0;
      for(int k15 = 0; k15 < totalM15; k15++)
      {
         if(swingsM15[k15].isHigh)
         {
            ArrayResize(highsM15, highM15Count + 1);
            highsM15[highM15Count] = swingsM15[k15];
            highM15Count++;
         }
      }
      if(highM15Count >= 2)
      {
         H1SwingPoint h115 = highsM15[highM15Count-2];
         H1SwingPoint h215 = highsM15[highM15Count-1];
         if(h215.price < h115.price)
         {
            g_m15BearStartPrice = h115.price;
            g_m15BearEndPrice   = h215.price;
            g_m15BearStartTime  = h115.time;
            g_m15BearEndTime    = h215.time;
         }
      }
   }

   // Mettre à jour des zones locales S/R H1 sous forme de rectangles (buy/sell zones)
   double lastRange = rates[copied-1].high - rates[copied-1].low;
   if(lastRange <= 0.0)
      lastRange = 10 * _Point;
   double buffer = MathMax(lastRange * 0.5, 10 * _Point);

   // Zone d'achat autour du dernier creux H1
   if(lowCount > 0)
   {
      H1SwingPoint lastLow = lows[lowCount-1];
      g_aiBuyZoneLow  = lastLow.price - buffer;
      g_aiBuyZoneHigh = lastLow.price + buffer;
   }

   // Zone de vente autour du dernier sommet H1
   if(highCount > 0)
   {
      H1SwingPoint lastHigh = highs[highCount-1];
      g_aiSellZoneLow  = lastHigh.price - buffer;
      g_aiSellZoneHigh = lastHigh.price + buffer;
   }

   // (Optionnel) reset ETE local car non recalculé ici
   g_h1ETEFound     = false;
   g_h1ETEHeadPrice = 0.0;
   g_h1ETEHeadTime  = 0;

   DrawH1Structure();
}

// -------------------------------------------------------------------
// IA : Affichage dans un panneau séparé (BAS À DROITE, 3 lignes max)
// -------------------------------------------------------------------
void DrawAIRecommendation(string action, double confidence, string reason, double price)
{
   // Nom unique par symbole pour éviter les collisions entre graphiques
   string panelName = "AI_PANEL_MAIN_" + _Symbol;
   string detailPanelName = "AI_PANEL_DETAIL_" + _Symbol;
   
   // Supprimer les anciens panneaux
   ObjectDelete(0, panelName);
   ObjectDelete(0, detailPanelName);
   
   // Créer le panneau principal (résumé) avec gestion d'erreur
   if(!ObjectCreate(0, panelName, OBJ_LABEL, 0, 0, 0))
   {
      int err = GetLastError();
      if(err != 0)
         Print("❌ Erreur création panneau IA principal: ", err);
      return;
   }
   
   // Positionner en bas à droite
   ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 50);
   ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
   ObjectSetInteger(0, panelName, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
   ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, panelName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, panelName, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, panelName, OBJPROP_ZORDER, 0);
   ObjectSetInteger(0, panelName, OBJPROP_FONTSIZE, 16);
   ObjectSetString(0, panelName, OBJPROP_FONT, "Arial Bold");
   
   // Couleur selon l'action
   color clr = clrWhite;
   if(action == "buy")  clr = clrLime;
   if(action == "sell") clr = clrRed;
   if(action == "hold") clr = clrSilver;
   
   ObjectSetInteger(0, panelName, OBJPROP_COLOR, clr);
   
   // Construire le texte du panneau principal
   string actionUpper = action;
   StringToUpper(actionUpper);
   
   string txt = "";
   if(action == "buy")
      txt += "🤖 IA " + _Symbol + ": ACHAT " + DoubleToString(confidence * 100.0, 0) + "%\n";
   else if(action == "sell")
      txt += "🤖 IA " + _Symbol + ": VENTE " + DoubleToString(confidence * 100.0, 0) + "%\n";
   else
      txt += "🤖 IA " + _Symbol + ": ATTENTE\n";
   
   // Ligne 2: Confiance
   if(confidence > 0.0)
      txt += "Confiance: " + DoubleToString(confidence * 100.0, 1) + "%\n";
   else
      txt += "Analyse en cours...\n";
   
   // Ligne 3: Raison (limitée à 40 caractères)
   if(StringLen(reason) > 0)
   {
      string shortReason = reason;
      if(StringLen(shortReason) > 40)
         shortReason = StringSubstr(shortReason, 0, 37) + "...";
      txt += shortReason;
   }
   else
      txt += "En attente de signal";
   
   ObjectSetString(0, panelName, OBJPROP_TEXT, txt);
   
   // Créer le panneau détaillé (analyse Gemma+Gemini) uniquement si nécessaire
   if(StringLen(g_lastAIAnalysis) > 0 && UseAdvancedDecisionGemma)
   {
      if(!ObjectCreate(0, detailPanelName, OBJ_LABEL, 0, 0, 0))
      {
         int err = GetLastError();
         if(err != 0)
            Print("❌ Erreur création panneau IA détail: ", err);
         return;
      }
      
      // Positionner au-dessus du panneau principal
      ObjectSetInteger(0, detailPanelName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, detailPanelName, OBJPROP_YDISTANCE, 150);
      ObjectSetInteger(0, detailPanelName, OBJPROP_CORNER, CORNER_RIGHT_LOWER);
      ObjectSetInteger(0, detailPanelName, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
      ObjectSetInteger(0, detailPanelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, detailPanelName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, detailPanelName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, detailPanelName, OBJPROP_ZORDER, 0);
      ObjectSetInteger(0, detailPanelName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, detailPanelName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, detailPanelName, OBJPROP_COLOR, clrYellow);
      
      // Construire le texte détaillé
      string detailTxt = "🧠 ANALYSE IA COMPLÈTE\n";
      detailTxt += "━━━━━━━━━━━━━━━━━━━━\n";
      detailTxt += "Modèle: Gemma+Gemini\n\n";
      
      // Ajouter l'analyse complète si disponible
      if(StringLen(g_lastAIAnalysis) > 0)
      {
         string analysis = g_lastAIAnalysis;
         // Couper le texte en lignes de 50 caractères max
         string lines[20]; // Maximum 20 lignes
         int lineCount = 0;
         
         while(StringLen(analysis) > 0 && lineCount < 20)
         {
            if(StringLen(analysis) <= 50)
            {
               lines[lineCount] = analysis;
               analysis = "";
            }
            else
            {
               lines[lineCount] = StringSubstr(analysis, 0, 50);
               analysis = StringSubstr(analysis, 50);
            }
            lineCount++;
         }
         
         // Ajouter les 4 premières lignes (plus de détails)
         for(int i = 0; i < MathMin(lineCount, 4); i++)
         {
            detailTxt += lines[i] + "\n";
         }
         
         if(lineCount > 4)
            detailTxt += "...";
      }
      else
      {
         detailTxt += "Analyse en cours...";
      }
      
      ObjectSetString(0, detailPanelName, OBJPROP_TEXT, detailTxt);
   }
}

// Affiche un label d'information quand un signal IA est bloqué par la validation
void DrawAIBlockLabel(string symbol, string title, string reason)
{
   string name = "AI_BLOCK_LABEL_" + symbol;
   ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      return;

   string txt = title + " (" + symbol + ")\n" + reason;
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 40);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
}
// -------------------------------------------------------------------
// Tableau de bord serveur IA (affichage continu des données renvoyées)
// -------------------------------------------------------------------
void DrawServerDashboard()
{
   string panelName = "AI_SERVER_DASH_" + _Symbol;
   string textName  = panelName + "_TXT";

   // Créer le conteneur si absent
   if(ObjectFind(0, panelName) < 0)
   {
      ObjectCreate(0, panelName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 50);
      ObjectSetInteger(0, panelName, OBJPROP_XSIZE, 320);
      ObjectSetInteger(0, panelName, OBJPROP_YSIZE, 90);
      ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, panelName, OBJPROP_BGCOLOR, clrBlack);
      ObjectSetInteger(0, panelName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, panelName, OBJPROP_BACK, true);
      ObjectSetInteger(0, panelName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, panelName, OBJPROP_SELECTABLE, false);
   }

   // Construire le texte avec les dernières données serveur
   string action = (g_lastAIAction == "") ? "hold" : g_lastAIAction;
   string actionLabel = (action == "buy") ? "ACHAT" : (action == "sell" ? "VENTE" : "ATTENTE");
   color actionColor = (action == "buy") ? clrLime : (action == "sell" ? clrRed : clrSilver);

   string reason = g_lastAIReason;
   if(StringLen(reason) > 70) reason = StringSubstr(reason, 0, 67) + "...";

   string spike = "";
   if(g_aiSpikePredicted && g_lastAIConfidence > 0)
   {
      spike = StringFormat("\n📈 Spike prévu: %s @ %.2f (Confiance: %.0f%%)",
                           g_aiSpikeDirection ? "ACHAT" : "VENTE",
                           g_aiSpikeZonePrice,
                           g_lastAIConfidence * 100.0);
   }
   else
   {
      spike = "Spike: n/a";
   }

   string updated = (g_lastAITime > 0) ? TimeToString(g_lastAITime, TIME_DATE|TIME_SECONDS) : "n/a";

   // Aperçu JSON (brut) renvoyé par le serveur IA pour ce symbole
   string jsonPreview = g_lastAIJson;
   if(StringLen(jsonPreview) > 180)
      jsonPreview = StringSubstr(jsonPreview, 0, 177) + "...";

   string txt = StringFormat("Action: %s   Conf: %.0f%%\nRaison: %s\n%s\nMaj: %s\nJSON: %s",
                             actionLabel,
                             g_lastAIConfidence * 100.0,
                             reason,
                             spike,
                             updated,
                             jsonPreview);

   // Créer / mettre à jour le label texte de manière sécurisée
   if(!ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0))
   {
      // Si l'objet existe déjà, on le met simplement à jour
      int err = GetLastError();
      if(err != 4200) // ERR_OBJECT_ALREADY_EXISTS = 4200
      {
         Print("Erreur création objet texte: ", err);
         return;
      }
   }
   
   // Désactiver la sélection et le déplacement
   ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, textName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, textName, OBJPROP_HIDDEN, true);
   
   // Configurer l'apparence
   ObjectSetString(0, textName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, actionColor);
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, 15);
   ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, 55);
   
   // Forcer la mise à jour du graphique
   ChartRedraw(0);
}
// -------------------------------------------------------------------
// IA : Calcul multiplicateur de lot basé sur la confiance IA
// -------------------------------------------------------------------
double AI_GetLotMultiplier(ENUM_ORDER_TYPE type, int aiAction, double aiConfidence)
{
   if(!UseAI_Agent || aiConfidence < AI_MinConfidence)
      return 1.0; // Pas d'influence si confiance trop faible
   
   // Si l'IA est d'accord avec la direction
   bool aiAgrees = ((type == ORDER_TYPE_BUY && aiAction > 0) || 
                    (type == ORDER_TYPE_SELL && aiAction < 0));
   
   if(aiAgrees)
   {
      // Utiliser le lot minimum du broker au lieu de multiplier
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      return minLot; // Toujours utiliser le minimum pour éviter les lots élevés
   }
   else
   {
      // Réduire le lot si l'IA n'est pas d'accord (min 0.3x)
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      return minLot; // Toujours utiliser le minimum
   }
}

// -------------------------------------------------------------------
// IA : Envoyer notification push MT5 pour signal consolidé
// -------------------------------------------------------------------
void AI_SendNotification(string signalType, string direction, double confidence, string reason)
{
   if(!AI_UseNotifications) return;
   
   // Vérifier si on a déjà envoyé cette notification récemment (anti-spam)
   static datetime lastNotifTime = 0;
   static string lastNotif = "";
   string currentNotif = signalType + "_" + direction + "_" + DoubleToString(confidence, 2);
   
   if(TimeCurrent() - lastNotifTime < 300 && lastNotif == currentNotif) // 5 minutes entre notifications identiques
      return;
   
   // Construire le message de notification
   string msg = "";
   string spikeProb = "";
   
   // Calculer la probabilité de spike si disponible
   if(g_aiSpikePredicted && g_lastAIConfidence > 0)
   {
      spikeProb = StringFormat("\n📈 Probabilité de spike: %.1f%%", g_lastAIConfidence * 100.0);
   }
   
   if(signalType == "IA_SIGNAL")
   {
      msg = StringFormat("🚀 SIGNAL %s - %s\nConfiance: %.1f%%%s\n%s", 
                        _Symbol, direction, confidence * 100.0, spikeProb, reason);
   }
   else if(signalType == "AUTO_M1")
   {
      msg = StringFormat("⚡ %s - %s (M1)\nConfiance: %.1f%%%s\n%s", 
                        _Symbol, direction, confidence * 100.0, spikeProb, reason);
   }
   else if(signalType == "RSI_TREND_BUY" || signalType == "RSI_TREND_SELL")
   {
      string type = (signalType == "RSI_TREND_BUY") ? "RSI ACHAT" : "RSI VENTE";
      msg = StringFormat("📊 %s - %s\nConfiance: %.1f%%%s\n%s", 
                        _Symbol, type, confidence * 100.0, spikeProb, reason);
   }
   else if(signalType == "SPIKE_DETECTED")
   {
      msg = StringFormat("🚨 SPIKE DÉTECTÉ - %s\nProbabilité: %.1f%%\n%s", 
                        direction, confidence * 100.0, reason);
   }
   
   if(msg == "") return; // Type de signal non géré
   
   // Envoyer notification push MT5 (apparaît dans les notifications du terminal)
   SendNotification(msg);
   Print("📱 NOTIFICATION PUSH MT5: ", msg);
   
   g_lastNotificationTime = TimeCurrent();
   g_lastNotificationSignal = signalType;
   lastNotifTime = TimeCurrent();
   lastNotif = currentNotif;
}

// -------------------------------------------------------------------
// IA : Affichage des prédictions de spike (une seule flèche qui se met à jour)
// -------------------------------------------------------------------
void DrawSpikePrediction(double price, bool isUp)
{
   if(!AI_PredictSpikes || price <= 0) 
   {
      // Si désactivé ou prix invalide, supprimer la flèche existante
      ObjectDelete(0, "AI_SPIKE_PREDICTION");
      g_aiSpikePredicted = false;
      g_aiSpikeExecuted  = false;
      g_aiSpikePendingPlaced = false;
      return;
   }
   
   // Créer ou mettre à jour la flèche existante
   if(ObjectFind(0, "AI_SPIKE_PREDICTION") < 0)
   {
      if(!ObjectCreate(0, "AI_SPIKE_PREDICTION", OBJ_ARROW, 0, TimeCurrent(), price))
      {
         Print("Erreur création flèche prédiction: ", GetLastError());
         return;
      }
   }
   else
   {
      ObjectMove(0, "AI_SPIKE_PREDICTION", 0, TimeCurrent(), price);
   }

   // Style de la flèche
   int arrowCode = isUp ? 233 : 234; // Flèche vers le haut ou vers le bas
   color arrowColor = isUp ? clrLime : clrRed;
   
   // Mettre à jour les propriétés de l'objet
   string objName = "AI_SPIKE_PREDICTION";
   
   // Vérifier si l'objet existe, sinon le créer
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_ARROW, 0, TimeCurrent(), price);
   }
   
   // Mettre à jour les propriétés
   ObjectMove(0, objName, 0, TimeCurrent(), price);
   ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, arrowColor);
   ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   ObjectSetInteger(0, objName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
   
   // Mettre à jour les variables globales
   g_aiSpikePredicted = true;
   g_aiSpikeZonePrice = price;
   g_aiSpikeDirection = isUp;
   g_aiSpikePredictionTime = TimeCurrent();
   g_aiSpikeExecuted  = false;
   g_aiSpikeExecTime  = 0;
   g_aiSpikePendingPlaced = false;
   
   // Forcer le rafraîchissement du graphique
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Affiche la flèche clignotante de spike prédit et exécute le trade|
//+------------------------------------------------------------------+
void DisplaySpikeAlert()
{
   // Ne gérer les spikes automatiquement que sur les indices Boom/Crash et en M1
   if(Period() != PERIOD_M1)
      return;

   // Cooldown après plusieurs tentatives ratées : ignorer les nouveaux signaux
   if(g_spikeCooldownUntil > 0 && TimeCurrent() < g_spikeCooldownUntil)
      return;

   // Déterminer le type de spike selon le symbole
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);

   // Vérifier les signaux de spike depuis les zones SMC_OB
   double smcSpikePrice = 0.0;
   bool smcIsBuySpike = false;
   double smcConfidence = 0.0;
   
   // Détecter un spike basé sur les zones SMC_OB
   bool smcSpikeDetected = PredictSpikeFromSMCOB(smcSpikePrice, smcIsBuySpike, smcConfidence);
   
   // Si un spike est détecté avec une bonne confiance, l'utiliser
   if(smcSpikeDetected && smcConfidence >= 0.7)
   {
      isBoom = smcIsBuySpike;
      double spikePrice = smcSpikePrice;
      g_aiStrongSpike = true; // Marquer comme un spike fort
      g_aiSpikeZonePrice = spikePrice;
      g_aiSpikeDetectedTime = TimeCurrent();
      
      Print("🔍 Détection SMC_OB: Spike ", (isBoom ? "hausier" : "baissier"), 
            " détecté à ", DoubleToString(spikePrice, _Digits), 
            " - Confiance: ", DoubleToString(smcConfidence * 100, 1), "%");
   }
   
   // Si c'est un symbole Boom/Crash, vérifier les signaux de spike
   if((isBoom || isCrash) && g_aiStrongSpike)
   {
      // Déclarer les variables de prix une seule fois au début
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      // Cooldown anti-mitraillage: pas de nouvelle exécution si une tentative a eu lieu récemment,
      // sauf s'il n'y a AUCUNE position ouverte (on veut alors absolument saisir l'opportunité).
      if(g_lastSpikeBlockTime > 0 && (TimeCurrent() - g_lastSpikeBlockTime) < 120) // 2 minutes
      {
         if(CountAllPositionsForMagic() > 0)
            return;
      }
   
      bool isBuySpike = false;
   
      if(isBoom)
      {
         isBuySpike = true;
      }
      else if(isCrash)
      {
         isBuySpike = false;
      }
      // Règle stricte: BUY uniquement sur Boom, SELL uniquement sur Crash
      
      // Utiliser le prix de la zone de spike ou le prix actuel
      double spikePrice = (g_aiSpikeZonePrice > 0.0) ? g_aiSpikeZonePrice : 
                         ((isBuySpike) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID));
      
      // Créer ou mettre à jour la flèche clignotante sur le graphique
      string arrowName = "SPIKE_ARROW_" + _Symbol;
      
      if(ObjectFind(0, arrowName) < 0)
      {
         ObjectCreate(0, arrowName, OBJ_ARROW, 0, TimeCurrent(), spikePrice);
      }
      else
      {
         ObjectMove(0, arrowName, 0, TimeCurrent(), spikePrice);
      }
   
      // Propriétés de la flèche
      int arrowCode = isBuySpike ? 233 : 234; // Flèche vers le haut ou vers le bas
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, isBuySpike ? clrLime : clrRed);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   
      // Envoyer une notification + bip sonore UNIQUEMENT si le signal n'a pas encore été exécuté
      if(!g_aiSpikeExecuted && TimeCurrent() - g_lastSpikeAlertNotifTime > 30) // Cooldown de 30 secondes entre alertes du même signal
      {
         g_lastSpikeAlertNotifTime = TimeCurrent();
         string dirText = isBuySpike ? "BUY (spike haussier)" : "SELL (spike baissier)";
         string msg = StringFormat("ALERTE SPIKE %s\nSymbole: %s\nDirection: %s\nZone: %.5f\nAction: Surveillance en cours...",
                                   (isBuySpike ? "BOOM" : "CRASH"), _Symbol, dirText, spikePrice);
         SendNotification(msg);
         PlaySound("alert.wav");
      }

      // Définir l'heure d'entrée pré-spike (dernière bougie avant le mouvement)
      if(g_spikeEntryTime == 0)
         g_spikeEntryTime = TimeCurrent() + 30; // 30 secondes par défaut
   
      // Exécuter automatiquement le trade sur spike "fort" OU sur pré-alerte
      // pour agir plus tôt et ne pas manquer le mouvement
      if(!g_aiStrongSpike && !g_aiEarlySpikeWarning)
         return;

      // Mettre à jour le moment où le spike a été détecté
      g_aiSpikeDetectedTime = TimeCurrent();
      
      // Exécuter automatiquement le trade si pas encore fait,
      // UNIQUEMENT une seule position spike autorisée
      if(!g_aiSpikeExecuted && g_spikeEntryTime > 0 && TimeCurrent() >= g_spikeEntryTime)
      {
         // Vérifier qu'il n'y a pas déjà une position spike en cours
         if(CountPositionsForSymbolMagic() > 0)
         {
            if(DebugBlocks)
               Print("🚫 Spike ignoré: position déjà existante sur ", _Symbol);
            ClearSpikeSignal();
            return;
         }
         
         // Appliquer la logique Boom/Crash même pour les spikes
         ENUM_ORDER_TYPE spikeOrderType = isBuySpike ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         if(!CanTradeBoomCrashWithTrend(spikeOrderType))
         {
            if(DebugBlocks)
               Print("🚫 Spike ignoré: logique Boom/Crash avec tendance M1");
            ClearSpikeSignal();
            return;
         }
         
         // Récupérer les données nécessaires
         double atr[];
         if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
         {
            Print("❌ Impossible de récupérer l'ATR pour spike");
            return;
         }
         
         double price = isBuySpike ? ask : bid;
         ENUM_ORDER_TYPE orderType = isBuySpike ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         string comment = "SPIKE_" + (isBuySpike ? "BUY" : "SELL");

         // Conditions minimales (heure, drawdown, spread)
         if(!IsTradingTimeAllowed())
         {
            if(DebugBlocks) Print("🚫 Spike ignoré: hors heures de trading");
            ClearSpikeSignal();
            return;
         }
         if(IsDrawdownExceeded())
         {
            if(DebugBlocks) Print("🚫 Spike ignoré: drawdown dépassé");
            ClearSpikeSignal();
            return;
         }
         double spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * _Point;
         if(spread > MaxSpreadPoints * _Point)
         {
            if(DebugBlocks) Print("🚫 Spike ignoré: spread trop élevé (", DoubleToString(spread/_Point, 0), " points)");
            ClearSpikeSignal();
            return;
         }

         // Exiger l'accord de l'IA (direction + confiance) si disponible
         if(UseAI_Agent)
         {
            string act = g_lastAIAction;
            StringToUpper(act);
            bool aiAgree = false;
            if(isBuySpike && (act == "BUY" || act == "ACHAT"))
               aiAgree = true;
            if(!isBuySpike && (act == "SELL" || act == "VENTE"))
               aiAgree = true;
            if(!aiAgree || g_lastAIConfidence < AI_MinConfidence)
            {
               Print("🚫 Spike ignoré: IA pas d'accord ou confiance trop faible (", g_lastAIAction, " conf=", g_lastAIConfidence, ")");
               ClearSpikeSignal();
               return;
            }
         }

         // Exécuter directement la position spike (pas d'ordres pending pour éviter duplication)
         if(ExecuteTradeWithATR(orderType, atr[0], price, comment, 1.0, true))
         {
            g_aiSpikeExecuted = true;
            g_aiSpikeExecTime = TimeCurrent();
            
            if(DebugBlocks)
               Print("🚀 Position spike exécutée: ", EnumToString(orderType), " à ", DoubleToString(price, _Digits), " (UNIQUE)");
         }
         else
         {
            Print("❌ Échec exécution position spike");
            ClearSpikeSignal();
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Logique de trading Boom/Crash basée sur tendance M1               |
//+------------------------------------------------------------------+
bool CanTradeBoomCrashWithTrend(ENUM_ORDER_TYPE orderType)
{
   // Vérifier si c'est un symbole Boom/Crash
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(!isBoom && !isCrash)
      return true; // Pas Boom/Crash = autorisé
   
   // Récupérer l'analyse de tendance H1
   TrendAnalysis trendAnalysis = GetMultiTimeframeTrendAnalysis();
   
   if(!trendAnalysis.is_valid || trendAnalysis.h1_confidence < 60.0)
   {
      if(DebugBlocks)
         Print("⚠️ Tendance H1 non valide ou confiance < 60% (", trendAnalysis.h1_confidence, "%), autorisation par défaut");
      return true; // Autoriser si pas de tendance valide ou confiance insuffisante
   }
   
   // Normaliser la direction pour comparaison
   string trendDirection = trendAnalysis.h1_direction;
   StringToLower(trendDirection);
   
   bool isUptrend = (trendDirection == "buy" || trendDirection == "hausse");
   bool isDowntrend = (trendDirection == "sell" || trendDirection == "baisse");
   
   // LOGIQUE SPÉCIFIQUE BOOM/CRASH
   if(isUptrend)
   {
      // En uptrend H1:
      // - Éviter les BUY sur Crash (logique : Crash va contre la tendance haussière)
      // - Autoriser BUY sur Boom (logique : Boom suit la tendance haussière)
      // - HOLD si pas de BUY sur Boom déjà pris
      
      if(isCrash && orderType == ORDER_TYPE_BUY)
      {
         if(DebugBlocks)
            Print("🚫 UPTREND H1: BUY sur Crash refusé (contre-tendance)");
         return false;
      }
      
      if(isBoom && orderType == ORDER_TYPE_BUY)
      {
         // Vérifier si déjà une position BUY sur Boom
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            if(PositionGetTicket(i) > 0 && 
               PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               if(DebugBlocks)
                  Print("🚫 UPTREND H1: BUY sur Boom refusé (déjà en position BUY)");
               return false;
            }
         }
         
         if(DebugBlocks)
            Print("✅ UPTREND H1: BUY sur Boom autorisé (avec tendance)");
         return true;
      }
      
      // Pour les SELL en uptrend: autoriser mais avec prudence
      if(orderType == ORDER_TYPE_SELL)
      {
         if(DebugBlocks)
            Print("⚠️ UPTREND H1: SELL autorisé (contre-tendance avec prudence)");
         return true;
      }
      
      // Par défaut en uptrend: autoriser
      return true;
   }
   else if(isDowntrend)
   {
      // En downtrend H1:
      // - Privilégier les SELL sur Crash (logique : Crash suit la tendance baissière)
      // - Éviter BUY sur Boom (logique : Boom va contre la tendance baissière)
      
      if(isCrash && orderType == ORDER_TYPE_SELL)
      {
         if(DebugBlocks)
            Print("✅ DOWNTREND H1: SELL sur Crash privilégié (avec tendance)");
         return true;
      }
      
      if(isBoom && orderType == ORDER_TYPE_BUY)
      {
         if(DebugBlocks)
            Print("🚫 DOWNTREND H1: BUY sur Boom refusé (contre-tendance)");
         return false;
      }
      
      // Pour les autres cas en downtrend: autoriser avec prudence
      if(DebugBlocks)
         Print("⚠️ DOWNTREND H1: Trade autorisé (avec prudence)");
      return true;
   }
   else // Trend neutre ou indéterminé
   {
      if(DebugBlocks)
         Print("⚠️ TENDANCE H1 NEUTRE: Trade autorisé (sans préférence)");
      return true;
   }
   
   return true; // Par défaut, autoriser
}

//+------------------------------------------------------------------+
//| Fermeture automatique des positions spike après le mouvement     |
//| AMELIORE POUR BOOM/CRASH: attendre que le spike soit complet      |
//+------------------------------------------------------------------+
void CloseSpikePositionAfterMove()
{
   // Si pas de position spike exécutée, rien à faire
   if(!g_aiSpikeExecuted)
      return;
   
   // Vérifier s'il y a une position spike ouverte
   if(CountPositionsForSymbolMagic() == 0)
      return;
   
   bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   
   // Récupérer la position
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double currentPrice = posType == POSITION_TYPE_BUY ? 
                               SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                               SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double profit = PositionGetDouble(POSITION_PROFIT);
            
            // Calculer le mouvement depuis l'ouverture
            double priceMove = MathAbs(currentPrice - openPrice);
            double atr[];
            if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0)
               return;
            
            double atrValue = atr[0];
            double moveInAtr = priceMove / atrValue;
            
            // Pour Boom/Crash: vérifier si le spike est en cours ou terminé
            bool spikeStillActive = false;
            if(isBoomCrash)
            {
               // Vérifier la vitesse du mouvement (spike actif = mouvement rapide)
               static double g_lastSpikeCheckPrice = 0.0;
               static datetime g_lastSpikeCheckTime = 0;
               datetime now = TimeCurrent();
               
               if(g_lastSpikeCheckTime > 0 && (now - g_lastSpikeCheckTime) <= 2) // Vérifier toutes les 2 secondes
               {
                  double priceChange = MathAbs(currentPrice - g_lastSpikeCheckPrice);
                  double timeDiff = (double)(now - g_lastSpikeCheckTime);
                  double speed = (timeDiff > 0) ? (priceChange / timeDiff) : 0.0;
                  
                  // Si vitesse > 0.5 points/seconde, le spike est encore actif
                  if(speed > 0.5)
                     spikeStillActive = true;
               }
               
               g_lastSpikeCheckPrice = currentPrice;
               g_lastSpikeCheckTime = now;
            }
            
            // Fermer si :
            // Pour Boom/Crash:
            // 1. Profit >= BoomCrashProfitCut (0.30$ par défaut) ET spike terminé (pas de mouvement rapide)
            // 2. Mouvement > 4 ATR (spike terminé, plus conservateur que 3 ATR)
            // 3. Perte > 1$ (stop de sécurité)
            // 4. Temps écoulé > 3 minutes ET profit > 0 (timeout avec profit)
            // Pour autres symboles:
            // 1. Profit > 2$ (objectif atteint)
            // 2. Mouvement > 3 ATR (spike terminé)
            // 3. Perte > 1$ (stop de sécurité)
            // 4. Temps écoulé > 5 minutes (timeout)
            bool shouldClose = false;
            string closeReason = "";
            
            if(isBoomCrash)
            {
               // Boom/Crash: stratégie plus conservatrice - attendre que le spike soit complet
               if(profit >= BoomCrashProfitCut && !spikeStillActive && moveInAtr >= 2.0)
               {
                  shouldClose = true;
                  closeReason = StringFormat("Profit %.2f$ atteint - Spike terminé", BoomCrashProfitCut);
               }
               else if(moveInAtr >= 4.0 && !spikeStillActive) // Attendre 4 ATR et vérifier que le spike est terminé
               {
                  shouldClose = true;
                  closeReason = "Mouvement spike terminé (>4 ATR, vitesse ralentie)";
               }
               else if(profit <= -1.0)
               {
                  shouldClose = true;
                  closeReason = "Stop de sécurité (-1$)";
               }
               else if(TimeCurrent() - g_aiSpikeExecTime > 180 && profit > 0) // 3 minutes avec profit
               {
                  shouldClose = true;
                  closeReason = "Timeout 3 minutes avec profit";
               }
            }
            else
            {
               // Autres symboles: logique originale
               if(profit >= 2.0)
               {
                  shouldClose = true;
                  closeReason = "Profit cible 2$ atteint";
               }
               else if(moveInAtr >= 3.0)
               {
                  shouldClose = true;
                  closeReason = "Mouvement spike terminé (>3 ATR)";
               }
               else if(profit <= -1.0)
               {
                  shouldClose = true;
                  closeReason = "Stop de sécurité (-1$)";
               }
               else if(TimeCurrent() - g_aiSpikeExecTime > 300) // 5 minutes
               {
                  shouldClose = true;
                  closeReason = "Timeout 5 minutes";
               }
            }
            
            if(shouldClose)
            {
               if(trade.PositionClose(ticket))
               {
                  Print("🎯 Position spike fermée: ", closeReason, 
                        " (Profit: ", DoubleToString(profit, 2), "$, Mouvement: ", DoubleToString(moveInAtr, 1), " ATR)");
                  
                  // Notification de fermeture
                  string closeMsg = StringFormat("🎯 SPIKE FERMÉ 🎯\n%s %s\nRaison: %s\nProfit: %.2f$\nMouvement: %.1f ATR",
                                                  (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                                                  _Symbol, closeReason, profit, moveInAtr);
                  SendNotification(closeMsg);
                  
                  // Réinitialiser l'état spike
                  ClearSpikeSignal();
               }
               else
               {
                  Print("❌ Échec fermeture position spike: ", trade.ResultRetcode());
               }
            }
            
            break; // Une seule position spike à la fois
         }
      }
   }
}


//+------------------------------------------------------------------+
//| Vérifie si un trade spike est en cours et gère sa clôture        |
//+------------------------------------------------------------------+
bool IsInSMCOBZone(double price, double &zoneStrength, bool &isBuyZone, double &zoneWidth)
{
   for(int i = 0; i < g_smcZonesCount; i++)
   {
      if(!g_smcZones[i].isActive) continue;
      
      double zoneHigh = g_smcZones[i].price * (1 + g_smcZones[i].width);
      double zoneLow = g_smcZones[i].price * (1 - g_smcZones[i].width);
      
      if(price >= zoneLow && price <= zoneHigh)
      {
         zoneStrength = g_smcZones[i].strength;
         isBuyZone = g_smcZones[i].isBuyZone;
         zoneWidth = g_smcZones[i].width;
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Détecte et met à jour les zones SMC_OB                           |
//+------------------------------------------------------------------+
void UpdateSMCOBZones()
{
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 60) // Mettre à jour toutes les minutes
      return;
      
   lastUpdate = TimeCurrent();
   
   // Réinitialiser le compteur de zones
   g_smcZonesCount = 0;
   
   // Obtenir les données des bougies
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, SMC_OB_Lookback, rates);
   if(copied <= 0) return;
   
   // Détecter les zones SMC_OB (Order Blocks)
   for(int i = SMC_OB_MinCandles; i < copied - SMC_OB_MinCandles; i++)
   {
      // Vérifier si c'est un bloc d'achat (bearish candle suivie de bougies haussières)
      if(rates[i].close < rates[i].open) // Bearish candle
      {
         bool isBuyZone = true;
         for(int j = 1; j <= SMC_OB_MinCandles; j++)
         {
            if(rates[i+j].close <= rates[i].close)
            {
               isBuyZone = false;
               break;
            }
         }
         
         if(isBuyZone && g_smcZonesCount < ArraySize(g_smcZones))
         {
            g_smcZones[g_smcZonesCount].price = rates[i].close;
            g_smcZones[g_smcZonesCount].isBuyZone = true;
            g_smcZones[g_smcZonesCount].time = rates[i].time;
            g_smcZones[g_smcZonesCount].strength = 0.7; // Force moyenne par défaut
            g_smcZones[g_smcZonesCount].width = SMC_OB_ZoneWidth;
            g_smcZones[g_smcZonesCount].isActive = true;
            g_smcZonesCount++;
            continue;
         }
      }
      
      // Vérifier si c'est un bloc de vente (bullish candle suivie de bougies baissières)
      if(rates[i].close > rates[i].open) // Bullish candle
      {
         bool isSellZone = true;
         for(int j = 1; j <= SMC_OB_MinCandles; j++)
         {
            if(rates[i+j].close >= rates[i].close)
            {
               isSellZone = false;
               break;
            }
         }
         
         if(isSellZone && g_smcZonesCount < ArraySize(g_smcZones))
         {
            g_smcZones[g_smcZonesCount].price = rates[i].close;
            g_smcZones[g_smcZonesCount].isBuyZone = false;
            g_smcZones[g_smcZonesCount].time = rates[i].time;
            g_smcZones[g_smcZonesCount].strength = 0.7; // Force moyenne par défaut
            g_smcZones[g_smcZonesCount].width = SMC_OB_ZoneWidth;
            g_smcZones[g_smcZonesCount].isActive = true;
            g_smcZonesCount++;
         }
      }
   }
   
   // Désactiver les zones trop anciennes
   int currentBar = iBars(_Symbol, PERIOD_CURRENT);
   for(int i = 0; i < g_smcZonesCount; i++)
   {
      int zoneBar = iBarShift(_Symbol, PERIOD_CURRENT, g_smcZones[i].time);
      if(currentBar - zoneBar > SMC_OB_ExpiryBars)
      {
         g_smcZones[i].isActive = false;
      }
   }
}

//+------------------------------------------------------------------+
//| STRATÉGIE SPIKE ZONE - Retournement ou Cassure                   |
//| 1. Prix entre dans zone → Attendre                                |
//| 2. Prix se retourne → Trade retournement                          |
//| 3. Prix casse la zone → Trade continuation                        |
//+------------------------------------------------------------------+
// Variables statiques pour tracker l'état de la zone
static bool g_priceWasInZone = false;
static double g_zoneEntryPrice = 0;
static double g_zoneHigh = 0;
static double g_zoneLow = 0;
static bool g_zoneIsBuy = false;
static datetime g_zoneEntryTime = 0;

bool PredictSpikeFromSMCOB(double &spikePrice, bool &isBuySpike, double &confidence)
{
   if(!SMC_OB_UseForSpikes) return false;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double zoneStrength = 0.0;
   bool isBuyZone = false;
   double zoneWidth = 0.0;
   
   // Récupérer les derniers prix pour détecter le mouvement
   double close1 = iClose(_Symbol, PERIOD_M1, 1);
   double close2 = iClose(_Symbol, PERIOD_M1, 2);
   double close3 = iClose(_Symbol, PERIOD_M1, 3);
   
   // Vérifier si le prix est dans une zone SMC_OB
   bool isInZone = IsInSMCOBZone(currentPrice, zoneStrength, isBuyZone, zoneWidth);
   
   if(isInZone)
   {
      // Calculer les bornes de la zone
      double zoneCenter = 0;
      for(int i = 0; i < g_smcZonesCount; i++)
      {
         if(!g_smcZones[i].isActive) continue;
         double zHigh = g_smcZones[i].price * (1 + g_smcZones[i].width);
         double zLow = g_smcZones[i].price * (1 - g_smcZones[i].width);
         if(currentPrice >= zLow && currentPrice <= zHigh)
         {
            g_zoneHigh = zHigh;
            g_zoneLow = zLow;
            g_zoneIsBuy = g_smcZones[i].isBuyZone;
            zoneCenter = g_smcZones[i].price;
            break;
         }
      }
      
      // Prix vient d'entrer dans la zone
      if(!g_priceWasInZone)
      {
         g_priceWasInZone = true;
         g_zoneEntryPrice = currentPrice;
         g_zoneEntryTime = TimeCurrent();
         Print("📍 Prix entré dans zone ", (g_zoneIsBuy ? "ACHAT" : "VENTE"), " - Attente retournement ou cassure...");
         
         // Afficher flèche clignotante d'alerte
         g_aiSpikePredicted = true;
         g_aiSpikeDirection = g_zoneIsBuy;
         g_aiSpikeZonePrice = zoneCenter;
         return false; // Attendre confirmation
      }
      
      // Prix dans la zone - Détecter RETOURNEMENT
      bool priceReversingUp = (close1 > close2 && close2 > close3 && currentPrice > close1);
      bool priceReversingDown = (close1 < close2 && close2 < close3 && currentPrice < close1);
      
      // RETOURNEMENT dans zone ACHAT (verte) → BUY
      if(g_zoneIsBuy && priceReversingUp)
      {
         spikePrice = g_zoneHigh + (g_zoneHigh - g_zoneLow); // Cible au-dessus
         isBuySpike = true;
         confidence = zoneStrength * 0.95;
         Print("🔄 RETOURNEMENT HAUSSIER détecté dans zone ACHAT!");
         g_priceWasInZone = false; // Reset
         return true;
      }
      
      // RETOURNEMENT dans zone VENTE (rouge) → SELL
      if(!g_zoneIsBuy && priceReversingDown)
      {
         spikePrice = g_zoneLow - (g_zoneHigh - g_zoneLow); // Cible en dessous
         isBuySpike = false;
         confidence = zoneStrength * 0.95;
         Print("🔄 RETOURNEMENT BAISSIER détecté dans zone VENTE!");
         g_priceWasInZone = false; // Reset
         return true;
      }
   }
   else
   {
      // Prix HORS de la zone
      if(g_priceWasInZone && g_zoneEntryTime > 0)
      {
         // Vérifier si CASSURE de la zone (prix a traversé)
         
         // CASSURE HAUSSIÈRE (prix sort par le haut de la zone)
         if(currentPrice > g_zoneHigh && close1 > g_zoneHigh)
         {
            spikePrice = currentPrice + (g_zoneHigh - g_zoneLow) * 2; // Continuation haussière
            isBuySpike = true;
            confidence = 0.85;
            Print("💥 CASSURE HAUSSIÈRE! Prix a traversé la zone vers le haut - BUY continuation!");
            g_priceWasInZone = false;
            g_zoneEntryTime = 0;
            return true;
         }
         
         // CASSURE BAISSIÈRE (prix sort par le bas de la zone)
         if(currentPrice < g_zoneLow && close1 < g_zoneLow)
         {
            spikePrice = currentPrice - (g_zoneHigh - g_zoneLow) * 2; // Continuation baissière
            isBuySpike = false;
            confidence = 0.85;
            Print("💥 CASSURE BAISSIÈRE! Prix a traversé la zone vers le bas - SELL continuation!");
            g_priceWasInZone = false;
            g_zoneEntryTime = 0;
            return true;
         }
         
         // Timeout - prix sorti sans signal clair (reset après 5 min)
         if(TimeCurrent() - g_zoneEntryTime > 300)
         {
            g_priceWasInZone = false;
            g_zoneEntryTime = 0;
            g_aiSpikePredicted = false;
         }
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Affiche les zones SMC_OB sur le graphique                        |
//+------------------------------------------------------------------+
void DrawSMCOBZones()
{
   static datetime lastDraw = 0;
   if(TimeCurrent() - lastDraw < 10) // Mettre à jour toutes les 10 secondes
      return;
      
   lastDraw = TimeCurrent();
   
   // Supprimer les anciens objets
   for(int i = 0; i < g_smcZonesCount; i++)
   {
      string objName = "SMC_OB_" + IntegerToString(i);
      ObjectDelete(0, objName);
   }
   
   // Afficher les zones actives
   for(int i = 0; i < g_smcZonesCount; i++)
   {
      if(!g_smcZones[i].isActive) continue;
      
      string objName = "SMC_OB_" + IntegerToString(i);
      color zoneColor = g_smcZones[i].isBuyZone ? clrLime : clrRed;
      
      double zoneHigh = g_smcZones[i].price * (1 + g_smcZones[i].width);
      double zoneLow = g_smcZones[i].price * (1 - g_smcZones[i].width);
      
      // Créer un rectangle pour la zone
      if(!ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 0, 0, 0, 0))
         continue;
         
      // Définir les propriétés du rectangle avec les bonnes énumérations
      datetime time1 = TimeCurrent() - 3600*24*30; // Début (il y a 30 jours)
      datetime time2 = TimeCurrent() + 3600*24;    // Fin (dans 1 jour)
      
      // Définir les points du rectangle avec ObjectCreate
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time1, zoneHigh, time2, zoneLow);
      
      // Définir les propriétés du rectangle
      ObjectSetInteger(0, objName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_ZORDER, 0);
   }
   
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Ferme immédiatement les positions Boom/Crash en profit (même minimal)|
//+------------------------------------------------------------------+
void CloseBoomCrashPositionsOnSpike()
{
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   // Uniquement pour Boom/Crash
   if(!isBoom && !isCrash) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            double profit = PositionGetDouble(POSITION_PROFIT);
         
         // Fermer si profit >= 0.01$ (même minimal)
         if(profit >= 0.01)
         {
            if(trade.PositionClose(ticket))
            {
               Print("Position Boom/Crash fermée sur spike - Profit: $", DoubleToString(profit, 2), " - Ticket: ", ticket);
               SendNotification(StringFormat("CLOSE SPIKE %s - Profit: $%.2f", _Symbol, profit));
            }
            else
            {
               Print("Erreur fermeture position spike: ", GetLastError());
            }
         }
         // Fermer aussi si perte > 0.50$ pour limiter les dégâts
         else if(profit <= -0.50)
         {
            if(trade.PositionClose(ticket))
            {
               Print("Position Boom/Crash fermée (perte limitée) - Perte: $", DoubleToString(profit, 2), " - Ticket: ", ticket);
            }
         }
      }
   }
}

}

//+------------------------------------------------------------------+
//| Met à jour l'affichage clignotant de la flèche et détecte le spike|
//+------------------------------------------------------------------+
void UpdateSpikeAlertDisplay()
{
   // Tant qu'un trade spike est en cours d'exécution, on laisse la logique
   // de détection/fermeture fonctionner même si g_aiSpikePredicted passe à false.
   if(!g_aiSpikePredicted && !g_aiSpikeExecuted)
   {
      // Supprimer la flèche si plus de prédiction
      string arrowName = "SPIKE_ARROW_" + _Symbol;
      ObjectDelete(0, arrowName);
      return;
   }
   
   // Vérifier si le spike a été détecté (mouvement rapide vers la zone)
   if(g_aiSpikeExecuted && CountPositionsForSymbolMagic() > 0)
   {
      // Fermer immédiatement les positions Boom/Crash en profit (même minimal)
      CloseBoomCrashPositionsOnSpike();
      
      double currentPrice = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) + SymbolInfoDouble(_Symbol, SYMBOL_BID)) / 2.0;
      double spikeZonePrice = (g_aiSpikeZonePrice > 0.0) ? g_aiSpikeZonePrice : currentPrice;
      
      // Détecter si le prix a atteint la zone de spike (dans un rayon de 0.1% du prix)
      double priceDiff = MathAbs(currentPrice - spikeZonePrice);
      double tolerance = currentPrice * 0.001; // 0.1% de tolérance
      
      bool isBoom = (StringFind(_Symbol, "Boom") != -1);
      bool isCrash = (StringFind(_Symbol, "Crash") != -1);
      bool isBuySpike = (isBoom || (!isCrash && g_aiSpikeDirection));
      bool isBoom300 = (StringFind(_Symbol, "Boom 300") != -1);
      
      bool spikeDetected = false;

      // Cas spécial Boom 300 : clôture immédiate dès le premier spike exécuté,
      // sans attendre que le prix atteigne une zone théorique.
      if(isBoom300)
      {
         spikeDetected = true;
      }
      else
      {
         // Pour BUY: prix doit monter vers la zone
         // Pour SELL: prix doit descendre vers la zone
         if(isBuySpike && currentPrice >= spikeZonePrice - tolerance)
            spikeDetected = true;
         else if(!isBuySpike && currentPrice <= spikeZonePrice + tolerance)
            spikeDetected = true;
      }
      
      // Pour Boom/Crash : vérifier si le profit cible est atteint avant de fermer
      if(spikeDetected && (isBoom || isCrash))
      {
         bool shouldClose = false;
         
         // Vérifier si nous avons une position ouverte
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               double profit = PositionGetDouble(POSITION_PROFIT);
               double volume = PositionGetDouble(POSITION_VOLUME);
               double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
               double pointsProfit = MathAbs(currentPrice - openPrice) / _Point;
               
               // Pour Boom/Crash : fermer dès que le spike est détecté, même avec gain minimal
               // Accepter les gains dès 0.01$ pour sécuriser rapidement
               if(profit >= 0.01 || profit <= -0.5)  // Fermer avec 0.01$ de profit ou 0.50$ de perte
               {
                  shouldClose = true;
                  Print("Spike détecté sur ", _Symbol, " - Fermeture avec profit: $", DoubleToString(profit, 2));
                  break;
               }
               
               // Ou si la position est ouverte depuis plus de 2 minutes (réduit de 5 à 2)
               if(TimeCurrent() - PositionGetInteger(POSITION_TIME) > 120)
               {
                  shouldClose = true;
                  Print("Spike - Fermeture après timeout (2 minutes) sur ", _Symbol);
                  break;
               }
            }
         }
         
         if(shouldClose)
         {
            // Récupérer le profit final pour le message
            double finalProfit = 0;
            for(int i = PositionsTotal() - 1; i >= 0; i--)
            {
               if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
               {
                  finalProfit = PositionGetDouble(POSITION_PROFIT);
                  break;
               }
            }
            
            CloseAllPositionsForSymbolMagic();
            string msgEnd = StringFormat("SPIKE EXECUTE sur %s - Position clôturée avec profit: $%.2f", _Symbol, finalProfit);
            SendNotification(msgEnd);
            
            // Arrêter la flèche et le clignotement
            string arrowEnd = "SPIKE_ARROW_" + _Symbol;
            ObjectDelete(0, arrowEnd);
            g_aiSpikePredicted = false;
         }
         g_aiStrongSpike = false;
         g_aiSpikeExecuted = false;
         g_aiSpikePendingPlaced = false;
         return;
      }
   }
   
   // Ne pas garder un signal spike trop longtemps : après 20 secondes,
   // on le considère comme expiré (sinon risque de trade très en retard).
   if(TimeCurrent() - g_aiSpikeDetectedTime > 20)
   {
      ClearSpikeSignal();
      return;
   }
   
   // Mettre à jour le label de compte à rebours (affiché en gros sur le graphique) - TOUJOURS ACTIF
   string labelName = "SPIKE_COUNTDOWN_" + _Symbol;
   if(g_spikeEntryTime > 0 && g_aiSpikePredicted)
   {
      int remaining = (int)(g_spikeEntryTime - TimeCurrent());
      if(remaining < 0) remaining = 0;

      // Calculer les dimensions du graphique
      int chartWidth  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
      int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
      
      // Créer ou mettre à jour un label centré au milieu du graphique
      if(ObjectFind(0, labelName) < 0)
      {
         if(!ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0))
         {
            Print("❌ Erreur création label countdown: ", GetLastError());
         }
         else
         {
            // Configuration initiale du label
            ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_CENTER);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 48); // Taille plus grande pour visibilité
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Black");
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
            ObjectSetInteger(0, labelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
         }
      }

      // Mettre à jour le label à chaque appel (position et texte)
      if(ObjectFind(0, labelName) >= 0)
      {
         // Recalculer les dimensions au cas où la fenêtre a été redimensionnée
         chartWidth  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
         chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
         
         // Positionner au centre du graphique
         ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, chartWidth / 2);
         ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, chartHeight / 2);

         // Mettre à jour le texte
         string txt = "SPIKE dans: " + IntegerToString(remaining) + "s";
         ObjectSetString(0, labelName, OBJPROP_TEXT, txt);
         
         // Forcer la visibilité
         ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
      }
      else if(remaining > 0)
      {
         // Si le label n'existe pas mais qu'il devrait, essayer de le recréer
         Print("⚠️ Label countdown introuvable mais spike actif. Tentative de recréation...");
      }
   }
   else
   {
      // Si pas de spike prévu, supprimer le label
      if(ObjectFind(0, labelName) >= 0)
         ObjectDelete(0, labelName);
   }
   
   // Faire clignoter la flèche (changement de visibilité toutes les 1 secondes)
   static datetime lastBlinkTime = 0;
   static bool blinkState = false;

   // Utiliser 1 seconde (TimeCurrent retourne un entier), évite comparaison flottante incorrecte
   if(TimeCurrent() - lastBlinkTime >= 1)
   {
      blinkState = !blinkState;
      lastBlinkTime = TimeCurrent();

      string arrowName = "SPIKE_ARROW_" + _Symbol;
      if(ObjectFind(0, arrowName) >= 0)
      {
         bool isBoom = (StringFind(_Symbol, "Boom") != -1);
         bool isCrash = (StringFind(_Symbol, "Crash") != -1);
         bool isBuySpike = (isBoom || (!isCrash && g_aiSpikeDirection));

         // Toujours afficher la flèche en couleur vive pendant les 20 secondes
         color arrowColor = isBuySpike ? clrLime : clrRed;

         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
      }
   }
   
   // Forcer le rafraîchissement du graphique pour voir le label et la flèche
   ChartRedraw(0);
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calcule un SL dynamique basé sur la volatilité                    |
//+------------------------------------------------------------------+
double CalculateDynamicSL(ENUM_ORDER_TYPE orderType, double atr, double price, double volatilityRatio)
{
   double stopLoss = 0;
   double multiplier = 1.0;
   
   // Ajustement du multiplicateur selon la volatilité
   if(volatilityRatio > Volatility_Threshold)
      multiplier = Volatility_High_Mult;
   else
      multiplier = Volatility_Low_Mult;
   
   // Calcul du SL selon le type d'ordre
   if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP)
   {
      stopLoss = price - (atr * multiplier * SL_ATR_Mult);
      // S'assurer que le SL est à une distance minimale
      double minStop = price - (atr * 0.5); // 0.5 ATR de marge
      stopLoss = MathMin(stopLoss, minStop);
   }
   else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP)
   {
      stopLoss = price + (atr * multiplier * SL_ATR_Mult);
      double minStop = price + (atr * 0.5);
      stopLoss = MathMax(stopLoss, minStop);
   }
   
   return NormalizeDouble(stopLoss, _Digits);
}
 
//+------------------------------------------------------------------+
//| Calcule un TP dynamique basé sur la volatilité                    |
//+------------------------------------------------------------------+
double CalculateDynamicTP(ENUM_ORDER_TYPE orderType, double atr, double price, double volatilityRatio)
{
   double takeProfit = 0;
   double rewardRatio = 2.0; // Ratio risque/récompense par défaut
   
   // Ajustement du ratio selon la volatilité
   if(volatilityRatio > Volatility_Threshold)
      rewardRatio = 3.0; // Objectif plus élevé en cas de forte volatilité
   
   if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP)
      takeProfit = price + (atr * TP_ATR_Mult * rewardRatio);
   else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL_STOP)
      takeProfit = price - (atr * TP_ATR_Mult * rewardRatio);
   
   return NormalizeDouble(takeProfit, _Digits);
}

//+------------------------------------------------------------------+
//| Applique un trailing stop intelligent                            |
//+------------------------------------------------------------------+
void ApplyTrailingStop(ulong ticket, double currentATR, double volatilityRatio)
{
   if(!UseTrailing || !PositionSelectByTicket(ticket)) 
      return;
   
   double trailingStep = currentATR * Trail_ATR_Mult;
   double volatilityMultiplier = 1.0 + (volatilityRatio * 0.5); // Ajustement selon la volatilité
   trailingStep *= volatilityMultiplier;
   
   double currentStop = PositionGetDouble(POSITION_SL);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double newStop = 0;
   bool modify = false;
   
   if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
   {
      double activationLevel = openPrice + (currentATR * Trail_Activation_ATR);
      if(currentPrice > activationLevel)
      {
         newStop = currentPrice - trailingStep;
         if(newStop > currentStop && newStop > openPrice)
            modify = true;
      }
   }
   else // SELL
   {
      double activationLevel = openPrice - (currentATR * Trail_Activation_ATR);
      if(currentPrice < activationLevel)
      {
         newStop = currentPrice + trailingStep;
         if((newStop < currentStop || currentStop == 0) && newStop < openPrice)
            modify = true;
      }
   }
   
   // Validation du nouveau stop loss avant modification
   if(modify)
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double stopLevel = 0, freezeLevel = 0;
      stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      freezeLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double spread = ask - bid;
      
      // Vérifier que le nouveau stop est valide
      bool isValidStop = true;
      string invalidReason = "";
      
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
      {
         double minStopDistance = MathMax(stopLevel, spread) + (10 * point); // Marge de sécurité
         if(bid - newStop < minStopDistance)
         {
            isValidStop = false;
            invalidReason = "Stop trop proche du prix (distance: " + DoubleToString(bid - newStop, _Digits) + " < min: " + DoubleToString(minStopDistance, _Digits) + ")";
         }
      }
      else // SELL
      {
         double minStopDistance = MathMax(stopLevel, spread) + (10 * point); // Marge de sécurité
         if(newStop - ask < minStopDistance)
         {
            isValidStop = false;
            invalidReason = "Stop trop proche du prix (distance: " + DoubleToString(newStop - ask, _Digits) + " < min: " + DoubleToString(minStopDistance, _Digits) + ")";
         }
      }
      
      // Vérifier que le stop n'est pas dans la zone de freeze
      if(freezeLevel > 0)
      {
         double distanceToFreeze = MathAbs(currentPrice - newStop);
         if(distanceToFreeze <= freezeLevel)
         {
            isValidStop = false;
            invalidReason = "Stop dans la zone de freeze (distance: " + DoubleToString(distanceToFreeze, _Digits) + " <= freeze: " + DoubleToString(freezeLevel, _Digits) + ")";
         }
      }
      
      // Appliquer le stop seulement si valide
      if(isValidStop)
      {
         if(trade.PositionModify(ticket, newStop, PositionGetDouble(POSITION_TP)))
         {
            if(DebugBlocks)
               Print("✅ Trailing stop ajusté pour ticket ", ticket, " - Nouveau SL: ", DoubleToString(newStop, _Digits));
         }
         else
         {
            Print("❌ Échec modification trailing stop: ", trade.ResultRetcodeDescription(), " (code: ", trade.ResultRetcode(), ")");
         }
      }
      else
      {
         if(DebugBlocks)
            Print("⚠️ Trailing stop ignoré - ", invalidReason);
      }
   }
}

//+------------------------------------------------------------------+
//| Gestion de la prise de profit partielle                          |
//+------------------------------------------------------------------+
void ApplyPartialProfitTaking(ulong ticket, double currentProfit)
{
   if(!PositionSelectByTicket(ticket) || currentProfit <= 0) 
      return;
   
   double lotSize = PositionGetDouble(POSITION_VOLUME);
   double currentTP = PositionGetDouble(POSITION_TP);
   double currentSL = PositionGetDouble(POSITION_SL);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double profitInPips = MathAbs(currentPrice - openPrice) / _Point;
   bool isBuy = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   
   // Vérifier si une prise de profit partielle est justifiée
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(profitInPips > TakeProfit1_Pips && lotSize > minLot * 2)
   {
      double closeVolume = NormalizeDouble(lotSize * PartialClose1_Percent / 100.0, 2);
      if(closeVolume >= minLot)
      {
         trade.PositionClosePartial(ticket, closeVolume);
         Print("Prise de profit partielle effectuée pour le ticket ", ticket, 
               " - Volume fermé: ", closeVolume, " lots");
               
         // Ajuster le stop loss au point d'entrée pour le reste de la position
         if(UseBreakEven)
         {
            double newSL = openPrice;
            if(!isBuy) 
               newSL += 10 * _Point; // Ajustement pour éviter le spread
            trade.PositionModify(ticket, newSL, currentTP);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Fonction utilitaire pour récupérer le cours de clôture           |
//+------------------------------------------------------------------+
double Close(int shift)
{
   double close[];
   ArraySetAsSeries(close, true);
   CopyClose(_Symbol, PERIOD_CURRENT, shift, 1, close);
   return close[0];
}

//+------------------------------------------------------------------+
//| Calcule le ratio de volatilité actuel                            |
//+------------------------------------------------------------------+
double GetVolatilityRatio(double atr, double price = 0)
{
   if(price == 0) 
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
   // Calculer la variation moyenne du prix sur les dernières 14 périodes
   double sum = 0;
   int period = 14;
   for(int i = 1; i <= period; i++)
   {
      sum += MathAbs(Close(i) - Close(i+1)) / _Point;
   }
   double averageRange = sum / period;
   
   // Calculer le ratio de volatilité (ATR / Fourchette moyenne)
   double volatilityRatio = atr / (averageRange * _Point);
   
   return NormalizeDouble(volatilityRatio, 2);
}

//+------------------------------------------------------------------+
//| Initialise l'état dynamique d'une position                      |
//+------------------------------------------------------------------+
void InitializeDynamicPositionState(ulong ticket, double sl, double tp, double atr)
{
   // Rechercher si l'état existe déjà
   for(int i = 0; i < ArraySize(g_dynamicPosStates); i++)
   {
      if(g_dynamicPosStates[i].ticket == ticket)
      {
         // Mettre à jour l'état existant
         g_dynamicPosStates[i].initialSL = sl;
         g_dynamicPosStates[i].initialTP = tp;
         g_dynamicPosStates[i].atrAtOpen = atr;
         g_dynamicPosStates[i].lastAdjustmentTime = TimeCurrent();
         return;
      }
   }
   
   // Créer un nouvel état
   DynamicPositionState newState;
   newState.ticket = ticket;
   newState.initialSL = sl;
   newState.initialTP = tp;
   newState.atrAtOpen = atr;
   newState.lastAdjustmentTime = TimeCurrent();
   newState.highestProfit = 0;
   newState.trendConfirmed = false;
   newState.trailingActive = false;
   newState.partialClose1Done = 0;
   newState.partialClose2Done = 0;
   
   // Ajouter au tableau
   ArrayResize(g_dynamicPosStates, ArraySize(g_dynamicPosStates) + 1);
   g_dynamicPosStates[ArraySize(g_dynamicPosStates) - 1] = newState;
}

//+------------------------------------------------------------------+
//| Récupère l'état dynamique d'une position                        |
//+------------------------------------------------------------------+
DynamicPositionState GetDynamicPositionState(ulong ticket)
{
   DynamicPositionState emptyState = {0};
   
   for(int i = 0; i < ArraySize(g_dynamicPosStates); i++)
   {
      if(g_dynamicPosStates[i].ticket == ticket)
      {
         return g_dynamicPosStates[i];
      }
   }
   
   return emptyState; // Retourne un état vide si non trouvé
}

// === BASIC EMA + ZONE SIGNALS =====================================
//  - Uses EMA 9/21 on M1 and AI buy/sell zones
//  - Draws blue/red prediction arrows and can auto-execute via existing ExecuteTrade()
//  - Arrows blink and auto-remove after 60 seconds
// ------------------------------------------------------------------
void DrawBasicPredictionArrow(bool isBuy, double price, string reason)
{
   static int counter = 0;
   counter++;
   bool visible = (counter / 5) % 2 == 0; // Fait clignoter toutes les 5 itérations
   
   string name = "BASIC_PRED_"+TimeToString(TimeCurrent(), TIME_SECONDS)+"_"+IntegerToString(MathRand());
   int code = isBuy ? 233 : 234;        // Up / Down arrow Wingdings
   color clr = isBuy ? clrBlue : clrRed;
   
   if(ObjectCreate(0, name, OBJ_ARROW, 0, TimeCurrent(), price))
   {
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, reason);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS); // Ne pas afficher sur d'autres timeframes
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   
   // Supprimer les anciennes flèches
   datetime oldestTime = TimeCurrent() - 60; // Garder les flèches pendant 60 secondes
   ObjectsDeleteAll(0, "BASIC_PRED_", 0, OBJ_ARROW);
}

void CheckBasicEmaSignals()
{
   // Cool-down between signals
   if(TimeCurrent() - g_lastBasicSignalTime < BASIC_SIGNAL_COOLDOWN_SEC)
      return;
   if(emaFastQuickHandle == INVALID_HANDLE || emaSlowQuickHandle == INVALID_HANDLE)
      return;

   double fastBuf[1], slowBuf[1];
   if(CopyBuffer(emaFastQuickHandle, 0, 0, 1, fastBuf) <= 0) return;
   if(CopyBuffer(emaSlowQuickHandle, 0, 0, 1, slowBuf) <= 0) return;

   double fast = fastBuf[0];
   double slow = slowBuf[0];
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0 || bid <= 0) return;

   // Vérifier si le symbole est un Boom ou un Crash
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   bool isStepIndex = (StringFind(_Symbol, "Step Index") != -1);

   // POUR STEP INDEX ET BOOM: Validation stricte de la tendance M15 et H1 AVANT tout
   if(isStepIndex || isBoom)
   {
      // Vérifier H1
      double emaFastH1[], emaSlowH1[];
      bool h1Valid = false;
      bool h1TrendUp = false;
      bool h1TrendDown = false;
      
      if(h1_ema_fast_handle != INVALID_HANDLE && h1_ema_slow_handle != INVALID_HANDLE)
      {
         if(CopyBuffer(h1_ema_fast_handle, 0, 0, 3, emaFastH1) >= 3 &&
            CopyBuffer(h1_ema_slow_handle, 0, 0, 3, emaSlowH1) >= 3)
         {
            h1TrendUp   = emaFastH1[0] > emaSlowH1[0] && emaFastH1[1] > emaSlowH1[1] && emaFastH1[2] > emaSlowH1[2];
            h1TrendDown = emaFastH1[0] < emaSlowH1[0] && emaFastH1[1] < emaSlowH1[1] && emaFastH1[2] < emaSlowH1[2];
            h1Valid = (h1TrendUp || h1TrendDown);
         }
      }
      
      // Vérifier M15
      double emaFastM15[], emaSlowM15[];
      bool m15Valid = false;
      bool m15TrendUp = false;
      bool m15TrendDown = false;
      
      if(emaFastM15Handle != INVALID_HANDLE && emaSlowM15Handle != INVALID_HANDLE)
      {
         if(CopyBuffer(emaFastM15Handle, 0, 0, 3, emaFastM15) >= 3 &&
            CopyBuffer(emaSlowM15Handle, 0, 0, 3, emaSlowM15) >= 3)
         {
            m15TrendUp   = emaFastM15[0] > emaSlowM15[0] && emaFastM15[1] > emaSlowM15[1] && emaFastM15[2] > emaSlowM15[2];
            m15TrendDown = emaFastM15[0] < emaSlowM15[0] && emaFastM15[1] < emaSlowM15[1] && emaFastM15[2] < emaSlowM15[2];
            m15Valid = (m15TrendUp || m15TrendDown);
         }
      }
      
      // Pour les achats (Boom/Step Index): nécessite uptrend M15 ET H1
      if(fast > slow)
      {
         if(!h1Valid || !h1TrendUp)
         {
            // Log seulement une fois par minute pour éviter le spam
            static datetime lastH1BlockLog = 0;
            static string lastH1BlockSymbol = "";
            datetime now = TimeCurrent();
            if(now - lastH1BlockLog >= 60 || lastH1BlockSymbol != _Symbol)
            {
               Print("⚠️ ", _Symbol, ": ACHAT BLOQUÉ - Tendance H1 non haussière (H1 valid: ", h1Valid, ", H1 up: ", h1TrendUp, ")");
               lastH1BlockLog = now;
               lastH1BlockSymbol = _Symbol;
            }
            return;
         }
         if(!m15Valid || !m15TrendUp)
         {
            // Log seulement une fois par minute
            static datetime lastM15BlockLog = 0;
            static string lastM15BlockSymbol = "";
            datetime now = TimeCurrent();
            if(now - lastM15BlockLog >= 60 || lastM15BlockSymbol != _Symbol)
            {
               Print("⚠️ ", _Symbol, ": ACHAT BLOQUÉ - Tendance M15 non haussière (M15 valid: ", m15Valid, ", M15 up: ", m15TrendUp, ")");
               lastM15BlockLog = now;
               lastM15BlockSymbol = _Symbol;
            }
            return;
         }
         // Log de confirmation seulement si DebugBlocks est activé
         if(DebugBlocks)
            Print("✅ ", _Symbol, ": Uptrend confirmé M15 + H1 - Achat autorisé");
      }
      
      // Pour les ventes (Crash/Step Index): nécessite downtrend M15 ET H1
      if(fast < slow)
      {
         if(!h1Valid || !h1TrendDown)
         {
            // Log seulement une fois par minute
            static datetime lastH1SellBlockLog = 0;
            static string lastH1SellBlockSymbol = "";
            datetime now = TimeCurrent();
            if(now - lastH1SellBlockLog >= 60 || lastH1SellBlockSymbol != _Symbol)
            {
               Print("⚠️ ", _Symbol, ": VENTE BLOQUÉE - Tendance H1 non baissière (H1 valid: ", h1Valid, ", H1 down: ", h1TrendDown, ")");
               lastH1SellBlockLog = now;
               lastH1SellBlockSymbol = _Symbol;
            }
            return;
         }
         if(!m15Valid || !m15TrendDown)
         {
            // Log seulement une fois par minute
            static datetime lastM15SellBlockLog = 0;
            static string lastM15SellBlockSymbol = "";
            datetime now = TimeCurrent();
            if(now - lastM15SellBlockLog >= 60 || lastM15SellBlockSymbol != _Symbol)
            {
               Print("⚠️ ", _Symbol, ": VENTE BLOQUÉE - Tendance M15 non baissière (M15 valid: ", m15Valid, ", M15 down: ", m15TrendDown, ")");
               lastM15SellBlockLog = now;
               lastM15SellBlockSymbol = _Symbol;
            }
            return;
         }
         // Log de confirmation seulement si DebugBlocks est activé
         if(DebugBlocks)
            Print("✅ ", _Symbol, ": Downtrend confirmé M15 + H1 - Vente autorisée");
      }
   }

   // Determine if price inside IA zones
   bool inBuyZone = (g_aiBuyZoneLow > 0 && g_aiBuyZoneHigh > 0 && bid >= g_aiBuyZoneLow && bid <= g_aiBuyZoneHigh);
   bool inSellZone = (g_aiSellZoneLow > 0 && g_aiSellZoneHigh > 0 && ask <= g_aiSellZoneHigh && ask >= g_aiSellZoneLow);

   double atrVal[1];
   double atr = 0.0;
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atrVal) > 0)
      atr = atrVal[0];

   int dirAllowed = AllowedDirectionFromSymbol(_Symbol);

   // BUY condition (Boom only + Step Index avec tendance haussière)
   if(fast > slow && (inBuyZone || isStepIndex))
   {
      // Pour Step Index: acheter seulement si tendance haussière claire
      if(isStepIndex)
      {
         // Vérifier RSI pour éviter les achats en surachat
         double rsiVal[1];
         if(rsiHandle != INVALID_HANDLE && CopyBuffer(rsiHandle, 0, 0, 1, rsiVal) > 0)
         {
            if(rsiVal[0] > 70)  // Ne pas acheter si RSI > 70
            {
               Print("⚠️ Step Index: ACHAT BLOQUÉ - RSI surachat (", DoubleToString(rsiVal[0], 1), ")");
               return;
            }
         }
      }
      
      // Vérifier si l'achat est autorisé pour ce symbole
      if(IsTradeAllowed(1))  // 1 = direction d'achat
      {
         string reason = isStepIndex ? "EMA UP + Step Index Trend" : "EMA UP + BUY ZONE";
         DrawBasicPredictionArrow(true, ask, reason);
         if(AI_AutoExecuteTrades && CountPositionsForSymbolMagic() == 0)
            ExecuteTradeWithATR(ORDER_TYPE_BUY, atr, ask, "BASIC_EMA_BUY", 1.0, false);
         g_lastBasicSignalTime = TimeCurrent();
      }
      else
      {
         // Log seulement une fois par minute pour éviter le spam
         static datetime lastBuyBlockLog = 0;
         static string lastBuyBlockSymbol = "";
         datetime now = TimeCurrent();
         if(now - lastBuyBlockLog >= 60 || lastBuyBlockSymbol != _Symbol)
         {
            Print("Ordre d'achat bloqué: non autorisé sur ", _Symbol);
            lastBuyBlockLog = now;
            lastBuyBlockSymbol = _Symbol;
         }
      }
      return;
   }
   
   // SELL condition (Crash only + Step Index avec tendance baissière)
   if(fast < slow && (inSellZone || isStepIndex))
   {
      // Pour Step Index: vendre seulement si tendance baissière claire
      if(isStepIndex)
      {
         // Vérifier RSI pour éviter les ventes en survente
         double rsiVal[1];
         if(rsiHandle != INVALID_HANDLE && CopyBuffer(rsiHandle, 0, 0, 1, rsiVal) > 0)
         {
            if(rsiVal[0] < 30)  // Ne pas vendre si RSI < 30
            {
               Print("⚠️ Step Index: VENTE BLOQUÉE - RSI survente (", DoubleToString(rsiVal[0], 1), ")");
               return;
            }
         }
      }
      
      // Vérifier si la vente est autorisée pour ce symbole
      if(IsTradeAllowed(-1))  // -1 = direction de vente
      {
         string reason = isStepIndex ? "EMA DOWN + Step Index Trend" : "EMA DOWN + SELL ZONE";
         DrawBasicPredictionArrow(false, bid, reason);
         if(AI_AutoExecuteTrades && CountPositionsForSymbolMagic() == 0) {
            double lot = CalculateLotSize(atr); // Utiliser le calcul standard sans multiplicateur
            if(lot > 0) {
               ExecuteTradeWithATR(ORDER_TYPE_SELL, lot, bid, "BASIC_EMA_SELL", 1.0, false);
            }
         }
         g_lastBasicSignalTime = TimeCurrent();
      }
      else
      {
         // Log seulement une fois par minute pour éviter le spam
         static datetime lastSellBlockLog = 0;
         static string lastSellBlockSymbol = "";
         datetime now = TimeCurrent();
         if(now - lastSellBlockLog >= 60 || lastSellBlockSymbol != _Symbol)
         {
            Print("Ordre de vente bloqué: non autorisé sur ", _Symbol);
            lastSellBlockLog = now;
            lastSellBlockSymbol = _Symbol;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Fonction de diagnostic complète                                  |
//+------------------------------------------------------------------+
void RunDiagnostic()
{
   string report = "=== RAPPORT DE DIAGNOSTIC ===\n";
   int errors = 0;
   int warnings = 0;
   
   // 1. Vérification de la connexion au terminal
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      report += "❌ ERREUR: Pas de connexion au terminal MT5\n";
      errors++;
   }
   
   // 2. Vérification de la connexion au serveur de trading
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      report += "❌ ERREUR: Le trading automatisé n'est pas autorisé dans les paramètres du terminal\n";
      errors++;
   }
   
   // 3. Vérification des autorisations de trading
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      report += "❌ ERREUR: Le trading automatisé n'est pas autorisé pour ce compte\n";
      errors++;
   }
   
   // 4. Vérification de la connexion Internet
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      report += "⚠️ AVERTISSEMENT: Pas de connexion Internet détectée\n";
      warnings++;
   }
   
   // 5. Vérification des paramètres du compte
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   
   report += StringFormat("• Solde du compte: %.2f %s\n", balance, AccountInfoString(ACCOUNT_CURRENCY));
   report += StringFormat("• Équité: %.2f %s\n", equity, AccountInfoString(ACCOUNT_CURRENCY));
   report += StringFormat("• Marge utilisée: %.2f %s\n", margin, AccountInfoString(ACCOUNT_CURRENCY));
   
   if(margin > 0)
   {
      double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
      report += StringFormat("• Niveau de marge: %.2f%%\n", marginLevel);
      
      if(marginLevel < 100)
      {
         report += "❌ ERREUR: Niveau de marge critique! Inférieur à 100%\n";
         errors++;
      }
      else if(marginLevel < 200)
      {
         report += "⚠️ AVERTISSEMENT: Niveau de marge faible. Inférieur à 200%\n";
         warnings++;
      }
   }
   
   // 6. Vérification des paramètres du symbole
   if(!SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE))
   {
      report += "❌ ERREUR: Le trading n'est pas autorisé pour ce symbole\n";
      errors++;
   }
   
   // 7. Vérification des indicateurs
   if(rsiHandle == INVALID_HANDLE) { report += "❌ ERSEUR: Handle RSI invalide\n"; errors++; }
   if(atrHandle == INVALID_HANDLE) { report += "❌ ERSEUR: Handle ATR invalide\n"; errors++; }
   if(emaFastHandle == INVALID_HANDLE) { report += "❌ ERSEUR: Handle EMA rapide invalide\n"; errors++; }
   if(emaSlowHandle == INVALID_HANDLE) { report += "❌ ERSEUR: Handle EMA lent invalide\n"; errors++; }
   
   // 8. Vérification des paramètres de trading
   if(MaxPositionsTotal <= 0) { report += "⚠️ AVERTISSEMENT: Nombre maximum de positions non défini\n"; warnings++; }
   if(MaxDrawdownPercent <= 0) { report += "⚠️ AVERTISSEMENT: Stop de drawdown non défini\n"; warnings++; }
   
   // 9. Vérification des connexions API
   if(UseAI_Agent && StringLen(AI_TimeWindowsURLBase) == 0)
   {
      report += "⚠️ AVERTISSEMENT: URL de l'API IA non configurée\n";
      warnings++;
   }
   
   // 10. Vérification des paramètres de gestion des risques
   double riskPerTrade = 1.0; // Valeur par défaut si non définie
   // Vérifier si la variable RiskPerTrade existe avant de l'utiliser
   #ifdef RiskPerTrade
   if(RiskPerTrade > 0) riskPerTrade = RiskPerTrade;
   #endif
   
   if(riskPerTrade <= 0 || riskPerTrade > 5)
   {
      report += "⚠️ AVERTISSEMENT: Le risque par trade est en dehors des limites recommandées (0.1% - 5%)\n";
      warnings++;
   }
   
   // 11. Vérification des positions ouvertes
   int totalPos = PositionsTotal();
   if(totalPos > 0)
   {
      report += StringFormat("\n=== POSITIONS OUVERTES (%d) ===\n", totalPos);
      for(int i = 0; i < totalPos; i++)
      {
         if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ulong ticket = PositionGetTicket(i);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            string type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "ACHAT" : "VENTE";
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double sl = PositionGetDouble(POSITION_SL);
            double tp = PositionGetDouble(POSITION_TP);
            
            report += StringFormat("%s #%I64u - %s %.2f lots @ %.5f (actuel: %.5f) - SL: %.5f TP: %.5f - P&L: %.2f %s\n", 
                                 type, ticket, _Symbol, volume, openPrice, currentPrice, sl, tp, 
                                 profit, AccountInfoString(ACCOUNT_CURRENCY));
         }
      }
   }
   
   // 12. Vérification des ordres en attente
   int totalOrders = OrdersTotal();
   if(totalOrders > 0)
   {
      report += StringFormat("\n=== ORDRES EN ATTENTE (%d) ===\n", totalOrders);
      for(int i = 0; i < totalOrders; i++)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket > 0)
         {
            if(OrderSelect(ticket))
            {
               string symbol = OrderGetString(ORDER_SYMBOL);
               ulong magic = OrderGetInteger(ORDER_MAGIC);
               
               if(symbol == _Symbol && magic == InpMagicNumber)
               {
                  ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                  string type = "";
                  
                  switch(orderType)
                  {
                     case ORDER_TYPE_BUY_LIMIT: type = "BUY LIMIT"; break;
                     case ORDER_TYPE_SELL_LIMIT: type = "SELL LIMIT"; break;
                     case ORDER_TYPE_BUY_STOP: type = "BUY STOP"; break;
                     case ORDER_TYPE_SELL_STOP: type = "SELL STOP"; break;
                     default: type = "INCONNU";
                  }
                  
                  double volume = OrderGetDouble(ORDER_VOLUME_CURRENT);
                  double openPrice = OrderGetDouble(ORDER_PRICE_OPEN);
                  double sl = OrderGetDouble(ORDER_SL);
                  double tp = OrderGetDouble(ORDER_TP);
                  
                  report += StringFormat("%s #%I64u - %s %.2f lots @ %.5f - SL: %.5f TP: %.5f\n", 
                                      type, ticket, symbol, volume, openPrice, sl, tp);
               }
            }
         }
      }
   }
   
   // 13. Vérification de l'historique récent
   datetime end = TimeCurrent();
   datetime start = end - 86400; // Dernières 24 heures
   HistorySelect(start, end);
   int totalHistory = HistoryDealsTotal();
   
   if(totalHistory > 0)
   {
      report += StringFormat("\n=== HISTORIQUE RÉCENT (%d opérations) ===\n", totalHistory);
      double totalProfit = 0;
      int wins = 0, losses = 0;
      
      for(int i = 0; i < totalHistory; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket > 0)
         {
            if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol && 
               (ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
            {
               double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
               totalProfit += profit;
               
               if(profit > 0) wins++;
               else if(profit < 0) losses++;
            }
         }
      }
      
      int totalTrades = wins + losses;
      double winRate = (totalTrades > 0) ? (double)wins / totalTrades * 100.0 : 0;
      
      report += StringFormat("• Total des trades: %d\n", totalTrades);
      report += StringFormat("• Trades gagnants: %d (%.1f%%)\n", wins, winRate);
      report += StringFormat("• Trades perdants: %d (%.1f%%)\n", losses, 100.0 - winRate);
      report += StringFormat("• Profit/Perte net: %.2f %s\n", totalProfit, AccountInfoString(ACCOUNT_CURRENCY));
   }
   
   // 14. Vérification de la mémoire utilisée
   long usedMemory = MQLInfoInteger(MQL_MEMORY_USED) / 1024; // en Ko
   report += StringFormat("\n=== RESSOURCES ===\n• Mémoire utilisée: %d Ko\n", usedMemory);
   
   if(usedMemory > 10240) // 10 Mo
   {
      report += "⚠️ AVERTISSEMENT: Utilisation mémoire élevée\n";
      warnings++;
   }
   
   // 15. Vérification des paramètres du robot
   report += "\n=== PARAMÈTRES DU ROBOT ===\n";
   report += StringFormat("• Magic Number: %d\n", InpMagicNumber);
   report += StringFormat("• Lot initial: %.2f\n", FixedLotSize);
   report += StringFormat("• Risque par trade: %.1f%%\n", riskPerTrade);
   
   // Vérifier si StopLoss et TakeProfit sont définis
   int stopLoss = 0, takeProfit = 0;
   #ifdef StopLoss
   if(StopLoss > 0) stopLoss = StopLoss;
   #endif
   #ifdef TakeProfit
   if(TakeProfit > 0) takeProfit = TakeProfit;
   #endif
   
   report += StringFormat("• Stop Loss: %d points\n", stopLoss);
   report += StringFormat("• Take Profit: %d points\n", takeProfit);
   
   // Vérifier si les heures de trading sont définies
   int startH = 0, startM = 0, endH = 23, endM = 59;
   #ifdef StartHour
   if(StartHour >= 0 && StartHour < 24) startH = StartHour;
   #endif
   #ifdef StartMinute
   if(StartMinute >= 0 && StartMinute < 60) startM = StartMinute;
   #endif
   #ifdef EndHour
   if(EndHour >= 0 && EndHour < 24) endH = EndHour;
   #endif
   #ifdef EndMinute
   if(EndMinute >= 0 && EndMinute < 60) endM = EndMinute;
   #endif
   
   report += StringFormat("• Heure de trading: %02d:%02d - %02d:%02d\n", startH, startM, endH, endM);
   
   // 16. Vérification des connexions réseau
   if(UseAI_Agent)
   {
      report += "\n=== CONNEXIONS RÉSEAU ===\n";
      report += StringFormat("• API IA: %s\n", AI_TimeWindowsURLBase);
      
      // Tester la connexion à l'API
      string testUrl = AI_TimeWindowsURLBase + "/test";
      char data[];
      char result[];
      string headers;
      int res = WebRequest("GET", testUrl, NULL, NULL, 5000, data, 0, result, headers);
      
      if(res == 200)
         report += "• Statut API: Connecté\n";
      else
      {
         report += StringFormat("❌ ERREUR: Impossible de se connecter à l'API (code %d)\n", GetLastError());
         errors++;
      }
   }
   
   // Affichage du rapport final
   report += "\n=== RÉSUMÉ DU DIAGNOSTIC ===\n";
   report += StringFormat("• Erreurs critiques: %d\n", errors);
   report += StringFormat("• Avertissements: %d\n", warnings);
   
   if(errors > 0)
      report += "❌ DES ERREURS CRITIQUES ONT ÉTÉ DÉTECTÉES. VÉRIFIEZ LES MESSAGES CI-DESSUS.\n";
   else if(warnings > 0)
      report += "⚠️ DES AVERTISSEMENTS ONT ÉTÉ DÉTECTÉS. VÉRIFIEZ LES MESSAGES CI-DESSUS.\n";
   else
      report += "✅ Aucun problème détecté. Le robot est prêt à trader.\n";
   
   // Enregistrement du rapport dans un fichier
   string filename = "Diagnostic_" + _Symbol + "_" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ".txt";
   StringReplace(filename, " ", "_");
   StringReplace(filename, ":", "-");
   
   int handle = FileOpen(filename, FILE_WRITE|FILE_TXT);
   if(handle != INVALID_HANDLE)
   {
      FileWriteString(handle, report);
      FileClose(handle);
      report += StringFormat("\nRapport enregistré dans: %s\n", filename);
   }
   
   // Affichage dans le journal
   Print(report);
   
   // Affichage dans une fenêtre de message
   Alert("Diagnostic terminé. Voir le journal pour les détails.");
}

//+------------------------------------------------------------------+
//| Missing function implementations                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Fonction de capture d'écran désactivée - Mode texte uniquement  |
//+----------------------------------------------------------------+
string CaptureChartForAI()
{
   // Fonction vide - La capture d'écran est désactivée
   return "";
}

//+------------------------------------------------------------------+
//| Gestionnaire d'événements de trading                             |
//+------------------------------------------------------------------+
void OnTrade()
{
   // Ne traiter que les fermetures de position
   if(HistorySelect(TimeCurrent()-1, TimeCurrent()))
   {
      int total = HistoryDealsTotal();
      if(total > 0)
      {
         // Récupérer le dernier ordre fermé
         ulong ticket = HistoryDealGetTicket(total-1);
         if(ticket > 0)
         {
            // Vérifier si c'est une position fermée (et non un ordre d'ouverture ou autre)
            if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
            {
               // Vérifier si c'est notre EA
               if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
               {
                  // Récupérer le symbole et le profit de la position fermée
                  string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
                  double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                  
                  // Mettre à jour le suivi des pertes/gains avec le symbole
                  UpdateLossTracking(profit, symbol);
                  
                  // Mettre à jour le compteur de pertes pour Boom 1000
                  if(StringFind(symbol, "Boom 1000") != -1)
                  {
                     UpdateBoom1000LossStreak(profit);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+

