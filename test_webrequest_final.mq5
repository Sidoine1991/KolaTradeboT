//+------------------------------------------------------------------+
//| Test de compilation pour vérifier les corrections WebRequest      |
//+------------------------------------------------------------------+

// Test des signatures WebRequest corrigées
void TestWebRequestSignatures()
{
    string url = "https://example.com/api";
    string headers = "Content-Type: application/json\r\n";
    string data = "{\"test\":\"value\"}";
    
    // Test POST - Signature correcte : WebRequest(method, url, headers, timeout, data[], result[], headers[])
    uchar post_data[];
    StringToCharArray(data, post_data);  // Correction : pas de CHARSET_UTF8
    
    uchar result[];
    string result_headers;
    
    int res = WebRequest("POST", url, headers, 10000, post_data, result, result_headers);
    
    // Test GET - Signature correcte : WebRequest(method, url, headers, timeout, result[], headers[])
    uchar get_result[];
    string get_headers;
    
    int get_res = WebRequest("GET", url, headers, 5000, get_result, get_headers);
    
    if(res == 200)
    {
        string json = CharArrayToString(result);
        Print("✅ POST成功: ", json);
    }
    
    if(get_res == 200)
    {
        string get_json = CharArrayToString(get_result);
        Print("✅ GET成功: ", get_json);
    }
}

//+------------------------------------------------------------------+
//| Fonction principale de test                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    TestWebRequestSignatures();
    return INIT_SUCCEEDED;
}
