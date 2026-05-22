# TradingView → TradBOT Webhook Integration Guide

## Overview

TradBOT's AI server now accepts real-time trading signals from TradingView via webhook. Signals are validated against SMC setups and executed automatically on MT5.

---

## Architecture

```
TradingView Alert
    ↓ (JSON payload via HTTP POST)
ai_server.py /webhook/tradingview
    ↓ (Validates + Analyzes)
process_analysis_360()
    ↓ (Applies SMC logic)
SMC_Universal.mq5 (Auto-execute or manual review)
```

---

## Step 1: Configure Your AI Server

### Local Development
```bash
cd D:\Dev\TradBOT
python ai_server.py
# Server runs on http://localhost:8000
```

### Render Deployment
- Your webhook URL will be: `https://your-app.onrender.com/webhook/tradingview`
- Get the URL from your Render dashboard

### Verify Webhook is Live
```bash
curl http://localhost:8000/webhook/tradingview/test
# or
curl https://your-app.onrender.com/webhook/tradingview/test
```

Expected response:
```json
{
  "status": "SUCCESS",
  "symbol": "EURUSD",
  "action": "BUY",
  "timeframe": "M5",
  "confidence": 0.85,
  "decision": {
    "status": "SIGNAL",
    "verdict": "PERFECT"
  }
}
```

---

## Step 2: Create TradingView Alert

### In TradingView Chart

1. **Open your strategy/indicator**
2. **Add Alert**:
   - Chart → Alerts → Create Alert
   - Select your strategy/indicator
   - Set frequency: "Once per bar close"

3. **Alert Webhook URL**:
   - Click "Manage Alerts"
   - Find your alert
   - Click "Configure webhook"
   - **Webhook URL**: `https://your-app.onrender.com/webhook/tradingview`
   - **Message format**: JSON (see below)

---

## Step 3: Format Alert Message

### Minimal Signal (Required fields only)
```json
{
  "symbol": "EURUSD",
  "timeframe": "M5",
  "action": "BUY",
  "confidence": 0.85
}
```

### Complete Signal (Recommended for precision)
```json
{
  "symbol": "EURUSD",
  "timeframe": "M5",
  "action": "BUY",
  "confidence": 0.85,
  "price": 1.0850,
  "stop_loss": 1.0830,
  "take_profit": 1.0900,
  "reason": "PERFECT Setup - FVG Breakout + OB Support"
}
```

### Pine Script Example (Copy & Paste)

**For Strategy**:
```pinescript
strategy("TradBOT Signal Sender", overlay=true)

// Your existing strategy logic...
if (buySignalDetected)
    msg = json.stringify({
        "symbol": syminfo.prefix + syminfo.basecurrency,
        "timeframe": timeframe.period,
        "action": "BUY",
        "confidence": 0.85,
        "price": close,
        "stop_loss": ta.lowest(low, 10),
        "take_profit": close + (ta.atr(14) * 2),
        "reason": "SMC Perfect Setup"
    })
    alert(msg)
```

**For Indicator**:
```pinescript
indicator("TradBOT Signal Detector", overlay=true)

// Your indicator logic...
if (bullishSignal)
    msg = json.stringify({
        "symbol": syminfo.prefix + syminfo.basecurrency,
        "timeframe": timeframe.period,
        "action": "BUY",
        "confidence": 0.80,
        "price": close,
        "reason": "Indicator confluence detected"
    })
    alert(msg)
```

---

## Signal Fields Reference

| Field | Type | Required | Example | Notes |
|-------|------|----------|---------|-------|
| `symbol` | string | ✓ | `EURUSD` | Format: [A-Z0-9_]{2,20} |
| `timeframe` | string | ✓ | `M5` | M1, M5, M15, M30, H1, H4, D1 |
| `action` | string | ✓ | `BUY` | BUY, SELL, or CLOSE |
| `confidence` | float | ✗ | `0.85` | Range: 0.0 to 1.0 (default: 0.75) |
| `price` | float | ✗ | `1.0850` | Current price (for logging) |
| `stop_loss` | float | ✗ | `1.0830` | SL level (optional, AI can calculate) |
| `take_profit` | float | ✗ | `1.0900` | TP level (optional, AI can calculate) |
| `reason` | string | ✗ | `FVG Breakout` | Analysis reason (for logging) |
| `alert_message` | string | ✗ | Raw message | Original alert text |
| `custom_data` | object | ✗ | `{"rsi": 75}` | Additional metadata |

---

## Step 4: Configure SMC_Universal.mq5

### Enable Webhook Signal Trading

In `SMC_Universal.mq5` (Inputs tab):
```
UseWebhookSignals = true          ✓ Enable webhook-sourced trades
AllowAutomaticEntryFromWebhook = true  ✓ Auto-execute on signal
WebhookConfidenceThreshold = 0.75      Minimum confidence (0.0-1.0)
```

### Optional: Manual Review Before Execution
Set `AllowAutomaticEntryFromWebhook = false` to:
- Receive push notifications when signal arrives
- Manually review and approve via MT5 UI
- Click "Execute Webhook Signal" to trade

---

## Step 5: Test End-to-End

### Test 1: Webhook Connectivity
```bash
# Check webhook is responding
curl http://localhost:8000/webhook/tradingview/test
```

### Test 2: Send Signal from TradingView
1. Open TradingView chart
2. Manually trigger alert via code:
   ```pinescript
   alert(json.stringify({
       "symbol": "EURUSD",
       "timeframe": "M5",
       "action": "BUY",
       "confidence": 0.90
   }))
   ```

### Test 3: Check AI Server Logs
```bash
# Monitor incoming signals in real-time
curl http://localhost:8000/logs?limit=50
```

Expected log entry:
```
📊 TradingView Signal reçu: EURUSD M5 BUY (confiance: 90%, prix: 1.0850)
✅ TradingView Signal traité: EURUSD → SIGNAL (temps: 0.145s)
```

### Test 4: Verify MT5 Trade Execution
1. Open MT5 terminal
2. Watch "Journal" tab for trade execution log
3. Check "Positions" for open trade

---

## Webhook Response Format

Every request returns:

```json
{
  "status": "SUCCESS",
  "symbol": "EURUSD",
  "action": "BUY",
  "timeframe": "M5",
  "confidence": 0.85,
  "decision": {
    "status": "SIGNAL",
    "verdict": "PERFECT",
    "score": 0.92,
    "signals": [...]
  },
  "source": "tradingview",
  "processed_at": "2026-05-22T14:30:45.123Z",
  "processing_time_ms": 145
}
```

### Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| 200 SUCCESS | Signal processed | Check `decision.verdict` for result |
| 400 Bad Request | Invalid symbol/timeframe/action | Fix Pine Script JSON |
| 500 Server Error | AI server crash | Check logs, restart server |

---

## Troubleshooting

### "Webhook URL not reachable"
- ✓ Verify Render app is deployed and running
- ✓ Check URL format: `https://your-app.onrender.com/webhook/tradingview`
- ✓ Test with: `curl https://your-app.onrender.com/webhook/tradingview/test`

### "Invalid symbol"
- ✓ Symbol must be 2-20 alphanumeric chars + underscores
- ✓ Example: `EURUSD` ✓ | `EUR_USD` ✓ | `EUR/USD` ✗

### "Timeframe not supported"
- ✓ Supported: M1, M5, M15, M30, H1, H4, D1
- ✓ Not supported: M2, M3, H2, H3

### "Action not recognized"
- ✓ Valid: `BUY`, `SELL`, `CLOSE`
- ✓ Invalid: `buy`, `Buy`, `LONG`, `SHORT`

### No Trade Executed
- ✓ Check MT5 IsWebhookSignalsAllowed = true
- ✓ Verify symbol is available on your broker
- ✓ Check account balance > 2x required margin
- ✓ Review MT5 Journal for rejection reason

### Signal Not Appearing in Logs
- ✓ Check AI server is running: `http://localhost:8000/health`
- ✓ Verify webhook URL is correct in TradingView
- ✓ Check TradingView alert is actually firing (add debug alert)

---

## Advanced: Custom Signal Processing

### Override AI Decision with Confidence Weighting

In `ai_server.py`, the webhook signal is converted to:

```python
analysis_payload = {
    "symbol": signal.symbol,
    "timeframe": signal.timeframe,
    "direction": signal.action,
    "confidence": signal.confidence,  # 0.0-1.0 from TradingView
    "stop_loss": signal.stop_loss,
    "take_profit": signal.take_profit,
    "reason": signal.reason,
    "source": "tradingview_webhook",
    "timestamp": datetime.utcnow().isoformat(),
}
```

This is then passed to `process_analysis_360()` which applies SMC validation logic.

### Example: Custom Data Injection

Send additional analysis data:

```pinescript
msg = json.stringify({
    "symbol": "EURUSD",
    "timeframe": "M5",
    "action": "BUY",
    "confidence": 0.85,
    "custom_data": {
        "rsi": 75,
        "macd_histogram": 0.0042,
        "divergence_type": "bullish_hidden",
        "confluence_score": 0.92
    }
})
alert(msg)
```

This data is merged into the analysis pipeline and used for additional context.

---

## Production Checklist

- [ ] Webhook URL is HTTPS (not HTTP)
- [ ] TradingView alert frequency is "Once per bar close"
- [ ] AI server is deployed to Render with auto-restart enabled
- [ ] MT5 is running on VPS 24/7
- [ ] `AllowAutomaticEntryFromWebhook = true` in SMC_Universal.mq5
- [ ] Account has sufficient balance for minimum lot size
- [ ] Tested with manual alert before enabling auto-trading
- [ ] Monitoring logs in real-time for any failures
- [ ] Backup manual trading if webhook fails

---

## Support

**Webhook Documentation Endpoint**:
```bash
curl http://localhost:8000/webhook/tradingview/docs
```

**Test Webhook**:
```bash
curl http://localhost:8000/webhook/tradingview/test
```

**Server Health**:
```bash
curl http://localhost:8000/health
```

**Recent Logs**:
```bash
curl http://localhost:8000/logs?limit=100
```

---

## Example: Complete Setup

### TradingView Alert Message
```json
{
  "symbol": "EURUSD",
  "timeframe": "M5",
  "action": "BUY",
  "confidence": 0.87,
  "price": 1.08564,
  "stop_loss": 1.08324,
  "take_profit": 1.08904,
  "reason": "FVG Breakout + OB Support Confluence"
}
```

### AI Server Response
```json
{
  "status": "SUCCESS",
  "symbol": "EURUSD",
  "action": "BUY",
  "timeframe": "M5",
  "confidence": 0.87,
  "decision": {
    "status": "SIGNALS",
    "count": 1,
    "signals": [
      {
        "status": "SIGNAL",
        "verdict": "PERFECT",
        "score": 0.91,
        "strategy": "SCALPING",
        "timeframe": "M5",
        "symbol": "EURUSD",
        "direction": "BUY",
        "reason": "Confluence: FVG + OB + Trend Alignment"
      }
    ]
  },
  "source": "tradingview",
  "processed_at": "2026-05-22T14:32:18.456Z",
  "processing_time_ms": 156
}
```

### MT5 Auto-Execution
```
[14:32:18] BUY 0.10 EURUSD @ 1.08564 SL=1.08324 TP=1.08904
[14:32:19] ✅ Position #123456 opened
[14:32:20] 📲 Notification: Perfect Setup - EURUSD BUY (87% confidence)
```

---

**Version**: 1.0  
**Last Updated**: 2026-05-22  
**TradBOT**: v1.00
