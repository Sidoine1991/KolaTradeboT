#property copyright "TradBOT"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 9

// Plot 0: EMA200
#property indicator_label1  "EMA200"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// Plot 1: BB Upper
#property indicator_label2  "BB Upper"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

// Plot 2: BB Middle
#property indicator_label3  "BB Middle"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDarkGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1

// Plot 3: BB Lower
#property indicator_label4  "BB Lower"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrSilver
#property indicator_style4  STYLE_DOT
#property indicator_width4  1

// Plot 4: VWAP
#property indicator_label5  "VWAP"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrOrange
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2

// Plot 5: SAR (dots)
#property indicator_label6  "SAR"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrMediumPurple
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

// Plot 6: Ichimoku Kijun
#property indicator_label7  "Kijun"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrSandyBrown
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

// Plot 7: Supertrend Up
#property indicator_label8  "Supertrend Up"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrLime
#property indicator_style8  STYLE_SOLID
#property indicator_width8  2

// Plot 8: Supertrend Down
#property indicator_label9  "Supertrend Down"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrRed
#property indicator_style9  STYLE_SOLID
#property indicator_width9  2

// Inputs
input int    InpEMA200Period   = 200;
input int    InpBBPeriod       = 20;
input double InpBBDev          = 2.0;
input int    InpATRPeriod      = 14;
input int    InpVWAPWindow     = 50;
input double InpSARStep        = 0.02;
input double InpSARMax         = 0.2;
input int    InpIchiTenkan     = 9;
input int    InpIchiKijun      = 26;
input int    InpST_ATR_Period  = 10;
input double InpST_Multiplier  = 3.0;
input bool   InpDrawFractalSR  = true;
input bool   InpDrawDailyPivots= true;
// OTE Strategy inputs
input bool   InpEnableOTE      = true;   // Draw OTE zones and bias
input int    InpOTEPivotWindow = 5;      // Pivot window for impulse detection
// Trading (note: this file is an Indicator; order placement should be in an EA)
input double InpMinLot         = 1.0;    // Minimum lot size when used by an EA

// Buffers
double bufEMA200[];
double bufBBU[];
double bufBBM[];
double bufBBL[];
double bufVWAP[];
double bufSAR[];
double bufKijun[];
double bufST[];
double bufSTDn[];

// Handles
int hEMA = INVALID_HANDLE;
int hBB  = INVALID_HANDLE;
int hATR = INVALID_HANDLE;
int hSAR = INVALID_HANDLE;
int hIchi= INVALID_HANDLE;

// Utility: clear objects by prefix
void ClearObjectsByPrefix(const string prefix)
{
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--)
   {
      string name = ObjectName(0,i,-1,-1);
      if(StringFind(name,prefix)==0) ObjectDelete(0,name);
   }
}

int OnInit()
{
   IndicatorSetInteger(INDICATOR_DIGITS, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   SetIndexBuffer(0, bufEMA200, INDICATOR_DATA);
   SetIndexBuffer(1, bufBBU,    INDICATOR_DATA);
   SetIndexBuffer(2, bufBBM,    INDICATOR_DATA);
   SetIndexBuffer(3, bufBBL,    INDICATOR_DATA);
   SetIndexBuffer(4, bufVWAP,   INDICATOR_DATA);
   SetIndexBuffer(5, bufSAR,    INDICATOR_DATA);
   SetIndexBuffer(6, bufKijun,  INDICATOR_DATA);
   SetIndexBuffer(7, bufST,     INDICATOR_DATA);
   SetIndexBuffer(8, bufSTDn,   INDICATOR_DATA);

   PlotIndexSetInteger(5, PLOT_ARROW, 159); // small dot for SAR

   // Create handles
   hEMA = iMA(_Symbol, _Period, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
   hBB  = iBands(_Symbol, _Period, InpBBPeriod, InpBBDev, 0, PRICE_CLOSE);
   hATR = iATR(_Symbol, _Period, InpATRPeriod);
   hSAR = iSAR(_Symbol, _Period, InpSARStep, InpSARMax);
   hIchi= iIchimoku(_Symbol, _Period, InpIchiTenkan, InpIchiKijun, 52);

   if(hEMA==INVALID_HANDLE || hBB==INVALID_HANDLE || hATR==INVALID_HANDLE || hSAR==INVALID_HANDLE || hIchi==INVALID_HANDLE)
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   int to_copy = rates_total - prev_calculated + 10;
   if(to_copy<100) to_copy=100;
   int copied;

   // EMA200
   copied = CopyBuffer(hEMA, 0, 0, rates_total, bufEMA200);

   // BB: upper(0), middle(1), lower(2)
   CopyBuffer(hBB, 0, 0, rates_total, bufBBU);
   CopyBuffer(hBB, 1, 0, rates_total, bufBBM);
   CopyBuffer(hBB, 2, 0, rates_total, bufBBL);

   // SAR
   CopyBuffer(hSAR, 0, 0, rates_total, bufSAR);

   // Ichimoku Kijun is buffer 1
   double tmpKijun[]; ArrayResize(tmpKijun, rates_total);
   CopyBuffer(hIchi, 1, 0, rates_total, tmpKijun);
   for(int i=0;i<rates_total;i++) bufKijun[i]=tmpKijun[i];

   // VWAP approximation: sum(price*volume)/sum(volume) over window
   int win = MathMax(10, InpVWAPWindow);
   double closes[]; ArraySetAsSeries(closes,true); CopyClose(_Symbol,_Period,0,rates_total,closes);
   long   vols[];   ArraySetAsSeries(vols,true);   CopyTickVolume(_Symbol,_Period,0,rates_total,vols);
   ArraySetAsSeries(bufVWAP,true);
   for(int i=0;i<rates_total;i++)
   {
      int start = MathMax(0, i - win + 1);
      double num=0.0, den=0.0;
      for(int j=i; j>=start; j--)
      {
         num += closes[j] * (double)vols[j];
         den += (double)vols[j];
      }
      bufVWAP[i] = (den>0.0 ? num/den : EMPTY_VALUE);
   }

   // Supertrend (simple implementation)
   double highs[]; ArraySetAsSeries(highs,true); CopyHigh(_Symbol,_Period,0,rates_total,highs);
   double lows[];  ArraySetAsSeries(lows,true);  CopyLow(_Symbol,_Period,0,rates_total,lows);
   double atr[];   ArraySetAsSeries(atr,true);   CopyBuffer(hATR,0,0,rates_total,atr);
   ArraySetAsSeries(bufST,true); ArraySetAsSeries(bufSTDn,true);
   double trend=0.0; // 1 up, -1 down
   double st=0.0;
   for(int i=rates_total-1; i>=0; i--)
   {
      double mid = (highs[i] + lows[i]) * 0.5;
      double bandUp = mid + InpST_Multiplier * atr[i];
      double bandDn = mid - InpST_Multiplier * atr[i];
      if(i==rates_total-1)
      {
         st = bandUp; trend = 1.0;
      }
      else
      {
         double prevUp = bufST[i+1];
         double prevDn = bufSTDn[i+1];
         bool wasUp = (prevUp!=EMPTY_VALUE && prevDn==EMPTY_VALUE);
         double prev = (wasUp ? prevUp : prevDn);
         if(wasUp)
         {
            double st_candidate = MathMin(bandUp, prev);
            if(price[i] < st_candidate) { trend = -1.0; st = bandDn; }
            else { trend = 1.0; st = st_candidate; }
         }
         else
         {
            double st_candidate2 = MathMax(bandDn, prev);
            if(price[i] > st_candidate2) { trend = 1.0; st = bandUp; }
            else { trend = -1.0; st = st_candidate2; }
         }
      }
      if(trend>0){ bufST[i]=st; bufSTDn[i]=EMPTY_VALUE; }
      else        { bufST[i]=EMPTY_VALUE; bufSTDn[i]=st; }
   }

   // Draw Fractal S/R as objects
   if(InpDrawFractalSR)
   {
      int bars = MathMin(300, rates_total-1);
      ClearObjectsByPrefix("TB_SR_");
      double up[]; ArraySetAsSeries(up,true);
      double dn[]; ArraySetAsSeries(dn,true);
      int hFrac = iFractals(_Symbol,_Period);
      if(hFrac!=INVALID_HANDLE)
      {
         CopyBuffer(hFrac,0,0,rates_total,up);
         CopyBuffer(hFrac,1,0,rates_total,dn);
         int drawnU=0, drawnD=0, maxSeg=8, segLen=25;
         datetime t[]; ArraySetAsSeries(t,true); CopyTime(_Symbol,_Period,0,rates_total,t);
         for(int i=1; i<bars-1 && (drawnU<maxSeg || drawnD<maxSeg); i++)
         {
            if(drawnU<maxSeg && up[i]!=EMPTY_VALUE)
            {
               int j=MathMax(0, i-segLen);
               string n=StringFormat("TB_SR_U_%d",(int)t[i]);
               ObjectCreate(0,n,OBJ_TREND,0,t[i],up[i],t[j],up[i]);
               ObjectSetInteger(0,n,OBJPROP_COLOR,clrMagenta);
               ObjectSetInteger(0,n,OBJPROP_WIDTH,2);
               drawnU++;
            }
            if(drawnD<maxSeg && dn[i]!=EMPTY_VALUE)
            {
               int j2=MathMax(0, i-segLen);
               string n2=StringFormat("TB_SR_D_%d",(int)t[i]);
               ObjectCreate(0,n2,OBJ_TREND,0,t[i],dn[i],t[j2],dn[i]);
               ObjectSetInteger(0,n2,OBJPROP_COLOR,clrDodgerBlue);
               ObjectSetInteger(0,n2,OBJPROP_WIDTH,2);
               drawnD++;
            }
         }
      }
   }

   // Draw Daily Pivots
   if(InpDrawDailyPivots)
   {
      ClearObjectsByPrefix("TB_PVT_");
      MqlDateTime dt; TimeToStruct(TimeCurrent(), dt);
      datetime dayStart = (datetime)StructToTime(dt) - (dt.hour*3600 + dt.min*60 + dt.sec);
      // Get yesterday H/L/C on current symbol from D1 timeframe
      double yHigh=iHigh(_Symbol, PERIOD_D1, 1);
      double yLow =iLow(_Symbol,  PERIOD_D1, 1);
      double yClose=iClose(_Symbol,PERIOD_D1, 1);
      if(yHigh>0 && yLow>0 && yClose>0)
      {
         double P = (yHigh + yLow + yClose)/3.0;
         double R1 = 2*P - yLow; double S1 = 2*P - yHigh;
         double R2 = P + (yHigh - yLow); double S2 = P - (yHigh - yLow);
         double R3 = yHigh + 2*(P - yLow); double S3 = yLow - 2*(yHigh - P);
         datetime t0[]; ArraySetAsSeries(t0,true); CopyTime(_Symbol,_Period,0,2,t0);
         datetime x1 = (ArraySize(t0)>0 ? t0[0] : TimeCurrent());
         datetime x0 = (ArraySize(t0)>1 ? t0[1] : x1 - 24*3600);
         string names[7] = {"TB_PVT_P","TB_PVT_R1","TB_PVT_S1","TB_PVT_R2","TB_PVT_S2","TB_PVT_R3","TB_PVT_S3"};
         double vals[7]  = {P,R1,S1,R2,S2,R3,S3};
         color cols[7]   = {clrGainsboro,clrTomato,clrDeepSkyBlue,clrTomato,clrDeepSkyBlue,clrTomato,clrDeepSkyBlue};
         for(int k=0;k<7;k++)
         {
            ObjectCreate(0,names[k],OBJ_TREND,0,x0,vals[k],x1,vals[k]);
            ObjectSetInteger(0,names[k],OBJPROP_COLOR,cols[k]);
            ObjectSetInteger(0,names[k],OBJPROP_WIDTH,1);
         }
      }
   }

   // ===============================
   // OTE Strategy: zones & guidance
   // ===============================
   if(InpEnableOTE)
   {
      ClearObjectsByPrefix("TB_OTE_");
      int bars = MathMin(400, rates_total-1);
      if(bars>50)
      {
         // Retrieve series
         datetime t[]; ArraySetAsSeries(t,true); CopyTime(_Symbol,_Period,0,rates_total,t);
         double highs2[]; ArraySetAsSeries(highs2,true); CopyHigh(_Symbol,_Period,0,rates_total,highs2);
         double lows2[];  ArraySetAsSeries(lows2,true);  CopyLow(_Symbol,_Period,0,rates_total,lows2);
         double closes2[];ArraySetAsSeries(closes2,true);CopyClose(_Symbol,_Period,0,rates_total,closes2);

         // Detect last impulse via simple pivots
         int w = MathMax(3, MathMin(11, InpOTEPivotWindow));
         int lastHighIdx=-1, lastLowIdx=-1;
         for(int i=bars-1; i>=w && (lastHighIdx<0 || lastLowIdx<0); i--)
         {
            bool isHigh=true, isLow=true;
            for(int k=1;k<=w && (isHigh||isLow);k++)
            {
               if(isHigh && highs2[i]<=highs2[i-k]) isHigh=false;
               if(isHigh && highs2[i]<=highs2[i+k]) isHigh=false;
               if(isLow  && lows2[i]>=lows2[i-k])  isLow=false;
               if(isLow  && lows2[i]>=lows2[i+k])  isLow=false;
            }
            if(isHigh && lastHighIdx<0) lastHighIdx=i;
            if(isLow  && lastLowIdx<0)  lastLowIdx=i;
         }

         if(lastHighIdx>=0 && lastLowIdx>=0)
         {
            double swingHigh = highs2[lastHighIdx];
            double swingLow  = lows2[lastLowIdx];
            if(swingHigh>0 && swingLow>0 && swingHigh>swingLow)
            {
               bool impulseUp = (lastHighIdx>lastLowIdx);
               double range = swingHigh - swingLow;
               if(range>0.0)
               {
                  // Fib levels (0, 0.5, 0.78, 1) based on low->high orientation
                  double fib0   = swingLow;
                  double fib05  = swingLow + 0.5  * range;
                  double fib078 = swingLow + 0.78 * range;
                  double fib1   = swingHigh;

                  // Draw buy zone (0-0.5) in green
                  string brect = "TB_OTE_BUY";
                  ObjectCreate(0,brect,OBJ_RECTANGLE,0,t[bars-1],fib0,t[0],fib05);
                  ObjectSetInteger(0,brect,OBJPROP_COLOR, clrLime);
                  ObjectSetInteger(0,brect,OBJPROP_WIDTH, 1);
                  ObjectSetInteger(0,brect,OBJPROP_BACK,  true);
                  ObjectSetInteger(0,brect,OBJPROP_STYLE,  STYLE_SOLID);
                  // Note: Some properties like fill/alpha may not be supported on OBJ_RECTANGLE in all builds.

                  // Draw OTE sell zone (0.78-1) in red
                  string srect = "TB_OTE_SELL";
                  ObjectCreate(0,srect,OBJ_RECTANGLE,0,t[bars-1],fib078,t[0],fib1);
                  ObjectSetInteger(0,srect,OBJPROP_COLOR, clrTomato);
                  ObjectSetInteger(0,srect,OBJPROP_WIDTH, 1);
                  ObjectSetInteger(0,srect,OBJPROP_BACK,  true);
                  ObjectSetInteger(0,srect,OBJPROP_STYLE,  STYLE_SOLID);
                  // Note: Some properties like fill/alpha may not be supported on OBJ_RECTANGLE in all builds.

                  // Evaluate bias for current price
                  double px = closes2[0];
                  double pos = (px - fib0) / (range==0.0?1.0:range);
                  string biasMsg = "OTE: ";
                  color  biasCol = clrGainsboro;
                  if(impulseUp)
                  {
                     if(pos>=0.0 && pos<=0.5){ biasMsg+="Zone d’achat (0-0.5)"; biasCol=clrLime; }
                     else if(pos>0.5 && pos<0.78){ biasMsg+="Zone risquée (0.5-0.78)"; biasCol=clrGold; }
                     else if(pos>=0.78 && pos<=1.0){ biasMsg+="Zone OTE vente (0.78-1)"; biasCol=clrTomato; }
                     else { biasMsg+="Hors plage"; }
                  }
                  else // impulse down -> mirror
                  {
                     double posDown = (fib1 - px) / (range==0.0?1.0:range);
                     if(posDown>=0.0 && posDown<=0.5){ biasMsg+="Zone de vente (0-0.5)"; biasCol=clrTomato; }
                     else if(posDown>0.5 && posDown<0.78){ biasMsg+="Zone risquée (0.5-0.78)"; biasCol=clrGold; }
                     else if(posDown>=0.78 && posDown<=1.0){ biasMsg+="Zone OTE achat (0.78-1)"; biasCol=clrLime; }
                     else { biasMsg+="Hors plage"; }
                  }

                  // Label
                  string lab = "TB_OTE_LABEL";
                  ObjectCreate(0,lab,OBJ_LABEL,0,0,0);
                  ObjectSetInteger(0,lab,OBJPROP_XDISTANCE, 10);
                  ObjectSetInteger(0,lab,OBJPROP_YDISTANCE, 20);
                  ObjectSetInteger(0,lab,OBJPROP_CORNER, CORNER_LEFT_UPPER);
                  ObjectSetInteger(0,lab,OBJPROP_COLOR, biasCol);
                  ObjectSetString(0,lab,OBJPROP_TEXT, biasMsg);
               }
            }
         }
      }
   }

   // Note: InpMinLot provided to enforce minimum lot size when an EA reads this indicator or shares settings.
   // Ensure any EA using this strategy clamps lot size: lot = MathMax(InpMinLot, lot);

   return(rates_total);
}


