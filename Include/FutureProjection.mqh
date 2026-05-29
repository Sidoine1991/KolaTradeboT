//+------------------------------------------------------------------+
//| FutureProjection.mqh — Intégration MCP TradingView Future Levels |
//| Projette les setups SMC 200 bougies en avant pour MQL5           |
//| Version: 1.0                                                      |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.0"

#include <JAson.mqh>

struct FutureProjectionData {
    double current_price;
    string bias_direction;
    double bias_strength;
    double sl_level;
    double tp_target_1;
    double tp_target_2;
    double tp_target_3;
    double estimated_win_rate;
    double risk_reward_ratio;
    int entry_zone_count;
    double best_entry_price;
    double best_entry_quality;
    datetime timestamp;
};

class FutureProjection {
private:
    string ai_server_url;
    int connection_timeout;

public:
    FutureProjection(string server_url = "http://localhost:8000") {
        ai_server_url = server_url;
        connection_timeout = 5000;  // ms
    }

    // Récupère la projection future pour un symbole
    bool GetFutureProjection(
        const string symbol,
        const string timeframe,
        double current_price,
        const string direction,
        FutureProjectionData &out_data
    ) {
        string url = StringFormat(
            "%s/projection/future-levels?symbol=%s&timeframe=%s&current_price=%.5f&direction=%s",
            ai_server_url, symbol, timeframe, current_price, direction
        );

        string response = HTTPGet(url);
        if (response == "") {
            Print("❌ FutureProjection: HTTP request failed for ", symbol);
            return false;
        }

        return ParseProjectionResponse(response, out_data);
    }

    // Parse la réponse JSON
    bool ParseProjectionResponse(const string json_response, FutureProjectionData &out_data) {
        CJAson parser;

        if (!parser.Deserialize(json_response)) {
            Print("❌ FutureProjection: JSON parse error");
            return false;
        }

        // Extraire les champs principaux
        out_data.current_price = parser.GetValue("current_price").ToDouble();
        out_data.bias_direction = parser.GetValue("bias_direction").ToString();
        out_data.bias_strength = parser.GetValue("bias_strength").ToDouble();
        out_data.sl_level = parser.GetValue("sl_level").ToDouble();
        out_data.estimated_win_rate = parser.GetValue("estimated_win_rate").ToDouble();
        out_data.risk_reward_ratio = parser.GetValue("risk_reward_ratio").ToDouble();

        // Extraire les TP targets
        CJAson *tp_array = parser.GetValue("tp_targets");
        if (tp_array != NULL) {
            int tp_count = tp_array.Size();
            if (tp_count > 0) out_data.tp_target_1 = tp_array.GetValue(0).ToDouble();
            if (tp_count > 1) out_data.tp_target_2 = tp_array.GetValue(1).ToDouble();
            if (tp_count > 2) out_data.tp_target_3 = tp_array.GetValue(2).ToDouble();
            delete tp_array;
        }

        // Extraire les entry zones
        CJAson *entry_zones = parser.GetValue("entry_zones");
        if (entry_zones != NULL) {
            int zone_count = entry_zones.Size();
            out_data.entry_zone_count = zone_count;

            if (zone_count > 0) {
                // Choisir la meilleure zone d'entrée
                double best_quality = 0;
                for (int i = 0; i < zone_count; i++) {
                    CJAson *zone = entry_zones.GetValue(i);
                    double quality = zone.GetValue("quality_score").ToDouble();
                    if (quality > best_quality) {
                        best_quality = quality;
                        out_data.best_entry_price = zone.GetValue("price").ToDouble();
                        out_data.best_entry_quality = quality;
                    }
                    delete zone;
                }
            }
            delete entry_zones;
        }

        out_data.timestamp = TimeCurrent();
        delete parser;
        return true;
    }

    // Utilitaire HTTP
    string HTTPGet(const string url) {
        char result[];
        string headers = "Content-Type: application/json\r\n";

        int res = WebRequest("GET", url, headers, connection_timeout, result);

        if (res == -1) {
            Print("❌ WebRequest error: ", GetLastError());
            return "";
        }

        if (res != 200) {
            Print("❌ HTTP error code: ", res);
            return "";
        }

        return CharArrayToString(result);
    }
};

//+------------------------------------------------------------------+
// Exemple d'utilisation dans OnTick():
//+------------------------------------------------------------------+
/*
void OnTick() {
    static FutureProjection fp;
    FutureProjectionData proj;

    double current_price = SymbolInfoDouble(Symbol(), SYMBOL_BID);

    // Récupérer la projection pour LONG
    if (fp.GetFutureProjection(Symbol(), "M1", current_price, "LONG", proj)) {
        Print("📊 Projection Future pour ", Symbol());
        Print("   Bias: ", proj.bias_direction, " (force: ", proj.bias_strength, ")");
        Print("   TP Targets: ", proj.tp_target_1, " / ", proj.tp_target_2, " / ", proj.tp_target_3);
        Print("   SL: ", proj.sl_level);
        Print("   Win Rate: ", proj.estimated_win_rate * 100, "%");
        Print("   Risk/Reward: ", proj.risk_reward_ratio, ":1");
        Print("   Entry quality: ", proj.best_entry_quality, "/10");

        // Utiliser pour trader :
        if (proj.bias_strength > 0.7 && proj.risk_reward_ratio > 2.0) {
            // Setup de bonne qualité
            OpenPosition(proj.best_entry_price, proj.sl_level, proj.tp_target_1);
        }
    }
}
*/
