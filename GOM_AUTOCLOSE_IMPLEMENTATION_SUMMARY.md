# 🆕 GOM Auto-Close Implementation Summary

## Objective
When GOM verdict transitions to WAIT with an open position, automatically close that position and wait for GOM to improve to GOOD/PERFECT before reopening.

## Changes Made

### 1. Added Global Tracking Variable
- **Line 247**: `int g_lastGOMVerdictNum = 0;` (already existed)
- Tracks verdict: 0=WAIT, ±1=BUY/SELL, ±2=GOOD, ±3=PERFECT

### 2. New Function: MonitorGOMWaitClosePositions()
- **Lines 636-667**: Complete position monitoring and closure logic
- **Location**: OnTick() at line 737
- **Logic**:
  1. If GOM is NOT WAIT → return early (no action)
  2. Loop through all open positions (iterate backwards for safety)
  3. Check if position is on current symbol (_Symbol)
  4. Extract ticket, entry price, P&L
  5. Close position immediately via CTrade.PositionClose()
  6. Log success/failure with explicit verdict reason

### 3. Integrated into OnTick()
- **Line 737**: Added call after CheckGOMReEntry()
```mql5
if(UseGOMScalp)           MonitorGOMWaitClosePositions();
```

### 4. Existing GOM=WAIT Guards (5 paths already protected)
1. **Line 2087-2089**: CanDuplicateNowWithGOM() → blocks duplication on WAIT
2. **Line 1920-1921**: CheckGOMAutoEntry() → blocks new entry on WAIT
3. **Line 3563-3564**: DRV_EvaluateEntry() → blocks market entry on WAIT
4. **Line 1686**: TVSetupBlockPlaceOnWait → blocks limit order on WAIT
5. **Line 2838-2841**: TryReEntryOnEMA() → blocks EMA re-entry on WAIT

## Logging Output

### ✅ On Successful Close
```
[GOM-WAIT-CLOSE] ✅ XAUUSD fermée | entry=2534.50 pnl=45.32 | verdict=WAIT (vnum=0)
```

### ❌ On Close Error
```
[GOM-WAIT-CLOSE] ❌ XAUUSD erreur fermeture | ticket=12345 | <error description>
```

## Workflow

```
Market Conditions:
XAUUSD with open BUY @ 2534.50

↓ GOM transitions: -2 (GOOD) → 0 (WAIT)
↓ OnTick() fires
↓ PollGOMScalpVerdict() updates g_lastGOMVerdictNum = 0
↓ MonitorGOMWaitClosePositions() detects WAIT
↓ Closes position immediately
↓ Logs closure reason with vnum=0

Position CLOSED ✅

↓ Wait for GOM to improve
↓ GOM transitions: 0 (WAIT) → -2 (GOOD) or -3 (PERFECT)
↓ CheckGOMAutoEntry() / CheckGOMReEntry() can resume entry logic
```

## Testing Checklist

- [ ] Compile TradeManager.mq5 → 0 errors, 0 warnings
- [ ] Attach to XAUUSD M1 chart
- [ ] Manually place BUY position @ 2534.50
- [ ] Verify position shows in Terminal
- [ ] Wait for GOM verdict to turn WAIT on TradingView
- [ ] Observe position auto-closes in Terminal
- [ ] Check log output: [GOM-WAIT-CLOSE] message should appear
- [ ] Verify P&L is captured in log
- [ ] Test on Boom500 (M1)
- [ ] Test on Crash1000 (M1)
- [ ] Test on BTCUSD (H1)

## Files Modified
- `D:\Dev\TradBOT\TradeManager.mq5`
  - Lines 636-667: New MonitorGOMWaitClosePositions()
  - Line 737: Added to OnTick()

## Status
✅ Implementation Complete
⏳ Awaiting Compilation & Testing
