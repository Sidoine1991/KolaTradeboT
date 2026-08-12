//| Test HTTP Simple
#property copyright "Test"
#property version   "1.00"

void OnStart()
{
    Print("=== TEST HTTP ===");

    string url = "http://127.0.0.1:8000/gom-verdict?symbol=Crash%201000%20Index";
    char post[], result[];
    string headers = "";
    string respHeaders;

    Print("URL: ", url);
    int code = WebRequest("GET", url, headers, 5000, post, result, respHeaders);
    Print("HTTP Code: ", code);

    if(code == 200)
    {
        string resp = CharArrayToString(result);
        Print("Response (first 200 chars): ", StringSubstr(resp, 0, 200));
    }
    else if(code == -1)
    {
        Print("ERROR: -1 (Network error or WebRequest not allowed)");
        Print("FIX: Tools -> Options -> Expert Advisors -> Allow WebRequest");
    }
    else
    {
        Print("HTTP Error Code: ", code);
    }
}
