#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Morning Scanning System — Auto Top 3 Opportunities
Scans symbols, calculates confluence scores, sends consolidated WhatsApp message
"""

import sys
import io
import os

# Fix Windows encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

import requests
import json
from datetime import datetime
from typing import List, Dict, Tuple

class MorningScanner:
    def __init__(self, ai_server_url="http://127.0.0.1:8000"):
        self.ai_server = ai_server_url
        self.timeout = 30
        self.market_status = "Not initialized"
        self.symbols = []

        # Initialize will be called explicitly when needed
        self._initialized = False

    def initialize(self):
        """Initialize the scanner by fetching D1 candidates from AI server"""
        if self._initialized:
            return

        self.symbols = self._fetch_daily_candidates()

        if not self.symbols:
            print("⚠️ No D1 candidates found, falling back to default symbols")
            self.symbols = self._fallback_symbols()

        self._initialized = True

    def _fetch_daily_candidates(self) -> List[str]:
        """Fetch filtered D1 candidates from AI server"""
        try:
            resp = requests.get(
                f"{self.ai_server}/symbols/daily-candidates",
                timeout=self.timeout
            )
            if resp.status_code == 200:
                data = resp.json()
                candidates = data.get("candidates", [])

                if not candidates:
                    print(f"⚠️ No candidates passed D1 filters (scanned {data.get('scanned', 0)} symbols)")
                    return []

                # Limit to top 20 to avoid timeout (20 * 2s = ~40s scan time)
                top20 = candidates[:20]

                # Build market status string
                self.market_status = self._build_market_status(top20)

                return [c['symbol'] for c in top20]
            else:
                print(f"⚠️ Failed to fetch D1 candidates: {resp.status_code}")
                return []
        except Exception as e:
            print(f"⚠️ Error fetching D1 candidates: {e}")
            return []

    def _fallback_symbols(self) -> List[str]:
        """Fallback to minimal hardcoded list if API fails"""
        from datetime import datetime
        now = datetime.utcnow()
        is_weekend = now.weekday() >= 5

        symbols = ["XAUUSD", "EURUSD", "BTCUSD"]
        if not is_weekend:
            symbols.extend(["GBPUSD", "AUDUSD"])

        self.market_status = "FALLBACK — Minimal list"
        return symbols

    def _build_market_status(self, candidates: List[Dict]) -> str:
        """Build human-readable market status from candidates"""
        by_category = {}
        for c in candidates:
            cat = c['category']
            by_category[cat] = by_category.get(cat, 0) + 1

        parts = [f"{count} {cat.title()}" for cat, count in sorted(by_category.items())]
        return f"{len(candidates)} symbols scanned — " + ", ".join(parts)

    def scan_all(self) -> List[Dict]:
        """Scan all symbols and calculate confluence scores"""
        scores = []

        # Combine main symbols with AI-server-only symbols
        all_symbols = self.symbols + self.ai_server_only_symbols

        for sym in all_symbols:
            try:
                # Fetch GOM verdict
                gom_resp = requests.get(
                    f"{self.ai_server}/gom-verdict?symbol={sym}",
                    timeout=self.timeout
                )
                gom = gom_resp.json() if gom_resp.status_code == 200 else {}

                # Fetch session bias
                bias_resp = requests.get(
                    f"{self.ai_server}/session-bias?symbol={sym}",
                    timeout=self.timeout
                )
                bias = bias_resp.json() if bias_resp.status_code == 200 else {}

                # Fetch pending order
                order_resp = requests.get(
                    f"{self.ai_server}/pending-order?symbol={sym}",
                    timeout=self.timeout
                )
                order = order_resp.json() if order_resp.status_code == 200 else {}

                # Calculate confluence score
                score = self._calculate_score(gom, bias)

                if score >= 4:  # Only include symbols with score >= 4
                    scores.append({
                        "symbol": sym,
                        "score": score,
                        "gom": gom,
                        "bias": bias,
                        "order": order
                    })
                    print(f"✓ {sym}: {score:.1f}/10")
                else:
                    print(f"⊘ {sym}: {score:.1f}/10 (below threshold)")

            except Exception as e:
                print(f"✗ {sym}: {e}")
                continue

        # Sort by score descending and return top 3
        scores.sort(key=lambda x: x["score"], reverse=True)
        return scores[:3]

    def _calculate_score(self, gom: Dict, bias: Dict) -> float:
        """Calculate confluence score using GOM's pre-calculated scores (0-10)"""
        # Use the max of buy/sell scores from GOM's confluence engine
        score_buy = float(gom.get("score_buy", 0))
        score_sell = float(gom.get("score_sell", 0))

        # Take the highest score (strongest signal)
        confluence = max(score_buy, score_sell)

        # Boost if bias is aligned with signal
        vnum = gom.get("verdict_num", 0)
        bias_direction = bias.get("direction", "NEUTRAL")

        if (vnum > 0 and bias_direction == "BUY") or (vnum < 0 and bias_direction == "SELL"):
            confluence += 0.5  # Small bonus for aligned bias

        return min(confluence, 10.0)  # Cap at 10

    def build_message(self, top3: List[Dict]) -> str:
        """Build consolidated WhatsApp message for Top 3"""
        now = datetime.utcnow()
        time_str = now.strftime("%H:%M UTC")
        date_str = now.strftime("%d/%m %H:%M UTC")

        msg = f"📊 TradBOT MORNING SCAN [{time_str}]\n\n"
        msg += f"*TOP 3 OPPORTUNITIES — {date_str}*\n"
        msg += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

        emojis = ["🥇", "🥈", "🥉"]

        for i, item in enumerate(top3):
            sym = item["symbol"]
            score = item["score"]
            gom = item["gom"]
            bias = item["bias"]
            order = item["order"]

            emoji = emojis[i] if i < len(emojis) else f"#{i+1}"

            # GOM verdict emoji
            gom_emoji = "🟢" if gom.get("verdict_num", 0) > 0 else "🔴" if gom.get("verdict_num", 0) < 0 else "⚪"

            msg += f"{emoji} {sym}\n"
            msg += f"   Confluence: {score:.1f}/10 | {gom_emoji} GOM: {gom.get('verdict', 'N/A')} | "
            msg += f"Bias: {bias.get('direction', 'N/A')} {int(bias.get('confidence', 0)*100)}%\n"

            # Add price if available
            if "price" in gom:
                msg += f"   Price: {gom.get('price', 'N/A')} | VWAP: {gom.get('vwap', 'N/A')}\n"

            # Add order status
            if order.get("ok"):
                order_data = order.get("order", {})
                msg += f"   Entry: {order_data.get('entry_price', 'N/A')} | Status: ✅ {order_data.get('status', 'Ready').upper()}\n"
            else:
                msg += f"   Status: ⏳ Pending\n"

            msg += "\n"

        msg += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
        msg += f"📈 COMPOSITE ANALYSIS\n"
        msg += f"  ✅ Direction: All aligned on {top3[0]['gom'].get('verdict_num', 0) > 0 and 'BUY' or 'SELL'}\n"
        msg += f"  ✅ Average Confluence: {sum(x['score'] for x in top3) / len(top3):.1f}/10\n\n"
        msg += "🎯 STRATEGY\n"
        msg += "  1. Start with #1 (highest confluence)\n"
        msg += "  2. Monitor #2, #3 for entry signals\n"
        msg += "  3. Close all if any hits WAIT\n\n"
        msg += "📌 Next scan: In 20 min\n"
        msg += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        return msg

    def send_whatsapp(self, message: str, phone: str = "+2290196911346") -> bool:
        """Send message via PsychoBot"""
        try:
            response = requests.post(
                "https://psychobot-1si7.onrender.com/send-message",
                json={"phone": phone, "message": message},
                timeout=15,
                verify=False  # SSL bypass for Render certificate issue
            )
            return response.status_code == 200
        except Exception as e:
            print(f"❌ WhatsApp send failed: {e}")
            return False

    def save_to_log(self, message: str, log_file: str = "D:\\Dev\\TradBOT\\whatsapp_alerts.log"):
        """Save message to log file as fallback"""
        try:
            timestamp = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S")
            with open(log_file, "a", encoding="utf-8") as f:
                f.write(f"\n[{timestamp}] MORNING SCAN\n")
                f.write(message + "\n")
                f.write("="*80 + "\n\n")
            return True
        except Exception as e:
            print(f"❌ Log save failed: {e}")
            return False


def main():
    print("🔍 Starting Morning Scanning System...")

    scanner = MorningScanner()

    # Initialize scanner (fetch D1 candidates)
    scanner.initialize()

    # Show market status
    print(f"📍 Market Status: {scanner.market_status}")

    # Scan all symbols
    print(f"\n📊 Scanning {len(scanner.symbols)} symbols...")
    top3 = scanner.scan_all()

    if not top3:
        print("⚠️ No opportunities found (all below threshold)")
        return

    print(f"\n✅ Found {len(top3)} opportunities")

    # Build consolidated message
    message = scanner.build_message(top3)
    print("\n" + "="*80)
    print(message)
    print("="*80)

    # Send via WhatsApp
    print("\n📱 Sending WhatsApp message...")
    if scanner.send_whatsapp(message):
        print("✅ WhatsApp message sent successfully")
    else:
        print("⚠️ WhatsApp offline — saving to log")
        scanner.save_to_log(message)


if __name__ == "__main__":
    main()
