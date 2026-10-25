//+------------------------------------------------------------------+
//|                                     Apply_SpikeHunter_Template.mq5|
//| Script: configure chart, attach indicators, save .tpl             |
//+------------------------------------------------------------------+
#property script_show_inputs

// Template options
input string   InpTemplateName     = "SpikeHunter_Default.tpl";
input ENUM_TIMEFRAMES InpTF        = PERIOD_M1;

// Indicator params (mirror SpikeHunter_Squeeze_Indicator)
input int      InpBBPeriod         = 20;
input double   InpBBDeviation      = 2.0;
input int      InpBodyZWindow      = 120;
input int      InpEMAFast          = 9;
input int      InpEMASlow          = 21;
input int      InpATRShort         = 14;
input int      InpATRLong          = 50;
input bool     InpShowArrows       = true;

// Visuals
input bool     InpAttachMABands    = true;   // add EMA(9/21) + BB(20,2) on main window
input color    InpBgColor          = clrBlack;
input color    InpForeColor        = clrSilver;
input color    InpBullCandle       = clrLime;
input color    InpBearCandle       = clrTomato;
input bool     InpHideGrid         = true;

//+------------------------------------------------------------------+
void ConfigureChart(const long chart)
{
  ChartSetInteger(chart, CHART_AUTOSCROLL, true);
  ChartSetInteger(chart, CHART_SHIFT, true);
  ChartSetInteger(chart, CHART_MODE, CHART_CANDLES);
  ChartSetInteger(chart, CHART_FOREGROUND, false);
  ChartSetInteger(chart, CHART_COLOR_BACKGROUND, InpBgColor);
  ChartSetInteger(chart, CHART_COLOR_FOREGROUND, InpForeColor);
  ChartSetInteger(chart, CHART_COLOR_CHART_UP, InpBullCandle);
  ChartSetInteger(chart, CHART_COLOR_CHART_DOWN, InpBearCandle);
  ChartSetInteger(chart, CHART_COLOR_CANDLE_BULL, InpBullCandle);
  ChartSetInteger(chart, CHART_COLOR_CANDLE_BEAR, InpBearCandle);
  ChartSetInteger(chart, CHART_COLOR_GRID, clrDimGray);
  ChartSetInteger(chart, CHART_COLOR_VOLUME, clrDodgerBlue);
  ChartSetInteger(chart, CHART_SHOW_GRID, !InpHideGrid);
  ChartSetInteger(chart, CHART_SHOW_VOLUMES, false);
  ChartSetInteger(chart, CHART_SCALEFIX, false);
}

bool EnsureTimeframe(const long chart, ENUM_TIMEFRAMES tf)
{
  if(ChartSetSymbolPeriod(chart, _Symbol, tf)) return(true);
  Print("[ApplyTemplate] Failed to set timeframe");
  return(false);
}

// Attach standard overlays on main window
void AttachOverlayIndicators(const long chart)
{
  if(!InpAttachMABands) return;
  int hEmaFast = iMA(_Symbol, PERIOD_CURRENT, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
  int hEmaSlow = iMA(_Symbol, PERIOD_CURRENT, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
  int hBands   = iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
  if(hEmaFast!=INVALID_HANDLE) ChartIndicatorAdd(chart, 0, hEmaFast);
  if(hEmaSlow!=INVALID_HANDLE) ChartIndicatorAdd(chart, 0, hEmaSlow);
  if(hBands  !=INVALID_HANDLE) ChartIndicatorAdd(chart, 0, hBands);
}

// Attach custom squeeze indicator in a separate subwindow
void AttachSqueezeIndicator(const long chart)
{
  int handle = iCustom(_Symbol, PERIOD_CURRENT, "SpikeHunter_Squeeze_Indicator",
                       InpBBPeriod, InpBBDeviation, InpBodyZWindow,
                       InpEMAFast, InpEMASlow, InpATRShort, InpATRLong, InpShowArrows);
  if(handle==INVALID_HANDLE)
  {
    Print("[ApplyTemplate] Failed to create iCustom handle for SpikeHunter_Squeeze_Indicator");
    return;
  }
  // subwindow index 1 (a new one will be created if needed)
  if(!ChartIndicatorAdd(chart, 1, handle))
    Print("[ApplyTemplate] ChartIndicatorAdd failed for squeeze indicator");
}

// Try to save template to terminal templates directory
void TrySaveTemplate(const long chart)
{
#ifdef __MQL5__
  if(!ChartSaveTemplate(chart, InpTemplateName))
    Print("[ApplyTemplate] ChartSaveTemplate failed. You can still save manually: Charts → Template → Save Template...");
#endif
}

//+------------------------------------------------------------------+
void OnStart()
{
  long chart = ChartID();
  if(!EnsureTimeframe(chart, InpTF)) return;
  ConfigureChart(chart);
  AttachOverlayIndicators(chart);
  AttachSqueezeIndicator(chart);
  TrySaveTemplate(chart);
  Print("[ApplyTemplate] SpikeHunter template applied and saved as ", InpTemplateName);
}

//+------------------------------------------------------------------+

