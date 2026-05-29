//+------------------------------------------------------------------+
//| EntryConfluence.mqh — Confluence Score 0-10 pour les entrées      |
//| Intègre: EMA stack, OB, FVG, RSI, Pattern en un seul score        |
//| Version: 1.0                                                      |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.0"

#include <JAson.mqh>

struct ConfluenceFactor {
    double score;
    string detail;
};

struct EntryConfluenceData {
    double confluence_score;        // 0-10
    double ema_stack_score;
    double order_block_score;
    double fvg_gap_score;
    double rsi_signal_score;
    double pattern_score;
    int factors_passed;             // Nombre de facteurs >= 1.5
    string quality_rating;          // EXCEPTIONAL, HIGH, MEDIUM, LOW, VERY_LOW
    string action;                  // BUY_STRONG, BUY_WEAK, SKIP, etc.
    string recommendation;          // ENTER, WAIT, SKIP
    double estimated_win_rate;      // 0-1.0
    double risk_reward_ratio;       // 1:X
    datetime timestamp;
};

class EntryConfluence {
private:
    string ai_server_url;
    int connection_timeout;

public:
    EntryConfluence(string server_url = "http://localhost:8000") {
        ai_server_url = server_url;
        connection_timeout = 5000;  // ms
    }

    // Récupère le score de confluence pour un niveau d'entrée
    bool GetEntryConfluence(
        const string symbol,
        const string timeframe,
        double price,
        const string direction,
        EntryConfluenceData &out_data
    ) {
        string url = StringFormat(
            "%s/projection/entry-confluence?symbol=%s&timeframe=%s&price=%.5f&direction=%s",
            ai_server_url, symbol, timeframe, price, direction
        );

        string response = HTTPGet(url);
        if (response == "") {
            Print("❌ EntryConfluence: HTTP request failed");
            return false;
        }

        return ParseConfluenceResponse(response, out_data);
    }

    // Parse la réponse JSON
    bool ParseConfluenceResponse(const string json_response, EntryConfluenceData &out_data) {
        CJAson parser;

        if (!parser.Deserialize(json_response)) {
            Print("❌ EntryConfluence: JSON parse error");
            return false;
        }

        // Extraire les scores
        out_data.confluence_score = parser.GetValue("confluence_score").ToDouble();
        out_data.quality_rating = parser.GetValue("quality_rating").ToString();
        out_data.action = parser.GetValue("action").ToString();
        out_data.recommendation = parser.GetValue("recommendation").ToString();
        out_data.estimated_win_rate = parser.GetValue("estimated_win_rate").ToDouble();
        out_data.risk_reward_ratio = parser.GetValue("risk_reward_ratio").ToDouble();
        out_data.factors_passed = (int)parser.GetValue("factors_passed").ToDouble();

        // Extraire les facteurs individuels
        CJAson *factors = parser.GetValue("factors");
        if (factors != NULL) {
            CJAson *ema = factors.GetValue("ema_stack");
            if (ema != NULL) {
                out_data.ema_stack_score = ema.GetValue("score").ToDouble();
                delete ema;
            }

            CJAson *ob = factors.GetValue("order_block");
            if (ob != NULL) {
                out_data.order_block_score = ob.GetValue("score").ToDouble();
                delete ob;
            }

            CJAson *fvg = factors.GetValue("fvg_gap");
            if (fvg != NULL) {
                out_data.fvg_gap_score = fvg.GetValue("score").ToDouble();
                delete fvg;
            }

            CJAson *rsi = factors.GetValue("rsi_signal");
            if (rsi != NULL) {
                out_data.rsi_signal_score = rsi.GetValue("score").ToDouble();
                delete rsi;
            }

            CJAson *pattern = factors.GetValue("pattern");
            if (pattern != NULL) {
                out_data.pattern_score = pattern.GetValue("score").ToDouble();
                delete pattern;
            }

            delete factors;
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

    // Afficher le rapport de confluence
    void PrintConfluenceReport(const EntryConfluenceData &data) {
        Print("\n=== ENTRY CONFLUENCE REPORT ===");
        Print("Score: ", data.confluence_score, "/10 | Rating: ", data.quality_rating);
        Print("Action: ", data.action);
        Print("\nFactor Breakdown:");
        Print("  EMA Stack:   ", data.ema_stack_score, "/2.5");
        Print("  Order Block: ", data.order_block_score, "/2.5");
        Print("  FVG Gap:     ", data.fvg_gap_score, "/2.0");
        Print("  RSI Signal:  ", data.rsi_signal_score, "/2.0");
        Print("  Pattern:     ", data.pattern_score, "/1.5");
        Print("  ├─ Factors Passed: ", data.factors_passed, "/5");
        Print("\nEstimated Win Rate: ", (data.estimated_win_rate * 100), "%");
        Print("Risk/Reward: 1:", data.risk_reward_ratio);
        Print("Recommendation: ", data.recommendation);
        Print("============================\n");
    }

    // Statut visuel pour les logs
    string GetStatusEmoji(double score) {
        if (score >= 8.5) return "🟢🟢";      // Exceptional
        if (score >= 7.0) return "🟢";        // High
        if (score >= 6.0) return "🟡";        // Medium
        if (score >= 5.0) return "🟠";        // Low
        return "🔴";                           // Very Low
    }
};

//+------------------------------------------------------------------+
// Exemple d'utilisation:
//+------------------------------------------------------------------+
/*
void OnTick() {
    static EntryConfluence ec;
    EntryConfluenceData conf;

    double entry_price = 2508.50;

    if (ec.GetEntryConfluence(Symbol(), "M1", entry_price, "LONG", conf)) {
        Print(ec.GetStatusEmoji(conf.confluence_score),
              " Confluence Score: ", conf.confluence_score,
              "/10 — ", conf.quality_rating);

        // Afficher le rapport complet
        ec.PrintConfluenceReport(conf);

        // Décision d'entrée basée sur la confluence
        if (conf.confluence_score >= 7.5) {
            Print("✅ EXCELLENT ENTRY - Opening position");
            // OpenPosition(...);
        } else if (conf.confluence_score >= 6.5) {
            Print("⚠️ GOOD ENTRY - Proceed with caution");
        } else {
            Print("❌ WEAK ENTRY - Skip this opportunity");
        }
    }
}
*/
