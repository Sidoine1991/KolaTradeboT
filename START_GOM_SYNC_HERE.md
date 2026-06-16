# 🚀 START GOM SYNC HERE

## Quick Launch (Choose One)

### 1️⃣ **Python Daemon** (Recommended)
```bash
cd D:\Dev\TradBOT
python Python/gom_sync_with_report.py
```
→ **Result**: Infinite loop, 10-minute intervals, stays in terminal

---

### 2️⃣ **Batch Script** (Easier)
```cmd
Double-click: start_gom_daemon.bat
```
→ **Result**: Opens window, 10-minute loop, Ctrl+C to stop

---

### 3️⃣ **Windows Task Scheduler** (Background)
```powershell
cd D:\Dev\TradBOT
.\schedule_gom_sync_10min.ps1
```
→ **Result**: Runs silently every 10 minutes in background

---

### 4️⃣ **Manual Test** (One-time)
```bash
cd D:\Dev\TradBOT
python Python/gom_sync_with_report.py --report
```
→ **Result**: Executes once, shows output, exits

---

## What Happens Every 10 Minutes

```
✓ Load GOM verdicts from MT5 live dashboard
✓ Apply safety gates (RSI, M15, session, Boom/Crash)
✓ Process signal changes (WAIT→close, GOOD→PERFECT)
✓ Place market orders (if coherence ≥85%)
✓ Build formatted report with TF directions
✓ Send WhatsApp notification
✓ Log everything to logs/gom_sync.log
```

---

## Status & Monitoring

### Check Logs (Real-time)
```bash
cd D:\Dev\TradBOT
tail -f logs/gom_sync.log
```

### Last Test Results
```
2026-06-16 15:52:43 UTC
✅ 3 verdicts loaded from MT5
✅ Gates applied (2 M15, 3 coherence filtered)
✅ Report sent to WhatsApp
✅ Logs written successfully
```

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "ModuleNotFoundError" | Use `C:\Python314_old\python.exe` (hardcoded in scripts) |
| No WhatsApp messages | Check AI server `/notify-whatsapp` endpoint |
| Task won't start | Run PowerShell as **Administrator** |
| Loop keeps stopping | Check `logs/gom_sync.log` for errors |

---

## Documentation

- **Full setup guide**: `GOM_SYNC_README.md`
- **Configuration**: `Python/gom_sync_with_report.py` (lines 23-28, 107-122)
- **Gates & logic**: `Python/gom_sync_with_report.py` (lines 243-260)

---

## What Gets Sent to WhatsApp

Example report (every 10 minutes):

```
🎯 **GOM VERDICTS REPORT** 📊
==================================================
🟢 BOOM 900 INDEX — GOOD BUY | Entry: 9145.91 | SL: 9143.34 | TP: 9158.94 | Coh: 67%
  🟢M1 🟢M5 🟢M15 ⚪H1 🟢H4 🔴D1

🔴 CRASH 500 INDEX — GOOD SELL | Entry: 2986.12 | SL: 2989.92 | TP: 2978.51 | Coh: 67%
  ⚪M1 ⚪M5 ⚪M15 ⚪H1 🔴H4 🔴D1

==================================================
📅 2026-06-16 15:52:43 UTC
```

---

**Ready to go!** Pick an option above and start. 🎯
