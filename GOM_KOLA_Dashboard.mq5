//+------------------------------------------------------------------+
//| GOM/KOLA TradingView Dashboard for MT5                           |
//| Displays real-time GOM verdict, scores, indicators from AI Server|
//| Updates every 30 seconds with colored boxes                      |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                 |
//+------------------------------------------------------------------+
input group "=== DASHBOARD SETTINGS ==="
input string AIServerURL = "http://127.0.0.1:8000";
input int UpdateIntervalSec = 30;
input string MonitoredSymbols = "XAUUSD,Boom 600 Index,Crash 600 Index";

input group "=== LAYOUT ==="
input int DashboardX = 20;
input int DashboardY = 50;
input int PanelWidth = 380;
input int RowHeight = 28;
input int FontSize = 9;
input int RowGap = 2;

input group "=== COLORS ==="
input color ColorHeaderBuy = 0x1B5E20;        // Dark green (PERFECT/GOOD BUY)
input color ColorBuy = 0x2E7D32;              // Green (BUY)
input color ColorNeutral = 0x757575;          // Gray (WAIT)
input color ColorSell = 0xC62828;             // Red (SELL)
input color ColorHeaderSell = 0x8B0000;       // Dark red (PERFECT/GOOD SELL)
input color ColorBackground = 0x1E1E1E;       // Dark background
input color ColorText = clrWhite;             // White text
input color ColorBorder = 0x424242;           // Medium gray border

//+------------------------------------------------------------------+
//| STRUCTURES                                                       |
//+------------------------------------------------------------------+
struct GOMData {
   string symbol;
   string verdict;           // "BUY", "SELL", "WAIT"
   int verdict_num;          // -3 to +3
   double score_buy;         // 0-15
   double score_sell;        // 0-15
   double spike_pct;         // 0-100
   int rsi;                  // 0-100
   int st_dir;               // 1 or -1
   double entry_quality;     // 0-100
   double coherence_pct;     // 0-100
   double kola_buy;          // Price level
   double kola_sell;         // Price level
   double current_price;
   bool valid;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
datetime g_lastUpdate = 0;

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
int OnInit() {
   EventSetTimer(1);  // Check every second if update is needed
   Print("[GOM Dashboard] Initialized. Update interval: " + IntegerToString(UpdateIntervalSec) + "s");
   Print("[GOM Dashboard] Monitoring symbols: " + MonitoredSymbols);
   RefreshDashboard();  // Initial draw
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
   EventKillTimer();
   RemoveAllDashboardObjects();
   ChartRedraw();
   Print("[GOM Dashboard] Deinitialized. Reason: " + IntegerToString(reason));
}

//+------------------------------------------------------------------+
//| TIMER EVENT                                                      |
//+------------------------------------------------------------------+
void OnTimer() {
   if(TimeCurrent() - g_lastUpdate >= UpdateIntervalSec) {
      g_lastUpdate = TimeCurrent();
      RefreshDashboard();
   }
}

//+------------------------------------------------------------------+
//| REFRESH DASHBOARD                                                |
//+------------------------------------------------------------------+
void RefreshDashboard() {
   string symbols[];
   int count = StringSplit(MonitoredSymbols, ',', symbols);

   for(int i = 0; i < count; i++) {
      string sym = StringTrimLeft(StringTrimRight(symbols[i]));
      if(StringLen(sym) == 0) continue;

      GOMData data = FetchGOMData(sym);
      if(data.valid) {
         DrawSymbolPanel(sym, data, i);
      } else {
         DrawErrorPanel(sym, i, "No GOM data");
      }
   }

   ChartRedraw();
   Print("[GOM Dashboard] Updated " + IntegerToString(count) + " symbols");
}

//+------------------------------------------------------------------+
//| FETCH GOM DATA FROM AI SERVER                                    |
//+------------------------------------------------------------------+
GOMData FetchGOMData(string symbol) {
   GOMData data;
   data.symbol = symbol;
   data.valid = false;

   // Build URL with symbol parameter
   string encodedSym = StringReplace(symbol, " ", "%20");
   string url = AIServerURL + "/gom-verdict?symbol=" + encodedSym;

   char request[], response[];
   string headers = "Content-Type: application/json\r\n";
   int timeout = 5000;  // 5 seconds

   ResetLastError();
   int retcode = WebRequest("GET", url, headers, timeout, request, response, headers);

   if(retcode != 200) {
      Print("[GOM Dashboard] WebRequest error for " + symbol + ": " + IntegerToString(retcode));
      return data;
   }

   // Parse response
   string json = CharArrayToString(response);

   // Extract fields
   data.verdict = GetJSONStringValue(json, "verdict");
   data.verdict_num = StringToInteger(GetJSONValue(json, "verdict_num"));
   data.score_buy = StringToDouble(GetJSONValue(json, "score_buy"));
   data.score_sell = StringToDouble(GetJSONValue(json, "score_sell"));
   data.spike_pct = StringToDouble(GetJSONValue(json, "spike_pct"));
   data.rsi = StringToInteger(GetJSONValue(json, "rsi"));
   data.st_dir = StringToInteger(GetJSONValue(json, "st_dir"));
   data.entry_quality = StringToDouble(GetJSONValue(json, "entry_quality"));
   data.coherence_pct = StringToDouble(GetJSONValue(json, "coherence_pct"));
   data.kola_buy = StringToDouble(GetJSONValue(json, "kola_buy"));
   data.kola_sell = StringToDouble(GetJSONValue(json, "kola_sell"));
   data.current_price = StringToDouble(GetJSONValue(json, "price"));

   data.valid = (StringLen(data.verdict) > 0 && data.score_buy >= 0);

   return data;
}

//+------------------------------------------------------------------+
//| DRAW SYMBOL PANEL (6 ROWS)                                       |
//+------------------------------------------------------------------+
void DrawSymbolPanel(string symbol, GOMData &data, int index) {
   int baseY = DashboardY + (index * ((RowHeight + RowGap) * 6 + 10));
   int x = DashboardX;

   // Row 1: Header with verdict color
   color headerColor = GetVerdictColor(data.verdict_num);
   DrawRow(symbol + "_HDR", x, baseY, symbol, headerColor);

   // Row 2: Verdict + RSI
   string verdictText = StringFormat("Verdict: %s (%d) | RSI: %d",
                                      data.verdict, data.verdict_num, data.rsi);
   DrawRow(symbol + "_VERDICT", x, baseY + (RowHeight + RowGap), verdictText, ColorBackground);

   // Row 3: Scores
   string scoresText = StringFormat("Buy: %.1f | Sell: %.1f | Gap: %.1f",
                                     data.score_buy, data.score_sell,
                                     data.score_buy - data.score_sell);
   DrawRow(symbol + "_SCORES", x, baseY + (RowHeight + RowGap) * 2, scoresText, ColorBackground);

   // Row 4: Indicators
   string stSymbol = (data.st_dir == 1) ? "▲" : "▼";
   string indText = StringFormat("Spike: %.0f%% | ST: %s | Quality: %.0f%%",
                                  data.spike_pct, stSymbol, data.entry_quality);
   DrawRow(symbol + "_IND", x, baseY + (RowHeight + RowGap) * 3, indText, ColorBackground);

   // Row 5: KOLA levels
   string kolaText = StringFormat("KOLA BUY: %.2f | SELL: %.2f",
                                   data.kola_buy, data.kola_sell);
   DrawRow(symbol + "_KOLA", x, baseY + (RowHeight + RowGap) * 4, kolaText, ColorBackground);

   // Row 6: Status
   string statusText = StringFormat("Coherence: %.0f%% | Price: %.2f",
                                     data.coherence_pct, data.current_price);
   DrawRow(symbol + "_STATUS", x, baseY + (RowHeight + RowGap) * 5, statusText, ColorBackground);
}

//+------------------------------------------------------------------+
//| DRAW ERROR PANEL                                                 |
//+------------------------------------------------------------------+
void DrawErrorPanel(string symbol, int index, string error) {
   int baseY = DashboardY + (index * ((RowHeight + RowGap) * 6 + 10));
   int x = DashboardX;

   string errorText = symbol + " - " + error;
   DrawRow(symbol + "_ERR", x, baseY, errorText, ColorNeutral);
}

//+------------------------------------------------------------------+
//| DRAW SINGLE ROW (RECTANGLE + LABEL)                              |
//+------------------------------------------------------------------+
void DrawRow(string name, int x, int y, string text, color bgColor) {
   // Create background rectangle
   string bgName = name + "_BG";
   if(ObjectFind(0, bgName) < 0) {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   }

   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, PanelWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, RowHeight);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, ColorBorder);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_WIDTH, 1);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
   ObjectSetInteger(0, bgName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bgName, OBJPROP_ZORDER, 2000);

   // Create text label
   string txtName = name + "_TXT";
   if(ObjectFind(0, txtName) < 0) {
      ObjectCreate(0, txtName, OBJ_LABEL, 0, 0, 0);
   }

   ObjectSetString(0, txtName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, txtName, OBJPROP_XDISTANCE, x + 8);
   ObjectSetInteger(0, txtName, OBJPROP_YDISTANCE, y + 5);
   ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, txtName, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, txtName, OBJPROP_COLOR, ColorText);
   ObjectSetInteger(0, txtName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, txtName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, txtName, OBJPROP_ZORDER, 2001);
}

//+------------------------------------------------------------------+
//| GET VERDICT COLOR BASED ON VERDICT NUM                           |
//+------------------------------------------------------------------+
color GetVerdictColor(int verdict_num) {
   if(verdict_num >= 2) return ColorHeaderBuy;        // Dark green (PERFECT/GOOD BUY)
   if(verdict_num == 1) return ColorBuy;              // Green (BUY)
   if(verdict_num == 0) return ColorNeutral;          // Gray (WAIT)
   if(verdict_num == -1) return ColorSell;            // Red (SELL)
   if(verdict_num <= -2) return ColorHeaderSell;      // Dark red (PERFECT/GOOD SELL)
   return ColorNeutral;
}

//+------------------------------------------------------------------+
//| JSON PARSING - GET STRING VALUE                                  |
//+------------------------------------------------------------------+
string GetJSONStringValue(string json, string key) {
   string search = "\"" + key + "\":\"";
   int start = StringFind(json, search);
   if(start < 0) return "";

   start += StringLen(search);
   int end = StringFind(json, "\"", start);
   if(end < 0) return "";

   return StringSubstr(json, start, end - start);
}

//+------------------------------------------------------------------+
//| JSON PARSING - GET NUMERIC VALUE                                 |
//+------------------------------------------------------------------+
string GetJSONValue(string json, string key) {
   string search = "\"" + key + "\":";
   int start = StringFind(json, search);
   if(start < 0) return "0";

   start += StringLen(search);
   while(start < StringLen(json) &&
         (StringGetCharacter(json, start) == ' ' ||
          StringGetCharacter(json, start) == '"')) {
      start++;
   }

   int end = start;
   while(end < StringLen(json)) {
      ushort ch = StringGetCharacter(json, end);
      if(ch == ',' || ch == '}' || ch == '"' || ch == ' ') break;
      end++;
   }

   return StringSubstr(json, start, end - start);
}

//+------------------------------------------------------------------+
//| REMOVE ALL DASHBOARD OBJECTS                                     |
//+------------------------------------------------------------------+
void RemoveAllDashboardObjects() {
   int objCount = ObjectsTotal(0);
   for(int i = objCount - 1; i >= 0; i--) {
      string objName = ObjectName(0, i);
      if(StringFind(objName, "_BG") > 0 || StringFind(objName, "_TXT") > 0 ||
         StringFind(objName, "_HDR") > 0 || StringFind(objName, "_ERR") > 0 ||
         StringFind(objName, "_VERDICT") > 0 || StringFind(objName, "_SCORES") > 0 ||
         StringFind(objName, "_IND") > 0 || StringFind(objName, "_KOLA") > 0 ||
         StringFind(objName, "_STATUS") > 0) {
         ObjectDelete(0, objName);
      }
   }
}

//+------------------------------------------------------------------+
//| STRING REPLACE HELPER                                            |
//+------------------------------------------------------------------+
string StringReplace(string str, string oldStr, string newStr) {
   string result = str;
   int pos = 0;
   while((pos = StringFind(result, oldStr, pos)) >= 0) {
      result = StringSubstr(result, 0, pos) + newStr +
               StringSubstr(result, pos + StringLen(oldStr));
      pos += StringLen(newStr);
   }
   return result;
}

//+------------------------------------------------------------------+
//| END OF FILE                                                      |
//+------------------------------------------------------------------+
