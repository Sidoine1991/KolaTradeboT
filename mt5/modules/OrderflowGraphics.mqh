//+------------------------------------------------------------------+
//| OrderFlow Graphics � bandes SL/TP orderflow sur le chart         |
//| BUY  : petite bande rouge SL sous le prix + bande verte TP au-dessus (subdivisions)
//| SELL : bande rouge sous le prix � SL en bas, TP subdivis�s vers le haut
//+------------------------------------------------------------------+

#ifndef _ORDERFLOW_GRAPHICS_MQH_
#define _ORDERFLOW_GRAPHICS_MQH_

input bool ShowOrderFlowSLTPBands = true;  // Bandes orderflow SL/TP sur chart
input int  OrderFlowTPLevels      = 3;     // Niveaux TP subdivises orderflow (1-5)

//+------------------------------------------------------------------+
struct OrderFlowData
{
   double buyer_volume;
   double seller_volume;
   double ratio;
   double mid_price;
   string dominance;
   double buyer_price;
   double seller_price;
};

//+------------------------------------------------------------------+
void OF_DeleteByPrefix(const long chId, const string prefix)
{
   int total = ObjectsTotal(chId, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(chId, i, 0, -1);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(chId, name);
   }
}

//+------------------------------------------------------------------+
double OF_ZoneMinDistance(const string sym, const double refPx)
{
   double minD = SMCGP_MinStopDistance(sym, refPx);
   if(minD > 0) return minD;

   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(pt <= 0) pt = _Point;
   return MathMax(pt * 50.0, refPx * 0.001);
}

//+------------------------------------------------------------------+
void OF_DrawZoneRect(const long chId, const string name,
                     const datetime t0, const datetime t1,
                     const double priceTop, const double priceBot,
                     const color clr, const int alpha = 80)
{
   if(priceTop <= priceBot) return;
   ObjectDelete(chId, name);
   ObjectCreate(chId, name, OBJ_RECTANGLE, 0, t0, priceTop, t1, priceBot);
   ObjectSetInteger(chId, name, OBJPROP_FILL, true);
   ObjectSetInteger(chId, name, OBJPROP_BACK, true);
   ObjectSetInteger(chId, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(chId, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chId, name, OBJPROP_BGCOLOR, clr);
}

//+------------------------------------------------------------------+
void OF_DrawZoneLabel(const long chId, const string name,
                      const datetime tMid, const double price,
                      const string text, const color clr)
{
   ObjectDelete(chId, name);
   ObjectCreate(chId, name, OBJ_TEXT, 0, tMid, price);
   ObjectSetString(chId, name, OBJPROP_TEXT, text);
   ObjectSetInteger(chId, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(chId, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(chId, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetInteger(chId, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
OrderFlowData AnalyzeOrderflow()
{
   OrderFlowData flow;
   flow.buyer_volume  = 0.0;
   flow.seller_volume = 0.0;
   flow.ratio         = 1.0;
   flow.dominance     = "BALANCED";
   flow.mid_price     = 0.0;
   flow.buyer_price   = 0.0;
   flow.seller_price  = 0.0;

   MqlTick tick = {};
   if(!SymbolInfoTick(_Symbol, tick))
      return flow;

   flow.mid_price    = (tick.bid + tick.ask) / 2.0;
   flow.seller_price = tick.ask;
   flow.buyer_price  = tick.bid;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5)
      return flow;

   double buyers = 0.0, sellers = 0.0;
   for(int i = 0; i < 5; i++)
   {
      double body = MathAbs(rates[i].close - rates[i].open);
      if(rates[i].close > rates[i].open) buyers  += body;
      else                               sellers += body;
   }

   flow.buyer_volume  = buyers;
   flow.seller_volume = sellers;
   if(sellers > 0) flow.ratio = buyers / sellers;

   if(flow.ratio > 1.3)      flow.dominance = "BUYERS";
   else if(flow.ratio < 0.75) flow.dominance = "SELLERS";
   else                       flow.dominance = "BALANCED";

   return flow;
}

//+------------------------------------------------------------------+
//| SL/TP depuis bandes orderflow (pour ex�cution)                   |
//| BUY  : SL sous le prix (bande rouge), TP au-dessus (vert)          |
//| SELL : SL au-dessus du prix, TP dans bande rouge sous le prix    |
//+------------------------------------------------------------------+
bool OrderFlow_GetTradeStops(const string sym, const int dirSign, const double entryPx,
                             double &sl, double &tp1, double &tp2, double &tp3)
{
   if(dirSign == 0 || entryPx <= 0) return false;
   int dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   double minD = OF_ZoneMinDistance(sym, entryPx);
   double slH    = minD * 0.35;
   double tpStep = minD * 1.0;

   if(dirSign == 1)
   {
      sl  = NormalizeDouble(entryPx - slH, dg);
      tp1 = NormalizeDouble(entryPx + tpStep, dg);
      tp2 = NormalizeDouble(entryPx + tpStep * 2.0, dg);
      tp3 = NormalizeDouble(entryPx + tpStep * 3.0, dg);
   }
   else
   {
      sl  = NormalizeDouble(entryPx + slH, dg);
      tp1 = NormalizeDouble(entryPx - tpStep, dg);
      tp2 = NormalizeDouble(entryPx - tpStep * 2.0, dg);
      tp3 = NormalizeDouble(entryPx - tpStep * 3.0, dg);
   }
   return (sl > 0 && tp1 > 0);
}

//+------------------------------------------------------------------+
void DrawOrderFlowOnChart()
{
   long chId = ChartID();
   if(chId <= 0) return;

   OF_DeleteByPrefix(chId, "ORDERFLOW_");
   if(!ShowOrderFlowSLTPBands) return;

   OrderFlowData flow = AnalyzeOrderflow();
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0 || ask <= 0) return;

   double entry = (bid + ask) / 2.0;
   double minD  = OF_ZoneMinDistance(_Symbol, entry);
   double slH   = minD * 0.35;
   double tpStep = minD * 1.0;
   int tpLvls = OrderFlowTPLevels;
   if(tpLvls < 1) tpLvls = 1;
   if(tpLvls > 5) tpLvls = 5;

   datetime times[];
   ArraySetAsSeries(times, true);
   if(CopyTime(_Symbol, PERIOD_CURRENT, 0, 10, times) < 10) return;

   datetime t0 = times[9];
   datetime t1 = times[0] + PeriodSeconds(PERIOD_CURRENT) * 20;
   datetime tMid = times[4];

   bool showBuy  = (flow.dominance == "BUYERS"  || flow.dominance == "BALANCED");
   bool showSell = (flow.dominance == "SELLERS" || flow.dominance == "BALANCED");
   int alphaBuy  = (flow.dominance == "BUYERS")  ? 70 : 110;
   int alphaSell = (flow.dominance == "SELLERS") ? 70 : 110;

   // ??? OVERFLOW BUY : SL rouge sous le prix, TP vert au-dessus subdivis� ???
   if(showBuy)
   {
      double slTop = entry;
      double slBot = entry - slH;
      OF_DrawZoneRect(chId, "ORDERFLOW_BUY_SL", t0, t1, slTop, slBot, C'180,40,40', alphaBuy);
      OF_DrawZoneLabel(chId, "ORDERFLOW_BUY_SL_LBL", tMid, (slTop + slBot) / 2.0, "SL BUY", clrWhite);

      double tpBase = entry;
      for(int i = 0; i < tpLvls; i++)
      {
         double tpLo = tpBase + tpStep * (double)i;
         double tpHi = tpBase + tpStep * (double)(i + 1);
         string zn = "ORDERFLOW_BUY_TP" + IntegerToString(i + 1);
         OF_DrawZoneRect(chId, zn, t0, t1, tpHi, tpLo, C'0,140,70', alphaBuy);
         OF_DrawZoneLabel(chId, zn + "_LBL", tMid, (tpLo + tpHi) / 2.0,
                           "TP" + IntegerToString(i + 1), clrWhite);
      }
   }

   // ??? OVERFLOW SELL : bande rouge sous le prix � SL en bas, TP subdivis�s vers le haut ???
   if(showSell)
   {
      double bandTop = entry;
      double bandBot = entry - slH - tpStep * (double)tpLvls;
      OF_DrawZoneRect(chId, "ORDERFLOW_SELL_BAND", t0, t1, bandTop, bandBot, C'120,30,30', alphaSell);

      // Petite bande SL en bas de la zone rouge
      double slStripTop = bandBot + slH;
      OF_DrawZoneRect(chId, "ORDERFLOW_SELL_SL", t0, t1, slStripTop, bandBot, C'220,50,50', 50);
      OF_DrawZoneLabel(chId, "ORDERFLOW_SELL_SL_LBL", tMid, (slStripTop + bandBot) / 2.0, "SL SELL", clrWhite);

      // Subdivisions TP : du bas vers le haut (TP1 proche du SL strip, TPn pr�s du prix)
      for(int i = 0; i < tpLvls; i++)
      {
         double tpLo = slStripTop + tpStep * (double)i;
         double tpHi = slStripTop + tpStep * (double)(i + 1);
         if(tpHi > bandTop) tpHi = bandTop;
         if(tpLo >= tpHi) continue;
         string zn = "ORDERFLOW_SELL_TP" + IntegerToString(i + 1);
         OF_DrawZoneRect(chId, zn, t0, t1, tpHi, tpLo, C'200,60,60', alphaSell + 15);
         OF_DrawZoneLabel(chId, zn + "_LBL", tMid, (tpLo + tpHi) / 2.0,
                           "TP" + IntegerToString(i + 1), clrWhite);
      }
   }

   // Ligne d'entr�e / mid
   ObjectDelete(chId, "ORDERFLOW_ENTRY");
   ObjectCreate(chId, "ORDERFLOW_ENTRY", OBJ_HLINE, 0, 0, entry);
   ObjectSetInteger(chId, "ORDERFLOW_ENTRY", OBJPROP_COLOR, C'255,215,0');
   ObjectSetInteger(chId, "ORDERFLOW_ENTRY", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(chId, "ORDERFLOW_ENTRY", OBJPROP_WIDTH, 1);
   ObjectSetString(chId, "ORDERFLOW_ENTRY", OBJPROP_TOOLTIP,
                   "Entry/Mid " + DoubleToString(entry, _Digits) + " | " + flow.dominance);
}

#endif // _ORDERFLOW_GRAPHICS_MQH_
