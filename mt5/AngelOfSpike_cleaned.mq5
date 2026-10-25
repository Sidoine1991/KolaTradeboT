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

CPositionInfo g_position;
CTrade g_trade;
bool g_predictionActive = false;
bool g_isBoomCrashMode = false;

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
int g_indicatorCacheSize = 0;

//--- Dernière mise à jour des indicateurs
datetime g_lastIndicatorUpdate = 0;
const int INDICATOR_UPDATE_INTERVAL = 1; // Mise à jour toutes les secondes

//--- Variable pour le contrôle du temps entre les ticks
static datetime g_lastTickTime = 0;

//--- Variables d'entrée
input int      InpMagicNumber = 123456;         // Magic Number
input double   InpMaxLossPerTradeUSD = 3.5;     // Perte maximale par trade (USD)
input bool     InpEnableBoomCrashTrading = true; // Activer le trading sur les indices Boom/Crash

//--- Variables pour la gestion des trades Boom/Crash
int g_boomCrashMinProfitPoints = 20;  // Profit minimum en points pour la fermeture après spike

//--- Function Declarations
bool ValidateOrderPrices(string symbol, double entryPrice, double &sl, double &tp, int direction);
bool InitializeIndicators(const string symbol);
void ReleaseIndicators();
void ClosePositionAfterSpikeCapture();

//+------------------------------------------------------------------+
//| Fermer la position après capture du spike                      |
//+------------------------------------------------------------------+
void ClosePositionAfterSpikeCapture()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionSelectByIndex(i))
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                string symbol = PositionGetString(POSITION_SYMBOL);
                double profit = PositionGetDouble(POSITION_PROFIT);

                // Fermer si profit > 0 (spike capturé) ou si perte > seuil
                if(profit > 0 || profit < -InpMaxLossPerTradeUSD)
                {
                    if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
                    {
                        g_trade.Sell(PositionGetDouble(POSITION_VOLUME), symbol, 0, 0, 0, "Spike Captured");
                    }
                    else
                    {
                        g_trade.Buy(PositionGetDouble(POSITION_VOLUME), symbol, 0, 0, 0, "Spike Captured");
                    }

                    Print("✅ POSITION FERMEE APRES SPIKE: ", symbol, " - Profit: $", DoubleToString(profit, 2));
                }
            }
        }
    }
}

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
    if(g_ma20Handle == INVALID_HANDLE) 
    { 
        Print("Erreur initialisation MA20"); 
        return false; 
    }
    
    g_ma50Handle = iMA(symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    if(g_ma50Handle == INVALID_HANDLE) 
    { 
        ReleaseIndicators(); 
        Print("Erreur initialisation MA50"); 
        return false;
    }
    
    // Initialiser d'autres indicateurs ici (RSI, MACD, etc.)...
    
    // Mettre à jour le symbole courant
    g_currentSymbol = symbol;
    
    return true;
}

//+------------------------------------------------------------------+
//| Libérer les poignées des indicateurs                            |
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
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Initialiser le trade
    g_trade.SetExpertMagicNumber(InpMagicNumber);
    
    // Initialiser les indicateurs pour le symbole courant
    if(!InitializeIndicators(_Symbol))
    {
        Print("Erreur lors de l'initialisation des indicateurs");
        return INIT_FAILED;
    }
    
    Print("AngelOfSpike Pro initialisé avec succès sur ", _Symbol);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Libérer les ressources
    ReleaseIndicators();
    Print("AngelOfSpike Pro arrêté");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    static datetime lastTickTime = 0;
    datetime currentTime = TimeCurrent();
    
    // Vérifier si le temps minimum entre les ticks est écoulé (1 seconde par défaut)
    if(currentTime - lastTickTime < 1)
        return;
    
    lastTickTime = currentTime;
    
    // Vérifier et fermer les positions selon les règles de spike
    ClosePositionAfterSpikeCapture();
    
    // Autres logiques de trading ici...
}

//+------------------------------------------------------------------+
//| Valider les prix d'ordre                                         |
//+------------------------------------------------------------------+
bool ValidateOrderPrices(string symbol, double entryPrice, double &sl, double &tp, int direction)
{
    if(symbol == "" || entryPrice <= 0)
        return false;
    
    // Obtenir les écarts de prix minimaux
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    
    // Vérifier les niveaux de stop loss et take profit
    if(sl > 0)
    {
        if((direction == ORDER_TYPE_BUY && sl >= entryPrice) || 
           (direction == ORDER_TYPE_SELL && sl <= entryPrice))
        {
            Print("Stop Loss invalide pour ", symbol, ": ", sl);
            return false;
        }
    }
    
    if(tp > 0)
    {
        if((direction == ORDER_TYPE_BUY && tp <= entryPrice) || 
           (direction == ORDER_TYPE_SELL && tp >= entryPrice))
        {
            Print("Take Profit invalide pour ", symbol, ": ", tp);
            return false;
        }
    }
    
    return true;
}
//+------------------------------------------------------------------+
