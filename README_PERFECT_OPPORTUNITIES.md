# 🎯 Perfect Opportunities Real-Time Scanner

Real-time detection and WhatsApp alerts for symbols meeting **ALL trading gates** simultaneously.

## ✨ Features

- ✅ **Real-time scanning** (every 30 seconds) for perfect trading conditions
- ✅ **WhatsApp alerts** (every 2 minutes) with current opportunities
- ✅ **Countdown timers** showing remaining trading window duration
- ✅ **Live dashboard** with visual opportunity tracking
- ✅ **Boom/Crash window detection** (UTC 08:00-16:00)
- ✅ **Symbol categorization** (Gold, Forex, BC, etc.)

## 📊 Perfect Opportunity Criteria

A symbol is **PERFECT** when **ALL** gates are ✅:

```
✓ IA Status Confidence    ≥ 70%
✓ GOM Coherence          ≥ 85%
✓ Probability Gate       ≥ 65%
✓ Action (BUY/SELL)      ✅ Confirmed
```

## 🚀 Quick Start

### 1. Install Scanner Service

```bash
# Windows (requires Admin)
cd D:\Dev\TradBOT
install_perfect_scanner_task.bat

# Verify installation
schtasks /query /tn "TradBOT-PerfectOpportunitiesScanner"
```

### 2. View Live Dashboard

Open in browser:
```
http://localhost:8000/dashboard/perfect_opportunities.html
```

### 3. Check WhatsApp Status

Scanner sends updates to your WhatsApp every 2 minutes when opportunities exist.

## 📋 Configuration

### Environment Variables

```bash
GOM_AI_SERVER=http://localhost:8000              # AI Server address
PSYCHOBOT_RENDER=http://localhost:3000           # PsychoBot WhatsApp endpoint
SCAN_INTERVAL=30                                 # Scan every N seconds
WHATSAPP_UPDATE_INTERVAL=120                     # Send WhatsApp every N seconds
OWNER_NUMBER=229                                 # Phone prefix for WhatsApp
```

### Thresholds (in code)

```python
MIN_IA_CONFIDENCE = 70.0      # IA confidence threshold %
MIN_GOM_COHERENCE = 85.0      # GOM coherence threshold %
MIN_PROBABILITY = 65.0        # Probability gate threshold %
```

## 🎯 WhatsApp Message Format

When opportunities are detected:

```
🎯 **PERFECT TRADING OPPORTUNITIES** 🎯
⏰ 14:32:45 UTC

📈 **XAUUSD**
  IA: 85% | GOM: 92% | PROB: 78%
  ⏱️  Trading until 16:00 UTC (1h 27m left)
  ✅ Perfect for 5m

📉 **Boom500**
  IA: 72% | GOM: 88% | PROB: 70%
  ⏱️  Trading until 16:00 UTC (1h 27m left)

📊 Total: 2 perfect opportunity(ies)
Ready to trade! ✨
```

## 📡 API Endpoints

### Get Current Opportunities

```bash
curl http://localhost:8000/api/perfect-opportunities
```

Response:
```json
{
  "opportunities": [
    {
      "symbol": "XAUUSD",
      "ia_confidence": 85.0,
      "gom_coherence": 92.0,
      "probability": 78.0,
      "action": "BUY",
      "detected_at": "2026-06-17T14:30:00"
    }
  ],
  "count": 1,
  "last_update": "2026-06-17T14:32:45"
}
```

### Get Specific Symbol

```bash
curl http://localhost:8000/api/perfect-opportunities/XAUUSD
```

## 🔍 How It Works

### Scanning Loop

```
1. Every 30 seconds:
   - Check each symbol's GOM verdict
   - Verify ALL gates are met (70% + 85% + 65%)
   - Track when opportunities become "perfect"

2. Every 2 minutes:
   - Send WhatsApp alert if opportunities exist
   - Include countdown timers
   - Show duration tracking

3. Dashboard (real-time):
   - Poll API every 5 seconds
   - Display cards with metrics
   - Show countdown animations
```

### Boom/Crash Window Detection

For Boom/Crash symbols (Boom500, Crash1000, etc.):

```
Trading Window: UTC 08:00 - 16:00
Outside window: Cannot trade

Countdown shows:
- IF 08:00-16:00 UTC: "Trading until 16:00 UTC (Xh Ym left)"
- IF other times: "Window closed. Opens 08:00 UTC (in Xh Ym)"
```

### Other Symbols (Gold, Forex, Crypto)

Standard 1-hour trading window with automatic renewal.

## 📊 Dashboard Features

- 🎯 **Real-time card display** for each perfect opportunity
- 📈/📉 **Action indicators** (BUY/SELL with color coding)
- 🔴 **Metrics visualization** (IA%, GOM%, PROB%)
- ⏱️ **Countdown timer** showing remaining window
- ✅ **Detection duration** showing how long symbol has been perfect
- 📊 **Status bar** with total count and last scan time

## 🛠️ Manual Control

### Start Scanner Now

```bash
schtasks /run /tn "TradBOT-PerfectOpportunitiesScanner"
```

### View Logs

```bash
# Real-time logs
Get-Content -Path "D:\Dev\TradBOT\logs\scanner.log" -Tail 50 -Wait

# Or view file
notepad D:\Dev\TradBOT\logs\scanner.log
```

### Stop Scanner

```bash
# Disable task (keeps it installed)
schtasks /change /tn "TradBOT-PerfectOpportunitiesScanner" /disable

# Or delete task completely
schtasks /delete /tn "TradBOT-PerfectOpportunitiesScanner" /f
```

## 🐛 Troubleshooting

### No WhatsApp Alerts

1. Check PsychoBot is running: `http://localhost:3000/status`
2. Verify OWNER_NUMBER in environment
3. Check logs: `Get-Content D:\Dev\TradBOT\logs\scanner.log | Select-Object -Last 20`

### Dashboard Shows "No opportunities"

1. Verify AI Server is running: `http://localhost:8000/health`
2. Check if any symbols meet criteria in logs
3. Try lowering thresholds temporarily to test

### Task Not Running

1. Verify task is enabled: `schtasks /query /tn "TradBOT-PerfectOpportunitiesScanner" /v`
2. Check Python path exists: `Test-Path "C:\Users\YourUser\AppData\Local\Programs\Python\Python314\python.exe"`
3. Run as Administrator: `schtasks /delete ... && run installer again`

## 📱 Integration with MT5

To receive alerts from MT5 EA:

1. EA detects perfect opportunity
2. Sends HTTP POST to Python scanner
3. Scanner adds to opportunities list
4. WhatsApp alert sent within 2 minutes
5. Dashboard updates in real-time

## 🎮 Development

### Run Scanner Manually

```bash
cd D:\Dev\TradBOT\Python
python perfect_opportunity_scanner.py

# With debug logging
DEBUG=1 python perfect_opportunity_scanner.py
```

### Modify Thresholds

Edit `perfect_opportunity_scanner.py`:

```python
MIN_IA_CONFIDENCE = 70.0      # Lower = more alerts
MIN_GOM_COHERENCE = 85.0
MIN_PROBABILITY = 65.0
```

### Custom Symbols List

Edit the `symbols_to_scan` list in `main()`:

```python
symbols_to_scan = [
    "XAUUSD", "EURUSD", "GBPUSD",
    "Boom500", "Crash500",
    # Add more...
]
```

## 📞 Support

- 📊 Dashboard: http://localhost:8000/dashboard/perfect_opportunities.html
- 📡 API: http://localhost:8000/api/perfect-opportunities
- 📱 WhatsApp: Check messages from PsychoBot
- 📋 Logs: D:\Dev\TradBOT\logs\scanner.log

---

**Version**: 1.0 | **Updated**: 2026-06-17 | **Status**: ✅ Production Ready
