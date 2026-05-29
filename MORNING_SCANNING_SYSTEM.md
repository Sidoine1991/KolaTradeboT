# 📊 Morning Scanning System — Auto Top 3 Opportunities

## Overview
Système de scan automatique qui **identifie les 3 meilleures opportunités du moment** et envoie **1 message WhatsApp consolidé** via PsychoBot.

---

## Architecture

### Étape 1: Collect Active Symbols
```
Sources:
1. MT5 MarketWatch (symboles ouverts)
2. Liste prédéfinie: XAUUSD, EURUSD, GBPUSD, BTCUSD, synthétiques
3. AI server: /pending-order status
```

### Étape 2: Score GOM Each Symbol
```
Pour chaque symbole:
- Fetch /gom-verdict (GOM score BUY/SELL)
- Fetch /session-bias (biais direction)
- Calculate confluence score (0-10)
- Sort par confluence descendante
```

### Étape 3: Select Top 3
```
Top 3 = symboles avec score confluence > 6
Classement: PERFECT BUY > GOOD BUY > BUY > WAIT
```

### Étape 4: Send Consolidated Message
```
1 message WhatsApp avec:
- Résumé des 3 symboles
- Scores comparatifs
- Décisions scalping rapides
```

---

## Symbols to Monitor

### Predefined List
```
GOLD:
  - XAUUSD (primary)

FOREX:
  - EURUSD
  - GBPUSD
  - AUDUSD

CRYPTO:
  - BTCUSD
  - ETHUSD

SYNTHETICS (Boom/Crash):
  - Boom 600 Index
  - Crash 600 Index
  - Volatility 75 Index
```

---

## Scoring Formula

```
Confluence Score = GOM_Signal + Bias_Direction + Multi_TF_Alignment

GOM_Signal (0-4 pts):
  PERFECT BUY/SELL = 4 pts
  GOOD BUY/SELL = 3 pts
  BUY/SELL = 2 pts
  WAIT = 0 pts

Bias_Direction (0-3 pts):
  Aligns with GOM = 3 pts
  Neutral = 1 pt
  Opposes GOM = 0 pts

Multi_TF_Alignment (0-3 pts):
  5+ TF aligned = 3 pts
  3-4 TF aligned = 2 pts
  2 TF aligned = 1 pt
  Mixed = 0 pts

Total: 0-10 pts
```

---

## Workflow

### Script Flow
```
1. Fetch all symbols from predefined list
2. For each symbol:
   - GET /gom-verdict
   - GET /session-bias
   - Calculate confluence score
3. Sort by score DESC
4. Select Top 3 (score > 4)
5. For each Top 3:
   - GET /pending-order
   - GET /tradingagents/report-status
6. Build consolidated WhatsApp message
7. Send via PsychoBot
8. Log to file (fallback)
```

---

## Message Format (Consolidated)

```
📊 TradBOT MORNING SCAN [HH:MM UTC]

*TOP 3 OPPORTUNITIES — 29/05 HH:MM UTC*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🥇 #1 — XAUUSD
   Confluence: 9.2/10 | GOM: PERFECT BUY | Bias: BUY 90%
   Price: $4528.39 | VWAP: $4510.62 (+$17.77)
   Entry: 4526.44 | SL: 4505.52 | TP: 4539.75
   Status: ✅ Ready
   
🥈 #2 — EURUSD  
   Confluence: 7.5/10 | GOM: GOOD BUY | Bias: BUY 75%
   Price: 1.0875 | VWAP: 1.0850 (+0.0025)
   Entry: 1.0870 | SL: 1.0820 | TP: 1.0920
   Status: ✅ Ready
   
🥉 #3 — BTCUSD
   Confluence: 6.8/10 | GOM: GOOD BUY | Bias: BUY 85%
   Price: $67250 | VWAP: $67100 (+$150)
   Entry: 67200 | SL: 67000 | TP: 67500
   Status: ⏳ Pending

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 COMPOSITE ANALYSIS
  ✅ All 3 align: BUY direction
  ✅ Multi-TF: 4 BULL average
  ⚠️ Coherence: 77% average (good)

🎯 STRATEGY
  1. Start with #1 (XAUUSD) — highest confluence
  2. Monitor #2, #3 for entry signals
  3. Close all if any hits WAIT
  
📌 Next scan: In 20 min
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Implementation

### Python Script: `morning_scan.py`
```python
import requests
import json
from datetime import datetime

class MorningScanner:
    def __init__(self, ai_server_url="http://127.0.0.1:8000"):
        self.ai_server = ai_server_url
        self.symbols = [
            "XAUUSD", "EURUSD", "GBPUSD", "BTCUSD",
            "Boom 600 Index", "Crash 600 Index"
        ]
    
    def scan_all(self):
        """Scan all symbols and return Top 3"""
        scores = []
        
        for sym in self.symbols:
            try:
                # Fetch GOM verdict
                gom = requests.get(
                    f"{self.ai_server}/gom-verdict?symbol={sym}",
                    timeout=5
                ).json()
                
                # Fetch bias
                bias = requests.get(
                    f"{self.ai_server}/session-bias?symbol={sym}",
                    timeout=5
                ).json()
                
                # Calculate confluence
                score = self.calculate_score(gom, bias)
                scores.append({
                    "symbol": sym,
                    "score": score,
                    "gom": gom,
                    "bias": bias
                })
            except:
                continue
        
        # Sort and return top 3
        top3 = sorted(scores, key=lambda x: x["score"], reverse=True)[:3]
        return top3
    
    def calculate_score(self, gom, bias):
        """Calculate confluence score"""
        score = 0
        
        # GOM signal
        vnum = gom.get("verdict_num", 0)
        if vnum in [3, -3]:
            score += 4
        elif vnum in [2, -2]:
            score += 3
        elif vnum in [1, -1]:
            score += 2
        
        # Bias alignment
        if bias.get("direction") in ["BUY", "SELL"]:
            score += 3
        
        # Multi-TF (from GOM)
        bull_count = gom.get("tf_bull_count", 0)
        if bull_count >= 5:
            score += 3
        elif bull_count >= 3:
            score += 2
        
        return score
    
    def build_message(self, top3):
        """Build consolidated WhatsApp message"""
        msg = f"📊 TradBOT MORNING SCAN [{datetime.utcnow().strftime('%H:%M')} UTC]\n\n"
        msg += f"*TOP 3 OPPORTUNITIES — {datetime.utcnow().strftime('%d/%m %H:%M UTC')}*\n"
        msg += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"
        
        for i, item in enumerate(top3, 1):
            sym = item["symbol"]
            score = item["score"]
            gom = item["gom"]
            bias = item["bias"]
            
            emoji = ["🥇", "🥈", "🥉"][i-1]
            msg += f"{emoji} #{i} — {sym}\n"
            msg += f"   Confluence: {score:.1f}/10 | GOM: {gom.get('verdict', 'N/A')} | "
            msg += f"Bias: {bias.get('direction', 'N/A')} {int(bias.get('confidence', 0)*100)}%\n"
            msg += f"   Status: ✅ Ready\n\n"
        
        msg += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        msg += "🎯 Start with #1 (highest confluence)\n"
        msg += "📌 Next scan: In 20 min\n"
        
        return msg

# Usage
scanner = MorningScanner()
top3 = scanner.scan_all()
message = scanner.build_message(top3)
print(message)
```

---

## Automation

### Scheduled Execution
```bash
# Every 20 minutes
*/20 * * * * python /D/Dev/TradBOT/morning_scan.py

# Every hour
0 * * * * python /D/Dev/TradBOT/morning_scan.py

# Every 4 hours (main scans)
0 */4 * * * python /D/Dev/TradBOT/morning_scan.py
```

---

## Integration with WhatsApp

### Send Message
```bash
curl -X POST "https://psychobot-1si7.onrender.com/send-message" \
  -H "Content-Type: application/json" \
  -d "{\"phone\": \"+2290196911346\", \"message\": \"$MESSAGE\"}"
```

### Fallback to Log
```bash
if [ $? -ne 0 ]; then
  echo "[$(date)] Message not sent — saved to log"
  echo "$MESSAGE" >> D:\Dev\TradBOT\whatsapp_alerts.log
fi
```

---

## Status

🔄 **Morning Scanning System — Ready**
- Scans predefined symbols
- Calculates confluence scores
- Identifies Top 3 opportunities
- Sends consolidated message every 20min
- Fallback logging if PsychoBot offline
