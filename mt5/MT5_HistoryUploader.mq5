//+------------------------------------------------------------------+
//|                                      MT5_HistoryUploader.mq5    |
//|                        Upload historique MT5 vers Render API    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025"
#property link      "https://www.metaquotes.net/"
#property version   "1.00"
#property strict

// Configuration
input string API_URL = "https://kolatradebot.onrender.com/mt5/history-upload"; // URL de l'endpoint Render
input int    BarsToUpload = 2000;  // Nombre de bougies à uploader
input int    UploadInterval = 60;  // Intervalle entre uploads (secondes)
input bool   AutoUpload = true;    // Upload automatique au démarrage et périodiquement
input bool   UploadOnRequest = false; // Upload uniquement sur demande (via OnTimer)

// Variables globales
datetime lastUploadTime = 0;
string symbolsToUpload[] = {
    "EURUSD", "GBPUSD", "USDJPY", "AUDUSD", "USDCAD", "USDCHF", "NZDUSD",
    "XAUUSD", "XAGUSD", "US Oil",
    "BTCUSD", "ETHUSD", "LTCUSD", "XRPUSD", "TRXUSD", "UNIUSD", "SHBUSD", "TONUSD",
    "Boom 300 Index", "Boom 500 Index", "Boom 600 Index", "Boom 900 Index", "Boom 150 Index",
    "Crash 300 Index", "Crash 600 Index", "Crash 900 Index", "Crash 150 Index", "Crash 1000 Index",
    "Volatility 10 Index", "Volatility 25 Index", "Volatility 50 Index", "Volatility 100 Index",
    "Volatility 75 Index", "Volatility 150 Index", "Volatility 250 Index",
    "Step Index", "Step Index 200", "Step Index 400",
    "Jump 10 Index", "Jump 25 Index",
    "DEX 600 UP Index", "DEX 900 UP Index",
    "AUDUSD DFX 10 Index", "USDJPY DFX 20 Index", "GBPUSD DFX 10 Index",
    "Vol over Boom 400", "Vol over Boom 550", "Vol over Crash 400", "Vol over Crash 750"
};

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("🚀 MT5 History Uploader initialisé");
    Print("   ├─ URL API: ", API_URL);
    Print("   ├─ Bougies par upload: ", BarsToUpload);
    Print("   ├─ Intervalle: ", UploadInterval, " secondes");
    Print("   └─ Upload auto: ", AutoUpload ? "OUI" : "NON");
    
    if(AutoUpload)
    {
        // Upload immédiat au démarrage
        EventSetTimer(1); // Timer toutes les secondes pour vérifier l'intervalle
        UploadAllSymbols();
    }
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    Print("🛑 MT5 History Uploader arrêté");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    // Rien à faire ici, on utilise OnTimer
}

//+------------------------------------------------------------------+
//| Timer function                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
    if(!AutoUpload)
        return;
    
    datetime currentTime = TimeCurrent();
    
    // Vérifier si l'intervalle est écoulé
    if(currentTime - lastUploadTime >= UploadInterval)
    {
        UploadAllSymbols();
        lastUploadTime = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Upload toutes les données pour tous les symboles                  |
//+------------------------------------------------------------------+
void UploadAllSymbols()
{
    Print("📤 Début upload historique pour ", ArraySize(symbolsToUpload), " symboles...");
    
    int successCount = 0;
    int failCount = 0;
    
    for(int i = 0; i < ArraySize(symbolsToUpload); i++)
    {
        string symbol = symbolsToUpload[i];
        
        // Upload pour M1 (prioritaire pour ML)
        if(UploadHistoryForSymbol(symbol, PERIOD_M1))
            successCount++;
        else
            failCount++;
        
        // Petit délai pour ne pas surcharger l'API
        Sleep(100);
    }
    
    Print("✅ Upload terminé: ", successCount, " succès, ", failCount, " échecs");
}

//+------------------------------------------------------------------+
//| Upload historique pour un symbole et timeframe donné              |
//+------------------------------------------------------------------+
bool UploadHistoryForSymbol(string symbol, ENUM_TIMEFRAMES period)
{
    // Vérifier que le symbole existe
    if(!SymbolSelect(symbol, true))
    {
        Print("⚠️ Symbole non disponible: ", symbol);
        return false;
    }
    
    // Récupérer les données historiques
    MqlRates rates[];
    int copied = CopyRates(symbol, period, 0, BarsToUpload, rates);
    
    if(copied <= 0)
    {
        Print("❌ Impossible de récupérer les données pour ", symbol, " (copied: ", copied, ")");
        return false;
    }
    
    // Convertir en JSON
    string jsonData = BuildJSONFromRates(symbol, period, rates, copied);
    
    if(StringLen(jsonData) == 0)
    {
        Print("❌ Erreur construction JSON pour ", symbol);
        return false;
    }
    
    // Envoyer via WebRequest
    char data[];
    string headers = "Content-Type: application/json\r\n";
    string result_headers = "";
    
    int payloadLen = StringLen(jsonData);
    ArrayResize(data, payloadLen + 1);
    int copied_chars = StringToCharArray(jsonData, data, 0, WHOLE_ARRAY, CP_UTF8);
    
    if(copied_chars <= 0)
    {
        Print("❌ Erreur conversion JSON en UTF-8 pour ", symbol);
        return false;
    }
    
    ArrayResize(data, copied_chars - 1);
    
    // Envoyer la requête
    char result[];
    int res = WebRequest("POST", API_URL, headers, 10000, data, result, result_headers);
    
    if(res >= 200 && res < 300)
    {
        string response = CharArrayToString(result, 0, -1, CP_UTF8);
        Print("✅ Upload réussi pour ", symbol, " ", EnumToString(period), " (", copied, " bougies) - HTTP ", res);
        return true;
    }
    else
    {
        int errorCode = GetLastError();
        Print("❌ Échec upload pour ", symbol, " ", EnumToString(period), ": HTTP ", res, " - Erreur MT5: ", errorCode);
        
        if(errorCode == 4060)
        {
            Print("⚠️ ERREUR 4060: URL non autorisée dans MT5!");
            Print("   Allez dans: Outils -> Options -> Expert Advisors");
            Print("   Ajoutez: https://kolatradebot.onrender.com");
        }
        
        return false;
    }
}

//+------------------------------------------------------------------+
//| Construire le JSON à partir des rates                             |
//+------------------------------------------------------------------+
string BuildJSONFromRates(string symbol, ENUM_TIMEFRAMES period, MqlRates &rates[], int count)
{
    string timeframe = PeriodToString(period);
    
    string json = "{";
    json += "\"symbol\":\"" + symbol + "\",";
    json += "\"timeframe\":\"" + timeframe + "\",";
    json += "\"data\":[";
    
    for(int i = 0; i < count; i++)
    {
        if(i > 0) json += ",";
        
        json += "{";
        json += "\"time\":" + IntegerToString((int)rates[i].time) + ",";
        json += "\"open\":" + DoubleToString(rates[i].open, _Digits) + ",";
        json += "\"high\":" + DoubleToString(rates[i].high, _Digits) + ",";
        json += "\"low\":" + DoubleToString(rates[i].low, _Digits) + ",";
        json += "\"close\":" + DoubleToString(rates[i].close, _Digits) + ",";
        json += "\"tick_volume\":" + IntegerToString(rates[i].tick_volume);
        json += "}";
    }
    
    json += "]}";
    
    return json;
}

//+------------------------------------------------------------------+
//| Convertir ENUM_TIMEFRAMES en string                                |
//+------------------------------------------------------------------+
string PeriodToString(ENUM_TIMEFRAMES period)
{
    switch(period)
    {
        case PERIOD_M1:  return "M1";
        case PERIOD_M5:  return "M5";
        case PERIOD_M15: return "M15";
        case PERIOD_M30: return "M30";
        case PERIOD_H1:  return "H1";
        case PERIOD_H4:  return "H4";
        case PERIOD_D1:  return "D1";
        default:         return "M1";
    }
}

//+------------------------------------------------------------------+

