# GOM Sync 10-Minute Scheduling Setup

## Overview

The GOM Sync system runs the `gom_sync_with_report.py` script every 10 minutes to:
1. Load GOM verdicts from the AI server (live MT5 dashboard)
2. Apply trading gates (coherence, RSI, session windows, etc.)
3. Place market orders for eligible signals
4. Send reports via WhatsApp (AI server or PsychoBot fallback)
5. Log all activities to `logs/gom_sync.log`

## Current Status

✅ **Script**: `Python/gom_sync_with_report.py` — operational
✅ **Wrapper**: `scripts/run-gom-sync-10min.bat` — ready
✅ **Task**: `TradBOT-GOM-Sync-10min` — may need admin reconfiguration

## Setup Instructions

### Option 1: Manual Setup via PowerShell (RECOMMENDED)

**Run as Administrator:**

```powershell
# Navigate to project
cd D:\Dev\TradBOT

# Execute setup script
.\scripts\setup-gom-task.ps1
```

This creates a 10-minute scheduled task that runs:
- **Executable**: `D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat`
- **Schedule**: Every 10 minutes, starting immediately
- **Duration**: 23 hours 50 minutes (restarts Windows needed)
- **Timeout**: 5 minutes per run

### Option 2: Manual Setup via Task Scheduler GUI

1. Open **Task Scheduler** (`taskschd.msc`)
2. Create folder `\TradBOT` if missing
3. Create new task:
   - **Name**: `TradBOT-GOM-Sync-10min`
   - **Path**: `\TradBOT\`
   - **Trigger**: Repeat every 10 minutes (starting now)
   - **Action**:
     - Program: `D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat`
     - Start in: `D:\Dev\TradBOT`
   - **Settings**:
     - Allow task to be run on demand: ✓
     - Run task as soon as possible after a scheduled start is missed: ✓
     - Time limit: 5 minutes

### Option 3: Manual Uninstall

```powershell
.\scripts\setup-gom-task.ps1 -Uninstall
```

## Manual Execution

To run one iteration immediately:

```bash
cd D:\Dev\TradBOT
python Python\gom_sync_with_report.py --report
```

To run in continuous loop (Ctrl+C to stop):

```bash
cd D:\Dev\TradBOT
python Python\gom_sync_with_report.py
```

## Logs

All activities logged to: `D:\Dev\TradBOT\logs\gom_sync.log`

View latest entries:

```bash
tail -50 D:\Dev\TradBOT\logs\gom_sync.log
```

## Troubleshooting

### Task shows error code 2147942402

**Cause**: File path or Python executable not found  
**Solution**: Run `setup-gom-task.ps1` with admin rights

### Task never runs

**Check**:
1. Task Scheduler is running: `net start Schedule`
2. Task exists: `powershell "Get-ScheduledTask -TaskPath '\TradBOT\' -TaskName '*GOM*'"`
3. Next run time is set correctly
4. Check logs for errors: `tail -100 logs/gom_sync.log | grep ERROR`

### Python path issues

The wrapper script auto-detects Python via `where python`. If it fails:

```bash
# Verify Python is in PATH
python --version

# If not found, add Python to PATH or update script
```

## Gates & Configuration

The script applies multiple trading gates before placing orders:

| Gate | Condition | Bypass |
|------|-----------|--------|
| **Coherence** | `>= 70%` minimum (gates: 85% internal for market orders) | None |
| **RSI Extreme** | Reject BUY if RSI > 78, SELL if RSI < 22 | None |
| **M15 Conflict** | Reject if M15 direction opposes verdict | Spike confirmation |
| **Session Window** | Symbol must be in trading hours UTC | None |
| **Direction** | Boom=BUY only, Crash=SELL only | None |
| **Position** | No duplicate positions on same symbol | None |
| **Pause (Win Streak)** | 3 consecutive wins → 1 hour pause | Automatic reset after loss |

## WhatsApp Reports

Reports are sent via two channels (in order of preference):

1. **AI Server** (`http://127.0.0.1:8000/notify-whatsapp`)
2. **PsychoBot Render** (fallback, `https://psychobot-1si7.onrender.com/send-message`)

Report format example:

```
🎯 **GOM VERDICTS REPORT** 📊
==================================================
🟢 BOOM 300 INDEX — PERFECT BUY | Entry: 899.73 | SL: 897.03 | TP: 905.13 | Coh: 83%
  🟢M5 🟢M15 🟢H1
  🤖 ML: 🟢BUY 95% | acc=78%
🔴 XAUUSD — SELL | Entry: 4324.55 | SL: 4336.72 | TP: 4300.21 | Coh: 83%
  🔴M1 🔴M5 🟢H1
==================================================
📅 2026-06-16 16:26:47 UTC
```

## Performance Notes

- **Typical runtime**: 10–30 seconds per iteration
- **MT5 Dashboard queries**: Up to 15 symbols in parallel
- **Timeout per request**: 5 seconds per HTTP call
- **Log file rotation**: None (grows indefinitely — monitor size)

To clean up old logs:

```bash
# Backup and reset
cp D:\Dev\TradBOT\logs\gom_sync.log D:\Dev\TradBOT\logs\gom_sync.log.backup
echo. > D:\Dev\TradBOT\logs\gom_sync.log
```

## Next Steps

1. ✅ Run setup: `.\scripts\setup-gom-task.ps1`
2. ✅ Test manually: `python Python\gom_sync_with_report.py --report`
3. ✅ Monitor logs: `tail -f logs/gom_sync.log`
4. ✅ Verify WhatsApp messages received
5. ✅ Check Task Scheduler for 10-minute execution pattern

---

**Last Updated**: 2026-06-16  
**Author**: Claude Code  
**Status**: Production Ready ✅
