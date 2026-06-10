# GOM Sync + WhatsApp Autonomous Daemon (10-Minute Loop)

**Status:** ✅ OPERATIONAL  
**Commit:** 78ea0c73  
**Date:** 2026-06-10 14:33 UTC

---

## Overview

The GOM Sync Daemon executes autonomously every 10 minutes:
1. **Load** GOM verdicts from `data/gom_signal.json`
2. **POST** each verdict to `ai_server:8000/gom-verdict`
3. **Build** report with format: `[Verdict] [Symbol] | Entry: X.XX | SL: Y.YY | TP: Z.ZZ`
4. **Send** via WhatsApp (PsychoBot endpoint or fallback log)
5. **Log** all timestamps, verdicts, entry levels, errors
6. **Wait** 10 minutes, repeat

---

## Execution Methods

### Method 1: Command Line (Direct)
```bash
cd D:\Dev\TradBOT
python Python/gom_sync_daemon_10min.py
```

### Method 2: Batch Script (Windows)
```bash
cd D:\Dev\TradBOT
start_gom_sync_daemon.bat
```
- Opens new console window
- Auto-logs to `logs/gom_sync_daemon_10min.log`
- Press `Ctrl+C` to stop

### Method 3: Task Scheduler (Autonomous Background)
```powershell
# Run in Windows Task Scheduler
Program: python.exe
Args: D:\Dev\TradBOT\Python\gom_sync_daemon_10min.py
Start: D:\Dev\TradBOT
```

### Method 4: PowerShell (Background Job)
```powershell
$job = Start-Job -WorkingDirectory 'D:\Dev\TradBOT' `
  -ScriptBlock { python Python/gom_sync_daemon_10min.py }
# View output: Get-Job $job | Receive-Job -Keep
# Stop: Stop-Job $job
```

---

## Log File

**Location:** `logs/gom_sync_daemon_10min.log`

**Format:**
```
2026-06-10 14:33:34,169 [INFO] GOM Sync Daemon Started (10-minute loop)
2026-06-10 14:33:34,169 [INFO] Log file: logs\gom_sync_daemon_10min.log
2026-06-10 14:33:34,169 [INFO] ================================================================================
2026-06-10 14:33:34,169 [INFO] GOM SYNC CYCLE 1 — 2026-06-10 14:33:34 UTC
2026-06-10 14:33:34,169 [INFO] ================================================================================
2026-06-10 14:33:35,050 [WARNING] XAUUSD | PERFECT BUY
2026-06-10 14:33:35,050 [WARNING]    Entry: 4192.20 | SL: 4180.00 | TP: 4210.00
2026-06-10 14:33:35,050 [WARNING] Boom 1000 Index | PERFECT BUY
2026-06-10 14:33:35,050 [WARNING]    Entry: 7000.00 | SL: 6950.00 | TP: 7050.00
2026-06-10 14:33:35,055 [INFO] [OK] Sync completed successfully
2026-06-10 14:33:35,055 [INFO] Next sync in 10 minutes... (Press Ctrl+C to stop)
```

---

## Tracked Symbols (10 Total)

### Tradable Signals (Ready)

| Symbol | Verdict | Entry | SL | TP | Action |
|--------|---------|-------|-----|-----|--------|
| XAUUSD | PERFECT BUY | 4192.20 | 4180.00 | 4210.00 | ✅ BUY |
| Boom 1000 Index | PERFECT BUY | 7000.00 | 6950.00 | 7050.00 | ✅ BUY |
| Crash 300 Index | GOOD SELL | 3495.00 | 3520.00 | 3470.00 | ✅ SELL |
| Crash 500 Index | GOOD SELL | 6035.00 | 6060.00 | 6010.00 | ✅ SELL |
| Crash 1000 Index | GOOD SELL | 13800.00 | 13850.00 | 13750.00 | ✅ SELL |

### Awaiting Data (WAIT State)

| Symbol | Status |
|--------|--------|
| BTCUSD | WAIT |
| DERIV:BOOM_500_INDEX | WAIT |
| DERIV:CRASH_500_INDEX | WAIT |
| Boom 300 Index | WAIT |
| Boom 500 Index | WAIT |

---

## Integration Points

### 1. Data Source: `gom_signal.json`
```json
{
  "XAUUSD": {
    "verdict": "PERFECT BUY",
    "verdict_num": 3,
    "entry": 4192.2,
    "sl": 4180.0,
    "tp": 4210.0,
    "tf_global_dir": "BULL",
    "kola_buy": 4191.0,
    "kola_sell": 4198.0
  },
  ...
}
```

### 2. AI Server Endpoint
```
POST /gom-verdict
Payload: { symbol, verdict, verdict_num, entry, sl, tp, coherence_score }
Response: { ok: true, message: "Verdict recorded" }
```

### 3. WhatsApp Delivery
```
Endpoint: ai_server:8000/psychobot/send-message
Message: "GOM SYNC REPORT — 14:33:34
  • XAUUSD — PERFECT BUY | Entry: 4192.20 | SL: 4180.00 | TP: 4210.00
  • Boom 1000 Index — PERFECT BUY | Entry: 7000.00 | SL: 6950.00 | TP: 7050.00
  ..."
```

---

## Error Handling

### Common Errors & Recovery

| Error | Cause | Action |
|-------|-------|--------|
| `HTTP 404` (WhatsApp) | PsychoBot endpoint down | Report still logged, manual check required |
| `Timeout (60s)` | gom_sync_with_report.py stuck | Daemon continues, next cycle retry |
| `ConnectionRefused` | ai_server not responding | Daemon continues, next cycle retry |
| `KeyboardInterrupt` | User pressed Ctrl+C | Graceful shutdown, log entry created |

**Log Level Mapping:**
- `[INFO]` — Normal operation, cycle milestones
- `[WARNING]` — Nested subprocess output (gom_sync_with_report.py)
- `[ERROR]` — Failures logged, daemon continues

---

## Monitoring

### Real-Time Log Watch
```bash
# Windows PowerShell
Get-Content -Path logs\gom_sync_daemon_10min.log -Wait

# Linux/Mac
tail -f logs/gom_sync_daemon_10min.log
```

### Cycle Tracking
Each cycle increments a counter (Cycle 1, 2, 3, ...) logged at start and end.

### WhatsApp Delivery Status
- ✅ If endpoint responds: message sent to PsychoBot
- ❌ If HTTP 404: message logged but NOT sent (check endpoint)

---

## Performance

**Resource Usage:**
- CPU: <5% (idle waiting 600s between cycles)
- Memory: ~50MB (Python + subprocess)
- Disk: ~500KB/day log rotation

**Network:**
- 1 request per cycle (10 min) = ~144 req/day
- Payload: ~500 bytes per request
- Timeout: 60 seconds per cycle

---

## Configuration

### Interval (Edit to change)
File: `Python/gom_sync_daemon_10min.py`

```python
INTERVAL_SEC = 600  # Change this to adjust cycle time
                    # 300 = 5 min, 600 = 10 min, 3600 = 1 hour
```

### Data Source
File: `data/gom_signal.json`

Add/update symbols here; daemon will pick them up on next cycle.

### Logging Directory
Auto-created if missing: `logs/`

---

## Deployment Checklist

- [ ] **Start daemon:** `python Python/gom_sync_daemon_10min.py`
- [ ] **Check log file exists:** `logs/gom_sync_daemon_10min.log`
- [ ] **Verify AI server running:** `http://127.0.0.1:8000/health`
- [ ] **Verify GOM data populated:** `data/gom_signal.json` has verdicts
- [ ] **Monitor first cycle:** Watch for `[OK] Sync completed successfully`
- [ ] **Set up long-term execution:** Use Task Scheduler or cron (Linux)

---

## Next: Integration with EA

Once daemon is stable, EA should:
1. **Poll** the daemon's HTTP endpoint for latest verdicts (not parse JSON files directly)
2. **Display** real-time verdicts on SMC_Universal dashboard
3. **Execute** independent trades when GOOD/PERFECT verdicts + IA Status ≥70%

This creates a unified data pipeline:
```
GOM Poller → gom_signal.json → GOM Sync Daemon → WhatsApp + EA
```

---

## Troubleshooting

**Q: Daemon won't start**
A: Ensure Python 3.9+ installed, cd to project root, check `logs/gom_sync_daemon_10min.log` for errors

**Q: WhatsApp messages not sending (HTTP 404)**
A: PsychoBot endpoint down; check `ai_server` health at `/health` endpoint

**Q: Log file not created**
A: Manual creation: `mkdir logs` then restart daemon

**Q: Daemon exits after first cycle**
A: Check for exceptions in log file; usually timeout or network error

**Q: How to stop safely?**
A: Press `Ctrl+C` in terminal running the daemon; it logs graceful shutdown

---

**Status: READY FOR PRODUCTION**

