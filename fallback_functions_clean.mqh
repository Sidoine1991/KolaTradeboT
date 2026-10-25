//+------------------------------------------------------------------+
//| FONCTIONS DE FALLBACK LOCAL CORRIGÉES                          |
//+------------------------------------------------------------------+

// Générer une analyse locale basée sur les indicateurs techniques
string GenerateLocalFallbackAnalysis()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFast) < 2 ||
      CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlow) < 2)
      return "";
   
   string direction = (emaFast[0] > emaSlow[0]) ? "BUY" : "SELL";
   double confidence = MathAbs(emaFast[0] - emaSlow[0]) / currentPrice * 100;
   
   string analysis = "{\"recommendation\":\"" + direction + "\",\"confidence\":" + 
                   DoubleToString(MathMin(0.7, confidence), 3) + 
                   ",\"reasoning\":\"Local fallback - EMA analysis\"}";
   
   if(DebugMode)
      Print("🔧 Fallback local généré pour Analysis: ", direction, " (", DoubleToString(confidence*100, 1), "%)");
   
   return analysis;
}

// Générer une tendance locale basée sur les EMA multi-timeframes
string GenerateLocalFallbackTrend()
{
   string trend = "";
   
   // Analyser M1
   string m1Trend = GetTrendOnTimeframe(PERIOD_M1);
   trend += "\"trend_m1\":{\"direction\":\"" + m1Trend + "\"},";
   
   // Analyser M5
   string m5Trend = GetTrendOnTimeframe(PERIOD_M5);
   trend += "\"trend_m5\":{\"direction\":\"" + m5Trend + "\"},";
   
   // Analyser H1
   string h1Trend = GetTrendOnTimeframe(PERIOD_H1);
   trend += "\"trend_h1\":{\"direction\":\"" + h1Trend + "\"},";
   
   // Consensus simple
   int uptrendCount = 0;
   if(StringFind(m1Trend, "UP") >= 0) uptrendCount++;
   if(StringFind(m5Trend, "UP") >= 0) uptrendCount++;
   if(StringFind(h1Trend, "UP") >= 0) uptrendCount++;
   
   string consensus = (uptrendCount >= 2) ? "STRONG_UPTREND" : "NEUTRAL";
   double confidence = uptrendCount / 3.0;
   
   string fullTrend = "{\"symbol\":\"" + _Symbol + "\",\"timeframe\":\"M1\",\"timestamp\":\"" + 
                     TimeToString(TimeCurrent()) + "\"," + trend +
                     "\"consensus\":{\"direction\":\"" + consensus + "\",\"confidence\":" + 
                     DoubleToString(confidence, 2) + ",\"uptrend_count\":" + IntegerToString(uptrendCount) + 
                     ",\"downtrend_count\":" + IntegerToString(3-uptrendCount) + "}}";
   
   if(DebugMode)
      Print("🔧 Fallback local généré pour Trend: ", consensus, " (", DoubleToString(confidence*100, 0), "%)");
   
   return fullTrend;
}

// Générer une prédiction locale basée sur l'analyse technique
string GenerateLocalFallbackPrediction()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr[];
   ArraySetAsSeries(atr, true);
   
   double atrValue = 0;
   if(CopyBuffer(atrHandle, 0, 0, 1, atr) > 0)
      atrValue = atr[0];
   else
      atrValue = currentPrice * 0.001; // 0.1% fallback
   
   // Direction basée sur EMA
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   string direction = "NEUTRAL";
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFast) >= 2 &&
      CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlow) >= 2)
   {
      direction = (emaFast[0] > emaSlow[0]) ? "UP" : "DOWN";
   }
   
   // Calculer SL/TP basés sur ATR
   double stopLoss = (direction == "UP") ? currentPrice - (atrValue * 2) : currentPrice + (atrValue * 2);
   double takeProfit = (direction == "UP") ? currentPrice + (atrValue * 3) : currentPrice - (atrValue * 3);
   
   string prediction = "{\"symbol\":\"" + _Symbol + "\",\"timeframe\":\"M1\",\"timestamp\":\"" + 
                     TimeToString(TimeCurrent()) + "\",\"prediction\":{\"direction\":\"" + direction + 
                     "\",\"confidence\":" + DoubleToString(0.6, 2) + ",\"price_target\":" + 
                     DoubleToString(takeProfit, 2) + ",\"stop_loss\":" + DoubleToString(stopLoss, 2) + 
                     ",\"take_profit\":" + DoubleToString(takeProfit, 2) + ",\"time_horizon\":\"1h\"},\"analysis\":{\"trend_strength\":65,\"volatility\":50,\"volume\":55,\"rsi\":50,\"macd\":\"NEUTRAL\"},\"source\":\"local_fallback\"}";
   
   if(DebugMode)
      Print("🔧 Fallback local généré pour Prediction: ", direction, " (60% confiance)");
   
   return prediction;
}

// Générer une analyse cohérente locale
string GenerateLocalFallbackCoherent()
{
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Analyse simple basée sur la position actuelle vs moyennes mobiles
   double emaFast[], emaSlow[];
   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);
   
   string direction = "NEUTRAL";
   double strength = 50.0;
   
   if(CopyBuffer(emaFastHandle, 0, 0, 2, emaFast) >= 2 &&
      CopyBuffer(emaSlowHandle, 0, 0, 2, emaSlow) >= 2)
   {
      if(emaFast[0] > emaSlow[0])
      {
         direction = "UP";
         strength = 60.0 + (emaFast[0] - emaSlow[0]) / currentPrice * 1000;
      }
      else
      {
         direction = "DOWN";
         strength = 60.0 + (emaSlow[0] - emaFast[0]) / currentPrice * 1000;
      }
   }
   
   strength = MathMax(40.0, MathMin(80.0, strength));
   
   string coherent = "{\"symbol\":\"" + _Symbol + "\",\"timeframe\":\"M1\",\"timestamp\":\"" + 
                     TimeToString(TimeCurrent()) + "\",\"direction\":\"" + direction + 
                     "\",\"coherence_score\":" + DoubleToString(strength/100, 2) + 
                     ",\"trend_alignment\":" + DoubleToString(strength, 1) + 
                     ",\"volume_confirmation\":true,\"is_valid\":" + 
                     ((strength > 55) ? "true" : "false") + ",\"reasoning\":\"Local coherent analysis\"}";
   
   if(DebugMode)
      Print("🔧 Fallback local généré pour Coherent: ", direction, " (", DoubleToString(strength, 0), "% cohérence)");
   
   return coherent;
}
