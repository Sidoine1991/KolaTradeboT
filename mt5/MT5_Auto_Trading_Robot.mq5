//+------------------------------------------------------------------+
//|                                    MT5_Auto_Trading_Robot.mq5 |
//|                                    Copyright 2026, TradBOT Team     |
//|                                              https://github.com/    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, TradBOT Team"
#property link      "https://github.com/Sidoine1991/KolaTradeboT"
#property version   "1.00"
#property description "Robot de trading automatique IA intégré à MT5"
#property script_show_inputs

#include <Trade\Trade.mqh>

//--- Paramètres d'entrée
input string InpRenderAPI = "https://kolatradebot.onrender.com";
input int    InpRefreshSeconds = 10;  // Rafraîchissement en secondes
input double InpMinConfidence = 70.0; // Confiance minimale
input double InpBoomVolume = 0.5;    // Volume Boom 300
input double InpOtherVolume = 0.2;   // Volume autres
input bool   InpEnableTrading = true;  // Activer le trading
input bool   InpShowDashboard = true;  // Afficher le dashboard
input color  InpBuyColor = clrLime;
input color  InpSellColor = clrRed;
input color  InpNeutralColor = clrGray;

//--- Variables globales
CTrade trade;
datetime last_refresh = 0;
datetime last_trade = {};
bool dashboard_visible = true;
string active_symbols[];

//--- Structures
struct SignalData
{
    string symbol;
    string signal;
    double confidence;
    datetime timestamp;
};

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🤖 Démarrage du Robot Trading IA...");
    
    // Initialiser le trading
    trade.SetExpertMagicNumber(234000);
    trade.SetMarginMode();
    
    // Définir les symboles à surveiller
    ArrayResize(active_symbols, 4);
    active_symbols[0] = "Boom 300 Index";
    active_symbols[1] = "Boom 600 Index";
    active_symbols[2] = "Boom 900 Index";
    active_symbols[3] = "Crash 1000 Index";
    
    // Créer le dashboard si demandé
    if(InpShowDashboard)
    {
        CreateDashboard();
    }
    
    Print("✅ Robot initialisé avec succès");
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    if(InpShowDashboard)
    {
        CleanupDashboard();
    }
    Print("🔄 Robot arrêté");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // Rafraîchir les données
    if(TimeCurrent() - last_refresh >= InpRefreshSeconds)
    {
        RefreshAndTrade();
        last_refresh = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Rafraîchir et exécuter les trades                                |
//+------------------------------------------------------------------+
void RefreshAndTrade()
{
    // Récupérer les signaux IA
    SignalData signals[];
    GetAISignals(signals);
    
    // Mettre à jour le dashboard
    if(InpShowDashboard)
    {
        UpdateDashboard(signals);
    }
    
    // Exécuter les trades si activé
    if(InpEnableTrading)
    {
        ExecuteTrades(signals);
    }
}

//+------------------------------------------------------------------+
//| Exécuter les trades basés sur les signaux                         |
//+------------------------------------------------------------------+
void ExecuteTrades(SignalData &signals[])
{
    for(int i = 0; i < ArraySize(signals); i++)
    {
        SignalData signal = signals[i];
        
        // Vérifier la confiance
        if(signal.confidence < InpMinConfidence)
            continue;
        
        // Vérifier si on a déjà une position sur ce symbole
        if(HasOpenPosition(signal.symbol))
            continue;
        
        // Vérifier les règles Boom/Crash
        if(!IsSignalAllowed(signal.symbol, signal.signal))
        {
            Print("🚫 Signal non autorisé: ", signal.symbol, " ", signal.signal);
            continue;
        }
        
        // Éviter les trades trop fréquents
        if(signal.symbol == last_trade.symbol && 
           TimeCurrent() - last_trade.time < 60) // 1 minute minimum
            continue;
        
        // Déterminer le volume
        double volume = GetVolumeForSymbol(signal.symbol);
        
        // Exécuter le trade
        bool success = false;
        
        if(signal.signal == "BUY")
        {
            success = ExecuteBuy(signal.symbol, volume);
        }
        else if(signal.signal == "SELL")
        {
            success = ExecuteSell(signal.symbol, volume);
        }
        
        if(success)
        {
            last_trade.symbol = signal.symbol;
            last_trade.time = TimeCurrent();
            
            string message = StringFormat("✅ Trade exécuté: %s %s @%.5f (Conf: %.0f%%)", 
                                        signal.signal, signal.symbol, 
                                        GetCurrentPrice(signal.symbol), signal.confidence);
            Print(message);
            SendNotification(message);
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier si un signal est autorisé                               |
//+------------------------------------------------------------------+
bool IsSignalAllowed(string symbol, string signal)
{
    // Règles: Boom = SELL uniquement, Crash = BUY uniquement
    if(StringFind(symbol, "Boom") >= 0)
    {
        return signal == "SELL";
    }
    else if(StringFind(symbol, "Crash") >= 0)
    {
        return signal == "BUY";
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Vérifier si une position est ouverte                             |
//+------------------------------------------------------------------+
bool HasOpenPosition(string symbol)
{
    for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
    {
        if(PositionGetSymbol(pos) == symbol)
        {
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| Exécuter un ordre d'achat                                         |
//+------------------------------------------------------------------+
bool ExecuteBuy(string symbol, double volume)
{
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // SL/TP simplifiés (pas de SL/TP pour le moment)
    double sl = 0.0;
    double tp = 0.0;
    
    if(trade.Buy(volume, symbol, ask, sl, tp, "AI Robot BUY"))
    {
        return trade.ResultRetcode() == TRADE_RETCODE_DONE;
    }
    
    Print("❌ Échec achat ", symbol, ": ", trade.ResultRetcode(), " - ", trade.ResultComment());
    return false;
}

//+------------------------------------------------------------------+
//| Exécuter un ordre de vente                                        |
//+------------------------------------------------------------------+
bool ExecuteSell(string symbol, double volume)
{
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    // SL/TP simplifiés (pas de SL/TP pour le moment)
    double sl = 0.0;
    double tp = 0.0;
    
    if(trade.Sell(volume, symbol, bid, sl, tp, "AI Robot SELL"))
    {
        return trade.ResultRetcode() == TRADE_RETCODE_DONE;
    }
    
    Print("❌ Échec vente ", symbol, ": ", trade.ResultRetcode(), " - ", trade.ResultComment());
    return false;
}

//+------------------------------------------------------------------+
//| Obtenir le volume pour un symbole                                 |
//+------------------------------------------------------------------+
double GetVolumeForSymbol(string symbol)
{
    if(symbol == "Boom 300 Index")
        return InpBoomVolume;
    else
        return InpOtherVolume;
}

//+------------------------------------------------------------------+
//| Obtenir le prix actuel                                            |
//+------------------------------------------------------------------+
double GetCurrentPrice(string symbol)
{
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    
    // Retourner le prix moyen
    return (bid + ask) / 2.0;
}

//+------------------------------------------------------------------+
//| Récupérer les signaux IA                                          |
//+------------------------------------------------------------------+
void GetAISignals(SignalData &signals[])
{
    ArrayResize(signals, ArraySize(active_symbols));
    
    for(int i = 0; i < ArraySize(active_symbols); i++)
    {
        string symbol = active_symbols[i];
        string url = InpRenderAPI + "/predict/" + symbol;
        
        // Préparer la requête
        string headers = "Content-Type: application/json\r\n";
        char data[];
        char result[];
        
        // Appeler l'API
        int timeout = 5000; // 5 secondes
        
        if(WebRequest::Get(url, headers, timeout, data, result, headers))
        {
            string response = CharArrayToString(result);
            
            // Parser la réponse JSON
            if(StringFind(response, "\"direction\":\"UP\"") > 0)
            {
                signals[i].symbol = symbol;
                signals[i].signal = "BUY";
                signals[i].confidence = ExtractConfidence(response);
                signals[i].timestamp = TimeCurrent();
            }
            else if(StringFind(response, "\"direction\":\"DOWN\"") > 0)
            {
                signals[i].symbol = symbol;
                signals[i].signal = "SELL";
                signals[i].confidence = ExtractConfidence(response);
                signals[i].timestamp = TimeCurrent();
            }
            else
            {
                signals[i].symbol = symbol;
                signals[i].signal = "WAIT";
                signals[i].confidence = 0;
                signals[i].timestamp = TimeCurrent();
            }
        }
        else
        {
            signals[i].symbol = symbol;
            signals[i].signal = "ERROR";
            signals[i].confidence = 0;
            signals[i].timestamp = TimeCurrent();
        }
    }
}

//+------------------------------------------------------------------+
//| Extraire la confiance de la réponse JSON                         |
//+------------------------------------------------------------------+
double ExtractConfidence(string response)
{
    int conf_pos = StringFind(response, "\"confidence\":");
    if(conf_pos > 0)
    {
        int start = conf_pos + 14;
        int end = StringFind(response, ",", start);
        if(end < 0) end = StringFind(response, "}", start);
        
        if(end > start)
        {
            string conf_str = StringSubstr(response, start, end - start);
            return StringToDouble(conf_str) * 100;
        }
    }
    return 0.0;
}

//+------------------------------------------------------------------+
//| Créer le dashboard                                               |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    // Titre
    CreateTextObject("ROBOT_TITLE", 50, 20, "🤖 AUTO TRADING ROBOT", 12, clrDodgerBlue);
    
    // En-têtes
    CreateTextObject("HEADER_SYMBOL", 50, 50, "SYMBOL", 9, clrWhite);
    CreateTextObject("HEADER_SIGNAL", 150, 50, "SIGNAL", 9, clrWhite);
    CreateTextObject("HEADER_CONF", 250, 50, "CONF", 9, clrWhite);
    CreateTextObject("HEADER_POS", 350, 50, "POSITION", 9, clrWhite);
    CreateTextObject("HEADER_STATUS", 500, 50, "STATUS", 9, clrWhite);
    
    // Lignes pour chaque symbole
    for(int i = 0; i < ArraySize(active_symbols); i++)
    {
        int y = 80 + i * 30;
        string prefix = StringReplace(active_symbols[i], " ", "_");
        
        CreateTextObject(prefix + "_SYMBOL", 50, y, active_symbols[i], 9, clrDodgerBlue);
        CreateTextObject(prefix + "_SIGNAL", 150, y, "⏳ WAIT", 9, InpNeutralColor);
        CreateTextObject(prefix + "_CONF", 250, y, "---", 9, InpNeutralColor);
        CreateTextObject(prefix + "_POS", 350, y, "📉 NONE", 9, InpNeutralColor);
        CreateTextObject(prefix + "_STATUS", 500, y, "✅ READY", 9, clrLime);
    }
    
    // Statistiques
    CreateTextObject("STATS_LABEL", 50, 220, "📊 STATISTIQUES", 10, clrDodgerBlue);
    CreateTextObject("STATS_DATA", 50, 245, "Positions: 0 | Trades: 0 | P&L: 0.00", 9, clrWhite);
    
    // Contrôles
    CreateButtonObject("BTN_TOGGLE", 50, 280, 80, 25, "👁️ TOGGLE", clrWhite, InpNeutralColor);
    CreateButtonObject("BTN_REFRESH", 140, 280, 80, 25, "🔄 REFRESH", clrWhite, InpNeutralColor);
    
    Print("✅ Dashboard créé");
}

//+------------------------------------------------------------------+
//| Mettre à jour le dashboard                                       |
//+------------------------------------------------------------------+
void UpdateDashboard(SignalData &signals[])
{
    // Mettre à jour l'heure
    CreateTextObject("CURRENT_TIME", 400, 20, "🕐 " + TimeToString(TimeCurrent(), TIME_SECONDS), 9, clrWhite);
    
    // Statistiques
    int total_positions = 0;
    double total_profit = 0.0;
    int total_trades = 0;
    
    // Compter les positions
    for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
    {
        string symbol = PositionGetSymbol(pos);
        for(int i = 0; i < ArraySize(active_symbols); i++)
        {
            if(symbol == active_symbols[i])
            {
                total_positions++;
                total_profit += PositionGetDouble(POSITION_PROFIT);
                break;
            }
        }
    }
    
    // Mettre à jour chaque symbole
    for(int i = 0; i < ArraySize(signals); i++)
    {
        SignalData signal = signals[i];
        string prefix = StringReplace(signal.symbol, " ", "_");
        
        // Signal et confiance
        color signal_color = InpNeutralColor;
        string signal_text = "⏳ WAIT";
        
        if(signal.signal == "BUY")
        {
            signal_text = StringFormat("📈 BUY %.0f%%", signal.confidence);
            signal_color = InpBuyColor;
        }
        else if(signal.signal == "SELL")
        {
            signal_text = StringFormat("📉 SELL %.0f%%", signal.confidence);
            signal_color = InpSellColor;
        }
        else if(signal.signal == "ERROR")
        {
            signal_text = "❌ ERROR";
            signal_color = clrRed;
        }
        
        CreateTextObject(prefix + "_SIGNAL", 150, 0, signal_text, 9, signal_color);
        CreateTextObject(prefix + "_CONF", 250, 0, StringFormat("%.0f%%", signal.confidence), 9, signal_color);
        
        // Position
        string pos_text = "📉 NONE";
        color pos_color = InpNeutralColor;
        
        if(HasOpenPosition(signal.symbol))
        {
            pos_text = "💼 ACTIVE";
            pos_color = clrYellow;
        }
        
        CreateTextObject(prefix + "_POS", 350, 0, pos_text, 9, pos_color);
        
        // Status
        string status = "✅ READY";
        color status_color = clrLime;
        
        if(signal.signal == "ERROR")
        {
            status = "❌ ERROR";
            status_color = clrRed;
        }
        else if(HasOpenPosition(signal.symbol))
        {
            status = "💼 POSITION";
            status_color = clrYellow;
        }
        else if(signal.confidence >= InpMinConfidence && IsSignalAllowed(signal.symbol, signal.signal))
        {
            status = "🔥 SIGNAL";
            status_color = clrOrange;
        }
        
        CreateTextObject(prefix + "_STATUS", 500, 0, status, 9, status_color);
    }
    
    // Mettre à jour les statistiques
    string stats_text = StringFormat("Positions: %d | P&L: %.2f | API: ✅", total_positions, total_profit);
    CreateTextObject("STATS_DATA", 50, 245, stats_text, 9, total_profit >= 0 ? clrLime : clrRed);
}

//+------------------------------------------------------------------+
//| Gérer les événements graphiques                                   |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
    if(id == CHARTEVENT_OBJECT_CLICK)
    {
        if(sparam == "BTN_TOGGLE")
        {
            dashboard_visible = !dashboard_visible;
            ToggleDashboard(dashboard_visible);
        }
        else if(sparam == "BTN_REFRESH")
        {
            RefreshAndTrade();
        }
    }
}

//+------------------------------------------------------------------+
//| Fonctions utilitaires pour le dashboard                           |
//+------------------------------------------------------------------+
void CreateTextObject(string name, int x, int y, string text, int size, color col)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
        ObjectSetString(0, name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, name, OBJPROP_COLOR, col);
    }
    else
    {
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_COLOR, col);
    }
}

void CreateButtonObject(string name, int x, int y, int width, int height, string text, color text_color, color bg_color)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
        ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
        ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
        ObjectSetString(0, name, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
    }
}

void ToggleDashboard(bool visible)
{
    string objects[] = {
        "ROBOT_TITLE", "HEADER_SYMBOL", "HEADER_SIGNAL", "HEADER_CONF", 
        "HEADER_POS", "HEADER_STATUS", "STATS_LABEL", "STATS_DATA", "CURRENT_TIME"
    };
    
    for(int i = 0; i < ArraySize(active_symbols); i++)
    {
        string prefix = StringReplace(active_symbols[i], " ", "_");
        ArrayResize(objects, ArraySize(objects) + 4);
        objects[ArraySize(objects) - 4] = prefix + "_SYMBOL";
        objects[ArraySize(objects) - 3] = prefix + "_SIGNAL";
        objects[ArraySize(objects) - 2] = prefix + "_CONF";
        objects[ArraySize(objects) - 1] = prefix + "_POS";
        objects[ArraySize(objects) - 1] = prefix + "_STATUS";
    }
    
    for(int i = 0; i < ArraySize(objects); i++)
    {
        if(ObjectFind(0, objects[i]) >= 0)
        {
            ObjectSetInteger(0, objects[i], OBJPROP_TIME_FRAMES, visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
        }
    }
}

void CleanupDashboard()
{
    string objects[] = {
        "ROBOT_TITLE", "HEADER_SYMBOL", "HEADER_SIGNAL", "HEADER_CONF", 
        "HEADER_POS", "HEADER_STATUS", "STATS_LABEL", "STATS_DATA", "CURRENT_TIME",
        "BTN_TOGGLE", "BTN_REFRESH"
    };
    
    for(int i = 0; i < ArraySize(active_symbols); i++)
    {
        string prefix = StringReplace(active_symbols[i], " ", "_");
        ArrayResize(objects, ArraySize(objects) + 4);
        objects[ArraySize(objects) - 4] = prefix + "_SYMBOL";
        objects[ArraySize(objects) - 3] = prefix + "_SIGNAL";
        objects[ArraySize(objects) - 2] = prefix + "_CONF";
        objects[ArraySize(objects) - 1] = prefix + "_POS";
        objects[ArraySize(objects) - 1] = prefix + "_STATUS";
    }
    
    for(int i = 0; i < ArraySize(objects); i++)
    {
        ObjectDelete(0, objects[i]);
    }
    
    ChartRedraw();
}
//+------------------------------------------------------------------+
