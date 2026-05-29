#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json
from datetime import datetime, timezone
import requests
import warnings
warnings.filterwarnings('ignore')
import sys
import os

# Force UTF-8 output
if sys.platform == 'win32':
    os.environ['PYTHONIOENCODING'] = 'utf-8'

# Données collectées
tv_data = {
    "price": 4553.775,
    "open": 4558.105,
    "high": 4558.105,
    "low": 4551.015,
    "close": 4553.775,
    "volume": 2744
}

gom_data = {
    "vwap": 4534.882,
    "bb_sup": 4586.209,
    "bb_mid": 4560.590,
    "bb_inf": 4534.971,
    "st_line": 5368.544,
    "st_dir": "UP",
    "fib_0": 4595.330,
    "fib_236": 4575.182,
    "fib_382": 4562.717,
    "fib_500": 4552.643,
    "fib_618": 4542.568,
    "fib_786": 4528.225,
    "fib_100": 4509.955,
    "score_buy": 4.110,
    "score_sell": 1.834,
    "spike_pct": 14.525,
    "rsi": 50.808,
    "verdict": "BUY",
    "verdict_num": 1,
    "quality": 34.109
}

bias_data = {
    "direction": "BUY",
    "confidence": 0.9,
    "age_hours": 11.99,
    "valid": True,
    "expires_hours": 12.01
}

order_data = {
    "ok": True,
    "action": "BUY",
    "entry_price": 4557.21,
    "stop_loss": None,
    "take_profit": None,
    "confidence": 0.88,
    "gom_verdict": "GOOD BUY",
    "gom_score_buy": 7.16,
    "gom_score_sell": 3.14
}

ta_data = {
    "ok": False,
    "direction": "NONE",
    "confidence": 0.0
}

# Construire le message
now_utc = datetime.now(timezone.utc)
time_str = now_utc.strftime("%H:%M")
date_str = now_utc.strftime("%d/%m")

# Déterminer position prix vs indicateurs
price = tv_data["price"]
vwap = gom_data["vwap"]
bb_inf = gom_data["bb_inf"]
bb_mid = gom_data["bb_mid"]
bb_sup = gom_data["bb_sup"]
st_line = gom_data["st_line"]

price_vs_vwap = "AU-DESSUS" if price > vwap else "EN-DESSOUS"
price_vs_st = "AU-DESSUS" if price > st_line else "EN-DESSOUS"

# Position BB
if price < bb_inf:
    bb_pos = "EN-DESSOUS (Inf)"
elif price < bb_mid:
    bb_pos = "ENTRE Inf/Mid"
elif price < bb_sup:
    bb_pos = "ENTRE Mid/Sup"
else:
    bb_pos = "AU-DESSUS (Sup)"

# Fib zone
fib_zone = ""
if price >= gom_data["fib_0"]:
    fib_zone = "Au-dessus 0% (sommet)"
elif price >= gom_data["fib_236"]:
    fib_zone = "Zone 23.6%"
elif price >= gom_data["fib_382"]:
    fib_zone = "Zone 38.2%"
elif price >= gom_data["fib_500"]:
    fib_zone = "Zone 50%"
elif price >= gom_data["fib_618"]:
    fib_zone = "Zone 61.8%"
elif price >= gom_data["fib_786"]:
    fib_zone = "Zone 78.6%"
else:
    fib_zone = "En-dessous 100% (bas)"

# Emoji verdict
verdict_emoji = "🟢" if gom_data["verdict"] == "BUY" else "🔴" if gom_data["verdict"] == "SELL" else "⚪"
bias_emoji = "🟢" if bias_data["direction"] == "BUY" else "🔴" if bias_data["direction"] == "SELL" else "⚪"
order_emoji = "🟢" if order_data["action"] == "BUY" else "🔴" if order_data["action"] == "SELL" else "⚪"
ta_emoji = "🟢" if ta_data["direction"] == "BUY" else "🔴" if ta_data["direction"] == "SELL" else "📭"

# Confluence (count agreements)
confluence = 0
details = []
if gom_data["verdict"] == "BUY":
    confluence += 1
    details.append("GOM: BUY")
if bias_data["direction"] == "BUY":
    confluence += 1
    details.append("BIAS: BUY")
if order_data["action"] == "BUY" and order_data["ok"]:
    confluence += 1
    details.append("ORDRE: BUY")
if ta_data["ok"] and ta_data["direction"] == "BUY":
    confluence += 1
    details.append("TA: BUY")

decision = "BUY" if confluence >= 2 else "WAIT"
if confluence == 0:
    decision = "WAIT"
    details.append("Aucune confluence")

# Construire message
msg = f"""📊 TradBOT [{time_str} UTC]

*XAUUSD — Suivi 20min* | {date_str} {time_str} UTC
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* ${price:.2f}
📍 VWAP : ${vwap:.2f} → prix {price_vs_vwap}
📊 BB : [${bb_inf:.2f} / ${bb_mid:.2f} / ${bb_sup:.2f}] → {bb_pos}
⚡ Supertrend : ${st_line:.2f} (UP) → prix {price_vs_st}
📐 Fibo : {fib_zone}
━━━━━━━━━━━━━━━━━━━━
{verdict_emoji} *Verdict GOM KOLA : {gom_data["verdict"]}*
   Score BUY={gom_data["score_buy"]:.1f}  SELL={gom_data["score_sell"]:.1f}  Spike={gom_data["spike_pct"]:.1f}%
   RSI={gom_data["rsi"]:.0f} | ST=UP
━━━━━━━━━━━━━━━━━━━━
{bias_emoji} *Biais session :* {bias_data["direction"]} {bias_data["confidence"]*100:.0f}% | ✅ valide {bias_data["expires_hours"]:.1f}h
━━━━━━━━━━━━━━━━━━━━
{order_emoji} *Ordre EA :* BUY @ ${order_data["entry_price"]:.2f} ({order_data["gom_verdict"]})
━━━━━━━━━━━━━━━━━━━━
{ta_emoji} *Rapport TradingAgents :* NONE (aucun rapport actif)
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisee*
  Confluence {confluence}/3: {", ".join(details)}
🎯 *Decision scalping*
  {decision}
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_"""

# Sauvegarder le message localement
with open("D:\\Dev\\TradBOT\\unified_report_latest.txt", "w", encoding="utf-8") as f:
    f.write(msg)

print("=" * 70)
print("[OK] Message unifié construit et sauvegardé")
print("=" * 70)

# Envoyer via PsychoBot
phone = "+2290196911346"
psychobot_url = "https://psychobot-1si7.onrender.com/send-message"

payload = {
    "phone": phone,
    "message": msg
}

print("\n[ENVOI] Via PsychoBot WhatsApp...")
try:
    resp = requests.post(psychobot_url, json=payload, timeout=10, verify=False)
    if resp.status_code in [200, 201, 202]:
        print(f"[SUCCESS] Message envoye via WhatsApp ! (HTTP {resp.status_code})")
    else:
        print(f"[ERROR] PsychoBot error: {resp.status_code}")
        print(f"Response: {resp.text}")
        with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
            f.write(f"\n[{now_utc.isoformat()}] [FALLBACK]\n{msg}\n")
except Exception as e:
    print(f"[ERROR] Exception: {e}")
    print(f"[FALLBACK] Message logged to whatsapp_alerts.log")
    with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
        f.write(f"\n[{now_utc.isoformat()}] [FALLBACK]\n{msg}\n")

print("\nDone!")
