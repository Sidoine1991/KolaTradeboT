//+------------------------------------------------------------------+
//| OrderFlow Graphics Module — Dessine orderflow directement sur le chart
//| Zones de prix acheteurs (vert) vs vendeurs (rouge)
//+------------------------------------------------------------------+

#ifndef _ORDERFLOW_GRAPHICS_MQH_
#define _ORDERFLOW_GRAPHICS_MQH_

//+------------------------------------------------------------------+
//| Structure: Orderflow Data
//+------------------------------------------------------------------+
struct OrderFlowData
{
   double buyer_volume;    // Volume acheteurs (bid)
   double seller_volume;   // Volume vendeurs (ask)
   double ratio;           // buyer_volume / seller_volume
   double mid_price;       // Prix mid (bid + ask) / 2
   string dominance;       // "BUYERS" | "SELLERS" | "BALANCED"
   double buyer_price;     // Niveau de prix des acheteurs
   double seller_price;    // Niveau de prix des vendeurs
};

//+------------------------------------------------------------------+
//| Analyser l'orderflow
//+------------------------------------------------------------------+
OrderFlowData AnalyzeOrderflow()
{
   OrderFlowData flow;
   flow.buyer_volume = 0.0;
   flow.seller_volume = 0.0;
   flow.ratio = 1.0;
   flow.dominance = "BALANCED";
   flow.mid_price = 0.0;
   flow.buyer_price = 0.0;
   flow.seller_price = 0.0;

   // Lire tick actuel
   MqlTick tick = {};
   if(!SymbolInfoTick(_Symbol, tick))
      return flow;

   flow.mid_price = (tick.bid + tick.ask) / 2.0;
   flow.seller_price = tick.ask;  // Les vendeurs vendent à l'ask
   flow.buyer_price = tick.bid;   // Les acheteurs achètent au bid

   // Lire volume récent
   long volume;
   if(!SymbolInfoInteger(_Symbol, SYMBOL_VOLUME, volume))
      volume = 0;

   // Analyser les 5 derniers bars pour dominance
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_M1, 0, 5, rates) < 5)
      return flow;

   double buyers = 0, sellers = 0;
   for(int i = 0; i < 5; i++)
   {
      double body = MathAbs(rates[i].close - rates[i].open);

      // Si close > open = haussier = acheteurs dominant
      if(rates[i].close > rates[i].open)
         buyers += body;
      else
         sellers += body;
   }

   flow.buyer_volume = buyers * volume / 100000.0;
   flow.seller_volume = sellers * volume / 100000.0;

   // Ratio: > 1.0 = plus d'acheteurs
   if(flow.seller_volume > 0)
      flow.ratio = flow.buyer_volume / flow.seller_volume;

   // Dominance
   if(flow.ratio > 1.3)
      flow.dominance = "BUYERS";
   else if(flow.ratio < 0.75)
      flow.dominance = "SELLERS";
   else
      flow.dominance = "BALANCED";

   return flow;
}

//+------------------------------------------------------------------+
//| Dessiner les zones orderflow directement sur le chart
//+------------------------------------------------------------------+
void DrawOrderFlowOnChart()
{
   OrderFlowData flow = AnalyzeOrderflow();
   long chId = ChartID();
   if(chId <= 0) return;

   // Copier les 10 dernières bougies pour établir les niveaux
   MqlRates rates[];
   datetime times[];
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(times, true);

   if(CopyRates(_Symbol, PERIOD_M1, 0, 10, rates) < 10 ||
      CopyTime(_Symbol, PERIOD_M1, 0, 10, times) < 10)
      return;

   datetime now = TimeCurrent();
   datetime start_time = times[9];  // Bar la plus ancienne
   datetime end_time = times[0];    // Bar la plus récente

   // Zone des acheteurs (bas, en vert)
   string buyer_zone = "ORDERFLOW_BUYER_" + _Symbol;
   ObjectDelete(chId, buyer_zone);
   ObjectCreate(chId, buyer_zone, OBJ_RECTANGLE, 0, start_time, flow.buyer_price, end_time, rates[0].low);
   ObjectSetInteger(chId, buyer_zone, OBJPROP_FILL, true);
   ObjectSetInteger(chId, buyer_zone, OBJPROP_BACK, true);

   // Couleur acheteurs: vert transparent
   if(flow.dominance == "BUYERS")
      ObjectSetInteger(chId, buyer_zone, OBJPROP_COLOR, C'0,255,100');  // Vert vif
   else
      ObjectSetInteger(chId, buyer_zone, OBJPROP_COLOR, C'0,100,50');   // Vert foncé

   // Zone des vendeurs (haut, en rouge)
   string seller_zone = "ORDERFLOW_SELLER_" + _Symbol;
   ObjectDelete(chId, seller_zone);
   ObjectCreate(chId, seller_zone, OBJ_RECTANGLE, 0, start_time, rates[0].high, end_time, flow.seller_price);
   ObjectSetInteger(chId, seller_zone, OBJPROP_FILL, true);
   ObjectSetInteger(chId, seller_zone, OBJPROP_BACK, true);

   // Couleur vendeurs: rouge transparent
   if(flow.dominance == "SELLERS")
      ObjectSetInteger(chId, seller_zone, OBJPROP_COLOR, C'255,50,50');   // Rouge vif
   else
      ObjectSetInteger(chId, seller_zone, OBJPROP_COLOR, C'100,50,50');   // Rouge foncé

   // Ligne Mid (équilibre)
   string mid_line = "ORDERFLOW_MID_" + _Symbol;
   ObjectDelete(chId, mid_line);
   ObjectCreate(chId, mid_line, OBJ_HLINE, 0, 0, flow.mid_price);
   ObjectSetInteger(chId, mid_line, OBJPROP_COLOR, C'200,200,0');   // Jaune
   ObjectSetInteger(chId, mid_line, OBJPROP_WIDTH, 1);
   ObjectSetInteger(chId, mid_line, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetString(chId, mid_line, OBJPROP_TOOLTIP, "Mid: " + DoubleToString(flow.mid_price, _Digits));
}

#endif // _ORDERFLOW_GRAPHICS_MQH_
