#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XAUUSD Unified Report — Collect TradingView + AI Server data, send via WhatsApp
Étapes:
1. Fetch TradingView data (MCP): quote, indicators, GOM KOLA tables
2. Fetch AI Server data (curl): session-bias, pending-order, tradingagents report
3. Build unified WhatsApp message with exact format
4. Send via PsychoBot (/send-message)
5. Fallback to log if PsychoBot down
"""

import sys
import io
import os
import json
import requests
import subprocess
from datetime import datetime, timedelta
from typing import Dict, Optional, Any

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


class XAUUSDReporter:
    def __init__(self, symbol="XAUUSD"):
        self.symbol = symbol
        self.tv_symbol = "OANDA:XAUUSD"  # TradingView format
        self.ai_server = "http://127.0.0.1:8000"
        self.psychobot_url = "https://psychobot-1si7.onrender.com/send-message"
        self.phone = "+2290196911346"
        self.log_file = "D:\\Dev\\TradBOT\\whatsapp_alerts.log"

        self.tv_data = {}
        self.ai_data = {}
        self.timestamp = datetime.utcnow()


    def fetch_tradingview_data(self) -> Dict[str, Any]:
        """Fetch TradingView data via MCP (quote, indicators, GOM tables)"""
        print("📺 Fetching TradingView data...")
        try:
            from mcp__tradingview_kola import (
                quote_get,
                data_get_study_values,
                data_get_pine_tables
            )

            tv_data = {}

            # Step 1: Get real-time quote
            try:
                quote = quote_get(symbol="OANDA:XAUUSD")
                if quote and 'ok' in quote and quote['ok']:
                    tv_data['quote'] = quote.get('quote', {})
                    print(f"  ✓ Quote: ${quote['quote'].get('last', 'N/A')}")
            except Exception as e:
                print(f"  ⚠️ Quote fetch failed: {e}")

            # Step 2: Get indicator values (RSI, Supertrend, BB, VWAP, etc.)
            try:
                study_values = data_get_study_values()
                tv_data['indicators'] = study_values
                print(f"  ✓ Indicators: {len(study_values) if study_values else 0} items")
            except Exception as e:
                print(f"  ⚠️ Indicators fetch failed: {e}")

            # Step 3: Get GOM KOLA tables (scores, verdict)
            try:
                gom_tables = data_get_pine_tables(study_filter="GOM KOLA")
                tv_data['gom'] = gom_tables
                print(f"  ✓ GOM KOLA: {len(gom_tables) if gom_tables else 0} tables")
            except Exception as e:
                print(f"  ⚠️ GOM tables fetch failed: {e}")

            self.tv_data = tv_data
            return tv_data

        except ImportError:
            print("  ⚠️ MCP tools not available, using fallback")
            return {}


    def fetch_ai_server_data(self) -> Dict[str, Any]:
        """Fetch AI Server data via curl (session-bias, pending-order, tradingagents report)"""
        print("🤖 Fetching AI Server data...")
        ai_data = {}

        # Endpoint 1: session-bias
        try:
            resp = requests.get(
                f"{self.ai_server}/session-bias?symbol={self.symbol}",
                timeout=10
            )
            if resp.status_code == 200:
                ai_data['bias'] = resp.json()
                print(f"  ✓ Session bias: {ai_data['bias'].get('direction', 'N/A')}")
            else:
                print(f"  ⚠️ Session bias: HTTP {resp.status_code}")
        except Exception as e:
            print(f"  ⚠️ Session bias failed: {e}")

        # Endpoint 2: pending-order
        try:
            resp = requests.get(
                f"{self.ai_server}/pending-order?symbol={self.symbol}",
                timeout=10
            )
            if resp.status_code == 200:
                ai_data['order'] = resp.json()
                print(f"  ✓ Pending order: {'✅ Active' if resp.json().get('ok') else '📭 None'}")
            else:
                print(f"  ⚠️ Pending order: HTTP {resp.status_code}")
        except Exception as e:
            print(f"  ⚠️ Pending order failed: {e}")

        # Endpoint 3: tradingagents report
        try:
            resp = requests.get(
                f"{self.ai_server}/tradingagents/report-status?symbol={self.symbol}",
                timeout=10
            )
            if resp.status_code == 200:
                ai_data['tradingagents'] = resp.json()
                print(f"  ✓ TradingAgents report: {ai_data['tradingagents'].get('direction', 'N/A')}")
            else:
                print(f"  ⚠️ TradingAgents: HTTP {resp.status_code}")
        except Exception as e:
            print(f"  ⚠️ TradingAgents failed: {e}")

        self.ai_data = ai_data
        return ai_data


    def build_message(self) -> str:
        """Build unified WhatsApp message with exact format"""
        time_str = self.timestamp.strftime("%H:%M")
        date_str = self.timestamp.strftime("%d/%m %H:%M UTC")

        msg = f"📊 TradBOT [{time_str} UTC]\n\n"
        msg += f"*{self.symbol} — Suivi 20min* | {date_str}\n"
        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 1: TradingView data
        quote = self.tv_data.get('quote', {})
        indicators = self.tv_data.get('indicators', {})

        price = quote.get('last', 'N/A')
        msg += f"💰 *Prix live :* ${price}\n"

        vwap = indicators.get('VWAP', 'N/A')
        if vwap != 'N/A':
            vwap_val = float(vwap) if isinstance(vwap, (int, float)) else vwap
            position = "AU-DESSUS" if price > vwap_val else "EN-DESSOUS" if price < vwap_val else "SUR"
            msg += f"📍 VWAP : {vwap_val} → prix {position}\n"

        # Bollinger Bands
        bb_high = indicators.get('BB_Upper', 'N/A')
        bb_mid = indicators.get('BB_Middle', 'N/A')
        bb_low = indicators.get('BB_Lower', 'N/A')
        msg += f"📊 BB : [{bb_low} / {bb_mid} / {bb_high}]\n"

        # Supertrend
        st = indicators.get('Supertrend', 'N/A')
        st_dir = "↑" if indicators.get('ST_Direction', 0) > 0 else "↓"
        msg += f"⚡ Supertrend : {st} ({st_dir})\n"

        # Fibo
        msg += f"📐 Fibo : (levels from chart)\n"
        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 2: GOM KOLA verdict
        gom = self.tv_data.get('gom', {})
        if gom:
            gom_tables = json.loads(gom) if isinstance(gom, str) else gom
            verdict = gom_tables[0].get('verdict', 'WAIT') if isinstance(gom_tables, list) and gom_tables else 'WAIT'
            verdict_emoji = "🟢" if verdict == "BUY" else "🔴" if verdict == "SELL" else "⚪"

            score_buy = gom_tables[0].get('score_buy', 0) if isinstance(gom_tables, list) and gom_tables else 0
            score_sell = gom_tables[0].get('score_sell', 0) if isinstance(gom_tables, list) and gom_tables else 0
            spike = gom_tables[0].get('spike_z', 0) if isinstance(gom_tables, list) and gom_tables else 0
            rsi = indicators.get('RSI', 'N/A')

            msg += f"{verdict_emoji} *Verdict GOM KOLA : {verdict}*\n"
            msg += f"   Score BUY={score_buy:.0f}  SELL={score_sell:.0f}  Spike={spike:.1f}%\n"
            msg += f"   RSI={rsi} | ST={st_dir}\n"
        else:
            msg += "⚪ *Verdict GOM KOLA : WAIT* (données indisponibles)\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 3: Session bias
        bias = self.ai_data.get('bias', {})
        if bias and bias.get('direction'):
            bias_emoji = "🟢" if bias['direction'] == "BUY" else "🔴" if bias['direction'] == "SELL" else "⚪"
            confidence = int(bias.get('confidence', 0) * 100)
            age = bias.get('age_minutes', 'N/A')
            msg += f"{bias_emoji} *Biais session :* {bias['direction']} {confidence}% | ✅ valide depuis {age}min\n"
        else:
            msg += "⚪ *Biais session :* N/A (hors-ligne)\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 4: Pending order from EA
        order = self.ai_data.get('order', {})
        if order.get('ok'):
            order_data = order.get('order', {})
            action = order_data.get('action', 'N/A')
            entry = order_data.get('entry_price', 'N/A')
            sl = order_data.get('sl', 'N/A')
            tp = order_data.get('tp', 'N/A')
            msg += f"📦 *Ordre EA :* {action} @ {entry} | SL: {sl} | TP: {tp}\n"
        else:
            msg += f"📭 *Ordre EA :* Aucun ordre actif\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 5: TradingAgents report
        ta = self.ai_data.get('tradingagents', {})
        if ta and ta.get('direction'):
            ta_emoji = "🟢" if ta['direction'] == "BUY" else "🔴" if ta['direction'] == "SELL" else "⚪"
            confidence = int(ta.get('confidence', 0) * 100)
            age = ta.get('age_minutes', 'N/A')
            entry = ta.get('entry_price', 'N/A')
            sl = ta.get('sl', 'N/A')
            tp = ta.get('tp', 'N/A')
            msg += f"{ta_emoji} *Rapport TradingAgents :* {ta['direction']} {confidence}% | Age: {age}min\n"
            msg += f"   Entrée: {entry} | SL: {sl} | TP: {tp}\n"
        else:
            msg += f"⚪ *Rapport TradingAgents :* N/A (hors-ligne)\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 6: Cross-analysis
        msg += "🔬 *Analyse croisée*\n"

        # Check confluence
        signals = []
        if bias and bias.get('direction'):
            signals.append(bias['direction'])
        if ta and ta.get('direction'):
            signals.append(ta['direction'])
        if gom:
            gom_verdict = "BUY" if gom_tables[0].get('verdict') == "BUY" else "SELL" if gom_tables[0].get('verdict') == "SELL" else None
            if gom_verdict:
                signals.append(gom_verdict)

        if signals:
            unique_signals = set(signals)
            if len(unique_signals) == 1:
                direction = unique_signals.pop()
                msg += f"  ✅ CONFLUENCE: Tous les signaux en {direction}\n"
            else:
                msg += f"  ⚠️ CONFLITS: Signaux mixtes {signals}\n"

        msg += "🎯 *Décision scalping*\n"
        if not self.ai_data.get('bias') and not self.ai_data.get('tradingagents'):
            msg += "  ⚠️ AI server hors ligne — données partielles\n"
        else:
            msg += "  (Voir ci-dessus pour BUY/SELL/WAIT)\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"
        msg += "_Prochain check dans 20 min_"

        return msg


    def send_whatsapp(self, message: str) -> bool:
        """Send message via PsychoBot"""
        print("\n📱 Sending WhatsApp message...")
        try:
            payload = {
                "phone": self.phone,
                "message": message
            }
            response = requests.post(
                self.psychobot_url,
                json=payload,
                timeout=15,
                verify=False
            )

            if response.status_code == 200:
                print("✅ WhatsApp message sent successfully")
                return True
            else:
                print(f"⚠️ WhatsApp send failed: HTTP {response.status_code}")
                return False

        except Exception as e:
            print(f"❌ WhatsApp send error: {e}")
            return False


    def save_to_log(self, message: str) -> bool:
        """Save message to log file as fallback"""
        try:
            timestamp = self.timestamp.strftime("%Y-%m-%d %H:%M:%S")
            with open(self.log_file, "a", encoding="utf-8") as f:
                f.write(f"\n[{timestamp}] XAUUSD UNIFIED REPORT\n")
                f.write(message + "\n")
                f.write("=" * 80 + "\n\n")
            print(f"✅ Message saved to log: {self.log_file}")
            return True
        except Exception as e:
            print(f"❌ Log save failed: {e}")
            return False


    def run(self):
        """Execute full report: fetch → build → send"""
        print("=" * 80)
        print(f"🚀 XAUUSD Unified Report — {self.timestamp.strftime('%Y-%m-%d %H:%M:%S UTC')}")
        print("=" * 80 + "\n")

        # Step 1: Fetch TradingView data
        self.fetch_tradingview_data()

        # Step 2: Fetch AI Server data
        self.fetch_ai_server_data()

        # Step 3: Build message
        print("\n💬 Building WhatsApp message...")
        message = self.build_message()

        print("\n" + "=" * 80)
        print("MESSAGE PREVIEW:")
        print("=" * 80)
        print(message)
        print("=" * 80 + "\n")

        # Step 4: Send via WhatsApp
        if self.send_whatsapp(message):
            print("✅ Report sent successfully")
        else:
            print("⚠️ WhatsApp offline, saving to log...")
            self.save_to_log(message)

        print("\n" + "=" * 80)
        print("✅ Report generation complete")
        print("=" * 80)


def main():
    reporter = XAUUSDReporter(symbol="XAUUSD")
    reporter.run()


if __name__ == "__main__":
    main()
