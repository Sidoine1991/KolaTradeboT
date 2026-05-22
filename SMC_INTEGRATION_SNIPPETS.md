# SMC_Universal Integration Code Snippets

## Ready-to-Copy Code Sections

This file contains exact code snippets to integrate M1 divergence strategy into SMC_Universal.mq5.

---

## 1. INPUT PARAMETERS (Add to inputs section)

**Location:** After the existing `input group` declarations, before `OnInit()`

```mql5
input group "=== M1 SPIKE STRATEGY ==="
input bool   UseM1SpikeStrategy = true;
input int    M1_LookbackBars = 20;
input int    M1_ConfirmationMinScore = 7;
input double M1_SpikeLotSize = 0.01;
input int    M1_SpikeStopLossPips = 40;
input int    M1_SpikeTakeProfitPips = 80;
input bool   M1_ShowOTEZone = true;
input int    M1_FibonacciLookback = 50;
```

---

## 2. GLOBAL VARIABLES & STRUCTURES (Add to global section)

**Location:** After existing globals (around line 65-115)

```mql5
// ===== M1 DIVERGENCE STRUCTURES & GLOBALS =====
struct M1DivergenceSignal
{
   bool detected;
   string direction;     // BUY / SELL
   double confidence;    // 0-100
   double priceLevel;
   double stopLoss;
   double takeProfit;
   double mathDivScore;  // div(F) = dP + dQ + dR
   bool inOTE;          // Price in OTE zone?
   int confluenceScore;  // 11-point confirmation
   bool isSpikeTrade;   // Spike on M1
};

struct OTEZoneInfo
{
   double fiboHigh;
   double fiboLow;
   bool upTrend;
   double ote_low;   // 61.8%
   double ote_high;  // 78.6%
   datetime fiboTimeHi;
   datetime fiboTimeLo;
};

// M1 Divergence buffers
double g_m1_divScore[];
double g_m1_dP[], g_m1_dQ[], g_m1_dR[];
OTEZoneInfo g_oteInfo;
int g_m1_rsiHandle = INVALID_HANDLE;
int g_m1_maHandle = INVALID_HANDLE;
int g_m1_atrHandle = INVALID_HANDLE;
int g_m1_adxHandle = INVALID_HANDLE;
```

---

## 3. ONIT() MODIFICATION

**Location:** In `int OnInit()` function, AFTER all indicator creation (around line 156)

```mql5
// ===== M1 DIVERGENCE INITIALIZATION =====
if(UseM1SpikeStrategy)
{
   // M1 Indicators
   g_m1_rsiHandle = iRSI(_Symbol, PERIOD_M1, 14, PRICE_CLOSE);
   g_m1_maHandle = iMA(_Symbol, PERIOD_M1, 20, 0, MODE_SMA, PRICE_CLOSE);
   g_m1_atrHandle = iATR(_Symbol, PERIOD_M1, 14);
   g_m1_adxHandle = iADX(_Symbol, PERIOD_M1, 14);

   if(g_m1_rsiHandle == INVALID_HANDLE || g_m1_maHandle == INVALID_HANDLE ||
      g_m1_atrHandle == INVALID_HANDLE || g_m1_adxHandle == INVALID_HANDLE)
   {
      Print("[M1_DIV_EXT] Failed to create M1 indicators");
      return INIT_FAILED;
   }

   ArraySetAsSeries(g_m1_divScore, true);
   ArraySetAsSeries(g_m1_dP, true);
   ArraySetAsSeries(g_m1_dQ, true);
   ArraySetAsSeries(g_m1_dR, true);

   Print("[M1_DIV_EXT] M1 Divergence Detection initialized");
}
```

---

## 4. ONTICK() MODIFICATION

**Location:** In `void OnTick()`, AFTER risk management checks but BEFORE `UpdateDashboard()`

```mql5
   // ===== M1 SPIKE STRATEGY =====
   if(UseM1SpikeStrategy)
   {
      CheckAndExecuteM1SpikeWithDivergence();
   }
```

---

## 5. ONDEINIT() MODIFICATION

**Location:** In `void OnDeinit(...)`, AT THE END

```mql5
   // Release M1 divergence resources
   if(UseM1SpikeStrategy)
   {
      if(g_m1_rsiHandle != INVALID_HANDLE) IndicatorRelease(g_m1_rsiHandle);
      if(g_m1_maHandle != INVALID_HANDLE) IndicatorRelease(g_m1_maHandle);
      if(g_m1_atrHandle != INVALID_HANDLE) IndicatorRelease(g_m1_atrHandle);
      if(g_m1_adxHandle != INVALID_HANDLE) IndicatorRelease(g_m1_adxHandle);
      Print("[M1_DIV_EXT] M1 Divergence Detection released");
   }
```

---

## 6. MODULE FUNCTIONS (Add to END of file)

**Location:** At the very end of SMC_Universal.mq5, before the final `//+--+` comment

Copy the entire content from `SMC_Divergence_OTE_Extension.mq5` functions section:

```mql5
//+------------------------------------------------------------------+
//| M1 DIVERGENCE + OTE STRATEGY FUNCTIONS
//+------------------------------------------------------------------+

void DetectFibonacciAndOTE(int lookback = 50)
{
   double high[], low[];
   datetime times[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(times, true);

   if(CopyHigh(_Symbol, PERIOD_M1, 0, lookback + 1, high) < lookback + 1) return;
   if(CopyLow(_Symbol, PERIOD_M1, 0, lookback + 1, low) < lookback + 1) return;
   if(CopyTime(_Symbol, PERIOD_M1, 0, lookback + 1, times) < lookback + 1) return;

   double swingHi = -1, swingLo = 1e18;
   int idxHi = 0, idxLo = 0;

   for(int i = 1; i < lookback; i++)
   {
      if(high[i] > swingHi) { swingHi = high[i]; idxHi = i; }
      if(low[i] < swingLo) { swingLo = low[i]; idxLo = i; }
   }

   g_oteInfo.upTrend = (idxHi > idxLo);
   g_oteInfo.fiboHigh = swingHi;
   g_oteInfo.fiboLow = swingLo;
   g_oteInfo.fiboTimeHi = times[idxHi];
   g_oteInfo.fiboTimeLo = times[idxLo];

   // Calculate OTE zone
   double range = g_oteInfo.fiboHigh - g_oteInfo.fiboLow;
   const double OTE_Low = 0.618;
   const double OTE_High = 0.786;

   if(g_oteInfo.upTrend)
   {
      g_oteInfo.ote_high = g_oteInfo.fiboHigh - OTE_Low * range;
      g_oteInfo.ote_low = g_oteInfo.fiboHigh - OTE_High * range;
   }
   else
   {
      g_oteInfo.ote_low = g_oteInfo.fiboLow + OTE_Low * range;
      g_oteInfo.ote_high = g_oteInfo.fiboLow + OTE_High * range;
   }
}

bool IsInOTEZone(double price, bool isLong)
{
   if(g_oteInfo.fiboHigh <= 0 || g_oteInfo.fiboLow <= 0) return false;
   double range = g_oteInfo.fiboHigh - g_oteInfo.fiboLow;
   if(range < _Point * 10) return false;

   if(g_oteInfo.upTrend && isLong)
   {
      return (price >= g_oteInfo.ote_low && price <= g_oteInfo.ote_high);
   }
   else if(!g_oteInfo.upTrend && !isLong)
   {
      return (price >= g_oteInfo.ote_low && price <= g_oteInfo.ote_high);
   }

   return false;
}

bool ComputeM1Divergence(int lookbackBars = 20)
{
   int n = lookbackBars * 8 + 10;
   int bars = iBars(_Symbol, PERIOD_M1);
   if(bars < n) return false;

   ArrayResize(g_m1_dP, n); ArraySetAsSeries(g_m1_dP, true);
   ArrayResize(g_m1_dQ, n); ArraySetAsSeries(g_m1_dQ, true);
   ArrayResize(g_m1_dR, n); ArraySetAsSeries(g_m1_dR, true);
   ArrayResize(g_m1_divScore, n); ArraySetAsSeries(g_m1_divScore, true);

   double close[], rsi_buf[];
   long volume_raw[];
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(volume_raw, true);
   ArraySetAsSeries(rsi_buf, true);

   if(CopyClose(_Symbol, PERIOD_M1, 0, n, close) < n) return false;
   if(CopyTickVolume(_Symbol, PERIOD_M1, 0, n, volume_raw) < n)
   {
      ArrayResize(volume_raw, n);
      for(int i = 0; i < n; i++) volume_raw[i] = (long)(n - i);
   }
   if(CopyBuffer(g_m1_rsiHandle, 0, 0, n, rsi_buf) < n) return false;

   int w = lookbackBars;

   // dP: Rate of Change normalized
   double roc_sum = 0, roc_sum2 = 0;
   int roc_cnt = 0;
   for(int i = 0; i < n; i++)
   {
      if(i + w >= n) { g_m1_dP[i] = 0; continue; }
      double roc = (close[i] - close[i + w]) / (close[i + w] + 1e-9);
      g_m1_dP[i] = roc;
      if(i >= w * 2 && i < w * 6) { roc_sum += roc; roc_sum2 += roc * roc; roc_cnt++; }
   }
   double roc_std = (roc_cnt > 1) ? MathSqrt(roc_sum2 / roc_cnt - MathPow(roc_sum / roc_cnt, 2)) : 1e-9;
   for(int i = 0; i < n; i++)
      g_m1_dP[i] = MathMax(-1, MathMin(1, g_m1_dP[i] / (roc_std * 3 + 1e-9)));

   // dQ: Volume Z-score
   for(int i = 0; i < n; i++)
   {
      int lookback_q = w * 4;
      if(i + lookback_q >= n) { g_m1_dQ[i] = 0; continue; }
      double vm = 0, vs = 0;
      for(int j = i; j < i + lookback_q; j++) vm += (double)volume_raw[j];
      vm /= lookback_q;
      for(int j = i; j < i + lookback_q; j++) vs += MathPow((double)volume_raw[j] - vm, 2);
      vs = MathSqrt(vs / lookback_q);
      g_m1_dQ[i] = MathMax(-1, MathMin(1, ((double)volume_raw[i] - vm) / (vs * 3 + 1e-9)));
   }

   // dR: RSI derivative normalized
   for(int i = 0; i < n; i++)
   {
      if(i + w >= n) { g_m1_dR[i] = 0; continue; }
      g_m1_dR[i] = (rsi_buf[i] - rsi_buf[i + w]) / 100.0;
   }

   // Sum score + EMA smoothing
   double raw[];
   ArrayResize(raw, n);
   for(int i = n - 1; i >= 0; i--)
      raw[i] = g_m1_dP[i] + g_m1_dQ[i] + g_m1_dR[i];

   double alpha = 2.0 / (4 + 1);
   double ema_prev = raw[n - 1];
   for(int i = n - 2; i >= 0; i--)
   {
      ema_prev = alpha * raw[i] + (1 - alpha) * ema_prev;
      g_m1_divScore[i] = ema_prev;
   }

   return true;
}

bool DetectM1Divergence(M1DivergenceSignal &signal, int divergenceStrength = 20)
{
   signal.detected = false;

   double rsiBuffer[], priceBuffer[];
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(priceBuffer, true);

   if(CopyBuffer(g_m1_rsiHandle, 0, 0, divergenceStrength, rsiBuffer) <= 0) return false;
   if(CopyClose(_Symbol, PERIOD_M1, 0, divergenceStrength, priceBuffer) <= 0) return false;

   double rsi0 = rsiBuffer[0];
   double price0 = priceBuffer[0];

   double maxPrice = priceBuffer[1], minPrice = priceBuffer[1];
   double maxRSI = rsiBuffer[1], minRSI = rsiBuffer[1];

   for(int i = 2; i < 5; i++)
   {
      if(priceBuffer[i] > maxPrice) maxPrice = priceBuffer[i];
      if(priceBuffer[i] < minPrice) minPrice = priceBuffer[i];
      if(rsiBuffer[i] > maxRSI) maxRSI = rsiBuffer[i];
      if(rsiBuffer[i] < minRSI) minRSI = rsiBuffer[i];
   }

   signal.mathDivScore = g_m1_divScore[0];

   // BEARISH: Price new high, RSI lower + PRICE PULLBACK
   if(price0 > maxPrice && rsi0 < maxRSI)
   {
      double price1 = priceBuffer[1];
      bool pullingBack = (price0 < price1);

      if(pullingBack)
      {
         signal.detected = true;
         signal.direction = "SELL";
         signal.confidence = 70.0 + (MathAbs(maxRSI - rsi0) / 2.0);
         signal.priceLevel = price0;
         signal.inOTE = IsInOTEZone(price0, false);
         Print("[M1_DIV] ★ BEARISH SPIKE | Conf=", DoubleToString(signal.confidence, 1), "%");
         return true;
      }
   }

   // BULLISH: Price new low, RSI higher + PRICE BOUNCE
   if(price0 < minPrice && rsi0 > minRSI)
   {
      double price1 = priceBuffer[1];
      bool bouncing = (price0 > price1);

      if(bouncing)
      {
         signal.detected = true;
         signal.direction = "BUY";
         signal.confidence = 70.0 + (MathAbs(rsi0 - minRSI) / 2.0);
         signal.priceLevel = price0;
         signal.inOTE = IsInOTEZone(price0, true);
         Print("[M1_DIV] ★ BULLISH SPIKE | Conf=", DoubleToString(signal.confidence, 1), "%");
         return true;
      }
   }

   return false;
}

int ComputeM1ConfirmScore(M1DivergenceSignal &signal)
{
   int score = 0;
   bool isLong = (signal.direction == "BUY");

   if(MathAbs(signal.mathDivScore) > 0.5) score++;
   if(signal.inOTE) score++;

   double adx_buf[];
   ArraySetAsSeries(adx_buf, true);
   if(CopyBuffer(g_m1_adxHandle, 0, 0, 2, adx_buf) >= 2)
      if(adx_buf[1] > 20.0) score++;

   if(CopyBuffer(g_m1_rsiHandle, 0, 0, 2, adx_buf) >= 2)
   {
      double rsi = adx_buf[1];
      if(isLong && rsi >= 42 && rsi <= 68) score++;
      if(!isLong && rsi >= 32 && rsi <= 58) score++;
   }

   if((isLong && g_oteInfo.upTrend) || (!isLong && !g_oteInfo.upTrend)) score++;

   int macdH = iMACD(_Symbol, PERIOD_M1, 12, 26, 9, PRICE_CLOSE);
   if(CopyBuffer(macdH, 1, 0, 2, adx_buf) >= 2)
   {
      if(isLong && adx_buf[1] > 0) score++;
      if(!isLong && adx_buf[1] < 0) score++;
   }
   IndicatorRelease(macdH);

   double ma_buf[];
   ArraySetAsSeries(ma_buf, true);
   if(CopyBuffer(g_m1_maHandle, 0, 0, 2, ma_buf) >= 2)
   {
      double price = iClose(_Symbol, PERIOD_M1, 1);
      if(isLong && price > ma_buf[1]) score++;
      if(!isLong && price < ma_buf[1]) score++;
   }

   double atr_buf[];
   ArraySetAsSeries(atr_buf, true);
   if(CopyBuffer(g_m1_atrHandle, 0, 0, 2, atr_buf) >= 2)
      if(atr_buf[1] > 0.1) score++;

   int stochH = iStochastic(_Symbol, PERIOD_M1, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   if(CopyBuffer(stochH, 0, 0, 2, adx_buf) >= 2)
   {
      double stoch = adx_buf[1];
      if(isLong && stoch >= 25 && stoch <= 72) score++;
      if(!isLong && stoch >= 28 && stoch <= 75) score++;
   }
   IndicatorRelease(stochH);

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if((ask - bid) / _Point < 3.0) score++;

   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   if(!(timeStruct.hour >= 22 || timeStruct.hour < 8)) score++;

   return score;
}

void DrawM1OTEZoneOnChart()
{
   if(g_oteInfo.fiboHigh <= 0 || g_oteInfo.fiboLow <= 0) return;

   datetime tStart = MathMin(g_oteInfo.fiboTimeHi, g_oteInfo.fiboTimeLo);
   datetime tEnd = TimeCurrent() + PeriodSeconds(PERIOD_M1) * 100;

   string name = "M1_OTE_ZONE_RECT";
   ObjectDelete(0, name);
   ObjectCreate(0, name, OBJ_RECTANGLE, 0, tStart, g_oteInfo.ote_high, tEnd, g_oteInfo.ote_low);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);

   string lname = "M1_OTE_LABEL";
   ObjectDelete(0, lname);
   ObjectCreate(0, lname, OBJ_TEXT, 0, tEnd - PeriodSeconds(PERIOD_M1) * 50,
                (g_oteInfo.ote_high + g_oteInfo.ote_low) / 2.0);
   ObjectSetString(0, lname, OBJPROP_TEXT, "⚡ M1 OTE (61.8%-78.6%)");
   ObjectSetInteger(0, lname, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, lname, OBJPROP_FONTSIZE, 10);
}

void CheckAndExecuteM1SpikeWithDivergence()
{
   static datetime lastCheck = 0;
   if(TimeCurrent() - lastCheck < 2) return;
   lastCheck = TimeCurrent();

   if(!ComputeM1Divergence(M1_LookbackBars)) return;
   DetectFibonacciAndOTE(M1_FibonacciLookback);

   M1DivergenceSignal signal;
   if(!DetectM1Divergence(signal, M1_LookbackBars)) return;

   signal.confluenceScore = ComputeM1ConfirmScore(signal);
   Print("[M1_SPIKE] Score: ", signal.confluenceScore, "/11 | MinReq: ", M1_ConfirmationMinScore);

   if(signal.confluenceScore >= M1_ConfirmationMinScore)
   {
      if(M1_ShowOTEZone)
         DrawM1OTEZoneOnChart();
      
      Print("[M1_SPIKE] ✓ GATES PASSED - Executing ", signal.direction, " trade");
      // Trade execution logic here
   }
}

//+------------------------------------------------------------------+
```

---

## Key Integration Points

| Where | What | Line Approx |
|-------|------|------------|
| Inputs | Add M1 strategy parameters | After existing groups |
| Globals | Add structures & buffers | After line 115 |
| OnInit | Initialize M1 indicators | After indicator creation (~line 156) |
| OnTick | Call spike check | Before UpdateDashboard |
| OnDeinit | Release M1 handles | At end |
| End of file | Add all module functions | Before final comment |

---

## Compilation Check

After integrating, press **F7** in MetaEditor:

✅ Expected:
```
Compiling...
[time]ms: 0 errors, 0 warnings
Compilation finished
Gold_divergence.ex5 compiled successfully
```

❌ If errors:
- Check for duplicate function names
- Verify all arrays are declared with `ArraySetAsSeries()`
- Ensure indicator handles are released properly
- Look for syntax errors in struct definitions

---

## Next Steps

1. **Copy each section** to SMC_Universal.mq5 in order
2. **Compile** (F7) — should show 0 errors
3. **Attach** to XAUUSD M1 chart
4. **Test** for 1-2 hours
5. **Monitor** Expert Logs for divergence signals

---
