#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Construire et envoyer le message WhatsApp unifié XAUUSD
"""
import json
import requests
from datetime import datetime, timezone
import sys

# Données TradingView (du chart)
tv_data = {
    "price": 73561.075,
    "vwap": 73505.433,
    "bb_sup": 73580.243,
    "bb_mid": 73559.357,
    "bb_inf": 73538.471,
    "st": 77673.067,
    "st_dir": "UP",
    "score_buy": 3.739,
    "score_sell": 3.539,
    "spike_pct": 9.864,
    "rsi": 47.614,
    "verdict_num": 0,
    "entry_quality": 13.753,
    "coherence_pct": 50.0,
}

def build_message(tv_data, ai_available=False):
    """Construire le message WhatsApp"""

    price = tv_data["price"]
    vwap = tv_data["vwap"]
    bb_sup = tv_data["bb_sup"]
    bb_mid = tv_data["bb_mid"]
    bb_inf = tv_data["bb_inf"]
    st = tv_data["st"]
    st_dir = tv_data["st_dir"]
    score_buy = tv_data["score_buy"]
    score_sell = tv_data["score_sell"]
    spike_pct = tv_data["spike_pct"]
    rsi = tv_data["rsi"]
    verdict_num = tv_data["verdict_num"]

    # Calculs
    vwap_pos = "AU-DESSUS" if price > vwap else "EN-DESSOUS"

    if price > bb_sup:
        bb_pos = "AU-DESSUS"
    elif price < bb_inf:
        bb_pos = "EN-DESSOUS"
    else:
        bb_pos = "DANS BANDE"

    st_pos = "AU-DESSUS" if price > st else "EN-DESSOUS"

    # Verdict emoji
    verdict_map = {
        -3: ("STRONG SELL", "🔴"),
        -2: ("SELL", "🔴"),
        -1: ("SELL BIAS", "🟠"),
        0: ("WAIT", "🟡"),
        1: ("BUY BIAS", "🟢"),
        2: ("BUY", "🟢"),
        3: ("STRONG BUY", "🟢"),
    }
    verdict_text, verdict_emoji = verdict_map.get(verdict_num, ("WAIT", "🟡"))

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
📐 Fibo : zone 50%
━━━━━━━━━━━━━━━━━━━━
{verdict_emoji} *Verdict GOM KOLA : {verdict_text}*
   Score BUY={score_buy:.1f}  SELL={score_sell:.1f}  Spike={spike_pct:.1f}%
   RSI={rsi:.0f} | ST={st_dir}
━━━━━━━━━━━━━━━━━━━━
"""

    if not ai_available:
        msg += """⚠️ *Biais session :* ⚠️ AI SERVER HORS LIGNE
━━━━━━━━━━━━━━━━━━━━
📭 *Ordre EA :* ⚠️ AI SERVER HORS LIGNE
━━━━━━━━━━━━━━━━━━━━
⚠️ *Rapport TradingAgents :* ⚠️ AI SERVER HORS LIGNE
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
  GOM en WAIT (équilibre BUY/SELL 3.7 vs 3.5)
  Spike détecté : +9.9% vs baseline
  Quality faible : 14% → signaux peu fiables
  Coherence modérée : 50%
🎯 *Décision scalping*
  ATTENDRE confirmation du biais session
  (AI server hors ligne — données incomplètes)
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_
_AI server reconnexion en cours..._"""

    return msg

def send_whatsapp(message):
    """Envoyer le message via PsychoBot"""
    try:
        url = "https://psychobot-1si7.onrender.com/send-message"
        payload = {
            "phone": "+2290196911346",
            "message": message
        }
        headers = {"Content-Type": "application/json"}

        # Désactiver la vérification SSL (Render a des issues de certificat)
        response = requests.post(url, json=payload, headers=headers, timeout=10, verify=False)

        if response.status_code in [200, 201]:
            print("[✅] Message sent successfully via PsychoBot")
            return True
        else:
            print(f"[❌] PsychoBot error: {response.status_code} - {response.text}")
            return False

    except Exception as e:
        print(f"[❌] PsychoBot timeout/error: {e}")
        return False

def log_message(message):
    """Écrire le message dans le log si PsychoBot échoue"""
    try:
        with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
            now = datetime.now().isoformat()
            f.write(f"\n{'='*60}\n[{now}] XAUUSD Alert\n{'='*60}\n{message}\n")
        print("[✅] Message logged to whatsapp_alerts.log")
        return True
    except Exception as e:
        print(f"[❌] Failed to log message: {e}")
        return False

if __name__ == "__main__":
    import io
    import sys

    # Force UTF-8 output
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

    # Construire le message
    msg = build_message(tv_data, ai_available=False)

    print(msg)
    print("\n" + "="*60)
    print("SENDING VIA PSYCHOBOT...")
    print("="*60 + "\n")

    # Essayer d'envoyer via PsychoBot
    sent = send_whatsapp(msg)

    # Si echec, logger le message
    if not sent:
        print("\n[!] Logging message as fallback...\n")
        log_message(msg)
