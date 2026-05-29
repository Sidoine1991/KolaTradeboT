# XAUUSD Monitor System — Complete File Index

**Created:** 2026-05-29  
**Status:** ✅ Production-Ready  
**Total Files:** 13 new scripts + documentation

---

## 🎯 Start Here

**👉 NEW USERS:** Read `XAUUSD_MONITOR_QUICK_START.txt` (2 minutes)  
**👉 SETUP:** Follow `SETUP_MONITOR.md` (detailed guide)  
**👉 DEPLOY:** Run `Start-XAUUSDMonitor.ps1` (Windows) or `start_xauusd_monitor.sh` (Linux)

---

## 📂 Core Deliverables (Production Scripts)

### Main Monitoring Scripts

| File | Purpose | Start Command |
|------|---------|---|
| ⭐ **`run_xauusd_monitor.py`** | **All-in-one main monitor (RECOMMENDED)** | `python run_xauusd_monitor.py` |
| `xauusd_monitor.py` | Simplified version (basic version) | `python xauusd_monitor.py` |

### Launcher Scripts

| File | Platform | Start Command |
|------|----------|---|
| **`Start-XAUUSDMonitor.ps1`** | Windows PowerShell | `powershell -ExecutionPolicy Bypass -File D:\Dev\TradBOT\Start-XAUUSDMonitor.ps1` |
| **`start_xauusd_monitor.sh`** | Linux/macOS Bash | `bash start_xauusd_monitor.sh` |

### Configuration

| File | Purpose |
|------|---------|
| `xauusd_monitor_config.json` | Full configuration schema (interval, endpoints, etc) |

---

## 📚 Documentation (Complete & Production-Ready)

### Quick Start

| File | Time | Audience |
|------|------|----------|
| **`XAUUSD_MONITOR_QUICK_START.txt`** | **2 min** | **Everyone — start here** |
| `XAUUSD_MONITOR_SUMMARY.md` | 5 min | Overview & features |

### Detailed Guides

| File | Topic | Audience |
|------|-------|----------|
| **`SETUP_MONITOR.md`** | **Step-by-step setup + troubleshooting** | **Implementation** |
| `XAUUSD_MONITOR.md` | Complete reference documentation | Advanced users |
| `data/state/xauusd_monitor_session.md` | System state & deployment checklist | DevOps |

---

## 🔧 Advanced Options (Optional)

### Enhanced Versions (MCP Integration, Node.js, etc)

| File | Purpose |
|------|---------|
| `scripts/xauusd_monitor_mcp.py` | Full TradingView MCP integration |
| `scripts/xauusd_alert_20min.js` | Node.js alternative |
| `scripts/xauusd_whatsapp_monitor.py` | Advanced async version |

---

## 📊 Auto-Generated Files (Created at Runtime)

| File | Content |
|------|---------|
| `xauusd_monitor.log` | Monitor operation log (created on first run) |
| `whatsapp_alerts.log` | WhatsApp fallback alerts (if delivery fails) |
| `.xauusd_monitor.pid` | Process ID (for stopping monitor) |

---

## 🚀 Quick Deployment (3 Steps)

### Step 1: Install Dependency
```bash
python -m pip install httpx -q
```

### Step 2: Test Everything Works
```bash
python run_xauusd_monitor.py --test
```

### Step 3: Start Monitoring
```bash
# Option A: Windows PowerShell
powershell -ExecutionPolicy Bypass -File Start-XAUUSDMonitor.ps1

# Option B: Windows Command Prompt
cd D:\Dev\TradBOT && start python run_xauusd_monitor.py

# Option C: Linux/macOS
nohup python3 run_xauusd_monitor.py > xauusd_monitor.log 2>&1 &
```

✅ **Result:** First WhatsApp alert within 1 minute

---

## 📋 What Each Script Does

### `run_xauusd_monitor.py` — Main Monitor

**Features:**
- Every 20 minutes: Collect XAUUSD data
- Supports three modes: `--test`, `--once`, or continuous
- Parallel data collection from AI server
- Fallback logging if WhatsApp fails
- Production-grade error handling

**Modes:**
```bash
# Test connections
python run_xauusd_monitor.py --test

# Run once and exit
python run_xauusd_monitor.py --once

# Continuous monitoring (infinite loop)
python run_xauusd_monitor.py
```

### `xauusd_monitor.py` — Simplified Version

**Features:**
- Lightweight alternative
- Same functionality as main script
- Good for learning or modifications
- Fewer advanced error handlers

---

## 🔌 Integration Points

### Data Sources (Every 20 Minutes)

1. **AI Server** (http://127.0.0.1:8000)
   - Session bias → Market direction + strength
   - Pending order → EA order status
   - Report status → Latest trading verdict

2. **TradingView** (Optional MCP)
   - Quote: OANDA:XAUUSD price
   - Indicators: RSI, VWAP, Bollinger Bands, Supertrend
   - GOM verdict from Pine tables

### Delivery

- **Primary:** PsychoBot WhatsApp API
- **Fallback:** Log file (`whatsapp_alerts.log`)

---

## 💾 Configuration

### Default Settings
```json
{
  "interval": 20,           // minutes
  "ai_server": "http://127.0.0.1:8000",
  "whatsapp_phone": "+2290196911346",
  "timeout": 5,             // seconds
  "fallback_log": "whatsapp_alerts.log"
}
```

### Override with Environment Variables
```bash
export WHATSAPP_PHONE="+1234567890"
export AI_SERVER_URL="http://custom:8000"
export CHECK_INTERVAL=10
python run_xauusd_monitor.py
```

---

## 🎯 Message Format (Every 20 Minutes)

```
📊 TradBOT [HH:MM UTC]

*XAUUSD — Suivi 20min* | DD/MM HH:MM UTC
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* $XXXX.XX [TradingView]
📍 VWAP : $XXXX.XX [TradingView]
📊 BB : [lower / mid / upper] [TradingView]
⚡ Supertrend : $XXXX.XX [TradingView]
━━━━━━━━━━━━━━━━━━━━
🟢/🔴 *Verdict GOM KOLA :* BUY/SELL/WAIT
━━━━━━━━━━━━━━━━━━━━
🟢/🔴 *Biais session :* UP/DOWN XX% [AI Server]
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* ✅ ACTIF / 📭 Aucun [AI Server]
━━━━━━━━━━━━━━━━━━━━
🟢/🔴 *Rapport TradingAgents :* BUY/SELL XX% [AI Server]
━━━━━━━━━━━━━━━━━━━━
🎯 *Décision :* CONFLUENCE ANALYSIS
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_
```

---

## ✅ System Requirements

**Required:**
- Python 3.8+
- `httpx` library (auto-installed on first run)
- AI Server running on http://127.0.0.1:8000
- PsychoBot accessible at https://psychobot-1si7.onrender.com

**Optional:**
- TradingView MCP for real-time data (enhances message)
- Claude Code CLI (for MCP integration)

---

## 🛠️ Troubleshooting

### "Python not found"
Download from https://www.python.org/downloads/  
✅ Check "Add Python to PATH" during installation

### "httpx module not found"
```bash
pip install httpx -q
```

### "Connection refused http://127.0.0.1:8000"
Start AI Server first — Monitor will retry

### "WhatsApp not receiving messages"
1. Check: `python run_xauusd_monitor.py --test`
2. View logs: `tail -f xauusd_monitor.log`
3. Check fallback: `cat whatsapp_alerts.log`

**→ See `SETUP_MONITOR.md` for complete troubleshooting**

---

## 📖 Documentation Map

```
Choose your path:

┌─ NEW USER (2 min)
│  └─→ XAUUSD_MONITOR_QUICK_START.txt
│      └─→ Run: python run_xauusd_monitor.py --test
│
├─ SETUP ISSUES (10 min)
│  └─→ SETUP_MONITOR.md
│      └─→ Follow step-by-step guide
│
├─ PRODUCTION DEPLOYMENT (15 min)
│  └─→ SETUP_MONITOR.md → "Step 4: Start Continuous Monitoring"
│      └─→ Use Start-XAUUSDMonitor.ps1 or start_xauusd_monitor.sh
│
└─ ADVANCED / REFERENCE (30 min)
   └─→ XAUUSD_MONITOR.md (complete reference)
       └─→ Customization, error handling, integration points
```

---

## 🎓 What You'll Get

After setup, you'll have:

✅ Autonomous 24/7 monitoring system  
✅ WhatsApp alerts every 20 minutes  
✅ Comprehensive logging  
✅ Error resilience (survives AI server downtime)  
✅ Multi-platform support (Windows, Linux, macOS)  
✅ Production-grade code  
✅ Zero manual intervention needed  

---

## 🚀 Next Steps

1. **Read** → `XAUUSD_MONITOR_QUICK_START.txt` (2 min)
2. **Setup** → `python -m pip install httpx -q`
3. **Test** → `python run_xauusd_monitor.py --test`
4. **Deploy** → `Start-XAUUSDMonitor.ps1` or shell script
5. **Verify** → Check WhatsApp for first alert

---

## 📞 Support

- **Quick questions?** → `XAUUSD_MONITOR_QUICK_START.txt`
- **Setup help?** → `SETUP_MONITOR.md`
- **Full reference?** → `XAUUSD_MONITOR.md`
- **Debug mode?** → `python run_xauusd_monitor.py --test`

---

## 📁 Complete File Tree

```
D:\Dev\TradBOT\
├── run_xauusd_monitor.py              ⭐ Main monitor (START HERE)
├── xauusd_monitor.py                  Simplified version
├── XAUUSD_MONITOR_QUICK_START.txt     ⭐ Quick start (2 min)
├── SETUP_MONITOR.md                   Detailed setup guide
├── XAUUSD_MONITOR.md                  Complete reference
├── XAUUSD_MONITOR_SUMMARY.md          Delivery summary
├── XAUUSD_MONITOR_INDEX.md            This file
├── xauusd_monitor_config.json         Configuration
├── Start-XAUUSDMonitor.ps1            Windows launcher
├── start_xauusd_monitor.sh            Linux launcher
│
├── scripts/
│   ├── xauusd_monitor_mcp.py          MCP integration (advanced)
│   ├── xauusd_alert_20min.js          Node.js version (advanced)
│   └── xauusd_whatsapp_monitor.py     Advanced Python version
│
└── data/state/
    └── xauusd_monitor_session.md      System state & checklist
```

---

## 🎉 You're Ready!

Everything is set up and documented. Start with the quick start guide and you'll be monitoring XAUUSD within 2 minutes.

**Good luck!** 🚀
