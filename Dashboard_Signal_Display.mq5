//| Dashboard_Signal_Display.mq5 - Affiche signaux ML sur le graphique
//| Script simple - Attache sur n'importe quel graphique
//| Récupère les signaux du serveur ML et les affiche en temps réel

#property script_show_inputs

input string API_URL = "http://127.0.0.1:8000";
input string RENDER_URL = "https://kolatradebot-7ofl.onrender.com";
input int    UpdateIntervalSec = 5;

struct MLSignal {
    string symbol;
    string signal;
    double confidence;
    double accuracy;
    string model_name;
    string pattern_name;
    datetime timestamp;
};

// Récupère le signal ML via HTTP
bool FetchMLSignal(string symbol, MLSignal &sig) {
    char response[];
    string url = API_URL + "/ml/signal?symbol=" + symbol + "&timeframe=M1";

    // Essayer local
    int res = WebRequest("GET", url, "", NULL, 500, response, NULL);

    if (res != 200) {
        // Fallback Render
        url = RENDER_URL + "/ml/signal?symbol=" + symbol + "&timeframe=M1";
        res = WebRequest("GET", url, "", NULL, 500, response, NULL);
    }

    if (res == 200) {
        string response_str = CharArrayToString(response);

        sig.symbol = symbol;
        sig.signal = ExtractJsonString(response_str, "\"signal\":\"");
        sig.confidence = StringToDouble(ExtractJsonValue(response_str, "\"confidence\":"));
        sig.accuracy = StringToDouble(ExtractJsonValue(response_str, "\"accuracy\":"));
        sig.model_name = ExtractJsonString(response_str, "\"model_name\":\"");
        sig.pattern_name = ExtractJsonString(response_str, "\"pattern_name\":\"");
        sig.timestamp = TimeCurrent();

        return true;
    }

    return false;
}

// Extrait une valeur string JSON
string ExtractJsonString(string json, string key) {
    int pos = StringFind(json, key);
    if (pos == -1) return "";

    pos += StringLen(key);
    int end = StringFind(json, "\"", pos);
    if (end == -1) return "";

    return StringSubstr(json, pos, end - pos);
}

// Extrait une valeur numérique JSON
string ExtractJsonValue(string json, string key) {
    int pos = StringFind(json, key);
    if (pos == -1) return "";

    pos += StringLen(key);
    int end = StringFind(json, ",", pos);
    if (end == -1) end = StringFind(json, "}", pos);
    if (end == -1) return "";

    return StringSubstr(json, pos, end - pos);
}

// Affiche les signaux sur le graphique
void DisplaySignals() {
    MLSignal sig;

    if (!FetchMLSignal(_Symbol, sig)) {
        Comment("Unable to fetch ML signal for ", _Symbol);
        return;
    }

    // Déterminer couleur par signal
    color signal_color = clrYellow;
    if (sig.signal == "BUY") signal_color = clrLimeGreen;
    else if (sig.signal == "SELL") signal_color = clrRed;
    else if (sig.signal == "HOLD") signal_color = clrOrange;

    // Afficher les infos
    Comment(
        "═════════════════════════════════\n",
        "📊 ML SIGNAL: ", sig.signal, "\n",
        "═════════════════════════════════\n",
        "Confidence: ", DoubleToString(sig.confidence * 100, 1), "%\n",
        "Accuracy:   ", DoubleToString(sig.accuracy, 1), "%\n",
        "Model:      ", sig.model_name, "\n",
        "Pattern:    ", sig.pattern_name, "\n",
        "Updated:    ", TimeToString(sig.timestamp, TIME_DATE|TIME_SECONDS)
    );

    // Label sur graphique (coin haut droit)
    string label_name = "ML_SIGNAL_LABEL";

    if (ObjectFind(0, label_name) == -1) {
        ObjectCreate(0, label_name, OBJ_LABEL, 0, 0, 0);
    }

    ObjectSetInteger(0, label_name, OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, label_name, OBJPROP_YDISTANCE, 20);
    ObjectSetString(0, label_name, OBJPROP_TEXT, sig.signal);
    ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 14);
    ObjectSetInteger(0, label_name, OBJPROP_FONT, "Arial");
    ObjectSetInteger(0, label_name, OBJPROP_COLOR, signal_color);
}

void OnStart() {
    // Script infini - afficher les signaux continuellement
    while (!IsStopped()) {
        DisplaySignals();
        Sleep(UpdateIntervalSec * 1000);
    }
}
