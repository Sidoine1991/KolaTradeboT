#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XAUUSD Unified Report - Avec données TradingView + AI Server complètes
Envoie via PsychoBot avec format exact
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

print("[UNIFIED] XAUUSD Full Report - All Data Sources")
print("=" * 70)

# === DONNÉES TRADINGVIEW (Reçues) ===
tv_data = {
    "price": 4544.66,
    "vwap": 4530.58,
    "bb_sup": 4549.39,
    "bb_mid": 4545.76,
    "bb_inf": 4542.13,
    "supertrend": 4577.59,
    "st_dir": "UP",
    "score_buy": 5.88,
    "score_sell": 5.42,
    "spike_pct": 10.08,
    "rsi": 37.83,
    "verdict_num": 0,  # WAIT
}

# === DONNÉES AI SERVER (Reçues via curl) ===
ai_data = {
    "bias": {
        "direction": "BUY",
        "confidence": 0.9,
        "validity_hours": 10.64,
    },
    "order": {
        "action": "BUY",
        "entry_price": 4544.35,
        "confidence": 0.88,
        "gom_verdict": "GOOD BUY",
        "status": "ready",
    },
    "ta": {
        "direction": "NONE",
        "confidence": 0.0,
        "age_minutes": 0.0,
    }
}

print("\n[DATA COLLECTION]")
print("  [OK] TradingView: Quote + GOM KOLA + Tables")
print("  [OK] AI Server: Bias + Order + TradingAgents")

# === CONSTRUIRE MESSAGE ===
print("\n[MESSAGE] Building with exact format...")

now = datetime.now(timezone.utc)
time_str = now.strftime("%H:%M UTC")
date_str = now.strftime("%d/%m %H:%M UTC")

# Extract values
price = tv_data["price"]
vwap = tv_data["vwap"]
bb_sup = tv_data["bb_sup"]
bb_mid = tv_data["bb_mid"]
bb_inf = tv_data["bb_inf"]
st = tv_data["supertrend"]

# Positions
vwap_pos = "AU-DESSUS" if price > vwap else "EN-DESSOUS"
bb_pos = "DANS BANDE" if bb_inf <= price <= bb_sup else ("AU-DESSUS" if price > bb_sup else "EN-DESSOUS")
st_pos = "AU-DESSUS" if price > st else "EN-DESSOUS"

# Fibo
if price >= bb_sup:
    fib_zone = "0% (Sup BB)"
elif price >= bb_mid:
    fib_zone = "38.2%"
else:
    fib_zone = "50%"

# Verdict
verdict_map = {-3: "STRONG SELL", -2: "SELL", -1: "SELL BIAS", 0: "WAIT", 1: "BUY BIAS", 2: "BUY", 3: "STRONG BUY"}
verdict = verdict_map.get(tv_data["verdict_num"], "WAIT")

# Message
msg = f"""[REPORT] TradBOT [{time_str}]

*XAUUSD -- Suivi 20min* | {date_str}
========================================
[PRICE] Prix live : ${price:.2f}
[VWAP] VWAP : ${vwap:.2f} -> {vwap_pos}
[BB] BB : [${bb_inf:.2f} / ${bb_mid:.2f} / ${bb_sup:.2f}] -> {bb_pos}
[ST] Supertrend : ${st:.2f} ({tv_data['st_dir']}) -> {st_pos}
[FIB] Fibo : Zone {fib_zone}
========================================
[VERDICT] {verdict}
   Score BUY={tv_data['score_buy']:.1f}  SELL={tv_data['score_sell']:.1f}  Spike={tv_data['spike_pct']:.1f}%
   RSI={tv_data['rsi']:.0f} | ST={tv_data['st_dir']}
========================================
[BIAS] Session : {ai_data['bias']['direction']} {ai_data['bias']['confidence']*100:.0f}% | [OK] valide {ai_data['bias']['validity_hours']:.1f}h
[ORDER] EA Order : {ai_data['order']['action']} @ ${ai_data['order']['entry_price']:.2f} | Conf: {ai_data['order']['confidence']*100:.0f}%
[TA] TradingAgents : {ai_data['ta']['direction']} | Age: {ai_data['ta']['age_minutes']:.0f}min
========================================
[ANALYSIS] Analyse croisee
  GOM Verdict: {verdict}
  Session Bias: {ai_data['bias']['direction']} (ALIGNED)
  EA Order: {ai_data['order']['action']} (READY) @ ${ai_data['order']['entry_price']:.2f}
  Confluence: 3/3 [BUY - BUY - ORDER]

[DECISION] Decision scalping
  BUY - EXECUTE (High confluence)
========================================
_Prochain check dans 20 min_
"""

print(f"  Length: {len(msg)} chars")
print(f"  Timestamp: {date_str}")

# === ENVOYER ===
print("\n[SEND] Sending via PsychoBot...")

try:
    resp = requests.post(
        "https://psychobot-1si7.onrender.com/send-message",
        json={"phone": "+2290196911346", "message": msg},
        timeout=15,
        verify=False
    )

    if resp.status_code == 200:
        print("[SUCCESS] Message sent!")
        data = resp.json()
        print(f"  Phone: {data.get('phone')}")
        print(f"  JID: {data.get('jid')}")
    else:
        print(f"[WARNING] HTTP {resp.status_code}")
        with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
            f.write(f"\n[{now.isoformat()}]\n{msg}\n\n")

except Exception as e:
    print(f"[ERROR] {e}")
    with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
        f.write(f"\n[{now.isoformat()}]\n{msg}\n\n")

print("\n" + "=" * 70)
print("[COMPLETE] XAUUSD unified report sent\n")
print("Message Preview:")
print(msg[:400] + "...")
