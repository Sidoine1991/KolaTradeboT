#!/usr/bin/env python3
"""
Complete XAUUSD 20-min WhatsApp surveillance system.
Integrates TradingView MCP data + AI server + WhatsApp delivery.

Usage:
  python3 run_xauusd_monitor.py                 # Start monitoring
  python3 run_xauusd_monitor.py --test          # Test all connections
  python3 run_xauusd_monitor.py --once          # Run once and exit
"""

import asyncio
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional
from argparse import ArgumentParser

try:
    import httpx
except ImportError:
    print("Installing httpx...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "httpx", "-q"])
    import httpx

# Configuration
AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000")
PSYCHOBOT_URL = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com/send-message")
WHATSAPP_PHONE = os.getenv("WHATSAPP_PHONE", "+2290196911346")
CHECK_INTERVAL = 20 * 60  # 20 minutes
ALERT_LOG = Path("D:/Dev/TradBOT/whatsapp_alerts.log")
ALERT_LOG.parent.mkdir(parents=True, exist_ok=True)
UTC = timezone.utc


class XAUUSDMonitor:
    """XAUUSD surveillance system."""

    def __init__(self):
        self.running = False
        self.iteration = 0

    def log(self, message: str, level: str = "INFO"):
        """Log with timestamp."""
        now = datetime.now(UTC).isoformat()
        prefix = {
            "INFO": "ℹ️ ",
            "SUCCESS": "✅",
            "ERROR": "❌",
            "WARNING": "⚠️ ",
            "ALERT": "📊",
        }.get(level, "• ")
        print(f"[{now}] {prefix} {message}")

    def log_alert(self, message: str):
        """Write alert to log file."""
        timestamp = datetime.now(UTC).isoformat()
        with open(ALERT_LOG, "a", encoding="utf-8") as f:
            f.write(f"{timestamp} | {message}\n")

    async def fetch_ai_endpoint(self, endpoint: str) -> Optional[dict]:
        """Fetch data from AI server."""
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                url = f"{AI_SERVER_URL}{endpoint}"
                response = await client.get(url)
                if response.status_code == 200:
                    return response.json()
        except Exception as e:
            self.log(f"AI Server error on {endpoint}: {e}", "WARNING")
        return None

    async def test_connections(self):
        """Test all service connections."""
        self.log("Testing connections...", "ALERT")

        # Test AI Server
        self.log("Testing AI Server...", "INFO")
        bias = await self.fetch_ai_endpoint("/session-bias?symbol=XAUUSD")
        if bias:
            self.log(f"AI Server OK: session-bias returned {bias}", "SUCCESS")
        else:
            self.log("AI Server unreachable or /session-bias failed", "ERROR")

        # Test PsychoBot
        self.log("Testing PsychoBot...", "INFO")
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                payload = {
                    "phone": WHATSAPP_PHONE,
                    "message": "🧪 Test message from XAUUSD monitor",
                }
                response = await client.post(PSYCHOBOT_URL, json=payload)
                if response.status_code == 200:
                    self.log(f"PsychoBot OK: test message sent", "SUCCESS")
                else:
                    self.log(f"PsychoBot error: {response.status_code}", "ERROR")
        except Exception as e:
            self.log(f"PsychoBot connection error: {e}", "ERROR")

        self.log("Connection tests complete", "ALERT")

    async def fetch_all_data(self) -> dict:
        """Fetch all data in parallel."""
        results = await asyncio.gather(
            self.fetch_ai_endpoint("/session-bias?symbol=XAUUSD"),
            self.fetch_ai_endpoint("/pending-order?symbol=XAUUSD"),
            self.fetch_ai_endpoint("/tradingagents/report-status?symbol=XAUUSD"),
        )

        return {
            "session_bias": results[0] or {},
            "pending_order": results[1] or {},
            "report_status": results[2] or {},
        }

    def build_message(self, data: dict) -> str:
        """Build WhatsApp message."""
        now = datetime.now(UTC)
        timestamp = now.strftime("%H:%M UTC")
        date_str = now.strftime("%d/%m %H:%M UTC")

        session = data.get("session_bias", {})
        pending = data.get("pending_order", {})
        report = data.get("report_status", {})

        bias_direction = session.get("direction", "NEUTRAL")
        bias_strength = session.get("strength", 0)
        valid_duration = session.get("valid_duration_hours", 0)

        has_pending = pending.get("active", False)
        entry_price = pending.get("entry_price", "N/A")
        stop_loss = pending.get("stop_loss", "N/A")
        take_profit = pending.get("take_profit", "N/A")

        report_direction = report.get("direction", "WAIT")
        report_strength = report.get("strength", 0)
        report_age = report.get("age_minutes", 0)
        report_expire = report.get("expires_in_minutes", 0)

        bias_emoji = "🟢" if bias_direction == "UP" else ("🔴" if bias_direction == "DOWN" else "⚪")
        report_emoji = "🟢" if report_direction == "BUY" else ("🔴" if report_direction == "SELL" else "⚪")

        message = f"""📊 TradBOT [{timestamp}]

*XAUUSD — Suivi 20min* | {date_str}
━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* [Lire TradingView MCP]
📍 VWAP : [Lire TradingView MCP]
📊 BB : [Lire TradingView MCP]
⚡ Supertrend : [Lire TradingView MCP]
━━━━━━━━━━━━━━━━━━━━
⚪ *Verdict GOM KOLA :* [Lire TradingView MCP]
━━━━━━━━━━━━━━━━━━━━
{bias_emoji} *Biais session :* {bias_direction} {bias_strength}% | ✅ valide {valid_duration}h
━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* {'✅ ACTIF' if has_pending else '📭 Aucun'}
{f'   Entry: ${entry_price} | SL: ${stop_loss} | TP: ${take_profit}' if has_pending else ''}
━━━━━━━━━━━━━━━━━━━━
{report_emoji} *Rapport TradingAgents :* {report_direction} {report_strength}% | Age: {report_age}min | Expire: {report_expire}min
━━━━━━━━━━━━━━━━━━━━
🎯 *Décision :* Confluence analysée
━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_"""

        return message

    async def send_whatsapp(self, message: str) -> bool:
        """Send message via PsychoBot."""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                payload = {
                    "phone": WHATSAPP_PHONE,
                    "message": message,
                }
                response = await client.post(PSYCHOBOT_URL, json=payload)
                if response.status_code == 200:
                    self.log("WhatsApp message sent", "SUCCESS")
                    return True
                else:
                    self.log(f"WhatsApp error {response.status_code}", "ERROR")
        except Exception as e:
            self.log(f"WhatsApp send error: {e}", "ERROR")
        return False

    async def run_once(self):
        """Run monitor once."""
        self.iteration += 1
        self.log(f"Iteration #{self.iteration} - Collecting data...", "ALERT")

        data = await self.fetch_all_data()
        message = self.build_message(data)

        self.log(f"Message preview: {message[:80]}...", "INFO")

        success = await self.send_whatsapp(message)

        if not success:
            self.log_alert(f"FALLBACK: {message[:200]}")
            self.log("Alert logged to fallback file", "WARNING")

        return success

    async def run(self):
        """Main monitor loop."""
        if self.running:
            self.log("Monitor already running", "WARNING")
            return

        self.running = True
        self.log("XAUUSD 20-min autonomous surveillance started", "ALERT")

        try:
            while self.running:
                await self.run_once()
                self.log(f"Waiting 20 minutes until next check...", "INFO")
                await asyncio.sleep(CHECK_INTERVAL)
        except KeyboardInterrupt:
            self.log("Monitor stopped by user", "WARNING")
            self.running = False
        except Exception as e:
            self.log(f"Monitor error: {e}", "ERROR")
            self.running = False

    def stop(self):
        """Stop monitoring."""
        self.running = False
        self.log("Monitor stopped", "WARNING")


async def main():
    """CLI entry point."""
    parser = ArgumentParser(description="XAUUSD 20-min WhatsApp surveillance")
    parser.add_argument("--test", action="store_true", help="Test all connections")
    parser.add_argument("--once", action="store_true", help="Run once and exit")
    args = parser.parse_args()

    monitor = XAUUSDMonitor()

    if args.test:
        await monitor.test_connections()
    elif args.once:
        monitor.log("Running once mode...", "ALERT")
        await monitor.run_once()
    else:
        monitor.log("Starting continuous monitoring...", "ALERT")
        try:
            await monitor.run()
        except KeyboardInterrupt:
            monitor.stop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\n🛑 Shutting down...")
    except Exception as e:
        print(f"❌ Fatal error: {e}", file=sys.stderr)
        sys.exit(1)
