//+------------------------------------------------------------------+
//|                                       MT5_Trading_Dashboard.mq5 |
//|                                    Copyright 2026, TradBOT Team     |
//|                                              https://github.com/    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, TradBOT Team"
#property link      "https://github.com/Sidoine1991/KolaTradeboT"
#property version   "1.00"
#property description "Dashboard de trading IA intégré à MT5"
#property script_show_inputs

#include <Trade\Trade.mqh>

//--- Paramètres d'entrée
input string InpRenderAPI = "https://kolatradebot.onrender.com";
input int    InpRefreshSeconds = 5;  // Rafraîchissement en secondes
input color  InpBuyColor = clrLime;
input color  InpSellColor = clrRed;
input color  InpNeutralColor = clrGray;
input int    InpFontSize = 10;
input string InpFontName = "Arial";

//--- Variables globales
CTrade trade;
string dashboard_objects[];
datetime last_refresh = 0;
bool dashboard_visible = true;

//--- Structures pour les données
struct SignalData
{
    string symbol;
    string signal;
    double confidence;
    datetime timestamp;
};

struct PositionData
{
    string symbol;
    string type;
    double price;
    double profit;
    ulong ticket;
};

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
    Print("🤖 Démarrage du Dashboard Trading IA...");
    
    // Initialiser le trading
    trade.SetExpertMagicNumber(234000);
    trade.SetMarginMode();
    
    // Créer le dashboard
    CreateDashboard();
    
    // Boucle principale
    while(!IsStopped())
    {
        // Rafraîchir les données
        if(TimeCurrent() - last_refresh >= InpRefreshSeconds)
        {
            RefreshDashboard();
            last_refresh = TimeCurrent();
        }
        
        // Gérer les événements
        CheckUserInput();
        
        Sleep(1000);
    }
    
    // Nettoyer
    CleanupDashboard();
    Print("🔄 Dashboard arrêté");
}

//+------------------------------------------------------------------+
//| Créer l'interface du dashboard                                   |
//+------------------------------------------------------------------+
void CreateDashboard()
{
    // Titre principal
    CreateTextObject("TITLE", 50, 20, "🤖 TRADING IA DASHBOARD", InpFontSize + 6, clrDodgerBlue);
    
    // En-têtes des colonnes
    CreateTextObject("HEADER_SYMBOL", 50, 60, "SYMBOL", InpFontSize, clrWhite);
    CreateTextObject("HEADER_SIGNAL", 200, 60, "SIGNAL", InpFontSize, clrWhite);
    CreateTextObject("HEADER_CONF", 350, 60, "CONF", InpFontSize, clrWhite);
    CreateTextObject("HEADER_POS", 450, 60, "POSITION", InpFontSize, clrWhite);
    CreateTextObject("HEADER_PNL", 600, 60, "P&L", InpFontSize, clrWhite);
    CreateTextObject("HEADER_TIME", 750, 60, "UPDATE", InpFontSize, clrWhite);
    
    // Ligne de séparation
    CreateLineObject("SEPARATOR", 50, 85, 850, 85, clrGray);
    
    // Créer les lignes pour chaque symbole
    string symbols[] = {"Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index"};
    
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        int y = 110 + i * 40;
        string prefix = StringReplace(symbols[i], " ", "_");
        
        // Nom du symbole
        CreateTextObject(prefix + "_SYMBOL", 50, y, symbols[i], InpFontSize, clrDodgerBlue);
        
        // Signal
        CreateTextObject(prefix + "_SIGNAL", 200, y, "⏳ WAIT", InpFontSize, InpNeutralColor);
        
        // Confiance
        CreateTextObject(prefix + "_CONF", 350, y, "---", InpFontSize, InpNeutralColor);
        
        // Position
        CreateTextObject(prefix + "_POS", 450, y, "📉 NONE", InpFontSize, InpNeutralColor);
        
        // P&L
        CreateTextObject(prefix + "_PNL", 600, y, "---", InpFontSize, InpNeutralColor);
        
        // Heure de mise à jour
        CreateTextObject(prefix + "_TIME", 750, y, "---", InpFontSize, InpNeutralColor);
    }
    
    // Performance globale
    CreateTextObject("PERF_LABEL", 50, 280, "📊 PERFORMANCE GLOBALE", InpFontSize + 2, clrDodgerBlue);
    CreateTextObject("PERF_DATA", 50, 310, "Positions: 0 | P&L: 0.00 | Signaux: 0", InpFontSize, clrWhite);
    
    // Contrôles
    CreateButtonObject("BTN_REFRESH", 50, 360, 100, 30, "🔄 REFRESH", clrWhite, InpNeutralColor);
    CreateButtonObject("BTN_TOGGLE", 170, 360, 100, 30, "👁️ SHOW/HIDE", clrWhite, InpNeutralColor);
    CreateButtonObject("BTN_CLOSE", 290, 360, 100, 30, "❌ CLOSE", clrWhite, InpNeutralColor);
    
    // Instructions
    CreateTextObject("INSTRUCTIONS", 50, 410, 
        "RÈGLES: Boom=SELL uniquement | Crash=BUY uniquement | Confiance min=70%\n" +
        "CONTROLES: Click sur les boutons pour interagir | Glissez pour déplacer", 
        InpFontSize - 1, clrGray);
    
    Print("✅ Dashboard créé avec succès");
}

//+------------------------------------------------------------------+
//| Rafraîchir les données du dashboard                               |
//+------------------------------------------------------------------+
void RefreshDashboard()
{
    // Mettre à jour l'heure
    string current_time = TimeToString(TimeCurrent(), TIME_SECONDS);
    CreateTextObject("CURRENT_TIME", 750, 20, "🕐 " + current_time, InpFontSize, clrWhite);
    
    // Récupérer les signaux IA
    SignalData signals[];
    GetAISignals(signals);
    
    // Récupérer les positions
    PositionData positions[];
    GetPositions(positions);
    
    // Mettre à jour chaque symbole
    string symbols[] = {"Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index"};
    
    double total_profit = 0;
    int active_positions = 0;
    int active_signals = 0;
    
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        string symbol = symbols[i];
        string prefix = StringReplace(symbol, " ", "_");
        
        // Trouver le signal pour ce symbole
        string signal = "WAIT";
        double confidence = 0;
        
        for(int j = 0; j < ArraySize(signals); j++)
        {
            if(signals[j].symbol == symbol)
            {
                signal = signals[j].signal;
                confidence = signals[j].confidence;
                if(signal != "WAIT" && signal != "ERROR") active_signals++;
                break;
            }
        }
        
        // Trouver la position pour ce symbole
        string pos_type = "NONE";
        double pos_price = 0;
        double pos_profit = 0;
        
        for(int j = 0; j < ArraySize(positions); j++)
        {
            if(positions[j].symbol == symbol)
            {
                pos_type = positions[j].type;
                pos_price = positions[j].price;
                pos_profit = positions[j].profit;
                if(pos_type != "NONE") 
                {
                    active_positions++;
                    total_profit += pos_profit;
                }
                break;
            }
        }
        
        // Mettre à jour l'affichage
        UpdateSymbolRow(prefix, signal, confidence, pos_type, pos_price, pos_profit);
    }
    
    // Mettre à jour la performance globale
    string perf_text = StringFormat("Positions: %d | P&L: %.2f | Signaux: %d", 
                                    active_positions, total_profit, active_signals);
    CreateTextObject("PERF_DATA", 50, 310, perf_text, InpFontSize, 
                    total_profit >= 0 ? clrLime : clrRed);
}

//+------------------------------------------------------------------+
//| Mettre à jour une ligne de symbole                               |
//+------------------------------------------------------------------+
void UpdateSymbolRow(string prefix, string signal, double confidence, 
                    string pos_type, double pos_price, double pos_profit)
{
    // Signal et confiance
    color signal_color = InpNeutralColor;
    string signal_text = "⏳ WAIT";
    
    if(signal == "BUY")
    {
        signal_text = StringFormat("📈 BUY %.0f%%", confidence);
        signal_color = InpBuyColor;
    }
    else if(signal == "SELL")
    {
        signal_text = StringFormat("📉 SELL %.0f%%", confidence);
        signal_color = InpSellColor;
    }
    else if(signal == "ERROR")
    {
        signal_text = "❌ ERROR";
        signal_color = clrRed;
    }
    
    CreateTextObject(prefix + "_SIGNAL", 200, 0, signal_text, InpFontSize, signal_color);
    CreateTextObject(prefix + "_CONF", 350, 0, StringFormat("%.0f%%", confidence), InpFontSize, signal_color);
    
    // Position
    color pos_color = InpNeutralColor;
    string pos_text = "📉 NONE";
    
    if(pos_type != "NONE")
    {
        pos_text = StringFormat("💼 %s @ %.5f", pos_type, pos_price);
        pos_color = pos_profit >= 0 ? clrLime : clrRed;
    }
    
    CreateTextObject(prefix + "_POS", 450, 0, pos_text, InpFontSize, pos_color);
    
    // P&L
    string pnl_text = "---";
    color pnl_color = InpNeutralColor;
    
    if(pos_type != "NONE")
    {
        pnl_text = StringFormat("%+.2f", pos_profit);
        pnl_color = pos_profit >= 0 ? clrLime : clrRed;
    }
    
    CreateTextObject(prefix + "_PNL", 600, 0, pnl_text, InpFontSize, pnl_color);
    
    // Heure de mise à jour
    CreateTextObject(prefix + "_TIME", 750, 0, TimeToString(TimeCurrent(), TIME_SECONDS), InpFontSize, InpNeutralColor);
}

//+------------------------------------------------------------------+
//| Récupérer les signaux IA depuis Render API                        |
//+------------------------------------------------------------------+
void GetAISignals(SignalData &signals[])
{
    string symbols[] = {"Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index"};
    ArrayResize(signals, ArraySize(symbols));
    
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        string symbol = symbols[i];
        string url = InpRenderAPI + "/predict/" + symbol;
        
        // Utiliser WebRequest pour appeler l'API
        string response;
        string headers;
        char data[];
        
        int timeout = 5000; // 5 secondes
        
        if(WebRequest::Get(url, headers, timeout, data, headers, response))
        {
            // Parser la réponse JSON (simplifié)
            if(StringFind(response, "\"direction\":\"UP\"") > 0)
            {
                signals[i].symbol = symbol;
                signals[i].signal = "BUY";
                // Extraire la confiance (simplifié)
                int conf_pos = StringFind(response, "\"confidence\":");
                if(conf_pos > 0)
                {
                    string conf_str = StringSubstr(response, conf_pos + 13, 4);
                    signals[i].confidence = StringToDouble(conf_str) * 100;
                }
            }
            else if(StringFind(response, "\"direction\":\"DOWN\"") > 0)
            {
                signals[i].symbol = symbol;
                signals[i].signal = "SELL";
                // Extraire la confiance
                int conf_pos = StringFind(response, "\"confidence\":");
                if(conf_pos > 0)
                {
                    string conf_str = StringSubstr(response, conf_pos + 13, 4);
                    signals[i].confidence = StringToDouble(conf_str) * 100;
                }
            }
            else
            {
                signals[i].symbol = symbol;
                signals[i].signal = "WAIT";
                signals[i].confidence = 0;
            }
            
            signals[i].timestamp = TimeCurrent();
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
//| Récupérer les positions MT5                                     |
//+------------------------------------------------------------------+
void GetPositions(PositionData &positions[])
{
    string symbols[] = {"Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index"};
    ArrayResize(positions, ArraySize(symbols));
    
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        string symbol = symbols[i];
        
        positions[i].symbol = symbol;
        positions[i].type = "NONE";
        positions[i].price = 0;
        positions[i].profit = 0;
        positions[i].ticket = 0;
        
        // Parcourir les positions
        for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
        {
            if(PositionGetSymbol(pos) == symbol)
            {
                positions[i].type = PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY ? "BUY" : "SELL";
                positions[i].price = PositionGetDouble(POSITION_PRICE_OPEN);
                positions[i].profit = PositionGetDouble(POSITION_PROFIT);
                positions[i].ticket = PositionGetInteger(POSITION_TICKET);
                break;
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Vérifier les entrées utilisateur                                  |
//+------------------------------------------------------------------+
void CheckUserInput()
{
    // Vérifier les clics sur les boutons
    if(ObjectGetInteger(0, "BTN_REFRESH", OBJPROP_STATE))
    {
        RefreshDashboard();
        ObjectSetInteger(0, "BTN_REFRESH", OBJPROP_STATE, false);
        ChartRedraw();
    }
    
    if(ObjectGetInteger(0, "BTN_TOGGLE", OBJPROP_STATE))
    {
        dashboard_visible = !dashboard_visible;
        ToggleDashboardVisibility(dashboard_visible);
        ObjectSetInteger(0, "BTN_TOGGLE", OBJPROP_STATE, false);
        ChartRedraw();
    }
    
    if(ObjectGetInteger(0, "BTN_CLOSE", OBJPROP_STATE))
    {
        ObjectSetInteger(0, "BTN_CLOSE", OBJPROP_STATE, false);
        ExpertRemove();
    }
}

//+------------------------------------------------------------------+
//| Afficher/Masquer le dashboard                                    |
//+------------------------------------------------------------------+
void ToggleDashboardVisibility(bool visible)
{
    string objects[] = {
        "TITLE", "HEADER_SYMBOL", "HEADER_SIGNAL", "HEADER_CONF", 
        "HEADER_POS", "HEADER_PNL", "HEADER_TIME", "SEPARATOR",
        "PERF_LABEL", "PERF_DATA", "INSTRUCTIONS", "CURRENT_TIME"
    };
    
    // Ajouter tous les objets de symboles
    string symbols[] = {"Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index"};
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        string prefix = StringReplace(symbols[i], " ", "_");
        ArrayResize(objects, ArraySize(objects) + 5);
        objects[ArraySize(objects) - 5] = prefix + "_SYMBOL";
        objects[ArraySize(objects) - 4] = prefix + "_SIGNAL";
        objects[ArraySize(objects) - 3] = prefix + "_CONF";
        objects[ArraySize(objects) - 2] = prefix + "_POS";
        objects[ArraySize(objects) - 1] = prefix + "_PNL";
        objects[ArraySize(objects) - 1] = prefix + "_TIME";
    }
    
    for(int i = 0; i < ArraySize(objects); i++)
    {
        if(ObjectFind(0, objects[i]) >= 0)
        {
            ObjectSetInteger(0, objects[i], OBJPROP_TIME_FRAMES, visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS);
        }
    }
}

//+------------------------------------------------------------------+
//| Créer un objet texte                                            |
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
        ObjectSetString(0, name, OBJPROP_FONT, InpFontName);
        ObjectSetInteger(0, name, OBJPROP_COLOR, col);
        ObjectSetInteger(0, name, OBJPROP_BACK_COLOR, clrNONE);
        ObjectSetInteger(0, name, OBJPROP_TIME_FRAMES, OBJ_ALL_PERIODS);
    }
    else
    {
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_COLOR, col);
    }
}

//+------------------------------------------------------------------+
//| Créer un objet ligne                                             |
//+------------------------------------------------------------------+
void CreateLineObject(string name, int x1, int y1, int x2, int y2, color col)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, y1);
        ObjectSetInteger(0, name, OBJPROP_COLOR, col);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, name, OBJPROP_TIME_FRAMES, OBJ_ALL_PERIODS);
    }
}

//+------------------------------------------------------------------+
//| Créer un objet bouton                                            |
//+------------------------------------------------------------------+
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
        ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpFontSize - 1);
        ObjectSetString(0, name, OBJPROP_FONT, InpFontName);
        ObjectSetInteger(0, name, OBJPROP_COLOR, text_color);
        ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg_color);
        ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrWhite);
        ObjectSetInteger(0, name, OBJPROP_TIME_FRAMES, OBJ_ALL_PERIODS);
    }
}

//+------------------------------------------------------------------+
//| Nettoyer le dashboard                                            |
//+------------------------------------------------------------------+
void CleanupDashboard()
{
    // Supprimer tous les objets créés
    string objects[] = {
        "TITLE", "HEADER_SYMBOL", "HEADER_SIGNAL", "HEADER_CONF", 
        "HEADER_POS", "HEADER_PNL", "HEADER_TIME", "SEPARATOR",
        "PERF_LABEL", "PERF_DATA", "INSTRUCTIONS", "CURRENT_TIME",
        "BTN_REFRESH", "BTN_TOGGLE", "BTN_CLOSE"
    };
    
    string symbols[] = {"Boom 300 Index", "Boom 600 Index", "Boom 900 Index", "Crash 1000 Index"};
    for(int i = 0; i < ArraySize(symbols); i++)
    {
        string prefix = StringReplace(symbols[i], " ", "_");
        ArrayResize(objects, ArraySize(objects) + 5);
        objects[ArraySize(objects) - 5] = prefix + "_SYMBOL";
        objects[ArraySize(objects) - 4] = prefix + "_SIGNAL";
        objects[ArraySize(objects) - 3] = prefix + "_CONF";
        objects[ArraySize(objects) - 2] = prefix + "_POS";
        objects[ArraySize(objects) - 1] = prefix + "_PNL";
        objects[ArraySize(objects) - 1] = prefix + "_TIME";
    }
    
    for(int i = 0; i < ArraySize(objects); i++)
    {
        ObjectDelete(0, objects[i]);
    }
    
    ChartRedraw();
}
//+------------------------------------------------------------------+
