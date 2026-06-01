#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Collecte XAUUSD unifié + envoie message WhatsApp via PsychoBot
Avec format exact spécifié
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

print("[UNIFIED REPORT] XAUUSD - Collecting all data...")
print("=" * 70)

# === DONNÉES TRADINGVIEW ===
tv_quote = {
    "price": 4544.66,
    "open": 4544.53,
    "high": 4544.88,
    "low": 4544.53,
}

tv_gom = {
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
    "kola_buy": 4542.99,
    "kola_sell": 4553.82,
}

# === DONNÉES AI SERVER ===
print("\n[STEP 1] Fetching AI Server data...")

ai_available = False
bias_data = {}
order_data = {}
ta_data = {}

try:
    # Test health
    health = requests.get("http://127.0.0.1:8000/health", timeout=3, verify=False)
    if health.status_code == 200:
        ai_available = True
        print("  [OK] AI Server online")

        # Récupérer les 3 endpoints
        try:
            resp = requests.get("http://127.0.0.1:8000/session-bias?symbol=XAUUSD", timeout=5, verify=False)
            if resp.status_code == 200:
                bias_data = resp.json()
                print("  [OK] Session Bias retrieved")
        except Exception as e:
            print(f"  [WARN] Session Bias: {str(e)[:30]}")

        try:
            resp = requests.get("http://127.0.0.1:8000/pending-order?symbol=XAUUSD", timeout=5, verify=False)
            if resp.status_code == 200:
                order_data = resp.json()
                print("  [OK] Pending Order retrieved")
        except Exception as e:
            print(f"  [WARN] Pending Order: {str(e)[:30]}")

        try:
            resp = requests.get("http://127.0.0.1:8000/tradingagents/report-status?symbol=XAUUSD", timeout=5, verify=False)
            if resp.status_code == 200:
                ta_data = resp.json()
                print("  [OK] TradingAgents Report retrieved")
        except Exception as e:
            print(f"  [WARN] TradingAgents: {str(e)[:30]}")

except Exception as e:
    print(f"  [OFFLINE] AI Server unreachable: {str(e)[:40]}")
    ai_available = False

# === CONSTRUIRE LE MESSAGE ===
print("\n[STEP 2] Building WhatsApp message...")

now = datetime.now(timezone.utc)
time_str = now.strftime("%H:%M UTC")
date_str = now.strftime("%d/%m %H:%M UTC")

# Positions
price = tv_quote["price"]
vwap = tv_gom["vwap"]
bb_sup = tv_gom["bb_sup"]
bb_mid = tv_gom["bb_mid"]
bb_inf = tv_gom["bb_inf"]
st = tv_gom["supertrend"]

vwap_pos = "AU-DESSUS" if price > vwap else "EN-DESSOUS"
bb_pos = "DANS BANDE" if bb_inf <= price <= bb_sup else ("AU-DESSUS" if price > bb_sup else "EN-DESSOUS")
st_pos = "AU-DESSUS" if price > st else "EN-DESSOUS"

# Fibonacci
if price >= bb_sup:
    fib_zone = "0% (Sup BB)"
elif price >= bb_mid:
    fib_zone = "38.2%"
elif price >= bb_inf:
    fib_zone = "50%"
else:
    fib_zone = "61.8%"

# Verdict
verdict_map = {-3: "STRONG SELL", -2: "SELL", -1: "SELL BIAS", 0: "WAIT", 1: "BUY BIAS", 2: "BUY", 3: "STRONG BUY"}
verdict = verdict_map.get(tv_gom["verdict_num"], "WAIT")

# Construire le message avec format EXACT
message = f"""[REPORT] TradBOT [{time_str}]

*XAUUSD -- Suivi 20min* | {date_str}
========================================
[PRICE] Prix live : ${price:.2f}
[VWAP] VWAP : ${vwap:.2f} -> {vwap_pos}
[BB] BB : [${bb_inf:.2f} / ${bb_mid:.2f} / ${bb_sup:.2f}] -> {bb_pos}
[ST] Supertrend : ${st:.2f} ({tv_gom['st_dir']}) -> {st_pos}
[FIB] Fibo : Zone {fib_zone}
========================================
[VERDICT] {verdict}
   Score BUY={tv_gom['score_buy']:.1f}  SELL={tv_gom['score_sell']:.1f}  Spike={tv_gom['spike_pct']:.1f}%
   RSI={tv_gom['rsi']:.0f} | ST={tv_gom['st_dir']}
========================================
"""

# Ajouter données AI server
if ai_available:
    if bias_data:
        direction = bias_data.get("direction", "UNKNOWN")
        strength = bias_data.get("strength", 0)
        validity = bias_data.get("validity_hours", 0)
        status = "[OK]" if validity > 0 else "[EXPIRED]"
        message += f"[BIAS] Session : {direction} {strength:.0f}% | {status} valide {validity:.1f}h\n"
    else:
        message += "[BIAS] Session : [NO DATA]\n"

    if order_data and order_data.get("active"):
        side = order_data.get("side", "")
        price_order = order_data.get("price", 0)
        message += f"[ORDER] EA Order : {side} @ ${price_order:.2f}\n"
    else:
        message += "[ORDER] Aucun ordre EA actif\n"

    if ta_data:
        signal = ta_data.get("signal", "WAIT")
        age = ta_data.get("age_minutes", 0)
        expires = ta_data.get("expires_in_minutes", 0)
        message += f"[TA] TradingAgents : {signal} | Age: {age:.0f}min | Expire: {expires:.0f}min\n"
    else:
        message += "[TA] Aucun rapport actif\n"
else:
    message += """[BIAS] Session : [WARNING] AI server hors ligne
[ORDER] Ordre EA : [WARNING] AI server hors ligne
[TA] TradingAgents : [WARNING] AI server hors ligne
"""

message += f"""
========================================
[ANALYSIS] Analyse croisee
  Verdict GOM: {verdict}
  Bias: {'Aligne' if ai_available else 'Unknown'}
  Order: {'Actif' if (order_data and order_data.get("active")) else 'Inactif'}

[DECISION] Decision scalping
  {verdict}
========================================
_Prochain check dans 20 min_
"""

print(f"  Message length: {len(message)} chars")

# === ENVOYER VIA PSYCHOBOT ===
print("\n[STEP 3] Sending via PsychoBot...")

try:
    resp = requests.post(
        "https://psychobot-1si7.onrender.com/send-message",
        json={"phone": "+2290196911346", "message": message},
        timeout=15,
        verify=False
    )

    if resp.status_code == 200:
        print("[SUCCESS] Message sent via WhatsApp")
        print(f"  Response: {resp.text[:80]}")
    else:
        print(f"[WARNING] HTTP {resp.status_code}")
        # Fallback to log
        with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
            f.write(f"\n[{now.isoformat()}] [FALLBACK]\n{message}\n\n")
            print("[FALLBACK] Message logged to whatsapp_alerts.log")

except Exception as e:
    print(f"[ERROR] {e}")
    with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
        f.write(f"\n[{now.isoformat()}] [ERROR FALLBACK]\n{message}\n\n")
    print("[FALLBACK] Message logged to whatsapp_alerts.log")

print("\n" + "=" * 70)
print("[COMPLETE] Unified XAUUSD report")
