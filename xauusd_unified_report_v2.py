#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XAUUSD Unified Report v2 — TradingView MCP + AI Server curl
Collecte données XAUUSD et envoie UN message WhatsApp unifié

ÉTAPE 1: TradingView MCP (parallèle) — quote, indicateurs, GOM KOLA
ÉTAPE 2: AI Server curl (parallèle) — session-bias, pending-order, tradingagents
ÉTAPE 3: Construire message avec format exact
ÉTAPE 4: Envoyer via PsychoBot (ou log si down)
"""

import sys
import io
import json
import subprocess
from datetime import datetime
from typing import Dict, Any, Optional
import concurrent.futures

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')


class XAUUSDUnifiedReport:
    def __init__(self):
        self.symbol = "XAUUSD"
        self.tv_symbol = "OANDA:XAUUSD"
        self.ai_server = "http://127.0.0.1:8000"
        self.psychobot_url = "https://psychobot-1si7.onrender.com/send-message"
        self.phone = "+2290196911346"
        self.log_file = r"D:\Dev\TradBOT\whatsapp_alerts.log"
        self.timestamp = datetime.utcnow()

        self.tv_quote = {}
        self.tv_indicators = {}
        self.tv_gom = {}
        self.ai_bias = {}
        self.ai_order = {}
        self.ai_ta = {}
        self.ai_server_available = True


    def fetch_tv_quote(self):
        """Fetch live XAUUSD quote from TradingView MCP"""
        try:
            from mcp__tradingview_kola import quote_get
            result = quote_get(symbol=self.tv_symbol)
            if result and result.get('ok'):
                self.tv_quote = result.get('quote', {})
                print("  ✓ TradingView quote fetched")
        except Exception as e:
            print(f"  ⚠️ TradingView quote failed: {e}")


    def fetch_tv_indicators(self):
        """Fetch indicator values (RSI, Supertrend, BB, VWAP, etc.)"""
        try:
            from mcp__tradingview_kola import data_get_study_values
            result = data_get_study_values()
            if result:
                self.tv_indicators = result
                print("  ✓ TradingView indicators fetched")
        except Exception as e:
            print(f"  ⚠️ TradingView indicators failed: {e}")


    def fetch_tv_gom(self):
        """Fetch GOM KOLA tables from TradingView"""
        try:
            from mcp__tradingview_kola import data_get_pine_tables
            result = data_get_pine_tables(study_filter="GOM KOLA")
            if result:
                self.tv_gom = result
                print("  ✓ GOM KOLA tables fetched")
        except Exception as e:
            print(f"  ⚠️ GOM KOLA tables failed: {e}")


    def fetch_ai_bias(self):
        """Fetch session bias from AI server via curl"""
        try:
            cmd = [
                "curl", "-s",
                f"{self.ai_server}/session-bias?symbol={self.symbol}"
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if result.returncode == 0 and result.stdout:
                self.ai_bias = json.loads(result.stdout)
                print("  ✓ AI Server session-bias fetched")
            else:
                print(f"  ⚠️ AI Server session-bias failed: {result.returncode}")
                self.ai_server_available = False
        except Exception as e:
            print(f"  ⚠️ AI Server session-bias error: {e}")
            self.ai_server_available = False


    def fetch_ai_order(self):
        """Fetch pending EA order from AI server"""
        try:
            cmd = [
                "curl", "-s",
                f"{self.ai_server}/pending-order?symbol={self.symbol}"
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if result.returncode == 0 and result.stdout:
                self.ai_order = json.loads(result.stdout)
                print("  ✓ AI Server pending-order fetched")
            else:
                self.ai_server_available = False
        except Exception as e:
            print(f"  ⚠️ AI Server pending-order error: {e}")
            self.ai_server_available = False


    def fetch_ai_tradingagents(self):
        """Fetch TradingAgents report from AI server"""
        try:
            cmd = [
                "curl", "-s",
                f"{self.ai_server}/tradingagents/report-status?symbol={self.symbol}"
            ]
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if result.returncode == 0 and result.stdout:
                self.ai_ta = json.loads(result.stdout)
                print("  ✓ AI Server tradingagents fetched")
            else:
                self.ai_server_available = False
        except Exception as e:
            print(f"  ⚠️ AI Server tradingagents error: {e}")
            self.ai_server_available = False


    def fetch_all_data(self):
        """Fetch all data in parallel"""
        print("\n📺 Fetching TradingView data (MCP)...")
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
            futures = [
                executor.submit(self.fetch_tv_quote),
                executor.submit(self.fetch_tv_indicators),
                executor.submit(self.fetch_tv_gom),
            ]
            concurrent.futures.wait(futures)

        print("\n🤖 Fetching AI Server data (curl)...")
        with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
            futures = [
                executor.submit(self.fetch_ai_bias),
                executor.submit(self.fetch_ai_order),
                executor.submit(self.fetch_ai_tradingagents),
            ]
            concurrent.futures.wait(futures)


    def build_message(self) -> str:
        """Build unified WhatsApp message with exact format"""
        time_str = self.timestamp.strftime("%H:%M")
        date_str = self.timestamp.strftime("%d/%m %H:%M UTC")

        msg = f"📊 TradBOT [{time_str} UTC]\n\n"
        msg += f"*{self.symbol} — Suivi 20min* | {date_str}\n"
        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 1: Live price & TradingView indicators
        price = self.tv_quote.get('last', 'N/A')
        msg += f"💰 *Prix live :* ${price}\n"

        # VWAP
        vwap = self.tv_indicators.get('VWAP', 'N/A')
        if vwap != 'N/A':
            try:
                vwap_val = float(vwap)
                price_val = float(price)
                position = "AU-DESSUS" if price_val > vwap_val else "EN-DESSOUS"
                msg += f"📍 VWAP : ${vwap_val:.2f} → prix {position}\n"
            except:
                msg += f"📍 VWAP : {vwap}\n"

        # Bollinger Bands
        bb_high = self.tv_indicators.get('BB_Upper', self.tv_indicators.get('BBands_Upper', 'N/A'))
        bb_mid = self.tv_indicators.get('BB_Middle', self.tv_indicators.get('BBands_Middle', 'N/A'))
        bb_low = self.tv_indicators.get('BB_Lower', self.tv_indicators.get('BBands_Lower', 'N/A'))
        msg += f"📊 BB : [{bb_low} / {bb_mid} / {bb_high}]\n"

        # Supertrend
        st = self.tv_indicators.get('Supertrend', self.tv_indicators.get('ST', 'N/A'))
        st_dir = "↑" if isinstance(self.tv_indicators.get('Supertrend_Direction', 0), (int, float)) and self.tv_indicators.get('Supertrend_Direction', 0) > 0 else "↓"
        msg += f"⚡ Supertrend : ${st} ({st_dir})\n"

        # Fibo (if available)
        msg += f"📐 Fibo : (zones from chart)\n"
        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 2: GOM KOLA Verdict
        if self.tv_gom:
            try:
                gom_list = self.tv_gom if isinstance(self.tv_gom, list) else [self.tv_gom]
                gom_row = gom_list[0] if gom_list else {}

                verdict = gom_row.get('verdict', 'WAIT')
                verdict_emoji = "🟢" if verdict == "BUY" else "🔴" if verdict == "SELL" else "⚪"

                score_buy = gom_row.get('score_buy', 0)
                score_sell = gom_row.get('score_sell', 0)
                spike_z = gom_row.get('spike_z', 0)
                rsi = self.tv_indicators.get('RSI', 'N/A')

                msg += f"{verdict_emoji} *Verdict GOM KOLA : {verdict}*\n"
                msg += f"   Score BUY={score_buy:.0f}  SELL={score_sell:.0f}  Spike={spike_z:.1f}%\n"
                msg += f"   RSI={rsi} | ST={st_dir}\n"
            except Exception as e:
                msg += f"⚪ *Verdict GOM KOLA : WAIT* (erreur: {e})\n"
        else:
            msg += f"⚪ *Verdict GOM KOLA : WAIT* (données indisponibles)\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 3: Session Bias
        if self.ai_bias and self.ai_bias.get('direction'):
            bias_emoji = "🟢" if self.ai_bias['direction'] == "BUY" else "🔴" if self.ai_bias['direction'] == "SELL" else "⚪"
            confidence = int(self.ai_bias.get('confidence', 0) * 100)
            age = self.ai_bias.get('age_minutes', 'N/A')
            msg += f"{bias_emoji} *Biais session :* {self.ai_bias['direction']} {confidence}% | ✅ valide depuis {age}min\n"
        elif not self.ai_server_available:
            msg += f"⚪ *Biais session :* ⚠️ AI server hors ligne\n"
        else:
            msg += f"⚪ *Biais session :* N/A\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 4: EA Pending Order
        if self.ai_order and self.ai_order.get('ok'):
            order_data = self.ai_order.get('order', {})
            action = order_data.get('action', 'N/A')
            entry = order_data.get('entry_price', 'N/A')
            sl = order_data.get('sl', 'N/A')
            tp = order_data.get('tp', 'N/A')
            msg += f"📦 *Ordre EA :* {action} @ {entry} | SL: {sl} | TP: {tp}\n"
        else:
            msg += f"📭 *Ordre EA :* Aucun ordre EA actif\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 5: TradingAgents Report
        if self.ai_ta and self.ai_ta.get('direction'):
            ta_emoji = "🟢" if self.ai_ta['direction'] == "BUY" else "🔴" if self.ai_ta['direction'] == "SELL" else "⚪"
            confidence = int(self.ai_ta.get('confidence', 0) * 100)
            age = self.ai_ta.get('age_minutes', 'N/A')
            entry = self.ai_ta.get('entry_price', 'N/A')
            sl = self.ai_ta.get('sl', 'N/A')
            tp = self.ai_ta.get('tp', 'N/A')
            msg += f"{ta_emoji} *Rapport TradingAgents :* {self.ai_ta['direction']} {confidence}% | Age: {age}min\n"
            msg += f"   Entrée: {entry} | SL: {sl} | TP: {tp}\n"
        elif not self.ai_server_available:
            msg += f"⚪ *Rapport TradingAgents :* ⚠️ AI server hors ligne\n"
        else:
            msg += f"⚪ *Rapport TradingAgents :* N/A\n"

        msg += "━━━━━━━━━━━━━━━━━━━━\n"

        # Section 6: Cross-analysis
        msg += "🔬 *Analyse croisée*\n"

        signals = []
        if self.ai_bias and self.ai_bias.get('direction'):
            signals.append(self.ai_bias['direction'])
        if self.ai_ta and self.ai_ta.get('direction'):
            signals.append(self.ai_ta['direction'])
        if self.tv_gom:
            try:
                gom_list = self.tv_gom if isinstance(self.tv_gom, list) else [self.tv_gom]
                gom_verdict = gom_list[0].get('verdict', '') if gom_list else ''
                if gom_verdict in ['BUY', 'SELL']:
                    signals.append(gom_verdict)
            except:
                pass

        if signals:
            unique_signals = set(signals)
            if len(unique_signals) == 1:
                direction = unique_signals.pop()
                msg += f"  ✅ CONFLUENCE: Tous les signaux en {direction}\n"
            else:
                msg += f"  ⚠️ CONFLITS: Signaux mixtes ({signals})\n"

        if not self.ai_server_available:
            msg += f"  ⚠️ AI server hors ligne — données partielles\n"

        msg += "🎯 *Décision scalping*\n"
        msg += "  (Voir ci-dessus pour BUY/SELL/WAIT)\n"
        msg += "━━━━━━━━━━━━━━━━━━━━\n"
        msg += "_Prochain check dans 20 min_"

        return msg


    def send_whatsapp(self, message: str) -> bool:
        """Send message via PsychoBot using curl"""
        print("\n📱 Sending WhatsApp via PsychoBot...")
        try:
            # Escape message for JSON
            escaped_msg = json.dumps(message)

            cmd = [
                "curl", "-s", "-X", "POST",
                self.psychobot_url,
                "-H", "Content-Type: application/json",
                "-d", f'{{"phone": "{self.phone}", "message": {escaped_msg}}}'
            ]

            result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)

            if result.returncode == 0:
                print("✅ WhatsApp message sent successfully")
                return True
            else:
                print(f"❌ WhatsApp send failed: HTTP error ({result.returncode})")
                print(f"   Response: {result.stdout[:200]}")
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
                f.write("=" * 80 + "\n")
            print(f"✅ Message saved to log: {self.log_file}")
            return True
        except Exception as e:
            print(f"❌ Log save failed: {e}")
            return False


    def run(self):
        """Execute full report pipeline"""
        print("=" * 80)
        print(f"🚀 XAUUSD Unified Report — {self.timestamp.strftime('%Y-%m-%d %H:%M:%S UTC')}")
        print("=" * 80)

        # Fetch all data
        self.fetch_all_data()

        # Build message
        print("\n💬 Building WhatsApp message...")
        message = self.build_message()

        # Print preview
        print("\n" + "=" * 80)
        print("MESSAGE PREVIEW:")
        print("=" * 80)
        print(message)
        print("=" * 80)

        # Send WhatsApp
        if not self.send_whatsapp(message):
            print("\n⚠️ PsychoBot unavailable, saving to log...")
            self.save_to_log(message)

        print("\n✅ Report complete")


def main():
    reporter = XAUUSDUnifiedReport()
    reporter.run()


if __name__ == "__main__":
    main()
