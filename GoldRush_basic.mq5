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
input double InpLots = 0.01;
input int InpStopLoss = 500;
input int InpTakeProfit = 1000;
input int InpMagicNum = 123456;
input bool InpUseTrailing = true;
input int InpTrailDist = 300;

//==================== PARAMÈTRES TRAILING STOP SPÉCIAUX ====================
input double BoomCrashTrailDistPips = 50.0;
input double BoomCrashTrailStartPips = 20.0;
input double BoomCrashTrailStepPips = 10.0;

//==================== VOLUMES SPÉCIAUX ====================
input double BoomCrashMinLot = 0.2;

//==================== GESTION AVANCÉE DES PROFITS ====================
input group "--- GESTION PROFITS ---"
input bool UseProfitDuplication = true;
input double ProfitThresholdForDuplicate = 1.0;
input double DuplicationLotSize = 0.4;
input double TotalProfitTarget = 5.0;
input bool AutoCloseOnTarget = false;
input bool UseTrailingForProfit = true;

//==================== PARAMÈTRES IA ====================
input group "--- INTÉGRATION IA ---"
input bool UseAI_Agent = true;
input string AI_ServerURL = "https://kolatradebot.onrender.com/decision";
input string AI_LocalServerURL = "http://localhost:8000/decision";
input bool UseLocalFirst = true;
input double AI_MinConfidence = 0.05;
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
input bool UseMultiTimeframeEMA = true;
input bool UseSupertrendIndicator = true;
input bool UseSupportResistance = true;
input int EMA_Fast_Period = 12;
input int EMA_Slow_Period = 26;
input int Supertrend_Period = 10;
input double Supertrend_Multiplier = 3.0;
input int SR_LookbackBars = 50;

//==================== PARAMÈTRES AVANCÉS ====================
input group "--- FONCTIONNALITÉS AVANCÉES ---"
input bool UseDerivArrowDetection = true;
input bool UseStrongSignalValidation = true;
input bool UseDynamicSLTP = true;
input bool UseAdvancedDashboard = true;

//==================== PARAMÈTRES DÉTECTION DE SPIKES ====================
input group "--- DÉTECTION DE SPIKES ---"
input bool UseSpikeDetection = true;
input double SpikeThresholdPercent = 0.1;  // Réduit à 0.1% pour Boom/Crash
input int SpikeDetectionWindow = 3;        // Réduit à 3 pour plus de sensibilité
input double SpikeMinConfidence = 0.05;     // Réduit à 5% pour plus de détections
input bool UseVolumeSpikeDetection = true;
input double VolumeSpikeMultiplier = 1.5;   // Réduit pour Boom/Crash
input bool UseStandardDeviationSpike = true;
input double StdDevSpikeThreshold = 1.0;    // Réduit pour Boom/Crash
input bool UseSpikePatternAnalysis = true;
input int SpikePatternLookback = 12;        // Réduit pour Boom/Crash
input bool UseLimitOrdersForSpikes = true;

//==================== GESTION DES RISQUES ====================
input group "--- GESTION DES RISQUES ---"
input double MaxDailyDrawdownPercent = 5.0;
input double MaxPositionDrawdown = 10.0;
input int MaxOpenPositions = 5;
input bool UseEmergencyStop = true;
input double EmergencyStopDrawdown = 15.0;
input bool UseTimeBasedTrading = false;
input string TradingStartTime = "08:00";
input string TradingEndTime = "22:00";
input bool UseMaxDailyTrades = true;
input int MaxDailyTrades = 10;
input double RiskPerTrade = 2.0;
input double MinSignalStrength = 0.30;
input int DashboardRefresh = 5;

//==================== SYSTÈME INTELLIGENT (MAX PROFIT / SÉCURITÉ / ANTI-PERTE) ====================
input group "--- SYSTÈME INTELLIGENT ---"
input bool UseSmartBreakeven = true;           // Breakeven automatique pour sécuriser
input double BreakevenTriggerPips = 15.0;      // Déclencher breakeven après X pips profit
input double BreakevenBufferPips = 2.0;        // Buffer au-dessus du prix d'ouverture
input bool UsePartialTakeProfit = true;        // Prise de profit partielle
input double PartialCloseAtPips = 30.0;       // Fermer une partie à X pips profit
input double PartialClosePercent = 50.0;        // Pourcentage du volume à fermer (0-100)
input double MaxLossPerTradePercent = 1.5;    // Perte max par trade (% du balance)
input double MinRiskRewardRatio = 1.2;         // Ratio TP/SL minimum pour entrer (ex: 1.2 = TP au moins 1.2x SL)
input bool UseSecureProfitTrail = true;        // Trailing serré une fois gain sécurisé
input double SecureProfitTriggerPips = 50.0;   // Au-delà de X pips, trailing sécurisé
input double SecureTrailPips = 15.0;           // Distance du trailing en mode sécurisé

//==================== VARIABLES GLOBALES ====================
string LastTradeSignal = "";
double lastPrediction = 0.0;
int lastAISource = 0;
datetime lastDrawTime = 0;
bool g_hasPosition = false;
ulong lastOrderTicket = 0;
double totalSymbolProfit = 0.0;
ulong duplicatedPositionTicket = 0;
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
double LotMultiplier = 1.0;
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

//==================== OBJETS ====================
CTrade trade;

//==================== HANDLES (MULTI-TIMEFRAMES) ====================
int emaFast_H1, emaSlow_H1;
int emaFast_M15, emaSlow_M15;
int emaFast_M5, emaSlow_M5;
int emaFast_M1, emaSlow_M1;
int supertrend_H1, supertrend_M15, supertrend_M5, supertrend_M1;
int maFast_M5, maSlow_M5;
int maFast_H1, maSlow_H1;
int rsi_H1, adx_H1, atr_H1;

//==================== CONTRÔLES ====================
datetime lastBarTime = 0;
datetime lastAIUpdate = 0;
string lastDashText = "";
string g_lastAIAction = "";
double g_lastAIConfidence = 0.0;
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
// Suivi système intelligent (breakeven / partial close)
#define MAX_TRACKED_TICKETS 64
ulong g_partialClosedTickets[MAX_TRACKED_TICKETS];
int g_nPartialClosedTickets = 0;
ulong g_breakevenSetTickets[MAX_TRACKED_TICKETS];
int g_nBreakevenSetTickets = 0;

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
//| INIT                                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNum);

   emaFast_H1 = iMA(_Symbol, PERIOD_H1, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_H1 = iMA(_Symbol, PERIOD_H1, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaFast_M15 = iMA(_Symbol, PERIOD_M15, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_M15 = iMA(_Symbol, PERIOD_M15, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaFast_M5 = iMA(_Symbol, PERIOD_M5, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_M5 = iMA(_Symbol, PERIOD_M5, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaFast_M1 = iMA(_Symbol, PERIOD_M1, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   emaSlow_M1 = iMA(_Symbol, PERIOD_M1, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);

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

void CloseAllPositions()
{
   CTrade tradeLocal;
   tradeLocal.SetExpertMagicNumber(InpMagicNum);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum)
         continue;

      tradeLocal.PositionClose(ticket);
      Print("✅ Position fermée (arrêt d'urgence): ", ticket);
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
//| ON TICK                                                          |
//+------------------------------------------------------------------+
void OnTick()
{
   if(IsEmergencyStopActivated())
   {
      Print("🛑 ARRÊT D'URGENCE - Fermeture de toutes les positions");
      CloseAllPositions();
      ExpertRemove();
      return;
   }

   if(IsDailyDrawdownExceeded())
   {
      Print("⚠️ Drawdown quotidien dépassé - Aucun nouveau trade autorisé aujourd'hui");
      return;
   }

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
   else if(InpUseTrailing)
   {
      if(TimeCurrent() - lastLogTime > 60)
         Print("🔍 Trailing stop actif - Appel de ManageTrailingStop()");
      ManageTrailingStop();
   }

   if(UseProfitDuplication)
      ManageAdvancedProfits();

   if(UseAllEndpoints)
      UpdateAllEndpoints();

   if(UseAI_Agent && TimeCurrent() - lastAIUpdate >= AI_UpdateInterval)
   {
      UpdateAISignal();
      lastAIUpdate = TimeCurrent();
   }

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

   if(UseMultiTimeframeEMA || UseSupertrendIndicator)
      UpdateMultiTimeframeData();

   if(UseDerivArrowDetection)
      UpdateDerivArrowDetection();

   if(UseSpikeDetection)
      UpdateSpikeDetection();

   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   if(!IsSymbolAllowedForTrading())
   {
      Print("❌ Trading non autorisé sur ce symbole: ", _Symbol);
      return;
   }

   bool shouldTrade = false;
   ENUM_ORDER_TYPE tradeType = WRONG_VALUE;

   Print("🔍 DÉCISION TRADING - AI_Agent: ", UseAI_Agent ? "OUI" : "NON",
         ", AI_Confidence: ", DoubleToString(g_lastAIConfidence, 2),
         ", AI_Action: '", g_lastAIAction, "'",
         ", MinConfidence: ", DoubleToString(AI_MinConfidence, 2));

   if(UseAllEndpoints && endpointsAlignment >= MinEndpointsConfidence)
   {
      if(endpointsAlignment > 0.6)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_BUY;
         Print("🎯 Signal endpoints Render: ACHAT (alignement: ", DoubleToString(endpointsAlignment*100, 1), "%)");
      }
      else if(endpointsAlignment < 0.4)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_SELL;
         Print("🎯 Signal endpoints Render: VENTE (alignement: ", DoubleToString(endpointsAlignment*100, 1), "%)");
      }
   }
   else if(UseAI_Agent && HasStrongSignal())
   {
      if(StringFind(g_lastAIAction, "buy") >= 0)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_BUY;
         Print("🎯 Signal IA: ACHAT (confiance: ", DoubleToString(g_lastAIConfidence, 2), ")");
      }
      else if(StringFind(g_lastAIAction, "sell") >= 0)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_SELL;
         Print("🎯 Signal IA: VENTE (confiance: ", DoubleToString(g_lastAIConfidence, 2), ")");
      }
   }
   else if(UseMultiTimeframeEMA || UseSupertrendIndicator)
   {
      if(CheckAdvancedTechnicalSignal())
      {
         shouldTrade = true;
         tradeType = GetAdvancedSignalDirection();
         Print("🎯 Signal technique: ", tradeType == ORDER_TYPE_BUY ? "ACHAT" : "VENTE");
      }
   }
   else if(UseDerivArrowDetection && derivArrowPresent)
   {
      if(derivArrowType == 1)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_BUY;
         Print("🎯 Signal Deriv Arrow: ACHAT");
      }
      else if(derivArrowType == 2)
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_SELL;
         Print("🎯 Signal Deriv Arrow: VENTE");
      }
   }
   else if(UseSpikeDetection && IsSpikeDetected())
   {
      if(GetSpikeType() == "BOOM")
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_BUY;
         Print("🎯 Signal Spike: BOOM ACHAT (confiance: ", DoubleToString(GetSpikeConfidence() * 100, 1), "%)");
      }
      else if(GetSpikeType() == "CRASH")
      {
         shouldTrade = true;
         tradeType = ORDER_TYPE_SELL;
         Print("🎯 Signal Spike: CRASH VENTE (confiance: ", DoubleToString(GetSpikeConfidence() * 100, 1), "%)");
      }
   }

   // MODE FALLBACK - Si aucun signal fort n'est détecté, utiliser un signal simple
   if(!shouldTrade)
   {
      // Vérifier si nous avons au moins une position ouverte
      if(PositionsTotal() == 0)
      {
         // Générer un signal basé sur RSI simple pour éviter le blocage total
         double rsiValue = 50.0;
         if(rsi_H1 != INVALID_HANDLE)
         {
            double rsiBuffer[1];
            if(CopyBuffer(rsi_H1, 0, 0, 1, rsiBuffer) > 0)
               rsiValue = rsiBuffer[0];
         }
         
         if(rsiValue < 35) // RSI très bas = signal d'achat potentiel
         {
            shouldTrade = true;
            tradeType = ORDER_TYPE_BUY;
            Print("🔄 MODE FALLBACK - ACHAT RSI bas (", DoubleToString(rsiValue, 1), ")");
         }
         else if(rsiValue > 65) // RSI très haut = signal de vente potentiel
         {
            shouldTrade = true;
            tradeType = ORDER_TYPE_SELL;
            Print("🔄 MODE FALLBACK - VENTE RSI haut (", DoubleToString(rsiValue, 1), ")");
         }
      }
   }

   if(!shouldTrade)
   {
      Print("❌ Aucun signal de trading valide détecté");
   }

   if(shouldTrade && ValidateAdvancedEntry(tradeType))
   {
      Print("🚀 EXÉCUTION TRADE - Type: ", tradeType == ORDER_TYPE_BUY ? "BUY" : "SELL",
            ", Ask: ", ask, ", Bid: ", bid);

      if(StringFind(_Symbol, "Boom") >= 0 && tradeType == ORDER_TYPE_SELL)
      {
         Print("🚨 SÉCURITÉ - Positions SELL interdites sur Boom: ", _Symbol);
         return;
      }

      if(StringFind(_Symbol, "Crash") >= 0 && tradeType == ORDER_TYPE_BUY)
      {
         Print("🚨 SÉCURITÉ - Positions BUY interdites sur Crash: ", _Symbol);
         return;
      }

      if(UseSpikeDetection && IsSpikeDetected())
      {
         ExecuteSpikeTrade(tradeType, ask, bid);
      }
      else
      {
         ExecuteAdvancedTrade(tradeType, ask, bid);
      }
   }
   else if(shouldTrade)
   {
      Print("❌ Trade annulé - Validation entrée échouée");
   }

   DrawMultiTimeframeIndicators();
   double rsi[], adx[], atr[];
   ArraySetAsSeries(rsi,true);
   ArraySetAsSeries(adx,true);
   ArraySetAsSeries(atr,true);
   // Récupérer les valeurs des indicateurs avec gestion d'erreur
   double rsiVal = 50.0;
   double adxVal = 0.0;
   double atrVal = 0.0;
   
   if(rsi_H1 != INVALID_HANDLE)
   {
      double rsiBuffer[1];
      if(CopyBuffer(rsi_H1,0,0,1,rsiBuffer)>0)
         rsiVal = rsiBuffer[0];
   }
   
   if(adx_H1 != INVALID_HANDLE)
   {
      double adxBuffer[1];
      if(CopyBuffer(adx_H1,0,0,1,adxBuffer)>0)
         adxVal = adxBuffer[0];
   }
   
   if(atr_H1 != INVALID_HANDLE)
   {
      double atrBuffer[1];
      if(CopyBuffer(atr_H1,0,0,1,atrBuffer)>0)
         atrVal = atrBuffer[0];
   }
   
   Print("Valeurs des indicateurs - RSI:", rsiVal, " ADX:", adxVal, " ATR:", atrVal);
   DrawAdvancedDashboard(rsiVal, adxVal, atrVal);
   
   // Forcer l'affichage du dashboard à chaque tick
   static datetime lastDashboardUpdate = 0;
   if(TimeCurrent() - lastDashboardUpdate >= 5) // Mise à jour toutes les 5 secondes
   {
      DrawAdvancedDashboard(rsiVal, adxVal, atrVal);
      lastDashboardUpdate = TimeCurrent();
   }
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

      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol) continue;

      bool isBoom = (StringFind(symbol, "Boom") >= 0);
      bool isCrash = (StringFind(symbol, "Crash") >= 0);

      if(!isBoom && !isCrash) continue;

      if(UseTrailingForProfit)
      {
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            double newSL = currentPrice - (BoomCrashTrailStepPips * 10 * point);
            if(newSL > sl && newSL > openPrice)
            {
               trade.PositionModify(ticket, newSL, tp);
            }
         }
         else // POSITION_TYPE_SELL
         {
            double newSL = currentPrice + (BoomCrashTrailStepPips * 10 * point);
            if((sl == 0 || newSL < sl) && newSL < openPrice)
            {
               trade.PositionModify(ticket, newSL, tp);
            }
         }
      }
   }
}

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
               double distance = bid - newSL;
               // Désactivation temporaire des erreurs SL pour Volatility
               if(StringFind(_Symbol, "Volatility") >= 0)
               {
                  Print("🔧 SYMBOLE VOLATILITY - Validation SL désactivée dans trailing stop");
                  continue; // Continuer sans erreur
               }
               
               if(distance < stopLevel)
               {
                  Print("❌ SL trop proche du prix actuel pour BUY. Distance: ", DoubleToString(distance, 5),
                        ", Minimum: ", DoubleToString(stopLevel, 5));
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
               double distance = newSL - ask;
               // Désactivation temporaire des erreurs SL pour Volatility
               if(StringFind(_Symbol, "Volatility") >= 0)
               {
                  Print("🔧 SYMBOLE VOLATILITY - Validation SL désactivée dans trailing stop");
                  continue; // Continuer sans erreur
               }
               
               if(distance < stopLevel)
               {
                  Print("❌ SL trop proche du prix actuel pour SELL. Distance: ", DoubleToString(distance, 5),
                        ", Minimum: ", DoubleToString(stopLevel, 5));
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
   if(!UseSmartBreakeven && !UsePartialTakeProfit && !UseSecureProfitTrail)
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
            newSL = NormalizeDouble(newSL, digits);
            newSL = MathMax(newSL, openPrice);
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
            newSL = NormalizeDouble(newSL, digits);
            newSL = MathMin(newSL, openPrice);
            if((currentSL == 0 || newSL < currentSL - minDist) && newSL > ask + minDist)
            {
               if(CheckStopLoss(_Symbol, (ENUM_POSITION_TYPE)posType, openPrice, newSL, currentTP))
               {
                  trade.PositionModify(ticket, newSL, currentTP);
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

   if(!hasDuplicated && maxPositionProfit >= ProfitThresholdForDuplicate)
   {
      if(PositionSelectByTicket(mostProfitableTicket))
      {
         long type = PositionGetInteger(POSITION_TYPE);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         if(type == POSITION_TYPE_BUY)
         {
            double sl = bid - InpStopLoss * _Point;
            double tp = bid + InpTakeProfit * _Point;

            if(trade.Buy(GetCorrectLotSize(), _Symbol, ask, sl, tp, "GoldRush Duplication"))
            {
               hasDuplicated = true;
               duplicatedPositionTicket = trade.ResultOrder();
               Print("🚀 Position dupliquée - Lot: ", GetCorrectLotSize(), " - Ticket: ", duplicatedPositionTicket);
            }
         }
         else if(type == POSITION_TYPE_SELL)
         {
            double sl = ask + InpStopLoss * _Point;
            double tp = ask - InpTakeProfit * _Point;

            if(trade.Sell(GetCorrectLotSize(), _Symbol, bid, sl, tp, "GoldRush Duplication"))
            {
               hasDuplicated = true;
               duplicatedPositionTicket = trade.ResultOrder();
               Print("🚀 Position dupliquée - Lot: ", GetCorrectLotSize(), " - Ticket: ", duplicatedPositionTicket);
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
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNum) continue;

      if(trade.PositionClose(ticket))
         Print("✅ Position fermée - Ticket: ", ticket, " - Raison: ", reason);
   }

   hasDuplicated = false;
   duplicatedPositionTicket = 0;
   totalSymbolProfit = 0.0;
}

//+------------------------------------------------------------------+
//| OBTENIR LE VOLUME CORRECT POUR LE SYMBOLE                  |
//+------------------------------------------------------------------+
double GetCorrectLotSize()
{
   string symbol = _Symbol;
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "Gold") >= 0 ||
      StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "Silver") >= 0 ||
      StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0 ||
      StringFind(symbol, "Volatility") >= 0)
   {
      Print("📊 Symbole à risque détecté: ", symbol);
      Print("   Lot minimum broker: ", minLot);
      Print("   Lot maximum broker: ", maxLot);
      Print("   Step lot: ", stepLot);
      Print("   ⚠️ Utilisation du lot minimum pour sécurité");

      double adjustedLot = MathRound(minLot / stepLot) * stepLot;
      adjustedLot = MathMax(adjustedLot, minLot);

      Print("   ✅ Lot ajusté: ", adjustedLot);
      return adjustedLot;
   }

   if(StringFind(symbol, "USD") >= 0 || StringFind(symbol, "EUR") >= 0 ||
      StringFind(symbol, "GBP") >= 0 || StringFind(symbol, "JPY") >= 0 ||
      StringFind(symbol, "AUD") >= 0 || StringFind(symbol, "CAD") >= 0 ||
      StringFind(symbol, "CHF") >= 0 || StringFind(symbol, "NZD") >= 0)
   {
      Print("📊 Symbole Forex détecté: ", symbol);
      Print("   Lot minimum broker: ", minLot);
      Print("   ⚠️ Utilisation du lot minimum pour sécurité");

      double adjustedLot = MathRound(minLot / stepLot) * stepLot;
      adjustedLot = MathMax(adjustedLot, minLot);

      Print("   ✅ Lot ajusté: ", adjustedLot);
      return adjustedLot;
   }

   double finalLot = MathMax(InpLots, minLot);
   finalLot = MathRound(finalLot / stepLot) * stepLot;
   finalLot = MathMin(finalLot, maxLot);

   Print("📊 Symbole standard: ", symbol);
   Print("   Lot configuré: ", finalLot);

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
         
         // Mettre à jour la source
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

   return (g_lastAIConfidence >= AI_MinConfidence &&
           (StringFind(g_lastAIAction, "buy") >= 0 || StringFind(g_lastAIAction, "sell") >= 0));
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
   double high_H1[], low_H1[];
   ArraySetAsSeries(high_H1, true);
   ArraySetAsSeries(low_H1, true);

   if(CopyHigh(_Symbol, PERIOD_H1, 0, SR_LookbackBars, high_H1) > 0 &&
      CopyLow(_Symbol, PERIOD_H1, 0, SR_LookbackBars, low_H1) > 0)
   {
      H1_Resistance = high_H1[ArrayMaximum(high_H1, 0, SR_LookbackBars)];
      H1_Support = low_H1[ArrayMinimum(low_H1, 0, SR_LookbackBars)];
   }

   double high_M5[], low_M5[];
   ArraySetAsSeries(high_M5, true);
   ArraySetAsSeries(low_M5, true);

   if(CopyHigh(_Symbol, PERIOD_M5, 0, SR_LookbackBars, high_M5) > 0 &&
      CopyLow(_Symbol, PERIOD_M5, 0, SR_LookbackBars, low_M5) > 0)
   {
      M5_Resistance = high_M5[ArrayMaximum(high_M5, 0, SR_LookbackBars)];
      M5_Support = low_M5[ArrayMinimum(low_M5, 0, SR_LookbackBars)];
   }
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
   double correctLotSize = CalculateLotSize((int)MathMax(1, (int)stopLossPips));
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
         Print("✅ Trade ACHAT exécuté - Lot: ", correctLotSize, " - SL: ", sl, " TP: ", tp);
      else
         Print("❌ Échec ACHAT - Erreur: ", trade.ResultRetcode());
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(trade.Sell(correctLotSize, _Symbol, bid, sl, tp, "GoldRush AI Sell"))
         Print("✅ Trade VENTE exécuté - Lot: ", correctLotSize, " - SL: ", sl, " TP: ", tp);
      else
         Print("❌ Échec VENTE - Erreur: ", trade.ResultRetcode());
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
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atrVal = 0.0;
   if(atr_H1 != INVALID_HANDLE)
   {
      double atrBuf[1];
      if(CopyBuffer(atr_H1, 0, 0, 1, atrBuf) > 0) atrVal = atrBuf[0];
   }
   double slDist = (InpStopLoss > 0) ? (InpStopLoss * point) : (atrVal * 2.0);
   double tpDist = (InpTakeProfit > 0) ? (InpTakeProfit * point) : (atrVal * 3.0);
   if(slDist <= 0) slDist = 100 * point;
   if(tpDist <= 0) tpDist = 150 * point;
   double rrRatio = tpDist / slDist;
   if(MinRiskRewardRatio > 0 && rrRatio < MinRiskRewardRatio)
   {
      Print("❌ Entrée rejetée: ratio risque/récompense ", DoubleToString(rrRatio, 2), " < ", DoubleToString(MinRiskRewardRatio, 2));
      return false;
   }

   Print("🔍 VALIDATION ENTRY - Type: ", orderType == ORDER_TYPE_BUY ? "BUY" : "SELL",
         ", Prix: ", currentPrice,
         ", R:R=", DoubleToString(rrRatio, 2),
         ", UseSupportResistance: ", UseSupportResistance ? "OUI" : "NON",
         ", UseSupertrend: ", UseSupertrendIndicator ? "OUI" : "NON");

   if(UseSupportResistance)
   {
      if(orderType == ORDER_TYPE_BUY && currentPrice > H1_Resistance * 0.995)
      {
         Print("❌ Entrée ACHAT rejetée: trop près de la résistance H1 (", H1_Resistance, ")");
         return false;
      }
      if(orderType == ORDER_TYPE_SELL && currentPrice < H1_Support * 1.005)
      {
         Print("❌ Entrée VENTE rejetée: trop près du support H1 (", H1_Support, ")");
         return false;
      }
   }

   if(UseSupertrendIndicator)
   {
      Print("🔍 Supertrend H1 direction: ", supertrend_H1_dir);
      if(orderType == ORDER_TYPE_BUY && supertrend_H1_dir < 0)
      {
         Print("❌ Entrée ACHAT rejetée: Supertrend H1 baissier");
         return false;
      }
      if(orderType == ORDER_TYPE_SELL && supertrend_H1_dir > 0)
      {
         Print("❌ Entrée VENTE rejetée: Supertrend H1 haussier");
         return false;
      }
   }

   Print("✅ Validation entrée réussie");
   return true;
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
   if(TimeCurrent() - lastUpdate < 60)
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
//| DÉTECTION DE SPIKE PAR POURCENTAGE                              |
//+------------------------------------------------------------------+
bool DetectPercentageSpike(double currentPrice, double &priceMA, double &priceSTD, double &intensity, double &confidence)
{
   double prices[];
   ArraySetAsSeries(prices, true);

   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, SpikeDetectionWindow, prices) < SpikeDetectionWindow)
      return false;

   priceMA = 0;
   for(int i = 0; i < SpikeDetectionWindow; i++)
      priceMA += prices[i];
   priceMA /= SpikeDetectionWindow;

   priceSTD = 0;
   for(int i = 0; i < SpikeDetectionWindow; i++)
      priceSTD += MathPow(prices[i] - priceMA, 2);
   priceSTD = MathSqrt(priceSTD / SpikeDetectionWindow);

   double priceChangePct = ((currentPrice - priceMA) / priceMA) * 100;

   bool isSpike = MathAbs(priceChangePct) > SpikeThresholdPercent;

   if(isSpike)
   {
      intensity = MathAbs(priceChangePct);

      double pctMA = 0;
      double pctSTD = 0;
      double pctChanges[];
      ArraySetAsSeries(pctChanges, true);

      for(int i = 1; i < SpikeDetectionWindow; i++)
      {
         pctChanges[i-1] = ((prices[i-1] - prices[i]) / prices[i]) * 100;
         pctMA += pctChanges[i-1];
      }

      if(SpikeDetectionWindow > 1)
      {
         pctMA /= (SpikeDetectionWindow - 1);

         for(int i = 0; i < SpikeDetectionWindow - 1; i++)
            pctSTD += MathPow(pctChanges[i] - pctMA, 2);
         pctSTD = MathSqrt(pctSTD / (SpikeDetectionWindow - 1));
      }

      if(pctSTD > 0)
         confidence = MathMin(MathAbs(priceChangePct) / (MathAbs(pctMA) + 0.5 * pctSTD), 1.0);
      else
         confidence = MathMin(intensity / SpikeThresholdPercent, 1.0);

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| DÉTECTION DE SPIKE PAR ÉCART-TYPE (Z-SCORE)                     |
//+------------------------------------------------------------------+
bool DetectStandardDeviationSpike(double currentPrice, double &priceMA, double &priceSTD, double &spikeZScore, double &intensity, double &confidence)
{
   double prices[];
   ArraySetAsSeries(prices, true);

   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, SpikeDetectionWindow, prices) < SpikeDetectionWindow)
      return false;

   priceMA = 0;
   for(int i = 0; i < SpikeDetectionWindow; i++)
      priceMA += prices[i];
   priceMA /= SpikeDetectionWindow;

   priceSTD = 0;
   for(int i = 0; i < SpikeDetectionWindow; i++)
      priceSTD += MathPow(prices[i] - priceMA, 2);
   priceSTD = MathSqrt(priceSTD / SpikeDetectionWindow);

   if(priceSTD > 0)
      spikeZScore = MathAbs(currentPrice - priceMA) / priceSTD;
   else
      spikeZScore = 0;

   bool isSpike = spikeZScore > StdDevSpikeThreshold;

   if(isSpike)
   {
      intensity = spikeZScore;
      confidence = MathMin(spikeZScore / StdDevSpikeThreshold, 1.0);
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
