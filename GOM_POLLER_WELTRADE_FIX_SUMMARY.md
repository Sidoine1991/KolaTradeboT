# GOM Poller - Weltrade Support Fix (2026-06-18)

## Problem
Le GOM poller ne prenait en compte **QUE les symboles Deriv**, pas les symboles Weltrade (PAINX, GAINX, FXVOL) du second terminal.

**Impact**: Verdicts GOM jamais reçus pour Weltrade → IA HOLD jamais override → aucun trade exécuté

---

## Solution Implemented

### 1. **Updated master_gom_poller.py** ✅
Added Weltrade symbol mappings to TradingView:
```python
# Weltrade symbols (mapped to DERIV equivalents for GOM Pine script)
"PAINX":    "DERIV:BOOM_500_INDEX",      # Weltrade Boom = Deriv Boom
"GAINX":    "DERIV:CRASH_500_INDEX",     # Weltrade Crash = Deriv Crash
"FXVOL":    "DERIV:VOLATILITY_75_INDEX", # Weltrade Vol = Deriv Vol
"SFVVOL":   "DERIV:VOLATILITY_75_INDEX", # Weltrade Stock Vol = Deriv Vol
```

Added to `_DEFAULT_SYMBOLS`:
```python
_DEFAULT_SYMBOLS = [
    # ... existing Deriv symbols ...
    # Weltrade symbols (added 2026-06-18)
    "PAINX", "GAINX", "FXVOL",
]
```

**Status**: ✅ Weltrade symbols will be polled via TradingView CDP

---

### 2. **Updated gom_mt5_poller.py** ✅
Added Weltrade symbols to the default polling list:
```python
DEFAULT_SYMBOLS: List[str] = [
    # Deriv symbols
    "Boom 1000 Index", "Boom 500 Index", "Crash 1000 Index", "Crash 500 Index",
    # Weltrade symbols (added 2026-06-18)
    "PAINX", "GAINX", "FXVOL",
]
```

**Status**: ✅ BUT: This poller only connects to the **default terminal** (Deriv). 
Weltrade symbols will be ignored if only Deriv terminal is active.

---

### 3. **Created NEW: gom_multiterminal_poller.py** ✅
A brand new poller that connects to **BOTH terminals simultaneously**:

```
Terminal 1 (Deriv)         Terminal 2 (Weltrade)
    ↓                           ↓
   [Boom/Crash/Vol]        [PAINX/GAINX/FXVOL]
    ↓                           ↓
    └─────────→ GOM Calculator (local, no TradingView needed)
                    ↓
                POST /gom-verdict (ai_server :8000)
                    ↓
                [Verdicts for ALL symbols]
```

**Features**:
- Connects to both MT5 terminals via Python MetaTrader5 API
- Polls Deriv symbols from Terminal 1
- Polls Weltrade symbols from Terminal 2
- Sends all verdicts to `/gom-verdict` endpoint
- Terminal info tagged in payload (`"terminal": "deriv"` or `"terminal": "weltrade"`)

**Usage**:
```bash
python python/gom_multiterminal_poller.py              # 30s interval, both terminals
python python/gom_multiterminal_poller.py --interval 60 # faster polling
python python/gom_multiterminal_poller.py --once        # single tour
```

**Status**: ✅ **RECOMMENDED** — Use this for full multi-terminal support

---

## How GOM Poller Now Works

### Flow Diagram:

```
┌─────────────────────────────────────────────────────────────┐
│                   AI Server (:8000)                         │
│                                                             │
│  ┌────────────────────────────────────────────────────┐    │
│  │  /gom-verdict  (receives verdicts from pollers)    │    │
│  │  /gom-kola-dashboard  (serves to EA)               │    │
│  └────────────────────────────────────────────────────┘    │
└──────────┬───────────────────────┬──────────────────────────┘
           ↑                       ↑
           │ POST verdicts         │ GET /gom-kola-dashboard
           │                       │
    ┌──────┴────────┐      ┌───────┴────────┐
    │  POLLER 1     │      │  SMC_Universal │
    │  (Deriv)      │      │  EA on MT5     │
    │               │      │                │
    │ • Boom 500    │      │ • Triggers     │
    │ • Crash 500   │      │   override     │
    │ • XAUUSD      │      │ • Places       │
    └───────────────┘      │   orders       │
                           └────────────────┘
    ┌──────────────────────────────────────┐
    │  POLLER 2 (NEW)                      │
    │  gom_multiterminal_poller.py         │
    │                                      │
    │ • Deriv Terminal → Boom/Crash        │
    │ • Weltrade Terminal → PAINX/GAINX   │
    │ • Feeds BOTH to /gom-verdict        │
    └──────────────────────────────────────┘
```

---

## Deployment Instructions

### Option 1: Use existing poller (TradingView-based)
```bash
# Terminal Deriv must have TradingView chart with GOM indicator
python python/master_gom_poller.py --interval 30
```
✅ Works for Deriv symbols  
⚠️ Weltrade symbols not directly supported (need TradingView charts)

### Option 2: Use MT5 poller (Deriv only)
```bash
python python/gom_mt5_poller.py --interval 30
```
✅ Works for Deriv symbols locally (no TradingView)  
❌ Weltrade symbols ignored (only default terminal polled)

### Option 3: Use NEW multi-terminal poller (RECOMMENDED)
```bash
python python/gom_multiterminal_poller.py --interval 30
```
✅ Polls BOTH terminals simultaneously  
✅ Works for ALL symbols (Deriv + Weltrade)  
✅ No TradingView required  
✅ Sends verdicts for Weltrade to `/gom-verdict`

---

## Files Modified / Created

| File | Change | Impact |
|------|--------|--------|
| `python/master_gom_poller.py` | Added Weltrade symbols to _MT5_TO_TV mapping + _DEFAULT_SYMBOLS | Weltrade symbols polled via TV CDP |
| `python/gom_mt5_poller.py` | Added PAINX/GAINX/FXVOL to DEFAULT_SYMBOLS | Weltrade symbols in polling list (but only if terminal detected) |
| `python/gom_multiterminal_poller.py` | **NEW FILE** | Multi-terminal polling: Deriv + Weltrade simultaneously |
| `verify_gom_poller_weltrade.py` | **NEW FILE** | Verification script |

---

## Verification

Run this to verify Weltrade support:
```bash
python verify_gom_poller_weltrade.py
```

Expected output:
```
[1] master_gom_poller.py - Checking for Weltrade symbols...
    OK: PAINX
    OK: GAINX
    OK: FXVOL

[2] gom_mt5_poller.py - Checking for Weltrade symbols...
    OK: PAINX
    OK: GAINX
    OK: FXVOL

[3] gom_multiterminal_poller.py (NEW)...
    OK: File created
    OK: Weltrade support configured

CONCLUSION: Weltrade symbols are now polled!
```

---

## Next Steps

1. **Launch the multi-terminal poller**:
   ```bash
   python python/gom_multiterminal_poller.py
   ```

2. **Watch the logs** for Weltrade verdicts:
   ```
   [2026-06-18 13:45:23] [GOM-MultiTerminal] ✅ PAINX [weltrade] → GOOD_BUY buy=0.8 sell=0.2 coh=75%
   [2026-06-18 13:45:25] [GOM-MultiTerminal] ✅ GAINX [weltrade] → PERFECT_SELL buy=0.1 sell=0.9 coh=85%
   ```

3. **Verify EA receives verdicts**:
   - Check SMC_Universal logs for `[GOM-POLL] ✅ SUCCESS for PAINX`
   - Confirm override fires: `✅ IA HOLD OVERRIDE - GOM a signal GOOD BUY → BUY AUTORISÉ`

4. **Monitor trades**:
   - Weltrade trades should execute when GOM signals vn≥2 (GOOD/PERFECT)
   - Even if IA shows HOLD, the override will allow execution

---

## Summary

**Before**: GOM poller ignored Weltrade symbols → No verdicts for PAINX/GAINX/FXVOL  
**After**: Multi-terminal poller feeds verdicts from BOTH terminals → GOM override works for Weltrade

**Key Enabler**: `gom_multiterminal_poller.py` connects to both MT5 terminals and creates a unified `/gom-verdict` feed.

---

**Status**: ✅ **READY FOR DEPLOYMENT**

Start the poller and watch Weltrade verdicts flow into the AI server!
