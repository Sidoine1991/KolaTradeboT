#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Build and send XAUUSD unified WhatsApp report"""

import sys
import io
import json
import subprocess
from datetime import datetime

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Raw data from TradingView
tv_quote = {
    "last": 73858.787,
    "high": 73858.787,
    "low": 73850.69,
}

tv_indicators = {
    "VWAP": 73551.829,
    "BB_Inf": 73829.599,
    "BB_Mid": 73893.669,
    "BB_Sup": 73957.739,
    "Supertrend": 77673.067,
    "RSI": 36.686,
    "ST_Dir": 1,  # UP
    "Score_Buy": 2.5,
    "Score_Sell": 4.8,
    "Spike_Pct": 11,
    "Verdict": "SELL",
    "Fib_0": 74069.488,
    "Fib_236": 74014.138,
    "Fib_382": 73979.897,
    "Fib_500": 73952.222,
    "Fib_618": 73924.547,
    "Fib_786": 73885.146,
}

# AI Server data
ai_bias = {
    "direction": "NEUTRAL",
    "confidence": 0.0,
    "age_hours": 32.66,
    "valid": False,
    "reason": "expired"
}

ai_order = {
    "ok": True,
    "action": "BUY",
    "entry_price": 4534.405,
    "stop_loss": 4532.35,
    "take_profit": 4545.35,
    "confidence": 0.88,
    "status": "ready"
}

ai_ta = {
    "ok": False,
    "direction": None,
}

timestamp = datetime.utcnow()
time_str = timestamp.strftime("%H:%M")
date_str = timestamp.strftime("%d/%m %H:%M UTC")

# Build message with exact format
message = f"""📊 TradBOT [{time_str} UTC]

*XAUUSD — Suivi 20min* | {date_str}
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* ${tv_quote['last']:.2f}
📍 VWAP : ${tv_indicators['VWAP']:.2f} → prix AU-DESSUS
📊 BB : [{tv_indicators['BB_Inf']:.2f} / {tv_indicators['BB_Mid']:.2f} / {tv_indicators['BB_Sup']:.2f}]
⚡ Supertrend : ${tv_indicators['Supertrend']:.2f} (↑)
📐 Fibo : [{tv_indicators['Fib_618']:.2f} / {tv_indicators['Fib_500']:.2f} / {tv_indicators['Fib_382']:.2f}]
━━━━━━━━━━━━━━━━━━━━
🔴 *Verdict GOM KOLA : {tv_indicators['Verdict']}*
   Score BUY={tv_indicators['Score_Buy']:.1f}  SELL={tv_indicators['Score_Sell']:.1f}  Spike={tv_indicators['Spike_Pct']}%
   RSI={tv_indicators['RSI']:.0f} | ST=↑
━━━━━━━━━━━━━━━━━━━━
⚪ *Biais session :* {ai_bias['direction']} ⚠️ EXPIRED ({ai_bias['age_hours']:.1f}h)
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* {ai_order['action']} @ {ai_order['entry_price']:.2f} | SL: {ai_order['stop_loss']:.2f} | TP: {ai_order['take_profit']:.2f} | ✅ {ai_order['status'].upper()}
━━━━━━━━━━━━━━━━━━━━
⚪ *Rapport TradingAgents :* N/A (données indisponibles)
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
  CONFLIT: GOM=SELL vs EA=BUY | Bias=EXPIRED
  → Attendre confirmation ou suivre ordre EA en place
🎯 *Décision scalping*
  WAIT — Ordre EA en attente de marché | GOM bearish mais non confirmé
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_"""

print("=" * 80)
print("MESSAGE COMPLET:")
print("=" * 80)
print(message)
print("=" * 80)

# Send via PsychoBot
print("\n📱 Envoi du message WhatsApp via PsychoBot...")

phone = "+2290196911346"
psychobot_url = "https://psychobot-1si7.onrender.com/send-message"

try:
    cmd = [
        "curl", "-s", "-X", "POST",
        psychobot_url,
        "-H", "Content-Type: application/json",
        "-d", json.dumps({"phone": phone, "message": message})
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)

    if result.returncode == 0:
        print("✅ Message WhatsApp envoyé avec succès!")
    else:
        print(f"⚠️ Erreur d'envoi: {result.returncode}")
        print("Sauvegarde dans le log...")

        # Fallback to log
        log_file = r"D:\Dev\TradBOT\whatsapp_alerts.log"
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(f"\n[{timestamp.strftime('%Y-%m-%d %H:%M:%S')}] XAUUSD UNIFIED REPORT\n")
            f.write(message + "\n")
            f.write("=" * 80 + "\n")
        print(f"✅ Message sauvegardé dans: {log_file}")

except Exception as e:
    print(f"❌ Erreur: {e}")
    print("Sauvegarde dans le log...")

    log_file = r"D:\Dev\TradBOT\whatsapp_alerts.log"
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(f"\n[{timestamp.strftime('%Y-%m-%d %H:%M:%S')}] XAUUSD UNIFIED REPORT\n")
        f.write(message + "\n")
        f.write("=" * 80 + "\n")
    print(f"✅ Message sauvegardé dans: {log_file}")

print("\n✅ Rapport XAUUSD complet")
