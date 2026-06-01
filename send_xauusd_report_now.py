#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import io
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import json
import subprocess
from datetime import datetime

timestamp = datetime.utcnow()
time_str = timestamp.strftime("%H:%M")
date_str = timestamp.strftime("%d/%m %H:%M UTC")

# TradingView data
price = 73858.787
vwap = 73551.829
bb_inf = 73829.599
bb_mid = 73893.669
bb_sup = 73957.739
supertrend = 77673.067
rsi = 36.686
score_buy = 2.5
score_sell = 4.8
spike = 11
verdict = "SELL"

# AI Server data
bias_dir = "NEUTRAL"
bias_age = 32.66
order_action = "BUY"
order_entry = 4534.405
order_sl = 4532.35
order_tp = 4545.35

price_vs_vwap = "AU-DESSUS" if price > vwap else "EN-DESSOUS"
price_vs_st = "EN-DESSOUS" if price < supertrend else "AU-DESSUS"

message = f"""📊 TradBOT [{time_str} UTC]

*XAUUSD — Suivi 20min* | {date_str}
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* ${price:.2f}
📍 VWAP : ${vwap:.2f} → prix {price_vs_vwap}
📊 BB : [{bb_inf:.2f} / {bb_mid:.2f} / {bb_sup:.2f}]
⚡ Supertrend : ${supertrend:.2f} (↑) → {price_vs_st}
📐 Fibo : zone [{bb_inf:.2f} - {bb_sup:.2f}]
━━━━━━━━━━━━━━━━━━━━
🔴 *Verdict GOM KOLA : {verdict}*
   Score BUY={score_buy:.1f}  SELL={score_sell:.1f}  Spike={spike}%
   RSI={rsi:.0f} | ST=↑
━━━━━━━━━━━━━━━━━━━━
⚪ *Biais session :* {bias_dir} | ❌ EXPIRED ({bias_age:.1f}h)
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* {order_action} @ {order_entry:.2f} | SL: {order_sl:.2f} | TP: {order_tp:.2f}
━━━━━━━━━━━━━━━━━━━━
⚪ *Rapport TradingAgents :* N/A (données indisponibles)
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
  ⚠️ CONFLIT: GOM={verdict} vs EA={order_action}
  → Bias expiré, EA actif, attendre confirmation marché
🎯 *Décision scalping*
  WAIT — Ordre EA en place | GOM bearish non confirmé
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_"""

print("=" * 80)
print("MESSAGE UNIFIÉ:")
print("=" * 80)
print(message)
print("=" * 80)

payload = {"phone": "+2290196911346", "message": message}

print("\n📱 Envoi WhatsApp via PsychoBot...")
cmd = ["curl", "-s", "-X", "POST", "https://psychobot-1si7.onrender.com/send-message",
       "-H", "Content-Type: application/json", "-d", json.dumps(payload)]

try:
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    if result.returncode == 0:
        print("✅ Message envoyé avec succès!")
        print(f"Response: {result.stdout[:200]}")
    else:
        print(f"⚠️ Erreur HTTP: {result.returncode}")
        log_file = r"D:\Dev\TradBOT\whatsapp_alerts.log"
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"\n[{timestamp.strftime('%Y-%m-%d %H:%M:%S')}] XAUUSD UNIFIED\n")
            f.write(message + "\n")
            f.write("=" * 80 + "\n")
        print(f"✅ Sauvegardé dans: {log_file}")
except Exception as e:
    print(f"❌ Erreur: {e}")
    log_file = r"D:\Dev\TradBOT\whatsapp_alerts.log"
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(f"\n[{timestamp.strftime('%Y-%m-%d %H:%M:%S')}] XAUUSD UNIFIED\n")
        f.write(message + "\n")
        f.write("=" * 80 + "\n")
    print(f"✅ Sauvegardé dans: {log_file}")
