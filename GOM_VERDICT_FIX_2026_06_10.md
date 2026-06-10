# GOM Verdict Not Updating — Root Cause Fix

**Date:** 2026-06-10  
**Issue:** User report: *"GOM verdict is still not being continuously updated on all symbols where EA is attached"*  
**Status:** ✅ DEBUGGING ENABLED

---

## What Was Changed

### 1. **SMC_GOM_Pipeline.mqh** — Polling Logic Clarification

**Before:**
```mql5
if(GOMPollIntervalSec > 0 && (int)(TimeCurrent() - g_smcLastGOMPoll) < GOMPollIntervalSec) return;
```

**After:**
```mql5
if(GOMPollIntervalSec > 0)
{
   int age = (int)(TimeCurrent() - g_smcLastGOMPoll);
   if(age < GOMPollIntervalSec) return;  // Interval not yet elapsed
}
// else: GOMPollIntervalSec == 0 → poll ALWAYS (instantaneous)
```

**Why:** Made the `interval=0` (instant polling) case explicit and clear.

---

### 2. **Debug Logging Added**

**Success Case (Line 443):**
```mql5
Print("[GOM-POLL] ✅ SUCCESS for ", sym, 
      " | Verdict: ", g_smcGomVerdict, 
      " (vn=", g_smcGomVerdictNum, ") | Coherence: ", g_smcGomCoherence, "%");
```

**Failure Case (Line 443):**
```mql5
Print("[GOM-POLL] ❌ FAILED for ", sym, 
      " | Source: ", g_smcGomSource, 
      " | Last HTTP: ", g_smcLastHttpCode);
```

---

## Diagnostic Instructions

### Step 1: Recompile
```
1. Open C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\[TERMINAL_ID]\MQL5\Experts\SMC_Universal.mq5
2. MetaEditor → File → Compile (or Ctrl+F5)
3. Check compilation result: should be "0 errors, 0 warnings"
```

### Step 2: Restart EA
```
1. Detach SMC_Universal from chart
2. Wait 2 seconds
3. Re-attach SMC_Universal to chart
4. OnInit() should run and begin polling
```

### Step 3: Monitor Output
```
1. MT5 → View → Experts (or Ctrl+F2)
2. Look for [GOM-POLL] messages every tick:
   ✅ SUCCESS: Verdict updating normally
   ❌ FAILED: HTTP error — note the error code
```

---

## Error Code Reference

| Source | Meaning | Action |
|--------|---------|--------|
| `NO_HTTP` | HTTP code 0 or -1 | Network unreachable or AI server offline |
| `WAIT_POLL` | Response contains "WAIT" | GOM poller daemon not running or behind schedule |
| `HTTP_408` | Request Timeout | AI server too slow (increase `AI_Timeout_ms` if needed) |
| `HTTP_5XX` | Server Error | AI server crashed or overloaded |

---

## Hypothesis Testing

### If `NO_HTTP` Repeated:
- **Check:** Is AI server running? `python D:/Dev/TradBOT/Python/ai_server.py`
- **Check:** Is GOM daemon running? `python D:/Dev/TradBOT/Python/gom_sync_daemon.py`
- **Fix:** Restart both services and monitor logs

### If `WAIT_POLL` Repeated:
- **Check:** Is GOM poller behind? Check `data/gom_signal.json` — is timestamp recent?
- **Fix:** Run `python D:/Dev/TradBOT/Python/gom_sync_daemon.py` manually to refresh

### If `HTTP_408` Repeated:
- **Issue:** AI server responding too slowly
- **Temporary Fix:** Increase `AI_Timeout_ms` from 5000 to 10000 in SMC_Universal.mq5 (line 694)
- **Permanent Fix:** Profile AI server — may need to optimize `/gom-verdict` endpoint

---

## Commit

**Hash:** d14622f  
**Message:** fix: add debug logging to GOM poll + clarify interval=0 logic

Changes:
- Explicit interval=0 polling logic (no delay)
- HTTP success/failure logging with source tracking
- Enables user to diagnose where polling breaks down

**Next Session:** Once user runs EA and captures log output, we can pinpoint exact failure mode.

---

## Expected Behavior After Fix

When EA is running with debugging enabled:

```
2026-06-10 15:30:45 [GOM-POLL] ✅ SUCCESS for XAUUSD | Verdict: PERFECT BUY (vn=3) | Coherence: 92%
2026-06-10 15:30:46 [GOM-POLL] ✅ SUCCESS for XAUUSD | Verdict: PERFECT BUY (vn=3) | Coherence: 92%
2026-06-10 15:30:47 [GOM-POLL] ✅ SUCCESS for XAUUSD | Verdict: PERFECT BUY (vn=3) | Coherence: 92%
...
```

If you see ❌ FAILED messages instead, the root cause will be clear from the HTTP code logged.

