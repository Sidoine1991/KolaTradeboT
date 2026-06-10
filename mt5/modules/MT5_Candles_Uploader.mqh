//+------------------------------------------------------------------+
//| MT5 Candles Uploader Module — Envoie les candles à l'API
//| Version: 2.0 (Fixed MQL5 syntax)
//+------------------------------------------------------------------+

#ifndef MT5_CANDLES_UPLOADER_MQH
#define MT5_CANDLES_UPLOADER_MQH

// Classe pour uploader les candles
class MT5CandlesUploader {
private:
    string aiServerUrl;
    string symbol;
    int timeout_ms;

public:
    // Constructeur
    MT5CandlesUploader(string _symbol, string _serverUrl) {
        symbol = _symbol;
        aiServerUrl = _serverUrl;
        timeout_ms = 5000;
    }

    // Récupère les candles et formate en JSON
    string FormatCandlesJSON(string sym, ENUM_TIMEFRAMES tf, int count = 100) {
        MqlRates rates[];

        int bars = CopyRates(sym, tf, 0, count, rates);
        if (bars <= 0) {
            Print("Error: CopyRates failed for ", sym);
            return "";
        }

        // Construit le JSON
        string json = "{\"symbol\":\"" + sym + "\",\"timeframe\":\"";

        // Ajoute le timeframe
        if (tf == PERIOD_M1) json += "M1";
        else if (tf == PERIOD_M5) json += "M5";
        else if (tf == PERIOD_M15) json += "M15";
        else if (tf == PERIOD_H1) json += "H1";
        else if (tf == PERIOD_H4) json += "H4";
        else if (tf == PERIOD_D1) json += "D1";
        else json += "M1";

        json += "\",\"candles\":[";

        for (int i = 0; i < bars; i++) {
            if (i > 0) json += ",";
            json += "{";
            json += "\"time\":" + IntegerToString((long)rates[i].time) + ",";
            json += "\"open\":" + DoubleToString(rates[i].open, 2) + ",";
            json += "\"high\":" + DoubleToString(rates[i].high, 2) + ",";
            json += "\"low\":" + DoubleToString(rates[i].low, 2) + ",";
            json += "\"close\":" + DoubleToString(rates[i].close, 2) + ",";
            json += "\"volume\":" + IntegerToString((long)rates[i].tick_volume);
            json += "}";
        }

        json += "]}";
        return json;
    }

    // Envoie les candles à l'API
    bool UploadCandles(string sym, ENUM_TIMEFRAMES tf, int count = 100) {
        string json = FormatCandlesJSON(sym, tf, count);

        if (json == "") {
            Print("Error: JSON formatting failed");
            return false;
        }

        // Crée la requête HTTP
        string url = aiServerUrl + "/mt5/upload-candles";
        string headers = "Content-Type: application/json\r\n";

        uchar data[];
        uchar result[];

        int len = StringLen(json);
        ArrayResize(data, len);
        for (int i = 0; i < len; i++) {
            data[i] = (uchar)StringGetCharacter(json, i);
        }

        Print("[UPLOAD] Sending ", count, " candles for ", sym, " to ", url);

        // Envoie la requête
        int response_code = WebRequest("POST", url, headers, timeout_ms, data, result);

        if (response_code == 200) {
            Print("OK: Candles uploaded for ", sym);
            return true;
        } else {
            Print("ERROR: Upload failed. Code: ", response_code);
            return false;
        }
    }

    // Envoie les candles pour tous les timeframes
    bool UploadAllTimeframes(string sym) {
        bool success = true;

        if (!UploadCandles(sym, PERIOD_M1, 100)) success = false;
        Sleep(500);
        if (!UploadCandles(sym, PERIOD_M5, 100)) success = false;
        Sleep(500);
        if (!UploadCandles(sym, PERIOD_M15, 100)) success = false;
        Sleep(500);
        if (!UploadCandles(sym, PERIOD_H1, 100)) success = false;
        Sleep(500);
        if (!UploadCandles(sym, PERIOD_H4, 100)) success = false;
        Sleep(500);
        if (!UploadCandles(sym, PERIOD_D1, 100)) success = false;

        return success;
    }
};

#endif
