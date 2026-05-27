# XAUUSD Trading System — Unified Architecture

## Problem Summary

**Before:** 20+ Python scripts running independently → duplicate messages, empty WhatsApp alerts, TradeManager ignoring GOM verdict, missing TradingView opportunities.

**Solution:** Single centralized monitor + file-based signal passing → clean separation of concerns.

---

## New Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    XAUUSD Central Monitor                    │
│   (xauusd_central_monitor.py) — SINGLE CANONICAL SCRIPT     │
│                                                             │
│  ÉTAPE 1: Collect TradingView (quote, GOM, RSI, BB, ST)   │
│  ÉTAPE 2: Collect AI Server (bias, order, TA) — parallel  │
│  ÉTAPE 3: Build unified WhatsApp message                   │
│  ÉTAPE 4: Send via PsychoBot                               │
│  BONUS:  Save trading signals to JSON files                │
└──────────────────┬──────────────────────────────────────────┘
                   │
                   ├─→ gom_signal.json (GOM verdict for TradeManager)
                   │
                   ├─→ opportunities.json (3 trading setups)
                   │
                   └─→ WhatsApp message via PsychoBot
                       (fallback to whatsapp_alerts.log if offline)
                       
                   │
                   ▼
        ┌──────────────────────┐
        │   TradeManager.mq5   │
        │                      │
        │ • Polls gom_signal   │
        │ • Reads opportunities│
        │ • Executes trades    │
        │ • Trailing stops     │
        └──────────────────────┘
```

---

## File System — Data Layer

```
D:\Dev\TradBOT\
├── data/
│   ├── gom_signal.json          ← Central Monitor writes GOM verdict
│   │   {
│   │     "verdict": "SELL",
│   │     "score_buy": 4.82,
│   │     "score_sell": 6.056,
│   │     "decision": "🟡 SELL en attente",
│   │     "confluence": "GOM=SELL"
│   │   }
│   │
│   └── opportunities.json        ← Central Monitor writes 3 opportunities
│       [
│         {
│           "id": "OPP-001",
│           "type": "SELL",
│           "timeframe": "M15",
│           "entry": 4508.5,
│           "sl": 4510.0,
│           "tp": [4505.5, 4503.5],
│           "confidence": 0.75
│         },
│         ...
│       ]
│
├── xauusd_central_monitor.py    ← SINGLE authoritative monitor
├── whatsapp_alerts.log          ← Fallback log (if PsychoBot offline)
└── START_COMPLETE_SYSTEM.bat    ← Unified startup script
```

---

## Component Responsibilities

### 1. Central Monitor (`xauusd_central_monitor.py`)

**Role:** Orchestrator — Collects data, builds message, executes trading signals.

**Does:**
- ✅ Calls TradingView MCP tools (quote, study values, pine tables)
- ✅ Fetches AI Server: /session-bias, /pending-order, /tradingagents
- ✅ Constructs WhatsApp message with exact format
- ✅ Sends via PsychoBot (fallback to local log)
- ✅ **NEW:** Writes gom_signal.json and opportunities.json

**Does NOT:**
- ❌ Execute MT5 trades (TradeManager does that)
- ❌ Manage positions (TradeManager does that)
- ❌ Trailing stops (TradeManager does that)

**Run mode:**
```bash
python xauusd_central_monitor.py    # Single cycle (ÉTAPES 1-4)
# Or modify to: run_loop(1200)      # Every 20 minutes
```

---

### 2. TradeManager (`TradeManager.mq5`)

**Role:** Execution engine — Reads signals, manages trades, trailing stops.

**NEW Functions:**
- `LoadGOMSignalFromFile()` — Read gom_signal.json, get verdict + decision
- `LoadOpportunitiesFromFile()` — Read opportunities.json, extract 3 setups

**Does:**
- ✅ Reads GOM verdict from gom_signal.json (replaces old polling)
- ✅ Reads opportunities from opportunities.json
- ✅ Executes trades based on opportunity direction + entry/SL/TP
- ✅ Applies trailing stops
- ✅ Closes trades on opposite signal

**Integration points:**
- OnTick() calls LoadGOMSignalFromFile() every 5 seconds
- OnTick() checks opportunities.json for executable setups
- Respects entry_quality, confidence, convergence checks

---

### 3. AI Server (`ai_server.py`)

**Role:** State machine — Manages biais, pending orders, TA reports.

**Unchanged:**
- Provides /session-bias?symbol=XAUUSD
- Provides /pending-order?symbol=XAUUSD
- Provides /tradingagents/report-status?symbol=XAUUSD
- Stores biais cache + pending orders

---

## Startup Sequence

### Clean Start:

```bash
# 1. Kill all orphans
taskkill /F /IM python.exe /T

# 2. Start Central Monitor (creates signal files)
cd D:\Dev\TradBOT
python xauusd_central_monitor.py

# ✅ This creates:
#   • gom_signal.json (verdict + decision)
#   • opportunities.json (3 trading setups)
#   • Sends WhatsApp message

# 3. MetaTrader 5 auto-starts (or manually: START_COMPLETE_SYSTEM.bat)
# TradeManager reads signal files every 5 seconds
# → Executes opportunities as they align
```

---

## Message Flow

### WhatsApp Message Cycle (Every 20 min)

```
[T+0:00] Central Monitor starts
  │
  ├─ ÉTAPE 1: TradingView collect
  │   • quote_get → $4490.10
  │   • study_values → RSI=36.8, BB, ST, GOM verdict=SELL
  │   • pine_tables → GOM scores
  │
  ├─ ÉTAPE 2: AI Server collect (parallel)
  │   • bias → NEUTRAL (expired)
  │   • order → none
  │   • ta → NONE
  │
  ├─ ÉTAPE 3: Message build
  │   • Format: Price → VWAP → BB → ST → GOM → Bias → Order → TA → Decision
  │   • Decision: "🟡 SELL en attente"
  │
  ├─ ÉTAPE 4: Send via PsychoBot
  │   • POST to psychobot-1si7.onrender.com/send-message
  │   • Phone: +2290196911346
  │   • Message: 8 sections, 800 chars
  │   • ✅ HTTP 200 → Success
  │   • ❌ Timeout → Fallback to whatsapp_alerts.log
  │
  └─ BONUS: Save trading signals
     • gom_signal.json ← verdict + decision
     • opportunities.json ← 3 setups for TradeManager

[T+0:05] TradeManager.mq5 OnTick()
  │
  ├─ LoadGOMSignalFromFile() → "SELL" verdict
  │
  ├─ LoadOpportunitiesFromFile()
  │   • OPP-001: SELL @ 4508.5, R:R 2.5, 75% confidence
  │   • OPP-002: BUY @ 4504.5, R:R 2.0, 60% confidence
  │   • OPP-003: SELL @ 4495.0, R:R 3.0, 55% confidence
  │
  └─ Execute opportunities
     • Check price vs entry
     • If aligned, open trade with SL/TP
     • Apply trailing stop
     • Monitor for GOM opposite signal → close

[T+20:00] Next cycle (message + signals updated)
```

---

## Troubleshooting

### Problem: Duplicate WhatsApp messages

**Before:** Multiple monitor scripts all sending independently
**Fix:** Kill orphans, run ONLY xauusd_central_monitor.py

```bash
# Verify only ONE process running:
ps aux | grep xauusd
# Should show ONE line for xauusd_central_monitor.py
```

### Problem: Empty WhatsApp messages

**Before:** Message construction failed but still sent
**Fix:** Central Monitor now validates message before sending (800+ chars)

```python
if len(msg) < 100:
    print("❌ Message too short, skipping")
    return False
```

### Problem: TradeManager ignores GOM verdict

**Before:** TradeManager polled /gom-verdict endpoint (broken)
**Fix:** TradeManager now reads gom_signal.json file (always available)

```python
if LoadGOMSignalFromFile(verdict, scoreBuy, scoreSell, decision):
    # Execute trade based on verdict
    if verdict == "SELL":
        # Open SELL trade from opportunity
```

### Problem: TradingView opportunities not reaching MT5

**Before:** No communication between chart and EA
**Fix:** Central Monitor writes opportunities.json, TradeManager reads it

```python
# MT5 can now read:
# • Entry price
# • SL + TP
• Confidence score
# • Timeframe (for filtering)
```

---

## Key Improvements

| Issue | Before | After |
|-------|--------|-------|
| **Process Count** | 20+ independent scripts | 1 central monitor |
| **Message Duplicates** | Multiple copies sent | Single message per cycle |
| **Empty Messages** | Yes (validation failed) | No (pre-validated) |
| **GOM Signal to MT5** | HTTP polling (broke) | File-based (reliable) |
| **Opportunities to MT5** | Not passed at all | JSON file with 3 setups |
| **Fallback** | None (messages lost) | whatsapp_alerts.log |
| **Startup** | Manual, fragile | START_COMPLETE_SYSTEM.bat |

---

## Next Steps

1. **Test Central Monitor:**
   ```bash
   python D:\Dev\TradBOT\xauusd_central_monitor.py
   # Verify: gom_signal.json + opportunities.json created
   # Verify: WhatsApp message sent (HTTP 200)
   ```

2. **Test TradeManager Signal Reading:**
   - Attach TradeManager to XAUUSD chart
   - Check logs: `[TradeManager] ✅ GOM signal loaded: SELL`
   - Check logs: `[TradeManager] ✅ Opportunities loaded: 3 setups`

3. **Execute First Trade:**
   - Central Monitor runs → creates opportunities.json
   - TradeManager reads → opens trade on OPP-001 if price near 4508.5
   - Trailing stop activates automatically

4. **Schedule 20-min Loop (Optional):**
   - Modify `run_once()` to `run_loop(1200)` in xauusd_central_monitor.py
   - Set Windows Task Scheduler to launch at startup

---

## Files Modified/Created

- ✅ `xauusd_central_monitor.py` (NEW) — Centralized monitor
- ✅ `data/gom_signal.json` (NEW) — Verdict file
- ✅ `data/opportunities.json` (NEW) — Setups file
- ✅ `TradeManager.mq5` (MODIFIED) — Added LoadGOMSignalFromFile() + LoadOpportunitiesFromFile()
- ✅ `START_COMPLETE_SYSTEM.bat` (NEW) — Unified startup
- ✅ `SYSTEM_ARCHITECTURE_UNIFIED.md` (NEW) — This doc

---

## Cleanup

Delete all orphaned scripts:
```bash
rm D:\Dev\TradBOT\xauusd_production_monitor.py
rm D:\Dev\TradBOT\xauusd_unified*.py
rm D:\Dev\TradBOT\xauusd_complete*.py
rm D:\Dev\TradBOT\unified_xauusd*.py
rm D:\Dev\TradBOT\xauusd_4etapes*.py
rm D:\Dev\TradBOT\send_*.py
rm D:\Dev\TradBOT\test_monitor.py
# Keep ONLY: xauusd_central_monitor.py
```

---

**Status:** ✅ Architecture redesigned for unified, reliable operation.
