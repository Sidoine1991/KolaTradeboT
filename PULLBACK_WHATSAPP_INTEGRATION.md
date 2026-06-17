# Pullback Entry System — WhatsApp Alerts Integration (Petit Capital)

## 🎯 Architecture Complète

```
SMC_Universal.mq5 (Pullback Event)
    ↓ WebRequest POST
AI Server /pullback-alert endpoint
    ↓ FastAPI receives event
pullback_alert_service.py
    ↓ Process & format
pullback_alert_formatter.py (calibrated on GOM)
    ↓ Beautiful formatted message
PsychoBot Render
    ↓
WhatsApp (NOT MT5 push notification)
    ↓
Your phone with full context ✅
```

---

## 📱 Files & Components

### 1. **Python Service Layer**

| File | Purpose |
|------|---------|
| `Python/pullback_alert_formatter.py` | Format messages with GOM context |
| `Python/pullback_alert_service.py` | Receive events, process, send alerts |
| `ai_server.py` | FastAPI endpoint `/pullback-alert` |

### 2. **MQL5 Module**

| File | Purpose |
|------|---------|
| `mt5/modules/SMC_PullbackAlerts.mqh` | Helper functions to send events |
| `mt5/SMC_Universal.mq5` | Include + call PullbackAlerts functions |

### 3. **Integration Points**

When Pullback System detects event in SMC_Universal:
```mql5
#include "modules/SMC_PullbackAlerts.mqh"

// Phase 1: Pullback starts
AlertPullbackStarted(
    symbol,
    "BUY",
    breakoutPrice,
    0.5, 1.5,           // min/max pullback %
    "PERFECT BUY",      // GOM level
    0.85,               // confidence
    75.0                // coherence
);

// Phase 2: Pullback detected
AlertPullbackDetected(
    symbol,
    "BUY",
    breakoutPrice,
    pullbackPrice,
    pullbackPct,
    atrValue,
    mlConfidence
);

// Phase 3: Resumption confirmed (GO!)
AlertResumptionConfirmed(
    symbol,
    "BUY",
    entryPrice,
    sl,
    tp,
    lot,
    coherence,
    "Kola Buy"
);

// Phase 4: Trade opened
AlertTradeOpened(
    symbol,
    "BUY",
    entryPrice,
    sl,
    tp,
    lot,
    ticket,
    "PERFECT BUY",
    0.85
);
```

---

## 🔧 Setup Instructions

### 1. **Enable MT5 WebRequest**

1. Open MT5 → **Tools → Options**
2. **Expert Advisors** tab
3. **"Allow WebRequest for listed URL"**
4. Add:
   ```
   http://127.0.0.1:8000
   https://psychobot-1si7.onrender.com
   ```
5. Click **OK**

### 2. **Python Service Dependencies**

Already installed (no new packages):
- `requests` — HTTP calls
- `logging` — File logging
- `json` — Message parsing

### 3. **MQL5 Integration**

Edit `SMC_Universal.mq5`:

```mql5
// Add at top after other includes
#include "modules/SMC_PullbackAlerts.mqh"

// In OnTick() when Pullback event detected:
if(pullbackStarted) {
    AlertPullbackStarted(
        symbol, "BUY", breakoutPrice,
        0.5, 1.5, gomLevel, gomConfidence, gomCoherence
    );
}
```

---

## 📊 Message Examples (With GOM Context)

### Phase 1: PULLBACK STARTED
```
🎯 *PULLBACK ENTRY INITIATED*

🟢 *Boom 150 Index* — BUY
Entry Level: 1456.23

📊 *GOM Context:*
GOM Level: PERFECT BUY
Confidence: 85%
Coherence: 75%

*Attente Pullback:*
Recul visé: 0.5% - 1.5%

⏰ 14:20:05 UTC
```

### Phase 3: RESUMPTION CONFIRMED
```
✅ *RESUMPTION CONFIRMED — GO!*

🟢 *Boom 150 Index* — BUY

*ENTRY:* 1453.45 (Kola Buy)
*SL:* 1451.95 ↘️
*TP:* 1455.20 ↗️
*Lot:* 0.01

*Risk/Reward:* 1:1.17
🔗 Coherence: 🟢 75%

*Signals:* EMA Cross + Volume Spike (2/3)

⏰ 14:25:33 UTC
```

### Phase 4: TRADE OPENED
```
💰 *TRADE OPENED*

🟢 *Boom 150 Index* | Method: PULLBACK
Ticket: #12345

*ENTRY:* 1453.45
*SL:* 1451.95
*TP:* 1455.20
*Lot:* 0.01

*Risk/Reward:*
Risk: $0.48 | Reward: $0.53
Ratio: 1:1.10

📊 GOM Context:
Verdict: PERFECT BUY
Confidence: 85%

⏰ 14:25:35 UTC
```

---

## 🛡️ For $10 Capital

**Why WhatsApp instead of MT5 push?**

1. ✅ **No push notification issues** — WhatsApp is 99% reliable
2. ✅ **Full context included** — GOM level, coherence, confidence visible
3. ✅ **Better decision making** — You see all metrics before opening trade
4. ✅ **Permanent record** — Message history in WhatsApp
5. ✅ **No app limitations** — MT5 mobile push drops frequently

**Risk management:**
- Every alert shows: Entry, SL, TP, Lot, Risk $, Reward $
- Risk capped at 5% of $10 = $0.50 max loss
- Ratio displayed (1:1.10 means $1.10 reward for $1 risk)
- GOM coherence shown — don't trade if < 70%

---

## 📋 Deployment Checklist

- [ ] `Python/pullback_alert_formatter.py` — READY
- [ ] `Python/pullback_alert_service.py` — READY
- [ ] `ai_server.py` — `/pullback-alert` endpoint added
- [ ] `mt5/modules/SMC_PullbackAlerts.mqh` — READY
- [ ] `SMC_Universal.mq5` — Add `#include "modules/SMC_PullbackAlerts.mqh"`
- [ ] `SMC_Universal.mq5` — Add calls to AlertPullbackStarted/Detected/etc
- [ ] MT5 WebRequest — URL authorized
- [ ] Test: Send test event via Python service
- [ ] Go LIVE: Recompile SMC_Universal (0 errors)

---

## 🧪 Testing

### Test Python Service Locally
```bash
cd D:/Dev/TradBOT/Python
python pullback_alert_service.py
```

Expected:
```
Starting Pullback Alert Service (test mode)
[EVENT] PULLBACK_START — Boom 150 Index BUY
[FORMAT] Message formatted successfully
[MOCK] Would send: 🎯 *PULLBACK ENTRY INITIATED*...
```

### Test End-to-End
1. Load SMC_Universal on Boom 150 M1
2. Wait for signal GOM PERFECT/GOOD
3. Check WhatsApp for 4 messages (Pullback Start → Detected → Go → Opened)
4. Verify message contains GOM context

---

## 🔄 Data Flow Example

```
SMC_Universal detects: GOM PERFECT BUY on Boom 150
    ↓
Calls: AlertPullbackStarted("Boom 150 Index", "BUY", 1456.23, ...)
    ↓
WebRequest POST to http://127.0.0.1:8000/pullback-alert
JSON: {
    "phase": "pullback_start",
    "symbol": "Boom 150 Index",
    "direction": "BUY",
    "gom_level": "PERFECT BUY",
    "gom_confidence": 0.85,
    "gom_coherence": 75.0
}
    ↓
ai_server.py /pullback-alert endpoint receives
    ↓
pullback_alert_service.handle_pullback_event()
    ↓
pullback_alert_formatter.format_pullback_started() 
    ↓ Injects GOM context into message
    ↓
send_via_psychobot(message)
    ↓
POST https://psychobot-1si7.onrender.com/send-message
    ↓
WhatsApp to +2290196911346 ✅
    ↓
You receive: 🎯 PULLBACK ENTRY INITIATED + GOM context
```

---

## 🚀 Live Usage

Once deployed:

1. **EA runs on MT5** — monitors Boom/Crash M1
2. **Signal triggered** — GOM PERFECT/GOOD detected
3. **Pullback System activates** — WebRequest → Python → WhatsApp
4. **You receive alert** — Beautiful formatted message with ALL context
5. **You decide** — Review metrics, accept or skip
6. **Trade opens** — Manual or auto (depends on your settings)
7. **You get confirmation** — Phase 4 alert with ticket + Risk/Reward

**All on WhatsApp, not MT5 push.** ✅

---

## 📞 Support

- **WhatsApp Endpoint**: `https://psychobot-1si7.onrender.com/send-message`
- **Phone**: `+2290196911346` (from env or hardcoded in ai_server.py)
- **Logs**: `D:/Dev/TradBOT/logs/pullback_alerts.log`

