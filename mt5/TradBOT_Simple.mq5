#property copyright "TradBOT"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 6

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

// Inputs
input int    InpEMA200Period   = 200;
input int    InpBBPeriod       = 20;
input double InpBBDev          = 2.0;
input int    InpVWAPWindow     = 50;
input double InpSARStep        = 0.02;
input double InpSARMax         = 0.2;
input bool   InpDrawFractalSR  = true;
input bool   InpDrawDailyPivots= true;

// Buffers
double bufEMA200[];
double bufBBU[];
double bufBBM[];
double bufBBL[];
double bufVWAP[];
double bufSAR[];

// Handles
int hEMA = INVALID_HANDLE;
int hBB  = INVALID_HANDLE;
int hSAR = INVALID_HANDLE;

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

   PlotIndexSetInteger(5, PLOT_ARROW, 159); // small dot for SAR

   // Create handles
   hEMA = iMA(_Symbol, _Period, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
   hBB  = iBands(_Symbol, _Period, InpBBPeriod, InpBBDev, 0, PRICE_CLOSE);
   hSAR = iSAR(_Symbol, _Period, InpSARStep, InpSARMax);

   if(hEMA==INVALID_HANDLE || hBB==INVALID_HANDLE || hSAR==INVALID_HANDLE)
      return INIT_FAILED;

   return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   if(rates_total < 100) return(0);
   
   int start = MathMax(0, prev_calculated - 1);
   if(start < 0) start = 0;

   // EMA200
   if(CopyBuffer(hEMA, 0, start, rates_total - start, bufEMA200, start) <= 0)
      return(0);

   // BB: upper(0), middle(1), lower(2)
   if(CopyBuffer(hBB, 0, start, rates_total - start, bufBBU, start) <= 0) return(0);
   if(CopyBuffer(hBB, 1, start, rates_total - start, bufBBM, start) <= 0) return(0);
   if(CopyBuffer(hBB, 2, start, rates_total - start, bufBBL, start) <= 0) return(0);

   // SAR
   if(CopyBuffer(hSAR, 0, start, rates_total - start, bufSAR, start) <= 0) return(0);

   // VWAP approximation: sum(price*volume)/sum(volume) over window
   int win = MathMax(10, InpVWAPWindow);
   for(int i = start; i < rates_total; i++)
   {
      double closes[]; ArraySetAsSeries(closes,true);
      long   vols[];   ArraySetAsSeries(vols,true);
      
      int copy_count = MathMin(win, i + 1);
      if(CopyClose(_Symbol,_Period,i-copy_count+1,copy_count,closes) <= 0) continue;
      if(CopyTickVolume(_Symbol,_Period,i-copy_count+1,copy_count,vols) <= 0) continue;
      
      double num=0.0, den=0.0;
      for(int j=0; j<copy_count; j++)
      {
         num += closes[j] * (double)vols[j];
         den += (double)vols[j];
      }
      bufVWAP[i] = (den>0.0 ? num/den : EMPTY_VALUE);
   }

   // Draw Fractal S/R as objects (only on last calculation)
   if(InpDrawFractalSR && prev_calculated == 0)
   {
      int bars = MathMin(100, rates_total-1);
      ClearObjectsByPrefix("TB_SR_");
      double up[]; ArraySetAsSeries(up,true);
      double dn[]; ArraySetAsSeries(dn,true);
      int hFrac = iFractals(_Symbol,_Period);
      if(hFrac!=INVALID_HANDLE)
      {
         if(CopyBuffer(hFrac,0,0,bars,up) > 0 && CopyBuffer(hFrac,1,0,bars,dn) > 0)
         {
            int drawnU=0, drawnD=0, maxSeg=5, segLen=20;
            datetime t[]; ArraySetAsSeries(t,true); 
            if(CopyTime(_Symbol,_Period,0,bars,t) > 0)
            {
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
         IndicatorRelease(hFrac);
      }
   }

   // Draw Daily Pivots (only on last calculation)
   if(InpDrawDailyPivots && prev_calculated == 0)
   {
      ClearObjectsByPrefix("TB_PVT_");
      double yHigh=iHigh(_Symbol, PERIOD_D1, 1);
      double yLow =iLow(_Symbol,  PERIOD_D1, 1);
      double yClose=iClose(_Symbol,PERIOD_D1, 1);
      if(yHigh>0 && yLow>0 && yClose>0)
      {
         double P = (yHigh + yLow + yClose)/3.0;
         double R1 = 2*P - yLow; double S1 = 2*P - yHigh;
         double R2 = P + (yHigh - yLow); double S2 = P - (yHigh - yLow);
         double R3 = yHigh + 2*(P - yLow); double S3 = yLow - 2*(yHigh - P);
         
         datetime t0[]; ArraySetAsSeries(t0,true); 
         if(CopyTime(_Symbol,_Period,0,2,t0) > 0)
         {
            datetime x1 = t0[0];
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
   }

   return(rates_total);
}

void OnDeinit(const int reason)
{
   if(hEMA!=INVALID_HANDLE) IndicatorRelease(hEMA);
   if(hBB!=INVALID_HANDLE)  IndicatorRelease(hBB);
   if(hSAR!=INVALID_HANDLE) IndicatorRelease(hSAR);
}
