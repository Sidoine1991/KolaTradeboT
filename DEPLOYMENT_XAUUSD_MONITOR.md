# XAUUSD Real-Time Monitoring System — Deployment Guide

## Overview

The XAUUSD monitoring system provides autonomous 24/7 surveillance of the gold market with:
- **Frequency**: Every 20 minutes (1200 seconds)
- **Data sources**: TradingView (price, VWAP, BB, SuperTrend, RSI) + AI server (bias, GOM verdict, TradingAgents report)
- **Delivery**: Unified WhatsApp message via PsychoBot
- **Reliability**: Automatic fallback to log file if PsychoBot is unreachable

## Quick Start

### Local Development (Windows)

```powershell
# From TradBOT project root
.\scripts\start_xauusd_monitor.ps1 -Phone "+2290196911346" -Interval 1200
```

**Expected output:**
```
🚀 Starting XAUUSD Real-Time Monitor
   Phone: +2290196911346
   Interval: 1200 seconds (20 minutes)
   Log file: logs/xauusd_monitor_ps.log

✅ Monitor started (PID: 12345)
📊 Monitoring XAUUSD every 20 minutes...
```

### Local Development (Linux/macOS)

```bash
cd /d/Dev/TradBOT
python python/unified_xauusd_monitor.py --interval 1200 --phone "+2290196911346"
```

### Single Cycle Test

```bash
python python/unified_xauusd_monitor.py --once --phone "+2290196911346"
```

## Architecture

### Data Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│ XAUUSD Monitoring Cycle (every 20 minutes)                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─ TradingView (parallel) ────────────────────────────────────┐   │
│  │  • mcp__tradingview-kola__quote_get                         │   │
│  │  • mcp__tradingview-kola__data_get_study_values            │   │
│  │  • mcp__tradingview-kola__data_get_pine_tables (GOM KOLA)  │   │
│  │                                                              │   │
│  │  Fallback: If TradingView unavailable, continue with        │   │
│  │            GOM data from AI server                          │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─ AI Server (parallel) ──────────────────────────────────────┐   │
│  │  • GET /session-bias?symbol=OR                              │   │
│  │  • GET /pending-order?symbol=OR                             │   │
│  │  • GET /tradingagents/report-status?symbol=OR               │   │
│  │  • GET /gom-verdict?symbol=OR                               │   │
│  │                                                              │   │
│  │  Fallback: If AI server unavailable, show ⚠️ warnings       │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─ Build Message ──────────────────────────────────────────────┐   │
│  │  Format unified WhatsApp message with:                       │   │
│  │  • Price & levels (VWAP, BB, SuperTrend)                    │   │
│  │  • GOM verdict + scores                                     │   │
│  │  • Session bias + confidence                                │   │
│  │  • EA pending order                                         │   │
│  │  • TradingAgents report                                     │   │
│  │  • Confluence analysis & scalping decision                  │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
│  ┌─ Send via PsychoBot ─────────────────────────────────────────┐   │
│  │  POST https://psychobot-1si7.onrender.com/send-message       │   │
│  │                                                              │   │
│  │  Fallback: If PsychoBot unreachable:                         │   │
│  │    → Save message to D:\Dev\TradBOT\whatsapp_alerts.log      │   │
│  └──────────────────────────────────────────────────────────────┘   │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Message Format

Example WhatsApp output:

```
📊 TradBOT [17:20 UTC]

*XAUUSD — Suivi 20min* | 29/05 17:20 UTC
━━━━━━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* $2456.78
📍 VWAP : $2456.50 → prix AU-DESSUS
📊 BB : [2445.20 / 2451.00 / 2467.50] → au-dessus BB Mid
⚡ Supertrend : $2448.30 (▲ Haussier) → prix AU-DESSUS
━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 *Verdict GOM KOLA : BUY*
   BUY=7.2  SELL=2.1  Spike=65%
   RSI=72
━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 *Biais session :* BULLISH 85% | Age: 2.5h
━━━━━━━━━━━━━━━━━━━━━━━━━
✅ *Ordre EA :* LIMIT BUY
   Entrée : $2455.00
   SL : $2440.00
   TP : $2470.00
   Confiance : 78%
   R:R = 1:1.8
━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 *Rapport TradingAgents :* BUY 82%
   Age : 5min | Expire dans : 55min
━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 *Décision:* 🟢 SCALP BUY (confluence)
━━━━━━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_
```

## Configuration

### Environment Variables

```bash
# .env file (or set via CLI)
XAUUSD_PHONE="+2290196911346"       # WhatsApp recipient
XAUUSD_INTERVAL=1200                # Monitoring interval (seconds)
AI_SERVER_URL="http://127.0.0.1:8000"
PSYCHOBOT_URL="https://psychobot-1si7.onrender.com"
```

### CLI Arguments

```bash
python unified_xauusd_monitor.py \
    --phone "+2290196911346" \
    --interval 1200 \
    --once              # Single cycle (omit for loop)
```

## Logs & Monitoring

### Log Files

- **Monitor loop log**: `logs/xauusd_monitor.log`
- **WhatsApp fallback**: `D:\Dev\TradBOT\whatsapp_alerts.log`
- **Orchestrator state**: `logs/orchestrator_state.json`

### View Live Output

```bash
# PowerShell
Get-Content -Path "logs/xauusd_monitor.log" -Wait

# Linux/macOS
tail -f logs/xauusd_monitor.log
```

### Check Cycle Count

```bash
# See how many cycles have completed
python scripts/xauusd_monitoring_orchestrator.py --status
```

## Production Deployment

### Windows Task Scheduler

1. **Create script**: `scripts/start_xauusd_monitor.ps1`
2. **Task Scheduler → Create Basic Task**
   - Name: "XAUUSD Monitoring"
   - Trigger: "At log on"
   - Action: `powershell.exe`
   - Arguments: `-File "D:\Dev\TradBOT\scripts\start_xauusd_monitor.ps1"`

### Linux/Render (systemd)

```bash
# Copy service file
sudo cp .deployment/xauusd_monitor.service /etc/systemd/system/

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable xauusd_monitor.service
sudo systemctl start xauusd_monitor.service

# Check status
sudo systemctl status xauusd_monitor.service
journalctl -u xauusd_monitor.service -f
```

## Troubleshooting

### TradingView Connection Failed

**Log message**:
```
[WARNING] [TV] Quote collection failed, will use AI server data only
```

**Cause**: MCP server not running or path misconfigured.

**Fix**:
1. Ensure TradingView Desktop is running
2. Check MCP path in `unified_xauusd_monitor.py`
3. Verify `node` command works: `node --version`

### AI Server Unreachable

**Log message**:
```
[WARNING] [AI] Session bias failed: Failed to connect
```

**Cause**: AI server down or wrong URL.

**Fix**:
```bash
curl -s http://127.0.0.1:8000/session-bias?symbol=OR
# Should return JSON, not error
```

### PsychoBot SSL Error

**Log message**:
```
[ERROR] [WhatsApp] certificate verify failed
```

**Fix**: Already handled in v2 with `verify=False`. If persists, check:
```bash
curl -k https://psychobot-1si7.onrender.com/send-message
```

### No Message Sent

**Check**:
1. WhatsApp fallback log: `D:\Dev\TradBOT\whatsapp_alerts.log`
2. Monitor log for errors: `logs/xauusd_monitor.log`
3. Test PsychoBot directly:
   ```bash
   python python/test_psychobot.py
   ```

## Performance Tuning

### Reduce Cycle Duration

If cycles are taking >30s:

1. **Disable MCP TradingView calls** (comment out in code)
2. **Increase timeout thresholds**
3. **Use AI server GOM only**

### Parallel Data Collection

Already implemented:
- TradingView quote + indicators + GOM all parallel
- AI server bias + order + report + GOM all parallel
- Total time: ~2-5 seconds typical

## Scaling

### Multiple Symbols

Create separate instances:

```bash
# XAUUSD
python unified_xauusd_monitor.py --phone "+2290196911346"

# BTCUSD (separate instance)
python unified_xauusd_monitor.py --symbol BTCUSD --phone "+2290196911346"
```

### High-Frequency (10 minutes)

```bash
python unified_xauusd_monitor.py --interval 600 --phone "+2290196911346"
```

Note: Reduces TradingView MCP call frequency to avoid lag.

## Security

### Sensitive Data

- **Phone numbers**: Stored in `.env` (not in code)
- **API keys**: Use environment variables only
- **PsychoBot URL**: Production URL in code (OK to expose)

### SSL Verification

- Development: `verify=False` (self-signed Render certificate)
- Production: Use proper certificates

## Support

- **Monitor version**: 2.0 (unified TradingView + AI server)
- **Contact**: via PsychoBot WhatsApp messaging

---

**Last updated**: 2026-05-29
**Maintainer**: TradBOT Automation Team
