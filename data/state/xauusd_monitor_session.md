# XAUUSD Monitor Session

**Started:** 2026-05-29
**Status:** Ready for deployment
**Check interval:** 20 minutes

## System Components

### Core Scripts
- `run_xauusd_monitor.py` — Main monitor (all-in-one, recommended)
- `xauusd_monitor.py` — Simplified version
- `Start-XAUUSDMonitor.ps1` — Windows starter
- `start_xauusd_monitor.sh` — Linux starter

### Configuration
- `xauusd_monitor_config.json` — Full configuration schema
- `.env` — Environment variables (AI_SERVER_URL, WHATSAPP_PHONE, etc)

### Documentation
- `XAUUSD_MONITOR_QUICK_START.txt` — Fast setup (2 minutes)
- `SETUP_MONITOR.md` — Detailed setup guide
- `XAUUSD_MONITOR.md` — Complete reference

### Logs
- `xauusd_monitor.log` — Monitor operation log
- `whatsapp_alerts.log` — WhatsApp fallback log

### Advanced
- `scripts/xauusd_monitor_mcp.py` — MCP integration (TradingView)
- `scripts/xauusd_alert_20min.js` — Node.js alternative

## Data Collection (Every 20 minutes)

### AI Server (Parallel calls)
1. **Session Bias** — Market direction + strength + validity
   - Endpoint: `/session-bias?symbol=XAUUSD`
   - Fields: direction, strength, valid_duration_hours

2. **Pending Order** — EA order status
   - Endpoint: `/pending-order?symbol=XAUUSD`
   - Fields: active, entry_price, stop_loss, take_profit

3. **TradingAgents Report** — Latest strategy verdict
   - Endpoint: `/tradingagents/report-status?symbol=XAUUSD`
   - Fields: direction, strength, age_minutes, expires_in_minutes

### TradingView (Future enhancement via MCP)
- XAUUSD price quote
- RSI, VWAP, Bollinger Bands, Supertrend
- GOM KOLA Pine indicator verdict

## Message Format

Unified WhatsApp alert every 20 minutes:

```
📊 TradBOT [HH:MM UTC]

*XAUUSD — Suivi 20min* | DD/MM HH:MM UTC
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* $XXXX.XX
📍 VWAP : $XXXX.XX
📊 BB : [lower / mid / upper]
⚡ Supertrend : $XXXX.XX
━━━━━━━━━━━━━━━━━━━━
🟢/🔴 *Verdict GOM KOLA : BUY/SELL/WAIT*
   BUY=X  SELL=X  Spike=X%
   RSI=XX
━━━━━━━━━━━━━━━━━━━━
🟢/🔴 *Biais session :* UP/DOWN XX% | ✅ valide Xh
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* ✅ ACTIF / 📭 Aucun
━━━━━━━━━━━━━━━━━━━━
🟢/🔴 *Rapport TradingAgents :* BUY/SELL XX% | Age: Xmin | Expire: Xmin
━━━━━━━━━━━━━━━━━━━━
🎯 *Décision :* CONFLUENCE ANALYSIS
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_
```

## Deployment Checklist

- [ ] Python 3.8+ installed
- [ ] `httpx` module installed (`pip install httpx`)
- [ ] AI Server running on http://127.0.0.1:8000
- [ ] PsychoBot accessible at https://psychobot-1si7.onrender.com
- [ ] Test connections: `python run_xauusd_monitor.py --test`
- [ ] Send test alert: `python run_xauusd_monitor.py --once`
- [ ] Start monitor: `Start-XAUUSDMonitor.ps1` or `start_xauusd_monitor.sh`
- [ ] Verify first alert received on WhatsApp
- [ ] Check monitor.log for errors

## Error Handling

| Scenario | Response |
|----------|----------|
| AI Server timeout (>5s) | Continue with TradingView data only, mark sections ⚠️ |
| PsychoBot unreachable | Write to `whatsapp_alerts.log`, continue loop |
| TradingView MCP timeout | Skip TradingView sections, continue with AI data |
| Max retry | Sleep 60s, retry on next cycle |

## Files Structure

```
D:\Dev\TradBOT\
├── run_xauusd_monitor.py           # Main script (all-in-one)
├── xauusd_monitor.py                # Simplified version
├── xauusd_monitor_config.json       # Configuration
├── XAUUSD_MONITOR.md                # Full documentation
├── SETUP_MONITOR.md                 # Setup guide
├── XAUUSD_MONITOR_QUICK_START.txt   # Quick start
├── Start-XAUUSDMonitor.ps1          # Windows starter
├── start_xauusd_monitor.sh          # Linux starter
├── xauusd_monitor.log               # Monitor logs (auto-created)
├── whatsapp_alerts.log              # Fallback alerts (auto-created)
├── .xauusd_monitor.pid              # Process ID (auto-created)
│
├── scripts/
│   ├── xauusd_monitor_mcp.py        # MCP integration (advanced)
│   ├── xauusd_alert_20min.js        # Node.js alternative
│   └── xauusd_whatsapp_monitor.py   # Full-featured Python version
│
└── data/
    └── state/
        └── xauusd_monitor_session.md # This file
```

## Commands Reference

### Test Mode
```bash
# Windows
python run_xauusd_monitor.py --test

# Linux/macOS
python3 run_xauusd_monitor.py --test
```

### Single Alert
```bash
# Windows
python run_xauusd_monitor.py --once

# Linux/macOS
python3 run_xauusd_monitor.py --once
```

### Continuous Monitoring
```bash
# Windows (background)
Start-Process -NoWindow -FilePath python -ArgumentList "run_xauusd_monitor.py"

# Linux/macOS (background)
nohup python3 run_xauusd_monitor.py > xauusd_monitor.log 2>&1 &
```

### View Logs
```bash
# Windows (live)
Get-Content xauusd_monitor.log -Tail 20 -Wait

# Linux/macOS (live)
tail -f xauusd_monitor.log
```

### Stop Monitor
```bash
# Windows
Stop-Process -Name python -Filter {$_.CommandLine -match "run_xauusd"}

# Linux/macOS
kill $(cat .xauusd_monitor.pid)
```

## Integration Points

### With AI Server
- Fetches session bias every 20 minutes
- Reads pending order status
- Gets latest TradingAgents verdict

### With PsychoBot
- Sends WhatsApp alerts via `/send-message`
- Phone: +2290196911346 (configurable)
- Timeout: 10 seconds

### With TradingView (Future)
- Can integrate MCP calls for real-time data
- Scripts provided for TradingView quote, indicators, GOM verdict
- Currently uses AI server data as primary source

## Success Criteria

✅ Monitor starts without errors
✅ First test alert received on WhatsApp
✅ Alerts continue every 20 minutes
✅ No errors in xauusd_monitor.log
✅ Can be stopped and restarted cleanly

## Notes

- Monitor is fully autonomous — no manual intervention required
- Survives AI server downtime — continues with available data
- Resilient to network failures — fallback to log file
- Lightweight — ~30-50MB memory footprint
- CPU idle during 20-minute wait intervals
