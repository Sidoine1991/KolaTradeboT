#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Message WhatsApp Unifié XAUUSD - Format exact avec toutes les données
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

print("[BUILD] XAUUSD Complete Unified Report")
print("=" * 70)

# === DONNÉES TRADINGVIEW ===
tv = {
    "price": 4543.09,
    "vwap": 4535.978,
    "bb_sup": 4544.304,
    "bb_mid": 4543.150,
    "bb_inf": 4541.997,
    "st": 4576.986,
    "st_dir": "UP",
    "score_buy": 6.155,
    "score_sell": 2.710,
    "spike_pct": 11.245,
    "rsi": 49.094,
    "verdict_num": 2,  # BUY
    "coherence": 66.667,
    "quality": 61.219,
}

# === DONNÉES AI SERVER (À ajouter après curl) ===
ai = {
    "bias": None,
    "order": None,
    "ta": None,
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

# Fibo
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

# === MESSAGE EXACT FORMAT ===
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
"""

# Ajouter AI server data
try:
    resp_bias = requests.get("http://127.0.0.1:8000/session-bias?symbol=XAUUSD", timeout=10, verify=False)
    if resp_bias.status_code == 200:
        bias = resp_bias.json().get("data", {})
        direction = bias.get("direction", "UNKNOWN")
        confidence = bias.get("confidence", 0)
        validity = bias.get("expires_in_hours", 0)
        msg += f"[BIAS] Session : {direction} {confidence*100:.0f}% | [OK] valide {validity:.1f}h\n"
    else:
        msg += "[BIAS] Session : [WARNING] AI server unreachable\n"
except:
    msg += "[BIAS] Session : [WARNING] AI server offline\n"

try:
    resp_order = requests.get("http://127.0.0.1:8000/pending-order?symbol=XAUUSD", timeout=10, verify=False)
    if resp_order.status_code == 200:
        order = resp_order.json().get("order", {})
        if order.get("action"):
            action = order.get("action")
            price_order = order.get("entry_price", 0)
            conf = order.get("confidence", 0)
            msg += f"[ORDER] EA Order : {action} @ ${price_order:.2f} | Conf: {conf*100:.0f}%\n"
        else:
            msg += "[ORDER] EA Order : None active\n"
    else:
        msg += "[ORDER] EA Order : [WARNING] AI server unreachable\n"
except:
    msg += "[ORDER] EA Order : [WARNING] AI server offline\n"

try:
    resp_ta = requests.get("http://127.0.0.1:8000/tradingagents/report-status?symbol=XAUUSD", timeout=10, verify=False)
    if resp_ta.status_code == 200:
        ta = resp_ta.json()
        signal = ta.get("direction", "NONE")
        age = ta.get("age_minutes", 0)
        msg += f"[TA] TradingAgents : {signal} | Age: {age:.0f}min\n"
    else:
        msg += "[TA] TradingAgents : [WARNING] AI server unreachable\n"
except:
    msg += "[TA] TradingAgents : [WARNING] AI server offline\n"

msg += f"""
========================================
[ANALYSIS] Analyse croisee
  GOM Verdict: {verdict}
  Coherence: {tv['coherence']:.0f}%
  Quality: {tv['quality']:.0f}%

[DECISION] Decision scalping
  {verdict} - High Quality Setup
========================================
_Next check in 20 min_
"""

print("Message:")
print(msg)
print("\n" + "=" * 70)
print("[SEND] Sending via PsychoBot...")

try:
    resp = requests.post(
        "https://psychobot-1si7.onrender.com/send-message",
        json={"phone": "+2290196911346", "message": msg},
        timeout=15,
        verify=False
    )

    if resp.status_code == 200:
        print("[SUCCESS] Message sent to WhatsApp!")
        data = resp.json()
        print(f"  Phone: {data.get('phone')}")
        print(f"  Message: Sent")
    else:
        print(f"[WARNING] HTTP {resp.status_code}")
        with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
            f.write(f"\n[{now.isoformat()}]\n{msg}\n\n")
        print("[FALLBACK] Logged to whatsapp_alerts.log")

except Exception as e:
    print(f"[ERROR] {e}")
    with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
        f.write(f"\n[{now.isoformat()}]\n{msg}\n\n")
    print("[FALLBACK] Logged to whatsapp_alerts.log")

print("\n[COMPLETE]")
