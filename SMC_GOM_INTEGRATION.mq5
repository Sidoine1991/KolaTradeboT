// 🎯 SMC_Universal — GOM Integration with WhatsApp Notifications
// Fetch GOM verdicts from ai_server + send WhatsApp alerts for new PERFECT signals

#include <Trade/Trade.mqh>

// ═══════════════════════════════════════════════════════════════
// GLOBAL VARS FOR GOM TRACKING
// ═══════════════════════════════════════════════════════════════

struct GOMVerdictData
{
    string symbol;
    int verdict_num;       // -3 to +3
    string verdict;
    double score_buy;
    double score_sell;
    double verdict_gap;
    double coherence_pct;
    double entry;
    double sl;
    double tp;
};

// Track which signals we've already notified (to avoid spam)
map<string, int> notified_verdicts;  // symbol → vn (only notify on change)

static datetime last_gom_fetch = 0;
static int gom_fetch_interval = 60;  // Fetch every 60 seconds

// ═══════════════════════════════════════════════════════════════
// FETCH GOM VERDICTS FROM ai_server
// ═══════════════════════════════════════════════════════════════

bool FetchGOMVerdicts(GOMVerdictData &verdicts[])
{
    string url = "http://127.0.0.1:8000/gom-verdicts";
    string headers = "Content-Type: application/json\r\n";

    char request[];
    char response[];
    int timeout = 5000;

    // Make HTTP GET request
    int res = WebRequest("GET", url, headers, timeout, request, response, "");

    if(res != 200)
    {
        Print("❌ FetchGOMVerdicts HTTP error: ", res);
        return false;
    }

    // Convert response to string
    string response_str = CharArrayToString(response);

    // Check if response is valid
    if(StringFind(response_str, "\"ok\": true") < 0)
    {
        Print("❌ GOM response error: ", response_str);
        return false;
    }

    Print("✅ GOM verdicts fetched successfully");
    // TODO: Parse JSON response and populate verdicts[]
    // This requires a JSON library or manual string parsing

    return true;
}

// ═══════════════════════════════════════════════════════════════
// SEND WHATSAPP ALERT FOR NEW PERFECT SIGNALS
// ═══════════════════════════════════════════════════════════════

void SendWhatsAppAlert(const GOMVerdictData &verdict)
{
    // Only alert for PERFECT BUY/SELL
    if(verdict.verdict_num != 3 && verdict.verdict_num != -3)
        return;

    // Format message
    string emoji = (verdict.verdict_num == 3) ? "🟢" : "🔴";
    string action = (verdict.verdict_num == 3) ? "BUY" : "SELL";

    string message = StringFormat(
        "%s **%s — PERFECT %s**\n"
        "Entry: %.2f\nSL: %.2f\nTP: %.2f\n"
        "Gap: %.2f | Coherence: %.0f%%",
        emoji, verdict.symbol, action,
        verdict.entry, verdict.sl, verdict.tp,
        verdict.verdict_gap, verdict.coherence_pct
    );

    // Send via ai_server /send-message endpoint
    SendHTTPMessage(message);
}

void SendHTTPMessage(const string &message)
{
    string url = "http://127.0.0.1:8000/send-message";
    string headers = "Content-Type: application/json\r\n";

    // Build JSON payload
    string payload = StringFormat(
        "{\"channel\": \"whatsapp\", \"message\": \"%s\"}",
        message
    );

    char request[];
    StringToCharArray(payload, request);
    char response[];
    int timeout = 5000;

    int res = WebRequest("POST", url, headers, timeout, request, response, "");

    if(res == 200)
    {
        Print("✅ WhatsApp alert sent: ", message);
    }
    else
    {
        Print("⚠️ WhatsApp send failed (HTTP ", res, ") — storing locally");
        // Fallback: write to log file
        LogToFile(message);
    }
}

void LogToFile(const string &message)
{
    // Write to logs/gom_alerts.log
    int file_handle = FileOpen("logs/gom_alerts.log", FILE_WRITE | FILE_TXT | FILE_ANSI);
    if(file_handle != INVALID_HANDLE)
    {
        FileWrite(file_handle, TimeToString(TimeCurrent()) + " | " + message);
        FileClose(file_handle);
    }
}

// ═══════════════════════════════════════════════════════════════
// UPDATE GOM DASHBOARD
// ═══════════════════════════════════════════════════════════════

void UpdateGOMDashboard(const GOMVerdictData &verdicts[])
{
    // Display on chart using ObjectCreate + ObjectSetString
    // Example format:
    // 🟢 PERFECT BUY (2):
    //    XAUUSD        Entry: 4192.20  SL: 4180.00  TP: 4210.00
    //    Boom 1000     Entry: 7000.00  SL: 6950.00  TP: 7050.00
    //
    // 🔴 PERFECT SELL (2):
    //    Crash 300     Entry: 3495.00  SL: 3520.00  TP: 3470.00
    //    Crash 500     Entry: 6035.00  SL: 6060.00  TP: 6010.00

    // Count verdicts by type
    int perfect_buy = 0, good_buy = 0, buy = 0;
    int perfect_sell = 0, good_sell = 0, sell = 0;

    for(int i = 0; i < ArraySize(verdicts); i++)
    {
        switch(verdicts[i].verdict_num)
        {
            case 3:  perfect_buy++;  break;
            case 2:  good_buy++;     break;
            case 1:  buy++;          break;
            case -1: sell++;         break;
            case -2: good_sell++;    break;
            case -3: perfect_sell++; break;
        }
    }

    // Create comment
    string dashboard = "";
    dashboard += "🎯 GOM VERDICTS DASHBOARD\n";
    dashboard += "═════════════════════════════════════\n\n";

    if(perfect_buy > 0)
        dashboard += StringFormat("🟢 PERFECT BUY (%d)\n", perfect_buy);
    if(good_buy > 0)
        dashboard += StringFormat("🟢 GOOD BUY (%d)\n", good_buy);
    if(buy > 0)
        dashboard += StringFormat("🟢 BUY (%d)\n", buy);

    if(perfect_sell > 0)
        dashboard += StringFormat("🔴 PERFECT SELL (%d)\n", perfect_sell);
    if(good_sell > 0)
        dashboard += StringFormat("🔴 GOOD SELL (%d)\n", good_sell);
    if(sell > 0)
        dashboard += StringFormat("🔴 SELL (%d)\n", sell);

    dashboard += "\nLast update: " + TimeToString(TimeCurrent());

    Comment(dashboard);
}

// ═══════════════════════════════════════════════════════════════
// MAIN: TRACK SIGNAL CHANGES AND SEND ALERTS
// ═══════════════════════════════════════════════════════════════

void TrackAndAlertGOMChanges(const GOMVerdictData &verdicts[])
{
    for(int i = 0; i < ArraySize(verdicts); i++)
    {
        string symbol = verdicts[i].symbol;
        int current_vn = verdicts[i].verdict_num;
        int last_vn = notified_verdicts[symbol];  // 0 if not found

        // NEW PERFECT signal detected
        if((current_vn == 3 || current_vn == -3) && last_vn != current_vn)
        {
            Print("🆕 NEW PERFECT signal detected: ", symbol);
            SendWhatsAppAlert(verdicts[i]);
            notified_verdicts[symbol] = current_vn;  // Track this alert
        }
    }
}

// ═══════════════════════════════════════════════════════════════
// INTEGRATION IN OnTick()
// ═══════════════════════════════════════════════════════════════

void OnTick_GOMUpdate()
{
    // Fetch GOM verdicts every 60 seconds
    datetime now = TimeCurrent();

    if((now - last_gom_fetch) >= gom_fetch_interval)
    {
        GOMVerdictData verdicts[];

        if(FetchGOMVerdicts(verdicts))
        {
            // Update dashboard
            UpdateGOMDashboard(verdicts);

            // Check for new PERFECT signals and send WhatsApp alerts
            TrackAndAlertGOMChanges(verdicts);
        }

        last_gom_fetch = now;
    }
}

// ═══════════════════════════════════════════════════════════════
// NOTES FOR IMPLEMENTATION
// ═══════════════════════════════════════════════════════════════

/*
To integrate this into SMC_Universal.mq5:

1. Add this code to the global scope (after #include statements)
2. Call OnTick_GOMUpdate() in the main OnTick() function
3. Handle JSON parsing (requires a JSON library or manual parsing)

Example in OnTick():
    void OnTick()
    {
        // ... existing code ...
        OnTick_GOMUpdate();  // Add this line
        // ... more code ...
    }

JSON Parsing Options:
A) Use cJSON4MQL (third-party JSON library)
B) Use NexaFlex JSON (simpler alternative)
C) Parse manually using StringFind() + StringSubstr()

WhatsApp Integration:
- ai_server endpoint /send-message handles actual delivery
- Fallback to local logs if WhatsApp fails (HTTP 404)
- Only alert on NEW PERFECT signals (not every tick)

Dashboard Display:
- Uses Comment() for simplicity
- Can be replaced with ObjectCreate() for fancy tables
- Updates every 60 seconds with fresh GOM data
*/
