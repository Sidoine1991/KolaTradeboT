//+------------------------------------------------------------------+
//| Test final de compilation WebRequest - Toutes les signatures      |
//+------------------------------------------------------------------+

// Test de toutes les signatures WebRequest utilisées dans GoldRush_basic
void TestAllWebRequestSignatures()
{
    string url = "https://example.com/api";
    string headers = "Content-Type: application/json\r\n";
    string data = "{\"test\":\"value\"}";
    
    // === SIGNATURE 1 : WebRequest avec data (POST) ===
    // WebRequest(method, url, headers, timeout, data[], result[], headers[])
    uchar post_data[];
    StringToCharArray(data, post_data);
    
    uchar post_result[];
    string post_headers;
    
    int post_res = WebRequest("POST", url, headers, 10000, post_data, post_result, post_headers);
    
    // === SIGNATURE 2 : WebRequest sans data (GET) ===
    // WebRequest(method, url, headers, timeout, data[], result[], headers[])
    // data[] peut être vide pour GET
    uchar empty_data[];  // Tableau vide pour GET
    uchar get_result[];
    string get_headers;
    
    int get_res = WebRequest("GET", url, headers, 5000, empty_data, get_result, get_headers);
    
    // Vérification des résultats
    if(post_res == 200)
    {
        string json = CharArrayToString(post_result);
        Print("✅ POST signature correcte: ", json);
    }
    
    if(get_res == 200)
    {
        string get_json = CharArrayToString(get_result);
        Print("✅ GET signature correcte: ", get_json);
    }
}

//+------------------------------------------------------------------+
//| Test des fonctions exactes de GoldRush_basic                     |
//+------------------------------------------------------------------+
void TestGoldRushFunctions()
{
    // Simulation de UpdateAnalysisEndpoint
    string url = "https://kolatradebot.onrender.com/analysis";
    string headers = "Content-Type: application/json\r\n";
    uchar result_data[];
    string result_headers;
    
    // GET avec empty_data (correction appliquée)
    uchar empty_data[];
    int responseCode = WebRequest("GET", url, headers, 5000, empty_data, result_data, result_headers);
    
    // POST avec données (déjà correct)
    string data = "{\"symbol\":\"" + _Symbol + "\"}";
    uchar post_uchar[];
    StringToCharArray(data, post_uchar);
    
    responseCode = WebRequest("POST", url, headers, 5000, post_uchar, result_data, result_headers);
}

//+------------------------------------------------------------------+
int OnInit()
{
    TestAllWebRequestSignatures();
    TestGoldRushFunctions();
    Print("✅ Tous les tests WebRequest complétés");
    return INIT_SUCCEEDED;
}
