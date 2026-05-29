# 🎯 GOM Trend-Following Strategy v2 (Simplified)

## Philosophy
**Trade the trend without waiting for the perfect setup.**

Instead of:
- ❌ Waiting for perfect confluence (OTE + ICT + SMC)
- ❌ Blocking on KOLA state
- ❌ Filtering on Quality/Coherence thresholds
- ❌ Rejecting WAIT signals (too conservative)

We now:
- ✅ **GOOD/PERFECT signals ONLY** → Open immediately
- ✅ Enter at **OB pullback levels** (order block bounce)
- ✅ Scalp on **EMA raides** (steep EMAs = strong trend)
- ✅ Ride momentum until TREND CHANGE
- ✅ **PERFECT→GOOD** = Prepare exit (TP zone approaching)
- ✅ **GOOD/PERFECT→WAIT** = Close immediately (trend reversal = correction)

---

## Entry Logic

### Signal Detection
GOM verdict every 1 second:
- `vnum = 3` → **PERFECT BUY** ✅ ENTER
- `vnum = 2` → **GOOD BUY** ✅ ENTER
- `vnum = -2` → **GOOD SELL** ✅ ENTER
- `vnum = -3` → **PERFECT SELL** ✅ ENTER
- `vnum = 0` → **WAIT** ❌ DO NOT ENTER (but don't close immediately)
- `vnum = ±1` → **BUY/SELL** (simple) — ignored

### Entry Conditions (ALL REMOVED except signal + direction match)

| Condition | Before | After | Status |
|-----------|--------|-------|--------|
| **Minimum Quality** | 65% | 0% (none) | ✅ Removed |
| **Minimum Coherence** | 50% | 0% (none) | ✅ Removed |
| **RSI Limits** | [30,80] | [0,100] | ✅ Removed |
| **KOLA State** | NEAR BUY/SELL | Ignored | ✅ Removed |
| **OTE/ICT/SMC** | 3 confluences | None required | ✅ Removed |
| **Global Dir** | Must match | Ignored | ✅ Removed |
| **Consolidation Check** | Strict | Disabled | ✅ Removed |
| **Cooldown** | 45s | 5s | ⚡ Reduced |

### Entry Placement

**Position Opening:**
1. **Signal:** GOOD/PERFECT (vnum = ±2 or ±3)
2. **Direction:** Match signal (BUY → long, SELL → short)
3. **Entry Price:** 
   - Near OB pullback level (where price bounced)
   - Aligned with steep EMA (momentum)
   - Market execution (no pending orders)
4. **Lot Size:** Fixed 0.01 (no dynamic sizing)

**Example:** GOM=PERFECT BUY @ 4525.68 (OB level)
```
Entry: 4525.68
SL: Below OB (e.g., 4524.00)
TP1: +1 ATR (e.g., 4530.00) — take half
TP2: +2 ATR (e.g., 4535.00) — hold rest
```

---

## Exit Logic (Simplified)

### Degradation Monitoring
Every 1 second, check if verdict changes:

| Current Pos | Signal Change | Action |
|-------------|----------------|--------|
| **BUY** | GOM=WAIT | 🔴 **CLOSE** (trend reversal) |
| **BUY** | GOM=SELL (opp) | 🔴 **CLOSE** (reversal confirmed) |
| **BUY** | GOM=PERFECT BUY | 🟢 **HOLD** (trend strong) |
| **BUY** | GOM=GOOD BUY (downgrade) | 🟡 **PREPARE EXIT** (momentum fading) |
| **BUY** | GOM=BUY/SIMPLE | 🟡 **HOLD** (weak signal, but ok) |
| **SELL** | GOM=WAIT | 🔴 **CLOSE** (trend reversal) |
| **SELL** | GOM=BUY (opp) | 🔴 **CLOSE** (reversal confirmed) |
| **SELL** | GOM=PERFECT SELL | 🟢 **HOLD** (trend strong) |
| **SELL** | GOM=GOOD SELL (downgrade) | 🟡 **PREPARE EXIT** (momentum fading) |

### Critical Rule: WAIT = Close
```
if(GOM_Verdict == WAIT)
   Close_All_Positions()  // Trend change detected
```

**Why?** WAIT signals a consolidation or reversal — profit protection is more important than catching extra pips.

### Preparation for Exit: PERFECT→GOOD
When signal downgrades from PERFECT → GOOD:
1. **Move SL to breakeven** (protect profit)
2. **Set TP at first target** (lock in $1-2)
3. **Wait for reversal signal** (WAIT or opposite direction)

Example:
```
Entry: 4525.68 (PERFECT BUY)
↓ Signal downgrades to GOOD BUY
↓ Move SL → 4525.68 (breakeven)
↓ Set TP1 → 4530.00 (first target, +1 ATR)
↓ Wait for WAIT or SELL signal
↓ Close at TP or GOM signal
```

---

## Money Management

### Fixed Lot Strategy
- **Lot Size:** 0.01 per trade
- **Max Positions:** 2 concurrent (XAUUSD)
- **Max Daily Loss:** 5% of account
- **Risk per Trade:** $1-3 USD (SL at 1-3 pips)

### Profit Targets
| TP Level | ATR Multiple | Target Price (XAUUSD) |
|----------|--------------|----------------------|
| **TP1** | +1 × ATR | ~4530 (take 50%) |
| **TP2** | +2 × ATR | ~4535 (let ride) |

### Stop Loss
- **SL Level:** Below OB (order block low)
- **SL Distance:** 1-2 pips from OB
- **Example:** BUY @ 4525.68, SL @ 4524.00

---

## GOM Signal States (Reference)

| vnum | Verdict | Action |
|------|---------|--------|
| **3** | PERFECT BUY | ✅ Open BUY |
| **2** | GOOD BUY | ✅ Open BUY (weaker) |
| **1** | BUY (simple) | ⊘ Ignored |
| **0** | WAIT | ⊘ Consolidation — CLOSE |
| **-1** | SELL (simple) | ⊘ Ignored |
| **-2** | GOOD SELL | ✅ Open SELL (weaker) |
| **-3** | PERFECT SELL | ✅ Open SELL |

---

## Key Changes from v1

### REMOVED (No longer block entries)
- ✅ Quality threshold (was 65%, now 0%)
- ✅ Coherence threshold (was 50%, now 0%)
- ✅ RSI limits (was [30,80], now [0,100])
- ✅ KOLA state requirement
- ✅ OTE/ICT/SMC validation (3 confluences)
- ✅ Global direction matching
- ✅ Consolidation blocking

### REDUCED (Faster signal detection)
- ✅ Cooldown: 45s → 5s
- ✅ Re-entry cooldown: 20s → 5s
- ✅ Re-entry max count: 5 → 99 (unlimited)

### SIMPLIFIED (Cleaner logic)
- ✅ Close on WAIT only (was: WAIT + Quality low + RSI extremes)
- ✅ Prepare exit on PERFECT→GOOD only
- ✅ Fixed lot (was: dynamic based on quality/coherence)
- ✅ Min vnum: 2 (GOOD only, was 3 for Gold)

---

## Configuration in TradeManager.mq5

```ini
[=== GOM TREND FOLLOWING ===]
UseGOMScalp = true
GOMPollIntervalSec = 1
GOMSignalMaxAgeSec = 90
UseGOMAutoEntry = true
GOMAutoEntryCooldownSec = 5        ← REDUCED from 45s
GOMMinQuality = 0.0                ← DISABLED
GOMMinCoherence = 0.0              ← DISABLED
GOMBlockOnWait = false             ← WAIT doesn't block entry
GOMWaitPullbackToKola = false      ← KOLA not required
RequireGlobalDirMatch = false      ← Global dir not required

[=== GOLD (XAUUSD) ===]
GoldMinVnum = 2                    ← GOOD = 2 accepted
GoldRequireKola = false            ← DISABLED
GoldMinForce = 0.0                 ← DISABLED
GoldMinCoherence = 0.0             ← DISABLED
GoldMaxRSI = 100.0                 ← No limit
GoldMinRSI = 0.0                   ← No limit

[=== SIZING ===]
UseDynamicLot = false              ← Fixed lot only
LotPerfectKola = 0.01
LotGood = 0.01
LotWeak = 0.01
```

---

## Expected Behavior

### Before (Overly Conservative)
```
GOM=PERFECT BUY @ 4525
❌ KOLA ≠ NEAR BUY → BLOCKED
OR
Quality 55% < 65% → BLOCKED
OR
Coherence 40% < 50% → BLOCKED
→ Miss profitable move
```

### After (Trend Following)
```
GOM=PERFECT BUY @ 4525
✅ vnum=3 → OPEN immediately
✅ Enter at OB + EMA aligned
✅ Ride to +2 ATR or WAIT signal
✅ Close on reversal (WAIT/opposite direction)
→ Catch the trend, cut losses fast
```

---

## Testing Checklist

- [ ] Compile TradeManager.mq5 (0 errors)
- [ ] Attach to XAUUSD M1 chart
- [ ] Check logs for GOM signal detection (every 1s)
- [ ] Verify entry on GOOD/PERFECT (no blocking)
- [ ] Test exit on WAIT → Position closes
- [ ] Test exit on signal reversal (BUY pos closes on SELL signal)
- [ ] Check profit/loss scaling (money management)
- [ ] Monitor for 24h without manual intervention

---

## Status
🟢 **Strategy Simplified & Ready**
- All restrictive filters removed
- Exit logic streamlined (WAIT + reversal = close)
- Entry: GOOD/PERFECT only
- Result: Trade momentum without waiting for perfect setup

**Deployment:** Compile & restart MT5
**Expected:** Higher trade frequency, faster exits, better trend following
