# ⚡ TradBOT Quick Start Guide

## 🎯 Start Everything in 30 Seconds

### Windows (One Command)

**Option A: Batch File (Easiest)**
```cmd
start-complete-system.bat
```

**Option B: PowerShell (Recommended)**
```powershell
.\start-complete-system.ps1
```

**Result:** Both PsychoBot + AI Server launch in separate windows

---

## 📋 What Gets Started

| Service | Port | Status |
|---------|------|--------|
| PsychoBot WhatsApp | 8888 | ✅ Running |
| TradBOT AI Server | 8000 | ✅ Running |
| GOM Sync | - | Ready to execute |
| Pipeline Hourly | - | Ready to execute |

---

## 🚀 Execute Pipelines (After 30 sec wait)

### GOM Sync + WhatsApp Report
```bash
cd D:\Dev\TradBOT
python Python/gom_sync_with_report.py --report
```

### Pipeline Hourly + Word Report
```bash
cd D:\Dev\TradBOT
python Python/pipeline_hourly_autonomous.py --once
```

---

## 📅 Automate (Optional)

```powershell
# One-time setup - Register Windows Task Scheduler
.\register-autonomous-scheduler.ps1

# Tasks run automatically:
# - GOM Sync: Every 10 minutes
# - Pipeline: Every 1 hour
```

---

## ✅ Verify Everything

```bash
# Check services running
curl http://localhost:8888  # PsychoBot
curl http://localhost:8000/health  # AI Server

# View latest reports
tail -f logs/gom_sync.log
tail -f logs/pipeline_hourly.log

# Check generated files
ls -lh logs/*.docx
```

---

## 📊 Expected Output

**GOM Sync:**
```
🟢 XAUUSD — PERFECT BUY | Entry: 4218.99 | Coh: 83%
📤 Rapport WhatsApp envoyé (HTTP 200)
```

**Pipeline:**
```
PIPELINE HOURLY REPORT
Top-5 Analyzed: 5
Orders Placed: 2
📄 Word report saved: logs/pipeline_report_*.docx
📤 Word report sent via WhatsApp (HTTP 200)
```

---

## 🎉 Ready!

✅ Services running  
✅ GOM Sync every 10 min → WhatsApp  
✅ Pipeline every hour → Word report  
✅ Spike anticipation active  
✅ Multi-TF IA Status v2  
✅ All logs saved  

**You're live! 🚀**
