# XAUUSD 20-min WhatsApp Surveillance System

**Autonomous monitoring system that collects XAUUSD data every 20 minutes and sends unified WhatsApp alerts via PsychoBot.**

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ XAUUSD Monitor (main loop every 20 min)                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Step 1: Parallel Data Collection                           │
│  ├─ TradingView (via MCP)                                   │
│  │  ├─ Quote: OANDA:XAUUSD price                           │
│  │  ├─ Indicators: RSI, VWAP, Bollinger Bands, Supertrend  │
│  │  └─ Pine Tables: GOM KOLA verdict                       │
│  │                                                          │
│  └─ AI Server (http://127.0.0.1:8000)                      │
│     ├─ /session-bias?symbol=XAUUSD                         │
│     ├─ /pending-order?symbol=XAUUSD                        │
│     └─ /tradingagents/report-status?symbol=XAUUSD          │
│                                                              │
│  Step 2: Build Unified WhatsApp Message                     │
│  ├─ Format: French, structured sections                     │
│  ├─ Include: Price, indicators, verdicts, decisions        │
│  └─ Timeout: Skip unavailable data, mark as ⚠️             │
│                                                              │
│  Step 3: Send Alert                                         │
│  ├─ Primary: PsychoBot /send-message endpoint              │
│  └─ Fallback: Log to whatsapp_alerts.log file              │
│                                                              │
│  Step 4: Wait 20 Minutes                                    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Quick Start

### Option 1: Windows PowerShell (Recommended)

```powershell
# Run as Administrator or with ExecutionPolicy Bypass
powershell -ExecutionPolicy Bypass -File D:\Dev\TradBOT\Start-XAUUSDMonitor.ps1
```

### Option 2: Linux/macOS Bash

```bash
chmod +x D:/Dev/TradBOT/start_xauusd_monitor.sh
./D/Dev/TradBOT/start_xauusd_monitor.sh
```

### Option 3: Direct Python

```bash
cd D:/Dev/TradBOT
python3 xauusd_monitor.py
```

## Message Format

Every 20 minutes, a structured WhatsApp alert is sent:

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

## Configuration

**File:** `xauusd_monitor_config.json`

Key settings:
- `interval_minutes`: 20 (change if needed)
- `ai_server.base_url`: http://127.0.0.1:8000
- `whatsapp.phone`: +2290196911346
- `whatsapp.service`: PsychoBot
- `whatsapp.timeout_seconds`: 10

## Data Collection Flow

### TradingView (Parallel)

1. **Quote** — Current XAUUSD price, OHLCV data
   ```
   MCP: mcp__tradingview-kola__quote_get
   params: {symbol: "OANDA:XAUUSD"}
   ```

2. **Indicators** — RSI, VWAP, Bollinger Bands, Supertrend values
   ```
   MCP: mcp__tradingview-kola__data_get_study_values
   ```

3. **GOM KOLA Verdict** — Pine indicator table output
   ```
   MCP: mcp__tradingview-kola__data_get_pine_tables
   params: {study_filter: "GOM KOLA"}
   ```

### AI Server (Parallel)

1. **Session Bias** — Market direction and validity
   ```
   GET http://127.0.0.1:8000/session-bias?symbol=XAUUSD
   Response: {direction, strength, valid_duration_hours}
   ```

2. **Pending Order** — Current EA pending order status
   ```
   GET http://127.0.0.1:8000/pending-order?symbol=XAUUSD
   Response: {active, entry_price, stop_loss, take_profit}
   ```

3. **TradingAgents Report** — Latest strategy verdict
   ```
   GET http://127.0.0.1:8000/tradingagents/report-status?symbol=XAUUSD
   Response: {direction, strength, age_minutes, expires_in_minutes}
   ```

## Error Handling

### AI Server Offline

If AI server is unreachable (timeout > 5 seconds):
- Continue with TradingView data only
- Mark AI sections with ⚠️ prefix
- Log error to console
- Retry after 20 minutes

### WhatsApp Delivery Failed

If PsychoBot is unreachable:
- Write full message to `whatsapp_alerts.log`
- Continue monitoring loop
- Log fallback write timestamp

### TradingView MCP Timeout

If TradingView MCP calls timeout:
- Skip TradingView sections
- Continue with AI server data
- Mark sections with [N/A]

## Logging

### Monitor Logs

**File:** `xauusd_monitor.log`

```
[2026-05-29T20:00:00+00:00] 🚀 XAUUSD 20-min autonomous WhatsApp surveillance started
[2026-05-29T20:00:01+00:00] 📊 Iteration #1 - Collecting data...
[2026-05-29T20:00:02+00:00] ✅ WhatsApp sent successfully
[2026-05-29T20:00:02+00:00] ⏰ Waiting 20 minutes until next check...
```

### WhatsApp Alert Fallback Log

**File:** `whatsapp_alerts.log`

```
2026-05-29T20:05:00+00:00 | FALLBACK: 📊 TradBOT [20:05 UTC]...
```

## System Requirements

- **Python 3.8+**
- **httpx** library (auto-installed)
- **AI Server** running on http://127.0.0.1:8000
- **PsychoBot** reachable at https://psychobot-1si7.onrender.com
- **TradingView** desktop with MCP server running

## Monitoring the Monitor

### Check if Running (PowerShell)

```powershell
$pid = Get-Content D:\Dev\TradBOT\.xauusd_monitor.pid
Get-Process -Id $pid -ErrorAction SilentlyContinue
```

### View Live Logs

```bash
# Last 20 lines
tail -n 20 D:/Dev/TradBOT/xauusd_monitor.log

# Follow in real-time
tail -f D:/Dev/TradBOT/xauusd_monitor.log
```

### Stop the Monitor

```powershell
# Windows
Stop-Process -Name "python" -Filter {$_.Id -eq (Get-Content D:\Dev\TradBOT\.xauusd_monitor.pid)}

# Linux/Mac
kill $(cat D/Dev/TradBOT/.xauusd_monitor.pid)
```

## Integration Points

### With TradingAgents

Monitor fetches latest TradingAgents verdict:
- Decision direction (BUY/SELL/WAIT)
- Confidence strength (0-100%)
- Report age and expiration

### With Session Bias

Includes session context:
- Market bias (UP/DOWN/NEUTRAL)
- Bias strength percentage
- How long bias is valid

### With EA Pending Orders

Shows if EA has active pending order:
- Entry price
- Stop loss
- Take profit

## Troubleshooting

### Monitor Not Starting

```bash
# Check Python
python3 --version

# Check httpx
python3 -c "import httpx"

# Run with verbose output
python3 xauusd_monitor.py 2>&1
```

### WhatsApp Not Receiving Messages

1. Check PsychoBot URL is reachable:
   ```bash
   curl -v https://psychobot-1si7.onrender.com/send-message
   ```

2. Check WhatsApp number format: `+COUNTRY_CODE_PHONE_NUMBER`

3. Check logs for fallback entries:
   ```bash
   tail -n 50 D:/Dev/TradBOT/whatsapp_alerts.log
   ```

### AI Server Connection Issues

1. Verify AI server is running:
   ```bash
   curl http://127.0.0.1:8000/health
   ```

2. Check endpoint availability:
   ```bash
   curl http://127.0.0.1:8000/session-bias?symbol=XAUUSD
   ```

3. Monitor will continue with TradingView data only if AI server is down

## Advanced Usage

### Custom Check Interval

Edit `xauusd_monitor.py`:

```python
CHECK_INTERVAL = 10 * 60  # 10 minutes instead of 20
```

### Custom Message Format

Edit `build_whatsapp_message()` function in `xauusd_monitor.py`

### Environment Variables

```bash
export AI_SERVER_URL="http://custom-server:8000"
export PSYCHOBOT_URL="https://custom-psychobot.com/send-message"
export WHATSAPP_PHONE="+1234567890"
python3 xauusd_monitor.py
```

## Related Files

- `xauusd_monitor_config.json` — Configuration schema
- `scripts/xauusd_alert_20min.js` — Node.js alternative
- `scripts/xauusd_whatsapp_monitor.py` — Advanced version with TradingView MCP direct calls
- `whatsapp_alerts.log` — Fallback log file
- `xauusd_monitor.log` — Monitor operation log

## Next Steps

1. Start the monitor
2. Verify first message arrives within 1 minute
3. Check logs for any errors
4. Monitor should run autonomously every 20 minutes
