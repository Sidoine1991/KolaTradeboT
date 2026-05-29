# 🚀 AUTO-COMPILE SYSTEM — Complete Automation Guide

## Overview

This system automates the complete compilation and trading startup process:

1. ✅ Closes existing MT5/MetaEditor
2. ✅ Recompiles TradeManager.mq5 and SpikeRiderEA.mq5
3. ✅ Launches MT5 Terminal
4. ✅ Verifies EA parameters
5. ✅ Monitors trading activity

## Quick Start

### Option 1: Full Automated (Recommended)
```bash
D:\Dev\TradBOT\START_TRADING_SYSTEM.bat
```

This runs:
1. Auto-compile Python script
2. Waits 30 seconds for MT5 to load
3. Verification checks
4. Displays instructions

### Option 2: Manual Compilation Only
```bash
D:\Dev\TradBOT\RUN_AUTO_COMPILE.bat
```

Or directly:
```bash
cd D:\Dev\TradBOT
python auto_compile.py
```

### Option 3: Monitor Only
```bash
D:\Dev\TradBOT\python monitor_eas.py
```

Check current EA status without recompiling.

---

## What Gets Compiled

### TradeManager.mq5
✅ **Modifications:**
- `GOMBlockOnWait = false` (Line 116) — WAIT verdicts don't block trades
- `GOMMinCoherence = 50.0` (Line 112) — Lowered from 70% for more entries
- `MinTAConfidence = 0.40` (Line 92) — Lowered from 55% for sensitivity
- `GoldMaxRSI = 80.0` (Line 134) — Raised from 70% for less overbought filter

**Result:** More trades execute, fewer false blockers.

### SpikeRiderEA.mq5
✅ **Modifications:**
- `InpGOMBlockOnWait = false` (Line 132) — WAIT doesn't block spike trades
- `InpSniperMinConfidence = 50.0` (Line 104) — Lowered from 80% for early detection
- `InpZScoreMin = 1.5` (Line 36) — Lowered from 2.0 for sensitivity

**Result:** Spike detection more responsive, enters earlier.

---

## Files Created

| File | Purpose |
|------|---------|
| `auto_compile.py` | Main Python compilation script |
| `RUN_AUTO_COMPILE.bat` | Batch wrapper for auto_compile.py |
| `START_TRADING_SYSTEM.bat` | Full orchestration (compile + verify + monitor) |
| `monitor_eas.py` | Check EA status without recompiling |
| `COMPILATION_GUIDE.md` | Detailed compilation documentation |
| `FORCE_RELOAD_EAS.bat` | Legacy batch script (alternative) |

---

## Execution Flow

```
START_TRADING_SYSTEM.bat
    │
    ├─→ RUN_AUTO_COMPILE.bat
    │       │
    │       └─→ auto_compile.py
    │           ├─ Verify source modifications
    │           ├─ Kill terminal64.exe
    │           ├─ Kill MetaEditor64.exe
    │           ├─ Compile TradeManager.mq5 (F9)
    │           ├─ Compile SpikeRiderEA.mq5 (F9)
    │           └─ Launch terminal64.exe
    │
    ├─→ Wait 30 seconds (MT5 loading)
    │
    └─→ monitor_eas.py
        ├─ Check MT5 running
        ├─ Verify parameters
        ├─ Read Expert logs
        └─ Report status
```

---

## Expected Behavior After Compilation

### Terminal Console Output
```
[08:25:00] ✅ Verifying source modifications
  ✓ GOMBlockOnWait disabled
  ✓ GOMMinCoherence lowered to 50%
  ✓ MinTAConfidence lowered to 40%

[08:25:05] ✅ Closing existing MT5 and MetaEditor

[08:25:10] 🔨 Compiling TradeManager.mq5...
  ✅ TradeManager compiled successfully

[08:25:20] 🔨 Compiling SpikeRiderEA.mq5...
  ✅ SpikeRiderEA compiled successfully

[08:25:30] ✅ Launching MT5 Terminal
  ✅ Process terminal64.exe started
```

### MT5 Expert Advisor Logs (F2)
Look for these messages indicating successful EA execution:

```
[GOM-Auto] ✅ XAUUSD: GOM=PERFECT BUY (vnum=3) — SIGNAL ACCEPTÉ ✅
[GOM-Auto] 🟢 XAUUSD BUY autorisé — confiance 60% >= 50% (ABAISSÉ) ✅
[GOM-Auto] 📦 ORDER OPENED: XAUUSD BUY @ 4512.16

[SpikeRider] ✅ Init v5.03 | Boom 600 Index | BUY only
[SpikeRider] TV bridge Boom 600 Index | sniper=ready 55% ✅
[SpikeRider] ✅ SPIKE DETECTED Z-Score=1.8
```

---

## Troubleshooting

### Problem: "Python not found in PATH"
**Solution:**
```bash
# Install Python from: https://www.python.org/downloads/
# Or add Python to PATH manually
```

### Problem: "Compilation fails with syntax errors"
**Solution:**
1. Open MetaEditor manually
2. Open the file with the error
3. Check the line numbers in the error message
4. Review the modification we made on that line
5. Recompile with F9

### Problem: "Trades still not executing after compilation"
**Solution:**
1. Verify in MT5: Tools > Options > Experts > Allow algorithmic trading = ✓
2. Attach EAs to charts:
   - XAUUSD M1 → TradeManager
   - Boom 600 M1 → SpikeRiderEA
3. Check F2 logs for [GOM-Auto] and [SpikeRider] messages
4. Verify parameters in EA Inputs tab match expected values

### Problem: "MetaEditor won't close after compilation"
**Solution:**
```bash
# Kill it manually
taskkill /F /IM MetaEditor64.exe
```

---

## Manual Verification Checklist

After running START_TRADING_SYSTEM.bat, verify in MT5:

- [ ] Terminal → Options → Allow algorithmic trading = ✓
- [ ] Terminal → Options → Allow DLL imports = ✓
- [ ] F2 Logs → See [GOM-Auto] messages
- [ ] F2 Logs → See [SpikeRider] messages
- [ ] Charts → TradeManager attached to XAUUSD M1
- [ ] Charts → SpikeRiderEA attached to Boom/Crash indices
- [ ] whatsapp_alerts.log → New entries appearing

---

## Monitoring After Startup

### Real-time Monitoring
```bash
# Run anytime to check status
python D:\Dev\TradBOT\monitor_eas.py
```

### Trade Log
```bash
# View recent trades
type D:\Dev\TradBOT\whatsapp_alerts.log | tail -50
```

### MT5 Expert Logs
In MT5:
1. Press F2
2. Search for `[GOM-Auto]` or `[SpikeRider]`
3. Trades will show as `ORDER OPENED` messages

---

## System Requirements

- **Python 3.7+** (for auto-compilation)
- **MetaTrader 5** (latest version)
- **Windows 10/11** (64-bit recommended)
- **Git Bash or CMD** (for running batch scripts)

---

## Key Parameters After Compilation

| Parameter | Value | Effect |
|-----------|-------|--------|
| `GOMBlockOnWait` | false | WAIT verdicts won't block trades |
| `GOMMinCoherence` | 50% | More entries allowed (was 70%) |
| `MinTAConfidence` | 40% | Lower confidence threshold (was 55%) |
| `InpSniperMinConfidence` | 50% | Spikes detected earlier (was 80%) |
| `InpZScoreMin` | 1.5 | More sensitive spike detection (was 2.0) |

---

## Next Steps

1. **Run the startup script:**
   ```bash
   START_TRADING_SYSTEM.bat
   ```

2. **Wait 40 seconds** for full MT5 initialization

3. **Manually attach EAs** to charts (can't be automated)

4. **Monitor F2 logs** for EA activity

5. **Check whatsapp_alerts.log** for trade records

---

## Support

If issues occur:
1. Check `whatsapp_alerts.log` for recent activity
2. Run `monitor_eas.py` to verify system state
3. Review MT5 Expert logs (F2) for error messages
4. Check that source files haven't been corrupted

---

**Status:** ✅ Automation scripts ready to use  
**Last Updated:** 2026-05-29  
**Compiled by:** TradBOT Automation System
