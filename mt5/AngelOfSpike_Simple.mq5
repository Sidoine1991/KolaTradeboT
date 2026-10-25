//+------------------------------------------------------------------+
//| AngelOfSpike.mq5 - Version Simplifiée                            |
//| Robot de Trading Automatique - Version Corrigée                 |
//+------------------------------------------------------------------+
#property copyright "AngelOfSpike Simplified"
#property version   "5.0"
#property description "Robot de trading simplifié pour Boom/Crash"

//--- Includes
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/HistoryOrderInfo.mqh>
#include <Object.mqh>

//--- Inputs
input group "=== CONFIGURATION GENERALE ==="
input bool   InpEnableTrading          = true;   // Activer le trading automatique
input int    InpMagicNumber            = 880011; // Magic number
input string InpAllowedSymbols         = "Boom 300 Index,Crash 300 Index"; // Symboles autorises

input group "=== GESTION DU CAPITAL ==="
input double InpLotSize                = 0.01;   // Taille du lot
input double InpMaxLotSize             = 1.0;    // Taille maximum du lot
input double InpMinSLDistance          = 20.0;   // Distance minimum SL (points)
input double InpMaxSLDistance          = 50.0;   // Distance maximum SL (points)
input double InpMinTPDistance          = 20.0;   // Distance minimum TP (points)
input double InpMaxTPDistance          = 100.0;  // Distance maximum TP (points)
input double InpRiskRewardRatio        = 2.0;    // Ratio risque/recompense

input group "=== SIGNAL & EXECUTION ==="
input bool   InpTradeOnSpikeImmediately= true;   // Executer le trade des l'affichage de la fleche
input bool   InpShowSpikeArrows        = true;   // Afficher les fleches predictives
input double InpMinSpikeM1Probability  = 15.0;   // Seuil probabilite M1 pour signal
input int    InpArrowBlinkSeconds      = 5;      // Duree affichage fleche (secondes)

input group "=== DEBUG & MONITORING ==="
input bool   InpDebug                  = true;   // Mode debug active
input bool   InpShowHeartbeat          = true;   // Afficher logs heartbeat
input bool   InpSendNotifications      = true;   // Envoyer notifications
input string InpNotifyTag              = "AngelOfSpike"; // Tag notifications

//--- Variables globales
CTrade g_trade;
datetime g_lastHeartbeat = 0;
datetime g_lastOrderTime = 0;
int g_heartbeatCounter = 0;
int g_signalAttempts = 0;
int g_lastSignalDirection = 0;
string g_lastSignalSymbol = "";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 AngelOfSpike - Version Simplifiée");
    Print("=====================================");
   
    // Configurer le trade
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(10);
    g_trade.SetTypeFilling(ORDER_FILLING_FOK);
    
    Print("🔧 Configuration Trade:");
    Print("   - Magic Number: ", InpMagicNumber);
    Print("   - Lot Size: ", InpLotSize);
    Print("   - Trading: ", InpEnableTrading ? "ACTIF" : "INACTIF");
    Print("   - Debug: ", InpDebug ? "ACTIF" : "INACTIF");
    Print("=====================================");
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🛑 AngelOfSpike arrêté - Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Logs heartbeat périodiques
    if(InpShowHeartbeat && TimeCurrent() - g_lastHeartbeat >= 10)
    {
        LogHeartbeat();
        g_lastHeartbeat = TimeCurrent();
    }
    
    // Vérifier les conditions de base
    if(!InpEnableTrading)
    {
        return;
    }
    
    // Traiter les symboles autorisés
    string symbols[];
    StringSplit(InpAllowedSymbols, ',', symbols);
    
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        string symbol = StringTrim(symbols[i]);
        if(symbol == "") continue;
        
        // Vérifier si on peut trader ce symbole
        if(CanTradeSymbol(symbol))
        {
            // Détecter et exécuter les signaux
            DetectAndExecuteSignal(symbol);
        }
    }
    
    // Afficher des indicateurs de debug si activé
    if(InpDebug)
    {
        Print("🔍 Debug: ", TimeToString(TimeCurrent()));
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
    // Logs heartbeat périodiques
    if(InpShowHeartbeat)
    {
        LogHeartbeat();
    }
}

//+------------------------------------------------------------------+
//| Détecter et exécuter les signaux                                |
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
    
    if(probability >= InpMinSpikeM1Probability)
    {
        g_signalAttempts++;
        
        // Choisir la direction
        int direction = ChooseSignalDirection(symbol);
        
        if(direction != 0)
        {
            Print("🎯 SIGNAL DÉTECTÉ: ", symbol, " - Direction: ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), " - Probabilité: ", probability, "%");
            
            // Afficher la flèche
            if(InpShowSpikeArrows)
            {
                DrawSpikeArrow(symbol, direction);
            }
            
            // Exécuter le trade
            if(InpTradeOnSpikeImmediately)
            {
                ExecuteTrade(symbol, direction);
            }
            
            // Mettre à jour les variables de suivi
            g_lastSignalSymbol = symbol;
            g_lastSignalDirection = direction;
        }
    }
    else
    {
        if(InpDebug) Print("📊 ", symbol, " - Probabilité insuffisante: ", DoubleToString(probability, 1), "%");
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
            probability += 30.0;
        }
        
        // Volatilité récente
        double volatility = CalculateVolatility(symbol, 3);
        if(volatility > 0.3)
        {
            probability += 25.0;
        }
        
        // Pression d'achat
        double buyPressure = CalculateBuyPressure(symbol);
        if(buyPressure > 0.6)
        {
            probability += 20.0;
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
            probability += 30.0;
        }
        
        // Volatilité récente
        double volatility = CalculateVolatility(symbol, 3);
        if(volatility > 0.3)
        {
            probability += 25.0;
        }
        
        // Pression de vente
        double sellPressure = CalculateSellPressure(symbol);
        if(sellPressure > 0.6)
        {
            probability += 20.0;
        }
    }
    
    // Limiter la probabilité maximale
    probability = MathMin(probability, 95.0);
    
    if(InpDebug) Print("🔍 Probabilité finale: ", DoubleToString(probability, 1), "%");
    
    return probability;
}

//+------------------------------------------------------------------+
//| Choisir la direction du signal                                  |
//+------------------------------------------------------------------+
int ChooseSignalDirection(const string symbol)
{
    if(StringFind(symbol, "Boom") >= 0)
    {
        if(InpDebug) Print("   Direction prédite: ACHAT (Boom)");
        return POSITION_TYPE_BUY;
    }
    else if(StringFind(symbol, "Crash") >= 0)
    {
        if(InpDebug) Print("   Direction prédite: VENTE (Crash)");
        return POSITION_TYPE_SELL;
    }
    
    // Pour les autres symboles, analyser la tendance
    double price1 = iClose(symbol, PERIOD_CURRENT, 1);
    double price5 = iClose(symbol, PERIOD_CURRENT, 5);
    
    if(price1 > price5)
    {
        if(InpDebug) Print("   Direction prédite: ACHAT (Tendance haussière)");
        return POSITION_TYPE_BUY;
    }
    else
    {
        if(InpDebug) Print("   Direction prédite: VENTE (Tendance baissière)");
        return POSITION_TYPE_SELL;
    }
}

//+------------------------------------------------------------------+
//| Exécuter un trade                                               |
//+------------------------------------------------------------------+
bool ExecuteTrade(const string symbol, int direction)
{
    Print("⚡ EXECUTION TRADE: ", symbol, " - ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
    
    // Vérifications finales
    if(!CanPlaceNewOrder(symbol, direction))
    {
        Print("🚫 EXECUTION BLOQUEE: CanPlaceNewOrder a refuse");
        return false;
    }
    
    // Calculer le lot
    double lot = CalculateLot(symbol);
    if(lot <= 0)
    {
        Print("🚫 EXECUTION BLOQUEE: Lot invalide (", lot, ")");
        return false;
    }
    
    // Obtenir les prix actuels
    double currentBid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    if(currentBid <= 0 || currentAsk <= 0)
    {
        Print("🚫 EXECUTION BLOQUEE: Prix invalides");
        return false;
    }
    
    // Calculer les niveaux SL/TP
    double sl = 0, tp = 0;
    if(!CalculateSLTP(symbol, direction, (direction == POSITION_TYPE_BUY ? currentAsk : currentBid), sl, tp))
    {
        Print("🚫 EXECUTION BLOQUEE: Impossible de calculer SL/TP valides");
        return false;
    }
    
    // Exécuter le trade
    bool success = false;
    if(direction == POSITION_TYPE_BUY)
    {
        success = g_trade.Buy(lot, symbol, currentAsk, sl, tp, "AngelOfSpike_Buy");
    }
    else
    {
        success = g_trade.Sell(lot, symbol, currentBid, sl, tp, "AngelOfSpike_Sell");
    }
    
    if(success)
    {
        Print("✅ TRADE EXECUTE: ", symbol, " - ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"), " - Lot: ", lot);
        g_lastOrderTime = TimeCurrent();
        
        // Envoyer notification
        if(InpSendNotifications)
        {
            SendNotification(InpNotifyTag + ": Trade execute " + symbol + " " + (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
        }
    }
    else
    {
        Print("❌ ECHEC TRADE: ", symbol, " - Erreur: ", g_trade.ResultRetcode());
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| Calculer le lot                                                 |
//+------------------------------------------------------------------+
double CalculateLot(const string symbol)
{
    double lot = InpLotSize;
    
    // Obtenir les contraintes du symbole
    double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
    
    // Normaliser le lot
    if(minLot > 0 && maxLot > 0 && lotStep > 0)
    {
        lot = MathMax(lot, minLot);
        lot = MathMin(lot, MathMin(maxLot, InpMaxLotSize));
        lot = MathRound(lot / lotStep) * lotStep;
    }
    
    return lot;
}

//+------------------------------------------------------------------+
//| Calculer SL/TP                                                  |
//+------------------------------------------------------------------+
bool CalculateSLTP(const string symbol, int direction, double entryPrice, double &sl, double &tp)
{
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    double spread = SymbolInfoDouble(symbol, SYMBOL_SPREAD) * point;
    
    if(direction == POSITION_TYPE_BUY)
    {
        sl = entryPrice - (InpMinSLDistance * point);
        tp = entryPrice + (InpMinSLDistance * point * InpRiskRewardRatio);
    }
    else
    {
        sl = entryPrice + (InpMinSLDistance * point);
        tp = entryPrice - (InpMinSLDistance * point * InpRiskRewardRatio);
    }
    
    // Vérifier les distances minimales
    double minDistance = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
    if(minDistance > 0)
    {
        if(direction == POSITION_TYPE_BUY)
        {
            if(sl > entryPrice - minDistance) sl = entryPrice - minDistance;
            if(tp < entryPrice + minDistance) tp = entryPrice + minDistance;
        }
        else
        {
            if(sl < entryPrice + minDistance) sl = entryPrice + minDistance;
            if(tp > entryPrice - minDistance) tp = entryPrice - minDistance;
        }
    }
    
    return (sl > 0 && tp > 0);
}

//+------------------------------------------------------------------+
//| Vérifier si on peut placer un nouvel ordre                      |
//+------------------------------------------------------------------+
bool CanPlaceNewOrder(const string symbol, int direction)
{
    // Vérifier le cooldown
    if(TimeCurrent() - g_lastOrderTime < 5)
    {
        if(InpDebug) Print("⏰ Cooldown actif - Attendre 5 secondes");
        return false;
    }
    
    // Vérifier le nombre de positions
    int totalPositions = CountEAPositions();
    if(totalPositions >= 5) // Limite de 5 positions
    {
        if(InpDebug) Print("🚫 Limite de positions atteinte: ", totalPositions);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Compter les positions de l'EA                                   |
//+------------------------------------------------------------------+
int CountEAPositions()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetTicket(i) > 0)
        {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
                count++;
            }
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| Compter les positions pour un symbole                           |
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
    // Vérifier si le symbole est dans la liste autorisée
    if(StringFind(InpAllowedSymbols, symbol) < 0)
    {
        return false;
    }
    
    // Vérifier si le symbole est disponible
    if(!SymbolSelect(symbol, true))
    {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Dessiner une flèche de signal                                   |
//+------------------------------------------------------------------+
void DrawSpikeArrow(const string symbol, int direction)
{
    // Supprimer les anciennes flèches pour ce symbole
    ObjectsDeleteAll(0, "AngelOfSpike_" + symbol + "_");
    
    // Créer un identifiant unique pour la flèche
    string arrowName = "AngelOfSpike_" + symbol + "_" + IntegerToString(GetTickCount());
    
    // Utiliser le graphique actuel
    datetime time = TimeCurrent();
    double currentPrice = (direction == POSITION_TYPE_BUY) ? 
                         SymbolInfoDouble(symbol, SYMBOL_BID) - 30 * SymbolInfoDouble(symbol, SYMBOL_POINT) : 
                         SymbolInfoDouble(symbol, SYMBOL_ASK) + 30 * SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // Vérifier les valeurs avant création
    if(time <= 0 || currentPrice <= 0)
    {
        Print("❌ Erreur: Valeurs invalides pour la flèche - Time:", time, " Price:", currentPrice);
        return;
    }
    
    Print("🎯 Affichage flèche: ", arrowName, " - Direction: ", (direction == POSITION_TYPE_BUY ? "BUY" : "SELL"));
    
    // Créer la flèche
    if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, time, currentPrice))
    {
        ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, direction == POSITION_TYPE_BUY ? 233 : 234);
        ObjectSetInteger(0, arrowName, OBJPROP_COLOR, direction == POSITION_TYPE_BUY ? clrLime : clrRed);
        ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 4);
        ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
        ObjectSetInteger(0, arrowName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
        ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
        
        // Forcer la mise à jour du graphique
        ChartRedraw(0);
        
        Print("✅ Flèche ", direction == POSITION_TYPE_BUY ? "ACHAT" : "VENTE", 
              " affichée sur ", symbol, " à ", TimeToString(TimeCurrent()));
    }
    else
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
//| Logs heartbeat                                                  |
//+------------------------------------------------------------------+
void LogHeartbeat()
{
    g_heartbeatCounter++;
    
    int totalPositions = CountEAPositions();
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    
    Print("💓 HEARTBEAT #", g_heartbeatCounter, " - ", TimeToString(TimeCurrent(), TIME_SECONDS));
    Print("   💰 Solde: $", DoubleToString(balance, 2));
    Print("   📊 Positions: ", totalPositions);
    Print("   🎯 Signaux: ", g_signalAttempts);
    Print("   🔄 Dernier signal: ", g_lastSignalSymbol, " - ", (g_lastSignalDirection == POSITION_TYPE_BUY ? "BUY" : "SELL"));
}