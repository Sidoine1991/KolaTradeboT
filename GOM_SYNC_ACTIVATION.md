# 🎯 GOM SYNC ACTIVATION — 10 MIN LOOP

## Status: ✅ READY TO ACTIVATE

The GOM Sync system is **fully configured**. Here's how to activate it for 24/7 autonomous reporting.

---

## 🚀 OPTION 1: One-Click Launcher (RECOMMENDED)

### Simple bat file — Just double-click and forget

```
Double-click: start-gom-sync-10min.bat
```

**What it does:**
- Launches `gom_sync_scheduler.py`
- Runs forever in a terminal window
- Loads GOM verdicts every 10 minutes
- Sends WhatsApp report every 10 minutes
- Logs everything to `logs/gom_sync_scheduler.log`

**Output:**
```
🚀 Lancement du GOM Sync Scheduler...
ℹ️  Ce processus tournera indéfiniment
ℹ️  Rapports GOM envoyés toutes les 10 minutes
ℹ️  Logs stockés dans: logs/gom_sync_scheduler.log
```

**To Stop:**
- Close the terminal window (or Ctrl+C)

---

## 🎯 OPTION 2: Windows Task Scheduler (ADVANCED)

### Runs in background 24/7 (no terminal window)

#### Step 1: Register the task

```powershell
# Open PowerShell as Administrator
cd D:\Dev\TradBOT
.\scripts\register-gom-sync-task.ps1
```

**Output:**
```
✅ Tâche enregistrée avec succès!
📊 Détails de la tâche:
  Nom: TradBOT-GOM-Sync-10min
  Chemin: \TradBOT\
  Fréquence: Toutes les 10 minutes
  Script: D:\Dev\TradBOT\Python\gom_sync_with_report.py
  Logs: D:\Dev\TradBOT\logs\gom_sync_task.log
```

#### Step 2: Verify it's running

```powershell
Get-ScheduledTask -TaskName "TradBOT-GOM-Sync-10min"
```

**Benefits:**
- ✅ Runs even if you're not logged in
- ✅ Starts automatically on reboot
- ✅ No terminal window (clean desktop)
- ✅ Logs are saved

**To Stop:**
```powershell
Unregister-ScheduledTask -TaskName "TradBOT-GOM-Sync-10min" -Confirm:$false
```

---

## 📊 WHAT HAPPENS EVERY 10 MINUTES

```
1. Load GOM verdicts from /gom-verdicts endpoint
   ↓
2. Filter verdicts:
   • Coherence ≥ 70% (quality gate)
   • Age < 1 hour (freshness check)
   • Valid direction (Boom/Crash rules)
   ↓
3. Send each verdict to /gom-verdict endpoint
   ↓
4. Build WhatsApp report
   • PERFECT signals highlighted
   • Entry/SL/TP shown
   • Multi-TF alignment indicated
   ↓
5. Send report via WhatsApp (PsychoBot)
   ↓
6. Log everything:
   • Timestamps
   • Verdicts loaded
   • Verdicts filtered
   • WhatsApp status
   • Any errors
```

---

## 📋 COMMAND: Manual One-Shot Execution

If you want to run it once manually:

```powershell
cd D:\Dev\TradBOT
python Python/gom_sync_with_report.py --report
```

**Output:**
```
[SYNC] Exécution unique GOM sync...
[OK] Charge 7 verdicts GOM depuis serveur LIVE (/gom-verdicts)
[SEND] BOOM 1000 INDEX → PERFECT BUY (HTTP 200)
[SEND] XAUUSD → PERFECT BUY (HTTP 200)
[LOG] Rapport construit (2 signaux actifs)
[OK] Rapport WhatsApp envoyé (HTTP 200)
[OK] Exécution unique terminée
```

---

## 🔍 MONITORING & LOGS

### View live logs

```powershell
# Option 1: Follow logs in real-time
tail -f logs/gom_sync_scheduler.log

# Option 2: View last 50 lines
tail -50 logs/gom_sync_scheduler.log

# Option 3: Search for errors
grep -i "error\|failed" logs/gom_sync_scheduler.log
```

### Check if process is running

```powershell
# Option 1: Check scheduled task
Get-ScheduledTask -TaskName "TradBOT-GOM-Sync-10min"

# Option 2: Check Python processes
Get-Process python | Where-Object { $_.CommandLine -like "*gom_sync*" }

# Option 3: Check for any Python processes
Get-Process python
```

---

## ⏰ EXPECTED REPORTS

### Every 10 minutes, you'll receive WhatsApp:

```
🎯 **GOM VERDICTS REPORT**
==================================================
🟢 BOOM 1000 INDEX — PERFECT BUY 
   Entry: 13907.79 | SL: 13878.41 | TP: 13957.11
   Coherence: 67%
   🔴M1 🟢M5 🟢M15 🟢H1 🔴H4 🔴D1

🟢 XAUUSD — PERFECT BUY
   Entry: 4226.01 | SL: 4219.85 | TP: 4232.17
   Coherence: 83%
   🟢M1 🟢M5 🟢M15 🟢H1 🔴H4 🔴D1

🟡 CRASH 500 INDEX — GOOD BUY
   Entry: 500.42 | SL: 495.15 | TP: 505.69
   Coherence: 61%
   (Below 70% gate - check manually)
==================================================
📅 2026-06-12 16:40:00 UTC
```

---

## 🛑 TROUBLESHOOTING

### "Python not found"
```
Solution: Add Python to PATH
  Settings → Environment Variables → 
  Edit PATH → Add C:\Python311\
```

### "ModuleNotFoundError"
```
Solution: Install requirements
  cd D:\Dev\TradBOT
  pip install -r requirements.txt
```

### "Connection refused" to AI Server
```
Solution: Make sure AI Server is running
  Check: http://127.0.0.1:8000/health
```

### "No WhatsApp messages"
```
Solution: Check PsychoBot configuration
  Verify .env has: WHATSAPP_TOKEN=...
  Verify /notify-whatsapp endpoint working
```

### "Logs not appearing"
```
Solution: Check logs directory exists
  mkdir logs (if needed)
  Verify write permissions
```

---

## 📊 LOG FILE LOCATION

```
D:\Dev\TradBOT\logs\gom_sync_scheduler.log
```

**Format:**
```
2026-06-12 16:30:00 - INFO - [SYNC] Starting GOM sync...
2026-06-12 16:30:01 - INFO - [OK] Loaded 7 GOM verdicts
2026-06-12 16:30:02 - INFO - [SEND] BOOM 1000 INDEX → HTTP 200
...
```

---

## ✅ CHECKLIST

Before activating, verify:

- [ ] AI Server running (http://127.0.0.1:8000)
- [ ] gom_signal.json exists and is fresh
- [ ] logs/ directory exists (or will be created)
- [ ] Python installed and accessible
- [ ] Requirements installed (`pip list | grep requests`)
- [ ] WhatsApp bot configured (if using PsychoBot)
- [ ] .env file has WHATSAPP_TOKEN (if using PsychoBot)

---

## 🚀 QUICK START

### Fastest Way to Start:

```
1. Double-click: start-gom-sync-10min.bat
2. Keep the window open
3. Check WhatsApp for reports every 10 min
4. Done!
```

### If you want it running in background forever:

```powershell
1. Open PowerShell as Admin
2. cd D:\Dev\TradBOT
3. .\scripts\register-gom-sync-task.ps1
4. Task will auto-start on reboot
```

---

## 📈 EXPECTED BEHAVIOR

### First Execution
```
✅ Loads verdicts from /gom-verdicts
✅ Sends 7 verdicts to /gom-verdict
✅ Builds report with 2-5 active signals
✅ Sends WhatsApp report
✅ Logs everything
```

### Every 10 Minutes After
```
✅ Repeats the same cycle
✅ Only new/updated verdicts sent
✅ WhatsApp report sent
✅ Logs appended
```

---

## 🎯 NEXT STEPS

### After GOM Sync is running:

1. **Verify verdicts are accurate** (check WhatsApp)
2. **Monitor for 1-2 hours** (ensure consistency)
3. **Launch SMC_Universal.mq5 EA** (will use these verdicts)
4. **Enable Trailing Stop Monitor** (manages positions)
5. **System is now autonomous!**

---

## 📞 STATUS

```
🟢 GOM Sync Scheduler: READY
🟢 Verdicts: LIVE (updated every 10 min)
🟢 WhatsApp Reports: SENDING
🟢 Logs: ACTIVE
```

**Total setup time:** 2 minutes  
**Result:** Autonomous GOM reporting 24/7

---

**Last Updated:** 2026-06-12  
**Status:** ✅ Production Ready
