# TradingView → TradBOT Quick Start

**5 minutes to live trading signals from TradingView**

---

## Step 1: Start AI Server (30 seconds)

```bash
cd D:\Dev\TradBOT
python ai_server.py
```

You should see:
```
INFO:     Uvicorn running on http://0.0.0.0:8000
```

---

## Step 2: Test Webhook (30 seconds)

**Option A: Command Line**
```bash
python test_tradingview_webhook.py
```

**Option B: Manual Test**
```bash
curl http://localhost:8000/webhook/tradingview/test
```

Expected response: `"status": "SUCCESS"` ✓

---

## Step 3: Copy Pine Script (1 minute)

Go to **TradingView** → **Pine Script Editor** → Create new script

Copy entire contents from: `D:\Dev\TradBOT\tradingview_template.pine`

Replace these lines with your strategy logic:

```pinescript
// YOUR STRATEGY LOGIC HERE
buySignal = rsiValue < 30 and close > ta.sma(close, 20)
sellSignal = rsiValue > 70 and close < ta.sma(close, 20)
```

Then click **"Add to Chart"**

---

## Step 4: Create Alert (2 minutes)

1. **Chart** → **Alerts** → **Create Alert**
2. Select your script name
3. Frequency: **"Once per bar close"**
4. Webhook checkbox: **Enable**
5. Message: Leave blank (uses default)
6. **Create**

Now scroll down to **"Manage Alerts"** (bell icon top-right)

1. Find your alert
2. Click **⋮ (three dots)** → **Configure webhook**
3. **Webhook URL**: 
   ```
   http://localhost:8000/webhook/tradingview
   ```
   (Or if using Render: `https://your-app.onrender.com/webhook/tradingview`)
4. Click **Save**

---

## Step 5: Enable MT5 Auto-Trading (1 minute)

**In MT5 Terminal** → Open **SMC_Universal.mq5** → Click **Inputs** tab

Enable these checkboxes:
- ✓ `UseWebhookSignals`
- ✓ `AllowAutomaticEntryFromWebhook`

---

## Test It

1. **Open a chart in TradingView**
2. **Manually trigger your alert** via Pine Script:
   ```pinescript
   alert("test")
   ```
3. **Watch MT5 terminal** for new trade
4. **Check logs**: `curl http://localhost:8000/logs?limit=20`

---

## What Just Happened

```
Pine Script Alert
    ↓
    Sends JSON via webhook
    ↓
ai_server.py validates
    ↓
Checks SMC rules + Confidence
    ↓
Returns VERDICT (PERFECT, GOOD, HOLD)
    ↓
MT5 executes (if PERFECT + auto-trading ON)
    ↓
Push notification sent
```

---

## Common Issues

| Problem | Solution |
|---------|----------|
| "Connection refused" | AI server not running. Run: `python ai_server.py` |
| Alert not firing | Check TradingView strategy has no compilation errors |
| No webhook received | Verify webhook URL in TradingView Manage Alerts |
| MT5 not trading | Check `AllowAutomaticEntryFromWebhook = true` |
| Wrong signal format | Copy entire `tradingview_template.pine` again |

---

## Next: Going Live

### Local Dev
- ✓ Done! Signals run from `localhost:8000`

### Cloud Deployment (Render)
1. Deploy ai_server.py to Render
2. Get app URL: `https://your-app.onrender.com`
3. Update TradingView webhook URL
4. Enable 24/7 auto-restart in Render
5. Add account balance monitoring

### See Also
- Full guide: `TRADINGVIEW_WEBHOOK_SETUP.md`
- Technical docs: `http://localhost:8000/webhook/tradingview/docs`
- API reference: `http://localhost:8000/swagger`

---

**You're ready! 🚀**
