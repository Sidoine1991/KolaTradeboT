// Test script pour vérifier la syntaxe WebRequest corrigée
void TestWebRequest()
{
    string url = "https://example.com/api";
    string headers = "Content-Type: application/json\r\n";
    string data = "{\"test\":\"value\"}";
    
    char post[];
    StringToCharArray(data, post);
    
    // Convertir char[] en uchar[] - CORRECTION APPLIQUÉE
    uchar post_uchar[];
    ArrayResize(post_uchar, ArraySize(post));
    for(int i=0; i<ArraySize(post); i++)
        post_uchar[i] = (uchar)post[i];
    
    uchar result[];
    string result_headers;
    
    // WebRequest avec BONS paramètres - CORRECTION APPLIQUÉE
    int res = WebRequest("POST", url, headers, 10000, post_uchar, result, result_headers);
    
    if(res == 200)
    {
        string json = CharArrayToString(result);
        Print("✅ Succès: ", json);
    }
    else
    {
        Print("❌ Erreur: Code ", res);
    }
}

// Test GET sans données POST
void TestWebRequestGET()
{
    string url = "https://example.com/api";
    string headers = "Content-Type: application/json\r\n";
    
    uchar result[];
    string result_headers;
    
    // WebRequest GET sans données POST - CORRECTION APPLIQUÉE
    int res = WebRequest("GET", url, headers, 5000, result, result_headers);
    
    if(res == 200)
    {
        string json = CharArrayToString(result);
        Print("✅ GET Succès: ", json);
    }
    else
    {
        Print("❌ GET Erreur: Code ", res);
    }
}
