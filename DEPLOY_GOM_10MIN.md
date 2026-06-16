# 🚀 GOM SYNC 10-MINUTE DEPLOYMENT

**Status:** ✅ Production Ready  
**Date:** 2026-06-16  
**Script:** `python/gom_sync_with_report.py --report`  
**Loop:** Every 10 minutes via Windows Task Scheduler

---

## ⚡ QUICK START

### 1️⃣ Test It Works
```powershell
cd D:\Dev\TradBOT
.\launch-gom-10min.ps1 test
```

### 2️⃣ Run Manual Execution
```powershell
.\launch-gom-10min.ps1 run
```

Expected output:
```
🔄 [SYNC] Exécution unique GOM sync...
[OK] Charge 1 verdicts GOM depuis dashboard MT5 LIVE
📋 Rapport construit (N signaux actifs)
✅ Rapport WhatsApp envoyé via AI server
✅ Exécution unique terminée
```

### 3️⃣ Deploy to Task Scheduler (Admin)
```powershell
# Right-click PowerShell → Run as Administrator
cd D:\Dev\TradBOT
.\launch-gom-10min.ps1 install
```

### 4️⃣ Verify Installation
```powershell
.\launch-gom-10min.ps1 verify
```

---

## 📊 WHAT IT DOES EVERY 10 MINUTES

| Step | Action |
|------|--------|
| 1 | Load live GOM verdicts from MT5 dashboard (or fallback to AI server/JSON) |
| 2 | Apply all trading gates (coherence, timeframe, Boom/Crash direction, RSI, etc.) |
| 3 | Place market orders for eligible verdicts (coherence ≥ 85%) |
| 4 | Detect verdict changes (WAIT→close, GOOD→PERFECT→order) |
| 5 | Build formatted report with entry/SL/TP + timeframe directions |
| 6 | Send via WhatsApp (AI server or PsychoBot fallback) |
| 7 | Log everything to `logs/gom_sync.log` |

---

## 🎯 KEY GATES

Orders are **only placed** if ALL conditions met:

- ✅ Coherence ≥ 85%
- ✅ Not already in position on this symbol
- ✅ Boom/Crash direction respected (SELL only on Boom, BUY only on Crash)
- ✅ RSI not extreme (BUY when RSI ≤ 78, SELL when RSI ≥ 22)
- ✅ M15 not opposing verdict
- ✅ Trading window active (symbol-specific UTC hours)
- ✅ Not in 3-win-streak trading pause (1h pause after 3 consecutive wins)
- ✅ Multi-TF trend coherence OK (no BUY in strong BEAR, no SELL in strong BULL)

---

## 📋 CLI COMMANDS

```powershell
# Install on Task Scheduler (admin required)
.\launch-gom-10min.ps1 install

# Check installation status
.\launch-gom-10min.ps1 verify

# Run pre-flight tests
.\launch-gom-10min.ps1 test

# Execute immediately (don't wait 10 min)
.\launch-gom-10min.ps1 run

# View recent logs
.\launch-gom-10min.ps1 logs

# Auto-fix task issues
.\launch-gom-10min.ps1 fix

# Show help
.\launch-gom-10min.ps1 help
```

---

## 📊 LOGS LOCATION

**File:** `D:\Dev\TradBOT\logs\gom_sync.log`

**View live tail:**
```powershell
Get-Content logs/gom_sync.log -Tail 20 -Wait
```

**Example log output:**
```
2026-06-16 17:44:36 - INFO - [SYNC] Exécution unique GOM sync...
2026-06-16 17:45:12 - WARNING - [GATE-M15] ETHUSD: M15=BEAR opposé à BUY — rejeté
2026-06-16 17:45:22 - INFO - [OK] Charge 1 verdicts GOM depuis dashboard MT5 LIVE
2026-06-16 17:45:33 - WARNING - [GATE-COH] XAUUSD: cohérence 67% < 85% — ordre ignoré
2026-06-16 17:45:40 - INFO - [LOG] Rapport construit (1 signaux actifs)
2026-06-16 17:45:41 - INFO - ✅ Rapport WhatsApp envoyé via AI server
```

---

## 🔧 MANUAL OPERATIONS

### Run immediately
```powershell
schtasks /run /tn "TradBOT\GOM-Sync-10min"
```

### View task schedule
```powershell
schtasks /query /tn "TradBOT\GOM-Sync-10min" /v
```

### Pause the task
```powershell
schtasks /end /tn "TradBOT\GOM-Sync-10min"
```

### Resume the task
```powershell
schtasks /run /tn "TradBOT\GOM-Sync-10min"
```

### Uninstall the task
```powershell
schtasks /delete /tn "TradBOT\GOM-Sync-10min" /f
```

---

## ⚙️ CONFIGURATION

**Minimum Coherence to Place Order:**
```python
# In gom_sync_with_report.py, line 618
MIN_COHERENCE_TO_PLACE = 85  # percent
```

**Loop Interval:**
```python
# In gom_sync_with_report.py, line 27
LOOP_INTERVAL = 600  # 10 minutes (seconds)
```

**Trading Windows (UTC hours):**
```python
_SYMBOL_TRADING_WINDOWS = {
    "XAUUSD": [(7, 17)],      # 7-17 UTC
    "BTCUSD": [(8, 22)],      # 8-22 UTC
    "ETHUSD": [(8, 22)],      # 8-22 UTC
    "NAS100": [(13, 20)],     # 13:30-20:00 UTC
    "US30": [(13, 20)],       # 13:30-20:00 UTC
}
```

---

## ❌ TROUBLESHOOTING

**Q: Task not running every 10 minutes?**
```powershell
# Reinstall
.\launch-gom-10min.ps1 install
```

**Q: Python not found?**
```powershell
python --version
# If not in PATH, add to System settings or set in shell:
$env:Path += ";C:\Python314"
```

**Q: No WhatsApp messages?**
- Check AI server: `curl http://127.0.0.1:8000/health`
- Check PsychoBot: `curl https://psychobot-1si7.onrender.com/health`
- Review logs: `.\launch-gom-10min.ps1 logs`

**Q: Verdicts rejected by gates?**
- This is **correct behavior** — system protects against false signals
- Check `[GATE-xxx]` entries in logs to understand why

**Q: Task stopped running?**
```powershell
.\launch-gom-10min.ps1 fix
```

---

## 📈 WHAT YOU'LL SEE IN WHATSAPP

**Every 10 minutes** (if verdicts active):
```
🎯 **GOM VERDICTS REPORT** 📊
==================================================
🟢 XAUUSD — GOOD BUY | Entry: 4341.84 | SL: 4338.22 | TP: 4345.67 | Coh: 67%
  🟢M1 🟢M5 🟢M15 🟢H1 🟢H4 🔴D1
  🤖 ML: 🟢BUY 89% | acc=78%
==================================================
📅 2026-06-16 17:45:40 UTC
```

**When order placed:**
```
🚀 *MARKET ORDER* — XAUUSD
BUY @ 4341.84 SL=4338.22 TP=4345.67
✅ Ordre placé
```

**When position closes:**
```
🔴 *GOM WAIT — FERMETURE IMMÉDIATE* — XAUUSD
Verdict GOOD BUY → WAIT
✅ Ordre de fermeture envoyé
```

---

## 📚 DOCUMENTATION

- **Full Reference:** `memory/session_2026_06_16_gom_sync_deployment.md`
- **Setup Guide:** `README_GOM_SYNC_10MIN.md`
- **Quick Setup:** `GOM_SYNC_SETUP.md`

---

## 🎬 NEXT STEPS

1. **Deploy:** `.\launch-gom-10min.ps1 install` (admin required)
2. **Monitor:** `.\launch-gom-10min.ps1 logs` (watch activity)
3. **Verify:** Wait 10 minutes, check logs for successful run
4. **Optimize:** Tune `MIN_COHERENCE_TO_PLACE` based on results

---

**Status: ✅ Production Ready — Ready to Deploy**

Last Updated: 2026-06-16
