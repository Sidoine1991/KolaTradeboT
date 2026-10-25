//+------------------------------------------------------------------+
//|                                                      VPIN_Proxy.mq5 |
//|                                      Copyright 2023, Stable Version |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- indicator buffers
double VPINBuffer[];

//--- input parameters
input int WindowBars = 300;
input int Smoothing  = 3;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, VPINBuffer, INDICATOR_DATA);
   IndicatorSetString(INDICATOR_SHORTNAME, "VPIN(" + string(WindowBars) + ")");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int start = MathMax(prev_calculated - 1, 1);

   for(int i = start; i < rates_total; i++)
   {
      int win = MathMin(WindowBars, i);
      if(win < 10) { VPINBuffer[i] = 0; continue; }

      double buy=0, sell=0, total=0;

      for(int j = i-win; j < i; j++)
      {
         if(j < 0) continue;

         double tv = tick_volume[j];
         total += tv;

         if(close[j] > open[j]) buy += tv;
         else if(close[j] < open[j]) sell += tv;
      }

      double vpin = (total>0) ? MathAbs(buy-sell)/total : 0;

      // Smoothing
      double sum = 0; int kmax = 0;
      for(int k=0; k<Smoothing && (i-k)>=0; k++)
      {
         sum += (k==0? vpin : VPINBuffer[i-k]);
         kmax++;
      }
      VPINBuffer[i] = sum / kmax;
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
