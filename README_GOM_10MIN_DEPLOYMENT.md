# 🚀 GOM SYNC 10-MINUTE AUTONOMOUS DEPLOYMENT

**Production-ready GOM synchronization + WhatsApp reporting system**  
**Automatic execution every 10 minutes via Windows Task Scheduler**

---

## ⚡ Quick Start (3 minutes)

### 1. Open PowerShell as Administrator
```
WIN+X → Windows PowerShell (Admin)
OR
WIN+X → Terminal (Admin)
```

### 2. Run One Command
```powershell
cd D:\Dev\TradBOT
powershell -NoProfile -ExecutionPolicy Bypass -File DEPLOY_10MIN_AUTO.ps1
```

### 3. Result
```
✅ Task created: \TradBOT\GOM-Sync-10min
✅ State: Ready
✅ Test execution successful
✅ AUTONOMOUS SYSTEM ACTIVE
```

**Done!** The system now runs **automatically every 10 minutes**.

---

## 📊 What It Does

Every 10 minutes, the system:

1. **Loads GOM verdicts** from MT5 live dashboard (priority) or AI server (fallback) or JSON file
2. **Applies 9 protective gates** to reject false signals:
   - Coherence ≥ 85%
   - Correct Boom/Crash direction
   - RSI not extreme
   - M15 confirming
   - Trend coherence
   - Trading window active
   - Position not duplicate
   - Trading pause inactive
   - Verdict not stale

3. **Posts verdicts** to AI server (`/gom-verdict`)

4. **Builds WhatsApp report** with:
   - Symbol + Action (emoji: 🟢 BUY / 🔴 SELL)
   - Entry, SL, TP prices
   - Coherence %
   - Timeframe directions (M1, M5, M15, H1, H4, D1)
   - ML advisory (if available)

5. **Sends via WhatsApp** (AI server or PsychoBot fallback)

6. **Logs everything** to `logs/gom_sync.log`:
   - Timestamps
   - Verdicts loaded
   - Gates applied
   - Errors
   - WhatsApp status

---

## 📱 WhatsApp Report Example

```
🎯 **GOM VERDICTS REPORT** 📊
==================================================
🟢 XAUUSD — GOOD BUY | Entry: 6031.70 | SL: 6025.81 | TP: 6038.78 | Coh: 85%
  🟢M1 🟢M5 🟢M15 🟢H1 🟢H4 🟢D1
  🤖 ML: 🟢BUY 92% | acc=85%
🔴 BTCUSD — SELL | Entry: 43200.50 | SL: 43250.00 | TP: 43150.00 | Coh: 78%
  🔴M1 🟢M5 🔴M15 🔴H1 🔴H4 🔴D1
==================================================
📅 2026-06-16 18:00:00 UTC
```

---

## 🎮 Commands

### Check Status
```powershell
schtasks /query /tn "TradBOT\GOM-Sync-10min" /v
```

### Run Immediately
```powershell
schtasks /run /tn "TradBOT\GOM-Sync-10min"
```

### View Logs (Live)
```powershell
Get-Content logs\gom_sync.log -Tail 20 -Wait
```

### Verify Installation
```powershell
.\launch-gom-10min.ps1 verify
```

### Full Help
```powershell
.\launch-gom-10min.ps1 help
```

---

## 📁 Documentation Files

| File | Purpose |
|------|---------|
| **DEPLOY_10MIN_AUTO.ps1** | Complete deployment (admin) |
| **START_10MIN_SYNC.md** | Quick start guide (2 pages) |
| **DEPLOY_GOM_10MIN.md** | Quick reference card |
| **GOM_SYNC_10MIN_GUIDE.md** | Full technical documentation |
| **DEPLOY_INSTRUCTIONS.txt** | Visual step-by-step instructions |
| **README_GOM_10MIN_DEPLOYMENT.md** | This file |

---

## 🔐 Gates Applied

| Gate | Purpose |
|------|---------|
| **Coherence ≥ 85%** | Mandatory confidence threshold |
| **Boom/Crash Direction** | SELL only Boom, BUY only Crash |
| **RSI Extreme** | No BUY when RSI>78, no SELL when RSI<22 |
| **M15 Opposing** | Reject if M15 counter to verdict |
| **Trend Coherence** | No BUY in BEAR, no SELL in BULL |
| **Trading Window** | Symbol-specific UTC hours |
| **Position Duplicate** | Max one open per symbol |
| **Trading Pause** | No orders during win-streak pause (1h) |
| **Verdict Age** | Reject if > 1h old |

---

## 📋 Log Location

**File:** `D:\Dev\TradBOT\logs\gom_sync.log` (auto-created)

**Example:**
```
2026-06-16 18:00:00 - INFO - 🔄 [SYNC] Exécution unique GOM sync...
2026-06-16 18:00:05 - WARNING - [GATE-M15] ETHUSD: M15=BEAR — rejeté
2026-06-16 18:00:10 - INFO - [OK] Charge 2 verdicts GOM depuis dashboard
2026-06-16 18:00:12 - WARNING - [GATE-COH] XAUUSD: cohérence 67% < 85%
2026-06-16 18:00:14 - INFO - 📤 BTCUSD → BUY (HTTP 200)
2026-06-16 18:00:16 - INFO - 📋 Rapport construit (2 signaux actifs)
2026-06-16 18:00:18 - INFO - ✅ Rapport WhatsApp envoyé via AI server
2026-06-16 18:00:18 - INFO - ✅ Exécution unique terminée
```

---

## ❌ Troubleshooting

### Task not running
```powershell
.\launch-gom-10min.ps1 fix
```

### Python not found
```powershell
python --version
# If missing: https://www.python.org/downloads/
```

### No WhatsApp messages
1. Check AI server: `curl http://127.0.0.1:8000/health`
2. Check logs: `Select-String "ERROR|WhatsApp" logs\gom_sync.log`
3. Test manually: `.\launch-gom-10min.ps1 run`

### Verdicts rejected by gates
**This is NORMAL** — Gates protect against false signals. Check for verdicts with:
- Coherence >= 85%
- M15 aligned
- RSI not extreme
- Position not already open

---

## ✅ Features

✅ **MT5 Live Priority** — Real-time data from dashboard  
✅ **9 Protective Gates** — Anti-false-signal protection  
✅ **Non-blocking API calls** — Timeout=3-5s per endpoint  
✅ **Verdict deduplication** — Keeps freshest by symbol  
✅ **Position tracking** — Won't duplicate opens  
✅ **Verdict change detection** — WAIT→close, GOOD→PERFECT→order  
✅ **Win-streak pause** — 1h pause after 3 consecutive wins  
✅ **Complete logging** — Timestamps, verdicts, errors, gates  
✅ **WhatsApp reporting** — Every 10 minutes  
✅ **Fallback resilience** — PsychoBot if AI server down  

---

## 🎯 Next Steps

1. **Deploy:** Run `DEPLOY_10MIN_AUTO.ps1` (admin)
2. **Wait:** 10 minutes for first automatic execution
3. **Verify:** Check logs and WhatsApp
4. **Monitor:** Watch 2-3 cycles to confirm stable operation
5. **Optimize:** Adjust `MIN_COHERENCE_TO_PLACE` if needed

---

## 📊 Architecture

```
Task Scheduler (10-min interval)
  ↓
scripts/run-gom-sync-10min.bat
  ↓
python/gom_sync_with_report.py --report
  ├─ Load GOM verdicts (MT5 → AI server → JSON)
  ├─ Apply 9 gates
  ├─ POST /gom-verdict
  ├─ Build WhatsApp report
  ├─ Send via WhatsApp
  └─ Log to logs/gom_sync.log
```

---

## ✨ Status

| Component | Status |
|-----------|--------|
| **System** | ✅ Production Ready |
| **Script** | ✅ Tested & Verified |
| **Deployment** | ✅ Automated & Complete |
| **Documentation** | ✅ Comprehensive |
| **Monitoring** | ✅ Logs + WhatsApp |
| **Protection** | ✅ 9 Gates Active |
| **Automation** | ✅ 10-Minute Cycles |

---

## 📞 Support

For issues, see **GOM_SYNC_10MIN_GUIDE.md** for complete troubleshooting guide.

---

**Created:** 2026-06-16  
**Version:** 1.0  
**Status:** 🚀 Production Ready  
**Deployment:** Git committed ✅

---

## Quick Reference

```powershell
# Deploy (admin)
cd D:\Dev\TradBOT
powershell -NoProfile -ExecutionPolicy Bypass -File DEPLOY_10MIN_AUTO.ps1

# Check status
schtasks /query /tn "TradBOT\GOM-Sync-10min" /v

# View logs
Get-Content logs\gom_sync.log -Tail 20 -Wait

# Run immediately
schtasks /run /tn "TradBOT\GOM-Sync-10min"
```

**That's it! Your autonomous GOM sync system is now live.** 🚀
