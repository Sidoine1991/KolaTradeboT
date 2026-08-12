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
input string DEALS_API_URL = "https://kolatradebot.onrender.com/mt5/deals-upload"; // URL upload deals (batch)
input int    BarsToUpload = 2000;  // Nombre de bougies à uploader
input int    UploadInterval = 60;  // Intervalle entre uploads (secondes)
input int    WebTimeoutMs = 20000; // Timeout WebRequest (ms)
input int    MaxRetries = 2;       // Nb retries si 503/429/erreur réseau
input bool   AutoUpload = true;    // Upload automatique au démarrage et périodiquement
input bool   UploadOnRequest = false; // Upload uniquement sur demande (via OnTimer)
input bool   UploadDeals = true;   // Uploader aussi les deals (clôtures) pour harmonie MT5->Supabase->Excel
input int    DealsLookbackDays = 7; // Période (jours) pour uploader les deals
input bool   DealsIncludeAllMagics = false; // true=tous trades compte, false=filtrer par Magic
input long   DealsMagicFilter = 202502; // utilisé si DealsIncludeAllMagics=false

// Variables globales
datetime lastUploadTime = 0;
datetime g_backoffUntil = 0;
int      g_consecutiveFailures = 0;
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
    Print("   ├─ URL Deals API: ", DEALS_API_URL);
    Print("   ├─ Bougies par upload: ", BarsToUpload);
    Print("   ├─ Intervalle: ", UploadInterval, " secondes");
    Print("   └─ Upload auto: ", AutoUpload ? "OUI" : "NON");
    
    if(AutoUpload)
    {
        // Upload immédiat au démarrage
        EventSetTimer(1); // Timer toutes les secondes pour vérifier l'intervalle
        UploadAllSymbols();
        if(UploadDeals) UploadDealsBatch();
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
        if(UploadDeals) UploadDealsBatch();
        lastUploadTime = currentTime;
    }
}

//+------------------------------------------------------------------+
//| Upload toutes les données pour tous les symboles                  |
//+------------------------------------------------------------------+
void UploadAllSymbols()
{
    // Backoff global si l'API est en surcharge / indisponible
    if(g_backoffUntil > 0 && TimeCurrent() < g_backoffUntil)
    {
        int secLeft = (int)(g_backoffUntil - TimeCurrent());
        if(secLeft > 0)
            Print("⏳ Upload suspendu (backoff) encore ", secLeft, "s");
        return;
    }

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
        
        // Petit délai pour ne pas surcharger l'API (augmenté si erreurs)
        Sleep(g_consecutiveFailures > 0 ? 250 : 120);

        // Si on vient d'entrer en backoff, arrêter la boucle pour ne pas spammer
        if(g_backoffUntil > 0 && TimeCurrent() < g_backoffUntil)
            break;
    }
    
    Print("✅ Upload terminé: ", successCount, " succès, ", failCount, " échecs");
}

//+------------------------------------------------------------------+
//| Upload batch des deals clôturés (DEAL_ENTRY_OUT)                  |
//+------------------------------------------------------------------+
bool UploadDealsBatch()
{
    datetime toTime = TimeCurrent();
    datetime fromTime = toTime - (DealsLookbackDays * 24 * 60 * 60);
    if(DealsLookbackDays <= 0) fromTime = toTime - 24 * 60 * 60;

    if(!HistorySelect(fromTime, toTime))
    {
        Print("❌ Deals upload: HistorySelect échoué");
        return false;
    }

    int total = HistoryDealsTotal();
    if(total <= 0)
    {
        Print("ℹ️ Deals upload: aucun deal dans la période");
        return true;
    }

    string json = "{\"deals\":[";
    int count = 0;

    for(int i = 0; i < total; i++)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket == 0) continue;

        long entry = (long)HistoryDealGetInteger(ticket, DEAL_ENTRY);
        if(entry != DEAL_ENTRY_OUT) continue;

        long magic = (long)HistoryDealGetInteger(ticket, DEAL_MAGIC);
        if(!DealsIncludeAllMagics && magic != DealsMagicFilter) continue;

        string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
        if(StringLen(symbol) <= 0) continue;

        double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) +
                        HistoryDealGetDouble(ticket, DEAL_SWAP) +
                        HistoryDealGetDouble(ticket, DEAL_COMMISSION);
        datetime closeTime = (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
        double price = HistoryDealGetDouble(ticket, DEAL_PRICE);
        long posId = (long)HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
        string isWinStr = (profit > 0 ? "true" : "false");

        // Supabase/Postgres préfère un timestamp ISO (YYYY-MM-DD HH:MM:SS ou YYYY-MM-DDTHH:MM:SSZ).
        // MT5 retourne souvent "YYYY.MM.DD HH:MM:SS" -> on remplace les points.
        string closeTimeStr = TimeToString(closeTime, TIME_DATE|TIME_SECONDS);
        StringReplace(closeTimeStr, ".", "-");

        string obj = StringFormat("{\"mt5_deal_id\":%llu,\"position_id\":%lld,\"symbol\":\"%s\",\"profit\":%.5f,\"is_win\":%s,\"close_time\":\"%s\",\"price\":%.5f,\"magic\":%lld}",
                                  ticket, posId, symbol, profit, isWinStr,
                                  closeTimeStr,
                                  price, magic);
        if(count > 0) json += ",";
        json += obj;
        count++;
        if(count >= 500) break;
    }

    json += "]}";

    string headers = "Content-Type: application/json\r\n";
    char post[];
    char result[];
    string resultHeaders;
    StringToCharArray(json, post, 0, StringLen(json));
    ResetLastError();
    int res = WebRequest("POST", DEALS_API_URL, headers, WebTimeoutMs, post, result, resultHeaders);
    if(res != 200 && res != 201)
    {
        int err = GetLastError();
        string body = CharArrayToString(result, 0, -1, CP_UTF8);
        Print("❌ Upload deals échoué HTTP ", res, " | Err MT5: ", err, " | Body: ", StringSubstr(body, 0, 300));
        return false;
    }
    Print("✅ Upload deals OK: ", count, " deals (OUT) envoyés");
    return true;
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
    int res = -1;
    int errorCode = 0;
    string response = "";

    // Retries sur surcharge/erreur réseau
    for(int attempt = 0; attempt <= MaxRetries; attempt++)
    {
        ResetLastError();
        ArrayResize(result, 0);
        result_headers = "";
        res = WebRequest("POST", API_URL, headers, WebTimeoutMs, data, result, result_headers);
        errorCode = GetLastError();
        response = CharArrayToString(result, 0, -1, CP_UTF8);

        // OK
        if(res >= 200 && res < 300)
            break;

        // 4060: URL non autorisée -> inutile de retry
        if(errorCode == 4060)
            break;

        // Backoff/retry uniquement si surcharge ou erreur réseau (HTTP 503/429/5xx ou res<0)
        bool retryable = (res == 503 || res == 429 || res == -1 || (res >= 500 && res <= 599));
        if(!retryable || attempt >= MaxRetries)
            break;

        int waitMs = 500 * (attempt + 1) * (attempt + 1); // 500ms, 2000ms, 4500ms...
        Print("⚠️ Retry upload ", symbol, " ", EnumToString(period),
              " | HTTP ", res, " | Err MT5: ", errorCode,
              " | Attente ", waitMs, "ms",
              " | Body: ", StringSubstr(response, 0, 120));
        Sleep(waitMs);
    }
    
    if(res >= 200 && res < 300)
    {
        Print("✅ Upload réussi pour ", symbol, " ", EnumToString(period), " (", copied, " bougies) - HTTP ", res);
        g_consecutiveFailures = 0;
        return true;
    }
    else
    {
        Print("❌ Échec upload pour ", symbol, " ", EnumToString(period), ": HTTP ", res, " - Erreur MT5: ", errorCode);
        if(StringLen(response) > 0)
            Print("   ↳ Body: ", StringSubstr(response, 0, 300));
        if(StringLen(result_headers) > 0)
            Print("   ↳ Headers: ", StringSubstr(result_headers, 0, 300));
        
        if(errorCode == 4060)
        {
            Print("⚠️ ERREUR 4060: URL non autorisée dans MT5!");
            Print("   Allez dans: Outils -> Options -> Expert Advisors");
            Print("   Ajoutez: https://kolatradebot.onrender.com");
        }

        // Surcharge serveur: déclencher un backoff global pour éviter de marteler l'API
        if(res == 503 || res == 429 || (res >= 500 && res <= 599))
        {
            g_consecutiveFailures++;
            int backoffSec = (int)MathMin(600.0, 15.0 * (double)g_consecutiveFailures); // 15s, 30s, 45s... max 10min
            g_backoffUntil = TimeCurrent() + backoffSec;
            Print("⏳ Backoff activé ", backoffSec, "s (consecutiveFailures=", g_consecutiveFailures, ")");
        }
        else
        {
            g_consecutiveFailures++;
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

