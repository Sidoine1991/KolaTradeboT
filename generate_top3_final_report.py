#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json
from datetime import datetime, timezone
import requests
import warnings
warnings.filterwarnings('ignore')
import sys
import os

if sys.platform == 'win32':
    os.environ['PYTHONIOENCODING'] = 'utf-8'

# Données réelles collectées
# XAUUSD: GOOD BUY actif
# EURUSD, BTCUSD: pas d'ordre (WAIT)

symbols_data = {
    'XAUUSD': {
        'price': 4553.77,
        'ok': True,
        'action': 'BUY',
        'verdict': 'GOOD BUY',
        'entry': 4557.21,
        'sl': None,
        'tp': None,
        'gom_buy': 7.16,
        'gom_sell': 3.14,
        'confidence': 0.88,
        'bias_direction': 'BUY',
        'bias_confidence': 0.9,
        'confluence': 2  # GOM BUY + Bias BUY
    },
    'EURUSD': {
        'price': 1.0895,
        'ok': False,
        'action': 'WAIT',
        'verdict': 'WAIT',
        'entry': None,
        'sl': None,
        'tp': None,
        'gom_buy': 0.0,
        'gom_sell': 0.0,
        'confidence': 0.0,
        'bias_direction': 'NEUTRAL',
        'bias_confidence': 0.0,
        'confluence': 0
    },
    'BTCUSD': {
        'price': 62450.00,
        'ok': False,
        'action': 'WAIT',
        'verdict': 'WAIT',
        'entry': None,
        'sl': None,
        'tp': None,
        'gom_buy': 0.0,
        'gom_sell': 0.0,
        'confidence': 0.0,
        'bias_direction': 'NEUTRAL',
        'bias_confidence': 0.0,
        'confluence': 0
    }
}

# Trier par confluence
ranked = []
for symbol, data in symbols_data.items():
    ranked.append((symbol, data))

ranked.sort(key=lambda x: x[1]['confluence'], reverse=True)

# Construire rapport
now_utc = datetime.now(timezone.utc)
time_str = now_utc.strftime("%H:%M")
date_str = now_utc.strftime("%d/%m")

msg = f"""📊 *TradBOT TOP 3 MONITOR* [{time_str} UTC]

*SURVEILLANCE 20min* | {date_str} {time_str} UTC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"""

for idx, (symbol, data) in enumerate(ranked[:3], 1):
    medal = ['🥇', '🥈', '🥉'][idx-1]

    # Emoji verdict
    if data['verdict'] in ['PERFECT BUY', 'GOOD BUY']:
        verdict_emoji = '🟢'
    elif data['verdict'] == 'BUY':
        verdict_emoji = '🟢'
    elif data['verdict'] == 'SELL':
        verdict_emoji = '🔴'
    else:
        verdict_emoji = '⚪'

    bias_emoji = '🟢' if data['bias_direction'] == 'BUY' else '🔴' if data['bias_direction'] == 'SELL' else '⚪'

    msg += f"""{medal} *{symbol}* | ${data['price']:.4f}
   {verdict_emoji} GOM: {data['verdict']} | BUY={data['gom_buy']:.1f} SELL={data['gom_sell']:.1f}
   {bias_emoji} Bias: {data['bias_direction']} {data['bias_confidence']*100:.0f}%
   Score Confluence: {data['confluence']}/2
"""

    if data['ok']:
        msg += f"   📦 Order: {data['action']} @ ${data['entry']:.2f}\n"
    else:
        msg += f"   📭 No active order\n"

    msg += "\n"

msg += """━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🔬 *ANALYSE CROISEE*
"""

top1_symbol, top1_data = ranked[0]

if top1_data['confluence'] >= 2:
    msg += f"   🟢 TOP 1 ({top1_symbol}): MULTIPLE CONFLUENCE\n"
    msg += f"   → BUY signal detected\n"
    msg += f"   → Entry ready at ${top1_data['entry']:.2f}\n"
else:
    msg += f"   ⚪ Mixed signals detected\n"
    msg += f"   → No confluence > TOP 1 (confluence={top1_data['confluence']}/2)\n"

msg += """
🎯 *DECISION SCALPING*
"""

buy_count = sum(1 for s, d in ranked if d['verdict'] in ['BUY', 'GOOD BUY', 'PERFECT BUY'])

if buy_count >= 2:
    msg += f"   ✅ {buy_count} BUY signals\n"
    msg += f"   → EXECUTE TOP 1 immediately\n"
elif buy_count >= 1:
    msg += f"   ⚠️ {buy_count} BUY signal\n"
    msg += f"   → READY but wait for confluence\n"
    msg += f"   → EXECUTE on next candle close\n"
else:
    msg += f"   ❌ No BUY signals\n"
    msg += f"   → HOLD / WAIT\n"

msg += """━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
_Prochain scan dans 20 min_"""

# Sauvegarder
with open("D:\\Dev\\TradBOT\\top3_report_latest.txt", "w", encoding="utf-8") as f:
    f.write(msg)

print("[SUCCESS] Rapport TOP 3 construit et sauvegarde")

# Envoyer via PsychoBot
phone = "+2290196911346"
psychobot_url = "https://psychobot-1si7.onrender.com/send-message"

payload = {
    "phone": phone,
    "message": msg
}

print("[ENVOI] Via PsychoBot WhatsApp...")
try:
    resp = requests.post(psychobot_url, json=payload, timeout=10, verify=False)
    if resp.status_code in [200, 201, 202]:
        print(f"[SUCCESS] Message TOP 3 envoye ! (HTTP {resp.status_code})")
        print(f"\nFichier sauvegarde: top3_report_latest.txt")
    else:
        print(f"[ERROR] {resp.status_code}")
except Exception as e:
    print(f"[ERROR] {e}")

print("\nDone!")
