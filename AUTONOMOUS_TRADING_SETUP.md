# 🤖 AUTONOMOUS TRADING SETUP — SMC_Universal + AI Server

## ✅ STATUS: READY TO ACTIVATE

Your system is **95% ready** for 100% autonomous trading. Here's what's already in place:

```
✅ SMC_Universal.mq5 (EA)
   • Listens to /gom-verdict endpoint
   • Multi-TF validation (H4 → H1 → M15 → M1)
   • Trailing Stop + Breakeven SL
   • Boom/Crash protection
   • 2% risk management

✅ AI Server (Python)
   • /gom-verdict endpoint (live verdicts)
   • /gom-verdicts endpoint (all signals)
   • /pending-order endpoint (queues orders)
   • /update-position-sl endpoint (updates SL/TP)

✅ Background Services
   • master_gom_poller.py (RUNNING — updates gom_signal.json)
   • gom_sync_scheduler.py (10 min loop — sends WhatsApp reports)
   • trademanager_position_sync.py (5 sec loop — manages trailing stops)

✅ Data Flow
   • MT5 Candles → master_gom_poller → gom_signal.json
   • gom_signal.json → /gom-verdict → SMC_Universal.mq5
   • SMC_Universal → Orders → MT5 Terminal
   • Open Positions → trademanager_position_sync → Trailing Stop Updates
```

---

## 🚀 STEP 1: LAUNCH EVERYTHING (3 Terminals)

### Terminal 1: GOM Poller (Keep Running 24/7)
```powershell
cd D:\Dev\TradBOT
python Python/master_gom_poller.py
```
**Status**: ✅ Already running (backgrounded earlier)

---

### Terminal 2: GOM Sync Scheduler (Every 10 min)
```powershell
cd D:\Dev\TradBOT
python Python/gom_sync_scheduler.py
```
**Output**: Updates verdicts, sends WhatsApp reports every 10 minutes

---

### Terminal 3: Position Monitor (Every 5 sec)
```powershell
cd D:\Dev\TradBOT
python Python/trademanager_position_sync.py
```
**Output**: Manages trailing stops, breakeven SL, profit locking

---

## 🎯 STEP 2: CONFIGURE SMC_Universal.mq5

**File**: `mt5/SMC_Universal.mq5`

Key settings already configured:
- `input int AI_Timeout_ms = 5000` — Time to wait for AI response
- `input bool DisableAllAutoEntries = false` — Set to TRUE to disable, FALSE to enable auto-trading

### Current Settings (Check in MT5 Inputs):
```
AutoTrading: YES (enabled)
AllowLiveTrading: YES (enabled)
AI_Timeout_ms: 5000 (5 second timeout)
GOM_UseAI: YES (use AI verdicts)
GOM_RequireCoherence: YES (gate: 70%+ coherence)
```

---

## ✅ STEP 3: START THE EA IN MT5

1. Open MT5 Terminal
2. Right-click **SMC_Universal** → Compile (or F5 to refresh)
3. Drag EA onto your chart (any symbol)
4. Enable AutoTrading button (toolbar)
5. Check EA Inputs:
   - `DisableAllAutoEntries` = FALSE (allow auto-trades)
   - `GOM_RequireCoherence` = TRUE (require 70%+ coherence)
   - `AllowLiveTrading` = TRUE (allow real orders)

---

## 📊 WHAT HAPPENS NEXT (Automatic)

```
🕐 EVERY 10 MIN (GOM Sync Scheduler):
  1. Load GOM verdicts from /gom-verdicts
  2. Filter: only Good/Perfect signals + coherence ≥ 70%
  3. Send WhatsApp report
  4. Queue top-3 signals to /pending-order

🕐 EVERY 5 SEC (Position Monitor):
  1. Fetch open positions
  2. Calculate trailing stop distance
  3. Activate breakeven at +$2 profit
  4. Update SL/TP via /update-position-sl

🕐 REAL-TIME (SMC_Universal.mq5):
  1. Polls /gom-verdict every time new candle forms
  2. Validates multi-TF (H4, H1, M15, M1)
  3. Checks GOM coherence ≥ 70%
  4. Places order if all gates pass
  5. Manages trailing stop automatically
  6. Protects positions with breakeven SL
```

---

## 🎯 SIGNAL FLOW (Complete)

```
MT5 Candles (M1)
    ↓
master_gom_poller.py ← LIVE DATA
    ↓
gom_signal.json (updated every 30-60 sec)
    ↓
/gom-verdict endpoint (AI Server)
    ↓
SMC_Universal.mq5 (polls every new candle)
    ↓
Multi-TF Validation:
  • H4 trend (EMA 50)
  • H1 structure (EMA 21 slope)
  • M15 momentum (RSI zone)
  • M1 entry setup
    ↓
Quality Gates:
  • Coherence ≥ 70% ✓
  • Boom/Crash rule ✓
  • Risk ≤ 2% ✓
  • Multi-TF aligned ✓
    ↓
PLACE ORDER (if all pass)
    ↓
trademanager_position_sync.py monitors
    ↓
Trailing Stop + Breakeven SL activated
```

---

## 🔍 MONITORING & LOGGING

```powershell
# Check GOM Sync logs
tail -f logs/gom_sync_scheduler.log

# Check Position Monitor logs
tail -f logs/trademanager_sync.log

# Check AI Server logs
tail -f logs/ai_server.log

# Watch all 3 processes
Get-Process python | Where-Object { $_.ProcessName -like "*python*" }
```

---

## ⚠️ KILL SWITCHES (Safety)

### Emergency Stop (Disable Auto-Trading)
**In MT5**: Uncheck "AutoTrading" button (top toolbar)

### Stop All Python Services
```powershell
# Stop individual processes
pkill -f "gom_sync_scheduler"
pkill -f "trademanager_position_sync"
pkill -f "master_gom_poller"

# Or kill all python
pkill -f python
```

### Disable EA
**In MT5**: Right-click EA → Disable

---

## 📋 PRE-LAUNCH CHECKLIST

- [ ] Master GOM Poller running (`ps aux | grep master_gom_poller`)
- [ ] gom_signal.json updated (check timestamp: `ls -l gom_signal.json`)
- [ ] AI Server running on http://127.0.0.1:8000
- [ ] MT5 Terminal open + SMC_Universal.mq5 attached to chart
- [ ] AutoTrading enabled in MT5
- [ ] DisableAllAutoEntries = FALSE in EA inputs
- [ ] AllowLiveTrading = TRUE in EA inputs
- [ ] GOM_RequireCoherence = TRUE (70%+ gate)
- [ ] Phone ready for WhatsApp alerts

---

## 🚀 READY TO GO!

Everything is set. When you're ready:

1. Make sure all 3 Python services are running
2. Start SMC_Universal.mq5 in MT5
3. The EA will automatically:
   - Poll /gom-verdict every candle
   - Validate signals against multi-TF rules
   - Place orders when gates pass
   - Manage positions with trailing stops
   - Send position updates to WhatsApp

**You will receive WhatsApp alerts every 10 minutes with:**
- GOM verdicts (entry price, SL, TP)
- Coherence score
- Multi-TF alignment
- Any position updates

---

## 💡 WHAT YOU STILL CONTROL

✅ Can start/stop at any time
✅ Can modify EA inputs (risk, timeframes, etc.)
✅ Can intervene manually if needed
✅ Can adjust quality gates
✅ Can pause specific symbols
✅ Emergency button: disable AutoTrading

---

**Last Updated**: 2026-06-12  
**System Status**: 🟢 READY FOR AUTONOMOUS TRADING
