//+------------------------------------------------------------------+
//| ML_DataCollector.mqh - Collect all indicators for ML training     |
//| Gathers 50+ indicators across multiple timeframes                |
//| Prepares data for storage in AWS RDS and ML model training      |
//+------------------------------------------------------------------+
#property strict

#ifndef ML_DATACOLLECTOR_MQH
#define ML_DATACOLLECTOR_MQH

#include "AssetStrategy.mqh"

//+------------------------------------------------------------------+
//| IndicatorSnapshot - Complete market data for ML                  |
//+------------------------------------------------------------------+
struct IndicatorSnapshot {
   // Identification
   string symbol;
   datetime timestamp;
   string timeframe;

   // Price
   double bid;
   double ask;
   double spread_pips;

   // Momentum (M1, M5, M15)
   double rsi_m1;
   double rsi_m5;
   double rsi_m15;
   double rsi_h1;

   // Volatility
   double atr_m1;
   double atr_m5;
   double atr_m15;
   double atr_h1;
   double atr_ratio;  // current_atr / 50-bar average

   // Trend (EMA 9/21 on M1/M5/M15/H1)
   double ema_fast_m1;
   double ema_slow_m1;
   double ema_fast_m5;
   double ema_slow_m5;
   double ema_fast_m15;
   double ema_slow_m15;
   double ema_fast_h1;
   double ema_slow_h1;

   // SMC Structures
   bool fvg_detected;
   int fvg_direction;  // -1=Bearish, 0=None, 1=Bullish
   bool bos_detected;
   int bos_direction;
   double ob_proximity_atr;
   bool sweep_detected;
   string sweep_type;  // "SSL", "BSL", or ""

   // KOLA Levels
   double m5_buy_level;
   double m5_sell_level;
   int m5_buy_touches;
   int m5_sell_touches;
   double m15_buy_level;
   double m15_sell_level;
   int m15_buy_touches;
   int m15_sell_touches;
   double h1_buy_level;
   double h1_sell_level;
   int h1_buy_touches;
   int h1_sell_touches;

   // Confluence Scores
   double tech_buy_score;
   double tech_sell_score;
   int entry_quality;
   double spike_probability;

   // Bollinger Bands + VWAP
   bool bb_squeeze;
   double vwap_distance_pct;
   double bb_pctb;
   double bb_width_pct;

   // Volume
   long volume_current;
   double volume_ratio;

   // SIDO Patterns
   bool sido_double_top;
   bool sido_double_bottom;

   // Asset Category
   string asset_category;

   // Multi-timeframe alignment
   double coherence_score;

   // Additional context
   string signal_action;  // BUY, SELL, HOLD
   double signal_confidence;
};

//+------------------------------------------------------------------+
//| Collect all indicators for a symbol                             |
//+------------------------------------------------------------------+
IndicatorSnapshot CollectAllIndicators(string symbol)
{
   IndicatorSnapshot snap;

   snap.symbol = symbol;
   snap.timestamp = TimeCurrent();
   snap.timeframe = "M1";

   // Price data
   snap.bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   snap.ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   snap.spread_pips = (snap.ask - snap.bid) / SymbolInfoDouble(symbol, SYMBOL_POINT);

   // === MOMENTUM ===
   snap.rsi_m1 = CollectRSI(symbol, PERIOD_M1);
   snap.rsi_m5 = CollectRSI(symbol, PERIOD_M5);
   snap.rsi_m15 = CollectRSI(symbol, PERIOD_M15);
   snap.rsi_h1 = CollectRSI(symbol, PERIOD_H1);

   // === VOLATILITY ===
   snap.atr_m1 = CollectATR(symbol, PERIOD_M1);
   snap.atr_m5 = CollectATR(symbol, PERIOD_M5);
   snap.atr_m15 = CollectATR(symbol, PERIOD_M15);
   snap.atr_h1 = CollectATR(symbol, PERIOD_H1);
   snap.atr_ratio = CalculateATRRatio(symbol, PERIOD_M1);

   // === TREND ===
   snap.ema_fast_m1 = CollectEMA(symbol, PERIOD_M1, 9);
   snap.ema_slow_m1 = CollectEMA(symbol, PERIOD_M1, 21);
   snap.ema_fast_m5 = CollectEMA(symbol, PERIOD_M5, 9);
   snap.ema_slow_m5 = CollectEMA(symbol, PERIOD_M5, 21);
   snap.ema_fast_m15 = CollectEMA(symbol, PERIOD_M15, 9);
   snap.ema_slow_m15 = CollectEMA(symbol, PERIOD_M15, 21);
   snap.ema_fast_h1 = CollectEMA(symbol, PERIOD_H1, 9);
   snap.ema_slow_h1 = CollectEMA(symbol, PERIOD_H1, 21);

   // === SMC STRUCTURES ===
   CollectSMCStructures(symbol, snap);

   // === KOLA LEVELS ===
   CollectKOLALevels(symbol, snap);

   // === CONFLUENCE & SCORES ===
   snap.tech_buy_score = ReadGVDirect("LastConfluenceBuyScore", 0.0);
   snap.tech_sell_score = ReadGVDirect("LastConfluenceSellScore", 0.0);
   snap.entry_quality = (int)ReadGVDirect("LastEntryQuality", 0.0);
   snap.spike_probability = ReadGVDirect("LastSpikeProbability", 0.0);

   // === BOLLINGER BANDS + VWAP ===
   CollectBollingerAndVWAP(symbol, snap);

   // === VOLUME ===
   MqlTick tick;
   if(SymbolInfoTick(symbol, tick)) {
      snap.volume_current = tick.volume;
      snap.volume_ratio = CalculateVolumeRatio(symbol);
   }

   // === SIDO PATTERNS ===
   snap.sido_double_top = ReadGVDirect("SIDODoubleTop", 0.0) > 0;
   snap.sido_double_bottom = ReadGVDirect("SIDODoubleBottom", 0.0) > 0;

   // === ASSET CATEGORY ===
   snap.asset_category = AssetStrategy_GetCategoryName(symbol);

   // === MULTI-TIMEFRAME ALIGNMENT ===
   snap.coherence_score = CalculateMultiTimeframeCoherence(symbol);

   // === SIGNAL FROM EA ===
   snap.signal_action = "HOLD";  // Default - MT5 GlobalVariable doesn't support strings
   snap.signal_confidence = ReadGVDirect("LastDecisionConfidence", 0.0);

   return snap;
}

//+------------------------------------------------------------------+
//| Helper: Collect RSI                                              |
//+------------------------------------------------------------------+
double CollectRSI(string symbol, ENUM_TIMEFRAMES tf)
{
   int handle = iRSI(symbol, tf, 14, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return 0.0;

   double rsi[1];
   if(CopyBuffer(handle, 0, 0, 1, rsi) != 1) {
      IndicatorRelease(handle);
      return 0.0;
   }

   IndicatorRelease(handle);
   return rsi[0];
}

//+------------------------------------------------------------------+
//| Helper: Collect ATR                                              |
//+------------------------------------------------------------------+
double CollectATR(string symbol, ENUM_TIMEFRAMES tf)
{
   int handle = iATR(symbol, tf, 14);
   if(handle == INVALID_HANDLE) return 0.0;

   double atr[1];
   if(CopyBuffer(handle, 0, 0, 1, atr) != 1) {
      IndicatorRelease(handle);
      return 0.0;
   }

   IndicatorRelease(handle);
   return atr[0];
}

//+------------------------------------------------------------------+
//| Helper: Collect EMA                                              |
//+------------------------------------------------------------------+
double CollectEMA(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int handle = iMA(symbol, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(handle == INVALID_HANDLE) return 0.0;

   double ema[1];
   if(CopyBuffer(handle, 0, 0, 1, ema) != 1) {
      IndicatorRelease(handle);
      return 0.0;
   }

   IndicatorRelease(handle);
   return ema[0];
}

//+------------------------------------------------------------------+
//| Helper: Calculate ATR Ratio                                      |
//+------------------------------------------------------------------+
double CalculateATRRatio(string symbol, ENUM_TIMEFRAMES tf)
{
   double current_atr = CollectATR(symbol, tf);

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, tf, 0, 50, rates) < 50) return 0.0;

   double sum_atr = 0.0;
   int handle = iATR(symbol, tf, 14);
   if(handle == INVALID_HANDLE) return 0.0;

   double atr_array[50];
   if(CopyBuffer(handle, 0, 0, 50, atr_array) != 50) {
      IndicatorRelease(handle);
      return 0.0;
   }

   IndicatorRelease(handle);

   for(int i = 1; i < 50; i++) {
      sum_atr += atr_array[i];
   }

   double avg_atr = sum_atr / 49.0;

   if(avg_atr == 0.0) return 0.0;
   return current_atr / avg_atr;
}

//+------------------------------------------------------------------+
//| Helper: Collect SMC Structures                                   |
//+------------------------------------------------------------------+
void CollectSMCStructures(string symbol, IndicatorSnapshot &snap)
{
   snap.fvg_detected = ReadGVDirect("FVGDetected", 0.0) > 0;
   snap.fvg_direction = (int)ReadGVDirect("FVGDirection", 0.0);
   snap.bos_detected = ReadGVDirect("BOSDetected", 0.0) > 0;
   snap.bos_direction = (int)ReadGVDirect("BOSDirection", 0.0);
   snap.ob_proximity_atr = ReadGVDirect("OBProximityATR", 0.0);
   snap.sweep_detected = ReadGVDirect("SweepDetected", 0.0) > 0;
   snap.sweep_type = "";  // Default - MT5 GlobalVariable doesn't support strings
}

//+------------------------------------------------------------------+
//| Helper: Collect KOLA Levels                                      |
//+------------------------------------------------------------------+
void CollectKOLALevels(string symbol, IndicatorSnapshot &snap)
{
   snap.m5_buy_level = ReadGVDirect("GOM_KOLA_" + symbol + "_M5_BUY", 0.0);
   snap.m5_sell_level = ReadGVDirect("GOM_KOLA_" + symbol + "_M5_SELL", 0.0);
   snap.m5_buy_touches = (int)ReadGVDirect("GOM_KOLA_" + symbol + "_M5_BUY_TOUCHES", 0.0);
   snap.m5_sell_touches = (int)ReadGVDirect("GOM_KOLA_" + symbol + "_M5_SELL_TOUCHES", 0.0);

   snap.m15_buy_level = ReadGVDirect("GOM_KOLA_" + symbol + "_M15_BUY", 0.0);
   snap.m15_sell_level = ReadGVDirect("GOM_KOLA_" + symbol + "_M15_SELL", 0.0);
   snap.m15_buy_touches = (int)ReadGVDirect("GOM_KOLA_" + symbol + "_M15_BUY_TOUCHES", 0.0);
   snap.m15_sell_touches = (int)ReadGVDirect("GOM_KOLA_" + symbol + "_M15_SELL_TOUCHES", 0.0);

   snap.h1_buy_level = ReadGVDirect("GOM_KOLA_" + symbol + "_H1_BUY", 0.0);
   snap.h1_sell_level = ReadGVDirect("GOM_KOLA_" + symbol + "_H1_SELL", 0.0);
   snap.h1_buy_touches = (int)ReadGVDirect("GOM_KOLA_" + symbol + "_H1_BUY_TOUCHES", 0.0);
   snap.h1_sell_touches = (int)ReadGVDirect("GOM_KOLA_" + symbol + "_H1_SELL_TOUCHES", 0.0);
}

//+------------------------------------------------------------------+
//| Helper: Collect Bollinger Bands + VWAP                           |
//+------------------------------------------------------------------+
void CollectBollingerAndVWAP(string symbol, IndicatorSnapshot &snap)
{
   snap.bb_squeeze = ReadGVDirect("BBSqueeze", 0.0) > 0;
   snap.vwap_distance_pct = ReadGVDirect("VWAPDistancePct", 0.0);
   snap.bb_pctb = ReadGVDirect("BBPercentB", 0.0);
   snap.bb_width_pct = ReadGVDirect("BBWidthPct", 0.0);
}

//+------------------------------------------------------------------+
//| Helper: Calculate Volume Ratio                                   |
//+------------------------------------------------------------------+
double CalculateVolumeRatio(string symbol)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(symbol, PERIOD_M1, 0, 50, rates) < 50) return 0.0;

   double current_vol = rates[0].tick_volume;
   double avg_vol = 0.0;

   for(int i = 1; i < 50; i++) {
      avg_vol += rates[i].tick_volume;
   }

   avg_vol /= 49.0;

   if(avg_vol == 0.0) return 0.0;
   return current_vol / avg_vol;
}

//+------------------------------------------------------------------+
//| Helper: Calculate Multi-Timeframe Coherence                      |
//+------------------------------------------------------------------+
double CalculateMultiTimeframeCoherence(string symbol)
{
   double m1_trend = 0.0, m5_trend = 0.0, m15_trend = 0.0, h1_trend = 0.0;

   // Simple trend: if fast EMA > slow EMA = bullish
   double ema_fast = CollectEMA(symbol, PERIOD_M1, 9);
   double ema_slow = CollectEMA(symbol, PERIOD_M1, 21);
   m1_trend = (ema_fast > ema_slow) ? 1.0 : -1.0;

   ema_fast = CollectEMA(symbol, PERIOD_M5, 9);
   ema_slow = CollectEMA(symbol, PERIOD_M5, 21);
   m5_trend = (ema_fast > ema_slow) ? 1.0 : -1.0;

   ema_fast = CollectEMA(symbol, PERIOD_M15, 9);
   ema_slow = CollectEMA(symbol, PERIOD_M15, 21);
   m15_trend = (ema_fast > ema_slow) ? 1.0 : -1.0;

   ema_fast = CollectEMA(symbol, PERIOD_H1, 9);
   ema_slow = CollectEMA(symbol, PERIOD_H1, 21);
   h1_trend = (ema_fast > ema_slow) ? 1.0 : -1.0;

   double all_agree = (m1_trend == m5_trend && m5_trend == m15_trend && m15_trend == h1_trend) ? 1.0 : 0.0;
   double three_agree = (MathAbs(m1_trend + m5_trend + m15_trend + h1_trend) >= 3.0) ? 0.75 : 0.5;

   if(all_agree > 0.5) return 1.0;
   return three_agree;
}

//+------------------------------------------------------------------+
//| Helper: Read Global Variable (with default)                      |
//+------------------------------------------------------------------+
double ReadGVDirect(string key, double default_value)
{
   if(!GlobalVariableCheck(key)) return default_value;
   return GlobalVariableGet(key);
}

#endif

