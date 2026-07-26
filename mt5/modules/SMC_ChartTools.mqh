#ifndef SMC_CHARTTOOLS_MQH
#define SMC_CHARTTOOLS_MQH

// EMA LINES - dessine EMA 200, 100, 50 sur le graphique
void SMCCT_DrawEMALine(const string label, const int period, const ENUM_TIMEFRAMES tf, const color clr, const int width=1)
{
   int handle = iMA(_Symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return;
   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(handle, 0, 0, 500, buf) < 2) { IndicatorRelease(handle); return; }
   for(int i=1; i<500; i++)
   {
      if(buf[i]==0 || buf[i-1]==0) continue;
      string obj = label + "_" + IntegerToString(i);
      ObjectCreate(0, obj, OBJ_TREND, 0, iTime(_Symbol, tf, i-1), buf[i-1], iTime(_Symbol, tf, i), buf[i]);
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, obj, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, obj, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, obj, OBJPROP_BACK, true);
   }
   IndicatorRelease(handle);
}

void SMCCT_DrawAllEMAs()
{
   SMCCT_DrawEMALine("SMA_M", 200, PERIOD_CURRENT, clrRed, 2);
   SMCCT_DrawEMALine("SMA_H", 100, PERIOD_CURRENT, clrGold, 1);
   SMCCT_DrawEMALine("SMA_Q", 50, PERIOD_CURRENT, clrDodgerBlue, 1);
}

void SMCCT_CleanEMAs()
{
   string prefixes[] = {"SMA_M_", "SMA_H_", "SMA_Q_"};
   for(int p=0; p<3; p++)
   {
      int total = ObjectsTotal(0, 0, OBJ_TREND);
      for(int i=total-1; i>=0; i--)
      {
         string name = ObjectName(0, i, 0, OBJ_TREND);
         if(StringFind(name, prefixes[p]) == 0)
            ObjectDelete(0, name);
      }
   }
}

// SESSIONS - dessine les zones asiatique, europeenne, new-yorkaise
void SMCCT_DrawSessionZone(const string label, const datetime start, const datetime end, const color clr, const string txt)
{
   string obj = "SESS_" + label;
   if(ObjectCreate(0, obj, OBJ_RECTANGLE, 0, start, ChartGetDouble(0, CHART_PRICE_MAX), end, ChartGetDouble(0, CHART_PRICE_MIN)))
   {
      ObjectSetInteger(0, obj, OBJPROP_FILL, true);
      ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, obj, OBJPROP_BACK, true);
      ObjectSetInteger(0, obj, OBJPROP_WIDTH, 0);
   }
   string lbl = "SESS_LABEL_" + label;
   ObjectCreate(0, lbl, OBJ_TEXT, 0, start + 300, ChartGetDouble(0, CHART_PRICE_MAX) * 0.98);
   ObjectSetString(0, lbl, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, lbl, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 10);
}

void SMCCT_DrawAllSessions()
{
   MqlDateTime dt; TimeCurrent(dt);
   datetime today = dt.year*100000000 + dt.mon*1000000 + dt.day*10000;
   datetime dayStart = StringToTime(IntegerToString(dt.year) + "." + IntegerToString(dt.mon) + "." + IntegerToString(dt.day) + " 00:00");

   datetime asianStart = dayStart + 23*3600;
   datetime asianEnd   = dayStart + 32*3600;
   datetime londonStart = dayStart + 7*3600;
   datetime londonEnd  = dayStart + 16*3600;
   datetime nyStart   = dayStart + 13*3600;
   datetime nyEnd     = dayStart + 22*3600;

   SMCCT_DrawSessionZone("ASIAN", asianStart, asianEnd, 0x4A4A5A, "ASIAN");   // Dim gray-blue
   SMCCT_DrawSessionZone("LONDON", londonStart, londonEnd, 0x1A3A5C, "LONDON"); // Dim blue
   SMCCT_DrawSessionZone("NY", nyStart, nyEnd, 0x5C1A1A, "NEW YORK");           // Dim dark red
}

void SMCCT_CleanSessions()
{
   string prefixes[] = {"SESS_ASIAN", "SESS_LONDON", "SESS_NY", "SESS_LABEL_ASIAN", "SESS_LABEL_LONDON", "SESS_LABEL_NY"};
   for(int p=0; p<6; p++)
   {
      ObjectDelete(0, "SESS_" + prefixes[p]);
      ObjectDelete(0, "SESS_LABEL_" + prefixes[p]);
   }
}

//+------------------------------------------------------------------+
//| SMCCT_DrawCorrectionOverlay — overlay de correction Dow (vert/rouge)
//| La zone semi-transparente apparaît quand Dow Theory = BULL ou BEAR
//| et disparaît quand le prix quitte la zone (WAIT/consolidation).   |
//+------------------------------------------------------------------+
void SMCCT_DrawCorrectionOverlay()
{
   string symbol = _Symbol;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   int vcgVerdict = g_smcGomVerdictNum;
   bool dowBull = (vcgVerdict >= 2);
   bool dowBear = (vcgVerdict <= -2);

   uint   fillColor = 0;
   color  lineColor = clrNONE;

   if(dowBull)
   {
      fillColor = ColorToARGB(clrLime, 40);
      lineColor = clrLime;
   }
   else if(dowBear)
   {
      fillColor = ColorToARGB(clrRed, 40);
      lineColor = clrRed;
   }

   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double mid = (bid + ask) / 2.0;

   double zoneWidthPts = 122.5;
   double zoneLow  = mid - zoneWidthPts * _Point * 0.5;
   double zoneHigh = mid + zoneWidthPts * _Point * 0.5;

   string rectName = "DOW_CORRECTION_RECT";
   string textName = "DOW_CORRECTION_TEXT";
   ObjectDelete(0, rectName);
   ObjectDelete(0, textName);

   if(fillColor != clrNONE)
   {
      datetime now = TimeCurrent();
      datetime future = now + PeriodSeconds(PERIOD_CURRENT) * 20;

      ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, now, zoneLow, future, zoneHigh);
      ObjectSetInteger(0, rectName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, rectName, OBJPROP_FILL, true);
      ObjectSetInteger(0, rectName, OBJPROP_BACK, true);
      ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, rectName, OBJPROP_SELECTABLE, false);

      string dirTxt = dowBull ? "BULL" : "BEAR";
      ObjectCreate(0, textName, OBJ_TEXT, 0, now, zoneHigh);
      ObjectSetString(0, textName, OBJPROP_TEXT, " DOW " + dirTxt + " EP=" + DoubleToString(mid, digits));
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, textName, OBJPROP_COLOR, lineColor);
      ObjectSetInteger(0, textName, OBJPROP_BACK, false);
      ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
   }

   Print("[SMCCT] Dow Overlay: ", dowBull ? "BULL" : (dowBear ? "BEAR" : "WAIT"),
         " EP=", DoubleToString(mid, digits),
         " zone=[", DoubleToString(zoneLow, digits), " - ", DoubleToString(zoneHigh, digits), "]");
}

#endif
