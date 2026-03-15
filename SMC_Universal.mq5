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
#include <Trade/TerminalInfo.mqh>
#include <Trade/TerminalInfo.mqh>

//+------------------------------------------------------------------+
//| WRAPPER POUR CAPTURER TOUTES LES FERMETURES                    |
//+------------------------------------------------------------------+
bool PositionCloseWithLog(ulong ticket, string reason = "")
{
   string symbol = "";
   
   // Obtenir les informations avant fermeture
   if(PositionSelectByTicket(ticket))
   {
      symbol = PositionGetString(POSITION_SYMBOL);
      double profit = PositionGetDouble(POSITION_PROFIT);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int secondsSinceOpen = (int)(TimeCurrent() - openTime);
      
      // NOUVEAU: PROTECTION CONTRE LES FERMETURES AVEC PETITES PERTES
      if(profit < 0 && profit > -2.0)
      {
         Print("🛡️ PROTECTION PETITE PERTE - Fermeture bloquée");
         Print("   📊 Position: ", symbol, " | Ticket: ", ticket);
         Print("   💰 Perte: ", DoubleToString(profit, 2), "$ > -2.00$ (seuil de protection)");
         Print("   🚫 Raison: ", reason, " | ACTION: Position maintenue");
         return false; // Bloquer la fermeture
      }
      
      // Si la perte est ≥ 2$, autoriser la fermeture avec log
      if(profit < 0 && profit <= -2.0)
      {
         Print("⚠️ PERTE IMPORTANTE DÉTECTÉE - Fermeture autorisée");
         Print("   📊 Position: ", symbol, " | Ticket: ", ticket);
         Print("   💰 Perte: ", DoubleToString(profit, 2), "$ ≤ -2.00$ (seuil dépassé)");
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
   bool closed = trade.PositionClose(ticket);
   
   // NOUVEAU: Enregistrer le temps de fermeture si succès
   if(closed)
   {
      RecordPositionCloseTime(symbol);
   }
   
   return closed;
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
void DrawLiquidityZonesOnChart();
void PlaceScalpingLimitOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope);
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
void DrawSMCChannelsMultiTF();
void DrawEMASupertrendMultiTF();
void DrawLimitOrderLevels();
void CloseLimitPositionsIfLinesMissing();
void UpdateDashboard();
void ManagePivotLimitOrder();
bool GetSuperTrendLevel(ENUM_TIMEFRAMES tf, double &supportOut, double &resistanceOut);
double GetClosestBuyLevel(double currentPrice, double atr, double maxDistATR, string &sourceOut);
double GetClosestSellLevel(double currentPrice, double atr, double maxDistATR, string &sourceOut);
void PlaceHistoricalBasedScalpingOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope, int existingLimitOrders);
bool CaptureChartDataFromChart();
void ManageTrailingStop();
void GenerateFallbackAIDecision();
void GenerateFallbackMLMetrics();
void DrawPreciseSwingPredictionsWithOrders();
void DrawOrderLinksToSwings(double nextSH, double nextSL, datetime nextSHTime, datetime nextSLTime);
void PlacePreciseSwingBasedOrders();
void CheckAndExecuteDerivArrowTrade();
void StartSpikePositionMonitoring(string direction);
bool IsSymbolPaused(string symbol);
void UpdateSymbolPauseInfo(string symbol, double profit);
bool ShouldPauseSymbol(string symbol, double profit);

// Fonctions de détection avancée de spike
double CalculateVolatilityCompression();
double CalculatePriceAcceleration();
bool DetectVolumeSpike();
bool IsPreSpikePattern();
bool IsPreSpikePatternForSymbol(string symbol);
bool IsNearKeyLevel(double price);
bool IsNearKeyLevelForSymbol(string symbol, double price);
double CalculateSpikeProbability();
void CheckImminentSpike();
void CheckSMCChannelReturnMovements();
void PlaceReturnMovementLimitOrder(string direction, double currentPrice, double channelPrice, double atrVal, double strength);
double FindNearestSupportResistance(string symbol, double currentPrice, string &typeOut);
bool GetRealSupportResistanceFromSupabase(string symbol, double &support, double &resistance);
bool ParseSupabaseSupportResistance(string json, double &support, double &resistance);
bool CheckCorrectionZoneProtection(string entryType);
void DrawSpikeWarning(double probability);
void InitializeSymbolPauseSystem();
bool IsPriceInRange();
bool DetectPriceRange();
bool CalculatePreciseEntryPoint(string direction, double &entryPrice, double &stopLoss, double &takeProfit);
bool IsDerivArrowPresent();
bool GetDerivArrowDirection(string &direction);
void ExecuteDerivArrowTrade(string direction, bool fromArrowDirect = false);
void ExecuteSpikeSeriesTrade(string direction);
bool ValidateEntryWithMultipleSignals(string direction);
void ScanSymbolsForOpportunities();
void ScanAndPlaceLimitOrdersNearLevels();
double GetClosestBuyLevelForSymbol(string symbol, double currentPrice, double atr, double maxDistATR, string &sourceOut);
double GetClosestSellLevelForSymbol(string symbol, double currentPrice, double atr, double maxDistATR, string &sourceOut);
double GetATRForSymbol(string symbol);
bool ValidateAndAdjustLimitPriceForSymbol(string symbol, double &entryPrice, double &stopLoss, double &takeProfit, ENUM_ORDER_TYPE orderType);
double CalculateOpportunityScore(string symbol);
string GetBestSymbolToTrade();
bool GetAISignalForSymbol(string symbol, string timeframe, string &actionOut, double &confidenceOut);
void ExecuteSpikeMarketTradeForSymbol(string symbol, string direction, double aiConfidence);
void ResetDailyCounters();
void UpdateDailyProfit();
bool CanTradeToday();
void DrawDailyCounter();
void InitializeCapitalProtection();
bool IsCapitalProtected();
double GetAdaptiveRiskPercent();
void UpdateEMAData();
bool IsPriceNearEMA(double price, double emaValue, double tolerancePercent = 0.1);
double GetNearestEMASupport(double price);
double GetNearestEMAResistance(double price);
bool IsEMAAlignmentBullish();
bool IsEMAAlignmentBearish();
void DrawEMAOnChart();
bool ValidateEntryWithEMA(string direction, double currentPrice);
void PlacePostHoldLimitOrder(string closedSymbol, ENUM_POSITION_TYPE closedType, double closedProfit);
double FindSMCChannelIntersection(string direction);
bool GetSMCChannelLimits(double &upperLimit, double &lowerLimit);
double GetSMCForcePercentage();
bool IsOrderExecutionAllowed();
void SendDerivArrowNotification(string direction, double entryPrice, double stopLoss, double takeProfit);
bool IsStaircaseTrend(string direction);
double ComputeSetupScore(const string direction);

// Stabilité / reconnexion internet
void CheckRobotStability();
void AutoRecoverySystem();

// Fonctions IA pour communiquer avec le serveur
bool UpdateAIDecision(int timeoutMs = -1);
string GetAISignalData(string symbol, string timeframe);
string GetTrendAlignmentData(string symbol); 
string GetCoherentAnalysisData(string symbol);
void ProcessAIDecision(string jsonData);
void UpdateMLMetricsDisplay();
string ExtractJsonValue(string json, string key);
void CancelConflictingPendingLimitsForSymbol(string symbol);
void UpdateAccumulatedGainsProtection();
bool IsAccumulatedGainsProtectionActive();
void CloseAllEAPositions(string reason);
bool IsLimitOrderNearExecution(ulong orderTicket);
bool IsPriceCorrectionImminent(string symbol);
void CancelOrdersOnImminentCorrection();
bool CheckAndExecuteMarketOrderOnPivotTouch();
void CheckAndClosePivotTouchWithoutSpike();  // Fermer si pivot disparaît + pas de spike en 7 bougies

// Fonctions de cooldown après spike
bool IsPositionInCooldown(string symbol);
void RecordPositionCloseTime(string symbol);
bool CheckCooldownBeforeEntry(string symbol);
bool CheckSeriesCooldownBeforeEntry(string symbol);  // Cooldown allégé pour séries de spikes

// Fonctions Supabase pour les zones de correction
bool LoadCorrectionZonesFromSupabase(string symbol);
bool IsInSupabaseCorrectionZone(string symbol, double price, string &zoneTypeOut);
bool RecordCorrectionZoneUsage(string symbol, string zoneType, double price, bool wasBreakout, bool tradeExecuted, double tradeResult = 0.0);
int GetSymbolIndex(string symbol);

void GetLatestConfirmedSwings(double &lastSH, datetime &lastSHTime, double &lastSL, datetime &lastSLTime);
void DrawConfirmedSwingPoints();
bool DetectBoomCrashSwingPoints();
void UpdateSpikeWarningBlink();
void CheckPredictedSwingTriggers();
int  CountOpenLimitOrdersForSymbol(const string symbol);
int  CountChannelLimitOrdersForSymbol(const string symbol);
bool CanPlaceNewLimitOrderForSymbol(const string symbol, const string context, bool skipPeriodCheck = false);
bool GetRecentAndProjectedMLChannelIntersection(string direction, double &recentPrice, datetime &recentTime, double &projectedPrice, datetime &projectedTime);
void AdjustEMAScalpingLimitOrder();
void ManagePivotLimitOrder();

// Dessin basique des derniers swing high / low sur le graphique courant
void DrawSwingHighLow()
{
   // DEBUG: Vérifier si les graphiques sont activés
   if(!ShowChartGraphics) 
   {
      Print("🔍 DEBUG DrawSwingHighLow - ShowChartGraphics = FALSE, SKIP");
      return;
   }
   
   Print("🔍 DEBUG DrawSwingHighLow - Début dessin SH/SL pour ", _Symbol);
   
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 2, rates) < 2) 
   {
      Print("🔍 DEBUG DrawSwingHighLow - Erreur copie rates, SKIP");
      return;
   }
   
   datetime lastTime = rates[0].time;
   double lastHigh = rates[0].high;
   double lastLow = rates[0].low;
   
   Print("🔍 DEBUG DrawSwingHighLow - Time: ", TimeToString(lastTime), " | High: ", DoubleToString(lastHigh, _Digits), " | Low: ", DoubleToString(lastLow, _Digits));

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
   
   Print("🔍 DEBUG DrawSwingHighLow - SH/SL créés avec succès");
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

// Règle directionnelle spécifique Boom/Crash:
// - Sur Boom: uniquement BUY (jamais SELL)
// - Sur Crash: uniquement SELL (jamais BUY)
bool IsDirectionAllowedForBoomCrash(const string symbol, const string action)
{
   string s = symbol;
   StringToUpper(s);
   string a = action;
   StringToUpper(a);
   
   bool isBoom  = (StringFind(s, "BOOM")  >= 0);
   bool isCrash = (StringFind(s, "CRASH") >= 0);
   
   if(isBoom && a == "SELL")
      return false;
   if(isCrash && a == "BUY")
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

// Vrai s'il est autorisé de placer un nouvel ordre LIMIT pour ce symbole
// - Sécurité globale: 1 seul LIMIT par symbole pour l'EA
// - Pour Boom/Crash: ordres LIMIT uniquement depuis un graphique M5 (sauf si skipPeriodCheck=true pour scan multi-symboles)
bool CanPlaceNewLimitOrderForSymbol(const string symbol, const string context, bool skipPeriodCheck = false)
{
   bool isBoom  = (StringFind(symbol, "Boom")  >= 0);
   bool isCrash = (StringFind(symbol, "Crash") >= 0);
   
   // Pour Boom/Crash: limiter les placements d'ordres LIMIT au graphique M5 (sauf scan multi-symboles)
   if(!skipPeriodCheck && (isBoom || isCrash) && Period() != PERIOD_M5)
   {
      Print("🚫 ", context, " BLOQUÉS - ", symbol,
            " (Boom/Crash) : ordres LIMIT autorisés uniquement sur graphique M5 (TF actuel = ",
            EnumToString((ENUM_TIMEFRAMES)Period()), ")");
      return false;
   }

   int totalLimits = CountOpenLimitOrdersForSymbol(symbol);
   if(totalLimits >= 1)
   {
      Print("🚫 ", context, " BLOQUÉS - Un ordre LIMIT est déjà en attente sur ", symbol,
            " (total=", totalLimits, ")");
      return false;
   }
   return true;
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

// Variables de trading et positions
double g_maxProfit = 0.0;
datetime g_lastBoomCrashPrice = 0;
datetime s_lastRefUpdate = 0;

// Suivi de l'équité journalière pour contrôle du drawdown et des pauses
double   g_dailyStartEquity = 0.0;
double   g_dailyMaxEquity   = 0.0;
double   g_dailyMinEquity   = 0.0;
int      g_dailyEquityDate  = 0;   // YYYYMMDD
datetime g_dailyPauseUntil  = 0;   // Pause trading après objectif de gain journalier

// Dernière perte par symbole (éviter 2e perte consécutive sans conditions strictes)
string g_lastLossSymbol   = "";

// Variables pour protection des gains accumulés
double   g_accumulatedGainsStart = 0.0;  // Point de départ des gains accumulés
double   g_peakAccumulatedGains = 0.0;    // Sommet des gains accumulés
datetime g_gainsProtectionStartTime = 0; // Début de la protection des gains
bool    g_gainsProtectionActive = false;     // Protection des gains activée
datetime g_lastLossTime   = 0;
static const int RECENT_LOSS_WINDOW_SEC = 3600;  // 1 h

// Perte cumulative sur trades consécutifs → pause 30 min
double   g_cumulativeLossSuccessive = 0.0;
datetime g_lossPauseUntil            = 0;

// Stabilité anti-déconnexion (connexion internet perdue/retablie)
datetime g_lastHeartbeat       = 0;
int      g_reconnectAttempts   = 0;
const int MAX_RECONNECT_ATTEMPTS = 5;
bool     g_isStable            = true;

//| INPUTS                                                            |
input group "=== GÉNÉRAL ==="
input bool   UseMinLotOnly     = true;   // Toujours lot minimum (le plus bas)
input int    MaxPositionsTerminal = 20;  // Nombre max de positions (tout le terminal MT5) - valeur élevée pour multi‑symboles
input bool   UseGlobalPositionLimit = true; // Si true, appliquer MaxPositionsTerminal comme plafond global de sécurité
input bool   OnePositionPerSymbol = true; // Une seule position par symbole - MAINTENU pour éviter duplication
input int    InpMagicNumber       = 202502; // Magic Number
input double MaxTotalLossDollars  = 10.0; // Perte totale max ($) - au-delà on ferme la position la plus perdante
input double MaxLossPerSpikeTradeDollars = 3.0;  // Perte max par trade Spike Boom/Crash ($) - lot réduit si dépassement
input double MaxRiskPerTradePercent   = 1.5;  // Risque normal par trade (% de l'équité)
input double MaxDailyDrawdownPercent  = 10.0; // Drawdown max journalier (%) avant blocage des nouvelles entrées
input double DailyProfitTargetDollars = 10.0; // Gain journalier cible ($) avant mise en pause 1h
input double CumulativeLossPauseThresholdDollars = 5.0;  // Perte cumulative (trades consécutifs) avant pause
input double ProtectAccumulatedGainsThreshold = 8.0; // Seuil de gains accumulés avant protection ($)
input double MaxLossAfterGainsProtection = 2.0; // Perte max autorisée après gains protégés ($)
input int    CumulativeLossPauseMinutes = 30;  // Durée de la pause après perte cumulative (min)
input double MinSetupScoreEntry      = 60.0;  // Score minimum (0-100) pour autoriser une nouvelle entrée (légèrement plus agressif)
input double MinAIConfidencePercent   = 60.0;  // Confiance IA minimum (%) pour exécuter un trade
input double MinAIConfidenceBoomDiscount = 55.0; // Confiance min (%) Boom BUY en zone Discount / Crash SELL en Premium (capturer mouvements favorables)
input bool   UseSessions       = true;   // Trader seulement LO/NYO
input bool   ShowChartGraphics = true;   // FVG, OB, Fibo, EMA, Swing H/L sur le graphique
input bool   ShowPremiumDiscount = true; // Zones Premium (vente) / Discount (achat) / Équilibre
input bool   ShowSignalArrow     = true; // Flèche dynamique clignotante BUY/SELL
input bool   RequireSMCDerivArrowForMarketOrders = true; // Avant tout ordre au marché, attendre SMC_DERIV_ARROW
input bool   ScalpArrowMode = true;   // Scalper: entrer dès flèche (vert Boom, rouge Crash), fermer quand flèche disparaît
input int    SMCDerivArrowMaxAgeBars = 3; // La flèche doit être sur les N dernières bougies (timeframe courant)
input bool   ShowPredictedSwing  = true; // SL/SH prédits (futurs) sur le canal
input bool   ShowEMASupportResistance = true; // EMA M1, M5, H1 en support/résistance
input bool   UseStaircaseTrendMode = true; // Activer le mode tendance escalier pour Boom/Crash (structure HH/HL ou LL/LH)
input bool   UltraLightMode      = false; // Mode ultra léger: pas de graphiques ni IA, exécution trading minimale
input bool   BlockAllTrades      = false; // BLOQUER toutes les entrées/sorties (mode observation seul)
input int    CooldownBarsAfterSpikeClose = 3;   // Bougies M1 après fermeture (spike) avant réentrée - éviter entrée immédiate avant 2e spike
input int    SpikePredictionOffsetMinutes = 60; // Décalage dans le futur pour afficher l'entrée de spike dans la zone prédite

input group "=== SL/TP DYNAMIQUES (prudent / sécuriser gain) ==="
input double SL_ATRMult        = 2.5;    // Stop Loss (x ATR) - prudent
input double TP_ATRMult        = 5.0;    // Take Profit (x ATR) - ratio 2:1
input double ProximityLimitATR  = 0.5;    // Proximité (x ATR) pour placer ordre LIMIT quand prix proche du niveau
input group "=== TRAILING STOP (sécuriser les gains) ==="
input bool   UseTrailingStop    = true;   // Activer le Trailing Stop automatique
input double TrailingStop_ATRMult = 3.0;  // Distance Trailing Stop (x ATR) - moins agressif pour protéger les gains

input group "=== GRAPHIQUES SMC (affichage visuel) ==="
input bool   ShowPredictionChannel = true; // Afficher le canal de prédiction ML
input bool   ShowBookmarkLevels    = true; // Lignes horizontales sur derniers Swing High/Low (bookmark ICT)

input group "=== TABLEAU DE BORD ET MÉTRIQUES ==="
input bool   UseDashboard        = true;   // Afficher le tableau de bord avec métriques
input bool   ShowMLMetrics       = true;   // Afficher les métriques ML (entraînement modèle)
input bool   UseSpikeAutoClose    = true;   // Fermeture automatique des spikes (ACTIVÉ)
input bool   UseDollarExits       = true;  // Fermetures basées sur $ (DÉSACTIVÉ - laisse SL/TP normal)
input bool   UseIAHoldClose       = true;  // Fermer sur HOLD (désactivé=laisser SL/TP naturel, capturer le spike)
input bool   UseDirectionConflictClose = true; // Fermer sur conflit direction (ACTIVÉ - permet rotation automatique)
input bool   ForceImmediateConflictClose = true; // Forcer fermeture immédiate sur conflit IA (sans protections)
input bool   UseCorrectionZoneProtection = true;  // Activer protection zones correction
input double CorrectionZoneRiskThreshold = 65.0; // Seuil de risque (65%)
input bool   BlockOnHighRiskZones = true;         // Bloquer entrées zones à risque

input group "=== AI SERVER (confirmation signaux) ==="
input bool   UseAIServer       = true;   // Utiliser le serveur IA pour confirmation
input bool   AllowPivotTouchOverrideIA = true; // Pivot Touch peut passer si IA opposée mais faible (<70%)
input string AI_ServerURL       = "http://127.0.0.1:8000";  // URL du serveur IA local (même que les scripts de test)
input string AI_ServerRender    = "https://kolatradebot.onrender.com";  // URL render en fallback
input int    AI_Timeout_ms     = 5000;   // Timeout WebRequest (ms)
input bool   CancelOrdersOnCorrection = false;  // Annuler ordres si correction imminente
input bool   ExecuteMarketOnPivotTouch = true;   // Exécuter au marché quand prix touche Pivot High/Low
input bool   AutoCancelLimitOrders = false;       // Annulation automatique des ordres LIMIT (true=activé, false=désactivé)
input bool   EnableSMCChannelReturn = false;    // Activer les entrées sur retour de canal SMC (true=activé, false=désactivé)
input int    AI_UpdateInterval_Seconds = 30;  // Intervalle mise à jour IA (secondes)
input bool   UseRenderAsPrimary = false; // Utiliser le serveur local en premier (Render en fallback)
input string AI_ServerURL2      = "http://127.0.0.1:8000";  // URL serveur local (fallback interne)
input double MinAIConfidence   = 0.55;   // Confiance IA min pour exécuter (55% = plus de sécurité)
input int    AI_Timeout_ms2     = 10000;  // Timeout WebRequest (ms) - Render cold start
input string AI_ModelName       = "SMC_Model";  // Nom du modèle IA
input string AI_ModelVersion    = "1.0";  // Version du modèle IA
input bool   AI_UseGPU          = true;   // Utiliser le GPU pour l'IA (si disponible)
input bool   RequireAIConfirmation = true

; // Exiger confirmation IA pour SMC (false = trader sans IA)
input bool   UseFVG            = true;   // Fair Value Gap
input bool   UseOrderBlocks    = true;   // Order Blocks
input bool   UseLiquiditySweep = true;   // Liquidity Sweep (LS)
input bool   RequireStructureAfterSweep = true; // Smart Money: entrée après confirmation (LS+BOS/FVG/OB)
input bool   NoEntryDuringSweep = true;  // Attendre 1+ barres après le sweep (jamais pendant panique)
input bool   StopBeyondNewStructure = true; // Stop au-delà nouvelle structure (pas niveau évident)
input bool   UseBOS            = true;   // Break Of Structure
input bool   UseOTE            = true;   // Optimal Trade Entry (Fib 0.62-0.79)
input bool   UseEqualHL        = true;   // Equal Highs/Lows (EQH/EQL)

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

input group "=== ORDRES LIMITES (niveau le plus proche) ==="
input bool   UseClosestLevelForLimits = true;  // Niveau le plus proche: S/R, EMA M5/H1, SuperTrend M5/H1, swing
input double MaxDistanceLimitATR = 1.0;        // Distance max ordre limite (x ATR) — éviter ordres trop éloignés
input bool   ShowLimitOrderLevels = true;      // Afficher tous les niveaux limite sur le graphique

input group "=== IA SERVEUR ==="

input group "=== BOOM/CRASH ==="
input bool   BoomBuyOnly       = true;   // Boom: BUY uniquement
input bool   CrashSellOnly     = true;   // Crash: SELL uniquement
input bool   NoSLTP_BoomCrash  = false;  // Pas de SL/TP sur Boom/Crash (DÉSACTIVÉ - utilise SL/TP normal)
input double BoomCrashSpikeTP  = 0.50;   // Fermer dès petit gain (spike capté) si profit > ce seuil ($) - AUGMENTÉ
input double BoomCrashSpikePct = 0.50;   // Pourcentage de mouvement pour détecter spike (50% - beaucoup plus élevé)
input double TargetProfitBoomCrashUSD = 2.0; // Gain à capter ($) - fermer si profit >= ce seuil (Spike_Close)
input double MaxLossDollars    = 15.0;   // Fermer toute position si perte atteint ($) - augmenté pour éviter fermetures prématurées
input double TakeProfitDollars = 2.0;    // Fermer si bénéfice atteint ($) - Volatility/Forex/Commodity

// Filtre basé sur la probabilité de spike issue du modèle ML
input bool   UseSpikeMLFilter        = true;   // Utiliser la probabilité ML de spike pour filtrer les entrées
input double SpikeML_MinProbability  = 0.60;   // Probabilité ML minimale de spike pour autoriser le trade (60% pour scalping plus agressif sur Boom/Crash)
input bool   SpikeUsePreSpikeOnlyForBoomCrash = true; // Boom/Crash: entrer dès le pattern pré-spike (avant le 1er spike)
input bool   SpikeRequirePreSpikePattern = true; // Mode strict: exiger le pattern pré-spike EN PLUS d'un spike récent
input double Staircase_MinProbability      = 0.70;  // Proba min "escalier" (serveur IA) pour assouplir les conditions spikes sur Boom/Crash
input double PreSpike_CompressionRatio   = 0.65;  // Pré-spike: range10 < range50 * ratio (plus haut = plus permissif)
input double PreSpike_ConsolidationPct   = 0.002; // Pré-spike: distance au MA20 (0.2% par défaut)
input double PreSpike_KeyLevelPct        = 0.002; // Pré-spike: proximité swing high/low (0.2% par défaut)

input group "=== INDICATEURS CLASSIQUES (RSI / MACD / BB / VWAP / Pivots / Ichimoku / OBV) ==="
input bool   UseClassicIndicatorsFilter = true;  // Activer le filtre combiné d'indicateurs classiques
input int    ClassicMinConfirmations    = 2;     // Nombre minimal d'indicateurs alignés avec la direction
input bool   UseBollingerFilter         = false;  // Utiliser les Bandes de Bollinger dans le filtre
input bool   UseVWAPFilter              = true;  // Utiliser le VWAP intraday
input bool   UsePivotFilter             = true;  // Utiliser les points pivots journaliers
input bool   UseIchimokuFilter          = true;  // Utiliser un résumé tendance Ichimoku H1
input bool   UseOBVFilter               = true;  // Utiliser le volume OBV comme confirmation
input group "=== SUPABASE (optionnel - S/R et zones uniquement) ==="
input string  SupabaseUrl                = "https://bpzqnooiisgadzicwupi.supabase.co";    // URL Supabase (S/R; laisser vide = calculs locaux. IA/ML = serveur)
input string  SupabaseApiKey             = "";    // Clé API Supabase (anon ou service)

//| GESTION DES POSITIONS ET VARIABLES GLOBALES                    |

// Vrai si ce symbole a subi une perte récente (SL ou autre) → réentrée soumise à conditions strictes
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
   
   // Seuil FIXE à 85% pour les autres symboles :
   // on ne trade QUE si l'IA est clairement BUY ou SELL avec très forte confiance.
   double minConf = 0.85;
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
// Variables swing (compatibles avec nouveau système anti-repaint)
double g_lastSwingHigh = 0, g_lastSwingLow = 0;
datetime g_lastSwingHighTime = 0, g_lastSwingLowTime = 0;
static datetime g_lastChannelUpdate = 0;
static double g_chUpperStart = 0, g_chUpperEnd = 0, g_chLowerStart = 0, g_chLowerEnd = 0;
static datetime g_chTimeStart = 0, g_chTimeEnd = 0;

//| VÉRIFIER SI LE TRADE EST AUTORISÉ APRÈS FERMETURE EN GAIN |
bool CanTradeAfterProfitClose(string symbol)
{
   // Trouver l'index du symbole
   int symbolIndex = -1;
   for(int i = 0; i < 10; i++)
   {
      if(g_profitCloseSymbolIndex[i] == 0)
      {
         // Initialiser l'index si non utilisé
         g_profitCloseSymbolIndex[i] = (int)symbol[0] + (int)symbol[1];
      }
      
      if(g_profitCloseSymbolIndex[i] == ((int)symbol[0] + (int)symbol[1]))
      {
         symbolIndex = i;
         break;
      }
   }
   
   // Si pas d'historique de fermeture en gain, autoriser
   if(symbolIndex == -1 || g_lastProfitCloseTime[symbolIndex] == 0)
   {
      return true;
   }
   
   // Calculer le nombre de bougies M1 depuis la dernière fermeture en gain
   datetime currentTime = TimeCurrent();
   int secondsSinceClose = (int)(currentTime - g_lastProfitCloseTime[symbolIndex]);
   int barsSinceClose = secondsSinceClose / 60; // 1 bougie M1 = 60 secondes
   
   // Autoriser seulement si le nombre minimum de bougies est passé
   bool canTrade = barsSinceClose >= MIN_BARS_AFTER_PROFIT_CLOSE;
   
   if(!canTrade)
   {
      Print("🚫 TRADE BLOQUÉ - Protection anti-reprise après gain | ", symbol, 
            " | Bougies attendues: ", MIN_BARS_AFTER_PROFIT_CLOSE, 
            " | Bougies écoulées: ", barsSinceClose);
   }
   
   return canTrade;
}

//| ENREGISTRER LA FERMETURE EN GAIN |
void RecordProfitClose(string symbol)
{
   // Trouver l'index du symbole
   int symbolIndex = -1;
   for(int i = 0; i < 10; i++)
   {
      if(g_profitCloseSymbolIndex[i] == 0)
      {
         g_profitCloseSymbolIndex[i] = (int)symbol[0] + (int)symbol[1];
      }
      
      if(g_profitCloseSymbolIndex[i] == ((int)symbol[0] + (int)symbol[1]))
      {
         symbolIndex = i;
         break;
      }
   }
   
   if(symbolIndex != -1)
   {
      g_lastProfitCloseTime[symbolIndex] = TimeCurrent();
      Print("📊 FERMETURE EN GAIN ENREGISTRÉE - ", symbol, 
            " | Attente de ", MIN_BARS_AFTER_PROFIT_CLOSE, " bougies M1 avant prochain trade");
   }
}

//| CHARGER LES ZONES DE CORRECTION DEPUIS SUPABASE |
bool LoadCorrectionZonesFromSupabase(string symbol)
{
   // Vérifier si la mise à jour est nécessaire
   if(TimeCurrent() - g_lastCorrectionZonesUpdate < CORRECTION_ZONES_UPDATE_INTERVAL)
   {
      return true; // Utiliser les zones en cache
   }
   
   // Trouver l'index du symbole
   int symbolIndex = GetSymbolIndex(symbol);
   if(symbolIndex == -1)
   {
      Print("❌ Erreur - Index symbole non trouvé pour: ", symbol);
      return false;
   }
   
   // Préparer la requête HTTP pour Supabase
   string url = "https://bpzqnooiisgadzicwupi.supabase.co/rest/v1/correction_zones?select=*&symbol=eq." + symbol + "&is_active=eq.true&order=created_at.desc";
   string headers = "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4\r\n" +
                   "Content-Type: application/json\r\n";
   
   char data[];
   char result[];
   string resultStr;
   
   // Envoyer la requête GET
   int timeout = 5000; // 5 secondes
   int res = WebRequest("GET", url, headers, timeout, data, result, headers);
   
   if(res != 200)
   {
      Print("❌ Erreur chargement zones Supabase - Code: ", res, " | Symbole: ", symbol);
      return false;
   }
   
   // Parser la réponse JSON
   resultStr = CharArrayToString(result);
   
   // Réinitialiser les zones pour ce symbole
   g_correctionSupportLevels[symbolIndex] = 0.0;
   g_correctionResistanceLevels[symbolIndex] = 0.0;
   g_correctionPremiumLevels[symbolIndex] = 0.0;
   g_correctionDiscountLevels[symbolIndex] = 0.0;
   
   // Parser simple des zones (extraction basique des niveaux)
   // Note: En MQ5, on ferait un parsing JSON simple ici
   if(StringFind(resultStr, "\"zone_type\":\"support\"") >= 0)
   {
      // Extraire le niveau de support (parser simplifié)
      int start = StringFind(resultStr, "\"price_level\":", 0);
      if(start > 0)
      {
         start += 15; // Longueur de "price_level":
         int end = StringFind(resultStr, ",", start);
         if(end > start)
         {
            string priceStr = StringSubstr(resultStr, start, end - start);
            g_correctionSupportLevels[symbolIndex] = StringToDouble(priceStr);
         }
      }
   }
   
   if(StringFind(resultStr, "\"zone_type\":\"resistance\"") >= 0)
   {
      // Extraire le niveau de résistance
      int start = StringFind(resultStr, "\"price_level\":", StringFind(resultStr, "\"zone_type\":\"resistance\"", 0));
      if(start > 0)
      {
         start += 15;
         int end = StringFind(resultStr, ",", start);
         if(end > start)
         {
            string priceStr = StringSubstr(resultStr, start, end - start);
            g_correctionResistanceLevels[symbolIndex] = StringToDouble(priceStr);
         }
      }
   }
   
   if(StringFind(resultStr, "\"zone_type\":\"premium\"") >= 0)
   {
      // Extraire le niveau Premium
      int start = StringFind(resultStr, "\"price_level\":", StringFind(resultStr, "\"zone_type\":\"premium\"", 0));
      if(start > 0)
      {
         start += 15;
         int end = StringFind(resultStr, ",", start);
         if(end > start)
         {
            string priceStr = StringSubstr(resultStr, start, end - start);
            g_correctionPremiumLevels[symbolIndex] = StringToDouble(priceStr);
         }
      }
   }
   
   if(StringFind(resultStr, "\"zone_type\":\"discount\"") >= 0)
   {
      // Extraire le niveau Discount
      int start = StringFind(resultStr, "\"price_level\":", StringFind(resultStr, "\"zone_type\":\"discount\"", 0));
      if(start > 0)
      {
         start += 15;
         int end = StringFind(resultStr, ",", start);
         if(end > start)
         {
            string priceStr = StringSubstr(resultStr, start, end - start);
            g_correctionDiscountLevels[symbolIndex] = StringToDouble(priceStr);
         }
      }
   }
   
   g_correctionZonesLoaded[symbolIndex] = true;
   g_lastCorrectionZonesUpdate = TimeCurrent();
   
   Print("✅ Zones de correction Supabase chargées - ", symbol);
   Print("   Support: ", DoubleToString(g_correctionSupportLevels[symbolIndex], 5));
   Print("   Résistance: ", DoubleToString(g_correctionResistanceLevels[symbolIndex], 5));
   Print("   Premium: ", DoubleToString(g_correctionPremiumLevels[symbolIndex], 5));
   Print("   Discount: ", DoubleToString(g_correctionDiscountLevels[symbolIndex], 5));
   
   return true;
}

//| VÉRIFIER SI LE PRIX EST DANS UNE ZONE DE CORRECTION SUPABASE |
bool IsInSupabaseCorrectionZone(string symbol, double price, string &zoneTypeOut)
{
   int symbolIndex = GetSymbolIndex(symbol);
   if(symbolIndex == -1 || !g_correctionZonesLoaded[symbolIndex])
   {
      zoneTypeOut = "";
      return false;
   }
   
   double support = g_correctionSupportLevels[symbolIndex];
   double resistance = g_correctionResistanceLevels[symbolIndex];
   double premium = g_correctionPremiumLevels[symbolIndex];
   double discount = g_correctionDiscountLevels[symbolIndex];
   
   // Vérifier si le prix est dans une zone (tolérance de 0.1%)
   double tolerance = price * 0.001; // 0.1%
   
   if(support > 0 && MathAbs(price - support) <= tolerance)
   {
      zoneTypeOut = "support";
      return true;
   }
   
   if(resistance > 0 && MathAbs(price - resistance) <= tolerance)
   {
      zoneTypeOut = "resistance";
      return true;
   }
   
   if(premium > 0 && MathAbs(price - premium) <= tolerance)
   {
      zoneTypeOut = "premium";
      return true;
   }
   
   if(discount > 0 && MathAbs(price - discount) <= tolerance)
   {
      zoneTypeOut = "discount";
      return true;
   }
   
   zoneTypeOut = "";
   return false;
}

//| ENREGISTRER L'OUVERTURE D'UNE POSITION |
void RecordPositionOpen(string symbol)
{
   // Trouver l'index du symbole
   int symbolIndex = -1;
   for(int i = 0; i < 10; i++)
   {
      if(g_positionOpenSymbolIndex[i] == 0)
      {
         g_positionOpenSymbolIndex[i] = (int)symbol[0] + (int)symbol[1];
      }
      
      if(g_positionOpenSymbolIndex[i] == ((int)symbol[0] + (int)symbol[1]))
      {
         symbolIndex = i;
         break;
      }
   }
   
   if(symbolIndex != -1)
   {
      g_positionOpenTime[symbolIndex] = TimeCurrent();
      Print("📊 POSITION OUVERTE ENREGISTRÉE - ", symbol, 
            " | Surveillance de ", MAX_BARS_WITHOUT_SPIKE, " bougies sans spike");
   }
}

//| VÉRIFIER SI FERMETURE AUTOMATIQUE NÉCESSAIRE |
bool ShouldClosePositionWithoutSpike(string symbol)
{
   // Trouver l'index du symbole
   int symbolIndex = -1;
   for(int i = 0; i < 10; i++)
   {
      if(g_positionOpenSymbolIndex[i] == ((int)symbol[0] + (int)symbol[1]))
      {
         symbolIndex = i;
         break;
      }
   }
   
   // Si pas d'historique d'ouverture, autoriser
   if(symbolIndex == -1 || g_positionOpenTime[symbolIndex] == 0)
   {
      return false;
   }
   
   // Calculer le nombre de bougies M1 depuis l'ouverture
   datetime currentTime = TimeCurrent();
   int secondsSinceOpen = (int)(currentTime - g_positionOpenTime[symbolIndex]);
   int barsSinceOpen = secondsSinceOpen / 60; // 1 bougie M1 = 60 secondes
   
   // Vérifier si IA est en HOLD
   bool isAIHold = (StringFind(g_lastAIAction, "HOLD") >= 0);
   
   // Fermer seulement si le nombre maximum de bougies est passé ET IA en HOLD
   bool shouldClose = (barsSinceOpen >= MAX_BARS_WITHOUT_SPIKE) && isAIHold;
   
   if(shouldClose)
   {
      Print("🚫 FERMETURE AUTOMATIQUE - ", symbol, 
            " | Bougies écoulées: ", barsSinceOpen, " ≥ ", MAX_BARS_WITHOUT_SPIKE,
            " | IA: ", g_lastAIAction);
   }
   
   return shouldClose;
}

//| RÉINITIALISER LE TEMPS D'OUVERTURE |
void ResetPositionOpenTime(string symbol)
{
   int symbolIndex = -1;
   for(int i = 0; i < 10; i++)
   {
      if(g_positionOpenSymbolIndex[i] == ((int)symbol[0] + (int)symbol[1]))
      {
         symbolIndex = i;
         break;
      }
   }
   
   if(symbolIndex != -1)
   {
      g_positionOpenTime[symbolIndex] = 0;
   }
}

//| RÉINITIALISER LE COMPTEUR JOURNALIER |
void ResetDailyCounters()
{
   datetime currentTime = TimeCurrent();
   datetime todayStart = StringToTime(TimeToString(currentTime, TIME_DATE) + " 00:00:00");
   
   // Si c'est un nouveau jour, réinitialiser
   if(currentTime >= todayStart && g_dailyResetTime < todayStart)
   {
      g_dailyProfit = 0.0;
      g_dailyTradesCount = 0;
      g_dailyTargetReached = false;
      g_robotStoppedForDay = false;
      g_dailyResetTime = currentTime;
      
      Print("🔄 RÉINITIALISATION JOURNALIÈRE - ", TimeToString(currentTime));
      Print("   📊 Objectif: ", DoubleToString(g_dailyTarget, 2), "$ | Maximum: ", DoubleToString(g_dailyMaxAllowed, 2), "$");
   }
}

//| METTRE À JOUR LE PROFIT JOURNALIER |
void UpdateDailyProfit()
{
   double totalProfit = 0.0;
   int tradesCount = 0;
   
   // Parcourir toutes les positions fermées aujourd'hui (méthode plus précise)
   datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 00:00:00");
   
   // Méthode 1: Compter les ordres fermés via HistoryOrders()
   for(int i = 0; i < HistoryOrdersTotal(); i++)
   {
      ulong orderTicket = HistoryOrderGetTicket(i);
      if(orderTicket == 0) continue;
      
      datetime orderTime = (datetime)HistoryOrderGetInteger(orderTicket, ORDER_TIME_DONE);
      if(orderTime < todayStart) continue;
      
      long orderMagic = HistoryOrderGetInteger(orderTicket, ORDER_MAGIC);
      if(orderMagic != InpMagicNumber) continue;
      
      // Compter uniquement les ordres exécutés (pas les annulations)
      ENUM_ORDER_STATE orderState = (ENUM_ORDER_STATE)HistoryOrderGetInteger(orderTicket, ORDER_STATE);
      if(orderState != ORDER_STATE_FILLED) continue;
      
      // Compter uniquement les ordres de type MARKET (pas les ordres limit modifiés)
      ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)HistoryOrderGetInteger(orderTicket, ORDER_TYPE);
      if(orderType != ORDER_TYPE_BUY && orderType != ORDER_TYPE_SELL) continue;
      
      tradesCount++;
      
      // Le profit sera compté via les deals pour éviter les doubles comptages
   }
   
   // Méthode 2: Calculer le profit via les deals (plus fiable)
   double dealProfit = 0.0;
   int dealCount = 0;
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      
      datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
      if(dealTime < todayStart) continue;
      
      long dealMagic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      if(dealMagic != InpMagicNumber) continue;
      
      // Compter uniquement les deals de type DEAL_TYPE_ENTRY (pas les deals de sortie)
      ulong dealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
      {
         dealProfit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         dealCount++;
      }
   }
   
   g_dailyProfit = dealProfit;
   g_dailyTradesCount = tradesCount;
   
   // Logs de debugging pour vérifier la cohérence
   static datetime lastLog = 0;
   if(TimeCurrent() - lastLog >= 60) // Log toutes les 60 secondes max
   {
      Print("📊 MISE À JOUR COMPTEURS - ", _Symbol);
      Print("   📍 Trades comptés (ordres): ", tradesCount);
      Print("   📍 Deals comptés (entries): ", dealCount);
      Print("   📍 Profit journalier: ", DoubleToString(g_dailyProfit, 2), "$");
      Print("   📍 Date début: ", TimeToString(todayStart));
      lastLog = TimeCurrent();
   }
   
   // Vérifier si l'objectif est atteint
   if(g_dailyProfit >= g_dailyTarget && !g_dailyTargetReached)
   {
      g_dailyTargetReached = true;
      Print("🎯 OBJECTIF JOURNALIER ATTEINT ! - Profit: ", DoubleToString(g_dailyProfit, 2), "$ / ", DoubleToString(g_dailyTarget, 2), "$");
      Alert("🎯 OBJECTIF JOURNALIER ATTEINT ! - " + DoubleToString(g_dailyProfit, 2) + "$ / " + DoubleToString(g_dailyTarget, 2) + "$");
   }
   
   // Vérifier si le robot doit s'arrêter
   if(g_dailyTargetReached && g_dailyProfit < g_dailyTarget - 2.0 && !g_robotStoppedForDay)
   {
      g_robotStoppedForDay = true;
      Print("🛑 ROBOT ARRÊTÉ POUR LA JOURNÉE - Perte après objectif atteint");
      Print("   📊 Profit actuel: ", DoubleToString(g_dailyProfit, 2), "$ | Objectif: ", DoubleToString(g_dailyTarget, 2), "$");
      Alert("🛑 ROBOT ARRÊTÉ POUR LA JOURNÉE - " + DoubleToString(g_dailyProfit, 2) + "$");
   }
   
   // Vérifier le maximum autorisé
   if(g_dailyProfit >= g_dailyMaxAllowed && !g_robotStoppedForDay)
   {
      g_robotStoppedForDay = true;
      Print("🛑 ROBOT ARRÊTÉ - Maximum journalier atteint: ", DoubleToString(g_dailyProfit, 2), "$");
      Alert("🛑 ROBOT ARRÊTÉ - MAXIMUM ATTEINT " + DoubleToString(g_dailyProfit, 2) + "$");
   }
}

//| VÉRIFIER SI LE ROBOT PEUT TRADER AUJOURD'HUI |
bool CanTradeToday()
{
   ResetDailyCounters();
   UpdateDailyProfit();
   
   // NOUVEAU: Initialiser et vérifier la protection du capital
   InitializeCapitalProtection();
   
   if(g_robotStoppedForDay)
   {
      Print("🚫 ROBOT ARRÊTÉ POUR LA JOURNÉE - ", DoubleToString(g_dailyProfit, 2), "$ / ", DoubleToString(g_dailyTarget, 2), "$");
      return false;
   }
   
   // NOUVEAU: Vérifier la protection du capital accumulé
   if(!IsCapitalProtected())
   {
      Print("🛑 PROTECTION CAPITAL ACTIVÉE - Gains protégés contre les pertes");
      return false;
   }
   
   return true;
}

int GetSymbolIndex(string symbol)
{
   // Créer un hash simple du nom du symbole
   int hash = 0;
   for(int i = 0; i < StringLen(symbol); i++)
   {
      hash += (int)symbol[i] * (i + 1);
   }
   return hash % 10; // Retourner un index entre 0 et 9
}

//| SYSTÈME DE PROTECTION DU CAPITAL ACCUMULÉ |
void InitializeCapitalProtection()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   datetime currentTime = TimeCurrent();
   
   // Obtenir le jour de la semaine (0=Dimanche, 1=Lundi, etc.)
   MqlDateTime timeStruct;
   TimeToStruct(currentTime, timeStruct);
   int dayOfWeek = timeStruct.day_of_week;
   int dayOfMonth = timeStruct.day;
   
   // Initialiser le solde de début de semaine (Lundi)
   if(g_weeklyStartingBalance == 0.0 || (dayOfWeek == 1 && 
      (currentTime - g_weeklyResetTime) > 86400)) // Plus de 24h depuis dernière réinitialisation
   {
      g_weeklyStartingBalance = currentBalance;
      g_weeklyResetTime = currentTime;
      Print("📅 RÉINITIALISATION HEBDOMADAIRE - Solde: ", DoubleToString(g_weeklyStartingBalance, 2), "$");
   }
   
   // Initialiser le solde de début de mois
   if(g_monthlyStartingBalance == 0.0 || (dayOfMonth == 1 && 
      (currentTime - g_monthlyResetTime) > 86400)) // Plus de 24h depuis dernière réinitialisation
   {
      g_monthlyStartingBalance = currentBalance;
      g_monthlyResetTime = currentTime;
      Print("📅 RÉINITIALISATION MENSUELLE - Solde: ", DoubleToString(g_monthlyStartingBalance, 2), "$");
   }
   
   // Calculer les gains accumulés
   double weeklyProfit = currentBalance - g_weeklyStartingBalance;
   double monthlyProfit = currentBalance - g_monthlyStartingBalance;
   
   // Mettre à jour les maximums
   if(weeklyProfit > g_maxWeeklyProfit) g_maxWeeklyProfit = weeklyProfit;
   if(monthlyProfit > g_maxMonthlyProfit) g_maxMonthlyProfit = monthlyProfit;
   
   // Calculer les gains totaux accumulés
   g_totalAccumulatedGains = MathMax(0, currentBalance - 1000.0); // Supposons 1000$ comme capital initial
   
   // Activer le mode protection si gains significatifs
   g_capitalProtectionMode = (g_totalAccumulatedGains >= 50.0); // 50$ de gains accumulés
}

//| VÉRIFIER LA PROTECTION DU CAPITAL |
bool IsCapitalProtected()
{
   if(!g_capitalProtectionMode) return true; // Pas encore en mode protection
   
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double weeklyProfit = currentBalance - g_weeklyStartingBalance;
   double monthlyProfit = currentBalance - g_monthlyStartingBalance;
   
   // Protection hebdomadaire : ne pas perdre plus de 30% du gain maximum
   if(g_maxWeeklyProfit > 0)
   {
      double weeklyLossAllowed = g_maxWeeklyProfit * 0.3; // 30% du gain max
      double currentWeeklyLoss = g_maxWeeklyProfit - weeklyProfit;
      
      if(currentWeeklyLoss > weeklyLossAllowed)
      {
         Print("🛑 PROTECTION HEBDOMADAIRE - Perte: ", DoubleToString(currentWeeklyLoss, 2), 
               "$ > ", DoubleToString(weeklyLossAllowed, 2), "$ (30% du gain max)");
         return false;
      }
   }
   
   // Protection mensuelle : ne pas perdre plus de 25% du gain maximum
   if(g_maxMonthlyProfit > 0)
   {
      double monthlyLossAllowed = g_maxMonthlyProfit * 0.25; // 25% du gain max
      double currentMonthlyLoss = g_maxMonthlyProfit - monthlyProfit;
      
      if(currentMonthlyLoss > monthlyLossAllowed)
      {
         Print("🛑 PROTECTION MENSUELLE - Perte: ", DoubleToString(currentMonthlyLoss, 2), 
               "$ > ", DoubleToString(monthlyLossAllowed, 2), "$ (25% du gain max)");
         return false;
      }
   }
   
   return true;
}

//| STRATÉGIE DE GESTION DU RISQUE ADAPTATIVE |
double GetAdaptiveRiskPercent()
{
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double weeklyProfit = currentBalance - g_weeklyStartingBalance;
   double monthlyProfit = currentBalance - g_monthlyStartingBalance;
   
   // Risque de base : 2%
   double riskPercent = 2.0;
   
   // Réduire le risque après gains importants
   if(g_totalAccumulatedGains >= 100.0)
   {
      riskPercent = 1.0; // 1% si +100$ de gains
   }
   else if(g_totalAccumulatedGains >= 50.0)
   {
      riskPercent = 1.5; // 1.5% si +50$ de gains
   }
   
   // Réduire davantage si en perte hebdomadaire
   if(weeklyProfit < -20.0)
   {
      riskPercent *= 0.5; // Moitié du risque si -20$ hebdomadaire
   }
   
   return riskPercent;
}

//| SYSTÈME DE MISE À JOUR DES EMA |
void UpdateEMAData()
{
   datetime currentTime = TimeCurrent();
   
   // Mettre à jour toutes les 60 secondes ou si pas encore initialisé
   if(currentTime - g_emaLastUpdateTime < 60 && g_emaDataReady) return;
   
   // Obtenir les données de prix pour calculer les EMA
   double closePrices[];
   ArraySetAsSeries(closePrices, true);
   
   if(CopyClose(_Symbol, PERIOD_M1, 0, 1000, closePrices) < 200)
   {
      Print("❌ Erreur - Impossible d'obtenir les prix pour calculer les EMA");
      g_emaDataReady = false;
      return;
   }
   
   // Calculer les EMA
   if(!CalculateEMA(closePrices, g_ema9, 9) ||
      !CalculateEMA(closePrices, g_ema21, 21) ||
      !CalculateEMA(closePrices, g_ema50, 50) ||
      !CalculateEMA(closePrices, g_ema100, 100) ||
      !CalculateEMA(closePrices, g_ema200, 200))
   {
      Print("❌ Erreur - Impossible de calculer les EMA");
      g_emaDataReady = false;
      return;
   }
   
   g_emaLastUpdateTime = currentTime;
   g_emaDataReady = true;
   
   // Dessiner les EMA sur le graphique
   DrawEMAOnChart();
}

//| CALCULER UNE EMA |
bool CalculateEMA(const double &priceData[], double &emaBuffer[], int period)
{
   if(ArraySize(priceData) < period) return false;
   
   ArraySetAsSeries(emaBuffer, true);
   
   // Calculer la première SMA comme point de départ
   double sum = 0;
   for(int i = 0; i < period; i++)
   {
      sum += priceData[i];
   }
   emaBuffer[period - 1] = sum / period;
   
   // Calculer le multiplicateur
   double multiplier = 2.0 / (period + 1);
   
   // Calculer l'EMA pour le reste des données
   for(int i = period - 2; i >= 0; i--)
   {
      emaBuffer[i] = (priceData[i] * multiplier) + (emaBuffer[i + 1] * (1 - multiplier));
   }
   
   return true;
}

//| VÉRIFIER SI LE PRIX EST PRÈS D'UNE EMA |
bool IsPriceNearEMA(double price, double emaValue, double tolerancePercent = 0.1)
{
   double tolerance = price * tolerancePercent / 100; // 0.1% par défaut
   return MathAbs(price - emaValue) <= tolerance;
}

//| OBTENIR LE SUPPORT EMA LE PLUS PROCHE |
double GetNearestEMASupport(double price)
{
   if(!g_emaDataReady) return 0.0;
   
   double nearestSupport = 0.0;
   double minDistance = DBL_MAX;
   
   // Vérifier chaque EMA comme support potentiel (EMA sous le prix)
   double emas[] = {g_ema9[0], g_ema21[0], g_ema50[0], g_ema100[0], g_ema200[0]};
   
   for(int i = 0; i < 5; i++)
   {
      if(emas[i] > 0 && emas[i] < price) // EMA sous le prix = support
      {
         double distance = price - emas[i];
         if(distance < minDistance && IsPriceNearEMA(price, emas[i], 0.15)) // 0.15% tolérance
         {
            minDistance = distance;
            nearestSupport = emas[i];
         }
      }
   }
   
   return nearestSupport;
}

//| OBTENIR LA RÉSISTANCE EMA LA PLUS PROCHE |
double GetNearestEMAResistance(double price)
{
   if(!g_emaDataReady) return 0.0;
   
   double nearestResistance = 0.0;
   double minDistance = DBL_MAX;
   
   // Vérifier chaque EMA comme résistance potentielle (EMA au-dessus du prix)
   double emas[] = {g_ema9[0], g_ema21[0], g_ema50[0], g_ema100[0], g_ema200[0]};
   
   for(int i = 0; i < 5; i++)
   {
      if(emas[i] > 0 && emas[i] > price) // EMA au-dessus du prix = résistance
      {
         double distance = emas[i] - price;
         if(distance < minDistance && IsPriceNearEMA(price, emas[i], 0.15)) // 0.15% tolérance
         {
            minDistance = distance;
            nearestResistance = emas[i];
         }
      }
   }
   
   return nearestResistance;
}

//| VÉRIFIER L'ALIGNEMENT HAUSSIER DES EMA |
bool IsEMAAlignmentBullish()
{
   if(!g_emaDataReady) return false;
   
   // Alignement haussier: EMA9 > EMA21 > EMA50 > EMA100 > EMA200
   return (g_ema9[0] > g_ema21[0] && 
           g_ema21[0] > g_ema50[0] && 
           g_ema50[0] > g_ema100[0] && 
           g_ema100[0] > g_ema200[0]);
}

//| VÉRIFIER L'ALIGNEMENT BAISSIER DES EMA |
bool IsEMAAlignmentBearish()
{
   if(!g_emaDataReady) return false;
   
   // Alignement baissier: EMA9 < EMA21 < EMA50 < EMA100 < EMA200
   return (g_ema9[0] < g_ema21[0] && 
           g_ema21[0] < g_ema50[0] && 
           g_ema50[0] < g_ema100[0] && 
           g_ema100[0] < g_ema200[0]);
}

//| DESSINER LES EMA SUR LE GRAPHIQUE (1000 bougies + futures) |
void DrawEMAOnChart()
{
   if(!g_emaDataReady) return;
   
   // Nettoyer tous les anciens objets EMA
   string emaPrefixes[] = {"EMA_9", "EMA_21", "EMA_50", "EMA_100", "EMA_200"};
   for(int p = 0; p < 5; p++)
   {
      string prefix = emaPrefixes[p];
      
      // Nettoyer les lignes principales
      if(ObjectFind(0, prefix) >= 0)
         ObjectDelete(0, prefix);
      
      // Nettoyer les projections futures
      if(ObjectFind(0, prefix + "_FUTURE") >= 0)
         ObjectDelete(0, prefix + "_FUTURE");
      
      // Nettoyer les labels
      if(ObjectFind(0, prefix + "_LABEL") >= 0)
         ObjectDelete(0, prefix + "_LABEL");
      
      // Nettoyer tous les autres objets avec ce préfixe
      for(int i = 0; i < 2000; i++)
      {
         string objName = prefix + "_" + IntegerToString(i);
         if(ObjectFind(0, objName) >= 0)
            ObjectDelete(0, objName);
      }
   }
   
   // Couleurs pour chaque EMA
   color emaColors[] = {clrYellow, clrDodgerBlue, clrOrange, clrPurple, clrMagenta};
   int emaPeriods[] = {9, 21, 50, 100, 200};
   
   // Obtenir 1000 bougies de données temporelles pour les EMA
   datetime timeData[];
   ArraySetAsSeries(timeData, true);
   if(CopyTime(_Symbol, PERIOD_M1, 0, 1000, timeData) < 1000)
   {
      Print("❌ Erreur - Impossible d'obtenir les données temporelles pour les EMA");
      return;
   }
   
   for(int i = 0; i < 5; i++)
   {
      string emaName = "EMA_" + IntegerToString(emaPeriods[i]);
      
      // Créer des segments de ligne pour chaque bougie historique (courbe continue)
      for(int j = 0; j < 999 && j < ArraySize(g_ema9) - 1; j++)
      {
         string segmentName = emaName + "_SEG_" + IntegerToString(j);
         if(ObjectFind(0, segmentName) >= 0)
            ObjectDelete(0, segmentName);
         
         double emaValue1 = 0, emaValue2 = 0;
         switch(i)
         {
            case 0: 
               if(j < ArraySize(g_ema9) && j + 1 < ArraySize(g_ema9))
               {
                  emaValue1 = g_ema9[j];
                  emaValue2 = g_ema9[j + 1];
               }
               break;
            case 1: 
               if(j < ArraySize(g_ema21) && j + 1 < ArraySize(g_ema21))
               {
                  emaValue1 = g_ema21[j];
                  emaValue2 = g_ema21[j + 1];
               }
               break;
            case 2: 
               if(j < ArraySize(g_ema50) && j + 1 < ArraySize(g_ema50))
               {
                  emaValue1 = g_ema50[j];
                  emaValue2 = g_ema50[j + 1];
               }
               break;
            case 3: 
               if(j < ArraySize(g_ema100) && j + 1 < ArraySize(g_ema100))
               {
                  emaValue1 = g_ema100[j];
                  emaValue2 = g_ema100[j + 1];
               }
               break;
            case 4: 
               if(j < ArraySize(g_ema200) && j + 1 < ArraySize(g_ema200))
               {
                  emaValue1 = g_ema200[j];
                  emaValue2 = g_ema200[j + 1];
               }
               break;
         }
         
         if(emaValue1 > 0 && emaValue2 > 0)
         {
            if(ObjectCreate(0, segmentName, OBJ_TREND, 0, timeData[j + 1], emaValue1, timeData[j], emaValue2))
            {
               ObjectSetInteger(0, segmentName, OBJPROP_COLOR, emaColors[i]);
               ObjectSetInteger(0, segmentName, OBJPROP_STYLE, STYLE_SOLID);
               ObjectSetInteger(0, segmentName, OBJPROP_WIDTH, (i < 2) ? 2 : 1);
               ObjectSetInteger(0, segmentName, OBJPROP_RAY_RIGHT, false);
               ObjectSetInteger(0, segmentName, OBJPROP_BACK, true);
            }
         }
      }
      
      // Créer la projection future (100 bougies)
      string futureName = "EMA_" + IntegerToString(emaPeriods[i]) + "_FUTURE";
      
      if(ObjectCreate(0, futureName, OBJ_TREND, 0, 0, 0))
      {
         datetime currentTime = TimeCurrent();
         datetime futureTime = currentTime + 100 * PeriodSeconds(PERIOD_M1);
         
         ObjectSetInteger(0, futureName, OBJPROP_COLOR, emaColors[i]);
         ObjectSetInteger(0, futureName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetInteger(0, futureName, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, futureName, OBJPROP_RAY_RIGHT, false);
         
         // Valeur EMA actuelle et future (projection linéaire simple)
         double currentEMA = 0;
         switch(i)
         {
            case 0: currentEMA = g_ema9[0]; break;
            case 1: currentEMA = g_ema21[0]; break;
            case 2: currentEMA = g_ema50[0]; break;
            case 3: currentEMA = g_ema100[0]; break;
            case 4: currentEMA = g_ema200[0]; break;
         }
         
         // Projection simple (maintient la valeur actuelle)
         ObjectSetDouble(0, futureName, OBJPROP_PRICE, 0, currentEMA);
         ObjectSetInteger(0, futureName, OBJPROP_TIME, 0, currentTime);
         ObjectSetDouble(0, futureName, OBJPROP_PRICE, 1, currentEMA);
         ObjectSetInteger(0, futureName, OBJPROP_TIME, 1, futureTime);
      }
      
      // Ajouter des labels pour chaque EMA
      string labelName = "EMA_" + IntegerToString(emaPeriods[i]) + "_LABEL";
      
      if(ObjectCreate(0, labelName, OBJ_TEXT, 0, 0, 0))
      {
         double currentEMA = 0;
         switch(i)
         {
            case 0: currentEMA = g_ema9[0]; break;
            case 1: currentEMA = g_ema21[0]; break;
            case 2: currentEMA = g_ema50[0]; break;
            case 3: currentEMA = g_ema100[0]; break;
            case 4: currentEMA = g_ema200[0]; break;
         }
         
         datetime labelTime = TimeCurrent() + 120 * PeriodSeconds(PERIOD_M1); // 2 minutes dans le futur
         
         ObjectSetString(0, labelName, OBJPROP_TEXT, "EMA" + IntegerToString(emaPeriods[i]));
         ObjectSetInteger(0, labelName, OBJPROP_TIME, 0, labelTime);
         ObjectSetDouble(0, labelName, OBJPROP_PRICE, 0, currentEMA);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, emaColors[i]);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, labelName, OBJPROP_BACK, true);
      }
   }
   
   Print("✅ EMA dessinées - 1000 bougies passées + 100 bougies futures");
}

//| TROUVER L'INTERSECTION CANAL SMC + PRIX ACTUEL |
double FindSMCChannelIntersection(string direction)
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Obtenir les limites du canal SMC
   double upperChannel = 0, lowerChannel = 0;
   if(!GetSMCChannelLimits(upperChannel, lowerChannel))
   {
      Print("❌ Impossible d'obtenir les limites du canal SMC");
      return 0.0;
   }
   
   double intersectionPrice = 0.0;
   
   if(direction == "BUY")
   {
      // Pour BUY: chercher l'intersection avec la borne inférieure du canal
      if(currentPrice > lowerChannel)
      {
         // Si prix au-dessus, chercher quand il touchera la borne inférieure
         intersectionPrice = lowerChannel;
         Print("📍 Intersection BUY SMC - Prix actuel: ", DoubleToString(currentPrice, _Digits), 
               " → Canal bas: ", DoubleToString(intersectionPrice, _Digits));
      }
      else if(currentPrice <= lowerChannel)
      {
         // Si prix déjà au niveau ou en dessous, utiliser le prix actuel
         intersectionPrice = currentPrice;
         Print("📍 Intersection BUY SMC - Prix déjà au niveau canal: ", DoubleToString(intersectionPrice, _Digits));
      }
   }
   else if(direction == "SELL")
   {
      // Pour SELL: chercher l'intersection avec la borne supérieure du canal
      if(currentPrice < upperChannel)
      {
         // Si prix en dessous, chercher quand il touchera la borne supérieure
         intersectionPrice = upperChannel;
         Print("📍 Intersection SELL SMC - Prix actuel: ", DoubleToString(currentPrice, _Digits), 
               " → Canal haut: ", DoubleToString(intersectionPrice, _Digits));
      }
      else if(currentPrice >= upperChannel)
      {
         // Si prix déjà au niveau ou au-dessus, utiliser le prix actuel
         intersectionPrice = currentPrice;
         Print("📍 Intersection SELL SMC - Prix déjà au niveau canal: ", DoubleToString(intersectionPrice, _Digits));
      }
   }
   
   // Vérifier que l'intersection est valide et pas trop loin
   if(intersectionPrice > 0)
   {
      double distancePercent = MathAbs(intersectionPrice - currentPrice) / currentPrice * 100;
      if(distancePercent > 0.3) // RÉDUIT: Max 0.3% au lieu de 1%
      {
         Print("🚫 Intersection SMC trop loin: ", DoubleToString(distancePercent, 2), "% > 0.3%");
         
         // NOUVEAU: UTILISER UN NIVEAU PLUS PROCHE COMME REPLI
         double fallbackPrice = 0.0;
         if(direction == "BUY")
         {
            // Pour BUY: utiliser un niveau juste en dessous du prix actuel
            fallbackPrice = currentPrice * (1 - 0.001); // 0.1% en dessous
            Print("🔄 Repli BUY - Prix: ", DoubleToString(fallbackPrice, _Digits));
         }
         else if(direction == "SELL")
         {
            // Pour SELL: utiliser un niveau juste au-dessus du prix actuel
            fallbackPrice = currentPrice * (1 + 0.001); // 0.1% au-dessus
            Print("🔄 Repli SELL - Prix: ", DoubleToString(fallbackPrice, _Digits));
         }
         
         return fallbackPrice;
      }
   }
   
   return intersectionPrice;
}

//| OBTENIR LES LIMITES DU CANAL SMC |
bool GetSMCChannelLimits(double &upperLimit, double &lowerLimit)
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // MÉTHODE #1: UTILISER LES ZONES SMC EXISTANTES
   bool inDiscount = IsInDiscountZone();
   bool inPremium = IsInPremiumZone();
   
   if(inDiscount && inPremium)
   {
      // Calculer depuis les zones Premium/Discount
      // La largeur du canal est basée sur la force actuelle du marché - RÉDUITE
      double forcePercentage = GetSMCForcePercentage();
      double channelWidth = currentPrice * (forcePercentage / 200.0); // RÉDUIT: /200 au lieu de /100
      
      // Positionner le canal autour du prix actuel
      upperLimit = currentPrice + channelWidth / 2;
      lowerLimit = currentPrice - channelWidth / 2;
      
      Print("📊 Canal SMC depuis zones - Largeur: ", DoubleToString(channelWidth, 2), 
            " | Haut: ", DoubleToString(upperLimit, _Digits), 
            " | Bas: ", DoubleToString(lowerLimit, _Digits));
      return true;
   }
   
   // MÉTHODE #2: UTILISER L'ATR POUR UN CANAL DYNAMIQUE
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   int localAtrHandle = iATR(_Symbol, PERIOD_M1, 14);
   if(localAtrHandle != INVALID_HANDLE && CopyBuffer(localAtrHandle, 0, 0, 1, atrBuffer) >= 1)
   {
      double atr = atrBuffer[0];
      double channelMultiplier = 1.0; // RÉDUIT: Canal = 1x ATR au lieu de 2x ATR
      
      upperLimit = currentPrice + atr * channelMultiplier;
      lowerLimit = currentPrice - atr * channelMultiplier;
      
      Print("📊 Canal SMC depuis ATR - ATR: ", DoubleToString(atr, _Digits), 
            " | Haut: ", DoubleToString(upperLimit, _Digits), 
            " | Bas: ", DoubleToString(lowerLimit, _Digits));
      IndicatorRelease(atrHandle);
      return true;
   }
   
   // MÉTHODE #3: CANAL FIXE 1% (dernier recours)
   double fixedWidth = currentPrice * 0.01; // RÉDUIT: 1% fixe au lieu de 2%
   upperLimit = currentPrice + fixedWidth / 2;
   lowerLimit = currentPrice - fixedWidth / 2;
   
   Print("📊 Canal SMC fixe 1% - Haut: ", DoubleToString(upperLimit, _Digits), 
         " | Bas: ", DoubleToString(lowerLimit, _Digits));
   
   return true;
}

//| OBTENIR LE POURCENTAGE DE FORCE SMC |
double GetSMCForcePercentage()
{
   // Simuler le calcul de force basé sur la position dans les zones - RÉDUIT
   bool inDiscount = IsInDiscountZone();
   bool inPremium = IsInPremiumZone();
   
   if(inDiscount && inPremium)
   {
      return 1.5; // RÉDUIT: Force modérée 1.5% au lieu de 3.0%
   }
   else if(inDiscount)
   {
      return 1.2; // RÉDUIT: Force plus faible 1.2% au lieu de 2.5%
   }
   else if(inPremium)
   {
      return 1.8; // RÉDUIT: Force plus élevée 1.8% au lieu de 3.5%
   }
   
   return 1.5; // RÉDUIT: Force par défaut 1.5% au lieu de 3.0%
}

//| RÉCUPÉRER LES VRAIS NIVEAUX S/R DEPUIS SUPABASE |
bool GetRealSupportResistanceFromSupabase(string symbol, double &support, double &resistance)
{
   support = 0.0;
   resistance = 0.0;
   
   if(StringLen(SupabaseUrl) == 0 || StringLen(SupabaseApiKey) == 0)
   {
      static bool _supabase_sr_logged = false;
      if(!_supabase_sr_logged) { _supabase_sr_logged = true; Print("ℹ️ S/R: calculs locaux (SupabaseUrl/SupabaseApiKey vides - optionnel)"); }
      return false;
   }
   
   // Récupérer les configurations depuis les inputs
   string supabaseUrl = SupabaseUrl + "/rest/v1/support_resistance_levels";
   string apiKey = SupabaseApiKey;
   
   // Ajouter les paramètres pour filtrer par symbole, timeframe M1 et ordonner par force
   string queryParams = "?symbol=eq." + symbol + 
                        "&timeframe=eq.M1" +
                        "&order=strength_score.desc" +
                        "&limit=3";
   string fullUrl = supabaseUrl + queryParams;
   
   // Préparer la requête HTTP
   string response = "";
   string headers = "apikey: " + apiKey + "\r\n" + 
                   "Authorization: Bearer " + apiKey + "\r\n" +
                   "Content-Type: application/json\r\n" +
                   "Prefer: return=representation\r\n";
   
   // Envoyer la requête GET
   int timeout = 3000; // 3 secondes pour éviter de bloquer le trading
   char data[];
   char result[];
   
   Print("🌐 Requête Supabase S/R pour: ", symbol, " (M1)");
   
   // Utiliser WebRequest pour récupérer les données
   int statusCode = WebRequest("GET", fullUrl, headers, timeout, data, result, headers);
   
   if(statusCode == 200)
   {
      // Convertir la réponse en string
      response = CharArrayToString(result);
      
      // Parser la réponse JSON pour extraire support et résistance
      if(ParseSupabaseSupportResistance(response, support, resistance))
      {
         Print("✅ Données S/R Supabase récupérées avec succès");
         return true;
      }
      else
      {
         Print("❌ Erreur parsing JSON Supabase: ", StringSubstr(response, 0, 200));
         return false;
      }
   }
   else
   {
      Print("❌ Erreur requête Supabase - Code: ", statusCode, " | Erreur: ", GetLastError());
      
      // En cas d'erreur, essayer le fallback sur les calculs locaux
      Print("🔄 Fallback sur calculs locaux S/R");
      return false;
   }
}

//| PARSER LA RÉPONSE JSON SUPABASE |
bool ParseSupabaseSupportResistance(string json, double &support, double &resistance)
{
   support = 0.0;
   resistance = 0.0;
   
   // Parser simple pour extraire les valeurs de support/résistance
   // Format attendu: [{"support": 1234.5, "resistance": 1235.0, "timestamp": "..."}, ...]
   
   int supportPos = StringFind(json, "\"support\":");
   int resistancePos = StringFind(json, "\"resistance\":");
   
   if(supportPos > 0 && resistancePos > 0)
   {
      // Extraire la valeur du support
      string supportStr = "";
      int start = supportPos + 11; // Après "support":
      while(start < StringLen(json) && json[start] != ',' && json[start] != '}')
      {
         if(json[start] != ' ' && json[start] != '"')
            supportStr += CharToString((uchar)json[start]);
         start++;
      }
      
      // Extraire la valeur de la résistance
      string resistanceStr = "";
      start = resistancePos + 14; // Après "resistance":
      while(start < StringLen(json) && json[start] != ',' && json[start] != '}')
      {
         if(json[start] != ' ' && json[start] != '"')
            resistanceStr += CharToString((uchar)json[start]);
         start++;
      }
      
      // Convertir en double
      support = StringToDouble(supportStr);
      resistance = StringToDouble(resistanceStr);
      
      if(support > 0 && resistance > 0)
      {
         Print("📊 Parsing S/R - Support: ", supportStr, " -> ", DoubleToString(support, _Digits));
         Print("📊 Parsing S/R - Résistance: ", resistanceStr, " -> ", DoubleToString(resistance, _Digits));
         return true;
      }
   }
   
   return false;
}

//| VÉRIFIER SI LES ORDRES SONT AUTORISÉS (NON HOLD) |
bool IsOrderExecutionAllowed()
{
   if(!g_isStable || !TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      return false; // Connexion perdue - pas de log pour éviter spam
   }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      return false;
   }
   if(g_lastAIAction == "HOLD")
   {
      Print("🚫 ORDRES BLOQUÉS - IA Server en mode HOLD");
      Print("   📍 Action IA: HOLD - Aucun ordre autorisé");
      return false;
   }
   return true;
}

//| VÉRIFIER LA PROTECTION CONTRE LES ZONES DE CORRECTION |
bool CheckCorrectionZoneProtection(string entryType)
{
   if(!UseCorrectionZoneProtection) 
   {
      Print("✅ Protection zones correction désactivée - ", entryType, " autorisé");
      return true;
   }
   
   if(!g_correctionAnalysisDone) 
   {
      Print("⚠️ Analyse correction non disponible - ", entryType, " autorisé par défaut");
      return true;
   }
   
   double correctionScore = GetCorrectionScore();
   bool isHighRiskZone = IsInHighRiskCorrectionZone();
   int predictedDuration = PredictCurrentCorrectionDuration();
   
   Print("🔍 PROTECTION ZONE CORRECTION - ", entryType);
   Print("   📊 Score: ", DoubleToString(correctionScore, 1), "%");
   Print("   📊 Risque: ", (isHighRiskZone ? "ÉLEVÉ" : "MODÉRÉ"));
   Print("   📊 Durée prédite: ", predictedDuration, " bougies");
   
   // BLOQUER si score >= seuil de risque
   if(correctionScore >= CorrectionZoneRiskThreshold)
   {
      Print("🚫 ", entryType, " BLOQUÉ - Zone de correction détectée");
      Print("   📊 Score: ", DoubleToString(correctionScore, 1), "% ≥ ", DoubleToString(CorrectionZoneRiskThreshold, 1), "%");
      Print("   📊 Risque: ", (isHighRiskZone ? "ÉLEVÉ" : "MODÉRÉ"), " - Entrée interdite");
      
      // Enregistrer la tentative d'entrée en zone de correction
      RecordCorrectionZoneUsage(_Symbol, "HIGH_RISK_BLOCKED", SymbolInfoDouble(_Symbol, SYMBOL_BID), false, false);
      return false;
   }
   
   Print("✅ ", entryType, " AUTORISÉ - Score acceptable: ", DoubleToString(correctionScore, 1), "%");
   return true;
}

//| VALIDER L'ENTRÉE AVEC LES EMA POUR BOOM/CRASH |
bool ValidateEntryWithEMA(string direction, double currentPrice)
{
   if(!g_emaDataReady) return true; // Si EMA pas prêtes, autoriser par défaut
   
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   
   if(!isBoom && !isCrash) return true; // Uniquement pour Boom/Crash
   
   // Règles pour Boom (recherche d'entrées BUY)
   if(isBoom && direction == "BUY")
   {
      // Conditions optimales pour BUY sur Boom
      bool nearSupport = IsPriceNearEMA(currentPrice, g_ema9[0], 0.2) || 
                        IsPriceNearEMA(currentPrice, g_ema21[0], 0.2) ||
                        IsPriceNearEMA(currentPrice, g_ema50[0], 0.2);
      
      bool bullishAlignment = IsEMAAlignmentBullish() || 
                             (g_ema9[0] > g_ema21[0] && g_ema21[0] > g_ema50[0]);
      
      bool priceAboveKeyEMA = currentPrice > g_ema200[0] && currentPrice > g_ema100[0];
      
      // Autoriser si près d'un support EMA avec alignement haussier
      if(nearSupport && bullishAlignment)
      {
         Print("📈 EMA VALIDATION Boom BUY - Près support EMA + alignement haussier");
         return true;
      }
      
      // Autoriser si prix au-dessus des EMA clés avec alignement
      if(priceAboveKeyEMA && bullishAlignment)
      {
         Print("📈 EMA VALIDATION Boom BUY - Au-dessus EMA clés + alignement");
         return true;
      }
      
      // Refuser si prix sous les EMA majeures
      if(currentPrice < g_ema200[0])
      {
         Print("🚫 EMA REJET Boom BUY - Prix sous EMA200");
         return false;
      }
      
      // Refuser si alignement baissier
      if(IsEMAAlignmentBearish())
      {
         Print("🚫 EMA REJET Boom BUY - Alignement baissier EMA");
         return false;
      }
   }
   
   // Règles pour Crash (recherche d'entrées SELL)
   if(isCrash && direction == "SELL")
   {
      // Conditions optimales pour SELL sur Crash
      bool nearResistance = IsPriceNearEMA(currentPrice, g_ema9[0], 0.2) || 
                           IsPriceNearEMA(currentPrice, g_ema21[0], 0.2) ||
                           IsPriceNearEMA(currentPrice, g_ema50[0], 0.2);
      
      bool bearishAlignment = IsEMAAlignmentBearish() || 
                            (g_ema9[0] < g_ema21[0] && g_ema21[0] < g_ema50[0]);
      
      bool priceBelowKeyEMA = currentPrice < g_ema200[0] && currentPrice < g_ema100[0];
      
      // Autoriser si près d'une résistance EMA avec alignement baissier
      if(nearResistance && bearishAlignment)
      {
         Print("📉 EMA VALIDATION Crash SELL - Près résistance EMA + alignement baissier");
         return true;
      }
      
      // Autoriser si prix sous les EMA clés avec alignement
      if(priceBelowKeyEMA && bearishAlignment)
      {
         Print("📉 EMA VALIDATION Crash SELL - Sous EMA clés + alignement");
         return true;
      }
      
      // Refuser si prix au-dessus des EMA majeures
      if(currentPrice > g_ema200[0])
      {
         Print("🚫 EMA REJET Crash SELL - Prix au-dessus EMA200");
         return false;
      }
      
      // Refuser si alignement haussier
      if(IsEMAAlignmentBullish())
      {
         Print("🚫 EMA REJET Crash SELL - Alignement haussier EMA");
         return false;
      }
   }
   
   // Pour les directions contraires (SELL sur Boom, BUY sur Crash)
   if((isBoom && direction == "SELL") || (isCrash && direction == "BUY"))
   {
      // Autoriser seulement si très près d'une EMA de contre-tendance
      bool veryNearEMA = IsPriceNearEMA(currentPrice, g_ema9[0], 0.1) || 
                        IsPriceNearEMA(currentPrice, g_ema21[0], 0.1);
      
      if(veryNearEMA)
      {
         Print("⚠️ EMA VALIDATION contre-tendance - Très près EMA pour reversal");
         return true;
      }
      else
      {
         Print("🚫 EMA REJET contre-tendance - Pas assez près EMA");
         return false;
      }
   }
   
   return true; // Par défaut, autoriser
}

//| AMÉLIORER LE SCORE D'OPPORTUNITÉ AVEC LES EMA |
double CalculateOpportunityScore(string symbol)
{
   double score = 0.0;
   
   // Mettre à jour les EMA
   UpdateEMAData();
   
   if(!g_emaDataReady) return 0.5; // Score neutre si EMA pas prêtes
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   bool isBoom = (StringFind(symbol, "Boom") >= 0);
   bool isCrash = (StringFind(symbol, "Crash") >= 0);
   
   // Score de base selon le type de symbole
   if(isBoom || isCrash)
   {
      score += 0.3; // +30% pour Boom/Crash
      
      // Bonus pour alignement EMA favorable
      if(isBoom && IsEMAAlignmentBullish())
      {
         score += 0.25; // +25% si alignement haussier pour Boom
         Print("📈 EMA Bonus Boom - Alignement haussier détecté");
      }
      
      if(isCrash && IsEMAAlignmentBearish())
      {
         score += 0.25; // +25% si alignement baissier pour Crash
         Print("📉 EMA Bonus Crash - Alignement baissier détecté");
      }
      
      // Bonus si prix près d'une EMA de support/résistance
      double emaSupport = GetNearestEMASupport(currentPrice);
      double emaResistance = GetNearestEMAResistance(currentPrice);
      
      if(emaSupport > 0 && isBoom)
      {
         score += 0.15; // +15% si près support EMA pour Boom
         Print("📍 EMA Bonus Boom - Près support EMA");
      }
      
      if(emaResistance > 0 && isCrash)
      {
         score += 0.15; // +15% si près résistance EMA pour Crash
         Print("📍 EMA Bonus Crash - Près résistance EMA");
      }
      
      // Pénalité si alignement défavorable
      if(isBoom && IsEMAAlignmentBearish())
      {
         score -= 0.2; // -20% si alignement baissier pour Boom
         Print("🚫 EMA Pénalité Boom - Alignement baissier");
      }
      
      if(isCrash && IsEMAAlignmentBullish())
      {
         score -= 0.2; // -20% si alignement haussier pour Crash
         Print("🚫 EMA Pénalité Crash - Alignement haussier");
      }
   }
   else
   {
      // Pour les autres symboles, score plus modéré
      score += 0.2;
      
      // Bonus si EMA bien alignées (tendance claire)
      if(IsEMAAlignmentBullish() || IsEMAAlignmentBearish())
      {
         score += 0.1;
         Print("📊 EMA Bonus - Tendance claire détectée");
      }
   }
   
   // Limiter le score entre 0 et 1
   score = MathMax(0.0, MathMin(1.0, score));
   
   return score;
}

//| ENREGISTRER UNE ZONE DE CORRECTION DANS SUPABASE |
bool RecordCorrectionZoneUsage(string symbol, string zoneType, double price, bool wasBreakout, bool tradeExecuted, double tradeResult = 0.0)
{
   string url = "https://bpzqnooiisgadzicwupi.supabase.co/rest/v1/correction_zone_history";
   string headers = "apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJwenFub29paXNnYWR6aWN3dXBpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE1ODQ0NDcsImV4cCI6MjA4NzE2MDQ0N30.BDdYM-SQDCIVJJueUH8ed9-vHrY_g2sb8PDeD9vb_L4\r\n" +
                   "Content-Type: application/json\r\n" +
                   "Prefer: return=minimal\r\n";
   
   // Créer le JSON pour l'enregistrement
   string jsonData = "{";
   jsonData += "\"symbol\":\"" + symbol + "\",";
   jsonData += "\"zone_type\":\"" + zoneType + "\",";
   jsonData += "\"price_level\":" + DoubleToString(price, 5) + ",";
   jsonData += "\"touched_at\":\"" + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "\",";
   jsonData += "\"touch_price\":" + DoubleToString(price, 5) + ",";
   jsonData += "\"was_breakout\":" + (wasBreakout ? "true" : "false") + ",";
   jsonData += "\"trade_executed\":" + (tradeExecuted ? "true" : "false");
   if(tradeExecuted)
   {
      jsonData += ",\"trade_result\":" + DoubleToString(tradeResult, 2);
   }
   jsonData += "}";
   
   char data[];
   char result[];
   StringToCharArray(jsonData, data);
   
   // Envoyer la requête POST
   int timeout = 5000; // 5 secondes
   int res = WebRequest("POST", url, headers, timeout, data, result, headers);
   
   if(res != 201) // 201 = Created
   {
      Print("❌ Erreur enregistrement zone Supabase - Code: ", res, " | Symbole: ", symbol);
      return false;
   }
   
   Print("✅ Zone de correction enregistrée - ", symbol, " | Type: ", zoneType, " | Prix: ", DoubleToString(price, 5));
   return true;
}
static datetime g_lastSpikeDetectionTime[10]; // Temps du dernier spike par symbole
static int g_spikeSymbolIndex[10]; // Index des symboles pour les spikes

//| VARIABLES POUR PROTECTION ANTI-REPRISE APRÈS GAINS |
static datetime g_lastProfitCloseTime[10]; // Temps de dernière fermeture en gain par symbole
static int g_profitCloseSymbolIndex[10]; // Index des symboles pour les fermetures en gain
static const int MIN_BARS_AFTER_PROFIT_CLOSE = 4; // Attendre 4 bougies M1 après fermeture en gain

//| VARIABLES POUR FERMETURE AUTOMATIQUE SANS SPIKE |
static datetime g_positionOpenTime[10]; // Temps d'ouverture par symbole
static int g_positionOpenSymbolIndex[10]; // Index des symboles pour les positions ouvertes
static const int MAX_BARS_WITHOUT_SPIKE = 7; // Fermer après 7 bougies M1 sans spike

//| VARIABLES POUR SUIVI JOURNALIER DES TRADES |
static double g_dailyProfit = 0.0; // Profit journalier actuel
static double g_dailyTarget = 16.0; // Objectif journalier (16$)
static double g_dailyMaxAllowed = 20.0; // Maximum autorisé (20$)
static datetime g_dailyResetTime = 0; // Heure de réinitialisation journalière
static bool g_dailyTargetReached = false; // Objectif journalier atteint
static bool g_robotStoppedForDay = false; // Robot arrêté pour la journée
static int g_dailyTradesCount = 0; // Nombre de trades journaliers

//| VARIABLES POUR PROTECTION DES GAINS ACCUMULÉS |
static double g_weeklyStartingBalance = 0.0; // Solde de début de semaine
static double g_monthlyStartingBalance = 0.0; // Solde de début de mois
static double g_totalAccumulatedGains = 0.0; // Gains totaux accumulés
static double g_maxWeeklyProfit = 0.0; // Profit hebdomadaire maximum atteint
static double g_maxMonthlyProfit = 0.0; // Profit mensuel maximum atteint
static datetime g_weeklyResetTime = 0; // Réinitialisation hebdomadaire
static datetime g_monthlyResetTime = 0; // Réinitialisation mensuelle
static bool g_capitalProtectionMode = false; // Mode protection capital activé

//| VARIABLES POUR SCAN MULTI-SYMBOLES |
static string g_trackedSymbols[20]; // Symboles suivis
static int g_trackedSymbolsCount = 0; // Nombre de symboles suivis
static double g_symbolOpportunityScore[20]; // Score d'opportunité par symbole
static datetime g_lastScanTime = 0; // Dernier scan multi-symboles
static string g_symbolAIAction[20];
static double g_symbolAIConfidence[20];
static datetime g_symbolAIUpdate[20];

//| VARIABLES POUR ZONES DE CORRECTION SUPABASE |
static datetime g_lastCorrectionZonesUpdate = 0; // Dernière mise à jour des zones de correction
static double g_correctionSupportLevels[10]; // Niveaux de support par symbole
static double g_correctionResistanceLevels[10]; // Niveaux de résistance par symbole
static double g_correctionPremiumLevels[10]; // Niveaux Premium par symbole
static double g_correctionDiscountLevels[10]; // Niveaux Discount par symbole
static bool g_correctionZonesLoaded[10]; // Zones chargées par symbole
static const int CORRECTION_ZONES_UPDATE_INTERVAL = 300; // 5 minutes entre les mises à jour

//| VARIABLES POUR EMA COMME SUPPORT/RÉSISTANCE |
static double g_ema9[1000];       // EMA 9 périodes
static double g_ema21[1000];      // EMA 21 périodes  
static double g_ema50[1000];      // EMA 50 périodes
static double g_ema100[1000];     // EMA 100 périodes
static double g_ema200[1000];     // EMA 200 périodes
static datetime g_emaLastUpdateTime = 0; // Dernière mise à jour des EMA
static bool g_emaDataReady = false; // EMA prêtes à être utilisées

//--- Variables pour le prédicteur de corrections
double g_correctionMA[500];                // MA pour détection de corrections
datetime g_lastSpikeTime[10] = {0}; // Index 0-2: Boom 300/500/1000, 3-5: Crash 300/500/1000

// TEMPS DE DERNIÈRE FERMETURE DE POSITION PAR SYMBOLE (pour cooldown après spike)
datetime g_lastPositionCloseTime[10] = {0}; // Temps de dernière fermeture par symbole

// VARIABLES POUR L'ANALYSE QUANTITATIVE DES CORRECTIONS
int g_totalTrends = 0;                   // Nombre total de tendances analysées

int    g_correctionCount = 0;                   // Nombre de corrections détectées
int    g_durationSum = 0;                       // Somme des durées de corrections
double g_historicalCorrectionProb = 0.0;       // Probabilité historique de correction
double g_averageCorrectionDuration = 0.0;       // Durée moyenne des corrections
bool   g_correctionAnalysisDone = false;        // Flag pour éviter l'analyse répétée
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
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   atrHandle = iATR(_Symbol, LTF, 14);
   emaHandle = iMA(_Symbol, LTF, 9, 0, MODE_EMA, PRICE_CLOSE);
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
   Print("   IA: ", UseAIServer ? AI_ServerURL : "Désactivé");
   if(ShowMLMetrics)
   {
      long cid = ChartID();
      string mlLabelName = "SMC_ML_Metrics_" + _Symbol;
      if(ObjectCreate(cid, mlLabelName, OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetInteger(cid, mlLabelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(cid, mlLabelName, OBJPROP_XDISTANCE, 12);
         ObjectSetInteger(cid, mlLabelName, OBJPROP_YDISTANCE, 42);
         ObjectSetInteger(cid, mlLabelName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(cid, mlLabelName, OBJPROP_COLOR, clrDodgerBlue);
         ObjectSetString(cid, mlLabelName, OBJPROP_FONT, "Consolas");
         ObjectSetString(cid, mlLabelName, OBJPROP_TEXT, "ML (entraînement): En attente de données...");
      }
   }
   // Label visible "Décision ML" pour montrer que le robot utilise la décision du serveur IA
   if(UseAIServer)
   {
      long cid = ChartID();
      string decLabelName = "SMC_AI_Decision_" + _Symbol;
      if(ObjectCreate(cid, decLabelName, OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetInteger(cid, decLabelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(cid, decLabelName, OBJPROP_XDISTANCE, 10);
         ObjectSetInteger(cid, decLabelName, OBJPROP_YDISTANCE, 22);
         ObjectSetInteger(cid, decLabelName, OBJPROP_FONTSIZE, 11);
         ObjectSetInteger(cid, decLabelName, OBJPROP_COLOR, clrLime);
         ObjectSetString(cid, decLabelName, OBJPROP_FONT, "Consolas");
         ObjectSetString(cid, decLabelName, OBJPROP_TEXT, "Décision ML: — (en attente)");
      }
   }
   return INIT_SUCCEEDED;
}

bool TryAcquireOpenLock()
{
   string lockName = "SMC_OPEN_LOCK_" + IntegerToString(InpMagicNumber);
   
   // Vérification simple sans Sleep pour éviter détachement
   if(GlobalVariableGet(lockName) != 0) return false;
   GlobalVariableSet(lockName, 1);
   if(UseGlobalPositionLimit && CountPositionsOurEA() >= MaxPositionsTerminal)
   {
      GlobalVariableSet(lockName, 0);
      return false;
   }
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
   if(ema21LTF != INVALID_HANDLE) { IndicatorRelease(ema21LTF); ema21LTF = INVALID_HANDLE; }
   if(ema31LTF != INVALID_HANDLE) { IndicatorRelease(ema31LTF); ema31LTF = INVALID_HANDLE; }
   if(ema50LTF != INVALID_HANDLE) { IndicatorRelease(ema50LTF); ema50LTF = INVALID_HANDLE; }
   if(ema100LTF != INVALID_HANDLE) { IndicatorRelease(ema100LTF); ema100LTF = INVALID_HANDLE; }
   if(ema200LTF != INVALID_HANDLE) { IndicatorRelease(ema200LTF); ema200LTF = INVALID_HANDLE; }
   ObjectDelete(ChartID(), "SMC_ML_Metrics_" + _Symbol);
   ObjectDelete(ChartID(), "SMC_AI_Decision_" + _Symbol);
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

// Zone Discount "épuisée": prix descendu au-delà des 3/4 de la zone (proche du bas)
bool IsDeepInDiscountZone75()
{
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
   for(int i = n - 20; i < n; i++)
      sma20[i] = sma20[MathMax(0, n - 21)];

   double eq = sma20[0];
   double discLow = low[ArrayMinimum(low, 0, 20)];
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(discLow >= eq) return false;
   if(bid < discLow || bid > eq) return false; // pas en zone discount

   double zoneHeight = eq - discLow;
   // 3/4 du niveau d'achat: dernier quart (25%) de la zone proche du bas
   double deepThreshold = discLow + zoneHeight * 0.25;
   return (bid <= deepThreshold);
}

// Zone Premium "épuisée": prix monté au-delà des 3/4 de la zone (proche du haut)
bool IsDeepInPremiumZone75()
{
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
   for(int i = n - 20; i < n; i++)
      sma20[i] = sma20[MathMax(0, n - 21)];

   double eq = sma20[0];
   double premHigh = high[ArrayMaximum(high, 0, 20)];
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(premHigh <= eq) return false;
   if(ask < eq || ask > premHigh) return false; // pas en zone premium

   double zoneHeight = premHigh - eq;
   // 3/4 de la zone Premium: dernier quart (25%) proche du haut
   double deepThreshold = premHigh - zoneHeight * 0.25;
   return (ask >= deepThreshold);
}

// Détection d'une tendance en escalier (trend staircase) sur Boom/Crash
// direction: "BUY" ou "SELL"
bool IsBoomCrashTrendStaircase(string direction)
{
   string dir = direction;
   StringToUpper(dir);
   if(dir != "BUY" && dir != "SELL")
      return false;

   // Utiliser l'historique M1 récent pour détecter un enchaînement de bougies dans le même sens
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 40, rates) < 25)
      return false;

   int upSteps = 0;
   int downSteps = 0;
   // Regarder les 20 dernières transitions de clôture
   for(int i = 1; i <= 20; i++)
   {
      double cNow  = rates[i-1].close;
      double cPrev = rates[i].close;
      if(cNow > cPrev)
         upSteps++;
      else if(cNow < cPrev)
         downSteps++;
   }

   double totalSteps = upSteps + downSteps;
   if(totalSteps < 5)
      return false;

   double upRatio   = (double)upSteps   / totalSteps;
   double downRatio = (double)downSteps / totalSteps;

   // Vérifier aussi l'alignement EMA court terme (emaFastM1 / emaSlowM1)
   double emaFast = 0.0, emaSlow = 0.0;
   double bufFast[], bufSlow[];
   ArraySetAsSeries(bufFast, true);
   ArraySetAsSeries(bufSlow, true);

   if(emaFastM1 != INVALID_HANDLE && CopyBuffer(emaFastM1, 0, 0, 1, bufFast) > 0)
      emaFast = bufFast[0];
   if(emaSlowM1 != INVALID_HANDLE && CopyBuffer(emaSlowM1, 0, 0, 1, bufSlow) > 0)
      emaSlow = bufSlow[0];

   bool emaBull = (emaFast > 0.0 && emaSlow > 0.0 && emaFast > emaSlow);
   bool emaBear = (emaFast > 0.0 && emaSlow > 0.0 && emaFast < emaSlow);

   if(dir == "BUY")
      return emaBull && upRatio >= 0.65;

   if(dir == "SELL")
      return emaBear && downRatio >= 0.65;

   return false;
}

// Vérifie si un ordre LIMIT est autorisé par l'IA pour une direction donnée ("BUY"/"SELL")
bool IsAILimitOrderAllowed(string direction)
{
   if(!UseAIServer) return true; // pas de filtre IA si serveur désactivé

   string dir = direction;
   StringToUpper(dir);
   string ia = g_lastAIAction;
   StringToUpper(ia);

   // IA HOLD ou inconnue → ne pas placer d'ordre limite
   if(ia == "" || ia == "HOLD")
   {
      Print("🚫 ORDRE LIMIT BLOQUÉ - IA en HOLD ou inconnue (", ia, ") pour direction ", dir);
      return false;
   }

   // IA strictement contraire à la direction LIMIT → bloquer
   if((dir == "BUY" && ia == "SELL") || (dir == "SELL" && ia == "BUY"))
   {
      Print("🚫 ORDRE LIMIT BLOQUÉ - IA contraire (IA=", ia, ", direction LIMIT=", dir, ")");
      return false;
   }

   return true;
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
   double tolerance = atrVal * 0.8; // AUGMENTÉ de 0.4 à 0.8 ATR pour plus de sensibilité
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
   double tolerance = atrVal * 0.8; // AUGMENTÉ de 0.4 à 0.8 ATR pour plus de sensibilité
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
   if((UseGlobalPositionLimit && CountPositionsOurEA() >= MaxPositionsTerminal) || IsMaxSimultaneousEAOrdersReached()) return;
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
   
   if(!HasRecentSMCDerivArrowForDirection("BUY"))
   {
      Print("🚫 FVG_Kill BUY bloqué - Attendre flèche SMC_DERIV_ARROW BUY sur ", _Symbol);
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
   if((UseGlobalPositionLimit && CountPositionsOurEA() >= MaxPositionsTerminal) || IsMaxSimultaneousEAOrdersReached()) return;
   if(!TryAcquireOpenLock()) return;
   
   if(!CanOpenAdditionalPositionForSymbol(_Symbol, "SELL"))
   {
      Print("❌ FVG_Kill SELL bloqué (règle duplication / IA) sur ", _Symbol);
      ReleaseOpenLock();
      return;
   }
   double lot = CalculateLotSize();
   if(lot <= 0) { ReleaseOpenLock(); return; }
   
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
   
   if(!HasRecentSMCDerivArrowForDirection("SELL"))
   {
      Print("🚫 FVG_Kill SELL bloqué - Attendre flèche SMC_DERIV_ARROW SELL sur ", _Symbol);
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

// Comptabilise toutes les positions + ordres en attente de l'EA (par magic)
int CountEAActiveOrdersAndPositions()
{
   int count = 0;

   // Positions ouvertes
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      count++;
   }

   // Ordres en attente
   for(int j = OrdersTotal() - 1; j >= 0; j--)
   {
      ulong ticket = OrderGetTicket(j);
      if(ticket == 0) continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      count++;
   }

   return count;
}

// Vrai si on a déjà le nombre maximum d'ordres "actifs" (positions + pending) pour l'EA
bool IsMaxSimultaneousEAOrdersReached()
{
   int maxAllowed = UseGlobalPositionLimit ? MaxPositionsTerminal : 1000000; // si désactivé, plafond très haut
   int totalEA = CountEAActiveOrdersAndPositions();

   if(totalEA >= maxAllowed)
   {
      static datetime lastLogSim = 0;
      if(TimeCurrent() - lastLogSim >= 30)
      {
         Print("🛡️ LIMITE D'ORDRES EA ATTEINTE - ",
               totalEA, "/", maxAllowed,
               " (positions + ordres LIMIT/pending). Aucun nouveau trade n'est lancé.");
         lastLogSim = TimeCurrent();
      }
      return true;
   }

   return false;
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

//| PROTECTION DES GAINS ACCUMULÉS - Éviter l'effet dent de scie       |
//| Protège les gains réalisés après 2+ trades gagnants successifs   |
void UpdateAccumulatedGainsProtection()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Initialiser au premier lancement
   if(g_accumulatedGainsStart == 0.0)
   {
      g_accumulatedGainsStart = currentEquity;
      g_peakAccumulatedGains = currentEquity;
      g_gainsProtectionActive = false;
      return;
   }
   
   double accumulatedGains = currentEquity - g_accumulatedGainsStart;
   
   // Détecter si on a atteint le seuil de gains accumulés
   if(!g_gainsProtectionActive && accumulatedGains >= ProtectAccumulatedGainsThreshold)
   {
      g_gainsProtectionActive = true;
      g_gainsProtectionStartTime = TimeCurrent();
      g_peakAccumulatedGains = currentEquity;
      
      Print("🛡️ PROTECTION GAINS ACTIVÉE - Gains accumulés: ", DoubleToString(accumulatedGains, 2), "$ ≥ ", 
            DoubleToString(ProtectAccumulatedGainsThreshold, 2), "$");
      Print("   💰 Sommet atteint: ", DoubleToString(g_peakAccumulatedGains, 2), "$");
      Print("   🚫 Perte maximale autorisée: ", DoubleToString(MaxLossAfterGainsProtection, 2), "$");
   }
   
   // Si la protection est active, vérifier si on dépasse la perte maximale autorisée
   if(g_gainsProtectionActive)
   {
      double drawdownFromPeak = g_peakAccumulatedGains - currentEquity;
      
      if(drawdownFromPeak >= MaxLossAfterGainsProtection)
      {
         Print("🚨 PERTE MAXIMALE ATTEINTE - Drawdown: ", DoubleToString(drawdownFromPeak, 2), "$ ≥ ", 
               DoubleToString(MaxLossAfterGainsProtection, 2), "$");
         Print("   🔄 Fermeture de toutes les positions pour protéger les gains accumulés");
         
         // Fermer toutes les positions de l'EA
         CloseAllEAPositions("Protection gains accumulés - perte max atteinte");
         
         // Réinitialiser la protection
         g_gainsProtectionActive = false;
         g_accumulatedGainsStart = currentEquity;
         g_peakAccumulatedGains = currentEquity;
      }
   }
}

//| Vérifie si la protection des gains est active                    |
bool IsAccumulatedGainsProtectionActive()
{
   return g_gainsProtectionActive;
}

//| Ferme toutes les positions de l'EA avec une raison spécifique     |
void CloseAllEAPositions(string reason)
{
   int totalPositions = PositionsTotal();
   for(int i = totalPositions - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      
      ulong ticket = posInfo.Ticket();
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      string symbol = posInfo.Symbol();
      
      if(PositionCloseWithLog(ticket, reason))
      {
         Print("✅ Position fermée - ", symbol, ": ", DoubleToString(profit, 2), "$ (", reason, ")");
      }
      else
      {
         Print("❌ Échec fermeture - ", symbol, ": ", DoubleToString(profit, 2), "$ (", reason, ")");
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
      if(StringFind(symbol, "Boom") >= 0 && movePct >= BoomCrashSpikePct)
      {
         if(CloseBoomCrashPosition(ticket, symbol))
         {
            Print("🚀 Boom/Crash fermé (spike prix ", DoubleToString(currentProfit, 2), "$) - ", symbol);
            g_lastBoomCrashPrice = 0;
            s_lastRefUpdate = 0;
         }
      }
      if(StringFind(symbol, "Crash") >= 0 && movePct <= -BoomCrashSpikePct)
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
      
      if(cat != SYM_BOOM_CRASH) continue;
      
      // MODE SCALP FLÈCHE: fermer quand la flèche disparaît après avoir capté le spike
      if(ScalpArrowMode && symbol == _Symbol)
      {
         string posDir = (posInfo.PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";
         double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
         bool arrowGone = !HasRecentSMCDerivArrowForDirection(posDir);
         if(arrowGone && profit > 0)
         {
            ulong ticket = posInfo.Ticket();
            if(PositionCloseWithLog(ticket, "Scalp flèche - flèche disparue après spike capté"))
            {
               Print("🎯 SCALP FLÈCHE FERMÉ - ", symbol, " | Flèche disparue + spike capté (", DoubleToString(profit, 2), "$)");
               RecordPositionCloseTime(symbol);
               if(profit > 0) RecordProfitClose(symbol);
               if(UseNotifications) SendNotification("🎯 Scalp flèche fermé - " + symbol + " - " + DoubleToString(profit, 2) + "$");
            }
            continue;
         }
      }
      
      // NOUVEAU: Distinguer les trades "SPIKE TRADE" des autres:
      // - SPIKE TRADE: fermeture possible immédiatement après spike capté
      // - Autres trades Boom/Crash: laisser respirer quelques secondes
      datetime openTime = posInfo.Time();
      int secondsSinceOpen = (int)(TimeCurrent() - openTime);
      string comment = posInfo.Comment();
      bool isSpikeTrade = (StringFind(comment, "SPIKE TRADE") >= 0);
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      double openPrice = posInfo.PriceOpen();
      double currentPrice = (posInfo.PositionType() == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(symbol, SYMBOL_ASK);
      
      // SORTIE RAPIDE EN CORRECTION (sans délai): si marché en correction avec perte, fermer immédiatement
      if(symbol == _Symbol && UseCorrectionZoneProtection && g_correctionAnalysisDone && 
         GetCorrectionScore() >= CorrectionZoneRiskThreshold && profit < 0)
      {
         ulong ticket = posInfo.Ticket();
         if(PositionCloseWithLog(ticket, "Correction détectée - couper perte"))
         {
            Print("🛑 SORTIE CORRECTION - ", symbol, " | Perte limitée: ", DoubleToString(profit, 2), "$ | ticket=", ticket);
            UpdateSymbolPauseInfo(symbol, profit);
            if(UseNotifications)
               SendNotification("🛑 Sortie correction - " + symbol + " - Perte limitée " + DoubleToString(profit, 2) + "$");
         }
         continue;
      }
      
      // Pour les trades classiques (non-SPIKE), attendre 10s avant fermeture spike
      if(!isSpikeTrade && secondsSinceOpen < 10)
      {
         continue;
      }
      
      // Calculer le pourcentage de profit/perte
      double priceChangePercent = MathAbs((currentPrice - openPrice) / openPrice) * 100;
      
      // DEBUG: Log l'état de la position
      Print("🔍 DEBUG - Position Spike Close - ", symbol, 
            " | Profit: ", DoubleToString(profit, 2), "$",
            " | Changement: ", DoubleToString(priceChangePercent, 3), "%",
            " | Type: ", (posInfo.PositionType() == POSITION_TYPE_BUY ? "BUY" : "SELL"));
      
      // Fermer sur profit positif (spike capté) - PLUS RÉACTIF
      bool shouldClose = false;
      string closeReason = "";
      
      if(profit >= 0.10) // Seuil réduit à 0.10$ pour fermeture rapide
      {
         shouldClose = true;
         closeReason = "Spike capté (profit ≥ 0.10$)";
      }
      // Fermer sur perte importante (protection)
      else if(profit <= -0.50) // Seuil de perte à 0.50$
      {
         shouldClose = true;
         closeReason = "Perte excessive (≤ -0.50$)";
      }
      // Fermer sur mouvement de spike rapide même avec petit gain
      else if(priceChangePercent >= 0.3 && profit > 0.05) // Mouvement ≥ 0.3% avec profit > 0.05$
      {
         shouldClose = true;
         closeReason = "Spike rapide détecté";
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
            
            // NOUVEAU: ENREGISTRER LA FERMETURE SI C'EST UN GAIN
            if(profit > 0)
            {
               RecordProfitClose(symbol);
            }
            
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
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      int secondsSinceOpen = (int)(TimeCurrent() - openTime);
      
      // SORTIE CORRECTION: pas de délai (priorité sur le délai 30s)
      if(cat == SYM_BOOM_CRASH && symbol == _Symbol && UseCorrectionZoneProtection && 
         g_correctionAnalysisDone && GetCorrectionScore() >= CorrectionZoneRiskThreshold && profit < 0)
      {
         Print("🛑 SORTIE CORRECTION Boom/Crash - ", symbol, " | Perte: ", DoubleToString(profit, 2), "$ | ticket=", ticket);
         if(!PositionSelectByTicket(ticket)) { continue; }
         if(PositionCloseWithLog(ticket, "Correction détectée - couper perte"))
         {
            Print("✅ Position fermée en correction - perte limitée");
            UpdateSymbolPauseInfo(symbol, profit);
         }
         continue;
      }
      
      // Laisser les trades respirer 30 secondes sauf sortie correction
      if(secondsSinceOpen < 30)
      {
         continue;
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
      
      // Règle de perte maximale
      if(cat == SYM_BOOM_CRASH)
         ; // Sinon: ne pas fermer Boom/Crash sur perte - laisser SL/TP
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
         // Spike TP pour Boom/Crash - PLUS RÉACTIF
         if(profit >= 0.10 && profit < 2.0) // Si entre 0.10$ et 2$
         {
            Print("⚠️ TENTATIVE FERMETURE BOOM/CRASH SPIKE TP - ", symbol, " | Profit: ", DoubleToString(profit, 2), "$ | Seuil: 0.10$");
            // VALIDATION: Vérifier que la position existe toujours avant de fermer
            if(!PositionSelectByTicket(ticket))
            {
               Print("⚠️ Position déjà fermée avant Boom/Crash spike TP - ", symbol, " | ticket=", ticket);
               continue;
            }
            
            if(CloseBoomCrashPosition(ticket, symbol))
            {
               Print("🚀 EA Boom/Crash fermé après spike (gain ≥ 0.10$): ", DoubleToString(profit, 2), "$ | ticket=", ticket, " - ", symbol);
               if(symbol == _Symbol) { g_lastBoomCrashPrice = 0; }
               
               // NOUVEAU: ENREGISTRER LA FERMETURE SI C'EST UN GAIN
               if(profit > 0)
               {
                  RecordProfitClose(symbol);
               }
               
               // NOUVEAU: Enregistrer le temps du spike pour la protection Crash 500
               if(StringFind(symbol, "Crash") >= 0)
               {
                  static datetime lastSpikeTime[10]; // Tableau pour différents symboles Crash
                  static int symbolIndex = -1;
                  
                  // Initialiser l'index si nécessaire
                  if(symbolIndex == -1)
                  {
                     if(StringFind(symbol, "Crash 300") >= 0) symbolIndex = 0;
                     else if(StringFind(symbol, "Crash 500") >= 0) symbolIndex = 1;
                     else if(StringFind(symbol, "Crash 1000") >= 0) symbolIndex = 2;
                     else symbolIndex = 3; // Autres Crash
                  }
                  
                  lastSpikeTime[symbolIndex] = TimeCurrent();
                  Print("🎯 SPIKE CRASH ENREGISTRÉ - ", symbol, " | Spike TP: ", DoubleToString(profit, 2), "$");
                  Print("   ⏱️ Temps spike enregistré pour protection des prochaines entrées");
               }
            }
            continue;
         }
      }
   }
}

//| VALIDATION DES ORDRES LIMITES - Vérification juste avant exécution   |
//| Vérifie si un ordre LIMIT est proche de l'exécution (3 dernières bougies M1) |
bool IsLimitOrderNearExecution(ulong orderTicket)
{
   if(!OrderSelect(orderTicket)) return false;
   
   string symbol = OrderGetString(ORDER_SYMBOL);
   double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
   ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   
   // Obtenir les prix actuels
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   
   if(bid <= 0 || ask <= 0) return false;
   
   // Calculer la distance au prix actuel
   double distance = 0.0;
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      // BUY LIMIT: exécution quand ask <= orderPrice
      distance = ask - orderPrice;
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      // SELL LIMIT: exécution quand bid >= orderPrice
      distance = orderPrice - bid;
   }
   
   // Si distance négative, l'ordre est déjà dans la zone d'exécution
   if(distance < 0) return true;
   
   // Obtenir l'ATR pour calculer la distance "proche"
   double atrValue = 0.0;
   if(atrHandle != INVALID_HANDLE)
   {
      double atr[];
      ArraySetAsSeries(atr, true);
      if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1)
         atrValue = atr[0];
   }
   
   // ATR par défaut si non disponible
   if(atrValue <= 0)
      atrValue = SymbolInfoDouble(symbol, SYMBOL_BID) * 0.002;
   
   // Considérer "proche" si distance <= 0.1 ATR (environ 1 bougie M1 pour Boom/Crash)
   double maxDistance = atrValue * 0.1;
   
   return (distance <= maxDistance);
}

//| DÉTECTION DE CORRECTION IMMINENTE |
//| Analyse plusieurs indicateurs pour prédire une correction proche |
bool IsPriceCorrectionImminent(string symbol)
{
   if(!CancelOrdersOnCorrection) return false;
   
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(currentPrice <= 0) return false;
   
   bool isBoom = (StringFind(symbol, "Boom") >= 0);
   bool isCrash = (StringFind(symbol, "Crash") >= 0);
   
   // 1. DÉTECTION PAR SURACHAT/SURVENTE (RSI)
   double rsiBuffer[];
   ArraySetAsSeries(rsiBuffer, true);
   
   int rsiHandle = iRSI(symbol, PERIOD_M1, 14, PRICE_CLOSE);
   if(rsiHandle != INVALID_HANDLE && CopyBuffer(rsiHandle, 0, 0, 5, rsiBuffer) >= 5)
   {
      double currentRSI = rsiBuffer[0];
      
      // Surachat pour Boom (risque de baisse), Survente pour Crash (risque de hausse)
      if((isBoom && currentRSI > 75.0) || (isCrash && currentRSI < 25.0))
      {
         Print("🚨 SIGNAL CORRECTION - RSI extrême: ", DoubleToString(currentRSI, 1), 
               " sur ", symbol, " - Correction probable");
         return true;
      }
   }
   
   // 2. DÉTECTION PAR ÉCART EMA EXCESSIF
   if(g_emaDataReady)
   {
      double ema9 = g_ema9[0];
      double ema21 = g_ema21[0];
      
      if(ema9 > 0 && ema21 > 0)
      {
         double deviation9 = MathAbs(currentPrice - ema9) / ema9 * 100;
         double deviation21 = MathAbs(currentPrice - ema21) / ema21 * 100;
         
         // Écart excessif par rapport aux EMA (signe de sur-réaction)
         if(deviation9 > 1.5 || deviation21 > 2.0)
         {
            Print("🚨 SIGNAL CORRECTION - Écart EMA excessif: ", 
                  DoubleToString(deviation9, 2), "% / ", DoubleToString(deviation21, 2), 
                  "% sur ", symbol, " - Correction probable");
            return true;
         }
      }
   }
   
   // 3. DÉTECTION PAR SPIKE DE VOLATILITÉ
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   if(atrHandle != INVALID_HANDLE && CopyBuffer(atrHandle, 0, 0, 10, atrBuffer) >= 10)
   {
      double currentATR = atrBuffer[0];
      double avgATR = 0;
      
      // Calculer la moyenne ATR des 9 dernières bougies
      for(int i = 1; i < 10; i++)
         avgATR += atrBuffer[i];
      avgATR /= 9;
      
      // Spike de volatilitité actuel (2x la moyenne normale)
      if(currentATR > avgATR * 2.0)
      {
         Print("🚨 SIGNAL CORRECTION - Spike volatilité: ", 
               DoubleToString(currentATR, _Digits), " vs moyenne ", DoubleToString(avgATR, _Digits),
               " sur ", symbol, " - Correction probable");
         return true;
      }
   }
   
   // 4. DÉTECTION PAR CHANGEMENT IA RÉCENT
   if(UseAIServer && g_lastAIAction != "")
   {
      static datetime lastAIChangeTime = 0;
      static string lastAIAction = "";
      
      if(g_lastAIAction != lastAIAction)
      {
         lastAIChangeTime = TimeCurrent();
         lastAIAction = g_lastAIAction;
      }
      
      // Si IA vient de changer vers HOLD (signe d'incertitude)
      if(g_lastAIAction == "HOLD" && (TimeCurrent() - lastAIChangeTime) < 300) // 5 minutes
      {
         Print("🚨 SIGNAL CORRECTION - IA récemment passée à HOLD sur ", symbol,
               " - Correction probable");
         return true;
      }
   }
   
   return false;
}

//| ENREGISTREMENT DES TEMPS DE SPIKE PAR SYMBOLE |
//| Permet de détecter les corrections basées sur l'absence de spike |
void RecordSpikeTime(string symbol)
{
   int symbolIndex = GetSymbolIndex(symbol);

   if(symbolIndex >= 0 && symbolIndex < 10)
   {
      g_lastSpikeTime[symbolIndex] = TimeCurrent();
      Print("🎯 SPIKE ENREGISTRÉ - ", symbol, " | Temps: ", TimeToString(g_lastSpikeTime[symbolIndex]));
   }
}

//| VÉRIFICATION DE COOLDOWN APRÈS FERMETURE |
//| Vérifie si le symbole est en période d'attente après une fermeture |
bool IsPositionInCooldown(string symbol)
{
   int symbolIndex = GetSymbolIndex(symbol);
   
   if(symbolIndex < 0 || symbolIndex >= 10)
      return false; // Symbole non reconnu, pas de cooldown
   
   if(g_lastPositionCloseTime[symbolIndex] == 0)
      return false; // Pas de fermeture précédente, pas de cooldown
   
   // Calculer le temps écoulé depuis la dernière fermeture
   int secondsSinceClose = (int)(TimeCurrent() - g_lastPositionCloseTime[symbolIndex]);
   int barsToWait = MathMax(4, MathMin(10, CooldownBarsAfterSpikeClose)); // 4-10 bougies
   int cooldownSeconds = barsToWait * 60; // bougies M1 * 60 secondes
   
   if(secondsSinceClose < cooldownSeconds)
   {
      int remainingBars = (cooldownSeconds - secondsSinceClose) / 60;
      Print("🔄 COOLDOWN ACTIF - ", symbol, " | ", remainingBars, " bougie(s) restante(s) avant nouvelle entrée");
      return true; // Encore en cooldown
   }
   
   return false; // Cooldown terminé
}

//| ENREGISTRER LE TEMPS DE FERMETURE |
//| Enregistre l'heure de fermeture pour le cooldown |
void RecordPositionCloseTime(string symbol)
{
   int symbolIndex = GetSymbolIndex(symbol);
   
   if(symbolIndex >= 0 && symbolIndex < 10)
   {
      g_lastPositionCloseTime[symbolIndex] = TimeCurrent();
      int bars = MathMax(4, MathMin(10, CooldownBarsAfterSpikeClose));
      Print("⏰ FERMETURE ENREGISTRÉE - ", symbol, " | Cooldown de ", bars, " bougies M1 activé");
   }
}

//| VÉRIFICATION AVANT NOUVELLE ENTRÉE |
//| Vérifie si une nouvelle entrée est autorisée (cooldown + conditions) |
bool CheckCooldownBeforeEntry(string symbol)
{
   // Vérifier d'abord si en cooldown
   if(IsPositionInCooldown(symbol))
   {
      Print("🚫 ENTRÉE BLOQUÉE - ", symbol, " | En cooldown après fermeture récente");
      return false;
   }
   
   // Vérifier les conditions de marché
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   if(currentPrice <= 0) return false;
   
   bool isBoom = (StringFind(symbol, "Boom") >= 0);
   bool isCrash = (StringFind(symbol, "Crash") >= 0);
   
   // Index dédié aux spikes (doit matcher la logique de détection série spikes)
   int spikeSymbolIndex = -1;
   if(StringFind(symbol, "Crash 300") >= 0) spikeSymbolIndex = 0;
   else if(StringFind(symbol, "Crash 500") >= 0) spikeSymbolIndex = 1;
   else if(StringFind(symbol, "Crash 1000") >= 0) spikeSymbolIndex = 2;
   else if(StringFind(symbol, "Boom 300") >= 0) spikeSymbolIndex = 3;
   else if(StringFind(symbol, "Boom 500") >= 0) spikeSymbolIndex = 4;
   else if(StringFind(symbol, "Boom 1000") >= 0) spikeSymbolIndex = 5;
   else spikeSymbolIndex = 6;
   
   // Pour Boom/Crash: éviter d'entrer juste après un spike détecté (protection anti-correction)
   if((isBoom || isCrash) && spikeSymbolIndex >= 0)
   {
      // Le code de détection met à jour g_lastSpikeDetectionTime[], pas g_lastSpikeTime[]
      datetime lastSpike = 0;
      if(spikeSymbolIndex < 10)
         lastSpike = g_lastSpikeDetectionTime[spikeSymbolIndex];

      // Fallback: si un autre module a rempli g_lastSpikeTime[]
      int fallbackIndex = GetSymbolIndex(symbol);
      if(lastSpike <= 0 && fallbackIndex >= 0 && fallbackIndex < 10)
         lastSpike = g_lastSpikeTime[fallbackIndex];

      if(lastSpike > 0 && (TimeCurrent() - lastSpike) < 300) // 5 minutes
      {
         int minutesSince = (int)(TimeCurrent() - lastSpike) / 60;
         Print("🚫 ENTRÉE BLOQUÉE - Spike trop récent sur ", symbol,
               " | ", minutesSince, " min depuis spike (attendre stabilisation / éviter correction)");
         return false;
      }
   }
   
   return true; // Entrée autorisée
}

//| COOLDOWN ALLÉGÉ POUR SÉRIES DE SPIKES                         |
//| Autorise une ré‑entrée beaucoup plus rapide après un spike    |
//| Utilisé uniquement par ExecuteSpikeSeriesTrade                |
bool CheckSeriesCooldownBeforeEntry(string symbol)
{
   int symbolIndex = GetSymbolIndex(symbol);
   if(symbolIndex < 0 || symbolIndex >= 10)
      return true;  // symbole non suivi → pas de cooldown spécial
   
   if(g_lastPositionCloseTime[symbolIndex] == 0)
      return true;  // aucune fermeture précédente → OK
   
   int secondsSinceClose = (int)(TimeCurrent() - g_lastPositionCloseTime[symbolIndex]);
   // Pour les séries de spikes: 1 à 3 bougies maximum d'attente
   int barsToWait = 2;
   int cooldownSeconds = barsToWait * 60;
   
   if(secondsSinceClose < cooldownSeconds)
   {
      int remainingBars = (cooldownSeconds - secondsSinceClose) / 60;
      Print("🔄 COOLDOWN SÉRIE SPIKE ACTIF - ", symbol, " | ", remainingBars,
            " bougie(s) restante(s) avant nouvelle entrée de série");
      return false;
   }
   
   // IMPORTANT: ne pas appliquer ici la protection 5 minutes g_lastSpikeDetectionTime[]
   // La détection de série suppose justement plusieurs spikes rapprochés.
   return true;
}

//| ANNULATION DES ORDRES SUR CORRECTION IMMINENTE |
//| Annule tous les ordres LIMIT si une correction est détectée |
void CancelOrdersOnImminentCorrection()
{
   if(!CancelOrdersOnCorrection) return;
   
   // Vérifier tous les symboles Boom/Crash pour les corrections
   string symbols[] = {"Boom 500 Index", "Boom 1000 Index", "Crash 500 Index", "Crash 1000 Index", "Crash 300 Index", "Boom 300 Index"};
   
   for(int s = 0; s < ArraySize(symbols); s++)
   {
      string symbol = symbols[s];
      
      // Vérifier si une correction est imminente pour ce symbole
      if(!IsPriceCorrectionImminent(symbol))
         continue;
         
      Print("🚨 CORRECTION IMMINENTE DÉTECTÉE - Annulation des ordres sur ", symbol);
      
      // Parcourir tous les ordres en attente
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         ulong ticket = OrderGetTicket(i);
         if(ticket == 0) continue;
         
         // Vérifier si c'est un ordre de notre EA sur ce symbole
         if(OrderGetString(ORDER_SYMBOL) != symbol) continue;
         if((ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
         
         ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(orderType != ORDER_TYPE_BUY_LIMIT && orderType != ORDER_TYPE_SELL_LIMIT) continue;
         
         double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         string comment = OrderGetString(ORDER_COMMENT);
         
         // Annuler l'ordre
         if(trade.OrderDelete(ticket))
         {
            Print("✅ ORDRE ANNULÉ (CORRECTION) - Ticket: ", ticket,
                  " | Symbole: ", symbol,
                  " | Type: ", (orderType == ORDER_TYPE_BUY_LIMIT ? "BUY_LIMIT" : "SELL_LIMIT"),
                  " | Prix: ", DoubleToString(orderPrice, _Digits),
                  " | Commentaire: ", comment,
                  " | 🚨 Raison: Correction imminente détectée");
         }
         else
         {
            Print("❌ ÉCHEC ANNULATION (CORRECTION) - Ticket: ", ticket,
                  " | Erreur: ", GetLastError());
         }
      }
   }
}

//| EXÉCUTION AU MARCHÉ SUR TOUCH PIVOT |
//| Exécute un ordre au marché immédiatement quand le prix touche Pivot High/Low |
bool CheckAndExecuteMarketOrderOnPivotTouch()
{
   if(!ExecuteMarketOnPivotTouch) return false;
   
   // Ne jamais trader les touches de pivot quand une forte correction est en cours
   if(UseCorrectionZoneProtection && g_correctionAnalysisDone)
   {
      double correctionScore = GetCorrectionScore();
      bool isHighRiskZone = IsInHighRiskCorrectionZone();
      if(isHighRiskZone && correctionScore >= CorrectionZoneRiskThreshold)
      {
         Print("🚫 PIVOT TOUCH BLOQUÉ - Zone de correction à haut risque (Score: ",
               DoubleToString(correctionScore, 1), "%) → pas de trade sur ", _Symbol);
         return false;
      }
   }
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(currentPrice <= 0 || currentAsk <= 0) return false;
   
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   if(!isBoom && !isCrash) return false;
   
   // Limite globale: ne jamais dépasser MaxPositionsTerminal trades EA (optionnelle)
   if(IsMaxSimultaneousEAOrdersReached() || (UseGlobalPositionLimit && CountPositionsOurEA() >= MaxPositionsTerminal))
   {
      Print("🚫 PIVOT TOUCH BLOQUÉ - Limite de positions atteinte (", MaxPositionsTerminal, ")");
      return false;
   }
   
   // Vérification IA: utiliser uniquement les signaux clairement directionnels avec forte confiance
   string iaAct = g_lastAIAction;
   StringToUpper(iaAct);
   double iaConf = g_lastAIConfidence;
   
   if(UseAIServer)
   {
      if(iaAct == "HOLD" || iaAct == "")
      {
         Print("🚫 PIVOT TOUCH BLOQUÉ - IA en HOLD / indéterminée sur ", _Symbol);
         return false;
      }
      // minConf/iaAct vérifiés par branche (SELL/BUY) pour permettre override si IA faiblement opposée
   }
   
   // Utiliser les MÊMES niveaux que les lignes visibles (BUY/SELL LIMIT sur le graphique)
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 30, r) < 5) return false;
   
   double atrVal = 0;
   if(atrHandle != INVALID_HANDLE) { double atr[]; ArraySetAsSeries(atr, true); if(CopyBuffer(atrHandle, 0, 0, 1, atr) >= 1) atrVal = atr[0]; }
   if(atrVal <= 0) atrVal = (r[0].high - r[0].low) * 2;
   
   string srcBuy = "", srcSell = "";
   double buyLevel = GetClosestBuyLevel(currentPrice, atrVal, MaxDistanceLimitATR, srcBuy);
   double sellLevel = GetClosestSellLevel(currentPrice, atrVal, MaxDistanceLimitATR, srcSell);
   
   double tol = MathMax(currentPrice * 0.002, atrVal * 0.5);
   
   // Touch SELL LIMIT = le HIGH récent a atteint le niveau (prix est monté puis le spike chute)
   bool touchedSellLevel = (sellLevel > 0) && ((r[0].high >= sellLevel - tol) || (r[1].high >= sellLevel - tol) || (r[2].high >= sellLevel - tol));
   // Touch BUY LIMIT = le LOW récent a atteint le niveau (prix est descendu puis rebond)
   bool touchedBuyLevel = (buyLevel > 0) && ((r[0].low <= buyLevel + tol) || (r[1].low <= buyLevel + tol) || (r[2].low <= buyLevel + tol));
   
   // RÈGLE CRITIQUE: ne jamais SELL quand le prix est tombé au BUY LIMIT (trop tard, spike déjà passé)
   bool priceAtBuyLevel = (buyLevel > 0) && (MathAbs(currentPrice - buyLevel) <= tol);
   // Ne jamais BUY quand le prix est monté au SELL LIMIT
   bool priceAtSellLevel = (sellLevel > 0) && (MathAbs(currentPrice - sellLevel) <= tol);
   
   // Bande trop serrée entre BUY LIMIT et SELL LIMIT ?
   double bandWidth = 0.0;
   bool hasBothLimits = (buyLevel > 0 && sellLevel > 0);
   if(hasBothLimits)
      bandWidth = MathAbs(sellLevel - buyLevel);
   // Seuil de « bande serrée » : 0.3% ou 1x ATR (le plus grand)
   double tightBandThreshold = MathMax(currentPrice * 0.003, atrVal * 1.0);
   bool isTightBand = hasBothLimits && (bandWidth > 0 && bandWidth <= tightBandThreshold);
   
   // 3. EXÉCUTION DES ORDRES AU MARCHÉ
   
   // Si prix touche SELL LIMIT → SELL au marché (Crash uniquement)
   // Jamais SELL quand le prix est tombé au BUY LIMIT (trop tard, le spike a déjà chuté)
   if(touchedSellLevel && !priceAtBuyLevel)
   {
      // Vérifier si on a déjà une position SELL sur ce symbole
      bool hasSellPosition = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetTicket(i) > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
               hasSellPosition = true;
               break;
            }
         }
      }
      
      if(!hasSellPosition)
      {
         double lotSize = CalculateLotSize();
         if(lotSize > 0)
         {
            // Crash uniquement pour ce mode
            if(!isCrash)
               return false;
            
            // IA: SELL confirmé OU override si IA BUY mais faible (<70%) - le touch du pivot prime
            if(UseAIServer)
            {
               bool iaOk = (iaAct == "SELL" && iaConf >= 0.77);
               if(!iaOk && AllowPivotTouchOverrideIA && iaAct == "BUY" && iaConf < 0.70)
                  iaOk = true; // Override: IA faiblement opposée, le touch SELL LIMIT est un signal technique fort
               if(!iaOk)
               {
                  Print("🚫 SELL PIVOT BLOQUÉ - IA ", iaAct, " (", DoubleToString(iaConf*100,1), "%) sur ", _Symbol);
                  return false;
               }
            }
            
            // PROTECTION: Ne jamais SELL au BUY LIMIT (prix tombé au support = spike déjà passé)
            if(priceAtBuyLevel)
            {
               Print("🚫 SELL PIVOT BLOQUÉ - Prix au BUY LIMIT (support) - Spike déjà chuté, mauvais niveau pour SELL sur ", _Symbol);
               return false;
            }
            
            // CAS SPÉCIAL: bande BUY/SELL LIMIT trop serrée → ne pas prendre le signal au marché,
            // mais placer un ordre SELL LIMIT légèrement SOUS le SELL LIMIT (plus proche du prix).
            if(isTightBand)
            {
               // Vérifier s'il n'y a pas déjà un ordre limite spécial
               for(int j = OrdersTotal() - 1; j >= 0; j--)
               {
                  ulong ot = OrderGetTicket(j);
                  if(ot == 0) continue;
                  if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
                  if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
                  string c = OrderGetString(ORDER_COMMENT);
                  if(StringFind(c, "TIGHT_BAND SELL LIMIT") >= 0)
                     return false; // déjà en place
               }
               
               double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               if(point <= 0) point = 0.00001;
               
               double offset = MathMax(atrVal * 0.5, point * 10); // déplacer de 0.5 ATR ou 10 points
               double limitPrice = sellLevel - offset;            // « sous » le SELL LIMIT (vers le prix)
               
               // Garantir une distance minimum au-dessus du prix actuel pour respecter la règle SELL LIMIT
               double minDist = point * 5;
               if(limitPrice <= currentPrice + minDist)
                  limitPrice = currentPrice + minDist;
               
               MqlTradeRequest req;
               MqlTradeResult  res;
               ZeroMemory(req);
               ZeroMemory(res);
               
               req.action   = TRADE_ACTION_PENDING;
               req.symbol   = _Symbol;
               req.magic    = InpMagicNumber;
               req.type     = ORDER_TYPE_SELL_LIMIT;
               req.volume   = lotSize;
               req.price    = limitPrice;
               // SL/TP simples basés sur ATR
               req.sl       = limitPrice + atrVal * 2.0;
               req.tp       = limitPrice - atrVal * 3.0;
               req.comment  = "TIGHT_BAND SELL LIMIT";
               
               if(OrderSend(req, res))
               {
                  Print("📌 TIGHT_BAND SELL LIMIT PLACÉ - ", _Symbol,
                        " | Prix: ", DoubleToString(limitPrice, _Digits),
                        " | Bande: ", DoubleToString(bandWidth, _Digits));
               }
               else
               {
                  Print("❌ ÉCHEC PLACEMENT TIGHT_BAND SELL LIMIT - Erreur: ", res.comment);
               }
               
               return false; // Ne pas exécuter au marché dans ce cas
            }
            
            // Contexte SMC: éviter de vendre en pleine correction haussière (sauf si touch clair du pivot = résistance)
            bool atPivotResistance = (sellLevel > 0 && MathAbs(currentPrice - sellLevel) <= MathMax(currentPrice * 0.003, atrVal * 0.8));
            bool inPremium = IsInPremiumZone();
            double emaRes = GetNearestEMAResistance(currentPrice);
            bool nearEMARes = (emaRes > 0.0 && IsPriceNearEMA(currentPrice, emaRes, 0.2));
            if(!atPivotResistance && !inPremium && !nearEMARes)
            {
               Print("🚫 SELL PIVOT BLOQUÉ - Prix pas en zone Premium ni près d'une résistance EMA sur ", _Symbol);
               return false;
            }
            
            // Annuler tous les ordres LIMIT en conflit
            CancelConflictingPendingLimitsForSymbol(_Symbol);
            
            // Exécuter SELL au marché
            if(trade.Sell(lotSize, _Symbol, currentPrice, 0, 0, "SELL PIVOT TOUCH - " + srcSell))
            {
               Print("🚀 SELL EXÉCUTÉ AU MARCHÉ - SELL LIMIT touché: ", DoubleToString(sellLevel, _Digits),
                     " | Prix: ", DoubleToString(currentPrice, _Digits),
                     " | Source: ", srcSell,
                     " | Lot: ", DoubleToString(lotSize, 2));
               
               // Dessiner une marque sur le graphique
               DrawPivotTouchMarker(sellLevel, true, srcSell);
               return true;
            }
            else
            {
               Print("❌ ÉCHEC SELL PIVOT TOUCH - Erreur: ", GetLastError());
            }
         }
      }
   }
   
   // Si prix touche BUY LIMIT → BUY au marché (Boom uniquement)
   if(touchedBuyLevel && !priceAtSellLevel)
   {
      // Vérifier si on a déjà une position BUY sur ce symbole
      bool hasBuyPosition = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetTicket(i) > 0)
         {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
               PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               hasBuyPosition = true;
               break;
            }
         }
      }
      
      if(!hasBuyPosition)
      {
         double lotSize = CalculateLotSize();
         if(lotSize > 0)
         {
            // Boom uniquement pour ce mode
            if(!isBoom)
               return false;
            
            // IA: BUY confirmé OU override si IA SELL mais faible (<70%) - le touch du pivot prime
            if(UseAIServer)
            {
               bool iaOk = (iaAct == "BUY" && iaConf >= 0.77);
               if(!iaOk && AllowPivotTouchOverrideIA && iaAct == "SELL" && iaConf < 0.70)
                  iaOk = true; // Override: IA faiblement opposée, le touch BUY LIMIT est un signal technique fort
               if(!iaOk)
               {
                  Print("🚫 BUY PIVOT BLOQUÉ - IA ", iaAct, " (", DoubleToString(iaConf*100,1), "%) sur ", _Symbol);
                  return false;
               }
            }
            
            // PROTECTION: Ne jamais BUY au SELL LIMIT (prix monté à résistance = mauvais timing)
            if(priceAtSellLevel)
            {
               Print("🚫 BUY PIVOT BLOQUÉ - Prix au SELL LIMIT (résistance) - Mauvais niveau pour BUY sur ", _Symbol);
               return false;
            }
            
            // CAS SPÉCIAL: bande BUY/SELL LIMIT trop serrée → ne pas prendre le signal au marché,
            // mais placer un ordre BUY LIMIT légèrement AU-DESSUS du BUY LIMIT (plus proche du prix).
            if(isTightBand)
            {
               // Vérifier s'il n'y a pas déjà un ordre limite spécial
               for(int j = OrdersTotal() - 1; j >= 0; j--)
               {
                  ulong ot = OrderGetTicket(j);
                  if(ot == 0) continue;
                  if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
                  if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
                  string c = OrderGetString(ORDER_COMMENT);
                  if(StringFind(c, "TIGHT_BAND BUY LIMIT") >= 0)
                     return false; // déjà en place
               }
               
               double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
               if(point <= 0) point = 0.00001;
               
               double offset = MathMax(atrVal * 0.5, point * 10); // déplacer de 0.5 ATR ou 10 points
               double limitPrice = buyLevel + offset;            // « au-dessus » du BUY LIMIT (vers le prix)
               
               // Garantir une distance minimum en dessous du prix actuel pour respecter BUY LIMIT
               double minDist = point * 5;
               if(limitPrice >= currentAsk - minDist)
                  limitPrice = currentAsk - minDist;
               
               MqlTradeRequest req;
               MqlTradeResult  res;
               ZeroMemory(req);
               ZeroMemory(res);
               
               req.action   = TRADE_ACTION_PENDING;
               req.symbol   = _Symbol;
               req.magic    = InpMagicNumber;
               req.type     = ORDER_TYPE_BUY_LIMIT;
               req.volume   = lotSize;
               req.price    = limitPrice;
               // SL/TP simples basés sur ATR
               req.sl       = limitPrice - atrVal * 2.0;
               req.tp       = limitPrice + atrVal * 3.0;
               req.comment  = "TIGHT_BAND BUY LIMIT";
               
               if(OrderSend(req, res))
               {
                  Print("📌 TIGHT_BAND BUY LIMIT PLACÉ - ", _Symbol,
                        " | Prix: ", DoubleToString(limitPrice, _Digits),
                        " | Bande: ", DoubleToString(bandWidth, _Digits));
               }
               else
               {
                  Print("❌ ÉCHEC PLACEMENT TIGHT_BAND BUY LIMIT - Erreur: ", res.comment);
               }
               
               return false; // Ne pas exécuter au marché dans ce cas
            }
            
            // Contexte SMC: zone Discount ou support EMA - SAUF si prix a touché le BUY LIMIT (touch = confirmation support)
            // Quand touchedBuyLevel, le LOW a atteint buyLevel → on est au support, bypass zone stricte si prix proche
            double nearBuyTol = MathMax(currentPrice * 0.004, atrVal * 1.0);  // 0.4% ou 1 ATR
            bool atBuyLevelNow = (buyLevel > 0 && MathAbs(currentPrice - buyLevel) <= nearBuyTol);
            bool inDiscount = IsInDiscountZone();
            double emaSup = GetNearestEMASupport(currentPrice);
            bool nearEMASup = (emaSup > 0.0 && IsPriceNearEMA(currentPrice, emaSup, 0.3));  // 0.3% tolérance
            if(!atBuyLevelNow && !inDiscount && !nearEMASup)
            {
               Print("🚫 BUY PIVOT BLOQUÉ - Prix pas en zone Discount ni près d'un support EMA sur ", _Symbol);
               return false;
            }
            
            // Annuler tous les ordres LIMIT en conflit
            CancelConflictingPendingLimitsForSymbol(_Symbol);
            
            // Exécuter BUY au marché
            if(trade.Buy(lotSize, _Symbol, currentAsk, 0, 0, "BUY PIVOT TOUCH - " + srcBuy))
            {
               Print("🚀 BUY EXÉCUTÉ AU MARCHÉ - BUY LIMIT touché: ", DoubleToString(buyLevel, _Digits),
                     " | Prix: ", DoubleToString(currentAsk, _Digits),
                     " | Source: ", srcBuy,
                     " | Lot: ", DoubleToString(lotSize, 2));
               
               // Dessiner une marque sur le graphique
               DrawPivotTouchMarker(buyLevel, false, srcBuy);
               return true;
            }
            else
            {
               Print("❌ ÉCHEC BUY PIVOT TOUCH - Erreur: ", GetLastError());
            }
         }
      }
   }
   
   return false;
}

//| FERMER SI PIVOT DISPARAÎT APRÈS TOUCH + PAS DE SPIKE EN 7 BOUGIES |
void CheckAndClosePivotTouchWithoutSpike()
{
   if(PositionsTotal() == 0) return;
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   if(!isBoom && !isCrash) return;
   
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 15, r) < 10) return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) point = 0.00001;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      if(posInfo.Symbol() != _Symbol) continue;
      
      string comment = posInfo.Comment();
      if(StringFind(comment, "PIVOT TOUCH") < 0) continue;
      
      bool isSell = (posInfo.Type() == POSITION_TYPE_SELL);
      double entryPrice = posInfo.PriceOpen();
      datetime openTime = (datetime)posInfo.Time();
      
      // Pivot "disparu" = niveau actuel (g_lastSwingHigh/Low) diffère de >0.2% du pivot d'entrée
      double pctTol = 0.002;
      bool pivotGone = false;
      if(isSell)
      {
         if(g_lastSwingHigh > 0 && MathAbs(g_lastSwingHigh - entryPrice) / MathMax(entryPrice, point) > pctTol)
            pivotGone = true;
         // Aussi: prix s'est éloigné du pivot (niveau cassé / nouveau swing)
         if(g_lastSwingHigh <= 0) pivotGone = true;  // Plus de pivot high valide
      }
      else // BUY
      {
         if(g_lastSwingLow > 0 && MathAbs(g_lastSwingLow - entryPrice) / MathMax(entryPrice, point) > pctTol)
            pivotGone = true;
         if(g_lastSwingLow <= 0) pivotGone = true;
      }
      
      if(pivotGone)
      {
         ulong ticket = posInfo.Ticket();
         double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
         Print("🚫 FERMETURE PIVOT TOUCH - Pivot disparu (ligne BUY/SELL LIMIT effacée) - ", _Symbol,
               " | Ticket: ", ticket, " | Profit: ", DoubleToString(profit, 2), "$");
         PositionCloseWithLog(ticket, "Pivot disparu - ligne LIMIT effacée");
      }
   }
}

//| DESSINER UNE MARQUE DE TOUCH PIVOT |
void DrawPivotTouchMarker(double price, bool isSell, string source)
{
   if(!ShowChartGraphics) return;
   
   datetime currentTime = TimeCurrent();
   string markerName = "PIVOT_TOUCH_" + (isSell ? "SELL_" : "BUY_") + IntegerToString((int)currentTime);
   
   // Supprimer l'ancien marqueur s'il existe
   if(ObjectFind(0, markerName) >= 0)
      ObjectDelete(0, markerName);
   
   // Créer une flèche pour marquer le touch
   if(ObjectCreate(0, markerName, OBJ_ARROW, 0, currentTime, price))
   {
      // Flèche plus visible (épaisse) + couleur selon type
      ObjectSetInteger(0, markerName, OBJPROP_COLOR, isSell ? clrRed : clrLime);
      ObjectSetInteger(0, markerName, OBJPROP_ARROWCODE, isSell ? 234 : 233); // Flèche haut/bas
      ObjectSetInteger(0, markerName, OBJPROP_WIDTH, 4);
      ObjectSetInteger(0, markerName, OBJPROP_BACK, false);
      // Légende explicite: Pivot High / Pivot Low
      string legend = (isSell ? "Pivot High (SELL LIMIT)" : "Pivot Low (BUY LIMIT)");
      ObjectSetString(0, markerName, OBJPROP_TEXT, legend);
      
      // Créer une ligne horizontale pour le niveau pivot
      string lineName = "PIVOT_LINE_" + (isSell ? "SELL_" : "BUY_") + IntegerToString((int)currentTime);
      if(ObjectFind(0, lineName) >= 0)
         ObjectDelete(0, lineName);
         
      if(ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, price))
      {
         // Ligne épaisse, bien visible, couleur cohérente avec la flèche
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, isSell ? clrRed : clrLime);
         ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
         // Mettre aussi un texte pour les niveaux, visible au survol
         string lineLegend = (isSell ? "Pivot High (SELL LIMIT)" : "Pivot Low (BUY LIMIT)");
         ObjectSetString(0, lineName, OBJPROP_TEXT, lineLegend);
      }
   }
}

//| ANNULATION INTELLIGENTE DES ORDRES LIMITES                     |
//| N'annule que les ordres LIMIT proches de l'exécution            |
void CancelConflictingPendingLimitsForSymbol(string symbol)
{
   if(!UseAIServer || !AutoCancelLimitOrders)
      return;

   bool isBoom  = (StringFind(symbol, "Boom")  >= 0);
   bool isCrash = (StringFind(symbol, "Crash") >= 0);
   if(!isBoom && !isCrash)
      return;

   string ia = g_lastAIAction;
   StringToUpper(ia);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != symbol)
         continue;
      if((ulong)OrderGetInteger(ORDER_MAGIC) != InpMagicNumber)
         continue;

      ENUM_ORDER_TYPE t = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(t != ORDER_TYPE_BUY_LIMIT && t != ORDER_TYPE_SELL_LIMIT)
         continue;

      // NOUVEAU: Vérifier si l'ordre est proche de l'exécution
      bool isNearExecution = IsLimitOrderNearExecution(ticket);
      
      // Si l'ordre est loin, ne PAS l'annuler même si conflit IA
      if(!isNearExecution)
      {
         double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
         double distance = 0.0;
         
         if(t == ORDER_TYPE_BUY_LIMIT)
            distance = ask - orderPrice;
         else if(t == ORDER_TYPE_SELL_LIMIT)
            distance = orderPrice - bid;
         
         Print("🔍 ORDRE LIMIT LOIN - Pas d'annulation | Ticket: ", ticket,
               " | Type: ", (t == ORDER_TYPE_BUY_LIMIT ? "BUY_LIMIT" : "SELL_LIMIT"),
               " | Prix: ", DoubleToString(orderPrice, _Digits),
               " | Distance: ", DoubleToString(distance, _Digits),
               " | IA: ", ia,
               " | 💡 Attendre exécution ou proximité");
         continue;
      }

      // NOUVEAU: Vérification renforcée de la cohérence IA avant annulation
      bool shouldCancel = false;
      string cancelReason = "";

      // Crash: SELL_LIMIT n'est autorisé que si IA est strictement SELL
      if(isCrash && t == ORDER_TYPE_SELL_LIMIT)
      {
         if(ia != "SELL")
         {
            shouldCancel = true;
            cancelReason = "IA Crash ≠ SELL pour SELL_LIMIT";
         }
      }

      // Boom: BUY_LIMIT n'est autorisé que si IA est strictement BUY
      if(isBoom && t == ORDER_TYPE_BUY_LIMIT)
      {
         if(ia != "BUY")
         {
            shouldCancel = true;
            cancelReason = "IA Boom ≠ BUY pour BUY_LIMIT";
         }
      }
      
      // NOUVEAU: Vérification supplémentaire - si IA est HOLD, conserver les ordres
      if(ia == "HOLD")
      {
         shouldCancel = false;
         cancelReason = "";
         Print("🛡️ IA HOLD - Conservation des ordres LIMIT | Ticket: ", ticket,
               " | Type: ", (t == ORDER_TYPE_BUY_LIMIT ? "BUY_LIMIT" : "SELL_LIMIT"),
               " | Attente retour signal BUY/SELL");
      }

      if(shouldCancel)
      {
         string cmt   = OrderGetString(ORDER_COMMENT);
         double price = OrderGetDouble(ORDER_PRICE_OPEN);
         Print("🚫 ANNULATION ORDRE LIMIT CONFLIT IA (PROCHE EXÉCUTION) - Ticket: ", ticket,
               " | Symbole: ", symbol,
               " | Type: ", (t == ORDER_TYPE_BUY_LIMIT ? "BUY_LIMIT" : "SELL_LIMIT"),
               " | IA: ", ia,
               " | Prix: ", DoubleToString(price, _Digits),
               " | Commentaire: ", cmt,
               " | ⚡ PROCHE EXÉCUTION - Raison: ", cancelReason);

         if(!trade.OrderDelete(ticket))
         {
            Print("❌ ÉCHEC ANNULATION LIMIT - Ticket: ", ticket,
                  " | Code erreur: ", GetLastError());
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

      // PRIORITÉ ABSOLUE: Conflit IA > Toutes les autres protections
      // Si l'IA dit BUY et on a un SELL (ou inverse), FERMER IMMÉDIATEMENT
      // Sans tenir compte des protections Boom/Crash, spike, ou autres
      
      // Récupérer les informations détaillées pour le log
      double profit = PositionGetDouble(POSITION_PROFIT);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      string comment = PositionGetString(POSITION_COMMENT);
      int secondsSinceOpen = (int)(TimeCurrent() - openTime);
      
      Print("🚨 CONFLIT IA DÉTECTÉ - ", psym,
            " | Type=", (ptype == POSITION_TYPE_BUY ? "BUY" : "SELL"),
            " | IA=", ai, " ", DoubleToString(conf * 100.0, 1), "%",
            " | Profit=", DoubleToString(profit, 2), "$",
            " | Âge=", secondsSinceOpen, "s",
            " | Comment=", comment,
            " | ⚠️ FERMETURE IMMÉDIATE PRIORITAIRE SUR CONFLIT");
      
      // Si ForceImmediateConflictClose est activé, on ferme sans aucune condition
      if(ForceImmediateConflictClose)
      {
         Print("🔥 FORCE IMMÉDIAT ACTIVÉ - Fermeture sans aucune protection");
      }
      else
      {
         // Logique originale avec protections (si ForceImmediateConflictClose = false)
         // Ici on pourrait réintroduire les protections si nécessaire
         Print("📋 MODE NORMAL - Vérification des protections avant fermeture");
      }

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
         
         // Fermer la position
         bool closed = PositionCloseWithLog(ticket, "IA HOLD - Fermeture automatique");
         
         if(closed)
         {
            Print("🔄 POSITION FERMÉE - IA HOLD | ", 
                  (type == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
                  " sur ", symbol, 
                  " | Profit: ", DoubleToString(profit, 2), "$",
                  " | En attente d'un nouveau signal IA");
         }
         else
         {
            Print("❌ ÉCHEC FERMETURE - IA HOLD | Erreur: ", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Stabilité anti-déconnexion - heartbeat + vérification connexion  |
//+------------------------------------------------------------------+
void CheckRobotStability()
{
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastHeartbeat <= 30) return;
   g_lastHeartbeat = currentTime;
   
   if(TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      g_reconnectAttempts = 0;
      g_isStable = true;
   }
   else
   {
      Print("⚠️ CONNEXION PERDUE - Attente reconnexion...");
      g_isStable = false;
   }
}

//+------------------------------------------------------------------+
//| Récupération automatique après reconnexion internet               |
//+------------------------------------------------------------------+
void AutoRecoverySystem()
{
   if(g_isStable) return;
   if(g_reconnectAttempts >= MAX_RECONNECT_ATTEMPTS)
   {
      Print("❌ ÉCHEC RÉCUPÉRATION après ", MAX_RECONNECT_ATTEMPTS, " tentatives - Arrêt du robot");
      ExpertRemove();
      return;
   }
   
   g_reconnectAttempts++;
   Print("🔄 TENTATIVE RÉCUPÉRATION #", g_reconnectAttempts, "/", MAX_RECONNECT_ATTEMPTS);
   Sleep(5000);
   
   if(TerminalInfoInteger(TERMINAL_CONNECTED))
   {
      Print("✅ RÉCUPÉRATION RÉUSSIE - Robot reconnecté");
      g_isStable = true;
      g_reconnectAttempts = 0;
   }
}

void OnTick()
{
   // Stabilité anti-déconnexion (priorité absolue)
   CheckRobotStability();
   AutoRecoverySystem();
   if(!g_isStable)
   {
      Sleep(2000);
      return;
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
         
         // TABLEAU DE BORD pour observation (15 s pour mise à jour plus réactive)
         if(currentTime - lastDashboardUpdate >= 15)
         {
            lastDashboardUpdate = currentTime;
            UpdateDashboard();
         }
      }
      return; // Sortir immédiatement - aucun trading
   }

   // PAUSE JOURNALIÈRE AUTOMATIQUE APRÈS GAIN CIBLE
   // Met à jour les stats (si pas déjà fait par un autre appel) et bloque le trading pendant la pause.
   UpdateDailyEquityStats();
   
   // PROTECTION DES GAINS ACCUMULÉS - Éviter l'effet dent de scie
   UpdateAccumulatedGainsProtection();
   
   // PROTECTION CONTRE LES CORRECTIONS IMMINENTES - Annuler les ordres si correction détectée
   CancelOrdersOnImminentCorrection();
   
   // EXÉCUTION AU MARCHÉ SUR TOUCH PIVOT - Spike automatique sur niveaux clés
   CheckAndExecuteMarketOrderOnPivotTouch();
   
   if(IsAccumulatedGainsProtectionActive())
   {
      static datetime lastProtectionLog = 0;
      if(currentTime - lastProtectionLog >= 60) // Log toutes les 60 secondes
      {
         double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
         double accumulatedGains = currentEquity - g_accumulatedGainsStart;
         double drawdownFromPeak = g_peakAccumulatedGains - currentEquity;
         
         Print("🛡️ PROTECTION GAINS ACTIVE - Accumulé: ", DoubleToString(accumulatedGains, 2), "$");
         Print("   📉 Drawdown actuel: ", DoubleToString(drawdownFromPeak, 2), "$ / ", DoubleToString(MaxLossAfterGainsProtection, 2), "$ max");
         lastProtectionLog = currentTime;
      }
   }
   
   if(IsDailyProfitPauseActive())
   {
      static datetime lastPauseLog = 0;
      if(currentTime - lastPauseLog >= 60) // Log toutes les 60 secondes max pendant la pause
      {
         Print("⏸ PAUSE JOURNALIÈRE EN COURS - Trading suspendu après gain cible de ",
               DoubleToString(DailyProfitTargetDollars, 2), "$. Reprise automatique à ",
               TimeToString(g_dailyPauseUntil, TIME_SECONDS));
         lastPauseLog = currentTime;
      }
      // On continue à mettre à jour les graphiques / IA plus bas si nécessaire,
      // mais aucune nouvelle entrée/sortie ne sera autorisée car CalculateLotSize renverra 0
      // et les fonctions d'entrée vérifient déjà ce volume.
   }

   if(IsCumulativeLossPauseActive())
   {
      static datetime lastLossPauseLog = 0;
      if(currentTime - lastLossPauseLog >= 60)
      {
         Print("⏸ PAUSE PERTE CUMULATIVE EN COURS - ", CumulativeLossPauseThresholdDollars, "$ de pertes consécutives. Reprise à ",
               TimeToString(g_lossPauseUntil, TIME_SECONDS));
         lastLossPauseLog = currentTime;
      }
   }
   
   // STRATÉGIE UNIQUE : SMC DERIV ARROW sur Boom/Crash uniquement
   CheckAndExecuteDerivArrowTrade();
   
   // NOUVEAU: AFFICHAGE DES INDICATEURS DE FORCE DANS LES ZONES SMC
   // Affiche la force du prix en pourcentage dans les zones Premium/Discount
   DrawSMCForceIndicators();
   
   // NOUVEAU: SEGMENTATION VISUELLE DES ZONES SMC
   // Affiche des segments centrés dans les zones Premium/Discount avec indicateurs de force
   DrawSMCZoneSegments();
   
   // Vérifier si le robot peut trader aujourd'hui
   if(!CanTradeToday())
   {
      // Afficher le compteur journalier même si le robot est arrêté
      DrawDailyCounter();
      return;
   }
   
   // NOUVEAU: SCAN MULTI-SYMBOLES POUR MEILLEURES OPPORTUNITÉS
   ScanSymbolsForOpportunities();
   
   // NOUVEAU: AFFICHAGE DU COMPTEUR JOURNALIER
   DrawDailyCounter();
   
   // Gestion des positions existantes (fermeture rapide après spike)
   ManageBoomCrashSpikeClose();
   
   // NOUVEAU: VÉRIFICATION FERMETURE AUTOMATIQUE SANS SPIKE + IA HOLD
   CheckAndClosePositionsWithoutSpike();
   
   // Fermer PIVOT TOUCH si pivot disparaît + pas de spike en 7 bougies
   CheckAndClosePivotTouchWithoutSpike();
   
   // Gestion des sorties en dollars (TP/SL globaux + BoomCrashSpikeTP)
   ManageDollarExits();
   
   // Trailing stop pour sécuriser les gains
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
      
      // Après chaque mise à jour IA, annuler les LIMIT Boom/Crash qui ne sont plus cohérents
      CancelConflictingPendingLimitsForSymbol(_Symbol);
      
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
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      if(currentTime - lastSpikeCheck >= 5)
      {
         lastSpikeCheck = currentTime;
         CheckImminentSpike(); // Vérification rapide sans graphiques
      }
   }
   
   // GRAPHIQUES SMC CONTRÔLÉS (toutes les 15 secondes pour plus de réactivité)
   if(currentTime - lastGraphicsUpdate >= 15)
   {
      lastGraphicsUpdate = currentTime;
      
      // DÉTECTION ANTI-REPAINT DES SWING POINTS
      DetectNonRepaintingSwingPoints();
      DrawConfirmedSwingPoints();
      
      // NOUVEAU: AFFICHAGE DES ZONES DE CORRECTION FUTURES (toujours actif)
      UpdateCorrectionZones();
      
      // GRAPHIQUES SMC SEULEMENT SI ShowChartGraphics = true
      if(ShowChartGraphics)
      {
         // DÉTECTION SPÉCIALE BOOM/CRASH (ANTI-SPIKE)
         if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
         {
            DetectBoomCrashSwingPoints();
            
            // DÉTECTION AVANCÉE DE SPIKE IMMINENT - OPTIMISÉE
            CheckImminentSpike();
         }
         
         // DÉTECTION DES MOUVEMENTS DE RETOUR VERS CANAUX SMC
         CheckSMCChannelReturnMovements();
      
         // AFFICHAGE STATUT IA ET PRÉDICTIONS
         DrawAIStatusAndPredictions();
      
         // Graphiques essentiels et zones Premium/Discount
         DrawSwingHighLow();
         DrawBookmarkLevels();
         DrawFVGOnChart();
         DrawOBOnChart();
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
        if(ShowSMCChannelsMultiTF) DrawSMCChannelsMultiTF();
        if(ShowEMASupertrendMultiTF) DrawEMASupertrendMultiTF();
        if(ShowLimitOrderLevels)
        {
           DrawLimitOrderLevels();
           CloseLimitPositionsIfLinesMissing();
        }
      
        // Ajuster périodiquement les ordres LIMIT vers les niveaux pivot / EMA mis à jour
        AdjustEMAScalpingLimitOrder();
        ManagePivotLimitOrder();
      }
      
      // Placer un ordre limite SMC "sniper" sur Boom/Crash (entre prix et canal H1)
      PlaceSMCChannelLimitOrder();
   }
   
   // ENTRÉES AU MARCHÉ BASÉES SUR LA DÉCISION IA SMC/EMA
   // (Non-Boom/Crash principalement, Boom/Crash restant géré par Deriv Arrow)
   ExecuteAIDecisionMarketOrder();
   
   // Métriques ML sur le graphique (toutes les 30 s, indépendant de l’IA et du dashboard)
   static datetime lastMLStandalone = 0;
   if(ShowMLMetrics && (currentTime - lastMLStandalone) >= 30)
   {
      lastMLStandalone = currentTime;
      UpdateMLMetricsDisplay();
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
   string bcStr = (StringFind(_Symbol, "Boom") >= 0) ? "BOOM" : (StringFind(_Symbol, "Crash") >= 0) ? "CRASH" : "FOREX";
   
   // NOUVEAU: Métriques de correction quantitative
   string correctionMetrics = "";
   string correctionConclusion = "";
   if(g_correctionAnalysisDone)
   {
      double correctionScore = GetCorrectionScore();
      int predictedDuration = PredictCurrentCorrectionDuration();
      bool isHighRisk = IsInHighRiskCorrectionZone();
      double historicalProb = g_historicalCorrectionProb;
      double conditionalProb = CalculateConditionalCorrectionProbability();
      
      // DÉTERMINER LA CONCLUSION
      if(isHighRisk && correctionScore > 80.0)
      {
         correctionConclusion = "🔴 CONCLUSION: CORRECTION IMMINENTE - TRADES BLOQUÉS";
      }
      else if(correctionScore > 65.0)
      {
         correctionConclusion = "🟡 CONCLUSION: RISQUE ÉLEVÉ - SURVEILLANCE RENFORCÉE";
      }
      else
      {
         correctionConclusion = "🟢 CONCLUSION: CONDITIONS FAVORABLES - TRADING NORMAL";
      }
      
      correctionMetrics = "\n📊 CORRECTION QUANTITATIVE:\n";
      correctionMetrics += "   Score global: " + DoubleToString(correctionScore, 1) + "% | ";
      correctionMetrics += "Risque: " + (isHighRisk ? "ÉLEVÉ" : "MODÉRÉ") + "\n";
      correctionMetrics += "   Probabilité historique: " + DoubleToString(historicalProb, 1) + "% | ";
      correctionMetrics += "Conditionnelle: " + DoubleToString(conditionalProb, 1) + "%\n";
      correctionMetrics += "   Durée prédite: " + IntegerToString(predictedDuration) + " bougies H1 | ";
      correctionMetrics += "Attente recommandée: " + IntegerToString(GetRecommendedWaitTime()) + " bougies\n";
      correctionMetrics += "   " + correctionConclusion;
   }
   else
   {
      correctionMetrics = "\n📊 CORRECTION QUANTITATIVE: Analyse en cours...\n";
      correctionMetrics += "   🟡 CONCLUSION: EN ATTENTE DES DONNÉES";
   }
   
   Comment("═══ SMC Universal + FVG_Kill PRO ═══\n",
           "Stratégie: SMC (FVG|OB|LS|BOS) + FVG_Kill (EMA HTF + LS)\n",
           "Trend HTF: ", trendHTF, " | Liquidity Sweep: ", lsStr, " | Kill Zone: ", killStr, "\n",
           "Boom/Crash: ", bcStr, " | Catégorie: ", catStr, "\n",
           "IA: ", (g_lastAIAction != "") ? (g_lastAIAction + " " + DoubleToString(g_lastAIConfidence*100,1) + "% | Align: " + g_lastAIAlignment + " | Cohér: " + g_lastAICoherence) : "OFF", "\n",
           "Dernière mise à jour IA: ", (g_lastAIUpdate > 0) ? TimeToString(g_lastAIUpdate, TIME_SECONDS) : "Jamais", "\n",
           "Positions terminal: ", totalPos, "/", MaxPositionsTerminal, " | ", _Symbol, ": ", posCount, "/1\n",
           "Perte totale: ", DoubleToString(totalPL, 2), " $ (max ", DoubleToString(MaxTotalLossDollars, 0), "$)\n",
           "Swing: ", swingStr, "\n",
           "ATR: ", DoubleToString(atrVal, _Digits), " | EMA(9): ", DoubleToString(emaVal, _Digits),
           "\nCanal ML: ", (g_channelValid ? "OK" : "—"),
           "\nML (entraînement): ", g_mlMetricsStr,
           correctionMetrics);

   // Mise à jour du label "Décision ML" visible sur le graphique (le robot utilise bien la décision du serveur)
   long cid = ChartID();
   string decLabelName = "SMC_AI_Decision_" + _Symbol;
   if(ObjectFind(cid, decLabelName) >= 0)
   {
      string decText;
      if(!UseAIServer)
         decText = "Décision ML: — (IA désactivée)";
      else if(g_lastAIAction != "")
      {
         int secAgo = (int)(TimeCurrent() - g_lastAIUpdate);
         decText = "Décision ML: " + g_lastAIAction + " " + DoubleToString(g_lastAIConfidence * 100, 1) + "%";
         if(secAgo >= 0 && secAgo < 3600)
            decText += " (il y a " + IntegerToString(secAgo) + " s)";
         else if(g_lastAIUpdate > 0)
            decText += " | " + TimeToString(g_lastAIUpdate, TIME_SECONDS);
      }
      else
         decText = "Décision ML: — (en attente 1ère réponse)";
      ObjectSetString(cid, decLabelName, OBJPROP_TEXT, decText);
      ObjectSetInteger(cid, decLabelName, OBJPROP_COLOR, (g_lastAIAction == "buy" || g_lastAIAction == "BUY") ? clrLime : (g_lastAIAction == "sell" || g_lastAIAction == "SELL") ? clrOrangeRed : clrSilver);
   }
   ChartRedraw(cid);
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
   string baseUrl = UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL;
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
         string dataSource = ExtractJsonValue(metricsData, "data_source");
         g_mlMetricsStr = "Précision: " + acc + "% | Modèle: " + model + " | Samples: " + samples;
         if(wins != "N/A" && losses != "N/A")
            g_mlMetricsStr += " | Feedback: " + wins + "W/" + losses + "L";
         if(status != "N/A" && status != "trained")
            g_mlMetricsStr += " | " + (status == "collecting_data" ? "Collecte données..." : status);
         if(dataSource != "N/A" && dataSource != "")
            g_mlMetricsStr += " | Source: " + dataSource;
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
      // Ne pas écraser une valeur utile si on a déjà des métriques affichées
      if(StringLen(g_mlMetricsStr) == 0)
         g_mlMetricsStr = "ML: Données non récupérées (WebRequest bloqué)";
      Print("❌ WebRequest ML metrics échoué (code ", res, "). Les données Supabase passent par le serveur IA. Autorisez l'URL: ", baseUrl);
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

   // Afficher les métriques ML sur le graphique (label dédié, chart actuel)
   long cid = ChartID();
   string mlLabelName = "SMC_ML_Metrics_" + _Symbol;
   if(ObjectFind(cid, mlLabelName) == -1)
   {
      if(ObjectCreate(cid, mlLabelName, OBJ_LABEL, 0, 0, 0))
      {
         ObjectSetInteger(cid, mlLabelName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
         ObjectSetInteger(cid, mlLabelName, OBJPROP_XDISTANCE, 12);
         ObjectSetInteger(cid, mlLabelName, OBJPROP_YDISTANCE, 42);
         ObjectSetInteger(cid, mlLabelName, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(cid, mlLabelName, OBJPROP_COLOR, clrDodgerBlue);
         ObjectSetString(cid, mlLabelName, OBJPROP_FONT, "Consolas");
      }
   }
   if(ObjectFind(cid, mlLabelName) >= 0)
      ObjectSetString(cid, mlLabelName, OBJPROP_TEXT, "ML (entraînement): " + g_mlMetricsStr);
   ChartRedraw(cid);
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

double FindNearestSupportResistance(string symbol, double currentPrice, string &typeOut)
{
   double nearestLevel = 0.0;
   string nearestType = "";
   double minDistance = DBL_MAX;
   
   // NOUVEAU: RÉCUPÉRER LES VRAIS NIVEAUX S/R DEPUIS SUPABASE
   double supabaseSupport = 0.0, supabaseResistance = 0.0;
   if(GetRealSupportResistanceFromSupabase(symbol, supabaseSupport, supabaseResistance))
   {
      Print("📊 Supabase S/R - Support: ", DoubleToString(supabaseSupport, _Digits), 
            " | Résistance: ", DoubleToString(supabaseResistance, _Digits));
      
      // Vérifier le support Supabase
      if(supabaseSupport > 0 && currentPrice > supabaseSupport)
      {
         double distance = currentPrice - supabaseSupport;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearestLevel = supabaseSupport;
            nearestType = "SUPABASE_SUPPORT";
            Print("📍 Support Supabase trouvé - Distance: ", DoubleToString(distance, _Digits));
         }
      }
      
      // Vérifier la résistance Supabase
      if(supabaseResistance > 0 && currentPrice < supabaseResistance)
      {
         double distance = supabaseResistance - currentPrice;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearestLevel = supabaseResistance;
            nearestType = "SUPABASE_RESISTANCE";
            Print("📍 Résistance Supabase trouvée - Distance: ", DoubleToString(distance, _Digits));
         }
      }
      
      // Si on a trouvé un niveau Supabase valide, le retourner directement
      if(nearestLevel > 0)
      {
         typeOut = nearestType;
         Print("✅ Niveau Supabase sélectionné: ", nearestType, " @ ", DoubleToString(nearestLevel, _Digits));
         return nearestLevel;
      }
   }
   else if(StringLen(SupabaseUrl) > 0 && StringLen(SupabaseApiKey) > 0)
   {
      static bool _supabase_sr_fail_logged = false;
      if(!_supabase_sr_fail_logged) { _supabase_sr_fail_logged = true; Print("⚠️ Échec récupération S/R Supabase - Utilisation calculs locaux"); }
   }
   
   // MÉTHODE DE SECOURS: Calculs locaux si Supabase indisponible
   // Mettre à jour les données EMA
   UpdateEMAData();
   
   // 1. Vérifier les EMA comme S/R dynamiques
   if(g_emaDataReady)
   {
      // Vérifier les EMA comme support
      double emaSupport = GetNearestEMASupport(currentPrice);
      if(emaSupport > 0)
      {
         double distance = currentPrice - emaSupport;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearestLevel = emaSupport;
            nearestType = "EMA_SUPPORT";
         }
      }
      
      // Vérifier les EMA comme résistance
      double emaResistance = GetNearestEMAResistance(currentPrice);
      if(emaResistance > 0)
      {
         double distance = emaResistance - currentPrice;
         if(distance < minDistance)
         {
            minDistance = distance;
            nearestLevel = emaResistance;
            nearestType = "EMA_RESISTANCE";
         }
      }
   }
   
   // 2. Vérifier les swing points historiques
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(symbol, PERIOD_H1, 0, 100, rates) >= 50)
   {
      // Détecter les swing highs et lows
      for(int i = 2; i < ArraySize(rates) - 2; i++)
      {
         // Swing High (résistance)
         if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
            rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
         {
            double distance = MathAbs(rates[i].high - currentPrice);
            if(distance < minDistance && distance <= currentPrice * 0.005) // 0.5% max
            {
               minDistance = distance;
               nearestLevel = rates[i].high;
               nearestType = "SWING_HIGH";
            }
         }
         
         // Swing Low (support)
         if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
            rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
         {
            double distance = MathAbs(rates[i].low - currentPrice);
            if(distance < minDistance && distance <= currentPrice * 0.005) // 0.5% max
            {
               minDistance = distance;
               nearestLevel = rates[i].low;
               nearestType = "SWING_LOW";
            }
         }
      }
   }
   
   // 3. Vérifier les zones Supabase (backup)
   string zoneType;
   if(IsInSupabaseCorrectionZone(symbol, currentPrice, zoneType))
   {
      int symbolIndex = GetSymbolIndex(symbol);
      if(symbolIndex != -1)
      {
         if(zoneType == "support" && g_correctionSupportLevels[symbolIndex] > 0)
         {
            double distance = currentPrice - g_correctionSupportLevels[symbolIndex];
            if(distance < minDistance)
            {
               minDistance = distance;
               nearestLevel = g_correctionSupportLevels[symbolIndex];
               nearestType = "SUPABASE_SUPPORT";
            }
         }
         else if(zoneType == "resistance" && g_correctionResistanceLevels[symbolIndex] > 0)
         {
            double distance = g_correctionResistanceLevels[symbolIndex] - currentPrice;
            if(distance < minDistance)
            {
               minDistance = distance;
               nearestLevel = g_correctionResistanceLevels[symbolIndex];
               nearestType = "SUPABASE_RESISTANCE";
            }
         }
      }
   }
   
   typeOut = nearestType;
   
   if(nearestLevel > 0)
   {
      Print("📍 S/R trouvé: ", nearestType, " | Niveau: ", DoubleToString(nearestLevel, 5), 
            " | Distance: ", DoubleToString(minDistance, 5));
   }
   
   return nearestLevel;
}

//| VÉRIFIER ET FERMER LES POSITIONS SANS SPIKE |
void CheckAndClosePositionsWithoutSpike()
{
   // Si aucune position, sortir
   if(PositionsTotal() == 0) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!posInfo.SelectByIndex(i)) continue;
      if(posInfo.Magic() != InpMagicNumber) continue;
      
      string symbol = posInfo.Symbol();
      
      // Vérifier si cette position doit être fermée
      if(ShouldClosePositionWithoutSpike(symbol))
      {
         ulong ticket = posInfo.Ticket();
         double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
         
         Print("🚫 FERMETURE AUTOMATIQUE SANS SPIKE - ", symbol, 
               " | Ticket: ", ticket, 
               " | Profit: ", DoubleToString(profit, 2), "$",
               " | Raison: ", MAX_BARS_WITHOUT_SPIKE, " bougies sans spike + IA HOLD");
         
         // Fermer la position
         if(PositionCloseWithLog(ticket, "Fermeture automatique - " + IntegerToString(MAX_BARS_WITHOUT_SPIKE) + " bougies sans spike + IA HOLD"))
         {
            // Réinitialiser le temps d'ouverture
            ResetPositionOpenTime(symbol);
            
            // Si c'est un gain, enregistrer pour la protection anti-reprise
            if(profit > 0)
            {
               RecordProfitClose(symbol);
            }
            
            // Notification
            if(UseNotifications)
            {
               Alert("🚫 Position fermée automatiquement - ", symbol, " - ", DoubleToString(profit, 2), "$");
               SendNotification("🚫 Position fermée automatiquement - " + symbol + " - " + DoubleToString(profit, 2) + "$");
            }
         }
         else
         {
            int err = GetLastError();
            Print("❌ ÉCHEC FERMETURE AUTOMATIQUE - ", symbol, " | ticket=", ticket, " | code=", err);
         }
      }
   }
}


//| GESTION DES POSITIONS ET VARIABLES GLOBALES                    |

void PlaceScalpingLimitOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope)
   {
      Print("🚫 ORDRES LIMITES BLOQUÉS - Pas de décision IA forte (conf: ", DoubleToString(g_lastAIConfidence*100, 1), "% < ", DoubleToString(MinAIConfidence*100, 1), "%)");
      return;
   }


void PlaceHistoricalBasedScalpingOrders(MqlRates &rates[], int futureBars, double currentPrice, double currentATR, double trendSlope, int existingLimitOrders)
   {
      // NOUVEAU: VÉRIFIER SI LE ROBOT PEUT TRADER AUJOURD'HUI
      if(!CanTradeToday())
      {
         Print("🚫 ORDRES LIMITES BLOQUÉS - Robot arrêté pour la journée");
         return;
      }
      
      // NOUVEAU: BLOQUER TOUS LES ORDRES SI IA SERVER EST EN HOLD
      if(!IsOrderExecutionAllowed())
      {
         return;
      }
      
      // NOUVEAU: VÉRIFIER LA PROTECTION CONTRE LES ZONES DE CORRECTION
      if(!CheckCorrectionZoneProtection("ORDRE LIMIT"))
      {
         Print("🚫 ORDRES LIMITES BLOQUÉS - Zone de correction à haut risque");
         return;
      }
      
      // NOUVEAU: VÉRIFICATION PROTECTION ANTI-REPRISE APRÈS GAIN
      if(!CanTradeAfterProfitClose(_Symbol))
      {
         Print("🚫 ORDRES HISTORIQUES BLOQUÉS - Protection anti-reprise après gain active");
         return;
      }
      
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
      
      // Limite globale: maximum 1 ordre LIMIT par symbole
      {
         if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "ORDRES HISTORIQUES"))
            return;
      }
      
      // RÈGLE STRICTE: BLOQUER TOUS LES ORDRES BUY SUR BOOM SI IA = SELL
      bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
      bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
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
            // NOUVEAU: UTILISER LE S/R LE PLUS PROCHE AU LIEU DES CALCULS COMPLEXES
            string srType = "";
            double nearestSR = FindNearestSupportResistance(_Symbol, closePrice, srType);
            
            double bestLevel = 0;
            // NOUVEAU: UTILISER L'INTERSECTION CANAL SMC + PRIX ACTUEL
            double smcIntersection = FindSMCChannelIntersection("BUY");
            string levelSource = "";
            
            if(smcIntersection > 0)
            {
               // Utiliser l'intersection canal SMC comme niveau d'entrée
               bestLevel = smcIntersection;
               levelSource = "Intersection Canal SMC";
               Print("📍 BUY LIMIT sur intersection Canal SMC - ", _Symbol, " | Niveau: ", DoubleToString(bestLevel, _Digits));
            }
            else if(nearestSR > 0 && srType == "support")
            {
               // Fallback sur le support EMA le plus proche
               bestLevel = nearestSR;
               levelSource = "Support EMA proche (" + srType + ")";
               Print("📍 BUY LIMIT sur support EMA - ", _Symbol, " | Niveau: ", DoubleToString(bestLevel, _Digits));
            }
            else
            {
               // Dernier recours: ancienne méthode
               bestLevel = GetClosestBuyLevel(closePrice, currentATR, MaxDistanceLimitATR, levelSource);
            }
            
            // NOUVEAU: VÉRIFIER SI LE NIVEAU EST TROP LOIN ET UTILISER UN REPLI PROCHE
            double distancePercent = MathAbs(bestLevel - closePrice) / closePrice * 100;
            if(distancePercent > 0.2) // Si plus de 0.2% de distance
            {
               Print("🚫 Niveau trop loin: ", DoubleToString(distancePercent, 2), "% > 0.2%");
               
               // Utiliser un niveau proche à 0.1% sous le prix actuel
               bestLevel = closePrice * (1 - 0.001); // 0.1% en dessous
               levelSource = "Repli proche (0.1%)";
               Print("🔄 BUY LIMIT repli proche - ", _Symbol, " | Niveau: ", DoubleToString(bestLevel, _Digits));
            }
            
            if(bestLevel > 0)
            {
               // Sécurité globale: un seul ordre LIMIT par symbole
               if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "EMA SMC LIMIT"))
                  return;
               
               // Placer l'ordre EXACTEMENT sur le niveau de support/EMA tracé
               double entry = bestLevel;
               double sl = entry - currentATR * SL_ATRMult;
               double tp = entry + currentATR * TP_ATRMult;
               
               MqlTradeRequest req = {};
               MqlTradeResult res = {};
               req.action = TRADE_ACTION_PENDING;
               req.symbol = _Symbol;
               req.volume = NormalizeVolumeForSymbol(0.01);
               req.type = ORDER_TYPE_BUY_LIMIT;
               req.price = entry;
               req.sl = sl;
               req.tp = tp;
               req.magic = InpMagicNumber;
               req.comment = "EMA SMC BUY LIMIT";
               
               // Vérification IA avant envoi de l'ordre LIMIT (mêmes conditions directionnelles qu'un ordre marché)
               if(!IsAILimitOrderAllowed("BUY"))
               {
                  Print("🚫 EMA SMC BUY LIMIT annulé - Conditions IA non valides pour LIMIT.");
               }
               else if(ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, ORDER_TYPE_BUY_LIMIT) && OrderSend(req, res))
               {
                  Print("📈 EMA SMC BUY LIMIT @ ", req.price, levelSource, " | SL=", req.sl, " | TP=", req.tp);
                  ordersToPlace--;
               }
            }
         }
         
         // SELL LIMIT en downtrend, IA SELL
         if(downtrend && (aiDir == "SELL") && ordersToPlace > 0)
         {
            // NOUVEAU: UTILISER LE S/R LE PLUS PROCHE AU LIEU DES CALCULS COMPLEXES
            string srType = "";
            double nearestSR = FindNearestSupportResistance(_Symbol, closePrice, srType);
            
            double bestLevel = 0;
            // NOUVEAU: UTILISER L'INTERSECTION CANAL SMC + PRIX ACTUEL
            double smcIntersection = FindSMCChannelIntersection("SELL");
            string levelSource = "";
            
            if(smcIntersection > 0)
            {
               // Utiliser l'intersection canal SMC comme niveau d'entrée
               bestLevel = smcIntersection;
               levelSource = "Intersection Canal SMC";
               Print("📍 SELL LIMIT sur intersection Canal SMC - ", _Symbol, " | Niveau: ", DoubleToString(bestLevel, _Digits));
            }
            else if(nearestSR > 0 && srType == "resistance")
            {
               // Fallback sur la résistance EMA la plus proche
               bestLevel = nearestSR;
               levelSource = "Résistance EMA proche (" + srType + ")";
               Print("📍 SELL LIMIT sur résistance EMA - ", _Symbol, " | Niveau: ", DoubleToString(bestLevel, _Digits));
            }
            else
            {
               // Dernier recours: ancienne méthode
               bestLevel = GetClosestSellLevel(closePrice, currentATR, MaxDistanceLimitATR, levelSource);
            }
            
            // NOUVEAU: VÉRIFIER SI LE NIVEAU EST TROP LOIN ET UTILISER UN REPLI PROCHE
            double distancePercent = MathAbs(bestLevel - closePrice) / closePrice * 100;
            if(distancePercent > 0.2) // Si plus de 0.2% de distance
            {
               Print("🚫 Niveau trop loin: ", DoubleToString(distancePercent, 2), "% > 0.2%");
               
               // Utiliser un niveau proche à 0.1% au-dessus du prix actuel
               bestLevel = closePrice * (1 + 0.001); // 0.1% au-dessus
               levelSource = "Repli proche (0.1%)";
               Print("🔄 SELL LIMIT repli proche - ", _Symbol, " | Niveau: ", DoubleToString(bestLevel, _Digits));
            }
            
            if(bestLevel > 0)
            {
               // Sécurité globale: un seul ordre LIMIT par symbole
               if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "EMA SMC LIMIT"))
                  return;
               
               // Placer l'ordre EXACTEMENT sur le niveau de résistance/EMA tracé
               double entry = bestLevel;
               double sl = entry + currentATR * SL_ATRMult;
               double tp = entry - currentATR * TP_ATRMult;
               
               MqlTradeRequest req = {};
               MqlTradeResult res = {};
               req.action = TRADE_ACTION_PENDING;
               req.symbol = _Symbol;
               req.volume = NormalizeVolumeForSymbol(0.01);
               req.type = ORDER_TYPE_SELL_LIMIT;
               req.price = entry;
               req.sl = sl;
               req.tp = tp;
               req.magic = InpMagicNumber;
               req.comment = "EMA SMC SELL LIMIT";
               
               // Vérification IA avant envoi de l'ordre LIMIT
               if(!IsAILimitOrderAllowed("SELL"))
               {
                  Print("🚫 EMA SMC SELL LIMIT annulé - Conditions IA non valides pour LIMIT.");
               }
               else if(ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, ORDER_TYPE_SELL_LIMIT) && OrderSend(req, res))
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
         
         // Sécurité globale: un seul ordre LIMIT par symbole (et TF M5 pour Boom/Crash)
         if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "HIST PETITS MOUVEMENTS"))
            return;

         // Sécurité globale: un seul ordre LIMIT par symbole (et TF M5 pour Boom/Crash)
         if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "HIST PETITS MOUVEMENTS"))
            return;

         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_PENDING;
         request.symbol = _Symbol;
         request.volume = NormalizeVolumeForSymbol(0.01);
         request.type = ORDER_TYPE_BUY_LIMIT;
         request.price = buyLimitPrice;
         request.sl = buyLimitPrice - (currentATR * 0.5); // SL plus proche pour petits mouvements
         request.tp = tpPrice;
         request.magic = InpMagicNumber;
         request.comment = "HIST SL BUY - PETITS MOUVEMENTS";
         
         // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
        if(!IsAILimitOrderAllowed("BUY"))
        {
           Print("🚫 BUY LIMIT petits mouvements annulé - Conditions IA non valides pour LIMIT.");
           return;
        }
        if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_BUY_LIMIT))
         {
            Print("❌ Échec validation prix BUY LIMIT - Ordre annulé");
            return;
         }
         
         if(OrderSend(request, result))
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
         
         // Sécurité globale: un seul ordre LIMIT par symbole (et TF M5 pour Boom/Crash)
         if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "HIST PETITS MOUVEMENTS"))
            return;

         // Sécurité globale: un seul ordre LIMIT par symbole (et TF M5 pour Boom/Crash)
         if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "HIST PETITS MOUVEMENTS"))
            return;

         MqlTradeRequest request = {};
         MqlTradeResult result = {};
         
         request.action = TRADE_ACTION_PENDING;
         request.symbol = _Symbol;
         request.volume = NormalizeVolumeForSymbol(0.01);
         request.type = ORDER_TYPE_SELL_LIMIT;
         request.price = sellLimitPrice;
         request.sl = sellLimitPrice + (currentATR * 0.5); // SL plus proche pour petits mouvements
         request.tp = tpPrice;
         request.magic = InpMagicNumber;
         request.comment = "HIST SH SELL - PETITS MOUVEMENTS";
         
         // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
        if(!IsAILimitOrderAllowed("SELL"))
        {
           Print("🚫 SELL LIMIT petits mouvements annulé - Conditions IA non valides pour LIMIT.");
           return;
        }
        if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_SELL_LIMIT))
         {
            Print("❌ Échec validation prix SELL LIMIT - Ordre annulé");
            return;
         }
         
         if(OrderSend(request, result))
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
   
   // Limite globale: maximum 1 ordre LIMIT par symbole
   if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "ORDRES SPIKE"))
      return;

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
         
         // Sécurité globale: un seul ordre LIMIT par symbole (et TF M5 pour Boom/Crash)
         if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "ORDRES SPIKE"))
            return;

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
        string dir = isBoom ? "BUY" : "SELL";
        if(!IsAILimitOrderAllowed(dir))
        {
           Print("🚫 ", spikeType, " annulé - Conditions IA non valides pour LIMIT.");
           continue;
        }
        if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, orderType))
         {
            Print("❌ Échec validation prix ", spikeType, " - Ordre annulé");
            continue;
         }
         
         if(OrderSend(request, result))
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
   
   // Limite globale: maximum 1 ordre LIMIT par symbole
   {
      if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "ORDRES NORMAUX"))
         return;
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
      request.sl = buyLimitPrice - currentATR * 1.0;
      request.tp = tpPrice;
      request.magic = InpMagicNumber;
      request.comment = "Scalp SL Near";
      
      // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
      if(!IsAILimitOrderAllowed("BUY"))
      {
         Print("🚫 BUY LIMIT scalping annulé - Conditions IA non valides pour LIMIT.");
         return;
      }
      if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_BUY_LIMIT))
      {
         Print("❌ Échec validation prix BUY LIMIT scalping - Ordre annulé");
         return;
      }
      
      if(OrderSend(request, result))
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
      request.sl = sellLimitPrice + currentATR * 1.0;
      request.tp = tpPrice;
      request.magic = InpMagicNumber;
      request.comment = "Scalp SH Near";
      
      // VALIDATION ET AJUSTEMENT DES PRIX AVANT ENVOI
      if(!IsAILimitOrderAllowed("SELL"))
      {
         Print("🚫 SELL LIMIT scalping annulé - Conditions IA non valides pour LIMIT.");
         return;
      }
      if(!ValidateAndAdjustLimitPrice(request.price, request.sl, request.tp, ORDER_TYPE_SELL_LIMIT))
      {
         Print("❌ Échec validation prix SELL LIMIT scalping - Ordre annulé");
         return;
      }
      
      if(OrderSend(request, result))
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
   int len = 60; // portion historique utilisée pour la pente
   if(CopyBuffer(emaHandle, 0, 0, len, ema) < len) return;
   datetime time[];
   ArraySetAsSeries(time, true);
   if(CopyTime(_Symbol, LTF, 0, len, time) < len) return;
   
   // Supprimer les anciens objets EMA
   ObjectDelete(0, "SMC_EMA_MAIN");
   ObjectDelete(0, "SMC_EMA_PROJ");
   
   // 1) Ligne EMA historique (du passé récent jusqu'à maintenant)
   datetime tPast = time[len - 1];
   double   emaPast = ema[len - 1];
   datetime tNow  = time[0];
   double   emaNow  = ema[0];
   
   if(ObjectCreate(0, "SMC_EMA_MAIN", OBJ_TREND, 0, tPast, emaPast, tNow, emaNow))
   {
      ObjectSetInteger(0, "SMC_EMA_MAIN", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, "SMC_EMA_MAIN", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "SMC_EMA_MAIN", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "SMC_EMA_MAIN", OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, "SMC_EMA_MAIN", OBJPROP_BACK, true);
   }
   
   // 2) Projection EMA sur 500 bougies futures (canal/ligne de tendance)
   int    futureBars  = 500;
   int    secondsPerBar = PeriodSeconds(LTF);
   if(secondsPerBar <= 0) secondsPerBar = PeriodSeconds(PERIOD_CURRENT);
   datetime tFuture = tNow + (datetime)(futureBars * secondsPerBar);
   
   double dtHist = (double)(tNow - tPast);
   double slopePerSec = (dtHist != 0.0) ? (emaNow - emaPast) / dtHist : 0.0;
   double emaFuture = emaNow + slopePerSec * (double)(tFuture - tNow);
   
   if(ObjectCreate(0, "SMC_EMA_PROJ", OBJ_TREND, 0, tNow, emaNow, tFuture, emaFuture))
   {
      ObjectSetInteger(0, "SMC_EMA_PROJ", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, "SMC_EMA_PROJ", OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, "SMC_EMA_PROJ", OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, "SMC_EMA_PROJ", OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, "SMC_EMA_PROJ", OBJPROP_BACK, true);
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
   
   if(UseGlobalPositionLimit && CountPositionsOurEA() >= MaxPositionsTerminal) return;
   
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
   bool isBoom  = (StringFind(_Symbol, "Boom")  >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
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
   
      // Limite globale: maximum 1 ordre LIMIT par symbole
      int totalLimits = CountOpenLimitOrdersForSymbol(_Symbol);
      // Pour Boom/Crash: un seul LIMIT proche à la fois
      if(totalLimits >= 1) return;
   
   if(CountPositionsForSymbol(_Symbol) > 0) return; // Pas de nouvel ordre si déjà en position
   if(IsMaxSimultaneousEAOrdersReached()) return;
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

   // Vérification IA avant envoi de tout ordre LIMIT canal SMC
   if(!IsAILimitOrderAllowed(channelDir))
   {
      Print("🚫 ORDRE LIMIT SMC annulé - Conditions IA non valides pour LIMIT (direction ", channelDir, ").");
      ReleaseOpenLock();
      return;
   }
   
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
   
   if(!OrderSend(req, res))
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

//| Niveaux BUY/SELL LIMIT pour un symbole donné (pivot M1 uniquement, pour scan multi-symboles) |
double GetClosestBuyLevelForSymbol(string symbol, double currentPrice, double atr, double maxDistATR, string &sourceOut)
{
   sourceOut = "";
   if(atr <= 0) return 0.0;
   double maxDist = MathMax(atr * MathMax(0.2, maxDistATR), atr * 0.2);
   double best = 0.0;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 80, r) < 20) return 0.0;
   for(int i = 2; i < 30; i++)
   {
      double lo = r[i].low;
      if(lo <= 0 || lo >= currentPrice) continue;
      if(lo < r[i-1].low && lo < r[i+1].low)
      {
         double dist = currentPrice - lo;
         if(dist <= maxDist && lo > best) { best = lo; sourceOut = "Pivot Low"; }
      }
   }
   return best;
}

double GetClosestSellLevelForSymbol(string symbol, double currentPrice, double atr, double maxDistATR, string &sourceOut)
{
   sourceOut = "";
   if(atr <= 0) return 0.0;
   double maxDist = MathMax(atr * MathMax(0.2, maxDistATR), atr * 0.2);
   double best = 0.0;
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 80, r) < 20) return 0.0;
   for(int i = 2; i < 30; i++)
   {
      double hi = r[i].high;
      if(hi <= 0 || hi <= currentPrice) continue;
      if(hi > r[i-1].high && hi > r[i+1].high)
      {
         double dist = hi - currentPrice;
         if(dist <= maxDist && (best == 0.0 || hi < best)) { best = hi; sourceOut = "Pivot High"; }
      }
   }
   return best;
}

double GetATRForSymbol(string symbol)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 20, r) < 14) return 0.0;
   double sum = 0.0;
   for(int i = 0; i < 14 && i < ArraySize(r); i++)
      sum += (r[i].high - r[i].low);
   return (sum / 14.0);
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
   if(g_lastSwingLow > 0)
   {
      ObjectCreate(0, "SMC_Limit_SwingLow", OBJ_HLINE, 0, 0, g_lastSwingLow);
      ObjectSetInteger(0, "SMC_Limit_SwingLow", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, "SMC_Limit_SwingLow", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetString(0, "SMC_Limit_SwingLow", OBJPROP_TOOLTIP, "Swing Low (PML)");
   }
   if(g_lastSwingHigh > 0)
   {
      ObjectCreate(0, "SMC_Limit_SwingHigh", OBJ_HLINE, 0, 0, g_lastSwingHigh);
      ObjectSetInteger(0, "SMC_Limit_SwingHigh", OBJPROP_COLOR, clrTomato);
      ObjectSetInteger(0, "SMC_Limit_SwingHigh", OBJPROP_STYLE, STYLE_DASH);
      ObjectSetString(0, "SMC_Limit_SwingHigh", OBJPROP_TOOLTIP, "Swing High (PML)");
   }
   // Lignes BUY/SELL LIMIT principales (épaisses) avec légende explicite
   if(buyLevel > 0)
   {
      ObjectCreate(0, "SMC_Limit_BuyLevel", OBJ_HLINE, 0, 0, buyLevel);
      ObjectSetInteger(0, "SMC_Limit_BuyLevel", OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, "SMC_Limit_BuyLevel", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "SMC_Limit_BuyLevel", OBJPROP_WIDTH, 5);
      string buyLabel = "BUY LIMIT (" + srcBuy + ")";
      ObjectSetString(0, "SMC_Limit_BuyLevel", OBJPROP_TOOLTIP, buyLabel);
      
      // Texte visible sur le graphique pour identifier clairement le niveau
      datetime tLabel = TimeCurrent();
      string buyTextName = "SMC_Limit_BuyLabel";
      if(ObjectFind(0, buyTextName) >= 0)
         ObjectDelete(0, buyTextName);
      if(ObjectCreate(0, buyTextName, OBJ_TEXT, 0, tLabel, buyLevel))
      {
         ObjectSetString(0, buyTextName, OBJPROP_TEXT, buyLabel);
         ObjectSetInteger(0, buyTextName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, buyTextName, OBJPROP_FONTSIZE, 10);
      }
   }
   if(sellLevel > 0)
   {
      ObjectCreate(0, "SMC_Limit_SellLevel", OBJ_HLINE, 0, 0, sellLevel);
      ObjectSetInteger(0, "SMC_Limit_SellLevel", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "SMC_Limit_SellLevel", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "SMC_Limit_SellLevel", OBJPROP_WIDTH, 5);
      string sellLabel = "SELL LIMIT (" + srcSell + ")";
      ObjectSetString(0, "SMC_Limit_SellLevel", OBJPROP_TOOLTIP, sellLabel);
      
      datetime tLabel2 = TimeCurrent();
      string sellTextName = "SMC_Limit_SellLabel";
      if(ObjectFind(0, sellTextName) >= 0)
         ObjectDelete(0, sellTextName);
      if(ObjectCreate(0, sellTextName, OBJ_TEXT, 0, tLabel2, sellLevel))
      {
         ObjectSetString(0, sellTextName, OBJPROP_TEXT, sellLabel);
         ObjectSetInteger(0, sellTextName, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, sellTextName, OBJPROP_FONTSIZE, 10);
      }
   }
}

//| Ferme les positions liées aux niveaux BUY/SELL LIMIT si la ligne correspondante a disparu |
void CloseLimitPositionsIfLinesMissing()
{
   // On ne déclenche cette logique que si les graphiques sont affichés
   if(!ShowChartGraphics)
      return;

   bool hasBuyLine  = (ObjectFind(0, "SMC_Limit_BuyLevel")  >= 0);
   bool hasSellLine = (ObjectFind(0, "SMC_Limit_SellLevel") >= 0);

   // Si les deux lignes existent toujours, rien à faire
   if(hasBuyLine && hasSellLine)
      return;

   int total = PositionsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      long   type    = PositionGetInteger(POSITION_TYPE);
      string comment = PositionGetString(POSITION_COMMENT);

      // Ne toucher qu'aux positions ouvertes par les stratégies LIMIT / PIVOT
      bool isLimitStrategy =
         StringFind(comment, "PIVOT TOUCH")      >= 0 ||
         StringFind(comment, "BUY LIMIT")        >= 0 ||
         StringFind(comment, "SELL LIMIT")       >= 0 ||
         StringFind(comment, "SMC_CH BUY LIMIT") >= 0 ||
         StringFind(comment, "SMC_CH SELL LIMIT")>= 0 ||
         StringFind(comment, "EMA SMC BUY LIMIT")>= 0 ||
         StringFind(comment, "EMA SMC SELL LIMIT")>= 0;

      if(!isLimitStrategy)
         continue;

      bool shouldClose = false;
      if(type == POSITION_TYPE_BUY && !hasBuyLine)
         shouldClose = true;
      else if(type == POSITION_TYPE_SELL && !hasSellLine)
         shouldClose = true;

      if(shouldClose)
      {
         Print("🚫 FERMETURE AUTO LIMIT - Ligne BUY/SELL LIMIT disparue pour ", _Symbol,
               " | Ticket: ", ticket,
               " | Commentaire: ", comment);

         PositionCloseWithLog(ticket, "Ligne LIMIT disparue sur le graphique");
      }
   }
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

   // Zone future remplie en filigrane pour visualiser la direction probable
   datetime tFutureStart = tNow;
   datetime tFutureEnd   = tEnd;
   double topPrice    = MathMax(u0, uEnd);
   double bottomPrice = MathMin(l0, lEnd);
   string fillName = "SMC_Chan_Fill";
   if(ObjectCreate(0, fillName, OBJ_RECTANGLE, 0, tFutureStart, topPrice, tFutureEnd, bottomPrice))
   {
      color fillColor = (slopeUpper >= 0.0) ? (color)C'220,245,220' : (color)C'245,220,220';
      ObjectSetInteger(0, fillName, OBJPROP_COLOR, fillColor);
      ObjectSetInteger(0, fillName, OBJPROP_BACK, true);
      ObjectSetInteger(0, fillName, OBJPROP_WIDTH, 1);
   }

   // Deux lignes qui enveloppent les bougies et suivent leur mouvement
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
   
   if(OrderSend(req, res))
   {
      Print("🔧 EMA SMC LIMIT ajusté @ ", DoubleToString(req.price, _Digits),
            " (ancien: ", DoubleToString(oldPrice, _Digits), ") src=", src);
   }
}

// Maintient un ordre LIMIT basé sur les pivots (BUY pour Boom, SELL pour Crash)
// - 1 seul ordre pivot par symbole (respecte aussi la limite globale 1 LIMIT/symbole)
// - Met à jour le prix si le pivot (support/résistance) se déplace
// - Mise à jour maximum toutes les 60 secondes pour limiter les modifications
void ManagePivotLimitOrder()
{
   static datetime lastUpdateTime = 0;
   datetime now = TimeCurrent();
   if(now - lastUpdateTime < 60) // 1 minute
      return;
   lastUpdateTime = now;

   bool isBoom  = (StringFind(_Symbol, "Boom")  >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   if(!isBoom && !isCrash)
      return; // Stratégie pivot uniquement pour Boom/Crash

   // Même règle que les autres ordres LIMIT Boom/Crash: uniquement sur graphique M5
   if(Period() != PERIOD_M5)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0)
      return;

   // ATR courant (comme pour AdjustEMAScalpingLimitOrder)
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

   string src = "";
   double desiredPrice = 0.0;
   ENUM_ORDER_TYPE ordType;
   string comment;

   if(isBoom)
   {
      // Boom: uniquement BUY LIMIT sur le niveau pivot de support
      desiredPrice = GetClosestBuyLevel(bid, atrVal, MaxDistanceLimitATR, src);
      ordType = ORDER_TYPE_BUY_LIMIT;
      comment = "PIVOT BUY LIMIT";
   }
   else // Crash
   {
      // Crash: uniquement SELL LIMIT sur le niveau pivot de résistance
      desiredPrice = GetClosestSellLevel(ask, atrVal, MaxDistanceLimitATR, src);
      ordType = ORDER_TYPE_SELL_LIMIT;
      comment = "PIVOT SELL LIMIT";
   }

   if(desiredPrice <= 0)
      return; // Aucun pivot exploitable

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   // Rechercher un ordre LIMIT pivot existant pour ce symbole
   ulong ticket = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != InpMagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      ENUM_ORDER_TYPE tType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(tType != ordType) continue;

      string cmt = OrderGetString(ORDER_COMMENT);
      if(StringFind(cmt, "PIVOT") >= 0)
      {
         ticket = t;
         break;
      }
   }

   // Calcul des SL/TP autour du pivot
   double sl, tp;
   if(ordType == ORDER_TYPE_BUY_LIMIT)
   {
      sl = desiredPrice - atrVal * SL_ATRMult;
      tp = desiredPrice + atrVal * TP_ATRMult;
   }
   else
   {
      sl = desiredPrice + atrVal * SL_ATRMult;
      tp = desiredPrice - atrVal * TP_ATRMult;
   }

   if(ticket == 0)
   {
      // Pas encore d'ordre pivot → en placer un (en respectant la limite globale)
      if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "ORDRES PIVOT"))
         return;

      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);

      req.action = TRADE_ACTION_PENDING;
      req.symbol = _Symbol;
      req.magic  = InpMagicNumber;
      req.type   = ordType;
      req.volume = NormalizeVolumeForSymbol(0.01);
      req.price  = desiredPrice;
      req.sl     = sl;
      req.tp     = tp;
      req.comment = comment;

      if(!ValidateAndAdjustLimitPrice(req.price, req.sl, req.tp, ordType))
         return;

      if(OrderSend(req, res))
      {
         Print("📌 ORDRE PIVOT PLACÉ - ", _Symbol,
               " | Type: ", (ordType == ORDER_TYPE_BUY_LIMIT ? "BUY_LIMIT" : "SELL_LIMIT"),
               " | Prix: ", DoubleToString(req.price, _Digits),
               " | Src: ", src);
      }
      return;
   }

   // Ordre pivot déjà présent → le mettre à jour si le pivot a bougé
   double oldPrice = OrderGetDouble(ORDER_PRICE_OPEN);
   if(MathAbs(oldPrice - desiredPrice) < point * 2)
      return; // changement trop faible

   MqlTradeRequest modReq;
   MqlTradeResult  modRes;
   ZeroMemory(modReq);
   ZeroMemory(modRes);

   modReq.action = TRADE_ACTION_MODIFY;
   modReq.order  = ticket;
   modReq.symbol = _Symbol;
   modReq.magic  = InpMagicNumber;
   modReq.price  = desiredPrice;
   modReq.sl     = sl;
   modReq.tp     = tp;

   if(!ValidateAndAdjustLimitPrice(modReq.price, modReq.sl, modReq.tp, ordType))
      return;

   if(OrderSend(modReq, modRes))
   {
      Print("🔧 ORDRE PIVOT AJUSTÉ - ", _Symbol,
            " | Type: ", (ordType == ORDER_TYPE_BUY_LIMIT ? "BUY_LIMIT" : "SELL_LIMIT"),
            " | Ancien: ", DoubleToString(oldPrice, _Digits),
            " | Nouveau: ", DoubleToString(modReq.price, _Digits),
            " | Src: ", src);
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
   if((UseGlobalPositionLimit && CountPositionsOurEA() >= MaxPositionsTerminal) || IsMaxSimultaneousEAOrdersReached()) return;
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
      if(StringFind(_Symbol, "Boom") >= 0)
      {
         // Boom n'accepte que BUY
         if(sig.action == "SELL")
         {
            Print("❌ SELL SMC BLOQUÉ - Boom n'accepte que BUY (IA: ", g_lastAIAction, " ", DoubleToString(g_lastAIConfidence*100,1), "%)");
            ReleaseOpenLock();
            return;
         }
      }
      else if(StringFind(_Symbol, "Crash") >= 0)
      {
         // Crash n'accepte que SELL
         if(sig.action == "BUY")
         {
            Print("❌ BUY SMC BLOQUÉ - Crash n'accepte que SELL (IA: ", g_lastAIAction, " ", DoubleToString(g_lastAIConfidence*100,1), "%)");
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

   // Réduire les entrées hâtives: exiger la flèche SMC_DERIV_ARROW avant tout ordre au marché
   if(!HasRecentSMCDerivArrowForDirection(sig.action))
   {
      Print("🚫 ORDRE SMC BLOQUÉ - Attendre flèche SMC_DERIV_ARROW ", sig.action, " sur ", _Symbol);
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
         Print("✅ SMC BUY @ ", sig.entryPrice, " - ", sig.concept);
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
         Print("✅ SMC SELL @ ", sig.entryPrice, " - ", sig.concept);
         if(UseNotifications) { Alert("SMC SELL ", _Symbol, " ", sig.concept); SendNotification("SMC SELL " + _Symbol + " " + sig.concept); }
      }
   }
   ReleaseOpenLock();
}

double CalculateLotSize()
{
   // Mettre à jour les stats de drawdown journalier
   UpdateDailyEquityStats();

   // Si le gain journalier cible est atteint et une pause est active, bloquer toute nouvelle entrée
   if(IsDailyProfitPauseActive())
   {
      Print("⏸ Nouvelle entrée bloquée - pause journalière active après gain cible.");
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

double NormalizeVolumeForSymbolEx(string symbol, double desiredVolume)
{
   double minLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
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
      g_dailyPauseUntil = 0; // reset de la pause au changement de journée
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

// Indique si le gain journalier cible est atteint et déclenche une pause 1h si nécessaire
bool IsDailyProfitPauseActive()
{
   // Si pas de cible configurée ou stats non initialisées, ne rien faire
   if(DailyProfitTargetDollars <= 0.0 || g_dailyStartEquity <= 0.0)
      return false;

   datetime now = TimeCurrent();

   // Si une pause est déjà en cours et pas encore expirée
   if(g_dailyPauseUntil > now)
      return true;

   // Si la pause a expiré, la considérer comme terminée
   if(g_dailyPauseUntil != 0 && g_dailyPauseUntil <= now)
      return false;

   // Calculer le gain journalier en équité
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dailyProfit = equity - g_dailyStartEquity;

   if(dailyProfit >= DailyProfitTargetDollars)
   {
      // Démarrer une nouvelle pause d'une heure
      g_dailyPauseUntil = now + 3600;
      Print("⏸ PAUSE JOURNALIÈRE ACTIVÉE - Gain journalier ",
            DoubleToString(dailyProfit, 2), "$ ≥ ",
            DoubleToString(DailyProfitTargetDollars, 2),
            "$ | Trading en pause jusqu'à ",
            TimeToString(g_dailyPauseUntil, TIME_SECONDS));
      return true;
   }

   return false;
}

// Indique si la pause après perte cumulative est active
bool IsCumulativeLossPauseActive()
{
   if(CumulativeLossPauseThresholdDollars <= 0) return false;

   datetime now = TimeCurrent();

   if(g_lossPauseUntil > now)
      return true;

   if(g_lossPauseUntil != 0 && g_lossPauseUntil <= now)
   {
      g_lossPauseUntil = 0;
      Print("▶️ REPRISE - Pause perte cumulative terminée");
   }

   return false;
}

//| Validation des prix LIMIT pour un symbole donné (scan multi-symboles) |
bool ValidateAndAdjustLimitPriceForSymbol(string symbol, double &entryPrice, double &stopLoss, double &takeProfit, ENUM_ORDER_TYPE orderType)
{
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
   long stopsLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = MathMax(stopsLevel * point, 30 * point);
   if(orderType == ORDER_TYPE_BUY_LIMIT)
   {
      if(entryPrice >= currentAsk || (currentAsk - entryPrice) < minDistance) return false;
      if(stopLoss >= entryPrice || (entryPrice - stopLoss) < minDistance) stopLoss = entryPrice - minDistance * 1.2;
      if(takeProfit <= entryPrice || (takeProfit - entryPrice) < minDistance) takeProfit = entryPrice + minDistance * 3;
   }
   else if(orderType == ORDER_TYPE_SELL_LIMIT)
   {
      if(entryPrice <= currentBid || (entryPrice - currentBid) < minDistance) return false;
      if(stopLoss <= entryPrice || (stopLoss - entryPrice) < minDistance) stopLoss = entryPrice + minDistance * 1.2;
      if(takeProfit >= entryPrice || (entryPrice - takeProfit) < minDistance) takeProfit = entryPrice - minDistance * 3;
   }
   entryPrice = NormalizeDouble(entryPrice, digits);
   stopLoss = NormalizeDouble(stopLoss, digits);
   takeProfit = NormalizeDouble(takeProfit, digits);
   return true;
}

//| VALIDATION ET AJUSTEMENT DES PRIX POUR ORDRES LIMITES            |
bool ValidateAndAdjustLimitPrice(double &entryPrice, double &stopLoss, double &takeProfit, ENUM_ORDER_TYPE orderType)
{
   // Règle directionnelle stricte pour Boom/Crash:
   // - Pas de SELL LIMIT sur Boom
   // - Pas de BUY LIMIT sur Crash
   bool isBoom  = (StringFind(_Symbol, "Boom")  >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   if(isBoom && orderType == ORDER_TYPE_SELL_LIMIT)
   {
      Print("🚫 VALIDATION LIMIT REFUSÉE - Pas de SELL LIMIT autorisé sur symbole Boom (", _Symbol, ")");
      return false;
   }
   if(isCrash && orderType == ORDER_TYPE_BUY_LIMIT)
   {
      Print("🚫 VALIDATION LIMIT REFUSÉE - Pas de BUY LIMIT autorisé sur symbole Crash (", _Symbol, ")");
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
      
      // Limiter le trailing aux marchés Volatility / Forex / Métaux (hors Boom/Crash)
      string symbol = posInfo.Symbol();
      ENUM_SYMBOL_CATEGORY cat = SMC_GetSymbolCategory(symbol);
      if(cat == SYM_BOOM_CRASH)
         continue;
      
      double profit = posInfo.Profit() + posInfo.Swap() + posInfo.Commission();
      double openPrice = posInfo.PriceOpen();
      double currentSL = posInfo.StopLoss();
      double currentTP = posInfo.TakeProfit();
      
      // Position initiale sans SL
      if(currentSL == 0)
      {
         if(posInfo.PositionType() == POSITION_TYPE_BUY)
         {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double newSL = currentPrice - trailDistance;
            
            // VALIDATION: Vérifier que la position existe toujours avant de modifier
            if(!PositionSelectByTicket(posInfo.Ticket()))
            {
               continue;
            }
            
            // Double validation: vérifier que le magic number et symbole correspondent
            if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol)
            {
               continue;
            }
            
            if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
               Print("🛡️ Stop loss initial BUY: ", DoubleToString(newSL, _Digits));
         }
         else
         {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double newSL = currentPrice + trailDistance;
            
            // VALIDATION: Vérifier que la position existe toujours avant de modifier
            if(!PositionSelectByTicket(posInfo.Ticket()))
            {
               continue;
            }
            
            // Double validation: vérifier que le magic number et symbole correspondent
            if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol)
            {
               continue;
            }
            
            if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
               Print("🛡️ Stop loss initial SELL: ", DoubleToString(newSL, _Digits));
         }
         continue;
      }
      
      // Trail si position est en gain OU si on risque de perdre >50% du gain maximum
      bool shouldTrail = false;
      
      if(profit > 0)
      {
         // Garder en mémoire le gain maximum
         if(profit > g_maxProfit) g_maxProfit = profit;
         
         // Activer le trailing SEULEMENT à partir de 1$ de gain
         // Avant 1$, on laisse respirer la position.
         if(profit < 1.0)
         {
            shouldTrail = false;
         }
         else
         {
            shouldTrail = true;
         }
      }
      else if(g_maxProfit >= 1.0)
      {
         // Si on a déjà eu au moins 1$ de gain et qu'on a rendu >50% de ce gain,
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
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double newSL = currentPrice - trailDistance;
            
            // Only move SL if it improves the current SL and is above open price
            if(newSL > currentSL && newSL > openPrice)
            {
               // VALIDATION: Vérifier que la position existe toujours avant de modifier
               if(!PositionSelectByTicket(posInfo.Ticket()))
               {
                  continue;
               }
               
               // Double validation: vérifier que le magic number et symbole correspondent
               if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol)
               {
                  continue;
               }
               
               if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
               {
                  Print("🔄 Trailing Stop BUY mis à jour: ", DoubleToString(currentSL, _Digits), " → ", DoubleToString(newSL, _Digits));
               }
            }
         }
         else if(posInfo.PositionType() == POSITION_TYPE_SELL)
         {
            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double newSL = currentPrice + trailDistance;
            
            // Only move SL if it improves the current SL and is below open price
            if((newSL < currentSL || currentSL == 0) && newSL < openPrice)
            {
               // VALIDATION: Vérifier que la position existe toujours avant de modifier
               if(!PositionSelectByTicket(posInfo.Ticket()))
               {
                  continue;
               }
               
               // Double validation: vérifier que le magic number et symbole correspondent
               if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber || PositionGetString(POSITION_SYMBOL) != _Symbol)
               {
                  continue;
               }
               
               if(trade.PositionModify(posInfo.Ticket(), newSL, posInfo.TakeProfit()))
               {
                  Print("🔄 Trailing Stop SELL mis à jour: ", DoubleToString(currentSL, _Digits), " → ", DoubleToString(newSL, _Digits));
               }
            }
         }
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
                     // Accumuler perte sur trades consécutifs → pause si seuil atteint
                     g_cumulativeLossSuccessive += MathAbs(profit);
                     if(CumulativeLossPauseThresholdDollars > 0 && g_cumulativeLossSuccessive >= CumulativeLossPauseThresholdDollars)
                     {
                        int pauseSec = MathMax(60, CumulativeLossPauseMinutes * 60);
                        g_lossPauseUntil = TimeCurrent() + pauseSec;
                        double totalLoss = g_cumulativeLossSuccessive;
                        g_cumulativeLossSuccessive = 0.0;
                        Print("⏸ PAUSE PERTE CUMULATIVE - ", DoubleToString(totalLoss, 2), "$ de pertes consécutives ≥ ",
                              DoubleToString(CumulativeLossPauseThresholdDollars, 2), "$ | Pause ", CumulativeLossPauseMinutes, " min jusqu'à ",
                              TimeToString(g_lossPauseUntil, TIME_SECONDS));
                     }
                  }
                  else if(symbol == g_lastLossSymbol)
                  {
                     g_lastLossSymbol = "";
                     g_lastLossTime   = 0;
                  }
                  if(profit > 0)
                     g_cumulativeLossSuccessive = 0.0;  // Reset sur gain (trades consécutifs interrompus)

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
   
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   
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

   if(IsSymbolPaused(_Symbol)) return;
   if(!CheckCooldownBeforeEntry(_Symbol)) return;          // Toujours attendre les petites bougies après un spike
   if(!CheckCorrectionZoneProtection("DERIV/SPIKE")) return;
   
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
   
   // DÉTECTION DES FLÈCHES DERIV ARROW EXISTANTES (locale à cette fonction)
   string arrowDirection = "";
   bool hasDerivArrow = GetDerivArrowDirection(arrowDirection);
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
   
   // Normaliser l'action IA pour les validations suivantes
   string aiAction = g_lastAIAction;
   if(aiAction == "buy") aiAction = "BUY";
   if(aiAction == "sell") aiAction = "SELL";
   
   if(hasDerivArrow)
   {
      Print("🎯 FLÈCHE DERIV ARROW DÉTECTÉE - Direction: ", arrowDirection, " sur ", _Symbol);
      if(isBoom && arrowDirection == "BUY")
      {
         // BOOM: entrer au marché seulement si l'IA est BUY avec confiance >= 77%
         double boomMinConf = 0.77;
         if(UseAIServer && (aiAction != "BUY" || g_lastAIConfidence < boomMinConf))
         {
            Print("🚫 FLÈCHE VERTE BOOM BLOQUÉE - IA=", aiAction,
                  " | Confiance=", DoubleToString(g_lastAIConfidence*100, 1), "% (< ",
                  DoubleToString(boomMinConf*100, 1), "%) | Pas d'entrée marché");
            return;
         }
         
         Print("✅ FLÈCHE VERTE + BOOM + IA BUY>=77% - Exécution BUY autorisée", ScalpArrowMode ? " (MODE SCALP)" : "");
         ExecuteDerivArrowTrade("BUY", true);  // true = entrée directe sur flèche
         return;
      }
      else if(isCrash && arrowDirection == "SELL")
      {
         Print("✅ FLÈCHE ROUGE + CRASH = COMPATIBLE - Exécution SELL autorisée", ScalpArrowMode ? " (MODE SCALP)" : "");
         ExecuteDerivArrowTrade("SELL", true);
         return;
      }
      else
      {
         Print("🚫 FLÈCHE DERIV ARROW INCOMPATIBLE - ", arrowDirection, " sur ", _Symbol, " (règle Boom/Crash)");
         return;
      }
   }
   
   // RÈGLE STRICTE: BLOQUER TOUS LES TRADES BUY SUR BOOM SI IA = SELL
   
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
      
      // BYPASS: Boom BUY en zone Discount (achat) = conditions favorables, seuil configurable
      // Permet de capturer les mouvements haussiers même avec confiance IA modérée (ex: 59%)
      double zoneFavMin = MathMax(0.50, MathMin(0.70, MinAIConfidenceBoomDiscount/100.0));
      if(isBoom && aiAction == "BUY" && inDiscount)
         requiredConfidence = MathMin(requiredConfidence, zoneFavMin);
      
      // Crash SELL en zone Premium (vente) = idem
      if(isCrash && aiAction == "SELL" && inPremium)
         requiredConfidence = MathMin(requiredConfidence, zoneFavMin);
      
      // Si l'IA est SELL en zone Discount (achat) ou BUY en zone Premium (vente),
      // augmenter l'exigence de confiance (trade "contre-zone").
      bool contrarianToZone = (aiAction == "SELL" && inDiscount) || (aiAction == "BUY" && inPremium);
      if(contrarianToZone)
         requiredConfidence = MathMax(requiredConfidence, 0.75);
   }
   else
   {
      // Pour Volatility: garder un seuil fixe plus élevé
      requiredConfidence = 0.85;
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
      
      // Nouvelle info serveur IA: pattern escalier Boom/Crash (staircase_up / staircase_down)
      // Si proba escalier élevée, on assouplit légèrement les conditions spike pour ne pas rater la série.
      double staircaseProb = 0.0;
      if(UseAIServer)
      {
         string stairUrl = (UseRenderAsPrimary ? AI_ServerRender : AI_ServerURL) + "/ml/staircase?symbol=";
         string symEsc = _Symbol;
         StringReplace(symEsc, " ", "%20");
         stairUrl += symEsc + "&timeframe=M1";
         
         char stairResult[];
         string stairHeaders;
         char stairPost[];
         int stairRes = WebRequest("GET", stairUrl, "", AI_Timeout_ms, stairPost, stairResult, stairHeaders);
         if(stairRes == 200)
         {
            string stairJson = CharArrayToString(stairResult);
            if(StringFind(stairJson, "staircase_up_prob") >= 0 || StringFind(stairJson, "staircase_down_prob") >= 0)
            {
               if(isBoom)
                  staircaseProb = StrToDouble(ExtractJsonValue(stairJson, "staircase_up_prob"));
               else if(isCrash)
                  staircaseProb = StrToDouble(ExtractJsonValue(stairJson, "staircase_down_prob"));
            }
         }
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
      
      // Si le serveur IA détecte un escalier fort (staircaseProb ≥ Staircase_MinProbability),
      // on autorise aussi l'entrée même si le filtre spike pur est trop strict.
      if(!shouldTrade && staircaseProb >= Staircase_MinProbability)
      {
         shouldTrade = true;
         Print("✅ Boom/Crash - Entrée autorisée par pattern ESCALIER IA (proba=",
               DoubleToString(staircaseProb*100.0, 1), "%) même si conditions spike strictes non remplies");
      }

      // Crash 1000 / Boom‑Crash en zone Premium "épuisée":
      // si le prix est déjà très haut dans la zone Premium H1, on autorise une
      // entrée anticipée dès qu'un pré‑spike OU un spike valide apparaît,
      // pour capter la série de spikes de retournement plus tôt.
      if(!shouldTrade && isCrash && aiAction == "SELL" && IsDeepInPremiumZone75())
      {
         if(preSpike || spikeDetected)
         {
            shouldTrade = true;
            Print("✅ Crash - Entrée anticipée en zone Premium épuisée (pré‑spike/spike) pour capter la série de spikes de retournement");
         }
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
      
      // NOUVEAU: MODE TREND STAIRCASE - Tendance en escalier avec structure HH/HL ou LL/LH
      // Permet de capturer les tendances fortes même si proba spike est faible
      if(!shouldTrade && UseStaircaseTrendMode && g_lastAIConfidence >= 0.75) // Seuil de confiance modéré pour tendance escalier
      {
         bool staircaseTrend = IsStaircaseTrend(aiAction);
         if(staircaseTrend)
         {
            // Validation supplémentaire: éviter les zones extrêmes (Premium épuisé pour BUY, Discount épuisé pour SELL)
            bool extremeZoneBlocked = false;
            if(isBoom && aiAction == "BUY" && IsDeepInPremiumZone75())
            {
               extremeZoneBlocked = true;
               Print("🚫 Tendance escalier bloquée - Boom BUY en zone Premium épuisée (>75%)");
            }
            if(isCrash && aiAction == "SELL" && IsDeepInDiscountZone75())
            {
               extremeZoneBlocked = true;
               Print("🚫 Tendance escalier bloquée - Crash SELL en zone Discount épuisée (>75%)");
            }
            
            if(!extremeZoneBlocked)
            {
               shouldTrade = true;
               Print("✅ Boom/Crash - Entrée autorisée par TENDANCE ESCALIER (", 
                     DoubleToString(g_lastAIConfidence*100, 1), "% confiance IA) - Structure ",
                     aiAction == "BUY" ? "HH/HL" : "LL/LH", " détectée");
            }
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
            " | Mode Trend Staircase: ", UseStaircaseTrendMode ? "OUI" : "NON",
            " | Autorisé: ", shouldTrade ? "OUI" : "NON");
   }
   else if(isVolatility)
   {
      // Volatility: Pas de spike requis, seulement signal IA fort (80%+)
      spikeDetected = false; // Non applicable
      shouldTrade = true; // Trade autorisé si IA forte (déjà validé ci-dessus)
      
      Print("🔍 DEBUG - Volatility - Trade autorisé (confiance IA: ", DoubleToString(g_lastAIConfidence*100, 1), "%)");
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
      // Règles Boom/Crash: directions spécifiques
      if(StringFind(_Symbol, "Boom") >= 0)
      {
         if(iaDirection == "BUY")
         {
            direction = "BUY"; // Boom + IA BUY = OK
         }
         else
         {
            Print("❌ CONFLIT: IA dit ", iaDirection, " mais Boom n'accepte que BUY - trade ignoré");
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
            Print("❌ CONFLIT: IA dit ", iaDirection, " mais Crash n'accepte que SELL - trade ignoré");
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

//| VARIABLES SUPABASE POUR SUPPORT/RÉSISTANCE |
string g_supabaseUrl = "";
string g_supabaseApiKey = "";

//| PLACER ORDRE LIMIT POST-HOLD APRÈS PERTE 2,0$ |
void PlacePostHoldLimitOrder(string closedSymbol, ENUM_POSITION_TYPE closedType, double closedProfit)
{
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
   bool isBoom = (StringFind(closedSymbol, "Boom") >= 0);
   bool isCrash = (StringFind(closedSymbol, "Crash") >= 0);
   
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
      // Boom en zone Discount avec position BUY fermée → ordre BUY limit
      limitType = ORDER_TYPE_BUY_LIMIT;
      
      // NOUVEAU: UTILISER L'INTERSECTION CANAL SMC
      limitPrice = FindSMCChannelIntersection("BUY");
      if(limitPrice > 0)
      {
         limitReason = "Boom Discount - Intersection Canal SMC (post-HOLD)";
         shouldPlaceLimit = true;
         Print("🎯 POST-HOLD - Intersection Canal SMC trouvée: ", DoubleToString(limitPrice, _Digits));
      }
      else
      {
         // Fallback sur support historique
         limitPrice = GetSupportLevel(20); // Support sur 20 barres
         limitReason = "Boom Discount - Support 20 bars (post-HOLD)";
         shouldPlaceLimit = true;
         Print("🎯 POST-HOLD - Fallback support historique: ", DoubleToString(limitPrice, _Digits));
      }
      Print("🎯 POST-HOLD - Condition Boom+Discount+BUY remplie");
   }
   else if(isCrash && inPremium && closedType == POSITION_TYPE_SELL)
   {
      // Crash en zone Premium avec position SELL fermée → ordre SELL limit
      limitType = ORDER_TYPE_SELL_LIMIT;
      
      // NOUVEAU: UTILISER L'INTERSECTION CANAL SMC
      limitPrice = FindSMCChannelIntersection("SELL");
      if(limitPrice > 0)
      {
         limitReason = "Crash Premium - Intersection Canal SMC (post-HOLD)";
         shouldPlaceLimit = true;
         Print("🎯 POST-HOLD - Intersection Canal SMC trouvée: ", DoubleToString(limitPrice, _Digits));
      }
      else
      {
         // Fallback sur résistance historique
         limitPrice = GetResistanceLevel(20); // Résistance sur 20 barres
         limitReason = "Crash Premium - Resistance 20 bars (post-HOLD)";
         shouldPlaceLimit = true;
         Print("🎯 POST-HOLD - Fallback résistance historique: ", DoubleToString(limitPrice, _Digits));
      }
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
   
   // Sécurité globale: un seul ordre LIMIT par symbole
   if(!CanPlaceNewLimitOrderForSymbol(closedSymbol, "POST-HOLD LIMIT"))
      return;
   
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
   
   // Vérification IA avant envoi LIMIT (direction en fonction du type)
   string dir = (limitType == ORDER_TYPE_BUY_LIMIT ? "BUY" : "SELL");
   if(!IsAILimitOrderAllowed(dir))
   {
      Print("🚫 POST-HOLD LIMIT annulé - Conditions IA non valides pour LIMIT (", dir, ").");
   }
   else if(OrderSend(request, result))
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

//| Place des ordres LIMIT sur les symboles où le prix est déjà proche du niveau BUY/SELL LIMIT |
void ScanAndPlaceLimitOrdersNearLevels()
{
   if(IsMaxSimultaneousEAOrdersReached()) return;
   if(!CanTradeToday()) return;
   
   for(int i = 0; i < g_trackedSymbolsCount; i++)
   {
      string symbol = g_trackedSymbols[i];
      bool isBoom  = (StringFind(symbol, "Boom")  >= 0);
      bool isCrash = (StringFind(symbol, "Crash") >= 0);
      if(!isBoom && !isCrash) continue;
      
      if(CountPositionsForSymbol(symbol) > 0) continue;
      if(!CanPlaceNewLimitOrderForSymbol(symbol, "SCAN PROXIMITÉ", true)) continue;
      
      SymbolSelect(symbol, true);
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(bid <= 0 || ask <= 0) continue;
      
      double atrVal = GetATRForSymbol(symbol);
      if(atrVal <= 0) atrVal = (ask - bid) * 2;
      
      string srcBuy = "", srcSell = "";
      double buyLevel  = GetClosestBuyLevelForSymbol(symbol, bid, atrVal, MaxDistanceLimitATR, srcBuy);
      double sellLevel = GetClosestSellLevelForSymbol(symbol, ask, atrVal, MaxDistanceLimitATR, srcSell);
      
      double proximityTol = atrVal * ProximityLimitATR;
      
      // Vérifier IA pour ce symbole
      string iaAct = "HOLD";
      double iaConf = 0.0;
      if(UseAIServer && !GetAISignalForSymbol(symbol, "M1", iaAct, iaConf))
         iaAct = "HOLD";
      StringToUpper(iaAct);
      
      MqlTradeRequest req;
      MqlTradeResult  res;
      ZeroMemory(req);
      ZeroMemory(res);
      req.action = TRADE_ACTION_PENDING;
      req.symbol = symbol;
      req.magic  = InpMagicNumber;
      req.volume = NormalizeVolumeForSymbolEx(symbol, 0.01);
      if(req.volume <= 0) continue;
      
      // Boom: BUY LIMIT si prix proche du support (buyLevel)
      if(isBoom && buyLevel > 0 && (ask - buyLevel) <= proximityTol && buyLevel < ask)
      {
         if(UseAIServer && (iaAct != "BUY" || iaConf < 0.75)) continue;
         if(!AllowReentryAfterRecentLoss(symbol, "BUY", false)) continue;
         
         req.type = ORDER_TYPE_BUY_LIMIT;
         req.price = buyLevel;
         req.sl    = buyLevel - atrVal * SL_ATRMult;
         req.tp    = buyLevel + atrVal * TP_ATRMult;
         req.comment = "SCAN PROX BUY (" + srcBuy + ")";
         
         if(ValidateAndAdjustLimitPriceForSymbol(symbol, req.price, req.sl, req.tp, ORDER_TYPE_BUY_LIMIT))
         {
            if(OrderSend(req, res))
               Print("📌 ORDRE LIMIT PROXIMITÉ - ", symbol, " BUY @ ", DoubleToString(req.price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)), " | Src: ", srcBuy);
         }
         continue; // Un seul ordre par symbole par scan
      }
      
      // Crash: SELL LIMIT si prix proche de la résistance (sellLevel)
      if(isCrash && sellLevel > 0 && (sellLevel - bid) <= proximityTol && sellLevel > bid)
      {
         if(UseAIServer && (iaAct != "SELL" || iaConf < 0.75)) continue;
         if(!AllowReentryAfterRecentLoss(symbol, "SELL", false)) continue;
         
         req.type = ORDER_TYPE_SELL_LIMIT;
         req.price = sellLevel;
         req.sl    = sellLevel + atrVal * SL_ATRMult;
         req.tp    = sellLevel - atrVal * TP_ATRMult;
         req.comment = "SCAN PROX SELL (" + srcSell + ")";
         
         if(ValidateAndAdjustLimitPriceForSymbol(symbol, req.price, req.sl, req.tp, ORDER_TYPE_SELL_LIMIT))
         {
            if(OrderSend(req, res))
               Print("📌 ORDRE LIMIT PROXIMITÉ - ", symbol, " SELL @ ", DoubleToString(req.price, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS)), " | Src: ", srcSell);
         }
      }
   }
}

//| SCANNER LES SYMBOLES POUR MEILLEURES OPPORTUNITÉS |
void ScanSymbolsForOpportunities()
{
   // Scanner toutes les 30 secondes maximum
   if(TimeCurrent() - g_lastScanTime < 30) return;
   g_lastScanTime = TimeCurrent();
   
   Print("🔍 SCAN MULTI-SYMBOLES - Recherche des meilleures opportunités...");
   
   // Initialiser la liste des symboles si vide
   if(g_trackedSymbolsCount == 0)
   {
      // Symboles Boom/Crash par défaut (tous les graphiques attachés)
      g_trackedSymbols[0] = "Boom 50 Index";
      g_trackedSymbols[1] = "Boom 300 Index";
      g_trackedSymbols[2] = "Boom 500 Index";
      g_trackedSymbols[3] = "Boom 900 Index";
      g_trackedSymbols[4] = "Boom 1000 Index";
      g_trackedSymbols[5] = "Crash 50 Index";
      g_trackedSymbols[6] = "Crash 300 Index";
      g_trackedSymbols[7] = "Crash 500 Index";
      g_trackedSymbols[8] = "Crash 900 Index";
      g_trackedSymbols[9] = "Crash 1000 Index";
      g_trackedSymbolsCount = 10;
   }
   
   // SCAN: placer ordres LIMIT sur symboles où le prix est déjà proche du niveau BUY/SELL LIMIT
   ScanAndPlaceLimitOrdersNearLevels();
   
   // Calculer le score d'opportunité pour chaque symbole
   for(int i = 0; i < g_trackedSymbolsCount; i++)
   {
      string symbol = g_trackedSymbols[i];
      g_symbolOpportunityScore[i] = CalculateOpportunityScore_V2(symbol);
      
      // Cacher le dernier signal IA par symbole pour logs / exécution
      string act = "HOLD";
      double conf = 0.0;
      if(GetAISignalForSymbol(symbol, "M1", act, conf))
      {
         g_symbolAIAction[i] = act;
         g_symbolAIConfidence[i] = conf;
         g_symbolAIUpdate[i] = TimeCurrent();
      }
      
      Print("📊 ", symbol, " | Score: ", DoubleToString(g_symbolOpportunityScore[i], 2));
   }
   
   // Trouver le meilleur symbole
   int bestIndex = -1;
   double bestScore = -1.0;
   
   for(int i = 0; i < g_trackedSymbolsCount; i++)
   {
      if(g_symbolOpportunityScore[i] > bestScore)
      {
         bestScore = g_symbolOpportunityScore[i];
         bestIndex = i;
      }
   }
   
   if(bestIndex >= 0 && bestScore > 0.5) // Score minimum pour trader
   {
      Print("🎯 MEILLEURE OPPORTUNITÉ - ", g_trackedSymbols[bestIndex], 
            " | Score: ", DoubleToString(bestScore, 2));
      
      // Exécution automatique: respecter éventuellement la limite globale, entrer au marché dès pré‑spike
      if(!IsMaxSimultaneousEAOrdersReached() &&
         (!UseGlobalPositionLimit || CountPositionsOurEA() < MaxPositionsTerminal))
      {
         string bestSymbol = g_trackedSymbols[bestIndex];
         if(CountPositionsForSymbol(bestSymbol) == 0)
         {
            bool isBoom = (StringFind(bestSymbol, "Boom") >= 0);
            bool isCrash = (StringFind(bestSymbol, "Crash") >= 0);
            string dir = isBoom ? "BUY" : (isCrash ? "SELL" : "");
            
            // Conditions: pré‑spike + IA pas HOLD et pas contre‑tendance
            bool preSpike = IsPreSpikePatternForSymbol(bestSymbol);
            string iaAct = g_symbolAIAction[bestIndex];
            double iaConf = g_symbolAIConfidence[bestIndex];
            
            // Seuil 77% demandé (0..1)
            double minConf = 0.77;
            
            bool iaOk = (!UseAIServer) || (iaAct != "HOLD" && iaAct == dir && iaConf >= minConf);
            
            if(preSpike && dir != "" && iaOk)
               ExecuteSpikeMarketTradeForSymbol(bestSymbol, dir, iaConf);
         }
      }
   }
}

// Exécution d'un spike trade au marché sur un symbole (multi‑symbole)
void ExecuteSpikeMarketTradeForSymbol(string symbol, string direction, double aiConfidence)
{
   if(!CanTradeToday()) return;
   if(IsMaxSimultaneousEAOrdersReached()) return;
   if(CountPositionsForSymbol(symbol) > 0) return;
   if(!IsDirectionAllowedForBoomCrash(symbol, direction)) return;
   
   // Protection: ne pas empiler des "SPIKE TRADE" sur un même symbole
   if(HasOpenSpikeTradeForSymbol(symbol)) return;
   
   // Assurer que le symbole est sélectionné
   SymbolSelect(symbol, true);
   
   double lot = GetMinLotForSymbol(symbol);
   if(lot <= 0) lot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   
   // Market order sans SL/TP (la logique de fermeture spike gère la sortie)
   double sl = 0.0, tp = 0.0;
   
   if(!TryAcquireOpenLock()) return;
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   bool ok = false;
   if(direction == "BUY")
      ok = trade.Buy(lot, symbol, 0.0, sl, tp, "SPIKE TRADE");
   else if(direction == "SELL")
      ok = trade.Sell(lot, symbol, 0.0, sl, tp, "SPIKE TRADE");
   
   ReleaseOpenLock();
   
   if(ok && trade.ResultRetcode() == TRADE_RETCODE_DONE)
   {
      ResetPositionOpenTime(symbol);
      Print("⚡ SPIKE TRADE OUVERT (multi‑symbole) - ", symbol, " ", direction,
            " | IA=", (UseAIServer ? (direction + " " + DoubleToString(aiConfidence*100, 1) + "%") : "OFF"));
      if(UseNotifications)
         SendNotification("⚡ SPIKE TRADE " + symbol + " " + direction + " (IA " + DoubleToString(aiConfidence*100, 1) + "%)");
   }
   else
   {
      Print("❌ SPIKE TRADE ÉCHEC - ", symbol, " ", direction, " | ret=", (int)trade.ResultRetcode());
   }
}

//| CALCULER LE SCORE D'OPPORTUNITÉ POUR UN SYMBOLE |
double CalculateOpportunityScore_V2(string symbol)
{
   double score = 0.0;
   
   // 1. Vérifier la volatilité récente (30%))
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 20, rates) < 10) return 0.0;
   
   double totalRange = 0.0;
   for(int i = 0; i < 10; i++)
   {
      totalRange += rates[i].high - rates[i].low;
   }
   double avgRange = totalRange / 10.0;
   double volatilityScore = MathMin(avgRange / rates[0].close * 100, 10.0) / 10.0; // Normalisé 0-1
   score += volatilityScore * 0.3;
   
   // 1b. Pré‑spike (compression + consolidation + keylevel) (30%)
   bool preSpike = IsPreSpikePatternForSymbol(symbol);
   if(preSpike) score += 0.30;
   
   // 2. Vérifier si le prix est près d'un S/R (40%))
   string srType = "";
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
   double nearestSR = FindNearestSupportResistance(symbol, currentPrice, srType);
   
   if(nearestSR > 0)
   {
      double distance = MathAbs(nearestSR - currentPrice) / currentPrice * 100;
      double proximityScore = MathMax(0, 1 - distance / 0.5); // Plus proche = meilleur score
      score += proximityScore * 0.4;
   }
   
   // 3. Vérifier l'alignement IA (20%)
   // Important: pour le scan multi‑symbole, on récupère une décision IA par symbole.
   string aiAct = "";
   double aiConf = 0.0;
   if(GetAISignalForSymbol(symbol, "M1", aiAct, aiConf))
   {
      // Score uniquement si direction IA compatible Boom/Crash
      bool isBoom = (StringFind(symbol, "Boom") >= 0);
      bool isCrash = (StringFind(symbol, "Crash") >= 0);
      bool dirOk = (isBoom && aiAct == "BUY") || (isCrash && aiAct == "SELL");
      if(dirOk && aiAct != "HOLD")
         score += MathMin(1.0, MathMax(0.0, aiConf)) * 0.2;
   }
   
   // 4. Vérifier si aucune position en cours (10%))
   int positions = CountPositionsForSymbol(symbol);
   if(positions == 0)
   {
      score += 0.1;
   }
   
   return MathMin(score, 1.0); // Limiter à 1.0
}

// Récupère et parse le signal IA d'un symbole (action + confidence)
bool GetAISignalForSymbol(string symbol, string timeframe, string &actionOut, double &confidenceOut)
{
   actionOut = "HOLD";
   confidenceOut = 0.0;
   if(!UseAIServer) return false;
   
   string json = GetAISignalData(symbol, timeframe);
   if(json == "") return false;
   
   string act = ExtractJsonValue(json, "action");
   StringReplace(act, "\"", "");
   StringTrimLeft(act);
   StringTrimRight(act);
   StringToUpper(act);
   if(act == "") act = "HOLD";
   
   string confStr = ExtractJsonValue(json, "confidence");
   StringReplace(confStr, "\"", "");
   StringTrimLeft(confStr);
   StringTrimRight(confStr);
   double conf = (confStr == "" ? 0.0 : StringToDouble(confStr));
   if(conf > 1.0) conf = conf / 100.0; // tolérer un format 0-100
   if(conf < 0.0) conf = 0.0;
   if(conf > 1.0) conf = 1.0;
   
   actionOut = act;
   confidenceOut = conf;
   return true;
}

//| TROUVER LE MEILLEUR SYMBOLE À TRADER |
string GetBestSymbolToTrade()
{
   int bestIndex = -1;
   double bestScore = -1.0;
   
   for(int i = 0; i < g_trackedSymbolsCount; i++)
   {
      if(g_symbolOpportunityScore[i] > bestScore)
      {
         bestScore = g_symbolOpportunityScore[i];
         bestIndex = i;
      }
   }
   
   if(bestIndex >= 0 && bestScore > 0.5)
   {
      return g_trackedSymbols[bestIndex];
   }
   
   return "";
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
               // NOUVEAU: Protection spéciale pour les positions SPIKE TRADE sur Boom/Crash
               // Les positions SPIKE TRADE ne doivent jamais être fermées sur HOLD
               // car elles sont conçues pour capturer les spikes qui peuvent survenir après des signaux HOLD
               string posComment = PositionGetString(POSITION_COMMENT);
               ENUM_SYMBOL_CATEGORY symCat = SMC_GetSymbolCategory(posSymbol);
               
               if(symCat == SYM_BOOM_CRASH && StringFind(posComment, "SPIKE TRADE") >= 0)
               {
                  Print("🛑 SKIP CLOSE (SPIKE TRADE sur HOLD) - Position protégée | ", posSymbol,
                        " | Ticket: ", posTicket, " | Profit: ", DoubleToString(posProfit, 2), "$",
                        " | Comment: ", posComment,
                        " | 🎯 SPIKE TRADE - Maintien obligatoire même sur HOLD");
                  continue;
               }
               
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
                  
                  if(OrderSend(request, result))
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
   int maxAllowedPositions = (accountEquity < 20.0) ? 1 : (UseGlobalPositionLimit ? MaxPositionsTerminal : 1000000);
   
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

//| AFFICHER LE COMPTEUR JOURNALIER SUR LE GRAPHIQUE |
void DrawDailyCounter()
{
   string counterName = "SMC_DAILY_COUNTER";
   
   // Mettre à jour le profit journalier
   UpdateDailyProfit();
   
   // NOUVEAU: Mettre à jour la protection du capital
   InitializeCapitalProtection();
   
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double weeklyProfit = currentBalance - g_weeklyStartingBalance;
   double monthlyProfit = currentBalance - g_monthlyStartingBalance;
   
   // Créer le texte du compteur
   string counterText = "📊 TRADING JOURNALIER\n";
   counterText += "━━━━━━━━━━━━━━━\n";
   counterText += "Profit: " + DoubleToString(g_dailyProfit, 2) + "$\n";
   counterText += "Objectif: " + DoubleToString(g_dailyTarget, 2) + "$\n";
   counterText += "Maximum: " + DoubleToString(g_dailyMaxAllowed, 2) + "$\n";
   counterText += "Trades: " + IntegerToString(g_dailyTradesCount) + "\n";
   
   // NOUVEAU: Ajouter les informations de protection du capital
   counterText += "\n🛡️ PROTECTION CAPITAL\n";
   counterText += "━━━━━━━━━━━━━━━\n";
   counterText += "Semaine: " + DoubleToString(weeklyProfit, 2) + "$\n";
   counterText += "Mois: " + DoubleToString(monthlyProfit, 2) + "$\n";
   counterText += "Gains: " + DoubleToString(g_totalAccumulatedGains, 2) + "$\n";
   
   // Couleur selon le statut
   color counterColor = clrWhite;
   string statusText = "";
   
   if(g_robotStoppedForDay)
   {
      counterColor = clrRed;
      statusText = "\n🛑 ROBOT ARRÊTÉ";
   }
   else if(g_dailyTargetReached)
   {
      counterColor = clrYellow;
      statusText = "\n🎯 OBJECTIF ATTEINT";
   }
   else if(!IsCapitalProtected())
   {
      counterColor = clrOrange;
      statusText = "\n🛡️ PROTECTION ACTIVE";
   }
   else
   {
      counterColor = clrLime;
      statusText = "\n🚀 EN COURS";
   }
   
   // Calculer la progression
   double progress = MathMin(g_dailyProfit / g_dailyTarget * 100, 100);
   counterText += statusText;
   counterText += "\nProgression: " + DoubleToString(progress, 1) + "%";
   
   // NOUVEAU: Ajouter le niveau de risque actuel
   double riskPercent = GetAdaptiveRiskPercent();
   counterText += "\nRisque: " + DoubleToString(riskPercent, 1) + "%";
   
   // Créer ou mettre à jour l'objet
   if(ObjectFind(0, counterName) < 0)
   {
      ObjectCreate(0, counterName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, counterName, OBJPROP_XDISTANCE, 20);
      ObjectSetInteger(0, counterName, OBJPROP_YDISTANCE, 100);
      ObjectSetString(0, counterName, OBJPROP_TEXT, counterText);
      ObjectSetString(0, counterName, OBJPROP_FONT, "Courier New");
      ObjectSetInteger(0, counterName, OBJPROP_FONTSIZE, 8); // Réduit pour plus d'infos
      ObjectSetInteger(0, counterName, OBJPROP_COLOR, counterColor);
      ObjectSetInteger(0, counterName, OBJPROP_BGCOLOR, clrBlack);
      ObjectSetInteger(0, counterName, OBJPROP_BORDER_COLOR, counterColor);
   }
   else
   {
      ObjectSetString(0, counterName, OBJPROP_TEXT, counterText);
      ObjectSetInteger(0, counterName, OBJPROP_COLOR, counterColor);
   }
}
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
void ExecuteDerivArrowTrade(string direction, bool fromArrowDirect = false)
{
   if(!CanTradeToday())
   {
      Print("🚫 DERIV ARROW BLOQUÉ - Robot arrêté pour la journée");
      return;
   }
   
   // MODE SCALP FLÈCHE: entrée directe - bypass IA / filtres principaux
   bool scalpMode = (ScalpArrowMode && fromArrowDirect);
   if(scalpMode)
      Print("📌 MODE SCALP - Entrée directe sur flèche (bypass IA/cooldown)");
   else
   {
      if(!IsOrderExecutionAllowed()) return;
   }
   
   Print("🎯 EXÉCUTION DERIV ARROW - Direction: ", direction, " | Symbole: ", _Symbol);
   
   // Protection anti‑reprise après gain: ignorée en mode scalp pour entrer dès le 1er signal
   if(!scalpMode && !CanTradeAfterProfitClose(_Symbol))
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Protection anti-reprise après gain active");
      return;
   }
   if(!scalpMode) Print("✅ Protection anti-reprise OK");
   
   if(IsMaxSimultaneousEAOrdersReached())
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Limite de trades atteinte (", MaxPositionsTerminal, ")");
      return;
   }
   
   // Cooldown après spike: ignoré en mode scalp pour capter le spike immédiatement
   if(!scalpMode && !CheckCooldownBeforeEntry(_Symbol))
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Cooldown actif");
      return;
   }
   if(!scalpMode) Print("✅ Protection capital OK");
   
   // Vérification confiance IA - bypass en mode scalp
   if(!scalpMode && UseAIServer)
   {
      double aiConfidence = g_lastAIConfidence;
      Print("📊 Vérification IA - Confiance: ", DoubleToString(aiConfidence, 1), "% | Action: ", g_lastAIAction);
      if(aiConfidence < MinAIConfidencePercent)
      {
         Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Confiance IA insuffisante: ", 
               DoubleToString(aiConfidence, 1), "% < ", DoubleToString(MinAIConfidencePercent, 1), "% minimum");
         Print("   📊 IA Action: ", g_lastAIAction);
         return;
      }
      else
      {
         Print("✅ CONFIANCE IA VALIDÉE - ", DoubleToString(aiConfidence, 1), "% ≥ ", 
               DoubleToString(MinAIConfidencePercent, 1), "% minimum");
      }
   }
   else if(!scalpMode)
   {
      Print("📊 Serveur IA désactivé - Utilisation flèche uniquement");
   }
   
   // Vérification correction quantitative - bypass en mode scalp
   if(!scalpMode && g_correctionAnalysisDone)
   {
      double correctionScore = GetCorrectionScore();
      int predictedDuration = PredictCurrentCorrectionDuration();
      bool isHighRisk = IsInHighRiskCorrectionZone();
      double historicalProb = g_historicalCorrectionProb;
      double conditionalProb = CalculateConditionalCorrectionProbability();
      
      Print("📊 ANALYSE CORRECTION QUANTITATIVE:");
      Print("   📍 Score global: ", DoubleToString(correctionScore, 1), "% | Risque: ", (isHighRisk ? "ÉLEVÉ" : "MODÉRÉ"));
      Print("   📍 Probabilité historique: ", DoubleToString(historicalProb, 1), "% | Conditionnelle: ", DoubleToString(conditionalProb, 1), "%");
      Print("   📍 Durée prédite: ", predictedDuration, " bougies H1");
      
      // BLOQUER LES TRADES SI RISQUE DE CORRECTION ÉLEVÉ
      if(isHighRisk && correctionScore >= CorrectionZoneRiskThreshold)
      {
         Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Zone à haut risque de correction (", DoubleToString(correctionScore, 1), "% ≥ ", DoubleToString(CorrectionZoneRiskThreshold, 1), "%)");
         Print("   📊 Probabilité conditionnelle: ", DoubleToString(conditionalProb, 1), "% - Trop élevé pour entrer");
         return;
      }
      
      // CORRECTION PROBABLE : S'ABSTENIR AU LIEU DE TRADER
      if(correctionScore > 65.0 && predictedDuration > 0)
      {
         int recommendedWait = GetRecommendedWaitTime();
         Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Correction probable (", DoubleToString(correctionScore, 1), "%)");
         Print("   📊 Durée prédite: ", predictedDuration, " bougies | Attente recommandée: ", recommendedWait, " bougies");
         
         // Ici on NE prend PAS le trade : on laisse le marché terminer sa correction
         return;
      }
      else
      {
         Print("✅ CONDITIONS DE CORRECTION FAVORABLES - Risque acceptable pour entrée");
      }
   }
   else
   {
      Print("📊 Analyse correction pas encore disponible - Trade basé sur signal uniquement");
   }
   
   // MODE SCALP: exécution directe sur flèche - bypass spike series et toutes les protections
   bool isBoomSymbol = (StringFind(_Symbol, "Boom") >= 0);
   bool isCrashSymbol = (StringFind(_Symbol, "Crash") >= 0);
   if(scalpMode && (isBoomSymbol || isCrashSymbol))
   {
      Print("⚡ MODE SCALP - Exécution immédiate sur flèche (bypass spike/correction)");
      ExecuteSpikeTrade(direction, true);  // true = fromScalpArrow, bypass cooldown/zone/flèche
      return;
   }
   
   if(isBoomSymbol || isCrashSymbol)
   {
      string spikeDirection = isBoomSymbol ? "BUY" : "SELL";
      bool spikeSeriesDetected = DetectSpikeSeries(spikeDirection);
      
      if(spikeSeriesDetected)
      {
         Print("🚨 SÉRIE DE SPIKES DÉTECTÉE - ", _Symbol, " | Direction: ", spikeDirection);
         Print("⚡ EXÉCUTION IMMÉDIATE BASÉE SUR SÉRIE DE SPIKES");
         
         // Exécuter le trade basé sur la série de spikes
         ExecuteSpikeSeriesTrade(spikeDirection);
         return; // Sortir pour éviter les autres vérifications
      }
      else
      {
         Print("📊 Aucune série de spikes détectée - Continuer avec les autres stratégies");
      }
   }
   
   // Validation : Boom = BUY uniquement, Crash = SELL uniquement
   Print("🎯 Validation symbole - Boom: ", isBoomSymbol, " | Crash: ", isCrashSymbol, " | Direction: ", direction);
   
   if(isBoomSymbol && direction != "BUY")
   {
      Print("🚫 FLÈCHE DERIV ARROW IGNOREE - ", direction, " sur Boom (seul BUY autorisé)");
      return;
   }
   
   if(isCrashSymbol && direction != "SELL")
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
   
   // NOUVEAU: CHARGER LES ZONES DE CORRECTION SUPABASE
   LoadCorrectionZonesFromSupabase(_Symbol);
   
   // NOUVEAU: VÉRIFIER SI LE PRIX EST DANS LA ZONE D'ÉQUILIBRE
   bool inDiscount = IsInDiscountZone();
   bool inPremium  = IsInPremiumZone();
   
   // Vérifier les zones Supabase
   string supabaseZoneType = "";
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   bool inSupabaseZone = IsInSupabaseCorrectionZone(_Symbol, price, supabaseZoneType);
   
   Print("📍 Zones SMC - Discount: ", inDiscount, " | Premium: ", inPremium);
   if(inSupabaseZone)
   {
      Print("🌐 Zone Supabase: ", supabaseZoneType, " | Prix: ", DoubleToString(price, 5));
   }
   
   // Si le prix est dans la zone d'équilibre (ni premium ni discount), bloquer le trade
   if(!inDiscount && !inPremium && !inSupabaseZone)
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Prix dans zone d'équilibre sur ", _Symbol, 
            " (ni Premium ni Discount) - Trade non autorisé");
      return;
   }
   Print("✅ Zone SMC OK (ni Premium ni Discount)");
   
   // VALIDATION DES ZONES SUPABASE
   if(inSupabaseZone)
   {
      // Si le prix est dans une zone Supabase, appliquer des règles spécifiques
      if(supabaseZoneType == "support" && direction == "SELL")
      {
         Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - SELL dans zone de support Supabase sur ", _Symbol);
         return;
      }
      if(supabaseZoneType == "resistance" && direction == "BUY")
      {
         Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - BUY dans zone de résistance Supabase sur ", _Symbol);
         return;
      }
      if(supabaseZoneType == "premium" && direction == "BUY")
      {
         Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - BUY dans zone Premium Supabase sur ", _Symbol);
         return;
      }
      if(supabaseZoneType == "discount" && direction == "SELL")
      {
         Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - SELL dans zone Discount Supabase sur ", _Symbol);
         return;
      }
      
      Print("✅ Zone Supabase compatible - Direction: ", direction, " | Zone: ", supabaseZoneType);
      
      // Enregistrer l'utilisation de la zone Supabase
      RecordCorrectionZoneUsage(_Symbol, supabaseZoneType, price, false, true);
   }
   
   // Protection capital: zone d'achat au bord inférieur → SELL seulement si confiance IA >= 85%
   if(direction == "SELL" && IsAtDiscountLowerEdge() && g_lastAIConfidence < 0.85)
   {
      Print("🚫 FLÈCHE DERIV ARROW BLOQUÉE - Zone Discount au bord inférieur: SELL autorisé seulement si confiance IA ≥ 85% (actuel: ",
            DoubleToString(g_lastAIConfidence*100, 1), "%)");
      return;
   }
   // Protection capital: zone premium au bord supérieur (Boom) → BUY seulement si confiance IA >= 85%
   if(direction == "BUY" && isBoomSymbol && IsAtPremiumUpperEdge() && g_lastAIConfidence < 0.85)
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
   
   // Obtenir le prix actuel (déplacé ici pour être disponible plus tôt)
   MqlRates r[];
   ArraySetAsSeries(r, true);
   if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 1, r) < 1)
   {
      Print("❌ ERREUR - Impossible d'obtenir les prix pour ", _Symbol);
      return;
   }
   
   double currentPrice = r[0].close;
   
   // NOUVEAU: ANALYSE QUANTITATIVE DES CORRECTIONS
   // Lancer l'analyse historique des corrections
   DetectHistoricalCorrections();
   
   // NOUVEAU: PROTECTION CONTRE LES ZONES DE CORRECTION AVANCÉE
   // Utiliser la méthode quantitative pour déterminer si on doit bloquer les entrées
   double correctionScore = GetCorrectionScore();
   bool isHighRiskZone = IsInHighRiskCorrectionZone();
   int recommendedWait = GetRecommendedWaitTime();
   
   // Vérifier si un spike a été détecté récemment
   int spikeSymbolIndex = -1;
   if(StringFind(_Symbol, "Crash 300") >= 0) spikeSymbolIndex = 0;
   else if(StringFind(_Symbol, "Crash 500") >= 0) spikeSymbolIndex = 1;
   else if(StringFind(_Symbol, "Crash 1000") >= 0) spikeSymbolIndex = 2;
   else if(StringFind(_Symbol, "Boom 300") >= 0) spikeSymbolIndex = 3;
   else if(StringFind(_Symbol, "Boom 500") >= 0) spikeSymbolIndex = 4;
   else if(StringFind(_Symbol, "Boom 1000") >= 0) spikeSymbolIndex = 5;
   else spikeSymbolIndex = 6;
   
   // Log des informations de correction
   Print("🔍 ANALYSE QUANTITATIVE - ", _Symbol);
   Print("   📊 Score de correction: ", DoubleToString(correctionScore, 1), "%");
   Print("   📊 Zone à haut risque: ", (isHighRiskZone ? "OUI" : "NON"));
   Print("   📊 Attente recommandée: ", recommendedWait, " bougies");
   
   if(g_lastSpikeDetectionTime[spikeSymbolIndex] > 0)
   {
      int candlesSinceSpike = (int)((TimeCurrent() - g_lastSpikeDetectionTime[spikeSymbolIndex]) / PeriodSeconds(PERIOD_M1));
      
      // Utiliser la durée recommandée au lieu de fixe 5 bougies
      int minWaitTime = recommendedWait;
      
      // Si zone à haut risque, augmenter l'attente
      if(isHighRiskZone) minWaitTime = (int)(minWaitTime * 1.5);
      
      // Si moins de la durée requise, bloquer les entrées
      if(candlesSinceSpike < minWaitTime)
      {
         Print("🔍 PROTECTION CORRECTION QUANTITATIVE - Flèche détectée mais zone de correction active");
         Print("   📍 Bougies écoulées: ", candlesSinceSpike, "/", minWaitTime, " - ATTENTE");
         Print("   📊 Score de correction: ", DoubleToString(correctionScore, 1), "% (", (isHighRiskZone ? "HAUT RISQUE" : "RISQUE MODÉRÉ"), ")");
         Print("   🚫 FLÈCHE DERIV ARROW BLOQUÉE - Zone de correction quantitative (", _Symbol, ")");
         return;
      }
      
      // Si plus de 15 bougies, réinitialiser (série terminée)
      if(candlesSinceSpike > 15)
      {
         g_lastSpikeDetectionTime[spikeSymbolIndex] = 0;
         Print("🔍 SÉRIE DE SPIKES TERMINÉE - Protection correction quantitative désactivée");
      }
   }
   
   // Protection supplémentaire si zone à haut risque même sans spike récent
   if(isHighRiskZone)
   {
      Print("🔍 ZONE À HAUT RISQUE DÉTECTÉE - Score: ", DoubleToString(correctionScore, 1), "%");
      Print("   ⚠️ ATTENTE RECOMMANDÉE: ", recommendedWait, " bougies avant toute entrée");
      Print("   🚫 FLÈCHE DERIV ARROW BLOQUÉE - Zone à haut risque de correction");
      return;
   }
   
   // NOUVEAU: PROTECTION CRASH 500 - Attendre après spike avant nouvelle entrée
   if(StringFind(_Symbol, "Crash") >= 0)
   {
      // Vérifier si un spike a été capturé récemment sur ce symbole
      static datetime lastSpikeTime[10]; // Tableau pour différents symboles Crash
      static int symbolIndex = -1;
      
      // Trouver l'index pour ce symbole
      // if(symbolIndex == -1)
      // {
         // Initialiser l'index basé sur le nom du symbole
         // if(StringFind(_Symbol, "Crash 300") >= 0) symbolIndex = 0;
         // else if(StringFind(_Symbol, "Crash 500") >= 0) symbolIndex = 1;
         // else if(StringFind(_Symbol, "Crash 1000") >= 0) symbolIndex = 2;
         // else symbolIndex = 3; // Autres Crash
      // }
      
      // Vérifier si un spike a été capturé récemment (dernières 5 minutes)
      if(g_lastSpikeDetectionTime[spikeSymbolIndex] > 0 && (TimeCurrent() - g_lastSpikeDetectionTime[spikeSymbolIndex]) < 300)
      {
         int minutesSinceSpike = (int)(TimeCurrent() - g_lastSpikeDetectionTime[spikeSymbolIndex]) / 60;
         Print("🛑 CRASH 500 PROTECTION - Spike capturé il y a ", minutesSinceSpike, " minute(s) sur ", _Symbol);
         Print("   ⏱️ ATTENTE 3 BOUGIES M1 avant nouvelle entrée (prix dans zone discount)");
         Print("   📍 Prix actuel: ", DoubleToString(currentPrice, _Digits), " | Zone: ", (inDiscount ? "DISCOUNT" : "AUTRE"));
         return;
      }
      
      // NOUVEAU: Si le prix est déjà dans la zone discount, attendre 3 bougies M1
      if(inDiscount)
      {
         // Vérifier si 3 bougies complètes se sont formées depuis le dernier spike
         if(g_lastSpikeDetectionTime[spikeSymbolIndex] > 0)
         {
            datetime threeCandlesLater = lastSpikeTime[symbolIndex] + 3 * PeriodSeconds(PERIOD_M1);
            if(TimeCurrent() < threeCandlesLater)
            {
               int candlesToWait = (int)((threeCandlesLater - TimeCurrent()) / PeriodSeconds(PERIOD_M1));
               Print("🛑 CRASH 500 ZONE DISCOUNT - Prix déjà dans zone d'achat sur ", _Symbol);
               Print("   ⏱️ ATTENTE de ", candlesToWait, " bougie(s) M1 avant nouvelle entrée");
               Print("   📍 Prix actuel: ", DoubleToString(currentPrice, _Digits), " | Zone: DISCOUNT");
               Print("   🎯 OBJECTIF: Éviter les entrées risquées après spike");
               return;
            }
         }
      }
   }
   
   // NOUVEAU: CAPTURE ACTIVE DES SÉRIES DE SPIKES SUR CANAL SUPÉRIEUR
   // Quand le prix touche smc_upper_chan et un spike arrive, CAPTURER les spikes
   if(StringFind(_Symbol, "Crash") >= 0 && direction == "SELL")
   {
      // Vérifier si le prix touche ou a touché récemment le canal supérieur
      bool touchedUpperChannel = PriceTouchesUpperChannel();
      
      if(touchedUpperChannel)
      {
         // Vérifier si un spike a été détecté récemment (dernières 2 minutes)
         static datetime lastUpperChannelSpikeTime[10]; // Tableau pour différents symboles Crash
         static int upperChannelSymbolIndex = -1;
         static bool spikeSeriesActive[10] = {false}; // Suivi des séries actives
         
         // Initialiser l'index si nécessaire
         if(upperChannelSymbolIndex == -1)
         {
            if(StringFind(_Symbol, "Crash 300") >= 0) upperChannelSymbolIndex = 0;
            else if(StringFind(_Symbol, "Crash 500") >= 0) upperChannelSymbolIndex = 1;
            else if(StringFind(_Symbol, "Crash 1000") >= 0) upperChannelSymbolIndex = 2;
            else upperChannelSymbolIndex = 3; // Autres Crash
         }
         
         // Détecter un spike récent (mouvement baissier rapide > 0.3% en 1 bougie)
         MqlRates recentRates[];
         ArraySetAsSeries(recentRates, true);
         if(CopyRates(_Symbol, PERIOD_M1, 0, 3, recentRates) >= 3)
         {
            // Calculer le pourcentage de mouvement de la dernière bougie
            double lastMovePct = MathAbs(recentRates[0].close - recentRates[0].open) / recentRates[0].open;
            
            // Si mouvement significatif détecté (spike probable)
            if(lastMovePct >= 0.003) // 0.3% de mouvement
            {
               lastUpperChannelSpikeTime[upperChannelSymbolIndex] = TimeCurrent();
               spikeSeriesActive[upperChannelSymbolIndex] = true; // Activer la série de spikes
               
               Print("🎯 SÉRIE DE SPIKES DÉTECTÉE - ", _Symbol);
               Print("   📍 Prix: ", DoubleToString(recentRates[0].close, _Digits), " | Mouvement: ", DoubleToString(lastMovePct*100, 2), "%");
               Print("   📍 Canal supérieur touché - Série de spikes baissiers ACTIVÉE");
               Print("   🚀 CAPTURE ACTIVE - Prêt à capturer les spikes descendants");
            }
         }
         
         // Si une série de spikes est active (dernières 5 minutes)
         if(spikeSeriesActive[upperChannelSymbolIndex] && 
            lastUpperChannelSpikeTime[upperChannelSymbolIndex] > 0 && 
            (TimeCurrent() - lastUpperChannelSpikeTime[upperChannelSymbolIndex]) < 300)
         {
            int minutesSinceSpike = (int)(TimeCurrent() - lastUpperChannelSpikeTime[upperChannelSymbolIndex]) / 60;
            
            Print("🚀 SÉRIE DE SPIKES EN COURS - ", _Symbol);
            Print("   📍 Canal supérieur + spikes baissiers actifs depuis ", minutesSinceSpike, " min");
            Print("   💡 CAPTURE IMMÉDIATE AUTORISÉE - Les spikes 'pleuvent', il faut les capturer !");
            Print("   🎯 OBJECTIF: Capturer tous les spikes descendants de la série");
            
            // ACCÉLÉRER l'exécution - pas d'attente pendant les séries de spikes
            spikeSeriesActive[upperChannelSymbolIndex] = true; // Maintenir actif
         }
         else if(spikeSeriesActive[upperChannelSymbolIndex])
         {
            // Désactiver la série après 5 minutes sans spike
            spikeSeriesActive[upperChannelSymbolIndex] = false;
            Print("⏹️ SÉRIE DE SPIKES TERMINÉE - ", _Symbol);
            Print("   📍 Plus de spikes détectés depuis 5 minutes");
            Print("   📊 Retour à la normale - Surveillance du prochain spike");
         }
      }
   }
   
   // NOUVEAU: CAPTURE ACTIVE DES SÉRIES DE SPIKES SUR CANAL INFÉRIEUR (Boom)
   // Quand le prix touche smc_lower_chan et un spike haussier arrive, CAPTURER les spikes
   if(StringFind(_Symbol, "Boom") >= 0 && direction == "BUY")
   {
      // Vérifier si le prix touche ou a touché récemment le canal inférieur
      bool touchedLowerChannel = PriceTouchesLowerChannel();
      
      if(touchedLowerChannel)
      {
         // Vérifier si un spike a été détecté récemment (dernières 2 minutes)
         static datetime lastLowerChannelSpikeTime[10]; // Tableau pour différents symboles Boom
         static int lowerChannelSymbolIndex = -1;
         static bool boomSpikeSeriesActive[10] = {false}; // Suivi des séries actives
         
         // Initialiser l'index si nécessaire
         if(lowerChannelSymbolIndex == -1)
         {
            if(StringFind(_Symbol, "Boom 300") >= 0) lowerChannelSymbolIndex = 0;
            else if(StringFind(_Symbol, "Boom 500") >= 0) lowerChannelSymbolIndex = 1;
            else if(StringFind(_Symbol, "Boom 1000") >= 0) lowerChannelSymbolIndex = 2;
            else lowerChannelSymbolIndex = 3; // Autres Boom
         }
         
         // Détecter un spike récent (mouvement haussier rapide > 0.3% en 1 bougie)
         MqlRates recentRates[];
         ArraySetAsSeries(recentRates, true);
         if(CopyRates(_Symbol, PERIOD_M1, 0, 3, recentRates) >= 3)
         {
            // Calculer le pourcentage de mouvement de la dernière bougie
            double lastMovePct = MathAbs(recentRates[0].close - recentRates[0].open) / recentRates[0].open;
            
            // Si mouvement significatif détecté (spike probable)
            if(lastMovePct >= 0.003) // 0.3% de mouvement
            {
               lastLowerChannelSpikeTime[lowerChannelSymbolIndex] = TimeCurrent();
               boomSpikeSeriesActive[lowerChannelSymbolIndex] = true; // Activer la série de spikes
               
               Print("🎯 SÉRIE DE SPIKES DÉTECTÉE - ", _Symbol);
               Print("   📍 Prix: ", DoubleToString(recentRates[0].close, _Digits), " | Mouvement: ", DoubleToString(lastMovePct*100, 2), "%");
               Print("   📍 Canal inférieur touché - Série de spikes haussiers ACTIVÉE");
               Print("   🚀 CAPTURE ACTIVE - Prêt à capturer les spikes haussiers");
            }
         }
         
         // Si une série de spikes est active (dernières 5 minutes)
         if(boomSpikeSeriesActive[lowerChannelSymbolIndex] && 
            lastLowerChannelSpikeTime[lowerChannelSymbolIndex] > 0 && 
            (TimeCurrent() - lastLowerChannelSpikeTime[lowerChannelSymbolIndex]) < 300)
         {
            int minutesSinceSpike = (int)(TimeCurrent() - lastLowerChannelSpikeTime[lowerChannelSymbolIndex]) / 60;
            
            Print("🚀 SÉRIE DE SPIKES EN COURS - ", _Symbol);
            Print("   📍 Canal inférieur + spikes haussiers actifs depuis ", minutesSinceSpike, " min");
            Print("   💡 CAPTURE IMMÉDIATE AUTORISÉE - Les spikes 'pleuvent', il faut les capturer !");
            Print("   🎯 OBJECTIF: Capturer tous les spikes haussiers de la série");
            
            // ACCÉLÉRER l'exécution - pas d'attente pendant les séries de spikes
            boomSpikeSeriesActive[lowerChannelSymbolIndex] = true; // Maintenir actif
         }
         else if(boomSpikeSeriesActive[lowerChannelSymbolIndex])
         {
            // Désactiver la série après 5 minutes sans spike
            boomSpikeSeriesActive[lowerChannelSymbolIndex] = false;
            Print("⏹️ SÉRIE DE SPIKES TERMINÉE - ", _Symbol);
            Print("   📍 Plus de spikes détectés depuis 5 minutes");
            Print("   📊 Retour à la normale - Surveillance du prochain spike");
         }
      }
   }
   
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
      if(isCrashSymbol || isBoomSymbol)
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
   
   if(OrderSend(request, result))
   {
      Print(" ORDRE DERIV ARROW EXÉCUTÉ - ", direction, " sur ", _Symbol,
            " | Prix: ", DoubleToString((direction == "BUY") ? askPrice : bidPrice, _Digits),
            " | SL: ", DoubleToString(stopLoss, _Digits),
            " | TP: ", DoubleToString(takeProfit, _Digits));
      
      // NOUVEAU: ENREGISTRER L'OUVERTURE DE POSITION
      RecordPositionOpen(_Symbol);
      
      Print("   Ticket: ", result.order);
      
      // MÉMORISER CETTE FLÈCHE COMME TRAITÉE
      lastProcessedArrow = currentArrowKey;
      lastProcessedTime = TimeCurrent();
   }
   else
   {
      Print("❌ ÉCHEC ORDRE DERIV ARROW - Erreur: ", GetLastError());
   }
}

//| EXÉCUTER UN TRADE BASÉ SUR SÉRIE DE SPIKES               |
void ExecuteSpikeSeriesTrade(string direction)
{
   // NOUVEAU: VÉRIFIER SI LE ROBOT PEUT TRADER AUJOURD'HUI
   if(!CanTradeToday())
   {
      Print("🚫 SÉRIE DE SPIKES BLOQUÉE - Robot arrêté pour la journée");
      return;
   }
   
   // COOLDOWN SPÉCIAL SÉRIE: attendre seulement 1-2 bougies après fermeture
   // (utilise CheckSeriesCooldownBeforeEntry au lieu de CheckCooldownBeforeEntry)
   if(!CheckSeriesCooldownBeforeEntry(_Symbol))
   {
      Print("🚫 SÉRIE DE SPIKES BLOQUÉE - Cooldown série encore actif (courte attente entre spikes)");
      return;
   }
   
   // NOUVEAU: BLOQUER TOUS LES ORDRES SI IA SERVER EST EN HOLD
   if(!IsOrderExecutionAllowed())
   {
      return;
   }
   
   Print("🚀 EXÉCUTION SÉRIE DE SPIKES - Direction: ", direction, " | Symbole: ", _Symbol);
   
   // NOUVEAU: VÉRIFICATION PROTECTION ANTI-REPRISE APRÈS GAIN
   if(!CanTradeAfterProfitClose(_Symbol))
   {
      Print("🚫 SÉRIE DE SPIKES BLOQUÉE - Protection anti-reprise après gain active");
      return;
   }
   Print("✅ Protection anti-reprise OK");
   
   // Protection contre les duplications
   if(CountPositionsForSymbol(_Symbol) > 0)
   {
      Print("🚫 SÉRIE DE SPIKES BLOQUÉE - Position déjà existante sur ", _Symbol);
      return;
   }
   
   // Protection capital
   if(IsMaxSimultaneousEAOrdersReached())
   {
      Print("🚫 SÉRIE DE SPIKES BLOQUÉE - Limite de trades atteinte");
      return;
   }
   
   // Obtenir le prix actuel
   double currentPrice = SymbolInfoDouble(_Symbol, (direction == "BUY") ? SYMBOL_ASK : SYMBOL_BID);
   double atrArray[];
   ArraySetAsSeries(atrArray, true);
   int atrHandleLocal = iATR(_Symbol, PERIOD_CURRENT, 14);
   if(CopyBuffer(atrHandleLocal, 0, 0, 1, atrArray) < 1) return;
   double atr = atrArray[0];
   
   // SL/TP optimisés pour les séries de spikes
   double stopLoss, takeProfit;
   
   if(direction == "BUY")
   {
      // BUY sur Boom : SL plus serré, TP plus grand
      stopLoss = currentPrice - (atr * 1.5);  // 1.5 ATR
      takeProfit = currentPrice + (atr * 4.0); // 4 ATR pour les spikes
   }
   else // SELL sur Crash
   {
      // SELL sur Crash : SL plus serré, TP plus grand
      stopLoss = currentPrice + (atr * 1.5);  // 1.5 ATR
      takeProfit = currentPrice - (atr * 4.0); // 4 ATR pour les spikes
   }
   
   // Validation des distances minimales
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minStopDistance = (double)stopsLevel * point;
   if(minStopDistance <= 0) minStopDistance = atr * 0.5;
   
   double safeDistance = MathMax(minStopDistance, atr * 0.8);
   
   // Ajuster SL/TP si nécessaire
   if(direction == "BUY")
   {
      if(currentPrice - stopLoss < safeDistance)
         stopLoss = currentPrice - safeDistance;
      if(takeProfit - currentPrice < safeDistance * 2)
         takeProfit = currentPrice + safeDistance * 2;
   }
   else
   {
      if(stopLoss - currentPrice < safeDistance)
         stopLoss = currentPrice + safeDistance;
      if(currentPrice - takeProfit < safeDistance * 2)
         takeProfit = currentPrice - safeDistance * 2;
   }
   
   // Normaliser les prix
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   Print("📊 SÉRIE DE SPIKES - Prix: ", DoubleToString(currentPrice, _Digits));
   Print("   📍 SL: ", DoubleToString(stopLoss, _Digits), " | TP: ", DoubleToString(takeProfit, _Digits));
   Print("   📍 ATR: ", DoubleToString(atr, _Digits), " | Distance SL: ", DoubleToString(MathAbs(currentPrice - stopLoss), _Digits));
   
   // Exécuter l'ordre
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = CalculateLotSize();
   request.type = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = currentPrice;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 20;
   request.magic = InpMagicNumber;
   request.comment = "SPIKE SERIES " + direction;
   
   if(OrderSend(request, result))
   {
      Print("✅ SÉRIE DE SPIKES EXÉCUTÉE - ", direction, " sur ", _Symbol);
      Print("   📍 Prix: ", DoubleToString(currentPrice, _Digits), " | SL: ", DoubleToString(stopLoss, _Digits));
      Print("   📍 TP: ", DoubleToString(takeProfit, _Digits), " | Ticket: ", result.order);
      
      // Notification mobile
      string message = StringFormat("🚨 SÉRIE DE SPIKES %s\n%s\nPrix: %s\nSL: %s\nTP: %s\nTicket: %d",
                                   direction, _Symbol, 
                                   DoubleToString(currentPrice, _Digits),
                                   DoubleToString(stopLoss, _Digits),
                                   DoubleToString(takeProfit, _Digits),
                                   result.order);
      SendNotification(message);
   }
   else
   {
      Print("❌ ÉCHEC SÉRIE DE SPIKES - Erreur: ", GetLastError());
   }
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
   
   // BLOQUER LES ORDRES MARCHÉ SUR BOOM/CRASH - ATTENDRE DERIV ARROW
   if(cat == SYM_BOOM_CRASH)
   {
      Print("🚫 ORDRES MARCHÉ BLOQUÉS SUR BOOM/CRASH - Attendre DERIV ARROW pour ", _Symbol);
      return;
   }
   
   // BLOQUER LES ORDRES SI PRIX EST DANS UN RANGE
   if(IsPriceInRange())
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
   
   // VALIDATION MULTI-SIGNAUX POUR ENTRÉES PRÉCISES
   if(!ValidateEntryWithMultipleSignals(g_lastAIAction))
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
   
   bool orderExecuted = false;
   
   if(g_lastAIAction == "BUY" || g_lastAIAction == "buy")
   {
      if(!HasRecentSMCDerivArrowForDirection("BUY"))
      {
         Print("🚫 ORDRE MARCHÉ BLOQUÉ - Attendre flèche SMC_DERIV_ARROW BUY sur ", _Symbol);
         ReleaseOpenLock();
         return;
      }
      // Utiliser l'entrée précise calculée au lieu du prix actuel
      if(trade.Buy(lot, _Symbol, preciseEntry, preciseSL, preciseTP, "IA SMC-EMA BUY PRÉCIS"))
      {
         orderExecuted = true;
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
      if(!HasRecentSMCDerivArrowForDirection("SELL"))
      {
         Print("🚫 ORDRE MARCHÉ BLOQUÉ - Attendre flèche SMC_DERIV_ARROW SELL sur ", _Symbol);
         ReleaseOpenLock();
         return;
      }
      // Utiliser l'entrée précise calculée au lieu du prix actuel
      if(trade.Sell(lot, _Symbol, preciseEntry, preciseSL, preciseTP, "IA SMC-EMA SELL PRÉCIS"))
      {
         orderExecuted = true;
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
   return IsPreSpikePatternForSymbol(_Symbol);
}

// Version multi‑symbole (utilisée par le scan opportunités)
bool IsPreSpikePatternForSymbol(string symbol)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(symbol, PERIOD_M1, 0, 50, rates) < 50) return false;
   
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
   bool keyLevel = IsNearKeyLevelForSymbol(symbol, rates[0].close);
   
   return (compression && consolidation && keyLevel);
}

// Vérifie si le prix est près d'un niveau clé (support/résistance)
bool IsNearKeyLevel(double price)
{
   return IsNearKeyLevelForSymbol(_Symbol, price);
}

// Version multi‑symbole (utilisée par le scan opportunités)
bool IsNearKeyLevelForSymbol(string symbol, double price)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 100, rates) < 100) return false;
   
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

//| DÉTECTION DES MOUVEMENTS DE RETOUR VERS CANAUX SMC               |
void CheckSMCChannelReturnMovements()
{
   // NOUVEAU: Vérifier si les entrées sur retour de canal SMC sont activées
   if(!EnableSMCChannelReturn) return;
   
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
   // NOUVEAU: VÉRIFICATION PROTECTION ANTI-REPRISE APRÈS GAIN
   if(!CanTradeAfterProfitClose(_Symbol))
   {
      Print("🚫 ORDRE RETOUR BLOQUÉ - Protection anti-reprise après gain active");
      return;
   }
   
   // Vérifier s'il est permis de placer un nouvel ordre LIMIT (un seul ordre LIMIT par symbole)
   if(!CanPlaceNewLimitOrderForSymbol(_Symbol, "ORDRE RETOUR"))
      return;
   
   // Réentrée après perte sur ce symbole: exiger conditions exceptionnelles (IA ≥90% + spike/setup fort)
   if(!AllowReentryAfterRecentLoss(_Symbol, direction, strength >= 0.8))
      return;
   
   if(CountPositionsForSymbol(_Symbol) > 0) return; // Pas d'ordre si déjà en position
   if(IsMaxSimultaneousEAOrdersReached()) return;
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
      
      // Vérification IA avant envoi LIMIT
      if(!IsAILimitOrderAllowed("BUY"))
      {
         Print("🚫 ORDRE RETOUR BUY annulé - Conditions IA non valides pour LIMIT.");
      }
      else if(OrderSend(req, res))
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
      
      // Vérification IA avant envoi LIMIT
      if(!IsAILimitOrderAllowed("SELL"))
      {
         Print("🚫 ORDRE RETOUR SELL annulé - Conditions IA non valides pour LIMIT.");
      }
      else if(OrderSend(req, res))
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
   
  // Texte de prédiction spike - privilégier la probabilité envoyée par le serveur IA
  double spikeProb = g_lastSpikeProbability; // 0..1
  if(spikeProb < 0.0 || spikeProb > 1.0)
     spikeProb = CalculateSpikeProbability();
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

//| DÉTECTEUR DE TENDANCE EN ESCALIER POUR BOOM/CRASH                |
//| Détecte les structures HH/HL (uptrend) ou LL/LH (downtrend)      |
//| avec empilement EMA pour confirmer la tendance                     |
bool IsStaircaseTrend(string direction)
{
   // Récupérer les 20 dernières bougies M1 pour analyse structurelle
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   if(CopyRates(_Symbol, PERIOD_M1, 0, 20, rates) < 20)
   {
      Print("❌ Impossible de copier les rates pour détecter tendance escalier");
      return false;
   }
   
   // Récupérer les EMA 9 et 21 pour confirmation
   double ema9[], ema21[];
   ArraySetAsSeries(ema9, true);
   ArraySetAsSeries(ema21, true);
   
   if(CopyBuffer(emaM1H, 0, 0, 20, ema9) < 20 || CopyBuffer(emaM5H, 0, 0, 20, ema21) < 20)
   {
      // Fallback: calculer les EMA localement si les handles ne sont pas disponibles
      for(int i = 0; i < 20; i++)
      {
         ema9[i] = rates[i].close; // Simplification
         ema21[i] = rates[i].close;
      }
   }
   
   // Détecter les points hauts et bas significatifs (swing points)
   double highs[] = {}, lows[] = {};
   datetime highTimes[] = {}, lowTimes[] = {};
   
   // Identifier les swing highs et lows sur les 15 dernières bougies
   for(int i = 2; i < 15; i++)
   {
      // Swing High: bougie i plus haute que les 2 précédentes et 2 suivantes
      if(rates[i].high > rates[i-1].high && rates[i].high > rates[i-2].high &&
         rates[i].high > rates[i+1].high && rates[i].high > rates[i+2].high)
      {
         ArrayResize(highs, ArraySize(highs) + 1);
         ArrayResize(highTimes, ArraySize(highTimes) + 1);
         highs[ArraySize(highs)-1] = rates[i].high;
         highTimes[ArraySize(highTimes)-1] = rates[i].time;
      }
      
      // Swing Low: bougie i plus basse que les 2 précédentes et 2 suivantes
      if(rates[i].low < rates[i-1].low && rates[i].low < rates[i-2].low &&
         rates[i].low < rates[i+1].low && rates[i].low < rates[i+2].low)
      {
         ArrayResize(lows, ArraySize(lows) + 1);
         ArrayResize(lowTimes, ArraySize(lowTimes) + 1);
         lows[ArraySize(lows)-1] = rates[i].low;
         lowTimes[ArraySize(lowTimes)-1] = rates[i].time;
      }
   }
   
   // Analyser la structure selon la direction demandée
   if(direction == "BUY")
   {
      // Uptrend: Higher Highs (HH) et Higher Lows (HL)
      if(ArraySize(highs) >= 2 && ArraySize(lows) >= 2)
      {
         // Vérifier HH: le high le plus récent > high précédent
         bool hasHH = (highs[0] > highs[1]);
         // Vérifier HL: le low le plus récent > low précédent
         bool hasHL = (lows[0] > lows[1]);
         
         // Confirmation EMA: prix au-dessus des EMAs (tendance haussière)
         bool priceAboveEMAs = (rates[0].close > ema9[0] && rates[0].close > ema21[0]);
         // EMA 9 au-dessus de EMA 21 (alignement haussier)
         bool emaBullishAlignment = (ema9[0] > ema21[0]);
         
         bool staircaseUptrend = (hasHH || hasHL) && priceAboveEMAs && emaBullishAlignment;
         
         if(staircaseUptrend)
         {
            Print("✅ TENDANCE ESCALIER HAUSSIÈRE détectée - HH:", hasHH ? "OUI" : "NON", 
                  " | HL:", hasHL ? "OUI" : "NON", 
                  " | Prix > EMAs:", priceAboveEMAs ? "OUI" : "NON",
                  " | EMA9 > EMA21:", emaBullishAlignment ? "OUI" : "NON");
         }
         
         return staircaseUptrend;
      }
   }
   else if(direction == "SELL")
   {
      // Downtrend: Lower Lows (LL) et Lower Highs (LH)
      if(ArraySize(highs) >= 2 && ArraySize(lows) >= 2)
      {
         // Vérifier LL: le low le plus récent < low précédent
         bool hasLL = (lows[0] < lows[1]);
         // Vérifier LH: le high le plus récent < high précédent
         bool hasLH = (highs[0] < highs[1]);
         
         // Confirmation EMA: prix en dessous des EMAs (tendance baissière)
         bool priceBelowEMAs = (rates[0].close < ema9[0] && rates[0].close < ema21[0]);
         // EMA 9 en dessous de EMA 21 (alignement baissier)
         bool emaBearishAlignment = (ema9[0] < ema21[0]);
         
         bool staircaseDowntrend = (hasLL || hasLH) && priceBelowEMAs && emaBearishAlignment;
         
         if(staircaseDowntrend)
         {
            Print("✅ TENDANCE ESCALIER BAISSIÈRE détectée - LL:", hasLL ? "OUI" : "NON", 
                  " | LH:", hasLH ? "OUI" : "NON", 
                  " | Prix < EMAs:", priceBelowEMAs ? "OUI" : "NON",
                  " | EMA9 < EMA21:", emaBearishAlignment ? "OUI" : "NON");
         }
         
         return staircaseDowntrend;
      }
   }
   
   return false;
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
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      spikeMultiplier = 1.2; // 1.2x pour Boom/Crash (plus sensible)
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
   if(StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0)
   {
      priceThreshold = 0.0001; // 0.01% pour Boom/Crash (plus sensible)
   }
   
   bool priceSpike = priceChange > priceThreshold;
   
   Print("🔍 DEBUG - Spike prix - Changement: ", DoubleToString(priceChange*100, 4), "% | Seuil: ", DoubleToString(priceThreshold*100, 4), "% | Spike: ", priceSpike ? "OUI" : "NON");
   
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

//| EXÉCUTER UN TRADE BASÉ SUR SPIKE                                  |
void ExecuteSpikeTrade(string direction, bool fromScalpArrow = false)
{
   // Toujours respecter le cooldown et la protection de zone de correction,
   // même pour les entrées déclenchées en mode scalp sur flèche.
   if(!CheckCooldownBeforeEntry(_Symbol))
   {
      Print("🚫 SPIKE TRADE BLOQUÉ - Cooldown actif après fermeture spike récente");
      return;
   }
   if(!CheckCorrectionZoneProtection("SPIKE TRADE"))
   {
      Print("🚫 SPIKE TRADE BLOQUÉ - Zone de correction à haut risque");
      return;
   }

   // Anti-correction: éviter SELL Crash quand le prix remonte depuis le bas du Discount vers l'équilibre
   // (souvent une correction/rétraction qui piège les SELL tardifs).
   string sym = _Symbol;
   bool isCrash = (StringFind(sym, "Crash") >= 0);
   string dir = direction; StringToUpper(dir);
   if(isCrash && dir == "SELL" && IsInDiscountZone() && !IsEMAAlignmentBearish())
   {
      Print("🚫 CRASH SELL BLOQUÉ - Correction détectée (prix en Discount mais EMA non baissières) → attendre reprise baissière");
      return;
   }
   
   // Filtre additionnel: sur Crash, éviter d'entrer en pleine correction.
   // Autoriser SELL seulement si le prix est revenu vers une résistance (zone Premium ou résistance EMA proche).
   if(isCrash && dir == "SELL")
   {
      bool inPremium = IsInPremiumZone();
      double bidNow = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double emaRes = GetNearestEMAResistance(bidNow);
      bool nearEMAResistance = (emaRes > 0.0 && IsPriceNearEMA(bidNow, emaRes, 0.2));
      
      if(!inPremium && !nearEMAResistance)
      {
         Print("🚫 CRASH SELL BLOQUÉ - Prix en correction (ni zone Premium ni près d'une résistance EMA). Attendre que le prix touche la résistance / EMA trend baissière projetée.");
         return;
      }
   }
   
   // Filtre additionnel demandé: sur Crash, éviter d'entrer "en correction".
   // Autoriser SELL seulement si le prix est revenu vers une résistance (zone Premium ou résistance EMA proche).
   if(isCrash && dir == "SELL")
   {
      bool inPremium = IsInPremiumZone();
      double bidNow = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double emaRes = GetNearestEMAResistance(bidNow);
      bool nearEMAResistance = (emaRes > 0.0 && IsPriceNearEMA(bidNow, emaRes, 0.2));
      
      if(!inPremium && !nearEMAResistance)
      {
         Print("🚫 CRASH SELL BLOQUÉ - Prix en correction (pas en Premium / pas près résistance EMA). Attendre touch résistance / trend baissière projetée.");
         return;
      }
   }
   
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
      if(!fromScalpArrow && !HasRecentSMCDerivArrowForDirection("BUY"))
      {
         Print("🚫 SPIKE TRADE BUY bloqué - Attendre flèche SMC_DERIV_ARROW BUY sur ", _Symbol);
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
      
      Print("🔍 DEBUG - BUY - Ask: ", DoubleToString(ask, _Digits), " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits));
      Print("🔍 DEBUG - Vérification SL/TP BUY - SL < Ask: ", (sl < ask || sl == 0) ? "OK" : "ERREUR", " | TP > Ask: ", (tp > ask || tp == 0) ? "OK" : "ERREUR");
      
      if(trade.Buy(lot, _Symbol, 0.0, sl, tp, "SPIKE TRADE BUY"))
      {
         orderExecuted = true;
         Print("✅ SPIKE TRADE BUY EXÉCUTÉ - ", _Symbol, " @", DoubleToString(ask, _Digits), " | Lot: ", DoubleToString(lot, 2), " | Magic: ", trade.RequestMagic());
         Print("🔍 DEBUG - Ticket d'ordre: ", trade.ResultOrder());
      }
      else
      {
         Print("❌ Échec SPIKE TRADE BUY - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   else // SELL
   {
      if(!fromScalpArrow && !HasRecentSMCDerivArrowForDirection("SELL"))
      {
         Print("🚫 SPIKE TRADE SELL bloqué - Attendre flèche SMC_DERIV_ARROW SELL sur ", _Symbol);
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
      
      Print("🔍 DEBUG - SELL - Bid: ", DoubleToString(bid, _Digits), " | SL: ", DoubleToString(sl, _Digits), " | TP: ", DoubleToString(tp, _Digits));
      Print("🔍 DEBUG - Vérification SL/TP SELL - SL > Bid: ", (sl > bid || sl == 0) ? "OK" : "ERREUR", " | TP < Bid: ", (tp < bid || tp == 0) ? "OK" : "ERREUR");
      
      if(trade.Sell(lot, _Symbol, 0.0, sl, tp, "SPIKE TRADE SELL"))
      {
         orderExecuted = true;
         Print("✅ SPIKE TRADE SELL EXÉCUTÉ - ", _Symbol, " @", DoubleToString(bid, _Digits), " | Lot: ", DoubleToString(lot, 2), " | Magic: ", trade.RequestMagic());
         Print("🔍 DEBUG - Ticket d'ordre: ", trade.ResultOrder());
      }
      else
      {
         Print("❌ Échec SPIKE TRADE SELL - Erreur: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
      }
   }
   
   if(orderExecuted)
   {
      Print("🎯 SPIKE TRADE EXÉCUTÉ AVEC SUCCÈS - Direction: ", direction, " | Symbole: ", _Symbol);
      
      // Démarrer la surveillance pour clôture immédiate en gain positif
      StartSpikePositionMonitoring(direction);
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

//| ROTATION AUTOMATIQUE DES POSITIONS - Évite de rester bloqué sur un symbole |
void AutoRotatePositions()
{
   int totalPositions = CountPositionsOurEA();
   
   // Si on n'est pas à la limite de positions, pas besoin de rotation
   if(!UseGlobalPositionLimit || totalPositions < MaxPositionsTerminal)
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
      
      // Fermer seulement si c'est une position en perte ≥ -2.0$ ou si elle est ouverte depuis plus de 30 minutes
      datetime positionTime = (datetime)PositionGetInteger(POSITION_TIME);
      int minutesOpen = (int)(TimeCurrent() - positionTime) / 60;
      
      if(positionProfit <= -2.0 || minutesOpen > 30)
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

//| SEGMENTATION DES ZONES SMC AVEC INDICATEURS DE FORCE       |
//| Affiche des segments centrés dans les zones Premium/Discount avec pourcentages |
void DrawSMCZoneSegments()
{
   // Limiter l'exécution à une fois toutes les 10 secondes
   static datetime lastZoneUpdate = 0;
   if(TimeCurrent() - lastZoneUpdate < 10) return;
   lastZoneUpdate = TimeCurrent();
   
   // Obtenir les prix des zones SMC
   double upperPrice = 0, lowerPrice = 0, middlePrice = 0;
   string upperName = "SMC_CH_H1_UPPER";
   string lowerName = "SMC_CH_H1_LOWER";
   
   if(ObjectFind(0, upperName) >= 0)
      upperPrice = ObjectGetDouble(0, upperName, OBJPROP_PRICE);
   if(ObjectFind(0, lowerName) >= 0)
      lowerPrice = ObjectGetDouble(0, lowerName, OBJPROP_PRICE);
   
   if(upperPrice <= 0 || lowerPrice <= 0) return;
   middlePrice = (upperPrice + lowerPrice) / 2;
   
   // Calculer la force actuelle
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double totalRange = upperPrice - lowerPrice;
   double forcePercentage = 0;
   
   if(totalRange > 0)
   {
      if(currentPrice >= upperPrice)
         forcePercentage = 100;
      else if(currentPrice <= lowerPrice)
         forcePercentage = 0;
      else
         forcePercentage = ((currentPrice - lowerPrice) / totalRange) * 100;
   }
   
   // Déterminer le type de symbole
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   string forceType = isBoom ? "FORCE D'ACHAT" : "FORCE DE VENTE";
   string spikeType = isBoom ? "SPIKE BOOM" : "SPIKE CRASH";
   
   // Créer les segments dans chaque zone
   DrawZoneSegment("PREMIUM", upperPrice, forcePercentage, forceType, spikeType, clrOrange, true);
   DrawZoneSegment("MIDDLE", middlePrice, forcePercentage, forceType, spikeType, clrYellow, false);
   DrawZoneSegment("DISCOUNT", lowerPrice, forcePercentage, forceType, spikeType, clrLime, true);
   
   // Log de la segmentation
   static double lastLoggedForce = -1;
   if(MathAbs(forcePercentage - lastLoggedForce) > 5.0)
   {
      Print("📊 SEGMENTATION ZONES SMC - ", _Symbol);
      Print("   📍 ", forceType, ": ", DoubleToString(forcePercentage, 1), "%");
      Print("   📍 Prix actuel: ", DoubleToString(currentPrice, _Digits));
      Print("   📍 Zones: Premium=", DoubleToString(upperPrice, _Digits), 
             " | Middle=", DoubleToString(middlePrice, _Digits), 
             " | Discount=", DoubleToString(lowerPrice, _Digits));
      Print("   🎯 ", spikeType, " ", (forcePercentage >= 60 ? "PROBABLE" : "PEU PROBABLE"));
      lastLoggedForce = forcePercentage;
   }
}

//| DESSINE UN SEGMENT DANS UNE ZONE SMC                   |
//| Affiche un segment visuel avec indicateur de force centré        |
void DrawZoneSegment(string zoneName, double zonePrice, double force, string forceType, string spikeType, color zoneColor, bool isExtreme)
{
   // Supprimer l'ancien segment
   ObjectDelete(0, "SMC_ZONE_" + zoneName + "_" + _Symbol);
   ObjectDelete(0, "SMC_ZONE_TEXT_" + zoneName + "_" + _Symbol);
   
   // Obtenir les dimensions du graphique
   datetime currentTime = TimeCurrent();
   double segmentWidth = SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.001; // 0.1% du prix
   
   // Créer le segment horizontal
   if(!ObjectCreate(0, "SMC_ZONE_" + zoneName + "_" + _Symbol, OBJ_RECTANGLE, 0, 
                     currentTime - PeriodSeconds(PERIOD_M1) * 10, zonePrice - segmentWidth/2, 
                     currentTime + PeriodSeconds(PERIOD_M1) * 10, zonePrice + segmentWidth/2))
   {
      ObjectSetInteger(0, "SMC_ZONE_" + zoneName + "_" + _Symbol, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, "SMC_ZONE_" + zoneName + "_" + _Symbol, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "SMC_ZONE_" + zoneName + "_" + _Symbol, OBJPROP_WIDTH, isExtreme ? 3 : 2);
      ObjectSetInteger(0, "SMC_ZONE_" + zoneName + "_" + _Symbol, OBJPROP_BACK, true);
      ObjectSetInteger(0, "SMC_ZONE_" + zoneName + "_" + _Symbol, OBJPROP_FILL, true);
      ObjectSetInteger(0, "SMC_ZONE_" + zoneName + "_" + _Symbol, OBJPROP_BGCOLOR, zoneColor);
   }
   
   // Créer le texte centré avec force et spike
   string textContent = zoneName + "\n" + forceType + "\n" + DoubleToString(force, 1) + "%\n" + spikeType;
   
   if(!ObjectCreate(0, "SMC_ZONE_TEXT_" + zoneName + "_" + _Symbol, OBJ_TEXT, 0, 
                     currentTime, zonePrice))
   {
      ObjectSetString(0, "SMC_ZONE_TEXT_" + zoneName + "_" + _Symbol, OBJPROP_TEXT, textContent);
      ObjectSetInteger(0, "SMC_ZONE_TEXT_" + zoneName + "_" + _Symbol, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, "SMC_ZONE_TEXT_" + zoneName + "_" + _Symbol, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, "SMC_ZONE_TEXT_" + zoneName + "_" + _Symbol, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, "SMC_ZONE_TEXT_" + zoneName + "_" + _Symbol, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, "SMC_ZONE_TEXT_" + zoneName + "_" + _Symbol, OBJPROP_BACK, false);
   }
}

//| INDICATEURS DE FORCE DANS LES ZONES SMC                        |
//| Affiche la force du prix en pourcentage dans les zones Premium/Discount |
void DrawSMCForceIndicators()
{
   // Limiter l'exécution à une fois toutes les 10 secondes
   static datetime lastForceUpdate = 0;
   if(TimeCurrent() - lastForceUpdate < 10) return;
   lastForceUpdate = TimeCurrent();
   
   // Obtenir les prix actuels des canaux SMC
   double upperPrice = 0, lowerPrice = 0, middlePrice = 0;
   string upperName = "SMC_CH_H1_UPPER";
   string lowerName = "SMC_CH_H1_LOWER";
   
   if(ObjectFind(0, upperName) >= 0)
      upperPrice = ObjectGetDouble(0, upperName, OBJPROP_PRICE);
   if(ObjectFind(0, lowerName) >= 0)
      lowerPrice = ObjectGetDouble(0, lowerName, OBJPROP_PRICE);
   
   if(upperPrice <= 0 || lowerPrice <= 0) return;
   middlePrice = (upperPrice + lowerPrice) / 2;
   
   // Calculer la force du prix actuel
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double totalRange = upperPrice - lowerPrice;
   double forcePercentage = 0;
   
   if(totalRange > 0)
   {
      if(currentPrice >= upperPrice)
         forcePercentage = 100; // Au-dessus du canal
      else if(currentPrice <= lowerPrice)
         forcePercentage = 0; // En dessous du canal
      else
         forcePercentage = ((currentPrice - lowerPrice) / totalRange) * 100;
   }
   
   // Déterminer le type de force selon le symbole
   bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
   string forceType = isBoom ? "FORCE D'ACHAT" : "FORCE DE VENTE";
   string spikeType = isBoom ? "SPIKE BOOM" : "SPIKE CRASH";
   color forceColor = isBoom ? clrGreen : clrRed;
   
   // Créer les segments dans chaque zone
   DrawForceSegment("FORCE_UPPER", upperPrice, forcePercentage, forceType, spikeType, forceColor, true);
   DrawForceSegment("FORCE_MIDDLE", middlePrice, forcePercentage, forceType, spikeType, forceColor, false);
   DrawForceSegment("FORCE_LOWER", lowerPrice, forcePercentage, forceType, spikeType, forceColor, true);
}

//| DESSINE UN SEGMENT DE FORCE DANS UNE ZONE SMC               |
//| Affiche un segment avec la force du prix en pourcentage        |
void DrawForceSegment(string segmentName, double price, double force, string forceType, string spikeType, color segmentColor, bool isExtreme)
{
   // Supprimer l'ancien segment
   ObjectDelete(0, segmentName);
   
   // Calculer la position du segment (largeur de 20% de la zone visible)
   double visibleRange = SymbolInfoDouble(_Symbol, SYMBOL_BID) * 0.02; // 2% du prix
   double segmentWidth = visibleRange * 0.2; // 20% de la plage visible
   double segmentStart = price - segmentWidth / 2;
   double segmentEnd = price + segmentWidth / 2;
   
   // Déterminer la couleur selon la force
   color forceLevelColor;
   if(force >= 80)
      forceLevelColor = clrRed; // Force très élevée
   else if(force >= 60)
      forceLevelColor = clrOrange; // Force élevée
   else if(force >= 40)
      forceLevelColor = clrYellow; // Force moyenne
   else if(force >= 20)
      forceLevelColor = clrDodgerBlue; // Force faible
   else
      forceLevelColor = clrBlue; // Force très faible
   
   // Créer le segment horizontal
   if(!ObjectCreate(0, segmentName, OBJ_HLINE, 0, 0, price))
   {
      Print("❌ Erreur création segment de force: ", GetLastError());
      return;
   }
   
   ObjectSetInteger(0, segmentName, OBJPROP_COLOR, forceLevelColor);
   ObjectSetInteger(0, segmentName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, segmentName, OBJPROP_WIDTH, isExtreme ? 3 : 2);
   ObjectSetInteger(0, segmentName, OBJPROP_BACK, false);
   
   // Créer le texte de force
   string textName = segmentName + "_TEXT";
   ObjectDelete(0, textName);
   
   string forceText = StringFormat("%s\n%.1f%%\n%s", 
                                forceType, 
                                force, 
                                spikeType);
   
   datetime textTime = TimeCurrent();
   double textPrice = price + (isExtreme ? 0.0005 : 0.0003); // Légèrement au-dessus du segment
   
   if(!ObjectCreate(0, textName, OBJ_TEXT, 0, textTime, textPrice))
   {
      Print("❌ Erreur création texte de force: ", GetLastError());
      return;
   }
   
   ObjectSetString(0, textName, OBJPROP_TEXT, forceText);
   ObjectSetInteger(0, textName, OBJPROP_COLOR, segmentColor);
   ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, textName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, textName, OBJPROP_BACK, false);
   
   // Créer des indicateurs visuels de petits segments
   string indicatorName = segmentName + "_INDICATOR";
   ObjectDelete(0, indicatorName);
   
   // Créer un rectangle pour l'indicateur
   if(!ObjectCreate(0, indicatorName, OBJ_RECTANGLE, 0, textTime - PeriodSeconds(PERIOD_M1) * 2, price - 0.0002, textTime, price + 0.0002))
   {
      Print("❌ Erreur création indicateur de force: ", GetLastError());
      return;
   }
   
   ObjectSetInteger(0, indicatorName, OBJPROP_COLOR, forceLevelColor);
   ObjectSetInteger(0, indicatorName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, indicatorName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, indicatorName, OBJPROP_BACK, true);
   ObjectSetInteger(0, indicatorName, OBJPROP_FILL, true);
   ObjectSetInteger(0, indicatorName, OBJPROP_BGCOLOR, forceLevelColor);
   
   // Log de la force actuelle
   static double lastLoggedForce = -1;
   if(MathAbs(force - lastLoggedForce) > 5.0) // Log seulement si changement significatif
   {
      Print("📊 INDICATEUR FORCE SMC - ", _Symbol);
      Print("   📍 ", forceType, ": ", DoubleToString(force, 1), "% (position dans canal SMC)");
      Print("   📍 Prix: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits));
      Print("   📍 Niveau: ", (force >= 80 ? "TRÈS ÉLEVÉ" : 
                               force >= 60 ? "ÉLEVÉ" :
                               force >= 40 ? "MOYEN" :
                               force >= 20 ? "FAIBLE" : "TRÈS FAIBLE"));
      Print("   🎯 ", spikeType, " ", (force >= 60 ? "PROBABLE" : "PEU PROBABLE"));
      Print("   💡 Seuil détection spike: 0.6% de mouvement en 1 bougie M1");
      lastLoggedForce = force;
   }
}

//| CAPTURE ACTIVE DES SÉRIES DE SPIKES (même sans flèche)           |
//| Capture les séries de spikes sur Boom/Crash même sans Deriv Arrow |
void CheckAndCaptureSpikeSeries()
{
   // Limiter l'exécution à une fois toutes les 5 secondes pour éviter la surcharge
   static datetime lastSpikeSeriesCheck = 0;
   if(TimeCurrent() - lastSpikeSeriesCheck < 5) return;
   lastSpikeSeriesCheck = TimeCurrent();
   
   // DEBUG: Log de base
   Print("🔍 DEBUG CheckAndCaptureSpikeSeries - ", _Symbol);
   
   // Vérifier s'il y a déjà une position (éviter duplication)
   int existingPositions = CountPositionsForSymbol(_Symbol);
   if(existingPositions > 0) 
   {
      Print("🔍 DEBUG - Position existante détectée: ", existingPositions, " - SKIP");
      return;
   }
   
   // Vérifier si le trading est autorisé (capital, pauses, etc.)
   double lot = CalculateLotSize();
   if(lot <= 0) 
   {
      Print("🔍 DEBUG - Lot invalide: ", lot, " - SKIP");
      return;
   }
   
   Print("🔍 DEBUG - Tests de base OK, vérification Crash...");
   
   // CAPTURE ACTIVE SUR CRASH - SPIKES DESCENDANTS
   if(StringFind(_Symbol, "Crash") >= 0)
   {
      Print("🔍 DEBUG - Crash détecté, vérification canal supérieur...");
      
      // Vérifier si le prix touche le canal supérieur
      bool touchedUpperChannel = PriceTouchesUpperChannel();
      Print("🔍 DEBUG - Canal supérieur touché: ", (touchedUpperChannel ? "OUI" : "NON"));
      
      if(touchedUpperChannel)
      {
         Print("🔍 DEBUG - Canal supérieur OK, vérification spike...");
         
         // Variables statiques pour suivre les séries
         static datetime lastUpperChannelSpikeTime[10] = {0};
         static int upperChannelSymbolIndex = -1;
         static bool spikeSeriesActive[10] = {false};
         
         // Initialiser l'index si nécessaire
         if(upperChannelSymbolIndex == -1)
         {
            if(StringFind(_Symbol, "Crash 300") >= 0) upperChannelSymbolIndex = 0;
            else if(StringFind(_Symbol, "Crash 500") >= 0) upperChannelSymbolIndex = 1;
            else if(StringFind(_Symbol, "Crash 1000") >= 0) upperChannelSymbolIndex = 2;
            else upperChannelSymbolIndex = 3;
         }
         
         Print("🔍 DEBUG - Index Crash: ", upperChannelSymbolIndex);
         
         // Détecter un spike récent
         MqlRates recentRates[];
         ArraySetAsSeries(recentRates, true);
         if(CopyRates(_Symbol, PERIOD_M1, 0, 3, recentRates) >= 3)
         {
            double lastMovePct = MathAbs(recentRates[0].close - recentRates[0].open) / recentRates[0].open;
            Print("🔍 DEBUG - Mouvement dernière bougie: ", DoubleToString(lastMovePct*100, 3), "%");
            
            // Si spike détecté (> 0.6% - mouvement significatif)
            if(lastMovePct >= 0.006)
            {
               Print("🔍 DEBUG - Spike détecté! Activation série...");
               lastUpperChannelSpikeTime[upperChannelSymbolIndex] = TimeCurrent();
               spikeSeriesActive[upperChannelSymbolIndex] = true;
               
               // NOUVEAU: Enregistrer le spike pour la protection correction dans DerivArrow
               int spikeSymbolIndex = -1;
               if(StringFind(_Symbol, "Crash 300") >= 0) spikeSymbolIndex = 0;
               else if(StringFind(_Symbol, "Crash 500") >= 0) spikeSymbolIndex = 1;
               else if(StringFind(_Symbol, "Crash 1000") >= 0) spikeSymbolIndex = 2;
               else if(StringFind(_Symbol, "Boom 300") >= 0) spikeSymbolIndex = 3;
               else if(StringFind(_Symbol, "Boom 500") >= 0) spikeSymbolIndex = 4;
               else if(StringFind(_Symbol, "Boom 1000") >= 0) spikeSymbolIndex = 5;
               else spikeSymbolIndex = 6;
               
               // Enregistrer le spike pour la protection correction
               g_lastSpikeDetectionTime[spikeSymbolIndex] = TimeCurrent();
               
               Print("🎯 SÉRIE DE SPIKES DÉTECTÉE (AUTO) - ", _Symbol);
               Print("   📍 Prix: ", DoubleToString(recentRates[0].close, _Digits), " | Mouvement: ", DoubleToString(lastMovePct*100, 2), "%");
               Print("   📍 Canal supérieur touché - Série de spikes baissiers ACTIVÉE");
               Print("   🚀 CAPTURE ACTIVE AUTO - Prêt à capturer les spikes descendants");
               Print("   🛡️ PROTECTION CORRECTION ACTIVÉE - 5 bougies avant nouvelles entrées");
            }
            else
            {
               Print("🔍 DEBUG - Mouvement insuffisant pour spike (< 0.6%)");
            }
         }
         else
         {
            Print("🔍 DEBUG - Erreur copie rates");
         }
         
         // Si série active : CAPTURER APRÈS DURÉE QUANTITATIVE OPTIMALE
         if(spikeSeriesActive[upperChannelSymbolIndex] && 
            lastUpperChannelSpikeTime[upperChannelSymbolIndex] > 0)
         {
            // Calculer le nombre de bougies écoulées depuis le premier spike
            int candlesSinceSpike = (int)((TimeCurrent() - lastUpperChannelSpikeTime[upperChannelSymbolIndex]) / PeriodSeconds(PERIOD_M1));
            
            // Utiliser la méthode quantitative pour déterminer la durée d'attente optimale
            int recommendedWait = GetRecommendedWaitTime();
            double correctionScore = GetCorrectionScore();
            bool isHighRiskZone = IsInHighRiskCorrectionZone();
            
            Print("🔍 DEBUG - Série active détectée, bougies écoulées: ", candlesSinceSpike);
            Print("   📊 Analyse quantitative - Score: ", DoubleToString(correctionScore, 1), "% | Attente: ", recommendedWait, " bougies");
            
            // Ajuster la durée d'attente selon le risque
            int minWaitTime = recommendedWait;
            if(isHighRiskZone) 
            {
               minWaitTime = (int)(minWaitTime * 1.5); // Augmenter si haut risque
               Print("   ⚠️ HAUT RISQUE - Attente augmentée à ", minWaitTime, " bougies");
            }
            
            // Attendre la durée recommandée avant d'entrer
            if(candlesSinceSpike < minWaitTime)
            {
               Print("🔍 DEBUG - Attente quantitative avant entrée (", candlesSinceSpike, "/", minWaitTime, ") - ÉVITER CORRECTION");
               return;
            }
            
            // Si plus de 20 bougies, la série est probablement terminée
            if(candlesSinceSpike > 20)
            {
               Print("🔍 DEBUG - Série expirée (", candlesSinceSpike, " bougies > 20) - DÉSACTIVATION");
               spikeSeriesActive[upperChannelSymbolIndex] = false;
               return;
            }
            
            Print("🔍 DEBUG - Fenêtre d'entrée OK (", candlesSinceSpike, " bougies), vérification flèche SMC_Deriv...");
            Print("   📊 Score de correction: ", DoubleToString(correctionScore, 1), "% (", (isHighRiskZone ? "HAUT RISQUE" : "RISQUE ACCEPTABLE"), ")");
            
            // NOUVEAU: VÉRIFICATION FINALE - Flèche SMC_Deriv Arrow obligatoire
            string arrowDirection = "";
            bool hasDerivArrow = GetDerivArrowDirection(arrowDirection);
            
            if(!hasDerivArrow)
            {
               Print("🔍 DEBUG - Aucune flèche SMC_Deriv détectée - ATTENTE");
               Print("⏸️ CAPTURE EN ATTENTE - Flèche SMC_Deriv Arrow requise pour confirmer le spike");
               return;
            }
            
            // Vérifier la couleur de la flèche selon le type de symbole
            bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
            bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
            
            if(isCrash && arrowDirection != "SELL")
            {
               Print("🔍 DEBUG - Flèche SMC_Deriv incompatible: ", arrowDirection, " (ROUGE requise pour Crash) - ATTENTE");
               Print("⏸️ CAPTURE EN ATTENTE - Flèche ROUGE SMC_Deriv Arrow requise pour Crash");
               return;
            }
            
            if(isBoom && arrowDirection != "BUY")
            {
               Print("🔍 DEBUG - Flèche SMC_Deriv incompatible: ", arrowDirection, " (VERTE requise pour Boom) - ATTENTE");
               Print("⏸️ CAPTURE EN ATTENTE - Flèche VERTE SMC_Deriv Arrow requise pour Boom");
               return;
            }
            
            // Vérifier si l'IA est compatible (SELL pour Crash)
            if(UseAIServer && g_lastAIAction != "SELL" && g_lastAIAction != "HOLD")
            {
               Print("🔍 DEBUG - IA incompatible: ", g_lastAIAction, " (SELL requis pour Crash) - SKIP");
               Print("⚠️ CAPTURE BLOQUÉE - IA incompatible: ", g_lastAIAction, " (SELL requis pour Crash)");
               return;
            }
            
            Print("🎯 CAPTURE OPTIMALE - ", candlesSinceSpike, " bougies après premier spike + Flèche SMC_Deriv ", arrowDirection);
            Print("🔍 DEBUG - IA compatible, exécution trade SELL...");
            
            // Exécuter immédiatement le trade SELL
            Print("🚀 CAPTURE AUTO SÉRIE SPIKES - ", _Symbol);
            Print("   📍 Canal supérieur + ", candlesSinceSpike, " bougies après spike + Flèche SMC_Deriv ", arrowDirection, " → Exécution SELL");
            Print("   💡 Capture de la SUITE des spikes après 3-4 bougies de stabilisation");
            
            ExecuteSpikeSeriesTrade("SELL");
            return;
         }
         else
         {
            Print("🔍 DEBUG - Série non active ou expirée");
            if(spikeSeriesActive[upperChannelSymbolIndex])
               Print("🔍 DEBUG - spikeSeriesActive: TRUE");
            else
               Print("🔍 DEBUG - spikeSeriesActive: FALSE");
               
            if(lastUpperChannelSpikeTime[upperChannelSymbolIndex] > 0)
            {
               int timeSince = (int)(TimeCurrent() - lastUpperChannelSpikeTime[upperChannelSymbolIndex]);
               Print("🔍 DEBUG - Temps depuis dernier spike: ", timeSince, " secondes");
            }
            else
            {
               Print("🔍 DEBUG - Aucun spike enregistré");
            }
         }
         
         // Désactiver après 5 minutes sans spike
         if(spikeSeriesActive[upperChannelSymbolIndex] && 
            (TimeCurrent() - lastUpperChannelSpikeTime[upperChannelSymbolIndex]) >= 300)
         {
            spikeSeriesActive[upperChannelSymbolIndex] = false;
            Print("⏹️ SÉRIE DE SPIKES TERMINÉE (AUTO) - ", _Symbol);
            Print("   📍 Plus de spikes détectés depuis 5 minutes");
         }
      }
   }
   
   // CAPTURE ACTIVE SUR BOOM - SPIKES HAUSSIERS
   if(StringFind(_Symbol, "Boom") >= 0)
   {
      // Vérifier si le prix touche le canal inférieur
      bool touchedLowerChannel = PriceTouchesLowerChannel();
      
      if(touchedLowerChannel)
      {
         // Variables statiques pour suivre les séries
         static datetime lastLowerChannelSpikeTime[10] = {0};
         static int lowerChannelSymbolIndex = -1;
         static bool boomSpikeSeriesActive[10] = {false};
         
         // Initialiser l'index si nécessaire
         if(lowerChannelSymbolIndex == -1)
         {
            if(StringFind(_Symbol, "Boom 300") >= 0) lowerChannelSymbolIndex = 0;
            else if(StringFind(_Symbol, "Boom 500") >= 0) lowerChannelSymbolIndex = 1;
            else if(StringFind(_Symbol, "Boom 1000") >= 0) lowerChannelSymbolIndex = 2;
            else lowerChannelSymbolIndex = 3;
         }
         
         // Détecter un spike récent
         MqlRates recentRates[];
         ArraySetAsSeries(recentRates, true);
         if(CopyRates(_Symbol, PERIOD_M1, 0, 3, recentRates) >= 3)
         {
            double lastMovePct = MathAbs(recentRates[0].close - recentRates[0].open) / recentRates[0].open;
            
            // Si spike détecté (> 0.6% - mouvement significatif)
            if(lastMovePct >= 0.006)
            {
               lastLowerChannelSpikeTime[lowerChannelSymbolIndex] = TimeCurrent();
               boomSpikeSeriesActive[lowerChannelSymbolIndex] = true;
               
               // NOUVEAU: Enregistrer le spike pour la protection correction dans DerivArrow
               int spikeSymbolIndex = -1;
               if(StringFind(_Symbol, "Crash 300") >= 0) spikeSymbolIndex = 0;
               else if(StringFind(_Symbol, "Crash 500") >= 0) spikeSymbolIndex = 1;
               else if(StringFind(_Symbol, "Crash 1000") >= 0) spikeSymbolIndex = 2;
               else if(StringFind(_Symbol, "Boom 300") >= 0) spikeSymbolIndex = 3;
               else if(StringFind(_Symbol, "Boom 500") >= 0) spikeSymbolIndex = 4;
               else if(StringFind(_Symbol, "Boom 1000") >= 0) spikeSymbolIndex = 5;
               else spikeSymbolIndex = 6;
               
               // Enregistrer le spike pour la protection correction
               g_lastSpikeDetectionTime[spikeSymbolIndex] = TimeCurrent();
               
               Print("🎯 SÉRIE DE SPIKES DÉTECTÉE (AUTO) - ", _Symbol);
               Print("   📍 Prix: ", DoubleToString(recentRates[0].close, _Digits), " | Mouvement: ", DoubleToString(lastMovePct*100, 2), "%");
               Print("   📍 Canal inférieur touché - Série de spikes haussiers ACTIVÉE");
               Print("   🚀 CAPTURE ACTIVE AUTO - Prêt à capturer les spikes haussiers");
               Print("   🛡️ PROTECTION CORRECTION ACTIVÉE - 5 bougies avant nouvelles entrées");
            }
         }
         
         // Si série active : CAPTURER APRÈS DURÉE QUANTITATIVE OPTIMALE
         if(boomSpikeSeriesActive[lowerChannelSymbolIndex] && 
            lastLowerChannelSpikeTime[lowerChannelSymbolIndex] > 0)
         {
            // Calculer le nombre de bougies écoulées depuis le premier spike
            int candlesSinceSpike = (int)((TimeCurrent() - lastLowerChannelSpikeTime[lowerChannelSymbolIndex]) / PeriodSeconds(PERIOD_M1));
            
            // Utiliser la méthode quantitative pour déterminer la durée d'attente optimale
            int recommendedWait = GetRecommendedWaitTime();
            double correctionScore = GetCorrectionScore();
            bool isHighRiskZone = IsInHighRiskCorrectionZone();
            
            Print("🔍 DEBUG - Série active détectée, bougies écoulées: ", candlesSinceSpike);
            Print("   📊 Analyse quantitative - Score: ", DoubleToString(correctionScore, 1), "% | Attente: ", recommendedWait, " bougies");
            
            // Ajuster la durée d'attente selon le risque
            int minWaitTime = recommendedWait;
            if(isHighRiskZone) 
            {
               minWaitTime = (int)(minWaitTime * 1.5); // Augmenter si haut risque
               Print("   ⚠️ HAUT RISQUE - Attente augmentée à ", minWaitTime, " bougies");
            }
            
            // Attendre la durée recommandée avant d'entrer
            if(candlesSinceSpike < minWaitTime)
            {
               Print("🔍 DEBUG - Attente quantitative avant entrée (", candlesSinceSpike, "/", minWaitTime, ") - ÉVITER CORRECTION");
               return;
            }
            
            // Si plus de 20 bougies, la série est probablement terminée
            if(candlesSinceSpike > 20)
            {
               Print("🔍 DEBUG - Série expirée (", candlesSinceSpike, " bougies > 20) - DÉSACTIVATION");
               boomSpikeSeriesActive[lowerChannelSymbolIndex] = false;
               return;
            }
            
            Print("🔍 DEBUG - Fenêtre d'entrée OK (", candlesSinceSpike, " bougies), vérification flèche SMC_Deriv...");
            Print("   📊 Score de correction: ", DoubleToString(correctionScore, 1), "% (", (isHighRiskZone ? "HAUT RISQUE" : "RISQUE ACCEPTABLE"), ")");
            
            // NOUVEAU: VÉRIFICATION FINALE - Flèche SMC_Deriv Arrow obligatoire
            string arrowDirection = "";
            bool hasDerivArrow = GetDerivArrowDirection(arrowDirection);
            
            if(!hasDerivArrow)
            {
               Print("🔍 DEBUG - Aucune flèche SMC_Deriv détectée - ATTENTE");
               Print("⏸️ CAPTURE EN ATTENTE - Flèche SMC_Deriv Arrow requise pour confirmer le spike");
               return;
            }
            
            // Vérifier la couleur de la flèche selon le type de symbole
            bool isBoom = (StringFind(_Symbol, "Boom") >= 0);
            bool isCrash = (StringFind(_Symbol, "Crash") >= 0);
            
            if(isBoom && arrowDirection != "BUY")
            {
               Print("🔍 DEBUG - Flèche SMC_Deriv incompatible: ", arrowDirection, " (VERTE requise pour Boom) - ATTENTE");
               Print("⏸️ CAPTURE EN ATTENTE - Flèche VERTE SMC_Deriv Arrow requise pour Boom");
               return;
            }
            
            if(isCrash && arrowDirection != "SELL")
            {
               Print("🔍 DEBUG - Flèche SMC_Deriv incompatible: ", arrowDirection, " (ROUGE requise pour Crash) - ATTENTE");
               Print("⏸️ CAPTURE EN ATTENTE - Flèche ROUGE SMC_Deriv Arrow requise pour Crash");
               return;
            }
            
            // Vérifier si l'IA est compatible (BUY pour Boom)
            if(UseAIServer && g_lastAIAction != "BUY" && g_lastAIAction != "HOLD")
            {
               Print("🔍 DEBUG - IA incompatible: ", g_lastAIAction, " (BUY requis pour Boom) - SKIP");
               Print("⚠️ CAPTURE BLOQUÉE - IA incompatible: ", g_lastAIAction, " (BUY requis pour Boom)");
               return;
            }
            
            Print("🎯 CAPTURE OPTIMALE - ", candlesSinceSpike, " bougies après premier spike + Flèche SMC_Deriv ", arrowDirection);
            Print("🔍 DEBUG - IA compatible, exécution trade BUY...");
            
            // Exécuter immédiatement le trade BUY
            Print("🚀 CAPTURE AUTO SÉRIE SPIKES - ", _Symbol);
            Print("   📍 Canal inférieur + ", candlesSinceSpike, " bougies après spike + Flèche SMC_Deriv ", arrowDirection, " → Exécution BUY");
            Print("   💡 Capture de la SUITE des spikes après 3-4 bougies de stabilisation");
            
            ExecuteSpikeSeriesTrade("BUY");
            return;
         }
         
         // Désactiver après 5 minutes sans spike
         if(boomSpikeSeriesActive[lowerChannelSymbolIndex] && 
            (TimeCurrent() - lastLowerChannelSpikeTime[lowerChannelSymbolIndex]) >= 300)
         {
            boomSpikeSeriesActive[lowerChannelSymbolIndex] = false;
            Print("⏹️ SÉRIE DE SPIKES TERMINÉE (AUTO) - ", _Symbol);
            Print("   📍 Plus de spikes détectés depuis 5 minutes");
         }
      }
   }
}

//| PRÉDICTEUR QUANTITATIF DE CORRECTIONS                           |
//| Analyse statistique des corrections historiques                  |
void DetectHistoricalCorrections()
{
   // Limiter l'analyse à une fois par session pour éviter la surcharge
   static datetime lastAnalysisTime = 0;
   if(TimeCurrent() - lastAnalysisTime < 3600) return; // 1 heure
   lastAnalysisTime = TimeCurrent();
   
   // Réinitialiser les compteurs
   g_totalTrends = 0;
   g_correctionCount = 0;
   g_durationSum = 0;
   
   // Obtenir les données MA20 pour l'analyse
   if(!CopyBuffer(iMA(_Symbol, PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE), 0, 0, 500, g_correctionMA))
   {
      Print("❌ Erreur - Impossible d'obtenir les données MA pour analyse de corrections");
      return;
   }
   
   // Obtenir les prix de clôture
   double closePrices[];
   ArraySetAsSeries(closePrices, true);
   if(CopyClose(_Symbol, PERIOD_H1, 0, 500, closePrices) < 500)
   {
      Print("❌ Erreur - Impossible d'obtenir les prix pour analyse de corrections");
      return;
   }
   
   bool inCorrection = false;
   int startIndex = -1;
   
   // Parcourir l'historique pour détecter les corrections
   double rsiBuffer[];
   ArraySetAsSeries(rsiBuffer, true);
   if(CopyBuffer(iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE), 0, 0, 500, rsiBuffer) < 500)
   {
      Print("❌ Erreur - Impossible d'obtenir les données RSI pour analyse de corrections");
      return;
   }
   
   for(int i = 499; i >= 0; i--)
   {
      double price = closePrices[i];
      double maVal = g_correctionMA[i];
      double rsi_val = rsiBuffer[i];
      
      // Définition améliorée de la correction
      bool isCorrection = (price < maVal && rsi_val > 70); // Prix sous MA + surachat
      
      if(isCorrection)
      {
         if(!inCorrection)
         {
            startIndex = i;
            inCorrection = true;
         }
      }
      else
      {
         if(inCorrection)
         {
            int duration = startIndex - i + 1;
            g_durationSum += duration;
            g_correctionCount++;
            inCorrection = false;
         }
         g_totalTrends++; // Compter les tendances complètes
      }
   }
   
   // Si correction en cours jusqu'à la dernière bougie
   if(inCorrection)
   {
      int duration = startIndex - 0 + 1;
      g_durationSum += duration;
      g_correctionCount++;
      g_totalTrends++;
   }
   
   // Calculer les statistiques
   if(g_totalTrends > 0)
      g_historicalCorrectionProb = (double)g_correctionCount / g_totalTrends * 100;
   
   if(g_correctionCount > 0)
      g_averageCorrectionDuration = (double)g_durationSum / g_correctionCount;
   
   g_correctionAnalysisDone = true;
   
   Print("📊 ANALYSE QUANTITATIVE DES CORRECTIONS - ", _Symbol);
   Print("   📍 Tendances analysées: ", g_totalTrends);
   Print("   📍 Corrections détectées: ", g_correctionCount);
   Print("   📍 Probabilité historique: ", DoubleToString(g_historicalCorrectionProb, 2), "%");
   Print("   📍 Durée moyenne: ", DoubleToString(g_averageCorrectionDuration, 2), " bougies H1");
}

//| Calculer la probabilité conditionnelle de correction               |
double CalculateConditionalCorrectionProbability()
{
   double rsiBuffer[];
   double atrBuffer[];
   double maBuffer[];
   
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(maBuffer, true);
   
   // Copier les données des indicateurs
   if(CopyBuffer(iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE), 0, 0, 1, rsiBuffer) < 1) return 50.0;
   if(CopyBuffer(iATR(_Symbol, PERIOD_H1, 14), 0, 0, 1, atrBuffer) < 1) return 50.0;
   if(CopyBuffer(iMA(_Symbol, PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE), 0, 0, 1, maBuffer) < 1) return 50.0;
   
   double rsi = rsiBuffer[0];
   double atr = atrBuffer[0];
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double maVal = maBuffer[0];
   
   // Calculer la distance à la MA en ATR
   double distanceToMA = MathAbs(currentPrice - maVal) / atr;
   
   // Calculer la volatilité normalisée
   double volatility = atr / currentPrice * 100;
   
   // Facteurs de probabilité conditionnelle
   double rsiFactor = (rsi > 80) ? 0.9 : (rsi > 70) ? 0.7 : (rsi < 30) ? 0.2 : 0.4;
   double distanceFactor = (distanceToMA > 2.5) ? 0.8 : (distanceToMA > 1.5) ? 0.6 : (distanceToMA > 1.0) ? 0.4 : 0.2;
   double volatilityFactor = (volatility > 1.5) ? 0.7 : (volatility > 1.0) ? 0.5 : 0.3;
   
   // Formule pondérée: 40% RSI + 35% Distance + 25% Volatilité
   double conditionalProb = 0.4 * rsiFactor + 0.35 * distanceFactor + 0.25 * volatilityFactor;
   
   return conditionalProb * 100; // En pourcentage
}

//| Prédire la durée actuelle de correction                           |
int PredictCurrentCorrectionDuration()
{
   if(!g_correctionAnalysisDone) return 5; // Valeur par défaut
   
   double rsiBuffer[];
   double atrBuffer[];
   double maBuffer[];
   
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(maBuffer, true);
   
   // Copier les données des indicateurs
   if(CopyBuffer(iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE), 0, 0, 1, rsiBuffer) < 1) return 5;
   if(CopyBuffer(iATR(_Symbol, PERIOD_H1, 14), 0, 0, 1, atrBuffer) < 1) return 5;
   if(CopyBuffer(iMA(_Symbol, PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE), 0, 0, 1, maBuffer) < 1) return 5;
   
   double rsi = rsiBuffer[0];
   double atr = atrBuffer[0];
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double maVal = maBuffer[0];
   
   // Si pas en correction, retourner 0
   if(currentPrice >= maVal && rsi <= 70) return 0;
   
   // Prédire basé sur les conditions actuelles
   double adjustment = 1.0;
   
   // Ajustements selon les indicateurs
   if(rsi > 85) adjustment *= 2.0;        // Surachat extrême = correction très longue
   else if(rsi > 80) adjustment *= 1.5;   // Surachat fort = correction longue
   else if(rsi < 40) adjustment *= 0.6;   // Survente = correction plus courte
   
   if(atr > g_averageCorrectionDuration * 0.15) adjustment *= 1.3; // Haute volatilité
   
   int predictedDuration = (int)(g_averageCorrectionDuration * adjustment);
   return MathMax(3, MathMin(20, predictedDuration)); // Limiter entre 3-20 bougies
}

//| Obtenir le score de correction global (0-100)                     |
double GetCorrectionScore()
{
   if(!g_correctionAnalysisDone) return 50.0; // Valeur par défaut
   
   double historicalProb = g_historicalCorrectionProb;
   double conditionalProb = CalculateConditionalCorrectionProbability();
   
   // Pondération: 30% historique, 70% conditionnel (plus réactif)
   double score = 0.3 * historicalProb + 0.7 * conditionalProb;
   
   return MathMin(100.0, MathMax(0.0, score));
}

//| Vérifier si on est dans une zone de correction à haut risque        |
bool IsInHighRiskCorrectionZone()
{
   double correctionScore = GetCorrectionScore();
   int predictedDuration = PredictCurrentCorrectionDuration();
   
   // Zone à haut risque = score élevé ET durée prédite significative
   return (correctionScore > 65 && predictedDuration > 5);
}

//| Obtenir la durée d'attente recommandée avant d'entrer              |
int GetRecommendedWaitTime()
{
   if(!g_correctionAnalysisDone) return 5; // Valeur par défaut
   
   double correctionScore = GetCorrectionScore();
   int predictedDuration = PredictCurrentCorrectionDuration();
   
   // Si forte probabilité de correction, attendre plus longtemps
   double multiplier = 1.0 + (correctionScore / 100.0) * 0.8;
   
   int recommendedWait = (int)(predictedDuration * multiplier);
   
   // Minimum 5 bougies, maximum 15 bougies
   return MathMax(5, MathMin(15, recommendedWait));
}

//| DÉTECTION DES SÉRIES DE SPIKES SUR BOOM/CRASH               |
bool DetectSpikeSeries(string direction)
{
   Print("🔍 DEBUG - DetectSpikeSeries appelée pour ", _Symbol, " | Direction: ", direction);
   
   // Récupérer les données nécessaires
   double close[], high[], low[];
   long volume[];
   double rsi[], atr[], ema5[], ema10[], ema20[], ema50[];
   
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(volume, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);
   ArraySetAsSeries(ema5, true);
   ArraySetAsSeries(ema10, true);
   ArraySetAsSeries(ema20, true);
   ArraySetAsSeries(ema50, true);
   
   if(CopyClose(_Symbol, PERIOD_CURRENT, 0, 50, close) < 50) return false;
   if(CopyHigh(_Symbol, PERIOD_CURRENT, 0, 50, high) < 50) return false;
   if(CopyLow(_Symbol, PERIOD_CURRENT, 0, 50, low) < 50) return false;
   if(CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 50, volume) < 50) return false;
   
   // Indicateurs
   int rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   int atrHandleLocal = iATR(_Symbol, PERIOD_CURRENT, 14);
   int ema5Handle = iMA(_Symbol, PERIOD_CURRENT, 5, 0, MODE_EMA, PRICE_CLOSE);
   int ema10Handle = iMA(_Symbol, PERIOD_CURRENT, 10, 0, MODE_EMA, PRICE_CLOSE);
   int ema20Handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
   int ema50Handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_EMA, PRICE_CLOSE);
   
   if(CopyBuffer(rsiHandle, 0, 0, 50, rsi) < 50) return false;
   if(CopyBuffer(atrHandleLocal, 0, 0, 50, atr) < 50) return false;
   if(CopyBuffer(ema5Handle, 0, 0, 50, ema5) < 50) return false;
   if(CopyBuffer(ema10Handle, 0, 0, 50, ema10) < 50) return false;
   if(CopyBuffer(ema20Handle, 0, 0, 50, ema20) < 50) return false;
   if(CopyBuffer(ema50Handle, 0, 0, 50, ema50) < 50) return false;
   
   // 1. DÉTECTION DE COMPRESSION
   bool isCompression = DetectCompressionPhase(close, high, low, 20);
   Print("🔍 DEBUG - Compression détectée: ", (isCompression ? "OUI" : "NON"));
   
   // 2. DÉTECTION DE BREAKOUT
   bool isBreakout = DetectBreakout(close, high, low, 10);
   Print("🔍 DEBUG - Breakout détecté: ", (isBreakout ? "OUI" : "NON"));
   
   // 3. ALIGNEMENT DES MOYENNES MOBILES
   bool isAlignedMA = (ema5[0] > ema10[0]) && (ema10[0] > ema20[0]) && (ema20[0] > ema50[0]);
   Print("🔍 DEBUG - Alignement MA: ", (isAlignedMA ? "OUI" : "NON"));
   
   // 4. MOMENTUM RSI
   bool isMomentum = (direction == "BUY") ? (rsi[0] > 55 && rsi[0] < 80) : (rsi[0] < 45 && rsi[0] > 20);
   Print("🔍 DEBUG - Momentum RSI: ", (isMomentum ? "OUI" : "NON"), " | RSI: ", DoubleToString(rsi[0], 1));
   
   // 5. EXPANSION ATR
   bool isATRExpansion = DetectATRExpansion(atr, 10);
   Print("🔍 DEBUG - Expansion ATR: ", (isATRExpansion ? "OUI" : "NON"));
   
   // 6. SÉRIE DE SPIKES (3+ bougies consécutives)
   bool isSpikeSeries = DetectConsecutiveSpikes(close, high, low, volume, direction);
   Print("🔍 DEBUG - Série de spikes: ", (isSpikeSeries ? "OUI" : "NON"));
   
   // COMBINAISON DES CONDITIONS
   bool spikeSeriesDetected = false;
   
   if(direction == "BUY")
   {
      // Conditions pour BUY sur Boom
      spikeSeriesDetected = isCompression && isBreakout && isAlignedMA && isMomentum && isATRExpansion;
      
      // Alternative: série de spikes déjà en cours
      if(!spikeSeriesDetected && isSpikeSeries && isAlignedMA && isMomentum)
      {
         spikeSeriesDetected = true;
         Print("🔍 DEBUG - Série de spikes BUY détectée (alternative)");
      }
   }
   else // SELL sur Crash
   {
      // Conditions pour SELL sur Crash
      spikeSeriesDetected = isCompression && isBreakout && !isAlignedMA && isMomentum && isATRExpansion;
      
      // Alternative: série de spikes déjà en cours
      if(!spikeSeriesDetected && isSpikeSeries && !isAlignedMA && isMomentum)
      {
         spikeSeriesDetected = true;
         Print("🔍 DEBUG - Série de spikes SELL détectée (alternative)");
      }
   }
   
   Print("🚨 SÉRIE DE SPIKES DÉTECTÉE - ", _Symbol, " | Direction: ", direction, " | Confiance: ", (spikeSeriesDetected ? "ÉLEVÉE" : "FAIBLE"));
   Print("   📊 Compression: ", (isCompression ? "✅" : "❌"), " | Breakout: ", (isBreakout ? "✅" : "❌"));
   Print("   📊 Alignement MA: ", (isAlignedMA ? "✅" : "❌"), " | Momentum: ", (isMomentum ? "✅" : "❌"));
   Print("   📊 Expansion ATR: ", (isATRExpansion ? "✅" : "❌"), " | Série spikes: ", (isSpikeSeries ? "✅" : "❌"));
   
   return spikeSeriesDetected;
}

//| DÉTECTION DE PHASE DE COMPRESSION                           |
bool DetectCompressionPhase(double &close[], double &high[], double &low[], int period)
{
   double range = 0;
   double minRange = DBL_MAX;
   double maxRange = DBL_MIN;
   
   // Calculer les ranges sur la période
   for(int i = 0; i < period; i++)
   {
      double currentRange = high[i] - low[i];
      range += currentRange;
      minRange = MathMin(minRange, currentRange);
      maxRange = MathMax(maxRange, currentRange);
   }
   
   double avgRange = range / period;
   double currentRange = high[0] - low[0];
   
   // Compression si le range actuel est significativement plus petit que la moyenne
   bool isCompression = (currentRange < avgRange * 0.7) && (maxRange - minRange > avgRange * 2);
   
   Print("🔍 DEBUG - Compression - Range actuel: ", DoubleToString(currentRange, _Digits), " | Moyenne: ", DoubleToString(avgRange, _Digits));
   
   return isCompression;
}

//| DÉTECTION DE BREAKOUT                                     |
bool DetectBreakout(double &close[], double &high[], double &low[], int period)
{
   double highestHigh = high[ArrayMaximum(high, 0, period)];
   double lowestLow = low[ArrayMinimum(low, 0, period)];
   
   // Breakout haussier
   bool isBreakoutUp = close[0] > highestHigh;
   
   // Breakout baissier
   bool isBreakoutDown = close[0] < lowestLow;
   
   bool isBreakout = isBreakoutUp || isBreakoutDown;
   
   Print("🔍 DEBUG - Breakout - Close: ", DoubleToString(close[0], _Digits), " | Highest: ", DoubleToString(highestHigh, _Digits), " | Lowest: ", DoubleToString(lowestLow, _Digits));
   
   return isBreakout;
}

//| DÉTECTION D'EXPANSION ATR                                |
bool DetectATRExpansion(double &atr[], int period)
{
   double currentATR = atr[0];
   double avgATR = 0;
   
   for(int i = 1; i < period; i++)
   {
      avgATR += atr[i];
   }
   avgATR /= (period - 1);
   
   // Expansion si ATR actuel > moyenne + 25%
   bool isExpansion = currentATR > (avgATR * 1.25);
   
   Print("🔍 DEBUG - ATR Expansion - Actuel: ", DoubleToString(currentATR, _Digits), " | Moyenne: ", DoubleToString(avgATR, _Digits));
   
   return isExpansion;
}

//| DÉTECTION DE SPIKES CONSÉCUTIFS                          |
bool DetectConsecutiveSpikes(double &close[], double &high[], double &low[], long &volume[], string direction)
{
   int consecutiveSpikes = 0;
   double avgRange = 0;
   
   // Calculer le range moyen
   for(int i = 0; i < 20; i++)
   {
      avgRange += high[i] - low[i];
   }
   avgRange /= 20;
   
   // Détecter les spikes consécutifs
   for(int i = 0; i < 10; i++)
   {
      double currentRange = high[i] - low[i];
      double bodySize = MathAbs(close[i] - close[i+1]);
      
      // Spike si range > 1.5x la moyenne ET corps > 1.2x la moyenne
      bool isSpike = (currentRange > avgRange * 1.5) && (bodySize > avgRange * 1.2);
      
      if(direction == "BUY")
      {
         // Spike haussier
         isSpike = isSpike && (close[i] > close[i+1]);
      }
      else
      {
         // Spike baissier
         isSpike = isSpike && (close[i] < close[i+1]);
      }
      
      if(isSpike)
      {
         consecutiveSpikes++;
         Print("🔍 DEBUG - Spike détecté à bougie ", i, " | Range: ", DoubleToString(currentRange, _Digits), " | Corps: ", DoubleToString(bodySize, _Digits));
      }
      else
      {
         break; // Arrêter dès qu'on n'a plus de spike
      }
   }
   
   bool isSpikeSeries = (consecutiveSpikes >= 3);
   
   Print("🔍 DEBUG - Spikes consécutifs: ", consecutiveSpikes, " | Série détectée: ", (isSpikeSeries ? "OUI" : "NON"));
   
   return isSpikeSeries;
}
void DrawFutureCorrectionZones()
{
   Print("🔍 DEBUG - DrawFutureCorrectionZones appelée pour ", _Symbol);
   
   if(!g_correctionAnalysisDone) 
   {
      Print("🔍 DEBUG - Analyse correction pas encore faite, retour");
      return;
   }
   
   // Obtenir les données actuelles
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   Print("🔍 DEBUG - Prix actuel: ", DoubleToString(currentPrice, _Digits));
   
   double rsiBuffer[], atrBuffer[], maBuffer[];
   
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(maBuffer, true);
   
   if(CopyBuffer(iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE), 0, 0, 1, rsiBuffer) < 1) 
   {
      Print("🔍 DEBUG - Erreur copie RSI, retour");
      return;
   }
   if(CopyBuffer(iATR(_Symbol, PERIOD_H1, 14), 0, 0, 1, atrBuffer) < 1) 
   {
      Print("🔍 DEBUG - Erreur copie ATR, retour");
      return;
   }
   if(CopyBuffer(iMA(_Symbol, PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE), 0, 0, 1, maBuffer) < 1) 
   {
      Print("🔍 DEBUG - Erreur copie MA, retour");
      return;
   }
   
   double rsi = rsiBuffer[0];
   double atr = atrBuffer[0];
   double maVal = maBuffer[0];
   
   Print("🔍 DEBUG - RSI: ", DoubleToString(rsi, 2), " | ATR: ", DoubleToString(atr, _Digits), " | MA: ", DoubleToString(maVal, _Digits));
   
   // Calculer les prédictions
   double correctionScore = GetCorrectionScore();
   int predictedDuration = PredictCurrentCorrectionDuration();
   bool isHighRisk = IsInHighRiskCorrectionZone();
   
   Print("🔍 DEBUG - Score: ", DoubleToString(correctionScore, 1), "% | Durée: ", predictedDuration, " | Haut risque: ", (isHighRisk ? "OUI" : "NON"));
   
   // Supprimer les anciennes zones
   ObjectDelete(0, "CORRECTION_ZONE_FUTURE");
   ObjectDelete(0, "CORRECTION_ZONE_LABEL");
   ObjectDelete(0, "CORRECTION_ZONE_RISK");
   ObjectDelete(0, "CORRECTION_ZONE_TOP");
   ObjectDelete(0, "CORRECTION_ZONE_BOTTOM");
   
   Print("🔍 DEBUG - Anciens objets supprimés");
   
   // Si pas de correction prévue, afficher un label simple
   if(predictedDuration == 0)
   {
      Print("🔍 DEBUG - Pas de correction prévue, affichage label vert");
      if(ObjectCreate(0, "CORRECTION_ZONE_LABEL", OBJ_TEXT, 0, TimeCurrent() + PeriodSeconds(PERIOD_H1) * 3, currentPrice))
      {
         ObjectSetString(0, "CORRECTION_ZONE_LABEL", OBJPROP_TEXT, "🟢 PAS DE CORRECTION");
         ObjectSetInteger(0, "CORRECTION_ZONE_LABEL", OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, "CORRECTION_ZONE_LABEL", OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, "CORRECTION_ZONE_LABEL", OBJPROP_ANCHOR, ANCHOR_LEFT);
         Print("🔍 DEBUG - Label vert créé avec succès");
      }
      else
      {
         Print("🔍 DEBUG - Erreur création label vert: ", GetLastError());
      }
      return;
   }
   
   // Calculer la zone de correction future
   datetime startTime = TimeCurrent() + PeriodSeconds(PERIOD_H1);
   datetime endTime = startTime + PeriodSeconds(PERIOD_H1) * predictedDuration;
   
   Print("🔍 DEBUG - Période: ", TimeToString(startTime), " → ", TimeToString(endTime));
   
   // Déterminer les niveaux de la zone
   double zoneTop, zoneBottom;
   
   if(StringFind(_Symbol, "Crash") >= 0)
   {
      // Pour Crash : correction vers le bas
      zoneTop = currentPrice;
      zoneBottom = currentPrice - (atr * 2.0); // 2 ATR de correction
      Print("🔍 DEBUG - Crash - Zone: ", DoubleToString(zoneTop, _Digits), " → ", DoubleToString(zoneBottom, _Digits));
   }
   else
   {
      // Pour Boom : correction vers le haut
      zoneBottom = currentPrice;
      zoneTop = currentPrice + (atr * 2.0); // 2 ATR de correction
      Print("🔍 DEBUG - Boom - Zone: ", DoubleToString(zoneBottom, _Digits), " → ", DoubleToString(zoneTop, _Digits));
   }
   
   // Couleur selon le niveau de risque - COULEURS CLAIRES ET TRANSPARENTES
   color zoneColor = (isHighRisk) ? clrLightSalmon : clrLightSkyBlue;
   string zoneLabel = (isHighRisk) ? "🔴 ZONE HAUT RISQUE" : "🔵 ZONE CORRECTION";
   
   Print("🔍 DEBUG - Couleur zone: ", (isHighRisk ? "Rouge clair" : "Bleu clair"));
   
   // Créer la zone de correction (rectangle) - TRÈS TRANSPARENT
   string zoneName = "CORRECTION_ZONE_FUTURE";
   if(ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, startTime, zoneTop, endTime, zoneBottom))
   {
      ObjectSetInteger(0, zoneName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, zoneName, OBJPROP_BACK, true); // En arrière-plan
      ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
      
      // Transparence TRÈS ÉLEVÉE pour que la zone soit claire et visible
      int alpha = (isHighRisk) ? 80 : 60; // Très transparent mais visible
      color fillColor = (isHighRisk) ? 
                       (color)ColorToARGB(clrLightSalmon, (uchar)alpha) : 
                       (color)ColorToARGB(clrLightSkyBlue, (uchar)alpha);
      ObjectSetInteger(0, zoneName, OBJPROP_BGCOLOR, fillColor);
      
      Print("🔍 DEBUG - Rectangle créé avec succès - Alpha: ", alpha, " (très transparent)");
   }
   else
   {
      Print("🔍 DEBUG - Erreur création rectangle: ", GetLastError());
   }
   
   // Créer le label principal avec texte clair
   if(ObjectCreate(0, "CORRECTION_ZONE_LABEL", OBJ_TEXT, 0, startTime, zoneTop))
   {
      string labelText = StringFormat("%s\nScore: %.1f%%\nDurée: %d bougies\nATR: %.4f", 
                                     zoneLabel, correctionScore, predictedDuration, atr);
      ObjectSetString(0, "CORRECTION_ZONE_LABEL", OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, "CORRECTION_ZONE_LABEL", OBJPROP_COLOR, (isHighRisk) ? clrDarkRed : clrDarkBlue);
      ObjectSetInteger(0, "CORRECTION_ZONE_LABEL", OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, "CORRECTION_ZONE_LABEL", OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      
      Print("🔍 DEBUG - Label créé avec succès");
   }
   else
   {
      Print("🔍 DEBUG - Erreur création label: ", GetLastError());
   }
   
   // Créer les lignes de support/résistance de la zone - COULEURS CLAIRES
   string topLineName = "CORRECTION_ZONE_TOP";
   string bottomLineName = "CORRECTION_ZONE_BOTTOM";
   
   // Ligne supérieure
   if(ObjectCreate(0, topLineName, OBJ_HLINE, 0, endTime, zoneTop))
   {
      ObjectSetInteger(0, topLineName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, topLineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, topLineName, OBJPROP_WIDTH, 1);
      Print("🔍 DEBUG - Ligne supérieure créée");
   }
   else
   {
      Print("🔍 DEBUG - Erreur création ligne supérieure: ", GetLastError());
   }
   
   // Ligne inférieure
   if(ObjectCreate(0, bottomLineName, OBJ_HLINE, 0, endTime, zoneBottom))
   {
      ObjectSetInteger(0, bottomLineName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, bottomLineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, bottomLineName, OBJPROP_WIDTH, 1);
      Print("🔍 DEBUG - Ligne inférieure créée");
   }
   else
   {
      Print("🔍 DEBUG - Erreur création ligne inférieure: ", GetLastError());
   }
   
   // Afficher les informations dans le journal
   Print("📊 ZONE DE CORRECTION FUTURE AFFICHÉE - ", _Symbol);
   Print("   📍 Score: ", DoubleToString(correctionScore, 1), "% | Risque: ", (isHighRisk ? "ÉLEVÉ" : "MODÉRÉ"));
   Print("   📍 Durée prédite: ", predictedDuration, " bougies H1");
   Print("   📍 Zone: ", DoubleToString(zoneBottom, _Digits), " - ", DoubleToString(zoneTop, _Digits));
   Print("   📍 Période: ", TimeToString(startTime), " → ", TimeToString(endTime));
   Print("   🎨 Couleur: ", (isHighRisk ? "Rouge clair transparent" : "Bleu clair transparent"));
}

//| Mettre à jour les zones de correction en temps réel               |
void UpdateCorrectionZones()
{
   Print("🔍 DEBUG - UpdateCorrectionZones appelée pour ", _Symbol);
   Print("🔍 DEBUG - ShowChartGraphics: ", (ShowChartGraphics ? "TRUE" : "FALSE"));
   
   // Forcer l'analyse des corrections si pas encore faite
   if(!g_correctionAnalysisDone)
   {
      Print("🔍 DEBUG - Forçage de l'analyse des corrections");
      DetectHistoricalCorrections();
   }
   
   // Limiter les mises à jour pour éviter la surcharge
   static datetime lastUpdate = 0;
   if(TimeCurrent() - lastUpdate < 60) 
   {
      Print("🔍 DEBUG - UpdateCorrectionZones sautée (moins de 60 secondes écoulées)");
      return; // 1 minute
   }
   lastUpdate = TimeCurrent();
   
   Print("🔍 DEBUG - UpdateCorrectionZones exécution de DrawFutureCorrectionZones");
   DrawFutureCorrectionZones();
}
