//+------------------------------------------------------------------+
//| SMC_PredictivePanel.mqh — Setup SMC prédictif (API → graphique)  |
//| Connecté à /api/predictive-panel (agents-dashboard)              |
//+------------------------------------------------------------------+
#ifndef SMC_PREDICTIVE_PANEL_MQH
#define SMC_PREDICTIVE_PANEL_MQH

struct SMCPP_PanelState
{
   bool     ok;
   string   alert;
   string   direction;
   string   h1Label;
   string   m15Label;
   double   price;
   double   tp1;
   double   tp2;
   double   sl;
   double   zoneHigh;
   double   zoneLow;
   double   levelLow;
   double   levelHigh;
   double   pathPrices[];
   datetime lastPoll;
   datetime lastAlert;
};

SMCPP_PanelState g_predPanel;

void SMCPP_InitPanelState()
{
   g_predPanel.ok = false;
   g_predPanel.alert = "NONE";
   g_predPanel.direction = "NEUTRAL";
   g_predPanel.h1Label = "";
   g_predPanel.m15Label = "";
   g_predPanel.price = 0;
   g_predPanel.tp1 = 0;
   g_predPanel.tp2 = 0;
   g_predPanel.sl = 0;
   g_predPanel.zoneHigh = 0;
   g_predPanel.zoneLow = 0;
   g_predPanel.levelLow = 0;
   g_predPanel.levelHigh = 0;
   ArrayFree(g_predPanel.pathPrices);
   g_predPanel.lastPoll = 0;
   g_predPanel.lastAlert = 0;
}

void SMCPP_ClearDrawings()
{
   ObjectsDeleteAll(0, "PRED_");
   ObjectDelete(0, "PRED_LBL_STATUS");
}

bool SMCPP_ExtractPricesFromPath(const string &body, double &prices[])
{
   ArrayFree(prices);
   int pos = StringFind(body, "\"path\"");
   if(pos < 0) return false;
   int end = StringFind(body, "]", pos);
   if(end < 0) return false;
   string chunk = StringSubstr(body, pos, end - pos);
   int p = 0;
   while(true)
   {
      int pk = StringFind(chunk, "\"price\":", p);
      if(pk < 0) break;
      pk += 8;
      string num = "";
      for(int i = pk; i < StringLen(chunk); i++)
      {
         ushort c = StringGetCharacter(chunk, i);
         if((c >= '0' && c <= '9') || c == '.' || c == '-')
            num += ShortToString(c);
         else if(StringLen(num) > 0) break;
      }
      if(StringLen(num) > 0)
      {
         int n = ArraySize(prices);
         ArrayResize(prices, n + 1);
         prices[n] = StringToDouble(num);
      }
      p = pk + 1;
   }
   return (ArraySize(prices) > 0);
}

bool SMCPP_ExtractFirstZone(const string &body, double &hi, double &lo)
{
   hi = lo = 0;
   int zpos = StringFind(body, "\"zones\"");
   if(zpos < 0) return false;
   string zchunk = StringSubstr(body, zpos, MathMin(400, StringLen(body) - zpos));
   int hpos = StringFind(zchunk, "\"high\":");
   int lpos = StringFind(zchunk, "\"low\":");
   if(hpos < 0 || lpos < 0) return false;
   string hsub = StringSubstr(zchunk, hpos + 7, 20);
   string lsub = StringSubstr(zchunk, lpos + 6, 20);
   hi = StringToDouble(hsub);
   lo = StringToDouble(lsub);
   return (hi > 0 && lo > 0 && hi > lo);
}

void SMCPP_DrawHLine(const string name, const double price, const color clr, const string lbl, const ENUM_LINE_STYLE style = STYLE_DASH)
{
   if(price <= 0) return;
   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   datetime t1 = t0 + PeriodSeconds(PERIOD_CURRENT) * 80;
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_TREND, 0, t0, price, t1, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);

   string lname = name + "_LBL";
   ObjectDelete(0, lname);
   ObjectCreate(0, lname, OBJ_TEXT, 0, t1, price);
   ObjectSetString(0, lname, OBJPROP_TEXT, lbl);
   ObjectSetInteger(0, lname, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lname, OBJPROP_FONTSIZE, 8);
}

void SMCPP_DrawZoneRect(const string name, const double hi, const double lo, const color fill, const int alpha = 40)
{
   if(hi <= 0 || lo <= 0 || hi <= lo) return;
   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 5);
   datetime t1 = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 60;
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, t0, hi, t1, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR, fill);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
}

void SMCPP_DrawPath(const double &prices[])
{
   int n = ArraySize(prices);
   if(n < 2) return;
   datetime t0 = iTime(_Symbol, PERIOD_CURRENT, 0);
   int stepSec = PeriodSeconds(PERIOD_CURRENT);
   for(int i = 0; i < n - 1; i++)
   {
      string seg = "PRED_PATH_" + IntegerToString(i);
      datetime t1 = t0 + (i + 1) * stepSec;
      datetime t2 = t0 + (i + 2) * stepSec;
      ObjectDelete(0, seg);
      ObjectCreate(0, seg, OBJ_TREND, 0, t1, prices[i], t2, prices[i + 1]);
      ObjectSetInteger(0, seg, OBJPROP_COLOR, 0x6A6A6A);  // Dim white path
      ObjectSetInteger(0, seg, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, seg, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, seg, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, seg, OBJPROP_BACK, false);
   }
}

void SMCPP_DrawPanel(const SMCPP_PanelState &st)
{
   if(!PredictivePanelDrawChart) return;
   SMCPP_ClearDrawings();

   color obClr = (st.direction == "BUY") ? 0x1A5C8A : 0x8A5C1A;  // Dim OB colors
   if(st.zoneHigh > st.zoneLow)
      SMCPP_DrawZoneRect("PRED_OB_ZONE", st.zoneHigh, st.zoneLow, obClr);

   double top = MathMax(st.tp2, MathMax(st.levelHigh, st.zoneHigh));
   double bot = MathMin(st.sl, MathMin(st.levelLow, st.zoneLow));
   if(top > bot && st.price > 0)
      SMCPP_DrawZoneRect("PRED_PLAY_ZONE", top, bot, 0x0D1D2E);  // Very dim blue (transparent)

   SMCPP_DrawHLine("PRED_LVL_LOW", st.levelLow, 0x8A8A00, "Low H1 - M15");  // Dim gold
   SMCPP_DrawHLine("PRED_LVL_HIGH", st.levelHigh, 0x8A8A00, "High récent"); // Dim gold
   SMCPP_DrawHLine("PRED_TP1", st.tp1, 0x1A8A1A, "TP1", STYLE_SOLID);      // Dim lime
   SMCPP_DrawHLine("PRED_TP2", st.tp2, 0x1A6A1A, "TP2", STYLE_SOLID);      // Dim green
   SMCPP_DrawHLine("PRED_SL", st.sl, 0x8A1A1A, "SL", STYLE_SOLID);         // Dim red
   SMCPP_DrawPath(st.pathPrices);

   string status = "PRED: " + st.alert + " | " + st.direction;
   if(StringLen(st.m15Label) > 0) status += " | " + st.m15Label;
   ObjectDelete(0, "PRED_LBL_STATUS");
   ObjectCreate(0, "PRED_LBL_STATUS", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "PRED_LBL_STATUS", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, "PRED_LBL_STATUS", OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, "PRED_LBL_STATUS", OBJPROP_YDISTANCE, 95);
   ObjectSetString(0, "PRED_LBL_STATUS", OBJPROP_TEXT, status);
   ObjectSetInteger(0, "PRED_LBL_STATUS", OBJPROP_COLOR,
                   st.alert == "ACTIVE" ? 0x1A8A1A : st.alert == "FORMING" ? 0x8A5C1A : 0x5A5A5A);  // Dimmed
   ObjectSetInteger(0, "PRED_LBL_STATUS", OBJPROP_FONTSIZE, 9);
}

bool SMCPP_FetchPanel(const string symbol, string &body)
{
   string sym = symbol;
   StringReplace(sym, " ", "%20");
   string path = "/api/predictive-panel?symbol=" + sym + "&chart_tf=M15";
   string url = AI_ServerURL + path;
   char post[], result[];
   string headers = "Content-Type: application/json\r\n";
   string respH = "";
   int code = WebRequest("GET", url, headers, AI_Timeout_ms, post, result, respH);
   if(code != 200)
   {
      static datetime s_log = 0;
      if(TimeCurrent() - s_log >= 120)
      {
         s_log = TimeCurrent();
         Print("[PRED-PANEL] HTTP ", code, " url=", url, " err=", GetLastError());
      }
      return false;
   }
   body = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return (StringFind(body, "\"ok\":true") >= 0 || StringFind(body, "\"ok\": true") >= 0);
}

double SMCPP_JsonDoubleSafe(const string json, const string key, double defaultIfNull)
{
   if(StringLen(json) < 10) return defaultIfNull;

   string needle = "\"" + key + "\"";
   int p = StringFind(json, needle);
   if(p < 0) return defaultIfNull;

   int colon = StringFind(json, ":", p);
   if(colon < 0) return defaultIfNull;

   int start = colon + 1;
   while(start < StringLen(json) && (StringGetCharacter(json, start) == ' ' || StringGetCharacter(json, start) == '\t'))
      start++;

   if(start >= StringLen(json)) return defaultIfNull;

   ushort c = StringGetCharacter(json, start);
   if(c == '"')
   {
      start++;
      int end = StringFind(json, "\"", start);
      if(end < 0) return defaultIfNull;
      string value = StringSubstr(json, start, end - start);
      StringTrimLeft(value);
      StringTrimRight(value);
      if(StringLen(value) <= 0) return defaultIfNull;
      return StringToDouble(value);
   }

   int end = start;
   while(end < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, end);
      if(ch == ',' || ch == '}' || ch == '\n' || ch == '\r') break;
      end++;
   }

   if(end <= start) return defaultIfNull;

   string value = StringSubstr(json, start, end - start);
   StringTrimLeft(value);
   StringTrimRight(value);

   if(StringLen(value) <= 0 || value == "null" || value == "undefined")
      return defaultIfNull;

   return StringToDouble(value);
}

void SMCPP_ParseAndStore(const string &body)
{
   g_predPanel.ok = true;
   g_predPanel.alert = SMCGP_JsonString(body, "alert");
   if(g_predPanel.alert == "") g_predPanel.alert = "NONE";
   g_predPanel.direction = SMCGP_JsonString(body, "direction");
   g_predPanel.price = SMCGP_JsonDouble(body, "price", 0);

   int h1p = StringFind(body, "\"h1\"");
   if(h1p >= 0)
   {
      string hchunk = StringSubstr(body, h1p, 200);
      g_predPanel.h1Label = SMCGP_JsonString(hchunk, "label");
   }
   int m15p = StringFind(body, "\"m15\"");
   if(m15p >= 0)
   {
      string mchunk = StringSubstr(body, m15p, 200);
      g_predPanel.m15Label = SMCGP_JsonString(mchunk, "label");
   }

   int proj = StringFind(body, "\"projection\"");
   if(proj >= 0)
   {
      string pchunk = StringSubstr(body, proj, 600);
      g_predPanel.tp1 = SMCPP_JsonDoubleSafe(pchunk, "tp1", -1.0);
      g_predPanel.tp2 = SMCPP_JsonDoubleSafe(pchunk, "tp2", -1.0);
      g_predPanel.sl  = SMCPP_JsonDoubleSafe(pchunk, "sl", -1.0);

      if(g_predPanel.tp1 < 0) g_predPanel.tp1 = 0;
      if(g_predPanel.tp2 < 0) g_predPanel.tp2 = 0;
      if(g_predPanel.sl < 0) g_predPanel.sl = 0;

      if(g_predPanel.tp1 <= 0 && pchunk != "")
      {
         int tp1Pos = StringFind(body, "\"tp1\"");
         if(tp1Pos >= 0)
         {
            string tp1Chunk = StringSubstr(body, tp1Pos, 200);
            g_predPanel.tp1 = SMCGP_JsonDouble(tp1Chunk, "value", 0);
         }
      }

      if(g_predPanel.tp2 <= 0 && pchunk != "")
      {
         int tp2Pos = StringFind(body, "\"tp2\"");
         if(tp2Pos >= 0)
         {
            string tp2Chunk = StringSubstr(body, tp2Pos, 200);
            g_predPanel.tp2 = SMCGP_JsonDouble(tp2Chunk, "value", 0);
         }
      }
   }

   SMCPP_ExtractFirstZone(body, g_predPanel.zoneHigh, g_predPanel.zoneLow);
   SMCPP_ExtractPricesFromPath(body, g_predPanel.pathPrices);

   g_predPanel.levelLow = 0;
   g_predPanel.levelHigh = 0;
   int lpos = StringFind(body, "\"levels\"");
   if(lpos >= 0)
   {
      string lchunk = StringSubstr(body, lpos, 500);
      int p1 = StringFind(lchunk, "\"price\":");
      if(p1 >= 0) g_predPanel.levelLow = StringToDouble(StringSubstr(lchunk, p1 + 8, 12));
      int p2 = StringFind(lchunk, "\"price\":", p1 + 8);
      if(p2 >= 0) g_predPanel.levelHigh = StringToDouble(StringSubstr(lchunk, p2 + 8, 12));
   }
   if(g_predPanel.levelLow <= 0 && g_predPanel.sl > 0)
      g_predPanel.levelLow = g_predPanel.sl;
}

void SMCPP_AlertIfNeeded()
{
   if(!PredictivePanelAlert) return;
   if(g_predPanel.alert != "ACTIVE" && g_predPanel.alert != "FORMING") return;
   if(TimeCurrent() - g_predPanel.lastAlert < 300) return;
   g_predPanel.lastAlert = TimeCurrent();

   string tp1Display = (g_predPanel.tp1 > 0) ? StringFormat("%.5f", g_predPanel.tp1) : "N/A";
   string tp2Display = (g_predPanel.tp2 > 0) ? StringFormat("%.5f", g_predPanel.tp2) : "N/A";
   string slDisplay = (g_predPanel.sl > 0) ? StringFormat("%.5f", g_predPanel.sl) : "N/A";

   string msg = StringFormat("[PRED SETUP %s] %s %s | %s | TP1=%s TP2=%s SL=%s",
                             g_predPanel.alert, _Symbol, g_predPanel.direction,
                             g_predPanel.m15Label, tp1Display, tp2Display, slDisplay);
   Alert(msg);
   PB_SendWhatsAppAlert(msg);
   Print("[PRED-ALERT] ", msg);
}

void SMCPP_ManagePredictivePanel()
{
   if(!UsePredictivePanel || !UseAIServer) return;

   static bool s_panelInit = false;
   if(!s_panelInit)
   {
      SMCPP_InitPanelState();
      s_panelInit = true;
   }

   if(TimeCurrent() - g_predPanel.lastPoll < PredictivePanelPollSec) return;

   string body = "";
   if(!SMCPP_FetchPanel(_Symbol, body))
   {
      g_predPanel.ok = false;
      return;
   }

   g_predPanel.lastPoll = TimeCurrent();
   SMCPP_ParseAndStore(body);
   SMCPP_DrawPanel(g_predPanel);
   SMCPP_AlertIfNeeded();
}

#endif // SMC_PREDICTIVE_PANEL_MQH
