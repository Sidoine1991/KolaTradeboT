#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Complete Morning Scan Report Generator
Analyzes markets via TradingView MCP watchlist scan, generates Word report,
sends via WhatsApp and pushes safe signals (score >= 6) to TradeManager.
"""

import sys
import io
import os
import json
import requests
import base64
from pathlib import Path
from datetime import datetime
from typing import List, Dict, Optional

try:
    from docx import Document
    from docx.shared import Pt, RGBColor, Inches
    from docx.enum.text import WD_ALIGN_PARAGRAPH
    HAS_DOCX = True
except ImportError:
    HAS_DOCX = False

# Fix Windows encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Minimum confluence score to auto-send signal to TradeManager
SAFE_SIGNAL_MIN_SCORE = 6

class MorningScanReportGenerator:
    def __init__(self):
        self.ai_server = "http://127.0.0.1:8000"
        self.psychobot_url = "https://psychobot-1si7.onrender.com"
        self.phone = "+2290196911346"
        self.reports_dir = Path("D:/Dev/TradBOT/reports/morning_scan")
        self.reports_dir.mkdir(parents=True, exist_ok=True)

        # Default symbols for morning scan (used as fallback)
        self.priority_symbols = [
            "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "NZDUSD", "USDCAD",
            "XAUUSD", "XAGUSD",
            "US30", "US500", "NAS100",
            "BTCUSD", "ETHUSD"
        ]

    def get_open_market_symbols(self) -> List[str]:
        """Filter symbols by market hours"""
        now = datetime.utcnow()
        weekday = now.weekday()
        hour = now.hour

        open_symbols = []
        for symbol in self.priority_symbols:
            if any(c in symbol for c in ["BTC", "ETH"]):
                open_symbols.append(symbol)
                continue
            if weekday < 5:
                open_symbols.append(symbol)
            elif weekday == 5 and hour < 22:
                open_symbols.append(symbol)
            elif weekday == 6 and hour >= 22:
                open_symbols.append(symbol)

        return open_symbols

    def run_mcp_watchlist_scan(self, symbols: List[str]) -> List[Dict]:
        """
        Call the MCP tradbot_watchlist_scan tool via the ai_server bridge.
        Falls back to /ml/predict per symbol if bridge unavailable.
        """
        try:
            response = requests.post(
                f"{self.ai_server}/bridge/mcp-watchlist-scan",
                json={"symbols": symbols},
                timeout=120
            )
            if response.status_code == 200:
                data = response.json()
                return data.get("all_results", [])
        except Exception:
            pass

        # Fallback: analyze each symbol via /ml/predict
        results = []
        for symbol in symbols:
            try:
                r = requests.get(f"{self.ai_server}/ml/predict", params={"symbol": symbol}, timeout=30)
                if r.status_code == 200:
                    d = r.json()
                    signal = d.get("signal", d.get("recommendation", "NEUTRAL"))
                    confidence = d.get("confidence", d.get("score", 0.5))
                    if confidence > 1:
                        confidence /= 100
                    direction = "BUY" if signal == "BUY" else "SELL" if signal == "SELL" else "NEUTRAL"
                    results.append({
                        "symbol": symbol,
                        "success": True,
                        "current_price": d.get("current_price", 0),
                        "bias": {"direction": direction, "score": round(confidence * 10, 1), "reasons": []},
                        "entry_setup": {
                            "valid": signal in ["BUY", "SELL"],
                            "confluence_score": round(confidence * 10, 1),
                            "direction": direction,
                            "entry_price": d.get("entry_price", d.get("current_price", 0)),
                            "stop_loss": d.get("stop_loss"),
                            "take_profit": d.get("take_profit"),
                        }
                    })
            except Exception as e:
                print(f"  ⚠️ {symbol}: {e}")
        return results

    def normalize_result(self, raw: Dict) -> Dict:
        """Flatten MCP scan result into a uniform dict for report/signal use."""
        if not raw.get("success"):
            return {
                "symbol": raw.get("symbol", "?"),
                "direction": "NEUTRAL",
                "bias_score": 0,
                "entry_valid": False,
                "entry_price": None,
                "stop_loss": None,
                "take_profit": None,
                "confluence_score": 0,
                "current_price": 0,
                "reasons": [],
                "success": False,
            }
        entry = raw.get("entry_setup", {})
        bias = raw.get("bias", {})
        score = abs(entry.get("confluence_score", bias.get("score", 0)))
        direction = entry.get("direction", bias.get("direction", "NEUTRAL"))
        return {
            "symbol": raw.get("symbol", "?"),
            "direction": direction,
            "bias_score": score,
            "entry_valid": entry.get("valid", False) and direction in ["BUY", "SELL"],
            "entry_price": entry.get("entry_price"),
            "stop_loss": entry.get("stop_loss"),
            "take_profit": entry.get("take_profit"),
            "confluence_score": score,
            "current_price": raw.get("current_price", 0),
            "reasons": bias.get("reasons", []),
            "atr": entry.get("atr"),
            "structure_m15": raw.get("structure_m15", {}),
            "structure_h1": raw.get("structure_h1", {}),
            "success": True,
        }

    def send_signal_to_trade_manager(self, result: Dict) -> bool:
        """POST a safe signal to TradeManager via /pending-order."""
        score = result.get("confluence_score", 0)
        if score < SAFE_SIGNAL_MIN_SCORE or not result.get("entry_valid"):
            return False
        direction = result.get("direction")
        if direction not in ["BUY", "SELL"]:
            return False

        payload = {
            "symbol": result["symbol"],
            "action": direction,
            "recommendation": direction,
            "entry_price": result.get("entry_price"),
            "stop_loss": result.get("stop_loss"),
            "take_profit": result.get("take_profit"),
            "execution_type": "limit",
            "confidence": round(min(score / 10.0, 1.0), 2),
            "reasoning": f"Morning scan SMC — score {score}/10 — " + ", ".join(result.get("reasons", [])),
            "status": "ready",
        }

        try:
            r = requests.post(f"{self.ai_server}/pending-order", json=payload, timeout=15)
            if r.status_code == 200:
                print(f"  ✅ Signal envoyé à TradeManager: {result['symbol']} {direction} @ {result.get('entry_price')} (score {score})")
                return True
            else:
                print(f"  ⚠️ TradeManager {result['symbol']}: HTTP {r.status_code} — {r.text[:200]}")
                return False
        except Exception as e:
            print(f"  ❌ TradeManager {result['symbol']}: {e}")
            return False

    def generate_text_report(self, results: List[Dict], sent_symbols: List[str] = None) -> str:
        """Generate text summary for WhatsApp"""
        now = datetime.utcnow().strftime("%d/%m/%Y %H:%M UTC")
        sent_symbols = sent_symbols or []

        valid_signals = [r for r in results if r.get("entry_valid")]
        top_3 = sorted(valid_signals, key=lambda x: x.get("confluence_score", 0), reverse=True)[:3]

        message = f"📊 *TradBOT — Scan Matinal*\n"
        message += f"🕐 {now}\n"
        message += f"📈 Symboles analysés : {len(results)} | ✅ Setups valides : {len(valid_signals)}\n"
        if sent_symbols:
            message += f"🚀 *Signaux envoyés à TradeManager :* {', '.join(sent_symbols)}\n"
        message += f"━━━━━━━━━━━━━━━━━━━━\n\n"

        if top_3:
            message += "🎯 *TOP 3 OPPORTUNITÉS :*\n\n"
            for i, signal in enumerate(top_3, 1):
                direction_emoji = "🟢" if signal["direction"] == "BUY" else "🔴"
                sent_tag = " 🚀" if signal["symbol"] in sent_symbols else ""
                message += f"{i}. *{signal['symbol']}* {direction_emoji} {signal['direction']}{sent_tag}\n"
                message += f"   💯 Score : {signal.get('confluence_score', 0):.1f}/10\n"
                entry = signal.get('entry_price')
                message += f"   💰 Entry : {entry if entry else 'N/A'}\n"
                message += f"   🛑 SL : {signal.get('stop_loss', 'N/A')}\n"
                message += f"   🎯 TP : {signal.get('take_profit', 'N/A')}\n"
                if signal.get("reasons"):
                    message += f"   📋 {' | '.join(signal['reasons'][:2])}\n"
                message += "\n"
        else:
            message += "⚠️ Aucun setup de qualité trouvé\n"
            message += "📊 Marché : faible volatilité ou tendance incertaine\n\n"

        message += "📁 Rapport complet Word en pièce jointe"
        return message

    def generate_word_report(self, results: List[Dict]) -> Optional[Path]:
        """Generate Word document with trading analysis"""
        timestamp = datetime.now().strftime("%Y%m%d_%H%M")

        if not HAS_DOCX:
            # Fallback to text if python-docx not available
            filename = f"TradBOT_Morning_Scan_{timestamp}.txt"
            filepath = self.reports_dir / filename

            try:
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write("TradBOT Morning Scan Report\n")
                    f.write("=" * 70 + "\n\n")
                    f.write(f"Generated: {datetime.utcnow().strftime('%Y-%m-%d %H:%M:%S UTC')}\n\n")

                    for result in results:
                        f.write(f"\n{result['symbol']}\n")
                        f.write("-" * 40 + "\n")
                        f.write(f"Direction: {result.get('direction', 'N/A')}\n")
                        f.write(f"Bias Score: {result.get('bias_score', 0):.2f}\n")
                        f.write(f"Entry Valid: {result.get('entry_valid', False)}\n")
                        f.write(f"Confluence: {result.get('confluence_score', 0):.2f}\n")

                print(f"✅ Report saved (text): {filepath}")
                return filepath
            except Exception as e:
                print(f"❌ Error creating text report: {e}")
                return None

        # Create Word document
        filename = f"TradBOT_Morning_Scan_{timestamp}.docx"
        filepath = self.reports_dir / filename

        try:
            doc = Document()

            # Header
            title = doc.add_heading("TradBOT Morning Scan Report", level=1)
            title.alignment = WD_ALIGN_PARAGRAPH.CENTER

            # Metadata
            meta = doc.add_paragraph()
            meta.add_run(f"Generated: ").bold = True
            meta.add_run(datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC"))

            # Summary
            valid_signals = [r for r in results if r.get("entry_valid")]
            summary = doc.add_paragraph()
            summary.add_run(f"Symbols Analyzed: ").bold = True
            summary.add_run(f"{len(results)}\n")
            summary.add_run(f"Valid Setups: ").bold = True
            summary.add_run(f"{len(valid_signals)}")

            # Top opportunities
            if valid_signals:
                doc.add_heading("Top Opportunities", level=2)
                top_3 = sorted(valid_signals, key=lambda x: x.get("confluence_score", 0), reverse=True)[:3]

                for i, signal in enumerate(top_3, 1):
                    doc.add_heading(f"{i}. {signal['symbol']} - {signal['direction']}", level=3)

                    table = doc.add_table(rows=5, cols=2)
                    table.style = 'Light Grid Accent 1'

                    table.cell(0, 0).text = "Confluence Score"
                    table.cell(0, 1).text = f"{signal.get('confluence_score', 0):.1f}/10"

                    table.cell(1, 0).text = "Entry Price"
                    table.cell(1, 1).text = str(signal.get('entry_price', 'N/A'))

                    table.cell(2, 0).text = "Stop Loss"
                    table.cell(2, 1).text = str(signal.get('stop_loss', 'N/A'))

                    table.cell(3, 0).text = "Take Profit"
                    table.cell(3, 1).text = str(signal.get('take_profit', 'N/A'))

                    table.cell(4, 0).text = "Current Price"
                    table.cell(4, 1).text = str(signal.get('current_price', 'N/A'))

                    doc.add_paragraph()

            # All symbols analysis
            doc.add_heading("Detailed Analysis", level=2)

            table = doc.add_table(rows=1, cols=5)
            table.style = 'Light Grid Accent 1'
            hdr_cells = table.rows[0].cells
            hdr_cells[0].text = "Symbol"
            hdr_cells[1].text = "Direction"
            hdr_cells[2].text = "Score"
            hdr_cells[3].text = "Valid"
            hdr_cells[4].text = "Confluence"

            for result in results:
                row_cells = table.add_row().cells
                row_cells[0].text = result['symbol']
                row_cells[1].text = result.get('direction', 'N/A')
                row_cells[2].text = f"{result.get('bias_score', 0):.2f}"
                row_cells[3].text = "Yes" if result.get('entry_valid') else "No"
                row_cells[4].text = f"{result.get('confluence_score', 0):.2f}"

            # Footer
            footer = doc.add_paragraph()
            footer.add_run("TradBOT AI Server Analysis | ").italic = True
            footer.add_run("Powered by ML & GOM Indicators").italic = True

            doc.save(filepath)
            print(f"✅ Report saved (Word): {filepath}")
            return filepath

        except Exception as e:
            print(f"❌ Error creating Word report: {e}")
            return None

    def send_via_whatsapp(self, message: str, file_path: Optional[Path] = None) -> bool:
        """Send report via PsychoBot — message + optional Word file via tmpfiles upload"""
        import urllib3
        urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
        try:
            # 1. Send text message
            response = requests.post(
                f"{self.psychobot_url}/send-message",
                json={"phone": self.phone, "message": message},
                timeout=30,
                verify=False
            )
            if response.status_code not in [200, 201]:
                print(f"❌ WhatsApp message failed: HTTP {response.status_code}")
                return False
            print(f"✅ WhatsApp message sent")

            # 2. Send Word file — base64 direct vers PsychoBot (pas de service tiers)
            if file_path and file_path.exists():
                try:
                    import base64
                    print(f"📤 Envoi {file_path.name} via base64 → PsychoBot...")
                    file_b64 = base64.b64encode(file_path.read_bytes()).decode("utf-8")
                    file_resp = requests.post(
                        f"{self.psychobot_url}/send-file",
                        json={
                            "phone": self.phone,
                            "message": f"📎 {file_path.name}",
                            "file_base64": file_b64,
                            "file_name": file_path.name,
                            "mime_type": "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
                        },
                        timeout=60,
                        verify=False
                    )
                    if file_resp.status_code == 200 and file_resp.json().get("success"):
                        print(f"✅ Word file sent via WhatsApp")
                    else:
                        print(f"⚠️ File send: {file_resp.status_code} — {file_resp.text[:200]}")
                except Exception as file_err:
                    print(f"⚠️ File upload/send skipped: {file_err}")

            return True

        except Exception as e:
            print(f"❌ WhatsApp error: {e}")
            return False

    def log_to_file(self, message: str, file_path: Optional[Path] = None):
        """Log to whatsapp_alerts.log"""
        log_file = Path("D:/Dev/TradBOT/whatsapp_alerts.log")
        try:
            with open(log_file, "a", encoding="utf-8") as f:
                now = datetime.now().isoformat()
                f.write(f"\n{'='*70}\n")
                f.write(f"[{now}] Morning Scan Report\n")
                f.write(f"{'='*70}\n")
                f.write(message + "\n")
                if file_path:
                    f.write(f"File: {file_path}\n")
                f.write("\n")
            print(f"✅ Logged to {log_file}")
        except Exception as e:
            print(f"❌ Logging failed: {e}")

    def run(self, no_file: bool = False, scan_results: List[Dict] = None):
        """Main execution.

        Args:
            no_file: Skip Word document generation.
            scan_results: Pre-fetched MCP scan results (list of raw dicts from
                          tradbot_watchlist_scan). If provided, skips the API scan.
        """
        print("🚀 Starting Morning Scan Report Generation\n")

        # Step 1: Get scan data
        if scan_results is not None:
            print(f"📊 Using {len(scan_results)} pre-fetched MCP results\n")
            raw_results = scan_results
        else:
            symbols = self.get_open_market_symbols()
            print(f"📊 Scanning {len(symbols)} open market symbols via MCP...\n")
            raw_results = self.run_mcp_watchlist_scan(symbols)

        # Step 2: Normalize results
        results = [self.normalize_result(r) for r in raw_results]
        successful = [r for r in results if r.get("success")]
        print(f"✅ Analysis complete: {len(successful)}/{len(results)} successful\n")

        # Step 3: Send safe signals to TradeManager
        print("🚀 Envoi des signaux sûrs à TradeManager (score >= {})...\n".format(SAFE_SIGNAL_MIN_SCORE))
        sent_symbols = []
        for result in sorted(successful, key=lambda x: x.get("confluence_score", 0), reverse=True):
            if self.send_signal_to_trade_manager(result):
                sent_symbols.append(result["symbol"])

        if not sent_symbols:
            print("  ℹ️ Aucun signal avec score suffisant — aucun envoi à TradeManager\n")

        # Step 4: Generate Word report
        file_path = None
        if not no_file:
            file_path = self.generate_word_report(results)

        # Step 5: Build and send WhatsApp message
        text_message = self.generate_text_report(results, sent_symbols)

        print("\n📤 Sending via WhatsApp...")
        success = self.send_via_whatsapp(text_message, file_path)

        if not success:
            print("⚠️ WhatsApp failed, logging to file...")
            self.log_to_file(text_message, file_path)

        print("\n✅ Morning scan report complete!")

def main():
    import argparse
    parser = argparse.ArgumentParser(description="Generate morning scan report")
    parser.add_argument("--no-file", action="store_true", help="Skip file generation")
    args = parser.parse_args()

    generator = MorningScanReportGenerator()
    generator.run(no_file=args.no_file)

if __name__ == "__main__":
    main()
