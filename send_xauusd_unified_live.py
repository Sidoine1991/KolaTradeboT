#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Collect XAUUSD data and send unified WhatsApp message via PsychoBot
Collecte données XAUUSD et envoie message WhatsApp unifié
"""

import sys
import io
import json
import requests
from datetime import datetime, timezone

# Force UTF-8 output
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def send_unified_message():
    """Collect all XAUUSD data and send unified WhatsApp message"""

    # ===== DONNÉES TRADINGVIEW (actuelle) =====
    price = 73622.017
    vwap = 73507.771
    bb_sup = 73676.826
    bb_mid = 73619.116
    bb_inf = 73561.405
    st = 77673.067
    st_dir = "UP"
    score_buy = 7.201
    score_sell = 0.150
    spike_pct = 6.635
    rsi = 56.176
    verdict_num = 3  # PERFECT BUY
    entry_quality = 42.173
    coherence_pct = 83.333
    fib_500 = 73609.615
    kola_entry = 73550.443
    kola_sl = 73548.398
    kola_tp1 = 73552.488
    kola_tp2 = 73553.511

    # ===== DONNÉES AI SERVER =====
    session_bias = "NEUTRAL (expired 29.8h ago)"
    pending_order = "BUY ready @ 73550.443 | Confidence: 88% | SL: 73548.398 | TP: 73552.488/73553.511"
    ta_report = "No active TradingAgents report"

    # ===== CALCULS =====
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

    # ===== TIMESTAMP =====
    now_utc = datetime.now(timezone.utc)
    time_str = now_utc.strftime("%H:%M")
    date_str = now_utc.strftime("%d/%m %H:%M")

    # ===== CONSTRUIRE MESSAGE =====
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
🟡 *Biais session :* {session_bias}
   ❌ Non valide (signal EA autonome)
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* {pending_order}
━━━━━━━━━━━━━━━━━━━━
📭 *Rapport TradingAgents :* {ta_report}
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
  GOM Signal TRÈS FORT : BUY 7.2 >> SELL 0.2 (confluence maximale)
  Quality setup : 42% (entrée confirmée)
  Coherence : 83% (très aligné)
  Biais expiré : Ordre EA autonome = signal principal
  CONFLUENCE : GOM BUY(7.2) >> Biais NEUTRAL >> TA NONE
🎯 *Décision scalping*
  ACTION : SUIVRE signal GOM PERFECT BUY (confidence 88%)
  Entrée confirmée @ ${kola_entry:,.0f}
  SL: ${kola_sl:,.0f} | TP1: ${kola_tp1:,.0f} | TP2: ${kola_tp2:,.0f}
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_"""

    print(msg)
    print("\n" + "="*70)
    print("SENDING VIA PSYCHOBOT")
    print("="*70 + "\n")

    # ===== ENVOYER VIA PSYCHOBOT =====
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
            print(f"Response: {resp.json() if resp.text else 'OK'}\n")
            return True
        else:
            print(f"[❌] PsychoBot error: {resp.status_code}")
            print(f"Response: {resp.text[:200]}\n")
            raise Exception(f"Status {resp.status_code}")

    except Exception as e:
        print(f"[❌] PsychoBot failed: {str(e)[:100]}")
        print("[📝] Logging to fallback file...\n")

        try:
            with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
                now = datetime.now().isoformat()
                f.write(f"\n{'='*70}\n[{now}] XAUUSD Unified Alert (PsychoBot Fallback)\n{'='*70}\n{msg}\n")
            print("[✅] Message logged to whatsapp_alerts.log\n")
            return True
        except Exception as log_err:
            print(f"[❌] Logging failed: {log_err}\n")
            return False

if __name__ == "__main__":
    success = send_unified_message()
    sys.exit(0 if success else 1)
