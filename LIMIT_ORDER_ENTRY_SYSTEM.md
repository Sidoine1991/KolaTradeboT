# Limit Order Entry System - Entry Levels Respect

## Overview

The robot now places **LIMIT ORDERS** at marked entry levels instead of market orders, respecting the:
- **Verdict tier requirements** (GOOD/PERFECT for M1/M5)
- **Timeframe directions** (H1 confirmation)
- **Entry level lines** (M1/M5/H1 EMA Fast displayed on chart)

---

## Entry Logic

### Condition Matrix

#### BUY Setup (OB Bullish)
```
Requirements:
✓ OB with CHOCH confirmed (bullish)
✓ M1 OR M5 bullish (EMA9 > EMA21)
✓ Score >= 0.35 (GOOD/PERFECT verdict)
✓ H1 bullish (confirms direction)

Action: Place LIMIT BUY @ EMA M1 Fast level
```

#### SELL Setup (OB Bearish)
```
Requirements:
✓ OB with CHOCH confirmed (bearish)
✓ M1 OR M5 bearish (EMA9 < EMA21)
✓ Score >= 0.35 (GOOD/PERFECT verdict)
✓ H1 bearish (confirms direction)

Action: Place LIMIT SELL @ EMA M1 Fast level
```

---

## Order Placement Details

### Limit Order Type
- **BUY**: `ORDER_TYPE_BUY_LIMIT`
- **SELL**: `ORDER_TYPE_SELL_LIMIT`

### Entry Price
- **Level**: EMA M1 Fast (9-period exponential moving average on M1)
- **Location**: Marked as green/red horizontal line on chart
- **Why**: M1 is most immediate timeframe, tight entry control

### Stop Loss
```
BUY:  SL = OB_Low - 20 pips
SELL: SL = OB_High + 20 pips
```

### Take Profit Levels (ATR-Scaled)
```
TP1 = Entry ± (ATR × 0.5)   → First partial close
TP2 = Entry ± (ATR × 1.0)   → Second partial close (saved)
TP3 = Entry ± (ATR × 1.5)   → Final close (saved)
```

### Order Properties
- **Type Filling**: IOC (Immediate Or Cancel)
- **Comment**: "LIMIT BUY @ EMA M1 | OB+OTE Setup"
- **Volume**: Calculated by GetOptimalLotSize()

---

## Verdict Tier Requirements

### Score Calculation
```
Final Score = (Confluence - 0.5) × 2.0 × 0.80 + IA_Score × 0.20

Where:
- Confluence = (M1_bull + M5_bull + H1_bull) / 3
- IA_Score = ±Confidence or 0 for HOLD
```

### Verdict Levels
| Score Range | Verdict | M1/M5 | H1 | Entry |
|---|---|---|---|---|
| \|Score\| < 0.35 | WAIT | ❌ | ❌ | No order |
| 0.35 ≤ \|Score\| < 0.65 | GOOD | ✓ | ✓ | LIMIT order |
| \|Score\| ≥ 0.65 | PERFECT | ✓ | ✓ | LIMIT order |

**Key**: M1 or M5 must reach GOOD/PERFECT for order placement

---

## Entry Timeline

```
1. OB+CHOCH Detection
   └─ Rectangle drawn on chart (blue/red)
   
2. Monitor Verdict
   └─ Dashboard shows: M1/M5 direction + H1 confirmation
   └─ Score calculated: 80% confluence + 20% IA
   
3. Check Requirements
   └─ Is M1 or M5 directionally aligned?
   └─ Is |Score| >= 0.35 (GOOD minimum)?
   └─ Does H1 confirm direction?
   
4. Place Limit Order (if all conditions met)
   └─ LIMIT BUY/SELL @ EMA M1 Fast level
   └─ SL at OB ± 20 pips
   └─ TP1 at ATR × 0.5
   └─ TP2 & TP3 saved for cascading closes
   
5. Await Fill
   └─ Price must touch EMA M1 Fast level
   └─ Order fills automatically
   └─ Position monitoring begins
   
6. Manage Position
   └─ TP1 hits → Close 33%
   └─ TP2 hits → Close 33%
   └─ TP3 hits → Close 33%
   └─ OR SL hits → Close all
```

---

## Example Trade Scenario

### Setup: PERFECT BUY Signal

```
Chart Display:
- OB Rectangle: Blue (bullish) @ 10360-10365
- EMA M1 Entry: Green line @ 10362.50
- EMA M5 Entry: Green line @ 10362.75
- EMA H1 Entry: Green line @ 10363.00

Verdict Dashboard:
- M1: ↑ (bullish)
- M5: ↑ (bullish)
- H1: ↑ (bullish)
- Score: 0.82 (PERFECT BUY)
- IA: BUY 85%

Conditions Check:
✓ M1 bullish (score 0.82)
✓ M5 bullish (score 0.82)
✓ |Score| = 0.82 >= 0.65 (PERFECT)
✓ H1 bullish (confirms)
✓ OB bullish (confirmed with CHOCH)

Action: Place LIMIT BUY

Order Details:
- Type: BUY_LIMIT
- Price: 10362.50 (EMA M1 Fast)
- SL: 10360.00 - 20 = 10340.00
- ATR: 15 pips
- TP1: 10362.50 + 7.5 = 10370.00
- TP2: 10362.50 + 15 = 10377.50
- TP3: 10362.50 + 22.5 = 10385.00

Price Action:
14:05 - Price @ 10361.50 → Waiting
14:12 - Price @ 10362.50 → ORDER FILLS ✅
14:15 - Price @ 10370.00 → TP1 HIT, close 33%
14:20 - Price @ 10377.50 → TP2 HIT, close 33%
14:25 - Price @ 10385.00 → TP3 HIT, close 33%

Result: +45 pips total profit
```

---

## Verdict Tier Filtering

### Why This Matters

**Before** (Old System):
- Any M1 direction → Market order immediately
- Could result in low-confidence entries
- Higher false signal rate

**Now** (New System):
- M1/M5 **must** show GOOD (|score| >= 0.35) or better
- H1 **must** confirm direction
- Filters out indecisive setups
- Higher quality entries, lower false signals

### Quality Improvement
```
WAIT/HOLD → No order (conf. < 35%)
GOOD BUY  → Order at EMA M1 (conf. 35-65%)
PERFECT   → Order at EMA M1 (conf. > 65%)
```

---

## Risk Management

### Order Parameters
- **Min Risk**: 20 pips (SL boundary)
- **Max Risk**: Variable (account equity based)
- **Lot Size**: Calculated by GetOptimalLotSize()

### Position Limits
- Max 5 simultaneous positions
- Max 20 trades per day
- Max $500 loss per day
- Automatic pause after max loss

---

## Monitoring & Alerts

### Journal Logs

When order is placed:
```
✅ LIMIT BUY Order Placed | Level: 10362.50
   SL: 10340.00
   TP1: 10370.00
   TP2: 10377.50
   TP3: 10385.00
```

When order fills:
```
✅ Position Opened: BUY 0.2
   Entry: 10362.50
   SL: 10340.00
```

When TP1 hits:
```
✅ TP1 Target Hit: +7.50 pips
   Close 33% (0.067 lot)
   Remaining: 0.133 lot
```

When error occurs:
```
❌ LIMIT BUY Failed: Error 123
```

---

## Configuration

### Inputs (adjustable in MT5)
```mql5
VerdictThresholdGOOD = 0.35      // Minimum for entry
VerdictThresholdPERFECT = 0.65   // Maximum threshold
```

### Fixed Parameters
- **Entry Level**: EMA M1 Fast (9-period)
- **SL Buffer**: 20 pips from OB
- **ATR Period**: 14 bars
- **Filling Type**: IOC (Immediate Or Cancel)

---

## Advantages Over Market Orders

1. **Better Price**: Wait for optimal level (EMA M1)
2. **Verdict Protection**: Requires GOOD/PERFECT for M1/M5
3. **H1 Confirmation**: Filters directional conflicts
4. **Selective**: Avoids low-confidence setups
5. **Automated**: No manual intervention needed
6. **Logging**: Full traceability of all orders

---

## Status

✅ **Implementation Complete**
- Limit order placement logic: Active
- Verdict tier filtering: Active
- Entry level respect: Active
- Multi-TP system: Ready
- Logging: Complete

Generated: 2026-05-17
Function: CheckAndExecuteOTEEntry()
Type: Limit Order Entry System
