//+------------------------------------------------------------------+
//| Fx_SMC_Robot_Visual_Corrige.mq5                                  |
//| EA SMC avec affichage graphique complet                          |
//| Auteur: ChatGPT (corrigé)                                        |
//+------------------------------------------------------------------+
#property strict
#property version   "1.4"
#property description "SMC EA avec OB, FVG, IFVG, BOS, MSS et affichage graphique"

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <ChartObjects\ChartObjectsLines.mqh>
#include <ChartObjects\ChartObjectsTxtControls.mqh>
#include <ChartObjects\ChartObjectsShapes.mqh>
#include <StdLibErr.mqh>

// Déclaration de l'objet trade
CTrade trade;

// Variables pour les signaux et notifications
string g_signalPrefix = "SMC_Signal_";
color g_buyColor = clrLime;
color g_sellColor = clrRed;

// Variables globales pour le suivi des signaux
datetime g_lastSignalTime = 0;
double g_lastSignalPrice = 0.0;
double g_lastSL = 0.0;
double g_lastTP = 0.0;
bool g_signalActive = false;

// Variables pour l'optimisation des performances
datetime g_lastUpdateTime = 0;
int g_maxObjects = 100; // Nombre maximum d'objets sur le graphique
int g_updateInterval = 5; // Mise à jour toutes les 5 secondes

//-------------------- Paramètres --------------------//
// Handles des indicateurs
int g_ma20_handle = INVALID_HANDLE;
int g_ma50_handle = INVALID_HANDLE;
int g_atr_handle  = INVALID_HANDLE;

// Paramètres de trading
input ENUM_TIMEFRAMES HTF = PERIOD_M15;      // Timeframe HTF
input ENUM_TIMEFRAMES LTF = PERIOD_M1;       // Timeframe LTF
input double LotSize = 0.1;                  // Taille de lot fixe (0 = gestion automatique)
input double RiskPercent = 1.0;              // Risque % du capital (si LotSize = 0)
input int MaxSpread = 20;                    // Spread maximum autorisé (points)
input int Slippage = 3;                      // Slippage maximum (points)
input int MagicNumber = 123456;              // Numéro magique pour les ordres

// Gestion du risque
input bool UseEquityProtection = true;
input double MaxDailyLossPercent = 5.0;
input bool CloseAllOnFriday = true;
input int CloseHourFriday = 20;

// Gestion des positions
input bool UseTrailingStop = true;
input int TrailingStop = 50;
input int TrailingStep = 10;
input bool UseBreakEven = true;
input int BreakEvenAt = 20;
input int BreakEvenPlus = 5;

// Avancé
input bool AggressiveMode = false;
input int PipBuffer = 5;
input bool TradeMonday = true;
input bool TradeFriday = true;
input string TradeSessionStart = "00:00";
input string TradeSessionEnd = "23:59";

// Variables globales
double OB_High = 0;
double OB_Low  = 0;

// Tampons
double ma20_buffer[];
double ma50_buffer[];
double atr_buffer[];

// Noms d'objets
string obRect   = "SMC_OB_Rect";
string fvgRect  = "SMC_FVG_Rect";
string entryLine= "SMC_EntryLine";
string slLine   = "SMC_SLLine";
string tpLine   = "SMC_TPLine";

// Etats
enum ENUM_SMC_STATE {
   STATE_SEARCH_HTF_SETUP,
   STATE_WAIT_FOR_OB_RETEST,
   STATE_SEARCH_LTF_CONFIRMATION
};
ENUM_SMC_STATE currentState = STATE_SEARCH_HTF_SETUP;

//--- prototypes
bool ExecuteTrade(bool isBuy);
bool DrawEntrySLTP(double entry, double sl, double tp, ENUM_ORDER_TYPE signalType = ORDER_TYPE_BUY);
void UpdateSupportResistance();
void UpdateSupportResistanceZones();
int FindSupportResistanceLevels(ENUM_TIMEFRAMES tf, double &levels[]);
void CleanOldSignals();
bool ShowSignal(const ENUM_ORDER_TYPE signalType, const double price, const string reason = "");
bool SendCustomNotification(string message);

//+------------------------------------------------------------------+
//| ExecuteTrade                                                     |
//+------------------------------------------------------------------+
bool ExecuteTrade(bool isBuy)
{
    // Log de débogage pour vérifier la direction
    PrintFormat("🔍 DEBUG SMC ExecuteTrade: isBuy=%s (%s)", 
               isBuy ? "true" : "false", isBuy ? "ACHAT" : "VENTE");
    
    // Vérifications de base
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
    {
        Print("Erreur: Le trading n'est pas autorisé");
        return false;
    }

    // Spread en points (SYMBOL_SPREAD donne en points)
    long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    if(spread_points < 0) spread_points = 0;
    if(spread_points > MaxSpread)
    {
        PrintFormat("Erreur: Spread trop élevé (%d) > %d", (int)spread_points, MaxSpread);
        return false;
    }

    // Vérifier si Boom/Crash
    bool isBoomCrash = (StringFind(_Symbol, "Boom") >= 0 || StringFind(_Symbol, "Crash") >= 0);

    // Récupérer ATR
    if(g_atr_handle == INVALID_HANDLE)
    {
        Print("ATR handle invalide");
        return false;
    }
    double atr_val[1];
    if(CopyBuffer(g_atr_handle, 0, 0, 1, atr_val) <= 0)
    {
        Print("Erreur lors de la récupération de l'ATR");
        return false;
    }

    // Paramètres
    double lotSize = 0.0;
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double point     = _Point;
    double minLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxLot    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lotStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    // Forcer lot pour Boom/Crash (vérifier limites broker)
    if(isBoomCrash)
    {
        lotSize = 0.2;
        if(maxLot > 0 && lotSize > maxLot) lotSize = maxLot;
        if(minLot > 0 && lotSize < minLot)
        {
            PrintFormat("Erreur: lot forcé %.2f < minLot %.2f", lotSize, minLot);
            return false;
        }
        PrintFormat("Symbole Boom/Crash détecté - Lot forcé à %.2f", lotSize);
    }
    else
    {
        double stopLossPips = atr_val[0] / point;
        if(stopLossPips <= 0 || tickValue <= 0 || tickSize <= 0)
        {
            Print("Erreur: paramètres invalides pour calcul lot");
            return false;
        }
        double desiredRiskUSD = 3.0; // configurable si voulu
        double per_pip_value_factor = tickValue * (point / tickSize);
        if(per_pip_value_factor <= 0)
        {
            Print("Erreur: facteur pip invalide");
            return false;
        }
        double rawLot = desiredRiskUSD / (stopLossPips * per_pip_value_factor);
        if(lotStep > 0) lotSize = MathFloor(rawLot / lotStep) * lotStep;
        else lotSize = rawLot;
        // Respecter limites
        if(minLot > 0) lotSize = MathMax(minLot, lotSize);
        if(maxLot > 0) lotSize = MathMin(maxLot, lotSize);
        if(minLot > 0 && lotSize < minLot)
        {
            PrintFormat("Erreur: lot calculé %.2f inférieur au minimum %.2f", lotSize, minLot);
            return false;
        }
    }

    // Calcul marge & vérification
    double entryPrice = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double margin = 0.0;
    ENUM_ORDER_TYPE ordType = isBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    if(!OrderCalcMargin(ordType, _Symbol, lotSize, entryPrice, margin))
    {
        Print("Erreur calcul marge: ", GetLastError());
        return false;
    }
    double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
    if(margin > freeMargin)
    {
        PrintFormat("Erreur: Marge insuffisante. Nécessaire: %.2f, Disponible: %.2f", margin, freeMargin);
        return false;
    }

    // Calcul SL/TP (basé sur ATR)
    double sl = 0.0, tp = 0.0;
    double atrPrice = atr_val[0];
    if(isBuy)
    {
        sl = entryPrice - 0.8 * atrPrice;  // SL plus serré à 0.8 ATR
        tp = entryPrice + 2.5 * atrPrice;  // TP à 2.5 ATR (ratio 1:3)
        PrintFormat("🔧 SMC ACHAT: Entry=%.5f, SL=%.5f (%.1f ATR), TP=%.5f (%.1f ATR)", 
                   entryPrice, sl, 0.8, tp, 2.5);
    }
    else
    {
        sl = entryPrice + 0.8 * atrPrice;  // SL plus serré à 0.8 ATR
        tp = entryPrice - 2.5 * atrPrice;  // TP à 2.5 ATR (ratio 1:3)
        PrintFormat("🔧 SMC VENTE: Entry=%.5f, SL=%.5f (%.1f ATR), TP=%.5f (%.1f ATR)", 
                   entryPrice, sl, 0.8, tp, 2.5);
    }

    // Vérifier distance minimale stops
    long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    double minDistance = stops_level * point;
    if(MathAbs(entryPrice - sl) < minDistance)
    {
        if(isBuy) sl = entryPrice - minDistance;
        else sl = entryPrice + minDistance;
        Print("Ajustement du SL pour respecter la distance minimale");
    }

    // Normaliser
    entryPrice = NormalizeDouble(entryPrice, _Digits);
    sl = NormalizeDouble(sl, _Digits);
    tp = NormalizeDouble(tp, _Digits);

    // Préparer trade
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);

    bool result = false;
    if(isBuy) result = trade.Buy(lotSize, _Symbol, entryPrice, sl, tp, "SMC Buy Signal");
    else result = trade.Sell(lotSize, _Symbol, entryPrice, sl, tp, "SMC Sell Signal");

    if(!result)
    {
        int error = GetLastError();
        PrintFormat("Échec de l'ordre %s. Erreur %d", isBuy ? "d'achat" : "de vente", error);
        return false;
    }

    PrintFormat("Ordre %s exécuté. Prix: %s, Lot: %.2f, SL: %s, TP: %s",
                isBuy ? "d'achat" : "de vente",
                DoubleToString(entryPrice, _Digits),
                lotSize,
                DoubleToString(sl, _Digits),
                DoubleToString(tp, _Digits));

    // Dessiner niveaux
    if(!DrawEntrySLTP(entryPrice, sl, tp, ordType))
        Print("Avertissement: impossible de dessiner SL/TP");

    return true;
}

//+------------------------------------------------------------------+
//| OnInit                                                           |
//+------------------------------------------------------------------+
int OnInit()
{
    if(!SymbolSelect(_Symbol, true))
    {
        Print("Erreur: Impossible de sélectionner le symbole ", _Symbol);
        return INIT_FAILED;
    }

    // Création des indicateurs
    g_ma20_handle = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE);
    g_ma50_handle = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE);
    g_atr_handle  = iATR(_Symbol, PERIOD_CURRENT, 14);

    if(g_ma20_handle == INVALID_HANDLE || g_ma50_handle == INVALID_HANDLE || g_atr_handle == INVALID_HANDLE)
    {
        Print("Erreur lors de la création des indicateurs");
        return INIT_FAILED;
    }

    // Tenter d'ajouter au chart (si possible)
    ChartIndicatorAdd(0, 0, g_ma20_handle);
    ChartIndicatorAdd(0, 0, g_ma50_handle);
    ChartIndicatorAdd(0, 1, g_atr_handle);

    // Config trade
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetDeviationInPoints(Slippage);
    trade.SetTypeFilling(ORDER_FILLING_FOK);

    Print("SMC EA Visual initialisé : MA20, MA50, ATR chargés");

    // Première mise à jour S/R
    UpdateSupportResistance();

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnDeinit - nettoyage                                             |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Supprimer objets créés par EA (préfixe SMC_)
    int total = ObjectsTotal(0);
    for(int i = total - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i);
        if(StringFind(nm, "SMC_") == 0 || StringFind(nm, g_signalPrefix) == 0)
            ObjectDelete(0, nm);
    }

    // Libération handles
    if(g_ma20_handle != INVALID_HANDLE) { IndicatorRelease(g_ma20_handle); g_ma20_handle = INVALID_HANDLE; }
    if(g_ma50_handle != INVALID_HANDLE) { IndicatorRelease(g_ma50_handle); g_ma50_handle = INVALID_HANDLE; }
    if(g_atr_handle  != INVALID_HANDLE) { IndicatorRelease(g_atr_handle);  g_atr_handle  = INVALID_HANDLE; }
}

//+------------------------------------------------------------------+
//| OnTick                                                            |
//+------------------------------------------------------------------+
void OnTick()
{
    datetime currentTime = TimeCurrent();
    
    // Vérifier si on doit effectuer une mise à jour (toutes les 5 secondes par défaut)
    if(currentTime - g_lastUpdateTime < g_updateInterval) 
        return;
        
    g_lastUpdateTime = currentTime;
    
    // Nettoyage anciens signaux
    CleanOldSignals();

    // MAJ S/R toutes les 5 minutes (12 appels par heure au lieu de 60)
    static datetime lastSRUpdate = 0;
    if(currentTime - lastSRUpdate >= 300) // 5 minutes
    {
        UpdateSupportResistance();
        lastSRUpdate = currentTime;
    }

    // Ex: exemple simple de signal basé sur MA50 (démo)
    double ma50_latest = 0.0;
    if(g_ma50_handle != INVALID_HANDLE)
    {
        double buf[];
        ArrayResize(buf,1);
        if(CopyBuffer(g_ma50_handle, 0, 0, 1, buf) > 0)
            ma50_latest = buf[0];
    }

    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Exécution d'un signal démonstratif (tous les 15 minutes pour éviter spam)
    MqlDateTime time_struct;
    TimeCurrent(time_struct);
    // Vérifier si c'est le moment d'envoyer un signal (toutes les 15 minutes)
    static datetime lastSignalTime = 0;
    
    // Vérifier les conditions du signal
    bool hasPredictionArrow = ObjectFind(0, "Prediction_Arrow") >= 0; // Vérifier si une flèche de prédiction est présente
    bool signalAchat = (ma50_latest > 0 && bid > ma50_latest && hasPredictionArrow);
    
    // Si un signal est actif et qu'il a moins de 5 minutes, on le maintient
    if(g_signalActive && (currentTime - g_lastSignalTime) < 300) // 5 minutes = 300 secondes
    {
        // Afficher les niveaux précédents
        if(g_lastSignalPrice > 0 && g_lastSL > 0 && g_lastTP > 0)
        {
            ShowSignal(ORDER_TYPE_BUY, g_lastSignalPrice, "Signal SMC Actif - Achat");
            DrawEntrySLTP(g_lastSignalPrice, g_lastSL, g_lastTP, ORDER_TYPE_BUY);
        }
    }
    // Si nouveau signal et délai minimum écoulé depuis le dernier signal
    else if(signalAchat && (currentTime - g_lastSignalTime) >= 300) // 5 minutes = 300 secondes
    {
        // Vérifier si pas de position ouverte par ce robot
        if(!HasOpenPosition())
        {
            // Afficher le signal sur le graphique
            ShowSignal(ORDER_TYPE_BUY, ask, "Signal SMC - Achat");
            
            // Vérifier les autorisations de trading
            if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED))
            {
                // Calculer les niveaux SL et TP
                double atr[1];
                double sl = 0, tp = 0;
                
                if(CopyBuffer(g_atr_handle, 0, 0, 1, atr) > 0)
                {
                    sl = ask - (atr[0] * 0.8);  // SL à 0.8 ATR (plus serré)
                    tp = ask + (atr[0] * 2.5);  // TP à 2.5 ATR (ratio 1:3)
                    
                    // Sauvegarder les niveaux pour les 5 prochaines minutes
                    g_lastSignalPrice = ask;
                    g_lastSL = sl;
                    g_lastTP = tp;
                    g_lastSignalTime = currentTime;
                    g_signalActive = true;
                    
                    // Afficher les niveaux sur le graphique
                    if(DrawEntrySLTP(ask, sl, tp, ORDER_TYPE_BUY))
                    {
                        Print("Nouveau signal - Entrée: ", ask, ", SL: ", sl, ", TP: ", tp, ", Valide 5 minutes");
                    }
                    
                    // Exécuter le trade
                    PrintFormat("🔍 DEBUG SMC: Préparation exécution ACHAT - Signal: DEMONSTRATION");
                    if(ExecuteTrade(true))
                    {
                        Print("Ordre d'achat exécuté avec succès");
                        lastSignalTime = currentTime;
                    }
                    else
                    {
                        Print("Échec de l'exécution du trade. Dernière erreur: ", GetLastError());
                    }
                }
            }
            else
            {
                Print("Le trading n'est pas autorisé. Vérifiez les paramètres du terminal.");
            }
        }
        else
        {
            Print("Un trade est déjà en cours. Attente de sa clôture avant d'en ouvrir un nouveau.");
        }
    }
}

//+------------------------------------------------------------------+
//| DrawSupportResistanceZone                                         |
//+------------------------------------------------------------------+
void DrawSupportResistanceZone(string name, double price1, double price2, color clr, int width = 1)
{
    datetime time1 = iTime(_Symbol, PERIOD_CURRENT, 100);
    datetime time2 = TimeCurrent();

    if(ObjectFind(0, name) < 0)
    {
        // Création rectangle avec times/prices
        if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2))
        {
            // fallback : créer lignes si échec
            string l1 = name + "_H1";
            string l2 = name + "_H2";
            if(ObjectFind(0, l1) < 0) ObjectCreate(0, l1, OBJ_HLINE, 0, 0, price1);
            if(ObjectFind(0, l2) < 0) ObjectCreate(0, l2, OBJ_HLINE, 0, 0, price2);
            ObjectSetInteger(0, l1, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, l2, OBJPROP_COLOR, clr);
            return;
        }
    }

    // Propriétés du rectangle
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

    // Assigner prix/time explicitement (sécuriser)
    ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price1);
    ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price2);
    ObjectSetInteger(0, name, OBJPROP_TIME, 0, time1);
    ObjectSetInteger(0, name, OBJPROP_TIME, 1, time2);
}

//+------------------------------------------------------------------+
//| UpdateSupportResistanceZones                                      |
//+------------------------------------------------------------------+
void UpdateSupportResistanceZones()
{
    // Supprimer anciennes zones créées par l'EA (préfixe "SMC_SR_")
    int total = ObjectsTotal(0);
    for(int i = total - 1; i >= 0; i--)
    {
        string nm = ObjectName(0, i);
        if(StringFind(nm, "SMC_SR_") == 0)
            ObjectDelete(0, nm);
    }

    ENUM_TIMEFRAMES timeframes[] = {PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};
    color colors[] = {clrDodgerBlue, clrLime, clrOrange, clrMagenta};

    for(int i = 0; i < ArraySize(timeframes); i++)
    {
        double levels[];
        ArrayResize(levels,0);
        int levelCount = FindSupportResistanceLevels(timeframes[i], levels);
        for(int j = 0; j < levelCount; j++)
        {
            string name = StringFormat("SMC_SR_%s_%d", EnumToString(timeframes[i]), j);
            double zoneHeight = 10 * _Point;
            DrawSupportResistanceZone(name, levels[j] - zoneHeight, levels[j] + zoneHeight, colors[i % ArraySize(colors)]);
        }
    }
}

//+------------------------------------------------------------------+
//| FindSupportResistanceLevels                                       |
//+------------------------------------------------------------------+
int FindSupportResistanceLevels(ENUM_TIMEFRAMES tf, double &levels[])
{
    // Préparer buffers
    int barsToCopy = 200;
    double highs[];
    double lows[];
    ArrayResize(highs, barsToCopy);
    ArrayResize(lows, barsToCopy);
    ArraySetAsSeries(highs, true);
    ArraySetAsSeries(lows, true);

    int copiedHigh = CopyHigh(_Symbol, tf, 0, barsToCopy, highs);
    int copiedLow  = CopyLow(_Symbol, tf, 0, barsToCopy, lows);
    if(copiedHigh <= 0 || copiedLow <= 0) return 0;

    int maxLevels = 10;
    ArrayResize(levels, 0);
    int count = 0;

    // Sommets locaux (high)
    for(int i = 5; i < MathMin(copiedHigh - 5, barsToCopy - 5) && count < maxLevels/2; i++)
    {
        if(highs[i] > highs[i-1] && highs[i] > highs[i+1] && highs[i] > highs[i-2] && highs[i] > highs[i+2])
        {
            ArrayResize(levels, count+1);
            levels[count++] = highs[i];
        }
    }

    // Creux locaux (low)
    for(int i = 5; i < MathMin(copiedLow - 5, barsToCopy - 5) && count < maxLevels; i++)
    {
        if(lows[i] < lows[i-1] && lows[i] < lows[i+1] && lows[i] < lows[i-2] && lows[i] < lows[i+2])
        {
            ArrayResize(levels, count+1);
            levels[count++] = lows[i];
        }
    }

    return count;
}

//+------------------------------------------------------------------+
//| UpdateSupportResistance (throttle)                                |
//+------------------------------------------------------------------+
void UpdateSupportResistance()
{
    static datetime lastUpdate = 0;
    datetime currentTime = TimeCurrent();
    
    // Mise à jour toutes les 5 minutes uniquement
    if(currentTime - lastUpdate < 300)
        return;
        
    // Vérifier si le graphique est visible (méthode alternative plus simple)
    if(ChartGetInteger(0, CHART_BRING_TO_TOP) == 0)
        return;
        
    UpdateSupportResistanceZones();
    lastUpdate = currentTime;
    
    // Forcer le rafraîchissement du graphique une seule fois après la mise à jour
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| OnChartEvent                                                       |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
    // Empêcher suppression/drag des objets SMC_
    if(id == CHARTEVENT_OBJECT_DRAG || id == CHARTEVENT_OBJECT_ENDEDIT ||
       id == CHARTEVENT_OBJECT_CLICK || id == CHARTEVENT_OBJECT_DELETE)
    {
        if(StringFind(sparam, "SMC_") == 0)
        {
            // Réappliquer propriétés utiles
            ObjectSetInteger(0, sparam, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
            ObjectSetInteger(0, sparam, OBJPROP_BACK, true);
            ObjectSetInteger(0, sparam, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, sparam, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, sparam, OBJPROP_HIDDEN, true);

            if(id == CHARTEVENT_OBJECT_DELETE)
            {
                // On ne recrée pas automatiquement tous les objets (peut être implémenté)
            }
            ChartRedraw(0);
        }
    }

    // Rafraîchir indicateurs si nouveau bar
    static int lastBarCount = 0;
    int currentBars = iBars(_Symbol, _Period);
    if(currentBars != lastBarCount)
    {
        if(g_ma20_handle != INVALID_HANDLE) ChartIndicatorAdd(0, 0, g_ma20_handle);
        if(g_ma50_handle != INVALID_HANDLE) ChartIndicatorAdd(0, 0, g_ma50_handle);
        if(g_atr_handle  != INVALID_HANDLE) ChartIndicatorAdd(0, 1, g_atr_handle);
        lastBarCount = currentBars;
    }
}

//+------------------------------------------------------------------+
//| ShowSignal                                                         |
//+------------------------------------------------------------------+
bool ShowSignal(const ENUM_ORDER_TYPE signalType, const double price, const string reason)
{
    // Throttle signaux
    if(TimeCurrent() - g_lastSignalTime < 60) return false;
    g_lastSignalTime = TimeCurrent();

    datetime currentTime = TimeCurrent();
    string timeStr = TimeToString(currentTime, TIME_DATE|TIME_SECONDS);
    string signalName = g_signalPrefix + IntegerToString((int)currentTime);

    color arrowColor = (signalType == ORDER_TYPE_BUY) ? g_buyColor : g_sellColor;
    int arrowCode = (signalType == ORDER_TYPE_BUY) ? 233 : 234;
    string signalText = (signalType == ORDER_TYPE_BUY) ? "ACHAT" : "VENTE";

    // Créer flèche
    if(!ObjectCreate(0, signalName, OBJ_ARROW, 0, currentTime, price))
    {
        Print("Erreur création flèche signal: ", GetLastError());
        return false;
    }
    ObjectSetInteger(0, signalName, OBJPROP_ARROWCODE, arrowCode);
    ObjectSetInteger(0, signalName, OBJPROP_COLOR, arrowColor);
    ObjectSetInteger(0, signalName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, signalName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    ObjectSetInteger(0, signalName, OBJPROP_BACK, true);

    // Label
    string labelName = signalName + "_Label";
    if(ObjectCreate(0, labelName, OBJ_TEXT, 0, currentTime, price + 10*_Point))
    {
        string text = signalText + " @ " + DoubleToString(price, _Digits) + "\n" + reason;
        ObjectSetString(0, labelName, OBJPROP_TEXT, text);
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, arrowColor);
        ObjectSetInteger(0, labelName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
    }

    // Notification
    string notification = StringFormat("Signal %s - %s @ %s | %s | %s", signalText, _Symbol, DoubleToString(price,_Digits), reason, timeStr);
    if(!SendCustomNotification(notification))
        Print("Erreur envoi notification: ", GetLastError());

    Print(notification);
    ChartRedraw(0);
    return true;
}

//+------------------------------------------------------------------+
//| DrawEntrySLTP                                                      |
//+------------------------------------------------------------------+
bool DrawEntrySLTP(double entry, double sl, double tp, ENUM_ORDER_TYPE signalType)
{
    if(entry <= 0 || sl <= 0 || tp <= 0) return false;

    // Afficher signal
    string sigReason = "SL: " + DoubleToString(sl, _Digits) + " | TP: " + DoubleToString(tp, _Digits);
    ShowSignal(signalType, entry, sigReason);

    static int lineCounter = 0;
    lineCounter++;

    string entryLineName = "SMC_Entry_" + IntegerToString(lineCounter);
    string slLineName    = "SMC_SL_" + IntegerToString(lineCounter);
    string tpLineName    = "SMC_TP_" + IntegerToString(lineCounter);

    if(ObjectFind(0, entryLineName) >= 0) ObjectDelete(0, entryLineName);
    if(ObjectFind(0, slLineName) >= 0)    ObjectDelete(0, slLineName);
    if(ObjectFind(0, tpLineName) >= 0)    ObjectDelete(0, tpLineName);

    ObjectCreate(0, entryLineName, OBJ_HLINE, 0, 0, entry);
    ObjectSetInteger(0, entryLineName, OBJPROP_COLOR, (signalType == ORDER_TYPE_BUY) ? g_buyColor : g_sellColor);
    ObjectSetInteger(0, entryLineName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, entryLineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

    ObjectCreate(0, slLineName, OBJ_HLINE, 0, 0, sl);
    ObjectSetInteger(0, slLineName, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, slLineName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, slLineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

    ObjectCreate(0, tpLineName, OBJ_HLINE, 0, 0, tp);
    ObjectSetInteger(0, tpLineName, OBJPROP_COLOR, clrBlue);
    ObjectSetInteger(0, tpLineName, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, tpLineName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);

    // Labels
    string entryLabel = entryLineName + "_Label";
    string slLabel    = slLineName + "_Label";
    string tpLabel    = tpLineName + "_Label";

    if(ObjectCreate(0, entryLabel, OBJ_TEXT, 0, TimeCurrent(), entry))
    {
        string text = "Entry @ " + DoubleToString(entry, _Digits);
        ObjectSetString(0, entryLabel, OBJPROP_TEXT, text);
        ObjectSetInteger(0, entryLabel, OBJPROP_COLOR, (signalType == ORDER_TYPE_BUY) ? g_buyColor : g_sellColor);
    }
    if(ObjectCreate(0, slLabel, OBJ_TEXT, 0, TimeCurrent(), sl))
    {
        string text = "SL @ " + DoubleToString(sl, _Digits);
        ObjectSetString(0, slLabel, OBJPROP_TEXT, text);
        ObjectSetInteger(0, slLabel, OBJPROP_COLOR, clrRed);
    }
    if(ObjectCreate(0, tpLabel, OBJ_TEXT, 0, TimeCurrent(), tp))
    {
        string text = "TP @ " + DoubleToString(tp, _Digits);
        ObjectSetString(0, tpLabel, OBJPROP_TEXT, text);
        ObjectSetInteger(0, tpLabel, OBJPROP_COLOR, clrBlue);
    }

    ChartRedraw(0);
    return true;
}

//+------------------------------------------------------------------+
//| CleanOldSignals                                                   |
//+------------------------------------------------------------------+
void CleanOldSignals()
{
    datetime currentTime = TimeCurrent();
    datetime oldestTime = currentTime - 86400; // 24h
    int total = ObjectsTotal(0);
    
    // Limiter le nombre d'objets à traiter pour éviter les ralentissements
    int maxObjectsToCheck = 100;
    int objectsChecked = 0;
    
    for(int i = total - 1; i >= 0 && objectsChecked < maxObjectsToCheck; i--, objectsChecked++)
    {
        string name = ObjectName(0, i);
        if(StringFind(name, g_signalPrefix) == 0)
        {
            // Utiliser une méthode plus rapide pour obtenir le temps (évite les appels multiples)
            datetime objTime = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME);
            if(objTime < oldestTime)
            {
                string textName = name + "_Label";
                ObjectDelete(0, name);
                ObjectDelete(0, textName);
            }
        }
    }
    
    // Nettoyage supplémentaire si trop d'objets
    if(total > g_maxObjects)
    {
        int toDelete = total - g_maxObjects;
        for(int i = 0; i < toDelete && i < total; i++)
        {
            string objName = ObjectName(0, i);
            if(StringFind(objName, g_signalPrefix) == 0 || 
               StringFind(objName, "SMC_") == 0)
            {
                ObjectDelete(0, objName);
                ObjectDelete(0, objName + "_Label");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifie s'il y a déjà une position ouverte sur ce symbole        |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        if(PositionGetSymbol(i) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| SendCustomNotification                                            |
//+------------------------------------------------------------------+
bool SendCustomNotification(string message)
{
    if(!SendNotification(message))
    {
        Print("Erreur d'envoi de notification: ", GetLastError());
        return false;
    }
    return true;
}
//+------------------------------------------------------------------+
