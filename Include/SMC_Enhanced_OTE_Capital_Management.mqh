//+------------------------------------------------------------------+
//| SMC_Enhanced_OTE_Capital_Management.mqh                          |
//| Gestion avancée du capital pour stratégie OTE+Fibonacci          |
//| Confirmations renforcées + Robot intelligent                      |
//+------------------------------------------------------------------+
#property copyright "TradBOT 2026"
#property link      "https://github.com/yourusername/tradbot"
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| PARAMÈTRES GESTION DE CAPITAL INTELLIGENTE                       |
//+------------------------------------------------------------------+

// Paramètres de risque adaptatif
input group "=== GESTION CAPITAL INTELLIGENTE ==="
input double SmartRisk_MinPercent = 0.5;        // Risque minimum par trade (%)
input double SmartRisk_MaxPercent = 2.0;        // Risque maximum par trade (%)
input double SmartRisk_BasePercent = 1.0;       // Risque de base (%)
input bool   UseAdaptiveRiskScaling = true;     // Adapter le risque selon performance
input double WinStreakRiskBonus = 0.2;          // Bonus par gain consécutif (%)
input double LossStreakRiskReduction = 0.3;     // Réduction par perte consécutive (%)
input int    MaxConsecutiveLossesBeforePause = 3; // Pause après N pertes consécutives

// Protection du capital
input group "=== PROTECTION CAPITAL ==="
input double DailyMaxLossPercent = 5.0;         // Perte journalière max (% capital)
input double DailyProfitTargetPercent = 8.0;    // Objectif profit journalier (%)
input bool   StopTradingAfterDailyTarget = true; // Arrêter après objectif atteint
input double MaxDrawdownPercent = 10.0;         // Drawdown max autorisé (%)
input bool   UseBreakEvenProtection = true;     // Activer protection break-even
input double BreakEvenTriggerRR = 1.5;          // Déclencher BE à R:R
input double BreakEvenOffsetPoints = 5.0;       // Offset BE en points

// Taille de position intelligente
input group "=== TAILLE POSITION INTELLIGENTE ==="
input bool   UseKellyPosition = false;          // Utiliser formule Kelly (avancé)
input double KellyCriterion = 0.25;             // Fraction Kelly (0.25 = Kelly/4)
input bool   UseFixedRiskAmount = false;        // Montant fixe en USD
input double FixedRiskAmountUSD = 10.0;         // Montant risque fixe ($)
input double MaxPositionSizePercent = 30.0;     // Max taille position (% capital)

//+------------------------------------------------------------------+
//| CONFIRMATIONS OTE RENFORCÉES                                     |
//+------------------------------------------------------------------+

input group "=== CONFIRMATIONS OTE RENFORCÉES ==="
input bool   OTE_RequireMultiTimeframeAlignment = true;  // Alignement multi-TF obligatoire
input bool   OTE_RequireVolumeConfirmation = true;       // Confirmation volume
input double OTE_MinVolumeRatio = 1.2;                   // Volume min (ratio moyenne)
input bool   OTE_RequireMAConfluence = true;             // Confluence moyennes mobiles
input bool   OTE_RequireMomentumConfirmation = true;     // Confirmation momentum (RSI/MACD)
input double OTE_MinRSIStrength = 40.0;                  // RSI minimum pour BUY
input double OTE_MaxRSIStrength = 60.0;                  // RSI maximum pour SELL
input bool   OTE_RequirePriceActionConfirmation = true;  // Confirmation price action
input bool   OTE_RequireStructureAlignment = true;       // Alignement structure SMC
input int    OTE_MinConfirmations = 5;                   // Nombre minimum de confirmations

// Filtres qualité de setup OTE
input group "=== QUALITÉ SETUP OTE ==="
input double OTE_MinQualityScore = 75.0;        // Score qualité minimum (%)
input bool   OTE_RequireFreshSetup = true;      // Setup récent uniquement
input int    OTE_MaxSetupAgeBars = 20;          // Age max setup (barres)
input bool   OTE_AvoidNewsEvents = true;        // Éviter événements économiques
input int    OTE_NewsAvoidanceMinutes = 30;     // Minutes avant/après news
input bool   OTE_RequireCleanZone = true;       // Zone OTE propre (pas de résistances)

//+------------------------------------------------------------------+
//| AFFICHAGE GRAPHIQUE OPTIMISÉ                                     |
//+------------------------------------------------------------------+

input group "=== AFFICHAGE GRAPHIQUE OPTIMISÉ ==="
input bool   UseMinimalLabels = true;           // Labels minimalistes
input int    Chart_LabelFontSize = 7;           // Taille police labels (petit)
input int    Chart_TitleFontSize = 9;           // Taille police titres
input color  Chart_OTE_BuyColor = clrDodgerBlue;    // Couleur zone OTE BUY
input color  Chart_OTE_SellColor = clrCrimson;      // Couleur zone OTE SELL
input int    Chart_OTE_Transparency = 90;       // Transparence zones OTE (0-255)
input bool   Chart_ShowOnlyActiveSetups = true; // Afficher uniquement setups actifs
input bool   Chart_UseCompactDisplay = true;    // Affichage compact
input int    Chart_MaxLabelLength = 15;         // Longueur max labels

//+------------------------------------------------------------------+
//| STRUCTURES DE DONNÉES                                            |
//+------------------------------------------------------------------+

struct SmartCapitalState
{
   double currentBalance;
   double startOfDayBalance;
   double currentEquity;
   double dailyPL;
   double peakEquity;
   double currentDrawdown;
   int consecutiveWins;
   int consecutiveLosses;
   int dailyTradeCount;
   double dailyWinRate;
   datetime lastTradeTime;
   bool dailyTargetReached;
   bool dailyMaxLossReached;
   bool pauseTrading;
};

struct OTEConfirmationScore
{
   bool trendAlignment;           // Alignement tendance multi-TF
   bool volumeConfirmation;        // Confirmation volume
   bool maConfluence;              // Confluence MA
   bool momentumConfirmation;      // Confirmation momentum
   bool priceActionConfirmation;   // Confirmation price action
   bool structureAlignment;        // Alignement structure
   bool freshSetup;                // Setup récent
   bool cleanZone;                 // Zone propre
   int totalConfirmations;         // Total confirmations
   double qualityScore;            // Score qualité (0-100)
};

struct EnhancedOTESetup
{
   double entryPrice;
   double stopLoss;
   double takeProfit;
   double fibLevel;                // Niveau Fibonacci (0.618, 0.786, etc.)
   string direction;               // BUY ou SELL
   datetime setupTime;
   int setupAgeBars;
   double riskRewardRatio;
   double expectedValue;           // Espérance mathématique
   OTEConfirmationScore confirmations;
   bool isValid;
   double positionSize;            // Taille position calculée
   string rejectionReason;         // Raison rejet si invalide
};

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES                                               |
//+------------------------------------------------------------------+

SmartCapitalState g_capitalState;
datetime g_lastDailyReset = 0;

//+------------------------------------------------------------------+
//| Initialisation de l'état du capital                             |
//+------------------------------------------------------------------+
void InitSmartCapitalManagement()
{
   g_capitalState.currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_capitalState.startOfDayBalance = g_capitalState.currentBalance;
   g_capitalState.currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_capitalState.dailyPL = 0.0;
   g_capitalState.peakEquity = g_capitalState.currentEquity;
   g_capitalState.currentDrawdown = 0.0;
   g_capitalState.consecutiveWins = 0;
   g_capitalState.consecutiveLosses = 0;
   g_capitalState.dailyTradeCount = 0;
   g_capitalState.dailyWinRate = 0.0;
   g_capitalState.lastTradeTime = 0;
   g_capitalState.dailyTargetReached = false;
   g_capitalState.dailyMaxLossReached = false;
   g_capitalState.pauseTrading = false;

   g_lastDailyReset = TimeCurrent();

   Print("✅ Smart Capital Management initialisé");
   Print("   💰 Balance: ", DoubleToString(g_capitalState.currentBalance, 2), " USD");
   Print("   🎯 Objectif journalier: +", DoubleToString(DailyProfitTargetPercent, 1), "%");
   Print("   🛡️ Perte max journalière: -", DoubleToString(DailyMaxLossPercent, 1), "%");
}

//+------------------------------------------------------------------+
//| Mise à jour de l'état du capital                                |
//+------------------------------------------------------------------+
void UpdateSmartCapitalState()
{
   // Reset journalier
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   MqlDateTime lastDt;
   TimeToStruct(g_lastDailyReset, lastDt);

   if(dt.day != lastDt.day)
   {
      ResetDailyStats();
      g_lastDailyReset = TimeCurrent();
   }

   // Mise à jour balance et équité
   g_capitalState.currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_capitalState.currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);

   // Calcul P&L journalier
   g_capitalState.dailyPL = g_capitalState.currentBalance - g_capitalState.startOfDayBalance;
   double dailyPLPercent = (g_capitalState.dailyPL / g_capitalState.startOfDayBalance) * 100.0;

   // Mise à jour peak equity et drawdown
   if(g_capitalState.currentEquity > g_capitalState.peakEquity)
      g_capitalState.peakEquity = g_capitalState.currentEquity;

   g_capitalState.currentDrawdown = ((g_capitalState.peakEquity - g_capitalState.currentEquity) / g_capitalState.peakEquity) * 100.0;

   // Vérification objectif journalier
   if(dailyPLPercent >= DailyProfitTargetPercent && StopTradingAfterDailyTarget)
   {
      if(!g_capitalState.dailyTargetReached)
      {
         Print("🎯 OBJECTIF JOURNALIER ATTEINT: +", DoubleToString(dailyPLPercent, 2), "% (+", DoubleToString(g_capitalState.dailyPL, 2), " USD)");
         Print("⏸️ Trading arrêté pour la journée");
      }
      g_capitalState.dailyTargetReached = true;
      g_capitalState.pauseTrading = true;
   }

   // Vérification perte max journalière
   if(dailyPLPercent <= -DailyMaxLossPercent)
   {
      if(!g_capitalState.dailyMaxLossReached)
      {
         Print("🚨 PERTE MAX JOURNALIÈRE ATTEINTE: ", DoubleToString(dailyPLPercent, 2), "% (", DoubleToString(g_capitalState.dailyPL, 2), " USD)");
         Print("⏸️ Trading arrêté pour la journée");
      }
      g_capitalState.dailyMaxLossReached = true;
      g_capitalState.pauseTrading = true;
   }

   // Vérification drawdown max
   if(g_capitalState.currentDrawdown >= MaxDrawdownPercent)
   {
      Print("🚨 DRAWDOWN MAX ATTEINT: ", DoubleToString(g_capitalState.currentDrawdown, 2), "%");
      g_capitalState.pauseTrading = true;
   }

   // Pause après pertes consécutives
   if(g_capitalState.consecutiveLosses >= MaxConsecutiveLossesBeforePause)
   {
      Print("⏸️ PAUSE: ", g_capitalState.consecutiveLosses, " pertes consécutives");
      g_capitalState.pauseTrading = true;
   }
}

//+------------------------------------------------------------------+
//| Reset des statistiques journalières                             |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
   Print("📅 NOUVEAU JOUR - Reset statistiques");

   g_capitalState.startOfDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_capitalState.dailyPL = 0.0;
   g_capitalState.dailyTradeCount = 0;
   g_capitalState.dailyWinRate = 0.0;
   g_capitalState.dailyTargetReached = false;
   g_capitalState.dailyMaxLossReached = false;
   g_capitalState.pauseTrading = false;
   g_capitalState.consecutiveWins = 0;
   g_capitalState.consecutiveLosses = 0;
}

//+------------------------------------------------------------------+
//| Calcul de la taille de position intelligente                    |
//+------------------------------------------------------------------+
double CalculateSmartPositionSize(string symbol, double entryPrice, double stopLoss, double confidence = 70.0)
{
   UpdateSmartCapitalState();

   // Vérifier si trading autorisé
   if(g_capitalState.pauseTrading)
   {
      Print("⏸️ Trading en pause - Aucune nouvelle position");
      return 0.0;
   }

   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);

   // Montant risque de base
   double riskPercent = SmartRisk_BasePercent;

   // Ajustement adaptatif du risque
   if(UseAdaptiveRiskScaling)
   {
      // Bonus pour séries gagnantes
      if(g_capitalState.consecutiveWins > 0)
         riskPercent += (WinStreakRiskBonus * g_capitalState.consecutiveWins);

      // Réduction pour séries perdantes
      if(g_capitalState.consecutiveLosses > 0)
         riskPercent -= (LossStreakRiskReduction * g_capitalState.consecutiveLosses);

      // Ajustement selon confiance IA
      double confidenceUnit = confidence / 100.0;
      if(confidenceUnit > 0.80)
         riskPercent *= 1.2;  // +20% si haute confiance
      else if(confidenceUnit < 0.60)
         riskPercent *= 0.7;  // -30% si faible confiance
   }

   // Limites min/max
   if(riskPercent < SmartRisk_MinPercent) riskPercent = SmartRisk_MinPercent;
   if(riskPercent > SmartRisk_MaxPercent) riskPercent = SmartRisk_MaxPercent;

   // Calcul taille position
   double riskAmount;
   if(UseFixedRiskAmount)
      riskAmount = FixedRiskAmountUSD;
   else
      riskAmount = g_capitalState.currentBalance * (riskPercent / 100.0);

   // Distance SL en points
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double slDistance = MathAbs(entryPrice - stopLoss) / point;

   // Valeur du tick
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);

   if(tickValue <= 0 || tickSize <= 0 || slDistance <= 0)
      return minLot;

   // Calcul lot
   double pipValue = (tickValue / tickSize) * point;
   double lotSize = riskAmount / (slDistance * pipValue);

   // Limiter à max % du capital
   double maxPositionValue = g_capitalState.currentBalance * (MaxPositionSizePercent / 100.0);
   double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double maxLotByCapital = maxPositionValue / (contractSize * entryPrice);

   if(lotSize > maxLotByCapital)
      lotSize = maxLotByCapital;

   // Arrondir selon step
   int steps = (int)MathFloor(lotSize / lotStep);
   lotSize = steps * lotStep;

   // Appliquer limites broker
   if(lotSize < minLot) lotSize = minLot;
   if(lotSize > maxLot) lotSize = maxLot;

   // Normalisation
   lotSize = NormalizeDouble(lotSize, 2);

   Print("📊 POSITION SIZE CALCULÉE");
   Print("   💰 Risque: ", DoubleToString(riskPercent, 2), "% (", DoubleToString(riskAmount, 2), " USD)");
   Print("   📏 SL distance: ", DoubleToString(slDistance, 1), " points");
   Print("   📦 Lot: ", DoubleToString(lotSize, 2));
   Print("   ✅ Streak: ", g_capitalState.consecutiveWins, "W / ", g_capitalState.consecutiveLosses, "L");

   return lotSize;
}

//+------------------------------------------------------------------+
//| Évaluation des confirmations OTE renforcées                     |
//+------------------------------------------------------------------+
OTEConfirmationScore EvaluateOTEConfirmations(string symbol, string direction, double entryPrice, double fibLevel)
{
   OTEConfirmationScore score;
   score.totalConfirmations = 0;
   score.qualityScore = 0.0;

   // 1. Alignement tendance multi-timeframe
   score.trendAlignment = CheckMultiTimeframeTrendAlignment(symbol, direction);
   if(score.trendAlignment)
   {
      score.totalConfirmations++;
      score.qualityScore += 20.0;
      Print("   ✅ Alignement tendance multi-TF");
   }
   else if(OTE_RequireMultiTimeframeAlignment)
   {
      Print("   ❌ Pas d'alignement tendance multi-TF");
   }

   // 2. Confirmation volume
   score.volumeConfirmation = CheckVolumeConfirmation(symbol);
   if(score.volumeConfirmation)
   {
      score.totalConfirmations++;
      score.qualityScore += 15.0;
      Print("   ✅ Confirmation volume");
   }
   else if(OTE_RequireVolumeConfirmation)
   {
      Print("   ❌ Volume insuffisant");
   }

   // 3. Confluence moyennes mobiles
   score.maConfluence = CheckMAConfluence(symbol, direction, entryPrice);
   if(score.maConfluence)
   {
      score.totalConfirmations++;
      score.qualityScore += 15.0;
      Print("   ✅ Confluence moyennes mobiles");
   }
   else if(OTE_RequireMAConfluence)
   {
      Print("   ❌ Pas de confluence MA");
   }

   // 4. Confirmation momentum
   score.momentumConfirmation = CheckMomentumConfirmation(symbol, direction);
   if(score.momentumConfirmation)
   {
      score.totalConfirmations++;
      score.qualityScore += 15.0;
      Print("   ✅ Confirmation momentum");
   }
   else if(OTE_RequireMomentumConfirmation)
   {
      Print("   ❌ Momentum non aligné");
   }

   // 5. Confirmation price action
   score.priceActionConfirmation = CheckPriceActionConfirmation(symbol, direction);
   if(score.priceActionConfirmation)
   {
      score.totalConfirmations++;
      score.qualityScore += 15.0;
      Print("   ✅ Confirmation price action");
   }
   else if(OTE_RequirePriceActionConfirmation)
   {
      Print("   ❌ Price action non conforme");
   }

   // 6. Alignement structure SMC
   score.structureAlignment = CheckStructureAlignment(symbol, direction);
   if(score.structureAlignment)
   {
      score.totalConfirmations++;
      score.qualityScore += 10.0;
      Print("   ✅ Structure SMC alignée");
   }
   else if(OTE_RequireStructureAlignment)
   {
      Print("   ❌ Structure non alignée");
   }

   // 7. Setup récent
   score.freshSetup = true;  // À implémenter avec age réel
   if(score.freshSetup)
   {
      score.totalConfirmations++;
      score.qualityScore += 5.0;
   }

   // 8. Zone propre
   score.cleanZone = CheckCleanOTEZone(symbol, entryPrice, direction);
   if(score.cleanZone)
   {
      score.totalConfirmations++;
      score.qualityScore += 5.0;
      Print("   ✅ Zone OTE propre");
   }
   else if(OTE_RequireCleanZone)
   {
      Print("   ❌ Zone OTE encombrée");
   }

   Print("📊 SCORE CONFIRMATIONS OTE: ", score.totalConfirmations, "/8 (", DoubleToString(score.qualityScore, 1), "%)");

   return score;
}

//+------------------------------------------------------------------+
//| Vérification alignement tendance multi-TF                        |
//+------------------------------------------------------------------+
bool CheckMultiTimeframeTrendAlignment(string symbol, string direction)
{
   if(!OTE_RequireMultiTimeframeAlignment) return true;

   // Vérifier EMA sur M1, M5, M15
   ENUM_TIMEFRAMES timeframes[] = {PERIOD_M1, PERIOD_M5, PERIOD_M15};
   int alignedCount = 0;

   for(int i = 0; i < ArraySize(timeframes); i++)
   {
      double ema9 = iMA(symbol, timeframes[i], 9, 0, MODE_EMA, PRICE_CLOSE);
      double ema21 = iMA(symbol, timeframes[i], 21, 0, MODE_EMA, PRICE_CLOSE);
      double currentPrice = (direction == "BUY") ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);

      if(direction == "BUY")
      {
         if(currentPrice > ema9 && ema9 > ema21)
            alignedCount++;
      }
      else  // SELL
      {
         if(currentPrice < ema9 && ema9 < ema21)
            alignedCount++;
      }
   }

   return (alignedCount >= 2);  // Au moins 2 TF alignés sur 3
}

//+------------------------------------------------------------------+
//| Vérification confirmation volume                                 |
//+------------------------------------------------------------------+
bool CheckVolumeConfirmation(string symbol)
{
   if(!OTE_RequireVolumeConfirmation) return true;

   long currentVolume[];
   if(CopyTickVolume(symbol, PERIOD_M1, 0, 1, currentVolume) < 1)
      return false;

   long avgVolume[];
   if(CopyTickVolume(symbol, PERIOD_M1, 0, 20, avgVolume) < 20)
      return false;

   // Calculer moyenne
   double volumeSum = 0.0;
   for(int i = 0; i < ArraySize(avgVolume); i++)
      volumeSum += avgVolume[i];

   double avgVol = volumeSum / ArraySize(avgVolume);
   double volumeRatio = (double)currentVolume[0] / avgVol;

   return (volumeRatio >= OTE_MinVolumeRatio);
}

//+------------------------------------------------------------------+
//| Vérification confluence MA                                       |
//+------------------------------------------------------------------+
bool CheckMAConfluence(string symbol, string direction, double entryPrice)
{
   if(!OTE_RequireMAConfluence) return true;

   // Vérifier proximité avec EMA20/23 (rebond)
   double ema20 = iMA(symbol, PERIOD_M1, 20, 0, MODE_EMA, PRICE_CLOSE);
   double ema23 = iMA(symbol, PERIOD_M1, 23, 0, MODE_EMA, PRICE_CLOSE);

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tolerance = 35 * point;  // 35 points de tolérance

   if(direction == "BUY")
   {
      // Prix doit être proche ou au-dessus de EMA20/23
      if(entryPrice >= ema20 - tolerance || entryPrice >= ema23 - tolerance)
         return true;
   }
   else  // SELL
   {
      // Prix doit être proche ou en-dessous de EMA20/23
      if(entryPrice <= ema20 + tolerance || entryPrice <= ema23 + tolerance)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérification confirmation momentum                               |
//+------------------------------------------------------------------+
bool CheckMomentumConfirmation(string symbol, string direction)
{
   if(!OTE_RequireMomentumConfirmation) return true;

   // RSI
   double rsi = iRSI(symbol, PERIOD_M1, 14, PRICE_CLOSE);

   if(direction == "BUY")
   {
      // RSI entre 40 et 60 = zone idéale pour BUY (pas surachat)
      if(rsi >= OTE_MinRSIStrength && rsi <= 70.0)
         return true;
   }
   else  // SELL
   {
      // RSI entre 40 et 60 = zone idéale pour SELL (pas survente)
      if(rsi >= 30.0 && rsi <= OTE_MaxRSIStrength)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérification price action                                        |
//+------------------------------------------------------------------+
bool CheckPriceActionConfirmation(string symbol, string direction)
{
   if(!OTE_RequirePriceActionConfirmation) return true;

   // Vérifier la dernière bougie M1
   double open[], high[], low[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   if(CopyOpen(symbol, PERIOD_M1, 0, 3, open) < 3) return false;
   if(CopyHigh(symbol, PERIOD_M1, 0, 3, high) < 3) return false;
   if(CopyLow(symbol, PERIOD_M1, 0, 3, low) < 3) return false;
   if(CopyClose(symbol, PERIOD_M1, 0, 3, close) < 3) return false;

   double body = MathAbs(close[0] - open[0]);
   double totalRange = high[0] - low[0];

   if(totalRange <= 0) return false;

   double bodyRatio = body / totalRange;

   if(direction == "BUY")
   {
      // Bougie haussière avec corps >= 50% de la range
      if(close[0] > open[0] && bodyRatio >= 0.5)
         return true;
   }
   else  // SELL
   {
      // Bougie baissière avec corps >= 50% de la range
      if(close[0] < open[0] && bodyRatio >= 0.5)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Vérification alignement structure SMC                           |
//+------------------------------------------------------------------+
bool CheckStructureAlignment(string symbol, string direction)
{
   if(!OTE_RequireStructureAlignment) return true;

   // À implémenter: vérifier OB, FVG, BOS dans la direction
   // Pour l'instant, retourner true si non requis
   return true;
}

//+------------------------------------------------------------------+
//| Vérification zone OTE propre                                    |
//+------------------------------------------------------------------+
bool CheckCleanOTEZone(string symbol, double entryPrice, string direction)
{
   if(!OTE_RequireCleanZone) return true;

   // Vérifier qu'il n'y a pas de support/résistance majeur dans la zone
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);

   if(CopyHigh(symbol, PERIOD_M15, 0, 50, high) < 50) return false;
   if(CopyLow(symbol, PERIOD_M15, 0, 50, low) < 50) return false;

   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tolerance = 20 * point;

   // Compter combien de fois le prix a touché la zone OTE
   int touchCount = 0;
   for(int i = 0; i < 50; i++)
   {
      if(MathAbs(high[i] - entryPrice) <= tolerance || MathAbs(low[i] - entryPrice) <= tolerance)
         touchCount++;
   }

   // Zone propre = maximum 2 touchés historiques
   return (touchCount <= 2);
}

//+------------------------------------------------------------------+
//| Validation complète d'un setup OTE                              |
//+------------------------------------------------------------------+
bool ValidateEnhancedOTESetup(EnhancedOTESetup &setup)
{
   Print("🔍 VALIDATION SETUP OTE RENFORCÉ - ", setup.direction, " @ ", DoubleToString(setup.entryPrice, _Digits));

   // 1. Vérifier si trading autorisé
   UpdateSmartCapitalState();
   if(g_capitalState.pauseTrading)
   {
      setup.rejectionReason = "Trading en pause";
      Print("   ❌ ", setup.rejectionReason);
      return false;
   }

   // 2. Évaluer confirmations
   setup.confirmations = EvaluateOTEConfirmations(_Symbol, setup.direction, setup.entryPrice, setup.fibLevel);

   // 3. Vérifier nombre minimum de confirmations
   if(setup.confirmations.totalConfirmations < OTE_MinConfirmations)
   {
      setup.rejectionReason = "Confirmations insuffisantes (" + IntegerToString(setup.confirmations.totalConfirmations) + "/" + IntegerToString(OTE_MinConfirmations) + ")";
      Print("   ❌ ", setup.rejectionReason);
      return false;
   }

   // 4. Vérifier score qualité
   if(setup.confirmations.qualityScore < OTE_MinQualityScore)
   {
      setup.rejectionReason = "Score qualité insuffisant (" + DoubleToString(setup.confirmations.qualityScore, 1) + "% < " + DoubleToString(OTE_MinQualityScore, 1) + "%)";
      Print("   ❌ ", setup.rejectionReason);
      return false;
   }

   // 5. Vérifier R:R minimum
   double risk = MathAbs(setup.entryPrice - setup.stopLoss);
   double reward = MathAbs(setup.takeProfit - setup.entryPrice);
   setup.riskRewardRatio = reward / risk;

   if(setup.riskRewardRatio < 2.0)
   {
      setup.rejectionReason = "R:R insuffisant (" + DoubleToString(setup.riskRewardRatio, 2) + " < 2.0)";
      Print("   ❌ ", setup.rejectionReason);
      return false;
   }

   Print("✅ SETUP OTE VALIDÉ");
   Print("   📊 Confirmations: ", setup.confirmations.totalConfirmations, "/8");
   Print("   ⭐ Qualité: ", DoubleToString(setup.confirmations.qualityScore, 1), "%");
   Print("   💎 R:R: 1:", DoubleToString(setup.riskRewardRatio, 2));

   setup.isValid = true;
   return true;
}

//+------------------------------------------------------------------+
//| Affichage graphique optimisé du setup OTE                       |
//+------------------------------------------------------------------+
void DrawEnhancedOTESetup(const EnhancedOTESetup &setup)
{
   if(!setup.isValid) return;

   // Supprimer anciens objets
   ObjectsDeleteAll(0, "ENHANCED_OTE_");

   datetime now = TimeCurrent();
   datetime endTime = now + PeriodSeconds(PERIOD_CURRENT) * 40;

   color setupColor = (setup.direction == "BUY") ? Chart_OTE_BuyColor : Chart_OTE_SellColor;

   // Zone OTE (rectangle transparent)
   string zoneName = "ENHANCED_OTE_ZONE";
   ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, now, setup.entryPrice - (MathAbs(setup.entryPrice - setup.stopLoss) * 0.2), endTime, setup.entryPrice);
   ObjectSetInteger(0, zoneName, OBJPROP_COLOR, setupColor);
   ObjectSetInteger(0, zoneName, OBJPROP_FILL, true);
   ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
   ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);

   // Ligne entrée (fine)
   string entryLine = "ENHANCED_OTE_ENTRY";
   ObjectCreate(0, entryLine, OBJ_TREND, 0, now, setup.entryPrice, endTime, setup.entryPrice);
   ObjectSetInteger(0, entryLine, OBJPROP_COLOR, setupColor);
   ObjectSetInteger(0, entryLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, entryLine, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, entryLine, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, entryLine, OBJPROP_SELECTABLE, false);

   // Ligne SL (rouge, fine)
   string slLine = "ENHANCED_OTE_SL";
   ObjectCreate(0, slLine, OBJ_TREND, 0, now, setup.stopLoss, endTime, setup.stopLoss);
   ObjectSetInteger(0, slLine, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, slLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, slLine, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, slLine, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, slLine, OBJPROP_SELECTABLE, false);

   // Ligne TP (vert, fine)
   string tpLine = "ENHANCED_OTE_TP";
   ObjectCreate(0, tpLine, OBJ_TREND, 0, now, setup.takeProfit, endTime, setup.takeProfit);
   ObjectSetInteger(0, tpLine, OBJPROP_COLOR, clrLimeGreen);
   ObjectSetInteger(0, tpLine, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, tpLine, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, tpLine, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, tpLine, OBJPROP_SELECTABLE, false);

   if(!UseMinimalLabels)
   {
      // Label compact
      string label = "ENHANCED_OTE_LABEL";
      string labelText = setup.direction + " " + DoubleToString(setup.fibLevel * 100, 1) + "% RR:" + DoubleToString(setup.riskRewardRatio, 1);

      if(Chart_UseCompactDisplay && StringLen(labelText) > Chart_MaxLabelLength)
         labelText = StringSubstr(labelText, 0, Chart_MaxLabelLength);

      ObjectCreate(0, label, OBJ_TEXT, 0, now, setup.entryPrice);
      ObjectSetString(0, label, OBJPROP_TEXT, labelText);
      ObjectSetInteger(0, label, OBJPROP_COLOR, setupColor);
      ObjectSetInteger(0, label, OBJPROP_FONTSIZE, Chart_LabelFontSize);
      ObjectSetString(0, label, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, label, OBJPROP_SELECTABLE, false);
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Gestion du Break-Even automatique                               |
//+------------------------------------------------------------------+
void ManageBreakEvenProtection()
{
   if(!UseBreakEvenProtection) return;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(PositionGetTicket(i))) continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      if(symbol != _Symbol) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

      double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      double beOffset = BreakEvenOffsetPoints * point;

      double risk = 0.0;
      double reward = 0.0;

      if(type == POSITION_TYPE_BUY)
      {
         risk = openPrice - sl;
         reward = currentPrice - openPrice;

         // Vérifier si R:R atteint
         if(reward >= risk * BreakEvenTriggerRR && sl < openPrice)
         {
            double newSL = openPrice + beOffset;
            MqlTradeRequest request = {};
            MqlTradeResult result = {};

            request.action = TRADE_ACTION_SLTP;
            request.symbol = symbol;
            request.sl = newSL;
            request.tp = tp;
            request.position = PositionGetInteger(POSITION_TICKET);

            if(OrderSend(request, result))
            {
               Print("✅ BREAK-EVEN activé - BUY @ ", DoubleToString(newSL, _Digits));
            }
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         risk = sl - openPrice;
         reward = openPrice - currentPrice;

         // Vérifier si R:R atteint
         if(reward >= risk * BreakEvenTriggerRR && sl > openPrice)
         {
            double newSL = openPrice - beOffset;
            MqlTradeRequest request = {};
            MqlTradeResult result = {};

            request.action = TRADE_ACTION_SLTP;
            request.symbol = symbol;
            request.sl = newSL;
            request.tp = tp;
            request.position = PositionGetInteger(POSITION_TICKET);

            if(OrderSend(request, result))
            {
               Print("✅ BREAK-EVEN activé - SELL @ ", DoubleToString(newSL, _Digits));
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Affichage dashboard capital                                      |
//+------------------------------------------------------------------+
void DisplayCapitalDashboard()
{
   UpdateSmartCapitalState();

   string dashText = "═══ CAPITAL MANAGEMENT ═══\n";
   dashText += "Balance: " + DoubleToString(g_capitalState.currentBalance, 2) + " USD\n";
   dashText += "Equity: " + DoubleToString(g_capitalState.currentEquity, 2) + " USD\n";

   double plPercent = (g_capitalState.dailyPL / g_capitalState.startOfDayBalance) * 100.0;
   dashText += "P&L jour: " + DoubleToString(g_capitalState.dailyPL, 2) + " (" + DoubleToString(plPercent, 2) + "%)\n";
   dashText += "Drawdown: " + DoubleToString(g_capitalState.currentDrawdown, 2) + "%\n";
   dashText += "Streak: " + IntegerToString(g_capitalState.consecutiveWins) + "W / " + IntegerToString(g_capitalState.consecutiveLosses) + "L\n";
   dashText += "Trades: " + IntegerToString(g_capitalState.dailyTradeCount) + "\n";

   if(g_capitalState.pauseTrading)
      dashText += "STATUS: PAUSE\n";
   else
      dashText += "STATUS: ACTIF\n";

   string dashName = "CAPITAL_DASHBOARD";
   if(ObjectFind(0, dashName) < 0)
   {
      ObjectCreate(0, dashName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, dashName, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, dashName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, dashName, OBJPROP_YDISTANCE, 30);
      ObjectSetInteger(0, dashName, OBJPROP_COLOR, clrWhite);
      ObjectSetInteger(0, dashName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, dashName, OBJPROP_FONT, "Courier New");
   }

   ObjectSetString(0, dashName, OBJPROP_TEXT, dashText);
}
