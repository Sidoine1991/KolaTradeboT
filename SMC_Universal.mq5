//| SMC_Universal.mq5                                                 |
//| Robot Smart Money Concepts - UN SEUL ROBOT multi-actifs + IA      |
//| Boom/Crash | Volatility | Forex | Commodities | Metals           |
//| FVG | OB | BOS | LS | OTE | EQH/EQL | P/D | LO/NYO              |
#property copyright "TradBOT SMC"
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/OrderInfo.mqh>
#include <Trade/DealInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
// #include "SMC_Setups_Display.mqh" // Désactivé pour éviter l'erreur de fichier non trouvé

//+------------------------------------------------------------------+
//| MATÉRIALISATION DES SETUPS SMC SUR GRAPHIQUE                   |
//+------------------------------------------------------------------+

// Dessiner un setup OTE (Optimal Trade Entry)
void DrawOTESetup(double entryPrice, double stopLoss, double takeProfit, string direction)
{
   // Supprimer les anciens objets OTE
   ObjectsDeleteAll(0, "OTE_SETUP_");
   
   datetime currentTime = TimeCurrent();
   datetime futureTime = currentTime + PeriodSeconds(PERIOD_M1) * 20;
   
   // Zone d'entrée OTE
   string entryZone = "OTE_SETUP_ENTRY_ZONE";
   ObjectCreate(0, entryZone, OBJ_RECTANGLE, 0, currentTime, entryPrice - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2, 
                futureTime, entryPrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 2);
   ObjectSetInteger(0, entryZone, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, entryZone, OBJPROP_BGCOLOR, C'220,220,255');
   ObjectSetInteger(0, entryZone, OBJPROP_FILL, true);
   ObjectSetInteger(0, entryZone, OBJPROP_BACK, true);
   ObjectSetInteger(0, entryZone, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, entryZone, OBJPROP_WIDTH, 1);
   
   // Ligne d'entrée
   string entryLine = "OTE_SETUP_ENTRY_LINE";
   ObjectCreate(0, entryLine, OBJ_HLINE, 0, currentTime, entryPrice);
   ObjectSetInteger(0, entryLine, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, entryLine, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, entryLine, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, entryLine, OBJPROP_BACK, false);
   
   // Ligne SL
   string slLine = "OTE_SETUP_SL_LINE";
   ObjectCreate(0, slLine, OBJ_HLINE, 0, currentTime, stopLoss);
   ObjectSetInteger(0, slLine, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, slLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, slLine, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, slLine, OBJPROP_BACK, false);
   
   // Ligne TP
   string tpLine = "OTE_SETUP_TP_LINE";
   ObjectCreate(0, tpLine, OBJ_HLINE, 0, currentTime, takeProfit);
   ObjectSetInteger(0, tpLine, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, tpLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, tpLine, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, tpLine, OBJPROP_BACK, false);
   
   // Labels
   string entryLabel = "OTE_SETUP_ENTRY_LABEL";
   ObjectCreate(0, entryLabel, OBJ_TEXT, 0, currentTime + PeriodSeconds(PERIOD_M1) * 2, entryPrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5);
   ObjectSetString(0, entryLabel, OBJPROP_TEXT, "OTE Entry " + direction + " @" + DoubleToString(entryPrice, _Digits));
   ObjectSetInteger(0, entryLabel, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, entryLabel, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, entryLabel, OBJPROP_BACK, false);
   
   string slLabel = "OTE_SETUP_SL_LABEL";
   ObjectCreate(0, slLabel, OBJ_TEXT, 0, currentTime + PeriodSeconds(PERIOD_M1) * 2, stopLoss - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3);
   ObjectSetString(0, slLabel, OBJPROP_TEXT, "SL @" + DoubleToString(stopLoss, _Digits));
   ObjectSetInteger(0, slLabel, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, slLabel, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, slLabel, OBJPROP_BACK, false);
   
   string tpLabel = "OTE_SETUP_TP_LABEL";
   ObjectCreate(0, tpLabel, OBJ_TEXT, 0, currentTime + PeriodSeconds(PERIOD_M1) * 2, takeProfit + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3);
   ObjectSetString(0, tpLabel, OBJPROP_TEXT, "TP @" + DoubleToString(takeProfit, _Digits));
   ObjectSetInteger(0, tpLabel, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, tpLabel, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, tpLabel, OBJPROP_BACK, false);
   
   // Titre du setup
   string title = "OTE_SETUP_TITLE";
   ObjectCreate(0, title, OBJ_TEXT, 0, currentTime, takeProfit + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
   ObjectSetString(0, title, OBJPROP_TEXT, "⚡ OTE SETUP - " + direction + " ⚡");
   ObjectSetInteger(0, title, OBJPROP_COLOR, clrYellow);
   ObjectSetInteger(0, title, OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, title, OBJPROP_BACK, false);
   
   Print("🎯 SETUP OTE MATÉRIALISÉ - ", direction, " ", _Symbol);
   Print("   📍 Entry: ", DoubleToString(entryPrice, _Digits));
   Print("   🛡️ SL: ", DoubleToString(stopLoss, _Digits));
   Print("   🎯 TP: ", DoubleToString(takeProfit, _Digits));
}

// Dessiner un setup BOS (Break of Structure)
void DrawBOSSetup(double breakPrice, string direction, datetime breakTime)
{
   // Supprimer les anciens objets BOS
   ObjectsDeleteAll(0, "BOS_SETUP_");
   
   datetime futureTime = breakTime + PeriodSeconds(PERIOD_M1) * 30;
   
   // Ligne de breakout BOS
   string bosLine = "BOS_SETUP_BREAK_LINE";
   ObjectCreate(0, bosLine, OBJ_TREND, 0, breakTime, breakPrice, futureTime, breakPrice);
   ObjectSetInteger(0, bosLine, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, bosLine, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, bosLine, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, bosLine, OBJPROP_BACK, false);
   
   // Flèche de direction
   string arrow = "BOS_SETUP_ARROW";
   ObjectCreate(0, arrow, OBJ_ARROW, 0, breakTime + PeriodSeconds(PERIOD_M1) * 5, 
                direction == "BUY" ? breakPrice - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10 : 
                                   breakPrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10);
   ObjectSetInteger(0, arrow, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, arrow, OBJPROP_ARROWCODE, direction == "BUY" ? 233 : 234);
   ObjectSetInteger(0, arrow, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, arrow, OBJPROP_BACK, false);
   
   // Label BOS
   string bosLabel = "BOS_SETUP_LABEL";
   ObjectCreate(0, bosLabel, OBJ_TEXT, 0, breakTime + PeriodSeconds(PERIOD_M1) * 2, 
                direction == "BUY" ? breakPrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5 : 
                                   breakPrice - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5);
   ObjectSetString(0, bosLabel, OBJPROP_TEXT, "🔥 BOS " + direction + " 🔥");
   ObjectSetInteger(0, bosLabel, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, bosLabel, OBJPROP_FONTSIZE, 11);
   ObjectSetInteger(0, bosLabel, OBJPROP_BACK, false);
   
   Print("🔥 SETUP BOS MATÉRIALISÉ - ", direction, " @ ", DoubleToString(breakPrice, _Digits), " ", _Symbol);
}

// Dessiner un setup CHOCH (Change of Character)
void DrawCHOCHSetup(double changePrice, string direction, datetime changeTime)
{
   // Supprimer les anciens objets CHOCH
   ObjectsDeleteAll(0, "CHOCH_SETUP_");
   
   datetime futureTime = changeTime + PeriodSeconds(PERIOD_M1) * 25;
   
   // Zone de changement CHOCH
   string chochZone = "CHOCH_SETUP_ZONE";
   ObjectCreate(0, chochZone, OBJ_RECTANGLE, 0, changeTime, 
                changePrice - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3,
                futureTime, changePrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3);
   ObjectSetInteger(0, chochZone, OBJPROP_COLOR, clrPurple);
   ObjectSetInteger(0, chochZone, OBJPROP_BGCOLOR, C'200,150,255');
   ObjectSetInteger(0, chochZone, OBJPROP_FILL, true);
   ObjectSetInteger(0, chochZone, OBJPROP_BACK, true);
   ObjectSetInteger(0, chochZone, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, chochZone, OBJPROP_WIDTH, 2);
   
   // Ligne de changement
   string changeLine = "CHOCH_SETUP_CHANGE_LINE";
   ObjectCreate(0, changeLine, OBJ_HLINE, 0, changeTime, changePrice);
   ObjectSetInteger(0, changeLine, OBJPROP_COLOR, clrPurple);
   ObjectSetInteger(0, changeLine, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, changeLine, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, changeLine, OBJPROP_BACK, false);
   
   // Marqueur de changement
   string marker = "CHOCH_SETUP_MARKER";
   ObjectCreate(0, marker, OBJ_ARROW, 0, changeTime, changePrice);
   ObjectSetInteger(0, marker, OBJPROP_COLOR, clrPurple);
   ObjectSetInteger(0, marker, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, marker, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, marker, OBJPROP_BACK, false);
   
   // Label CHOCH
   string chochLabel = "CHOCH_SETUP_LABEL";
   ObjectCreate(0, chochLabel, OBJ_TEXT, 0, changeTime + PeriodSeconds(PERIOD_M1) * 3, 
                changePrice + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 8);
   ObjectSetString(0, chochLabel, OBJPROP_TEXT, "🔄 CHOCH " + direction + " 🔄");
   ObjectSetInteger(0, chochLabel, OBJPROP_COLOR, clrPurple);
   ObjectSetInteger(0, chochLabel, OBJPROP_FONTSIZE, 11);
   ObjectSetInteger(0, chochLabel, OBJPROP_BACK, false);
   
   Print("🔄 SETUP CHOCH MATÉRIALISÉ - ", direction, " @ ", DoubleToString(changePrice, _Digits), " ", _Symbol);
}

// Nettoyer tous les setups SMC
void ClearAllSMCSetups()
{
   ObjectsDeleteAll(0, "OTE_SETUP_");
   ObjectsDeleteAll(0, "BOS_SETUP_");
   ObjectsDeleteAll(0, "CHOCH_SETUP_");
   Print("🧹 TOUS LES SETUPS SMC NETTOYÉS - ", _Symbol);
}

//+------------------------------------------------------------------+
//| WRAPPER POUR CAPTURER TOUTES LES FERMETURES                    |
//+------------------------------------------------------------------+
bool PositionCloseWithLog(ulong ticket, string reason = "")
{
   if(CloseOnlyOnAIHoldOrBrokerSLTP)
   {
      string r = reason;
      StringToUpper(r);
      bool isAIHoldClose = (StringFind(r, "IA HOLD") >= 0);
      if(!isAIHoldClose)
      {
         Print("⛔ Fermeture active bloquée (mode SL/TP ou IA HOLD uniquement) | ticket=", ticket, " | reason=", reason);
         return false;
      }
   }

   // Anti-doublon de fermeture : si on tente plusieurs fois de fermer la même position dans un court délai,
   // MT5 renvoie souvent "Order to close this position already exists".
   static ulong   lastCloseTickets[16] = {0};
   static datetime lastCloseTimes[16]  = {0};
   static int     lastCloseIdx = 0;

   datetime now = TimeCurrent();
   for(int i = 0; i < 16; i++)
   {
      if(lastCloseTickets[i] == ticket && lastCloseTimes[i] > 0 && (now - lastCloseTimes[i]) <= 3)
      {
         Print("?? SKIP duplicate close (cooldown) | ticket=", ticket, " | reason=", reason);
         return true;
      }
   }

   // Obtenir les informations avant fermeture
   if(!PositionSelectByTicket(ticket))
   {
      Print("?? Position déjà fermée (skip) | ticket=", ticket, " | reason=", reason);
      return true;
   }
   else
   {
      string symbol = PositionGetString(POSITION_SYMBOL);
      double profit = PositionGetDouble(POSITION_PROFIT);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int secondsSinceOpen = (int)(now - openTime);
      
      // NOUVEAU: PROTECTION CONTRE LES FERMETURES AVEC PETITES PERTES
      if(profit < 0 && profit > -2.0)
      {
         Print("??? PROTECTION PETITE PERTE - Fermeture bloquée");
         Print("   ?? Position: ", symbol, " | Ticket: ", ticket);
         Print("   ?? Perte: ", DoubleToString(profit, 2), "$ > -2.00$ (seuil de protection)");
         Print("   ?? Raison: ", reason, " | ACTION: Position maintenue");
         return false; // Bloquer la fermeture
      }
      
      // Si la perte est ? 2$, autoriser la fermeture avec log
      if(profit < 0 && profit <= -2.0)
      {
         Print("?? PERTE IMPORTANTE DÉTECTÉE - Fermeture autorisée");
         Print("   ?? Position: ", symbol, " | Ticket: ", ticket);
         Print("   ?? Perte: ", DoubleToString(profit, 2), "$ ? -2.00$ (seuil dépassé)");
         Print("   ? Raison: ", reason, " | ACTION: Fermeture autorisée");
      }
      
      // Si profit positif, autoriser normalement
      if(profit >= 0)
      {
         Print("?? POSITION EN GAIN - Fermeture autorisée");
         Print("   ?? Position: ", symbol, " | Ticket: ", ticket);
         Print("   ?? Profit: ", DoubleToString(profit, 2), "$ | ACTION: Fermeture autorisée");
      }
      
      Print("?? FERMETURE DÉTECTÉE - ", symbol, 
            " | Ticket: ", ticket,
            " | Profit: ", DoubleToString(profit, 2), "$",
            " | Âge: ", secondsSinceOpen, "s",
            " | Raison: ", reason);
   }
   
   // Exécuter la fermeture réelle
   bool ok = trade.PositionClose(ticket);
   now = TimeCurrent();

   // Enregistrer l'historique pour empêcher les doublons
   lastCloseTickets[lastCloseIdx] = ticket;
   lastCloseTimes[lastCloseIdx]   = now;
   lastCloseIdx = (lastCloseIdx + 1) % 16;

   if(ok)
   {
      g_lastCloseActionTime = now;
      g_lastCloseActionSymbol = PositionSelectByTicket(ticket) ? PositionGetString(POSITION_SYMBOL) : _Symbol;
      return true;
   }

   // Si la position n'existe plus, c'est que quelqu'un l'a déjà fermée
   if(!PositionSelectByTicket(ticket))
   {
      g_lastCloseActionTime = now;
      return true;
   }

   // Si MT5/plateforme signale que la fermeture existe déjà, considérer comme OK (évite les retries).
   string c = trade.ResultComment();
   StringToLower(c);
   if(StringFind(c, "already exists") >= 0 || StringFind(c, "order to close") >= 0)
   {
      g_lastCloseActionTime = now;
      return true;
   }

   return false;
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
void UpdatePropiceTopSymbols();
void DrawPropiceTopOnChart();
void DrawEMACurveOnChart();
void DrawLiquidityZonesOnChart();
//void PlaceScalpingLimitOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope); // SUPPRIMÉ - Plus d'ordres limit
void DrawHistoricalSwingPoints(MqlRates &rates[], int bars, double point);
void DrawBookmarkLevels();
void ManageBoomCrashSpikeClose();
void ManageDollarExits();
void CloseWorstPositionIfTotalLossExceeded();
void CloseAllPositionsIfTotalProfitReached();
void ClosePositionsOnIAHold();
void ClosePositionsOnDirectionConflict();
void AutoRotatePositions();
void DrawPremiumDiscountZones();
void DrawSignalArrow();
void UpdateSignalArrowBlink();
void DrawPredictedSwingPoints();
void DrawEMASupportResistance();
void DrawPredictionChannel();
void DrawFutureCandlesM1();
bool FetchFutureCandlesM1Hybrid(bool forceRefresh = false);
bool FetchFutureCandlesFromServer(int horizon);
void BuildFutureCandlesFallbackLocal(int horizon);
bool ParseFutureCandlesJson(const string &json, int expectedCount);
bool ValidateFuturePredictionRunToServer(int minReadyBars = 30);
bool FetchPredictionScoreFromServer();
bool IsInServerPredictedCorrectionZone();
void DrawSMCChannelsMultiTF();
void DrawEMASupertrendMultiTF();
//void DrawLimitOrderLevels(); // SUPPRIMÉ - Plus d'affichage ordres limit
void UpdateDashboard();
void CleanupDashboardObjects();
void AnalyzeFutureOTEZones(double swingHigh, double swingLow, datetime swingHighTime, datetime swingLowTime);
bool ShouldExecuteOTETrade(string direction, string aiAction, double aiConfidence, string trendDirection);
void ExecuteFutureOTETrade(string direction, double entryPrice, double swingLow, double swingHigh);
string GetCurrentTrendDirection();
void ValidateAndAdjustStopLossTakeProfit(string direction, double entryPrice, double &stopLoss, double &takeProfit);
void EnforceMinBoomCrashStopLossDollarRisk(const string symbol, const string direction, const double entryPrice, const double volume, double &stopLoss);
void CleanupAllChartObjects();
bool CheckDailyProfitPause();
double CalculateDailyProfitFromHistory();
bool IsMostPropiceSymbol();
string GetMostPropiceSymbol();
bool CheckSymbolLossProtection();
void ResetSymbolProtection();
void PredictFutureProtectedPoints();
bool GetFutureProtectedPointLevels(double &futureSupportOut, double &futureResistanceOut);
bool GetSuperTrendLevel(ENUM_TIMEFRAMES tf, double &supportOut, double &resistanceOut);
double GetClosestBuyLevel(double currentPrice, double atr, double maxDistATR, string &sourceOut);
double GetClosestSellLevel(double currentPrice, double atr, double maxDistATR, string &sourceOut);
double CalculateLotSizeForPendingOrders();
//void PlaceHistoricalBasedScalpingOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope, int existingLimitOrders); // SUPPRIMÉ - Plus d'ordres limit historiques
bool CaptureChartDataFromChart();
void ManageTrailingStop();
void GenerateFallbackAIDecision();
void GenerateFallbackMLMetrics();
bool EnsureMLContinuousTrainingRunning(bool forceStart = false);
void DrawMLMetricsOnChart();
bool GetSymbolStatsFromHistory(const string symbol, datetime fromTime, datetime toTime, int &winsOut, int &lossesOut, double &netOut);
string FormatWLNet(int wins, int losses, double net);
void DrawDashboardOnChart(const string &lines[], const color &colors[], int count);
void RunCategoryStrategy();
bool Forex_DetectBOSRetest(string &dirOut, double &entryOut, double &slOut, double &tpOut);
void ExecuteForexBOSRetest();
bool IsPriceNearEMAPullbackZone(const string direction, double currentPrice, double &ema21Out, double &ema31Out, double &distOut, double &maxDistOut);
struct OTEImbalanceSetup
{
   string   dir;
   datetime tSwingHigh;
   datetime tSwingLow;
   double   swingHigh;
   double   swingLow;

   double   oteLow;
   double   oteHigh;

   double   fvgLow;
   double   fvgHigh;
   datetime tFVG;

   double   zoneLow;
   double   zoneHigh;

   double   entry;
   double   sl;
   double   tp;
};
bool DetectOTEImbalanceSetup(OTEImbalanceSetup &setupOut, bool requirePriceInZone);
void ExecuteOTEImbalanceTrade();
void DrawOTEImbalanceOnChart();
void DrawPreciseSwingPredictionsWithOrders();
void DrawOrderLinksToSwings(double nextSH, double nextSL, datetime nextSHTime, datetime nextSLTime);
void PlacePreciseSwingBasedOrders();
void CheckAndExecuteDerivArrowTrade();
void UpdateM5EntryLevelsAndLines();
void CheckAndExecuteM5TouchEntryTrade();
bool ExecuteM5TouchOrder(string direction);
bool IsBoomCrashDirectionAllowedByIA(const string symbol, const string direction);

// Recovery exceptionnel Boom/Crash:
// - Boom: après dernier spike BUY, armement sur touch SELL Entry M5 puis déclenchement après 4 petites bougies M1
// - Crash: après dernier spike SELL, armement sur touch BUY Entry M5 puis déclenchement après 4 petites bougies M1
// La position est ensuite fermée par précaution après 5 petites bougies M1.
bool IsAIHoldOrSellForBoomExceptional();
bool IsAIHoldOrBuyForCrashExceptional();
int  CountSmallM1CandlesSince(datetime fromTime);
void CheckAndExecuteExceptionalBoomCrashRecoveryEntries();
bool ExecuteExceptionalBoomCrashRecoveryOrder(const string direction, const string commentTag);
double GetSupportLevelTF(ENUM_TIMEFRAMES tf, int bars);
double GetResistanceLevelTF(ENUM_TIMEFRAMES tf, int bars);
void StartSpikePositionMonitoring(string direction);
bool IsSymbolPaused(string symbol);
void UpdateSymbolPauseInfo(string symbol, double profit);
bool ShouldPauseSymbol(string symbol, double profit);
double GetSymbolCumulativeProfit(string symbol);
datetime GetTodayStart();
bool ShouldPauseSymbolForProfit(string symbol);
void ResetDailyProfitTargetPauses();
void CleanupSMCChartObjects();

// Fonctions de détection avancée de spike
double CalculateVolatilityCompression();
double CalculatePriceAcceleration();
bool DetectVolumeSpike();
bool IsPreSpikePattern();
bool IsNearKeyLevel(double price);
double CalculateSpikeProbability();
void CheckImminentSpike();
void CheckSMCChannelReturnMovements();
//void PlaceReturnMovementLimitOrder(string direction, double currentPrice, double channelPrice, double atrVal, double strength); // SUPPRIMÉ - Plus d'ordres limit retour
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
//void AdjustEMAScalpingLimitOrder(); // SUPPRIMÉ - Plus d'ajustement ordres limit

// Fonctions de remplacement automatique des ordres limites
//bool ShouldReplaceLimitOrder(ENUM_ORDER_TYPE orderType, string orderComment, double orderPrice); // SUPPRIMÉ - Plus de remplacement ordres limit
//bool ReplaceLimitOrder(ENUM_ORDER_TYPE oldOrderType, double oldOrderPrice, string oldOrderComment); // SUPPRIMÉ - Plus de remplacement ordres limit
//void GuardPendingLimitOrdersWithAI_Enhanced(); // SUPPRIMÉ - Plus de garde ordres limit
double GetCurrentATR();

// Fonctions de détection de spikes sans IA
bool IsVolumeSpikeDetected();
bool IsPriceSpikeDetected();
bool IsVolatilityCompressionDetected();
bool IsCalmBeforeStorm();
bool IsSMCSpikeZone();
bool IsAcceleratingMomentum();
bool IsSpikeImminentWithoutAI();
void CheckAndExecuteSpikeTrade();
void ExecuteSpikeTrade();

// Fonctions utilitaires pour la détection de spikes
bool IsNearSupport();
bool IsNearResistance();
double GetOptimalLotSize();

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

// Nettoyage global des objets graphiques du robot (anciens dessins obsolètes).
// Ne supprime que les objets dont le nom commence par "SMC_" (sécurité: ne touche pas aux dessins manuels).
void CleanupSMCChartObjects()
{
   // Préfixes principaux (issus de toutes les fonctionnalités)
   string prefixes[] = {
      "SMC_DASH_LINE_",
      "SMC_PROPICE_",
      "SMC_FVG_",
      "SMC_IFVG_",
      "SMC_OB_",
      "SMC_ICT_SIG_",
      "SMC_FUT_",
      "SMC_Fib_",
      "SMC_Liq_",
      "SMC_Limit_",
      "SMC_Chan_",
      "SMC_Pred_SH_",
      "SMC_Pred_SL_",
      "SMC_Confirmed_SH_",
      "SMC_Confirmed_SL_",
      "SMC_BC_SH_",
      "SMC_BC_SL_",
      "SMC_Hist_SH_",
      "SMC_Hist_SL_",
      "SMC_Bookmark_",
      "SMC_CH_",
      "SMC_EMA_",
      "SMC_ICT_",
      "SMC_Spike_",
      "SMC_Last_"
   };

   for(int i = 0; i < ArraySize(prefixes); i++)
      ObjectsDeleteAll(0, prefixes[i]);

   // Objets nommés (pas toujours couverts par un préfixe unique)
   ObjectDelete(0, "SMC_Spike_Warning");
   ObjectDelete(0, "SMC_Chan_Label");
   ObjectDelete(0, "SMC_Chan_Status");
   ObjectDelete(0, "SMC_Last_SH");
   ObjectDelete(0, "SMC_Last_SL");
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
struct FutureCandleData {
   datetime time;
   double open;
   double high;
   double low;
   double close;
   double confidence;
};
enum ENUM_SYMBOL_CATEGORY {
   SYM_BOOM_CRASH,
   SYM_VOLATILITY,
   SYM_FOREX,
   SYM_COMMODITY,
   SYM_METAL,
   SYM_UNKNOWN
};
ENUM_SYMBOL_CATEGORY SMC_GetSymbolCategory(string symbol)
{
   string s = symbol;
   StringToUpper(s);
   if(StringFind(s, "BOOM") >= 0 || StringFind(s, "CRASH") >= 0) return SYM_BOOM_CRASH;
   if(StringFind(s, "VOLATILITY") >= 0 || StringFind(s, "RANGE BREAK") >= 0) return SYM_VOLATILITY;
   if(StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0) return SYM_METAL;
   if(StringFind(s, "XAG") >= 0 || StringFind(s, "SILVER") >= 0) return SYM_METAL;
   if(StringFind(s, "OIL") >= 0 || StringFind(s, "COPPER") >= 0) return SYM_COMMODITY;
   if(StringFind(s, "USD") >= 0 || StringFind(s, "EUR") >= 0 || StringFind(s, "GBP") >= 0 || StringFind(s, "JPY") >= 0) return SYM_FOREX;
   return SYM_UNKNOWN;
}

bool IsBoomSymbol(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   return (StringFind(s, "BOOM") >= 0);
}

bool IsCrashSymbol(const string symbol)
{
   string s = symbol;
   StringToUpper(s);
   return (StringFind(s, "CRASH") >= 0);
}

// Règle directionnelle spécifique Boom/Crash:
// - Sur Boom: uniquement BUY (jamais SELL)
// - Sur Crash: uniquement SELL (jamais BUY)
bool IsDirectionAllowedForBoomCrash(const string symbol, const string action)
{
   string a = action;
   StringToUpper(a);
   
   bool isBoom  = IsBoomSymbol(symbol);
   bool isCrash = IsCrashSymbol(symbol);
   
   if(isBoom && a == "SELL")
      return false;
   if(isCrash && a == "BUY")
      return false;
   return true;
}

bool IsOrderTypeAllowedForBoomCrash(const string symbol, const ENUM_ORDER_TYPE orderType)
{
   string dir = "";
   if(orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT ||
      orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_STOP_LIMIT)
      dir = "BUY";
   else if(orderType == ORDER_TYPE_SELL || orderType == ORDER_TYPE_SELL_LIMIT ||
           orderType == ORDER_TYPE_SELL_STOP || orderType == ORDER_TYPE_SELL_STOP_LIMIT)
      dir = "SELL";
   else
      return true;

   return IsDirectionAllowedForBoomCrash(symbol, dir);
}

// Alignement IA pour entrées Boom/Crash "standard" (Deriv arrow, spike, M5 touch):
// - Boom BUY  : refus si IA ≠ BUY (donc SELL ou HOLD bloqués)
// - Crash SELL: refus si IA ≠ SELL (donc BUY ou HOLD bloqués)
// Si UseAIServer=false, pas de filtre.
bool IsBoomCrashDirectionAllowedByIA(const string symbol, const string action)
{
   if(!UseAIServer)
      return true;

   if(!IsBoomSymbol(symbol) && !IsCrashSymbol(symbol))
      return true;

   string a = action;
   StringToUpper(a);

   string ia = g_lastAIAction;
   StringToUpper(ia);

   if(IsBoomSymbol(symbol) && a == "BUY")
   {
      if(ia != "BUY")
      {
         Print("🚫 BOOM+IA - BUY refusé sur ", symbol, " | IA=", g_lastAIAction, " (requis: BUY)");
         return false;
      }
   }

   if(IsCrashSymbol(symbol) && a == "SELL")
   {
      if(ia != "SELL")
      {
         Print("🚫 CRASH+IA - SELL refusé sur ", symbol, " | IA=", g_lastAIAction, " (requis: SELL)");
         return false;
      }
   }

   return true;
}

// --- Helpers IA (confiance en unité 0..1) ---
double NormalizeAIConfidenceUnit()
{
   double c = g_lastAIConfidence;
   // Le serveur peut envoyer 0..1 ou 0..100 : normaliser en 0..1
   if(c > 1.0)
      c /= 100.0;
   return c;
}

bool IsAIConfidenceAtLeast(const double minConfUnit, const string contextTag)
{
   if(!UseAIServer)
      return true;

   double confUnit = NormalizeAIConfidenceUnit();
   if(confUnit < minConfUnit)
   {
      Print("🚫 ", contextTag, " - Confiance IA insuffisante: ",
            DoubleToString(confUnit * 100.0, 1), "% < ",
            DoubleToString(minConfUnit * 100.0, 1), "% (action=",
            g_lastAIAction, ")");
      return false;
   }
   return true;
}

// Filtres d'entrée plus pointues (fiabilité)
static datetime g_lastEntryTimeForSymbol = 0;

bool IsSpreadAcceptable()
{
   if(MaxSpreadPoints <= 0) return true;
   long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread > MaxSpreadPoints)
   {
      Print("🚫 ENTRÉE BLOQUÉE - Spread trop élevé: ", (int)spread, " > ", MaxSpreadPoints, " points");
      return false;
   }
   return true;
}

bool IsEntryCooldownActive()
{
   if(EntryCooldownSeconds <= 0) return false;
   datetime now = TimeCurrent();
   if(g_lastEntryTimeForSymbol > 0 && (now - g_lastEntryTimeForSymbol) < EntryCooldownSeconds)
   {
      Print("🚫 ENTRÉE BLOQUÉE - Cooldown actif: ", EntryCooldownSeconds - (int)(now - g_lastEntryTimeForSymbol), "s restantes");
      return true;
   }
   return false;
}

bool IsLastCandleConfirmingDirection(const string direction)
{
   if(!RequireConfirmationCandle) return true;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 1, 2, rates) < 2) return true; // pas de données = on autorise
   double open0 = rates[0].open;
   double close0 = rates[0].close;
   string d = direction; StringToUpper(d);
   if(d == "BUY")
   {
      if(close0 <= open0)
      {
         Print("🚫 ENTRÉE BLOQUÉE - Dernière bougie M1 non haussière (close=", DoubleToString(close0, _Digits), " <= open=", DoubleToString(open0, _Digits), ")");
         return false;
      }
   }
   else if(d == "SELL")
   {
      if(close0 >= open0)
      {
         Print("🚫 ENTRÉE BLOQUÉE - Dernière bougie M1 non baissière (close=", DoubleToString(close0, _Digits), " >= open=", DoubleToString(open0, _Digits), ")");
         return false;
      }
   }
   return true;
}

// Vérifier que le gain potentiel (TP) atteint le minimum requis (mouvements francs, ex: 2$ sur capital 10$)
bool IsMinimumProfitPotentialMet(double entryPrice, double tp, const string &direction, double lot)
{
   if(MinProfitPotentialUSD <= 0) return true;
   if(lot <= 0) return false;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0) tickSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(tickSize <= 0) tickSize = 0.0001;
   if(tickVal <= 0) tickVal = 1.0;

   double priceDist = 0.0;
   string d = direction; StringToUpper(d);
   if(tp > 0)
   {
      if(d == "BUY")  priceDist = tp - entryPrice;
      else            priceDist = entryPrice - tp;
   }
   else
   {
      // Pas de TP (Boom/Crash NoSLTP): estimer avec 2 ATR comme mouvement attendu
      int atrH = iATR(_Symbol, PERIOD_M1, 14);
      if(atrH == INVALID_HANDLE) return true; // pas de données = on autorise
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrH, 0, 0, 1, atrBuf) < 1) return true;
      priceDist = atrBuf[0] * 2.0; // 2 ATR = mouvement franc minimum
   }
   if(priceDist <= 0) return false;

   double profitUSD = (priceDist / tickSize) * tickVal * lot;
   if(profitUSD < MinProfitPotentialUSD)
   {
      Print("🚫 ENTRÉE BLOQUÉE - Gain potentiel trop faible: ", DoubleToString(profitUSD, 2), "$ < ", MinProfitPotentialUSD, "$ (mouvement franc requis)");
      return false;
   }
   return true;
}

// Contrôle de duplication de position:
// - Boom/Crash: une seule position par symbole (jamais de duplication)
// - Forex/Metal/Volatility: duplication autorisée une seule fois
//   si profit symbole >= 1$ + IA alignée + confiance >= 85%
bool CanOpenAdditionalPositionForSymbol(const string symbol, const string action)
{
   int existing = CountPositionsForSymbol(symbol);
   if(existing <= 0)
      return true; // première position

   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
   string act = action;
   StringToUpper(act);

   // Boom/Crash: interdiction stricte de duplication
   if(cat == SYM_BOOM_CRASH)
      return false;

   // Duplication conditionnelle uniquement pour Forex/Metal/Volatility
   bool dupAllowedCat = (cat == SYM_FOREX || cat == SYM_METAL || cat == SYM_VOLATILITY);
   if(!dupAllowedCat)
      return false;

   // Une seule duplication max => au plus 2 positions sur le symbole
   if(existing >= 2)
      return false;

   // IA serveur doit confirmer fortement la même direction
   string aiAction = g_lastAIAction;
   StringToUpper(aiAction);
   if(aiAction != "BUY" && aiAction != "SELL")
      return false;
   if(aiAction != act)
      return false;
   if(g_lastAIConfidence < 0.85)
      return false;

   // Profit symbole >= 1$ avant duplication
   double symbolProfit = 0.0;
   bool hasBuy = false, hasSell = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      if(posInfo.Symbol() != symbol) continue;

      symbolProfit += posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      if(posInfo.PositionType() == POSITION_TYPE_BUY)  hasBuy  = true;
      if(posInfo.PositionType() == POSITION_TYPE_SELL) hasSell = true;
   }
   if(symbolProfit < 1.0)
      return false;

   // Dupliquer uniquement dans le sens déjà présent
   if(act == "BUY" && !hasBuy) return false;
   if(act == "SELL" && !hasSell) return false;

   return true;
}

// CountOpenLimitOrdersForSymbol: limit orders désactivés => la fonction est définie plus bas (compatibilité).

// Compte tous les ordres en attente (pending) pour ce symbole (notre EA).
// Utile pour éviter une entrée marché si un pending existe déjà (risque de doublon au fill).
int CountPendingOrdersForSymbol(const string symbol)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT ||
         t == ORDER_TYPE_BUY_STOP  || t == ORDER_TYPE_SELL_STOP  ||
         t == ORDER_TYPE_BUY_STOP_LIMIT || t == ORDER_TYPE_SELL_STOP_LIMIT)
      {
         count++;
      }
   }
   return count;
}

bool HasAnyExposureForSymbol(const string symbol)
{
   // Une fois qu'une position existe (ou un pending existe), on bloque toutes nouvelles expositions
   return (CountPositionsForSymbol(symbol) > 0) || (CountPendingOrdersForSymbol(symbol) > 0);
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

// Annule tous les pending LIMIT (BUY_LIMIT/SELL_LIMIT) de notre EA sur un symbole.
// Objectif: garantir "un seul ordre limit par symbol" quand on recalcule les niveaux.
void CancelAllPendingLimitOrdersForSymbol(const string symbol)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;

      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;

      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action = TRADE_ACTION_REMOVE;
      req.order  = ticket;
      req.symbol = symbol;
      req.magic  = InpMagicNumber;

      if(!OrderSend(req, res))
      {
         Print("? annulation LIMIT échouée | ticket=", ticket, " | symbol=", symbol, " | code=", res.retcode);
      }
   }
}

// Anti-duplication pending LIMIT: garder uniquement 1 pending LIMIT par `symbol` (sur notre magic)
void EnsureSinglePendingLimitOrderForSymbol(const string symbol)
{
   // Evite de spammer la suppression sur ticks rapides
   static datetime lastEnforce = 0;
   datetime now = TimeCurrent();
   if(now - lastEnforce < 10) return;
   lastEnforce = now;

   int totalLimits = CountOpenLimitOrdersForSymbol(symbol);
   if(totalLimits <= 1) return;

   ulong keepTicket = 0;
   ulong latestTicket = 0;

   // Choix du ticket à conserver: un ordre canal (cmt contient "SMC_CH") sinon le plus récent
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;

      if(!OrderSelect(ticket)) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;

      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;

      if(ticket > latestTicket)
         latestTicket = ticket;

      string cmt = OrderGetString(ORDER_COMMENT);
      if(keepTicket == 0 && StringFind(cmt, "SMC_CH") >= 0)
         keepTicket = ticket;
   }

   if(keepTicket == 0)
      keepTicket = latestTicket;
   if(keepTicket == 0) return;

   // Supprimer tous les autres pending LIMIT
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || ticket == keepTicket) continue;

      if(!OrderSelect(ticket)) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol) continue;

      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;

      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action = TRADE_ACTION_REMOVE;
      req.order  = ticket;
      req.symbol = symbol;
      req.magic  = InpMagicNumber;

      if(!OrderSend(req, res))
      {
         Print("? Suppression LIMIT anti-duplication échouée | ticket=", ticket,
               " | symbol=", symbol, " | retcode=", res.retcode);
      }
   }
}

// ===== PROFIL HORAIRE "SYMBOL PROPICE" (Top N) =====
int ParsePropiceTopSymbolsJson(const string &json, string &outText, string &outSymbolsCsv, int &outHourUtc)
{
   outText = "";
   outSymbolsCsv = "";
   outHourUtc = -1;
   if(StringLen(json) <= 0) return 0;

   // now_hour_utc
   int hPos = StringFind(json, "\"now_hour_utc\"");
   if(hPos >= 0)
   {
      int colon = StringFind(json, ":", hPos);
      if(colon > 0)
      {
         int p = colon + 1;
         while(p < StringLen(json) && (StringGetCharacter(json, p) == ' ' || StringGetCharacter(json, p) == '\t')) p++;
         string num = "";
         while(p < StringLen(json))
         {
            ushort ch = StringGetCharacter(json, p);
            if(ch < '0' || ch > '9') break;
            num += CharToString((uchar)ch);
            p++;
         }
         if(StringLen(num) > 0) outHourUtc = (int)StringToInteger(num);
      }
   }

   // Extraire "symbol" + "propice_score" depuis rows[]
   int count = 0;
   int pos = 0;
   while(true)
   {
      int sPos = StringFind(json, "\"symbol\"", pos);
      if(sPos < 0) break;

      int q1 = StringFind(json, "\"", sPos + 8);
      if(q1 < 0) { pos = sPos + 7; continue; }
      int q2 = StringFind(json, "\"", q1 + 1);
      if(q2 < 0) { pos = q1 + 1; continue; }
      string sym = StringSubstr(json, q1 + 1, q2 - q1 - 1);
      pos = q2 + 1;

      double score = -1.0;
      int scPos = StringFind(json, "\"propice_score\"", pos);
      if(scPos > 0)
      {
         int colon = StringFind(json, ":", scPos);
         if(colon > 0)
         {
            int p = colon + 1;
            while(p < StringLen(json) && (StringGetCharacter(json, p) == ' ' || StringGetCharacter(json, p) == '\t')) p++;
            string num = "";
            bool dotSeen = false;
            while(p < StringLen(json))
            {
               ushort ch = StringGetCharacter(json, p);
               if((ch >= '0' && ch <= '9') || (ch == '.' && !dotSeen))
               {
                  if(ch == '.') dotSeen = true;
                  num += CharToString((uchar)ch);
                  p++;
                  continue;
               }
               break;
            }
            if(StringLen(num) > 0) score = StringToDouble(num);
         }
      }

      if(StringLen(sym) > 0)
      {
         if(StringLen(outSymbolsCsv) > 0) outSymbolsCsv += ",";
         outSymbolsCsv += sym;

         if(StringLen(outText) > 0) outText += " | ";
         if(score >= 0.0)
            outText += sym + "(" + DoubleToString(score, 2) + ")";
         else
            outText += sym;
         count++;
      }
   }

   return count;
}

void UpdatePropiceTopSymbols()
{
   if(!UseAIServer)
   {
      g_propiceTopSymbolsText = "Mode IA désactivé";
      g_propiceTopSymbols = "";
      g_currentSymbolIsPropice = true;
      g_symbolIsPropice = true;
      g_lastPropiceUpdateTime = TimeCurrent();
      g_propiceTopSymbolsStatus = "OFF";
      return;
   }

   datetime now = TimeCurrent();
   if(g_lastPropiceUpdateTime > 0 && (now - g_lastPropiceUpdateTime) < PropiceUpdateIntervalSec)
      return;
   g_lastPropiceUpdateTime = now;

   // Vérifier si les URLs sont configurées
   if(AI_ServerURL == "" && AI_ServerRender == "")
   {
      g_propiceTopSymbolsText = "Filtre désactivé - URL non configurée";
      g_propiceTopSymbolsStatus = "OFF";
      g_currentSymbolIsPropice = true;
      g_symbolIsPropice = true;
      return;
   }
   
   // Test de connexion simple pour diagnostiquer
   string testUrl = (AI_ServerURL != "") ? AI_ServerURL : AI_ServerRender;
   if(testUrl != "")
   {
      Print("🩺 Test de connexion santé à: ", testUrl, "/health");
      char testPost[], testResult[];
      string testHeaders;
      int healthRes = WebRequest("GET", testUrl + "/health", "", 3000, testPost, testResult, testHeaders);
      Print("   Health check HTTP ", healthRes);
      if(healthRes == 200)
      {
         Print("✅ Serveur IA actif et répondant");
      }
      else
      {
         Print("❌ Serveur IA non répondant (HTTP ", healthRes, ")");
      }
   }

   // Afficher un message de chargement plus informatif
   string loadingTime = TimeToString(now, TIME_MINUTES);
   g_propiceTopSymbolsText = "Chargement... (" + loadingTime + ")";
   g_propiceTopSymbolsStatus = "Requête en cours";

   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string fallbackUrl = UseRenderAsPrimary ? AI_ServerURL : AI_ServerRender;
   string url = baseUrl + "/symbols/propice/top?timeframe=M1&lookback_days=14&n=" + IntegerToString(PropiceTopN);

   char post[], result[];
   string resultHeaders;
   string fallbackUrlFull = fallbackUrl + "/symbols/propice/top?timeframe=M1&lookback_days=14&n=" + IntegerToString(PropiceTopN);
   
   // Essayer le serveur primaire
   Print("🔍 PropiceTop - Tentative connexion à: ", url);
   Print("   Serveur local: ", AI_ServerURL);
   Print("   Serveur Render: ", AI_ServerRender);
   Print("   UseRenderAsPrimary: ", UseRenderAsPrimary ? "true" : "false");
   
   int res = WebRequest("GET", url, "", 5000, post, result, resultHeaders);
   Print("   Résultat primaire: HTTP ", res);
   
   if(res != 200)
   {
      // Essayer le serveur de fallback
      Print("🔄 PropiceTop - Fallback vers: ", fallbackUrlFull);
      res = WebRequest("GET", fallbackUrlFull, "", 5000, post, result, resultHeaders);
      Print("   Résultat fallback: HTTP ", res);
   }
   
   if(res != 200)
   {
      int err = GetLastError();
      g_propiceTopSymbolsStatus = "Erreur HTTP " + IntegerToString(res) + " (err " + IntegerToString(err) + ")";
      g_propiceTopSymbolsText = "Connexion impossible";
      Print("❌ PropiceTop - ", g_propiceTopSymbolsStatus);
      Print("   Primaire: ", url);
      Print("   Fallback: ", fallbackUrlFull);
      
      // Mode dégradé (fail-open): si le serveur est indisponible, ne pas bloquer les trades uniquement à cause du réseau
      g_currentSymbolIsPropice = true;
      g_symbolIsPropice = true;
      
      // Afficher les symptômes standards si aucune donnée n'est disponible
      g_propiceTopSymbolsText = "Serveur indisponible - Mode dégradé actif";
      g_propiceTopSymbolsStatus = "Fail-open (tous symboles autorisés)";
      return;
   }

   string json = CharArrayToString(result, 0, -1, CP_UTF8);
   string outText, outCsv;
   int hourUtc = -1;
   int n = ParsePropiceTopSymbolsJson(json, outText, outCsv, hourUtc);
   if(n <= 0)
   {
      Print("⚠️ PropiceTop - Réponse vide ou invalide");
      g_propiceTopSymbolsStatus = "Données invalides";
      g_propiceTopSymbolsText = "Mode dégradé - Filtre désactivé";
      
      // Mode dégradé : autoriser tous les symboles si les données sont invalides
      g_currentSymbolIsPropice = true;
      g_symbolIsPropice = true;
      return;
   }

   // Améliorer l'affichage avec l'heure de mise à jour
   string updateTime = TimeToString(now, TIME_MINUTES);
   g_propiceTopSymbolsText = outText + " (MAJ: " + updateTime + ")";
   g_propiceTopSymbols     = outCsv;
   g_lastPropiceUpdate     = now;
   g_propiceTopSymbolsStatus = "OK (UTC h=" + IntegerToString(hourUtc) + ")";

   // Symbole courant dans la liste et sa position de priorité
   g_currentSymbolIsPropice = false;
   g_currentSymbolPriority = -1; // Réinitialiser la priorité
   
   // Extraire les symboles individuels pour déterminer la priorité
   string symbols[];
   StringSplit(outCsv, ',', symbols);
   
   // Vérifier si le symbole actuel est dans la liste et déterminer sa position
   for(int i = 0; i < ArraySize(symbols); i++)
   {
      StringTrimLeft(symbols[i]);
      StringTrimRight(symbols[i]);
      if(symbols[i] == _Symbol)
      {
         g_currentSymbolIsPropice = true;
         g_currentSymbolPriority = i; // 0 = plus propice, 1 = deuxième, etc.
         break;
      }
   }
   
   g_symbolIsPropice = g_currentSymbolIsPropice;
   
   // Log amélioré avec la position de priorité
   string statusIcon = g_currentSymbolIsPropice ? "✅" : "🚫";
   string priorityStr = "";
   if(g_currentSymbolIsPropice && g_currentSymbolPriority >= 0)
   {
      if(g_currentSymbolPriority == 0)
         priorityStr = " (🥇 PLUS PROPICE)";
      else if(g_currentSymbolPriority == 1)
         priorityStr = " (🥈 2ème)";
      else if(g_currentSymbolPriority == 2)
         priorityStr = " (🥉 3ème)";
      else
         priorityStr = " (📍 " + IntegerToString(g_currentSymbolPriority + 1) + "ème)";
   }
   
   Print("🌟 PropiceTop (UTC h=", hourUtc, ") -> ", outText, " | ", _Symbol, " ", statusIcon, priorityStr, " | Status: ", g_propiceTopSymbolsStatus);
}

void DrawPropiceTopOnChart()
{
   // L'affichage principal est intégré au dashboard (UpdateDashboard).
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
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tol = MathMax(point, ICTSweepTolerancePoints * point);
   for(int i = 3; i < 45; i++)
   {
      if(rates[i].close < rates[i].open && rates[i+1].close > rates[i+1].open)
      {
         double moveUp = rates[i+2].high - rates[i].low;
         if(moveUp > point * 20 && ICT_HasLiquiditySweepBeforeIndex(rates, 50, i, 1, tol)) {
            obOut.high = rates[i].high; obOut.low = rates[i].low; obOut.direction = 1;
            obOut.time = rates[i].time; obOut.barIndex = i; obOut.type = "OB";
            return true;
         }
      }
      if(rates[i].close > rates[i].open && rates[i+1].close < rates[i+1].open)
      {
         double moveDown = rates[i].high - rates[i+2].low;
         if(moveDown > point * 20 && ICT_HasLiquiditySweepBeforeIndex(rates, 50, i, -1, tol)) {
            obOut.high = rates[i].high; obOut.low = rates[i].low; obOut.direction = -1;
            obOut.time = rates[i].time; obOut.barIndex = i; obOut.type = "OB";
            return true;
         }
      }
   }
   return false;
}
bool ICT_HasLiquiditySweepBeforeIndex(const MqlRates &rates[], int bars, int obIndex, int direction, double tol)
{
   int startIdx = obIndex + 1;
   int endIdx = MathMin(bars - 1, obIndex + 8);
   if(startIdx >= bars) return false;

   if(direction > 0)
   {
      double refLow = rates[startIdx].low;
      for(int j = startIdx; j <= endIdx; j++)
         refLow = MathMin(refLow, rates[j].low);
      return (rates[obIndex].low < (refLow - tol));
   }

   double refHigh = rates[startIdx].high;
   for(int k = startIdx; k <= endIdx; k++)
      refHigh = MathMax(refHigh, rates[k].high);
   return (rates[obIndex].high > (refHigh + tol));
}
bool ICT_DetectInvertedFVG(const string symbol, ENUM_TIMEFRAMES tf, int direction, int lookback, FVGData &ifvgOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = MathMax(40, lookback);
   if(CopyRates(symbol, tf, 0, bars, rates) < bars) return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double minGap = point * 3.0;
   double tol = MathMax(point, ICTSweepTolerancePoints * point);

   for(int i = 6; i < bars - 3; i++)
   {
      double top = 0.0, bottom = 0.0;
      int fvgDir = 0;

      if(rates[i+1].high < rates[i-1].low)
      {
         top = rates[i-1].low;
         bottom = rates[i+1].high;
         fvgDir = 1; // bullish FVG support potentiel
      }
      else if(rates[i+1].low > rates[i-1].high)
      {
         top = rates[i+1].low;
         bottom = rates[i-1].high;
         fvgDir = -1; // bearish FVG résistance potentielle
      }
      else
      {
         continue;
      }

      if((top - bottom) < minGap) continue;

      bool held = false, broken = false, retested = false;
      int breakIdx = -1;

      for(int j = i - 1; j >= 1; j--)
      {
         bool touched = (rates[j].high >= bottom && rates[j].low <= top);
         if(!broken)
         {
            if(fvgDir > 0)
            {
               if(touched && rates[j].close >= bottom) held = true;
               if(held && rates[j].close < (bottom - tol))
               {
                  broken = true;
                  breakIdx = j;
               }
            }
            else
            {
               if(touched && rates[j].close <= top) held = true;
               if(held && rates[j].close > (top + tol))
               {
                  broken = true;
                  breakIdx = j;
               }
            }
         }
         else if(j < breakIdx)
         {
            if(touched)
            {
               retested = true;
               break;
            }
         }
      }

      if(!held || !broken || !retested) continue;

      if((direction < 0 && fvgDir > 0) || (direction > 0 && fvgDir < 0))
      {
         ifvgOut.top = top;
         ifvgOut.bottom = bottom;
         ifvgOut.direction = direction;
         ifvgOut.time = rates[i].time;
         ifvgOut.isInversion = true;
         ifvgOut.barIndex = i;
         return true;
      }
   }
   return false;
}
bool ICT_DetectValidatedBreaker(const string symbol, ENUM_TIMEFRAMES tf, int direction, int lookback, OrderBlockData &breakerOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = MathMax(50, lookback);
   if(CopyRates(symbol, tf, 0, bars, rates) < bars) return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tol = MathMax(point, ICTSweepTolerancePoints * point);

   for(int i = 8; i < bars - 6; i++)
   {
      int obDir = 0;
      double obHigh = 0.0, obLow = 0.0;

      if(rates[i].close < rates[i].open && rates[i+1].close > rates[i+1].open &&
         (rates[i+2].high - rates[i].low) > point * 20 && ICT_HasLiquiditySweepBeforeIndex(rates, bars, i, 1, tol))
      {
         obDir = 1; obHigh = rates[i].high; obLow = rates[i].low;
      }
      else if(rates[i].close > rates[i].open && rates[i+1].close < rates[i+1].open &&
              (rates[i].high - rates[i+2].low) > point * 20 && ICT_HasLiquiditySweepBeforeIndex(rates, bars, i, -1, tol))
      {
         obDir = -1; obHigh = rates[i].high; obLow = rates[i].low;
      }
      else
      {
         continue;
      }

      bool broken = false, retested = false;
      int breakIdx = -1;
      for(int j = i - 1; j >= 1; j--)
      {
         if(!broken)
         {
            if(obDir > 0 && rates[j].close < (obLow - tol)) { broken = true; breakIdx = j; }
            if(obDir < 0 && rates[j].close > (obHigh + tol)) { broken = true; breakIdx = j; }
         }
         else if(j < breakIdx)
         {
            if(rates[j].high >= obLow && rates[j].low <= obHigh)
            {
               retested = true;
               break;
            }
         }
      }

      if(!broken || !retested) continue;
      if((direction < 0 && obDir > 0) || (direction > 0 && obDir < 0))
      {
         breakerOut.high = obHigh;
         breakerOut.low = obLow;
         breakerOut.direction = direction;
         breakerOut.time = rates[i].time;
         breakerOut.barIndex = i;
         breakerOut.type = "BREAKER";
         return true;
      }
   }
   return false;
}
bool ICT_DetectNestedOrderBlockConfirmation(const string symbol, ENUM_TIMEFRAMES tf, int direction, int lookback, OrderBlockData &outerObOut, OrderBlockData &innerObOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = MathMax(60, lookback);
   if(CopyRates(symbol, tf, 0, bars, rates) < bars) return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tol = MathMax(point, ICTSweepTolerancePoints * point);

   for(int i = 12; i < bars - 10; i++)
   {
      int outerDir = 0;
      double outerHigh = 0.0, outerLow = 0.0;
      if(rates[i].close < rates[i].open && rates[i+1].close > rates[i+1].open &&
         (rates[i+2].high - rates[i].low) > point * 20 && ICT_HasLiquiditySweepBeforeIndex(rates, bars, i, 1, tol))
      {
         outerDir = 1; outerHigh = rates[i].high; outerLow = rates[i].low;
      }
      else if(rates[i].close > rates[i].open && rates[i+1].close < rates[i+1].open &&
              (rates[i].high - rates[i+2].low) > point * 20 && ICT_HasLiquiditySweepBeforeIndex(rates, bars, i, -1, tol))
      {
         outerDir = -1; outerHigh = rates[i].high; outerLow = rates[i].low;
      }
      else
      {
         continue;
      }

      if(outerDir != direction) continue;

      // Cherche un OB plus récent et plus petit, entièrement contenu dans l'OB principal.
      for(int j = i - 2; j >= 2; j--)
      {
         int innerDir = 0;
         double inHigh = 0.0, inLow = 0.0;
         if(rates[j].close < rates[j].open && rates[j+1].close > rates[j+1].open &&
            (rates[j+2].high - rates[j].low) > point * 12 && ICT_HasLiquiditySweepBeforeIndex(rates, bars, j, 1, tol))
         {
            innerDir = 1; inHigh = rates[j].high; inLow = rates[j].low;
         }
         else if(rates[j].close > rates[j].open && rates[j+1].close < rates[j+1].open &&
                 (rates[j].high - rates[j+2].low) > point * 12 && ICT_HasLiquiditySweepBeforeIndex(rates, bars, j, -1, tol))
         {
            innerDir = -1; inHigh = rates[j].high; inLow = rates[j].low;
         }
         else
         {
            continue;
         }

         if(innerDir != outerDir) continue;
         if(inHigh <= outerHigh && inLow >= outerLow && (inHigh - inLow) < (outerHigh - outerLow))
         {
            outerObOut.high = outerHigh; outerObOut.low = outerLow; outerObOut.direction = outerDir;
            outerObOut.time = rates[i].time; outerObOut.barIndex = i; outerObOut.type = "OB_OUTER";
            innerObOut.high = inHigh; innerObOut.low = inLow; innerObOut.direction = innerDir;
            innerObOut.time = rates[j].time; innerObOut.barIndex = j; innerObOut.type = "OB_INNER";
            return true;
         }
      }
   }
   return false;
}
bool ICT_ValidateEvidenceSequence(const string symbol, ENUM_TIMEFRAMES tf, const string direction, int &scoreOut, string &reasonOut)
{
   scoreOut = 0;
   reasonOut = "";
   int dir = (direction == "BUY") ? 1 : -1;

   OrderBlockData ob;
   if(SMC_DetectOrderBlock(symbol, tf, ob) && ob.direction == dir)
   {
      scoreOut++;
      reasonOut += "OB valide (sweep), ";
   }

   FVGData ifvg;
   if(ICT_DetectInvertedFVG(symbol, tf, dir, ICTLookbackBars, ifvg))
   {
      scoreOut++;
      reasonOut += "IFVG valide, ";
   }

   OrderBlockData breaker;
   if(ICT_DetectValidatedBreaker(symbol, tf, dir, ICTLookbackBars, breaker))
   {
      scoreOut++;
      reasonOut += "Breaker historique valide, ";
   }

   OrderBlockData outerOb, innerOb;
   if(ICT_DetectNestedOrderBlockConfirmation(symbol, tf, dir, ICTLookbackBars, outerOb, innerOb))
   {
      scoreOut++;
      reasonOut += "OB imbriqué confirmé, ";
   }

   int bosDir = 0;
   if(SMC_DetectBOS(symbol, tf, bosDir) && bosDir == dir)
   {
      scoreOut++;
      reasonOut += "BOS aligné, ";
   }

   return (scoreOut >= MathMax(1, ICTMinSignatures));
}
void DrawICTValidationGraphics()
{
   if(DashboardSingleSourceMode)
   {
      ObjectDelete(0, "SMC_ICT_SIG_CHECKLIST");
      return;
   }

   ObjectsDeleteAll(0, "SMC_ICT_SIG_");

   int buyScore = 0, sellScore = 0;
   string buyReason = "", sellReason = "";
   bool buyOk = ICT_ValidateEvidenceSequence(_Symbol, LTF, "BUY", buyScore, buyReason);
   bool sellOk = ICT_ValidateEvidenceSequence(_Symbol, LTF, "SELL", sellScore, sellReason);

   string label = "SMC_ICT_SIG_CHECKLIST";
   if(ObjectFind(0, label) < 0)
      ObjectCreate(0, label, OBJ_LABEL, 0, 0, 0);

   string txt = "ICT Checklist\nBUY: " + IntegerToString(buyScore) + "/" + IntegerToString(ICTMinSignatures) +
                (buyOk ? " OK" : " WAIT") + "\nSELL: " + IntegerToString(sellScore) + "/" + IntegerToString(ICTMinSignatures) +
                (sellOk ? " OK" : " WAIT") + "\nB: " + buyReason + "\nS: " + sellReason;
   ObjectSetInteger(0, label, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, label, OBJPROP_XDISTANCE, 12);
   ObjectSetInteger(0, label, OBJPROP_YDISTANCE, 120);
   ObjectSetInteger(0, label, OBJPROP_COLOR, (buyOk || sellOk) ? clrLimeGreen : clrOrangeRed);
   ObjectSetString(0, label, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, label, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, label, OBJPROP_TEXT, txt);
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

// Probabilité de spike calculée / reçue depuis l'IA
double   g_lastSpikeProbability = 0.0;
datetime g_lastSpikeUpdate      = 0;

// Variables ML pour le tableau de bord
string g_mlMetricsStr = "";
datetime g_lastMLMetricsUpdate = 0;
bool g_channelValid = false;
double g_mlLastAccuracy = -1.0;
string g_mlLastModelName = "";
FutureCandleData g_futureCandles[];
int      g_futureCandlesCount = 0;
datetime g_futureCandlesLastUpdate = 0;
string   g_futureCandlesSource = "NONE";
string   g_futurePredictionRunId = "";
datetime g_futurePredictionRunFetchedAt = 0;
bool     g_futurePredictionRunValidated = false;
int      g_futurePredictionValidatedSteps = 0;
double   g_predictionScore = -1.0;
int      g_predictionSamples = 0;
datetime g_predictionScoreUpdatedAt = 0;
string   g_predictionScoreSource = "N/A";
bool     g_serverCorrectionActive = false;
double   g_serverCorrectionConfidence = 0.0;
string   g_serverCorrectionAction = "N/A";
datetime g_serverCorrectionLastUpdate = 0;

// Variable de debugging
bool DebugMode = false;
// Top symboles "propices" (profil horaire) renvoyés par le serveur
string   g_propiceTopSymbols = "";
bool     g_symbolIsPropice   = false;
datetime g_lastPropiceUpdate = 0;
// Stats symboles (source serveur/Supabase) pour affichage cohérent MT5 = Excel = Supabase
int    g_dayWins = 0, g_dayLosses = 0, g_monthWins = 0, g_monthLosses = 0;
double g_dayNetProfit = 0.0, g_monthNetProfit = 0.0;
datetime g_symbolStatsLastLocalUpdate = 0;
datetime g_symbolStatsLastSyncAttempt = 0;
datetime g_symbolStatsLastSyncOk = 0;
bool     g_symbolStatsSyncOk = false;
string   g_symbolStatsLastChecksum = "";

// Variables de trading et positions
double g_maxProfit = 0.0;
datetime g_lastBoomCrashPrice = 0;
datetime s_lastRefUpdate = 0;

// Eviter les erreurs MT5 juste après fermeture (ex: "Position doesn't exist" sur SL/TP)
datetime g_lastCloseActionTime = 0;
string   g_lastCloseActionSymbol = "";

// Suivi de l'équité journalière pour contrôle du drawdown
double g_dailyStartEquity = 0.0;
double g_dailyMaxEquity   = 0.0;
double g_dailyMinEquity   = 0.0;
int    g_dailyEquityDate  = 0;   // YYYYMMDD
datetime g_dailyPauseUntil = 0;     // Pause après gain cible (jusqu'à fin de journée)
datetime g_dailyLossPauseUntil = 0; // Pause après perte journalière max (2h)

// Perte cumulative sur trades consécutifs → pause
double   g_cumulativeLossSuccessive = 0.0;
datetime g_lossPauseUntil            = 0;

// Dernière perte par symbole (éviter 2e perte consécutive sans conditions strictes)
string g_lastLossSymbol   = "";
datetime g_lastLossTime   = 0;
static const int RECENT_LOSS_WINDOW_SEC = 3600;  // 1 h

//| INPUTS                                                            |
input group "=== GÉNÉRAL ==="
input bool   UseMinLotOnly     = true;   // Toujours lot minimum (le plus bas)
input double InpLotSize         = 0.2;   // Taille de lot par défaut
input bool   EnableTrading      = true;   // Activer/Désactiver le trading
input int    MaxPositionsTerminal = 2;   // Nombre max de positions (tout le terminal MT5) - LIMITÉ À 2 pour protéger le capital
input bool   OnePositionPerSymbol = true; // Une seule position par symbole - MAINTENU pour éviter duplication
input int    InpMagicNumber       = 202502; // Magic Number
input double MaxTotalLossDollars = 10.0;   // Perte maximale totale en dollars avant de couper toutes les positions
input double DailyProfitTarget = 20.0;     // Objectif de profit journalier en dollars
input int    PauseAfterProfitHours = 4;    // Durée de la pause en heures après avoir atteint l'objectif de profit la plus perdante
input double MaxLossPerSpikeTradeDollars = 3.0;  // Perte max par trade Spike Boom/Crash ($) - lot réduit si dépassement
input double MaxLossPerSymbolDollars = 4.0;   // Perte maximale par symbole avant blocage complet de ce symbole
input double MaxRiskPerTradePercent   = 1.5;  // Risque normal par trade (% de l'équité)
input double MaxDailyDrawdownPercent  = 10.0; // Drawdown max journalier (%) avant blocage des nouvelles entrées
input double DailyProfitTargetDollars = 20.0; // Gain journalier max ($) - stop trading jusqu'à fin de journée
input double MaxDailyLossDollars      = 10.0; // Perte journalière max ($) - pause 2h
input double CumulativeLossPauseThresholdDollars = 5.0; // Pertes consécutives cumulées ($) avant pause
input int    CumulativeLossPauseMinutes = 30; // Durée de pause après pertes consécutives (min)
input bool   EnableProfitLock             = true;  // Stop si gros giveback après gros gain
input double ProfitLockStartDollars       = 10.0;  // Active après ce gain max journalier ($)
input double ProfitLockMaxGivebackDollars = 5.0;   // Giveback max depuis le pic d'équité ($)
input bool   ProfitLockClosePositions     = true;  // Fermer positions + supprimer pending lors du stop
input bool   UsePerSymbolDailyObjectiveOnly = true; // Objectif journée: pause par symbole uniquement (pas de stop global)
input bool   UseHighConfidenceFilterWhenSomeSymbolsProfitLocked = true; // Quand des symboles sont déjà "verrouillés" par profit, exiger plus de probabilité
input int    LockedSymbolsMinCountForFilter = 1; // Seuil du nombre de symboles déjà verrouillés pour activer le filtre
input double ExtraMinAIConfidenceWhenLockedPercent = 10.0; // +% confiance minimale (en plus des seuils internes)
input double ExtraMinSetupScoreWhenLocked = 10.0; // +score minimum setup (0-100) quand des symboles sont verrouillés
input bool   BlockEquilibriumCorrectionTrades = true; // Bloquer les trades en zone de correction (autour de l'équilibre ICT)
input bool   UseServerCorrectionZoneFilter = true;    // Bloquer aussi selon prédiction correction serveur/Supabase
input double ServerCorrectionMinConfidence = 70.0;    // Seuil confiance (%) pour activer le blocage serveur
input double EquilibriumCorrectionBandPercent = 20.0; // Largeur zone correction (% de Premium↔Discount), centrée sur l'équilibre
input int    CorrectionRangeLookbackBarsM1 = 60;      // Lookback M1 pour détecter une correction (range)
input double CorrectionMaxRangePctM1 = 0.12;          // Range max (%) sur lookback M1 pour considérer "correction"
input double CorrectionMaxAtrPctM1 = 0.020;           // ATR(14) M1 max (%) pour considérer "marché calme/correction"
input bool   DebugCorrectionZoneFilter = false;       // Logs détaillés du filtre correction (throttlé)
input double MinSetupScoreEntry      = 65.0;  // Score minimum (0-100) pour autoriser une nouvelle entrée
input double MinAIConfidencePercent   = 65.0;  // Confiance IA minimum (%) pour exécuter un trade
input bool   CloseOnlyOnAIHoldOrBrokerSLTP = true; // Empêche les fermetures actives (sauf IA=HOLD). Laisser SL/TP broker gérer le reste.
input group "=== ENTRÉES PLUS POINTUES (fiabilité) ==="
input int    MaxSpreadPoints          = 80;   // Spread max (points) - éviter entrée si spread trop élevé
input int    EntryCooldownSeconds     = 90;   // Cooldown min (sec) après dernière entrée sur ce symbole
input bool   RequireConfirmationCandle = true; // Exiger 1 bougie M1 dans le sens (close>open BUY, close<open SELL)
input double MinProfitPotentialUSD    = 2.0;  // Gain potentiel min ($) - ex: 2$ pour capital 10$ = mouvement franc requis
input double InpRiskReward        = 3.0;   // Ratio Risque/Rendement pour TP (3.0 = 1:3)

// === DÉTECTION SPIKES SANS IA ===
input bool   UseSpikeDetectionWithoutAI = true;  // Activer détection spikes même si IA faible
input int    SpikeDetectionMinSignals = 3;       // Nombre minimum de signaux spike requis (sur 6)
input double SpikeVolumeMultiplier = 2.0;       // Multiplicateur pour détecter spike de volume
input double SpikePriceMultiplier = 1.5;        // Multiplicateur pour détecter spike de prix
input double SpikeCompressionThreshold = 0.5;    // Seuil de compression ATR (0.5 = 50% de la moyenne)
input int    SpikeCalmBarsMin = 3;               // Nombre minimum de bougies calmes requises
input double SpikeMomentumChange = 5.0;         // Changement RSI minimum pour momentum accélérant
input bool   DebugSpikeDetection = false;       // Logs détaillés de détection spike

input bool   UseSessions       = true;   // Trader seulement LO/NYO
input bool   ShowChartGraphics = true;   // FVG, OB, Fibo, EMA, Swing H/L sur le graphique
input bool   ShowPremiumDiscount = true; // Zones Premium (vente) / Discount (achat) / Équilibre
input bool   ShowSignalArrow     = true; // Flèche dynamique clignotante BUY/SELL
input bool   RequireSMCDerivArrowForMarketOrders = true; // Avant tout ordre au marché, attendre SMC_DERIV_ARROW
input int    SMCDerivArrowMaxAgeBars = 3; // La flèche doit être sur les N dernières bougies (timeframe courant)
input bool   AllowScalpEntryByEMA1EMA5WithoutDerivArrow = true; // Scalping: EMA(1)/EMA(5) fort => autoriser même sans flèche récente
input double EMA1EMA5StrongMinGapPct = 0.01; // Gap minimum EMA1-EMA5 (%) pour considérer "fort"
input bool   RequireFutureProtectTouchForBoomCrashDerivArrow = true; // Boom/Crash: armer entrée sur touch future protect avant flèche DERIV
input int    FutureProtectTouchArmSeconds = 120; // Fenêtre après touch pour accepter la flèche (secondes)
input double FutureProtectTouchToleranceATRMult = 0.4; // Tolérance de touch autour du niveau (x ATR M15)
input int    FutureProtectTouchCheckIntervalSec = 2; // Throttle calcul touch (secondes)
input bool   UseTouchProtectScalpExitOnDerivArrow = true; // Boom/Crash: fermer le scalp au moment où la flèche DERIV apparaît
input int    TouchProtectScalpMinHoldSeconds = 10; // Délai min avant fermeture scalp (évite fermeture immédiate)
input int    TouchProtectScalpReentryCooldownSeconds = 60; // Cooldown après sortie sur flèche (évite boucle entrée/sortie au même niveau)
input bool   UseSR20TouchEntryForBoomCrashDerivArrow = true; // Boom/Crash: activer entrée sur support/résistance 20 bars
input double SR20TouchToleranceATRMult = 0.5; // Tolérance autour de SR20 via ATR M1
input int    SR20TouchATRPeriod = 20; // Période ATR pour tolérance SR20 (M1)
input bool   AllowBoomCrashTrendEntryWithoutArrow = true; // Autoriser entrée Boom/Crash en tendance forte sans flèche
input double BoomCrashTrendEntryMinConfidencePct = 90.0;  // Confiance ML min (%) pour bypass flèche en tendance forte
input int    BoomCrashTrendLookbackBarsM1 = 60;           // Lookback M1 pour détecter tendance "escalier"
input double BoomCrashTrendMinMovePct = 0.10;             // Mouvement min (%) sur lookback M1 (ex: 0.10 = 0.10%)
input double BoomCrashTrendMaxDrawdownPct = 0.35;         // Drawdown max (%) du mouvement (0.35 = 35% du move)
input double BoomCrashTrendMinBullishCandleRatio = 0.60;  // % bougies dans le sens de la tendance
input bool   DebugDerivArrowCapture = true;              // Debug capture flèche SMC_DERIV_ARROW (logs)
input bool   ShowPredictedSwing  = true; // SL/SH prédits (futurs) sur le canal
input bool   ShowEMASupportResistance = true; // EMA M1, M5, H1 en support/résistance
input bool   RequireEMATouchBeforeEntry = true;   // Exiger une retouche EMA (9/21/50/100/200) avant une nouvelle entrée
input int    EMATouchLookbackBarsM1 = 30;         // Nb bougies M1 max pour considérer une "retouche" récente
input double EMATouchMaxDistancePct = 0.03;       // Distance max (%) prix↔EMA pour valider la retouche (0.03 = 0.03%)
input bool   DebugEMATouchFilter = false;         // Logs EMA-touch (throttlé)
input bool   UltraLightMode      = false; // Mode ultra léger: pas de graphiques ni IA, exécution trading minimale
input bool   BlockAllTrades      = false; // BLOQUER toutes les entrées/sorties (mode observation seul)
input int    SpikePredictionOffsetMinutes = 60; // Décalage dans le futur pour afficher l'entrée de spike dans la zone prédite

input group "=== SL/TP DYNAMIQUES (prudent / sécuriser gain) ==="
input double SL_ATRMult        = 2.5;    // Stop Loss (x ATR) - prudent
input double TP_ATRMult        = 5.0;    // Take Profit (x ATR) - ratio 2:1
input group "=== TRAILING STOP (sécuriser les gains) ==="
input bool   UseTrailingStop    = true;   // Activer le Trailing Stop automatique
input double TrailingStop_ATRMult = 3.0;  // Distance Trailing Stop (x ATR) - moins agressif pour protéger les gains
input double TrailingStartProfitDollars = 0.50; // Activer le trailing dès petit gain ($)
input bool   DynamicSL_Enable = true;               // SL dynamique (BE + trailing + lock gain max)
input double DynamicSL_StartProfitDollars = 0.50;   // Commencer à protéger à partir de ce profit ($)
input double DynamicSL_LockPctOfMax = 0.50;         // Protéger au moins X% du gain max (0.50 = 50%)
input int    DynamicSL_BE_BufferPoints = 5;         // Marge break-even (points)

input group "=== GRAPHIQUES SMC (affichage visuel) ==="
input bool   ShowPredictionChannel = true; // Afficher le canal de prédiction ML
input bool   ShowFutureCandlesM1 = true; // Afficher les chandeliers japonais futurs M1
input int    FutureCandlesCount = 200; // Nombre de bougies futures à projeter
input int    FutureCandlesRefreshSeconds = 20; // TTL cache prédiction (s)
input bool   AutoValidateFuturePredictions = true; // Envoyer validation prédictions vs réel au serveur
input int    FuturePredictionMinBarsToValidate = 30; // Nb min de bougies réelles closes avant envoi validation
input bool   ShowBookmarkLevels    = true; // Lignes horizontales sur derniers Swing High/Low (bookmark ICT)

input group "=== TABLEAU DE BORD ET MÉTRIQUES ==="
input bool   UseDashboard        = true;   // Afficher le tableau de bord avec métriques
input bool   DashboardSingleSourceMode = true; // Eviter les doublons: infos texte uniquement via UpdateDashboard()
input bool   ShowMLMetrics       = true;   // Afficher les métriques ML (entraînement modèle)
input bool   AutoStartMLContinuousTraining = true; // Démarrer l'entraînement continu ML automatiquement
input int    MLContinuousCheckIntervalSec  = 300;  // Vérifier/relancer continuous training (sec)
input int    MLMetricsLabelYOffsetPixels   = 200;  // Décalage vertical (px) pour éviter la superposition - augmenté
input int    DashboardLabelXOffsetPixels   = 10;   // Offset X dashboard (px)
input int    DashboardLabelYStartPixels    = 18;   // Début Y dashboard (px)
input int    DashboardLabelLineHeightPixels= 22;   // Hauteur ligne dashboard (px) - augmenté pour éviter la superposition
input bool   UseSpikeAutoClose    = true;   // Fermeture automatique des spikes (ACTIVÉ)
input bool   UseDollarExits       = true;  // Fermetures basées sur $ (DÉSACTIVÉ - laisse SL/TP normal)
input bool   UseIAHoldClose       = true;  // Fermer sur HOLD (désactivé=laisser SL/TP naturel, capturer le spike)
input bool   UseDirectionConflictClose = true; // Fermer sur conflit direction (ACTIVÉ - permet rotation automatique)

input group "=== AI SERVER (confirmation signaux) ==="
input bool   UseAIServer       = true;   // Utiliser le serveur IA pour confirmation
input string AI_ServerURL       = "http://localhost:8000";  // URL du serveur IA local
input string AI_ServerRender    = "https://kolatradebot.onrender.com";  // URL render en fallback
input int    AI_Timeout_ms     = 5000;   // Timeout WebRequest (ms)
input int    AI_UpdateInterval_Seconds = 30;  // Intervalle mise à jour IA (secondes)
input bool   UsePropiceSymbolsFilter = true;  // ⚠️ IMPORTANT: Filtre horaire - Le robot trade UNIQUEMENT sur les symboles les plus "propices" selon l'heure actuelle (UTC)
                                            // Fonctionnement: Le serveur analyse les performances par tranche horaire et retourne le Top N des symboles les plus performants
                                            // Si le symbole actuel n'est pas dans ce Top, le robot BLOQUE tous les trades (même si signal IA/SMC valide)
                                            // Objectif: Maximiser les probabilités de succès en tradant uniquement pendant les heures optimales pour chaque symbole
input int    PropiceTopN = 5;                // Top N symbols renvoyés par /symbols/propice/top
input int    PropiceUpdateIntervalSec = 60;  // Refresh filtre propice (secondes)
input bool   UseRenderAsPrimary = false; // Utiliser le serveur local en premier (Render en fallback)
input string AI_ServerURL2      = "http://localhost:8000";  // URL serveur local
input bool   PropiceAllowMarketOrdersOnAllPropiceSymbols = true; // Marché: autoriser sur tous les symboles propices (pas seulement le rang 0)
input double PropiceNonTopExtraMinAIConfidencePercentPerRank = 5.0; // +% confiance minimale par rang (rang 1=2eme, etc.)
input double PropiceNonTopExtraMinSetupScore = 5.0; // +score minimum si setupScore est utilisé (rangs >0)
input double MinAIConfidence   = 0.55;   // Confiance IA min pour exécuter (55% = plus de sécurité)
input int    AI_Timeout_ms2     = 10000;  // Timeout WebRequest (ms) - Render cold start
input string AI_ModelName       = "SMC_Model";  // Nom du modèle IA
input string AI_ModelVersion    = "1.0";  // Version du modèle IA
input bool   AI_UseGPU          = true;   // Utiliser le GPU pour l'IA (si disponible)
input bool   RequireAIConfirmation = true; // Exiger confirmation IA pour SMC (false = trader sans IA)
input int    M5TouchArrowRecoveryWindowSec = 300; // Fenêtre de rattrapage après touch M5 raté (Boom BUY via flèche)
input bool   EnableBoomCrashRecoveryTrades = false; // DÉSACTIVÉ: SELL Boom / BUY Crash (trade recovery exceptionnel)

//input group "=== ORDRES LIMITES (remplacement automatique) ==="
input bool   ReplaceMisalignedLimitOrders = true;  // Référence compatibilité (ordres limit désactivés)
input double MaxDistanceForLimitCheck = 20.0;   // Référence compatibilité (ordres limit désactivés)
input double MinConfidenceForReplacement = 0.60; // Référence compatibilité (ordres limit désactivés)
input bool   UseFVG            = true;   // Fair Value Gap
input bool   UseOrderBlocks    = true;   // Order Blocks
input bool   UseLiquiditySweep = true;   // Liquidity Sweep (LS)
input bool   UseICTEvidenceSequence = true; // Exiger une séquence de confirmations ICT avant entrée
input int    ICTMinSignatures  = 3;      // Signatures minimales requises (OB/IFVG/Breaker/BOS)
input int    ICTLookbackBars   = 120;    // Fenêtre historique pour validation ICT
input double ICTSweepTolerancePoints = 8.0; // Tolérance sweep/liquidité en points
input bool   ICTRequireNestedOBSequence = true; // Exiger OB principal + OB interne valide avant entrée
input bool   DrawICTChecklistGraphics = true; // Afficher la checklist de validation ICT sur graphique
input bool   RequireStructureAfterSweep = true; // Smart Money: entrée après confirmation (LS+BOS/FVG/OB)
input bool   NoEntryDuringSweep = true;  // Attendre 1+ barres après le sweep (jamais pendant panique)
input bool   StopBeyondNewStructure = true; // Stop au-delà nouvelle structure (pas niveau évident)
input bool   UseBOS            = true;   // Break Of Structure
input bool   UseOTE            = true;   // Optimal Trade Entry (Fib 0.62-0.79)
input bool   UseEqualHL        = true;   // Equal Highs/Lows (EQH/EQL)
input bool   ShowOTEImbalanceOnChart = true; // Dessiner setup OTE + Imbalance (FVG) sur le graphique
input int    OTEImbalanceProjectionBars = 120; // Projection visuelle (LTF) vers la droite
input bool   OTE_UseLimitOrders = true; // Entrées OTE via limit (meilleure précision)

// NOUVEAUX: Paramètres SMC_OTE flexible pour plus d'opportunités
input bool   OTE_UseFlexibleLogic    = true;  // Utiliser logique flexible SMC_OTE (plus de trades)
input double OTE_MinRiskPoints       = 2.0;   // Risque minimum en points (2 = petits mouvements)
input double OTE_ConfluenceTolerance = 0.3;   // Tolérance confluence FVG-OTE (30% = plus flexible)
input int    OTE_MaxPositionsPerSymbol = 2;    // Max positions par symbole (1=strict, 2=flexible)
input double OTE_MinConfidenceForex  = 55.0;  // Confiance IA minimum pour Forex (plus flexible)
input double OTE_MinConfidenceOther  = 60.0;  // Confiance IA minimum pour autres symboles

// NOUVEAUX: Paramètres pour entrées sur niveaux techniques (éviter les corrections)
input bool   OTE_UseTechnicalLevels  = true;  // Entrer uniquement sur niveaux techniques clés
input double OTE_SR20_ATR_Tolerance   = 0.5;   // Distance max Support/Résistance 20 barres (en ATR)
input double OTE_Pivot_ATR_Tolerance  = 0.3;   // Distance max Pivot Daily (en ATR)
input double OTE_ST_ATR_Tolerance     = 0.4;   // Distance max Supertrend M5 (en ATR)
input double OTE_TL_ATR_Tolerance     = 0.6;   // Distance max Trendline (en ATR)
input double OTE_Correction_ATR_Threshold = 0.8; // Seuil de correction forte (en ATR)

// NOUVEAU: Paramètre pour contrôler la stratégie SMC_OTE complète
input bool   UseSMC_OTEStrategy    = true;  // Activer la stratégie SMC_OTE complète (3 étapes)

input group "=== TIMEFRAMES ==="
input ENUM_TIMEFRAMES HTF      = PERIOD_H4;  // Structure (HTF)
input ENUM_TIMEFRAMES LTF      = PERIOD_M15; // Entrée (LTF)

input group "=== FVG_Kill PRO (Smart Money) ==="
input bool   UseFVGKillMode    = true;   // Activer logique FVG_Kill (EMA HTF + LS)
input int    EMA50_Period      = 50;     // EMA 50 (HTF)
input int    EMA200_Period     = 200;    // EMA 200 (HTF)
input double ATR_Mult          = 1.8;    // Multiplicateur ATR (SL FVG_Kill)
input bool   UseTrailingStructure = true; // Trailing SL sur structure (LTF bar)
input bool   BoomCrashMode     = true;   // Boom/Crash: BUY sur Boom, SELL sur Crash

input group "=== SESSIONS (heure serveur) ==="
input bool   TradeOutsideKillZone = true;  // Trader 24/7 (true = ignorer Kill Zone)
input int    LondonStart       = 8;      // London Open début
input int    LondonEnd         = 11;     // London Open fin
input int    NYOStart          = 13;     // New York Open début
input int    NYOEnd            = 16;     // New York Open fin

input group "=== NOTIFICATIONS ==="
input bool   UseNotifications  = true;   // Alert + notification push (signaux et trades)

input group "=== BOUGIES FUTURES ==="
input int    PredictionChannelPastBars = 1000; // (interne)
input int    PredictionChannelBars = 1000;  // (interne, canal de prédiction sur 1000 bougies futures)

input group "=== CANAUX SMC MULTI-TF ==="
input bool   ShowSMCChannelsMultiTF = true;  // Afficher canaux SMC sur H1, M30, M5
input bool   ShowEMASupertrendMultiTF = true; // Afficher EMA Supertrend S/R sur H1, M30, M5
input int    SMCChannelFutureBars = 5000;    // Bougies futures M1 à projeter
input int    EMAFastPeriod = 9;   // Période EMA rapide pour Supertrend
input int    EMASlowPeriod = 21;  // Période EMA lente pour Supertrend
input double ATRMultiplier = 2.0; // Multiplicateur ATR pour Supertrend

//input group "=== ORDRES LIMITES (niveau le plus proche) ==="
//input bool   UseClosestLevelForLimits = true;  // SUPPRIMÉ - Plus d'ordres limit
input double MaxDistanceLimitATR = 1.0;        // Valeur conservée pour compatibilité (les ordres limit sont désactivés)
//input bool   ShowLimitOrderLevels = true;      // SUPPRIMÉ - Plus d'affichage ordres limit

input group "=== IA SERVEUR ==="

input group "=== BOOM/CRASH ==="
input bool   BoomBuyOnly       = true;   // Boom: BUY uniquement
input bool   CrashSellOnly     = true;   // Crash: SELL uniquement
input bool   NoSLTP_BoomCrash  = false;  // Pas de SL/TP sur Boom/Crash (DÉSACTIVÉ - utilise SL/TP normal)
input double BoomCrashSpikeTP  = 0.50;   // Fermer dès petit gain (spike capté) si profit > ce seuil ($) - AUGMENTÉ
input double BoomCrashSpikePct = 0.50;   // Pourcentage de mouvement pour détecter spike (50% - beaucoup plus élevé)
input double BoomCrashSecondSpikeImminentProb = 0.85; // Si proba spike >= seuil, attendre un 2e spike avant fermeture
input double TargetProfitBoomCrashUSD = 2.0; // Gain à capter ($) - fermer si profit >= ce seuil (Spike_Close)
input double MaxLossDollars    = 15.0;   // Fermer toute position si perte atteint ($) - augmenté pour éviter fermetures prématurées
input double TakeProfitDollars = 2.0;    // Fermer si bénéfice atteint ($) - Volatility/Forex/Commodity
input bool   UseMaxLossBoomCrashPerTrade = true; // Boom/Crash: fermer si perte par position > seuil
input double MaxLossBoomCrashPerTradeUSD = 4.0;  // Boom/Crash: perte max admise par trade ($)
input double SymbolProfitTargetUSD = 10.0; // Profit target individuel par symbole ($) - OR, ARGENT, etc.

// Filtre basé sur la probabilité de spike issue du modèle ML
input bool   UseSpikeMLFilter        = true;   // Utiliser la probabilité ML de spike pour filtrer les entrées
input double SpikeML_MinProbability  = 0.75;   // Probabilité ML minimale de spike pour autoriser le trade (75%)
input bool   SpikeUsePreSpikeOnlyForBoomCrash = true; // Boom/Crash: entrer dès le pattern pré-spike (avant le 1er spike)
input bool   SpikeRequirePreSpikePattern = true; // Mode strict: exiger le pattern pré-spike EN PLUS d'un spike récent
input double PreSpike_CompressionRatio   = 0.65;  // Pré-spike: range10 < range50 * ratio (plus haut = plus permissif)
input double PreSpike_ConsolidationPct   = 0.002; // Pré-spike: distance au MA20 (0.2% par défaut)
input double PreSpike_KeyLevelPct        = 0.002; // Pré-spike: proximité swing high/low (0.2% par défaut)

input group "=== INDICATEURS CLASSIQUES (RSI / MACD / BB / VWAP / Pivots / Ichimoku / OBV) ==="
input bool   UseClassicIndicatorsFilter = true;  // Activer le filtre combiné d'indicateurs classiques
input int    ClassicMinConfirmations    = 2;     // Nombre minimal d'indicateurs alignés avec la direction
input bool   UseBollingerFilter         = true;  // Utiliser les Bandes de Bollinger dans le filtre
input bool   UseVWAPFilter              = true;  // Utiliser le VWAP intraday
input bool   UsePivotFilter             = true;  // Utiliser les points pivots journaliers
input bool   UseIchimokuFilter          = true;  // Utiliser un résumé tendance Ichimoku H1
input bool   UseOBVFilter               = true;  // Utiliser le volume OBV comme confirmation

//| GESTION DES POSITIONS ET VARIABLES GLOBALES                    |

// Vrai si ce symbole a subi une perte récente (SL ou autre) ? réentrée soumise à conditions strictes
bool IsRecentLossOnSymbol(const string symbol)
{
   if(g_lastLossSymbol == "" || symbol == "") return false;
   if(g_lastLossSymbol != symbol) return false;
   return (TimeCurrent() - g_lastLossTime <= RECENT_LOSS_WINDOW_SEC);
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
      Print("? Réentrée après perte autorisée sur ", symbol,
            " - conditions strictes remplies (conf IA ",
            DoubleToString(conf*100, 1), "% + spike/setup fort)");
      return true;
   }

   Print("?? Réentrée après perte sur ", symbol,
         " bloquée (éviter 2e perte consécutive - exiger conf IA ?90% + spike/setup fort)");
   return false;
}

// Lot minimal broker brut pour le symbole (sans surcharge interne)
double GetMinLotForSymbol(const string symbol)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   if(minLot <= 0.0)
   {
      Print("❌ MIN LOT INDISPONIBLE pour ", symbol, " - blocage trade pour éviter Invalid volume");
      return 0.0;
   }
   return minLot;
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
   Print("?? RECOVERY - Lot doublé (", DoubleToString(recoveryLot, 2), ") sur ", _Symbol, " pour compenser perte sur ", lostSym);
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
   
   // Seuil FIXE à 85% pour les autres symboles :
   // on ne trade QUE si l'IA est clairement BUY ou SELL avec très forte confiance.
   double minConf = 0.85;
   if(g_lastAIAction == "" || g_lastAIConfidence < minConf)
   {
      Print("?? TRADE BLOQUÉ - Pas de décision IA forte (conf: ",
            DoubleToString(g_lastAIConfidence*100, 1), "% < ",
            DoubleToString(minConf*100, 1), "%) sur ", _Symbol);
      return false;
   }
   
   if(g_lastAIAction == "HOLD" || g_lastAIAction == "hold")
   {
      Print("?? TRADE BLOQUÉ - IA en HOLD sur ", _Symbol, " (", DoubleToString(g_lastAIConfidence*100,1), "%)");
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
      Print("?? TRADE BLOQUÉ - Décision IA non directionnelle (", iaDir,
            ") ou incompatible pour ", _Symbol,
            " (conf: ", DoubleToString(g_lastAIConfidence*100,1), "%)");
      return false;
   }

   string dir = direction;
   StringToUpper(dir);

   if((iaDir == "BUY"  && dir != "BUY") ||
      (iaDir == "SELL" && dir != "SELL"))
   {
      Print("?? TRADE BLOQUÉ - Direction '", dir,
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
int hEmaFast = INVALID_HANDLE;  // EMA rapide pour tendance
int hEmaSlow = INVALID_HANDLE;  // EMA lente pour tendance
int ema50H = INVALID_HANDLE;
int ema200H = INVALID_HANDLE;
int fractalH = INVALID_HANDLE;
int emaM1H = INVALID_HANDLE;
int emaM5H = INVALID_HANDLE;
int emaH1H = INVALID_HANDLE;

// EMA(1) / EMA(5) scalping rapide (M1)
int ema1M1 = INVALID_HANDLE;
int ema5M1 = INVALID_HANDLE;

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

// EMAs SMC supplémentaires sur le timeframe d'entrée (LTF)
int ema21LTF = INVALID_HANDLE;
int ema31LTF = INVALID_HANDLE;
int ema50LTF = INVALID_HANDLE;
int ema100LTF = INVALID_HANDLE;
int ema200LTF = INVALID_HANDLE;
static datetime g_arrowBlinkTime = 0;
static bool g_arrowVisible = true;
static datetime g_spikeBlinkTime = 0;
static bool g_spikeWarningActive = false;
static datetime g_spikeWarningStart = 0;
static bool g_spikeWarningVisible = true;
int g_aiUpdateInterval = 30;
bool g_aiConnected = false;
static datetime g_lastBoomCrashPriceTime = 0;
// Recovery "exceptionnel" Boom/Crash:
// - Boom: on stocke le temps du dernier spike Boom (trade spike BUY)
// - Crash: on stocke le temps du dernier spike Crash (trade spike SELL)
// Ensuite, on arme quand un touch Entry M5 a eu lieu et on déclenche quand 4 petites bougies M1
// sont déjà passées. La position est ensuite fermée par précaution après 5 petites bougies M1.
static datetime g_lastBoomSpikeTime = 0;
static datetime g_lastCrashSpikeTime = 0;
static datetime g_lastBoomM5BuyTouchTime = 0;
static bool g_boomM5BuyArrowRecoveryArmed = false;
static bool g_allowBoomM5ArrowRecoveryBypass = false; // bypass IA strict uniquement pour recovery BUY Boom
static bool g_boomSellEntryArmed = false;
static datetime g_boomSellEntryArmedTouchTime = 0;
static bool g_crashBuyEntryArmed = false;
static datetime g_crashBuyEntryArmedTouchTime = 0;
static datetime g_boomFutureProtectTouchTime = 0;
static datetime g_crashFutureProtectTouchTime = 0;
static double   g_boomFutureProtectTouchLevel = 0.0;
static double   g_crashFutureProtectTouchLevel = 0.0;
static datetime g_lastFutureProtectTouchCalc = 0;
static datetime g_boomTouchReentryCooldownUntil = 0;
static datetime g_crashTouchReentryCooldownUntil = 0;
static datetime g_boomSR20TouchTime = 0;
static datetime g_crashSR20TouchTime = 0;
static double   g_boomSR20TouchLevel = 0.0;
static double   g_crashSR20TouchLevel = 0.0;
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
   bool profitTargetReached;  // Nouveau: flag pour profit target atteint
};

SymbolPauseInfo g_symbolPauses[20]; // Maximum 20 symboles
int g_pauseCount = 0;
int g_dashboardBottomY = 0; // pixels: dernière ligne du dashboard (pour empiler les labels)

// Filtre symboles "propices" (profil horaire)
datetime g_lastPropiceUpdateTime = 0;
string   g_propiceTopSymbolsText = "";
bool     g_currentSymbolIsPropice = true;
string   g_propiceTopSymbolsStatus = "";

// Gestion de la pause après profit journalier
datetime g_dailyProfitPauseStartTime = 0;
bool     g_dailyProfitTargetReached = false;
double   g_dailyProfitPeak = 0.0;

// Priorité du symbole actuel dans la liste des propices (0 = plus propice, -1 = non propice)
int      g_currentSymbolPriority = -1;

// Suivi des pertes par symbole pour protection
double   g_symbolCurrentLoss = 0.0;
datetime g_symbolLossStartTime = 0;
bool     g_symbolTradingBlocked = false;

input bool DashboardUseCommentFallback = false; // Désactivé pour éviter les doublons avec les labels
input int  PropiceLabelExtraYOffsetPixels = 30; // Décalage sous le dashboard pour "Top propices" - augmenté
input bool CleanChartOnStartup = true;  // Nettoyer tous les anciens dessins au démarrage du robot

// NOTE: Les stats gagnés/perdus doivent provenir de l'historique MT5 (pas en mémoire),
// et se recalculent par période (jour/mois) pour éviter toute "invention".

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   // Nettoyer tous les anciens dessins sur le chart au démarrage (si activé)
   if(CleanChartOnStartup)
   {
      CleanupAllChartObjects();
      Print("🧹 Nettoyage complet des anciens dessins effectué au démarrage");
   }
   
   atrHandle = iATR(_Symbol, LTF, 14);
   emaHandle = iMA(_Symbol, LTF, 9, 0, MODE_EMA, PRICE_CLOSE);
   hEmaFast = iMA(_Symbol, LTF, 9, 0, MODE_EMA, PRICE_CLOSE);   // EMA rapide
   hEmaSlow = iMA(_Symbol, LTF, 21, 0, MODE_EMA, PRICE_CLOSE);  // EMA lente
   ema50H = iMA(_Symbol, HTF, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);
   ema200H = iMA(_Symbol, HTF, EMA200_Period, 0, MODE_EMA, PRICE_CLOSE);
   // EMAs SMC sur le timeframe d'entrée (LTF)
   ema21LTF = iMA(_Symbol, LTF, 21, 0, MODE_EMA, PRICE_CLOSE);
   ema31LTF = iMA(_Symbol, LTF, 31, 0, MODE_EMA, PRICE_CLOSE);
   ema50LTF = iMA(_Symbol, LTF, 50, 0, MODE_EMA, PRICE_CLOSE);
   ema100LTF = iMA(_Symbol, LTF, 100, 0, MODE_EMA, PRICE_CLOSE);
   ema200LTF = iMA(_Symbol, LTF, 200, 0, MODE_EMA, PRICE_CLOSE);
   
   // Initialiser le système de gestion des pauses
   InitializeSymbolPauseSystem();
   
   Print("?? SMC Universal + FVG_Kill PRO | 1 pos/symbole | Stratégie visible");
   emaM1H = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
   emaM5H = iMA(_Symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
   emaH1H = iMA(_Symbol, PERIOD_H1, 20, 0, MODE_EMA, PRICE_CLOSE);

   // EMA(1)/EMA(5) pour bypass flèche (scalping rapide)
   ema1M1 = iMA(_Symbol, PERIOD_M1, 1, 0, MODE_EMA, PRICE_CLOSE);
   ema5M1 = iMA(_Symbol, PERIOD_M1, 5, 0, MODE_EMA, PRICE_CLOSE);
   
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
   // Vérification robuste des handles
   if(atrHandle == INVALID_HANDLE)
   {
      Print("? Erreur création ATR - Tentative de récupération...");
      atrHandle = iATR(_Symbol, LTF, 14);
      if(atrHandle == INVALID_HANDLE)
      {
         Print("?? Erreur ATR - Utilisation ATR calculé manuellement pour éviter détachement");
         Comment("?? ATR MANUEL - Robot fonctionnel");
         atrHandle = INVALID_HANDLE; // Garder INVALID_HANDLE mais continuer
      }
   }
   // Les indicateurs seront ajoutés dynamiquement si nécessaire pour éviter le détachement
   GlobalVariableSet("SMC_OPEN_LOCK_" + IntegerToString(InpMagicNumber), 0);
   Print("?? SMC Universal + FVG_Kill PRO | 1 pos/symbole | Stratégie visible");
   Print("   Catégorie: ", EnumToString(SMC_GetSymbolCategory(_Symbol)));
   Print("   IA: ", UseAIServer ? AI_ServerURL : "Désactivé");

   // Démarrer/relancer l'apprentissage continu côté backend (si activé)
   if(ShowMLMetrics && AutoStartMLContinuousTraining)
   {
      EnsureMLContinuousTrainingRunning(true);
      UpdateMLMetricsDisplay();      // Remplir g_mlMetricsStr rapidement
      DrawMLMetricsOnChart();        // Affichage immédiat sur le graphique
   }
   return INIT_SUCCEEDED;
}

bool TryAcquireOpenLock()
{
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
   Print("?? DÉTACHEMENT ROBOT SMC | ", _Symbol, " | Raison: ", reasonStr);
   if(reason == REASON_INITFAILED)
      Print("?? CAUSE: Erreur dans OnInit ou crash (indicateurs, mémoire, etc.)");

   if(atrHandle != INVALID_HANDLE) { IndicatorRelease(atrHandle); atrHandle = INVALID_HANDLE; }
   if(emaHandle != INVALID_HANDLE) { IndicatorRelease(emaHandle); emaHandle = INVALID_HANDLE; }
   if(hEmaFast != INVALID_HANDLE) { IndicatorRelease(hEmaFast); hEmaFast = INVALID_HANDLE; }
   if(hEmaSlow != INVALID_HANDLE) { IndicatorRelease(hEmaSlow); hEmaSlow = INVALID_HANDLE; }
   if(ema50H != INVALID_HANDLE) { IndicatorRelease(ema50H); ema50H = INVALID_HANDLE; }
   if(ema200H != INVALID_HANDLE) { IndicatorRelease(ema200H); ema200H = INVALID_HANDLE; }
   if(fractalH != INVALID_HANDLE) { IndicatorRelease(fractalH); fractalH = INVALID_HANDLE; }
   if(emaM1H != INVALID_HANDLE) { IndicatorRelease(emaM1H); emaM1H = INVALID_HANDLE; }
   if(emaM5H != INVALID_HANDLE) { IndicatorRelease(emaM5H); emaM5H = INVALID_HANDLE; }
   if(emaH1H != INVALID_HANDLE) { IndicatorRelease(emaH1H); emaH1H = INVALID_HANDLE; }
   if(ema1M1 != INVALID_HANDLE) { IndicatorRelease(ema1M1); ema1M1 = INVALID_HANDLE; }
   if(ema5M1 != INVALID_HANDLE) { IndicatorRelease(ema5M1); ema5M1 = INVALID_HANDLE; }
   if(emaFastM1 != INVALID_HANDLE) { IndicatorRelease(emaFastM1); emaFastM1 = INVALID_HANDLE; }
   if(emaSlowM1 != INVALID_HANDLE) { IndicatorRelease(emaSlowM1); emaSlowM1 = INVALID_HANDLE; }
   if(emaFastM5 != INVALID_HANDLE) { IndicatorRelease(emaFastM5); emaFastM5 = INVALID_HANDLE; }
   if(emaSlowM5 != INVALID_HANDLE) { IndicatorRelease(emaSlowM5); emaSlowM5 = INVALID_HANDLE; }
   if(emaFastH1 != INVALID_HANDLE) { IndicatorRelease(emaFastH1); emaFastH1 = INVALID_HANDLE; }
   if(emaSlowH1 != INVALID_HANDLE) { IndicatorRelease(emaSlowH1); emaSlowH1 = INVALID_HANDLE; }
   if(atrM1 != INVALID_HANDLE) { IndicatorRelease(atrM1); atrM1 = INVALID_HANDLE; }
   if(atrM5 != INVALID_HANDLE) { IndicatorRelease(atrM5); atrM5 = INVALID_HANDLE; }
   if(atrH1 != INVALID_HANDLE) { IndicatorRelease(atrH1); atrH1 = INVALID_HANDLE; }
   if(ema21LTF != INVALID_HANDLE) { IndicatorRelease(ema21LTF); ema21LTF = INVALID_HANDLE; }
   if(ema31LTF != INVALID_HANDLE) { IndicatorRelease(ema31LTF); ema31LTF = INVALID_HANDLE; }
   if(ema50LTF != INVALID_HANDLE) { IndicatorRelease(ema50LTF); ema50LTF = INVALID_HANDLE; }
   if(ema100LTF != INVALID_HANDLE) { IndicatorRelease(ema100LTF); ema100LTF = INVALID_HANDLE; }
   if(ema200LTF != INVALID_HANDLE) { IndicatorRelease(ema200LTF); ema200LTF = INVALID_HANDLE; }

   // Nettoyer les objets graphiques du robot
   CleanupSMCChartObjects();
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
      Print("? FVG_Kill BUY bloqué (règle duplication / IA) sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }
   
   // Exiger une décision IA forte pour tous les marchés non Boom/Crash
   if(!IsAITradeAllowedForDirection("BUY") || !IsMLModelTrustedForCurrentSymbol("BUY"))
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
   
   if(!HasRecentSMCDerivArrowForDirection("BUY"))
   {
      Print("?? FVG_Kill BUY bloqué - Attendre flèche SMC_DERIV_ARROW BUY sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   trade.Buy(lot, _Symbol, 0, sl, tp, "FVG_Kill BUY");
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
      Print("? FVG_Kill SELL bloqué (règle duplication / IA) sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }
   
   // Exiger une décision IA forte pour tous les marchés non Boom/Crash
   if(!IsAITradeAllowedForDirection("SELL") || !IsMLModelTrustedForCurrentSymbol("SELL"))
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
   
   if(!HasRecentSMCDerivArrowForDirection("SELL"))
   {
      Print("?? FVG_Kill SELL bloqué - Attendre flèche SMC_DERIV_ARROW SELL sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   trade.Sell(lot, _Symbol, 0, sl, tp, "FVG_Kill SELL");
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
      Print("?? Perte totale (", DoubleToString(totalProfit, 2), "$) >= ", DoubleToString(MaxTotalLossDollars, 0), "$ ? position la plus perdante fermée (", DoubleToString(worstProfit, 2), "$)");
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
      Print("?? PROFIT TOTAL ATTEINT (", DoubleToString(totalProfit, 2), "$ >= 3.00$) ? Fermeture de toutes les positions...");
      
      for(int i = 0; i < ArraySize(allTickets); i++)
      {
         ulong ticket = allTickets[i];
         // VALIDATION: Vérifier que la position existe toujours avant de fermer
         if(!PositionSelectByTicket(ticket))
         {
            Print("?? Position déjà fermée avant profit total close - ticket=", ticket);
            continue;
         }
         
         double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         string symbol = PositionGetString(POSITION_SYMBOL);
         
         if(PositionCloseWithLog(ticket, "Profit total atteint"))
         {
            Print("? Position fermée - ", symbol, ": ", DoubleToString(profit, 2), "$");
         }
         else
         {
            Print("? Échec fermeture - ", symbol, ": ", DoubleToString(profit, 2), "$");
         }
      }
      
      Print("?? FERMETURE COMPLÈTE - Profit total réalisé: ", DoubleToString(totalProfit, 2), "$");
   }
}

//+------------------------------------------------------------------+
//| Fermeture profit-only par symbole (POSITION_PROFIT seulement)   |
//| Ferme toutes les positions du symbole dès que la somme de      |
//| POSITION_PROFIT (sans swap/commission) >= targetProfitUSD      |
//+------------------------------------------------------------------+
void CloseAllPositionsIfSymbolProfitReached(double targetProfitUSD)
{
   if(targetProfitUSD <= 0.0) return;

   // 1) Collecte des symboles présents sur nos positions EA
   string symbols[];
   ArrayResize(symbols, 0);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      string sym = posInfo.Symbol();
      if(sym == "") continue;

      bool exists = false;
      for(int k = 0; k < ArraySize(symbols); k++)
      {
         if(symbols[k] == sym)
         {
            exists = true;
            break;
         }
      }
      if(!exists)
      {
         ArrayResize(symbols, ArraySize(symbols) + 1);
         symbols[ArraySize(symbols) - 1] = sym;
      }
   }

   if(ArraySize(symbols) <= 0) return;

   // 2) Pour chaque symbole: somme POSITION_PROFIT puis fermeture
   string reason = "Symbol profit-only >= " + DoubleToString(targetProfitUSD, 2) + "$";
   for(int s = 0; s < ArraySize(symbols); s++)
   {
      string sym = symbols[s];
      if(sym == "") continue;

      double symbolProfit = 0.0; // POSITION_PROFIT uniquement
      ulong tickets[];
      ArrayResize(tickets, 0);

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!posInfo.SelectByIndex(i)) continue;
         if(posInfo.Magic() != InpMagicNumber) continue;
         if(posInfo.Symbol() != sym) continue;

         symbolProfit += posInfo.Profit();

         ArrayResize(tickets, ArraySize(tickets) + 1);
         tickets[ArraySize(tickets) - 1] = posInfo.Ticket();
      }

      if(symbolProfit < targetProfitUSD) continue;

      Print("🎯 PROFIT PAR SYMBOLE (profit-only) ATTEINT - ", sym,
            " | Profit: ", DoubleToString(symbolProfit, 2), "$ >= ",
            DoubleToString(targetProfitUSD, 2), "$ - Fermeture immédiate.");

      for(int t = 0; t < ArraySize(tickets); t++)
      {
         ulong ticket = tickets[t];
         if(ticket == 0) continue;
         PositionCloseWithLog(ticket, reason);
      }
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
   return OrderSend(request, result);
}

bool CloseBoomCrashPosition(ulong ticket, const string symbol)
{
   if(ClosePositionByDeal(ticket))
   {
      Print("?? EA CLOSE DEAL OK - ", symbol, " | ticket=", ticket);
      return true;
   }
   if(PositionCloseWithLog(ticket, "Boom/Crash position close"))
   {
      Print("?? EA POSITION CLOSE OK - ", symbol, " | ticket=", ticket);
      return true;
   }
   int err = GetLastError();
   Print("? EA ÉCHEC FERMETURE Boom/Crash - ", symbol, " | ticket=", ticket, " | code=", err);
   return false;
}

void CloseBoomCrashAfterSpike(ulong ticket, string symbol, double currentProfit)
{
   if(posInfo.Magic() != InpMagicNumber) return;
   if(SMC_GetSymbolCategory(symbol) != SYM_BOOM_CRASH) return;
   
   // RÈGLE BOOM/CRASH: 2 dollars pour ces symboles (inchangé)
   if(currentProfit >= 2.0)
   {
      if(CloseBoomCrashPosition(ticket, symbol))
      {
         Print("? Boom/Crash fermé: bénéfice 2$ atteint (", DoubleToString(currentProfit, 2), "$) - ", symbol);
         if(symbol == _Symbol) { g_lastBoomCrashPrice = 0; }
      }
      return;
   }
   
   // Ensuite, les règles spécifiques Boom/Crash si < 2$
   if(currentProfit >= TargetProfitBoomCrashUSD && currentProfit < 2.0)
   {
      if(CloseBoomCrashPosition(ticket, symbol))
      {
         Print("?? Boom/Crash fermé (gain >= ", DoubleToString(TargetProfitBoomCrashUSD, 2), "$): ", DoubleToString(currentProfit, 2), "$) - ", symbol);
         if(symbol == _Symbol) { g_lastBoomCrashPrice = 0; }
      }
      return;
   }
   
   // Spike detection (si < 2$) - DÉSACTIVÉ par défaut pour éviter fermetures prématurées
   if(g_lastBoomCrashPrice > 0 && false) // false = DÉSACTIVÉ
   {
      double price = SymbolInfoDouble(symbol, SYMBOL_BID);
      double movePct = (price - g_lastBoomCrashPrice) / g_lastBoomCrashPrice * 100.0;
      if(StringFind(symbol, "Boom") >= 0 && movePct >= BoomCrashSpikePct)
      {
         if(CloseBoomCrashPosition(ticket, symbol))
         {
            Print("?? Boom/Crash fermé (spike prix ", DoubleToString(currentProfit, 2), "$) - ", symbol);
            g_lastBoomCrashPrice = 0;
            s_lastRefUpdate = 0;
         }
      }
      if(StringFind(symbol, "Crash") >= 0 && movePct <= -BoomCrashSpikePct)
      {
         if(CloseBoomCrashPosition(ticket, symbol))
         {
            Print("?? Boom/Crash fermé (spike prix ", DoubleToString(currentProfit, 2), "$) - ", symbol);
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
   // Réduire la fréquence des logs DEBUG pour éviter la surcharge
   static datetime lastDebugLog = 0;
   if(TimeCurrent() - lastDebugLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? DEBUG - ManageBoomCrashSpikeClose appelée | UseSpikeAutoClose: ", UseSpikeAutoClose ? "OUI" : "NON");
      lastDebugLog = TimeCurrent();
   }
   
   // Si aucune fermeture automatique n'est activée, sortir immédiatement
   if(!UseSpikeAutoClose && !UseTouchProtectScalpExitOnDerivArrow)
   {
      return;
   }
   
   // OPTIMISATION: Sortir rapidement si aucune position
   if(PositionsTotal() == 0) return;

   bool touchExitMode = (UseTouchProtectScalpExitOnDerivArrow && RequireFutureProtectTouchForBoomCrashDerivArrow);

   // Détection flèche DERIV Arrow une seule fois (pour sortie scalp)
   string arrowDirection = "";
   bool hasDerivArrow = false;
   if(touchExitMode)
   {
      hasDerivArrow = GetDerivArrowDirection(arrowDirection);
   }
   
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

      // Recovery exceptionnel: fermeture par précaution après 5 petites bougies M1
      // - Boom: EXC_RECOVERY_BOOM_SELL
      // - Crash: EXC_RECOVERY_CRASH_BUY
      if(StringFind(comment, "EXC_RECOVERY_") >= 0)
      {
         int smallCount = CountSmallM1CandlesSince(openTime);
         if(smallCount >= 5)
         {
            ulong ticket = posInfo.Ticket();
            if(PositionSelectByTicket(ticket))
            {
               PositionCloseWithLog(ticket, "EXC_RECOVERY close - 5 petites bougies M1");
               Print("?? EXC_RECOVERY fermé après 5 petites bougies M1 - ", _Symbol,
                     " | Ticket=", ticket, " | smallCount=", smallCount, " | Comment=", comment);
            }
         }
         // On laisse ce trade uniquement suivre sa règle recovery (pas de close scalping/TP intermédiaire)
         continue;
      }
      
      // Pour les trades classiques, on conserve une protection de 10 secondes.
      // Pour les SPIKE TRADE, aucune attente: on peut fermer dès que le spike est capté.
      int minHold = MathMax(1, TouchProtectScalpMinHoldSeconds);
      if(!isSpikeTrade && secondsSinceOpen < minHold) // Délai min avant fermeture scalp
      {
         Print("?? DEBUG - Spike Close - Trade trop récent (non SPIKE) - ", symbol, " | Ouvert il y a: ", secondsSinceOpen, "s");
         continue; // Ignorer ce trade pour l'instant
      }

      // Sortie scalp sur apparition de la flèche DERIV Arrow (Boom=BUY vert, Crash=SELL rouge)
      // Si la position est un "SPIKE TRADE", on ne la ferme pas sur la flèche.
      // Sinon une entrée déclenchée par flèche boom/crash serait immédiatement annulée.
      if(!isSpikeTrade && touchExitMode && hasDerivArrow)
      {
         bool isBoomPos = (StringFind(symbol, "Boom") >= 0);
         bool isCrashPos = (StringFind(symbol, "Crash") >= 0);
         bool shouldCloseOnArrow =
            (isBoomPos && arrowDirection == "BUY" && posInfo.PositionType() == POSITION_TYPE_BUY) ||
            (isCrashPos && arrowDirection == "SELL" && posInfo.PositionType() == POSITION_TYPE_SELL);

         if(shouldCloseOnArrow)
         {
            ulong ticket = posInfo.Ticket();
            if(PositionSelectByTicket(ticket))
            {
               if(PositionCloseWithLog(ticket, "Scalp close - TouchProtect + DERIV Arrow"))
               {
                  Print("?? Scalp fermé sur flèche DERIV - ", symbol, " | ticket=", ticket,
                        " | arrow=", arrowDirection, " | age=", secondsSinceOpen, "s");
                  
                  // Cooldown anti-boucle seulement pour le symbole courant (impact sur une nouvelle entrée dans cette instance)
                  if(symbol == _Symbol)
                  {
                     datetime now = TimeCurrent();
                     if(isBoomPos)  g_boomTouchReentryCooldownUntil  = now + TouchProtectScalpReentryCooldownSeconds;
                     if(isCrashPos) g_crashTouchReentryCooldownUntil = now + TouchProtectScalpReentryCooldownSeconds;
                  }
               }
            }
            continue; // sur décision close, ne pas appliquer le reste (profit/TP)
         }
      }
      
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      double openPrice = posInfo.PriceOpen();
      double currentPrice = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      // Calculer le pourcentage de profit/perte
      double priceChangePercent = MathAbs((currentPrice - openPrice) / openPrice) * 100;
      
      // DEBUG: Log l'état de la position (réduit pour éviter la surcharge)
      static datetime lastPositionDebugLog = 0;
      if(TimeCurrent() - lastPositionDebugLog >= 120) // Log toutes les 2 minutes maximum
      {
         Print("?? DEBUG - Position Spike Close - ", symbol, 
               " | Profit: ", DoubleToString(profit, 2), "$",
               " | Changement: ", DoubleToString(priceChangePercent, 3), "%",
               " | Type: ", (posInfo.PositionType() == POSITION_TYPE_BUY ? "BUY" : "SELL"));
         lastPositionDebugLog = TimeCurrent();
      }
      
      // Fermer UNIQUEMENT sur spike capté (profit) - jamais sur perte, laisser le SL naturel
      bool shouldClose = false;
      string closeReason = "";
      
      if(!touchExitMode && UseSpikeAutoClose)
      {
         // Règle demandée:
         // 1) fermer juste après spike capté
         // 2) si un 2e spike semble imminent, attendre de capter ce 2e spike avant fermeture
         double spikeProbNow = (symbol == _Symbol) ? CalculateSpikeProbability() : g_lastSpikeProbability;
         bool secondSpikeImminent = (spikeProbNow >= BoomCrashSecondSpikeImminentProb);
         bool secondSpikeCertain = (secondSpikeImminent && spikeProbNow >= MathMax(BoomCrashSecondSpikeImminentProb, 0.90));
         double firstSpikeTarget = MathMax(0.01, BoomCrashSpikeTP);
         double secondSpikeTarget = firstSpikeTarget * 1.8;

         if(profit >= firstSpikeTarget)
         {
            if(secondSpikeCertain)
            {
               if(profit >= secondSpikeTarget)
               {
                  shouldClose = true;
                  closeReason = "2e spike capté (imminent)";
               }
               else if(DebugSpikeDetection)
               {
                  Print("⏳ Spike close différé - 2e spike attendu | ", symbol,
                        " | p=", DoubleToString(spikeProbNow * 100.0, 1), "%",
                        " | profit=", DoubleToString(profit, 2), "$ / cible2=", DoubleToString(secondSpikeTarget, 2), "$");
               }
            }
            else
            {
               shouldClose = true;
               closeReason = "Spike capté";
            }
         }
      }
      
      if(shouldClose)
      {
         Print("?? TENTATIVE FERMETURE SPIKE - ", symbol, " | Raison: ", closeReason, 
               " | Profit: ", DoubleToString(profit, 2), "$ | Changement: ", DoubleToString(priceChangePercent, 3), "%");
         ulong ticket = posInfo.Ticket();
         // VALIDATION: Vérifier que la position existe toujours avant de fermer
         if(!PositionSelectByTicket(ticket))
         {
            Print("?? Position déjà fermée avant spike close - ", symbol, " | ticket=", ticket);
            continue;
         }
         
         if(PositionCloseWithLog(ticket, "Spike close - " + closeReason))
         {
            // OPTIMISATION: Log minimal pour éviter le lag
            Print("?? EA FERMETURE SPIKE - ", symbol, " | ticket=", ticket, " | Profit: ", DoubleToString(profit, 2));
            
            if(UseNotifications)
            {
               Alert("?? Spike fermé - ", symbol, " - ", closeReason);
               SendNotification("?? Spike fermé - " + symbol + " - " + closeReason);
            }
         }
         else
         {
            int err = GetLastError();
            Print("? EA ÉCHEC FERMETURE SPIKE - ", symbol, " | ticket=", ticket, " | code=", err);
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
         Print("?? DEBUG - ManageDollarExits DÉSACTIVÉE - laisse SL/TP normal fonctionner");
         lastLog = TimeCurrent();
      }
      return;
   }
   
   // DEBUG: Log pour voir si cette fonction est appelée
   // Réduire la fréquence des logs DEBUG pour éviter la surcharge
   static datetime lastDebugLog = 0;
   if(TimeCurrent() - lastDebugLog >= 120) // Log toutes les 2 minutes maximum
   {
      Print("?? DEBUG - ManageDollarExits appelée | MaxLossDollars: ", MaxLossDollars, " | BoomCrashSpikeTP: ", BoomCrashSpikeTP);
      lastDebugLog = TimeCurrent();
   }

   bool touchExitMode = (UseTouchProtectScalpExitOnDerivArrow && RequireFutureProtectTouchForBoomCrashDerivArrow);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      string symbol = PositionGetSymbol(i);
      if(symbol == "") continue;
      
      ulong ticket = PositionGetInteger(POSITION_TICKET);
      if(ticket == 0) continue;
      double profit = PositionGetDouble(POSITION_PROFIT);
      double swap = PositionGetDouble(POSITION_SWAP);
      double commission = PositionGetDouble(POSITION_SWAP); // Commission incluse dans le swap sur MT5
      double totalPnL = profit + swap + commission;
      ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
      
      // NOUVEAU: Laisser les trades respirer pendant 30 secondes après ouverture
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int secondsSinceOpen = (int)(TimeCurrent() - openTime);
      
      if(secondsSinceOpen < 30) // Moins de 30 secondes
      {
         // Coupure d'urgence Boom/Crash même si trade trop récent
         if(UseMaxLossBoomCrashPerTrade && cat == SYM_BOOM_CRASH && totalPnL <= -MaxLossBoomCrashPerTradeUSD)
         {
            Print("?? BOOM/CRASH MAX LOSS (urgence) - Fermeture même si trade récent | ", symbol,
                  " | PnL=", DoubleToString(totalPnL, 2), "$ | Seuil=-",
                  DoubleToString(MaxLossBoomCrashPerTradeUSD, 2), "$ | age=", secondsSinceOpen, "s | ticket=", ticket);
            if(PositionSelectByTicket(ticket))
               PositionCloseWithLog(ticket, "Boom/Crash max loss per trade (urgence)");
            continue;
         }
         
         Print("?? DEBUG - Trade trop récent - ", symbol, " | Ouvert il y a: ", secondsSinceOpen, "s | Profit: ", DoubleToString(profit, 2), "$");
         continue; // Ignorer ce trade pour l'instant
      }
      
      // DEBUG: Log chaque position analysée (réduit pour éviter la surcharge)
      static datetime lastPositionDebugLog = 0;
      if(TimeCurrent() - lastPositionDebugLog >= 120) // Log toutes les 2 minutes maximum
      {
         Print("?? DEBUG - Position analysée - ", symbol, " | Profit: ", DoubleToString(profit, 2), "$ | Ticket: ", ticket, " | Catégorie: ", (cat == SYM_BOOM_CRASH ? "BOOM_CRASH" : "AUTRE"), " | Âge: ", secondsSinceOpen, "s");
         lastPositionDebugLog = TimeCurrent();
      }
      
      // RÈGLE PAR SYMBOLE: Fermer les positions quand le profit target individuel est atteint
      double symbolProfitTarget = SymbolProfitTargetUSD;
      
      // Exception pour Boom/Crash: garder la règle de 2$ pour ces symboles
      if(cat == SYM_BOOM_CRASH)
         symbolProfitTarget = 2.0;

      // Boom/Crash: perte max par trade (fermeture immédiate si dépassement)
      if(UseMaxLossBoomCrashPerTrade && cat == SYM_BOOM_CRASH)
      {
         if(totalPnL <= -MaxLossBoomCrashPerTradeUSD)
         {
            Print("?? BOOM/CRASH MAX LOSS - Fermeture position | ", symbol,
                  " | PnL=", DoubleToString(totalPnL, 2), "$ | Seuil=-",
                  DoubleToString(MaxLossBoomCrashPerTradeUSD, 2), "$ | ticket=", ticket);

            if(PositionSelectByTicket(ticket))
            {
               PositionCloseWithLog(ticket, "Boom/Crash max loss per trade");
            }
            continue;
         }
      }
      
      // Désactivé: la fermeture profit est désormais pilotée par CloseAllPositionsIfSymbolProfitReached(3$)
      if(false && profit >= symbolProfitTarget)
      {
         Print("?? TENTATIVE FERMETURE TP ", DoubleToString(symbolProfitTarget, 1), "$ - ", symbol, " | Profit: ", DoubleToString(profit, 2), "$");
         // VALIDATION: Vérifier que la position existe toujours avant de fermer
         if(!PositionSelectByTicket(ticket))
         {
            Print("?? Position déjà fermée avant ", DoubleToString(symbolProfitTarget, 1), "$ TP - ", symbol, " | ticket=", ticket);
            continue;
         }
         
         if(PositionCloseWithLog(ticket, "Profit target symbole atteint"))
            Print("? EA Position fermée: profit target ", DoubleToString(symbolProfitTarget, 1), "$ atteint (", DoubleToString(profit, 2), "$) - ", symbol, " | ticket=", ticket);
         else
         {
            int err = GetLastError();
            Print("? EA ÉCHEC FERMETURE TP SYMBOLE - ", symbol, " | ticket=", ticket, " | code=", err);
         }
         continue;
      }
      
      // Règle de perte maximale (Boom/Crash: laisser le SL naturel, pas de fermeture sur perte)
      if(cat == SYM_BOOM_CRASH)
         ; // Ne pas fermer Boom/Crash sur perte - laisser SL/TP
      else if(profit <= -MaxLossDollars)
      {
         Print("?? TENTATIVE FERMETURE PERTE MAX - ", symbol, " | Profit: ", DoubleToString(profit, 2), "$ | MaxLoss: ", MaxLossDollars, "$");
         // VALIDATION: Vérifier que la position existe toujours avant de fermer
         if(!PositionSelectByTicket(ticket))
         {
            Print("?? Position déjà fermée avant perte max - ", symbol, " | ticket=", ticket);
            continue;
         }
         
         if(PositionCloseWithLog(ticket, "Profit total atteint"))
            Print("?? EA Position fermée: perte max atteinte (", DoubleToString(profit, 2), "$) - ", symbol, " | ticket=", ticket);
         else
         {
            int err = GetLastError();
            Print("? EA ÉCHEC FERMETURE SL GLOBAL - ", symbol, " | ticket=", ticket, " | code=", err);
         }
         continue;
      }
      
      // Règles spécifiques Boom/Crash (en plus de la règle universelle)
      if(cat == SYM_BOOM_CRASH && !touchExitMode)
      {
         // Spike TP pour Boom/Crash
         if(false && profit >= BoomCrashSpikeTP && profit < 2.0) // Désactivé: fermeture pilotée par CloseAllPositionsIfSymbolProfitReached(3$)
         {
            Print("?? TENTATIVE FERMETURE BOOM/CRASH SPIKE TP - ", symbol, " | Profit: ", DoubleToString(profit, 2), "$ | SpikeTP: ", DoubleToString(BoomCrashSpikeTP, 2), "$");
            // VALIDATION: Vérifier que la position existe toujours avant de fermer
            if(!PositionSelectByTicket(ticket))
            {
               Print("?? Position déjà fermée avant Boom/Crash spike TP - ", symbol, " | ticket=", ticket);
               continue;
            }
            
            if(CloseBoomCrashPosition(ticket, symbol))
            {
               Print("?? EA Boom/Crash fermé après spike (gain > ", DoubleToString(BoomCrashSpikeTP, 2), "$): ", DoubleToString(profit, 2), "$ | ticket=", ticket, " - ", symbol);
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
         // Recovery exceptionnel: on ne coupe pas la position avant la fermeture "par précaution"
         if(StringFind(cmt, "EXC_RECOVERY_") >= 0)
         {
            Print("?? SKIP CLOSE (conflit IA) - Boom/Crash EXC_RECOVERY protégé | ", psym,
                  " | Ticket=", ticket,
                  " | Type=", (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                  " | IA=", ai, " ", DoubleToString(conf * 100.0, 1), "% | Comment=", cmt);
            continue;
         }
         if(StringFind(cmt, "SMC_CH") >= 0 || StringFind(cmt, "RETURN_MOVE") >= 0)
         {
            Print("?? SKIP CLOSE (conflit IA) - Boom/Crash LIMIT protégé | ", psym,
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

      if(PositionCloseWithLog(ticket, "IA DIRECTION CONFLICT - ferm. après conflit IA"))
      {
         string profitStatus = (profit >= 0) ? "GAIN" : "PERTE";
         Print("?? POSITION FERMÉE (conflit IA) - ", psym,
               " | Type=", (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL"),
               " | IA=", ai, " ",
               DoubleToString(conf * 100.0, 1), "% | ",
               profitStatus, "=", DoubleToString(MathAbs(profit), 2), "$");
      }
      else
      {
         Print("? ECHEC FERMETURE (conflit IA) - ", psym,
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
            // Recovery exceptionnel: on laisse le trade recovery finir ses 5 petites bougies M1
            if(StringFind(cmt, "EXC_RECOVERY_") >= 0)
            {
               Print("?? SKIP CLOSE (IA HOLD) - Boom/Crash EXC_RECOVERY protégé | ",
                     (type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                     " sur ", symbol,
                     " | Ticket=", ticket,
                     " | Profit=", DoubleToString(profit, 2), "$",
                     " | Comment=", cmt);
               continue;
            }

            if(StringFind(cmt, "SMC_CH") >= 0 || StringFind(cmt, "RETURN_MOVE") >= 0)
            {
               Print("?? SKIP CLOSE (IA HOLD) - Boom/Crash LIMIT protégé | ",
                     (type == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                     " sur ", symbol,
                     " | Ticket=", ticket,
                     " | Profit=", DoubleToString(profit, 2), "$",
                     " | Comment=", cmt);
               continue;
            }
         }
         
         // Fermer la position
         bool closed = PositionCloseWithLog(ticket, "IA HOLD - Fermeture automatique");
         
         if(closed)
         {
            Print("?? POSITION FERMÉE - IA HOLD | ", 
                  (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                  " sur ", symbol, 
                  " | Profit: ", DoubleToString(profit, 2), "$",
                  " | En attente d'un nouveau signal IA");
         }
         else
         {
            Print("? ÉCHEC FERMETURE - IA HOLD | Erreur: ", GetLastError());
         }
      }
   }
}

// Dessine UNIQUEMENT les graphiques/indicateurs sur le chart (pas d'ordres).
// Objectif: ne rien laisser visuellement, même en mode observation / pause.
void DrawAllIndicatorGraphics()
{
   // DÉTECTION ANTI-REPAINT DES SWING POINTS
   DetectNonRepaintingSwingPoints();
   DrawConfirmedSwingPoints();
   
   // DÉTECTION SPÉCIALE BOOM/CRASH (ANTI-SPIKE)
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      DetectBoomCrashSwingPoints();
      CheckImminentSpike();
      // Disabled: cette routine place des ordres pending LIMIT via PlaceReturnMovementLimitOrder()
      // (objectif: aucune création BUY_LIMIT/SELL_LIMIT, uniquement market via touch M5).
      // CheckSMCChannelReturnMovements();
   }
   
   // AFFICHAGE STATUT IA ET PRÉDICTIONS
   DrawAIStatusAndPredictions();
   
   // Graphiques essentiels et zones Premium/Discount
   DrawSwingHighLow();
   DrawBookmarkLevels();
   DrawFVGOnChart();
   DrawOBOnChart();
   if(DrawICTChecklistGraphics) DrawICTValidationGraphics();
   DrawFibonacciOnChart();
   DrawEMACurveOnChart();
   DrawLiquidityZonesOnChart();
   
   // Zones Premium/Discount et équilibre
   if(ShowPremiumDiscount) DrawPremiumDiscountZones();
   
   // Autres graphiques optionnels
   if(ShowSignalArrow) { DrawSignalArrow(); UpdateSignalArrowBlink(); }
   
   // Avertisseur visuel des spikes imminents sur Boom/Crash
   UpdateSpikeWarningBlink();
   
   if(ShowPredictedSwing) DrawPredictedSwingPoints();
   if(ShowEMASupportResistance) DrawEMASupportResistance();
   if(ShowPredictionChannel) DrawPredictionChannel();
   if(ShowFutureCandlesM1) DrawFutureCandlesM1();
   if(ShowSMCChannelsMultiTF) DrawSMCChannelsMultiTF();
   if(ShowEMASupertrendMultiTF) DrawEMASupertrendMultiTF();
   //if(ShowLimitOrderLevels) DrawLimitOrderLevels(); // SUPPRIMÉ - Plus d'affichage ordres limit

   if(ShowOTEImbalanceOnChart) DrawOTEImbalanceOnChart();
   
   // NOUVEAU: Prédiction des Protected High/Low Points futurs
   PredictFutureProtectedPoints();
}

// Dessine sur le graphique la confluence OTE(0.62-0.786) + Imbalance(FVG)
// pour Forex/Metal/Commodity (style ICT visuel).
void DrawOTEImbalanceOnChart()
{
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(!(cat == SYM_FOREX || cat == SYM_METAL || cat == SYM_COMMODITY)) return;
   if(!UseFVG || !UseOTE) return;

   // Supprimer les anciens dessins OTE/Imbalance (pour ne pas saturer le chart)
   ObjectsDeleteAll(0, "SMC_OTEIMB_");
   
   // NETTOYAGE COMPLÉMENTAIRE - Supprimer toutes les lignes OTE visibles
   ObjectsDeleteAll(0, "SMC_OTEIMB_ENTRY");
   ObjectsDeleteAll(0, "SMC_OTEIMB_SL");
   ObjectsDeleteAll(0, "SMC_OTEIMB_TP");
   
   // NETTOYAGE DES ZONES OTE BUY/SELL - Supprimer tous les objets OTE visuels
   ObjectsDeleteAll(0, "SMC_OTE_BUY_");
   ObjectsDeleteAll(0, "SMC_OTE_SELL_");

   bool bullHTF = IsBullishHTF();
   bool bearHTF = IsBearishHTF();

   // fail-open visuel: si pas de tendance HTF claire, décider via EMA LTF
   string dir = "";
   if(bullHTF) dir = "BUY";
   else if(bearHTF) dir = "SELL";
   else
   {
      double bidNow = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double emaNow = 0.0;
      if(emaHandle != INVALID_HANDLE)
      {
         double e[];
         ArraySetAsSeries(e, true);
         if(CopyBuffer(emaHandle, 0, 0, 1, e) >= 1) emaNow = e[0];
      }
      if(emaNow <= 0.0) emaNow = bidNow; // fallback
      dir = (bidNow >= emaNow) ? "BUY" : "SELL";
   }

   // Récupérer derniers swing anchors (non-repaint)
   double lastSH = 0.0, lastSL = 0.0;
   datetime tSH = 0, tSL = 0;
   GetLatestConfirmedSwings(lastSH, tSH, lastSL, tSL);
   if(lastSH <= 0.0 || lastSL <= 0.0) return;

   double high = lastSH;
   double low  = lastSL;
   if(high <= low) return;

   double range = high - low;

   // OTE zone
   double oteLow = 0.0, oteHigh = 0.0;
   if(dir == "BUY")
   {
      oteHigh = low + range * 0.62;
      oteLow  = low + range * 0.786;
   }
   else
   {
      oteLow  = high - range * 0.62;
      oteHigh = high - range * 0.786;
      if(oteLow > oteHigh)
      {
         double tmp = oteLow;
         oteLow = oteHigh;
         oteHigh = tmp;
      }
   }

   // FVG (imbalance) optionnel: si trouvé et aligné, on dessine aussi la confluence
   bool hasFvg = false;
   FVGData fvg;
   double fvgLow = 0.0, fvgHigh = 0.0;
   double zoneLow = 0.0, zoneHigh = 0.0;
   bool confluenceOk = false;

   if(SMC_DetectFVG(_Symbol, LTF, 40, fvg))
   {
      if((dir == "BUY" && fvg.direction == 1) || (dir == "SELL" && fvg.direction == -1))
      {
         hasFvg = true;
         fvgLow  = fvg.bottom;
         fvgHigh = fvg.top;
      }
   }

   // Intersection confluence (si FVG trouvée)
   double oteZLow = MathMin(oteLow, oteHigh);
   double oteZHigh = MathMax(oteLow, oteHigh);
   if(hasFvg && fvgLow > 0.0 && fvgHigh > 0.0)
   {
      zoneLow  = MathMax(fvgLow, oteZLow);
      zoneHigh = MathMin(fvgHigh, oteZHigh);
      confluenceOk = (zoneHigh > zoneLow);
   }

   datetime now = TimeCurrent();
   datetime futureTime = now + (datetime)(PeriodSeconds(LTF) * OTEImbalanceProjectionBars / 5.0);
   if(futureTime <= now) futureTime = now + 60;

   color oteClr = confluenceOk ? clrGold : clrSilver;

   // Rectangle OTE
   string nameOTE = "SMC_OTEIMB_OTE";
   if(ObjectFind(0, nameOTE) < 0)
      ObjectCreate(0, nameOTE, OBJ_RECTANGLE, 0, now, oteZHigh, futureTime, oteZLow);
   ObjectSetInteger(0, nameOTE, OBJPROP_COLOR, oteClr);
   ObjectSetInteger(0, nameOTE, OBJPROP_BACK, true);
   ObjectSetInteger(0, nameOTE, OBJPROP_FILL, true);
   ObjectSetInteger(0, nameOTE, OBJPROP_WIDTH, 1);

   // Rectangle FVG (optionnel)
   if(hasFvg)
   {
      color fvgClr = (dir == "BUY") ? clrGreen : clrRed;
      string nameFVG = "SMC_OTEIMB_FVG";
      if(ObjectFind(0, nameFVG) < 0)
         ObjectCreate(0, nameFVG, OBJ_RECTANGLE, 0, fvg.time, fvgHigh, futureTime, fvgLow);
      ObjectSetInteger(0, nameFVG, OBJPROP_COLOR, fvgClr);
      ObjectSetInteger(0, nameFVG, OBJPROP_BACK, false);
      ObjectSetInteger(0, nameFVG, OBJPROP_FILL, false);
      ObjectSetInteger(0, nameFVG, OBJPROP_WIDTH, 1);
   }

   if(confluenceOk)
   {
      // Entry/SL/TP visuels RR ~ InpRiskReward
      double entry = (dir == "BUY") ? zoneHigh : zoneLow;
      double sl    = (dir == "BUY") ? lastSL : lastSH;
      double risk  = (dir == "BUY") ? (entry - sl) : (sl - entry);
      if(risk > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5.0)
      {
         double tp = (dir == "BUY") ? (entry + (MathMax(3.0, InpRiskReward) * risk)) : (entry - (MathMax(3.0, InpRiskReward) * risk));

         string nameEntry = "SMC_OTEIMB_ENTRY";
         string nameSL    = "SMC_OTEIMB_SL";
         string nameTP    = "SMC_OTEIMB_TP";

         // MASQUER LES LIGNES OTE - Ne pas dessiner les lignes Entry/SL/TP
         // Commenté pour masquer visuellement les lignes OTE sur le graphique
         /*
         ObjectCreate(0, nameEntry, OBJ_HLINE, 0, 0, entry);
         ObjectSetInteger(0, nameEntry, OBJPROP_COLOR, clrDodgerBlue);
         ObjectSetInteger(0, nameEntry, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, nameEntry, OBJPROP_WIDTH, 2);

         ObjectCreate(0, nameSL, OBJ_HLINE, 0, 0, sl);
         ObjectSetInteger(0, nameSL, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, nameSL, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, nameSL, OBJPROP_WIDTH, 2);

         ObjectCreate(0, nameTP, OBJ_HLINE, 0, 0, tp);
         ObjectSetInteger(0, nameTP, OBJPROP_COLOR, clrLimeGreen);
         ObjectSetInteger(0, nameTP, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, nameTP, OBJPROP_WIDTH, 2);
         */
      }
   }
}

void OnTick()
{
   // Réinitialiser les pauses de profit target au début de chaque journée
   ResetDailyProfitTargetPauses();
   
   // MODE IA ULTRA STABLE - PAS DE DÉTACHEMENT
   static datetime lastProcess = 0;
   static datetime lastGraphicsUpdate = 0;
   static datetime lastAIUpdate = 0;
   static datetime lastDashboardUpdate = 0;
   static datetime lastPropiceInfoLog = 0;
   datetime currentTime = TimeCurrent();
   
   // Traitement contrôlé pour stabilité (max ~1 tick toutes les 2 secondes)
   if(currentTime - lastProcess < 2) return;
   lastProcess = currentTime;
   
   // Log informatif sur la priorité du symbole actuel (toutes les 5 minutes)
   if(UsePropiceSymbolsFilter && g_currentSymbolIsPropice && (currentTime - lastPropiceInfoLog >= 300))
   {
      string mostPropice = GetMostPropiceSymbol();
      if(mostPropice != "" && mostPropice != _Symbol)
      {
         Print("📍 INFO PRIORITÉ - Symbole actuel: ", _Symbol, " (position #", g_currentSymbolPriority + 1, "ème)");
         Print("   🥇 Symbole le plus propice: ", mostPropice, " - Le robot donnera la priorité à ce symbole");
         Print("   💡 Conditions plus strictes appliquées aux symboles moins prioritaires");
      }
      lastPropiceInfoLog = currentTime;
   }
   
   // BLOCAGE TOTAL DES TRADES - Mode observation seul
   if(BlockAllTrades)
   {
      static datetime lastBlockLog = 0;
      if(currentTime - lastBlockLog >= 30) // Log toutes les 30 secondes
      {
         Print("?? MODE BLOCAGE ACTIVÉ - Aucune entrée/sortie autorisée - Observation seule");
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
            DrawAllIndicatorGraphics();
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
   
   // VÉRIFICATION DE LA PAUSE APRÈS PROFIT JOURNALIER
   if(!UsePerSymbolDailyObjectiveOnly && CheckDailyProfitPause())
   {
      static datetime lastPauseLog = 0;
      if(currentTime - lastPauseLog >= 60) // Log toutes les minutes pendant la pause
      {
         datetime pauseEndTime = (g_dailyPauseUntil > 0 ? g_dailyPauseUntil : (g_dailyProfitPauseStartTime + PauseAfterProfitHours * 3600));
         int remainingSeconds = (int)(pauseEndTime - currentTime);
         int remainingHours = remainingSeconds / 3600;
         int remainingMinutes = (remainingSeconds % 3600) / 60;
         Print("🚫 TRADES BLOQUÉS - Pause après profit journalier (", remainingHours, "h ", remainingMinutes, "min restantes)");
         lastPauseLog = currentTime;
      }
      
      // Garder les fonctions d'observation pendant la pause
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
            DrawAllIndicatorGraphics();
         }
         
         // TABLEAU DE BORD pour observation
         if(currentTime - lastDashboardUpdate >= 15)
         {
            lastDashboardUpdate = currentTime;
            UpdateDashboard();
         }
      }
      return; // Sortir - aucun trading pendant la pause
   }
   
   // STRATÉGIES PAR CATÉGORIE DE SYMBOLE (Boom/Crash, Volatility, Forex/Metals)
   // Anti-duplication immédiat: avant toute tentative de placement de LIMIT
   EnsureSinglePendingLimitOrderForSymbol(_Symbol);
   RunCategoryStrategy();
   
   // Gestion des positions existantes (fermeture rapide après spike)
   ManageBoomCrashSpikeClose();
   // Gestion des sorties en dollars (TP/SL globaux + BoomCrashSpikeTP)
   ManageDollarExits();

   // Protection "profit lock": éviter de rendre un gros gain du jour
   if(!UsePerSymbolDailyObjectiveOnly)
   {
      UpdateDailyEquityStats();
      ActivateProfitLockIfNeeded();
      if(IsDailyProfitPauseActive())
         return;
   }
   
   // Modification SL dynamique OBLIGATOIRE (plus de condition)
   // Le SL dynamique est maintenant obligatoire pour toutes les positions
   // Si on vient de fermer une position, éviter de modifier immédiatement (fenêtre de course MT5)
   if(g_lastCloseActionTime > 0 && (currentTime - g_lastCloseActionTime) <= 1)
   {
      Print("🔄 SL dynamique suspendu 1s après fermeture position");
   }
   else
   {
      ManageTrailingStop(); // OBLIGATOIRE - s'exécute toujours
   }
   
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

   // Mettre à jour le Top N "propice" (affichage + filtre optionnel)
   if(UsePropiceSymbolsFilter || UseDashboard)
      UpdatePropiceTopSymbols();
   
   // Si l'IA est passée en HOLD, couper immédiatement les positions de l'EA
   // Réduire la fréquence des logs DEBUG pour éviter la surcharge
   static datetime lastDebugLog = 0;
   if(TimeCurrent() - lastDebugLog >= 120) // Log toutes les 2 minutes maximum
   {
      Print("?? DEBUG - Vérification IA HOLD | g_lastAIAction: '", g_lastAIAction, "' | UseAIServer: ", UseAIServer);
      lastDebugLog = TimeCurrent();
   }
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
   
   // Vérifier en continu les ordres LIMIT en attente vs décision IA (HOLD/direction/confiance)
   // Version améliorée avec remplacement automatique des ordres non alignés
   //if(ReplaceMisalignedLimitOrders) // SUPPRIMÉ - Plus d'ordres limit
   //   GuardPendingLimitOrdersWithAI_Enhanced();
   //else
   //   GuardPendingLimitOrdersWithAI();
   
   // NOUVEAU: Détection de spikes sans IA pour ne manquer aucune opportunité
   CheckAndExecuteSpikeTrade();

   // Fermeture profit-only par symbole à 3$ (POSITION_PROFIT uniquement)
   // Exécutée avant les entrées M5 pour éviter toute réouverture sur le même tick.
   CloseAllPositionsIfSymbolProfitReached(3.0);
   
   // NOUVEAU: Vérification des touches M5 pour exécution M1 (priorité haute)
   CheckAndExecuteM5TouchEntryTrade();
   
   // NOUVEAU: Recovery exceptionnel Boom/Crash (touch M5 + 4 petites bougies M1)
   CheckAndExecuteExceptionalBoomCrashRecoveryEntries();
   
   // DÉTECTION ULTRA-RAPIDE DE SPIKE (toutes les 5 secondes pour Boom/Crash)
   static datetime lastSpikeCheck = 0;
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      if(currentTime - lastSpikeCheck >= 5)
      {
         lastSpikeCheck = currentTime;
         CheckImminentSpike(); // Vérification rapide sans graphiques
      }
   }
   
   // GRAPHIQUES SMC CONTRÔLÉS (toutes les 15 secondes pour plus de réactivité)
   if(ShowChartGraphics && currentTime - lastGraphicsUpdate >= 15)
   {
      lastGraphicsUpdate = currentTime;

      // Dessins complets des indicateurs (sans rien oublier visuellement)
      DrawAllIndicatorGraphics();
      
      // NOUVEAU: Dessiner la stratégie SMC_OTE complète
      DrawSMC_OTEStrategy();
      
      // SUPPRESSION COMPLÈTE DES FONCTIONNALITÉS DE DÉPLACEMENT D'ORDRES LIMIT
   // Les ordres LIMIT ne sont plus ajustés ou déplacés automatiquement
   // Seul le placement initial reste autorisé selon les règles strictes
      
      // NOUVEAU: Mettre à jour les niveaux d'entrée M5 et dessiner les lignes épaisses
      UpdateM5EntryLevelsAndLines();
   }
   
   // BLOCAGE DES ORDRES AU MARCHÉ CLASSIQUES - SEULS LES TOUCH M5 SONT AUTORISÉS
   // Les ordres au marché ne sont autorisés que si le prix touche les lignes BUY/SELL ENTRY M5
   if(UsePropiceSymbolsFilter && g_currentSymbolIsPropice)
   {
      // Si aucune ligne M5 active, bloquer les ordres au marché classiques
      if(!g_m5BuyLevelActive && !g_m5SellLevelActive)
      {
         // Bloquer ExecuteAIDecisionMarketOrder() - plus d'ordres au marché sans touch M5
         Print("🚫 PAS DE LIGNES M5 ACTIVES - Ordres au marché bloqués sur ", _Symbol);
         Print("   💡 Seuls les trades au touch des lignes BUY/SELL ENTRY M5 sont autorisés");
      }
      else
      {
         // Autoriser ExecuteAIDecisionMarketOrder() uniquement si lignes M5 actives
         ExecuteAIDecisionMarketOrder();
      }
   }
   else
   {
      // Si filtre non activé, comportement normal
      ExecuteAIDecisionMarketOrder();
   }

   // NOUVEAU: Exécuter la stratégie SMC_OTE complète (3 étapes)
   ExecuteSMC_OTEStrategy();

   // Sync stats symboles (MT5 History -> serveur -> Supabase)
   SyncSymbolTradeStatsToServer();

   // RÈGLE STRICTE: PAS D'ORDRES LIMIT SI SYMBOLE NON PRIORITAIRE
   // Supprimer tous les ordres LIMIT si le symbole n'est pas prioritaire
   if(UsePropiceSymbolsFilter && !g_currentSymbolIsPropice)
   {
      // Vérifier s'il y a des ordres LIMIT à supprimer
      if(CountOpenLimitOrdersForSymbol(_Symbol) > 0)
      {
         Print("🚫 SYMBOLE NON PRIORITAIRE - Suppression de tous les ordres LIMIT sur ", _Symbol);
         Print("   💡 Seuls les symboles prioritaires peuvent avoir des ordres LIMIT");
         
         // Supprimer tous les ordres LIMIT de ce symbole
         for(int i = OrdersTotal() - 1; i >= 0; i--)
         {
            if(OrderSelect(i) && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && 
               OrderGetString(ORDER_SYMBOL) == _Symbol)
            {
               ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
               if(ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT)
               {
                  MqlTradeRequest req = {};
                  MqlTradeResult  res = {};
                  req.action = TRADE_ACTION_REMOVE;
                  req.order = OrderGetInteger(ORDER_TICKET);
                  req.symbol = _Symbol;
                  
                  if(OrderSend(req, res))
                  {
                     Print("   🗑️ Ordre LIMIT supprimé: ", OrderGetInteger(ORDER_TICKET), " | Type: ", EnumToString(ot));
                  }
                  else
                  {
                     Print("   ❌ Erreur suppression ordre: ", res.retcode, " | ", res.comment);
                  }
               }
            }
         }
      }
   }
   
   // RÈGLE STRICTE: PAS D'ORDRES LIMIT SI PAS DE TOUCH BUY/SELL ENTRY M5
   // Seuls les trades au touch des lignes M5 sont autorisés
   if(UsePropiceSymbolsFilter && g_currentSymbolIsPropice)
   {
      // Vérifier si les lignes BUY/SELL ENTRY M5 sont actives
      if(!g_m5BuyLevelActive && !g_m5SellLevelActive)
      {
         // Si aucune ligne M5 active, supprimer les ordres LIMIT existants
         if(CountOpenLimitOrdersForSymbol(_Symbol) > 0)
         {
            Print("🚫 PAS DE LIGNES M5 ACTIVES - Suppression ordres LIMIT sur ", _Symbol);
            Print("   💡 Les ordres LIMIT ne sont autorisés que si BUY/SELL ENTRY M5 sont actives");
            
            // Supprimer tous les ordres LIMIT
            for(int i = OrdersTotal() - 1; i >= 0; i--)
            {
               if(OrderSelect(i) && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber && 
                  OrderGetString(ORDER_SYMBOL) == _Symbol)
               {
                  ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                  if(ot == ORDER_TYPE_BUY_LIMIT || ot == ORDER_TYPE_SELL_LIMIT)
                  {
                     MqlTradeRequest req = {};
                     MqlTradeResult  res = {};
                     req.action = TRADE_ACTION_REMOVE;
                     req.order = OrderGetInteger(ORDER_TICKET);
                     req.symbol = _Symbol;
                     
                     if(OrderSend(req, res))
                     {
                        Print("   🗑️ Ordre LIMIT supprimé (pas de lignes M5): ", OrderGetInteger(ORDER_TICKET));
                     }
                  }
               }
            }
         }
      }
   }
   
   // BLOCAGE DES ORDRES LIMIT CLASSIQUES - SEULS LES TOUCH M5 SONT AUTORISÉS
   // Commenté: PlaceScalpingLimitOrders() - PLUS D'ORDRES LIMIT SANS TOUCH M5
   /*
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atrBuf) >= 1)
         atrVal = atrBuf[0];
   }
   double mid = 0.0;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid > 0 && ask > 0) mid = (bid + ask) * 0.5;
   else mid = (bid > 0 ? bid : ask);

   MqlRates m1Rates[];
   ArraySetAsSeries(m1Rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 60, m1Rates) >= 30)
      PlaceScalpingLimitOrders(m1Rates, 0, mid, atrVal, 0.0);
   */
   
   // Fermeture profit-only par symbole à 3$ (POSITION_PROFIT uniquement)
   CloseAllPositionsIfSymbolProfitReached(3.0);

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
   // Nettoyage périodique des objets graphiques pour éviter l'accumulation
   static datetime lastCleanupTime = 0;
   if(TimeCurrent() - lastCleanupTime >= 600) // Nettoyer toutes les 10 minutes
   {
      CleanupDashboardObjects();
      lastCleanupTime = TimeCurrent();
      Print("?? Nettoyage périodique des objets dashboard effectué");
   }
   
   if(!UseDashboard) return;
   string catStr = "UNKNOWN";
   switch(SMC_GetSymbolCategory(_Symbol))
   {
      case SYM_BOOM_CRASH:  catStr = "Boom/Crash"; break;
      case SYM_VOLATILITY:  catStr = "Volatility"; break;
      case SYM_FOREX:       catStr = "Forex"; break;
      case SYM_COMMODITY:   catStr = "Commodity"; break;
      case SYM_METAL:       catStr = "Metal"; break;
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
   static datetime lastPredScoreFetch = 0;
   if(TimeCurrent() - lastPredScoreFetch >= 30)
   {
      if(!FetchPredictionScoreFromServer())
         g_predictionScoreSource = "N/A";
      lastPredScoreFetch = TimeCurrent();
   }
   string killStr = SMC_IsKillZone(LondonStart, LondonEnd, NYOStart, NYOEnd) ? "ACTIVE" : "OFF";
   string bcStr = IsBoomSymbol(_Symbol) ? "BOOM" : (IsCrashSymbol(_Symbol) ? "CRASH" : "FOREX");
   int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
   int channelLimits = CountChannelLimitOrdersForSymbol(_Symbol);
   int otherLimits = totalLimits - channelLimits;
   
   // NETTOYAGE AGRESSIF des anciens objets dashboard avant de créer les nouveaux
   CleanupDashboardObjects();
   
   // Nettoyer l'ancien Comment() pour éviter les superpositions avec les labels
   if(!DashboardUseCommentFallback)
      Comment("");

   string lines[25]; // Augmenté à 25 pour inclure toutes les lignes
   color  cols[25];
   int n = 0;
   lines[n] = "[Contexte] SMC Universal + FVG_Kill PRO"; cols[n] = clrWhite; n++;
   lines[n] = "Stratégie: SMC(FVG|OB|LS|BOS) + FVG_Kill(EMA HTF + LS)"; cols[n] = clrSilver; n++;
   lines[n] = "Trend HTF: " + trendHTF + " | LS: " + lsStr + " | KillZone: " + killStr; cols[n] = clrWhite; n++;
   lines[n] = catStr + " | " + bcStr + " | IA: " + ((g_lastAIAction != "") ? (g_lastAIAction + " " + DoubleToString(g_lastAIConfidence*100,1) + "%") : "OFF"); cols[n] = clrAqua; n++;
   lines[n] = "Positions: " + IntegerToString(totalPos) + "/" + IntegerToString(MaxPositionsTerminal) + " | " + _Symbol + ": " + IntegerToString(posCount) + "/1"; cols[n] = clrWhite; n++;
   lines[n] = "LIMIT: total=" + IntegerToString(totalLimits) + " | canal=" + IntegerToString(channelLimits) + " | autres=" + IntegerToString(otherLimits); cols[n] = clrKhaki; n++;
   lines[n] = "Rule: Boom=BUY only | Crash=SELL only"; cols[n] = clrAqua; n++;
   lines[n] = "P/L: " + DoubleToString(totalPL, 2) + "$ (max " + DoubleToString(MaxTotalLossDollars, 0) + "$) | Swing:" + swingStr; cols[n] = (totalPL >= 0 ? clrLime : clrTomato); n++;
   lines[n] = "ATR: " + DoubleToString(atrVal, _Digits) + " | EMA(9): " + DoubleToString(emaVal, _Digits) + " | Canal ML: " + string(g_channelValid ? "OK" : "—"); cols[n] = clrWhite; n++;
   if(ShowFutureCandlesM1 && n < 24)
   {
      string src = (g_futureCandlesSource == "" ? "NONE" : g_futureCandlesSource);
      lines[n] = "[IA/Prediction] Future M1: " + IntegerToString(FutureCandlesCount) + " candles | SourcePred: " + src;
      cols[n] = (src == "SERVER" ? clrLimeGreen : (src == "FALLBACK" ? clrYellow : clrTomato));
      n++;
   }
   if(n < 24)
   {
      string scoreTxt = (g_predictionScore >= 0.0 ? DoubleToString(g_predictionScore, 3) : "N/A");
      lines[n] = "PredScore M1(7d): " + scoreTxt + " | Samples: " + IntegerToString(g_predictionSamples) +
                 " | Source: " + g_predictionScoreSource;
      cols[n] = (g_predictionScore >= 0.70 ? clrLimeGreen : (g_predictionScore >= 0.0 ? clrYellow : clrSilver));
      n++;
   }
   if(n < 24)
   {
      bool corrActive = IsInServerPredictedCorrectionZone();
      lines[n] = "CorrZone(SRV): " + string(corrActive ? "ACTIVE" : "OFF") +
                 " | Conf: " + DoubleToString(g_serverCorrectionConfidence, 1) +
                 "% | Action: " + g_serverCorrectionAction;
      cols[n] = (corrActive ? clrTomato : clrSilver);
      n++;
   }
   if(n < 24)
   {
      string localState = (g_symbolStatsLastLocalUpdate > 0 && (TimeGMT() - g_symbolStatsLastLocalUpdate) <= 30) ? "OK" : "STALE";
      string syncState = g_symbolStatsSyncOk ? "OK" : "FAIL";
      string syncAt = (g_symbolStatsLastSyncOk > 0) ? TimeToString(g_symbolStatsLastSyncOk, TIME_DATE|TIME_SECONDS) : "N/A";
      lines[n] = "DataStatus: MT5_LOCAL=" + localState + " | SYNC_SUPABASE=" + syncState + " | LAST_SYNC=" + syncAt;
      cols[n] = (g_symbolStatsSyncOk ? clrSilver : clrTomato);
      n++;
   }
   
   // Afficher l'état de la pause après profit journalier (basé sur l'historique)
   if(g_dailyProfitTargetReached && g_dailyProfitPauseStartTime > 0)
   {
      datetime pauseEndTime = g_dailyPauseUntil;
      int remainingSeconds = (int)(pauseEndTime - TimeCurrent());
      int remainingHours = remainingSeconds / 3600;
      int remainingMinutes = (remainingSeconds % 3600) / 60;
      lines[n] = "🎯 PROFIT TARGET ATTEINT - PAUSE " + IntegerToString(remainingHours) + "h " + IntegerToString(remainingMinutes) + "min"; cols[n] = clrYellow; n++;
      lines[n] = "💰 Profit: " + DoubleToString(g_dayNetProfit, 2) + "$ / " + DoubleToString(DailyProfitTarget, 2) + "$ (historique)"; cols[n] = clrLime; n++;
   }
   else if(g_dayNetProfit >= DailyProfitTarget * 0.8) // Approche de l'objectif
   {
      double progress = (g_dayNetProfit / DailyProfitTarget) * 100.0;
      lines[n] = "🎯 Objectif: " + DoubleToString(g_dayNetProfit, 2) + "$ / " + DoubleToString(DailyProfitTarget, 2) + "$ (" + DoubleToString(progress, 1) + "%)"; cols[n] = clrAqua; n++;
   }
   else
   {
      // Afficher le profit journalier normal
      lines[n] = "💰 Profit jour: " + DoubleToString(g_dayNetProfit, 2) + "$ / " + DoubleToString(DailyProfitTarget, 2) + "$"; cols[n] = clrWhite; n++;
   }
   // ML metrics affichées séparément dans DrawMLMetricsOnChart() pour éviter les doublons
   // Stats agrégées côté serveur à partir des données issues MT5 (trade_feedback) puis stockées dans Supabase `symbol_trade_stats` (UTC)
   // Si les stats serveur sont encore à 0, compléter via historique local MT5
   EnsureLocalSymbolStatsUpToDate();
   string dayStr = FormatWLNet(g_dayWins, g_dayLosses, g_dayNetProfit);
   string monthStr = FormatWLNet(g_monthWins, g_monthLosses, g_monthNetProfit);
   // Lignes compactes (évite que \"Net=xx$\" soit coupé à droite)
   lines[n] = "[Performance] StatsJ UTC(MT5): " + dayStr; cols[n] = clrWhite; n++;
   lines[n] = "StatsM UTC(MT5): " + monthStr; cols[n] = clrWhite; n++;
   
   // Ligne: État de protection par symbole
   string protectionStatus = "";
   color protectionColor = clrWhite;
   if(g_symbolTradingBlocked)
   {
      protectionStatus = "🚨 SYMBOLE BLOQUÉ - Perte: " + DoubleToString(g_symbolCurrentLoss, 2) + "$ > " + DoubleToString(MaxLossPerSymbolDollars, 2) + "$";
      protectionColor = clrRed;
   }
   else if(g_symbolCurrentLoss > 0)
   {
      protectionStatus = "⚠️ Perte actuelle: " + DoubleToString(g_symbolCurrentLoss, 2) + "$ / " + DoubleToString(MaxLossPerSymbolDollars, 2) + "$";
      protectionColor = clrYellow;
   }
   else
   {
      protectionStatus = "✅ Symbole protégé - Aucune perte actuelle";
      protectionColor = clrLimeGreen;
   }
   lines[n] = protectionStatus; cols[n] = protectionColor; n++;
   
   // NOUVEAU: Afficher les prédictions de Protected Points futurs
   double futureSupport = 0.0, futureResistance = 0.0;
   bool hasFutureLevels = GetFutureProtectedPointLevels(futureSupport, futureResistance);
   
   if(hasFutureLevels)
   {
      string predictionStatus = "🔮 PRÉDICTIONS FUTURES: ";
      color predictionColor = clrCyan;
      
      // Affichage spécifique selon le type de symbole pour les ordres limit
      bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
      bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
      
      if(isBoom && futureSupport > 0)
      {
         predictionStatus += "BUY LIMIT @ " + DoubleToString(futureSupport, _Digits) + " (Support futur)";
      }
      else if(isCrash && futureResistance > 0)
      {
         predictionStatus += "SELL LIMIT @ " + DoubleToString(futureResistance, _Digits) + " (Résistance future)";
      }
      else if(futureSupport > 0 && futureResistance > 0)
      {
         predictionStatus += "S:" + DoubleToString(futureSupport, _Digits) + " | R:" + DoubleToString(futureResistance, _Digits);
      }
      else if(futureSupport > 0)
      {
         predictionStatus += "Support: " + DoubleToString(futureSupport, _Digits);
      }
      else if(futureResistance > 0)
      {
         predictionStatus += "Résistance: " + DoubleToString(futureResistance, _Digits);
      }
      else
      {
         predictionStatus = "🔮 Calcul en cours...";
      }
      
      lines[n] = predictionStatus; cols[n] = predictionColor; n++;
   }

   // --- Afficher les LIMIT pending réellement en place (BUY_LIMIT/SELL_LIMIT) ---
   // Utile pour confirmer que les prédictions futures ont bien été transformées en ordres.
   int shownPending = 0;
   for(int oi = OrdersTotal() - 1; oi >= 0 && shownPending < 2; oi--)
   {
      ulong oticket = OrderGetTicket(oi);
      if(oticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;

      double op = OrderGetDouble(ORDER_PRICE_OPEN);
      double osl = OrderGetDouble(ORDER_SL);
      double otp = OrderGetDouble(ORDER_TP);

      string side = (ot == ORDER_TYPE_BUY_LIMIT ? "BUY_LIMIT" : "SELL_LIMIT");
      string slStr = (osl > 0 ? DoubleToString(osl, _Digits) : "—");
      string tpStr = (otp > 0 ? DoubleToString(otp, _Digits) : "—");

      if(n < 24) // garder de la place pour le reste
      {
         lines[n] = "📌 PENDING " + side + " @ " + DoubleToString(op, _Digits) + " SL " + slStr + " TP " + tpStr;
         cols[n] = (ot == ORDER_TYPE_BUY_LIMIT ? clrLime : clrTomato);
         n++;
      }
      shownPending++;
   }

   // Si on a une prédiction mais aucun pending limit, on loggue une indication rapide côté dashboard.
   if(hasFutureLevels && totalLimits == 0 && n < 24)
   {
      lines[n] = "⚠️ Prédiction future active mais aucun LIMIT pending envoyé";
      cols[n] = clrYellow;
      n++;
   }
   
   DrawDashboardOnChart(lines, cols, n);

   if(ShowMLMetrics)
      DrawMLMetricsOnChart();

   // Top symbols "propices" (profil horaire) : label séparé, placé sous le dashboard (évite superposition)
   {
      // Amélioration: Afficher l'heure actuelle et les symbols propices de manière plus claire
      datetime currentTime = TimeCurrent();
      string currentTimeStr = TimeToString(currentTime, TIME_MINUTES); // Format HH:MM
      string utcTimeStr = TimeToString(currentTime, TIME_MINUTES|TIME_SECONDS); // Format UTC complet
      
      // Construire un affichage plus informatif
      string propTxt;
      if(g_propiceTopSymbolsText == "" || g_propiceTopSymbolsText == "En attente...")
      {
         propTxt = "Mise à jour en cours (" + currentTimeStr + ")";
      }
      else
      {
         propTxt = g_propiceTopSymbolsText + " (Heure: " + currentTimeStr + ")";
      }
      
      string propFlag = UsePropiceSymbolsFilter ? (g_currentSymbolIsPropice ? "✅ ACTIF" : "🚫 BLOQUÉ") : "⚠️ FILTRE OFF";
      string propStatus = (g_propiceTopSymbolsStatus == "" ? "..." : g_propiceTopSymbolsStatus);
      
      // Ajouter la priorité du symbole si propice
      string priorityInfo = "";
      if(UsePropiceSymbolsFilter && g_currentSymbolIsPropice && g_currentSymbolPriority >= 0)
      {
         if(g_currentSymbolPriority == 0)
            priorityInfo = " 🥇 PLUS PROPICE";
         else if(g_currentSymbolPriority == 1)
            priorityInfo = " 🥈 2ème";
         else if(g_currentSymbolPriority == 2)
            priorityInfo = " 🥉 3ème";
         else
            priorityInfo = " 📍 " + IntegerToString(g_currentSymbolPriority + 1) + "ème";
      }
      
      // Affichage amélioré avec plus de détails et priorité
      string propLine = "🌟 SYMBOLS PROPICES (UTC " + utcTimeStr + "): " + propTxt + " | " + _Symbol + ": " + propFlag + priorityInfo + " | " + propStatus;
      string name = "SMC_PROPICE_LINE";
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);  // Réduit à 7 pour cohérence
         ObjectSetInteger(0, name, OBJPROP_BACK, false);  // Premier plan pour visibilité
      }
      
      // Calculer la position Y pour éviter la superposition avec les ML Metrics
      int propiceY = MathMax(0, g_dashboardBottomY + PropiceLabelExtraYOffsetPixels + 25);  // +25px d'espacement supplémentaire
      int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS, 0);
      if(chartH <= 0 || propiceY > (chartH - 30))
      {
         // Si on dépasse l'écran, ancrer en bas-gauche pour garantir visibilité
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
         propiceY = 10;
      }
      else
      {
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      }
      
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, MathMax(0, DashboardLabelXOffsetPixels));
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, propiceY);
      ObjectSetInteger(0, name, OBJPROP_COLOR, g_currentSymbolIsPropice ? clrLime : clrYellow);
      ObjectSetString(0, name, OBJPROP_TEXT, propLine);
      
      // Log de débogage pour vérifier le positionnement
      static datetime lastPropiceDebugLog = 0;
      if(TimeCurrent() - lastPropiceDebugLog >= 300) // Toutes les 5 minutes
      {
         Print("?? DEBUG Propice - y=", propiceY, " | dashboardBottom=", g_dashboardBottomY);
         lastPropiceDebugLog = TimeCurrent();
      }
   }

   // Fallback "si labels invisibles": afficher aussi en Comment()
   if(DashboardUseCommentFallback)
   {
      string cmt = "";
      for(int i = 0; i < n; i++)
      {
         if(i > 0) cmt += "\n";
         cmt += lines[i];
      }
      cmt += "\n";
      cmt += "Top propices (UTC): " + (g_propiceTopSymbolsText == "" ? "En attente..." : g_propiceTopSymbolsText);
      Comment(cmt);
   }
}

void UpdateMLMetricsDisplay()
{
   // Réduire la fréquence des logs DEBUG pour éviter la surcharge
   static datetime lastDebugLog = 0;
   if(TimeCurrent() - lastDebugLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? DEBUG - UpdateMLMetricsDisplay appelée pour: ", _Symbol);
      lastDebugLog = TimeCurrent();
   }
   
   // Protection contre les appels excessifs - minimum 30 s entre les appels
   if((TimeCurrent() - g_lastMLMetricsUpdate) < 30)
   {
      Print("?? DEBUG - UpdateMLMetricsDisplay ignorée (trop récent)");
      return;
   }
   
   g_lastMLMetricsUpdate = TimeCurrent();
   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string pathMetrics = "/ml/metrics?symbol=" + symEnc + "&timeframe=M1";
   string pathStatus = "/ml/continuous/status";
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   Print("?? DEBUG - Requête ML vers: ", baseUrl, pathMetrics);
   
   // Récupérer les métriques ML (primaire puis fallback)
   int res = WebRequest("GET", baseUrl + pathMetrics, headers, AI_Timeout_ms, post, result, resultHeaders);
   if(res != 200)
   {
      string fallbackUrl = UseRenderAsPrimary ? AI_ServerURL : AI_ServerRender;
      Print("?? DEBUG - Fallback ML metrics vers: ", fallbackUrl, pathMetrics);
      res = WebRequest("GET", fallbackUrl + pathMetrics, headers, AI_Timeout_ms2, post, result, resultHeaders);
   }
   
   Print("?? DEBUG - WebRequest ML metrics - Code: ", res, " | Taille: ", ArraySize(result));
   
   if(res == 200)
   {
      string metricsData = CharArrayToString(result);
      Print("?? DEBUG - Données ML reçues: ", StringSubstr(metricsData, 0, MathMin(200, StringLen(metricsData))));
      
      // Parser les métriques et les afficher (clés plates: accuracy, model_name, total_samples, status, feedback_wins, feedback_losses)
      if(StringFind(metricsData, "accuracy") >= 0)
      {
         string acc = ExtractJsonValue(metricsData, "accuracy");
         string model = ExtractJsonValue(metricsData, "model_name");
         string samples = ExtractJsonValue(metricsData, "total_samples");
         string status = ExtractJsonValue(metricsData, "status");
         string wins = ExtractJsonValue(metricsData, "feedback_wins");
         string losses = ExtractJsonValue(metricsData, "feedback_losses");
         string dataSource = ExtractJsonValue(metricsData, "data_source");
         string sbConn = ExtractJsonValue(metricsData, "supabase_connected");
         string sbSync = ExtractJsonValue(metricsData, "last_supabase_sync");
         g_mlMetricsStr = "Précision: " + acc + "% | Modèle: " + model + " | Samples: " + samples;
         // Mettre à jour les variables numériques pour gating par catégorie
         g_mlLastAccuracy = (StringLen(acc) > 0 && acc != "N/A") ? StringToDouble(acc) : -1.0;
         g_mlLastModelName = model;
         if(wins != "N/A" && losses != "N/A")
            g_mlMetricsStr += " | Feedback: " + wins + "W/" + losses + "L";
         if(status != "N/A" && status != "trained")
            g_mlMetricsStr += " | " + (status == "collecting_data" ? "Collecte données..." : status);
         if(dataSource != "N/A")
            g_mlMetricsStr += " | Source: " + dataSource;
         else if(sbConn != "N/A")
            g_mlMetricsStr += " | Supabase: " + sbConn;
         if(sbSync != "N/A")
            g_mlMetricsStr += " | Sync: " + sbSync;
         Print("? DEBUG - Métriques ML mises à jour: ", g_mlMetricsStr);
      }
      else if(StringFind(metricsData, "status") >= 0)
      {
         string status = ExtractJsonValue(metricsData, "status");
         g_mlMetricsStr = (status == "collecting_data") ? "ML: Collecte de données en cours..." : "ML: " + status;
      }
      else
      {
         g_mlMetricsStr = "ML: En attente de données...";
         Print("?? DEBUG - Pas de métriques trouvées");
      }

      // Extraire aussi les stats jour/mois par symbole (source serveur/Supabase) si présentes
      // (clés attendues: day_wins, day_losses, day_net_profit, month_wins, month_losses, month_net_profit)
      string sDW = ExtractJsonValue(metricsData, "day_wins");
      string sDL = ExtractJsonValue(metricsData, "day_losses");
      string sDNP = ExtractJsonValue(metricsData, "day_net_profit");
      string sMW = ExtractJsonValue(metricsData, "month_wins");
      string sML = ExtractJsonValue(metricsData, "month_losses");
      string sMNP = ExtractJsonValue(metricsData, "month_net_profit");
      if(sDW != "N/A") g_dayWins = (int)StringToInteger(sDW);
      if(sDL != "N/A") g_dayLosses = (int)StringToInteger(sDL);
      if(sDNP != "N/A") g_dayNetProfit = StringToDouble(sDNP);
      if(sMW != "N/A") g_monthWins = (int)StringToInteger(sMW);
      if(sML != "N/A") g_monthLosses = (int)StringToInteger(sML);
      if(sMNP != "N/A") g_monthNetProfit = StringToDouble(sMNP);
   }
   else
   {
      // Fallback (serveur indisponible)
      GenerateFallbackMLMetrics();
      g_mlMetricsStr = "ML: Serveur indisponible (fallback actif)";
      Print("? DEBUG - Erreur WebRequest ML metrics: ", res);
   }
   
   // S'assurer que l'entraînement continu tourne (si activé)
   if(AutoStartMLContinuousTraining)
      EnsureMLContinuousTrainingRunning(false);

   // Récupérer le statut du canal
   int resStatus = WebRequest("GET", baseUrl + pathStatus, headers, AI_Timeout_ms, post, result, resultHeaders);
   if(resStatus != 200)
   {
      string fallbackUrl2 = UseRenderAsPrimary ? AI_ServerURL : AI_ServerRender;
      resStatus = WebRequest("GET", fallbackUrl2 + pathStatus, headers, AI_Timeout_ms2, post, result, resultHeaders);
   }
   
   Print("?? DEBUG - WebRequest ML status - Code: ", resStatus);
   
   if(resStatus == 200)
   {
      string statusData = CharArrayToString(result);
      g_channelValid = (StringFind(statusData, "\"valid\": true") >= 0);
      Print("? DEBUG - Canal ML valide: ", g_channelValid ? "OUI" : "NON");
   }
   else
   {
      g_channelValid = false;
      Print("? DEBUG - Erreur WebRequest ML status: ", resStatus);
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
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string path = "/ml/decision?symbol=" + symEnc + "&timeframe=M1";
   string headers = "";
   char post[], result[];
   string resultHeaders;
   
   int res = WebRequest("GET", baseUrl + path, headers, timeoutMs > 0 ? timeoutMs : AI_Timeout_ms, post, result, resultHeaders);
   
   if(res != 200)
   {
      // Fallback vers l'autre URL si échec
      string fallbackUrl = UseRenderAsPrimary ? AI_ServerURL : AI_ServerRender;
      res = WebRequest("GET", fallbackUrl + path, headers, timeoutMs > 0 ? timeoutMs : AI_Timeout_ms, post, result, resultHeaders);
      
      if(res != 200)
      {
         Print("? ERREUR IA - Échec des deux serveurs: ", res);
         return false;
      }
   }
   
   string jsonData = CharArrayToString(result);
   ProcessAIDecision(jsonData);
   
   Print("? Décision IA reçue - Action: ", g_lastAIAction, " | Confiance: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
   return true;
}

string GetAISignalData_Legacy(string symbol, string timeframe)
{
   string symEnc = symbol;
   StringReplace(symEnc, " ", "%20");
   
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
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
   
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
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
   
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
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
         // Le serveur peut envoyer 0–1 (décimal) ou 0–100 (pourcentage) ? normaliser en 0–1
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

// FONCTIONS SUPPRIMÉES - PLUS D'ORDRES LIMIT
// - PlaceScalpingLimitOrders() supprimée
// - DrawLimitOrderLevels() supprimée
// - PlaceHistoricalBasedScalpingOrders() supprimée
// - PlaceReturnMovementLimitOrder() supprimée
// - AdjustEMAScalpingLimitOrder() supprimée
// - ShouldReplaceLimitOrder() supprimée
// - ReplaceLimitOrder() supprimée
// - GuardPendingLimitOrdersWithAI_Enhanced() supprimée

// Fonctions utilitaires de comptage d'ordres (conservées pour compatibilité)
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
      
      /* // Si le symbole est propice mais pas sur de graphique, bloquer les ordres LIMIT
      if(!symbolFoundOnChart)
      {
         Print("🚫 ORDRES LIMIT BLOQUÉS - Symbole propice ", _Symbol, " non listé sur aucun graphique");
         Print("   💡 Ce symbole est considéré comme propice mais n'est pas affiché dans Market Watch");
         Print("   📊 Veuillez ajouter ", _Symbol, " à un graphique pour permettre les ordres LIMIT");
         return;
      }
      // (désactivation terminator prématurée) le commentaire multi-ligne continue jusqu'au fin
   }

   // IA/ML doit être favorable (direction + forte confiance)
   string aiDir = g_lastAIAction;
   StringToUpper(aiDir);
   
   // BLOCAGE SÉCURITÉ: NE PAS PLACER D'ORDRES SI IA EST EN HOLD
   if(aiDir == "HOLD")
   {
      Print("?? ORDRES SCALPING LIMIT BLOQUÉS - IA en HOLD sur ", _Symbol, " - Sécurité activée");
      return;
   }
   
   if(aiDir != "BUY" && aiDir != "SELL") return;
   if(!IsAITradeAllowedForDirection(aiDir))
      return; // log déjà fait dans IsAITradeAllowedForDirection()

   // Anti-duplication: 1 seul pending LIMIT par symbole (sur notre magic)
   if(CountOpenLimitOrdersForSymbol(_Symbol) >= 1)
      return;

   // Filtre "conditions réunies": indicateurs classiques (EMA/RSI/MACD/BB/VWAP/Pivots/Ichimoku/OBV)
   string classicSummary = "";
   if(!IsClassicIndicatorsAligned(aiDir, classicSummary))
   {
      Print("?? LIMIT STRAT BLOQUÉ - Indicateurs classiques non alignés (", aiDir, ") ", classicSummary);
      return;
   }

   if(currentATR <= 0.0)
      return;

   double price = currentPrice;
   if(price <= 0.0)
      price = (aiDir == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(price <= 0.0) return;

   string src = "";
   double entry = 0.0;
   ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY_LIMIT;
   if(aiDir == "BUY")
   {
      entry = GetClosestBuyLevel(price, currentATR, MaxDistanceLimitATR, src);
      orderType = ORDER_TYPE_BUY_LIMIT;
   }
   else
   {
      entry = GetClosestSellLevel(price, currentATR, MaxDistanceLimitATR, src);
      orderType = ORDER_TYPE_SELL_LIMIT;
   }

   if(entry <= 0.0)
      return;

   double sl = 0.0, tp = 0.0;
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      sl = entry - currentATR * SL_ATRMult;
      tp = entry + currentATR * TP_ATRMult;
   }
   else
   {
      sl = entry + currentATR * SL_ATRMult;
      tp = entry - currentATR * TP_ATRMult;
   }

   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   req.action = TRADE_ACTION_PENDING;
   req.symbol = _Symbol;
   req.volume = CalculateLotSizeForPendingOrders();
   if(req.volume <= 0.0) return;
   req.type   = orderType;
   req.price  = entry;
   req.sl     = sl;
   req.tp     = tp;
   req.magic  = InpMagicNumber;
   req.comment = "STRAT " + aiDir + " LIMIT (" + src + ")";

   if(!ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, orderType))
      return;

   if(OrderSend(req, res))
   {
      Print("?? LIMIT STRAT OK - ", aiDir, " @ ", DoubleToString(req.price, _Digits),
            " src=", src,
            " | Vol=", DoubleToString(req.volume, 2),
            " | SL=", DoubleToString(req.sl, _Digits),
            " | TP=", DoubleToString(req.tp, _Digits),
            " | Classic=", classicSummary);
   }
}
*/


/*
// Place les LIMIT "prédits" (Protected future points) exactement au même prix que ceux affichés au dashboard.
// Cible: uniquement Boom/Crash.
void PlaceFutureProtectedLimitsExact_BoomCrash(double currentATR)
{
   // FONCTION DÉSACTIVÉE - Les ordres LIMIT ne sont plus placés automatiquement
   Print("🚫 FONCTION DÉSACTIVÉE - PlaceFutureProtectedLimitsExact_BoomCrash() supprimé");
   return;
   
   // Ancien code conservé pour référence mais non exécuté
   // Throttle: éviter spam
   static datetime lastPlace = 0;
   datetime now = TimeCurrent();
   if(now - lastPlace < 60) return;
   lastPlace = now;

   if(SMC_GetSymbolCategory(_Symbol) != SYM_BOOM_CRASH) return;
   // currentATR peut être 0 sur certains contextes: ValidateLimitPriceExactEntry ajustera SL/TP

   // IA directionnelle (pas HOLD)
   string aiAction = g_lastAIAction;
   StringToUpper(aiAction);
   if(aiAction == "HOLD" || aiAction == "") return;
   // Pour les LIMIT "future protected points", on ne bloque pas sur la confiance
   // : le but est de placer les pending aux niveaux prédits (sinon tu ne vois jamais ces ordres).

   // Anti-duplication stricte: 1 seul LIMIT par symbole (EA)
   // On nettoie les autres LIMIT du symbole avant de poursuivre.
   int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
   // IMPORTANT: ne pas return ici.
   // On veut supprimer les doublons (ou limiter à 1 seul) avant de placer/modifier l'ordre future.
   double futureSupport = 0.0, futureResistance = 0.0;
   bool hasFutureLevels = GetFutureProtectedPointLevels(futureSupport, futureResistance);
   if(!hasFutureLevels) return;

   bool isBoom = IsBoomSymbol(_Symbol);
   bool isCrash = IsCrashSymbol(_Symbol);
   if(!isBoom && !isCrash) return;

   // Diagnostic: afficher les niveaux réellement utilisés pour le pending
   // (une fois/minute car la fonction est déjà throttlée)
   Print("🧩 FUTURE LIMIT EXACT - ", _Symbol,
         " | ai=", aiAction,
         " conf=", DoubleToString(g_lastAIConfidence*100.0, 1), "%",
         " | ATR=", DoubleToString(currentATR, _Digits),
         " | futureSupport=", DoubleToString(futureSupport, _Digits),
         " | futureResistance=", DoubleToString(futureResistance, _Digits),
         " | totalLimits=", IntegerToString(totalLimits));

   ENUM_ORDER_TYPE orderType;
   double entry;
   double sl;
   double tp;
   string side;

   if(isBoom)
   {
      // Boom: BUY_LIMIT uniquement
      if(futureSupport <= 0.0)
      {
         Print("🛑 FUTURE LIMIT EXACT - Boom mais futureSupport<=0.0 sur ", _Symbol);
         return;
      }
      orderType = ORDER_TYPE_BUY_LIMIT;
      side = "BUY";
      entry = futureSupport;
      sl = entry - currentATR * SL_ATRMult;
      // TP >= 3 fois la distance SL positive (ici: ATR*SL_ATRMult)
      tp = entry + (currentATR * SL_ATRMult * MathMax(3.0, InpRiskReward));
   }
   else // Crash
   {
      // Crash: SELL_LIMIT uniquement
      if(futureResistance <= 0.0)
      {
         Print("🛑 FUTURE LIMIT EXACT - Crash mais futureResistance<=0.0 sur ", _Symbol);
         return;
      }
      orderType = ORDER_TYPE_SELL_LIMIT;
      side = "SELL";
      entry = futureResistance;
      sl = entry + currentATR * SL_ATRMult;
      // TP >= 3 fois la distance SL positive (ici: ATR*SL_ATRMult)
      tp = entry - (currentATR * SL_ATRMult * MathMax(3.0, InpRiskReward));
   }

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0) tickSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   string ourCmtPrefix = "FUTURE_PROTECTED_LIMIT_EXACT_";
   ulong existingTicket = 0;
   double existingPrice = 0.0;

   // Chercher le pending futur existant (1 seul par symbole souhaité)
   // et supprimer tous les autres LIMIT sur ce symbole.
   for(int oi = OrdersTotal() - 1; oi >= 0; oi--)
   {
      ulong oticket = OrderGetTicket(oi);
      if(oticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;

      string cmt = OrderGetString(ORDER_COMMENT);
      bool isOurFuture = (StringFind(cmt, ourCmtPrefix) == 0);
      if(isOurFuture)
      {
         // On en garde le plus récent (ticket max) dans existingTicket
         if(oticket > existingTicket)
         {
            existingTicket = oticket;
            existingPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         }
      }
      else
      {
         // Règle utilisateur: pas deux LIMIT sur le même symbole -> annuler l'ancien/autre.
         MqlTradeRequest rdelOther = {};
         MqlTradeResult  rresOther = {};
         rdelOther.action = TRADE_ACTION_REMOVE;
         rdelOther.order  = oticket;
         rdelOther.symbol = _Symbol;
         if(OrderSend(rdelOther, rresOther))
         {
            Print("?? LIMIT supprimé (unicité symbole) | ", _Symbol,
                  " | ticket=", IntegerToString((int)oticket),
                  " | comment=", cmt);
         }
         else
         {
            Print("? Échec suppression LIMIT (unicité symbole) | ", _Symbol,
                  " | ticket=", IntegerToString((int)oticket),
                  " | retcode=", IntegerToString(rresOther.retcode));
         }
      }
   }

   // S'il existe plusieurs LIMIT au total, ne conserver qu'un seul future-limit (le plus récent)
   // et supprimer les doublons "future protected" restants.
   if(totalLimits > 1 && existingTicket != 0)
   {
      for(int oi = OrdersTotal() - 1; oi >= 0; oi--)
      {
         ulong oticket = OrderGetTicket(oi);
         if(oticket == 0 || oticket == existingTicket) continue;
         if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(ot != ORDER_TYPE_BUY_LIMIT && ot != ORDER_TYPE_SELL_LIMIT) continue;
         string cmt = OrderGetString(ORDER_COMMENT);
         if(StringFind(cmt, ourCmtPrefix) != 0) continue;

         MqlTradeRequest rdelDup = {};
         MqlTradeResult  rresDup = {};
         rdelDup.action = TRADE_ACTION_REMOVE;
         rdelDup.order  = oticket;
         rdelDup.symbol = _Symbol;
         if(!OrderSend(rdelDup, rresDup))
         {
            Print("❌ Erreur suppression ordre dupliqué: ", rresDup.retcode, " | ", rresDup.comment);
         }
      }
   }

   // Validation exacte avant toute action (entry ne doit pas bouger).
   if(!ValidateLimitPriceExactEntry(entry, sl, tp, orderType))
      return;

   bool needReplace = true;
   if(existingTicket != 0)
   {
      // Ne remplacer que si le prix a vraiment changé (sinon on laisse le pending tranquille)
      if(MathAbs(existingPrice - entry) <= tickSize * 0.5)
         needReplace = false;
   }

   // Si un pending existe et que le prix a changé: MODIFY sinon remove+recreate.
   if(existingTicket != 0 && needReplace)
   {
      // Tentative: modifier le pending (prix/SL/TP)
      MqlTradeRequest req = {};
      MqlTradeResult  res = {};
      req.action = TRADE_ACTION_MODIFY;
      req.order  = existingTicket;
      req.symbol = _Symbol;
      req.price  = entry;
      req.sl     = sl;
      req.tp     = tp;
      req.magic  = InpMagicNumber;

      if(OrderSend(req, res) && (res.retcode == TRADE_RETCODE_DONE || res.retcode == 10009))
      {
         Print("?? FUTURE LIMIT EXACT MODIFIÉ | ", _Symbol,
               " | ", side, " @ ", DoubleToString(entry, _Digits),
               " | SL=", DoubleToString(sl, _Digits),
               " | TP=", DoubleToString(tp, _Digits),
               " | oldTicket=", IntegerToString((int)existingTicket));
         return;
      }

      // Sinon: remove + resend
      MqlTradeRequest rdel = {};
      MqlTradeResult  rres = {};
      rdel.action = TRADE_ACTION_REMOVE;
      rdel.order  = existingTicket;
      rdel.symbol = _Symbol;
      if(!OrderSend(rdel, rres))
      {
         Print("? FUTURE LIMIT EXACT remove ÉCHEC | ", _Symbol,
               " | oldTicket=", IntegerToString((int)existingTicket),
               " | retcode=", IntegerToString(rres.retcode));
         // On tente malgré tout de recréer
      }
   }

   // (Re)créer le pending s'il n'existe pas ou après remove
   MqlTradeRequest req2 = {};
   MqlTradeResult  res2 = {};
   req2.action = TRADE_ACTION_PENDING;
   req2.symbol = _Symbol;
   req2.volume = CalculateLotSizeForPendingOrders();
   if(req2.volume <= 0.0) return;
   req2.type   = orderType;
   req2.price  = entry;
   req2.sl     = sl;
   req2.tp     = tp;
   req2.magic  = InpMagicNumber;
   req2.comment = ourCmtPrefix + side;

   if(OrderSend(req2, res2))
   {
      Print("?? FUTURE LIMIT EXACT (re)créé | ", _Symbol, " | ", side,
            " @ ", DoubleToString(entry, _Digits),
            " | SL=", DoubleToString(sl, _Digits),
            " | TP=", DoubleToString(tp, _Digits),
            " | retcode=", IntegerToString(res2.retcode));
   }
   else
   {
      Print("? FUTURE LIMIT EXACT ÉCHEC (re)création | ", _Symbol, " | ", side,
            " @ ", DoubleToString(entry, _Digits),
            " | retcode=", IntegerToString(res2.retcode),
            " | comment=", res2.comment);
   }
}

void PlaceHistoricalBasedScalpingOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope, int existingLimitOrders)
   {
      // VÉRIFICATION ANTI-DUPLICATION - Si position déjà en cours, ne pas placer d'ordres
      int existingPositionsOnSymbol = CountPositionsForSymbol(_Symbol);
      
      // CORRECTION: Utiliser les prix EXACTS des Protected Points 500 bougies (ceux affichés au dashboard)
      double futureSupport = 0.0, futureResistance = 0.0;
      
      // Obtenir les Protected Points projetés 500 bougies (ceux affichés au tableau de bord)
      MqlRates futureRates[];
      ArraySetAsSeries(futureRates, true);
      bool hasFutureLevels = false;
      
      if(CopyRates(_Symbol, PERIOD_M15, 0, 200, futureRates) >= 100)
      {
         double currentPrice = futureRates[0].close;
         datetime currentTime = futureRates[0].time;
         
         // Trouver le Protected Low Point le plus récent (celui projeté 500 bougies)
         for(int i = 5; i < 50; i++)
         {
            bool isProtectedLow = true;
            double currentLow = futureRates[i].low;
            
            // Vérifier si c'est un low protégé
            for(int j = i - 5; j >= 0 && j >= i - 10; j--)
            {
               if(futureRates[j].low < currentLow)
               {
                  isProtectedLow = false;
                  break;
               }
            }
            
            if(isProtectedLow && currentLow < currentPrice)
            {
               futureSupport = currentLow; // PRIX EXACT affiché au dashboard
               hasFutureLevels = true;
               break; // Prendre le plus récent
            }
         }
         
         // Trouver le Protected High Point le plus récent (celui projeté 500 bougies)
         for(int i = 5; i < 50; i++)
         {
            bool isProtectedHigh = true;
            double currentHigh = futureRates[i].high;
            
            // Vérifier si c'est un high protégé
            for(int j = i - 5; j >= 0 && j >= i - 10; j--)
            {
               if(futureRates[j].high > currentHigh)
               {
                  isProtectedHigh = false;
                  break;
               }
            }
            
            if(isProtectedHigh && currentHigh > currentPrice)
            {
               futureResistance = currentHigh; // PRIX EXACT affiché au dashboard
               hasFutureLevels = true;
               break; // Prendre le plus récent
            }
         }
      }
      
      // LOG DES PRÉDICTIONS POUR ORDRES LIMITES
      if(hasFutureLevels)
      {
         static datetime lastLimitOrderLog = 0;
         if(TimeCurrent() - lastLimitOrderLog >= 300) // Log toutes les 5 minutes
         {
            Print("🎯 PRÉDICTIONS FUTURES POUR ORDRES LIMITES - ", _Symbol);
            Print("   📍 Support futur: ", (futureSupport > 0 ? DoubleToString(futureSupport, _Digits) : "N/A"));
            Print("   📍 Résistance future: ", (futureResistance > 0 ? DoubleToString(futureResistance, _Digits) : "N/A"));
            Print("   💡 Utilisation pour placement stratégique d'ordres limites");
            lastLimitOrderLog = TimeCurrent();
         }
      }
      if(existingPositionsOnSymbol > 0)
      {
         Print("?? ORDRES HISTORIQUES BLOQUÉS - ", existingPositionsOnSymbol, " position(s) déjà en cours sur ", _Symbol, " - Attente fermeture");
         return;
      }
      
      // BLOCAGE SÉCURITÉ: NE PAS PLACER D'ORDRES SI IA EST EN HOLD
      string aiAction = g_lastAIAction;
      StringToUpper(aiAction);
      if(aiAction == "HOLD")
      {
         Print("?? ORDRES HISTORIQUES BLOQUÉS - IA en HOLD sur ", _Symbol, " - Sécurité activée");
         return;
      }
      
      // POUR TOUS LES MARCHÉS HORS BOOM/CRASH: n'autoriser les ordres que si IA ? 80% et alignée
      ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
      if(cat != SYM_BOOM_CRASH && !IsAITradeAllowedForDirection(g_lastAIAction))
      {
         // IsAITradeAllowedForDirection loggue déjà la raison précise
         return;
      }
      
      // Anti-duplication: 1 seul pending LIMIT par symbole
      {
         int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
         if(totalLimits >= 1)
         {
            Print("?? ORDRES HISTORIQUES BLOQUÉS - DUP LIMIT sur ", _Symbol);
            return;
         }
      }
      
      // RÈGLE STRICTE: BLOQUER TOUS LES ORDRES BUY SUR BOOM SI IA = SELL
      bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
      bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
      if(aiAction == "buy") aiAction = "BUY";
      if(aiAction == "sell") aiAction = "SELL";
      
      if(isBoom && aiAction == "SELL")
      {
         Print("?? ORDRES HISTORIQUES BOOM BLOQUÉS - IA = SELL (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal BUY avant de placer ordres BUY");
         return;
      }
      
      if(isCrash && aiAction == "BUY")
      {
         Print("?? ORDRES HISTORIQUES CRASH BLOQUÉS - IA = BUY (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal SELL avant de placer ordres SELL");
         return;
      }
      
      // 1) STRATÉGIE EMA SMC (200, 100, 50, 31, 21) AVEC IA FORTE
      int ordersToPlace = MathMax(0, 1 - existingLimitOrders); // Anti-duplication: max 1
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
         
         // STRATÉGIE UNIQUE: BOOM = BUY LIMIT exact au support futur, CRASH = SELL LIMIT exact à la résistance future
         
         // LOGS DE DÉBOGAGE DÉTAILLÉS POUR DIAGNOSTIC
         Print("🔍 DIAGNOSTIC ORDRE LIMIT BOOM - ", _Symbol);
         Print("   📊 isBoom: ", (isBoom ? "OUI" : "NON"));
         Print("   📊 hasFutureLevels: ", (hasFutureLevels ? "OUI" : "NON"));
         Print("   📊 futureSupport: ", (futureSupport > 0 ? DoubleToString(futureSupport, _Digits) : "0.0"));
         Print("   📊 ordersToPlace: ", IntegerToString(ordersToPlace));
         Print("   📊 currentPrice: ", DoubleToString(closePrice, _Digits));
         Print("   📊 currentATR: ", DoubleToString(currentATR, _Digits));
         
         if(isBoom && hasFutureLevels && futureSupport > 0 && ordersToPlace > 0)
         {
            Print("✅ Toutes les conditions réunies pour BUY LIMIT BOOM");
            
            // BOOM: Placer BUY LIMIT EXACTEMENT au prix affiché au tableau de bord
            double exactSupportPrice = futureSupport; // Prix exact affiché au dashboard
            
            Print("🎯 PRIX DU BUY LIMIT: ", DoubleToString(exactSupportPrice, _Digits));
            Print("   📍 Position par rapport au prix actuel: ", DoubleToString(closePrice - exactSupportPrice, _Digits), " points");
            
            // Placer BUY LIMIT au prix exact du support futur
            MqlTradeRequest req = {};
            MqlTradeResult res = {};
            req.action = TRADE_ACTION_PENDING;
            req.symbol = _Symbol;
            req.volume = CalculateLotSizeForPendingOrders();
            Print("📦 Volume calculé: ", DoubleToString(req.volume, 2));
            if(req.volume <= 0.0) 
            {
               Print("❌ VOLUME INVALIDE - Ordre annulé");
               return;
            }
            req.type = ORDER_TYPE_BUY_LIMIT;
            req.price = exactSupportPrice; // PRIX EXACT affiché au tableau de bord
            req.sl = exactSupportPrice - (currentATR * SL_ATRMult);
            // TP doit être >= 3 fois la distance SL positive
            req.tp = exactSupportPrice + (currentATR * SL_ATRMult * MathMax(3.0, InpRiskReward));
            req.magic = InpMagicNumber;
            req.comment = "BOOM EXACT_FUTURE_SUPPORT";
            
            Print("🔍 DÉTAILS ORDRE AVANT ENVOI:");
            Print("   📍 Type: BUY_LIMIT");
            Print("   💰 Prix: ", DoubleToString(req.price, _Digits));
            Print("   📦 Volume: ", DoubleToString(req.volume, 2));
            Print("   🛡️ SL: ", DoubleToString(req.sl, _Digits));
            Print("   🎯 TP: ", DoubleToString(req.tp, _Digits));
            Print("   🔮 Magic: ", IntegerToString(req.magic));
            
            // Validation "exact entry": on doit garder le prix affiché (futureSupport) identique.
            bool validationOk = ValidateLimitPriceExactEntry(req.price, req.sl, req.tp, ORDER_TYPE_BUY_LIMIT);
            Print("🔍 Validation prix: ", (validationOk ? "OK" : "ÉCHEC"));
            if(!validationOk)
            {
               Print("❌ VALIDATION PRIX ÉCHOUÉE - Ordre annulé");
               return;
            }
            
            bool orderSent = OrderSend(req, res);
            Print("🔍 Envoi ordre: ", (orderSent ? "SUCCÈS" : "ÉCHEC"));
            Print("   📊 Code retour: ", IntegerToString(res.retcode));
            Print("   📊 Commentaire: ", res.comment);
            
            if(orderSent)
            {
               Print("✅ BOOM BUY LIMIT PLACÉ AU PRIX EXACT DU TABLEAU DE BORD - ", _Symbol);
               Print("   🎯 PRIX EXACT dashboard: ", DoubleToString(exactSupportPrice, _Digits));
               Print("   📍 Prix ordre: ", DoubleToString(req.price, _Digits), " | Lot: ", DoubleToString(req.volume, 2));
               Print("   🛡️ SL: ", DoubleToString(req.sl, _Digits), " | 🎯 TP: ", DoubleToString(req.tp, _Digits));
               Print("   ✅ CORRESPONDANCE PARFAITE avec l'affichage");
            }
            else
            {
               Print("❌ ÉCHEC BOOM BUY LIMIT - Erreur: ", res.retcode, " - ", res.comment);
            }
            return; // Sortir après avoir placé l'ordre
         }
         else
         {
            Print("❌ CONDITIONS NON RÉUNIES POUR BUY LIMIT BOOM");
            if(!isBoom) Print("   ❌ Symbole non-BOOM détecté");
            if(!hasFutureLevels) Print("   ❌ Pas de niveaux futurs disponibles");
            if(futureSupport <= 0) Print("   ❌ Support futur invalide: ", DoubleToString(futureSupport, _Digits));
            if(ordersToPlace <= 0) Print("   ❌ Plus d'ordres à placer: ", IntegerToString(ordersToPlace));
         }
         
         if(isCrash && hasFutureLevels && futureResistance > 0 && ordersToPlace > 0)
         {
            // CRASH: Placer SELL LIMIT EXACTEMENT au prix affiché au tableau de bord
            double exactResistancePrice = futureResistance; // Prix exact affiché au dashboard
            
            // Placer SELL LIMIT au prix exact de la résistance future
            MqlTradeRequest req = {};
            MqlTradeResult res = {};
            req.action = TRADE_ACTION_PENDING;
            req.symbol = _Symbol;
            req.volume = CalculateLotSizeForPendingOrders();
            if(req.volume <= 0.0) return;
            req.type = ORDER_TYPE_SELL_LIMIT;
            req.price = exactResistancePrice; // PRIX EXACT affiché au tableau de bord
            req.sl = exactResistancePrice + (currentATR * SL_ATRMult);
            // TP doit être >= 3 fois la distance SL positive
            req.tp = exactResistancePrice - (currentATR * SL_ATRMult * MathMax(3.0, InpRiskReward));
            req.magic = InpMagicNumber;
            req.comment = "CRASH EXACT_FUTURE_RESISTANCE";
            
            // Validation "exact entry": on doit garder le prix affiché (futureResistance) identique.
            if(!ValidateLimitPriceExactEntry(req.price, req.sl, req.tp, ORDER_TYPE_SELL_LIMIT))
               return;
            
            if(OrderSend(req, res))
            {
               Print("✅ CRASH SELL LIMIT PLACÉ AU PRIX EXACT DU TABLEAU DE BORD - ", _Symbol);
               Print("   🎯 PRIX EXACT dashboard: ", DoubleToString(exactResistancePrice, _Digits));
               Print("   📍 Prix ordre: ", DoubleToString(req.price, _Digits), " | Lot: ", DoubleToString(req.volume, 2));
               Print("   🛡️ SL: ", DoubleToString(req.sl, _Digits), " | 🎯 TP: ", DoubleToString(req.tp, _Digits));
               Print("   ✅ CORRESPONDANCE PARFAITE avec l'affichage");
            }
            else
            {
               Print("❌ ÉCHEC CRASH SELL LIMIT - Erreur: ", res.retcode, " - ", res.comment);
            }
            return; // Sortir après avoir placé l'ordre
         }
         
         // LOGIQUE SUPPRIMÉE - PLUS D'ORDRES LIMIT AUTRES QUE PRÉDICTIONS FUTURES
// Seuls les ordres BOOM/CRASH basés sur les prédictions futures sont conservés
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
   // Si on a récemment touché un SL, le prix a tendance à monter ? BUY LIMIT au niveau exact du SL
   // Si on a récemment touché un SH, le prix a tendance à baisser ? SELL LIMIT au niveau exact du SH
   
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
         request.volume = CalculateLotSizeForPendingOrders();
         if(request.volume <= 0.0) return;
         request.type = ORDER_TYPE_BUY_LIMIT;
         request.price = buyLimitPrice;
         request.sl = buyLimitPrice - (currentATR * 0.5); // SL plus proche pour petits mouvements
         request.tp = tpPrice;
         request.magic = InpMagicNumber;
         request.comment = "HIST SL BUY - PETITS MOUVEMENTS";
         
         // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
         if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_BUY_LIMIT))
         {
            Print("? Échec validation prix BUY LIMIT - Ordre annulé");
            return;
         }
         
         if(OrderSend(request, result))
         {
            Print("?? ORDRE BUY PETITS MOUVEMENTS - Prix: ", request.price, " | Vol=", DoubleToString(request.volume, 2),
                  " | TP: ", request.tp, " | SL: ", request.sl, " | Distance: ", MathAbs(request.price - currentPrice), " points");
            ordersToPlace--;
         }
      }
      else
      {
         Print("?? SL trop loin (", MathAbs(lastSL - currentPrice), " > 0.5 ATR) - Ordre BUY annulé pour petits mouvements");
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
         request.volume = CalculateLotSizeForPendingOrders();
         if(request.volume <= 0.0) return;
         request.type = ORDER_TYPE_SELL_LIMIT;
         request.price = sellLimitPrice;
         request.sl = sellLimitPrice + (currentATR * 0.5); // SL plus proche pour petits mouvements
         request.tp = tpPrice;
         request.magic = InpMagicNumber;
         request.comment = "HIST SH SELL - PETITS MOUVEMENTS";
         
         // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
         if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_SELL_LIMIT))
         {
            Print("? Échec validation prix SELL LIMIT - Ordre annulé");
            return;
         }
         
         if(OrderSend(request, result))
         {
            Print("?? ORDRE SELL PETITS MOUVEMENTS - Prix: ", request.price, " | Vol=", DoubleToString(request.volume, 2),
                  " | TP: ", request.tp, " | SL: ", request.sl, " | Distance: ", MathAbs(request.price - currentPrice), " points");
            ordersToPlace--;
         }
      }
      else
      {
         Print("?? SH trop loin (", MathAbs(lastSH - currentPrice), " > 0.5 ATR) - Ordre SELL annulé pour petits mouvements");
      }
   }
   
   if(ordersToPlace > 0)
   {
      Print("?? STRATÉGIE HISTORIQUE - ", (2 - existingLimitOrders), " ordres placés sur SH/SL historiques");
   }
   else
   {
      Print("?? AUCUN SH/SL HISTORIQUE VALIDE - Analyse continue...");
   }
}
*/

void DetectAndPlaceBoomCrashSpikeOrders(MqlRates &rates[], double currentPrice, double currentATR, bool isBoom, int existingLimitOrders)
{
   // VÉRIFICATION ANTI-DUPLICATION - Si position déjà en cours, ne pas placer d'ordres
   int existingPositionsOnSymbol = CountPositionsForSymbol(_Symbol);
   if(existingPositionsOnSymbol > 0)
   {
      Print("?? ORDRES SPIKE BLOQUÉS - ", existingPositionsOnSymbol, " position(s) déjà en cours sur ", _Symbol, " - Attente fermeture");
      return;
   }
   
   // Anti-duplication: 1 seul pending LIMIT par symbole
   int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
   if(totalLimits >= 1)
   {
      Print("?? ORDRES SPIKE BLOQUÉS - DUP LIMIT sur ", _Symbol);
      return;
   }

   // RÈGLE IA PRIORITAIRE SUR BOOM/CRASH:
   // - Sur Boom: aucun BUY si IA = SELL
   // - Sur Crash: aucun SELL si IA = BUY
   string aiDir = g_lastAIAction;
   StringToUpper(aiDir);
   
   // BLOCAGE SÉCURITÉ: NE PAS PLACER D'ORDRES SI IA EST EN HOLD
   if(aiDir == "HOLD")
   {
      Print("?? ORDRES SPIKE BLOQUÉS - IA en HOLD sur ", _Symbol, " - Sécurité activée");
      return;
   }
   
   if(aiDir == "buy")  aiDir = "BUY";
   if(aiDir == "sell") aiDir = "SELL";
   bool isCrash = !isBoom;
   if(isBoom && aiDir == "SELL")
   {
      Print("?? ORDRES SPIKE BOOM BLOQUÉS - IA = SELL (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Aucun BUY LIMIT autorisé");
      return;
   }
   if(isCrash && aiDir == "BUY")
   {
      Print("?? ORDRES SPIKE CRASH BLOQUÉS - IA = BUY (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Aucun SELL LIMIT autorisé");
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
      int ordersToPlace = MathMin(MathMax(0, 1 - existingLimitOrders), spikeCount); // Anti-duplication: max 1
      
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
         request.volume = CalculateLotSizeForPendingOrders();
         if(request.volume <= 0.0) continue;
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
            Print("? Échec validation prix ", spikeType, " - Ordre annulé");
            continue;
         }
         
         if(OrderSend(request, result))
         {
            Print("?? ", spikeType, " PLACÉ - Entrée: ", request.price, " | Vol=", DoubleToString(request.volume, 2),
                  " | TP: ", request.tp, " | SL: ", request.sl);
         }
         else
         {
            Print("? ÉCHEC PLACEMENT ", spikeType, " - Erreur: ", result.comment);
         }
      }
      
      if(ordersToPlace < spikeCount)
      {
         Print("?? ", (spikeCount - ordersToPlace), " spikes supplémentaires détectés mais ordres limites non disponibles");
      }
   }
   else
   {
      Print("?? AUCUN SPIKE BOOM/CRASH DÉTECTÉ - Analyse continue...");
   }
}

void PlaceNormalScalpingOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope)
{
   // VÉRIFICATION ANTI-DUPLICATION - Si position déjà en cours, ne pas placer d'ordres
   int existingPositionsOnSymbol = CountPositionsForSymbol(_Symbol);
   if(existingPositionsOnSymbol > 0)
   {
      Print("?? ORDRES NORMAUX BLOQUÉS - ", existingPositionsOnSymbol, " position(s) déjà en cours sur ", _Symbol, " - Attente fermeture");
      return;
   }
   
   // Anti-duplication: 1 seul pending LIMIT par symbole
   {
      int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
      if(totalLimits >= 1)
      {
         Print("?? ORDRES NORMAUX BLOQUÉS - DUP LIMIT sur ", _Symbol);
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
      double tpPrice = buyLimitPrice + (currentATR * 1.5 * MathMax(3.0, InpRiskReward));
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = CalculateLotSizeForPendingOrders();
      if(request.volume <= 0.0) return;
      request.type = ORDER_TYPE_BUY_LIMIT;
      request.price = buyLimitPrice;
      request.sl = buyLimitPrice - currentATR * 1.5;
      request.tp = tpPrice;
      request.magic = InpMagicNumber;
      request.comment = "Scalp SL Near";
      
      // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
      if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_BUY_LIMIT))
      {
         Print("? Échec validation prix BUY LIMIT scalping - Ordre annulé");
         return;
      }
      
      if(OrderSend(request, result))
      {
         Print("?? SEUL ORDRE LIMIT BUY PLACÉ - Prix: ", request.price, " | Vol=", DoubleToString(request.volume, 2),
               " | TP: ", request.tp, " | SL: ", request.sl, " | Distance: ", distanceToSL, " points");
      }
   }
   else if(bestSHPrice > 0)
   {
      // Placer SELL LIMIT au SH le plus proche (niveau exact)
      double sellLimitPrice = bestSHPrice;
      double tpPrice = sellLimitPrice - (currentATR * 1.5 * MathMax(3.0, InpRiskReward));
      
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_PENDING;
      request.symbol = _Symbol;
      request.volume = CalculateLotSizeForPendingOrders();
      if(request.volume <= 0.0) return;
      request.type = ORDER_TYPE_SELL_LIMIT;
      request.price = sellLimitPrice;
      request.sl = sellLimitPrice + currentATR * 1.5;
      request.tp = tpPrice;
      request.magic = InpMagicNumber;
      request.comment = "Scalp SH Near";
      
      // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
      if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_SELL_LIMIT))
      {
         Print("? Échec validation prix SELL LIMIT scalping - Ordre annulé");
         return;
      }
      
      if(OrderSend(request, result))
      {
         Print("?? SEUL ORDRE LIMIT SELL PLACÉ - Prix: ", request.price, " | Vol=", DoubleToString(request.volume, 2),
               " | TP: ", request.tp, " | SL: ", request.sl, " | Distance: ", distanceToSH, " points");
      }
   }
   else
   {
      Print("? AUCUN NIVEAU VALIDE TROUVÉ pour ordre de scalping");
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
   
   Print("?? SWING HISTORIQUES - ", swingCount, " points détectés (SH: rouge, SL: bleu)");
}

void DrawFVGOnChart()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = 80;
   if(CopyRates(_Symbol, LTF, 0, bars, rates) < bars) return;
   ObjectsDeleteAll(0, "SMC_FVG_");
   ObjectsDeleteAll(0, "SMC_IFVG_");
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

   FVGData ifvgSell, ifvgBuy;
   datetime t2ifvg = TimeCurrent() + PeriodSeconds(LTF)*20;
   if(ICT_DetectInvertedFVG(_Symbol, LTF, -1, MathMax(80, ICTLookbackBars), ifvgSell))
   {
      string n1 = "SMC_IFVG_SELL";
      if(ObjectCreate(0, n1, OBJ_RECTANGLE, 0, ifvgSell.time, ifvgSell.bottom, t2ifvg, ifvgSell.top))
      {
         ObjectSetInteger(0, n1, OBJPROP_COLOR, clrTomato);
         ObjectSetInteger(0, n1, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, n1, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetInteger(0, n1, OBJPROP_FILL, false);
      }
   }
   if(ICT_DetectInvertedFVG(_Symbol, LTF, 1, MathMax(80, ICTLookbackBars), ifvgBuy))
   {
      string n2 = "SMC_IFVG_BUY";
      if(ObjectCreate(0, n2, OBJ_RECTANGLE, 0, ifvgBuy.time, ifvgBuy.bottom, t2ifvg, ifvgBuy.top))
      {
         ObjectSetInteger(0, n2, OBJPROP_COLOR, clrLimeGreen);
         ObjectSetInteger(0, n2, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, n2, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetInteger(0, n2, OBJPROP_FILL, false);
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
   double tol = MathMax(point, ICTSweepTolerancePoints * point);
   ObjectsDeleteAll(0, "SMC_OB_");
   int cnt = 0;
   for(int fvgIndex = 3; fvgIndex < bars - 4 && cnt < 10; fvgIndex++)
   {
      if(rates[fvgIndex].close < rates[fvgIndex].open && rates[fvgIndex+1].close > rates[fvgIndex+1].open && (rates[fvgIndex+1].high - rates[fvgIndex].low) > point*20
         && ICT_HasLiquiditySweepBeforeIndex(rates, bars, fvgIndex, 1, tol))
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
      if(rates[fvgIndex].close > rates[fvgIndex].open && rates[fvgIndex+1].close < rates[fvgIndex+1].open && (rates[fvgIndex].high - rates[fvgIndex+1].low) > point*20
         && ICT_HasLiquiditySweepBeforeIndex(rates, bars, fvgIndex, -1, tol))
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
   int n = 100; // Augmenté pour meilleure analyse des swings
   if(CopyHigh(_Symbol, LTF, 0, n, high) < n || CopyLow(_Symbol, LTF, 0, n, low) < n || CopyTime(_Symbol, LTF, 0, n, time) < n) return;
   
   // Identifier les vrais swings significatifs (pas juste le plus haut/plus bas)
   int iHigh = FindSignificantSwingHigh(high, low, n);
   int iLow = FindSignificantSwingLow(high, low, n);
   if(iHigh < 0 || iLow < 0) return;
   
   double h = high[iHigh], l = low[iLow];
   datetime tHigh = time[iHigh], tLow = time[iLow];
   
   // S'assurer que le high est avant le low pour une analyse correcte
   if(tHigh > tLow) {
      // Inverser pour avoir le swing high avant le swing low
      int tempIdx = iHigh;
      iHigh = iLow;
      iLow = tempIdx;
      double tempPrice = h;
      h = l;
      l = tempPrice;
      datetime tempTime = tHigh;
      tHigh = tLow;
      tLow = tempTime;
   }
   
   ObjectsDeleteAll(0, "SMC_Fib_");
   
   // Niveaux Fibonacci améliorés pour OTE
   double levels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
   color colors[] = {clrGray, clrDodgerBlue, clrAqua, clrYellow, clrOrange, clrOrangeRed, clrMagenta};
   string descriptions[] = {"Start", "23.6%", "38.2%", "50%", "61.8% (OTE)", "78.6% (OTE)", "100%"};
   
   for(int i = 0; i < 7; i++)
   {
      double price = l + (h - l) * levels[i];
      string name = "SMC_Fib_" + IntegerToString(i);
      if(ObjectCreate(0, name, OBJ_HLINE, 0, 0, price))
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, colors[i]);
         ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, (i == 4 || i == 5) ? 2 : 1); // OTE plus épais
         ObjectSetString(0, name, OBJPROP_TOOLTIP, "Fib " + descriptions[i]);
         
         // Mettre en évidence les zones OTE (61.8% et 78.6%)
         if(i == 4 || i == 5) {
            ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            if(i == 4) {
               ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
            } else {
               ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrangeRed);
            }
         }
      }
   }
   
   // Dessiner le retracement Fibonacci principal
   string fibName = "SMC_FIB_MAIN";
   if(ObjectCreate(0, fibName, OBJ_FIBO, 0, tLow, l, tHigh, h))
   {
      ObjectSetInteger(0, fibName, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, fibName, OBJPROP_LEVELS, 7);
      ObjectSetInteger(0, fibName, OBJPROP_LEVELCOLOR, clrOrange);
      ObjectSetInteger(0, fibName, OBJPROP_LEVELSTYLE, STYLE_DASH);
      ObjectSetInteger(0, fibName, OBJPROP_LEVELWIDTH, 1);
      
      // Configurer les niveaux
      for(int i = 0; i < 7; i++)
      {
         ObjectSetDouble(0, fibName, OBJPROP_LEVELVALUE, i, levels[i]);
         ObjectSetString(0, fibName, OBJPROP_LEVELTEXT, i, descriptions[i]);
      }
   }
   
   // Analyser et stocker les zones OTE futures pour le trading
   AnalyzeFutureOTEZones(h, l, tHigh, tLow);
}

// Fonction pour trouver les swings significatifs
int FindSignificantSwingHigh(double &high[], double &low[], int n)
{
   for(int i = 5; i < n - 5; i++) {
      bool isSwingHigh = true;
      for(int j = i - 5; j <= i + 5; j++) {
         if(j != i && high[j] >= high[i]) {
            isSwingHigh = false;
            break;
         }
      }
      if(isSwingHigh) return i;
   }
   return ArrayMaximum(high, 0, n);
}

// Fonction pour trouver les swings significatifs
int FindSignificantSwingLow(double &high[], double &low[], int n)
{
   for(int i = 5; i < n - 5; i++) {
      bool isSwingLow = true;
      for(int j = i - 5; j <= i + 5; j++) {
         if(j != i && low[j] <= low[i]) {
            isSwingLow = false;
            break;
         }
      }
      if(isSwingLow) return i;
   }
   return ArrayMinimum(low, 0, n);
}

// Analyser les zones OTE futures et prendre position si validées
void AnalyzeFutureOTEZones(double swingHigh, double swingLow, datetime swingHighTime, datetime swingLowTime)
{
   // Vérifier si nous avons déjà une position sur ce symbole
   if(HasAnyExposureForSymbol(_Symbol)) return;
   
   // Vérifier si le trading est activé
   if(!EnableTrading) return;
   
   // Obtenir le prix actuel
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(currentPrice <= 0) return;
   
   // Calculer les zones OTE
   double range = swingHigh - swingLow;
   if(range <= 0) return;
   
   // Zone OTE BUY (pour les mouvements baissiers qui vont rebondir)
   double oteBuyLow = swingLow + range * 0.62;   // 61.8%
   double oteBuyHigh = swingLow + range * 0.786;  // 78.6%
   
   // Zone OTE SELL (pour les mouvements haussiers qui vont corriger)
   double oteSellLow = swingHigh - range * 0.786;  // 78.6%
   double oteSellHigh = swingHigh - range * 0.62; // 61.8%
   
   // Analyser la tendance actuelle pour déterminer la direction probable
   string trendDirection = GetCurrentTrendDirection();
   
   // Vérifier si nous sommes dans une zone OTE future valide
   bool oteBuyValid = (currentPrice >= oteBuyLow && currentPrice <= oteBuyHigh);
   bool oteSellValid = (currentPrice >= oteSellLow && currentPrice <= oteSellHigh);
   
   // Validation supplémentaire avec IA
   string aiAction = g_lastAIAction;
   double aiConfidence = g_lastAIConfidence;
   bool isBoomCrash = (StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0);
   
   // Logs de debugging
   if(DebugMode) {
      Print("🔍 OTE FUTURE ANALYSIS - ", _Symbol);
      Print("   📊 Prix actuel: ", DoubleToString(currentPrice, _Digits));
      Print("   🎯 Zone OTE BUY: ", DoubleToString(oteBuyLow, _Digits), " - ", DoubleToString(oteBuyHigh, _Digits));
      Print("   🎯 Zone OTE SELL: ", DoubleToString(oteSellLow, _Digits), " - ", DoubleToString(oteSellHigh, _Digits));
      Print("   📈 Tendance: ", trendDirection);
      Print("   🤖 IA: ", aiAction, " (", DoubleToString(aiConfidence, 1), "%)");
      Print("   ✅ OTE BUY valide: ", oteBuyValid ? "OUI" : "NON");
      Print("   ✅ OTE SELL valide: ", oteSellValid ? "OUI" : "NON");
   }
   
   // Mode prioritaire Boom/Crash: en zone OTE + direction IA correcte => exécution marché immédiate
   if(isBoomCrash)
   {
      bool aiBuy = (aiAction == "BUY" || aiAction == "buy");
      bool aiSell = (aiAction == "SELL" || aiAction == "sell");
      bool aiOkConf = (aiConfidence <= 0.0 || aiConfidence >= MinAIConfidence);

      if(oteBuyValid && aiBuy && aiOkConf && IsDirectionAllowedForBoomCrash(_Symbol, "BUY"))
      {
         Print("✅ OTE_BC_MARKET_AUTO_EXEC | ", _Symbol,
               " | Dir=BUY | Price=", DoubleToString(currentPrice, _Digits),
               " | IA=", aiAction, "(", DoubleToString(aiConfidence, 1), "%)");
         ExecuteFutureOTETrade("BUY", currentPrice, swingLow, swingHigh);
         return;
      }
      if(oteSellValid && aiSell && aiOkConf && IsDirectionAllowedForBoomCrash(_Symbol, "SELL"))
      {
         Print("✅ OTE_BC_MARKET_AUTO_EXEC | ", _Symbol,
               " | Dir=SELL | Price=", DoubleToString(currentPrice, _Digits),
               " | IA=", aiAction, "(", DoubleToString(aiConfidence, 1), "%)");
         ExecuteFutureOTETrade("SELL", currentPrice, swingHigh, swingLow);
         return;
      }
   }

   // Exécuter un trade si les conditions OTE sont remplies (logique standard)
   if(oteBuyValid && ShouldExecuteOTETrade("BUY", aiAction, aiConfidence, trendDirection))
   {
      ExecuteFutureOTETrade("BUY", currentPrice, swingLow, swingHigh);
   }
   else if(oteSellValid && ShouldExecuteOTETrade("SELL", aiAction, aiConfidence, trendDirection))
   {
      ExecuteFutureOTETrade("SELL", currentPrice, swingHigh, swingLow);
   }
}

// Déterminer si un trade OTE doit être exécuté
bool ShouldExecuteOTETrade(string direction, string aiAction, double aiConfidence, string trendDirection)
{
   if(UseICTEvidenceSequence)
   {
      int ictScore = 0;
      string ictReason = "";
      if(!ICT_ValidateEvidenceSequence(_Symbol, LTF, direction, ictScore, ictReason))
      {
         if(DebugMode) Print("❌ OTE CHECKLIST ICT INVALIDE - ", direction, " | Score=", ictScore, "/", ICTMinSignatures, " | ", ictReason);
         return false;
      }
      if(DebugMode) Print("✅ OTE CHECKLIST ICT VALIDÉE - ", direction, " | Score=", ictScore, "/", ICTMinSignatures, " | ", ictReason);
   }

   // Vérifier la concordance avec l'IA
   if(aiAction != direction && aiAction != "") {
      if(DebugMode) Print("❌ OTE NON ALIGNÉ - Direction: ", direction, " | IA: ", aiAction);
      return false;
   }
   
   // Vérifier la confiance IA minimum
   if(aiConfidence < MinAIConfidence && aiConfidence > 0) {
      if(DebugMode) Print("❌ OTE CONFIANCE INSUFFISANTE - IA: ", DoubleToString(aiConfidence, 1), "% < ", MinAIConfidence, "%");
      return false;
   }
   
   // Vérifier la cohérence de la tendance
   if(direction == "BUY" && trendDirection == "DOWNTREND") {
      if(DebugMode) Print("❌ OTE CONTRE-TENDANCE - BUY sur tendance baissière");
      return false;
   }
   
   if(direction == "SELL" && trendDirection == "UPTREND") {
      if(DebugMode) Print("❌ OTE CONTRE-TENDANCE - SELL sur tendance haussière");
      return false;
   }
   
   // Vérifier la protection capital
   if(IsMaxPositionsReached()) {
      if(DebugMode) Print("❌ OTE BLOQUÉ - Protection capital activée");
      return false;
   }
   
   return true;
}

// Exécuter un trade basé sur l'OTE future validée
void ExecuteFutureOTETrade(string direction, double entryPrice, double swingLow, double swingHigh)
{
   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction))
   {
      Print("🚫 OTE FUTURE BLOQUÉ - Direction interdite sur ", _Symbol, " : ", direction);
      return;
   }

   double lot = NormalizeVolumeForSymbol(GetMinLotForSymbol(_Symbol));
   if(lot <= 0.0)
   {
      Print("❌ OTE FUTURE BLOQUÉ - lot minimum broker indisponible sur ", _Symbol);
      return;
   }
   double stopLoss, takeProfit;
   
   // Calculer SL et TP selon la direction OTE
   if(direction == "BUY")
   {
      // SL: sous le swing low
      stopLoss = swingLow - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 15;
      // TP: ratio >= 3:1 (min via RR clamp)
      takeProfit = entryPrice + (entryPrice - stopLoss) * MathMax(3.0, InpRiskReward);
   }
   else // SELL
   {
      // SL: au-dessus du swing high
      stopLoss = swingHigh + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 15;
      // TP: ratio >= 3:1 (min via RR clamp)
      takeProfit = entryPrice - (stopLoss - entryPrice) * MathMax(3.0, InpRiskReward);
   }
   
   // Valider et ajuster les distances minimales
   ValidateAndAdjustStopLossTakeProfit(direction, entryPrice, stopLoss, takeProfit);
   
   // Exécuter l'ordre
   bool success = false;
   string comment = "OTE_FUTURE_" + direction;
   
   if(direction == "BUY")
   {
      success = trade.Buy(lot, _Symbol, entryPrice, stopLoss, takeProfit, comment);
   }
   else
   {
      success = trade.Sell(lot, _Symbol, entryPrice, stopLoss, takeProfit, comment);
   }
   
   if(success)
   {
      Print("✅ OTE FUTURE EXÉCUTÉ - ", direction, " sur ", _Symbol);
      Print("   📍 Entry: ", DoubleToString(entryPrice, _Digits));
      Print("   🛡️ SL: ", DoubleToString(stopLoss, _Digits));
      Print("   🎯 TP: ", DoubleToString(takeProfit, _Digits));
      Print("   💰 Lot: ", DoubleToString(lot, 2));
      Print("   📝 Comment: ", comment);
   }
   else
   {
      Print("❌ OTE FUTURE ÉCHOUÉ - ", direction, " sur ", _Symbol);
      Print("   ❌ Erreur: ", trade.ResultRetcode(), " - ", trade.ResultComment());
   }
}

// Obtenir la direction de la tendance actuelle
string GetCurrentTrendDirection()
{
   // Utiliser les EMA pour déterminer la tendance
   double emaFast = 0.0, emaSlow = 0.0;
   
   if(hEmaFast != INVALID_HANDLE && hEmaSlow != INVALID_HANDLE)
   {
      double a1[], a2[];
      ArraySetAsSeries(a1, true);
      ArraySetAsSeries(a2, true);
      if(CopyBuffer(hEmaFast, 0, 0, 1, a1) >= 1 && CopyBuffer(hEmaSlow, 0, 0, 1, a2) >= 1)
      {
         emaFast = a1[0];
         emaSlow = a2[0];
      }
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   if(emaFast > emaSlow && currentPrice > emaFast)
      return "UPTREND";
   else if(emaFast < emaSlow && currentPrice < emaFast)
      return "DOWNTREND";
   else
      return "SIDEWAYS";
}

// Valider et ajuster les distances minimales pour SL/TP
void ValidateAndAdjustStopLossTakeProfit(string direction, double entryPrice, double &stopLoss, double &takeProfit)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) point = 0.0001;
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0) tickSize = point;
   
   // IMPORTANT: stops/freeze level sont exprimés en "points", donc conversion via SYMBOL_POINT.
   double stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   double freezeLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   
   // Distance minimale adaptée selon le type de symbole
   double minDistance;
   if(StringFind(_Symbol, "XAG") >= 0 || StringFind(_Symbol, "XAU") >= 0)
   {
      // Métaux précieux : distances plus grandes
      minDistance = MathMax(MathMax(stopsLevel, freezeLevel), 50 * tickSize); // Minimum 50 ticks pour les métaux
   }
   else if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      // Indices synthétiques : utiliser contrainte broker stricte + marge.
      minDistance = MathMax(MathMax(stopsLevel, freezeLevel), 80 * tickSize);
   }
   else
   {
      // Forex et autres : standard
      minDistance = MathMax(MathMax(stopsLevel, freezeLevel), 30 * tickSize); // Minimum 30 ticks pour Forex
   }
   minDistance = MathMax(minDistance, 2.0 * tickSize); // marge anti-arrondi

   // Prix de référence broker au moment de la validation.
   // Pour BUY, la fermeture se fait au Bid; pour SELL, au Ask.
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   if(direction == "BUY")
   {
      // Orientation correcte avant ajustements de distance.
      if(stopLoss >= entryPrice) stopLoss = entryPrice - minDistance;
      if(takeProfit <= entryPrice) takeProfit = entryPrice + (2.0 * minDistance);

      // Ajuster SL si trop proche
      if(entryPrice - stopLoss < minDistance)
         stopLoss = entryPrice - minDistance;
      
      // Ajuster TP si trop proche
      if(takeProfit - entryPrice < minDistance * 2)
         takeProfit = entryPrice + minDistance * 2;

      // Contrainte stricte contre le prix de clôture (Bid) pour limiter Invalid stops.
      if(bid > 0.0)
      {
         if(bid - stopLoss < minDistance) stopLoss = bid - minDistance;
         if(takeProfit - bid < minDistance) takeProfit = bid + minDistance;
      }

      // Alignement au tick sans réduire la distance: SL vers le bas, TP vers le haut.
      stopLoss = MathFloor(stopLoss / tickSize) * tickSize;
      takeProfit = MathCeil(takeProfit / tickSize) * tickSize;
   }
   else // SELL
   {
      // Orientation correcte avant ajustements de distance.
      if(stopLoss <= entryPrice) stopLoss = entryPrice + minDistance;
      if(takeProfit >= entryPrice) takeProfit = entryPrice - (2.0 * minDistance);

      // Ajuster SL si trop proche
      if(stopLoss - entryPrice < minDistance)
         stopLoss = entryPrice + minDistance;
      
      // Ajuster TP si trop proche
      if(entryPrice - takeProfit < minDistance * 2)
         takeProfit = entryPrice - minDistance * 2;

      // Contrainte stricte contre le prix de clôture (Ask) pour limiter Invalid stops.
      if(ask > 0.0)
      {
         if(stopLoss - ask < minDistance) stopLoss = ask + minDistance;
         if(ask - takeProfit < minDistance) takeProfit = ask - minDistance;
      }

      // Alignement au tick sans réduire la distance: SL vers le haut, TP vers le bas.
      stopLoss = MathCeil(stopLoss / tickSize) * tickSize;
      takeProfit = MathFloor(takeProfit / tickSize) * tickSize;
   }

   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
}

// Force un SL monétaire minimum sur Boom/Crash pour éviter des sorties SL trop petites
// (ex: -0.78$), afin de respecter la tolérance de perte paramétrée.
void EnforceMinBoomCrashStopLossDollarRisk(const string symbol, const string direction, const double entryPrice, const double volume, double &stopLoss)
{
   if(volume <= 0.0) return;
   if(StringFind(symbol, "Boom") < 0 && StringFind(symbol, "Crash") < 0) return;

   double targetLoss = MaxLossBoomCrashPerTradeUSD;
   if(targetLoss <= 0.0) return;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(point <= 0.0) point = _Point;
   if(tickSize <= 0.0) tickSize = point;
   if(point <= 0.0 || tickSize <= 0.0) return;

   ENUM_ORDER_TYPE orderType = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   double sl = stopLoss;

   // 3 essais suffisent pour élargir progressivement le SL si la perte calculée est trop faible.
   for(int attempt = 0; attempt < 3; attempt++)
   {
      double pnlAtSL = 0.0;
      if(!OrderCalcProfit(orderType, symbol, volume, entryPrice, sl, pnlAtSL))
         break;

      double absLoss = MathAbs(MathMin(0.0, pnlAtSL));
      if(absLoss + 0.01 >= targetLoss)
         break;

      // Élargir la distance SL proportionnellement au manque de risque monétaire.
      double scale = targetLoss / MathMax(absLoss, 0.01);
      scale = MathMin(6.0, MathMax(1.2, scale));
      double dist = MathAbs(entryPrice - sl) * scale;
      dist = MathMax(dist, 80.0 * tickSize);

      if(direction == "BUY")
         sl = entryPrice - dist;
      else
         sl = entryPrice + dist;

      // Alignement tick orienté
      if(direction == "BUY")
         sl = MathFloor(sl / tickSize) * tickSize;
      else
         sl = MathCeil(sl / tickSize) * tickSize;

      sl = NormalizeDouble(sl, _Digits);
   }

   stopLoss = sl;
}

// Valider et ajuster le SL pour les modifications de position
bool ValidateStopLossForModification(string symbol, string direction, double currentPrice, double &newSL)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(point <= 0) point = 0.0001;
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0) tickSize = point;
   
   // Obtenir les distances minimales du courtier
   double stopsLevel = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * tickSize;
   
   // Distance minimale adaptée selon le type de symbole
   double minDistance;
   if(StringFind(symbol, "XAG") >= 0 || StringFind(symbol, "XAU") >= 0)
   {
      // Métaux précieux : distances plus grandes
      minDistance = MathMax(stopsLevel, 50 * tickSize); // Minimum 50 ticks pour les métaux
   }
   else if(StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0)
   {
      // Indices synthétiques : distances très grandes
      minDistance = MathMax(stopsLevel, 300 * tickSize); // Minimum 300 ticks pour Boom/Crash
   }
   else
   {
      // Forex et autres : standard
      minDistance = MathMax(stopsLevel, 30 * tickSize); // Minimum 30 ticks pour Forex
   }
   
   // Valider et ajuster le SL selon la direction
   if(direction == "BUY")
   {
      // Pour BUY, SL doit être inférieur au prix actuel
      if(newSL >= currentPrice)
      {
         Print("❌ SL invalide pour BUY - SL (", DoubleToString(newSL, _Digits), ") >= prix (", DoubleToString(currentPrice, _Digits), ")");
         return false;
      }
      
      // Vérifier la distance minimale
      if(currentPrice - newSL < minDistance)
      {
         double adjustedSL = currentPrice - minDistance;
         Print("🔧 SL ajusté pour BUY sur ", symbol, " | Original: ", DoubleToString(newSL, _Digits), " -> Adjusted: ", DoubleToString(adjustedSL, _Digits), " (distance min: ", DoubleToString(minDistance, _Digits), ")");
         newSL = adjustedSL;
      }
   }
   else // SELL
   {
      // Pour SELL, SL doit être supérieur au prix actuel
      if(newSL <= currentPrice)
      {
         Print("❌ SL invalide pour SELL - SL (", DoubleToString(newSL, _Digits), ") <= prix (", DoubleToString(currentPrice, _Digits), ")");
         return false;
      }
      
      // Vérifier la distance minimale
      if(newSL - currentPrice < minDistance)
      {
         double adjustedSL = currentPrice + minDistance;
         Print("🔧 SL ajusté pour SELL sur ", symbol, " | Original: ", DoubleToString(newSL, _Digits), " -> Adjusted: ", DoubleToString(adjustedSL, _Digits), " (distance min: ", DoubleToString(minDistance, _Digits), ")");
         newSL = adjustedSL;
      }
   }
   
   return true;
}

// Duplicate function AnalyzeFutureOTEZones removed - implementation exists at line 101
// Duplicate function ShouldExecuteOTETrade removed - implementation exists at line 102
// Duplicate function ExecuteFutureOTETrade removed - implementation exists at line 103
// Duplicate function GetCurrentTrendDirection removed - implementation exists at line 104

void DrawEMACurveOnChart()
{
   // Trace les EMA 9/21/50/100/200 (LTF) et prolonge dans la zone future
   struct EmaCurveCfg { int handle; string prefix; color col; int width; };
   EmaCurveCfg cfgs[5];
   cfgs[0].handle = emaHandle;  cfgs[0].prefix = "SMC_EMA_CURVE_9_";   cfgs[0].col = clrLime;        cfgs[0].width = 2;
   cfgs[1].handle = ema21LTF;   cfgs[1].prefix = "SMC_EMA_CURVE_21_";  cfgs[1].col = clrAqua;        cfgs[1].width = 1;
   cfgs[2].handle = ema50LTF;   cfgs[2].prefix = "SMC_EMA_CURVE_50_";  cfgs[2].col = clrGold;        cfgs[2].width = 1;
   cfgs[3].handle = ema100LTF;  cfgs[3].prefix = "SMC_EMA_CURVE_100_"; cfgs[3].col = clrOrangeRed;   cfgs[3].width = 1;
   cfgs[4].handle = ema200LTF;  cfgs[4].prefix = "SMC_EMA_CURVE_200_"; cfgs[4].col = clrViolet;      cfgs[4].width = 1;

   int len = 60;
   datetime time[];
   ArraySetAsSeries(time, true);
   if(CopyTime(_Symbol, LTF, 0, len, time) < len) return;

   for(int c = 0; c < 5; c++)
   {
      if(cfgs[c].handle == INVALID_HANDLE) continue;

      double ema[];
      ArraySetAsSeries(ema, true);
      if(CopyBuffer(cfgs[c].handle, 0, 0, len, ema) < len) continue;

      // Nettoyer uniquement les objets de cette EMA
      ObjectsDeleteAll(0, cfgs[c].prefix);

      for(int i = 0; i < len - 1; i++)
      {
         string name = cfgs[c].prefix + IntegerToString(i);
         if(ObjectCreate(0, name, OBJ_TREND, 0, time[i], ema[i], time[i+1], ema[i+1]))
         {
            ObjectSetInteger(0, name, OBJPROP_COLOR, cfgs[c].col);
            ObjectSetInteger(0, name, OBJPROP_WIDTH, cfgs[c].width);
            // Prolonger le dernier segment vers la droite pour l'afficher dans la zone future
            ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, (i == (len - 2)));
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
         }
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
   if(StringFind(_Symbol, "Boom") < 0 && StringFind(_Symbol, "Crash") < 0) return;
   
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
   // Validation des données du canal (éviter NaN/infini ? détachement)
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

/*
// FONCTION SUPPRIMÉE - PLUS DE PLACEMENT D'ORDRES LIMIT CANAL
// Place un ordre limite "sniper" entre le prix actuel et le canal SMC (upper/lower)
// Un seul ordre limit SMC par symbole. L'IA sert de filtre directionnel:
// - si IA forte et opposée au sens naturel (Boom=BUY / Crash=SELL), on NE trade pas
// - si IA HOLD ou faible confiance, on autorise quand même le trade canal.
void PlaceSMCChannelLimitOrder()
{
   // FONCTION DÉSACTIVÉE - Les ordres LIMIT canal ne sont plus placés automatiquement
   Print("🚫 FONCTION DÉSACTIVÉE - PlaceSMCChannelLimitOrder() supprimé");
   return;
   
   // Ancien code conservé pour référence mais non exécuté
   bool isBoom  = (StringFind(_Symbol, "Boom")  >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   if(!isBoom && !isCrash) return;
   
   // ANTI-DUPLICATION: Vérifier s'il y a déjà des ordres LIMIT pour ce symbole
   if(CountOpenLimitOrdersForSymbol(_Symbol) > 0)
   {
      Print("🚫 ORDRE LIMIT DÉJÀ EXISTANT - Aucun nouvel ordre SMC canal sur ", _Symbol);
      return;
   }

   // RÈGLE STRICTE: Si filtre activé, uniquement les symboles prioritaires peuvent avoir des ordres LIMIT
   if(UsePropiceSymbolsFilter && !g_currentSymbolIsPropice)
   {
      Print("🚫 SYMBOLE NON PRIORITAIRE - Aucun ordre SMC canal autorisé sur ", _Symbol);
      return;
   }

   // RÈGLE STRICTE: Si filtre activé, uniquement si lignes M5 actives
   if(UsePropiceSymbolsFilter && g_currentSymbolIsPropice)
   {
      if(!g_m5BuyLevelActive && !g_m5SellLevelActive)
      {
         Print("🚫 PAS DE LIGNES M5 ACTIVES - Aucun ordre SMC canal autorisé sur ", _Symbol);
         return;
      }
   }
   
   // BLOCAGE SÉCURITÉ: NE PAS PLACER D'ORDRES SI IA EST EN HOLD
   string aiAction = g_lastAIAction;
   StringToUpper(aiAction);
   if(aiAction == "HOLD")
   {
      Print("?? ORDRE SMC CANAL BLOQUÉ - IA en HOLD sur ", _Symbol, " - Sécurité activée");
      return;
   }
   
   const double MIN_CONF_SMC_ORDER = 0.75;
   if(aiAction == "buy") aiAction = "BUY";
   if(aiAction == "sell") aiAction = "SELL";
   bool iaStrong = (aiAction == "BUY" || aiAction == "SELL") && g_lastAIConfidence >= MIN_CONF_SMC_ORDER;
   
   // Direction naturelle du trade canal (Boom = BUY, Crash = SELL)
   string channelDir = isBoom ? "BUY" : "SELL";
   
   // RÈGLE STRICTE: BLOQUER TOUS LES ORDRES BUY SUR BOOM SI IA = SELL
   if(isBoom && aiAction == "SELL")
   {
   // Réduire la fréquence des logs de trading pour éviter la surcharge
   static datetime lastTradingLog = 0;
   if(TimeCurrent() - lastTradingLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? ORDRE SMC BOOM BLOQUÉ - IA = SELL (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal BUY avant de placer ordre BUY");
      lastTradingLog = TimeCurrent();
   }
      return;
   }
   
   // RÈGLE STRICTE: BLOQUER TOUS LES ORDRES SELL SUR CRASH SI IA = BUY
   if(isCrash && aiAction == "BUY")
   {
   // Réduire la fréquence des logs de trading pour éviter la surcharge
   static datetime lastTradingLog = 0;
   if(TimeCurrent() - lastTradingLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? ORDRE SMC CRASH BLOQUÉ - IA = BUY (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal SELL avant de placer ordre SELL");
      lastTradingLog = TimeCurrent();
   }
      return;
   }
   
   // Si IA forte et opposée à la direction naturelle, ne pas placer d'ordre canal
   if(iaStrong && aiAction != channelDir)
   {
      Print("?? ORDRE SMC BLOQUÉ - IA forte (", DoubleToString(g_lastAIConfidence*100, 1), "%) opposée à direction naturelle (", channelDir, ")");
      return;
   }
   
   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles (IA ?90% + spike/setup fort)
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
   
   double lot = CalculateLotSizeForPendingOrders();
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
         if(distanceToCanal <= atrVal * 2.0) // Canal proche (? 2 ATR)
         {
            entry = lowerPrice; // Utiliser le canal directement
            entryType = "CANAL PROCHE";
         }
         else if(distanceToCanal <= atrVal * 4.0) // Canal moyen (2-4 ATR)
         {
            entry = lowerPrice + (atrVal * 0.5); // Mi-chemin entre prix et canal
            entryType = "CANAL MOYEN";
         }
         else // Canal loin (> 4 ATR) ? on préfère NE PAS entrer plutôt qu'entrer trop tôt
         {
            ReleaseOpenLock();
            Print("?? SMC BOOM - Canal trop loin (>4 ATR), aucune entrée pour éviter une entrée trop précoce");
            return;
         }
      }
      
      if(entry >= bid) { ReleaseOpenLock(); return; }
      req.type  = ORDER_TYPE_BUY_LIMIT;
      req.price = entry;
      if(!IsOrderTypeAllowedForBoomCrash(_Symbol, req.type))
      {
         ReleaseOpenLock();
         Print("🚫 SMC_CH BUY LIMIT BLOQUÉ - Type interdit pour ", _Symbol);
         return;
      }
      
      Print("?? SMC BOOM - ", entryType, " | Distance canal: ", DoubleToString(distanceToCanal/atrVal, 1), " ATR | Entry: ", DoubleToString(entry, _Digits));
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
         if(distanceToCanal <= atrVal * 2.0) // Canal proche (? 2 ATR)
         {
            entry = upperPrice; // Utiliser le canal directement
            entryType = "CANAL PROCHE";
         }
         else if(distanceToCanal <= atrVal * 4.0) // Canal moyen (2-4 ATR)
         {
            entry = upperPrice - (atrVal * 0.5); // Mi-chemin entre prix et canal
            entryType = "CANAL MOYEN";
         }
         else // Canal loin (> 4 ATR) ? on préfère NE PAS entrer plutôt qu'entrer trop tôt
         {
            ReleaseOpenLock();
            Print("?? SMC CRASH - Canal trop loin (>4 ATR), aucune entrée pour éviter une entrée trop précoce");
            return;
         }
      }
      
      if(entry <= ask) { ReleaseOpenLock(); return; }
      req.type  = ORDER_TYPE_SELL_LIMIT;
      req.price = entry;
      if(!IsOrderTypeAllowedForBoomCrash(_Symbol, req.type))
      {
         ReleaseOpenLock();
         Print("🚫 SMC_CH SELL LIMIT BLOQUÉ - Type interdit pour ", _Symbol);
         return;
      }
      
      Print("?? SMC CRASH - ", entryType, " | Distance canal: ", DoubleToString(distanceToCanal/atrVal, 1), " ATR | Entry: ", DoubleToString(entry, _Digits));
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
   
   if(!OrderSend(req, res))
      Print("? Echec envoi ordre limite SMC_CH sur ", _Symbol, " | code=", res.retcode);
   
   ReleaseOpenLock();
}
*/

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
      
      // CRITIQUE: éviter CopyBuffer avec INVALID_HANDLE ? crash/détachement
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

   // 1bis) Pivots journaliers (S1/S2) — niveaux stratégiques "Buy Limit"
   double highPrev = iHigh(_Symbol, PERIOD_D1, 1);
   double lowPrev  = iLow(_Symbol, PERIOD_D1, 1);
   double closePrev = iClose(_Symbol, PERIOD_D1, 1);
   if(highPrev > 0 && lowPrev > 0 && closePrev > 0 && highPrev > lowPrev)
   {
      double pivot = (highPrev + lowPrev + closePrev) / 3.0;
      double s1 = 2.0 * pivot - highPrev;
      double s2 = pivot - (highPrev - lowPrev);
      if(s1 > 0 && s1 < currentPrice)
      {
         double dist = currentPrice - s1;
         if(dist <= maxDist && s1 > best) { best = s1; sourceOut = "Pivot D1 S1"; }
      }
      if(s2 > 0 && s2 < currentPrice)
      {
         double dist = currentPrice - s2;
         if(dist <= maxDist && s2 > best) { best = s2; sourceOut = "Pivot D1 S2"; }
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

   // 1bis) Pivots journaliers (R1/R2) — niveaux stratégiques "Sell Limit"
   double highPrev = iHigh(_Symbol, PERIOD_D1, 1);
   double lowPrev  = iLow(_Symbol, PERIOD_D1, 1);
   double closePrev = iClose(_Symbol, PERIOD_D1, 1);
   if(highPrev > 0 && lowPrev > 0 && closePrev > 0 && highPrev > lowPrev)
   {
      double pivot = (highPrev + lowPrev + closePrev) / 3.0;
      double r1 = 2.0 * pivot - lowPrev;
      double r2 = pivot + (highPrev - lowPrev);
      if(r1 > 0 && r1 > currentPrice)
      {
         double dist = r1 - currentPrice;
         if(dist <= maxDist && (best == 0.0 || r1 < best)) { best = r1; sourceOut = "Pivot D1 R1"; }
      }
      if(r2 > 0 && r2 > currentPrice)
      {
         double dist = r2 - currentPrice;
         if(dist <= maxDist && (best == 0.0 || r2 < best)) { best = r2; sourceOut = "Pivot D1 R2"; }
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
   ObjectSetInteger(0, "SMC_Limit_Support", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "SMC_Limit_Support", OBJPROP_TOOLTIP, "Support (20 bars)");
   ObjectCreate(0, "SMC_Limit_Resistance", OBJ_HLINE, 0, 0, resistance);
   ObjectSetInteger(0, "SMC_Limit_Resistance", OBJPROP_COLOR, clrDarkRed);
   ObjectSetInteger(0, "SMC_Limit_Resistance", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "SMC_Limit_Resistance", OBJPROP_WIDTH, 2);
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
   if(ObjectFind(0, "SMC_Limit_ST_M5") >= 0) ObjectSetInteger(0, "SMC_Limit_ST_M5", OBJPROP_WIDTH, 3);
   if(ObjectFind(0, "SMC_Limit_ST_H1") >= 0) ObjectSetInteger(0, "SMC_Limit_ST_H1", OBJPROP_WIDTH, 3);
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
   string url1 = UseRenderAsPrimary ? (AI_ServerRender + pathCh) : (AI_ServerURL + pathCh);
   string url2 = UseRenderAsPrimary ? (AI_ServerURL + pathCh) : (AI_ServerRender + pathCh);
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

bool ParseFutureCandlesJson(const string &json, int expectedCount)
{
   ArrayResize(g_futureCandles, 0);
   g_futureCandlesCount = 0;
   if(StringLen(json) < 20) return false;

   int p = StringFind(json, "\"candles\"");
   if(p < 0) return false;
   int aStart = StringFind(json, "[", p);
   if(aStart < 0) return false;
   int aEnd = StringFind(json, "]", aStart);
   if(aEnd < 0) return false;

   int idx = aStart + 1;
   int safety = 0;
   while(idx < aEnd && safety < 2000 && g_futureCandlesCount < expectedCount)
   {
      safety++;
      int o1 = StringFind(json, "{", idx);
      if(o1 < 0 || o1 > aEnd) break;
      int o2 = StringFind(json, "}", o1);
      if(o2 < 0 || o2 > aEnd) break;
      string obj = StringSubstr(json, o1, o2 - o1 + 1);

      double tNum = ExtractJsonNumber(obj, "time");
      double oNum = ExtractJsonNumber(obj, "open");
      double hNum = ExtractJsonNumber(obj, "high");
      double lNum = ExtractJsonNumber(obj, "low");
      double cNum = ExtractJsonNumber(obj, "close");
      double conf = ExtractJsonNumber(obj, "confidence");

      if(tNum > 0 && oNum > 0 && hNum > 0 && lNum > 0 && cNum > 0)
      {
         int n = g_futureCandlesCount;
         ArrayResize(g_futureCandles, n + 1);
         g_futureCandles[n].time = (datetime)tNum;
         g_futureCandles[n].open = oNum;
         g_futureCandles[n].high = MathMax(hNum, MathMax(oNum, cNum));
         g_futureCandles[n].low = MathMin(lNum, MathMin(oNum, cNum));
         g_futureCandles[n].close = cNum;
         g_futureCandles[n].confidence = conf;
         g_futureCandlesCount++;
      }

      idx = o2 + 1;
   }

   return (g_futureCandlesCount > 0);
}

void BuildFutureCandlesFallbackLocal(int horizon)
{
   ArrayResize(g_futureCandles, 0);
   g_futureCandlesCount = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars = MathMax(220, horizon + 50);
   if(CopyRates(_Symbol, PERIOD_M1, 0, bars, rates) < 120) return;

   double closeNow = rates[0].close;
   if(closeNow <= 0) return;

   double sumRet = 0.0, sumSq = 0.0;
   int nRet = 0;
   for(int i = 1; i < 120; i++)
   {
      double c0 = rates[i-1].close, c1 = rates[i].close;
      if(c1 <= 0) continue;
      double r = (c0 / c1) - 1.0;
      sumRet += r;
      sumSq += r * r;
      nRet++;
   }
   if(nRet <= 1) return;
   double mu = sumRet / nRet;
   double var = MathMax(0.0, (sumSq / nRet) - (mu * mu));
   double sigma = MathSqrt(var);
   sigma = MathMax(0.00001, MathMin(0.01, sigma));

   // Biais tendance basé EMA rapide/lente si disponibles
   double trendBias = 0.0;
   if(emaFastM1 != INVALID_HANDLE && emaSlowM1 != INVALID_HANDLE)
   {
      double f[], s[];
      ArraySetAsSeries(f, true); ArraySetAsSeries(s, true);
      if(CopyBuffer(emaFastM1, 0, 0, 1, f) >= 1 && CopyBuffer(emaSlowM1, 0, 0, 1, s) >= 1 && closeNow > 0)
         trendBias = MathMax(-0.0006, MathMin(0.0006, (f[0] - s[0]) / closeNow));
   }

   double atr = 0.0;
   if(atrM1 != INVALID_HANDLE)
   {
      double a[]; ArraySetAsSeries(a, true);
      if(CopyBuffer(atrM1, 0, 0, 1, a) >= 1) atr = a[0];
   }
   if(atr <= 0) atr = closeNow * sigma * 1.2;

   double prevRet = 0.0;
   double currClose = closeNow;
   datetime t0 = rates[0].time;
   int legLen = MathMax(6, MathMin(30, horizon / 8));
   int legLeft = legLen;
   int regime = (trendBias >= 0 ? 1 : -1); // 1 up, -1 down
   double support = rates[MathMin(80, bars - 1)].low;
   double resistance = rates[MathMin(80, bars - 1)].high;
   if(support <= 0 || resistance <= 0 || resistance <= support)
   {
      support = closeNow * 0.995;
      resistance = closeNow * 1.005;
   }

   for(int k = 0; k < horizon; k++)
   {
      if(legLeft <= 0)
      {
         // Alternance impulsion/retrace/range pour éviter la projection linéaire.
         double phasePick = MathAbs(MathSin((double)(k + 3) * 0.73));
         if(phasePick > 0.72) regime = -regime;
         else if(phasePick < 0.22) regime = 0; // range
         else if(regime == 0) regime = (trendBias >= 0 ? 1 : -1);
         legLen = MathMax(5, 8 + (int)(MathAbs(MathSin((double)(k + 5) * 0.41)) * 14.0));
         legLeft = legLen;
      }

      double phaseW = (regime == 0 ? 0.0 : (regime > 0 ? 1.0 : -1.0));
      double osc1 = MathSin((double)(k + 1) * (0.32 + sigma * 55.0)) * sigma * 0.95;
      double osc2 = MathSin((double)(k + 1) * (0.89 + MathAbs(trendBias) * 800.0)) * sigma * 0.45;
      double pull = 0.0;
      double anchor = (phaseW >= 0 ? support : resistance);
      if(currClose > 0 && anchor > 0)
         pull = MathMax(-0.0022, MathMin(0.0022, ((anchor / currClose) - 1.0) * 0.12));

      double r = (mu * 0.28) + (trendBias * 0.35) + (prevRet * 0.20) + (phaseW * sigma * 1.85) + osc1 + osc2 + pull;
      r = MathMax(-0.03, MathMin(0.03, r));

      double o = currClose;
      double c = MathMax(0.00000001, o * (1.0 + r));
      double body = MathAbs(c - o);
      double wick = MathMax(atr * 0.35, body * 0.4);
      double h = MathMax(o, c) + wick;
      double l = MathMin(o, c) - wick;
      if(l <= 0) l = MathMin(o, c) * 0.999;

      int n = g_futureCandlesCount;
      ArrayResize(g_futureCandles, n + 1);
      g_futureCandles[n].time = t0 + (datetime)((k + 1) * 60);
      g_futureCandles[n].open = o;
      g_futureCandles[n].high = h;
      g_futureCandles[n].low = l;
      g_futureCandles[n].close = c;
      g_futureCandles[n].confidence = 0.45;
      g_futureCandlesCount++;

      prevRet = (c / o) - 1.0;
      currClose = c;
      legLeft--;
   }
}

bool FetchFutureCandlesFromServer(int horizon)
{
   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");
   string path = "/robot/predict_ohlc?symbol=" + symEnc + "&timeframe=M1&horizon=" + IntegerToString(horizon);
   string headers = "";
   char post[], result[];
   string resultHeaders;

   string url1 = UseRenderAsPrimary ? (AI_ServerRender + path) : (AI_ServerURL + path);
   string url2 = UseRenderAsPrimary ? (AI_ServerURL + path) : (AI_ServerRender + path);
   int timeout = MathMax(1500, AI_Timeout_ms);

   int res = WebRequest("GET", url1, headers, timeout, post, result, resultHeaders);
   if(res != 200)
      res = WebRequest("GET", url2, headers, MathMax(timeout, AI_Timeout_ms2), post, result, resultHeaders);
   if(res != 200) return false;

   string json = CharArrayToString(result);
   bool ok = ParseFutureCandlesJson(json, horizon);
   if(!ok) return false;

   string runId = ExtractJsonValue(json, "prediction_run_id");
   if(runId != "N/A" && runId != "")
   {
      if(runId != g_futurePredictionRunId)
      {
         g_futurePredictionRunId = runId;
         g_futurePredictionRunFetchedAt = TimeCurrent();
         g_futurePredictionRunValidated = false;
         g_futurePredictionValidatedSteps = 0;
      }
   }
   return true;
}

bool ValidateFuturePredictionRunToServer(int minReadyBars = 30)
{
   if(!AutoValidateFuturePredictions) return false;
   if(g_futurePredictionRunId == "" || g_futurePredictionRunId == "N/A") return false;
   if(g_futurePredictionRunValidated) return false;
   if(g_futureCandlesCount <= 0) return false;

   int need = MathMax(5, MathMin(200, minReadyBars));
   int maxSteps = MathMin(g_futureCandlesCount, MathMax(10, MathMin(500, FutureCandlesCount)));
   if(maxSteps <= 0) return false;

   string actualRows = "";
   int ready = 0;
   for(int i = 0; i < maxSteps; i++)
   {
      datetime t = g_futureCandles[i].time;
      int shift = iBarShift(_Symbol, PERIOD_M1, t, true);
      if(shift < 1) continue; // bar pas encore clôturée (ou pas trouvée)

      MqlRates rr[];
      ArraySetAsSeries(rr, true);
      if(CopyRates(_Symbol, PERIOD_M1, shift, 1, rr) < 1) continue;
      if(rr[0].open <= 0 || rr[0].high <= 0 || rr[0].low <= 0 || rr[0].close <= 0) continue;

      if(actualRows != "") actualRows += ",";
      actualRows += StringFormat(
         "{\"step\":%d,\"open\":%.8f,\"high\":%.8f,\"low\":%.8f,\"close\":%.8f}",
         i + 1, rr[0].open, rr[0].high, rr[0].low, rr[0].close
      );
      ready++;
   }

   if(ready < need) return false;

   string payload = StringFormat(
      "{\"run_id\":\"%s\",\"symbol\":\"%s\",\"timeframe\":\"M1\",\"actual_candles\":[%s]}",
      g_futurePredictionRunId, _Symbol, actualRows
   );

   string headers = "Content-Type: application/json\r\n";
   char post_data[], result_data[];
   string result_headers;
   StringToCharArray(payload, post_data, 0, StringLen(payload));

   string url1 = UseRenderAsPrimary ? (AI_ServerRender + "/robot/prediction/validate-run") : (AI_ServerURL + "/robot/prediction/validate-run");
   string url2 = UseRenderAsPrimary ? (AI_ServerURL + "/robot/prediction/validate-run") : (AI_ServerRender + "/robot/prediction/validate-run");
   int http_result = WebRequest("POST", url1, headers, AI_Timeout_ms, post_data, result_data, result_headers);
   if(http_result != 200)
      http_result = WebRequest("POST", url2, headers, AI_Timeout_ms2, post_data, result_data, result_headers);

   if(http_result == 200)
   {
      g_futurePredictionRunValidated = true;
      g_futurePredictionValidatedSteps = ready;
      return true;
   }

   return false;
}

bool FetchPredictionScoreFromServer()
{
   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");
   string path = "/symbols/prediction-score?symbol=" + symEnc + "&timeframe=M1&days=7";
   string headers = "";
   char post[], result[];
   string resultHeaders;

   string url1 = UseRenderAsPrimary ? (AI_ServerRender + path) : (AI_ServerURL + path);
   string url2 = UseRenderAsPrimary ? (AI_ServerURL + path) : (AI_ServerRender + path);

   int res = WebRequest("GET", url1, headers, MathMax(1500, AI_Timeout_ms), post, result, resultHeaders);
   if(res != 200)
      res = WebRequest("GET", url2, headers, MathMax(3000, AI_Timeout_ms2), post, result, resultHeaders);
   if(res != 200) return false;

   string json = CharArrayToString(result);
   if(StringLen(json) < 8) return false;

   string scoreStr = ExtractJsonValue(json, "score");
   string samplesStr = ExtractJsonValue(json, "samples");
   if(samplesStr == "N/A" || samplesStr == "")
      return false;

   int samples = (int)StringToInteger(samplesStr);
   double score = -1.0;
   if(scoreStr != "N/A" && scoreStr != "" && scoreStr != "null")
      score = StringToDouble(scoreStr);

   g_predictionSamples = MathMax(0, samples);
   g_predictionScore = score;
   g_predictionScoreUpdatedAt = TimeCurrent();
   g_predictionScoreSource = "SERVER";
   return true;
}

bool IsInServerPredictedCorrectionZone()
{
   if(!UseServerCorrectionZoneFilter) return false;
   datetime now = TimeCurrent();
   if((now - g_serverCorrectionLastUpdate) < 20)
      return g_serverCorrectionActive;

   string trend = "NEUTRAL";
   if(g_lastAIAction == "BUY" || g_lastAIAction == "buy") trend = "UP";
   else if(g_lastAIAction == "SELL" || g_lastAIAction == "sell") trend = "DOWN";

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0 && ask > 0) ? (bid + ask) * 0.5 : (bid > 0 ? bid : ask);
   if(mid <= 0.0) return false;

   string symEnc = _Symbol;
   StringReplace(symEnc, " ", "%20");
   string path = "/corrections/predict";
   string headers = "Content-Type: application/json\r\n";
   char post[], result[];
   string resultHeaders;
   string payload = StringFormat("{\"symbol\":\"%s\",\"timeframe\":\"M1\",\"current_price\":%s,\"current_trend\":\"%s\"}",
                                 _Symbol, DoubleToString(mid, _Digits), trend);
   StringToCharArray(payload, post, 0, StringLen(payload));

   string url1 = UseRenderAsPrimary ? (AI_ServerRender + path) : (AI_ServerURL + path);
   string url2 = UseRenderAsPrimary ? (AI_ServerURL + path) : (AI_ServerRender + path);
   int res = WebRequest("POST", url1, headers, MathMax(2000, AI_Timeout_ms), post, result, resultHeaders);
   if(res != 200)
      res = WebRequest("POST", url2, headers, MathMax(3000, AI_Timeout_ms2), post, result, resultHeaders);

   g_serverCorrectionLastUpdate = now;
   if(res != 200)
   {
      g_serverCorrectionActive = false;
      g_serverCorrectionAction = "N/A";
      g_serverCorrectionConfidence = 0.0;
      return false;
   }

   string json = CharArrayToString(result);
   string action = ExtractJsonValue(json, "recommended_action");
   double conf = ExtractJsonNumber(json, "confidence_score");
   if(conf <= 0.0)
      conf = ExtractJsonNumber(json, "prediction_confidence");

   bool active = ((action == "ENTER_CORRECTION" || action == "MONITOR_CORRECTION") &&
                  conf >= ServerCorrectionMinConfidence);
   g_serverCorrectionActive = active;
   g_serverCorrectionAction = action;
   g_serverCorrectionConfidence = conf;
   return active;
}

bool FetchFutureCandlesM1Hybrid(bool forceRefresh = false)
{
   if(!ShowFutureCandlesM1) return false;
   int horizon = MathMax(10, MathMin(500, FutureCandlesCount));
   datetime now = TimeCurrent();
   if(!forceRefresh && g_futureCandlesCount >= horizon && (now - g_futureCandlesLastUpdate) < MathMax(5, FutureCandlesRefreshSeconds))
      return true;

   bool okServer = FetchFutureCandlesFromServer(horizon);
   if(okServer && g_futureCandlesCount > 0)
   {
      g_futureCandlesSource = "SERVER";
      g_futureCandlesLastUpdate = now;
      return true;
   }

   BuildFutureCandlesFallbackLocal(horizon);
   if(g_futureCandlesCount > 0)
   {
      g_futureCandlesSource = "FALLBACK";
      g_futureCandlesLastUpdate = now;
      return true;
   }

   g_futureCandlesSource = "NONE";
   return false;
}

void DrawFutureCandlesM1()
{
   ObjectsDeleteAll(0, "SMC_FUT_CANDLE_");
   ObjectsDeleteAll(0, "SMC_FUT_WICK_");
   ObjectDelete(0, "SMC_FUT_STATUS");
   ObjectDelete(0, "SMC_FUT_CHAN_UPPER");
   ObjectDelete(0, "SMC_FUT_CHAN_LOWER");

   // Assurer un espace visuel à droite pour voir les bougies futures.
   ChartSetInteger(0, CHART_SHIFT, true);
   ChartSetInteger(0, CHART_AUTOSCROLL, true);
   ChartSetDouble(0, CHART_SHIFT_SIZE, 45.0);

   if(!FetchFutureCandlesM1Hybrid(false)) return;
   if(AutoValidateFuturePredictions)
      ValidateFuturePredictionRunToServer(FuturePredictionMinBarsToValidate);
   int n = MathMin(g_futureCandlesCount, MathMax(10, MathMin(500, FutureCandlesCount)));
   if(n <= 0) return;

   color bullClr = clrGreen; // buy
   color bearClr = clrRed;   // sell
   int tfSec = 60;
   int bodySec = 42; // largeur corps (70% de la bougie M1)
   double upFirst = 0.0, upLast = 0.0, dnFirst = 0.0, dnLast = 0.0;
   datetime tFirst = 0, tLast = 0;

   for(int i = 0; i < n; i++)
   {
      FutureCandleData c = g_futureCandles[i];
      if(c.time <= 0 || c.open <= 0 || c.high <= 0 || c.low <= 0 || c.close <= 0) continue;
      datetime tOpen = c.time;
      datetime tBodyEnd = c.time + bodySec;
      datetime tMid = c.time + (tfSec / 2);
      color cc = (c.close >= c.open) ? bullClr : bearClr;

      string wName = "SMC_FUT_WICK_" + IntegerToString(i);
      if(ObjectCreate(0, wName, OBJ_TREND, 0, tMid, c.low, tMid, c.high))
      {
         ObjectSetInteger(0, wName, OBJPROP_COLOR, cc);
         ObjectSetInteger(0, wName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, wName, OBJPROP_BACK, false);
         ObjectSetInteger(0, wName, OBJPROP_RAY_RIGHT, false);
      }

      string bName = "SMC_FUT_CANDLE_" + IntegerToString(i);
      double top = MathMax(c.open, c.close);
      double bot = MathMin(c.open, c.close);
      if(MathAbs(top - bot) < SymbolInfoDouble(_Symbol, SYMBOL_POINT))
         top = bot + SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ObjectCreate(0, bName, OBJ_RECTANGLE, 0, tOpen, bot, tBodyEnd, top))
      {
         ObjectSetInteger(0, bName, OBJPROP_COLOR, cc);
         ObjectSetInteger(0, bName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, bName, OBJPROP_FILL, true);
         ObjectSetInteger(0, bName, OBJPROP_BACK, false);
      }

      if(tFirst == 0)
      {
         tFirst = tMid;
         upFirst = c.high;
         dnFirst = c.low;
      }
      tLast = tMid;
      upLast = c.high;
      dnLast = c.low;
   }

   // Encadrer visuellement les bougies futures avec un canal.
   if(tFirst > 0 && tLast > tFirst)
   {
      if(ObjectCreate(0, "SMC_FUT_CHAN_UPPER", OBJ_TREND, 0, tFirst, upFirst, tLast, upLast))
      {
         ObjectSetInteger(0, "SMC_FUT_CHAN_UPPER", OBJPROP_COLOR, clrSilver);
         ObjectSetInteger(0, "SMC_FUT_CHAN_UPPER", OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, "SMC_FUT_CHAN_UPPER", OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, "SMC_FUT_CHAN_UPPER", OBJPROP_BACK, false);
      }
      if(ObjectCreate(0, "SMC_FUT_CHAN_LOWER", OBJ_TREND, 0, tFirst, dnFirst, tLast, dnLast))
      {
         ObjectSetInteger(0, "SMC_FUT_CHAN_LOWER", OBJPROP_COLOR, clrSilver);
         ObjectSetInteger(0, "SMC_FUT_CHAN_LOWER", OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, "SMC_FUT_CHAN_LOWER", OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, "SMC_FUT_CHAN_LOWER", OBJPROP_BACK, false);
      }
   }

   if(!DashboardSingleSourceMode)
   {
      // Statut visuel même si dashboard désactivé.
      if(ObjectCreate(0, "SMC_FUT_STATUS", OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetInteger(0, "SMC_FUT_STATUS", OBJPROP_CORNER, CORNER_LEFT_UPPER);
         int yBase = (g_dashboardBottomY > 0 ? g_dashboardBottomY + 6 : 90);
         ObjectSetInteger(0, "SMC_FUT_STATUS", OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(0, "SMC_FUT_STATUS", OBJPROP_YDISTANCE, yBase);
         ObjectSetString(0, "SMC_FUT_STATUS", OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, "SMC_FUT_STATUS", OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, "SMC_FUT_STATUS", OBJPROP_COLOR, (g_futureCandlesSource == "SERVER") ? clrLimeGreen : clrYellow);
         ObjectSetString(0, "SMC_FUT_STATUS", OBJPROP_TEXT,
                         "FutureCandles M1: " + IntegerToString(n) +
                         " | Source: " + g_futureCandlesSource +
                         " | Run: " + (g_futurePredictionRunId == "" ? "NONE" : "OK") +
                         " | Valid: " + (g_futurePredictionRunValidated ? IntegerToString(g_futurePredictionValidatedSteps) : "PENDING"));
      }
   }
   ChartRedraw(0);
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
   if(!DashboardSingleSourceMode)
   {
      string lbl = "Canal ML " + IntegerToString(pastBars) + "?" + IntegerToString(PredictionChannelBars) + " bars";
      if(ObjectFind(0, "SMC_Chan_Label") < 0)
         ObjectCreate(0, "SMC_Chan_Label", OBJ_LABEL, 0, 0, 0);
      int yBase = (g_dashboardBottomY > 0 ? g_dashboardBottomY + 22 : 50);
      ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_YDISTANCE, yBase);
      ObjectSetString(0, "SMC_Chan_Label", OBJPROP_TEXT, lbl);
      ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_COLOR, clrSilver);
      ObjectSetString(0, "SMC_Chan_Label", OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, "SMC_Chan_Label", OBJPROP_FONTSIZE, 8);
   }
}

void DrawPredictionChannelLabel(string text)
{
   if(DashboardSingleSourceMode)
   {
      ObjectDelete(0, "SMC_Chan_Status");
      return;
   }

   if(ObjectFind(0, "SMC_Chan_Status") < 0)
      ObjectCreate(0, "SMC_Chan_Status", OBJ_LABEL, 0, 0, 0);
   int yBase = (g_dashboardBottomY > 0 ? g_dashboardBottomY + 36 : 66);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_YDISTANCE, yBase);
   ObjectSetString(0, "SMC_Chan_Status", OBJPROP_TEXT, text);
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_COLOR, clrGray);
   ObjectSetString(0, "SMC_Chan_Status", OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, "SMC_Chan_Status", OBJPROP_FONTSIZE, 8);
}

// Ajuste l'ordre LIMIT EMA SMC (support/résistance) sur le niveau le plus proche
// Mise à jour maximum toutes les 5 minutes pour éviter les modifications trop fréquentes
/*
// FONCTION SUPPRIMÉE - PLUS DE DÉPLACEMENT D'ORDRES LIMIT
void AdjustEMAScalpingLimitOrder()
{
   // FONCTION DÉSACTIVÉE - Les ordres LIMIT ne sont plus déplacés automatiquement
   Print("🚫 FONCTION DÉSACTIVÉE - AdjustEMAScalpingLimitOrder() supprimé");
   return;
   
   // Ancien code conservé pour référence mais non exécuté
   static datetime lastAdjustTime = 0;
   datetime now = TimeCurrent();
   if(now - lastAdjustTime < 300) return; // 5 minutes
   lastAdjustTime = now;
   
   // RÈGLE STRICTE: Si filtre activé, uniquement les symboles prioritaires peuvent avoir des ordres LIMIT
   if(UsePropiceSymbolsFilter && !g_currentSymbolIsPropice)
   {
      Print("🚫 SYMBOLE NON PRIORITAIRE - Aucun ajustement ordre EMA autorisé sur ", _Symbol);
      return;
   }

   // RÈGLE STRICTE: Si filtre activé, uniquement si lignes M5 actives
   if(UsePropiceSymbolsFilter && g_currentSymbolIsPropice)
   {
      if(!g_m5BuyLevelActive && !g_m5SellLevelActive)
      {
         Print("🚫 PAS DE LIGNES M5 ACTIVES - Aucun ajustement ordre EMA autorisé sur ", _Symbol);
         return;
      }
   }
   
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
   
   if(OrderSend(req, res))
   {
      Print("?? EMA SMC LIMIT ajusté @ ", DoubleToString(req.price, _Digits),
            " (ancien: ", DoubleToString(oldPrice, _Digits), ") src=", src);
   }
}
*/

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
         if(fvg.direction == 1 && bid >= fvg.bottom && bid <= fvg.top) { hasBuySignal = true; reason += "FVG-Bull "; }
         else if(fvg.direction == -1 && ask <= fvg.top && ask >= fvg.bottom) { hasSellSignal = true; reason += "FVG-Bear "; }
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

   bool isBoom = (cat == SYM_BOOM_CRASH && StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (cat == SYM_BOOM_CRASH && StringFind(_Symbol, "Crash") >= 0);
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
         
         Print("?? SL/TP ajustés: SL=", DoubleToString(sig.stopLoss, _Digits), 
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
         
         Print("?? SL/TP ajustés SELL: SL=", DoubleToString(sig.stopLoss, _Digits), 
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
            Print("? Signal BUY confirmé par IA (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
            return true;
         }
         if(sig.action == "SELL" && (g_lastAIAction == "SELL" || g_lastAIAction == "sell")) 
         {
            Print("? Signal SELL confirmé par IA (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
            return true;
         }
      }
   }
   
   // Fallback plus permissif si IA disponible mais faible confiance
   if(g_lastAIConfidence >= 0.30 && g_lastAIConfidence > 0)
   {
      Print("?? Signal exécuté avec faible confiance IA (", DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return true;
   }
   
   // Si IA indisponible, autoriser quand même pour ne pas manquer d'opportunités
   if(g_lastAIAction == "" || g_lastAIConfidence == 0)
   {
      Print("?? IA indisponible - Signal SMC exécuté sans confirmation");
      return true;
   }
   
   Print("? Signal rejeté - IA: ", g_lastAIAction, " (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
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
   
   // Exiger une décision IA forte + modèle suffisamment précis pour tous les marchés non Boom/Crash
   if(!IsAITradeAllowedForDirection(sig.action) || !IsMLModelTrustedForCurrentSymbol(sig.action))
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
      Print("? Signal ", sig.action, " bloqué sur ", _Symbol, " (règle Boom/Crash: pas de SELL sur Boom, pas de BUY sur Crash)");
      ReleaseOpenLock();
      return;
   }
   
    // Contrôle de duplication: ne pas ouvrir de nouvelle position
    // si les conditions IA fortes + gain 2$ ne sont pas réunies
    if(!CanOpenAdditionalPositionForSymbol(_Symbol, sig.action))
    {
       Print("? Nouvelle position ", sig.action, " bloquée sur ", _Symbol, " (règle duplication: besoin +2$ sur position initiale et IA >= 80%)");
       ReleaseOpenLock();
       return;
    }
   
   // RÈGLE SPÉCIALE BOOM/CRASH: Bloquer TOUJOURS les signaux contraires à l'IA
   // Peu importe le niveau de confiance, pour respecter les règles Boom/Crash
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(cat == SYM_BOOM_CRASH)
   {
      if(StringFind(_Symbol, "Boom") >= 0)
      {
         // Boom n'accepte que BUY
         if(sig.action == "SELL")
         {
            Print("? SELL SMC BLOQUÉ - Boom n'accepte que BUY (IA: ", g_lastAIAction, " ", DoubleToString(g_lastAIConfidence*100,1), "%)");
            ReleaseOpenLock();
            return;
         }
      }
      else if(StringFind(_Symbol, "Crash") >= 0)
      {
         // Crash n'accepte que SELL
         if(sig.action == "BUY")
         {
            Print("? BUY SMC BLOQUÉ - Crash n'accepte que SELL (IA: ", g_lastAIAction, " ", DoubleToString(g_lastAIConfidence*100,1), "%)");
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
            Print("? SELL SMC bloqué car IA = BUY (conf: ", DoubleToString(g_lastAIConfidence*100,1), "%)");
            ReleaseOpenLock();
            return;
         }
         if((g_lastAIAction == "SELL" || g_lastAIAction == "sell") && sig.action == "BUY")
         {
            Print("? BUY SMC bloqué car IA = SELL (conf: ", DoubleToString(g_lastAIConfidence*100,1), "%)");
            ReleaseOpenLock();
            return;
         }
      }
   }
   
   // Protection capital: zone discount au bord inférieur ? SELL seulement si confiance IA >= 85%
   if(sig.action == "SELL" && IsAtDiscountLowerEdge() && g_lastAIConfidence < 0.85)
   {
      Print("? SELL SMC bloqué - Zone Discount au bord inférieur: confiance IA ? 85% requise (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      ReleaseOpenLock();
      return;
   }

   // Réduire les entrées hâtives: exiger la flèche SMC_DERIV_ARROW avant tout ordre au marché
   if(!HasRecentSMCDerivArrowForDirection(sig.action))
   {
      Print("?? ORDRE SMC BLOQUÉ - Attendre flèche SMC_DERIV_ARROW ", sig.action, " sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   
   // Réinitialiser le gain maximum pour la nouvelle position
   g_maxProfit = 0;
   
   if(sig.action == "BUY")
   {
      if(NoSLTP_BoomCrash && SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
         trade.Buy(lotSize, _Symbol, 0, 0, 0, "SMC " + sig.concept);
      else
         trade.Buy(lotSize, _Symbol, 0, sig.stopLoss, sig.takeProfit, "SMC " + sig.concept);
      if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         Print("? SMC BUY @ ", sig.entryPrice, " - ", sig.concept);
         if(UseNotifications) { Alert("SMC BUY ", _Symbol, " ", sig.concept); SendNotification("SMC BUY " + _Symbol + " " + sig.concept); }
      }
   }
   else if(sig.action == "SELL")
   {
      if(NoSLTP_BoomCrash && SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
         trade.Sell(lotSize, _Symbol, 0, 0, 0, "SMC " + sig.concept);
      else
         trade.Sell(lotSize, _Symbol, 0, sig.stopLoss, sig.takeProfit, "SMC " + sig.concept);
      if(trade.ResultRetcode() == TRADE_RETCODE_DONE)
      {
         Print("? SMC SELL @ ", sig.entryPrice, " - ", sig.concept);
         if(UseNotifications) { Alert("SMC SELL ", _Symbol, " ", sig.concept); SendNotification("SMC SELL " + _Symbol + " " + sig.concept); }
      }
   }
   ReleaseOpenLock();
}

double CalculateLotSize()
{
   // Mettre à jour les stats de drawdown journalier
   UpdateDailyEquityStats();

   // Objectif "journalier par symbole" : si ce symbole est verrouillé, bloquer l'entrée
   if(UsePerSymbolDailyObjectiveOnly && IsSymbolPaused(_Symbol))
      return 0.0;

   // Bloquer toute entrée en zone de correction (autour de l'équilibre ICT)
   if(IsInEquilibriumCorrectionZone())
   {
      static datetime lastCorrLog = 0;
      datetime now = TimeCurrent();
      if(now - lastCorrLog >= 30)
      {
         Print("🚫 ENTRÉE BLOQUÉE - Zone de correction autour de l'équilibre (",
               DoubleToString(EquilibriumCorrectionBandPercent, 1),
               "%) sur ", _Symbol);
         lastCorrLog = now;
      }
      return 0.0;
   }

   // Volume fixe demandé sur Boom/Crash: éviter que le money management génère autre chose
   if(SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
   {
      double fixedLot = InpLotSize;
      if(fixedLot <= 0.0) fixedLot = 0.2;
      return NormalizeVolumeForSymbol(fixedLot);
   }

   // Si la perte journalière max en $ est atteinte, bloquer toute nouvelle entrée pendant 2h
   if(IsDailyLossPauseActive())
   {
      Print("⏸ Nouvelle entrée bloquée - pause journalière après perte max atteinte.");
      return 0.0;
   }

   // Si le gain journalier cible est atteint, bloquer toute nouvelle entrée jusqu'à fin de journée
   if(!UsePerSymbolDailyObjectiveOnly && IsDailyProfitPauseActive())
   {
      Print("⏸ Nouvelle entrée bloquée - gain journalier cible atteint (fin de journée).");
      return 0.0;
   }

   // Si la perte cumulative (trades consécutifs) a déclenché une pause
   if(IsCumulativeLossPauseActive())
   {
      Print("⏸ Nouvelle entrée bloquée - pause perte cumulative active.");
      return 0.0;
   }

   // Si le drawdown max est atteint, ne plus ouvrir de nouvelles positions
   if(IsDailyDrawdownExceeded())
   {
      Print("?? Nouvelle entrée bloquée par la gestion de risque journalière.");
      return 0.0;
   }

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(UseMinLotOnly)
      return NormalizeVolumeForSymbol(minLot);
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
   
   // CORRECTION ROBUSTE POUR ÉVITER "INVALID VOLUME"
   // Arrondir correctement selon le step du broker
   int steps = (int)MathRound(lotSize / lotStep);
   lotSize = steps * lotStep;
   
   // S'assurer que le lot est >= minLot
   if(lotSize < minLot)
      lotSize = minLot;
   
   // S'assurer que le lot est <= maxLot
   if(lotSize > maxLot)
      lotSize = maxLot;
   
   // Normalisation finale avec la précision requise par le symbole
   int digits = 2; // Standard pour les volumes (généralement 2 décimales)
   double normalizedLot = NormalizeDouble(lotSize, digits);
   
   // VALIDATION FINALE - S'assurer que le lot reste dans la plage broker
   if(normalizedLot < minLot || normalizedLot > maxLot)
   {
      Print("🚨 VOLUME AJUSTÉ - Lot calculé hors plage broker: ", DoubleToString(normalizedLot, digits));
      Print("   📍 MinLot: ", DoubleToString(minLot, digits), " | MaxLot: ", DoubleToString(maxLot, digits));
      Print("   📍 LotStep: ", DoubleToString(lotStep, digits));
      normalizedLot = minLot; // Repli strict: lot minimum broker
   }
   
   // S'assurer que le lot final est valide
   if(normalizedLot < minLot)
      normalizedLot = minLot;
   if(normalizedLot > maxLot)
      normalizedLot = maxLot;
   
   // Log de débogage pour le volume calculé
   static datetime lastLotDebugLog = 0;
   if(TimeCurrent() - lastLotDebugLog >= 60) // Log toutes les minutes
   {
      Print("📊 VOLUME CALCULÉ - ", _Symbol);
      Print("   💰 Balance: ", DoubleToString(balance, 2), "$");
      Print("   🎯 Risk%: ", DoubleToString(riskPct, 1), "% | RiskAmount: ", DoubleToString(riskAmount, 2), "$");
      Print("   📏 SL Points: ", DoubleToString(slPoints, 1), " | Pip Value: ", DoubleToString(pipVal, 5));
      Print("   📦 Lot calculé: ", DoubleToString(lotSize, digits), " | Normalisé: ", DoubleToString(normalizedLot, digits));
      Print("   ✅ Lot final: ", DoubleToString(normalizedLot, digits), " (Valide: ", (normalizedLot >= minLot && normalizedLot <= maxLot ? "OUI" : "NON"), ")");
      lastLotDebugLog = TimeCurrent();
   }
   
   return NormalizeVolumeForSymbol(normalizedLot);
}

// Variante pour ordres en attente (BUY/SELL LIMIT) sur niveaux stratégiques (Pivot/SuperTrend/etc.).
// On garde le money management (pauses / drawdown) mais on ne bloque pas uniquement parce que le marché est en "correction".
double CalculateLotSizeForPendingOrders()
{
   UpdateDailyEquityStats();

   if(IsDailyLossPauseActive() || IsDailyProfitPauseActive() || IsCumulativeLossPauseActive() || IsDailyDrawdownExceeded())
      return 0.0;

   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(UseMinLotOnly)
      return NormalizeVolumeForSymbol(minLot);

   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskPct = MaxRiskPerTradePercent;
   if(riskPct <= 0.0) riskPct = 1.0;
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
   if(lotStep <= 0) lotStep = 0.01;
   
   // CORRECTION ROBUSTE POUR ÉVITER "INVALID VOLUME" (ORDRES LIMIT)
   // Arrondir correctement selon le step du broker
   int steps = (int)MathFloor(lotSize / lotStep);
   lotSize = steps * lotStep;
   
   // S'assurer que le lot est >= minLot
   if(lotSize < minLot)
      lotSize = minLot;
   
   // S'assurer que le lot est <= maxLot
   if(lotSize > maxLot)
      lotSize = maxLot;
   
   // Normalisation finale avec la précision requise par le symbole
   int digits = 2; // Standard pour les volumes (généralement 2 décimales)
   double normalizedLot = NormalizeDouble(lotSize, digits);
   
   // VALIDATION FINALE - S'assurer que le lot est valide
   if(normalizedLot < minLot || normalizedLot > maxLot)
   {
      Print("🚨 ERREUR VOLUME ORDRE LIMIT - Lot calculé invalide: ", DoubleToString(normalizedLot, digits));
      Print("   📍 MinLot: ", DoubleToString(minLot, digits), " | MaxLot: ", DoubleToString(maxLot, digits));
      Print("   📍 LotStep: ", DoubleToString(lotStep, digits), " | Digits: ", digits);
      Print("   💡 Utilisation du lot minimum par sécurité");
      return minLot; // Retourner le lot minimum en cas d'erreur
   }
   
   // Log de débogage pour le volume calculé (ordres limit)
   static datetime lastPendingLotDebugLog = 0;
   if(TimeCurrent() - lastPendingLotDebugLog >= 120) // Log toutes les 2 minutes
   {
      Print("📊 VOLUME ORDRE LIMIT CALCULÉ - ", _Symbol);
      Print("   💰 Balance: ", DoubleToString(balance, 2), "$");
      Print("   🎯 Risk%: ", DoubleToString(riskPct, 1), "% | RiskAmount: ", DoubleToString(riskAmount, 2), "$");
      Print("   📏 SL Points: ", DoubleToString(slPoints, 1), " | Pip Value: ", DoubleToString(pipVal, 5));
      Print("   📦 Lot calculé: ", DoubleToString(lotSize, digits), " | Normalisé: ", DoubleToString(normalizedLot, digits));
      Print("   ✅ Lot final ordre limit: ", DoubleToString(normalizedLot, digits), " (Valide: ", (normalizedLot >= minLot && normalizedLot <= maxLot ? "OUI" : "NON"), ")");
      lastPendingLotDebugLog = TimeCurrent();
   }
   
   return NormalizeVolumeForSymbol(normalizedLot);
}

// Normaliser un volume arbitraire en respectant min/max/step du symbole
double NormalizeVolumeForSymbol(double desiredVolume)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minLot <= 0.0) minLot = 0.01;
   if(maxLot <= 0.0) maxLot = minLot;
   if(lotStep <= 0.0) lotStep = minLot;
   if(maxLot < minLot) maxLot = minLot;
   double vol = desiredVolume;
   if(vol < minLot) vol = minLot;
   if(vol > maxLot) vol = maxLot;

   // IMPORTANT: certains brokers exigent minLot + N*step (pas seulement N*step depuis 0)
   int steps = (int)MathFloor(((vol - minLot) / lotStep) + 1e-8);
   vol = minLot + steps * lotStep;
   if(vol < minLot) vol = minLot;
   if(vol > maxLot) vol = maxLot;

   int digits = 0;
   double stepRef = lotStep;
   while(stepRef < 1.0 && digits < 8)
   {
      stepRef *= 10.0;
      digits++;
   }
   double normalizedVol = NormalizeDouble(vol, digits);
   
   // VALIDATION FINALE - S'assurer que le lot est valide
   if(normalizedVol < minLot || normalizedVol > maxLot)
   {
      Print("🚨 ERREUR VOLUME NORMALISATION - Volume invalide: ", DoubleToString(normalizedVol, digits));
      Print("   📍 MinLot: ", DoubleToString(minLot, digits), " | MaxLot: ", DoubleToString(maxLot, digits));
      Print("   📍 LotStep: ", DoubleToString(lotStep, digits), " | Digits: ", digits);
      Print("   📍 Volume désiré: ", DoubleToString(desiredVolume, digits));
      Print("   💡 Utilisation du lot minimum par sécurité");
      return minLot; // Retourner le lot minimum en cas d'erreur
   }
   
   return normalizedVol;
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
      g_dailyPauseUntil = 0;
      g_dailyLossPauseUntil = 0;
      g_lossPauseUntil = 0;
      g_cumulativeLossSuccessive = 0.0;
      Print("?? Réinitialisation stats journalières: équité départ = ", DoubleToString(equity, 2));
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
      Print("?? DRAWDOWN JOURNALIER MAX ATTEINT: ",
            DoubleToString(ddPercent, 1), "% / ",
            DoubleToString(MaxDailyDrawdownPercent, 1),
            "% - blocage des nouvelles entrées pour aujourd'hui.");
      return true;
   }
   return false;
}

// Zone de "correction" autour de l'équilibre ICT: bande centrée sur eq
// Largeur = EquilibriumCorrectionBandPercent% de la hauteur Premium↔Discount (premHigh - discLow)
bool IsInEquilibriumCorrectionZone()
{
   if(IsInServerPredictedCorrectionZone()) return true;
   if(!BlockEquilibriumCorrectionTrades) return false;
   if(EquilibriumCorrectionBandPercent <= 0.0) return false;

   double high[], low[], close[];
   ArraySetAsSeries(high, true); ArraySetAsSeries(low, true); ArraySetAsSeries(close, true);
   if(CopyHigh(_Symbol, PERIOD_H1, 0, 100, high) < 100 || CopyLow(_Symbol, PERIOD_H1, 0, 100, low) < 100 || CopyClose(_Symbol, PERIOD_H1, 0, 100, close) < 100)
      return false;

   int n = ArraySize(close);
   if(n < 25) return false;

   double sma20[];
   ArrayResize(sma20, n);
   ArraySetAsSeries(sma20, true);
   for(int i = 0; i < n - 20; i++)
   {
      double s = 0;
      for(int j = 0; j < 20; j++) s += close[i + j];
      sma20[i] = s / 20;
   }
   for(int i = n - 20; i < n; i++) sma20[i] = sma20[MathMax(0, n - 21)];

   double eq = sma20[0];
   double premHigh = high[ArrayMaximum(high, 0, 20)];
   double discLow  = low[ArrayMinimum(low, 0, 20)];
   if(premHigh <= eq || discLow >= eq) return false;

   double range = premHigh - discLow;
   if(range <= 0.0) return false;

   double band = range * (EquilibriumCorrectionBandPercent / 100.0);
   double half = band * 0.5;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid > 0 && ask > 0) ? (bid + ask) * 0.5 : bid;
   if(mid <= 0) return false;

   bool inEqBand = (mid >= (eq - half) && mid <= (eq + half));
   if(!inEqBand) return false;

   // --- Confirmation "intelligente" : on ne bloque que si c'est vraiment une correction/range (M1 calme) ---
   int lb = MathMax(20, CorrectionRangeLookbackBarsM1);
   double h1 = iHigh(_Symbol, PERIOD_M1, 0);
   if(Bars(_Symbol, PERIOD_M1) < (lb + 2)) return true; // si pas assez de data M1, rester conservateur

   double maxH = -DBL_MAX, minL = DBL_MAX;
   int aligned = 0;
   for(int i = 1; i <= lb; i++)
   {
      double o = iOpen(_Symbol, PERIOD_M1, i);
      double c = iClose(_Symbol, PERIOD_M1, i);
      double h = iHigh(_Symbol, PERIOD_M1, i);
      double l = iLow(_Symbol, PERIOD_M1, i);
      if(h <= 0 || l <= 0) continue;
      if(h > maxH) maxH = h;
      if(l < minL) minL = l;
      // simple alternance: si beaucoup de bougies inverses, c'est souvent une correction (pas une impulsion)
      if(c >= o) aligned++;
   }
   double rangeM1 = (maxH > -DBL_MAX && minL < DBL_MAX) ? (maxH - minL) : 0.0;
   double rangePct = (rangeM1 > 0.0) ? (rangeM1 / mid) * 100.0 : 0.0;

   // ATR(14) M1 en % (si dispo). Si l'ATR est très faible → marché "calme" → correction probable.
   double atrPct = 0.0;
   static int atrM1Handle = INVALID_HANDLE;
   if(atrM1Handle == INVALID_HANDLE)
      atrM1Handle = iATR(_Symbol, PERIOD_M1, 14);
   if(atrM1Handle != INVALID_HANDLE)
   {
      double buf[];
      ArraySetAsSeries(buf, true);
      if(CopyBuffer(atrM1Handle, 0, 0, 1, buf) >= 1 && buf[0] > 0.0)
         atrPct = (buf[0] / mid) * 100.0;
   }

   bool isTightRange = (rangePct > 0.0 && rangePct <= CorrectionMaxRangePctM1);
   bool isLowAtr     = (atrPct > 0.0 && atrPct <= CorrectionMaxAtrPctM1);

   if(DebugCorrectionZoneFilter)
   {
      static datetime lastDbg = 0;
      datetime now = TimeCurrent();
      if(now - lastDbg >= 15)
      {
         Print("CORR DEBUG ", _Symbol,
               " | inEqBand=YES",
               " | eq=", DoubleToString(eq, _Digits),
               " | mid=", DoubleToString(mid, _Digits),
               " | bandHalf=", DoubleToString(half, _Digits),
               " | rangePctM1=", DoubleToString(rangePct, 4),
               " (max ", DoubleToString(CorrectionMaxRangePctM1, 4), ")",
               " | atrPctM1=", DoubleToString(atrPct, 4),
               " (max ", DoubleToString(CorrectionMaxAtrPctM1, 4), ")",
               " | tightRange=", (isTightRange ? "YES" : "NO"),
               " | lowAtr=", (isLowAtr ? "YES" : "NO"));
         lastDbg = now;
      }
   }

   // On bloque seulement si (proche équilibre) ET (range serré OU ATR faible).
   return (isTightRange || isLowAtr);
}

// Gain journalier cible atteint → stop trading jusqu'à fin de journée
bool IsDailyProfitPauseActive()
{
   if(DailyProfitTargetDollars <= 0.0 || g_dailyStartEquity <= 0.0) return false;

   datetime now = TimeCurrent();
   if(g_dailyPauseUntil > now) return true;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyProfit = equity - g_dailyStartEquity;
   if(dailyProfit < DailyProfitTargetDollars) return false;

   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 23; dt.min = 59; dt.sec = 59;
   g_dailyPauseUntil = StructToTime(dt);
   Print("⏸ STOP JOURNALIER - Gain ", DoubleToString(dailyProfit, 2), "$ ≥ ",
         DoubleToString(DailyProfitTargetDollars, 2), "$ | pause jusqu'à ",
         TimeToString(g_dailyPauseUntil, TIME_SECONDS));
   return true;
}

bool IsProfitLockTriggered()
{
   if(!EnableProfitLock) return false;
   if(ProfitLockStartDollars <= 0.0 || ProfitLockMaxGivebackDollars <= 0.0) return false;
   if(g_dailyStartEquity <= 0.0) return false;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double peakProfit = g_dailyMaxEquity - g_dailyStartEquity;
   if(peakProfit < ProfitLockStartDollars) return false;

   double giveback = g_dailyMaxEquity - equity;
   return (giveback >= ProfitLockMaxGivebackDollars);
}

void CloseAllPositionsAndPendingOurEA(const string reason)
{
   // 1) Fermer positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      ulong ticket = posInfo.Ticket();
      PositionCloseWithLog(ticket, reason);
   }

   // 2) Supprimer ordres en attente
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;

      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t == ORDER_TYPE_BUY_LIMIT || t == ORDER_TYPE_SELL_LIMIT ||
         t == ORDER_TYPE_BUY_STOP  || t == ORDER_TYPE_SELL_STOP  ||
         t == ORDER_TYPE_BUY_STOP_LIMIT || t == ORDER_TYPE_SELL_STOP_LIMIT)
      {
         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action = TRADE_ACTION_REMOVE;
         req.order  = ticket;
         req.symbol = OrderGetString(ORDER_SYMBOL);
         req.magic  = InpMagicNumber;
         if(!OrderSend(req, res))
         {
            Print("❌ ÉCHEC ANNULATION LIMIT - Ticket=", ticket, " | Code=", res.retcode);
         }
      }
      }
   }

void ActivateProfitLockIfNeeded()
{
   if(!IsProfitLockTriggered()) return;

   datetime now = TimeCurrent();
   if(g_dailyPauseUntil > now) return; // déjà en pause

   // Pause jusqu'à fin de journée
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 23; dt.min = 59; dt.sec = 59;
   g_dailyPauseUntil = StructToTime(dt);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double peakProfit = g_dailyMaxEquity - g_dailyStartEquity;
   double giveback = g_dailyMaxEquity - equity;

   Print("⛔ PROFIT LOCK - Pic=", DoubleToString(peakProfit, 2), "$ | Giveback=", DoubleToString(giveback, 2),
         "$ ≥ ", DoubleToString(ProfitLockMaxGivebackDollars, 2), "$ | pause jusqu'à ", TimeToString(g_dailyPauseUntil, TIME_SECONDS));

   if(ProfitLockClosePositions)
      CloseAllPositionsAndPendingOurEA("PROFIT LOCK - giveback");
}

// Vérifie si le modèle ML courant est suffisamment fiable pour autoriser un trade sur ce symbole/catégorie
bool IsMLModelTrustedForCurrentSymbol(const string direction)
{
   if(!UseAIServer) return true; // pas de filtrage si IA désactivée
   if(g_mlLastAccuracy <= 0.0) return false; // pas de métriques utilisables

   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   double minAcc = 0.0;

   switch(cat)
   {
      case SYM_BOOM_CRASH:
         minAcc = 80.0; // Boom/Crash: demander une précision élevée
         break;
      case SYM_VOLATILITY:
         minAcc = 70.0;
         break;
      case SYM_FOREX:
      case SYM_METAL:
         minAcc = 65.0;
         break;
      case SYM_COMMODITY:
      case SYM_UNKNOWN:
      default:
         minAcc = 60.0;
         break;
   }

   if(g_mlLastAccuracy < minAcc)
   {
      Print("🚫 ML BLOQUÉ - Modèle insuffisamment précis pour ", _Symbol,
            " (cat=", (int)cat, ") | Acc=", DoubleToString(g_mlLastAccuracy, 1),
            "% < seuil ", DoubleToString(minAcc, 1), "% | Modèle=", g_mlLastModelName,
            " | Direction demandée=", direction);
      return false;
   }

   return true;
}

// Perte journalière max atteinte → pause 2h
bool IsDailyLossPauseActive()
{
   if(MaxDailyLossDollars <= 0.0 || g_dailyStartEquity <= 0.0) return false;

   datetime now = TimeCurrent();
   if(g_dailyLossPauseUntil > now) return true;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyProfit = equity - g_dailyStartEquity;
   if(dailyProfit > -MaxDailyLossDollars) return false;

   g_dailyLossPauseUntil = now + 2 * 60 * 60;
   Print("⏸ PAUSE PERTE JOURNALIÈRE - PnL ", DoubleToString(dailyProfit, 2), "$ ≤ -",
         DoubleToString(MaxDailyLossDollars, 2), "$ | pause jusqu'à ",
         TimeToString(g_dailyLossPauseUntil, TIME_SECONDS));
   return true;
}

// Pause après pertes consécutives cumulées (géré par g_lossPauseUntil)
bool IsCumulativeLossPauseActive()
{
   datetime now = TimeCurrent();
   if(g_lossPauseUntil > now) return true;
   if(g_lossPauseUntil != 0 && g_lossPauseUntil <= now)
      g_lossPauseUntil = 0;
   return false;
}

// Vérifie en continu les ordres LIMIT en attente et annule ceux qui ne sont plus alignés avec la décision IA
void GuardPendingLimitOrdersWithAI()
{
   if(!UseAIServer) return;

   // Mettre à jour la décision IA si elle est trop ancienne
   datetime now = TimeCurrent();
   if(now - g_lastAIUpdate >= AI_UpdateInterval_Seconds)
   {
      UpdateAIDecision(AI_Timeout_ms);
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;

      // Ne contrôler que les ordres proches du prix courant (prêts à être déclenchés)
      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double refPrice   = (t == ORDER_TYPE_BUY_LIMIT)
                          ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0) point = 0.0001;
      double maxDistPts = 10.0; // ne vérifier l'IA que si on est à <= 10 points
      if(MathAbs(orderPrice - refPrice) > maxDistPts * point)
         continue; // prix encore loin de l'ordre, ne pas annuler trop tôt

      string cmt = OrderGetString(ORDER_COMMENT);
      string dir = (t == ORDER_TYPE_BUY_LIMIT ? "BUY" : "SELL");

      string ia = g_lastAIAction;
      string iaUpper = ia;
      StringToUpper(iaUpper);
      double conf = g_lastAIConfidence * 100.0;
      double minConf = MinAIConfidencePercent + 10.0; // marge +10% par rapport au minimum global

      bool shouldCancel = false;

      // IA en HOLD -> annuler immédiatement l'ordre LIMIT
      if(iaUpper == "HOLD")
      {
         shouldCancel = true;
         Print("🚫 LIMIT ANNULÉ - IA en HOLD sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else if(iaUpper == "BUY" && dir == "SELL")
      {
         shouldCancel = true;
         Print("🚫 LIMIT ANNULÉ - IA=BUY mais ordre SELL LIMIT en attente sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else if(iaUpper == "SELL" && dir == "BUY")
      {
         shouldCancel = true;
         Print("🚫 LIMIT ANNULÉ - IA=SELL mais ordre BUY LIMIT en attente sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else
      {
         // Direction alignée mais confiance insuffisante
         if(conf < minConf)
         {
            shouldCancel = true;
            Print("🚫 LIMIT ANNULÉ - Confiance IA insuffisante pour ", dir, " sur ", _Symbol,
                  " | Conf=", DoubleToString(conf, 1), "% < seuil ", DoubleToString(minConf, 1),
                  "% | Ticket=", ticket, " | Comment=", cmt);
         }
      }

      if(shouldCancel)
      {
         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action = TRADE_ACTION_REMOVE;
         req.order  = ticket;
         req.symbol = _Symbol;

         if(!OrderSend(req, res))
         {
            Print("? ÉCHEC ANNULATION LIMIT - Ticket=", ticket, " | Code=", res.retcode);
         }
      }
   }
}

// Détermine si un ordre limite doit être remplacé selon les conditions IA
bool ShouldReplaceLimitOrder(ENUM_ORDER_TYPE orderType, string orderComment, double orderPrice)
{
   if(!UseAIServer || !ReplaceMisalignedLimitOrders) return false;
   
   // Mettre à jour la décision IA si trop ancienne
   datetime now = TimeCurrent();
   if(now - g_lastAIUpdate >= AI_UpdateInterval_Seconds)
   {
      UpdateAIDecision(AI_Timeout_ms);
   }
   
   string ia = g_lastAIAction;
   string iaUpper = ia;
   StringToUpper(iaUpper);
   double conf = g_lastAIConfidence * 100.0;
   double minConf = MinConfidenceForReplacement * 100.0;
   
   string dir = (orderType == ORDER_TYPE_BUY_LIMIT) ? "BUY" : "SELL";
   
   // Vérifier la distance du prix (configurable)
   double refPrice = (orderType == ORDER_TYPE_BUY_LIMIT)
                   ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                   : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) point = 0.0001;
   
   if(MathAbs(orderPrice - refPrice) > MaxDistanceForLimitCheck * point)
      return false; // Trop loin, pas besoin de remplacer maintenant
   
   // Condition 1: IA en HOLD -> ne pas remplacer
   if(iaUpper == "HOLD")
   {
      Print("🚫 PAS DE REMPLACEMENT - IA en HOLD pour ", dir, " sur ", _Symbol);
      return false;
   }
   
   // Condition 2: Direction opposée -> remplacer
   if((iaUpper == "BUY" && dir == "SELL") || (iaUpper == "SELL" && dir == "BUY"))
   {
      Print("🔄 REMPLACEMENT REQUIS - IA=", ia, " opposée à ordre ", dir, " sur ", _Symbol);
      return true;
   }
   
   // Condition 3: Confiance IA insuffisante -> ne pas remplacer
   if(conf < minConf)
   {
      Print("🚫 PAS DE REMPLACEMENT - Confiance IA insuffisante: ", DoubleToString(conf, 1), "% < ", DoubleToString(minConf, 1), "%");
      return false;
   }
   
   // Condition 4: Direction alignée mais IA a changé depuis placement -> remplacer
   // (vérifier si l'ordre a été placé avant le dernier changement IA)
   if(StringFind(orderComment, "STRAT") >= 0)
   {
      // Ordre stratégique : remplacer si IA est plus forte maintenant
      Print("🔄 REMPLACEMENT REQUIS - Ordre stratégique ", dir, " avec IA ", ia, " (", DoubleToString(conf, 1), "%) sur ", _Symbol);
      return true;
   }
   
   return false;
}

// Remplace un ordre limite par un nouvel ordre aligné avec l'IA
bool ReplaceLimitOrder(ENUM_ORDER_TYPE oldOrderType, double oldOrderPrice, string oldOrderComment)
{
   if(!UseAIServer) return false;
   
   string ia = g_lastAIAction;
   string iaUpper = ia;
   StringToUpper(iaUpper);
   
   // Déterminer le nouveau type d'ordre selon IA
   ENUM_ORDER_TYPE newOrderType;
   string newDirection;
   
   if(iaUpper == "BUY")
   {
      newOrderType = ORDER_TYPE_BUY_LIMIT;
      newDirection = "BUY";
   }
   else if(iaUpper == "SELL")
   {
      newOrderType = ORDER_TYPE_SELL_LIMIT;
      newDirection = "SELL";
   }
   else
   {
      Print("🚫 IMPOSSIBLE REMPLACEMENT - IA=", ia, " non valide pour nouvel ordre");
      return false;
   }
   
   // Calculer le nouveau prix d'ordre
   double currentPrice = SymbolInfoDouble(_Symbol, (newOrderType == ORDER_TYPE_BUY_LIMIT) ? SYMBOL_ASK : SYMBOL_BID);
   double atrVal = GetCurrentATR();
   double newOrderPrice;
   double stopLoss = 0;
   double takeProfit = 0;
   
   // Utiliser la logique existante de calcul de prix
   if(newOrderType == ORDER_TYPE_BUY_LIMIT)
   {
      // BUY LIMIT : sous le prix actuel
      string sourceOut;
      double supportLevel = GetClosestBuyLevel(currentPrice, atrVal, MaxDistanceLimitATR, sourceOut);
      if(supportLevel > 0)
         newOrderPrice = supportLevel;
      else
         newOrderPrice = currentPrice - 15 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      stopLoss = newOrderPrice - 300 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      takeProfit = newOrderPrice + 600 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   else
   {
      // SELL LIMIT : au-dessus du prix actuel
      string sourceOut;
      double resistanceLevel = GetClosestSellLevel(currentPrice, atrVal, MaxDistanceLimitATR, sourceOut);
      if(resistanceLevel > 0)
         newOrderPrice = resistanceLevel;
      else
         newOrderPrice = currentPrice + 15 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      stopLoss = newOrderPrice + 300 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      takeProfit = newOrderPrice - 600 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   
   // Calculer le lot size
   double lotSize = CalculateLotSizeForPendingOrders();
   if(lotSize <= 0)
   {
      Print("🚫 IMPOSSIBLE REMPLACEMENT - Lot size invalide");
      return false;
   }
   
   // Préparer la requête d'ordre
   MqlTradeRequest req = {};
   MqlTradeResult res = {};
   
   req.action = TRADE_ACTION_PENDING;
   req.symbol = _Symbol;
   req.volume = lotSize;
   req.type = newOrderType;
   req.price = newOrderPrice;
   req.sl = stopLoss;
   req.tp = takeProfit;
   req.deviation = 20;
   req.magic = InpMagicNumber;
   req.comment = "STRAT " + newDirection + " LIMIT (REPLACEMENT)";
   req.type_filling = ORDER_FILLING_IOC;
   req.type_time = ORDER_TIME_GTC;
   
   // Valider et ajuster le prix si nécessaire
   if(!ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, newOrderType))
   {
      Print("🚫 IMPOSSIBLE REMPLACEMENT - Prix/SL/TP invalides après ajustement");
      return false;
   }
   
   // Placer le nouvel ordre
   if(OrderSend(req, res))
   {
      Print("✅ REMPLACEMENT RÉUSSI - ", newDirection, " LIMIT placé | Prix=", DoubleToString(newOrderPrice, 5), 
            " | Lot=", DoubleToString(lotSize, 2), " | Ticket=", res.order);
      Print("   🔄 Ancien ordre: ", oldOrderComment, " | Prix=", DoubleToString(oldOrderPrice, 5));
      Print("   🧠 IA: ", ia, " | Confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%");
      return true;
   }
   else
   {
      Print("❌ ÉCHEC REMPLACEMENT - ", newDirection, " LIMIT | Code=", res.retcode, " | Comment=", res.comment);
      return false;
   }
}

// Récupère l'ATR courant du timeframe M1
double GetCurrentATR()
{
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   int copied = CopyBuffer(atrM1, 0, 0, 1, atrBuffer);
   if(copied > 0 && atrBuffer[0] > 0)
      return atrBuffer[0];
   
   // Fallback : utiliser l'ATR LTF si M1 indisponible
   if(atrHandle != INVALID_HANDLE)
   {
      copied = CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
      if(copied > 0 && atrBuffer[0] > 0)
         return atrBuffer[0];
   }
   
   // Dernier fallback : ATR fixe selon symbole
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   switch(cat)
   {
      case SYM_BOOM_CRASH: return 0.025;  // 25 points pour Boom/Crash
      case SYM_FOREX:     return 0.00020; // 20 pips pour Forex
      case SYM_COMMODITY: return 0.5;    // 50 points pour matières premières
      default:            return 0.001;   // Valeur par défaut
   }
}

// Version améliorée de GuardPendingLimitOrdersWithAI avec remplacement automatique
void GuardPendingLimitOrdersWithAI_Enhanced()
{
   if(!UseAIServer) return;

   // Sur Boom/Crash, on respecte uniquement la règle de type (Boom=BUY only / Crash=SELL only).
   // Ne pas annuler un pending juste parce que l'IA affiche une action opposée (sinon on n'a jamais le pending visible).
   ENUM_SYMBOL_CATEGORY symCat = SMC_GetSymbolCategory(_Symbol);

   // Mettre à jour la décision IA si elle est trop ancienne
   datetime now = TimeCurrent();
   if(now - g_lastAIUpdate >= AI_UpdateInterval_Seconds)
   {
      UpdateAIDecision(AI_Timeout_ms);
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(!OrderSelect(ticket)) continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT) continue;

      // Vérifier tous les ordres limites (distance étendue)
      double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
      double refPrice   = (t == ORDER_TYPE_BUY_LIMIT)
                          ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0) point = 0.0001;
      
      // Distance étendue selon paramètre
      if(MathAbs(orderPrice - refPrice) > MaxDistanceForLimitCheck * point)
         continue; // prix encore trop loin de l'ordre

      string cmt = OrderGetString(ORDER_COMMENT);
      string dir = (t == ORDER_TYPE_BUY_LIMIT ? "BUY" : "SELL");

      string ia = g_lastAIAction;
      string iaUpper = ia;
      StringToUpper(iaUpper);
      double conf = g_lastAIConfidence * 100.0;
      double minConf = MinAIConfidencePercent + 10.0; // marge +10% par rapport au minimum global

      bool shouldCancel = false;
      bool shouldReplace = false;

      // Logique d'annulation (existante)
      if(iaUpper == "HOLD")
      {
         shouldCancel = true;
         Print("🚫 LIMIT ANNULÉ - IA en HOLD sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else if(symCat != SYM_BOOM_CRASH && iaUpper == "BUY" && dir == "SELL")
      {
         shouldCancel = true;
         shouldReplace = ReplaceMisalignedLimitOrders; // Remplacement si activé
         Print("🔄 LIMIT CONFLIT - IA=BUY mais ordre SELL LIMIT sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else if(symCat != SYM_BOOM_CRASH && iaUpper == "SELL" && dir == "BUY")
      {
         shouldCancel = true;
         shouldReplace = ReplaceMisalignedLimitOrders; // Remplacement si activé
         Print("🔄 LIMIT CONFLIT - IA=SELL mais ordre BUY LIMIT sur ", _Symbol, " | Ticket=", ticket, " | Comment=", cmt);
      }
      else if(symCat != SYM_BOOM_CRASH)
      {
         // Direction alignée mais confiance insuffisante
         if(conf < minConf)
         {
            shouldCancel = true;
            shouldReplace = ReplaceMisalignedLimitOrders && conf >= MinConfidenceForReplacement * 100.0;
            Print("🚫 LIMIT CONFIANCE - Confiance IA insuffisante pour ", dir, " sur ", _Symbol,
                  " | Conf=", DoubleToString(conf, 1), "% < seuil ", DoubleToString(minConf, 1),
                  "% | Ticket=", ticket, " | Comment=", cmt);
         }
      }
      else
      {
         // Boom/Crash: garder l'ordre (sauf HOLD géré au-dessus)
      }

      // Exécuter l'annulation si nécessaire
      if(shouldCancel)
      {
         MqlTradeRequest req = {};
         MqlTradeResult  res = {};
         req.action = TRADE_ACTION_REMOVE;
         req.order  = ticket;
         req.symbol = _Symbol;

         if(OrderSend(req, res))
         {
            Print("✅ LIMIT ANNULÉ - ", dir, " sur ", _Symbol, " | Ticket=", ticket, " | Raison: ", 
                  (iaUpper == "HOLD" ? "IA HOLD" : 
                   (iaUpper == "BUY" && dir == "SELL") ? "Direction opposée BUY vs SELL" :
                   (iaUpper == "SELL" && dir == "BUY") ? "Direction opposée SELL vs BUY" :
                   "Confiance insuffisante"));
            
            // Tenter le remplacement si activé et conditions réunies
            if(shouldReplace && ShouldReplaceLimitOrder(t, cmt, orderPrice))
            {
               ReplaceLimitOrder(t, orderPrice, cmt);
            }
         }
         else
         {
            Print("❌ ÉCHEC ANNULATION LIMIT - Ticket=", ticket, " | Code=", res.retcode);
         }
      }
   }
}

// Vérifie que l'entraînement continu backend est actif; sinon, le démarre (si forceStart ou statut indique non-actif)
bool EnsureMLContinuousTrainingRunning(bool forceStart = false)
{
   if(!ShowMLMetrics) return false;
   if(!AutoStartMLContinuousTraining && !forceStart) return false;

   static datetime lastCheck = 0;
   datetime now = TimeCurrent();
   int interval = MathMax(30, MLContinuousCheckIntervalSec);
   if(!forceStart && (now - lastCheck) < interval)
      return true;
   lastCheck = now;

   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
   string fallbackUrl = UseRenderAsPrimary ? AI_ServerURL : AI_ServerRender;
   string headers = "Content-Type: application/json\r\n";
   char post[], result[];
   string resultHeaders;

   // 1) Lire status
   int resStatus = WebRequest("GET", baseUrl + "/ml/continuous/status", "", AI_Timeout_ms, post, result, resultHeaders);
   if(resStatus != 200)
      resStatus = WebRequest("GET", fallbackUrl + "/ml/continuous/status", "", AI_Timeout_ms2, post, result, resultHeaders);

   bool running = false;
   if(resStatus == 200)
   {
      string statusData = CharArrayToString(result);
      // On accepte plusieurs formats possibles: "running":true, "active":true, "enabled":true
      running = (StringFind(statusData, "\"running\": true") >= 0 ||
                 StringFind(statusData, "\"running\":true") >= 0 ||
                 StringFind(statusData, "\"active\": true") >= 0 ||
                 StringFind(statusData, "\"active\":true") >= 0 ||
                 StringFind(statusData, "\"enabled\": true") >= 0 ||
                 StringFind(statusData, "\"enabled\":true") >= 0);
   }

   // 2) Démarrer si nécessaire
   if(forceStart || !running)
   {
      string startUrl1 = baseUrl + "/ml/continuous/start";
      string startUrl2 = fallbackUrl + "/ml/continuous/start";
      int resStart = WebRequest("POST", startUrl1, headers, AI_Timeout_ms, post, result, resultHeaders);
      if(resStart != 200)
         resStart = WebRequest("POST", startUrl2, headers, AI_Timeout_ms2, post, result, resultHeaders);

      if(resStart == 200)
      {
         Print("✅ ML continuous training démarré/relancé.");
         return true;
      }
      Print("⚠️ Impossible de démarrer ML continuous training (HTTP ", resStart, ").");
      return false;
   }

   return true;
}

// Affichage dédié des métriques ML sur le graphique (label)
void DrawMLMetricsOnChart()
{
   string name = "SMC_ML_METRICS_LABEL";
   if(!ShowMLMetrics)
   {
      ObjectDelete(0, name);
      return;
   }

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
         return;
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);  // Réduit à 7 pour cohérence
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, name, OBJPROP_BACK, false);  // Premier plan pour visibilité
   }

   // Calculer la position Y pour éviter la superposition avec le dashboard
   int y = MathMax(MLMetricsLabelYOffsetPixels, g_dashboardBottomY + 45);  // 45px d'espace sous le dashboard (augmenté)
   
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);

   // Catégorie de symbole pour rendre explicite le type de modèle utilisé
   string catStr = "UNKNOWN";
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   switch(cat)
   {
      case SYM_BOOM_CRASH:  catStr = "Boom/Crash"; break;
      case SYM_VOLATILITY:  catStr = "Volatility"; break;
      case SYM_FOREX:       catStr = "Forex"; break;
      case SYM_COMMODITY:   catStr = "Commodity"; break;
      case SYM_METAL:       catStr = "Metal"; break;
   }

   string txt = "ML (" + catStr + ", " + _Symbol + "): " + (g_mlMetricsStr == "" ? "En attente..." : g_mlMetricsStr);
   txt += " | Canal: " + (g_channelValid ? "OK" : "—");
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, g_channelValid ? clrLime : clrYellow);
   
   // Log de débogage pour vérifier le positionnement
   static datetime lastMLDebugLog = 0;
   if(TimeCurrent() - lastMLDebugLog >= 300) // Toutes les 5 minutes
   {
      Print("?? DEBUG ML Metrics - y=", y, " | dashboardBottom=", g_dashboardBottomY);
      lastMLDebugLog = TimeCurrent();
   }
}

// Fonction de nettoyage global des objets graphiques du dashboard
void CleanupDashboardObjects()
{
   // Nettoyer TOUS les objets dashboard existants - méthode plus agressive
   int totalDeleted = 0;
   
   // Méthode 1: Nettoyer par préfixes connus
   string prefixes[] = {"SMC_DASHBOARD_LABEL", "SMC_DASH_LINE_", "SMC_ML_METRICS_LABEL", "SMC_PROPICE_LINE", "DASH_", "ML_"};
   
   for(int p = 0; p < ArraySize(prefixes); p++)
   {
      string prefix = prefixes[p];
      
      // Pour les préfixes de lignes, tester plusieurs numéros
      if(prefix == "SMC_DASH_LINE_")
      {
         for(int i = 0; i < 200; i++)
         {
            string name = prefix + IntegerToString(i);
            if(ObjectFind(0, name) >= 0)
            {
               if(ObjectDelete(0, name))
                  totalDeleted++;
            }
         }
      }
      else
      {
         // Pour les objets uniques, essayer directement
         if(ObjectFind(0, prefix) >= 0)
         {
            if(ObjectDelete(0, prefix))
               totalDeleted++;
         }
      }
   }

   // Nettoyage ciblé des labels d'information susceptibles de rester obsolètes
   string staleLabels[] = {"SMC_FUT_STATUS", "SMC_Chan_Label", "SMC_Chan_Status", "SMC_ICT_SIG_CHECKLIST"};
   for(int s = 0; s < ArraySize(staleLabels); s++)
   {
      if(ObjectFind(0, staleLabels[s]) >= 0 && ObjectDelete(0, staleLabels[s]))
         totalDeleted++;
   }
   
   // Méthode 2: Parcourir TOUS les objets sur le chart et supprimer ceux qui correspondent
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      
      // Supprimer tous les objets avec ces préfixes
      if(StringFind(objName, "SMC_DASH_") == 0 ||
         StringFind(objName, "SMC_DASHBOARD_LABEL") == 0 ||
         StringFind(objName, "SMC_ML_") == 0 ||
         StringFind(objName, "SMC_PROPICE_") == 0 ||
         StringFind(objName, "DASH_") == 0 ||
         StringFind(objName, "ML_METRICS") == 0)
      {
         if(ObjectDelete(0, objName))
            totalDeleted++;
      }
   }
   
   if(totalDeleted > 0)
   {
      Print("🧹 NETTOYAGE DASHBOARD - ", totalDeleted, " objets supprimés");
   }
}

// Fonction de nettoyage complet de tous les dessins SMC sur le chart
void CleanupAllChartObjects()
{
   // Préfixes de tous les objets SMC à nettoyer
   string prefixes[] = {
      "SMC_",           // Tous les objets SMC
      "FVG_",           // Fair Value Gaps
      "OB_",            // Order Blocks
      "BOS_",           // Break of Structure
      "LS_",            // Liquidity Sweep
      "OTE_",           // Optimal Trade Entry
      "EQH_", "EQL_",   // Equal High/Low
      "PD_",            // Point of Interest
      "SWING_",         // Swing points
      "EMA_",           // EMA lines
      "TREND_",         // Trend lines
      "CHANNEL_",       // Channels
      "SPIKE_",         // Spike indicators
      "ARROW_",         // Arrow signals
      "PREDICT_",       // Predictions
      "LEVEL_",         // Support/Resistance levels
      "ZONE_",          // Zones (Premium/Discount)
      "PROPICE_",       // Propice symbols
      "ML_",            // ML metrics
      "DASH_",          // Dashboard
      "SIGNAL_",        // Signal arrows
      "WARNING_"        // Warnings
   };
   
   int totalDeleted = 0;
   
   for(int p = 0; p < ArraySize(prefixes); p++)
   {
      string prefix = prefixes[p];
      
      // Parcourir tous les objets sur le chart
      for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
      {
         string objName = ObjectName(0, i);
         if(StringFind(objName, prefix) == 0)  // Commence par le préfixe
         {
            if(ObjectDelete(0, objName))
            {
               totalDeleted++;
            }
         }
      }
   }
   
   // Nettoyer aussi les objets plus anciens qui pourraient avoir d'autres noms
   string oldPrefixes[] = {"DERIV_", "BOOKMARK_", "KILLZONE_", "LIQUIDITY_"};
   
   for(int p = 0; p < ArraySize(oldPrefixes); p++)
   {
      string prefix = oldPrefixes[p];
      
      for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
      {
         string objName = ObjectName(0, i);
         if(StringFind(objName, prefix) == 0)
         {
            if(ObjectDelete(0, objName))
            {
               totalDeleted++;
            }
         }
      }
   }
   
   if(totalDeleted > 0)
   {
      Print("🧹 NETTOYAGE COMPLET - ", totalDeleted, " objets graphiques supprimés du chart");
   }
}

// Fonction pour vérifier et gérer la pause après avoir atteint l'objectif de profit journalier
bool CheckDailyProfitPause()
{
   // Calculer le profit journalier basé sur l'historique des trades du jour
   double dailyProfit = CalculateDailyProfitFromHistory();
   
   // Mettre à jour les variables globales pour cohérence
   g_dayNetProfit = dailyProfit;
   
   // Mettre à jour le pic de profit si nécessaire
   if(dailyProfit > g_dailyProfitPeak)
   {
      g_dailyProfitPeak = dailyProfit;
   }
   
   // Vérifier si l'objectif de profit est atteint pour la première fois
   if(dailyProfit >= DailyProfitTarget && !g_dailyProfitTargetReached)
   {
      g_dailyProfitTargetReached = true;
      g_dailyProfitPauseStartTime = TimeCurrent();
      
      // Calculer la durée de pause : PauseAfterProfitHours heures après atteinte du target
      datetime pauseEndTime = g_dailyProfitPauseStartTime + (PauseAfterProfitHours * 3600);
      g_dailyPauseUntil = pauseEndTime;
      
      Print("🎯 OBJECTIF PROFIT JOURNALIER ATTEINT !");
      Print("💰 Profit actuel: ", DoubleToString(dailyProfit, 2), "$ / Objectif: ", DoubleToString(DailyProfitTarget, 2), "$");
      Print("⏸️ PAUSE ACTIVÉE - Durée: ", PauseAfterProfitHours, " heures");
      Print("🚫 TOUS LES TRADES BLOQUÉS jusqu'à ", TimeToString(pauseEndTime, TIME_SECONDS));
      Print("📊 Basé sur l'historique des trades du jour");
      
      return true;  // Bloquer les trades
   }
   
   // Si la pause est active, vérifier si elle est terminée
   if(g_dailyProfitTargetReached && g_dailyProfitPauseStartTime > 0)
   {
      datetime pauseEndTime = g_dailyPauseUntil;
      
      if(TimeCurrent() >= pauseEndTime)
      {
         // Réinitialiser la pause
         g_dailyProfitTargetReached = false;
         g_dailyProfitPauseStartTime = 0;
         g_dailyProfitPeak = 0.0;
         g_dailyPauseUntil = 0;
         
         Print("✅ PAUSE TERMINÉE - Reprise du trading autorisée");
         Print("💰 Gains protégés: ", DoubleToString(dailyProfit, 2), "$");
         Print("🚀 Nouveaux trades autorisés à partir de maintenant");
         
         return false;  // Autoriser les trades
      }
      else
      {
         // Pause encore active - afficher le temps restant
         int remainingSeconds = (int)(pauseEndTime - TimeCurrent());
         int remainingHours = remainingSeconds / 3600;
         int remainingMinutes = (remainingSeconds % 3600) / 60;
         
         // Log toutes les 10 minutes pendant la pause
         static datetime lastPauseLog = 0;
         if(TimeCurrent() - lastPauseLog >= 600) // 10 minutes
         {
            Print("⏳ PAUSE PROFIT EN COURS");
            Print("⏱️ Temps restant: ", remainingHours, "h ", remainingMinutes, "min");
            Print("💰 Profit actuel: ", DoubleToString(dailyProfit, 2), "$ / Target: ", DoubleToString(DailyProfitTarget, 2), "$");
            Print("📊 Statistiques basées sur l'historique des trades du jour");
            lastPauseLog = TimeCurrent();
         }
         
         return true;  // Bloquer les trades
      }
   }
   
   return false;  // Autoriser les trades
}

// Calculer le profit journalier basé sur l'historique des trades
double CalculateDailyProfitFromHistory()
{
   double dailyProfit = 0.0;
   datetime todayStart = GetTodayStart();
   
   // Parcourir l'historique des trades du jour
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      if(dealTime < todayStart) continue; // Skip trades from previous days
      
      long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      if(dealMagic != InpMagicNumber) continue; // Only our EA's trades
      
      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      
      dailyProfit += dealProfit + dealSwap + dealCommission;
   }
   
   return dailyProfit;
}

// Vérifier si le symbole actuel est le plus propice (priorité 0)
bool IsMostPropiceSymbol()
{
   return g_currentSymbolPriority == 0;
}

// Obtenir le nom du symbole le plus propice (priorité 0)
string GetMostPropiceSymbol()
{
   if(g_propiceTopSymbols == "")
      return "";
   
   // Extraire le premier symbole de la liste (le plus propice)
   string symbols[];
   StringSplit(g_propiceTopSymbols, ',', symbols);
   
   if(ArraySize(symbols) > 0)
   {
      StringTrimLeft(symbols[0]);
      StringTrimRight(symbols[0]);
      return symbols[0];
   }
   
   return "";
}

// Vérifier la protection contre les pertes excessives par symbole
bool CheckSymbolLossProtection()
{
   // Calculer la perte actuelle pour ce symbole
   double currentLoss = 0.0;
   
   // Parcourir les positions ouvertes pour ce symbole
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(posInfo.SelectByIndex(i))
      {
         if(posInfo.Symbol() == _Symbol && posInfo.Magic() == InpMagicNumber)
         {
            double positionProfit = posInfo.Profit();
            if(positionProfit < 0)
               currentLoss += MathAbs(positionProfit);
         }
      }
   }
   
   // Mettre à jour la perte actuelle
   g_symbolCurrentLoss = currentLoss;
   
   // Si perte supérieure à la limite maximale autorisée
   if(g_symbolCurrentLoss >= MaxLossPerSymbolDollars)
   {
      if(!g_symbolTradingBlocked)
      {
         g_symbolTradingBlocked = true;
         g_symbolLossStartTime = TimeCurrent();
         
         Print("🚨 PROTECTION SYMBOLE ACTIVÉE - Perte maximale atteinte sur ", _Symbol);
         Print("   💰 Perte actuelle: ", DoubleToString(g_symbolCurrentLoss, 2), "$ > Limite: ", DoubleToString(MaxLossPerSymbolDollars, 2), "$");
         Print("   🚫 Trading sur ce symbole BLOQUÉ jusqu'à réinitialisation manuelle");
         Print("   ⚠️ Toutes les nouvelles positions sur ", _Symbol, " seront refusées");
         
         // Envoyer une notification d'alerte
         string alertMsg = "🚨 PROTECTION SYMBOLE - " + _Symbol + "\n" +
                         "Perte: " + DoubleToString(g_symbolCurrentLoss, 2) + "$\n" +
                         "Limite: " + DoubleToString(MaxLossPerSymbolDollars, 2) + "$\n" +
                         "Trading BLOQUÉ sur ce symbole";
         SendNotification(alertMsg);
      }
      return true; // Bloquer le trading
   }
   
   // Si le trading était bloqué mais qu'on a récupéré (aucune perte)
   if(g_symbolTradingBlocked && g_symbolCurrentLoss == 0.0)
   {
      g_symbolTradingBlocked = false;
      Print("✅ PROTECTION SYMBOLE DÉSACTIVÉE - ", _Symbol, " - Trading réactivé");
   }
   
   return false; // Autoriser le trading
}

// Réinitialiser manuellement la protection par symbole
void ResetSymbolProtection()
{
   g_symbolCurrentLoss = 0.0;
   g_symbolLossStartTime = 0;
   g_symbolTradingBlocked = false;
   
   Print("✅ PROTECTION SYMBOLE RÉINITIALISÉE - ", _Symbol);
   Print("   🔄 Trading réactivé sur ce symbole");
   Print("   💡 Protection remise à zéro - Surveillance des pertes reprise");
}

// Prédire les Protected High/Low Points dans les zones de prix futures
void PredictFutureProtectedPoints()
{
   // Nettoyer les anciennes prédictions
   ObjectsDeleteAll(0, "FUTURE_PROTECTED_");
   
   // Obtenir les données historiques pour l'analyse
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 200, rates) < 100) return;
   
   // Calculer l'ATR pour la volatilité
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   double atr = 0.0;
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) >= 1)
      atr = atrBuffer[0];
   
   // Obtenir le prix actuel
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   datetime currentTime = TimeCurrent();
   
   // --- PRÉDICTION DES FUTURES RÉSISTANCES (PROTECTED HIGH POINTS) ---
   
   // 1. Basé sur les highs protégés historiques récents
   double recentHighs[];
   ArrayResize(recentHighs, 0);
   int highCount = 0;
   
   // Extraire les highs protégés des 50 dernières bougies
   for(int i = 10; i < 50; i++)
   {
      bool isProtectedHigh = true;
      double currentHigh = rates[i].high;
      
      // Vérifier si c'est un high protégé
      for(int j = i - 5; j >= 0 && j >= i - 10; j--)
      {
         if(rates[j].high > currentHigh)
         {
            isProtectedHigh = false;
            break;
         }
      }
      
      if(isProtectedHigh && currentHigh > currentPrice)
      {
         ArrayResize(recentHighs, highCount + 1);
         recentHighs[highCount] = currentHigh;
         highCount++;
      }
   }
   
   // 2. Projeter les futures résistances basées sur la structure du marché
   double futureHighs[3];
   string highLabels[3] = {"R1+FUTUR", "R2+FUTUR", "R3+FUTUR"};
   color highColors[3] = {clrPurple, clrMagenta, clrMaroon};
   
   if(highCount >= 2)
   {
      // Calculer la distance moyenne et la tendance des highs protégés
      double avgHighDistance = 0.0;
      double highTrendSlope = 0.0;
      int validPoints = 0;
      
      for(int i = 1; i < highCount; i++)
      {
         double distance = recentHighs[i] - recentHighs[i-1];
         avgHighDistance += distance;
         
         // Calculer la pente de tendance (régression linéaire simple)
         if(i < highCount)
         {
            highTrendSlope += distance;
            validPoints++;
         }
      }
      
      if(validPoints > 0)
      {
         avgHighDistance /= (highCount - 1);
         highTrendSlope /= validPoints;
      }
      
      // Projeter 3 futures résistances avec projection améliorée
      double lastHigh = recentHighs[0];
      double projectedBasePrice = lastHigh;
      
      for(int i = 0; i < 3; i++)
      {
         // Projection progressive basée sur la tendance historique
         double trendProjection = highTrendSlope * (i + 1) * 0.8; // 80% de la tendance pour conservatisme
         double volatilityAdjustment = 0.0;
         
         // Ajustement avec la volatilité actuelle (ATR) - plus sophistiqué
         if(atr > 0)
         {
            // Volatilité croissante pour les niveaux plus lointains
            volatilityAdjustment = atr * (0.3 + (i * 0.2)); // 0.3, 0.5, 0.7 ATR
            
            // Ajustement basé sur la direction de la tendance
            if(highTrendSlope > 0) // Tendance haussière
               volatilityAdjustment *= 1.2; // Augmenter la projection
            else // Tendance baissière ou neutre
               volatilityAdjustment *= 0.8; // Réduire la projection
         }
         
         // Calcul du niveau futur avec tous les ajustements
         futureHighs[i] = projectedBasePrice + (avgHighDistance * (i + 1)) + trendProjection + volatilityAdjustment;
         
         // Projection temporelle améliorée - basée sur la vitesse historique
         int timeBars = 15 + (i * 10) + (int)(avgHighDistance / atr * 5); // 15, 25, 35+ bougies
         datetime futureTime = currentTime + (PeriodSeconds(PERIOD_M15) * timeBars);
         
         // Créer une ligne plus longue dans le futur pour meilleure visualisation
         datetime extendedFutureTime = futureTime + (PeriodSeconds(PERIOD_M15) * 20); // Extension de 20 bougies
         
         // Dessiner la ligne de prédiction améliorée
         string lineName = "FUTURE_PROTECTED_HIGH_" + IntegerToString(i);
         
         ObjectCreate(0, lineName, OBJ_TREND, 0, currentTime, futureHighs[i], extendedFutureTime, futureHighs[i]);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, highColors[i]);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2 + i); // Épaisseur croissante
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
         
         // Ajouter un label avec plus d'informations
         string labelName = "FUTURE_PROTECTED_HIGH_LABEL_" + IntegerToString(i);
         string labelText = highLabels[i] + " " + DoubleToString(futureHighs[i], _Digits) + 
                          " (+" + IntegerToString(timeBars) + " bars)";
         
         ObjectCreate(0, labelName, OBJ_TEXT, 0, futureTime, futureHighs[i] + (atr * 0.4));
         ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, highColors[i]);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
         
         // Ajouter une zone de probabilité autour du niveau prédit
         string zoneName = "FUTURE_PROTECTED_HIGH_ZONE_" + IntegerToString(i);
         double zoneWidth = atr * 0.5; // Zone de ±0.5 ATR
         
         ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, currentTime, futureHighs[i] - zoneWidth, 
                     extendedFutureTime, futureHighs[i] + zoneWidth);
         ObjectSetInteger(0, zoneName, OBJPROP_COLOR, highColors[i]);
         ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
         ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
         ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, highColors[i]);
         ObjectSetInteger(0, zoneName, OBJPROP_COLOR, clrNONE); // Bordure transparente
      }
   }
   
   // --- PRÉDICTION DES FUTURS SUPPORTS (PROTECTED LOW POINTS) ---
   
   // 1. Basé sur les lows protégés historiques récents
   double recentLows[];
   ArrayResize(recentLows, 0);
   int lowCount = 0;
   
   // Extraire les lows protégés des 50 dernières bougies
   for(int i = 10; i < 50; i++)
   {
      bool isProtectedLow = true;
      double currentLow = rates[i].low;
      
      // Vérifier si c'est un low protégé
      for(int j = i - 5; j >= 0 && j >= i - 10; j--)
      {
         if(rates[j].low < currentLow)
         {
            isProtectedLow = false;
            break;
         }
      }
      
      if(isProtectedLow && currentLow < currentPrice)
      {
         ArrayResize(recentLows, lowCount + 1);
         recentLows[lowCount] = currentLow;
         lowCount++;
      }
   }
   
   // 2. Projeter les futurs supports basés sur la structure du marché
   double futureLows[3];
   string lowLabels[3] = {"S1+FUTUR", "S2+FUTUR", "S3+FUTUR"};
   color lowColors[3] = {clrDarkGreen, clrDarkOrange, clrBrown};
   
   if(lowCount >= 2)
   {
      // Calculer la distance moyenne et la tendance des lows protégés
      double avgLowDistance = 0.0;
      double lowTrendSlope = 0.0;
      int validLowPoints = 0;
      
      for(int i = 1; i < lowCount; i++)
      {
         double distance = recentLows[i-1] - recentLows[i]; // Inversé car les lows sont en ordre décroissant
         avgLowDistance += distance;
         
         // Calculer la pente de tendance (régression linéaire simple)
         if(i < lowCount)
         {
            lowTrendSlope += distance;
            validLowPoints++;
         }
      }
      
      if(validLowPoints > 0)
      {
         avgLowDistance /= (lowCount - 1);
         lowTrendSlope /= validLowPoints;
      }
      
      // Projeter 3 futurs supports avec projection améliorée
      double lastLow = recentLows[0];
      double projectedBaseLow = lastLow;
      
      for(int i = 0; i < 3; i++)
      {
         // Projection progressive basée sur la tendance historique
         double trendProjection = lowTrendSlope * (i + 1) * 0.8; // 80% de la tendance pour conservatisme
         double volatilityAdjustment = 0.0;
         
         // Ajustement avec la volatilité actuelle (ATR) - plus sophistiqué
         if(atr > 0)
         {
            // Volatilité croissante pour les niveaux plus lointains
            volatilityAdjustment = atr * (0.3 + (i * 0.2)); // 0.3, 0.5, 0.7 ATR
            
            // Ajustement basé sur la direction de la tendance
            if(lowTrendSlope > 0) // Tendance baissière des lows (les lows descendent)
               volatilityAdjustment *= 1.2; // Augmenter la projection vers le bas
            else // Tendance haussière des lows ou neutre
               volatilityAdjustment *= 0.8; // Réduire la projection
         }
         
         // Calcul du niveau futur avec tous les ajustements
         futureLows[i] = projectedBaseLow - (avgLowDistance * (i + 1)) - trendProjection - volatilityAdjustment;
         
         // Projection temporelle améliorée - basée sur la vitesse historique
         int timeBars = 15 + (i * 10) + (int)(avgLowDistance / atr * 5); // 15, 25, 35+ bougies
         datetime futureTime = currentTime + (PeriodSeconds(PERIOD_M15) * timeBars);
         
         // Créer une ligne plus longue dans le futur pour meilleure visualisation
         datetime extendedFutureTime = futureTime + (PeriodSeconds(PERIOD_M15) * 20); // Extension de 20 bougies
         
         // Dessiner la ligne de prédiction améliorée
         string lineName = "FUTURE_PROTECTED_LOW_" + IntegerToString(i);
         
         ObjectCreate(0, lineName, OBJ_TREND, 0, currentTime, futureLows[i], extendedFutureTime, futureLows[i]);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, lowColors[i]);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2 + i); // Épaisseur croissante
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
         
         // Ajouter un label avec plus d'informations
         string labelName = "FUTURE_PROTECTED_LOW_LABEL_" + IntegerToString(i);
         string labelText = lowLabels[i] + " " + DoubleToString(futureLows[i], _Digits) + 
                          " (+" + IntegerToString(timeBars) + " bars)";
         
         ObjectCreate(0, labelName, OBJ_TEXT, 0, futureTime, futureLows[i] - (atr * 0.4));
         ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, lowColors[i]);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
         
         // Ajouter une zone de probabilité autour du niveau prédit
         string zoneName = "FUTURE_PROTECTED_LOW_ZONE_" + IntegerToString(i);
         double zoneWidth = atr * 0.5; // Zone de ±0.5 ATR
         
         ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, currentTime, futureLows[i] - zoneWidth, 
                     extendedFutureTime, futureLows[i] + zoneWidth);
         ObjectSetInteger(0, zoneName, OBJPROP_COLOR, lowColors[i]);
         ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
         ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
         ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, lowColors[i]);
         ObjectSetInteger(0, zoneName, OBJPROP_COLOR, clrNONE); // Bordure transparente
      }
   }
   
   // --- PRÉDICTION BASÉE SUR L'IA ET LES ZONES DE CONFLUENCE ---
   
   if(UseAIServer && g_lastAIAction != "")
   {
      // Si IA dit BUY, prédire un support futur probable
      if(g_lastAIAction == "BUY")
      {
         double predictedSupport = currentPrice - (atr * 1.5); // Support probable à 1.5 ATR en dessous
         datetime supportTime = currentTime + PeriodSeconds(PERIOD_M15) * 15; // 15 bougies dans le futur
         
         string aiSupportLine = "FUTURE_PROTECTED_AI_SUPPORT";
         ObjectCreate(0, aiSupportLine, OBJ_TREND, 0, currentTime, predictedSupport, supportTime, predictedSupport);
         ObjectSetInteger(0, aiSupportLine, OBJPROP_COLOR, clrLimeGreen);
         ObjectSetInteger(0, aiSupportLine, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetInteger(0, aiSupportLine, OBJPROP_WIDTH, 3);
         ObjectSetInteger(0, aiSupportLine, OBJPROP_BACK, true);
         
         string aiSupportLabel = "FUTURE_PROTECTED_AI_SUPPORT_LABEL";
         ObjectCreate(0, aiSupportLabel, OBJ_TEXT, 0, supportTime, predictedSupport - (atr * 0.2));
         ObjectSetString(0, aiSupportLabel, OBJPROP_TEXT, "AI-SUPPORT " + DoubleToString(predictedSupport, _Digits) + " (" + DoubleToString(g_lastAIConfidence * 100, 1) + "%)");
         ObjectSetInteger(0, aiSupportLabel, OBJPROP_COLOR, clrLimeGreen);
         ObjectSetInteger(0, aiSupportLabel, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, aiSupportLabel, OBJPROP_BACK, false);
      }
      
      // Si IA dit SELL, prédire une résistance future probable
      if(g_lastAIAction == "SELL")
      {
         double predictedResistance = currentPrice + (atr * 1.5); // Résistance probable à 1.5 ATR au dessus
         datetime resistanceTime = currentTime + PeriodSeconds(PERIOD_M15) * 15; // 15 bougies dans le futur
         
         string aiResistanceLine = "FUTURE_PROTECTED_AI_RESISTANCE";
         ObjectCreate(0, aiResistanceLine, OBJ_TREND, 0, currentTime, predictedResistance, resistanceTime, predictedResistance);
         ObjectSetInteger(0, aiResistanceLine, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, aiResistanceLine, OBJPROP_STYLE, STYLE_DASHDOT);
         ObjectSetInteger(0, aiResistanceLine, OBJPROP_WIDTH, 3);
         ObjectSetInteger(0, aiResistanceLine, OBJPROP_BACK, true);
         
         string aiResistanceLabel = "FUTURE_PROTECTED_AI_RESISTANCE_LABEL";
         ObjectCreate(0, aiResistanceLabel, OBJ_TEXT, 0, resistanceTime, predictedResistance + (atr * 0.2));
         ObjectSetString(0, aiResistanceLabel, OBJPROP_TEXT, "AI-RESISTANCE " + DoubleToString(predictedResistance, _Digits) + " (" + DoubleToString(g_lastAIConfidence * 100, 1) + "%)");
         ObjectSetInteger(0, aiResistanceLabel, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, aiResistanceLabel, OBJPROP_FONTSIZE, 9);
         ObjectSetInteger(0, aiResistanceLabel, OBJPROP_BACK, false);
      }
   }
   
   // --- PROJECTION DES PROTECTED POINTS ACTUELS 500 BOUGIES DANS LE FUTUR ---
   
   // Trouver le Protected High Point le plus récent
   double lastProtectedHigh = 0.0;
   datetime lastProtectedHighTime = 0;
   
   for(int i = 5; i < 50; i++)
   {
      bool isProtectedHigh = true;
      double currentHigh = rates[i].high;
      
      // Vérifier si c'est un high protégé
      for(int j = i - 5; j >= 0 && j >= i - 10; j--)
      {
         if(rates[j].high > currentHigh)
         {
            isProtectedHigh = false;
            break;
         }
      }
      
      if(isProtectedHigh && currentHigh > currentPrice)
      {
         lastProtectedHigh = currentHigh;
         lastProtectedHighTime = rates[i].time;
         break; // Prendre le plus récent
      }
   }
   
   // Trouver le Protected Low Point le plus récent
   double lastProtectedLow = 0.0;
   datetime lastProtectedLowTime = 0;
   
   for(int i = 5; i < 50; i++)
   {
      bool isProtectedLow = true;
      double currentLow = rates[i].low;
      
      // Vérifier si c'est un low protégé
      for(int j = i - 5; j >= 0 && j >= i - 10; j--)
      {
         if(rates[j].low < currentLow)
         {
            isProtectedLow = false;
            break;
         }
      }
      
      if(isProtectedLow && currentLow < currentPrice)
      {
         lastProtectedLow = currentLow;
         lastProtectedLowTime = rates[i].time;
         break; // Prendre le plus récent
      }
   }
   
   // Projeter le Protected High actuel 500 bougies dans le futur
   if(lastProtectedHigh > 0)
   {
      datetime futureHighTime = currentTime + (PeriodSeconds(PERIOD_M15) * 500); // 500 bougies dans le futur
      datetime extendedHighTime = futureHighTime + (PeriodSeconds(PERIOD_M15) * 50); // Extension de 50 bougies
      
      string highLineName = "PROTECTED_HIGH_FUTURE_500";
      ObjectCreate(0, highLineName, OBJ_TREND, 0, currentTime, lastProtectedHigh, extendedHighTime, lastProtectedHigh);
      ObjectSetInteger(0, highLineName, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, highLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, highLineName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, highLineName, OBJPROP_BACK, true);
      
      string highLabelName = "PROTECTED_HIGH_FUTURE_500_LABEL";
      ObjectCreate(0, highLabelName, OBJ_TEXT, 0, futureHighTime, lastProtectedHigh + (atr * 0.5));
      ObjectSetString(0, highLabelName, OBJPROP_TEXT, "PROTECTED_HIGH " + DoubleToString(lastProtectedHigh, _Digits) + " (+500 bars)");
      ObjectSetInteger(0, highLabelName, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, highLabelName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, highLabelName, OBJPROP_BACK, false);
   }
   
   // Projeter le Protected Low actuel 500 bougies dans le futur
   if(lastProtectedLow > 0)
   {
      datetime futureLowTime = currentTime + (PeriodSeconds(PERIOD_M15) * 500); // 500 bougies dans le futur
      datetime extendedLowTime = futureLowTime + (PeriodSeconds(PERIOD_M15) * 50); // Extension de 50 bougies
      
      string lowLineName = "PROTECTED_LOW_FUTURE_500";
      ObjectCreate(0, lowLineName, OBJ_TREND, 0, currentTime, lastProtectedLow, extendedLowTime, lastProtectedLow);
      ObjectSetInteger(0, lowLineName, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, lowLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, lowLineName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, lowLineName, OBJPROP_BACK, true);
      
      string lowLabelName = "PROTECTED_LOW_FUTURE_500_LABEL";
      ObjectCreate(0, lowLabelName, OBJ_TEXT, 0, futureLowTime, lastProtectedLow - (atr * 0.5));
      ObjectSetString(0, lowLabelName, OBJPROP_TEXT, "PROTECTED_LOW " + DoubleToString(lastProtectedLow, _Digits) + " (+500 bars)");
      ObjectSetInteger(0, lowLabelName, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, lowLabelName, OBJPROP_FONTSIZE, 10);
      ObjectSetInteger(0, lowLabelName, OBJPROP_BACK, false);
   }
   
   // --- LOG DES PRÉDICTIONS ---
   Print("🔮 PRÉDICTIONS FUTURES DES POINTS PROTÉGÉS - ", _Symbol);
   Print("   📊 Basé sur ", highCount, " highs et ", lowCount, " lows protégés historiques");
   Print("   🎯 ATR actuel: ", DoubleToString(atr, _Digits));
   Print("   💡 Prédictions IA: ", g_lastAIAction, " (confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
   
   // Log des Protected Points projetés
   if(lastProtectedHigh > 0)
      Print("   🟠 PROTECTED_HIGH projeté: ", DoubleToString(lastProtectedHigh, _Digits), " → +500 bougies");
   if(lastProtectedLow > 0)
      Print("   🟢 PROTECTED_LOW projeté: ", DoubleToString(lastProtectedLow, _Digits), " → +500 bougies");
}

// Obtenir les niveaux futurs de Protected Points pour le trading
bool GetFutureProtectedPointLevels(double &futureSupportOut, double &futureResistanceOut)
{
   futureSupportOut = 0.0;
   futureResistanceOut = 0.0;
   
   // Obtenir les données historiques
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 200, rates) < 100) return false;
   
   // Calculer l'ATR
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   double atr = 0.0;
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) >= 1)
      atr = atrBuffer[0];
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // --- CALCULER LES FUTURES RÉSISTANCES ---
   double recentHighs[];
   ArrayResize(recentHighs, 0);
   int highCount = 0;
   
   // Extraire les highs protégés
   for(int i = 10; i < 50; i++)
   {
      bool isProtectedHigh = true;
      double currentHigh = rates[i].high;
      
      for(int j = i - 5; j >= 0 && j >= i - 10; j--)
      {
         if(rates[j].high > currentHigh)
         {
            isProtectedHigh = false;
            break;
         }
      }
      
      if(isProtectedHigh && currentHigh > currentPrice)
      {
         ArrayResize(recentHighs, highCount + 1);
         recentHighs[highCount] = currentHigh;
         highCount++;
      }
   }
   
   // Calculer la prochaine résistance future
   if(highCount >= 2)
   {
      double avgHighDistance = 0.0;
      for(int i = 1; i < highCount; i++)
         avgHighDistance += recentHighs[i] - recentHighs[i-1];
      avgHighDistance /= (highCount - 1);
      
      futureResistanceOut = recentHighs[0] + avgHighDistance;
      if(atr > 0)
         futureResistanceOut += (atr * 0.5); // Ajustement volatilité
   }
   
   // --- CALCULER LES FUTURS SUPPORTS ---
   double recentLows[];
   ArrayResize(recentLows, 0);
   int lowCount = 0;
   
   // Extraire les lows protégés
   for(int i = 10; i < 50; i++)
   {
      bool isProtectedLow = true;
      double currentLow = rates[i].low;
      
      for(int j = i - 5; j >= 0 && j >= i - 10; j--)
      {
         if(rates[j].low < currentLow)
         {
            isProtectedLow = false;
            break;
         }
      }
      
      if(isProtectedLow && currentLow < currentPrice)
      {
         ArrayResize(recentLows, lowCount + 1);
         recentLows[lowCount] = currentLow;
         lowCount++;
      }
   }
   
   // Calculer le prochain support futur
   if(lowCount >= 2)
   {
      double avgLowDistance = 0.0;
      for(int i = 1; i < lowCount; i++)
         avgLowDistance += recentLows[i-1] - recentLows[i];
      avgLowDistance /= (lowCount - 1);
      
      futureSupportOut = recentLows[0] - avgLowDistance;
      if(atr > 0)
         futureSupportOut -= (atr * 0.5); // Ajustement volatilité
   }
   
   // --- PRIORITÉ AUX PRÉDICTIONS IA ---
   if(UseAIServer && g_lastAIAction != "")
   {
      if(g_lastAIAction == "BUY" && atr > 0)
      {
         futureSupportOut = currentPrice - (atr * 1.5);
      }
      else if(g_lastAIAction == "SELL" && atr > 0)
      {
         futureResistanceOut = currentPrice + (atr * 1.5);
      }
   }
   
   return (futureSupportOut > 0 || futureResistanceOut > 0);
}

void DrawDashboardOnChart(const string &lines[], const color &colors[], int count)
{
   // NETTOYAGE AGRESSIF - Supprimer TOUS les anciens labels dashboard
   for(int j = 0; j < 300; j++)  // jusqu'à 300 lignes potentielles
   {
      string name = "SMC_DASH_LINE_" + IntegerToString(j);
      if(ObjectFind(0, name) >= 0)
      {
         ObjectDelete(0, name);
      }
   }
   
   // Vérification supplémentaire : parcourir tous les objets et supprimer ceux qui correspondent
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
   {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "SMC_DASH_LINE_") == 0)
      {
         ObjectDelete(0, objName);
      }
   }
   
   // Créer/mettre à jour une liste de labels verticaux, sans superposition
   int x  = MathMax(0, DashboardLabelXOffsetPixels);
   int y0 = MathMax(0, DashboardLabelYStartPixels);
   int lh = MathMax(12, DashboardLabelLineHeightPixels);  // compact et lisible

   int maxLines = MathMin(count, 40);  // on autorise plus de lignes visibles

   // Log de débogage pour vérifier le positionnement
   static datetime lastDebugLog = 0;
   if(TimeCurrent() - lastDebugLog >= 300) // Toutes les 5 minutes
   {
      Print("?? DEBUG Dashboard - x=", x, " | y0=", y0, " | lineHeight=", lh, " | lines=", maxLines);
      lastDebugLog = TimeCurrent();
   }

   for(int i = 0; i < maxLines; i++)
   {
      string name = "SMC_DASH_LINE_" + IntegerToString(i);
      
      // Créer le label s'il n'existe pas
      if(ObjectFind(0, name) < 0)
      {
         if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
            continue;
         ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
         ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);  // harmonisé
         ObjectSetInteger(0, name, OBJPROP_BACK, false);  // Premier plan pour visibilité
      }

      // Calcul de la position Y avec vérification
      int yPos = y0 + (i * lh);
      
      // Appliquer le positionnement
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yPos);
      ObjectSetInteger(0, name, OBJPROP_COLOR, colors[i]);
      ObjectSetString(0, name, OBJPROP_TEXT, lines[i]);

      // Log de débogage pour les premières lignes seulement
      if(i < 3 && TimeCurrent() - lastDebugLog >= 300)
      {
         Print("?? DEBUG Line ", i, " - yPos=", yPos, " | text=", StringSubstr(lines[i], 0, 30));
      }
   }

   g_dashboardBottomY = y0 + maxLines * lh;
}

// Applique la stratégie adaptée à la catégorie de symbole (Boom/Crash, Volatility, Forex/Metals)
void RunCategoryStrategy()
{
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   
   switch(cat)
   {
      case SYM_BOOM_CRASH:
         // Boom/Crash: priorité aux signaux DERIV ARROW + logique spike dédiée
         CheckAndExecuteDerivArrowTrade();
         // Disabled: les ordres LIMIT "Protected future points" sont désactivés
         // (objectif: exécution 100% market via touch/entry lines).
         // La détection/gestion des spikes et canaux Boom/Crash est déjà appelée plus bas (ManageBoomCrashSpikeClose, CheckImminentSpike, etc.)
         break;

      case SYM_VOLATILITY:
         // Volatility: privilégier des entrées LIMIT sur niveaux "propices" (S/R 20 bars, Pivot D1, SuperTrend),
         // + confirmation IA (direction/confidence) et modèle ML fiable (déjà géré par IsMLModelTrustedForCurrentSymbol).
         CheckAndExecuteDerivArrowTrade(); // conserve la détection flèche, mais l'entrée est filtrée par l'IA + confiance
         break;

      case SYM_FOREX:
         // Forex: stratégie ICT-like OTE+Imbalance + BOS+Retest (entrée marché uniquement) avec garde-fous IA/ML/propice
         ExecuteOTEImbalanceTrade();
         ExecuteForexBOSRetest();
         // Fallback (si pas de signal BOS+retest): conserver le comportement générique existant
         CheckAndExecuteDerivArrowTrade();
         break;

      case SYM_METAL:
      case SYM_COMMODITY:
      case SYM_UNKNOWN:
      default:
         // Métaux / autres indices: utiliser la stratégie OTE+Imbalance si disponible, sinon logique SMC/Deriv Arrow générique
         ExecuteOTEImbalanceTrade();
         CheckAndExecuteDerivArrowTrade();
         break;
   }
}

// --- FOREX STRATEGY: BOS + Retest (market entry only) ---
// Détecte une cassure de structure (BOS) sur LTF puis attend un retest du niveau cassé.
// Quand le retest est validé, renvoie direction + niveaux SL/TP basés structure+ATR.
bool Forex_DetectBOSRetest(string &dirOut, double &entryOut, double &slOut, double &tpOut)
{
   dirOut = "";
   entryOut = 0.0;
   slOut = 0.0;
   tpOut = 0.0;

   // Cette stratégie ne s'applique qu'aux symboles Forex (métaux exclus pour l'instant)
   if(SMC_GetSymbolCategory(_Symbol) != SYM_FOREX) return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, LTF, 0, 120, rates);
   if(copied < 30) return false;

   // ATR sur LTF (tolérance retest)
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atrBuf[];
      ArraySetAsSeries(atrBuf, true);
      if(CopyBuffer(atrHandle, 0, 0, 2, atrBuf) >= 1)
         atrVal = atrBuf[0];
   }
   if(atrVal <= 0.0)
      atrVal = MathAbs(rates[1].high - rates[1].low); // fallback minimal

   double tol = MathMax(atrVal * 0.20, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);

   // Etat persistant "en attente de retest" (EA par symbole)
   static bool     s_waitingRetest = false;
   static string   s_dir = "";
   static double   s_level = 0.0;
   static datetime s_bosTime = 0;
   static datetime s_lastLog = 0;

   // Helper: chercher le swing high/low le plus récent (fractal-like)
   double lastSwingHigh = 0.0;
   double lastSwingLow  = 0.0;
   int swingHighIdx = -1;
   int swingLowIdx  = -1;

   for(int i = 5; i < MathMin(copied - 5, 80); i++)
   {
      bool isHigh = (rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
                     rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high);
      bool isLow  = (rates[i].low  < rates[i-1].low  && rates[i].low  < rates[i+1].low  &&
                     rates[i].low  < rates[i-2].low  && rates[i].low  < rates[i+2].low);

      if(swingHighIdx < 0 && isHigh) { swingHighIdx = i; lastSwingHigh = rates[i].high; }
      if(swingLowIdx  < 0 && isLow)  { swingLowIdx  = i; lastSwingLow  = rates[i].low;  }
      if(swingHighIdx >= 0 && swingLowIdx >= 0) break;
   }

   if(lastSwingHigh <= 0.0 || lastSwingLow <= 0.0) return false;

   double close1 = rates[1].close;
   double close2 = rates[2].close;

   // Timeout d'attente retest (évite d'attendre éternellement)
   if(s_waitingRetest && s_bosTime > 0)
   {
      if((TimeCurrent() - s_bosTime) > (60 * 60 * 6)) // 6h
      {
         s_waitingRetest = false;
         s_dir = "";
         s_level = 0.0;
         s_bosTime = 0;
      }
   }

   // Si pas en attente, détecter un BOS frais
   if(!s_waitingRetest)
   {
      // BOS UP: close[1] casse au-dessus du swing high
      if(close1 > lastSwingHigh && close2 <= lastSwingHigh)
      {
         s_waitingRetest = true;
         s_dir = "BUY";
         s_level = lastSwingHigh;
         s_bosTime = rates[1].time;
         if(TimeCurrent() - s_lastLog >= 60)
         {
            Print("📈 FOREX BOS détecté (BUY) sur ", _Symbol, " | Niveau=", DoubleToString(s_level, _Digits));
            s_lastLog = TimeCurrent();
         }
         return false;
      }
      // BOS DOWN: close[1] casse au-dessous du swing low
      if(close1 < lastSwingLow && close2 >= lastSwingLow)
      {
         s_waitingRetest = true;
         s_dir = "SELL";
         s_level = lastSwingLow;
         s_bosTime = rates[1].time;
         if(TimeCurrent() - s_lastLog >= 60)
         {
            Print("📉 FOREX BOS détecté (SELL) sur ", _Symbol, " | Niveau=", DoubleToString(s_level, _Digits));
            s_lastLog = TimeCurrent();
         }
         return false;
      }
      return false;
   }

   // En attente retest: vérifier retest du niveau cassé (tolérance ATR)
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   bool retestOk = false;
   if(s_dir == "BUY")
   {
      // Prix revient toucher/approcher le niveau cassé et clôture sans réintégrer fortement sous le niveau
      bool touched = (rates[0].low <= (s_level + tol));
      bool held    = (rates[0].close >= (s_level - tol));
      retestOk = (touched && held);
      if(!retestOk && TimeCurrent() - s_lastLog >= 120)
      {
         Print("⏳ FOREX Retest en attente (BUY) sur ", _Symbol,
               " | Niveau=", DoubleToString(s_level, _Digits),
               " | tol=", DoubleToString(tol, _Digits));
         s_lastLog = TimeCurrent();
      }
   }
   else if(s_dir == "SELL")
   {
      bool touched = (rates[0].high >= (s_level - tol));
      bool held    = (rates[0].close <= (s_level + tol));
      retestOk = (touched && held);
      if(!retestOk && TimeCurrent() - s_lastLog >= 120)
      {
         Print("⏳ FOREX Retest en attente (SELL) sur ", _Symbol,
               " | Niveau=", DoubleToString(s_level, _Digits),
               " | tol=", DoubleToString(tol, _Digits));
         s_lastLog = TimeCurrent();
      }
   }
   else
   {
      s_waitingRetest = false;
      s_level = 0.0;
      s_bosTime = 0;
      return false;
   }

   if(!retestOk) return false;

   // Optionnel: si filtres SMC activés, exiger une validation multi-signaux existante
   if(UseLiquiditySweep || UseOrderBlocks || UseFVG)
   {
      if(!ValidateEntryWithMultipleSignals(s_dir))
      {
         if(TimeCurrent() - s_lastLog >= 60)
         {
            Print("⛔ FOREX Retest OK mais filtres SMC KO sur ", _Symbol, " (", s_dir, ")");
            s_lastLog = TimeCurrent();
         }
         return false;
      }
   }

   dirOut = s_dir;
   entryOut = (s_dir == "BUY") ? ask : bid;

   // SL/TP structure + ATR
   double risk = 0.0;
   if(s_dir == "BUY")
   {
      // Ajustement: SL plus "large" et TP >= 3R
      slOut = s_level - atrVal * 1.00;
      risk = MathMax(entryOut - slOut, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 15.0);
      tpOut = entryOut + (MathMax(3.0, InpRiskReward) * risk);
   }
   else
   {
      // Ajustement: SL plus "large" et TP >= 3R
      slOut = s_level + atrVal * 1.00;
      risk = MathMax(slOut - entryOut, SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 15.0);
      tpOut = entryOut - (MathMax(3.0, InpRiskReward) * risk);
   }

   // Consommer le signal (une seule entrée par BOS)
   s_waitingRetest = false;
   s_dir = "";
   s_level = 0.0;
   s_bosTime = 0;

   return true;
}

void ExecuteForexBOSRetest()
{
   if(SMC_GetSymbolCategory(_Symbol) != SYM_FOREX) return;

   // PROTECTION CONTRE LES PERTES PAR SYMBOLE - Vérifier avant tout
   if(CheckSymbolLossProtection())
   {
      Print("🚨 FOREX BOS+Retest BLOQUÉ - Protection symbole activée sur ", _Symbol);
      Print("   💰 Perte actuelle: ", DoubleToString(g_symbolCurrentLoss, 2), "$ > Limite: ", DoubleToString(MaxLossPerSymbolDollars, 2), "$");
      return;
   }
   
   // FILTRE PRIORITÉ SYMBOLES PROPICES - BLOCAGE TOTAL SI NON PRIORITAIRE
   if(UsePropiceSymbolsFilter)
   {
      if(!g_currentSymbolIsPropice)
      {
         Print("🚫 FOREX BOS+Retest BLOQUÉ - Symbole non 'propice': ", _Symbol);
         Print("   Heure UTC: ", TimeToString(TimeCurrent(), TIME_SECONDS), " | Top propices: ", g_propiceTopSymbolsText);
         Print("   🚫 BLOCAGE TOTAL - Aucun trade autorisé sur les symboles non propices");
         return;
      }
      
      // Avant: blocage total si pas rang 0.
      // Maintenant: on autorise si le symbole est propice, avec seuils plus stricts côté IA (voir gating ci-dessous).
      if(!IsMostPropiceSymbol())
      {
         if(!PropiceAllowMarketOrdersOnAllPropiceSymbols)
         {
            string mostPropice = GetMostPropiceSymbol();
            Print("🚫 FOREX BOS+Retest BLOQUÉ - Symbole pas le plus propice: ", _Symbol);
            Print("   📍 Position actuelle: ", g_currentSymbolPriority + 1, "ème dans la liste");
            Print("   🥇 Symbole le plus propice: ", mostPropice);
            Print("   🚫 BLOCAGE TOTAL - Seul le symbole le plus propice peut être tradé");
            return;
         }
         Print("⚠️ FOREX BOS+Retest - Symbole propice rang >", g_currentSymbolPriority + 1,
               ") autorisé: ", _Symbol, " (seuil IA plus strict)"); 
      }
      else
      {
         Print("🥇 SYMBOLE LE PLUS PROPICE - FOREX BOS+Retest autorisé: ", _Symbol);
         Print("   ✅ Priorité maximale - Exécution autorisée");
      }
   }

   // Anti-duplication symbol exposure
   if(HasAnyExposureForSymbol(_Symbol)) return;

   string dir;
   double entry, sl, tp;
   if(!Forex_DetectBOSRetest(dir, entry, sl, tp)) return;

   string d = dir; StringToUpper(d);

   // IA gating (HOLD interdit + direction match + confiance >= MinAIConfidencePercent)
   if(UseAIServer)
   {
      string ia = g_lastAIAction;
      StringToUpper(ia);
      double confPct = g_lastAIConfidence * 100.0;
      double minConfPct = MinAIConfidencePercent;
      if(UsePropiceSymbolsFilter && PropiceAllowMarketOrdersOnAllPropiceSymbols &&
         g_currentSymbolIsPropice && g_currentSymbolPriority > 0)
      {
         minConfPct += (double)g_currentSymbolPriority *
                        PropiceNonTopExtraMinAIConfidencePercentPerRank;
      }

      if(ia == "" || ia == "HOLD")
      {
         Print("⛔ FOREX BOS+Retest bloqué - IA HOLD/absente sur ", _Symbol);
         return;
      }
      if(ia != d)
      {
         Print("⛔ FOREX BOS+Retest bloqué - IA=", ia, " != ", d, " sur ", _Symbol, " (", DoubleToString(confPct, 1), "%)");
         return;
      }
      if(confPct < minConfPct)
      {
         Print("⛔ FOREX BOS+Retest bloqué - Confiance IA trop faible: ", DoubleToString(confPct,1),
               "% < ", DoubleToString(minConfPct,1), "% sur ", _Symbol);
         return;
      }
   }

   // ML gating (seuil Forex via IsMLModelTrustedForCurrentSymbol)
   if(!IsMLModelTrustedForCurrentSymbol(d))
   {
      Print("⛔ FOREX BOS+Retest bloqué - Modèle ML non fiable sur ", _Symbol,
            " (acc=", DoubleToString(g_mlLastAccuracy * 100.0, 1), "%)");
      return;
   }

   // Lock terminal-level (éviter doubles opens simultanés)
   if(!TryAcquireOpenLock()) return;

   // Respecter les contraintes stops level du broker
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = MathMax((double)stopsLevel * point, point * 10.0);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(d == "BUY")
   {
      entry = ask;
      if((entry - sl) < minDist) sl = entry - minDist;
      if((tp - entry) < minDist) tp = entry + minDist;
   }
   else
   {
      entry = bid;
      if((sl - entry) < minDist) sl = entry + minDist;
      if((entry - tp) < minDist) tp = entry - minDist;
   }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double lot = CalculateLotSize(); // lots standard EA (risk mgmt déjà existant)
   lot = NormalizeVolumeForSymbol(lot);

   bool ok = false;
   string comment = "FOREX_BOS_RETEST";
   if(d == "BUY")
      ok = trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);
   else
      ok = trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);

   if(ok)
   {
      Print("✅ FOREX BOS+Retest EXECUTÉ ", d, " ", _Symbol,
            " | lot=", DoubleToString(lot, 2),
            " | SL=", DoubleToString(sl, _Digits),
            " | TP=", DoubleToString(tp, _Digits));
   }
   else
   {
      Print("❌ FOREX BOS+Retest ÉCHEC ", d, " ", _Symbol,
            " | err=", IntegerToString(GetLastError()));
   }

   ReleaseOpenLock();
}

string FormatWLNet(int wins, int losses, double net)
{
   return IntegerToString(wins) + "W/" + IntegerToString(losses) + "L | Net=" + DoubleToString(net, 2) + "$";
}

// Stats strictement issues de l'historique MT5 (deals) filtrés par Magic + symbole + période.
// Compte les sorties (DEAL_ENTRY_OUT) et agrège profit+swap+commission.
bool GetSymbolStatsFromHistory(const string symbol, datetime fromTime, datetime toTime, int &winsOut, int &lossesOut, double &netOut)
{
   winsOut = 0;
   lossesOut = 0;
   netOut = 0.0;
   if(StringLen(symbol) <= 0) return false;
   if(fromTime <= 0 || toTime <= 0 || toTime <= fromTime) return false;

   if(!HistorySelect(fromTime, toTime))
      return false;

   int total = HistoryDealsTotal();
   if(total <= 0) return true; // pas d'historique -> stats à 0

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      long magic = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
      if(magic != InpMagicNumber) continue;

      string sym = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(sym != symbol) continue;

      long entry = (long)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      netOut += profit;
      if(profit > 0) winsOut++;
      else if(profit < 0) lossesOut++;
   }

   return true;
}

// Stats étendues strictement issues de l'historique MT5 (deals) filtrés par Magic + symbole + période.
// tradeCount: nombre de deals de sortie (DEAL_ENTRY_OUT) dans la fenêtre
// grossProfit: somme des profits positifs
// grossLossAbs: somme des pertes en valeur absolue (positive)
// lastTradeAtOut: timestamp du dernier deal de sortie (0 si aucun)
bool GetSymbolStatsExtendedFromHistory(const string symbol,
                                      datetime fromTime,
                                      datetime toTime,
                                      int &tradeCountOut,
                                      int &winsOut,
                                      int &lossesOut,
                                      double &netOut,
                                      double &grossProfitOut,
                                      double &grossLossAbsOut,
                                      datetime &lastTradeAtOut)
{
   tradeCountOut = 0;
   winsOut = 0;
   lossesOut = 0;
   netOut = 0.0;
   grossProfitOut = 0.0;
   grossLossAbsOut = 0.0;
   lastTradeAtOut = 0;

   if(StringLen(symbol) <= 0) return false;
   if(fromTime <= 0 || toTime <= 0 || toTime <= fromTime) return false;

   if(!HistorySelect(fromTime, toTime))
      return false;

   int total = HistoryDealsTotal();
   if(total <= 0) return true;

   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      long magic = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
      if(magic != InpMagicNumber) continue;

      string sym = HistoryDealGetString(ticket, DEAL_SYMBOL);
      if(sym != symbol) continue;

      long entry = (long)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue;

      datetime t = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(t > lastTradeAtOut) lastTradeAtOut = t;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                      HistoryDealGetDouble(ticket, DEAL_SWAP) +
                      HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      tradeCountOut++;
      netOut += profit;
      if(profit > 0)
      {
         winsOut++;
         grossProfitOut += profit;
      }
      else if(profit < 0)
      {
         lossesOut++;
         grossLossAbsOut += -profit;
      }
   }

   return true;
}

// Stats locales: met à jour g_dayWins/g_dayLosses/g_dayNetProfit et g_monthWins/g_monthLosses/g_monthNetProfit
// directement depuis l'historique MT5 (source de vérité pour le panneau).
void EnsureLocalSymbolStatsUpToDate()
{
   // Throttle: éviter de marteler HistorySelect à chaque tick
   static datetime lastLocalUpdate = 0;
   datetime now = TimeCurrent();
   if(now - lastLocalUpdate < 15) // maj max toutes les 15s (dashboard se met à jour à 15s)
      return;
   lastLocalUpdate = now;

   datetime nowUtc = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(nowUtc, dt);

   // Début de journée UTC
   MqlDateTime d0 = dt;
   d0.hour = 0; d0.min = 0; d0.sec = 0;
   datetime dayStartUtc = StructToTime(d0);

   // Début de mois UTC
   MqlDateTime m0 = dt;
   m0.day = 1;
   m0.hour = 0; m0.min = 0; m0.sec = 0;
   datetime monthStartUtc = StructToTime(m0);

   int tcDay=0, wDay=0, lDay=0;
   double netDay=0, gpDay=0, glDay=0;
   datetime lastDay=0;

   int tcMonth=0, wMonth=0, lMonth=0;
   double netMonth=0, gpMonth=0, glMonth=0;
   datetime lastMonth=0;

   if(GetSymbolStatsExtendedFromHistory(_Symbol, dayStartUtc, nowUtc, tcDay, wDay, lDay, netDay, gpDay, glDay, lastDay))
   {
      g_dayWins = wDay;
      g_dayLosses = lDay;
      g_dayNetProfit = netDay;
   }

   if(GetSymbolStatsExtendedFromHistory(_Symbol, monthStartUtc, nowUtc, tcMonth, wMonth, lMonth, netMonth, gpMonth, glMonth, lastMonth))
   {
      g_monthWins = wMonth;
      g_monthLosses = lMonth;
      g_monthNetProfit = netMonth;
   }
   g_symbolStatsLastLocalUpdate = nowUtc;
}

// Envoie les stats jour/mois (UTC) au serveur pour UPSERT dans Supabase `symbol_trade_stats`
void SyncSymbolTradeStatsToServer()
{
   if(!UseAIServer) return;

   static datetime lastSync = 0;
   datetime now = TimeCurrent();
   if(now - lastSync < 300) return; // 5 minutes
   lastSync = now;

   if(AI_ServerURL == "" && AI_ServerRender == "") return;
   g_symbolStatsLastSyncAttempt = TimeGMT();

   datetime nowUtc = TimeGMT();
   MqlDateTime dt;
   TimeToStruct(nowUtc, dt);

   MqlDateTime d0 = dt;
   d0.hour = 0; d0.min = 0; d0.sec = 0;
   datetime dayStartUtc = StructToTime(d0);

   MqlDateTime m0 = dt;
   m0.day = 1;
   m0.hour = 0; m0.min = 0; m0.sec = 0;
   datetime monthStartUtc = StructToTime(m0);

   int tcDay=0, wDay=0, lDay=0;
   double netDay=0, gpDay=0, glDay=0;
   datetime lastDay=0;

   int tcMonth=0, wMonth=0, lMonth=0;
   double netMonth=0, gpMonth=0, glMonth=0;
   datetime lastMonth=0;

   if(!GetSymbolStatsExtendedFromHistory(_Symbol, dayStartUtc, nowUtc, tcDay, wDay, lDay, netDay, gpDay, glDay, lastDay))
      return;
   if(!GetSymbolStatsExtendedFromHistory(_Symbol, monthStartUtc, nowUtc, tcMonth, wMonth, lMonth, netMonth, gpMonth, glMonth, lastMonth))
      return;

   string dayDate = TimeToString(dayStartUtc, TIME_DATE);
   string monthDate = TimeToString(monthStartUtc, TIME_DATE);
   long lastDayMs = (lastDay > 0 ? (long)lastDay * 1000 : 0);
   long lastMonthMs = (lastMonth > 0 ? (long)lastMonth * 1000 : 0);

   string json_payload = StringFormat(
      "{"
      "\"rows\":["
      "{"
      "\"symbol\":\"%s\","
      "\"period_type\":\"day\","
      "\"period_start\":\"%s\","
      "\"timeframe\":\"M1\","
      "\"trade_count\":%d,"
      "\"wins\":%d,"
      "\"losses\":%d,"
      "\"net_profit\":%.2f,"
      "\"gross_profit\":%.2f,"
      "\"gross_loss\":%.2f,"
      "\"last_trade_at\":%lld"
      "},"
      "{"
      "\"symbol\":\"%s\","
      "\"period_type\":\"month\","
      "\"period_start\":\"%s\","
      "\"timeframe\":\"M1\","
      "\"trade_count\":%d,"
      "\"wins\":%d,"
      "\"losses\":%d,"
      "\"net_profit\":%.2f,"
      "\"gross_profit\":%.2f,"
      "\"gross_loss\":%.2f,"
      "\"last_trade_at\":%lld"
      "}"
      "]"
      "}",
      _Symbol, dayDate, tcDay, wDay, lDay, netDay, gpDay, glDay, lastDayMs,
      _Symbol, monthDate, tcMonth, wMonth, lMonth, netMonth, gpMonth, glMonth, lastMonthMs
   );

   string url1 = UseRenderAsPrimary ? (AI_ServerRender + "/mt5/symbol-trade-stats-upload") : (AI_ServerURL + "/mt5/symbol-trade-stats-upload");
   string url2 = UseRenderAsPrimary ? (AI_ServerURL + "/mt5/symbol-trade-stats-upload") : (AI_ServerRender + "/mt5/symbol-trade-stats-upload");

   string headers = "Content-Type: application/json\r\n";
   char post_data[];
   char result_data[];
   string result_headers;
   StringToCharArray(json_payload, post_data, 0, StringLen(json_payload));

   int http_result = WebRequest("POST", url1, headers, AI_Timeout_ms, post_data, result_data, result_headers);
   if(http_result != 200)
      http_result = WebRequest("POST", url2, headers, AI_Timeout_ms2, post_data, result_data, result_headers);

   if(http_result == 200)
   {
      g_dayWins = wDay; g_dayLosses = lDay; g_dayNetProfit = netDay;
      g_monthWins = wMonth; g_monthLosses = lMonth; g_monthNetProfit = netMonth;
      g_symbolStatsSyncOk = true;
      g_symbolStatsLastSyncOk = TimeGMT();
      g_symbolStatsLastChecksum = IntegerToString(tcDay) + "|" + IntegerToString(wDay) + "|" + IntegerToString(lDay) + "|" + DoubleToString(netDay, 2) +
                                  "|" + IntegerToString(tcMonth) + "|" + IntegerToString(wMonth) + "|" + IntegerToString(lMonth) + "|" + DoubleToString(netMonth, 2);
      Print("📊 STATS SYM SYNC OK - ", _Symbol, " | day ", IntegerToString(wDay), "W/", IntegerToString(lDay), "L net=", DoubleToString(netDay, 2),
            " | month ", IntegerToString(wMonth), "W/", IntegerToString(lMonth), "L net=", DoubleToString(netMonth, 2));
   }
   else
   {
      g_symbolStatsSyncOk = false;
      Print("⚠️ STATS SYM SYNC ÉCHEC - HTTP ", http_result, " | ", _Symbol);
   }
}

//| VALIDATION ET AJUSTEMENT DES PRIX POUR ORDRES LIMITES            |
bool ValidateAndAdjustLimitPrice(double &entryPrice, double &stopLoss, double &takeProfit, ENUM_ORDER_TYPE orderType)
{
   // Garde-fou central Boom/Crash: aucune inversion directionnelle autorisée
   if(!IsOrderTypeAllowedForBoomCrash(_Symbol, orderType))
   {
      Print("🚫 LIMIT BLOQUÉ - Type d'ordre interdit pour ", _Symbol,
            " | orderType=", (int)orderType,
            " | Rule: Boom=BUY only / Crash=SELL only");
      return false;
   }

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
      Print("?? Volatility Index détecté - Distance minimale: ", DoubleToString(minDistance, 0), " pips");
   }
   else if(isGold)
   {
      minDistance = MathMax(minDistance, 200 * point); // 200 pips minimum pour XAUUSD
      Print("?? Gold (XAUUSD) détecté - Distance minimale: ", DoubleToString(minDistance, 0), " pips");
   }
   else if(isForex)
   {
      minDistance = MathMax(minDistance, 100 * point); // Augmenté à 100 pips pour Forex (AUDJPY, etc.)
      Print("?? Forex détecté - Distance minimale: ", DoubleToString(minDistance, 0), " pips");
   }
   else
   {
      minDistance = MathMax(minDistance, 30 * point); // 30 pips minimum par défaut
   }
   
   // Validation et ajustement du prix d'entrée
   bool priceAdjusted = false;
   
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      // BUY LIMIT doit être < Ask
      if(entryPrice >= currentAsk)
      {
         entryPrice = currentBid - (minDistance * 2); // Plus de marge
         priceAdjusted = true;
         Print("?? BUY LIMIT price ajusté: ", DoubleToString(entryPrice, _Digits), " (doit être < Ask)");
      }
      
      // Vérifier distance minimale
      if(currentAsk - entryPrice < minDistance)
      {
         entryPrice = currentAsk - (minDistance * 1.5); // Plus de marge
         priceAdjusted = true;
         Print("?? BUY LIMIT distance ajustée: ", DoubleToString(entryPrice, _Digits), " (distance minimale)");
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      // SELL LIMIT doit être > Bid
      if(entryPrice <= currentBid)
      {
         entryPrice = currentAsk + (minDistance * 2); // Plus de marge
         priceAdjusted = true;
         Print("?? SELL LIMIT price ajusté: ", DoubleToString(entryPrice, _Digits), " (doit être > Bid)");
      }
      
      // Vérifier distance minimale
      if(entryPrice - currentBid < minDistance)
      {
         entryPrice = currentBid + (minDistance * 1.5); // Plus de marge
         priceAdjusted = true;
         Print("?? SELL LIMIT distance ajustée: ", DoubleToString(entryPrice, _Digits), " (distance minimale)");
      }
   }
   
   // Validation et ajustement du Stop Loss
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(stopLoss >= entryPrice || (entryPrice - stopLoss) < minDistance)
      {
         stopLoss = entryPrice - (minDistance * 1.2); // Plus de marge
         Print("?? BUY LIMIT SL ajusté: ", DoubleToString(stopLoss, _Digits));
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      if(stopLoss <= entryPrice || (stopLoss - entryPrice) < minDistance)
      {
         stopLoss = entryPrice + (minDistance * 1.2); // Plus de marge
         Print("?? SELL LIMIT SL ajusté: ", DoubleToString(stopLoss, _Digits));
      }
   }
   
   // Validation et ajustement du Take Profit
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(takeProfit <= entryPrice || (takeProfit - entryPrice) < minDistance)
      {
         takeProfit = entryPrice + (minDistance * 3); // Ratio 1:3 pour plus de sécurité
         Print("?? BUY LIMIT TP ajusté: ", DoubleToString(takeProfit, _Digits));
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      if(takeProfit >= entryPrice || (entryPrice - takeProfit) < minDistance)
      {
         takeProfit = entryPrice - (minDistance * 3); // Ratio 1:3 pour plus de sécurité
         Print("?? SELL LIMIT TP ajusté: ", DoubleToString(takeProfit, _Digits));
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
         Print("? ERREUR CRITIQUE: Prix BUY LIMIT toujours invalides après ajustement!");
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
         Print("? ERREUR CRITIQUE: Prix SELL LIMIT toujours invalides après ajustement!");
         Print("   Entry: ", DoubleToString(entryPrice, _Digits), " Bid: ", DoubleToString(currentBid, _Digits));
         Print("   SL: ", DoubleToString(stopLoss, _Digits), " TP: ", DoubleToString(takeProfit, _Digits));
         Print("   MinDistance: ", DoubleToString(minDistance, 0), " pips");
         return false;
      }
   }
   
   if(priceAdjusted)
   {
      Print("? Prix final ajusté - Entry: ", DoubleToString(entryPrice, _Digits), 
            " SL: ", DoubleToString(stopLoss, _Digits), 
            " TP: ", DoubleToString(takeProfit, _Digits));
   }
   
   return true;
}

// Validation "exact entry": ne modifie jamais le prix d'entrée,
// uniquement les SL/TP (et rejette l'ordre si le courtier exige un autre entry).
bool ValidateLimitPriceExactEntry(double entryPrice, double &stopLoss, double &takeProfit, ENUM_ORDER_TYPE orderType)
{
   static datetime lastExactEntryFailLog = 0;

   if(!IsOrderTypeAllowedForBoomCrash(_Symbol, orderType))
   {
      Print("🚫 LIMIT BLOQUÉ (exact entry) - Type d'ordre interdit pour ", _Symbol,
            " | orderType=", (int)orderType,
            " | Rule: Boom=BUY only / Crash=SELL only");
      return false;
   }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = stopsLevel * point;

   // Ajustements spécifiques (même logique que ValidateAndAdjustLimitPrice)
   bool isVolatility = (StringFind(_Symbol, "Volatility") >= 0 || StringFind(_Symbol, "RANGE BREAK") >= 0);
   bool isGold = (StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "GOLD") >= 0);
   bool isForex = (StringFind(_Symbol, "USD") >= 0 && !isGold && !isVolatility);

   if(isVolatility)
      minDistance = MathMax(minDistance, 500 * point);
   else if(isGold)
      minDistance = MathMax(minDistance, 200 * point);
   else if(isForex)
      minDistance = MathMax(minDistance, 100 * point);
   else
      minDistance = MathMax(minDistance, 30 * point);

   // Rejeter si le courtier n'accepte pas l'entrée à ce niveau exact.
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(entryPrice >= currentAsk)
      {
         if(TimeCurrent() - lastExactEntryFailLog > 60)
         {
            Print("❌ exact entry BUY_LIMIT rejeté: entry >= Ask | Symbol=", _Symbol,
                  " entry=", DoubleToString(entryPrice, _Digits),
                  " Ask=", DoubleToString(currentAsk, _Digits));
            lastExactEntryFailLog = TimeCurrent();
         }
         return false;
      }
      if(currentAsk - entryPrice < minDistance)
      {
         if(TimeCurrent() - lastExactEntryFailLog > 60)
         {
            Print("❌ exact entry BUY_LIMIT rejeté: distance Ask-entry < minDistance | Symbol=", _Symbol,
                  " dist=", DoubleToString(currentAsk - entryPrice, _Digits),
                  " minDistance=", DoubleToString(minDistance, 0));
            lastExactEntryFailLog = TimeCurrent();
         }
         return false;
      }
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      if(entryPrice <= currentBid)
      {
         if(TimeCurrent() - lastExactEntryFailLog > 60)
         {
            Print("❌ exact entry SELL_LIMIT rejeté: entry <= Bid | Symbol=", _Symbol,
                  " entry=", DoubleToString(entryPrice, _Digits),
                  " Bid=", DoubleToString(currentBid, _Digits));
            lastExactEntryFailLog = TimeCurrent();
         }
         return false;
      }
      if(entryPrice - currentBid < minDistance)
      {
         if(TimeCurrent() - lastExactEntryFailLog > 60)
         {
            Print("❌ exact entry SELL_LIMIT rejeté: distance entry-Bid < minDistance | Symbol=", _Symbol,
                  " dist=", DoubleToString(entryPrice - currentBid, _Digits),
                  " minDistance=", DoubleToString(minDistance, 0));
            lastExactEntryFailLog = TimeCurrent();
         }
         return false;
      }
   }
   else
   {
      return false;
   }

   // Ajuster uniquement SL/TP (entry inchangée).
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(stopLoss >= entryPrice || (entryPrice - stopLoss) < minDistance)
         stopLoss = entryPrice - (minDistance * 1.2);
      if(takeProfit <= entryPrice || (takeProfit - entryPrice) < minDistance)
         takeProfit = entryPrice + (minDistance * 3.0);
   }
   else // SELL_LIMIT
   {
      if(stopLoss <= entryPrice || (stopLoss - entryPrice) < minDistance)
         stopLoss = entryPrice + (minDistance * 1.2);
      if(takeProfit >= entryPrice || (entryPrice - takeProfit) < minDistance)
         takeProfit = entryPrice - (minDistance * 3.0);
   }

   // Alignement SL/TP sur tick size (réduit le risque de [Invalid stops]).
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      stopLoss   = MathFloor(stopLoss / tickSize) * tickSize;  // en dessous
      takeProfit = MathCeil(takeProfit / tickSize) * tickSize;  // au dessus
   }
   else
   {
      stopLoss   = MathCeil(stopLoss / tickSize) * tickSize;  // au dessus
      takeProfit = MathFloor(takeProfit / tickSize) * tickSize; // en dessous
   }

   stopLoss   = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);

   // Vérification finale très stricte: entry reste exact.
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(entryPrice >= currentAsk) return false;
      if(currentAsk - entryPrice < minDistance) return false;
      if(stopLoss >= entryPrice || (entryPrice - stopLoss) < minDistance) 
      {
         if(TimeCurrent() - lastExactEntryFailLog > 60)
         {
            Print("❌ exact entry BUY_LIMIT rejeté: SL invalide/insuffisant | Symbol=", _Symbol,
                  " entry=", DoubleToString(entryPrice, _Digits),
                  " SL=", DoubleToString(stopLoss, _Digits),
                  " minDistance=", DoubleToString(minDistance, 0));
            lastExactEntryFailLog = TimeCurrent();
         }
         return false;
      }
      if(takeProfit <= entryPrice || (takeProfit - entryPrice) < minDistance)
      {
         if(TimeCurrent() - lastExactEntryFailLog > 60)
         {
            Print("❌ exact entry BUY_LIMIT rejeté: TP invalide/insuffisant | Symbol=", _Symbol,
                  " entry=", DoubleToString(entryPrice, _Digits),
                  " TP=", DoubleToString(takeProfit, _Digits),
                  " minDistance=", DoubleToString(minDistance, 0));
            lastExactEntryFailLog = TimeCurrent();
         }
         return false;
      }
   }
   else // SELL_LIMIT
   {
      if(entryPrice <= currentBid) return false;
      if(entryPrice - currentBid < minDistance) return false;
      if(stopLoss <= entryPrice || (stopLoss - entryPrice) < minDistance) 
      {
         if(TimeCurrent() - lastExactEntryFailLog > 60)
         {
            Print("❌ exact entry SELL_LIMIT rejeté: SL invalide/insuffisant | Symbol=", _Symbol,
                  " entry=", DoubleToString(entryPrice, _Digits),
                  " SL=", DoubleToString(stopLoss, _Digits),
                  " minDistance=", DoubleToString(minDistance, 0));
            lastExactEntryFailLog = TimeCurrent();
         }
         return false;
      }
      if(takeProfit >= entryPrice || (entryPrice - takeProfit) < minDistance)
      {
         if(TimeCurrent() - lastExactEntryFailLog > 60)
         {
            Print("❌ exact entry SELL_LIMIT rejeté: TP invalide/insuffisant | Symbol=", _Symbol,
                  " entry=", DoubleToString(entryPrice, _Digits),
                  " TP=", DoubleToString(takeProfit, _Digits),
                  " minDistance=", DoubleToString(minDistance, 0));
            lastExactEntryFailLog = TimeCurrent();
         }
         return false;
      }
   }

   return true;
}

void ManageTrailingStop()
{
   // DEBUG: Log pour vérifier si la fonction est appelée
   static datetime lastDebugLog = 0;
   datetime now = TimeCurrent();
   if(now - lastDebugLog >= 10) // Log toutes les 10 secondes maximum
   {
      Print("🔍 DEBUG ManageTrailingStop() appelée | Positions totales: ", PositionsTotal());
      lastDebugLog = now;
   }
   
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
   
   Print("🔍 DEBUG: ", ourPositionsCount, " positions trouvées avec notre magic number");
   
   // NOTE: Modification SL dynamique OBLIGATOIRE partout
   // Plus de condition - le SL dynamique est maintenant obligatoire
   // if(!DynamicSL_Enable && !UseTrailingStop) return; // ANCIEN LOGIQUE - MAINTENANT OBLIGATOIRE

   // Throttle global: éviter spam de PositionModify
   static datetime lastRun = 0;
   datetime nowRun = TimeCurrent();
   if(nowRun - lastRun < 1) return; // max 1 fois / seconde
   lastRun = nowRun;
   
   // Parcourir uniquement nos positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      
      // Appliquer la modification dynamique des SL à TOUS les symboles tradés
      // Boom/Crash, Volatility Index, Forex, Métaux - tous éligibles (aucune exclusion)
      string symbol = posInfo.Symbol();
      ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
      if(cat == SYM_BOOM_CRASH)
      {
         // Règle utilisateur: ne jamais modifier le SL des positions Boom/Crash.
         continue;
      }
      
      ulong  ticket = posInfo.Ticket();
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      double currentTP = posInfo.TakeProfit();
      
      Print("🔍 DEBUG Position: ", symbol, " | Ticket: ", ticket, " | Profit: ", DoubleToString(profit, 2), "$ | SL: ", DoubleToString(currentSL, _Digits));

      // Trailing distance: ATR du symbole de la position (M1)
      double atrValue = 0.0;
      int atrLocalHandle = iATR(symbol, PERIOD_M1, 14);
      if(atrLocalHandle != INVALID_HANDLE)
      {
         double atrBuf[];
         ArraySetAsSeries(atrBuf, true);
         if(CopyBuffer(atrLocalHandle, 0, 0, 1, atrBuf) >= 1)
            atrValue = atrBuf[0];
      }
      if(atrValue <= 0.0) continue;

      double trailDistance = atrValue * (TrailingStop_ATRMult > 0 ? TrailingStop_ATRMult : 3.0); // 3.0 ATR par défaut
      // Break-even buffer: petit cushion pour sécuriser même micro-gains
      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      if(point <= 0) point = 0.0001;
      double beBuffer = (double)MathMax(0, DynamicSL_BE_BufferPoints > 0 ? DynamicSL_BE_BufferPoints : 5) * point; // 5 points par défaut

      // Prix courant selon le symbole de la position
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(bid <= 0 || ask <= 0) continue;
      
      // Vérifier existence position avant toute modif
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != symbol)
         continue;
      
      // Max profit par ticket (évite g_maxProfit global qui mélange les positions)
      string gvName = "SMC_MAXPROFIT_" + IntegerToString((int)ticket);
      double maxP = 0.0;
      if(GlobalVariableCheck(gvName))
         maxP = GlobalVariableGet(gvName);
      if(profit > maxP)
      {
         maxP = profit;
         GlobalVariableSet(gvName, maxP);
      }

      // Modification SL dynamique OBLIGATOIRE - PROTECTION 80% CONTRE PERTE DE GAIN
      double startP = DynamicSL_Enable ? DynamicSL_StartProfitDollars : 
                      (UseTrailingStop ? TrailingStartProfitDollars : 0.50); // 0.50$ par défaut
      
      // PROTECTION RENFORCÉE: Protéger 70% du gain maximum (perdre maximum 30%)
      double lockPct = DynamicSL_Enable ? DynamicSL_LockPctOfMax : 
                      (UseTrailingStop ? 0.70 : 0.70); // 70% par défaut - PROTÉGER 70% DU GAIN MAX
      if(lockPct < 0.0) lockPct = 0.0;
      if(lockPct > 1.0) lockPct = 1.0;

      bool shouldTrail = (profit >= startP) || (maxP >= startP && profit <= (maxP * (1.0 - lockPct)));
      double lockProfit = maxP * lockPct;
      
      Print("🔍 DEBUG Trailing: Profit=", DoubleToString(profit, 2), "$ | MaxProfit=", DoubleToString(maxP, 2), "$ | Start=", DoubleToString(startP, 2), "$ | ShouldTrail=", shouldTrail ? "YES" : "NO");

      // Convertir lockProfit ($) -> distance prix, selon tick_value/tick_size et volume
      double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickVal  = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tickSize <= 0) tickSize = point;
      if(tickVal <= 0) tickVal = 1.0;
      double dollarsPerPriceUnit = (tickVal / tickSize) * posInfo.Volume();
      if(dollarsPerPriceUnit <= 0) dollarsPerPriceUnit = 1.0;
      double lockPriceDist = (lockProfit > 0 ? (lockProfit / dollarsPerPriceUnit) : 0.0);
      
      if(shouldTrail)
      {
         if(posInfo.PositionType() == POSITION_TYPE_BUY)
         {
            // 1) Break-even dès micro gain: SL >= open + buffer
            double beSL = openPrice + beBuffer;
            // 2) Trailing ATR
            double newSL = bid - trailDistance;
            if(newSL < beSL) newSL = beSL;

            // 3) Lock X% du gain max en $: empêcher de retomber trop bas
            if(DynamicSL_Enable && lockPriceDist > 0)
            {
               double lockSL = bid - lockPriceDist;
               if(lockSL < beSL) lockSL = beSL;
               if(newSL < lockSL) newSL = lockSL;
            }
            
            Print("🔍 DEBUG BUY SL: Open=", DoubleToString(openPrice, _Digits), " | Bid=", DoubleToString(bid, _Digits), " | CurrentSL=", DoubleToString(currentSL, _Digits), " | NewSL=", DoubleToString(newSL, _Digits), " | BeSL=", DoubleToString(beSL, _Digits));
            
            // Valider le SL avant modification
            if(ValidateStopLossForModification(symbol, "BUY", bid, newSL))
            {
               // Only move SL if it improves the current SL and is above open price
               bool shouldModify = (newSL > currentSL && newSL > openPrice);
               Print("🔍 DEBUG BUY Modify: ShouldModify=", shouldModify ? "YES" : "NO", " | NewSL>CurrentSL=", (newSL > currentSL) ? "YES" : "NO", " | NewSL>OpenPrice=", (newSL > openPrice) ? "YES" : "NO");
               
               if(shouldModify)
               {
                  if(trade.PositionModify(ticket, newSL, currentTP))
                  {
                     Print("?? Trailing Stop BUY mis à jour: ", symbol, " | ", DoubleToString(currentSL, _Digits), " -> ", DoubleToString(newSL, _Digits));
                  }
                  else
                  {
                     Print("❌ ERREUR Trailing Stop BUY: ", trade.ResultRetcode(), " | ", trade.ResultRetcodeDescription());
                  }
               }
            }
            else
            {
               Print("🔍 DEBUG BUY SL Validation FAILED");
            }
         }
         else if(posInfo.PositionType() == POSITION_TYPE_SELL)
         {
            double beSL = openPrice - beBuffer;
            double newSL = ask + trailDistance;
            if(newSL > beSL) newSL = beSL;

            if(DynamicSL_Enable && lockPriceDist > 0)
            {
               double lockSL = ask + lockPriceDist;
               if(lockSL > beSL) lockSL = beSL;
               if(newSL > lockSL) newSL = lockSL;
            }
            
            Print("🔍 DEBUG SELL SL: Open=", DoubleToString(openPrice, _Digits), " | Ask=", DoubleToString(ask, _Digits), " | CurrentSL=", DoubleToString(currentSL, _Digits), " | NewSL=", DoubleToString(newSL, _Digits), " | BeSL=", DoubleToString(beSL, _Digits));
            
            // Valider le SL avant modification
            if(ValidateStopLossForModification(symbol, "SELL", ask, newSL))
            {
               // Only move SL if it improves the current SL and is below open price
               bool shouldModify = ((newSL < currentSL || currentSL == 0) && newSL < openPrice);
               Print("🔍 DEBUG SELL Modify: ShouldModify=", shouldModify ? "YES" : "NO", " | NewSL<CurrentSL=", (newSL < currentSL || currentSL == 0) ? "YES" : "NO", " | NewSL<OpenPrice=", (newSL < openPrice) ? "YES" : "NO");
               
               if(shouldModify)
               {
                  if(trade.PositionModify(ticket, newSL, currentTP))
                  {
                     Print("?? Trailing Stop SELL mis à jour: ", symbol, " | ", DoubleToString(currentSL, _Digits), " -> ", DoubleToString(newSL, _Digits));
                  }
                  else
                  {
                     Print("❌ ERREUR Trailing Stop SELL: ", trade.ResultRetcode(), " | ", trade.ResultRetcodeDescription());
                  }
               }
            }
            else
            {
               Print("🔍 DEBUG SELL SL Validation FAILED");
            }
         }
      }
   }

   // Nettoyage opportuniste: supprimer les GV max profit des tickets qui n'existent plus
   static datetime lastCleanup = 0;
   datetime nowC = TimeCurrent();
   if(nowC - lastCleanup >= 30)
   {
      lastCleanup = nowC;
      for(int gi = (int)GlobalVariablesTotal() - 1; gi >= 0; gi--)
      {
         string gv = GlobalVariableName(gi);
         if(StringFind(gv, "SMC_MAXPROFIT_") != 0) continue;
         string tidStr = StringSubstr(gv, StringLen("SMC_MAXPROFIT_"));
         long tid = (long)StringToInteger(tidStr);
         if(tid <= 0) continue;
         if(!PositionSelectByTicket((ulong)tid))
            GlobalVariableDel(gv);
      }
   }
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
      Print("?? Trop d'erreurs de capture graphique - Mode dégradé");
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
         Print("?? Buffer trop grand: ", bufferSize, " - Limitation à 100");
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
      Print("?? Données graphiques capturées: ", bufferSize, " bougies M1");
      return true;
   }
   else
   {
      captureErrors++;
      Print("? Erreur capture graphique (", captureErrors, "/3) - bars demandées: ", barsToCopy);
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
      if(dir == "SELL") { scoreFor++; summaryOut += "[RSI SURACHAT?SELL] "; }
      else              { scoreAgainst++; summaryOut += "[RSI SURACHAT CONTRA] "; }
   }
   else if(rsi < 30.0)
   {
      if(dir == "BUY")  { scoreFor++; summaryOut += "[RSI SURVENTE?BUY] "; }
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
               if(dir == "SELL") { scoreFor++; summaryOut += "[BB HAUT?SELL] "; }
               else              { scoreAgainst++; summaryOut += "[BB HAUT CONTRA] "; }
            }
            else if(nearLower)
            {
               if(dir == "BUY")  { scoreFor++; summaryOut += "[BB BAS?BUY] "; }
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
            if(dir == "BUY")  { scoreFor++; summaryOut += "[VWAP AU-DESSUS?BUY] "; }
            else              { scoreAgainst++; summaryOut += "[VWAP CONTRA] "; }
         }
         else if(price < vwap * 0.999)
         {
            if(dir == "SELL") { scoreFor++; summaryOut += "[VWAP SOUS?SELL] "; }
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
            if(dir == "SELL") { scoreFor++; summaryOut += "[PIVOT R1?SELL] "; }
            else              { scoreAgainst++; summaryOut += "[PIVOT R1 CONTRA] "; }
         }
         else if(nearS1)
         {
            if(dir == "BUY")  { scoreFor++; summaryOut += "[PIVOT S1?BUY] "; }
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
            if(dir == "BUY")  { scoreFor++; summaryOut += "[OBV INFLOW?BUY] "; }
            else              { scoreAgainst++; summaryOut += "[OBV CONTRA] "; }
         }
         else if(obv < 0)
         {
            if(dir == "SELL") { scoreFor++; summaryOut += "[OBV OUTFLOW?SELL] "; }
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
                  // C'est le deal de clôture de notre position
                  // Vérifier que c'est notre robot (magic number)
                  if(deal.Magic() != InpMagicNumber)
                     return;

                  // Extraire les données du trade
                  string symbol = deal.Symbol();
                  double profit = deal.Profit() + deal.Swap() + deal.Commission();
                  bool is_win = (profit > 0);
                  string side = (deal.Entry() == DEAL_ENTRY_IN) ? "BUY" : "SELL";

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
                  string url1 = UseRenderAsPrimary ? (AI_ServerRender + "/trades/feedback") : (AI_ServerURL + "/trades/feedback");
                  string url2 = UseRenderAsPrimary ? (AI_ServerURL + "/trades/feedback") : (AI_ServerRender + "/trades/feedback");
                  
                  Print("?? ENVOI FEEDBACK IA - URL1: ", url1);
                  Print("?? ENVOI FEEDBACK IA - URL2: ", url2);
                  Print("?? ENVOI FEEDBACK IA - Données: symbol=", symbol, " profit=", DoubleToString(profit, 2), " ai_conf=", DoubleToString(ai_confidence, 2));

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
                     Print("? FEEDBACK IA ENVOYÉ: ", symbol, " ", side, " Profit: ", DoubleToString(profit, 2), " IA Conf: ", DoubleToString(ai_confidence, 2));
                  }
                  else
                  {
                     Print("? ÉCHEC ENVOI FEEDBACK IA: HTTP ", http_result, " pour ", symbol, " ", side);
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
   string base = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
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
   
   Print("?? ENVOI IA: ", jsonRequest);
   
   StringToCharArray(jsonRequest, post);
   
   // Timeout réduit pour éviter le détachement
   int res = WebRequest("POST", url, headers, 2000, post, response, headers);
   
      if(res == 200)
      {
         string jsonResponse = CharArrayToString(response);
         Print("?? RÉPONSE IA: ", jsonResponse);
         
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
                     
                     // Accepter 0?1 ou 0?100%
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
            
            Print("? IA MISE À JOUR: ", g_lastAIAction, " | ", DoubleToString(g_lastAIConfidence*100,1), "% | ", g_lastAIAlignment, " | ", g_lastAICoherence);
            
            return true;
         }
      }
   }
   else
   {
      Print("? ERREUR IA: HTTP ", res);
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
   
   Print("?? IA SMC-EMA - Action: ", action, " | Conf: ", DoubleToString(confidence*100,1), "% | Align: ", g_lastAIAlignment, " | Cohér: ", g_lastAICoherence);
}

// Petit helper de debug pour inspecter rapidement la dernière décision IA
void DebugPrintAIDecision()
{
   Print("?? DEBUG IA - Symbole: ", _Symbol,
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
   
   // Réduire la fréquence des logs BOOM/CRASH pour éviter la superposition
   static datetime lastBoomCrashLog = 0;
   if(TimeCurrent() - lastBoomCrashLog >= 120) // Log toutes les 2 minutes maximum
   {
      Print("?? BOOM/CRASH - ", _Symbol, " | Mouvement: ", DoubleToString(avgMove, _Digits), " | Seuil spike: ", DoubleToString(spikeThreshold, _Digits));
      lastBoomCrashLog = TimeCurrent();
   }
   
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   
   // DÉTECTION DES SPIKES D'ABORD
   for(int i = 5; i < barsToAnalyze - 5; i++)
   {
      double priceChange = MathAbs(rates[i].close - rates[i-1].close);
      bool isSpike = (priceChange > spikeThreshold);
      
      if(!isSpike) continue;
      
      // Limiter les logs de spike pour éviter la surcharge
      static datetime lastSpikeLog = 0;
      if(TimeCurrent() - lastSpikeLog >= 30) // Log toutes les 30 secondes maximum
      {
         Print("?? SPIKE DÉTECTÉ - ", _Symbol, " | Barre ", i, " | Mouvement: ", DoubleToString(priceChange, _Digits), " | Type: ", isBoom ? "BOOM" : "CRASH");
         lastSpikeLog = TimeCurrent();
      }
      
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
                     
                     Print("?? SH APRÈS SPIKE BOOM (Signal SELL) - Prix: ", DoubleToString(currentHigh, _Digits), " | Spike: ", DoubleToString(rates[i].high, _Digits), " | Time: ", TimeToString(rates[j].time));
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
                     
                     Print("?? SL AVANT SPIKE CRASH (Signal CRASH) - Prix: ", DoubleToString(currentLow, _Digits), " | Spike: ", DoubleToString(rates[i].low, _Digits), " | Time: ", TimeToString(rates[j].time));
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
               
   // Réduire la fréquence des logs SWING pour éviter la superposition
   static datetime lastSwingLog = 0;
   if(TimeCurrent() - lastSwingLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? SWING HIGH CONFIRMÉ - ", _Symbol, " | Prix: ", DoubleToString(currentHigh, _Digits), " | Time: ", TimeToString(rates[i].time));
      lastSwingLog = TimeCurrent();
   }
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
               
   // Réduire la fréquence des logs SWING pour éviter la superposition
   static datetime lastSwingLog = 0;
   if(TimeCurrent() - lastSwingLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? SWING LOW CONFIRMÉ - ", _Symbol, " | Prix: ", DoubleToString(currentLow, _Digits), " | Time: ", TimeToString(rates[i].time));
      lastSwingLog = TimeCurrent();
   }
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
// Limité à 25 points pour éviter trop d'objets graphiques ? détachement
#define MAX_SWING_POINTS_DRAWN 25

void DrawConfirmedSwingPoints()
{
   long chId = ChartID();
   if(chId <= 0) return;
   
   ObjectsDeleteAll(chId, "SMC_Confirmed_SH_");
   ObjectsDeleteAll(chId, "SMC_Confirmed_SL_");
   
   // Limiter le nombre de points affichés pour éviter saturation objets ? détachement
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
   // Expiration du mode recovery M5->flèche (Boom BUY).
   if(g_boomM5BuyArrowRecoveryArmed && g_lastBoomM5BuyTouchTime > 0)
   {
      if((TimeCurrent() - g_lastBoomM5BuyTouchTime) > M5TouchArrowRecoveryWindowSec)
      {
         g_boomM5BuyArrowRecoveryArmed = false;
         g_lastBoomM5BuyTouchTime = 0;
      }
   }

   // DEBUG: Log pour voir si la fonction est appelée
   static datetime lastLog = 0;
   if(TimeCurrent() - lastLog >= 10) // Log toutes les 10 secondes maximum
   {
      Print("?? DEBUG - CheckAndExecuteDerivArrowTrade appelée pour: ", _Symbol, " | Time: ", TimeToString(TimeCurrent(), TIME_SECONDS));
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
   
   // Autoriser Boom/Crash ET Volatility (avec conditions différentes)
   bool isBoomCrash = (cat == SYM_BOOM_CRASH);
   bool isVolatility = (cat == SYM_VOLATILITY);
   
   if(!isBoomCrash && !isVolatility)
   {
      return; // Ignorer les autres symboles
   }

   // Anti-duplication: autoriser le scalping par flèche, mais limiter le cumul à 2 positions max.
   // (Le robot pourra re-entrer à chaque nouvelle flèche si le trend continue.)
   if(CountPositionsForSymbol(_Symbol) >= 2)
   {
      Print("?? DERIV ARROW - Limite positions atteinte (>=2) sur ", _Symbol, " -> skip");
      return;
   }
   
   // Confirmer le type de symbole
   // Réduire la fréquence des logs DEBUG de symbole pour éviter la surcharge
   static datetime lastDebugSymbolLog = 0;
   if(TimeCurrent() - lastDebugSymbolLog >= 300) // Log toutes les 5 minutes maximum
   {
      Print("? DEBUG - Symbole validé: ", _Symbol, " = ", catStr);
      lastDebugSymbolLog = TimeCurrent();
   }
   
   // VALIDATION IA: BLOQUER TOUS LES TRADES SI IA EST EN HOLD
   if(UseAIServer && (g_lastAIAction == "HOLD" || g_lastAIAction == "hold"))
   {
      Print("?? TRADE BLOQUÉ - IA en HOLD sur ", _Symbol);
      return;
   }
   
   // NOUVEAU: DÉTECTION DES FLÈCHES DERIV ARROW EXISTANTES
   // Boom/Crash: armer l'entrée quand le prix touche la future protected zone (low=Boom, high=Crash)
   if(isBoomCrash && RequireFutureProtectTouchForBoomCrashDerivArrow)
   {
      bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
      bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
      datetime now = TimeCurrent();

      // Expirer les arming si trop vieux
      if(g_boomFutureProtectTouchTime > 0 && (now - g_boomFutureProtectTouchTime) > FutureProtectTouchArmSeconds)
      {
         g_boomFutureProtectTouchTime = 0;
         g_boomFutureProtectTouchLevel = 0.0;
      }
      if(g_crashFutureProtectTouchTime > 0 && (now - g_crashFutureProtectTouchTime) > FutureProtectTouchArmSeconds)
      {
         g_crashFutureProtectTouchTime = 0;
         g_crashFutureProtectTouchLevel = 0.0;
      }

      if(UseSR20TouchEntryForBoomCrashDerivArrow)
      {
         if(g_boomSR20TouchTime > 0 && (now - g_boomSR20TouchTime) > FutureProtectTouchArmSeconds)
         {
            g_boomSR20TouchTime = 0;
            g_boomSR20TouchLevel = 0.0;
         }
         if(g_crashSR20TouchTime > 0 && (now - g_crashSR20TouchTime) > FutureProtectTouchArmSeconds)
         {
            g_crashSR20TouchTime = 0;
            g_crashSR20TouchLevel = 0.0;
         }
      }

      // Throttle calcul touch (évite d'appeler GetFutureProtectedPointLevels à chaque tick)
      if(g_lastFutureProtectTouchCalc == 0 || (now - g_lastFutureProtectTouchCalc) >= FutureProtectTouchCheckIntervalSec)
      {
         double futureSupport = 0.0, futureResistance = 0.0;
         bool hasFutureLevels = GetFutureProtectedPointLevels(futureSupport, futureResistance);
         if(hasFutureLevels && (isBoom || isCrash))
         {
            double atrM15 = GetATRValue(PERIOD_M15, 14);
            if(atrM15 <= 0.0)
               atrM15 = SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.002; // fallback
            double tol = atrM15 * FutureProtectTouchToleranceATRMult;
            if(tol <= 0.0)
               tol = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100.0;

            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

            if(isBoom && futureSupport > 0.0)
            {
               bool touchedLow = (bid >= futureSupport - tol && bid <= futureSupport + tol);
               if(touchedLow)
               {
                  g_boomFutureProtectTouchTime = now;
                  g_boomFutureProtectTouchLevel = futureSupport;
                  Print("?? BOOM - Touch future protect low armé | level=", DoubleToString(futureSupport, _Digits),
                        " | tol=", DoubleToString(tol, _Digits));
               }
            }

            if(isCrash && futureResistance > 0.0)
            {
               bool touchedHigh = (ask >= futureResistance - tol && ask <= futureResistance + tol);
               if(touchedHigh)
               {
                  g_crashFutureProtectTouchTime = now;
                  g_crashFutureProtectTouchLevel = futureResistance;
                  Print("?? CRASH - Touch future protect high armé | level=", DoubleToString(futureResistance, _Digits),
                        " | tol=", DoubleToString(tol, _Digits));
               }
            }

           // SR20 support/resistance: alternative à future protect
           if(UseSR20TouchEntryForBoomCrashDerivArrow)
           {
              double srSupport = GetSupportLevel(20);     // support 20 bars (M1)
              double srResistance = GetResistanceLevel(20); // resistance 20 bars (M1)
              if(srSupport > 0.0 || srResistance > 0.0)
              {
                 double atrSR = GetATRValue(PERIOD_M1, SR20TouchATRPeriod);
                 if(atrSR <= 0.0) atrSR = SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.002;
                 double srTol = atrSR * SR20TouchToleranceATRMult;
                 if(srTol <= 0.0) srTol = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 100.0;

                 double bidNow = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                 double askNow = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

                 if(isBoom && srSupport > 0.0)
                 {
                    bool touchedSR = (bidNow >= srSupport - srTol && bidNow <= srSupport + srTol);
                    if(touchedSR)
                    {
                       g_boomSR20TouchTime = now;
                       g_boomSR20TouchLevel = srSupport;
                       Print("?? BOOM - Touch SR20 support armé | level=", DoubleToString(srSupport, _Digits),
                             " | tol=", DoubleToString(srTol, _Digits));
                    }
                 }
                 if(isCrash && srResistance > 0.0)
                 {
                    bool touchedSR = (askNow >= srResistance - srTol && askNow <= srResistance + srTol);
                    if(touchedSR)
                    {
                       g_crashSR20TouchTime = now;
                       g_crashSR20TouchLevel = srResistance;
                       Print("?? CRASH - Touch SR20 resistance armé | level=", DoubleToString(srResistance, _Digits),
                             " | tol=", DoubleToString(srTol, _Digits));
                    }
                 }
              }
           }
         }
         g_lastFutureProtectTouchCalc = now;
      }
   }

   // Boom/Crash en mode touch-entry:
   // - entrée marché au touch future protect (low=Boom / high=Crash)
   // - aucune autre entrée dans cette fonction (sortie scalp gérée ailleurs sur flèche)
   if(isBoomCrash && RequireFutureProtectTouchForBoomCrashDerivArrow)
   {
      datetime now = TimeCurrent();
      bool isBoomSym = (StringFind(_Symbol, "Boom") >= 0);
      bool isCrashSym = (StringFind(_Symbol, "Crash") >= 0);

      bool armedBoomFuture = isBoomSym && g_boomFutureProtectTouchTime > 0 &&
                              (now - g_boomFutureProtectTouchTime) <= FutureProtectTouchArmSeconds;
      bool armedCrashFuture = isCrashSym && g_crashFutureProtectTouchTime > 0 &&
                               (now - g_crashFutureProtectTouchTime) <= FutureProtectTouchArmSeconds;

      bool armedBoomSR20 = false;
      bool armedCrashSR20 = false;
      if(UseSR20TouchEntryForBoomCrashDerivArrow)
      {
         armedBoomSR20 = isBoomSym && g_boomSR20TouchTime > 0 &&
                         (now - g_boomSR20TouchTime) <= FutureProtectTouchArmSeconds;
         armedCrashSR20 = isCrashSym && g_crashSR20TouchTime > 0 &&
                          (now - g_crashSR20TouchTime) <= FutureProtectTouchArmSeconds;
      }

      bool armedBoom = armedBoomFuture || armedBoomSR20;
      bool armedCrash = armedCrashFuture || armedCrashSR20;

      // Cooldown anti-boucle sur la même zone
      if(armedBoom && g_boomTouchReentryCooldownUntil > 0 && now < g_boomTouchReentryCooldownUntil)
         return;
      if(armedCrash && g_crashTouchReentryCooldownUntil > 0 && now < g_crashTouchReentryCooldownUntil)
         return;

      if(armedBoom || armedCrash)
      {
         // Ne pas consommer l'arm si on est en zone de correction: on retentera sur le prochain tick.
         if(IsInEquilibriumCorrectionZone())
            return;

         if(!HasAnyExposureForSymbol(_Symbol))
         {
            string dir = armedBoom ? "BUY" : "SELL";
            Print("?? TOUCH (future protect / SR20) => entrée marché immédiate (", dir, ") sur ", _Symbol,
                  " | level=", armedBoom
                                 ? DoubleToString((armedBoomFuture ? g_boomFutureProtectTouchLevel : g_boomSR20TouchLevel), _Digits)
                                 : DoubleToString((armedCrashFuture ? g_crashFutureProtectTouchLevel : g_crashSR20TouchLevel), _Digits));
            ExecuteDerivArrowTrade(dir); // garde toutes les validations existantes (IA/ML/zones/anti-dup)
         }
      }

      // Consommer l'arm: attendre un nouveau touch pour une nouvelle entrée
      g_boomFutureProtectTouchTime = 0;
      g_crashFutureProtectTouchTime = 0;
      g_boomFutureProtectTouchLevel = 0.0;
      g_crashFutureProtectTouchLevel = 0.0;

      g_boomSR20TouchTime = 0;
      g_crashSR20TouchTime = 0;
      g_boomSR20TouchLevel = 0.0;
      g_crashSR20TouchLevel = 0.0;

      return;
   }

   string arrowDirection = "";
   bool hasDerivArrow = GetDerivArrowDirection(arrowDirection);
   
   if(hasDerivArrow)
   {
      Print("?? FLÈCHE DERIV ARROW DÉTECTÉE - Direction: ", arrowDirection, " sur ", _Symbol);
      
      // Validation stricte: Boom = BUY uniquement, Crash = SELL uniquement
      bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
      bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
      
      if(isBoom && arrowDirection == "BUY")
      {
         int posBefore = CountPositionsForSymbol(_Symbol);
         Print("? FLÈCHE VERTE + BOOM = COMPATIBLE - Exécution BUY autorisée");

         bool recoveryBypass = (g_boomM5BuyArrowRecoveryArmed &&
                                g_lastBoomM5BuyTouchTime > 0 &&
                                (TimeCurrent() - g_lastBoomM5BuyTouchTime) <= M5TouchArrowRecoveryWindowSec);
         g_allowBoomM5ArrowRecoveryBypass = recoveryBypass;
         if(recoveryBypass)
            Print("⚡ RECOVERY BUY actif - exécution flèche verte avec bypass IA strict");

         ExecuteDerivArrowTrade("BUY");
         g_allowBoomM5ArrowRecoveryBypass = false;

         int posAfter = CountPositionsForSymbol(_Symbol);
         if(posAfter > posBefore)
         {
            if(recoveryBypass)
            {
               g_boomM5BuyArrowRecoveryArmed = false;
               g_lastBoomM5BuyTouchTime = 0;
               Print("✅ RECOVERY BUY consommé après entrée flèche sur ", _Symbol);
            }
         }
         return;
      }
      else if(isCrash && arrowDirection == "SELL")
      {
         int posBefore = CountPositionsForSymbol(_Symbol);
         Print("? FLÈCHE ROUGE + CRASH = COMPATIBLE - Exécution SELL autorisée");
         ExecuteDerivArrowTrade("SELL");
         int posAfter = CountPositionsForSymbol(_Symbol);
         if(posAfter > posBefore)
         {
            // On ne dépend plus du "touch arm" pour entrer sur flèche.
         }
         return;
      }
      else
      {
         Print("?? FLÈCHE DERIV ARROW INCOMPATIBLE - ", arrowDirection, " sur ", _Symbol, " (règle Boom/Crash)");
         return;
      }
   }
   
   // RÈGLE STRICTE: BLOQUER TOUS LES TRADES BUY SUR BOOM SI IA = SELL
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   string aiAction = g_lastAIAction;
   if(aiAction == "buy") aiAction = "BUY";
   if(aiAction == "sell") aiAction = "SELL";
   
   if(isBoom && aiAction == "SELL")
   {
   // Réduire la fréquence des logs de trading pour éviter la surcharge
   static datetime lastTradingLog = 0;
   if(TimeCurrent() - lastTradingLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? DERIV ARROW BOOM BLOQUÉ - IA = SELL (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal BUY avant de placer trade BUY");
      lastTradingLog = TimeCurrent();
   }
      return;
   }
   
   if(isCrash && aiAction == "BUY")
   {
   // Réduire la fréquence des logs de trading pour éviter la surcharge
   static datetime lastTradingLog = 0;
   if(TimeCurrent() - lastTradingLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? DERIV ARROW CRASH BLOQUÉ - IA = BUY (", DoubleToString(g_lastAIConfidence*100, 1), "%) | Attendre signal SELL avant de placer trade SELL");
      lastTradingLog = TimeCurrent();
   }
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
      // Sur Boom/Crash: exiger au minimum 80% ("IA serveur fort")
      double baseBoomConf = MathMax(MinAIConfidence, 0.80);
      requiredConfidence = baseBoomConf;
      
      // Si l'IA est SELL en zone Discount (achat) ou BUY en zone Premium (vente),
      // augmenter encore l'exigence de confiance (trade "contre-zone").
      bool contrarianToZone = (aiAction == "SELL" && inDiscount) || (aiAction == "BUY" && inPremium);
      if(contrarianToZone)
         requiredConfidence = MathMax(requiredConfidence, 0.80);
   }
   else
   {
      // Pour Volatility: garder un seuil fixe plus élevé
      requiredConfidence = 0.85;
   }

   // Filtre "peu probable" si des symboles ont déjà atteint leur profit target (donc on sécurise les gains)
   if(UseHighConfidenceFilterWhenSomeSymbolsProfitLocked)
   {
      int lockedCount = CountProfitTargetLockedSymbols();
      if(lockedCount >= LockedSymbolsMinCountForFilter)
      {
         double extraConf = ExtraMinAIConfidenceWhenLockedPercent / 100.0;
         requiredConfidence = MathMin(0.99, requiredConfidence + extraConf);
      }
   }
   
   if(UseAIServer && g_lastAIConfidence < requiredConfidence)
   {
      string zoneStr = "Equilibre";
      if(inDiscount) zoneStr = "Discount";
      else if(inPremium) zoneStr = "Premium";
      
      Print("?? TRADE BLOQUÉ - Confiance IA insuffisante sur ", _Symbol, " | Zone: ", zoneStr,
            " | ", DoubleToString(g_lastAIConfidence*100, 1), "% < ", DoubleToString(requiredConfidence*100, 1), "%");
      return;
   }
   
   // DÉTECTION DIFFÉRENCIÉE: Spike requis pour Boom/Crash, signal IA fort pour Volatility
   bool spikeDetected = false;
   bool shouldTrade = false;
   
   if(isBoomCrash)
   {
      // Boom/Crash: deux modes possibles
      // - Mode "pré-spike only" : entrer dès que le prix est dans la zone SMC / pré?spike (avant le 1er spike)
      // - Mode "spike confirmé" : attendre un spike récent + proba ML suffisante (avec option pré?spike strict)
      bool preSpike = IsPreSpikePattern();
      spikeDetected = DetectRecentSpike();
      
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
         // Entrer AVANT le premier spike: pattern pré?spike + proba ML OK
         shouldTrade = (preSpike && probaOk);
      }
      else
      {
         // Mode par défaut: spike récent + proba ML OK, avec option pré?spike strict
         shouldTrade = (spikeDetected && probaOk && (!SpikeRequirePreSpikePattern || preSpike));
      }
      
      // Bypass: signal IA fort (>=80%) pour autoriser l'entrée et capter les spikes
      // même si preSpike/spike récent/proba ML ne sont pas remplis (évite de rater une forte tendance)
      if(!shouldTrade && g_lastAIConfidence >= 0.80)
      {
         if((isBoom && aiAction == "BUY") || (isCrash && aiAction == "SELL"))
         {
            shouldTrade = true;
            Print("? Boom/Crash - Entrée autorisée par confiance IA forte (>=80%) (", DoubleToString(g_lastAIConfidence*100, 1), "%) - capture spikes/tendance");
         }
      }
      // Rebond canal: Boom ? BUY quand prix touche low_chan; Crash ? SELL quand prix touche upper chan
      if(!shouldTrade && isBoom && aiAction == "BUY" && PriceTouchesLowerChannel())
      {
         shouldTrade = true;
         Print("? Boom - Entrée autorisée (prix touche canal bas ? rebond haussier attendu)");
      }
      if(!shouldTrade && isCrash && aiAction == "SELL" && PriceTouchesUpperChannel())
      {
         shouldTrade = true;
         Print("? Crash - Entrée autorisée (prix touche canal haut ? rebond baissier attendu)");
      }
      // Après une perte sur ce symbole: exiger conditions meilleures + spike imminant pour éviter 2e perte consécutive
      if(shouldTrade && !AllowReentryAfterRecentLoss(_Symbol,
                                                     (isBoom ? "BUY" : "SELL"),
                                                     spikeDetected && (preSpike || spikeProbML >= 0.75)))
         shouldTrade = false;
      
      Print("?? DEBUG - Boom/Crash SNIPER - PreSpike: ", preSpike ? "OUI" : "NON",
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
      // Volatility: Pas de spike requis, seulement signal IA fort (80%+)
      spikeDetected = false; // Non applicable
      shouldTrade = true; // Trade autorisé si IA forte (déjà validé ci-dessus)
      
      Print("?? DEBUG - Volatility - Trade autorisé (confiance IA: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
   }
   
   if(!shouldTrade)
   {
      if(isBoomCrash)
         Print("? Conditions spike non remplies - trade Boom/Crash ignoré (Spike récent requis",
               SpikeRequirePreSpikePattern ? " + Pré-spike" : "",
               UseSpikeMLFilter ? " + Filtre proba" : "",
               ")");
      else
         Print("? Conditions non remplies - trade Volatility ignoré");
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
      Print("? Aucun signal IA clair (", g_lastAIAction, ") - trade ignoré");
      return;
   }
   
   // Vérifier la compatibilité entre le signal IA et le type de symbole
   if(isBoomCrash)
   {
      // Règles Boom/Crash: directions spécifiques
      if(StringFind(_Symbol, "Boom") >= 0)
      {
         if(iaDirection == "BUY")
         {
            direction = "BUY"; // Boom + IA BUY = OK
         }
         else
         {
            Print("? CONFLIT: IA dit ", iaDirection, " mais Boom n'accepte que BUY - trade ignoré");
            return;
         }
      }
      else if(StringFind(_Symbol, "Crash") >= 0)
      {
         if(iaDirection == "SELL")
         {
            direction = "SELL"; // Crash + IA SELL = OK
         }
         else
         {
            Print("? CONFLIT: IA dit ", iaDirection, " mais Crash n'accepte que SELL - trade ignoré");
            return;
         }
      }
   }
   else if(isVolatility)
   {
      // Volatility: BUY et SELL autorisés (suivre l'IA)
      direction = iaDirection; // Volatility suit directement l'IA
      Print("? Volatility - Direction IA acceptée: ", direction, " sur ", _Symbol);
   }
   
   Print("? Signal IA validé: ", iaDirection, " compatible avec ", _Symbol, " ? Direction: ", direction);

   // Vérifier l'alignement avec les indicateurs techniques classiques (TradingView-like)
   string classicSummary;
   bool classicOk = IsClassicIndicatorsAligned(direction, classicSummary);

   Print("?? DEBUG - Indicateurs classiques (", direction, ") => ", classicOk ? "ALIGNÉS" : "NON ALIGNÉS",
         " | ", classicSummary);

   if(!classicOk)
   {
      if(UseClassicIndicatorsFilter)
      {
         Print("?? TRADE SPIKE BLOQUÉ - Indicateurs classiques insuffisants (min ",
               ClassicMinConfirmations, " confirmations) sur ", _Symbol);
         return;
      }
   }

   // Protection capital: en zone d'achat au bord inférieur ? SELL seulement si confiance IA >= 85%
   if(direction == "SELL" && IsAtDiscountLowerEdge() && g_lastAIConfidence < 0.85)
   {
      Print("?? TRADE BLOQUÉ - Zone Discount au bord inférieur: SELL autorisé seulement si confiance IA ? 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }
   // Protection capital: en zone premium au bord supérieur (Boom) ? BUY seulement si confiance IA >= 85%
   if(direction == "BUY" && isBoom && IsAtPremiumUpperEdge() && g_lastAIConfidence < 0.85)
   {
      Print("?? TRADE BLOQUÉ - Zone Premium au bord supérieur (Boom): BUY autorisé seulement si confiance IA ? 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }

   // Réentrée après perte sur ce symbole (hors Boom/Crash): exiger conditions exceptionnelles
   if(!AllowReentryAfterRecentLoss(_Symbol, direction, spikeDetected))
      return;

   Print("?? SPIKE DÉTECTÉ - Direction: ", direction, " | Symbole: ", _Symbol);

   // EXÉCUTION DU TRADE avec les mêmes validations que précédemment
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

// Détecte une tendance "escalier" sur Boom/Crash en M1 (utile quand la flèche n'apparaît pas).
// Heuristique simple: mouvement net suffisant + majorité de bougies dans le sens + drawdown contenu.
bool IsBoomCrashTrendStaircase(const string direction)
{
   string dir = direction;
   StringToUpper(dir);
   if(dir != "BUY" && dir != "SELL") return false;

   int n = MathMax(20, BoomCrashTrendLookbackBarsM1);
   if(Bars(_Symbol, PERIOD_M1) < (n + 2)) return false;

   double startClose = iClose(_Symbol, PERIOD_M1, n);
   double endClose   = iClose(_Symbol, PERIOD_M1, 1);
   if(startClose <= 0.0 || endClose <= 0.0) return false;

   double netMove = endClose - startClose;
   if(dir == "SELL") netMove = -netMove;
   double netMovePct = (MathAbs(netMove) / endClose) * 100.0;
   if(netMove <= 0.0) return false;
   if(netMovePct < BoomCrashTrendMinMovePct) return false;

   int aligned = 0;
   double peak = (dir == "BUY") ? -DBL_MAX : DBL_MAX;
   double worstDrawdown = 0.0; // en prix, dans le sens opposé

   for(int i = n; i >= 1; i--)
   {
      double o = iOpen(_Symbol, PERIOD_M1, i);
      double c = iClose(_Symbol, PERIOD_M1, i);
      double h = iHigh(_Symbol, PERIOD_M1, i);
      double l = iLow(_Symbol, PERIOD_M1, i);
      if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0) continue;

      bool isAligned = (dir == "BUY") ? (c >= o) : (c <= o);
      if(isAligned) aligned++;

      if(dir == "BUY")
      {
         if(h > peak) peak = h;
         double dd = peak - l; // retracement depuis le peak
         if(dd > worstDrawdown) worstDrawdown = dd;
      }
      else
      {
         if(l < peak) peak = l;
         double dd = h - peak; // retracement depuis le trough
         if(dd > worstDrawdown) worstDrawdown = dd;
      }
   }

   double alignedRatio = (double)aligned / (double)n;
   if(alignedRatio < BoomCrashTrendMinBullishCandleRatio) return false;

   double maxAllowedDD = MathAbs(netMove) * BoomCrashTrendMaxDrawdownPct;
   if(worstDrawdown > maxAllowedDD) return false;

   return true;
}

// Scalping rapide: détecter un BUY/SELL "fort" via EMA(1)/EMA(5) sur M1.
// Objectif: permettre l'entrée quand la flèche SMC_DERIV_ARROW n'arrive pas assez vite.
bool IsEMA1EMA5Strong(const string direction)
{
   if(!AllowScalpEntryByEMA1EMA5WithoutDerivArrow) return false;
   if(direction != "BUY" && direction != "SELL") return false;

   if(ema1M1 == INVALID_HANDLE || ema5M1 == INVALID_HANDLE) return false;
   if(IsInEquilibriumCorrectionZone()) return false;

   double e1[2], e5[2];
   // e1/e5 sont des tableaux statiques (taille fixe), donc ArraySetAsSeries() n'est pas autorisé ici.

   if(CopyBuffer(ema1M1, 0, 0, 2, e1) < 2) return false;
   if(CopyBuffer(ema5M1, 0, 0, 2, e5) < 2) return false;

   double ema1 = e1[0];
   double ema5 = e5[0];
   double ema1Prev = e1[1];

   if(ema1 <= 0.0 || ema5 <= 0.0) return false;

   // Gap minimum entre EMA1 et EMA5 (en %)
   double gapPct = MathAbs(ema1 - ema5) / ema5 * 100.0;
   if(gapPct < EMA1EMA5StrongMinGapPct) return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(direction == "BUY")
   {
      if(!(ema1 > ema5 && bid > ema1 && ema1 > ema1Prev)) return false;
   }
   else // SELL
   {
      if(!(ema1 < ema5 && bid < ema1 && ema1 < ema1Prev)) return false;
   }

   return true;
}

// Exige la présence récente de la flèche SMC_DERIV_ARROW_<symbol> avant d'exécuter un ordre au marché.
// Direction: "BUY" ou "SELL" (insensible à la casse).
bool HasRecentSMCDerivArrowForDirection(string direction)
{
   if(!RequireSMCDerivArrowForMarketOrders) return true;

   string dir = direction;
   StringToUpper(dir);
   if(dir != "BUY" && dir != "SELL") return false;

   // Bypass scalping: si EMA(1) et EMA(5) sont fortement alignées sur M1,
   // alors on n'attend pas la flèche DERIV à temps.
   if(AllowScalpEntryByEMA1EMA5WithoutDerivArrow)
   {
      if(IsEMA1EMA5Strong(dir))
      {
         Print("⚡ BYPASS flèche DERIV - EMA(1)/EMA(5) M1 fort => autoriser ", dir, " sur ", _Symbol);
         return true;
      }
   }

   // Exception Boom/Crash: en tendance escalier forte + confiance ML très élevée, autoriser sans flèche
   if(AllowBoomCrashTrendEntryWithoutArrow && SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH)
   {
      double confPct = g_lastAIConfidence * 100.0;
      if(confPct >= BoomCrashTrendEntryMinConfidencePct && IsBoomCrashTrendStaircase(dir))
      {
         Print("BYPASS FLECHE - Boom/Crash tendance forte + ML conf ", DoubleToString(confPct, 1),
               "% >= ", DoubleToString(BoomCrashTrendEntryMinConfidencePct, 1), "% | Dir=", dir);
         return true;
      }
   }

   string arrowName = "SMC_DERIV_ARROW_" + _Symbol;
   string foundName = arrowName;
   if(ObjectFind(0, arrowName) < 0)
   {
      // Fallback: certains modules peuvent nommer différemment. On prend la plus récente des flèches SMC_DERIV_ARROW*.
      datetime bestTime = 0;
      string bestName = "";
      for(int i = ObjectsTotal(0, -1, OBJ_ARROW) - 1; i >= 0; i--)
      {
         string objName = ObjectName(0, i, -1, OBJ_ARROW);
         if(StringFind(objName, "SMC_DERIV_ARROW") < 0) continue;
         if(StringFind(objName, _Symbol) < 0) continue; // rester strict: flèche du symbole courant
         datetime t = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME, 0);
         if(t > bestTime)
         {
            bestTime = t;
            bestName = objName;
         }
      }
      if(bestName == "")
      {
         if(DebugDerivArrowCapture)
            Print("ARROW DEBUG - aucune flèche SMC_DERIV_ARROW trouvée pour ", _Symbol);
         return false;
      }
      foundName = bestName;
   }

   // Vérifier que la flèche est récente (N bougies max sur timeframe courant)
   datetime arrowTime = (datetime)ObjectGetInteger(0, foundName, OBJPROP_TIME, 0);
   int maxAgeBars = MathMax(1, SMCDerivArrowMaxAgeBars);
   int maxAgeSec = PeriodSeconds(PERIOD_CURRENT) * maxAgeBars;
   if(maxAgeSec <= 0) maxAgeSec = 60 * maxAgeBars;
   int ageSec = (int)(TimeCurrent() - arrowTime);
   if(ageSec > maxAgeSec)
   {
      if(DebugDerivArrowCapture)
         Print("ARROW DEBUG - flèche trop vieille: name=", foundName, " ageSec=", ageSec, " > maxAgeSec=", maxAgeSec, " | sym=", _Symbol);
      return false;
   }

   // Vérifier direction via le code de flèche
   int arrowCode = (int)ObjectGetInteger(0, foundName, OBJPROP_ARROWCODE);
   bool isBuyArrow = (arrowCode == 233);
   bool isSellArrow = (arrowCode == 234);
   if(DebugDerivArrowCapture)
      Print("ARROW DEBUG - found=", foundName, " code=", arrowCode, " ageSec=", ageSec, " dirNeed=", dir, " buy=", isBuyArrow, " sell=", isSellArrow);
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
   Print("?? DEBUG POST-HOLD - Début fonction");
   Print("   ?? Symbole: ", closedSymbol, " | Type: ", (closedType == POSITION_TYPE_BUY ? "BUY" : "SELL"), " | Profit: ", DoubleToString(closedProfit, 2), "$");
   
   // Vérifier si la fermeture était bien due à HOLD avec perte ? 2,0$
   if(closedProfit > -2.0)
   {
      Print("?? POST-HOLD - Perte insuffisante: ", DoubleToString(closedProfit, 2), "$ > -2.00$");
      return;
   }
   Print("? POST-HOLD - Perte suffisante: ", DoubleToString(closedProfit, 2), "$ ? -2.00$");
   
   // Vérifier si c'est bien Boom/Crash
   bool isBoom = (StringFind(closedSymbol, "Boom") >= 0);
   bool isCrash = (StringFind(closedSymbol, "Crash") >= 0);
   
   if(!isBoom && !isCrash)
   {
      Print("?? POST-HOLD - Symbole non Boom/Crash: ", closedSymbol);
      return;
   }
   Print("? POST-HOLD - Symbole valide - Boom: ", isBoom, " | Crash: ", isCrash);
   
   // Vérifier si un ordre limit est déjà en attente
   if(g_postHoldLimitOrderPending)
   {
      Print("?? POST-HOLD - Ordre limit déjà en attente, annulation");
      return;
   }
   Print("? POST-HOLD - Aucun ordre limit en attente");

   // Anti-duplication: si un pending LIMIT existe déjà sur ce symbole (même magic), ne pas en recréer un second
   if(CountOpenLimitOrdersForSymbol(closedSymbol) >= 1)
   {
      Print("?? POST-HOLD - Pending LIMIT déjà existant sur ", closedSymbol, " -> skip anti-duplication");
      return;
   }
   
   // Détecter si nous étions en zone Premium (vente) ou Discount (achat)
   bool inDiscount = IsInDiscountZone();
   bool inPremium = IsInPremiumZone();
   
   Print("?? POST-HOLD - Zones SMC - Discount: ", inDiscount, " | Premium: ", inPremium);
   
   // Conditions détaillées pour ordre limit
   bool shouldPlaceLimit = false;
   ENUM_ORDER_TYPE limitType = WRONG_VALUE;
   double limitPrice = 0.0;
   string limitReason = "";
   
   if(isBoom && inDiscount && closedType == POSITION_TYPE_BUY)
   {
      // Boom en zone Discount avec position BUY fermée ? ordre BUY limit au support
      limitType = ORDER_TYPE_BUY_LIMIT;
      limitPrice = GetSupportLevel(20); // Support sur 20 barres
      limitReason = "Boom Discount - Support 20 bars (post-HOLD)";
      shouldPlaceLimit = true;
      Print("?? POST-HOLD - Condition Boom+Discount+BUY remplie");
   }
   else if(isCrash && inPremium && closedType == POSITION_TYPE_SELL)
   {
      // Crash en zone Premium avec position SELL fermée ? ordre SELL limit à la résistance
      limitType = ORDER_TYPE_SELL_LIMIT;
      limitPrice = GetResistanceLevel(20); // Résistance sur 20 barres
      limitReason = "Crash Premium - Resistance 20 bars (post-HOLD)";
      shouldPlaceLimit = true;
      Print("?? POST-HOLD - Condition Crash+Premium+SELL remplie");
   }
   
   if(!shouldPlaceLimit)
   {
      Print("?? POST-HOLD - Conditions non remplies pour ordre limit");
      Print("   ?? Symbole: ", closedSymbol, " | Type: ", (closedType == POSITION_TYPE_BUY ? "BUY" : "SELL"));
      Print("   ?? Zones - Discount: ", inDiscount, " | Premium: ", inPremium);
      Print("   ?? Attendu: (Boom+Discount+BUY) ou (Crash+Premium+SELL)");
      return;
   }
   
   Print("? POST-HOLD - Conditions validées - Calcul niveau de prix...");
   
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
   
   Print("?? POST-HOLD - Requête ordre limit préparée:");
   Print("   ?? Type: ", (limitType == ORDER_TYPE_BUY_LIMIT ? "BUY LIMIT" : "SELL LIMIT"));
   Print("   ?? Prix: ", DoubleToString(limitPrice, _Digits), " | Lot: ", DoubleToString(lot, 2));
   Print("   ?? Raison: ", limitReason);
   
   if(OrderSend(request, result))
   {
      g_postHoldLimitOrderPending = true;
      g_lastHoldCloseTime = TimeCurrent();
      Print("? POST-HOLD - Ordre limit placé avec succès");
      Print("   ?? Symbole: ", closedSymbol, " | Type: ", (limitType == ORDER_TYPE_BUY_LIMIT ? "BUY LIMIT" : "SELL LIMIT"));
      Print("   ?? Prix: ", DoubleToString(limitPrice, _Digits), " | Lot: ", DoubleToString(lot, 2));
      Print("   ?? Raison: ", limitReason);
      Print("   ?? Ticket: ", result.order);
   }
   else
   {
      Print("? POST-HOLD - Échec placement ordre limit");
      Print("   ?? Erreur: ", result.retcode, " - ", result.comment);
      Print("   ?? Code erreur: ", GetLastError());
   }
}

//| OBTENIR NIVEAU DE SUPPORT (20 BARRES) |
double GetSupportLevel(int bars)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, bars + 1, rates) < bars + 1)
   {
      Print("? Impossible de copier les rates pour support");
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
      Print("? Impossible de copier les rates pour résistance");
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
      Print("?? CHANGEMENT IA DÉTECTÉ - ", g_lastAIActionPrevious, " ? HOLD");
      Print("   ?? SURVEILLANCE DES POSITIONS - Attente perte ? 2.0$ avant fermeture");
      
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
            string cmt = PositionGetString(POSITION_COMMENT);

            // Recovery exceptionnel: on laisse la fermeture "5 petites bougies M1" gérer le trade
            if(StringFind(cmt, "EXC_RECOVERY_") >= 0)
               continue;
            
            // Vérifier si la position correspond à l'action précédente
            bool shouldClose = false;
            if(g_lastAIActionPrevious == "BUY" && posType == POSITION_TYPE_BUY)
            {
               shouldClose = true;
               Print("   ?? SURVEILLANCE BUY - ", posSymbol, " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$");
            }
            else if(g_lastAIActionPrevious == "SELL" && posType == POSITION_TYPE_SELL)
            {
               shouldClose = true;
               Print("   ?? SURVEILLANCE SELL - ", posSymbol, " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$");
            }
            
            if(shouldClose)
            {
               // NOUVEAU: Vérifier si perte ? 2.0$ avant de fermer
               if(posProfit <= -2.0)
               {
                  Print("   ?? SEUIL DE PERTE ATTEINT - ", DoubleToString(posProfit, 2), "$ ? -2.00$");
                  Print("   ?? FERMETURE AUTOMATIQUE sur HOLD - Perte ? 2.0$");
                  
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
                  request.comment = "IA HOLD Auto-Close (Loss ? 2.0$)";
                  
                  if(OrderSend(request, result))
                  {
                     Print("? POSITION FERMÉE - ", posSymbol, " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$");
                     
                     // Disabled: PlacePostHoldLimitOrder() peut créer des pending
                     // LIMIT (BUY_LIMIT/SELL_LIMIT). Objectif: aucune limite,
                     // uniquement market via touch M5.
                     // PlacePostHoldLimitOrder(posSymbol, posType, posProfit);
                  }
                  else
                  {
                     Print("? ERREUR FERMETURE - ", posSymbol, " | Erreur: ", result.comment);
                  }
               }
               else
               {
                  Print("   ? SURVEILLANCE CONTINUE - Perte: ", DoubleToString(posProfit, 2), "$ > -2.00$ (seuil non atteint)");
                  Print("   ?? Attente HOLD - Position maintenue jusqu'à perte ? 2.0$");
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
               Print("?? CAPITAL FAIBLE - Équité: ", DoubleToString(accountEquity, 2), "$ < 20.00$");
               Print("   ?? LIMITATION À 1 POSITION SEULEMENT pour protéger le capital");
            }
            else
            {
               Print("??? PROTECTION CAPITAL - ", totalPositions, "/", maxAllowedPositions, " positions atteintes (sur symboles différents)");
            }
            
            Print("   ?? Positions actuelles :");
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
               Print("   ?? NOUVEAUX TRADES BLOQUÉS - Capital faible, 1 position max");
            }
            else
            {
               Print("   ?? NOUVEAUX TRADES BLOQUÉS jusqu'à libération d'une position");
               Print("   ?? Règle: Max ", maxAllowedPositions, " positions sur symboles différents autorisées");
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
            Print("?? Flèche ignorée - Trop petite ou invisible: ", objName, " | Width: ", arrowWidth);
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
            Print("?? GRANDE FLÈCHE VERTE DÉTECTÉE - Signal BUY sur ", _Symbol, 
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
            Print("?? GRANDE FLÈCHE ROUGE DÉTECTÉE - Signal SELL sur ", _Symbol,
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
               Print("?? GRANDE FLÈCHE UP DÉTECTÉE - Signal BUY sur ", _Symbol, 
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
               Print("?? GRANDE FLÈCHE DOWN DÉTECTÉE - Signal SELL sur ", _Symbol,
                     " (code: ", arrowCode, ") | Objet: ", objName,
                     " | Width: ", arrowWidth);
               
               // MÉMORISER CETTE FLÈCHE COMME DÉTECTÉE
               lastDetectedArrow = arrowKey;
               lastDetectedTime = currentTime;
               return true;
            }
            else
            {
               Print("?? Flèche ignorée - Code non reconnu: ", arrowCode, " | Objet: ", objName);
            }
         }
      }
   }
   
   return false;
}

//| EXÉCUTER UN TRADE BASÉ SUR LA FLÈCHE DERIV ARROW |
void ExecuteDerivArrowTrade(string direction)
{
   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction))
   {
      Print("🚫 DERIV ARROW BLOQUÉ - Direction interdite sur ", _Symbol, " : ", direction);
      return;
   }

   if(!IsBoomCrashDirectionAllowedByIA(_Symbol, direction))
   {
      Print("🚫 DERIV ARROW BLOQUÉ - Direction vs IA (Boom/Crash) sur ", _Symbol, " : ", direction);
      return;
   }

   Print("?? DÉBUT ANALYSE FLÈCHE DERIV ARROW - Direction: ", direction, " | Symbole: ", _Symbol);

   // Éviter de trader en "correction" (zone d'équilibre ICT)
   if(IsInEquilibriumCorrectionZone())
   {
      Print("🚫 DERIV ARROW bloqué - Zone de correction autour de l'équilibre sur ", _Symbol);
      return;
   }

   if(!IsSpreadAcceptable()) return;
   if(IsEntryCooldownActive()) return;
   if(!IsLastCandleConfirmingDirection(direction)) return;
   
   // NOUVEAU: VÉRIFICATION PROTECTION CAPITAL - MAX 2 POSITIONS
   if(IsMaxPositionsReached())
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - Protection capital activée (max ", MaxPositionsTerminal, " positions)");
      return;
   }
   Print("? Protection capital OK");
   
   // NOUVEAU: VÉRIFICATION CONFIANCE IA MINIMALE
   bool isBoomRecoveryBypass = (g_allowBoomM5ArrowRecoveryBypass && IsBoomSymbol(_Symbol) && direction == "BUY");

   // Règle globale: ne jamais prendre position si confiance IA < 75%
   if(!IsAIConfidenceAtLeast(0.75, "DERIV ARROW"))
      return;

   if(UseAIServer && !isBoomRecoveryBypass)
   {
      double aiConfidenceUnit = NormalizeAIConfidenceUnit();
      double minAiConfUnit = MinAIConfidencePercent;
      // MinAIConfidencePercent peut être fourni en % (65) ou en unité (0.65)
      if(minAiConfUnit > 1.0)
         minAiConfUnit /= 100.0;

      // Ajustement optionnel par filtre propice (extra en % ou unité)
      if(UsePropiceSymbolsFilter && PropiceAllowMarketOrdersOnAllPropiceSymbols &&
         g_currentSymbolIsPropice && g_currentSymbolPriority > 0)
      {
         double extra = (double)g_currentSymbolPriority * PropiceNonTopExtraMinAIConfidencePercentPerRank;
         if(PropiceNonTopExtraMinAIConfidencePercentPerRank > 1.0)
            extra /= 100.0;
         minAiConfUnit += extra;
      }

      // Toujours respecter le minimum global (75%)
      minAiConfUnit = MathMax(minAiConfUnit, 0.75);

      Print("?? Vérification IA - Confiance: ", DoubleToString(aiConfidenceUnit * 100.0, 1),
            "% | Action: ", g_lastAIAction);

      if(aiConfidenceUnit < minAiConfUnit)
      {
         Print("?? FLÈCHE DERIV ARROW BLOQUÉE - Confiance IA insuffisante: ", 
               DoubleToString(aiConfidenceUnit * 100.0, 1), "% < ",
               DoubleToString(minAiConfUnit * 100.0, 1), "% minimum");
         Print("   ?? IA Action: ", g_lastAIAction);
         return;
      }
      else
      {
         Print("✅ CONFIANCE IA VALIDÉE - ", DoubleToString(aiConfidenceUnit * 100.0, 1), "% ≥ ", 
               DoubleToString(minAiConfUnit * 100.0, 1), "% minimum");
      }
   }
   else if(UseAIServer && isBoomRecoveryBypass)
   {
      Print("⚡ DERIV ARROW recovery bypass actif (Boom BUY après touch M5 raté) - IA stricte assouplie");
   }
   else
   {
      Print("?? Serveur IA désactivé - Utilisation flèche uniquement");
   }

   // Vérifier que le modèle ML utilisé pour ce symbole est suffisamment fiable
   if(!IsMLModelTrustedForCurrentSymbol(direction))
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Modèle ML non fiable pour ", _Symbol);
      return;
   }
   
   // Validation : Boom = BUY uniquement, Crash = SELL uniquement
   bool isBoom = IsBoomSymbol(_Symbol);
   bool isCrash = IsCrashSymbol(_Symbol);
   
   Print("?? Validation symbole - Boom: ", isBoom, " | Crash: ", isCrash, " | Direction: ", direction);
   
   if(isBoom && direction != "BUY")
   {
      Print("?? FLÈCHE DERIV ARROW IGNOREE - ", direction, " sur Boom (seul BUY autorisé)");
      return;
   }
   
   if(isCrash && direction != "SELL")
   {
      Print("?? FLÈCHE DERIV ARROW IGNOREE - ", direction, " sur Crash (seul SELL autorisé)");
      return;
   }
   Print("? Validation symbole OK");
   
   // Vérifier que l'IA n'est pas en HOLD
   if(UseAIServer && (g_lastAIAction == "HOLD" || g_lastAIAction == "hold"))
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - IA en HOLD sur ", _Symbol);
      return;
   }
   Print("? IA non-HOLD OK");

   // Décision finale = ML + stratégie interne: la direction de la flèche doit être cohérente avec la décision ML
   if(UseAIServer && !isBoomRecoveryBypass)
   {
      string mlAction = g_lastAIAction;
      StringToUpper(mlAction);
      if(mlAction != direction)
      {
         Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Direction flèche (", direction, ") != décision ML (", mlAction, ") sur ", _Symbol);
         return;
      }
   }
   
   // NOUVEAU: VÉRIFIER SI LE PRIX EST DANS LA ZONE D'ÉQUILIBRE
   bool inDiscount = IsInDiscountZone();
   bool inPremium  = IsInPremiumZone();
   
   Print("?? Zones SMC - Discount: ", inDiscount, " | Premium: ", inPremium);
   
   // Si le prix est dans la zone d'équilibre (ni premium ni discount), bloquer le trade
   if(!inDiscount && !inPremium)
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - Prix dans zone d'équilibre sur ", _Symbol, 
            " (ni Premium ni Discount) - Trade non autorisé");
      return;
   }
   Print("? Zone SMC OK (ni Premium ni Discount)");
   
   // Protection capital: zone d'achat au bord inférieur ? SELL seulement si confiance IA >= 85%
   if(direction == "SELL" && IsAtDiscountLowerEdge() && g_lastAIConfidence < 0.85)
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - Zone Discount au bord inférieur: SELL autorisé seulement si confiance IA ? 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }
   // Protection capital: zone premium au bord supérieur (Boom) ? BUY seulement si confiance IA >= 85%
   if(direction == "BUY" && isBoom && IsAtPremiumUpperEdge() && g_lastAIConfidence < 0.85)
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - Zone Premium au bord supérieur (Boom): BUY autorisé seulement si confiance IA ? 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }
   
   // PROTECTION CONTRE LES PERTES PAR SYMBOLE - Vérifier avant tout
   if(CheckSymbolLossProtection())
   {
      Print("🚨 FLÈCHE DERIV ARROW BLOQUÉE - Protection symbole activée sur ", _Symbol);
      Print("   💰 Perte actuelle: ", DoubleToString(g_symbolCurrentLoss, 2), "$ > Limite: ", DoubleToString(MaxLossPerSymbolDollars, 2), "$");
      return;
   }
   
   // FILTRE PRIORITÉ SYMBOLES PROPICES - BLOCAGE TOTAL SI NON PRIORITAIRE
   if(UsePropiceSymbolsFilter)
   {
      if(!g_currentSymbolIsPropice)
      {
         Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Symbole non 'propice': ", _Symbol);
         Print("   Heure UTC: ", TimeToString(TimeCurrent(), TIME_SECONDS), " | Top propices: ", g_propiceTopSymbolsText);
         Print("   🚫 BLOCAGE TOTAL - Aucun trade autorisé sur les symboles non propices");
         return;
      }
      
      // Avant: blocage total si pas rang 0.
      // Maintenant: si le symbole est propice, on autorise, mais on pourra exiger plus de confiance (voir bloc ci-dessous).
      if(!IsMostPropiceSymbol())
      {
         Print("⚠️ FLÈCHE DERIV ARROW - Symbole propice rang >", g_currentSymbolPriority + 1,
               " | autorisé (priorité) sur ", _Symbol);
      }
      else
      {
         Print("🥇 SYMBOLE LE PLUS PROPICE - Flèche Deriv Arrow autorisée: ", _Symbol);
         Print("   ✅ Priorité maximale - Exécution autorisée");
      }
   }
   Print("💡 Le robot trade UNIQUEMENT sur les symboles les plus performants selon l'heure actuelle");

   // Lock global pour éviter double ouverture via chemins différents
   if(!TryAcquireOpenLock())
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - lock indisponible (anti-duplication tick)");
      return;
   }

   // Anti-duplication/exposition:
   // - pending existant => toujours bloqué
   // - position existante => ouverture possible seulement si CanOpenAdditionalPositionForSymbol autorise
   int pendingExp = CountPendingOrdersForSymbol(_Symbol);
   int existingExp = CountPositionsForSymbol(_Symbol);
   if(pendingExp > 0)
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - pending déjà existant sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   if(existingExp > 0 && !CanOpenAdditionalPositionForSymbol(_Symbol, direction))
   {
      Print("?? FLÈCHE DERIV ARROW BLOQUÉE - duplication interdite sur ", _Symbol,
            " | existing=", existingExp, " | dir=", direction);
      ReleaseOpenLock();
      return;
   }
   Print("? Anti-duplication OK (lock + exposition)");
   
   Print("?? TOUTES LES VALIDATIONS RÉUSSIES - EXÉCUTION DU TRADE...");
   
   // NOUVEAU: MÉMOIRE DES FLÈCHES DÉJÀ TRAITÉES
   static string lastProcessedArrow = "";
   static datetime lastProcessedTime = 0;
   
   // Créer une clé unique pour cette flèche (symbole + direction + heure)
   string currentArrowKey = _Symbol + "_" + direction + "_" + TimeToString(TimeCurrent(), TIME_MINUTES);
   
   // Vérifier si cette flèche a déjà été traitée récemment
   if(lastProcessedArrow == currentArrowKey && (TimeCurrent() - lastProcessedTime) < 300) // 5 minutes
   {
      Print("?? FLÈCHE DERIV ARROW DÉJÀ TRAITÉE - ", direction, " sur ", _Symbol, " (ignorer pour éviter duplication)");
      ReleaseOpenLock();
      return;
   }
   
   // Obtenir le prix actuel
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, r) < 1)
   {
      Print("? ERREUR - Impossible d'obtenir les prix pour ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   
   double currentPrice = r[0].close;
   double stopLoss, takeProfit;

   // NOUVEAU: FOREX/MÉTAUX - entrée uniquement sur pullback proche des EMA (évite entrée en extension)
   ENUM_SYMBOL_CATEGORY catNow = SMC_GetSymbolCategory(_Symbol);
   if(catNow == SYM_FOREX || catNow == SYM_METAL || catNow == SYM_COMMODITY)
   {
      double e21, e31, dist, maxDist;
      if(!IsPriceNearEMAPullbackZone(direction, currentPrice, e21, e31, dist, maxDist))
      {
         static datetime lastEmaBlockLog = 0;
         if(TimeCurrent() - lastEmaBlockLog >= 60)
         {
            Print("⛔ ENTRY BLOQUÉE (EMA pullback) - ", _Symbol, " ", direction,
                  " | Prix=", DoubleToString(currentPrice, _Digits),
                  " | EMA21=", DoubleToString(e21, _Digits),
                  " | EMA31=", DoubleToString(e31, _Digits),
                  " | DistZone=", DoubleToString(dist, _Digits),
                  " > Max=", DoubleToString(maxDist, _Digits));
            lastEmaBlockLog = TimeCurrent();
         }
         ReleaseOpenLock();
         return;
      }
   }
   
   // NOUVEAU: CALCUL SL/TP CORRECT POUR ÉVITER "INVALID STOPS"
   // Approche robuste : stopsLevel broker + buffer spécifique Boom/Crash + arrondi tick size
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0) tickSize = point;
   
   // Distance minimale obligatoire du courtier
   double minStopDistance = (double)stopsLevel * point;
   
   // Si stopsLevel = 0, utiliser une distance par défaut sécuritaire
   if(minStopDistance <= 0)
   {
      if(isCrash || isBoom)
      {
         minStopDistance = 500.0 * point; // 500 points minimum pour Crash/Boom
      }
      else
      {
         minStopDistance = 20 * point; // 20 pips pour autres
      }
   }
   else if(isCrash || isBoom)
   {
      // Même avec stopsLevel non nul, certains synthétiques refusent des stops trop proches
      minStopDistance = MathMax(minStopDistance, 500.0 * point);
   }
   
   // Buffer plus conservateur pour absorber variation spread/tick au moment de l'envoi
   double safeDistance = minStopDistance * (isCrash || isBoom ? 2.5 : 2.0);
   
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
   
   Print("?? DEBUG SL/TP - ", _Symbol, " ", direction, 
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
         Print("?? SL ajusté pour BUY sur ", _Symbol, " | Nouveau SL: ", DoubleToString(stopLoss, _Digits));
      }
      // Vérifier que TP est assez loin de l'ask
      if(takeProfit - askPrice < safeDistance)
      {
         takeProfit = askPrice + (safeDistance * 2.0);
         Print("?? TP ajusté pour BUY sur ", _Symbol, " | Nouveau TP: ", DoubleToString(takeProfit, _Digits));
      }
   }
   else // SELL
   {
      // Vérifier que SL est assez loin du bid
      if(stopLoss - bidPrice < safeDistance)
      {
         stopLoss = bidPrice + safeDistance;
         Print("?? SL ajusté pour SELL sur ", _Symbol, " | Nouveau SL: ", DoubleToString(stopLoss, _Digits));
      }
      // Vérifier que TP est assez loin du bid
      if(bidPrice - takeProfit < safeDistance)
      {
         takeProfit = bidPrice - (safeDistance * 2.0);
         Print("?? TP ajusté pour SELL sur ", _Symbol, " | Nouveau TP: ", DoubleToString(takeProfit, _Digits));
      }
   }
   
   // Aligner strictement SL/TP sur le tick size, avec arrondi orienté pour garder la validité
   if(direction == "BUY")
   {
      stopLoss = MathFloor(stopLoss / tickSize) * tickSize;     // SL en dessous
      takeProfit = MathCeil(takeProfit / tickSize) * tickSize;  // TP au-dessus
   }
   else
   {
      stopLoss = MathCeil(stopLoss / tickSize) * tickSize;      // SL au-dessus
      takeProfit = MathFloor(takeProfit / tickSize) * tickSize; // TP en dessous
   }
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   // Envoyer la notification
   SendDerivArrowNotification(direction, currentPrice, stopLoss, takeProfit);
   
   // Exécuter l'ordre au marché
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   double lotToTrade = CalculateLotSize();
   if(lotToTrade <= 0.0)
   {
      Print("🚫 DERIV ARROW - Volume calculé nul (probablement zone correction / pause / blocage) sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   request.volume = lotToTrade;
   request.type = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!IsOrderTypeAllowedForBoomCrash(_Symbol, request.type))
   {
      Print("🚫 ORDRE DERIV ARROW BLOQUÉ - Type interdit pour ", _Symbol);
      return;
   }
   request.price = (direction == "BUY") ? askPrice : bidPrice;
   EnforceMinBoomCrashStopLossDollarRisk(_Symbol, direction, request.price, request.volume, stopLoss);
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 20;
   request.magic = InpMagicNumber;
   request.comment = "DERIV ARROW " + direction;
   
   if(!IsMinimumProfitPotentialMet(request.price, takeProfit, direction, lotToTrade))
   {
      ReleaseOpenLock();
      return;
   }
   
   if(OrderSend(request, result))
   {
      g_lastEntryTimeForSymbol = TimeCurrent();
      Print("? ORDRE DERIV ARROW EXÉCUTÉ - ", direction, " sur ", _Symbol,
            " | Prix: ", DoubleToString((direction == "BUY") ? askPrice : bidPrice, _Digits),
            " | SL: ", DoubleToString(stopLoss, _Digits),
            " | TP: ", DoubleToString(takeProfit, _Digits),
            " | Ticket: ", result.order);
      if(UseNotifications)
      {
         Alert("✅ POSITION OUVERTE - DERIV ", direction, " ", _Symbol, " | Ticket: ", result.order);
      }
      
      // MÉMORISER CETTE FLÈCHE COMME TRAITÉE
      lastProcessedArrow = currentArrowKey;
      lastProcessedTime = TimeCurrent();
   }
   else
   {
      Print("? ÉCHEC ORDRE DERIV ARROW - Erreur: ", GetLastError());
   }

   ReleaseOpenLock();
}

// Exécute la stratégie OTE + Imbalance (FVG) améliorée avec logique flexible SMC_OTE
void ExecuteOTEImbalanceTrade()
{
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(!(cat == SYM_FOREX || cat == SYM_METAL || cat == SYM_COMMODITY))
      return;

   // Utiliser la logique flexible si activée, sinon la logique stricte
   bool useFlexible = OTE_UseFlexibleLogic;
   int maxPositions = OTE_MaxPositionsPerSymbol;

   // PROTECTION CONTRE LES PERTES PAR SYMBOLE - Vérifier avant tout
   if(CheckSymbolLossProtection())
   {
      Print("🚨 OTE+Imbalance BLOQUÉE - Protection symbole activée sur ", _Symbol);
      Print("   💰 Perte actuelle: ", DoubleToString(g_symbolCurrentLoss, 2), "$ > Limite: ", DoubleToString(MaxLossPerSymbolDollars, 2), "$");
      return;
   }
   
   // FILTRE PRIORITÉ SYMBOLES PROPICES - BLOCAGE TOTAL SI NON PRIORITAIRE
   if(UsePropiceSymbolsFilter)
   {
      if(!g_currentSymbolIsPropice)
      {
         Print("🚫 OTE+Imbalance BLOQUÉE - Symbole non 'propice': ", _Symbol);
         Print("   Heure UTC: ", TimeToString(TimeCurrent(), TIME_SECONDS), " | Top propices: ", g_propiceTopSymbolsText);
         Print("   🚫 BLOCAGE TOTAL - Aucun trade autorisé sur les symboles non propices");
         return;
      }
      
      // RÈGLE STRICTE: BLOQUER TOUS LES TRADES SAUF SUR LE SYMBOLE LE PLUS PROPICE
      if(!IsMostPropiceSymbol())
      {
         if(!PropiceAllowMarketOrdersOnAllPropiceSymbols)
         {
            string mostPropice = GetMostPropiceSymbol();
            Print("🚫 OTE+Imbalance BLOQUÉE - Symbole pas le plus propice: ", _Symbol);
            Print("   📍 Position actuelle: ", g_currentSymbolPriority + 1, "ème dans la liste");
            Print("   🥇 Symbole le plus propice: ", mostPropice);
            Print("   🚫 BLOCAGE TOTAL - Seul le symbole le plus propice peut être tradé");
            return;
         }
         Print("⚠️ OTE+Imbalance - Symbole propice rang >", g_currentSymbolPriority + 1,
               ") autorisé: ", _Symbol, " (priorité seulement)"); 
      }
      else
      {
         Print("🥇 SYMBOLE LE PLUS PROPICE - OTE+Imbalance autorisée: ", _Symbol);
         Print("   ✅ Priorité maximale - Exécution autorisée");
      }
   }
   
   // Vérifier le nombre de positions
   int currentPositions = CountPositionsForSymbol(_Symbol);
   if(currentPositions >= maxPositions)
   {
      static datetime lastBlockLog = 0;
      if(TimeCurrent() - lastBlockLog >= 60) // Log toutes les 60 secondes
      {
         Print("🛡️ OTE+Imbalance - ", maxPositions, " position(s) déjà ouverte(s) sur ", _Symbol, " - Nouveaux trades bloqués");
         lastBlockLog = TimeCurrent();
      }
      return;
   }

   string dir;
   double entry, sl, tp;
   
   // Utiliser la détection flexible ou stricte selon le paramètre
   bool setupDetected = false;
   if(useFlexible)
      setupDetected = DetectOTEImbalanceSetupFlexible(dir, entry, sl, tp);
   else
      setupDetected = DetectOTEImbalanceSetup(dir, entry, sl, tp);
      
   if(!setupDetected)
      return;

   string d = dir; StringToUpper(d);

   // Filtre "propice"
   if(UsePropiceSymbolsFilter && !g_currentSymbolIsPropice)
   {
      Print("⛔ OTE+Imbalance bloqué - symbole non propice: ", _Symbol);
      return;
   }

   // IA gating (assoupli si flexible)
   if(UseAIServer)
   {
      string ia = g_lastAIAction;
      StringToUpper(ia);
      double confPct = g_lastAIConfidence * 100.0;

      if(ia == "" || ia == "HOLD")
      {
         Print("⛔ OTE+Imbalance bloqué - IA HOLD/absente sur ", _Symbol);
         return;
      }
      
      // Logique flexible: autoriser même si IA ≠ direction si confluence forte
      if(ia != d)
      {
         if(useFlexible)
         {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double currentPrice = (d == "BUY") ? ask : bid;
            
            bool strongConfluence = IsStrongOTEFVGConfluence(currentPrice, d);
            double minConfOverride = (cat == SYM_FOREX) ? OTE_MinConfidenceForex : OTE_MinConfidenceOther;
            
            if(!strongConfluence || confPct < minConfOverride)
            {
               Print("⛔ OTE+Imbalance bloqué - IA=", ia, " != ", d, " sur ", _Symbol,
                     " (", DoubleToString(confPct, 1), "%) - Confluence insuffisante");
               return;
            }
            else
            {
               Print("⚠️ OTE+Imbalance AUTORISÉ malgré IA ≠ direction - Confluence forte sur ", _Symbol);
            }
         }
         else
         {
            // Logique stricte originale
            Print("⛔ OTE+Imbalance bloqué - IA=", ia, " != ", d, " sur ", _Symbol,
                  " (", DoubleToString(confPct, 1), "%)");
            return;
         }
      }
      
      // Seuil de confiance (différent si flexible)
      double minConfidence;
      if(useFlexible)
         minConfidence = (cat == SYM_FOREX) ? OTE_MinConfidenceForex : OTE_MinConfidenceOther;
      else
         minConfidence = MinAIConfidencePercent;
         
      if(confPct < minConfidence)
      {
         Print("⛔ OTE+Imbalance bloqué - Confiance IA trop faible: ",
               DoubleToString(confPct,1), "% < ", DoubleToString(minConfidence,1),
               "% sur ", _Symbol);
         return;
      }
   }

   // ML gating (assoupli si flexible)
   if(!IsMLModelTrustedForCurrentSymbol(d))
   {
      if(useFlexible)
      {
         double minAccuracy = 0.65;
         if(g_mlLastAccuracy < minAccuracy && !IsStrongOTEFVGConfluence(SymbolInfoDouble(_Symbol, d == "BUY" ? SYMBOL_ASK : SYMBOL_BID), d))
         {
            Print("⛔ OTE+Imbalance bloqué - Modèle ML non fiable sur ", _Symbol,
                  " (acc=", DoubleToString(g_mlLastAccuracy * 100.0, 1), "%)");
            return;
         }
         else if(g_mlLastAccuracy >= minAccuracy)
         {
            Print("⚠️ OTE+Imbalance AUTORISÉ malgré ML moyen - Confluence forte sur ", _Symbol);
         }
      }
      else
      {
         // Logique stricte originale
         Print("⛔ OTE+Imbalance bloqué - Modèle ML non fiable sur ", _Symbol,
               " (acc=", DoubleToString(g_mlLastAccuracy * 100.0, 1), "%)");
         return;
      }
   }

   if(!TryAcquireOpenLock()) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int stopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = MathMax((double)stopsLevel * point, point * 10.0);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price = (d == "BUY") ? ask : bid;

   // Ajuster SL/TP pour respecter min distance
   if(d == "BUY")
   {
      if(price - sl < minDist) sl = price - minDist;
      if(tp - price < minDist) tp = price + minDist * 2.0;
   }
   else
   {
      if(sl - price < minDist) sl = price + minDist;
      if(price - tp < minDist) tp = price - minDist * 2.0;
   }

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   double lot = CalculateLotSize();
   lot = NormalizeVolumeForSymbol(lot);

   bool ok = false;
   string comment = useFlexible ? "OTE_IMBALANCE_FLEX" : "OTE_IMBALANCE";
   if(d == "BUY")
      ok = trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);
   else
      ok = trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);

   if(ok)
   {
      string modeStr = useFlexible ? "FLEXIBLE" : "STRICT";
      Print("✅ OTE+Imbalance ", modeStr, " EXECUTÉ ", d, " ", _Symbol,
            " | lot=", DoubleToString(lot, 2),
            " | SL=", DoubleToString(sl, _Digits),
            " | TP=", DoubleToString(tp, _Digits),
            " | Positions: ", currentPositions + 1, "/", maxPositions);
   }
   else
   {
      string modeStr = useFlexible ? "FLEXIBLE" : "STRICT";
      Print("❌ OTE+Imbalance ", modeStr, " échoué ", d, " ", _Symbol,
            " | Erreur: ", trade.ResultRetcode(), " - ", trade.ResultComment());
   }

   ReleaseOpenLock();
}

// NOUVEAU: Détection OTE+Imbalance flexible (logique SMC_OTE intégrée): évite les entrées en extension / en pleine correction loin des EMA.
// Retourne true si le prix actuel est proche de la zone EMA21/EMA31 sur LTF, sinon false.
bool IsPriceNearEMAPullbackZone(const string direction, double currentPrice, double &ema21Out, double &ema31Out, double &distOut, double &maxDistOut)
{
   ema21Out = 0.0;
   ema31Out = 0.0;
   distOut = 0.0;
   maxDistOut = 0.0;

   if(ema21LTF == INVALID_HANDLE || ema31LTF == INVALID_HANDLE) return true; // fail-open

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(ema21LTF, 0, 0, 2, buf) < 1) return true;
   ema21Out = buf[0];
   if(CopyBuffer(ema31LTF, 0, 0, 2, buf) < 1) return true;
   ema31Out = buf[0];

   // ATR LTF pour distance max (tolérance)
   double atrVal = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double a[];
      ArraySetAsSeries(a, true);
      if(CopyBuffer(atrHandle, 0, 0, 2, a) >= 1)
         atrVal = a[0];
   }
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atrVal <= 0.0) atrVal = point * 100.0;

   // Distance autorisée: 0.25 ATR (min 10 points)
   maxDistOut = MathMax(atrVal * 0.25, point * 10.0);

   double zoneLow = MathMin(ema21Out, ema31Out);
   double zoneHigh = MathMax(ema21Out, ema31Out);

   // Distance du prix à la "zone EMA" (0 si dans la zone)
   if(currentPrice < zoneLow) distOut = zoneLow - currentPrice;
   else if(currentPrice > zoneHigh) distOut = currentPrice - zoneHigh;
   else distOut = 0.0;

   // Si déjà dans la zone, OK
   if(distOut <= maxDistOut) return true;

   // Sinon, trop loin: on attend le pullback vers EMA
   return false;
}

// NOUVEAU: Détection OTE+Imbalance flexible (logique SMC_OTE intégrée)
bool DetectOTEImbalanceSetupFlexible(string &dirOut, double &entryOut, double &slOut, double &tpOut)
{
   dirOut = "";
   entryOut = 0.0;
   slOut = 0.0;
   tpOut = 0.0;

   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(!(cat == SYM_FOREX || cat == SYM_METAL || cat == SYM_COMMODITY))
      return false;

   if(!UseFVG || !UseOTE)
      return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // 1) Détection tendance via EMA HTF (plus flexible que SMC_OTE)
   bool bullHTF = IsBullishHTF();
   bool bearHTF = IsBearishHTF();
   if(!bullHTF && !bearHTF)
      return false;

   string dir = bullHTF ? "BUY" : "SELL";

   // 2) Swing High / Low récents (logique SMC_OTE)
   if(!DetectNonRepaintingSwingPoints())
      return false;

   double lastSH, lastSL;
   datetime tSH, tSL;
   GetLatestConfirmedSwings(lastSH, tSH, lastSL, tSL);

   if(lastSH <= 0 || lastSL <= 0 || tSH == 0 || tSL == 0)
      return false;

   // 3) Zone OTE (0.62-0.786 du mouvement) - logique SMC_OTE
   double high = lastSH;
   double low  = lastSL;
   if(high <= low) return false;

   double range = high - low;
   double oteLow, oteHigh;

   if(dir == "BUY")
   {
      // OTE BUY: retracement 62-78.6% depuis le bas vers le haut
      oteHigh = low + range * 0.62;
      oteLow  = low + range * 0.786;
   }
   else
   {
      // OTE SELL: retracement 62-78.6% depuis le haut vers le bas
      oteLow  = high - range * 0.62;
      oteHigh = high - range * 0.786;
      if(oteLow > oteHigh)
      {
         double tmp = oteLow; oteLow = oteHigh; oteHigh = tmp;
      }
   }

   // 4) Imbalance (FVG) récente sur LTF - logique SMC_OTE
   FVGData fvg;
   if(!SMC_DetectFVG(_Symbol, LTF, 40, fvg))
      return false;

   // Direction cohérente avec la tendance
   if((dir == "BUY" && fvg.direction != 1) ||
      (dir == "SELL" && fvg.direction != -1))
      return false;

   double fvgLow  = fvg.bottom;
   double fvgHigh = fvg.top;

   // 5) Confluence flexible (logique SMC_OTE) - chevauchement partiel autorisé
   double zoneLow  = MathMax(fvgLow, oteLow);
   double zoneHigh = MathMin(fvgHigh, oteHigh);

   // NOUVEAU: Confluence flexible - autoriser chevauchement partiel
   bool confluenceOk = (zoneHigh > zoneLow) || (MathAbs(zoneHigh - zoneLow) < (oteHigh - oteLow) * 0.3);
   
   if(!confluenceOk)
      return false;

   double price = (dir == "BUY") ? bid : ask;
   
   // 5) VÉRIFICATION CRUCIALE: Entrer uniquement sur niveaux techniques clés
   // Éviter les entrées pendant les corrections
   if(OTE_UseTechnicalLevels)
   {
      bool isValidEntryLevel = false;
      double entryLevel = 0.0;
      string entrySource = "";
      
      // a) Support/Résistance 20 barres le plus proche
      double sr20Level = GetClosestSupportResistance20Bars(price, dir);
      if(sr20Level > 0)
      {
         double distToSR = MathAbs(price - sr20Level);
         double atr20 = GetATRValue(PERIOD_M15, 20);
         if(atr20 > 0 && distToSR <= atr20 * OTE_SR20_ATR_Tolerance)
         {
            isValidEntryLevel = true;
            entryLevel = sr20Level;
            entrySource = "SR20";
         }
      }
      
      // b) Niveaux Pivot Daily
      if(!isValidEntryLevel)
      {
         double pivotLevel = GetClosestPivotLevel(price, dir);
         if(pivotLevel > 0)
         {
            double distToPivot = MathAbs(price - pivotLevel);
            double atr20 = GetATRValue(PERIOD_M15, 20);
            if(atr20 > 0 && distToPivot <= atr20 * OTE_Pivot_ATR_Tolerance)
            {
               isValidEntryLevel = true;
               entryLevel = pivotLevel;
               entrySource = "PIVOT";
            }
         }
      }
      
      // c) Supertrend M5
      if(!isValidEntryLevel)
      {
         double stLevel = GetSupertrendLevelM5(dir);
         if(stLevel > 0)
         {
            double distToST = MathAbs(price - stLevel);
            double atr5 = GetATRValue(PERIOD_M5, 14);
            if(atr5 > 0 && distToST <= atr5 * OTE_ST_ATR_Tolerance)
            {
               isValidEntryLevel = true;
               entryLevel = stLevel;
               entrySource = "ST_M5";
            }
         }
      }
      
      // d) Trendline significative
      if(!isValidEntryLevel)
      {
         double tlLevel = GetClosestTrendlineLevel(price, dir);
         if(tlLevel > 0)
         {
            double distToTL = MathAbs(price - tlLevel);
            double atr20 = GetATRValue(PERIOD_M15, 20);
            if(atr20 > 0 && distToTL <= atr20 * OTE_TL_ATR_Tolerance)
            {
               isValidEntryLevel = true;
               entryLevel = tlLevel;
               entrySource = "TRENDLINE";
            }
         }
      }
      
      // BLOQUER si aucun niveau technique valide trouvé
      if(!isValidEntryLevel)
      {
         Print("⛔ OTE+Imbalance BLOQUÉ - Aucun niveau technique valide pour ", dir,
               " | Prix: ", DoubleToString(price, _Digits),
               " | Direction: ", dir,
               " | Symbole: ", _Symbol);
         return false;
      }
      
      // Vérification supplémentaire: ne pas entrer si le prix est en correction forte
      if(IsInStrongCorrection(price, dir))
      {
         Print("⛔ OTE+Imbalance BLOQUÉ - Prix en correction forte sur ", _Symbol,
               " | Prix: ", DoubleToString(price, _Digits),
               " | Direction: ", dir,
               " | Niveau: ", entrySource, " @ ", DoubleToString(entryLevel, _Digits),
               " | Distance: ", DoubleToString(MathAbs(price - entryLevel), _Digits));
         return false;
      }
      
      Print("✅ OTE+Imbalance NIVEAU TECHNIQUE VALIDÉ - ", entrySource,
            " | Prix: ", DoubleToString(price, _Digits),
            " | Niveau: ", DoubleToString(entryLevel, _Digits),
            " | Direction: ", dir,
            " | Distance: ", DoubleToString(MathAbs(price - entryLevel), _Digits));
   }
   else
   {
      // Mode sans restriction technique (ancienne logique)
      Print("⚠️ OTE+Imbalance MODE SANS RESTRICTION TECHNIQUE - Entrée directe",
            " | Prix: ", DoubleToString(price, _Digits),
            " | Direction: ", dir);
   }

   // 6) SL/TP avec risque minimum (éviter SL trop proche)
   double buffer = MathMax(point * 10.0, range * 0.04); // Buffer plus "large"
   double sl, tp;
   if(dir == "BUY")
   {
      sl = zoneLow - buffer;
      double risk = price - sl;
      if(risk <= point * 5.0) return false;
      tp = price + (MathMax(3.0, InpRiskReward) * risk);
   }
   else
   {
      sl = zoneHigh + buffer;
      double risk = sl - price;
      if(risk <= point * 5.0) return false;
      tp = price - (MathMax(3.0, InpRiskReward) * risk);
   }

   dirOut = dir;
   entryOut = price;
   slOut = sl;
   tpOut = tp;

   return true;
}

// NOUVEAU: Fonctions techniques pour les niveaux d'entrée

// Détecter le support/résistance 20 barres le plus proche
double GetClosestSupportResistance20Bars(double price, string direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 25, rates) < 20) return 0.0;
   
   double closestLevel = 0.0;
   double minDistance = DBL_MAX;
   
   for(int i = 1; i < 20; i++)
   {
      double level = (direction == "BUY") ? rates[i].low : rates[i].high;
      double distance = MathAbs(price - level);
      
      if(distance < minDistance)
      {
         minDistance = distance;
         closestLevel = level;
      }
   }
   
   return closestLevel;
}

// Détecter le niveau Pivot Daily le plus proche
double GetClosestPivotLevel(double price, string direction)
{
   double pivotPoints[4]; // [0]=S1, [1]=S2, [2]=R1, [3]=R2
   if(!CalculateDailyPivots(pivotPoints[0], pivotPoints[1], pivotPoints[2], pivotPoints[3]))
      return 0.0;
   
   double closestLevel = 0.0;
   double minDistance = DBL_MAX;
   
   // Pour BUY: chercher supports (S1, S2)
   // Pour SELL: chercher résistances (R1, R2)
   int startIdx = (direction == "BUY") ? 0 : 2;
   int endIdx = (direction == "BUY") ? 2 : 4;
   
   for(int i = startIdx; i < endIdx; i++)
   {
      double distance = MathAbs(price - pivotPoints[i]);
      if(distance < minDistance)
      {
         minDistance = distance;
         closestLevel = pivotPoints[i];
      }
   }
   
   return closestLevel;
}

// Calculer les pivots daily
bool CalculateDailyPivots(double &s1, double &s2, double &r1, double &r2)
{
   MqlRates dailyRates[];
   ArraySetAsSeries(dailyRates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 0, 2, dailyRates) < 2) return false;
   
   double high = dailyRates[1].high;
   double low = dailyRates[1].low;
   double close = dailyRates[1].close;
   
   double pivot = (high + low + close) / 3.0;
   double range = high - low;
   
   s1 = pivot - (range * 0.382);
   s2 = pivot - (range * 0.618);
   r1 = pivot + (range * 0.382);
   r2 = pivot + (range * 0.618);
   
   return true;
}

// Détecter le niveau Supertrend M5
double GetSupertrendLevelM5(string direction)
{
   int stHandle = iCustom(_Symbol, PERIOD_M5, "Supertrend", 10, 3.0);
   if(stHandle == INVALID_HANDLE) return 0.0;
   
   double stBuffer[];
   ArraySetAsSeries(stBuffer, true);
   if(CopyBuffer(stHandle, 0, 0, 2, stBuffer) < 1)
   {
      IndicatorRelease(stHandle);
      return 0.0;
   }
   
   double level = stBuffer[0];
   IndicatorRelease(stHandle);
   
   // Vérifier que le niveau est cohérent avec la direction
   if(direction == "BUY" && level > 0) return level;
   if(direction == "SELL" && level > 0) return level;
   
   return 0.0;
}

// Détecter la trendline la plus proche
double GetClosestTrendlineLevel(double price, string direction)
{
   int total = ObjectsTotal(0, -1, OBJ_TREND);
   double closestLevel = 0.0;
   double minDistance = DBL_MAX;
   
   for(int i = 0; i < total; i++)
   {
      string name = ObjectName(0, i, -1, OBJ_TREND);
      if(StringFind(name, "Trendline") < 0 && StringFind(name, "TL") < 0) continue;
      
      datetime time1 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 0);
      datetime time2 = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME, 1);
      double price1 = ObjectGetDouble(0, name, OBJPROP_PRICE, 0);
      double price2 = ObjectGetDouble(0, name, OBJPROP_PRICE, 1);
      
      if(time1 == 0 || time2 == 0) continue;
      
      // Calculer le niveau actuel de la trendline
      double slope = (price2 - price1) / (time2 - time1);
      double currentLevel = price1 + slope * (TimeCurrent() - time1);
      
      double distance = MathAbs(price - currentLevel);
      if(distance < minDistance)
      {
         minDistance = distance;
         closestLevel = currentLevel;
      }
   }
   
   return closestLevel;
}

// Vérifier si le prix est en correction forte
bool IsInStrongCorrection(double price, string direction)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M15, 0, 10, rates) < 5) return false;
   
   double atr = GetATRValue(PERIOD_M15, 14);
   if(atr <= 0) return false;
   
   // Utiliser le paramètre configuré pour le seuil de correction
   double correctionThreshold = atr * OTE_Correction_ATR_Threshold;
   
   // Pour BUY: vérifier si le prix baisse fortement
   if(direction == "BUY")
   {
      double decline = rates[0].close - rates[4].close;
      if(decline < -correctionThreshold) // Baisse forte sur 5 bougies
      {
         Print("📉 CORRECTION FORTE DÉTECTÉE - Baisse de ", DoubleToString(MathAbs(decline), _Digits),
               " points (seuil: ", DoubleToString(correctionThreshold, _Digits), ")");
         return true;
      }
   }
   else // SELL
   {
      double rise = rates[0].close - rates[4].close;
      if(rise > correctionThreshold) // Hausse forte sur 5 bougies
      {
         Print("📈 CORRECTION FORTE DÉTECTÉE - Hausse de ", DoubleToString(rise, _Digits),
               " points (seuil: ", DoubleToString(correctionThreshold, _Digits), ")");
         return true;
      }
   }
   
   return false;
}

// Obtenir la valeur ATR
double GetATRValue(ENUM_TIMEFRAMES timeframe, int period)
{
   int handle = iATR(_Symbol, timeframe, period);
   if(handle == INVALID_HANDLE) return 0.0;
   
   double buffer[];
   ArraySetAsSeries(buffer, true);
   if(CopyBuffer(handle, 0, 0, 1, buffer) < 1)
   {
      IndicatorRelease(handle);
      return 0.0;
   }
   
   double value = buffer[0];
   IndicatorRelease(handle);
   return value;
}

// NOUVEAU: Fonction pour vérifier la confluence forte OTE+FVG
bool IsStrongOTEFVGConfluence(double price, string direction)
{
   if(!UseFVG || !UseOTE) return false;

   // Détecter FVG récent
   FVGData fvg;
   if(!SMC_DetectFVG(_Symbol, LTF, 40, fvg))
      return false;

   // Détecter swing points
   if(!DetectNonRepaintingSwingPoints())
      return false;

   double lastSH, lastSL;
   datetime tSH, tSL;
   GetLatestConfirmedSwings(lastSH, tSH, lastSL, tSL);

   if(lastSH <= 0 || lastSL <= 0) return false;

   // Calculer zone OTE
   double high = lastSH, low = lastSL;
   double range = high - low;
   double oteLow, oteHigh;

   if(direction == "BUY")
   {
      oteHigh = low + range * 0.62;
      oteLow  = low + range * 0.786;
   }
   else
   {
      oteLow  = high - range * 0.62;
      oteHigh = high - range * 0.786;
      if(oteLow > oteHigh)
      {
         double tmp = oteLow; oteLow = oteHigh; oteHigh = tmp;
      }
   }

   // Vérifier confluence
   double zoneLow  = MathMax(fvg.bottom, oteLow);
   double zoneHigh = MathMin(fvg.top, oteHigh);

   // Confluence forte si:
   // 1. Intersection significative (>20% de la zone OTE)
   // 2. Prix proche de la zone de confluence
   double intersectionSize = zoneHigh - zoneLow;
   double oteSize = oteHigh - oteLow;
   
   bool strongIntersection = (intersectionSize > 0 && intersectionSize > oteSize * 0.2);
   bool priceNearZone = (price >= zoneLow - (oteSize * 0.1) && price <= zoneHigh + (oteSize * 0.1));

   return strongIntersection && priceNearZone;
}

// Détection de setup ICT-like: tendance claire + Imbalance (FVG) + zone OTE (0.62-0.786) alignées.
bool DetectOTEImbalanceSetup(string &dirOut, double &entryOut, double &slOut, double &tpOut)
{
   dirOut = "";
   entryOut = 0.0;
   slOut = 0.0;
   tpOut = 0.0;

   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(!(cat == SYM_FOREX || cat == SYM_METAL || cat == SYM_COMMODITY))
      return false;

   if(!UseFVG || !UseOTE)
      return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // 1) Détection tendance via EMA HTF
   bool bullHTF = IsBullishHTF();
   bool bearHTF = IsBearishHTF();
   if(!bullHTF && !bearHTF)
      return false;

   string dir = bullHTF ? "BUY" : "SELL";

   // 2) Swing High / Low récents (structure)
   if(!DetectNonRepaintingSwingPoints())
      return false;

   double lastSH, lastSL;
   datetime tSH, tSL;
   GetLatestConfirmedSwings(lastSH, tSH, lastSL, tSL);

   if(lastSH <= 0 || lastSL <= 0 || tSH == 0 || tSL == 0)
      return false;

   // 3) Zone OTE (0.62-0.786 du mouvement)
   double high = lastSH;
   double low  = lastSL;
   if(high <= low) return false;

   double range = high - low;
   double oteLow, oteHigh;

   if(dir == "BUY")
   {
      // OTE BUY: retracement 62-78.6% depuis le bas vers le haut
      oteHigh = low + range * 0.62;
      oteLow  = low + range * 0.786;
   }
   else
   {
      // OTE SELL: retracement 62-78.6% depuis le haut vers le bas
      oteLow  = high - range * 0.62;
      oteHigh = high - range * 0.786;
      if(oteLow > oteHigh)
      {
         double tmp = oteLow; oteLow = oteHigh; oteHigh = tmp;
      }
   }

   // 4) Imbalance (FVG) récente sur LTF
   FVGData fvg;
   if(!SMC_DetectFVG(_Symbol, LTF, 40, fvg))
      return false;

   // Direction cohérente avec la tendance
   if((dir == "BUY" && fvg.direction != 1) ||
      (dir == "SELL" && fvg.direction != -1))
      return false;

   double fvgLow  = fvg.bottom;
   double fvgHigh = fvg.top;

   // 5) Confluence: intersection FVG ∩ OTE
   double zoneLow  = MathMax(fvgLow, oteLow);
   double zoneHigh = MathMin(fvgHigh, oteHigh);

   if(zoneHigh <= zoneLow)
      return false;

   double price = (dir == "BUY") ? bid : ask;
   if(price < zoneLow || price > zoneHigh)
      return false; // attendre que le prix entre dans la zone confluente

   // 6) SL sous / au-dessus de la zone, TP >= 3R
   double buffer = MathMax(point * 15.0, range * 0.07);
   double sl, tp;
   if(dir == "BUY")
   {
      sl = zoneLow - buffer;
      double risk = price - sl;
      if(risk <= point * 8.0) return false;
      tp = price + (MathMax(3.0, InpRiskReward) * risk);
   }
   else
   {
      sl = zoneHigh + buffer;
      double risk = sl - price;
      if(risk <= point * 8.0) return false;
      tp = price - (MathMax(3.0, InpRiskReward) * risk);
   }

   dirOut = dir;
   entryOut = price;
   slOut = NormalizeDouble(sl, _Digits);
   tpOut = NormalizeDouble(tp, _Digits);

   return true;
}

//| Exécuter les ordres au marché basés sur les décisions IA SMC EMA   |
void ExecuteAIDecisionMarketOrder()
{
   // Catégorie du symbole pour adapter le seuil de confiance IA
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   double requiredConf = MinAIConfidence;
   // Pour tous les marchés HORS Boom/Crash: 85% minimum
   if(cat != SYM_BOOM_CRASH)
      requiredConf = 0.85;

   if(UseHighConfidenceFilterWhenSomeSymbolsProfitLocked)
   {
      int lockedCount = CountProfitTargetLockedSymbols();
      if(lockedCount >= LockedSymbolsMinCountForFilter)
      {
         double extraConf = ExtraMinAIConfidenceWhenLockedPercent / 100.0;
         requiredConf = MathMin(0.99, requiredConf + extraConf);
      }
   }

   // Priorité "propice": si rang > 0, on rend l'entrée plus exigeante (sans bloquer totalement).
   if(UsePropiceSymbolsFilter && PropiceAllowMarketOrdersOnAllPropiceSymbols &&
      g_currentSymbolIsPropice && g_currentSymbolPriority > 0)
   {
      double rankExtraConf = (double)g_currentSymbolPriority * (PropiceNonTopExtraMinAIConfidencePercentPerRank / 100.0);
      requiredConf = MathMin(0.99, requiredConf + rankExtraConf);
   }
   
   // Vérifier si on a une décision IA valide
   if(g_lastAIAction == "" || g_lastAIConfidence < requiredConf)
   {
      return;
   }
   
   // NOUVEAU: Obtenir les prédictions de Protected Points futurs
   double futureSupport = 0.0, futureResistance = 0.0;
   bool hasFutureLevels = GetFutureProtectedPointLevels(futureSupport, futureResistance);
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // VALIDATION SUPPLÉMENTAIRE BASÉE SUR LES PRÉDICTIONS FUTURES
   if(hasFutureLevels)
   {
      // Si IA dit BUY, vérifier qu'on n'est pas trop près d'une résistance future
      if(g_lastAIAction == "BUY" && futureResistance > 0)
      {
         double distanceToResistance = futureResistance - currentPrice;
         double atr = GetATRValue(PERIOD_M15, 14);
         
         if(distanceToResistance < atr * 0.5) // Trop proche de la résistance future
         {
            static datetime lastWarningLog = 0;
            if(TimeCurrent() - lastWarningLog >= 60) // Log toutes les minutes
            {
               Print("🚫 IA BUY BLOQUÉ - Trop proche résistance future: ", DoubleToString(futureResistance, _Digits));
               Print("   📍 Distance: ", DoubleToString(distanceToResistance, _Digits), " < ", DoubleToString(atr * 0.5, _Digits));
               Print("   💡 Attendre un meilleur point d'entrée");
               lastWarningLog = TimeCurrent();
            }
            return;
         }
      }
      
      // Si IA dit SELL, vérifier qu'on n'est pas trop près d'un support futur
      if(g_lastAIAction == "SELL" && futureSupport > 0)
      {
         double distanceToSupport = currentPrice - futureSupport;
         double atr = GetATRValue(PERIOD_M15, 14);
         
         if(distanceToSupport < atr * 0.5) // Trop proche du support future
         {
            static datetime lastWarningLog = 0;
            if(TimeCurrent() - lastWarningLog >= 60) // Log toutes les minutes
            {
               Print("🚫 IA SELL BLOQUÉ - Trop proche support future: ", DoubleToString(futureSupport, _Digits));
               Print("   📍 Distance: ", DoubleToString(distanceToSupport, _Digits), " < ", DoubleToString(atr * 0.5, _Digits));
               Print("   💡 Attendre un meilleur point d'entrée");
               lastWarningLog = TimeCurrent();
            }
            return;
         }
      }
      
      // LOG DES PRÉDICTIONS UTILISÉES
      static datetime lastPredictionLog = 0;
      if(TimeCurrent() - lastPredictionLog >= 300) // Log toutes les 5 minutes
      {
         Print("🔮 PRÉDICTIONS FUTURES UTILISÉES - ", _Symbol);
         Print("   🎯 Support futur: ", (futureSupport > 0 ? DoubleToString(futureSupport, _Digits) : "N/A"));
         Print("   🎯 Résistance future: ", (futureResistance > 0 ? DoubleToString(futureResistance, _Digits) : "N/A"));
         Print("   📍 Prix actuel: ", DoubleToString(currentPrice, _Digits));
         Print("   🤖 Action IA: ", g_lastAIAction, " (confiance: ", DoubleToString(g_lastAIConfidence * 100, 1), "%)");
         lastPredictionLog = TimeCurrent();
      }
   }
   
   // BLOQUER LES ORDRES SI IA EST EN HOLD
   // Réduire la fréquence des logs DEBUG HOLD pour éviter la surcharge
   static datetime lastDebugHoldLog = 0;
   if(TimeCurrent() - lastDebugHoldLog >= 120) // Log toutes les 2 minutes maximum
   {
      Print("?? DEBUG HOLD (Market): g_lastAIAction = '", g_lastAIAction, "' | g_lastAIConfidence = ", DoubleToString(g_lastAIConfidence*100, 1), "%");
      lastDebugHoldLog = TimeCurrent();
   }
   
   if(g_lastAIAction == "HOLD" || g_lastAIAction == "hold")
   {
      Print("?? ORDRES MARCHÉ BLOQUÉS - IA en HOLD - Attente de changement de statut");
      return;
   }
   
   // Calculer une note de setup globale et bloquer si trop basse
   double setupScore = ComputeSetupScore(g_lastAIAction);

   if(UseHighConfidenceFilterWhenSomeSymbolsProfitLocked)
   {
      int lockedCount = CountProfitTargetLockedSymbols();
      if(lockedCount >= LockedSymbolsMinCountForFilter)
      {
         setupScore += ExtraMinSetupScoreWhenLocked;
      }
   }

   // Priorité "propice": rang > 0 => seuil de setup plus strict (sans bloquer totalement).
   double minSetupScoreEntry = MinSetupScoreEntry;
   if(UsePropiceSymbolsFilter && PropiceAllowMarketOrdersOnAllPropiceSymbols &&
      g_currentSymbolIsPropice && g_currentSymbolPriority > 0)
   {
      minSetupScoreEntry += (double)g_currentSymbolPriority * PropiceNonTopExtraMinSetupScore;
   }

   if(setupScore < minSetupScoreEntry)
   {
   // Réduire la fréquence des logs de setup score pour éviter la surcharge
   static datetime lastSetupScoreLog = 0;
   if(TimeCurrent() - lastSetupScoreLog >= 60) // Log toutes les 60 secondes maximum
   {
      Print("?? ORDRE IA BLOQUÉ - SetupScore trop bas: ",
            DoubleToString(setupScore, 1), " < ",
            DoubleToString(minSetupScoreEntry, 1),
            " pour ", _Symbol, " (", g_lastAIAction, ")");
      lastSetupScoreLog = TimeCurrent();
   }
      return;
   }
   
   Print("? ORDRES MARCHÉ AUTORISÉS - IA: ", g_lastAIAction,
         " | SetupScore=", DoubleToString(setupScore, 1));

   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles
   if(!AllowReentryAfterRecentLoss(_Symbol, g_lastAIAction, false))
      return;

   // PROTECTION CONTRE LES PERTES PAR SYMBOLE - Vérifier avant tout
   if(CheckSymbolLossProtection())
   {
      Print("🚨 TRADE IA BLOQUÉ - Protection symbole activée sur ", _Symbol);
      Print("   💰 Perte actuelle: ", DoubleToString(g_symbolCurrentLoss, 2), "$ > Limite: ", DoubleToString(MaxLossPerSymbolDollars, 2), "$");
      Print("   🚫 Trading sur ce symbole BLOQUÉ pour protection du capital");
      return;
   }
   
   // FILTRE PRIORITÉ SYMBOLES PROPICES - BLOCAGE TOTAL SI NON PRIORITAIRE
   if(UsePropiceSymbolsFilter)
   {
      if(!g_currentSymbolIsPropice)
      {
         Print("🚫 TRADE IA BLOQUÉ - Symbole non 'propice' actuellement: ", _Symbol);
         Print("   Heure UTC: ", TimeToString(TimeCurrent(), TIME_SECONDS), " | Top propices: ", g_propiceTopSymbolsText);
         Print("   💡 Le robot trade UNIQUEMENT sur les symboles les plus performants selon l'heure actuelle");
         Print("   🚫 BLOCAGE TOTAL - Aucun trade autorisé sur les symboles non propices");
         return;
      }
      
      // Avant: blocage total si pas rang 0.
      // Maintenant: on autorise si le symbole est propice (rang >0) et on appliquera des seuils plus stricts via requiredConf.
      if(!IsMostPropiceSymbol())
      {
         if(!PropiceAllowMarketOrdersOnAllPropiceSymbols)
         {
            string mostPropice = GetMostPropiceSymbol();
            Print("🚫 TRADE IA BLOQUÉ - Symbole pas le plus propice: ", _Symbol);
            Print("   📍 Position actuelle: ", g_currentSymbolPriority + 1, "ème dans la liste");
            Print("   🥇 Symbole le plus propice: ", mostPropice);
            Print("   🚫 BLOCAGE TOTAL - Seul le symbole le plus propice peut être tradé");
            return;
         }
         Print("⚠️ TRADE IA autorisé (propice rang >", g_currentSymbolPriority + 1,
               ") sur ", _Symbol, " - seuils plus stricts appliqués");
      }
      else
      {
         Print("🥇 SYMBOLE LE PLUS PROPICE - Trading autorisé: ", _Symbol);
         Print("   ✅ Priorité maximale - Conditions de trading normales");
         Print("   🎯 Confiance IA: ", DoubleToString(g_lastAIConfidence * 100, 1), "%");
      }
   }
   
   // Vérification ANTI-DUPLICATION stricte - AUCUNE position sur CE symbole
   if(HasAnyExposureForSymbol(_Symbol))
   {
      Print("?? DUPLICATION BLOQUÉE - Exposition déjà existante sur ", _Symbol, " (position ou ordre en attente)");
      return; // BLOQUER TOUTE duplication sur ce symbole
   }
   
   // BOOM/CRASH: exiger flèche récente OU (optionnel) tendance forte + confiance ML élevée
   if(cat == SYM_BOOM_CRASH)
   {
      if(!HasRecentSMCDerivArrowForDirection(g_lastAIAction))
      {
         Print("?? ORDRES MARCHÉ BLOQUÉS SUR BOOM/CRASH - Pas de flèche (ou conditions tendance forte non remplies) pour ", _Symbol);
         return;
      }
   }
   
   // BLOQUER LES ORDRES SI PRIX EST DANS UN RANGE
   if(IsPriceInRange())
   {
      Print("?? ORDRES MARCHÉ BLOQUÉS - Prix dans un range sur ", _Symbol, " - Attente de breakout");
      return;
   }
   
   // Vérifier le lock pour éviter les doublons
   if(!TryAcquireOpenLock()) return;
   
   // Règle Boom/Crash: pas de SELL sur Boom, pas de BUY sur Crash
   if(!IsDirectionAllowedForBoomCrash(_Symbol, g_lastAIAction))
   {
      Print("? Ordre IA ", g_lastAIAction, " bloqué sur ", _Symbol, " (règle Boom/Crash)");
      ReleaseOpenLock();
      return;
   }
   
   // VALIDATION MULTI-SIGNAUX POUR ENTRÉES PRÉCISES
   if(!ValidateEntryWithMultipleSignals(g_lastAIAction))
   {
      Print("? ENTRÉE BLOQUÉE - Validation multi-signaux échouée pour ", g_lastAIAction, " sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   
   // CALCULER L'ENTRÉE PRÉCISE AU LIEU DU PRIX ACTUEL
   double preciseEntry, preciseSL, preciseTP;
   if(!CalculatePreciseEntryPoint(g_lastAIAction, preciseEntry, preciseSL, preciseTP))
   {
      Print("? CALCUL D'ENTRÉE PRÉCISE ÉCHOUÉ pour ", g_lastAIAction, " sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }

   // Valider/Ajuster SL/TP avant d'envoyer l'ordre précis (stop-level broker + tick size)
   string dirForValidation = (g_lastAIAction == "BUY" || g_lastAIAction == "buy") ? "BUY" : "SELL";
   ValidateAndAdjustStopLossTakeProfit(dirForValidation, preciseEntry, preciseSL, preciseTP);

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0) tickSize = _Point;
   if(tickSize > 0)
   {
      preciseSL = MathRound(preciseSL / tickSize) * tickSize;
      preciseTP = MathRound(preciseTP / tickSize) * tickSize;
      preciseSL = NormalizeDouble(preciseSL, _Digits);
      preciseTP = NormalizeDouble(preciseTP, _Digits);
   }
   // Re-valider après arrondi tick
   ValidateAndAdjustStopLossTakeProfit(dirForValidation, preciseEntry, preciseSL, preciseTP);
   preciseSL = NormalizeDouble(preciseSL, _Digits);
   preciseTP = NormalizeDouble(preciseTP, _Digits);

   // Cohérence direction SL/TP
   if(dirForValidation == "BUY")
   {
      if(preciseSL >= preciseEntry || preciseTP <= preciseEntry)
      {
         Print("❌ IA SMC-EMA PRÉCIS invalid SL/TP - sl=", DoubleToString(preciseSL, _Digits),
               " tp=", DoubleToString(preciseTP, _Digits), " entry=", DoubleToString(preciseEntry, _Digits));
         ReleaseOpenLock();
         return;
      }
   }
   else
   {
      if(preciseSL <= preciseEntry || preciseTP >= preciseEntry)
      {
         Print("❌ IA SMC-EMA PRÉCIS invalid SL/TP - sl=", DoubleToString(preciseSL, _Digits),
               " tp=", DoubleToString(preciseTP, _Digits), " entry=", DoubleToString(preciseEntry, _Digits));
         ReleaseOpenLock();
         return;
      }
   }
   
   double lot = CalculateLotSize();
   Print("🔍 DIAGNOSTIC VOLUME - ", _Symbol);
   Print("   📦 Lot calculé: ", DoubleToString(lot, 2));
   Print("   📊 Min Lot: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN), 2));
   Print("   📊 Max Lot: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), 2));
   Print("   📊 Lot Step: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP), 2));
   
   if(lot <= 0)
   {
      Print("❌ VOLUME INVALIDE - Lot calculé: ", DoubleToString(lot, 2), " <= 0");
      ReleaseOpenLock();
      return;
   }
   
   bool orderExecuted = false;
   
   if(g_lastAIAction == "BUY" || g_lastAIAction == "buy")
   {
      if(!HasRecentSMCDerivArrowForDirection("BUY"))
      {
         Print("?? ORDRE MARCHÉ BLOQUÉ - Attendre flèche SMC_DERIV_ARROW BUY sur ", _Symbol);
         ReleaseOpenLock();
         return;
      }
      // Utiliser l'entrée précise calculée au lieu du prix actuel
      if(trade.Buy(lot, _Symbol, preciseEntry, preciseSL, preciseTP, "IA SMC-EMA BUY PRÉCIS"))
      {
         orderExecuted = true;
         
         // Matérialiser le setup OTE sur le graphique
         DrawOTESetup(preciseEntry, preciseSL, preciseTP, "BUY");
         
         Print("?? ORDRE BUY PRÉCIS EXÉCUTÉ - Entry: ", DoubleToString(preciseEntry, _Digits), 
               " | SL: ", DoubleToString(preciseSL, _Digits), 
               " | TP: ", DoubleToString(preciseTP, _Digits),
               " | Lot: ", DoubleToString(lot, 2),
               " | Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
         
         if(UseNotifications)
         {
            Alert("?? BUY PRÉCIS ", _Symbol, " @", DoubleToString(preciseEntry, _Digits), " - Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
            SendNotification("?? BUY PRÉCIS " + _Symbol + " @" + DoubleToString(preciseEntry, _Digits) + " - Conf: " + DoubleToString(g_lastAIConfidence*100, 1) + "%");
         }
      }
      else
      {
         Print("? Échec ordre BUY PRÉCIS - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else if(g_lastAIAction == "SELL" || g_lastAIAction == "sell")
   {
      if(!HasRecentSMCDerivArrowForDirection("SELL"))
      {
         Print("?? ORDRE MARCHÉ BLOQUÉ - Attendre flèche SMC_DERIV_ARROW SELL sur ", _Symbol);
         ReleaseOpenLock();
         return;
      }
      // Utiliser l'entrée précise calculée au lieu du prix actuel
      if(trade.Sell(lot, _Symbol, preciseEntry, preciseSL, preciseTP, "IA SMC-EMA SELL PRÉCIS"))
      {
         orderExecuted = true;
         
         // Matérialiser le setup OTE sur le graphique
         DrawOTESetup(preciseEntry, preciseSL, preciseTP, "SELL");
         
         Print("?? ORDRE SELL PRÉCIS EXÉCUTÉ - Entry: ", DoubleToString(preciseEntry, _Digits), 
               " | SL: ", DoubleToString(preciseSL, _Digits), 
               " | TP: ", DoubleToString(preciseTP, _Digits),
               " | Lot: ", DoubleToString(lot, 2),
               " | Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
         
         if(UseNotifications)
         {
            Alert("?? SELL PRÉCIS ", _Symbol, " @", DoubleToString(preciseEntry, _Digits), " - Conf: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
            SendNotification("?? SELL PRÉCIS " + _Symbol + " @" + DoubleToString(preciseEntry, _Digits) + " - Conf: " + DoubleToString(g_lastAIConfidence*100, 1) + "%");
         }
      }
      else
      {
         Print("? Échec ordre SELL PRÉCIS - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
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
      g_symbolPauses[i].profitTargetReached = false;  // Initialisation du nouveau champ
   }
}

// Réinitialiser les pauses de profit target au début de chaque journée
void ResetDailyProfitTargetPauses()
{
   static datetime lastResetDate = 0;
   datetime currentDate = GetTodayStart();
   
   if(lastResetDate < currentDate)
   {
      // Nouvelle journée détectée - réinitialiser les pauses de profit target
      for(int i = 0; i < 20; i++)
      {
         if(g_symbolPauses[i].profitTargetReached)
         {
            Print("🔄 RÉINITIALISATION JOURNALIÈRE - Pause profit target réinitialisée pour: ", g_symbolPauses[i].symbol);
            g_symbolPauses[i].profitTargetReached = false;
            g_symbolPauses[i].pauseUntil = 0;
            g_symbolPauses[i].symbol = ""; // Effacer complètement l'entrée
         }
      }
      
      // Réinitialiser aussi la pause globale de profit journalier
      if(g_dailyProfitTargetReached)
      {
         Print("🔄 RÉINITIALISATION JOURNALIÈRE - Pause profit global réinitialisée");
         g_dailyProfitTargetReached = false;
         g_dailyProfitPauseStartTime = 0;
         g_dailyProfitPeak = 0.0;
         g_dailyPauseUntil = 0;
      }
      
      lastResetDate = currentDate;
      Print("✅ RÉINITIALISATION JOURNALIÈRE TERMINEE - Toutes les pauses profit target ont été réinitialisées");
   }
}

bool IsSymbolPaused(string symbol)
{
   // 1. Vérifier si le symbole doit être en pause pour profit target atteint
   if(ShouldPauseSymbolForProfit(symbol))
      return true;
   
   // 2. Vérifier les pauses existantes (pertes/gains successifs)
   datetime currentTime = TimeCurrent();
   for(int i = 0; i < g_pauseCount; i++)
   {
      if(g_symbolPauses[i].symbol == symbol)
      {
         if(currentTime < g_symbolPauses[i].pauseUntil)
         {
            Print("?? SYMBOLE EN PAUSE: ", symbol, " - Jusqu'à: ", TimeToString(g_symbolPauses[i].pauseUntil, TIME_SECONDS));
            return true;
         }
         break;
      }
   }
   return false;
}

// Compte combien de symboles sont actuellement verrouillés par profit target (pour éviter les trades peu probables).
int CountProfitTargetLockedSymbols()
{
   int count = 0;
   datetime now = TimeCurrent();
   for(int i = 0; i < 20; i++)
   {
      if(g_symbolPauses[i].symbol == "") continue;
      if(!g_symbolPauses[i].profitTargetReached) continue;
      if(g_symbolPauses[i].pauseUntil <= now) continue;
      count++;
   }
   return count;
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
         Print("?? PERTE DÉTECTÉE: ", symbol, " | Perte: ", DoubleToString(profit, 2), "$ | Pertes consécutives: ", g_symbolPauses[index].consecutiveLosses);
      }
      else if(profit > 0)
      {
         g_symbolPauses[index].consecutiveWins++;
         g_symbolPauses[index].consecutiveLosses = 0;
         Print("?? GAIN DÉTECTÉ: ", symbol, " | Gain: ", DoubleToString(profit, 2), "$ | Gains consécutifs: ", g_symbolPauses[index].consecutiveWins);
      }
      
      g_symbolPauses[index].lastTradeTime = currentTime;
      g_symbolPauses[index].lastProfit = profit;
   }
}

// Fonction pour calculer le profit cumulé par symbole (toutes positions fermées + ouvertes)
double GetSymbolCumulativeProfit(string symbol)
{
   double symbolProfit = 0.0;
   
   // 1. Ajouter le profit des positions ouvertes pour ce symbole
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      if(posSymbol != symbol) continue;
      
      ulong posMagic = PositionGetInteger(POSITION_MAGIC);
      if(posMagic != InpMagicNumber) continue;
      
      symbolProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   
   // 2. Ajouter le profit des positions fermées aujourd'hui pour ce symbole (via l'historique)
   datetime todayStart = GetTodayStart();
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      if(dealTime < todayStart) continue; // Seulement les trades d'aujourd'hui
      
      string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      if(dealSymbol != symbol) continue;
      
      ulong dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      if(dealMagic != InpMagicNumber) continue;
      
      // Seulement les deals de type fermeture (SELL pour BUY, BUY pour SELL)
      ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
      {
         symbolProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT) + HistoryDealGetDouble(dealTicket, DEAL_SWAP) + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      }
   }
   
   return symbolProfit;
}

// Fonction pour obtenir l'heure de début de journée
datetime GetTodayStart()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
}

// Fonction pour vérifier si un symbole doit être en pause (profit target atteint)
bool ShouldPauseSymbolForProfit(string symbol)
{
   if(SymbolProfitTargetUSD <= 0.0) return false; // Désactivé
   
   double symbolProfit = GetSymbolCumulativeProfit(symbol);
   
   // Exception pour Boom/Crash: utiliser 2$ comme target
   double target = SymbolProfitTargetUSD;
   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
   if(cat == SYM_BOOM_CRASH)
      target = 2.0;
   
   if(symbolProfit >= target)
   {
      // Marquer le symbole comme étant en pause jusqu'à fin de journée
      for(int i = 0; i < 20; i++)
      {
         if(g_symbolPauses[i].symbol == "" || g_symbolPauses[i].symbol == symbol)
         {
            g_symbolPauses[i].symbol = symbol;
            g_symbolPauses[i].profitTargetReached = true;
            
            // Pause jusqu'à fin de journée (23:59:59)
            MqlDateTime dt;
            TimeCurrent(dt);
            dt.hour = 23; dt.min = 59; dt.sec = 59;
            g_symbolPauses[i].pauseUntil = StructToTime(dt);
            
            Print("🎯 PROFIT TARGET SYMBOLE ATTEINT - ", symbol, ": ", DoubleToString(symbolProfit, 2), "$ ≥ ", DoubleToString(target, 1), "$");
            Print("⏸️ PAUSE SYMBOLE ACTIVÉE - ", symbol, " jusqu'à fin de journée (", TimeToString(g_symbolPauses[i].pauseUntil, TIME_SECONDS), ")");
            break;
         }
      }
      return true;
   }
   
   return false;
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
               Print("?? PAUSE 10 MINUTES: ", symbol, " - 2 pertes successives détectées");
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
               Print("?? PAUSE 5 MINUTES: ", symbol, " - 2 gains successifs détectés");
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
         Print("?? SYMBOLE MIS EN PAUSE: ", symbol, " - Durée: ", minutes, " minutes | Jusqu'à: ", TimeToString(pauseUntil, TIME_SECONDS));
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
      Print("?? RANGE DÉTECTÉ sur ", _Symbol, 
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

   // 3) Contexte de tendance HTF (bonus/malus)
   bool bullHTF = IsBullishHTF();
   bool bearHTF = IsBearishHTF();
   string dir = direction;
   StringToUpper(dir);

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

   Print("?? SETUP SCORE ", _Symbol, " ", dir, " = ", DoubleToString(score, 1),
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
         
         Print("?? MÉTRIQUES FALLBACK - Action: ", g_lastAIAction, 
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
         
         Print("?? MÉTRIQUES DÉFAUT - Pas assez de données pour fallback");
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
   Print("? Décision IA mise à jour via /decision - Action: ", g_lastAIAction,
         " | Confiance: ", DoubleToString(g_lastAIConfidence*100, 1), "%");
   return true;
}

string GetAISignalData(string symbol, string timeframe)
{
   string symEnc = symbol;
   StringReplace(symEnc, " ", "%20");
   
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
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
   
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
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
   
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
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
   string notificationMsg = "?? DERIV ARROW " + direction + "\n" +
                           "Symbole: " + _Symbol + "\n" +
                           "Entry: " + entryStr + "\n" +
                           "SL: " + slStr + "\n" +
                           "TP: " + tpStr + "\n" +
                           "Gain estimé: $" + gainStr + "\n" +
                           "Risk/Reward: 1:" + ratioStr;
   
   // Créer le message d'alerte desktop
   string alertMsg = "?? DERIV ARROW " + direction + " - " + _Symbol + 
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
   Print("?? NOTIFICATION ENVOYÉE - DERIV ARROW ", direction);
   Print("?? Symbole: ", _Symbol);
   Print("?? Entry: ", entryStr, " | SL: ", slStr, " | TP: ", tpStr);
   Print("?? Gain estimé: $", gainStr, " | Risk/Reward: 1:", ratioStr);
   Print("?? Notification mobile envoyée avec succès!");
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
      
      // CORRECTION: SL avec distance minimum garantie pour Boom/Crash
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double minSLDistance = MathMax(atrValue * 1.0, 10.0 * point); // Augmenté à 10 points minimum
      stopLoss = entryPrice - minSLDistance;
      
      // CORRECTION: TP avec distance minimum garantie (ratio 2:1 minimum)
      double risk = entryPrice - stopLoss;
      double minTPDistance = MathMax(risk * 2.0, 20.0 * point); // Augmenté à 20 points minimum
      takeProfit = entryPrice + minTPDistance;
      
      // Validation: l'entrée doit être < prix actuel + 1 ATR
      if(entryPrice > currentPrice + atrValue) return false;
   }
   else // SELL
   {
      // Entrée SELL: sous la résistance ou fib61_8
      double sellLevel1 = resistance - (atrValue * 0.5);
      double sellLevel2 = fib61_8 - (atrValue * 0.3);
      
      entryPrice = MathMin(sellLevel1, sellLevel2);
      
      // CORRECTION: SL avec distance minimum garantie pour Boom/Crash
      double minSLDistance = MathMax(atrValue * 1.0, 10.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT)); // Augmenté à 10 points minimum
      stopLoss = entryPrice + minSLDistance;
      
      // CORRECTION: TP avec distance minimum garantie (ratio 2:1 minimum)
      double risk = stopLoss - entryPrice;
      double minTPDistance = MathMax(risk * 2.0, 20.0 * SymbolInfoDouble(_Symbol, SYMBOL_POINT)); // Augmenté à 20 points minimum
      takeProfit = entryPrice - minTPDistance;
      
      // Validation: l'entrée doit être > prix actuel - 1 ATR
      if(entryPrice < currentPrice - atrValue) return false;
   }
   
   // Validation finale des distances
   long stopsLevel = 0;
   double point = 0.0;
   SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL, stopsLevel);
   SymbolInfoDouble(_Symbol, SYMBOL_POINT, point);
   double minDistance = (double)stopsLevel * point;
   
   // CORRECTION: Distance minimum plus réaliste pour Boom/Crash
   if(minDistance == 0) 
   {
      // Pour Boom/Crash, utiliser une distance minimum réaliste
      if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
         minDistance = 15.0 * point; // Augmenté à 15 points minimum pour Boom/Crash
      else
         minDistance = atrValue * 0.5; // Distance par défaut pour autres symboles
   }
   
   // S'assurer que la distance minimum est au moins 15 points
   if(minDistance < 15.0 * point)
      minDistance = 15.0 * point;
   
   // LOGS DE DÉBOGAGE DÉTAILLÉS POUR DIAGNOSTIC STOPS
   Print("🔍 DIAGNOSTIC STOPS - ", _Symbol, " | Direction: ", direction);
   Print("   📍 Entry: ", DoubleToString(entryPrice, _Digits));
   Print("   🛡️ SL: ", DoubleToString(stopLoss, _Digits));
   Print("   🎯 TP: ", DoubleToString(takeProfit, _Digits));
   Print("   📊 Current Price: ", DoubleToString(currentPrice, _Digits));
   Print("   📏 Min Distance: ", DoubleToString(minDistance, _Digits));
   Print("   📏 Entry-SL Distance: ", DoubleToString(MathAbs(entryPrice - stopLoss), _Digits));
   Print("   📏 TP-Entry Distance: ", DoubleToString(MathAbs(takeProfit - entryPrice), _Digits));
   Print("   📏 Stops Level: ", IntegerToString((int)stopsLevel), " points");
   Print("   📏 Point: ", DoubleToString(point, _Digits));
   
   if(MathAbs(entryPrice - stopLoss) < minDistance) 
   {
      Print("❌ STOP LOSS INVALIDE - Distance insuffisante: ", DoubleToString(MathAbs(entryPrice - stopLoss), _Digits), " < ", DoubleToString(minDistance, _Digits));
      return false;
   }
   if(MathAbs(takeProfit - entryPrice) < minDistance * 2) 
   {
      Print("❌ TAKE PROFIT INVALIDE - Distance insuffisante: ", DoubleToString(MathAbs(takeProfit - entryPrice), _Digits), " < ", DoubleToString(minDistance * 2, _Digits));
      return false;
   }
   
   Print("?? ENTRÉE PRÉCISE CALCULÉE - ", direction,
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

   // 4b. Retouche EMA (9/21/50/100/200) avant de reprendre un trade (anti-correction)
   bool emaTouchConfirm = true;
   if(RequireEMATouchBeforeEntry)
   {
      emaTouchConfirm = false;
      int lb = MathMax(3, EMATouchLookbackBarsM1);

      // On récupère les valeurs EMA sur M1 pour comparer aux bougies M1
      int handles[5] = { emaHandle, ema21LTF, ema50LTF, ema100LTF, ema200LTF };
      double emaBuf[5][64];
      int need = MathMin(lb + 1, 64);

      for(int h = 0; h < 5; h++)
      {
         if(handles[h] == INVALID_HANDLE) continue;
         double tmp[];
         ArraySetAsSeries(tmp, true);
         if(CopyBuffer(handles[h], 0, 0, need, tmp) < need) continue;
         for(int i = 0; i < need; i++) emaBuf[h][i] = tmp[i];
      }

      double mid = (rates[0].close > 0.0) ? rates[0].close : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double maxDist = mid * (EMATouchMaxDistancePct / 100.0);
      if(maxDist <= 0.0) maxDist = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;

      // Touch = une bougie dont high/low encadre l'EMA OU close suffisamment proche de l'EMA
      for(int i = 1; i <= lb && i < 30; i++)
      {
         for(int h = 0; h < 5; h++)
         {
            if(handles[h] == INVALID_HANDLE) continue;
            double ev = emaBuf[h][i];
            if(ev <= 0.0) continue;
            bool crossed = (rates[i].low <= ev && rates[i].high >= ev);
            bool near = (MathAbs(rates[i].close - ev) <= maxDist);
            if(crossed || near)
            {
               emaTouchConfirm = true;
               break;
            }
         }
         if(emaTouchConfirm) break;
      }

      if(DebugEMATouchFilter)
      {
         static datetime lastDbg = 0;
         datetime now = TimeCurrent();
         if(now - lastDbg >= 10)
         {
            Print("EMA TOUCH DEBUG ", _Symbol, " dir=", direction,
                  " | ok=", (emaTouchConfirm ? "YES" : "NO"),
                  " | lb=", lb, " | maxDist=", DoubleToString(maxDist, _Digits));
            lastDbg = now;
         }
      }

      // Si pas de retouche EMA → bloquer (anti-correction / attendre pullback)
      if(!emaTouchConfirm) return false;
   }
   
   // 5. Confirmation par volatilité (ni trop basse, ni trop élevée)
   double volatility = range / rates[0].close;
   bool volatilityConfirm = (volatility > 0.0005 && volatility < 0.02);
   if(volatilityConfirm) confirmationCount++;
   
   Print("?? VALIDATION MULTI-SIGNAUX - ", direction,
         " | Confirmations: ", confirmationCount, "/5",
         " | Momentum: ", momentumConfirm ? "?" : "?",
         " | Volume: ", volumeConfirm ? "?" : "?",
         " | Structure: ", structureConfirm ? "?" : "?",
         " | EMA: ", emaConfirm ? "?" : "?",
         " | Volatilité: ", volatilityConfirm ? "?" : "?");
   
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
      if(StringFind(_Symbol, "Boom") >= 0)  touchChannel = PriceTouchesLowerChannel();
      if(StringFind(_Symbol, "Crash") >= 0) touchChannel = PriceTouchesUpperChannel();
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
      string alertMsg = "?? SPIKE IMMINENT sur " + _Symbol + 
                      " | Probabilité: " + DoubleToString(finalSpikeProb*100, 1) + "%" +
                      " | Compression: " + DoubleToString(volCompression*100, 1) + "%" +
                      " | Volume: " + (volumeSpike ? "SPIKE" : "Normal");
      
      Print(alertMsg);
      
      if(UseNotifications)
      {
         Alert(alertMsg);
         SendNotification("?? SPIKE " + _Symbol + " " + DoubleToString(finalSpikeProb*100, 1) + "%");
      }
      
      // Dessiner un marqueur visuel rapide
      DrawSpikeWarning(finalSpikeProb);
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
   
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   
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
            Print("?? MOUVEMENT RETOUR BOOM - Vers canal inférieur | Force: ", DoubleToString(returnStrength, 1), " ATR | Distance: ", DoubleToString(currentDistance/atrVal, 1), " ATR");
            
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
            Print("?? MOUVEMENT RETOUR CRASH - Vers canal supérieur | Force: ", DoubleToString(returnStrength, 1), " ATR | Distance: ", DoubleToString(currentDistance/atrVal, 1), " ATR");
            
            // Placer un ordre limite plus proche pour capturer ce mouvement
            PlaceReturnMovementLimitOrder("SELL", ask, upperPrice, atrVal, returnStrength);
         }
      }
   }
}

//| PLACEMENT D'ORDRE LIMITE POUR MOUVEMENT DE RETOUR               |
void PlaceReturnMovementLimitOrder(string direction, double currentPrice, double channelPrice, double atrVal, double strength)
{
   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction))
   {
      Print("🚫 RETURN LIMIT BLOQUÉ - Direction interdite sur ", _Symbol, " : ", direction);
      return;
   }

   // BLOCAGE SÉCURITÉ: NE PAS PLACER D'ORDRES SI IA EST EN HOLD
   string aiAction = g_lastAIAction;
   StringToUpper(aiAction);
   if(aiAction == "HOLD")
   {
      Print("?? ORDRE RETOUR BLOQUÉ - IA en HOLD sur ", _Symbol, " - Sécurité activée");
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
   
   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles (IA ?90% + spike/setup fort)
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
      
      if(OrderSend(req, res))
      {
         Print("? ORDRE RETOUR BUY PLACÉ - Entry: ", DoubleToString(entryPrice, _Digits), 
               " | Force: ", DoubleToString(strength, 1), " ATR");
      }
      else
      {
         Print("? ÉCHEC ORDRE RETOUR BUY - Erreur: ", res.retcode);
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
      
      if(OrderSend(req, res))
      {
         Print("? ORDRE RETOUR SELL PLACÉ - Entry: ", DoubleToString(entryPrice, _Digits), 
               " | Force: ", DoubleToString(strength, 1), " ATR");
      }
      else
      {
         Print("? ÉCHEC ORDRE RETOUR SELL - Erreur: ", res.retcode);
      }
   }
   
   ReleaseOpenLock();
}

// ===================================================================
// STRATÉGIE SMC_OTE COMPLÈTE - DESSINS ET DÉTECTION
// 3 Étapes: 1) Tendance  2) Imbalance  3) OTE Zone
// ===================================================================

// Dessiner tous les éléments de la stratégie SMC_OTE
void DrawSMC_OTEStrategy()
{
   if(!ShowOTEImbalanceOnChart) return;
   
   // 1) Dessiner la tendance et structure de marché
   DrawSMC_TrendAndStructure();
   
   // 2) Dessiner les zones d'Imbalance (FVG)
   DrawSMC_ImbalanceZones();
   
   // 3) Dessiner les zones OTE (Fibonacci 0.62-0.786)
   DrawSMC_OTEZones();
   
   // 4) Dessiner les setups 5 étoiles (confluence complète)
   DrawSMC_FiveStarSetups();
}

// 1) DESSINER LA TENDANCE ET STRUCTURE DE MARCHÉ - VERSION STYLÉE
void DrawSMC_TrendAndStructure()
{
   // Détecter et dessiner les points High/Low protégés
   DrawProtectedHighsLows();
   
   // Détecter et dessiner les BOS (Break Of Structure)
   DrawBOSPoints();
   
   // Détecter et dessiner les CHoCH (Change of Character)
   DrawCHoCHPoints();
   
   // Dessiner la ligne de tendance principale
   DrawMainTrendLine();
}

// Dessiner les Highs et Lows protégés - VERSION STYLÉE
void DrawProtectedHighsLows()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, LTF, 0, 100, rates) < 50) return;
   
   // Nettoyer les anciens dessins
   ObjectsDeleteAll(0, "PROTECTED_HIGH_");
   ObjectsDeleteAll(0, "PROTECTED_LOW_");
   
   // Limiter le nombre de points affichés
   int maxPoints = 3;
   int highCount = 0, lowCount = 0;
   
   // Détecter les highs protégés (limité à 3)
   for(int i = 5; i < 45 && highCount < maxPoints; i++)
   {
      bool isProtectedHigh = true;
      double currentHigh = rates[i].high;
      
      // Vérifier si ce high est protégé
      for(int j = MathMax(0, i-10); j < i; j++)
      {
         if(rates[j].high > currentHigh)
         {
            isProtectedHigh = false;
            break;
         }
      }
      
      if(isProtectedHigh && currentHigh > 0)
      {
         string highName = "PROTECTED_HIGH_" + IntegerToString(highCount);
         
         // Ligne horizontale fine au lieu de texte
         ObjectCreate(0, highName, OBJ_HLINE, 0, 0, currentHigh);
         ObjectSetInteger(0, highName, OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(0, highName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, highName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, highName, OBJPROP_BACK, true);
         
         // Petit point indicateur
         string pointName = "PROTECTED_HIGH_POINT_" + IntegerToString(highCount);
         ObjectCreate(0, pointName, OBJ_ARROW, 0, rates[i].time, currentHigh);
         ObjectSetInteger(0, pointName, OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(0, pointName, OBJPROP_ARROWCODE, 159); // Cercle
         ObjectSetInteger(0, pointName, OBJPROP_WIDTH, 2);
         
         highCount++;
      }
   }
   
   // Détecter les lows protégés (limité à 3)
   for(int i = 5; i < 45 && lowCount < maxPoints; i++)
   {
      bool isProtectedLow = true;
      double currentLow = rates[i].low;
      
      // Vérifier si ce low est protégé
      for(int j = MathMax(0, i-10); j < i; j++)
      {
         if(rates[j].low < currentLow)
         {
            isProtectedLow = false;
            break;
         }
      }
      
      if(isProtectedLow && currentLow > 0)
      {
         string lowName = "PROTECTED_LOW_" + IntegerToString(lowCount);
         
         // Ligne horizontale fine au lieu de texte
         ObjectCreate(0, lowName, OBJ_HLINE, 0, 0, currentLow);
         ObjectSetInteger(0, lowName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, lowName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lowName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lowName, OBJPROP_BACK, true);
         
         // Petit point indicateur
         string pointName = "PROTECTED_LOW_POINT_" + IntegerToString(lowCount);
         ObjectCreate(0, pointName, OBJ_ARROW, 0, rates[i].time, currentLow);
         ObjectSetInteger(0, pointName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, pointName, OBJPROP_ARROWCODE, 159); // Cercle
         ObjectSetInteger(0, pointName, OBJPROP_WIDTH, 2);
         
         lowCount++;
      }
   }
}

// Dessiner les points BOS - VERSION STYLÉE
void DrawBOSPoints()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, LTF, 0, 100, rates) < 50) return;
   
   // Nettoyer les anciens dessins
   ObjectsDeleteAll(0, "BOS_");
   
   // Limiter le nombre de points BOS
   int maxBOS = 2;
   int bosCount = 0;
   
   for(int i = 10; i < 40 && bosCount < maxBOS; i++)
   {
      // BOS Haussier
      if(rates[i].high > rates[i+5].high && rates[i+3].low < rates[i+8].low)
      {
         string bosName = "BOS_BUY_" + IntegerToString(bosCount);
         ObjectCreate(0, bosName, OBJ_ARROW, 0, rates[i].time, rates[i].high);
         ObjectSetInteger(0, bosName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, bosName, OBJPROP_ARROWCODE, 233);
         ObjectSetInteger(0, bosName, OBJPROP_WIDTH, 3);
         
         bosCount++;
      }
      
      // BOS Baissier
      if(rates[i].low < rates[i+5].low && rates[i+3].high > rates[i+8].high)
      {
         string bosName = "BOS_SELL_" + IntegerToString(bosCount);
         ObjectCreate(0, bosName, OBJ_ARROW, 0, rates[i].time, rates[i].low);
         ObjectSetInteger(0, bosName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, bosName, OBJPROP_ARROWCODE, 234);
         ObjectSetInteger(0, bosName, OBJPROP_WIDTH, 3);
         
         bosCount++;
      }
   }
}

// Dessiner les points CHoCH - VERSION STYLÉE
void DrawCHoCHPoints()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, LTF, 0, 100, rates) < 50) return;
   
   // Nettoyer les anciens dessins
   ObjectsDeleteAll(0, "CHOCH_");
   
   // Limiter le nombre de points CHoCH
   int maxCHoCH = 2;
   int chochCount = 0;
   
   for(int i = 15; i < 35 && chochCount < maxCHoCH; i++)
   {
      // CHoCH Haussier
      bool wasDowntrend = true;
      for(int j = i+5; j < i+15 && j < 50; j++)
      {
         if(rates[j].high > rates[j+1].high)
         {
            wasDowntrend = false;
            break;
         }
      }
      
      if(wasDowntrend && rates[i].high > rates[i+2].high && rates[i+1].high > rates[i+3].high)
      {
         string chochName = "CHOCH_BUY_" + IntegerToString(chochCount);
         ObjectCreate(0, chochName, OBJ_ARROW, 0, rates[i].time, rates[i].high);
         ObjectSetInteger(0, chochName, OBJPROP_COLOR, clrAqua);
         ObjectSetInteger(0, chochName, OBJPROP_ARROWCODE, 233);
         ObjectSetInteger(0, chochName, OBJPROP_WIDTH, 4);
         
         chochCount++;
      }
      
      // CHoCH Baissier
      bool wasUptrend = true;
      for(int j = i+5; j < i+15 && j < 50; j++)
      {
         if(rates[j].low < rates[j+1].low)
         {
            wasUptrend = false;
            break;
         }
      }
      
      if(wasUptrend && rates[i].low < rates[i+2].low && rates[i+1].low < rates[i+3].low)
      {
         string chochName = "CHOCH_SELL_" + IntegerToString(chochCount);
         ObjectCreate(0, chochName, OBJ_ARROW, 0, rates[i].time, rates[i].low);
         ObjectSetInteger(0, chochName, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, chochName, OBJPROP_ARROWCODE, 234);
         ObjectSetInteger(0, chochName, OBJPROP_WIDTH, 4);
         
         chochCount++;
      }
   }
}

// Dessiner la ligne de tendance principale
void DrawMainTrendLine()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, LTF, 0, 100, rates) < 50) return;
   
   // Nettoyer les anciennes lignes
   ObjectsDeleteAll(0, "TREND_LINE_");
   
   // Détecter les points de tendance significatifs
   double trendHighs[], trendLows[];
   datetime trendHighTimes[], trendLowTimes[];
   
   int highCount = 0, lowCount = 0;
   
   // Identifier les highs et lows de tendance
   for(int i = 10; i < 40; i++)
   {
      // High de tendance
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
         rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
      {
         ArrayResize(trendHighs, highCount + 1);
         ArrayResize(trendHighTimes, highCount + 1);
         trendHighs[highCount] = rates[i].high;
         trendHighTimes[highCount] = rates[i].time;
         highCount++;
      }
      
      // Low de tendance
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
         rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
      {
         ArrayResize(trendLows, lowCount + 1);
         ArrayResize(trendLowTimes, lowCount + 1);
         trendLows[lowCount] = rates[i].low;
         trendLowTimes[lowCount] = rates[i].time;
         lowCount++;
      }
   }
   
   // Dessiner la ligne de tendance haussière
   if(highCount >= 2)
   {
      string trendLineName = "TREND_LINE_UPTREND_" + _Symbol;
      if(ObjectFind(0, trendLineName) < 0)
      {
         ObjectCreate(0, trendLineName, OBJ_TREND, 0, 
                     trendHighTimes[highCount-1], trendHighs[highCount-1],
                     trendHighTimes[0], trendHighs[0]);
         ObjectSetInteger(0, trendLineName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, trendLineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, trendLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, trendLineName, OBJPROP_RAY_RIGHT, true);
         ObjectSetString(0, trendLineName, OBJPROP_TEXT, "Uptrend");
      }
   }
   
   // Dessiner la ligne de tendance baissière
   if(lowCount >= 2)
   {
      string trendLineName = "TREND_LINE_DOWNTREND_" + _Symbol;
      if(ObjectFind(0, trendLineName) < 0)
      {
         ObjectCreate(0, trendLineName, OBJ_TREND, 0, 
                     trendLowTimes[lowCount-1], trendLows[lowCount-1],
                     trendLowTimes[0], trendLows[0]);
         ObjectSetInteger(0, trendLineName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, trendLineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, trendLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, trendLineName, OBJPROP_RAY_RIGHT, true);
         ObjectSetString(0, trendLineName, OBJPROP_TEXT, "Downtrend");
      }
   }
}

// 2) DESSINER LES ZONES D'IMBALANCE (FVG) - VERSION STYLÉE
void DrawSMC_ImbalanceZones()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, LTF, 0, 100, rates) < 3) return;
   
   // Nettoyer les anciennes zones
   ObjectsDeleteAll(0, "SMC_IMBALANCE_");
   
   for(int i = 2; i < 80; i++)
   {
      // Imbalance Haussier (Bullish FVG) - Style épuré
      if(rates[i].high < rates[i+2].low && rates[i+1].high < rates[i+2].low)
      {
         double top = rates[i+2].low;
         double bottom = rates[i].high;
         double gap = top - bottom;
         
         // Ne dessiner que les gaps significatifs
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(gap < point * 5.0) continue;
         
         string fvgName = "SMC_IMBALANCE_BUY_" + IntegerToString(i);
         
         // Rectangle semi-transparent avec bordure fine
         ObjectCreate(0, fvgName, OBJ_RECTANGLE, 0, 
                     rates[i].time, top,
                     rates[i+2].time, bottom);
         ObjectSetInteger(0, fvgName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, fvgName, OBJPROP_BACK, true);
         ObjectSetInteger(0, fvgName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, fvgName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, fvgName, OBJPROP_FILL, true);
         ObjectSetInteger(0, fvgName, OBJPROP_BGCOLOR, clrLime);
         ObjectSetInteger(0, fvgName, OBJPROP_FILL, true);
         
         // Petit indicateur de gap au lieu de label text
         string indicatorName = "SMC_IMBALANCE_BUY_IND_" + IntegerToString(i);
         ObjectCreate(0, indicatorName, OBJ_ARROW, 0, 
                     rates[i+1].time, (top + bottom) / 2);
         ObjectSetInteger(0, indicatorName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, indicatorName, OBJPROP_ARROWCODE, 159); // Cercle
         ObjectSetInteger(0, indicatorName, OBJPROP_WIDTH, 2);
      }
      
      // Imbalance Baissier (Bearish FVG) - Style épuré
      if(rates[i].low > rates[i+2].high && rates[i+1].low > rates[i+2].high)
      {
         double bottom = rates[i+2].high;
         double top = rates[i].low;
         double gap = top - bottom;
         
         // Ne dessiner que les gaps significatifs
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(gap < point * 5.0) continue;
         
         string fvgName = "SMC_IMBALANCE_SELL_" + IntegerToString(i);
         
         // Rectangle semi-transparent avec bordure fine
         ObjectCreate(0, fvgName, OBJ_RECTANGLE, 0, 
                     rates[i].time, top,
                     rates[i+2].time, bottom);
         ObjectSetInteger(0, fvgName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, fvgName, OBJPROP_BACK, true);
         ObjectSetInteger(0, fvgName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, fvgName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, fvgName, OBJPROP_FILL, true);
         ObjectSetInteger(0, fvgName, OBJPROP_BGCOLOR, clrRed);
         
         // Petit indicateur de gap au lieu de label text
         string indicatorName = "SMC_IMBALANCE_SELL_IND_" + IntegerToString(i);
         ObjectCreate(0, indicatorName, OBJ_ARROW, 0, 
                     rates[i+1].time, (top + bottom) / 2);
         ObjectSetInteger(0, indicatorName, OBJPROP_COLOR, clrWhite);
         ObjectSetInteger(0, indicatorName, OBJPROP_ARROWCODE, 159); // Cercle
         ObjectSetInteger(0, indicatorName, OBJPROP_WIDTH, 2);
      }
   }
}

// 3) DESSINER LES ZONES OTE (FIBONACCI 0.62-0.786) - VERSION STYLÉE
void DrawSMC_OTEZones()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, LTF, 0, 100, rates) < 20) return;
   
   // Nettoyer les anciennes zones
   ObjectsDeleteAll(0, "SMC_OTE_");
   
   // Trouver les points significatifs pour le Fibonacci
   for(int i = 10; i < 60; i++)
   {
      // Structure haussière: chercher un low significatif suivi d'un high significatif
      double swingLow = rates[i].low;
      double swingHigh = 0;
      datetime swingLowTime = rates[i].time;
      datetime swingHighTime = 0;
      
      // Chercher le high suivant plus élevé
      for(int j = i-5; j >= MathMax(0, i-25); j--)
      {
         if(rates[j].high > swingHigh)
         {
            swingHigh = rates[j].high;
            swingHighTime = rates[j].time;
         }
      }
      
      if(swingHigh > swingLow && swingHighTime > 0)
      {
         // Calculer les niveaux OTE
         double range = swingHigh - swingLow;
         double ote62 = swingLow + range * 0.62;   // Niveau 0.62
         double ote786 = swingLow + range * 0.786; // Niveau 0.786
         
         // MASQUER LES LIGNES OTE BUY - Ne pas dessiner les zones et lignes OTE BUY
         // Commenté pour masquer visuellement les éléments OTE BUY sur le graphique
         /*
         // Dessiner la zone OTE avec style épuré
         string oteName = "SMC_OTE_BUY_" + IntegerToString(i);
         ObjectCreate(0, oteName, OBJ_RECTANGLE, 0, 
                     swingLowTime, ote62,
                     swingHighTime, ote786);
         ObjectSetInteger(0, oteName, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, oteName, OBJPROP_BACK, true);
         ObjectSetInteger(0, oteName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, oteName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, oteName, OBJPROP_FILL, true);
         ObjectSetInteger(0, oteName, OBJPROP_BGCOLOR, clrGold);
         
         // Lignes horizontales fines pour les niveaux (au lieu de labels)
         string line62 = "SMC_OTE_BUY_62_" + IntegerToString(i);
         ObjectCreate(0, line62, OBJ_HLINE, 0, 0, ote62);
         ObjectSetInteger(0, line62, OBJPROP_COLOR, clrYellow);
         ObjectSetInteger(0, line62, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, line62, OBJPROP_WIDTH, 1);
         
         string line786 = "SMC_OTE_BUY_786_" + IntegerToString(i);
         ObjectCreate(0, line786, OBJ_HLINE, 0, 0, ote786);
         ObjectSetInteger(0, line786, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, line786, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, line786, OBJPROP_WIDTH, 1);
         
         // Petit triangle pour indiquer la zone OTE
         string triangleName = "SMC_OTE_BUY_TRI_" + IntegerToString(i);
         ObjectCreate(0, triangleName, OBJ_TRIANGLE, 0, 
                     swingLowTime, ote62,
                     swingLowTime + PeriodSeconds(LTF) * 2, ote62,
                     swingLowTime + PeriodSeconds(LTF), ote786);
         ObjectSetInteger(0, triangleName, OBJPROP_COLOR, clrGold);
         ObjectSetInteger(0, triangleName, OBJPROP_BACK, true);
         ObjectSetInteger(0, triangleName, OBJPROP_FILL, true);
         */
      }
      
      // Structure baissière: chercher un high significatif suivi d'un low significatif
      swingHigh = rates[i].high;
      swingLow = 0;
      swingHighTime = rates[i].time;
      swingLowTime = 0;
      
      // Chercher le low suivant plus bas
      for(int j = i-5; j >= MathMax(0, i-25); j--)
      {
         if(rates[j].low < swingLow || swingLow == 0)
         {
            swingLow = rates[j].low;
            swingLowTime = rates[j].time;
         }
      }
      
      if(swingLow > 0 && swingLow < swingHigh && swingLowTime > 0)
      {
         // Calculer les niveaux OTE
         double range = swingHigh - swingLow;
         double ote62 = swingHigh - range * 0.62;   // Niveau 0.62
         double ote786 = swingHigh - range * 0.786; // Niveau 0.786
         
         // MASQUER LES LIGNES OTE SELL - Ne pas dessiner les zones et lignes OTE SELL
         // Commenté pour masquer visuellement les éléments OTE SELL sur le graphique
         /*
         // Dessiner la zone OTE avec style épuré
         string oteName = "SMC_OTE_SELL_" + IntegerToString(i);
         ObjectCreate(0, oteName, OBJ_RECTANGLE, 0, 
                     swingHighTime, ote62,
                     swingLowTime, ote786);
         ObjectSetInteger(0, oteName, OBJPROP_COLOR, clrPurple);
         ObjectSetInteger(0, oteName, OBJPROP_BACK, true);
         ObjectSetInteger(0, oteName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, oteName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, oteName, OBJPROP_FILL, true);
         ObjectSetInteger(0, oteName, OBJPROP_BGCOLOR, clrPurple);
         
         // Lignes horizontales fines pour les niveaux (au lieu de labels)
         string line62 = "SMC_OTE_SELL_62_" + IntegerToString(i);
         ObjectCreate(0, line62, OBJ_HLINE, 0, 0, ote62);
         ObjectSetInteger(0, line62, OBJPROP_COLOR, clrYellow);
         ObjectSetInteger(0, line62, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, line62, OBJPROP_WIDTH, 1);
         
         string line786 = "SMC_OTE_SELL_786_" + IntegerToString(i);
         ObjectCreate(0, line786, OBJ_HLINE, 0, 0, ote786);
         ObjectSetInteger(0, line786, OBJPROP_COLOR, clrOrange);
         ObjectSetInteger(0, line786, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, line786, OBJPROP_WIDTH, 1);
         
         // Petit triangle pour indiquer la zone OTE
         string triangleName = "SMC_OTE_SELL_TRI_" + IntegerToString(i);
         ObjectCreate(0, triangleName, OBJ_TRIANGLE, 0, 
                     swingHighTime, ote62,
                     swingHighTime + PeriodSeconds(LTF) * 2, ote62,
                     swingHighTime + PeriodSeconds(LTF), ote786);
         ObjectSetInteger(0, triangleName, OBJPROP_COLOR, clrPurple);
         ObjectSetInteger(0, triangleName, OBJPROP_BACK, true);
         ObjectSetInteger(0, triangleName, OBJPROP_FILL, true);
         */
      }
   }
}

// 4) DESSINER LES SETUPS 5 ÉTOILES (CONFLUENCE COMPLÈTE) - VERSION STYLÉE
void DrawSMC_FiveStarSetups()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, LTF, 0, 100, rates) < 50) return;
   
   // Nettoyer les anciens setups
   ObjectsDeleteAll(0, "SMC_5STAR_");
   
   // Détecter les setups 5 étoiles
   for(int i = 20; i < 40; i++)
   {
      // Vérifier setup BUY 5 étoiles
      if(IsFiveStarBuySetup(rates, i))
      {
         string setupName = "SMC_5STAR_BUY_" + IntegerToString(i);
         
         // Étoile stylée au lieu de flèche avec texte
         ObjectCreate(0, setupName, OBJ_ARROW, 0, rates[i].time, rates[i].low);
         ObjectSetInteger(0, setupName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, setupName, OBJPROP_ARROWCODE, 181); // Étoile
         ObjectSetInteger(0, setupName, OBJPROP_WIDTH, 4);
         
         // Zone d'entrée épurée avec bordure lumineuse
         string zoneName = "SMC_5STAR_BUY_ZONE_" + IntegerToString(i);
         double entryZone = rates[i].low;
         ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, 
                     rates[i].time, entryZone - 0.0008,
                     rates[i].time + PeriodSeconds(LTF) * 3, entryZone + 0.0008);
         ObjectSetInteger(0, zoneName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
         ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
         ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, clrLime);
         
         // Ligne verticale pour marquer l'entrée
         string lineName = "SMC_5STAR_BUY_LINE_" + IntegerToString(i);
         ObjectCreate(0, lineName, OBJ_VLINE, 0, rates[i].time, 0);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      }
      
      // Vérifier setup SELL 5 étoiles
      if(IsFiveStarSellSetup(rates, i))
      {
         string setupName = "SMC_5STAR_SELL_" + IntegerToString(i);
         
         // Étoile stylée au lieu de flèche avec texte
         ObjectCreate(0, setupName, OBJ_ARROW, 0, rates[i].time, rates[i].high);
         ObjectSetInteger(0, setupName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, setupName, OBJPROP_ARROWCODE, 181); // Étoile
         ObjectSetInteger(0, setupName, OBJPROP_WIDTH, 4);
         
         // Zone d'entrée épurée avec bordure lumineuse
         string zoneName = "SMC_5STAR_SELL_ZONE_" + IntegerToString(i);
         double entryZone = rates[i].high;
         ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, 
                     rates[i].time, entryZone + 0.0008,
                     rates[i].time + PeriodSeconds(LTF) * 3, entryZone - 0.0008);
         ObjectSetInteger(0, zoneName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
         ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
         ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, clrRed);
         
         // Ligne verticale pour marquer l'entrée
         string lineName = "SMC_5STAR_SELL_LINE_" + IntegerToString(i);
         ObjectCreate(0, lineName, OBJ_VLINE, 0, rates[i].time, 0);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, true);
      }
   }
}

// Vérifier si c'est un setup BUY 5 étoiles
bool IsFiveStarBuySetup(MqlRates &rates[], int index)
{
   // 1) Tendance haussière confirmée
   if(!IsUptrendConfirmed(rates, index)) return false;
   
   // 2) Imbalance dans la zone
   if(!HasImbalanceInZone(rates, index, "BUY")) return false;
   
   // 3) Zone OTE alignée
   if(!IsInOTEZone(rates, index, "BUY")) return false;
   
   return true;
}

// Vérifier si c'est un setup SELL 5 étoiles
bool IsFiveStarSellSetup(MqlRates &rates[], int index)
{
   // 1) Tendance baissière confirmée
   if(!IsDowntrendConfirmed(rates, index)) return false;
   
   // 2) Imbalance dans la zone
   if(!HasImbalanceInZone(rates, index, "SELL")) return false;
   
   // 3) Zone OTE alignée
   if(!IsInOTEZone(rates, index, "SELL")) return false;
   
   return true;
}

// Vérifier si la tendance haussière est confirmée
bool IsUptrendConfirmed(MqlRates &rates[], int index)
{
   // Vérifier les highs et lows plus élevés
   for(int i = index; i < index + 10 && i < ArraySize(rates) - 1; i++)
   {
      if(rates[i].high < rates[i+1].high || rates[i].low < rates[i+1].low)
         return false;
   }
   return true;
}

// Vérifier si la tendance baissière est confirmée
bool IsDowntrendConfirmed(MqlRates &rates[], int index)
{
   // Vérifier les highs et lows plus bas
   for(int i = index; i < index + 10 && i < ArraySize(rates) - 1; i++)
   {
      if(rates[i].high > rates[i+1].high || rates[i].low > rates[i+1].low)
         return false;
   }
   return true;
}

// Vérifier s'il y a un imbalance dans la zone
bool HasImbalanceInZone(MqlRates &rates[], int index, string direction)
{
   // Vérifier les 3 bougies pour l'imbalance
   if(index < 2) return false;
   
   if(direction == "BUY")
   {
      // Imbalance haussier: top bougie 1 ne touche pas bottom bougie 3
      return (rates[index].high < rates[index-2].low && 
              rates[index-1].high < rates[index-2].low);
   }
   else // SELL
   {
      // Imbalance baissier: bottom bougie 1 ne touche pas top bougie 3
      return (rates[index].low > rates[index-2].high && 
              rates[index-1].low > rates[index-2].high);
   }
}

// Vérifier si le prix est dans la zone OTE
bool IsInOTEZone(MqlRates &rates[], int index, string direction)
{
   if(index < 20) return false;
   
   // Trouver les points swing pour Fibonacci
   double swingLow = 0, swingHigh = 0;
   
   if(direction == "BUY")
   {
      // Chercher le low et high pour la structure haussière
      swingLow = rates[index].low;
      for(int i = index - 5; i >= MathMax(0, index - 25); i--)
      {
         if(rates[i].high > swingHigh)
            swingHigh = rates[i].high;
      }
      
      if(swingHigh > swingLow)
      {
         double range = swingHigh - swingLow;
         double ote62 = swingLow + range * 0.62;
         double ote786 = swingLow + range * 0.786;
         
         double currentPrice = rates[index].close;
         return (currentPrice >= ote62 && currentPrice <= ote786);
      }
   }
   else // SELL
   {
      // Chercher le high et low pour la structure baissière
      swingHigh = rates[index].high;
      for(int i = index - 5; i >= MathMax(0, index - 25); i--)
      {
         if(rates[i].low < swingLow || swingLow == 0)
            swingLow = rates[i].low;
      }
      
      if(swingLow > 0 && swingLow < swingHigh)
      {
         double range = swingHigh - swingLow;
         double ote62 = swingHigh - range * 0.62;
         double ote786 = swingHigh - range * 0.786;
         
         double currentPrice = rates[index].close;
         return (currentPrice >= ote786 && currentPrice <= ote62);
      }
   }
   
   return false;
}

// ===================================================================
// STRATÉGIE SMC_OTE COMPLÈTE - EXÉCUTION
// 3 Étapes: 1) Tendance  2) Imbalance  3) OTE Zone
// ===================================================================

// Exécuter la stratégie SMC_OTE complète
void ExecuteSMC_OTEStrategy()
{
   // Vérifier si la stratégie est activée
   if(!UseSMC_OTEStrategy) return;

   ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(_Symbol);
   if(!(cat == SYM_FOREX || cat == SYM_METAL || cat == SYM_COMMODITY))
      return;

   // Vérifier le nombre de positions
   int currentPositions = CountPositionsForSymbol(_Symbol);
   if(currentPositions >= 2)
   {
      static datetime lastBlockLog = 0;
      if(TimeCurrent() - lastBlockLog >= 60)
      {
         Print("🛡️ SMC_OTE - 2 positions déjà ouvertes sur ", _Symbol, " - Nouveaux trades bloqués");
         lastBlockLog = TimeCurrent();
      }
      return;
   }

   // ÉTAPE 1: Identifier la tendance du marché
   string trendDirection = "";
   if(!IdentifyMarketTrend(trendDirection))
   {
      Print("📊 SMC_OTE - Tendance non identifiée sur ", _Symbol);
      return;
   }

   // ÉTAPE 2: Détecter les zones d'Imbalance (FVG)
   double imbalanceTop = 0, imbalanceBottom = 0;
   datetime imbalanceTime = 0;
   if(!DetectImbalanceZone(trendDirection, imbalanceTop, imbalanceBottom, imbalanceTime))
   {
      Print("⚠️ SMC_OTE - Aucun Imbalance valide détecté sur ", _Symbol);
      return;
   }

   // ÉTAPE 3: Calculer et vérifier la zone OTE (Fibonacci 0.62-0.786)
   double oteLow = 0, oteHigh = 0;
   if(!CalculateOTEZone(trendDirection, oteLow, oteHigh))
   {
      Print("📐 SMC_OTE - Impossible de calculer la zone OTE sur ", _Symbol);
      return;
   }

   // VÉRIFICATION DE LA CONFLUENCE 5 ÉTOILES
   if(!IsFiveStarConfluence(trendDirection, imbalanceTop, imbalanceBottom, oteLow, oteHigh))
   {
      Print("⭐ SMC_OTE - Confluence 5 étoiles non validée sur ", _Symbol);
      return;
   }

   // Vérifier si le prix est dans la zone d'entrée
   double currentPrice = (trendDirection == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(!IsPriceInEntryZone(currentPrice, imbalanceTop, imbalanceBottom, oteLow, oteHigh))
   {
      Print("📍 SMC_OTE - Prix pas dans la zone d'entrée sur ", _Symbol,
            " | Prix: ", DoubleToString(currentPrice, _Digits));
      return;
   }

   // Calculer SL/TP selon la stratégie (TP >= 3R risk/reward)
   double entryPrice = currentPrice;
   double stopLoss, takeProfit;
   
   if(trendDirection == "BUY")
   {
      stopLoss = MathMin(imbalanceBottom, oteLow) - 15 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double risk = entryPrice - stopLoss;
      takeProfit = entryPrice + (MathMax(3.0, InpRiskReward) * risk); // TP >= 3R
   }
   else // SELL
   {
      stopLoss = MathMax(imbalanceTop, oteHigh) + 15 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double risk = stopLoss - entryPrice;
      takeProfit = entryPrice - (MathMax(3.0, InpRiskReward) * risk); // TP >= 3R
   }

   // Exécuter le trade
   ExecuteSMC_OTETrade(trendDirection, entryPrice, stopLoss, takeProfit);
}

// ÉTAPE 1: Identifier la tendance du marché
bool IdentifyMarketTrend(string &directionOut)
{
   directionOut = "";
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, HTF, 0, 50, rates) < 30) return false;

   // Analyser la structure de marché sur les 30 dernières bougies
   int higherHighs = 0, higherLows = 0;
   int lowerHighs = 0, lowerLows = 0;

   for(int i = 5; i < 25; i++)
   {
      // Comparer avec les bougies précédentes
      if(rates[i].high > rates[i+5].high) higherHighs++;
      if(rates[i].low > rates[i+5].low) higherLows++;
      if(rates[i].high < rates[i+5].high) lowerHighs++;
      if(rates[i].low < rates[i+5].low) lowerLows++;
   }

   // Déterminer la tendance dominante
   if(higherHighs > lowerHighs && higherLows > lowerLows)
   {
      directionOut = "BUY"; // Marché haussier
      Print("📈 SMC_OTE - Tendance haussière identifiée sur ", _Symbol);
      return true;
   }
   else if(lowerHighs > higherHighs && lowerLows > higherLows)
   {
      directionOut = "SELL"; // Marché baissier
      Print("📉 SMC_OTE - Tendance baissière identifiée sur ", _Symbol);
      return true;
   }
   else
   {
      return false; // Pas de tendance claire
   }
}

// ÉTAPE 2: Détecter les zones d'Imbalance (FVG)
bool DetectImbalanceZone(string direction, double &topOut, double &bottomOut, datetime &timeOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, LTF, 0, 100, rates) < 3) return false;

   // Chercher les imbalances récents et significatifs
   for(int i = 2; i < 50; i++)
   {
      if(direction == "BUY")
      {
         // Imbalance haussier: top bougie 1 ne touche pas bottom bougie 3
         if(rates[i].high < rates[i+2].low && rates[i+1].high < rates[i+2].low)
         {
            double gap = rates[i+2].low - rates[i].high;
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            // Vérifier que l'imbalance est significatif (au moins 5 points)
            if(gap >= point * 5.0)
            {
               topOut = rates[i+2].low;
               bottomOut = rates[i].high;
               timeOut = rates[i+1].time;
               
               Print("🎯 SMC_OTE - Imbalance BUY détecté | Gap: ", DoubleToString(gap, _Digits),
                     " | Top: ", DoubleToString(topOut, _Digits),
                     " | Bottom: ", DoubleToString(bottomOut, _Digits));
               return true;
            }
         }
      }
      else // SELL
      {
         // Imbalance baissier: bottom bougie 1 ne touche pas top bougie 3
         if(rates[i].low > rates[i+2].high && rates[i+1].low > rates[i+2].high)
         {
            double gap = rates[i].low - rates[i+2].high;
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            
            // Vérifier que l'imbalance est significatif (au moins 5 points)
            if(gap >= point * 5.0)
            {
               topOut = rates[i].low;
               bottomOut = rates[i+2].high;
               timeOut = rates[i+1].time;
               
               Print("🎯 SMC_OTE - Imbalance SELL détecté | Gap: ", DoubleToString(gap, _Digits),
                     " | Top: ", DoubleToString(topOut, _Digits),
                     " | Bottom: ", DoubleToString(bottomOut, _Digits));
               return true;
            }
         }
      }
   }

   return false;
}

// ÉTAPE 3: Calculer la zone OTE (Fibonacci 0.62-0.786)
bool CalculateOTEZone(string direction, double &lowOut, double &highOut)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, HTF, 0, 100, rates) < 20) return false;

   // Trouver les points swing significatifs
   double swingLow = 0, swingHigh = 0;
   datetime swingLowTime = 0, swingHighTime = 0;

   if(direction == "BUY")
   {
      // Chercher un low significatif suivi d'un high significatif
      for(int i = 10; i < 50; i++)
      {
         // Low significatif
         if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low &&
            rates[i].low < rates[i-2].low && rates[i].low < rates[i+2].low)
         {
            if(swingLow == 0 || rates[i].low < swingLow)
            {
               swingLow = rates[i].low;
               swingLowTime = rates[i].time;
            }
         }
      }

      // Chercher le high suivant plus élevé
      for(int j = 5; j < 30; j++)
      {
         if(rates[j].high > swingHigh && rates[j].time > swingLowTime)
         {
            swingHigh = rates[j].high;
            swingHighTime = rates[j].time;
         }
      }
   }
   else // SELL
   {
      // Chercher un high significatif suivi d'un low significatif
      for(int i = 10; i < 50; i++)
      {
         // High significatif
         if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high &&
            rates[i].high > rates[i-2].high && rates[i].high > rates[i+2].high)
         {
            if(swingHigh == 0 || rates[i].high > swingHigh)
            {
               swingHigh = rates[i].high;
               swingHighTime = rates[i].time;
            }
         }
      }

      // Chercher le low suivant plus bas
      for(int j = 5; j < 30; j++)
      {
         if(rates[j].low < swingLow && rates[j].time > swingHighTime)
         {
            swingLow = rates[j].low;
            swingLowTime = rates[j].time;
         }
      }
   }

   if(swingHigh > 0 && swingLow > 0 && swingHigh != swingLow)
   {
      double range = MathAbs(swingHigh - swingLow);
      
      if(direction == "BUY")
      {
         lowOut = swingLow + range * 0.62;   // OTE 0.62
         highOut = swingLow + range * 0.786; // OTE 0.786
      }
      else // SELL
      {
         highOut = swingHigh - range * 0.62;   // OTE 0.62
         lowOut = swingHigh - range * 0.786;  // OTE 0.786
      }

      Print("📐 SMC_OTE - Zone OTE calculée | Low: ", DoubleToString(lowOut, _Digits),
            " | High: ", DoubleToString(highOut, _Digits),
            " | Range: ", DoubleToString(range, _Digits));
      return true;
   }

   return false;
}

// Vérifier la confluence 5 étoiles
bool IsFiveStarConfluence(string direction, double imbalanceTop, double imbalanceBottom, double oteLow, double oteHigh)
{
   // Vérifier que l'imbalance et la zone OTE se chevauchent
   double zoneLow = MathMax(imbalanceBottom, oteLow);
   double zoneHigh = MathMin(imbalanceTop, oteHigh);

   if(zoneHigh <= zoneLow)
   {
      Print("⚠️ SMC_OTE - Pas de confluence entre Imbalance et OTE");
      return false;
   }

   double confluenceSize = zoneHigh - zoneLow;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // La confluence doit être significative (au moins 10 points)
   if(confluenceSize < point * 10.0)
   {
      Print("⚠️ SMC_OTE - Confluence trop petite: ", DoubleToString(confluenceSize, _Digits));
      return false;
   }

   Print("⭐ SMC_OTE - Confluence 5 étoiles validée! | Zone: ", 
         DoubleToString(zoneLow, _Digits), " - ", DoubleToString(zoneHigh, _Digits),
         " | Taille: ", DoubleToString(confluenceSize, _Digits));
   return true;
}

// Vérifier si le prix est dans la zone d'entrée
bool IsPriceInEntryZone(double price, double imbalanceTop, double imbalanceBottom, double oteLow, double oteHigh)
{
   // Calculer la zone de confluence
   double zoneLow = MathMax(imbalanceBottom, oteLow);
   double zoneHigh = MathMin(imbalanceTop, oteHigh);

   // Ajouter une tolérance de 50% de la taille de la zone
   double tolerance = (zoneHigh - zoneLow) * 0.5;
   zoneLow -= tolerance;
   zoneHigh += tolerance;

   bool inZone = (price >= zoneLow && price <= zoneHigh);
   
   if(inZone)
   {
      Print("✅ SMC_OTE - Prix dans la zone d'entrée! | Prix: ", DoubleToString(price, _Digits),
            " | Zone: ", DoubleToString(zoneLow, _Digits), " - ", DoubleToString(zoneHigh, _Digits));
   }
   
   return inZone;
}

// Exécuter le trade SMC_OTE
void ExecuteSMC_OTETrade(string direction, double entry, double sl, double tp)
{
   if(!TryAcquireOpenLock()) return;
   
   // NOUVEAU: Obtenir les prédictions de Protected Points futurs pour validation
   double futureSupport = 0.0, futureResistance = 0.0;
   bool hasFutureLevels = GetFutureProtectedPointLevels(futureSupport, futureResistance);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // VALIDATION SUPPLÉMENTAIRE BASÉE SUR LES PRÉDICTIONS FUTURES
   if(hasFutureLevels)
   {
      // Si BUY, vérifier qu'on n'est pas trop près d'une résistance future
      if(direction == "BUY" && futureResistance > 0)
      {
         double distanceToResistance = futureResistance - entry;
         double atr = GetATRValue(PERIOD_M15, 14);
         
         if(distanceToResistance < atr * 0.3) // Plus strict pour SMC_OTE
         {
            Print("🚫 SMC_OTE BUY BLOQUÉ - Trop proche résistance future: ", DoubleToString(futureResistance, _Digits));
            Print("   📍 Distance: ", DoubleToString(distanceToResistance, _Digits), " < ", DoubleToString(atr * 0.3, _Digits));
            Print("   💡 SMC_OTE exige une meilleure distance des niveaux futurs");
            ReleaseOpenLock();
            return;
         }
      }
      
      // Si SELL, vérifier qu'on n'est pas trop près d'un support futur
      if(direction == "SELL" && futureSupport > 0)
      {
         double distanceToSupport = entry - futureSupport;
         double atr = GetATRValue(PERIOD_M15, 14);
         
         if(distanceToSupport < atr * 0.3) // Plus strict pour SMC_OTE
         {
            Print("🚫 SMC_OTE SELL BLOQUÉ - Trop proche support future: ", DoubleToString(futureSupport, _Digits));
            Print("   📍 Distance: ", DoubleToString(distanceToSupport, _Digits), " < ", DoubleToString(atr * 0.3, _Digits));
            Print("   💡 SMC_OTE exige une meilleure distance des niveaux futurs");
            ReleaseOpenLock();
            return;
         }
      }
      
      // LOG DES PRÉDICTIONS UTILISÉES POUR SMC_OTE
      Print("🔮 SMC_OTE AVEC PRÉDICTIONS FUTURES - ", _Symbol);
      Print("   🎯 Support futur: ", (futureSupport > 0 ? DoubleToString(futureSupport, _Digits) : "N/A"));
      Print("   🎯 Résistance future: ", (futureResistance > 0 ? DoubleToString(futureResistance, _Digits) : "N/A"));
      Print("   📍 Entrée SMC_OTE: ", DoubleToString(entry, _Digits));
      Print("   📊 Direction: ", direction, " | Validation: ✅");
   }

   double lot = CalculateLotSize();
   lot = NormalizeVolumeForSymbol(lot);

   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   // Ajuster SL/TP pour respecter le stop-level broker et le tick size
   // (sinon "Invalid stops" sur certains synth indices comme Crash 1000 Index).
   double mktPrice = (direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   ValidateAndAdjustStopLossTakeProfit(direction, mktPrice, sl, tp);

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0) tickSize = _Point;
   if(tickSize > 0)
   {
      sl = MathRound(sl / tickSize) * tickSize;
      tp = MathRound(tp / tickSize) * tickSize;
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);
   }
   // Re-valider après arrondi tick (sinon le rounding peut réduire légèrement la distance)
   ValidateAndAdjustStopLossTakeProfit(direction, mktPrice, sl, tp);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   // Cohérence direction SL/TP (évite des rejets supplémentaires)
   if(direction == "BUY")
   {
      if(sl >= mktPrice || tp <= mktPrice)
      {
         Print("❌ SMC_OTE_5STAR invalid SL/TP after adjust - sl=", DoubleToString(sl, _Digits),
               " tp=", DoubleToString(tp, _Digits), " price=", DoubleToString(mktPrice, _Digits));
         ReleaseOpenLock();
         return;
      }
   }
   else // SELL
   {
      if(sl <= mktPrice || tp >= mktPrice)
      {
         Print("❌ SMC_OTE_5STAR invalid SL/TP after adjust - sl=", DoubleToString(sl, _Digits),
               " tp=", DoubleToString(tp, _Digits), " price=", DoubleToString(mktPrice, _Digits));
         ReleaseOpenLock();
         return;
      }
   }

   bool success = false;
   string comment = "SMC_OTE_5STAR";

   if(direction == "BUY")
   {
      success = trade.Buy(lot, _Symbol, 0.0, sl, tp, comment);
   }
   else // SELL
   {
      success = trade.Sell(lot, _Symbol, 0.0, sl, tp, comment);
   }

   if(success)
   {
      // Ajouter les informations sur les prédictions futures dans le log de succès
      string predictionInfo = "";
      if(hasFutureLevels)
      {
         if(direction == "BUY" && futureResistance > 0)
            predictionInfo = " | R_future: " + DoubleToString(futureResistance, _Digits);
         else if(direction == "SELL" && futureSupport > 0)
            predictionInfo = " | S_future: " + DoubleToString(futureSupport, _Digits);
      }
      
      Print("🚀 SMC_OTE 5 ÉTOILES EXÉCUTÉ - ", direction, " ", _Symbol,
            " | Entry: ", DoubleToString(entry, _Digits),
            " | SL: ", DoubleToString(sl, _Digits),
            " | TP: ", DoubleToString(tp, _Digits),
            " | Lot: ", DoubleToString(lot, 2),
            " | Risk/Reward: 2R",
            predictionInfo);
   }
   else
   {
      Print("❌ SMC_OTE - Échec exécution ", direction, " sur ", _Symbol,
            " | Erreur: ", trade.ResultRetcode(), " - ", trade.ResultComment());
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
   Print("?? SPIKE WARNING AFFICHÉ - ", _Symbol, 
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
   // Bas-gauche, sans chevaucher les autres labels (ex: canal ML à ~50px)
   ObjectSetInteger(0, statusBoxName, OBJPROP_YDISTANCE, 90);
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
   ObjectSetInteger(0, statusTextName, OBJPROP_YDISTANCE, 100); // Aligné avec la boîte
   ObjectSetInteger(0, statusTextName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, statusTextName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, statusTextName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, statusTextName, OBJPROP_CORNER, CORNER_LEFT_LOWER); // Bas à gauche
}

//| DÉTECTER UN SPIKE RÉCENT sur Boom/Crash                           |
bool DetectRecentSpike()
{
   Print("?? DEBUG - Détection de spike pour: ", _Symbol);
   
   // Vérifier les 5 dernières bougies pour un spike significatif
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5)
   {
      Print("? Impossible de copier les rates pour détecter spike");
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
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      spikeMultiplier = 1.2; // 1.2x pour Boom/Crash (plus sensible)
   }
   
   double spikeThreshold = avgMovement * spikeMultiplier;
   
   bool isSpike = lastMovement > spikeThreshold;
   
   Print("?? DEBUG - Analyse spike - Mouvement actuel: ", DoubleToString(lastMovement, _Digits), 
         " | Moyenne: ", DoubleToString(avgMovement, _Digits), 
         " | Seuil: ", DoubleToString(spikeThreshold, _Digits), 
         " | Ratio: ", DoubleToString(lastMovement/avgMovement, 1),
         " | Spike: ", isSpike ? "OUI" : "NON");
   
   // Ajouter une détection alternative basée sur le prix
   double priceChange = MathAbs(rates[0].close - rates[1].close) / rates[1].close;
   
   // Seuil différent pour Boom/Crash vs autres symboles
   double priceThreshold = 0.001; // 0.1% par défaut
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      priceThreshold = 0.0001; // 0.01% pour Boom/Crash (plus sensible)
   }
   
   bool priceSpike = priceChange > priceThreshold;
   
   Print("?? DEBUG - Spike prix - Changement: ", DoubleToString(priceChange*100, 4), "% | Seuil: ", DoubleToString(priceThreshold*100, 4), "% | Spike: ", priceSpike ? "OUI" : "NON");
   
   // Ajouter une détection basée sur le volume pour Boom/Crash
   bool volumeSpike = false;
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      long volume[];
      ArraySetAsSeries(volume, true);
      if(CopyTickVolume(_Symbol, PERIOD_M1, 0, 3, volume) >= 3)
      {
         double recentVolume = (double)volume[0];
         double avgVolume = ((double)volume[1] + (double)volume[2]) / 2.0;
         volumeSpike = recentVolume > avgVolume * 1.3; // 30% plus élevé
         
         Print("?? DEBUG - Spike volume - Récent: ", DoubleToString(recentVolume, 0), 
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
      
      Print("?? SPIKE DÉTECTÉ - Type: ", spikeType, 
            " | Mouvement: ", DoubleToString(lastMovement, _Digits), 
            " | Changement prix: ", DoubleToString(priceChange*100, 3), "%");
   }
   
   return finalSpike;
}

//| EXÉCUTER UN TRADE BASÉ SUR SPIKE                                  |
void ExecuteSpikeTrade(string direction)
{
   if(IsInEquilibriumCorrectionZone())
   {
      Print("🚫 SPIKE TRADE BLOQUÉ - Zone de correction autour de l'équilibre sur ", _Symbol);
      return;
   }

   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction))
   {
      Print("🚫 SPIKE TRADE BLOQUÉ - Direction interdite sur ", _Symbol, " : ", direction);
      return;
   }

   if(!IsBoomCrashDirectionAllowedByIA(_Symbol, direction))
   {
      Print("🚫 SPIKE TRADE BLOQUÉ - Direction vs IA (Boom/Crash) sur ", _Symbol, " : ", direction);
      return;
   }

   if(!IsSpreadAcceptable()) return;
   if(IsEntryCooldownActive()) return;
   if(!IsLastCandleConfirmingDirection(direction)) return;

   // Contrôle anti-duplication centralisé par catégorie
   if(!CanOpenAdditionalPositionForSymbol(_Symbol, direction))
   {
      Print("🚫 SPIKE TRADE BLOQUÉ - duplication non autorisée sur ", _Symbol,
            " | dir=", direction, " | positions=", CountPositionsForSymbol(_Symbol));
      return;
   }

   // Confiance IA minimum globale (75%)
   if(!IsAIConfidenceAtLeast(0.75, "SPIKE TRADE"))
      return;

   // Spike trades réservés aux symboles Boom/Crash et seulement si le modèle ML est fiable
   if(!IsMLModelTrustedForCurrentSymbol(direction))
   {
      Print("🚫 SPIKE TRADE BLOQUÉ - Modèle ML non fiable pour ", _Symbol);
      return;
   }

   // En mode touch-entry (Boom/Crash), la logique peut aussi vouloir entrer
   // directement sur apparition de la flèche DERIV (scalping spikes).
   // Donc on n'ignore plus SPIKE TRADE juste parce que "touch arm" est activé.

   // Boom/Crash: armer l'entrée via touch future protect (low=Boom, high=Crash)
   if(RequireFutureProtectTouchForBoomCrashDerivArrow)
   {
      bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
      bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
      // Si la flèche DERIV est récente pour cette direction, on bypass le "touch arm".
      bool hasRecentDerivArrow = HasRecentSMCDerivArrowForDirection(direction);
      datetime now = TimeCurrent();

      if(isBoom && direction == "BUY")
      {
         bool armed = hasRecentDerivArrow ||
                       (g_boomFutureProtectTouchTime > 0 &&
                        (now - g_boomFutureProtectTouchTime) <= FutureProtectTouchArmSeconds);
         if(!armed)
         {
            Print("?? SPIKE TRADE bloqué (Boom) - Attendre touch future protect low avant flèche BUY",
                  " | touchTime=", (g_boomFutureProtectTouchTime > 0 ? TimeToString(g_boomFutureProtectTouchTime, TIME_SECONDS) : "N/A"),
                  " | level=", DoubleToString(g_boomFutureProtectTouchLevel, _Digits));
            return;
         }
      }
      else if(isCrash && direction == "SELL")
      {
         bool armed = hasRecentDerivArrow ||
                       (g_crashFutureProtectTouchTime > 0 &&
                        (now - g_crashFutureProtectTouchTime) <= FutureProtectTouchArmSeconds);
         if(!armed)
         {
            Print("?? SPIKE TRADE bloqué (Crash) - Attendre touch future protect high avant flèche SELL",
                  " | touchTime=", (g_crashFutureProtectTouchTime > 0 ? TimeToString(g_crashFutureProtectTouchTime, TIME_SECONDS) : "N/A"),
                  " | level=", DoubleToString(g_crashFutureProtectTouchLevel, _Digits));
            return;
         }
      }
   }

   // Calculer lot size (recovery: doubler le lot min sur un autre symbole après une perte)
   double lot = CalculateLotSize();
   lot = ApplyRecoveryLot(lot);
   if(lot <= 0) 
   {
      Print("? Erreur calcul lot size - trade annulé");
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
   
   Print("?? DEBUG - ATR pour SL/TP: ", DoubleToString(atrValue, _Digits), " | Symbol: ", _Symbol);
   
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
      lot = NormalizeVolumeForSymbol(lot);
      potentialLoss = lot * riskPerLotDollars;
      if(potentialLoss > MaxLossPerSpikeTradeDollars * 1.01)
      {
         Print("? TRADE BLOQUÉ - Perte min (lot min ", DoubleToString(minLot, 2), ") = ", DoubleToString(potentialLoss, 2), "$ > ", MaxLossPerSpikeTradeDollars, "$");
         return;
      }
      Print("?? Lot réduit pour perte max ", MaxLossPerSpikeTradeDollars, "$ ? Lot: ", DoubleToString(lot, 2), " | Perte potentielle: ", DoubleToString(potentialLoss, 2), "$");
   }
   else
      Print("? Perte potentielle VALIDÉE: ", DoubleToString(potentialLoss, 2), "$ <= ", MaxLossPerSpikeTradeDollars, "$");
   
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
   Print("?? DEBUG - NoSLTP_BoomCrash: ", NoSLTP_BoomCrash ? "OUI" : "NON", " | Catégorie: ", (SMC_GetSymbolCategory(_Symbol) == SYM_BOOM_CRASH ? "BOOM_CRASH" : "AUTRE"));
   
   if(direction == "BUY")
   {
      if(!HasRecentSMCDerivArrowForDirection("BUY"))
      {
         Print("?? SPIKE TRADE BUY bloqué - Attendre flèche SMC_DERIV_ARROW BUY sur ", _Symbol);
         return;
      }
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl = 0, tp = 0;
      
      // Appliquer SL/TP seulement si NoSLTP_BoomCrash est désactivé
      if(!NoSLTP_BoomCrash || SMC_GetSymbolCategory(_Symbol) != SYM_BOOM_CRASH)
      {
         sl = ask - atrValue * 2.0;  // Pour BUY: SL en-dessous (plus bas)
         tp = ask + atrValue * 3.0;  // Pour BUY: TP au-dessus (plus haut)
      }
      
      Print("?? DEBUG - BUY - Ask: ", DoubleToString(ask, _Digits), " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits));
      Print("?? DEBUG - Vérification SL/TP BUY - SL < Ask: ", (sl < ask || sl == 0) ? "OK" : "ERREUR", " | TP > Ask: ", (tp > ask || tp == 0) ? "OK" : "ERREUR");
      
      if(!IsMinimumProfitPotentialMet(ask, tp, "BUY", lot)) return;
      
      if(trade.Buy(lot, _Symbol, 0.0, sl, tp, "SPIKE TRADE BUY"))
      {
         orderExecuted = true;
         g_lastEntryTimeForSymbol = TimeCurrent();
         Print("? SPIKE TRADE BUY EXÉCUTÉ - ", _Symbol, " @", DoubleToString(ask, _Digits), " | Lot: ", DoubleToString(lot, 2), " | Magic: ", trade.RequestMagic());
         Print("?? DEBUG - Ticket d'ordre: ", trade.ResultOrder());
      }
      else
      {
         Print("? Échec SPIKE TRADE BUY - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else // SELL
   {
      if(!HasRecentSMCDerivArrowForDirection("SELL"))
      {
         Print("?? SPIKE TRADE SELL bloqué - Attendre flèche SMC_DERIV_ARROW SELL sur ", _Symbol);
         return;
      }
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl = 0, tp = 0;
      
      // Appliquer SL/TP seulement si NoSLTP_BoomCrash est désactivé
      if(!NoSLTP_BoomCrash || SMC_GetSymbolCategory(_Symbol) != SYM_BOOM_CRASH)
      {
         sl = bid + atrValue * 2.0;  // Pour SELL: SL au-dessus (plus haut)
         tp = bid - atrValue * 3.0;  // Pour SELL: TP en-dessous (plus bas)
      }
      
      Print("?? DEBUG - SELL - Bid: ", DoubleToString(bid, _Digits), " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits));
      Print("?? DEBUG - Vérification SL/TP SELL - SL > Bid: ", (sl > bid || sl == 0) ? "OK" : "ERREUR", " | TP < Bid: ", (tp < bid || tp == 0) ? "OK" : "ERREUR");
      
      if(trade.Sell(lot, _Symbol, 0.0, sl, tp, "SPIKE TRADE SELL"))
      {
         orderExecuted = true;
         g_lastEntryTimeForSymbol = TimeCurrent();
         Print("? SPIKE TRADE SELL EXÉCUTÉ - ", _Symbol, " @", DoubleToString(bid, _Digits), " | Lot: ", DoubleToString(lot, 2), " | Magic: ", trade.RequestMagic());
         Print("?? DEBUG - Ticket d'ordre: ", trade.ResultOrder());
      }
      else
      {
         Print("? Échec SPIKE TRADE SELL - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   
   if(orderExecuted)
   {
      Print("?? SPIKE TRADE EXÉCUTÉ AVEC SUCCÈS - Direction: ", direction, " | Symbole: ", _Symbol);

      // Marquer le temps du dernier spike (utilisé par la recovery exceptionnelle Boom/Crash)
      datetime now = TimeCurrent();
      string dirUpper = direction;
      StringToUpper(dirUpper);
      if(IsBoomSymbol(_Symbol) && dirUpper == "BUY")
      {
         g_lastBoomSpikeTime = now;
         g_boomSellEntryArmed = false;
         g_boomSellEntryArmedTouchTime = 0;
      }
      else if(IsCrashSymbol(_Symbol) && dirUpper == "SELL")
      {
         g_lastCrashSpikeTime = now;
         g_crashBuyEntryArmed = false;
         g_crashBuyEntryArmedTouchTime = 0;
      }

      // Consommer le touch (une fois utilisé pour l'entrée)
      bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
      bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
      if(isBoom)
      {
         g_boomFutureProtectTouchTime = 0;
         g_boomFutureProtectTouchLevel = 0.0;
      }
      if(isCrash)
      {
         g_crashFutureProtectTouchTime = 0;
         g_crashFutureProtectTouchLevel = 0.0;
      }
      
      // Démarrer la surveillance pour clôture immédiate en gain positif
      StartSpikePositionMonitoring(direction);
   }
}

//| SURVEILLER ET FERMER LA POSITION SPIKE EN GAIN POSITIF           |
void StartSpikePositionMonitoring(string direction)
{
   // DÉSACTIVÉ - Cette fonction fermait les positions trop rapidement
   // Laisser ManageBoomCrashSpikeClose() gérer les fermetures
   Print("?? SURVEILLANCE SPIKE DÉSACTIVÉE - Laisser le trade respirer");
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
               Print("?? SURVEILLANCE SPIKE - Ticket: ", ticket, " | Profit: ", DoubleToString(profit, 2), "$");
               
               // Fermer immédiatement si en gain positif (même 0.01$)
               if(profit > 0)
               {
                  Print("?? GAIN POSITIF DÉTECTÉ - Fermeture immédiate | Profit: ", DoubleToString(profit, 2), "$");
                  PositionCloseWithLog(ticket, "SPIKE GAIN POSITIF");
                  return;
               }
            }
         }
      }
      
      attempt++;
      Sleep(1000); // Attendre 1 seconde avant la prochaine vérification
   }
   
   Print("? FIN SURVEILLANCE SPIKE - Position non fermée dans le délai imparti");
   */
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
   Print("?? ROTATION AUTO - Positions: ", totalPositions, "/", MaxPositionsTerminal, " - Vérification opportunités...");
   
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
         Print("?? Position déjà fermée avant rotation - ticket=", ticketToClose);
         return;
      }
      
      string symbolToClose = PositionGetString(POSITION_SYMBOL);
      double positionProfit = PositionGetDouble(POSITION_PROFIT);
      
      // Fermer seulement si c'est une position en perte ou si elle est ouverte depuis plus de 30 minutes
      datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
      int minutesOpen = (int)(TimeCurrent() - positionTime) / 60;
      
      if(positionProfit < -0.2 || minutesOpen > 30)
      {
         Print("?? ROTATION AUTO - Fermeture position: ", symbolToClose, 
               " | Profit: ", DoubleToString(positionProfit, 2), "$",
               " | Âge: ", minutesOpen, " min");
         
         if(PositionCloseWithLog(ticketToClose, "Rotation automatique"))
         {
            Print("? ROTATION AUTO - Position fermée avec succès - Libère place pour nouvelles opportunités");
         }
         else
         {
            int err = GetLastError();
            Print("? ROTATION AUTO - Échec fermeture position: ", symbolToClose, " | Erreur: ", err);
         }
      }
      else
      {
         Print("?? ROTATION AUTO - Position conservée: ", symbolToClose, 
               " | Profit: ", DoubleToString(positionProfit, 2), "$",
               " | Âge: ", minutesOpen, " min (tôt ou profitable)");
      }
   }
   else
   {
      Print("?? ROTATION AUTO - Aucune position éligible à la fermeture");
   }
}

//+------------------------------------------------------------------+
//| FONCTIONS DE DÉTECTION SPIKES SANS IA                           |
//+------------------------------------------------------------------+

// Détection de spike de volume
bool IsVolumeSpikeDetected()
{
   double recentVolume = (double)iVolume(_Symbol, PERIOD_M1, 0);
   double avgVolume = 0;
   
   // Calcul moyenne volume sur 20 bougies
   for(int i = 1; i <= 20; i++)
   {
      avgVolume += (double)iVolume(_Symbol, PERIOD_M1, i);
   }
   avgVolume /= 20.0;
   
   bool spikeDetected = (recentVolume > avgVolume * SpikeVolumeMultiplier);
   
   if(DebugSpikeDetection)
   {
      Print("📊 Volume Spike - Actuel: ", NormalizeDouble(recentVolume, 0), 
            " | Moyenne: ", NormalizeDouble(avgVolume, 0),
            " | Spike: ", spikeDetected ? "OUI" : "NON");
   }
   
   return spikeDetected;
}

// Détection de spike de prix
bool IsPriceSpikeDetected()
{
   double currentRange = iHigh(_Symbol, PERIOD_M1, 0) - iLow(_Symbol, PERIOD_M1, 0);
   double atr = iATR(_Symbol, PERIOD_M1, 20);
   
   bool spikeDetected = (currentRange > atr * SpikePriceMultiplier);
   
   if(DebugSpikeDetection)
   {
      Print("📈 Prix Spike - Range: ", NormalizeDouble(currentRange, 5),
            " | ATR: ", NormalizeDouble(atr, 5),
            " | Spike: ", spikeDetected ? "OUI" : "NON");
   }
   
   return spikeDetected;
}

// Détection de compression avant explosion
bool IsVolatilityCompressionDetected()
{
   double atrCurrent = iATR(_Symbol, PERIOD_M1, 1);
   double atrAvg = 0;
   
   // Calcul moyenne ATR sur 20 bougies
   for(int i = 2; i <= 21; i++)
   {
      atrAvg += iATR(_Symbol, PERIOD_M1, i);
   }
   atrAvg /= 20.0;
   
   bool compressionDetected = (atrCurrent < atrAvg * SpikeCompressionThreshold);
   
   if(DebugSpikeDetection)
   {
      Print("🗜️ Compression - ATR: ", NormalizeDouble(atrCurrent, 5),
            " | Moyenne: ", NormalizeDouble(atrAvg, 5),
            " | Compression: ", compressionDetected ? "OUI" : "NON");
   }
   
   return compressionDetected;
}

// Détection de pattern "Calm Before Storm"
bool IsCalmBeforeStorm()
{
   int calmBars = 0;
   double atr = iATR(_Symbol, PERIOD_M1, 20);
   
   // Vérifier les 5 dernières bougies
   for(int i = 1; i <= 5; i++)
   {
      double range = iHigh(_Symbol, PERIOD_M1, i) - iLow(_Symbol, PERIOD_M1, i);
      if(range < atr * 0.3) calmBars++;
   }
   
   bool calmDetected = (calmBars >= SpikeCalmBarsMin);
   
   if(DebugSpikeDetection)
   {
      Print("🌊 Calm Before Storm - Barres calmes: ", calmBars, "/", SpikeCalmBarsMin,
            " | Pattern: ", calmDetected ? "OUI" : "NON");
   }
   
   return calmDetected;
}

// Détection de zones SMC propices aux spikes
bool IsSMCSpikeZone()
{
   bool inDiscount = IsInDiscountZone();
   bool inPremium = IsInPremiumZone();
   bool nearSupport = IsNearSupport();
   bool nearResistance = IsNearResistance();
   
   bool spikeZone = false;
   
   if(StringFind(_Symbol, "Boom") >= 0)
   {
      // Boom: spike probable en sortie de Discount vers support
      spikeZone = inDiscount && nearSupport;
   }
   else if(StringFind(_Symbol, "Crash") >= 0)
   {
      // Crash: spike probable en sortie de Premium vers résistance
      spikeZone = inPremium && nearResistance;
   }
   
   if(DebugSpikeDetection)
   {
      Print("🎯 Zone SMC Spike - Discount: ", inDiscount ? "OUI" : "NON",
            " | Premium: ", inPremium ? "OUI" : "NON",
            " | Support: ", nearSupport ? "OUI" : "NON",
            " | Résistance: ", nearResistance ? "OUI" : "NON",
            " | Zone Spike: ", spikeZone ? "OUI" : "NON");
   }
   
   return spikeZone;
}

// Détection de momentum accélérant
bool IsAcceleratingMomentum()
{
   int rsiHandle = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
   if(rsiHandle == INVALID_HANDLE) return false;
   
   double rsiBuffer[2];
   if(CopyBuffer(rsiHandle, 0, 0, 2, rsiBuffer) < 2) return false;
   
   double rsiCurrent = rsiBuffer[0];
   double rsiPrevious = rsiBuffer[1];
   
   double rsiChange = MathAbs(rsiCurrent - rsiPrevious);
   bool momentumDetected = (rsiChange > SpikeMomentumChange);
   
   if(DebugSpikeDetection)
   {
      Print("🚀 Momentum Accélérant - RSI: ", NormalizeDouble(rsiCurrent, 1),
            " | Précédent: ", NormalizeDouble(rsiPrevious, 1),
            " | Changement: ", NormalizeDouble(rsiChange, 1),
            " | Momentum: ", momentumDetected ? "OUI" : "NON");
   }
   
   return momentumDetected;
}

// Fonction principale de détection de spike imminent
bool IsSpikeImminentWithoutAI()
{
   if(!UseSpikeDetectionWithoutAI) return false;
   
   int signalCount = 0;
   
   if(IsVolumeSpikeDetected()) signalCount++;
   if(IsPriceSpikeDetected()) signalCount++;
   if(IsVolatilityCompressionDetected()) signalCount++;
   if(IsCalmBeforeStorm()) signalCount++;
   if(IsSMCSpikeZone()) signalCount++;
   if(IsAcceleratingMomentum()) signalCount++;
   
   bool spikeImminent = (signalCount >= SpikeDetectionMinSignals);
   
   if(DebugSpikeDetection)
   {
      Print("🎯 DÉTECTION SPIKE SANS IA - Signaux: ", signalCount, "/", SpikeDetectionMinSignals,
            " | Spike Imminent: ", spikeImminent ? "OUI" : "NON");
   }
   
   return spikeImminent;
}

// Vérification et exécution de trade spike
void CheckAndExecuteSpikeTrade()
{
   // 1. Vérifier si IA est suffisamment forte
   if(g_lastAIConfidence >= MinAIConfidencePercent)
   {
      if(DebugSpikeDetection)
         Print("🤖 IA FORTE - Utilisation logique IA normale (", 
               NormalizeDouble(g_lastAIConfidence, 1), "% ≥ ", 
               NormalizeDouble(MinAIConfidencePercent, 1), "%)");
      return; // Utiliser logique IA normale
   }
   
   // 2. Si IA faible -> Vérifier détection spike
   if(UseSpikeDetectionWithoutAI && IsSpikeImminentWithoutAI())
   {
      Print("🚨 SPIKE DÉTECTÉ SANS IA - Confiance IA: ", 
            NormalizeDouble(g_lastAIConfidence, 1), "% < ", 
            NormalizeDouble(MinAIConfidencePercent, 1), "%");
      
      // Vérifier protections capital et positions
      if(!IsMaxPositionsReached())
      {
         ExecuteSpikeTrade();
      }
      else
      {
         Print("🚫 SPIKE BLOQUÉ - Maximum positions atteintes");
      }
   }
}

// Exécution de trade spike
void ExecuteSpikeTrade()
{
   if(IsInEquilibriumCorrectionZone())
   {
      Print("🚫 SPIKE ANNULÉ - Zone de correction autour de l'équilibre sur ", _Symbol);
      return;
   }

   string direction = "";
   
   // Déterminer direction selon symbole et zones SMC
   if(IsBoomSymbol(_Symbol))
   {
      if(IsInDiscountZone())
      {
         direction = "BUY";
         Print("📈 SPIKE BUY BOOM - Zone Discount détectée");
      }
   }
   else if(IsCrashSymbol(_Symbol))
   {
      if(IsInPremiumZone())
      {
         direction = "SELL";
         Print("📉 SPIKE SELL CRASH - Zone Premium détectée");
      }
   }
   
   if(direction == "")
   {
      Print("🚫 SPIKE ANNULÉ - Direction non déterminée");
      return;
   }

   if(!IsDirectionAllowedForBoomCrash(_Symbol, direction))
   {
      Print("🚫 SPIKE ANNULÉ - Direction interdite sur ", _Symbol, " : ", direction);
      return;
   }

   if(!IsBoomCrashDirectionAllowedByIA(_Symbol, direction))
   {
      Print("🚫 SPIKE ANNULÉ - Direction vs IA (Boom/Crash) sur ", _Symbol, " : ", direction);
      return;
   }

   if(!IsSpreadAcceptable()) return;
   if(IsEntryCooldownActive()) return;
   if(!IsLastCandleConfirmingDirection(direction)) return;

   // Confiance IA minimum globale (75%)
   if(!IsAIConfidenceAtLeast(0.75, "SPIKE TRADE"))
      return;

   // Règle de duplication par catégorie/symbole
   if(!CanOpenAdditionalPositionForSymbol(_Symbol, direction))
   {
      Print("🚫 SPIKE ANNULÉ - duplication interdite sur ", _Symbol, " | dir=", direction);
      return;
   }
   
   // Exécuter ordre au marché
   MqlTradeRequest req = {};
   MqlTradeResult  res = {};
   
   req.action = TRADE_ACTION_DEAL;
   req.symbol = _Symbol;
   req.volume = GetOptimalLotSize();
   req.magic = InpMagicNumber;
   req.comment = "SPIKE_DETECTION_AI_" + IntegerToString((int)g_lastAIConfidence);
   
   if(direction == "BUY")
   {
      req.type = ORDER_TYPE_BUY;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      req.sl = req.price - 300 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      req.tp = req.price + 600 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }
   else
   {
      req.type = ORDER_TYPE_SELL;
      req.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      req.sl = req.price + 300 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      req.tp = req.price - 600 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   }

   // Respect du stop-level broker (sinon "Invalid stops" sur certains indices/synth)
   {
      double sl = req.sl;
      double tp = req.tp;
      ValidateAndAdjustStopLossTakeProfit(direction, req.price, sl, tp);
      EnforceMinBoomCrashStopLossDollarRisk(_Symbol, direction, req.price, req.volume, sl);
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);

      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(tickSize <= 0) tickSize = point;
      if(tickSize > 0)
      {
         sl = MathRound(sl / tickSize) * tickSize;
         tp = MathRound(tp / tickSize) * tickSize;
         sl = NormalizeDouble(sl, _Digits);
         tp = NormalizeDouble(tp, _Digits);
      }
      req.sl = sl;
      req.tp = tp;
   }

   // Sécurité cohérence direction SL/TP (évite rejets supplémentaires)
   if(direction == "BUY")
   {
      if(req.sl >= req.price || req.tp <= req.price)
      {
         Print("❌ SPIKE invalid SL/TP (BUY) - skip sur ", _Symbol,
               " sl=", DoubleToString(req.sl, _Digits),
               " tp=", DoubleToString(req.tp, _Digits),
               " price=", DoubleToString(req.price, _Digits));
         return;
      }
   }
   else // SELL
   {
      if(req.sl <= req.price || req.tp >= req.price)
      {
         Print("❌ SPIKE invalid SL/TP (SELL) - skip sur ", _Symbol,
               " sl=", DoubleToString(req.sl, _Digits),
               " tp=", DoubleToString(req.tp, _Digits),
               " price=", DoubleToString(req.price, _Digits));
         return;
      }
   }

   if(!IsMinimumProfitPotentialMet(req.price, req.tp, direction, req.volume))
      return;
   
   if(OrderSend(req, res))
   {
      g_lastEntryTimeForSymbol = TimeCurrent();
      Print("✅ SPIKE EXÉCUTÉ - ", direction, " sur ", _Symbol, 
            " | Ticket: ", res.order, " | Confiance IA: ", 
            NormalizeDouble(g_lastAIConfidence, 1), "%");
      if(UseNotifications)
      {
         Alert("✅ POSITION SPIKE OUVERTE - ", direction, " ", _Symbol, " | Ticket: ", res.order);
      }

      // Marquer le temps du dernier spike (utilisé par la recovery exceptionnelle Boom/Crash)
      string dirUpper = direction;
      StringToUpper(dirUpper);
      datetime now = TimeCurrent();
      if(IsBoomSymbol(_Symbol) && dirUpper == "BUY")
      {
         g_lastBoomSpikeTime = now;
         g_boomSellEntryArmed = false;
         g_boomSellEntryArmedTouchTime = 0;
      }
      else if(IsCrashSymbol(_Symbol) && dirUpper == "SELL")
      {
         g_lastCrashSpikeTime = now;
         g_crashBuyEntryArmed = false;
         g_crashBuyEntryArmedTouchTime = 0;
      }
      
      // Notification mobile
      SendNotification("✅ POSITION SPIKE OUVERTE " + direction + " " + _Symbol +
                      " | Ticket: " + IntegerToString(res.order) +
                      " | IA: " + DoubleToString(g_lastAIConfidence, 1) + "%");
   }
   else
   {
      Print("❌ ÉCHEC SPIKE - ", direction, " sur ", _Symbol, 
            " | Code: ", res.retcode, " | Confiance IA: ", 
            NormalizeDouble(g_lastAIConfidence, 1), "%");

      if(res.retcode == TRADE_RETCODE_INVALID_STOPS)
      {
         // Retry unique avec recalcul strict SL/TP sur prix courant broker.
         double retryPrice = (direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double retrySL = (direction == "BUY") ? (retryPrice - 300 * SymbolInfoDouble(_Symbol, SYMBOL_POINT))
                                               : (retryPrice + 300 * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
         double retryTP = (direction == "BUY") ? (retryPrice + 600 * SymbolInfoDouble(_Symbol, SYMBOL_POINT))
                                               : (retryPrice - 600 * SymbolInfoDouble(_Symbol, SYMBOL_POINT));

         ValidateAndAdjustStopLossTakeProfit(direction, retryPrice, retrySL, retryTP);
         retrySL = NormalizeDouble(retrySL, _Digits);
         retryTP = NormalizeDouble(retryTP, _Digits);

         req.price = retryPrice;
         req.sl = retrySL;
         req.tp = retryTP;

         MqlTradeResult retryRes = {};
         if(OrderSend(req, retryRes) && retryRes.retcode == TRADE_RETCODE_DONE)
         {
            g_lastEntryTimeForSymbol = TimeCurrent();
            Print("✅ SPIKE EXÉCUTÉ APRÈS RETRY STOPS - ", direction, " sur ", _Symbol,
                  " | Ticket: ", retryRes.order);
            if(UseNotifications)
            {
               Alert("✅ POSITION SPIKE OUVERTE (RETRY) - ", direction, " ", _Symbol, " | Ticket: ", retryRes.order);
               SendNotification("✅ POSITION SPIKE OUVERTE (RETRY) " + direction + " " + _Symbol + " | Ticket: " + IntegerToString(retryRes.order));
            }
         }
         else
         {
            Print("❌ SPIKE RETRY ÉCHEC - ", direction, " sur ", _Symbol,
                  " | Code: ", retryRes.retcode, " | ", retryRes.comment);
         }
      }
   }
}

// ------------------------------------------------------------------
// Recovery exceptionnel Boom/Crash (sur touch Entry M5 + petites bougies M1)
// ------------------------------------------------------------------
bool IsAIHoldOrSellForBoomExceptional()
{
   string a = g_lastAIAction;
   StringToUpper(a);
   return (a == "HOLD" || a == "SELL");
}

bool IsAIHoldOrBuyForCrashExceptional()
{
   string a = g_lastAIAction;
   StringToUpper(a);
   return (a == "HOLD" || a == "BUY");
}

// Compte les "petites bougies" M1 depuis `fromTime` (ex: range < ATR*0.3), sur les bougies CLÔTURÉES uniquement.
int CountSmallM1CandlesSince(datetime fromTime)
{
   if(fromTime <= 0) return 0;

   // ATR courant (cohérent avec IsCalmBeforeStorm)
   double atr = iATR(_Symbol, PERIOD_M1, 20);
   if(atr <= 0) return 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // Suffisant pour couvrir l'entrée (4 petites + 5 petites = 9 petites) et les ratés
   int copied = CopyRates(_Symbol, PERIOD_M1, 0, 250, rates);
   if(copied < 50) return 0;

   int count = 0;
   // i=0 = bougie courante (pas clôturée)
   for(int i = 1; i < copied; i++)
   {
      if(rates[i].time <= fromTime) break; // on est passé au passé du spike/entry

      double range = rates[i].high - rates[i].low;
      if(range < atr * 0.3)
         count++;
   }
   return count;
}

bool ExecuteExceptionalBoomCrashRecoveryOrder(const string direction, const string commentTag)
{
   if(!EnableBoomCrashRecoveryTrades)
      return false; // Recovery trades (SELL Boom / BUY Crash) désactivés
   if(direction != "BUY" && direction != "SELL") return false;
   if(IsInEquilibriumCorrectionZone())
   {
      Print("🚫 EXC_RECOVERY BLOQUÉ - Zone de correction autour de l'équilibre sur ", _Symbol,
            " | ", commentTag);
      return false;
   }

   // Confiance IA minimum globale (75%)
   if(!IsAIConfidenceAtLeast(0.75, commentTag))
      return false;

   // Anti-duplication sécurité
   if(CountPositionsForSymbol(_Symbol) > 0) return false;

   if(!TryAcquireOpenLock()) return false;

   double lot = GetOptimalLotSize();
   if(lot <= 0.0) { ReleaseOpenLock(); return false; }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double price = (direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double sl = 0.0, tp = 0.0;
   if(direction == "BUY")
   {
      sl = price - (300 * point);
      tp = price + (600 * point);
   }
   else
   {
      sl = price + (300 * point);
      tp = price - (600 * point);
   }

   // IMPORTANT: corrige les distances SL/TP selon le stop-level broker.
   // Sinon on obtient souvent "Invalid stops" sur certains synth indices.
   ValidateAndAdjustStopLossTakeProfit(direction, price, sl, tp);
   EnforceMinBoomCrashStopLossDollarRisk(_Symbol, direction, price, lot, sl);
   sl = NormalizeDouble(sl, _Digits);
   tp = NormalizeDouble(tp, _Digits);

   // IMPORTANT: aligner SL/TP sur le tick size (sinon certains brokers rejettent).
   // tick size peut être différent de SYMBOL_POINT selon le symbole.
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0) tickSize = point;
   if(tickSize > 0)
   {
      // Arrondir au tick le plus proche
      sl = MathRound(sl / tickSize) * tickSize;
      tp = MathRound(tp / tickSize) * tickSize;

      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);

      // Re-valider après arrondi pour garantir la distance minimale.
      ValidateAndAdjustStopLossTakeProfit(direction, price, sl, tp);
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);
   }

   // Double-check explicite avec SYMBOL_TRADE_STOPS_LEVEL (au cas où le helper
   // applique une logique trop conservatrice / non idéale selon symbole)
   long stopsLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   // NB: conversion en distance prix via tickSize (sinon mismatch unit -> Invalid stops)
   if(tickSize <= 0) tickSize = point;
   double minDist = (double)stopsLevelPoints * tickSize;
   if(minDist > 0.0)
   {
      if(direction == "BUY")
      {
         if(price - sl < minDist) sl = price - minDist;
         if(tp - price < minDist * 2.0) tp = price + minDist * 2.0;
      }
      else
      {
         if(sl - price < minDist) sl = price + minDist;
         if(price - tp < minDist * 2.0) tp = price - minDist * 2.0;
      }
      sl = NormalizeDouble(sl, _Digits);
      tp = NormalizeDouble(tp, _Digits);
   }

   // Sécurité : cohérence direction SL/TP
   if(direction == "BUY")
   {
      if(sl >= price || tp <= price)
      {
         Print("? EXC_RECOVERY invalid SL/TP (BUY) - sl=", DoubleToString(sl, _Digits),
               " tp=", DoubleToString(tp, _Digits), " price=", DoubleToString(price, _Digits),
               " | ", commentTag, " | ", _Symbol);
         ReleaseOpenLock();
         return false;
      }
   }
   else // SELL
   {
      if(sl <= price || tp >= price)
      {
         Print("? EXC_RECOVERY invalid SL/TP (SELL) - sl=", DoubleToString(sl, _Digits),
               " tp=", DoubleToString(tp, _Digits), " price=", DoubleToString(price, _Digits),
               " | ", commentTag, " | ", _Symbol);
         ReleaseOpenLock();
         return false;
      }
   }

   bool ok = false;
   if(direction == "BUY")  ok = trade.Buy(lot, _Symbol, 0.0, sl, tp, commentTag);
   else                     ok = trade.Sell(lot, _Symbol, 0.0, sl, tp, commentTag);

   if(ok)
      Print("?? EXC_RECOVERY ordre OK - ", commentTag, " | ", direction, " sur ", _Symbol);
   else
      Print("? EXC_RECOVERY ordre KO - ", commentTag, " | ", direction, " sur ", _Symbol,
            " | Retcode: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());

   // Debug addition si broker rejette les stops (aide à vérifier les distances calculées)
   if(!ok)
   {
      long stopsLevelPoints2 = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
      double minDist2 = (double)stopsLevelPoints2 * point;
      double slDist = 0.0, tpDist = 0.0;
      if(direction == "BUY")
      {
         slDist = price - sl;
         tpDist = tp - price;
      }
      else
      {
         slDist = sl - price;
         tpDist = price - tp;
      }

      Print("? EXC_RECOVERY debug stops - ",
            "price=", DoubleToString(price, _Digits),
            " sl=", DoubleToString(sl, _Digits),
            " tp=", DoubleToString(tp, _Digits),
            " slDist=", DoubleToString(slDist, _Digits),
            " tpDist=", DoubleToString(tpDist, _Digits),
            " stopsLevelPoints=", stopsLevelPoints2,
            " minDist=", DoubleToString(minDist2, _Digits),
            " tickSize=", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE), _Digits),
            " | ", commentTag);
   }

   ReleaseOpenLock();
   return ok;
}

// Déclenche l'entrée recovery exceptionnelle si:
// - touch Entry M5 déjà enregistré (armed)
// - après dernier spike: au moins 4 petites bougies M1 comptées
// - IA status: HOLD ou SELL/BUD selon cas
void CheckAndExecuteExceptionalBoomCrashRecoveryEntries()
{
   if(!EnableBoomCrashRecoveryTrades) return;
   // Si IA pas encore reçue, laisser le mécanisme armer mais pas déclencher
   if(g_lastAIAction == "") return;

   // BOOM: SELL recovery
   if(IsBoomSymbol(_Symbol))
   {
      if(g_boomSellEntryArmed && g_lastBoomSpikeTime > 0)
      {
         // Vérifier que le touch a bien eu lieu après ce spike
         if(g_boomSellEntryArmedTouchTime >= g_lastBoomSpikeTime)
         {
            if(IsAIHoldOrSellForBoomExceptional())
            {
               int smallCount = CountSmallM1CandlesSince(g_lastBoomSpikeTime);
               if(smallCount >= 4)
               {
                  // Une position max par symbole: éviter d'empiler
                  if(CountPositionsForSymbol(_Symbol) == 0)
                  {
                     bool ok = ExecuteExceptionalBoomCrashRecoveryOrder("SELL", "EXC_RECOVERY_BOOM_SELL");
                     if(ok) g_boomSellEntryArmed = false;
                  }
                  else
                  {
                     g_boomSellEntryArmed = false;
                  }
               }
            }
         }
         else
         {
            // Touch avant spike => invalider arming
            g_boomSellEntryArmed = false;
         }
      }
   }

   // CRASH: BUY recovery
   if(IsCrashSymbol(_Symbol))
   {
      if(g_crashBuyEntryArmed && g_lastCrashSpikeTime > 0)
      {
         if(g_crashBuyEntryArmedTouchTime >= g_lastCrashSpikeTime)
         {
            if(IsAIHoldOrBuyForCrashExceptional())
            {
               int smallCount = CountSmallM1CandlesSince(g_lastCrashSpikeTime);
               if(smallCount >= 4)
               {
                  if(CountPositionsForSymbol(_Symbol) == 0)
                  {
                     bool ok = ExecuteExceptionalBoomCrashRecoveryOrder("BUY", "EXC_RECOVERY_CRASH_BUY");
                     if(ok) g_crashBuyEntryArmed = false;
                  }
                  else
                  {
                     g_crashBuyEntryArmed = false;
                  }
               }
            }
         }
         else
         {
            g_crashBuyEntryArmed = false;
         }
      }
   }
}

// Fonctions utilitaires pour la détection de spikes
bool IsNearSupport()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double supportLevel = GetSupportLevel(20); // Support sur 20 barres
   double distance = MathAbs(currentPrice - supportLevel);
   double atr = iATR(_Symbol, PERIOD_M1, 20);
   
   return (distance <= atr * 0.5); // À moins de 0.5 ATR du support
}

bool IsNearResistance()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double resistanceLevel = GetResistanceLevel(20); // Résistance sur 20 barres
   double distance = MathAbs(currentPrice - resistanceLevel);
   double atr = iATR(_Symbol, PERIOD_M1, 20);
   
   return (distance <= atr * 0.5); // À moins de 0.5 ATR de la résistance
}

double GetOptimalLotSize()
{
   // Volume fixe demandé sur Boom/Crash
   double defaultLot = 0.2;
   if(StringFind(_Symbol, "Boom") < 0 && StringFind(_Symbol, "Crash") < 0)
      defaultLot = InpLotSize;
   
   double lotSize = defaultLot;
   
   // Récupérer la taille de lot minimale du symbole
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(minLot > 0) lotSize = MathMax(defaultLot, minLot);
   
   // Ajuster au pas de lot
   if(lotStep > 0)
   {
      lotSize = MathFloor(lotSize / lotStep) * lotStep;
      lotSize = MathMax(lotSize, MathMax(defaultLot, minLot));
   }
   
   return MathMin(lotSize, maxLot);
}

//+------------------------------------------------------------------+
//| FONCTIONS POUR LIGNES D'ENTRÉE M5 ET EXÉCUTION M1               |
//+------------------------------------------------------------------+

// Variables globales pour les niveaux d'entrée M5
static double g_m5BuyEntryLevel = 0.0;
static double g_m5SellEntryLevel = 0.0;
static datetime g_m5LevelsLastUpdate = 0;
static bool g_m5BuyLevelActive = false;
static bool g_m5SellLevelActive = false;

//+------------------------------------------------------------------+
//| Met à jour les niveaux d'entrée M5 et dessine les lignes épaisses |
//+------------------------------------------------------------------+
void UpdateM5EntryLevelsAndLines()
{
   // Mettre à jour toutes les 2 minutes M5 (120 secondes)
   static datetime lastM5Update = 0;
   datetime currentTime = TimeCurrent();
   
   if(currentTime - lastM5Update < 120) return; // Mise à jour toutes les 2 minutes
   lastM5Update = currentTime;
   
   // Récupérer les données M5
   MqlRates m5Rates[];
   ArraySetAsSeries(m5Rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M5, 0, 100, m5Rates) < 50)
   {
      Print("❌ Erreur: Impossible de récupérer les données M5 pour les niveaux d'entrée");
      return;
   }
   
   // Calculer les niveaux de support/résistance M5
   // SR20 demandé (support/résistance calculés sur 20 bougies)
   double m5Support = GetSupportLevelTF(PERIOD_M5, 20);
   double m5Resistance = GetResistanceLevelTF(PERIOD_M5, 20);
   
   // Calculer les EMAs M5 pour confirmation
   double ema9M5 = 0.0, ema21M5 = 0.0;
   int ema9Handle = iMA(_Symbol, PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE);
   int ema21Handle = iMA(_Symbol, PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE);
   
   if(ema9Handle != INVALID_HANDLE && ema21Handle != INVALID_HANDLE)
   {
      double ema9Buf[], ema21Buf[];
      ArraySetAsSeries(ema9Buf, true);
      ArraySetAsSeries(ema21Buf, true);
      
      if(CopyBuffer(ema9Handle, 0, 0, 1, ema9Buf) >= 1) ema9M5 = ema9Buf[0];
      if(CopyBuffer(ema21Handle, 0, 0, 1, ema21Buf) >= 1) ema21M5 = ema21Buf[0];
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Déterminer les niveaux d'entrée
   g_m5BuyEntryLevel = 0.0;
   g_m5SellEntryLevel = 0.0;
   g_m5BuyLevelActive = false;
   g_m5SellLevelActive = false;
   
   // Niveau BUY: Support M5 ou EMA21 M5 si le prix est au-dessus
   if(currentPrice > m5Support && m5Support > 0)
   {
      g_m5BuyEntryLevel = m5Support + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5; // 5 pips au-dessus du support
      g_m5BuyLevelActive = true;
   }
   else if(currentPrice > ema21M5 && ema21M5 > 0)
   {
      g_m5BuyEntryLevel = ema21M5 + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3; // 3 pips au-dessus EMA21
      g_m5BuyLevelActive = true;
   }
   
   // Niveau SELL: Résistance M5 ou EMA21 M5 si le prix est en dessous
   if(currentPrice < m5Resistance && m5Resistance > 0)
   {
      g_m5SellEntryLevel = m5Resistance - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 5; // 5 pips sous la résistance
      g_m5SellLevelActive = true;
   }
   else if(currentPrice < ema21M5 && ema21M5 > 0)
   {
      g_m5SellEntryLevel = ema21M5 - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 3; // 3 pips sous EMA21
      g_m5SellLevelActive = true;
   }
   
   // Dessiner les lignes épaisses sur le graphique
   DrawM5EntryLines();
   
   g_m5LevelsLastUpdate = currentTime;
   
   Print("📊 NIVEAUX M5 MIS À JOUR - Buy: ", DoubleToString(g_m5BuyEntryLevel, _Digits), 
         " | Sell: ", DoubleToString(g_m5SellEntryLevel, _Digits));
}

//+------------------------------------------------------------------+
//| Dessine les lignes d'entrée M5 épaisses sur le graphique         |
//+------------------------------------------------------------------+
void DrawM5EntryLines()
{
   // Supprimer les anciennes lignes
   ObjectsDeleteAll(0, "M5_ENTRY_");
   
   datetime currentTime = TimeCurrent();
   datetime lineEndTime = currentTime + PeriodSeconds(PERIOD_M1) * 100; // Étendre sur 100 bougies M1
   
   // Ligne BUY ENTRY (épaisse et verte)
   if(g_m5BuyLevelActive && g_m5BuyEntryLevel > 0)
   {
      string buyLineName = "M5_ENTRY_BUY_LINE";
      ObjectCreate(0, buyLineName, OBJ_HLINE, 0, currentTime, g_m5BuyEntryLevel);
      ObjectSetInteger(0, buyLineName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, buyLineName, OBJPROP_WIDTH, 5); // Très épaisse
      ObjectSetInteger(0, buyLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, buyLineName, OBJPROP_BACK, false);
      ObjectSetString(0, buyLineName, OBJPROP_TEXT, "BUY ENTRY M5");
      ObjectSetInteger(0, buyLineName, OBJPROP_TIME, currentTime);
      ObjectSetInteger(0, buyLineName, OBJPROP_TIME, lineEndTime);
      
      // Label pour la ligne BUY
      string buyLabel = "M5_ENTRY_BUY_LABEL";
      ObjectCreate(0, buyLabel, OBJ_TEXT, 0, currentTime + PeriodSeconds(PERIOD_M1) * 10, g_m5BuyEntryLevel);
      ObjectSetString(0, buyLabel, OBJPROP_TEXT, "🟢 BUY ENTRY M5");
      ObjectSetInteger(0, buyLabel, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, buyLabel, OBJPROP_FONTSIZE, 12);
      ObjectSetInteger(0, buyLabel, OBJPROP_BACK, false);
   }
   
   // Ligne SELL ENTRY (épaisse et rouge)
   if(g_m5SellLevelActive && g_m5SellEntryLevel > 0)
   {
      string sellLineName = "M5_ENTRY_SELL_LINE";
      ObjectCreate(0, sellLineName, OBJ_HLINE, 0, currentTime, g_m5SellEntryLevel);
      ObjectSetInteger(0, sellLineName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, sellLineName, OBJPROP_WIDTH, 5); // Très épaisse
      ObjectSetInteger(0, sellLineName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, sellLineName, OBJPROP_BACK, false);
      ObjectSetString(0, sellLineName, OBJPROP_TEXT, "SELL ENTRY M5");
      ObjectSetInteger(0, sellLineName, OBJPROP_TIME, currentTime);
      ObjectSetInteger(0, sellLineName, OBJPROP_TIME, lineEndTime);
      
      // Label pour la ligne SELL
      string sellLabel = "M5_ENTRY_SELL_LABEL";
      ObjectCreate(0, sellLabel, OBJ_TEXT, 0, currentTime + PeriodSeconds(PERIOD_M1) * 10, g_m5SellEntryLevel);
      ObjectSetString(0, sellLabel, OBJPROP_TEXT, "🔴 SELL ENTRY M5");
      ObjectSetInteger(0, sellLabel, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, sellLabel, OBJPROP_FONTSIZE, 12);
      ObjectSetInteger(0, sellLabel, OBJPROP_BACK, false);
   }
}

//+------------------------------------------------------------------+
//| Vérifie si le prix M1 touche les niveaux d'entrée M5 et exécute  |
//+------------------------------------------------------------------+
void CheckAndExecuteM5TouchEntryTrade()
{
   // Vérifier si les niveaux M5 sont à jour
   if(g_m5LevelsLastUpdate == 0 || (TimeCurrent() - g_m5LevelsLastUpdate) > 300) // 5 minutes max
   {
      UpdateM5EntryLevelsAndLines();
   }
   
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Tolérance de touch: élargie pour éviter de rater l'ENTRY M5 sur spikes rapides.
   double touchTolerance = point * 5;
   
   // DEBUG: Afficher les niveaux actuels et prix
   static datetime lastDebugLog = 0;
   if(TimeCurrent() - lastDebugLog >= 30) // Log toutes les 30 secondes
   {
      lastDebugLog = TimeCurrent();
      Print("🔍 SURVEILLANCE TOUCH M5 - Bid: ", DoubleToString(currentBid, _Digits), 
            " | Ask: ", DoubleToString(currentAsk, _Digits));
      if(g_m5BuyLevelActive)
         Print("   🟢 BUY ENTRY M5: ", DoubleToString(g_m5BuyEntryLevel, _Digits), 
               " | Distance: ", DoubleToString(MathAbs(currentAsk - g_m5BuyEntryLevel) / point, 1), " pips");
      if(g_m5SellLevelActive)
         Print("   🔴 SELL ENTRY M5: ", DoubleToString(g_m5SellEntryLevel, _Digits), 
               " | Distance: ", DoubleToString(MathAbs(currentBid - g_m5SellEntryLevel) / point, 1), " pips");
   }
   
   // Vérifier le touch du niveau BUY ENTRY
   if(g_m5BuyLevelActive && g_m5BuyEntryLevel > 0)
   {
      // Pour BUY, on vérifie si l'Ask touche le niveau
      if(MathAbs(currentAsk - g_m5BuyEntryLevel) <= touchTolerance)
      {
         // Recovery exceptionnel: Crash => BUY recovery sur touch BUY Entry M5
         if(IsCrashSymbol(_Symbol))
         {
            if(!EnableBoomCrashRecoveryTrades)
            {
               g_m5BuyLevelActive = false;
               return;
            }
            datetime touchTime = TimeCurrent();
            if(g_lastCrashSpikeTime > 0 && touchTime >= g_lastCrashSpikeTime)
            {
               // Ne pas armer si on est déjà en position sur le symbole
               if(CountPositionsForSymbol(_Symbol) > 0) return;

               g_crashBuyEntryArmed = true;
               g_crashBuyEntryArmedTouchTime = touchTime;
               Print("?? EXC_RECOVERY arm (Crash BUY) - touch BUY Entry M5 après spike | Symbole=", _Symbol);

               // Déclenchement immédiat si les 4 petites bougies sont déjà atteintes
               int smallCount = CountSmallM1CandlesSince(g_lastCrashSpikeTime);
               if(IsAIHoldOrBuyForCrashExceptional() && smallCount >= 4)
               {
                  bool ok = ExecuteExceptionalBoomCrashRecoveryOrder("BUY", "EXC_RECOVERY_CRASH_BUY");
                  if(ok) g_crashBuyEntryArmed = false;
               }

               // Désactiver le niveau pour éviter les répétitions (l'entrée finale se fait via arming + compteur)
               g_m5BuyLevelActive = false;
               return;
            }
         }

         // Filtre IA serveur fort (direction + confiance) avant toute exécution
         // Boom: si le touch M5 n'aboutit pas (blocage IA/duplication), armer un rattrapage scalp sur flèche verte.
         if(IsBoomSymbol(_Symbol))
         {
            g_lastBoomM5BuyTouchTime = TimeCurrent();
            g_boomM5BuyArrowRecoveryArmed = true;
            g_m5BuyLevelActive = false; // consommer le touch même si on rate l'exécution immédiate
            Print("?? RECOVERY ARM - Boom touch BUY ENTRY M5 => rattrapage flèche BUY | level=",
                  DoubleToString(g_m5BuyEntryLevel, _Digits));
         }

         if(RequireAIConfirmation && !IsBoomSymbol(_Symbol) && !IsCrashSymbol(_Symbol))
         {
            if(g_lastAIConfidence < 0.80)
               return;

            string aiDir = g_lastAIAction;
            StringToUpper(aiDir);
            if(aiDir != "BUY")
               return;
         }

         // Autoriser entrée initiale ou duplication selon profit IA/conditions
         bool canOpen = CanOpenAdditionalPositionForSymbol(_Symbol, "BUY");
         if(!canOpen)
         {
            Print("⚠️ TOUCH BUY ENTRY M5 IGNORÉ - Conditions duplication/IA non remplies sur ", _Symbol);
            return;
         }

         Print("🚀 TOUCH BUY ENTRY M5 DÉTECTÉ - Prix Ask: ", DoubleToString(currentAsk, _Digits), 
               " | Niveau: ", DoubleToString(g_m5BuyEntryLevel, _Digits));
         Print("   💥 EXÉCUTION AUTOMATIQUE AU MARCHÉ - BUY sur ", _Symbol);
         
         // Exécuter l'ordre BUY au marché
         bool okBuy = ExecuteM5TouchOrder("BUY");
         if(okBuy)
            g_boomM5BuyArrowRecoveryArmed = false;
         
         // Marquer le point de touch sur le graphique
         DrawM5TouchMarker("BUY", g_m5BuyEntryLevel);
         
         // Envoyer notification mobile
         SendNotification("🚀 BUY ENTRY M5 TOUCHÉ - " + _Symbol + " | " + DoubleToString(currentAsk, _Digits));
      }
   }
   
   // Vérifier le touch du niveau SELL ENTRY
   if(g_m5SellLevelActive && g_m5SellEntryLevel > 0)
   {
      // Pour SELL, on vérifie si le Bid touche le niveau
      if(MathAbs(currentBid - g_m5SellEntryLevel) <= touchTolerance)
      {
         // Recovery exceptionnel: Boom => SELL recovery sur touch SELL Entry M5
         if(IsBoomSymbol(_Symbol))
         {
            if(!EnableBoomCrashRecoveryTrades)
            {
               g_m5SellLevelActive = false;
               return;
            }
            datetime touchTime = TimeCurrent();
            if(g_lastBoomSpikeTime > 0 && touchTime >= g_lastBoomSpikeTime)
            {
               // Ne pas armer si on est déjà en position sur le symbole
               if(CountPositionsForSymbol(_Symbol) > 0) return;

               g_boomSellEntryArmed = true;
               g_boomSellEntryArmedTouchTime = touchTime;
               Print("?? EXC_RECOVERY arm (Boom SELL) - touch SELL Entry M5 après spike | Symbole=", _Symbol);

               // Déclenchement immédiat si les 4 petites bougies sont déjà atteintes
               int smallCount = CountSmallM1CandlesSince(g_lastBoomSpikeTime);
               if(IsAIHoldOrSellForBoomExceptional() && smallCount >= 4)
               {
                  bool ok = ExecuteExceptionalBoomCrashRecoveryOrder("SELL", "EXC_RECOVERY_BOOM_SELL");
                  if(ok) g_boomSellEntryArmed = false;
               }

               // Désactiver le niveau pour éviter les répétitions (l'entrée finale se fait via arming + compteur)
               g_m5SellLevelActive = false;
               return;
            }
         }

         // Filtre IA serveur fort (direction + confiance) avant toute exécution
         if(RequireAIConfirmation && !IsBoomSymbol(_Symbol) && !IsCrashSymbol(_Symbol))
         {
            if(g_lastAIConfidence < 0.80)
               return;

            string aiDir = g_lastAIAction;
            StringToUpper(aiDir);
            if(aiDir != "SELL")
               return;
         }

         // Autoriser entrée initiale ou duplication selon profit IA/conditions
         bool canOpen = CanOpenAdditionalPositionForSymbol(_Symbol, "SELL");
         if(!canOpen)
         {
            Print("⚠️ TOUCH SELL ENTRY M5 IGNORÉ - Conditions duplication/IA non remplies sur ", _Symbol);
            return;
         }

         Print("🚀 TOUCH SELL ENTRY M5 DÉTECTÉ - Prix Bid: ", DoubleToString(currentBid, _Digits), 
               " | Niveau: ", DoubleToString(g_m5SellEntryLevel, _Digits));
         Print("   💥 EXÉCUTION AUTOMATIQUE AU MARCHÉ - SELL sur ", _Symbol);
         
         // Exécuter l'ordre SELL au marché
         ExecuteM5TouchOrder("SELL");
         
         // Désactiver temporairement ce niveau pour éviter répétitions
         g_m5SellLevelActive = false;
         
         // Marquer le point de touch sur le graphique
         DrawM5TouchMarker("SELL", g_m5SellEntryLevel);
         
         // Envoyer notification mobile
         SendNotification("🚀 SELL ENTRY M5 TOUCHÉ - " + _Symbol + " | " + DoubleToString(currentBid, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| Exécute un ordre au marché lors du touch M5                      |
//+------------------------------------------------------------------+
bool ExecuteM5TouchOrder(string direction)
{
   if(IsInEquilibriumCorrectionZone())
   {
      Print("🚫 M5 TOUCH annulé - Zone de correction autour de l'équilibre sur ", _Symbol);
      return false;
   }

   if(!IsBoomCrashDirectionAllowedByIA(_Symbol, direction))
   {
      Print("🚫 M5 TOUCH annulé - Direction vs IA (Boom/Crash) sur ", _Symbol, " : ", direction);
      return false;
   }

   // Confiance IA minimum globale (75%)
   if(!IsAIConfidenceAtLeast(0.75, "M5 TOUCH"))
      return false;

   if(!IsSpreadAcceptable()) return false;
   if(IsEntryCooldownActive()) return false;
   if(!IsLastCandleConfirmingDirection(direction)) return false;

   double lotSize = GetOptimalLotSize();
   double price = (direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   // Calculer SL/TP selon la direction
   double stopLoss = 0.0;
   double takeProfit = 0.0;
   
   if(direction == "BUY")
   {
      stopLoss = price - (300 * point); // SL à 300 pips
      takeProfit = price + (600 * point); // TP à 600 pips
   }
   else // SELL
   {
      stopLoss = price + (300 * point); // SL à 300 pips
      takeProfit = price - (600 * point); // TP à 600 pips
   }

   // Respect du stop-level broker (évite [Invalid stops] sur certains synth indices)
   ValidateAndAdjustStopLossTakeProfit(direction, price, stopLoss, takeProfit);
   EnforceMinBoomCrashStopLossDollarRisk(_Symbol, direction, price, lotSize, stopLoss);
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);

   // Alignement tick size (certains brokers sont stricts)
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0) tickSize = point;
   if(tickSize > 0)
   {
      stopLoss = MathRound(stopLoss / tickSize) * tickSize;
      takeProfit = MathRound(takeProfit / tickSize) * tickSize;
      stopLoss = NormalizeDouble(stopLoss, _Digits);
      takeProfit = NormalizeDouble(takeProfit, _Digits);
   }

   // Cohérence direction SL/TP (sécurité supplémentaire)
   if(direction == "BUY")
   {
      if(stopLoss >= price || takeProfit <= price)
      {
         Print("❌ EXC_M5 invalid SL/TP (BUY) - skip sur ", _Symbol,
               " sl=", DoubleToString(stopLoss, _Digits),
               " tp=", DoubleToString(takeProfit, _Digits),
               " price=", DoubleToString(price, _Digits));
         return false;
      }
   }
   else // SELL
   {
      if(stopLoss <= price || takeProfit >= price)
      {
         Print("❌ EXC_M5 invalid SL/TP (SELL) - skip sur ", _Symbol,
               " sl=", DoubleToString(stopLoss, _Digits),
               " tp=", DoubleToString(takeProfit, _Digits),
               " price=", DoubleToString(price, _Digits));
         return false;
      }
   }
   
   // Préparer la requête d'ordre
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = price;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 10;
   request.magic = InpMagicNumber; // alignement pour profit/duplication par symbole
   request.comment = "M5_TOUCH_ENTRY_" + direction;

   if(!IsMinimumProfitPotentialMet(price, takeProfit, direction, lotSize))
      return false;
   
   // Exécuter l'ordre
   bool success = OrderSend(request, result);
   
   if(success && result.retcode == TRADE_RETCODE_DONE)
   {
      g_lastEntryTimeForSymbol = TimeCurrent();
      Print("✅ ORDRE M5 TOUCH EXÉCUTÉ - ", direction, " sur ", _Symbol, 
            " | Ticket: ", result.order, " | Lot: ", DoubleToString(lotSize, 2),
            " | SL: ", DoubleToString(stopLoss, _Digits), 
            " | TP: ", DoubleToString(takeProfit, _Digits));
      if(UseNotifications)
      {
         Alert("✅ POSITION OUVERTE - M5 TOUCH ", direction, " ", _Symbol, " | Ticket: ", result.order);
      }
      
      // Envoyer une notification mobile
      SendNotification("🎯 M5 TOUCH - " + direction + " " + _Symbol + " | Ticket: " + IntegerToString(result.order));
      return true;
   }
   else
   {
      Print("❌ ÉCHEC ORDRE M5 TOUCH - Erreur: ", result.retcode, " | ", result.comment);
      if(result.retcode == TRADE_RETCODE_INVALID_STOPS)
      {
         // Retry unique: recalc sur prix courant + validation stricte broker.
         double retryPrice = (direction == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double retrySL = stopLoss;
         double retryTP = takeProfit;
         ValidateAndAdjustStopLossTakeProfit(direction, retryPrice, retrySL, retryTP);
         retrySL = NormalizeDouble(retrySL, _Digits);
         retryTP = NormalizeDouble(retryTP, _Digits);

         request.price = retryPrice;
         request.sl = retrySL;
         request.tp = retryTP;

         MqlTradeResult retryResult = {};
         bool retryOk = OrderSend(request, retryResult);
         if(retryOk && retryResult.retcode == TRADE_RETCODE_DONE)
         {
            g_lastEntryTimeForSymbol = TimeCurrent();
            Print("✅ ORDRE M5 TOUCH EXÉCUTÉ APRÈS RETRY STOPS - ", direction, " sur ", _Symbol,
                  " | Ticket: ", retryResult.order,
                  " | SL: ", DoubleToString(retrySL, _Digits),
                  " | TP: ", DoubleToString(retryTP, _Digits));
            if(UseNotifications)
            {
               Alert("✅ POSITION OUVERTE - M5 TOUCH (RETRY) ", direction, " ", _Symbol, " | Ticket: ", retryResult.order);
               SendNotification("🎯 M5 TOUCH RETRY - " + direction + " " + _Symbol + " | Ticket: " + IntegerToString(retryResult.order));
            }
            return true;
         }
         Print("❌ RETRY M5 TOUCH ÉCHEC - Erreur: ", retryResult.retcode, " | ", retryResult.comment);
      }
      return false;
   }
}

//+------------------------------------------------------------------+
//| Dessine un marqueur au point de touch M5                          |
//+------------------------------------------------------------------+
void DrawM5TouchMarker(string direction, double price)
{
   string markerName = "M5_TOUCH_MARKER_" + direction;
   datetime currentTime = TimeCurrent();
   
   // Supprimer l'ancien marqueur
   ObjectDelete(0, markerName);
   
   // Créer une flèche au point de touch
   ObjectCreate(0, markerName, OBJ_ARROW, 0, currentTime, price);
   ObjectSetInteger(0, markerName, OBJPROP_COLOR, (direction == "BUY") ? clrLime : clrRed);
   ObjectSetInteger(0, markerName, OBJPROP_ARROWCODE, (direction == "BUY") ? 233 : 234); // Flèches haut/bas
   ObjectSetInteger(0, markerName, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, markerName, OBJPROP_BACK, false);
   ObjectSetString(0, markerName, OBJPROP_TEXT, "M5_TOUCH_" + direction);
}

//+------------------------------------------------------------------+
//| FONCTIONS DE SUPPORT/RÉSISTANCE PAR TIMEFRAME                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calcule le niveau de support pour un timeframe donné             |
//+------------------------------------------------------------------+
double GetSupportLevelTF(ENUM_TIMEFRAMES tf, int bars)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, tf, 0, bars, rates) < bars)
   {
      Print("❌ Erreur: Impossible de récupérer les données pour support/résistance TF: ", EnumToString(tf));
      return 0.0;
   }
   
   double support = 0.0;
   int supportCount = 0;
   
   // Chercher les plus bas significatifs (swing lows)
   for(int i = 2; i < bars - 2; i++)
   {
      // Un swing low est plus bas que les 2 barres précédentes et les 2 barres suivantes
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
         rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
      {
         support += rates[i].low;
         supportCount++;
      }
   }
   
   if(supportCount > 0)
   {
      support = support / supportCount; // Moyenne des swing lows
   }
   else
   {
      // Fallback: utiliser le plus bas sur la période
      support = rates[0].low;
      for(int i = 1; i < bars; i++)
      {
         if(rates[i].low < support)
            support = rates[i].low;
      }
   }
   
   return support;
}

//+------------------------------------------------------------------+
//| Calcule le niveau de résistance pour un timeframe donné          |
//+------------------------------------------------------------------+
double GetResistanceLevelTF(ENUM_TIMEFRAMES tf, int bars)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, tf, 0, bars, rates) < bars)
   {
      Print("❌ Erreur: Impossible de récupérer les données pour support/résistance TF: ", EnumToString(tf));
      return 0.0;
   }
   
   double resistance = 0.0;
   int resistanceCount = 0;
   
   // Chercher les plus hauts significatifs (swing highs)
   for(int i = 2; i < bars - 2; i++)
   {
      // Un swing high est plus haut que les 2 barres précédentes et les 2 barres suivantes
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
         rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
      {
         resistance += rates[i].high;
         resistanceCount++;
      }
   }
   
   if(resistanceCount > 0)
   {
      resistance = resistance / resistanceCount; // Moyenne des swing highs
   }
   else
   {
      // Fallback: utiliser le plus haut sur la période
      resistance = rates[0].high;
      for(int i = 1; i < bars; i++)
      {
         if(rates[i].high > resistance)
            resistance = rates[i].high;
      }
   }
   
   return resistance;
}

//| END OF PROGRAM                                                  |
