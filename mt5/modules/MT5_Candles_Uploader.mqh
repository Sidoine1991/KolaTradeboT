//+------------------------------------------------------------------+
//| MT5 Candles Uploader Module — Envoie les candles à l'API
//| Version: 1.0
//+------------------------------------------------------------------+

#ifndef MT5_CANDLES_UPLOADER_MQH
#define MT5_CANDLES_UPLOADER_MQH

#include <WinAPI/winsock.mqh>

// Structure pour une candle
struct CandleData {
    long time;      // Unix timestamp
    double open;
    double high;
    double low;
    double close;
    long volume;
};

class MT5CandlesUploader {
private:
    string aiServerUrl;
    string symbol;
    int timeout_ms;

public:
    MT5CandlesUploader(string _symbol, string _serverUrl = "http://localhost:8000") {
        symbol = _symbol;
        aiServerUrl = _serverUrl;
        timeout_ms = 5000;
    }

    // Récupère les candles depuis MT5 et les formate en JSON
    string FormatCandlesJSON(string sym, string timeframe, int count = 100) {
        // Récupère les candles
        MqlRates rates[];
        string tf_str = IntToString(PeriodSeconds(StringToTimeframe(timeframe)) / 60);

        int bars = CopyRates(sym, StringToTimeframe(timeframe), 0, count, rates);
        if (bars <= 0) {
            Print("❌ Erreur CopyRates pour ", sym, " ", timeframe);
            return "";
        }

        // Construit le JSON
        string json = "{\"symbol\":\"" + sym + "\",\"timeframe\":\"" + timeframe + "\",\"candles\":[";

        for (int i = 0; i < bars; i++) {
            if (i > 0) json += ",";
            json += "{";
            json += "\"time\":" + IntToString(rates[i].time) + ",";
            json += "\"open\":" + DoubleToString(rates[i].open, 2) + ",";
            json += "\"high\":" + DoubleToString(rates[i].high, 2) + ",";
            json += "\"low\":" + DoubleToString(rates[i].low, 2) + ",";
            json += "\"close\":" + DoubleToString(rates[i].close, 2) + ",";
            json += "\"volume\":" + IntToString(rates[i].tick_volume);
            json += "}";
        }

        json += "]}";
        return json;
    }

    // Envoie les candles à l'API
    bool UploadCandles(string sym, string timeframe, int count = 100) {
        string json = FormatCandlesJSON(sym, timeframe, count);

        if (json == "") {
            Print("❌ Erreur formatage JSON");
            return false;
        }

        // Crée la requête HTTP
        string url = aiServerUrl + "/mt5/upload-candles";
        string headers = "Content-Type: application/json\r\n";

        char data[];
        int len = StringLen(json);
        ArrayResize(data, len);
        for (int i = 0; i < len; i++) {
            data[i] = (uchar)StringGetCharacter(json, i);
        }

        Print("[UPLOAD] Sending ", count, " candles for ", sym, " ", timeframe, " to ", url);

        // Envoie la requête
        char response[];
        int response_code = WebRequest(
            "POST",
            url,
            headers,
            timeout_ms,
            data,
            response
        );

        if (response_code == 200) {
            Print("✅ Candles uploaded successfully for ", sym, " ", timeframe);
            return true;
        } else {
            Print("❌ Upload failed. Code: ", response_code);
            return false;
        }
    }

    // Envoie les candles pour plusieurs timeframes
    bool UploadAllTimeframes(string sym) {
        bool success = true;
        string timeframes[] = {"M1", "M5", "M15", "H1", "H4", "D1"};

        for (int i = 0; i < ArraySize(timeframes); i++) {
            if (!UploadCandles(sym, timeframes[i], 100)) {
                success = false;
            }
            Sleep(500); // Délai entre les requêtes
        }

        return success;
    }
};

#endif
