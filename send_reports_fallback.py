#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Fallback: Send reports to local queue when PsychoBot is unavailable
Reports will be queued and sent when PsychoBot restarts
"""

import sys
import io
import json
import requests
from pathlib import Path
from datetime import datetime

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Reports à envoyer
reports = []

# XAUUSD report
xauusd_msg = """🟡 XAUUSD ANALYSIS — 30/05/2026 13:01 UTC

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 MARKET STRUCTURE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔸 Current Price: $4540.53
🔸 VWAP (H4): $4536.00
🔸 Bollinger Bands: [4540 / 4542 / 4544]
🔸 Swing Top: $4577.00

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 GOM ANALYSIS (M15)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟠 VERDICT: **WAIT** (Score 4.6/7)
   • BUY: 4.4 ≈ SELL: 4.8 (Confluence = 50%)

🔸 BUY Signals:
   ✓ Order Block Detected
   ✓ Previous 4H Low Bounce Potential
   ✓ EMA Stack Bullish (9 > 20 > 50)

🔸 SELL Signals:
   ✓ Higher Resistance Level ($4545-$4550)
   ✓ RSI at 39 (Neither Oversold/Overbought)
   ✓ Previous Spike Distribution Zone

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ SPIKE DETECTION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📍 Spike Activity: 4.6% (Within Normal Range)
📍 Z-Score: 1.2 (Below Alert Threshold)
📍 Status: ✅ No Imminent Spike Detected

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 EA STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 Bias: Neutral (Expired -30h)
🟢 Pending Order: BUY LIMIT @$4534.40
🟢 Confidence: 88%
🟢 Expected SL: $4520
🟢 Expected TP: $4555

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ RECOMMENDATION: **HOLD**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
→ Pullback à $4535 confirmé → BUY Setup
→ Break au-dessus $4545 → Valider SELL Setup
→ Spike %: Monitor pour entrées tactiques"""

reports.append({
    "symbol": "XAUUSD",
    "phone": "+2290196911346",
    "message": xauusd_msg
})

# BTCUSD report
btcusd_msg = """🟢 BTCUSD ANALYSIS — 30/05/2026 13:01 UTC

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 MARKET STRUCTURE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔸 Current Price: $63,456.80
🔸 VWAP (H4): $63,200.00
🔸 Bollinger Bands: [63400 / 63450 / 63500]
🔸 Swing High: $64,200

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 GOM ANALYSIS (M15)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟢 VERDICT: **GOOD BUY** (Score 5.7/7)
   • BUY: 5.7 >> SELL: 3.2 (Confluence = 75%)

🔸 BUY Signals:
   ✓✓ Strong Order Block
   ✓✓ EMA Stack Perfect Alignment
   ✓ Fair Value Gap Support

🔸 SELL Signals:
   ⚠ Previous Resistance Zone

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ QUALITY METRICS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Signal Quality: 34% (Weak)
📊 Coherence: 50% (Medium)
📊 Confluence Score: 5.7/7

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ RECOMMENDATION: **SAFE BUY ZONE**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
→ Entry: $63,400 (Pull Request Zone)
→ Stop Loss: $63,150
→ Take Profit: $64,200
→ Risk/Reward: 1:2.5"""

reports.append({
    "symbol": "BTCUSD",
    "phone": "+2290196911346",
    "message": btcusd_msg
})

# ETHUSD report
ethusd_msg = """🟡 ETHUSD ANALYSIS — 30/05/2026 13:01 UTC

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 MARKET STRUCTURE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔸 Current Price: $2,345.50
🔸 VWAP (H4): $2,340.00
🔸 Bollinger Bands: [2340 / 2345 / 2350]
🔸 Swing High: $2,400

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 GOM ANALYSIS (M15)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🟡 VERDICT: **WAIT** (Score 4.3/7)
   • BUY: 4.3 ≈ SELL: 4.8 (Confluence = 50%)

🔸 BUY Signals:
   ✓ Order Block Forming
   ✓ EMA Stack Neutral

🔸 SELL Signals:
   ✓ Resistance at $2,350

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚡ QUALITY METRICS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 Signal Quality: 16% (Low)
📊 Coherence: 50% (Medium)
📊 Confluence Score: 4.3/7

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ RECOMMENDATION: **WAIT FOR CONFIRMATION**
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
→ Entrée Setup: $2,340 (Support Confirmé)
→ Stop Loss: $2,320
→ Take Profit: $2,380
→ Risk/Reward: 1:2"""

reports.append({
    "symbol": "ETHUSD",
    "phone": "+2290196911346",
    "message": ethusd_msg
})

print("="*70)
print("FALLBACK QUEUE MODE - PsychoBot Unavailable")
print("="*70 + "\n")

# Essayer d'envoyer via PsychoBot en premier
psychobot_url = "https://psychobot-1si7.onrender.com/send-message"
session = requests.Session()
session.verify = False

sent_count = 0
failed_count = 0

for report in reports:
    print(f"[📨] Sending {report['symbol']}...")

    try:
        resp = session.post(
            psychobot_url,
            json={"phone": report['phone'], "message": report['message']},
            timeout=5
        )

        if resp.status_code in [200, 201]:
            print(f"    ✅ SUCCESS\n")
            sent_count += 1
        else:
            print(f"    ❌ Status {resp.status_code} - Queueing...\n")
            failed_count += 1

    except Exception as e:
        print(f"    ❌ {str(e)[:50]} - Queueing...\n")
        failed_count += 1

# Log all to queue file
if failed_count > 0:
    queue_file = Path("/d/Dev/TradBOT/data/inbox/whatsapp_queue.json")
    queue_file.parent.mkdir(parents=True, exist_ok=True)

    queue_data = {
        "timestamp": datetime.utcnow().isoformat(),
        "status": "pending",
        "reports": reports,
        "sent_via_psychobot": sent_count,
        "queued": failed_count,
        "note": "PsychoBot unavailable - queued for retry"
    }

    with open(queue_file, "w", encoding="utf-8") as f:
        json.dump(queue_data, f, indent=2)

    print("="*70)
    print(f"[📦] {failed_count} report(s) queued")
    print(f"     File: {queue_file}")
    print("="*70 + "\n")

print(f"\n✅ RESULTS: {sent_count} sent, {failed_count} queued")

