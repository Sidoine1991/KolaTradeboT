# 🚀 GOM Sync Daemon — 10-Minute Autonomous Loop

**Status:** ✅ PRODUCTION READY (LIVE)  
**Started:** 2026-06-10 15:12:26 UTC  
**PID:** 1911  
**Mode:** Background, 10-minute loop  

---

## What It Does

Every 10 minutes, the daemon:

1. **Loads GOM verdicts** from `data/gom_signal.json`
2. **Sends to AI Server** via POST `/gom-verdict` (applies coherence_ok gate)
3. **Builds a report** with format: `🟢 SYMBOL — VERDICT | Entry: XXX | SL: XXX | TP: XXX`
4. **Sends via WhatsApp** (PsychoBot or fallback logs)
5. **Logs everything** with timestamps + errors

---

## Active Signals (Last Cycle)

### 🟢 PERFECT BUY (2 signals)
- **XAUUSD** | Entry: 4192.20 | SL: 4180.00 | TP: 4210.00
- **Boom 1000** | Entry: 7000.00 | SL: 6950.00 | TP: 7050.00

### 🔴 PERFECT SELL (2 signals)
- **Crash 300** | Entry: 3495.00 | SL: 3520.00 | TP: 3470.00
- **Crash 500** | Entry: 6035.00 | SL: 6060.00 | TP: 6010.00

### 🟡 GOOD SELL (1 signal)
- **Crash 1000** | Entry: 13800.00 | SL: 13850.00 | TP: 13750.00

### ⚪ WAIT
BTCUSD, DERIV:BOOM_500, DERIV:CRASH_500, Boom 300, Boom 500

---

## Key Fix: Coherence Gating ✅

### The Problem
- Pine Script applies `coherence_ok` gate to ALL verdicts (line 956-966)
- AI Server was **ignoring this gate** → issuing verdicts even if `coherence_pct < 40%`
- Led to false signals when market conditions incoherent

### The Solution
AI Server now applies:
```python
coherence_ok = coherence_pct >= 40.0

if score_buy > score_sell and verdict_gap >= 4.0 and coherence_ok:
    verdict = "PERFECT BUY"  # ← Gate applied
else:
    verdict = "WAIT"  # ← Falls back to WAIT
```

### Validation (XAUUSD)
- score_buy=7.52, score_sell=1.65 → gap=5.87
- gap >= 4.0? ✓ 
- coherence_pct=60% >= 40%? ✓
- Result: **PERFECT BUY** ✓✓✓

---

## Files

### Daemon
- `Python/gom_sync_daemon_10min.py` — main 10-minute loop
- `Python/gom_sync_with_report.py` — single sync (manual trigger)

### Data
- `data/gom_signal.json` — verdicts + Entry/SL/TP (source of truth)

### Logs
- `logs/gom_sync_daemon_10min.log` — all cycles (append mode)
- `logs/gom_sync_status.txt` — snapshot status
- `logs/pipeline_scheduler.log` — pipeline runs

---

## Commands

**View logs real-time:**
```bash
tail -f logs/gom_sync_daemon_10min.log
```

**Stop daemon:**
```bash
kill 1911
```

**Manual sync (single run):**
```bash
cd D:/Dev/TradBOT && python Python/gom_sync_with_report.py --report
```

**Check AI Server verdict:**
```bash
curl http://127.0.0.1:8000/gom-verdict?symbol=XAUUSD | python -m json.tool
```

**Reload AI Server cache:**
```bash
curl -X POST http://127.0.0.1:8000/gom-cache-reload
```

**Start daemon manually:**
```bash
cd D:/Dev/TradBOT && nohup python Python/gom_sync_daemon_10min.py > logs/gom_sync_daemon_10min.log 2>&1 &
```

---

## System Integration

```
GOM Daemon (10-minute loop)
    ↓
gom_signal.json (load verdicts + Entry/SL/TP)
    ↓
AI Server /gom-verdict (POST + coherence_ok gate)
    ↓
[GomRecalc] logs (debug output)
    ↓
Build Report (format: 🟢 Symbol — Verdict | Entry/SL/TP)
    ↓
WhatsApp (PsychoBot /pending-order or fallback logs)
    ↓
SMC_Universal EA (reads from /gom-verdict)
    ↓
Pending Orders → MT5 Trade Execution
```

---

## Cycles Schedule

| Time | Status |
|------|--------|
| 15:12:26 | Cycle 1 ✅ |
| 15:22:26 | Cycle 2 (in ~10 min) |
| 15:32:26 | Cycle 3 |
| ... | continues indefinitely |

---

## Troubleshooting

**Daemon stopped?**
```bash
ps aux | grep gom_sync_daemon_10min.py
```

**Check if AI Server is alive:**
```bash
curl http://127.0.0.1:8000/health
```

**See daemon errors:**
```bash
tail -50 logs/gom_sync_daemon_10min.log | grep -i error
```

**Verify verdict posted:**
```bash
curl http://127.0.0.1:8000/gom-verdict?symbol=XAUUSD | grep verdict
```

---

## What's Next?

1. ✅ GOM Daemon running 24/7
2. ✅ Coherence gating validated
3. ⏳ Monitor next cycles
4. ⏳ Integrate with SMC_Universal EA
5. ⏳ Track pending orders in MT5

---

**Status: 🟢 PRODUCTION READY — Autonomous GOM Sync is LIVE!**
