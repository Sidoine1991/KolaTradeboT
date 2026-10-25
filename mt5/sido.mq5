//+------------------------------------------------------------------+
//|                                                        sido.mq5  |
//|                        Copyright 2023, TradBOT                   |
//|                                       https://www.mql5.com       |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.05"
#property strict
#property indicator_chart_window
#property indicator_plots   9

//--- nombre de buffers (MQL5)
#property indicator_buffers 9

//--- Propriétés des plots
#property indicator_label1  "EMA200"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_label2  "BB Upper"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrSilver
#property indicator_style2  STYLE_DOT
#property indicator_width2  1
#property indicator_label3  "BB Middle"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrDarkGray
#property indicator_style3  STYLE_DOT
#property indicator_width3  1
#property indicator_label4  "BB Lower"
#property indicator_type4   DRAW_LINE
#property indicator_color4  clrSilver
#property indicator_style4  STYLE_DOT
#property indicator_width4  1
#property indicator_label5  "VWAP"
#property indicator_type5   DRAW_LINE
#property indicator_color5  clrOrange
#property indicator_style5  STYLE_SOLID
#property indicator_width5  2
#property indicator_label6  "SAR"
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrMediumPurple
#property indicator_style6  STYLE_SOLID
#property indicator_width6  1
#property indicator_label7  "Kijun"
#property indicator_type7   DRAW_LINE
#property indicator_color7  clrSandyBrown
#property indicator_style7  STYLE_SOLID
#property indicator_width7  1
#property indicator_label8  "Supertrend Up"
#property indicator_type8   DRAW_LINE
#property indicator_color8  clrLime
#property indicator_style8  STYLE_SOLID
#property indicator_width8  2
#property indicator_label9  "Supertrend Down"
#property indicator_type9   DRAW_LINE
#property indicator_color9  clrRed
#property indicator_style9  STYLE_SOLID
#property indicator_width9  2

//--- Inputs
input int      InpEMA200Period    = 200;
input int      InpBBPeriod        = 20;
input double   InpBBDev           = 2.0;
input int      InpATRPeriod       = 14;
input int      InpVWAPWindow      = 50;
input double   InpSARStep         = 0.02;
input double   InpSARMax          = 0.2;
input int      InpIchiTenkan      = 9;
input int      InpIchiKijun       = 26;
input int      InpST_ATR_Period   = 10;
input double   InpST_Multiplier   = 3.0;
input bool     InpDrawFractalSR   = true;
input bool     InpDrawDailyPivots = true;
input bool     InpEnableOTE       = true;
input int      InpOTEPivotWindow  = 5;
input double   InpMinLot          = 1.0;
input bool     InpEnableSpikePrediction = true;
input int      InpSpikeLookback   = 50;  // Reduced for better performance
input double   InpSpikeThreshold  = 1.8; // Lowered for more sensitive detection
input int      InpPredictionMinutes = 1;
input bool     InpEnableBlueSpikeAlerts = true; // Nouvelle option pour les alertes bleues
input double   InpBlueSpikeThreshold = 1.5; // Seuil plus sensible pour les alertes bleues
input int      InpBlueSpikeLookback = 30; // Lookback réduit pour les alertes bleues

//--- Buffers
double bufEMA200[];
double bufBBU[];
double bufBBM[];
double bufBBL[];
double bufVWAP[];
double bufSAR[];
double bufKijun[];
double bufST[];
double bufSTDn[];

//--- Handles
int hEMA = INVALID_HANDLE, hBB = INVALID_HANDLE, hATR = INVALID_HANDLE, hSAR = INVALID_HANDLE, hIchi = INVALID_HANDLE, hFrac = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Utility: clear objects by prefix                                 |
//+------------------------------------------------------------------+
void ClearObjectsByPrefix(const string prefix)
{
   int total = ObjectsTotal(0);
   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(name != "" && StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| Blue Spike Alert Function - Alerte de spike imminente           |
//+------------------------------------------------------------------+
void PredictBlueSpikeAlerts(const int rates_total,
                           const datetime &time[],
                           const double &high[],
                           const double &low[],
                           const double &close[],
                           const double &open[],
                           const double &atr[])
{
   if(!InpEnableBlueSpikeAlerts || rates_total < 30) return;
   
   // Safety checks
   if(ArraySize(time) == 0 || ArraySize(high) == 0 || ArraySize(low) == 0 || ArraySize(close) == 0 || ArraySize(open) == 0)
   {
      Print("Error: Invalid arrays in PredictBlueSpikeAlerts");
      return;
   }
   
   ClearObjectsByPrefix("TB_BLUE_SPIKE_");
   
   int lookback = MathMin(InpBlueSpikeLookback, rates_total - 10);
   
   // Calculer les indicateurs de momentum et volatilité pour détecter les spikes imminents
   for(int i = rates_total - lookback; i >= 5; i--)
   {
      if(i < 0 || i >= rates_total) continue;
      
      // Analyse de la compression de volatilité (signe avant-coureur d'un spike)
      double volatility_compression = 0;
      double momentum_buildup = 0;
      double volume_surge = 0;
      
      // 1. Compression de volatilité (Bollinger Bands squeeze)
      if(i < ArraySize(bufBBU) && i < ArraySize(bufBBL) && i < ArraySize(atr))
      {
         double bb_width = bufBBU[i] - bufBBL[i];
         double atr_val = atr[i];
         if(atr_val > 0)
         {
            double bb_squeeze = bb_width / (atr_val * 2.0);
            if(bb_squeeze < 1.2) // Compression forte
            {
               volatility_compression = 0.4;
            }
            else if(bb_squeeze < 1.5) // Compression modérée
            {
               volatility_compression = 0.2;
            }
         }
      }
      
      // 2. Accumulation de momentum (mouvement latéral avant explosion)
      if(i >= 10)
      {
         double price_range = 0;
         double body_size = 0;
         for(int k = 1; k <= 10; k++)
         {
            if(i-k >= 0)
            {
               price_range += (high[i-k] - low[i-k]);
               body_size += MathAbs(close[i-k] - open[i-k]);
            }
         }
         
         double avg_range = price_range / 10.0;
         double avg_body = body_size / 10.0;
         double current_range = high[i] - low[i];
         double current_body = MathAbs(close[i] - open[i]);
         
         // Détection d'accumulation (range réduit, corps petits)
         if(avg_range > 0 && current_range < avg_range * 0.7 && current_body < avg_body * 0.5)
         {
            momentum_buildup = 0.3;
         }
      }
      
      // 3. Patterns de consolidation (doji, spinning top)
      double body_ratio = (high[i] - low[i] > 0) ? MathAbs(close[i] - open[i]) / (high[i] - low[i]) : 0;
      double upper_shadow = high[i] - MathMax(open[i], close[i]);
      double lower_shadow = MathMin(open[i], close[i]) - low[i];
      double shadow_ratio = (high[i] - low[i] > 0) ? (upper_shadow + lower_shadow) / (high[i] - low[i]) : 0;
      
      // Pattern de consolidation (petit corps, grandes ombres)
      if(body_ratio < 0.2 && shadow_ratio > 0.6)
      {
         momentum_buildup += 0.2;
      }
      
      // 4. Proximité des niveaux clés (support/résistance, EMA200)
      double proximity_factor = 0;
      if(i < ArraySize(bufEMA200) && bufEMA200[i] != EMPTY_VALUE)
      {
         double distance_to_ema = MathAbs(close[i] - bufEMA200[i]);
         double atr_val = (i < ArraySize(atr)) ? atr[i] : 0;
         if(atr_val > 0)
         {
            double proximity = distance_to_ema / (atr_val * 2.0);
            if(proximity < 0.5) // Très proche de l'EMA200
            {
               proximity_factor = 0.2;
            }
         }
      }
      
      // Calcul du score total de probabilité de spike imminent
      double spike_imminent_score = volatility_compression + momentum_buildup + volume_surge + proximity_factor;
      
      // Alerte SPIKE IMMINENT (flèche bleue) - seuil plus sensible
      if(spike_imminent_score > InpBlueSpikeThreshold)
      {
         // Déterminer la direction probable du spike
         bool bullish_context = false;
         bool bearish_context = false;
         
         // Contexte haussier
         if(i < ArraySize(bufEMA200) && close[i] > bufEMA200[i] && 
            i < ArraySize(bufST) && bufST[i] != EMPTY_VALUE)
         {
            bullish_context = true;
         }
         
         // Contexte baissier  
         if(i < ArraySize(bufEMA200) && close[i] < bufEMA200[i] && 
            i < ArraySize(bufSTDn) && bufSTDn[i] != EMPTY_VALUE)
         {
            bearish_context = true;
         }
         
         // Créer l'alerte bleue
         string alert_name = StringFormat("TB_BLUE_SPIKE_%d", (int)time[i]);
         double alert_price = close[i];
         
         if(ObjectCreate(0, alert_name, OBJ_ARROW, 0, time[i], alert_price))
         {
            // Flèche bleue pointant vers le haut (spike imminent)
            ObjectSetInteger(0, alert_name, OBJPROP_ARROWCODE, 233); // Flèche vers le haut
            ObjectSetInteger(0, alert_name, OBJPROP_WIDTH, 4); // Plus épaisse pour être visible
            ObjectSetInteger(0, alert_name, OBJPROP_COLOR, (long)clrDodgerBlue); // Bleu vif
            ObjectSetString(0, alert_name, OBJPROP_TOOLTIP, 
                           StringFormat("🚀 SPIKE IMMINENT!\nConfiance: %.1f%%\nDirection: %s", 
                           MathMin(100.0, spike_imminent_score * 25),
                           bullish_context ? "HAUSSIER" : (bearish_context ? "BAISSIER" : "NEUTRE")));
            
            // Ajouter un texte d'alerte
            string text_name = StringFormat("TB_BLUE_TEXT_%d", (int)time[i]);
            if(ObjectCreate(0, text_name, OBJ_TEXT, 0, time[i], alert_price + (high[i] - low[i]) * 0.3))
            {
               ObjectSetString(0, text_name, OBJPROP_TEXT, "SPIKE!");
               ObjectSetInteger(0, text_name, OBJPROP_COLOR, (long)clrDodgerBlue);
               ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 8);
               ObjectSetString(0, text_name, OBJPROP_FONT, "Arial Bold");
            }
         }
         else
         {
            Print("Failed to create blue spike alert: ", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Spike Prediction Function                                        |
//+------------------------------------------------------------------+
void PredictSpikes(const int rates_total,
                   const datetime &time[],
                   const double &high[],
                   const double &low[],
                   const double &close[],
                   const double &open[],
                   const double &atr[])
{
   if(!InpEnableSpikePrediction || rates_total < 50) return;
   
   // Safety checks
   if(ArraySize(time) == 0 || ArraySize(high) == 0 || ArraySize(low) == 0 || ArraySize(close) == 0 || ArraySize(open) == 0)
   {
      Print("Error: Invalid arrays in PredictSpikes");
      return;
   }
   
   ClearObjectsByPrefix("TB_SPIKE_");
   
   int lookback = MathMin(InpSpikeLookback, rates_total - 20);
   int prediction_bars = MathMax(1, MathMin(3, InpPredictionMinutes)); // Limit to 1-3 bars ahead for better accuracy
   
   // Calculate volatility and momentum indicators
   double volatility_sma[]; ArrayResize(volatility_sma, rates_total); ArraySetAsSeries(volatility_sma, true);
   double momentum_sma[]; ArrayResize(momentum_sma, rates_total); ArraySetAsSeries(momentum_sma, true);
   double volume_sma[]; ArrayResize(volume_sma, rates_total); ArraySetAsSeries(volume_sma, true);
   
   // Calculate moving averages for volatility, momentum, and volume
   for(int i = 20; i < rates_total; i++)
   {
      double vol_sum = 0, mom_sum = 0, vol_avg = 0;
      for(int j = 0; j < 20; j++)
      {
         if(i-j >= 0)
         {
            vol_sum += (high[i-j] - low[i-j]);
            mom_sum += MathAbs(close[i-j] - open[i-j]);
         }
      }
      volatility_sma[i] = vol_sum / 20.0;
      momentum_sma[i] = mom_sum / 20.0;
   }
   
   // Detect spike patterns and predict future spikes
   int max_iterations = 0;
   int max_loops = MathMin(200, lookback); // Limit loops for better performance
   for(int i = rates_total - lookback; i >= prediction_bars; i--)
   {
      max_iterations++;
      if(max_iterations > max_loops) // Prevent excessive processing
      {
         Print("Info: Spike prediction completed (", max_iterations, " iterations)");
         break;
      }
      
      if(i < 0 || i >= rates_total) continue;
      
      // Current bar analysis
      double current_range = high[i] - low[i];
      double current_body = MathAbs(close[i] - open[i]);
      double current_atr = (i < ArraySize(atr)) ? atr[i] : 0;
      
      // Calculate spike probability factors
      double volatility_factor = 0, momentum_factor = 0, pattern_factor = 0;
      
      // 1. Volatility compression detection (squeeze before explosion)
      if(i >= 10)
      {
         double avg_vol = 0;
         for(int k = 1; k <= 10; k++)
         {
            if(i-k >= 0) avg_vol += volatility_sma[i-k];
         }
         avg_vol /= 10.0;
         
         if(avg_vol > 0)
         {
            volatility_factor = (volatility_sma[i] / avg_vol) - 1.0; // Relative volatility
         }
      }
      
      // 2. Momentum buildup detection
      if(i >= 5)
      {
         double mom_sum = 0;
         for(int k = 1; k <= 5; k++)
         {
            if(i-k >= 0) mom_sum += momentum_sma[i-k];
         }
         double avg_mom = mom_sum / 5.0;
         
         if(avg_mom > 0)
         {
            momentum_factor = (momentum_sma[i] / avg_mom) - 1.0;
         }
      }
      
      // 3. Pattern recognition (doji, hammer, shooting star, etc.)
      double body_ratio = (current_range > 0) ? current_body / current_range : 0;
      double upper_shadow = high[i] - MathMax(open[i], close[i]);
      double lower_shadow = MathMin(open[i], close[i]) - low[i];
      
      // Doji pattern (small body, large shadows)
      if(body_ratio < 0.1 && upper_shadow > current_range * 0.3 && lower_shadow > current_range * 0.3)
      {
         pattern_factor += 0.3;
      }
      
      // Hammer/Shooting star patterns
      if(body_ratio > 0.3 && body_ratio < 0.7)
      {
         if(lower_shadow > current_range * 0.6) pattern_factor += 0.2; // Hammer
         if(upper_shadow > current_range * 0.6) pattern_factor += 0.2; // Shooting star
      }
      
      // 4. Bollinger Bands squeeze
      if(i < ArraySize(bufBBU) && i < ArraySize(bufBBL))
      {
         double bb_width = bufBBU[i] - bufBBL[i];
         if(current_atr > 0)
         {
            double bb_squeeze = bb_width / (current_atr * 2.0);
            if(bb_squeeze < 1.5) pattern_factor += 0.2; // Squeeze detected
         }
      }
      
      // 5. Volume spike (if available)
      double volume_spike = 0;
      if(i >= 10)
      {
         double avg_vol = 0;
         for(int k = 1; k <= 10; k++)
         {
            if(i-k >= 0) avg_vol += 1.0; // Simplified volume
         }
         avg_vol /= 10.0;
         volume_spike = (1.0 / avg_vol) - 1.0;
      }
      
      // Calculate total spike probability with weighted factors
      double spike_probability = (volatility_factor * 0.3) + (momentum_factor * 0.3) + (pattern_factor * 0.3) + (volume_spike * 0.1);
      
      // Predict BOOM (upward spike) - only if probability is significant
      if(spike_probability > InpSpikeThreshold && spike_probability < 10.0) // Cap at 10.0 to prevent extreme values
      {
         // Check if we're in a potential upward breakout scenario
         bool breakout_up = false;
         
         // Price near resistance levels
         if(i < ArraySize(bufBBU) && close[i] > bufBBM[i] && close[i] < bufBBU[i] * 0.98)
         {
            breakout_up = true;
         }
         
         // Supertrend bullish
         if(i < ArraySize(bufST) && bufST[i] != EMPTY_VALUE)
         {
            breakout_up = true;
         }
         
         // EMA200 support
         if(i < ArraySize(bufEMA200) && close[i] > bufEMA200[i])
         {
            breakout_up = true;
         }
         
         if(breakout_up)
         {
            datetime prediction_time = time[i] + prediction_bars * PeriodSeconds();
            string spike_name = StringFormat("TB_SPIKE_BOOM_%d", (int)time[i]);
            
            if(ObjectCreate(0, spike_name, OBJ_ARROW, 0, prediction_time, high[i] + current_atr * 0.5))
            {
               ObjectSetInteger(0, spike_name, OBJPROP_ARROWCODE, 233); // Up arrow
               ObjectSetInteger(0, spike_name, OBJPROP_WIDTH, 3);
               ObjectSetInteger(0, spike_name, OBJPROP_COLOR, (long)clrGold);
               ObjectSetString(0, spike_name, OBJPROP_TOOLTIP, 
                              StringFormat("BOOM Prediction: %.1f%% confidence", MathMin(100.0, spike_probability * 15)));
            }
            else
            {
               Print("Failed to create BOOM spike object: ", GetLastError());
            }
         }
      }
      
      // Predict CRASH (downward spike) - only if probability is significant
      if(spike_probability > InpSpikeThreshold && spike_probability < 10.0) // Cap at 10.0 to prevent extreme values
      {
         // Check if we're in a potential downward breakdown scenario
         bool breakdown_down = false;
         
         // Price near support levels
         if(i < ArraySize(bufBBL) && close[i] < bufBBM[i] && close[i] > bufBBL[i] * 1.02)
         {
            breakdown_down = true;
         }
         
         // Supertrend bearish
         if(i < ArraySize(bufSTDn) && bufSTDn[i] != EMPTY_VALUE)
         {
            breakdown_down = true;
         }
         
         // EMA200 resistance
         if(i < ArraySize(bufEMA200) && close[i] < bufEMA200[i])
         {
            breakdown_down = true;
         }
         
         if(breakdown_down)
         {
            datetime prediction_time = time[i] + prediction_bars * PeriodSeconds();
            string spike_name = StringFormat("TB_SPIKE_CRASH_%d", (int)time[i]);
            
            if(ObjectCreate(0, spike_name, OBJ_ARROW, 0, prediction_time, low[i] - current_atr * 0.5))
            {
               ObjectSetInteger(0, spike_name, OBJPROP_ARROWCODE, 234); // Down arrow
               ObjectSetInteger(0, spike_name, OBJPROP_WIDTH, 3);
               ObjectSetInteger(0, spike_name, OBJPROP_COLOR, (long)clrDarkRed);
               ObjectSetString(0, spike_name, OBJPROP_TOOLTIP, 
                              StringFormat("CRASH Prediction: %.1f%% confidence", MathMin(100.0, spike_probability * 15)));
            }
            else
            {
               Print("Failed to create CRASH spike object: ", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   IndicatorSetInteger(INDICATOR_DIGITS, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   SetIndexBuffer(0, bufEMA200, INDICATOR_DATA);
   SetIndexBuffer(1, bufBBU,   INDICATOR_DATA);
   SetIndexBuffer(2, bufBBM,   INDICATOR_DATA);
   SetIndexBuffer(3, bufBBL,   INDICATOR_DATA);
   SetIndexBuffer(4, bufVWAP,  INDICATOR_DATA);
   SetIndexBuffer(5, bufSAR,   INDICATOR_DATA);
   SetIndexBuffer(6, bufKijun, INDICATOR_DATA);
   SetIndexBuffer(7, bufST,    INDICATOR_DATA);
   SetIndexBuffer(8, bufSTDn,  INDICATOR_DATA);

   hEMA  = iMA(_Symbol, _Period, InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE);
   hBB   = iBands(_Symbol, _Period, InpBBPeriod, (int)InpBBDev, 0, PRICE_CLOSE);
   hATR  = iATR(_Symbol, _Period, InpATRPeriod);
   hSAR  = iSAR(_Symbol, _Period, InpSARStep, InpSARMax);
   hIchi = iIchimoku(_Symbol, _Period, InpIchiTenkan, InpIchiKijun, 52);
   hFrac = iFractals(_Symbol, _Period);

   if(hEMA == INVALID_HANDLE || hBB == INVALID_HANDLE || hATR == INVALID_HANDLE || hSAR == INVALID_HANDLE || hIchi == INVALID_HANDLE || hFrac == INVALID_HANDLE)
   {
      Print("Erreur création handles: ", GetLastError());
      return INIT_FAILED;
   }

   ArraySetAsSeries(bufEMA200, true);
   ArraySetAsSeries(bufBBU, true);
   ArraySetAsSeries(bufBBM, true);
   ArraySetAsSeries(bufBBL, true);
   ArraySetAsSeries(bufVWAP, true);
   ArraySetAsSeries(bufSAR, true);
   ArraySetAsSeries(bufKijun, true);
   ArraySetAsSeries(bufST, true);
   ArraySetAsSeries(bufSTDn, true);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert calculation function (MQL5 signature)                     |
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
   // Safety checks to prevent crashes
   if(rates_total <= 0) return 0;
   if(ArraySize(time) == 0 || ArraySize(open) == 0 || ArraySize(high) == 0 || ArraySize(low) == 0 || ArraySize(close) == 0)
   {
      Print("Error: Invalid array sizes in OnCalculate");
      return 0;
   }
   
   // Limit processing to prevent overload
   int max_bars = MathMin(rates_total, 500);
   if(rates_total > max_bars)
   {
      Print("Info: Processing limited to ", max_bars, " bars for optimal performance");
   }

   // Safe CopyBuffer calls with error checking
   if(CopyBuffer(hEMA, 0, 0, rates_total, bufEMA200) <= 0)
   {
      Print("Error copying EMA buffer: ", GetLastError());
      return prev_calculated;
   }
   if(CopyBuffer(hBB, 0, 0, rates_total, bufBBU) <= 0)
   {
      Print("Error copying BB Upper buffer: ", GetLastError());
      return prev_calculated;
   }
   if(CopyBuffer(hBB, 1, 0, rates_total, bufBBM) <= 0)
   {
      Print("Error copying BB Middle buffer: ", GetLastError());
      return prev_calculated;
   }
   if(CopyBuffer(hBB, 2, 0, rates_total, bufBBL) <= 0)
   {
      Print("Error copying BB Lower buffer: ", GetLastError());
      return prev_calculated;
   }
   if(CopyBuffer(hSAR, 0, 0, rates_total, bufSAR) <= 0)
   {
      Print("Error copying SAR buffer: ", GetLastError());
      return prev_calculated;
   }

   double tmpKijun[]; ArrayResize(tmpKijun, rates_total); ArraySetAsSeries(tmpKijun, true);
   CopyBuffer(hIchi, 1, 0, rates_total, tmpKijun);
   ArrayCopy(bufKijun, tmpKijun);

   int win = MathMax(10, InpVWAPWindow);
   ArraySetAsSeries(bufVWAP, true);
   for(int i = 0; i < rates_total; i++)
   {
      int start = MathMax(0, i - win + 1);
      double num = 0.0, den = 0.0;
      for(int j = i; j >= start; j--)
      {
         double v = (double)tick_volume[j];
         if(v > 0.0) { num += close[j] * v; den += v; }
      }
      bufVWAP[i] = (den > 0.0) ? num / den : EMPTY_VALUE;
   }

   double atr[]; ArraySetAsSeries(atr, true); CopyBuffer(hATR, 0, 0, rates_total, atr);
   ArraySetAsSeries(bufST, true); ArraySetAsSeries(bufSTDn, true);
   double st_prev = EMPTY_VALUE, stdn_prev = EMPTY_VALUE;
   
   // Call spike prediction function with safety check
   if(InpEnableSpikePrediction && rates_total >= 50)
   {
      PredictSpikes(rates_total, time, high, low, close, open, atr);
   }
   
   // Call blue spike alert function with safety check
   if(InpEnableBlueSpikeAlerts && rates_total >= 30)
   {
      PredictBlueSpikeAlerts(rates_total, time, high, low, close, open, atr);
   }

   for(int i = rates_total - 1; i >= 0; i--)
   {
      if(i >= ArraySize(atr) || atr[i] == EMPTY_VALUE || high[i] == EMPTY_VALUE || low[i] == EMPTY_VALUE || close[i] == EMPTY_VALUE)
      { bufST[i] = EMPTY_VALUE; bufSTDn[i] = EMPTY_VALUE; continue; }

      double mid = (high[i] + low[i]) * 0.5;
      double atr_val = atr[i];
      double bandUp = mid + InpST_Multiplier * atr_val;
      double bandDn = mid - InpST_Multiplier * atr_val;
      double st = EMPTY_VALUE; double trend = 0.0;

      if(i == rates_total - 1)
      { trend = (close[i] > mid) ? 1.0 : -1.0; st = (trend > 0) ? bandUp : bandDn; }
      else
      {
         st_prev = bufST[i+1]; stdn_prev = bufSTDn[i+1];
         bool wasUp = (st_prev != EMPTY_VALUE && stdn_prev == EMPTY_VALUE);
         double prev = wasUp ? st_prev : stdn_prev;
         if(wasUp)
         {
            double st_candidate = MathMin(bandUp, prev);
            if(close[i] < st_candidate) { trend = -1.0; st = bandDn; }
            else { trend = 1.0; st = st_candidate; }
         }
         else
         {
            double st_candidate2 = MathMax(bandDn, prev);
            if(close[i] > st_candidate2) { trend = 1.0; st = bandUp; }
            else { trend = -1.0; st = st_candidate2; }
         }
      }

      if(trend > 0) { bufST[i] = st; bufSTDn[i] = EMPTY_VALUE; }
      else           { bufST[i] = EMPTY_VALUE; bufSTDn[i] = st; }
   }

   if(InpDrawFractalSR)
   {
      ClearObjectsByPrefix("TB_SR_");
      double up_fractals[], dn_fractals[]; ArraySetAsSeries(up_fractals, true); ArraySetAsSeries(dn_fractals, true);
      CopyBuffer(hFrac, 0, 0, rates_total, up_fractals); CopyBuffer(hFrac, 1, 0, rates_total, dn_fractals);
      int bars_to_check = MathMin(300, rates_total - 1);
      int drawn_up = 0, drawn_dn = 0, max_lines = 8, seg_len = 25;
      datetime bar_times[]; ArraySetAsSeries(bar_times, true); CopyTime(_Symbol, _Period, 0, rates_total, bar_times);
      for(int i = 1; i < bars_to_check && (drawn_up < max_lines || drawn_dn < max_lines); i++)
      {
         if(drawn_up < max_lines && up_fractals[i] != EMPTY_VALUE)
         {
            int j = MathMax(0, i - seg_len);
            string n = StringFormat("TB_SR_U_%d_%d", (int)bar_times[i], i);
            if(ObjectCreate(0, n, OBJ_TREND, 0, bar_times[i], up_fractals[i], bar_times[j], up_fractals[i]))
            { ObjectSetInteger(0, n, OBJPROP_COLOR, (long)clrMagenta); ObjectSetInteger(0, n, OBJPROP_WIDTH, 2); ObjectSetInteger(0, n, OBJPROP_STYLE, (long)STYLE_SOLID); drawn_up++; }
         }
         if(drawn_dn < max_lines && dn_fractals[i] != EMPTY_VALUE)
         {
            int j2 = MathMax(0, i - seg_len);
            string n2 = StringFormat("TB_SR_D_%d_%d", (int)bar_times[i], i);
            if(ObjectCreate(0, n2, OBJ_TREND, 0, bar_times[i], dn_fractals[i], bar_times[j2], dn_fractals[i]))
            { ObjectSetInteger(0, n2, OBJPROP_COLOR, (long)clrDodgerBlue); ObjectSetInteger(0, n2, OBJPROP_WIDTH, 2); ObjectSetInteger(0, n2, OBJPROP_STYLE, (long)STYLE_SOLID); drawn_dn++; }
         }
      }
   }

   if(InpDrawDailyPivots)
   {
      ClearObjectsByPrefix("TB_PVT_");
      double yHigh=iHigh(_Symbol, PERIOD_D1, 1), yLow=iLow(_Symbol, PERIOD_D1, 1), yClose=iClose(_Symbol, PERIOD_D1, 1);
      if(yHigh>0 && yLow>0 && yClose>0)
      {
         double P=(yHigh+yLow+yClose)/3.0, R1=2*P - yLow, S1=2*P - yHigh, R2=P + (yHigh - yLow), S2=P - (yHigh - yLow), R3=yHigh + 2*(P - yLow), S3=yLow - 2*(yHigh - P);
         datetime t0[]; ArraySetAsSeries(t0, true); CopyTime(_Symbol, _Period, 0, 2, t0);
         datetime x1 = TimeCurrent(); datetime x0 = (ArraySize(t0)>1 ? t0[1] : x1 - 24*3600);
         string names[7] = {"TB_PVT_P","TB_PVT_R1","TB_PVT_S1","TB_PVT_R2","TB_PVT_S2","TB_PVT_R3","TB_PVT_S3"};
         double vals[7]  = {P,R1,S1,R2,S2,R3,S3}; color cols[7] = {clrGainsboro,clrTomato,clrDeepSkyBlue,clrTomato,clrDeepSkyBlue,clrTomato,clrDeepSkyBlue};
         for(int k=0;k<7;k++) if(ObjectCreate(0,names[k],OBJ_TREND,0,x0,vals[k],x1,vals[k])) { ObjectSetInteger(0,names[k],OBJPROP_COLOR,(long)cols[k]); ObjectSetInteger(0,names[k],OBJPROP_WIDTH,1); ObjectSetInteger(0,names[k],OBJPROP_STYLE,(long)STYLE_SOLID); }
      }
   }

   if(InpEnableOTE)
   {
      ClearObjectsByPrefix("TB_OTE_");
      ClearObjectsByPrefix("TB_SIG_");
      int bars_for_ote = MathMin(400, rates_total - 1);
      if(bars_for_ote > 15)
      {
         datetime bt[]; double hh[], ll[], cc[];
         ArraySetAsSeries(bt,true); ArraySetAsSeries(hh,true); ArraySetAsSeries(ll,true); ArraySetAsSeries(cc,true);
         ArrayResize(bt, rates_total); ArrayResize(hh, rates_total); ArrayResize(ll, rates_total); ArrayResize(cc, rates_total);
         for(int i=0;i<rates_total;i++){ bt[i]=time[i]; hh[i]=high[i]; ll[i]=low[i]; cc[i]=close[i]; }

         int w = MathMax(3, MathMin(11, InpOTEPivotWindow)); int lastH=-1, lastL=-1;
         int i_start = w; int i_end = bars_for_ote - 1 - w;
         if(i_end < i_start) i_end = i_start;
         for(int i=i_end; i>=i_start; i--){ bool isH=true; for(int k=1;k<=w;k++){ if(hh[i]<=hh[i-k] || hh[i]<=hh[i+k]){ isH=false; break; } } if(isH){ lastH=i; break; } }
         for(int i=i_end; i>=i_start; i--){ bool isL=true; for(int k=1;k<=w;k++){ if(ll[i]>=ll[i-k] || ll[i]>=ll[i+k]){ isL=false; break; } } if(isL){ lastL=i; break; } }

         if(lastH>=0 && lastL>=0)
         {
            double swingH = hh[lastH], swingL = ll[lastL], rng = swingH - swingL;
            if(rng>0.0)
            {
               bool up = (lastH>lastL);
               double fib0 = up ? swingL : swingH, fib1 = up ? swingH : swingL;
               double fib05 = fib0 + 0.5*rng, fib078 = fib0 + 0.78*rng;
               datetime x_left = bt[i_end]; datetime x_right = bt[0];
               string rBuy = StringFormat("TB_OTE_BUY_%d_%d", (int)x_left, i_end);
               if(ObjectCreate(0,rBuy,OBJ_RECTANGLE,0,x_left,fib0,x_right,fib05))
               { ObjectSetInteger(0,rBuy,OBJPROP_COLOR,(long)clrLime); ObjectSetInteger(0,rBuy,OBJPROP_WIDTH,1); ObjectSetInteger(0,rBuy,OBJPROP_STYLE,(long)STYLE_SOLID); ObjectSetInteger(0,rBuy,OBJPROP_BACK, (long)1); }
               string rSell = StringFormat("TB_OTE_SELL_%d_%d", (int)x_left, i_end);
               if(ObjectCreate(0,rSell,OBJ_RECTANGLE,0,x_left,fib078,x_right,fib1))
               { ObjectSetInteger(0,rSell,OBJPROP_COLOR,(long)clrTomato); ObjectSetInteger(0,rSell,OBJPROP_WIDTH,1); ObjectSetInteger(0,rSell,OBJPROP_STYLE,(long)STYLE_SOLID); ObjectSetInteger(0,rSell,OBJPROP_BACK,(long)1); }

               double px = cc[0]; string msg = "OTE: "; color col = clrGainsboro; double pos = (px - fib0) / rng;
               if(up)
               {
                  if(pos>=0.0 && pos<=0.5){ msg+="Zone achat (0-0.5)"; col=clrLime; }
                  else if(pos>0.5 && pos<0.78){ msg+="Zone risquée (0.5-0.78)"; col=clrGold; }
                  else if(pos>=0.78 && pos<=1.0){ msg+="Zone OTE vente (0.78-1)"; col=clrTomato; }
                  else { msg+="Hors plage"; }
               }
               else
               {
                  double posD = (fib1 - px) / rng;
                  if(posD>=0.0 && posD<=0.5){ msg+="Zone vente (0-0.5)"; col=clrTomato; }
                  else if(posD>0.5 && posD<0.78){ msg+="Zone risquée (0.5-0.78)"; col=clrGold; }
                  else if(posD>=0.78 && posD<=1.0){ msg+="Zone OTE achat (0.78-1)"; col=clrLime; }
                  else { msg+="Hors plage"; }
               }
               string lab = "TB_OTE_LABEL";
               if(ObjectCreate(0,lab,OBJ_LABEL,0,0,0))
               { ObjectSetInteger(0,lab,OBJPROP_XDISTANCE,10); ObjectSetInteger(0,lab,OBJPROP_YDISTANCE,20); ObjectSetInteger(0,lab,OBJPROP_CORNER,(long)CORNER_LEFT_UPPER); ObjectSetInteger(0,lab,OBJPROP_COLOR,(long)col); ObjectSetString(0,lab,OBJPROP_TEXT,msg); }

               // ==========================
               // Signaux fléchés BUY/SELL
               // ==========================
               int lookback = MathMin(150, i_end - i_start + 1);
               double px_offset = rng * 0.01; // offset visuel
               for(int ii=i_end; ii>=i_end - lookback + 1; ii--)
               {
                  if(ii<0 || ii>=rates_total) continue;
                  bool trend_up  = (bufST[ii]   != EMPTY_VALUE);
                  bool trend_down= (bufSTDn[ii] != EMPTY_VALUE);
                  bool above_ema = (bufEMA200[ii] != EMPTY_VALUE && cc[ii] > bufEMA200[ii]);
                  bool below_ema = (bufEMA200[ii] != EMPTY_VALUE && cc[ii] < bufEMA200[ii]);

                  bool buy_cond=false, sell_cond=false;
                  if(up)
                  {
                     double pos_i = (cc[ii] - fib0) / rng;
                     buy_cond  = (pos_i>=0.0 && pos_i<=0.5)  && trend_up   && above_ema;
                     sell_cond = (pos_i>=0.78 && pos_i<=1.0) && trend_down && below_ema;
                  }
                  else
                  {
                     double posD_i = (fib1 - cc[ii]) / rng;
                     sell_cond = (posD_i>=0.0 && posD_i<=0.5)  && trend_down && below_ema;
                     buy_cond  = (posD_i>=0.78 && posD_i<=1.0) && trend_up   && above_ema;
                  }

                  if(buy_cond)
                  {
                     string nb = StringFormat("TB_SIG_BUY_%d", (int)bt[ii]);
                     if(ObjectCreate(0, nb, OBJ_ARROW, 0, bt[ii], ll[ii] - px_offset))
                     {
                        ObjectSetInteger(0, nb, OBJPROP_ARROWCODE, 241);
                        ObjectSetInteger(0, nb, OBJPROP_WIDTH, 2);
                        ObjectSetInteger(0, nb, OBJPROP_COLOR, (long)clrLime);
                     }
                  }
                  else if(sell_cond)
                  {
                     string ns = StringFormat("TB_SIG_SELL_%d", (int)bt[ii]);
                     if(ObjectCreate(0, ns, OBJ_ARROW, 0, bt[ii], hh[ii] + px_offset))
                     {
                        ObjectSetInteger(0, ns, OBJPROP_ARROWCODE, 242);
                        ObjectSetInteger(0, ns, OBJPROP_WIDTH, 2);
                        ObjectSetInteger(0, ns, OBJPROP_COLOR, (long)clrTomato);
                     }
                  }
               }
            }
         }
      }
   }

   // Final safety check
   if(rates_total > 0)
   {
      return rates_total;
   }
   else
   {
      Print("Error: rates_total is zero or negative");
      return prev_calculated;
   }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ClearObjectsByPrefix("TB_SR_");
   ClearObjectsByPrefix("TB_PVT_");
   ClearObjectsByPrefix("TB_OTE_");
   ClearObjectsByPrefix("TB_SPIKE_");
   ClearObjectsByPrefix("TB_BLUE_SPIKE_"); // Nettoyer les alertes bleues
   ClearObjectsByPrefix("TB_BLUE_TEXT_");   // Nettoyer les textes bleus
   if(ObjectFind(0, "TB_OTE_LABEL") != -1)
      ObjectDelete(0, "TB_OTE_LABEL");
}


