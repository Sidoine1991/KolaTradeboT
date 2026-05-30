# SpikeRiderEA v5.07 — Deployment Guide

## What's Fixed

**SpikeRider no longer trades in counter-trend.** The GOM verdict from `/spike-tv-state` is now properly enforced.

| Issue | Symptom | Fix |
|-------|---------|-----|
| `JsonExtractBool` bug | Defaulted to `true` when key missing | Now defaults to `false` |
| No counter-trend block | EA ignored `"counter_trend": true` | Now blocks immediately |
| No staleness check | Traded on 2+ min old TV data | Now rejects if > 120s old |
| Missing defaults | Undefined behavior if fields absent | All fields have safe defaults |

---

## Pre-Deployment Checklist

- [ ] Stop all SpikeRider instances on live accounts
- [ ] Backup existing SpikeRiderEA.ex5 binary (if exists)
- [ ] Verify AI server is running: `curl http://127.0.0.1:8000/spike-tv-state?symbol=Boom500Index`
- [ ] Check `/spike-tv-state` returns: `"counter_trend": true/false` (not missing)

---

## Deployment Steps

### Step 1: Compile SpikeRiderEA v5.07

```bash
# In MetaTrader 5 MetaEditor or via CLI
metaeditor64.exe /compile:SpikeRiderEA.mq5
```

Expected: **0 errors, 0 warnings**

### Step 2: Validate Compilation

Check output binary has timestamp >= now:
```bash
ls -la SpikeRiderEA.ex5  # Should show recent timestamp
```

### Step 3: Run Validation Tests

```bash
python test_gom_verdict.py
```

Expected:
```
[PASS] JsonExtractBool Fix
[PASS] Counter-Trend GOM Verdict
[PASS] Safe Defaults
RESULT: [PASS] ALL TESTS PASSED
```

### Step 4: Deploy to Trading Terminals

1. Copy `SpikeRiderEA.ex5` to:
   - `C:\Program Files\MetaTrader 5\MQL5\Experts\`
2. Reload/Restart MT5 platform
3. Attach EA to each Boom/Crash chart

### Step 5: Monitor Initial Trades

Watch first 10 trades for:

1. **Counter-trend block** — if AI server says `counter_trend=true`, EA must NOT enter
2. **Logs show verdict** — check logs include `verdict_CT=BLOQUE` or `verdict_CT=ok`
3. **Staleness rejection** — if TV data > 120s old, logs say `données expirées`
4. **Entry reasons** — logs show `GOM-Bridge OK | verdict_CT=...`

Example good log:
```
[SpikeRider] GOM-Bridge Boom500Index | verdict_CT=ok | sniper=READY 87% | 
imm=72% | spike=BUY Z=2.8 | struct=[M15=bullish H1=bullish] OB=buy_side 
EMA=bullish | global=BULL[82%] coh=88%
[SpikeRider] ✅ SETUP SPIKE BUY | Z=2.80 | ✓ OK BUY | Z=2.80 | stair=80% | 
BOS+ CH- OTE+ | TV[OK CT=ok sniper=ready] | Global=BULL(82%) Coh=88%
```

Example bad log (should NOT trade):
```
[SpikeRider] GOM-Bridge Boom500Index | verdict_CT=BLOQUE | ...
[SpikeRider] SETUP SPIKE BUY bloqué: TV contre-tendance | EMA=bearish OB=sell_side dir=SELL
```

---

## Rollback Plan

If issues occur:

### Quick Rollback (< 1 minute)

1. Open MT5
2. Remove EA from affected charts
3. Reattach old SpikeRiderEA.ex5 (v5.03 or earlier)
4. Monitor for stability

### Full Rollback (git-based)

```bash
# Revert to previous version
git revert HEAD~1
# Or hard rollback to pre-fix commit
git checkout <commit-hash> -- SpikeRiderEA.mq5
# Recompile
metaeditor64.exe /compile:SpikeRiderEA.mq5
```

---

## Known Behavior Changes

### Change 1: Stricter Counter-Trend Blocking

**Before:** EA might trade opposite to GOM verdict
**After:** EA ALWAYS respects `"counter_trend": true`

**Impact:** Fewer false trades, but also fewer entries on ambiguous setups

### Change 2: Staleness Rejection

**Before:** EA traded on 2+ minute old TV data
**After:** EA rejects entries if TV data > 120 seconds old

**Impact:** Safer, but may refuse entry if AI server has latency > 2 min

### Change 3: Safe Defaults

**Before:** Missing GOM fields → undefined behavior
**After:** Missing fields → safe defaults (neutral, false, 0)

**Impact:** More stable when AI server offline or degraded

---

## Configuration Recommendations

For optimal GOM verdict integration:

```ini
; Input Settings in EA
InpUseTVBridge=true                 ; Enable GOM bridge
InpBlockCounterTrendTV=true         ; ALWAYS block on counter_trend
InpTVBridgePollSec=2                ; Poll every 2s (not too often)
InpTVBridgeMaxAgeSec=20             ; Reject if > 20s old
InpRequireGlobalDir=true            ; Use global TF direction
InpGlobalMinConfidence=70           ; Min 70% confidence
```

---

## Support & Troubleshooting

### Problem: "Données expirées" errors

**Cause:** AI server slow or unreachable
**Fix:**
1. Check AI server is running: `curl http://127.0.0.1:8000/health`
2. Check network latency: `ping 127.0.0.1`
3. Increase `InpTVBridgeMaxAgeSec` to 30-40 (tradeoff: less fresh data)

### Problem: Too many trades blocked

**Cause:** AI server conservative (always sets `counter_trend=true`)
**Fix:**
1. Check AI server logic for `/spike-tv-state`
2. Verify TradingView data is fresh on server side
3. Set `InpBlockCounterTrendTV=false` (NOT RECOMMENDED — use as last resort)

### Problem: Logs don't show verdict

**Cause:** Debug logging off or GOM verdict missing from response
**Fix:**
1. Set `InpDebug=true` in EA inputs
2. Check `/spike-tv-state` response includes `"counter_trend"` field
3. Verify ai_server is connected to TradingView MCP

---

## Verification Commands

```bash
# Check AI server GOM endpoint
curl http://127.0.0.1:8000/spike-tv-state?symbol=Boom500Index | jq '.counter_trend'

# Expected output: true or false (not missing)

# Check SpikeRider version
# In MT5, attach EA to chart. Expert tab should show:
# "[SpikeRider] ✅ Init v5.07 | ... | GOM-Bridge=ON (GOM verdict active)"
```

---

## Metrics to Monitor Post-Deployment

Track for 1 week:

| Metric | Target | Action if Failed |
|--------|--------|------------------|
| Win rate | > 50% (no change expected) | Review entry logic |
| Blocked trades (CT=true) | > 5% of attempts | Normal — shows GOM working |
| Staleness rejections | < 2% of attempts | Increase `MaxAgeSec` if too high |
| EA crashes | 0 | Revert to v5.03 |

---

## Emergency Contact

If GOM verdict blocking prevents all trades:

**Temporary Workaround:**
```mql5
// In SpikeRiderEA.mq5, line ~484:
if(InpBlockCounterTrendTV && tvSaysCounterTrend)  // ← Comment this line
{
   // reason = ...; return false;  // ← Now disabled
}
```

Recompile and redeploy. **This is NOT recommended** — use only as emergency bridge.

---

## Version History

| Version | Date | Change |
|---------|------|--------|
| v5.03 | 2026-05-28 | Initial GOM bridge (broken) |
| v5.07 | 2026-05-30 | GOM verdict fixed + staleness + safe defaults |

