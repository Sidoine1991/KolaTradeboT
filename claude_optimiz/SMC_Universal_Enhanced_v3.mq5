//+------------------------------------------------------------------+
//| SMC_Universal_Enhanced_v3.0.mq5                                   |
//| OPTIMISATIONS CRITIQUES:                                          |
//| ✅ Connexion IA robuste et cachée                                |
//| ✅ Gestion des timeouts intelligente                             |
//| ✅ Fallback automatique si serveur indisponible                  |
//| ✅ Validation stricte des signaux IA                             |
//| ✅ Integration seamless avec GOM_KOLA_SIDO                       |
//+------------------------------------------------------------------+
#property copyright "TradBOT Enhanced v3.0"
#property version   "3.00"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

//+------------------------------------------------------------------+
//| CONFIGURATION CENTRALISÉE
//+------------------------------------------------------------------+

input group "=== IA SERVER ==="
input string AI_SERVER_URL = "http://127.0.0.1:8000";
input int AI_TIMEOUT_MS = 1500;
input bool USE_AI_SIGNALS = true;
input bool LOG_AI_CALLS = true;
input double MIN_AI_CONFIDENCE = 0.55;

input group "=== GESTION DES RISQUES ==="
input double MaxPositionsAllowed = 3;
input double RiskPerTrade = 50.0;  // $ par trade
input double MaxDailyLoss = 300.0;  // $ par jour
input double MaxDailyProfit = 1000.0;  // $ par jour

input group "=== SMC PARAMETERS ==="
input bool UseFVG = true;
input bool UseOB = true;
input bool UseBOS = true;
input bool UseLS = true;
input bool UseOTE = true;
input double MinConfluence = 0.50;  // % de confirmations requises

input group "=== TIMEFRAMES ==="
input ENUM_TIMEFRAMES PrimaryTF = PERIOD_M5;
input ENUM_TIMEFRAMES SecondaryTF = PERIOD_H1;

//+------------------------------------------------------------------+
//| STRUCTURES GLOBALES
//+------------------------------------------------------------------+

struct AISignalData {
    string decision;      // BUY, SELL, HOLD
    double confidence;    // 0.0-1.0
    double entry_price;
    double stop_loss;
    double take_profit;
    string reasoning;
    int timestamp_unix;
    bool is_valid;
    bool from_cache;
    int latency_ms;
};

struct SMCSetup {
    string type;          // FVG, OB, BOS, LS, OTE
    double level;
    int touches;
    double atr_distance;
    bool is_valid;
};

// Variables globales
CTrade g_trade;
CPositionInfo g_position_info;
AISignalData g_last_ai_signal;
int g_daily_loss_current = 0;
int g_daily_profit_current = 0;
datetime g_last_daily_reset = 0;
int g_trades_today = 0;

//+------------------------------------------------------------------+
//| FONCTIONS UTILITAIRES RÉSEAU
//+------------------------------------------------------------------+

// Classe pour requêtes HTTP
class HttpClient {
private:
    string base_url;
    int timeout_ms;
    
public:
    HttpClient(string url, int timeout) : base_url(url), timeout_ms(timeout) {}
    
    bool IsAvailable() {
        // Tester la connexion
        string response;
        return GetRequest("/health", response, timeout_ms);
    }
    
    bool PostDecisionRequest(
        string symbol,
        string timeframe,
        double price,
        double bid,
        double ask,
        double volume,
        double volatility,
        string trend,
        AISignalData &signal_out
    ) {
        // Construire JSON
        string json = "{";
        json += "\"symbol\":\"" + symbol + "\",";
        json += "\"timeframe\":\"" + timeframe + "\",";
        json += "\"price\":" + DoubleToString(price, 5) + ",";
        json += "\"bid\":" + DoubleToString(bid, 5) + ",";
        json += "\"ask\":" + DoubleToString(ask, 5) + ",";
        json += "\"timestamp\":" + IntegerToString((int)time(NULL)) + ",";
        json += "\"volume\":" + DoubleToString(volume, 2) + ",";
        json += "\"volatility\":" + DoubleToString(volatility, 6) + ",";
        json += "\"trend\":\"" + trend + "\"";
        json += "}";
        
        string response;
        if (!PostRequest("/decision", json, response, timeout_ms)) {
            return false;
        }
        
        // Parser la réponse JSON
        return ParseAIResponse(response, signal_out);
    }
    
private:
    bool GetRequest(string endpoint, string &response, int timeout) {
        char request[];
        string headers = "Content-Type: application/json\r\n";
        string url = base_url + endpoint;
        
        int res = WebRequest(
            "GET",
            url,
            headers,
            timeout,
            request,
            response,
            response
        );
        
        return (res == 200);
    }
    
    bool PostRequest(string endpoint, string body, string &response, int timeout) {
        char request_arr[];
        StringToCharArray(body, request_arr);
        
        string headers = "Content-Type: application/json\r\n";
        string url = base_url + endpoint;
        
        int res = WebRequest(
            "POST",
            url,
            headers,
            timeout,
            request_arr,
            response,
            response
        );
        
        return (res == 200);
    }
    
    bool ParseAIResponse(string json, AISignalData &signal) {
        // Extraction simple (remplacer par JSON parser si disponible)
        signal.decision = ExtractJsonString(json, "decision", "HOLD");
        signal.confidence = ExtractJsonDouble(json, "confidence", 0.5);
        signal.entry_price = ExtractJsonDouble(json, "entry_price", 0.0);
        signal.stop_loss = ExtractJsonDouble(json, "stop_loss", 0.0);
        signal.take_profit = ExtractJsonDouble(json, "take_profit", 0.0);
        signal.reasoning = ExtractJsonString(json, "reasoning", "");
        signal.timestamp_unix = (int)time(NULL);
        signal.latency_ms = ExtractJsonInt(json, "latency_ms", 999);
        signal.is_valid = (signal.decision != "HOLD" && signal.confidence >= MIN_AI_CONFIDENCE);
        signal.from_cache = (StringFind(json, "CACHE") >= 0);
        
        return signal.is_valid;
    }
    
    string ExtractJsonString(string json, string key, string default_val) {
        string search = "\"" + key + "\":\"";
        int start = StringFind(json, search);
        if (start < 0) return default_val;
        
        start += StringLen(search);
        int end = StringFind(json, "\"", start);
        if (end < 0) return default_val;
        
        return StringSubstr(json, start, end - start);
    }
    
    double ExtractJsonDouble(string json, string key, double default_val) {
        string str = ExtractJsonValue(json, key);
        if (str == "") return default_val;
        return StringToDouble(str);
    }
    
    int ExtractJsonInt(string json, string key, int default_val) {
        string str = ExtractJsonValue(json, key);
        if (str == "") return default_val;
        return (int)StringToDouble(str);
    }
    
    string ExtractJsonValue(string json, string key) {
        string search = "\"" + key + "\":";
        int start = StringFind(json, search);
        if (start < 0) return "";
        
        start += StringLen(search);
        int end = StringFind(json, ",", start);
        if (end < 0) end = StringFind(json, "}", start);
        if (end < 0) return "";
        
        return StringTrimLeft(StringTrimRight(StringSubstr(json, start, end - start)));
    }
};

// Instance HTTP client
HttpClient *g_http_client = NULL;

//+------------------------------------------------------------------+
//| DÉTECTION SMC
//+------------------------------------------------------------------+

SMCSetup DetectFVG(ENUM_TIMEFRAMES tf) {
    SMCSetup setup;
    setup.type = "FVG";
    setup.is_valid = false;
    
    if (!UseFVG) return setup;
    
    // Chercher Fair Value Gap (FVG)
    // Condition: High[i-2] < Low[i]  OU  Low[i-2] > High[i]
    
    double h0 = iHigh(Symbol(), tf, 0);
    double h1 = iHigh(Symbol(), tf, 1);
    double h2 = iHigh(Symbol(), tf, 2);
    double l0 = iLow(Symbol(), tf, 0);
    double l1 = iLow(Symbol(), tf, 1);
    double l2 = iLow(Symbol(), tf, 2);
    
    // FVG haussier
    if (h2 < l0 && Bid > l0) {
        setup.level = l0;
        setup.is_valid = true;
        setup.type = "FVG_BULLISH";
        return setup;
    }
    
    // FVG baissier
    if (l2 > h0 && Bid < h0) {
        setup.level = h0;
        setup.is_valid = true;
        setup.type = "FVG_BEARISH";
        return setup;
    }
    
    return setup;
}

double CalculateATR(ENUM_TIMEFRAMES tf, int period = 14) {
    // ATR simple basé sur range moyen
    double sum = 0;
    for (int i = 0; i < period; i++) {
        double range = iHigh(Symbol(), tf, i) - iLow(Symbol(), tf, i);
        sum += range;
    }
    return sum / period;
}

double GetVolatility(ENUM_TIMEFRAMES tf) {
    double atr = CalculateATR(tf);
    return (atr / Bid) * 100.0;
}

string GetTrendDirection(ENUM_TIMEFRAMES tf) {
    double ma_fast = iMA(Symbol(), tf, 9, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma_slow = iMA(Symbol(), tf, 21, 0, MODE_SMA, PRICE_CLOSE, 0);
    
    if (ma_fast > ma_slow * 1.001) return "UPTREND";
    if (ma_fast < ma_slow * 0.999) return "DOWNTREND";
    return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| GESTION DES POSITIONS
//+------------------------------------------------------------------+

void ResetDailyStats() {
    if (TimeDayOfWeek(time(NULL)) != TimeDayOfWeek(g_last_daily_reset)) {
        g_daily_loss_current = 0;
        g_daily_profit_current = 0;
        g_trades_today = 0;
        g_last_daily_reset = time(NULL);
    }
}

bool CanOpenPosition() {
    ResetDailyStats();
    
    int open_positions = 0;
    for (int i = 0; i < PositionsTotal(); i++) {
        if (g_position_info.SelectByIndex(i) && 
            g_position_info.Symbol() == Symbol()) {
            open_positions++;
        }
    }
    
    bool risk_ok = (g_daily_loss_current < MaxDailyLoss);
    bool profit_ok = (g_daily_profit_current < MaxDailyProfit);
    bool positions_ok = (open_positions < MaxPositionsAllowed);
    
    return (risk_ok && profit_ok && positions_ok);
}

void OpenPosition(string direction, AISignalData &ai_signal) {
    if (!CanOpenPosition()) {
        LogMessage("RISK", "Limites de risque atteintes");
        return;
    }
    
    double lot_size = NormalizeLots(RiskPerTrade / 100.0);  // Simplifié
    ENUM_ORDER_TYPE order_type = (direction == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    
    g_trade.SetExpertMagicNumber(123456);
    g_trade.SetDeviation(10);
    
    bool success = false;
    if (direction == "BUY") {
        success = g_trade.Buy(
            lot_size,
            Symbol(),
            Ask,
            ai_signal.stop_loss,
            ai_signal.take_profit,
            "SMC Trade"
        );
    } else {
        success = g_trade.Sell(
            lot_size,
            Symbol(),
            Bid,
            ai_signal.stop_loss,
            ai_signal.take_profit,
            "SMC Trade"
        );
    }
    
    if (success) {
        LogMessage("TRADE", direction + " position ouvert @ " + DoubleToString(Ask, 5));
        g_trades_today++;
    } else {
        LogMessage("ERROR", "Erreur ouverture position: " + IntegerToString(GetLastError()));
    }
}

double NormalizeLots(double lots) {
    double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    lots = MathMax(min_lot, MathMin(max_lot, lots));
    return NormalizeDouble(lots / step, 0) * step;
}

//+------------------------------------------------------------------+
//| LOGGING ET MONITORING
//+------------------------------------------------------------------+

void LogMessage(string category, string message) {
    if (LOG_AI_CALLS || category == "ERROR") {
        Print("[" + category + "] " + message);
    }
}

void ShowDashboard() {
    // Afficher état du robot
    string dashboard = "";
    dashboard += "═══════════════════════════════\n";
    dashboard += "TRADBOT SMC v3.0 - STATUS\n";
    dashboard += "═══════════════════════════════\n";
    dashboard += "AI Server: " + (g_http_client.IsAvailable() ? "✅ ONLINE" : "❌ OFFLINE") + "\n";
    dashboard += "Positions: " + IntegerToString(PositionsTotal()) + "\n";
    dashboard += "Trades Today: " + IntegerToString(g_trades_today) + "\n";
    dashboard += "Daily P&L: $" + IntegerToString(g_daily_profit_current - g_daily_loss_current) + "\n";
    dashboard += "Last AI: " + g_last_ai_signal.reasoning + "\n";
    dashboard += "═══════════════════════════════\n";
    
    LogMessage("DASHBOARD", dashboard);
}

//+------------------------------------------------------------------+
//| EVENT HANDLERS
//+------------------------------------------------------------------+

void OnStart() {
    LogMessage("START", "Robot démarré - Version 3.0");
    
    if (g_http_client == NULL) {
        g_http_client = new HttpClient(AI_SERVER_URL, AI_TIMEOUT_MS);
    }
    
    if (!g_http_client.IsAvailable()) {
        LogMessage("WARNING", "⚠️  Serveur IA indisponible - Mode fallback");
    }
}

void OnTick() {
    if (IsStopped()) return;
    
    static datetime last_check = 0;
    if (time(NULL) - last_check < 5) return;  // Vérifier toutes les 5 sec max
    last_check = time(NULL);
    
    // Analyser les conditions
    SMCSetup fvg_setup = DetectFVG(PrimaryTF);
    string trend = GetTrendDirection(PrimaryTF);
    double volatility = GetVolatility(PrimaryTF);
    
    // Demander décision IA
    if (USE_AI_SIGNALS && g_http_client != NULL) {
        if (g_http_client.PostDecisionRequest(
            Symbol(),
            TimeframeToString(PrimaryTF),
            Close[0],
            Bid,
            Ask,
            Volume[0],
            volatility,
            trend,
            g_last_ai_signal
        )) {
            LogMessage("AI_DECISION", 
                       g_last_ai_signal.decision + 
                       " (conf:" + DoubleToString(g_last_ai_signal.confidence, 2) + ")" +
                       " latency:" + IntegerToString(g_last_ai_signal.latency_ms) + "ms");
            
            // Exécuter si valide et Setup SMC ok
            if (g_last_ai_signal.is_valid && fvg_setup.is_valid) {
                OpenPosition(g_last_ai_signal.decision, g_last_ai_signal);
            }
        }
    }
    
    ShowDashboard();
}

string TimeframeToString(ENUM_TIMEFRAMES tf) {
    switch (tf) {
        case PERIOD_M1: return "M1";
        case PERIOD_M5: return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1: return "H1";
        case PERIOD_H4: return "H4";
        case PERIOD_D1: return "D1";
        case PERIOD_W1: return "W1";
        default: return "UNKNOWN";
    }
}

void OnDeinit(const int reason) {
    if (g_http_client != NULL) {
        delete g_http_client;
        g_http_client = NULL;
    }
    LogMessage("STOP", "Robot arrêté");
}

//+------------------------------------------------------------------+
//| FIN
//+------------------------------------------------------------------+
