#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Message WhatsApp Unifié XAUUSD - Format exact spécifié
"""

import json
import requests
from datetime import datetime, timezone
import sys
import os
import urllib3

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

if sys.platform == 'win32':
    os.environ['PYTHONIOENCODING'] = 'utf-8'

print("[MESSAGE] Building XAUUSD unified WhatsApp report...")
print("=" * 70)

# === DONNÉES TRADINGVIEW ===
tv = {
    "price": 4544.35,
    "vwap": 4535.929,
    "bb_sup": 4548.515,
    "bb_mid": 4546.101,
    "bb_inf": 4543.687,
    "st": 4576.986,
    "st_dir": "UP",
    "score_buy": 5.697,
    "score_sell": 4.806,
    "spike_pct": 6.213,
    "rsi": 37.125,
    "verdict_num": 0,  # WAIT
    "coherence": 33.333,
    "quality": 36.179,
}

now = datetime.now(timezone.utc)
time_str = now.strftime("%H:%M UTC")
date_str = now.strftime("%d/%m %H:%M UTC")

# Positions
price = tv["price"]
vwap = tv["vwap"]
bb_sup = tv["bb_sup"]
bb_mid = tv["bb_mid"]
bb_inf = tv["bb_inf"]
st = tv["st"]

vwap_pos = "AU-DESSUS" if price > vwap else "EN-DESSOUS"
bb_pos = "DANS BANDE" if bb_inf <= price <= bb_sup else ("AU-DESSUS" if price > bb_sup else "EN-DESSOUS")
st_pos = "AU-DESSUS" if price > st else "EN-DESSOUS"

# Fibo zone
if price >= bb_sup:
    fib = "0% (Sup BB)"
elif price >= bb_mid:
    fib = "38.2%"
elif price >= bb_inf:
    fib = "50%"
else:
    fib = "61.8%"

# Verdict
verdict_map = {-3: "STRONG SELL", -2: "SELL", -1: "SELL BIAS", 0: "WAIT", 1: "BUY BIAS", 2: "BUY", 3: "STRONG BUY"}
verdict = verdict_map.get(tv["verdict_num"], "WAIT")

# === CONSTRUIRE LE MESSAGE EXACT ===
msg = f"""[REPORT] TradBOT [{time_str}]

*XAUUSD - Suivi 20min* | {date_str}
========================================
[PRICE] Prix live : ${price:.2f}
[VWAP] VWAP : ${vwap:.2f} -> {vwap_pos}
[BB] BB : [${bb_inf:.2f} / ${bb_mid:.2f} / ${bb_sup:.2f}] -> {bb_pos}
[ST] Supertrend : ${st:.2f} ({tv['st_dir']}) -> {st_pos}
[FIB] Fibo : {fib}
========================================
[VERDICT] {verdict}
   Score BUY={tv['score_buy']:.1f}  SELL={tv['score_sell']:.1f}  Spike={tv['spike_pct']:.1f}%
   RSI={tv['rsi']:.0f} | ST={tv['st_dir']}
========================================
[BIAS] Session : [WARNING] AI server offline
[ORDER] EA Order : [WARNING] AI server offline
[TA] TradingAgents : [WARNING] AI server offline
========================================
[ANALYSIS] Analyse croisee
  GOM Verdict: {verdict}
  Coherence: {tv['coherence']:.0f}%
  Quality: {tv['quality']:.0f}%
  Status: TradingView OK | AI OFFLINE

[DECISION] Decision scalping
  WAIT - Attendre AI server (bias + order)
========================================
_Next check in 20 min_
"""

print("Message construit :")
print(msg)
print("\n" + "=" * 70)
print("[SEND] Envoi via PsychoBot...")

try:
    resp = requests.post(
        "https://psychobot-1si7.onrender.com/send-message",
        json={"phone": "+2290196911346", "message": msg},
        timeout=15,
        verify=False
    )

    if resp.status_code == 200:
        print("[SUCCESS] Message envoyé via WhatsApp!")
        data = resp.json()
        print(f"  Phone: {data.get('phone')}")
        print(f"  JID: {data.get('jid')}")
    else:
        print(f"[WARNING] HTTP {resp.status_code}")
        with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
            f.write(f"\n[{now.isoformat()}] [FALLBACK]\n{msg}\n\n")
        print("[FALLBACK] Logged to whatsapp_alerts.log")

except Exception as e:
    print(f"[ERROR] {e}")
    with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
        f.write(f"\n[{now.isoformat()}] [ERROR]\n{msg}\n\n")
    print("[FALLBACK] Logged to whatsapp_alerts.log")

print("\n[COMPLETE]")
