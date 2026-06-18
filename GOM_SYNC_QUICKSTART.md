# GOM Sync + WhatsApp Report — 10-Minute Loop

## ✅ Status: READY TO DEPLOY

All components are installed and functional:
- ✅ Script: `Python/gom_sync_with_report.py` (33KB, complete)
- ✅ PowerShell wrapper: `gom_sync_loop.ps1`
- ✅ Task installer: `install_gom_sync_task.bat`
- ✅ Logs: `logs/gom_sync.log` and `logs/gom_sync_loop.log`

---

## 🚀 Quick Start

### Option 1: Run Once (Test)

```bash
cd D:/Dev/TradBOT
python Python/gom_sync_with_report.py --report
```

**Output:**
- Loads GOM verdicts from `data/gom_signal.json`
- Posts each verdict to `/gom-verdict` on ai_server:8000
- Generates WhatsApp report with format:
  ```
  🟢 XAUUSD — BUY | Entry: 6031.70 | SL: 6025.81 | TP: 6038.78
  ```
- Sends report via PsychoBot WhatsApp or AI server
- Logs to `logs/gom_sync.log`

### Option 2: Run 10-Minute Loop (Interactive)

```powershell
powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1
```

**Features:**
- Runs every 10 minutes
- Logs each iteration to `logs/gom_sync_loop.log`
- Press Ctrl+C to stop
- Shows success/error counts

### Option 3: Install Windows Task Scheduler (Production)

**Requires Admin:**

```batch
install_gom_sync_task.bat install
```

**Result:**
- Task name: `TradBOT-GOM-Sync-10min`
- Runs every 10 minutes automatically
- Starts with Windows
- Run as SYSTEM user

**Check status:**
```batch
install_gom_sync_task.bat status
```

**Remove task:**
```batch
install_gom_sync_task.bat uninstall
```

---

## 📊 What It Does

### Phase 1: Load GOM Verdicts
```
Priority 1: /gom-kola-dashboard (MT5 live, real-time)
  ↓ Fallback
Priority 2: /gom-verdicts (AI server store)
  ↓ Fallback
Priority 3: data/gom_signal.json (local JSON)
```

### Phase 2: Validate & Filter
- **Coherence gate**: Only orders with coherence_pct ≥ 70%
- **Direction gate**: Boom=BUY only, Crash=SELL only
- **Trading window**: Respect UTC session hours
- **MTF coherence**: Verify 4/6 timeframes align
- **RSI filter**: Reject overbought/oversold extremes

### Phase 3: Place Orders
- Posts validated verdicts to `/gom-verdict` endpoint
- Enforces SL/TP safeguards for synthetics (CRASH/BOOM)
- Deduplicates by symbol

### Phase 4: Generate Report
```
🎯 **GOM VERDICTS REPORT** 📊
==================================================
🟢 BOOM 900 INDEX — PERFECT BUY | Entry: 9156.29 | SL: 9146.69 | TP: 9175.47 | Coh: 83%
  🟢M1 🟢M5 🟢M15 🟢H1 🟢H4 🔴D1
  🤖 ML: 🟢BUY 95% | acc=88%

🔴 CRASH 300 INDEX — PERFECT SELL | Entry: 1827.75 | SL: 1841.12 | TP: 1801.02 | Coh: 83%
  🔴M1 🔴M5 ⚪M15 ⚪H1 🔴H4 ⚪D1

🟢 BTCUSD — SELL | Entry: 65811.64 | SL: 65937.44 | TP: 65622.93 | Coh: 83%
  🔴M1 🔴M5 🔴M15 🔴H1 🟢H4 🔴D1
==================================================
📅 2026-06-17 08:30:15 UTC
```

### Phase 5: Send WhatsApp
- **Primary**: Via `/notify-whatsapp` on AI server:8000
- **Fallback**: Via PsychoBot Render (`https://psychobot-1si7.onrender.com`)
- **Recipient**: Phone number from `WHATSAPP_PHONE_NUMBER` env var

---

## 📁 File Structure

```
D:/Dev/TradBOT/
├── Python/
│   └── gom_sync_with_report.py    (Main script — 33KB)
├── gom_sync_loop.ps1              (PowerShell wrapper)
├── install_gom_sync_task.bat      (Windows Task Scheduler installer)
├── data/
│   └── gom_signal.json            (GOM verdicts source)
└── logs/
    ├── gom_sync.log               (Script output)
    └── gom_sync_loop.log          (Loop wrapper output)
```

---

## 🔧 Configuration

### Environment Variables (Optional)

```bash
# AI Server endpoint (default: http://127.0.0.1:8000)
export AI_SERVER=http://127.0.0.1:8000

# WhatsApp bot URL (default: PsychoBot Render)
export PSYCHOBOT_URL=https://psychobot-1si7.onrender.com

# WhatsApp recipient phone (default: Sidoine)
export WHATSAPP_PHONE_NUMBER=+2290196911346
```

### Loop Interval

**Run every 5 minutes:**
```powershell
powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1 -IntervalMinutes 5
```

**Run once (no loop):**
```powershell
powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1 -RunOnce
```

---

## 📋 Logs

### Real-Time Monitoring

```bash
# Follow the log file (Windows)
Get-Content logs/gom_sync.log -Wait

# Or tail-like (PowerShell)
powershell -Command "Get-Content logs/gom_sync_loop.log -Tail 50 -Wait"
```

### Log Format

```
2026-06-17 08:30:15 - gom_sync - INFO - [OK] Charge 3 verdicts GOM depuis dashboard MT5 LIVE
2026-06-17 08:30:16 - gom_sync - INFO - 📤 BOOM 900 INDEX → PERFECT BUY (HTTP 200)
2026-06-17 08:30:17 - gom_sync - INFO - ✅ Rapport WhatsApp envoyé via AI server
2026-06-17 08:30:17 - gom_sync - INFO - 📋 Rapport construit (3 signaux actifs)
```

---

## ✨ Features

| Feature | Status |
|---------|--------|
| Load GOM from MT5 live dashboard | ✅ Working |
| Fallback to AI server store | ✅ Working |
| Fallback to local JSON | ✅ Working |
| Validate coherence ≥ 70% | ✅ Working |
| Enforce Boom=BUY / Crash=SELL | ✅ Working |
| Trading window filters | ✅ Working |
| MTF coherence checks | ✅ Working |
| RSI overbought/oversold filters | ✅ Working |
| Post to `/gom-verdict` | ✅ Working |
| SL/TP safeguards (synthetics) | ✅ Working |
| Order deduplication | ✅ Working |
| Generate formatted report | ✅ Working |
| Send via AI server WhatsApp | ✅ Working |
| Fallback to PsychoBot | ✅ Working |
| 10-minute loop | ✅ Working |
| Windows Task Scheduler | ✅ Working |
| Comprehensive logging | ✅ Working |

---

## 🐛 Troubleshooting

### No verdicts loaded
- Check `data/gom_signal.json` exists and has valid data
- Verify AI server is running: `curl http://127.0.0.1:8000/health`
- Check logs: `type logs/gom_sync.log | findstr ERROR`

### WhatsApp not sending
- Verify `WHATSAPP_PHONE_NUMBER` env var is set correctly
- Check PsychoBot is online: `curl https://psychobot-1si7.onrender.com/health`
- Try direct: `python Python/gom_sync_with_report.py --report`

### Task not running
- Verify admin rights: `run as administrator`
- Check Task Scheduler: `schtasks /query /tn TradBOT-GOM-Sync-10min /v`
- View task history: Event Viewer → Windows Logs → System

### Python not found
- Ensure Python 3.11+ is in PATH: `python --version`
- Or use full path: `C:\Users\USER\AppData\Local\Programs\Python\Python314\python.exe`

---

## 📞 Support

| Issue | Solution |
|-------|----------|
| Loop only runs once | Remove `--report` flag or use `--RunOnce` |
| SSL certificate error | Add `verify=False` to requests (dev only) |
| Permission denied (logs) | Check `logs/` folder permissions |
| Port 8000 already in use | Change `AI_SERVER` env var to different port |
| Timeout errors | Increase timeout in script (line ~95, default=5s) |

---

## 🎯 Next Steps

1. **Test once:**
   ```bash
   cd D:/Dev/TradBOT
   python Python/gom_sync_with_report.py --report
   ```

2. **Check logs:**
   ```bash
   type logs/gom_sync.log
   ```

3. **Run 10-minute loop (interactive):**
   ```powershell
   powershell -ExecutionPolicy Bypass -File gom_sync_loop.ps1
   ```

4. **Deploy to Windows Task Scheduler:**
   ```batch
   install_gom_sync_task.bat install
   ```

5. **Monitor:**
   ```batch
   install_gom_sync_task.bat status
   ```

---

## 📝 Notes

- All times are **UTC** (not local)
- SL/TP are enforced server-side before MT5 posting
- Verdicts older than 1 hour are rejected
- Deduplication keeps the newest verdict per symbol
- Reports are generated every loop cycle
- Windows Task Scheduler runs as SYSTEM (no console window)
