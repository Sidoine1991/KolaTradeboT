//| EA_Dashboard_Sync.mqh - Synchronisation EA ↔ Dashboard ML
//| Envoie infos de l'EA au dashboard et récupère signaux ML

#ifndef EA_DASHBOARD_SYNC_MQH
#define EA_DASHBOARD_SYNC_MQH

#include <Trade/SymbolInfo.mqh>

// URLs des serveurs
const string DASHBOARD_LOCAL_URL = "http://127.0.0.1:8000";
const string DASHBOARD_RENDER_URL = "https://kolatradebot-7ofl.onrender.com";

// Structure pour stocker le signal ML
struct MLSignal {
    string symbol;
    string signal;        // "BUY", "SELL", "HOLD"
    double confidence;
    double accuracy;
    string model_name;
    string pattern_name;
    double pattern_score;
    int total_samples;
    datetime timestamp;
};

// Récupère le signal ML pour un symbole
bool GetMLSignal(string symbol, MLSignal &sig) {
    char response[];
    string url = DASHBOARD_LOCAL_URL + "/ml/signal?symbol=" + symbol + "&timeframe=M1";

    // Essayer local d'abord
    int res = WebRequest("GET", url, "", NULL, 500, response, NULL);
    if (res != 200 && res != -1) {
        // Fallback à Render
        url = DASHBOARD_RENDER_URL + "/ml/signal?symbol=" + symbol + "&timeframe=M1";
        res = WebRequest("GET", url, "", NULL, 500, response, NULL);
    }

    if (res == 200) {
        // Parser JSON (simple parser pour champs clés)
        string response_str = CharArrayToString(response);

        sig.symbol = symbol;
        sig.signal = ExtractJsonValue(response_str, "\"signal\":\"", "\"");
        sig.confidence = StringToDouble(ExtractJsonValue(response_str, "\"confidence\":", ","));
        sig.accuracy = StringToDouble(ExtractJsonValue(response_str, "\"accuracy\":", ","));
        sig.model_name = ExtractJsonValue(response_str, "\"model_name\":\"", "\"");
        sig.pattern_name = ExtractJsonValue(response_str, "\"pattern_name\":\"", "\"");
        sig.pattern_score = StringToDouble(ExtractJsonValue(response_str, "\"score\":", ","));
        sig.total_samples = (int)StringToDouble(ExtractJsonValue(response_str, "\"total_samples\":", ","));
        sig.timestamp = TimeCurrent();

        return true;
    }

    return false;
}

// Envoie les infos de l'EA au dashboard (optionnel pour stats)
bool SendEAStatus(string symbol, string action, double price, double sl, double tp,
                   double risk_pct, string reason) {
    // Construire JSON
    string json = "{\"symbol\":\"" + symbol + "\","
                 "\"action\":\"" + action + "\","
                 "\"price\":" + DoubleToString(price, 5) + ","
                 "\"sl\":" + DoubleToString(sl, 5) + ","
                 "\"tp\":" + DoubleToString(tp, 5) + ","
                 "\"risk_pct\":" + DoubleToString(risk_pct, 2) + ","
                 "\"reason\":\"" + reason + "\"}";

    char response[];
    string url = DASHBOARD_LOCAL_URL + "/ea/status";

    int res = WebRequest("POST", url, "", json, 500, response, NULL);
    if (res == 200) {
        return true;
    }

    // Fallback non critique
    return false;
}

// Extrait une valeur JSON simple
string ExtractJsonValue(string json, string start_key, string end_char) {
    int start_pos = StringFind(json, start_key);
    if (start_pos == -1) return "";

    start_pos += StringLen(start_key);
    int end_pos = StringFind(json, end_char, start_pos);
    if (end_pos == -1) end_pos = StringLen(json);

    return StringSubstr(json, start_pos, end_pos - start_pos);
}

#endif
