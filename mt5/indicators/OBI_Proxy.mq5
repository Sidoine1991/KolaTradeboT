//+------------------------------------------------------------------+
//|                                                      OBI_Proxy.mq5 |
//|                                      Copyright 2023, Stable Version |
//|                                             https://www.yoursite.com |
//+------------------------------------------------------------------+
#property indicator_separate_window
#property indicator_buffers 1
#property indicator_plots   1
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- indicator buffers
double OBIBuffer[];

//--- input parameters
input int LookbackBars = 100;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, OBIBuffer, INDICATOR_DATA);
   IndicatorSetString(INDICATOR_SHORTNAME, "OBI(" + string(LookbackBars) + ")");
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
      int win = MathMin(LookbackBars, i);
      if(win < 10) { OBIBuffer[i] = 0; continue; }

      double buy=0, sell=0;

      for(int j = i-win; j < i; j++)
      {
         if(close[j] > open[j]) buy  += tick_volume[j];
         else if(close[j] < open[j]) sell += tick_volume[j];
      }

      double total = buy + sell;

      OBIBuffer[i] = (total>0 ? (buy-sell)/total : 0);
   }

   return(rates_total);
}
//+------------------------------------------------------------------+
