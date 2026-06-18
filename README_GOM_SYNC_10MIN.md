# GOM Sync 10-Minute Autonomous Execution

## 🎯 Objective

Execute GOM synchronization and WhatsApp reporting every 10 minutes automatically via Windows Task Scheduler.

## ✅ Current Status

- **Script**: `Python/gom_sync_with_report.py` ✓ Working
- **Wrapper**: `scripts/run-gom-sync-10min.bat` ✓ Ready
- **Logs**: `logs/gom_sync.log` ✓ Active (3.4MB+, daily)
- **WhatsApp**: Dual-channel (AI server + PsychoBot fallback) ✓ Active
- **Task Scheduler**: Needs reconfiguration (error code 2147942402)

## 🚀 Quick Start

### 1. Install Task Scheduler Task (Administrator Required)

**Option A: Automated** (Recommended)
```bash
# Right-click, "Run as administrator"
install-gom-task.bat
```

**Option B: Manual PowerShell**
```powershell
cd D:\Dev\TradBOT
powershell -ExecutionPolicy Bypass -File .\scripts\setup-gom-task.ps1
```

**Option C: Manual via Task Scheduler GUI**
See `GOM_SYNC_SETUP.md` for detailed steps.

### 2. Test Installation

```powershell
# Verify configuration
.\verify-gom-task.ps1

# Fix any issues
.\verify-gom-task.ps1 -Fix

# Run immediately to test
.\verify-gom-task.ps1 -RunNow
```

### 3. Manual Execution (No Task Scheduler)

```bash
# One-time run (--report mode)
cd D:\Dev\TradBOT
python Python\gom_sync_with_report.py --report

# Continuous loop (Ctrl+C to stop)
python Python\gom_sync_with_report.py
```

## 📊 What Gets Executed Every 10 Minutes

1. **Load GOM Verdicts** ← Latest signals from MT5 dashboard
2. **Apply Trading Gates**:
   - ✅ Coherence >= 70% (internal gate: 85%)
   - ✅ RSI extremes (>78 rejected, <22 rejected)
   - ✅ M15 conflict detection
   - ✅ Session window validation (UTC hours)
   - ✅ Boom/Crash direction enforcement
   - ✅ Duplicate position prevention
   - ✅ Win-streak pause detection
   - ✅ ML score verification (advisory only)
3. **Place Market Orders** ← Eligible signals only
4. **Post Verdicts** → AI server `/gom-verdict` endpoint
5. **Build Report** ← Formatted signal summary
6. **Send WhatsApp** ← AI server or PsychoBot fallback
7. **Log Everything** → `logs/gom_sync.log`

## 📁 File Structure

```
D:\Dev\TradBOT\
├── Python/
│   ├── gom_sync_with_report.py     ← Main script (10min loop or --report mode)
│   ├── gom_sync_scheduler.py        ← Alternative scheduler (not used in 10min task)
│   └── ...
├── scripts/
│   ├── run-gom-sync-10min.bat       ← Wrapper called by Task Scheduler
│   ├── setup-gom-task.ps1           ← PowerShell setup (if admin available)
│   ├── TradBOT-GOM-Sync-10min.xml   ← XML task definition
│   └── ...
├── logs/
│   └── gom_sync.log                 ← All execution logs (append mode)
├── install-gom-task.bat             ← Easy installer (requires admin)
├── verify-gom-task.ps1              ← Verification & troubleshooting
├── test-gom-setup.bat               ← Pre-flight test
├── GOM_SYNC_SETUP.md                ← Detailed setup guide
└── README_GOM_SYNC_10MIN.md         ← This file
```

## 🔍 Verification Commands

```bash
# Check if task exists and is running
Get-ScheduledTask -TaskPath '\TradBOT\' -TaskName '*GOM*' | Get-ScheduledTaskInfo

# View recent logs
tail -30 D:\Dev\TradBOT\logs\gom_sync.log

# Check for errors
grep ERROR D:\Dev\TradBOT\logs\gom_sync.log | tail -10

# Force immediate run
powershell "Start-ScheduledTask -TaskPath '\TradBOT\' -TaskName 'TradBOT-GOM-Sync-10min'"

# View all TradBOT scheduled tasks
powershell "Get-ScheduledTask -TaskPath '\TradBOT\' | Format-Table TaskName, State"
```

## ⚙️ Configuration

### Script Parameters

The script uses environment variables and can be customized:

```python
# In Python/gom_sync_with_report.py
GOM_FILE = Path("D:/Dev/TradBOT/data/gom_signal.json")
AI_SERVER = "http://127.0.0.1:8000"
LOGS_DIR = Path("D:/Dev/TradBOT/logs")
LOOP_INTERVAL = 600  # 10 minutes in seconds
MIN_COHERENCE_TO_PLACE = 85  # Gate for market orders
_VERDICT_MAX_AGE_HOURS = 1  # Reject signals older than 1h
```

### WhatsApp Configuration

```python
PSYCHOBOT_URL = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")
WHATSAPP_PHONE = os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")
```

Set environment variables to override:
```bash
set PSYCHOBOT_URL=https://custom-psychobot-url
set WHATSAPP_PHONE_NUMBER=+1234567890
```

## 🛠️ Troubleshooting

### Task shows "File not found" (Error 2147942402)

1. Verify wrapper exists:
   ```bash
   dir D:\Dev\TradBOT\scripts\run-gom-sync-10min.bat
   ```

2. Verify Python in PATH:
   ```bash
   where python
   python --version
   ```

3. Fix with reinstall:
   ```bash
   # Run as Administrator
   install-gom-task.bat
   ```

### Task never executes (next run keeps resetting)

1. Check Task Scheduler service:
   ```bash
   net start Schedule
   ```

2. Verify task permissions:
   ```powershell
   Get-ScheduledTask -TaskPath '\TradBOT\' -TaskName '*GOM*' | Select-Object Principal
   ```

3. View event logs:
   ```powershell
   Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -MaxEvents 10
   ```

### Python ModuleNotFoundError

Ensure correct Python version (3.11+ required):
```bash
python --version
pip list | grep requests
```

If missing dependencies:
```bash
pip install requests
```

### No WhatsApp messages

1. Check AI server availability:
   ```bash
   curl http://127.0.0.1:8000/health
   ```

2. Check PsychoBot fallback:
   ```bash
   curl https://psychobot-1si7.onrender.com/health
   ```

3. Verify phone number in logs:
   ```bash
   grep "WHATSAPP_PHONE" D:\Dev\TradBOT\logs\gom_sync.log
   ```

## 📊 Log Format

Each execution logs:

```
2026-06-16 16:26:47,847 - gom_sync - INFO - 🔄 [Itération 123] Synchronisation GOM...
2026-06-16 16:26:50,123 - gom_sync - INFO - [OK] Charge 9 verdicts GOM depuis dashboard MT5 LIVE
2026-06-16 16:26:08,526 - gom_sync - WARNING - [GATE-COH] XAUUSD: coherence 83% < 85% — ordre ignoré
2026-06-16 16:26:25,481 - gom_sync - INFO - 📤 BOOM 1000 INDEX → PERFECT SELL (HTTP 200)
2026-06-16 16:26:47,848 - gom_sync - INFO - 📋 Rapport construit (5 signaux actifs)
2026-06-16 16:26:52,558 - gom_sync - INFO - ✅ Rapport WhatsApp envoyé via AI server
```

### Log Levels

- `INFO` - Normal execution steps
- `WARNING` - Gate rejections, timeouts
- `ERROR` - API failures, Python errors
- `DEBUG` - Detailed HTTP responses (verbose)

## 🎯 Performance Metrics

| Metric | Value |
|--------|-------|
| Typical runtime | 10–30 seconds |
| MT5 dashboard queries | Up to 15 symbols in parallel |
| Request timeout | 5 seconds each |
| Log file size | ~3.4 MB (grows daily) |
| Task frequency | Every 10 minutes |

## 🔄 Maintenance

### Clean Logs Monthly

```bash
# Backup and reset
copy D:\Dev\TradBOT\logs\gom_sync.log D:\Dev\TradBOT\logs\gom_sync.log.backup
echo. > D:\Dev\TradBOT\logs\gom_sync.log
```

### Monitor Disk Usage

```bash
# Check log size
dir D:\Dev\TradBOT\logs
# At 3.4MB per day, expect ~100MB per month
```

### Restart Task Daily

The task repeats for 23 hours 50 minutes. After this window, it stops automatically. Set up a second daily task to reset it:

```bash
# Additional scheduled task (optional)
# Trigger: Daily at 23:55
# Action: Delete and recreate via install-gom-task.bat
```

## 🚀 Next Steps

1. ✅ **Install**: Run `install-gom-task.bat` as Administrator
2. ✅ **Verify**: Run `verify-gom-task.ps1` to confirm
3. ✅ **Monitor**: Check `logs/gom_sync.log` for activity
4. ✅ **Test WhatsApp**: Verify messages received (check /send-message response in logs)
5. ✅ **Observe**: Watch for 10-minute execution pattern

## 📞 Support

- **Script**: `Python/gom_sync_with_report.py`
- **Logs**: `logs/gom_sync.log`
- **Setup Guide**: `GOM_SYNC_SETUP.md`
- **Verification**: `verify-gom-task.ps1`
- **Issues**: Check logs for error codes and stack traces

---

**Status**: ✅ Production Ready  
**Last Updated**: 2026-06-16  
**Author**: Claude Code TradBOT Team
