# Divergence Robot v2.0 + GOM Integration

**Date**: 2026-05-22  
**Status**: Complete Implementation  
**Strategy**: Divergence Trading v5 + Multi-TF GOM Entry Levels

---

## Overview

The Divergence Robot combines vectorial divergence field analysis with multi-timeframe GOM (Golden Opportunity Moments) entry level detection. It detects market divergences, Order Blocks, and SIDO patterns to scalp entries at optimal levels.

**Key Features:**
- ✅ Divergence signal calculation (price momentum + volume anomaly + RSI derivative)
- ✅ Multi-timeframe GOM level detection (M1, M5, M15, M30, H1)
- ✅ Order Block (OB) detection with body % confirmation
- ✅ SIDO pattern recognition (Double Top/Bottom)
- ✅ Touch-based level confirmation system
- ✅ Trailing stops + daily trade caps + position management
- ✅ Python backend integration for real-time divergence scoring

---

## Strategy Parameters

### Divergence Configuration (v5)

| Parameter | Default | Description |
|-----------|---------|-------------|
| `DivWindow` | 5 | Lookback bars for divergence calculation |
| `DivThreshold` | 0.18 | Minimum divergence threshold (normalized) |
| `SLMultiplier` | 1.4 | ATR multiplier for stop loss |
| `TPMultiplier` | 2.5 | ATR multiplier for take profit |
| `ConfluenceMin` | 3 | Minimum confluence score to execute |
| `TrailFactor` | 1.3 | ATR multiplier for trailing stop |
| `MaxHoldBars` | 10 | Maximum bars to hold position |

### Risk Management

| Parameter | Default | Description |
|-----------|---------|-------------|
| `RiskPercent` | 1.2 | % of capital per trade |
| `MaxCapital` | 10000 | Base trading capital |
| `MaxPositionsAllowed` | 3 | Concurrent position limit |
| `MaxTradesPerDay` | 5 | Daily trade execution cap |
| `MaxDailyLossPercent` | 5.0 | Daily loss limit before shutdown |

### GOM Entry Levels

| Parameter | Default | Description |
|-----------|---------|-------------|
| `EnableGOMEntryLevels` | true | Multi-TF entry level detection |
| `ShowM1Levels` | true | Enable M1 level scanning |
| `ShowM5Levels` | true | Enable M5 level scanning |
| `ShowM15Levels` | true | Enable M15 level scanning |
| `ShowM30Levels` | false | Enable M30 level scanning |
| `ShowH1Levels` | true | Enable H1 level scanning |

### Touch Detection System

| Parameter | Default | Description |
|-----------|---------|-------------|
| `EnableTouchDetection` | true | Activate touch-based confirmation |
| `TouchZoneATRPercent` | 25.0 | Touch zone size (% of ATR) |
| `BarsForTouchCount` | 150 | Bars to analyze for touches |
| `TouchesForMaxWidth` | 8 | Touches needed for "strong" level |

### Order Block Detection

| Parameter | Default | Description |
|-----------|---------|-------------|
| `EnableOrderBlockDetection` | true | OB scanning active |
| `OBLookbackBars` | 50 | Bars to scan for OB |
| `OBMinBodyPercent` | 0.4 | Minimum candle body size (40% of range) |

### SIDO Pattern Detection

| Parameter | Default | Description |
|-----------|---------|-------------|
| `EnableSIDO` | true | SIDO pattern detection active |
| `SIDOPivotLookback` | 3 | Pivot lookback for pattern detection |
| `SIDOBarsToAnalyze` | 300 | Bars to scan for patterns |
| `SIDOToleranceATRPercent` | 35.0 | Tolerance for level matching (% ATR) |

---

## How It Works

### 1. Divergence Signal Calculation

The robot calculates a vectorial divergence field with three components:

```
div F = dP/dx + dQ/dy + dR/dz

where:
  dP/dx = Rate of Change (price momentum)
  dQ/dy = Z-score of volume (volume anomaly)
  dR/dz = RSI derivative (momentum confirmation)
```

**Confluence Scoring** (each +1 for signal strength):
1. **Price Momentum**: If |ROC| > DivThreshold → +1 score, +25% confidence
2. **RSI Divergence**: If RSI > 70 + negative ROC → SELL (+20%), or RSI < 30 + positive ROC → BUY (+20%)
3. **Volume Confirmation**: If volume anomaly > DivThreshold → +1 score, +15%
4. **Trend Alignment**: If price > EMA(12) > EMA(26) → BUY (+15%), else → SELL

**Entry Criteria**:
- Confluence score ≥ ConfluenceMin (3)
- Confidence ≥ 50%

### 2. GOM Entry Level Detection

For each enabled timeframe (M1 through H1):

1. **Pivot Detection**: Scan for local highs/lows over BarsForTouchCount
2. **Touch Counting**: Count touches within TouchZoneATRPercent of level
3. **Level Strength**: Level with 2+ touches is added to GOM pool
4. **Entry Selection**: When signal detected, use nearest GOM level in direction

**Entry Level Priority**:
- M5 GOM level (most preferred)
- M1 GOM level (fallback)
- M15/M30/H1 GOM level (if available)
- Current price (last resort)

### 3. Order Block Detection

Scans for rejection candles indicating order block formation:

**BUY Order Block**:
```
1. Prior candle closes DOWN
2. Current candle closes UP (rejection)
3. Candle body ≥ OBMinBodyPercent of total range
```

**SELL Order Block**:
```
1. Prior candle closes UP
2. Current candle closes DOWN (rejection)
3. Candle body ≥ OBMinBodyPercent of total range
```

Price touching OB level acts as entry confirmation (optional integration).

### 4. SIDO Pattern Detection

Scans for chart figure (Chartist) patterns:

**DOUBLE TOP** (bearish reversal):
```
- Two peaks within SIDOToleranceATRPercent tolerance
- Neckline support below both peaks
```

**DOUBLE BOTTOM** (bullish reversal):
```
- Two troughs within SIDOToleranceATRPercent tolerance
- Neckline resistance above both troughs
```

Patterns displayed on chart for trader confirmation; signals remain independent.

### 5. Position Management

**Trailing Stops**:
```
if (UseTrailingStop) {
    For BUY: newSL = Bid - ATR * TrailFactor
    For SELL: newSL = Ask + ATR * TrailFactor
    Apply if improves SL
}
```

**Position Exit Triggers**:
- Maximum hold time: MaxHoldBars
- Daily loss: 2% of capital
- Daily trade cap: MaxTradesPerDay reached
- Trailing stop hit

---

## API Integration (ai_server.py)

### POST /divergence/signal

Calculates divergence signal from live candle data.

**Request**:
```json
{
  "symbol": "EURUSD",
  "candles": [
    {"o": 1.0850, "h": 1.0860, "l": 1.0840, "c": 1.0855, "v": 1000},
    ...
  ],
  "lookback": 5,
  "threshold": 0.18,
  "confluence_min": 3
}
```

**Response**:
```json
{
  "ok": true,
  "symbol": "EURUSD",
  "direction": "BUY",
  "confidence": 87.5,
  "divergence_score": 4,
  "entry_price": 1.0855,
  "stop_loss": 1.0830,
  "take_profit": 1.0900,
  "reason": "Score 4, Price ROC 0.0245, Vol Anom 1.35, RSI 72.3"
}
```

### GET /divergence/stats

Returns strategy statistics and optimal parameters.

**Response**:
```json
{
  "ok": true,
  "symbol": "EURUSD",
  "strategy": "Divergence v5",
  "params": {
    "w": 5,
    "div_t": 0.18,
    "sl_m": 1.4,
    "tp_m": 2.5,
    "cm": 3,
    "tr_f": 1.3,
    "max_hold": 10
  },
  "metrics": {
    "sharpe": 0.85,
    "win_rate": 0.424,
    "profit_factor": 1.05,
    "trades_per_day": 3.2,
    "max_drawdown": -0.19
  }
}
```

---

## Dashboard Display

Real-time dashboard shows:

```
═ DIVERGENCE ROBOT v2.0 + GOM ═
Strategy: Divergence v5 + Multi-TF GOM
Timeframe: H1 Entry | M1-H1 GOM Levels
───────────────────────────────────
Positions: 1/3
Trades Today: 2/5

Last Signal: BUY @ 1.0855
Confidence: 87.5%
Score: 4/3

GOM Entry: 1.0850 (M5)
Active GOM Levels: 12
Order Block: BUY [1.0840-1.0860]
SIDO Pattern: DOUBLE_BOTTOM
```

---

## Trading Example

### Scenario: EURUSD, 14:30 UTC

```
Step 1: Divergence Detection
  → Price ROC: +2.45% (above threshold 0.18)
  → RSI: 72.3 (> 70), but ROC positive → no SELL signal yet
  → Volume spike: +35% (above threshold)
  → Trend: Close > EMA(12) > EMA(26)
  → Confluence: 4/3 ✓
  → Confidence: 87.5% ✓

Step 2: GOM Entry Level
  → Scan M1-H1 for support/resistance
  → M5 touch level found: 1.0850 (5 touches in 2 hours)
  → Current price: 1.0855
  → Use M5 level as entry

Step 3: Order Block Check
  → Scan last 50 bars for OB
  → BUY OB detected: [1.0840 - 1.0860]
  → Current price in OB range → Confirmation ✓

Step 4: Calculate SL/TP
  → ATR(14) = 0.00150
  → SL = 1.0855 - 0.00150 * 1.4 = 1.0834 ❌ Too close to OB low
  → TP = 1.0855 + 0.00150 * 2.5 = 1.0893

Step 5: Execute
  → Lot size = risk_pct * capital / (entry - SL) = 1.2% * 10000 / 21 pips ≈ 0.057 lot
  → 🚀 BUY 0.057 @ 1.0850 SL=1.0834 TP=1.0893

Step 6: Monitoring
  → Trail stop: newSL = Bid - ATR * 1.3 (if improves)
  → Timeout: Close after 10 bars if open
  → Daily cap: Stop at 5 trades executed

Step 7: Exit
  → TP hit @ 1.0893 → +43 pips gross profit
  → Close: 0.057 * 43 * ~10/point value ≈ +$20+ USD profit (risk-reward 2.5R)
```

---

## Expected Performance

Based on divergence_v5_production.py parameters:

| Metric | Value | Notes |
|--------|-------|-------|
| Sharpe Ratio | 0.85 | Risk-adjusted returns |
| Win Rate | 42.4% | % of profitable trades |
| Profit Factor | 1.05 | Gross profit / Gross loss |
| Avg Trades/Day | 3.2 | Activity level |
| Max Drawdown | -19.0% | Worst consecutive loss |
| Capital | $10,000 | Base trading capital |
| Risk/Trade | 1.2% | Per-trade risk limit |

**Expected Monthly** (260 trading days):
- ~26 signals detected (3.2 * 8 trading hours average)
- ~11 profitable trades, ~15 losses
- Net: +1.05 PF → ~5% monthly return target

---

## Troubleshooting

### "No GOM levels detected"

**Cause**: Insufficient touches or levels outside tolerance  
**Fix**:
1. Increase `BarsForTouchCount` to 200-300
2. Increase `TouchZoneATRPercent` to 35-40
3. Check symbol has adequate liquidity

### "Order executes but SL too tight"

**Cause**: ATR too low or SLMultiplier too aggressive  
**Fix**:
1. Increase `SLMultiplier` to 1.8-2.0
2. Add minimum SL distance check
3. Wait for higher volatility environment

### "Position closes immediately"

**Cause**: MaxHoldBars reached or daily trade cap hit  
**Fix**:
1. Increase `MaxHoldBars` to 15-20
2. Increase `MaxTradesPerDay` to 8-10
3. Check daily loss tracking

### "SIDO pattern shows but divergence doesn't trigger"

**Cause**: SIDO is independent confirmation; requires divergence score ≥ ConfluenceMin  
**Fix**: SIDO acts as bonus signal, not primary trigger. Divergence score must reach 3 independently.

---

## Files

| File | Purpose |
|------|---------|
| `Divergence_Robot_With_GOM.mq5` | Main EA strategy |
| `divergence_v5_production.py` | Reference parameters |
| `ai_server.py` | Backend endpoints (/divergence/signal, /divergence/stats) |

---

## Compilation & Deployment

### MQL5 Compilation

```bash
# In MetaTrader 5:
1. File → Open Data Folder
2. MQL5 → Experts
3. Copy Divergence_Robot_With_GOM.mq5
4. Tools → Compile → F7
```

**Expected output**: 0 errors, 0 warnings

### Python Backend

```bash
# Ensure ai_server.py includes divergence endpoints:
cd /d D:\Dev\TradBOT
python ai_server.py --port 8000
```

Test endpoint:
```bash
curl -X POST http://localhost:8000/divergence/signal \
  -H "Content-Type: application/json" \
  -d '{
    "symbol": "EURUSD",
    "candles": [...],
    "lookback": 5,
    "threshold": 0.18
  }'
```

---

## Summary

The Divergence Robot v2.0 brings together:

✅ **Vectorial divergence analysis** — Price momentum + volume + RSI  
✅ **Multi-timeframe GOM entry** — Scalp at optimal S/R levels  
✅ **Order Block detection** — Institutional supply/demand zones  
✅ **SIDO pattern recognition** — Chartist figure confirmation  
✅ **Python backend** — Real-time divergence scoring via API  
✅ **Risk management** — Trailing stops, daily caps, position limits  

**Result**: Intelligent divergence-based scalping with confluence-driven entry signals. 🎯

---

**Support**: Check logs for full execution details.  
**Last Updated**: 2026-05-22

