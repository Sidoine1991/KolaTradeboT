//+------------------------------------------------------------------+
//|                                          F_INX_scalper_double.mq5 |
//|                                      Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.metaquotes.net/ |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.metaquotes.net/"
#property version   "1.00"

#include "d:\\Dev\\TradBOT\\mt5\\Include\\Trade\\Trade.mqh"
#include "d:\\Dev\\TradBOT\\mt5\\Include\\Object.mqh"
#include "d:\\Dev\\TradBOT\\mt5\\Include\\StdLibErr.mqh"
#include "d:\\Dev\\TradBOT\\mt5\\Include\\Trade\\OrderInfo.mqh"
#include "d:\\Dev\\TradBOT\\mt5\\Include\\Trade\\HistoryOrderInfo.mqh"
#include "d:\\Dev\\TradBOT\\mt5\\Include\\Trade\\PositionInfo.mqh"
#include "d:\\Dev\\TradBOT\\mt5\\Include\\Trade\\DealInfo.mqh"

//+------------------------------------------------------------------+
//| Paramètres d'entrée                                              |
//+------------------------------------------------------------------+
input group "--- CONFIGURATION DE BASE ---"
input int    InpMagicNumber     = 888888;  // Magic Number
input double InitialLotSize     = 0.01;    // Taille de lot initiale
input double MaxLotSize          = 1.0;     // Taille de lot maximale
input double TakeProfitUSD       = 10.0;    // Take Profit en USD (fixe)
input double StopLossUSD         = 5.0;     // Stop Loss en USD (fixe)
input double ProfitThresholdForDouble = 0.5; // Seuil de profit (USD) pour doubler le lot
input int    MinPositionLifetimeSec = 5;    // Délai minimum avant modification (secondes)

input group "--- AI AGENT ---"
input bool   UseAI_Agent        = true;    // Activer l'agent IA (via serveur externe)
input string AI_ServerURL       = "http://127.0.0.1:8000/decision"; // URL serveur IA
input bool   UseAdvancedDecisionGemma = true; // Utiliser endpoint decisionGemma (Gemma+Gemini) avec analyse visuelle
input int    AI_Timeout_ms       = 800;     // Timeout WebRequest en millisecondes
input double AI_MinConfidence    = 0.8;     // Confiance minimale IA pour trader (80%)
input int    AI_UpdateInterval   = 5;      // Intervalle de mise à jour IA (secondes)
input string AI_AnalysisURL    = "http://127.0.0.1:8000/analysis";  // URL base pour l'analyse complète (structure H1, etc.)
input int    AI_AnalysisIntervalSec = 60;  // Fréquence de rafraîchissement de l'analyse (secondes)
input string AI_TimeWindowsURLBase = "http://127.0.0.1:8000"; // Racine API pour /time_windows

input group "--- ÉLÉMENTS GRAPHIQUES ---"
input bool   DrawAIZones         = true;    // Dessiner les zones BUY/SELL de l'IA
input bool   DrawSupportResistance = true;  // Dessiner support/résistance M5/H1
input bool   DrawTrendlines      = true;    // Dessiner les trendlines
input bool   DrawDerivPatterns   = true;    // Dessiner les patterns Deriv
input bool   DrawSMCZones        = true;    // Dessiner les zones SMC/OrderBlock

input group "--- STRATÉGIE US SESSION BREAK & RETEST (PRIORITAIRE) ---"
input bool   UseUSSessionStrategy = true;   // Activer la stratégie US Session (prioritaire)
input double US_RiskReward        = 2.0;    // Risk/Reward ratio pour US Session
input int    US_RetestTolerance   = 30;     // Tolérance retest en points
input bool   US_OneTradePerDay    = true;   // Un seul trade par jour pour US Session

input group "--- GESTION DES RISQUES ---"
input double MaxDailyLoss        = 100.0;   // Perte quotidienne maximale (USD)
input double MaxDailyProfit      = 200.0;   // Profit quotidien maximale (USD)
input double CautiousModeProfitThreshold = 0.7; // Seuil pour activer mode prudent (70% de MaxDailyProfit)
input double MaxTotalLoss        = 5.0;     // Perte totale maximale toutes positions (USD)
input bool   UseTrailingStop     = false;   // Utiliser trailing stop (désactivé pour scalping fixe)

input group "--- SORTIES VOLATILITY ---"
input double VolatilityQuickTP   = 2.0;     // Fermer rapidement les indices Volatility à +2$ de profit

input group "--- SORTIES BOOM/CRASH ---"
input double BoomCrashSpikeTP    = 0.01;    // Fermer Boom/Crash dès que le spike donne au moins ce profit (0.01 = quasi immédiat)

input group "--- INDICATEURS ---"
input int    EMA_Fast_Period     = 9;       // Période EMA rapide
input int    EMA_Slow_Period     = 21;      // Période EMA lente
input int    RSI_Period          = 14;      // Période RSI
input int    ATR_Period          = 14;      // Période ATR

input group "--- DEBUG ---"
input bool   DebugMode           = true;    // Mode debug (logs détaillés)

//+------------------------------------------------------------------+
//| Variables globales                                               |
//+------------------------------------------------------------------+
// Trading objects (will be initialized in OnInit)
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
int rsiHandle;
int atrHandle;
int atrM5Handle;
int atrH1Handle;

// Variables IA
static string   g_lastAIAction    = "";
static double   g_lastAIConfidence = 0.0;
static string   g_lastAIReason    = "";
static datetime g_lastAITime      = 0;
static bool     g_aiFallbackMode  = false;
static int      g_aiConsecutiveFailures = 0;
const int       AI_FAILURE_THRESHOLD = 3;

// Nouvelles variables IA enrichies (depuis ai_server.py amélioré)
static double   g_lastAIRawScore  = 0.0;        // Score brut multi-timeframe
static int      g_lastAIBullishTFs = 0;          // Nombre de timeframes haussiers alignés
static int      g_lastAIBearishTFs = 0;          // Nombre de timeframes baissiers alignés
static bool     g_lastAIM5H1Alignment = false;  // Alignement M5/H1 confirmé par l'IA
static string   g_lastAIDirectionM1 = "";       // Direction M1
static string   g_lastAIDirectionM5 = "";       // Direction M5
static string   g_lastAIDirectionH1 = "";       // Direction H1
static string   g_lastAIDirectionM30 = "";      // Direction M30
static string   g_lastAIDirectionH4 = "";       // Direction H4
static string   g_lastAIDirectionD1 = "";       // Direction D1
static double   g_lastAIConfidenceM1 = 0.0;     // Confiance M1
static double   g_lastAIConfidenceM5 = 0.0;     // Confiance M5
static double   g_lastAIConfidenceH1 = 0.0;     // Confiance H1
static double   g_lastAIConfidenceM30 = 0.0;    // Confiance M30
static double   g_lastAIConfidenceH4 = 0.0;     // Confiance H4
static double   g_lastAIConfidenceD1 = 0.0;     // Confiance D1
static string   g_lastAIAssetClass = "";         // Classe d'actif: "boom_crash", "volatility", "forex", "metal", "index", "other"
static double   g_lastAITradingHourScore = 0.0;  // Score horaire (bonus/malus selon heures préférées/interdites)

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
const double PROFIT_SECURE_THRESHOLD = 5.0;  // Seuil d'activation (5$) - ferme toutes positions gagnantes
const double PROFIT_DRAWDOWN_LIMIT = 0.5;    // Limite de drawdown (50%)

// Suivi de la recommandation IA qui a ouvert la position
static string g_positionAIAction = "";  // Action IA qui a ouvert la position actuelle ("buy", "sell", "")

// Variable globale pour le type de signal actuel
static ENUM_ORDER_TYPE currentSignalType = WRONG_VALUE;

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
//| Forward declarations                                             |
//+------------------------------------------------------------------+
void SecureDynamicProfits();
bool CheckAIZoneEntryWithEMA(ENUM_ORDER_TYPE orderType, bool &isInZone, bool &emaConfirmed, bool &isCorrection);
void CloseVolatilityIfLossExceeded(double lossLimit);
void CloseProfitablePositionsOnMaxLoss();
double GetTotalLoss();
void CheckAndManagePositions();
void LookForTradingOpportunity();
void ResetDailyCountersIfNeeded();
void ResetDailyCounters();
void UpdateAIDecision();
void ExtractAIZonesFromResponse(string resp);
void ExtractEnrichedAIFields(string resp);
void ExtractTimeframeData(string resp, string timeframe, string &direction, double &confidence);
void DrawSupportResistanceLevels();
void DrawAIZonesOnChart();
void DrawTrendlinesOnChart();
void DrawDerivPatternsOnChart();
void UpdateDerivArrowBlink();
bool IsVolatilitySymbol(const string symbol);
bool IsIndexSymbol(const string symbol);
bool CheckM1M5H1Alignment(ENUM_ORDER_TYPE orderType);
bool IsInCompressionRange();
bool CheckEMAEntryConfirmation(ENUM_ORDER_TYPE orderType);
void CloseBoomCrashAfterSpike(ulong ticket, double currentProfit);
void CheckAndCloseBuyOnCorrection(ulong ticket, double currentProfit);
void CheckAndCloseSellOnCorrection(ulong ticket, double currentProfit);
void CheckAndCloseOnAIRecommendationChange(ulong ticket, int posType, double currentProfit);
void ExecuteTrade(ENUM_ORDER_TYPE orderType);
bool ExecuteUSTrade(ENUM_ORDER_TYPE orderType, double entryPrice, double sl, double tp);
bool TrySpikeEntry(ENUM_ORDER_TYPE orderType);
double NormalizeLotSize(double lot);
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
   
   if(emaFastHandle == INVALID_HANDLE || emaSlowHandle == INVALID_HANDLE || 
      emaFastH1Handle == INVALID_HANDLE || emaSlowH1Handle == INVALID_HANDLE ||
      emaFastM5Handle == INVALID_HANDLE || emaSlowM5Handle == INVALID_HANDLE ||
      rsiHandle == INVALID_HANDLE || atrHandle == INVALID_HANDLE ||
      atrM5Handle == INVALID_HANDLE || atrH1Handle == INVALID_HANDLE)
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
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(atrM5Handle != INVALID_HANDLE) IndicatorRelease(atrM5Handle);
   if(atrH1Handle != INVALID_HANDLE) IndicatorRelease(atrH1Handle);
   
   Print("Robot Scalper Double arrêté");
} // Fin de OnDeinit

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Vérifier la connexion au serveur de trading
   if(!TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      if(DebugMode) Print("⚠️ Déconnecté du serveur de trading !");
      return;
   }
   
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      if(DebugMode) Print("⚠️ Le trading automatisé n'est pas autorisé !");
      return;
   }
   
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      if(DebugMode) Print("⚠️ Le trading n'est pas autorisé dans le terminal !");
      return;
   }
   
   // Réinitialiser les compteurs quotidiens si nécessaire
   ResetDailyCountersIfNeeded();
   
   // NOUVELLE LOGIQUE: Activer le mode prudent quand le profit journalier atteint un seuil
   // Pour protéger les gains, on ne prend que les signaux très sûrs
   double cautiousModeThreshold = MaxDailyProfit * CautiousModeProfitThreshold;
   bool cautiousMode = (g_dailyProfit >= cautiousModeThreshold);
   if(cautiousMode && DebugMode)
      Print("⚠️ MODE PRUDENT ACTIVÉ: Profit journalier élevé (", DoubleToString(g_dailyProfit, 2), " USD >= ", DoubleToString(cautiousModeThreshold, 2), " USD) - Seulement signaux très sûrs pour protéger les gains");
   
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
   
   // Dessiner les éléments graphiques
   static datetime lastDrawUpdate = 0;
   if(TimeCurrent() - lastDrawUpdate >= 5) // Mise à jour toutes les 5 secondes
   {
      if(DrawSupportResistance)
         DrawSupportResistanceLevels();
      if(DrawAIZones)
         DrawAIZonesOnChart();
      if(DrawTrendlines)
         DrawTrendlinesOnChart();
      if(DrawDerivPatterns)
      {
         DrawDerivPatternsOnChart();
         UpdateDerivArrowBlink(); // Mettre à jour le clignotement (une fois toutes les 5 secondes avec DrawDerivPatternsOnChart)
      }
      lastDrawUpdate = TimeCurrent();
   }
   
   // Vérifier les positions existantes
   CheckAndManagePositions();
   
   // Sécurisation dynamique des profits
   SecureDynamicProfits();
   
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
      Print("📥 Réponse IA reçue: ", StringSubstr(resp, 0, 200)); // Afficher les 200 premiers caractères
   
   // Parser la réponse JSON - recherche plus robuste
   int actionPos = StringFind(resp, "\"action\"");
   if(actionPos < 0)
      actionPos = StringFind(resp, "\"action\""); // Essayer sans échappement
   
   if(actionPos >= 0)
   {
      // Chercher la valeur après "action":
      int colonPos = StringFind(resp, ":", actionPos);
      if(colonPos > actionPos)
      {
         // Chercher la valeur entre guillemets
         int quoteStart = StringFind(resp, "\"", colonPos);
         if(quoteStart > colonPos)
         {
            int quoteEnd = StringFind(resp, "\"", quoteStart + 1);
            if(quoteEnd > quoteStart)
            {
               string actionValue = StringSubstr(resp, quoteStart + 1, quoteEnd - quoteStart - 1);
               StringToLower(actionValue); // Convertir en minuscules pour comparaison
               
               // Gérer différents formats possibles
               if(StringFind(actionValue, "buy") >= 0 || StringFind(actionValue, "achat") >= 0)
                  g_lastAIAction = "buy";
               else if(StringFind(actionValue, "sell") >= 0 || StringFind(actionValue, "vente") >= 0)
                  g_lastAIAction = "sell";
               else
                  g_lastAIAction = "hold";
            }
         }
      }
      
      // Fallback: recherche simple si le parsing détaillé échoue
      if(g_lastAIAction == "")
      {
         string respLower = resp;
         StringToLower(respLower);
         if(StringFind(respLower, "\"buy\"") >= 0 || StringFind(respLower, "buy") >= 0)
            g_lastAIAction = "buy";
         else if(StringFind(respLower, "\"sell\"") >= 0 || StringFind(respLower, "sell") >= 0)
            g_lastAIAction = "sell";
         else
            g_lastAIAction = "hold";
      }
   }
   else
   {
      // Si "action" n'est pas trouvé, essayer de détecter directement
      string respLower = resp;
      StringToLower(respLower);
      if(StringFind(respLower, "\"buy\"") >= 0)
         g_lastAIAction = "buy";
      else if(StringFind(respLower, "\"sell\"") >= 0)
         g_lastAIAction = "sell";
      else
         g_lastAIAction = "hold";
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
   
   int reasonPos = StringFind(resp, "\"reason\"");
   if(reasonPos >= 0)
   {
      int colonR = StringFind(resp, ":", reasonPos);
      if(colonR > 0)
      {
         int startQuote = StringFind(resp, "\"", colonR);
         if(startQuote > 0)
         {
            int endQuote = StringFind(resp, "\"", startQuote + 1);
            if(endQuote > startQuote)
               g_lastAIReason = StringSubstr(resp, startQuote + 1, endQuote - startQuote - 1);
         }
      }
   }
   
   // If we successfully parsed the response, process the data
   if(g_lastAIAction != "")
   {
      // Extraire les zones BUY/SELL depuis la réponse JSON
      ExtractAIZonesFromResponse(resp);
      
      // Extraire les nouveaux champs enrichis depuis la réponse JSON
      ExtractEnrichedAIFields(resp);
      
      g_lastAITime = TimeCurrent();
      
      if(DebugMode)
      {
         string alignmentInfo = g_lastAIM5H1Alignment ? "✅ M5/H1 aligné" : "❌ M5/H1 non aligné";
         string assetInfo = g_lastAIAssetClass != "" ? " | Asset: " + g_lastAIAssetClass : "";
         Print("🤖 IA: ", g_lastAIAction, " (confiance: ", DoubleToString(g_lastAIConfidence, 2), 
               " | Score brut: ", DoubleToString(g_lastAIRawScore, 2),
               " | TF: ", IntegerToString(g_lastAIBullishTFs), "↑/", IntegerToString(g_lastAIBearishTFs), "↓",
               " | ", alignmentInfo, assetInfo, ") - ", g_lastAIReason);
      }
   }
}

//+------------------------------------------------------------------+
//| Extraire les zones BUY/SELL depuis la réponse JSON de l'IA       |
//+------------------------------------------------------------------+
void ExtractAIZonesFromResponse(string resp)
{
   if(resp == "") 
      return;
      
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
//| Extraire les champs enrichis depuis la réponse JSON de l'IA      |
//+------------------------------------------------------------------+
void ExtractEnrichedAIFields(string resp)
{
   if(resp != "")
   {
      // Extraire raw_score
      int rawScorePos = StringFind(resp, "\"raw_score\"");
      if(rawScorePos >= 0)
      {
         int colon = StringFind(resp, ":", rawScorePos);
         if(colon > 0)
         {
            int endPos = StringFind(resp, ",", colon);
            if(endPos > 0)
            {
               string rawScoreStr = StringSubstr(resp, colon + 1, endPos - colon - 1);
               g_lastAIRawScore = StringToDouble(rawScoreStr);
            }
         }
      }
      
      // Initialiser les variables avec des valeurs par défaut
      string dirM1 = "", dirM5 = "", dirH1 = "", dirM30 = "", dirH4 = "", dirD1 = "";
      double confM1 = 0.0, confM5 = 0.0, confH1 = 0.0, confM30 = 0.0, confH4 = 0.0, confD1 = 0.0;
      
      ExtractTimeframeData(resp, "M1", dirM1, confM1);
      g_lastAIDirectionM1 = dirM1;
      g_lastAIConfidenceM1 = confM1;
      
      ExtractTimeframeData(resp, "M5", dirM5, confM5);
      g_lastAIDirectionM5 = dirM5;
      g_lastAIConfidenceM5 = confM5;
      
      ExtractTimeframeData(resp, "H1", dirH1, confH1);
      g_lastAIDirectionH1 = dirH1;
      g_lastAIConfidenceH1 = confH1;
      
      ExtractTimeframeData(resp, "M30", dirM30, confM30);
      g_lastAIDirectionM30 = dirM30;
      g_lastAIConfidenceM30 = confM30;
      
      ExtractTimeframeData(resp, "H4", dirH4, confH4);
      g_lastAIDirectionH4 = dirH4;
      g_lastAIConfidenceH4 = confH4;
      
      ExtractTimeframeData(resp, "D1", dirD1, confD1);
      g_lastAIDirectionD1 = dirD1;
      g_lastAIConfidenceD1 = confD1;
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
   
   // NOUVELLE LOGIQUE: Fermer les positions en gain si la perte max est atteinte
   // SEULEMENT POUR BOOM/CRASH - pas pour forex ni volatility
   bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
   if(isBoomCrash)
   {
      CloseProfitablePositionsOnMaxLoss();
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
            
            // Si pas de SL/TP, les définir
            if(sl == 0 && tp == 0)
            {
               SetFixedSLTP(ticket);
            }
            
            // Pour Boom/Crash: Fermer après spike même avec petit gain (0.2$ minimum)
            bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
            if(isBoomCrash)
            {
               CloseBoomCrashAfterSpike(ticket, currentProfit);
            }
            
            // NOUVELLE LOGIQUE: Fermer les positions si le prix sort de la zone IA et entre en correction
            // SEULEMENT POUR BOOM/CRASH - pas pour forex ni volatility
            bool isBoomCrashCorrection = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
            if(isBoomCrashCorrection)
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
            
            // NOUVELLE LOGIQUE: Vérifier si l'IA change de recommandation et fermer la position si nécessaire
            // SEULEMENT POUR BOOM/CRASH - pas pour forex ni volatility
            bool isBoomCrashAI = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
            if(isBoomCrashAI)
            {
               ENUM_POSITION_TYPE posType = positionInfo.PositionType();
               CheckAndCloseOnAIRecommendationChange(ticket, posType, currentProfit);
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
      g_positionAIAction = ""; // Réinitialiser l'action IA qui a ouvert la position
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
         // Fermer si profit >= 0 ou perte <= 2$ (limiter les pertes)
         if(currentProfit >= 0 || currentProfit >= -2.0)
         {
            if(trade.PositionClose(ticket))
            {
               Print("✅ Position BUY fermée: Prix sorti de zone d'achat [", g_aiBuyZoneLow, "-", g_aiBuyZoneHigh, "] et correction détectée - Profit=", DoubleToString(currentProfit, 2), "$");
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
         // Fermer si profit >= 0 ou perte <= 2$
         if(currentProfit >= 0 || currentProfit >= -2.0)
         {
            if(trade.PositionClose(ticket))
            {
               Print("✅ Position SELL fermée: Prix sorti de zone de vente [", g_aiSellZoneLow, "-", g_aiSellZoneHigh, "] et correction détectée - Profit=", DoubleToString(currentProfit, 2), "$");
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
//| Vérifier et fermer position si recommandation IA change          |
//| Ferme si l'IA recommande "hold" ou change de direction          |
//+------------------------------------------------------------------+
void CheckAndCloseOnAIRecommendationChange(ulong ticket, int posType, double currentProfit)
{
   if(!UseAI_Agent || g_lastAIAction == "")
      return;
   
   // Vérifier si l'IA recommande de fermer (hold ou changement de direction)
   bool shouldClose = false;
   string closeReason = "";
   
   // Cas 1: L'IA recommande "hold" ou est vide
   if(g_lastAIAction == "hold" || g_lastAIAction == "")
   {
      shouldClose = true;
      closeReason = "IA recommande HOLD/ATTENTE";
   }
   // Cas 2: L'IA change de direction (BUY -> SELL ou SELL -> BUY)
   else if((posType == POSITION_TYPE_BUY && g_lastAIAction == "sell") ||
           (posType == POSITION_TYPE_SELL && g_lastAIAction == "buy"))
   {
      shouldClose = true;
      closeReason = "IA change de direction: " + (posType == POSITION_TYPE_BUY ? "BUY" : "SELL") + " -> " + g_lastAIAction;
   }
   // Cas 3: L'IA recommande la même direction mais avec confiance très faible (< 50%)
   else if(g_lastAIConfidence < 0.50)
   {
      shouldClose = true;
      closeReason = "Confiance IA trop faible (" + DoubleToString(g_lastAIConfidence * 100, 1) + "%)";
   }
   
   if(shouldClose)
   {
      // Ne fermer que si on a un profit ou une petite perte (éviter de fermer avec grosse perte)
      // Exception: si changement de direction, fermer même avec petite perte
      bool canClose = false;
      if((posType == POSITION_TYPE_BUY && g_lastAIAction == "sell") ||
         (posType == POSITION_TYPE_SELL && g_lastAIAction == "buy"))
      {
         // Changement de direction: fermer même avec perte jusqu'à -3$
         canClose = (currentProfit >= 0 || currentProfit >= -3.0);
      }
      else
      {
         // Hold ou faible confiance: fermer seulement si profit ou perte très petite
         canClose = (currentProfit >= 0 || currentProfit >= -1.0);
      }
      
      if(canClose)
   {
      if(trade.PositionClose(ticket))
      {
            Print("✅ Position fermée: ", closeReason, " - Profit=", DoubleToString(currentProfit, 2), "$");
            g_positionAIAction = ""; // Réinitialiser
         }
         else if(DebugMode)
         {
            Print("❌ Erreur fermeture position (changement IA): ", trade.ResultRetcodeDescription());
         }
      }
      else if(DebugMode)
      {
         Print("⏸️ Position conservée malgré ", closeReason, ": Perte trop importante (", DoubleToString(currentProfit, 2), "$) - Attendre SL/TP");
      }
   }
}

//+------------------------------------------------------------------+
//| Vérifier l'alignement M1/M5/H1 avec les EMA                      |
//| Retourne true si les 3 timeframes sont alignés dans la même direction |
//+------------------------------------------------------------------+
bool CheckM1M5H1Alignment(ENUM_ORDER_TYPE orderType)
{
   // Récupérer les EMA pour M1, M5 et H1
   double emaFastM1[], emaSlowM1[], emaFastM5[], emaSlowM5[], emaFastH1[], emaSlowH1[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   
   // Copier les valeurs EMA
   if(CopyBuffer(emaFastHandle, 0, 0, 1, emaFastM1) <= 0 ||
      CopyBuffer(emaSlowHandle, 0, 0, 1, emaSlowM1) <= 0 ||
      CopyBuffer(emaFastM5Handle, 0, 0, 1, emaFastM5) <= 0 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 1, emaSlowM5) <= 0 ||
      CopyBuffer(emaFastH1Handle, 0, 0, 1, emaFastH1) <= 0 ||
      CopyBuffer(emaSlowH1Handle, 0, 0, 1, emaSlowH1) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA M1/M5/H1 pour alignement");
      return false;
   }
   
   // Vérifier l'alignement pour BUY
   if(orderType == ORDER_TYPE_BUY)
   {
      bool m1Bullish = (emaFastM1[0] > emaSlowM1[0]);
      bool m5Bullish = (emaFastM5[0] > emaSlowM5[0]);
      bool h1Bullish = (emaFastH1[0] > emaSlowH1[0]);
      
      if(m1Bullish && m5Bullish && h1Bullish)
      {
         if(DebugMode)
            Print("✅ Alignement M1/M5/H1 haussier confirmé: M1=", m1Bullish ? "UP" : "DOWN", 
                  " M5=", m5Bullish ? "UP" : "DOWN", " H1=", h1Bullish ? "UP" : "DOWN");
         return true;
      }
      else
      {
         if(DebugMode)
            Print("❌ Alignement M1/M5/H1 haussier non confirmé: M1=", m1Bullish ? "UP" : "DOWN", 
                  " M5=", m5Bullish ? "UP" : "DOWN", " H1=", h1Bullish ? "UP" : "DOWN");
         return false;
      }
   }
   // Vérifier l'alignement pour SELL
   else if(orderType == ORDER_TYPE_SELL)
   {
      bool m1Bearish = (emaFastM1[0] < emaSlowM1[0]);
      bool m5Bearish = (emaFastM5[0] < emaSlowM5[0]);
      bool h1Bearish = (emaFastH1[0] < emaSlowH1[0]);
      
      if(m1Bearish && m5Bearish && h1Bearish)
      {
         if(DebugMode)
            Print("✅ Alignement M1/M5/H1 baissier confirmé: M1=", m1Bearish ? "DOWN" : "UP", 
                  " M5=", m5Bearish ? "DOWN" : "UP", " H1=", h1Bearish ? "DOWN" : "UP");
         return true;
      }
      else
      {
         if(DebugMode)
            Print("❌ Alignement M1/M5/H1 baissier non confirmé: M1=", m1Bearish ? "DOWN" : "UP", 
                  " M5=", m5Bearish ? "DOWN" : "UP", " H1=", h1Bearish ? "DOWN" : "UP");
         return false;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Détecter si le prix est dans une zone de compression/range      |
//| Retourne true si le marché est en range (pas de tendance claire) |
//+------------------------------------------------------------------+
bool IsInCompressionRange()
{
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
      return false; // En cas d'erreur, ne pas bloquer le trade
   }
   
   // Calculer la distance entre EMA rapide et lente pour chaque timeframe
   double distanceM1 = MathAbs(emaFastM1[0] - emaSlowM1[0]);
   double distanceM5 = MathAbs(emaFastM5[0] - emaSlowM5[0]);
   double distanceH1 = MathAbs(emaFastH1[0] - emaSlowH1[0]);
   
   // Récupérer le prix actuel
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculer la distance en points
   double distanceM1Points = distanceM1 / point;
   double distanceM5Points = distanceM5 / point;
   double distanceH1Points = distanceH1 / point;
   
   // Récupérer l'ATR pour avoir une référence de volatilité
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
   {
      double atrPoints = atr[0] / point;
      
      // Zone de compression détectée si:
      // 1. Les EMA sont très proches (< 30% de l'ATR) sur au moins 2 timeframes
      // 2. OU les EMA sont croisées (pas d'alignement clair)
      
      int compressionCount = 0;
      if(distanceM1Points < atrPoints * 0.3) compressionCount++;
      if(distanceM5Points < atrPoints * 0.3) compressionCount++;
      if(distanceH1Points < atrPoints * 0.3) compressionCount++;
      
      // Si au moins 2 timeframes sont en compression, c'est une zone de range
      if(compressionCount >= 2)
      {
         if(DebugMode)
            Print("⚠️ Zone de compression détectée: M1=", DoubleToString(distanceM1Points, 1), 
                  "pts M5=", DoubleToString(distanceM5Points, 1), "pts H1=", DoubleToString(distanceH1Points, 1), 
                  "pts (ATR=", DoubleToString(atrPoints, 1), "pts)");
         return true;
      }
      
      // Vérifier aussi si les EMA sont croisées (pas d'alignement clair)
      bool m1Aligned = (emaFastM1[0] > emaSlowM1[0]) || (emaFastM1[0] < emaSlowM1[0]);
      bool m5Aligned = (emaFastM5[0] > emaSlowM5[0]) || (emaFastM5[0] < emaSlowM5[0]);
      bool h1Aligned = (emaFastH1[0] > emaSlowH1[0]) || (emaFastH1[0] < emaSlowH1[0]);
      
      // Si les directions sont différentes entre les timeframes, c'est un range
      bool m1Bullish = (emaFastM1[0] > emaSlowM1[0]);
      bool m5Bullish = (emaFastM5[0] > emaSlowM5[0]);
      bool h1Bullish = (emaFastH1[0] > emaSlowH1[0]);
      
      if((m1Bullish != m5Bullish) || (m5Bullish != h1Bullish))
      {
         if(DebugMode)
            Print("⚠️ Zone de range détectée: Directions M1/M5/H1 non alignées (M1=", m1Bullish ? "UP" : "DOWN", 
                  " M5=", m5Bullish ? "UP" : "DOWN", " H1=", h1Bullish ? "UP" : "DOWN", ")");
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier l'entrée avec confirmation EMA                          |
//| Retourne true si le prix est proche de l'EMA et prêt pour entrée |
//+------------------------------------------------------------------+
bool CheckEMAEntryConfirmation(ENUM_ORDER_TYPE orderType)
{
   // Récupérer les EMA M1 (timeframe principal pour entrée)
   double emaFastM1[], emaSlowM1[];
   ArraySetAsSeries(emaFastM1, true);
   ArraySetAsSeries(emaSlowM1, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFastM1) <= 0 ||
      CopyBuffer(emaSlowHandle, 0, 0, 3, emaSlowM1) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA M1 pour confirmation entrée");
      return false;
   }
   
   double currentPrice = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Récupérer l'ATR pour calculer la distance acceptable
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) <= 0 || atr[0] <= 0)
   {
      return false;
   }
   
   double atrPoints = atr[0] / point;
   double maxDistancePoints = atrPoints * 0.5; // Distance maximale acceptable = 50% de l'ATR
   
   // Pour BUY: vérifier que le prix est proche ou au-dessus de l'EMA rapide
   if(orderType == ORDER_TYPE_BUY)
   {
      // Le prix doit être proche de l'EMA rapide (pas trop loin au-dessus)
      double distanceToEMA = currentPrice - emaFastM1[0];
      double distancePoints = MathAbs(distanceToEMA) / point;
      
      // Vérifier aussi que l'EMA rapide est au-dessus de l'EMA lente (tendance haussière)
      bool emaAligned = (emaFastM1[0] > emaSlowM1[0]);
      
      // Vérifier que le prix est en train de rebondir sur l'EMA (les dernières bougies)
      bool priceBouncing = false;
      if(distancePoints <= maxDistancePoints)
      {
         // Le prix est proche de l'EMA, vérifier le rebond
         // Si la bougie précédente était en dessous et maintenant on est au-dessus ou proche
         priceBouncing = true;
      }
      
      if(emaAligned && priceBouncing && distancePoints <= maxDistancePoints)
      {
         if(DebugMode)
            Print("✅ Confirmation entrée BUY: Prix proche EMA rapide (distance=", DoubleToString(distancePoints, 1), 
                  "pts < ", DoubleToString(maxDistancePoints, 1), "pts) et EMA alignée");
         return true;
      }
      else if(DebugMode)
      {
         Print("❌ Confirmation entrée BUY échouée: Distance=", DoubleToString(distancePoints, 1), 
               "pts EMA alignée=", emaAligned ? "OUI" : "NON");
      }
   }
   // Pour SELL: vérifier que le prix est proche ou en-dessous de l'EMA rapide
   else if(orderType == ORDER_TYPE_SELL)
   {
      // Le prix doit être proche de l'EMA rapide (pas trop loin en-dessous)
      double distanceToEMA = emaFastM1[0] - currentPrice;
      double distancePoints = MathAbs(distanceToEMA) / point;
      
      // Vérifier aussi que l'EMA rapide est en-dessous de l'EMA lente (tendance baissière)
      bool emaAligned = (emaFastM1[0] < emaSlowM1[0]);
      
      // Vérifier que le prix est en train de rebondir sur l'EMA (les dernières bougies)
      bool priceBouncing = false;
      if(distancePoints <= maxDistancePoints)
      {
         priceBouncing = true;
      }
      
      if(emaAligned && priceBouncing && distancePoints <= maxDistancePoints)
      {
         if(DebugMode)
            Print("✅ Confirmation entrée SELL: Prix proche EMA rapide (distance=", DoubleToString(distancePoints, 1), 
                  "pts < ", DoubleToString(maxDistancePoints, 1), "pts) et EMA alignée");
         return true;
      }
      else if(DebugMode)
      {
         Print("❌ Confirmation entrée SELL échouée: Distance=", DoubleToString(distancePoints, 1), 
               "pts EMA alignée=", emaAligned ? "OUI" : "NON");
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Fermer les positions Boom/Crash après spike (profit >= 0.2$)     |
//+------------------------------------------------------------------+
void CloseBoomCrashAfterSpike(ulong ticket, double currentProfit)
{
   if(!positionInfo.SelectByTicket(ticket))
      return;
   
   // Pour Boom/Crash: fermer immédiatement dès qu'on atteint le profit minimal configuré
   // (le spike est implicite dans l'ouverture de position)
   if(currentProfit >= BoomCrashSpikeTP)
   {
      if(trade.PositionClose(ticket))
      {
         Print("✅ Position Boom/Crash fermée après spike: Profit=", DoubleToString(currentProfit, 2),
               "$ (seuil BoomCrashSpikeTP=", DoubleToString(BoomCrashSpikeTP, 2), "$)");
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
//+------------------------------------------------------------------+
//| Calculer le lot total de toutes les positions du même type       |
//+------------------------------------------------------------------+
double GetTotalLotSizeForPositionType(ENUM_POSITION_TYPE posType)
{
   double totalLot = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Symbol() == _Symbol && 
            positionInfo.Magic() == InpMagicNumber &&
            positionInfo.PositionType() == posType)
         {
            totalLot += positionInfo.Volume();
         }
      }
   }
   
   return totalLot;
}

//+------------------------------------------------------------------+
//| Doubler le lot en ouvrant une nouvelle position                  |
//| Le lot total sera multiplié par 2 (lot actuel * 2)               |
//+------------------------------------------------------------------+
void DoublePositionLot(ulong ticket)
{
   if(!positionInfo.SelectByTicket(ticket))
      return;
   
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   
   // NOUVELLE LOGIQUE: Calculer le lot total actuel de toutes les positions du même type
   double currentTotalLot = GetTotalLotSizeForPositionType(posType);
   
   // Le nouveau lot total doit être le lot actuel multiplié par 2
   double newTotalLot = currentTotalLot * 2.0;
   
   // Calculer le volume à ajouter (nouveau total - lot actuel)
   double volumeToAdd = newTotalLot - currentTotalLot;
   
   // Vérifier la limite maximale (sur le nouveau lot total)
   if(newTotalLot > MaxLotSize)
   {
      if(DebugMode)
         Print("⚠️ Lot maximum atteint: ", MaxLotSize, " (lot total actuel: ", currentTotalLot, " -> nouveau total: ", newTotalLot, ")");
      return;
   }
   
   if(volumeToAdd <= 0)
   {
      if(DebugMode)
         Print("⚠️ Volume à ajouter invalide: ", volumeToAdd, " (lot actuel: ", currentTotalLot, ")");
      return;
   }
   
   // Vérifier le lot minimum et maximum du broker
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Normaliser le volume à ajouter
   volumeToAdd = NormalizeLotSize(volumeToAdd);
   
   // Vérifier que le nouveau lot total ne dépasse pas la limite du broker
   if(newTotalLot > maxLot)
   {
      volumeToAdd = maxLot - currentTotalLot;
      volumeToAdd = MathFloor(volumeToAdd / lotStep) * lotStep;
      if(volumeToAdd < minLot)
      {
         if(DebugMode)
            Print("⚠️ Impossible d'ajouter du volume: limite broker atteinte");
         return;
      }
   }
   
   if(volumeToAdd < minLot)
   {
      if(DebugMode)
         Print("⚠️ Volume à ajouter trop petit: ", volumeToAdd, " (minimum: ", minLot, ")");
      return;
   }
   
   // Ouvrir une nouvelle position dans le même sens
   ENUM_ORDER_TYPE orderType = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 
                              ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculer SL et TP en points pour la nouvelle position
   double sl, tp;
   // posType est déjà déclaré ligne 1560, réutiliser la variable existante
   CalculateSLTPInPoints(posType, price, sl, tp);
   
   if(trade.PositionOpen(_Symbol, orderType, volumeToAdd, price, sl, tp, "DOUBLE_LOT"))
   {
      // Mettre à jour le lot total dans le tracker
      double newTotalLotAfterAdd = GetTotalLotSizeForPositionType(posType);
      g_positionTracker.currentLot = newTotalLotAfterAdd;
      g_positionTracker.lotDoubled = true;
      
      Print("✅ Position dupliquée: Lot total ", DoubleToString(currentTotalLot, 2), " -> ", DoubleToString(newTotalLotAfterAdd, 2), 
            " (ajout: ", DoubleToString(volumeToAdd, 2), ")");
   }
   else
   {
      Print("❌ Erreur duplication position: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Définir SL/TP fixes en USD                                       |
//+------------------------------------------------------------------+
void SetFixedSLTP(ulong ticket)
{
   if(!positionInfo.SelectByTicket(ticket))
      return;
   
   double currentPrice = positionInfo.PriceCurrent();
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   
   double sl, tp;
   CalculateSLTPInPoints(posType, currentPrice, sl, tp);
   
   if(trade.PositionModify(ticket, sl, tp))
   {
      if(DebugMode)
         Print("✅ SL/TP définis: SL=", sl, " TP=", tp);
   }
   else
   {
      if(DebugMode)
         Print("⚠️ Erreur modification SL/TP: ", trade.ResultRetcode());
   }
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
   
   // Vérifier les niveaux minimums du broker
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * point;
   
   if(MathAbs(entryPrice - sl) < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         sl = NormalizeDouble(entryPrice - minDistance - point, _Digits);
      else
         sl = NormalizeDouble(entryPrice + minDistance + point, _Digits);
   }
   
   if(MathAbs(tp - entryPrice) < minDistance)
   {
      if(posType == POSITION_TYPE_BUY)
         tp = NormalizeDouble(entryPrice + minDistance + point, _Digits);
      else
         tp = NormalizeDouble(entryPrice - minDistance - point, _Digits);
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
   
   // Vérifier les distances minimum
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopLevel * point;
   
   if(MathAbs(entryPrice - sl) < minDistance)
   {
      if(DebugMode)
         Print("❌ Distance SL insuffisante pour US Session");
      return false;
   }
   if(MathAbs(tp - entryPrice) < minDistance)
   {
      if(DebugMode)
         Print("❌ Distance TP insuffisante pour US Session");
      return false;
   }
   
   if(trade.PositionOpen(_Symbol, orderType, normalizedLot, entryPrice, sl, tp, "US_SESSION_BREAK_RETEST"))
   {
      if(DebugMode)
         Print("✅ Trade US Session ouvert: ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " Lot=", normalizedLot, " Entry=", entryPrice, " SL=", sl, " TP=", tp);
      return true;
   }
   else
   {
      if(DebugMode)
         Print("❌ Erreur ouverture trade US Session: ", trade.ResultRetcodeDescription());
      return false;
   }
}

//| Chercher une opportunité de trading                              |
//+------------------------------------------------------------------+
void LookForTradingOpportunity()
{
   // PROTECTION: Vérifier la perte totale maximale (5$ toutes positions)
   // Si perte >= 5$, attendre que la perte descende avant de reprendre les trades
   double totalLoss = GetTotalLoss();
   if(totalLoss >= MaxTotalLoss)
   {
      if(DebugMode)
         Print("⏸️ TRADES EN PAUSE: Perte totale maximale atteinte (", DoubleToString(totalLoss, 2), "$ >= ", DoubleToString(MaxTotalLoss, 2), "$) - En attente de réduction des pertes");
      return;
   }
   
   // Déclarer signalType et hasSignal au début de la fonction pour qu'ils soient accessibles partout
   static ENUM_ORDER_TYPE signalType = WRONG_VALUE;
   bool hasSignal = false;
   
   // Initialize signalType to a default value
   signalType = WRONG_VALUE;
   
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
   
   
   // NOUVELLE LOGIQUE: Détecter le mode prudent (profit journalier élevé)
   // Activer le mode prudent pour protéger les gains quand on approche du profit max
   double cautiousModeThreshold = MaxDailyProfit * CautiousModeProfitThreshold;
   bool cautiousMode = (g_dailyProfit >= cautiousModeThreshold);
   
   // Calculer la confiance requise en fonction du type d'actif
   double requiredConfidence = AI_MinConfidence; // Par défaut 80%
   bool isForex = IsForexSymbol(_Symbol);
   
   // Ajuster la confiance minimale pour le forex
   if(isForex)
   {
      requiredConfidence = 0.66; // 66% pour le forex
   }
   else if(cautiousMode)
   {
      requiredConfidence = 0.95; // 95% en mode prudent pour les autres actifs
   }
   
   if(cautiousMode && DebugMode)
      Print("⚠️ MODE PRUDENT: Profit journalier ", DoubleToString(g_dailyProfit, 2), " USD (seuil: ", DoubleToString(cautiousModeThreshold, 2), " USD) - Confiance requise: ", DoubleToString(requiredConfidence * 100, 1), "%", isForex ? " [FOREX]" : "");
   
   // RÈGLE STRICTE : Si l'IA est activée, TOUJOURS vérifier la confiance AVANT de trader
   if(UseAI_Agent)
   {
      // Si l'IA a une recommandation mais confiance insuffisante, BLOQUER
      if(g_lastAIAction != "" && g_lastAIAction != "hold" && g_lastAIConfidence < requiredConfidence)
      {
         if(DebugMode)
            Print("🚫 TRADE BLOQUÉ: IA recommande ", g_lastAIAction, " mais confiance insuffisante (", DoubleToString(g_lastAIConfidence * 100, 1), "% < ", DoubleToString(requiredConfidence * 100, 1), "%)", cautiousMode ? " [MODE PRUDENT]" : "");
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
         
         // VÉRIFIER L'ALIGNEMENT DE TENDANCE M1/M5/H1 AVANT DE TRADER
         // Utiliser les données IA enrichies si disponibles, sinon calculer localement
         if(signalType != WRONG_VALUE)
         {
            // NOUVELLE VÉRIFICATION: Éviter les zones de compression/range
            if(IsInCompressionRange())
            {
               if(DebugMode)
                  Print("⏸️ Signal IA ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " rejeté - Zone de compression/range détectée");
               return; // Ne pas trader dans les zones de compression
            }
            
            bool alignmentOK = false;
            
            // PRIORITÉ: Utiliser les données IA enrichies si disponibles et récentes (< 30 secondes)
            if(g_lastAITime > 0 && (TimeCurrent() - g_lastAITime) < 30)
            {
               // Utiliser m5_h1_alignment_ok de l'IA si disponible
               if(g_lastAIM5H1Alignment)
               {
                  // Vérifier aussi que la direction correspond au signal
                  bool directionMatch = false;
                  if(signalType == ORDER_TYPE_BUY)
                     directionMatch = (g_lastAIDirectionM5 == "bullish" && g_lastAIDirectionH1 == "bullish");
                  else if(signalType == ORDER_TYPE_SELL)
                     directionMatch = (g_lastAIDirectionM5 == "bearish" && g_lastAIDirectionH1 == "bearish");
                  
                  if(directionMatch)
                  {
                     // Vérifier aussi l'alignement M1 (nouvelle exigence)
                     alignmentOK = CheckM1M5H1Alignment(signalType);
                     if(alignmentOK && DebugMode)
                     {
                        ENUM_ORDER_TYPE orderType = signalType; // Use signalType which should be of type ENUM_ORDER_TYPE
                        if(orderType != WRONG_VALUE) 
                        {
                           Print("✅ Alignement M1/M5/H1 confirmé par IA pour ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), ": M5=", g_lastAIDirectionM5, " H1=", g_lastAIDirectionH1, 
                                 " | TF alignés: ", IntegerToString(g_lastAIBullishTFs), "↑/", IntegerToString(g_lastAIBearishTFs), "↓");
                        } 
                        else 
                        {
                           Print("✅ Alignement M1/M5/H1 confirmé par IA: M5=", g_lastAIDirectionM5, " H1=", g_lastAIDirectionH1, 
                                 " | TF alignés: ", IntegerToString(g_lastAIBullishTFs), "↑/", IntegerToString(g_lastAIBearishTFs), "↓");
                        }
                     }
                  }
                  else
                  {
                     if(DebugMode)
                        Print("⏸️ Signal IA ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " rejeté - Alignement M5/H1 OK mais direction ne correspond pas (M5=", g_lastAIDirectionM5, " H1=", g_lastAIDirectionH1, ")");
                  }
               }
               else
               {
                  // Si l'IA dit que l'alignement n'est pas OK, utiliser le calcul local comme fallback
                  alignmentOK = CheckM1M5H1Alignment(signalType);
                  if(!alignmentOK && DebugMode)
                     Print("⏸️ Signal IA ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " rejeté - Alignement M1/M5/H1 non confirmé par IA");
               }
            }
            else
            {
               // Données IA trop anciennes ou indisponibles, utiliser le calcul local avec M1/M5/H1
               alignmentOK = CheckM1M5H1Alignment(signalType);
            }
            
            if(alignmentOK)
            {
               // NOUVELLE LOGIQUE: Vérifier que le prix est dans la zone IA avec confirmation EMA
               // Évite de trader les corrections
               bool isInZone = false;
               bool emaConfirmed = false;
               bool isCorrection = false;
               
               // NOUVELLE VÉRIFICATION: Confirmation entrée avec EMA
               bool emaEntryOK = CheckEMAEntryConfirmation(signalType);
               if(!emaEntryOK)
               {
                  if(DebugMode)
                     Print("⏸️ Signal IA ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " rejeté - Confirmation entrée EMA non validée");
                  return; // Ne pas trader sans confirmation EMA
               }
               
               // Appeler la fonction qui modifie les variables par référence
               bool zoneEntryOK = CheckAIZoneEntryWithEMA(signalType, isInZone, emaConfirmed, isCorrection);
               
               if(zoneEntryOK)
               {
                  // Vérifications supplémentaires en mode prudent
                  if(cautiousMode)
                  {
                     // En mode prudent, vérifier le prix actuel
                     double currentPrice = (signalType == ORDER_TYPE_BUY) ? 
                                          SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                                          SymbolInfoDouble(_Symbol, SYMBOL_BID);
                     
                     if(DebugMode)
                        Print("✅ Mode prudent - Vérification du prix: ", DoubleToString(currentPrice, _Digits));
                  }
                  
                  // VÉRIFICATIONS SUPPLÉMENTAIRES AVEC DONNÉES IA ENRICHIES
                  // Utiliser asset_class pour adapter la stratégie
                  bool assetClassOK = true;
                  int totalTFs = g_lastAIBullishTFs + g_lastAIBearishTFs;
                  
                  if(g_lastAIAssetClass == "boom_crash" || g_lastAIAssetClass == "volatility")
                  {
                     // Pour Boom/Crash et Volatility, être plus strict sur le nombre de TF alignés
                     int minTFs = cautiousMode ? 4 : 3; // En mode prudent, nécessiter 4 TF au lieu de 3
                     if(totalTFs < minTFs)
                     {
                        assetClassOK = false;
                        if(DebugMode)
                           Print("⏸️ Signal ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " rejeté - Asset class ", g_lastAIAssetClass, " nécessite au moins ", IntegerToString(minTFs), " TF alignés (actuel: ", IntegerToString(totalTFs), ")", cautiousMode ? " [MODE PRUDENT]" : "");
                     }
                  }
                  else
                  {
                     // Pour les autres actifs, en mode prudent, nécessiter au moins 3 TF alignés
                     if(cautiousMode && totalTFs < 3)
                     {
                        assetClassOK = false;
                        if(DebugMode)
                           Print("⏸️ Signal ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " rejeté - Mode prudent nécessite au moins 3 TF alignés (actuel: ", IntegerToString(totalTFs), ")");
                     }
                  }
                  
                  // Utiliser trading_hour_score pour filtrer les heures interdites
                  // En mode prudent, être encore plus strict sur les heures
                  bool hourOK = true;
                  double hourThreshold = cautiousMode ? 0.0 : -0.15; // En mode prudent, accepter seulement les heures préférées (score >= 0)
                  if(g_lastAITradingHourScore < hourThreshold)
                  {
                     hourOK = false;
                     if(DebugMode)
                        Print("⏸️ Signal ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " rejeté - Heure de trading défavorable (score: ", DoubleToString(g_lastAITradingHourScore, 2), " < ", DoubleToString(hourThreshold, 2), ")", cautiousMode ? " [MODE PRUDENT]" : "");
                  }
                  
                  // Utiliser raw_score pour valider la force du signal
                  // En mode prudent, nécessiter un score brut plus élevé
                  bool rawScoreOK = true;
                  double minRawScore = cautiousMode ? 0.30 : 0.15; // En mode prudent, nécessiter score >= 0.30 au lieu de 0.15
                  if(MathAbs(g_lastAIRawScore) < minRawScore)
                  {
                     rawScoreOK = false;
                     if(DebugMode)
                        Print("⏸️ Signal ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " rejeté - Score brut trop faible (", DoubleToString(g_lastAIRawScore, 2), " < ", DoubleToString(minRawScore, 2), ")", cautiousMode ? " [MODE PRUDENT]" : "");
                  }
                  
                  // VÉRIFICATION SUPPLÉMENTAIRE EN MODE PRUDENT: Alignement M1/M5/H1 obligatoire
                  bool m1m5h1AlignmentOK = true;
                  if(cautiousMode)
                  {
                     m1m5h1AlignmentOK = CheckM1M5H1Alignment(signalType);
                     if(!m1m5h1AlignmentOK && DebugMode)
                        Print("⏸️ Signal ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " rejeté - Alignement M1/M5/H1 non confirmé [MODE PRUDENT]");
                  }
                  
                  if(assetClassOK && hourOK && rawScoreOK && m1m5h1AlignmentOK)
                  {
                     hasSignal = true;
                     // signalType already contains the correct value
                     
                     if(DebugMode)
                     {
                        string assetInfo = g_lastAIAssetClass != "" ? " | Asset: " + g_lastAIAssetClass : "";
                        string hourInfo = g_lastAITradingHourScore != 0.0 ? " | Hour score: " + DoubleToString(g_lastAITradingHourScore, 2) : "";
                        Print("✅ Signal ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " basé sur recommandation IA (confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), 
                              "% | Score brut: ", DoubleToString(g_lastAIRawScore, 2), 
                              " | TF: ", IntegerToString(g_lastAIBullishTFs), "↑/", IntegerToString(g_lastAIBearishTFs), "↓",
                              assetInfo, hourInfo, ") - Prix dans zone IA + EMA M5 confirmé + Pas de correction", cautiousMode ? " [MODE PRUDENT]" : "");
                     }
                  }
                  else if(DebugMode)
                  {
                     Print("⏸️ Signal ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " rejeté - Critères enrichis non satisfaits (AssetClass: ", assetClassOK ? "OK" : "KO", 
                           " | Hour: ", hourOK ? "OK" : "KO", " | RawScore: ", rawScoreOK ? "OK" : "KO",
                           " | M1/M5/H1: ", m1m5h1AlignmentOK ? "OK" : "KO", ")", cautiousMode ? " [MODE PRUDENT]" : "");
                  }

                  // S'assurer que signalType est initialisé (évite l'erreur de compilation)
                  if(signalType == WRONG_VALUE)
                  {
                     if(g_lastAIAction == "buy")
                        signalType = ORDER_TYPE_BUY;
                     else if(g_lastAIAction == "sell")
                        signalType = ORDER_TYPE_SELL;
                     else
                        signalType = ORDER_TYPE_BUY; // Valeur par défaut
                  }

                  // SPIKE Boom/Crash : si confiance élevée et conditions EMA M5, tenter entrée rapide
                  if(IsBoomCrashSymbol(_Symbol) && g_lastAIConfidence >= 0.80)
                  {
                     // Ensure signalType is properly initialized before use
                     if(signalType == ORDER_TYPE_BUY || signalType == ORDER_TYPE_SELL)
                     {
                        if(TrySpikeEntry(signalType))
                        {
                           if(DebugMode)
                              Print("✅ Tentative d'entrée spike ", (signalType == ORDER_TYPE_BUY ? "BUY" : "SELL"));
                           return; // spike tenté, ne pas poursuivre
                        }
                     }
                  }
                  return; // Conditions non remplies, ne pas trader
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
      StringFind(symbol, "CHF") != -1 || StringFind(symbol, "NZD") != -1 ||
      StringFind(symbol, "XAU") != -1 || StringFind(symbol, "XAG") != -1)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si le symbole est un indice                              |
//+------------------------------------------------------------------+
bool IsIndexSymbol(string symbol)
{
   return (StringFind(symbol, "Volatility") != -1 || 
           StringFind(symbol, "Step Index") != -1 ||
           StringFind(symbol, "Boom") != -1 ||
           StringFind(symbol, "Crash") != -1);
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
   // Vérifier si la confiance est suffisante pour la duplication
   if(g_lastAIConfidence < 0.75) // 75% de confiance minimale pour la duplication
      return false;
      
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
//| Fermer les positions en gain quand la perte max est atteinte      |
//+------------------------------------------------------------------+
void CloseProfitablePositionsOnMaxLoss()
{
   double totalLoss = GetTotalLoss();
   
   // Vérifier si la perte max est atteinte
   if(totalLoss < MaxTotalLoss)
      return; // Pas encore à la limite
   
   if(DebugMode)
      Print("⚠️ Perte maximale atteinte (", DoubleToString(totalLoss, 2), "$ >= ", DoubleToString(MaxTotalLoss, 2), "$) - Fermeture des positions en gain");
   
   // Fermer toutes les positions en gain pour limiter les pertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
         {
            double profit = positionInfo.Profit();
            
            // Fermer uniquement les positions en gain
            if(profit > 0)
            {
               if(trade.PositionClose(ticket))
               {
                  Print("✅ Position en gain fermée (perte max atteinte): Profit=", DoubleToString(profit, 2), "$");
               }
               else if(DebugMode)
               {
                  Print("❌ Erreur fermeture position en gain: ", trade.ResultRetcodeDescription());
               }
            }
         }
      }
   }
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
   
   // PROTECTION: Bloquer SELL sur Boom et BUY sur Crash
   bool isBoom = (StringFind(_Symbol, "Boom") != -1);
   bool isCrash = (StringFind(_Symbol, "Crash") != -1);
   
   if(isBoom && orderType == ORDER_TYPE_SELL)
   {
      Print("🚫 TRADE BLOQUÉ: Impossible de trader SELL sur ", _Symbol, " (Boom = BUY uniquement)");
      return;
   }
   
   if(isCrash && orderType == ORDER_TYPE_BUY)
   {
      Print("🚫 TRADE BLOQUÉ: Impossible de trader BUY sur ", _Symbol, " (Crash = SELL uniquement)");
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
   
   // Éviter la duplication de la même position (uniquement pour volatility, step index et forex)
   if(HasDuplicatePosition(orderType))
   {
      Print("🚫 Trade ignoré - Position ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"), " déjà ouverte sur ", _Symbol, " - Évite la duplication");
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
      
      // Sauvegarder l'action IA qui a ouvert cette position
      g_positionAIAction = g_lastAIAction;
   }
   else
   {
      Print("❌ Erreur ouverture trade: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Vérifie l'alignement entre deux timeframes                       |
//+------------------------------------------------------------------+
bool CheckTimeframeAlignment(ENUM_ORDER_TYPE orderType, ENUM_TIMEFRAMES tf1, ENUM_TIMEFRAMES tf2)
{
   double emaFast1[], emaSlow1[], emaFast2[], emaSlow2[];
   ArraySetAsSeries(emaFast1, true);
   ArraySetAsSeries(emaSlow1, true);
   ArraySetAsSeries(emaFast2, true);
   ArraySetAsSeries(emaSlow2, true);
   
   // Récupérer les EMA pour le premier timeframe
   int emaFast1Handle = iMA(_Symbol, tf1, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   int emaSlow1Handle = iMA(_Symbol, tf1, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   // Récupérer les EMA pour le deuxième timeframe
   int emaFast2Handle = iMA(_Symbol, tf2, EMA_Fast_Period, 0, MODE_EMA, PRICE_CLOSE);
   int emaSlow2Handle = iMA(_Symbol, tf2, EMA_Slow_Period, 0, MODE_EMA, PRICE_CLOSE);
   
   // Copier les données
   if(CopyBuffer(emaFast1Handle, 0, 0, 3, emaFast1) <= 0 ||
      CopyBuffer(emaSlow1Handle, 0, 0, 3, emaSlow1) <= 0 ||
      CopyBuffer(emaFast2Handle, 0, 0, 3, emaFast2) <= 0 ||
      CopyBuffer(emaSlow2Handle, 0, 0, 3, emaSlow2) <= 0)
   {
      if(DebugMode)
         Print("Erreur lors de la récupération des données EMA");
      return false;
   }
   
   // Vérifier l'alignement pour un ordre d'achat
   if(orderType == ORDER_TYPE_BUY)
   {
      return (emaFast1[0] > emaSlow1[0] && emaFast2[0] > emaSlow2[0]);
   }
   // Vérifier l'alignement pour un ordre de vente
   else if(orderType == ORDER_TYPE_SELL)
   {
      return (emaFast1[0] < emaSlow1[0] && emaFast2[0] < emaSlow2[0]);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Vérifier l'alignement de tendance M5 et H1                       |
//+------------------------------------------------------------------+
bool CheckTrendAlignment(ENUM_ORDER_TYPE orderType)
{
   // Pour le forex, on accepte soit M5/H1 alignés, soit M5/M30 alignés
   if(IsForexSymbol(_Symbol))
   {
      // Vérifier si M5 et M30 sont alignés
      bool m5m30Aligned = CheckTimeframeAlignment(orderType, PERIOD_M5, PERIOD_M30);
      if(m5m30Aligned)
         return true;
         
      // Vérifier si M5 et H1 sont alignés
      bool m5h1Aligned = CheckTimeframeAlignment(orderType, PERIOD_M5, PERIOD_H1);
      if(m5h1Aligned)
         return true;
         
      return false;
   }
   // Pour les autres actifs, on garde la vérification stricte M5/H1
   else
   {
      return CheckTimeframeAlignment(orderType, PERIOD_M5, PERIOD_H1);
   }
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
//| Convertit une direction de tendance en abréviation               |
//+------------------------------------------------------------------+
string GetTrendAbbreviation(string direction)
{
   if(direction == "up") return "↑";
   if(direction == "down") return "↓";
   if(direction == "sideways") return "→";
   return "-";
}

//+------------------------------------------------------------------+
//| Formate le texte d'un timeframe pour l'affichage                 |
//+------------------------------------------------------------------+
string FormatTimeframeText(string tf, string dir, double conf) 
{
   if(dir == "" || conf <= 0) return ""; // Ne pas afficher si pas de données
   return StringFormat("%s:%s %.0f%%", tf, GetTrendAbbreviation(dir), conf * 100);
}

//+------------------------------------------------------------------+
//| Dessiner les zones BUY/SELL de l'IA                              |
//+------------------------------------------------------------------+
void DrawAIZonesOnChart()
{
   datetime now = TimeCurrent();
   datetime past = now - 24 * 60 * 60;   // historique 24h
   datetime future = now + 24 * 60 * 60;  // projection 24h
   
   // Zone BUY
   string buyZoneName = "AI_BUY_ZONE_" + _Symbol;
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
      
      ObjectSetInteger(0, buyZoneName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, buyZoneName, OBJPROP_BACK, true);
      ObjectSetInteger(0, buyZoneName, OBJPROP_FILL, true);
      ObjectSetInteger(0, buyZoneName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, buyZoneName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, buyZoneName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, buyZoneName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      
      // Label BUY
      string buyLabelName = "AI_BUY_LABEL_" + _Symbol;
      double labelPrice = (g_aiBuyZoneLow + g_aiBuyZoneHigh) / 2.0;
      if(ObjectFind(0, buyLabelName) < 0)
         ObjectCreate(0, buyLabelName, OBJ_TEXT, 0, now - 1800, labelPrice);
      else
         ObjectMove(0, buyLabelName, 0, now - 1800, labelPrice);
      ObjectSetString(0, buyLabelName, OBJPROP_TEXT, "ZONE ACHAT IA");
      ObjectSetInteger(0, buyLabelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, buyLabelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, buyLabelName, OBJPROP_FONT, "Arial Bold");
   }
   
   // Zone SELL
   string sellZoneName = "AI_SELL_ZONE_" + _Symbol;
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
      
      ObjectSetInteger(0, sellZoneName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, sellZoneName, OBJPROP_BACK, true);
      ObjectSetInteger(0, sellZoneName, OBJPROP_FILL, true);
      ObjectSetInteger(0, sellZoneName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, sellZoneName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, sellZoneName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, sellZoneName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      
      // Label SELL
      string sellLabelName = "AI_SELL_LABEL_" + _Symbol;
      double labelPrice = (g_aiSellZoneLow + g_aiSellZoneHigh) / 2.0;
      if(ObjectFind(0, sellLabelName) < 0)
         ObjectCreate(0, sellLabelName, OBJ_TEXT, 0, now - 1800, labelPrice);
      else
         ObjectMove(0, sellLabelName, 0, now - 1800, labelPrice);
      ObjectSetString(0, sellLabelName, OBJPROP_TEXT, "ZONE VENTE IA");
      ObjectSetInteger(0, sellLabelName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, sellLabelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, sellLabelName, OBJPROP_FONT, "Arial Bold");
   }
   
   // Label de recommandation IA
   string aiLabelName = "AI_Recommendation_" + _Symbol;
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
      aiText += "ATTENTE";
   
   ObjectSetString(0, aiLabelName, OBJPROP_TEXT, aiText);
   ObjectSetInteger(0, aiLabelName, OBJPROP_COLOR, (g_lastAIAction == "buy") ? clrLime : (g_lastAIAction == "sell") ? clrRed : clrYellow);
   ObjectSetInteger(0, aiLabelName, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, aiLabelName, OBJPROP_FONT, "Arial Bold");
   
   // Afficher les tendances par timeframe avec confiances
   string trendLabelName = "AI_Trends_" + _Symbol;
   if(ObjectFind(0, trendLabelName) < 0)
      ObjectCreate(0, trendLabelName, OBJ_LABEL, 0, 0, 0);
   
   ObjectSetInteger(0, trendLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, trendLabelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, trendLabelName, OBJPROP_YDISTANCE, 50);
   
   // Construire le texte des tendances
   string trendText = "Tendance: ";
   
   // Déterminer la tendance globale basée sur les directions
   string globalTrend = "NEUTRE";
   color trendColor = clrGray;
   
   if(g_lastAIAction == "buy")
   {
      globalTrend = "HAUSSIÈRE";
      trendColor = clrLime;
   }
   else if(g_lastAIAction == "sell")
   {
      globalTrend = "BAISSIÈRE";
      trendColor = clrRed;
   }
   
   trendText += globalTrend + " | Confiance: " + DoubleToString(g_lastAIConfidence * 100, 0) + "%\n";
   
   string timeframeTexts[];
   ArrayResize(timeframeTexts, 6); // M1, M5, H1, M30, H4, D1

   // Récupérer les textes pour chaque timeframe
   timeframeTexts[0] = FormatTimeframeText("M1", g_lastAIDirectionM1, g_lastAIConfidenceM1);
   timeframeTexts[1] = FormatTimeframeText("M5", g_lastAIDirectionM5, g_lastAIConfidenceM5);
   timeframeTexts[2] = FormatTimeframeText("H1", g_lastAIDirectionH1, g_lastAIConfidenceH1);
   timeframeTexts[3] = FormatTimeframeText("M30", g_lastAIDirectionM30, g_lastAIConfidenceM30);
   timeframeTexts[4] = FormatTimeframeText("H4", g_lastAIDirectionH4, g_lastAIConfidenceH4);
   timeframeTexts[5] = FormatTimeframeText("D1", g_lastAIDirectionD1, g_lastAIConfidenceD1);

   // Compter les timeframes valides
   int validTimeframes = 0;
   for(int i = 0; i < ArraySize(timeframeTexts); i++) {
       if(timeframeTexts[i] != "") validTimeframes++;
   }

   // Construire le texte final avec les timeframes valides
   if(validTimeframes > 0) {
       int count = 0;
       string line1 = "";
       string line2 = "";
       
       // Première ligne (M1, M5, H1)
       for(int i = 0; i < 3 && i < ArraySize(timeframeTexts); i++) {
           if(timeframeTexts[i] != "") {
               if(count > 0) line1 += " | ";
               line1 += timeframeTexts[i];
               count++;
           }
       }
       
       // Deuxième ligne (M30, H4, D1)
       count = 0;
       for(int i = 3; i < ArraySize(timeframeTexts); i++) {
           if(timeframeTexts[i] != "") {
               if(count > 0) line2 += " | ";
               line2 += timeframeTexts[i];
               count++;
           }
       }
       
       // Ajouter les lignes au texte final
       if(line1 != "") trendText += line1;
       if(line2 != "") {
           if(line1 != "") trendText += "\n";
           trendText += line2;
       }
   }
   
   ObjectSetString(0, trendLabelName, OBJPROP_TEXT, trendText);
   ObjectSetInteger(0, trendLabelName, OBJPROP_COLOR, trendColor);
   ObjectSetInteger(0, trendLabelName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, trendLabelName, OBJPROP_FONT, "Arial");
}

//+------------------------------------------------------------------+
//| Dessiner les trendlines basées sur les EMA M5 et H1              |
//| Depuis l'historique de 1000 bougies                              |
//+------------------------------------------------------------------+
void DrawTrendlinesOnChart()
{
   if(!DrawTrendlines)
      return;
   
   // Récupérer les bougies d'historique pour M5 (vérifier la disponibilité)
   double emaFastM5[], emaSlowM5[];
   datetime timeM5[];
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   ArraySetAsSeries(timeM5, true);
   
   // Limiter à 500 bougies pour éviter les erreurs si l'historique est limité
   int countM5 = 500;
   int availableM5 = Bars(_Symbol, PERIOD_M5);
   if(availableM5 > 0 && availableM5 < countM5)
      countM5 = availableM5;
   
   if(countM5 < 10) // Minimum 10 bougies nécessaires
   {
      if(DebugMode)
         Print("⚠️ Pas assez d'historique M5 disponible: ", countM5);
      return;
   }
   
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
   
   // Récupérer les bougies d'historique pour H1 (vérifier la disponibilité)
   double emaFastH1[], emaSlowH1[];
   datetime timeH1[];
   ArraySetAsSeries(emaFastH1, true);
   ArraySetAsSeries(emaSlowH1, true);
   ArraySetAsSeries(timeH1, true);
   
   // Limiter à 500 bougies pour éviter les erreurs
   int countH1 = 500;
   int availableH1 = Bars(_Symbol, PERIOD_H1);
   if(availableH1 > 0 && availableH1 < countH1)
      countH1 = availableH1;
   
   if(countH1 < 10) // Minimum 10 bougies nécessaires
   {
      if(DebugMode)
         Print("⚠️ Pas assez d'historique H1 disponible: ", countH1);
      return;
   }
   
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
      // Limiter le nettoyage pour éviter les boucles infinies
      int maxCleanup = MathMin(total, 100);
      for(int i = maxCleanup - 1; i >= 0; i--)
      {
         string name = ObjectName(0, i);
         if(StringLen(name) > 0 && StringFind(name, prefix) == 0 && StringFind(name, "DERIV_ARROW_" + _Symbol) < 0)
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
   
   // Faire clignoter la flèche (changement de visibilité toutes les 1 secondes)
   static datetime lastBlinkTime = 0;
   static bool blinkState = false;
   
   if(TimeCurrent() - lastBlinkTime >= 1)
   {
      blinkState = !blinkState;
      lastBlinkTime = TimeCurrent();
      
      // Toggle visibility pour créer l'effet de clignotement
      ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, blinkState ? true : false);
      
      // Mettre à jour la position pour suivre la dernière bougie
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, rates) > 0 && ArraySize(rates) > 0)
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
//| Sécurisation dynamique des profits                                |
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
               
               // Fermer dès que le profit atteint le seuil rapide
               if(profit >= VolatilityQuickTP)
               {
                  if(trade.PositionClose(ticket))
                  {
                     Print("✅ Volatility: Position fermée à TP rapide ", DoubleToString(VolatilityQuickTP, 2),
                           "$ (profit=", DoubleToString(profit, 2), "$) - Prise de gain rapide, prêt à se replacer si le mouvement continue");
                  }
                  else if(DebugMode)
                  {
                     Print("❌ Erreur fermeture position Volatility: ", trade.ResultRetcodeDescription());
                  }
               }
            }
         }
      }
   }
   
   // 1. SÉCURISATION DES GAINS POUR FOREX UNIQUEMENT
   // Sécuriser au moins 50% des gains dès que le profit atteint 2$
   bool isForex = IsForexSymbol(_Symbol);
   if(isForex)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && positionInfo.SelectByTicket(ticket))
         {
            if(positionInfo.Symbol() == _Symbol && positionInfo.Magic() == InpMagicNumber)
            {
               double profit = positionInfo.Profit();
               
               // Sécuriser dès que le profit atteint 2$
               if(profit >= 2.0)
               {
                  double maxProfitForPosition = GetMaxProfitForPosition(ticket);
                  if(maxProfitForPosition == 0.0 && profit > 0)
                     maxProfitForPosition = profit; // Utiliser le profit actuel comme référence initiale
                  
                  // Si la position est en profit, sécuriser au moins 50% des gains
                  if(profit > 0 && maxProfitForPosition > 0)
                  {
                     // Calculer le profit à sécuriser (50% du profit max atteint)
                     double profitToSecure = maxProfitForPosition * 0.5; // 50% du profit max
                     
                     // Convertir le profit en points pour calculer le nouveau TP
                     double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                     double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                     double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                     double pointsToSecure = (profitToSecure * tickSize) / (tickValue * point);
                     
                     // Récupérer les prix pour calculer le nouveau TP
                     double openPrice = positionInfo.PriceOpen();
                     double currentPrice = positionInfo.PriceCurrent();
                     double currentSL = positionInfo.StopLoss();
                     double currentTP = positionInfo.TakeProfit();
                     ENUM_POSITION_TYPE posType = positionInfo.PositionType();
                     
                     // Calculer le nouveau TP pour sécuriser 50% des gains
                     double newTP = 0.0;
                     if(posType == POSITION_TYPE_BUY)
                     {
                        // Pour BUY: TP = prix d'ouverture + points pour sécuriser 50% des gains
                        newTP = openPrice + pointsToSecure;
                     }
                     else if(posType == POSITION_TYPE_SELL)
                     {
                        // Pour SELL: TP = prix d'ouverture - points pour sécuriser 50% des gains
                        newTP = openPrice - pointsToSecure;
                     }
                     
                     if(trade.PositionModify(ticket, currentSL, newTP))
                     {
                        if(DebugMode)
                           Print("🔒 Forex: TP sécurisé pour 50% des gains: Ticket=", ticket, 
                                 " Profit max=", DoubleToString(maxProfitForPosition, 2), "$",
                                 " Profit à sécuriser=", DoubleToString(profitToSecure, 2), "$",
                                 " TP: ", DoubleToString(currentTP, _Digits), " -> ", DoubleToString(newTP, _Digits));
                        
                        // Calculer et déplacer le Stop Loss au seuil de rentabilité
                        double newSL = 0.0;
                        if(posType == POSITION_TYPE_BUY)
                        {
                           // Pour BUY: SL légèrement en dessous du prix d'ouverture (seuil de rentabilité)
                           newSL = openPrice - (10 * _Point);  // 10 points en dessous pour éviter les faux déclenchements
                        }
                        else if(posType == POSITION_TYPE_SELL)
                        {
                           // Pour SELL: SL légèrement au-dessus du prix d'ouverture (seuil de rentabilité)
                           newSL = openPrice + (10 * _Point);  // 10 points au-dessus pour éviter les faux déclenchements
                        }
                        
                        // Mettre à jour le SL au seuil de rentabilité
                        if(trade.PositionModify(ticket, newSL, newTP))
                        {
                           if(DebugMode)
                              Print("🔒 Forex: SL déplacé au seuil de rentabilité: Ticket=", ticket, 
                                    " Ancien SL: ", DoubleToString(currentSL, _Digits),
                                    " Nouveau SL: ", DoubleToString(newSL, _Digits));
                        }
                        else if(DebugMode)
                        {
                           Print("❌ Erreur modification SL: ", trade.ResultRetcodeDescription());
                        }
                     }
                     if(g_positionTracker.ticket == ticket)
                        g_positionTracker.profitSecured = true;
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
   
   // Calculer le profit total de TOUTES les positions (tous symboles)
   double totalProfit = 0.0;
   int profitablePositions = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Magic() == InpMagicNumber)  // TOUS les symboles avec ce magic
         {
            double currentProfit = positionInfo.Profit();
            totalProfit += currentProfit;  // Ajouter au profit global
            
            if(currentProfit > 0)
               profitablePositions++;
         }
      }
   }
   
   // Mettre à jour le profit maximum global
   if(totalProfit > g_globalMaxProfit)
      g_globalMaxProfit = totalProfit;
   
   // 2. FERMETURE GLOBALE AUTOMATIQUE À 5$
   // Fermer TOUTES les positions gagnantes sur tous symboles quand profit global >= 5$
   if(totalProfit >= PROFIT_SECURE_THRESHOLD)
   {
      int closedCount = 0;
      double totalClosedProfit = 0.0;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket > 0 && positionInfo.SelectByTicket(ticket))
         {
            if(positionInfo.Magic() == InpMagicNumber && positionInfo.Profit() > 0)  // Positions gagnantes uniquement
            {
               double profit = positionInfo.Profit();
               string symbol = positionInfo.Symbol();
               
               if(trade.PositionClose(ticket))
               {
                  closedCount++;
                  totalClosedProfit += profit;
                  Print("💰 FERMETURE GLOBALE 5$: Position ", symbol, " fermée - Profit: ", 
                        DoubleToString(profit, 2), "$");
               }
               else if(DebugMode)
               {
                  Print("❌ Erreur fermeture position globale ", symbol, ": ", trade.ResultRetcodeDescription());
               }
            }
         }
      }
      
      if(closedCount > 0)
      {
         Print("🎯 OBJECTIF 5$ ATTEINT: ", closedCount, " positions gagnantes fermées - Profit total: ", 
               DoubleToString(totalClosedProfit, 2), "$");
         
         // Réinitialiser le suivi après fermeture globale
         g_globalMaxProfit = 0.0;
         return;  // Sortir de la fonction après fermeture globale
      }
   }
   
   // NOUVELLE LOGIQUE: Toujours sécuriser les profits en modifiant le TP pour garantir 50% des gains
   // Vérifier chaque position pour ajuster le TP dynamiquement
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
            double currentTP = positionInfo.TakeProfit();
            ENUM_POSITION_TYPE posType = positionInfo.PositionType();
            
            // Récupérer le profit max pour cette position
            double maxProfitForPosition = GetMaxProfitForPosition(ticket);
            if(maxProfitForPosition == 0.0 && currentProfit > 0)
               maxProfitForPosition = currentProfit; // Utiliser le profit actuel comme référence initiale
            
            // Si la position est en profit, sécuriser au moins 50% des gains
            if(currentProfit > 0 && maxProfitForPosition > 0)
            {
               // Calculer le profit à sécuriser (50% du profit max atteint)
               double profitToSecure = maxProfitForPosition * 0.5; // 50% du profit max
               
               // Convertir le profit en points pour calculer le nouveau TP
               double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
               double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
               double pointsToSecure = (profitToSecure * tickSize) / (tickValue * point);
               
               // Calculer le nouveau TP pour sécuriser 50% des gains
               double newTP = 0.0;
               if(posType == POSITION_TYPE_BUY)
               {
                  // Pour BUY: TP = prix d'ouverture + points pour sécuriser 50% des gains
                  newTP = openPrice + pointsToSecure;
               }
               else if(posType == POSITION_TYPE_SELL)
               {
                  // Pour SELL: TP = prix d'ouverture - points pour sécuriser 50% des gains
                  newTP = openPrice - pointsToSecure;
               }
               
               // Normaliser le TP
               newTP = NormalizeDouble(newTP, _Digits);
               
               // Vérifier que le nouveau TP est meilleur que le TP actuel (plus proche du prix actuel)
               bool shouldUpdateTP = false;
               if(posType == POSITION_TYPE_BUY)
               {
                  // Pour BUY: nouveau TP doit être >= TP actuel (ou TP actuel = 0)
                  if(currentTP == 0 || newTP >= currentTP)
                     shouldUpdateTP = true;
               }
               else if(posType == POSITION_TYPE_SELL)
               {
                  // Pour SELL: nouveau TP doit être <= TP actuel (ou TP actuel = 0)
                  if(currentTP == 0 || newTP <= currentTP)
                     shouldUpdateTP = true;
               }
               
               // Vérifier les niveaux minimums du broker
               long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
               double minDistance = stopLevel * point;
               
               if(shouldUpdateTP && MathAbs(newTP - currentPrice) > minDistance)
               {
                  if(trade.PositionModify(ticket, currentSL, newTP))
                  {
                     if(DebugMode)
                        Print("✅ TP modifié pour sécuriser 50% des gains: Ticket=", ticket, 
                              " Profit max=", DoubleToString(maxProfitForPosition, 2), "$",
                              " Profit à sécuriser=", DoubleToString(profitToSecure, 2), "$",
                              " TP: ", DoubleToString(currentTP, _Digits), " -> ", DoubleToString(newTP, _Digits));
                  }
                  if(g_positionTracker.ticket == ticket)
                     g_positionTracker.profitSecured = true;
               }
            }
            if(totalProfit >= PROFIT_SECURE_THRESHOLD)
            {
               // Récupérer le profit max pour cette position (déjà calculé ci-dessus)
               if(maxProfitForPosition > 0)
               {
                  // Calculer le drawdown en pourcentage
                  double drawdownPercent = 0.0;
                  if(maxProfitForPosition > 0)
                     drawdownPercent = (maxProfitForPosition - currentProfit) / maxProfitForPosition;
                  
                  // Si drawdown > 50%, fermer la position
                  if(drawdownPercent > PROFIT_DRAWDOWN_LIMIT && currentProfit > 0)
                  {
                     if(trade.PositionClose(ticket))
                     {
                        Print("🔒 Position fermée - Drawdown > 50%: Profit max=", DoubleToString(maxProfitForPosition, 2), 
                              "$ Profit actuel=", DoubleToString(currentProfit, 2), "$ Drawdown=", DoubleToString(drawdownPercent * 100, 1), "%");
                     }
                     continue;
                  }
                  
                  // Sinon, sécuriser les profits en déplaçant le SL
                  if(currentProfit > 0 && maxProfitForPosition > 0)
                  {
                     // Calculer le nouveau SL pour sécuriser 50% du profit max
                     double profitToSecure = maxProfitForPosition * PROFIT_DRAWDOWN_LIMIT; // 50% du profit max
                     
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
                     
                     // Calculer le nouveau SL
                     double newSL = 0.0;
                     if(posType == POSITION_TYPE_BUY)
                     {
                        newSL = openPrice + (pointsToSecure * point);
                        // S'assurer que le nouveau SL est meilleur que l'actuel
                        if(currentSL == 0 || newSL > currentSL)
                        {
                           // Vérifier les niveaux minimums du broker
                           long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                           double minDistance = stopLevel * point;
                           if(newSL < currentPrice - minDistance)
                           {
                              double tp = positionInfo.TakeProfit();
                              if(trade.PositionModify(ticket, newSL, tp))
                              {
                                 if(DebugMode)
                                    Print("🔒 SL sécurisé pour position BUY: ", DoubleToString(newSL, _Digits), 
                                          " (sécurise ", DoubleToString(profitToSecure, 2), "$)");
                                 if(g_positionTracker.ticket == ticket)
                                    g_positionTracker.profitSecured = true;
                              }
                           }
                        }
                     }
                     else // SELL
                     {
                        newSL = openPrice - (pointsToSecure * point);
                        // S'assurer que le nouveau SL est meilleur que l'actuel
                        if(currentSL == 0 || newSL < currentSL)
                        {
                           // Vérifier les niveaux minimums du broker
                           long stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
                           double minDistance = stopLevel * point;
                           if(newSL > currentPrice + minDistance)
                           {
                              double tp = positionInfo.TakeProfit();
                              if(trade.PositionModify(ticket, newSL, tp))
                              {
                                 if(DebugMode)
                                    Print("🔒 SL sécurisé pour position SELL: ", DoubleToString(newSL, _Digits), 
                                          " (sécurise ", DoubleToString(profitToSecure, 2), "$)");
                                 if(g_positionTracker.ticket == ticket)
                                    g_positionTracker.profitSecured = true;
                              }
                           }
                        }
                     }
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

// Tentative d'entrée spike sur Boom/Crash avec confiance IA élevée et timing EMA M5
bool TrySpikeEntry(ENUM_ORDER_TYPE orderType)
{
   if(!IsBoomCrashSymbol(_Symbol))
      return false;

   // Confiance IA minimale 80%
   if(g_lastAIConfidence < 0.80)
      return false;

   int idx = GetSpikeIndex(_Symbol);
   datetime now = TimeCurrent();
   if(now < g_spikeCooldown[idx])
   {
      if(DebugMode)
         Print("⏸️ Spike cooldown actif pour ", _Symbol, " jusqu'à ", TimeToString(g_spikeCooldown[idx]));
      return false;
   }

   // Récupérer EMA M5
   double emaFastM5[], emaSlowM5[];
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   if(CopyBuffer(emaFastM5Handle, 0, 0, 1, emaFastM5) <= 0 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 1, emaSlowM5) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Spike: erreur récupération EMA M5");
      return false;
   }

   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double emaFast = emaFastM5[0];
   double emaSlow = emaSlowM5[0];
   double proximity = MathAbs(price - emaFast);

   // Conditions de tendance et proximité EMA
   bool ok = false;
   if(orderType == ORDER_TYPE_BUY)
   {
      if(emaFast > emaSlow && price <= emaFast + 5 * _Point)
         ok = true;
   }
   else // SELL
   {
      if(emaFast < emaSlow && price >= emaFast - 5 * _Point)
         ok = true;
   }

   if(!ok)
      return false;

   // Tentative d'entrée via logique standard
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
bool CheckAIZoneEntryWithEMA(ENUM_ORDER_TYPE orderType, bool &isInZone, bool &emaConfirmed, bool &isCorrection)
{
   isInZone = false;
   emaConfirmed = false;
   isCorrection = false;
   
   // Utiliser la variable globale currentSignalType
   currentSignalType = orderType;
   
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
      {
         Print("⏸️ Trade ", EnumToString(orderType), " rejeté: Correction détectée - Attendre entrée dans zone sans correction");
      }
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
//| Extrait les données de tendance pour un timeframe spécifique       |
//+------------------------------------------------------------------+
void ExtractTimeframeData(string resp, string timeframe, string &direction, double &confidence)
{
   // Chercher les données pour ce timeframe
   string searchPattern = "\"" + timeframe + "\"";
   int tfPos = StringFind(resp, searchPattern);
   if(tfPos >= 0)
   {
      // Extraire la direction
      string dirPattern = "\"direction\"";
      int dirPos = StringFind(resp, dirPattern, tfPos);
      if(dirPos >= 0)
      {
         int colon = StringFind(resp, ":", dirPos);
         if(colon > 0)
         {
            int startQuote = StringFind(resp, "\"", colon);
            if(startQuote >= 0)
            {
               int endQuote = StringFind(resp, "\"", startQuote + 1);
               if(endQuote > startQuote)
               {
                  direction = StringSubstr(resp, startQuote + 1, endQuote - startQuote - 1);
               }
            }
         }
      }
      
      // Extraire la confiance
      string confPattern = "\"confidence\"";
      int confPos = StringFind(resp, confPattern, tfPos);
      if(confPos >= 0)
      {
         int colon = StringFind(resp, ":", confPos);
         if(colon > 0)
         {
            int endPos = StringFind(resp, ",", colon);
            if(endPos <= 0)
               endPos = StringFind(resp, "}", colon);
            if(endPos > colon)
            {
               string confStr = StringSubstr(resp, colon + 1, endPos - colon - 1);
               confidence = StringToDouble(confStr);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+