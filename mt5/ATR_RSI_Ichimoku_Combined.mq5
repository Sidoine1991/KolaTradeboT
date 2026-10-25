//+------------------------------------------------------------------+
//|                                     ATR_RSI_Ichimoku_Combined.mq5 |
//|                        Indicateur combiné pour Boom/Crash          |
//|                          ATR + RSI + Ichimoku dans une fenêtre      |
//+------------------------------------------------------------------+
#property copyright "F_INX_Indicators"
#property version   "1.00"
#property strict

#property indicator_separate_window
#property indicator_buffers 8
#property indicator_plots   8

//--- RSI
#property indicator_label1  "RSI"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- ATR
#property indicator_label2  "ATR"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Ichimoku Tenkan-sen
#property indicator_label3  "Tenkan-sen"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrBlue
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Ichimoku Kijun-sen
#property indicator_label4  "Kijun-sen"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrRed
#property indicator_style4  STYLE_SOLID
#property indicator_width4  1

//--- Ichimoku Senkou Span A
#property indicator_label5  "Senkou A"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrGreen
#property indicator_style5  STYLE_SOLID
#property indicator_width5  1

//--- Ichimoku Senkou Span B
#property indicator_label6  "Senkou B"
#property indicator_type6   DRAW_LINE
#property indicator_color6  clrOrange
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1

//--- Ichimoku Chikou Span
#property indicator_label7  "Chikou"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrPurple
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1

//--- Signal Line
#property indicator_label8  "Signal"
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrYellow
#property indicator_style8  STYLE_SOLID
#property indicator_width8  3

//--- Input Parameters
input group "RSI Settings"
input int    RSI_Period      = 14;
input int    RSI_Price       = PRICE_CLOSE;
input double RSI_Overbought  = 70.0;
input double RSI_Oversold    = 30.0;

input group "ATR Settings"
input int    ATR_Period      = 14;

input group "Ichimoku Settings"
input int    Tenkan          = 9;
input int    Kijun           = 26;
input int    SenkouB         = 52;

input group "Display Settings"
input bool   ShowRSI         = true;
input bool   ShowATR         = true;
input bool   ShowIchimoku    = true;
input bool   ShowSignals     = true;
input double SignalMultiplier = 2.0; // Multiplier for ATR to show as RSI scale

input group "Boom/Crash Settings"
input bool   EnableAlerts    = true;
input bool   EnableSoundAlerts = true;
input string SoundFile       = "alert.wav";
input bool   EnablePushNotifications = true;
input int    AlertCooldownSeconds = 30; // Minimum seconds between alerts
input bool   ShowBoomCrashZones = true; // Show special zones for Boom/Crash

//--- Indicator Buffers
double RSIBuffer[];
double ATRBuffer[];
double TenkanBuffer[];
double KijunBuffer[];
double SenkouABuffer[];
double SenkouBBuffer[];
double ChikouBuffer[];
double SignalBuffer[];

//--- Global Variables
int rsi_handle;
int atr_handle;
datetime last_alert_time = 0;
string current_symbol = "";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Set buffers
   SetIndexBuffer(0, RSIBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ATRBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, TenkanBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, KijunBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, SenkouABuffer, INDICATOR_DATA);
   SetIndexBuffer(5, SenkouBBuffer, INDICATOR_DATA);
   SetIndexBuffer(6, ChikouBuffer, INDICATOR_DATA);
   SetIndexBuffer(7, SignalBuffer, INDICATOR_DATA);
   
   //--- Set empty values
   SetIndexEmptyValue(0, 0.0);
   SetIndexEmptyValue(1, 0.0);
   SetIndexEmptyValue(2, 0.0);
   SetIndexEmptyValue(3, 0.0);
   SetIndexEmptyValue(4, 0.0);
   SetIndexEmptyValue(5, 0.0);
   SetIndexEmptyValue(6, 0.0);
   SetIndexEmptyValue(7, 0.0);
   
   //--- Set arrow code for signals
   PlotIndexSetInteger(7, PLOT_ARROW, 159);
   
   //--- Create RSI handle
   rsi_handle = iRSI(_Symbol, _Period, RSI_Period, RSI_Price);
   if(rsi_handle == INVALID_HANDLE)
   {
      Print("Error creating RSI indicator handle");
      return(INIT_FAILED);
   }
   
   //--- Create ATR handle
   atr_handle = iATR(_Symbol, _Period, ATR_Period);
   if(atr_handle == INVALID_HANDLE)
   {
      Print("Error creating ATR indicator handle");
      return(INIT_FAILED);
   }
   
   //--- Set indicator labels
   string shortname = "ATR_RSI_Ichimoku(" + IntegerToString(RSI_Period) + "," + IntegerToString(ATR_Period) + ")";
   IndicatorSetString(INDICATOR_SHORTNAME, shortname);
   
   //--- Set levels for RSI
   IndicatorSetInteger(INDICATOR_LEVELS, 2);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 0, RSI_Oversold);
   IndicatorSetDouble(INDICATOR_LEVELVALUE, 1, RSI_Overbought);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 0, clrLightGray);
   IndicatorSetInteger(INDICATOR_LEVELCOLOR, 1, clrLightGray);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 0, STYLE_DOT);
   IndicatorSetInteger(INDICATOR_LEVELSTYLE, 1, STYLE_DOT);
   
   //--- Set scale
   IndicatorSetInteger(INDICATOR_MINIMUM, 0);
   IndicatorSetInteger(INDICATOR_MAXIMUM, 100);
   
   //--- Initialize symbol
   current_symbol = _Symbol;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release handles
   if(rsi_handle != INVALID_HANDLE)
      IndicatorRelease(rsi_handle);
   if(atr_handle != INVALID_HANDLE)
      IndicatorRelease(atr_handle);
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
                const long &real_volume[],
                const int &spread[])
{
   //--- Check for minimum bars
   if(rates_total < MathMax(RSI_Period, MathMax(ATR_Period, MathMax(Tenkan, MathMax(Kijun, SenkouB)))))
      return(0);
   
   //--- Calculate start position
   int start = prev_calculated;
   if(start == 0) start = MathMax(RSI_Period, MathMax(ATR_Period, MathMax(Tenkan, MathMax(Kijun, SenkouB)))) - 1;
   
   //--- Copy RSI data
   double rsi_temp[];
   if(CopyBuffer(rsi_handle, 0, 0, rates_total, rsi_temp) <= 0)
      return(0);
   
   //--- Copy ATR data
   double atr_temp[];
   if(CopyBuffer(atr_handle, 0, 0, rates_total, atr_temp) <= 0)
      return(0);
   
   //--- Main calculation loop
   for(int i = start; i < rates_total && !IsStopped(); i++)
   {
      //--- RSI
      if(ShowRSI)
         RSIBuffer[i] = rsi_temp[i];
      else
         RSIBuffer[i] = 0;
      
      //--- ATR (scaled to RSI range 0-100)
      if(ShowATR && atr_temp[i] > 0)
      {
         // Scale ATR to RSI range using multiplier
         double atr_scaled = atr_temp[i] * SignalMultiplier * 1000; // Adjust multiplier as needed
         ATRBuffer[i] = MathMin(100, MathMax(0, atr_scaled));
      }
      else
         ATRBuffer[i] = 0;
      
      //--- Ichimoku calculations
      if(ShowIchimoku && i >= MathMax(Tenkan, MathMax(Kijun, SenkouB)))
      {
         // Tenkan-sen (Conversion Line)
         double high_tenkan = high[ArrayMaximum(high, Tenkan, i - Tenkan + 1)];
         double low_tenkan = low[ArrayMinimum(low, Tenkan, i - Tenkan + 1)];
         TenkanBuffer[i] = (high_tenkan + low_tenkan) / 2.0;
         
         // Kijun-sen (Base Line)
         double high_kijun = high[ArrayMaximum(high, Kijun, i - Kijun + 1)];
         double low_kijun = low[ArrayMinimum(low, Kijun, i - Kijun + 1)];
         KijunBuffer[i] = (high_kijun + low_kijun) / 2.0;
         
         // Senkou Span A (Leading Span A)
         SenkouABuffer[i] = (TenkanBuffer[i] + KijunBuffer[i]) / 2.0;
         
         // Senkou Span B (Leading Span B)
         double high_senkou = high[ArrayMaximum(high, SenkouB, i - SenkouB + 1)];
         double low_senkou = low[ArrayMinimum(low, SenkouB, i - SenkouB + 1)];
         SenkouBBuffer[i] = (high_senkou + low_senkou) / 2.0;
         
         // Chikou Span (Lagging Span)
         if(i >= Kijun)
            ChikouBuffer[i] = close[i - Kijun];
      }
      
      //--- Generate signals
      if(ShowSignals && i > 0)
      {
         SignalBuffer[i] = 0;
         string signal_type = "";
         bool signal_generated = false;
         
         // Buy signals
         if(RSIBuffer[i] < RSI_Oversold && RSIBuffer[i-1] >= RSI_Oversold)
         {
            // RSI oversold crossover
            SignalBuffer[i] = RSIBuffer[i];
            signal_type = "BUY RSI Oversold";
            signal_generated = true;
         }
         else if(TenkanBuffer[i] > KijunBuffer[i] && TenkanBuffer[i-1] <= KijunBuffer[i-1])
         {
            // Ichimoku bullish crossover
            SignalBuffer[i] = RSIBuffer[i];
            signal_type = "BUY Ichimoku Bullish";
            signal_generated = true;
         }
         else if(RSIBuffer[i] > 50 && TenkanBuffer[i] > KijunBuffer[i] && RSIBuffer[i-1] <= 50)
         {
            // Combined bullish signal
            SignalBuffer[i] = RSIBuffer[i];
            signal_type = "BUY Combined Bullish";
            signal_generated = true;
         }
         
         // Sell signals
         if(RSIBuffer[i] > RSI_Overbought && RSIBuffer[i-1] <= RSI_Overbought)
         {
            // RSI overbought crossover
            SignalBuffer[i] = RSIBuffer[i];
            signal_type = "SELL RSI Overbought";
            signal_generated = true;
         }
         else if(TenkanBuffer[i] < KijunBuffer[i] && TenkanBuffer[i-1] >= KijunBuffer[i-1])
         {
            // Ichimoku bearish crossover
            SignalBuffer[i] = RSIBuffer[i];
            signal_type = "SELL Ichimoku Bearish";
            signal_generated = true;
         }
         else if(RSIBuffer[i] < 50 && TenkanBuffer[i] < KijunBuffer[i] && RSIBuffer[i-1] >= 50)
         {
            // Combined bearish signal
            SignalBuffer[i] = RSIBuffer[i];
            signal_type = "SELL Combined Bearish";
            signal_generated = true;
         }
         
         // Generate alerts
         if(signal_generated && EnableAlerts)
         {
            GenerateAlert(signal_type, time[i], RSIBuffer[i]);
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Alert generation function                                       |
//+------------------------------------------------------------------+
void GenerateAlert(string signal_type, datetime signal_time, double rsi_value)
{
   // Check cooldown
   if(TimeCurrent() - last_alert_time < AlertCooldownSeconds)
      return;
   
   // Update last alert time
   last_alert_time = TimeCurrent();
   
   // Format message
   string message = StringFormat("%s - %s @ %s | RSI: %.2f",
                               current_symbol,
                               signal_type,
                               TimeToString(signal_time, TIME_MINUTES),
                               rsi_value);
   
   // Sound alert
   if(EnableSoundAlerts)
   {
      PlaySound(SoundFile);
   }
   
   // Push notification
   if(EnablePushNotifications)
   {
      SendNotification(message);
   }
   
   // Print to Experts log
   Print("ALERT: ", message);
   
   // Check if it's Boom or Crash specific
   if(StringFind(current_symbol, "Boom") != -1)
   {
      if(StringFind(signal_type, "BUY") != -1)
      {
         Print("BOOM SIGNAL: Potential BUY entry detected - RSI oversold or bullish crossover");
      }
   }
   else if(StringFind(current_symbol, "Crash") != -1)
   {
      if(StringFind(signal_type, "SELL") != -1)
      {
         Print("CRASH SIGNAL: Potential SELL entry detected - RSI overbought or bearish crossover");
      }
   }
}

//+------------------------------------------------------------------+
//| Helper function to scale price to RSI range                    |
//+------------------------------------------------------------------+
double ScalePriceToRSI(double price, double min_price, double max_price)
{
   if(max_price == min_price) return 50.0;
   return ((price - min_price) / (max_price - min_price)) * 100.0;
}

//+------------------------------------------------------------------+
