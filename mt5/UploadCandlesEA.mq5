//+------------------------------------------------------------------+
//| UploadCandlesEA.mq5 — Upload candles to AI Server
//| Version: 2.0 (Fixed)
//+------------------------------------------------------------------+

#property copyright "TradBOT"
#property version   "2.0"
#property description "Upload candles every 15 minutes to AI Server"
#property strict

#include "modules/MT5_Candles_Uploader.mqh"

input string   AIServerUrl = "http://localhost:8000";
input int      UploadInterval = 1; // Minutes (TEST: 1 minute)
input bool     UploadM1 = true;
input bool     UploadM5 = true;
input bool     UploadM15 = true;
input bool     UploadH1 = true;

MT5CandlesUploader *uploader = NULL;
datetime lastUpload = 0;

int OnInit() {
    Print("========================================");
    Print("UploadCandlesEA v2.0 STARTED");
    Print("Symbol: ", _Symbol);
    Print("Server: ", AIServerUrl);
    Print("Upload interval: ", UploadInterval, " minute(s)");
    Print("========================================");

    if (uploader != NULL) delete uploader;
    uploader = new MT5CandlesUploader(_Symbol, AIServerUrl);

    Print("EA initialized successfully!");
    lastUpload = 0; // Force upload on first tick

    return INIT_SUCCEEDED;
}

void OnTick() {
    if (uploader == NULL) {
        Print("ERROR: uploader is NULL!");
        return;
    }

    datetime now = TimeCurrent();
    long elapsed = (long)(now - lastUpload);

    if (elapsed >= UploadInterval * 60) {
        lastUpload = now;

        Print("=== TICK UPLOAD START [", TimeToString(now), "] ===");

        if (UploadM1) {
            Print("  Uploading M1...");
            uploader.UploadCandles(_Symbol, PERIOD_M1, 100);
        }
        Sleep(500);

        if (UploadM5) {
            Print("  Uploading M5...");
            uploader.UploadCandles(_Symbol, PERIOD_M5, 100);
        }
        Sleep(500);

        if (UploadM15) {
            Print("  Uploading M15...");
            uploader.UploadCandles(_Symbol, PERIOD_M15, 100);
        }
        Sleep(500);

        if (UploadH1) {
            Print("  Uploading H1...");
            uploader.UploadCandles(_Symbol, PERIOD_H1, 100);
        }

        Print("=== TICK UPLOAD END ===");
    }
}

void OnDeinit(const int reason) {
    if (uploader != NULL) delete uploader;
    Print("UploadCandlesEA stopped");
}
