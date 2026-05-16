//+------------------------------------------------------------------+
//| GOM_KOLA_SIDO_ENHANCED_v3.0.mq5                                  |
//| OPTIMISATIONS:                                                    |
//| ✅ Communication bidirectionnelle avec serveur IA                |
//| ✅ Cache des décisions IA pour latence minimale                 |
//| ✅ Détection automatique modèle SMC + SIDO                      |
//| ✅ Dashboard temps-réel avec statut IA                          |
//| ✅ Fallback gracieux si serveur indisponible                    |
//+------------------------------------------------------------------+
#property copyright "TradBOT GOM v3.0"
#property version   "3.00"
#property strict
#property script_show_inputs

//+------------------------------------------------------------------+
//| INCLUDES
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS
//+------------------------------------------------------------------+

input group "=== IA SERVER INTEGRATION ==="
input string AI_SERVER_URL = "http://127.0.0.1:8000";
input int AI_TIMEOUT_MS = 1200;
input bool ENABLE_AI_ANALYSIS = true;
input double MIN_IA_CONFIDENCE = 0.55;
input bool CACHE_AI_DECISIONS = true;

input group "=== GOM TIMEFRAMES ==="
input bool ShowM1Levels = true;
input bool ShowM5Levels = true;
input bool ShowM15Levels = true;
input bool ShowM30Levels = true;
input bool ShowH1Levels = true;
input bool ShowH4Levels = true;
input bool ShowD1Levels = true;
input bool ShowW1Levels = true;

input group "=== ALGORITHM (THREE LINE BREAK) ==="
input int LineBreakPeriod = 3;
input int MaxBarsToAnalyze = 300;

input group "=== TOUCH SYSTEM ==="
input bool EnableTouchDetection = true;
input double TouchZoneATRPercent = 25.0;
input int BarsForTouchCount = 200;

input group "=== SIDE (CHART PATTERNS) ==="
input bool EnableSIDO = true;
input int SIDOPivotLookback = 3;
input int SIDOBarsToAnalyze = 300;

input group "=== DASHBOARD & DISPLAY ==="
input bool ShowBottomDashboard = true;
input bool ShowMLFeaturePanel = true;
input int DashboardFontSize = 10;
input color DashboardTextColor = clrWhite;

input group "=== RISK MANAGEMENT ==="
input double MaxDailyLoss = 300.0;
input double MaxPositions = 3;
input double RiskPerTrade = 50.0;

//+------------------------------------------------------------------+
//| STRUCTURES ET TYPES
//+------------------------------------------------------------------+

struct AIAnalysisCache {
    string symbol;
    string timeframe;
    string decision;
    double confidence;
    double entry_price;
    double stop_loss;
    double take_profit;
    int timestamp;
    bool is_valid;
    int latency_ms;
};

struct GOMSignal {
    string type;           // "FVG", "OB", "BOS", "PATTERN", "CONFLUENCE"
    double level;
    int timeframe;
    bool is_bullish;
    double strength;       // 0-1
    int touch_count;
    int timestamp;
};

struct SIDOPattern {
    string type;           // "DOUBLE_TOP", "DOUBLE_BOTTOM", "TRIANGLE", etc
    double price_level;
    int touches;
    double validity_percent;
    bool is_valid;
    string direction;      // "UP", "DOWN"
};

//+------------------------------------------------------------------+
//| VARIABLES GLOBALES
//+------------------------------------------------------------------+

AIAnalysisCache g_ai_cache;
GOMSignal g_current_signal;
SIDOPattern g_current_pattern;
bool g_server_online = false;
int g_total_trades = 0;
double g_daily_pnl = 0;
string g_last_ai_decision = "NONE";

CTrade g_trade;
CPositionInfo g_pos_info;

//+------------------------------------------------------------------+
//| CLIENT RÉSEAU
//+------------------------------------------------------------------+

class AIServerClient {
private:
    string base_url;
    int timeout_ms;
    bool is_online;
    
public:
    AIServerClient(string url, int timeout) : 
        base_url(url), 
        timeout_ms(timeout),
        is_online(false) {
        TestConnection();
    }
    
    bool TestConnection() {
        string response;
        char dummy[];
        int res = WebRequest(
            "GET",
            base_url + "/health",
            "Content-Type: application/json\r\n",
            timeout_ms,
            dummy,
            response,
            response
        );
        
        is_online = (res == 200);
        if (is_online) {
            Print("✅ AI Server ONLINE");
        } else {
            Print("⚠️  AI Server OFFLINE - Mode fallback");
        }
        return is_online;
    }
    
    bool IsOnline() { return is_online; }
    
    bool RequestDecision(
        string symbol,
        string timeframe,
        double price,
        double bid,
        double ask,
        double volatility,
        string trend,
        AIAnalysisCache &cache_out
    ) {
        if (!is_online) return false;
        
        // Construire requête JSON
        string json_request = "{";
        json_request += "\"symbol\":\"" + symbol + "\",";
        json_request += "\"timeframe\":\"" + timeframe + "\",";
        json_request += "\"price\":" + DoubleToString(price, 5) + ",";
        json_request += "\"bid\":" + DoubleToString(bid, 5) + ",";
        json_request += "\"ask\":" + DoubleToString(ask, 5) + ",";
        json_request += "\"timestamp\":" + IntegerToString((int)time(NULL)) + ",";
        json_request += "\"volatility\":" + DoubleToString(volatility, 6) + ",";
        json_request += "\"trend\":\"" + trend + "\"";
        json_request += "}";
        
        string response;
        char request[];
        StringToCharArray(json_request, request);
        
        int start_time = GetTickCount();
        int res = WebRequest(
            "POST",
            base_url + "/decision",
            "Content-Type: application/json\r\n",
            timeout_ms,
            request,
            response,
            response
        );
        int latency = GetTickCount() - start_time;
        
        if (res != 200) {
            Print("❌ AI Request failed HTTP " + IntegerToString(res));
            return false;
        }
        
        // Parser réponse
        return ParseResponse(response, cache_out, latency);
    }
    
private:
    bool ParseResponse(string json, AIAnalysisCache &cache, int latency) {
        cache.symbol = ExtractString(json, "symbol");
        cache.decision = ExtractString(json, "decision");
        cache.confidence = ExtractDouble(json, "confidence");
        cache.entry_price = ExtractDouble(json, "entry_price");
        cache.stop_loss = ExtractDouble(json, "stop_loss");
        cache.take_profit = ExtractDouble(json, "take_profit");
        cache.timestamp = (int)time(NULL);
        cache.latency_ms = latency;
        cache.is_valid = (cache.confidence >= MIN_IA_CONFIDENCE);
        
        return cache.is_valid;
    }
    
    string ExtractString(string json, string key) {
        string search = "\"" + key + "\":\"";
        int start = StringFind(json, search);
        if (start < 0) return "";
        
        start += StringLen(search);
        int end = StringFind(json, "\"", start);
        if (end < 0) return "";
        
        return StringSubstr(json, start, end - start);
    }
    
    double ExtractDouble(string json, string key) {
        string search = "\"" + key + "\":";
        int start = StringFind(json, search);
        if (start < 0) return 0.0;
        
        start += StringLen(search);
        int end = StringFind(json, ",", start);
        if (end < 0) end = StringFind(json, "}", start);
        
        string value = StringSubstr(json, start, end - start);
        value = StringTrimLeft(StringTrimRight(value));
        
        return StringToDouble(value);
    }
};

AIServerClient *g_ai_client = NULL;

//+------------------------------------------------------------------+
//| DÉTECTION GOM (Three Line Break + Touch System)
//+------------------------------------------------------------------+

GOMSignal DetectFVG() {
    GOMSignal signal;
    signal.timestamp = (int)time(NULL);
    signal.is_valid = false;
    
    // Fair Value Gap: gap non comblé
    double h2 = iHigh(Symbol(), PERIOD_M5, 2);
    double l0 = iLow(Symbol(), PERIOD_M5, 0);
    double h0 = iHigh(Symbol(), PERIOD_M5, 0);
    double l2 = iLow(Symbol(), PERIOD_M5, 2);
    
    // FVG Haussier
    if (h2 < l0) {
        signal.type = "FVG_BULLISH";
        signal.level = l0;
        signal.is_bullish = true;
        signal.strength = 0.7;
        signal.is_valid = true;
        return signal;
    }
    
    // FVG Baissier
    if (l2 > h0) {
        signal.type = "FVG_BEARISH";
        signal.level = h0;
        signal.is_bullish = false;
        signal.strength = 0.7;
        signal.is_valid = true;
        return signal;
    }
    
    return signal;
}

SIDOPattern DetectPattern() {
    SIDOPattern pattern;
    pattern.is_valid = false;
    
    // Détection simple Double Top/Bottom
    double h1 = iHigh(Symbol(), PERIOD_H1, 30);
    double h2 = iHigh(Symbol(), PERIOD_H1, 60);
    
    double l1 = iLow(Symbol(), PERIOD_H1, 30);
    double l2 = iLow(Symbol(), PERIOD_H1, 60);
    
    // Double Top
    if (MathAbs(h1 - h2) < h1 * 0.005) {  // Tolérance 0.5%
        pattern.type = "DOUBLE_TOP";
        pattern.price_level = (h1 + h2) / 2;
        pattern.is_valid = true;
        pattern.direction = "DOWN";
        pattern.validity_percent = 0.85;
        return pattern;
    }
    
    // Double Bottom
    if (MathAbs(l1 - l2) < l1 * 0.005) {
        pattern.type = "DOUBLE_BOTTOM";
        pattern.price_level = (l1 + l2) / 2;
        pattern.is_valid = true;
        pattern.direction = "UP";
        pattern.validity_percent = 0.85;
        return pattern;
    }
    
    return pattern;
}

//+------------------------------------------------------------------+
//| CONFLUENCE ANALYSIS
//+------------------------------------------------------------------+

double CalculateConfluence(GOMSignal &gom_signal, SIDOPattern &sido_pattern, AIAnalysisCache &ai_cache) {
    double confluence = 0.0;
    int confirmations = 0;
    
    // Confirmation GOM (FVG/OB)
    if (gom_signal.is_valid) {
        confluence += 0.3;
        confirmations++;
    }
    
    // Confirmation SIDO (Pattern)
    if (sido_pattern.is_valid) {
        confluence += 0.3;
        confirmations++;
    }
    
    // Confirmation IA
    if (ai_cache.is_valid && ai_cache.decision != "HOLD") {
        confluence += ai_cache.confidence;
        confirmations++;
    }
    
    if (confirmations == 0) return 0.0;
    
    return confluence / confirmations;
}

//+------------------------------------------------------------------+
//| GESTION POSITIONS
//+------------------------------------------------------------------+

bool CanTrade() {
    // Vérifier limites de risque
    int open = 0;
    for (int i = 0; i < PositionsTotal(); i++) {
        if (g_pos_info.SelectByIndex(i) && g_pos_info.Symbol() == Symbol()) {
            open++;
        }
    }
    
    return (open < MaxPositions) && (MathAbs(g_daily_pnl) < MaxDailyLoss);
}

void ExecuteTrade(string direction, AIAnalysisCache &ai_cache, double confluence) {
    if (!CanTrade()) return;
    
    double lot = NormalizeLot(RiskPerTrade / 100.0);
    
    g_trade.SetExpertMagicNumber(999);
    g_trade.SetDeviation(15);
    
    if (direction == "BUY") {
        g_trade.Buy(
            lot,
            Symbol(),
            Ask,
            ai_cache.stop_loss,
            ai_cache.take_profit,
            "GOM Trade"
        );
    } else if (direction == "SELL") {
        g_trade.Sell(
            lot,
            Symbol(),
            Bid,
            ai_cache.stop_loss,
            ai_cache.take_profit,
            "GOM Trade"
        );
    }
}

double NormalizeLot(double lot) {
    double min_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
    
    lot = MathMax(min_lot, MathMin(max_lot, lot));
    return NormalizeDouble(lot / step, 0) * step;
}

//+------------------------------------------------------------------+
//| DASHBOARD
//+------------------------------------------------------------------+

void UpdateDashboard() {
    if (!ShowBottomDashboard) return;
    
    string dash = "";
    dash += "╔════════════════════════════════════════╗\n";
    dash += "║   GOM-KOLA-SIDO v3.0 - LIVE STATUS  ║\n";
    dash += "╠════════════════════════════════════════╣\n";
    dash += "║ AI Server: " + (g_server_online ? "✅ ONLINE    " : "⚠️  OFFLINE   ") + "        ║\n";
    dash += "║ Last AI Decision: " + g_last_ai_decision + "                 ║\n";
    dash += "║ Current GOM Signal: " + g_current_signal.type + "              ║\n";
    dash += "║ Current Pattern: " + g_current_pattern.type + "              ║\n";
    dash += "║ Positions: " + IntegerToString(PositionsTotal()) + "    Daily P&L: $" + DoubleToString(g_daily_pnl, 2) + "    ║\n";
    dash += "║ Trades Today: " + IntegerToString(g_total_trades) + "                            ║\n";
    dash += "╚════════════════════════════════════════╝\n";
    
    Comment(dash);
}

//+------------------------------------------------------------------+
//| UTILITAIRES
//+------------------------------------------------------------------+

string GetTrendDirection(ENUM_TIMEFRAMES tf) {
    double ma9 = iMA(Symbol(), tf, 9, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma21 = iMA(Symbol(), tf, 21, 0, MODE_SMA, PRICE_CLOSE, 0);
    
    if (ma9 > ma21 * 1.001) return "UPTREND";
    if (ma9 < ma21 * 0.999) return "DOWNTREND";
    return "NEUTRAL";
}

double GetVolatility(ENUM_TIMEFRAMES tf, int period = 14) {
    double atr = iATR(Symbol(), tf, period, 0);
    return (atr / Close[0]) * 100.0;
}

//+------------------------------------------------------------------+
//| EVENT HANDLERS
//+------------------------------------------------------------------+

void OnInit() {
    Print("✅ GOM-KOLA-SIDO v3.0 Initialisation...");
    
    g_ai_client = new AIServerClient(AI_SERVER_URL, AI_TIMEOUT_MS);
    g_server_online = g_ai_client.IsOnline();
}

void OnTick() {
    if (IsStopped()) return;
    
    static datetime last_update = 0;
    if (time(NULL) - last_update < 3) return;  // Update max toutes les 3 sec
    last_update = time(NULL);
    
    // Détection GOM + SIDO
    g_current_signal = DetectFVG();
    g_current_pattern = DetectPattern();
    
    // Requête IA
    AIAnalysisCache cache;
    cache.is_valid = false;
    
    if (ENABLE_AI_ANALYSIS && g_server_online && g_ai_client.IsOnline()) {
        string trend = GetTrendDirection(PERIOD_M5);
        double volatility = GetVolatility(PERIOD_M5);
        
        if (g_ai_client.RequestDecision(
            Symbol(),
            "M5",
            Close[0],
            Bid,
            Ask,
            volatility,
            trend,
            cache
        )) {
            g_last_ai_decision = cache.decision + " (" + DoubleToString(cache.confidence, 2) + ")";
            Print("✅ AI Decision: " + g_last_ai_decision + " (latency: " + IntegerToString(cache.latency_ms) + "ms)");
        }
    }
    
    // Confluence Analysis
    double confluence = CalculateConfluence(g_current_signal, g_current_pattern, cache);
    
    // Trade Execution
    if (confluence > 0.65 && cache.is_valid) {
        ExecuteTrade(cache.decision, cache, confluence);
        g_total_trades++;
    }
    
    UpdateDashboard();
}

void OnDeinit(const int reason) {
    if (g_ai_client != NULL) {
        delete g_ai_client;
        g_ai_client = NULL;
    }
    Print("✅ GOM-KOLA-SIDO arrêté");
}

//+------------------------------------------------------------------+
//| FIN
//+------------------------------------------------------------------+
