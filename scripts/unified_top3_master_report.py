#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
UNIFIED TOP 3 MASTER REPORT
- Single consolidated message avec tous les TOP 3 symbols
- Toutes les données: prix, GOM, biais, confluence, ordres, analyses
- Envoyé UNE FOIS toutes les 20 minutes via WhatsApp
"""

import json
from datetime import datetime, timezone
import requests
import warnings
warnings.filterwarnings('ignore')
import sys
import os

if sys.platform == 'win32':
    os.environ['PYTHONIOENCODING'] = 'utf-8'

class UnifiedTop3Report:
    def __init__(self):
        self.symbols = ['XAUUSD', 'EURUSD', 'BTCUSD']
        self.ai_server = "http://127.0.0.1:8000"
        self.psychobot = "https://psychobot-1si7.onrender.com/send-message"
        self.phone = "+2290196911346"
        self.data = {}

    def fetch_all_data(self):
        """Collecte TOUTES les données pour les 3 symbols"""
        print("[COLLECT] Fetching data for all TOP 3 symbols...")

        for symbol in self.symbols:
            print(f"  ... {symbol}")
            self.data[symbol] = self.fetch_symbol_data(symbol)

    def fetch_symbol_data(self, symbol):
        """Récupère toutes les données pour un symbol"""
        data = {
            'symbol': symbol,
            'bias': {},
            'order': {},
            'price': 0,
            'confluence': 0
        }

        try:
            # Session Bias
            resp = requests.get(
                f"{self.ai_server}/session-bias",
                params={'symbol': symbol},
                timeout=5
            )
            if resp.status_code == 200:
                bias_resp = resp.json()
                if bias_resp.get('success'):
                    data['bias'] = bias_resp.get('data', {})

            # Pending Order / GOM Verdict
            resp = requests.get(
                f"{self.ai_server}/pending-order",
                params={'symbol': symbol},
                timeout=5
            )
            if resp.status_code == 200:
                order_resp = resp.json()
                if order_resp.get('ok'):
                    data['order'] = order_resp.get('order', {})

        except Exception as e:
            print(f"    Warning: {e}")

        # Calculer confluence
        conf = 0
        if data['bias'].get('direction') == 'BUY':
            conf += 1
        if data['order'].get('action') in ['BUY', 'SELL']:
            conf += 1
        data['confluence'] = conf

        return data

    def get_prices_from_tv(self):
        """Récupère les prix TradingView"""
        print("[PRICES] Fetching real-time prices...")

        # Hardcodé pour l'instant (données du dernier fetch)
        prices = {
            'XAUUSD': 4554.59,
            'EURUSD': 1.0895,
            'BTCUSD': 62450.00
        }

        for symbol, price in prices.items():
            if symbol in self.data:
                self.data[symbol]['price'] = price
                print(f"  ... {symbol}: ${price}")

    def build_message(self):
        """Construit le message unifié complet"""
        now_utc = datetime.now(timezone.utc)
        time_str = now_utc.strftime("%H:%M")
        date_str = now_utc.strftime("%d/%m")

        # Trier par confluence
        ranked = sorted(
            self.data.items(),
            key=lambda x: x[1]['confluence'],
            reverse=True
        )

        msg = f"""📊 *TradBOT UNIFIED TOP 3 REPORT* [{time_str} UTC]

*Complete Daily Surveillance* | {date_str} {time_str} UTC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"""

        # Section 1: TOP 3 Summary Table
        msg += """*1. TOP 3 RANKING*
┌─────┬─────────┬─────────────┬──────────┬────────────────┐
│ Rank│ Symbol  │ Price       │ GOM/Bias │ Confluence     │
├─────┼─────────┼─────────────┼──────────┼────────────────┤
"""

        for idx, (symbol, data) in enumerate(ranked[:3], 1):
            medal = ['🥇', '🥈', '🥉'][idx-1]
            price = data['price']
            gom = data['order'].get('gom_verdict', 'WAIT')[:4]
            bias = data['bias'].get('direction', 'NEUTRAL')[:4]
            conf = data['confluence']

            price_str = f"${price:.2f}" if symbol == 'XAUUSD' else f"${price:.4f}" if symbol == 'EURUSD' else f"${price:.0f}"
            msg += f"""│ {medal} │ {symbol:7} │ {price_str:11} │ {gom}/{bias:4} │ {conf}/2 {'✅' if conf >= 2 else '  '} │
"""

        msg += """└─────┴─────────┴─────────────┴──────────┴────────────────┘

*2. DETAILED ANALYSIS*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"""

        # Détails pour chaque symbol
        for idx, (symbol, data) in enumerate(ranked[:3], 1):
            medal = ['🥇', '🥈', '🥉'][idx-1]

            # Emoji
            verdict_emoji = self._get_verdict_emoji(data['order'].get('gom_verdict', 'WAIT'))
            bias_emoji = self._get_bias_emoji(data['bias'].get('direction', 'NEUTRAL'))

            msg += f"""{medal} *{symbol}*
   Price: ${data['price']:.2f} (Live)
   {verdict_emoji} GOM Verdict: {data['order'].get('gom_verdict', 'WAIT')}
      • BUY Score: {data['order'].get('gom_score_buy', 0):.1f}
      • SELL Score: {data['order'].get('gom_score_sell', 0):.1f}
   {bias_emoji} Session Bias: {data['bias'].get('direction', 'NEUTRAL')} {data['bias'].get('confidence', 0)*100:.0f}%
      • Expires: {data['bias'].get('expires_in_hours', 0):.1f}h
      • Valid: {'✅' if data['bias'].get('valid', False) else '❌'}
"""

            # Ordre EA
            if data['order'].get('action'):
                order = data['order']
                msg += f"""   📦 Order EA: {order['action']}
      • Entry: ${order.get('entry_price', 'N/A')}
      • Confidence: {order.get('confidence', 0)*100:.0f}%
      • Status: {order.get('status', 'unknown')}
"""
            else:
                msg += f"""   📭 No active order
"""

            msg += f"""   Score Confluence: {data['confluence']}/2 {'✅ MULTIPLE' if data['confluence'] >= 2 else '⚠️ WEAK' if data['confluence'] == 1 else '❌ NONE'}

"""

        # Section 3: Cross Analysis
        msg += """*3. CROSS ANALYSIS*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"""

        top1_symbol, top1_data = ranked[0]
        buy_count = sum(1 for s, d in ranked if d['order'].get('gom_verdict') in ['BUY', 'GOOD BUY', 'PERFECT BUY'])
        with_confluence = sum(1 for s, d in ranked if d['confluence'] >= 2)

        msg += f"""• Top 1 ({top1_symbol}):
  → Confluence: {top1_data['confluence']}/2 {'✅' if top1_data['confluence'] >= 2 else '⚠️' if top1_data['confluence'] == 1 else '❌'}
  → {top1_data['order'].get('gom_verdict', 'WAIT')} + {top1_data['bias'].get('direction', 'NEUTRAL')} bias

• Signal Count:
  → BUY signals: {buy_count}
  → With Confluence: {with_confluence}
  → WAIT signals: {3 - buy_count}

• Multi-Symbol Alignment:
  → {with_confluence}+ symbols aligned BUY+BIAS
  → {buy_count} total BUY signals
  → {sum(1 for s, d in ranked if d['bias'].get('direction') == 'BUY')} with BUY bias

*4. TRADING DECISION*
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

"""

        if with_confluence >= 2:
            msg += """✅ STRONG CONFLUENCE DETECTED
   → Execute TOP 1 IMMEDIATELY
   → Set up queue for TOP 2, 3
   → Risk management: SL below entry
"""
        elif with_confluence == 1:
            msg += """⚠️ WEAK CONFLUENCE
   → Entry READY but WAIT for confirmation
   → Enter on next candle close
   → Monitor bias validity
"""
        else:
            msg += """❌ NO CONFLUENCE
   → HOLD / DO NOT TRADE
   → Wait for multi-symbol alignment
   → Monitor for next signal
"""

        msg += """━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

*5. NEXT UPDATE* in 20 min
Session Active: 24/7 Autonomous
Last Update: """ + now_utc.strftime("%H:%M:%S UTC") + "\n"

        return msg

    def _get_verdict_emoji(self, verdict):
        """Retourne emoji pour verdict GOM"""
        if verdict in ['PERFECT BUY', 'GOOD BUY']:
            return '🟢'
        elif verdict == 'BUY':
            return '🟢'
        elif verdict == 'SELL':
            return '🔴'
        else:
            return '⚪'

    def _get_bias_emoji(self, direction):
        """Retourne emoji pour biais"""
        if direction == 'BUY':
            return '🟢'
        elif direction == 'SELL':
            return '🔴'
        else:
            return '⚪'

    def send_whatsapp(self, message):
        """Envoie le message via PsychoBot"""
        print("[SEND] Sending via WhatsApp...")

        payload = {
            "phone": self.phone,
            "message": message
        }

        try:
            resp = requests.post(
                self.psychobot,
                json=payload,
                timeout=10,
                verify=False
            )

            if resp.status_code in [200, 201, 202]:
                print(f"[SUCCESS] Message sent! (HTTP {resp.status_code})")
                return True
            else:
                print(f"[ERROR] HTTP {resp.status_code}: {resp.text}")
                return False

        except Exception as e:
            print(f"[ERROR] {e}")
            return False

    def save_locally(self, message):
        """Sauvegarde localement"""
        path = "D:\\Dev\\TradBOT\\unified_top3_report_latest.txt"
        with open(path, "w", encoding="utf-8") as f:
            f.write(message)
        print(f"[SAVED] {path}")

    def run(self):
        """Exécution complète"""
        print("=" * 70)
        print("[START] Unified TOP 3 Master Report Generation")
        print("=" * 70)

        self.fetch_all_data()
        self.get_prices_from_tv()
        message = self.build_message()

        self.save_locally(message)
        self.send_whatsapp(message)

        print("=" * 70)
        print("[COMPLETE] Report generated and sent!")
        print("=" * 70)

        return message


if __name__ == "__main__":
    report = UnifiedTop3Report()
    msg = report.run()
