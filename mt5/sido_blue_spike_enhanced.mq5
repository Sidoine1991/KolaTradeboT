//+------------------------------------------------------------------+
//|                                        sido_blue_spike_enhanced.mq5  |
//|                        Copyright 2023, TradBOT                   |
//|                                       https://www.mql5.com       |
//+------------------------------------------------------------------+
#property copyright "TradBOT"
#property version   "1.06"
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
input int      InpSpikeLookback   = 50;
input double   InpSpikeThreshold  = 1.8;
input int      InpPredictionMinutes = 1;

//--- NOUVELLES OPTIONS POUR LES ALERTES BLEUES
input bool     InpEnableBlueSpikeAlerts = true;
input double   InpBlueSpikeThreshold = 1.5;
input int      InpBlueSpikeLookback = 30;
input bool     InpEnableSoundAlerts = true;
input bool     InpEnablePushNotifications = true;
input bool     InpEnableEmailAlerts = false;
input string   InpEmailAddress = "";

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

//--- Variables globales pour les alertes
datetime last_alert_time = 0;
int alert_count = 0;

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
//| Fonction d'alerte avancée pour les spikes bleus                  |
//+------------------------------------------------------------------+
void SendSpikeAlert(const string message, const double confidence, const string direction)
{
   datetime current_time = TimeCurrent();
   
   // Éviter le spam d'alertes (max 1 alerte par minute)
   if(current_time - last_alert_time < 60)
      return;
   
   last_alert_time = current_time;
   alert_count++;
   
   // Alerte sonore
   if(InpEnableSoundAlerts)
   {
      PlaySound("alert.wav");
   }
   
   // Notification push
   if(InpEnablePushNotifications)
   {
      string push_message = StringFormat("🚀 SPIKE ALERT!\n%s\nConfiance: %.1f%%\nDirection: %s", 
                                        message, confidence, direction);
      SendNotification(push_message);
   }
   
   // Email
   if(InpEnableEmailAlerts && InpEmailAddress != "")
   {
      string email_subject = StringFormat("SPIKE ALERT - %s", _Symbol);
      string email_body = StringFormat("Alerte de spike détectée!\n\nSymbole: %s\nTimeframe: %s\nConfiance: %.1f%%\nDirection: %s\nHeure: %s", 
                                      _Symbol, EnumToString(_Period), confidence, direction, TimeToString(current_time));
      SendMail(email_subject, email_body);
   }
   
   // Message dans le journal
   Print(StringFormat("SPIKE ALERT #%d: %s (Confiance: %.1f%%, Direction: %s)", 
         alert_count, message, confidence, direction));
}

//+------------------------------------------------------------------+
//| Fonction de prédiction de spikes bleus améliorée                |
//+------------------------------------------------------------------+
void PredictBlueSpikeAlertsEnhanced(const int rates_total,
                                    const datetime &time[],
                                    const double &high[],
                                    const double &low[],
                                    const double &close[],
                                    const double &open[],
                                    const double &atr[])
{
   if(!InpEnableBlueSpikeAlerts || rates_total < 30) return;
   
   ClearObjectsByPrefix("TB_BLUE_SPIKE_");
   
   int lookback = MathMin(InpBlueSpikeLookback, rates_total - 10);
   
   for(int i = rates_total - lookback; i >= 5; i--)
   {
      if(i < 0 || i >= rates_total) continue;
      
      // Analyse multi-factorielle pour détecter les spikes imminents
      double volatility_compression = 0;
      double momentum_buildup = 0;
      double pattern_recognition = 0;
      double volume_analysis = 0;
      double support_resistance_proximity = 0;
      
      // 1. Compression de volatilité (Bollinger Bands squeeze)
      if(i < ArraySize(bufBBU) && i < ArraySize(bufBBL) && i < ArraySize(atr))
      {
         double bb_width = bufBBU[i] - bufBBL[i];
         double atr_val = atr[i];
         if(atr_val > 0)
         {
            double bb_squeeze = bb_width / (atr_val * 2.0);
            if(bb_squeeze < 1.0) // Compression extrême
            {
               volatility_compression = 0.5;
            }
            else if(bb_squeeze < 1.3) // Compression forte
            {
               volatility_compression = 0.3;
            }
            else if(bb_squeeze < 1.6) // Compression modérée
            {
               volatility_compression = 0.1;
            }
         }
      }
      
      // 2. Accumulation de momentum
      if(i >= 15)
      {
         double total_range = 0;
         double total_body = 0;
         int consolidation_bars = 0;
         
         for(int k = 1; k <= 15; k++)
         {
            if(i-k >= 0)
            {
               double bar_range = high[i-k] - low[i-k];
               double bar_body = MathAbs(close[i-k] - open[i-k]);
               total_range += bar_range;
               total_body += bar_body;
               
               // Compter les bougies de consolidation
               if(bar_body < bar_range * 0.3)
                  consolidation_bars++;
            }
         }
         
         double avg_range = total_range / 15.0;
         double avg_body = total_body / 15.0;
         double current_range = high[i] - low[i];
         double current_body = MathAbs(close[i] - open[i]);
         
         // Score d'accumulation
         if(avg_range > 0 && current_range < avg_range * 0.6 && current_body < avg_body * 0.4)
         {
            momentum_buildup = 0.4;
         }
         else if(avg_range > 0 && current_range < avg_range * 0.8 && current_body < avg_body * 0.6)
         {
            momentum_buildup = 0.2;
         }
         
         // Bonus pour consolidation prolongée
         if(consolidation_bars >= 10)
         {
            momentum_buildup += 0.2;
         }
      }
      
      // 3. Reconnaissance de patterns
      double body_ratio = (high[i] - low[i] > 0) ? MathAbs(close[i] - open[i]) / (high[i] - low[i]) : 0;
      double upper_shadow = high[i] - MathMax(open[i], close[i]);
      double lower_shadow = MathMin(open[i], close[i]) - low[i];
      double shadow_ratio = (high[i] - low[i] > 0) ? (upper_shadow + lower_shadow) / (high[i] - low[i]) : 0;
      
      // Pattern Doji (indécision)
      if(body_ratio < 0.1 && shadow_ratio > 0.7)
      {
         pattern_recognition = 0.3;
      }
      // Pattern Spinning Top (indécision avec petite tendance)
      else if(body_ratio < 0.3 && shadow_ratio > 0.5)
      {
         pattern_recognition = 0.2;
      }
      // Pattern Hammer/Shooting Star
      else if(body_ratio > 0.2 && body_ratio < 0.6)
      {
         if(lower_shadow > (high[i] - low[i]) * 0.6) // Hammer
            pattern_recognition = 0.25;
         else if(upper_shadow > (high[i] - low[i]) * 0.6) // Shooting Star
            pattern_recognition = 0.25;
      }
      
      // 4. Proximité des niveaux clés
      if(i < ArraySize(bufEMA200) && bufEMA200[i] != EMPTY_VALUE)
      {
         double distance_to_ema = MathAbs(close[i] - bufEMA200[i]);
         double atr_val = (i < ArraySize(atr)) ? atr[i] : 0;
         if(atr_val > 0)
         {
            double proximity = distance_to_ema / (atr_val * 2.0);
            if(proximity < 0.3) // Très proche
            {
               support_resistance_proximity = 0.3;
            }
            else if(proximity < 0.6) // Proche
            {
               support_resistance_proximity = 0.15;
            }
         }
      }
      
      // Calcul du score total avec pondération
      double spike_imminent_score = (volatility_compression * 0.3) + 
                                   (momentum_buildup * 0.3) + 
                                   (pattern_recognition * 0.2) + 
                                   (volume_analysis * 0.1) + 
                                   (support_resistance_proximity * 0.1);
      
      // Alerte SPIKE IMMINENT
      if(spike_imminent_score > InpBlueSpikeThreshold)
      {
         // Déterminer la direction probable
         string direction = "NEUTRE";
         bool bullish_context = false;
         bool bearish_context = false;
         
         // Contexte haussier
         if(i < ArraySize(bufEMA200) && close[i] > bufEMA200[i] && 
            i < ArraySize(bufST) && bufST[i] != EMPTY_VALUE)
         {
            bullish_context = true;
            direction = "HAUSSIER";
         }
         
         // Contexte baissier  
         if(i < ArraySize(bufEMA200) && close[i] < bufEMA200[i] && 
            i < ArraySize(bufSTDn) && bufSTDn[i] != EMPTY_VALUE)
         {
            bearish_context = true;
            direction = "BAISSIER";
         }
         
         // Créer l'alerte visuelle
         string alert_name = StringFormat("TB_BLUE_SPIKE_%d", (int)time[i]);
         double alert_price = close[i];
         
         if(ObjectCreate(0, alert_name, OBJ_ARROW, 0, time[i], alert_price))
         {
            // Flèche bleue distinctive
            ObjectSetInteger(0, alert_name, OBJPROP_ARROWCODE, 233);
            ObjectSetInteger(0, alert_name, OBJPROP_WIDTH, 5); // Plus épaisse
            ObjectSetInteger(0, alert_name, OBJPROP_COLOR, (long)clrDodgerBlue);
            ObjectSetString(0, alert_name, OBJPROP_TOOLTIP, 
                           StringFormat("🚀 SPIKE IMMINENT!\nConfiance: %.1f%%\nDirection: %s\nScore: %.2f", 
                           MathMin(100.0, spike_imminent_score * 30), direction, spike_imminent_score));
            
            // Texte d'alerte
            string text_name = StringFormat("TB_BLUE_TEXT_%d", (int)time[i]);
            if(ObjectCreate(0, text_name, OBJ_TEXT, 0, time[i], alert_price + (high[i] - low[i]) * 0.4))
            {
               ObjectSetString(0, text_name, OBJPROP_TEXT, "🚀 SPIKE!");
               ObjectSetInteger(0, text_name, OBJPROP_COLOR, (long)clrDodgerBlue);
               ObjectSetInteger(0, text_name, OBJPROP_FONTSIZE, 10);
               ObjectSetString(0, text_name, OBJPROP_FONT, "Arial Bold");
            }
            
            // Envoyer les alertes
            double confidence_percent = MathMin(100.0, spike_imminent_score * 30);
            SendSpikeAlert("Spike imminent détecté!", confidence_percent, direction);
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
   if(rates_total <= 0) return 0;
   
   // Copy buffers
   if(CopyBuffer(hEMA, 0, 0, rates_total, bufEMA200) <= 0) return prev_calculated;
   if(CopyBuffer(hBB, 0, 0, rates_total, bufBBU) <= 0) return prev_calculated;
   if(CopyBuffer(hBB, 1, 0, rates_total, bufBBM) <= 0) return prev_calculated;
   if(CopyBuffer(hBB, 2, 0, rates_total, bufBBL) <= 0) return prev_calculated;
   if(CopyBuffer(hSAR, 0, 0, rates_total, bufSAR) <= 0) return prev_calculated;

   double tmpKijun[]; ArrayResize(tmpKijun, rates_total); ArraySetAsSeries(tmpKijun, true);
   CopyBuffer(hIchi, 1, 0, rates_total, tmpKijun);
   ArrayCopy(bufKijun, tmpKijun);

   // VWAP calculation
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
   
   // Call enhanced blue spike alert function
   if(InpEnableBlueSpikeAlerts && rates_total >= 30)
   {
      PredictBlueSpikeAlertsEnhanced(rates_total, time, high, low, close, open, atr);
   }

   // Supertrend calculation
   ArraySetAsSeries(bufST, true); ArraySetAsSeries(bufSTDn, true);
   double st_prev = EMPTY_VALUE, stdn_prev = EMPTY_VALUE;
   
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

   return rates_total;
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
   ClearObjectsByPrefix("TB_BLUE_SPIKE_");
   ClearObjectsByPrefix("TB_BLUE_TEXT_");
   if(ObjectFind(0, "TB_OTE_LABEL") != -1)
      ObjectDelete(0, "TB_OTE_LABEL");
}
