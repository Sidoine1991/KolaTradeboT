//+------------------------------------------------------------------+
//| AngelOfSpike_Pro.mq5 - Version Améliorée                         |
//| Robot de Trading Optimisé pour Boom/Crash                       |
//+------------------------------------------------------------------+
#property copyright "AngelOfSpike Pro"
#property version   "2.0"
#property description "Robot optimisé: 2 ordres limit max, perte max 3.5$, TP ouvert, fermeture après spike"

//--- Includes
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Object.mqh>
#include <StdLibErr.mqh>
#include <Arrays\ArrayObj.mqh>
#include <Arrays\Array.mqh>
#include <Indicators\Indicators.mqh>

//--- Paramètres d'entrée principaux
input bool InpEnableBoomCrashTrading = true;  // Activer le trading sur les indices Boom/Crash

//--- Variables globales pour les indicateurs
int g_ma20Handle = INVALID_HANDLE, g_ma50Handle = INVALID_HANDLE, g_ema12Handle = INVALID_HANDLE, g_ema26Handle = INVALID_HANDLE;
int g_rsiHandle = INVALID_HANDLE, g_macdHandle = INVALID_HANDLE, g_stochHandle = INVALID_HANDLE, g_atrHandle = INVALID_HANDLE, g_bbHandle = INVALID_HANDLE;
string g_currentSymbol = ""; // Current symbol for indicator operations

//--- Structure pour le cache des données d'indicateurs
struct IndicatorData
{
    string symbol;  // Added symbol to the structure
    double ma20[2], ma50[2], ema12[2], ema26[2], rsi[2];
    double macdMain[2], macdSignal[2], stochMain[2], stochSignal[2], atr[2];
    double bbMiddle[2], bbUpper[2], bbLower[2];
    datetime lastUpdate;
};

//--- Cache des indicateurs par symbole
IndicatorData g_indicatorCache[];
int g_indicatorCacheSize = 0; // Taille du cache des indicateurs

//--- Dernière mise à jour des indicateurs
datetime g_lastIndicatorUpdate = 0;
const int INDICATOR_UPDATE_INTERVAL = 1; // Mise à jour toutes les secondes

//--- Variable pour le contrôle du temps entre les ticks
static datetime g_lastTickTime = 0;

//--- Variables pour la gestion des trades Boom/Crash
bool g_isBoomCrashMode = false;  // Mode spécifique pour les indices Boom/Crash
int g_boomCrashMinProfitPoints = 20;  // Profit minimum en points pour la fermeture après spike

//--- Variables globales pour la gestion des trades
int g_currentDirection = 0;  // Direction actuelle du trade (1 = ACHAT, -1 = VENTE)
int g_limitOrderCount = 0;   // Compteur d'ordres limit
bool g_predictionActive = false;  // Indique si une prédiction est active
string g_predictionSymbol = "";  // Symbole de la prédiction active
CTrade g_trade;  // Objet pour l'exécution des trades

//--- Function Declarations
bool ValidateOrderPrices(string symbol, double entryPrice, double &sl, double &tp, int direction);
bool InitializeIndicators(const string symbol);
bool IsBoomCrashSymbol(const string symbol);
void ExecuteTrade(const string symbol, int direction);
void ExecuteLimitOrders(const string symbol, int direction);
int CountLimitOrders(const string symbol);
double CalculateLotSize(const string symbol, double riskPercent = 1.0);
void DrawSpikeArrow(const string symbol, int direction, double price);
void ReleaseIndicators();
double CalculateBuyPressure(const string symbol);
double CalculateSellPressure(const string symbol);
bool CheckAndCloseAfterSpike(const string symbol, bool isBoom);
void ResetPrediction();
void ManagePredictionTiming(const string symbol);
void StartSpikePrediction(const string symbol, int direction, double probability);
void HidePredictiveArrow(const string symbol);
void HideStepPatternSetup(const string symbol);
int ChooseSignalDirection(const string symbol);
//+------------------------------------------------------------------+
//| Initialiser les indicateurs une seule fois                      |
//+------------------------------------------------------------------+
bool InitializeIndicators(const string symbol)
{
    // Vérifier si le symbole est valide
    if(symbol == "" || !SymbolSelect(symbol, true))
    {
        Print("Erreur: Symbole invalide ou non chargé: ", symbol);
        return false;
    }
    
    // Si c'est le même symbole et que les indicateurs sont déjà initialisés
    if(symbol == g_currentSymbol && g_ma20Handle != INVALID_HANDLE) 
        return true;
    
    // Libérer les anciens indicateurs si on change de symbole
    if(g_currentSymbol != "" && symbol != g_currentSymbol)
    {
        ReleaseIndicators();
    }
    
    // Initialiser les nouveaux indicateurs avec gestion des erreurs
    g_ma20Handle = iMA(symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    if(g_ma20Handle == INVALID_HANDLE) { Print("Erreur initialisation MA20"); return false; }
        
    g_ma50Handle = iMA(symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    if(g_ma50Handle == INVALID_HANDLE) { ReleaseIndicators(); Print("Erreur initialisation MA50"); return false; }
    
    g_ema12Handle = iMA(symbol, PERIOD_CURRENT, 12, 0, MODE_EMA, PRICE_CLOSE);
    if(g_ema12Handle == INVALID_HANDLE) { ReleaseIndicators(); Print("Erreur initialisation EMA12"); return false; }
    
    g_ema26Handle = iMA(symbol, PERIOD_CURRENT, 26, 0, MODE_EMA, PRICE_CLOSE);
    if(g_ema26Handle == INVALID_HANDLE) { ReleaseIndicators(); Print("Erreur initialisation EMA26"); return false; }
    
    g_rsiHandle = iRSI(symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    if(g_rsiHandle == INVALID_HANDLE) { ReleaseIndicators(); Print("Erreur initialisation RSI"); return false; }
    
    g_macdHandle = iMACD(symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
    if(g_macdHandle == INVALID_HANDLE) { ReleaseIndicators(); Print("Erreur initialisation MACD"); return false; }
    
    g_stochHandle = iStochastic(symbol, PERIOD_CURRENT, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
    if(g_stochHandle == INVALID_HANDLE) { ReleaseIndicators(); Print("Erreur initialisation Stochastique"); return false; }
    
    g_atrHandle = iATR(symbol, PERIOD_CURRENT, 14);
    if(g_atrHandle == INVALID_HANDLE) { ReleaseIndicators(); Print("Erreur initialisation ATR"); return false; }
    
    g_bbHandle = iBands(symbol, PERIOD_CURRENT, 20, 0, 2.0, PRICE_CLOSE);
    if(g_bbHandle == INVALID_HANDLE) { ReleaseIndicators(); Print("Erreur initialisation Bandes de Bollinger"); return false; }
    
    g_currentSymbol = symbol;
    
    // Initialiser le cache pour ce symbole
    InitializeIndicatorCache(symbol);
    
    return true;
}

//+------------------------------------------------------------------+
//| Libérer les ressources des indicateurs                           |
//+------------------------------------------------------------------+
void ReleaseIndicators()
{
    if(g_ma20Handle != INVALID_HANDLE) { IndicatorRelease(g_ma20Handle); g_ma20Handle = INVALID_HANDLE; }
    if(g_ma50Handle != INVALID_HANDLE) { IndicatorRelease(g_ma50Handle); g_ma50Handle = INVALID_HANDLE; }
    if(g_ema12Handle != INVALID_HANDLE) { IndicatorRelease(g_ema12Handle); g_ema12Handle = INVALID_HANDLE; }
    if(g_ema26Handle != INVALID_HANDLE) { IndicatorRelease(g_ema26Handle); g_ema26Handle = INVALID_HANDLE; }
    if(g_rsiHandle != INVALID_HANDLE) { IndicatorRelease(g_rsiHandle); g_rsiHandle = INVALID_HANDLE; }
    if(g_macdHandle != INVALID_HANDLE) { IndicatorRelease(g_macdHandle); g_macdHandle = INVALID_HANDLE; }
    if(g_stochHandle != INVALID_HANDLE) { IndicatorRelease(g_stochHandle); g_stochHandle = INVALID_HANDLE; }
    if(g_atrHandle != INVALID_HANDLE) { IndicatorRelease(g_atrHandle); g_atrHandle = INVALID_HANDLE; }
    if(g_bbHandle != INVALID_HANDLE) { IndicatorRelease(g_bbHandle); g_bbHandle = INVALID_HANDLE; }
    
    g_currentSymbol = "";
}

//+------------------------------------------------------------------+
//| Initialiser le cache des indicateurs pour un symbole             |
//+------------------------------------------------------------------+
bool InitializeIndicatorCache(const string symbol)
{
    // Vérifier si le cache existe déjà pour ce symbole
    for(int i = 0; i < g_indicatorCacheSize; i++)
    {
        if(g_indicatorCache[i].symbol == symbol)
            return true; // Le cache existe déjà
    }
    
    // Créer une nouvelle entrée de cache
    int newSize = g_indicatorCacheSize + 1;
    if(ArrayResize(g_indicatorCache, newSize) < 0)
    {
        Print("Erreur: Impossible d'allouer de la mémoire pour le cache des indicateurs");
        return false;
    }
    
    // Initialiser la nouvelle entrée
    ZeroMemory(g_indicatorCache[g_indicatorCacheSize]);
    g_indicatorCache[g_indicatorCacheSize].symbol = symbol;
    g_indicatorCache[g_indicatorCacheSize].lastUpdate = 0;
    
    // Initialize arrays to zero
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].ma20, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].ma50, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].ema12, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].ema26, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].rsi, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].macdMain, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].macdSignal, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].stochMain, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].stochSignal, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].atr, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].bbMiddle, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].bbUpper, 0);
    ArrayInitialize(g_indicatorCache[g_indicatorCacheSize].bbLower, 0);
    
    g_indicatorCacheSize = newSize;
    return true;
}

//+------------------------------------------------------------------+
//| Mettre à jour le cache des indicateurs pour le symbole actuel    |
//+------------------------------------------------------------------+
bool UpdateIndicatorCache()
{
    if(g_currentSymbol == "") return false;
    
    int cacheIndex = -1;
    for(int i = 0; i < g_indicatorCacheSize; i++)
    {
        if(g_indicatorCache[i].symbol == g_currentSymbol)
        {
            cacheIndex = i;
            break;
        }
    }
    
    if(cacheIndex == -1) return false;
    
    // Mettre à jour uniquement si nécessaire
    datetime currentTime = TimeCurrent();
    if(currentTime - g_indicatorCache[cacheIndex].lastUpdate < INDICATOR_UPDATE_INTERVAL)
        return true;
    
    // Copier les données des indicateurs dans le cache
    bool success = true;
    
    success &= CopyBuffer(g_ma20Handle, 0, 0, 2, g_indicatorCache[cacheIndex].ma20) == 2;
    success &= CopyBuffer(g_ma50Handle, 0, 0, 2, g_indicatorCache[cacheIndex].ma50) == 2;
    success &= CopyBuffer(g_ema12Handle, 0, 0, 2, g_indicatorCache[cacheIndex].ema12) == 2;
    success &= CopyBuffer(g_ema26Handle, 0, 0, 2, g_indicatorCache[cacheIndex].ema26) == 2;
    success &= CopyBuffer(g_rsiHandle, 0, 0, 2, g_indicatorCache[cacheIndex].rsi) == 2;
    success &= CopyBuffer(g_macdHandle, 0, 0, 2, g_indicatorCache[cacheIndex].macdMain) == 2;
    success &= CopyBuffer(g_macdHandle, 1, 0, 2, g_indicatorCache[cacheIndex].macdSignal) == 2;
    success &= CopyBuffer(g_stochHandle, 0, 0, 2, g_indicatorCache[cacheIndex].stochMain) == 2;
    success &= CopyBuffer(g_stochHandle, 1, 0, 2, g_indicatorCache[cacheIndex].stochSignal) == 2;
    success &= CopyBuffer(g_atrHandle, 0, 0, 2, g_indicatorCache[cacheIndex].atr) == 2;
    
    // Bande de Bollinger (3 lignes)
    double bbUpper[2];
    success &= CopyBuffer(g_bbHandle, 1, 0, 2, bbUpper) == 2;
    success &= CopyBuffer(g_bbHandle, 0, 0, 2, g_indicatorCache[cacheIndex].bbMiddle) == 2;
    success &= CopyBuffer(g_bbHandle, 2, 0, 2, g_indicatorCache[cacheIndex].bbLower) == 2;
    
    // Copier la bande supérieure dans le cache
    if(success)
    {
        ArrayCopy(g_indicatorCache[cacheIndex].bbUpper, bbUpper);
        g_indicatorCache[cacheIndex].lastUpdate = currentTime;
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| Obtenir les données d'indicateurs depuis le cache               |
//+------------------------------------------------------------------+
bool GetCachedIndicatorData(const string symbol, double &ma20[], double &ma50[], double &ema12[], 
                           double &ema26[], double &rsi[], double &macdMain[], double &macdSignal[],
                           double &stochMain[], double &stochSignal[], double &atr[],
                           double &bbMiddle[], double &bbUpper[], double &bbLower[])
{
    if(symbol == "") return false;
    
    // Trouver l'index du cache pour ce symbole
    int cacheIndex = -1;
    for(int i = 0; i < g_indicatorCacheSize; i++)
    {
        if(g_indicatorCache[i].symbol == symbol)
        {
            cacheIndex = i;
            break;
        }
    }
    
    if(cacheIndex == -1) return false;
    
    // Copier les données du cache vers les tableaux de sortie
    ArrayCopy(ma20, g_indicatorCache[cacheIndex].ma20);
    ArrayCopy(ma50, g_indicatorCache[cacheIndex].ma50);
    ArrayCopy(ema12, g_indicatorCache[cacheIndex].ema12);
    ArrayCopy(ema26, g_indicatorCache[cacheIndex].ema26);
    ArrayCopy(rsi, g_indicatorCache[cacheIndex].rsi);
    ArrayCopy(macdMain, g_indicatorCache[cacheIndex].macdMain);
    ArrayCopy(macdSignal, g_indicatorCache[cacheIndex].macdSignal);
    ArrayCopy(stochMain, g_indicatorCache[cacheIndex].stochMain);
    ArrayCopy(stochSignal, g_indicatorCache[cacheIndex].stochSignal);
    ArrayCopy(atr, g_indicatorCache[cacheIndex].atr);
    ArrayCopy(bbMiddle, g_indicatorCache[cacheIndex].bbMiddle);
    ArrayCopy(bbUpper, g_indicatorCache[cacheIndex].bbUpper);
    ArrayCopy(bbLower, g_indicatorCache[cacheIndex].bbLower);
    
    return true;
}

//+------------------------------------------------------------------+
//| Analyser les indicateurs modernes (optimisé)                    |
//+------------------------------------------------------------------+
void AnalyzeModernIndicators(const string symbol)
{
    if(!InpShowModernIndicators) return;
    
    // Initialiser les indicateurs si nécessaire
    if(!InitializeIndicators(symbol)) return;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(currentPrice <= 0) return;
    
    // Déclarer les tableaux pour les données
    double ma20[2], ma50[2], ema12[2], ema26[2], rsi[2], macdMain[2], macdSignal[2];
    double stochMain[2], stochSignal[2], atr[2], bbMiddle[2], bbLower[2];
    
    // Copier les données des indicateurs
    if(CopyBuffer(g_ma20Handle, 0, 0, 2, ma20) <= 0 ||
       CopyBuffer(g_ma50Handle, 0, 0, 2, ma50) <= 0 ||
       CopyBuffer(g_ema12Handle, 0, 0, 2, ema12) <= 0 ||
       CopyBuffer(g_ema26Handle, 0, 0, 2, ema26) <= 0 ||
       CopyBuffer(g_rsiHandle, 0, 0, 2, rsi) <= 0 ||
       CopyBuffer(g_macdHandle, 0, 0, 2, macdMain) <= 0 ||
       CopyBuffer(g_macdHandle, 1, 0, 2, macdSignal) <= 0 ||
       CopyBuffer(g_stochHandle, 0, 0, 2, stochMain) <= 0 ||
       CopyBuffer(g_stochHandle, 1, 0, 2, stochSignal) <= 0 ||
       CopyBuffer(g_atrHandle, 0, 0, 2, atr) <= 0 ||
       CopyBuffer(g_bbHandle, 1, 0, 2, bbMiddle) <= 0 ||
       CopyBuffer(g_bbHandle, 2, 0, 2, bbLower) <= 0) 
    {
        Print("Erreur lors de la copie des données des indicateurs pour ", symbol);
        return;
    }
    
    // Affichage des valeurs des indicateurs
    if(InpDebug)
    {
        static datetime lastPrint = 0;
        if(TimeCurrent() - lastPrint >= 1) // Afficher max 1 fois par seconde
        {
            lastPrint = TimeCurrent();
            Print("🔍 ANALYSE MODERNE [", symbol, "]");
            Print("📈 MA20: ", DoubleToString(ma20[0], _Digits), " | MA50: ", DoubleToString(ma50[0], _Digits));
            Print("📊 RSI: ", DoubleToString(rsi[0], 2), " | MACD: ", DoubleToString(macdMain[0], _Digits));
            Print("📊 Stoch: ", DoubleToString(stochMain[0], 2), " | ATR: ", DoubleToString(atr[0], _Digits));
            Print("📊 BB Middle: ", DoubleToString(bbMiddle[0], _Digits), " | BB Lower: ", DoubleToString(bbLower[0], _Digits));
        }
    }
    
    // Pas besoin de libérer les handles ici, ils sont gérés par InitializeIndicators
}

//--- Inputs
input group "=== CONFIGURATION GENERALE ==="
input bool   InpEnableTrading          = true;   // Activer le trading automatique
input bool   InpRespectManualTrades    = true;   // Respecter les trades manuels
input int    InpMagicNumber            = 12345;  // Magic Number pour identifier les trades de l'EA
input double InpRiskPercent            = 1.0;    // Pourcentage du capital à risquer par trade
input int    InpStopLossPoints         = 100;    // Stop Loss en points
input int    InpTakeProfitPoints       = 200;    // Take Profit en points
input bool   InpDebug                  = true;   // Afficher les messages de débogage
input bool   Inp24HourTrading          = true;   // Trading 24h/24
input bool   InpSkipWeekends           = true;   // Ignorer les week-ends
input bool   InpAutoExecuteThreshold   = 80.0;   // Seuil d'exécution automatique (%)
input bool   InpAutoCloseAfterSpike    = true;   // Fermeture automatique après un spike
input bool   InpEnableScissorDetection = true;   // Activer la détection des ciseaux
input bool   InpShowScissorSignals     = true;   // Afficher les signaux de ciseaux
input bool   InpEnableProximityTrading = true;   // Activer le trading de proximité
input bool   InpShowProximityZones     = true;   // Afficher les zones de proximité
input string InpAllowedSymbols = "Boom 1000 Index,Boom 900 Index,Boom 600 Index,Boom 500 Index,Boom 300 Index,Boom 150 Index,Crash 1000 Index,Crash 900 Index,Crash 600 Index,Crash 500 Index,Crash 300 Index,Crash 150 Index"; // Symboles autorises (base)
input bool   InpAutoDetectAllBoomCrash = true;   // Détecter automatiquement TOUS les Boom/Crash
input bool   InpAutoDetectOtherIndices = true;   // Détecter automatiquement les autres indices

input group "=== GESTION DU CAPITAL ==="
input double InpLotSize                = 0.2;    // Taille du lot (fixe pour tous les symboles)
input double InpMaxLotSize             = 1.0;    // Taille maximum du lot
input double InpMaxTotalLoss           = 3.5;    // Perte totale maximum (3.5$)
input double InpSpikeCapturePoints     = 5.0;    // Points de profit pour fermer le spike
input double InpOtherIndicesGainUSD    = 2.0;    // Gain en $ pour fermer les autres indices

input group "=== DÉTECTION SPIKE ==="
input bool   InpAutoCloseAfterSpike    = true;   // Fermer automatiquement après spike
input double InpSpikeVolatilityThreshold = 2.0;  // Seuil de volatilité pour détecter spike (multiplicateur)
input int    InpSpikeDetectionPeriods  = 3;      // Périodes pour détecter le spike
input double InpSpikeCloseDelaySeconds = 0.0;    // Délai avant fermeture après spike (0 = immédiat)
input bool   InpCloseOnSpikePeak       = true;   // Fermer au pic du spike
input double InpSpikeProfitTarget      = 3.5;    // Profit minimum pour fermer après spike (3.5$)

input group "=== GESTION DES TRADES SIMULTANÉS ==="
input int    InpMaxSimultaneousTrades  = 2;      // Maximum de trades simultanés
input bool   InpPrioritizeBoomCrash    = true;   // Privilégier Boom/Crash sur autres indices
input bool   InpBlockNewTradesWhenMax  = true;   // Bloquer nouveaux trades quand max atteint

input group "=== DÉTECTION MOUVEMENTS EN CISEAUX ==="
input bool   InpEnableScissorDetection = true;   // Activer la détection des ciseaux
input int    InpScissorLookbackBars    = 10;     // Barres pour détecter les ciseaux
input double InpScissorMinMove         = 0.002;  // Mouvement minimum pour ciseau (0.2%)
input double InpScissorConfidence      = 70.0;   // Confiance minimale pour ciseau (70%)
input bool   InpShowScissorSignals     = true;   // Afficher les signaux de ciseaux

input group "=== TRADING PAR PROXIMITÉ SUPPORT/RÉSISTANCE ==="
input bool   InpEnableProximityTrading  = true;   // Activer le trading par proximité
input double InpProximityThreshold     = 0.001;  // Seuil de proximité (0.1% du prix)
input double InpMinSupportStrength      = 0.7;     // Force minimale du support (0.7)
input double InpMinResistanceStrength   = 0.7;    // Force minimale de la résistance (0.7)
input double InpMinConfidence           = 0.8;     // Confiance minimale (0.8)
input bool   InpShowProximityZones      = true;   // Afficher les zones de proximité
input bool   InpShowProximitySignals    = true;   // Afficher les signaux de proximité

input group "=== TIMEFRAMES POUR SUPPORT/RÉSISTANCE ==="
input bool   InpUseDailyLevels          = true;   // Utiliser les niveaux Daily
input bool   InpUseH8Levels             = true;   // Utiliser les niveaux H8
input bool   InpUseH6Levels             = true;   // Utiliser les niveaux H6
input bool   InpUseH4Levels             = true;   // Utiliser les niveaux H4
input bool   InpUseH1Levels             = true;   // Utiliser les niveaux H1
input bool   InpUseM30Levels            = true;   // Utiliser les niveaux M30
input bool   InpUseM15Levels            = true;   // Utiliser les niveaux M15
input bool   InpUseM5Levels             = true;   // Utiliser les niveaux M5
input int    InpMaxLevelsPerTimeframe   = 5;      // Max niveaux par timeframe
input double InpTimeframeWeight         = 1.0;     // Poids des timeframes (1.0 = égal)

input group "=== ORDRES LIMIT ==="
input bool   InpUseLimitOrders         = true;   // Utiliser les ordres limit
input int    InpMaxLimitOrders         = 2;      // Maximum 2 ordres limit par trade
input int    InpLimitOffsetPoints      = 20;     // Offset des ordres limit (points)
input int    InpLimitExpiryMinutes     = 5;      // Expiration des ordres limit (minutes)

input group "=== TRADING 24H/24 ==="
input bool   Inp24HourTrading          = true;   // Trading 24h/24 activé
input bool   InpSkipWeekends           = false;  // Ignorer les week-ends
input int    InpSessionStartHour       = 0;      // Heure de début session (0-23)
input int    InpSessionEndHour         = 23;     // Heure de fin session (0-23)

input group "=== PREDICTION & VISUAL ==="
input bool   InpEnablePrediction       = true;   // Activer la prédiction de spikes
input bool   InpShowBlinkingArrows     = true;   // Afficher les flèches clignotantes
input int    InpPredictionPeriods      = 5;      // Périodes pour l'analyse prédictive (plus court)
input double InpSpikeProbabilityThreshold = 60.0; // Seuil de probabilité pour les flèches (réduit de 85% à 60%)
input double InpStepPatternThreshold   = 40.0;   // Seuil spécifique pour les step patterns
input int    InpBlinkIntervalMs        = 300;    // Intervalle de clignotement plus rapide (ms)
input bool   InpExecuteOnArrowSignal   = true;   // Exécuter immédiatement quand la flèche apparaît
input bool   InpShowStepPatterns       = true;   // Afficher les step patterns prédictifs
input double InpAutoExecuteThreshold   = 60.0;   // Seuil de confiance pour exécution automatique (60%)
input bool   InpAutoExecuteHighConfidence = true; // Exécuter automatiquement les signaux haute confiance

input group "=== TIMING PRÉDICTION SPIKE ==="
input int    InpPredictionAdvanceSeconds = 3;    // Secondes d'avance pour la prédiction (3 sec avant spike)
input bool   InpSyncWithNotification    = true;  // Synchroniser flèche avec notification MT5
input int    InpNotificationDelayMs      = 500;   // Délai notification après flèche (ms)
input bool   InpAutoExecuteAfterNotification = false; // Exécuter automatiquement après notification

input group "=== ANALYSE TENDANCE GLOBALE ==="
input int    InpTrendAnalysisInterval   = 10;    // Intervalle d'analyse de tendance (secondes)
input bool   InpShowTrendDetails        = true;  // Afficher les détails des timeframes
input bool   InpShowSpikeAnnouncementArrows = true; // Afficher les flèches d'annonce de spike
input int    InpSpikeAnnouncementMaxTime = 300;  // Temps max pour afficher l'annonce (secondes)

input group "=== SYSTÈME DE TRADING AVANCÉ ==="
input bool   InpEnableAdvancedTrading   = false;  // Activer le système de trading avancé
input double InpCapitalPerTradeUSD      = 10.00; // Capital engagé par trade ($)
input double InpMaxLossBoomCrashUSD     = 3.50;  // Perte max Boom/Crash ($) - LIMITE STRICTE
input double InpMaxLossOtherUSD         = 3.50;  // Perte max autres symboles ($) - LIMITE STRICTE
input double InpTargetProfitUSD         = 5.00;  // Gain cible par trade ($)
input int    InpMaxConcurrentSymbols     = 2;     // Max symboles ouverts simultanément
input int    InpMaxPositionsPerSymbol    = 1;     // Max positions par symbole
input bool   InpStrictRiskRules          = true; // Appliquer les règles de risque strictes
input bool   InpCloseAfterSpike          = true; // Fermer automatiquement après spike détecté

input group "=== DÉTECTION SPIKE ULTRA-RÉACTIVE ==="
input bool   InpEnableSpikePrediction    = true;  // Activer la prédiction de spike
input double InpPredictionConfidenceMin  = 60.0;  // Confiance minimum pour prédiction (réduit pour plus de réactivité)
input int    InpPredictionLookbackBars   = 10;    // Barres à analyser pour prédiction (réduit)
input bool   InpShowPredictionArrows     = true;  // Afficher les flèches de prédiction
input int    InpPredictionAdvanceTime    = 15;    // Temps d'avance en secondes (réduit)
input double InpBoomCrashSpikeThreshold  = 0.5;   // Seuil de spike pour Boom/Crash (très sensible)
input int    InpTickAnalysisInterval     = 1;     // Analyser chaque tick (1 seconde max)
input bool   InpUltraFastMode           = true;  // Mode ultra-rapide pour Boom/Crash

input group "=== CONTRÔLE DES TRADES ==="
input bool   InpRequireTradeConfirmation = true;  // Exiger confirmation avant chaque trade
input bool   InpShowTradeWarnings         = true;  // Afficher les avertissements de trade
input bool   InpBlockSilentTrades         = true;  // Bloquer les trades silencieux
input bool   InpPreventAutoCloseOpen      = true;  // Empêcher fermeture/rouverture automatique
input bool   InpStrictSingleTrade         = true;  // UN SEUL trade à la fois (STRICT)
input int    InpTradeCooldownSeconds      = 30;    // Délai minimum entre trades (secondes)
input bool   InpBlockMultipleTriggers     = true;  // Bloquer les déclenchements multiples

input group "=== ZONES TECHNIQUES ==="
input bool   InpShowSupportResistance  = true;   // Afficher les zones de support/résistance
input bool   InpShowICTZones          = true;   // Afficher les zones ICT
input bool   InpShowFibonacciLevels   = true;   // Afficher les niveaux de Fibonacci
input bool   InpShowOrderBlocks       = true;   // Afficher les Order Blocks
input bool   InpShowBOSCOS            = true;   // Afficher BOS/COS
input bool   InpShowOTEZones          = true;   // Afficher les zones OTE
input bool   InpShowFairValueGaps     = true;   // Afficher les Fair Value Gaps
input bool   InpShowModernIndicators  = true;   // Afficher les indicateurs modernes 2025

input group "=== INDICATEURS TECHNIQUES MODERNES 2025 ==="
input bool   InpShowSmartMoneyConcepts = true;  // Afficher Smart Money Concepts
input bool   InpShowLiquidityLevels   = true;  // Afficher les niveaux de liquidité
input bool   InpShowMarketStructure   = true;   // Afficher la structure du marché
input bool   InpShowVolumeProfile     = true;   // Afficher le Volume Profile
input bool   InpShowWyckoffAnalysis  = true;   // Afficher l'analyse Wyckoff
input bool   InpShowElliottWaves      = true;   // Afficher les vagues d'Elliott
input bool   InpShowHarmonicPatterns  = true;   // Afficher les patterns harmoniques
input int    InpZoneLookbackPeriods   = 20;     // Périodes pour calculer les zones
input double InpZoneStrengthThreshold  = 0.6;    // Seuil de force des zones (0.0-1.0)

input group "=== DEBUG & MONITORING ==="
input bool   InpDebug = true;               // Activer les logs de débogage actif
input bool   InpDetailedTradeLogs       = true;   // Logs détaillés pour tous les trades
input bool   InpSendNotifications       = true;   // Envoyer notifications
input string InpNotifyTag               = "AngelOfSpike"; // Tag notifications

//--- Structure pour l'analyse de tendance
struct TrendAnalysis
{
    int dailyTrend;      // 1=Bullish, -1=Bearish, 0=Neutral
    int h4Trend;         // 1=Bullish, -1=Bearish, 0=Neutral
    int h1Trend;         // 1=Bullish, -1=Bearish, 0=Neutral
    int m30Trend;        // 1=Bullish, -1=Bearish, 0=Neutral
    int m15Trend;        // 1=Bullish, -1=Bearish, 0=Neutral
    int m5Trend;         // 1=Bullish, -1=Bearish, 0=Neutral
    int consolidatedTrend; // Tendance consolidée
    double confidence;   // Confiance de la tendance (0-100%)
    int spikePredictionSeconds; // Prédiction du spike en secondes
    string trendDescription; // Description textuelle
};

//--- Variables globales
CTrade g_trade;
bool g_globalTradeBlocked = false;
datetime g_globalBlockUntil = 0;
string g_predictionSymbol = "";
bool g_predictionActive = false;

//+------------------------------------------------------------------+
//| Calculer le risque de la position                               |
//+------------------------------------------------------------------+
double CalculatePositionRisk(const string symbol, double lotSize, double stopLoss)
{
    if(symbol == "" || lotSize <= 0) return 0.0;
    
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if(tickSize <= 0 || tickValue <= 0 || point <= 0)
    {
        Print("Erreur: Impossible de calculer le risque - valeurs invalides pour ", symbol);
        return 0.0;
    }
    
    // Calculer le risque en fonction du stop loss
    double riskPerLot = MathAbs(stopLoss) * tickValue / (tickSize / point);
    double risk = lotSize * riskPerLot;
    
    return NormalizeDouble(risk, 2);
}

//+------------------------------------------------------------------+
//| Calculer la perte totale actuelle                               |
//+------------------------------------------------------------------+
double CalculateTotalLoss()
{
    double totalLoss = 0.0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == NULL) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        
        double profit = PositionGetDouble(POSITION_PROFIT);
        if(profit < 0)
        {
            totalLoss += MathAbs(profit);
        }
    }
    
    return NormalizeDouble(totalLoss, 2);
}
datetime g_lastOrderTime = 0;

//--- Variables pour le système prédictif
datetime g_lastBlinkTime = 0;
bool g_blinkState = false;
string g_lastPredictionSymbol = "";
double g_lastPredictionProbability = 0.0;

//--- Variables pour le timing de prédiction
datetime g_predictionStartTime = 0;
datetime g_notificationSentTime = 0;
int g_predictionDirection = 0;
double g_predictionProbability = 0.0;
bool g_notificationSent = false;
bool g_orderExecuted = false;

//--- Variables pour les niveaux testés positifs
struct TestedLevel
{
    double price;
    int touches;
    datetime lastTouch;
    bool isValid;
    ENUM_TIMEFRAMES timeframe;
    string levelType; // "SUPPORT" ou "RESISTANCE"
};

TestedLevel g_testedLevels[];
int g_maxTestedLevels = 20;
datetime g_lastLevelUpdate = 0;
bool g_levelsInitialized = false;
bool g_arrowSignalActive = false;
datetime g_arrowSignalTime = 0;
string g_arrowSignalSymbol = "";

//--- Variables pour la gestion des trades simultanés
int g_currentTradesCount = 0;
string g_activeTradesSymbols[10]; // Stocker les symboles actifs

//--- Variables pour éviter les surcharges
int g_tickCounter = 0;

//--- Variables pour le contrôle strict des trades
datetime g_lastTradeTime = 0;           // Dernière exécution de trade
bool g_tradeLocked = false;             // Verrouillage des trades
string g_lastTradeSymbol = "";          // Dernier symbole tradé
int g_lastTradeDirection = 0;           // Dernière direction tradée
datetime g_tradeLockUntil = 0;          // Verrouillage jusqu'à cette heure
int g_totalTradesExecuted = 0;          // Compteur total de trades

//--- Variables pour la détection de spike
datetime g_spikeDetectionTime = 0;
double g_spikeBaseVolatility = 0.0;
bool g_spikeDetected = false;
string g_spikeSymbol = "";
datetime g_spikePeakTime = 0;

//+------------------------------------------------------------------+
//| Diagnostic des paramètres de configuration                       |
//+------------------------------------------------------------------+
void DiagnoseConfiguration()
{
    Print("🔧 === DIAGNOSTIC CONFIGURATION ANGELOFSPIKE ===");
    Print("📊 Trading activé: ", InpEnableTrading ? "OUI" : "NON");
    Print("📊 Trading 24h/24: ", Inp24HourTrading ? "OUI" : "NON");
    Print("📊 Ignorer week-ends: ", InpSkipWeekends ? "OUI" : "NON");
    Print("📊 Session: ", InpSessionStartHour, "h-", InpSessionEndHour, "h");
    Print("📊 Prédiction activée: ", InpEnablePrediction ? "OUI" : "NON");
    Print("📊 Seuil d'exécution: ", InpAutoExecuteThreshold, "%");
    Print("📊 Max trades simultanés: ", InpMaxSimultaneousTrades);
    Print("📊 Perte max totale: $", InpMaxTotalLoss);
    Print("📊 Symboles autorisés: ", InpAllowedSymbols);
    Print("📊 Auto-détection Boom/Crash: ", InpAutoDetectAllBoomCrash ? "OUI" : "NON");
    Print("📊 Auto-détection autres indices: ", InpAutoDetectOtherIndices ? "OUI" : "NON");
    Print("📊 Mode debug: ", InpDebug ? "ACTIVÉ" : "DÉSACTIVÉ");
    Print("📊 Notifications: ", InpSendNotifications ? "ACTIVÉES" : "DÉSACTIVÉES");
    Print("🔧 === FIN DIAGNOSTIC ===");
}

//+------------------------------------------------------------------+
//| Analyser la tendance globale multi-timeframe                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Analyser la tendance d'un timeframe spécifique                  |
//+------------------------------------------------------------------+
int AnalyzeTimeframeTrend(const string symbol, ENUM_TIMEFRAMES timeframe)
{
    // Récupérer les données de prix
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyHigh(symbol, timeframe, 0, 20, high) < 0 ||
       CopyLow(symbol, timeframe, 0, 20, low) < 0 ||
       CopyClose(symbol, timeframe, 0, 20, close) < 0)
    {
        return 0; // Erreur de récupération des données
    }
    
    // Analyser les 20 dernières bougies
    int bullishSignals = 0;
    int bearishSignals = 0;
    
    // 1. Analyse des moyennes mobiles
    double ma20 = 0, ma10 = 0, ma5 = 0;
    for(int i = 0; i < 20; i++)
    {
        ma20 += close[i];
    }
    ma20 /= 20;
    
    for(int i = 0; i < 10; i++)
    {
        ma10 += close[i];
    }
    ma10 /= 10;
    
    for(int i = 0; i < 5; i++)
    {
        ma5 += close[i];
    }
    ma5 /= 5;
    
    // Tendance des MA (plus sensible)
    if(ma5 > ma10) bullishSignals += 2;
    else if(ma5 < ma10) bearishSignals += 2;
    
    if(ma10 > ma20) bullishSignals += 1;
    else if(ma10 < ma20) bearishSignals += 1;
    
    // Position du prix par rapport aux MA
    if(close[0] > ma5) bullishSignals += 2;
    else if(close[0] < ma5) bearishSignals += 2;
    
    // 2. Analyse des hauts et bas
    double highestHigh = high[ArrayMaximum(high, 0, 10)];
    double lowestLow = low[ArrayMinimum(low, 0, 10)];
    double currentPrice = close[0];
    
    if(currentPrice > (highestHigh + lowestLow) / 2) bullishSignals += 2;
    else if(currentPrice < (highestHigh + lowestLow) / 2) bearishSignals += 2;
    
    // 2.5. Analyse de momentum (prix vs prix précédent)
    if(close[0] > close[1]) bullishSignals += 1;
    else if(close[0] < close[1]) bearishSignals += 1;
    
    if(close[1] > close[2]) bullishSignals += 1;
    else if(close[1] < close[2]) bearishSignals += 1;
    
    // 3. Analyse des patterns de bougies
    double open[];
    ArraySetAsSeries(open, true);
    if(CopyOpen(symbol, timeframe, 0, 5, open) >= 0)
    {
        for(int i = 0; i < 5; i++)
        {
            if(close[i] > open[i]) bullishSignals += 1; // Bougie haussière
            else if(close[i] < open[i]) bearishSignals += 1; // Bougie baissière
        }
    }
    
    // 4. Analyse de la volatilité
    double volatility = 0;
    for(int i = 1; i < 10; i++)
    {
        volatility += MathAbs(close[i] - close[i-1]);
    }
    volatility /= 9;
    
    if(volatility > 0.001) // Volatilité élevée
    {
        if(bullishSignals > bearishSignals) bullishSignals += 2;
        else if(bearishSignals > bullishSignals) bearishSignals += 2;
    }
    
    // Déterminer la tendance (seuils plus sensibles)
    if(InpDebug && StringFind(symbol, "Boom") >= 0) // Debug pour Boom seulement
    {
        Print("🔍 ANALYSE TIMEFRAME [", symbol, " ", EnumToString(timeframe), "]: Bullish=", bullishSignals, " Bearish=", bearishSignals);
    }
    
    if(bullishSignals > bearishSignals) return 1;  // Bullish
    else if(bearishSignals > bullishSignals) return -1; // Bearish
    else return 0; // Neutral
}

//+------------------------------------------------------------------+
//| Analyser la tendance globale consolidée                         |
//+------------------------------------------------------------------+
TrendAnalysis AnalyzeGlobalTrend(const string symbol)
{
    TrendAnalysis analysis;
    ZeroMemory(analysis);
    
    // Analyser chaque timeframe
    analysis.dailyTrend = AnalyzeTimeframeTrend(symbol, PERIOD_D1);
    analysis.h4Trend = AnalyzeTimeframeTrend(symbol, PERIOD_H4);
    analysis.h1Trend = AnalyzeTimeframeTrend(symbol, PERIOD_H1);
    analysis.m30Trend = AnalyzeTimeframeTrend(symbol, PERIOD_M30);
    analysis.m15Trend = AnalyzeTimeframeTrend(symbol, PERIOD_M15);
    analysis.m5Trend = AnalyzeTimeframeTrend(symbol, PERIOD_M5);
    
    // Calculer la tendance consolidée avec pondération
    double weightedSum = 0;
    double totalWeight = 0;
    
    // Pondération par importance du timeframe
    weightedSum += analysis.dailyTrend * 6.0;   // Daily = poids 6
    totalWeight += 6.0;
    
    weightedSum += analysis.h4Trend * 5.0;      // H4 = poids 5
    totalWeight += 5.0;
    
    weightedSum += analysis.h1Trend * 4.0;      // H1 = poids 4
    totalWeight += 4.0;
    
    weightedSum += analysis.m30Trend * 3.0;      // M30 = poids 3
    totalWeight += 3.0;
    
    weightedSum += analysis.m15Trend * 2.0;     // M15 = poids 2
    totalWeight += 2.0;
    
    weightedSum += analysis.m5Trend * 1.0;      // M5 = poids 1
    totalWeight += 1.0;
    
    // Normaliser la tendance consolidée
    double normalizedTrend = weightedSum / totalWeight;
    
    if(normalizedTrend > 0.1) analysis.consolidatedTrend = 1;      // Bullish
    else if(normalizedTrend < -0.1) analysis.consolidatedTrend = -1; // Bearish
    else analysis.consolidatedTrend = 0;                           // Neutral
    
    // Calculer la confiance
    analysis.confidence = MathAbs(normalizedTrend) * 100;
    
    // Prédire le timing du spike basé sur l'alignement des timeframes
    int alignedTimeframes = 0;
    if(analysis.dailyTrend == analysis.consolidatedTrend) alignedTimeframes++;
    if(analysis.h4Trend == analysis.consolidatedTrend) alignedTimeframes++;
    if(analysis.h1Trend == analysis.consolidatedTrend) alignedTimeframes++;
    if(analysis.m30Trend == analysis.consolidatedTrend) alignedTimeframes++;
    if(analysis.m15Trend == analysis.consolidatedTrend) alignedTimeframes++;
    if(analysis.m5Trend == analysis.consolidatedTrend) alignedTimeframes++;
    
    // Plus d'alignement = spike plus proche
    if(alignedTimeframes >= 5) analysis.spikePredictionSeconds = 30;      // Très proche
    else if(alignedTimeframes >= 4) analysis.spikePredictionSeconds = 60;  // Proche
    else if(alignedTimeframes >= 3) analysis.spikePredictionSeconds = 120; // Moyen
    else if(alignedTimeframes >= 2) analysis.spikePredictionSeconds = 300; // Loin
    else analysis.spikePredictionSeconds = 600;                            // Très loin
    
    // Description textuelle
    if(analysis.consolidatedTrend == 1)
        analysis.trendDescription = "BULLISH";
    else if(analysis.consolidatedTrend == -1)
        analysis.trendDescription = "BEARISH";
    else
        analysis.trendDescription = "NEUTRAL";
    
    return analysis;
}

//+------------------------------------------------------------------+
//| Demander confirmation avant d'exécuter un trade                 |
//+------------------------------------------------------------------+
bool RequestTradeConfirmation(const string symbol, const int direction, const double confidence)
{
    if(!InpRequireTradeConfirmation) return true;
    
    Print("⚠️ ===== DEMANDE DE CONFIRMATION DE TRADE =====");
    Print("📊 Symbole: ", symbol);
    Print("📈 Direction: ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
    Print("📊 Confiance: ", DoubleToString(confidence, 1), "%");
    Print("⏰ Heure: ", TimeToString(TimeCurrent()));
    Print("⚠️ ATTENTION: Un trade va être exécuté!");
    Print("⚠️ Pour confirmer, changez InpRequireTradeConfirmation à false");
    Print("⚠️ Ou attendez 10 secondes pour annuler automatiquement");
    Print("=============================================");
    
    // Attendre 10 secondes pour confirmation
    datetime startTime = TimeCurrent();
    while(TimeCurrent() - startTime < 10)
    {
        Sleep(1000);
        if(!InpRequireTradeConfirmation)
        {
            Print("✅ CONFIRMATION REÇUE - Exécution du trade autorisée");
            return true;
        }
    }
    
    Print("❌ CONFIRMATION EXPIRÉE - Trade annulé");
    return false;
}

//+------------------------------------------------------------------+
//| Obtenir le symbole de tendance                                  |
//+------------------------------------------------------------------+
string GetTrendSymbol(int trend)
{
    if(trend == 1) return "📈";
    else if(trend == -1) return "📉";
    else return "➡️";
}

//+------------------------------------------------------------------+
//| Afficher la flèche dynamique d'annonce de spike                 |
//+------------------------------------------------------------------+
void DisplaySpikeAnnouncementArrow(const string symbol, const TrendAnalysis &analysis)
{
    // Supprimer l'ancienne flèche d'annonce
    ObjectsDeleteAll(0, "SpikeAnnouncement_" + symbol);
    
    // Ne pas afficher si pas de tendance claire
    if(analysis.consolidatedTrend == 0) return;
    
    // Obtenir le prix actuel
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    datetime currentTime = TimeCurrent();
    
    if(currentPrice <= 0) return;
    
    // Créer la flèche d'annonce
    string arrowName = "SpikeAnnouncement_" + symbol + "_" + IntegerToString(currentTime);
    
    // Position de la flèche (au-dessus du prix pour BUY, en-dessous pour SELL)
    double arrowPrice = currentPrice;
    int arrowCode = 0;
    color arrowColor = clrWhite;
    
    if(analysis.consolidatedTrend == 1) // BULLISH
    {
        arrowPrice = currentPrice + 50 * SymbolInfoDouble(symbol, SYMBOL_POINT);
        arrowCode = 233; // Flèche vers le haut
        arrowColor = clrLime;
    }
    else if(analysis.consolidatedTrend == -1) // BEARISH
    {
        arrowPrice = currentPrice - 50 * SymbolInfoDouble(symbol, SYMBOL_POINT);
        arrowCode = 234; // Flèche vers le bas
        arrowColor = clrRed;
    }
    
    // Créer la flèche
    if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, currentTime, arrowPrice))
    {
        string directionText = (analysis.consolidatedTrend == 1) ? "BUY" : "SELL";
        
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 5);
        ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
        ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, true);
        
        // Ajouter un label texte pour indiquer la direction
        string labelName = "SpikeLabel_" + symbol + "_" + IntegerToString(currentTime);
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, arrowPrice))
        {
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, arrowColor);
            ObjectSetString(0, labelName, OBJPROP_TEXT, "SPIKE " + directionText);
            ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_UPPER);
            ObjectSetInteger(0, labelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        }
        
        // Faire clignoter la flèche si le spike est très proche
        if(analysis.spikePredictionSeconds <= 60)
        {
            // Animation de clignotement
            static datetime lastBlinkTime = 0;
            static bool blinkState = false;
            
            if(TimeCurrent() - lastBlinkTime >= 500) // Clignoter toutes les 500ms
            {
                blinkState = !blinkState;
                lastBlinkTime = TimeCurrent();
                
                if(blinkState)
                {
                    ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrYellow);
                }
                else
                {
                    ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
                }
            }
        }
        
        // Forcer la mise à jour du graphique
        ChartRedraw(0);
        
        if(InpDebug)
        {
            Print("🎯 FLÈCHE SPIKE AFFICHÉE [", symbol, "]: ", 
                  (analysis.consolidatedTrend == 1 ? "BUY" : "SELL"), 
                  " - Dans ", analysis.spikePredictionSeconds, "s");
        }
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour la flèche d'annonce de spike                      |
//+------------------------------------------------------------------+
void UpdateSpikeAnnouncementArrow(const string symbol, const TrendAnalysis &analysis)
{
    // Supprimer les anciennes flèches
    ObjectsDeleteAll(0, "SpikeAnnouncement_" + symbol);
    
    // Afficher la nouvelle flèche seulement si spike proche ET confiance > 80%
    if(analysis.spikePredictionSeconds <= InpSpikeAnnouncementMaxTime && analysis.confidence > 80.0)
    {
        if(InpDebug)
        {
            Print("🔔 ANNONCE SPIKE [", symbol, "]: ", 
                  (analysis.consolidatedTrend == 1 ? "BUY" : "SELL"), 
                  " - Confiance: ", DoubleToString(analysis.confidence, 1), "%");
        }
        DisplaySpikeAnnouncementArrow(symbol, analysis);
    }
    else if(InpDebug && analysis.spikePredictionSeconds <= InpSpikeAnnouncementMaxTime)
    {
        Print("🔕 Spike ignoré [", symbol, "]: Confiance trop faible (", 
              DoubleToString(analysis.confidence, 1), "% <= 80%)");
    }
}

//+------------------------------------------------------------------+
//| Calculer la taille de lot basée sur le capital                  |
//+------------------------------------------------------------------+
double CalculateLotSize(const string symbol, const double capitalUSD)
{
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if(tickValue <= 0.0 || tickSize <= 0.0 || point <= 0.0) return 0.2; // CORRIGÉ: 0.2 au lieu de 0.01
    
    // Calculer le lot pour le capital donné
    double usdPerPointPerLot = tickValue * (point / tickSize);
    if(usdPerPointPerLot <= 0.0) return 0.2; // CORRIGÉ: 0.2 au lieu de 0.01
    
    double lot = capitalUSD / (usdPerPointPerLot * 100); // 100 points de marge
    return MathMax(0.2, MathMin(lot, 1.0)); // CORRIGÉ: 0.2 au lieu de 0.01
}

//+------------------------------------------------------------------+
//| Obtenir la perte maximale selon le symbole                      |
//+------------------------------------------------------------------+
double GetMaxLossForSymbol(const string symbol)
{
    if(StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0) 
        return InpMaxLossBoomCrashUSD;
    return InpMaxLossOtherUSD;
}

//+------------------------------------------------------------------+
//| Afficher les indicateurs EMA avec enveloppes sur le graphique   |
//+------------------------------------------------------------------+
void DrawIndicators(const string symbol)
{
    // Toujours afficher les indicateurs
    // if(!InpShowModernIndicators) return; // Désactivé pour forcer l'affichage
    
    // Nettoyer les anciens objets
    ObjectsDeleteAll(0, "EMA_" + symbol + "_");
    
    // Obtenir le timeframe actuel
    ENUM_TIMEFRAMES timeframe = (ENUM_TIMEFRAMES)Period();
    
    // Définir les périodes, couleurs et largeurs d'enveloppe des EMA
    struct EMA_Setting {
        int period;
        color clr;
        string name;
        double envelopePercent; // Pourcentage d'enveloppe (écart en % du prix)
    };
    
    // Définition des EMA avec leurs paramètres d'enveloppe
    EMA_Setting emaSettings[] = {
        {5, clrRed, "EMA5", 0.2},     // 0.2% d'enveloppe
        {10, clrBlue, "EMA10", 0.15},  // 0.15% d'enveloppe
        {15, clrGreen, "EMA15", 0.1},  // 0.1% d'enveloppe
        {20, clrMagenta, "EMA20", 0.08},
        {30, clrDodgerBlue, "EMA30", 0.06},
        {50, clrOrange, "EMA50", 0.04},
        {100, clrYellow, "EMA100", 0.03},
        {200, clrWhite, "EMA200", 0.02}
    };
    
    // Obtenir les données de prix
    MqlRates rates[];
    int bars = 500; // Nombre de bougies à afficher
    if(CopyRates(symbol, timeframe, 0, bars, rates) < bars) {
        Print("Erreur lors de la copie des données de prix pour ", symbol);
        return;
    }
    
    // Afficher chaque EMA
    for(int i = 0; i < ArraySize(emaSettings); i++) {
        int period = emaSettings[i].period;
        string emaName = "EMA_" + symbol + "_" + IntegerToString(period);
        
        // Créer un handle pour l'EMA
        int emaHandle = iMA(symbol, timeframe, period, 0, MODE_EMA, PRICE_CLOSE);
        if(emaHandle == INVALID_HANDLE) {
            Print("Erreur création EMA", period, ": ", GetLastError());
            continue;
        }
        
        // Copier les valeurs de l'EMA
        double emaValues[];
        ArraySetAsSeries(emaValues, true);
        if(CopyBuffer(emaHandle, 0, 0, bars, emaValues) <= 0) {
            Print("Erreur copie des données EMA", period, ": ", GetLastError());
            IndicatorRelease(emaHandle);
            continue;
        }
        
        // Créer la ligne de l'EMA
        if(!ObjectCreate(0, emaName, OBJ_TREND, 0, 0, 0)) {
            Print("Erreur création de la ligne EMA", period, ": ", GetLastError());
            IndicatorRelease(emaHandle);
            continue;
        }
        
        // Définir les propriétés de la ligne
        ObjectSetInteger(0, emaName, OBJPROP_COLOR, emaSettings[i].clr);
        ObjectSetInteger(0, emaName, OBJPROP_WIDTH, (i < 3) ? 2 : 1); // Plus épais pour les 3 premières EMA
        ObjectSetInteger(0, emaName, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, emaName, OBJPROP_STYLE, STYLE_SOLID);
        
        // Créer les enveloppes autour de l'EMA
        string upperBandName = emaName + "_UPPER";
        string lowerBandName = emaName + "_LOWER";
        
        // Créer les objets pour les bandes d'enveloppe
        if(!ObjectCreate(0, upperBandName, OBJ_TREND, 0, 0, 0) || !ObjectCreate(0, lowerBandName, OBJ_TREND, 0, 0, 0)) {
            Print("Erreur création des bandes d'enveloppe pour ", emaName);
            IndicatorRelease(emaHandle);
            continue;
        }
        
        // Tracer la ligne EMA et ses enveloppes
        for(int j = 1; j < bars; j++) {
            if(j < ArraySize(rates) && j < ArraySize(emaValues)) {
                // Ligne EMA principale
                ObjectMove(0, emaName, j-1, rates[j-1].time, emaValues[j-1]);
                ObjectMove(0, emaName, j, rates[j].time, emaValues[j]);
                
                // Calculer les valeurs des bandes d'enveloppe
                double upperValue = emaValues[j-1] * (1 + emaSettings[i].envelopePercent/100.0);
                double lowerValue = emaValues[j-1] * (1 - emaSettings[i].envelopePercent/100.0);
                
                // Mettre à jour les bandes supérieure et inférieure
                ObjectMove(0, upperBandName, j-1, rates[j-1].time, upperValue);
                ObjectMove(0, upperBandName, j, rates[j].time, upperValue);
                
                ObjectMove(0, lowerBandName, j-1, rates[j-1].time, lowerValue);
                ObjectMove(0, lowerBandName, j, rates[j].time, lowerValue);
            }
        }
        
        // Définir les propriétés des bandes d'enveloppe
        color envelopeColor = (color)(emaSettings[i].clr & 0xFFFFFF | 0x40 << 24); // 25% de transparence
        
        // Bande supérieure
        ObjectSetInteger(0, upperBandName, OBJPROP_COLOR, envelopeColor);
        ObjectSetInteger(0, upperBandName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, upperBandName, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, upperBandName, OBJPROP_RAY_RIGHT, false);
        
        // Bande inférieure
        ObjectSetInteger(0, lowerBandName, OBJPROP_COLOR, envelopeColor);
        ObjectSetInteger(0, lowerBandName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, lowerBandName, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, lowerBandName, OBJPROP_RAY_RIGHT, false);
        
        // Ajouter un label
        string labelName = emaName + "_LABEL";
        if(!ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0)) {
            Print("Erreur création du label pour EMA", period, ": ", GetLastError());
            IndicatorRelease(emaHandle);
            continue;
        }
        
        // Définir les propriétés du label
        ObjectSetString(0, labelName, OBJPROP_TEXT, emaSettings[i].name);
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 20 + (i * 15));
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, emaSettings[i].clr);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
        ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
        
        // Libérer le handle de l'indicateur
        IndicatorRelease(emaHandle);
    }
    
    // Mettre à jour le graphique
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Vérifier les signaux de trading pour les indices Boom/Crash      |
//+------------------------------------------------------------------+
int CheckBoomCrashSignal(const string symbol, double &confidence)
{
    if(!IsBoomCrashSymbol(symbol)) return 0;
    
    // Récupérer les données de prix
    MqlRates rates[];
    ArraySetAsSeries(rates, true);
    if(CopyRates(symbol, PERIOD_M1, 0, 50, rates) < 50) return 0;
    
    // Vérifier la tendance avec les moyennes mobiles
    double maFast[3], maSlow[3];
    int maFastHandle = iMA(symbol, PERIOD_M1, 5, 0, MODE_EMA, PRICE_CLOSE);
    int maSlowHandle = iMA(symbol, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE);
    
    if(CopyBuffer(maFastHandle, 0, 0, 3, maFast) != 3 || 
       CopyBuffer(maSlowHandle, 0, 0, 3, maSlow) != 3)
    {
        IndicatorRelease(maFastHandle);
        IndicatorRelease(maSlowHandle);
        return 0;
    }
    
    // Vérifier le croisement des moyennes mobiles
    bool fastAboveSlow = (maFast[1] > maSlow[1]);
    bool wasBelow = (maFast[2] <= maSlow[2]);
    
    // Calculer la force du signal basée sur l'angle des moyennes mobiles
    double angleFast = MathArctan((maFast[0] - maFast[2]) / 2.0) * 180.0 / M_PI;
    double angleSlow = MathArctan((maSlow[0] - maSlow[2]) / 2.0) * 180.0 / M_PI;
    
    // Libérer les handles des indicateurs
    IndicatorRelease(maFastHandle);
    IndicatorRelease(maSlowHandle);
    
    // Détection d'un signal d'achat (croisement haussier)
    if(fastAboveSlow && wasBelow && angleFast > 10.0)
    {
        confidence = MathMin(90.0, MathAbs(angleFast) * 2.0);
        return POSITION_TYPE_BUY;
    }
    
    // Détection d'un signal de vente (croisement baissier)
    if(!fastAboveSlow && !wasBelow && angleFast < -10.0)
    {
        confidence = MathMin(90.0, MathAbs(angleFast) * 2.0);
        return POSITION_TYPE_SELL;
    }
    
    return 0;
}

//+------------------------------------------------------------------+
//| Vérifier si on peut ouvrir un symbole                           |
//+------------------------------------------------------------------+
bool CanOpenSymbol(const string symbol)
{
    if(symbol == "") return false;
    // Vérifier si c'est un symbole Boom/Crash
    bool isBoomCrash = IsBoomCrashSymbol(symbol);
    
    // Pour les indices Boom/Crash, on utilise des règles plus souples
    if(isBoomCrash)
    {
        // Vérifier le spread pour les indices Boom/Crash (doit être raisonnable)
        double spread = SymbolInfoInteger(symbol, SYMBOL_SPREAD) * SymbolInfoDouble(symbol, SYMBOL_POINT);
        if(spread > 2.0) // Spread maximum de 2 points pour les Boom/Crash
        {
            if(InpDebug) Print("❌ Spread trop élevé pour ", symbol, ": ", DoubleToString(spread, 1), " points");
            return false;
        }
        
        // Vérifier la volatilité (ATR sur 14 périodes)
        double atr[];
        ArraySetAsSeries(atr, true);
        int atr_handle = iATR(symbol, PERIOD_M1, 14);
        if(CopyBuffer(atr_handle, 0, 0, 1, atr) == 1)
        {
            double atrValue = atr[0] / SymbolInfoDouble(symbol, SYMBOL_POINT);
            if(atrValue < 5.0) // ATR minimum de 5 points pour éviter les marchés trop calmes
            {
                if(InpDebug) Print("❌ Volatilité trop faible pour ", symbol, ": ", DoubleToString(atrValue, 1), " points");
                IndicatorRelease(atr_handle);
                return false;
            }
        }
        IndicatorRelease(atr_handle);
        
        // Vérifier si on a déjà une position sur ce symbole Boom/Crash
        for(int i = 0; i < PositionsTotal(); i++)
        {
            ulong ticket = PositionGetTicket(i);
            if(ticket > 0 && PositionGetString(POSITION_SYMBOL) == symbol)
            {
                if(InpDebug) Print("❌ Position déjà ouverte sur ", symbol);
                return false;
            }
        }
        
        return true; // Toutes les conditions sont remplies pour un trade Boom/Crash
    }
    
    // RÈGLE STRICTE: Maximum 2 positions au total
    int totalPositions = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) != "")
        {
            totalPositions++;
        }
    }
    
    if(totalPositions >= 2)
    {
        Print("🚫 LIMITE STRICTE: Maximum 2 positions autorisées (actuellement: ", totalPositions, ")");
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    static double totalLoss = 0.0;
    totalLoss = 0.0;
    
    // Vérifier d'abord la perte totale
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelect(PositionGetSymbol(i)))
        {
            totalLoss += PositionGetDouble(POSITION_PROFIT);
        }
    }
    
    // Si la perte totale dépasse 3.5$, fermer toutes les positions
    if(totalLoss <= -3.5)
    {
        string closeReason = "Perte maximale atteinte (3.5$)";
        CloseAllPositionsForLossLimit(closeReason);
        return;
    }
    
    // Gérer les positions individuelles
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionSelect(PositionGetSymbol(i))) continue;
        
        string symbol = PositionGetString(POSITION_SYMBOL);
        double profit = PositionGetDouble(POSITION_PROFIT);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        
        // Vérifier si le spike est terminé (variation de prix significative)
        MqlRates rates[];
        if(CopyRates(symbol, PERIOD_M1, 0, 2, rates) == 2)
        {
            double priceChange = MathAbs(rates[0].close - rates[1].close);
            int atr_handle = iATR(symbol, PERIOD_M1, 14);
            double atr[1];
            if(CopyBuffer(atr_handle, 0, 0, 1, atr) <= 0)
            {
                Print("Erreur lors de la copie de l'ATR pour ", symbol);
                IndicatorRelease(atr_handle);
                continue;
            }
            IndicatorRelease(atr_handle);
            
            // Si la variation de prix est supérieure à 2x l'ATR, considérer comme un spike
            if(priceChange > 2.0 * atr[0])
            {
                // Fermer la position après le spike
                CTrade trade;
                if(trade.PositionClose(PositionGetInteger(POSITION_TICKET)))
                {
                    Print("✅ Position fermée après spike sur ", symbol, 
                          " - Profit: ", DoubleToString(profit, 2), " $");
                }
                continue;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Afficher la flèche prédictive                                    |
//+------------------------------------------------------------------+
void DisplayPredictionArrow(const string symbol, int direction, double probability)
{
    // Supprimer les anciennes flèches pour ce symbole
    string prefix = "Predictive_" + symbol + "_";
    ObjectsDeleteAll(0, prefix, 0, -1);
    
    if(probability < InpSpikeProbabilityThreshold)
        return;
        
    string arrowName = prefix + "Current";
    color arrowColor = (direction == POSITION_TYPE_BUY) ? clrLime : clrRed;
    
    if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, TimeCurrent(), 0))
    {
        double price = (direction == POSITION_TYPE_BUY) ? 
            SymbolInfoDouble(symbol, SYMBOL_ASK) : 
            SymbolInfoDouble(symbol, SYMBOL_BID);
            
        ObjectMove(0, arrowName, 0, TimeCurrent(), price);
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, (direction == POSITION_TYPE_BUY) ? 233 : 234);
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
        ObjectSetString(0, arrowName, OBJPROP_TEXT, "SPIKE PREDICTION " + DoubleToString(probability, 1) + "%");
        ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        
        // Faire clignoter la flèche
        static datetime lastBlinkTime = 0;
        if(TimeCurrent() - lastBlinkTime >= 1) // Clignotement toutes les secondes
        {
            static bool blinkState = true;
            blinkState = !blinkState;
            ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, blinkState ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
            lastBlinkTime = TimeCurrent();
        }
        }
}

//+------------------------------------------------------------------+
//| Choisir la direction du signal                                  |
//+------------------------------------------------------------------+
int ChooseSignalDirection(const string symbol)
{
    // Analyser les conditions techniques pour déterminer la direction
    double buyPressure = CalculateBuyPressure(symbol);
    double sellPressure = CalculateSellPressure(symbol);
    
    // Analyser la tendance récente
    double recentVolatility = CalculateVolatility(symbol, 5);
    
    // Déterminer la direction basée sur la pression et la volatilité
    if(buyPressure > sellPressure && recentVolatility > 0.3)
    {
        return POSITION_TYPE_BUY;
    }
    else if(sellPressure > buyPressure && recentVolatility > 0.3)
    {
        return POSITION_TYPE_SELL;
    }
    
    return 0; // Aucune direction claire
}

//+------------------------------------------------------------------+
//| Détecter et exécuter les signaux (un seul à la fois)           |
//+------------------------------------------------------------------+
void DetectAndExecuteSignal(const string symbol)
{
    if(InpDebug) Print("🔎 Vérification des signaux pour ", symbol);
    
    // Vérifier qu'il n'y a pas déjà une position sur ce symbole
    int symbolPositions = CountSymbolPositions(symbol);
    if(symbolPositions > 0)
    {
        if(InpDebug) Print("ℹ️ ", symbol, " - Positions existantes: ", symbolPositions);
        return;
    }
    
    // Analyser les conditions techniques
    double probability = AnalyzeTechnicalConditions(symbol);
    
    // NOUVEAU: Seuil strict de 80% pour tous les signaux
    if(probability >= InpAutoExecuteThreshold) // Utiliser le seuil de 80%
    {
        // Choisir la direction
        int direction = ChooseSignalDirection(symbol);
        
        if(direction != 0)
        {
            Print("🎯 SIGNAL HAUTE CONFIANCE DÉTECTÉ: ", symbol, " - Direction: ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), " - Probabilité: ", probability, "%");
            
            // Afficher la flèche au prix actuel
            double currentPrice = (direction == POSITION_TYPE_BUY) ? 
                                SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                                SymbolInfoDouble(symbol, SYMBOL_BID);
            DrawSpikeArrow(symbol, direction, currentPrice);
            
            // Exécuter le trade avec ordres limit
            if(InpUseLimitOrders)
            {
                ExecuteLimitOrders(symbol, direction);
            }
            else
            {
                ExecuteTrade(symbol, direction);
            }
            
            // Marquer le symbole comme actif
            g_currentSymbol = symbol;
            g_currentDirection = direction;
        }
    }
    else
    {
        if(InpDebug) Print("📊 ", symbol, " - Probabilité insuffisante: ", DoubleToString(probability, 1), "% (seuil: ", InpAutoExecuteThreshold, "%)");
    }
}

//+------------------------------------------------------------------+
//| Exécuter les ordres limit (max 2) avec validation complète      |
//+------------------------------------------------------------------+
void ExecuteLimitOrders(const string symbol, int direction)
{
    Print("⚡ EXECUTION ORDRES LIMIT: ", symbol, " - ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
    
    // Vérifier le nombre d'ordres limit existants
    int existingLimitOrders = CountLimitOrders(symbol);
    if(existingLimitOrders >= InpMaxLimitOrders)
    {
        Print("🚫 EXECUTION BLOQUEE: Limite d'ordres limit atteinte (", existingLimitOrders, "/", InpMaxLimitOrders, ")");
        return;
    }
    
    // Calculer le lot
    double lot = CalculateLot(symbol);
    if(lot <= 0)
    {
        Print("🚫 EXECUTION BLOQUEE: Lot invalide (", lot, ")");
        return;
    }
    
    // Obtenir les informations du symbole avec validation
    double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    
    // Validation complète des prix
    if(currentBid <= 0 || currentAsk <= 0)
    {
        Print("🚫 EXECUTION BLOQUEE: Prix invalides - Bid:", currentBid, " Ask:", currentAsk);
        return;
    }
    
    if(point <= 0)
    {
        Print("🚫 EXECUTION BLOQUEE: Point invalide:", point);
        return;
    }
    
    if(digits < 0)
    {
        Print("🚫 EXECUTION BLOQUEE: Digits invalide:", digits);
        return;
    }
    
    // Vérifier que le spread n'est pas trop important
    double spread = currentAsk - currentBid;
    if(spread > currentBid * 0.01) // Spread > 1% du prix
    {
        Print("🚫 EXECUTION BLOQUEE: Spread trop important:", DoubleToString(spread, digits));
        return;
    }
    
    // Vérifier que les prix ne sont pas des valeurs infinies ou NaN
    if(!MathIsValidNumber(currentBid) || !MathIsValidNumber(currentAsk))
    {
        Print("🚫 EXECUTION BLOQUEE: Prix non numériques valides");
        return;
    }
    
    // Calculer le prix de l'ordre limit selon la logique correcte
    double limitPrice = 0;
    double sl = 0, tp = 0;
    
    // Calculer les niveaux SL/TP avec la fonction dédiée
    if(!CalculateSLTP(symbol, direction, (direction == POSITION_TYPE_BUY ? currentAsk : currentBid), sl, tp))
    {
        Print("🚫 EXECUTION BLOQUEE: Impossible de calculer SL/TP valides");
        return;
    }
    
    if(direction == POSITION_TYPE_BUY)
    {
        // BUY LIMIT: prix d'entrée EN DESSOUS du prix actuel
        limitPrice = NormalizeDouble(currentAsk - (InpLimitOffsetPoints * point), digits);
        
        // Recalculer SL/TP basés sur le prix d'entrée de l'ordre limit
        if(!CalculateSLTP(symbol, direction, limitPrice, sl, tp))
        {
            Print("🚫 EXECUTION BLOQUEE: Impossible de recalculer SL/TP pour ordre limit");
            return;
        }
    }
    else
    {
        // SELL LIMIT: prix d'entrée AU-DESSUS du prix actuel
        limitPrice = NormalizeDouble(currentBid + (InpLimitOffsetPoints * point), digits);
        
        // Recalculer SL/TP basés sur le prix d'entrée de l'ordre limit
        if(!CalculateSLTP(symbol, direction, limitPrice, sl, tp))
        {
            Print("🚫 EXECUTION BLOQUEE: Impossible de recalculer SL/TP pour ordre limit");
            return;
        }
    }
    
    // Normaliser les prix
    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);
    
    // Validation des distances minimales
    if(stopLevel > 0)
    {
        double slDistance = MathAbs(limitPrice - sl);
        if(slDistance < stopLevel)
        {
            Print("🚫 EXECUTION BLOQUEE: SL trop proche. Distance actuelle: ", DoubleToString(slDistance, digits), 
                  ", StopLevel requis: ", DoubleToString(stopLevel, digits));
            return;
        }
        
        // Vérifier la distance TP (obligatoire)
        double tpDistance = MathAbs(tp - limitPrice);
        if(tpDistance < stopLevel)
        {
            Print("🚫 EXECUTION BLOQUEE: TP trop proche. Distance actuelle: ", DoubleToString(tpDistance, digits), 
                  ", StopLevel requis: ", DoubleToString(stopLevel, digits));
            return;
        }
    }
    
    // Validation finale des prix
    if(!ValidateLimitOrderPrices(symbol, direction, limitPrice, sl, tp))
    {
        Print("🚫 EXECUTION BLOQUEE: Validation des prix échouée");
        return;
    }
    
    // NOUVEAU: Validation supplémentaire avec la nouvelle fonction
    if(!ValidateOrderPrices(symbol, limitPrice, sl, tp, direction))
    {
        Print("🚫 EXECUTION BLOQUEE: Validation des prix avancée échouée");
        return;
    }
    
    // Créer l'ordre limit avec MqlTradeRequest pour plus de contrôle
    MqlTradeRequest request;
    MqlTradeResult result;
    ZeroMemory(request);
    ZeroMemory(result);
    
    request.action = TRADE_ACTION_PENDING;
    request.symbol = symbol;
    request.volume = lot;
    request.price = limitPrice;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.type = (direction == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
    request.magic = InpMagicNumber;
    request.comment = "AngelOfSpike_Limit_" + IntegerToString(TimeCurrent());
    request.expiration = TimeCurrent() + InpLimitExpiryMinutes * 60;
    request.type_time = ORDER_TIME_SPECIFIED;
    
    // Envoyer l'ordre
    bool success = OrderSend(request, result);
    
    if(success)
    {
        g_limitOrderCount++;
        Print("✅ ORDRE LIMIT créé: ", symbol, " - Prix: ", DoubleToString(limitPrice, digits), 
              " - SL: ", DoubleToString(sl, digits), " - TP: ", DoubleToString(tp, digits));
    }
    else
    {
        Print("❌ ECHEC ORDRE LIMIT: ", symbol, " - Erreur: ", result.retcode, " - ", result.comment);
        Print("   Prix demandé: ", DoubleToString(limitPrice, digits), 
              " - SL: ", DoubleToString(sl, digits), 
              " - TP: ", DoubleToString(tp, digits));
    }
    
    g_lastOrderTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Exécuter un trade avec gestion du risque                         |
//+------------------------------------------------------------------+
bool ExecuteTrade(const string symbol, int direction, double lotSize = 0.0, double sl = 0.0, double tp = 0.0)
{
    if(!InpEnableTrading) 
    {
        Print("⚠️ Trading désactivé dans les paramètres");
        return false;
    }
    
    // Vérifier la perte totale maximale
    double currentTotalLoss = CalculateTotalLoss();
    if(currentTotalLoss >= InpMaxTotalLoss)
    {
        Print("❌ Perte totale maximale atteinte (", currentTotalLoss, "$ / ", InpMaxTotalLoss, "$) - Aucun nouveau trade autorisé");
        return false;
    }
    
    CTrade trade;
    trade.SetExpertMagicNumber(InpMagicNumber);
    
    double price = (direction == ORDER_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Calculer la taille du lot si non spécifiée
    if(lotSize <= 0.0)
    {
        lotSize = InpLotSize; // Utiliser la taille de lot définie dans les paramètres
    }
    
    // Vérifier le lot minimum autorisé
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    if(lotSize < minLot)
    {
        Print("⚠️ Taille de lot trop petite. Ajustée à ", minLot);
        lotSize = minLot;
    }
    
    // Vérifier le risque maximum par trade
    double maxRiskPerTrade = 3.5; // 3.5$ par défaut
    double positionRisk = CalculatePositionRisk(symbol, lotSize, sl);
    
    if(positionRisk > maxRiskPerTrade)
    {
        // Ajuster la taille du lot pour respecter le risque maximum
        double riskRatio = maxRiskPerTrade / positionRisk;
        lotSize = NormalizeDouble(lotSize * riskRatio, 2);
        Print("⚠️ Risque ajusté pour respecter le maximum de ", maxRiskPerTrade, "$");
    }
    
    // Définir les niveaux de SL et TP si non spécifiés
    if(sl == 0.0 && InpStopLossPoints > 0)
    {
        sl = (direction == ORDER_TYPE_BUY) ? price - InpStopLossPoints * point : price + InpStopLossPoints * point;
    }
    
    if(tp == 0.0 && InpTakeProfitPoints > 0)
    {
        tp = (direction == ORDER_TYPE_BUY) ? price + InpTakeProfitPoints * point : price - InpTakeProfitPoints * point;
    }
    
    // Vérifier les niveaux de SL/TP
    if(sl > 0 && tp > 0)
    {
        double minStopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
        if(MathAbs(price - sl) < minStopLevel || MathAbs(tp - price) < minStopLevel)
        {
            Print("❌ Niveaux de SL/TP trop proches du prix. Trade annulé");
            return false;
        }
    }
    
    // Exécuter le trade
    bool result = false;
    if(direction == ORDER_TYPE_BUY)
    {
        result = trade.Buy(lotSize, symbol, 0, sl, tp, "AngelOfSpike");
    }
    else
    {
        result = trade.Sell(lotSize, symbol, 0, sl, tp, "AngelOfSpike");
    }
    
    // Vérifier le résultat
    if(result)
    {
        Print("✅ Trade exécuté avec succès: ", symbol, " ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), 
              " Lot: ", lotSize, " SL: ", sl, " TP: ", tp);
        g_currentTradesCount++;
    }
    else
    {
        Print("❌ Échec de l'exécution du trade: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
    }
    
    return result;
}

//+------------------------------------------------------------------+
//| Détecter un mouvement de prix brusque (spike)                  |
//+------------------------------------------------------------------+
bool DetectSpike(const string symbol)
{
    if(!InpAutoCloseAfterSpike) return false;
    
    // Vérifier si le symbole est un Boom ou Crash
    bool isBoomCrash = (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
    
    // Pour les paires normales, utiliser la détection de volatilité
    if(!isBoomCrash) return false;
    
    MqlRates rates[];
    if(CopyRates(symbol, PERIOD_CURRENT, 0, 10, rates) < 10) return false;
    
    // Calculer la volatilité moyenne sur les 9 dernières bougies (sans la dernière)
    double avgRange = 0;
    for(int i = 1; i < 10; i++)
    {
        avgRange += (rates[i].high - rates[i].low) / SymbolInfoDouble(symbol, SYMBOL_POINT);
    }
    avgRange /= 9.0;
    
    // Vérifier si le mouvement actuel est un spike (3x la moyenne)
    double currentRange = (rates[0].high - rates[0].low) / SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    if(avgRange > 0 && currentRange > avgRange * InpSpikeVolatilityThreshold)
    {
        // Vérifier la direction du mouvement
        bool isUpSpike = (rates[0].close > rates[0].open);
        int direction = isUpSpike ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
        
        // Vérifier que le mouvement est significatif (au moins 10 points)
        if(currentRange < 10.0) return false;
        
        // Dessiner la flèche de signal
        double arrowPrice = isUpSpike ? rates[0].high : rates[0].low;
        DrawSpikeArrow(symbol, direction, arrowPrice);
        
        // Mettre à jour l'état global du spike
        g_spikeDetected = true;
        g_spikeSymbol = symbol;
        
        if(InpDebug)
        {
            string spikeType = isUpSpike ? "HAUSSIER" : "BAISSIER";
            Print("🚨 SPIKE ", spikeType, " DÉTECTÉ: ", symbol, 
                  " - Range actuel: ", DoubleToString(currentRange, 1), 
                  " vs moyenne: ", DoubleToString(avgRange, 1),
                  " (x", DoubleToString(currentRange / avgRange, 1), ")");
        }
        
        return true;
    }
    
    // Réinitialiser la détection de spike si le mouvement est terminé
    if(g_spikeDetected && g_spikeSymbol == symbol)
    {
        g_spikeDetected = false;
        g_spikeSymbol = "";
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Vérifier et fermer les positions si spike capturé              |
//+------------------------------------------------------------------+
void CheckAndCloseSpikePositions(const string symbol)
{
    // Détection et fermeture automatique après spike
    if(InpAutoCloseAfterSpike)
    {
        // Fermeture immédiate au pic du spike
        if(DetectSpike(symbol))
        {
            CloseAllPositionsForSymbol(symbol, "Spike détecté - Fermeture immédiate");
            if(InpDebug) Print("🚀 FERMETURE SPIKE: Position fermée sur ", symbol, " (fermeture au pic du spike)");
        }
    }
    // Vérifier la perte globale avant tout
    static datetime lastGlobalLossCheck = 0;
    if(TimeCurrent() - lastGlobalLossCheck >= 1) // Vérifier toutes les secondes
    {
        double totalGlobalLoss = CalculateTotalGlobalLoss();
        if(totalGlobalLoss >= InpMaxTotalLoss)
        {
            Print("🚨 PERTE GLOBALE MAX ATTEINTE: $", DoubleToString(totalGlobalLoss, 2), " >= $", InpMaxTotalLoss, " - FERMETURE FORCÉE!");
            CloseAllPositionsForLossLimit("PERTE GLOBALE MAX");
            return;
        }
        lastGlobalLossCheck = TimeCurrent();
    }
    
    // Vérifier toutes les positions ouvertes pour ce symbole
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && 
               PositionGetString(POSITION_SYMBOL) == symbol)
            {
                ulong ticket = PositionGetTicket(i);
                int direction = (int)PositionGetInteger(POSITION_TYPE);
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double currentPrice = (direction == POSITION_TYPE_BUY) ? 
                                     SymbolInfoDouble(symbol, SYMBOL_BID) : 
                                     SymbolInfoDouble(symbol, SYMBOL_ASK);
                
                // Calculer le profit en points
                double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
                double profitPoints = 0;
                
                if(direction == POSITION_TYPE_BUY)
                {
                    profitPoints = (currentPrice - openPrice) / point;
                }
    else
    {
                    profitPoints = (openPrice - currentPrice) / point;
                }
                
                // Calculer le profit en dollars
                double profitUSD = PositionGetDouble(POSITION_PROFIT);
                
                // NOUVEAU: Vérifier la perte maximale par position
                if(profitUSD <= -InpMaxTotalLoss)
                {
                    Print("🚨 PERTE MAX PAR POSITION: $", DoubleToString(profitUSD, 2), " - FERMETURE FORCÉE!");
                    if(g_trade.PositionClose(ticket))
                    {
                        Print("✅ Position fermée pour perte max: ", ticket);
                        UpdateActiveTradesCount();
                    }
                    continue;
                }
                
                // Vérifier si c'est un symbole Boom/Crash ou autre
                bool isBoomCrash = (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
                
                bool shouldClose = false;
                string closeReason = "";
                
                // NOUVEAU: Fermeture après spike détecté
                if(InpAutoCloseAfterSpike && g_spikeDetected && g_spikeSymbol == symbol)
                {
                    shouldClose = true;
                    closeReason = "SPIKE DÉTECTÉ - FERMETURE IMMÉDIATE";
                }
                else if(isBoomCrash)
                {
                    // Pour Boom/Crash: fermer après capture du spike (points)
                    if(profitPoints >= InpSpikeCapturePoints)
                    {
                        shouldClose = true;
                        closeReason = "SPIKE CAPTURÉ";
                    }
                }
                else
                {
                    // Pour autres indices: fermer au seuil configuré
                    if(profitUSD >= InpOtherIndicesGainUSD)
                    {
                        shouldClose = true;
                        closeReason = "GAIN " + DoubleToString(InpOtherIndicesGainUSD, 0) + "$ ATTEINT";
                    }
                }
                
                if(shouldClose)
                {
                    if(g_trade.PositionClose(ticket))
                    {
                        if(closeReason == "SPIKE DÉTECTÉ - FERMETURE IMMÉDIATE")
                        {
                            Print("🎯 FERMETURE APRÈS SPIKE! ", symbol, " - Profit: $", DoubleToString(profitUSD, 2));
                        }
                        else if(isBoomCrash)
                        {
                            Print("🎯 SPIKE CAPTURÉ! ", symbol, " - Profit: ", DoubleToString(profitPoints, 1), " points");
                        }
                        else
                        {
                            Print("💰 GAIN ATTEINT! ", symbol, " - Profit: $", DoubleToString(profitUSD, 2));
                        }
                        
                        // Envoyer notification de fermeture
                        if(InpSendNotifications)
                        {
                            string notification = "✅ " + closeReason + " sur " + symbol;
                            if(closeReason == "SPIKE DÉTECTÉ - FERMETURE IMMÉDIATE")
                                notification += " - $" + DoubleToString(profitUSD, 2);
                            else if(isBoomCrash)
                                notification += " - " + DoubleToString(profitPoints, 1) + " points";
                            else
                                notification += " - $" + DoubleToString(profitUSD, 2);
                            
                            SendNotification(notification);
                        }
                        
                        // Mettre à jour le compteur de trades
                        UpdateActiveTradesCount();
                        
                        // Réinitialiser les variables
                        g_currentSymbol = "";
                        g_currentDirection = 0;
                        g_limitOrderCount = 0;
                        
                        // Réinitialiser les signaux de flèche
                        if(g_arrowSignalSymbol == symbol)
                        {
                            g_arrowSignalActive = false;
                            g_arrowSignalSymbol = "";
                            HidePredictiveArrow(symbol);
                        }
                        
                        // Annuler tous les ordres limit restants pour ce symbole
                        CancelAllLimitOrders(symbol);
                        
                        // Log de libération d'un slot de trade
                        if(InpDebug)
                        {
                            Print("🔄 Slot de trade libéré - ", g_currentTradesCount, "/", InpMaxSimultaneousTrades, " trades actifs");
                        }
    }
    else
    {
                        Print("❌ Erreur fermeture position ", ticket, " sur ", symbol, " - Erreur: ", GetLastError());
                    }
                }
                else if(InpDebug)
                {
                    if(isBoomCrash)
                    {
                        Print("📊 ", symbol, " - Profit actuel: ", DoubleToString(profitPoints, 1), " points (seuil: ", InpSpikeCapturePoints, ")");
    }
    else
    {
                        Print("📊 ", symbol, " - Profit actuel: $", DoubleToString(profitUSD, 2), " (seuil: $", InpOtherIndicesGainUSD, ")");
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Analyser les conditions techniques                               |
//+------------------------------------------------------------------+
double AnalyzeTechnicalConditions(const string symbol)
{
    if(InpDebug) Print("🔍 Analyse technique pour ", symbol);
    
    double probability = 0.0;
    
    // Analyse basique pour Boom/Crash
    if(StringFind(symbol, "Boom") >= 0)
    {
        // Pour Boom, chercher des signaux d'achat
        double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        double price1 = iClose(symbol, PERIOD_CURRENT, 1);
        double price5 = iClose(symbol, PERIOD_CURRENT, 5);
        
        if(price1 > price5) // Tendance haussière
        {
            probability += 40.0;
        }
        
        // Volatilité récente
        double volatility = CalculateVolatility(symbol, 3);
        if(volatility > 0.3)
        {
            probability += 30.0;
        }
        
        // Pression d'achat
        double buyPressure = CalculateBuyPressure(symbol);
        if(buyPressure > 0.4)  // Seuil de pression réduit à 0.4
        {
            probability += 30.0;
            if(InpDebug) Print("📊 Pression d'achat détectée: ", DoubleToString(buyPressure*100, 1), "%");
        }
    }
    else if(StringFind(symbol, "Crash") >= 0)
    {
        // Pour Crash, chercher des signaux de vente
        double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
        double price1 = iClose(symbol, PERIOD_CURRENT, 1);
        double price5 = iClose(symbol, PERIOD_CURRENT, 5);
        
        if(price1 < price5) // Tendance baissière
        {
            probability += 40.0;
        }
        
        // Volatilité récente
        double volatility = CalculateVolatility(symbol, 3);
        if(volatility > 0.3)
        {
            probability += 30.0;
        }
        
        // Pression de vente
        double sellPressure = CalculateSellPressure(symbol);
        if(sellPressure > 0.4)  // Seuil de pression réduit à 0.4
        {
            probability += 30.0;
            if(InpDebug) Print("📉 Pression de vente détectée: ", DoubleToString(sellPressure*100, 1), "%");
        }
    }
    
    // Limiter la probabilité maximale
    probability = MathMin(probability, 95.0);
    
    if(InpDebug) 
    {
        Print("\n🔍 ===== ANALYSE TECHNIQUE TERMINÉE =====");
        Print("📊 Symbole: ", symbol);
        Print("📈 Probabilité finale: ", DoubleToString(probability, 1), "%");
        Print("🎯 Seuil d'exécution: ", InpAutoExecuteThreshold, "%");
        Print("==================================\n");
    }
    
    return probability;
}


//+------------------------------------------------------------------+
//| Calculer le lot                                                 |
//+------------------------------------------------------------------+
double CalculateLot(const string symbol)
{
    double lot = InpLotSize; // Utilise maintenant 0.2 par défaut
    
    // Obtenir les contraintes du symbole
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // CORRIGÉ: Forcer le lot minimum à 0.2 pour tous les symboles
    lot = MathMax(lot, 0.2); // Lot minimum garanti à 0.2
    
    // Normaliser le lot selon les contraintes du broker
    if(minLot > 0 && maxLot > 0 && lotStep > 0)
    {
        lot = MathMax(lot, minLot); // Respecter le minimum du broker si > 0.2
        lot = MathMin(lot, MathMin(maxLot, InpMaxLotSize));
        lot = MathRound(lot / lotStep) * lotStep;
    }
    
    // S'assurer que le lot final est au minimum 0.2
    return MathMax(lot, 0.2);
}

//+------------------------------------------------------------------+
//| Calculer SL/TP optimisés pour Boom/Crash                        |
//+------------------------------------------------------------------+
bool CalculateSLTP(const string symbol, int direction, double entryPrice, double &sl, double &tp)
{
    // Validation des paramètres d'entrée
    if(entryPrice <= 0)
    {
        if(InpDebug) Print("❌ Prix d'entrée invalide: ", entryPrice);
        return false;
    }
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(point <= 0)
    {
        if(InpDebug) Print("❌ Point invalide pour ", symbol, ": ", point);
        return false;
    }
    
    bool isBoomCrash = (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
    
    if(isBoomCrash)
    {
        // Configuration dynamique pour Boom/Crash basée sur la volatilité
        double volatility = CalculateVolatility(symbol, 5); // Volatilité sur 5 périodes
        double baseSLPoints = 12.0; // SL de base plus serré
        double baseTPPoints = 25.0; // TP de base pour Boom/Crash
        
        // NOUVEAU: Ajuster selon la confiance du signal
        double confidenceMultiplier = 1.0;
        if(g_lastPredictionProbability >= InpAutoExecuteThreshold)
        {
            // Pour les signaux haute confiance (80%+), optimiser les SL/TP
            confidenceMultiplier = 0.8; // SL/TP plus serrés pour haute confiance
            if(InpDebug) Print("🎯 Signal haute confiance détecté - Optimisation SL/TP");
        }
        
        // Ajuster le SL selon la volatilité et la confiance
        double slPoints = baseSLPoints * confidenceMultiplier;
        if(volatility > 0.5) // Haute volatilité
        {
            slPoints = (baseSLPoints + 5.0) * confidenceMultiplier; // SL plus large en cas de haute volatilité
        }
        else if(volatility < 0.2) // Faible volatilité
        {
            slPoints = (baseSLPoints - 3.0) * confidenceMultiplier; // SL plus serré en cas de faible volatilité
        }
        
        // Ajuster le TP selon la volatilité et la confiance
        double tpPoints = baseTPPoints * (1.0 + (1.0 - confidenceMultiplier)); // TP plus large pour haute confiance
        if(volatility > 0.5) // Haute volatilité = TP plus large
        {
            tpPoints = (baseTPPoints + 10.0) * (1.0 + (1.0 - confidenceMultiplier));
        }
        else if(volatility < 0.2) // Faible volatilité = TP plus serré
        {
            tpPoints = (baseTPPoints - 5.0) * (1.0 + (1.0 - confidenceMultiplier));
        }
        
        // S'assurer que le SL reste dans des limites raisonnables
        slPoints = MathMax(6.0, MathMin(slPoints, 25.0));
        // S'assurer que le TP reste dans des limites raisonnables
        tpPoints = MathMax(15.0, MathMin(tpPoints, 60.0));
        
        if(direction == POSITION_TYPE_BUY)
        {
            sl = entryPrice - (slPoints * point);
            tp = entryPrice + (tpPoints * point); // TP fixe pour Boom/Crash
        }
        else
        {
            sl = entryPrice + (slPoints * point);
            tp = entryPrice - (tpPoints * point); // TP fixe pour Boom/Crash
        }
        
        if(InpDebug)
        {
            Print("📊 Boom/Crash SL/TP dynamique: Volatilité=", DoubleToString(volatility, 3), 
                  ", SL=", DoubleToString(slPoints, 1), " points, TP=", DoubleToString(tpPoints, 1), " points");
        }
    }
    else
    {
        // Configuration pour autres indices
        double slPoints = 25.0;  // SL plus large pour autres indices
        double tpPoints = 50.0;  // TP fixe pour autres indices
        
        if(direction == POSITION_TYPE_BUY)
        {
            sl = entryPrice - (slPoints * point);
            tp = entryPrice + (tpPoints * point);
        }
        else
        {
            sl = entryPrice + (slPoints * point);
            tp = entryPrice - (tpPoints * point);
        }
    }
    
    // Vérifier les distances minimales
    double minDistance = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    if(minDistance > 0)
    {
        if(direction == POSITION_TYPE_BUY)
        {
            if(sl > entryPrice - minDistance) sl = entryPrice - minDistance;
            if(tp > 0 && tp < entryPrice + minDistance) tp = entryPrice + minDistance;
        }
        else
        {
            if(sl < entryPrice + minDistance) sl = entryPrice + minDistance;
            if(tp > 0 && tp > entryPrice - minDistance) tp = entryPrice - minDistance;
        }
    }
    
    // Validation finale des prix calculés
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    if(digits < 0) digits = 5; // Valeur par défaut
    
    // Normaliser les prix
    sl = NormalizeDouble(sl, digits);
    tp = NormalizeDouble(tp, digits);
    
    // Validation des distances minimales
    double minDistanceValidation = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    if(minDistanceValidation <= 0) minDistanceValidation = 10 * point; // Distance minimale par défaut
    
    // Vérifier que SL et TP sont valides
    if(sl <= 0)
    {
        if(InpDebug) Print("❌ SL invalide calculé: ", sl);
        return false;
    }
    
    if(tp <= 0)
    {
        if(InpDebug) Print("❌ TP invalide calculé: ", tp);
        return false;
    }
    
    // Vérifier les distances par rapport au prix d'entrée
    double slDistance = MathAbs(entryPrice - sl);
    double tpDistance = MathAbs(tp - entryPrice);
    
    if(slDistance < minDistanceValidation)
    {
        if(InpDebug) Print("❌ SL trop proche: distance=", DoubleToString(slDistance, digits), 
                          " min=", DoubleToString(minDistanceValidation, digits));
        return false;
    }
    
    if(tpDistance < minDistanceValidation)
    {
        if(InpDebug) Print("❌ TP trop proche: distance=", DoubleToString(tpDistance, digits), 
                          " min=", DoubleToString(minDistanceValidation, digits));
        return false;
    }
    
    // Vérifier que les prix sont dans des limites raisonnables
    double maxPrice = entryPrice * 2.0; // Prix maximum (200% du prix d'entrée)
    double minPrice = entryPrice * 0.5;  // Prix minimum (50% du prix d'entrée)
    
    if(sl > maxPrice || sl < minPrice)
    {
        if(InpDebug) Print("❌ SL hors limites: ", DoubleToString(sl, digits), 
                          " (min=", DoubleToString(minPrice, digits), 
                          " max=", DoubleToString(maxPrice, digits), ")");
        return false;
    }
    
    if(tp > maxPrice || tp < minPrice)
    {
        if(InpDebug) Print("❌ TP hors limites: ", DoubleToString(tp, digits), 
                          " (min=", DoubleToString(minPrice, digits), 
                          " max=", DoubleToString(maxPrice, digits), ")");
        return false;
    }
    
    if(InpDebug)
    {
        string slTpInfo = StringFormat("SL/TP validés pour %s: SL=%.5f, TP=%.5f", 
                                      symbol, sl, tp);
        Print("📊 ", slTpInfo);
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Compter les positions pour un symbole                         |
//+------------------------------------------------------------------+
int CountSymbolPositions(const string symbol)
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && 
               PositionGetString(POSITION_SYMBOL) == symbol)
            {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Vérifier si on peut trader le symbole                           |
//+------------------------------------------------------------------+
bool CanTradeSymbol(const string symbol)
{
    // Vérifier si le symbole est disponible
    if(!SymbolSelect(symbol, true))
    {
        return false;
    }
    
    // Si la détection automatique est activée, accepter tous les symboles détectés
    if(InpAutoDetectAllBoomCrash || InpAutoDetectOtherIndices)
    {
        // Vérifier si c'est un Boom/Crash ou un autre indice selon les paramètres
        bool isBoomCrash = (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
        
        if((isBoomCrash && InpAutoDetectAllBoomCrash) || 
           (!isBoomCrash && InpAutoDetectOtherIndices))
        {
            return true;
        }
    }
    
    // Vérifier si le symbole est dans la liste autorisée
    if(StringFind(InpAllowedSymbols, symbol) >= 0)
    {
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Dessiner une flèche de signal de spike                         |
//+------------------------------------------------------------------+
void DrawSpikeArrow(const string symbol, int direction, double price)
{
    // Supprimer les anciennes flèches pour ce symbole
    ObjectsDeleteAll(0, "SpikeArrow_" + symbol + "_");
    
    // Créer un identifiant unique pour la flèche
    string arrowName = "SpikeArrow_" + symbol + "_" + IntegerToString(GetTickCount());
    
    // Définir la couleur de la flèche
    color arrowColor = (direction == POSITION_TYPE_BUY) ? clrLime : clrRed;
    int arrowCode = (direction == POSITION_TYPE_BUY) ? 233 : 234; // Flèche verte pour achat, rouge pour vente
    
    // Créer la flèche
    if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, TimeCurrent(), price))
    {
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
        ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, true);
        
        // Afficher un message de débogage
        if(InpDebug)
        {
            string signalType = (direction == POSITION_TYPE_BUY) ? "SPIKE HAUSSIER 🟢" : "SPIKE BAISSIER 🔴";
            Print("📢 ", signalType, " détecté sur ", symbol, " à ", DoubleToString(price, _Digits));
        }
    }else
    {
        Print("❌ Erreur création flèche ", arrowName, ": ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Calculer la volatilité                                          |
//+------------------------------------------------------------------+
double CalculateVolatility(const string symbol, int periods)
{
    double sum = 0.0;
    int validPeriods = 0;
    
    for(int i = 1; i <= periods; i++)
    {
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low = iLow(symbol, PERIOD_CURRENT, i);
        double close = iClose(symbol, PERIOD_CURRENT, i);
        
        if(high > 0 && low > 0 && close > 0)
        {
            double range = high - low;
            if(range > 0)
            {
                sum += range / close; // Volatilité normalisée
                validPeriods++;
            }
        }
    }
    
    return validPeriods > 0 ? sum / validPeriods : 0.0;
}

//+------------------------------------------------------------------+
//| Calculer la pression d'achat                                    |
//+------------------------------------------------------------------+
double CalculateBuyPressure(const string symbol)
{
    double buyPressure = 0.0;
    int validBars = 0;
    
    for(int i = 1; i <= 3; i++) // Analyser les 3 dernières bougies
    {
        double open = iOpen(symbol, PERIOD_CURRENT, i);
        double close = iClose(symbol, PERIOD_CURRENT, i);
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low = iLow(symbol, PERIOD_CURRENT, i);
        
        if(open > 0 && close > 0 && high > 0 && low > 0)
        {
            if(close > open) // Bougie haussière
            {
                double bodySize = close - open;
                double totalRange = high - low;
                if(totalRange > 0)
                {
                    buyPressure += bodySize / totalRange;
                    validBars++;
                }
            }
        }
    }
    
    return validBars > 0 ? buyPressure / validBars : 0.0;
}

//+------------------------------------------------------------------+
//| Calculer la pression de vente                                   |
//+------------------------------------------------------------------+
double CalculateSellPressure(const string symbol)
{
    double sellPressure = 0.0;
    int validBars = 0;
    
    for(int i = 1; i <= 3; i++) // Analyser les 3 dernières bougies
    {
        double open = iOpen(symbol, PERIOD_CURRENT, i);
        double close = iClose(symbol, PERIOD_CURRENT, i);
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low = iLow(symbol, PERIOD_CURRENT, i);
        
        if(open > 0 && close > 0 && high > 0 && low > 0)
        {
            if(close < open) // Bougie baissière
            {
                double bodySize = open - close;
                double totalRange = high - low;
                if(totalRange > 0)
                {
                    sellPressure += bodySize / totalRange;
                    validBars++;
                }
            }
        }
    }
    
    return validBars > 0 ? sellPressure / validBars : 0.0;
}

//+------------------------------------------------------------------+
//| Compter les ordres limit pour un symbole                        |
//+------------------------------------------------------------------+
int CountLimitOrders(const string symbol)
{
    int count = 0;
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderGetTicket(i))
        {
            ulong magic = OrderGetInteger(ORDER_MAGIC);
            string orderSymbol = OrderGetString(ORDER_SYMBOL);
            ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            
            if(magic == InpMagicNumber && 
               orderSymbol == symbol &&
               (orderType == ORDER_TYPE_BUY_LIMIT || 
                orderType == ORDER_TYPE_SELL_LIMIT))
            {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Annuler tous les ordres limit pour un symbole                   |
//+------------------------------------------------------------------+
void CancelAllLimitOrders(const string symbol)
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderGetTicket(i))
        {
            ulong ticket = OrderGetInteger(ORDER_TICKET);
            ulong magic = OrderGetInteger(ORDER_MAGIC);
            string orderSymbol = OrderGetString(ORDER_SYMBOL);
            ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
            
            if(magic == InpMagicNumber && 
               orderSymbol == symbol &&
               (orderType == ORDER_TYPE_BUY_LIMIT || 
                orderType == ORDER_TYPE_SELL_LIMIT))
            {
                if(g_trade.OrderDelete(ticket))
                {
                    Print("🗑️ Ordre limit annulé: ", ticket, " pour ", symbol);
                }
                else
                {
                    Print("❌ Erreur annulation ordre limit: ", ticket, " - Erreur: ", GetLastError());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Détecter automatiquement les autres indices                     |
//+------------------------------------------------------------------+
string GetOtherIndices()
{
    string otherIndices = "";
    int totalSymbols = SymbolsTotal(false);
    
    // Limiter le scan pour éviter les surcharges
    int maxSymbolsToScan = 50; // Maximum 50 symboles à scanner
    int symbolsToScan = MathMin(totalSymbols, maxSymbolsToScan);
    
    for(int i = 0; i < symbolsToScan; i++)
    {
        string symbolName = SymbolName(i, false);
        
        // Vérifier si c'est un indice (contient "Index") mais pas Boom/Crash
        if(StringFind(symbolName, "Index") >= 0 && 
           StringFind(symbolName, "Boom") < 0 && 
           StringFind(symbolName, "Crash") < 0)
        {
            // Vérifier que le symbole est tradable
            if(SymbolSelect(symbolName, true))
            {
                if(otherIndices != "") otherIndices += ",";
                otherIndices += symbolName;
                
                if(InpDebug) Print("🔍 Autre indice détecté: ", symbolName);
            }
        }
    }
    
    if(InpDebug && otherIndices != "") 
        Print("📊 Total autres indices trouvés: ", otherIndices);
    
    return otherIndices;
}

//+------------------------------------------------------------------+
//| Vérifier si le trading est autorisé (24h/24)                    |
//+------------------------------------------------------------------+
bool IsTradingAllowed()
{
    // Si le trading 24h/24 est désactivé, vérifier les sessions
    if(!Inp24HourTrading)
    {
        datetime currentTime = TimeCurrent();
        MqlDateTime timeStruct;
        TimeToStruct(currentTime, timeStruct);
        
        int currentHour = timeStruct.hour;
        
        // Vérifier si on est dans la plage horaire autorisée
        if(InpSessionStartHour <= InpSessionEndHour)
        {
            // Session normale (ex: 8h-18h)
            if(currentHour < InpSessionStartHour || currentHour > InpSessionEndHour)
            {
                if(InpDebug) Print("🚫 TRADING HORS SESSION: Heure actuelle ", currentHour, "h (session: ", InpSessionStartHour, "h-", InpSessionEndHour, "h)");
                return false;
            }
        }
        else
        {
            // Session qui traverse minuit (ex: 22h-6h)
            if(currentHour < InpSessionStartHour && currentHour > InpSessionEndHour)
            {
                if(InpDebug) Print("🚫 TRADING HORS SESSION: Heure actuelle ", currentHour, "h (session: ", InpSessionStartHour, "h-", InpSessionEndHour, "h)");
                return false;
            }
        }
    }
    
    // Vérifier les week-ends si activé
    if(InpSkipWeekends)
    {
        datetime currentTime = TimeCurrent();
        MqlDateTime timeStruct;
        TimeToStruct(currentTime, timeStruct);
        
        // 0 = Dimanche, 6 = Samedi
        if(timeStruct.day_of_week == 0 || timeStruct.day_of_week == 6)
        {
            if(InpDebug) Print("🚫 TRADING WEEK-END: ", (timeStruct.day_of_week == 0 ? "Dimanche" : "Samedi"));
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Valider les prix des ordres limit                               |
//+------------------------------------------------------------------+
bool ValidateLimitOrderPrices(const string symbol, int direction, double limitPrice, double sl, double tp)
{
    double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    if(direction == POSITION_TYPE_BUY)
    {
        // BUY LIMIT: prix d'entrée doit être EN DESSOUS du prix actuel
        if(limitPrice >= currentAsk)
        {
            Print("❌ BUY LIMIT invalide: Prix d'entrée (", DoubleToString(limitPrice, digits), 
                  ") >= Ask actuel (", DoubleToString(currentAsk, digits), ")");
            return false;
        }
        
        // SL doit être EN DESSOUS du prix d'entrée
        if(sl >= limitPrice)
        {
            Print("❌ BUY LIMIT SL invalide: SL (", DoubleToString(sl, digits), 
                  ") >= Prix d'entrée (", DoubleToString(limitPrice, digits), ")");
            return false;
        }
        
        // TP doit être AU-DESSUS du prix d'entrée (obligatoire)
        if(tp <= limitPrice)
        {
            Print("❌ BUY LIMIT TP invalide: TP (", DoubleToString(tp, digits), 
                  ") <= Prix d'entrée (", DoubleToString(limitPrice, digits), ")");
            return false;
        }
    }
    else
    {
        // SELL LIMIT: prix d'entrée doit être AU-DESSUS du prix actuel
        if(limitPrice <= currentBid)
        {
            Print("❌ SELL LIMIT invalide: Prix d'entrée (", DoubleToString(limitPrice, digits), 
                  ") <= Bid actuel (", DoubleToString(currentBid, digits), ")");
            return false;
        }
        
        // SL doit être AU-DESSUS du prix d'entrée
        if(sl <= limitPrice)
        {
            Print("❌ SELL LIMIT SL invalide: SL (", DoubleToString(sl, digits), 
                  ") <= Prix d'entrée (", DoubleToString(limitPrice, digits), ")");
            return false;
        }
        
        // TP doit être EN DESSOUS du prix d'entrée (obligatoire)
        if(tp >= limitPrice)
        {
            Print("❌ SELL LIMIT TP invalide: TP (", DoubleToString(tp, digits), 
                  ") >= Prix d'entrée (", DoubleToString(limitPrice, digits), ")");
            return false;
        }
    }
    
    if(InpDebug)
    {
        Print("✅ Validation des prix réussie pour ", symbol, " - Direction: ", 
              (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Vérifie si on peut ouvrir un NOUVEAU trade pour ce symbole       |
//+------------------------------------------------------------------+
bool CanOpenNewTradeForSymbol(const string symbol)
{
    // Règle 1 : A-t-on déjà un trade ou un ordre en attente sur CE symbole ?
    if(PositionSelect(symbol) || OrdersTotal() > 0)
    {
        // Vérifie plus en détail s'il y a des positions ou ordres pour ce symbole avec notre magic number
        if(CountSymbolPositions(symbol) > 0 || CountLimitOrders(symbol) > 0)
        {
             if(InpDebug) Print("INFO [", symbol, "]: Trade ou ordre déjà en cours pour ce symbole.");
            return false;
        }
    }
    
    // Règle 2 : A-t-on atteint le nombre maximum de trades simultanés ?
    if(g_currentTradesCount >= InpMaxSimultaneousTrades)
    {
        if(InpDebug) Print("INFO [", symbol, "]: Limite de ", InpMaxSimultaneousTrades, " trades simultanés atteinte. Trades actifs: ", g_currentTradesCount);
                    return false;
    }
    
    // Toutes les conditions sont remplies
    return true;
}

//+------------------------------------------------------------------+
//| Mettre à jour le compteur de trades actifs                      |
//+------------------------------------------------------------------+
void UpdateActiveTradesCount()
{
    g_currentTradesCount = 0;
    
    // Limiter le nombre de positions à vérifier
    int maxPositions = 20; // Maximum 20 positions
    int positionsToCheck = MathMin(PositionsTotal(), maxPositions);
    
    // Compter les positions actives
    for(int i = positionsToCheck - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                string symbol = PositionGetString(POSITION_SYMBOL);
                if(g_currentTradesCount < 10) // Limite de sécurité
                {
                    g_activeTradesSymbols[g_currentTradesCount] = symbol;
                    g_currentTradesCount++;
                }
            }
        }
    }
    
    // Limiter le nombre d'ordres à vérifier
    int maxOrders = 20; // Maximum 20 ordres
    int ordersToCheck = MathMin(OrdersTotal(), maxOrders);
    
    // Compter les ordres limit actifs
    for(int i = ordersToCheck - 1; i >= 0; i--)
    {
        if(OrderGetTicket(i) > 0)
        {
            if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber &&
               (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT || 
                OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT))
            {
                string symbol = OrderGetString(ORDER_SYMBOL);
                // Vérifier si ce symbole n'est pas déjà compté
                bool alreadyCounted = false;
                for(int j = 0; j < g_currentTradesCount; j++)
                {
                    if(g_activeTradesSymbols[j] == symbol)
                    {
                        alreadyCounted = true;
                        break;
                    }
                }
                if(!alreadyCounted && g_currentTradesCount < 10)
                {
                    g_activeTradesSymbols[g_currentTradesCount] = symbol;
                    g_currentTradesCount++;
                }
            }
        }
    }
    
    if(InpDebug && g_currentTradesCount > 0)
    {
        Print("📊 Trades actifs: ", g_currentTradesCount, "/", InpMaxSimultaneousTrades);
    }
}

//+------------------------------------------------------------------+
//| Construire la liste complète des symboles à trader              |
//+------------------------------------------------------------------+
void BuildCompleteSymbolList(string &symbols[])
{
    // Commencer avec les symboles de base
    string baseSymbols[];
    StringSplit(InpAllowedSymbols, ',', baseSymbols);
    
    // Copier les symboles de base
    int baseSize = ArraySize(baseSymbols);
    if(baseSize > 0)
    {
        ArrayResize(symbols, baseSize);
        for(int i = 0; i < baseSize; i++)
        {
            symbols[i] = baseSymbols[i];
        }
    }
    
    // Ajouter TOUS les symboles Boom/Crash si détection automatique activée
    if(InpAutoDetectAllBoomCrash)
    {
        string boomCrashSymbols = GetAllBoomCrashSymbols();
        if(boomCrashSymbols != "")
        {
            string additionalSymbols[];
            StringSplit(boomCrashSymbols, ',', additionalSymbols);
            
            // Ajouter les nouveaux symboles à la liste
            int currentSize = ArraySize(symbols);
            ArrayResize(symbols, currentSize + ArraySize(additionalSymbols));
            
            for(int i = 0; i < ArraySize(additionalSymbols); i++)
            {
                symbols[currentSize + i] = additionalSymbols[i];
            }
        }
    }
    
    // Ajouter les autres indices si détection automatique activée
    if(InpAutoDetectOtherIndices)
    {
        string otherIndices = GetOtherIndices();
        if(otherIndices != "")
        {
            string additionalSymbols[];
            StringSplit(otherIndices, ',', additionalSymbols);
            
            // Ajouter les nouveaux symboles à la liste
            int currentSize = ArraySize(symbols);
            ArrayResize(symbols, currentSize + ArraySize(additionalSymbols));
            
            for(int i = 0; i < ArraySize(additionalSymbols); i++)
            {
                symbols[currentSize + i] = additionalSymbols[i];
            }
        }
    }
    
    // Supprimer les doublons
    RemoveDuplicateSymbols(symbols);
    
    if(InpDebug)
    {
        Print("📊 Total symboles détectés: ", ArraySize(symbols));
        for(int i = 0; i < ArraySize(symbols); i++)
        {
            Print("   ", i+1, ". ", symbols[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Détecter TOUS les symboles Boom/Crash disponibles               |
//+------------------------------------------------------------------+
string GetAllBoomCrashSymbols()
{
    string boomCrashSymbols = "";
    int totalSymbols = SymbolsTotal(true); // true = seulement les symboles visibles
    
    // Limiter le scan pour éviter les surcharges
    int maxSymbolsToScan = 100; // Maximum 100 symboles à scanner
    int symbolsToScan = MathMin(totalSymbols, maxSymbolsToScan);
    
    if(InpDebug) Print("🔍 Scan de ", symbolsToScan, " symboles pour détecter Boom/Crash...");
    
    for(int i = 0; i < symbolsToScan; i++)
    {
        string symbolName = SymbolName(i, true);
        
        // Vérifier si c'est un symbole Boom ou Crash
        if(StringFind(symbolName, "Boom") >= 0 || StringFind(symbolName, "Crash") >= 0)
        {
            // Vérifier que le symbole est tradable
            if(SymbolSelect(symbolName, true))
            {
                if(boomCrashSymbols != "") boomCrashSymbols += ",";
                boomCrashSymbols += symbolName;
                
                if(InpDebug) Print("✅ Boom/Crash détecté: ", symbolName);
            }
        }
    }
    
    if(InpDebug && boomCrashSymbols != "") 
        Print("🎯 Total Boom/Crash trouvés: ", boomCrashSymbols);
    
    return boomCrashSymbols;
}

//+------------------------------------------------------------------+
//| Supprimer les symboles en double de la liste                    |
//+------------------------------------------------------------------+
void RemoveDuplicateSymbols(string &symbols[])
{
    int size = ArraySize(symbols);
    if(size <= 1) return; // Pas de doublons possibles
    
    // Créer un tableau temporaire pour les symboles uniques
    string uniqueSymbols[];
    ArrayResize(uniqueSymbols, 0);
    
    for(int i = 0; i < size; i++)
    {
        bool isDuplicate = false;
        
        // Vérifier si ce symbole existe déjà
        for(int j = 0; j < ArraySize(uniqueSymbols); j++)
        {
            if(symbols[i] == uniqueSymbols[j])
            {
                isDuplicate = true;
                break;
            }
        }
        
        // Ajouter seulement si ce n'est pas un doublon
        if(!isDuplicate)
        {
            ArrayResize(uniqueSymbols, ArraySize(uniqueSymbols) + 1);
            uniqueSymbols[ArraySize(uniqueSymbols) - 1] = symbols[i];
        }
    }
    
    // Remplacer le tableau original
    ArrayResize(symbols, ArraySize(uniqueSymbols));
    for(int i = 0; i < ArraySize(uniqueSymbols); i++)
    {
        symbols[i] = uniqueSymbols[i];
    }
}

//+------------------------------------------------------------------+
//| Traitement de l'analyse prédictive et visuelle                  |
//+------------------------------------------------------------------+
void ProcessPredictiveAnalysis(const string symbol)
{
    // Analyser la probabilité de spike avec des critères plus stricts
    double spikeProbability = AnalyzeSpikeProbability(symbol);
    
    // NOUVEAU: Analyser spécifiquement les step patterns
    double stepPatternProbability = AnalyzeStepPatterns(symbol);
    
    // Mettre à jour les variables globales
    g_lastPredictionSymbol = symbol;
    g_lastPredictionProbability = spikeProbability;
    
    // NOUVEAU: Seuil strict de 80% pour tous les signaux prédictifs
    if(spikeProbability >= InpAutoExecuteThreshold)
    {
        // Vérifier si c'est un nouveau signal (pas déjà actif)
        if(!g_predictionActive || g_predictionSymbol != symbol)
        {
            // NOUVEAU SIGNAL HAUTE CONFIANCE DÉTECTÉ - SPIKE IMMINENT !
            int direction = ChooseSignalDirection(symbol);
            
            if(direction != 0)
            {
                Print("🚨 SPIKE IMMINENT HAUTE CONFIANCE DÉTECTÉ! ", symbol, " - Probabilité: ", DoubleToString(spikeProbability, 1), "%");
                
                // Démarrer la prédiction avec timing
                StartSpikePrediction(symbol, direction, spikeProbability);
            }
        }
        
        // Gérer le timing des prédictions actives
        ManagePredictionTiming(symbol);
    }
    else
    {
        // Masquer la flèche si la probabilité est trop faible (< 80%)
        HidePredictiveArrow(symbol);
        HideStepPatternSetup(symbol);
        
        // Réinitialiser le signal si la probabilité baisse
        if(g_predictionActive && g_predictionSymbol == symbol)
        {
            ResetPrediction();
            if(InpDebug) Print("📉 Signal de flèche annulé pour ", symbol, " - Probabilité trop faible (", DoubleToString(spikeProbability, 1), "% < ", InpAutoExecuteThreshold, "%)");
        }
        
        // Afficher les signaux rejetés en debug
        if(InpDebug)
        {
            Print("🚫 SIGNAL REJETÉ: ", symbol, " - Probabilité: ", DoubleToString(spikeProbability, 1), "% (seuil: ", InpAutoExecuteThreshold, "%)");
        }
    }
}

//+------------------------------------------------------------------+
//| Validate Order Prices                                           |
//+------------------------------------------------------------------+
bool ValidateOrderPrices(string symbol, double entryPrice, double &sl, double &tp, int direction)
{
    if(entryPrice <= 0.0 || sl <= 0.0 || tp <= 0.0)
    {
        Print("❌ VALIDATION PRIX ÉCHOUÉE [", symbol, "]: Prix SL/TP/Entry ne peuvent être nuls ou négatifs.");
        return false;
    }
        
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double stopLevelPoints = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDistance = stopLevelPoints * point;

    // Si le broker ne fournit pas de StopLevel, on utilise une valeur de sécurité
    if(minDistance <= 0) minDistance = 5 * point;

    double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    if(direction == (int)POSITION_TYPE_BUY)
    {
        // Pour un BUY, le SL doit être sous le prix d'entrée, le TP au-dessus.
        if(sl >= entryPrice) { Print("❌ VAL. PRIX [BUY]: SL doit être < Entry."); return false; }
        if(tp <= entryPrice) { Print("❌ VAL. PRIX [BUY]: TP doit être > Entry."); return false; }

        // Vérifier la distance minimale du SL par rapport au BID actuel (pour les ordres marché)
        if(MathAbs(sl - currentBid) < minDistance)
        {
             Print("❌ VAL. PRIX [BUY]: SL trop proche du prix BID actuel. Distance: ", MathAbs(sl - currentBid), " Min: ", minDistance);
             sl = currentBid - minDistance; // Ajustement agressif
             Print("   -> SL ajusté à ", NormalizeDouble(sl, digits));
        }
    }
    else // POSITION_TYPE_SELL
    {
        // Pour un SELL, le SL doit être au-dessus du prix d'entrée, le TP en-dessous.
        if(sl <= entryPrice) { Print("❌ VAL. PRIX [SELL]: SL doit être > Entry."); return false; }
        if(tp >= entryPrice) { Print("❌ VAL. PRIX [SELL]: TP doit être < Entry."); return false; }
        
        // Vérifier la distance minimale du SL par rapport au ASK actuel (pour les ordres marché)
        if(MathAbs(sl - currentAsk) < minDistance)
        {
            Print("❌ VAL. PRIX [SELL]: SL trop proche du prix ASK actuel. Distance: ", DoubleToString(MathAbs(sl - currentAsk), 5), " Min: ", DoubleToString(minDistance, 5));
            sl = currentAsk + minDistance; // Ajustement agressif
            Print("   -> SL ajusté à ", NormalizeDouble(sl, digits));
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Analyser la probabilité de spike                                |
//+------------------------------------------------------------------+
double AnalyzeSpikeProbability(const string symbol)
{
    double probability = 0.0;
    
    // 1. Analyse de la volatilité récente (plus sélective)
    double recentVolatility = CalculateVolatility(symbol, InpPredictionPeriods);
    if(recentVolatility > 0.6) // Seuil plus élevé
    {
        probability += 30.0; // Haute volatilité = plus de chance de spike
    }
    else if(recentVolatility > 0.4)
    {
        probability += 20.0;
    }
    else if(recentVolatility < 0.1) // Très faible volatilité = accumulation
    {
        probability += 15.0; // Potentiel de breakout
    }
    
    // 2. Analyse des patterns de prix (plus stricte)
    double pricePatternScore = AnalyzePricePatterns(symbol);
    probability += pricePatternScore;
    
    // 3. Analyse du momentum (critères plus stricts)
    double momentumScore = AnalyzeMomentum(symbol);
    probability += momentumScore;
    
    // 4. Analyse des niveaux de support/résistance
    double supportResistanceScore = AnalyzeSupportResistance(symbol);
    probability += supportResistanceScore;
    
    // 5. Analyse temporelle (périodes de forte activité)
    double timeScore = AnalyzeTimePatterns();
    probability += timeScore;
    
    // 6. NOUVEAU: Analyse de la compression (accumulation avant spike)
    double compressionScore = AnalyzePriceCompression(symbol);
    probability += compressionScore;
    
    // 7. NOUVEAU: Analyse de la pression d'achat/vente
    double pressureScore = AnalyzeMarketPressure(symbol);
    probability += pressureScore;
    
    // Limiter la probabilité maximale
    probability = MathMin(probability, 95.0);
    
    // Seuil minimum pour considérer un signal valide
    if(probability < 70.0)
    {
        return 0.0; // Pas de signal si probabilité trop faible
    }
    
    return probability;
}

//+------------------------------------------------------------------+
//| Analyser les patterns de prix                                   |
//+------------------------------------------------------------------+
double AnalyzePricePatterns(const string symbol)
{
    double score = 0.0;
    
    // Analyser les 5 dernières bougies
    for(int i = 1; i <= 5; i++)
    {
        double open = iOpen(symbol, PERIOD_CURRENT, i);
        double close = iClose(symbol, PERIOD_CURRENT, i);
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low = iLow(symbol, PERIOD_CURRENT, i);
        
        if(open > 0 && close > 0 && high > 0 && low > 0)
        {
            double bodySize = MathAbs(close - open);
            double totalRange = high - low;
            
            if(totalRange > 0)
            {
                double bodyRatio = bodySize / totalRange;
                
                // Bougies avec petit corps = consolidation = potentiel spike
                if(bodyRatio < 0.3)
                {
                    score += 3.0;
                }
                
                // Bougies avec longues ombres = rejet = potentiel spike
                double upperShadow = high - MathMax(open, close);
                double lowerShadow = MathMin(open, close) - low;
                
                if(upperShadow > bodySize * 2 || lowerShadow > bodySize * 2)
                {
                    score += 4.0;
                }
            }
        }
    }
    
    return MathMin(score, 20.0);
}









//+------------------------------------------------------------------+
//| Analyser le momentum                                            |
//+------------------------------------------------------------------+
double AnalyzeMomentum(const string symbol)
{
    double score = 0.0;
    
    // Calculer le momentum sur plusieurs périodes
    double price1 = iClose(symbol, PERIOD_CURRENT, 1);
    double price3 = iClose(symbol, PERIOD_CURRENT, 3);
    double price5 = iClose(symbol, PERIOD_CURRENT, 5);
    
    if(price1 > 0 && price3 > 0 && price5 > 0)
    {
        // Momentum accélérant
        double momentum1 = (price1 - price3) / price3;
        double momentum2 = (price3 - price5) / price5;
        
        if(MathAbs(momentum1) > MathAbs(momentum2) * 1.5)
        {
            score += 15.0; // Momentum accélérant
        }
        
        // Changement de direction
        if((momentum1 > 0 && momentum2 < 0) || (momentum1 < 0 && momentum2 > 0))
        {
            score += 10.0; // Changement de direction = potentiel spike
        }
    }
    
    return MathMin(score, 25.0);
}

//+------------------------------------------------------------------+
//| Analyser les niveaux de support/résistance                      |
//+------------------------------------------------------------------+
double AnalyzeSupportResistance(const string symbol)
{
    double score = 0.0;
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Analyser les niveaux récents
    double highestHigh = 0;
    double lowestLow = 999999;
    
    for(int i = 1; i <= 10; i++)
    {
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low = iLow(symbol, PERIOD_CURRENT, i);
        
        if(high > highestHigh) highestHigh = high;
        if(low < lowestLow) lowestLow = low;
    }
    
    // Vérifier si on est proche d'un niveau clé
    double distanceToHigh = MathAbs(currentPrice - highestHigh);
    double distanceToLow = MathAbs(currentPrice - lowestLow);
    
    if(distanceToHigh < 20 * point || distanceToLow < 20 * point)
    {
        score += 15.0; // Proche d'un niveau clé = potentiel rebond/spike
    }
    
    return MathMin(score, 20.0);
}





//+------------------------------------------------------------------+
//| Analyser les patterns temporels                                 |
//+------------------------------------------------------------------+
double AnalyzeTimePatterns()
{
    double score = 0.0;
    
    MqlDateTime timeStruct;
    TimeToStruct(TimeCurrent(), timeStruct);
    
    int hour = timeStruct.hour;
    int minute = timeStruct.min;
    
    // Périodes de forte activité (exemple: ouverture des marchés)
    if((hour >= 8 && hour <= 10) || (hour >= 14 && hour <= 16))
    {
        score += 10.0;
    }
    
    // Minutes rondes (tendance aux spikes)
    if(minute % 5 == 0)
    {
        score += 5.0;
    }
    
    return MathMin(score, 15.0);
}


//+------------------------------------------------------------------+
//| Masquer la flèche prédictive                                    |
//+------------------------------------------------------------------+
void HidePredictiveArrow(const string symbol)
{
    ObjectsDeleteAll(0, "Predictive_" + symbol + "_");
    ObjectsDeleteAll(0, "Predictive_Label_" + symbol);
    ObjectsDeleteAll(0, "StepPattern_" + symbol + "_");
    ObjectsDeleteAll(0, "StepPattern_Label_" + symbol);
    ChartRedraw(0);
    
    if(InpDebug) Print("🔄 Flèches prédictives masquées pour ", symbol);
}

//+------------------------------------------------------------------+
//| Analyser la compression des prix (accumulation avant spike)      |
//+------------------------------------------------------------------+
double AnalyzePriceCompression(const string symbol)
{
    double score = 0.0;
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Analyser les 3 dernières bougies pour détecter la compression
    double totalRange = 0;
    double avgRange = 0;
    int validBars = 0;
    
    for(int i = 1; i <= 3; i++)
    {
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low = iLow(symbol, PERIOD_CURRENT, i);
        
        if(high > 0 && low > 0)
        {
            totalRange += (high - low);
            validBars++;
        }
    }
    
    if(validBars > 0)
    {
        avgRange = totalRange / validBars;
        
        // Compression détectée si la plage moyenne est très petite
        if(avgRange < 10 * point) // Moins de 10 points de plage
        {
            score += 20.0; // Forte compression = potentiel spike
        }
        else if(avgRange < 20 * point)
        {
            score += 10.0; // Compression modérée
        }
    }
    
    return MathMin(score, 25.0);
}

//+------------------------------------------------------------------+
//| Analyser la pression du marché                                   |
//+------------------------------------------------------------------+
double AnalyzeMarketPressure(const string symbol)
{
    double score = 0.0;
    
    // Analyser les 3 dernières bougies pour la pression
    int bullishBars = 0;
    int bearishBars = 0;
    double totalBuyPressure = 0;
    double totalSellPressure = 0;
    
    for(int i = 1; i <= 3; i++)
    {
        double open = iOpen(symbol, PERIOD_CURRENT, i);
        double close = iClose(symbol, PERIOD_CURRENT, i);
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low = iLow(symbol, PERIOD_CURRENT, i);
        
        if(open > 0 && close > 0 && high > 0 && low > 0)
        {
            if(close > open) // Bougie haussière
            {
                bullishBars++;
                double bodySize = close - open;
                double totalRange = high - low;
                if(totalRange > 0)
                {
                    totalBuyPressure += bodySize / totalRange;
                }
            }
            else if(close < open) // Bougie baissière
            {
                bearishBars++;
                double bodySize = open - close;
                double totalRange = high - low;
                if(totalRange > 0)
                {
                    totalSellPressure += bodySize / totalRange;
                }
            }
        }
    }
    
    // Détecter une pression unidirectionnelle forte
    if(bullishBars >= 2 && totalBuyPressure > 0.6)
    {
        score += 15.0; // Forte pression d'achat
    }
    else if(bearishBars >= 2 && totalSellPressure > 0.6)
    {
        score += 15.0; // Forte pression de vente
    }
    
    // Détecter un équilibre qui peut se rompre
    if(bullishBars == bearishBars && MathAbs(totalBuyPressure - totalSellPressure) < 0.2)
    {
        score += 10.0; // Équilibre = potentiel de rupture
    }
    
    return MathMin(score, 20.0);
}

//+------------------------------------------------------------------+
//| Dessiner le setup des step patterns                             |
//+------------------------------------------------------------------+
void DrawStepPatternSetup(const string symbol, double probability)
{
    // Supprimer l'ancien setup de step pattern
    ObjectsDeleteAll(0, "StepPattern_" + symbol + "_");
    ObjectsDeleteAll(0, "StepPattern_Label_" + symbol);
    
    // Vérifier que le symbole est valide
    if(!SymbolSelect(symbol, true))
    {
        if(InpDebug) Print("❌ Symbole invalide pour step pattern: ", symbol);
        return;
    }
    
    // Créer le setup de step pattern
    string setupName = "StepPattern_" + symbol + "_" + IntegerToString(GetTickCount());
    datetime time = TimeCurrent();
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Validation des valeurs
    if(time <= 0 || currentPrice <= 0 || point <= 0)
    {
        if(InpDebug) Print("❌ Valeurs invalides pour step pattern - Time:", time, " Price:", currentPrice, " Point:", point);
        return;
    }
    
    // Positionner le setup au-dessus du prix actuel
    double setupPrice = currentPrice + 80 * point;
    
    // Créer l'objet rectangle pour le step pattern
    if(ObjectCreate(0, setupName, OBJ_RECTANGLE, 0, time - 300, setupPrice - 20 * point, time + 300, setupPrice + 20 * point))
    {
        // Configurer le rectangle
        ObjectSetInteger(0, setupName, OBJPROP_COLOR, clrOrange);
        ObjectSetInteger(0, setupName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, setupName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, setupName, OBJPROP_BACK, true);
        ObjectSetInteger(0, setupName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        ObjectSetInteger(0, setupName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, setupName, OBJPROP_HIDDEN, false);
        
        // Ajouter un label avec la probabilité
        string labelName = "StepPattern_Label_" + symbol + "_" + IntegerToString(GetTickCount());
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, time, setupPrice))
        {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "STEP PATTERN " + DoubleToString(probability, 0) + "%");
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrOrange);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
            ObjectSetInteger(0, labelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
        }
        
        // Forcer la mise à jour du graphique
        ChartRedraw(0);
        Sleep(10); // Petite pause pour s'assurer que l'objet est créé
        
        if(InpDebug)
        {
            Print("📊 Step pattern affiché: ", symbol, " - Probabilité: ", DoubleToString(probability, 1), "%");
        }
    }
    else
    {
        if(InpDebug) Print("❌ Erreur création step pattern ", setupName, ": ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Masquer le setup des step patterns                              |
//+------------------------------------------------------------------+
void HideStepPatternSetup(const string symbol)
{
    ObjectsDeleteAll(0, "StepPattern_" + symbol + "_");
    ObjectsDeleteAll(0, "StepPattern_Label_" + symbol);
    ChartRedraw(0);
    
    if(InpDebug) Print("🔄 Step patterns masqués pour ", symbol);
}

//+------------------------------------------------------------------+
//| Analyser les step patterns spécifiques                          |
//+------------------------------------------------------------------+
double AnalyzeStepPatterns(const string symbol)
{
    double score = 0.0;
    
    // Analyser les 5 dernières bougies pour détecter les step patterns
    double prices[5];
    bool validData = true;
    
    // Récupérer les prix de clôture
    for(int i = 1; i <= 5; i++)
    {
        prices[i-1] = iClose(symbol, PERIOD_CURRENT, i);
        if(prices[i-1] <= 0)
        {
            validData = false;
            break;
        }
    }
    
    if(!validData) return 0.0;
    
    // Détecter les patterns en escalier
    int stepCount = 0;
    double stepSize = 0;
    
    for(int i = 1; i < 5; i++)
    {
        double diff = prices[i-1] - prices[i];
        if(MathAbs(diff) > 0)
        {
            if(stepSize == 0) stepSize = MathAbs(diff);
            
            // Vérifier si c'est un step (mouvement régulier)
            if(MathAbs(MathAbs(diff) - stepSize) < stepSize * 0.3) // Tolérance de 30%
            {
                stepCount++;
            }
        }
    }
    
    // Score basé sur le nombre de steps détectés
    if(stepCount >= 3)
    {
        score = 40.0; // Fort step pattern
    }
    else if(stepCount >= 2)
    {
        score = 25.0; // Step pattern modéré
    }
    else if(stepCount >= 1)
    {
        score = 15.0; // Step pattern faible
    }
    
    return MathMin(score, 50.0);
}


//+------------------------------------------------------------------+
//| Dessiner les zones de support et résistance                     |
//+------------------------------------------------------------------+
void DrawSupportResistanceZones(const string symbol)
{
    double highs[], lows[];
    ArrayResize(highs, InpZoneLookbackPeriods);
    ArrayResize(lows, InpZoneLookbackPeriods);
    
    // Récupérer les hauts et bas
    for(int i = 1; i <= InpZoneLookbackPeriods; i++)
    {
        highs[i-1] = iHigh(symbol, PERIOD_CURRENT, i);
        lows[i-1] = iLow(symbol, PERIOD_CURRENT, i);
    }
    
    // Trouver les niveaux de support et résistance
    double supportLevels[], resistanceLevels[];
    FindSupportResistanceLevels(highs, lows, supportLevels, resistanceLevels);
    
    // Dessiner les zones de support
    for(int i = 0; i < ArraySize(supportLevels); i++)
    {
        DrawZone(symbol, "Support_" + symbol + "_" + IntegerToString(i), 
                supportLevels[i], clrGreen, "SUPPORT");
    }
    
    // Dessiner les zones de résistance
    for(int i = 0; i < ArraySize(resistanceLevels); i++)
    {
        DrawZone(symbol, "Resistance_" + symbol + "_" + IntegerToString(i), 
                resistanceLevels[i], clrRed, "RESISTANCE");
    }
}

//+------------------------------------------------------------------+
//| Dessiner les zones ICT (Inner Circle Trader)                    |
//+------------------------------------------------------------------+
void DrawICTZones(const string symbol)
{
    // Zones ICT : Fair Value Gaps, Liquidity Pools, etc.
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Analyser les gaps de prix récents
    for(int i = 1; i <= 5; i++)
    {
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low = iLow(symbol, PERIOD_CURRENT, i);
        double open = iOpen(symbol, PERIOD_CURRENT, i);
        double close = iClose(symbol, PERIOD_CURRENT, i);
        
        if(high > 0 && low > 0 && open > 0 && close > 0)
        {
            // Détecter les Fair Value Gaps
            if(close > open && (high - low) > 10 * point) // Bougie haussière avec gap
            {
                double gapStart = MathMin(open, close);
                double gapEnd = MathMax(open, close);
                
                if(gapEnd - gapStart > 5 * point) // Gap significatif
                {
                    DrawZone(symbol, "ICT_FVG_" + symbol + "_" + IntegerToString(i), 
                            (gapStart + gapEnd) / 2, clrBlue, "ICT FVG");
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Dessiner les niveaux de Fibonacci                               |
//+------------------------------------------------------------------+
void DrawFibonacciLevels(const string symbol)
{
    // Trouver le swing high et swing low récents
    double swingHigh = 0, swingLow = 999999;
    datetime swingHighTime = 0, swingLowTime = 0;
    
    for(int i = 1; i <= InpZoneLookbackPeriods; i++)
    {
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low = iLow(symbol, PERIOD_CURRENT, i);
        datetime time = iTime(symbol, PERIOD_CURRENT, i);
        
        if(high > swingHigh)
        {
            swingHigh = high;
            swingHighTime = time;
        }
        if(low < swingLow)
        {
            swingLow = low;
            swingLowTime = time;
        }
    }
    
    if(swingHigh > 0 && swingLow < 999999)
    {
        double range = swingHigh - swingLow;
        
        // Niveaux de Fibonacci
        double fibLevels[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0};
        color fibColors[] = {clrNavy, clrBlue, clrAqua, clrYellow, clrOrange, clrRed, clrMaroon};
        
        for(int i = 0; i < ArraySize(fibLevels); i++)
        {
            double fibPrice = swingLow + (range * fibLevels[i]);
            DrawZone(symbol, "Fib_" + symbol + "_" + DoubleToString(fibLevels[i], 3), 
                    fibPrice, fibColors[i], "FIB " + DoubleToString(fibLevels[i] * 100, 1) + "%");
        }
    }
}

//+------------------------------------------------------------------+
//| Dessiner les Order Blocks                                       |
//+------------------------------------------------------------------+
void DrawOrderBlocks(const string symbol)
{
    // Analyser les bougies pour détecter les Order Blocks
    for(int i = 1; i <= 10; i++)
    {
        double open = iOpen(symbol, PERIOD_CURRENT, i);
        double close = iClose(symbol, PERIOD_CURRENT, i);
        double high = iHigh(symbol, PERIOD_CURRENT, i);
        double low = iLow(symbol, PERIOD_CURRENT, i);
        datetime time = iTime(symbol, PERIOD_CURRENT, i);
        
        if(open > 0 && close > 0 && high > 0 && low > 0)
        {
            // Détecter les Order Blocks (bougies avec petit corps et longues ombres)
            double bodySize = MathAbs(close - open);
            double totalRange = high - low;
            
            if(totalRange > 0)
            {
                double bodyRatio = bodySize / totalRange;
                
                // Order Block : petit corps (ratio < 0.3) et range significatif
                if(bodyRatio < 0.3 && totalRange > 5 * SymbolInfoDouble(symbol, SYMBOL_POINT))
                {
                    color blockColor = (close > open) ? clrLime : clrMagenta;
                    string blockType = (close > open) ? "OB BUY" : "OB SELL";
                    
                    DrawOrderBlock(symbol, "OrderBlock_" + symbol + "_" + IntegerToString(i), 
                                 time, low, high, blockColor, blockType);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Dessiner une zone générique                                     |
//+------------------------------------------------------------------+
void DrawZone(const string symbol, const string zoneName, double price, color zoneColor, const string label)
{
    datetime currentTime = TimeCurrent();
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Créer un rectangle pour la zone
    if(ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, currentTime - 3600, price - 5 * point, currentTime + 3600, price + 5 * point))
    {
        ObjectSetInteger(0, zoneName, OBJPROP_COLOR, zoneColor);
        ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
        ObjectSetInteger(0, zoneName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, zoneName, OBJPROP_HIDDEN, false);
        
        // Ajouter un label
        string labelName = zoneName + "_Label";
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, price + 10 * point))
        {
            ObjectSetString(0, labelName, OBJPROP_TEXT, label);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, zoneColor);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
        }
    }
}

//+------------------------------------------------------------------+
//| Dessiner un Order Block spécifique                              |
//+------------------------------------------------------------------+
void DrawOrderBlock(const string symbol, const string blockName, datetime time, double low, double high, color blockColor, const string label)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Créer un rectangle pour l'Order Block
    if(ObjectCreate(0, blockName, OBJ_RECTANGLE, 0, time, low, time + 1800, high))
    {
        ObjectSetInteger(0, blockName, OBJPROP_COLOR, blockColor);
        ObjectSetInteger(0, blockName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, blockName, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, blockName, OBJPROP_BACK, true);
        ObjectSetInteger(0, blockName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        ObjectSetInteger(0, blockName, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, blockName, OBJPROP_HIDDEN, false);
        
        // Ajouter un label
        string labelName = blockName + "_Label";
        if(ObjectCreate(0, labelName, OBJ_TEXT, 0, time, (low + high) / 2))
        {
            ObjectSetString(0, labelName, OBJPROP_TEXT, label);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, blockColor);
            ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
            ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
        }
    }
}

//+------------------------------------------------------------------+
//| Trouver les niveaux de support et résistance                    |
//+------------------------------------------------------------------+
void FindSupportResistanceLevels(const double &highs[], const double &lows[], double &supportLevels[], double &resistanceLevels[])
{
    int supportCount = 0, resistanceCount = 0;
    ArrayResize(supportLevels, 0);
    ArrayResize(resistanceLevels, 0);
    
    // Trouver les pivots
    for(int i = 2; i < ArraySize(highs) - 2; i++)
    {
        // Pivot haut (résistance)
        if(highs[i] > highs[i-1] && highs[i] > highs[i-2] && 
           highs[i] > highs[i+1] && highs[i] > highs[i+2])
        {
            ArrayResize(resistanceLevels, resistanceCount + 1);
            resistanceLevels[resistanceCount] = highs[i];
            resistanceCount++;
        }
        
        // Pivot bas (support)
        if(lows[i] < lows[i-1] && lows[i] < lows[i-2] && 
           lows[i] < lows[i+1] && lows[i] < lows[i+2])
        {
            ArrayResize(supportLevels, supportCount + 1);
            supportLevels[supportCount] = lows[i];
            supportCount++;
        }
    }
}

//+------------------------------------------------------------------+
//| Détecter et fermer après spike                                  |
//+------------------------------------------------------------------+
void DetectAndCloseAfterSpike(const string symbol)
{
    // Vérifier s'il y a des positions ouvertes pour ce symbole
    bool hasPositions = false;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && 
               PositionGetString(POSITION_SYMBOL) == symbol)
            {
                hasPositions = true;
                break;
            }
        }
    }
    
    if(!hasPositions) return;
    
    // Calculer la volatilité actuelle
    double currentVolatility = CalculateVolatility(symbol, InpSpikeDetectionPeriods);
    
    // Initialiser la volatilité de base si c'est la première fois
    if(g_spikeBaseVolatility == 0.0)
    {
        g_spikeBaseVolatility = currentVolatility;
        g_spikeDetectionTime = TimeCurrent();
        if(InpDebug) Print("📊 Volatilité de base initialisée: ", DoubleToString(g_spikeBaseVolatility, 4));
    }
    
    // Afficher les informations de debug
    PrintSpikeDebugInfo(symbol);
    
    // Détecter un spike (volatilité > seuil)
    if(currentVolatility >= g_spikeBaseVolatility * InpSpikeVolatilityThreshold)
    {
        if(!g_spikeDetected)
        {
            g_spikeDetected = true;
            g_spikeSymbol = symbol;
            g_spikePeakTime = TimeCurrent();
            
            Print("🚨 SPIKE DÉTECTÉ! ", symbol, " - Volatilité: ", DoubleToString(currentVolatility, 4), 
                  " (seuil: ", DoubleToString(g_spikeBaseVolatility * InpSpikeVolatilityThreshold, 4), ")");
            
            // Fermer immédiatement après spike détecté
            CloseAllPositionsForSymbol(symbol, "SPIKE DÉTECTÉ");
        }
    }
    else
    {
        // Spike terminé, vérifier si on doit fermer avec délai
        if(g_spikeDetected && g_spikeSymbol == symbol)
        {
            datetime currentTime = TimeCurrent();
            double timeSinceSpike = (double)(currentTime - g_spikePeakTime);
            
            if(timeSinceSpike >= InpSpikeCloseDelaySeconds)
            {
                CloseAllPositionsForSymbol(symbol, "SPIKE TERMINÉ");
                ResetSpikeDetection();
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Fermer toutes les positions pour un symbole                     |
//+------------------------------------------------------------------+
void CloseAllPositionsForSymbol(const string symbol, const string reason)
{
    int closedCount = 0;
    double totalProfit = 0.0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber && 
               PositionGetString(POSITION_SYMBOL) == symbol)
            {
                ulong ticket = PositionGetTicket(i);
                double profit = PositionGetDouble(POSITION_PROFIT);
                totalProfit += profit;
                
                // Vérifier le profit minimum si configuré
                if(profit >= InpSpikeProfitTarget)
                {
                    if(g_trade.PositionClose(ticket))
                    {
                        closedCount++;
                        Print("✅ Position fermée après spike: ", ticket, " - Profit: $", DoubleToString(profit, 2), " - Raison: ", reason);
                    }
                    else
                    {
                        Print("❌ Erreur fermeture position: ", ticket, " - Erreur: ", GetLastError());
                    }
                }
                else
                {
                    if(InpDebug) Print("📊 Profit insuffisant pour fermeture: $", DoubleToString(profit, 2), " < $", InpSpikeProfitTarget);
                }
            }
        }
    }
    
    if(closedCount > 0)
    {
        Print("🎯 FERMETURE SPIKE TERMINÉE: ", closedCount, " position(s) fermée(s) - Profit total: $", DoubleToString(totalProfit, 2));
        
        // Envoyer notification
        if(InpSendNotifications)
        {
            SendNotification("SPIKE FERMÉ: " + symbol + " - " + IntegerToString(closedCount) + " position(s) - $" + DoubleToString(totalProfit, 2));
        }
        
        // Mettre à jour le compteur de trades
        UpdateActiveTradesCount();
        
        // Réinitialiser les variables
        g_currentSymbol = "";
        g_currentDirection = 0;
        g_limitOrderCount = 0;
        
        // Annuler tous les ordres limit restants
        CancelAllLimitOrders(symbol);
    }
}

//+------------------------------------------------------------------+
//| Réinitialiser la détection de spike                             |
//+------------------------------------------------------------------+
void ResetSpikeDetection()
{
    g_spikeDetected = false;
    g_spikeSymbol = "";
    g_spikePeakTime = 0;
    g_spikeBaseVolatility = 0.0;
    g_spikeDetectionTime = 0;
    
    if(InpDebug) Print("🔄 Détection de spike réinitialisée");
}

//+------------------------------------------------------------------+
//| Vérification d'urgence de la perte                              |
//+------------------------------------------------------------------+
void EmergencyLossCheck()
{
    // Vérification d'urgence pour s'assurer que la perte ne dépasse jamais le seuil
    double emergencyLoss = 0.0;
    int emergencyPositions = 0;
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                double profit = PositionGetDouble(POSITION_PROFIT);
                if(profit < 0)
                {
                    emergencyLoss += MathAbs(profit);
                    emergencyPositions++;
                }
            }
        }
    }
    
    // Si la perte dépasse le seuil, fermer immédiatement
    if(emergencyLoss >= InpMaxTotalLoss)
    {
        Print("🚨 VÉRIFICATION D'URGENCE: Perte détectée $", DoubleToString(emergencyLoss, 2), " >= $", InpMaxTotalLoss, " - FERMETURE D'URGENCE!");
        
        // Fermer toutes les positions immédiatement
        for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            if(PositionGetTicket(i) > 0)
            {
                if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
                {
                    ulong ticket = PositionGetTicket(i);
                    string symbol = PositionGetString(POSITION_SYMBOL);
                    
                    // Fermeture d'urgence sans délai
                    if(g_trade.PositionClose(ticket))
                    {
                        Print("🚨 FERMETURE D'URGENCE RÉUSSIE: ", symbol, " - Ticket: ", ticket);
                    }
                    else
                    {
                        Print("🚨 ÉCHEC FERMETURE D'URGENCE: ", ticket, " - Erreur: ", GetLastError());
                    }
                }
            }
        }
        
        // Envoyer notification d'urgence
        if(InpSendNotifications)
        {
            SendNotification("URGENCE: Perte dépassée - Toutes positions fermées - $" + DoubleToString(emergencyLoss, 2));
        }
    }
    else if(InpDebug && emergencyPositions > 0)
    {
        Print("⚠️ VÉRIFICATION D'URGENCE: Perte actuelle $", DoubleToString(emergencyLoss, 2), " (", emergencyPositions, " position(s)) - Seuil: $", InpMaxTotalLoss);
    }
}

//+------------------------------------------------------------------+
//| Calculer la perte globale totale                               |
//+------------------------------------------------------------------+
double CalculateTotalGlobalLoss()
{
    double totalLoss = 0.0;
    int positionCount = 0;
    
    for(int i = (int)PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                double profit = PositionGetDouble(POSITION_PROFIT);
                string symbol = PositionGetString(POSITION_SYMBOL);
                ulong ticket = PositionGetTicket(i);
                
                if(profit < 0) // Seulement les pertes
                {
                    totalLoss += MathAbs(profit);
                    positionCount++;
                    
                    if(InpDebug)
                    {
                        Print("📊 PERTE DÉTECTÉE: ", symbol, " - Ticket: ", ticket, " - Perte: $", DoubleToString(MathAbs(profit), 2));
                    }
                }
            }
        }
    }
    
    if(InpDebug && positionCount > 0)
    {
        Print("💰 PERTE GLOBALE CALCULÉE: $", DoubleToString(totalLoss, 2), " (", positionCount, " position(s) en perte)");
    }
    
    return totalLoss;
}

//+------------------------------------------------------------------+
//| Fermer toutes les positions pour limite de perte                |
//+------------------------------------------------------------------+
void CloseAllPositionsForLossLimit(const string reason)
{
    int closedCount = 0;
    double totalLoss = 0.0;
    int totalPositions = PositionsTotal();
    int errorCount = 0;
    
    Print("\n🚨🚨🚨 LANCEMENT FERMETURE D'URGENCE 🚨🚨🚨");
    Print("📌 Raison: ", reason);
    Print("📊 Nombre total de positions: ", totalPositions);
    
    // Première passe: compter les positions à fermer
    int positionsToClose = 0;
    for(int i = 0; i < totalPositions; i++)
    {
        if(PositionGetTicket(i) > 0 && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            positionsToClose++;
        }
    }
    
    Print("🔍 ", positionsToClose, " position(s) à fermer");
    
    // Seconde passe: fermer les positions
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!PositionSelectByTicket(PositionGetTicket(i))) continue;
        
        if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
            ulong ticket = PositionGetTicket(i);
            string symbol = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            Print("\n🔧 Traitement position #", i, ":");
            Print("   Symbole: ", symbol);
            Print("   Ticket: ", ticket);
            Print("   Type: ", (posType == POSITION_TYPE_BUY) ? "Achat" : "Vente");
            Print("   Volume: ", DoubleToString(volume, 2));
            Print("   Profit: $", DoubleToString(profit, 2));
            
            totalLoss += MathAbs(profit);
            
            // Essayer de fermer la position
            bool closed = false;
            for(int attempt = 1; attempt <= 5; attempt++) // Jusqu'à 5 tentatives
            {
                Print("   Tentative ", attempt, "/5 de fermeture...");
                
                // Sélectionner la position
                if(PositionSelectByTicket(ticket))
                {
                    // Fermer la position
                    if(g_trade.PositionClose(ticket))
                    {
                        closed = true;
                        closedCount++;
                        Print("   ✅ FERMETURE RÉUSSIE après ", attempt, " tentative(s)");
                        Print("   📊 Détails: ", symbol, " - Volume: ", DoubleToString(volume, 2), " - Profit: $", DoubleToString(profit, 2));
                        break;
                    }
                    else
                    {
                        int errorCode = GetLastError();
                        errorCount++;
                        string errorDesc = "";
                        switch(errorCode)
                        {
                            case 1: errorDesc = "No error"; break;
                            case 130: errorDesc = "Invalid stops"; break;
                            case 131: errorDesc = "Invalid trade volume"; break;
                            case 132: errorDesc = "Market is closed"; break;
                            case 133: errorDesc = "Trade is disabled"; break;
                            case 134: errorDesc = "Not enough money"; break;
                            case 135: errorDesc = "Price changed"; break;
                            case 136: errorDesc = "Off quotes"; break;
                            case 137: errorDesc = "Broker is busy"; break;
                            case 138: errorDesc = "Requote"; break;
                            case 139: errorDesc = "Order is locked"; break;
                            case 140: errorDesc = "Long positions only allowed"; break;
                            case 141: errorDesc = "Too many requests"; break;
                            case 145: errorDesc = "Modification denied because order is too close to market"; break;
                            case 146: errorDesc = "Trading context is busy"; break;
                            case 147: errorDesc = "Expirations are denied by broker"; break;
                            case 148: errorDesc = "The amount of open and pending orders has reached the limit"; break;
                            case 149: errorDesc = "An attempt to modify a position or order when hedging is disabled"; break;
                            case 150: errorDesc = "An attempt to close a position contravening the FIFO rule"; break;
                            default: errorDesc = "Unknown error";
                        }
                        Print("   ❌ Échec tentative ", attempt, ": Erreur ", errorCode, " - ", errorDesc);
                        
                        // Attendre un peu avant de réessayer
                        Sleep(200 * attempt); // Attente croissante
                    }
                }
                else
                {
                    Print("   ⚠️ Impossible de sélectionner la position ", ticket, " - Erreur: ", GetLastError());
                    break; // Sortir de la boucle si la position n'existe plus
                }
            }
            
            if(!closed)
            {
                int lastError = GetLastError();
                string lastErrorDesc = "";
                switch(lastError)
                {
                    case 1: lastErrorDesc = "No error"; break;
                    case 130: lastErrorDesc = "Invalid stops"; break;
                    case 131: lastErrorDesc = "Invalid trade volume"; break;
                    case 132: lastErrorDesc = "Market is closed"; break;
                    case 133: lastErrorDesc = "Trade is disabled"; break;
                    case 134: lastErrorDesc = "Not enough money"; break;
                    case 135: lastErrorDesc = "Price changed"; break;
                    case 136: lastErrorDesc = "Off quotes"; break;
                    case 137: lastErrorDesc = "Broker is busy"; break;
                    case 138: lastErrorDesc = "Requote"; break;
                    case 139: lastErrorDesc = "Order is locked"; break;
                    case 140: lastErrorDesc = "Long positions only allowed"; break;
                    case 141: lastErrorDesc = "Too many requests"; break;
                    case 145: lastErrorDesc = "Modification denied because order is too close to market"; break;
                    case 146: lastErrorDesc = "Trading context is busy"; break;
                    case 147: lastErrorDesc = "Expirations are denied by broker"; break;
                    case 148: lastErrorDesc = "The amount of open and pending orders has reached the limit"; break;
                    case 149: lastErrorDesc = "An attempt to modify a position or order when hedging is disabled"; break;
                    case 150: lastErrorDesc = "An attempt to close a position contravening the FIFO rule"; break;
                    default: lastErrorDesc = "Unknown error";
                }
                Print("   🚨 ÉCHEC CRITIQUE: Impossible de fermer la position ", ticket, " après 5 tentatives");
                Print("   ℹ️  Dernière erreur: ", lastError, " - ", lastErrorDesc);
            }
        }
    }
    
    if(closedCount > 0)
    {
        Print("🚨 FERMETURE FORCÉE TERMINÉE: ", closedCount, " position(s) fermée(s) - Perte totale: $", DoubleToString(totalLoss, 2));
        
        // Envoyer notification
        if(InpSendNotifications)
        {
            SendNotification("PERTE MAX: " + IntegerToString(closedCount) + " position(s) fermée(s) - $" + DoubleToString(totalLoss, 2));
        }
        
        // Mettre à jour le compteur de trades
        UpdateActiveTradesCount();
        
        // Réinitialiser toutes les variables
        g_currentSymbol = "";
        g_currentDirection = 0;
        g_limitOrderCount = 0;
        g_arrowSignalActive = false;
        g_arrowSignalSymbol = "";
        g_spikeDetected = false;
        g_spikeSymbol = "";
        
        // Annuler tous les ordres limit
        for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
            if(OrderGetTicket(i))
            {
                if(OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
                {
                    g_trade.OrderDelete(OrderGetInteger(ORDER_TICKET));
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Afficher les informations de debug sur les spikes               |
//+------------------------------------------------------------------+
void PrintSpikeDebugInfo(const string symbol)
{
    if(!InpDebug) return;
    
    double currentVolatility = CalculateVolatility(symbol, InpSpikeDetectionPeriods);
    double spikeThreshold = g_spikeBaseVolatility * InpSpikeVolatilityThreshold;
    
    Print("📊 SPIKE DEBUG - ", symbol, 
          " - Volatilité actuelle: ", DoubleToString(currentVolatility, 4),
          " - Seuil spike: ", DoubleToString(spikeThreshold, 4),
          " - Spike détecté: ", (g_spikeDetected ? "OUI" : "NON"),
          " - Symbole spike: ", g_spikeSymbol);
}

//+------------------------------------------------------------------+
//| Détecter les niveaux de support et résistance (Multi-Timeframe)|
//+------------------------------------------------------------------+
void DetectSupportResistanceLevels(const string symbol, double &supportLevels[], double &resistanceLevels[])
{
    if(!SymbolSelect(symbol, true)) return;
    
    ArrayResize(supportLevels, 0);
    ArrayResize(resistanceLevels, 0);
    
    // Définir les timeframes à analyser
    ENUM_TIMEFRAMES timeframes[];
    ArrayResize(timeframes, 8);
    
    int tfIndex = 0;
    if(InpUseDailyLevels) timeframes[tfIndex++] = PERIOD_D1;
    if(InpUseH8Levels) timeframes[tfIndex++] = PERIOD_H8;
    if(InpUseH6Levels) timeframes[tfIndex++] = PERIOD_H6;
    if(InpUseH4Levels) timeframes[tfIndex++] = PERIOD_H4;
    if(InpUseH1Levels) timeframes[tfIndex++] = PERIOD_H1;
    if(InpUseM30Levels) timeframes[tfIndex++] = PERIOD_M30;
    if(InpUseM15Levels) timeframes[tfIndex++] = PERIOD_M15;
    if(InpUseM5Levels) timeframes[tfIndex++] = PERIOD_M5;
    
    ArrayResize(timeframes, tfIndex);
    
    // Analyser chaque timeframe
    for(int tf = 0; tf < tfIndex; tf++)
    {
        ENUM_TIMEFRAMES timeframe = timeframes[tf];
        double tfSupportLevels[];
        double tfResistanceLevels[];
        
        // Détecter les niveaux pour ce timeframe
        DetectLevelsForTimeframe(symbol, timeframe, tfSupportLevels, tfResistanceLevels);
        
        // Fusionner avec les niveaux existants
        MergeLevels(supportLevels, tfSupportLevels, true);
        MergeLevels(resistanceLevels, tfResistanceLevels, false);
    }
    
    // Limiter le nombre de niveaux
    if(ArraySize(supportLevels) > InpMaxLevelsPerTimeframe * tfIndex)
    {
        ArrayResize(supportLevels, InpMaxLevelsPerTimeframe * tfIndex);
    }
    if(ArraySize(resistanceLevels) > InpMaxLevelsPerTimeframe * tfIndex)
    {
        ArrayResize(resistanceLevels, InpMaxLevelsPerTimeframe * tfIndex);
    }
    
    if(InpDebug)
    {
        Print("🔍 DÉTECTION MULTI-TIMEFRAME [", symbol, "]: ", ArraySize(supportLevels), " supports, ", 
              ArraySize(resistanceLevels), " résistances détectés");
    }
}

//+------------------------------------------------------------------+
//| Détecter les niveaux pour un timeframe spécifique              |
//+------------------------------------------------------------------+
void DetectLevelsForTimeframe(const string symbol, ENUM_TIMEFRAMES timeframe, double &supportLevels[], double &resistanceLevels[])
{
    ArrayResize(supportLevels, 0);
    ArrayResize(resistanceLevels, 0);
    
    // Nombre de barres à analyser selon le timeframe
    int lookbackBars = GetLookbackBars(timeframe);
    
    // Détecter les swing highs et lows
    for(int i = 5; i < lookbackBars; i++)
    {
        double high1 = iHigh(symbol, timeframe, i);
        double high2 = iHigh(symbol, timeframe, i-1);
        double high3 = iHigh(symbol, timeframe, i+1);
        
        double low1 = iLow(symbol, timeframe, i);
        double low2 = iLow(symbol, timeframe, i-1);
        double low3 = iLow(symbol, timeframe, i+1);
        
        // Swing High (Résistance)
        if(high1 > high2 && high1 > high3)
        {
            double resistance = high1;
            if(ArraySize(resistanceLevels) == 0 || MathAbs(resistance - resistanceLevels[ArraySize(resistanceLevels)-1]) > 0.001)
            {
                ArrayResize(resistanceLevels, ArraySize(resistanceLevels) + 1);
                resistanceLevels[ArraySize(resistanceLevels)-1] = resistance;
            }
        }
        
        // Swing Low (Support)
        if(low1 < low2 && low1 < low3)
        {
            double support = low1;
            if(ArraySize(supportLevels) == 0 || MathAbs(support - supportLevels[ArraySize(supportLevels)-1]) > 0.001)
            {
                ArrayResize(supportLevels, ArraySize(supportLevels) + 1);
                supportLevels[ArraySize(supportLevels)-1] = support;
            }
        }
    }
    
    // Limiter le nombre de niveaux par timeframe
    if(ArraySize(supportLevels) > InpMaxLevelsPerTimeframe)
    {
        ArrayResize(supportLevels, InpMaxLevelsPerTimeframe);
    }
    if(ArraySize(resistanceLevels) > InpMaxLevelsPerTimeframe)
    {
        ArrayResize(resistanceLevels, InpMaxLevelsPerTimeframe);
    }
}

//+------------------------------------------------------------------+
//| Obtenir le nombre de barres à analyser selon le timeframe      |
//+------------------------------------------------------------------+
int GetLookbackBars(ENUM_TIMEFRAMES timeframe)
{
    switch(timeframe)
    {
        case PERIOD_D1:  return 50;   // 50 jours
        case PERIOD_H8:  return 100;  // 100 barres H8
        case PERIOD_H6:  return 120;  // 120 barres H6
        case PERIOD_H4:  return 150;  // 150 barres H4
        case PERIOD_H1:  return 200;  // 200 barres H1
        case PERIOD_M30: return 300;  // 300 barres M30
        case PERIOD_M15: return 400;  // 400 barres M15
        case PERIOD_M5:  return 500;  // 500 barres M5
        default: return 100;
    }
}

//+------------------------------------------------------------------+
//| Fusionner les niveaux de différents timeframes                 |
//+------------------------------------------------------------------+
void MergeLevels(double &mainLevels[], double &newLevels[], bool isSupport)
{
    for(int i = 0; i < ArraySize(newLevels); i++)
    {
        double newLevel = newLevels[i];
        bool found = false;
        
        // Vérifier si le niveau existe déjà
        for(int j = 0; j < ArraySize(mainLevels); j++)
        {
            if(MathAbs(mainLevels[j] - newLevel) < 0.001)
            {
                found = true;
                break;
            }
        }
        
        // Ajouter le niveau s'il n'existe pas
        if(!found)
        {
            ArrayResize(mainLevels, ArraySize(mainLevels) + 1);
            mainLevels[ArraySize(mainLevels)-1] = newLevel;
        }
    }
}

//+------------------------------------------------------------------+
//| Calculer la proximité du prix par rapport aux niveaux           |
//+------------------------------------------------------------------+
double CalculateProximityToLevels(const string symbol, double currentPrice, double &levels[], int levelCount)
{
    if(levelCount == 0) return 0.0;
    
    double minDistance = DBL_MAX;
    
    for(int i = 0; i < levelCount; i++)
    {
        double distance = MathAbs(currentPrice - levels[i]) / currentPrice;
        if(distance < minDistance)
        {
            minDistance = distance;
        }
    }
    
    return minDistance;
}

//+------------------------------------------------------------------+
//| Analyser la proximité des supports/résistances                  |
//+------------------------------------------------------------------+
bool AnalyzeProximityTrading(const string symbol, int &direction, double &confidence)
{
    if(!InpEnableProximityTrading) return false;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(currentPrice <= 0) return false;
    
    // Détecter les niveaux
    double supportLevels[];
    double resistanceLevels[];
    DetectSupportResistanceLevels(symbol, supportLevels, resistanceLevels);
    
    // Calculer la proximité
    double supportProximity = CalculateProximityToLevels(symbol, currentPrice, supportLevels, ArraySize(supportLevels));
    double resistanceProximity = CalculateProximityToLevels(symbol, currentPrice, resistanceLevels, ArraySize(resistanceLevels));
    
    // Vérifier la proximité du support
    if(supportProximity <= InpProximityThreshold && ArraySize(supportLevels) > 0)
    {
        // Calculer la force du support
        double supportStrength = CalculateLevelStrength(symbol, supportLevels, ArraySize(supportLevels));
        
        if(supportStrength >= InpMinSupportStrength)
        {
            direction = POSITION_TYPE_BUY;
            confidence = MathMin(supportStrength * 100.0, 95.0);
            
            if(InpDebug)
            {
                Print("🎯 PROXIMITÉ SUPPORT [", symbol, "]: Prix ", DoubleToString(currentPrice, 5), 
                      " | Support ", DoubleToString(supportLevels[0], 5), 
                      " | Proximité ", DoubleToString(supportProximity * 100, 2), "%",
                      " | Force ", DoubleToString(supportStrength, 2),
                      " | Confiance ", DoubleToString(confidence, 1), "%");
            }
            
            return true;
        }
    }
    
    // Vérifier la proximité de la résistance
    if(resistanceProximity <= InpProximityThreshold && ArraySize(resistanceLevels) > 0)
    {
        // Calculer la force de la résistance
        double resistanceStrength = CalculateLevelStrength(symbol, resistanceLevels, ArraySize(resistanceLevels));
        
        if(resistanceStrength >= InpMinResistanceStrength)
        {
            direction = POSITION_TYPE_SELL;
            confidence = MathMin(resistanceStrength * 100.0, 95.0);
            
            if(InpDebug)
            {
                Print("🎯 PROXIMITÉ RÉSISTANCE [", symbol, "]: Prix ", DoubleToString(currentPrice, 5), 
                      " | Résistance ", DoubleToString(resistanceLevels[0], 5), 
                      " | Proximité ", DoubleToString(resistanceProximity * 100, 2), "%",
                      " | Force ", DoubleToString(resistanceStrength, 2),
                      " | Confiance ", DoubleToString(confidence, 1), "%");
            }
            
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Calculer la force d'un niveau                                   |
//+------------------------------------------------------------------+
double CalculateLevelStrength(const string symbol, double &levels[], int levelCount)
{
    if(levelCount == 0) return 0.0;
    
    double totalStrength = 0.0;
    int validLevels = 0;
    
    for(int i = 0; i < levelCount; i++)
    {
        // Compter le nombre de touches du niveau
        int touchCount = 0;
        for(int j = 1; j < 50; j++)
        {
            double high = iHigh(symbol, PERIOD_CURRENT, j);
            double low = iLow(symbol, PERIOD_CURRENT, j);
            
            if(MathAbs(high - levels[i]) < 0.001 || MathAbs(low - levels[i]) < 0.001)
            {
                touchCount++;
            }
        }
        
        // La force est basée sur le nombre de touches
        double levelStrength = MathMin(touchCount / 10.0, 1.0);
        totalStrength += levelStrength;
        validLevels++;
    }
    
    return validLevels > 0 ? totalStrength / validLevels : 0.0;
}

//+------------------------------------------------------------------+
//| Dessiner les zones de proximité (Multi-Timeframe)              |
//+------------------------------------------------------------------+
void DrawProximityZones(const string symbol)
{
    if(!InpShowProximityZones) return;
    if(!SymbolSelect(symbol, true)) return;
    
    // Supprimer les anciennes zones
    ObjectsDeleteAll(0, "Proximity_" + symbol + "_");
    
    // Définir les timeframes à analyser
    ENUM_TIMEFRAMES timeframes[];
    ArrayResize(timeframes, 8);
    
    int tfIndex = 0;
    if(InpUseDailyLevels) timeframes[tfIndex++] = PERIOD_D1;
    if(InpUseH8Levels) timeframes[tfIndex++] = PERIOD_H8;
    if(InpUseH6Levels) timeframes[tfIndex++] = PERIOD_H6;
    if(InpUseH4Levels) timeframes[tfIndex++] = PERIOD_H4;
    if(InpUseH1Levels) timeframes[tfIndex++] = PERIOD_H1;
    if(InpUseM30Levels) timeframes[tfIndex++] = PERIOD_M30;
    if(InpUseM15Levels) timeframes[tfIndex++] = PERIOD_M15;
    if(InpUseM5Levels) timeframes[tfIndex++] = PERIOD_M5;
    
    ArrayResize(timeframes, tfIndex);
    
    // Dessiner les niveaux pour chaque timeframe
    for(int tf = 0; tf < tfIndex; tf++)
    {
        ENUM_TIMEFRAMES timeframe = timeframes[tf];
        double tfSupportLevels[];
        double tfResistanceLevels[];
        
        // Détecter les niveaux pour ce timeframe
        DetectLevelsForTimeframe(symbol, timeframe, tfSupportLevels, tfResistanceLevels);
        
        // Obtenir la couleur et le style selon le timeframe
        color supportColor, resistanceColor;
        int lineStyle, lineWidth;
        GetTimeframeStyle(timeframe, supportColor, resistanceColor, lineStyle, lineWidth);
        
        // Dessiner les supports
        for(int i = 0; i < ArraySize(tfSupportLevels); i++)
        {
            string supportName = "Proximity_" + symbol + "_Support_" + GetTimeframeString(timeframe) + "_" + IntegerToString(i);
            if(ObjectCreate(0, supportName, OBJ_HLINE, 0, 0, tfSupportLevels[i]))
            {
                ObjectSetInteger(0, supportName, OBJPROP_COLOR, supportColor);
                ObjectSetInteger(0, supportName, OBJPROP_STYLE, lineStyle);
                ObjectSetInteger(0, supportName, OBJPROP_WIDTH, lineWidth);
                ObjectSetString(0, supportName, OBJPROP_TEXT, "SUPPORT " + GetTimeframeString(timeframe) + " " + DoubleToString(tfSupportLevels[i], 5));
            }
        }
        
        // Dessiner les résistances
        for(int i = 0; i < ArraySize(tfResistanceLevels); i++)
        {
            string resistanceName = "Proximity_" + symbol + "_Resistance_" + GetTimeframeString(timeframe) + "_" + IntegerToString(i);
            if(ObjectCreate(0, resistanceName, OBJ_HLINE, 0, 0, tfResistanceLevels[i]))
            {
                ObjectSetInteger(0, resistanceName, OBJPROP_COLOR, resistanceColor);
                ObjectSetInteger(0, resistanceName, OBJPROP_STYLE, lineStyle);
                ObjectSetInteger(0, resistanceName, OBJPROP_WIDTH, lineWidth);
                ObjectSetString(0, resistanceName, OBJPROP_TEXT, "RESISTANCE " + GetTimeframeString(timeframe) + " " + DoubleToString(tfResistanceLevels[i], 5));
            }
        }
    }
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Obtenir le style visuel selon le timeframe                      |
//+------------------------------------------------------------------+
void GetTimeframeStyle(ENUM_TIMEFRAMES timeframe, color &supportColor, color &resistanceColor, int &lineStyle, int &lineWidth)
{
    switch(timeframe)
    {
        case PERIOD_D1:
            supportColor = clrLime;
            resistanceColor = clrRed;
            lineStyle = STYLE_SOLID;
            lineWidth = 3;
            break;
        case PERIOD_H8:
            supportColor = clrGreen;
            resistanceColor = clrMaroon;
            lineStyle = STYLE_SOLID;
            lineWidth = 2;
            break;
        case PERIOD_H6:
            supportColor = clrDarkGreen;
            resistanceColor = clrDarkRed;
            lineStyle = STYLE_SOLID;
            lineWidth = 2;
            break;
        case PERIOD_H4:
            supportColor = clrForestGreen;
            resistanceColor = clrFireBrick;
            lineStyle = STYLE_DASH;
            lineWidth = 2;
            break;
        case PERIOD_H1:
            supportColor = clrMediumSeaGreen;
            resistanceColor = clrIndianRed;
            lineStyle = STYLE_DASH;
            lineWidth = 1;
            break;
        case PERIOD_M30:
            supportColor = clrLightGreen;
            resistanceColor = clrLightCoral;
            lineStyle = STYLE_DOT;
            lineWidth = 1;
            break;
        case PERIOD_M15:
            supportColor = clrPaleGreen;
            resistanceColor = clrMistyRose;
            lineStyle = STYLE_DOT;
            lineWidth = 1;
            break;
        case PERIOD_M5:
            supportColor = clrHoneydew;
            resistanceColor = clrLavenderBlush;
            lineStyle = STYLE_DOT;
            lineWidth = 1;
            break;
        default:
            supportColor = clrLime;
            resistanceColor = clrRed;
            lineStyle = STYLE_SOLID;
            lineWidth = 2;
    }
}

//+------------------------------------------------------------------+
//| Obtenir la chaîne de caractères du timeframe                   |
//+------------------------------------------------------------------+
string GetTimeframeString(ENUM_TIMEFRAMES timeframe)
{
    switch(timeframe)
    {
        case PERIOD_D1:  return "D1";
        case PERIOD_H8:  return "H8";
        case PERIOD_H6:  return "H6";
        case PERIOD_H4:  return "H4";
        case PERIOD_H1:  return "H1";
        case PERIOD_M30: return "M30";
        case PERIOD_M15: return "M15";
        case PERIOD_M5:  return "M5";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Initialiser les niveaux testés positifs                        |
//+------------------------------------------------------------------+
void InitializeTestedLevels()
{
    if(g_levelsInitialized) return;
    
    ArrayResize(g_testedLevels, 0);
    g_lastLevelUpdate = TimeCurrent();
    g_levelsInitialized = true;
    
    if(InpDebug)
    {
        Print("🔧 INITIALISATION: Système de niveaux testés positifs activé");
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour les niveaux testés positifs                       |
//+------------------------------------------------------------------+
void UpdateTestedLevels(const string symbol)
{
    if(!g_levelsInitialized) InitializeTestedLevels();
    
    // Mettre à jour toutes les 5 minutes
    if(TimeCurrent() - g_lastLevelUpdate < 300) return;
    
    g_lastLevelUpdate = TimeCurrent();
    
    // Détecter les nouveaux niveaux
    double supportLevels[];
    double resistanceLevels[];
    DetectSupportResistanceLevels(symbol, supportLevels, resistanceLevels);
    
    // Valider les niveaux existants
    ValidateExistingLevels(symbol);
    
    // Ajouter les nouveaux niveaux
    AddNewLevels(symbol, supportLevels, resistanceLevels);
    
    // Nettoyer les niveaux invalides
    CleanInvalidLevels();
    
    if(InpDebug)
    {
        Print("🔄 MISE À JOUR NIVEAUX [", symbol, "]: ", ArraySize(g_testedLevels), " niveaux testés positifs");
    }
}

//+------------------------------------------------------------------+
//| Valider les niveaux existants                                  |
//+------------------------------------------------------------------+
void ValidateExistingLevels(const string symbol)
{
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(currentPrice <= 0) return;
    
    for(int i = 0; i < ArraySize(g_testedLevels); i++)
    {
        if(!g_testedLevels[i].isValid) continue;
        
        double levelPrice = g_testedLevels[i].price;
        double distance = MathAbs(currentPrice - levelPrice) / currentPrice;
        
        // Si le prix est proche du niveau, vérifier s'il le teste
        if(distance <= InpProximityThreshold)
        {
            // Vérifier si le niveau a été testé (touché)
            if(IsLevelTested(symbol, levelPrice, g_testedLevels[i].levelType))
            {
                g_testedLevels[i].touches++;
                g_testedLevels[i].lastTouch = TimeCurrent();
                
                if(InpDebug)
                {
                    Print("✅ NIVEAU TESTÉ [", symbol, "]: ", g_testedLevels[i].levelType, " @ ", 
                          DoubleToString(levelPrice, 5), " | Touches: ", g_testedLevels[i].touches);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier si un niveau a été testé                              |
//+------------------------------------------------------------------+
bool IsLevelTested(const string symbol, double levelPrice, string levelType)
{
    // Vérifier les dernières barres pour voir si le niveau a été touché
    for(int i = 1; i <= 5; i++)
    {
        double high = iHigh(symbol, PERIOD_M1, i);
        double low = iLow(symbol, PERIOD_M1, i);
        
        if(levelType == "SUPPORT")
        {
            // Pour un support, vérifier si le prix a touché le niveau par le bas
            if(MathAbs(low - levelPrice) < 0.001)
            {
                return true;
            }
        }
        else if(levelType == "RESISTANCE")
        {
            // Pour une résistance, vérifier si le prix a touché le niveau par le haut
            if(MathAbs(high - levelPrice) < 0.001)
            {
                return true;
            }
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Ajouter de nouveaux niveaux                                    |
//+------------------------------------------------------------------+
void AddNewLevels(const string symbol, double &supportLevels[], double &resistanceLevels[])
{
    // Ajouter les supports
    for(int i = 0; i < ArraySize(supportLevels); i++)
    {
        if(!LevelExists(supportLevels[i]))
        {
            AddTestedLevel(supportLevels[i], "SUPPORT", PERIOD_M1);
        }
    }
    
    // Ajouter les résistances
    for(int i = 0; i < ArraySize(resistanceLevels); i++)
    {
        if(!LevelExists(resistanceLevels[i]))
        {
            AddTestedLevel(resistanceLevels[i], "RESISTANCE", PERIOD_M1);
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier si un niveau existe déjà                              |
//+------------------------------------------------------------------+
bool LevelExists(double price)
{
    for(int i = 0; i < ArraySize(g_testedLevels); i++)
    {
        if(MathAbs(g_testedLevels[i].price - price) < 0.001)
        {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Ajouter un niveau testé                                        |
//+------------------------------------------------------------------+
void AddTestedLevel(double price, string levelType, ENUM_TIMEFRAMES timeframe)
{
    if(ArraySize(g_testedLevels) >= g_maxTestedLevels)
    {
        // Supprimer le niveau le plus ancien
        for(int i = 0; i < ArraySize(g_testedLevels) - 1; i++)
        {
            g_testedLevels[i] = g_testedLevels[i + 1];
        }
        ArrayResize(g_testedLevels, ArraySize(g_testedLevels) - 1);
    }
    
    int newIndex = ArraySize(g_testedLevels);
    ArrayResize(g_testedLevels, newIndex + 1);
    
    g_testedLevels[newIndex].price = price;
    g_testedLevels[newIndex].touches = 0;
    g_testedLevels[newIndex].lastTouch = 0;
    g_testedLevels[newIndex].isValid = true;
    g_testedLevels[newIndex].timeframe = timeframe;
    g_testedLevels[newIndex].levelType = levelType;
    
    if(InpDebug)
    {
        Print("➕ NOUVEAU NIVEAU [", levelType, "]: ", DoubleToString(price, 5), " @ ", GetTimeframeString(timeframe));
    }
}

//+------------------------------------------------------------------+
//| Nettoyer les niveaux invalides                                 |
//+------------------------------------------------------------------+
void CleanInvalidLevels()
{
    for(int i = ArraySize(g_testedLevels) - 1; i >= 0; i--)
    {
        // Supprimer les niveaux non testés depuis plus de 24h
        if(g_testedLevels[i].lastTouch > 0 && TimeCurrent() - g_testedLevels[i].lastTouch > 86400)
        {
            if(InpDebug)
            {
                Print("🗑️ NIVEAU SUPPRIMÉ [", g_testedLevels[i].levelType, "]: ", 
                      DoubleToString(g_testedLevels[i].price, 5), " (non testé depuis 24h)");
            }
            
            // Déplacer les éléments
            for(int j = i; j < ArraySize(g_testedLevels) - 1; j++)
            {
                g_testedLevels[j] = g_testedLevels[j + 1];
            }
            ArrayResize(g_testedLevels, ArraySize(g_testedLevels) - 1);
        }
    }
}

//+------------------------------------------------------------------+
//| Analyser la proximité des niveaux testés positifs             |
//+------------------------------------------------------------------+
bool AnalyzeTestedLevelsProximity(const string symbol, int &direction, double &confidence)
{
    if(!InpEnableProximityTrading) return false;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(currentPrice <= 0) return false;
    
    // Mettre à jour les niveaux testés
    UpdateTestedLevels(symbol);
    
    // Chercher le niveau testé le plus proche
    double minDistance = DBL_MAX;
    int bestLevelIndex = -1;
    
    for(int i = 0; i < ArraySize(g_testedLevels); i++)
    {
        if(!g_testedLevels[i].isValid) continue;
        
        double distance = MathAbs(currentPrice - g_testedLevels[i].price) / currentPrice;
        
        if(distance < minDistance && distance <= InpProximityThreshold)
        {
            minDistance = distance;
            bestLevelIndex = i;
        }
    }
    
    if(bestLevelIndex >= 0)
    {
        TestedLevel level = g_testedLevels[bestLevelIndex];
        
        // Calculer la confiance basée sur le nombre de touches
        double touchConfidence = MathMin(level.touches * 20.0, 95.0);
        
        if(level.levelType == "SUPPORT" && touchConfidence >= InpMinConfidence)
        {
            direction = POSITION_TYPE_BUY;
            confidence = touchConfidence;
            
            if(InpDebug)
            {
                Print("🎯 NIVEAU TESTÉ POSITIF [", symbol, "]: SUPPORT @ ", DoubleToString(level.price, 5), 
                      " | Touches: ", level.touches, " | Confiance: ", DoubleToString(confidence, 1), "%");
            }
            
            return true;
        }
        else if(level.levelType == "RESISTANCE" && touchConfidence >= InpMinConfidence)
        {
            direction = POSITION_TYPE_SELL;
            confidence = touchConfidence;
            
            if(InpDebug)
            {
                Print("🎯 NIVEAU TESTÉ POSITIF [", symbol, "]: RÉSISTANCE @ ", DoubleToString(level.price, 5), 
                      " | Touches: ", level.touches, " | Confiance: ", DoubleToString(confidence, 1), "%");
            }
            
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Dessiner les niveaux testés positifs                          |
//+------------------------------------------------------------------+
void DrawTestedLevels(const string symbol)
{
    if(!InpShowProximityZones) return;
    if(!SymbolSelect(symbol, true)) return;
    
    // Supprimer les anciennes zones
    ObjectsDeleteAll(0, "Tested_" + symbol + "_");
    
    for(int i = 0; i < ArraySize(g_testedLevels); i++)
    {
        if(!g_testedLevels[i].isValid) continue;
        
        TestedLevel level = g_testedLevels[i];
        string levelName = "Tested_" + symbol + "_" + level.levelType + "_" + IntegerToString(i);
        
        if(ObjectCreate(0, levelName, OBJ_HLINE, 0, 0, level.price))
        {
            // Couleur selon le type et le nombre de touches
            color levelColor;
            if(level.levelType == "SUPPORT")
            {
                levelColor = (level.touches >= 3) ? clrLime : clrGreen;
            }
            else
            {
                levelColor = (level.touches >= 3) ? clrRed : clrMaroon;
            }
            
            ObjectSetInteger(0, levelName, OBJPROP_COLOR, levelColor);
            ObjectSetInteger(0, levelName, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(0, levelName, OBJPROP_WIDTH, MathMax(level.touches, 1));
            ObjectSetString(0, levelName, OBJPROP_TEXT, level.levelType + " TESTÉ (" + IntegerToString(level.touches) + ") " + DoubleToString(level.price, 5));
        }
    }
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Détecter les mouvements en ciseaux haussiers/baissiers         |
//+------------------------------------------------------------------+
bool DetectScissorMovement(const string symbol, int &direction, double &confidence)
{
    if(!InpEnableScissorDetection) return false;
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    if(currentPrice <= 0) return false;
    
    // Analyser les dernières barres pour détecter un mouvement en ciseaux
    double prices[];
    ArrayResize(prices, InpScissorLookbackBars);
    
    // Récupérer les prix des dernières barres
    for(int i = 0; i < InpScissorLookbackBars; i++)
    {
        prices[i] = iClose(symbol, PERIOD_M1, i + 1);
    }
    
    // Analyser le pattern de ciseaux
    ScissorPattern pattern = AnalyzeScissorPattern(prices, InpScissorLookbackBars);
    
    if(pattern.isValid && pattern.confidence >= InpScissorConfidence)
    {
        direction = pattern.direction;
        confidence = pattern.confidence;
        
        if(InpDebug)
        {
            Print("✂️ MOUVEMENT CISEAUX [", symbol, "]: ", 
                  (pattern.direction == POSITION_TYPE_BUY ? "HAUSSIER" : "BAISSIER"),
                  " | Confiance ", DoubleToString(confidence, 1), "%",
                  " | Amplitude ", DoubleToString(pattern.amplitude * 100, 2), "%");
        }
        
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Structure pour les patterns de ciseaux                         |
//+------------------------------------------------------------------+
struct ScissorPattern
{
    bool isValid;
    int direction;
    double confidence;
    double amplitude;
    int peakIndex;
    int valleyIndex;
};

//+------------------------------------------------------------------+
//| Analyser le pattern de ciseaux                                 |
//+------------------------------------------------------------------+
ScissorPattern AnalyzeScissorPattern(double &prices[], int barCount)
{
    ScissorPattern pattern;
    pattern.isValid = false;
    pattern.direction = 0;
    pattern.confidence = 0.0;
    pattern.amplitude = 0.0;
    pattern.peakIndex = -1;
    pattern.valleyIndex = -1;
    
    if(barCount < 5) return pattern;
    
    // Trouver le point le plus haut et le plus bas
    double maxPrice = prices[0];
    double minPrice = prices[0];
    int maxIndex = 0;
    int minIndex = 0;
    
    for(int i = 1; i < barCount; i++)
    {
        if(prices[i] > maxPrice)
        {
            maxPrice = prices[i];
            maxIndex = i;
        }
        if(prices[i] < minPrice)
        {
            minPrice = prices[i];
            minIndex = i;
        }
    }
    
    // Calculer l'amplitude du mouvement
    double amplitude = (maxPrice - minPrice) / minPrice;
    
    if(amplitude < InpScissorMinMove) return pattern;
    
    // Déterminer la direction du ciseaux
    double currentPrice = prices[0];
    double startPrice = prices[barCount - 1];
    
    // Analyser la tendance générale
    bool isUptrend = (currentPrice > startPrice);
    bool isDowntrend = (currentPrice < startPrice);
    
    // Analyser les mouvements alternés (ciseaux)
    int upMoves = 0;
    int downMoves = 0;
    
    for(int i = 1; i < barCount; i++)
    {
        if(prices[i] > prices[i-1]) upMoves++;
        else if(prices[i] < prices[i-1]) downMoves++;
    }
    
    // Calculer la confiance basée sur l'amplitude et l'alternance
    double amplitudeConfidence = MathMin(amplitude * 1000, 50.0); // Max 50% pour l'amplitude
    double alternanceConfidence = MathMin((upMoves + downMoves) * 5, 30.0); // Max 30% pour l'alternance
    double trendConfidence = 20.0; // 20% de base
    
    pattern.confidence = amplitudeConfidence + alternanceConfidence + trendConfidence;
    
    // Déterminer la direction finale
    if(isUptrend && pattern.confidence >= InpScissorConfidence)
    {
        pattern.direction = POSITION_TYPE_BUY;
        pattern.isValid = true;
        pattern.amplitude = amplitude;
        pattern.peakIndex = maxIndex;
        pattern.valleyIndex = minIndex;
    }
    else if(isDowntrend && pattern.confidence >= InpScissorConfidence)
    {
        pattern.direction = POSITION_TYPE_SELL;
        pattern.isValid = true;
        pattern.amplitude = amplitude;
        pattern.peakIndex = maxIndex;
        pattern.valleyIndex = minIndex;
    }
    
    return pattern;
}

//+------------------------------------------------------------------+
//| Dessiner les signaux de ciseaux                               |
//+------------------------------------------------------------------+
void DrawScissorSignals(const string symbol)
{
    if(!InpShowScissorSignals) return;
    if(!SymbolSelect(symbol, true)) return;
    
    // Supprimer les anciens signaux
    ObjectsDeleteAll(0, "Scissor_" + symbol + "_");
    
    double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID);
    datetime currentTime = TimeCurrent();
    
    // Analyser le pattern actuel
    double prices[];
    ArrayResize(prices, InpScissorLookbackBars);
    
    for(int i = 0; i < InpScissorLookbackBars; i++)
    {
        prices[i] = iClose(symbol, PERIOD_M1, i + 1);
    }
    
    ScissorPattern pattern = AnalyzeScissorPattern(prices, InpScissorLookbackBars);
    
    if(pattern.isValid && pattern.confidence >= InpScissorConfidence)
    {
        string signalName = "Scissor_" + symbol + "_" + IntegerToString(GetTickCount());
        
        if(ObjectCreate(0, signalName, OBJ_ARROW, 0, currentTime, currentPrice))
        {
            // Couleur selon la direction
            color signalColor = (pattern.direction == POSITION_TYPE_BUY) ? clrLime : clrRed;
            int arrowCode = (pattern.direction == POSITION_TYPE_BUY) ? 233 : 234;
            
            ObjectSetInteger(0, signalName, OBJPROP_ARROWCODE, arrowCode);
            ObjectSetInteger(0, signalName, OBJPROP_COLOR, signalColor);
            ObjectSetInteger(0, signalName, OBJPROP_WIDTH, 4);
            ObjectSetString(0, signalName, OBJPROP_TEXT, 
                "CISEAUX " + (pattern.direction == POSITION_TYPE_BUY ? "HAUSSIER" : "BAISSIER") + 
                " " + DoubleToString(pattern.confidence, 1) + "%");
        }
    }
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Vérifier si le symbole est un indice Boom/Crash                 |
//+------------------------------------------------------------------+
bool IsBoomCrashSymbol(const string symbol)
{
    if(symbol == "") return false;
    return (StringFind(symbol, "Boom") >= 0 || StringFind(symbol, "Crash") >= 0);
}

//+------------------------------------------------------------------+
//| Vérifier et fermer les positions après un spike                  |
//+------------------------------------------------------------------+
void CheckAndCloseAfterSpike(const string symbol, bool isBoom)
{
    if(!IsBoomCrashSymbol(symbol)) return;
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        
        if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
        
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        double profit = PositionGetDouble(POSITION_PROFIT);
        double profitPoints = 0;
        
        if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
        {
            profitPoints = (currentPrice - openPrice) / point;
        }
        else
        {
            profitPoints = (openPrice - currentPrice) / point;
        }
        
        // Fermer la position si le profit minimum est atteint
        if(profitPoints >= g_boomCrashMinProfitPoints)
        {
            CTrade trade;
            if(trade.PositionClose(ticket))
            {
                Print("✅ Position fermée après spike sur ", symbol, 
                      " - Profit: ", DoubleToString(profit, 2), 
                      " - Points: ", DoubleToString(profitPoints, 1));
            }
            else
            {
                Print("❌ Erreur fermeture position ", ticket, " sur ", symbol, 
                      " - Erreur: ", GetLastError());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Calculer le lot optimal pour Boom/Crash                          |
//+------------------------------------------------------------------+
double CalculateBoomCrashLotSize(const string symbol, double riskPercent = 1.0)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * (riskPercent / 100.0);
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    
    // Calculer le lot basé sur le risque et le stop loss
    double stopLossPoints = g_boomCrashMinProfitPoints * 0.5; // SL à 50% du TP
    double moneyPerLot = stopLossPoints * tickValue / tickSize;
    
    if(moneyPerLot <= 0) return minLot;
    
    double lots = NormalizeDouble(riskAmount / moneyPerLot, 2);
    
    // Ajuster au lot step le plus proche
    lots = MathFloor(lots / lotStep) * lotStep;
    
    // Vérifier les limites
    if(lots < minLot) lots = minLot;
    if(lots > maxLot) lots = maxLot;
    
    return lots;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Libérer les indicateurs
    ReleaseIndicators();
    
    // Supprimer les objets graphiques
    ObjectsDeleteAll(0, "SpikeAnnouncement_");
    ObjectsDeleteAll(0, "StepPattern_");
    ObjectsDeleteAll(0, "EMA_");
    
    Print("Expert Advisor arrêté. Raison: ", GetUninitReasonText(reason));
}

//+------------------------------------------------------------------+
//| Mettre à jour les indicateurs                                   |
//+------------------------------------------------------------------+
void UpdateIndicators(const string symbol)
{
    if(!InpEnableTrading) return;
    
    // Initialiser les indicateurs si nécessaire
    if(!InitializeIndicators(symbol)) return;
    
    // Mettre à jour le cache des indicateurs
    UpdateIndicatorCache();
    
    // Afficher les indicateurs graphiques
    if(InpShowModernIndicators)
    {
        DrawIndicators(symbol);
    }
}

//+------------------------------------------------------------------+
//| Vérifier les opportunités de trading                            |
//+------------------------------------------------------------------+
void CheckTradingOpportunities()
{
    if(!InpEnableTrading) return;
    
    string symbol = Symbol();
    
    // Vérifier si le symbole est autorisé
    if(!IsBoomCrashSymbol(symbol) && !CanTradeSymbol(symbol))
        return;
    
    // Analyser les conditions techniques
    double probability = AnalyzeTechnicalConditions(symbol);
    
    // Vérifier si on peut ouvrir un nouveau trade
    if(CanOpenNewTradeForSymbol(symbol))
    {
        // Détecter et exécuter les signaux
        DetectAndExecuteSignal(symbol);
    }
    
    // Gérer la prédiction de spike
    if(InpEnablePrediction)
    {
        ProcessPredictiveAnalysis(symbol);
    }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Vérifier si c'est une nouvelle bougie
    static datetime lastBarTime = 0;
    datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
    
    if(lastBarTime != currentBarTime)
    {
        lastBarTime = currentBarTime;
        // Mettre à jour les indicateurs à chaque nouvelle bougie
        UpdateIndicators(_Symbol);
    }
    
    // Vérifier les opportunités de trading
    CheckTradingOpportunities();
    
    // Gérer les positions ouvertes
    ManageOpenPositions();
}

//+------------------------------------------------------------------+
//| Fonction utilitaire pour obtenir la raison de la désinitialisation |
//+------------------------------------------------------------------+
string GetUninitReasonText(int reasonCode)
{
    switch(reasonCode)
    {
        case REASON_ACCOUNT:
            return "Compte changé";
        case REASON_CHARTCHANGE:
            return "Paramètres du graphique modifiés";
        case REASON_CHARTCLOSE:
            return "Graphique fermé";
        case REASON_PARAMETERS:
            return "Paramètres d'entrée modifiés";
        case REASON_RECOMPILE:
            return "Expert recompilé";
        case REASON_REMOVE:
            return "Expert retiré du graphique";
        case REASON_TEMPLATE:
            return "Modèle appliqué";
        default:
            return "Autre raison";
    }
}
