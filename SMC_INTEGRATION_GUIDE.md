# SMC_Universal + OTE/Divergence Integration Guide

## Overview

Integration de la stratégie **OTE+Fibonacci+Mathematical Divergence RSI** dans **SMC_Universal.mq5** pour trader les **spikes M1** avec qualité.

**Stratégies combinées:**
1. **Gold_divergence.mq5** → OTE zone (61.8%-78.6% Fibo), Mathematical divergence (dP+dQ+dR), RSI divergence detection
2. **SMC_Universal.mq5** → Smart Money Concepts, multi-asset, IA server validation, risk management
3. **New Module** → M1 Spike trading with 11-point confirmation gates

---

## Architecture

### Files
- `SMC_Divergence_OTE_Extension.mq5` — Standalone M1 divergence detection module
- `SMC_Universal.mq5` — Main robot (modified to call spike module)
- `Gold_divergence.mq5` — Reference implementation (OTE + divergence logic)

### Key Components

#### 1. M1 Divergence Detection Module (`SMC_Divergence_OTE_Extension.mq5`)
```
Functions:
├── InitM1DivergenceDetection()           — Initialize M1 indicators
├── ComputeM1Divergence()                 — Calculate div(F) = dP + dQ + dR
├── DetectM1Divergence()                  — Find RSI divergence + price bounce/pullback
├── IsInOTEZone()                         — Check if price in 61.8%-78.6% OTE zone
├── DetectFibonacciAndOTE()               — Find swing high/low + calculate OTE
├── ComputeM1ConfirmScore()               — 11-point confirmation gates
├── DrawM1OTEZoneOnChart()                — Visualize OTE zone + entry levels
└── ExecuteM1SpikeEntry()                 — Execute trade with SL/TP
```

#### 2. Integration Points in SMC_Universal.mq5

**In OnInit():**
```mql5
// Add after existing indicator initialization
if(!InitM1DivergenceDetection())
{
   Print("[ERROR] Failed to initialize M1 divergence detection");
   return INIT_FAILED;
}
```

**In OnTick():**
```mql5
// Add near end of OnTick() before dashboard update
if(UseM1SpikeStrategy)
{
   CheckAndExecuteM1SpikeWithDivergence();
}
```

**In OnDeinit():**
```mql5
// Add at end
ReleaseM1DivergenceDetection();
```

#### 3. New Input Parameters

Add to SMC_Universal.mq5 inputs:
```mql5
input group "=== M1 SPIKE STRATEGY ==="
input bool   UseM1SpikeStrategy = true;              // Enable M1 spike detection
input int    M1_LookbackBars = 20;                   // Bars for divergence calculation
input int    M1_ConfirmationMinScore = 7;            // Min gates to pass (0-11)
input double M1_SpikeLotSize = 0.01;                 // Lot size for spike trades
input int    M1_SpikeStopLossPips = 40;              // SL in pips
input int    M1_SpikeTakeProfitPips = 80;            // TP in pips
input bool   M1_ShowOTEZone = true;                  // Draw OTE on chart
input int    M1_FibonacciLookback = 50;              // Bars for swing detection
```

---

## Strategy Logic

### 1. Signal Detection Flow (M1)

```
OnTick() every 2 seconds
    ↓
ComputeM1Divergence() — Calculate:
    • dP = Rate of Change (normalized)
    • dQ = Volume Z-score
    • dR = RSI derivative
    • div(F) = dP + dQ + dR (smoothed with EMA)
    ↓
DetectFibonacciAndOTE() — Identify:
    • Swing High (latest local maximum)
    • Swing Low (latest local minimum)
    • OTE zone: 61.8%-78.6% Fibonacci retracement
    ↓
DetectM1Divergence() — Find RSI divergence:
    • BULLISH: Price < Min, RSI > Min, Price bouncing up (price0 > price1)
    • BEARISH: Price > Max, RSI < Max, Price pulling back (price0 < price1)
    ↓
ComputeM1ConfirmScore() — Pass 11-point gates:
    1. Math divergence strength (|div(F)| > 0.5)
    2. Price in OTE zone
    3. ADX trending (> 20)
    4. RSI in favorable zone
    5. Swing alignment with trend
    6. MACD histogram positive/negative
    7. MA20 alignment
    8. ATR volatility (> 0.1)
    9. Stochastic favorable zone
    10. Spread acceptable (< 3 pips)
    11. Not Asian session
    ↓
IsInOTEZone() — Check entry zone:
    • If YES → Signal ready for execution
    • If NO → Wait for price to touch OTE
    ↓
ExecuteM1SpikeEntry() — Execute market order:
    • Direction: BUY or SELL
    • Entry: Current ASK (BUY) or BID (SELL)
    • SL: 40 pips away
    • TP: 80 pips away
```

### 2. Confirmation Scoring (11 Gates)

Each gate is binary (0 or 1):

| Gate | Condition | Score |
|------|-----------|-------|
| 1 | Math Divergence \|div(F)\| > 0.5 | 1 |
| 2 | Price in OTE zone | 1 |
| 3 | ADX > 20 | 1 |
| 4 | RSI in correct zone | 1 |
| 5 | Swing/Trend aligned | 1 |
| 6 | MACD correct direction | 1 |
| 7 | Price > MA20 (BUY) or < MA20 (SELL) | 1 |
| 8 | ATR > 0.1 | 1 |
| 9 | Stochastic favorable zone | 1 |
| 10 | Spread < 3 pips | 1 |
| 11 | Not Asian session | 1 |

**Minimum to trade:** Score ≥ 7 (default)

### 3. Price Bounce/Pullback Confirmation

**Purpose:** Prevent false signals continuing in opposite direction

**Logic:**
- **BULLISH divergence:** Price makes new low but RSI doesn't → ONLY confirm if price0 > price1 (bouncing)
- **BEARISH divergence:** Price makes new high but RSI doesn't → ONLY confirm if price0 < price1 (pulling back)

**Example:**
```
Price action:  500 → 505 → 502 → 498 [NEW LOW]
RSI:           60 →  62 →  61 → 35  [BUT STILL HIGH > MIN]
Divergence:    BULLISH detected BUT price0=498 < price1=502 (not bouncing)
Result:        WAIT — no bounce yet, signal not confirmed
```

---

## Chart Visualization

### M1 OTE Zone Display
```
Chart shows:
├── Gold rectangle = OTE zone (61.8%-78.6%)
├── Green line = M1 ENTRY BUY (lower level)
├── Red line = M1 ENTRY SELL (upper level)
├── Green arrows = BULLISH spike signals
├── Red arrows = BEARISH spike signals
└── Yellow bookmarks = Entry/SL/TP levels
```

---

## Integration Steps (Detailed)

### Step 1: Add Module Functions to SMC_Universal.mq5

At the **bottom** of SMC_Universal.mq5 (before final `//+--+`), add:

```mql5
//+------------------------------------------------------------------+
//| M1 DIVERGENCE + OTE STRATEGY (Integrated from Extension Module)
//+------------------------------------------------------------------+

// [Copy all functions from SMC_Divergence_OTE_Extension.mq5]
// - InitM1DivergenceDetection()
// - ReleaseM1DivergenceDetection()
// - ComputeM1Divergence()
// - DetectM1Divergence()
// - IsInOTEZone()
// - DetectFibonacciAndOTE()
// - ComputeM1ConfirmScore()
// - DrawM1OTEZoneOnChart()
// - ExecuteM1SpikeEntry()
// - CheckAndExecuteM1SpikeWithDivergence()

// [Copy struct M1DivergenceSignal and OTEZoneInfo]
// [Copy all globals: g_m1_divScore[], g_m1_dP[], etc.]
```

### Step 2: Add Input Parameters

In `SMC_Universal.mq5` input section (after existing groups):

```mql5
input group "=== M1 SPIKE STRATEGY (NEW) ==="
input bool   UseM1SpikeStrategy = true;
input int    M1_LookbackBars = 20;
input int    M1_ConfirmationMinScore = 7;
input double M1_SpikeLotSize = 0.01;
input int    M1_SpikeStopLossPips = 40;
input int    M1_SpikeTakeProfitPips = 80;
input bool   M1_ShowOTEZone = true;
input int    M1_FibonacciLookback = 50;
```

### Step 3: Initialize in OnInit()

Find `OnInit()` and add **after** all indicator creation:

```mql5
// M1 Divergence Detection
if(!InitM1DivergenceDetection())
{
   Print("[ERROR] M1 divergence initialization failed");
   return INIT_FAILED;
}
```

### Step 4: Add Spike Check in OnTick()

Find `OnTick()` and add **before** `UpdateDashboard()`:

```mql5
// M1 Spike Trading with OTE + Divergence
if(UseM1SpikeStrategy)
{
   CheckAndExecuteM1SpikeWithDivergence();
}
```

### Step 5: Release in OnDeinit()

Find `OnDeinit()` and add **at the end**:

```mql5
// Release M1 resources
ReleaseM1DivergenceDetection();
```

### Step 6: Modify ExecuteM1SpikeEntry()

In `ExecuteM1SpikeEntry()`, replace placeholder execution with:

```mql5
// Use SMC_ExecuteMarketOrder (if available)
bool success = false;

if(signal.direction == "BUY")
{
   success = SMC_TradeBuy(M1_SpikeLotSize, entry, sl, tp, "[M1_SPIKE] OTE BUY");
}
else
{
   success = SMC_TradeSell(M1_SpikeLotSize, entry, sl, tp, "[M1_SPIKE] OTE SELL");
}

if(success)
{
   Print("[M1_SPIKE] ✓ Trade executed successfully");
   return true;
}
else
{
   Print("[M1_SPIKE] ✗ Trade execution failed");
   return false;
}
```

---

## Expected Behavior

### Console Logs (Expert Logs)
```
[M1_DIV] ★ BULLISH SPIKE | Price<Min + RSI>Min + Bounce | Conf=78.5%
[M1_SPIKE] ✓ Divergence detected: BUY @ 2345.67 | InOTE: true
[M1_SPIKE] Confirmation Score: 9/11
[M1_SPIKE] ✓ GATES PASSED - Ready for execution
[M1_SPIKE] EXECUTING BUY @ 2345.67 | SL=2341.27 | TP=2353.67 | Score=9/11
[M1_SPIKE] ✓ Trade executed successfully
```

### Dashboard Update
```
[M1 SPIKE STRATEGY]
 • Last Signal: BUY @ 2345.67
 • Confidence: 78.5%
 • Math Div: 0.642
 • In OTE: YES
 • Confirmation: 9/11 ✓
 • Last Trade: Executed 5s ago
```

---

## Testing Procedure

### 1. Compile
```
Open MT5 → Tools → MetaEditor
Open SMC_Universal.mq5
Press F7 (Compile)
Expected: 0 errors, 0 warnings
```

### 2. Attach to Chart
```
• Open XAUUSD M1 chart (or any symbol)
• Drag & drop SMC_Universal.ex5 onto chart
• Or: Right-click → Expert Advisors → Attach
• Enable "Allow automated trading"
```

### 3. Monitor Logs
```
Alt+L to open Expert Logs
Watch for M1 divergence detection messages
Look for execution logs
```

### 4. Visual Verification
```
On chart, you should see:
• Gold rectangle = OTE zone
• Green/Red lines = Entry levels
• Arrows = Divergence signals
• Bookmarks = Executed trades
```

---

## Troubleshooting

### No signals detected
- Check M1 timeframe has sufficient bars
- Verify RSI, MA, ATR indicators created correctly
- Check console for divergence computation errors
- Verify `UseM1SpikeStrategy = true`

### Signals detected but not executing
- Check confirmation score (must be ≥ 7)
- Verify account has sufficient margin
- Check `EnableAutoTrading = true`
- Look for IA validation errors (if `UseAIServer = true`)

### High number of false signals
- Increase `M1_ConfirmationMinScore` (default 7 → try 8 or 9)
- Adjust `M1_SpikeStopLossPips` higher for wider SL
- Enable `BlockAsianSession` to avoid low-liquidity times

### Spread too high
- Gate 10 checks `spread < 3 pips` — will auto-block if higher
- Trade only during major session overlap
- Use broker with tighter spreads

---

## Performance Optimization

### CPU Usage
- Divergence computation runs every 2 seconds (throttle in `CheckAndExecuteM1SpikeWithDivergence()`)
- Indicator buffers pre-sized to avoid repeated allocations
- ObjectDraw operations lightweight (only on new bars)

### Memory
- Fixed-size arrays for M1 divergence buffers (max ~200 bars)
- OTE structure lightweight (7 doubles + 2 datetimes)
- Indicator handles properly released on deinit

---

## Production Checklist

- [ ] Module compiled with 0 errors
- [ ] Input parameters configured for symbol
- [ ] IA server URLs verified (if `UseAIServer = true`)
- [ ] Initial capital set per risk management
- [ ] Risk per trade limited to account %
- [ ] Trailing stop enabled for profit protection
- [ ] Daily loss limit set
- [ ] Asian session blocking enabled (if needed)
- [ ] Notification system tested
- [ ] Live testing on demo account first

---

## Next Steps

1. **Copy module functions** to SMC_Universal.mq5
2. **Add input parameters** and spike check
3. **Test on demo chart** (XAUUSD M1 recommended)
4. **Monitor for 1-2 hours** to verify signal quality
5. **Adjust gates threshold** if needed
6. **Deploy to live account** with position size =1 lot

---

## Support

For issues:
1. Check Expert Logs for error messages
2. Verify all indicators created (check handles)
3. Confirm AI server connectivity (if used)
4. Review confirmation score (should be 7-11)
5. Test with simpler parameters first

---
