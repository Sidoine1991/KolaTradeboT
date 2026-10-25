//+------------------------------------------------------------------+
//| Fx_robot_pro_v5.mq5 - Système de trading avancé                 |
//| Fonctionnalités :                                                |
//| - Gestion des risques avancée avec ATR dynamique                 |
//| - Détection de tendance multi-timeframe                          |
//| - Gestion intelligente du capital et du risque                   |
//| - Sortie partielle des positions et trailing stop avancé         |
//| Auteur: Sidoine Yebadokpo & Assistant IA                         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025 - Tous droits réservés"
#property version   "5.0" // Version majeure
#property strict

//--- Include des bibliothèques nécessaires
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Math\Stat\Math.mqh>
#include <Indicators\Trend.mqh>
#include <Indicators\Oscillators.mqh>

//--- Paramètres de trading avancés
input group "=== GESTION DU RISQUE ==="
input double   InpRiskPercent       = 1.0;       // Pourcentage du capital à risquer par trade (%)
input double   InpMaxRiskPerTrade   = 2.0;       // Risque maximum par trade (% du capital)
input double   InpMaxDailyRisk      = 5.0;       // Risque maximum journalier (% du capital)
input bool     InpUseATRForSL       = true;      // Utiliser ATR pour le Stop Loss
input double   InpATRMultiplierSL   = 1.5;       // Multiplicateur ATR pour le Stop Loss
input double   InpATRMultiplierTP   = 3.0;       // Multiplicateur ATR pour le Take Profit

input group "=== GESTION DES POSITIONS ==="
input bool     InpUsePartialClose   = true;      // Activer la sortie partielle
input int      InpPartialCloseAt1   = 50;        // % de la position à fermer au 1er TP
input double   InpPartialTP1        = 1.0;       // Niveau du 1er TP (en multiples d'ATR)
input double   InpPartialTP2        = 2.0;       // Niveau du 2ème TP (en multiples d'ATR)
input bool     InpUseTrailingStop   = true;      // Activer le trailing stop
input double   InpTrailingStart     = 1.5;       // Niveau de départ du trailing (en multiples d'ATR)
input double   InpTrailingStep      = 0.5;       // Pas du trailing (en multiples d'ATR)

input group "=== DETECTION DE TENDANCE ==="
input ENUM_TIMEFRAMES InpTrendTF1   = PERIOD_M15; // Timeframe tendance court terme
input ENUM_TIMEFRAMES InpTrendTF2   = PERIOD_H1;  // Timeframe tendance moyen terme
input ENUM_TIMEFRAMES InpTrendTF3   = PERIOD_H4;  // Timeframe tendance long terme
input int      InpTrendMAPeriod1    = 20;        // Période MA courte
input int      InpTrendMAPeriod2    = 50;        // Période MA longue
input int      InpADXPeriod         = 14;        // Période ADX pour la force de la tendance
input int      InpADXThreshold      = 25;        // Seuil ADX minimum

input group "=== CONFIGURATION GENERALE ==="
input ulong    InpMagicNumber       = 20251115;  // Magic Number
input bool     InpEnableTrading     = true;      // Activer le trading
input bool     InpShowVisuals       = true;      // Afficher les éléments visuels
input int      InpMaxOpenPositions  = 5;         // Nombre maximum de positions ouvertes
input ENUM_TIMEFRAMES InpSpikeTimeframe = PERIOD_M1; // Timeframe pour la détection de spikes
input double   InpVPIN_Threshold    = 0.60;      // Seuil VPIN pour le trading
input double   InpOBI_Threshold     = 0.55;      // Seuil OBI pour le trading
input int      InpATR_Period        = 14;        // Période ATR
input int      InpVPIN_WindowBars   = 500;       // Fenêtre pour le calcul du VPIN
input int      InpOBI_Lookback      = 300;       // Période de lookback pour OBI
input int      InpCVD_WindowBars    = 500;       // Fenêtre pour le calcul du CVD
input double   InpLotSize           = 0.1;       // Taille de lot fixe (si utilisée)
input bool     InpUseFixedLot       = false;     // Utiliser une taille de lot fixe
input int      InpMinBarsRequired   = 100;       // Nombre minimum de barres requises

//--- Handles des indicateurs
int g_atr_handle = INVALID_HANDLE;
int g_adx_handle = INVALID_HANDLE;
int g_ma_fast_handle = INVALID_HANDLE;
int g_ma_slow_handle = INVALID_HANDLE;
int g_rsi_handle = INVALID_HANDLE;
int g_ma_trend1_handle = INVALID_HANDLE;
int g_ma_trend2_handle = INVALID_HANDLE;

//--- Variables globales
CTrade trade;
CPositionInfo PositionInfo;
COrderInfo OrderInfo;
CDealInfo DealInfo;

datetime g_lastBarTime = 0;
double   g_lastATR = 0.0;
double   g_lastVPIN = 0.0;
double   g_lastOBI = 0.0;
double   g_lastCVD = 0.0;
double   g_dailyPL = 0.0;
int      g_tradesToday = 0;
bool     g_hasOpenPosition = false;

//--- Structure pour le suivi des positions
struct PositionData {
   ulong  ticket;
   double entryPrice;
   double stopLoss;
   double takeProfit;
   double atrValue;
   datetime openTime;
   int     direction; // 1 pour achat, -1 pour vente
};

//--- Tableau pour suivre les positions ouvertes
CArrayObj *g_openPositions = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialisation du tableau des positions
   g_openPositions = new CArrayObj();
   
   //--- Initialisation des paramètres de trading
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   //--- Initialisation des indicateurs
   if(!InitializeIndicators())
   {
      Print("Erreur lors de l'initialisation des indicateurs");
      return INIT_FAILED;
   }
   
   //--- Vérification du nombre minimum de barres
   if(Bars(_Symbol, PERIOD_CURRENT) < InpMinBarsRequired)
   {
      Print("Nombre de barres insuffisant pour l'analyse");
      return INIT_PARAMETERS_INCORRECT;
   }
   
   //--- Initialisation du timer
   EventSetTimer(1);
   
   Print("Robot initialisé avec succès");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Libération des ressources
   EventKillTimer();
   
   //--- Libération des indicateurs
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
   if(g_ma_fast_handle != INVALID_HANDLE) IndicatorRelease(g_ma_fast_handle);
   if(g_ma_slow_handle != INVALID_HANDLE) IndicatorRelease(g_ma_slow_handle);
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
   if(g_ma_trend1_handle != INVALID_HANDLE) IndicatorRelease(g_ma_trend1_handle);
   if(g_ma_trend2_handle != INVALID_HANDLE) IndicatorRelease(g_ma_trend2_handle);
   
   //--- Libération du tableau des positions
   if(CheckPointer(g_openPositions) != POINTER_INVALID)
   {
      g_openPositions.Clear();
      delete g_openPositions;
   }
   
   Print("Robot arrêté");
}

//+------------------------------------------------------------------+
//| Initialisation des indicateurs                                   |
//+------------------------------------------------------------------+
bool InitializeIndicators()
{
   //--- Initialisation ATR
   g_atr_handle = iATR(_Symbol, PERIOD_CURRENT, InpATR_Period);
   if(g_atr_handle == INVALID_HANDLE)
   {
      Print("Erreur création ATR");
      return false;
   }
   
   //--- Initialisation ADX
   g_adx_handle = iADX(_Symbol, PERIOD_CURRENT, InpADXPeriod);
   if(g_adx_handle == INVALID_HANDLE)
   {
      Print("Erreur création ADX");
      return false;
   }
   
   //--- Initialisation des moyennes mobiles rapide et lente
   g_ma_fast_handle = iMA(_Symbol, PERIOD_CURRENT, InpTrendMAPeriod1, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_slow_handle = iMA(_Symbol, PERIOD_CURRENT, InpTrendMAPeriod2, 0, MODE_EMA, PRICE_CLOSE);
   
   if(g_ma_fast_handle == INVALID_HANDLE || g_ma_slow_handle == INVALID_HANDLE)
   {
      Print("Erreur création des moyennes mobiles");
      return false;
   }
   
   //--- Initialisation RSI
   g_rsi_handle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   if(g_rsi_handle == INVALID_HANDLE)
   {
      Print("Erreur création RSI");
      return false;
   }
   
   //--- Initialisation des moyennes mobiles pour la tendance
   g_ma_trend1_handle = iMA(_Symbol, InpTrendTF1, InpTrendMAPeriod1, 0, MODE_EMA, PRICE_CLOSE);
   g_ma_trend2_handle = iMA(_Symbol, InpTrendTF1, InpTrendMAPeriod2, 0, MODE_EMA, PRICE_CLOSE);
   
   if(g_ma_trend1_handle == INVALID_HANDLE || g_ma_trend2_handle == INVALID_HANDLE)
   {
      Print("Erreur création des moyennes mobiles de tendance");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Vérifier si une nouvelle barre est formée
   if(IsNewBar())
   {
      // Mettre à jour les indicateurs
      UpdateIndicators();
      
      // Vérifier les opportunités de trading
      CheckTradingOpportunities();
      
      // Gérer les positions ouvertes
      ManageOpenPositions();
   }
}

//+------------------------------------------------------------------+
//| Vérifie si une nouvelle barre est formée                         |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Met à jour les valeurs des indicateurs                           |
//+------------------------------------------------------------------+
void UpdateIndicators()
{
   // Mettre à jour ATR
   double atrBuffer[];
   if(CopyBuffer(g_atr_handle, 0, 0, 1, atrBuffer) > 0)
   {
      g_lastATR = atrBuffer[0];
   }
   
   // Mettre à jour VPIN
   g_lastVPIN = ComputeVPIN(InpVPIN_WindowBars, PERIOD_CURRENT);
   
   // Mettre à jour OBI
   g_lastOBI = ComputeOBI(InpOBI_Lookback, PERIOD_CURRENT);
   
   // Mettre à jour CVD
   g_lastCVD = ComputeCVD(InpCVD_WindowBars, PERIOD_CURRENT);
}

//+------------------------------------------------------------------+
//| Vérifie les opportunités de trading                              |
//+------------------------------------------------------------------+
void CheckTradingOpportunities()
{
   // Vérifier les conditions de trading
   if(!InpEnableTrading) return;
   
   // Vérifier le nombre maximum de positions ouvertes
   if(GetOpenPositionsCount() >= InpMaxOpenPositions) return;
   
   // Vérifier le risque journalier
   if(GetDailyRisk() >= InpMaxDailyRisk) return;
   
   // Vérifier les conditions de trading
   CheckTradingConditions();
}

//+------------------------------------------------------------------+
//| Gère les positions ouvertes                                      |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   // Mettre à jour le tableau des positions
   UpdatePositionsArray();
   
   // Gérer le trailing stop
   if(InpUseTrailingStop)
   {
      ManageTrailingStop();
   }
   
   // Gérer la sortie partielle
   if(InpUsePartialClose)
   {
      ManagePartialClose();
   }
}

//+------------------------------------------------------------------+
//| Fonction principale de l'expert                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Vérifier si c'est une nouvelle barre
   if(IsNewBar())
   {
      // Mettre à jour les indicateurs
      UpdateIndicators();
      
      // Vérifier les opportunités de trading
      CheckTradingOpportunities();
   }
   
   // Gérer les positions ouvertes à chaque tick
   ManageOpenPositions();
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calcule le VPIN (Volume-Synchronized Probability of Informed Trading) |
//+------------------------------------------------------------------+
double ComputeVPIN(int windowBars, ENUM_TIMEFRAMES timeframe)
{
   MqlRates rates[];
   double volume[];
   
   // Récupérer les données des prix et des volumes
   if(CopyRates(_Symbol, timeframe, 0, windowBars, rates) <= 0) return 0.0;
   if(CopyTickVolume(_Symbol, timeframe, 0, windowBars, volume) <= 0) return 0.0;
   
   double buyVolume = 0.0;
   double sellVolume = 0.0;
   double totalVolume = 0.0;
   
   // Calculer les volumes d'achat et de vente
   for(int i = 1; i < windowBars; i++)
   {
      if(rates[i].close > rates[i-1].close)
         buyVolume += volume[i];
      else if(rates[i].close < rates[i-1].close)
         sellVolume += volume[i];
      
      totalVolume += volume[i];
   }
   
   // Éviter la division par zéro
   if(totalVolume == 0) return 0.0;
   
   // Calculer le VPIN
   return MathAbs(buyVolume - sellVolume) / totalVolume;
}

//+------------------------------------------------------------------+
//| Calcule l'OBI (Order Book Imbalance)                             |
//+------------------------------------------------------------------+
double ComputeOBI(int lookback, ENUM_TIMEFRAMES timeframe)
{
   MqlTick last_tick;
   MqlRates rates[];
   
   // Récupérer le dernier tick
   if(!SymbolInfoTick(_Symbol, last_tick)) return 0.0;
   
   // Récupérer les données des prix
   if(CopyRates(_Symbol, timeframe, 0, lookback, rates) <= 0) return 0.0;
   
   double sumBidVol = 0.0;
   double sumAskVol = 0.0;
   
   // Simuler l'ordre book avec les données disponibles
   for(int i = 0; i < lookback; i++)
   {
      if(rates[i].close > rates[i].open)
         sumBidVol += rates[i].real_volume;
      else if(rates[i].close < rates[i].open)
         sumAskVol += rates[i].real_volume;
   }
   
   // Éviter la division par zéro
   double totalVol = sumBidVol + sumAskVol;
   if(totalVol == 0) return 0.0;
   
   // Calculer l'OBI
   return (sumBidVol - sumAskVol) / totalVol;
}

//+------------------------------------------------------------------+
//| Calcule le CVD (Cumulative Volume Delta)                         |
//+------------------------------------------------------------------+
double ComputeCVD(int windowBars, ENUM_TIMEFRAMES timeframe)
{
   MqlRates rates[];
   double volume[];
   
   // Récupérer les données des prix et des volumes
   if(CopyRates(_Symbol, timeframe, 0, windowBars, rates) <= 0) return 0.0;
   if(CopyTickVolume(_Symbol, timeframe, 0, windowBars, volume) <= 0) return 0.0;
   
   double cvd = 0.0;
   
   // Calculer le CVD
   for(int i = 0; i < windowBars; i++)
   {
      if(rates[i].close > rates[i].open)
         cvd += volume[i];
      else if(rates[i].close < rates[i].open)
         cvd -= volume[i];
   }
   
   return cvd;
}

//+------------------------------------------------------------------+
//| Vérifie les conditions de trading                                |
//+------------------------------------------------------------------+
void CheckTradingConditions()
{
   // Vérifier les signaux de trading
   bool buySignal = CheckBuySignal();
   bool sellSignal = CheckSellSignal();
   
   // Exécuter les trades si les conditions sont remplies
   if(buySignal && !sellSignal)
   {
      ExecuteTrade(1, g_lastATR); // Signal d'achat
   }
   else if(sellSignal && !buySignal)
   {
      ExecuteTrade(-1, g_lastATR); // Signal de vente
   }
}

//+------------------------------------------------------------------+
//| Vérifie le signal d'achat                                        |
//+------------------------------------------------------------------+
bool CheckBuySignal()
{
   // Conditions pour un signal d'achat
   bool condition1 = g_lastVPIN > InpVPIN_Threshold; // VPIN élevé
   bool condition2 = g_lastOBI > InpOBI_Threshold;   // Déséquilibre d'achat
   
   // Vérifier la tendance
   bool trendCondition = CheckTrend(1); // 1 pour tendance haussière
   
   return (condition1 && condition2 && trendCondition);
}

//+------------------------------------------------------------------+
//| Vérifie le signal de vente                                       |
//+------------------------------------------------------------------+
bool CheckSellSignal()
{
   // Conditions pour un signal de vente
   bool condition1 = g_lastVPIN > InpVPIN_Threshold; // VPIN élevé
   bool condition2 = g_lastOBI < -InpOBI_Threshold;  // Déséquilibre de vente
   
   // Vérifier la tendance
   bool trendCondition = CheckTrend(-1); // -1 pour tendance baissière
   
   return (condition1 && condition2 && trendCondition);
}

//+------------------------------------------------------------------+
//| Vérifie la tendance du marché                                    |
//+------------------------------------------------------------------+
bool CheckTrend(int direction)
{
   double maFast[], maSlow[];
   ArraySetAsSeries(maFast, true);
   ArraySetAsSeries(maSlow, true);
   
   // Récupérer les valeurs des moyennes mobiles
   if(CopyBuffer(g_ma_fast_handle, 0, 0, 3, maFast) < 3) return false;
   if(CopyBuffer(g_ma_slow_handle, 0, 0, 3, maSlow) < 3) return false;
   
   // Vérifier la configuration des moyennes mobiles
   if(direction > 0) // Tendance haussière
   {
      return (maFast[0] > maSlow[0] && maFast[1] > maSlow[1]);
   }
   else // Tendance baissière
   {
      return (maFast[0] < maSlow[0] && maFast[1] < maSlow[1]);
   }
}

//+------------------------------------------------------------------+
//| Exécute un trade                                                 |
//+------------------------------------------------------------------+
void ExecuteTrade(int direction, double atrVal)
{
   // Vérifier si le trading est activé
   if(!InpEnableTrading) return;
   
   // Vérifier si une position est déjà ouverte
   if(HasOpenPosition()) return;
   
   // Calculer la taille de la position
   double lotSize = CalculateLotSize(atrVal);
   if(lotSize <= 0) return;
   
   // Calculer les niveaux de stop loss et take profit
   double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   double sl = 0.0, tp = 0.0;
   CalculateSLTP(direction, price, atrVal, sl, tp);
   
   // Exécuter l'ordre
   bool success = false;
   if(direction > 0)
   {
      success = trade.Buy(lotSize, _Symbol, price, sl, tp, "Buy Signal");
   }
   else
   {
      success = trade.Sell(lotSize, _Symbol, price, sl, tp, "Sell Signal");
   }
   
   // Journalisation
   if(success)
   {
      PrintFormat("Ordre %s exécuté - Lot: %.2f, Prix: %f, SL: %f, TP: %f", 
                 (direction > 0) ? "Achat" : "Vente", 
                 lotSize, price, sl, tp);
   }
   else
   {
      PrintFormat("Erreur lors de l'exécution de l'ordre: %d", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Calcule la taille de la position                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(double atrVal)
{
   if(InpUseFixedLot)
   {
      // Vérifier que la taille du lot est valide
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      double lot = NormalizeDouble(InpLotSize, 2);
      lot = MathFloor(lot / lotStep) * lotStep;
      
      if(lot < minLot) lot = minLot;
      if(lot > maxLot) lot = maxLot;
      
      return lot;
   }
   else
   {
      // Calcul basé sur le risque
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = accountBalance * (InpRiskPercent / 100.0);
      
      // Limiter le risque par trade
      double maxRiskAmount = accountBalance * (InpMaxRiskPerTrade / 100.0);
      riskAmount = MathMin(riskAmount, maxRiskAmount);
      
      // Calculer la taille du lot en fonction du risque et du stop loss
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(tickValue == 0 || tickSize == 0 || pointValue == 0) 
         return 0.0;
      
      // Calculer la distance du stop loss en points
      double stopLossPoints = MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_BID) - 
                                     (SymbolInfoDouble(_Symbol, SYMBOL_BID) - (atrVal * InpATRMultiplierSL)));
      stopLossPoints = stopLossPoints / pointValue;
      
      // Calculer la taille du lot
      double lot = (riskAmount / (stopLossPoints * tickValue * tickSize)) * pointValue;
      
      // Normaliser la taille du lot selon les contraintes du courtier
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      lot = MathFloor(lot / lotStep) * lotStep;
      lot = MathMax(minLot, MathMin(lot, maxLot));
      
      return lot;
   }
}

//+------------------------------------------------------------------+
//| Calcule les niveaux de stop loss et take profit                  |
//+------------------------------------------------------------------+
void CalculateSLTP(int direction, double entryPrice, double atrVal, double &sl, double &tp)
{
   if(direction > 0) // Achat
   {
      sl = entryPrice - (atrVal * InpATRMultiplierSL);
      tp = entryPrice + (atrVal * InpATRMultiplierTP);
   }
   else // Vente
   {
      sl = entryPrice + (atrVal * InpATRMultiplierSL);
      tp = entryPrice - (atrVal * InpATRMultiplierTP);
   }
   
   // Ajuster les niveaux selon les exigences du courtier
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
}

//+------------------------------------------------------------------+
//| Vérifie si une position est déjà ouverte                         |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Met à jour le tableau des positions ouvertes                     |
//+------------------------------------------------------------------+
void UpdatePositionsArray()
{
   if(CheckPointer(g_openPositions) == POINTER_INVALID) return;
   
   // Vider le tableau
   g_openPositions.Clear();
   
   // Remplir avec les positions actuelles
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            PositionData *pos = new PositionData();
            pos.ticket = ticket;
            pos.entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            pos.stopLoss = PositionGetDouble(POSITION_SL);
            pos.takeProfit = PositionGetDouble(POSITION_TP);
            pos.openTime = (datetime)PositionGetInteger(POSITION_TIME);
            pos.direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
            
            g_openPositions.Add(pos);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gère le trailing stop pour les positions ouvertes                |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(CheckPointer(g_openPositions) == POINTER_INVALID) return;
   
   for(int i = 0; i < g_openPositions.Total(); i++)
   {
      PositionData *pos = g_openPositions.At(i);
      if(pos == NULL) continue;
      
      if(!PositionSelectByTicket(pos.ticket)) continue;
      
      double currentPrice = (pos.direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) 
                                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double newSL = pos.stopLoss;
      double atr = g_lastATR;
      
      if(pos.direction > 0) // Position d'achat
      {
         double distance = currentPrice - pos.entryPrice;
         if(distance > atr * InpTrailingStart)
         {
            newSL = currentPrice - (atr * InpTrailingStep);
            if(newSL > pos.stopLoss + _Point) // Ne déplacer que vers le haut
            {
               trade.PositionModify(pos.ticket, newSL, pos.takeProfit);
               pos.stopLoss = newSL;
            }
         }
      }
      else // Position de vente
      {
         double distance = pos.entryPrice - currentPrice;
         if(distance > atr * InpTrailingStart)
         {
            newSL = currentPrice + (atr * InpTrailingStep);
            if(newSL < pos.stopLoss - _Point || pos.stopLoss == 0) // Ne déplacer que vers le bas
            {
               trade.PositionModify(pos.ticket, newSL, pos.takeProfit);
               pos.stopLoss = newSL;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gère la sortie partielle des positions                           |
//+------------------------------------------------------------------+
void ManagePartialClose()
{
   if(CheckPointer(g_openPositions) == POINTER_INVALID) return;
   
   for(int i = 0; i < g_openPositions.Total(); i++)
   {
      PositionData *pos = g_openPositions.At(i);
      if(pos == NULL) continue;
      
      if(!PositionSelectByTicket(pos.ticket)) continue;
      
      double currentPrice = (pos.direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) 
                                              : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      double profitInATR = 0.0;
      if(pos.direction > 0)
         profitInATR = (currentPrice - pos.entryPrice) / g_lastATR;
      else
         profitInATR = (pos.entryPrice - currentPrice) / g_lastATR;
      
      // Vérifier si le premier niveau de prise de bénéfices est atteint
      if(profitInATR >= InpPartialTP1 && PositionGetDouble(POSITION_VOLUME) > 0.01)
      {
         double volumeToClose = NormalizeDouble(PositionGetDouble(POSITION_VOLUME) * (InpPartialCloseAt1 / 100.0), 2);
         if(volumeToClose >= 0.01)
         {
            trade.PositionClosePartial(pos.ticket, volumeToClose);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Retourne le nombre de positions ouvertes                         |
//+------------------------------------------------------------------+
int GetOpenPositionsCount()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calcule le risque journalier actuel                              |
//+------------------------------------------------------------------+
double GetDailyRisk()
{
   double dailyPL = 0.0;
   
   // Parcourir l'historique de la journée
   HistorySelect(TimeCurrent() - 86400, TimeCurrent());
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol &&
            HistoryDealGetInteger(ticket, DEAL_MAGIC) == InpMagicNumber)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                          HistoryDealGetDouble(ticket, DEAL_SWAP) +
                          HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            
            dailyPL += profit;
         }
      }
   }
   
   // Calculer le pourcentage de risque par rapport au solde du compte
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(accountBalance > 0)
   {
      return (dailyPL / accountBalance) * 100.0;
   }
   
   return 0.0;
}

//--- Include des bibliothèques nécessaires
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Arrays\ArrayObj.mth>
#include <Math\Stat\Math.mqh>

//--- Paramètres de trading avancés
input group "=== GESTION DU RISQUE ==="
input double   InpRiskPercent       = 1.0;       // Pourcentage du capital à risquer par trade (%)
input double   InpMaxRiskPerTrade   = 2.0;       // Risque maximum par trade (% du capital)
input double   InpMaxDailyRisk      = 5.0;       // Risque maximum journalier (% du capital)
input bool     InpUseATRForSL       = true;      // Utiliser ATR pour le Stop Loss
input double   InpATRMultiplierSL   = 1.5;       // Multiplicateur ATR pour le Stop Loss
input double   InpATRMultiplierTP   = 3.0;       // Multiplicateur ATR pour le Take Profit

input group "=== GESTION DES POSITIONS ==="
input bool     InpUsePartialClose   = true;      // Activer la sortie partielle
input int      InpPartialCloseAt1   = 50;        // % de la position à fermer au 1er TP
input double   InpPartialTP1        = 1.0;       // Niveau du 1er TP (en multiples d'ATR)
input double   InpPartialTP2        = 2.0;       // Niveau du 2ème TP (en multiples d'ATR)
input bool     InpUseTrailingStop   = true;      // Activer le trailing stop
input double   InpTrailingStart     = 1.5;       // Niveau de départ du trailing (en multiples d'ATR)
input double   InpTrailingStep      = 0.5;       // Pas du trailing (en multiples d'ATR)

input group "=== PARAMETRES DES INDICATEURS ==="
input ENUM_TIMEFRAMES InpSpikeTimeframe = PERIOD_M5;  // Timeframe pour le trading
input int      InpATR_Period        = 14;        // Période de l'ATR
input int      InpADXPeriod         = 14;        // Période ADX pour la force de la tendance
input int      InpTrendMAPeriod1    = 20;        // Période MA courte
input int      InpTrendMAPeriod2    = 50;        // Période MA longue
input int      InpVPIN_WindowBars   = 500;       // Fenêtre pour le calcul du VPIN
input int      InpOBI_Lookback      = 300;       // Lookback pour l'OBI
input int      InpCVD_WindowBars    = 500;       // Fenêtre pour le calcul du CVD
input double   InpVPIN_Threshold    = 0.60;      // Seuil VPIN pour les signaux
input double   InpOBI_Threshold     = 0.55;      // Seuil OBI pour les signaux
input int      InpMinBarsRequired   = 600;       // Nombre minimum de bougies nécessaires
input bool     InpEnableTrading     = true;      // Activer le trading
input long     InpMagicNumber       = 123456;    // Magic Number pour les ordres
input group "=== VISUALS ==="
input bool     InpShowVisuals           = true;   // Afficher OB, trend, fibo, SR
input color    InpColorOB_Bull          = clrLime;
input color    InpColorOB_Bear          = clrRed;
input color    InpColorSR               = clrAqua;
input color    InpColorTrend            = clrYellow;
input color    InpColorSpikeArrow       = clrMagenta;

// Liste des symboles prioritaires
const string PRIORITY_SYMBOLS[] = {
   "Volatility 10 Index", "Volatility 25 Index", "Volatility 50 Index", 
   "Volatility 75 Index", "Volatility 100 Index", "Volatility 10 (1s) Index", 
   "Volatility 25 (1s) Index", "Volatility 50 (1s) Index", "Volatility 75 (1s) Index", 
   "Volatility 100 (1s) Index", "Volatility 150 (2s) Index", "Volatility 250 (2s) Index", 
   "Boom 300 Index", "Boom 500 Index", "Boom 600 Index", "Boom 900 Index", "Boom 1000 Index", 
   "Crash 150 Index", "Crash 300 Index", "Crash 500 Index", "Crash 600 Index", "Crash 900 Index", 
   "Crash 1000 Index", "Step Index 1", "Step Index 2", "Step Index 3", "Step Index 4", "Step Index 5"
};

// internal handles
int g_atr_handle = INVALID_HANDLE;
int g_adx_handle = INVALID_HANDLE;
int g_ma_fast_handle = INVALID_HANDLE;
int g_ma_slow_handle = INVALID_HANDLE;
int g_rsi_handle = INVALID_HANDLE;
int g_ma_trend1_handle = INVALID_HANDLE;
int g_ma_trend2_handle = INVALID_HANDLE;

// global state
datetime g_lastBarTime = 0;
double   g_lastVPIN    = 0.0;
double   g_lastOBI     = 0.0;
double   g_lastCVD     = 0.0;
int      g_drawCount   = 0;
bool     g_hasOpenPosition = false;  // Pour suivre si une position est ouverte
CArrayObj *g_openPositions = NULL;   // Tableau des positions ouvertes

// Variables pour le suivi journalier
double g_dailyPL = 0.0;
bool g_tradingActive = true;

//+------------------------------------------------------------------+
//| Fonction d'initialisation                                        |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("Fx_robot v5.0 - Initialisation...");
   
   // Initialiser les handles des indicateurs
   g_atr_handle = iATR(_Symbol, InpSpikeTimeframe, InpATR_Period);
   g_adx_handle = iADX(_Symbol, InpSpikeTimeframe, InpADXPeriod);
   g_ma_fast_handle = iMA(_Symbol, InpSpikeTimeframe, InpTrendMAPeriod1, 0, MODE_SMA, PRICE_CLOSE);
   g_ma_slow_handle = iMA(_Symbol, InpSpikeTimeframe, InpTrendMAPeriod2, 0, MODE_SMA, PRICE_CLOSE);
   g_rsi_handle = iRSI(_Symbol, InpSpikeTimeframe, 14);
   
   // Initialiser les handles pour l'analyse multi-timeframe
   g_ma_trend1_handle = iMA(_Symbol, InpTrendTF1, InpTrendMAPeriod1, 0, MODE_SMA, PRICE_CLOSE);
   g_ma_trend2_handle = iMA(_Symbol, InpTrendTF1, InpTrendMAPeriod2, 0, MODE_SMA, PRICE_CLOSE);
   
   // Vérifier que tous les handles sont valides
   if(g_atr_handle == INVALID_HANDLE || g_adx_handle == INVALID_HANDLE || 
      g_ma_fast_handle == INVALID_HANDLE || g_ma_slow_handle == INVALID_HANDLE || 
      g_rsi_handle == INVALID_HANDLE || g_ma_trend1_handle == INVALID_HANDLE || 
      g_ma_trend2_handle == INVALID_HANDLE)
   {
      Print("Erreur: échec de l'initialisation des indicateurs");
      return(INIT_FAILED);
   }
   
   // Initialiser le tableau des positions ouvertes
   if(g_openPositions == NULL)
      g_openPositions = new CArrayObj();
   else
      g_openPositions.Clear();
   
   // Configurer les paramètres de trading
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   // Démarrer le timer pour vérifier les nouvelles bougies (1s)
   EventSetTimer(1);
   
   // Nettoyer les éléments visuels précédents
   if(InpShowVisuals) 
      DeleteAllEAObjects();
   
   // Afficher les paramètres dans le journal
   Print("=== PARAMETRES DU ROBOT ===");
   PrintFormat("Risque par trade: %.1f%% (Max: %.1f%% par jour)", InpRiskPercent, InpMaxDailyRisk);
   PrintFormat("Multiplicateurs: SL=%.1fATR, TP=%.1fATR", InpATRMultiplierSL, InpATRMultiplierTP);
   PrintFormat("Sortie partielle: %s (%.0f%% @ %.1fATR, reste @ %.1fATR)", 
               InpUsePartialClose ? "Activée" : "Désactivée", 
               InpPartialCloseAt1, InpPartialTP1, InpPartialTP2);
   PrintFormat("Trailing stop: %s (Départ: %.1fATR, Pas: %.1fATR)", 
               InpUseTrailingStop ? "Activé" : "Désactivé", 
               InpTrailingStart, InpTrailingStep);
   
   Print("Initialisation terminée avec succès");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
   if(g_ma_fast_handle != INVALID_HANDLE) IndicatorRelease(g_ma_fast_handle);
   if(g_ma_slow_handle != INVALID_HANDLE) IndicatorRelease(g_ma_slow_handle);
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
   EventKillTimer();
   if(InpShowVisuals) DeleteAllEAObjects();
   Print("Fx_robot v2.3 - Deinit");
}

//+------------------------------------------------------------------+
//| OnTimer - main loop (chaque seconde)                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(!InpEnableTrading) return;
   // travailler uniquement sur nouvelles bougies
   datetime t = iTime(_Symbol, InpSpikeTimeframe, 0);
   if(t == g_lastBarTime) return;
   g_lastBarTime = t;
   long bars = GetBarsCount(_Symbol, InpSpikeTimeframe);
   if(bars < InpMinBarsRequired)
   {
      PrintFormat("Attente des données : bars=%d < required=%d", (int)bars, InpMinBarsRequired);
      return;
   }
   // Calcul des indicateurs/proxies institutionnels
   double atr = GetCurrentATR(g_atr_handle);
   double vpin = ComputeVPIN(InpVPIN_WindowBars, InpSpikeTimeframe);
   double obi  = ComputeOBI(InpOBI_Lookback, InpSpikeTimeframe);
   double cvd  = ComputeCVD(InpCVD_WindowBars, InpSpikeTimeframe);
   double adx = GetCurrentADX(g_adx_handle);
   double ma_fast = GetCurrentMA(g_ma_fast_handle);
   double ma_slow = GetCurrentMA(g_ma_slow_handle);
   double rsi = GetCurrentRSI(g_rsi_handle);
   bool liquidity_sweep = DetectLiquiditySweep(InpSpikeTimeframe, atr, 2.5);
   int fvg = DetectFVG(InpSpikeTimeframe);
   g_lastVPIN = vpin; g_lastOBI = obi; g_lastCVD = cvd;
   // Décision de trading : Buy uniquement sur Boom, Sell uniquement sur Crash
   int direction = 0; // +1 BUY Boom, -1 SELL Crash
   
   // Log des valeurs des indicateurs
   PrintFormat("VPIN=%.2f (Seuil: %.2f), OBI=%.2f (Seuil: ±%.2f), CVD=%.2f, ATR=%.5f, ADX=%.2f, MA Fast=%.5f, MA Slow=%.5f, RSI=%.2f", 
               vpin, InpVPIN_Threshold, obi, InpOBI_Threshold, cvd, atr, adx, ma_fast, ma_slow, rsi);
   
   // Vérifier si le symbole est dans la liste des priorités
   if(!IsPrioritySymbol())
   {
      // N'exécuter le code qu'une seule fois par bougie pour éviter de surcharger les logs
      static datetime lastWarningTime = 0;
      if(TimeCurrent() - lastWarningTime > 60) // Afficher le message max toutes les 60 secondes
      {
         Print("Attention: Le symbole actuel n'est pas dans la liste des symboles prioritaires.");
         lastWarningTime = TimeCurrent();
      }
      return;
   }
   
   // Vérifier si un trade est déjà en cours
   if(HasOpenPosition())
   {
      Print("Un trade est déjà en cours. Attente de sa clôture.");
      return;
   }
   
   // Vérification des conditions pour un signal fort
   if(vpin >= InpVPIN_Threshold * 1.2) // Seuil plus élevé pour les signaux forts
   {
      Print("Condition VPIN forte détectée");
      
      // Signal d'achat (Boom) - conditions renforcées
      if(obi >= InpOBI_Threshold * 1.3 && cvd > 0.2 && IsUptrend()) 
      {
         direction = +1;
         Print("Signal ACHAT FORT (BOOM) détecté - Conditions réunies:");
         PrintFormat("  - VPIN élevé: %.2f (Seuil: %.2f)", vpin, InpVPIN_Threshold * 1.2);
         PrintFormat("  - OBI haussier fort: %.2f (Seuil: %.2f)", obi, InpOBI_Threshold * 1.3);
         PrintFormat("  - CVD positif: %.2f", cvd);
      }
      // Signal de vente (Crash) - conditions renforcées
      else if(obi <= -InpOBI_Threshold * 1.3 && cvd < -0.2 && !IsUptrend()) 
      {
         direction = -1;
         Print("Signal VENTE FORTE (CRASH) détecté - Conditions réunies:");
         PrintFormat("  - VPIN élevé: %.2f (Seuil: %.2f)", vpin, InpVPIN_Threshold * 1.2);
         PrintFormat("  - OBI baissier fort: %.2f (Seuil: %.2f)", obi, -InpOBI_Threshold * 1.3);
         PrintFormat("  - CVD négatif: %.2f", cvd);
      }
      // Gestion des FVG (Fair Value Gaps) si activé et avec confirmation
      else if(liquidity_sweep && fvg != 0) 
      {
         // Vérifier la tendance pour confirmer le signal FVG
         if((fvg > 0 && IsUptrend()) || (fvg < 0 && !IsUptrend()))
         {
            direction = fvg;
            Print("Signal FVG confirmé par la tendance - Direction: ", (direction > 0) ? "BUY" : "SELL");
         }
      }
      else
      {
         Print("Aucun signal fort détecté - Conditions non remplies:");
         if(obi < InpOBI_Threshold * 1.3 && obi > -InpOBI_Threshold * 1.3) 
            PrintFormat("  - OBI %.2f n'atteint pas le seuil de ±%.2f", obi, InpOBI_Threshold * 1.3);
         if((direction == 1 && cvd <= 0.2) || (direction == -1 && cvd >= -0.2))
            Print("  - CVD ", cvd, " pas assez significatif (|CVD| < 0.2)");
      }
   }
   else
   {
      PrintFormat("VPIN %.2f trop bas pour le trading (seuil: %.2f)", vpin, InpVPIN_Threshold * 1.2);
   }
   // Dessins si activés
   if(InpShowVisuals)
   {
      DrawOrderBlocksAroundLastBars(12, 20);
      DrawSimpleTrendline(30);
      DrawFiboOnLastMove(60);
      DrawSRZones(120, 10);
   }
   // Affichage flèche prédictive
   if(direction != 0) DrawSpikeArrow(direction);
   // Exécution (si permissions et conditions remplies)
   if(direction != 0 && CanPlaceNewOrder())
   {
      Print("Tentative d'exécution du trade...");
      
      // Vérifier qu'aucune position n'est déjà ouverte (sécurité supplémentaire)
      if(!HasOpenPosition())
      {
         PrintFormat("Exécution du trade - Direction: %s", (direction > 0) ? "BUY (BOOM)" : "SELL (CRASH)");
         ExecuteTrade(direction, atr);
      }
      else
      {
         Print("Trade non exécuté - Une position est déjà ouverte");
      }
   }
}

//+------------------------------------------------------------------+
//| Ajoute une zone de volume au graphique                          |
//+------------------------------------------------------------------+
void AddVolumeProfile()
{
   // Créer la zone de volume si non existante
   string vpName = "FXPRO_" + (string)InpMagicNumber + "_VP";
   
   // Supprimer l'objet existant s'il existe
   ObjectDelete(0, vpName);
   
   // Obtenir les prix hauts et bas pour la période
   datetime end = TimeCurrent();
   datetime start = end - PeriodSeconds(PERIOD_D1) * 5; // 5 jours de données
   
   // Obtenir les prix hauts et bas pour la période
   double high = iHigh(_Symbol, PERIOD_D1, iHighest(_Symbol, PERIOD_D1, MODE_HIGH, 5, 0));
   double low = iLow(_Symbol, PERIOD_D1, iLowest(_Symbol, PERIOD_D1, MODE_LOW, 5, 0));
   
   // Créer le rectangle avec les coordonnées directement
   if(!ObjectCreate(0, vpName, OBJ_RECTANGLE, 0, start, high, end, low))
   {
      Print("Erreur création zone de volume: ", GetLastError());
      return;
   }
   
   // Définir les propriétés de base
   ObjectSetInteger(0, vpName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, vpName, OBJPROP_BACK, true);
   ObjectSetInteger(0, vpName, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, vpName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, vpName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, vpName, OBJPROP_BGCOLOR, clrDodgerBlue);
   ObjectSetInteger(0, vpName, OBJPROP_FILL, true);
   ObjectSetInteger(0, vpName, OBJPROP_SELECTABLE, false);
   
   Print("Zone de volume ajoutée du ", TimeToString(start), " au ", TimeToString(end));
}

//+------------------------------------------------------------------+
//| Fonctions utilitaires                                            |
//+------------------------------------------------------------------+
long GetBarsCount(string symbol, ENUM_TIMEFRAMES tf)
{
   long cnt = SeriesInfoInteger(symbol, tf, SERIES_BARS_COUNT);
   if(cnt < 0) cnt = 0;
   return cnt;
}

double GetCurrentATR(int handle)
{
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[];
   if(CopyBuffer(handle, 0, 0, 1, buf) <= 0) return 0.0;
   return buf[0];
}

// VPIN proxy
double ComputeVPIN(int windowBars, ENUM_TIMEFRAMES tf)
{
   if(windowBars <= 10) return 0.0;
   MqlRates rates[];
   int copied = CopyRates(_Symbol, tf, 1, windowBars, rates);
   if(copied <= 0) return 0.0;
   double buyVol=0.0, sellVol=0.0, totalVol=0.0;
   for(int i=0; i<copied; i++)
   {
      long tv = rates[i].tick_volume;
      totalVol += (double)tv;
      if(rates[i].close > rates[i].open) buyVol += (double)tv;
      else if(rates[i].close < rates[i].open) sellVol += (double)tv;
      else { buyVol += (double)tv*0.5; sellVol += (double)tv*0.5; }
   }
   if(totalVol <= 0.0) return 0.0;
   return MathAbs(buyVol - sellVol) / totalVol;
}

// OBI proxy
double ComputeOBI(int lookbackBars, ENUM_TIMEFRAMES tf)
{
   if(lookbackBars <= 10) return 0.0;
   MqlRates rates[];
   int copied = CopyRates(_Symbol, tf, 1, lookbackBars, rates);
   if(copied <= 0) return 0.0;
   double buyVol=0.0, sellVol=0.0;
   for(int i=0; i<copied; i++)
   {
      long tv = rates[i].tick_volume;
      if(rates[i].close > rates[i].open) buyVol += (double)tv;
      else if(rates[i].close < rates[i].open) sellVol += (double)tv;
   }
   double total = buyVol + sellVol;
   if(total <= 0.0) return 0.0;
   return (buyVol - sellVol) / total;
}

// CVD proxy
double ComputeCVD(int windowBars, ENUM_TIMEFRAMES tf)
{
   if(windowBars <= 5) return 0.0;
   MqlRates rates[];
   int copied = CopyRates(_Symbol, tf, 1, windowBars, rates);
   if(copied <= 0) return 0.0;
   double cvd = 0.0;
   for(int i=0; i<copied; i++)
   {
      double sign = 0.0;
      if(rates[i].close > rates[i].open) sign = 1.0;
      else if(rates[i].close < rates[i].open) sign = -1.0;
      cvd += sign * (double)rates[i].tick_volume;
   }
   return cvd;
}

bool DetectLiquiditySweep(ENUM_TIMEFRAMES tf, double atr_val, double wickMult)
{
   if(atr_val <= 0.0) return false;
   MqlRates r[];
   if(CopyRates(_Symbol, tf, 1, 2, r) < 2) return false;
   double high = r[0].high, low = r[0].low, open = r[0].open, close = r[0].close;
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;
   if(upperWick > wickMult * atr_val || lowerWick > wickMult * atr_val) return true;
   return false;
}

int DetectFVG(ENUM_TIMEFRAMES tf)
{
   MqlRates r[];
   if(CopyRates(_Symbol, tf, 1, 3, r) < 3) return 0;
   double prevClose = r[1].close;
   double curOpen   = r[0].open;
   if(curOpen - prevClose > 0.0) return +1;
   if(prevClose - curOpen > 0.0) return -1;
   return 0;
}

// ------------------ Visuals (OB, Trend, Fibo, SR, Flèches) ------------------
void DeleteAllEAObjects()
{
   string prefix = "FXPRO_" + (string)InpMagicNumber + "_";
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0) ObjectDelete(0, name);
   }
}

void DrawOrderBlocksAroundLastBars(int lookbackBars, int widthBars)
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   
   if(CopyRates(_Symbol, InpSpikeTimeframe, 0, lookbackBars, r) < lookbackBars) return;
   
   string prefix = "FXPRO_" + (string)InpMagicNumber + "_OB_";
   for(int i=0; i<lookbackBars-1; i++)
   {
      double body = MathAbs(r[i].close - r[i].open);
      double range = r[i].high - r[i].low;
      if(range <= 0) continue;
      if(body >= 0.6 * range)
      {
         datetime t_high = r[i].time;
         double price_high = r[i].high;
         double price_low  = r[i].low;
         string name = prefix + IntegerToString((int)t_high);
         if(ObjectFind(0, name) == -1)
         {
            datetime t2 = t_high + (datetime)(widthBars * PeriodSeconds(InpSpikeTimeframe));
            if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t_high, price_high, t2, price_low))
               Print("ObjectCreate OB failed: ", GetLastError());
            color clr = (r[i].close > r[i].open) ? InpColorOB_Bull : InpColorOB_Bear;
            ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
            ObjectSetInteger(0, name, OBJPROP_BACK, true);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         }
      }
   }
}

void DrawSimpleTrendline(int lookback)
{
   MqlRates r[];
   if(CopyRates(_Symbol, InpSpikeTimeframe, 1, lookback, r) <= 0) return;
   double maxv = -1e12; int idxMax = -1;
   double minv = 1e12;  int idxMin = -1;
   for(int i=0; i<lookback; i++)
   {
      if(r[i].high > maxv) { maxv = r[i].high; idxMax = i; }
      if(r[i].low  < minv) { minv = r[i].low;  idxMin = i; }
   }
   if(idxMax >= 0 && idxMin >= 0)
   {
      datetime t1 = r[idxMax].time; double p1 = r[idxMax].high;
      datetime t2 = r[idxMin].time; double p2 = r[idxMin].low;
      string name = "FXPRO_" + (string)InpMagicNumber + "_TREND";
      if(ObjectFind(0, name) != -1) ObjectDelete(0, name);
      if(!ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2))
         Print("ObjectCreate TREND failed: ", GetLastError());
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorTrend);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, InpSpikeTimeframe);
   }
}

void DrawFiboOnLastMove(int lookback)
{
   MqlRates r[];
   if(CopyRates(_Symbol, InpSpikeTimeframe, 1, lookback, r) <= 0) return;
   double maxv = -1e12; int imax = -1;
   double minv = 1e12;  int imin = -1;
   for(int i=0; i<lookback; i++)
   {
      if(r[i].high > maxv) { maxv = r[i].high; imax = i; }
      if(r[i].low  < minv) { minv = r[i].low; imin = i; }
   }
   if(imax < 0 || imin < 0) return;
   datetime t_high = r[imax].time; datetime t_low = r[imin].time;
   double price_high = r[imax].high; double price_low = r[imin].low;
   string name = "FXPRO_" + (string)InpMagicNumber + "_FIBO";
   if(ObjectFind(0, name) != -1) ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_FIBO, 0, t_low, price_low, t_high, price_high))
      Print("ObjectCreate FIBO failed: ", GetLastError());
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, InpSpikeTimeframe);
}

void DrawSRZones(int lookback, double zonePips)
{
   MqlRates r[];
   // Utiliser le timeframe H4 pour les zones de support/résistance
   if(CopyRates(_Symbol, PERIOD_H4, 0, lookback, r) < lookback) return;
   int buckets = 40;
   double high = r[0].high, low = r[0].low;
   for(int i=1; i<lookback; i++) { if(r[i].high > high) high = r[i].high; if(r[i].low < low) low = r[i].low; }
   double range = high - low;
   if(range <= 0.0) return;
   double step = range / buckets;
   double freq[];
   ArrayResize(freq, buckets);
   for(int i=0; i<buckets; i++) freq[i] = 0.0;
   for(int i=0; i<lookback; i++)
   {
      int idx = (int)((r[i].close - low) / step);
      if(idx < 0) idx = 0; if(idx >= buckets) idx = buckets - 1;
      freq[idx] += 1.0;
   }
   for(int i=0; i<buckets; i++)
   {
      if(freq[i] >= 3.0)
      {
         double price_center = low + (i + 0.5) * step;
         string name = "FXPRO_" + (string)InpMagicNumber + "_SR_" + IntegerToString(i);
         double top = price_center + zonePips * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         double bot = price_center - zonePips * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         if(ObjectFind(0, name) != -1) ObjectDelete(0, name);
         datetime t0 = TimeCurrent();
         datetime t1 = t0 + (datetime)(PeriodSeconds(PERIOD_H4) * 10);
         if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, t0, top, t1, bot))
            Print("ObjectCreate SR failed: ", GetLastError());
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorSR);
         ObjectSetInteger(0, name, OBJPROP_BGCOLOR, InpColorSR);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      }
   }
}

void DrawSpikeArrow(int direction)
{
   string name = "FXPRO_" + (string)InpMagicNumber + "_ARW_" + IntegerToString(g_drawCount);
   g_drawCount++;
   double price = iClose(_Symbol, InpSpikeTimeframe, 0);
   datetime t = iTime(_Symbol, InpSpikeTimeframe, 0);
   if(ObjectCreate(0, name, OBJ_ARROW, 0, t, price))
      ObjectSetInteger(0, name, OBJPROP_COLOR, InpColorSpikeArrow);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (direction>0)?233:234);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, InpSpikeTimeframe);
}

// ------------------ Gestion des trades ------------------
bool CanPlaceNewOrder()
{
   return true;
}

// Compter positions ouvertes selon direction
int CountOpenPositions(int direction)
{
   int count = 0;
   int total = PositionsTotal();
   
   for(int i=0; i<total; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         string symbol = PositionGetString(POSITION_SYMBOL);
         long magic = PositionGetInteger(POSITION_MAGIC);
         if(symbol == _Symbol && magic == InpMagicNumber)
         {
            long posType = PositionGetInteger(POSITION_TYPE);
            if(direction > 0 && posType == POSITION_TYPE_BUY) count++;
            if(direction < 0 && posType == POSITION_TYPE_SELL) count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Calcule la taille de position optimale basée sur le risque       |
//+------------------------------------------------------------------+
double CalculateLotSize(double atr_val, double stopLossPips)
{
   // Vérifier les paramètres d'entrée
   if(atr_val <= 0 || stopLossPips <= 0 || InpRiskPercent <= 0)
   {
      Print("Paramètres de calcul de lot invalides");
      return 0.0;
   }
   
   // Récupérer les informations du symbole
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Calculer la valeur du pip en fonction de la devise du compte
   double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * 
                    (SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) / 
                     SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   
   // Calculer le capital disponible pour le trading
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   // Utiliser le plus petit entre le solde et l'équité pour être conservateur
   double accountValue = MathMin(balance, equity);
   
   // Calculer le montant à risquer en fonction du pourcentage de risque
   double riskAmount = accountValue * (InpRiskPercent / 100.0);
   
   // Limiter le risque maximum par trade
   double maxRiskAmount = accountValue * (InpMaxRiskPerTrade / 100.0);
   riskAmount = MathMin(riskAmount, maxRiskAmount);
   
   // Calculer la valeur du stop loss en points
   double stopLossPoints = stopLossPips * (point / SymbolInfoDouble(_Symbol, SYMBOL_POINT));
   
   // Calculer la taille de position en fonction du risque
   double lotSize = (riskAmount / (stopLossPips * pipValue));
   
   // Ajuster selon les contraintes du courtier
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   
   // Vérifier la marge disponible
   double marginRequired = 0.0;
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double margin = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
   
   if(margin > 0)
   {
      marginRequired = lotSize * margin * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      if(marginRequired > freeMargin)
      {
         // Ajuster le lot pour correspondre à la marge disponible
         lotSize = MathFloor((freeMargin * 0.95) / (margin * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE) / lotStep)) * lotStep;
         Print("Avertissement: Marge insuffisante. Taille de lot réduite à ", lotSize);
      }
   }
   
   // Journaliser les détails du calcul
   PrintFormat("Calcul du lot: Risque=%.2f%%, StopLoss=%.1f pips, TailleLot=%.2f, MargeReq=%.2f, MargeDispo=%.2f", 
               InpRiskPercent, stopLossPips, lotSize, marginRequired, freeMargin);
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Analyse de tendance multi-timeframe et multi-indicateurs         |
//+------------------------------------------------------------------+
int AnalyzeTrend()
{
   // 1 = Tendance haussière, -1 = Tendance baissière, 0 = Pas de tendance claire
   
   // 1. Vérifier la force de la tendance avec ADX
   double adxBuffer[];
   double plusDI[], minusDI[];
   ArraySetAsSeries(adxBuffer, true);
   ArraySetAsSeries(plusDI, true);
   ArraySetAsSeries(minusDI, true);
   
   // Récupérer les valeurs ADX
   if(CopyBuffer(g_adx_handle, 0, 0, 3, adxBuffer) <= 0 ||
      CopyBuffer(g_adx_handle, 1, 0, 3, plusDI) <= 0 ||
      CopyBuffer(g_adx_handle, 2, 0, 3, minusDI) <= 0)
   {
      Print("Erreur lors de la récupération des données ADX");
      return 0;
   }
   
   double adx = adxBuffer[0];
   double diPlus = plusDI[0];
   double diMinus = minusDI[0];
   
   // Vérifier si la tendance est suffisamment forte
   bool strongTrend = (adx > InpADXThreshold);
   
   // 2. Analyse des moyennes mobiles sur plusieurs timeframes
   int trendScore = 0;
   
   // Timeframe court terme (M15)
   double maShort[], maLong[];
   ArraySetAsSeries(maShort, true);
   ArraySetAsSeries(maLong, true);
   
   // Récupérer les MA pour le court terme
   if(CopyBuffer(g_ma_trend1_handle, 0, 0, 3, maShort) <= 0 ||
      CopyBuffer(g_ma_trend2_handle, 0, 0, 3, maLong) <= 0)
   {
      Print("Erreur lors de la récupération des MA court terme");
      return 0;
   }
   
   // Vérifier l'alignement des MA
   if(maShort[0] > maLong[0] && maShort[1] > maLong[1] && maShort[2] > maLong[2])
      trendScore += 1; // Tendance haussière
   else if(maShort[0] < maLong[0] && maShort[1] < maLong[1] && maShort[2] < maLong[2])
      trendScore -= 1; // Tendance baissière
   
   // 3. Vérifier la pente des MA
   double maSlope = (maShort[0] - maShort[2]) / 2.0; // Pente sur 2 périodes
   double maSlopePercent = (maSlope / maShort[1]) * 100.0;
   
   // Ajouter au score en fonction de la pente
   if(maSlopePercent > 0.05) trendScore += 1;
   else if(maSlopePercent < -0.05) trendScore -= 1;
   
   // 4. Vérifier le RSI pour la survente/surachat
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(g_rsi_handle, 0, 0, 2, rsi) <= 0)
   {
      Print("Erreur lors de la récupération du RSI");
      return 0;
   }
   
   // Ajuster le score en fonction du RSI
   if(rsi[0] > 70) trendScore -= 1;  // Surachat, potentiel retournement baissier
   else if(rsi[0] < 30) trendScore += 1;  // Survente, potentiel retournement haussier
   
   // 5. Vérifier la tendance sur des timeframes plus élevés
   // (Implémentation simplifiée - dans une version complète, nous utiliserions des indicateurs sur H1 et H4)
   
   // Décision finale
   if(strongTrend && trendScore >= 2) 
      return 1;  // Forte tendance haussière
   else if(strongTrend && trendScore <= -2) 
      return -1; // Forte tendance baissière
   else if(trendScore >= 1) 
      return 1;  // Tendance haussière modérée
   else if(trendScore <= -1) 
      return -1; // Tendance baissière modérée
      
   return 0; // Pas de tendance claire
}

//+------------------------------------------------------------------+
//| Vérifie si on a déjà une position ouverte                        |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Vérifie si le symbole actuel est dans la liste des prioritaires  |
//+------------------------------------------------------------------+
bool IsPrioritySymbol()
{
   string currentSymbol = _Symbol;
   for(int i = 0; i < ArraySize(PRIORITY_SYMBOLS); i++)
   {
      if(currentSymbol == PRIORITY_SYMBOLS[i])
         return true;
   }
   Print("Symbole ", currentSymbol, " n'est pas dans la liste des symboles prioritaires");
   return false;
}

//+------------------------------------------------------------------+
//| Exécute un trade avec gestion avancée du risque                  |
//+------------------------------------------------------------------+
void ExecuteTrade(int direction, double atrVal)
{
   // Vérifications de base
   if(direction == 0 || atrVal <= 0) 
   {
      Print("Paramètres de trade invalides");
      return;
   }
   
   // Vérifier le nombre maximal de positions ouvertes
   if(CountOpenPositions() >= InpMaxOpenPositions)
   {
      Print("Nombre maximum de positions ouvertes atteint (", InpMaxOpenPositions, ")");
      return;
   }
   
   // Vérifier le risque journalier
   if(!CheckDailyRisk())
   {
      Print("Risque journalier maximum atteint");
      return;
   }
   
   // Analyser la tendance actuelle
   int trendDirection = AnalyzeTrend();
   
   // Vérifier la cohérence avec la tendance
   if((direction > 0 && trendDirection < 0) || (direction < 0 && trendDirection > 0))
   {
      Print("Trade rejeté : contre-tendance détectée");
      return;
   }
   
   // Préparer les paramètres du trade
   string tradeType = (direction > 0) ? "BUY" : "SELL";
   double price = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) 
                                 : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Calculer les niveaux de stop loss et take profit
   double stopLossPips = atrVal * InpATRMultiplierSL / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double takeProfitPips = atrVal * InpATRMultiplierTP / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   double stopLoss = (direction > 0) ? price - (atrVal * InpATRMultiplierSL) 
                                    : price + (atrVal * InpATRMultiplierSL);
   
   double takeProfit = (direction > 0) ? price + (atrVal * InpATRMultiplierTP) 
                                      : price - (atrVal * InpATRMultiplierTP);
   
   // Calculer la taille de position en fonction du risque
   double lotSize = CalculateLotSize(atrVal, stopLossPips);
   
   if(lotSize <= 0)
   {
      Print("Erreur: Taille de lot invalide calculée: ", lotSize);
      return;
   }
   
   // Journalisation des paramètres du trade
   Print("=== NOUVEAU TRADE ===");
   PrintFormat("Symbole: %s, Direction: %s, Prix: %.5f", _Symbol, tradeType, price);
   PrintFormat("ATR: %.5f, StopLoss: %.5f (%.1f pips), TakeProfit: %.5f (%.1f pips)", 
               atrVal, stopLoss, stopLossPips, takeProfit, takeProfitPips);
   PrintFormat("Taille position: %.2f lots (risque: %.2f%% du capital)", 
               lotSize, InpRiskPercent);
   
   // Configurer les paramètres de trading
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10); // Déviation maximale en points
   trade.SetTypeFilling(ORDER_FILLING_FOK); // Remplissage immédiat ou annulation
   
   // Exécuter l'ordre
   bool orderPlaced = false;
   
   if(InpUsePartialClose)
   {
      // Calculer les niveaux de sortie partielle
      double partialTP1 = (direction > 0) ? price + (atrVal * InpPartialTP1) 
                                        : price - (atrVal * InpPartialTP1);
      
      // Exécuter l'ordre principal avec le TP final
      orderPlaced = (direction > 0) ? 
         trade.Buy(lotSize, _Symbol, price, stopLoss, takeProfit, "FxPro BUY") :
         trade.Sell(lotSize, _Symbol, price, stopLoss, takeProfit, "FxPro SELL");
      
      // Si l'ordre est passé avec succès, ajouter un ordre de sortie partielle
      if(orderPlaced && trade.ResultOrder() > 0)
      {
         // Enregistrer les informations de la position pour la gestion ultérieure
         PositionData posData;
         posData.ticket = trade.ResultOrder();
         posData.entryPrice = price;
         posData.stopLoss = stopLoss;
         posData.takeProfit = takeProfit;
         posData.atrValue = atrVal;
         posData.openTime = TimeCurrent();
         posData.direction = direction;
         
         // Ajouter à la liste des positions suivies
         g_openPositions.Add(GetPointer(posData));
         
         Print("Ordre principal exécuté avec succès. Ticket: ", posData.ticket);
      }
   }
   else
   {
      // Exécuter un ordre simple sans sortie partielle
      orderPlaced = (direction > 0) ? 
         trade.Buy(lotSize, _Symbol, price, stopLoss, takeProfit, "FxPro BUY") :
         trade.Sell(lotSize, _Symbol, price, stopLoss, takeProfit, "FxPro SELL");
      
      if(orderPlaced)
         Print("Ordre exécuté avec succès. Ticket: ", trade.ResultOrder());
   }
   
   // Vérifier les erreurs
   if(!orderPlaced)
   {
      uint error = GetLastError();
      Print("Erreur lors de l'exécution de l'ordre: ", error, " - ", ErrorDescription(error));
   }
}

//+------------------------------------------------------------------+
//| Vérifie le risque journalier maximum                             |
//+------------------------------------------------------------------+
bool CheckDailyRisk()
{
   // Vérifier si nous avons dépassé le risque journalier maximum
   if(g_dailyPL < 0 && MathAbs(g_dailyPL) >= AccountInfoDouble(ACCOUNT_BALANCE) * (InpMaxDailyRisk / 100.0))
   {
      Print("Risque journalier maximum atteint. PL du jour: ", g_dailyPL);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Compte le nombre de positions ouvertes pour ce symbole et magic  |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            count++;
         }
      }
   }
   
   return count;
}

//+------------------------------------------------------------------+
//| Gère le trailing stop pour les positions ouvertes                |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!InpUseTrailingStop) return;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double stopLoss = PositionGetDouble(POSITION_SL);
            double takeProfit = PositionGetDouble(POSITION_TP);
            double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
            
            // Trouver les données de position dans notre liste
            PositionData *posData = NULL;
            for(int j = 0; j < g_openPositions.Total(); j++)
            {
               PositionData *p = g_openPositions.At(j);
               if(p.ticket == ticket)
               {
                  posData = p;
                  break;
               }
            }
            
            if(posData == NULL) continue;
            
            // Calculer la distance en pips
            double atr = posData.atrValue;
            double trailStart = atr * InpTrailingStart;
            double trailStep = atr * InpTrailingStep;
            
            if(posData.direction > 0) // Position d'achat
            {
               double newSl = currentPrice - trailStart;
               
               // Vérifier si le prix a suffisamment évolué
               if(currentPrice - openPrice >= trailStart)
               {
                  // Vérifier si nous pouvons déplacer le stop loss
                  if(newSl > stopLoss + trailStep)
                  {
                     // Déplacer le stop loss
                     trade.PositionModify(ticket, newSl, takeProfit);
                     PrintFormat("Trailing stop déplacé à %.5f pour le ticket %d", newSl, ticket);
                  }
               }
            }
            else // Position de vente
            {
               double newSl = currentPrice + trailStart;
               
               // Vérifier si le prix a suffisamment évolué
               if(openPrice - currentPrice >= trailStart)
               {
                  // Vérifier si nous pouvons déplacer le stop loss
                  if(newSl < stopLoss - trailStep || stopLoss == 0)
                  {
                     // Déplacer le stop loss
                     trade.PositionModify(ticket, newSl, takeProfit);
                     PrintFormat("Trailing stop déplacé à %.5f pour le ticket %d", newSl, ticket);
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Gère la sortie partielle des positions                           |
//+------------------------------------------------------------------+
void ManagePartialClose()
{
   if(!InpUsePartialClose) return;
   
   for(int i = 0; i < g_openPositions.Total(); i++)
   {
      PositionData *posData = g_openPositions.At(i);
      
      if(PositionSelectByTicket(posData.ticket))
      {
         double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double positionSize = PositionGetDouble(POSITION_VOLUME);
         double currentProfit = PositionGetDouble(POSITION_PROFIT);
         
         // Calculer la distance par rapport au prix d'ouverture
         double distance = (posData.direction > 0) ? 
                           (currentPrice - openPrice) : 
                           (openPrice - currentPrice);
         
         // Vérifier si nous avons atteint le premier niveau de prise de bénéfices
         if(distance >= posData.atrValue * InpPartialTP1 && 
            positionSize > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) * 2)
         {
            // Fermer une partie de la position (50% par défaut)
            double closeVolume = NormalizeDouble(positionSize * (InpPartialCloseAt1 / 100.0), 2);
            
            // S'assurer que le volume à fermer est valide
            double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
            
            closeVolume = MathFloor(closeVolume / lotStep) * lotStep;
            closeVolume = MathMax(closeVolume, minLot);
            
            // Vérifier que le volume restant est suffisant
            if(positionSize - closeVolume >= minLot)
            {
               // Fermer une partie de la position
               trade.PositionClosePartial(posData.ticket, closeVolume);
               PrintFormat("Sortie partielle de %.2f lots sur la position %d (profit: %.2f)", 
                           closeVolume, posData.ticket, currentProfit * (closeVolume / positionSize));
            }
         }
      }
   }
}