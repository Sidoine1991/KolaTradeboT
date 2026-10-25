//+------------------------------------------------------------------+
//|                                                    EA_SignalBridge |
//| Pulls Streamlit signals (API/file) and draws arrows on MT5 chart |
//| Version: Expert Advisor (Program)                                |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.00"
#property strict

//--- Inputs
input string  InpApiURL      = "http://localhost:8001/signals"; // API URL
input bool    InpAllowWeb    = true;                              // Use WebRequest first
input int     InpPollSeconds = 5;                                 // Poll interval (seconds)
input color   InpBuyColor    = clrLimeGreen;                      // Buy signal color
input color   InpSellColor   = clrCrimson;                        // Sell signal color
input bool    InpAutoTrade   = false;                             // Auto trade signals
input double  InpLotSize     = 0.1;                              // Lot size for auto trading
input int     InpMagicNumber = 12345;                            // Magic number for trades

//--- Global variables
datetime g_lastPoll = 0;
string   g_program_name = "EA_SignalBridge";
datetime g_lastTradeTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set the timer for polling
   EventKillTimer(); // Kill any existing timer first
   EventSetTimer((int)MathMax(1, InpPollSeconds));

   // Use _Symbol for compatibility
   if(!SymbolSelect(_Symbol, true))
   {
      Print("Failed to select symbol: ", _Symbol);
      return(INIT_FAILED);
   }

   Print("EA_SignalBridge initialized successfully on ", _Symbol, " ", EnumToString(_Period));
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Kill the timer
   EventKillTimer();
   // Clean up any drawn objects created by this EA
   ObjectsDeleteAll(0, g_program_name + "_");
   Print("EA_SignalBridge deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // No tick processing needed for signal display
   // Signals are processed by OnTimer
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
      ProcessSignalsFromJson(payload);
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
//| Function to execute trade based on signal                        |
//+------------------------------------------------------------------+
bool ExecuteTrade(const string symbol, const string side, const double price, const double sl, const double tp)
{
   if (!InpAutoTrade) return false;
   
   // Check if we already have a position for this symbol
   if (PositionSelect(symbol))
   {
      Print("Position already exists for ", symbol, ". Skipping trade.");
      return false;
   }
   
   // Check minimum time between trades
   if (TimeCurrent() - g_lastTradeTime < 60) // 1 minute cooldown
   {
      Print("Trade cooldown active. Skipping trade.");
      return false;
   }
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = symbol;
   request.volume = InpLotSize;
   request.type = (side == "BUY") ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   request.price = (side == "BUY") ? SymbolInfoDouble(symbol, SYMBOL_ASK) : SymbolInfoDouble(symbol, SYMBOL_BID);
   request.sl = sl;
   request.tp = tp;
   request.magic = InpMagicNumber;
   request.comment = "EA_SignalBridge_" + side;
   
   if (OrderSend(request, result))
   {
      g_lastTradeTime = TimeCurrent();
      Print("Trade executed: ", side, " ", symbol, " at ", result.price, " SL:", sl, " TP:", tp);
      return true;
   }
   else
   {
      Print("Trade failed: ", side, " ", symbol, " Error: ", result.retcode);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Function to process signals from JSON string                     |
//+------------------------------------------------------------------+
void ProcessSignalsFromJson(const string json)
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

      // Execute trade if auto trading is enabled
      if (InpAutoTrade)
      {
         ExecuteTrade(sSymbol, sSide, price, sl, tp);
      }

      // Draw signal on chart
      DrawSignalOnChart(sSymbol, sSide, price, sl, tp);

      search_pos = object_end + 1;
   }
}

//+------------------------------------------------------------------+
//| Function to draw signal on chart                                 |
//+------------------------------------------------------------------+
void DrawSignalOnChart(const string symbol, const string side, const double price, const double sl, const double tp)
{
   int arrow_code = (StringCompare(side, "BUY", false) == 0) ? 233 : 234;
   color arrow_color = (StringCompare(side, "BUY", false) == 0) ? InpBuyColor : InpSellColor;
   string side_display_name = (StringCompare(side, "BUY", false) == 0) ? "BUY" : "SELL";

   datetime time_array[];
   ArraySetAsSeries(time_array, true);
   int copied = CopyTime(_Symbol, _Period, 0, 1, time_array);
   datetime signal_bar_time = (copied > 0) ? time_array[0] : TimeCurrent();

   string base_name = g_program_name + "_" + symbol + "_" + side + "_" + (string)signal_bar_time + "_" + DoubleToString(price, _Digits);
   string arrow_name = base_name + "_ARROW";

   // Create or update arrow
   if (ObjectFind(0, arrow_name) < 0)
   {
      if (!ObjectCreate(0, arrow_name, OBJ_ARROW, 0, signal_bar_time, price))
      {
         Print("Failed to create arrow object '", arrow_name, "'. Error: ", GetLastError());
         return;
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
   ObjectSetString(0, arrow_name, OBJPROP_TOOLTIP, symbol + " " + side_display_name + " @" + TimeToString(signal_bar_time) + " Price: " + DoubleToString(price, _Digits));

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
      ObjectSetString(0, sl_line_name, OBJPROP_TOOLTIP, symbol + " SL: " + DoubleToString(sl, _Digits));
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
      ObjectSetString(0, tp_line_name, OBJPROP_TOOLTIP, symbol + " TP: " + DoubleToString(tp, _Digits));
      ObjectSetDouble(0, tp_line_name, OBJPROP_PRICE, tp);
   }
}
