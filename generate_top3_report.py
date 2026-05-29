#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import json
import os
from datetime import datetime, timezone
import requests
import warnings
warnings.filterwarnings('ignore')
import sys

if sys.platform == 'win32':
    os.environ['PYTHONIOENCODING'] = 'utf-8'

# Lire les données collectées
def load_json(path):
    try:
        with open(path, 'r') as f:
            return json.load(f)
    except:
        return {}

xau_bias = load_json('/tmp/xau_bias.json')
xau_order = load_json('/tmp/xau_order.json')
eur_bias = load_json('/tmp/eur_bias.json')
eur_order = load_json('/tmp/eur_order.json')
btc_bias = load_json('/tmp/btc_bias.json')
btc_order = load_json('/tmp/btc_order.json')

# Prix
prices = {
    "XAUUSD": 4553.77,
    "EURUSD": 1.0895,
    "BTCUSD": 62450.00
}

# Construire le rapport TOP 3
now_utc = datetime.now(timezone.utc)
time_str = now_utc.strftime("%H:%M")
date_str = now_utc.strftime("%d/%m")

# Préparer données pour chaque symbol
symbols_data = {
    'XAUUSD': {
        'bias': xau_bias,
        'order': xau_order,
        'price': prices['XAUUSD'],
        'verdict': xau_order.get('order', {}).get('gom_verdict', 'WAIT') if xau_order.get('ok') else 'WAIT'
    },
    'EURUSD': {
        'bias': eur_bias,
        'order': eur_order,
        'price': prices['EURUSD'],
        'verdict': eur_order.get('order', {}).get('gom_verdict', 'WAIT') if eur_order.get('ok') else 'WAIT'
    },
    'BTCUSD': {
        'bias': btc_bias,
        'order': btc_order,
        'price': prices['BTCUSD'],
        'verdict': btc_order.get('order', {}).get('gom_verdict', 'WAIT') if btc_order.get('ok') else 'WAIT'
    }
}

# Calculer scores et trier
ranked = []
for symbol, data in symbols_data.items():
    bias_data = data['bias'].get('data', {})
    order_data = data['order'].get('order', {}) if data['order'].get('ok') else {}

    # Score confluence
    conf_score = 0
    details = []
    if bias_data.get('direction') == 'BUY':
        conf_score += 1
        details.append('BIAS:BUY')
    if order_data.get('action') == 'BUY':
        conf_score += 1
        details.append('ORDER:BUY')

    ranked.append({
        'symbol': symbol,
        'price': data['price'],
        'confluence': conf_score,
        'verdict': data['verdict'],
        'bias_direction': bias_data.get('direction', 'NEUTRAL'),
        'bias_confidence': bias_data.get('confidence', 0),
        'order_action': order_data.get('action', 'NONE'),
        'entry_price': order_data.get('entry_price'),
        'sl': order_data.get('stop_loss'),
        'tp': order_data.get('take_profit'),
        'gom_score_buy': order_data.get('gom_score_buy', 0),
        'gom_score_sell': order_data.get('gom_score_sell', 0),
        'details': details
    })

# Trier par confluence descendant
ranked.sort(key=lambda x: x['confluence'], reverse=True)

# Construire message TOP 3
msg = f"""📊 *TradBOT TOP 3 MONITOR* [{time_str} UTC]

*SURVEILLANCE 20min* | {date_str} {time_str} UTC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"""

for idx, sym_data in enumerate(ranked[:3], 1):
    medal = ['🥇', '🥈', '🥉'][idx-1]

    # Emoji verdict
    if sym_data['verdict'] in ['PERFECT BUY', 'GOOD BUY']:
        verdict_emoji = '🟢'
    elif sym_data['verdict'] == 'BUY':
        verdict_emoji = '🟢'
    elif sym_data['verdict'] == 'SELL':
        verdict_emoji = '🔴'
    else:
        verdict_emoji = '⚪'

    bias_emoji = '🟢' if sym_data['bias_direction'] == 'BUY' else '🔴' if sym_data['bias_direction'] == 'SELL' else '⚪'

    msg += f"""{medal} *{sym_data['symbol']}* | ${sym_data['price']:.4f}
   {verdict_emoji} GOM: {sym_data['verdict']} | BUY={sym_data['gom_score_buy']:.1f} SELL={sym_data['gom_score_sell']:.1f}
   {bias_emoji} Bias: {sym_data['bias_direction']} {sym_data['bias_confidence']*100:.0f}%
   Score Confluence: {sym_data['confluence']}/2 {', '.join(sym_data['details'])}
"""

    if sym_data['order_action'] != 'NONE':
        msg += f"   Order: {sym_data['order_action']} @ ${sym_data['entry_price']:.4f} | SL: ${sym_data['sl']:.4f} | TP: ${sym_data['tp']:.4f}\n"
    else:
        msg += f"   No active order\n"

    msg += "\n"

msg += """━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ANALYSE CROISEE
"""

# Confluence analysis
top1 = ranked[0]
if top1['confluence'] >= 2:
    msg += f"   TOP 1 ({top1['symbol']}): MULTIPLE CONFLUENCE\n"
    msg += f"   Execute TOP 1 immediately\n"
    msg += f"   Queue TOP 2, 3 for entry signals\n"
else:
    msg += f"   Mixed signals detected\n"
    msg += f"   Wait for confluence confirmation\n"

msg += """
DECISION SCALPING
"""

buy_count = sum(1 for s in ranked if s['verdict'] in ['BUY', 'GOOD BUY', 'PERFECT BUY'])

if buy_count >= 2:
    msg += f"   {buy_count} BUY signals detected → EXECUTE TOP 1\n"
elif buy_count >= 1:
    msg += f"   1 BUY signal → WAIT for confirmation\n"
else:
    msg += f"   No BUY confluence → HOLD/WAIT\n"

msg += """━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
_Prochain scan dans 20 min_"""

# Sauvegarder
with open("D:\\Dev\\TradBOT\\top3_report_latest.txt", "w", encoding="utf-8") as f:
    f.write(msg)

# Afficher sans emojis pour éviter les problèmes
print("=" * 70)
print("[RAPPORT TOP 3 CONSTRUIT ET SAUVEGARDE]")
print("=" * 70)

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
    else:
        print(f"[ERROR] {resp.status_code}")
except Exception as e:
    print(f"[ERROR] {e}")

print("\nDone!")
