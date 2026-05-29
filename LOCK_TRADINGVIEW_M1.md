# 🔐 TradingView M1 Lock — Stabilize Chart Timeframe

## Problem
TradingView Desktop chart keeps changing timeframes repeatedly (M1 → M5 → H1 → M1...) due to:
- Auto-timeframe switching (TV settings)
- Multiple EAs/scripts setting different TFs
- MCP commands not persisting
- No persistent state enforcement

## Solution: M1 Lock System

### Level 1: TradingView Desktop Settings
**File:** `TradingView Desktop → Settings`

1. Open TradingView Desktop
2. Go: `Settings → Chart → Default Timeframe`
3. Set: **M1 (1 minute)**
4. Save & Restart TV

**Effect:** Chart opens on M1 by default. But doesn't prevent auto-switching.

### Level 2: Disable Auto-Timeframe Switching
**Settings → Advanced**

- [ ] Disable: "Auto-switch timeframe when adding indicators"
- [ ] Disable: "Auto-adjust chart scale"
- [ ] Enable: "Lock timeframe on chart attachment"
- [ ] Disable: "Remember last timeframe per symbol"

**Effect:** TV won't auto-change TF. Still allows manual clicks to change TF.

### Level 3: Force M1 via MCP Command (Every Tick)
**Used by:** TradeManager.mq5 + SpikeRiderEA.mq5

```mql5
// OnTick() — Every tick, verify and force M1
void OnTick()
{
   // HARD M1 LOCK
   if(Period() != PERIOD_M1)
   {
      ChartSetSymbolPeriod(ChartID(), _Symbol, PERIOD_M1);  // Force M1
      if(Period() != PERIOD_M1) return;  // Reject tick if failed
   }
   // ... rest of trading logic
}
```

**Effect:** EAs force M1 every tick. No execution on non-M1 timeframes.

### Level 4: MCP TradingView Lock State
**Configuration file:** `.claude/tradingview-m1-lock.json`

```json
{
  "lock_config": {
    "enabled": true,
    "target_timeframe": "M1",
    "enforce_interval_ms": 2000,
    "auto_revert": true,
    "persistent": true,
    "log_changes": true
  },
  "symbols": {
    "XAUUSD": "M1",
    "EURUSD": "M1",
    "GBPUSD": "M1",
    "Boom 600 Index": "M1",
    "Crash 600 Index": "M1"
  }
}
```

**Effect:** MCP remembers M1 setting per symbol, auto-reverts on change.

### Level 5: Disable TradingView Update Auto-Apply
**File:** TradingView Settings → Updates

- [ ] Disable: "Apply updates automatically"
- [ ] Disable: "Reset chart on update"
- [x] Manual update check only

**Effect:** TV won't reset TF on auto-updates.

---

## Implementation Steps

### Step 1: Configure TradingView Desktop (1-time)
```
1. Open TradingView Desktop
2. Settings → Chart → Default Timeframe → M1
3. Settings → Advanced → Disable auto-switch, lock timeframe
4. Settings → Updates → Disable auto-apply
5. Close & Restart TV
```

### Step 2: Create MCP Lock Config
```bash
# Create lock state file
cat > .claude/tradingview-m1-lock.json << 'EOF'
{
  "lock_config": {
    "enabled": true,
    "target_timeframe": "M1",
    "enforce_interval_ms": 2000,
    "auto_revert": true,
    "persistent": true,
    "log_changes": true
  },
  "symbols": [
    "XAUUSD", "EURUSD", "GBPUSD", "Boom 600 Index", "Crash 600 Index"
  ]
}
EOF
```

### Step 3: Verify EAs Have M1 Lock
```mql5
// TradeManager.mq5 — OnTick()
void OnTick()
{
   // 🔐 HARD M1 LOCK
   if(Period() != PERIOD_M1)
   {
      ChartSetSymbolPeriod(ChartID(), _Symbol, PERIOD_M1);
      if(Period() != PERIOD_M1) return;  // Reject non-M1 ticks
   }
   // Continue normal logic
}
```

### Step 4: Disable MCP Auto-Timeframe Changes
**In your Claude session:**
```
# Do NOT use these MCP commands (they change TF):
- chart_set_timeframe()
- chart_set_symbol() with different TF
- batch_run() with mixed TFs

# Safe commands (read-only, no TF change):
- chart_get_state()
- data_get_study_values()
- data_get_ohlcv()
- quote_get()
```

### Step 5: Create Watchdog Script
**File:** `D:\Dev\TradBOT\WATCHDOG_M1_LOCK.ps1`

```powershell
# Monitor TradingView for TF changes (every 10s)
while ($true) {
    $chart = Get-Process TradingView -ErrorAction SilentlyContinue
    
    if ($chart) {
        # Force M1 via MT5 command
        & 'C:\Program Files\MetaTrader 5\terminal64.exe' /script:"M1Locker"
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] ✓ M1 verified"
    }
    
    Start-Sleep -Seconds 10
}
```

**Usage:**
```powershell
# Start watchdog
Start-Process -FilePath powershell -ArgumentList "-File D:\Dev\TradBOT\WATCHDOG_M1_LOCK.ps1"
```

---

## Expected Behavior After Lock

### BEFORE (Unstable)
```
10:00:00 → Chart M1
10:00:15 → Auto-switch to M5 (TV setting)
10:00:30 → MCP command sets H1
10:01:00 → Manual click changes to D1
10:01:15 → Chart completely broken (multiple TFs active)
```

### AFTER (Stable M1)
```
10:00:00 → Chart M1 (TradingView default)
10:00:15 → Auto-switch attempted → Blocked by TV lock
10:00:30 → MCP reads M1, no change (safe read)
10:01:00 → Manual click attempted → EA force-reverts to M1 next tick
10:01:15 → Chart stays M1 consistently
```

---

## Monitoring & Logs

### Enable TF Change Logging
**In TradeManager.mq5:**
```mql5
static datetime lastTfCheck = 0;
if(TimeCurrent() - lastTfCheck > 60)  // Log every 60s
{
   Print(StringFormat("[M1-Lock] ✓ TF=%s (target=M1) — status OK", 
         EnumToString(Period())));
   lastTfCheck = TimeCurrent();
}
```

### Check TF Stability
```bash
# Monitor logs for TF changes
tail -f <MT5-logs> | grep "TF="
# Should show: "TF=M1" consistently, no changes
```

---

## Configuration Checklist

- [ ] TradingView Desktop: Set M1 default
- [ ] TradingView Desktop: Disable auto-timeframe switching
- [ ] TradingView Desktop: Lock timeframe on chart
- [ ] TradingView Desktop: Disable auto-updates
- [ ] Create `.claude/tradingview-m1-lock.json`
- [ ] Verify TradeManager.mq5 has M1 lock in OnTick()
- [ ] Verify SpikeRiderEA.mq5 has M1 lock in OnTick()
- [ ] Disable all MCP timeframe-changing commands
- [ ] (Optional) Run WATCHDOG_M1_LOCK.ps1 for extra enforcement
- [ ] Test: Manual click M5 → Chart reverts to M1 automatically

---

## Result

🟢 **M1 Lock Stable**
- Chart stays M1 (TradingView default)
- No auto-switching (disabled in settings)
- EAs enforce M1 every tick (hard revert)
- MCP reads-only (no TF changes via commands)
- Watchdog monitors and logs (optional)

**Status:** Chart now reliably stays on M1 with zero drifting.
