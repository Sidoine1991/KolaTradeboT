#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Send XAUUSD unified WhatsApp message via PsychoBot
"""

import sys
import io
import json
import requests
from datetime import datetime, timezone

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Données TradingView XAUUSD
price = 4540.53
vwap = 4536.003
bb_sup = 4544.328
bb_mid = 4542.002
bb_inf = 4539.677
st = 4576.986
st_dir = "UP"
score_buy = 4.416
score_sell = 4.796
spike_pct = 4.561
rsi = 38.531
verdict_num = 0  # WAIT
entry_quality = 13.348
coherence_pct = 50.0
fib_500 = 4544.650

# Données AI Server
session_bias_dir = "NEUTRAL"
session_bias_age = 29.99
session_valid = False
pending_order = {
    "action": "BUY",
    "entry": 4534.405,
    "sl": 4532.35,
    "tp": 4545.35,
    "confidence": 0.88,
    "verdict": "PERFECT BUY"
}
ta_report = "NONE"

# Calculs
vwap_pos = "AU-DESSUS" if price > vwap else "EN-DESSOUS"

if price > bb_sup:
    bb_pos = "AU-DESSUS"
elif price < bb_inf:
    bb_pos = "EN-DESSOUS"
else:
    bb_pos = "DANS BANDE"

st_pos = "AU-DESSUS" if price > st else "EN-DESSOUS"

verdict_map = {
    -3: ("STRONG SELL", "🔴"),
    -2: ("SELL", "🔴"),
    -1: ("SELL BIAS", "🟠"),
    0: ("WAIT", "🟡"),
    1: ("BUY BIAS", "🟢"),
    2: ("BUY", "🟢"),
    3: ("PERFECT BUY", "🟢"),
}
verdict_text, verdict_emoji = verdict_map.get(verdict_num, ("WAIT", "🟡"))

# Fibo zone
fib_zone = "50%"

# Timestamp
now_utc = datetime.now(timezone.utc)
time_str = now_utc.strftime("%H:%M")
date_str = now_utc.strftime("%d/%m %H:%M")

# Message
msg = f"""📊 TradBOT [{time_str} UTC]

*XAUUSD — Suivi 20min* | {date_str} UTC
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* ${price:,.2f}
📍 VWAP : ${vwap:,.2f} → prix {vwap_pos}
📊 BB : [{bb_inf:,.0f} / {bb_mid:,.0f} / {bb_sup:,.0f}] → {bb_pos}
⚡ Supertrend : ${st:,.0f} ({st_dir}) → {st_pos}
📐 Fibo : zone {fib_zone}
━━━━━━━━━━━━━━━━━━━━
{verdict_emoji} *Verdict GOM KOLA : {verdict_text}*
   Score BUY={score_buy:.1f}  SELL={score_sell:.1f}  Spike={spike_pct:.1f}%
   RSI={rsi:.0f} | ST={st_dir}
━━━━━━━━━━━━━━━━━━━━
🟡 *Biais session :* {session_bias_dir} {int(session_bias_age)}h ago | ❌ Non valide
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* {pending_order['action']} ready @ ${pending_order['entry']:,.2f}
   Entry: ${pending_order['entry']:,.2f} | SL: ${pending_order['sl']:,.2f} | TP: ${pending_order['tp']:,.2f}
   Confidence: {int(pending_order['confidence']*100)}% | Verdict: {pending_order['verdict']}
━━━━━━━━━━━━━━━━━━━━
📭 *Rapport TradingAgents :* Aucun rapport actif
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
  GOM WAIT (équilibre BUY 4.4 vs SELL 4.8)
  Biais expiré (30h) → Signal EA autonome = PERFECT BUY
  Ordre EA actif confirmé
  CONFLUENCE : GOM WAIT >> Biais NEUTRAL >> Ordre BUY READY
🎯 *Décision scalping*
  ATTENDRE confluence avant entrée
  Ordres EA ready en attente du signal GOM
  Monitorer pour break de 4545 (TP EA)
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_"""

print(msg)
print("\n" + "="*70)
print("SENDING VIA PSYCHOBOT")
print("="*70 + "\n")

session = requests.Session()
session.verify = False

payload = {
    "phone": "+2290196911346",
    "message": msg
}

try:
    resp = session.post(
        "https://psychobot-1si7.onrender.com/send-message",
        json=payload,
        timeout=15
    )

    if resp.status_code in [200, 201]:
        print("[✅] Message sent successfully via PsychoBot")
        print(f"Status: {resp.status_code}")
        resp_data = resp.json()
        print(f"Response: {json.dumps(resp_data, indent=2)}\n")
        sys.exit(0)
    else:
        print(f"[❌] PsychoBot error: {resp.status_code}")
        print(f"Response: {resp.text[:300]}\n")
        raise Exception(f"Status {resp.status_code}")

except Exception as e:
    print(f"[❌] PsychoBot failed: {str(e)[:100]}")
    print("[📝] Logging to fallback file...\n")

    try:
        with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
            now = datetime.now().isoformat()
            f.write(f"\n{'='*70}\n[{now}] XAUUSD Unified Alert (PsychoBot Fallback)\n{'='*70}\n{msg}\n")
        print("[✅] Message logged to whatsapp_alerts.log\n")
        sys.exit(0)
    except Exception as log_err:
        print(f"[❌] Logging failed: {log_err}\n")
        sys.exit(1)
