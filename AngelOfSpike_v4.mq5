//+------------------------------------------------------------------+
//|            AngelOfSpike v4.0 - Confluence & Spike Exit           |
//|    Version experte conçue pour la stratégie "Close After Spike"   |
//|               Créé et optimisé par l'Expert en IA                 |
//+------------------------------------------------------------------+
#property copyright "Conçu pour vous. Votre succès est l'objectif."
#property version   "4.0"
#property description "Stratégie de confluence moderne avec sortie dynamique post-spike et SL fixe en USD."

//--- Includes
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>

//--- Inputs (regroupés et nettoyés)
input group "=== CONFIGURATION GENERALE ==="
input bool   InpEnableTrading         = true;     // Activer le trading automatique
input int    InpMagicNumber           = 880011;   // Magic Number
input string InpAllowedSymbols        = "Boom 1000 Index,Crash 1000 Index,Boom 500 Index,Crash 500 Index"; // Symboles autorisés

input group "=== GESTION DE RISQUE 'SPIKE HUNTER' ==="
input double InpMaxLossPerTradeUSD    = 3.50;     // [STOP LOSS] Perte maximale par trade en USD
input int    InpMaxConcurrentTrades   = 1;        // Nombre de trades ouverts max en même temps
input double InpLotSize               = 0.2;      // Taille du lot (À DÉFINIR AVEC PRUDENCE)

input group "=== STRATÉGIE DE CONFLUENCE (ENTRÉE) ==="
input bool   InpEnableConfluence      = true;     // Activer la Stratégie de Confluence
input int    InpMinConfluenceSignals  = 3;        // Nb. minimum de signaux alignés (1-5) pour trader

input group "--- MODULE: RSI Extrême ---"
input bool   InpEnableRSI             = true;     // Activer le module RSI
input int    InpRSI_Period            = 14;       // Période du RSI
input double InpRSI_Overbought        = 80.0;     // Seuil de surachat pour signal
input double InpRSI_Oversold          = 20.0;     // Seuil de survente pour signal

input group "--- MODULE: SUPPORT & RESISTANCE (Fractals) ---"
input bool   InpEnableSR              = true;     // Activer l'analyse S/R
input int    InpSR_FractalLookback    = 50;       // Périodes pour trouver les fractals S/R
input double InpSR_ProximityPoints    = 50;       // Proximité du prix au S/R (en points)

input group "--- MODULE: ORDER BLOCKS (OB) ---"
input bool   InpEnableOrderBlock      = true;     // Activer l'analyse Order Block
input int    InpOB_Lookback           = 50;       // Périodes pour trouver les OB

input group "--- MODULE: OTE / FIBONACCI ---"
input bool   InpEnableOTE             = true;     // Activer l'analyse OTE/Fibo
input int    InpOTE_SwingLookback     = 100;      // Périodes pour trouver le swing
input double InpOTE_MinLevel          = 0.618;    // Niveau Fibo OTE Min
input double InpOTE_MaxLevel          = 0.786;    // Niveau Fibo OTE Max

input group "--- MODULE: MARKET STRUCTURE (BOS/CHoCH) ---"
input bool   InpEnableBOS_CHoCH       = true;     // Activer l'analyse BOS/CHoCH
input int    InpStructure_Lookback    = 120;      // Périodes pour analyse de structure

input group "=== FILTRES & TIMING ==="
input int    InpSlippagePoints        = 50;       // Slippage maximum (en points)
input int    InpMaxSpreadPoints       = 15000;    // Spread max autorisé (en points)
input int    InpMinSecondsBetweenTrades = 60;     // Temps d'attente entre deux trades (secondes)

input group "=== AFFICHAGE & NOTIFICATIONS ==="
input bool   InpShowSignalArrows      = true;     // Afficher les flèches de signal
input bool   InpShowHUD               = true;     // Afficher le HUD d'informations
input bool   InpSendNotifications     = true;     // Envoyer notification push
input bool   InpAlertPopup            = false;    // Alerte popup locale

input group "=== DEBUG ==="
input bool   InpDebug                 = true;     // Activer les logs de diagnostic

//--- Variables Globales
CTrade      trade;
CPositionInfo posInfo;
string      g_allowedSymbolsArray[];
datetime    g_lastTradeTime = 0;
string      g_hudStatus = "Initialisation...";

//--- Handles d'indicateurs
int         g_rsiHandle = INVALID_HANDLE;
int         g_fractalsHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Initialisation                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 Initialisation de AngelOfSpike v4.0...");

    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        Print("❌ ERREUR: Le trading automatique n'est pas activé !");
        return(INIT_FAILED);
    }
    
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetSlippage(InpSlippagePoints);
    trade.SetTypeFillingBySymbol(Symbol());
    
    StringSplit(InpAllowedSymbols, ',', g_allowedSymbolsArray);
    Print("📈 Symboles surveillés : ", InpAllowedSymbols);
    
    InitializeIndicators(Symbol());
    if(InpShowHUD) UpdateHUD();
    
    EventSetTimer(5); // Timer pour tâches de fond
    
    Print("✅ AngelOfSpike v4.0 initialisé et prêt.");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| D-Initialisation                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("🛑 Arrêt de AngelOfSpike v4.0. Nettoyage...");
    EventKillTimer();
    ReleaseIndicators();
    ObjectsDeleteAll(0, "SignalArrow_");
    if(InpShowHUD) ObjectDelete(0,"AngelOfSpikeHUD");
    Print("🧹 Nettoyage terminé.");
}

//+------------------------------------------------------------------+
//| Logique Principale à chaque Tick                                 |
//+------------------------------------------------------------------+
void OnTick()
{
    // --- 1. Gestion des positions OUVERTES ---
    ManageOpenPositions();
    
    // --- 2. Vérifications pour ouvrir un NOUVEAU trade ---
    if(!InpEnableTrading) return;
    if(TimeCurrent() - g_lastTradeTime < InpMinSecondsBetweenTrades) return;
    if(CountOpenTrades() >= InpMaxConcurrentTrades)
    {
        g_hudStatus = "Limite de trades atteinte.";
        return;
    }
    
    // --- 3. Boucle sur les symboles pour trouver un signal ---
    for(int i = 0; i < ArraySize(g_allowedSymbolsArray); i++)
    {
        string symbol = g_allowedSymbolsArray[i];
        if(!SymbolSelect(symbol, true) || IsPositionOpenForSymbol(symbol)) continue;

        g_hudStatus = "Analyse de " + symbol + "...";
        int tradeDirection = AnalyzeConfluenceStrategy(symbol);
        
        if(tradeDirection != 0) // Un signal de trading a été trouvé !
        {
            g_hudStatus = "Signal trouvé! Exécution...";
            ExecuteTrade(symbol, tradeDirection);
            break; 
        }
    }
    g_hudStatus = "En attente de signal...";
}

//+------------------------------------------------------------------+
//| Tâches de fond (toutes les 5 secondes)                           |
//+------------------------------------------------------------------+
void OnTimer()
{
    if(InpShowHUD) UpdateHUD();
}

//+------------------------------------------------------------------+
//| --- Section GESTION DES TRADES OUVERTS ---                      |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
    MqlRates rates[2];

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(!posInfo.SelectByIndex(i) || posInfo.Magic() != InpMagicNumber) continue;
        
        string symbol = posInfo.Symbol();
        
        // Logique de sortie 1: Atteinte de la perte maximale
        if(posInfo.Profit() <= -InpMaxLossPerTradeUSD)
        {
            Print("🚨 SL en USD atteint pour ", symbol, ". Fermeture forcée.");
            trade.PositionClose(posInfo.Ticket());
            continue;
        }

        // Logique de sortie 2: Fermeture après le spike
        // On ne cherche à fermer que si le trade est en gain
        if(posInfo.Profit() > 0.10) // Petit buffer de profit
        {
            if(CopyRates(symbol, PERIOD_M1, 0, 2, rates) < 2) continue;
            
            bool lastCandleWasSpike = false;
            bool currentCandleIsRetracement = false;
            
            if(posInfo.PositionType() == POSITION_TYPE_BUY) // Pour un Achat (sur Boom)
            {
                // La bougie précédente était une forte hausse (bougie verte)
                if(rates[1].close > rates[1].open) lastCandleWasSpike = true;
                // La bougie actuelle est en train de baisser (bougie rouge)
                if(rates[0].close < rates[0].open) currentCandleIsRetracement = true;
            }
            else // Pour une Vente (sur Crash)
            {
                // La bougie précédente était une forte baisse (bougie rouge)
                if(rates[1].close < rates[1].open) lastCandleWasSpike = true;
                // La bougie actuelle est en train de monter (bougie verte)
                if(rates[0].close > rates[0].open) currentCandleIsRetracement = true;
            }
            
            // Si le spike est suivi d'un retracement, on ferme pour prendre les profits
            if(lastCandleWasSpike && currentCandleIsRetracement)
            {
                string message = StringFormat("🎯 Spike terminé pour %s. Prise de profit à $%.2f", symbol, posInfo.Profit());
                Print(message);
                SendCustomNotification(message);
                trade.PositionClose(posInfo.Ticket());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| --- Section ANALYSE & STRATÉGIE (ENTRÉE) ---                   |
//+------------------------------------------------------------------+
int AnalyzeConfluenceStrategy(const string symbol)
{
    if(!InpEnableConfluence) return 0;
    InitializeIndicators(symbol);

    int buySignals = 0, sellSignals = 0;
    string log = "Confluence " + symbol + ":";

    if(InpEnableRSI)            { int s = AnalyzeRSI(symbol);              if(s==1) buySignals++;  if(s==-1) sellSignals++; log += (s!=0)?" [RSI]":""; }
    if(InpEnableSR)             { int s = AnalyzeSupportResistance(symbol); if(s==1) buySignals++;  if(s==-1) sellSignals++; log += (s!=0)?" [S/R]":""; }
    if(InpEnableOrderBlock)     { int s = AnalyzeOrderBlock(symbol);        if(s==1) buySignals++;  if(s==-1) sellSignals++; log += (s!=0)?" [OB]":""; }
    if(InpEnableOTE)            { int s = AnalyzeOTE_FIBO(symbol);          if(s==1) buySignals++;  if(s==-1) sellSignals++; log += (s!=0)?" [OTE]":""; }
    if(InpEnableBOS_CHoCH)      { int s = AnalyzeBOS_CHoCH(symbol);         if(s==1) buySignals++;  if(s==-1) sellSignals++; log += (s!=0)?" [STRUCT]":""; }

    if(buySignals >= InpMinConfluenceSignals && sellSignals == 0)
    {
        if(InpDebug) Print("📈 ", log, " -> Signal d'ACHAT (", IntegerToString(buySignals), " confluences)");
        return 1;
    }
    if(sellSignals >= InpMinConfluenceSignals && buySignals == 0)
    {
        if(InpDebug) Print("📉 ", log, " -> Signal de VENTE (", IntegerToString(sellSignals), " confluences)");
        return -1;
    }
    return 0;
}

int AnalyzeRSI(const string symbol)
{
    if(g_rsiHandle == INVALID_HANDLE) return 0;
    double rsi[2];
    if(CopyBuffer(g_rsiHandle, 0, 0, 2, rsi) < 2) return 0;
    if(rsi[1] > InpRSI_Oversold && rsi[0] < InpRSI_Oversold) return 1; // Croisement de la zone de survente vers le haut
    if(rsi[1] < InpRSI_Overbought && rsi[0] > InpRSI_Overbought) return -1; // Croisement de la zone de surachat vers le bas
    return 0;
}

int AnalyzeSupportResistance(const string symbol)
{
    if(g_fractalsHandle == INVALID_HANDLE) return 0;
    double upFractals[5], downFractals[5];
    if(CopyBuffer(g_fractalsHandle, 0, 0, 5, upFractals) < 5 || CopyBuffer(g_fractalsHandle, 1, 0, 5, downFractals) < 5) return 0;

    double resistance = 0, support = 0;
    for(int i = 1; i < 5; i++) { if(upFractals[i] > 0) { resistance = upFractals[i]; break; } }
    for(int i = 1; i < 5; i++) { if(downFractals[i] > 0) { support = downFractals[i]; break; } }

    if(resistance == 0 || support == 0) return 0;

    double proximity = InpSR_ProximityPoints * SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(MathAbs(SymbolInfoDouble(symbol, SYMBOL_ASK) - support) <= proximity) return 1;
    if(MathAbs(SymbolInfoDouble(symbol, SYMBOL_BID) - resistance) <= proximity) return -1;
    return 0;
}

int AnalyzeOrderBlock(const string symbol)
{
    MqlRates rates[];
    if(CopyRates(symbol, PERIOD_M1, 0, InpOB_Lookback, rates) < InpOB_Lookback) return 0;
    for(int i = InpOB_Lookback - 2; i > 1; i--)
    {
        if(rates[i].close < rates[i].open && rates[i-1].close > rates[i].high)
            if(SymbolInfoDouble(symbol, SYMBOL_ASK) <= rates[i].high && SymbolInfoDouble(symbol, SYMBOL_ASK) >= rates[i].low) return 1;
        if(rates[i].close > rates[i].open && rates[i-1].close < rates[i].low)
            if(SymbolInfoDouble(symbol, SYMBOL_BID) <= rates[i].high && SymbolInfoDouble(symbol, SYMBOL_BID) >= rates[i].low) return -1;
    }
    return 0;
}

int AnalyzeOTE_FIBO(const string symbol)
{
    MqlRates rates[];
    if(CopyRates(symbol, PERIOD_M1, 0, InpOTE_SwingLookback, rates) < InpOTE_SwingLookback) return 0;
    double swingHigh = 0, swingLow = 1e9;
    int highIndex = -1, lowIndex = -1;
    for(int i=0; i<InpOTE_SwingLookback; i++)
    {
        if(rates[i].high > swingHigh) { swingHigh = rates[i].high; highIndex = i; }
        if(rates[i].low < swingLow) { swingLow = rates[i].low; lowIndex = i; }
    }
    if(highIndex == -1 || lowIndex == -1) return 0;
    double range = swingHigh - swingLow;
    if(range == 0) return 0;
    
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);

    if(lowIndex > highIndex) // Tendance haussière
    {
        double oteMin = swingHigh - range * InpOTE_MaxLevel;
        double oteMax = swingHigh - range * InpOTE_MinLevel;
        if(price >= oteMin && price <= oteMax) return 1;
    }
    else // Tendance baissière
    {
        double oteMin = swingLow + range * InpOTE_MinLevel;
        double oteMax = swingLow + range * InpOTE_MaxLevel;
        if(price >= oteMin && price <= oteMax) return -1;
    }
    return 0;
}

int AnalyzeBOS_CHoCH(const string symbol)
{
    MqlRates rates[5];
    if(CopyRates(symbol, PERIOD_M1, 0, 5, rates) < 5) return 0;
    if(rates[3].low < rates[4].low && rates[2].low < rates[3].low && rates[0].high > rates[2].high) return 1;
    if(rates[3].high > rates[4].high && rates[2].high > rates[3].high && rates[0].low < rates[2].low) return -1;
    return 0;
}

//+------------------------------------------------------------------+
//| --- Section EXÉCUTION & UTILITAIRES ---                        |
//+------------------------------------------------------------------+
void ExecuteTrade(const string symbol, const int direction)
{
    double spread_points = (SymbolInfoDouble(symbol, SYMBOL_ASK) - SymbolInfoDouble(symbol, SYMBOL_BID)) / SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(spread_points > InpMaxSpreadPoints)
    {
        if(InpDebug) Print("❌ TRADE ANNULÉ [", symbol, "]: Spread trop élevé (", IntegerToString((int)spread_points), " points).");
        return;
    }
    
    double entry_price = (direction == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
    double sl_price = 0;
    if(!CalculateSL(symbol, direction, entry_price, sl_price))
    {
        if(InpDebug) Print("❌ TRADE ANNULÉ [", symbol, "]: Impossible de calculer un SL valide.");
        return;
    }

    string trade_type = (direction == 1) ? "BUY" : "SELL";
    if(InpDebug) Print("📬 Envoi de l'ordre ", trade_type, " pour ", symbol, " @ ", NormalizeDouble(entry_price, 5), " SL:", NormalizeDouble(sl_price, 5), " TP: OUVERT");

    bool result = false;
    if(direction == 1)
        result = trade.Buy(InpLotSize, symbol, entry_price, sl_price, 0.0, "AngelOfSpike BUY");
    else
        result = trade.Sell(InpLotSize, symbol, entry_price, sl_price, 0.0, "AngelOfSpike SELL");

    if(result)
    {
        g_lastTradeTime = TimeCurrent();
        if(InpShowSignalArrows) ShowSignalArrow(symbol, direction);
        string message = StringFormat("✅ %s %s @ %.4f", trade_type, symbol, entry_price);
        SendCustomNotification(message);
        Print(message);
    }
    else
    {
        Print("🔥 ÉCHEC TRADE ", trade_type, " ", symbol, ". Erreur: ", trade.ResultRetcode(), " - ", trade.ResultComment());
    }
}

bool CalculateSL(const string symbol, const int direction, const double entry_price, double &sl_price)
{
    double tick_value = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
    double tick_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
    
    if(tick_value <= 0 || tick_size <= 0)
    {
        Print("⚠️ Valeur du tick non disponible pour ", symbol, ". Impossible de calculer le SL en USD.");
        return false;
    }

    double sl_distance_in_price = (InpMaxLossPerTradeUSD / InpLotSize) * (tick_size / tick_value);
    sl_price = (direction == 1) ? entry_price - sl_distance_in_price : entry_price + sl_distance_in_price;

    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    sl_price = NormalizeDouble(sl_price, digits);
    
    double stops_level = (double)SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble(symbol, SYMBOL_POINT);
    if(MathAbs(entry_price - sl_price) < stops_level)
    {
        if(InpDebug) Print("Ajustement SL: trop proche du prix. Niveau min: ", stops_level);
        sl_price = (direction == 1) ? entry_price - stops_level : entry_price + stops_level;
    }
    return true;
}

void InitializeIndicators(const string symbol)
{
    static string s_current_symbol = "";
    if(symbol == s_current_symbol) return;
    ReleaseIndicators();
    g_rsiHandle = iRSI(symbol, PERIOD_M1, InpRSI_Period, PRICE_CLOSE);
    g_fractalsHandle = iFractals(symbol, PERIOD_M1);
    if(g_rsiHandle==INVALID_HANDLE || g_fractalsHandle==INVALID_HANDLE) 
        Print("❌ Erreur init indicateurs pour ", symbol);
    s_current_symbol = symbol;
}

void ReleaseIndicators()
{
    if(g_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_rsiHandle);
    if(g_fractalsHandle != INVALID_HANDLE) IndicatorRelease(g_fractalsHandle);
    g_rsiHandle = INVALID_HANDLE;
    g_fractalsHandle = INVALID_HANDLE;
}

int CountOpenTrades()
{
    int count = 0;
    for(int i = PositionsTotal() - 1; i >= 0; i--)
        if(posInfo.SelectByIndex(i) && posInfo.Magic() == InpMagicNumber)
            count++;
    return count;
}

bool IsPositionOpenForSymbol(const string symbol)
{
    return PositionSelect(symbol);
}

void ShowSignalArrow(const string symbol, const int direction)
{
    string name = "SignalArrow_" + symbol + "_" + TimeToString(TimeCurrent());
    double price = (direction == 1) ? SymbolInfoDouble(symbol, SYMBOL_BID) : SymbolInfoDouble(symbol, SYMBOL_ASK);
    double offset = SymbolInfoDouble(symbol, SYMBOL_POINT) * 200;
    ObjectCreate(0, name, OBJ_ARROW, 0, TimeCurrent(), (direction == 1) ? price - offset : price + offset);
    ObjectSetInteger(0, name, OBJPROP_ARROWCODE, (direction == 1) ? 233 : 234);
    ObjectSetInteger(0, name, OBJPROP_COLOR, (direction == 1) ? clrDodgerBlue : clrOrangeRed);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    ChartRedraw();
}

void UpdateHUD()
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE), equity = AccountInfoDouble(ACCOUNT_EQUITY);
    int open_trades = CountOpenTrades();
    double floating_pl = equity - balance;

    string hudText = StringFormat(
        "--- AngelOfSpike v4.0 ---\n"
        "Statut: %s\n"
        "Trading: %s\n"
        "Solde: %.2f | P/L: %.2f\n"
        "Trades Actifs: %d / %d",
        g_hudStatus,
        InpEnableTrading ? "✅ ACTIVÉ" : "❌ INACTIF",
        balance, floating_pl, open_trades, InpMaxConcurrentTrades
    );
    
    if(ObjectFind(0, "AngelOfSpikeHUD") < 0)
    {
        ObjectCreate(0, "AngelOfSpikeHUD", OBJ_LABEL, 0, 10, 20);
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_COLOR, clrWhite);
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_FONTSIZE, 10);
        ObjectSetString(0, "AngelOfSpikeHUD", OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, "AngelOfSpikeHUD", OBJPROP_BACK, false);
    }
    ObjectSetString(0, "AngelOfSpikeHUD", OBJPROP_TEXT, hudText);
}

void SendCustomNotification(string message)
{
    if(InpSendNotifications) SendNotification(message);
    if(InpAlertPopup) Alert(message);
}
//+------------------------------------------------------------------+
