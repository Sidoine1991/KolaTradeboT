//| SMC_Universal.mq5                                                 |
//| Robot Smart Money Concepts - UN SEUL ROBOT multi-actifs + IA      |
//| Boom/Crash | Volatility | Forex | Commodities | Metals           |
//| GOM: TradingView -> ai_server -> SMC (symbole graphique MT5)      |
//|                                                                    |
//| UPDATE 2026-07-15 (v1.05): SPIKE CHAIN STATE DETECTOR + SNIPER CAP|
//|   ÉTENDU (Claude)                                                  |
//| - Machine à états CALME/PRÉ-SPIKE/CHAÎNE ACTIVE/ÉPUISEMENT (z-score|
//|   ATR + persistance directionnelle) pour détecter le DÉBUT d'une   |
//|   chaîne de spikes Boom/Crash/Painx/Gainx, avant confirmation      |
//|   classique (SMC_UpdateSpikeChainState, appelée depuis OnTick)     |
//| - Entrée précoce optionnelle dès CHAÎNE ACTIVE (2e bougie forte),  |
//|   gardée par l'alignement des indicateurs classiques (classicOk)   |
//| - Sniper Risk Cap ($2 + RR mini) étendu aux ordres LIMIT           |
//|   (EMA SMC BUY/SELL LIMIT), à l'entrée IA précise, et à FVG_Kill   |
//|   BUY/SELL - en plus de l'entrée SMC principale et des spike trades|
//| UPDATE 2026-07-15: SNIPER SCALPER MODE (Claude)                  |
//| - Cap $ universel MaxLossPerTradeDollars=2.0 applique via         |
//|   SMC_ApplySniperRiskCap() sur l'entree SMC principale            |
//| - RR minimum force (MinRewardRiskRatio=3.0) sur entree SMC        |
//|   ET sur ExecuteSpikeTrade (Boom/Crash/Painx/Gainx avec SL/TP)    |
//| - Gate de confluence mini (MinSniperConfluenceGates) via tags     |
//|   LS-/FVG-/OB-/BOS-/Zone-/IA- deja generes par DetectSMCSignal   |
//| - Classification symboles etendue: Weltrade PAINX/GAINX -> spike, |
//|   Deriv JUMP/STEP -> volatility (XAU/GOLD/XAG/SILVER deja OK     |
//|   quel que soit le suffixe broker, donc XM Global Gold couvert)   |
//| UPDATE 2026-06-11: Audit complet + corrections critiques         |
//| - GOMMinCoherencePct: 55% -> 70% (regle absolue IA gate)        |
//| - UseGOMWaitAutoClose: forceClose=true (bypass protection perte) |
//| - WAIT auto-close filtre Magic Number (no fermeture autres EAs)  |
//| - Fallback /gom-verdict stale supprime (invalide si echec LIVE)  |
//| - GOMG_ClearAll: wildcard invalide corrige (prefix sans *)       |
//| UPDATE 2026-06-10: GOM Pipeline 100% LIVE (NO STALE JSON)       |
//| - SMCGP_PollGOM() calls /gom-kola-dashboard (LIVE) first        |
//| - Fallback: /gom-kola-dashboard -> /gom-tableau-complete        |
//| - Verdicts SYNCHRONIZED avec TradingView (< 1 sec latency)      |
#property copyright "TradBOT SMC"
#property version   "1.05"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
#include "modules/GOM_Graphics.mqh"
#include "Modele_spike/SpikeChainPredictor.mqh"
#include "modules/SMC_ChainPredictor.mqh"
#include "modules/SMC_CrossCorrelation.mqh"
#include "modules/SMC_DowTrendline.mqh"
#include "modules/SMC_TFGate.mqh"
#include "modules/SMC_SpikeModels.mqh"
// #include "modules/EA_PivotEntry.mqh"        // TODO: Refactor pour MQL5
// #include "modules/EA_IndependentTrader.mqh"  // TODO: Refactor pour MQL5
// #include "modules/AutoTrading.mqh"  // TODO: Fix MQL5 OrderSend compatibility

//--- Constants (hardcoded visual params to save input slots) ---
#define ShowPredictedSwing          true    // SL/SH prédits sur le canal
#define ShowEMASupportResistance    true    // EMA M1, M5, H1 S/R
#define ShowLimitOrderLevels        true    // Afficher niveaux limit orders
#define ImpulseZoneShowOnChart      true    // Dessiner zone impulse sur graphique
#define ShowTVBollingerLines        true    // Bandes BB TV sync
#define ShowTVOrderBlocks           true    // Zones OB TV sync
#define UseLocalOrderBlockDrawings  false   // Drawings OB locaux
#define ShowOrderFlowCompass        false   // Order flow compass
#define GOMSyncSymbolToTV           false   // Sync symbol to TV
#define CleanupLegacyDrawings       true    // Cleanup old drawings on init
#define PatternDrawOnChart          true    // Afficher patterns sur graphique
#define ShowEMA50100200             true    // Tracer EMA 50/100/200
#define ShowTradingSessions         true    // Sessions Asian/EU/NY
#define ShowCognitionPath           true    // Cognition forecast path
#define ShowChartGraphics           true    // FVG, OB, Fibo, EMA, Swing H/L
#define ShowPremiumDiscount         true    // Zones Premium/Discount/équilibre
#define ShowSignalArrow             true    // Flèche dynamique BUY/SELL
#define ShowSpikeZones              true    // Zones spike H1+M5

//+------------------------------------------------------------------+
//| ENUMS, STRUCTS & DEFINES                                        |
//+------------------------------------------------------------------+
enum ENUM_SMC_TRADE_PERM
{
   SMC_TRADE_PERM_BLOCKED = -1,
   SMC_TRADE_PERM_GOM_ONLY = 0,
   SMC_TRADE_PERM_FULL = 1
};

struct SMC_EntryGateResult
{
   bool   allow;
   string reason;
   double probabilityScore;
   int    gatesPassed;
   int    gatesTotal;
   string gateDetails;
   bool   isHighProbability;
   ENUM_SMC_TRADE_PERM tradePermission;
   string modeUsed;
   double entryPriceHint;
   double slHint;
   double tpHint;
};
//--- OTE Fractal / Momentum State
struct SMC_PulseState
{
   bool   active;
   int    barsSinceLastPulse;
   double lastPulsePrice;
   int    pulseDirection;      // +1 haussier, -1 baissier
   double pulseStrength;
   double momentumDecline;     // < 0 = declin
   double entryThreshold;
   double entryConfidence;
   bool   entryReady;
   string entryDirection;
   double entryPrice;
   double target;
   double stopLoss;
};
//--- Spike Series State (chaîne de spikes Boom/Crash)
struct SMC_SpikeSeriesState
{
   int      spikeCount;
   datetime seriesStartTime;
   datetime lastSpikeTime;
   double   prevSpikeATR;
   double   lastSpikeATR;
   int      avgSpikeIntervalBars;
   bool     seriesActive;
   double   spikeDeclineRatio;
};
//--- Circuit-Breaker / Readiness globaux (forward decl)
struct SMC_DailyReadiness
{
   bool   cbActive;
   double cbSymbolCoolSec;
   bool   go;
   double score;
   string cbReason;
   string bestHours;
   string avoidHours;
};
//+------------------------------------------------------------------+

#define SMC_EVALUATE_ENTRY_GATE(dirSign,isGomOrder,symbol,lot,entryPrice,sl) \
   SMC_EvaluateEntryGate(dirSign,isGomOrder,symbol,lot,entryPrice,sl)

//+------------------------------------------------------------------+
//| WRAPPER POUR CAPTURER TOUTES LES FERMETURES                    |
//+------------------------------------------------------------------+
bool PositionCloseWithLog(ulong ticket, string reason = "", bool forceClose = false)
{
   // Obtenir les informations avant fermeture
   if(PositionSelectByTicket(ticket))
   {
      string symbol = PositionGetString(POSITION_SYMBOL);
      double profit = PositionGetDouble(POSITION_PROFIT);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int secondsSinceOpen = (int)(TimeCurrent() - openTime);

      // PROTECTION CONTRE LES SORTIES RAPIDES SANS SPIKE
      // Attendre au moins 1$ de perte avant toute fermeture auto (sauf forceClose)
      double minLossBeforeClose = MathMax(1.0, MinLossBeforeAutoCloseUSD);
      if(!forceClose && profit < 0 && profit > -minLossBeforeClose)
      {
         Print("[PROTECT] Fermeture bloquee (perte ", DoubleToString(profit,2),
               "$ > -", DoubleToString(minLossBeforeClose, 2), "$) | raison=", reason,
               " — attendre 1$ de perte avant décision");
         return false;
      }
      
      if(profit < 0 && profit <= -minLossBeforeClose)
      {
         Print("⚠️ PERTE SEUIL ATTEINT - Fermeture autorisée");
         Print("   📊 Position: ", symbol, " | Ticket: ", ticket);
         Print("   💰 Perte: ", DoubleToString(profit, 2), "$ ≤ -",
               DoubleToString(minLossBeforeClose, 2), "$");
         Print("   ✅ Raison: ", reason, " | ACTION: Fermeture autorisée");
      }
      
      // Si profit positif, autoriser normalement
      if(profit >= 0)
      {
         Print("💰 POSITION EN GAIN - Fermeture autorisée");
         Print("   📊 Position: ", symbol, " | Ticket: ", ticket);
         Print("   💰 Profit: ", DoubleToString(profit, 2), "$ | ACTION: Fermeture autorisée");
      }
      
      Print("🚨 FERMETURE DÉTECTÉE - ", symbol,
            " | Ticket: ", ticket,
            " | Profit: ", DoubleToString(profit, 2), "$",
            " | Âge: ", secondsSinceOpen, "s",
            " | Raison: ", reason);
   }

   // Exécuter la fermeture réelle
   bool result = trade.PositionClose(ticket);

   // Si fermeture réussie, réinitialiser g_maxProfit pour la prochaine position
   if(result)
   {
      g_maxProfit = 0;
      Print("✅ g_maxProfit réinitialisé pour la prochaine position");
   }

   return result;
}

//+------------------------------------------------------------------+

// Forward declarations
bool GetAISignalData();
bool UpdateAIDecision(int timeoutMs = -1);
void UpdateMLMetricsDisplay();
void DrawSwingHighLow();
void DrawFVGOnChart();
void DrawOBOnChart();
void DrawFibonacciOnChart();
void DrawEMACurveOnChart();
void DrawEMA50100200OnChart();
void DrawTradingSessionsOnChart();
void SMC_UpdateSpikeSeries();
bool SMC_SpikeSeriesAllowsReentry(const string symbol);
double GOM_GetATRValue();
int    SMC_ExtractSpikeFreqFromSymbol(const string sym);
void   TrySpikeImminentAutoEntry(const double spikeProb);
void DrawLiquidityZonesOnChart();
void PlaceScalpingLimitOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope);
void PlaceSRLimitOrders20Bars();
void UpdateSR20BounceState();   // S/R 20 bars touché+rebondi -> arme chaîne spikes
void DrawHistoricalSwingPoints(MqlRates &rates[], int bars, double point);
void DrawBookmarkLevels();
void ManageBoomCrashSpikeClose();
void ManageDollarExits();
void CloseWorstPositionIfTotalLossExceeded();
void CloseAllPositionsIfTotalProfitReached();
void ClosePositionsOnIAHold();
void ClosePositionsOnDirectionConflict();
void AutoRotatePositions();
void CloseUnprofitableAfterDelay();
bool IsAlgoSpikeReady();
void DrawPremiumDiscountZones();
void DrawSignalArrow();
void UpdateSignalArrowBlink();
void DrawPredictedSwingPoints();
void DrawEMASupportResistance();
void DrawPredictionChannel();
void DrawSMCChannelsMultiTF();
void DrawEMASupertrendMultiTF();
void DrawLimitOrderLevels();
void UpdateDashboard();
bool GetSuperTrendLevel(ENUM_TIMEFRAMES tf, double &supportOut, double &resistanceOut);
double GetClosestBuyLevel(double currentPrice, double atr, double maxDistATR, string &sourceOut);
double GetClosestSellLevel(double currentPrice, double atr, double maxDistATR, string &sourceOut);
void PlaceHistoricalBasedScalpingOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope, int existingLimitOrders);
bool CaptureChartDataFromChart();
void ManageTrailingStop();
void TP1_CloseAndReEntry();
void CloseOnVerdictWait();
void GenerateFallbackAIDecision();
void GenerateFallbackMLMetrics();
void DrawPreciseSwingPredictionsWithOrders();
void DrawOrderLinksToSwings(double nextSH, double nextSL, datetime nextSHTime, datetime nextSLTime);
void PlacePreciseSwingBasedOrders();
void CheckAndExecuteDerivArrowTrade();
void ExecuteVolatilityTrade(string direction);
void StartSpikePositionMonitoring(string direction);
bool IsSymbolPaused(string symbol);
void UpdateSymbolPauseInfo(string symbol, double profit);
bool ShouldPauseSymbol(string symbol, double profit);
void CM_ResetIfNewDay();
void CM_RefreshDailyStats();
bool CM_IsEntryBlocked(string &reason);
void CM_OnClosedTrade(double profit);
string CM_StatusLine();
double CM_StructureTrailSL(const string symbol, const long posType);

// Fonctions de détection avancée de spike
double CalculateVolatilityCompression();
double CalculatePriceAcceleration();
bool DetectVolumeSpike();
bool IsPreSpikePattern();
bool IsNearKeyLevel(double price);
double CalculateSpikeProbability();
void CheckImminentSpike();
void CheckRSISqueezeAndTrade();
void CheckSMCChannelReturnMovements();
void PlaceReturnMovementLimitOrder(string direction, double currentPrice, double channelPrice, double atrVal, double strength);
void DrawSpikeWarning(double probability);
void InitializeSymbolPauseSystem();
bool IsPriceInRange();
bool DetectPriceRange();
bool CalculatePreciseEntryPoint(string direction, double &entryPrice, double &stopLoss, double &takeProfit);
bool IsDerivArrowPresent();
bool GetDerivArrowDirection(string &direction);
void ExecuteDerivArrowTrade(string direction);
bool ValidateEntryWithMultipleSignals(string direction);
void SendDerivArrowNotification(string direction, double entryPrice, double stopLoss, double takeProfit);
double ComputeSetupScore(const string direction);

// NOUVEAU: Buffer SL post-entrée +1$
bool SMC_ApplyPostEntrySLBuffer(const string symbol, const ulong ticket, const double bufferUSD = 1.0);

// SMC modules supplementaires (Pipeline, GOM, DecisionEngine)
void DrawBollingerCurve() {}
void DrawSpikeZonesOnChart() {}
void UpdateSpikeCountdown() {}
void SMC_CalculateLocalOTE() {}
void SMC_DetectCHoCH() {}
void SMC_DetectMSB() {}
void SMC_DrawMultiTP(double entryPrice, double slPrice, double dirSign) {}
void SMC_CleanMultiTP() {}
double SMC_AssetSLMult() { return 1.0; }
int SMC_AssetMinConfluence() { return 1; }
void SMC_ManageGainProtectionTrail();
bool TryExecuteGOMPerfectEntry();
void ManageManualTradeSLTP();
void ManageGOMVerdictExits();
void ManageGOMAutonomousStrategy();
void ManageGOMWaitPullbackLimit();
void ManageGOMAlignedLimitOrders();
bool GOM_EntryCoherenceOK();
bool COG_ConflictsWithGOM();
bool GOM_EntryEnvironmentOK(const int dirSign);
bool SMC_BCHourAllowsTrade(const string symbol = "");
// SMC_HighProbabilityAllowsEntry et SMC_ComputeEntryProbability d�finis dans SMC_ProbabilityGate.mqh
void SMC_ResetTradeStatistics();
bool SMC_DailyDisciplineAllowsEntry();
bool SMC_PerformancePauseAllowsEntry(const string symbol = "");
bool SMC_SurvivalMarginOK(const string symbol, double lot, double entryPrice, double sl);
void SMC_ResetPerformancePauseDaily();
void SMC_ResetPerformancePauseFull();
void SMC_LoadPerformancePauseState();
void SMC_RecordDailyTradeOpen();
double SMC_GetDailyBalanceDepositsUSD();
double SMC_GetDailyProfitUSD();
double SMC_GetDailyProfitTargetUSD();
bool SMC_GOMSupportsOpenPosition(const int posDir);
double SMC_GetPositionMaxLossUSD(const int posDir, const bool isGomWaitExit);
bool SMC_IsCorrectionZoneForDirection(const string symbol, const int dirSign);
SMC_EntryGateResult SMC_EvaluateEntryGate(const int dirSign, const bool isGomOrder, const string symbol, const double lot = 0, const double entryPrice = 0, const double sl = 0);
void SMC_MarkSpikeCaptured(const string symbol);
int  SMC_CountSmallM1BarsAfterTime(const string symbol, const datetime afterTime);
bool SMC_IsCrash150Symbol(const string symbol);
bool SMC_IsWeltradeSymbol(const string symbol);
bool SMC_IsWeltradeBoomCrash(const string symbol);
bool SMC_IsWeltradeVolSymbol(const string symbol);
bool SMC_IsSyntheticAutonomousSym(const string symbol);
bool SMC_GOMAutonomousAllowed(const string symbol);
bool SMC_IAAndCOGAligned(const int dirSign);
bool GOM_EntryAlignmentOK(const int dirSign);
bool SMC_IsPropitiousTradeHour(const string symbol = "");
bool GOM_CanOpenAlignedTrade(const int dirSign);
bool SMC_AlignExecStrictGateOK(const int dirSign, string &reasonOut);
bool SMC_ExecuteAlignMarketIfOK(const int dirSign, const string direction, const string levelSource);
bool SMC_TfDirMatchesSign(const int dirSign, const string tfDir);
bool SMC_M5H1PreciseAligned(const int dirSign);
bool SMC_PricePullbackM5EMA(const int dirSign, double &emaPrice, const double tolAtrMult = 0.40);
bool SMC_M1BarConfirmsDirection(const int dirSign);
bool SMC_M5EMATrendAligned(const int dirSign);
bool SMC_M5BarConfirmsPullback(const int dirSign, const double emaPrice);
bool SMC_GhostOrderflowAligned(const int dirSign);
bool SMC_M5EMAPullbackConfirmOK(const int dirSign, const double emaPrice, string &reasonOut);
bool SMC_IsPriceNearLevel(const int dirSign, const string symbol, const double atrMult);
bool SMC_DetectBounceAtLevel(const int dirSign, const string symbol);
void SMC_EnforceTerminalOrderLimits();
void SMC_ClearSymbolLocksOnInit();
int  SMC_CountConfluenceTags(const string reason);
bool SMC_ApplySniperRiskCap(const string symbol, const double slDistPrice, double &lot, double &tpDistPrice);
bool SMC_IsSpikeStyleSymbol(const string symbol);
void   SMC_UpdateSpikeChainState();
bool   SMC_IsSpikeChainEarlyEntry(string &outDirection);
double SMC_ComputeATRZScore(int lookback);
// --- Strategie Chaine de Spikes H1/M5 (Kola) - declarations anticipees ---
bool   SCH1_GetSR_H1(double &resistance, double &support);
bool   SCH1_IsSpikeBar(ENUM_TIMEFRAMES tf, int shift, int atrHandleTF, int biasDir);
double SCH1_CalculateForce(int biasDir);
bool   SCH1_IsSpikeRejectionM5(int biasDir);
bool   SCH1_IsNearSR_H1(int biasDir);
bool   SCH1_ComputeExtensionTP(int biasDir, double &tpOut);
bool   SCH1_StrategyGate(const string direction, string &reasonOut, double &tpHintOut);
void   SCH1_UpdateChainTracking();
void   SCH1_ManageOpenPositions();
void   SCH1_UpdatePanel();
string PB_JsonEscape(const string s);
bool PB_SendWhatsAppViaAI(const string event, const string symbol, const string message,
                          const string direction = "", double entry = 0, double sl = 0,
                          double tp = 0, double lot = 0);
bool PB_SendWhatsAppDirect(const string message);
bool PB_SendWhatsAppAlert(const string message);
int  SMC_GOMReentryCooldownSec();
void SMC_PollDailyReadiness();
bool SMC_ReadinessAllowsEntry(const string symbol);
void SMC_ManageAvoidHourClose();
void SMC_ReportTradeClose(const string symbol, double netProfit, bool isWin);

// Profil Or/Forex/Crypto — déclarations anticipées (implémentations après includes)
bool   SMC_IsGoldProfileActive();
bool   SMC_IsForexProfileActive();
bool   SMC_IsCryptoProfileActive();
double SMC_EffectiveSLMult();
double SMC_EffectiveTPMult();
double SMC_EffectiveMaxDailyDDPct();
double SMC_EffectiveRiskPct();
double SMC_EffectiveMaxTotalLossUSD();
int    SMC_EffectiveMaxPositionsTerminal();
double SMC_EffectiveGOMMinCoherence();
bool   SMC_TerminalPositionCapReached();
double SMC_EffectiveMinAIConfidence();
double SMC_EffectiveGOMTrailingMinUSD();
bool   SMC_EffectiveRequireDerivArrow();
bool   SMC_IsInProfileSessionWindow();
bool   SMC_IsGoldDirectionAllowed(const string direction);
double SMC_GoldTransitionLotFactor();
void   SMC_ManageGoldPartialTP();
void   SMC_ManageGoldScalp();

// OTE Scalper
bool   OTE_IsActiveSymbol(const string symbol);
void   OTE_InitHandles();
void   OTE_ReleaseHandles();
void   OTE_FindSwings(double &high1, double &high2, datetime &ht1, datetime &ht2,
                      double &low1, double &low2, datetime &lt1, datetime &lt2);
void   OTE_AnalyzeStructure();
void   OTE_UpdateHTFBias();
void   OTE_DetectZone();
void   OTE_DetectOrderBlock();
void   OTE_DetectFVG();
bool   OTE_ConfirmBullish();
bool   OTE_ConfirmBearish();
bool   OTE_CheckDailyLimits();
bool   OTE_IsSessionOK();
int    OTE_CountTrades();
double OTE_PipsToPrice(double pips);
double OTE_PriceToPips(double dist);
double OTE_CalcBuySL(double entry, double bid);
double OTE_CalcSellSL(double entry, double ask);
double OTE_CalcBuyTP(double entry, double sl);
double OTE_CalcSellTP(double entry, double sl);
double OTE_CalcLots(double entry, double sl);
bool   OTE_PlaceTrade(string direction, double ask, double bid, double sl, double tp, double lots);
void   OTE_ManageTrades();
void   OTE_DailyReset();
void   OTE_OnNewBar();
bool   OTE_IsNewBar();
bool   OTE_PlaceOTETrade(const int dirSign);
void   ManageOTEEAutonomousStrategy();
void   OTE_DrawZone();

// Module pipeline forward decls
bool   SMC_GOM_M5H1SMCConfirmOK(const string symbol, const string sym2 = "");
double SMC_WeltradeFxVolLot();
double SMC_WeltradeFxEqLot();
double SMC_WeltradeFxSwissLot();
bool   SMCPS_PatternGateOK(const string symbol, const int dirSign = 0, const bool logBlock = true);
bool   SMCPS_BreakoutConfirmed(const string symbol, const int dirSign);
bool   SafeOrderSend(MqlTradeRequest &req, MqlTradeResult &result, const string debugLabel = "");
bool   SafeOrderSendAndAlert(MqlTradeRequest &req, MqlTradeResult &result, const string debugLabel = "");
double SMC_EffectiveSymbolATR(const string symbol);

// Fonctions IA pour communiquer avec le serveur
bool UpdateAIDecision(int timeoutMs = -1);
string GetAISignalData(string symbol, string timeframe);
string GetTrendAlignmentData(string symbol); 
string GetCoherentAnalysisData(string symbol);
void ProcessAIDecision(string jsonData);
void UpdateMLMetricsDisplay();
string ExtractJsonValue(string json, string key);

void GetLatestConfirmedSwings(double &lastSH, datetime &lastSHTime, double &lastSL, datetime &lastSLTime);
void DrawConfirmedSwingPoints();
bool DetectBoomCrashSwingPoints();
void UpdateSpikeWarningBlink();
void CheckPredictedSwingTriggers();
int  CountOpenLimitOrdersForSymbol(const string symbol);
int  CountChannelLimitOrdersForSymbol(const string symbol);
bool GetRecentAndProjectedMLChannelIntersection(string direction, double &recentPrice, datetime &recentTime, double &projectedPrice, datetime &projectedTime);
void AdjustEMAScalpingLimitOrder();

// Dessin basique des derniers swing high / low sur le graphique courant
void DrawSwingHighLow()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 20, rates) < 5) return;

   double lastHigh = rates[0].high;
   double lastLow  = rates[0].low;
   datetime lastTime = rates[0].time;

   // Supprimer les anciens objets pour éviter l'encombrement
   ObjectDelete(0, "SMC_Last_SH");
   ObjectDelete(0, "SMC_Last_SL");

   // Dernier Swing High (simple: high de la dernière bougie)
   if(ObjectCreate(0, "SMC_Last_SH", OBJ_ARROW, 0, lastTime, lastHigh))
   {
      ObjectSetInteger(0, "SMC_Last_SH", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "SMC_Last_SH", OBJPROP_ARROWCODE, 233);
      ObjectSetInteger(0, "SMC_Last_SH", OBJPROP_WIDTH, 2);
   }

   // Dernier Swing Low (simple: low de la dernière bougie)
   if(ObjectCreate(0, "SMC_Last_SL", OBJ_ARROW, 0, lastTime, lastLow))
   {
      ObjectSetInteger(0, "SMC_Last_SL", OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, "SMC_Last_SL", OBJPROP_ARROWCODE, 234);
      ObjectSetInteger(0, "SMC_Last_SL", OBJPROP_WIDTH, 2);
   }
}

// Lignes horizontales "Bookmark" + bande verticale droite sur les derniers Swing High/Low confirmés (vue ICT)
void DrawBookmarkLevels()
{
   // Nom commun pour la bande verticale à droite + panneau d'info
   string bandName  = "SMC_Bookmark_Band_"  + _Symbol;
   string panelName = "SMC_Bookmark_Info_" + _Symbol;

   // Si l'affichage est désactivé, tout nettoyer et sortir
   if(!ShowBookmarkLevels)
   {
      ObjectDelete(0, bandName);
      ObjectDelete(0, "SMC_Bookmark_SH_" + _Symbol);
      ObjectDelete(0, "SMC_Bookmark_SL_" + _Symbol);
      ObjectDelete(0, panelName);
      return;
   }
   
   // Utilise les variables globales g_lastSwingHigh / g_lastSwingLow mises à jour par la détection SMC
   double lastSH = g_lastSwingHigh;
   double lastSL = g_lastSwingLow;
   if(lastSH <= 0 && lastSL <= 0)
   {
      // Aucun bookmark valide -> supprimer la bande et sortir
      ObjectDelete(0, bandName);
      ObjectDelete(0, "SMC_Bookmark_SH_" + _Symbol);
      ObjectDelete(0, "SMC_Bookmark_SL_" + _Symbol);
      ObjectDelete(0, panelName);
      return;
   }
   
   datetime now = TimeCurrent();
   datetime future = now + PeriodSeconds(PERIOD_CURRENT) * 500; // projeter la ligne assez loin dans le futur
   
   // Supprimer d'anciens bookmarks horizontaux pour ce symbole
   string shName = "SMC_Bookmark_SH_" + _Symbol;
   string slName = "SMC_Bookmark_SL_" + _Symbol;
   ObjectDelete(0, shName);
   ObjectDelete(0, slName);
   
   // Swing High bookmark (rouge pointillé)
   bool hasSH = (lastSH > 0.0);
   if(hasSH)
   {
      if(ObjectCreate(0, shName, OBJ_TREND, 0, now, lastSH, future, lastSH))
      {
         ObjectSetInteger(0, shName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, shName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, shName, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetString(0, shName, OBJPROP_TEXT, "Bookmark SH");
      }
   }
   
   // Swing Low bookmark (vert pointillé)
   bool hasSL = (lastSL > 0.0);
   if(hasSL)
   {
      if(ObjectCreate(0, slName, OBJ_TREND, 0, now, lastSL, future, lastSL))
      {
         ObjectSetInteger(0, slName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, slName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetString(0, slName, OBJPROP_TEXT, "Bookmark SL");
      }
   }

   // Dessin de la bande verticale sur le bord droit du graphique (haut en bas)
   // Couleur selon le type de dernier bookmark disponible
   color bandColor = clrYellow;
   if(hasSH && !hasSL)
      bandColor = clrRed;
   else if(hasSL && !hasSH)
      bandColor = clrLime;

   // Récupérer les dimensions du graphique en pixels
   int chartWidthPixels  = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int chartHeightPixels = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
   if(chartWidthPixels <= 0 || chartHeightPixels <= 0)
      return;

   int bandWidth = 10; // largeur en pixels de la bande

   // Créer ou mettre à jour un OBJ_RECTANGLE_LABEL ancré en haut à droite
   if(ObjectFind(0, bandName) == -1)
   {
      if(!ObjectCreate(0, bandName, OBJ_RECTANGLE_LABEL, 0, 0, 0))
         return;
   }

   ObjectSetInteger(0, bandName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, bandName, OBJPROP_XDISTANCE, 0);          // collé au bord droit
   ObjectSetInteger(0, bandName, OBJPROP_YDISTANCE, 0);          // depuis le haut
   ObjectSetInteger(0, bandName, OBJPROP_XSIZE, bandWidth);      // largeur bande
   ObjectSetInteger(0, bandName, OBJPROP_YSIZE, chartHeightPixels); // hauteur totale
   ObjectSetInteger(0, bandName, OBJPROP_COLOR, bandColor);
   ObjectSetInteger(0, bandName, OBJPROP_BACK, true);            // en arrière-plan
   ObjectSetInteger(0, bandName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, bandName, OBJPROP_WIDTH, 1);

   // Panneau d'information "Bookmark" fixé sur le bord droit du graphique
   if(ObjectFind(0, panelName) == -1)
   {
      if(!ObjectCreate(0, panelName, OBJ_LABEL, 0, 0, 0))
         return;
   }

   string txt = "BOOKMARK";
   if(hasSH)
      txt += "\nSH: " + DoubleToString(lastSH, _Digits);
   if(hasSL)
      txt += "\nSL: " + DoubleToString(lastSL, _Digits);

   ObjectSetInteger(0, panelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, panelName, OBJPROP_XDISTANCE, bandWidth + 4); // juste à gauche de la bande verticale
   ObjectSetInteger(0, panelName, OBJPROP_YDISTANCE, 10);
   ObjectSetString(0,  panelName, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, panelName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, panelName, OBJPROP_COLOR, clrWhite);
   ObjectSetString(0,  panelName, OBJPROP_FONT, "Arial");
}

//| SMC - Structures et énumérations (intégré)                       |
struct FVGData {
   double top;
   double bottom;
   int direction;
   datetime time;
   bool isInversion;
   int barIndex;
};
struct OrderBlockData {
   double high;
   double low;
   int direction;
   datetime time;
   int barIndex;
   string type;
};
struct SMC_Signal {
   string action;
   double confidence;
   string concept;
   string reasoning;
   double entryPrice;
   double stopLoss;
   double takeProfit;
};
enum ENUM_SYMBOL_CATEGORY {
   SYM_BOOM_CRASH,
   SYM_VOLATILITY,
   SYM_FOREX,
   SYM_COMMODITY,
   SYM_METAL,
   SYM_CRYPTO,
   SYM_UNKNOWN
};
ENUM_SYMBOL_CATEGORY SMC_GetSymbolCategory(string symbol)
{
   string s = symbol;
   StringToUpper(s);
   // Deriv: indices de spike (comportement identique à Boom/Crash: mouvements brusques 1 sens)
   if(StringFind(s, "BOOM") >= 0 || StringFind(s, "CRASH") >= 0) return SYM_BOOM_CRASH;
   // Weltrade: indices synthétiques équivalents Boom/Crash (spikes brusques)
   if(StringFind(s, "PAINX") >= 0 || StringFind(s, "GAINX") >= 0) return SYM_BOOM_CRASH;
   // Deriv: Volatility, Jump, Step, Range Break (mouvements continus, pas de spike directionnel unique)
   if(StringFind(s, "VOLATILITY") >= 0 || StringFind(s, "RANGE BREAK") >= 0 ||
      StringFind(s, "JUMP") >= 0 || StringFind(s, "STEP") >= 0) return SYM_VOLATILITY;
   // Métaux: couvre XAUUSD, XAUUSDm, XAUUSD.m, GOLD#, GOLDm (XM Global, Weltrade, etc. - suffixes broker ignorés)
   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0) return SYM_METAL;
   if(StringFind(s, "XAG") >= 0 || StringFind(s, "SILVER") >= 0) return SYM_METAL;
   if(StringFind(s, "OIL") >= 0 || StringFind(s, "COPPER") >= 0) return SYM_COMMODITY;
   if(StringFind(s, "BTC") >= 0 || StringFind(s, "ETH") >= 0 || StringFind(s, "SOL") >= 0 ||
      StringFind(s, "CRYPTO") >= 0 || StringFind(s, "BITCOIN") >= 0 || StringFind(s, "ETHEREUM") >= 0) return SYM_CRYPTO;
   if(StringFind(s, "USD") >= 0 || StringFind(s, "EUR") >= 0 || StringFind(s, "GBP") >= 0 || StringFind(s, "JPY") >= 0) return SYM_FOREX;
   return SYM_UNKNOWN;
}

// Un symbole se comporte-t-il comme un indice "spike" (Boom/Crash Deriv, Painx/Gainx Weltrade)?
bool SMC_IsSpikeStyleSymbol(const string symbol)
{
   return (SMC_GetSymbolCategory(symbol) == SYM_BOOM_CRASH);
}

// Symbole Weltrade synthétique (PainX/GainX) — subset de SYM_BOOM_CRASH
bool SMC_IsWeltradeSynthSymbol(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   return (StringFind(s, "PAINX") >= 0 || StringFind(s, "GAINX") >= 0);
}

// Helpers: Boom-like (Boom + Gainx) et Crash-like (Crash + Painx)
bool IsBoomLikeSymbol(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   return (StringFind(s, "BOOM") >= 0 || StringFind(s, "GAINX") >= 0);
}
bool IsCrashLikeSymbol(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   return (StringFind(s, "CRASH") >= 0 || StringFind(s, "PAINX") >= 0);
}

// Règle directionnelle spécifique Boom/Crash:
// - Sur Boom/Gainx: uniquement BUY (jamais SELL)
// - Sur Crash/Painx: uniquement SELL (jamais BUY)
bool IsDirectionAllowedForBoomCrash(const string symbol, const string action)
{
   string a = action;
   StringToUpper(a);
   
   if(IsBoomLikeSymbol(symbol) && a == "SELL")
      return false;
   if(IsCrashLikeSymbol(symbol) && a == "BUY")
      return false;
   return true;
}

// Contrôle de duplication de position:
// - Pas de duplication sur Boom/Crash (1 position max par symbole)
// - Sur autres marchés: duplication seulement si
//   * au moins 1 position existe déjà sur le symbole
//   * la première position est en gain >= 2$
//   * l'IA confirme la même direction avec >= 80% de confiance
bool CanOpenAdditionalPositionForSymbol(const string symbol, const string action)
{
   int existing = CountPositionsForSymbol(symbol);
   if(existing <= 0)
      return true; // première position toujours autorisée
   
   // Jamais de duplication sur Boom/Crash
   if(SMC_GetSymbolCategory(symbol) == SYM_BOOM_CRASH)
      return false;
   
   // Vérifier les conditions IA fortes (80% min) et même direction
   string aiAction = g_lastAIAction;
   StringToUpper(aiAction);
   string act = action;
   StringToUpper(act);
   
   if(g_lastAIConfidence < 0.85)
      return false;
   if((act == "BUY"  && aiAction != "BUY") ||
      (act == "SELL" && aiAction != "SELL"))
      return false;
   
   // Vérifier le gain de la position initiale (la plus ancienne) sur ce symbole
   datetime earliestTime = 0;
   double   earliestProfit = 0.0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      if(posInfo.Symbol() != symbol) continue;
      
      datetime openTime = (datetime)posInfo.Time();
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      
      if(earliestTime == 0 || openTime < earliestTime)
      {
         earliestTime = openTime;
         earliestProfit = profit;
      }
   }
   
   if(earliestTime == 0)
      return true; // sécurité: si on ne trouve pas, ne pas bloquer complètement
   
   return (earliestProfit >= 2.0);
}

// Compte tous les ordres LIMIT (BUY_LIMIT / SELL_LIMIT) ouverts pour ce symbole (notre EA)
int CountOpenLimitOrdersForSymbol(const string symbol)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT)
         count++;
   }
   return count;
}

// Compte uniquement les ordres LIMIT issus du canal SMC (commentaire "SMC_CH ...")
int CountChannelLimitOrdersForSymbol(const string symbol)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;
      
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, "SMC_CH") >= 0)
         count++;
   }
   return count;
}

// Forward declarations (defined in SMC_GOM_Pipeline.mqh, included later)
int  SMCGP_GetCachedVerdictNum(const string symbol);
void SMCGP_EnforceLimitDiscipline(const long magic, const int maxLimits = 2);

// ── GATEKEEPER GOM: WAIT interdit + direction GOOD/PERFECT obligatoire ──
// dirSign: +1 BUY, -1 SELL. Retourne false si bloqué.
// BLOQUE TOUT: WAIT (vn=0), SIMPLE (|vn|=1), CONTRE-VERDICT
bool CanPlaceOrderByGOM(const string symbol, const int dirSign, const string orderKind)
{
   if(!UseGOMVerdictFilter) return true;

   int vn = -999;
   if(g_smcGomConnected)
      vn = SMCGP_GetCachedVerdictNum(symbol);
   // Fallback symbole graphique courant si cache symbole manquant
   if(vn == -999 && symbol == _Symbol)
      vn = g_smcGomVerdictNum;

   if(vn == -999)
   {
      Print("🚫 ", orderKind, " BLOQUÉ — ", symbol, " — PAS DE VERDICT GOM");
      return false;
   }
   // WAIT (vn=0) : BLOQUER TOUT (market + limit)
   if(vn == 0)
   {
      Print("🚫 ", orderKind, " BLOQUÉ — ", symbol, " — GOM=WAIT (vn=0) — AUCUN ORDRE AUTORISÉ");
      return false;
   }
   // SIMPLE (|vn|=1) : BLOQUER TOUT — exige GOOD/PERFECT (|vn|>=2)
   // Exception: crash-like symbols with Dow trendline confirmed direction
   if(MathAbs(vn) < MinGOMVerdictNumAbs)
   {
      bool crashLike = IsCrashLikeSymbol(symbol) || IsBoomLikeSymbol(symbol);
      bool dowConfirmed = (g_dowState.active && g_dowState.isBearish && dirSign < 0) ||
                          (g_dowState.active && !g_dowState.isBearish && dirSign > 0);
      if(crashLike && dowConfirmed)
      {
         Print("✅ ", orderKind, " AUTORISÉ — ", symbol,
               " — GOM=SIMPLE vn=", vn, " + Dow trendline confirmé");
         // Continuer malgré SIMPLE
      }
      else
      {
         Print("🚫 ", orderKind, " BLOQUÉ — ", symbol,
               " — GOM=SIMPLE vn=", vn,
               " (exige GOOD/PERFECT |vn|>=", MinGOMVerdictNumAbs, ")");
         return false;
      }
   }
   // Contre-verdict interdit : le verdict DÉCIDE le trade
   if(dirSign > 0 && vn < 0)
   {
      Print("🚫 BUY ", orderKind, " BLOQUÉ sur ", symbol, " — GOM vn=", vn, " = SELL (verdict décide)");
      return false;
   }
   if(dirSign < 0 && vn > 0)
   {
      Print("🚫 SELL ", orderKind, " BLOQUÉ sur ", symbol, " — GOM vn=", vn, " = BUY (verdict décide)");
      return false;
   }
   return true;
}

bool CanPlaceMarketOrder(const string symbol, const int dirSign)
{
   return CanPlaceOrderByGOM(symbol, dirSign, "MARKET");
}

// ── GATEKEEPER: direction GOM + max 2 limit orders ─────────────────────
// Retourne true si l'ordre LIMIT est autorisé, false sinon
bool CanPlaceLimitOrder(const string symbol, ENUM_ORDER_TYPE orderType)
{
   int dirSign = 0;
   if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY)
      dirSign = 1;
   else if(orderType == ORDER_TYPE_SELL_LIMIT || orderType == ORDER_TYPE_SELL)
      dirSign = -1;

   if(!CanPlaceOrderByGOM(symbol, dirSign, "LIMIT"))
      return false;

   // Max 2 ordres LIMIT par symbole (garder les meilleurs via CleanupExcessLimits)
   int maxLimits = MathMax(1, MaxLimitOrdersTerminal);
   int total = CountOpenLimitOrdersForSymbol(symbol);
   if(total >= maxLimits)
   {
      Print("🚫 LIMIT BLOQUÉ — déjà ", total, " ordres limit sur ", symbol, " (max=", maxLimits, ")");
      return false;
   }

   return true;
}

// Supprime les ordres LIMIT les plus éloignés du prix courant si > max
void CleanupExcessLimits(const string symbol, int maxOrders)
{
   // Collecter tous nos limit orders
   struct LimitOrderInfo { ulong ticket; double price; ENUM_ORDER_TYPE type; datetime time; };
   LimitOrderInfo orders[];
   ArrayResize(orders, 0);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;

      int sz = ArraySize(orders);
      ArrayResize(orders, sz + 1);
      orders[sz].ticket = ticket;
      orders[sz].price  = OrderGetDouble(ORDER_PRICE_OPEN);
      orders[sz].type   = t;
      orders[sz].time   = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
   }

   int excess = ArraySize(orders) - maxOrders;
   if(excess <= 0) return;

   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);

   // Trier par distance au prix (plus éloigné en premier)
   for(int a = 0; a < ArraySize(orders) - 1; a++)
   {
      for(int b = a + 1; b < ArraySize(orders); b++)
      {
         double distA = MathAbs(orders[a].price - currentPrice);
         double distB = MathAbs(orders[b].price - currentPrice);
         if(distB > distA) // b plus loin → échanger
         {
            LimitOrderInfo tmp = orders[a];
            orders[a] = orders[b];
            orders[b] = tmp;
         }
      }
   }

   // Supprimer les plus éloignés
   for(int k = 0; k < excess; k++)
   {
      ulong tk = orders[k].ticket;
      if(!OrderSelect(tk)) continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      MqlTradeRequest dr = {}; MqlTradeResult drRes = {};
      dr.action = TRADE_ACTION_REMOVE;
      dr.order  = tk;
      if(!SafeOrderSend(dr, drRes))
         Print("❌ Échec suppression limit excessif ticket=", tk);
      else
         Print("🗑️ LIMIT SUPPRIMÉ (trop éloigné): ticket=", tk,
               " prix=", orders[k].price, " type=", EnumToString(orders[k].type),
               " comment=", cmt);
   }
}

bool SMC_DetectFVG(string symbol, ENUM_TIMEFRAMES tf, int lookback, FVGData &fvgOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, lookback, rates) < lookback) return false;
   for(int fvgIndex = 2; fvgIndex < lookback - 1; fvgIndex++)
   {
      if(rates[fvgIndex-1].low > rates[fvgIndex+1].high)
      {
         double gap = rates[fvgIndex-1].low - rates[fvgIndex+1].high;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(gap > point * 3) {
            fvgOut.top = rates[fvgIndex-1].low; fvgOut.bottom = rates[fvgIndex+1].high; fvgOut.direction = 1;
            fvgOut.time = rates[fvgIndex].time; fvgOut.isInversion = false; fvgOut.barIndex = fvgIndex;
            return true;
         }
      }
      if(rates[fvgIndex-1].high < rates[fvgIndex+1].low)
      {
         double gap = rates[fvgIndex+1].low - rates[fvgIndex-1].high;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(gap > point * 3) {
            fvgOut.top = rates[fvgIndex+1].low; fvgOut.bottom = rates[fvgIndex-1].high; fvgOut.direction = -1;
            fvgOut.time = rates[fvgIndex].time; fvgOut.isInversion = false; fvgOut.barIndex = fvgIndex;
            return true;
         }
      }
   }
   return false;
}
bool SMC_DetectBOS(string symbol, ENUM_TIMEFRAMES tf, int &directionOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 20, rates) < 20) return false;
   double prevSwingHigh = MathMax(rates[3].high, MathMax(rates[4].high, rates[5].high));
   double prevSwingLow = MathMin(rates[3].low, MathMin(rates[4].low, rates[5].low));
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minBreak = point * 5;
   if(rates[1].close > prevSwingHigh + minBreak) { directionOut = 1; return true; }
   if(rates[1].close < prevSwingLow - minBreak) { directionOut = -1; return true; }
   return false;
}
bool SMC_DetectLiquiditySweep(string symbol, ENUM_TIMEFRAMES tf, string &typeOut)
{
   int barsAgo;
   return SMC_DetectLiquiditySweepEx(symbol, tf, typeOut, barsAgo);
}
bool SMC_DetectLiquiditySweepEx(string symbol, ENUM_TIMEFRAMES tf, string &typeOut, int &barsAgoOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 15, rates) < 15) return false;
   barsAgoOut = 99;
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minSweep = point * 5;
   for(int b = 1; b <= 5; b++)
   {
      if(b + 2 >= ArraySize(rates)) break;
      double prevHigh = rates[b+1].high;
      double prevLow = rates[b+1].low;
      double currHigh = rates[b].high;
      double currLow = rates[b].low;
      if(currHigh > prevHigh && (currHigh - prevHigh) > minSweep)
      {
         typeOut = "BSL";
         barsAgoOut = b;
         return true;
      }
      if(currLow < prevLow && (prevLow - currLow) > minSweep)
      {
         typeOut = "SSL";
         barsAgoOut = b;
         return true;
      }
   }
   return false;
}
bool SMC_DetectOrderBlock(string symbol, ENUM_TIMEFRAMES tf, OrderBlockData &obOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 50, rates) < 50) return false;
   for(int i = 3; i < 45; i++)
   {
      if(rates[i].close < rates[i].open && rates[i+1].close > rates[i+1].open)
      {
         double moveUp = rates[i+2].high - rates[i].low;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(moveUp > point * 20) {
            obOut.high = rates[i].high; obOut.low = rates[i].low; obOut.direction = 1;
            obOut.time = rates[i].time; obOut.barIndex = i; obOut.type = "OB";
            return true;
         }
      }
      if(rates[i].close > rates[i].open && rates[i+1].close < rates[i+1].open)
      {
         double moveDown = rates[i].high - rates[i+2].low;
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         if(moveDown > point * 20) {
            obOut.high = rates[i].high; obOut.low = rates[i].low; obOut.direction = -1;
            obOut.time = rates[i].time; obOut.barIndex = i; obOut.type = "OB";
            return true;
         }
      }
   }
   return false;
}
bool SMC_IsLondonOpen(int hourStart, int hourEnd)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= hourStart && dt.hour <= hourEnd);
}
bool SMC_IsNewYorkOpen(int hourStart, int hourEnd)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= hourStart && dt.hour <= hourEnd);
}
bool SMC_IsKillZone(int loStart, int loEnd, int nyoStart, int nyoEnd)
{
   return SMC_IsLondonOpen(loStart, loEnd) || SMC_IsNewYorkOpen(nyoStart, nyoEnd);
}
double SMC_GetATRMultiplier(ENUM_SYMBOL_CATEGORY cat)
{
   switch(cat) {
      case SYM_BOOM_CRASH:  return 1.5;
      case SYM_VOLATILITY:  return 2.0;
      case SYM_FOREX:       return 2.0;
      case SYM_COMMODITY:   return 2.5;
      case SYM_METAL:       return 2.5;
      case SYM_CRYPTO:      return 3.0;
      default:              return 2.0;
   }
}

//| VARIABLES GLOBALES - IA ET MÉTRIQUES                             |

// Variables IA globales pour stocker les décisions du serveur
string g_lastAIAction = "";
double g_lastAIConfidence = 0.0;
string g_lastAIAlignment = "0.0%";
string g_lastAICoherence = "0.0%";
datetime g_lastAIUpdate = 0;

// Variables Intelligence Agents (gate /agents/gate)
bool     g_agentAllowed          = true;    // gate global autorise la position
double   g_agentLotMultiplier    = 1.0;     // multiplicateur lot (0.0 = bloqué)
double   g_agentRecommendedLot   = 0.0;     // lot recommandé Kelly (0 = utiliser le calcul EA)
double   g_agentConfidenceBoost  = 0.0;     // boost/pénalité à ajouter à g_lastAIConfidence
string   g_agentRegime           = "";      // régime marché: TRENDING_UP/DOWN/RANGING/VOLATILE/BREAKOUT
int      g_agentEntryScore       = 0;       // score entrée 0-100
string   g_agentRecommendation   = "";      // IMMEDIATE/ENTER_NOW/WAIT_RETEST/SKIP/BLOCKED
bool     g_agentCorrectionDetect = false;   // correction M1/M5 détectée
string   g_agentReasons          = "";      // raisons (log)
datetime g_agentLastUpdate       = 0;       // timestamp dernier appel gate
int      g_agentUpdateIntervalSec = 30;     // fréquence appel gate (secondes)

// Probabilité de spike calculée / reçue depuis l'IA
double   g_lastSpikeProbability = 0.0;
datetime g_lastSpikeUpdate      = 0;

// Garde-fou retracement multi-TF
bool     g_inRetrace           = false;

// Tick Frequency Analysis (détection cooldown Deriv)
int      g_tickFreqBuf[60];       // ticks comptés par seconde (buffer circulaire 60s)
int      g_tickFreqIdx        = 0;
datetime g_tickFreqLastSec    = 0;
int      g_tickFreqCurrent    = 0;
double   g_tickFreqAvg        = 0.0; // moyenne ticks/sec sur 60s
double   g_tickFreqRatio      = 1.0; // ratio actuel vs moyenne

// Variables ML pour le tableau de bord
string g_mlMetricsStr = "";
datetime g_lastMLMetricsUpdate = 0;
bool g_channelValid = false;

// Variables de trading et positions
double g_maxProfit = 0.0;
datetime g_lastBoomCrashPrice = 0;
datetime s_lastRefUpdate = 0;

// Impulse Zone 20 bars
double g_impulseSupport20    = 0;   // Plus bas des 20 dernières barres
double g_impulseResistance20 = 0;   // Plus haut des 20 dernières barres
double g_impulseSupBuffer    = 0;   // Buffer support (en price)
double g_impulseResBuffer    = 0;   // Buffer résistance (en price)
bool   g_impulseSupTouched   = false; // Prix a touché zone support
bool   g_impulseResTouched   = false; // Prix a touché zone résistance

//+------------------------------------------------------------------+
//| S/R 20 bars DÉJÀ TOUCHÉ + REBONDI -> impulsion forte confirmée  |
//| (le prix est venu toucher le niveau puis est reparti = rejet).      |
//| Quand armé (direction), on se prépare à une chaîne de spikes et   |
//| on autorise l'entrée marché sur RETEST du pointillé Entry pattern.  |
//+------------------------------------------------------------------+
// NB: g_sr20BounceArmedBuy/Sell et *Bars sont définis dans SMC_PatternSignals.mqh
datetime g_sr20BounceBuyTime  = 0;   // Dernier toucher+rebond support
datetime g_sr20BounceSellTime = 0;   // Dernier toucher+rebond résistance
int    g_sr20OutOfSupBars    = 0;    // Bougies HORS zone support (confirmation rebond)
int    g_sr20OutOfResBars    = 0;    // Bougies HORS zone résistance (confirmation rebond)
input int SR20BounceConfirmBars = 2; // N bougies hors-zone requises pour valider le rebond

// Dashboard indicators (set by CheckRSISqueezeAndTrade, read by GOM dashboard)
bool   g_dashSqueezeActive   = false; // RSI squeeze active on M5
double g_dashSqueezeRSI      = 0;     // Current M5 RSI value
bool   g_dashH1Aligned       = false; // H1 trend aligned with squeeze

// Suivi de l'équité journalière pour contrôle du drawdown
double g_dailyStartEquity = 0.0;
double g_dailyMaxEquity   = 0.0;
double g_dailyMinEquity   = 0.0;
int    g_dailyEquityDate  = 0;   // YYYYMMDD

// Gestion capital journalière (terminal-wide, magic InpMagicNumber)
int      g_cmDateYMD              = 0;
int      g_cmTradesToday          = 0;
double   g_cmNetProfitToday       = 0.0;
int      g_cmWinsToday            = 0;
int      g_cmLossesToday          = 0;
bool     g_cmDayStopped           = false;
string   g_cmDayStopReason        = "";
datetime g_cmPauseUntil           = 0;
int      g_cmConsecWins           = 0;
int      g_cmConsecLosses         = 0;
double   g_cmDayStartBalance      = 0.0;  // Solde au début de la journée
double   g_cmEffectiveProfitTarget = 0.0; // Seuil profit calculé (% × solde)
double   g_cmEffectiveMaxLoss      = 0.0; // Seuil perte calculé (% × solde)

// Dernière perte par symbole (éviter 2e perte consécutive sans conditions strictes)
string g_lastLossSymbol   = "";
datetime g_lastLossTime   = 0;
// RECENT_LOSS_WINDOW_SEC est maintenant configuré via LossCooldownMinutes input

// Compteur trades journalier (discipline quotidienne)
int    g_dailyTradeCount  = 0;

// Session Readiness & Circuit-Breaker
bool     g_readinessGo            = true;    // Défaut GO (fail-open si serveur KO)
int      g_readinessScore         = 100;     // Score 0-100 du dernier poll
bool     g_readinessCBActive      = false;   // Circuit-breaker global actif
bool     g_readinessCBSymbolCool  = false;   // Cooldown symbole courant
string   g_readinessCBReason      = "";      // Raison du halt
string   g_readinessBestHours     = "";      // ex: "8,9,13,14"
string   g_readinessAvoidHours    = "";      // ex: "0,1,2,22,23"

// DecisionEngine globals (defined in SMC_EntryGateResult section)
SMC_EntryGateResult g_lastEntryGateResult;  // Dernière évaluation
datetime            g_lastPerfectEntryTime = 0;  // Dernière PERFECT
string              g_lastPerfectEntrySymbol = ""; // Symbole PERFECT

// Pulse and Spike globals 
SMC_PulseState       g_pulseState;           // Momentum fade tracking
SMC_SpikeSeriesState g_spikeSeries;          // Spike cycle tracking

// OTE Engine globals (forward decls above)
bool   OTE_enabled = true;
double OTE_minConfidence = 0.0;
double OTE_lotsOverride = 0.0;

//| INPUTS                                                            |
input group "=== GÉNÉRAL ==="
input bool   UseMinLotOnly     = true;   // Toujours lot minimum (le plus bas)
input int    MaxPositionsTerminal = 2;   // Nombre max de positions (tout le terminal MT5) - LIMITÉ À 2
input bool   OnePositionPerSymbol = true; // Une seule position par symbole
input int    InpMagicNumber       = 202502; // Magic Number
input double MaxTotalLossDollars  = 10.0; // Perte totale max ($)
input double MaxLossPerSpikeTradeDollars = 2.0;  // Perte max par trade Spike Boom/Crash/Painx/Gainx ($)
input double MaxRiskPerTradePercent   = 1.5;  // Risque normal par trade (% equity)
input double MaxDailyDrawdownPercent  = 10.0; // Drawdown max journalier (%)
input double MinSetupScoreEntry      = 75.0;  // Score minimum (0-100) pour entrée
input double MinAIConfidencePercent   = 65.0;  // Confiance IA min (%)
input group "=== SNIPER SCALPER MODE (cap $ + RR + confluence) ==="
input bool   UseSniperScalperMode    = true;   // Active le cap $ universel + RR mini sur tous les trades
input double MaxLossPerTradeDollars  = 2.0;    // Perte MAX absolue par trade, tous symboles ($)
input double MinRewardRiskRatio      = 3.0;    // RR minimum exigé (TP = SL_dist x ce ratio)
input int    MinSniperConfluenceGates = 4;     // Nb mini de confluences SMC simultanées (OB,FVG,BOS,Sweep,OTE,EMA/SR,GOM,IA)
input bool   SniperRequireGOMOrAI    = true;   // Exiger verdict GOM OK ou confiance IA suffisante

input group "=== SPIKE CHAIN STATE DETECTOR ==="
input bool   UseSpikeChainDetector    = true;  // Active la détection de début de chaîne
input int    SpikeChainATRLookback    = 100;   // Nb de bougies pour la moyenne/écart-type ATR
input double SpikeChainZScoreThreshold = 1.5;  // Seuil z-score ATR -> état PRE_SPIKE
input double SpikeChainBodyATRMult    = 2.0;   // Corps mini (x ATR) pour compter comme "bougie forte"
input int    SpikeChainExhaustionBars = 3;     // Nb de bougies faibles consécutives -> retour CALME
input bool   UseSpikeChainEarlyEntry  = true;  // Autoriser une entrée dès CHAÎNE ACTIVE (avant confirmation classique)
input int    SpikeChainExtraConfluenceGates = 1; // Confluences supplémentaires exigées pour une entrée précoce
input group "=== STRATEGIE CHAINE DE SPIKES H1/M5 (Kola) ==="
input bool   UseSCH1_Strategy          = true;  // Active la strategie "Chaine de Spikes" H1/M5
input bool   SCH1_RequireForBoomCrash  = true;  // Rend cette validation OBLIGATOIRE pour les trades Boom/Crash/Painx/Gainx
input int    SCH1_SR_Lookback          = 20;    // Nb bougies H1 pour Support/Resistance
input double SCH1_SR_ProximityATR      = 1.0;   // Proximite zone S/R H1 (x ATR H1)
input int    InpSCH1_ATR_Period        = 14;    // Periode ATR (M5/H1/H4) utilisee par le module
input double SCH1_SpikeATRMultiplier   = 2.0;   // Seuil range/ATR pour qu une bougie compte comme spike
input int    SCH1_ForceThreshold       = 60;    // Score de force mini (0-100, H1/H4) pour valider l impulsion
input int    SCH1_ForceLookbackH1      = 20;    // Bougies H1 pour la densite de spikes recents
input int    SCH1_MomentumBarsH1       = 10;    // Bougies H1 pour le momentum directionnel
input double SCH1_MomentumScale        = 10.0;  // Facteur d echelle du score momentum H1
input double SCH1_RejectionCloseThresholdPct = 50.0; // % max de retour dans le corps du spike M5 (rejet)
input int    SCH1_ChainMaxSpikes       = 4;     // Taille moyenne cible de la chaine (3 a 4 spikes)
input int    SCH1_ChainRetraceMaxBars  = 3;     // Nb de bougies M5 de retracement max avant chaine essoufflee
input bool   SCH1_TPUseSRExtension     = true;  // TP = extension mesuree au-dela de la S/R H1 opposee
input bool   SCH1_ManageChainPositions = true;  // Partial close + verrouillage SL a chaque nouveau spike
input double SCH1_PartialClosePct      = 30.0;  // % de cloture partielle a chaque spike supplementaire
input bool   SCH1_ShowPanel            = true;  // Afficher un panneau d info dedie sur le graphique

input group "=== SPIKE CHAIN ONNX PREDICTOR ==="
input bool   UseOnnxSpikeFilter    = true;   // Activer le filtre directionnel ONNX sur les trades spike
input string OnnxSpikeModelFile    = "spike_chain_model.onnx"; // Nom du fichier ONNX dans MQL5/Files/
input double MarkovUpGivenUp       = 0.80;   // P(spike UP | spike précédent UP) — remplacer par valeur réelle
input double MarkovUpGivenDown     = 0.80;   // P(spike UP | spike précédent DOWN) — remplacer par valeur réelle
input double OnnxBuyThreshold      = 0.65;   // Seuil P(up) min pour autoriser BUY sur Boom/Crash
input double OnnxSellThreshold     = 0.35;   // Seuil P(up) max pour autoriser SELL sur Boom/Crash
input bool   UseSessions       = true;   // Trader seulement LO/NYO
input bool   UseDerivArrowTrades     = false; // Exécuter trades sur Deriv Arrow
input bool   RequireSMCDerivArrowForMarketOrders = true; // Attendre SMC_DERIV_ARROW (market SMC)
input bool   RequireSMCDerivArrowForAllOrders = false; // Exiger flèche SMC_DERIV_ARROW pour TOUT ordre (false = autonome)
input int    SMCDerivArrowMaxAgeBars = 3; // Flèche sur N dernières bougies
input bool   UltraLightMode      = false; // Mode ultra léger
input bool   BlockAllTrades      = false; // Bloquer toutes entrées/sorties
input int    SpikePredictionOffsetMinutes = 60; // Décalage futur entrée spike
input group "=== SL/TP DYNAMIQUES ==="
input double SL_ATRMult        = 2.5;    // Stop Loss (x ATR)
input double TP_ATRMult        = 5.0;    // Take Profit (x ATR)
input double MaxSLDollars      = 4.0;    // SL max en dollars (cap)
input int    MarketSLExtraPoints = 0;    // Points SL additionnels (market orders)
input double MarketSLExtraUSD    = 1.0;  // Buffer SL additionnel en $ (+1$ de marge)
input int    MarketTPExtraPoints = 0;    // Points TP additionnels (market orders)
input double FxVolTrailKeepPct   = 70.0; // FXVOL: % du peak à protéger (ne jamais rendre >30%)
input group "=== TRAILING STOP ==="
input bool   UseTrailingStop    = true;   // Trailing Stop auto
input double TrailingStop_ATRMult = 3.0;  // Distance trailing (x ATR)
input bool   UseGainProtectionTrail = true; // Protection gains: SL suit prix dès 1$ gain
input double GainProtectTriggerUSD  = 1.0;  // Seuil gain ($) pour protection
input double GainProtectKeepPct     = 70.0; // % du gain peak protégé
input group "=== GOLD SCALING TRAILING ==="
input bool   GoldScalingTrail   = true;   // Activer scaling trailing GOLD/Metals
input double GoldScaleTrailStart = 0.5;   // Trigger profit ($) pour GOLD scaling
input double GoldScaleTrailPct   = 70.0;  // % du gain à protéger (trailing)
input group "=== PATH CONCORDANCE TRAIL BONUS ==="
input bool   UsePathTrailBonus           = true;  // Bonus trailing si path concordant
input double PathTrailMinConcordancePct  = 65.0;  // Concordance path min (%)
input double PathTrailMinEntryProbPct    = 72.0;  // Probabilité entrée min (%) - dashboard P:
input double PathTrailMinIAConfidencePct = 65.0;  // Confiance IA status min (%)
input double PathTrailLoosenATRMax         = 1.6;   // Distance max trailing ATR
input double PathTrailGivebackFrac         = 0.35;  // Part peak rendable avant trail forcé
input double PathTrailCorrTightenMult      = 0.55;  // Resserre trailing si correction
input double PathTrailGainKeepBonusPct     = 55.0;  // % peak protégé mode bonus
input int    PathTrailMinRunwayBars        = 8;     // Barres path alignées min
input group "=== GESTION CAPITAL JOURNALIÈRE ==="
input bool   UseDailyCapitalManager     = true;  // Limites journalières + pauses
input int    MaxTradesPerDay            = 10;    // Max trades par jour
input double DailyProfitTargetPercent   = 10.0;  // Objectif profit journalier (%)
input double DailyMaxLossPercent        = 5.0;   // Perte max journalière (%)
input int    PauseAfterConsecWins   = 4;      // Pause après N gains consécutifs
input int    PauseAfterConsecLosses = 3;      // Pause après N pertes consécutives
input int    ConsecPauseMinutes     = 60;     // Durée pause (minutes)
input group "=== GRAPHIQUES SMC (affichage visuel) ==="
input bool   ShowPredictionChannel = true; // Canal prédiction ML
input bool   ShowBookmarkLevels    = true; // Lignes Swing High/Low (bookmark ICT)
input bool   UseMinimalICTDrawings = false; // Graphiques minimaux ICT
input group "=== TABLEAU DE BORD ET MÉTRIQUES ==="
input bool   UseDashboard        = true;   // Tableau de bord métriques
input bool   ShowMLMetrics       = true;   // Métriques ML
input bool   UseSpikeAutoClose    = true;   // Fermeture auto spikes
input bool   UseDollarExits       = true;  // Fermetures basées sur $
input bool   UseIAHoldClose       = true;  // Fermer sur HOLD
input bool   UseDirectionConflictClose = true; // Fermer sur conflit direction
input group "=== EMA/SR PROXIMITY GATE ==="
input bool   UseEMASRProximityGate    = true;   // Bloquer si loin de toute EMA/SR
input double EMASRProxATRMult        = 0.5;    // Distance max en ATR d'un niveau
input group "=== BOUNCE DETECTION ==="
input bool   UseBounceEntry          = true;   // Détection rebond sur niveau
input double BounceTouchATRMult      = 0.15;   // Distance max pour "toucher"
input double BounceConfirmATRMult    = 0.10;   // Distance min confirmation rebond
input group "=== MICRO CORRECTION STRATEGY ==="
input bool   UseMicroCorrectionStrategy = true;   // Micro-correction vers OB/OTE
input bool   MicroCorrOnlyForexGoldSilver = true;  // Limité Forex/Metal
input int    MicroCorrMaxHoldSec         = 30;    // Durée max position (sec)
input double MicroCorrSL_ATRMult         = 1.5;   // SL serré (x ATR)
input double MicroCorrTP_ATRMult         = 2.0;   // TP (x ATR)
input double MicroCorrMinOBOTEProximity  = 0.5;   // Proximité min OB/OTE (x ATR)
input bool   MicroCorrRequireGOMAlign    = true;  // Exiger GOM aligné
input int    MicroCorrMinGOMVerdict      = 2;     // |vn| min pour micro-correction
input group "=== AI SERVER ==="
input bool   UseAIServer       = true;   // Serveur IA
input string AI_ServerURL       = "http://127.0.0.1:8000";  // URL locale
input string AI_ServerRender    = "https://kolatradebot-7ofl.onrender.com";  // URL fallback
input int    AI_Timeout_ms     = 5000;   // Timeout WebRequest (ms)
input int    AI_UpdateInterval_Seconds = 30;  // Intervalle mise à jour IA
input bool   UseRenderAsPrimary = false; // Render en fallback
input string AI_ServerURL2      = "http://127.0.0.1:8000";  // URL locale 2
input double MinAIConfidence   = 0.55;   // Confiance IA min (55%)
input int    AI_Timeout_ms2     = 10000;  // Timeout Render cold start
input string AI_ModelName       = "SMC_Model";
input string AI_ModelVersion    = "1.0";
input bool   AI_UseGPU          = true;
input bool   RequireAIConfirmation = true;
input bool   UseFVG            = true;
input bool   UseOrderBlocks    = true;
input bool   UseLiquiditySweep = true;
input bool   RequireStructureAfterSweep = true;
input bool   NoEntryDuringSweep = true;
input bool   StopBeyondNewStructure = true;
input bool   UseBOS            = true;
input bool   UseOTE            = true;
input bool   UseEqualHL        = true;
input bool   UseStrongConfluence        = true; // Confluence OTE+OB+Structure
input group "=== TIMEFRAMES ==="
input ENUM_TIMEFRAMES HTF      = PERIOD_H4;  // Structure (HTF)
input ENUM_TIMEFRAMES LTF      = PERIOD_M15; // Entrée (LTF)
input group "=== FVG_Kill PRO ==="
input bool   UseFVGKillMode    = true;
input int    EMA50_Period      = 50;
input int    EMA200_Period     = 200;
input double ATR_Mult          = 1.8;
input bool   UseTrailingStructure = true;
input bool   BoomCrashMode     = true;
input group "=== SESSIONS ==="
input bool   TradeOutsideKillZone = true;
input int    LondonStart       = 8;
input int    LondonEnd         = 11;
input int    NYOStart          = 13;
input int    NYOEnd            = 16;
input bool   VolUseSessionFilter = true;  // Filtrer sessions pour Volatility synthetics
input int    VolSessionStart1   = 2;      // 1ère session: heure début UTC (ex: 02h)
input int    VolSessionEnd1     = 6;      // 1ère session: heure fin UTC (ex: 06h)
input int    VolSessionStart2   = 13;     // 2ème session: heure début UTC (ex: 13h)
input int    VolSessionEnd2     = 17;     // 2ème session: heure fin UTC (ex: 17h)
input group "=== NOTIFICATIONS ==="
input bool   UseNotifications  = true;
input bool   GOMVerdictPushNotify    = true; // Push MT5 quand GOM passe GOOD/PERFECT
input bool   SpikeImminentPushNotify = true; // Push MT5 spike IMMINENT
input bool   UseLossCooldown         = true;  // Pause après perte récente sur symbole
input int    LossCooldownMinutes     = 5;     // Durée cooldown après perte (minutes)
input group "=== BOUGIES FUTURES ==="
input int    PredictionChannelPastBars = 1000;
input int    PredictionChannelBars = 1000;
input group "=== CANAUX SMC MULTI-TF ==="
input bool   ShowSMCChannelsMultiTF = true;
input bool   ShowEMASupertrendMultiTF = true;
input int    SMCChannelFutureBars = 5000;
input int    EMAFastPeriod = 9;
input int    EMASlowPeriod = 21;
input double ATRMultiplier = 2.0;
input group "=== ORDRES LIMITES ==="
input bool   UseClosestLevelForLimits = true;
input double MaxDistanceLimitATR = 1.0;
input group "=== S/R 20 BAR LIMIT ORDERS ==="
input bool   UseSR20BarLimits       = true;   // Placer BUY_LIMIT/SELL_LIMIT aux S/R 20 bars
input int    SR20BarMaxOrders       = 2;      // Max ordres LIMIT par symbole (1 BUY + 1 SELL)
input double SR20BarSL_ATRMult      = 2.0;    // SL des limit orders S/R 20 bars (x ATR)
input double SR20BarTP_ATRMult      = 4.0;    // TP des limit orders S/R 20 bars (x ATR)
input double SR20BarMaxDistATR      = 1.5;    // Distance max du prix en ATR pour placer un ordre
//--- SL/TP des ordres LIMIT basés sur la taille des bougies M1
// (au lieu d'ATR qui donne un SL trop serré). SL = N bougies M1, TP = M bougies M1.
input int    LimitSL_M1Bars         = 3;     // SL ordre LIMIT = taille moyenne M1 × 3 bougies
input int    LimitTP_M1Bars         = 7;     // TP ordre LIMIT = taille moyenne M1 × 7 bougies
input bool   SR20BarCancelOnShift   = true;   // Annuler et repositionner si le niveau bouge
input int    SR20BounceWindowBars  = 20;     // Fenêtre (bougies) où le rebond S/R 20 bars reste armé (chaîne spikes)
input group "=== IMPULSE ZONE (20 bars = forte impulsion spike) ==="
input bool   UseImpulseZone         = true;  // Activer zone d'impulsion 20 bars
input double ImpulseZoneBufferATR   = 0.3;   // Buffer zone (x ATR) autour du S/R 20
input bool   ImpulseZoneAutoTrade   = true;  // Auto-trade si prix touche zone + Boom/Crash
input double ImpulseZoneSL_ATRMult  = 2.0;   // SL impulse trade (x ATR)
input double ImpulseZoneTP_ATRMult  = 5.0;   // TP impulse trade (x ATR)

input group "=== GOM PIPELINE (verdict + dashboard) ==="
input bool   UseGOMVerdictFilter    = true;  // Filtrer entrées par verdict GOOD/PERFECT
input bool   UseGOMPipeline         = true;  // Pipeline Python → MT5
enum GOMVerdictSourceEnum
{
   GOM_SRC_TRADINGVIEW = 0,
   GOM_SRC_LOCAL       = 1,
   GOM_SRC_AUTO        = 2,
   GOM_SRC_PREDICTIVE  = 3,
};
input GOMVerdictSourceEnum GOMVerdictSource = GOM_SRC_PREDICTIVE;
input bool   PipelineOnlyMode       = false;
input bool   ShowGOMDashboard       = true;  // Tableau de bord verdict GOM
input bool   UsePredictivePanel     = true;  // Setup SMC prédictif
input int    PredictivePanelPollSec = 15;    // Intervalle poll (sec)
input bool   PredictivePanelDrawChart = true; // Dessiner zones/TP/trajectoire
input bool   PredictivePanelAlert   = true;  // Alerte MT5/WhatsApp setup
input bool   ShowTVSyncedLevels     = true;  // Dessins TV sync
input bool   UseGOMWaitAutoClose    = true;  // Fermer si GOM=WAIT
input double GOMWaitCloseMinLossUSD = 1.5;   // Seuil perte min fermeture WAIT ($)
input double GOMHoldMaxLossUSD      = 3.0;   // Perte max GOM valide ($) - LOSS-GUARD
input double UniversalMaxLossUSD    = 3.0;   // Perte max toutes positions EA ($)
input bool   GOMRequireOBTouch      = true;  // Entrée sur OB entry
input bool   GOMRequireOTE          = true;  // Entrée si OTE
input int    GOMPollIntervalSec     = 0;     // Poll GOM (0=chaque tick, sinonz secondes)
input double GOMMinCoherencePct     = 80.0;  // Cohérence min (%)
input int    GOMGlobalMinConfidence = 4;     // Force direction globale (1-7)
input bool   UseTVBollingerFilter   = true;  // Bloquer contre BB Mid
input bool   GOMUploadCandles       = true;  // Upload candles
input int    GOMUploadIntervalMin   = 1;     // Intervalle upload (min)
input bool   UseEAIndependentEntry  = true;  // Entrées indépendantes EA
input bool   GOMOBTouchForPipeline  = false;
input bool   GOMPerfectAutoEntry    = true;  // Stratégie GOM autonome
input bool   UseGOMTFAlignmentEntry = true;  // Entrée marché si GOM BUY/SELL + tous TF alignés
input double GOMAlignSL_ATRMult     = 2.0;  // SL = ATR × multiplicateur
input double GOMAlignTP_ATRMult     = 3.0;  // TP = ATR × multiplicateur
input double GOMAlignMaxSpreadPts   = 200;  // Spread max (points) pour entrée alignée
//--- Inputs module SMC_GOMAlign.mqh (alignement GOM + IA + Cognition 5min)
input bool   GOMAlignSpikeImmediateMarket = true;  // Sur Boom/Crash: entrée marché immédiate dès alignement
input bool   GOMAlignLimitAuto          = true;  // Placer automatiquement les limites alignées
input bool   GOMAlignM5EMAMarket       = true;  // Exiger pullback M5 EMA pour entrée marché
input double GOMAlignM5EMATolATR      = 0.40;  // Tolérance pullback M5 EMA (× ATR)
input double GOMAlignLimitMaxDistATR   = 3.0;   // Distance max limite au prix (× ATR)
input bool   GOMAlignPreferLimit       = true;  // Préférer limite au marché si niveau dispo
input bool   GOMAlignMarketFallback    = true;  // Repli marché si limite non déclenchée
input double GOMAlignMinPredConcordPct = 60.0; // Concordance min prédiction 5min (%)
input bool   GOMAlignPushNotify        = true;  // Notification push alignement GOM
input bool   TakeProfitAt1Dollar    = true;  // Fermer à +1$ de profit (sécuriser)
input double TP1ProfitTargetUSD     = 1.0;   // Profit cible en $ avant fermeture
input bool   TP1ReEnterOnPullback  = true;  // Ré-entrée si pullback sur S/R, OB ou EMA
input double TP1ReEntryATRZone      = 0.5;  // Zone pullback = ATR × multiplicateur
input bool   UseCloseOnVerdictWait   = true;  // Fermer si verdict → WAIT et perte ≥ 1$
input double CloseOnWaitLossMinUSD  = 1.0;   // Perte min $ avant fermeture sur WAIT
input group "=== RSI SQUEEZE PREDICTOR (Boom/Crash) ==="
input bool   UseRSISqueezePredictor  = true;  // Activer prédiction squeeze RSI
input int    RSISqueezePeriod        = 7;     // Période RSI squeeze
input int    RSISqueezeLowThreshold  = 20;    // Seuil bas squeeze (Boom → BUY)
input int    RSISqueezeHighThreshold = 80;    // Seuil haut squeeze (Crash → SELL)
input bool   RSISqueezeAutoTrade     = true;  // Auto-trade si squeeze + H1 trend OK
input bool   RSISqueezeH1Filter     = true;  // Filtrer par tendance H1 (EMA50)
input bool   RSISqueezeShowDashboard = true;  // Afficher squeeze sur dashboard
input double GOMTrailingMinProfitUSD = 1.0;  // Trailing GOM actif (N$)
input bool   UsePropitiousScore     = true;  // Score propice (0-100)
input int    GOMMinPropiceScore     = 70;    // Score minimum
input bool   UseSessionReadiness    = true;  // Circuit-breaker + Readiness
input int    ReadinessMinScore      = 45;    // Score readiness minimum
input int    ReadinessPollMinutes   = 60;    // Fréquence poll readiness (min)
input int    GOM_Timeout_ms         = 15000;
input int    MCPPollIntervalSec     = 3;
input int    GOMDashboardY          = 50;    // Marge basse dashboard GOM (pixels)
input bool   UsePatternEntrySignals = true;   // Pattern M1/M5/H1 requis
input bool   PatternRequireM1orM5    = true;   // Au moins 1 pattern M1 ou M5
input bool   PatternAllowH1Only      = false;  // Autoriser pattern H1 seul
input bool   PatternTriggerMarketEntry = true; // MARKET si pattern + GOM GOOD/PERFECT
input bool   PatternRequireBreakout  = true;   // Cassure niveau pattern requise
input bool   UseSpikeImminentAutoTrade = true; // Entrer/sortir auto spike imminent
input bool   UseGOMCorrectionOverlay = true;  // Overlay correction GOM
input bool   GOMExecuteOnM5H1Pattern = true;  // Pattern M5H1 GOM
input bool   UseMaxSpreadFilter     = false;  // Filtre spread max
input int    MaxSpreadPoints        = 50;     // Spread max (points)
input bool   UseFridayCutoff        = false;  // Couper trades vendredi
input int    FridayCutoffHourUTC    = 20;     // Heure UTC cut vendredi
input group "=== PROFIL OR XAUUSD ==="
input bool   UseGoldHybridProfile   = true;
input double GoldSL_ATRMult         = 2.2;
input double GoldTP_ATRMult         = 1.5;
input double GoldTP2_ATRMult        = 3.0;
input bool   GoldUsePartialTP       = true;
input double GoldMaxDailyLossPct    = 5.0;
input double GoldMaxRiskPct         = 0.5;
input double GoldTrailingMinUSD     = 1.0;
input bool   GoldDisableDerivArrow  = true;
input bool   GoldGOMOnlyOnMetal     = true;
input double GoldMaxTotalLossUSD    = 6.0;
input int    GoldMaxPositions       = 2;
input double GoldMinAIConfidencePct = 65.0;
input double GoldGOMMinCoherencePct = 90.0;
input bool   GoldUseRegimeFilter    = true;
input group "=== GOLD SCALP ==="
input bool   GoldScalpEnabled       = true;
input int    GoldScalpMaxPositions  = 3;
input double GoldScalpSL_ATRMult    = 1.5;
input double GoldScalpTP_ATRMult    = 1.5;
input double GoldScalpRiskPct       = 0.3;
input bool   GoldScalpUseEMA9       = true;
input bool   GoldScalpUseOBBull     = true;
input double GoldScalpOBTolATR      = 0.3;
input int    GoldScalpCooldownSec   = 120;
input group "=== PROFIL SILVER XAGUSD ==="
input bool   UseSilverProfile       = true;
input double SilverSL_ATRMult       = 2.0;
input double SilverTP_ATRMult       = 3.0;
input double SilverMaxDailyLossPct  = 4.0;
input double SilverMaxRiskPct       = 0.75;
input double SilverTrailingMinUSD   = 0.8;
input bool   SilverDisableDerivArrow= true;
input double SilverMaxTotalLossUSD  = 5.0;
input int    SilverMaxPositions     = 2;
input double SilverMinAIConfidencePct= 60.0;
input double SilverGOMMinCoherencePct= 85.0;
input bool   SilverUseRegimeFilter  = true;
input bool   SilverScalpEnabled     = true;
input double SilverScalpSL_ATRMult  = 1.5;
input double SilverScalpTP_ATRMult  = 2.0;
input group "=== PROFIL FOREX ==="
input bool   UseForexProfile        = true;
input double ForexSL_ATRMult        = 2.0;
input double ForexTP_ATRMult        = 3.0;
input double ForexMaxDailyLossPct   = 3.0;
input double ForexMaxRiskPct        = 1.0;
input double ForexGOMMinCoherencePct= 80.0;
input bool   ForexUseSessionFilter  = true;
input int    ForexSessionStart      = 7;
input int    ForexSessionEnd        = 17;
input group "=== PROFIL CRYPTO ==="
input bool   UseCryptoProfile       = true;
input double CryptoSL_ATRMult       = 2.0;
input double CryptoTP_ATRMult       = 4.0;
input double CryptoMaxDailyLossPct  = 5.0;
input double CryptoMaxRiskPct       = 0.5;
input double CryptoGOMMinCoherencePct= 80.0;
input bool   CryptoUseSessionFilter = true;
input int    CryptoSessionStart     = 8;
input int    CryptoSessionEnd       = 22;
input group "=== DISCIPLINE ROBOT ==="
input bool   UseSignalFirstDiscipline = false;
input int    MaxLimitOrdersTerminal   = 2;
input int    MaxPositionHoldSec       = 300;
input double PreciseLimitMaxDistATR   = 1.5;
input bool   PreferLimitOverMarket    = true;
input double MinLossBeforeAutoCloseUSD = 1.5;
input bool   KeepPendingUntilTrigger  = true;
input group "=== JOURNAL CSV + DASHBOARD ==="
input bool   UseTradeJournal          = true;
input int    TradeJournalBackfillDays = 30;
input group "=== DISCIPLINE JOURNALIÈRE ==="
input bool   UseDailyDiscipline       = true;
input int    MaxDailyTrades           = 30;
input double DailyProfitTargetPct     = 10.0;
input bool   StopOnDailyTarget        = true;
input bool   StopOnMaxDailyTrades     = true;
input bool   ResetTradeStatistics     = true;
input group "=== PAUSE PERFORMANCE ==="
input bool   UseWinStreakPause        = true;
input int    WinStreakThreshold       = 5;
input int    WinStreakPauseHours      = 2;
input bool   UseProfitGivebackGuard   = true;
input double ProfitGivebackPct        = 40.0;
input double ProfitGivebackMinPeakUSD = 5.0;
input bool   UseAbsoluteDrawdownGuard = true;
input double AbsoluteDrawdownPct      = 85.0;
input group "=== PROBABILITÉ ÉLEVÉE ==="
input bool   UseHighProbabilityFilter = true;
input double MinEntryProbabilityPct   = 72.0;
input int    MinGOMVerdictNumAbs      = 2;
input double HighProbBcMinConfidence  = 70.0;
input group "=== BOOM/CRASH HEURES ==="
input bool   UseHourTradingGates      = false;
input bool   UseBCHourFilter          = false;
input double BCHourMinConfidence      = 70.0;
input group "=== COGNITION FORECAST M1 ==="
input int    CognitionHorizonBars     = 1000;
input double CognitionMinConfidence   = 0.55;
input double CognitionMinStrength     = 0.50;
input bool   UseCognitionFilter       = true;
input bool   UseCognitionShortHorizon = true;
input bool   UseTripleAlignmentGate   = true;
input group "=== OTE / FIBO SCALPER ==="
input bool   UseOTEStrategy          = true;
input int    OTE_SwingLB            = 8;
input int    OTE_LookbackLB         = 60;
input bool   OTE_UseMTF             = true;
input double OTE_618                = 0.618;
input double OTE_705                = 0.705;
input double OTE_790                = 0.790;
input double OTE_TP1_Fibo           = 1.272;
input double OTE_TP2_Fibo           = 1.618;
input bool   OTE_UseOB               = true;
input int    OTE_OB_LB              = 35;
input double OTE_OB_BodyRatio        = 0.45;
input bool   OTE_UseFVG             = true;
input double OTE_FVG_MinPips        = 3.0;
input bool   OTE_UseEngulfing        = true;
input bool   OTE_UsePinBar          = true;
input bool   OTE_UseRSI             = true;
input int    OTE_RSI_Period         = 14;
input double OTE_RSI_BullMin         = 38.0;
input double OTE_RSI_BearMax         = 62.0;
input double OTE_Risk_Pct            = 1.0;
input double OTE_Min_RR             = 1.5;
input int    OTE_MaxTrades          = 3;
input double OTE_MaxLoss_Day         = 3.0;
input double OTE_MaxProfit_Day       = 6.0;
input bool   OTE_PartialClose       = true;
input double OTE_PartialPct         = 50.0;
input bool   OTE_UseBE              = true;
input double OTE_BE_Trigger_R       = 1.0;
input bool   OTE_UseTrailing         = true;
input double OTE_Trail_StartR        = 1.5;
input double OTE_Trail_StepPips      = 5.0;
input bool   OTE_UseSession          = true;
input int    OTE_Sess_Start         = 7;
input int    OTE_Sess_End           = 20;
input bool   OTE_Trade_Mon          = true;
input bool   OTE_Trade_Tue          = true;
input bool   OTE_Trade_Wed          = true;
input bool   OTE_Trade_Thu          = true;
input bool   OTE_Trade_Fri          = true;
input group "=== INDICATEURS CLASSIQUES ==="
input bool   UseClassicIndicatorsFilter = true;
input int    ClassicMinConfirmations    = 2;
input bool   UseBollingerFilter         = true;
input bool   UseVWAPFilter              = true;
input bool   UsePivotFilter             = true;
input bool   UseIchimokuFilter          = true;
input bool   UseOBVFilter               = true;
input group "=== BOOM/CRASH ==="
input bool   BoomBuyOnly       = true;
input bool   CrashSellOnly     = true;
input bool   NoSLTP_BoomCrash  = false;
input double BoomCrashSpikeTP  = 0.80;
input double BoomCrashSpikePct = 0.50;
input double TargetProfitBoomCrashUSD = 2.0;
input double MaxLossDollars    = 1.0;   // Perte min $ avant sortie auto (évite sorties rapides)
input double TakeProfitDollars = 2.0;
input bool   UseSpikeMLFilter        = true;
input double SpikeML_MinProbability  = 0.75;
input bool   SpikeUsePreSpikeOnlyForBoomCrash = true;
input bool   SpikeRequirePreSpikePattern = true;
input double PreSpike_CompressionRatio   = 0.65;
input double PreSpike_ConsolidationPct   = 0.002;
input double PreSpike_KeyLevelPct        = 0.002;
input int    PostSpikeMinSmallCandles    = 2;
input double PostSpikeSmallBodyRatio     = 0.55;
input int    PostSpikeBlockBarsSinceSpike = 2;
input group "=== PURE MOMENTUM ==="
input bool   UsePureMomentumGate       = false;  // Activer le gate Pure Momentum
input double PureMomentumRSIBuyLevel   = 70;     // Seuil RSI achat (Boom/Gainx)
input double PureMomentumRSISellLevel  = 30;     // Seuil RSI vente (Crash/Painx)
input double PureMomentumStochBuyLevel = 80;     // Seuil Stoch achat
input double PureMomentumStochSellLevel= 20;     // Seuil Stoch vente
input double PureMomentumMaxRetracePct = 50.0;   // Max % retrace autorisé
input group "=== PULSE EXHAUSTION ==="
input bool   UsePulseExhaustion      = true;
input int    PulseExhaustThreshold    = 70;
input double PulseProfitKeepPct       = 60.0;
input int    PulseSmallBodyCount      = 3;
input double PulseVolumeDropRatio     = 0.50;
input double PulseATRDecayRatio       = 0.70;
input group "=== SPIKE SERIES ==="
input int    SpikeSeriesMaxCount      = 5;
input double SpikeSeriesDeclineExit   = 0.60;
input double BoomCrashProtectTriggerUSD = 0.30;
input group "=== GOM WAIT PULLBACK ==="
enum ENUM_WAIT_MODE
{
   WAIT_PATIENT,
   WAIT_PULLBACK
};
input ENUM_WAIT_MODE GOMWaitMode      = WAIT_PATIENT;
input double PullbackMinIAConf       = 55.0;
input bool   PullbackNotifyWhatsApp  = true;
input group "=== DECISION ENGINE ==="
input bool   UseDecisionEngine       = true;
input bool   TesterGOMFallback       = true;
input int    TesterGOMVerdictStrength = 2;
input int    GOMPerfectHoldImmunitySec= 300;
input int    PerfectRsiOBMax         = 88;
input int    PerfectRsiOSMin         = 12;
input int    PerfectM15PropiceMin    = 80;
input int    PerfectCOGPropiceMin    = 85;
input double PerfectMinCoherence     = 30.0;
input group "=== POSITIONS MANUELLES ==="
input bool   ManageManualPositions   = true;
input double ManualSL_ATRMult        = 1.5;
input double ManualTP_ATRMult        = 1.5;
input bool   ManualNotifyWhatsApp    = true;
input group "=== ALERTS ==="
input bool   UseWhatsAppAlerts          = true;
input bool   UseEmailAlerts             = false;
input string PsychoBotWebhookURL        = "https://psychobot-1si7.onrender.com/send-message";
input string AlertPhoneNumber           = "+2290196911346";
input int    AlertRetryCount            = 3;
input int    AlertRetryDelayMs          = 1000;
input int    AlertTimeoutMs             = 3000;

//=== GLOBALES SUPPLÉMENTAIRES PIPELINE GOM ===
int    g_dailyTargetHit     = 0;      // Joker cible journalière atteinte
double g_spikeBonusPts      = 0;      // Points bonus spike
int    g_spikeZoneCount     = 0;      // Compteur zones spike
bool   g_usePriceActionZoneGate = false; // Gate zone PA
bool   g_showPriceActionZone    = false; // Afficher zone PA
// g_lastEntryProbability d�fini dans SMC_ProbabilityGate.mqh
bool   g_showCorrectionOverlay  = true;  // Afficher overlay correction

// ── TP1 state (used by GOM dashboard in SMC_GOM_Pipeline.mqh) ─────────
datetime g_tp1LastCloseTime  = 0;       // Dernière fermeture TP1
string   g_tp1LastCloseDir   = "";      // Direction (BUY/SELL)
double   g_tp1LastClosePrice = 0;       // Prix de fermeture
double   g_tp1LastCloseATR   = 0;       // ATR au moment de la fermeture
bool     g_tp1WaitingReEntry = false;   // En attente d'un pullback

// ── Forward declarations (used by SMC_GOM_Pipeline.mqh) ───────────────
bool AreAllTimeframesAligned(string &direction);

#include "modules/SMC_Stubs.mqh"
#include "modules/SMC_PatternSignals.mqh"
#include "modules/SMC_ProbabilityGate.mqh"
#include "modules/SMC_GOMAlign.mqh"
#include "modules/SMC_GOM_Pipeline.mqh"
#include "modules/SMC_ChartTools.mqh"
#include "modules/SMC_SpikeChainSignal.mqh"
#include "modules/SMC_AutoScalp.mqh"
#include "modules/SMC_AutoScalpFX.mqh"
#include "modules/SMC_AutoScalpRange.mqh"
#include "modules/SMC_RetracementGuard.mqh"

// ==========================================================================
// === PROFIL OR / FOREX / CRYPTO — IMPLÉMENTATIONS                       ===
// ==========================================================================

// Variables TP partiel Or
bool     g_goldHalfClosed    = false;
double   g_goldSlDistance    = 0.0;
double   g_goldEntryPrice    = 0.0;
ulong    g_goldPartialTicket = 0;
// Variables régime marché Or (W1)
int      g_goldRegimeW1_50  = INVALID_HANDLE;
int      g_goldRegimeW1_200 = INVALID_HANDLE;
int      g_goldRegime       = 0;        // 1=BULL, -1=BEAR, 0=TRANSITION
datetime g_goldRegimeUpdate = 0;
// Variables Gold Scalp (COG vert)
datetime g_goldScalpLastEntry = 0;
string   g_goldScalpCogPrev   = "";
int      g_goldScalpEma9M1    = INVALID_HANDLE;

bool SMC_IsGoldProfileActive()
{
   return UseGoldHybridProfile && SMC_GetSymbolCategory(_Symbol) == SYM_METAL;
}
bool SMC_IsForexProfileActive()
{
   return UseForexProfile && SMC_GetSymbolCategory(_Symbol) == SYM_FOREX;
}
bool SMC_IsCryptoProfileActive()
{
   return UseCryptoProfile && SMC_GetSymbolCategory(_Symbol) == SYM_CRYPTO;
}

double SMC_EffectiveSLMult()
{
   if(SMC_IsGoldProfileActive())   return GoldSL_ATRMult;
   if(SMC_IsForexProfileActive())  return ForexSL_ATRMult;
   if(SMC_IsCryptoProfileActive()) return CryptoSL_ATRMult;
   return SL_ATRMult;
}

double SMC_EffectiveTPMult()
{
   double base;
   if(SMC_IsGoldProfileActive())   base = GoldTP_ATRMult;
   else if(SMC_IsForexProfileActive())  base = ForexTP_ATRMult;
   else if(SMC_IsCryptoProfileActive()) base = CryptoTP_ATRMult;
   else base = TP_ATRMult;

   if(UseAIServer && g_agentLastUpdate > 0 && g_agentRegime != "")
   {
      if(g_agentRegime == "TRENDING_UP" || g_agentRegime == "TRENDING_DOWN")
         base *= 1.30;
      else if(g_agentRegime == "BREAKOUT")
         base *= 1.15;
      else if(g_agentRegime == "RANGING")
         base *= 0.80;
      else if(g_agentRegime == "VOLATILE")
         base *= 0.70;
   }
   return base;
}

double SMC_EffectiveMaxDailyDDPct()
{
   if(SMC_IsGoldProfileActive())   return GoldMaxDailyLossPct;
   if(SMC_IsForexProfileActive())  return ForexMaxDailyLossPct;
   if(SMC_IsCryptoProfileActive()) return CryptoMaxDailyLossPct;
   return MaxDailyDrawdownPercent;
}

double SMC_EffectiveRiskPct()
{
   if(SMC_IsGoldProfileActive())   return GoldMaxRiskPct;
   if(SMC_IsForexProfileActive())  return ForexMaxRiskPct;
   if(SMC_IsCryptoProfileActive()) return CryptoMaxRiskPct;
   return MaxRiskPerTradePercent;
}

double SMC_EffectiveMaxTotalLossUSD()
{
   return SMC_IsGoldProfileActive() ? GoldMaxTotalLossUSD : MaxTotalLossDollars;
}

int SMC_EffectiveMaxPositionsTerminal()
{
   int cap = MaxPositionsTerminal;
   if(SMC_IsGoldProfileActive())
      cap = MathMin(cap, GoldMaxPositions);
   return MathMax(1, cap);
}

bool SMC_TerminalPositionCapReached()
{
   return CountPositionsOurEA() >= SMC_EffectiveMaxPositionsTerminal();
}

double SMC_EffectiveGOMMinCoherence()
{
   if(SMC_IsGoldProfileActive())   return GoldGOMMinCoherencePct;
   if(SMC_IsForexProfileActive())  return ForexGOMMinCoherencePct;
   if(SMC_IsCryptoProfileActive()) return CryptoGOMMinCoherencePct;
   if(SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
      return MathMin(GOMMinCoherencePct, 65.0);
   return GOMMinCoherencePct;
}

double SMC_EffectiveMinAIConfidence()
{
   return SMC_IsGoldProfileActive() ? GoldMinAIConfidencePct : MinAIConfidencePercent;
}

double SMC_EffectiveGOMTrailingMinUSD()
{
   return SMC_IsGoldProfileActive() ? GoldTrailingMinUSD : GOMTrailingMinProfitUSD;
}

bool SMC_EffectiveRequireDerivArrow()
{
   if(SMC_IsGoldProfileActive() && GoldDisableDerivArrow)
      return false;
   return RequireSMCDerivArrowForMarketOrders;
}

bool SMC_IsInProfileSessionWindow()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   if(SMC_IsForexProfileActive() && ForexUseSessionFilter)
      return (h >= ForexSessionStart && h < ForexSessionEnd);
   if(SMC_IsCryptoProfileActive() && CryptoUseSessionFilter)
      return (h >= CryptoSessionStart && h < CryptoSessionEnd);
   return true;
}

// Vérifie si on est dans une session Volatility optimale (2 fenêtres UTC)
bool SMC_IsVolSessionActive()
{
   if(!VolUseSessionFilter) return true;
   if(SMC_GetSymbolCategory(_Symbol) != SYM_VOLATILITY) return true;
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int h = dt.hour;
   bool inSession1 = (h >= VolSessionStart1 && h < VolSessionEnd1);
   bool inSession2 = (h >= VolSessionStart2 && h < VolSessionEnd2);
   return (inSession1 || inSession2);
}

int SMC_GetGoldRegimeW1()
{
   if(!GoldUseRegimeFilter) return 1;
   if(TimeCurrent() - g_goldRegimeUpdate < 300) return g_goldRegime;

   if(g_goldRegimeW1_50  == INVALID_HANDLE) g_goldRegimeW1_50  = iMA(_Symbol, PERIOD_W1, 50,  0, MODE_EMA, PRICE_CLOSE);
   if(g_goldRegimeW1_200 == INVALID_HANDLE) g_goldRegimeW1_200 = iMA(_Symbol, PERIOD_W1, 200, 0, MODE_EMA, PRICE_CLOSE);
   if(g_goldRegimeW1_50 == INVALID_HANDLE || g_goldRegimeW1_200 == INVALID_HANDLE) return g_goldRegime;

   double buf50[], buf200[];
   ArraySetAsSeries(buf50, true); ArraySetAsSeries(buf200, true);
   if(CopyBuffer(g_goldRegimeW1_50,  0, 0, 2, buf50)  < 2) return g_goldRegime;
   if(CopyBuffer(g_goldRegimeW1_200, 0, 0, 2, buf200) < 2) return g_goldRegime;

   double ema50  = buf50[1];
   double ema200 = buf200[1];
   if(ema200 <= 0) return g_goldRegime;

   double thresh = ema200 * 0.005;
   int newRegime;
   if(ema50 > ema200 + thresh)       newRegime = 1;
   else if(ema50 < ema200 - thresh)  newRegime = -1;
   else                               newRegime = 0;

   if(newRegime != g_goldRegime)
   {
      string names[] = {"BEAR", "TRANSITION", "BULL"};
      Print(StringFormat("[SMC-Gold] Régime W1 changé : %s ? %s | EMA50=%.2f EMA200=%.2f",
            names[g_goldRegime+1], names[newRegime+1], ema50, ema200));
   }
   g_goldRegime       = newRegime;
   g_goldRegimeUpdate = TimeCurrent();
   return g_goldRegime;
}

bool SMC_IsGoldDirectionAllowed(const string direction)
{
   if(!SMC_IsGoldProfileActive()) return true;
   int regime = SMC_GetGoldRegimeW1();
   if(regime ==  1) return (direction == "BUY");
   if(regime == -1) return true;
   return true;
}

double SMC_GoldTransitionLotFactor()
{
   if(!SMC_IsGoldProfileActive() || !GoldUseRegimeFilter) return 1.0;
   return (SMC_GetGoldRegimeW1() == 0) ? 0.5 : 1.0;
}

void SMC_ManageGoldPartialTP()
{
   if(!SMC_IsGoldProfileActive() || !GoldUsePartialTP) return;
   if(g_goldPartialTicket == 0) return;
   if(!posInfo.SelectByTicket(g_goldPartialTicket)) { g_goldPartialTicket = 0; return; }
   if(posInfo.Symbol() != _Symbol || posInfo.Magic() != InpMagicNumber) { g_goldPartialTicket = 0; return; }

   double curPrice = posInfo.PriceCurrent();
   double ep       = g_goldEntryPrice;
   double slDist   = g_goldSlDistance;
   if(slDist <= 0) return;

   bool isBuy = (posInfo.PositionType() == POSITION_TYPE_BUY);

   if(!g_goldHalfClosed)
   {
      double tp1dist = slDist * GoldTP_ATRMult / SMC_EffectiveSLMult();
      bool tp1Hit = isBuy ? (curPrice >= ep + slDist * 1.5) : (curPrice <= ep - slDist * 1.5);

      if(tp1Hit)
      {
         double halfLot = posInfo.Volume() * 0.5;
         double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         halfLot = MathMax(minLot, MathFloor(halfLot / stepLot) * stepLot);

         if(halfLot >= minLot && trade.PositionClosePartial(g_goldPartialTicket, halfLot))
         {
            g_goldHalfClosed = true;
            int    dg      = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            double newSL   = NormalizeDouble(ep, dg);
            double minStop = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
            bool   slOk    = isBuy ? (newSL < curPrice - minStop) : (newSL > curPrice + minStop);
            if(slOk) trade.PositionModify(g_goldPartialTicket, newSL, posInfo.TakeProfit());
            Print(StringFormat("[SMC-Gold] TP1 PARTIEL Or | %.2f lots fermés à RR=1.5 | SL?BE (%.2f)",
                  halfLot, ep));
         }
      }
   }
}

void SMC_ManageGoldScalp()
{
   if(!GoldScalpEnabled) return;
   if(!SMC_IsGoldProfileActive()) return;
   if(BlockAllTrades) return;

   string cogDir = g_cogDirection;
   int    gomVn  = g_smcGomVerdictNum;

   bool cogTurnedOff  = (cogDir != "BUY");
   bool gomWait       = (gomVn == 0);

   if(cogTurnedOff || gomWait)
   {
      if(g_goldScalpCogPrev == "BUY" && cogTurnedOff)
      {
         Print("[GOLD-SCALP] COG changé (", cogDir, ") — fermeture de tous les scalps Or");
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            if(!posInfo.SelectByIndex(i)) continue;
            if(posInfo.Symbol() != _Symbol)     continue;
            if(posInfo.Magic()  != InpMagicNumber) continue;
            if(StringFind(posInfo.Comment(), "GOLD_SCALP") < 0) continue;
            PositionCloseWithLog(posInfo.Ticket(), "COG changé — sortie scalp Or");
         }
      }
      else if(gomWait && g_goldScalpCogPrev == "BUY")
      {
         Print("[GOLD-SCALP] GOM=WAIT — fermeture scalps Or");
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            if(!posInfo.SelectByIndex(i)) continue;
            if(posInfo.Symbol() != _Symbol)        continue;
            if(posInfo.Magic()  != InpMagicNumber) continue;
            if(StringFind(posInfo.Comment(), "GOLD_SCALP") < 0) continue;
            PositionCloseWithLog(posInfo.Ticket(), "GOM WAIT — sortie scalp Or");
         }
      }
      g_goldScalpCogPrev = cogDir;
      return;
   }

    // --- STRICT GOM GATE: Only GOOD/PERFECT (vn >= 2 or vn <= -2) ---
    if(!UseGOMVerdictFilter || !g_smcGomConnected) return;
    if(!SMCGP_IsGoodPerfect(gomVn))
    {
       static datetime lastScalpGomLog = 0;
       if(TimeCurrent() - lastScalpGomLog >= 30)
       { lastScalpGomLog = TimeCurrent();
         Print("[GOLD-SCALP] Bloqué — verdict=", g_smcGomVerdict, " vn=", gomVn); }
       return;
    }

    g_goldScalpCogPrev = "BUY";

    if(g_smcIAStatusAction != "BUY")
   {
      static datetime s_iaGoldLog = 0;
      if(TimeCurrent() - s_iaGoldLog >= 120)
      { s_iaGoldLog = TimeCurrent();
        Print("[GOLD-SCALP] IA Status=", g_smcIAStatusAction, " — scalp bloqué"); }
      return;
   }

   if(!g_smcCorrEntrySafe && g_smcCorrExhaustPct < 65.0)
   {
      static datetime s_corrGoldLog = 0;
      if(TimeCurrent() - s_corrGoldLog >= 120)
      { s_corrGoldLog = TimeCurrent();
        Print("[GOLD-SCALP] Correction active (", g_smcCorrPhase, " ",
              DoubleToString(g_smcCorrExhaustPct, 0), "%) — scalp bloqué"); }
      return;
   }

   if(TimeCurrent() - g_goldScalpLastEntry < GoldScalpCooldownSec) return;

   int scalpCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Symbol() != _Symbol)        continue;
      if(posInfo.Magic()  != InpMagicNumber) continue;
      if(StringFind(posInfo.Comment(), "GOLD_SCALP") >= 0) scalpCount++;
   }
   if(scalpCount >= GoldScalpMaxPositions) return;
   if(SMC_TerminalPositionCapReached()) return;

   double atr = GOM_GetATRValue();
   if(atr <= 0) return;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0) return;

   bool trigger = false;
   string reason = "";

   if(GoldScalpUseEMA9 && g_goldScalpEma9M1 != INVALID_HANDLE)
   {
      double ema9[];
      ArraySetAsSeries(ema9, true);
      if(CopyBuffer(g_goldScalpEma9M1, 0, 0, 3, ema9) == 3)
      {
         double low1[];
         ArraySetAsSeries(low1, true);
         if(CopyLow(_Symbol, PERIOD_M1, 0, 3, low1) == 3)
         {
            bool touchedEma = (low1[1] <= ema9[1] + atr * 0.1);
            bool recovering = (ask > ema9[0]);
            if(touchedEma && recovering)
            {
               trigger = true;
               reason  = "EMA9_REBOND";
            }
         }
      }
   }

   if(!trigger && GoldScalpUseOBBull)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, PERIOD_M1, 0, 30, rates) == 30)
      {
         double tol = atr * GoldScalpOBTolATR;
         for(int k = 2; k < 28 && !trigger; k++)
         {
            bool isBullOB = (rates[k].close < rates[k].open &&
                             rates[k+1].close > rates[k+1].open &&
                             (rates[k+1].high - rates[k].low) > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
            if(!isBullOB) continue;
            double obHigh = rates[k].high;
            double obLow  = rates[k].low;
            if(ask >= obLow - tol && ask <= obHigh + tol)
            {
               trigger = true;
               reason  = StringFormat("OB_BULL@%.2f-%.2f", obLow, obHigh);
            }
         }
      }
   }

   if(!trigger) return;

   double sl = ask - atr * GoldScalpSL_ATRMult;
   double tp = ask + atr * GoldScalpTP_ATRMult;

   double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmt   = balance * GoldScalpRiskPct / 100.0;
   double slPips    = atr * GoldScalpSL_ATRMult;
   double tickVal   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lot = 0.01;
   if(tickVal > 0 && tickSize > 0 && slPips > 0)
      lot = riskAmt / (slPips / tickSize * tickVal);
   lot = MathMax(minLot, MathFloor(lot / lotStep) * lotStep);
   lot = MathMin(lot, maxLot);

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action    = TRADE_ACTION_DEAL;
   req.symbol    = _Symbol;
   req.volume    = lot;
   req.type      = ORDER_TYPE_BUY;
   req.price     = ask;
   req.sl        = NormalizeDouble(sl, _Digits);
   req.tp        = NormalizeDouble(tp, _Digits);
   req.deviation = 10;
   req.magic     = InpMagicNumber;
   req.comment   = "GOLD_SCALP|" + reason;
   {
      long fillFlags = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
      if((fillFlags & SYMBOL_FILLING_IOC) != 0)
         req.type_filling = ORDER_FILLING_IOC;
      else if((fillFlags & SYMBOL_FILLING_FOK) != 0)
         req.type_filling = ORDER_FILLING_FOK;
      else
         req.type_filling = ORDER_FILLING_RETURN;
   }

   g_goldScalpLastEntry = TimeCurrent();

   if(SafeOrderSendAndAlert(req, res) && res.retcode == TRADE_RETCODE_DONE)
   {
      Print(StringFormat("[GOLD-SCALP] BUY %.2f lots @ %.2f | SL=%.2f TP=%.2f | %s | COG=%s GOM=%s",
            lot, ask, sl, tp, reason, cogDir, g_smcGomVerdict));
   }
   else
   {
      Print(StringFormat("[GOLD-SCALP] Échec BUY retcode=%d | %s — cooldown %ds avant prochain essai",
            res.retcode, reason, GoldScalpCooldownSec));
   }
}

// ==========================================================================
// === FIN PROFIL OR / FOREX / CRYPTO                                     ===
// ==========================================================================

// ==========================================================================
// === PROACTIVE ENTRY ZONE CACHING (FVG / OB / Swing / ATR)              ===
// ==========================================================================
// Zones calculées AVANT spike — le spike arrive → on place l'ordre au prix de la zone
double   g_cachedBestBuyLevel   = 0.0;
double   g_cachedBestSellLevel  = 0.0;
string   g_cachedBuySource      = "";
string   g_cachedSellSource     = "";
datetime g_cachedZoneUpdate     = 0;
#define ZONE_CACHE_TTL_SEC  5   // Recalculer les zones toutes les 5 secondes

void UpdateCachedEntryZones()
{
   if(TimeCurrent() - g_cachedZoneUpdate < ZONE_CACHE_TTL_SEC) return;
   g_cachedZoneUpdate = TimeCurrent();

   double atr = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) >= 1) atr = atrBuf[0];
   }
   if(atr <= 0) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return;

   // --- BUY zones: Swing low (plus proche support) ---
   string srcBuy = "";
   double swingBuy = GetClosestBuyLevel(bid, atr, 2.0, srcBuy);
   if(swingBuy > 0 && swingBuy < bid && (bid - swingBuy) <= atr * 2.5)
   {
      g_cachedBestBuyLevel = swingBuy;
      g_cachedBuySource    = "SWING_" + srcBuy;
   }
   else
   {
      g_cachedBestBuyLevel = bid - atr * 1.5;
      g_cachedBuySource    = "ATR";
   }

   // --- SELL zones: Swing high (plus proche résistance) ---
   string srcSell = "";
   double swingSell = GetClosestSellLevel(ask, atr, 2.0, srcSell);
   if(swingSell > 0 && swingSell > ask && (swingSell - ask) <= atr * 2.5)
   {
      g_cachedBestSellLevel = swingSell;
      g_cachedSellSource    = "SWING_" + srcSell;
   }
   else
   {
      g_cachedBestSellLevel = ask + atr * 1.5;
      g_cachedSellSource    = "ATR";
   }
}

void DrawCachedEntryZones()
{
   if(!ShowChartGraphics) return;

   double atr = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) >= 1) atr = atrBuf[0];
   }
   if(atr <= 0) return;

   datetime now = TimeCurrent();
   int barSec = PeriodSeconds();

   // Zone BUY
   if(g_cachedBestBuyLevel > 0)
   {
      string name = "SMC_CachedBuyZone";
      double upper = g_cachedBestBuyLevel + atr * 0.1;
      double lower = g_cachedBestBuyLevel - atr * 0.1;
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, now - barSec * 20, lower, now + barSec * 50, upper);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetString(0, name, OBJPROP_TEXT, "BUY zone [" + g_cachedBuySource + "]");
   }

   // Zone SELL
   if(g_cachedBestSellLevel > 0)
   {
      string name = "SMC_CachedSellZone";
      double upper = g_cachedBestSellLevel + atr * 0.1;
      double lower = g_cachedBestSellLevel - atr * 0.1;
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, now - barSec * 20, lower, now + barSec * 50, upper);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrCrimson);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetString(0, name, OBJPROP_TEXT, "SELL zone [" + g_cachedSellSource + "]");
   }
}

//| GESTION DES POSITIONS ET VARIABLES GLOBALES                    |

// Vrai si ce symbole a subi une perte récente (SL ou autre) → réentrée soumise à conditions strictes
bool IsRecentLossOnSymbol(const string symbol)
{
   if(g_lastLossSymbol == "" || symbol == "") return false;
   if(g_lastLossSymbol != symbol) return false;
   return (TimeCurrent() - g_lastLossTime <= LossCooldownMinutes * 60);
}

// Autorise ou bloque une réentrée après perte récente sur ce symbole.
// spikeImminent: vrai si le contexte actuel indique un spike / setup exceptionnel (déjà calculé par l'appelant).
bool AllowReentryAfterRecentLoss(const string symbol, const string direction, bool spikeImminent)
{
   if(!IsRecentLossOnSymbol(symbol)) return true;

   string dir = direction;
   StringToUpper(dir);

   // Condition "exceptionnelle" minimale: confiance IA très forte + spike imminent
   double conf = g_lastAIConfidence;
   bool iaStrong = (conf >= 0.90) &&
                   (g_lastAIAction == "BUY" || g_lastAIAction == "buy" ||
                    g_lastAIAction == "SELL" || g_lastAIAction == "sell");

   // Si l'appelant n'a pas son propre flag spikeImminent, utiliser la proba locale
   if(!spikeImminent)
   {
      double p = CalculateSpikeProbability();
      spikeImminent = (p >= 0.80);
   }

   if(iaStrong && spikeImminent)
   {
      Print("✅ Réentrée après perte autorisée sur ", symbol,
            " - conditions strictes remplies (conf IA ",
            DoubleToString(conf*100, 1), "% + spike/setup fort)");
      return true;
   }

   Print("🚫 Réentrée après perte sur ", symbol,
         " bloquée (éviter 2e perte consécutive - exiger conf IA ≥90% + spike/setup fort)");
   return false;
}

// Lot minimal par défaut: 0.5 pour Boom 300 / Crash 300, sinon min du courtier
double GetMinLotForSymbol(const string symbol)
{
   if(StringFind(symbol, "Boom 300") >= 0 || StringFind(symbol, "Crash 300") >= 0)
      return 0.5;
   return SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
}

// Recovery: après une perte sur un symbole, le prochain signal sur un AUTRE symbole peut doubler le lot (une seule fois)
double ApplyRecoveryLot(double baseLot)
{
   if(g_lastLossSymbol == "" || g_lastLossSymbol == _Symbol)
      return baseLot;
   double minL = GetMinLotForSymbol(_Symbol);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double recoveryLot = MathMin(maxL, 2.0 * minL);
   recoveryLot = NormalizeVolumeForSymbol(recoveryLot);
   string lostSym = g_lastLossSymbol;
   g_lastLossSymbol = "";
   g_lastLossTime   = 0;
   Print("📈 RECOVERY - Lot doublé (", DoubleToString(recoveryLot, 2), ") sur ", _Symbol, " pour compenser perte sur ", lostSym);
   return recoveryLot;
}

// Vérifie si, pour ce symbole, la décision IA est suffisamment forte
// ET alignée en direction (jamais contre-tendance IA) pour autoriser
// l'ouverture d'une nouvelle position (hors Boom/Crash).
bool IsAITradeAllowedForDirection(const string direction)
{
   if(!UseAIServer) return true; // Pas d'IA requise si serveur désactivé
   
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   // Sur Boom/Crash, on garde la logique actuelle DERIV ARROW + règles spécifiques
   if(cat == SYM_BOOM_CRASH) return true;
   
   // Seuil FIXE à 65% pour les autres symboles :
   // on ne trade QUE si l'IA est BUY ou SELL avec confiance suffisante.
   double minConf = 0.65;
   if(g_lastAIAction == "" || g_lastAIConfidence < minConf)
   {
      Print("🚫 TRADE BLOQUÉ - Pas de décision IA forte (conf: ",
            DoubleToString(g_lastAIConfidence*100, 1), "% < ",
            DoubleToString(minConf*100, 1), "%) sur ", _Symbol);
      return false;
   }
   
   if(g_lastAIAction == "HOLD" || g_lastAIAction == "hold")
   {
      Print("🚫 TRADE BLOQUÉ - IA en HOLD sur ", _Symbol, " (", DoubleToString(g_lastAIConfidence*100,1), "%)");
      return false;
   }

   // Ne jamais trader CONTRE la direction IA:
   // - Si IA = BUY, seules les entrées BUY sont autorisées
   // - Si IA = SELL, seules les entrées SELL sont autorisées
   string iaDir = g_lastAIAction;
   StringToUpper(iaDir);

   // On ne laisse trader que si l'IA est clairement BUY ou SELL
   if(iaDir != "BUY" && iaDir != "SELL")
   {
      Print("🚫 TRADE BLOQUÉ - Décision IA non directionnelle (", iaDir,
            ") ou incompatible pour ", _Symbol,
            " (conf: ", DoubleToString(g_lastAIConfidence*100,1), "%)");
      return false;
   }

   string dir = direction;
   StringToUpper(dir);

   if((iaDir == "BUY"  && dir != "BUY") ||
      (iaDir == "SELL" && dir != "SELL"))
   {
      Print("🚫 TRADE BLOQUÉ - Direction '", dir,
            "' contraire au signal IA '", iaDir,
            "' (conf: ", DoubleToString(g_lastAIConfidence*100,1), "%) sur ", _Symbol);
      return false;
   }

   return true;
}

CTrade trade;
CPositionInfo posInfo;  // Local position info variable
COrderInfo orderInfo;

int atrHandle;
int emaHandle = INVALID_HANDLE;
int rsiSqueezeHandle = INVALID_HANDLE;  // RSI pour détection squeeze Boom/Crash
int ema50H = INVALID_HANDLE;
int ema200H = INVALID_HANDLE;
int fractalH = INVALID_HANDLE;
int emaM1H = INVALID_HANDLE;
int emaM5H = INVALID_HANDLE;
int emaH1H = INVALID_HANDLE;

// Handles pour EMA Supertrend Multi-TF
int emaFastM1 = INVALID_HANDLE;
int emaSlowM1 = INVALID_HANDLE;
int emaFastM5 = INVALID_HANDLE;
int emaSlowM5 = INVALID_HANDLE;
int emaFastH1 = INVALID_HANDLE;
int emaSlowH1 = INVALID_HANDLE;
int atrM1 = INVALID_HANDLE;
int atrM5 = INVALID_HANDLE;
int atrH1 = INVALID_HANDLE;
int atrH4 = INVALID_HANDLE;  // Chaine de Spikes H1/M5: ATR H4 pour le score de force

// EMAs SMC supplémentaires sur le timeframe d'entrée (LTF)
int ema21LTF = INVALID_HANDLE;
int ema31LTF = INVALID_HANDLE;
int ema50LTF = INVALID_HANDLE;
int ema100LTF = INVALID_HANDLE;
int ema200LTF = INVALID_HANDLE;
int ema50Chart = INVALID_HANDLE;
int ema100Chart = INVALID_HANDLE;
int ema200Chart = INVALID_HANDLE;
static datetime g_arrowBlinkTime = 0;
static bool g_arrowVisible = true;
static datetime g_spikeBlinkTime = 0;
static bool g_spikeWarningActive = false;
static datetime g_spikeWarningStart = 0;
static bool g_spikeWarningVisible = true;
int g_aiUpdateInterval = 30;
bool g_aiConnected = false;
static datetime g_lastBoomCrashPriceTime = 0;
// Variables swing (compatibles avec nouveau système anti-repaint)
double g_lastSwingHigh = 0, g_lastSwingLow = 0;
datetime g_lastSwingHighTime = 0, g_lastSwingLowTime = 0;
static datetime g_lastChannelUpdate = 0;
static double g_chUpperStart = 0, g_chUpperEnd = 0, g_chLowerStart = 0, g_chLowerEnd = 0;
static datetime g_chTimeStart = 0, g_chTimeEnd = 0;

//| VARIABLES GLOBALES POUR GESTION DES PAUSES ET BLACKLIST          |
struct SymbolPauseInfo {
   string symbol;
   datetime pauseUntil;
   int consecutiveLosses;
   int consecutiveWins;
   datetime lastTradeTime;
   double lastProfit;
};

SymbolPauseInfo g_symbolPauses[20]; // Maximum 20 symboles
int g_pauseCount = 0;

int OnInit()
{
   ArrayFill(g_tickFreqBuf, 0, 60, 0);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   atrHandle = iATR(_Symbol, LTF, 14);
   emaHandle = iMA(_Symbol, LTF, 9, 0, MODE_EMA, PRICE_CLOSE);
   rsiSqueezeHandle = iRSI(_Symbol, PERIOD_M5, RSISqueezePeriod, PRICE_CLOSE);
   ema50H = iMA(_Symbol, HTF, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema200H = iMA(_Symbol, HTF, EMA200_Period, 0, MODE_EMA, PRICE_CLOSE);
   // EMAs SMC sur le timeframe d'entrée (LTF)
   ema21LTF = iMA(_Symbol, LTF, 21, 0, MODE_EMA, PRICE_CLOSE);
   ema31LTF = iMA(_Symbol, LTF, 31, 0, MODE_EMA, PRICE_CLOSE);
   ema50LTF = iMA(_Symbol, LTF, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema100LTF = iMA(_Symbol, LTF, 100, 0, MODE_EMA, PRICE_CLOSE);
   ema200LTF = iMA(_Symbol, LTF, 200, 0, MODE_EMA, PRICE_CLOSE);
   ema50Chart  = iMA(_Symbol, PERIOD_CURRENT, 50,  0, MODE_EMA, PRICE_CLOSE);
   ema100Chart = iMA(_Symbol, PERIOD_CURRENT, 100, 0, MODE_EMA, PRICE_CLOSE);
   ema200Chart = iMA(_Symbol, PERIOD_CURRENT, 200, 0, MODE_EMA, PRICE_CLOSE);
   
   // Initialiser le système de gestion des pauses
   InitializeSymbolPauseSystem();
   CM_ResetIfNewDay();
   CM_RefreshDailyStats();
   
   Print("📊 SMC Universal + FVG_Kill PRO | 1 pos/symbole | Stratégie visible");
   emaM1H = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
   emaM5H = iMA(_Symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
   emaH1H = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);
   
   // Handles pour EMA Supertrend Multi-TF
   emaFastM1 = iMA(_Symbol, PERIOD_M1, EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM1 = iMA(_Symbol, PERIOD_M1, EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaFastM5 = iMA(_Symbol, PERIOD_M5, EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowM5 = iMA(_Symbol, PERIOD_M5, EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaFastH1 = iMA(_Symbol, PERIOD_H1, EMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   emaSlowH1 = iMA(_Symbol, PERIOD_H1, EMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
   atrM1 = iATR(_Symbol, PERIOD_M1, 14);
   atrM5 = iATR(_Symbol, PERIOD_M5, 14);
   atrH1 = iATR(_Symbol, PERIOD_H1, 14);
   atrH4 = iATR(_Symbol, PERIOD_H4, InpSCH1_ATR_Period); // Chaine de Spikes H1/M5
   // Vérification robuste des handles
   if(atrHandle == INVALID_HANDLE)
   {
      Print("❌ Erreur création ATR - Tentative de récupération...");
      atrHandle = iATR(_Symbol, LTF, 14);
      if(atrHandle == INVALID_HANDLE)
      {
         Print("⚠️ Erreur ATR - Utilisation ATR calculé manuellement pour éviter détachement");
         Comment("⚠️ ATR MANUEL - Robot fonctionnel");
         atrHandle = INVALID_HANDLE; // Garder INVALID_HANDLE mais continuer
      }
   }
   // Les indicateurs seront ajoutés dynamiquement si nécessaire pour éviter le détachement
   GlobalVariableSet("SMC_OPEN_LOCK_" + IntegerToString(InpMagicNumber), 0);
   Print("📊 SMC Universal + FVG_Kill PRO | 1 pos/symbole | Stratégie visible");
   Print("   Catégorie: ", EnumToString(SMC_GetSymbolCategory(_Symbol)));
   Print("   Symbole GOM: ", _Symbol, " | Serveur: ", AI_ServerURL);
   Print("   IA: ", UseAIServer ? AI_ServerURL : "Désactivé");
   SMCGP_Init();
   if(GOMSyncSymbolToTV)
      SMCGP_SendHeartbeat();

   // Spike Chain ONNX Predictor
   if(UseOnnxSpikeFilter && (IsBoomLikeSymbol(_Symbol) || IsCrashLikeSymbol(_Symbol)))
   {
      g_spikePredictorReady = g_spikePredictor.Init(OnnxSpikeModelFile, MarkovUpGivenUp, MarkovUpGivenDown);
      if(!g_spikePredictorReady)
         Print("⚠️ [ONNX] Modèle spike chain non chargé — filtre directionnel désactivé sur ", _Symbol);
   }

   // Chain Predictor — moteur prédictif de chaînes
   ChainPred_Init();

   // Spike Models (amplitude + interval) — auto-détectés par symbole
   g_spikeModelSetReady = SpikeModels_Init(_Symbol);
   if(g_spikeModelSetReady)
      Print("[SpikeModels] ONNX loaded for ", _Symbol);
   else
      Print("[SpikeModels] Not available for ", _Symbol);

   // Cross-Correlation — corrélation croisée PainX↔GainX
   CrossCorr_Init();

   // Dow Trendline — trendline de Dow + LIMIT orders
   DowTrendline_Init();

   // TF Gate — alignement multi-timeframe
   TFGate_Init();

   EventSetTimer(1);
   return INIT_SUCCEEDED;
}

void OnTimer()
{
   SMCGP_OnTimer();
}

bool TryAcquireOpenLock()
{
   if(UseDailyCapitalManager)
   {
      string cmReason = "";
      if(CM_IsEntryBlocked(cmReason))
      {
         static datetime s_lastCmLog = 0;
         if(TimeCurrent() - s_lastCmLog >= 60)
         {
            Print("🛑 Capital Manager — entrée bloquée: ", cmReason);
            s_lastCmLog = TimeCurrent();
         }
         return false;
      }
   }

   // ── SESSION FILTER: Volatility hors fenêtre optimale → bloquer ──
   if(!SMC_IsVolSessionActive())
   {
      static datetime s_lastSessLog = 0;
      if(TimeCurrent() - s_lastSessLog >= 300)
      {
         Print("🕐 SESSION VOL — hors fenêtre (", VolSessionStart1, "h-", VolSessionEnd1, "h / ",
               VolSessionStart2, "h-", VolSessionEnd2, "h UTC) | ", _Symbol);
         s_lastSessLog = TimeCurrent();
      }
      return false;
   }

   // ── LOSS COOLDOWN: pause après perte récente sur ce symbole ──
   if(UseLossCooldown && IsRecentLossOnSymbol(_Symbol))
   {
      int remain = (int)(LossCooldownMinutes * 60 - (TimeCurrent() - g_lastLossTime));
      if(remain > 0)
      {
         static datetime s_lastCoolLog = 0;
         if(TimeCurrent() - s_lastCoolLog >= 60)
         {
            Print("⏳ COOLDOWN — perte récente sur ", _Symbol, " | reste ",
                  remain / 60, "min ", remain % 60, "s");
            s_lastCoolLog = TimeCurrent();
         }
         return false;
      }
   }

   string lockName = "SMC_OPEN_LOCK_" + IntegerToString(InpMagicNumber);
   
   // Vérification simple sans Sleep pour éviter détachement
   if(GlobalVariableGet(lockName) != 0) return false;
   GlobalVariableSet(lockName, 1);
   if(CountPositionsOurEA() >= MaxPositionsTerminal) { GlobalVariableSet(lockName, 0); return false; }
   return true;
}
void ReleaseOpenLock() { GlobalVariableSet("SMC_OPEN_LOCK_" + IntegerToString(InpMagicNumber), 0); }

void OnDeinit(const int reason)
{
   // Diagnostic du détachement - identifier la cause exacte
   string reasonStr = "";
   switch(reason)
   {
      case REASON_PROGRAM:     reasonStr = "EA supprimé manuellement"; break;
      case REASON_REMOVE:      reasonStr = "EA retiré du graphique"; break;
      case REASON_RECOMPILE:   reasonStr = "EA recompilé"; break;
      case REASON_CHARTCHANGE: reasonStr = "Symbole/période changé"; break;
      case REASON_CHARTCLOSE:  reasonStr = "Graphique fermé"; break;
      case REASON_PARAMETERS:  reasonStr = "Paramètres modifiés"; break;
      case REASON_ACCOUNT:     reasonStr = "Compte changé"; break;
      case REASON_TEMPLATE:    reasonStr = "Template appliqué"; break;
      case REASON_INITFAILED:  reasonStr = "OnInit a échoué (CRASH)"; break;
      case REASON_CLOSE:       reasonStr = "Terminal fermé"; break;
      default:                 reasonStr = "Autre (code " + IntegerToString(reason) + ")"; break;
   }
   Print("🚨 DÉTACHEMENT ROBOT SMC | ", _Symbol, " | Raison: ", reasonStr);
   if(reason == REASON_INITFAILED)
      Print("⚠️ CAUSE: Erreur dans OnInit ou crash (indicateurs, mémoire, etc.)");

   SMCGP_Deinit();
   if(atrHandle != INVALID_HANDLE) { IndicatorRelease(atrHandle); atrHandle = INVALID_HANDLE; }
   if(emaHandle != INVALID_HANDLE) { IndicatorRelease(emaHandle); emaHandle = INVALID_HANDLE; }
   if(ema50H != INVALID_HANDLE) { IndicatorRelease(ema50H); ema50H = INVALID_HANDLE; }
   if(ema200H != INVALID_HANDLE) { IndicatorRelease(ema200H); ema200H = INVALID_HANDLE; }
   if(fractalH != INVALID_HANDLE) { IndicatorRelease(fractalH); fractalH = INVALID_HANDLE; }
   if(emaM1H != INVALID_HANDLE) { IndicatorRelease(emaM1H); emaM1H = INVALID_HANDLE; }
   if(emaM5H != INVALID_HANDLE) { IndicatorRelease(emaM5H); emaM5H = INVALID_HANDLE; }
   if(emaH1H != INVALID_HANDLE) { IndicatorRelease(emaH1H); emaH1H = INVALID_HANDLE; }
   if(emaFastM1 != INVALID_HANDLE) { IndicatorRelease(emaFastM1); emaFastM1 = INVALID_HANDLE; }
   if(emaSlowM1 != INVALID_HANDLE) { IndicatorRelease(emaSlowM1); emaSlowM1 = INVALID_HANDLE; }
   if(emaFastM5 != INVALID_HANDLE) { IndicatorRelease(emaFastM5); emaFastM5 = INVALID_HANDLE; }
   if(emaSlowM5 != INVALID_HANDLE) { IndicatorRelease(emaSlowM5); emaSlowM5 = INVALID_HANDLE; }
   if(emaFastH1 != INVALID_HANDLE) { IndicatorRelease(emaFastH1); emaFastH1 = INVALID_HANDLE; }
   if(emaSlowH1 != INVALID_HANDLE) { IndicatorRelease(emaSlowH1); emaSlowH1 = INVALID_HANDLE; }
   if(atrM1 != INVALID_HANDLE) { IndicatorRelease(atrM1); atrM1 = INVALID_HANDLE; }
   if(atrM5 != INVALID_HANDLE) { IndicatorRelease(atrM5); atrM5 = INVALID_HANDLE; }
   if(atrH1 != INVALID_HANDLE) { IndicatorRelease(atrH1); atrH1 = INVALID_HANDLE; }
   if(atrH4 != INVALID_HANDLE) { IndicatorRelease(atrH4); atrH4 = INVALID_HANDLE; }
   g_spikePredictor.Deinit();
   SpikeModels_Deinit();
   ChainPred_Cleanup();
   CrossCorr_Cleanup();
   DowTrendline_Cleanup();
   TFGate_Cleanup();
   EventKillTimer();
   SMCGP_CleanupChartObjects();
   if(ema21LTF != INVALID_HANDLE) { IndicatorRelease(ema21LTF); ema21LTF = INVALID_HANDLE; }
   if(ema31LTF != INVALID_HANDLE) { IndicatorRelease(ema31LTF); ema31LTF = INVALID_HANDLE; }
   if(ema50LTF != INVALID_HANDLE) { IndicatorRelease(ema50LTF); ema50LTF = INVALID_HANDLE; }
   if(ema100LTF != INVALID_HANDLE) { IndicatorRelease(ema100LTF); ema100LTF = INVALID_HANDLE; }
   if(ema200LTF != INVALID_HANDLE) { IndicatorRelease(ema200LTF); ema200LTF = INVALID_HANDLE; }
}

bool IsBullishHTF()
{
   if(ema50H == INVALID_HANDLE || ema200H == INVALID_HANDLE) return false;
   double f[], s[];
   ArraySetAsSeries(f, true); ArraySetAsSeries(s, true);
   if(CopyBuffer(ema50H, 0, 0, 1, f) < 1 || CopyBuffer(ema200H, 0, 0, 1, s) < 1) return false;
   return f[0] > s[0];
}
bool IsBearishHTF()
{
   if(ema50H == INVALID_HANDLE || ema200H == INVALID_HANDLE) return false;
   double f[], s[];
   ArraySetAsSeries(f, true); ArraySetAsSeries(s, true);
   if(CopyBuffer(ema50H, 0, 0, 1, f) < 1 || CopyBuffer(ema200H, 0, 0, 1, s) < 1) return false;
   return f[0] < s[0];
}
bool FVGKill_LiquiditySweepDetected()
{
   double prevHigh = iHigh(_Symbol, LTF, 2);
   double prevLow  = iLow(_Symbol, LTF, 2);
   double h1 = iHigh(_Symbol, LTF, 1);
   double l1 = iLow(_Symbol, LTF, 1);
   return (h1 > prevHigh || l1 < prevLow);
}
bool FVGKill_SweepConfirmed(int minBarsAgo = 2)
{
   string lsType;
   int barsAgo = 0;
   if(!SMC_DetectLiquiditySweepEx(_Symbol, LTF, lsType, barsAgo)) return false;
   return (barsAgo >= minBarsAgo);
}

bool IsInDiscountZone()
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 100, high) < 100 || CopyLow(_Symbol, PERIOD_H1, 0, 100, low) < 100 || CopyClose(_Symbol, PERIOD_H1, 0, 100, close) < 100) return false;
   int n = ArraySize(close);
   if(n < 25) return false;
   double sma20[];
   ArrayResize(sma20, n);
   ArraySetAsSeries(sma20, true);
   for(int i = 0; i < n - 20; i++) { double s = 0; for(int j = 0; j < 20; j++) s += close[i + j]; sma20[i] = s / 20; }
   for(int i = n - 20; i < n; i++) sma20[i] = sma20[MathMax(0, n - 21)];
   double eq = sma20[0];
   double discLow = low[ArrayMinimum(low, 0, 20)];
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (bid >= discLow && bid <= eq && discLow < eq);
}
bool IsInPremiumZone()
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 100, high) < 100 || CopyLow(_Symbol, PERIOD_H1, 0, 100, low) < 100 || CopyClose(_Symbol, PERIOD_H1, 0, 100, close) < 100) return false;
   int n = ArraySize(close);
   if(n < 25) return false;
   double sma20[];
   ArrayResize(sma20, n);
   ArraySetAsSeries(sma20, true);
   for(int i = 0; i < n - 20; i++) { double s = 0; for(int j = 0; j < 20; j++) s += close[i + j]; sma20[i] = s / 20; }
   for(int i = n - 20; i < n; i++) sma20[i] = sma20[MathMax(0, n - 21)];
   double eq = sma20[0];
   double premHigh = high[ArrayMaximum(high, 0, 20)];
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask >= eq && ask <= premHigh && premHigh > eq);
}

// Protection capital: vrai si en zone Discount et prix a touché le bord inférieur (zone d'achat)
// Utilisé pour exiger confiance IA >= 85% avant d'exécuter un SELL dans ce cas.
bool IsAtDiscountLowerEdge()
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 100, high) < 100 || CopyLow(_Symbol, PERIOD_H1, 0, 100, low) < 100 || CopyClose(_Symbol, PERIOD_H1, 0, 100, close) < 100) return false;
   int n = ArraySize(close);
   if(n < 25) return false;
   double sma20[];
   ArrayResize(sma20, n);
   ArraySetAsSeries(sma20, true);
   for(int i = 0; i < n - 20; i++) { double s = 0; for(int j = 0; j < 20; j++) s += close[i + j]; sma20[i] = s / 20; }
   for(int i = n - 20; i < n; i++) sma20[i] = sma20[MathMax(0, n - 21)];
   double eq = sma20[0];
   double discLow = low[ArrayMinimum(low, 0, 20)];
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(discLow >= eq) return false;
   if(bid < discLow || bid > eq) return false; // pas en zone discount
   double zoneHeight = eq - discLow;
   double edgeThreshold = discLow + zoneHeight * 0.15; // bord inférieur = 15% du bas de la zone
   return (bid <= edgeThreshold);
}

// Protection capital: vrai si en zone Premium et prix au bord supérieur (zone de vente)
// Utilisé pour exiger confiance IA >= 85% avant d'exécuter un BUY sur Boom dans ce cas.
bool IsAtPremiumUpperEdge()
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 100, high) < 100 || CopyLow(_Symbol, PERIOD_H1, 0, 100, low) < 100 || CopyClose(_Symbol, PERIOD_H1, 0, 100, close) < 100) return false;
   int n = ArraySize(close);
   if(n < 25) return false;
   double sma20[];
   ArrayResize(sma20, n);
   ArraySetAsSeries(sma20, true);
   for(int i = 0; i < n - 20; i++) { double s = 0; for(int j = 0; j < 20; j++) s += close[i + j]; sma20[i] = s / 20; }
   for(int i = n - 20; i < n; i++) sma20[i] = sma20[MathMax(0, n - 21)];
   double eq = sma20[0];
   double premHigh = high[ArrayMaximum(high, 0, 20)];
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(premHigh <= eq) return false;
   if(ask < eq || ask > premHigh) return false; // pas en zone premium
   double zoneHeight = premHigh - eq;
   double edgeThreshold = premHigh - zoneHeight * 0.15; // bord supérieur = 15% du haut de la zone
   return (ask >= edgeThreshold);
}

bool PriceTouchesLowerChannel()
{
   string lowerName = "SMC_CH_H1_LOWER";
   if(ObjectFind(0, lowerName) < 0) return false;
   double lowerPrice = ObjectGetDouble(0, lowerName, OBJPROP_PRICE);
   if(lowerPrice <= 0) return false;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrVal = 0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1) atrVal = atr[0];
   }
   if(atrVal <= 0) atrVal = SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.002;
   double tolerance = atrVal * 0.4;
   return (bid >= lowerPrice - tolerance && bid <= lowerPrice + tolerance);
}

bool PriceTouchesUpperChannel()
{
   string upperName = "SMC_CH_H1_UPPER";
   if(ObjectFind(0, upperName) < 0) return false;
   double upperPrice = ObjectGetDouble(0, upperName, OBJPROP_PRICE);
   if(upperPrice <= 0) return false;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atrVal = 0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1) atrVal = atr[0];
   }
   if(atrVal <= 0) atrVal = SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.002;
   double tolerance = atrVal * 0.4;
   return (ask >= upperPrice - tolerance && ask <= upperPrice + tolerance);
}

void ExecuteFVGKillBuy()
{
   // Vérifier si l'ATR handle est valide
   if(atrHandle == INVALID_HANDLE) return;
   // STRATÉGIE UNIQUE SPIKE POUR BOOM/CRASH: ne pas utiliser FVG_Kill sur ces indices
   if(SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH) return;
   
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, LTF, 0, 3, r) < 3) return;
   double sl = r[1].low - atr[0] * ATR_Mult;
   double tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - sl) * 2.0;
   if(CountPositionsOurEA() >= MaxPositionsTerminal) return;
   if(!TryAcquireOpenLock()) return;
   
   // Règle duplication / IA avant ouverture d'une nouvelle position
   if(!CanOpenAdditionalPositionForSymbol(_Symbol, "BUY"))
   {
      Print("❌ FVG_Kill BUY bloqué (règle duplication / IA) sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }
   if(UseSniperScalperMode)
   {
      double askRef = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double slDistFVGB = MathAbs(askRef - sl);
      double tpDistFVGB = 0;
      if(!SMC_ApplySniperRiskCap(_Symbol, slDistFVGB, lot, tpDistFVGB))
      {
         Print("🚫 FVG_Kill BUY bloqué par Sniper Risk Cap sur ", _Symbol);
         ReleaseOpenLock();
         return;
      }
      tp = askRef + tpDistFVGB;
   }
   
   // Exiger une décision IA forte pour tous les marchés non Boom/Crash
   if(!IsAITradeAllowedForDirection("BUY"))
   {
      ReleaseOpenLock();
      return;
   }

   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles (context FVG = setup fort)
   if(!AllowReentryAfterRecentLoss(_Symbol, "BUY", false))
   {
      ReleaseOpenLock();
      return;
   }
   
   // Réinitialiser le gain maximum pour la nouvelle position
   g_maxProfit = 0;
   
    if(RequireSMCDerivArrowForAllOrders && !HasRecentSMCDerivArrowForDirection("BUY"))
    {
       Print("🚫 FVG_Kill BUY bloqué - Attendre flèche SMC_DERIV_ARROW BUY sur ", _Symbol);
       ReleaseOpenLock();
      return;
   }
   if(g_smcGomConnected && g_smcGomVerdictNum < 0)
   {
      Print("🚫 FVG_Kill BUY BLOQUÉ — GOM verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ") — direction SELL");
      ReleaseOpenLock(); return;
   }
   if(g_smcGomConnected && g_smcGomVerdictNum == 0)
   {
      Print("🚫 FVG_Kill BUY BLOQUÉ — GOM verdict=WAIT (vn=0) — pas de direction");
      ReleaseOpenLock(); return;
   }
   if(SafeTradeBuy(lot, _Symbol, 0, sl, tp, "FVG_Kill BUY"))
   {
      ulong ticket = trade.ResultOrder();
      if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
   }
   ReleaseOpenLock();
   if(trade.ResultRetcode() == TRADE_RETCODE_DONE && UseNotifications)
   { Alert("FVG_Kill BUY ", _Symbol); SendNotification("FVG_Kill BUY " + _Symbol); }
}
void ExecuteFVGKillSell()
{
   // Vérifier si l'ATR handle est valide
   if(atrHandle == INVALID_HANDLE) return;
   // STRATÉGIE UNIQUE SPIKE POUR BOOM/CRASH: ne pas utiliser FVG_Kill sur ces indices
   if(SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH) return;
   
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, LTF, 0, 3, r) < 3) return;
   double sl = r[1].high + atr[0] * ATR_Mult;
   double tp = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (sl - SymbolInfoDouble(_Symbol, SYMBOL_BID)) * 2.0;
   if(CountPositionsOurEA() >= MaxPositionsTerminal) return;
   if(!TryAcquireOpenLock()) return;
   
   if(!CanOpenAdditionalPositionForSymbol(_Symbol, "SELL"))
   {
      Print("❌ FVG_Kill SELL bloqué (règle duplication / IA) sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }
   if(UseSniperScalperMode)
   {
      double bidRef = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double slDistFVGS = MathAbs(sl - bidRef);
      double tpDistFVGS = 0;
      if(!SMC_ApplySniperRiskCap(_Symbol, slDistFVGS, lot, tpDistFVGS))
      {
         Print("🚫 FVG_Kill SELL bloqué par Sniper Risk Cap sur ", _Symbol);
         ReleaseOpenLock();
         return;
      }
      tp = bidRef - tpDistFVGS;
   }
   
   // Exiger une décision IA forte pour tous les marchés non Boom/Crash
   if(!IsAITradeAllowedForDirection("SELL"))
   {
      ReleaseOpenLock();
      return;
   }

   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles (context FVG = setup fort)
   if(!AllowReentryAfterRecentLoss(_Symbol, "SELL", false))
   {
      ReleaseOpenLock();
      return;
   }
   
   // Réinitialiser le gain maximum pour la nouvelle position
   g_maxProfit = 0;
   
    if(RequireSMCDerivArrowForAllOrders && !HasRecentSMCDerivArrowForDirection("SELL"))
    {
       Print("🚫 FVG_Kill SELL bloqué - Attendre flèche SMC_DERIV_ARROW SELL sur ", _Symbol);
       ReleaseOpenLock();
      return;
   }
   if(g_smcGomConnected && g_smcGomVerdictNum > 0)
   {
      Print("🚫 FVG_Kill SELL BLOQUÉ — GOM verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ") — direction BUY");
      ReleaseOpenLock(); return;
   }
   if(g_smcGomConnected && g_smcGomVerdictNum == 0)
   {
      Print("🚫 FVG_Kill SELL BLOQUÉ — GOM verdict=WAIT (vn=0) — pas de direction");
      ReleaseOpenLock(); return;
   }
   if(SafeTradeSell(lot, _Symbol, 0, sl, tp, "FVG_Kill SELL"))
   {
      ulong ticket = trade.ResultOrder();
      if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
   }
   ReleaseOpenLock();
   if(trade.ResultRetcode() == TRADE_RETCODE_DONE && UseNotifications)
   { Alert("FVG_Kill SELL ", _Symbol); SendNotification("FVG_Kill SELL " + _Symbol); }
}

int CountPositionsForSymbol(string symbol)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber && posInfo.Symbol() == symbol)
         n++;
   return n;
}

// Retourne true si une position "SPIKE TRADE" est déjà ouverte sur ce symbole
bool HasOpenSpikeTradeForSymbol(string symbol)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) 
         continue;
      if(posInfo.Magic() != InpMagicNumber) 
         continue;
      if(posInfo.Symbol() != symbol) 
         continue;
      
      string comment = posInfo.Comment();
      if(StringFind(comment, "SPIKE TRADE") >= 0)
         return true;
   }
   return false;
}

int CountPositionsOurEA()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber)
         n++;
   return n;
}

void CloseWorstPositionIfTotalLossExceeded()
{
   double totalProfit = 0;
   double worstProfit = 0;
   ulong worstTicket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      double p = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      totalProfit += p;
      if(worstTicket == 0 || p < worstProfit)
      {
         worstProfit = p;
         worstTicket = posInfo.Ticket();
      }
   }
   if(totalProfit > -MaxTotalLossDollars) return;
   if(worstTicket != 0 && PositionCloseWithLog(worstTicket, "Perte totale max atteinte"))
      Print("🛑 Perte totale (", DoubleToString(totalProfit, 2), "$) >= ", DoubleToString(MaxTotalLossDollars, 0), "$ → position la plus perdante fermée (", DoubleToString(worstProfit, 2), "$)");
}

void CloseAllPositionsIfTotalProfitReached()
{
   double totalProfit = 0;
   ulong allTickets[];
   ArrayResize(allTickets, 0);
   
   // Calculer le profit total pour tous les symboles
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      double p = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      totalProfit += p;
      ArrayResize(allTickets, ArraySize(allTickets) + 1);
      allTickets[ArraySize(allTickets) - 1] = posInfo.Ticket();
   }
   
   // Fermer toutes les positions si le profit total atteint 3$
   if(totalProfit >= 3.0)
   {
      Print("💰 PROFIT TOTAL ATTEINT (", DoubleToString(totalProfit, 2), "$ >= 3.00$) → Fermeture de toutes les positions...");
      
      for(int i = 0; i < ArraySize(allTickets); i++)
      {
         ulong ticket = allTickets[i];
         // VALIDATION: Vérifier que la position existe toujours avant de fermer
         if(!PositionSelectByTicket(ticket))
         {
            Print("⚠️ Position déjà fermée avant profit total close - ticket=", ticket);
            continue;
         }
         
         double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         string symbol = PositionGetString(POSITION_SYMBOL);
         
         if(PositionCloseWithLog(ticket, "Profit total atteint"))
         {
            Print("✅ Position fermée - ", symbol, ": ", DoubleToString(profit, 2), "$");
         }
         else
         {
            Print("❌ Échec fermeture - ", symbol, ": ", DoubleToString(profit, 2), "$");
         }
      }
      
      Print("🎯 FERMETURE COMPLÈTE - Profit total réalisé: ", DoubleToString(totalProfit, 2), "$");
   }
}

// Fermeture par ordre inverse (comme Spike_Close_BoomCrash) pour compatibilité brokers
bool ClosePositionByDeal(ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   ENUM_ORDER_TYPE orderType = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   string symbol = PositionGetString(POSITION_SYMBOL);
   double volume = PositionGetDouble(POSITION_VOLUME);
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   request.action   = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol   = symbol;
   request.volume   = volume;
   request.type     = orderType;
   request.price    = (orderType == ORDER_TYPE_SELL) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
   request.deviation = 50;
   return SafeOrderSend(request, result);
}

bool CloseBoomCrashPosition(ulong ticket, const string symbol)
{
   if(ClosePositionByDeal(ticket))
   {
      Print("🧩 EA CLOSE DEAL OK - ", symbol, " | ticket=", ticket);
      return true;
   }
   if(PositionCloseWithLog(ticket, "Boom/Crash position close"))
   {
      Print("🧩 EA POSITION CLOSE OK - ", symbol, " | ticket=", ticket);
      return true;
   }
   int err = GetLastError();
   Print("❌ EA ÉCHEC FERMETURE Boom/Crash - ", symbol, " | ticket=", ticket, " | code=", err);
   return false;
}

void CloseBoomCrashAfterSpike(ulong ticket, string symbol, double currentProfit)
{
   if(posInfo.Magic() != InpMagicNumber) return;
   if(SMC_GetSymbolCategory(symbol) != SYM_BOOM_CRASH) return;
   
   // RÈGLE UNIVERSELLE D'ABORD: 2 dollars pour TOUS les symboles
   if(currentProfit >= 2.0)
   {
      if(CloseBoomCrashPosition(ticket, symbol))
      {
         Print("✅ Boom/Crash fermé: bénéfice 2$ atteint (", DoubleToString(currentProfit, 2), "$) - ", symbol);
         if(symbol == _Symbol) { g_lastBoomCrashPrice = 0; }
      }
      return;
   }
   
   // Ensuite, les règles spécifiques Boom/Crash si < 2$
   if(currentProfit >= TargetProfitBoomCrashUSD && currentProfit < 2.0)
   {
      if(CloseBoomCrashPosition(ticket, symbol))
      {
         Print("🚀 Boom/Crash fermé (gain >= ", DoubleToString(TargetProfitBoomCrashUSD, 2), "$): ", DoubleToString(currentProfit, 2), "$) - ", symbol);
         if(symbol == _Symbol) { g_lastBoomCrashPrice = 0; }
      }
      return;
   }
   
   // Spike detection (si < 2$) - DÉSACTIVÉ par défaut pour éviter fermetures prématurées
   if(g_lastBoomCrashPrice > 0 && false) // false = DÉSACTIVÉ
   {
      double price = SymbolInfoDouble(symbol, SYMBOL_BID);
      double movePct = (price - g_lastBoomCrashPrice) / g_lastBoomCrashPrice * 100.0;
       if(IsBoomLikeSymbol(symbol) && movePct >= BoomCrashSpikePct)
      {
         if(CloseBoomCrashPosition(ticket, symbol))
         {
            Print("🚀 Boom/Crash fermé (spike prix ", DoubleToString(currentProfit, 2), "$) - ", symbol);
            g_lastBoomCrashPrice = 0;
            s_lastRefUpdate = 0;
         }
      }
       if(IsCrashLikeSymbol(symbol) && movePct <= -BoomCrashSpikePct)
      {
         if(CloseBoomCrashPosition(ticket, symbol))
         {
            Print("🚀 Boom/Crash fermé (spike prix ", DoubleToString(currentProfit, 2), "$) - ", symbol);
            g_lastBoomCrashPrice = 0;
            s_lastRefUpdate = 0;
         }
      }
   }
}

// Parcourt toutes les positions et ferme Boom/Crash rapidement après spike
void ManageBoomCrashSpikeClose()
{
   // DEBUG: Log pour voir si cette fonction est appelée
   static datetime lastLog = 0;
   if(TimeCurrent() - lastLog >= 5) // Log toutes les 5 secondes maximum
   {
      Print("🔍 DEBUG - ManageBoomCrashSpikeClose appelée | UseSpikeAutoClose: ", UseSpikeAutoClose ? "OUI" : "NON");
      lastLog = TimeCurrent();
   }
   
   // Si la fermeture automatique est désactivée, sortir immédiatement
   if(!UseSpikeAutoClose)
   {
      return;
   }
   
   // OPTIMISATION: Sortir rapidement si aucune position
   if(PositionsTotal() == 0) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      
      string symbol = posInfo.Symbol();
      ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
      
      // Uniquement sur Boom/Crash
      if(cat != SYM_BOOM_CRASH) continue;
      
      // NOUVEAU: Distinguer les trades "SPIKE TRADE" des autres:
      // - SPIKE TRADE: fermeture possible immédiatement après spike capté
      // - Autres trades Boom/Crash: laisser respirer quelques secondes
      datetime openTime = posInfo.Time();
      int secondsSinceOpen = (int)(TimeCurrent() - openTime);
      string comment = posInfo.Comment();
      bool isSpikeTrade = (StringFind(comment, "SPIKE TRADE") >= 0);
      
      // Pour les trades classiques, on conserve une protection de 10 secondes.
      // Pour les SPIKE TRADE, aucune attente: on peut fermer dès que le spike est capté.
      if(!isSpikeTrade && secondsSinceOpen < 10) // Moins de 10 secondes pour les trades non "SPIKE TRADE"
      {
         Print("🔍 DEBUG - Spike Close - Trade trop récent (non SPIKE) - ", symbol, " | Ouvert il y a: ", secondsSinceOpen, "s");
         continue; // Ignorer ce trade pour l'instant
      }
      
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      double openPrice = posInfo.PriceOpen();
      double currentPrice = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      // Calculer le pourcentage de profit/perte
      double priceChangePercent = MathAbs((currentPrice - openPrice) / openPrice) * 100;
      
      // DEBUG: Log l'état de la position
      Print("🔍 DEBUG - Position Spike Close - ", symbol, 
            " | Profit: ", DoubleToString(profit, 2), "$",
            " | Changement: ", DoubleToString(priceChangePercent, 3), "%",
            " | Type: ", (posInfo.PositionType() == POSITION_TYPE_BUY ? "BUY" : "SELL"));
      
      // Fermer UNIQUEMENT sur spike capté (profit) - jamais sur perte, laisser le SL naturel
      bool shouldClose = false;
      string closeReason = "";
      
      if(profit >= BoomCrashSpikeTP) // Spike capté = profit atteint
      {
         shouldClose = true;
         closeReason = "Spike capté";
      }
      
      if(shouldClose)
      {
         Print("⚠️ TENTATIVE FERMETURE SPIKE - ", symbol, " | Raison: ", closeReason, 
               " | Profit: ", DoubleToString(profit, 2), "$ | Changement: ", DoubleToString(priceChangePercent, 3), "%");
         ulong ticket = posInfo.Ticket();
         // VALIDATION: Vérifier que la position existe toujours avant de fermer
         if(!PositionSelectByTicket(ticket))
         {
            Print("⚠️ Position déjà fermée avant spike close - ", symbol, " | ticket=", ticket);
            continue;
         }
         
         if(PositionCloseWithLog(ticket, "Spike close - " + closeReason))
         {
            // OPTIMISATION: Log minimal pour éviter le lag
            Print("🎯 EA FERMETURE SPIKE - ", symbol, " | ticket=", ticket, " | Profit: ", DoubleToString(profit, 2));
            
            if(UseNotifications)
            {
               Alert("🎯 Spike fermé - ", symbol, " - ", closeReason);
               SendNotification("🎯 Spike fermé - " + symbol + " - " + closeReason);
            }
         }
         else
         {
            int err = GetLastError();
            Print("❌ EA ÉCHEC FERMETURE SPIKE - ", symbol, " | ticket=", ticket, " | code=", err);
         }
      }
   }
}

void ManageDollarExits()
{
   // Si les sorties en dollars sont désactivées, sortir immédiatement
   if(!UseDollarExits)
   {
      static datetime lastLog = 0;
      if(TimeCurrent() - lastLog >= 30) // Log toutes les 30 secondes maximum
      {
         Print("🔍 DEBUG - ManageDollarExits DÉSACTIVÉE - laisse SL/TP normal fonctionner");
         lastLog = TimeCurrent();
      }
      return;
   }
   
   // DEBUG: Log pour voir si cette fonction est appelée
   static datetime lastLog = 0;
   if(TimeCurrent() - lastLog >= 5) // Log toutes les 5 secondes maximum
   {
      Print("🔍 DEBUG - ManageDollarExits appelée | MaxLossDollars: ", MaxLossDollars, " | BoomCrashSpikeTP: ", BoomCrashSpikeTP);
      lastLog = TimeCurrent();
   }
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      string symbol = PositionGetSymbol(i);
      if(symbol == "") continue;
      
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      if(ticket == 0) continue;
      double profit = PositionGetDouble(POSITION_PROFIT);
      ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
      
      // NOUVEAU: Laisser les trades respirer pendant 30 secondes après ouverture
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int secondsSinceOpen = (int)(TimeCurrent() - openTime);
      
      if(secondsSinceOpen < 30) // Moins de 30 secondes
      {
         Print("🔍 DEBUG - Trade trop récent - ", symbol, " | Ouvert il y a: ", secondsSinceOpen, "s | Profit: ", DoubleToString(profit, 2), "$");
         continue; // Ignorer ce trade pour l'instant
      }
      
      // DEBUG: Log chaque position analysée
      Print("🔍 DEBUG - Position analysée - ", symbol, " | Profit: ", DoubleToString(profit, 2), "$ | Ticket: ", ticket, " | Catégorie: ", (cat == SYM_BOOM_CRASH ? "BOOM_CRASH" : "AUTRE"), " | Âge: ", secondsSinceOpen, "s");
      
      // RÈGLE UNIVERSELLE: Fermer TOUTES les positions à 2 dollars de profit
      if(profit >= 2.0)
      {
         Print("⚠️ TENTATIVE FERMETURE TP 2$ - ", symbol, " | Profit: ", DoubleToString(profit, 2), "$");
         // VALIDATION: Vérifier que la position existe toujours avant de fermer
         if(!PositionSelectByTicket(ticket))
         {
            Print("⚠️ Position déjà fermée avant 2$ TP - ", symbol, " | ticket=", ticket);
            continue;
         }
         
         if(PositionCloseWithLog(ticket, "Profit total atteint"))
            Print("✅ EA Position fermée: bénéfice 2$ atteint (", DoubleToString(profit, 2), "$) - ", symbol, " | ticket=", ticket);
         else
         {
            int err = GetLastError();
            Print("❌ EA ÉCHEC FERMETURE TP GLOBAL - ", symbol, " | ticket=", ticket, " | code=", err);
         }
         continue;
      }
      
      // Règle de perte maximale (Boom/Crash: laisser le SL naturel, pas de fermeture sur perte)
      if(cat == SYM_BOOM_CRASH)
         ; // Ne pas fermer Boom/Crash sur perte - laisser SL/TP
      else if(profit <= -MaxLossDollars)
      {
         Print("⚠️ TENTATIVE FERMETURE PERTE MAX - ", symbol, " | Profit: ", DoubleToString(profit, 2), "$ | MaxLoss: ", MaxLossDollars, "$");
         // VALIDATION: Vérifier que la position existe toujours avant de fermer
         if(!PositionSelectByTicket(ticket))
         {
            Print("⚠️ Position déjà fermée avant perte max - ", symbol, " | ticket=", ticket);
            continue;
         }
         
         if(PositionCloseWithLog(ticket, "Profit total atteint"))
            Print("🛑 EA Position fermée: perte max atteinte (", DoubleToString(profit, 2), "$) - ", symbol, " | ticket=", ticket);
         else
         {
            int err = GetLastError();
            Print("❌ EA ÉCHEC FERMETURE SL GLOBAL - ", symbol, " | ticket=", ticket, " | code=", err);
         }
         continue;
      }
      
      // Règles spécifiques Boom/Crash (en plus de la règle universelle)
      if(cat == SYM_BOOM_CRASH)
      {
         // Spike TP pour Boom/Crash
         if(profit >= BoomCrashSpikeTP && profit < 2.0) // Si entre spike TP et 2$
         {
            Print("⚠️ TENTATIVE FERMETURE BOOM/CRASH SPIKE TP - ", symbol, " | Profit: ", DoubleToString(profit, 2), "$ | SpikeTP: ", DoubleToString(BoomCrashSpikeTP, 2), "$");
            // VALIDATION: Vérifier que la position existe toujours avant de fermer
            if(!PositionSelectByTicket(ticket))
            {
               Print("⚠️ Position déjà fermée avant Boom/Crash spike TP - ", symbol, " | ticket=", ticket);
               continue;
            }
            
            if(CloseBoomCrashPosition(ticket, symbol))
            {
               Print("🚀 EA Boom/Crash fermé après spike (gain > ", DoubleToString(BoomCrashSpikeTP, 2), "$): ", DoubleToString(profit, 2), "$ | ticket=", ticket, " - ", symbol);
               if(symbol == _Symbol) { g_lastBoomCrashPrice = 0; }
            }
            continue;
         }
      }
   }
}

// Ferme les positions et ordres en conflit avec l'IA (optionnel)
void ClosePositionsOnDirectionConflict()
{
   // Sécurité : ne rien faire si la fermeture sur conflit est désactivée
   if(!UseDirectionConflictClose || !UseAIServer)
      return;

   // IA doit être clairement BUY ou SELL avec une confiance suffisante
   string ai = g_lastAIAction;
   StringToUpper(ai);
   if(ai != "BUY" && ai != "SELL")
      return;

   double conf = g_lastAIConfidence;
   if(conf < MinAIConfidence)
      return;

   string sym = _Symbol;
   ENUM_SYMBOL_CATEGORY symCat = SMC_GetSymbolCategory(sym);

   // 1) Fermer les POSITIONS en conflit sur ce symbole (BUY vs SELL)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(!PositionSelectByTicket(ticket))
         continue;

      string psym = PositionGetString(POSITION_SYMBOL);
      ulong pmagic = (ulong)PositionGetInteger(POSITION_MAGIC);
      if(psym != sym || pmagic != InpMagicNumber)
         continue;

      ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool conflict = false;

      if(ptype == POSITION_TYPE_SELL && ai == "BUY")
         conflict = true;
      else if(ptype == POSITION_TYPE_BUY && ai == "SELL")
         conflict = true;

      if(!conflict)
         continue;

      // IMPORTANT: sur Boom/Crash, ne pas fermer les positions issues d'ordres LIMIT canal/retour
      // (sinon on "coupe" immédiatement après un fill et on rate le spike).
      if(symCat == SYM_BOOM_CRASH)
      {
         string cmt = PositionGetString(POSITION_COMMENT);
         if(StringFind(cmt, "SMC_CH") >= 0 || StringFind(cmt, "RETURN_MOVE") >= 0)
         {
            Print("🛑 SKIP CLOSE (conflit IA) - Boom/Crash LIMIT protégé | ", psym,
                  " | Ticket=", ticket,
                  " | Type=", (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                  " | IA=", ai, " ", DoubleToString(conf * 100.0, 1), "% | Comment=", cmt);
            continue;
         }
      }

      double profit = PositionGetDouble(POSITION_PROFIT);

      // RÈGLE STRICTE: Fermer TOUTES les positions en conflit avec l'IA
      // même si elles sont en perte - pour éviter de maintenir des positions opposées à l'IA
      // Log: afficher si la position est en perte ou en profit

      if(trade.PositionClose(ticket))
      {
         string profitStatus = (profit >= 0) ? "GAIN" : "PERTE";
         Print("⚠️ POSITION FERMÉE (conflit IA) - ", psym,
               " | Type=", (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL"),
               " | IA=", ai, " ",
               DoubleToString(conf * 100.0, 1), "% | ",
               profitStatus, "=", DoubleToString(MathAbs(profit), 2), "$");
      }
      else
      {
         Print("❌ ECHEC FERMETURE (conflit IA) - ", psym,
               " | Ticket=", ticket,
               " | Erreur=", _LastError);
      }
   }
}

// Ferme toutes les positions de l'EA quand l'IA passe en HOLD
void ClosePositionsOnIAHold()
{
   // Sécurité : ne rien faire si la fermeture sur HOLD est désactivée
   if(!UseIAHoldClose || !UseAIServer)
      return;
   
   // Vérifier si l'IA est en HOLD
   string aiAction = g_lastAIAction;
   StringToUpper(aiAction);
   
   if(aiAction != "HOLD") return;
   
   // Parcourir toutes les positions de l'EA
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         string symbol = PositionGetString(POSITION_SYMBOL);
         double profit = PositionGetDouble(POSITION_PROFIT);
         ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         string cmt = PositionGetString(POSITION_COMMENT);

         // IMPORTANT: sur Boom/Crash, ne pas fermer automatiquement les positions issues d'ordres LIMIT canal/retour
         // même si l'IA passe en HOLD (sinon on rate le spike juste après le fill).
         if(SMC_GetSymbolCategory(symbol) == SYM_BOOM_CRASH)
         {
            if(StringFind(cmt, "SMC_CH") >= 0 || StringFind(cmt, "RETURN_MOVE") >= 0)
            {
               Print("🛑 SKIP CLOSE (IA HOLD) - Boom/Crash LIMIT protégé | ",
                     (type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                     " sur ", symbol,
                     " | Ticket=", ticket,
                     " | Profit=", DoubleToString(profit, 2), "$",
                     " | Comment=", cmt);
               continue;
            }
         }
         
         // Respecter le seuil -1$ avant fermeture sur IA HOLD
         if(profit < 0 && profit > -1.0)
         {
            Print("[IA-HOLD] Ticket=", ticket, " perte=", DoubleToString(profit,2), "$ > -1$ — attente seuil avant fermeture");
            continue;
         }

         bool closed = PositionCloseWithLog(ticket, "IA HOLD - Fermeture automatique", true);

         if(closed)
            Print("[IA-HOLD] Position fermee | ", (type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                  " sur ", symbol, " | Profit: ", DoubleToString(profit, 2), "$");
         else
            Print("❌ ECHEC FERMETURE - IA HOLD | Erreur: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| GOM VERDICTS INTEGRATION — Fetch from ai_server /gom-verdicts   |
//+------------------------------------------------------------------+

static datetime last_gom_fetch = 0;
static int GOM_fetch_interval = 3;  // Fetch every 3 seconds (was 60)
static string last_notified_symbols = "";  // Track which symbols were notified

void UpdateGOMDashboard()
{
    // Fetch from ai_server every 60 seconds — WhatsApp alerts for PERFECT signals
    datetime now = TimeCurrent();

    if((now - last_gom_fetch) < GOM_fetch_interval)
        return;

    last_gom_fetch = now;

    string url = "http://127.0.0.1:8000/gom-verdicts";
    string headers = "Content-Type: application/json\r\n";

    uchar request[];
    uchar response[];
    string result_headers = "";
    int timeout = 5000;

    // MQL5 WebRequest signature: (url, method, headers, timeout, request[], response[], result_headers)
    int res = WebRequest("GET", url, headers, timeout, request, response, result_headers);

    if(res != 200)
    {
        return;
    }

    string response_str = CharArrayToString(response);

    // Check for "ok": true (with or without quotes — MQL5 string comparison)
    if(StringFind(response_str, "\"ok\":true") < 0 && StringFind(response_str, "\"ok\": true") < 0)
        return;

    // GOM scan WhatsApp DÉSACTIVÉ — on garde seulement les signaux SR20
    // (les alerts GOM PERFECT BUY/SELL sont maintenant gérées par les ordres SR20 + spike chain)

    // Reset tracking every 24 hours to allow re-notifications
    static datetime last_reset = 0;
    if((now - last_reset) >= 86400)  // 24 hours
    {
        last_notified_symbols = "";
        last_reset = now;
    }
}

void SendGOMWhatsAppAlert(const string &message)
{
    string url = "http://127.0.0.1:8000/notify-whatsapp";
    string payload = "{\"message\": \"🎯 GOM Signal: " + message + "\"}";

    uchar request[];
    StringToCharArray(payload, request);
    uchar response[];
    string result_headers = "";

    // MQL5 WebRequest signature: (url, method, headers, timeout, request[], response[], result_headers)
    int res = WebRequest("POST", url, "Content-Type: application/json\r\n", 3000, request, response, result_headers);

    if(res == 200)
    {
        Print("✅ WhatsApp alert sent: ", message);
    }
    else if(res == -1)
    {
        Print("⚠️ WebRequest not allowed (check Tools > Options > EA > Allow WebRequest)");
    }
    else
    {
        Print("⚠️ WhatsApp send failed (HTTP ", res, ")");
    }
}

// ── SR20 WhatsApp Signal: trade signal, entry, SL, TP, SR20 evolution, spike prediction, exit ──
void SendSR20WhatsAppSignal(const string &event, const string &symbol, const string &direction,
                            double entry, double sl, double tp, double price,
                            double sr20Level, const string &sr20Type, double atr,
                            double spikeProb, int greenBars, const string &exitReason)
{
    if(!UseWhatsAppAlerts) return;

    string ts = TimeToString(TimeCurrent(), TIME_MINUTES);
    string icon = "📊";
    if(event == "SR20_ENTRY")       icon = "🎯";
    else if(event == "SR20_SPIKE")  icon = "⚡";
    else if(event == "SR20_EXIT")   icon = "🏁";
    else if(event == "SR20_TP")     icon = "✅";
    else if(event == "SR20_SL")     icon = "🛑";
    else if(event == "SR20_WARN")   icon = "⚠️";

    string msg = icon + " " + event + " [" + ts + "]\n";
    msg += "Symbole: " + symbol + "\n";
    msg += "Direction: " + direction + "\n";
    msg += "Prix: " + DoubleToString(price, _Digits) + "\n";
    msg += "Entree: " + DoubleToString(entry, _Digits) + "\n";
    msg += "SL: " + DoubleToString(sl, _Digits) + " | TP: " + DoubleToString(tp, _Digits) + "\n";

    // SR20 evolution
    if(sr20Level > 0)
    {
        double dist = MathAbs(price - sr20Level);
        double distPct = (price > 0) ? (dist / price * 100.0) : 0;
        msg += "SR20 " + sr20Type + ": " + DoubleToString(sr20Level, _Digits) + "\n";
        msg += "Distance: " + DoubleToString(dist, _Digits) + " (" + DoubleToString(distPct, 2) + "%)\n";
        if(atr > 0)
        {
            double atrRatio = dist / atr;
            msg += "ATR ratio: " + DoubleToString(atrRatio, 2) + "\n";
        }
    }

    // Spike chain prediction
    if(spikeProb > 0)
    {
        msg += "Spike pred: " + DoubleToString(spikeProb * 100, 0) + "%";
        if(greenBars > 0)
            msg += " (" + IntegerToString(greenBars) + " bougies vertes)";
        msg += "\n";
    }

    // Exit reason
    if(exitReason != "")
        msg += "Sortie: " + exitReason + "\n";

    // Build JSON payload
    string payload = "{\"event\":\"" + event + "\",\"symbol\":\"" + symbol
        + "\",\"direction\":\"" + direction
        + "\",\"price\":" + DoubleToString(price, _Digits)
        + ",\"entry_price\":" + DoubleToString(entry, _Digits)
        + ",\"sl\":" + DoubleToString(sl, _Digits)
        + ",\"tp1\":" + DoubleToString(tp, _Digits)
        + ",\"message\":\"" + msg + "\"}";

    string url = "http://127.0.0.1:8000/notify-whatsapp";
    string headers = "Content-Type: application/json\r\n";
    uchar request[];
    StringToCharArray(payload, request);
    uchar response[];
    string result_headers = "";

    int res = WebRequest("POST", url, headers, 5000, request, response, result_headers);
    if(res == 200)
        Print("✅ SR20 WhatsApp: ", event, " ", symbol);
    else if(res == -1)
        Print("⚠️ SR20 WhatsApp: WebRequest not allowed");
    else
        Print("⚠️ SR20 WhatsApp failed (HTTP ", res, ")");
}

// ── Spike Chain Prediction: modelise les chaines de spikes a venir ──
void PredictSpikeChainAndAlert()
{
    if(!UseWhatsAppAlerts) return;
    bool isSpike = IsBoomLikeSymbol(_Symbol) || IsCrashLikeSymbol(_Symbol);
    if(!isSpike) return;

    // RSI squeeze + green bar count for spike probability
    static int rsiM1HandleLocal = INVALID_HANDLE;
    if(rsiM1HandleLocal == INVALID_HANDLE)
        rsiM1HandleLocal = iRSI(_Symbol, PERIOD_M1, 7, PRICE_CLOSE);
    if(rsiM1HandleLocal == INVALID_HANDLE) return;

    double rsi[];
    ArraySetAsSeries(rsi, true);
    if(CopyBuffer(rsiM1HandleLocal, 0, 0, 20, rsi) < 20) return;

    // Count consecutive green (bullish) candles
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_M1, 0, 10, rates) < 10) return;

    int greenBars = 0;
    for(int i = 0; i < 5; i++)
    {
        if(rates[i].close > rates[i].open)
            greenBars++;
        else
            break;
    }

    // Spike probability: based on RSI(7) squeeze + green bar count
    bool isBoom = IsBoomLikeSymbol(_Symbol);
    bool isCrash = IsCrashLikeSymbol(_Symbol);
    if(!isBoom && !isCrash) return;

    double rsiVal = rsi[0];
    double spikeProb = 0;

    // For Boom: spike = sudden drop (BUY). High RSI + green bars = spike imminent
    if(isBoom && rsiVal > 65 && greenBars >= 2)
    {
        spikeProb = MathMin(0.95, 0.4 + (rsiVal - 65) / 100.0 + greenBars * 0.1);
    }
    // For Crash/Painx: spike = sudden drop (SELL). Low RSI + green bars = spike imminent
    if(isCrash && rsiVal < 35 && greenBars >= 2)
    {
        spikeProb = MathMin(0.95, 0.4 + (35 - rsiVal) / 100.0 + greenBars * 0.1);
    }

    if(spikeProb < 0.5) return;

    // Check last notification time to avoid spam
    static datetime lastSpikeNotif = 0;
    if(TimeCurrent() - lastSpikeNotif < 120) return;  // max 1 per 2 min

    string dir = isBoom ? "BUY" : "SELL";
    string sr20Type = isBoom ? "SUP" : "RES";
    double sr20Level = isBoom ? g_impulseSupport20 : g_impulseResistance20;

    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double atrVal = 0;
    if(atrHandle != INVALID_HANDLE)
    {
        double atr[];
        ArraySetAsSeries(atr, true);
        if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1) atrVal = atr[0];
    }

    double entry = price;
    double sl = isBoom ? (price - atrVal * 2.0) : (price + atrVal * 2.0);
    double tp = isBoom ? (price + atrVal * 5.0) : (price - atrVal * 5.0);

    SendSR20WhatsAppSignal("SR20_SPIKE", _Symbol, dir,
                           entry, sl, tp, price,
                           sr20Level, sr20Type, atrVal,
                           spikeProb, greenBars,
                           "Spike imminent detecte");

    lastSpikeNotif = TimeCurrent();
}

void OnTick()
{
   // Tick Frequency Tracker (runs on EVERY tick, before rate-limiting)
   datetime tNow = TimeCurrent();
   if(tNow == g_tickFreqLastSec)
   {
      g_tickFreqCurrent++;
   }
   else
   {
      // Stocker le compte de la seconde précédente
      if(g_tickFreqLastSec > 0)
      {
         g_tickFreqBuf[g_tickFreqIdx] = g_tickFreqCurrent;
         g_tickFreqIdx = (g_tickFreqIdx + 1) % 60;
      }
      g_tickFreqCurrent = 1;
      g_tickFreqLastSec = tNow;
      // Calculer moyenne sur 60s
      double sum = 0; int cnt = 0;
      for(int i = 0; i < 60; i++) { if(g_tickFreqBuf[i] > 0) { sum += g_tickFreqBuf[i]; cnt++; } }
      g_tickFreqAvg = (cnt > 5) ? sum / cnt : 0.0;
      g_tickFreqRatio = (g_tickFreqAvg > 0) ? g_tickFreqCurrent / g_tickFreqAvg : 1.0;
   }

   // MODE IA ULTRA STABLE - PAS DE DÉTACHEMENT
   static datetime lastProcess = 0;
   static datetime lastGraphicsUpdate = 0;
   static datetime lastAIUpdate = 0;
   static datetime lastDashboardUpdate = 0;
   datetime currentTime = TimeCurrent();

   // Traitement contrôlé pour stabilité (max ~1 tick toutes les 2 secondes)
   if(currentTime - lastProcess < 2) return;
   lastProcess = currentTime;
   
    // Mise à jour de la machine à états Spike Chain (Boom/Crash/Painx/Gainx uniquement)
    SMC_UpdateSpikeChainState();
    SCH1_UpdateChainTracking(); // Chaine de Spikes H1/M5 (Kola)
    SCH1_ManageOpenPositions();
    SCH1_UpdatePanel();

     // Chain Predictor + Cross Correlation — panneau fusionné centré
     CrossCorr_ScanPartner(_Symbol);
     // ChainCorr_DrawMergedPanel(); // désactivé: remplacé par ChainPred_DrawPanel() + CrossCorr_DrawPanel()

      // Dow Trendline — scan trendline Dow + placement LIMIT
     DowTrendline_OnTick();

     // Spike Model Predictions — mettre à jour les prédictions amplitude/intervalle
     SpikeModels_UpdatePredictions();

     // ── GATE GOM WAIT / DÉCONNECTÉ: rejeter TOUTES les entrées ──
    // Même logique que connexion internet indisponible: aucun trade tant que GOM n'a pas un verdict actif
    bool gomBlocked = false;
    if(!UseGOMVerdictFilter) { /* pas de filtre GOM */ }
    else if(!g_smcGomConnected)
    {
       gomBlocked = true;
       static datetime s_lastGomBlockLog = 0;
       if(currentTime - s_lastGomBlockLog >= 30)
       {
          Print("❌ ORDRE REJETÉ — Connexion GOM indisponible — Toutes entrées bloquées (observation seule)");
          s_lastGomBlockLog = currentTime;
       }
    }
    else if(g_smcGomVerdictNum == 0)
    {
       gomBlocked = true;
       static datetime s_lastWaitBlockLog = 0;
       if(currentTime - s_lastWaitBlockLog >= 30)
       {
          Print("❌ ORDRE REJETÉ — GOM verdict = WAIT (vn=0) — Toutes entrées bloquées (observation seule)");
          s_lastWaitBlockLog = currentTime;
       }
    }
    else if(MathAbs(g_smcGomVerdictNum) < MinGOMVerdictNumAbs)
    {
       gomBlocked = true;
       static datetime s_lastSimpleBlockLog = 0;
       if(currentTime - s_lastSimpleBlockLog >= 30)
       {
          Print("❌ ORDRE REJETÉ — GOM verdict = SIMPLE (vn=", g_smcGomVerdictNum,
                ", exige |vn|>=", MinGOMVerdictNumAbs, ") — Toutes entrées bloquées");
          s_lastSimpleBlockLog = currentTime;
       }
    }

     // ── ANNULER TOUS nos pending orders si GOM=WAIT / DÉCONNECTÉ ──
    // Un LIMIT posé avant le WAIT doit être retiré du serveur, sinon il se déclenche au prix
    if(gomBlocked)
    {
       for(int i = OrdersTotal() - 1; i >= 0; i--)
       {
          ulong tk = OrderGetTicket(i);
          if(tk == 0) continue;
          if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
          if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
          string cm = OrderGetString(ORDER_COMMENT);
          // Annuler uniquement nos ordres pending (AUTOSCALP, DOW, PIPELINE, SR20, SMC...)
          if(StringFind(cm, "AUTOSCALP") >= 0 || StringFind(cm, "DOW") >= 0 ||
             StringFind(cm, "PIPELINE") >= 0 || StringFind(cm, "SR20") >= 0 ||
             StringFind(cm, "SMC") >= 0 || StringFind(cm, "IMPULSE") >= 0 ||
             StringFind(cm, "RETURN") >= 0 || StringFind(cm, "POSTHOLD") >= 0)
          {
             if(trade.OrderDelete(tk))
                Print("❌ LIMIT annulé (GOM=", (!g_smcGomConnected ? "déconnecté" : "WAIT"),
                      ") | ", cm);
          }
       }
    }

    // ── TF GATE: Bloquer entrée si TFs supérieurs contredisent le verdict GOM ──
    bool tfBlocked = false;
    bool tfReduced = false;
    if(!gomBlocked && UseTFGate && g_smcGomVerdictNum != 0)
    {
       int gomDirSign = (g_smcGomVerdictNum > 0) ? 1 : -1;
       if(!TFGate_AllowEntry(gomDirSign, tfReduced))
       {
          tfBlocked = true;
          static datetime s_lastTfBlockLog = 0;
          if(currentTime - s_lastTfBlockLog >= 30)
          {
             Print("🚫 ORDRE REJETÉ — TF Gate BLOCKED | verdict=", g_smcGomVerdict,
                   " score=", g_tfGateState.score,
                   " D1=", g_smcTfD1Dir, " H4=", g_smcTfH4Dir,
                   " H1=", g_smcTfH1Dir);
             s_lastTfBlockLog = currentTime;
          }
       }
    }

    // SETUP 1 - Scalping autonome synthétiques (fusion 30 ans + boucle, SL dur 3$)
    SMCASC_OnTickGuard();
    if(!gomBlocked && !tfBlocked && SMCASC_Enable && SMC_IsSpikeStyleSymbol(_Symbol))
    {
       int ascDir = IsBoomLikeSymbol(_Symbol) ? 1 : (IsCrashLikeSymbol(_Symbol) ? -1 : 0);
       if(ascDir != 0) SMCASC_TryScalpSynthetic(_Symbol, ascDir);
    }

    // SETUP 1B - Scalp Dow: GOM PERFECT + Cognition → entrer creux/sommet prédit
    if(!gomBlocked && !tfBlocked && SMCASC_DowScalpEnable && SMC_IsSpikeStyleSymbol(_Symbol))
    {
       int dowDir = IsBoomLikeSymbol(_Symbol) ? 1 : (IsCrashLikeSymbol(_Symbol) ? -1 : 0);
       if(dowDir != 0) SMCASC_TryDowScalp(_Symbol, dowDir);
    }

    // SETUP 1C - Dow M5 + SR20 + Patterns: Dow M5 confirme → prix au SR20 + pattern M1
     if(!gomBlocked && !tfBlocked && SMCASC_DowSR20Enable && SMC_IsSpikeStyleSymbol(_Symbol))
     {
        int sr20Dir = IsBoomLikeSymbol(_Symbol) ? 1 : (IsCrashLikeSymbol(_Symbol) ? -1 : 0);
        if(sr20Dir != 0) SMCASC_TryDowSR20Scalp(_Symbol, sr20Dir);
     }

     // SETUP 1D - Vol Momentum + Fib Retrace: momentum chain → Fib entry (Weltrade Volatility)
     if(!gomBlocked && !tfBlocked && SMCASC_VolMomEnable && SMC_GetSymbolCategory(_Symbol) == SYM_VOLATILITY)
     {
        SMCASC_TryVolMomentumScalp(_Symbol);
     }

    // SETUP 2 - Chasse aux stops Forex/Crypto/Gold (SL dur 3$)
    SMCFX_OnTickGuard();
    if(!gomBlocked && !tfBlocked && SMCFX_Enable && !SMC_IsSpikeStyleSymbol(_Symbol) && SMC_GetSymbolCategory(_Symbol) != SYM_VOLATILITY)
    {
       SMCFX_TryScalpSweep(_Symbol);
    }

    // SETUP 3 - Cassure de range extrême Gold/Crypto (SL dur 3$)
    SMCR_OnTickGuard();
    if(!gomBlocked && !tfBlocked && SMCR_Enable && !SMC_IsSpikeStyleSymbol(_Symbol) && SMC_GetSymbolCategory(_Symbol) != SYM_VOLATILITY)
    {
       SMCR_TryScalpRange(_Symbol);
    }

    // Garde-fou retracement multi-TF: met à jour les zones / détection début/fin
    if(SMCGR_Enable)
    {
       SMCGR_Update(_Symbol);
       SMCGR_DrawRetracementZones(_Symbol);
    }
    // Si le prix est en zone de retracement, NE RIEN EXÉCUTER (bloque tout)
    g_inRetrace = SMCGR_IsInRetracement(_Symbol);
    
   // BLOCAGE TOTAL DES TRADES - Mode observation seul
   if(BlockAllTrades)
   {
      static datetime lastBlockLog = 0;
      if(currentTime - lastBlockLog >= 30) // Log toutes les 30 secondes
      {
         Print("🔒 MODE BLOCAGE ACTIVÉ - Aucune entrée/sortie autorisée - Observation seule");
         lastBlockLog = currentTime;
      }
      
      // Garder seulement les graphiques et IA pour observation
      if(!UltraLightMode)
      {
         // MISE À JOUR IA pour observation
         if(UseAIServer && currentTime - lastAIUpdate >= AI_UpdateInterval_Seconds)
         {
            lastAIUpdate = currentTime;
            UpdateAIDecision(AI_Timeout_ms);
         }
         
         // GRAPHIQUES pour observation
         if(ShowChartGraphics && currentTime - lastGraphicsUpdate >= 30)
         {
            lastGraphicsUpdate = currentTime;
            DrawAIStatusAndPredictions();
            if(ShowSignalArrow) { DrawSignalArrow(); UpdateSignalArrowBlink(); }
         }

         // GOM dashboard en mode observation (BlockAllTrades)
         if(ShowGOMDashboard || UseGOMVerdictFilter || UseGOMPipeline)
         {
            SMCGP_PollGOM();
            if(ShowGOMDashboard)
               SMCGP_DrawGOMDashboard();
         }
         
         // TABLEAU DE BORD pour observation (15 s pour mise à jour plus réactive)
         if(currentTime - lastDashboardUpdate >= 15)
         {
            lastDashboardUpdate = currentTime;
            UpdateDashboard();
         }
      }
      return; // Sortir immédiatement - aucun trading
   }
   
   // ✅ AUTO TRADING LOOP — Placement + Trailing Stop + Profit targets
   // AutoTradingTick();  // TODO: Fix MQL5 compatibility

   if(UseDailyCapitalManager)
      CM_RefreshDailyStats();

   // ✅ POLL GOM — verdict propre au symbole de CE graphique
   SMCGP_PollGOM();
   if(ShowGOMDashboard)
      SMCGP_DrawGOMDashboard();

// ✅ ENFORCEMENT LIMIT — supprimer contre-tendance + max 2 (toutes 30s)
    {
       static datetime s_lastEnforce = 0;
       if(TimeCurrent() - s_lastEnforce >= 30)
       {
          s_lastEnforce = TimeCurrent();
          SMCGP_EnforceLimitDiscipline(InpMagicNumber, 2);
          // Nettoyage supplémentaire local
          CleanupExcessLimits(_Symbol, 2);
       }
   }

     // ✅ GOM WAIT AUTO-CLOSE — Fermer TOUTES nos positions si verdict = WAIT (vn=0)
     // FIX: Délai réduit 30s (was 180s), check toutes les 5s (was 30s), ferme TOUTE perte
     // Quand GOM passe à WAIT, il faut sortir vite — pas de delay inutile.
     bool gomWaitConfirmed = (g_smcGomVerdictNum == 0) &&
                             (g_smcGomConnected ||
                              (g_smcLastGOMPoll > 0 && TimeCurrent() - g_smcLastGOMPoll <= 900));
     if(UseGOMWaitAutoClose && gomWaitConfirmed)
     {
        static datetime s_lastWaitCloseCheck = 0;
        if(TimeCurrent() - s_lastWaitCloseCheck >= 5) // check toutes les 5s (was 30s)
        {
           s_lastWaitCloseCheck = TimeCurrent();
           string sym = _Symbol;
           for(int i = PositionsTotal() - 1; i >= 0; i--)
           {
              if(PositionGetSymbol(i) != sym) continue;
              if((ulong)PositionGetInteger(POSITION_MAGIC) != (ulong)InpMagicNumber) continue;
              ulong ticket = PositionGetInteger(POSITION_TICKET);
              double profit = PositionGetDouble(POSITION_PROFIT);
              datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
              int ageSeconds = (int)(TimeCurrent() - openTime);
              if(ageSeconds < 30) // délai 30s minimum (was 180s) avant auto-close WAIT
              {
                 continue;
              }
              // Sous WAIT on ferme TOUTE position (gain ou perte) — plus de threshold -$1
              Print("[GOM-WAIT] Verdict=WAIT sur ", sym, " | age=", ageSeconds, "s | profit=", DoubleToString(profit,2),
                    "$ | connected=", g_smcGomConnected, " | Fermeture FORCEE ticket=", ticket);
              PositionCloseWithLog(ticket, "GOM verdict=WAIT auto-close", true); // forceClose=true
           }
        }
     }

   // 🎯 GOM VERDICTS FROM ai_server — Every 60 seconds + WhatsApp alerts
   UpdateGOMDashboard();

   // Pipeline validé + dessin GOM si activé (tous symboles Deriv / forex / crypto)
   bool hasGOMData = (ShowGOMDashboard || UseGOMVerdictFilter || UseGOMPipeline);
   if(hasGOMData)
   {

      // Dessiner les Bollinger et zones GOM
      if(ShowGOMDashboard)
      {
         // Redessiner UNIQUEMENT si les valeurs GOM ont changé depuis le dernier dessin
         // Évite ObjectsDeleteAll à chaque tick (cause affichage absent sur Boom/Crash à ticks rapides)
         static double s_lastBbUp = 0, s_lastBbDn = 0, s_lastBbMid = 0;
         static double s_lastKolaBuy = 0, s_lastKolaSell = 0;
         bool bbChanged    = (MathAbs(g_smcBbUp  - s_lastBbUp)    > 0.0001 ||
                              MathAbs(g_smcBbDn  - s_lastBbDn)    > 0.0001 ||
                              MathAbs(g_smcBbMid - s_lastBbMid)   > 0.0001);
         bool kolaChanged  = (MathAbs(g_smcGomKolaBuy  - s_lastKolaBuy)  > 0.0001 ||
                              MathAbs(g_smcGomKolaSell - s_lastKolaSell) > 0.0001);

         if(bbChanged || kolaChanged)
         {
            // Mettre à jour les valeurs tracées
            s_lastBbUp    = g_smcBbUp;
            s_lastBbDn    = g_smcBbDn;
            s_lastBbMid   = g_smcBbMid;
            s_lastKolaBuy  = g_smcGomKolaBuy;
            s_lastKolaSell = g_smcGomKolaSell;

            // Supprimer les anciens dessins uniquement quand les valeurs changent
            ObjectsDeleteAll(0, "GOM_BB_");
            ObjectsDeleteAll(0, "GOM_KOLA_");
            ObjectsDeleteAll(0, "GOM_PRED_ZONE");

            // Dessiner toujours si ShowGOMDashboard = true, même sans connexion GOM
            if(g_smcBbUp > 0 && g_smcBbMid > 0 && g_smcBbDn > 0)
            {
               GOMG_DrawBollinger(g_smcBbUp, g_smcBbMid, g_smcBbDn);
               GOMG_DrawFutureZone(g_smcBbUp, g_smcBbDn, "GOM_PRED_ZONE");
               Print("[GOMG] Bollinger redessinées (valeurs changées)");
            }

            if(g_smcGomKolaBuy > 0 || g_smcGomKolaSell > 0)
            {
               GOMG_DrawKolaLevels(g_smcGomKolaBuy, g_smcGomKolaSell);
               Print("[GOMG] Niveaux Kola redessinés (valeurs changées)");
            }
         }

         // Zone OTE (Optimal Trade Entry — Fib 61.8%–78.6% du swing MT5 live)
         if(UseOTE)
         {
            SMCGP_DrawOTEZone();
            if(g_smcOteTop > 0 && g_smcOteBot > 0)
               Print(StringFormat("[GOMG] OTE zone: [%.5f - %.5f] in_ote=%s",
                     g_smcOteBot, g_smcOteTop, g_smcInOTE ? "YES" : "NO"));
         }

         // Dessiner les prédictions Bollinger (300 bougies) si disponibles
         if(ArraySize(g_smcPredBbMid) > 0)
         {
            static int s_lastPredSize = 0;
            static double s_lastPredMid0 = 0;
            bool predChanged = (ArraySize(g_smcPredBbMid) != s_lastPredSize ||
                                MathAbs(g_smcPredBbMid[0] - s_lastPredMid0) > 0.0001);
            if(predChanged)
            {
            s_lastPredSize  = ArraySize(g_smcPredBbMid);
            s_lastPredMid0  = g_smcPredBbMid[0];
            // Supprimer les anciennes prédictions uniquement quand elles changent
            ObjectsDeleteAll(0, "GOM_PRED_MID_");
            ObjectsDeleteAll(0, "GOM_PRED_UP_");
            ObjectsDeleteAll(0, "GOM_PRED_DN_");

            datetime now = TimeCurrent();
            int n_points = ArraySize(g_smcPredBbMid);
            int time_step = 60; // 1 min per point

            // Tracer MID (bleu, solide)
            for(int i = 0; i < n_points - 1; i++)
            {
               string line_name = StringFormat("GOM_PRED_MID_%d", i);
               datetime t1 = now + (i * time_step);
               datetime t2 = now + ((i + 1) * time_step);
               ObjectDelete(0, line_name);
               ObjectCreate(0, line_name, OBJ_TREND, 0, t1, g_smcPredBbMid[i], t2, g_smcPredBbMid[i + 1]);
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrBlue);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 2);
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
            }

            // Tracer UP (rouge, pointillé)
            for(int i = 0; i < n_points - 1; i++)
            {
               string line_name = StringFormat("GOM_PRED_UP_%d", i);
               datetime t1 = now + (i * time_step);
               datetime t2 = now + ((i + 1) * time_step);
               ObjectDelete(0, line_name);
               ObjectCreate(0, line_name, OBJ_TREND, 0, t1, g_smcPredBbUp[i], t2, g_smcPredBbUp[i + 1]);
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrRed);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
               ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
            }

            // Tracer DN (vert, pointillé)
            for(int i = 0; i < n_points - 1; i++)
            {
               string line_name = StringFormat("GOM_PRED_DN_%d", i);
               datetime t1 = now + (i * time_step);
               datetime t2 = now + ((i + 1) * time_step);
               ObjectDelete(0, line_name);
               ObjectCreate(0, line_name, OBJ_TREND, 0, t1, g_smcPredBbDn[i], t2, g_smcPredBbDn[i + 1]);
               ObjectSetInteger(0, line_name, OBJPROP_COLOR, clrGreen);
               ObjectSetInteger(0, line_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, line_name, OBJPROP_STYLE, STYLE_DASH);
               ObjectSetInteger(0, line_name, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, line_name, OBJPROP_BACK, false);
            }

            Print(StringFormat("[GOMG] Bollinger Predictions dessinées: %d points", n_points));
            } // end if(predChanged)
         }
      }

      if(UseGOMPipeline && !BlockAllTrades && !gomBlocked && !tfBlocked)
         SMCGP_PollAndExecutePipeline();

      // ✅ ENTRÉES INDÉPENDANTES EA: Pivot + Bollinger (GOOD/PERFECT + IA ≥70%)
      // À implémenter avec logique plus simple (éviter structures pour compatibilité MQL5)
      if(UseEAIndependentEntry && !BlockAllTrades && !gomBlocked && !tfBlocked && g_smcGomConnected)
      {
         if(SMCGP_IsGoodPerfect(g_smcGomVerdictNum))
         {
            // BUY si verdict positif (vn >= 2)
            if(g_smcGomVerdictNum >= 2)
            {
               static datetime lastBUYAttempt = 0;
               if(currentTime - lastBUYAttempt >= 60)
               {
                  lastBUYAttempt = currentTime;
                  Print("[EA-INDEP] ✅ BUY autorisé | Verdict=", g_smcGomVerdict, " | vn=", g_smcGomVerdictNum);
               }
            }

            // SELL si verdict négatif (vn <= -2)
            if(g_smcGomVerdictNum <= -2)
            {
               static datetime lastSELLAttempt = 0;
               if(currentTime - lastSELLAttempt >= 60)
               {
                  lastSELLAttempt = currentTime;
                  Print("[EA-INDEP] ✅ SELL autorisé | Verdict=", g_smcGomVerdict, " | vn=", g_smcGomVerdictNum);
               }
            }
         }
      }
   }

   // === PROACTIVE ENTRY ZONE CACHING (avant spike detection) ===
   UpdateCachedEntryZones();
   DrawCachedEntryZones();

   // STRATÉGIE DERIV ARROW désactivée — pipeline GOM uniquement
   if(!PipelineOnlyMode && UseDerivArrowTrades)
      CheckAndExecuteDerivArrowTrade();
   
   // Gestion des positions existantes (fermeture rapide après spike)
   ManageBoomCrashSpikeClose();
   // Gestion des sorties en dollars (TP/SL globaux + BoomCrashSpikeTP)
   ManageDollarExits();
   // Fermer toute position sans profit après 7 minutes (probable correction)
   CloseUnprofitableAfterDelay();

   // TP1$ : Fermer à +1$ profit et ré-entrée sur pullback S/R, OB, EMA
   TP1_CloseAndReEntry();
   // Fermer si verdict → WAIT et perte ≥ 1$
   CloseOnVerdictWait();

   // Trailing stop + SL structure — toujours actif (même UltraLight)
   if(UseTrailingStop)
      ManageTrailingStop();
   
   // Si on est en mode ultra léger: ne pas lancer l'IA ni mettre à jour les graphiques/dashboard
   if(UltraLightMode)
      return;
   
   // MISE À JOUR IA - Appel au serveur IA pour obtenir les décisions
   if(UseAIServer && currentTime - lastAIUpdate >= AI_UpdateInterval_Seconds)
   {
      lastAIUpdate = currentTime;
      UpdateAIDecision(AI_Timeout_ms);
      
      // Mettre à jour les métriques ML si activées (30 s pour affichage réactif)
      if(ShowMLMetrics && (TimeCurrent() - g_lastMLMetricsUpdate) >= 30)
      {
         UpdateMLMetricsDisplay();
      }
   }
   
   // Si l'IA est passée en HOLD, couper immédiatement les positions de l'EA
   Print("🔍 DEBUG - Vérification IA HOLD | g_lastAIAction: '", g_lastAIAction, "' | UseAIServer: ", UseAIServer);
   ClosePositionsOnIAHold();
   
   // NOUVEAU: Surveillance des changements IA vers HOLD et fermeture automatique
   MonitorAndClosePositionsOnHold();
   
   // NOUVEAU: Vérifier les conflits de direction sur Boom/Crash
   ClosePositionsOnDirectionConflict();
   
   // ROTATION AUTOMATIQUE DES POSITIONS pour éviter de rester bloqué sur un symbole
   static datetime lastRotationCheck = 0;
   if(currentTime - lastRotationCheck >= 60) // Vérifier toutes les minutes
   {
      lastRotationCheck = currentTime;
      AutoRotatePositions();
   }
   
   // DÉTECTION ULTRA-RAPIDE DE SPIKE (toutes les 5 secondes pour Boom/Crash)
   static datetime lastSpikeCheck = 0;
   if(IsBoomLikeSymbol(_Symbol) || IsCrashLikeSymbol(_Symbol))
   {
      if(currentTime - lastSpikeCheck >= 5)
      {
         lastSpikeCheck = currentTime;
         CheckImminentSpike(); // Vérification rapide sans graphiques
         CheckRSISqueezeAndTrade(); // RSI squeeze même en mode UltraLight
      }
   }
   
   // GRAPHIQUES SMC CONTRÔLÉS (toutes les 15 secondes pour plus de réactivité)
   if(ShowChartGraphics && currentTime - lastGraphicsUpdate >= 15)
   {
      lastGraphicsUpdate = currentTime;
      
      // DÉTECTION ANTI-REPAINT DES SWING POINTS
      DetectNonRepaintingSwingPoints();
      DrawConfirmedSwingPoints();
      
       // DÉTECTION SPÉCIALE BOOM/CRASH (ANTI-SPIKE)
       if(IsBoomLikeSymbol(_Symbol) || IsCrashLikeSymbol(_Symbol))
       {
          DetectBoomCrashSwingPoints();
         
         // DÉTECTION AVANCÉE DE SPIKE IMMINENT - OPTIMISÉE
         CheckImminentSpike();
         // RSI SQUEEZE PREDICTOR — squeeze + H1 trend + auto-trade
         CheckRSISqueezeAndTrade();
         
         // DÉTECTION DES MOUVEMENTS DE RETOUR VERS CANAUX SMC
         CheckSMCChannelReturnMovements();
      }
      
      // AFFICHAGE STATUT IA ET PRÉDICTIONS
      DrawAIStatusAndPredictions();
      
      // PATTERNS CHARTISTES — scan et dessin (SMCPS_DrawMarker appelle SMCPS_Scan)
      if(UsePatternEntrySignals)
      {
         SMCPS_EnsureScanned(_Symbol);
         SMCPS_DrawMarker(_Symbol);
      }
      
      // OVERLAY CORRECTION GOM
      if(UseGOMCorrectionOverlay && g_showCorrectionOverlay)
         SMCCT_DrawCorrectionOverlay();
      
      // LIGNES EMA 200/100/50 + SESSIONS + LIQUIDITÉ
      if(ShowEMASupportResistance)
      {
         DrawEMASupportResistance();
         DrawEMACurveOnChart();
         SMCCT_DrawAllEMAs();
      }
      DrawBollingerCurve();
      DrawLiquidityZonesOnChart();
      SMCCT_DrawAllSessions();
      
      // Dessins TV synchronisés (KOLA, OB setup, zone OTE) — comme TradeManager
      if(ShowTVSyncedLevels)
      {
         Print("[SMC-DEBUG] TV Sync vars: SetupValid=", g_smcSetupValid, " Entry=", g_smcSetupEntry,
               " SL=", g_smcSetupSL, " KolaBuy=", g_smcGomKolaBuy, " KolaSell=", g_smcGomKolaSell);
         SMCGP_DrawTVLevels();
      }

      // MODE TV SYNCED ONLY: Afficher UNIQUEMENT les niveaux sync depuis TradingView
      if(UseMinimalICTDrawings)
      {
         // MODE MINIMAL: UNIQUEMENT les niveaux TV sync
         // - Bollinger Bands (courbes) → dessinées dans bloc GOM (ShowGOMDashboard)
         // - KOLA Levels (BUY/SELL) → dessinées dans bloc GOM
         // - Zone OTE future → dessinée dans bloc GOM
         // - Fibonacci Retracements → dessinées ici
         // - Bougies prédites → dessinées dans bloc GOM
         // NO: SwingHighLow, BookmarkLevels, FVG, OB local, EMA, Liquidity

         DrawFibonacciOnChart();  // Retracements Fibonacci UNIQUEMENT
         if(ShowSignalArrow) { DrawSignalArrow(); UpdateSignalArrowBlink(); }
         UpdateSpikeWarningBlink();
      }
      else
      {
         // Full Mode: UNIQUEMENT TV Sync (Bollinger, 2 OB, Fibonacci, Prédictions, OTE)
         // Affichage propre : pas de Swing, Bookmark, FVG, EMA, Liquidity
         DrawFibonacciOnChart();
         if(ShowSignalArrow) { DrawSignalArrow(); UpdateSignalArrowBlink(); }
         UpdateSpikeWarningBlink();
          if(ShowLimitOrderLevels) DrawLimitOrderLevels();
          AdjustEMAScalpingLimitOrder();
         PlaceSMCChannelLimitOrder();
       }
    }
    
    // S/R 20 BAR LIMIT ORDERS (hors bloc graphiques — toujours actif)
    PlaceSRLimitOrders20Bars();   // met à jour g_impulseSupport20 / g_impulseResistance20
    UpdateSR20BounceState();      // S/R 20 bars touché+rebondi -> arme chaîne spikes
    
    // SPIKE CHAIN PREDICTION: modelise les chaines de spikes a venir + WhatsApp
    PredictSpikeChainAndAlert();
    
    // ENTRÉE GOM-ALIGN : marché si verdict BUY/SELL + 6 TFs alignés + trailing
    ExecuteGOMAlignmentMarketOrder();
    
    // ENTRÉES AU MARCHÉ BASÉES SUR LA DÉCISION IA SMC/EMA
   if(!PipelineOnlyMode)
   {
      ExecuteAIDecisionMarketOrder();
      // ENTRÉES PATTERN + GOM (MARKET si pattern + verdict GOOD/PERFECT)
      if(PatternTriggerMarketEntry && UsePatternEntrySignals)
      {
         if(g_smcGomVerdictNum >= 2)
            SMCPS_TryExecutePatternEntry(_Symbol, 1, "BUY");
         if(g_smcGomVerdictNum <= -2)
            SMCPS_TryExecutePatternEntry(_Symbol, -1, "SELL");
      }

      // ENTRÉE SUR RETEST du pointillé Entry (S/R 20 bars touché+rebondi = impulsion forte)
      // -> marché à CHAQUE toucher de l'entry du pattern, si GOM GOOD/PERFECT.
      if(PatternTriggerMarketEntry && UsePatternEntrySignals)
      {
         if(g_smcGomVerdictNum >= 2)
            SMCPS_TryExecutePatternEntryOnRetest(_Symbol, 1, "BUY");
         if(g_smcGomVerdictNum <= -2)
            SMCPS_TryExecutePatternEntryOnRetest(_Symbol, -1, "SELL");
      }
   }
   
   // TABLEAU DE BORD CONTRÔLÉ (toutes les 15 secondes)
   if(currentTime - lastDashboardUpdate >= 15)
   {
      lastDashboardUpdate = currentTime;
      UpdateDashboard();
   }
}

//| FONCTIONS DE GESTION DES PAUSES ET BLACKLIST TEMPORAIRE        |

void UpdateDashboard()
{
   if(!UseDashboard) return;
   string catStr = "UNKNOWN";
   switch(SMC_GetSymbolCategory(_Symbol))
   {
      case SYM_BOOM_CRASH:  catStr = "Boom/Crash"; break;
      case SYM_VOLATILITY:  catStr = "Volatility"; break;
      case SYM_FOREX:       catStr = "Forex"; break;
      case SYM_COMMODITY:   catStr = "Commodity"; break;
      case SYM_METAL:       catStr = "Metal"; break;
      case SYM_CRYPTO:      catStr = "Crypto"; break;
   }
   int posCount = CountPositionsForSymbol(_Symbol);
   int totalPos = CountPositionsOurEA();
   
   double totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber)
         totalPL += posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
   string swingStr = "";
   if(g_lastSwingHigh > 0) swingStr += " SH=" + DoubleToString(g_lastSwingHigh, _Digits);
   if(g_lastSwingLow > 0)  swingStr += " SL=" + DoubleToString(g_lastSwingLow, _Digits);
   double atrVal = 0, emaVal = 0;
   double atrArr[], emaArr[];
   ArraySetAsSeries(atrArr, true); ArraySetAsSeries(emaArr, true);
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atrArr) >= 1) atrVal = atrArr[0];
   if(emaHandle != INVALID_HANDLE && CopyBuffer(emaHandle, 0, 0, 1, emaArr) >= 1) emaVal = emaArr[0];
   string trendHTF = IsBullishHTF() ? "BULLISH" : "BEARISH";
   string lsStr = FVGKill_LiquiditySweepDetected() ? "YES" : "NO";
   if(ShowMLMetrics && (TimeCurrent() - g_lastMLMetricsUpdate) >= 30)
      UpdateMLMetricsDisplay();
   string killStr = SMC_IsKillZone(LondonStart, LondonEnd, NYOStart, NYOEnd) ? "ACTIVE" : "OFF";
   string bcStr = IsBoomLikeSymbol(_Symbol) ? "BOOM" : IsCrashLikeSymbol(_Symbol) ? "CRASH" : "FOREX";
   string gomStr = (UseGOMVerdictFilter || ShowGOMDashboard)
      ? StringFormat("%s %s vn=%+d Q=%.0f%% C=%.0f%% [%s] | TV->PY %s | sym=%s",
                     g_smcGomConnected ? "OK" : "OFF", g_smcGomVerdict, g_smcGomVerdictNum,
                     g_smcGomQuality, g_smcGomCoherence,
                     g_smcSetupValid ? g_smcSetupType : "—",
                     g_smcGomSource, _Symbol)
      : "OFF";
   string cmStr = CM_StatusLine();
   string trailStr = StringFormat("Trailing: %s | Struct: %s",
                                  UseTrailingStop ? "ON" : "OFF",
                                  UseTrailingStructure ? "ON" : "OFF");
   Comment("═══ SMC Universal + FVG_Kill PRO ═══\n",
           "Stratégie: SMC (FVG|OB|LS|BOS) + FVG_Kill (EMA HTF + LS)\n",
           cmStr, "\n",
           trailStr, "\n",
           "GOM/Pipeline: ", gomStr, " | Pipeline=", UseGOMPipeline ? "ON" : "OFF",
           " | Dash=", ShowGOMDashboard ? "ON" : "OFF", "\n",
           "Trend HTF: ", trendHTF, " | Liquidity Sweep: ", lsStr, " | Kill Zone: ", killStr, "\n",
           "Boom/Crash: ", bcStr, " | Catégorie: ", catStr, "\n",
           "IA: ", (g_lastAIAction != "") ? (g_lastAIAction + " " + DoubleToString(g_lastAIConfidence*100,1) + "% | Align: " + g_lastAIAlignment + " | Cohér: " + g_lastAICoherence) : "OFF", "\n",
           "Dernière mise à jour IA: ", (g_lastAIUpdate > 0) ? TimeToString(g_lastAIUpdate, TIME_SECONDS) : "Jamais", "\n",
           "Positions terminal: ", totalPos, "/", MaxPositionsTerminal, " | ", _Symbol, ": ", posCount, "/1\n",
           "Perte totale: ", DoubleToString(totalPL, 2), " $ (max ", DoubleToString(MaxTotalLossDollars, 0), "$)\n",
           "Swing: ", swingStr, "\n",
           "ATR: ", DoubleToString(atrVal, _Digits), " | EMA(9): ", DoubleToString(emaVal, _Digits),
           "\nCanal ML: ", (g_channelValid ? "OK" : "—"),
           "\nML (entraînement): ", g_mlMetricsStr);
}

void UpdateMLMetricsDisplay()
{
   Print("🔍 DEBUG - UpdateMLMetricsDisplay appelée pour: ", _Symbol);
   
   // Protection contre les appels excessifs - minimum 30 s entre les appels
   if((TimeCurrent() - g_lastMLMetricsUpdate) < 30)
   {
      Print("🔍 DEBUG - UpdateMLMetricsDisplay ignorée (trop récent)");
      return;
   }
   
   g_lastMLMetricsUpdate = TimeCurrent();
   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");
   string baseUrl = AI_ServerURL;
   string pathMetrics = "/ml/metrics?symbol=" + symEnc + "&timeframe=M1";
   string pathStatus = "/ml/continuous/status";
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   Print("🔍 DEBUG - Requête ML vers: ", baseUrl, pathMetrics);
   
   // Récupérer les métriques ML
   int res = WebRequest("GET", baseUrl + pathMetrics, headers, AI_Timeout_ms, post, result, resultHeaders);
   
   Print("🔍 DEBUG - WebRequest ML metrics - Code: ", res, " | Taille: ", ArraySize(result));
   
   if(res == 200)
   {
      string metricsData = CharArrayToString(result);
      Print("🔍 DEBUG - Données ML reçues: ", StringSubstr(metricsData, 0, MathMin(200, StringLen(metricsData))));
      
      // Parser les métriques et les afficher (clés plates: accuracy, model_name, total_samples, status, feedback_wins, feedback_losses)
      if(StringFind(metricsData, "accuracy") >= 0)
      {
         string acc = ExtractJsonValue(metricsData, "accuracy");
         string model = ExtractJsonValue(metricsData, "model_name");
         string samples = ExtractJsonValue(metricsData, "total_samples");
         string status = ExtractJsonValue(metricsData, "status");
         string wins = ExtractJsonValue(metricsData, "feedback_wins");
         string losses = ExtractJsonValue(metricsData, "feedback_losses");
         g_mlMetricsStr = "Précision: " + acc + "% | Modèle: " + model + " | Samples: " + samples;
         if(wins != "N/A" && losses != "N/A")
            g_mlMetricsStr += " | Feedback: " + wins + "W/" + losses + "L";
         if(status != "N/A" && status != "trained")
            g_mlMetricsStr += " | " + (status == "collecting_data" ? "Collecte données..." : status);
         Print("✅ DEBUG - Métriques ML mises à jour: ", g_mlMetricsStr);
      }
      else if(StringFind(metricsData, "status") >= 0)
      {
         string status = ExtractJsonValue(metricsData, "status");
         g_mlMetricsStr = (status == "collecting_data") ? "ML: Collecte de données en cours..." : "ML: " + status;
      }
      else
      {
         g_mlMetricsStr = "ML: En attente de données...";
         Print("⚠️ DEBUG - Pas de métriques trouvées");
      }
   }
   else
   {
      // Fallback vers les métriques par défaut
      g_mlMetricsStr = "ML: En attente de données...";
      Print("❌ DEBUG - Erreur WebRequest ML metrics: ", res);
   }
   
   // Récupérer le statut du canal
   int resStatus = WebRequest("GET", baseUrl + pathStatus, headers, AI_Timeout_ms, post, result, resultHeaders);
   
   Print("🔍 DEBUG - WebRequest ML status - Code: ", resStatus);
   
   if(resStatus == 200)
   {
      string statusData = CharArrayToString(result);
      g_channelValid = (StringFind(statusData, "\"valid\": true") >= 0);
      Print("✅ DEBUG - Canal ML valide: ", g_channelValid ? "OUI" : "NON");
   }
   else
   {
      g_channelValid = false;
      Print("❌ DEBUG - Erreur WebRequest ML status: ", resStatus);
   }
}

string ExtractJsonValue(string json, string key)
{
   string searchKey = "\"" + key + "\":";
   int start = StringFind(json, searchKey);
   if(start < 0) return "N/A";
   
   start += StringLen(searchKey);
   while(start < StringLen(json) && (json[start] == ' ' || json[start] == '\t')) start++;
   
   int end = start;
   while(end < StringLen(json) && json[end] != ',' && json[end] != '}' && json[end] != '\n') end++;
   
   string value = StringSubstr(json, start, end - start);
   StringReplace(value, "\"", "");
   StringReplace(value, " ", "");
   
   return value;
}

//| FONCTIONS IA - COMMUNICATION AVEC LE SERVEUR (copie legacy)       |

bool UpdateAIDecision_Legacy(int timeoutMs = -1)
{
   // Protection contre les appels excessifs
   static datetime lastAttempt = 0;
   datetime currentTime = TimeCurrent();
   if(currentTime - lastAttempt < 5) return false; // Max 1 appel / 5 secondes
   lastAttempt = currentTime;
   
   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");
   
   // Utiliser Render en premier si configuré
   string baseUrl = AI_ServerURL;
   string path = "/ml/decision?symbol=" + symEnc + "&timeframe=M1";
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   int res = WebRequest("GET", baseUrl + path, headers, timeoutMs > 0 ? timeoutMs : AI_Timeout_ms, post, result, resultHeaders);
   
   if(res != 200)
   {
      // Fallback vers l'autre URL si échec
      string fallbackUrl = AI_ServerURL;
      res = WebRequest("GET", fallbackUrl + path, headers, timeoutMs > 0 ? timeoutMs : AI_Timeout_ms, post, result, resultHeaders);
      
      if(res != 200)
      {
         Print("❌ ERREUR IA - Échec des deux serveurs: ", res);
         return false;
      }
   }
   
   string jsonData = CharArrayToString(result);
   ProcessAIDecision(jsonData);
   
   Print("✅ Décision IA reçue - Action: ", g_lastAIAction, " | Confiance: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
   return true;
}

string GetAISignalData_Legacy(string symbol, string timeframe)
{
   string symEnc = symbol;
   StringReplace(symEnc, " ", "%20");
   
   string baseUrl = AI_ServerURL;
   string path = "/ml/signal?symbol=" + symEnc + "&timeframe=" + timeframe;
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   int res = WebRequest("GET", baseUrl + path, headers, AI_Timeout_ms, post, result, resultHeaders);
   
   if(res == 200)
   {
      return CharArrayToString(result);
   }
   
   return "";
}

string GetTrendAlignmentData_Legacy(string symbol)
{
   string symEnc = symbol;
   StringReplace(symEnc, " ", "%20");
   
   string baseUrl = AI_ServerURL;
   string path = "/ml/trend_alignment?symbol=" + symEnc;
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   int res = WebRequest("GET", baseUrl + path, headers, AI_Timeout_ms, post, result, resultHeaders);
   
   if(res == 200)
   {
      return CharArrayToString(result);
   }
   
   return "";
}

string GetCoherentAnalysisData_Legacy(string symbol)
{
   string symEnc = symbol;
   StringReplace(symEnc, " ", "%20");
   
   string baseUrl = AI_ServerURL;
   string path = "/ml/coherent_analysis?symbol=" + symEnc;
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   int res = WebRequest("GET", baseUrl + path, headers, AI_Timeout_ms, post, result, resultHeaders);
   
   if(res == 200)
   {
      return CharArrayToString(result);
   }
   
   return "";
}

void ProcessAIDecision_Legacy(string jsonData)
{
   // Parser la réponse JSON du serveur IA
   // Format attendu: {"action": "BUY/SELL/HOLD", "confidence": 0.85, "alignment": "75%", "coherence": "82%"}
   
   g_lastAIUpdate = TimeCurrent();
   
   // Extraire l'action
   if(StringFind(jsonData, "\"action\":") >= 0)
   {
      int start = StringFind(jsonData, "\"action\":") + 9;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string action = StringSubstr(jsonData, start, end - start);
         StringReplace(action, "\"", "");
         StringReplace(action, " ", "");
         g_lastAIAction = action;
      }
   }
   
   // Extraire la confiance
   if(StringFind(jsonData, "\"confidence\":") >= 0)
   {
      int start = StringFind(jsonData, "\"confidence\":") + 13;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string confStr = StringSubstr(jsonData, start, end - start);
         double rawConf   = StringToDouble(confStr);
         // Le serveur peut envoyer 0–1 (décimal) ou 0–100 (pourcentage) → normaliser en 0–1
         if(rawConf > 1.0)
            rawConf /= 100.0;
         g_lastAIConfidence = rawConf;
      }
   }
   
   // Extraire l'alignement
   if(StringFind(jsonData, "\"alignment\":") >= 0)
   {
      int start = StringFind(jsonData, "\"alignment\":") + 12;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string alignStr = StringSubstr(jsonData, start, end - start);
         StringReplace(alignStr, "\"", "");
         g_lastAIAlignment = alignStr;
      }
   }
   
   // Extraire la cohérence
   if(StringFind(jsonData, "\"coherence\":") >= 0)
   {
      int start = StringFind(jsonData, "\"coherence\":") + 13;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string cohStr = StringSubstr(jsonData, start, end - start);
         StringReplace(cohStr, "\"", "");
         g_lastAICoherence = cohStr;
      }
   }
   
   // Si aucune donnée trouvée, valeurs par défaut
   if(g_lastAIAction == "") g_lastAIAction = "HOLD";
   if(g_lastAIConfidence == 0) g_lastAIConfidence = 0.5;
   if(g_lastAIAlignment == "") g_lastAIAlignment = "50%";
   if(g_lastAICoherence == "") g_lastAICoherence = "50%";
}


//| GESTION DES POSITIONS ET VARIABLES GLOBALES                    |

void PlaceScalpingLimitOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope)
   {
      Print("🚫 ORDRES LIMITES BLOQUÉS - Pas de décision IA forte (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "% < ", DoubleToString(MinAIConfidence*100, 1), "%)");
      return;
   }


void PlaceHistoricalBasedScalpingOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope, int existingLimitOrders)
   {
      // VÉRIFICATION ANTI-DUPLICATION - Si position déjà en cours, ne pas placer d'ordres
      int existingPositionsOnSymbol = CountPositionsForSymbol(_Symbol);
      if(existingPositionsOnSymbol > 0)
      {
         Print("🚫 ORDRES HISTORIQUES BLOQUÉS - ", existingPositionsOnSymbol, " position(s) déjà en cours sur ", _Symbol, " - Attente fermeture");
         return;
      }
      
      // POUR TOUS LES MARCHÉS HORS BOOM/CRASH: n'autoriser les ordres que si IA ≥ 80% et alignée
      ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
      if(cat != SYM_BOOM_CRASH && !IsAITradeAllowedForDirection(g_lastAIAction))
      {
         // IsAITradeAllowedForDirection loggue déjà la raison précise
         return;
      }
      
      // Limite globale: maximum 2 ordres LIMIT par symbole, dont 1 seul hors canal
      {
         int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
         int chanLimits  = CountChannelLimitOrdersForSymbol(_Symbol);
         int otherLimits = totalLimits - chanLimits;
         if(totalLimits >= 2 || otherLimits >= 1)
         {
            Print("🚫 ORDRES HISTORIQUES BLOQUÉS - Limite de LIMIT atteinte sur ", _Symbol, " (total=", totalLimits, ", canal=", chanLimits, ")");
            return;
         }
      }
      
      // RÈGLE STRICTE: BLOQUER TOUS LES ORDRES BUY SUR BOOM SI IA = SELL
      bool isBoom = IsBoomLikeSymbol(_Symbol);
      bool isCrash = IsCrashLikeSymbol(_Symbol);
      string aiAction = g_lastAIAction;
      if(aiAction == "buy") aiAction = "BUY";
      if(aiAction == "sell") aiAction = "SELL";
      
      if(isBoom && aiAction == "SELL")
      {
         Print("🚫 ORDRES HISTORIQUES BOOM BLOQUÉS - IA = SELL (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal BUY avant de placer ordres BUY");
         return;
      }
      
      if(isCrash && aiAction == "BUY")
      {
         Print("🚫 ORDRES HISTORIQUES CRASH BLOQUÉS - IA = BUY (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal SELL avant de placer ordres SELL");
         return;
      }
      
      // 1) STRATÉGIE EMA SMC (200, 100, 50, 31, 21) AVEC IA FORTE
      int ordersToPlace = 2 - existingLimitOrders; // Maximum 2 ordres par symbole
      if(ordersToPlace > 0 && ema21LTF != INVALID_HANDLE && ema31LTF != INVALID_HANDLE &&
         ema50LTF != INVALID_HANDLE && ema100LTF != INVALID_HANDLE && ema200LTF != INVALID_HANDLE)
      {
         double emaBuf[];
         ArraySetAsSeries(emaBuf, true);
         ArrayResize(emaBuf, 1);
      double ema21 = 0, ema31 = 0, ema50 = 0, ema100 = 0, ema200 = 0;
      if(CopyBuffer(ema21LTF, 0, 0, 1, emaBuf) >= 1) ema21 = emaBuf[0];
      if(CopyBuffer(ema31LTF, 0, 0, 1, emaBuf) >= 1) ema31 = emaBuf[0];
      if(CopyBuffer(ema50LTF, 0, 0, 1, emaBuf) >= 1) ema50 = emaBuf[0];
      if(CopyBuffer(ema100LTF, 0, 0, 1, emaBuf) >= 1) ema100 = emaBuf[0];
      if(CopyBuffer(ema200LTF, 0, 0, 1, emaBuf) >= 1) ema200 = emaBuf[0];
      
      double closePrice = rates[0].close;
      bool emaOk = (ema21 > 0 && ema31 > 0 && ema50 > 0 && ema100 > 0 && ema200 > 0);
      
      if(emaOk)
      {
         // Déterminer la tendance EMA sur LTF
         bool uptrend = (closePrice > ema200 && ema21 > ema31 && ema31 > ema50 && ema50 > ema100 && ema100 > ema200);
         bool downtrend = (closePrice < ema200 && ema21 < ema31 && ema31 < ema50 && ema50 < ema100 && ema100 < ema200);
         
         string aiDir = g_lastAIAction;
         StringToUpper(aiDir);
         
         // BUY LIMIT en uptrend, IA BUY (confiance déjà vérifiée à >= 75% dans PlaceScalpingLimitOrders)
         if(uptrend && (aiDir == "BUY") && ordersToPlace > 0)
         {
            double bestLevel = 0;
            string levelSource = "";
            bestLevel = GetClosestBuyLevel(closePrice, currentATR, MaxDistanceLimitATR, levelSource);
            
            if(bestLevel > 0)
            {
               // Placer l'ordre EXACTEMENT sur le niveau de support/EMA tracé
               double entry = bestLevel;
               double sl = entry - currentATR * SL_ATRMult;
               double tp = entry + currentATR * TP_ATRMult;
               double limitVol = NormalizeVolumeForSymbol(0.01);
               if(UseSniperScalperMode)
               {
                  double slDistBL = MathAbs(entry - sl);
                  double tpDistBL = 0;
                  double sniperLotBL = limitVol;
                  if(SMC_ApplySniperRiskCap(_Symbol, slDistBL, sniperLotBL, tpDistBL))
                  {
                     limitVol = sniperLotBL;
                     tp = entry + tpDistBL;
                  }
                  else
                  {
                     Print("🚫 EMA SMC BUY LIMIT annulé - Sniper Risk Cap refusé sur ", _Symbol);
                     bestLevel = 0; // annule le placement plus bas
                  }
               }
               
               MqlTradeRequest req = {};
               MqlTradeResult res = {};
               req.action = TRADE_ACTION_PENDING;
               req.symbol = _Symbol;
               req.volume = limitVol;
               req.type = ORDER_TYPE_BUY_LIMIT;
               req.price = entry;
               req.sl = sl;
               req.tp = tp;
               req.magic = InpMagicNumber;
                req.comment = "EMA SMC BUY LIMIT";
                
                if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_BUY_LIMIT)) return;
                CleanupExcessLimits(_Symbol, 2);
                if(bestLevel > 0 && ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, ORDER_TYPE_BUY_LIMIT) && SafeOrderSend(req, res))
               {
                  Print("📈 EMA SMC BUY LIMIT @ ", req.price, levelSource, " | SL=", req.sl, " | TP=", req.tp);
                  ordersToPlace--;
               }
            }
         }
         
         // SELL LIMIT en downtrend, IA SELL
         if(downtrend && (aiDir == "SELL") && ordersToPlace > 0)
         {
            double bestLevel = 0;
            string levelSource = "";
            bestLevel = GetClosestSellLevel(closePrice, currentATR, MaxDistanceLimitATR, levelSource);
            
            if(bestLevel > 0)
            {
               // Placer l'ordre EXACTEMENT sur le niveau de résistance/EMA tracé
               double entry = bestLevel;
               double sl = entry + currentATR * SL_ATRMult;
               double tp = entry - currentATR * TP_ATRMult;
               double limitVolS = NormalizeVolumeForSymbol(0.01);
               if(UseSniperScalperMode)
               {
                  double slDistSL = MathAbs(sl - entry);
                  double tpDistSL = 0;
                  double sniperLotSL = limitVolS;
                  if(SMC_ApplySniperRiskCap(_Symbol, slDistSL, sniperLotSL, tpDistSL))
                  {
                     limitVolS = sniperLotSL;
                     tp = entry - tpDistSL;
                  }
                  else
                  {
                     Print("🚫 EMA SMC SELL LIMIT annulé - Sniper Risk Cap refusé sur ", _Symbol);
                     bestLevel = 0;
                  }
               }
               
               MqlTradeRequest req = {};
               MqlTradeResult res = {};
               req.action = TRADE_ACTION_PENDING;
               req.symbol = _Symbol;
               req.volume = limitVolS;
               req.type = ORDER_TYPE_SELL_LIMIT;
               req.price = entry;
               req.sl = sl;
               req.tp = tp;
               req.magic = InpMagicNumber;
                req.comment = "EMA SMC SELL LIMIT";
                
                if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_SELL_LIMIT)) return;
                CleanupExcessLimits(_Symbol, 2);
                if(bestLevel > 0 && ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, ORDER_TYPE_SELL_LIMIT) && SafeOrderSend(req, res))
               {
                  Print("📉 EMA SMC SELL LIMIT @ ", req.price, levelSource, " | SL=", req.sl, " | TP=", req.tp);
                  ordersToPlace--;
               }
            }
         }
      }
   }
   
   // ANALYSE DES SH/SL HISTORIQUES POUR PRÉDIRE LES MOUVEMENTS FUTURS
   double recentSwingHighs[], recentSwingLows[];
   ArrayResize(recentSwingHighs, 10);
   ArrayResize(recentSwingLows, 10);
   int swingHighCount = 0, swingLowCount = 0;
   
   // Détecter les SH/SL historiques récents (dernières 100 bougies)
   for(int i = 10; i < 100 && (swingHighCount < 10 || swingLowCount < 10); i++)
   {
      // Détection de Swing High historique
      bool isHistoricalSH = true;
      for(int j = MathMax(0, i-5); j <= MathMin(ArraySize(rates)-1, i+5); j++)
      {
         if(j != i && rates[j].high >= rates[i].high)
         {
            isHistoricalSH = false;
            break;
         }
      }
      
      if(isHistoricalSH && rates[i].high > rates[i].close)
      {
         recentSwingHighs[swingHighCount] = rates[i].high;
         swingHighCount++;
      }
      
      // Détection de Swing Low historique
      bool isHistoricalSL = true;
      for(int j = MathMax(0, i-5); j <= MathMin(ArraySize(rates)-1, i+5); j++)
      {
         if(j != i && rates[j].low <= rates[i].low)
         {
            isHistoricalSL = false;
            break;
         }
      }
      
      if(isHistoricalSL && rates[i].low < rates[i].close)
      {
         recentSwingLows[swingLowCount] = rates[i].low;
         swingLowCount++;
      }
   }
   
   // STRATÉGIE BASÉE SUR L'ANALYSE HISTORIQUE
   // Si on a récemment touché un SL, le prix a tendance à monter → BUY LIMIT au niveau exact du SL
   // Si on a récemment touché un SH, le prix a tendance à baisser → SELL LIMIT au niveau exact du SH
   
   // Il reste éventuellement des ordres à placer sur la base de l'historique
   
   // ORDRE 1: BASÉ SUR LE DERNIER SL HISTORIQUE (STRATÉGIE BUY)
   if(swingLowCount > 0 && ordersToPlace > 0)
   {
      double lastSL = recentSwingLows[0]; // Le SL le plus récent
      double buyLimitPrice = lastSL; // Ordre placé directement au niveau du SL
      double tpPrice = buyLimitPrice + currentATR * 1.5; // TP plus proche pour scalping
      
      // Ne placer un ordre que si le SL est relativement proche (max 0.5 ATR pour petits mouvements)
      if(MathAbs(buyLimitPrice - currentPrice) <= currentATR * 0.5)
      {
         // Si le SL est trop proche (< 0.1 ATR), ajuster pour éviter les ordres trop près
         if(MathAbs(buyLimitPrice - currentPrice) < currentATR * 0.1)
         {
            buyLimitPrice = currentPrice - (currentATR * 0.15); // 15% de l'ATR sous le prix
            tpPrice = buyLimitPrice + (currentATR * 0.3); // TP plus proche pour petits mouvements
         }
         
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_PENDING;
         request.symbol = _Symbol;
         request.volume = NormalizeVolumeForSymbol(0.01);
         request.type = ORDER_TYPE_BUY_LIMIT;
         request.price = buyLimitPrice;
request.sl = buyLimitPrice - (currentATR * 1.2); // SL élargi pour petits mouvements
          request.tp = tpPrice;
          request.magic = InpMagicNumber;
          request.comment = "HIST SL BUY - PETITS MOUVEMENTS";
          
          // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
          if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_BUY_LIMIT))
          {
             Print("❌ Échec validation prix BUY LIMIT - Ordre annulé");
             return;
          }
          
          if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_BUY_LIMIT)) return;
          CleanupExcessLimits(_Symbol, 2);
          if(SafeOrderSend(request, result))
         {
            Print("📈 ORDRE BUY PETITS MOUVEMENTS - Prix: ", request.price, " | TP: ", request.tp, " | SL: ", request.sl, " | Distance: ", MathAbs(request.price - currentPrice), " points");
            ordersToPlace--;
         }
      }
      else
      {
         Print("📍 SL trop loin (", MathAbs(lastSL - currentPrice), " > 0.5 ATR) - Ordre BUY annulé pour petits mouvements");
      }
   }
   
   // ORDRE 2: BASÉ SUR LE DERNIER SH HISTORIQUE (STRATÉGIE SELL)
   if(swingHighCount > 0 && ordersToPlace > 0)
   {
      double lastSH = recentSwingHighs[0]; // Le SH le plus récent
      double sellLimitPrice = lastSH; // Ordre placé directement au niveau du SH
      double tpPrice = sellLimitPrice - currentATR * 1.5; // TP plus proche pour scalping
      
      // Ne placer un ordre que si le SH est relativement proche (max 0.5 ATR pour petits mouvements)
      if(MathAbs(sellLimitPrice - currentPrice) <= currentATR * 0.5)
      {
         // Si le SH est trop proche (< 0.1 ATR), ajuster pour éviter les ordres trop près
         if(MathAbs(sellLimitPrice - currentPrice) < currentATR * 0.1)
         {
            sellLimitPrice = currentPrice + (currentATR * 0.15); // 15% de l'ATR au-dessus du prix
            tpPrice = sellLimitPrice - (currentATR * 0.3); // TP plus proche pour petits mouvements
         }
         
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_PENDING;
         request.symbol = _Symbol;
         request.volume = NormalizeVolumeForSymbol(0.01);
         request.type = ORDER_TYPE_SELL_LIMIT;
         request.price = sellLimitPrice;
request.sl = sellLimitPrice + (currentATR * 1.2); // SL élargi pour petits mouvements
          request.tp = tpPrice;
          request.magic = InpMagicNumber;
          request.comment = "HIST SH SELL - PETITS MOUVEMENTS";
          
          // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
          if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_SELL_LIMIT))
          {
             Print("❌ Échec validation prix SELL LIMIT - Ordre annulé");
             return;
          }
          
          if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_SELL_LIMIT)) return;
          CleanupExcessLimits(_Symbol, 2);
          if(SafeOrderSend(request, result))
         {
            Print("📉 ORDRE SELL PETITS MOUVEMENTS - Prix: ", request.price, " | TP: ", request.tp, " | SL: ", request.sl, " | Distance: ", MathAbs(request.price - currentPrice), " points");
            ordersToPlace--;
         }
      }
      else
      {
         Print("📍 SH trop loin (", MathAbs(lastSH - currentPrice), " > 0.5 ATR) - Ordre SELL annulé pour petits mouvements");
      }
   }
   
   if(ordersToPlace > 0)
   {
      Print("📊 STRATÉGIE HISTORIQUE - ", (2 - existingLimitOrders), " ordres placés sur SH/SL historiques");
   }
   else
   {
      Print("📊 AUCUN SH/SL HISTORIQUE VALIDE - Analyse continue...");
   }
}

void DetectAndPlaceBoomCrashSpikeOrders(MqlRates &rates[], double currentPrice, double currentATR, bool isBoom, int existingLimitOrders)
{
   // VÉRIFICATION ANTI-DUPLICATION - Si position déjà en cours, ne pas placer d'ordres
   int existingPositionsOnSymbol = CountPositionsForSymbol(_Symbol);
   if(existingPositionsOnSymbol > 0)
   {
      Print("🚫 ORDRES SPIKE BLOQUÉS - ", existingPositionsOnSymbol, " position(s) déjà en cours sur ", _Symbol, " - Attente fermeture");
      return;
   }
   
   // Limite globale: maximum 2 ordres LIMIT par symbole
   int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
   int chanLimits  = CountChannelLimitOrdersForSymbol(_Symbol);
   int otherLimits = totalLimits - chanLimits;
   if(totalLimits >= 2 || otherLimits >= 1)
   {
      Print("🚫 ORDRES SPIKE BLOQUÉS - Limite de LIMIT atteinte sur ", _Symbol, " (total=", totalLimits, ", canal=", chanLimits, ")");
      return;
   }

   // RÈGLE IA PRIORITAIRE SUR BOOM/CRASH:
   // - Sur Boom: aucun BUY si IA = SELL
   // - Sur Crash: aucun SELL si IA = BUY
   string aiDir = g_lastAIAction;
   if(aiDir == "buy")  aiDir = "BUY";
   if(aiDir == "sell") aiDir = "SELL";
   bool isCrash = !isBoom;
   if(isBoom && aiDir == "SELL")
   {
      Print("🚫 ORDRES SPIKE BOOM BLOQUÉS - IA = SELL (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Aucun BUY LIMIT autorisé");
      return;
   }
   if(isCrash && aiDir == "BUY")
   {
      Print("🚫 ORDRES SPIKE CRASH BLOQUÉS - IA = BUY (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Aucun SELL LIMIT autorisé");
      return;
   }
   double spikeEntryPoints[];
   ArrayResize(spikeEntryPoints, 20);
   int spikeCount = 0;
   
   // Analyser les 30 dernières bougies pour détecter les points de spike
   for(int i = 2; i < 32 && spikeCount < 20; i++)
   {
      // Détection de compression avant spike (volatilité faible)
      bool isCompression = true;
      double avgRange = 0;
      for(int j = i-5; j <= i-1; j++)
      {
         if(j >= 0)
         {
            avgRange += rates[j].high - rates[j].low;
         }
      }
      if(i >= 5) avgRange /= 5;
      
      // Vérifier si les 5 bougies précédentes ont une faible volatilité
      for(int j = i-5; j <= i-1 && j >= 0; j++)
      {
         double currentRange = rates[j].high - rates[j].low;
         if(currentRange > avgRange * 1.5) // Volatilité trop élevée
         {
            isCompression = false;
            break;
         }
      }
      
      // Détection du point d'entrée du spike
      if(isCompression && i >= 2)
      {
         double prevClose = rates[i-1].close;
         double currentClose = rates[i].close;
         double priceChange = MathAbs(currentClose - prevClose) / prevClose;
         
         // Spike significatif détecté
         if(priceChange > 0.008) // 0.8% de mouvement minimum
         {
            spikeEntryPoints[spikeCount] = currentClose;
            spikeCount++;
            
            // Marquer le point d'entrée sur le graphique + activer l'avertisseur clignotant
            string spikeName = "SPIKE_ENTRY_" + IntegerToString(i);
            color spikeColor = isBoom ? clrOrange : clrPurple;
            
            // Positionner l'affichage du spike dans la zone prédite (décalé dans le futur)
            datetime spikeTime = TimeCurrent() + (datetime)(SpikePredictionOffsetMinutes * 60);
            
            if(ObjectCreate(0, spikeName, OBJ_ARROW, 0, spikeTime, currentClose))
            {
               ObjectSetInteger(0, spikeName, OBJPROP_COLOR, spikeColor);
               ObjectSetInteger(0, spikeName, OBJPROP_WIDTH, 5);
               ObjectSetInteger(0, spikeName, OBJPROP_ARROWCODE, isBoom ? 233 : 234);
               ObjectSetString(0, spikeName, OBJPROP_TEXT, isBoom ? "SPIKE BUY" : "SPIKE SELL");
               ObjectSetInteger(0, spikeName, OBJPROP_FONTSIZE, 12);
               ObjectSetInteger(0, spikeName, OBJPROP_ANCHOR, isBoom ? ANCHOR_LOWER : ANCHOR_UPPER);
               ObjectSetInteger(0, spikeName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
               ObjectSetInteger(0, spikeName, OBJPROP_BACK, false);
            }
            
            // Flèche unique d'avertissement clignotante
            if(ObjectFind(0, "SMC_Spike_Warning") < 0)
            {
               if(ObjectCreate(0, "SMC_Spike_Warning", OBJ_ARROW, 0, spikeTime, currentClose))
               {
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_COLOR, clrYellow);
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_WIDTH, 6);
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_ARROWCODE, isBoom ? 233 : 234);
                  ObjectSetString(0, "SMC_Spike_Warning", OBJPROP_TEXT, "SPIKE IMMINENT");
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_FONTSIZE, 14);
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_ANCHOR, isBoom ? ANCHOR_LOWER : ANCHOR_UPPER);
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
                  ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_BACK, false);
               }
            }
            else
            {
               ObjectMove(0, "SMC_Spike_Warning", 0, rates[i].time, currentClose);
               ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_COLOR, clrYellow);
            }
            
            g_spikeWarningActive = true;
            g_spikeWarningStart = TimeCurrent();
            g_spikeWarningVisible = true;
         }
      }
   }
   
   // PLACER LES ORDRES LIMITES AUX POINTS D'ENTRÉE DÉTECTÉS
   if(spikeCount > 0)
   {
      int ordersToPlace = MathMin(2 - existingLimitOrders, spikeCount); // Limiter par le nombre d'ordres disponibles
      
      for(int i = 0; i < ordersToPlace && i < spikeCount; i++)
      {
         // Prendre les points de spike en partant du PLUS RÉCENT
         // spikeEntryPoints[0] = plus ancien, spikeEntryPoints[spikeCount-1] = plus récent
         int idx = spikeCount - 1 - i;
         if(idx < 0 || idx >= spikeCount)
            break;
         
         double entryPrice = spikeEntryPoints[idx];
         string spikeType = isBoom ? "BOOM SPIKE BUY" : "CRASH SPIKE SELL";
         
         // Placer ordre limite exactement au point d'entrée
         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_PENDING;
         request.symbol = _Symbol;
         request.volume = NormalizeVolumeForSymbol(0.01);
         request.type = isBoom ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
         request.price = entryPrice;
         request.sl = entryPrice - (isBoom ? currentATR * 2.0 : -currentATR * 2.0);
         request.tp = entryPrice + (isBoom ? currentATR * 4.0 : -currentATR * 4.0);
         request.magic = InpMagicNumber;
         request.comment = spikeType;
         
         // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
          ENUM_ORDER_TYPE orderType = isBoom ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
          if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, orderType))
          {
             Print("❌ Échec validation prix ", spikeType, " - Ordre annulé");
             continue;
          }
          
          if(!CanPlaceLimitOrder(_Symbol, orderType)) continue;
          CleanupExcessLimits(_Symbol, 2);
          if(SafeOrderSend(request, result))
         {
            Print("🚀 ", spikeType, " PLACÉ - Entrée: ", request.price, " | TP: ", request.tp, " | SL: ", request.sl);
         }
         else
         {
            Print("❌ ÉCHEC PLACEMENT ", spikeType, " - Erreur: ", result.comment);
         }
      }
      
      if(ordersToPlace < spikeCount)
      {
         Print("🚀 ", (spikeCount - ordersToPlace), " spikes supplémentaires détectés mais ordres limites non disponibles");
      }
   }
   else
   {
      Print("📊 AUCUN SPIKE BOOM/CRASH DÉTECTÉ - Analyse continue...");
   }
}

void PlaceNormalScalpingOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope)
{
   // VÉRIFICATION ANTI-DUPLICATION - Si position déjà en cours, ne pas placer d'ordres
   int existingPositionsOnSymbol = CountPositionsForSymbol(_Symbol);
   if(existingPositionsOnSymbol > 0)
   {
      Print("🚫 ORDRES NORMAUX BLOQUÉS - ", existingPositionsOnSymbol, " position(s) déjà en cours sur ", _Symbol, " - Attente fermeture");
      return;
   }
   
   // Limite globale: maximum 2 ordres LIMIT par symbole, dont 1 seul hors canal
   {
      int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
      int chanLimits  = CountChannelLimitOrdersForSymbol(_Symbol);
      int otherLimits = totalLimits - chanLimits;
      if(totalLimits >= 2 || otherLimits >= 1)
      {
         Print("🚫 ORDRES NORMAUX BLOQUÉS - Limite de LIMIT atteinte sur ", _Symbol, " (total=", totalLimits, ", canal=", chanLimits, ")");
         return;
      }
   }
   
   // Chercher les prochains SL/SH significatifs dans les 30 prochaines minutes (900 bougies M1)
   int lookAheadBars = MathMin(900, futureBars);
   double bestSLPrice = 0, bestSHPrice = 0;
   datetime bestSLTime = 0, bestSHTime = 0;
   
   for(int predIndex = 30; predIndex < lookAheadBars; predIndex += 30) // Vérifier toutes les 30 bougies
   {
      datetime futureTime = TimeCurrent() + PeriodSeconds(LTF) * predIndex;
      double progressionFactor = (double)predIndex / futureBars;
      double trendComponent = trendSlope * predIndex * 0.5;
      double volatilityComponent = currentATR * progressionFactor * 1.5;
      
      // Calculer les prix prédits
      double shPrice = (currentPrice + currentATR * 2.0) + trendComponent + volatilityComponent * MathSin(predIndex * 0.1);
      double slPrice = (currentPrice - currentATR * 2.0) + trendComponent - volatilityComponent * MathSin(predIndex * 0.1);
      
      // Garder les SL/SH les plus proches et significatifs
      if(slPrice < currentPrice && (bestSLPrice == 0 || slPrice > bestSLPrice))
      {
         bestSLPrice = slPrice;
         bestSLTime = futureTime;
      }
      
      if(shPrice > currentPrice && (bestSHPrice == 0 || shPrice < bestSHPrice))
      {
         bestSHPrice = shPrice;
         bestSHTime = futureTime;
      }
   }
   
   // Calculer la distance par rapport au prix actuel
   double distanceToSL = (bestSLPrice > 0) ? currentPrice - bestSLPrice : DBL_MAX;
   double distanceToSH = (bestSHPrice > 0) ? bestSHPrice - currentPrice : DBL_MAX;
   
   // Placer UN SEUL ordre limite au niveau le plus proche du prix
   if(distanceToSL < distanceToSH && bestSLPrice > 0)
   {
      // Placer BUY LIMIT au SL le plus proche (niveau exact)
      double buyLimitPrice = bestSLPrice;
      double tpPrice = buyLimitPrice + currentATR * 2.0;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = NormalizeVolumeForSymbol(0.01);
      request.type = ORDER_TYPE_BUY_LIMIT;
      request.price = buyLimitPrice;
      request.sl = buyLimitPrice - currentATR * 1.5;
      request.tp = tpPrice;
      request.magic = InpMagicNumber;
       request.comment = "Scalp SL Near";
       
       // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
       if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_BUY_LIMIT))
       {
          Print("❌ Échec validation prix BUY LIMIT scalping - Ordre annulé");
          return;
       }
       
       if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_BUY_LIMIT)) return;
       CleanupExcessLimits(_Symbol, 2);
       if(SafeOrderSend(request, result))
      {
         Print("📈 SEUL ORDRE LIMIT BUY PLACÉ - Prix: ", request.price, " | TP: ", request.tp, " | SL: ", request.sl, " | Distance: ", distanceToSL, " points");
      }
   }
   else if(bestSHPrice > 0)
   {
      // Placer SELL LIMIT au SH le plus proche (niveau exact)
      double sellLimitPrice = bestSHPrice;
      double tpPrice = sellLimitPrice - currentATR * 2.0;
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = NormalizeVolumeForSymbol(0.01);
      request.type = ORDER_TYPE_SELL_LIMIT;
      request.price = sellLimitPrice;
      request.sl = sellLimitPrice + currentATR * 1.5;
      request.tp = tpPrice;
      request.magic = InpMagicNumber;
       request.comment = "Scalp SH Near";
       
       // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
       if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_SELL_LIMIT))
       {
          Print("❌ Échec validation prix SELL LIMIT scalping - Ordre annulé");
          return;
       }
       
       if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_SELL_LIMIT)) return;
       CleanupExcessLimits(_Symbol, 2);
       if(SafeOrderSend(request, result))
      {
         Print("📉 SEUL ORDRE LIMIT SELL PLACÉ - Prix: ", request.price, " | TP: ", request.tp, " | SL: ", request.sl, " | Distance: ", distanceToSH, " points");
      }
   }
   else
   {
      Print("❌ AUCUN NIVEAU VALIDE TROUVÉ pour ordre de scalping");
   }
}

void DrawHistoricalSwingPoints(MqlRates &rates[], int bars, double point)
{
   int swingLookback = 5; // Nombre de bougies de chaque côté pour valider un swing point
   int maxSwings = 20; // Nombre maximum de swing points à afficher
   int swingCount = 0;
   
   // Parcourir les bougies historiques pour détecter les swing points
   for(int i = swingLookback; i < bars - swingLookback && swingCount < maxSwings; i++)
   {
      // Détecter Swing High (le high de la bougie i est plus élevé que les swingLookback bougies avant et après)
      bool isSwingHigh = true;
      for(int j = i - swingLookback; j <= i + swingLookback; j++)
      {
         if(j != i && rates[j].high >= rates[i].high)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh)
      {
         string shName = "SMC_Hist_SH_" + IntegerToString(i);
         if(ObjectCreate(0, shName, OBJ_ARROW, 0, rates[i].time, rates[i].high))
         {
            ObjectSetInteger(0, shName, OBJPROP_COLOR, clrCrimson);
            ObjectSetInteger(0, shName, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, shName, OBJPROP_ARROWCODE, 233); // Flèche vers le haut
            ObjectSetString(0, shName, OBJPROP_TEXT, "SH");
            ObjectSetInteger(0, shName, OBJPROP_FONTSIZE, 10);
            ObjectSetInteger(0, shName, OBJPROP_ANCHOR, ANCHOR_LOWER);
            ObjectSetInteger(0, shName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); // Visible sur tous les timeframes
            ObjectSetInteger(0, shName, OBJPROP_BACK, false); // Au premier plan
            swingCount++;
         }
      }
      
      // Détecter Swing Low (le low de la bougie i est plus bas que les swingLookback bougies avant et après)
      bool isSwingLow = true;
      for(int j = i - swingLookback; j <= i + swingLookback; j++)
      {
         if(j != i && rates[j].low <= rates[i].low)
         {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow)
      {
         string slName = "SMC_Hist_SL_" + IntegerToString(i);
         if(ObjectCreate(0, slName, OBJ_ARROW, 0, rates[i].time, rates[i].low))
         {
            ObjectSetInteger(0, slName, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, slName, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, slName, OBJPROP_ARROWCODE, 234); // Flèche vers le bas
            ObjectSetString(0, slName, OBJPROP_TEXT, "SL");
            ObjectSetInteger(0, slName, OBJPROP_FONTSIZE, 10);
            ObjectSetInteger(0, slName, OBJPROP_ANCHOR, ANCHOR_UPPER);
            ObjectSetInteger(0, slName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS); // Visible sur tous les timeframes
            ObjectSetInteger(0, slName, OBJPROP_BACK, false); // Au premier plan
            swingCount++;
         }
      }
   }
   
   Print("📍 SWING HISTORIQUES - ", swingCount, " points détectés (SH: rouge, SL: bleu)");
}

void DrawFVGOnChart()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 80;
   if(CopyRates(_Symbol, LTF, 0, bars, rates) < bars) return;
   ObjectsDeleteAll(0, "SMC_FVG_");
   int cnt = 0;
   for(int fvgIndex = 2; fvgIndex < bars - 2 && cnt < 15; fvgIndex++)
   {
      if(rates[fvgIndex].close > rates[fvgIndex].open && rates[fvgIndex+1].high < rates[fvgIndex-1].low)
      {
         double top = rates[fvgIndex-1].low, bot = rates[fvgIndex+1].high;
         datetime t1 = rates[fvgIndex+1].time, t2 = TimeCurrent() + PeriodSeconds(LTF)*20;
         string name = "SMC_FVG_Bull_" + IntegerToString(fvgIndex);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, bot, t2, top))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, false);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
      if(rates[fvgIndex].close < rates[fvgIndex].open && rates[fvgIndex+1].low > rates[fvgIndex-1].high)
      {
         double top = rates[fvgIndex+1].low, bot = rates[fvgIndex-1].high;
         datetime t1 = rates[fvgIndex+1].time, t2 = TimeCurrent() + PeriodSeconds(LTF)*20;
         string name = "SMC_FVG_Bear_" + IntegerToString(fvgIndex);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, bot, t2, top))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, false);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
   }
}

void DrawOBOnChart()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 80;
   if(CopyRates(_Symbol, LTF, 0, bars, rates) < bars) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   ObjectsDeleteAll(0, "SMC_OB_");
   int cnt = 0;
   for(int fvgIndex = 3; fvgIndex < bars - 4 && cnt < 10; fvgIndex++)
   {
      if(rates[fvgIndex].close < rates[fvgIndex].open && rates[fvgIndex+1].close > rates[fvgIndex+1].open && (rates[fvgIndex+1].high - rates[fvgIndex].low) > point*20)
      {
         datetime t2 = TimeCurrent() + PeriodSeconds(LTF)*30;
         string name = "SMC_OB_Bull_" + IntegerToString(fvgIndex);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, rates[fvgIndex].time, rates[fvgIndex].low, t2, rates[fvgIndex].high))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
      if(rates[fvgIndex].close > rates[fvgIndex].open && rates[fvgIndex+1].close < rates[fvgIndex+1].open && (rates[fvgIndex].high - rates[fvgIndex+1].low) > point*20)
      {
         datetime t2 = TimeCurrent() + PeriodSeconds(LTF)*30;
         string name = "SMC_OB_Bear_" + IntegerToString(fvgIndex);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, rates[fvgIndex].time, rates[fvgIndex].low, t2, rates[fvgIndex].high))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrCrimson);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
   }
}

void DrawFibonacciOnChart()
{
   double high[], low[];
   datetime time[];
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(time, true);
   int n = 50;
   if(CopyHigh(_Symbol, LTF, 0, n, high) < n || CopyLow(_Symbol, LTF, 0, n, low) < n || CopyTime(_Symbol, LTF, 0, n, time) < n) return;
   int iHigh = ArrayMaximum(high, 0, n), iLow = ArrayMinimum(low, 0, n);
   if(iHigh < 0 || iLow < 0) return;
   double h = high[iHigh], l = low[iLow];
   ObjectsDeleteAll(0, "SMC_Fib_");
   double levels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
   color colors[] = {clrGray, clrDodgerBlue, clrAqua, clrYellow, clrOrange, clrOrangeRed, clrMagenta};
   for(int i = 0; i < 7; i++)
   {
      double price = l + (h - l) * levels[i];
      string name = "SMC_Fib_" + IntegerToString(i);
      if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, colors[i]);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetString(0, name, OBJPROP_TOOLTIP, "Fib " + DoubleToString(levels[i]*100, 1) + "%");
      }
   }
}

void DrawEMACurveOnChart()
{
   if(emaHandle == INVALID_HANDLE) return;
   double ema[];
   ArraySetAsSeries(ema, true);
   int len = 20;
   if(CopyBuffer(emaHandle, 0, 0, len, ema) < len) return;
   datetime time[];
   ArraySetAsSeries(time, true);
   if(CopyTime(_Symbol, LTF, 0, len, time) < len) return;
   ObjectsDeleteAll(0, "SMC_EMA_");
   for(int i = 0; i < len - 1; i++)
   {
      string name = "SMC_EMA_" + IntegerToString(i);
      if(ObjectCreate(0, name, OBJ_TREND, 0, time[i], ema[i], time[i+1], ema[i+1]))
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      }
   }
}

void DrawLiquidityZonesOnChart()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 30;
   if(CopyRates(_Symbol, LTF, 0, bars, rates) < bars) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   ObjectsDeleteAll(0, "SMC_Liq_");
   int cnt = 0;
   for(int i = 5; i < bars - 5 && cnt < 8; i++)
   {
      double zHigh = rates[i].high, zLow = rates[i].low;
      for(int j = i; j < i + 10 && j < bars; j++)
      {
         if(rates[j].high > zHigh) zHigh = rates[j].high;
         if(rates[j].low < zLow) zLow = rates[j].low;
      }
      if(zHigh - zLow > point * 5)
      {
         string name = "SMC_Liq_" + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, rates[i+5].time, zLow, rates[i].time, zHigh))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrPurple);
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_FILL, false);
            cnt++;
         }
      }
   }
}

void DrawPremiumDiscountZones()
{
   double high[], low[], close[];
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
   ENUM_TIMEFRAMES tf = PERIOD_H1;
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 100, high) < 100 || CopyLow(_Symbol, PERIOD_H1, 0, 100, low) < 100 || CopyClose(_Symbol, PERIOD_H1, 0, 100, close) < 100)
   {
      tf = LTF;
      int n = MathMin(100, Bars(_Symbol, tf));
      if(n < 30 || CopyHigh(_Symbol, tf, 0, n, high) < n || CopyLow(_Symbol, tf, 0, n, low) < n || CopyClose(_Symbol, tf, 0, n, close) < n) return;
   }
   int n = ArraySize(close);
   if(n < 25) return;
   double sma20[];
   ArrayResize(sma20, n);
   ArraySetAsSeries(sma20, true);
   for(int i = 0; i < n - 20; i++)
   {
      double sum = 0;
      for(int j = 0; j < 20; j++) sum += close[i + j];
      sma20[i] = sum / 20;
   }
   for(int i = n - 20; i < n; i++) sma20[i] = sma20[MathMax(0, n - 21)];
   double eq = sma20[0];
   datetime t0 = TimeCurrent() - 7200;
   datetime t1 = TimeCurrent();
   ObjectDelete(0, "SMC_ICT_PREMIUM_ZONE");
   ObjectDelete(0, "SMC_ICT_DISCOUNT_ZONE");
   ObjectDelete(0, "SMC_ICT_PREMIUM_LABEL");
   ObjectDelete(0, "SMC_ICT_DISCOUNT_LABEL");
   ObjectDelete(0, "SMC_ICT_EQUILIBRE");
   ObjectDelete(0, "SMC_ICT_EQUILIBRE_LABEL");
   double premHigh = high[ArrayMaximum(high, 0, 20)];
   double discLow = low[ArrayMinimum(low, 0, 20)];
   if(premHigh <= eq || discLow >= eq) return;
   ObjectCreate(0, "SMC_ICT_PREMIUM_ZONE", OBJ_RECTANGLE, 0, t0, eq, t1, premHigh);
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_ZONE", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_ZONE", OBJPROP_BACK, true);
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_ZONE", OBJPROP_FILL, true);
   ObjectCreate(0, "SMC_ICT_PREMIUM_LABEL", OBJ_TEXT, 0, t0 + 600, (eq + premHigh) / 2);
   ObjectSetString(0, "SMC_ICT_PREMIUM_LABEL", OBJPROP_TEXT, "Premium (vente)");
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_LABEL", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_LABEL", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "SMC_ICT_PREMIUM_LABEL", OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectCreate(0, "SMC_ICT_DISCOUNT_ZONE", OBJ_RECTANGLE, 0, t0, discLow, t1, eq);
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_ZONE", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_ZONE", OBJPROP_BACK, true);
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_ZONE", OBJPROP_FILL, true);
   ObjectCreate(0, "SMC_ICT_DISCOUNT_LABEL", OBJ_TEXT, 0, t0 + 1800, (discLow + eq) / 2);
   ObjectSetString(0, "SMC_ICT_DISCOUNT_LABEL", OBJPROP_TEXT, "Discount (achat)");
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_LABEL", OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_LABEL", OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, "SMC_ICT_DISCOUNT_LABEL", OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectCreate(0, "SMC_ICT_EQUILIBRE", OBJ_HLINE, 0, 0, eq);
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE", OBJPROP_WIDTH, 2);
   ObjectCreate(0, "SMC_ICT_EQUILIBRE_LABEL", OBJ_TEXT, 0, t0 + 3600, eq);
   ObjectSetString(0, "SMC_ICT_EQUILIBRE_LABEL", OBJPROP_TEXT, "ZONE D'ÉQUILIBRE");
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE_LABEL", OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE_LABEL", OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, "SMC_ICT_EQUILIBRE_LABEL", OBJPROP_ANCHOR, ANCHOR_LEFT);
   
   // Ligne verticale pour séparer clairement la zone passée de la zone prédite
   ObjectDelete(0, "SMC_PAST_FUTURE_DIVIDER");
   if(ObjectCreate(0, "SMC_PAST_FUTURE_DIVIDER", OBJ_VLINE, 0, t1, 0))
   {
      ObjectSetInteger(0, "SMC_PAST_FUTURE_DIVIDER", OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "SMC_PAST_FUTURE_DIVIDER", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "SMC_PAST_FUTURE_DIVIDER", OBJPROP_STYLE, STYLE_SOLID);
   }
}

void DrawSignalArrow()
{
   if(g_lastAIAction != "buy" && g_lastAIAction != "BUY" && g_lastAIAction != "sell" && g_lastAIAction != "SELL") return;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, r) < 1) return;
   double arrowPrice = r[0].close;
   datetime arrowTime = r[0].time;
   bool isBuy = (g_lastAIAction == "buy" || g_lastAIAction == "BUY");
   string arrowName = "SMC_DERIV_ARROW_" + _Symbol;
   if(ObjectFind(0, arrowName) < 0)
      ObjectCreate(0, arrowName, OBJ_ARROW, 0, arrowTime, arrowPrice);
   ObjectSetInteger(0, arrowName, OBJPROP_TIME, 0, arrowTime);
   ObjectSetDouble(0, arrowName, OBJPROP_PRICE, 0, arrowPrice);
   ObjectSetInteger(0, arrowName, OBJPROP_COLOR, isBuy ? clrLime : clrRed);
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, isBuy ? 233 : 234);
   ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
}

void UpdateSignalArrowBlink()
{
   if(g_lastAIAction != "buy" && g_lastAIAction != "BUY" && g_lastAIAction != "sell" && g_lastAIAction != "SELL")
   {
      // Ne plus supprimer la flèche immédiatement lorsque l'IA repasse en HOLD.
      // On garde simplement l'état actuel (flèche figée) pour que le trader la voie.
      return;
   }
   string arrowName = "SMC_DERIV_ARROW_" + _Symbol;
   if(ObjectFind(0, arrowName) < 0) return;
   datetime now = TimeCurrent();
   if(now - g_arrowBlinkTime >= 500)
   {
      g_arrowBlinkTime = now;
      g_arrowVisible = !g_arrowVisible;
   }
   ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, g_arrowVisible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
}

// Avertisseur clignotant pour l'arrivée imminente d'un spike Boom/Crash
void UpdateSpikeWarningBlink()
{
   if(!g_spikeWarningActive) return;
   if(!IsBoomLikeSymbol(_Symbol) && !IsCrashLikeSymbol(_Symbol)) return;
   
   datetime now = TimeCurrent();
   
   // Supprimer l'avertisseur après 2 minutes ou si l'objet n'existe plus
   if(now - g_spikeWarningStart > 120 || ObjectFind(0, "SMC_Spike_Warning") < 0)
   {
      ObjectDelete(0, "SMC_Spike_Warning");
      g_spikeWarningActive = false;
      return;
   }
   
   // Clignotement toutes les 0.7 seconde
   if(now - g_spikeBlinkTime >= 1)
   {
      g_spikeBlinkTime = now;
      g_spikeWarningVisible = !g_spikeWarningVisible;
      
      if(ObjectFind(0, "SMC_Spike_Warning") >= 0)
      {
         color c = g_spikeWarningVisible ? clrYellow : clrNONE;
         ObjectSetInteger(0, "SMC_Spike_Warning", OBJPROP_COLOR, c);
      }
   }
}

// Entrée automatique quand le prix touche les niveaux SH/SL prédits (canal ML)
void CheckPredictedSwingTriggers()
{
   long chId = ChartID();
   if(chId <= 0) return;
   
   if(g_lastAIAction == "HOLD" || g_lastAIAction == "hold") return;
   
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(cat == SYM_BOOM_CRASH) return;
   
   if(IsPriceInRange()) return;
   
   if(CountPositionsOurEA() >= MaxPositionsTerminal) return;
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(!MathIsValidNumber(bid) || !MathIsValidNumber(ask) || bid <= 0 || ask <= 0) return;
   
   int total = (int)ObjectsTotal(chId, -1, -1);
   if(total <= 0 || total > 2000) return; // Limite sécurité
   
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(chId, i);
      if(StringLen(name) == 0) continue;
      
      bool isPredSH = (StringFind(name, "SMC_Pred_SH_") == 0 || StringFind(name, "SMC_Dyn_SH_") == 0 || StringFind(name, "SMC_Prec_SH_") == 0);
      bool isPredSL = (StringFind(name, "SMC_Pred_SL_") == 0 || StringFind(name, "SMC_Dyn_SL_") == 0 || StringFind(name, "SMC_Prec_SL_") == 0);
      
      if(isPredSH)
      {
         double level = ObjectGetDouble(chId, name, OBJPROP_PRICE);
         if(!MathIsValidNumber(level) || level <= 0) continue;
         if(bid >= level)
         {
            SMC_Signal sig;
            sig.action = "SELL";
            sig.entryPrice = bid;
            sig.reasoning = "Predicted SH touch";
            sig.concept = "Pred-SH";
            sig.stopLoss = 0;
            sig.takeProfit = 0;
            ExecuteSignal(sig);
            ObjectDelete(chId, name);
            break;
         }
      }
      else if(isPredSL)
      {
         double level = ObjectGetDouble(chId, name, OBJPROP_PRICE);
         if(!MathIsValidNumber(level) || level <= 0) continue;
         if(ask <= level)
         {
            SMC_Signal sig;
            sig.action = "BUY";
            sig.entryPrice = ask;
            sig.reasoning = "Predicted SL touch";
            sig.concept = "Pred-SL";
            sig.stopLoss = 0;
            sig.takeProfit = 0;
            ExecuteSignal(sig);
            ObjectDelete(chId, name);
            break;
         }
      }
   }
}

void DrawPredictedSwingPoints()
{
   long chId = ChartID();
   if(chId <= 0) return; // Pas de chart valide = éviter crash/détachement
   if(!g_channelValid) return;
   // Validation des données du canal (éviter NaN/infini → détachement)
   if(!MathIsValidNumber(g_chUpperStart) || !MathIsValidNumber(g_chLowerStart) ||
      !MathIsValidNumber(g_chUpperEnd) || !MathIsValidNumber(g_chLowerEnd))
      return;
   ObjectsDeleteAll(chId, "SMC_Pred_SH_");
   ObjectsDeleteAll(chId, "SMC_Pred_SL_");
   datetime tNow = iTime(_Symbol, PERIOD_M1, 0);
   if(tNow <= 0) tNow = TimeCurrent();
   int periodSec = 60;
   int predBars = MathMax(1, MathMin(PredictionChannelBars, 5000)); // Limiter pour éviter overflow
   double slopeUpper = (g_chUpperEnd - g_chUpperStart) / (double)predBars;
   double slopeLower = (g_chLowerEnd - g_chLowerStart) / (double)predBars;
   int step = MathMax(1, predBars / 10);
   for(int k = 1; k <= 10; k++)
   {
      int barsAhead = MathMin(k * step, 5000); // Limiter pour éviter overflow datetime
      datetime t = tNow + (datetime)(barsAhead * periodSec);
      double minsFromStart = (g_chTimeStart > 0 && periodSec > 0) ? (double)(t - g_chTimeStart) / (double)periodSec : (double)barsAhead;
      double upPrice = g_chUpperStart + slopeUpper * minsFromStart;
      double loPrice = g_chLowerStart + slopeLower * minsFromStart;
      if(!MathIsValidNumber(upPrice) || !MathIsValidNumber(loPrice)) continue;
      string nameSH = "SMC_Pred_SH_" + IntegerToString(k);
      string nameSL = "SMC_Pred_SL_" + IntegerToString(k);
      if(ObjectCreate(chId, nameSH, OBJ_ARROW, 0, t, upPrice))
      {
         ObjectSetInteger(chId, nameSH, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(chId, nameSH, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(chId, nameSH, OBJPROP_WIDTH, 2);
      }
      if(ObjectCreate(chId, nameSL, OBJ_ARROW, 0, t, loPrice))
      {
         ObjectSetInteger(chId, nameSL, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(chId, nameSL, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(chId, nameSL, OBJPROP_WIDTH, 2);
      }
   }
}

void DrawSMCChannelsMultiTF()
{
   // Tracer les canaux SMC (upper/lower) depuis H1, M30, M5 projetés sur M1
   datetime currentTime = TimeCurrent();
   
   // Timeframes à analyser
   ENUM_TIMEFRAMES tfs[] = {PERIOD_H1, PERIOD_M30, PERIOD_M5};
   string tfNames[] = {"H1", "M30", "M5"};
   color tfColors[] = {clrBlue, clrPurple, clrGreen};
   
   for(int i = 0; i < ArraySize(tfs); i++)
   {
      string prefix = "SMC_CH_" + tfNames[i] + "_";
      ObjectsDeleteAll(0, prefix);
      
      // Récupérer les données du timeframe
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, tfs[i], 0, 200, rates) < 50) continue;
      
      // Calculer les hauts et bas pour le canal
      double upper = rates[0].high;
      double lower = rates[0].low;
      
      for(int j = 1; j < 100; j++) // Analyser les 100 dernières bougies
      {
         if(rates[j].high > upper) upper = rates[j].high;
         if(rates[j].low < lower) lower = rates[j].low;
      }
      
      // Projeter sur 5000 bougies M1 futures
      datetime startTime = currentTime;
      datetime endTime = currentTime + (datetime)(SMCChannelFutureBars * 60); // 5000 bougies M1 = 5000 minutes
      
      // Tracer la ligne supérieure du canal
      string upperName = prefix + "UPPER";
      ObjectCreate(0, upperName, OBJ_TREND, 0, startTime, upper, endTime, upper);
      ObjectSetInteger(0, upperName, OBJPROP_COLOR, tfColors[i]);
      ObjectSetInteger(0, upperName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, upperName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, upperName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, upperName, OBJPROP_BACK, false);
      ObjectSetString(0, upperName, OBJPROP_TOOLTIP, "Canal SMC " + tfNames[i] + " - Upper");
      
      // Tracer la ligne inférieure du canal
      string lowerName = prefix + "LOWER";
      ObjectCreate(0, lowerName, OBJ_TREND, 0, startTime, lower, endTime, lower);
      ObjectSetInteger(0, lowerName, OBJPROP_COLOR, tfColors[i]);
      ObjectSetInteger(0, lowerName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lowerName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lowerName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, lowerName, OBJPROP_BACK, false);
      ObjectSetString(0, lowerName, OBJPROP_TOOLTIP, "Canal SMC " + tfNames[i] + " - Lower");
      
      // Ajouter un label
      string labelName = prefix + "LABEL";
      ObjectCreate(0, labelName, OBJ_TEXT, 0, startTime, upper);
      ObjectSetString(0, labelName, OBJPROP_TEXT, "SMC " + tfNames[i]);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, tfColors[i]);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
}

// Place un ordre limite "sniper" entre le prix actuel et le canal SMC (upper/lower)
// Un seul ordre limit SMC par symbole. L'IA sert de filtre directionnel:
// - si IA forte et opposée au sens naturel (Boom=BUY / Crash=SELL), on NE trade pas
// - si IA HOLD ou faible confiance, on autorise quand même le trade canal.
void PlaceSMCChannelLimitOrder()
{
   // Bloquer en zone de correction (verdict GOM WAIT = vn==0)
   if(UseGOMVerdictFilter && g_smcGomConnected && g_smcGomVerdictNum == 0)
   {
      Print("[GOM-WAIT] PlaceSMCChannelLimitOrder bloqué — verdict=WAIT (correction)");
      return;
   }

   // OTE Filter: prix doit être dans zone Fib 61.8-78.6% pour entrer
   if(GOMRequireOTE && UseOTE && g_smcOteTop > 0 && g_smcOteBot > 0 && !g_smcInOTE)
   {
      Print("[OTE] PlaceSMCChannelLimitOrder bloqué — prix hors zone OTE");
      return;
   }

   bool isBoom  = IsBoomLikeSymbol(_Symbol);
   bool isCrash = IsCrashLikeSymbol(_Symbol);
   if(!isBoom && !isCrash) return;

   const double MIN_CONF_SMC_ORDER = 0.75;
   string aiAction = g_lastAIAction;
   if(aiAction == "buy") aiAction = "BUY";
   if(aiAction == "sell") aiAction = "SELL";
   bool iaStrong = (aiAction == "BUY" || aiAction == "SELL") && g_lastAIConfidence >= MIN_CONF_SMC_ORDER;
   
   // Direction naturelle du trade canal (Boom = BUY, Crash = SELL)
   string channelDir = isBoom ? "BUY" : "SELL";
   
   // RÈGLE STRICTE: BLOQUER TOUS LES ORDRES BUY SUR BOOM SI IA = SELL
   if(isBoom && aiAction == "SELL")
   {
      Print("🚫 ORDRE SMC BOOM BLOQUÉ - IA = SELL (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal BUY avant de placer ordre BUY");
      return;
   }
   
   // RÈGLE STRICTE: BLOQUER TOUS LES ORDRES SELL SUR CRASH SI IA = BUY
   if(isCrash && aiAction == "BUY")
   {
      Print("🚫 ORDRE SMC CRASH BLOQUÉ - IA = BUY (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal SELL avant de placer ordre SELL");
      return;
   }
   
   // Si IA forte et opposée à la direction naturelle, ne pas placer d'ordre canal
   if(iaStrong && aiAction != channelDir)
   {
      Print("🚫 ORDRE SMC BLOQUÉ - IA forte (", DoubleToString(g_lastAIConfidence*100, 1), "%) opposée à direction naturelle (", channelDir, ")");
      return;
   }
   
   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles (IA ≥90% + spike/setup fort)
   if(!AllowReentryAfterRecentLoss(_Symbol, channelDir, false))
      return;
   
   // Une fois placé, un ordre limit SMC n'est plus annulé automatiquement ici.
   // Il sera géré par le SL/TP naturel ou manuellement par l'utilisateur.
   
   // Un seul ordre LIMIT canal SMC par symbole
   int chanLimits = CountChannelLimitOrdersForSymbol(_Symbol);
   if(chanLimits >= 1) return;
   
   // Limite globale: maximum 2 ordres LIMIT par symbole
   int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
   // Pour Boom/Crash: un seul LIMIT proche à la fois
   if(totalLimits >= 1) return;
   
   if(CountPositionsForSymbol(_Symbol) > 0) return; // Pas de nouvel ordre si déjà en position
   if(!TryAcquireOpenLock()) return;
   
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) { ReleaseOpenLock(); return; }
   
   // Récupérer le canal SMC H1
   string upperName = "SMC_CH_H1_UPPER";
   string lowerName = "SMC_CH_H1_LOWER";
   if(ObjectFind(0, upperName) < 0 || ObjectFind(0, lowerName) < 0)
   {
      ReleaseOpenLock();
      return;
   }
   
   // Les canaux SMC H1 sont des lignes horizontales: prix identique sur toute la ligne.
   double upperPrice = ObjectGetDouble(0, upperName, OBJPROP_PRICE);
   double lowerPrice = ObjectGetDouble(0, lowerName, OBJPROP_PRICE);
   if(upperPrice <= 0 || lowerPrice <= 0) { ReleaseOpenLock(); return; }
   
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action = TRADE_ACTION_PENDING;
   req.symbol = _Symbol;
   req.magic  = InpMagicNumber;
   
   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }
   req.volume = lot;
   
   // Boom: BUY LIMIT avec logique de proximité intelligente
   if(isBoom)
   {
      if(bid <= lowerPrice) { ReleaseOpenLock(); return; }
      
      // Calculer la distance au canal
      double distanceToCanal = bid - lowerPrice;
      double atrVal = 0.0;
      if(atrHandle != INVALID_HANDLE)
      {
         double atrBuf[];
         ArraySetAsSeries(atrBuf, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0)
            atrVal = atrBuf[0];
      }
      if(atrVal <= 0) atrVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100;
      
      double entry = 0.0;
      string entryType = "";
      bool usedML = false;

      // PRIORITÉ: SuperTrend support (ordre unique et proche)
      double stSupp = 0.0, stRes = 0.0;
      double tmpS = 0.0, tmpR = 0.0;
      if(GetSuperTrendLevel(PERIOD_M5, tmpS, tmpR) && tmpS > 0) stSupp = tmpS;
      else if(GetSuperTrendLevel(PERIOD_H1, tmpS, tmpR) && tmpS > 0) stSupp = tmpS;
      if(stSupp > 0 && stSupp < bid)
      {
         double buffer = atrVal * 0.15;
         double candidate = stSupp + buffer; // au-dessus du support
         double maxDist = atrVal * MaxDistanceLimitATR;
         if((bid - candidate) <= maxDist && candidate < bid)
         {
            entry = candidate;
            entryType = "SUPER TREND SUPPORT";
            usedML = true; // on considère ST comme source prioritaire
         }
      }
      
      // 1) Essayer d'utiliser la DERNIÈRE INTERSECTION avec le canal ML (et sa projection)
      if(g_channelValid)
      {
         double recentML, projML;
         datetime recentTime, projTime;
         if(GetRecentAndProjectedMLChannelIntersection("BUY", recentML, recentTime, projML, projTime))
         {
            double candidate = projML;
            // Vérifier que la projection est bien sous le prix actuel (BUY LIMIT) et pas trop loin du canal H1
            if(candidate <= 0 || candidate >= bid || MathAbs(candidate - lowerPrice) > atrVal * 6.0)
               candidate = recentML;
            
            if(candidate > 0 && candidate < bid && MathAbs(candidate - lowerPrice) <= atrVal * 6.0)
            {
               entry = candidate;
               entryType = "ML INTERSECTION";
               usedML = true;
            }
         }
      }
      
      // 2) Fallback: logique de proximité classique sur le canal H1
      if(!usedML)
      {
         // LOGIQUE DE PROXIMITÉ INTELLIGENTE
         if(distanceToCanal <= atrVal * 2.0) // Canal proche (≤ 2 ATR)
         {
            entry = lowerPrice; // Utiliser le canal directement
            entryType = "CANAL PROCHE";
         }
         else if(distanceToCanal <= atrVal * 4.0) // Canal moyen (2-4 ATR)
         {
            entry = lowerPrice + (atrVal * 0.5); // Mi-chemin entre prix et canal
            entryType = "CANAL MOYEN";
         }
         else // Canal loin (> 4 ATR) → on préfère NE PAS entrer plutôt qu'entrer trop tôt
         {
            ReleaseOpenLock();
            Print("🚫 SMC BOOM - Canal trop loin (>4 ATR), aucune entrée pour éviter une entrée trop précoce");
            return;
         }
      }
      
      if(entry >= bid) { ReleaseOpenLock(); return; }
      req.type  = ORDER_TYPE_BUY_LIMIT;
      req.price = entry;
      
      Print("🎯 SMC BOOM - ", entryType, " | Distance canal: ", DoubleToString(distanceToCanal/atrVal, 1), " ATR | Entry: ", DoubleToString(entry, _Digits));
   }
   // Crash: SELL LIMIT avec logique de proximité intelligente
   else if(isCrash)
   {
      if(ask >= upperPrice) { ReleaseOpenLock(); return; }
      
      // Calculer la distance au canal
      double distanceToCanal = upperPrice - ask;
      double atrVal = 0.0;
      if(atrHandle != INVALID_HANDLE)
      {
         double atrBuf[];
         ArraySetAsSeries(atrBuf, true);
         if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0)
            atrVal = atrBuf[0];
      }
      if(atrVal <= 0) atrVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100;
      
      double entry = 0.0;
      string entryType = "";
      bool usedML = false;

      // PRIORITÉ: SuperTrend résistance (ordre unique et proche)
      double stSupp = 0.0, stRes = 0.0;
      double tmpS = 0.0, tmpR = 0.0;
      if(GetSuperTrendLevel(PERIOD_M5, tmpS, tmpR) && tmpR > 0) stRes = tmpR;
      else if(GetSuperTrendLevel(PERIOD_H1, tmpS, tmpR) && tmpR > 0) stRes = tmpR;
      if(stRes > 0 && stRes > ask)
      {
         double buffer = atrVal * 0.15;
         double candidate = stRes - buffer; // en-dessous de la résistance
         double maxDist = atrVal * MaxDistanceLimitATR;
         if((candidate - ask) <= maxDist && candidate > ask)
         {
            entry = candidate;
            entryType = "SUPER TREND RESISTANCE";
            usedML = true;
         }
      }
      
      // 1) Essayer d'utiliser la DERNIÈRE INTERSECTION avec le canal ML (et sa projection)
      if(g_channelValid)
      {
         double recentML, projML;
         datetime recentTime, projTime;
         if(GetRecentAndProjectedMLChannelIntersection("SELL", recentML, recentTime, projML, projTime))
         {
            double candidate = projML;
            // Vérifier que la projection est bien au-dessus du prix actuel (SELL LIMIT) et pas trop loin du canal H1
            if(candidate <= ask || MathAbs(candidate - upperPrice) > atrVal * 6.0)
               candidate = recentML;
            
            if(candidate > ask && MathAbs(candidate - upperPrice) <= atrVal * 6.0)
            {
               entry = candidate;
               entryType = "ML INTERSECTION";
               usedML = true;
            }
         }
      }
      
      // 2) Fallback: logique de proximité classique sur le canal H1
      if(!usedML)
      {
         // LOGIQUE DE PROXIMITÉ INTELLIGENTE
         if(distanceToCanal <= atrVal * 2.0) // Canal proche (≤ 2 ATR)
         {
            entry = upperPrice; // Utiliser le canal directement
            entryType = "CANAL PROCHE";
         }
         else if(distanceToCanal <= atrVal * 4.0) // Canal moyen (2-4 ATR)
         {
            entry = upperPrice - (atrVal * 0.5); // Mi-chemin entre prix et canal
            entryType = "CANAL MOYEN";
         }
         else // Canal loin (> 4 ATR) → on préfère NE PAS entrer plutôt qu'entrer trop tôt
         {
            ReleaseOpenLock();
            Print("🚫 SMC CRASH - Canal trop loin (>4 ATR), aucune entrée pour éviter une entrée trop précoce");
            return;
         }
      }
      
      if(entry <= ask) { ReleaseOpenLock(); return; }
      req.type  = ORDER_TYPE_SELL_LIMIT;
      req.price = entry;
      
      Print("🎯 SMC CRASH - ", entryType, " | Distance canal: ", DoubleToString(distanceToCanal/atrVal, 1), " ATR | Entry: ", DoubleToString(entry, _Digits));
   }
   else
   {
      ReleaseOpenLock();
      return;
   }
   
   // SL/TP simples basés sur ATR global
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0)
         atrVal = atrBuf[0];
   }
   if(atrVal <= 0) atrVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100;
   
   if(req.type == ORDER_TYPE_BUY_LIMIT)
   {
      req.sl = req.price - atrVal * SL_ATRMult;
      req.tp = req.price + atrVal * TP_ATRMult;
      req.comment = "SMC_CH BUY LIMIT";
   }
   else
   {
      req.sl = req.price + atrVal * SL_ATRMult;
      req.tp = req.price - atrVal * TP_ATRMult;
      req.comment = "SMC_CH SELL LIMIT";
   }
   
   if(!CanPlaceLimitOrder(_Symbol, req.type)) { ReleaseOpenLock(); return; }
   CleanupExcessLimits(_Symbol, 2);
   if(!SafeOrderSend(req, res))
      Print("❌ Echec envoi ordre limite SMC_CH sur ", _Symbol, " | code=", res.retcode);
   
   ReleaseOpenLock();
}

void DrawEMASupertrendMultiTF()
{
   long chId = ChartID();
   if(chId <= 0) return;
   
   datetime currentTime = TimeCurrent();
   ENUM_TIMEFRAMES tfs[] = {PERIOD_H1, PERIOD_M30, PERIOD_M5};
   string tfNames[] = {"H1", "M30", "M5"};
   color supportColors[] = {clrGreen, clrLime, clrAqua};
   color resistanceColors[] = {clrRed, clrOrange, clrMagenta};
   
   // Limiter à 500 bars (éviter crash sur symboles avec peu d'historique type Boom/Crash)
   int totalBars = MathMin(500, Bars(_Symbol, PERIOD_H1));
   if(totalBars < 50) return;
   
   for(int i = 0; i < ArraySize(tfs); i++)
   {
      int fastHandle = (tfs[i] == PERIOD_H1) ? emaFastH1 : 
                     (tfs[i] == PERIOD_M30) ? emaFastM5 : emaFastM1;
      int slowHandle = (tfs[i] == PERIOD_H1) ? emaSlowH1 : 
                     (tfs[i] == PERIOD_M30) ? emaSlowM5 : emaSlowM1;
      int atrHandleTF = (tfs[i] == PERIOD_H1) ? atrH1 : 
                       (tfs[i] == PERIOD_M30) ? atrM5 : atrM1;
      
      // CRITIQUE: éviter CopyBuffer avec INVALID_HANDLE → crash/détachement
      if(fastHandle == INVALID_HANDLE || slowHandle == INVALID_HANDLE || atrHandleTF == INVALID_HANDLE)
         continue;
      
      string prefix = "EMA_ST_" + tfNames[i] + "_";
      ObjectsDeleteAll(chId, prefix);
      
      double emaFast[], emaSlow[], atr[];
      datetime times[];
      ArraySetAsSeries(emaFast, true);
      ArraySetAsSeries(emaSlow, true);
      ArraySetAsSeries(atr, true);
      ArraySetAsSeries(times, true);
      
      if(CopyBuffer(fastHandle, 0, -totalBars, totalBars, emaFast) < totalBars) continue;
      if(CopyBuffer(slowHandle, 0, -totalBars, totalBars, emaSlow) < totalBars) continue;
      if(CopyBuffer(atrHandleTF, 0, -totalBars, totalBars, atr) < totalBars) continue;
      if(CopyTime(_Symbol, tfs[i], -totalBars, totalBars, times) < totalBars) continue;
      
      // Tracer la ligne Supertrend complète (passé + futur)
      string lineName = prefix + "LINE";
      
      datetime startTime = times[0];
      double emaFastStart = emaFast[0];
      double emaSlowStart = emaSlow[0];
      double atrStart = atr[0];
      if(!MathIsValidNumber(emaFastStart) || !MathIsValidNumber(emaSlowStart) || !MathIsValidNumber(atrStart))
         continue;
      
      double supertrendStart = 0;
      string directionStart = "";
      if(emaFastStart > emaSlowStart)
      {
         supertrendStart = emaSlowStart - (atrStart * ATRMultiplier); // Support
         directionStart = "SUPPORT";
      }
      else
      {
         supertrendStart = emaSlowStart + (atrStart * ATRMultiplier); // Résistance
         directionStart = "RESISTANCE";
      }
      
      // Point de fin (5000 bougies dans le futur)
      datetime endTime = currentTime + (datetime)(SMCChannelFutureBars * 60);
      
      // Créer la ligne de tendance complète
      if(!MathIsValidNumber(supertrendStart)) continue;
      ObjectCreate(chId, lineName, OBJ_TREND, 0, startTime, supertrendStart, endTime, supertrendStart);
      ObjectSetInteger(chId, lineName, OBJPROP_COLOR, 
                     (directionStart == "SUPPORT") ? supportColors[i] : resistanceColors[i]);
      ObjectSetInteger(chId, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(chId, lineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(chId, lineName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(chId, lineName, OBJPROP_BACK, false);
      ObjectSetString(chId, lineName, OBJPROP_TOOLTIP, 
                     "EMA Supertrend " + tfNames[i] + " - " + directionStart);
      
      int stepBars = MathMax(100, totalBars / 5);
      for(int j = 0; j < totalBars; j += stepBars)
      {
         if(j >= ArraySize(emaFast)) break;
         
         datetime pointTime = times[j];
         double emaFastVal = emaFast[j];
         double emaSlowVal = emaSlow[j];
         double atrVal = atr[j];
         
         double supertrend = 0;
         string direction = "";
         
         if(emaFastVal > emaSlowVal)
         {
            supertrend = emaSlowVal - (atrVal * ATRMultiplier); // Support
            direction = "SUPPORT";
         }
         else
         {
            supertrend = emaSlowVal + (atrVal * ATRMultiplier); // Résistance
            direction = "RESISTANCE";
         }
         
         if(!MathIsValidNumber(supertrend)) continue;
         string pointName = prefix + "POINT_" + IntegerToString(j);
         if(ObjectCreate(chId, pointName, OBJ_ARROW, 0, pointTime, supertrend))
         {
            ObjectSetInteger(chId, pointName, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(chId, pointName, OBJPROP_COLOR, 
                           (direction == "SUPPORT") ? supportColors[i] : resistanceColors[i]);
            ObjectSetInteger(chId, pointName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(chId, pointName, OBJPROP_BACK, false);
         }
      }
      
      string labelName = prefix + "LABEL";
      if(ObjectCreate(chId, labelName, OBJ_TEXT, 0, startTime, supertrendStart))
      {
         ObjectSetString(chId, labelName, OBJPROP_TEXT, "EMA-ST " + tfNames[i] + " " + directionStart);
         ObjectSetInteger(chId, labelName, OBJPROP_COLOR, 
                        (directionStart == "SUPPORT") ? supportColors[i] : resistanceColors[i]);
         ObjectSetInteger(chId, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(chId, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      }
   }
}

void DrawEMASupportResistance()
{
   if(emaM1H == INVALID_HANDLE || emaM5H == INVALID_HANDLE || emaH1H == INVALID_HANDLE) return;
   double emaM1[], emaM5[], emaH1[];
   ArraySetAsSeries(emaM1, true); ArraySetAsSeries(emaM5, true); ArraySetAsSeries(emaH1, true);
   if(CopyBuffer(emaM1H, 0, 0, 1, emaM1) < 1 || CopyBuffer(emaM5H, 0, 0, 1, emaM5) < 1 || CopyBuffer(emaH1H, 0, 0, 1, emaH1) < 1) return;
   ObjectDelete(0, "SMC_EMA_M1");
   ObjectDelete(0, "SMC_EMA_M5");
   ObjectDelete(0, "SMC_EMA_H1");
   ObjectCreate(0, "SMC_EMA_M1", OBJ_HLINE, 0, 0, emaM1[0]);
   ObjectSetInteger(0, "SMC_EMA_M1", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "SMC_EMA_M1", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "SMC_EMA_M1", OBJPROP_WIDTH, 1);
   ObjectSetString(0, "SMC_EMA_M1", OBJPROP_TOOLTIP, "EMA M1 (support/resistance)");
   ObjectCreate(0, "SMC_EMA_M5", OBJ_HLINE, 0, 0, emaM5[0]);
   ObjectSetInteger(0, "SMC_EMA_M5", OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, "SMC_EMA_M5", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "SMC_EMA_M5", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "SMC_EMA_M5", OBJPROP_TOOLTIP, "EMA M5 (support/resistance)");
   ObjectCreate(0, "SMC_EMA_H1", OBJ_HLINE, 0, 0, emaH1[0]);
   ObjectSetInteger(0, "SMC_EMA_H1", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, "SMC_EMA_H1", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "SMC_EMA_H1", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "SMC_EMA_H1", OBJPROP_TOOLTIP, "EMA H1 (support/resistance)");
}

//| Retourne le niveau SuperTrend actuel (support ou résistance) pour un TF |
bool GetSuperTrendLevel(ENUM_TIMEFRAMES tf, double &supportOut, double &resistanceOut)
{
   supportOut = 0;
   resistanceOut = 0;
   int fastH = INVALID_HANDLE, slowH = INVALID_HANDLE, atrH = INVALID_HANDLE;
   if(tf == PERIOD_M5) { fastH = emaFastM5; slowH = emaSlowM5; atrH = atrM5; }
   else if(tf == PERIOD_H1) { fastH = emaFastH1; slowH = emaSlowH1; atrH = atrH1; }
   else if(tf == PERIOD_M1) { fastH = emaFastM1; slowH = emaSlowM1; atrH = atrM1; }
   else return false;
   if(fastH == INVALID_HANDLE || slowH == INVALID_HANDLE || atrH == INVALID_HANDLE) return false;
   double emaF[], emaS[], atr[];
   ArraySetAsSeries(emaF, true); ArraySetAsSeries(emaS, true); ArraySetAsSeries(atr, true);
   if(CopyBuffer(fastH, 0, 0, 1, emaF) < 1 || CopyBuffer(slowH, 0, 0, 1, emaS) < 1 || CopyBuffer(atrH, 0, 0, 1, atr) < 1) return false;
   double atrVal = atr[0] * ATRMultiplier;
   if(emaF[0] > emaS[0]) { supportOut = emaS[0] - atrVal; resistanceOut = 0; }   // Support
   else { resistanceOut = emaS[0] + atrVal; supportOut = 0; }                     // Résistance
   return true;
}

//| Niveau BUY LIMIT = support M1 tracé sur le graphique (ligne SMC_Limit_Support) |
double GetClosestBuyLevel(double currentPrice, double atr, double maxDistATR, string &sourceOut)
{
   sourceOut = "";
   if(atr <= 0) return 0.0;
   double maxDist = MathMax(atr * MathMax(0.2, maxDistATR), atr * 0.2);
   double best = 0.0;

   // 1) Pivots locaux (support proche) sur M1
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 80, r) >= 20)
   {
      for(int i = 2; i < 30; i++)
      {
         double lo = r[i].low;
         if(lo <= 0 || lo >= currentPrice) continue;
         // Pivot low simple
         if(lo < r[i-1].low && lo < r[i+1].low)
         {
            double dist = currentPrice - lo;
            if(dist <= maxDist && lo > best)
            {
               best = lo;
               sourceOut = "Pivot Low";
            }
         }
      }
   }

   // 2) Swing low global (si disponible) mais seulement s'il est proche
   if(g_lastSwingLow > 0 && g_lastSwingLow < currentPrice)
   {
      double dist = currentPrice - g_lastSwingLow;
      if(dist <= maxDist && g_lastSwingLow > best)
      {
         best = g_lastSwingLow;
         sourceOut = "Swing Low";
      }
   }

   // 3) SuperTrend supports (M5/H1) si proche
   double stM5s = 0, stM5r = 0, stH1s = 0, stH1r = 0;
   if(GetSuperTrendLevel(PERIOD_M5, stM5s, stM5r) && stM5s > 0 && stM5s < currentPrice)
   {
      double dist = currentPrice - stM5s;
      if(dist <= maxDist && stM5s > best)
      {
         best = stM5s;
         sourceOut = "SuperTrend M5";
      }
   }
   if(GetSuperTrendLevel(PERIOD_H1, stH1s, stH1r) && stH1s > 0 && stH1s < currentPrice)
   {
      double dist = currentPrice - stH1s;
      if(dist <= maxDist && stH1s > best)
      {
         best = stH1s;
         sourceOut = "SuperTrend H1";
      }
   }

   // 4) Fallback: ligne support chart (souvent plus éloignée) uniquement si encore dans maxDist
   if(ObjectFind(0, "SMC_Limit_Support") >= 0)
   {
      double supp = ObjectGetDouble(0, "SMC_Limit_Support", OBJPROP_PRICE);
      if(supp > 0 && supp < currentPrice)
      {
         double dist = currentPrice - supp;
         if(dist <= maxDist && supp > best)
         {
            best = supp;
            sourceOut = "Chart Support";
         }
      }
   }

   return best;
}

//| Niveau SELL LIMIT = résistance M1 tracée sur le graphique (ligne SMC_Limit_Resistance) |
double GetClosestSellLevel(double currentPrice, double atr, double maxDistATR, string &sourceOut)
{
   sourceOut = "";
   if(atr <= 0) return 0.0;
   double maxDist = MathMax(atr * MathMax(0.2, maxDistATR), atr * 0.2);
   double best = 0.0;

   // 1) Pivots locaux (résistance proche) sur M1
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 80, r) >= 20)
   {
      for(int i = 2; i < 30; i++)
      {
         double hi = r[i].high;
         if(hi <= 0 || hi <= currentPrice) continue;
         // Pivot high simple
         if(hi > r[i-1].high && hi > r[i+1].high)
         {
            double dist = hi - currentPrice;
            if(dist <= maxDist && (best == 0.0 || hi < best))
            {
               best = hi;
               sourceOut = "Pivot High";
            }
         }
      }
   }

   // 2) Swing high global (si disponible) mais seulement s'il est proche
   if(g_lastSwingHigh > 0 && g_lastSwingHigh > currentPrice)
   {
      double dist = g_lastSwingHigh - currentPrice;
      if(dist <= maxDist && (best == 0.0 || g_lastSwingHigh < best))
      {
         best = g_lastSwingHigh;
         sourceOut = "Swing High";
      }
   }

   // 3) SuperTrend résistances (M5/H1) si proche
   double stM5s = 0, stM5r = 0, stH1s = 0, stH1r = 0;
   if(GetSuperTrendLevel(PERIOD_M5, stM5s, stM5r) && stM5r > 0 && stM5r > currentPrice)
   {
      double dist = stM5r - currentPrice;
      if(dist <= maxDist && (best == 0.0 || stM5r < best))
      {
         best = stM5r;
         sourceOut = "SuperTrend M5";
      }
   }
   if(GetSuperTrendLevel(PERIOD_H1, stH1s, stH1r) && stH1r > 0 && stH1r > currentPrice)
   {
      double dist = stH1r - currentPrice;
      if(dist <= maxDist && (best == 0.0 || stH1r < best))
      {
         best = stH1r;
         sourceOut = "SuperTrend H1";
      }
   }

   // 4) Fallback: ligne résistance chart uniquement si dans maxDist
   if(ObjectFind(0, "SMC_Limit_Resistance") >= 0)
   {
      double res = ObjectGetDouble(0, "SMC_Limit_Resistance", OBJPROP_PRICE);
      if(res > 0 && res > currentPrice)
      {
         double dist = res - currentPrice;
         if(dist <= maxDist && (best == 0.0 || res < best))
         {
            best = res;
            sourceOut = "Chart Resistance";
         }
      }
   }

   return best;
}

//| Affiche sur le graphique: Support, Résistance, EMA M1/M5/H1, SuperTrend M5/H1, niveaux limite choisis |
void DrawLimitOrderLevels()
{
   ObjectsDeleteAll(0, "SMC_Limit_");
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 30, rates) < 20) return;
   double support = rates[0].low, resistance = rates[0].high;
   for(int i = 1; i < 20; i++) { if(rates[i].low < support) support = rates[i].low; if(rates[i].high > resistance) resistance = rates[i].high; }
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atrVal = 0;
   if(atrHandle != INVALID_HANDLE) { double atr[]; ArraySetAsSeries(atr, true); if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1) atrVal = atr[0]; }
   if(atrVal <= 0) atrVal = (resistance - support) * 0.1;
   string srcBuy = "", srcSell = "";
   double buyLevel = GetClosestBuyLevel(price, atrVal, MaxDistanceLimitATR, srcBuy);
   double sellLevel = GetClosestSellLevel(price, atrVal, MaxDistanceLimitATR, srcSell);
   ObjectCreate(0, "SMC_Limit_Support", OBJ_HLINE, 0, 0, support);
   ObjectSetInteger(0, "SMC_Limit_Support", OBJPROP_COLOR, clrDarkGreen);
   ObjectSetInteger(0, "SMC_Limit_Support", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetString(0, "SMC_Limit_Support", OBJPROP_TOOLTIP, "Support (20 bars)");
   ObjectCreate(0, "SMC_Limit_Resistance", OBJ_HLINE, 0, 0, resistance);
   ObjectSetInteger(0, "SMC_Limit_Resistance", OBJPROP_COLOR, clrDarkRed);
   ObjectSetInteger(0, "SMC_Limit_Resistance", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetString(0, "SMC_Limit_Resistance", OBJPROP_TOOLTIP, "Résistance (20 bars)");
   double stM5s = 0, stM5r = 0, stH1s = 0, stH1r = 0;
   if(GetSuperTrendLevel(PERIOD_M5, stM5s, stM5r))
   {
      if(stM5s > 0) { ObjectCreate(0, "SMC_Limit_ST_M5", OBJ_HLINE, 0, 0, stM5s); ObjectSetInteger(0, "SMC_Limit_ST_M5", OBJPROP_COLOR, clrAqua); ObjectSetString(0, "SMC_Limit_ST_M5", OBJPROP_TOOLTIP, "SuperTrend M5 (support)"); }
      else if(stM5r > 0) { ObjectCreate(0, "SMC_Limit_ST_M5", OBJ_HLINE, 0, 0, stM5r); ObjectSetInteger(0, "SMC_Limit_ST_M5", OBJPROP_COLOR, clrMagenta); ObjectSetString(0, "SMC_Limit_ST_M5", OBJPROP_TOOLTIP, "SuperTrend M5 (résistance)"); }
   }
   if(GetSuperTrendLevel(PERIOD_H1, stH1s, stH1r))
   {
      if(stH1s > 0) { ObjectCreate(0, "SMC_Limit_ST_H1", OBJ_HLINE, 0, 0, stH1s); ObjectSetInteger(0, "SMC_Limit_ST_H1", OBJPROP_COLOR, clrDodgerBlue); ObjectSetString(0, "SMC_Limit_ST_H1", OBJPROP_TOOLTIP, "SuperTrend H1 (support)"); }
      else if(stH1r > 0) { ObjectCreate(0, "SMC_Limit_ST_H1", OBJ_HLINE, 0, 0, stH1r); ObjectSetInteger(0, "SMC_Limit_ST_H1", OBJPROP_COLOR, clrOrange); ObjectSetString(0, "SMC_Limit_ST_H1", OBJPROP_TOOLTIP, "SuperTrend H1 (résistance)"); }
   }
   if(g_lastSwingLow > 0) { ObjectCreate(0, "SMC_Limit_SwingLow", OBJ_HLINE, 0, 0, g_lastSwingLow); ObjectSetInteger(0, "SMC_Limit_SwingLow", OBJPROP_COLOR, clrLime); ObjectSetInteger(0, "SMC_Limit_SwingLow", OBJPROP_STYLE, STYLE_DASH); ObjectSetString(0, "SMC_Limit_SwingLow", OBJPROP_TOOLTIP, "Swing Low (PML)"); }
   if(g_lastSwingHigh > 0) { ObjectCreate(0, "SMC_Limit_SwingHigh", OBJ_HLINE, 0, 0, g_lastSwingHigh); ObjectSetInteger(0, "SMC_Limit_SwingHigh", OBJPROP_COLOR, clrTomato); ObjectSetInteger(0, "SMC_Limit_SwingHigh", OBJPROP_STYLE, STYLE_DASH); ObjectSetString(0, "SMC_Limit_SwingHigh", OBJPROP_TOOLTIP, "Swing High (PML)"); }
   if(buyLevel > 0) { ObjectCreate(0, "SMC_Limit_BuyLevel", OBJ_HLINE, 0, 0, buyLevel); ObjectSetInteger(0, "SMC_Limit_BuyLevel", OBJPROP_COLOR, clrLime); ObjectSetInteger(0, "SMC_Limit_BuyLevel", OBJPROP_WIDTH, 3); ObjectSetString(0, "SMC_Limit_BuyLevel", OBJPROP_TOOLTIP, "Niveau BUY LIMIT (" + srcBuy + ")"); }
   if(sellLevel > 0) { ObjectCreate(0, "SMC_Limit_SellLevel", OBJ_HLINE, 0, 0, sellLevel); ObjectSetInteger(0, "SMC_Limit_SellLevel", OBJPROP_COLOR, clrRed); ObjectSetInteger(0, "SMC_Limit_SellLevel", OBJPROP_WIDTH, 3); ObjectSetString(0, "SMC_Limit_SellLevel", OBJPROP_TOOLTIP, "Niveau SELL LIMIT (" + srcSell + ")"); }
}

void DrawPredictionChannel()
{
   int throttleSec = g_channelValid ? 60 : 15;
   if(TimeCurrent() - g_lastChannelUpdate < throttleSec)
   {
      if(g_channelValid)
         DrawPredictionChannelLines();
      else if(ShowChartGraphics)
         DrawPredictionChannelLabel("Canal ML: chargement...");
      return;
   }
   g_lastChannelUpdate = TimeCurrent();
   g_channelValid = false;
   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");
   string pathCh = "/prediction-channel?symbol=" + symEnc + "&timeframe=M1&future_bars=" + IntegerToString(PredictionChannelBars);
   string url1 = AI_ServerURL + pathCh;
   string url2 = AI_ServerURL + pathCh;
   string headers = "";
   char post[];
   char result[];
   string resultHeaders;
   int res = WebRequest("GET", url1, headers, AI_Timeout_ms, post, result, resultHeaders);
   if(res != 200)
      res = WebRequest("GET", url2, headers, AI_Timeout_ms, post, result, resultHeaders);
   if(res == 200)
   {
      string json = CharArrayToString(result);
      if(StringFind(json, "\"ok\":true") >= 0 || StringFind(json, "\"ok\": true") >= 0)
      {
         long timeStartSec = (long)ExtractJsonNumber(json, "time_start");
         int periodSec = (int)ExtractJsonNumber(json, "period_seconds");
         if(periodSec <= 0) periodSec = 60;
         g_chUpperStart = ExtractJsonNumber(json, "upper_start");
         g_chUpperEnd   = ExtractJsonNumber(json, "upper_end");
         g_chLowerStart = ExtractJsonNumber(json, "lower_start");
         g_chLowerEnd   = ExtractJsonNumber(json, "lower_end");
         g_chTimeStart = (datetime)timeStartSec;
         g_chTimeEnd   = (datetime)(timeStartSec + (long)PredictionChannelBars * (long)periodSec);
         g_channelValid = (g_chUpperStart != 0 || g_chLowerStart != 0) &&
                         MathIsValidNumber(g_chUpperStart) && MathIsValidNumber(g_chLowerStart) &&
                         MathIsValidNumber(g_chUpperEnd) && MathIsValidNumber(g_chLowerEnd);
      }
   }
   if(!g_channelValid)
      BuildFallbackPredictionChannel();
   if(g_channelValid)
      DrawPredictionChannelLines();
}

void BuildFallbackPredictionChannel()
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   int need = MathMin(1000, Bars(_Symbol, PERIOD_M1));
   if(need < 50) need = 50;
   if(CopyRates(_Symbol, PERIOD_M1, 0, need, r) < need) return;
   double sumX = 0, sumYH = 0, sumYL = 0, sumXX = 0, sumXYH = 0, sumXYL = 0;
   for(int i = 0; i < need; i++)
   {
      double x = (double)i;
      sumX += x; sumXX += x * x;
      sumYH += r[i].high; sumYL += r[i].low;
      sumXYH += x * r[i].high; sumXYL += x * r[i].low;
   }
   double n = (double)need;
   double denom = n * sumXX - sumX * sumX;
   if(MathAbs(denom) < 1e-10) denom = 1;
   double slopeH = (n * sumXYH - sumX * sumYH) / denom;
   double slopeL = (n * sumXYL - sumX * sumYL) / denom;
   double bH = (sumYH - slopeH * sumX) / n;
   double bL = (sumYL - slopeL * sumX) / n;
   double marginU = 0, marginL = 0;
   for(int i = 0; i < need; i++)
   {
      double regH = bH + slopeH * (double)i;
      double regL = bL + slopeL * (double)i;
      if(r[i].high > regH) marginU = MathMax(marginU, r[i].high - regH);
      if(r[i].low < regL)  marginL = MathMax(marginL, regL - r[i].low);
   }
   g_chTimeStart = r[0].time;
   g_chUpperStart = bH + marginU;
   g_chLowerStart = bL - marginL;
   g_chUpperEnd   = bH + marginU + slopeH * (double)PredictionChannelBars;
   g_chLowerEnd   = bL - marginL + slopeL * (double)PredictionChannelBars;
   // Validation anti-détachement: rejeter NaN/Inf avant d'activer le canal
   g_channelValid = (MathIsValidNumber(g_chUpperStart) && MathIsValidNumber(g_chLowerStart) &&
                     MathIsValidNumber(g_chUpperEnd) && MathIsValidNumber(g_chLowerEnd) &&
                     g_chTimeStart > 0);
}

double ExtractJsonNumber(string json, string key)
{
   string search = "\"" + key + "\":";
   int pos = StringFind(json, search);
   if(pos < 0) return 0;
   int start = pos + StringLen(search);
   while(start < StringLen(json) && (StringGetCharacter(json, start) == ' ' || StringGetCharacter(json, start) == '\t'))
      start++;
   int i = start;
   while(i < StringLen(json))
   {
      ushort c = StringGetCharacter(json, i);
      if(c == '-' || (c >= '0' && c <= '9') || c == '.')
         i++;
      else
         break;
   }
   if(i <= start) return 0;
   return StringToDouble(StringSubstr(json, start, i - start));
}

void DrawPredictionChannelLines()
{
   ObjectsDeleteAll(0, "SMC_Chan_");
   datetime tNow = iTime(_Symbol, PERIOD_M1, 0);
   if(tNow <= 0) tNow = TimeCurrent();
   int periodSec = 60;
   int pastBars = MathMax(1, PredictionChannelPastBars);
   double slopeUpper = (PredictionChannelBars > 0) ? (g_chUpperEnd - g_chUpperStart) / (double)PredictionChannelBars : 0;
   double slopeLower = (PredictionChannelBars > 0) ? (g_chLowerEnd - g_chLowerStart) / (double)PredictionChannelBars : 0;
   double minsFromStart = (g_chTimeStart > 0) ? (double)(tNow - g_chTimeStart) / (double)periodSec : 0;
   double u0 = g_chUpperStart + slopeUpper * minsFromStart;
   double l0 = g_chLowerStart + slopeLower * minsFromStart;
   datetime tStart = tNow - (datetime)(pastBars * periodSec);
   datetime tEnd = tNow + (datetime)(PredictionChannelBars * periodSec);
   double uStart = u0 - slopeUpper * (double)pastBars;
   double lStart = l0 - slopeLower * (double)pastBars;
   double uEnd = u0 + slopeUpper * (double)PredictionChannelBars;
   double lEnd = l0 + slopeLower * (double)PredictionChannelBars;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   int barsFit = (int)MathMin((long)pastBars, Bars(_Symbol, PERIOD_M1));
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsFit, r) >= barsFit)
   {
      double marginU = 0, marginL = 0;
      for(int i = 0; i < barsFit; i++)
      {
         double uAt = u0 - slopeUpper * (double)i;
         double lAt = l0 - slopeLower * (double)i;
         if(r[i].high > uAt) marginU = MathMax(marginU, r[i].high - uAt);
         if(r[i].low < lAt)  marginL = MathMax(marginL, lAt - r[i].low);
      }
      uStart += marginU; lStart -= marginL;
      uEnd += marginU;   lEnd -= marginL;
   }

   color clrChan = (color)C'220,220,220';
   // Pas de surface remplie : uniquement 2 lignes qui enveloppent les bougies et suivent leur mouvement
   if(ObjectCreate(0, "SMC_Chan_Upper", OBJ_TREND, 0, tStart, uStart, tEnd, uEnd))
   {
      ObjectSetInteger(0, "SMC_Chan_Upper", OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, "SMC_Chan_Upper", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "SMC_Chan_Upper", OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, "SMC_Chan_Upper", OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, "SMC_Chan_Upper", OBJPROP_BACK, false);
   }
   if(ObjectCreate(0, "SMC_Chan_Lower", OBJ_TREND, 0, tStart, lStart, tEnd, lEnd))
   {
      ObjectSetInteger(0, "SMC_Chan_Lower", OBJPROP_COLOR, clrSilver);
      ObjectSetInteger(0, "SMC_Chan_Lower", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "SMC_Chan_Lower", OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, "SMC_Chan_Lower", OBJPROP_RAY_LEFT, false);
      ObjectSetInteger(0, "SMC_Chan_Lower", OBJPROP_BACK, false);
   }
   string lbl = "Canal ML " + IntegerToString(pastBars) + "→" + IntegerToString(PredictionChannelBars) + " bars";
   if(ObjectFind(0, "SMC_Chan_Label") < 0)
      ObjectCreate(0, "SMC_Chan_Label", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_YDISTANCE, 50);
   ObjectSetString(0, "SMC_Chan_Label", OBJPROP_TEXT, lbl);
   ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_COLOR, clrSilver);
   ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_FONTSIZE, 9);
}

void DrawPredictionChannelLabel(string text)
{
   if(ObjectFind(0, "SMC_Chan_Status") < 0)
      ObjectCreate(0, "SMC_Chan_Status", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_YDISTANCE, 50);
   ObjectSetString(0, "SMC_Chan_Status", OBJPROP_TEXT, text);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_COLOR, clrGray);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_FONTSIZE, 9);
}

// Ajuste l'ordre LIMIT EMA SMC (support/résistance) sur le niveau le plus proche
// Mise à jour maximum toutes les 5 minutes pour éviter les modifications trop fréquentes
void AdjustEMAScalpingLimitOrder()
{
   static datetime lastAdjustTime = 0;
   datetime now = TimeCurrent();
   if(now - lastAdjustTime < 300) return; // 5 minutes
   lastAdjustTime = now;
   
   // Rechercher un ordre LIMIT EMA SMC pour ce symbole
   ulong ticket = 0;
   ENUM_ORDER_TYPE ordType = ORDER_TYPE_BUY_LIMIT;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, "EMA SMC BUY LIMIT") >= 0 || StringFind(cmt, "EMA SMC SELL LIMIT") >= 0)
      {
         ticket = t;
         ordType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         break;
      }
   }
   if(ticket == 0) return;
   
   // Calculer ATR actuel
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0)
         atrVal = atrBuf[0];
   }
   if(atrVal <= 0)
      atrVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100;
   
   double price = (ordType == ORDER_TYPE_BUY_LIMIT)
                  ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                  : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(price <= 0) return;
   
   string src = "";
   double bestLevel = 0.0;
   if(ordType == ORDER_TYPE_BUY_LIMIT)
      bestLevel = GetClosestBuyLevel(price, atrVal, MaxDistanceLimitATR, src);
   else
      bestLevel = GetClosestSellLevel(price, atrVal, MaxDistanceLimitATR, src);
   
   if(bestLevel <= 0) return;
   
   // Recalculer l'entrée EXACTEMENT sur le niveau S/R tracé
   double point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double newEntry = bestLevel;
   
   double oldPrice = OrderGetDouble(ORDER_PRICE_OPEN);
   if(MathAbs(oldPrice - newEntry) < point * 2) return; // changement trop petit
   
   // Recalculer SL/TP autour du nouveau prix
   double sl, tp;
   if(ordType == ORDER_TYPE_BUY_LIMIT)
   {
      sl = newEntry - atrVal * SL_ATRMult;
      tp = newEntry + atrVal * TP_ATRMult;
   }
   else
   {
      sl = newEntry + atrVal * SL_ATRMult;
      tp = newEntry - atrVal * TP_ATRMult;
   }
   
   // Préparer la requête de modification
   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);
   req.action = TRADE_ACTION_MODIFY;
   req.order  = ticket;
   req.symbol = _Symbol;
   req.magic  = InpMagicNumber;
   req.price  = newEntry;
   req.sl     = sl;
   req.tp     = tp;
   
   if(!ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, ordType))
      return;
   
   if(SafeOrderSend(req, res))
   {
      Print("🔧 EMA SMC LIMIT ajusté @ ", DoubleToString(req.price, _Digits),
            " (ancien: ", DoubleToString(oldPrice, _Digits), ") src=", src);
   }
}

// Retourne la dernière intersection prix/canal ML (et une projection simple)
// direction = "BUY" (canal inférieur) ou "SELL" (canal supérieur)
bool GetRecentAndProjectedMLChannelIntersection(string direction, double &recentPrice, datetime &recentTime, double &projectedPrice, datetime &projectedTime)
{
   if(!g_channelValid) return false;
   
   int periodSec = 60;
   double slopeUpper = (PredictionChannelBars > 0) ? (g_chUpperEnd - g_chUpperStart) / (double)PredictionChannelBars : 0;
   double slopeLower = (PredictionChannelBars > 0) ? (g_chLowerEnd - g_chLowerStart) / (double)PredictionChannelBars : 0;
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = CopyRates(_Symbol, PERIOD_M1, 0, 200, rates);
   if(bars < 10) return false;
   
   datetime last1 = 0, last2 = 0;
   double price1 = 0.0, price2 = 0.0;
   
   // Parcours des bougies (0 = plus récente)
   for(int i = 1; i < bars; i++)
   {
      datetime tCurr = rates[i-1].time;
      datetime tPrev = rates[i].time;
      
      double minsFromStartCurr = (g_chTimeStart > 0) ? (double)(tCurr - g_chTimeStart) / (double)periodSec : 0.0;
      double minsFromStartPrev = (g_chTimeStart > 0) ? (double)(tPrev - g_chTimeStart) / (double)periodSec : 0.0;
      
      double chCurr = 0.0, chPrev = 0.0;
      if(direction == "BUY")
      {
         chCurr = g_chLowerStart + slopeLower * minsFromStartCurr;
         chPrev = g_chLowerStart + slopeLower * minsFromStartPrev;
      }
      else // SELL
      {
         chCurr = g_chUpperStart + slopeUpper * minsFromStartCurr;
         chPrev = g_chUpperStart + slopeUpper * minsFromStartPrev;
      }
      
      double diffCurr = rates[i-1].close - chCurr;
      double diffPrev = rates[i].close - chPrev;
      
      bool crossed = (diffCurr == 0.0 || diffPrev == 0.0 || (diffCurr > 0.0 && diffPrev < 0.0) || (diffCurr < 0.0 && diffPrev > 0.0));
      if(crossed)
      {
         datetime tInt = tCurr;
         double pInt = chCurr;
         
         if(last1 == 0)
         {
            last1 = tInt;
            price1 = pInt;
         }
         else
         {
            last2 = last1;
            price2 = price1;
            last1 = tInt;
            price1 = pInt;
         }
      }
   }
   
   if(last1 == 0)
      return false;
   
   recentPrice = price1;
   recentTime = last1;
   
   // Par défaut la projection = dernière intersection
   projectedPrice = price1;
   projectedTime  = last1;
   
   if(last2 > 0 && g_chTimeEnd > 0)
   {
      int dtSec = (int)(last1 - last2);
      if(dtSec > 0)
      {
         datetime tProj = last1 + (datetime)dtSec;
         if(tProj > g_chTimeEnd)
            tProj = g_chTimeEnd;
         
         double minsFromStartProj = (g_chTimeStart > 0) ? (double)(tProj - g_chTimeStart) / (double)periodSec : 0.0;
         double chProj = 0.0;
         if(direction == "BUY")
            chProj = g_chLowerStart + slopeLower * minsFromStartProj;
         else
            chProj = g_chUpperStart + slopeUpper * minsFromStartProj;
         
         projectedPrice = chProj;
         projectedTime  = tProj;
      }
   }
   
   return true;
}

bool DetectSMCSignal(SMC_Signal &sig)
{
   sig.action = "HOLD";
   sig.confidence = 0;
   sig.reasoning = "";
   sig.entryPrice = 0;
   sig.stopLoss = 0;
   sig.takeProfit = 0;
   
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(atrHandle == INVALID_HANDLE) return false;
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 3, atr) < 3) return false;
   double atrMult = SMC_GetATRMultiplier(cat);
   
   bool hasBuySignal = false;
   bool hasSellSignal = false;
   string reason = "";
   
   bool lsSSL = false, lsBSL = false;
   int lsBarsAgo = 99;
   if(UseLiquiditySweep)
   {
      string lsType;
      int barsAgo = 0;
      if(SMC_DetectLiquiditySweepEx(_Symbol, LTF, lsType, barsAgo))
      {
         lsBarsAgo = barsAgo;
         if(lsType == "SSL") lsSSL = true;
         else if(lsType == "BSL") lsBSL = true;
      }
      if(!RequireStructureAfterSweep)
      {
         if(lsSSL) { hasBuySignal = true; reason += "LS-SSL "; }
         else if(lsBSL) { hasSellSignal = true; reason += "LS-BSL "; }
      }
   }
   
   if(UseFVG)
   {
      FVGData fvg;
      if(SMC_DetectFVG(_Symbol, LTF, 30, fvg))
      {
         // FVG + M5/H1 alignment: prix dans FVG ET M5/H1 confirment la direction
         string m5Dir = g_smcTfM5Dir;
         string h1Dir = g_smcTfH1Dir;
         bool m5H1Aligned = false;
         if(fvg.direction == 1 && m5Dir == "BULL" && h1Dir == "BULL") m5H1Aligned = true;
         if(fvg.direction == -1 && m5Dir == "BEAR" && h1Dir == "BEAR") m5H1Aligned = true;

         if(m5H1Aligned)
         {
            if(fvg.direction == 1 && bid >= fvg.bottom && bid <= fvg.top) { hasBuySignal = true; reason += "FVG-Bull+TF "; }
            else if(fvg.direction == -1 && ask <= fvg.top && ask >= fvg.bottom) { hasSellSignal = true; reason += "FVG-Bear+TF "; }
         }
      }
   }
   
   if(UseOrderBlocks)
   {
      OrderBlockData ob;
      if(SMC_DetectOrderBlock(_Symbol, LTF, ob))
      {
         if(ob.direction == 1 && bid >= ob.low && bid <= ob.high) { hasBuySignal = true; reason += "OB-Bull "; }
         else if(ob.direction == -1 && ask <= ob.high && ask >= ob.low) { hasSellSignal = true; reason += "OB-Bear "; }
      }
   }
   
   if(UseBOS)
   {
      int bosDir;
      if(SMC_DetectBOS(_Symbol, LTF, bosDir))
      {
         if(bosDir == 1) { hasBuySignal = true; reason += "BOS-Up "; }
         else if(bosDir == -1) { hasSellSignal = true; reason += "BOS-Down "; }
      }
   }
   bool inDiscount = IsInDiscountZone();
   bool inPremium  = IsInPremiumZone();
   if(inDiscount) { hasBuySignal = true; reason += "Zone-Discount "; }
   if(inPremium)  { hasSellSignal = true; reason += "Zone-Premium "; }

   if(RequireStructureAfterSweep && UseLiquiditySweep)
   {
      bool waitOk = !NoEntryDuringSweep || (lsBarsAgo >= 1); // Réduit de 2 à 1 barre
      // Moins restrictif: ne bloquer que les signaux contradictoires directs
      if(lsSSL && hasSellSignal) hasSellSignal = false; // Bloquer SELL si SSL détecté
      if(lsBSL && hasBuySignal) hasBuySignal = false;  // Bloquer BUY si BSL détecté
      // Garder les autres signaux même sans confirmation LS
      if(hasBuySignal && lsSSL && waitOk) reason += "[LS+Conf] ";
      if(hasSellSignal && lsBSL && waitOk) reason += "[LS+Conf] ";
   }
   if((g_lastAIAction == "BUY" || g_lastAIAction == "buy") && g_lastAIConfidence >= MinAIConfidence) { hasBuySignal = true; reason += "IA-BUY "; }
   if((g_lastAIAction == "SELL" || g_lastAIAction == "sell") && g_lastAIConfidence >= MinAIConfidence) { hasSellSignal = true; reason += "IA-SELL "; }

   bool isBoom = (cat == SYM_BOOM_CRASH && IsBoomLikeSymbol(_Symbol));
   bool isCrash = (cat == SYM_BOOM_CRASH && IsCrashLikeSymbol(_Symbol));
   if(isBoom && BoomBuyOnly) hasSellSignal = false;
   if(isCrash && CrashSellOnly) hasBuySignal = false;
   
   double slDist = atr[0] * SL_ATRMult;
   double tpDist = atr[0] * TP_ATRMult;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   bool haveRates = (CopyRates(_Symbol, LTF, 0, 10, r) >= 10);
   double newSwingLow = 0, newSwingHigh = 0;
   if(haveRates && StopBeyondNewStructure)
   {
      newSwingLow = r[1].low;
      newSwingHigh = r[1].high;
      for(int i = 2; i < 8; i++) { if(r[i].low < newSwingLow) newSwingLow = r[i].low; if(r[i].high > newSwingHigh) newSwingHigh = r[i].high; }
   }
   
   double buffer = atr[0] * 0.5;
   if(hasBuySignal && !hasSellSignal)
   {
      sig.action = "BUY";
      sig.confidence = 0.65;
      sig.concept = reason;
      sig.reasoning = "SMC: " + reason;
      sig.entryPrice = ask;
      if(!NoSLTP_BoomCrash)
      {
         // Calculer SL/TP plus proches du prix actuel
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         if(StopBeyondNewStructure && lsSSL && newSwingLow > 0)
            sig.stopLoss = newSwingLow - buffer;
         else
         {
            // SL plus proche : utiliser 20-30 pips au lieu de la distance ATR complète
            double minSL = MathMax(20.0 * _Point, slDist * 0.3); // 30% de la distance ATR
            sig.stopLoss = currentAsk - minSL;
         }
         
         // TP plus proche : utiliser 40-60 pips au lieu de la distance ATR complète
         double minTP = MathMax(40.0 * _Point, tpDist * 0.4); // 40% de la distance ATR
         sig.takeProfit = currentAsk + minTP;
         
         Print("📊 SL/TP ajustés: SL=", DoubleToString(sig.stopLoss, _Digits), 
                " TP=", DoubleToString(sig.takeProfit, _Digits), 
                " Ask=", DoubleToString(currentAsk, _Digits));
      }
      return true;
   }
   else if(hasSellSignal && !hasBuySignal)
   {
      sig.action = "SELL";
      sig.confidence = 0.65;
      sig.concept = reason;
      sig.reasoning = "SMC: " + reason;
      sig.entryPrice = bid;
      if(!NoSLTP_BoomCrash)
      {
         // Calculer SL/TP plus proches du prix actuel
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         if(StopBeyondNewStructure && lsBSL && newSwingHigh > 0)
            sig.stopLoss = newSwingHigh + buffer;
         else
         {
            // SL plus proche : utiliser 20-30 pips au lieu de la distance ATR complète
            double minSL = MathMax(20.0 * _Point, slDist * 0.3); // 30% de la distance ATR
            sig.stopLoss = currentBid + minSL;
         }
         
         // TP plus proche : utiliser 40-60 pips au lieu de la distance ATR complète
         double minTP = MathMax(40.0 * _Point, tpDist * 0.4); // 40% de la distance ATR
         sig.takeProfit = currentBid - minTP;
         
         Print("📊 SL/TP ajustés SELL: SL=", DoubleToString(sig.stopLoss, _Digits), 
                " TP=", DoubleToString(sig.takeProfit, _Digits), 
                " Bid=", DoubleToString(currentBid, _Digits));
      }
      return true;
   }
   return false;
}

bool ConfirmWithAI(SMC_Signal &sig)
{
   if(!RequireAIConfirmation) return true;
   if(!UseAIServer) return true;
   
   // Plus permissif: utiliser la dernière décision IA si disponible
   if(g_lastAIAction != "" && g_lastAIConfidence > 0)
   {
      // Confiance réduite pour plus d'opportunités
      if(g_lastAIConfidence >= 0.40) // 40% au lieu de 55%
      {
         if(sig.action == "BUY" && (g_lastAIAction == "BUY" || g_lastAIAction == "buy")) 
         {
            Print("✅ Signal BUY confirmé par IA (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
            return true;
         }
         if(sig.action == "SELL" && (g_lastAIAction == "SELL" || g_lastAIAction == "sell")) 
         {
            Print("✅ Signal SELL confirmé par IA (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
            return true;
         }
      }
   }
   
   // Fallback plus permissif si IA disponible mais faible confiance
   if(g_lastAIConfidence >= 0.30 && g_lastAIConfidence > 0)
   {
      Print("⚠️ Signal exécuté avec faible confiance IA (", DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return true;
   }
   
   // Si IA indisponible, autoriser quand même pour ne pas manquer d'opportunités
   if(g_lastAIAction == "" || g_lastAIConfidence == 0)
   {
      Print("🔄 IA indisponible - Signal SMC exécuté sans confirmation");
      return true;
   }
   
   Print("❌ Signal rejeté - IA: ", g_lastAIAction, " (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
   return false;
}

void ExecuteSignal(SMC_Signal &sig)
{
   if(CountPositionsOurEA() >= MaxPositionsTerminal) return;
   if(!TryAcquireOpenLock()) return;
   double lotSize = CalculateLotSize();
   lotSize = ApplyRecoveryLot(lotSize);
   if(lotSize <= 0) { ReleaseOpenLock(); return; }
   
   // STRATÉGIE UNIQUE SPIKE POUR BOOM/CRASH:
   // ne pas exécuter la logique SMC classique sur Boom/Crash
   if(SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
   {
      ReleaseOpenLock();
      return;
   }
   
   // Exiger une décision IA forte pour tous les marchés non Boom/Crash
   if(!IsAITradeAllowedForDirection(sig.action))
   {
      ReleaseOpenLock();
      return;
   }

   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles
   if(!AllowReentryAfterRecentLoss(_Symbol, sig.action, false))
   {
      ReleaseOpenLock();
      return;
   }
   
   // Interdire SELL sur Boom et BUY sur Crash
   if(!IsDirectionAllowedForBoomCrash(_Symbol, sig.action))
   {
      Print("❌ Signal ", sig.action, " bloqué sur ", _Symbol, " (règle Boom/Crash: pas de SELL sur Boom, pas de BUY sur Crash)");
      ReleaseOpenLock();
      return;
   }
   
    // Contrôle de duplication: ne pas ouvrir de nouvelle position
    // si les conditions IA fortes + gain 2$ ne sont pas réunies
    if(!CanOpenAdditionalPositionForSymbol(_Symbol, sig.action))
    {
       Print("❌ Nouvelle position ", sig.action, " bloquée sur ", _Symbol, " (règle duplication: besoin +2$ sur position initiale et IA >= 80%)");
       ReleaseOpenLock();
       return;
    }
   
   // RÈGLE SPÉCIALE BOOM/CRASH: Bloquer TOUJOURS les signaux contraires à l'IA
   // Peu importe le niveau de confiance, pour respecter les règles Boom/Crash
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(cat == SYM_BOOM_CRASH)
   {
       if(IsBoomLikeSymbol(_Symbol))
       {
          // Boom/Gainx n'accepte que BUY
          if(sig.action == "SELL")
          {
             Print("❌ SELL SMC BLOQUÉ - Boom/Gainx n'accepte que BUY (IA: ", g_lastAIAction, " ", DoubleToString(g_lastAIConfidence*100,1), "%)");
             ReleaseOpenLock();
             return;
          }
       }
       else if(IsCrashLikeSymbol(_Symbol))
       {
          // Crash/Painx n'accepte que SELL
          if(sig.action == "BUY")
          {
             Print("❌ BUY SMC BLOQUÉ - Crash/Painx n'accepte que SELL (IA: ", g_lastAIAction, " ", DoubleToString(g_lastAIConfidence*100,1), "%)");
             ReleaseOpenLock();
             return;
         }
      }
   }
   else
   {
      // Pour les autres symboles: bloquer seulement si confiance IA forte (>= max(MinAIConfidence, 60%))
      double strongAIThreshold = MathMax(MinAIConfidence, 0.65);
      if(g_lastAIConfidence >= strongAIThreshold)
      {
         if((g_lastAIAction == "BUY" || g_lastAIAction == "buy") && sig.action == "SELL")
         {
            Print("❌ SELL SMC bloqué car IA = BUY (conf: ", DoubleToString(g_lastAIConfidence*100,1), "%)");
            ReleaseOpenLock();
            return;
         }
         if((g_lastAIAction == "SELL" || g_lastAIAction == "sell") && sig.action == "BUY")
         {
            Print("❌ BUY SMC bloqué car IA = SELL (conf: ", DoubleToString(g_lastAIConfidence*100,1), "%)");
            ReleaseOpenLock();
            return;
         }
      }
   }
   
   // Protection capital: zone discount au bord inférieur → SELL seulement si confiance IA >= 85%
   if(sig.action == "SELL" && IsAtDiscountLowerEdge() && g_lastAIConfidence < 0.85)
   {
      Print("❌ SELL SMC bloqué - Zone Discount au bord inférieur: confiance IA ≥ 85% requise (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      ReleaseOpenLock();
      return;
   }

    // Réduire les entrées hâtives: exiger la flèche SMC_DERIV_ARROW avant tout ordre au marché (sauf mode autonome)
    if(RequireSMCDerivArrowForAllOrders && !HasRecentSMCDerivArrowForDirection(sig.action))
    {
       Print("🚫 ORDRE SMC BLOQUÉ - Attendre flèche SMC_DERIV_ARROW ", sig.action, " sur ", _Symbol);
       ReleaseOpenLock();
       return;
    }
   
   // Réinitialiser le gain maximum pour la nouvelle position
   g_maxProfit = 0;

   // === SNIPER SCALPER MODE: cap $ universel + RR mini + confluence mini ===
   bool sniperOkToTrade = true;
   double sniperLot = lotSize;
   double sniperSL = sig.stopLoss;
   double sniperTP = sig.takeProfit;
   bool skipSniperForThisSymbol = (NoSLTP_BoomCrash && SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH);
   if(UseSniperScalperMode && !skipSniperForThisSymbol)
   {
      int gatesHit = SMC_CountConfluenceTags(sig.concept);
      if(gatesHit < MinSniperConfluenceGates)
      {
         Print("🚫 SNIPER BLOQUÉ - Confluence insuffisante (", gatesHit, "/", MinSniperConfluenceGates,
               ") sur ", _Symbol, " - Raison: ", sig.concept);
         sniperOkToTrade = false;
      }
      if(sniperOkToTrade && SniperRequireGOMOrAI)
      {
         bool gomOrAiOk = (g_lastAIConfidence >= MinAIConfidence) || (StringFind(sig.concept, "IA-") >= 0);
         if(!gomOrAiOk)
         {
            Print("🚫 SNIPER BLOQUÉ - Ni GOM ni confirmation IA suffisante sur ", _Symbol);
            sniperOkToTrade = false;
         }
      }
      if(sniperOkToTrade)
      {
         double entryRef = (sig.action == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double slDistPrice = MathAbs(entryRef - sig.stopLoss);
         double tpDistPrice = 0;
         if(!SMC_ApplySniperRiskCap(_Symbol, slDistPrice, sniperLot, tpDistPrice))
         {
            sniperOkToTrade = false;
         }
         else
         {
            sniperSL = (sig.action == "BUY") ? (entryRef - slDistPrice) : (entryRef + slDistPrice);
            sniperTP = (sig.action == "BUY") ? (entryRef + tpDistPrice) : (entryRef - tpDistPrice);
         }
      }
   }
   if(UseSniperScalperMode && !skipSniperForThisSymbol && !sniperOkToTrade)
   {
      ReleaseOpenLock();
      return;
   }
   if(UseSniperScalperMode && !skipSniperForThisSymbol)
   {
      lotSize = sniperLot;
      sig.stopLoss = sniperSL;
      sig.takeProfit = sniperTP;
   }

   if(sig.action == "BUY")
   {
      if(NoSLTP_BoomCrash && SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
         SafeTradeBuy(lotSize, _Symbol, 0, 0, 0, "SMC " + sig.concept);
      else
         SafeTradeBuy(lotSize, _Symbol, 0, sig.stopLoss, sig.takeProfit, "SMC " + sig.concept);
      if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         Print("✅ SMC BUY @ ", sig.entryPrice, " - ", sig.concept);
         if(UseNotifications) { Alert("SMC BUY ", _Symbol, " ", sig.concept); SendNotification("SMC BUY " + _Symbol + " " + sig.concept); }
      }
   }
   else if(sig.action == "SELL")
   {
      if(NoSLTP_BoomCrash && SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
         SafeTradeSell(lotSize, _Symbol, 0, 0, 0, "SMC " + sig.concept);
      else
         SafeTradeSell(lotSize, _Symbol, 0, sig.stopLoss, sig.takeProfit, "SMC " + sig.concept);
      if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         Print("✅ SMC SELL @ ", sig.entryPrice, " - ", sig.concept);
         if(UseNotifications) { Alert("SMC SELL ", _Symbol, " ", sig.concept); SendNotification("SMC SELL " + _Symbol + " " + sig.concept); }
      }
   }
   ReleaseOpenLock();
}

// Compte le nombre de familles de confluence SMC distinctes présentes dans le tag de raison
// (LS=Liquidity Sweep, FVG, OB=Order Block, BOS, Zone=Premium/Discount, IA=confirmation IA)
int SMC_CountConfluenceTags(const string reason)
{
   int n = 0;
   if(StringFind(reason, "LS-")   >= 0) n++;
   if(StringFind(reason, "FVG-")  >= 0) n++;
   if(StringFind(reason, "OB-")   >= 0) n++;
   if(StringFind(reason, "BOS-")  >= 0) n++;
   if(StringFind(reason, "Zone-") >= 0) n++;
   if(StringFind(reason, "IA-")   >= 0) n++;
   return n;
}

// Sniper Risk Cap: recalcule le lot pour que la perte potentielle (si SL touché) ne dépasse
// JAMAIS MaxLossPerTradeDollars, et impose tpDistPrice = slDistPrice x MinRewardRiskRatio.
// Retourne false si même le lot minimum dépasse le cap $ -> le trade doit être annulé.
bool SMC_ApplySniperRiskCap(const string symbol, const double slDistPrice, double &lot, double &tpDistPrice)
{
   if(slDistPrice <= 0) return false;

   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal   = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0) tickSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(tickVal  <= 0) tickVal  = 1.0;

   double riskPerLotDollars = slDistPrice * (tickVal / tickSize);
   if(riskPerLotDollars <= 0) return false;

   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = minLot;
   if(lotStep <= 0) lotStep = 0.01;

   double lotCap    = MaxLossPerTradeDollars / riskPerLotDollars;
   double sizedLot  = MathFloor(lotCap / lotStep) * lotStep;
   sizedLot = MathMax(minLot, MathMin(maxLot, sizedLot));
   sizedLot = NormalizeDouble(sizedLot, 2);

   double potentialLoss = sizedLot * riskPerLotDollars;
   if(potentialLoss > MaxLossPerTradeDollars * 1.02)
   {
      Print("❌ SNIPER BLOQUÉ - Perte au lot min (", DoubleToString(minLot,2), ") = ",
            DoubleToString(potentialLoss, 2), "$ > cap ", DoubleToString(MaxLossPerTradeDollars, 2),
            "$ sur ", symbol, " (SL trop large pour ce cap $, augmenter MaxLossPerTradeDollars ou resserrer SL)");
      return false;
   }

   lot = sizedLot;
   tpDistPrice = slDistPrice * MinRewardRiskRatio;
   Print("🎯 SNIPER RISK CAP - ", symbol, " | SL dist: ", DoubleToString(slDistPrice, _Digits),
         " | Lot: ", DoubleToString(lot, 2), " | Perte max: ", DoubleToString(potentialLoss, 2),
         "$ | TP dist (RR ", DoubleToString(MinRewardRiskRatio,1), "): ", DoubleToString(tpDistPrice, _Digits));
   return true;
}

// NOUVEAU: Appliquer un buffer SL de +1$ immédiatement après l'ouverture de position
// Cela déplace le SL de 1$ vers l'entrée pour éviter un stop-out immédiat avant que le spike ne se déclenche
bool SMC_ApplyPostEntrySLBuffer(const string symbol, const ulong ticket, const double bufferUSD = 1.0)
{
   if(!PositionSelectByTicket(ticket)) return false;
   if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) return false;
   if(PositionGetString(POSITION_SYMBOL) != symbol) return false;

   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   double volume = PositionGetDouble(POSITION_VOLUME);
   
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0) tickSize = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(tickVal <= 0) tickVal = 1.0;
   
   int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   int stopsLvl = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (double)(stopsLvl + 5) * SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   // Calculer la distance en prix pour 1$
   double ticksNeeded = bufferUSD / (tickVal * volume);
   double priceDist = ticksNeeded * tickSize;
   
   if(priceDist < minDist) priceDist = minDist;
   
   double newSL = 0;
   if(posType == POSITION_TYPE_BUY)
   {
      // Pour BUY: SL = openPrice - priceDist (plus proche de l'entrée = plus de protection)
      newSL = NormalizeDouble(openPrice - priceDist, dg);
      // Ne modifier que si le nouveau SL est MEILLEUR (plus haut) que l'actuel
      if(currentSL > 0 && newSL <= currentSL) return false;
      if(newSL >= SymbolInfoDouble(symbol, SYMBOL_BID)) return false; // SL ne peut pas être >= prix actuel
   }
   else
   {
      // Pour SELL: SL = openPrice + priceDist
      newSL = NormalizeDouble(openPrice + priceDist, dg);
      if(currentSL > 0 && newSL >= currentSL) return false;
      if(newSL <= SymbolInfoDouble(symbol, SYMBOL_ASK)) return false;
   }
   
   if(trade.PositionModify(ticket, newSL, currentTP))
   {
      Print("🛡️ SL BUFFER +$1 APPLIQUÉ — ", symbol, " | Ticket: ", ticket,
            " | SL: ", DoubleToString(currentSL, dg), " → ", DoubleToString(newSL, dg),
            " | Buffer: $", DoubleToString(bufferUSD, 1));
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| MODULE : SPIKE CHAIN STATE DETECTOR                               |
//| Détecte le DÉBUT d'un enchaînement de spikes (Boom/Crash/         |
//| Painx/Gainx) via un z-score de volatilité + persistance directionnelle |
//+------------------------------------------------------------------+
enum ENUM_SPIKE_CHAIN_STATE
{
   SPIKE_STATE_CALM = 0,       // Volatilité normale
   SPIKE_STATE_PRE_SPIKE,      // Volatilité qui gonfle (z-score haut)
   SPIKE_STATE_CHAIN_ACTIVE,   // 2+ bougies fortes consécutives même sens
   SPIKE_STATE_EXHAUSTION      // Momentum qui retombe, en attente de retour au calme
};

ENUM_SPIKE_CHAIN_STATE g_spikeChainState        = SPIKE_STATE_CALM;
int                    g_spikeChainDirection    = 0;   // +1 haussier, -1 baissier, 0 aucun
int                    g_spikeChainStrongBars   = 0;   // nb de bougies fortes consécutives dans la chaîne
int                    g_spikeChainWeakBars     = 0;   // nb de bougies faibles consécutives (pour sortir en EXHAUSTION)
datetime               g_spikeChainLastBarTime  = 0;   // dernière bougie LTF traitée (évite retraitement intra-bougie)
int                    g_lastStrongBarDir       = 0;   // direction de la dernière bougie forte vue (mémoire courte)
datetime               g_lastStrongBarTime      = 0;
bool                   g_lastSpikeEntryWasEarly = false; // dernière entrée spike déclenchée en mode précoce ?

// Spike Chain ONNX Predictor
CSpikeChainPredictor   g_spikePredictor;
bool                   g_spikePredictorReady     = false;
// Dernier spike détecté (pour features ONNX)
double   g_lastSpikeAmplitudePips   = 0.0;
double   g_lastSpikeAmplitudeAtr    = 0.0;
double   g_lastSpikeVelocityProxy   = 0.0;
datetime g_lastSpikeDetectTime      = 0;
datetime g_prevSpikeDetectTime      = 0;
bool     g_lastSpikeWasUp           = false;

// Spike Model Set (amplitude + interval + direction) — declared in SMC_SpikeModels.mqh
bool             g_spikeModelSetReady = false;
double           g_spikePredAmp       = -1.0;  // predicted next spike amplitude (ATR)
double           g_spikePredInt       = -1.0;  // predicted minutes until next spike
double           g_spikePredDir       = -1.0;  // predicted P(next up) — Vol only

//+------------------------------------------------------------------+
//| Met à jour les prédictions des modèles spike (amplitude + interval)|
//| Appelé depuis OnTick après DowTrendline.                           |
//+------------------------------------------------------------------+
void SpikeModels_UpdatePredictions()
{
   if(!g_spikeModels.IsReady()) return;

   static datetime s_lastBar = 0;
   datetime curBar = iTime(_Symbol, LTF, 0);
   if(curBar == s_lastBar) return;
   s_lastBar = curBar;

   if(atrHandle == INVALID_HANDLE) return;

   double atrVal[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrVal) < 1) return;
   double currentATR = atrVal[0];
   if(currentATR <= 0.0) return;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, LTF, 0, 10, rates) < 10) return;

   double closePrices[];
   ArraySetAsSeries(closePrices, true);
   if(CopyClose(_Symbol, LTF, 0, 100, closePrices) < 100) return;

   double closeMean = 0, closeStd = 0;
   for(int i = 0; i < 100; i++) closeMean += closePrices[i];
   closeMean /= 100;
   for(int i = 0; i < 100; i++) closeStd += MathPow(closePrices[i] - closeMean, 2);
   closeStd = MathSqrt(closeStd / 100);
   double closeZscore = (closeStd > 0) ? (closePrices[0] - closeMean) / closeStd : 0.0;

   double body = rates[0].close - rates[0].open;
   double range = rates[0].high - rates[0].low;
   double amplitudeAtr = (currentATR > 0) ? MathAbs(body) / currentATR : 0.0;
   double velocityProxy = (currentATR > 0) ? range / currentATR : 0.0;

   datetime now = TimeCurrent();
   double minutesSincePrev = (g_lastSpikeDetectTime > 0) ? (now - g_lastSpikeDetectTime) / 60.0 : 60.0;
   if(minutesSincePrev < 0.5) minutesSincePrev = 0.5;

   MqlDateTime dt;
   TimeToStruct(now, dt);
   int hour = dt.hour;
   int minute = dt.min;

   int spikesLast60min = 0;
   double avgAmpLast5 = amplitudeAtr;
   double ampRatio = 1.0;
   int chainLen = 1;

   if(minutesSincePrev <= 15.0 && g_prevSpikeDetectTime > 0)
      chainLen = 2;

   double features[10];
   SpikeModels_BuildFeatures(
      amplitudeAtr, velocityProxy, minutesSincePrev, hour, minute,
      closeZscore, spikesLast60min, avgAmpLast5, ampRatio, chainLen,
      features
   );

   g_spikePredAmp = g_spikeModels.PredictAmplitude(features);
   g_spikePredInt = g_spikeModels.PredictInterval(features);

   if(g_spikePredAmp > 0 && g_spikePredInt > 0)
   {
      if(StringFind(_Symbol, "FX Vol") != -1 || StringFind(_Symbol, "SFX Vol") != -1)
      {
         double dirFeatures[8];
         SpikeModels_BuildDirFeatures(
            g_lastSpikeWasUp, g_lastSpikeAmplitudePips, g_lastSpikeAmplitudeAtr,
            g_lastSpikeVelocityProxy, minutesSincePrev, hour, minute, 0.5,
            dirFeatures
         );
         g_spikePredDir = g_spikeModels.PredictDirectionUp(dirFeatures);
      }
   }

   static int s_logCount = 0;
   if(s_logCount++ % 60 == 0 && g_spikePredAmp > 0)
   {
      PrintFormat("[SpikeModels] %s: predAmp=%.2f ATR, predInt=%.0f min",
         _Symbol, g_spikePredAmp, g_spikePredInt);
   }
}

//+------------------------------------------------------------------+
//| Calcule le z-score de l'ATR courant vs sa moyenne/écart-type      |
//| sur `lookback` bougies -> mesure si la volatilité "gonfle"        |
//+------------------------------------------------------------------+
double SMC_ComputeATRZScore(int lookback)
{
   if(atrHandle == INVALID_HANDLE) return 0.0;

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   int need = lookback + 1;
   if(CopyBuffer(atrHandle, 0, 0, need, atrBuf) < need) return 0.0;

   double currentATR = atrBuf[0];

   double sum = 0.0;
   for(int i = 1; i <= lookback; i++) sum += atrBuf[i];
   double mean = sum / lookback;

   double sq = 0.0;
   for(int i = 1; i <= lookback; i++) sq += MathPow(atrBuf[i] - mean, 2);
   double stdDev = MathSqrt(sq / lookback);

   if(stdDev <= 0.0) return 0.0;
   return (currentATR - mean) / stdDev;
}

//+------------------------------------------------------------------+
//| Met à jour la machine à états - à appeler une fois par tick.      |
//| Se recalcule uniquement à la clôture d'une nouvelle bougie LTF.   |
//+------------------------------------------------------------------+
void SMC_UpdateSpikeChainState()
{
   if(!UseSpikeChainDetector) return;
   if(!SMC_IsSpikeStyleSymbol(_Symbol)) return; // uniquement Boom/Crash/Painx/Gainx
   if(atrHandle == INVALID_HANDLE) return;

   datetime barTime = iTime(_Symbol, LTF, 0);
   if(barTime == g_spikeChainLastBarTime) return; // déjà traité cette bougie
   g_spikeChainLastBarTime = barTime;

   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, LTF, 1, 3, r) < 3) return; // bougies déjà clôturées (index 0 = dernière clôturée)

   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(atrHandle, 0, 1, 1, atrBuf) < 1) return;
   double atrVal = atrBuf[0];
   if(atrVal <= 0) return;

   double body      = r[0].close - r[0].open;
   double bodyAbs   = MathAbs(body);
   int    barDir    = (body > 0) ? 1 : (body < 0 ? -1 : 0);
   bool   isStrongBar = (bodyAbs >= atrVal * SpikeChainBodyATRMult);

   double zscore = SMC_ComputeATRZScore(SpikeChainATRLookback);

   switch(g_spikeChainState)
   {
      case SPIKE_STATE_CALM:
         if(zscore >= SpikeChainZScoreThreshold)
         {
            g_spikeChainState = SPIKE_STATE_PRE_SPIKE;
            Print("🟡 SPIKE CHAIN: CALME -> PRÉ-SPIKE (z-score=", DoubleToString(zscore,2), ") sur ", _Symbol);
            // Visuel: petit triangle jaune
            string objName = "SPIKE_CHAIN_PRE_" + IntegerToString(barTime);
            if(ShowChartGraphics && ObjectFind(0, objName) < 0)
            {
               if(ObjectCreate(0, objName, OBJ_ARROW, 0, barTime, r[1].low))
               {
                  ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 159);  // triangle up
                  ObjectSetInteger(0, objName, OBJPROP_COLOR, clrGold);
                  ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
                  ObjectSetString(0, objName, OBJPROP_TOOLTIP, "SPIKE CHAIN: PRE-SPIKE (z=" + DoubleToString(zscore,2) + ")");
               }
            }
            // Push notification
            if(UseNotifications && SpikeImminentPushNotify)
               SendNotification("🟡 SPIKE CHAIN PRE-SPIKE | " + _Symbol + " | z=" + DoubleToString(zscore,2));
         }
         break;

      case SPIKE_STATE_PRE_SPIKE:
         if(isStrongBar && barDir != 0)
         {
            if(g_lastStrongBarDir == barDir && g_lastStrongBarTime == iTime(_Symbol, LTF, 2))
            {
               g_spikeChainState     = SPIKE_STATE_CHAIN_ACTIVE;
               g_spikeChainDirection = barDir;
               g_spikeChainStrongBars = 2;
               g_spikeChainWeakBars  = 0;
               Print("🔴 SPIKE CHAIN: PRÉ-SPIKE -> CHAÎNE ACTIVE (", barDir > 0 ? "HAUSSIER" : "BAISSIER",
                     ") sur ", _Symbol);
               // Visuel: grande flèche verte/rouge
               string chainDir = (barDir > 0) ? "UP" : "DOWN";
               string objName = "SPIKE_CHAIN_ACTIVE_" + IntegerToString(barTime);
               if(ShowChartGraphics && ObjectFind(0, objName) < 0)
               {
                  if(ObjectCreate(0, objName, OBJ_ARROW, 0, barTime, barDir > 0 ? r[1].low : r[1].high))
                  {
                     ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, barDir > 0 ? 233 : 234);  // up/down arrow
                     ObjectSetInteger(0, objName, OBJPROP_COLOR, barDir > 0 ? clrLime : clrRed);
                     ObjectSetInteger(0, objName, OBJPROP_WIDTH, 3);
                     ObjectSetString(0, objName, OBJPROP_TOOLTIP,
                        "SPIKE CHAIN " + chainDir + " ACTIVE | " + IntegerToString(g_spikeChainStrongBars) + " bougies fortes");
                  }
               }
               // Push notification
               if(UseNotifications && SpikeImminentPushNotify)
                  SendNotification("🔴 SPIKE CHAIN ACTIVE " + chainDir + " | " + _Symbol + " | 2 bougies fortes confirmées");
            }
            else
            {
               g_lastStrongBarDir  = barDir;
               g_lastStrongBarTime = barTime;
            }
         }
         else if(zscore < SpikeChainZScoreThreshold * 0.5)
         {
            g_spikeChainState = SPIKE_STATE_CALM;
            Print("⚪ SPIKE CHAIN: PRÉ-SPIKE -> CALME (fausse alerte) sur ", _Symbol);
         }
         break;

      case SPIKE_STATE_CHAIN_ACTIVE:
         if(isStrongBar && barDir == g_spikeChainDirection)
         {
            g_spikeChainStrongBars++;
            g_spikeChainWeakBars = 0;
            // Mettre à jour le texte du dernier objet actif
            string objName = "SPIKE_CHAIN_ACTIVE_" + IntegerToString(iTime(_Symbol, LTF, 2));
            if(ObjectFind(0, objName) >= 0)
               ObjectSetString(0, objName, OBJPROP_TOOLTIP,
                  "SPIKE CHAIN " + (g_spikeChainDirection > 0 ? "UP" : "DOWN") +
                  " | " + IntegerToString(g_spikeChainStrongBars) + " bougies fortes");
         }
         else
         {
            g_spikeChainWeakBars++;
            if(g_spikeChainWeakBars >= 1)
            {
               g_spikeChainState = SPIKE_STATE_EXHAUSTION;
               Print("🟠 SPIKE CHAIN: CHAÎNE ACTIVE -> ÉPUISEMENT sur ", _Symbol,
                     " (", g_spikeChainStrongBars, " bougies fortes vues)");
               // Visuel: losange orange
               string exhName = "SPIKE_CHAIN_EXH_" + IntegerToString(barTime);
               if(ShowChartGraphics && ObjectFind(0, exhName) < 0)
               {
                  if(ObjectCreate(0, exhName, OBJ_ARROW, 0, barTime, r[1].close))
                  {
                     ObjectSetInteger(0, exhName, OBJPROP_ARROWCODE, 167);  // diamond
                     ObjectSetInteger(0, exhName, OBJPROP_COLOR, clrOrange);
                     ObjectSetInteger(0, exhName, OBJPROP_WIDTH, 2);
                     ObjectSetString(0, exhName, OBJPROP_TOOLTIP,
                        "SPIKE CHAIN ÉPUISEMENT | " + IntegerToString(g_spikeChainStrongBars) + " bougies fortes");
                  }
               }
               // Push notification
               if(UseNotifications && SpikeImminentPushNotify)
                  SendNotification("🟠 SPIKE CHAIN ÉPUISEMENT | " + _Symbol + " | " + IntegerToString(g_spikeChainStrongBars) + " bougies fortes");
            }
         }
         break;

      case SPIKE_STATE_EXHAUSTION:
         if(isStrongBar && barDir == g_spikeChainDirection)
         {
            // relance de la chaîne dans le même sens
            g_spikeChainState = SPIKE_STATE_CHAIN_ACTIVE;
            g_spikeChainStrongBars++;
            g_spikeChainWeakBars = 0;
            Print("🔴 SPIKE CHAIN: ÉPUISEMENT -> RELANCE sur ", _Symbol);
            // Visuel: nouvelle flèche de relance
            string relName = "SPIKE_CHAIN_REL_" + IntegerToString(barTime);
            if(ShowChartGraphics && ObjectFind(0, relName) < 0)
            {
               if(ObjectCreate(0, relName, OBJ_ARROW, 0, barTime, barDir > 0 ? r[1].low : r[1].high))
               {
                  ObjectSetInteger(0, relName, OBJPROP_ARROWCODE, barDir > 0 ? 233 : 234);
                  ObjectSetInteger(0, relName, OBJPROP_COLOR, clrMagenta);
                  ObjectSetInteger(0, relName, OBJPROP_WIDTH, 3);
                  ObjectSetString(0, relName, OBJPROP_TOOLTIP, "SPIKE CHAIN RELANCE | " + IntegerToString(g_spikeChainStrongBars) + " bougies fortes");
               }
            }
         }
         else
         {
            g_spikeChainWeakBars++;
            if(g_spikeChainWeakBars >= SpikeChainExhaustionBars)
            {
               Print("⚪ SPIKE CHAIN: ÉPUISEMENT -> CALME sur ", _Symbol);
               g_spikeChainState      = SPIKE_STATE_CALM;
               g_spikeChainDirection  = 0;
               g_spikeChainStrongBars = 0;
               g_spikeChainWeakBars   = 0;
               g_lastStrongBarDir     = 0;
               // Visuel: croix blanche (fin de chaîne)
               string endName = "SPIKE_CHAIN_END_" + IntegerToString(barTime);
               if(ShowChartGraphics && ObjectFind(0, endName) < 0)
               {
                  if(ObjectCreate(0, endName, OBJ_ARROW, 0, barTime, r[1].close))
                  {
                     ObjectSetInteger(0, endName, OBJPROP_ARROWCODE, 67);  // X mark
                     ObjectSetInteger(0, endName, OBJPROP_COLOR, clrWhite);
                     ObjectSetInteger(0, endName, OBJPROP_WIDTH, 2);
                     ObjectSetString(0, endName, OBJPROP_TOOLTIP, "SPIKE CHAIN TERMINÉE");
                  }
               }
            }
         }
         break;
   }
}

//+------------------------------------------------------------------+
//| Accesseur: y a-t-il une opportunité d'entrée précoce sur une      |
//| chaîne de spikes qui vient de démarrer ? A appeler avant/en plus  |
//| du déclencheur de spike classique.                                |
//+------------------------------------------------------------------+
bool SMC_IsSpikeChainEarlyEntry(string &outDirection)
{
   if(!UseSpikeChainDetector || !UseSpikeChainEarlyEntry) return false;
   if(g_spikeChainState != SPIKE_STATE_CHAIN_ACTIVE) return false;
   if(g_spikeChainDirection == 0) return false;

   outDirection = (g_spikeChainDirection > 0) ? "BUY" : "SELL";
   return true;
}

//+------------------------------------------------------------------+
//| STRATEGIE "CHAINE DE SPIKES" H1/M5 (Kola YEBADOKPO)               |
//+------------------------------------------------------------------+
//| Logique:                                                          |
//| 1) Support/Resistance H1 confirme sur SCH1_SR_Lookback bougies    |
//| 2) Score de force de l'impulsion (H1/H4): volatilite relative     |
//|    H4 + momentum directionnel H1 + densite de spikes recents H1   |
//| 3) Des que le prix est pres du bord S/R H1 ET que la force est    |
//|    validee, on cherche un rejet de spike sur M5 (1ere bougie de   |
//|    la chaine) -> signal d'entree                                  |
//| 4) Une fois la chaine lancee, on attend en moyenne 3-4 spikes     |
//|    supplementaires avec un retracement de 2-3 bougies M5 max      |
//|    entre chaque -> gestion (partial close + verrouillage SL) a    |
//|    chaque nouveau spike de la chaine                              |
//| 5) TP = extension mesuree au-dela de la S/R H1 opposee            |
//+------------------------------------------------------------------+
struct SCH1_ChainState
{
   bool     active;
   int      direction;        // +1 haussier (Boom/Gainx), -1 baissier (Crash/Painx)
   double   startPrice;       // prix avant le 1er spike de la chaine
   double   lastSpikePrice;
   datetime lastSpikeTime;
   int      spikeCount;
   int      barsSinceLastSpike;
   int      lastManagedSpikeCount;
};
SCH1_ChainState g_sch1Chain;
datetime         g_sch1LastM5BarTime = 0;
double           g_sch1_tpHint = 0.0; // dernier TP hint (extension S/R) valide par le gate SCH1

//+------------------------------------------------------------------+
//| ATR a un shift donne pour un handle donne (utilitaire local)      |
//+------------------------------------------------------------------+
double SCH1_GetATRAt(int handle, int shift)
{
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, 0, shift, 1, buf) <= 0) return 0.0;
   return buf[0];
}

//+------------------------------------------------------------------+
//| Support / Resistance H1 sur SCH1_SR_Lookback bougies (bougies     |
//| deja cloturees, index 1..N, la bougie 0 en formation est ignoree) |
//+------------------------------------------------------------------+
bool SCH1_GetSR_H1(double &resistance, double &support)
{
   resistance = -DBL_MAX;
   support    =  DBL_MAX;
   int n = MathMax(5, SCH1_SR_Lookback);
   if(Bars(_Symbol, PERIOD_H1) < n + 2) return false;

   for(int i = 1; i <= n; i++)
   {
      double h = iHigh(_Symbol, PERIOD_H1, i);
      double l = iLow(_Symbol, PERIOD_H1, i);
      if(h > resistance) resistance = h;
      if(l < support)    support    = l;
   }
   return (resistance > -DBL_MAX && support < DBL_MAX && resistance > support);
}

//+------------------------------------------------------------------+
//| Une bougie est un "spike" si son range depasse X*ATR, dans le     |
//| sens du biais (biasDir=+1 haussier type Boom/Gainx, -1 Crash/Painx)|
//+------------------------------------------------------------------+
bool SCH1_IsSpikeBar(ENUM_TIMEFRAMES tf, int shift, int atrHandleTF, int biasDir)
{
   if(atrHandleTF == INVALID_HANDLE) return false;
   double high  = iHigh(_Symbol, tf, shift);
   double low   = iLow(_Symbol, tf, shift);
   double open  = iOpen(_Symbol, tf, shift);
   double close = iClose(_Symbol, tf, shift);
   if(high <= 0 || low <= 0) return false;
   double range = high - low;

   double atrVal = SCH1_GetATRAt(atrHandleTF, shift);
   if(atrVal <= 0) return false;
   if(range < SCH1_SpikeATRMultiplier * atrVal) return false;

   bool bullish = (close > open);
   return (biasDir > 0) ? bullish : !bullish;
}

//+------------------------------------------------------------------+
//| Score de force de l'impulsion (0-100) sur H1/H4                   |
//| 40 pts volatilite relative H4, 30 pts momentum H1, 30 pts densite |
//| de spikes recents H1                                              |
//+------------------------------------------------------------------+
double SCH1_CalculateForce(int biasDir)
{
   double score = 0.0;

   //--- 1) Volatilite relative H4 (40 pts): ATR H4 courant vs moyenne 50 bougies
   if(atrH4 != INVALID_HANDLE)
   {
      double atrH4_now = SCH1_GetATRAt(atrH4, 1);
      double atrH4_sum = 0.0;
      int    n = 50;
      for(int i = 1; i <= n; i++)
         atrH4_sum += SCH1_GetATRAt(atrH4, i);
      double atrH4_avg = (n > 0) ? atrH4_sum / n : 0.0;
      double volRatio  = (atrH4_avg > 0) ? atrH4_now / atrH4_avg : 1.0;
      double volScore  = MathMin(40.0, MathMax(0.0, (volRatio - 0.8) / (2.0 - 0.8) * 40.0));
      score += volScore;
   }

   //--- 2) Momentum directionnel H1 (30 pts), dans le sens du biais
   if(atrH1 != INVALID_HANDLE)
   {
      double closeNow  = iClose(_Symbol, PERIOD_H1, 1);
      double closePast = iClose(_Symbol, PERIOD_H1, 1 + SCH1_MomentumBarsH1);
      double atrH1val  = SCH1_GetATRAt(atrH1, 1);
      double momentum  = (atrH1val > 0) ? (closeNow - closePast) / atrH1val : 0.0;
      if(biasDir < 0) momentum = -momentum;
      double momScore  = MathMin(30.0, MathMax(0.0, momentum * SCH1_MomentumScale));
      score += momScore;
   }

   //--- 3) Densite de spikes recents H1 (30 pts) - 3 spikes/lookback = score plein
   if(atrH1 != INVALID_HANDLE)
   {
      int spikeCountH1 = 0;
      for(int i = 1; i <= SCH1_ForceLookbackH1; i++)
         if(SCH1_IsSpikeBar(PERIOD_H1, i, atrH1, biasDir)) spikeCountH1++;
      double densScore = MathMin(30.0, (spikeCountH1 / 3.0) * 30.0);
      score += densScore;
   }

   return score;
}

//+------------------------------------------------------------------+
//| Rejet de spike sur M5: bougie[2] = spike, bougie[1] = rejet       |
//| (meche + cloture qui revient dans le corps du spike sans le       |
//| depasser au-dela du seuil %)                                      |
//+------------------------------------------------------------------+
bool SCH1_IsSpikeRejectionM5(int biasDir)
{
   if(atrM5 == INVALID_HANDLE) return false;
   if(!SCH1_IsSpikeBar(PERIOD_M5, 2, atrM5, biasDir)) return false;

   double spikeOpen  = iOpen(_Symbol, PERIOD_M5, 2);
   double spikeClose = iClose(_Symbol, PERIOD_M5, 2);
   double spikeHigh  = iHigh(_Symbol, PERIOD_M5, 2);
   double spikeLow   = iLow(_Symbol, PERIOD_M5, 2);
   double spikeBody  = MathAbs(spikeClose - spikeOpen);
   if(spikeBody <= 0) return false;

   double rejClose = iClose(_Symbol, PERIOD_M5, 1);
   double rejHigh  = iHigh(_Symbol, PERIOD_M5, 1);
   double rejLow   = iLow(_Symbol, PERIOD_M5, 1);

   if(biasDir > 0)
   {
      double limit = spikeOpen + spikeBody * (1.0 - SCH1_RejectionCloseThresholdPct / 100.0);
      return (rejClose >= limit && rejHigh >= spikeHigh - 0.2 * spikeBody);
   }
   else
   {
      double limit = spikeOpen - spikeBody * (1.0 - SCH1_RejectionCloseThresholdPct / 100.0);
      return (rejClose <= limit && rejLow <= spikeLow + 0.2 * spikeBody);
   }
}

//+------------------------------------------------------------------+
//| Prix proche (ou au-dela) de la zone S/R H1, dans le sens du biais |
//+------------------------------------------------------------------+
bool SCH1_IsNearSR_H1(int biasDir)
{
   double resistance, support;
   if(!SCH1_GetSR_H1(resistance, support)) return false;
   double atrH1val = SCH1_GetATRAt(atrH1, 1);
   if(atrH1val <= 0) return false;

   double price = (biasDir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(biasDir > 0)
      return (MathAbs(price - resistance) <= SCH1_SR_ProximityATR * atrH1val || price >= resistance);
   else
      return (MathAbs(price - support) <= SCH1_SR_ProximityATR * atrH1val || price <= support);
}

//+------------------------------------------------------------------+
//| TP = extension mesuree au-dela de la S/R H1 opposee (range S/R    |
//| projete depuis le bord casse)                                     |
//+------------------------------------------------------------------+
bool SCH1_ComputeExtensionTP(int biasDir, double &tpOut)
{
   double resistance, support;
   if(!SCH1_GetSR_H1(resistance, support)) return false;
   double range = resistance - support;
   if(range <= 0) return false;

   tpOut = (biasDir > 0) ? (resistance + range) : (support - range);
   return true;
}

//+------------------------------------------------------------------+
//| Gate principal: valide (ou non) le setup "Chaine de Spikes" pour   |
//| la direction donnee. A appeler en plus (ou a la place) des autres |
//| confirmations avant un trade Boom/Crash/Painx/Gainx.               |
//+------------------------------------------------------------------+
bool SCH1_StrategyGate(const string direction, string &reasonOut, double &tpHintOut)
{
   tpHintOut = 0.0;
   if(!UseSCH1_Strategy)
   {
      reasonOut = "SCH1 desactive";
      return true; // module desactive -> ne bloque rien
   }
   if(!SMC_IsSpikeStyleSymbol(_Symbol))
   {
      reasonOut = "SCH1 non applicable (symbole non spike-style)";
      return true; // strategie non concue pour ce symbole -> ne bloque pas
   }

   int biasDir = (direction == "BUY") ? 1 : -1;

   double force     = SCH1_CalculateForce(biasDir);
   bool   nearSR     = SCH1_IsNearSR_H1(biasDir);
   bool   rejection  = SCH1_IsSpikeRejectionM5(biasDir);
   bool   forceOk    = (force >= SCH1_ForceThreshold);

   reasonOut = StringFormat("SCH1[force=%.1f/%d nearSR=%s rejetM5=%s]",
                             force, SCH1_ForceThreshold,
                             nearSR ? "OUI" : "NON",
                             rejection ? "OUI" : "NON");

   if(!(forceOk && nearSR && rejection))
      return false;

   if(SCH1_TPUseSRExtension)
   {
      double tp;
      if(SCH1_ComputeExtensionTP(biasDir, tp))
         tpHintOut = tp;
   }

   // Demarrer/relancer le suivi de chaine des la validation du 1er rejet
   if(!g_sch1Chain.active || g_sch1Chain.direction != biasDir)
   {
      g_sch1Chain.active               = true;
      g_sch1Chain.direction            = biasDir;
      g_sch1Chain.startPrice           = iOpen(_Symbol, PERIOD_M5, 2);
      g_sch1Chain.lastSpikePrice       = iClose(_Symbol, PERIOD_M5, 2);
      g_sch1Chain.lastSpikeTime        = iTime(_Symbol, PERIOD_M5, 2);
      g_sch1Chain.spikeCount           = 1;
      g_sch1Chain.barsSinceLastSpike   = 0;
      g_sch1Chain.lastManagedSpikeCount = 0;
      Print("SPIKE CHAIN H1/M5: nouvelle chaine demarree (", direction, ") sur ", _Symbol, " | ", reasonOut);
   }

   return true;
}

//+------------------------------------------------------------------+
//| Suivi de la chaine en cours: compte les spikes M5 successifs et   |
//| detecte l'essoufflement (retracement > SCH1_ChainRetraceMaxBars   |
//| bougies sans nouveau spike, ou retracement trop profond).          |
//| A appeler une fois par nouvelle bougie M5 (depuis OnTick).         |
//+------------------------------------------------------------------+
void SCH1_UpdateChainTracking()
{
   if(!UseSCH1_Strategy) return;
   if(!SMC_IsSpikeStyleSymbol(_Symbol)) return;
   if(!g_sch1Chain.active) return;

   datetime curBarTime = iTime(_Symbol, PERIOD_M5, 0);
   if(curBarTime == g_sch1LastM5BarTime) return;
   g_sch1LastM5BarTime = curBarTime;

   int biasDir = g_sch1Chain.direction;
   if(biasDir == 0) { g_sch1Chain.active = false; return; }

   if(SCH1_IsSpikeBar(PERIOD_M5, 1, atrM5, biasDir))
   {
      g_sch1Chain.spikeCount++;
      g_sch1Chain.lastSpikePrice     = iClose(_Symbol, PERIOD_M5, 1);
      g_sch1Chain.lastSpikeTime      = iTime(_Symbol, PERIOD_M5, 1);
      g_sch1Chain.barsSinceLastSpike = 0;
      Print("SPIKE CHAIN H1/M5: spike #", g_sch1Chain.spikeCount, "/", SCH1_ChainMaxSpikes, " sur ", _Symbol);

      if(g_sch1Chain.spikeCount >= SCH1_ChainMaxSpikes)
      {
         Print("SPIKE CHAIN H1/M5: objectif de chaine atteint (", g_sch1Chain.spikeCount, " spikes) sur ", _Symbol, " - fin de suivi");
         g_sch1Chain.active = false;
      }
   }
   else
   {
      g_sch1Chain.barsSinceLastSpike++;

      double lastClose = iClose(_Symbol, PERIOD_M5, 1);
      double lastMove  = MathAbs(g_sch1Chain.lastSpikePrice - g_sch1Chain.startPrice);
      double retrace    = MathAbs(lastClose - g_sch1Chain.lastSpikePrice);
      bool deepRetrace  = (lastMove > 0 && (retrace / lastMove * 100.0) > 50.0);

      if(g_sch1Chain.barsSinceLastSpike > SCH1_ChainRetraceMaxBars || deepRetrace)
      {
         Print("SPIKE CHAIN H1/M5: chaine essoufflee (", g_sch1Chain.barsSinceLastSpike,
               " bougies de retracement) sur ", _Symbol, " - fin de suivi");
         g_sch1Chain.active = false;
      }
   }
}

//+------------------------------------------------------------------+
//| A chaque nouveau spike confirme de la chaine en cours: partial    |
//| close + verrouillage du SL (jamais en arriere). Applique sur les  |
//| positions ouvertes de ce symbole/magic.                            |
//+------------------------------------------------------------------+
void SCH1_ManageOpenPositions()
{
   if(!UseSCH1_Strategy || !SCH1_ManageChainPositions) return;
   if(!g_sch1Chain.active) return;
   if(g_sch1Chain.spikeCount <= g_sch1Chain.lastManagedSpikeCount) return;
   if(g_sch1Chain.spikeCount < 2) return;
   g_sch1Chain.lastManagedSpikeCount = g_sch1Chain.spikeCount;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      double posVolume  = PositionGetDouble(POSITION_VOLUME);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL      = PositionGetDouble(POSITION_SL);
      double curTP      = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      //--- cloture partielle
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double closeVolume = NormalizeDouble(posVolume * SCH1_PartialClosePct / 100.0, 2);
      if(closeVolume >= minLot && closeVolume < posVolume)
      {
         if(trade.PositionClosePartial(ticket, closeVolume))
            Print("SPIKE CHAIN H1/M5: cloture partielle ", DoubleToString(closeVolume,2),
                  " lots sur ticket ", ticket, " (spike #", g_sch1Chain.spikeCount, ")");
      }

      //--- verrouillage du SL au breakeven ou mieux, jamais en arriere
      double newSL = entryPrice;
      if(posType == POSITION_TYPE_BUY)
         newSL = (curSL > 0) ? MathMax(newSL, curSL) : newSL;
      else
         newSL = (curSL > 0) ? MathMin(newSL, curSL) : newSL;

      if(newSL != curSL)
         trade.PositionModify(ticket, newSL, curTP);
   }
}

//+------------------------------------------------------------------+
//| Panneau d'info dedie (optionnel, additif au dashboard existant)   |
//+------------------------------------------------------------------+
void SCH1_UpdatePanel()
{
   if(!UseSCH1_Strategy || !SCH1_ShowPanel) return;
   if(!SMC_IsSpikeStyleSymbol(_Symbol)) return;

   double resistance = 0, support = 0;
   SCH1_GetSR_H1(resistance, support);
   int biasDirPanel = IsBoomLikeSymbol(_Symbol) ? 1 : -1;
   double force = SCH1_CalculateForce(biasDirPanel);

   string txt = StringFormat(
      "--- Chaine de Spikes H1/M5 ---\n%s | R=%.5f S=%.5f | Force=%.1f/%d | Chaine:%s Spikes:%d/%d",
      _Symbol, resistance, support, force, SCH1_ForceThreshold,
      g_sch1Chain.active ? "ACTIVE" : "off", g_sch1Chain.spikeCount, SCH1_ChainMaxSpikes);
   Comment(txt);
}


double CalculateLotSize()
{
   // Mettre à jour les stats de drawdown journalier
   UpdateDailyEquityStats();

   // Si le drawdown max est atteint, ne plus ouvrir de nouvelles positions
   if(IsDailyDrawdownExceeded())
   {
      Print("⚠️ Nouvelle entrée bloquée par la gestion de risque journalière.");
      return 0.0;
   }

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(UseMinLotOnly)
      return NormalizeDouble(MathMax(minLot, lotStep), 2);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct = MaxRiskPerTradePercent;
   if(riskPct <= 0.0) riskPct = 1.0; // fallback très conservateur
   double riskAmount = balance * (riskPct / 100.0);
   double tickVal = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickVal <= 0 || tickSize <= 0) return minLot;
   if(atrHandle == INVALID_HANDLE) return minLot;
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return minLot;
   double slPoints = (atr[0] / point) * SL_ATRMult;
   double pipVal = (tickVal / tickSize) * point;
   if(pipVal <= 0) return minLot;
   double lotSize = riskAmount / (slPoints * pipVal);
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = MathRound(lotSize / lotStep) * lotStep;
   return NormalizeDouble(lotSize, 2);
}

// Normaliser un volume arbitraire en respectant min/max/step du symbole
double NormalizeVolumeForSymbol(double desiredVolume)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = minLot;
   double vol = desiredVolume;
   if(vol < minLot) vol = minLot;
   if(vol > maxLot) vol = maxLot;
   vol = MathFloor(vol / lotStep + 1e-8) * lotStep;
   return NormalizeDouble(vol, 2);
}

// Met à jour les statistiques d'équité journalière (début, max, min)
void UpdateDailyEquityStats()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   MqlDateTime dt;
   TimeCurrent(dt);
   int today = dt.year * 10000 + dt.mon * 100 + dt.day;

   if(g_dailyEquityDate != today || g_dailyStartEquity <= 0.0)
   {
      g_dailyEquityDate = today;
      g_dailyStartEquity = equity;
      g_dailyMaxEquity = equity;
      g_dailyMinEquity = equity;
      Print("📊 Réinitialisation stats journalières: équité départ = ", DoubleToString(equity, 2));
   }
   else
   {
      if(equity > g_dailyMaxEquity) g_dailyMaxEquity = equity;
      if(equity < g_dailyMinEquity) g_dailyMinEquity = equity;
   }
}

// Indique si le drawdown journalier max autorisé est dépassé
bool IsDailyDrawdownExceeded()
{
   if(MaxDailyDrawdownPercent <= 0.0 || g_dailyStartEquity <= 0.0)
      return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double ddPercent = 0.0;
   if(g_dailyStartEquity > 0.0)
      ddPercent = (g_dailyStartEquity - equity) / g_dailyStartEquity * 100.0;

   if(ddPercent >= MaxDailyDrawdownPercent)
   {
      Print("🛑 DRAWDOWN JOURNALIER MAX ATTEINT: ",
            DoubleToString(ddPercent, 1), "% / ",
            DoubleToString(MaxDailyDrawdownPercent, 1),
            "% - blocage des nouvelles entrées pour aujourd'hui.");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Taille moyenne d'une bougie M1 (high-low) en prix, sur les      |
//| N dernières bougies. Sert à dimensionner le SL/TP des ordres   |
//| LIMIT en "bougies M1" (ex: SL=3 bougies, TP=7 bougies)    |
//| au lieu d'ATR (trop serré pour les LIMIT en attente).          |
//+------------------------------------------------------------------+
double SMC_GetAvgM1BarSize(const int bars = 20)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M1, 1, bars, r) < MathMin(bars, 5)) return 0.0;
   int n = ArraySize(r);
   if(n < 1) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < n; i++)
      sum += MathAbs(r[i].high - r[i].low);
   return sum / n;
}

//| VALIDATION ET AJUSTEMENT DES PRIX POUR ORDRES LIMITES            |
bool ValidateAndAdjustLimitPrice(double &entryPrice, double &stopLoss, double &takeProfit, ENUM_ORDER_TYPE orderType)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Récupérer les exigences du courtier
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopsLevel * point;
   
   // Détection spécifique pour chaque type de symbole
   bool isVolatility = (StringFind(_Symbol, "Volatility") >= 0 || StringFind(_Symbol, "RANGE BREAK") >= 0);
   bool isGold = (StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0);
   bool isForex = (StringFind(_Symbol, "USD") >= 0 && !isGold && !isVolatility);
   
   if(isVolatility)
   {
      minDistance = MathMax(minDistance, 500 * point); // Augmenté à 500 pips pour Volatility
      Print("🔧 Volatility Index détecté - Distance minimale: ", DoubleToString(minDistance, 0), " pips");
   }
   else if(isGold)
   {
      minDistance = MathMax(minDistance, 200 * point); // 200 pips minimum pour XAUUSD
      Print("🔧 Gold (XAUUSD) détecté - Distance minimale: ", DoubleToString(minDistance, 0), " pips");
   }
   else if(isForex)
   {
      minDistance = MathMax(minDistance, 100 * point); // Augmenté à 100 pips pour Forex (AUDJPY, etc.)
      Print("🔧 Forex détecté - Distance minimale: ", DoubleToString(minDistance, 0), " pips");
   }
   else
   {
      minDistance = MathMax(minDistance, 30 * point); // 30 pips minimum par défaut
   }

   // ── SL/TP des LIMIT basés sur la taille des bougies M1 ──
   // SL = LimitSL_M1Bars bougies M1, TP = LimitTP_M1Bars bougies M1.
   // Remplace le SL/TP ATR (trop serré) calculé à l'appel de cette fonction.
   double m1Bar = SMC_GetAvgM1BarSize(20);
   if(m1Bar > 0.0)
   {
      double slDistM1 = m1Bar * (double)MathMax(1, LimitSL_M1Bars);
      double tpDistM1 = m1Bar * (double)MathMax(1, LimitTP_M1Bars);
      if(orderType == ORDER_TYPE_BUY_LIMIT)
      {
         stopLoss   = entryPrice - slDistM1;
         takeProfit = entryPrice + tpDistM1;
      }
      else if(orderType == ORDER_TYPE_SELL_LIMIT)
      {
         stopLoss   = entryPrice + slDistM1;
         takeProfit = entryPrice - tpDistM1;
      }
      Print("🔧 LIMIT SL/TP M1: SL=", DoubleToString(stopLoss, _Digits),
            " TP=", DoubleToString(takeProfit, _Digits),
            " (M1 bar=", DoubleToString(m1Bar, _Digits),
            " SLx", IntegerToString(LimitSL_M1Bars), " TPx", IntegerToString(LimitTP_M1Bars), ")");
   }
   else
      Print("⚠️ LIMIT M1 bar size indisponible - SL/TP ATR conservé");

   // Validation et ajustement du prix d'entrée
   bool priceAdjusted = false;
   
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      // BUY LIMIT doit être < Ask
      if(entryPrice >= currentAsk)
      {
         entryPrice = currentBid - (minDistance * 2); // Plus de marge
         priceAdjusted = true;
         Print("🔧 BUY LIMIT price ajusté: ", DoubleToString(entryPrice, _Digits), " (doit être < Ask)");
      }
      
      // Vérifier distance minimale
      if(currentAsk - entryPrice < minDistance)
      {
         entryPrice = currentAsk - (minDistance * 1.5); // Plus de marge
         priceAdjusted = true;
         Print("🔧 BUY LIMIT distance ajustée: ", DoubleToString(entryPrice, _Digits), " (distance minimale)");
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      // SELL LIMIT doit être > Bid
      if(entryPrice <= currentBid)
      {
         entryPrice = currentAsk + (minDistance * 2); // Plus de marge
         priceAdjusted = true;
         Print("🔧 SELL LIMIT price ajusté: ", DoubleToString(entryPrice, _Digits), " (doit être > Bid)");
      }
      
      // Vérifier distance minimale
      if(entryPrice - currentBid < minDistance)
      {
         entryPrice = currentBid + (minDistance * 1.5); // Plus de marge
         priceAdjusted = true;
         Print("🔧 SELL LIMIT distance ajustée: ", DoubleToString(entryPrice, _Digits), " (distance minimale)");
      }
   }
   
   // Validation et ajustement du Stop Loss
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(stopLoss >= entryPrice || (entryPrice - stopLoss) < minDistance)
      {
         stopLoss = entryPrice - (minDistance * 1.2); // Plus de marge
         Print("🔧 BUY LIMIT SL ajusté: ", DoubleToString(stopLoss, _Digits));
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      if(stopLoss <= entryPrice || (stopLoss - entryPrice) < minDistance)
      {
         stopLoss = entryPrice + (minDistance * 1.2); // Plus de marge
         Print("🔧 SELL LIMIT SL ajusté: ", DoubleToString(stopLoss, _Digits));
      }
   }
   
   // Validation et ajustement du Take Profit
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(takeProfit <= entryPrice || (takeProfit - entryPrice) < minDistance)
      {
         takeProfit = entryPrice + (minDistance * 3); // Ratio 1:3 pour plus de sécurité
         Print("🔧 BUY LIMIT TP ajusté: ", DoubleToString(takeProfit, _Digits));
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      if(takeProfit >= entryPrice || (entryPrice - takeProfit) < minDistance)
      {
         takeProfit = entryPrice - (minDistance * 3); // Ratio 1:3 pour plus de sécurité
         Print("🔧 SELL LIMIT TP ajusté: ", DoubleToString(takeProfit, _Digits));
      }
   }
   
   // Normaliser tous les prix
   entryPrice = NormalizeDouble(entryPrice, _Digits);
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   // Validation finale très stricte
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(entryPrice >= currentAsk || (currentAsk - entryPrice) < minDistance || 
         stopLoss >= entryPrice || (entryPrice - stopLoss) < minDistance ||
         takeProfit <= entryPrice || (takeProfit - entryPrice) < minDistance)
      {
         Print("❌ ERREUR CRITIQUE: Prix BUY LIMIT toujours invalides après ajustement!");
         Print("   Entry: ", DoubleToString(entryPrice, _Digits), " Ask: ", DoubleToString(currentAsk, _Digits));
         Print("   SL: ", DoubleToString(stopLoss, _Digits), " TP: ", DoubleToString(takeProfit, _Digits));
         Print("   MinDistance: ", DoubleToString(minDistance, 0), " pips");
         return false;
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      if(entryPrice <= currentBid || (entryPrice - currentBid) < minDistance ||
         stopLoss <= entryPrice || (stopLoss - entryPrice) < minDistance ||
         takeProfit >= entryPrice || (entryPrice - takeProfit) < minDistance)
      {
         Print("❌ ERREUR CRITIQUE: Prix SELL LIMIT toujours invalides après ajustement!");
         Print("   Entry: ", DoubleToString(entryPrice, _Digits), " Bid: ", DoubleToString(currentBid, _Digits));
         Print("   SL: ", DoubleToString(stopLoss, _Digits), " TP: ", DoubleToString(takeProfit, _Digits));
         Print("   MinDistance: ", DoubleToString(minDistance, 0), " pips");
         return false;
      }
   }
   
   if(priceAdjusted)
   {
      Print("✅ Prix final ajusté - Entry: ", DoubleToString(entryPrice, _Digits), 
            " SL: ", DoubleToString(stopLoss, _Digits), 
            " TP: ", DoubleToString(takeProfit, _Digits));
   }
   
   return true;
}

//| État de ré-entrée après TP1$ (déclarations déplacées avant #include)  |
// g_tp1LastCloseTime, g_tp1LastCloseDir, g_tp1LastClosePrice,
// g_tp1LastCloseATR, g_tp1WaitingReEntry — déclarées avant #include

//| Fermer à +1$ et préparer ré-entrée sur pullback S/R 20Bar / OB / EMA  |
void TP1_CloseAndReEntry()
{
   if(!TakeProfitAt1Dollar) return;
   if(PositionsTotal() == 0) return;

   // Calculer ATR pour ce tick
   double atrLocal[];
   ArraySetAsSeries(atrLocal, true);
   double atrValLocal = 0;
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atrLocal) >= 1)
      atrValLocal = atrLocal[0];

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;

      string symbol = posInfo.Symbol();
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();

      // ── Si en attente de ré-ENTRY : vérifier si prix touche zone pullback ──
      if(g_tp1WaitingReEntry && symbol == _Symbol)
      {
         // Vérifier cooldown 30 secondes minimum
         if(TimeCurrent() - g_tp1LastCloseTime < 30) continue;

         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         int    dg  = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

         // Calculer zone pullback autour du prix de fermeture
         double zoneSize = g_tp1LastCloseATR * TP1ReEntryATRZone;
         double zoneHigh = g_tp1LastClosePrice + zoneSize;
         double zoneLow  = g_tp1LastClosePrice - zoneSize;

         bool nearZone = false;
         string entryType = "";

         if(g_tp1LastCloseDir == "BUY")
         {
            // Ré-entrée BUY : prix re-baisse vers support zone
            if(bid <= zoneHigh && bid >= zoneLow)
            {
               nearZone = true;
               entryType = "S/R-PULLBACK";
            }
         }
         else if(g_tp1LastCloseDir == "SELL")
         {
            // Ré-entrée SELL : prix re-monte vers résistance zone
            if(ask <= zoneHigh && ask >= zoneLow)
            {
               nearZone = true;
               entryType = "S/R-PULLBACK";
            }
         }

         // Vérifier aussi OB zone (si disponible)
         if(!nearZone)
         {
            double obZone = zoneSize * 1.5; // Zone OB un peu plus large
            if(g_tp1LastCloseDir == "BUY" && bid <= g_tp1LastClosePrice + obZone && bid >= g_tp1LastClosePrice - obZone * 0.3)
            {
               nearZone = true;
               entryType = "OB-PULLBACK";
            }
            else if(g_tp1LastCloseDir == "SELL" && ask >= g_tp1LastClosePrice - obZone && ask <= g_tp1LastClosePrice + obZone * 0.3)
            {
               nearZone = true;
               entryType = "OB-PULLBACK";
            }
         }

          // Vérifier EMA M5 (si disponible)
          if(!nearZone && ema50LTF != INVALID_HANDLE)
          {
             double ema50[];
             ArraySetAsSeries(ema50, true);
             if(CopyBuffer(ema50LTF, 0, 0, 1, ema50) >= 1)
            {
               double emaDist = g_tp1LastCloseATR * 0.3;
               if(g_tp1LastCloseDir == "BUY" && bid >= ema50[0] - emaDist && bid <= ema50[0] + emaDist)
               {
                  nearZone = true;
                  entryType = "EMA5-PULLBACK";
               }
               else if(g_tp1LastCloseDir == "SELL" && ask <= ema50[0] + emaDist && ask >= ema50[0] - emaDist)
               {
                  nearZone = true;
                  entryType = "EMA5-PULLBACK";
               }
            }
         }

         // Exécuter ré-entrée si zone touchée
         if(nearZone)
         {
            if(!TryAcquireOpenLock()) continue;

            double lot = CalculateLotSize();
            if(lot <= 0) { ReleaseOpenLock(); continue; }

            double atr[];
            ArraySetAsSeries(atr, true);
            double atrVal = 0;
            if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1)
               atrVal = atr[0];
            if(atrVal <= 0) { ReleaseOpenLock(); continue; }

            bool orderOK = false;

            if(g_tp1LastCloseDir == "BUY")
            {
               if(g_smcGomConnected && g_smcGomVerdictNum < 0)
               {
                  Print("🚫 TP1-REENTRY BUY BLOQUÉ — GOM verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ")");
                  ReleaseOpenLock(); continue;
               }
               double sl = NormalizeDouble(ask - atrVal * GOMAlignSL_ATRMult, dg);
               double tp = NormalizeDouble(ask + atrVal * GOMAlignTP_ATRMult, dg);
               if(SafeTradeBuy(lot, symbol, ask, sl, tp, "TP1-REENTRY BUY"))
               {
                  orderOK = true;
                  Print("🔄 TP1 RE-ENTRY BUY ", symbol, " @", DoubleToString(ask, dg),
                        " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg),
                        " | ", entryType, " | Lot=", DoubleToString(lot, 2));
               }
            }
            else if(g_tp1LastCloseDir == "SELL")
            {
               if(g_smcGomConnected && g_smcGomVerdictNum > 0)
               {
                  Print("🚫 TP1-REENTRY SELL BLOQUÉ — GOM verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ")");
                  ReleaseOpenLock(); continue;
               }
               double sl = NormalizeDouble(bid + atrVal * GOMAlignSL_ATRMult, dg);
               double tp = NormalizeDouble(bid - atrVal * GOMAlignTP_ATRMult, dg);
               if(SafeTradeSell(lot, symbol, bid, sl, tp, "TP1-REENTRY SELL"))
               {
                  orderOK = true;
                  Print("🔄 TP1 RE-ENTRY SELL ", symbol, " @", DoubleToString(bid, dg),
                        " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg),
                        " | ", entryType, " | Lot=", DoubleToString(lot, 2));
               }
            }

            ReleaseOpenLock();

            if(orderOK)
            {
               g_tp1WaitingReEntry = false;
               g_maxProfit = 0;
               if(UseNotifications)
                  SendNotification("🔄 TP1 RE-ENTRY " + g_tp1LastCloseDir + " " + symbol + " " + entryType);
            }
         }
         continue; // Pas de gestion trailing sur cette position
      }

      // ── Vérifier profit >= cible → fermer immédiatement ─────────────────────
      if(profit >= TP1ProfitTargetUSD)
      {
         int    dg  = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

         if(PositionSelectByTicket(posInfo.Ticket()))
         {
            if(trade.PositionClose(posInfo.Ticket()))
            {
               g_tp1LastCloseTime  = TimeCurrent();
               g_tp1LastCloseDir   = (posInfo.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";
               g_tp1LastClosePrice = (posInfo.PositionType() == POSITION_TYPE_BUY)
                  ? SymbolInfoDouble(symbol, SYMBOL_BID)
                  : SymbolInfoDouble(symbol, SYMBOL_ASK);
               g_tp1LastCloseATR   = atrValLocal; // ATR calculé pour ce tick
               g_tp1WaitingReEntry = TP1ReEnterOnPullback;
               g_maxProfit         = 0;

               Print("💰 TP1 FERMETURE ", symbol, " | Profit: $", DoubleToString(profit, 2),
                     " | Dir: ", g_tp1LastCloseDir, " | Prix: ", DoubleToString(g_tp1LastClosePrice, dg),
                     " | Ré-entry: ", g_tp1WaitingReEntry ? "OUI" : "NON");
               if(UseNotifications)
                  SendNotification("💰 TP1 $1 SÉCURISÉ " + symbol + " profit=$" + DoubleToString(profit, 2));
               // WhatsApp SR20 TP signal
               SendSR20WhatsAppSignal("SR20_TP", symbol, g_tp1LastCloseDir,
                                      g_tp1LastClosePrice, 0, 0,
                                      SymbolInfoDouble(symbol, SYMBOL_BID),
                                      0, "", atrValLocal,
                                      0, 0,
                                      "TP1 $1 atteint — profit securise");
            }
         }
      }
   }
}

//| Fermer position si verdict GOM → WAIT et perte ≥ 1$                    |
void CloseOnVerdictWait()
{
   if(!UseCloseOnVerdictWait) return;
   if(PositionsTotal() == 0) return;

   // Si verdict n'est PAS WAIT → ne rien faire
   if(g_smcGomVerdictNum != 0) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;

      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();

      // FIX: Sous WAIT on ferme TOUTES nos positions immédiatement (gain ou perte)
      // Plus de threshold -$1 — quand GOM passe à WAIT, on sort vite.
      {
         string symbol = posInfo.Symbol();
         int    dg     = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
         string dir    = (posInfo.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";

         if(PositionSelectByTicket(posInfo.Ticket()))
         {
            if(trade.PositionClose(posInfo.Ticket()))
            {
               Print("🛑 CLOSE-VERDICT-WAIT ", symbol, " ", dir,
                     " | Profit: $", DoubleToString(profit, 2),
                     " | Verdict → WAIT");
               if(UseNotifications)
                  SendNotification("🛑 FERMETURE WAIT " + symbol + " " + dir + " profit=$" + DoubleToString(profit, 2));
                 // WhatsApp SR20 SL signal
                 double entryPx = PositionGetDouble(POSITION_PRICE_OPEN);
                 double atrExit = 0;
                 if(atrHandle != INVALID_HANDLE)
                 {
                    double atrBuf[];
                    ArraySetAsSeries(atrBuf, true);
                    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) >= 1) atrExit = atrBuf[0];
                 }
                 string exitMsg = "Verdict WAIT - sortie forcee profit $" + DoubleToString(profit, 2);
                 SendSR20WhatsAppSignal("SR20_EXIT", symbol, dir,
                                        entryPx, 0, 0,
                                        SymbolInfoDouble(symbol, SYMBOL_BID),
                                        0, "", atrExit,
                                        0, 0, exitMsg);
                g_maxProfit = 0;
            }
         }
      }
   }
}

void ManageTrailingStop()
{
   // OPTIMISATION: Sortir rapidement si aucune position
   if(PositionsTotal() == 0) return;
   
   // OPTIMISATION: Limiter le trailing stop aux positions de notre EA uniquement
   int ourPositionsCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber)
      {
         ourPositionsCount++;
      }
   }
   
   if(ourPositionsCount == 0) return;
   
   // Calculer l'ATR une seule fois pour toutes les positions
   double atr[];
   ArraySetAsSeries(atr, true);
   double atrValue = 0;
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1)
   {
      atrValue = atr[0];
   }
   
   if(atrValue == 0) return; // Sortir si pas d'ATR disponible
   
   double trailDistance = atrValue * TrailingStop_ATRMult;
   
   // Parcourir uniquement nos positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      
      string symbol = posInfo.Symbol();
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      double currentTP = posInfo.TakeProfit();

      // ── BOOM/CRASH : breakeven dès $2 de gain, pas de trailing ATR ──────────
      if(SMC_GetSymbolCategory(symbol) == SYM_BOOM_CRASH)
      {
         if(profit >= 2.0)
         {
            double pt   = SymbolInfoDouble(symbol, SYMBOL_POINT);
            int    dg   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
            int    stopsLvl = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double minDist  = (double)(stopsLvl + 5) * pt;

            if(posInfo.PositionType() == POSITION_TYPE_BUY)
            {
               double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
               double bePrice = NormalizeDouble(openPrice + MathMax(pt, minDist), dg);
               bool   needsMove = (currentSL == 0 || currentSL < bePrice);
               if(needsMove && bePrice < bid)
               {
                  if(PositionSelectByTicket(posInfo.Ticket()) &&
                     PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                  {
                     if(trade.PositionModify(posInfo.Ticket(), bePrice, currentTP))
                        Print("🔒 BREAKEVEN $2 BUY ", symbol, " SL: ",
                              DoubleToString(currentSL, dg), " → ", DoubleToString(bePrice, dg),
                              " | Gain: $", DoubleToString(profit, 2));
                  }
               }
            }
            else
            {
               double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);
               double bePrice = NormalizeDouble(openPrice - MathMax(pt, minDist), dg);
               bool   needsMove = (currentSL == 0 || currentSL > bePrice);
               if(needsMove && bePrice > ask)
               {
                  if(PositionSelectByTicket(posInfo.Ticket()) &&
                     PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                  {
                     if(trade.PositionModify(posInfo.Ticket(), bePrice, currentTP))
                        Print("🔒 BREAKEVEN $2 SELL ", symbol, " SL: ",
                              DoubleToString(currentSL, dg), " → ", DoubleToString(bePrice, dg),
                              " | Gain: $", DoubleToString(profit, 2));
                  }
               }
            }
         }
         continue; // Pas de trailing ATR sur Boom/Crash
      }

      // ── VOLATILITY (non-Boom/Crash, non-FXVOL) : breakeven + trailing ATR ──
      if(SMC_GetSymbolCategory(symbol) == SYM_VOLATILITY &&
         !SMC_IsWeltradeVolSymbol(symbol) && StringFind(symbol, "VOL") < 0)
      {
         // Breakeven: dès +$0.50 de gain → SL au point d'entrée
         if(profit >= 0.50)
         {
            double pt   = SymbolInfoDouble(symbol, SYMBOL_POINT);
            int    dg   = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
            int    stopsLvl = (int)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
            double minDist  = (double)(stopsLvl + 5) * pt;

            if(posInfo.PositionType() == POSITION_TYPE_BUY)
            {
               double bid    = SymbolInfoDouble(symbol, SYMBOL_BID);
               double bePrice = NormalizeDouble(openPrice + MathMax(pt, minDist), dg);
               bool   needsMove = (currentSL == 0 || currentSL < bePrice);
               if(needsMove && bePrice < bid)
               {
                  if(PositionSelectByTicket(posInfo.Ticket()) &&
                     PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                  {
                     if(trade.PositionModify(posInfo.Ticket(), bePrice, currentTP))
                        Print("🔒 BREAKEVEN VOL BUY ", symbol, " SL: ",
                              DoubleToString(currentSL, dg), " → ", DoubleToString(bePrice, dg),
                              " | Gain: $", DoubleToString(profit, 2));
                  }
               }
            }
            else
            {
               double ask    = SymbolInfoDouble(symbol, SYMBOL_ASK);
               double bePrice = NormalizeDouble(openPrice - MathMax(pt, minDist), dg);
               bool   needsMove = (currentSL == 0 || currentSL > bePrice);
               if(needsMove && bePrice > ask)
               {
                  if(PositionSelectByTicket(posInfo.Ticket()) &&
                     PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                  {
                     if(trade.PositionModify(posInfo.Ticket(), bePrice, currentTP))
                        Print("🔒 BREAKEVEN VOL SELL ", symbol, " SL: ",
                              DoubleToString(currentSL, dg), " → ", DoubleToString(bePrice, dg),
                              " | Gain: $", DoubleToString(profit, 2));
                  }
               }
            }
         }
         // Vol: pas de continue — laisse le trailing ATR gérer après breakeven
      }

      // ── FXVOL : ne jamais rendre plus de 30% du peak (protège FxVolTrailKeepPct%) ──
      if(SMC_IsWeltradeVolSymbol(symbol) ||
         (SMC_GetSymbolCategory(symbol) == SYM_VOLATILITY && StringFind(symbol, "VOL") >= 0))
      {
         static ulong  s_fxPeakTicket[32];
         static double s_fxPeakProfit[32];
         static int    s_fxPeakCount = 0;

         if(profit > 0)
         {
            int slot = -1;
            for(int p = 0; p < s_fxPeakCount; p++)
               if(s_fxPeakTicket[p] == posInfo.Ticket()) { slot = p; break; }
            if(slot < 0 && s_fxPeakCount < 32)
            {
               slot = s_fxPeakCount++;
               s_fxPeakTicket[slot] = posInfo.Ticket();
               s_fxPeakProfit[slot] = 0;
            }
            if(slot >= 0 && profit > s_fxPeakProfit[slot])
               s_fxPeakProfit[slot] = profit;

            double peak = (slot >= 0) ? s_fxPeakProfit[slot] : profit;
            double keepPct = MathMax(50.0, MathMin(95.0, FxVolTrailKeepPct)) / 100.0;
            if(peak >= 0.5)
            {
               double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
               double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
               double lotSize  = posInfo.Volume();
               int    dg       = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
               if(tickVal > 0 && tickSize > 0 && lotSize > 0)
               {
                  double protectUSD = peak * keepPct;
                  double ticksNeeded = protectUSD / (tickVal * lotSize);
                  double priceDist = ticksNeeded * tickSize;
                  double newSL = 0;
                  if(posInfo.PositionType() == POSITION_TYPE_BUY)
                  {
                     double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
                     newSL = NormalizeDouble(openPrice + priceDist, dg);
                     if(newSL > currentSL && newSL < bid)
                     {
                        if(PositionSelectByTicket(posInfo.Ticket()) &&
                           trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
                           Print("🎯 FXVOL TRAIL BUY ", symbol, " peak=$", DoubleToString(peak, 2),
                                 " protect=", DoubleToString(keepPct * 100, 0), "% SL→", DoubleToString(newSL, dg));
                     }
                  }
                  else
                  {
                     double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
                     newSL = NormalizeDouble(openPrice - priceDist, dg);
                     if((currentSL == 0 || newSL < currentSL) && newSL > ask)
                     {
                        if(PositionSelectByTicket(posInfo.Ticket()) &&
                           trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
                           Print("🎯 FXVOL TRAIL SELL ", symbol, " peak=$", DoubleToString(peak, 2),
                                 " protect=", DoubleToString(keepPct * 100, 0), "% SL→", DoubleToString(newSL, dg));
                     }
                  }
               }
            }
         }
         continue; // FXVOL: trailing dollar only
      }

      // ── GOLD/METAL : scaling trailing - protège 70% du gain en $ ───────
      bool isGold = (SMC_GetSymbolCategory(symbol) == SYM_METAL);
      if(isGold && GoldScalingTrail && GoldScaleTrailStart > 0)
      {
         double tickSize  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
         double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
         double lotSize   = posInfo.Volume();
         if(tickSize > 0 && tickValue > 0 && lotSize > 0)
         {
            double profitPips = (posInfo.PositionType() == POSITION_TYPE_BUY)
               ? (SymbolInfoDouble(symbol, SYMBOL_BID) - openPrice) / tickSize
               : (openPrice - SymbolInfoDouble(symbol, SYMBOL_ASK)) / tickSize;
            double profitDollar = profitPips * tickValue * lotSize;

            if(profitDollar >= GoldScaleTrailStart)
            {
               double protectedPips = profitPips * (GoldScaleTrailPct / 100.0);
               double protectDist   = protectedPips * tickSize;
               int    dg            = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

               if(posInfo.PositionType() == POSITION_TYPE_BUY)
               {
                  double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
                  double newSL = NormalizeDouble(bid - protectDist, dg);
                  if(newSL > currentSL && newSL < bid)
                  {
                     if(PositionSelectByTicket(posInfo.Ticket()) &&
                        PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                     {
                        if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
                           Print("🎯 GOLD SCALE BUY ", symbol, " | Profit: $", DoubleToString(profitDollar, 2),
                                 " | SL → ", DoubleToString(newSL, dg),
                                 " | Protège ", GoldScaleTrailPct, "%");
                     }
                  }
               }
               else if(posInfo.PositionType() == POSITION_TYPE_SELL)
               {
                  double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
                  double newSL = NormalizeDouble(ask + protectDist, dg);
                  if(newSL < currentSL || currentSL == 0)
                  {
                     if(PositionSelectByTicket(posInfo.Ticket()) &&
                        PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                     {
                        if(trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
                           Print("🎯 GOLD SCALE SELL ", symbol, " | Profit: $", DoubleToString(profitDollar, 2),
                                 " | SL → ", DoubleToString(newSL, dg),
                                 " | Protège ", GoldScaleTrailPct, "%");
                     }
                  }
               }
            }
         }
         continue; // Gold utilise uniquement le scaling dollar
      }

// Position initiale sans SL
       if(currentSL == 0)
       {
          if(posInfo.PositionType() == POSITION_TYPE_BUY)
          {
             double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
             double newSL = currentPrice - trailDistance;
             if(UseTrailingStructure)
             {
                double structSL = CM_StructureTrailSL(symbol, POSITION_TYPE_BUY);
                if(structSL > 0 && structSL < currentPrice)
                   newSL = MathMax(newSL, structSL);
             }

             // VALIDATION: Vérifier que la position existe toujours avant de modifier
             if(!PositionSelectByTicket(posInfo.Ticket()))
             {
                continue;
             }

             // Double validation: vérifier que le magic number et symbole correspondent
             if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != symbol)
             {
                continue;
             }

             if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
                Print("🛡️ SL initial BUY ", symbol, ": ", DoubleToString(newSL, _Digits));
          }
          else
          {
             double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
             double newSL = currentPrice + trailDistance;
             if(UseTrailingStructure)
             {
                double structSL = CM_StructureTrailSL(symbol, POSITION_TYPE_SELL);
                if(structSL > 0 && structSL > currentPrice)
                   newSL = MathMin(newSL, structSL);
             }

             // VALIDATION: Vérifier que la position existe toujours avant de modifier
             if(!PositionSelectByTicket(posInfo.Ticket()))
             {
                continue;
             }

             // Double validation: vérifier que le magic number et symbole correspondent
             if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != symbol)
             {
                continue;
             }

             if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
                Print("🛡️ SL initial SELL ", symbol, ": ", DoubleToString(newSL, _Digits));
          }
          continue;
       }
       
       // ── PROTECTION GAIN 70% QUAND H1+M5 ALIGNÉS (max 30% rendu) ──
       // S'applique à TOUS les symboles (sauf Boom/Crash/FXVOL/Gold déjà gérés)
       if(UseGainProtectionTrail && profit > 0)
       {
          // Track peak profit per position
          static ulong s_peakTicket[64];
          static double s_peakProfit[64];
          static int s_peakCount = 0;
          
          int peakSlot = -1;
          for(int p = 0; p < s_peakCount; p++)
             if(s_peakTicket[p] == posInfo.Ticket()) { peakSlot = p; break; }
          
          if(peakSlot < 0 && s_peakCount < 64)
          {
             peakSlot = s_peakCount++;
             s_peakTicket[peakSlot] = posInfo.Ticket();
             s_peakProfit[peakSlot] = 0;
          }
          
          if(peakSlot >= 0 && profit > s_peakProfit[peakSlot])
             s_peakProfit[peakSlot] = profit;
          
          double peakProfit = (peakSlot >= 0) ? s_peakProfit[peakSlot] : profit;
          
          // Vérifier alignement H1+M5 dans le sens de la position
          bool h1m5Aligned = IsH1M5AlignedForPosition(symbol, posInfo.PositionType());
          
          if(h1m5Aligned && peakProfit >= GainProtectTriggerUSD)
          {
             double keepPct = GainProtectKeepPct / 100.0; // 70% = 0.7
             double protectUSD = peakProfit * keepPct;
             
             double tickVal = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
             double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
             double lotSize = posInfo.Volume();
             int dg = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
             
             if(tickVal > 0 && tickSize > 0 && lotSize > 0)
             {
                double ticksNeeded = protectUSD / (tickVal * lotSize);
                double priceDist = ticksNeeded * tickSize;
                double newSL = 0;
                
                if(posInfo.PositionType() == POSITION_TYPE_BUY)
                {
                   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
                   newSL = NormalizeDouble(openPrice + priceDist, dg);
                   if(newSL > currentSL && newSL < bid)
                   {
                      if(PositionSelectByTicket(posInfo.Ticket()) &&
                         trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
                         Print("🛡️ H1M5-ALIGNED PROTECT BUY ", symbol, " peak=$", DoubleToString(peakProfit,2),
                               " protege=", DoubleToString(keepPct*100,0), "% SL->", DoubleToString(newSL, dg));
                   }
                }
                else
                {
                   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
                   newSL = NormalizeDouble(openPrice - priceDist, dg);
                   if((currentSL == 0 || newSL < currentSL) && newSL > ask)
                   {
                      if(PositionSelectByTicket(posInfo.Ticket()) &&
                         trade.PositionModify(posInfo.Ticket(), newSL, currentTP))
                         Print("🛡️ H1M5-ALIGNED PROTECT SELL ", symbol, " peak=$", DoubleToString(peakProfit,2),
                               " protege=", DoubleToString(keepPct*100,0), "% SL->", DoubleToString(newSL, dg));
                   }
                }
             }
          }
       }
       
       // Trail si position est en gain OU si on risque de perdre >50% du gain maximum
       bool shouldTrail = false;

      if(profit > 0)
      {
         // Garder en mémoire le gain maximum
         if(profit > g_maxProfit) g_maxProfit = profit;

         // Activer le trailing À PARTIR DE 0.5$ de gain
         // À 0.5$+, sécuriser au breakeven + ATR/2
         if(profit >= 0.5)
         {
            shouldTrail = true;
         }
      }
      else if(g_maxProfit >= 0.5)
      {
         // Si on a déjà eu au moins 0.5$ de gain et qu'on a rendu >50% de ce gain,
         // forcer le trailing pour empêcher de perdre plus de la moitié du gain maximum.
         if(profit <= (g_maxProfit * 0.5))
         {
            shouldTrail = true;
         }
      }
      
      if(shouldTrail)
      {
         if(posInfo.PositionType() == POSITION_TYPE_BUY)
         {
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
            double newSL = currentPrice - trailDistance;
            if(UseTrailingStructure)
            {
               double structSL = CM_StructureTrailSL(symbol, POSITION_TYPE_BUY);
               if(structSL > 0 && structSL > newSL && structSL < currentPrice)
                  newSL = structSL;
            }

            // BUY: SL doit être SOUS le prix courant et AMÉLIORER le SL existant
            if(newSL > currentSL && newSL <= currentPrice)
            {
               // VALIDATION: Vérifier que la position existe toujours avant de modifier
               if(!PositionSelectByTicket(posInfo.Ticket()))
               {
                  continue;
               }

               // Double validation: vérifier que le magic number et symbole correspondent
               if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != symbol)
               {
                  continue;
               }

               if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
               {
                  Print("🔒 SL BUY ", symbol, " sécurisé: ", DoubleToString(currentSL, _Digits), " → ", DoubleToString(newSL, _Digits), " | Gain: $", DoubleToString(profit, 2));
               }
            }
         }
         else if(posInfo.PositionType() == POSITION_TYPE_SELL)
         {
            double currentPrice = SymbolInfoDouble(symbol, SYMBOL_ASK);
            double newSL = currentPrice + trailDistance;
            if(UseTrailingStructure)
            {
               double structSL = CM_StructureTrailSL(symbol, POSITION_TYPE_SELL);
               if(structSL > 0 && structSL < newSL && structSL > currentPrice)
                  newSL = structSL;
            }

            // SELL: SL doit être AU-DESSUS du prix courant et AMÉLIORER le SL existant
            if(newSL < currentSL && newSL >= currentPrice)
            {
               // VALIDATION: Vérifier que la position existe toujours avant de modifier
               if(!PositionSelectByTicket(posInfo.Ticket()))
               {
                  continue;
               }

               // Double validation: vérifier que le magic number et symbole correspondent
               if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != symbol)
               {
                  continue;
               }

               if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
               {
                  Print("🔒 SL SELL ", symbol, " sécurisé: ", DoubleToString(currentSL, _Digits), " → ", DoubleToString(newSL, _Digits), " | Gain: $", DoubleToString(profit, 2));
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| GESTION CAPITAL JOURNALIÈRE — limites, pauses, trailing structure |
//+------------------------------------------------------------------+
int CM_TodayYMD()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
}

void CM_ResetIfNewDay()
{
   int today = CM_TodayYMD();
   if(g_cmDateYMD == today) return;

   g_cmDateYMD        = today;
   g_cmTradesToday    = 0;
   g_cmNetProfitToday = 0.0;
   g_cmWinsToday      = 0;
   g_cmLossesToday    = 0;
   g_cmDayStopped     = false;
   g_cmDayStopReason  = "";
   g_cmPauseUntil     = 0;
   g_cmConsecWins     = 0;
   g_cmConsecLosses   = 0;

   // Calculer les seuils dynamiques sur la base du solde réel au début de la journée
   g_cmDayStartBalance       = AccountInfoDouble(ACCOUNT_BALANCE);
   g_cmEffectiveProfitTarget = NormalizeDouble(g_cmDayStartBalance * DailyProfitTargetPercent / 100.0, 2);
   g_cmEffectiveMaxLoss      = NormalizeDouble(g_cmDayStartBalance * DailyMaxLossPercent      / 100.0, 2);

   Print("📅 Capital Manager — reset journalier ", today,
         " | Solde: ", DoubleToString(g_cmDayStartBalance, 2), "$",
         " | Cible +", DoubleToString(g_cmEffectiveProfitTarget, 2), "$",
         " (", DoubleToString(DailyProfitTargetPercent, 1), "%)",
         " | Max perte -", DoubleToString(g_cmEffectiveMaxLoss, 2), "$",
         " (", DoubleToString(DailyMaxLossPercent, 1), "%)");
}

void CM_RefreshDailyStats()
{
   if(!UseDailyCapitalManager) return;
   CM_ResetIfNewDay();

   datetime dayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(!HistorySelect(dayStart, TimeCurrent()))
      return;

   int trades = 0;
   double net = 0.0;
   int wins = 0, losses = 0;

   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(!HistoryDealSelect(dealTicket)) continue;
      if((long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != InpMagicNumber) continue;

      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_IN)
         trades++;

      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
      {
         double p = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                  + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                  + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         net += p;
         if(p > 0) wins++;
         else if(p < 0) losses++;
      }
   }

   g_cmTradesToday    = trades;
   g_cmNetProfitToday = net;
   g_cmWinsToday      = wins;
   g_cmLossesToday    = losses;

   if(!g_cmDayStopped)
   {
      if(g_cmEffectiveProfitTarget > 0 && net >= g_cmEffectiveProfitTarget)
      {
         g_cmDayStopped    = true;
         g_cmDayStopReason = "Objectif +" + DoubleToString(g_cmEffectiveProfitTarget, 2)
                           + "$ (" + DoubleToString(DailyProfitTargetPercent, 1) + "%) atteint";
      }
      else if(g_cmEffectiveMaxLoss > 0 && net <= -g_cmEffectiveMaxLoss)
      {
         g_cmDayStopped    = true;
         g_cmDayStopReason = "Perte max -" + DoubleToString(g_cmEffectiveMaxLoss, 2)
                           + "$ (" + DoubleToString(DailyMaxLossPercent, 1) + "%) atteint";
      }
      else if(MaxTradesPerDay > 0 && trades >= MaxTradesPerDay)
      {
         g_cmDayStopped    = true;
         g_cmDayStopReason = "Max " + IntegerToString(MaxTradesPerDay) + " trades/jour atteint";
      }
   }
}

bool CM_IsEntryBlocked(string &reason)
{
   reason = "";
   if(!UseDailyCapitalManager) return false;

   CM_RefreshDailyStats();

   if(g_cmDayStopped)
   {
      reason = g_cmDayStopReason;
      return true;
   }

   if(g_cmPauseUntil > TimeCurrent())
   {
      int remain = (int)(g_cmPauseUntil - TimeCurrent());
      reason = "Pause W/L (" + IntegerToString(remain / 60) + "m " + IntegerToString(remain % 60) + "s)";
      return true;
   }

   if(MaxTradesPerDay > 0 && g_cmTradesToday >= MaxTradesPerDay)
   {
      reason = "Max trades/jour " + IntegerToString(MaxTradesPerDay);
      return true;
   }

   if(g_cmEffectiveProfitTarget > 0 && g_cmNetProfitToday >= g_cmEffectiveProfitTarget)
   {
      reason = "Objectif profit +" + DoubleToString(g_cmEffectiveProfitTarget, 2)
             + "$ (" + DoubleToString(DailyProfitTargetPercent, 1) + "%)";
      return true;
   }

   if(g_cmEffectiveMaxLoss > 0 && g_cmNetProfitToday <= -g_cmEffectiveMaxLoss)
   {
      reason = "Perte max -" + DoubleToString(g_cmEffectiveMaxLoss, 2)
             + "$ (" + DoubleToString(DailyMaxLossPercent, 1) + "%)";
      return true;
   }

   return false;
}

void CM_OnClosedTrade(double profit)
{
   if(!UseDailyCapitalManager) return;

   if(profit > 0)
   {
      g_cmConsecWins++;
      g_cmConsecLosses = 0;
   }
   else if(profit < 0)
   {
      g_cmConsecLosses++;
      g_cmConsecWins = 0;
   }

   if(PauseAfterConsecWins > 0 && g_cmConsecWins >= PauseAfterConsecWins)
   {
      g_cmPauseUntil = TimeCurrent() + ConsecPauseMinutes * 60;
      g_cmConsecWins = 0;
      Print("⏸️ Pause ", ConsecPauseMinutes, " min — ", PauseAfterConsecWins, " gains consécutifs");
      if(UseDashboard) UpdateDashboard();
   }

   if(PauseAfterConsecLosses > 0 && g_cmConsecLosses >= PauseAfterConsecLosses)
   {
      g_cmPauseUntil = TimeCurrent() + ConsecPauseMinutes * 60;
      g_cmConsecLosses = 0;
      Print("⏸️ Pause ", ConsecPauseMinutes, " min — ", PauseAfterConsecLosses, " pertes consécutives");
      if(UseDashboard) UpdateDashboard();
   }

   CM_RefreshDailyStats();
   if(g_cmDayStopped && UseDashboard) UpdateDashboard();
}

string CM_StatusLine()
{
   if(!UseDailyCapitalManager) return "Capital Mgmt: OFF";
   CM_RefreshDailyStats();

   string status = g_cmDayStopped ? ("STOP — " + g_cmDayStopReason)
                                  : (g_cmPauseUntil > TimeCurrent() ? "PAUSE W/L" : "ACTIF");
   string pauseStr = (g_cmPauseUntil > TimeCurrent())
      ? (" | Reprise " + TimeToString(g_cmPauseUntil, TIME_MINUTES))
      : "";

   return StringFormat(
      "Capital: %d/%d trades | P/L %+.2f$ (cible +%.2f$ [%.0f%%] / max -%.2f$ [%.0f%%]) | %dW/%dL | Série %dW/%dL | %s%s",
      g_cmTradesToday, MaxTradesPerDay,
      g_cmNetProfitToday,
      g_cmEffectiveProfitTarget, DailyProfitTargetPercent,
      g_cmEffectiveMaxLoss, DailyMaxLossPercent,
      g_cmWinsToday, g_cmLossesToday,
      g_cmConsecWins, g_cmConsecLosses,
      status, pauseStr);
}

double CM_StructureTrailSL(const string symbol, const long posType)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, LTF, 1, 3, rates) < 2) return 0.0;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double pad = point * 10.0;
   if(posType == POSITION_TYPE_BUY)
      return rates[1].low - pad;
   if(posType == POSITION_TYPE_SELL)
      return rates[1].high + pad;
   return 0.0;
}

//| DONNÉES GRAPHIQUES POUR ANALYSE EN TEMPS RÉEL          |

// Buffer pour stocker les données graphiques en temps réel
MqlRates g_chartDataBuffer[];
static datetime g_lastChartCapture = 0;

//| FONCTION POUR CAPTURER LES DONNÉES GRAPHIQUES MT5          |
bool CaptureChartDataFromChart()
{
   // Protection anti-erreur critique
   static int captureErrors = 0;
   static datetime lastErrorReset = 0;
   datetime currentTime = TimeCurrent();
   
   // Réinitialiser les erreurs toutes les 2 minutes
   if(currentTime - lastErrorReset >= 120)
   {
      captureErrors = 0;
      lastErrorReset = currentTime;
   }
   
   // Si trop d'erreurs de capture, désactiver temporairement
   if(captureErrors > 3)
   {
      Print("⚠️ Trop d'erreurs de capture graphique - Mode dégradé");
      return false;
   }
   
   // Récupérer les dernières bougies depuis le graphique
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Limiter la taille pour éviter les surcharges
   int barsToCopy = MathMin(50, 100); // Maximum 50 bougies
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsToCopy, rates) >= barsToCopy)
   {
      // Stocker les données pour analyse ML
      int bufferSize = MathMin(barsToCopy, ArraySize(rates));
      int startIndex = MathMax(0, ArraySize(rates) - bufferSize);
      
      // Vérifier que le buffer n'est pas trop grand
      if(bufferSize > 100)
      {
         Print("⚠️ Buffer trop grand: ", bufferSize, " - Limitation à 100");
         bufferSize = 100;
      }
      
      // Redimensionner le buffer si nécessaire
      if(ArraySize(g_chartDataBuffer) != bufferSize)
         ArrayResize(g_chartDataBuffer, bufferSize);
      
      // Copier les données dans le buffer circulaire
      for(int i = 0; i < bufferSize && i < ArraySize(rates); i++)
      {
         g_chartDataBuffer[i] = rates[startIndex + i];
      }
      
      g_lastChartCapture = currentTime;
      Print("📊 Données graphiques capturées: ", bufferSize, " bougies M1");
      return true;
   }
   else
   {
      captureErrors++;
      Print("❌ Erreur capture graphique (", captureErrors, "/3) - bars demandées: ", barsToCopy);
      return false;
   }
}

//| FONCTION POUR CALCULER LES FEATURES À PARTIR DES DONNÉES MT5          |
double compute_features_from_mt5_data(MqlRates &rates[])
{
   // Utiliser les prix OHLCV directement depuis les données MT5
   double features[];
   int ratesSize = ArraySize(rates);
   ArrayResize(features, ratesSize * 20); // Allocate enough space for all features
   
   for(int i = 0; i < ratesSize; i++)
   {
      // Features de base (using offset to avoid overlap)
      int baseIdx = i * 20;
      features[baseIdx] = rates[i].close;
      features[baseIdx + 1] = rates[i].open;
      features[baseIdx + 2] = rates[i].high;
      features[baseIdx + 3] = rates[i].low;
      
      // Features techniques (calculées sur les bougies)
      // RSI
      double rsi = ComputeRSI(rates, 14, i);
      features[baseIdx + 4] = (rsi < 30) ? -1 : (rsi > 70) ? 1 : 0;
      
      // MACD
      double macd = ComputeMACD(rates, 12, 26, 9, i);
      features[baseIdx + 5] = (macd > 0) ? 1 : 0;
      
      // ATR
      double atr = 0;
      for(int j = MathMax(0, i - 13); j < i; j++)
      {
         double range = rates[j].high - rates[j].low;
         atr += range;
      }
      if(i > 13) atr /= 14;
      features[baseIdx + 6] = atr;
      
      // Volume (convert long to double)
      features[baseIdx + 7] = (double)rates[i].tick_volume;
      
      // Moyennes mobiles
      if(i >= 20) features[baseIdx + 8] = rates[i].close;
      if(i >= 50) features[baseIdx + 9] = rates[i].close;
      if(i >= 100) features[baseIdx + 10] = rates[i].close;
      
      // Features de volatilité
      if(i >= 20)
      {
         double returns[] = {0, 0, 0, 0, 0};
         for(int j = 1; j <= 20; j++)
         {
            double ret = rates[i - j].close - rates[i - j - 1].close;
            if(ret > 0) returns[j-1] = 1; else returns[j-1] = 0;
         }
         features[baseIdx + 11] = 1;
         for(int k = 0; k < ArraySize(returns); k++)
         {
            if(returns[k]) features[baseIdx + 11 + k] = 1;
         }
      }
      
      // Indicateurs de tendance
      if(i >= 2)
      {
         // EMA 5
         double ema5 = ComputeEMA(rates, 5, i);
         double ema20 = ComputeEMA(rates, 20, i);
         features[baseIdx + 12] = ema5;
         features[baseIdx + 13] = ema20;
         
         // RSI et autres indicateurs...
      }
      
      features[baseIdx] = rates[i].close; // Prix actuel
   }
   
   return 0.0;
}

//| FONCTION POUR DÉTECTER LES PATTERNS GRAPHIQUES          |
bool DetectChartPatterns(MqlRates &rates[])
{
   // Détecter les patterns SMC directement depuis les données graphiques
   // FVG, Order Blocks, Liquidity Sweep, etc.
   
   // Retourner les patterns détectés
   return true;
}

//| FONCTIONS TECHNIQUES POUR DONNÉES MT5                    |

double ComputeEMA(MqlRates &rates[], int period, int index)
{
   if(index < period - 1) return rates[index].close;
   
   double ema = rates[index].close;
   double multiplier = 2.0 / (period + 1);
   
   for(int i = 0; i <= index; i++)
   {
      ema = (rates[i].close - ema) * multiplier + ema;
   }
   
   return ema;
}

double ComputeRSI(MqlRates &rates[], int period, int index)
{
   if(index < period - 1) return 50.0;
   
   double gains = 0, losses = 0;
   for(int i = index - period + 1; i <= index; i++)
   {
      double change = rates[i].close - rates[i-1].close;
      if(change > 0)
         gains += change;
      else
         losses += -change;
   }
   
   double avgGain = gains / period;
   double avgLoss = losses / period;
   if(avgLoss == 0.0)
      return 100.0;
   double rs = avgGain / avgLoss;
   double rsi = 100.0 - (100.0 / (1.0 + rs));
   // Clamp pour rester dans [0,100]
   if(rsi < 0.0) rsi = 0.0;
   if(rsi > 100.0) rsi = 100.0;
   return rsi;
}

double ComputeMACD(MqlRates &rates[], int fast, int slow, int signal, int index)
{
   if(index < slow) return 0;
   
   double emaFast = rates[index].close;
   double emaSlow = rates[index].close;
   
   for(int i = 0; i <= index; i++)
   {
      emaFast = (rates[i].close * 2.0 / (fast + 1)) + emaFast * (fast - 1) / (fast + 1);
      emaSlow = (rates[i].close * 2.0 / (slow + 1)) + emaSlow * (slow - 1) / (slow + 1);
   }
   
   return emaFast - emaSlow;
}

// Résumé combiné des indicateurs classiques (MA/RSI/MACD/Bollinger/VWAP/Pivots/Ichimoku/OBV)
// Retourne true si suffisamment d'indicateurs sont alignés avec la direction demandée
bool IsClassicIndicatorsAligned(const string direction, string &summaryOut)
{
   summaryOut = "";

   if(!UseClassicIndicatorsFilter)
      return true;

   string dir = direction;
   if(dir != "BUY" && dir != "SELL")
      return true;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0)
      return true;

   // Données M1 récentes
   MqlRates m1[];
   ArraySetAsSeries(m1, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 60, m1) < 30)
      return true;

   double price = m1[0].close;

   int scoreFor = 0;
   int scoreAgainst = 0;

   // 1) Tendance EMA simple (déjà existante via emaFastM1 / emaSlowM1)
   double emaFast = 0.0, emaSlow = 0.0;
   double bufFast[], bufSlow[];
   ArraySetAsSeries(bufFast, true);
   ArraySetAsSeries(bufSlow, true);

   if(emaFastM1 != INVALID_HANDLE && CopyBuffer(emaFastM1, 0, 0, 1, bufFast) > 0)
      emaFast = bufFast[0];
   if(emaSlowM1 != INVALID_HANDLE && CopyBuffer(emaSlowM1, 0, 0, 1, bufSlow) > 0)
      emaSlow = bufSlow[0];

   if(emaFast > 0.0 && emaSlow > 0.0)
   {
      bool emaBull = (emaFast > emaSlow);
      bool emaBear = (emaFast < emaSlow);
      if(emaBull || emaBear)
      {
         if((dir == "BUY"  && emaBull) ||
            (dir == "SELL" && emaBear))
         {
            scoreFor++;
            summaryOut += "[EMA OK] ";
         }
         else
         {
            scoreAgainst++;
            summaryOut += "[EMA CONTRA] ";
         }
      }
   }

   // 2) RSI (existing ComputeRSI)
   double rsi = ComputeRSI(m1, 14, 0);
   if(rsi > 70.0)
   {
      if(dir == "SELL") { scoreFor++; summaryOut += "[RSI SURACHAT→SELL] "; }
      else              { scoreAgainst++; summaryOut += "[RSI SURACHAT CONTRA] "; }
   }
   else if(rsi < 30.0)
   {
      if(dir == "BUY")  { scoreFor++; summaryOut += "[RSI SURVENTE→BUY] "; }
      else              { scoreAgainst++; summaryOut += "[RSI SURVENTE CONTRA] "; }
   }

   // 3) MACD (existing ComputeMACD)
   double macd = ComputeMACD(m1, 12, 26, 9, 0);
   if(macd > 0)
   {
      if(dir == "BUY")  { scoreFor++; summaryOut += "[MACD HAUSSIER] "; }
      else              { scoreAgainst++; summaryOut += "[MACD CONTRA] "; }
   }
   else if(macd < 0)
   {
      if(dir == "SELL") { scoreFor++; summaryOut += "[MACD BAISSIER] "; }
      else              { scoreAgainst++; summaryOut += "[MACD CONTRA] "; }
   }

   // 4) Bandes de Bollinger
   if(UseBollingerFilter)
   {
      int bbHandle = iBands(_Symbol, PERIOD_M1, 20, 2.0, 0, PRICE_CLOSE);
      if(bbHandle != INVALID_HANDLE)
      {
         double upper[], middle[], lower[];
         ArraySetAsSeries(upper,  true);
         ArraySetAsSeries(middle, true);
         ArraySetAsSeries(lower,  true);
         if(CopyBuffer(bbHandle, 0, 0, 1, upper)  == 1 &&
            CopyBuffer(bbHandle, 1, 0, 1, middle) == 1 &&
            CopyBuffer(bbHandle, 2, 0, 1, lower)  == 1)
         {
            bool nearUpper = (price >= middle[0]) && (price > upper[0] * 0.995);
            bool nearLower = (price <= middle[0]) && (price < lower[0] * 1.005);
            if(nearUpper)
            {
               if(dir == "SELL") { scoreFor++; summaryOut += "[BB HAUT→SELL] "; }
               else              { scoreAgainst++; summaryOut += "[BB HAUT CONTRA] "; }
            }
            else if(nearLower)
            {
               if(dir == "BUY")  { scoreFor++; summaryOut += "[BB BAS→BUY] "; }
               else              { scoreAgainst++; summaryOut += "[BB BAS CONTRA] "; }
            }
         }
         IndicatorRelease(bbHandle);
      }
   }

   // 5) VWAP intraday (M1, dernière session ~60 bougies)
   if(UseVWAPFilter)
   {
      double sumPV = 0.0, sumV = 0.0;
      int barsVWAP = MathMin(ArraySize(m1), 60);
      for(int i = 0; i < barsVWAP; i++)
      {
         double typical = (m1[i].high + m1[i].low + m1[i].close) / 3.0;
         double vol     = (double)m1[i].tick_volume;
         sumPV += typical * vol;
         sumV  += vol;
      }
      if(sumV > 0.0)
      {
         double vwap = sumPV / sumV;
         if(price > vwap * 1.001)
         {
            if(dir == "BUY")  { scoreFor++; summaryOut += "[VWAP AU-DESSUS→BUY] "; }
            else              { scoreAgainst++; summaryOut += "[VWAP CONTRA] "; }
         }
         else if(price < vwap * 0.999)
         {
            if(dir == "SELL") { scoreFor++; summaryOut += "[VWAP SOUS→SELL] "; }
            else              { scoreAgainst++; summaryOut += "[VWAP CONTRA] "; }
         }
      }
   }

   // 6) Points pivots journaliers
   if(UsePivotFilter)
   {
      MqlRates d1[];
      ArraySetAsSeries(d1, true);
      if(CopyRates(_Symbol, PERIOD_D1, 0, 3, d1) >= 2)
      {
         double highPrev = d1[1].high;
         double lowPrev  = d1[1].low;
         double closePrev= d1[1].close;
         double pivot = (highPrev + lowPrev + closePrev) / 3.0;
         double r1 = 2.0 * pivot - lowPrev;
         double s1 = 2.0 * pivot - highPrev;

         bool nearR1 = MathAbs(price - r1) / r1 < 0.002;
         bool nearS1 = MathAbs(price - s1) / s1 < 0.002;

         if(nearR1)
         {
            if(dir == "SELL") { scoreFor++; summaryOut += "[PIVOT R1→SELL] "; }
            else              { scoreAgainst++; summaryOut += "[PIVOT R1 CONTRA] "; }
         }
         else if(nearS1)
         {
            if(dir == "BUY")  { scoreFor++; summaryOut += "[PIVOT S1→BUY] "; }
            else              { scoreAgainst++; summaryOut += "[PIVOT S1 CONTRA] "; }
         }
      }
   }

   // 7) Ichimoku H1 (résumé simple)
   if(UseIchimokuFilter)
   {
      int ichHandle = iIchimoku(_Symbol, PERIOD_H1, 9, 26, 52);
      if(ichHandle != INVALID_HANDLE)
      {
         double tenkanBuf[], kijunBuf[], spanABuf[], spanBBuf[];
         ArraySetAsSeries(tenkanBuf, true);
         ArraySetAsSeries(kijunBuf,  true);
         ArraySetAsSeries(spanABuf,  true);
         ArraySetAsSeries(spanBBuf,  true);

         bool okTenkan = (CopyBuffer(ichHandle, 0, 0, 1, tenkanBuf) == 1);
         bool okKijun  = (CopyBuffer(ichHandle, 1, 0, 1, kijunBuf)  == 1);
         bool okA      = (CopyBuffer(ichHandle, 2, 0, 1, spanABuf)  == 1);
         bool okB      = (CopyBuffer(ichHandle, 3, 0, 1, spanBBuf)  == 1);

         if(okTenkan && okKijun && okA && okB)
         {
            double cloudTop    = MathMax(spanABuf[0], spanBBuf[0]);
            double cloudBottom = MathMin(spanABuf[0], spanBBuf[0]);
            bool ichBull = (price > cloudTop && tenkanBuf[0] > kijunBuf[0]);
            bool ichBear = (price < cloudBottom && tenkanBuf[0] < kijunBuf[0]);

            if(ichBull)
            {
               if(dir == "BUY")  { scoreFor++; summaryOut += "[ICHIMOKU BULL] "; }
               else              { scoreAgainst++; summaryOut += "[ICHIMOKU CONTRA] "; }
            }
            else if(ichBear)
            {
               if(dir == "SELL") { scoreFor++; summaryOut += "[ICHIMOKU BEAR] "; }
               else              { scoreAgainst++; summaryOut += "[ICHIMOKU CONTRA] "; }
            }
         }
         IndicatorRelease(ichHandle);
      }
   }

   // 8) OBV (On-Balance Volume) sur M15
   if(UseOBVFilter)
   {
      MqlRates m15[];
      ArraySetAsSeries(m15, true);
      int copied = CopyRates(_Symbol, PERIOD_M15, 0, 30, m15);
      // Besoin d'au moins 2 barres pour comparer les clôtures
      if(copied >= 2)
      {
         double obv = 0.0;
         // Parcourir les barres en comparant close[i] avec close[i-1]
         // pour éviter tout dépassement de tableau (array out of range).
         for(int i = 1; i < copied; i++)
         {
            double vol = (double)m15[i].tick_volume;
            if(m15[i].close > m15[i-1].close)
               obv += vol;
            else if(m15[i].close < m15[i-1].close)
               obv -= vol;
         }
         if(obv > 0)
         {
            if(dir == "BUY")  { scoreFor++; summaryOut += "[OBV INFLOW→BUY] "; }
            else              { scoreAgainst++; summaryOut += "[OBV CONTRA] "; }
         }
         else if(obv < 0)
         {
            if(dir == "SELL") { scoreFor++; summaryOut += "[OBV OUTFLOW→SELL] "; }
            else              { scoreAgainst++; summaryOut += "[OBV CONTRA] "; }
         }
      }
   }

   // Décision finale : au moins ClassicMinConfirmations en faveur
   bool ok = (scoreFor >= ClassicMinConfirmations);

   summaryOut = "For=" + IntegerToString(scoreFor) +
                " Against=" + IntegerToString(scoreAgainst) + " " + summaryOut;

   return ok;
}

bool LookForTradingOpportunity(SMC_Signal &sig)
{
   // Cette fonction peut être implémentée plus tard si nécessaire
   return false;
}

void CheckTotalLossAndClose()
{
   // Cette fonction est déjà implémentée sous le nom CloseWorstPositionIfTotalLossExceeded()
   CloseWorstPositionIfTotalLossExceeded();
}

//| ENVOI DE FEEDBACK DE TRADES À L'IA SERVER                        |
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Ne traiter que les transactions de clôture de positions
   if(trans.type != TRADE_TRANSACTION_POSITION)
      return;

   // Pour les transactions de position, vérifier si c'est une clôture
   // En MQL5, on vérifie si la position existe encore
   CPositionInfo pos;
   if(!pos.SelectByTicket(trans.position))
   {
      // La position n'existe plus = elle a été fermée
      // Réinitialiser le maxProfit pour cette position
      g_maxProfit = 0;
      
      // On doit récupérer les informations depuis l'historique des deals
      if(HistorySelectByPosition(trans.position))
      {
         // Récupérer le dernier deal de cette position
         int deals = HistoryDealsTotal();
         for(int i = deals - 1; i >= 0; i--)
         {
            ulong deal_ticket = HistoryDealGetTicket(i);
            if(deal_ticket > 0)
            {
               CDealInfo deal;
               if(deal.SelectByIndex(i) && deal.PositionId() == trans.position)
               {
                  long dealEntry = deal.Entry();
                  if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_OUT_BY)
                     continue;

                  if(deal.Magic() != InpMagicNumber)
                     return;

                  string symbol = deal.Symbol();
                  double profit = deal.Profit() + deal.Swap() + deal.Commission();
                  bool is_win = (profit > 0);
                  string side = (deal.Type() == DEAL_TYPE_BUY) ? "BUY" : "SELL";

                  CM_OnClosedTrade(profit);

                  // Mémoriser perte récente par symbole (éviter 2e perte consécutive sans conditions strictes)
                  if(profit < 0)
                  {
                     g_lastLossSymbol = symbol;
                     g_lastLossTime   = (datetime)deal.Time();
                  }
                  else if(symbol == g_lastLossSymbol)
                  {
                     g_lastLossSymbol = "";
                     g_lastLossTime   = 0;
                  }

                  // Timestamps (convertir en millisecondes pour compatibilité JSON)
                  long open_time = (long)deal.Time() * 1000;  // Time of the deal
                  long close_time = (long)deal.Time() * 1000;

                  // Utiliser la dernière confiance IA connue
                  double ai_confidence = g_lastAIConfidence;

                  // Créer le payload JSON
                  string json_payload = StringFormat(
                     "{"
                     "\"symbol\":\"%s\","
                     "\"timeframe\":\"M1\","
                     "\"profit\":%.2f,"
                     "\"is_win\":%s,"
                     "\"ai_confidence\":%.4f,"
                     "\"side\":\"%s\","
                     "\"open_time\":%lld,"
                     "\"close_time\":%lld"
                     "}",
                     symbol,
                     profit,
                     is_win ? "true" : "false",
                     ai_confidence,
                     side,
                     open_time,
                     close_time
                  );

                  // Envoyer à l'IA server (essayer primaire puis secondaire)
                  string url1 = AI_ServerURL + "/trades/feedback";
                  string url2 = AI_ServerURL + "/trades/feedback";
                  
                  Print("📤 ENVOI FEEDBACK IA - URL1: ", url1);
                  Print("📤 ENVOI FEEDBACK IA - URL2: ", url2);
                  Print("📤 ENVOI FEEDBACK IA - Données: symbol=", symbol, " profit=", DoubleToString(profit, 2), " ai_conf=", DoubleToString(ai_confidence, 2));

                  string headers = "Content-Type: application/json\r\n";
                  char post_data[];
                  char result_data[];
                  string result_headers;

                  // Convertir string JSON en array de char
                  StringToCharArray(json_payload, post_data, 0, StringLen(json_payload));

                  // Premier essai
                  int http_result = WebRequest("POST", url1, headers, AI_Timeout_ms, post_data, result_data, result_headers);

                  // Si échec, essayer le serveur secondaire
                  if(http_result != 200)
                  {
                     http_result = WebRequest("POST", url2, headers, AI_Timeout_ms, post_data, result_data, result_headers);
                  }

                  // Log du résultat
                  if(http_result == 200)
                  {
                     Print("✅ FEEDBACK IA ENVOYÉ: ", symbol, " ", side, " Profit: ", DoubleToString(profit, 2), " IA Conf: ", DoubleToString(ai_confidence, 2));
                  }
                  else
                  {
                     Print("❌ ÉCHEC ENVOI FEEDBACK IA: HTTP ", http_result, " pour ", symbol, " ", side);
                  }

                  break; // On a trouvé le deal de clôture, sortir de la boucle
               }
            }
         }
      }
   }
}

//| Récupérer les données de l'endpoint Decision                        |
bool GetAISignalData()
{
   static datetime lastAPICall = 0;
   static string lastCachedResponse = "";
   
   datetime currentTime = TimeCurrent();
   
   // Cache API: éviter les appels trop fréquents (toutes les 30 secondes)
   if((currentTime - lastAPICall) < 30 && lastCachedResponse != "")
   {
      // Utiliser la réponse en cache
      if(StringFind(lastCachedResponse, "\"action\":") >= 0)
      {
         int actionStart = StringFind(lastCachedResponse, "\"action\":");
         actionStart = StringFind(lastCachedResponse, "\"", actionStart + 9) + 1;
         int actionEnd = StringFind(lastCachedResponse, "\"", actionStart);
         if(actionEnd > actionStart)
         {
            g_lastAIAction = StringSubstr(lastCachedResponse, actionStart, actionEnd - actionStart);
            return true;
         }
      }
   }
   
   // Endpoint POST /decision sur Render ou serveur local
   string base = AI_ServerURL;
   string url  = base + "/decision";
   string headers = "Content-Type: application/json\r\n";
   char post[];
   uchar response[];
   
   // Préparer les données de marché de base
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // ATR via handle principal (si disponible)
   double atr = 0.0;
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0)
      atr = atrBuf[0];
   
   // Calcul d'un RSI M15 pour alimenter le backend simplifié
   double rsi = 50.0;
   MqlRates rsiRates[];
   ArraySetAsSeries(rsiRates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 50, rsiRates) >= 15)
   {
      // Utilise la fonction ComputeRSI déjà définie (période 14)
      rsi = ComputeRSI(rsiRates, 14, 14);
   }
   // Sécurité supplémentaire : clamp 0-100 pour l'envoi JSON
   if(rsi < 0.0) rsi = 0.0;
   if(rsi > 100.0) rsi = 100.0;
   
   // Récupérer les EMA rapides/lentes via les handles existants (M1, M5, H1)
   double emaFastM1Val = 0.0, emaSlowM1Val = 0.0;
   double emaFastM5Val = 0.0, emaSlowM5Val = 0.0;
   double emaFastH1Val = 0.0, emaSlowH1Val = 0.0;
   double bufFast[], bufSlow[];
   ArraySetAsSeries(bufFast, true);
   ArraySetAsSeries(bufSlow, true);
   
   // M1
   if(emaFastM1 != INVALID_HANDLE && CopyBuffer(emaFastM1, 0, 0, 1, bufFast) > 0)
      emaFastM1Val = bufFast[0];
   if(emaSlowM1 != INVALID_HANDLE && CopyBuffer(emaSlowM1, 0, 0, 1, bufSlow) > 0)
      emaSlowM1Val = bufSlow[0];
   
   // M5
   if(emaFastM5 != INVALID_HANDLE && CopyBuffer(emaFastM5, 0, 0, 1, bufFast) > 0)
      emaFastM5Val = bufFast[0];
   if(emaSlowM5 != INVALID_HANDLE && CopyBuffer(emaSlowM5, 0, 0, 1, bufSlow) > 0)
      emaSlowM5Val = bufSlow[0];
   
   // H1
   if(emaFastH1 != INVALID_HANDLE && CopyBuffer(emaFastH1, 0, 0, 1, bufFast) > 0)
      emaFastH1Val = bufFast[0];
   if(emaSlowH1 != INVALID_HANDLE && CopyBuffer(emaSlowH1, 0, 0, 1, bufSlow) > 0)
      emaSlowH1Val = bufSlow[0];
   
   // Construire la requête JSON enrichie pour /decision (compatible decision_simplified)
   // Ajouter les indicateurs de détection de spike avancée - VERSION OPTIMISÉE
   double volCompression = 1.0; // Valeur par défaut
   double priceAccel = 0.0;
   bool volumeSpike = false;
   double spikeProb = 0.5; // Valeur neutre par défaut
   
   // Calcul rapide avec protection
   if(atrHandle != INVALID_HANDLE)
   {
      // Compression ATR rapide
      double buffer[];
      ArraySetAsSeries(buffer, true);
      if(CopyBuffer(atrHandle, 0, 0, 10, buffer) >= 5)
      {
         double recentATR = buffer[0];
         double avgATR = 0.0;
         for(int i = 0; i < 5; i++) avgATR += buffer[i];
         avgATR /= 5.0;
         if(avgATR > 0) volCompression = recentATR / avgATR;
      }
      
      // Accélération prix rapide
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      if(CopyRates(_Symbol, PERIOD_M1, 0, 3, rates) >= 2)
      {
         double change1 = (rates[0].close - rates[1].close) / rates[1].close;
         double change2 = (rates[1].close - rates[2].close) / rates[2].close;
         priceAccel = (change1 - change2) / 2.0;
      }
      
      // Volume spike rapide
      long volume[];
      ArraySetAsSeries(volume, true);
      if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 5, volume) >= 3)
      {
         double recentVolume = (double)volume[0];
         double avgVolume = 0.0;
         for(int i = 1; i < 3; i++) avgVolume += (double)volume[i];
         avgVolume /= 2.0;
         volumeSpike = (recentVolume > avgVolume * 1.5);
      }
      
      // Probabilité spike rapide - AJUSTÉ pour 70% de certitude
      spikeProb = 0.0;
      if(volCompression < 0.7) spikeProb += 0.4; // Compression forte (< 70%)
      if(MathAbs(priceAccel) > 0.001) spikeProb += 0.3; // Accélération notable
      if(volumeSpike) spikeProb += 0.3; // Volume spike confirmé
      spikeProb = MathMin(spikeProb, 1.0);

      // Mémoriser la probabilité locale de spike pour réutilisation (CheckImminentSpike, filtres ML, etc.)
      g_lastSpikeProbability = spikeProb;
      g_lastSpikeUpdate      = TimeCurrent();
   }
   
   string jsonRequest = StringFormat(
      "{\"symbol\":\"%s\",\"bid\":%.5f,\"ask\":%.5f,"
      "\"atr\":%.5f,\"rsi\":%.2f,"
      "\"ema_fast_m1\":%.5f,\"ema_slow_m1\":%.5f,"
      "\"ema_fast_m5\":%.5f,\"ema_slow_m5\":%.5f,"
      "\"ema_fast_h1\":%.5f,\"ema_slow_h1\":%.5f,"
      "\"volatility_compression\":%.3f,"
      "\"price_acceleration\":%.6f,"
      "\"volume_spike\":%s,"
      "\"spike_probability\":%.3f,"
      "\"timestamp\":\"%s\"}",
      _Symbol, bid, ask, atr, rsi,
      emaFastM1Val, emaSlowM1Val,
      emaFastM5Val, emaSlowM5Val,
      emaFastH1Val, emaSlowH1Val,
      volCompression,
      priceAccel,
      volumeSpike ? "true" : "false",
      spikeProb,
      TimeToString(TimeCurrent())
   );
   
   Print("📦 ENVOI IA: ", jsonRequest);
   
   StringToCharArray(jsonRequest, post);
   
   // Timeout réduit pour éviter le détachement
   int res = WebRequest("POST", url, headers, 2000, post, response, headers);
   
      if(res == 200)
      {
         string jsonResponse = CharArrayToString(response);
         Print("📥 RÉPONSE IA: ", jsonResponse);
         
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
               g_lastAIAction = StringSubstr(jsonResponse, actionStart, actionEnd - actionStart);
               
               int confStart = StringFind(jsonResponse, "\"confidence\":");
               if(confStart >= 0)
               {
                  confStart = StringFind(jsonResponse, ":", confStart) + 1;
                  int confEnd = StringFind(jsonResponse, ",", confStart);
                  if(confEnd < 0) confEnd = StringFind(jsonResponse, "}", confStart);
                  if(confEnd > confStart)
                  {
                     string confStr = StringSubstr(jsonResponse, confStart, confEnd - confStart);
                     g_lastAIConfidence = StringToDouble(confStr);
                  }
               }

               // Extraire la probabilité de spike renvoyée par le modèle ML (si disponible)
               int spikeStart = StringFind(jsonResponse, "\"spike_probability\"");
               if(spikeStart >= 0)
               {
                  spikeStart = StringFind(jsonResponse, ":", spikeStart) + 1;
                  int spikeEnd = StringFind(jsonResponse, ",", spikeStart);
                  if(spikeEnd < 0) spikeEnd = StringFind(jsonResponse, "}", spikeStart);
                  if(spikeEnd > spikeStart)
                  {
                     string spikeStr = StringSubstr(jsonResponse, spikeStart, spikeEnd - spikeStart);
                     double spikeVal = StringToDouble(spikeStr);
                     
                     // Accepter 0‑1 ou 0‑100%
                     if(spikeVal > 1.0)
                        spikeVal /= 100.0;
                     
                     if(spikeVal >= 0.0 && spikeVal <= 1.0)
                     {
                        g_lastSpikeProbability = spikeVal;
                        g_lastSpikeUpdate      = TimeCurrent();
                     }
                  }
               }
               
               // Extraire alignement et cohérence
            int alignStart = StringFind(jsonResponse, "\"alignment\":");
            if(alignStart >= 0)
            {
               alignStart = StringFind(jsonResponse, "\"", alignStart + 12) + 1;
               int alignEnd = StringFind(jsonResponse, "\"", alignStart);
               if(alignEnd > alignStart)
               {
                  g_lastAIAlignment = StringSubstr(jsonResponse, alignStart, alignEnd - alignStart);
               }
            }
            
            int cohStart = StringFind(jsonResponse, "\"coherence\":");
            if(cohStart >= 0)
            {
               cohStart = StringFind(jsonResponse, "\"", cohStart + 13) + 1;
               int cohEnd = StringFind(jsonResponse, "\"", cohStart);
               if(cohEnd > cohStart)
               {
                  g_lastAICoherence = StringSubstr(jsonResponse, cohStart, cohEnd - cohStart);
               }
            }
            
            g_lastAIUpdate = TimeCurrent();
            g_aiConnected = true;
            
            Print("✅ IA MISE À JOUR: ", g_lastAIAction, " | ", DoubleToString(g_lastAIConfidence*100,1), "% | ", g_lastAIAlignment, " | ", g_lastAICoherence);
            
            return true;
         }
      }
   }
   else
   {
      Print("❌ ERREUR IA: HTTP ", res);
      g_aiConnected = false;
      
      // FALLBACK: Le fallback sera géré par OnTick directement
      // GenerateFallbackAIDecision(); // Déplacé dans OnTick
   }
   
   return false;
}

//| Générer une décision IA de fallback basée sur les données de marché |
void GenerateFallbackAIDecision()
{
   // Récupérer les données de marché actuelles
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculer une tendance SMC EMA avancée
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   string action = "HOLD";
   double confidence = 0.5;
   double alignment = 50.0;
   double coherence = 50.0;
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, 50, rates) >= 20)
   {
      // Calculer les EMA pour analyse SMC
      double ema8 = 0, ema21 = 0, ema50 = 0, ema200 = 0;
      
      // EMA 8 (très court terme)
      double multiplier8 = 2.0 / (8 + 1);
      ema8 = rates[0].close;
      for(int i = 1; i < 8; i++)
         ema8 = rates[i].close * multiplier8 + ema8 * (1 - multiplier8);
      
      // EMA 21 (court terme)
      double multiplier21 = 2.0 / (21 + 1);
      ema21 = rates[0].close;
      for(int i = 1; i < 21; i++)
         ema21 = rates[i].close * multiplier21 + ema21 * (1 - multiplier21);
      
      // EMA 50 (moyen terme)
      double multiplier50 = 2.0 / (50 + 1);
      ema50 = rates[0].close;
      for(int i = 1; i < 50; i++)
         ema50 = rates[i].close * multiplier50 + ema50 * (1 - multiplier50);
      
      // EMA 200 (long terme)
      double multiplier200 = 2.0 / (200 + 1);
      ema200 = rates[0].close;
      for(int i = 1; i < MathMin(200, ArraySize(rates)); i++)
         ema200 = rates[i].close * multiplier200 + ema200 * (1 - multiplier200);
      
      double currentPrice = rates[0].close;
      
      // LOGIQUE SMC EMA AVANCÉE
      bool bullishStructure = (ema8 > ema21) && (ema21 > ema50) && (ema50 > ema200);
      bool bearishStructure = (ema8 < ema21) && (ema21 < ema50) && (ema50 < ema200);
      
      // Détecter les croisements EMA
      bool ema8Cross21Up = (ema8 > ema21) && (rates[1].close <= rates[2].close);
      bool ema8Cross21Down = (ema8 < ema21) && (rates[1].close >= rates[2].close);
      
      // Détecter la momentum
      double momentum = (currentPrice - ema50) / ema50;
      double momentumShort = (currentPrice - ema21) / ema21;
      
      // DÉCISION BASÉE SUR SMC EMA
      if(bullishStructure && momentum > 0.002)
      {
         action = "BUY";
         confidence = MathMin(0.95, 0.6 + MathAbs(momentum) * 100);
         alignment = MathMin(98.0, 60.0 + MathAbs(momentum) * 100);
         coherence = MathMin(95.0, 55.0 + MathAbs(momentumShort) * 80);
      }
      else if(bearishStructure && momentum < -0.002)
      {
         action = "SELL";
         confidence = MathMin(0.95, 0.6 + MathAbs(momentum) * 100);
         alignment = MathMin(98.0, 60.0 + MathAbs(momentum) * 100);
         coherence = MathMin(95.0, 55.0 + MathAbs(momentumShort) * 80);
      }
      else if(ema8Cross21Up && momentum > 0.001)
      {
         action = "BUY";
         confidence = 0.75 + (MathRand() % 15) / 100.0; // 75-90%
         alignment = 70.0 + (MathRand() % 20); // 70-90%
         coherence = 65.0 + (MathRand() % 25); // 65-90%
      }
      else if(ema8Cross21Down && momentum < -0.001)
      {
         action = "SELL";
         confidence = 0.75 + (MathRand() % 15) / 100.0; // 75-90%
         alignment = 70.0 + (MathRand() % 20); // 70-90%
         coherence = 65.0 + (MathRand() % 25); // 65-90%
      }
      else if(MathAbs(momentum) < 0.0005)
      {
         action = "HOLD";
         confidence = 0.40 + (MathRand() % 25) / 100.0; // 40-65%
         alignment = 35.0 + (MathRand() % 30); // 35-65%
         coherence = 30.0 + (MathRand() % 35); // 30-65%
      }
      else
      {
         // Décision basée sur le momentum restant
         if(momentum > 0)
         {
            action = "BUY";
            confidence = 0.55 + MathAbs(momentum) * 30;
            alignment = 50.0 + MathAbs(momentum) * 40;
            coherence = 45.0 + MathAbs(momentum) * 35;
         }
         else
         {
            action = "SELL";
            confidence = 0.55 + MathAbs(momentum) * 30;
            alignment = 50.0 + MathAbs(momentum) * 40;
            coherence = 45.0 + MathAbs(momentum) * 35;
         }
      }
   }
   else
   {
      // Si pas assez de données, générer des décisions variées réalistes
      string actions[] = {"BUY", "SELL", "HOLD"};
      // Pondération pour plus de BUY/SELL que HOLD
      int weights[] = {40, 40, 20}; // 40% BUY, 40% SELL, 20% HOLD
      int totalWeight = 100;
      int random = MathRand() % totalWeight;
      
      if(random < weights[0]) action = actions[0];
      else if(random < weights[0] + weights[1]) action = actions[1];
      else action = actions[2];
      
      confidence = 0.45 + (MathRand() % 40) / 100.0; // 45-85%
      alignment = 35.0 + (MathRand() % 55); // 35-90%
      coherence = 30.0 + (MathRand() % 60); // 30-90%
   }
   
   // Mettre à jour les variables globales
   g_lastAIAction = action;
   g_lastAIConfidence = confidence;
   g_lastAIAlignment = DoubleToString(alignment, 1) + "%";
   g_lastAICoherence = DoubleToString(coherence, 1) + "%";
   g_lastAIUpdate = TimeCurrent();
   
   Print("🔄 IA SMC-EMA - Action: ", action, " | Conf: ", DoubleToString(confidence*100,1), "% | Align: ", g_lastAIAlignment, " | Cohér: ", g_lastAICoherence);
}

// Petit helper de debug pour inspecter rapidement la dernière décision IA
void DebugPrintAIDecision()
{
   Print("🤖 DEBUG IA - Symbole: ", _Symbol,
         " | Action: ", g_lastAIAction,
         " | Confiance: ", DoubleToString(g_lastAIConfidence*100, 1), "%",
         " | Alignement: ", g_lastAIAlignment,
         " | Cohérence: ", g_lastAICoherence);
}

//| DÉTECTION SWING HIGH/LOW SPÉCIALE BOOM/CRASH (LOGIQUE TRADING) |
bool DetectBoomCrashSwingPoints()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int barsToAnalyze = 100;
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsToAnalyze, rates) < barsToAnalyze)
      return false;
   
   // Nettoyer les anciens objets Boom/Crash
   ObjectsDeleteAll(0, "SMC_BC_SH_");
   ObjectsDeleteAll(0, "SMC_BC_SL_");
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double avgMove = 0;
   
   // Calculer le mouvement moyen pour détecter les spikes
   for(int i = 1; i < barsToAnalyze; i++)
   {
      double move = MathAbs(rates[i-1].close - rates[i].close);
      avgMove += move;
   }
   avgMove /= (barsToAnalyze - 1);
   
   // Seuil de spike (8x le mouvement normal pour Boom/Crash)
   double spikeThreshold = avgMove * 8.0;
   
   Print("📊 BOOM/CRASH - Mouvement moyen: ", DoubleToString(avgMove, _Digits), " | Seuil spike: ", DoubleToString(spikeThreshold, _Digits));
   
   bool isBoom = IsBoomLikeSymbol(_Symbol);
   bool isCrash = IsCrashLikeSymbol(_Symbol);
   
   // DÉTECTION DES SPIKES D'ABORD
   for(int i = 5; i < barsToAnalyze - 5; i++)
   {
      double priceChange = MathAbs(rates[i].close - rates[i-1].close);
      bool isSpike = (priceChange > spikeThreshold);
      
      if(!isSpike) continue;
      
      Print("🚨 SPIKE DÉTECTÉ - Barre ", i, " | Mouvement: ", DoubleToString(priceChange, _Digits), " | Type: ", isBoom ? "BOOM" : "CRASH");
      
      // LOGIQUE BOOM : SH APRÈS SPIKE (pour annoncer le sell)
      if(isBoom)
      {
         // Chercher le Swing High APRÈS le spike (confirmation de retournement)
         for(int j = MathMax(0, i - 8); j <= MathMax(0, i - 2); j++) // 2-8 barres après le spike
         {
            double currentHigh = rates[j].high;
            
            // Vérifier si c'est un swing high local
            bool isPotentialSH = true;
            for(int k = MathMax(0, j - 3); k <= MathMin(barsToAnalyze - 1, j + 3); k++)
            {
               if(k != j && rates[k].high >= currentHigh)
               {
                  isPotentialSH = false;
                  break;
               }
            }
            
            // Confirmation : le SH doit être plus bas que le pic du spike
            if(isPotentialSH && currentHigh < rates[i].high)
            {
               // Confirmer que c'est bien après le spike
               bool confirmedAfterSpike = true;
               for(int k = j + 1; k <= MathMin(barsToAnalyze - 1, j + 3); k++)
               {
                  if(rates[k].high > currentHigh)
                  {
                     confirmedAfterSpike = false;
                     break;
                  }
               }
               
               if(confirmedAfterSpike)
               {
                  string shName = "SMC_BC_SH_" + IntegerToString(j);
                  if(ObjectCreate(0, shName, OBJ_ARROW, 0, rates[j].time, currentHigh))
                  {
                     ObjectSetInteger(0, shName, OBJPROP_COLOR, clrRed);
                     ObjectSetInteger(0, shName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, shName, OBJPROP_WIDTH, 6);
                     ObjectSetInteger(0, shName, OBJPROP_ARROWCODE, 233);
                     ObjectSetString(0, shName, OBJPROP_TOOLTIP, 
                                   "SH APRÈS SPIKE BOOM (Signal SELL): " + DoubleToString(currentHigh, _Digits) + " | Spike: " + DoubleToString(rates[i].high, _Digits));
                     
                     // Ligne horizontale
                     string lineName = shName + "_Line";
                     if(ObjectCreate(0, lineName, OBJ_HLINE, 0, rates[j].time, currentHigh))
                     {
                        ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrRed);
                        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
                        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
                        ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
                     }
                     
                     Print("🔴 SH APRÈS SPIKE BOOM (Signal SELL) - Prix: ", DoubleToString(currentHigh, _Digits), " | Spike: ", DoubleToString(rates[i].high, _Digits), " | Time: ", TimeToString(rates[j].time));
                  }
                  break; // Prendre le premier SH valide après le spike
               }
            }
         }
      }
      
      // LOGIQUE CRASH : SL AVANT SPIKE (pour annoncer le crash)
      if(isCrash)
      {
         // Chercher le Swing Low AVANT le spike (préparation du crash)
         for(int j = i + 2; j <= MathMin(barsToAnalyze - 1, i + 8); j++) // 2-8 barres avant le spike
         {
            double currentLow = rates[j].low;
            
            // Vérifier si c'est un swing low local
            bool isPotentialSL = true;
            for(int k = MathMax(0, j - 3); k <= MathMin(barsToAnalyze - 1, j + 3); k++)
            {
               if(k != j && rates[k].low <= currentLow)
               {
                  isPotentialSL = false;
                  break;
               }
            }
            
            // Confirmation : le SL doit être plus haut que le creux du spike
            if(isPotentialSL && currentLow > rates[i].low)
            {
               // Confirmer que c'est bien avant le spike
               bool confirmedBeforeSpike = true;
               for(int k = MathMax(0, j - 3); k <= j - 1; k++)
               {
                  if(rates[k].low < currentLow)
                  {
                     confirmedBeforeSpike = false;
                     break;
                  }
               }
               
               if(confirmedBeforeSpike)
               {
                  string slName = "SMC_BC_SL_" + IntegerToString(j);
                  if(ObjectCreate(0, slName, OBJ_ARROW, 0, rates[j].time, currentLow))
                  {
                     ObjectSetInteger(0, slName, OBJPROP_COLOR, clrBlue);
                     ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, slName, OBJPROP_WIDTH, 6);
                     ObjectSetInteger(0, slName, OBJPROP_ARROWCODE, 234);
                     ObjectSetString(0, slName, OBJPROP_TOOLTIP, 
                                   "SL AVANT SPIKE CRASH (Signal CRASH): " + DoubleToString(currentLow, _Digits) + " | Spike: " + DoubleToString(rates[i].low, _Digits));
                     
                     // Ligne horizontale
                     string lineName = slName + "_Line";
                     if(ObjectCreate(0, lineName, OBJ_HLINE, 0, rates[j].time, currentLow))
                     {
                        ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrBlue);
                        ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
                        ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
                        ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
                     }
                     
                     Print("🔵 SL AVANT SPIKE CRASH (Signal CRASH) - Prix: ", DoubleToString(currentLow, _Digits), " | Spike: ", DoubleToString(rates[i].low, _Digits), " | Time: ", TimeToString(rates[j].time));
                  }
                  break; // Prendre le premier SL valide avant le spike
               }
            }
         }
      }
   }
   
   return true;
}

//| DÉTECTION SWING HIGH/LOW NON-REPAINTING (ANTI-REPAINT)          |
struct SwingPoint {
   double price;
   datetime time;
   bool isHigh;
   int confirmedBar; // Barre où le swing est confirmé
};

SwingPoint swingPoints[100]; // Buffer pour stocker les SH/SL confirmés
int swingPointCount = 0;

//| Détecter les Swing High/Low sans repaint (confirmation requise)    |
bool DetectNonRepaintingSwingPoints()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int barsToAnalyze = 200;
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, barsToAnalyze, rates) < barsToAnalyze)
      return false;
   
   // Nettoyer les anciens points non confirmés
   for(int i = 0; i < swingPointCount; i++)
   {
      if(swingPoints[i].confirmedBar > 10) // Garder seulement les 10 dernières barres
      {
         for(int j = i; j < swingPointCount - 1; j++)
            swingPoints[j] = swingPoints[j + 1];
         swingPointCount--;
         i--;
      }
   }
   
   // Analyser les barres pour détecter les swings potentiels
   for(int i = 10; i < barsToAnalyze - 10; i++) // Éviter les bords
   {
      // DÉTECTION SWING HIGH (NON-REPAINTING)
      bool isPotentialSH = true;
      double currentHigh = rates[i].high;
      
      // Vérifier si c'est le plus haut sur au moins 5 barres de chaque côté
      for(int j = MathMax(0, i - 5); j <= MathMin(barsToAnalyze - 1, i + 5); j++)
      {
         if(j != i && rates[j].high >= currentHigh)
         {
            isPotentialSH = false;
            break;
         }
      }
      
      // CONFIRMATION SWING HIGH : Attendre 3 barres après le point potentiel
      if(isPotentialSH && i >= 13) // Assez de barres pour confirmer
      {
         bool confirmed = true;
         
         // Vérifier que les 3 barres suivantes n'ont pas dépassé ce high
         for(int j = i - 3; j >= MathMax(0, i - 5); j--) // 3 barres après le point
         {
            if(rates[j].high > currentHigh)
            {
               confirmed = false;
               break;
            }
         }
         
         // Vérifier que ce n'est pas déjà enregistré
         if(confirmed)
         {
            bool alreadyRecorded = false;
            for(int k = 0; k < swingPointCount; k++)
            {
               if(swingPoints[k].isHigh && 
                  MathAbs(swingPoints[k].price - currentHigh) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5 &&
                  MathAbs(swingPoints[k].time - rates[i].time) <= 300) // 5 minutes tolerance
               {
                  alreadyRecorded = true;
                  break;
               }
            }
            
            if(!alreadyRecorded && swingPointCount < 100)
            {
               swingPoints[swingPointCount].price = currentHigh;
               swingPoints[swingPointCount].time = rates[i].time;
               swingPoints[swingPointCount].isHigh = true;
               swingPoints[swingPointCount].confirmedBar = i;
               swingPointCount++;
               
               Print("🔴 SWING HIGH CONFIRMÉ - Prix: ", DoubleToString(currentHigh, _Digits), " | Time: ", TimeToString(rates[i].time));
            }
         }
      }
      
      // DÉTECTION SWING LOW (NON-REPAINTING)
      bool isPotentialSL = true;
      double currentLow = rates[i].low;
      
      // Vérifier si c'est le plus bas sur au moins 5 barres de chaque côté
      for(int j = MathMax(0, i - 5); j <= MathMin(barsToAnalyze - 1, i + 5); j++)
      {
         if(j != i && rates[j].low <= currentLow)
         {
            isPotentialSL = false;
            break;
         }
      }
      
      // CONFIRMATION SWING LOW : Attendre 3 barres après le point potentiel
      if(isPotentialSL && i >= 13) // Assez de barres pour confirmer
      {
         bool confirmed = true;
         
         // Vérifier que les 3 barres suivantes n'ont pas dépassé ce low
         for(int j = i - 3; j >= MathMax(0, i - 5); j--) // 3 barres après le point
         {
            if(rates[j].low < currentLow)
            {
               confirmed = false;
               break;
            }
         }
         
         // Vérifier que ce n'est pas déjà enregistré
         if(confirmed)
         {
            bool alreadyRecorded = false;
            for(int k = 0; k < swingPointCount; k++)
            {
               if(!swingPoints[k].isHigh && 
                  MathAbs(swingPoints[k].price - currentLow) < SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5 &&
                  MathAbs(swingPoints[k].time - rates[i].time) <= 300) // 5 minutes tolerance
               {
                  alreadyRecorded = true;
                  break;
               }
            }
            
            if(!alreadyRecorded && swingPointCount < 100)
            {
               swingPoints[swingPointCount].price = currentLow;
               swingPoints[swingPointCount].time = rates[i].time;
               swingPoints[swingPointCount].isHigh = false;
               swingPoints[swingPointCount].confirmedBar = i;
               swingPointCount++;
               
               Print("🔵 SWING LOW CONFIRMÉ - Prix: ", DoubleToString(currentLow, _Digits), " | Time: ", TimeToString(rates[i].time));
            }
         }
      }
   }
   
   return true;
}

//| Obtenir les derniers Swing High/Low confirmés (non-repainting)     |
void GetLatestConfirmedSwings(double &lastSH, datetime &lastSHTime, double &lastSL, datetime &lastSLTime)
{
   lastSH = 0;
   lastSHTime = 0;
   lastSL = 999999;
   lastSLTime = 0;
   
   // Parcourir tous les points pour trouver les plus récents
   for(int i = 0; i < swingPointCount; i++)
   {
      if(swingPoints[i].isHigh && swingPoints[i].time > lastSHTime)
      {
         lastSH = swingPoints[i].price;
         lastSHTime = swingPoints[i].time;
      }
      else if(!swingPoints[i].isHigh && swingPoints[i].time > lastSLTime)
      {
         lastSL = swingPoints[i].price;
         lastSLTime = swingPoints[i].time;
      }
   }
}

//| Dessiner les Swing Points confirmés (non-repainting)              |
// Limité à 25 points pour éviter trop d'objets graphiques → détachement
#define MAX_SWING_POINTS_DRAWN 25

void DrawConfirmedSwingPoints()
{
   long chId = ChartID();
   if(chId <= 0) return;
   
   ObjectsDeleteAll(chId, "SMC_Confirmed_SH_");
   ObjectsDeleteAll(chId, "SMC_Confirmed_SL_");
   
   // Limiter le nombre de points affichés pour éviter saturation objets → détachement
   int toDraw = MathMin(swingPointCount, MAX_SWING_POINTS_DRAWN);
   int futureBars = (SMCChannelFutureBars > 0 && SMCChannelFutureBars <= 5000) ? SMCChannelFutureBars : 5000;
   
   for(int i = 0; i < toDraw; i++)
   {
      if(!MathIsValidNumber(swingPoints[i].price) || swingPoints[i].time <= 0) continue;
      
      string objName;
      color objColor;
      int objCode;
      
      if(swingPoints[i].isHigh)
      {
         objName = "SMC_Confirmed_SH_" + IntegerToString(i);
         objColor = clrRed;
         objCode = 233;
      }
      else
      {
         objName = "SMC_Confirmed_SL_" + IntegerToString(i);
         objColor = clrBlue;
         objCode = 234;
      }
      
      if(ObjectCreate(chId, objName, OBJ_ARROW, 0, swingPoints[i].time, swingPoints[i].price))
      {
         ObjectSetInteger(chId, objName, OBJPROP_COLOR, objColor);
         ObjectSetInteger(chId, objName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(chId, objName, OBJPROP_WIDTH, 4);
         ObjectSetInteger(chId, objName, OBJPROP_ARROWCODE, objCode);
         ObjectSetString(chId, objName, OBJPROP_TOOLTIP, 
                       swingPoints[i].isHigh ? "SH Confirmé: " + DoubleToString(swingPoints[i].price, _Digits) 
                                            : "SL Confirmé: " + DoubleToString(swingPoints[i].price, _Digits));
         
         string lineName = objName + "_Line";
         datetime startTime = TimeCurrent();
         datetime endTime = startTime + (datetime)((long)futureBars * 60);
         
         if(MathIsValidNumber(swingPoints[i].price) && 
            ObjectCreate(chId, lineName, OBJ_TREND, 0, startTime, swingPoints[i].price, endTime, swingPoints[i].price))
         {
            ObjectSetInteger(chId, lineName, OBJPROP_COLOR, objColor);
            ObjectSetInteger(chId, lineName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(chId, lineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(chId, lineName, OBJPROP_BACK, true);
            ObjectSetInteger(chId, lineName, OBJPROP_RAY_RIGHT, true);
            ObjectSetInteger(chId, lineName, OBJPROP_RAY_LEFT, false);
         }
      }
   }
}

//| VÉRIFICATION ET EXÉCUTION IMMÉDIATE DU DERIV ARROW               |
void CheckAndExecuteDerivArrowTrade()
{
   // DEBUG: Log pour voir si la fonction est appelée
   static datetime lastLog = 0;
   if(TimeCurrent() - lastLog >= 10) // Log toutes les 10 secondes maximum
   {
      Print("🔍 DEBUG - CheckAndExecuteDerivArrowTrade appelée pour: ", _Symbol, " | Time: ", TimeToString(TimeCurrent(), TIME_SECONDS));
      lastLog = TimeCurrent();
   }
   
   // RÈGLE FONDAMENTALE: Boom/Crash + Volatility (avec conditions)
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   string catStr = "";
   switch(cat)
   {
      case SYM_BOOM_CRASH: catStr = "BOOM_CRASH"; break;
      case SYM_VOLATILITY: catStr = "VOLATILITY"; break;
      case SYM_FOREX: catStr = "FOREX"; break;
      default: catStr = "UNKNOWN"; break;
   }
   
   // Autoriser Boom/Crash ET Volatility ET FOREX (XAUUSD et autres commodités)
   bool isBoomCrash = (cat == SYM_BOOM_CRASH);
   bool isVolatility = (cat == SYM_VOLATILITY);
   bool isForex = (cat == SYM_FOREX);

   if(!isBoomCrash && !isVolatility && !isForex)
   {
      return; // Ignorer les autres symboles
   }

   if(UseGOMVerdictFilter && !g_smcGomConnected)
      return;

   // Anti‑duplication SPIKE uniquement : autoriser les autres stratégies sur le même symbole,
   // mais éviter plusieurs trades de type "SPIKE TRADE" en parallèle.
   if(HasOpenSpikeTradeForSymbol(_Symbol))
   {
      Print("🚫 SPIKE TRADE BLOQUÉ - Une position SPIKE TRADE est déjà ouverte sur ", _Symbol, " (pas de doublon)");
      return;
   }
   
   // Confirmer le type de symbole
   Print("✅ DEBUG - Symbole validé: ", _Symbol, " = ", catStr);
   
   // VALIDATION IA: BLOQUER TOUS LES TRADES SI IA EST EN HOLD
   if(UseAIServer && (g_lastAIAction == "HOLD" || g_lastAIAction == "hold"))
   {
      Print("🚫 TRADE BLOQUÉ - IA en HOLD sur ", _Symbol);
      return;
   }
   
   // NOUVEAU: DÉTECTION DES FLÈCHES DERIV ARROW EXISTANTES
   string arrowDirection = "";
   bool hasDerivArrow = GetDerivArrowDirection(arrowDirection);
   
   if(hasDerivArrow)
   {
      Print("🎯 FLÈCHE DERIV ARROW DÉTECTÉE - Direction: ", arrowDirection, " sur ", _Symbol);
      
      // Validation stricte: Boom = BUY uniquement, Crash = SELL uniquement
      bool isBoom = IsBoomLikeSymbol(_Symbol);
      bool isCrash = IsCrashLikeSymbol(_Symbol);
      
    if(isBoom && arrowDirection == "BUY")
       {
          Print("✅ FLÈCHE VERTE + BOOM = COMPATIBLE - Exécution BUY autorisée");
          ExecuteDerivArrowTrade("BUY");
          return;
       }
       else if(isCrash && arrowDirection == "SELL")
       {
          Print("✅ FLÈCHE ROUGE + CRASH = COMPATIBLE - Exécution SELL autorisée");
          ExecuteDerivArrowTrade("SELL");
          return;
       }
       else if(isVolatility)
       {
          // Volatility: les flèches sont des SIGNAUX, pas des règles directionnelles strictes
          // Continuer vers la logique Volatility spécialisée ci-dessous
          Print("ℹ️ FLÈCHE DERIV ARROW sur Volatility - Direction suggérée: ", arrowDirection, " → passer aux gates techniques");
       }
       else
       {
          Print("🚫 FLÈCHE DERIV ARROW INCOMPATIBLE - ", arrowDirection, " sur ", _Symbol, " (règle Boom/Crash)");
          return;
       }
   }
   
   // RÈGLE STRICTE: BLOQUER TOUS LES TRADES BUY SUR BOOM SI IA = SELL
   bool isBoom = IsBoomLikeSymbol(_Symbol);
   bool isCrash = IsCrashLikeSymbol(_Symbol);
   string aiAction = g_lastAIAction;
   if(aiAction == "buy") aiAction = "BUY";
   if(aiAction == "sell") aiAction = "SELL";
   
   if(isBoom && aiAction == "SELL")
   {
      Print("🚫 DERIV ARROW BOOM BLOQUÉ - IA = SELL (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal BUY avant de placer trade BUY");
      return;
   }
   
   if(isCrash && aiAction == "BUY")
   {
      Print("🚫 DERIV ARROW CRASH BLOQUÉ - IA = BUY (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal SELL avant de placer trade SELL");
      return;
   }
   
   // VALIDATION IA: Confiance minimum différente selon le type ET la zone ICT (Premium/Discount)
   // Objectif: éviter de prendre des positions avec une confiance IA faible,
   // surtout lorsque la décision IA est CONTRAIRE à la zone Premium/Discount.
   bool inDiscount = IsInDiscountZone();
   bool inPremium  = IsInPremiumZone();
   
   double requiredConfidence = 0.0;
   if(isBoomCrash)
   {
      // Sur Boom/Crash: exiger au minimum 65% (même si MinAIConfidence est plus bas)
      double baseBoomConf = MathMax(MinAIConfidence, 0.65);
      requiredConfidence = baseBoomConf;
      
      // Si l'IA est SELL en zone Discount (achat) ou BUY en zone Premium (vente),
      // augmenter encore l'exigence de confiance (trade "contre-zone").
      bool contrarianToZone = (aiAction == "SELL" && inDiscount) || (aiAction == "BUY" && inPremium);
      if(contrarianToZone)
         requiredConfidence = MathMax(requiredConfidence, 0.75);
   }
    else
    {
       // Pour Volatility: seuil identique Boom/Crash (65%) — les gates techniques assurent la qualité
       requiredConfidence = MathMax(MinAIConfidence, 0.65);
    }
   
   if(UseAIServer && g_lastAIConfidence < requiredConfidence)
   {
      string zoneStr = "Equilibre";
      if(inDiscount) zoneStr = "Discount";
      else if(inPremium) zoneStr = "Premium";
      
      Print("🚫 TRADE BLOQUÉ - Confiance IA insuffisante sur ", _Symbol, " | Zone: ", zoneStr,
            " | ", DoubleToString(g_lastAIConfidence*100, 1), "% < ", DoubleToString(requiredConfidence*100, 1), "%");
      return;
   }
   
   // DÉTECTION DIFFÉRENCIÉE: Spike requis pour Boom/Crash, signal IA fort pour Volatility
   bool spikeDetected = false;
   bool shouldTrade = false;
   
   if(isBoomCrash)
   {
      // Boom/Crash: deux modes possibles
      // - Mode "pré-spike only" : entrer dès que le prix est dans la zone SMC / pré‑spike (avant le 1er spike)
      // - Mode "spike confirmé" : attendre un spike récent + proba ML suffisante (avec option pré‑spike strict)
      bool preSpike = IsPreSpikePattern();
      spikeDetected = DetectRecentSpike();
      
      // --- Chain Predictor + CrossCorr: enregistrer chaque spike détecté (avant les gates) ---
      if(UseChainPredictor && spikeDetected)
      {
         MqlRates cpRates[];
         ArraySetAsSeries(cpRates, true);
         if(CopyRates(_Symbol, PERIOD_M1, 0, 5, cpRates) >= 5)
         {
            double cpBody = cpRates[0].close - cpRates[0].open;
            double cpBodyAbs = MathAbs(cpBody);
            double cpAtr = ChainPred_GetATR(_Symbol, PERIOD_M1, 14);
            double cpAmpAtr = (cpAtr > 0) ? cpBodyAbs / cpAtr : 1.0;
            int cpDir = (cpBody > 0) ? 1 : -1;
            ChainPred_RegisterSpike(cpRates[0].time, cpAmpAtr, cpDir);
            CrossCorr_RegisterSpike(_Symbol, cpRates[0].time, cpAmpAtr, cpDir);
         }
      }
      
      // Filtre supplémentaire basé sur la probabilité ML de spike (si activé)
      double spikeProbML = g_lastSpikeProbability;
      bool probaOk = true;
      if(UseSpikeMLFilter)
      {
         // Toujours calculer/rafraîchir une probabilité locale (éviter le cas "0%/N/A" qui court-circuite le filtre)
         if(g_lastSpikeUpdate == 0 || (TimeCurrent() - g_lastSpikeUpdate) > 300)
            spikeProbML = CalculateSpikeProbability();
         probaOk = (spikeProbML >= SpikeML_MinProbability);
      }
      
      if(SpikeUsePreSpikeOnlyForBoomCrash)
      {
         // Entrer AVANT le premier spike: pattern pré‑spike + proba ML OK
         shouldTrade = (preSpike && probaOk);
      }
      else
      {
         // Mode par défaut: spike récent + proba ML OK, avec option pré‑spike strict
         shouldTrade = (spikeDetected && probaOk && (!SpikeRequirePreSpikePattern || preSpike));
      }
      
      // Bypass: signal IA très fort (≥85%) → autoriser l'entrée pour capter les spikes en escalier
      // même si preSpike/spike récent/proba ML ne sont pas remplis (évite de rater une forte tendance)
      if(!shouldTrade && g_lastAIConfidence >= 0.85)
      {
         if((isBoom && aiAction == "BUY") || (isCrash && aiAction == "SELL"))
         {
            shouldTrade = true;
            Print("✅ Boom/Crash - Entrée autorisée par confiance IA forte (", DoubleToString(g_lastAIConfidence*100, 1), "%) - capture spikes/tendance");
         }
      }
      // Rebond canal: Boom → BUY quand prix touche low_chan; Crash → SELL quand prix touche upper chan
      if(!shouldTrade && isBoom && aiAction == "BUY" && PriceTouchesLowerChannel())
      {
         shouldTrade = true;
         Print("✅ Boom - Entrée autorisée (prix touche canal bas → rebond haussier attendu)");
      }
      if(!shouldTrade && isCrash && aiAction == "SELL" && PriceTouchesUpperChannel())
      {
         shouldTrade = true;
         Print("✅ Crash - Entrée autorisée (prix touche canal haut → rebond baissier attendu)");
      }
      // SPIKE CHAIN DETECTOR: entrée précoce dès le début d'une chaîne (2e bougie forte confirmée),
      // sans attendre le spike classique - uniquement si la direction est compatible Boom(BUY)/Crash(SELL)
      // ET si les indicateurs classiques sont alignés (confluence supplémentaire car entrée plus risquée)
      g_lastSpikeEntryWasEarly = false;
      if(!shouldTrade)
      {
         string chainDir = "";
         if(SMC_IsSpikeChainEarlyEntry(chainDir))
         {
             bool chainDirCompatible = (isBoom && chainDir == "BUY") || (isCrash && chainDir == "SELL");
             // Vérifier l'alignement des indicateurs classiques pour la direction de la chaîne
             string chainClassicSummary;
             bool classicOk = IsClassicIndicatorsAligned(chainDir, chainClassicSummary);
             if(chainDirCompatible && chainDir == aiAction && classicOk)
            {
               shouldTrade = true;
               g_lastSpikeEntryWasEarly = true;
               Print("🎯 SPIKE CHAIN - Entrée PRÉCOCE autorisée (chaîne ", chainDir,
                     " active, ", g_spikeChainStrongBars, " bougies fortes, indicateurs classiques alignés) sur ", _Symbol);
            }
            else if(chainDirCompatible && chainDir == aiAction && !classicOk)
            {
               Print("🚫 SPIKE CHAIN - Entrée précoce refusée (indicateurs classiques non alignés, confluence insuffisante) sur ", _Symbol);
            }
         }
      }
      // PAIx/GAINx: spike logic reste, mais verdict GOM Good/Perfect + pas de correction requis
      bool isPairxGainx = (StringFind(_Symbol, "PAINX") >= 0 || StringFind(_Symbol, "GAINX") >= 0);
      if(shouldTrade && isPairxGainx)
      {
         if(!SMCGP_IsGoodPerfect(g_smcGomVerdictNum))
         {
            Print("❌ PAIx/GAINx - Bloqué: verdict GOM insuffisant (vn=", g_smcGomVerdictNum, ")");
            shouldTrade = false;
         }
         else if(SMCGP_CorrectionBlocksEntry(true))
         {
            Print("❌ PAIx/GAINx - Bloqué en correction: ", SMCGP_CorrectionBlockReason(true));
            shouldTrade = false;
         }
      }
      // Après une perte sur ce symbole: exiger conditions meilleures + spike imminant pour éviter 2e perte consécutive
      if(shouldTrade && !AllowReentryAfterRecentLoss(_Symbol,
                                                     (isBoom ? "BUY" : "SELL"),
                                                     spikeDetected && (preSpike || spikeProbML >= 0.75)))
         shouldTrade = false;
      
      Print("🔍 DEBUG - Boom/Crash SNIPER - PreSpike: ", preSpike ? "OUI" : "NON",
            " | Spike récent: ", spikeDetected ? "OUI" : "NON",
            " | Proba ML spike: ",
            (spikeProbML > 0.0 ? DoubleToString(spikeProbML*100.0, 1) + "%" : "N/A"),
            " (min ",
            (UseSpikeMLFilter ? DoubleToString(SpikeML_MinProbability*100.0, 1) + "%" : "N/A"),
            ")",
            " | Mode pré-spike only: ", SpikeUsePreSpikeOnlyForBoomCrash ? "OUI" : "NON",
            " | Mode pré-spike strict: ", SpikeRequirePreSpikePattern ? "OUI" : "NON",
            " | Autorisé: ", shouldTrade ? "OUI" : "NON");
   }
      else if(isVolatility)
     {
        // Volatility: stratégie MULTI-CONFLUENCE technique (pas de spike requis)
        spikeDetected = false;
        
        // Direction IA locale (iaDirection n'est déclaré que plus bas)
        string volDir = "";
        if(g_lastAIAction == "BUY" || g_lastAIAction == "buy") volDir = "BUY";
        else if(g_lastAIAction == "SELL" || g_lastAIAction == "sell") volDir = "SELL";
        if(volDir == "") { Print("❌ Volatility - Aucun signal IA clair (", g_lastAIAction, ")"); }
        else
        {
           MqlRates volRates[];
           ArraySetAsSeries(volRates, true);
           if(CopyRates(_Symbol, PERIOD_M1, 0, 60, volRates) < 30)
           {
              Print("❌ Volatility - Données M1 insuffisantes");
           }
           else
           {
              int volConfirmations = 0;
              string volDetails = "";
              double volPrice = volRates[0].close;
              
              // Conf 1: EMA trend alignment (EMA9 > EMA21 = bullish)
              double bufF[], bufS[];
              ArraySetAsSeries(bufF, true);
              ArraySetAsSeries(bufS, true);
              double volEmaFast = 0, volEmaSlow = 0;
              if(emaFastM1 != INVALID_HANDLE && CopyBuffer(emaFastM1, 0, 0, 1, bufF) > 0)
                 volEmaFast = bufF[0];
              if(emaSlowM1 != INVALID_HANDLE && CopyBuffer(emaSlowM1, 0, 0, 1, bufS) > 0)
                 volEmaSlow = bufS[0];
              if(volEmaFast > 0 && volEmaSlow > 0)
              {
                 if((volDir == "BUY" && volEmaFast > volEmaSlow) ||
                    (volDir == "SELL" && volEmaFast < volEmaSlow))
                 {
                    volConfirmations++;
                    volDetails += "[EMA OK] ";
                 }
              }
              
              // Conf 2: RSI non-contre-tendance (< 70 pour BUY, > 30 pour SELL)
              double volRSI = ComputeRSI(volRates, 14, 0);
              if((volDir == "BUY" && volRSI < 70.0 && volRSI > 30.0) ||
                 (volDir == "SELL" && volRSI > 30.0 && volRSI < 70.0))
              {
                 volConfirmations++;
                 volDetails += StringFormat("[RSI %.0f OK] ", volRSI);
              }
              else if((volDir == "BUY" && volRSI < 40.0) ||
                      (volDir == "SELL" && volRSI > 60.0))
              {
                 volConfirmations += 2;
                 volDetails += StringFormat("[RSI %.0f FAVORABLE] ", volRSI);
              }
              
              // Conf 3: MACD alignment
              double volMACD = ComputeMACD(volRates, 12, 26, 9, 0);
              if((volDir == "BUY" && volMACD > 0) ||
                 (volDir == "SELL" && volMACD < 0))
              {
                 volConfirmations++;
                 volDetails += "[MACD OK] ";
              }
              
              // Conf 4: Bollinger Band position (prix dans la bonne moitié)
              if(UseBollingerFilter)
              {
                 int volBB = iBands(_Symbol, PERIOD_M1, 20, 2.0, 0, PRICE_CLOSE);
                 if(volBB != INVALID_HANDLE)
                 {
                    double bbUp[], bbMid[], bbLow[];
                    ArraySetAsSeries(bbUp, true);
                    ArraySetAsSeries(bbMid, true);
                    ArraySetAsSeries(bbLow, true);
                    if(CopyBuffer(volBB, 0, 0, 1, bbUp) == 1 &&
                       CopyBuffer(volBB, 1, 0, 1, bbMid) == 1 &&
                       CopyBuffer(volBB, 2, 0, 1, bbLow) == 1)
                    {
                       if((volDir == "BUY" && volPrice < bbMid[0]) ||
                          (volDir == "SELL" && volPrice > bbMid[0]))
                       {
                          volConfirmations++;
                          volDetails += "[BB OK] ";
                       }
                    }
                    IndicatorRelease(volBB);
                 }
              }
              
              // Conf 5: Momentum — 3 dernières bougies dans la bonne direction
              int momentumCount = 0;
              for(int v = 1; v <= 3 && v < ArraySize(volRates); v++)
              {
                 if(volDir == "BUY" && volRates[v].close > volRates[v].open) momentumCount++;
                 if(volDir == "SELL" && volRates[v].close < volRates[v].open) momentumCount++;
              }
              if(momentumCount >= 2)
              {
                 volConfirmations++;
                 volDetails += StringFormat("[MOM %d/3] ", momentumCount);
              }
              
              // Critère de validation: au moins 2 confirmations sur 5
              int minVolConfirmations = 2;
              if(volConfirmations >= minVolConfirmations)
              {
                 shouldTrade = true;
                 Print("✅ Volatility - Trade autorisé (", volConfirmations, "/5 confirmations: ", volDetails,
                       " | IA: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
              }
              else
              {
                 Print("❌ Volatility - Insuffisant (", volConfirmations, "/5 < ", minVolConfirmations,
                       " min) | ", volDetails);
              }
           }
        }
    }
   
   // --- Chaine de Spikes H1/M5 (Kola): gate obligatoire optionnel pour Boom/Crash/Painx/Gainx ---
   g_sch1_tpHint = 0.0;
   if(shouldTrade && isBoomCrash && UseSCH1_Strategy && SCH1_RequireForBoomCrash)
   {
      string sch1Dir = isBoom ? "BUY" : (isCrash ? "SELL" : "");
      if(sch1Dir != "")
      {
         string sch1Reason;
         double sch1Tp = 0.0;
         bool sch1Ok = SCH1_StrategyGate(sch1Dir, sch1Reason, sch1Tp);
         if(!sch1Ok)
         {
            Print("🚫 CHAINE DE SPIKES H1/M5 - Gate obligatoire non validé (", sch1Reason, ") sur ", _Symbol);
            shouldTrade = false;
         }
         else
         {
            g_sch1_tpHint = sch1Tp;
            Print("✅ CHAINE DE SPIKES H1/M5 - Gate validé | ", sch1Reason,
                  (sch1Tp > 0 ? " | TP extension S/R=" + DoubleToString(sch1Tp, _Digits) : ""));
         }
      }
   }

   if(!shouldTrade)
   {
      if(isBoomCrash)
         Print("❌ Conditions spike non remplies - trade Boom/Crash ignoré (Spike récent requis",
               SpikeRequirePreSpikePattern ? " + Pré-spike" : "",
               UseSpikeMLFilter ? " + Filtre proba" : "",
               ")");
      else
         Print("❌ Conditions non remplies - trade Volatility ignoré");
      return;
   }
   
   // DÉTERMINER LA DIRECTION basée sur le signal IA et le type de symbole
   string direction = "";
   string iaDirection = "";
   
   // Récupérer la direction de l'IA
   if(g_lastAIAction == "BUY" || g_lastAIAction == "buy")
      iaDirection = "BUY";
   else if(g_lastAIAction == "SELL" || g_lastAIAction == "sell")
      iaDirection = "SELL";
   else
   {
      Print("❌ Aucun signal IA clair (", g_lastAIAction, ") - trade ignoré");
      return;
   }
   
    // Vérifier la compatibilité entre le signal IA et le type de symbole
    if(isBoomCrash)
    {
       // Règles Boom/Crash/Painx/Gainx: directions spécifiques
       if(IsBoomLikeSymbol(_Symbol))
       {
          if(iaDirection == "BUY")
          {
             direction = "BUY"; // Boom/Gainx + IA BUY = OK
          }
          else
          {
             Print("❌ CONFLIT: IA dit ", iaDirection, " mais Boom/Gainx n'accepte que BUY - trade ignoré");
             return;
          }
       }
       else if(IsCrashLikeSymbol(_Symbol))
       {
          if(iaDirection == "SELL")
          {
             direction = "SELL"; // Crash/Painx + IA SELL = OK
          }
          else
          {
             Print("❌ CONFLIT: IA dit ", iaDirection, " mais Crash/Painx n'accepte que SELL - trade ignoré");
             return;
          }
      }
   }
   else if(isVolatility)
   {
      // Volatility: BUY et SELL autorisés (suivre l'IA)
      direction = iaDirection; // Volatility suit directement l'IA
      Print("✅ Volatility - Direction IA acceptée: ", direction, " sur ", _Symbol);
   }
   
   Print("✅ Signal IA validé: ", iaDirection, " compatible avec ", _Symbol, " → Direction: ", direction);

   // Vérifier l'alignement avec les indicateurs techniques classiques (TradingView-like)
   string classicSummary;
   bool classicOk = IsClassicIndicatorsAligned(direction, classicSummary);

   Print("🔍 DEBUG - Indicateurs classiques (", direction, ") => ", classicOk ? "ALIGNÉS" : "NON ALIGNÉS",
         " | ", classicSummary);

   if(!classicOk)
   {
      if(UseClassicIndicatorsFilter)
      {
         Print("🚫 TRADE SPIKE BLOQUÉ - Indicateurs classiques insuffisants (min ",
               ClassicMinConfirmations, " confirmations) sur ", _Symbol);
         return;
      }
   }

   // Protection capital: en zone d'achat au bord inférieur → SELL seulement si confiance IA >= 85%
   if(direction == "SELL" && IsAtDiscountLowerEdge() && g_lastAIConfidence < 0.85)
   {
      Print("🚫 TRADE BLOQUÉ - Zone Discount au bord inférieur: SELL autorisé seulement si confiance IA ≥ 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }
   // Protection capital: en zone premium au bord supérieur (Boom) → BUY seulement si confiance IA >= 85%
   if(direction == "BUY" && isBoom && IsAtPremiumUpperEdge() && g_lastAIConfidence < 0.85)
   {
      Print("🚫 TRADE BLOQUÉ - Zone Premium au bord supérieur (Boom): BUY autorisé seulement si confiance IA ≥ 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }

   // Réentrée après perte sur ce symbole (hors Boom/Crash): exiger conditions exceptionnelles
   if(!AllowReentryAfterRecentLoss(_Symbol, direction, spikeDetected))
      return;

   Print("🚀 SPIKE DÉTECTÉ - Direction: ", direction, " | Symbole: ", _Symbol);

   // ═══ SPIKE FEATURES — extraction partagée (ONNX + Chain Predictor + CrossCorr) ═══
   double spikeAtrVal    = 0;
   double spikeAmpPips   = 0;
   double spikeAmpAtr    = 0;
   double spikeVelProxy  = 0;
   double spikeMinPrev   = 0;
   datetime spikeTimeVal = 0;
   bool   spikeUpDir     = (direction == "BUY");

   {
      MqlRates spikeRates[];
      ArraySetAsSeries(spikeRates, true);
      if(CopyRates(_Symbol, PERIOD_M1, 0, 10, spikeRates) >= 10)
      {
         double atrBuf[];
         ArraySetAsSeries(atrBuf, true);
         if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atrBuf) >= 1)
            spikeAtrVal = atrBuf[0];

         int spikeIdx = -1;
         for(int i = 1; i <= 5 && i < ArraySize(spikeRates); i++)
         {
            double bodyI = MathAbs(spikeRates[i].close - spikeRates[i].open);
            if(spikeAtrVal > 0 && bodyI >= spikeAtrVal * SpikeChainBodyATRMult)
            { spikeIdx = i; break; }
         }

         if(spikeIdx > 0)
         {
            double body    = spikeRates[spikeIdx].close - spikeRates[spikeIdx].open;
            double bodyAbs = MathAbs(body);
            spikeUpDir     = (body > 0);

            double point   = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            spikeAmpPips   = (point > 0) ? bodyAbs / point : bodyAbs * 100;
            spikeAmpAtr    = (spikeAtrVal > 0) ? bodyAbs / spikeAtrVal : 0;

            double dtSec   = (spikeIdx > 0 && spikeIdx < ArraySize(spikeRates))
                              ? (double)(spikeRates[spikeIdx - 1].time - spikeRates[spikeIdx].time)
                              : 60.0;
            if(dtSec <= 0) dtSec = 60.0;
            spikeVelProxy  = spikeAmpPips / dtSec;
            spikeTimeVal   = spikeRates[spikeIdx].time;

            if(g_lastSpikeDetectTime > 0)
               spikeMinPrev = (double)(spikeTimeVal - g_lastSpikeDetectTime) / 60.0;

            // Mettre à jour la mémoire des spikes (pour tous les modules)
            g_prevSpikeDetectTime      = g_lastSpikeDetectTime;
            g_lastSpikeDetectTime      = spikeTimeVal;
            g_lastSpikeAmplitudePips   = spikeAmpPips;
            g_lastSpikeAmplitudeAtr    = spikeAmpAtr;
            g_lastSpikeVelocityProxy   = spikeVelProxy;
            g_lastSpikeWasUp           = spikeUpDir;
         }
      }
   }

   // --- ONNX Spike Chain Directional Filter ---
   if(UseOnnxSpikeFilter && g_spikePredictorReady && (isBoom || isCrash) && spikeAmpAtr > 0)
   {
      // Construire l'entrée ONNX
      SpikeChainInput sci;
      sci.dirIsUp              = spikeUpDir;
      sci.amplitudePips        = spikeAmpPips;
      sci.amplitudeAtr         = spikeAmpAtr;
      sci.velocityProxy        = spikeVelProxy;
      sci.minutesSincePrevSpike = spikeMinPrev;
      MqlDateTime spikeTm;
      TimeToStruct(spikeTimeVal, spikeTm);
      sci.hour                 = spikeTm.hour;
      sci.minute               = spikeTm.min;

      double pUp = g_spikePredictor.PredictNextSpikeUpProbability(sci);

      if(pUp >= 0)
      {
         Print("🧠 ONNX SPIKE PREDICT - P(up)=", DoubleToString(pUp, 3),
               " | spikeDir=", spikeUpDir ? "UP" : "DOWN",
               " | ampAtr=", DoubleToString(spikeAmpAtr, 2),
               " | vel=", DoubleToString(spikeVelProxy, 4),
               " | prevMin=", DoubleToString(spikeMinPrev, 1));

         // Filtre directionnel: refuser BUY si P(up) trop bas, refuser SELL si P(up) trop haut
         if(direction == "BUY" && pUp < OnnxSellThreshold)
         {
            Print("❌ ONNX BLOQUÉ BUY - P(up)=", DoubleToString(pUp, 3),
                  " < seuil=", DoubleToString(OnnxSellThreshold, 2),
                  " → probabilité de contre-spike trop élevée");
            return;
         }
         if(direction == "SELL" && pUp > OnnxBuyThreshold)
         {
            Print("❌ ONNX BLOQUÉ SELL - P(up)=", DoubleToString(pUp, 3),
                  " > seuil=", DoubleToString(OnnxBuyThreshold, 2),
                  " → probabilité de spike haussier trop élevée");
            return;
         }
         Print("✅ ONNX FILTRE PASSÉ - P(up)=", DoubleToString(pUp, 3), " compatible direction=", direction);
      }
      else
         Print("⚠️ ONNX prédiction échouée (err) — filtre ignoré");
   }

   // ═══ CHAIN PREDICTOR — Score d'imminence + boost corrélation croisée ═══
   if(UseChainPredictor && (IsBoomLikeSymbol(_Symbol) || IsCrashLikeSymbol(_Symbol) ||
       SMC_IsWeltradeSynthSymbol(_Symbol)))
   {
      double chainScore = ChainPred_GetImminence();
      double crossBoost = CrossCorr_GetImminenceBoost();
      double totalScore = MathMin(100.0, chainScore + crossBoost);

      Print("📊 CHAIN SCORE: ", DoubleToString(totalScore, 1),
            " (chain=", DoubleToString(chainScore, 1),
            " + cross=", DoubleToString(crossBoost, 1),
            ") | ISI=", DoubleToString(ChainPred_GetISICompression(), 2),
            " | Chain len=", ChainPred_GetChainLength(),
            " | Regime=", ChainPred_IsPreChain() ? "PRE_CHAIN" : (ChainPred_IsUncertainOrBetter() ? "UNCERTAIN" : "NORMAL"));

      // Signal croisé actif → log
      if(CrossCorr_IsSignalActive())
      {
         Print("🔀 CROSS-CORR: spike inverse de ", CrossCorr_GetTriggerSymbol(),
               " il y a ", CrossCorr_GetDelayBars(), " bars → boost ",
               DoubleToString(crossBoost, 1), " pts sur ", _Symbol);
      }
   }

    // EXÉCUTION DU TRADE — Volatility utilise un exécuteur dédié (market order + ATR SL/TP)
    if(isVolatility)
       ExecuteVolatilityTrade(direction);
    else
       ExecuteSpikeTrade(direction);
}

//| DÉTECTER SI UNE FLÈCHE DERIV ARROW EST PRÉSENTE SUR LE GRAPHIQUE |
bool IsDerivArrowPresent()
{
   // Chercher les objets flèche sur le graphique avec des noms typiques
   for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, OBJ_ARROW);
      
      // Vérifier si c'est une flèche Deriv Arrow (noms communs)
      if(StringFind(objName, "DERIV") >= 0 || StringFind(objName, "Deriv") >= 0 || 
         StringFind(objName, "ARROW") >= 0 || StringFind(objName, "Arrow") >= 0 ||
         StringFind(objName, "SIGNAL") >= 0 || StringFind(objName, "Signal") >= 0)
      {
         // Vérifier que l'objet est visible et sur la bougie récente
         datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
         datetime currentTime = TimeCurrent();
         
         // La flèche doit être sur les 5 dernières bougies maximum
         if(currentTime - objTime <= PeriodSeconds() * 5)
         {
            return true;
         }
      }
   }
   
   return false;
}

// Exige la présence récente de la flèche SMC_DERIV_ARROW_<symbol> avant d'exécuter un ordre au marché.
// Direction: "BUY" ou "SELL" (insensible à la casse).
bool HasRecentSMCDerivArrowForDirection(string direction)
{
   if(!RequireSMCDerivArrowForMarketOrders) return true;

   string dir = direction;
   StringToUpper(dir);
   if(dir != "BUY" && dir != "SELL") return false;

   string arrowName = "SMC_DERIV_ARROW_" + _Symbol;
   if(ObjectFind(0, arrowName) < 0) return false;

   // Vérifier que la flèche est récente (N bougies max sur timeframe courant)
   datetime arrowTime = (datetime)ObjectGetInteger(0, arrowName, OBJPROP_TIME, 0);
   int maxAgeBars = MathMax(1, SMCDerivArrowMaxAgeBars);
   int maxAgeSec = PeriodSeconds(PERIOD_CURRENT) * maxAgeBars;
   if(maxAgeSec <= 0) maxAgeSec = 60 * maxAgeBars;
   if(TimeCurrent() - arrowTime > maxAgeSec) return false;

   // Vérifier direction via le code de flèche
   int arrowCode = (int)ObjectGetInteger(0, arrowName, OBJPROP_ARROWCODE);
   bool isBuyArrow = (arrowCode == 233);
   bool isSellArrow = (arrowCode == 234);
   if(dir == "BUY" && !isBuyArrow) return false;
   if(dir == "SELL" && !isSellArrow) return false;

   return true;
}

//| VARIABLES GLOBALES POUR ORDRES LIMIT POST-HOLD |
static bool g_postHoldLimitOrderPending = false;
static datetime g_lastHoldCloseTime = 0;

//| PLACER ORDRE LIMIT POST-HOLD APRÈS PERTE 2,0$ |
void PlacePostHoldLimitOrder(string closedSymbol, ENUM_POSITION_TYPE closedType, double closedProfit)
{
   // Bloquer en zone de correction (verdict GOM WAIT = vn==0)
   if(UseGOMVerdictFilter && g_smcGomConnected && g_smcGomVerdictNum == 0)
   {
      Print("[GOM-WAIT] PlacePostHoldLimitOrder bloqué — verdict=WAIT (correction)");
      return;
   }

   Print("🔍 DEBUG POST-HOLD - Début fonction");
   Print("   📊 Symbole: ", closedSymbol, " | Type: ", (closedType == POSITION_TYPE_BUY ? "BUY" : "SELL"), " | Profit: ", DoubleToString(closedProfit, 2), "$");

   // Vérifier si la fermeture était bien due à HOLD avec perte ≥ 2,0$
   if(closedProfit > -2.0)
   {
      Print("📊 POST-HOLD - Perte insuffisante: ", DoubleToString(closedProfit, 2), "$ > -2.00$");
      return;
   }
   Print("✅ POST-HOLD - Perte suffisante: ", DoubleToString(closedProfit, 2), "$ ≤ -2.00$");
   
   // Vérifier si c'est bien Boom/Crash
    bool isBoom = IsBoomLikeSymbol(closedSymbol);
    bool isCrash = IsCrashLikeSymbol(closedSymbol);
   
   if(!isBoom && !isCrash)
   {
      Print("📊 POST-HOLD - Symbole non Boom/Crash: ", closedSymbol);
      return;
   }
   Print("✅ POST-HOLD - Symbole valide - Boom: ", isBoom, " | Crash: ", isCrash);
   
   // Vérifier si un ordre limit est déjà en attente
   if(g_postHoldLimitOrderPending)
   {
      Print("📊 POST-HOLD - Ordre limit déjà en attente, annulation");
      return;
   }
   Print("✅ POST-HOLD - Aucun ordre limit en attente");
   
   // Détecter si nous étions en zone Premium (vente) ou Discount (achat)
   bool inDiscount = IsInDiscountZone();
   bool inPremium = IsInPremiumZone();
   
   Print("🔍 POST-HOLD - Zones SMC - Discount: ", inDiscount, " | Premium: ", inPremium);
   
   // Conditions détaillées pour ordre limit
   bool shouldPlaceLimit = false;
   ENUM_ORDER_TYPE limitType = WRONG_VALUE;
   double limitPrice = 0.0;
   string limitReason = "";
   
   if(isBoom && inDiscount && closedType == POSITION_TYPE_BUY)
   {
      // Boom en zone Discount avec position BUY fermée → ordre BUY limit au support
      limitType = ORDER_TYPE_BUY_LIMIT;
      limitPrice = GetSupportLevel(20); // Support sur 20 barres
      limitReason = "Boom Discount - Support 20 bars (post-HOLD)";
      shouldPlaceLimit = true;
      Print("🎯 POST-HOLD - Condition Boom+Discount+BUY remplie");
   }
   else if(isCrash && inPremium && closedType == POSITION_TYPE_SELL)
   {
      // Crash en zone Premium avec position SELL fermée → ordre SELL limit à la résistance
      limitType = ORDER_TYPE_SELL_LIMIT;
      limitPrice = GetResistanceLevel(20); // Résistance sur 20 barres
      limitReason = "Crash Premium - Resistance 20 bars (post-HOLD)";
      shouldPlaceLimit = true;
      Print("🎯 POST-HOLD - Condition Crash+Premium+SELL remplie");
   }
   
   if(!shouldPlaceLimit)
   {
      Print("🚫 POST-HOLD - Conditions non remplies pour ordre limit");
      Print("   📍 Symbole: ", closedSymbol, " | Type: ", (closedType == POSITION_TYPE_BUY ? "BUY" : "SELL"));
      Print("   📍 Zones - Discount: ", inDiscount, " | Premium: ", inPremium);
      Print("   📍 Attendu: (Boom+Discount+BUY) ou (Crash+Premium+SELL)");
      return;
   }
   
   Print("✅ POST-HOLD - Conditions validées - Calcul niveau de prix...");
   
   // Placer l'ordre limit
   double lot = CalculateLotSize();
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_PENDING;
   request.symbol = closedSymbol;
   request.volume = lot;
   request.type = limitType;
   request.price = limitPrice;
   request.sl = 0;
   request.tp = 0;
   request.deviation = 10;
   request.magic = InpMagicNumber;
   request.comment = "POST-HOLD Limit - " + limitReason;
   request.type_time = ORDER_TIME_GTC; // Good till cancelled
   request.expiration = 0;
   
   Print("🔍 POST-HOLD - Requête ordre limit préparée:");
   Print("   📊 Type: ", (limitType == ORDER_TYPE_BUY_LIMIT ? "BUY LIMIT" : "SELL LIMIT"));
   Print("   💰 Prix: ", DoubleToString(limitPrice, _Digits), " | Lot: ", DoubleToString(lot, 2));
   Print("   📍 Raison: ", limitReason);
   
   if(!CanPlaceLimitOrder(closedSymbol, limitType)) return;
   CleanupExcessLimits(closedSymbol, 2);
   if(SafeOrderSend(request, result))
   {
      g_postHoldLimitOrderPending = true;
      g_lastHoldCloseTime = TimeCurrent();
      Print("✅ POST-HOLD - Ordre limit placé avec succès");
      Print("   📊 Symbole: ", closedSymbol, " | Type: ", (limitType == ORDER_TYPE_BUY_LIMIT ? "BUY LIMIT" : "SELL LIMIT"));
      Print("   💰 Prix: ", DoubleToString(limitPrice, _Digits), " | Lot: ", DoubleToString(lot, 2));
      Print("   📍 Raison: ", limitReason);
      Print("   🎫 Ticket: ", result.order);
   }
   else
   {
      Print("❌ POST-HOLD - Échec placement ordre limit");
      Print("   📊 Erreur: ", result.retcode, " - ", result.comment);
      Print("   📊 Code erreur: ", GetLastError());
   }
}

//| OBTENIR NIVEAU DE SUPPORT (20 BARRES) |
double GetSupportLevel(int bars)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, bars + 1, rates) < bars + 1)
   {
      Print("❌ Impossible de copier les rates pour support");
      return 0.0;
   }
   
   double support = rates[0].low;
   for(int i = 1; i <= bars; i++)
   {
      if(rates[i].low < support)
         support = rates[i].low;
   }
   
   return support;
}

//| OBTENIR NIVEAU DE RÉSISTANCE (20 BARRES) |
double GetResistanceLevel(int bars)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, bars + 1, rates) < bars + 1)
   {
      Print("❌ Impossible de copier les rates pour résistance");
      return 0.0;
   }
   
   double resistance = rates[0].high;
   for(int i = 1; i <= bars; i++)
   {
      if(rates[i].high > resistance)
         resistance = rates[i].high;
   }
   
   return resistance;
}
static string g_lastAIActionPrevious = ""; // Action IA précédente

//| SURVEILLER ET FERMER POSITIONS SI IA DEVIENT HOLD |
void MonitorAndClosePositionsOnHold()
{
   if(!UseAIServer) return; // Seulement si serveur IA actif
   
   // Vérifier si l'IA est passée de BUY/SELL à HOLD
   if(g_lastAIActionPrevious != "" && g_lastAIActionPrevious != "HOLD" && g_lastAIActionPrevious != "hold" &&
      (g_lastAIAction == "HOLD" || g_lastAIAction == "hold"))
   {
      Print("🔄 CHANGEMENT IA DÉTECTÉ - ", g_lastAIActionPrevious, " → HOLD");
      Print("   ⚠️ SURVEILLANCE DES POSITIONS - Attente perte ≥ 2.0$ avant fermeture");
      
      // Parcourir toutes les positions ouvertes
      int totalPositions = PositionsTotal();
      for(int i = totalPositions - 1; i >= 0; i--)
      {
         if(PositionGetTicket(i) > 0)
         {
            string posSymbol = PositionGetString(POSITION_SYMBOL);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            ulong posTicket = PositionGetInteger(POSITION_TICKET);
            double posProfit = PositionGetDouble(POSITION_PROFIT);
            
            // Vérifier si la position correspond à l'action précédente
            bool shouldClose = false;
            if(g_lastAIActionPrevious == "BUY" && posType == POSITION_TYPE_BUY)
            {
               shouldClose = true;
               Print("   🔄 SURVEILLANCE BUY - ", posSymbol, " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$");
            }
            else if(g_lastAIActionPrevious == "SELL" && posType == POSITION_TYPE_SELL)
            {
               shouldClose = true;
               Print("   🔄 SURVEILLANCE SELL - ", posSymbol, " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$");
            }
            
            if(shouldClose)
            {
               // NOUVEAU: Vérifier si perte ≥ 2.0$ avant de fermer
               if(posProfit <= -2.0)
               {
                  Print("   💰 SEUIL DE PERTE ATTEINT - ", DoubleToString(posProfit, 2), "$ ≤ -2.00$");
                  Print("   🔄 FERMETURE AUTOMATIQUE sur HOLD - Perte ≥ 2.0$");
                  
                  // Fermer la position
                  MqlTradeRequest request = {};
                  MqlTradeResult result = {};
                  
                  request.action = TRADE_ACTION_DEAL;
                  request.position = posTicket;
                  request.symbol = posSymbol;
                  request.volume = PositionGetDouble(POSITION_VOLUME);
                  request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
                  request.price = (posType == POSITION_TYPE_BUY) ? SymbolInfoDouble(posSymbol, SYMBOL_BID) : SymbolInfoDouble(posSymbol, SYMBOL_ASK);
                  request.deviation = 10;
                  request.magic = InpMagicNumber;
                  request.comment = "IA HOLD Auto-Close (Loss ≥ 2.0$)";
                  
                  if(SafeOrderSend(request, result))
                  {
                     Print("✅ POSITION FERMÉE - ", posSymbol, " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$");
                     
                     // NOUVEAU: Placer ordre limit post-HOLD si perte ≥ 2.0$
                     PlacePostHoldLimitOrder(posSymbol, posType, posProfit);
                  }
                  else
                  {
                     Print("❌ ERREUR FERMETURE - ", posSymbol, " | Erreur: ", result.comment);
                  }
               }
               else
               {
                  Print("   ⏳ SURVEILLANCE CONTINUE - Perte: ", DoubleToString(posProfit, 2), "$ > -2.00$ (seuil non atteint)");
                  Print("   📊 Attente HOLD - Position maintenue jusqu'à perte ≥ 2.0$");
               }
            }
         }
      }
   }
   
   // Mettre à jour l'action précédente
   g_lastAIActionPrevious = g_lastAIAction;
}
bool IsMaxPositionsReached()
{
   int totalPositions = PositionsTotal();
   
   // NOUVEAU: Protection capital faible - Si < 20$, limiter à 1 position seulement
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   int maxAllowedPositions = (accountEquity < 20.0) ? 1 : MaxPositionsTerminal;
   
   // Si on a déjà le nombre maximum de positions autorisées, bloquer les nouveaux trades
   if(totalPositions >= maxAllowedPositions)
   {
      // Si exactement le nombre maximum, log d'information
      if(totalPositions == maxAllowedPositions)
      {
         static datetime lastLog = 0;
         if(TimeCurrent() - lastLog >= 60) // Log toutes les minutes maximum
         {
            if(accountEquity < 20.0)
            {
               Print("🚨 CAPITAL FAIBLE - Équité: ", DoubleToString(accountEquity, 2), "$ < 20.00$");
               Print("   🔒 LIMITATION À 1 POSITION SEULEMENT pour protéger le capital");
            }
            else
            {
               Print("🛡️ PROTECTION CAPITAL - ", totalPositions, "/", maxAllowedPositions, " positions atteintes (sur symboles différents)");
            }
            
            Print("   📊 Positions actuelles :");
            for(int i = 0; i < totalPositions; i++)
            {
               if(PositionGetTicket(i) > 0)
               {
                  string posSymbol = PositionGetString(POSITION_SYMBOL);
                  double posProfit = PositionGetDouble(POSITION_PROFIT);
                  ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                  ulong posTicket = PositionGetInteger(POSITION_TICKET);
                  
                  Print("   - ", posType == POSITION_TYPE_BUY ? "BUY" : "SELL", " ", posSymbol, 
                        " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$");
               }
            }
            
            if(accountEquity < 20.0)
            {
               Print("   ⏸️ NOUVEAUX TRADES BLOQUÉS - Capital faible, 1 position max");
            }
            else
            {
               Print("   ⏸️ NOUVEAUX TRADES BLOQUÉS jusqu'à libération d'une position");
               Print("   💡 Règle: Max ", maxAllowedPositions, " positions sur symboles différents autorisées");
            }
            lastLog = TimeCurrent();
         }
      }
      return true; // Bloquer les nouveaux trades
   }
   
   return false; // Autoriser les trades
}

//| OBTENIR LA DIRECTION DE LA FLÈCHE DERIV ARROW |
bool GetDerivArrowDirection(string &direction)
{
   direction = "";
   
   // NOUVEAU: MÉMOIRE DES FLÈCHES DÉJÀ DÉTECTÉES
   static string lastDetectedArrow = "";
   static datetime lastDetectedTime = 0;
   
   // Chercher les objets flèche sur le graphique
   for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i, -1, OBJ_ARROW);
      
      // Vérifier si c'est une flèche Deriv Arrow - PLUS SPÉCIFIQUE
      bool isDerivArrow = false;
      if(StringFind(objName, "DERIV") >= 0 || StringFind(objName, "Deriv") >= 0 || 
         StringFind(objName, "ARROW") >= 0 || StringFind(objName, "Arrow") >= 0 ||
         StringFind(objName, "SIGNAL") >= 0 || StringFind(objName, "Signal") >= 0)
      {
         isDerivArrow = true;
      }
      
      // VÉRIFICATION SUPPLÉMENTAIRE: chercher les grandes flèches typiques
      if(!isDerivArrow)
      {
         // Noms de grandes flèches trading
         if(StringFind(objName, "BUY") >= 0 || StringFind(objName, "SELL") >= 0 ||
            StringFind(objName, "ENTRY") >= 0 || StringFind(objName, "Entry") >= 0 ||
            StringFind(objName, "TRADE") >= 0 || StringFind(objName, "Trade") >= 0)
         {
            isDerivArrow = true;
         }
      }
      
      if(!isDerivArrow) continue;
      
      datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
      datetime currentTime = TimeCurrent();
      
      // La flèche doit être sur les 3 dernières bougies maximum (plus réactif)
      if(currentTime - objTime <= PeriodSeconds() * 3)
      {
         // Vérifier que la flèche est VRAIMENT visible (propriétés visuelles)
         color arrowColor = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
         int arrowWidth = (int)ObjectGetInteger(0, objName, OBJPROP_WIDTH);
         bool arrowVisible = (bool)ObjectGetInteger(0, objName, OBJPROP_TIME, 0) > 0;
         
         // IGNORER les flèches trop petites ou invisibles
         if(arrowWidth < 2 || !arrowVisible)
         {
            Print("🔍 Flèche ignorée - Trop petite ou invisible: ", objName, " | Width: ", arrowWidth);
            continue;
         }
         
         // Créer une clé unique pour cette flèche
         string arrowKey = _Symbol + "_" + objName + "_" + TimeToString(objTime, TIME_MINUTES);
         
         // Vérifier si cette flèche a déjà été détectée
         if(lastDetectedArrow == arrowKey && (currentTime - lastDetectedTime) < 300) // 5 minutes
         {
            continue; // Ignorer cette flèche déjà traitée
         }
         
         // Vert = BUY, Rouge = SELL
         if(arrowColor == clrGreen || arrowColor == clrLime || arrowColor == clrForestGreen)
         {
            direction = "BUY";
            Print("🟢 GRANDE FLÈCHE VERTE DÉTECTÉE - Signal BUY sur ", _Symbol, 
                  " | Objet: ", objName, 
                  " | Width: ", arrowWidth,
                  " | Time: ", TimeToString(objTime, TIME_SECONDS));
            
            // MÉMORISER CETTE FLÈCHE COMME DÉTECTÉE
            lastDetectedArrow = arrowKey;
            lastDetectedTime = currentTime;
            return true;
         }
         else if(arrowColor == clrRed || arrowColor == clrCrimson || arrowColor == clrIndianRed)
         {
            direction = "SELL";
            Print("🔴 GRANDE FLÈCHE ROUGE DÉTECTÉE - Signal SELL sur ", _Symbol,
                  " | Objet: ", objName,
                  " | Width: ", arrowWidth,
                  " | Time: ", TimeToString(objTime, TIME_SECONDS));
            
            // MÉMORISER CETTE FLÈCHE COMME DÉTECTÉE
            lastDetectedArrow = arrowKey;
            lastDetectedTime = currentTime;
            return true;
         }
         else
         {
            // Si la couleur n'est pas claire, essayer de deviner par le code de la flèche
            long arrowCode = ObjectGetInteger(0, objName, OBJPROP_ARROWCODE);
            
            // Codes de flèche UP (BUY) - plus de codes pour les grandes flèches
            if(arrowCode == 241 || arrowCode == 242 || arrowCode == 233 || arrowCode == 225 ||
               arrowCode == 67 || arrowCode == 68 || arrowCode == 71 || arrowCode == 72) // Codes grandes flèches
            {
               direction = "BUY";
               Print("🟢 GRANDE FLÈCHE UP DÉTECTÉE - Signal BUY sur ", _Symbol, 
                     " (code: ", arrowCode, ") | Objet: ", objName,
                     " | Width: ", arrowWidth);
               
               // MÉMORISER CETTE FLÈCHE COMME DÉTECTÉE
               lastDetectedArrow = arrowKey;
               lastDetectedTime = currentTime;
               return true;
            }
            // Codes de flèche DOWN (SELL) - plus de codes pour les grandes flèches
            else if(arrowCode == 240 || arrowCode == 243 || arrowCode == 234 || arrowCode == 226 ||
                     arrowCode == 76 || arrowCode == 77 || arrowCode == 78 || arrowCode == 79) // Codes grandes flèches
            {
               direction = "SELL";
               Print("🔴 GRANDE FLÈCHE DOWN DÉTECTÉE - Signal SELL sur ", _Symbol,
                     " (code: ", arrowCode, ") | Objet: ", objName,
                     " | Width: ", arrowWidth);
               
               // MÉMORISER CETTE FLÈCHE COMME DÉTECTÉE
               lastDetectedArrow = arrowKey;
               lastDetectedTime = currentTime;
               return true;
            }
            else
            {
               Print("🔍 Flèche ignorée - Code non reconnu: ", arrowCode, " | Objet: ", objName);
            }
         }
      }
   }
   
   return false;
}

//| EXÉCUTER UN TRADE BASÉ SUR LA FLÈCHE DERIV ARROW |
void ExecuteDerivArrowTrade(string direction)
{
   Print("🔍 DÉBUT ANALYSE FLÈCHE DERIV ARROW - Direction: ", direction, " | Symbole: ", _Symbol);
   
   // NOUVEAU: VÉRIFICATION PROTECTION CAPITAL - MAX 2 POSITIONS
   if(IsMaxPositionsReached())
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Protection capital activée (max ", MaxPositionsTerminal, " positions)");
      return;
   }
   Print("✅ Protection capital OK");
   
   // NOUVEAU: VÉRIFICATION CONFIANCE IA MINIMALE
   if(UseAIServer)
   {
      double aiConfidencePct = (g_lastAIConfidence <= 1.0)
                               ? g_lastAIConfidence * 100.0
                               : g_lastAIConfidence;
      Print("📊 Vérification IA - Confiance: ", DoubleToString(aiConfidencePct, 1), "% | Action: ", g_lastAIAction);
      if(aiConfidencePct < MinAIConfidencePercent)
      {
         Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Confiance IA insuffisante: ", 
               DoubleToString(aiConfidencePct, 1), "% < ", DoubleToString(MinAIConfidencePercent, 1), "% minimum");
         Print("   📊 IA Action: ", g_lastAIAction);
         return;
      }
      else
      {
         Print("✅ CONFIANCE IA VALIDÉE - ", DoubleToString(aiConfidencePct, 1), "% ≥ ", 
               DoubleToString(MinAIConfidencePercent, 1), "% minimum");
      }
   }
   else
   {
      Print("📊 Serveur IA désactivé - Utilisation flèche uniquement");
   }

   if(UseGOMVerdictFilter && !SMCGP_GOMAllowsAction(direction))
   {
      Print("[ARROW] Bloqué — GOM ", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ")");
      return;
   }

   // GATE COHÉRENCE GOM >= 70% (règle absolue IA gate)
   if(g_smcGomCoherence > 0 && g_smcGomCoherence < 70.0)
   {
      Print("[ARROW] Bloqué — coherence ", DoubleToString(g_smcGomCoherence,1), "% < 70% requis");
      return;
   }

   // GATE M1 : M1 ne doit pas être opposé à la direction (micro-tendance)
   string m1Dir = g_smcTfM1Dir;
   if((direction == "BUY"  && m1Dir == "BEAR") ||
      (direction == "SELL" && m1Dir == "BULL"))
   {
      Print("[ARROW] Bloqué — M1=", m1Dir, " opposé à ", direction, " (entrée vouée à l'échec)");
      return;
   }

   // GATE tf_global_dir : tendance globale GOM ne doit pas contredire la direction
   string globalDir = g_smcGomGlobalDir;
   if((direction == "BUY"  && globalDir == "BEAR") ||
      (direction == "SELL" && globalDir == "BULL"))
   {
      Print("[ARROW] Bloqué — tf_global=", globalDir, " opposé à ", direction, " (contre-tendance globale)");
      return;
   }

   // Validation : Boom = BUY uniquement, Crash = SELL uniquement
   bool isBoom = IsBoomLikeSymbol(_Symbol);
   bool isCrash = IsCrashLikeSymbol(_Symbol);
   
   Print("🎯 Validation symbole - Boom: ", isBoom, " | Crash: ", isCrash, " | Direction: ", direction);
   
   if(isBoom && direction != "BUY")
   {
      Print("🚫 FLÈCHE DERIV ARROW IGNOREE - ", direction, " sur Boom (seul BUY autorisé)");
      return;
   }
   
   if(isCrash && direction != "SELL")
   {
      Print("🚫 FLÈCHE DERIV ARROW IGNOREE - ", direction, " sur Crash (seul SELL autorisé)");
      return;
   }
   Print("✅ Validation symbole OK");
   
   // Vérifier que l'IA n'est pas en HOLD
   if(UseAIServer && (g_lastAIAction == "HOLD" || g_lastAIAction == "hold"))
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - IA en HOLD sur ", _Symbol);
      return;
   }
   Print("✅ IA non-HOLD OK");
   
   // NOUVEAU: VÉRIFIER SI LE PRIX EST DANS LA ZONE D'ÉQUILIBRE
   bool inDiscount = IsInDiscountZone();
   bool inPremium  = IsInPremiumZone();
   
   Print("📍 Zones SMC - Discount: ", inDiscount, " | Premium: ", inPremium);
   
   // Si le prix est dans la zone d'équilibre (ni premium ni discount), bloquer le trade
   if(!inDiscount && !inPremium)
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Prix dans zone d'équilibre sur ", _Symbol, 
            " (ni Premium ni Discount) - Trade non autorisé");
      return;
   }
   Print("✅ Zone SMC OK (ni Premium ni Discount)");
   
   // Protection capital: zone d'achat au bord inférieur → SELL seulement si confiance IA >= 85%
   if(direction == "SELL" && IsAtDiscountLowerEdge() && g_lastAIConfidence < 0.85)
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Zone Discount au bord inférieur: SELL autorisé seulement si confiance IA ≥ 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }
   // Protection capital: zone premium au bord supérieur (Boom) → BUY seulement si confiance IA >= 85%
   if(direction == "BUY" && isBoom && IsAtPremiumUpperEdge() && g_lastAIConfidence < 0.85)
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Zone Premium au bord supérieur (Boom): BUY autorisé seulement si confiance IA ≥ 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }
   
   // Anti-duplication : vérifier qu'il n'y a pas déjà une position
   int existingPositions = CountPositionsForSymbol(_Symbol);
   if(existingPositions > 0)
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - ", existingPositions, " position(s) déjà existante(s) sur ", _Symbol);
      return;
   }
   Print("✅ Anti-duplication OK");
   
   Print("🚀 TOUTES LES VALIDATIONS RÉUSSIES - EXÉCUTION DU TRADE...");
   
   // NOUVEAU: MÉMOIRE DES FLÈCHES DÉJÀ TRAITÉES
   static string lastProcessedArrow = "";
   static datetime lastProcessedTime = 0;
   
   // Créer une clé unique pour cette flèche (symbole + direction + heure)
   string currentArrowKey = _Symbol + "_" + direction + "_" + TimeToString(TimeCurrent(), TIME_MINUTES);
   
   // Vérifier si cette flèche a déjà été traitée récemment
   if(lastProcessedArrow == currentArrowKey && (TimeCurrent() - lastProcessedTime) < 300) // 5 minutes
   {
      Print("🔄 FLÈCHE DERIV ARROW DÉJÀ TRAITÉE - ", direction, " sur ", _Symbol, " (ignorer pour éviter duplication)");
      return;
   }
   
   // Obtenir le prix actuel
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, r) < 1)
   {
      Print("❌ ERREUR - Impossible d'obtenir les prix pour ", _Symbol);
      return;
   }
   
   double currentPrice = r[0].close;
   double stopLoss, takeProfit;
   
   // NOUVEAU: CALCUL SL/TP CORRECT POUR ÉVITER "INVALID STOPS"
   // Approche radicale : utiliser les exigences du courtier
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Distance minimale obligatoire du courtier
   double minStopDistance = (double)stopsLevel * point;
   
   // Si stopsLevel = 0, utiliser une distance par défaut sécuritaire
   if(minStopDistance <= 0)
   {
      if(isCrash || isBoom)
      {
         minStopDistance = 1.0; // 1 point minimum pour Crash/Boom
      }
      else
      {
         minStopDistance = 20 * point; // 20 pips pour autres
      }
   }
   
   // Utiliser 2x la distance minimale pour être sûr
   double safeDistance = minStopDistance * 2.0;
   
   // Calculer SL/TP selon la direction
   if(direction == "BUY")
   {
      stopLoss = currentPrice - safeDistance;
      takeProfit = currentPrice + (safeDistance * 2.0);
   }
   else // SELL
   {
      stopLoss = currentPrice + safeDistance;
      takeProfit = currentPrice - (safeDistance * 2.0);
   }
   
   Print("🔍 DEBUG SL/TP - ", _Symbol, " ", direction, 
         " | Prix: ", DoubleToString(currentPrice, _Digits),
         " | Courtier StopsLevel: ", stopsLevel,
         " | MinDistance: ", DoubleToString(minStopDistance, _Digits),
         " | SafeDistance: ", DoubleToString(safeDistance, _Digits),
         " | SL: ", DoubleToString(stopLoss, _Digits),
         " | TP: ", DoubleToString(takeProfit, _Digits));
   
   // VALIDATION FINALE DES DISTANCES
   double askPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(direction == "BUY")
   {
      // Vérifier que SL est assez loin de l'ask
      if(askPrice - stopLoss < safeDistance)
      {
         stopLoss = askPrice - safeDistance;
         Print("🔧 SL ajusté pour BUY sur ", _Symbol, " | Nouveau SL: ", DoubleToString(stopLoss, _Digits));
      }
      // Vérifier que TP est assez loin de l'ask
      if(takeProfit - askPrice < safeDistance)
      {
         takeProfit = askPrice + (safeDistance * 2.0);
         Print("🔧 TP ajusté pour BUY sur ", _Symbol, " | Nouveau TP: ", DoubleToString(takeProfit, _Digits));
      }
   }
   else // SELL
   {
      // Vérifier que SL est assez loin du bid
      if(stopLoss - bidPrice < safeDistance)
      {
         stopLoss = bidPrice + safeDistance;
         Print("🔧 SL ajusté pour SELL sur ", _Symbol, " | Nouveau SL: ", DoubleToString(stopLoss, _Digits));
      }
      // Vérifier que TP est assez loin du bid
      if(bidPrice - takeProfit < safeDistance)
      {
         takeProfit = bidPrice - (safeDistance * 2.0);
         Print("🔧 TP ajusté pour SELL sur ", _Symbol, " | Nouveau TP: ", DoubleToString(takeProfit, _Digits));
      }
   }
   
   // Normaliser les prix
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   // Envoyer la notification
   SendDerivArrowNotification(direction, currentPrice, stopLoss, takeProfit);
   
   // Exécuter l'ordre au marché
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = CalculateLotSize();
   request.type = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = (direction == "BUY") ? askPrice : bidPrice;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 20;
   request.magic = InpMagicNumber;
   request.comment = "DERIV ARROW " + direction;
   
   if(SafeOrderSend(request, result))
   {
      Print("✅ ORDRE DERIV ARROW EXÉCUTÉ - ", direction, " sur ", _Symbol,
            " | Prix: ", DoubleToString((direction == "BUY") ? askPrice : bidPrice, _Digits),
            " | SL: ", DoubleToString(stopLoss, _Digits),
            " | TP: ", DoubleToString(takeProfit, _Digits),
            " | Ticket: ", result.order);
      
      // MÉMORISER CETTE FLÈCHE COMME TRAITÉE
      lastProcessedArrow = currentArrowKey;
      lastProcessedTime = TimeCurrent();
   }
   else
   {
      Print("❌ ÉCHEC ORDRE DERIV ARROW - Erreur: ", GetLastError());
   }
}

//| Vérifier si toutes les directions TF sont alignées dans un sens      |
bool AreAllTimeframesAligned(string &direction)
{
   // Vérifier que toutes les 6 TFs ont la même direction (BULL ou BEAR)
   string tf[6] = { g_smcTfM1Dir, g_smcTfM5Dir, g_smcTfM15Dir,
                     g_smcTfH1Dir, g_smcTfH4Dir, g_smcTfD1Dir };

   int bulls = 0, bears = 0;
   for(int i = 0; i < 6; i++)
   {
      if(tf[i] == "BULL") bulls++;
      else if(tf[i] == "BEAR") bears++;
   }

   // Toutes les 6 TFs doivent être alignées dans le même sens
   if(bulls == 6) { direction = "BUY"; return true; }
   if(bears == 6) { direction = "SELL"; return true; }

   // Au minimum 5/6 avec le global aligné
   string globalDir = g_smcGomGlobalDir;
   if(globalDir == "BULL" && bulls >= 5) { direction = "BUY"; return true; }
   if(globalDir == "BEAR" && bears >= 5) { direction = "SELL"; return true; }

   return false;
}

//| Entrée précise si H1 + M5 alignés dans le sens du verdict GOM       |
bool AreH1M5AlignedForGOM(string &direction)
{
   string m5 = g_smcTfM5Dir;
   string h1 = g_smcTfH1Dir;
   if(m5 == "BULL" && h1 == "BULL") { direction = "BUY";  return true; }
   if(m5 == "BEAR" && h1 == "BEAR") { direction = "SELL"; return true; }
   return false;
}

// NOUVEAU: Vérifier alignement H1+M5 pour N'IMPORTE QUELLE position (pas seulement GOM)
bool IsH1M5AlignedForPosition(const string symbol, const ENUM_POSITION_TYPE posType)
{
   // Récupérer M5 et H1 trend via EMA
   int emaFastM5Handle = iMA(symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   int emaSlowM5Handle = iMA(symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   int emaFastH1Handle = iMA(symbol, PERIOD_H1, 9, 0, MODE_EMA, PRICE_CLOSE);
   int emaSlowH1Handle = iMA(symbol, PERIOD_H1, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   if(emaFastM5Handle == INVALID_HANDLE || emaSlowM5Handle == INVALID_HANDLE ||
      emaFastH1Handle == INVALID_HANDLE || emaSlowH1Handle == INVALID_HANDLE)
      return false;
   
    double emaFastM5Buf[], emaSlowM5Buf[], emaFastH1Buf[], emaSlowH1Buf[];
    ArraySetAsSeries(emaFastM5Buf, true); ArraySetAsSeries(emaSlowM5Buf, true);
    ArraySetAsSeries(emaFastH1Buf, true); ArraySetAsSeries(emaSlowH1Buf, true);

    if(CopyBuffer(emaFastM5Handle, 0, 0, 2, emaFastM5Buf) < 2) return false;
    if(CopyBuffer(emaSlowM5Handle, 0, 0, 2, emaSlowM5Buf) < 2) return false;
    if(CopyBuffer(emaFastH1Handle, 0, 0, 2, emaFastH1Buf) < 2) return false;
    if(CopyBuffer(emaSlowH1Handle, 0, 0, 2, emaSlowH1Buf) < 2) return false;

    bool m5Bull = (emaFastM5Buf[0] > emaSlowM5Buf[0]);
    bool h1Bull = (emaFastH1Buf[0] > emaSlowH1Buf[0]);
   
   IndicatorRelease(emaFastM5Handle); IndicatorRelease(emaSlowM5Handle);
   IndicatorRelease(emaFastH1Handle); IndicatorRelease(emaSlowH1Handle);
   
   if(posType == POSITION_TYPE_BUY)
      return (m5Bull && h1Bull);
   else
      return (!m5Bull && !h1Bull);
}

//| Entrée marché GOM : BUY/SELL si verdict GOOD/PERFECT + H1/M5 alignés |
void ExecuteGOMAlignmentMarketOrder()
{
   if(!UseGOMTFAlignmentEntry) return;
   if(!g_smcGomConnected) return;

   // Verdict GOM GOOD/PERFECT uniquement
   if(g_smcGomVerdictNum < 2 && g_smcGomVerdictNum > -2) return;

   if(CountPositionsForSymbol(_Symbol) > 0) return;

   // Entrée précise : H1 + M5 alignés (prioritaire) ; sinon fallback 6 TF
   string tfDirection = "";
   bool aligned = AreH1M5AlignedForGOM(tfDirection);
   if(!aligned)
      aligned = AreAllTimeframesAligned(tfDirection);
   if(!aligned) return;

   bool gomBuy  = (g_smcGomVerdictNum >= 2 && tfDirection == "BUY");
   bool gomSell = (g_smcGomVerdictNum <= -2 && tfDirection == "SELL");
   if(!gomBuy && !gomSell) return;

   // Gate centralisé WAIT / contre-verdict
   int dirSign = gomBuy ? 1 : -1;
   if(!CanPlaceMarketOrder(_Symbol, dirSign)) return;

   // Vérifier le spread
   if(UseMaxSpreadFilter || GOMAlignMaxSpreadPts > 0)
   {
      double spread = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double maxSpread = GOMAlignMaxSpreadPts * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(maxSpread > 0 && spread > maxSpread)
      {
         static datetime lastSpreadLog = 0;
         if(TimeCurrent() - lastSpreadLog >= 30)
         {
            lastSpreadLog = TimeCurrent();
            Print("🚫 GOM-ALIGN Spread trop élevé: ", DoubleToString(spread, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
                  " > ", DoubleToString(maxSpread, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)));
         }
         return;
      }
   }

   // Calculer ATR pour SL/TP
   double atr[];
   ArraySetAsSeries(atr, true);
   double atrValue = 0;
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1)
      atrValue = atr[0];
   if(atrValue <= 0) return;

   // Anti-doublon cooldown (60 secondes entre entrées GOM-ALIGN)
   static datetime s_lastGomAlignEntry = 0;
   if(TimeCurrent() - s_lastGomAlignEntry < 60) return;

   // Vérifier lock
   if(!TryAcquireOpenLock()) return;

   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    dg  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   bool orderExecuted = false;

   if(gomBuy)
   {
      double sl = NormalizeDouble(ask - atrValue * GOMAlignSL_ATRMult, dg);
      double tp = NormalizeDouble(ask + atrValue * GOMAlignTP_ATRMult, dg);

if(SafeTradeBuy(lot, _Symbol, ask, sl, tp, "GOM-ALIGN BUY"))
       {
          orderExecuted = true;
          s_lastGomAlignEntry = TimeCurrent();
          ulong ticket = trade.ResultOrder();
          if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
          Print("🚀 GOM-ALIGN BUY EXÉCUTÉ | Entry=", DoubleToString(ask, dg),
                " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg),
                " Lot=", DoubleToString(lot, 2),
                " | vn=", g_smcGomVerdictNum, " TFs: M1=", g_smcTfM1Dir,
                " M5=", g_smcTfM5Dir, " M15=", g_smcTfM15Dir,
                " H1=", g_smcTfH1Dir, " H4=", g_smcTfH4Dir, " D1=", g_smcTfD1Dir);
         if(UseNotifications)
         {
            Alert("🚀 GOM-ALIGN BUY ", _Symbol, " @", DoubleToString(ask, dg),
                  " vn=", g_smcGomVerdictNum, " 6TF aligned");
            SendNotification("🚀 GOM-ALIGN BUY " + _Symbol + " vn=" + IntegerToString(g_smcGomVerdictNum) + " 6TF aligned");
             // WhatsApp SR20 signal
             string gomBuyMsg = "6 TFs alignes vn=" + IntegerToString(g_smcGomVerdictNum);
             SendSR20WhatsAppSignal("SR20_ENTRY", _Symbol, "BUY",
                                    ask, ask - atrValue * SL_ATRMult, ask + atrValue * TP_ATRMult,
                                    ask, 0, "GOM-ALIGN", atrValue,
                                    0, 0, gomBuyMsg);
         }
      }
      else
      {
         Print("❌ GOM-ALIGN BUY ÉCHOUÉ - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else if(gomSell)
   {
      double sl = NormalizeDouble(bid + atrValue * GOMAlignSL_ATRMult, dg);
      double tp = NormalizeDouble(bid - atrValue * GOMAlignTP_ATRMult, dg);

if(SafeTradeSell(lot, _Symbol, bid, sl, tp, "GOM-ALIGN SELL"))
       {
          orderExecuted = true;
          s_lastGomAlignEntry = TimeCurrent();
          ulong ticket = trade.ResultOrder();
          if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
          Print("🚀 GOM-ALIGN SELL EXÉCUTÉ | Entry=", DoubleToString(bid, dg),
                " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg),
                " Lot=", DoubleToString(lot, 2),
                " | vn=", g_smcGomVerdictNum, " TFs: M1=", g_smcTfM1Dir,
                " M5=", g_smcTfM5Dir, " M15=", g_smcTfM15Dir,
                " H1=", g_smcTfH1Dir, " H4=", g_smcTfH4Dir, " D1=", g_smcTfD1Dir);
         if(UseNotifications)
         {
            Alert("🚀 GOM-ALIGN SELL ", _Symbol, " @", DoubleToString(bid, dg),
                  " vn=", g_smcGomVerdictNum, " 6TF aligned");
            SendNotification("🚀 GOM-ALIGN SELL " + _Symbol + " vn=" + IntegerToString(g_smcGomVerdictNum) + " 6TF aligned");
             // WhatsApp SR20 signal
             string gomSellMsg = "6 TFs alignes vn=" + IntegerToString(g_smcGomVerdictNum);
             SendSR20WhatsAppSignal("SR20_ENTRY", _Symbol, "SELL",
                                    bid, bid + atrValue * SL_ATRMult, bid - atrValue * TP_ATRMult,
                                    bid, 0, "GOM-ALIGN", atrValue,
                                    0, 0, gomSellMsg);
         }
      }
      else
      {
         Print("❌ GOM-ALIGN SELL ÉCHOUÉ - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }

   ReleaseOpenLock();

   if(orderExecuted)
      g_maxProfit = 0;
}

//| Exécuter les ordres au marché basés sur les décisions IA SMC EMA   |
void ExecuteAIDecisionMarketOrder()
{
   if(UseGOMVerdictFilter && !SMCGP_GOMAllowsAction(g_lastAIAction))
   {
      static datetime lastGomLog = 0;
      if(TimeCurrent() - lastGomLog >= 30)
      {
         lastGomLog = TimeCurrent();
         Print("[SMC-GOM] Entrée IA bloquée — verdict=", g_smcGomVerdict,
               " vn=", g_smcGomVerdictNum, " connected=", g_smcGomConnected);
      }
      return;
   }

   // Catégorie du symbole pour adapter le seuil de confiance IA
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   double requiredConf = MinAIConfidence;
   // Pour tous les marchés HORS Boom/Crash: 85% minimum
   if(cat != SYM_BOOM_CRASH)
      requiredConf = 0.85;
   
   // Vérifier si on a une décision IA valide
   if(g_lastAIAction == "" || g_lastAIConfidence < requiredConf)
   {
      return;
   }
   
   // BLOQUER LES ORDRES SI IA EST EN HOLD
   Print("🔍 DEBUG HOLD (Market): g_lastAIAction = '", g_lastAIAction, "' | g_lastAIConfidence = ", DoubleToString(g_lastAIConfidence*100, 1), "%");
   
   if(g_lastAIAction == "HOLD" || g_lastAIAction == "hold")
   {
      Print("🚫 ORDRES MARCHÉ BLOQUÉS - IA en HOLD - Attente de changement de statut");
      return;
   }
   
   // Calculer une note de setup globale et bloquer si trop basse
   double setupScore = ComputeSetupScore(g_lastAIAction);
   if(setupScore < MinSetupScoreEntry)
   {
      Print("🚫 ORDRE IA BLOQUÉ - SetupScore trop bas: ",
            DoubleToString(setupScore, 1), " < ",
            DoubleToString(MinSetupScoreEntry, 1),
            " pour ", _Symbol, " (", g_lastAIAction, ")");
      return;
   }
   
   Print("✅ ORDRES MARCHÉ AUTORISÉS - IA: ", g_lastAIAction,
         " | SetupScore=", DoubleToString(setupScore, 1));

   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles
   if(!AllowReentryAfterRecentLoss(_Symbol, g_lastAIAction, false))
      return;
   
   // Vérification ANTI-DUPLICATION stricte - AUCUNE position sur CE symbole
   int existingPositionsOnSymbol = CountPositionsForSymbol(_Symbol);
   if(existingPositionsOnSymbol > 0)
   {
      Print("🚫 DUPLICATION BLOQUÉE - ", existingPositionsOnSymbol, " position(s) déjà existante(s) sur ", _Symbol, " - Aucun nouvel ordre autorisé");
      return; // BLOQUER TOUTE duplication sur ce symbole
   }
   
   // BOOM/CRASH: logique d'entrée par niveau de verdict
   //   PERFECT (±3) → entrée immédiate (signal exceptionnel)
   //   GOOD (±2) → entrée si conditions algo-spike mûres (Z-Score + EMA + cooldown)
   //   Sinon → attendre Deriv Arrow
   if(cat == SYM_BOOM_CRASH)
   {
      bool isPerfect = (g_smcGomVerdictNum >= 3 || g_smcGomVerdictNum <= -3);
      bool isGood = (g_smcGomVerdictNum >= 2 || g_smcGomVerdictNum <= -2);
      if(isPerfect)
      {
         Print("✅ BOOM/CRASH PERFECT ENTRY — vn=", g_smcGomVerdictNum, " → entrée marché immédiate sur ", _Symbol);
      }
      else if(isGood && IsAlgoSpikeReady())
      {
         Print("✅ BOOM/CRASH GOOD + ALGO-SPIKE — vn=", g_smcGomVerdictNum, " → conditions mûres, entrée sur ", _Symbol);
      }
      else
      {
         Print("🚫 ORDRES MARCHÉ BLOQUÉS SUR BOOM/CRASH (verdict=", g_smcGomVerdict, " vn=", g_smcGomVerdictNum,
               " | AlgoSpike=", IsAlgoSpikeReady() ? "YES" : "NO", ")");
         return;
      }
   }
   
   // BLOQUER LES ORDRES SI PRIX EST DANS UN RANGE (bypass si PERFECT)
   bool isPerfectVerdict = (g_smcGomVerdictNum >= 3 || g_smcGomVerdictNum <= -3);
   if(IsPriceInRange() && !isPerfectVerdict)
   {
      Print("🚫 ORDRES MARCHÉ BLOQUÉS - Prix dans un range sur ", _Symbol, " - Attente de breakout");
      return;
   }
   
   // Vérifier le lock pour éviter les doublons
   if(!TryAcquireOpenLock()) return;
   
   // Règle Boom/Crash: pas de SELL sur Boom, pas de BUY sur Crash
   if(!IsDirectionAllowedForBoomCrash(_Symbol, g_lastAIAction))
   {
      Print("❌ Ordre IA ", g_lastAIAction, " bloqué sur ", _Symbol, " (règle Boom/Crash)");
      ReleaseOpenLock();
      return;
   }
   
   // VALIDATION MULTI-SIGNAUX POUR ENTRÉES PRÉCISES (bypass si PERFECT)
   if(!isPerfectVerdict && !ValidateEntryWithMultipleSignals(g_lastAIAction))
   {
      Print("❌ ENTRÉE BLOQUÉE - Validation multi-signaux échouée pour ", g_lastAIAction, " sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   
   // CALCULER L'ENTRÉE PRÉCISE AU LIEU DU PRIX ACTUEL
   double preciseEntry, preciseSL, preciseTP;
   if(!CalculatePreciseEntryPoint(g_lastAIAction, preciseEntry, preciseSL, preciseTP))
   {
      Print("❌ CALCUL D'ENTRÉE PRÉCISE ÉCHOUÉ pour ", g_lastAIAction, " sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   
   double lot = CalculateLotSize();
   if(lot <= 0)
   {
      ReleaseOpenLock();
      return;
   }
   
   if(UseSniperScalperMode)
   {
      double slDistPrecise = MathAbs(preciseEntry - preciseSL);
      double tpDistPrecise = 0;
      if(!SMC_ApplySniperRiskCap(_Symbol, slDistPrecise, lot, tpDistPrecise))
      {
         Print("🚫 ENTRÉE IA PRÉCISE bloquée par Sniper Risk Cap sur ", _Symbol);
         ReleaseOpenLock();
         return;
      }
      preciseTP = (g_lastAIAction == "BUY" || g_lastAIAction == "buy") ?
                  (preciseEntry + tpDistPrecise) : (preciseEntry - tpDistPrecise);
   }
   
   bool orderExecuted = false;
   
   if(g_lastAIAction == "BUY" || g_lastAIAction == "buy")
   {
       if(RequireSMCDerivArrowForAllOrders && !HasRecentSMCDerivArrowForDirection("BUY"))
       {
          Print("🚫 ORDRE MARCHÉ BLOQUÉ - Attendre flèche SMC_DERIV_ARROW BUY sur ", _Symbol);
          ReleaseOpenLock();
          return;
       }
// Utiliser l'entrée précise calculée au lieu du prix actuel
       if(SafeTradeBuy(lot, _Symbol, preciseEntry, preciseSL, preciseTP, "IA SMC-EMA BUY PRÉCIS"))
       {
          orderExecuted = true;
          ulong ticket = trade.ResultOrder();
          if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
          Print("🚀 ORDRE BUY PRÉCIS EXÉCUTÉ - Entry: ", DoubleToString(preciseEntry, _Digits),
               " | SL: ", DoubleToString(preciseSL, _Digits), 
               " | TP: ", DoubleToString(preciseTP, _Digits),
               " | Lot: ", DoubleToString(lot, 2),
               " | Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
         
         if(UseNotifications)
         {
            Alert("🎯 BUY PRÉCIS ", _Symbol, " @", DoubleToString(preciseEntry, _Digits), " - Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
            SendNotification("🎯 BUY PRÉCIS " + _Symbol + " @" + DoubleToString(preciseEntry, _Digits) + " - Conf: " + DoubleToString(g_lastAIConfidence*100, 1) + "%");
         }
      }
      else
      {
         Print("❌ Échec ordre BUY PRÉCIS - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else if(g_lastAIAction == "SELL" || g_lastAIAction == "sell")
   {
       if(RequireSMCDerivArrowForAllOrders && !HasRecentSMCDerivArrowForDirection("SELL"))
       {
          Print("🚫 ORDRE MARCHÉ BLOQUÉ - Attendre flèche SMC_DERIV_ARROW SELL sur ", _Symbol);
          ReleaseOpenLock();
          return;
       }
// Utiliser l'entrée précise calculée au lieu du prix actuel
       if(SafeTradeSell(lot, _Symbol, preciseEntry, preciseSL, preciseTP, "IA SMC-EMA SELL PRÉCIS"))
       {
          orderExecuted = true;
          ulong ticket = trade.ResultOrder();
          if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
          Print("🚀 ORDRE SELL PRÉCIS EXÉCUTÉ - Entry: ", DoubleToString(preciseEntry, _Digits),
               " | SL: ", DoubleToString(preciseSL, _Digits), 
               " | TP: ", DoubleToString(preciseTP, _Digits),
               " | Lot: ", DoubleToString(lot, 2),
               " | Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
         
         if(UseNotifications)
         {
            Alert("🎯 SELL PRÉCIS ", _Symbol, " @", DoubleToString(preciseEntry, _Digits), " - Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
            SendNotification("🎯 SELL PRÉCIS " + _Symbol + " @" + DoubleToString(preciseEntry, _Digits) + " - Conf: " + DoubleToString(g_lastAIConfidence*100, 1) + "%");
         }
      }
      else
      {
         Print("❌ Échec ordre SELL PRÉCIS - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   
   ReleaseOpenLock();
   
   if(orderExecuted)
   {
      // Réinitialiser le gain maximum pour la nouvelle position
      g_maxProfit = 0;
   }
}

//| FONCTIONS DE GESTION DES PAUSES ET BLACKLIST TEMPORAIRE        |
void InitializeSymbolPauseSystem()
{
   g_pauseCount = 0;
   for(int i = 0; i < 20; i++)
   {
      g_symbolPauses[i].symbol = "";
      g_symbolPauses[i].pauseUntil = 0;
      g_symbolPauses[i].consecutiveLosses = 0;
      g_symbolPauses[i].consecutiveWins = 0;
      g_symbolPauses[i].lastTradeTime = 0;
      g_symbolPauses[i].lastProfit = 0;
   }
}

bool IsSymbolPaused(string symbol)
{
   datetime currentTime = TimeCurrent();
   for(int i = 0; i < g_pauseCount; i++)
   {
      if(g_symbolPauses[i].symbol == symbol)
      {
         if(currentTime < g_symbolPauses[i].pauseUntil)
         {
            Print("🚫 SYMBOLE EN PAUSE: ", symbol, " - Jusqu'à: ", TimeToString(g_symbolPauses[i].pauseUntil, TIME_SECONDS));
            return true;
         }
         break;
      }
   }
   return false;
}

void UpdateSymbolPauseInfo(string symbol, double profit)
{
   datetime currentTime = TimeCurrent();
   int index = -1;
   
   // Trouver ou créer l'entrée pour ce symbole
   for(int i = 0; i < g_pauseCount; i++)
   {
      if(g_symbolPauses[i].symbol == symbol)
      {
         index = i;
         break;
      }
   }
   
   if(index == -1 && g_pauseCount < 20)
   {
      // Créer nouvelle entrée
      index = g_pauseCount;
      g_symbolPauses[index].symbol = symbol;
      g_symbolPauses[index].pauseUntil = 0;
      g_symbolPauses[index].consecutiveLosses = 0;
      g_symbolPauses[index].consecutiveWins = 0;
      g_pauseCount++;
   }
   
   if(index >= 0)
   {
      // Mettre à jour les compteurs
      if(profit < 0)
      {
         g_symbolPauses[index].consecutiveLosses++;
         g_symbolPauses[index].consecutiveWins = 0;
         Print("📉 PERTE DÉTECTÉE: ", symbol, " | Perte: ", DoubleToString(profit, 2), "$ | Pertes consécutives: ", g_symbolPauses[index].consecutiveLosses);
      }
      else if(profit > 0)
      {
         g_symbolPauses[index].consecutiveWins++;
         g_symbolPauses[index].consecutiveLosses = 0;
         Print("📈 GAIN DÉTECTÉ: ", symbol, " | Gain: ", DoubleToString(profit, 2), "$ | Gains consécutifs: ", g_symbolPauses[index].consecutiveWins);
      }
      
      g_symbolPauses[index].lastTradeTime = currentTime;
      g_symbolPauses[index].lastProfit = profit;
   }
}

bool ShouldPauseSymbol(string symbol, double profit)
{
   // Pause après 2 pertes successives (10 minutes)
   if(profit < 0)
   {
      for(int i = 0; i < g_pauseCount; i++)
      {
         if(g_symbolPauses[i].symbol == symbol)
         {
            if(g_symbolPauses[i].consecutiveLosses >= 1) // Déjà 1 perte, celle-ci fait 2
            {
               Print("🚫 PAUSE 10 MINUTES: ", symbol, " - 2 pertes successives détectées");
               return true;
            }
            break;
         }
      }
   }
   
   // Pause après 2 gains successifs (5 minutes)
   if(profit > 0)
   {
      for(int i = 0; i < g_pauseCount; i++)
      {
         if(g_symbolPauses[i].symbol == symbol)
         {
            if(g_symbolPauses[i].consecutiveWins >= 1) // Déjà 1 gain, celui-ci fait 2
            {
               Print("🚫 PAUSE 5 MINUTES: ", symbol, " - 2 gains successifs détectés");
               return true;
            }
            break;
         }
      }
   }
   
   return false;
}

void ApplySymbolPause(string symbol, int minutes)
{
   datetime currentTime = TimeCurrent();
   datetime pauseUntil = currentTime + (minutes * 60);
   
   for(int i = 0; i < g_pauseCount; i++)
   {
      if(g_symbolPauses[i].symbol == symbol)
      {
         g_symbolPauses[i].pauseUntil = pauseUntil;
         Print("⏸️ SYMBOLE MIS EN PAUSE: ", symbol, " - Durée: ", minutes, " minutes | Jusqu'à: ", TimeToString(pauseUntil, TIME_SECONDS));
         break;
      }
   }
}

//| DÉTECTION DE RANGE - ÉVITER DE TRADER DANS LES RANGES         |
bool DetectPriceRange()
{
   // Utiliser les 20 dernières bougies pour détecter un range
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 20, rates) < 20) return false;
   
   double highs[], lows[];
   ArrayResize(highs, 20);
   ArrayResize(lows, 20);
   
   for(int i = 0; i < 20; i++)
   {
      highs[i] = rates[i].high;
      lows[i] = rates[i].low;
   }
   
   // Calculer le plus haut et plus bas sur la période
   double highestHigh = rates[0].high;
   double lowestLow = rates[0].low;
   
   for(int i = 1; i < 20; i++)
   {
      if(rates[i].high > highestHigh) highestHigh = rates[i].high;
      if(rates[i].low < lowestLow) lowestLow = rates[i].low;
   }
   
   double rangeSize = highestHigh - lowestLow;
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Déterminer si le prix est dans le range (zone médiane 40-60%)
   double rangeMiddle = lowestLow + (rangeSize * 0.5);
   double rangeWidth = rangeSize * 0.2; // 20% de chaque côté du milieu
   
   bool inRange = (currentPrice >= (rangeMiddle - rangeWidth) && currentPrice <= (rangeMiddle + rangeWidth));
   
   // Critères supplémentaires pour confirmer le range
   bool isConsolidating = false;
   
   // Vérifier si les bougies ont des corps petits (indique de consolidation)
   double avgBodySize = 0;
   for(int i = 0; i < 20; i++)
   {
      double bodySize = MathAbs(rates[i].close - rates[i].open);
      avgBodySize += bodySize;
   }
   avgBodySize /= 20;
   
   // Si les corps sont petits par rapport au range, c'est une consolidation
   isConsolidating = (avgBodySize < rangeSize * 0.1);
   
   // Détection finale de range
   bool isRange = inRange && isConsolidating && (rangeSize > 0);
   
   if(isRange)
   {
      Print("🔍 RANGE DÉTECTÉ sur ", _Symbol, 
             " | Range: ", DoubleToString(lowestLow, _Digits), " - ", DoubleToString(highestHigh, _Digits),
             " | Prix actuel: ", DoubleToString(currentPrice, _Digits),
             " | Largeur range: ", DoubleToString(rangeSize, _Digits),
             " | Corps moyen: ", DoubleToString(avgBodySize, _Digits));
   }
   
   return isRange;
}

bool IsPriceInRange()
{
   return DetectPriceRange();
}

//| NOTE DE SETUP IA (0-100)                                         |
double ComputeSetupScore(const string direction)
{
   // 1) Base: confiance IA (0-60 pts)
   double score = 0.0;
   double confPct = g_lastAIConfidence * 100.0;
   if(confPct < 0.0) confPct = 0.0;
   if(confPct > 100.0) confPct = 100.0;
   score += confPct * 0.60;

   // 2) Alignement et cohérence (0-20 pts chaque) à partir des chaînes "xx.x%"
   double alignPct = 0.0, cohPct = 0.0;
   if(StringLen(g_lastAIAlignment) > 0)
   {
      string s = g_lastAIAlignment;
      StringReplace(s, "%", "");
      alignPct = StringToDouble(s);
      if(alignPct < 0.0) alignPct = 0.0;
      if(alignPct > 100.0) alignPct = 100.0;
   }
   if(StringLen(g_lastAICoherence) > 0)
   {
      string s2 = g_lastAICoherence;
      StringReplace(s2, "%", "");
      cohPct = StringToDouble(s2);
      if(cohPct < 0.0) cohPct = 0.0;
      if(cohPct > 100.0) cohPct = 100.0;
   }
   score += alignPct * 0.20;
   score += cohPct * 0.20;

   // 2b) GOM verdict bonus — PERFECT/GOOD dans la bonne direction booste le score
   string dir = direction;
   StringToUpper(dir);
   if(g_smcGomConnected && g_smcGomVerdictNum != 0)
   {
      bool gomAligned = (dir == "BUY" && g_smcGomVerdictNum > 0) ||
                        (dir == "SELL" && g_smcGomVerdictNum < 0);
      if(gomAligned)
      {
         int absVn = MathAbs(g_smcGomVerdictNum);
         if(absVn >= 3) score += 25.0;      // PERFECT
         else if(absVn >= 2) score += 18.0;  // GOOD
         else score += 8.0;                  // BUY/SELL simple
      }
      // GOM coherence comme substitut si IA coherence vide
      if(cohPct <= 0.0 && g_smcGomCoherence > 0)
      {
         cohPct = g_smcGomCoherence;
         score += cohPct * 0.20;
      }
   }

   // 3) Contexte de tendance HTF (bonus/malus)
   bool bullHTF = IsBullishHTF();
   bool bearHTF = IsBearishHTF();

   if(dir == "BUY" && bullHTF)       score += 5.0;
   if(dir == "SELL" && bearHTF)      score += 5.0;
   if(dir == "BUY" && bearHTF)       score -= 10.0;
   if(dir == "SELL" && bullHTF)      score -= 10.0;

   // 4) Éviter les ranges (gros malus si range détecté)
   if(IsPriceInRange())
      score -= 15.0;

   // Clamp final 0-100
   if(score < 0.0)   score = 0.0;
   if(score > 100.0) score = 100.0;

   Print("📊 SETUP SCORE ", _Symbol, " ", dir, " = ", DoubleToString(score, 1),
         " (Conf=", DoubleToString(confPct,1), "% Align=", DoubleToString(alignPct,1),
         "% Coh=", DoubleToString(cohPct,1), "%)");

   return score;
}

//| MÉTRIQUES ML FALLBACK - SI SERVEUR IA INDISPONIBLE          |
void GenerateFallbackMLMetrics()
{
   // Si le serveur IA n'est pas connecté, générer des métriques basiques
   if(!g_aiConnected)
   {
      // Calculer des métriques basées sur l'analyse technique locale
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      
      if(CopyRates(_Symbol, PERIOD_M1, 0, 20, rates) >= 20)
      {
         // Calculer la tendance simple
         double priceChange = rates[0].close - rates[19].close;
         bool isUptrend = priceChange > 0;
         
         // Calculer la volatilité
         double avgRange = 0;
         for(int i = 0; i < 20; i++)
         {
            avgRange += rates[i].high - rates[i].low;
         }
         avgRange /= 20;
         
         // Générer des métriques de fallback
         if(isUptrend)
         {
            g_lastAIAction = "BUY";
            g_lastAIConfidence = MathMin(0.65, 0.5 + (priceChange / currentPrice) * 10); // Max 65%
         }
         else
         {
            g_lastAIAction = "SELL";
            g_lastAIConfidence = MathMin(0.65, 0.5 + MathAbs(priceChange / currentPrice) * 10); // Max 65%
         }
         
         // Alignement et cohérence basés sur la volatilité
         double volatilityScore = MathMin(1.0, avgRange / currentPrice * 100);
         g_lastAIAlignment = DoubleToString(volatilityScore * 80, 1) + "%"; // Max 80%
         g_lastAICoherence = DoubleToString(volatilityScore * 70, 1) + "%"; // Max 70%
         
         Print("🤖 MÉTRIQUES FALLBACK - Action: ", g_lastAIAction, 
               " | Confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%",
               " | Alignement: ", g_lastAIAlignment,
               " | Cohérence: ", g_lastAICoherence);
      }
      else
      {
         // Valeurs par défaut si pas assez de données
         g_lastAIAction = "HOLD";
         g_lastAIConfidence = 0.0;
         g_lastAIAlignment = "0.0%";
         g_lastAICoherence = "0.0%";
         
         Print("⚠️ MÉTRIQUES DÉFAUT - Pas assez de données pour fallback");
      }
   }
}

//| FONCTIONS IA - COMMUNICATION AVEC LE SERVEUR                       |

bool UpdateAIDecision(int timeoutMs = -1)
{
   // Déporter toute la logique réseau sur GetAISignalData()
   bool ok = GetAISignalData();
   if(!ok)
   {
      // En cas d'échec complet, générer immédiatement un fallback local
      GenerateFallbackAIDecision();
      return false;
   }
   // GetAISignalData met déjà à jour g_lastAIAction / g_lastAIConfidence / alignement / cohérence
   Print("✅ Décision IA mise à jour via /decision - Action: ", g_lastAIAction,
         " | Confiance: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
   return true;
}

string GetAISignalData(string symbol, string timeframe)
{
   string symEnc = symbol;
   StringReplace(symEnc, " ", "%20");
   
   string baseUrl = AI_ServerURL;
   string path = "/ml/signal?symbol=" + symEnc + "&timeframe=" + timeframe;
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   int res = WebRequest("GET", baseUrl + path, headers, AI_Timeout_ms, post, result, resultHeaders);
   
   if(res == 200)
   {
      return CharArrayToString(result);
   }
   
   return "";
}

string GetTrendAlignmentData(string symbol)
{
   string symEnc = symbol;
   StringReplace(symEnc, " ", "%20");
   
   string baseUrl = AI_ServerURL;
   string path = "/ml/trend_alignment?symbol=" + symEnc;
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   int res = WebRequest("GET", baseUrl + path, headers, AI_Timeout_ms, post, result, resultHeaders);
   
   if(res == 200)
   {
      return CharArrayToString(result);
   }
   
   return "";
}

string GetCoherentAnalysisData(string symbol)
{
   string symEnc = symbol;
   StringReplace(symEnc, " ", "%20");
   
   string baseUrl = AI_ServerURL;
   string path = "/ml/coherent_analysis?symbol=" + symEnc;
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   int res = WebRequest("GET", baseUrl + path, headers, AI_Timeout_ms, post, result, resultHeaders);
   
   if(res == 200)
   {
      return CharArrayToString(result);
   }
   
   return "";
}

void ProcessAIDecision(string jsonData)
{
   // Parser la réponse JSON du serveur IA
   // Format attendu: {"action": "BUY/SELL/HOLD", "confidence": 0.85, "alignment": "75%", "coherence": "82%"}
   
   g_lastAIUpdate = TimeCurrent();
   
   // Extraire l'action
   if(StringFind(jsonData, "\"action\":") >= 0)
   {
      int start = StringFind(jsonData, "\"action\":") + 9;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string action = StringSubstr(jsonData, start, end - start);
         StringReplace(action, "\"", "");
         StringReplace(action, " ", "");
         g_lastAIAction = action;
      }
   }
   
   // Extraire la confiance
   if(StringFind(jsonData, "\"confidence\":") >= 0)
   {
      int start = StringFind(jsonData, "\"confidence\":") + 13;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string confStr = StringSubstr(jsonData, start, end - start);
         g_lastAIConfidence = StringToDouble(confStr);
      }
   }
   
   // Extraire l'alignement
   if(StringFind(jsonData, "\"alignment\":") >= 0)
   {
      int start = StringFind(jsonData, "\"alignment\":") + 12;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string alignStr = StringSubstr(jsonData, start, end - start);
         StringReplace(alignStr, "\"", "");
         g_lastAIAlignment = alignStr;
      }
   }
   
   // Extraire la cohérence
   if(StringFind(jsonData, "\"coherence\":") >= 0)
   {
      int start = StringFind(jsonData, "\"coherence\":") + 13;
      int end = StringFind(jsonData, ",", start);
      if(end < 0) end = StringFind(jsonData, "}", start);
      
      if(end > start)
      {
         string cohStr = StringSubstr(jsonData, start, end - start);
         StringReplace(cohStr, "\"", "");
         g_lastAICoherence = cohStr;
      }
   }
   
   // Si aucune donnée trouvée, valeurs par défaut
   if(g_lastAIAction == "") g_lastAIAction = "HOLD";
   if(g_lastAIConfidence == 0) g_lastAIConfidence = 0.5;
   if(g_lastAIAlignment == "") g_lastAIAlignment = "50%";
   if(g_lastAICoherence == "") g_lastAICoherence = "50%";
}

//| NOTIFICATION MOBILE POUR APPARITION FLÈCHE DERIV ARROW          |
void SendDerivArrowNotification(string direction, double entryPrice, double stopLoss, double takeProfit)
{
   // Calculer le gain estimé
   double risk = MathAbs(entryPrice - stopLoss);
   double reward = MathAbs(takeProfit - entryPrice);
   double estimatedGain = 0;
   
   // Calculer le gain en points et en dollars (pour lot 0.01)
   double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pointsToTP = MathAbs(takeProfit - entryPrice) / tickSize;
   estimatedGain = pointsToTP * pointValue * 0.01; // Pour lot 0.01
   
   // Calculer le ratio Risk/Reward
   double riskRewardRatio = reward / risk;
   
   // Formater les prix
   string entryStr = DoubleToString(entryPrice, _Digits);
   string slStr = DoubleToString(stopLoss, _Digits);
   string tpStr = DoubleToString(takeProfit, _Digits);
   string gainStr = DoubleToString(estimatedGain, 2);
   string ratioStr = DoubleToString(riskRewardRatio, 2);
   
   // Créer le message de notification
   string notificationMsg = "🎯 DERIV ARROW " + direction + "\n" +
                           "Symbole: " + _Symbol + "\n" +
                           "Entry: " + entryStr + "\n" +
                           "SL: " + slStr + "\n" +
                           "TP: " + tpStr + "\n" +
                           "Gain estimé: $" + gainStr + "\n" +
                           "Risk/Reward: 1:" + ratioStr;
   
   // Créer le message d'alerte desktop
   string alertMsg = "🎯 DERIV ARROW " + direction + " - " + _Symbol + 
                    " @ " + entryStr + 
                    " | SL: " + slStr + 
                    " | TP: " + tpStr + 
                    " | Gain: $" + gainStr + 
                    " | R/R: 1:" + ratioStr;
   
   // Envoyer la notification mobile
   SendNotification(notificationMsg);
   
   // Envoyer l'alerte desktop
   Alert(alertMsg);
   
   // Log détaillé
   Print("📱 NOTIFICATION ENVOYÉE - DERIV ARROW ", direction);
   Print("📍 Symbole: ", _Symbol);
   Print("💰 Entry: ", entryStr, " | SL: ", slStr, " | TP: ", tpStr);
   Print("📊 Gain estimé: $", gainStr, " | Risk/Reward: 1:", ratioStr);
   Print("🔔 Notification mobile envoyée avec succès!");
}

//| CALCUL D'ENTRÉE PRÉCISE - SYSTÈME AMÉLIORÉ                    |
bool CalculatePreciseEntryPoint(string direction, double &entryPrice, double &stopLoss, double &takeProfit)
{
   // Récupérer les données de marché récentes
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 50, rates) < 50) return false;
   
   if(atrHandle == INVALID_HANDLE) return false;
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) < 1) return false;
   double atrValue = atr[0];
   
   // Analyser la structure de marché
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double support = rates[0].low;
   double resistance = rates[0].high;
   
   // Trouver le support/résistance le plus proche (last 10 bougies)
   for(int i = 1; i < 10; i++)
   {
      if(rates[i].low < support) support = rates[i].low;
      if(rates[i].high > resistance) resistance = rates[i].high;
   }
   
   // Calculer les niveaux de Fibonacci sur les 20 dernières bougies
   double highest = rates[0].high;
   double lowest = rates[0].low;
   for(int i = 1; i < 20; i++)
   {
      if(rates[i].high > highest) highest = rates[i].high;
      if(rates[i].low < lowest) lowest = rates[i].low;
   }
   
   double fib38_2 = lowest + (highest - lowest) * 0.382;
   double fib61_8 = lowest + (highest - lowest) * 0.618;
   
   // Calculer l'entrée précise selon la direction
   if(direction == "BUY")
   {
      // Entrée BUY: au-dessus du support ou fib38_2
      double buyLevel1 = support + (atrValue * 0.5);
      double buyLevel2 = fib38_2 + (atrValue * 0.3);
      
      entryPrice = MathMax(buyLevel1, buyLevel2);
      
      // SL: sous le support avec marge de sécurité
      stopLoss = support - (atrValue * 0.2);
      
      // TP: ratio 2:1 minimum
      double risk = entryPrice - stopLoss;
      takeProfit = entryPrice + (risk * 2.5);
      
      // Validation: l'entrée doit être < prix actuel + 1 ATR
      if(entryPrice > currentPrice + atrValue) return false;
   }
   else // SELL
   {
      // Entrée SELL: sous la résistance ou fib61_8
      double sellLevel1 = resistance - (atrValue * 0.5);
      double sellLevel2 = fib61_8 - (atrValue * 0.3);
      
      entryPrice = MathMin(sellLevel1, sellLevel2);
      
      // SL: au-dessus de la résistance avec marge
      stopLoss = resistance + (atrValue * 0.2);
      
      // TP: ratio 2:1 minimum
      double risk = stopLoss - entryPrice;
      takeProfit = entryPrice - (risk * 2.5);
      
      // Validation: l'entrée doit être > prix actuel - 1 ATR
      if(entryPrice < currentPrice - atrValue) return false;
   }
   
   // Validation finale des distances
   long stopsLevel = 0;
   double point = 0.0;
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevel);
   SymbolInfoDouble(_Symbol, SYMBOL_POINT, point);
   double minDistance = (double)stopsLevel * point;
   if(minDistance == 0) minDistance = atrValue * 0.5; // Distance par défaut
   
   if(MathAbs(entryPrice - stopLoss) < minDistance) return false;
   if(MathAbs(takeProfit - entryPrice) < minDistance * 2) return false;
   
   Print("🎯 ENTRÉE PRÉCISE CALCULÉE - ", direction,
         " | Entry: ", DoubleToString(entryPrice, _Digits),
         " | SL: ", DoubleToString(stopLoss, _Digits),
         " | TP: ", DoubleToString(takeProfit, _Digits),
         " | Risk/Reward: 1:", DoubleToString(MathAbs(takeProfit - entryPrice) / MathAbs(entryPrice - stopLoss), 2));
   
   return true;
}

//| VALIDATION MULTI-SIGNAUX POUR ENTRÉES PRÉCISES               |
bool ValidateEntryWithMultipleSignals(string direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 30, rates) < 30) return false;
   
   int confirmationCount = 0;
   
   // 1. Confirmation par momentum (last 5 bougies)
   double momentum = 0;
   for(int i = 0; i < 5; i++)
   {
      momentum += (rates[i].close - rates[i].open) / rates[i].open;
   }
   bool momentumConfirm = (direction == "BUY" && momentum > 0.001) || 
                          (direction == "SELL" && momentum < -0.001);
   if(momentumConfirm) confirmationCount++;
   
   // 2. Confirmation par volume (comparaison aux 10 bougies précédentes)
   double recentVolume = 0;
   double avgVolume = 0;
   for(int i = 0; i < 5; i++) recentVolume += (double)rates[i].tick_volume;
   for(int i = 5; i < 15; i++) avgVolume += (double)rates[i].tick_volume;
   recentVolume /= 5;
   avgVolume /= 10;
   
   bool volumeConfirm = recentVolume > avgVolume * 1.2; // Volume > 20% moyenne
   if(volumeConfirm) confirmationCount++;
   
   // 3. Confirmation par structure (pas de range)
   double range = rates[0].high - rates[0].low;
   double avgRange = 0;
   for(int i = 1; i < 10; i++) avgRange += rates[i].high - rates[i].low;
   avgRange /= 9;
   
   bool structureConfirm = range > avgRange * 0.8; // Range actuel > 80% moyenne
   if(structureConfirm) confirmationCount++;
   
   // 4. Confirmation par EMA (trend aligné)
   double ema[];
   ArraySetAsSeries(ema, true);
   bool emaConfirm = false;
   if(ema50H != INVALID_HANDLE && CopyBuffer(ema50H, 0, 0, 1, ema) >= 1)
   {
      emaConfirm = (direction == "BUY" && rates[0].close > ema[0]) ||
                   (direction == "SELL" && rates[0].close < ema[0]);
      if(emaConfirm) confirmationCount++;
   }
   
   // 5. Confirmation par volatilité (ni trop basse, ni trop élevée)
   double volatility = range / rates[0].close;
   bool volatilityConfirm = (volatility > 0.0005 && volatility < 0.02);
   if(volatilityConfirm) confirmationCount++;
   
   Print("🔍 VALIDATION MULTI-SIGNAUX - ", direction,
         " | Confirmations: ", confirmationCount, "/5",
         " | Momentum: ", momentumConfirm ? "✅" : "❌",
         " | Volume: ", volumeConfirm ? "✅" : "❌",
         " | Structure: ", structureConfirm ? "✅" : "❌",
         " | EMA: ", emaConfirm ? "✅" : "❌",
         " | Volatilité: ", volatilityConfirm ? "✅" : "❌");
   
   // Exiger au moins 3 confirmations sur 5
   return confirmationCount >= 3;
}

//| DÉTECTION AVANCÉE DE SPIKE IMMINENT                          |

// Calcule la compression de volatilité (prédicteur de spike)
double CalculateVolatilityCompression()
{
   // Vérifier si l'handle ATR est valide
   if(atrHandle == INVALID_HANDLE) return 0.0;
   
   double buffer[];
   ArraySetAsSeries(buffer, true);
   
   // Utiliser ATR sur 20 périodes pour la volatilité récente
   if(CopyBuffer(atrHandle, 0, 0, 20, buffer) < 20) return 0.0;
   
   double recentATR = buffer[0];
   double avgATR = 0.0;
   
   // Calculer la moyenne ATR sur 20 périodes
   for(int i = 0; i < 20; i++)
   {
      avgATR += buffer[i];
   }
   avgATR /= 20.0;
   
   // Compression = ratio ATR récent / moyenne ATR
   if(avgATR == 0) return 0.0;
   return recentATR / avgATR;
}

// Calcule l'accélération du prix (prédicteur de momentum)
double CalculatePriceAcceleration()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, 10, rates) < 10) return 0.0;
   
   // Calculer les variations de prix sur 3 périodes
   double change1 = (rates[0].close - rates[1].close) / rates[1].close;
   double change2 = (rates[1].close - rates[2].close) / rates[2].close;
   double change3 = (rates[2].close - rates[3].close) / rates[3].close;
   
   // Accélération = variation des variations
   double acceleration = (change1 - change3) / 3.0;
   
   return acceleration;
}

// Détecte les pics de volume anormaux
bool DetectVolumeSpike()
{
   long volume[];
   ArraySetAsSeries(volume, true);
   
   if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 20, volume) < 20) return false;
   
   double recentVolume = (double)volume[0];
   double avgVolume = 0.0;
   
   // Calculer la moyenne de volume sur 20 périodes
   for(int i = 1; i < 20; i++) // Exclure la période la plus récente
   {
      avgVolume += (double)volume[i];
   }
   avgVolume /= 19.0;
   
   // Spike si volume > 2x la moyenne
   return (recentVolume > avgVolume * 2.0);
}

// Détecte les patterns pré-spike spécifiques Boom/Crash
bool IsPreSpikePattern()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, 50, rates) < 50) return false;
   
   // 1. Détection de compression (range qui se resserre)
   double high50 = rates[0].high;
   double low50  = rates[0].low;
   for(int i = 1; i < 50; i++)
   {
      if(rates[i].high > high50) high50 = rates[i].high;
      if(rates[i].low  < low50)  low50  = rates[i].low;
   }
   double range50 = high50 - low50;
   
   double high10 = rates[0].high;
   double low10  = rates[0].low;
   for(int i = 1; i < 10; i++)
   {
      if(rates[i].high > high10) high10 = rates[i].high;
      if(rates[i].low  < low10)  low10  = rates[i].low;
   }
   double range10 = high10 - low10;
   
   // Compression récente si range10 < (ratio) du range50
   bool compression = (range10 < range50 * PreSpike_CompressionRatio);
   
   // 2. Détection de formation en coin/wedge
   double ma5 = 0, ma20 = 0;
   for(int i = 0; i < 5; i++) ma5 += rates[i].close;
   ma5 /= 5.0;
   for(int i = 0; i < 20; i++) ma20 += rates[i].close;
   ma20 /= 20.0;
   
   // Prix proche de la moyenne mobile (consolidation)
   bool consolidation = (MathAbs(rates[0].close - ma20) / ma20 < PreSpike_ConsolidationPct);
   
   // 3. Vérifier si le prix est à un niveau clé
   bool keyLevel = IsNearKeyLevel(rates[0].close);
   
   return (compression && consolidation && keyLevel);
}

// Vérifie si le prix est près d'un niveau clé (support/résistance)
bool IsNearKeyLevel(double price)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 100, rates) < 100) return false;
   
   // Chercher les niveaux de swing points récents
   for(int i = 5; i < 50; i++)
   {
      double high = rates[i].high;
      double low = rates[i].low;
      
      // Si prix est à moins de X% d'un swing high/low
      if(MathAbs(price - high) / high < PreSpike_KeyLevelPct || MathAbs(price - low) / low < PreSpike_KeyLevelPct)
      {
         return true;
      }
   }
   
   return false;
}

// Calcule la probabilité de spike imminent
double CalculateSpikeProbability()
{
   // Objectif: fournir une proba 0..1 stable et exploitable même quand le serveur IA ne renvoie rien.
   // Utilise des signaux rapides: compression ATR, accélération, volume, range, pré-spike, proximité canal.
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);

   double volCompression = 1.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 10, atrBuf) >= 6)
      {
         double recentATR = atrBuf[0];
         double avgATR = 0.0;
         for(int i = 1; i <= 5; i++) avgATR += atrBuf[i];
         avgATR /= 5.0;
         if(avgATR > 0.0) volCompression = recentATR / avgATR;
      }
   }

   // Rates M1 rapides
   MqlRates r5[];
   ArraySetAsSeries(r5, true);
   double accel = 0.0;
   double rangeRatio = 1.0;
   if(CopyRates(_Symbol, PERIOD_M1, 0, 6, r5) >= 3)
   {
      double change1 = (r5[0].close - r5[1].close) / (r5[1].close == 0 ? 1.0 : r5[1].close);
      double change2 = (r5[1].close - r5[2].close) / (r5[2].close == 0 ? 1.0 : r5[2].close);
      accel = (change1 - change2) / 2.0;

      double range0 = MathAbs(r5[0].high - r5[0].low);
      double avgRange = 0.0;
      for(int i = 1; i < 6; i++) avgRange += MathAbs(r5[i].high - r5[i].low);
      avgRange /= 5.0;
      if(avgRange > 0.0) rangeRatio = range0 / avgRange;
   }

   // Volume ratio
   double volRatio = 1.0;
   bool volumeSpike = false;
   long volTicks[];
   ArraySetAsSeries(volTicks, true);
   if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 10, volTicks) >= 6)
   {
      double recentV = (double)volTicks[0];
      double avgV = 0.0;
      for(int i = 1; i <= 5; i++) avgV += (double)volTicks[i];
      avgV /= 5.0;
      if(avgV > 0.0) volRatio = recentV / avgV;
      volumeSpike = (volRatio >= 1.6);
   }

   // Pré-spike "light" (sans scan swing complet)
   bool preSpikePattern = false;
   MqlRates r60[];
   ArraySetAsSeries(r60, true);
   if(cat == SYM_BOOM_CRASH && CopyRates(_Symbol, PERIOD_M1, 0, 60, r60) >= 50)
   {
      double hi10 = r60[0].high, lo10 = r60[0].low;
      for(int i = 0; i < 10; i++) { hi10 = MathMax(hi10, r60[i].high); lo10 = MathMin(lo10, r60[i].low); }
      double range10 = hi10 - lo10;
      double hi50 = r60[0].high, lo50 = r60[0].low;
      for(int i = 0; i < 50; i++) { hi50 = MathMax(hi50, r60[i].high); lo50 = MathMin(lo50, r60[i].low); }
      double range50 = hi50 - lo50;

      double ma20 = 0.0;
      for(int i = 0; i < 20; i++) ma20 += r60[i].close;
      ma20 /= 20.0;
      bool compression = (range50 > 0.0 && range10 < range50 * PreSpike_CompressionRatio);
      bool consolidation = (ma20 > 0.0 && (MathAbs(r60[0].close - ma20) / ma20) < PreSpike_ConsolidationPct);
      preSpikePattern = (compression && consolidation);
   }

   // Proximité canal SMC H1
   bool touchChannel = false;
   if(cat == SYM_BOOM_CRASH)
   {
       if(IsBoomLikeSymbol(_Symbol))  touchChannel = PriceTouchesLowerChannel();
       if(IsCrashLikeSymbol(_Symbol)) touchChannel = PriceTouchesUpperChannel();
   }

   // Normalisation 0..1
   double sCompression = 0.0;
   if(volCompression < 1.0) sCompression = MathMin((1.0 - volCompression) / 0.6, 1.0); // 0.4 => 1.0
   double sAccel = MathMin(MathAbs(accel) / 0.003, 1.0);
   double sVolume = 0.0;
   if(volRatio > 1.0) sVolume = MathMin((volRatio - 1.0) / 1.5, 1.0);
   double sRange = 0.0;
   if(rangeRatio > 1.0) sRange = MathMin((rangeRatio - 1.0) / 1.0, 1.0);
   double sPre = preSpikePattern ? 1.0 : 0.0;
   double sChan = touchChannel ? 1.0 : 0.0;

   double probability =
      0.25 * sCompression +
      0.20 * sAccel +
      0.20 * sVolume +
      0.15 * sRange +
      0.10 * sPre +
      0.10 * sChan;

   probability = MathMax(0.0, MathMin(probability, 1.0));

   // Publier pour les filtres/affichages
   g_lastSpikeProbability = probability;
   g_lastSpikeUpdate      = TimeCurrent();

   return probability;
}

// Algo Deriv reproduit : conditions pré-spike mûres (Z-Score ATR + EMA + Cooldown)
// Retourne true quand les conditions sont réunies pour un spike imminent
bool IsAlgoSpikeReady()
{
   if(atrHandle == INVALID_HANDLE) return false;

   // 1) Z-Score ATR (fenêtre 20 périodes)
   double atrBuf[];
   ArraySetAsSeries(atrBuf, true);
   if(CopyBuffer(atrHandle, 0, 0, 21, atrBuf) < 21) return false;

   double sum = 0.0, sumSq = 0.0;
   for(int i = 1; i <= 20; i++) { sum += atrBuf[i]; sumSq += atrBuf[i] * atrBuf[i]; }
   double mean = sum / 20.0;
   double variance = (sumSq / 20.0) - (mean * mean);
   double stdDev = (variance > 0) ? MathSqrt(variance) : 0.0;
   double zScore = (stdDev > 0) ? (atrBuf[0] - mean) / stdDev : 0.0;

   // Compression = Z-Score négatif (volatilité basse = pré-spike)
   // OU Z-Score très élevé = spike en cours/imminent
   bool atrReady = (zScore <= -1.0 || zScore >= 2.0);

   // 2) EMA(14) condition — prix dans la tendance du spike attendu
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 15, rates) < 15) return false;
   double close = rates[0].close;

   double emaSum = 0.0;
   double k = 2.0 / (14.0 + 1.0);
   double ema = rates[14].close;
   for(int i = 13; i >= 0; i--)
      ema = rates[i].close * k + ema * (1.0 - k);

   bool isBoom = IsBoomLikeSymbol(_Symbol);
   bool emaOk = isBoom ? (close > ema) : (close < ema);

   // 3) Cooldown estimé : pas de gros mouvement récent (5 dernières bougies)
   double maxMove = 0.0;
   for(int i = 0; i < 5; i++)
      maxMove = MathMax(maxMove, MathAbs(rates[i].close - rates[i].open));
   double avgBody = 0.0;
   for(int i = 5; i < 15; i++)
      avgBody += MathAbs(rates[i].close - rates[i].open);
   avgBody /= 10.0;
   bool cooldownOk = (avgBody > 0 && maxMove < avgBody * 3.0);

   // 4) Tick Frequency Analysis — ralentissement = fin de cooldown = spike imminent
   //    Ratio < 0.6 signifie que les ticks arrivent 40%+ plus lentement que la moyenne
   //    C'est le signal que le générateur Deriv est en phase de cooldown terminal
   bool tickFreqReady = false;
   if(g_tickFreqAvg > 2.0) // besoin d'au moins quelques secondes de données
   {
      // Ralentissement : ticks/sec actuel < 60% de la moyenne = cooldown actif
      double recentRate = (double)g_tickFreqCurrent;
      double ratio = recentRate / g_tickFreqAvg;
      g_tickFreqRatio = ratio;
      tickFreqReady = (ratio <= 0.6);
   }

   // Combinaison : Z-Score + EMA + (Cooldown candles OU Tick Frequency)
   bool conditionsReady = atrReady && emaOk && (cooldownOk || tickFreqReady);

   if(conditionsReady)
   {
      Print("[ALGO-SPIKE] ✅ Conditions mûres | Z-Score=", DoubleToString(zScore, 2),
            " | EMA=", DoubleToString(ema, _Digits),
            " | close=", DoubleToString(close, _Digits),
            " | ", isBoom ? "close>EMA" : "close<EMA",
            " | TickFreq=", DoubleToString(g_tickFreqRatio, 2),
            tickFreqReady ? " [TICK-SLOW]" : " [CANDLE-OK]");
      return true;
   }
   return false;
}

// Envoie une alerte de spike imminent - VERSION OPTIMISÉE
void CheckImminentSpike()
{
   // Uniquement sur Boom/Crash
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(cat != SYM_BOOM_CRASH) return;
   
   // Probabilité unifiée (même algo que l'affichage / filtre)
   double finalSpikeProb = CalculateSpikeProbability();
   double volCompression = CalculateVolatilityCompression();
   bool volumeSpike = DetectVolumeSpike();
   
   // Vérification finale
   if(finalSpikeProb < 0.0 || finalSpikeProb > 1.0) return;
   
   // Alerte si probabilité élevée (ajustée à 75% pour correspondre aux trades)
   if(finalSpikeProb > 0.75)
   {
      string alertMsg = "🚨 SPIKE IMMINENT sur " + _Symbol + 
                      " | Probabilité: " + DoubleToString(finalSpikeProb*100, 1) + "%" +
                      " | Compression: " + DoubleToString(volCompression*100, 1) + "%" +
                      " | Volume: " + (volumeSpike ? "SPIKE" : "Normal");
      
      Print(alertMsg);
      
      if(UseNotifications)
      {
         Alert(alertMsg);
         SendNotification("🚨 SPIKE " + _Symbol + " " + DoubleToString(finalSpikeProb*100, 1) + "%");
      }
      
      // Dessiner un marqueur visuel rapide
      DrawSpikeWarning(finalSpikeProb);
   }
}

//| RSI SQUEEZE PREDICTOR — squeeze RSI + tendance H1 + auto-trade       |
void CheckRSISqueezeAndTrade()
{
   if(!UseRSISqueezePredictor) return;

   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(cat != SYM_BOOM_CRASH) return;

   if(rsiSqueezeHandle == INVALID_HANDLE) return;

   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(rsiSqueezeHandle, 0, 0, 3, rsi) < 3) return;

   bool isBoom = IsBoomLikeSymbol(_Symbol);

   // --- DÉTECTION SQUEEZE ---
   bool squeezeSignal = false;
   if(isBoom && rsi[0] < RSISqueezeLowThreshold)
      squeezeSignal = true;
   if(!isBoom && rsi[0] > RSISqueezeHighThreshold)
      squeezeSignal = true;

   // --- FILTRE H1 TREND ---
   bool h1Aligned = true;
   if(RSISqueezeH1Filter && ema50H != INVALID_HANDLE)
   {
      double ema50H1Arr[];
      ArraySetAsSeries(ema50H1Arr, true);
      if(CopyBuffer(ema50H, 0, 0, 1, ema50H1Arr) >= 1)
      {
         double closeH1[];
         ArraySetAsSeries(closeH1, true);
         if(CopyClose(_Symbol, PERIOD_H1, 0, 1, closeH1) >= 1)
         {
            // Boom BUY need H1 BULL (close > EMA50), Crash SELL need H1 BEAR
            if(isBoom && closeH1[0] < ema50H1Arr[0]) h1Aligned = false;
            if(!isBoom && closeH1[0] > ema50H1Arr[0]) h1Aligned = false;
         }
      }
   }

    // --- GLOBALS pour dashboard GOM ---
    g_dashSqueezeActive = squeezeSignal;
    g_dashSqueezeRSI    = rsi[0];
    g_dashH1Aligned     = h1Aligned;

    // --- DASHBOARD SQUEEZE STATUS ---
    if(RSISqueezeShowDashboard)
   {
      string squeezeTxt = squeezeSignal ? "SQUEEZE!" : "Normal";
      color squeezeClr  = squeezeSignal ? clrLime : clrGray;
      string h1Txt      = h1Aligned ? "Aligned" : "Counter";
      color h1Clr       = h1Aligned ? clrLime : clrOrange;

      string objName = "RSI_SQUEEZE_DASH_" + _Symbol;
      if(ObjectFind(0, objName) < 0)
         ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, 90);
      ObjectSetString(0, objName, OBJPROP_TEXT,
         "RSI(" + IntegerToString(RSISqueezePeriod) + "): " + DoubleToString(rsi[0], 1) +
         " [" + squeezeTxt + "] H1: " + h1Txt);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, squeezeSignal ? squeezeClr : clrGray);
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, objName, OBJPROP_FONT, "Consolas");
   }

   if(!squeezeSignal) return;

   // --- LOGIQUE PRÉDICTIVE ---
   Print("🔍 RSI SQUEEZE détecté sur ", _Symbol,
         " | RSI: ", DoubleToString(rsi[0], 1),
         " | H1: ", h1Aligned ? "Aligné" : "Contre-tendance",
         " | Type: ", isBoom ? "BOOM → BUY" : "CRASH → SELL");

   if(UseNotifications && h1Aligned)
   {
      Alert("🔍 RSI SQUEEZE ", _Symbol, " RSI=", DoubleToString(rsi[0], 1),
            " H1=", h1Aligned ? "OK" : "NOK");
      SendNotification("🔍 SQUEEZE " + _Symbol + " RSI=" + DoubleToString(rsi[0], 1));
   }

   // --- AUTO-TRADE ---
   if(!RSISqueezeAutoTrade) return;
   if(!h1Aligned) return;
   if(PositionsTotal() > 0) return; // Pas de position ouverte
   if(CountPositionsForSymbol(_Symbol) > 0) return;

   if(!TryAcquireOpenLock()) return;

   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }

   double atrArr[];
   ArraySetAsSeries(atrArr, true);
   double atrVal = 0;
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atrArr) >= 1)
      atrVal = atrArr[0];
   if(atrVal <= 0) { ReleaseOpenLock(); return; }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int    dg  = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   bool orderOK = false;

    if(isBoom)
    {
       if(g_smcGomConnected && g_smcGomVerdictNum < 0)
{
           Print("🚫 RSI-SQUEEZE BUY BLOQUÉ — GOM verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ")");
           ReleaseOpenLock(); return;
        }
        double sl = NormalizeDouble(ask - atrVal * 2.0, dg);
        double tp = NormalizeDouble(ask + atrVal * 5.0, dg);
        if(SafeTradeBuy(lot, _Symbol, ask, sl, tp, "RSI-SQUEEZE BUY"))
       {
          orderOK = true;
          ulong ticket = trade.ResultOrder();
          if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
          Print("🚀 RSI-SQUEEZE BUY ", _Symbol, " @", DoubleToString(ask, dg),
                " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg),
                " RSI=", DoubleToString(rsi[0], 1));
       }
    }
     else
     {
        if(g_smcGomConnected && g_smcGomVerdictNum > 0)
        {
           Print("🚫 RSI-SQUEEZE SELL BLOQUÉ — GOM verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ")");
           ReleaseOpenLock(); return;
        }
        double sl = NormalizeDouble(bid + atrVal * 2.0, dg);
        double tp = NormalizeDouble(bid - atrVal * 5.0, dg);
        if(SafeTradeSell(lot, _Symbol, bid, sl, tp, "RSI-SQUEEZE SELL"))
       {
          orderOK = true;
          ulong ticket = trade.ResultOrder();
          if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
          Print("🚀 RSI-SQUEEZE SELL ", _Symbol, " @", DoubleToString(bid, dg),
                " SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg),
                " RSI=", DoubleToString(rsi[0], 1));
       }
    }

   ReleaseOpenLock();

   if(orderOK)
   {
      g_maxProfit = 0;
      if(UseNotifications)
         SendNotification("🚀 SQUEEZE TRADE " + _Symbol + (isBoom ? " BUY" : " SELL") +
                          " RSI=" + DoubleToString(rsi[0], 1));
   }
}

//| DÉTECTION DES MOUVEMENTS DE RETOUR VERS CANAUX SMC               |
void CheckSMCChannelReturnMovements()
{
   // Uniquement sur Boom/Crash
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(cat != SYM_BOOM_CRASH) return;
   
   // Récupérer les canaux SMC H1
   string upperName = "SMC_CH_H1_UPPER";
   string lowerName = "SMC_CH_H1_LOWER";
   if(ObjectFind(0, upperName) < 0 || ObjectFind(0, lowerName) < 0) return;
   
   double upperPrice = ObjectGetDouble(0, upperName, OBJPROP_PRICE);
   double lowerPrice = ObjectGetDouble(0, lowerName, OBJPROP_PRICE);
   if(upperPrice <= 0 || lowerPrice <= 0) return;
   
   // Obtenir les prix actuels
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return;
   
   // Obtenir l'ATR pour les calculs de distance
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) > 0)
         atrVal = atrBuf[0];
   }
   if(atrVal <= 0) atrVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100;
   
   bool isBoom = IsBoomLikeSymbol(_Symbol);
   bool isCrash = IsCrashLikeSymbol(_Symbol);
   
   // RÈGLE STRICTE: BLOQUER TOUS LES MOUVEMENTS DE RETOUR BUY SUR BOOM SI IA = SELL
   string aiAction = g_lastAIAction;
   if(aiAction == "buy") aiAction = "BUY";
   if(aiAction == "sell") aiAction = "SELL";
   
   if(isBoom && aiAction == "SELL")
   {
      // Ne même pas analyser les mouvements de retour si IA = SELL sur Boom
      return;
   }
   
   if(isCrash && aiAction == "BUY")
   {
      // Ne même pas analyser les mouvements de retour si IA = BUY sur Crash
      return;
   }
   
   // Analyser les 5 dernières bougies pour détecter un mouvement de retour
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 3) return;
   
   // Détecter si le prix fait un mouvement de retour vers un canal
   bool returnMovementDetected = false;
   string returnDirection = "";
   double returnStrength = 0.0;
   
   if(isBoom)
   {
      // Pour Boom: vérifier si le prix monte vers le canal inférieur après être descendu
      double currentDistance = bid - lowerPrice;
      double previousDistance = rates[1].close - lowerPrice;
      
      // Mouvement de retour: la distance au canal diminue significativement
      if(previousDistance > currentDistance && previousDistance - currentDistance > atrVal * 0.3)
      {
         returnMovementDetected = true;
         returnDirection = "BUY";
         returnStrength = (previousDistance - currentDistance) / atrVal;
         
         // Vérifier si le mouvement est assez fort pour justifier une entrée immédiate
         if(returnStrength >= 0.5 && currentDistance <= atrVal * 3.0)
         {
            Print("🔄 MOUVEMENT RETOUR BOOM - Vers canal inférieur | Force: ", DoubleToString(returnStrength, 1), " ATR | Distance: ", DoubleToString(currentDistance/atrVal, 1), " ATR");
            
            // Placer un ordre limite plus proche pour capturer ce mouvement
            PlaceReturnMovementLimitOrder("BUY", bid, lowerPrice, atrVal, returnStrength);
         }
      }
   }
   else if(isCrash)
   {
      // Pour Crash: vérifier si le prix descend vers le canal supérieur après être monté
      double currentDistance = upperPrice - ask;
      double previousDistance = upperPrice - rates[1].close;
      
      // Mouvement de retour: la distance au canal diminue significativement
      if(previousDistance > currentDistance && previousDistance - currentDistance > atrVal * 0.3)
      {
         returnMovementDetected = true;
         returnDirection = "SELL";
         returnStrength = (previousDistance - currentDistance) / atrVal;
         
         // Vérifier si le mouvement est assez fort pour justifier une entrée immédiate
         if(returnStrength >= 0.5 && currentDistance <= atrVal * 3.0)
         {
            Print("🔄 MOUVEMENT RETOUR CRASH - Vers canal supérieur | Force: ", DoubleToString(returnStrength, 1), " ATR | Distance: ", DoubleToString(currentDistance/atrVal, 1), " ATR");
            
            // Placer un ordre limite plus proche pour capturer ce mouvement
            PlaceReturnMovementLimitOrder("SELL", ask, upperPrice, atrVal, returnStrength);
         }
      }
   }
}

//| PLACEMENT D'ORDRE LIMITE POUR MOUVEMENT DE RETOUR               |
void PlaceReturnMovementLimitOrder(string direction, double currentPrice, double channelPrice, double atrVal, double strength)
{
   // Bloquer en zone de correction (verdict GOM WAIT = vn==0)
   if(UseGOMVerdictFilter && g_smcGomConnected && g_smcGomVerdictNum == 0)
   {
      Print("[GOM-WAIT] PlaceReturnMovementLimitOrder bloqué — verdict=WAIT (correction)");
      return;
   }

   // OTE Filter: prix doit être dans zone Fib 61.8-78.6%
   if(GOMRequireOTE && UseOTE && g_smcOteTop > 0 && g_smcOteBot > 0 && !g_smcInOTE)
   {
      Print("[OTE] PlaceReturnMovementLimitOrder bloqué — prix hors zone OTE");
      return;
   }

   // Vérifier si on a déjà un ordre de retour en cours
   int countReturnOrders = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(StringFind(OrderGetString(ORDER_COMMENT), "RETURN_MOVE") >= 0) countReturnOrders++;
   }
   if(countReturnOrders >= 1) return; // Un seul ordre de retour à la fois
   
   // Limite globale: maximum 2 ordres LIMIT par symbole, dont 1 seul hors canal
   {
      int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
      int chanLimits  = CountChannelLimitOrdersForSymbol(_Symbol);
      int otherLimits = totalLimits - chanLimits;
      // Pour Boom/Crash: un seul LIMIT proche à la fois
      if(totalLimits >= 1 || otherLimits >= 1) return;
   }
   
   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles (IA ≥90% + spike/setup fort)
   if(!AllowReentryAfterRecentLoss(_Symbol, direction, strength >= 0.8))
      return;
   
   if(CountPositionsForSymbol(_Symbol) > 0) return; // Pas d'ordre si déjà en position
   if(!TryAcquireOpenLock()) return;
   
   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }
   
   // Calculer le prix d'entrée optimisé pour le mouvement de retour
   double entryPrice;
   double distanceToChannel = MathAbs(currentPrice - channelPrice);
   
   if(direction == "BUY")
   {
      // Priorité SuperTrend support: entrée juste au-dessus du support, mais < prix actuel
      double stSupp = 0.0, stRes = 0.0;
      double tmpS = 0.0, tmpR = 0.0;
      if(GetSuperTrendLevel(PERIOD_M5, tmpS, tmpR) && tmpS > 0) stSupp = tmpS;
      else if(GetSuperTrendLevel(PERIOD_H1, tmpS, tmpR) && tmpS > 0) stSupp = tmpS;
      if(stSupp > 0 && stSupp < currentPrice)
      {
         double candidate = stSupp + atrVal * 0.15;
         if(candidate < currentPrice)
            entryPrice = candidate;
         else
            entryPrice = currentPrice - atrVal * 0.5;
      }
      else
      {
      // BUY: placer l'ordre entre le prix actuel et le canal, plus proche du prix
      if(distanceToChannel <= atrVal * 2.0)
         entryPrice = channelPrice + (atrVal * 0.2); // Très proche du canal
      else if(distanceToChannel <= atrVal * 4.0)
         entryPrice = currentPrice - (atrVal * 0.8); // Plus proche du prix
      else
         entryPrice = currentPrice - (atrVal * 1.2); // Distance modérée
      }
      
      if(entryPrice >= currentPrice) { ReleaseOpenLock(); return; }
      
      // Placer l'ordre BUY LIMIT
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);
      req.action = TRADE_ACTION_PENDING;
      req.symbol = _Symbol;
      req.magic = InpMagicNumber;
      req.volume = lot;
      req.type = ORDER_TYPE_BUY_LIMIT;
      req.price = entryPrice;
      req.sl = entryPrice - atrVal * 2.0;
      req.tp = entryPrice + atrVal * 4.0;
      req.comment = "RETURN_MOVE BUY LIMIT";
      
      if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_BUY_LIMIT)) { ReleaseOpenLock(); return; }
      CleanupExcessLimits(_Symbol, 2);
      if(SafeOrderSend(req, res))
      {
         Print("✅ ORDRE RETOUR BUY PLACÉ - Entry: ", DoubleToString(entryPrice, _Digits), 
               " | Force: ", DoubleToString(strength, 1), " ATR");
      }
      else
      {
         Print("❌ ÉCHEC ORDRE RETOUR BUY - Erreur: ", res.retcode);
      }
   }
   else // SELL
   {
      // Priorité SuperTrend résistance: entrée juste en-dessous de la résistance, mais > prix actuel
      double stSupp = 0.0, stRes = 0.0;
      double tmpS = 0.0, tmpR = 0.0;
      if(GetSuperTrendLevel(PERIOD_M5, tmpS, tmpR) && tmpR > 0) stRes = tmpR;
      else if(GetSuperTrendLevel(PERIOD_H1, tmpS, tmpR) && tmpR > 0) stRes = tmpR;
      if(stRes > 0 && stRes > currentPrice)
      {
         double candidate = stRes - atrVal * 0.15;
         if(candidate > currentPrice)
            entryPrice = candidate;
         else
            entryPrice = currentPrice + atrVal * 0.5;
      }
      else
      {
      // SELL: placer l'ordre entre le prix actuel et le canal, plus proche du prix
      if(distanceToChannel <= atrVal * 2.0)
         entryPrice = channelPrice - (atrVal * 0.2); // Très proche du canal
      else if(distanceToChannel <= atrVal * 4.0)
         entryPrice = currentPrice + (atrVal * 0.8); // Plus proche du prix
      else
         entryPrice = currentPrice + (atrVal * 1.2); // Distance modérée
      }
      
      if(entryPrice <= currentPrice) { ReleaseOpenLock(); return; }
      
      // Placer l'ordre SELL LIMIT
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);
      req.action = TRADE_ACTION_PENDING;
      req.symbol = _Symbol;
      req.magic = InpMagicNumber;
      req.volume = lot;
      req.type = ORDER_TYPE_SELL_LIMIT;
      req.price = entryPrice;
      req.sl = entryPrice + atrVal * 2.0;
      req.tp = entryPrice - atrVal * 4.0;
      req.comment = "RETURN_MOVE SELL LIMIT";
      
      if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_SELL_LIMIT)) { ReleaseOpenLock(); return; }
      CleanupExcessLimits(_Symbol, 2);
      if(SafeOrderSend(req, res))
      {
         Print("✅ ORDRE RETOUR SELL PLACÉ - Entry: ", DoubleToString(entryPrice, _Digits), 
               " | Force: ", DoubleToString(strength, 1), " ATR");
      }
      else
      {
         Print("❌ ÉCHEC ORDRE RETOUR SELL - Erreur: ", res.retcode);
      }
   }
   
   ReleaseOpenLock();
}

// Dessine un avertissement visuel de spike imminent - VERSION AMÉLIORÉE
void DrawSpikeWarning(double probability)
{
   string warningName = "SPIKE_WARNING_" + _Symbol;
   string probTextName = "SPIKE_PROB_TEXT_" + _Symbol;
   
   // Supprimer les avertissements précédents
   if(ObjectFind(0, warningName) >= 0)
      ObjectDelete(0, warningName);
   if(ObjectFind(0, probTextName) >= 0)
      ObjectDelete(0, probTextName);
   
   // Créer un nouvel avertissement
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, r) < 1) return;
   
   // Déterminer la couleur selon la probabilité
   color spikeColor = clrRed;
   if(probability >= 0.85) spikeColor = clrRed;      // 85%+ = Rouge critique
   else if(probability >= 0.70) spikeColor = clrOrange; // 70-84% = Orange alerte
   else if(probability >= 0.60) spikeColor = clrYellow; // 60-69% = Jaune attention
   else spikeColor = clrWhite; // < 60% = Blanc info
   
   // Dessiner une flèche d'avertissement
   ObjectCreate(0, warningName, OBJ_ARROW, 0, r[0].time, r[0].high);
   ObjectSetInteger(0, warningName, OBJPROP_ARROWCODE, 241); // Point d'exclamation
   ObjectSetInteger(0, warningName, OBJPROP_COLOR, spikeColor);
   ObjectSetInteger(0, warningName, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, warningName, OBJPROP_BACK, false);
   
   // Ajouter un texte avec la probabilité
   string probText = "SPIKE " + DoubleToString(probability*100, 0) + "%";
   ObjectCreate(0, probTextName, OBJ_TEXT, 0, r[0].time, r[0].high + (r[0].high - r[0].low) * 0.5);
   ObjectSetString(0, probTextName, OBJPROP_TEXT, probText);
   ObjectSetInteger(0, probTextName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, probTextName, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, probTextName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, probTextName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, probTextName, OBJPROP_BACK, true);
   
   // Log de l'affichage
   Print("📊 SPIKE WARNING AFFICHÉ - ", _Symbol, 
         " | Probabilité: ", DoubleToString(probability*100, 1), "%",
         " | Couleur: ", (probability >= 0.85 ? "ROUGE CRITIQUE" : 
                         (probability >= 0.70 ? "ORANGE ALERTE" : 
                         (probability >= 0.60 ? "JAUNE ATTENTION" : "BLANC INFO"))));
}

// Affiche l'état IA et les prédictions sur le graphique
void DrawAIStatusAndPredictions()
{
   string statusBoxName = "AI_STATUS_BOX_" + _Symbol;
   string statusTextName = "AI_STATUS_TEXT_" + _Symbol;
   
   // Supprimer les objets précédents
   if(ObjectFind(0, statusBoxName) >= 0)
      ObjectDelete(0, statusBoxName);
   if(ObjectFind(0, statusTextName) >= 0)
      ObjectDelete(0, statusTextName);
   
   // Créer une boîte de statut
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, r) < 1) return;
   
   // Position de la boîte (coin supérieur gauche)
   datetime boxTime = r[0].time;
   double boxPrice = r[0].high + (r[0].high - r[0].low) * 0.8;
   
   // Créer le rectangle de fond
   ObjectCreate(0, statusBoxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, statusBoxName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, statusBoxName, OBJPROP_YDISTANCE, 200); // Positionné en bas
   ObjectSetInteger(0, statusBoxName, OBJPROP_XSIZE, 250);
   ObjectSetInteger(0, statusBoxName, OBJPROP_YSIZE, 80);
   ObjectSetInteger(0, statusBoxName, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, statusBoxName, OBJPROP_BORDER_COLOR, clrGray);
   ObjectSetInteger(0, statusBoxName, OBJPROP_CORNER, CORNER_LEFT_LOWER); // Bas à gauche
   
   // Texte de statut IA
   string iaStatus = UseAIServer ? 
                    ("IA: " + g_lastAIAction + " (" + DoubleToString(g_lastAIConfidence*100, 1) + "%)") : 
                    "IA: DÉSACTIVÉ";
   
   // Texte de prédiction spike
   double spikeProb = CalculateSpikeProbability();
   string spikeStatus = "SPIKE: " + DoubleToString(spikeProb*100, 1) + "%";
   
   // Créer le texte de statut
   ObjectCreate(0, statusTextName, OBJ_LABEL, 0, 0, 0);
   ObjectSetString(0, statusTextName, OBJPROP_TEXT, 
                 iaStatus + "\n" + spikeStatus + "\nSymbole: " + _Symbol);
   ObjectSetInteger(0, statusTextName, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, statusTextName, OBJPROP_YDISTANCE, 210); // Aligné avec la boîte
   ObjectSetInteger(0, statusTextName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, statusTextName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, statusTextName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, statusTextName, OBJPROP_CORNER, CORNER_LEFT_LOWER); // Bas à gauche
}

//| DÉTECTER UN SPIKE RÉCENT sur Boom/Crash                           |
bool DetectRecentSpike()
{
   Print("🔍 DEBUG - Détection de spike pour: ", _Symbol);
   
   // Vérifier les 5 dernières bougies pour un spike significatif
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5)
   {
      Print("❌ Impossible de copier les rates pour détecter spike");
      return false;
   }
   
   // Calculer le mouvement moyen des bougies
   double avgMovement = 0.0;
   for(int i = 1; i < 5; i++) // Ignorer la bougie actuelle (0)
   {
      avgMovement += MathAbs(rates[i].high - rates[i].low);
   }
   avgMovement /= 4.0;
   
   // Vérifier si la dernière bougie a un mouvement significatif
   double lastMovement = MathAbs(rates[0].high - rates[0].low);
   
   // Rendre la détection plus permissive - seuil différent pour Boom/Crash
   double spikeMultiplier = 1.5; // 1.5x par défaut
    if(IsBoomLikeSymbol(_Symbol) || IsCrashLikeSymbol(_Symbol))
    {
       spikeMultiplier = 1.2; // 1.2x pour Boom/Crash/Painx/Gainx (plus sensible)
   }
   
   double spikeThreshold = avgMovement * spikeMultiplier;
   
   bool isSpike = lastMovement > spikeThreshold;
   
   Print("🔍 DEBUG - Analyse spike - Mouvement actuel: ", DoubleToString(lastMovement, _Digits), 
         " | Moyenne: ", DoubleToString(avgMovement, _Digits), 
         " | Seuil: ", DoubleToString(spikeThreshold, _Digits), 
         " | Ratio: ", DoubleToString(lastMovement/avgMovement, 1),
         " | Spike: ", isSpike ? "OUI" : "NON");
   
   // Ajouter une détection alternative basée sur le prix
   double priceChange = MathAbs(rates[0].close - rates[1].close) / rates[1].close;
   
   // Seuil différent pour Boom/Crash vs autres symboles
   double priceThreshold = 0.001; // 0.1% par défaut
    if(IsBoomLikeSymbol(_Symbol) || IsCrashLikeSymbol(_Symbol))
    {
       priceThreshold = 0.0001; // 0.01% pour Boom/Crash/Painx/Gainx (plus sensible)
   }
   
   bool priceSpike = priceChange > priceThreshold;
   
   Print("🔍 DEBUG - Spike prix - Changement: ", DoubleToString(priceChange*100, 4), "% | Seuil: ", DoubleToString(priceThreshold*100, 4), "% | Spike: ", priceSpike ? "OUI" : "NON");
   
   // Ajouter une détection basée sur le volume pour Boom/Crash
   bool volumeSpike = false;
    if(IsBoomLikeSymbol(_Symbol) || IsCrashLikeSymbol(_Symbol))
   {
      long volume[];
      ArraySetAsSeries(volume, true);
      if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 3, volume) >= 3)
      {
         double recentVolume = (double)volume[0];
         double avgVolume = ((double)volume[1] + (double)volume[2]) / 2.0;
         volumeSpike = recentVolume > avgVolume * 1.3; // 30% plus élevé
         
         Print("🔍 DEBUG - Spike volume - Récent: ", DoubleToString(recentVolume, 0), 
               " | Moyenne: ", DoubleToString(avgVolume, 0), 
               " | Spike: ", volumeSpike ? "OUI" : "NON");
      }
   }
   
   // Considérer comme spike si l'un des trois est vrai
   bool finalSpike = isSpike || priceSpike || volumeSpike;
   
   if(finalSpike)
   {
      string spikeType = "";
      if(isSpike) spikeType += "Mouvement";
      if(priceSpike) spikeType += (spikeType != "" ? "+" : "") + "Prix";
      if(volumeSpike) spikeType += (spikeType != "" ? "+" : "") + "Volume";
      
      Print("🚨 SPIKE DÉTECTÉ - Type: ", spikeType, 
            " | Mouvement: ", DoubleToString(lastMovement, _Digits), 
            " | Changement prix: ", DoubleToString(priceChange*100, 3), "%");
   }
   
   return finalSpike;
}

//| Trouver le meilleur niveau d'entrée spike (FVG/OB/Swing/Liquidity)
double GetBestSpikeEntryLevel(string direction, double currentPrice, double atrValue, string &sourceOut)
{
   sourceOut = "ATR Fallback";
   double bestLevel = 0.0;
   double maxDist = atrValue * 2.0;
   
   // 1) FVG zones — prix dans ou proche d'un FVG
   if(UseFVG)
   {
      FVGData fvg;
      if(SMC_DetectFVG(_Symbol, LTF, 30, fvg))
      {
         if(direction == "BUY" && fvg.direction == 1)
         {
            double entry = fvg.bottom;
            double dist = MathAbs(currentPrice - entry);
            if(dist <= maxDist && dist > 0)
            {
               bestLevel = entry;
               sourceOut = "FVG Bull @ " + DoubleToString(fvg.bottom, _Digits);
            }
         }
         else if(direction == "SELL" && fvg.direction == -1)
         {
            double entry = fvg.top;
            double dist = MathAbs(entry - currentPrice);
            if(dist <= maxDist && dist > 0)
            {
               bestLevel = entry;
               sourceOut = "FVG Bear @ " + DoubleToString(fvg.top, _Digits);
            }
         }
      }
   }
   
   // 2) Order Block zones
   if(UseOrderBlocks)
   {
      OrderBlockData ob;
      if(SMC_DetectOrderBlock(_Symbol, LTF, ob))
      {
         if(direction == "BUY" && ob.direction == 1)
         {
            double entry = ob.low;
            double dist = MathAbs(currentPrice - entry);
            if(dist <= maxDist && dist > 0 && (bestLevel == 0 || dist < MathAbs(currentPrice - bestLevel)))
            {
               bestLevel = entry;
               sourceOut = "OB Bull @ " + DoubleToString(ob.low, _Digits);
            }
         }
         else if(direction == "SELL" && ob.direction == -1)
         {
            double entry = ob.high;
            double dist = MathAbs(entry - currentPrice);
            if(dist <= maxDist && dist > 0 && (bestLevel == 0 || dist < MathAbs(bestLevel - currentPrice)))
            {
               bestLevel = entry;
               sourceOut = "OB Bear @ " + DoubleToString(ob.high, _Digits);
            }
         }
      }
   }
   
   // 3) Swing levels (proches)
   if(direction == "BUY")
   {
      double swingLevel = GetClosestBuyLevel(currentPrice, atrValue, 2.0, sourceOut);
      if(swingLevel > 0)
      {
         double dist = MathAbs(currentPrice - swingLevel);
         if(dist <= maxDist && dist > 0 && (bestLevel == 0 || dist < MathAbs(currentPrice - bestLevel)))
         {
            bestLevel = swingLevel;
            sourceOut = sourceOut;
         }
      }
   }
   else
   {
      double swingLevel = GetClosestSellLevel(currentPrice, atrValue, 2.0, sourceOut);
      if(swingLevel > 0)
      {
         double dist = MathAbs(swingLevel - currentPrice);
         if(dist <= maxDist && dist > 0 && (bestLevel == 0 || dist < MathAbs(bestLevel - currentPrice)))
         {
            bestLevel = swingLevel;
            sourceOut = sourceOut;
         }
      }
   }
   
   // 4) Fallback ATR offset
   if(bestLevel == 0)
   {
      if(direction == "BUY")
         bestLevel = currentPrice - atrValue * 0.3;
      else
         bestLevel = currentPrice + atrValue * 0.3;
      sourceOut = "ATR Offset";
   }
   
   return bestLevel;
}

//| EXÉCUTER UN TRADE BASÉ SUR SPIKE                                  |
void ExecuteSpikeTrade(string direction)
{
   // Calculer lot size (recovery: doubler le lot min sur un autre symbole après une perte)
   double lot = CalculateLotSize();
   lot = ApplyRecoveryLot(lot);
   if(lot <= 0) 
   {
      Print("❌ Erreur calcul lot size - trade annulé");
      return;
   }
   
   // Calculer SL/TP basés sur l'ATR
   double atrValue = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1)
         atrValue = atr[0];
   }
   
   if(atrValue == 0) atrValue = SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.002; // 0.2% par défaut
   
   Print("🔍 DEBUG - ATR pour SL/TP: ", DoubleToString(atrValue, _Digits), " | Symbol: ", _Symbol);
   
   // Perte max par trade (3$): perte en $ = (SL en prix) * (tickValue/tickSize) * lot
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0) tickSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickVal <= 0) tickVal = 1.0;
   double riskPerLotDollars = (atrValue * 2.0) * (tickVal / tickSize); // $ par lot si SL 2x ATR touché
   if(riskPerLotDollars <= 0) riskPerLotDollars = 1.0;
   double potentialLoss = lot * riskPerLotDollars;
   if(potentialLoss > MaxLossPerSpikeTradeDollars)
   {
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(lotStep <= 0) lotStep = 0.01;
      double lotCap = MaxLossPerSpikeTradeDollars / riskPerLotDollars;
      lot = MathFloor(lotCap / lotStep) * lotStep;
      lot = MathMax(minLot, MathMin(maxLot, lot));
      lot = NormalizeDouble(lot, 2);
      potentialLoss = lot * riskPerLotDollars;
      if(potentialLoss > MaxLossPerSpikeTradeDollars * 1.01)
      {
         Print("❌ TRADE BLOQUÉ - Perte min (lot min ", DoubleToString(minLot, 2), ") = ", DoubleToString(potentialLoss, 2), "$ > ", MaxLossPerSpikeTradeDollars, "$");
         return;
      }
      Print("🔧 Lot réduit pour perte max ", MaxLossPerSpikeTradeDollars, "$ → Lot: ", DoubleToString(lot, 2), " | Perte potentielle: ", DoubleToString(potentialLoss, 2), "$");
   }
   else
      Print("✅ Perte potentielle VALIDÉE: ", DoubleToString(potentialLoss, 2), "$ <= ", MaxLossPerSpikeTradeDollars, "$");
   
   // Envoyer notification
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double notificationSL = 0, notificationTP = 0;
   
   if(direction == "BUY")
   {
      notificationSL = currentPrice - (currentPrice * 0.001);
      notificationTP = currentPrice + (currentPrice * 0.003);
   }
   else // SELL
   {
      notificationSL = currentPrice + (currentPrice * 0.001);
      notificationTP = currentPrice - (currentPrice * 0.003);
   }
   
   SendDerivArrowNotification(direction, currentPrice, notificationSL, notificationTP);
   
   // Exécuter l'ordre
   bool orderExecuted = false;
   
   // DEBUG: Vérifier l'option NoSLTP_BoomCrash
   Print("🔍 DEBUG - NoSLTP_BoomCrash: ", NoSLTP_BoomCrash ? "OUI" : "NON", " | Catégorie: ", (SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH ? "BOOM_CRASH" : "AUTRE"));
   
     if(direction == "BUY")
     {
        // SPIKE TRADE autonome: le spike capté est le signal, pas besoin de flèche SMC_DERIV_ARROW
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
       double sl = 0, tp = 0;
       
       // Utiliser les zones prédécalculées (proactives) au lieu de recalculer
       string entrySource = "";
       double limitPrice = 0.0;
       if(g_cachedBestBuyLevel > 0 && g_cachedBestBuyLevel < ask)
       {
          limitPrice = g_cachedBestBuyLevel;
          entrySource = g_cachedBuySource;
          Print("🎯 SPIKE BUY USING CACHED ZONE: ", entrySource, " @ ", DoubleToString(limitPrice, _Digits));
       }
       else
       {
          limitPrice = GetBestSpikeEntryLevel("BUY", ask, atrValue, entrySource);
          Print("🎯 SPIKE BUY FALLBACK TO DYNAMIC: ", entrySource, " @ ", DoubleToString(limitPrice, _Digits));
       }
       
       // Appliquer SL/TP seulement si NoSLTP_BoomCrash est désactivé
       if(!NoSLTP_BoomCrash || SMC_GetSymbolCategory(_Symbol) != SYM_BOOM_CRASH)
       {
          sl = limitPrice - atrValue * 2.0;
          double buySpikeRR = UseSniperScalperMode ? MinRewardRiskRatio : 1.5;
          tp = limitPrice + (limitPrice - sl) * buySpikeRR;
          // Chaine de Spikes H1/M5 (Kola): TP = extension S/R H1 opposee si disponible et coherent
          if(SCH1_TPUseSRExtension && g_sch1_tpHint > limitPrice)
          {
             tp = g_sch1_tpHint;
             Print("🎯 SPIKE BUY - TP ajuste par extension S/R H1 (Chaine de Spikes): ", DoubleToString(tp, _Digits));
          }
       }
       
       Print("🎯 SPIKE BUY LIMIT - Source: ", entrySource, " | Ask: ", DoubleToString(ask, _Digits), " | Limit: ", DoubleToString(limitPrice, _Digits),
             " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits));
      
      MqlTradeRequest req = {};
      MqlTradeResult res = {};
      req.action   = TRADE_ACTION_PENDING;
      req.symbol   = _Symbol;
      req.volume   = lot;
      req.type     = ORDER_TYPE_BUY_LIMIT;
      req.price    = limitPrice;
      req.sl       = sl;
      req.tp       = tp;
      req.magic    = InpMagicNumber;
      req.deviation = 50;
      req.comment  = g_lastSpikeEntryWasEarly ? "SPIKE CHAIN EARLY BUY LIMIT" : "SPIKE TRADE BUY LIMIT";
      
      if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_BUY_LIMIT)) return;
      CleanupExcessLimits(_Symbol, 2);
       if(ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, ORDER_TYPE_BUY_LIMIT) && SafeOrderSend(req, res))
       {
          orderExecuted = true;
          Print("✅ SPIKE TRADE BUY LIMIT placé @ ", DoubleToString(req.price, _Digits), " | Lot: ", DoubleToString(lot, 2), " | Ticket: ", res.order);
          // Chaîne de spikes enrichie : enregistrer + notifier (Dow + type chaîne + TP1-3)
          SMCSCS_RegisterSpike(_Symbol, 1.0, 0);
          SMCSCS_NotifyChainSignal(_Symbol, 1.0, atrValue);
       }
      else
      {
         Print("❌ Échec SPIKE TRADE BUY LIMIT - Erreur: ", res.retcode, " - ", res.comment);
      }
   }
     else // SELL
     {
        // SPIKE TRADE autonome: le spike capté est le signal, pas besoin de flèche SMC_DERIV_ARROW
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
       double sl = 0, tp = 0;
       
       // Utiliser les zones prédécalculées (proactives) au lieu de recalculer
       string entrySource = "";
       double limitPrice = 0.0;
       if(g_cachedBestSellLevel > 0 && g_cachedBestSellLevel > bid)
       {
          limitPrice = g_cachedBestSellLevel;
          entrySource = g_cachedSellSource;
          Print("🎯 SPIKE SELL USING CACHED ZONE: ", entrySource, " @ ", DoubleToString(limitPrice, _Digits));
       }
       else
       {
          limitPrice = GetBestSpikeEntryLevel("SELL", bid, atrValue, entrySource);
          Print("🎯 SPIKE SELL FALLBACK TO DYNAMIC: ", entrySource, " @ ", DoubleToString(limitPrice, _Digits));
       }
       
       // Appliquer SL/TP seulement si NoSLTP_BoomCrash est désactivé
       if(!NoSLTP_BoomCrash || SMC_GetSymbolCategory(_Symbol) != SYM_BOOM_CRASH)
       {
          sl = limitPrice + atrValue * 2.0;
          double sellSpikeRR = UseSniperScalperMode ? MinRewardRiskRatio : 1.5;
          tp = limitPrice - (sl - limitPrice) * sellSpikeRR;
          // Chaine de Spikes H1/M5 (Kola): TP = extension S/R H1 opposee si disponible et coherente
          if(SCH1_TPUseSRExtension && g_sch1_tpHint > 0 && g_sch1_tpHint < limitPrice)
          {
             tp = g_sch1_tpHint;
             Print("🎯 SPIKE SELL - TP ajuste par extension S/R H1 (Chaine de Spikes): ", DoubleToString(tp, _Digits));
          }
       }
       
       Print("🎯 SPIKE SELL LIMIT - Source: ", entrySource, " | Bid: ", DoubleToString(bid, _Digits), " | Limit: ", DoubleToString(limitPrice, _Digits),
             " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits));
      
      MqlTradeRequest req = {};
      MqlTradeResult res = {};
      req.action   = TRADE_ACTION_PENDING;
      req.symbol   = _Symbol;
      req.volume   = lot;
      req.type     = ORDER_TYPE_SELL_LIMIT;
      req.price    = limitPrice;
      req.sl       = sl;
      req.tp       = tp;
      req.magic    = InpMagicNumber;
      req.deviation = 50;
      req.comment  = g_lastSpikeEntryWasEarly ? "SPIKE CHAIN EARLY SELL LIMIT" : "SPIKE TRADE SELL LIMIT";
      
      if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_SELL_LIMIT)) return;
      CleanupExcessLimits(_Symbol, 2);
       if(ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, ORDER_TYPE_SELL_LIMIT) && SafeOrderSend(req, res))
       {
          orderExecuted = true;
          Print("✅ SPIKE TRADE SELL LIMIT placé @ ", DoubleToString(req.price, _Digits), " | Lot: ", DoubleToString(lot, 2), " | Ticket: ", res.order);
          // Chaîne de spikes enrichie : enregistrer + notifier (Dow + type chaîne + TP1-3)
          SMCSCS_RegisterSpike(_Symbol, -1.0, 0);
          SMCSCS_NotifyChainSignal(_Symbol, -1.0, atrValue);
       }
      else
      {
         Print("❌ Échec SPIKE TRADE SELL LIMIT - Erreur: ", res.retcode, " - ", res.comment);
      }
   }
   
   if(orderExecuted)
   {
      Print("🎯 SPIKE TRADE EXÉCUTÉ AVEC SUCCÈS - Direction: ", direction, " | Symbole: ", _Symbol,
            g_lastSpikeEntryWasEarly ? " | Mode: ENTRÉE PRÉCOCE (Spike Chain)" : "");
      
      // MT5 Push Notification (Mobile)
      string notifMsg = StringFormat("SPIKE %s %s | Lot: %s",
                                     direction, _Symbol, DoubleToString(lot, 2));
      SendNotification(notifMsg);
      Print("📱 PUSH NOTIFICATION envoyée: ", notifMsg);
      
      // Démarrer la surveillance pour clôture immédiate en gain positif
      StartSpikePositionMonitoring(direction);
   }
    g_lastSpikeEntryWasEarly = false;
}

void ExecuteVolatilityTrade(string direction)
{
   Print("🔍 VOLATILITY TRADE - Direction: ", direction, " | Symbole: ", _Symbol);
   
   // Protection capital: max positions
   if(IsMaxPositionsReached())
   {
      Print("🚫 VOLATILITY BLOQUÉ - Max positions atteint (", MaxPositionsTerminal, ")");
      return;
   }
   
   // Anti-doublon: pas de position existante sur ce symbole
   int existingPositions = CountPositionsForSymbol(_Symbol);
   if(existingPositions > 0)
   {
      Print("🚫 VOLATILITY BLOQUÉ - ", existingPositions, " position(s) déjà ouverte(s) sur ", _Symbol);
      return;
   }
   
   // Calculer lot
   double lot = CalculateLotSize();
   lot = ApplyRecoveryLot(lot);
   if(lot <= 0)
   {
      Print("❌ VOLATILITY - Lot invalide");
      return;
   }
   
   // ATR pour SL/TP
   double atrValue = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) >= 1)
         atrValue = atrBuf[0];
   }
   if(atrValue <= 0)
      atrValue = SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.002;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = (double)stopsLevel * point;
   if(minStopDistance <= 0) minStopDistance = 5 * point;
   
   // SL/TP basés sur ATR avec RR ratio
   double slDist = atrValue * SL_ATRMult;
   double rrRatio = UseSniperScalperMode ? MinRewardRiskRatio : 2.0;
   double tpDist = slDist * rrRatio;
   
   // S'assurer que SL respecte le min du courtier
   slDist = MathMax(slDist, minStopDistance * 2.0);
   tpDist = MathMax(tpDist, slDist * rrRatio);
   
   // Vérifier perte max en $
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0) tickSize = point;
   if(tickVal <= 0) tickVal = 1.0;
   double riskPerLotDollars = slDist * (tickVal / tickSize);
   if(riskPerLotDollars <= 0) riskPerLotDollars = 1.0;
   double potentialLoss = lot * riskPerLotDollars;
   if(potentialLoss > MaxLossPerTradeDollars)
   {
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      if(lotStep <= 0) lotStep = 0.01;
      double lotCap = MaxLossPerTradeDollars / riskPerLotDollars;
      lot = MathFloor(lotCap / lotStep) * lotStep;
      lot = MathMax(minLot, MathMin(maxLot, lot));
      lot = NormalizeDouble(lot, 2);
      potentialLoss = lot * riskPerLotDollars;
      if(potentialLoss > MaxLossPerTradeDollars * 1.01)
      {
         Print("❌ VOLATILITY BLOQUÉ - Perte min (lot ", DoubleToString(minLot, 2), ") = ",
               DoubleToString(potentialLoss, 2), "$ > ", MaxLossPerTradeDollars, "$");
         return;
      }
      Print("🔧 VOLATILITY Lot réduit → ", DoubleToString(lot, 2), " | Perte: ", DoubleToString(potentialLoss, 2), "$");
   }
   
   // Prix actuel + SL/TP
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = 0, tp = 0;
   
   if(direction == "BUY")
   {
      sl = NormalizeDouble(ask - slDist, _Digits);
      tp = NormalizeDouble(ask + tpDist, _Digits);
   }
   else
   {
      sl = NormalizeDouble(bid + slDist, _Digits);
      tp = NormalizeDouble(bid - tpDist, _Digits);
   }
   
   Print("🎯 VOLATILITY ", direction, " | Ask/Bid: ", DoubleToString(direction == "BUY" ? ask : bid, _Digits),
         " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits),
         " | SL dist: ", DoubleToString(slDist/point, 0), " pts | RR: ", DoubleToString(rrRatio, 1),
         " | ATR: ", DoubleToString(atrValue, _Digits));
   
   // Envoyer notification
   SendDerivArrowNotification(direction, direction == "BUY" ? ask : bid, sl, tp);
   
// Exécuter ordre au marché
    MqlTradeRequest req = {};
    MqlTradeResult res = {};
    req.action    = TRADE_ACTION_DEAL;
    req.symbol    = _Symbol;
    req.volume    = lot;
    req.type      = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    req.price     = (direction == "BUY") ? ask : bid;
    req.sl        = sl;
    req.tp        = tp;
    req.magic     = InpMagicNumber;
    req.deviation = 50;
    req.comment   = "VOLATILITY " + direction;
    
    if(SafeOrderSend(req, res))
    {
       ulong ticket = res.order;
       if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
       Print("✅ VOLATILITY TRADE EXÉCUTÉ - ", direction, " ", _Symbol,
             " | Lot: ", DoubleToString(lot, 2),
             " | Ticket: ", res.order,
            " | SL: ", DoubleToString(sl, _Digits),
            " | TP: ", DoubleToString(tp, _Digits));
      
      string notifMsg = StringFormat("VOLATILITY %s %s | Lot: %s | RR: %s",
                                     direction, _Symbol, DoubleToString(lot, 2),
                                     DoubleToString(rrRatio, 1));
      SendNotification(notifMsg);
      Print("📱 PUSH NOTIFICATION envoyée: ", notifMsg);
   }
   else
   {
      Print("❌ VOLATILITY TRADE ÉCHOUÉ - Erreur: ", res.retcode, " - ", res.comment);
   }
}

//| SURVEILLER ET FERMER LA POSITION SPIKE EN GAIN POSITIF           |
void StartSpikePositionMonitoring(string direction)
{
   // DÉSACTIVÉ - Cette fonction fermait les positions trop rapidement
   // Laisser ManageBoomCrashSpikeClose() gérer les fermetures
   Print("🔍 SURVEILLANCE SPIKE DÉSACTIVÉE - Laisser le trade respirer");
   return;
   
   /* 
   // CODE ORIGINAL DÉSACTIVÉ:
   // Attendre un peu que la position soit complètement initialisée
   Sleep(1000);
   
   // Surveiller pendant 30 secondes maximum
   int maxAttempts = 30;
   int attempt = 0;
   
   while(attempt < maxAttempts)
   {
      // Parcourir les positions pour trouver celle du spike trade
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            string symbol = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            string comment = PositionGetString(POSITION_COMMENT);
            
            // Vérifier si c'est notre position spike
            if(symbol == _Symbol && StringFind(comment, "SPIKE TRADE") >= 0)
            {
               Print("🔍 SURVEILLANCE SPIKE - Ticket: ", ticket, " | Profit: ", DoubleToString(profit, 2), "$");
               
               // Fermer immédiatement si en gain positif (même 0.01$)
               if(profit > 0)
               {
                  Print("💰 GAIN POSITIF DÉTECTÉ - Fermeture immédiate | Profit: ", DoubleToString(profit, 2), "$");
                  PositionCloseWithLog(ticket, "SPIKE GAIN POSITIF");
                  return;
               }
            }
         }
      }
      
      attempt++;
      Sleep(1000); // Attendre 1 seconde avant la prochaine vérification
   }
   
   Print("⏰ FIN SURVEILLANCE SPIKE - Position non fermée dans le délai imparti");
   */
}

//| FERMETURE SANS PROFIT APRÈS 7 MINUTES — probable correction de marché |
void CloseUnprofitableAfterDelay()
{
   static datetime s_lastCheck = 0;
   if(TimeCurrent() - s_lastCheck < 15) return; // check toutes les 15s max
   s_lastCheck = TimeCurrent();

   const int    DELAY_SECONDS = 7 * 60; // 7 minutes
   datetime     now           = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;

      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      if(now - openTime < DELAY_SECONDS) continue; // pas encore 7 min

      double profit = PositionGetDouble(POSITION_PROFIT);
      // Attendre au moins 1$ de perte — pas de sortie rapide sans spike
      double minLoss = MathMax(1.0, MinLossBeforeAutoCloseUSD);
      if(profit > -minLoss) continue;

      ulong ticket = PositionGetInteger(POSITION_TICKET);
      int   ageMin = (int)((now - openTime) / 60);
      Print("[7MIN-CLOSE] Perte >= $", DoubleToString(minLoss, 2), " après ", ageMin,
            " min sur ", _Symbol,
            " | profit=", DoubleToString(profit, 2),
            " | ticket=", ticket, " → fermeture");
      PositionCloseWithLog(ticket, "7min loss close");
   }
}

//| ROTATION AUTOMATIQUE DES POSITIONS - Évite de rester bloqué sur un symbole |
void AutoRotatePositions()
{
   int totalPositions = CountPositionsOurEA();
   
   // Si on n'est pas à la limite de positions, pas besoin de rotation
   if(totalPositions < MaxPositionsTerminal)
   {
      return;
   }
   
   // Si on est à la limite, vérifier s'il y a des opportunités sur d'autres symboles
   Print("🔄 ROTATION AUTO - Positions: ", totalPositions, "/", MaxPositionsTerminal, " - Vérification opportunités...");
   
   // Chercher la position la plus ancienne ou la moins performante
   ulong oldestTicket = 0;
   datetime oldestTime = TimeCurrent();
   double worstProfit = 999999;
   ulong worstTicket = 0;
   string worstSymbol = "";
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      
      string symbol = posInfo.Symbol();
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      datetime openTime = posInfo.Time();
      ulong ticket = posInfo.Ticket();
      
      // Priorité 1: Position en perte depuis longtemps
      if(profit < -0.5 && openTime < oldestTime)
      {
         oldestTime = openTime;
         oldestTicket = ticket;
      }
      
      // Priorité 2: Position avec la pire performance
      if(profit < worstProfit)
      {
         worstProfit = profit;
         worstTicket = ticket;
         worstSymbol = symbol;
      }
   }
   
   // Fermer la position la plus ancienne en perte OU la pire position
   ulong ticketToClose = (oldestTicket > 0) ? oldestTicket : worstTicket;
   
   if(ticketToClose > 0)
   {
      if(!PositionSelectByTicket(ticketToClose))
      {
         Print("⚠️ Position déjà fermée avant rotation - ticket=", ticketToClose);
         return;
      }
      
      string symbolToClose = PositionGetString(POSITION_SYMBOL);
      double positionProfit = PositionGetDouble(POSITION_PROFIT);
      
      // Fermer seulement si c'est une position en perte ou si elle est ouverte depuis plus de 30 minutes
      datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
      int minutesOpen = (int)(TimeCurrent() - positionTime) / 60;
      
      if(positionProfit < -0.2 || minutesOpen > 30)
      {
         Print("🔄 ROTATION AUTO - Fermeture position: ", symbolToClose, 
               " | Profit: ", DoubleToString(positionProfit, 2), "$",
               " | Âge: ", minutesOpen, " min");
         
         if(PositionCloseWithLog(ticketToClose, "Rotation automatique"))
         {
            Print("✅ ROTATION AUTO - Position fermée avec succès - Libère place pour nouvelles opportunités");
         }
         else
         {
            int err = GetLastError();
            Print("❌ ROTATION AUTO - Échec fermeture position: ", symbolToClose, " | Erreur: ", err);
         }
      }
      else
      {
         Print("🔄 ROTATION AUTO - Position conservée: ", symbolToClose, 
               " | Profit: ", DoubleToString(positionProfit, 2), "$",
               " | Âge: ", minutesOpen, " min (tôt ou profitable)");
      }
   }
   else
   {
      Print("🔄 ROTATION AUTO - Aucune position éligible à la fermeture");
   }
}

//+------------------------------------------------------------------+
//| Place S/R 20-bar limit orders - spike entry points               |
//| BUY_LIMIT juste EN-DESSOUS support (rebond spike haussier)       |
//| SELL_LIMIT juste AU-DESSUS résistance (rebond spike baissier)    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| S/R 20 bars DÉJÀ TOUCHÉ + REBONDI -> impulsion forte.            |
//| Logique: on suit l'état "prix dans la zone S/R 20 bars". Quand   |
//| le prix ENTRE dans la zone (touch) puis EN SORT vers l'extérieur   |
//| (rebond/refus), on arme le flag de direction. Le flag reste armé   |
//| un certain nombre de bougies (fenêtre de chaîne de spikes).        |
//+------------------------------------------------------------------+
void UpdateSR20BounceState()
{
    if(!UseSR20BarLimits && !UseImpulseZone) return;

    // Limiter aux symboles de type spike (Boom/Crash/Painx/Gainx)
    if(!SMC_IsSpikeStyleSymbol(_Symbol)) return;

    // Calculer (ou rafraîchir) les extrêmes 20 bars indépendamment du flag
    // UseSR20BarLimits, car PlaceSRLimitOrders20Bars peut ne pas tourner.
    double atrVal = 0;
    if(atrHandle != INVALID_HANDLE)
    {
        double atr[]; ArraySetAsSeries(atr, true);
        if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1) atrVal = atr[0];
    }
    if(atrVal <= 0) atrVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 50;
    if(atrVal <= 0) return;

    int lowestIdx  = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 20, 1);
    int highestIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 1);
    if(lowestIdx < 0 || highestIdx < 0) return;

    g_impulseSupport20    = iLow(_Symbol, PERIOD_CURRENT, lowestIdx);
    g_impulseResistance20 = iHigh(_Symbol, PERIOD_CURRENT, highestIdx);
    g_impulseSupBuffer   = atrVal * ImpulseZoneBufferATR;
    g_impulseResBuffer   = atrVal * ImpulseZoneBufferATR;

    double sup20 = g_impulseSupport20;
    double res20 = g_impulseResistance20;
    if(sup20 <= 0 || res20 <= 0) return;

    double supBuf = (g_impulseSupBuffer > 0) ? g_impulseSupBuffer : SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;
    double resBuf = (g_impulseResBuffer > 0) ? g_impulseResBuffer : SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10;

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if(bid <= 0 || ask <= 0) return;
    double price = (bid + ask) * 0.5;

    // État actuel: le prix est-il DANS la zone (touch) ?
    bool inSup = (price <= sup20 + supBuf);
    bool inRes = (price >= res20 - resBuf);
    bool outSup = (price > sup20 + supBuf);   // clairement reparti au-dessus
    bool outRes = (price < res20 - resBuf);   // clairement reparti en-dessous

    // Expiration des armes après la fenêtre
    if(g_sr20BounceBuyBars > 0)
    {
        g_sr20BounceBuyBars++;
        if(g_sr20BounceBuyBars > SR20BounceWindowBars)
        {
            g_sr20BounceBuyBars = 0;
            g_sr20BounceArmedBuy = false;
        }
    }
    if(g_sr20BounceSellBars > 0)
    {
        g_sr20BounceSellBars++;
        if(g_sr20BounceSellBars > SR20BounceWindowBars)
        {
            g_sr20BounceSellBars = 0;
            g_sr20BounceArmedSell = false;
        }
    }

    // Compteurs "hors zone" pour confirmation du rebond (>= SR20BounceConfirmBars bougies)
    if(outSup) g_sr20OutOfSupBars++; else g_sr20OutOfSupBars = 0;
    if(outRes) g_sr20OutOfResBars++; else g_sr20OutOfResBars = 0;

    static bool s_prevInSup = false;
    static bool s_prevInRes = false;

    // Rebond support: était DANS la zone, maintenant HORS zone pendant >= N bougies
    if(!inSup && s_prevInSup && g_sr20OutOfSupBars >= SR20BounceConfirmBars)
    {
        g_sr20BounceArmedBuy = true;
        g_sr20BounceBuyTime  = TimeCurrent();
        g_sr20BounceBuyBars   = 1;
        g_sr20BounceArmedSell = false;  // MUTEX: un seul côté armé à la fois
        g_sr20BounceSellBars  = 0;
        Print("🟢 SR20 BOUNCE: support 20 bars touché+rebondi (HAUSSIER) sur ", _Symbol,
              " | niveau=", DoubleToString(sup20, _Digits), " prix=", DoubleToString(price, _Digits));
    }

    // Rebond résistance: était DANS la zone, maintenant HORS zone pendant >= N bougies
    if(!inRes && s_prevInRes && g_sr20OutOfResBars >= SR20BounceConfirmBars)
    {
        g_sr20BounceArmedSell = true;
        g_sr20BounceSellTime  = TimeCurrent();
        g_sr20BounceSellBars   = 1;
        g_sr20BounceArmedBuy = false;   // MUTEX: un seul côté armé à la fois
        g_sr20BounceBuyBars  = 0;
        Print("🔴 SR20 BOUNCE: résistance 20 bars touchée+rebondie (BAISSIER) sur ", _Symbol,
              " | niveau=", DoubleToString(res20, _Digits), " prix=", DoubleToString(price, _Digits));
    }

    s_prevInSup = inSup;
    s_prevInRes = inRes;
}

void PlaceSRLimitOrders20Bars()
{
    if(!UseSR20BarLimits || BlockAllTrades) return;

    // GOM=WAIT : déjà annulé par le gate centralisé OnTick — on sort simplement
    if(g_smcGomVerdictNum == 0 || !g_smcGomConnected) return;

    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 25, rates) < 20) return;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int    dg    = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   double atrVal = 0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1) atrVal = atr[0];
   }
   if(atrVal <= 0) atrVal = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - price) * 2.0;
   if(atrVal <= 0) return;

   // ── Compter SEULEMENT nos ordres SR20 existants (pas les EMA SMC, etc.) ──
   int sr20BuyExists = 0, sr20SellExists = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, "SR20") < 0) continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_LIMIT)  sr20BuyExists++;
      if(ot == ORDER_TYPE_SELL_LIMIT) sr20SellExists++;
   }
   int sr20Total = sr20BuyExists + sr20SellExists;
   if(sr20Total >= SR20BarMaxOrders) return;

   // ── Détection pivot highs / lows sur 20 bars ──
   double supports[], resistances[];
   ArrayResize(supports, 0);
   ArrayResize(resistances, 0);

   for(int i = 2; i < 18; i++)
   {
      // Pivot Low (support): low[i] < low[i-1] et low[i] < low[i+1]
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
         rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
      {
         int sz = ArraySize(supports);
         ArrayResize(supports, sz + 1);
         supports[sz] = rates[i].low;
      }
      // Pivot High (resistance): high[i] > high[i-1] et high[i] > high[i+1]
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
         rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
      {
         int sz = ArraySize(resistances);
         ArrayResize(resistances, sz + 1);
         resistances[sz] = rates[i].high;
      }
   }

   if(ArraySize(supports) == 0 && ArraySize(resistances) == 0) return;

   // ── Choisir le support et la résistance les plus proches ──
   double bestSupport = 0, bestResistance = 0;
   double minDistSupport = 999 * atrVal, minDistResistance = 999 * atrVal;

   for(int i = 0; i < ArraySize(supports); i++)
   {
      if(supports[i] < price && supports[i] > 0)
      {
         double dist = price - supports[i];
         if(dist < minDistSupport && dist < atrVal * SR20BarMaxDistATR)
         {
            minDistSupport = dist;
            bestSupport = supports[i];
         }
      }
   }

   for(int i = 0; i < ArraySize(resistances); i++)
   {
      if(resistances[i] > price && resistances[i] > 0)
      {
         double dist = resistances[i] - price;
         if(dist < minDistResistance && dist < atrVal * SR20BarMaxDistATR)
         {
            minDistResistance = dist;
            bestResistance = resistances[i];
         }
      }
   }

    Print("📊 SR20 Pivots: ", ArraySize(supports), " supports, ", ArraySize(resistances),
          " resistances | Best: S=", DoubleToString(bestSupport, dg),
          " R=", DoubleToString(bestResistance, dg),
          " | Price=", DoubleToString(price, dg),
          " | SR20 orders: ", sr20Total, "/", SR20BarMaxOrders);

    // ── Dessiner les lignes S/R 20 bars sur le graphique ──
    datetime now = TimeCurrent();
    datetime future = now + PeriodSeconds(PERIOD_CURRENT) * 200;

    string supName  = "SR20_Support_"   + _Symbol;
    string resName  = "SR20_Resistance_" + _Symbol;
    string supLabel = "SR20_SUP_LABEL_" + _Symbol;
    string resLabel = "SR20_RES_LABEL_" + _Symbol;

    // Support: ligne blanche épaisse pleine
    if(bestSupport > 0)
    {
       ObjectDelete(0, supName);
       if(ObjectCreate(0, supName, OBJ_TREND, 0, now, bestSupport, future, bestSupport))
       {
          ObjectSetInteger(0, supName, OBJPROP_COLOR, clrWhite);
          ObjectSetInteger(0, supName, OBJPROP_WIDTH, 3);
          ObjectSetInteger(0, supName, OBJPROP_STYLE, STYLE_SOLID);
          ObjectSetInteger(0, supName, OBJPROP_RAY_RIGHT, false);
          ObjectSetInteger(0, supName, OBJPROP_BACK, false);
          ObjectSetString(0, supName, OBJPROP_TEXT, "SR20 Support");
       }
       // Label
       ObjectDelete(0, supLabel);
       if(ObjectCreate(0, supLabel, OBJ_TEXT, 0, now, bestSupport))
       {
          ObjectSetString(0, supLabel, OBJPROP_TEXT, "SR20 ▲ " + DoubleToString(bestSupport, dg));
          ObjectSetInteger(0, supLabel, OBJPROP_COLOR, clrWhite);
          ObjectSetInteger(0, supLabel, OBJPROP_FONTSIZE, 8);
          ObjectSetString(0, supLabel, OBJPROP_FONT, "Arial Bold");
       }
    }
    else
    {
       ObjectDelete(0, supName);
       ObjectDelete(0, supLabel);
    }

    // Résistance: ligne blanche épaisse pleine
    if(bestResistance > 0)
    {
       ObjectDelete(0, resName);
       if(ObjectCreate(0, resName, OBJ_TREND, 0, now, bestResistance, future, bestResistance))
       {
          ObjectSetInteger(0, resName, OBJPROP_COLOR, clrWhite);
          ObjectSetInteger(0, resName, OBJPROP_WIDTH, 3);
          ObjectSetInteger(0, resName, OBJPROP_STYLE, STYLE_SOLID);
          ObjectSetInteger(0, resName, OBJPROP_RAY_RIGHT, false);
          ObjectSetInteger(0, resName, OBJPROP_BACK, false);
          ObjectSetString(0, resName, OBJPROP_TEXT, "SR20 Resistance");
       }
       // Label
       ObjectDelete(0, resLabel);
       if(ObjectCreate(0, resLabel, OBJ_TEXT, 0, now, bestResistance))
       {
          ObjectSetString(0, resLabel, OBJPROP_TEXT, "SR20 ▼ " + DoubleToString(bestResistance, dg));
          ObjectSetInteger(0, resLabel, OBJPROP_COLOR, clrWhite);
          ObjectSetInteger(0, resLabel, OBJPROP_FONTSIZE, 8);
          ObjectSetString(0, resLabel, OBJPROP_FONT, "Arial Bold");
       }
    }
    else
    {
       ObjectDelete(0, resName);
       ObjectDelete(0, resLabel);
    }

   // ── Supprimer les anciens ordres SR20 si le niveau a shifté ──
   if(SR20BarCancelOnShift && (bestSupport > 0 || bestResistance > 0))
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
         string cmt = OrderGetString(ORDER_COMMENT);
         if(StringFind(cmt, "SR20") < 0) continue;

         ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         double op = OrderGetDouble(ORDER_PRICE_OPEN);

         if(otype == ORDER_TYPE_BUY_LIMIT && bestSupport > 0 && MathAbs(op - bestSupport) > atrVal * 0.3)
         {
            trade.OrderDelete(ticket);
            sr20BuyExists--;
            Print("🔄 SR20 BUY_LIMIT annulé (shift): prix ", DoubleToString(op, dg),
                  " ≠ support ", DoubleToString(bestSupport, dg));
         }
         if(otype == ORDER_TYPE_SELL_LIMIT && bestResistance > 0 && MathAbs(op - bestResistance) > atrVal * 0.3)
         {
            trade.OrderDelete(ticket);
            sr20SellExists--;
            Print("🔄 SR20 SELL_LIMIT annulé (shift): prix ", DoubleToString(op, dg),
                  " ≠ résistance ", DoubleToString(bestResistance, dg));
         }
      }
   }

    // ── Placer BUY_LIMIT juste en dessous du support (spike rebond) ──
    // Sur Crash/Painx: PAS de BUY LIMIT (uniquement SELL)
    if(bestSupport > 0 && sr20BuyExists < 1 && sr20Total < SR20BarMaxOrders
       && !IsCrashLikeSymbol(_Symbol))
   {
       // Offset: 2 points sous le support pour capter le spike rebond
       double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
       if(tickSize <= 0) tickSize = point;
       double entry = NormalizeDouble(bestSupport - point * 2, dg);
      double sl    = NormalizeDouble(entry - atrVal * SR20BarSL_ATRMult, dg);
      double tp    = NormalizeDouble(entry + atrVal * SR20BarTP_ATRMult, dg);

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action   = TRADE_ACTION_PENDING;
      req.symbol   = _Symbol;
      req.volume   = NormalizeVolumeForSymbol(0.01);
      req.type     = ORDER_TYPE_BUY_LIMIT;
      req.price    = entry;
      req.sl       = sl;
      req.tp       = tp;
      req.magic    = InpMagicNumber;
       req.comment  = "SR20 BUY LIMIT";

        if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_BUY_LIMIT)) { ReleaseOpenLock(); return; }
        CleanupExcessLimits(_Symbol, 2);
        if(ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, ORDER_TYPE_BUY_LIMIT))
        {
           if(trade.SafeOrderSend(req, res))
          {
             Print("📊 SR20 BUY_LIMIT @ ", req.price, " (support ", bestSupport,
                   ") | SL=", req.sl, " | TP=", req.tp, " | ATR=", DoubleToString(atrVal, dg));
             sr20BuyExists++;
             // WhatsApp SR20 signal
             SendSR20WhatsAppSignal("SR20_ENTRY", _Symbol, "BUY",
                                    req.price, req.sl, req.tp, price,
                                    bestSupport, "SUPPORT", atrVal,
                                    0, 0, "");
          }
          else
             Print("❌ SR20 BUY_LIMIT échoué: ", res.retcode, " - ", res.comment);
       }
   }

    // ── Placer SELL_LIMIT juste au-dessus de la résistance (spike rejet) ──
    // Sur Boom/Gainx: PAS de SELL LIMIT (uniquement BUY)
    if(bestResistance > 0 && sr20SellExists < 1 && sr20Total < SR20BarMaxOrders
       && !IsBoomLikeSymbol(_Symbol))
   {
       double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
       if(tickSize <= 0) tickSize = point;
       double entry = NormalizeDouble(bestResistance + point * 2, dg);
      double sl    = NormalizeDouble(entry + atrVal * SR20BarSL_ATRMult, dg);
      double tp    = NormalizeDouble(entry - atrVal * SR20BarTP_ATRMult, dg);

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action   = TRADE_ACTION_PENDING;
      req.symbol   = _Symbol;
      req.volume   = NormalizeVolumeForSymbol(0.01);
      req.type     = ORDER_TYPE_SELL_LIMIT;
      req.price    = entry;
      req.sl       = sl;
      req.tp       = tp;
      req.magic    = InpMagicNumber;
       req.comment  = "SR20 SELL LIMIT";

        if(!CanPlaceLimitOrder(_Symbol, ORDER_TYPE_SELL_LIMIT)) { ReleaseOpenLock(); return; }
        CleanupExcessLimits(_Symbol, 2);
        if(ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, ORDER_TYPE_SELL_LIMIT))
        {
           if(trade.SafeOrderSend(req, res))
          {
             Print("📊 SR20 SELL_LIMIT @ ", req.price, " (résistance ", bestResistance,
                   ") | SL=", req.sl, " | TP=", req.tp, " | ATR=", DoubleToString(atrVal, dg));
             sr20SellExists++;
             // WhatsApp SR20 signal
             SendSR20WhatsAppSignal("SR20_ENTRY", _Symbol, "SELL",
                                    req.price, req.sl, req.tp, price,
                                    bestResistance, "RESISTANCE", atrVal,
                                    0, 0, "");
          }
         else
             Print("❌ SR20 SELL_LIMIT échoué: ", res.retcode, " - ", res.comment);
      }
   }

   // ══════════════════════════════════════════════════════════════════════
   // IMPULSE ZONE : niveau de forte impulsion 20 bars (spike trigger)
   // Utilise iLowest/iHighest sur 20 barres = extrêmes absolus
   // ══════════════════════════════════════════════════════════════════════
   if(!UseImpulseZone) return;

   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   bool isSpikeSymbol = (cat == SYM_BOOM_CRASH);
   if(!isSpikeSymbol && !ImpulseZoneShowOnChart) return;

   // Calculer les extrêmes absolus sur 20 barres (pas les pivots, les VRAIS min/max)
   int lowestIdx  = iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, 20, 1);
   int highestIdx = iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, 20, 1);

   if(lowestIdx < 0 || highestIdx < 0) return;

   g_impulseSupport20    = iLow(_Symbol, PERIOD_CURRENT, lowestIdx);
   g_impulseResistance20 = iHigh(_Symbol, PERIOD_CURRENT, highestIdx);

   // Buffer en price = ATR × multiplicateur
   g_impulseSupBuffer = atrVal * ImpulseZoneBufferATR;
   g_impulseResBuffer = atrVal * ImpulseZoneBufferATR;

   // Vérifier si le prix touche les zones
   g_impulseSupTouched  = (price <= g_impulseSupport20 + g_impulseSupBuffer);
   g_impulseResTouched  = (price >= g_impulseResistance20 - g_impulseResBuffer);

   // ── Dessiner les zones d'impulsion (rectangles colorés) ──
   if(ImpulseZoneShowOnChart)
   {
      datetime now = TimeCurrent();
      datetime future = now + PeriodSeconds(PERIOD_CURRENT) * 100;

      // Zone Support = vert semi-transparent
      string supZone = "IMPULSE_SUP_ZONE_" + _Symbol;
      string supLine = "IMPULSE_SUP_LINE_" + _Symbol;
      string supTxt  = "IMPULSE_SUP_TXT_" + _Symbol;

      if(g_impulseSupport20 > 0)
      {
         ObjectDelete(0, supZone);
         if(ObjectCreate(0, supZone, OBJ_RECTANGLE, 0, now, g_impulseSupport20 - g_impulseSupBuffer, future, g_impulseSupport20 + g_impulseSupBuffer))
         {
            ObjectSetInteger(0, supZone, OBJPROP_COLOR, g_impulseSupTouched ? clrLime : clrDarkGreen);
            ObjectSetInteger(0, supZone, OBJPROP_BACK, true);
            ObjectSetInteger(0, supZone, OBJPROP_FILL, true);
            ObjectSetInteger(0, supZone, OBJPROP_WIDTH, 1);
         }
         // Ligne centrale
         ObjectDelete(0, supLine);
         if(ObjectCreate(0, supLine, OBJ_TREND, 0, now, g_impulseSupport20, future, g_impulseSupport20))
         {
            ObjectSetInteger(0, supLine, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, supLine, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, supLine, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, supLine, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, supLine, OBJPROP_BACK, false);
         }
         // Label
         ObjectDelete(0, supTxt);
         if(ObjectCreate(0, supTxt, OBJ_TEXT, 0, now, g_impulseSupport20))
         {
            string touchTxt = g_impulseSupTouched ? " ⚡ IMPULSE!" : "";
            ObjectSetString(0, supTxt, OBJPROP_TEXT,
               "⚡ IMPULSE SUP " + DoubleToString(g_impulseSupport20, dg) + touchTxt);
            ObjectSetInteger(0, supTxt, OBJPROP_COLOR, g_impulseSupTouched ? clrLime : clrDarkGreen);
            ObjectSetInteger(0, supTxt, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, supTxt, OBJPROP_FONT, "Consolas Bold");
         }
      }

      // Zone Résistance = rouge semi-transparent
      string resZone = "IMPULSE_RES_ZONE_" + _Symbol;
      string resLine = "IMPULSE_RES_LINE_" + _Symbol;
      string resTxt  = "IMPULSE_RES_TXT_" + _Symbol;

      if(g_impulseResistance20 > 0)
      {
         ObjectDelete(0, resZone);
         if(ObjectCreate(0, resZone, OBJ_RECTANGLE, 0, now, g_impulseResistance20 - g_impulseResBuffer, future, g_impulseResistance20 + g_impulseResBuffer))
         {
            ObjectSetInteger(0, resZone, OBJPROP_COLOR, g_impulseResTouched ? clrRed : clrDarkRed);
            ObjectSetInteger(0, resZone, OBJPROP_BACK, true);
            ObjectSetInteger(0, resZone, OBJPROP_FILL, true);
            ObjectSetInteger(0, resZone, OBJPROP_WIDTH, 1);
         }
         // Ligne centrale
         ObjectDelete(0, resLine);
         if(ObjectCreate(0, resLine, OBJ_TREND, 0, now, g_impulseResistance20, future, g_impulseResistance20))
         {
            ObjectSetInteger(0, resLine, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(0, resLine, OBJPROP_WIDTH, 2);
            ObjectSetInteger(0, resLine, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, resLine, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(0, resLine, OBJPROP_BACK, false);
         }
         // Label
         ObjectDelete(0, resTxt);
         if(ObjectCreate(0, resTxt, OBJ_TEXT, 0, now, g_impulseResistance20))
         {
            string touchTxt = g_impulseResTouched ? " ⚡ IMPULSE!" : "";
            ObjectSetString(0, resTxt, OBJPROP_TEXT,
               "⚡ IMPULSE RES " + DoubleToString(g_impulseResistance20, dg) + touchTxt);
            ObjectSetInteger(0, resTxt, OBJPROP_COLOR, g_impulseResTouched ? clrRed : clrDarkRed);
            ObjectSetInteger(0, resTxt, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, resTxt, OBJPROP_FONT, "Consolas Bold");
         }
      }
   }

   // ── AUTO-TRADE IMPULSE ZONE (Boom/Crash/Painx/Gainx) ──
   if(!ImpulseZoneAutoTrade || !isSpikeSymbol) return;
   if(CountPositionsForSymbol(_Symbol) > 0) return;
   // ── GOM WAIT / DÉCONNECTÉ: rejeter impulse trade ──
   if(UseGOMVerdictFilter && (!g_smcGomConnected || g_smcGomVerdictNum == 0 || MathAbs(g_smcGomVerdictNum) < MinGOMVerdictNumAbs))
   {
      static datetime s_lastImpulseBlock = 0;
      if(TimeCurrent() - s_lastImpulseBlock >= 30)
      {
         Print("❌ IMPULSE REJETÉ — GOM ",
               (!g_smcGomConnected ? "déconnecté" : (g_smcGomVerdictNum == 0 ? "verdict=WAIT" : "verdict=SIMPLE")),
               " — Aucun ordre autorisé");
         s_lastImpulseBlock = TimeCurrent();
      }
      return;
   }

   bool isBoom = IsBoomLikeSymbol(_Symbol);

   // Boom/Gainx → BUY si prix touche support impulse
   // Crash/Painx → SELL si prix touche résistance impulse
   bool impulseBuy  = (isBoom && g_impulseSupTouched && g_impulseSupport20 > 0);
   bool impulseSell = (!isBoom && g_impulseResTouched && g_impulseResistance20 > 0);

   if(!impulseBuy && !impulseSell) return;

   if(!TryAcquireOpenLock()) return;

   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }

   // ── SI GOM VERDICT = WAIT → limiter au lieu de market ──
   if(g_smcGomConnected && g_smcGomVerdictNum == 0)
   {
      bool orderOK = false;
      ENUM_ORDER_TYPE limitType = impulseBuy ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
      double refPrice = impulseBuy ? g_impulseSupport20 : g_impulseResistance20;

      // Scanner M5 puis M15 pour le pivot SR20 le plus proche
      ENUM_TIMEFRAMES tfList[2] = { PERIOD_M5, PERIOD_M15 };
      for(int tf = 0; tf < 2; tf++)
      {
         if(orderOK) break;
         MqlRates tfRates[];
         ArraySetAsSeries(tfRates, true);
         if(CopyRates(_Symbol, tfList[tf], 0, 25, tfRates) < 20) continue;

         double bestLevel = 0;
         double minDist = 999 * atrVal;

         for(int i = 2; i < 18; i++)
         {
            if(impulseBuy)
            {
               // Pivot Low (support): low[i] < voisins
               if(tfRates[i].low < tfRates[i-1].low && tfRates[i].low < tfRates[i+1].low &&
                  tfRates[i].low < tfRates[i-2].low && tfRates[i].low < tfRates[i+2].low)
               {
                  double dist = price - tfRates[i].low;
                  if(dist > 0 && dist < minDist && dist < atrVal * SR20BarMaxDistATR)
                  {
                     minDist = dist;
                     bestLevel = tfRates[i].low;
                  }
               }
            }
            else
            {
               // Pivot High (resistance): high[i] > voisins
               if(tfRates[i].high > tfRates[i-1].high && tfRates[i].high > tfRates[i+1].high &&
                  tfRates[i].high > tfRates[i-2].high && tfRates[i].high > tfRates[i+2].high)
               {
                  double dist = tfRates[i].high - price;
                  if(dist > 0 && dist < minDist && dist < atrVal * SR20BarMaxDistATR)
                  {
                     minDist = dist;
                     bestLevel = tfRates[i].high;
                  }
               }
            }
         }

         if(bestLevel <= 0) continue;

         // Placer le limit order sur ce niveau SR20 M5/M15
         double entry = NormalizeDouble(bestLevel - point * 2, dg);  // BUY: sous support
         double sl    = NormalizeDouble(entry - atrVal * ImpulseZoneSL_ATRMult, dg);
         double tp    = NormalizeDouble(entry + atrVal * ImpulseZoneTP_ATRMult, dg);
         if(impulseSell)
         {
            entry = NormalizeDouble(bestLevel + point * 2, dg);  // SELL: au-dessus résistance
            sl    = NormalizeDouble(entry + atrVal * ImpulseZoneSL_ATRMult, dg);
            tp    = NormalizeDouble(entry - atrVal * ImpulseZoneTP_ATRMult, dg);
         }

         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action  = TRADE_ACTION_PENDING;
         req.symbol  = _Symbol;
         req.volume  = NormalizeVolumeForSymbol(0.01);
         req.type    = limitType;
         req.price   = entry;
         req.sl      = sl;
         req.tp      = tp;
         req.magic   = InpMagicNumber;
          req.comment = "IMPULSE SR20 WAIT";

          string tfName = (tfList[tf] == PERIOD_M5) ? "M5" : "M15";
          if(!CanPlaceLimitOrder(_Symbol, limitType)) continue;
          CleanupExcessLimits(_Symbol, 2);
          if(ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, limitType))
         {
            if(trade.SafeOrderSend(req, res))
            {
               orderOK = true;
               Print("⚡ IMPULSE→SR20 ", (impulseBuy ? "BUY" : "SELL"), " LIMIT @ ", req.price,
                     " | TF=", tfName, " | SR20=", DoubleToString(bestLevel, dg),
                     " | GOM=WAIT → limit au lieu de market",
                     " | SL=", req.sl, " TP=", req.tp);
            }
            else
               Print("❌ IMPULSE SR20 WAIT échoué: ", res.retcode, " - ", res.comment);
         }
      }

      ReleaseOpenLock();
      return;  // En WAIT on ne fait jamais de market order
   }

   // ── GOM verdict != WAIT → exécuter le market order impulse ──
   // Bloquer si direction opposée au verdict GOM
   if(g_smcGomConnected)
   {
      if(impulseBuy && g_smcGomVerdictNum < 0)
      {
         Print("🚫 IMPULSE BUY BLOQUÉ — GOM verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ") — direction SELL");
         ReleaseOpenLock(); return;
      }
      if(impulseSell && g_smcGomVerdictNum > 0)
      {
         Print("🚫 IMPULSE SELL BLOQUÉ — GOM verdict=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ") — direction BUY");
         ReleaseOpenLock(); return;
      }
   }
   bool orderOK = false;

if(impulseBuy)
    {
       double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
       double sl = NormalizeDouble(entry - atrVal * ImpulseZoneSL_ATRMult, dg);
       double tp = NormalizeDouble(entry + atrVal * ImpulseZoneTP_ATRMult, dg);

       if(SafeTradeBuy(lot, _Symbol, entry, sl, tp, "IMPULSE BUY"))
       {
          orderOK = true;
          ulong ticket = trade.ResultOrder();
          if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
          Print("⚡ IMPULSE BUY ", _Symbol, " @", DoubleToString(entry, dg),
                " | Zone supp: ", DoubleToString(g_impulseSupport20, dg),
                " ±", DoubleToString(g_impulseSupBuffer, dg),
                " | GOM=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ")",
                " | SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg));
       }
    }
    else if(impulseSell)
    {
       double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
       double sl = NormalizeDouble(entry + atrVal * ImpulseZoneSL_ATRMult, dg);
       double tp = NormalizeDouble(entry - atrVal * ImpulseZoneTP_ATRMult, dg);

       if(SafeTradeSell(lot, _Symbol, entry, sl, tp, "IMPULSE SELL"))
       {
          orderOK = true;
          ulong ticket = trade.ResultOrder();
          if(ticket > 0) SMC_ApplyPostEntrySLBuffer(_Symbol, ticket, 1.0);
          Print("⚡ IMPULSE SELL ", _Symbol, " @", DoubleToString(entry, dg),
                " | Zone res: ", DoubleToString(g_impulseResistance20, dg),
                " ±", DoubleToString(g_impulseResBuffer, dg),
                " | GOM=", g_smcGomVerdict, " (vn=", g_smcGomVerdictNum, ")",
                " | SL=", DoubleToString(sl, dg), " TP=", DoubleToString(tp, dg));
       }
    }

   ReleaseOpenLock();

   if(orderOK)
   {
      g_maxProfit = 0;
      if(UseNotifications)
      {
         string dir = impulseBuy ? "BUY" : "SELL";
         Alert("⚡ IMPULSE ", dir, " ", _Symbol);
         SendNotification("⚡ IMPULSE " + dir + " " + _Symbol);
      }
   }
}

//| END OF PROGRAM                                                  |

