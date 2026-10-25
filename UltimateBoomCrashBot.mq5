//+------------------------------------------------------------------+
//|                                           UltimateBoomCrashBot.mq5 |
//|                        Copyright 2025, Ultimate Trading System      |
//|                                             https://ultimate-trading.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Ultimate Trading System"
#property link      "https://ultimate-trading.com"
#property version   "3.00"
#property description "Ultimate Boom/Crash Bot - Indicateurs complets + Signaux Render + Prédictions"
#property icon      "\\Images\\UltimateBot.ico"

#include <Trade\Trade.mqh>
#include <Charts\Chart.mqh>

//--- Paramètres de Trading
input group             "Paramètres de Trading"
input double            LotSize = 0.2;                 // Taille du lot
input string            AI_ServerURL = "https://kolatradebot.onrender.com"; // URL du serveur IA
input int               AI_Timeout = 10000;             // Timeout API (ms)
input int               AI_UpdateInterval = 5;            // Intervalle mise à jour (secondes)
input double            MaxLoss_USD = 3.0;             // Perte maximale par position
input double            SpikeProfit_USD = 0.50;          // Profit cible pour spike

input group             "Indicateurs Techniques"
input int               MA_Period = 20;                  // Période MA mobile
input int               RSI_Period = 14;                 // Période RSI
input double            RSI_Oversold = 30.0;            // Niveau survente
input double            RSI_Overbought = 70.0;          // Niveau surachat

input group             "Affichage Graphique"
input bool              ShowMA = true;                     // Afficher MA mobile
input bool              ShowRSI = true;                    // Afficher RSI
input bool              ShowSignals = true;                 // Afficher signaux d'entrée
input bool              ShowPredictions = true;             // Afficher prédictions
input bool              ShowSpikeArrows = true;            // Afficher flèches de spike
input color             MA_Color = clrBlue;                // Couleur MA
input color             RSI_Color_Up = clrGreen;           // Couleur RSI survente
input color             RSI_Color_Down = clrRed;         // Couleur RSI surachat

input group             "Identification"
input long              MagicNumber = 88888;               // Numéro magique
input bool              DebugMode = true;                  // Mode debug

//--- Variables globales
CTrade      trade;
int         ma_handle;
int         rsi_handle;
int         ma_buffer[];
int         rsi_buffer[];
datetime    last_ai_update = 0;
string      last_ai_signal = "";
double      last_ai_confidence = 0;
double      price_predictions[100]; // Prédictions sur 100 bougies
int         prediction_index = 0;

//--- Objets graphiques
string      spike_arrow_name = "";
datetime    spike_arrow_time = 0;
bool        spike_arrow_blink = false;

//+------------------------------------------------------------------+
//| Structure pour les signaux IA                                     |
//+------------------------------------------------------------------+
struct AISignal
{
    string   action;        // BUY/SELL/HOLD
    double   confidence;     // Confiance 0-1
    string   reason;        // Raison du signal
    double   prediction;     // Prédiction de prix
    datetime timestamp;     // Timestamp du signal
};

AISignal current_ai_signal;

//+------------------------------------------------------------------+
//| Initialisation                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    trade.SetExpertMagicNumber(MagicNumber);
    trade.SetMarginMode();
    trade.SetTypeFillingBySymbol(_Symbol);
    
    // Initialiser les indicateurs
    ma_handle = iMA(_Symbol, _Period, MA_Period, 0, MODE_EMA, PRICE_CLOSE);
    rsi_handle = iRSI(_Symbol, _Period, RSI_Period, PRICE_CLOSE);
    
    if(ma_handle == INVALID_HANDLE || rsi_handle == INVALID_HANDLE)
    {
        Print("❌ Erreur initialisation indicateurs");
        return INIT_FAILED;
    }
    
    // Initialiser les buffers
    ArraySetAsSeries(ma_buffer, true);
    ArraySetAsSeries(rsi_buffer, true);
    
    // Nettoyer les anciens objets graphiques
    CleanChartObjects();
    
    Print("✅ UltimateBoomCrashBot initialisé sur ", _Symbol);
    Print("📊 Paramètres: Lot=", LotSize, " | MA=", MA_Period, " | RSI=", RSI_Period);
    Print("🌐 Serveur IA: ", AI_ServerURL);
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitialisation                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    CleanChartObjects();
    Print("🛑 UltimateBoomCrashBot arrêté - Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Tick principal                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
    // Mettre à jour les indicateurs
    UpdateIndicators();
    
    // Mettre à jour les signaux IA
    UpdateAISignals();
    
    // Afficher les indicateurs graphiques
    UpdateGraphics();
    
    // Gérer les positions existantes
    ManagePositions();
    
    // Afficher les prédictions
    UpdatePredictions();
}

//+------------------------------------------------------------------+
//| Mettre à jour les indicateurs                                      |
//+------------------------------------------------------------------+
void UpdateIndicators()
{
    if(CopyBuffer(ma_handle, 0, 0, 3, ma_buffer) <= 0 ||
       CopyBuffer(rsi_handle, 0, 0, 3, rsi_buffer) <= 0)
    {
        return;
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour les signaux IA                                       |
//+------------------------------------------------------------------+
void UpdateAISignals()
{
    datetime current_time = TimeCurrent();
    
    // Mettre à jour toutes les 5 secondes
    if(current_time - last_ai_update < AI_UpdateInterval)
        return;
    
    last_ai_update = current_time;
    
    // Appeler tous les endpoints Render
    UpdateFromDecision();
    UpdateFromPredict();
    UpdateFromSpikeDetection();
    UpdateFromTrendAnalysis();
    
    if(DebugMode)
    {
        Print("🤖 Signal IA: ", current_ai_signal.action, 
              " | Confiance: ", DoubleToString(current_ai_signal.confidence * 100, 1), "%",
              " | Raison: ", current_ai_signal.reason);
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour depuis endpoint /decision                             |
//+------------------------------------------------------------------+
void UpdateFromDecision()
{
    string url = AI_ServerURL + "/decision";
    string data = "{\"symbol\":\"" + _Symbol + "\",\"bid\":" + 
                 DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), 5) + 
                 ",\"ask\":" + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), 5) + "}";
    
    string headers = "Content-Type: application/json\r\n";
    uchar post_data[];
    uchar result[];
    string result_headers;
    
    StringToCharArray(data, post_data);
    
    int res = WebRequest("POST", url, headers, AI_Timeout, post_data, result, result_headers);
    
    if(res == 200)
    {
        string response = CharArrayToString(result);
        ParseAIResponse(response);
    }
    else if(DebugMode)
    {
        Print("⚠️ Erreur /decision: ", res);
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour depuis endpoint /predict                              |
//+------------------------------------------------------------------+
void UpdateFromPredict()
{
    string url = AI_ServerURL + "/predict";
    string data = "{\"symbol\":\"" + _Symbol + "\",\"bars\":100}";
    
    string headers = "Content-Type: application/json\r\n";
    uchar post_data[];
    uchar result[];
    string result_headers;
    
    StringToCharArray(data, post_data);
    
    int res = WebRequest("POST", url, headers, AI_Timeout, post_data, result, result_headers);
    
    if(res == 200)
    {
        string response = CharArrayToString(result);
        ParsePredictResponse(response);
    }
    else if(DebugMode)
    {
        Print("⚠️ Erreur /predict: ", res);
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour depuis endpoint /spike-detection                     |
//+------------------------------------------------------------------+
void UpdateFromSpikeDetection()
{
    string url = AI_ServerURL + "/spike-detection";
    string data = "{\"symbol\":\"" + _Symbol + "\"}";
    
    string headers = "Content-Type: application/json\r\n";
    uchar post_data[];
    uchar result[];
    string result_headers;
    
    StringToCharArray(data, post_data);
    
    int res = WebRequest("POST", url, headers, AI_Timeout, post_data, result, result_headers);
    
    if(res == 200)
    {
        string response = CharArrayToString(result);
        ParseSpikeResponse(response);
    }
    else if(DebugMode)
    {
        Print("⚠️ Erreur /spike-detection: ", res);
    }
}

//+------------------------------------------------------------------+
//| Mettre à jour depuis endpoint /trend-analysis                        |
//+------------------------------------------------------------------+
void UpdateFromTrendAnalysis()
{
    string url = AI_ServerURL + "/trend-analysis";
    string data = "{\"symbol\":\"" + _Symbol + "\"}";
    
    string headers = "Content-Type: application/json\r\n";
    uchar post_data[];
    uchar result[];
    string result_headers;
    
    StringToCharArray(data, post_data);
    
    int res = WebRequest("POST", url, headers, AI_Timeout, post_data, result, result_headers);
    
    if(res == 200)
    {
        string response = CharArrayToString(result);
        ParseTrendResponse(response);
    }
    else if(DebugMode)
    {
        Print("⚠️ Erreur /trend-analysis: ", res);
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse IA                                             |
//+------------------------------------------------------------------+
void ParseAIResponse(string response)
{
    // Parser simple pour extraire action, confidence, reason
    int action_pos = StringFind(response, "\"action\"");
    if(action_pos >= 0)
    {
        int colon_pos = StringFind(response, ":", action_pos);
        int quote_start = StringFind(response, "\"", colon_pos);
        int quote_end = StringFind(response, "\"", quote_start + 1);
        
        if(quote_end > quote_start)
        {
            current_ai_signal.action = StringSubstr(response, quote_start + 1, quote_end - quote_start - 1);
        }
    }
    
    // Parser confiance
    int conf_pos = StringFind(response, "\"confidence\"");
    if(conf_pos >= 0)
    {
        int colon_conf = StringFind(response, ":", conf_pos);
        int conf_end = StringFind(response, ",", colon_conf);
        if(conf_end < 0) conf_end = StringFind(response, "}", colon_conf);
        
        if(conf_end > colon_conf)
        {
            string conf_str = StringSubstr(response, colon_conf + 1, conf_end - colon_conf - 1);
            current_ai_signal.confidence = StringToDouble(conf_str);
        }
    }
    
    current_ai_signal.timestamp = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Parser les prédictions                                             |
//+------------------------------------------------------------------+
void ParsePredictResponse(string response)
{
    // Parser pour extraire les prédictions sur 100 bougies
    int pred_pos = StringFind(response, "\"predictions\"");
    if(pred_pos >= 0)
    {
        // Extraire le tableau de prédictions
        int start = StringFind(response, "[", pred_pos);
        int end = StringFind(response, "]", start);
        
        if(end > start)
        {
            string pred_str = StringSubstr(response, start + 1, end - start - 1);
            // Parser les valeurs séparées par virgules
            string values[];
            StringSplit(pred_str, ',', values);
            
            for(int i = 0; i < MathMin(100, ArraySize(values)); i++)
            {
                price_predictions[i] = StringToDouble(values[i]);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse spike                                           |
//+------------------------------------------------------------------+
void ParseSpikeResponse(string response)
{
    // Détecter si un spike est annoncé
    if(StringFind(response, "\"spike\":true") >= 0)
    {
        CreateSpikeArrow();
        Print("🚨 SPIKE DÉTECTÉ! Préparation entrée...");
    }
}

//+------------------------------------------------------------------+
//| Parser la réponse tendance                                         |
//+------------------------------------------------------------------+
void ParseTrendResponse(string response)
{
    // Parser les informations de tendance
    if(StringFind(response, "\"trend\":\"up\"") >= 0)
    {
        if(DebugMode) Print("📈 Tendance: HAUSSIÈRE");
    }
    else if(StringFind(response, "\"trend\":\"down\"") >= 0)
    {
        if(DebugMode) Print("📉 Tendance: BAISSIÈRE");
    }
}

//+------------------------------------------------------------------+
//| Afficher les indicateurs graphiques                                 |
//+------------------------------------------------------------------+
void UpdateGraphics()
{
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Afficher MA mobile
    if(ShowMA && ArraySize(ma_buffer) > 0)
    {
        string ma_name = "Ultimate_MA_" + IntegerToString(MA_Period);
        ObjectCreate(0, ma_name, OBJ_HLINE, 0, 0, ma_buffer[0]);
        ObjectSetInteger(0, ma_name, OBJPROP_COLOR, MA_Color);
        ObjectSetInteger(0, ma_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, ma_name, OBJPROP_STYLE, STYLE_SOLID);
    }
    
    // Afficher RSI
    if(ShowRSI && ArraySize(rsi_buffer) > 0)
    {
        string rsi_name = "Ultimate_RSI_" + IntegerToString(RSI_Period);
        color rsi_color = (rsi_buffer[0] < RSI_Oversold) ? RSI_Color_Up : 
                        (rsi_buffer[0] > RSI_Overbought) ? RSI_Color_Down : clrGray;
        
        ObjectCreate(0, rsi_name, OBJ_TEXT, 0, 0, 0);
        ObjectSetString(0, rsi_name, OBJPROP_TEXT, "RSI: " + DoubleToString(rsi_buffer[0], 1));
        ObjectSetInteger(0, rsi_name, OBJPROP_COLOR, rsi_color);
        ObjectSetInteger(0, rsi_name, OBJPROP_FONTSIZE, 10);
        ObjectSetInteger(0, rsi_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    }
    
    // Afficher les signaux d'entrée
    if(ShowSignals)
    {
        DisplayTradeSignals();
    }
}

//+------------------------------------------------------------------+
//| Afficher les signaux de trading                                   |
//+------------------------------------------------------------------+
void DisplayTradeSignals()
{
    if(ArraySize(ma_buffer) < 2 || ArraySize(rsi_buffer) < 1)
        return;
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ma_value = ma_buffer[0];
    double rsi_value = rsi_buffer[0];
    
    // Signaux d'achat
    bool buy_signal = (current_price > ma_value && rsi_value < RSI_Oversold);
    if(buy_signal && current_ai_signal.action == "BUY")
    {
        string buy_arrow = "Ultimate_BUY_" + IntegerToString((int)TimeCurrent());
        ObjectCreate(0, buy_arrow, OBJ_ARROW_UP, 0, TimeCurrent(), current_price);
        ObjectSetInteger(0, buy_arrow, OBJPROP_COLOR, clrGreen);
        ObjectSetInteger(0, buy_arrow, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, buy_arrow, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
        ObjectSetString(0, buy_arrow, OBJPROP_TEXT, "BUY");
    }
    
    // Signaux de vente
    bool sell_signal = (current_price < ma_value && rsi_value > RSI_Overbought);
    if(sell_signal && current_ai_signal.action == "SELL")
    {
        string sell_arrow = "Ultimate_SELL_" + IntegerToString((int)TimeCurrent());
        ObjectCreate(0, sell_arrow, OBJ_ARROW_DOWN, 0, TimeCurrent(), current_price);
        ObjectSetInteger(0, sell_arrow, OBJPROP_COLOR, clrRed);
        ObjectSetInteger(0, sell_arrow, OBJPROP_WIDTH, 3);
        ObjectSetInteger(0, sell_arrow, OBJPROP_ANCHOR, ANCHOR_TOP);
        ObjectSetString(0, sell_arrow, OBJPROP_TEXT, "SELL");
    }
}

//+------------------------------------------------------------------+
//| Afficher les prédictions sur 100 bougies                           |
//+------------------------------------------------------------------+
void UpdatePredictions()
{
    if(!ShowPredictions || ArraySize(price_predictions) < 10)
        return;
    
    // Afficher les prédictions futures
    for(int i = 0; i < 10; i++) // Afficher 10 prochaines bougies
    {
        if(i >= ArraySize(price_predictions)) break;
        
        datetime future_time = TimeCurrent() + (i + 1) * PeriodSeconds();
        double pred_price = price_predictions[prediction_index + i];
        
        string pred_line = "Ultimate_PRED_" + IntegerToString(i);
        ObjectCreate(0, pred_line, OBJ_TREND, 0, TimeCurrent(), price_predictions[prediction_index], 
                   future_time, pred_price);
        
        // Couleur selon la direction
        if(pred_price > price_predictions[prediction_index])
            ObjectSetInteger(0, pred_line, OBJPROP_COLOR, clrGreen);
        else
            ObjectSetInteger(0, pred_line, OBJPROP_COLOR, clrRed);
            
        ObjectSetInteger(0, pred_line, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, pred_line, OBJPROP_STYLE, STYLE_DOT);
    }
}

//+------------------------------------------------------------------+
//| Créer une flèche de spike clignotante                          |
//+------------------------------------------------------------------+
void CreateSpikeArrow()
{
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    spike_arrow_name = "Ultimate_SPIKE_" + IntegerToString((int)TimeCurrent());
    spike_arrow_time = TimeCurrent();
    spike_arrow_blink = true;
    
    ObjectCreate(0, spike_arrow_name, OBJ_ARROW_UP, 0, spike_arrow_time, current_price);
    ObjectSetInteger(0, spike_arrow_name, OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, spike_arrow_name, OBJPROP_WIDTH, 5);
    ObjectSetInteger(0, spike_arrow_name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
    ObjectSetString(0, spike_arrow_name, OBJPROP_TEXT, "🚨 SPIKE");
    
    Print("🚨 FLÈCHE DE SPIKE CRÉÉE - Clignotement activé");
}

//+------------------------------------------------------------------+
//| Gérer le clignotement de la flèche de spike                        |
//+------------------------------------------------------------------+
void UpdateSpikeArrow()
{
    if(!spike_arrow_blink || spike_arrow_name == "")
        return;
    
    datetime current_time = TimeCurrent();
    
    // Clignoter toutes les secondes
    if(current_time - spike_arrow_time >= 1)
    {
        color new_color = (ObjectGetInteger(0, spike_arrow_name, OBJPROP_COLOR) == clrYellow) ? clrOrange : clrYellow;
        ObjectSetInteger(0, spike_arrow_name, OBJPROP_COLOR, new_color);
        spike_arrow_time = current_time;
    }
    
    // Supprimer après 30 secondes
    if(current_time - ObjectGetInteger(0, spike_arrow_name, OBJPROP_TIME) >= 30)
    {
        ObjectDelete(0, spike_arrow_name);
        spike_arrow_name = "";
        spike_arrow_blink = false;
    }
}

//+------------------------------------------------------------------+
//| Gérer les positions existantes                                     |
//+------------------------------------------------------------------+
void ManagePositions()
{
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelectByIndex(i))
        {
            if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
               PositionGetInteger(POSITION_MAGIC) == MagicNumber)
            {
                double profit = PositionGetDouble(POSITION_PROFIT);
                double swap = PositionGetDouble(POSITION_SWAP);
                double commission = PositionGetDouble(POSITION_COMMISSION);
                double total_profit = profit + swap + commission;
                
                // Fermer si profit cible atteint
                if(total_profit >= SpikeProfit_USD)
                {
                    trade.PositionClose(PositionGetTicket(POSITION_TICKET));
                    Print("💰 Position fermée - Profit cible atteint: ", DoubleToString(total_profit, 2), " USD");
                    continue;
                }
                
                // Fermer si perte maximale atteinte
                if(total_profit <= -MaxLoss_USD)
                {
                    trade.PositionClose(PositionGetTicket(POSITION_TICKET));
                    Print("🛑 Position fermée - Perte maximale atteinte: ", DoubleToString(total_profit, 2), " USD");
                    continue;
                }
            }
        }
    }
    
    // Ouvrir nouvelles positions selon signaux IA
    OpenNewPositions();
}

//+------------------------------------------------------------------+
//| Ouvrir de nouvelles positions                                      |
//+------------------------------------------------------------------+
void OpenNewPositions()
{
    if(PositionsTotal() > 0) return; // Une position à la fois
    
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Vérifier les signaux techniques
    bool is_boom = (StringFind(_Symbol, "Boom") >= 0);
    bool is_crash = (StringFind(_Symbol, "Crash") >= 0);
    
    if(ArraySize(ma_buffer) < 1 || ArraySize(rsi_buffer) < 1)
        return;
    
    double ma_value = ma_buffer[0];
    double rsi_value = rsi_buffer[0];
    
    // Signaux techniques
    bool tech_buy = (current_price > ma_value && rsi_value < RSI_Oversold);
    bool tech_sell = (current_price < ma_value && rsi_value > RSI_Overbought);
    
    // Signaux IA
    bool ai_buy = (current_ai_signal.action == "BUY" && current_ai_signal.confidence > 0.5);
    bool ai_sell = (current_ai_signal.action == "SELL" && current_ai_signal.confidence > 0.5);
    
    // Logique d'ouverture
    if(is_boom)
    {
        // Boom: seulement BUY
        if(tech_buy && ai_buy)
        {
            if(trade.Buy(LotSize, _Symbol, ask, 0, 0, "Ultimate Boom BUY"))
            {
                Print("🚀 BOOM BUY OUVERT - Signal technique + IA");
                CreateSpikeArrow(); // Flèche de spike
            }
        }
    }
    else if(is_crash)
    {
        // Crash: seulement SELL
        if(tech_sell && ai_sell)
        {
            if(trade.Sell(LotSize, _Symbol, bid, 0, 0, "Ultimate Crash SELL"))
            {
                Print("🚀 CRASH SELL OUVERT - Signal technique + IA");
                CreateSpikeArrow(); // Flèche de spike
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Nettoyer les objets graphiques                                   |
//+------------------------------------------------------------------+
void CleanChartObjects()
{
    for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
    {
        string obj_name = ObjectName(0, i, -1, -1);
        if(StringFind(obj_name, "Ultimate_") >= 0)
        {
            ObjectDelete(0, obj_name);
        }
    }
}
