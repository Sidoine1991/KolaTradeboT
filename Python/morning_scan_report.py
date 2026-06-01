#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Complete Morning Scan Report Generator
Analyzes markets via TradingView MCP, generates Word report, sends via WhatsApp
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

class MorningScanReportGenerator:
    def __init__(self):
        self.ai_server = "http://127.0.0.1:8000"
        self.psychobot_url = "https://psychobot-1si7.onrender.com"
        self.phone = "+2290196911346"
        self.reports_dir = Path("D:/Dev/TradBOT/reports/morning_scan")
        self.reports_dir.mkdir(parents=True, exist_ok=True)

        # Priority symbols for morning scan
        self.priority_symbols = [
            # Forex majors
            "EURUSD", "GBPUSD", "USDJPY", "USDCHF", "AUDUSD", "NZDUSD", "USDCAD",
            # Commodities
            "XAUUSD", "XAGUSD", "USOIL",
            # Indices
            "US30", "US500", "NAS100",
            # Crypto
            "BTCUSD", "ETHUSD"
        ]

    def get_open_market_symbols(self) -> List[str]:
        """Filter symbols by market hours"""
        now = datetime.utcnow()
        weekday = now.weekday()
        hour = now.hour

        open_symbols = []

        for symbol in self.priority_symbols:
            # Crypto - always open
            if any(c in symbol for c in ["BTC", "ETH"]):
                open_symbols.append(symbol)
                continue

            # Forex/Commodities - weekdays
            if weekday < 5:  # Monday to Friday
                open_symbols.append(symbol)
            elif weekday == 5 and hour < 22:  # Friday until 22:00
                open_symbols.append(symbol)
            elif weekday == 6 and hour >= 22:  # Sunday from 22:00
                open_symbols.append(symbol)

        return open_symbols

    def analyze_symbol(self, symbol: str) -> Optional[Dict]:
        """Analyze symbol via AI server"""
        try:
            # Use /ml/predict endpoint with symbol parameter
            response = requests.get(
                f"{self.ai_server}/ml/predict",
                params={"symbol": symbol},
                timeout=30
            )

            if response.status_code == 200:
                data = response.json()

                # Extract signal info from AI server response
                signal = data.get("signal", data.get("recommendation", "NEUTRAL"))
                confidence = data.get("confidence", data.get("score", 0.5))

                # Ensure confidence is 0-1
                if confidence > 1:
                    confidence = confidence / 100

                direction = "BUY" if signal == "BUY" else "SELL" if signal == "SELL" else "NEUTRAL"

                return {
                    "symbol": symbol,
                    "direction": direction,
                    "bias_score": confidence * 10,  # Scale to 0-10
                    "entry_valid": signal in ["BUY", "SELL"],
                    "entry_price": data.get("entry_price", data.get("current_price", 0)),
                    "stop_loss": data.get("stop_loss"),
                    "take_profit": data.get("take_profit"),
                    "confluence_score": confidence * 10,
                    "current_price": data.get("current_price", 0),
                    "success": True,
                    "raw": data  # Keep raw for debugging
                }
            else:
                print(f"⚠️ Analysis failed for {symbol}: HTTP {response.status_code}")
                return None

        except Exception as e:
            print(f"❌ Error analyzing {symbol}: {e}")
            return None

    def generate_text_report(self, results: List[Dict]) -> str:
        """Generate text summary for WhatsApp"""
        now = datetime.utcnow().strftime("%d/%m/%Y %H:%M UTC")

        # Filter valid entries
        valid_signals = [r for r in results if r.get("entry_valid")]

        # Sort by confluence score
        top_3 = sorted(valid_signals, key=lambda x: x.get("confluence_score", 0), reverse=True)[:3]

        message = f"📊 TradBOT Morning Scan Report\n"
        message += f"🕐 Generated: {now}\n"
        message += f"📈 Symbols analyzed: {len(results)}\n"
        message += f"✅ Valid setups: {len(valid_signals)}\n\n"

        if top_3:
            message += "🎯 TOP 3 OPPORTUNITIES:\n\n"
            for i, signal in enumerate(top_3, 1):
                message += f"{i}. {signal['symbol']} - {signal['direction']}\n"
                message += f"   💯 Score: {signal.get('confluence_score', 0):.1f}\n"
                message += f"   💰 Entry: {signal.get('entry_price', 'N/A')}\n"
                message += f"   🛑 SL: {signal.get('stop_loss', 'N/A')}\n"
                message += f"   🎯 TP: {signal.get('take_profit', 'N/A')}\n\n"
        else:
            message += "⚠️ No high-quality setups found\n"
            message += "📊 Market conditions: Low volatility or unclear trends\n\n"

        message += "📁 Full analysis attached as Word document"

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
        """Send report via PsychoBot"""
        try:
            payload = {
                "phone": self.phone,
                "message": message
            }

            # Add file if provided
            if file_path and file_path.exists():
                with open(file_path, "rb") as f:
                    file_data = f.read()

                file_base64 = base64.b64encode(file_data).decode('utf-8')
                payload["file_data"] = file_base64
                payload["file_name"] = file_path.name
                payload["file_type"] = "text/plain"  # or application/vnd... for .docx

            response = requests.post(
                f"{self.psychobot_url}/send-message",
                json=payload,
                timeout=30,
                verify=False
            )

            if response.status_code in [200, 201]:
                print(f"✅ WhatsApp sent successfully")
                return True
            else:
                print(f"❌ WhatsApp failed: HTTP {response.status_code}")
                return False

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

    def run(self, no_file: bool = False):
        """Main execution"""
        print("🚀 Starting Morning Scan Report Generation\n")

        # Get open market symbols
        symbols = self.get_open_market_symbols()
        print(f"📊 Analyzing {len(symbols)} open market symbols...\n")

        # Analyze each symbol
        results = []
        for i, symbol in enumerate(symbols, 1):
            print(f"[{i}/{len(symbols)}] Analyzing {symbol}...", end=" ")
            analysis = self.analyze_symbol(symbol)
            if analysis:
                results.append(analysis)
                print(f"✅ {analysis.get('direction', 'NEUTRAL')}")
            else:
                print("❌ Failed")

        print(f"\n✅ Analysis complete: {len(results)}/{len(symbols)} successful\n")

        # Generate reports
        text_message = self.generate_text_report(results)

        file_path = None
        if not no_file:
            file_path = self.generate_word_report(results)

        # Send via WhatsApp
        print("\n📤 Sending via WhatsApp...")
        success = self.send_via_whatsapp(text_message, file_path)

        # Fallback: log to file
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
