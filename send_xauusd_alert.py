#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Build and send XAUUSD WhatsApp alert via PsychoBot
"""

import sys
import io
import requests
import json
from datetime import datetime

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Data collected
tv_data = {
    "price": 4537.845,
    "time": "11:25 UTC",
    "date": "29/05",
    "vwap": 4511.719,
    "bb_up": 4539.348,
    "bb_mid": 4523.662,
    "bb_dn": 4507.976,
    "supertrend": 5368.544,
    "fib_0": 4543.310,
    "fib_382": 4522.554,
    "rsi": 68,
    "verdict": "GOOD BUY",
    "score_buy": 6.7,
    "score_sell": 2.8,
    "spike_pct": 24,
    "st_dir": "UP",
    "coherence": 83,
    "quality": 52,
    "kola": "NEAR SELL",
    "bull_count": 5,
    "bear_count": 1
}

bias_data = {
    "direction": "BUY",
    "confidence": 90,
    "expires_in_hours": 20.01
}

order_data = {
    "action": "BUY",
    "entry": 4537.695,
    "confidence": 88,
    "status": "READY"
}

# Build message
price_vs_vwap = tv_data["price"] - tv_data["vwap"]
price_vs_vwap_txt = f"AU-DESSUS (+${price_vs_vwap:.2f})" if price_vs_vwap > 0 else f"EN-DESSOUS (${price_vs_vwap:.2f})"

bb_position = "EN HAUT" if tv_data["price"] > tv_data["bb_mid"] else "EN BAS"

# Determine verdict emoji
gom_emoji = "🟢" if tv_data["verdict"].startswith("BUY") or tv_data["verdict"] == "PERFECT BUY" else "🔴"
bias_emoji = "🟢" if bias_data["direction"] == "BUY" else "🔴"

message = f"""📊 TradBOT [{tv_data['time']}]

*XAUUSD — Suivi 20min* | {tv_data['date']} {tv_data['time']}
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* ${tv_data['price']:.2f}
📍 VWAP : ${tv_data['vwap']:.3f} → prix {price_vs_vwap_txt}
📊 BB : [${tv_data['bb_dn']:.3f} / ${tv_data['bb_mid']:.3f} / ${tv_data['bb_up']:.3f}] → {bb_position}
⚡ Supertrend : ${tv_data['supertrend']:.3f} ({tv_data['st_dir']}) → AU-DESSUS
📐 Fibo : ${tv_data['fib_0']:.3f} (R0) / ${tv_data['fib_382']:.3f} (S1)
━━━━━━━━━━━━━━━━━━━━
{gom_emoji} *Verdict GOM KOLA : {tv_data['verdict']}*
   Score BUY={tv_data['score_buy']:.1f}  SELL={tv_data['score_sell']:.1f}  Spike={tv_data['spike_pct']}%
   RSI={tv_data['rsi']} | ST={tv_data['st_dir']}
━━━━━━━━━━━━━━━━━━━━
{bias_emoji} *Biais session :* {bias_data['direction']} {bias_data['confidence']}% | ✅ valide {bias_data['expires_in_hours']:.1f}h
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* {gom_emoji} {order_data['action']} market @ ${order_data['entry']:.2f} | Conf {order_data['confidence']}% | {order_data['status']}
   SL: — | TP: —
━━━━━━━━━━━━━━━━━━━━
❌ *Rapport TradingAgents :* NONE | Pas d'ordre TA actif
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
  ✅ CONFLUENCE (3/4) : GOM {tv_data['verdict']} + Biais {bias_data['direction']} + Prix > VWAP
  ✅ Multi-TF : {tv_data['bull_count']} BULL / {tv_data['bear_count']} BEAR → Tendance haussière dominante
  ⚠️ KOLA: {tv_data['kola']} (divergence possible)
  ✅ Setup qualité: {tv_data['quality']}%
🎯 *Décision scalping*
  {gom_emoji} {order_data['action']} IMMÉDIAT — confluence dominante
  EL: {order_data['entry']:.2f}-{tv_data['bb_up']:.2f} | SL: {tv_data['bb_dn']:.2f} | TP1: {tv_data['fib_0']:.2f} | TP2: 4545
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_
"""

print("📊 Message XAUUSD construit:")
print("="*80)
print(message)
print("="*80)

# Send via PsychoBot
phone = "+2290196911346"
url = "https://psychobot-1si7.onrender.com/send-message"

print(f"\n📱 Envoi du message à {phone}...")

try:
    response = requests.post(
        url,
        json={"phone": phone, "message": message},
        timeout=15
    )

    if response.status_code == 200:
        print("✅ Message envoyé avec succès via PsychoBot")
    else:
        print(f"⚠️ Erreur HTTP {response.status_code} — Fallback logging")
        save_to_log(message)

except Exception as e:
    print(f"⚠️ Erreur: {e} — Fallback logging")
    # Save to log
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
        f.write(f"\n[{timestamp}] XAUUSD MARKET ALERT\n")
        f.write(message + "\n")
        f.write("="*80 + "\n\n")
    print("💾 Message sauvegardé dans whatsapp_alerts.log")

def save_to_log(msg):
    timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
    with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
        f.write(f"\n[{timestamp}] XAUUSD MARKET ALERT\n")
        f.write(msg + "\n")
        f.write("="*80 + "\n\n")
    print("💾 Message sauvegardé dans whatsapp_alerts.log")
