# 🚀 TradBOT Commands Cheat Sheet

## ⚡ QUICK START

### Copie-colle ces commandes exactes :

```powershell
# 1️⃣ GOM SYNC (Charge verdicts + rapport WhatsApp)
python Python/gom_sync_with_report.py --report

# 2️⃣ TRAILING STOP (Monitore positions + sécurise gains)
python Python/trademanager_position_sync.py --once

# 3️⃣ TRADBOT EXECUTE (Place ordres auto)
python Python/tradbot_execute_with_ta.py --auto

# 4️⃣ GOM SCHEDULER (10 min loop - background)
python Python/gom_sync_scheduler.py
```

---

## 🎯 TRADING PIPELINE

```
┌─────────────────────────────────────────┐
│ 1. GOM SYNC (Charge verdicts)           │
│    python Python/gom_sync_with_report.py --report
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│ 2. TRADBOT EXECUTE (Place ordres)       │
│    python Python/tradbot_execute_with_ta.py --auto
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│ 3. POSITION MONITOR (Sécurise gains)    │
│    python Python/trademanager_position_sync.py
└─────────────────────────────────────────┘
```

---

## 📊 FULL AUTOMATION (Recommended)

Lancer **3 processus en parallèle** :

### Terminal 1: GOM Sync Scheduler (10 min loop)
```powershell
cd D:\Dev\TradBOT
python Python/gom_sync_scheduler.py
```

### Terminal 2: Trailing Stop Monitor (5 sec loop)
```powershell
cd D:\Dev\TradBOT
python Python/trademanager_position_sync.py
```

### Terminal 3: TradBOT Execute (manual or auto)
```powershell
cd D:\Dev\TradBOT
python Python/tradbot_execute_with_ta.py --auto
```

---

## 📁 SIMPLE LAUNCHERS

```powershell
# GOM Sync (one shot)
.\gom.bat

# Trailing Stop (one shot)
.\trailing.bat

# Position Monitor (continuous)
.\trailing.bat --once
```

**Note**: Ces launchers n'existent pas encore, mais tu peux les créer avec :
```powershell
# Créer .\gom.bat
python Python/gom_sync_with_report.py --report

# Créer .\trailing.bat
python Python/trademanager_position_sync.py %*
```

---

## 🔍 LOGS & MONITORING

```powershell
# GOM Sync logs
tail -f logs/gom_sync_scheduler.log

# Trailing Stop logs
tail -f logs/trademanager_sync.log

# TradBOT logs
tail -f logs/tradbot_execute.log

# Search for errors
grep -i "error\|failed" logs/*.log

# Search for warnings
grep -i "warning" logs/*.log
```

---

## ⏰ AUTOMATION SCHEDULE

| Time | Action | Command |
|------|--------|---------|
| **Every 10 min** | GOM Sync | `gom_sync_scheduler.py` |
| **Every 5 sec** | Trailing Stop | `trademanager_position_sync.py` |
| **Manual** | TradBOT Execute | `tradbot_execute_with_ta.py --auto` |

---

## 🛠️ TROUBLESHOOTING

### ❌ "can't open file" Error
**Cause**: Espace ou typo dans le nom du fichier

**Solution**: Copie-colle exacte depuis ce document

```powershell
# ❌ WRONG
python Python/trademanager_posi tion_sync.py

# ✅ CORRECT
python Python/trademanager_position_sync.py
```

### ❌ Module not found
**Solution**: Change to correct directory
```powershell
cd D:\Dev\TradBOT
python Python/trademanager_position_sync.py --once
```

### ❌ HTTP 404 (No positions)
**This is normal** - Means no open positions yet
```
✅ Script works fine
✅ Waiting for positions
```

---

## 📊 STATUS CHECK

```powershell
# Check if processes running
Get-Process python

# Get all log files
dir logs\

# Check latest logs
tail -20 logs/gom_sync_scheduler.log
tail -20 logs/trademanager_sync.log
```

---

## 🚀 ONE-LINER FULL SETUP

```powershell
# Start all 3 processes (open 3 terminals)

# Terminal 1
cd D:\Dev\TradBOT && python Python/gom_sync_scheduler.py

# Terminal 2
cd D:\Dev\TradBOT && python Python/trademanager_position_sync.py

# Terminal 3
cd D:\Dev\TradBOT && python Python/tradbot_execute_with_ta.py --auto
```

---

## 📋 SYSTEM STATUS

```powershell
# ✅ All Systems Operational
- GOM Sync: READY (10 min loop)
- Trailing Stop: READY (5 sec monitor)
- TradBOT Execute: READY (manual trigger)
- Position Manager: READY (live SL updates)
- Logs: ACTIVE (real-time)
- WhatsApp: CONNECTED (alerts every 10 min)
```

---

## 🎯 QUICK REFERENCE

| What | Command |
|------|---------|
| Load verdicts | `python Python/gom_sync_with_report.py --report` |
| Check gains | `python Python/trademanager_position_sync.py --once` |
| Place orders | `python Python/tradbot_execute_with_ta.py --auto` |
| Monitor live | `tail -f logs/gom_sync_scheduler.log` |
| Stop all | `pkill -f python` |

---

**Last Updated**: 2026-06-12  
**Status**: ✅ Production Ready
