//+------------------------------------------------------------------+
//| MT5 Candles Uploader — batch protocol aligned with ai_server.py   |
//| Protocol 1: one POST for M1/M5/M15/H1/H4/D1 per chart symbol     |
//+------------------------------------------------------------------+
#ifndef MT5_CANDLES_UPLOADER_MQH
#define MT5_CANDLES_UPLOADER_MQH

class MT5CandlesUploader {
private:
   string aiServerUrl;
   string symbol;
   int timeout_ms;

   string TimeframeName(const ENUM_TIMEFRAMES tf)
   {
      if(tf == PERIOD_M1)  return "M1";
      if(tf == PERIOD_M5)  return "M5";
      if(tf == PERIOD_M15) return "M15";
      if(tf == PERIOD_H1)  return "H1";
      if(tf == PERIOD_H4)  return "H4";
      if(tf == PERIOD_D1)  return "D1";
      if(tf == PERIOD_W1)  return "W1";
      return "M1";
   }

   string FormatCandleArrayJSON(const string sym, const ENUM_TIMEFRAMES tf,
                                const int count)
   {
      MqlRates rates[];
      int bars = CopyRates(sym, tf, 1, count, rates);
      if(bars <= 0)
      {
         Print("[UPLOAD] CopyRates failed for ", sym, " ", TimeframeName(tf));
         return "";
      }
      int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      if(digits < 0 || digits > 12) digits = _Digits;
      string json = "[";
      for(int i = 0; i < bars; i++)
      {
         if(i > 0) json += ",";
         json += "{\"time\":" + IntegerToString((long)rates[i].time);
         json += ",\"open\":" + DoubleToString(rates[i].open, digits);
         json += ",\"high\":" + DoubleToString(rates[i].high, digits);
         json += ",\"low\":" + DoubleToString(rates[i].low, digits);
         json += ",\"close\":" + DoubleToString(rates[i].close, digits);
         json += ",\"volume\":" + IntegerToString((long)rates[i].tick_volume) + "}";
      }
      json += "]";
      return json;
   }

   string ActiveBaseUrl()
   {
      string base = SMCGP_ActiveServerURL();
      if(StringLen(base) == 0) base = aiServerUrl;
      while(StringLen(base) > 0 && StringSubstr(base, StringLen(base)-1, 1) == "/")
         base = StringSubstr(base, 0, StringLen(base)-1);
      return base;
   }

   bool PostJSON(const string url, const string json, const string label)
   {
      uchar data[];
      uchar result[];
      int bytes = StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);
      if(bytes <= 1)
      {
         Print("[UPLOAD] JSON vide/invalide | ", label);
         return false;
      }
      ArrayResize(data, bytes - 1); // retirer le NUL final
      string responseHeaders = "";
      string headers = "Content-Type: application/json; charset=utf-8\r\n";
      ResetLastError();
      int code = WebRequest("POST", url, headers, timeout_ms, data, result, responseHeaders);
      int terminalError = GetLastError();
      string body = CharArrayToString(result, 0, -1, CP_UTF8);
      bool ok = (code == 200 &&
                 (StringFind(body, "\"ok\":true") >= 0 ||
                  StringFind(body, "\"ok\": true") >= 0));
      if(ok)
      {
         Print("[UPLOAD] OK | ", label, " | ", body);
         return true;
      }
      StringReplace(body, "\r", " ");
      StringReplace(body, "\n", " ");
      if(StringLen(body) > 300) body = StringSubstr(body, 0, 300);
      Print("[UPLOAD] ÉCHEC | ", label, " | status=", code,
            " terminal_error=", terminalError, " | réponse=", body,
            " | url=", url);
      return false;
   }

public:
   MT5CandlesUploader(string _symbol, string _serverUrl)
   {
      symbol = _symbol;
      aiServerUrl = _serverUrl;
      timeout_ms = 10000; // aligné sur AI_Timeout_ms; une seule requête par symbole
   }

   string FormatCandlesJSON(string sym, ENUM_TIMEFRAMES tf, int count = 100)
   {
      string candles = FormatCandleArrayJSON(sym, tf, count);
      if(candles == "") return "";
      return "{\"symbol\":\"" + sym + "\",\"timeframe\":\"" +
             TimeframeName(tf) + "\",\"candles\":" + candles + "}";
   }

   bool UploadCandles(string sym, ENUM_TIMEFRAMES tf, int count = 100)
   {
      string json = FormatCandlesJSON(sym, tf, count);
      if(json == "") return false;
      return PostJSON(ActiveBaseUrl() + "/mt5/upload-candles", json,
                      sym + " " + TimeframeName(tf));
   }

   bool UploadAllTimeframes(string sym)
   {
      string json = "{\"protocol_version\":1,\"symbol\":\"" + sym + "\",\"timeframes\":{";
      string names[6] = {"M1", "M5", "M15", "H1", "H4", "D1"};
      ENUM_TIMEFRAMES tfs[6] = {PERIOD_M1, PERIOD_M5, PERIOD_M15,
                                PERIOD_H1, PERIOD_H4, PERIOD_D1};
      int counts[6] = {1500, 100, 100, 100, 100, 100};
      for(int i = 0; i < 6; i++)
      {
         string candles = FormatCandleArrayJSON(sym, tfs[i], counts[i]);
         if(candles == "" || candles == "[]") return false;
         if(i > 0) json += ",";
         json += "\"" + names[i] + "\":" + candles;
      }
      json += "}}";
      return PostJSON(ActiveBaseUrl() + "/mt5/upload-candles/batch", json,
                      sym + " batch M1/M5/M15/H1/H4/D1");
   }
};
#endif
