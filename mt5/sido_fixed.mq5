#property copyright "TradBOT"
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_plots 4

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

// Inputs
input int    InpEMA200Period   = 200;
input int    InpBBPeriod       = 20;
input double InpBBDev          = 2.0;

// Buffers
double bufEMA200[];
double bufBBU[];
double bufBBM[];
double bufBBL[];

// Handles
int hEMA = INVALID_HANDLE;
int hBB  = INVALID_HANDLE;

int OnInit()
{
   IndicatorSetInteger(INDICATOR_DIGITS, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   SetIndexBuffer(0, bufEMA200, INDICATOR_DATA);
   SetIndexBuffer(1, bufBBU,    INDICATOR_DATA);
   SetIndexBuffer(2, bufBBM,    INDICATOR_DATA);
   SetIndexBuffer(3, bufBBL,    INDICATOR_DATA);

   hEMA = iMA(_Symbol, _Period, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
   hBB  = iBands(_Symbol, _Period, InpBBPeriod, InpBBDev, 0, PRICE_CLOSE);
   if(hEMA==INVALID_HANDLE || hBB==INVALID_HANDLE) return INIT_FAILED;
   return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const int begin,
                const double &price[])
{
   if(rates_total <= 0) return(0);

   // Always copy into buffers with the correct signature: (handle, buffer, start, count, targetArray)
   if(CopyBuffer(hEMA, 0, 0, rates_total, bufEMA200) <= 0) return(0);
   CopyBuffer(hBB, 0, 0, rates_total, bufBBU);   // upper
   CopyBuffer(hBB, 1, 0, rates_total, bufBBM);   // middle
   CopyBuffer(hBB, 2, 0, rates_total, bufBBL);   // lower

   return(rates_total);
}

void OnDeinit(const int reason)
{
   if(hEMA!=INVALID_HANDLE) IndicatorRelease(hEMA);
   if(hBB!=INVALID_HANDLE)  IndicatorRelease(hBB);
}
