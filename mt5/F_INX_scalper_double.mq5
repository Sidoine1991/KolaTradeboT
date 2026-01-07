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

// Include custom strategy modules
bool CheckEMATouchEntry(ENUM_ORDER_TYPE &signalType); // Forward declaration

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
input bool   UseAdvancedDecisionGemma = false; // Utiliser endpoint decisionGemma (Gemma+Gemini) avec analyse visuelle
input int    AI_Timeout_ms       = 800;     // Timeout WebRequest en millisecondes
input double AI_MinConfidence    = 0.6;     // Confiance minimale IA pour trader (60%)
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
input bool   DailyLimitAccountWide = false;  // Limite journalière sur TOUT le compte (sinon Robot seulement)
input double MaxTotalLoss        = 5.0;     // Perte totale maximale toutes positions (USD)
input bool   UseTrailingStop     = true;    // Utiliser trailing stop

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
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Réinitialiser les compteurs quotidiens si nécessaire
   ResetDailyCountersIfNeeded();
   
   // MODE PRUDENT: Activé dès que profit quotidien >= 50$ pour sécuriser les gains
   bool cautiousMode = (g_dailyProfit >= 50.0);
   if(cautiousMode && DebugMode)
      Print("✅ MODE PRUDENT ACTIVÉ: Profit quotidien >= 50$ (", DoubleToString(g_dailyProfit, 2), " USD) - Sécurisation avec signaux ultra-sûrs");
   
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
   
   // Calculer le profit/perte actuel depuis l'historique (net: profit + commission + swap)
   datetime startOfDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   datetime endOfDay = startOfDay + 86400;
   
   if(HistorySelect(startOfDay, endOfDay))
   {
      int totalDeals = HistoryDealsTotal();
      double totalPnL = 0.0;
      
      for(int i = 0; i < totalDeals; i++)
      {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         
         // Vérifier si c'est notre EA (si non-global)
         if(!DailyLimitAccountWide && HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagicNumber)
            continue;
         
         // Profit seulement pour les sorties (clôture)
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) == DEAL_ENTRY_OUT)
         {
            totalPnL += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         }
         
         // TOUJOURS compter les commissions et swaps (entrées ET sorties)
         totalPnL += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         totalPnL += HistoryDealGetDouble(ticket, DEAL_SWAP);
      }
      
      // Séparer en profit et perte nets pour la journée
      if(totalPnL > 0)
      {
         g_dailyProfit = totalPnL;
         g_dailyLoss = 0;
      }
      else
      {
         g_dailyProfit = 0;
         g_dailyLoss = MathAbs(totalPnL);
      }
   }
}

//+------------------------------------------------------------------+
//| Check for EMA Touch Entry with M5 Bounce Confirmation           |
//+------------------------------------------------------------------+
bool CheckEMATouchEntry(ENUM_ORDER_TYPE &signalType)
{
   signalType = WRONG_VALUE;
   
   // Get current price
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Get M1 Fast EMA
   double emaFast[];
   ArraySetAsSeries(emaFast, true);
   if(CopyBuffer(emaFastHandle, 0, 0, 3, emaFast) < 3)
      return false;
   
   // Get ATR for tolerance calculation
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1)
      return false;
   
   double touchTolerance = atr[0] * 0.5; // ±0.5 ATR tolerance
   
   // Check if price is touching EMA
   bool isTouchingEMA = MathAbs(currentPrice - emaFast[0]) <= touchTolerance;
   if(!isTouchingEMA)
      return false;
   
   // Get M5 candles for bounce confirmation
   MqlRates ratesM5[];
   ArraySetAsSeries(ratesM5, true);
   if(CopyRates(_Symbol, PERIOD_M5, 0, 2, ratesM5) < 2)
      return false;
   
   // Get M5 EMAs for trend confirmation
   double emaFastM5[];
   double emaSlowM5[];
   ArraySetAsSeries(emaFastM5, true);
   ArraySetAsSeries(emaSlowM5, true);
   if(CopyBuffer(emaFastM5Handle, 0, 0, 2, emaFastM5) < 2 || 
      CopyBuffer(emaSlowM5Handle, 0, 0, 2, emaSlowM5) < 2)
      return false;
   
   // Verify clear trend on M5 (Fast EMA > Slow EMA for uptrend)
   bool isUptrend = (emaFastM5[0] > emaSlowM5[0]);
   bool isDowntrend = (emaFastM5[0] < emaSlowM5[0]);
   
   if(!isUptrend && !isDowntrend)
      return false; // No clear trend
   
   // Check for BUY setup
   if(isUptrend)
   {
      // Price was below EMA, now touching/above
      bool wasBelowEMA = (emaFast[1] > ratesM5[1].close);
      bool isAboveEMA = (currentPrice >= emaFast[0]);
      
      // M5 candle is bullish
      bool m5Bullish = (ratesM5[0].close > ratesM5[0].open);
      
      if(wasBelowEMA && isAboveEMA && m5Bullish)
      {
         signalType = ORDER_TYPE_BUY;
         if(DebugMode)
            Print("✅ EMA TOUCH BUY: Prix rebondi sur EMA rapide avec bougie M5 haussière");
         return true;
      }
   }
   
   // Check for SELL setup
   if(isDowntrend)
   {
      // Price was above EMA, now touching/below
      bool wasAboveEMA = (emaFast[1] < ratesM5[1].close);
      bool isBelowEMA = (currentPrice <= emaFast[0]);
      
      // M5 candle is bearish
      bool m5Bearish = (ratesM5[0].close < ratesM5[0].open);
      
      if(wasAboveEMA && isBelowEMA && m5Bearish)
      {
         signalType = ORDER_TYPE_SELL;
         if(DebugMode)
            Print("✅ EMA TOUCH SELL: Prix rebondi sur EMA rapide avec bougie M5 baissière");
         return true;
      }
   }
   
   return false;
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
   
   // Extraire les zones BUY/SELL depuis la réponse JSON
   ExtractAIZonesFromResponse(resp);
   
   g_lastAITime = TimeCurrent();
   
   if(DebugMode)
      Print("🤖 IA: ", g_lastAIAction, " (confiance: ", DoubleToString(g_lastAIConfidence, 2), ") - ", g_lastAIReason);
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
            
            // PROGRESSIVE PROFIT SECURING: Ajuster le SL pour sécuriser 50% du profit max
            if(g_positionTracker.maxProfitReached >= 1.0 && !g_positionTracker.profitSecured)
            {
               // Si le profit actuel est inférieur à 50% du profit max, ajuster le SL
               double profitRetrace = g_positionTracker.maxProfitReached - currentProfit;
               double allowedRetrace = g_positionTracker.maxProfitReached * 0.5; // 50% du max
               
               if(profitRetrace >= allowedRetrace)
               {
                  // Calculer nouveau SL pour verrouiller 50% du profit max
                  double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
                  double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
                  double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
                  
                  if(tickValue > 0 && point > 0)
                  {
                     double pointValue = (tickValue / tickSize) * point;
                     double profitToSecure = g_positionTracker.maxProfitReached * 0.5; // 50%
                     double slDistance = (profitToSecure / (pointValue * g_positionTracker.currentLot));
                     
                     double newSL = 0;
                     double currentPrice = positionInfo.PriceCurrent();
                     
                     if(positionInfo.PositionType() == POSITION_TYPE_BUY)
                     {
                        newSL = NormalizeDouble(currentPrice - (slDistance * point), _Digits);
                        // Ne jamais déplacer le SL en arrière
                        if(newSL > positionInfo.StopLoss() || positionInfo.StopLoss() == 0)
                        {
                           if(trade.PositionModify(ticket, newSL, positionInfo.TakeProfit()))
                           {
                              g_positionTracker.profitSecured = true;
                              Print("🔒 SL ajusté pour sécuriser 50% du profit max (", DoubleToString(profitToSecure, 2), "$) - Nouveau SL: ", newSL);
                           }
                        }
                     }
                     else if(positionInfo.PositionType() == POSITION_TYPE_SELL)
                     {
                        newSL = NormalizeDouble(currentPrice + (slDistance * point), _Digits);
                        // Ne jamais déplacer le SL en arrière
                        if(newSL < positionInfo.StopLoss() || positionInfo.StopLoss() == 0)
                        {
                           if(trade.PositionModify(ticket, newSL, positionInfo.TakeProfit()))
                           {
                              g_positionTracker.profitSecured = true;
                              Print("🔒 SL ajusté pour sécuriser 50% du profit max (", DoubleToString(profitToSecure, 2), "$) - Nouveau SL: ", newSL);
                           }
                        }
                     }
                  }
               }
            }
            
            // Vérifier si on doit dupliquer le trade (avec lot 2x le lot initial)
            datetime now = TimeCurrent();
            int positionAge = (int)(now - g_positionTracker.openTime);
            
            // Conditions pour duplication :
            // 1. Nombre de duplications < 4 (limite autorisée)
            // 2. Profit positif (robot en gain proprement)
            // 3. Signal IA fort dans le sens voulu (confiance >= 80% et action correspond au sens de la position)
            // 4. Position âgée d'au moins MinPositionLifetimeSec secondes
            bool shouldDuplicate = false;
            
            // Compter le nombre de positions dupliquées existantes pour ce symbole
            int duplicateCount = CountDuplicatePositions(_Symbol);
            const int MAX_DUPLICATIONS = 4;
            
            if(duplicateCount < MAX_DUPLICATIONS &&
               currentProfit >= 1.0 && // Profit >= 1.0$ pour dupliquer
               positionAge >= MinPositionLifetimeSec)
            {
               // Mapper le type de position vers le type d'ordre pour les vérifications
               ENUM_ORDER_TYPE orderType = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 
                                          ORDER_TYPE_BUY : ORDER_TYPE_SELL;

               // Condition supplémentaire: Confiance IA >= 80% (si IA activée)
               if(UseAI_Agent && (g_lastAIConfidence < 0.80 || g_lastAIAction == "hold"))
               {
                   if(DebugMode && positionAge % 15 == 0) // Log moins fréquent
                      Print("⏸️ Duplication attente: Profit OK (", DoubleToString(currentProfit, 2), "$) mais confiance IA insuffisante ou IA en attente (", DoubleToString(g_lastAIConfidence*100, 1), "%)");
               }
               // VÉRIFIER L'ALIGNEMENT DE TENDANCE AVANT DUPLICATION
               else if(!CheckTrendAlignment(orderType))
               {
                   if(DebugMode && positionAge % 15 == 0)
                      Print("⏸️ Duplication attente: Profit OK mais TENDANCE plus alignée sur M5/H1");
               }
               // VÉRIFIER LA ZONE IA ET EMA AVANT DUPLICATION (ignore zone check during duplication)
               else
               {
                   bool isInZone = false;
                   bool emaConfirmed = false;
                   bool isCorrection = false;
                   
                   if(!CheckAIZoneEntryWithEMA(orderType, isInZone, emaConfirmed, isCorrection, true))
                   {
                      if(DebugMode && positionAge % 15 == 0)
                         Print("⏸️ Duplication attente: Profit OK mais correction détectée (EMA M1)");
                   }
                   else
                   {
                      // TOUTES LES CONDITIONS SONT RÉUNIES
                      shouldDuplicate = true;
                      
                      if(DebugMode)
                         Print("✅ Duplication AUTORISÉE: Profit=", DoubleToString(currentProfit, 2), 
                               "$ | Confiance IA=", DoubleToString(g_lastAIConfidence*100, 1), 
                               "% | Tendance & Momentum OK | Duplications=", duplicateCount, "/", MAX_DUPLICATIONS);
                   }
               }
            }
            
            if(shouldDuplicate)
            {
               DuplicateTradeWithDoubleLot(ticket);
            }
            
            // Vérifier les SL/TP (gérés par le broker, mais on peut vérifier)
            double sl = positionInfo.StopLoss();
            double tp = positionInfo.TakeProfit();
            
            // Si pas de SL/TP, les définir
            if(sl == 0 && tp == 0)
            {
               SetFixedSLTP(ticket);
            }
            
            // SPIKE Boom/Crash
            bool isBoomCrash = (StringFind(_Symbol, "Boom") != -1 || StringFind(_Symbol, "Crash") != -1);
            if(isBoomCrash)
            {
               CloseBoomCrashAfterSpike(ticket, currentProfit);
            }
            
            // NOUVEAU: Fermeture si l'IA recommande d'ATTENDRE (hold)
            if(UseAI_Agent && (g_lastAIAction == "hold" || g_lastAIAction == ""))
            {
               if(currentProfit >= 0.5 || currentProfit <= -1.0) // Seuil min pour éviter micro-clôtures inutiles
               {
                  if(trade.PositionClose(ticket))
                  {
                     Print("✅ Position fermée: IA recommande d'ATTENDRE (ATTENTE/HOLD) - Profit=", DoubleToString(currentProfit, 2), "$");
                     g_hasPosition = false;
                     continue;
                  }
               }
            }
            
            // Appliquer le Trailing Stop
            ApplyDynamicTrailingStop(ticket);
            
            // NOUVELLE LOGIQUE: Fermer les positions si le prix sort de la zone IA et entre en correction
            // Évite de garder des positions pendant les corrections
            ENUM_POSITION_TYPE posType = positionInfo.PositionType();
            if(posType == POSITION_TYPE_BUY)
            {
               CheckAndCloseBuyOnCorrection(ticket, currentProfit);
            }
            else if(posType == POSITION_TYPE_SELL)
            {
               CheckAndCloseSellOnCorrection(ticket, currentProfit);
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
void DuplicateTradeWithDoubleLot(ulong ticket)
{
   if(!positionInfo.SelectByTicket(ticket))
      return;
   
   double initialLot = g_positionTracker.initialLot;
   double duplicationLot = initialLot * 2.0;
   
   // Vérifier le lot minimum et maximum du broker
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   duplicationLot = NormalizeLotSize(duplicationLot);
   duplicationLot = MathMax(minLot, MathMin(maxLot, duplicationLot));
   
   // DUPLICATION START
   // DUPLICATION EXECUTION
   ENUM_ORDER_TYPE orderType = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 
                              ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   
   double price = (orderType == ORDER_TYPE_BUY) ? 
                  SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                  SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculer SL et TP en points pour la nouvelle position
   double sl, tp;
   ENUM_POSITION_TYPE posType = positionInfo.PositionType();
   CalculateSLTPInPoints(posType, price, sl, tp);
   
   if(trade.PositionOpen(_Symbol, orderType, duplicationLot, price, sl, tp, "DUPLICATA"))
   {
      Print("✅ Trade DUPLIQUÉ: Type=", EnumToString(orderType), " Lot=", duplicationLot, " (2x initial)");
   }
   else
   {
      Print("❌ Erreur duplication trade: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

int CountDuplicatePositions(string symbol)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && positionInfo.SelectByTicket(ticket))
      {
         if(positionInfo.Symbol() == symbol && positionInfo.Magic() == InpMagicNumber)
         {
            if(positionInfo.Comment() == "DUPLICATA")
               count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Appliquer le Trailing Stop dynamique basé sur l'ATR              |
//+------------------------------------------------------------------+
void ApplyDynamicTrailingStop(ulong ticket)
{
   if(!UseTrailingStop || !positionInfo.SelectByTicket(ticket))
      return;
   
   double currentPrice = (positionInfo.PositionType() == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double atrValue = 0;
   double atr_b[];
   ArraySetAsSeries(atr_b, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr_b) > 0) atrValue = atr_b[0];
   
   if(atrValue <= 0) return;
   
   double trailingDistance = atrValue * 1.5; // Trailing serré à 1.5x ATR
   double currentSL = positionInfo.StopLoss();
   double newSL = 0;
   
   if(positionInfo.PositionType() == POSITION_TYPE_BUY)
   {
      newSL = NormalizeDouble(currentPrice - trailingDistance, _Digits);
      if(newSL > currentSL + (5 * point) || (currentSL == 0 && newSL < currentPrice - point))
      {
         trade.PositionModify(ticket, newSL, positionInfo.TakeProfit());
      }
   }
   else if(positionInfo.PositionType() == POSITION_TYPE_SELL)
   {
      newSL = NormalizeDouble(currentPrice + trailingDistance, _Digits);
      if(newSL < currentSL - (5 * point) || (currentSL == 0 && newSL > currentPrice + point))
      {
         trade.PositionModify(ticket, newSL, positionInfo.TakeProfit());
      }
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
      // NOUVELLE RÈGLE: SL à 20% du TP (Ratio 1:4)
      double currentSL_USD = TakeProfitUSD * 0.2; 
      
      // RÉDUCTION SUPPLÉMENTAIRE POUR STEP INDEX (très volatil)
      if(StringFind(_Symbol, "Step") != -1)
      {
         currentSL_USD = currentSL_USD * 0.5; // On serre encore plus sur Step Index
         if(DebugMode) Print("📏 Step Index detected: SL set to 10% of TP (", DoubleToString(currentSL_USD, 2), " USD)");
      }
      else
      {
         if(DebugMode) Print("📏 SL/TP Ratio strict (20/80) appliqué: SL=", DoubleToString(currentSL_USD, 2), " USD");
      }

      // Points pour SL
      double slValuePerPoint = lotSize * pointValue;
      if(slValuePerPoint > 0)
         slPoints = currentSL_USD / slValuePerPoint;
      
      // Points pour TP
      double tpValuePerPoint = lotSize * pointValue;
      if(tpValuePerPoint > 0)
         tpPoints = TakeProfitUSD / tpValuePerPoint;
   }
   
   // --- NOUVEAU: SERRER LES SL/TP AVEC L'ATR (DYNAMIQUE) ---
   // On récupère l'ATR actuel pour s'assurer que les distances ne sont pas trop grandes
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0 && atr[0] > 0)
   {
      double atrPoints = atr[0] / point;
      
      // CAP SERRÉ: Le SL ne doit pas dépasser 1.5x ATR (TRES PROCHE)
      double maxSLPoints = atrPoints * 1.5;
      if(slPoints > maxSLPoints)
      {
         if(DebugMode) Print("📏 SL trop éloigné - Cap ATR ultra-serré appliqué: ", DoubleToString(maxSLPoints, 0), " pts");
         slPoints = maxSLPoints;
      }
      
      // CAP SERRÉ: Le TP ne doit pas dépasser 3x ATR (OBJECTIF REALISTE)
      double maxTPPoints = atrPoints * 3.0;
      if(tpPoints > maxTPPoints)
      {
         if(DebugMode) Print("📏 TP trop éloigné - Cap ATR réaliste appliqué: ", DoubleToString(maxTPPoints, 0), " pts");
         tpPoints = maxTPPoints;
      }
   }

   // Fallback ATR
   if(slPoints <= 0 || tpPoints <= 0)
   {
      if(ArraySize(atr) > 0 && atr[0] > 0)
      {
         slPoints = (2.0 * atr[0]) / point;
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
   
   // PRIORITÉ 2: STRATÉGIE EMA TOUCH (Si tendance claire)
   if(CheckEMATouchEntry(signalType))
   {
      if(DebugMode)
         Print("💡 Opportunité EMA Touch détectée: ", EnumToString(signalType));
      hasSignal = true;
   }
   
   // MODE PRUDENT: Activé dès profit >= 50$ pour sécuriser intelligemment
   bool cautiousMode = (g_dailyProfit >= 50.0);
   double requiredConfidence = cautiousMode ? 0.95 : AI_MinConfidence; // 95% en mode prudent, 80% normalement
   
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
         
         // VÉRIFIER L'ALIGNEMENT DE TENDANCE M5/H1 AVANT DE TRADER
         if(signalType != WRONG_VALUE)
         {
            if(CheckTrendAlignment(signalType))
            {
               // NOUVELLE LOGIQUE: Vérifier que le prix est dans la zone IA avec confirmation EMA
               // Évite de trader les corrections
               bool isInZone = false;
               bool emaConfirmed = false;
               bool isCorrection = false;
               
               if(CheckAIZoneEntryWithEMA(signalType, isInZone, emaConfirmed, isCorrection))
               {
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
                     Print("🤖 Signal ", EnumToString(signalType), " basé sur recommandation IA (confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%) - Prix dans zone IA + EMA M5 confirmé + Pas de correction", cautiousMode ? " [MODE PRUDENT]" : "");

                  // SPIKE Boom/Crash : si confiance élevée et conditions EMA M5, tenter entrée rapide
                  if(IsBoomCrashSymbol(_Symbol) && g_lastAIConfidence >= 0.80)
                  {
                     if(TrySpikeEntry(signalType))
                        return; // spike tenté, ne pas poursuivre
                  }
               }
               else
               {
                  if(DebugMode)
                  {
                     if(!isInZone)
                        Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Prix pas dans zone IA");
                     else if(!emaConfirmed)
                        Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - EMA M5 non confirmée");
                     else if(isCorrection)
                        Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Correction détectée (attendre entrée propre dans zone)");
                  }
                  return; // Conditions non remplies, ne pas trader
               }
            }
            else
            {
               if(DebugMode)
                  Print("⏸️ Signal IA ", EnumToString(signalType), " rejeté - Alignement M5/H1 non confirmé");
               return; // Pas d'alignement, ne pas trader
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
//| Sécurisation dynamique des profits                                |
//| Active dès que le profit total >= 3$                              |
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
   
   // Vérifier si on doit activer la sécurisation (profit total >= 3$)
   if(totalProfit < PROFIT_SECURE_THRESHOLD)
   {
      // Pas encore de profit suffisant, pas de sécurisation
      return;
   }
   
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
            
            // Récupérer le profit max pour cette position
            double maxProfitForPosition = GetMaxProfitForPosition(ticket);
            if(maxProfitForPosition == 0.0 && currentProfit > 0)
               maxProfitForPosition = currentProfit; // Utiliser le profit actuel comme référence initiale
            
            // Si le profit max est > 0, vérifier le drawdown
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
bool CheckAIZoneEntryWithEMA(ENUM_ORDER_TYPE orderType, bool &isInZone, bool &emaConfirmed, bool &isCorrection, bool ignoreZone=false)
{
   // --- NOUVEAU: FILTRE PROXIMITÉ DES ZONES (RANGE) ---
   if(!ignoreZone && g_aiBuyZoneHigh > 0 && g_aiSellZoneLow > 0)
   {
      double zoneGap = g_aiSellZoneLow - g_aiBuyZoneHigh;
      double atrM1_v = 0;
      double atr_b[];
      ArraySetAsSeries(atr_b, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr_b) > 0) atrM1_v = atr_b[0];
      if(atrM1_v > 0 && zoneGap < atrM1_v * 5.0) return false;
   }

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
   
   if(ignoreZone)
   {
      isInZone = true;
      priceEnteringZone = true;
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
   
   // Récupérer les valeurs EMA M5 (confirmation principale) + Momentum Slope
   if(CopyBuffer(emaFastM5Handle, 0, 0, 3, emaFastM5) <= 0 ||
      CopyBuffer(emaSlowM5Handle, 0, 0, 3, emaSlowM5) <= 0)
   {
      if(DebugMode)
         Print("⚠️ Erreur récupération EMA M5 pour vérification zone");
      return false;
   }
   
   // --- FILTRE MCS: SÉPARATION DYNAMIQUE & SLOPE (M5) ---
   double emaDiff = MathAbs(emaFastM5[0] - emaSlowM5[0]);
   double prevEmaDiff = MathAbs(emaFastM5[1] - emaSlowM5[1]);
   double atr_b[];
   double atrM1 = 0;
   ArraySetAsSeries(atr_b, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr_b) > 0) atrM1 = atr_b[0];

   // 1. Séparation dynamique (min 1.5x ATR)
   if(atrM1 > 0 && emaDiff < atrM1 * 1.5)
   {
      if(DebugMode) 
         Print("⏸️ Tendance trop faible (Séparation EMA < 1.5x ATR): ", DoubleToString(emaDiff/_Point, 0), " pts < ", DoubleToString((atrM1*1.5)/_Point, 0), " pts");
      return false;
   }
   
   // 2. Slope Momentum (les EMAs doivent s'écarter, pas stagner ou converger)
   if(emaDiff <= prevEmaDiff * 0.98) // Si la séparation diminue ou stagne (marge 2%)
   {
      if(DebugMode)
         Print("⏸️ Momentum stagnant ou convergent (EMA Slope <= 0): ", DoubleToString(emaDiff/_Point, 0), " <= ", DoubleToString(prevEmaDiff/_Point, 0), " pts");
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

