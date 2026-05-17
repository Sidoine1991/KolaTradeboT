# OTE Entry System - Complete Setup

## System Overview

The robot now combines **Fibonacci Retracement**, **Order Block confirmation with CHOCH**, and **OTE (Optimal Trade Entry)** to execute trades with precise risk management.

---

## Components

### 1. **Fibonacci Retracement (Displayed)**
- **Levels**: 0%, 23.6%, 38.2%, 50%, 61.8% (OTE), 78.6% (OTE), 100%
- **Colors**: 
  - 61.8% = Orange (solid line, thick)
  - 78.6% = Orange Red (solid line, thick)
  - Others = Dashed lines
- **Purpose**: Visual guide for OTE zones

### 2. **Order Block + CHOCH Detection**
- **OB Detection**: Identifies block formation (swing high/low range)
- **CHOCH Confirmation**: Confirms with Break of Structure
  - **Bullish CHOCH**: New swing high > previous swing high
  - **Bearish CHOCH**: New swing low < previous swing low
- **Display**: One blue rectangle (bullish) or red rectangle (bearish)
- **Stored**: `g_confirmedOB` global variable

### 3. **OTE Entry Trigger**
- **Condition**: Price enters 61.8%-78.6% Fibonacci zone
- **Confirmation**: OB + CHOCH already detected
- **Entry Price**: 
  - BUY: Ask price when entering upper OTE zone
  - SELL: Bid price when entering lower OTE zone

### 4. **Risk Management (SL + Multi-TP)**

#### Stop Loss (SL)
```
Bullish: SL = OB low - 20 pips
Bearish: SL = OB high + 20 pips
```

#### Take Profit Levels
- **TP1**: ATR × 0.5 (first partial close)
- **TP2**: ATR × 1.0 (second partial close) [saved in `g_lastTP2`]
- **TP3**: ATR × 1.5 (full close) [saved in `g_lastTP3`]

---

## Execution Flow

```
1. OnTick() every millisecond
   ↓
2. DrawConfirmedOBWithCHOCH()
   - Scan last 80 bars for CHOCH pattern
   - If found: Draw OB rectangle, store in g_confirmedOB
   ↓
3. CheckAndExecuteOTEEntry()
   - Check if g_confirmedOB is valid (CHOCH confirmed)
   - If price in Fib 61.8%-78.6% zone:
     * Calculate SL, TP1, TP2, TP3
     * Execute trade.Buy() or trade.Sell()
     * Log: Entry, SL, TP1, TP2, TP3
     * Save TP2, TP3 for cascading closes
   ↓
4. Position Management
   - TP1 hits → Close 33% (automatic)
   - TP2 hits → Close 33% (manual via g_lastTP2)
   - TP3 hits → Close 33% (manual via g_lastTP3)
   OR
   - SL hits → Close all (automatic)
```

---

## Code Functions

### DrawConfirmedOBWithCHOCH()
- Scans last 80 bars for CHOCH pattern
- Draws single OB rectangle if confirmed
- Stores data in `g_confirmedOB`

### DetectConfirmedOBWithCHOCH()
- Returns `true` if CHOCH detected (break of structure)
- Bullish: `rates[i].close > rates[i+1].high`
- Bearish: `rates[i].close < rates[i+1].low`

### CheckAndExecuteOTEEntry()
- Monitors Fibonacci 61.8%-78.6% zone
- Triggers entry when price enters zone + OB confirmed
- Calculates and logs all levels
- Executes trade with multi-TP system

---

## Global Variables

```mql5
OrderBlockData g_confirmedOB;  // Current confirmed OB
double g_lastTP2 = 0;         // TP2 price for partial close
double g_lastTP3 = 0;         // TP3 price for final close
```

---

## Visual Display on Chart

1. **Fibonacci Lines**: Horizontal lines at 7 levels (0%-100%)
2. **OB Rectangle**: 
   - Blue = Bullish OB
   - Red = Bearish OB
   - Thickness = 2 px
3. **Entry Levels**: M1/M5/H1 EMA lines (green/red)
4. **GOM_SIDO Dashboard**: 5-level verdict at bottom-left

---

## Trading Workflow

1. **Identify Setup**: Robot detects CHOCH on chart
2. **Wait for Entry**: Price must reach 61.8%-78.6% Fibonacci zone
3. **Enter Trade**: Automatic execution at exact zone entry
4. **Risk Locked**: SL at OB level + 20 pips
5. **Profit Targets**:
   - TP1 at ATR × 0.5 → Close 33%
   - TP2 at ATR × 1.0 → Close 33%
   - TP3 at ATR × 1.5 → Close 33%

---

## Configuration

### Inputs (can be modified in MT5)
- `ShowBookmarkLevels = false` (ICT bookmarks disabled)
- `ShowBottomDashboard = true` (GOM_SIDO verdict visible)
- `VerdictThresholdGOOD = 0.35`
- `VerdictThresholdPERFECT = 0.65`

### Fixed Parameters
- **OB Detection**: Last 80 bars scanned
- **CHOCH Threshold**: Next HH/LL after swing point
- **OTE Zone**: 61.8%-78.6% (Fibonacci standard)
- **SL Buffer**: 20 pips from OB boundary
- **ATR Period**: 14 bars (standard)

---

## Example Trade

### Scenario: Bullish Setup
```
1. Robot detects CHOCH:
   - Previous swing low: 10345.50
   - Previous swing high: 10365.80
   - New high: 10366.00 (CHOCH confirmed ✓)

2. OB created:
   - High: 10365.80
   - Low: 10360.00
   - Color: Blue (bullish)

3. Fibonacci retracement:
   - Low: 10345.50
   - High: 10365.80
   - 61.8% zone: 10358.20 - 10361.00
   - 78.6% zone: 10361.00 - 10363.30

4. Price enters 61.8%-78.6% zone:
   - Entry: 10359.50 (ask)
   - SL: 10360.00 - 20 pips = 10359.80
   - ATR: 15 pips
   - TP1: 10359.50 + 7.5 = 10367.00
   - TP2: 10359.50 + 15.0 = 10374.50
   - TP3: 10359.50 + 22.5 = 10382.00

5. Trade executed:
   ✅ BUY 0.2 @ 10359.50
   SL @ 10359.80 | TP1 @ 10367.00 | TP2 @ 10374.50 | TP3 @ 10382.00
```

---

## Status
✅ **Complete and Ready**
- Fibonacci retracement: Displayed
- OB + CHOCH detection: Implemented
- OTE entry system: Active
- Multi-TP management: Configured
- Risk management: SL + TP1/TP2/TP3

Generated: 2026-05-17
Robot: SMC_Universal.mq5
