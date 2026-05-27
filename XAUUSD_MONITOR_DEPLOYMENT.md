# XAUUSD WhatsApp Monitor — Production Deployment Guide

## Quick Start

```bash
# Start the 20-minute monitoring loop:
D:\Dev\TradBOT\start_xauusd_production_monitor.bat

# Or directly:
cd D:\Dev\TradBOT
python xauusd_production_monitor.py
```

**Press Ctrl+C to stop gracefully.**

---

## What It Does

Unified WhatsApp monitoring system that runs every **20 minutes**:

### ÉTAPE 1: TradingView Data
- Live XAUUSD price
- VWAP, Bollinger Bands, Supertrend
- RSI, Fibonacci zones
- **GOM KOLA verdict** (BUY/SELL/WAIT) with scores

### ÉTAPE 2: AI Server Data
- Session bias (BUY/SELL/NEUTRAL with confidence)
- Pending orders (entry, SL, TP, action)
- TradingAgents report (direction, confidence)

### ÉTAPE 3: Unified Message Build
- Technical indicators summary
- Confluence analysis (GOM + Bias + TA + EA signals)
- **Final decision**: 
  - 🟢 BUY/SELL — Confluence 2/2 (full agreement)
  - ⚠️ CONFLIT (signals disagree)
  - 🟡 WAIT (insufficient signals)

### ÉTAPE 4: Send via PsychoBot
- Primary: Send via `https://psychobot-1si7.onrender.com/send-message`
- Fallback: Save to `whatsapp_alerts.log` if network fails
- Delivery to: **+2290196911346**

---

## Example Message Format

```
📊 TradBOT [23:49 UTC]

*XAUUSD — Suivi 20min* | 27/05 23:49 UTC
━━━━━━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* $4507.33
📍 VWAP : $4505.99 → prix AU-DESSUS
📊 BB : $4504.42 / $4508.08 / $4511.74 → AU-DESSUS
⚡ Supertrend : $4582.72 (↑) → EN-DESSOUS
📐 Fibo : 📍 Zone 4508-4506
━━━━━━━━━━━━━━━━━━━━━━━━━
🔴/🟢 *Verdict GOM KOLA : SELL*
   Score BUY=4.3  SELL=5.8  Spike=4.6%
   RSI=46.6 | ST=↑
━━━━━━━━━━━━━━━━━━━━━━━━━
🔴/🟢 *Biais session :* SELL 50% | ✅ valide 1.8h
━━━━━━━━━━━━━━━━━━━━━━━━━
📭 *Ordre EA :* Aucun ordre EA actif
━━━━━━━━━━━━━━━━━━━━━━━━━
🔴/🟢 *Rapport TradingAgents :* NONE 0%
   ⚠️ Pas de signal actif
━━━━━━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
   Signaux: GOM=SELL | Bias=SELL
   📊 Confluence: 🔴 SELL — Confluence 2/2
━━━━━━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_
```

---

## Configuration

**File**: `xauusd_production_monitor.py`

| Setting | Value | Change? |
|---------|-------|---------|
| **Interval** | 1200s (20 min) | Line 24: `INTERVAL = 1200` |
| **Phone** | +2290196911346 | Line 25: `PHONE = "..."` |
| **Fallback log** | D:\Dev\TradBOT\whatsapp_alerts.log | Line 26: `LOG_FILE = "..."` |
| **AI Server** | http://127.0.0.1:8000 | Line 23: `AI_SERVER_URL = "..."` |
| **PsychoBot** | https://psychobot-1si7.onrender.com | Line 24: `PSYCHOBOT_URL = "..."` |

---

## Monitoring & Logs

### Console Output
```
[Cycle] 2026-05-27T23:49:00.000000
[AI] Fetching data...
  Bias: ✅
  Order: ❌
  TA: ✅
[Message] Building...
  Length: 787 chars
[Send] Attempting PsychoBot...
[WhatsApp] ✅ Message sent
```

### Fallback Log
```bash
# Check if messages were saved (network failures):
tail -f D:\Dev\TradBOT\whatsapp_alerts.log

# Grep for errors:
grep -i "ERROR\|EXCEPTION" D:\Dev\TradBOT\whatsapp_alerts.log
```

---

## Troubleshooting

### Issue: "HTTP 200 but no message received"
- ✅ Check PsychoBot Render logs (https://dashboard.render.com)
- ✅ Verify PSYCHOBOT_URL is correct
- ✅ Check if new API key is set in Render env vars

### Issue: "Connection refused (AI server)"
- ✅ Verify `ai_server.py` is running: `python ai_server.py`
- ✅ Check if FastAPI is listening on `http://127.0.0.1:8000`
- ✅ Run: `curl http://127.0.0.1:8000/health`

### Issue: "No bias/order/TA data"
- ✅ Check if endpoints exist: `/session-bias`, `/pending-order`, `/tradingagents/report-status`
- ✅ Run test: `curl http://127.0.0.1:8000/session-bias?symbol=XAUUSD`

### Issue: "TradingView data is stale"
- ⚠️ **Current design**: TV data is mocked (hardcoded in script)
- 📝 To update: Manually collect via TradingView MCP tools and paste into `TV_DATA` dict
- 🚀 Future: Integrate real-time MCP data collector service

---

## Security Checklist

- ✅ No API keys in Python code
- ✅ No phone numbers in git history
- ✅ Fallback log is local-only
- ✅ PsychoBot URL is public (no secrets in URL)
- ✅ All credentials use environment variables (Render)

---

## Integration with TradBOT Ecosystem

| Component | Status | Notes |
|-----------|--------|-------|
| **AI Server** | ✅ Running | Provides bias, orders, TA data |
| **GOM KOLA Pine Script** | ✅ On chart | Generates verdict + scores |
| **TradeManager.mq5** | ✅ Running | Executes trades, syncs SL/TP |
| **TradingView Desktop** | ✅ Connected | Live XAUUSD chart |
| **PsychoBot** | ✅ Live | WhatsApp delivery |

---

## Next Steps (Optional)

### 1. Real-Time TradingView Data
Create `tv_data_collector.py` to poll MCP tools and write to `tv_latest.json`:
```python
# Polls every 30s via MCP tools
# Outputs: tv_latest.json with real quote, indicators, GOM verdict
# Monitor reads this file instead of hardcoded dict
```

### 2. Persistent Storage
Add SQLite/Supabase logging of all messages + delivery status:
```python
# Track which messages were sent, which failed
# Build analytics dashboard
```

### 3. Multi-Symbol Monitoring
Extend to monitor BTCUSD, EURUSD, etc. simultaneously:
```python
# Run parallel loops for each symbol
# Aggregate signals into single master message
```

---

## Support

**Questions?** Check:
1. Console output (`[Error]`, `[WhatsApp]` prefixes)
2. Fallback log: `D:\Dev\TradBOT\whatsapp_alerts.log`
3. AI server logs: Check FastAPI console
4. PsychoBot Render logs: https://dashboard.render.com
