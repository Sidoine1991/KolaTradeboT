//| Test HTTP GOM — Vérifie que MT5 peut lire /gom-verdict |
#property copyright "Debug"
#property version   "1.00"

#include <Trade/Trade.mqh>

string AI_ServerURL = "http://127.0.0.1:8000";

void OnStart()
{
    Print("═══ TEST GOM HTTP ═══");

    string symbol = "Crash 1000 Index";
    string url = AI_ServerURL + "/gom-verdict?symbol=" + symbol;

    Print("URL: ", url);

    char result[];
    int timeout = 5000;

    int code = WebRequest("GET", url, "", timeout, NULL, result, "");

    Print("HTTP Code: ", code);

    if(code == 200)
    {
        string response = CharArrayToString(result);
        Print("Response: ", response);

        // Parse simple
        if(StringFind(response, "\"ok\":true") >= 0)
            Print("[OK] Serveur répond correctement");

        if(StringFind(response, "\"verdict\":\"SELL\"") >= 0)
            Print("[OK] Verdict SELL détecté");

        if(StringFind(response, "\"verdict_num\":-2") >= 0)
            Print("[OK] Verdict num -2 détecté");
    }
    else
    {
        Print("[ERROR] HTTP Code: ", code);
    }
}
