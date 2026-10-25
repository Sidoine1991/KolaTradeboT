//+------------------------------------------------------------------+
//|                                                 Ind_SignalBridge |
//| Pulls Streamlit signals (API/file) and draws arrows on MT5 chart |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 0 // No plots needed for this indicator, only objects
#property indicator_buffers 0
#property indicator_style1 STYLE_SOLID

//--- Inputs
input string  InpApiURL      = "http://localhost:8001/signals"; // API URL
input bool    InpAllowWeb    = true;                              // Use WebRequest first
input int     InpPollSeconds = 5;                                 // Poll interval (seconds)
input color   InpBuyColor    = clrLimeGreen;                      // Buy signal color
input color   InpSellColor   = clrCrimson;                        // Sell signal color

//--- Global variables
datetime g_lastPoll = 0;
string   g_indicator_name = ""; // To store the indicator's name for object management

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Store the indicator's name for object identification
   g_indicator_name = MQLInfoString(MQL_PROGRAM_NAME);
   if (g_indicator_name == "")
   {
      g_indicator_name = "Ind_SignalBridge";
   }

   // Set the timer for polling (restart timer if already running)
   EventKillTimer(); // Kill any existing timer first
   EventSetTimer((int)MathMax(1, InpPollSeconds));

   // Use _Symbol for compatibility
   if(!SymbolSelect(_Symbol, true))
   {
      Print("Failed to select symbol: ", _Symbol);
      return(INIT_FAILED);
   }

   Print("Ind_SignalBridge initialized successfully on ", _Symbol, " ", EnumToString(_Period));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Only clean up if indicator is being removed completely
   if(reason == REASON_REMOVE || reason == REASON_PROGRAM)
   {
      // Kill the timer
      EventKillTimer();
      // Clean up any drawn objects created by this indicator
      ObjectsDeleteAll(0, g_indicator_name + "_");
   }
   else
   {
      // For timeframe changes, just kill timer but keep objects
      EventKillTimer();
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   // No calculations needed here; signals are drawn by OnTimer.
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Timer event function                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Prevent excessive calls if timer interval is very short or system is slow
   if (TimeCurrent() - g_lastPoll < InpPollSeconds - 1) return;
   g_lastPoll = TimeCurrent();

   string payload = "";
   bool success = false;

   // Try to fetch signals from API first if enabled
   if (InpAllowWeb)
   {
      uchar post_data[]; // Empty for GET request
      uchar result_data[];
      string headers = "";

      int request_result = WebRequest("GET", InpApiURL, headers, 5000, post_data, result_data, headers);
      if (request_result == 200) // HTTP status code 200 OK
      {
         payload = CharArrayToString(result_data, 0, WHOLE_ARRAY, CP_UTF8);
         if (StringLen(payload) > 0)
         {
            success = true;
         }
         else
         {
            Print("WebRequest successful but received empty payload from: ", InpApiURL);
         }
      }
      else
      {
         Print("WebRequest failed to ", InpApiURL, ". Error: ", GetLastError(), " Status Code: ", request_result);
      }
   }

   // If API failed or was not allowed, try reading from a local file
   if (!success)
   {
      string mql5_files_path = TerminalInfoString(TERMINAL_DATA_PATH) + "\\MQL5\\Files\\";
      string file_path = mql5_files_path + "signals.json";

      int file_handle = FileOpen(file_path, FILE_READ | FILE_TXT | FILE_UNICODE);
      if (file_handle != INVALID_HANDLE)
      {
         payload = FileReadString(file_handle);
         FileClose(file_handle);
         if (StringLen(payload) > 0)
         {
            success = true;
         }
         else
         {
            Print("Local file '", file_path, "' is empty.");
         }
      }
      else
      {
         Print("Failed to open local file '", file_path, "'. Error: ", GetLastError());
      }
   }

   // If we have a payload, process it
   if (success && StringLen(payload) > 0)
   {
      DrawSignalsFromJson(payload);
   }
}

//+------------------------------------------------------------------+
//| Helper function to extract value from JSON string                |
//+------------------------------------------------------------------+
string ExtractValue(const string src, const string key, int &search_pos)
{
   int key_len = StringLen(key);
   if (key_len == 0) return "";

   int pos = StringFind(src, "\"" + key + "\"", search_pos);
   if (pos < 0) return "";

   int colon_pos = StringFind(src, ":", pos + key_len);
   if (colon_pos < 0) return "";

   int start_val = colon_pos + 1;
   while (start_val < StringLen(src) && (src[start_val] == ' ' || src[start_val] == '\t' || src[start_val] == '\n' || src[start_val] == '\r'))
   {
      start_val++;
   }

   if (src[start_val] == '"')
   {
      int quote_end = start_val + 1;
      while (quote_end < StringLen(src))
      {
         if (src[quote_end] == '"' && src[quote_end-1] != '\\') break;
         quote_end++;
      }
      if (quote_end >= StringLen(src)) return "";

      search_pos = quote_end + 1;
      string extracted_string = StringSubstr(src, start_val + 1, quote_end - (start_val + 1));
      extracted_string = StringReplace(extracted_string, "\\\"", "\"");
      extracted_string = StringReplace(extracted_string, "\\\\", "\\");
      return extracted_string;
   }
   else
   {
      int end_val = start_val;
      while (end_val < StringLen(src) &&
             src[end_val] != ',' && src[end_val] != '}' && src[end_val] != '{' && src[end_val] != '[' && src[end_val] != ']' &&
             src[end_val] != ' ' && src[end_val] != '\t' && src[end_val] != '\n' && src[end_val] != '\r')
      {
         end_val++;
      }
      search_pos = end_val;
      return StringSubstr(src, start_val, end_val - start_val);
   }
}

//+------------------------------------------------------------------+
//| Function to parse date-time string                               |
//+------------------------------------------------------------------+
datetime ParseDateTimeString(const string s)
{
   if (StringLen(s) < 19) return 0;

   MqlDateTime dt;
   dt.year = (int)StringToInteger(StringSubstr(s, 0, 4));
   dt.mon  = (int)StringToInteger(StringSubstr(s, 5, 2));
   dt.day  = (int)StringToInteger(StringSubstr(s, 8, 2));
   dt.hour = (int)StringToInteger(StringSubstr(s, 11, 2));
   dt.min  = (int)StringToInteger(StringSubstr(s, 14, 2));
   dt.sec  = (int)StringToInteger(StringSubstr(s, 17, 2));

   if (dt.mon < 1 || dt.mon > 12 || dt.day < 1 || dt.day > 31)
   {
      Print("Invalid date components in string: ", s);
      return 0;
   }

   datetime result_time = StructToTime(dt);
   if (result_time == 0)
   {
      Print("Failed to convert parsed date/time to datetime: ", s);
   }
   return result_time;
}

//+------------------------------------------------------------------+
//| Function to draw signals from JSON string                        |
//+------------------------------------------------------------------+
void DrawSignalsFromJson(const string json)
{
   string current_symbol = _Symbol;
   int search_pos = 0;
   int json_len = StringLen(json);

   while (search_pos < json_len)
   {
      int object_start = StringFind(json, "{", search_pos);
      if (object_start < 0) break;

      int object_end = StringFind(json, "}", object_start + 1);
      if (object_end < 0) break;

      string signal_json = StringSubstr(json, object_start, object_end - object_start + 1);
      int parse_iter_pos = 0;

      string sSymbol = ExtractValue(signal_json, "symbol", parse_iter_pos);
      string sSide = ExtractValue(signal_json, "side", parse_iter_pos);
      string sPriceStr = ExtractValue(signal_json, "price", parse_iter_pos);
      string sSLStr = ExtractValue(signal_json, "sl", parse_iter_pos);
      string sTPStr = ExtractValue(signal_json, "tp", parse_iter_pos);

      if (StringCompare(sSymbol, current_symbol, false) != 0)
      {
         search_pos = object_end + 1;
         continue;
      }

      double price = (sPriceStr != "") ? StringToDouble(sPriceStr) : 0.0;
      double sl = (sSLStr != "") ? StringToDouble(sSLStr) : 0.0;
      double tp = (sTPStr != "") ? StringToDouble(sTPStr) : 0.0;

      if (price <= 0.0 || StringCompare(sSide, "") == 0)
      {
         Print("Skipping incomplete or invalid signal: ", signal_json);
         search_pos = object_end + 1;
         continue;
      }

      int arrow_code = (StringCompare(sSide, "BUY", false) == 0) ? 233 : 234;
      color arrow_color = (StringCompare(sSide, "BUY", false) == 0) ? InpBuyColor : InpSellColor;
      string side_display_name = (StringCompare(sSide, "BUY", false) == 0) ? "BUY" : "SELL";

      datetime time_array[];
      ArraySetAsSeries(time_array, true);
      int copied = CopyTime(_Symbol, _Period, 0, 1, time_array);
      datetime signal_bar_time = (copied > 0) ? time_array[0] : TimeCurrent();

      string base_name = g_indicator_name + "_" + sSymbol + "_" + sSide + "_" + (string)signal_bar_time + "_" + DoubleToString(price, _Digits);
      string arrow_name = base_name + "_ARROW";

      // Create or update arrow (check if object exists first)
      if (ObjectFind(0, arrow_name) < 0)
      {
         if (!ObjectCreate(0, arrow_name, OBJ_ARROW, 0, signal_bar_time, price))
         {
            Print("Failed to create arrow object '", arrow_name, "'. Error: ", GetLastError());
            search_pos = object_end + 1;
            continue;
         }
      }
      else
      {
         // Update existing object position and properties
         ObjectSetInteger(0, arrow_name, OBJPROP_TIME, signal_bar_time);
         ObjectSetDouble(0, arrow_name, OBJPROP_PRICE, price);
      }

      ObjectSetInteger(0, arrow_name, OBJPROP_COLOR, arrow_color);
      ObjectSetInteger(0, arrow_name, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arrow_name, OBJPROP_ARROWCODE, arrow_code);
      ObjectSetString(0, arrow_name, OBJPROP_TOOLTIP, sSymbol + " " + side_display_name + " @" + TimeToString(signal_bar_time) + " Price: " + DoubleToString(price, _Digits));

      // Draw SL line
      if (sl > 0.0)
      {
         string sl_line_name = base_name + "_SL";
         if (ObjectFind(0, sl_line_name) < 0)
         {
            if (!ObjectCreate(0, sl_line_name, OBJ_HLINE, 0, 0, sl))
            {
               Print("Failed to create SL line object '", sl_line_name, "'. Error: ", GetLastError());
            }
         }
         ObjectSetInteger(0, sl_line_name, OBJPROP_COLOR, clrGray);
         ObjectSetInteger(0, sl_line_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, sl_line_name, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetString(0, sl_line_name, OBJPROP_TOOLTIP, sSymbol + " SL: " + DoubleToString(sl, _Digits));
         ObjectSetDouble(0, sl_line_name, OBJPROP_PRICE, sl);
      }

      // Draw TP line
      if (tp > 0.0)
      {
         string tp_line_name = base_name + "_TP";
         if (ObjectFind(0, tp_line_name) < 0)
         {
            if (!ObjectCreate(0, tp_line_name, OBJ_HLINE, 0, 0, tp))
            {
               Print("Failed to create TP line object '", tp_line_name, "'. Error: ", GetLastError());
            }
         }
         ObjectSetInteger(0, tp_line_name, OBJPROP_COLOR, arrow_color);
         ObjectSetInteger(0, tp_line_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, tp_line_name, OBJPROP_STYLE, STYLE_SOLID);
         ObjectSetString(0, tp_line_name, OBJPROP_TOOLTIP, sSymbol + " TP: " + DoubleToString(tp, _Digits));
         ObjectSetDouble(0, tp_line_name, OBJPROP_PRICE, tp);
      }

      search_pos = object_end + 1;
   }
}