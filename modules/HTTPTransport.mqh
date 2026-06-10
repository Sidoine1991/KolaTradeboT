//+------------------------------------------------------------------+
//| HTTPTransport.mqh — Unified HTTP communication abstraction       |
//| Single responsibility: all WebRequest calls go through here      |
//+------------------------------------------------------------------+
#ifndef TM_HTTP_TRANSPORT_MQH
#define TM_HTTP_TRANSPORT_MQH

#include "TMState.mqh"

// ═══════════════════════════════════════════════════════════════════
// HTTP RESPONSE STRUCT
// ═══════════════════════════════════════════════════════════════════

struct HTTPResponse
{
   int      code;          // HTTP status code (200 = success)
   string   body;          // Response body (JSON or text)
   bool     success;       // true if code == 200
   string   error;         // Error message if failed
   int      elapsedMs;     // Round-trip time in milliseconds
};

// ═══════════════════════════════════════════════════════════════════
// HTTP REQUEST FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

HTTPResponse HTTP_Get(const string path, int timeoutMs = 5000)
{
   HTTPResponse resp;
   resp.code = 0;
   resp.body = "";
   resp.success = false;
   resp.error = "";
   resp.elapsedMs = 0;

   if(path == "" || g_state.config.aiServerURL == "")
   {
      resp.error = "Invalid path or aiServerURL";
      return resp;
   }

   string url = g_state.config.aiServerURL + path;
   char data[], result[];
   string headers = "Content-Type: application/json\r\n";
   string respH = "";

   datetime start = TimeCurrent();
   resp.code = WebRequest("GET", url, headers, timeoutMs, data, result, respH);
   resp.elapsedMs = (int)((TimeCurrent() - start) * 1000);

   resp.body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   resp.success = (resp.code == 200);

   if(!resp.success)
   {
      resp.error = StringFormat("HTTP GET failed: code=%d, url=%s", resp.code, url);
      PrintFormat("[HTTPTransport] %s", resp.error);
   }

   return resp;
}

HTTPResponse HTTP_Post(const string path, const string jsonBody, int timeoutMs = 10000)
{
   HTTPResponse resp;
   resp.code = 0;
   resp.body = "";
   resp.success = false;
   resp.error = "";
   resp.elapsedMs = 0;

   if(path == "" || g_state.config.aiServerURL == "")
   {
      resp.error = "Invalid path or aiServerURL";
      return resp;
   }

   string url = g_state.config.aiServerURL + path;
   char post[];
   StringToCharArray(jsonBody, post, 0, StringLen(jsonBody));
   ArrayResize(post, StringLen(jsonBody));
   char result[];
   string headers = "Content-Type: application/json\r\n";
   string respH = "";

   datetime start = TimeCurrent();
   resp.code = WebRequest("POST", url, headers, timeoutMs, post, result, respH);
   resp.elapsedMs = (int)((TimeCurrent() - start) * 1000);

   resp.body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   resp.success = (resp.code == 200);

   if(!resp.success)
   {
      resp.error = StringFormat("HTTP POST failed: code=%d, url=%s, body_len=%d", resp.code, url, StringLen(jsonBody));
      PrintFormat("[HTTPTransport] %s", resp.error);
   }

   return resp;
}

// ═══════════════════════════════════════════════════════════════════
// CONVENIENCE WRAPPERS FOR COMMON ENDPOINTS
// ═══════════════════════════════════════════════════════════════════

HTTPResponse HTTP_HealthCheck()
{
   return HTTP_Get("/health", 5000);
}

HTTPResponse HTTP_GetGOMVerdict(const string symbol = "")
{
   string path = "/gom-verdict";
   if(symbol != "") path += "?symbol=" + symbol;
   return HTTP_Get(path, 5000);
}

HTTPResponse HTTP_GetPendingOrders()
{
   return HTTP_Get("/pending-order", 5000);
}

HTTPResponse HTTP_PostPendingOrder(const string jsonBody)
{
   return HTTP_Post("/pending-order", jsonBody, 10000);
}

HTTPResponse HTTP_PostPendingOrderExecuted(const string orderId, const string jsonBody)
{
   string path = "/pending-order/executed/" + orderId;
   return HTTP_Post(path, jsonBody, 5000);
}

HTTPResponse HTTP_NotifyWhatsApp(const string jsonBody)
{
   return HTTP_Post("/notify-whatsapp", jsonBody, 8000);
}

// ═══════════════════════════════════════════════════════════════════
// JSON PARSING HELPERS (consolidated)
// ═══════════════════════════════════════════════════════════════════

bool JsonGetString(const string json, const string key, string &value)
{
   value = "";
   int pos = StringFind(json, "\"" + key + "\"");
   if(pos < 0) return false;

   pos = StringFind(json, ":", pos);
   if(pos < 0) return false;

   pos++;
   while(pos < StringLen(json) && (json[pos] == ' ' || json[pos] == '\t')) pos++;

   if(json[pos] == '\"')
   {
      pos++;
      int end = StringFind(json, "\"", pos);
      if(end < 0) return false;
      value = StringSubstr(json, pos, end - pos);
      return true;
   }

   return false;
}

bool JsonGetDouble(const string json, const string key, double &value)
{
   value = 0.0;
   int pos = StringFind(json, "\"" + key + "\"");
   if(pos < 0) return false;

   pos = StringFind(json, ":", pos);
   if(pos < 0) return false;

   pos++;
   while(pos < StringLen(json) && (json[pos] == ' ' || json[pos] == '\t')) pos++;

   int end = pos;
   while(end < StringLen(json) && json[end] != ',' && json[end] != '}' && json[end] != ']') end++;

   string numStr = StringSubstr(json, pos, end - pos);
   numStr = StringTrimLeft(numStr);
   numStr = StringTrimRight(numStr);

   if(numStr == "" || numStr == "null") return false;

   value = StringToDouble(numStr);
   return true;
}

bool JsonGetInt(const string json, const string key, int &value)
{
   double dval = 0.0;
   if(!JsonGetDouble(json, key, dval)) return false;
   value = (int)dval;
   return true;
}

bool JsonGetBool(const string json, const string key, bool &value)
{
   value = false;
   int pos = StringFind(json, "\"" + key + "\"");
   if(pos < 0) return false;

   pos = StringFind(json, ":", pos);
   if(pos < 0) return false;

   pos++;
   while(pos < StringLen(json) && (json[pos] == ' ' || json[pos] == '\t')) pos++;

   if(StringSubstr(json, pos, 4) == "true")
   {
      value = true;
      return true;
   }
   if(StringSubstr(json, pos, 5) == "false")
   {
      value = false;
      return true;
   }

   return false;
}

#endif // TM_HTTP_TRANSPORT_MQH
