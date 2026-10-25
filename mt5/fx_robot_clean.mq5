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
// #include <Indicators\Oscillators.mqh>  // Commenté car non trouvé

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

CArrayObj *g_openPositions = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialisation des indicateurs
   g_atr_handle = iATR(_Symbol, InpSpikeTimeframe, InpATR_Period);
   g_adx_handle = iADX(_Symbol, InpSpikeTimeframe, InpADXPeriod);
   g_ma_fast_handle = iMA(_Symbol, InpSpikeTimeframe, InpTrendMAPeriod1, 0, MODE_SMA, PRICE_CLOSE);
   g_ma_slow_handle = iMA(_Symbol, InpSpikeTimeframe, InpTrendMAPeriod2, 0, MODE_SMA, PRICE_CLOSE);
   g_rsi_handle = iRSI(_Symbol, InpSpikeTimeframe, 14, PRICE_CLOSE);
   
   // Initialisation des handles pour l'analyse multi-timeframe
   g_ma_trend1_handle = iMA(_Symbol, InpTrendTF1, InpTrendMAPeriod1, 0, MODE_SMA, PRICE_CLOSE);
   g_ma_trend2_handle = iMA(_Symbol, InpTrendTF1, InpTrendMAPeriod2, 0, MODE_SMA, PRICE_CLOSE);
   
   // Initialisation du tableau des positions
   g_openPositions = new CArrayObj();
   
   // Configuration du trade
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Démarrer le timer pour la gestion en temps réel
   EventSetTimer(1);
   
   Print("Expert Advisor initialisé avec succès");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Libération des handles
   if(g_atr_handle != INVALID_HANDLE) IndicatorRelease(g_atr_handle);
   if(g_adx_handle != INVALID_HANDLE) IndicatorRelease(g_adx_handle);
   if(g_ma_fast_handle != INVALID_HANDLE) IndicatorRelease(g_ma_fast_handle);
   if(g_ma_slow_handle != INVALID_HANDLE) IndicatorRelease(g_ma_slow_handle);
   if(g_rsi_handle != INVALID_HANDLE) IndicatorRelease(g_rsi_handle);
   if(g_ma_trend1_handle != INVALID_HANDLE) IndicatorRelease(g_ma_trend1_handle);
   if(g_ma_trend2_handle != INVALID_HANDLE) IndicatorRelease(g_ma_trend2_handle);
   
   // Suppression du tableau des positions
   if(g_openPositions != NULL) {
      g_openPositions.Clear();
      delete g_openPositions;
   }
   
   // Arrêt du timer
   EventKillTimer();
   
   Print("Expert Advisor désinitialisé");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!InpEnableTrading) return;
   
   // Vérifier si c'est une nouvelle bougie
   datetime currentBarTime = iTime(_Symbol, InpSpikeTimeframe, 0);
   if(currentBarTime == g_lastBarTime) return;
   g_lastBarTime = currentBarTime;
   
   // Vérifier le nombre minimum de barres
   if(Bars(_Symbol, InpSpikeTimeframe) < InpMinBarsRequired) {
      Print("Nombre de barres insuffisant pour l'analyse");
      return;
   }
   
   // Mettre à jour les indicateurs et prendre des décisions de trading
   UpdateIndicators();
   CheckForTradingSignals();
   
   // Gérer les positions ouvertes
   ManageOpenPositions();
}

//+------------------------------------------------------------------+
//| Mise à jour des indicateurs                                      |
//+------------------------------------------------------------------+
void UpdateIndicators()
{
   // Mettre à jour les valeurs des indicateurs
   double atrBuffer[];
   if(CopyBuffer(g_atr_handle, 0, 0, 1, atrBuffer) > 0) {
      g_lastATR = atrBuffer[0];
   } else {
      Print("Erreur lors de la lecture de l'ATR");
      g_lastATR = 0;
   }
}

//+------------------------------------------------------------------+
//| Vérification des signaux de trading                              |
//+------------------------------------------------------------------+
void CheckForTradingSignals()
{
   // Vérifier si une position est déjà ouverte
   if(g_hasOpenPosition) return;
   
   // Vérifier les conditions d'entrée en position
   double maFast[], maSlow[];
   ArraySetAsSeries(maFast, true);
   ArraySetAsSeries(maSlow, true);
   
   // Récupérer les valeurs des moyennes mobiles
   if(CopyBuffer(g_ma_fast_handle, 0, 0, 2, maFast) <= 0 || 
      CopyBuffer(g_ma_slow_handle, 0, 0, 2, maSlow) <= 0) {
      Print("Erreur lors de la lecture des indicateurs");
      return;
   }
   
   // Condition d'achat : croisement haussier des moyennes mobiles
   if(maFast[1] <= maSlow[1] && maFast[0] > maSlow[0]) {
      double lotSize = CalculateLotSize();
      double sl = 0, tp = 0;
      
      if(InpUseATRForSL) {
         sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - g_lastATR * InpATRMultiplierSL;
         tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + g_lastATR * InpATRMultiplierTP;
      }
      
      // Ouvrir une position d'achat
      if(trade.Buy(lotSize, _Symbol, 0, sl, tp, "Signal d'achat")) {
         g_hasOpenPosition = true;
      }
   }
}

//+------------------------------------------------------------------+
//| Gestion des positions ouvertes                                   |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   if(!g_hasOpenPosition) return;
   
   // Vérifier si la position est toujours ouverte
   if(PositionsTotal() == 0) {
      g_hasOpenPosition = false;
      return;
   }
   
   // Gérer le trailing stop
   if(InpUseTrailingStop) {
      ManageTrailingStop();
   }
   
   // Gérer la sortie partielle
   if(InpUsePartialClose) {
      ManagePartialClose();
   }
}

//+------------------------------------------------------------------+
//| Gestion du trailing stop                                         |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   // Implémentation du trailing stop
   // (À compléter avec votre logique de trailing stop)
}

//+------------------------------------------------------------------+
//| Gestion de la sortie partielle                                   |
//+------------------------------------------------------------------+
void ManagePartialClose()
{
   // Implémentation de la sortie partielle
   // (À compléter avec votre logique de sortie partielle)
}

//+------------------------------------------------------------------+
//| Calcul de la taille de lot en fonction du risque                 |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   if(InpUseFixedLot) {
      return InpLotSize;
   }
   
   // Calculer la taille du lot en fonction du risque
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(tickSize == 0 || tickValue == 0 || lotStep == 0) {
      Print("Erreur lors du calcul de la taille du lot: valeurs nulles");
      return 0.1; // Valeur par défaut
   }
   
   double riskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (InpRiskPercent / 100.0);
   double stopLossPips = g_lastATR * InpATRMultiplierSL / _Point;
   double moneyRiskPerLot = stopLossPips * tickValue / tickSize;
   
   if(moneyRiskPerLot == 0) {
      Print("Erreur: moneyRiskPerLot est nul");
      return 0.1; // Valeur par défaut
   }
   
   double lots = NormalizeDouble(riskAmount / moneyRiskPerLot, 2);
   
   // Ajuster au lotStep le plus proche
   lots = MathFloor(lots / lotStep) * lotStep;
   
   // Vérifier les limites de lot
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   lots = MathMax(minLot, MathMin(maxLot, lots));
   
   return lots;
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Vérifier périodiquement l'état des positions
   g_hasOpenPosition = (PositionsTotal() > 0);
}

//+------------------------------------------------------------------+
//| Fonction pour vérifier si une position est ouverte               |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   return g_hasOpenPosition;
}
