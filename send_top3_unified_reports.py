#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Send unified WhatsApp reports for Top 3 symbols from morning scan
Envoie 3 rapports WhatsApp unifiés pour les Top 3 symbols
"""

import sys
import io
import json
import requests
from datetime import datetime, timezone

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

def format_price(value, decimals=2):
    """Format price with thousands separator"""
    if isinstance(value, str):
        value = float(value.replace(' ', '.').replace(',', '.'))
    return f"{value:,.{decimals}f}"

def build_message(symbol_data):
    """Build WhatsApp message for a symbol"""

    symbol = symbol_data['symbol']
    price = symbol_data['price']
    vwap = symbol_data['vwap']
    bb_sup = symbol_data['bb_sup']
    bb_mid = symbol_data['bb_mid']
    bb_inf = symbol_data['bb_inf']
    st = symbol_data['st']
    st_dir = symbol_data['st_dir']
    score_buy = symbol_data['score_buy']
    score_sell = symbol_data['score_sell']
    spike_pct = symbol_data['spike_pct']
    rsi = symbol_data['rsi']
    verdict_num = symbol_data['verdict_num']
    entry_quality = symbol_data['entry_quality']
    coherence_pct = symbol_data['coherence_pct']
    session_bias = symbol_data['session_bias']
    pending_order = symbol_data['pending_order']

    # Calculs
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
        2: ("GOOD BUY", "🟢"),
        3: ("PERFECT BUY", "🟢"),
    }
    verdict_text, verdict_emoji = verdict_map.get(verdict_num, ("WAIT", "🟡"))

    now_utc = datetime.now(timezone.utc)
    time_str = now_utc.strftime("%H:%M")
    date_str = now_utc.strftime("%d/%m %H:%M")

    msg = f"""📊 TradBOT [{time_str} UTC]

*{symbol} — Suivi 20min* | {date_str} UTC
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* ${format_price(price, 2)}
📍 VWAP : ${format_price(vwap, 2)} → prix {vwap_pos}
📊 BB : [{format_price(bb_inf, 0)} / {format_price(bb_mid, 0)} / {format_price(bb_sup, 0)}] → {bb_pos}
⚡ Supertrend : ${format_price(st, 0)} ({st_dir}) → {st_pos}
━━━━━━━━━━━━━━━━━━━━
{verdict_emoji} *Verdict GOM KOLA : {verdict_text}*
   Score BUY={score_buy:.1f}  SELL={score_sell:.1f}  Spike={spike_pct:.1f}%
   RSI={rsi:.0f} | ST={st_dir}
━━━━━━━━━━━━━━━━━━━━
🟡 *Biais session :* {session_bias}
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* {pending_order}
━━━━━━━━━━━━━━━━━━━━
🔬 *Analyse croisée*
  Verdict: {verdict_text} | Quality: {entry_quality:.0f}% | Coherence: {coherence_pct:.0f}%
🎯 *Décision scalping*
  Signal GOM {verdict_text} - À surveiller
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_"""

    return msg

def send_reports():
    """Collect data for Top 3 symbols and send unified reports"""

    print("\n" + "="*70)
    print("TOP 3 SYMBOLS UNIFIED REPORTS")
    print("="*70 + "\n")

    # Top 3 symbols data
    symbols_data = [
        {
            'symbol': 'BTCUSD',
            'price': 73563.01,
            'vwap': 73454,
            'bb_sup': 73604,
            'bb_mid': 73571,
            'bb_inf': 73537,
            'st': 77663,
            'st_dir': 'UP',
            'score_buy': 5.7,
            'score_sell': 3.2,
            'spike_pct': 7.0,
            'rsi': 53,
            'verdict_num': 2,  # GOOD BUY
            'entry_quality': 34,
            'coherence_pct': 50,
            'session_bias': 'NEUTRAL (expired 145h ago)',
            'pending_order': 'Aucun ordre actif'
        },
        {
            'symbol': 'ETHUSD',
            'price': 2015.03,
            'vwap': 2012.6,
            'bb_sup': 2016.9,
            'bb_mid': 2015.7,
            'bb_inf': 2014.5,
            'st': 2133.7,
            'st_dir': 'UP',
            'score_buy': 4.3,
            'score_sell': 4.8,
            'spike_pct': 12.3,
            'rsi': 37.3,
            'verdict_num': 0,  # WAIT
            'entry_quality': 15.7,
            'coherence_pct': 50,
            'session_bias': 'NEUTRAL (absent)',
            'pending_order': 'Aucun ordre actif'
        }
    ]

    session = requests.Session()
    session.verify = False

    sent_count = 0
    failed_count = 0

    for sym_data in symbols_data:
        print(f"\n[{sym_data['symbol']}] Building message...\n")

        msg = build_message(sym_data)
        print(msg)

        print(f"\n[{sym_data['symbol']}] Sending via PsychoBot...\n")

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
                print(f"[✅] {sym_data['symbol']} sent successfully")
                sent_count += 1
            else:
                print(f"[❌] {sym_data['symbol']} error: {resp.status_code}")
                failed_count += 1

                # Fallback to log
                try:
                    with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
                        now = datetime.now().isoformat()
                        f.write(f"\n{'='*70}\n[{now}] {sym_data['symbol']} Report (Fallback)\n{'='*70}\n{msg}\n")
                    print(f"[📝] Logged to fallback file")
                except:
                    pass

        except Exception as e:
            print(f"[❌] {sym_data['symbol']} error: {str(e)[:50]}")
            failed_count += 1

        print(f"\n" + "-"*70)

    # Summary
    print(f"\n" + "="*70)
    print(f"SUMMARY: {sent_count} sent, {failed_count} failed")
    print("="*70 + "\n")

    return sent_count == len(symbols_data)

if __name__ == "__main__":
    success = send_reports()
    sys.exit(0 if success else 1)
