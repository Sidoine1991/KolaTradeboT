//+------------------------------------------------------------------+
//| ML_Scanner.mqh - Multi-symbol scanner for data collection        |
//| Scans all symbols in Market Watch every 5 minutes                |
//| Sends indicator snapshots to Render server for storage & ML      |
//+------------------------------------------------------------------+
#property strict

#ifndef ML_SCANNER_MQH
#define ML_SCANNER_MQH

#include "ML_DataCollector.mqh"

//+------------------------------------------------------------------+
//| Global scanner state                                              |
//+------------------------------------------------------------------+
static datetime g_LastScanTime = 0;
static int g_ScanIntervalSeconds = 300;  // 5 minutes

//+------------------------------------------------------------------+
//| Initialize scanner                                               |
//+------------------------------------------------------------------+
void ML_Scanner_Init()
{
   g_LastScanTime = TimeCurrent();
   Print("[ML_Scanner] Initialized with 5-minute scan interval");
}

//+------------------------------------------------------------------+
//| Check if it's time to scan                                        |
//+------------------------------------------------------------------+
bool ML_Scanner_IsTimeToScan()
{
   datetime now = TimeCurrent();
   return (now - g_LastScanTime) >= g_ScanIntervalSeconds;
}

//+------------------------------------------------------------------+
//| Scan all symbols in Market Watch                                 |
//+------------------------------------------------------------------+
void ML_Scanner_ScanAllSymbols(string ai_server_url, string ai_render_url, bool use_render_primary)
{
   if(!ML_Scanner_IsTimeToScan()) return;

   datetime scan_start = TimeCurrent();
   int scanned_count = 0;
   int success_count = 0;

   Print("[ML_Scanner] ========== SCAN START: " + TimeToString(scan_start) + " ==========");

   // Get all symbols
   int total_symbols = SymbolsTotal(true);  // true = only Market Watch

   if(total_symbols == 0) {
      Print("[ML_Scanner] WARNING: No symbols in Market Watch!");
      return;
   }

   Print("[ML_Scanner] Scanning " + IntToString(total_symbols) + " symbols...");

   // Scan each symbol
   for(int i = 0; i < total_symbols; i++) {
      string symbol = SymbolName(i, true);
      if(StringLen(symbol) == 0) continue;

      scanned_count++;

      // Collect all indicators
      IndicatorSnapshot snap = CollectAllIndicators(symbol);

      // Send to server
      bool sent = ML_Scanner_SendSnapshot(snap, ai_server_url, ai_render_url, use_render_primary);

      if(sent) {
         success_count++;
         Print("[ML_Scanner] " + symbol + " ✓ sent");
      } else {
         Print("[ML_Scanner] " + symbol + " ✗ failed");
      }

      // Small delay to avoid overwhelming network
      Sleep(50);
   }

   datetime scan_end = TimeCurrent();
   int scan_duration = scan_end - scan_start;

   Print("[ML_Scanner] ========== SCAN COMPLETE ==========");
   Print("[ML_Scanner] Scanned: " + IntToString(scanned_count) + " symbols");
   Print("[ML_Scanner] Success: " + IntToString(success_count) + " / " + IntToString(scanned_count));
   Print("[ML_Scanner] Duration: " + IntToString(scan_duration) + " seconds");

   g_LastScanTime = scan_end;
}

//+------------------------------------------------------------------+
//| Send snapshot to server                                           |
//+------------------------------------------------------------------+
bool ML_Scanner_SendSnapshot(IndicatorSnapshot &snap, string ai_server_url, string ai_render_url, bool use_render_primary)
{
   // Build JSON payload
   string json = SnapshotToJSON(snap);

   // Determine which URL to use
   string primary_url = use_render_primary ? ai_render_url : ai_server_url;
   string backup_url = use_render_primary ? ai_server_url : ai_render_url;

   // Try primary endpoint
   int timeout = 5000;  // 5 seconds
   char response[];
   string headers = "Content-Type: application/json\r\n";

   int res = WebRequest("POST", primary_url + "/store_snapshot", headers, timeout, json, response, NULL);

   if(res == 200 || res == 201) {
      return true;
   }

   Print("[ML_Scanner] Primary endpoint failed for " + snap.symbol + ", trying backup...");

   // Try backup endpoint
   res = WebRequest("POST", backup_url + "/store_snapshot", headers, timeout, json, response, NULL);

   if(res == 200 || res == 201) {
      Print("[ML_Scanner] Backup endpoint succeeded for " + snap.symbol);
      return true;
   }

   Print("[ML_Scanner] Both endpoints failed for " + snap.symbol + " (HTTP " + IntToString(res) + ")");
   return false;
}

//+------------------------------------------------------------------+
//| Convert IndicatorSnapshot to JSON                                |
//+------------------------------------------------------------------+
string SnapshotToJSON(IndicatorSnapshot &snap)
{
   string json = "{";

   // Identification
   json += "\"symbol\":\"" + snap.symbol + "\",";
   json += "\"timestamp\":" + IntToString(snap.timestamp) + ",";
   json += "\"timeframe\":\"" + snap.timeframe + "\",";

   // Price
   json += "\"bid\":" + DoubleToString(snap.bid, 8) + ",";
   json += "\"ask\":" + DoubleToString(snap.ask, 8) + ",";
   json += "\"spread_pips\":" + DoubleToString(snap.spread_pips, 2) + ",";

   // Momentum
   json += "\"rsi_m1\":" + DoubleToString(snap.rsi_m1, 2) + ",";
   json += "\"rsi_m5\":" + DoubleToString(snap.rsi_m5, 2) + ",";
   json += "\"rsi_m15\":" + DoubleToString(snap.rsi_m15, 2) + ",";
   json += "\"rsi_h1\":" + DoubleToString(snap.rsi_h1, 2) + ",";

   // Volatility
   json += "\"atr_m1\":" + DoubleToString(snap.atr_m1, 8) + ",";
   json += "\"atr_m5\":" + DoubleToString(snap.atr_m5, 8) + ",";
   json += "\"atr_m15\":" + DoubleToString(snap.atr_m15, 8) + ",";
   json += "\"atr_h1\":" + DoubleToString(snap.atr_h1, 8) + ",";
   json += "\"atr_ratio\":" + DoubleToString(snap.atr_ratio, 3) + ",";

   // Trend
   json += "\"ema_fast_m1\":" + DoubleToString(snap.ema_fast_m1, 8) + ",";
   json += "\"ema_slow_m1\":" + DoubleToString(snap.ema_slow_m1, 8) + ",";
   json += "\"ema_fast_m5\":" + DoubleToString(snap.ema_fast_m5, 8) + ",";
   json += "\"ema_slow_m5\":" + DoubleToString(snap.ema_slow_m5, 8) + ",";
   json += "\"ema_fast_m15\":" + DoubleToString(snap.ema_fast_m15, 8) + ",";
   json += "\"ema_slow_m15\":" + DoubleToString(snap.ema_slow_m15, 8) + ",";
   json += "\"ema_fast_h1\":" + DoubleToString(snap.ema_fast_h1, 8) + ",";
   json += "\"ema_slow_h1\":" + DoubleToString(snap.ema_slow_h1, 8) + ",";

   // SMC
   json += "\"fvg_detected\":" + (snap.fvg_detected ? "true" : "false") + ",";
   json += "\"fvg_direction\":" + IntToString(snap.fvg_direction) + ",";
   json += "\"bos_detected\":" + (snap.bos_detected ? "true" : "false") + ",";
   json += "\"bos_direction\":" + IntToString(snap.bos_direction) + ",";
   json += "\"ob_proximity_atr\":" + DoubleToString(snap.ob_proximity_atr, 3) + ",";
   json += "\"sweep_detected\":" + (snap.sweep_detected ? "true" : "false") + ",";
   json += "\"sweep_type\":\"" + snap.sweep_type + "\",";

   // KOLA
   json += "\"m5_buy_level\":" + DoubleToString(snap.m5_buy_level, 8) + ",";
   json += "\"m5_sell_level\":" + DoubleToString(snap.m5_sell_level, 8) + ",";
   json += "\"m5_buy_touches\":" + IntToString(snap.m5_buy_touches) + ",";
   json += "\"m5_sell_touches\":" + IntToString(snap.m5_sell_touches) + ",";
   json += "\"m15_buy_level\":" + DoubleToString(snap.m15_buy_level, 8) + ",";
   json += "\"m15_sell_level\":" + DoubleToString(snap.m15_sell_level, 8) + ",";
   json += "\"m15_buy_touches\":" + IntToString(snap.m15_buy_touches) + ",";
   json += "\"m15_sell_touches\":" + IntToString(snap.m15_sell_touches) + ",";
   json += "\"h1_buy_level\":" + DoubleToString(snap.h1_buy_level, 8) + ",";
   json += "\"h1_sell_level\":" + DoubleToString(snap.h1_sell_level, 8) + ",";
   json += "\"h1_buy_touches\":" + IntToString(snap.h1_buy_touches) + ",";
   json += "\"h1_sell_touches\":" + IntToString(snap.h1_sell_touches) + ",";

   // Confluence
   json += "\"tech_buy_score\":" + DoubleToString(snap.tech_buy_score, 3) + ",";
   json += "\"tech_sell_score\":" + DoubleToString(snap.tech_sell_score, 3) + ",";
   json += "\"entry_quality\":" + IntToString(snap.entry_quality) + ",";
   json += "\"spike_probability\":" + DoubleToString(snap.spike_probability, 3) + ",";

   // Bollinger + VWAP
   json += "\"bb_squeeze\":" + (snap.bb_squeeze ? "true" : "false") + ",";
   json += "\"vwap_distance_pct\":" + DoubleToString(snap.vwap_distance_pct, 3) + ",";
   json += "\"bb_pctb\":" + DoubleToString(snap.bb_pctb, 3) + ",";
   json += "\"bb_width_pct\":" + DoubleToString(snap.bb_width_pct, 3) + ",";

   // Volume
   json += "\"volume_current\":" + IntToString(snap.volume_current) + ",";
   json += "\"volume_ratio\":" + DoubleToString(snap.volume_ratio, 3) + ",";

   // SIDO
   json += "\"sido_double_top\":" + (snap.sido_double_top ? "true" : "false") + ",";
   json += "\"sido_double_bottom\":" + (snap.sido_double_bottom ? "true" : "false") + ",";

   // Asset & Coherence
   json += "\"asset_category\":\"" + snap.asset_category + "\",";
   json += "\"coherence_score\":" + DoubleToString(snap.coherence_score, 3) + ",";

   // Signal (last field, no comma)
   json += "\"signal_action\":\"" + snap.signal_action + "\",";
   json += "\"signal_confidence\":" + DoubleToString(snap.signal_confidence, 3);

   json += "}";

   return json;
}

#endif

