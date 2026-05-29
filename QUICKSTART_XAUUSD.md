# 🚀 XAUUSD Monitoring — Quick Start

**Status**: ✅ **Production Ready**  
**Last Test**: 2026-05-29 18:20 UTC  
**Message Delivery**: ✅ WhatsApp operational

## 30-Second Setup

### 1️⃣ Verify System

```bash
python scripts/verify_xauusd_system.py
```

Should show: **✅ System ready!**

### 2️⃣ Start Monitoring

**Windows (PowerShell)**:
```powershell
.\scripts\start_xauusd_monitor.ps1
```

**Linux/macOS**:
```bash
python python/unified_xauusd_monitor.py --interval 1200 --phone "+2290196911346"
```

### 3️⃣ Check Logs

```bash
tail -f logs/xauusd_monitor.log
```

Expected output:
```
2026-05-29 18:20:04,437 [INFO] [WhatsApp] ✅ Message sent to +2290196911346
2026-05-29 18:20:04,438 [INFO] [Success] Message sent successfully
```

## ✨ What Happens

**Every 20 minutes**, the monitor:

1. **Collects data** from TradingView and AI server (in parallel, ~2-5s)
2. **Builds unified message** with price, indicators, verdicts
3. **Sends WhatsApp** via PsychoBot
4. **Falls back to log** if WhatsApp unreachable

Example message:

```
📊 TradBOT [17:20 UTC]

*XAUUSD — Suivi 20min* | 29/05 17:20 UTC
━━━━━━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* $2456.78
📍 VWAP : $2456.50 → prix AU-DESSUS
🟢 *Verdict GOM KOLA : BUY*
   BUY=7.2  SELL=2.1  Spike=65%
🟢 *Biais session :* BULLISH 85%
✅ *Ordre EA :* LIMIT BUY E=2455.00 SL=2440.00 TP=2470.00
🟢 *TradingAgents :* BUY 82%
🎯 *Décision:* 🟢 SCALP BUY (confluence)

_Prochain check dans 20 min_
```

## 📁 Key Files

- **Main script**: `python/unified_xauusd_monitor.py`
- **Launcher**: `scripts/start_xauusd_monitor.ps1`
- **Logs**: `logs/xauusd_monitor.log`
- **Fallback**: `whatsapp_alerts.log`
- **Documentation**: `DEPLOYMENT_XAUUSD_MONITOR.md`

## 🔧 Common Tasks

### Test Once (Don't Loop)

```bash
python python/unified_xauusd_monitor.py --once --phone "+2290196911346"
```

### Stop Monitoring

**Windows**:
```powershell
Stop-Process -Name python -Filter {$_.CommandLine -like "*unified_xauusd_monitor*"}
```

**Linux**:
```bash
pkill -f unified_xauusd_monitor
```

### View All Messages

```bash
tail -100 whatsapp_alerts.log
```

### Check How Many Cycles Completed

```bash
python scripts/xauusd_monitoring_orchestrator.py --status
```

## ⚠️ Troubleshooting

| Issue | Fix |
|-------|-----|
| "AI server hors ligne" | Check AI server running on `127.0.0.1:8000` |
| "⚠️" in price fields | TradingView MCP unavailable (OK, will use AI server) |
| Message in log but not WhatsApp | Check `whatsapp_alerts.log`, WhatsApp might be down |
| Nothing happens | Check `logs/xauusd_monitor.log` for errors |

Run health check anytime:
```bash
python scripts/verify_xauusd_system.py
```

## 📚 Learn More

- **Full deployment guide**: `DEPLOYMENT_XAUUSD_MONITOR.md`
- **System architecture**: `XAUUSD_MONITORING_README.md`
- **Code**: `python/unified_xauusd_monitor.py`

## 🎯 Next Steps

1. ✅ Run health check
2. ✅ Start monitoring
3. ✅ Receive WhatsApp alerts
4. ✅ Use messages for trading decisions

**Enjoy autonomous XAUUSD surveillance!** 🌟

---

**Version**: 2.0 | **Updated**: 2026-05-29
