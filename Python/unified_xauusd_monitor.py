#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Unified XAUUSD Monitor v2
=========================
Collecte toutes les données XAUUSD (TradingView + AI server) et envoie
UN message WhatsApp unifié via PsychoBot toutes les 20 minutes.

Usage:
    python unified_xauusd_monitor.py --interval 1200 --phone "+2290196911346"

Requirements:
    - aiohttp (async HTTP)
    - Requests library
    - TradingView Desktop with MCP server
    - AI server running on http://127.0.0.1:8000
    - PsychoBot endpoint: https://psychobot-1si7.onrender.com/send-message
"""

import sys
import io
import json
import subprocess
import asyncio
import aiohttp
import requests
import argparse
import logging
from datetime import datetime
from typing import Dict, Optional, Any

# Fix console encoding for Windows
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("D:\\Dev\\TradBOT\\whatsapp_alerts.log", encoding="utf-8"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Configuration
AI_SERVER_URL = "http://127.0.0.1:8000"
PSYCHOBOT_URL = "https://psychobot-1si7.onrender.com/send-message"
DEFAULT_PHONE = "+2290196911346"
MCP_CLI_PATH = "D:/Dev/Depot Github/tradingview-mcp_kola/src/cli.mjs"


class XAUUSDMonitor:
    """Unified monitor for XAUUSD with TradingView + AI server data collection."""

    def __init__(self, phone: str = DEFAULT_PHONE, interval: int = 1200):
        self.phone = phone
        self.interval = interval
        self.symbol = "OR"  # AI server uses "OR" for XAUUSD/Gold
        self.tv_symbol = "OANDA:XAUUSD"  # TradingView symbol
        self.session = None

    async def __aenter__(self):
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        if self.session:
            await self.session.close()

    # =========================================================================
    # ÉTAPE 1: Collecte TradingView (MCP tools)
    # =========================================================================

    def _run_mcp(self, *args: str) -> Optional[dict]:
        """Execute MCP CLI tool and return JSON result."""
        try:
            # Try alternative MCP paths with fallback
            mcp_paths = [
                MCP_CLI_PATH,
                "tradingview-mcp_kola/src/cli.mjs",
                "node_modules/.bin/tv-mcp"
            ]

            result = None
            for mcp_path in mcp_paths:
                cmd = f"node {mcp_path} " + " ".join(args)
                try:
                    result = subprocess.run(
                        cmd,
                        shell=True,
                        capture_output=True,
                        text=True,
                        timeout=10,
                    )
                    if result.returncode == 0:
                        break
                except subprocess.TimeoutExpired:
                    logger.warning(f"[MCP] Timeout with {mcp_path}")
                    continue
                except Exception as e:
                    logger.warning(f"[MCP] Failed with {mcp_path}: {e}")
                    continue

            if not result or result.returncode != 0:
                logger.warning(f"[MCP] All paths failed. Last error: {result.stderr[:200] if result else 'No result'}")
                return None

            try:
                return json.loads(result.stdout)
            except json.JSONDecodeError:
                logger.warning(f"[MCP] Invalid JSON: {result.stdout[:200]}")
                return None
        except Exception as e:
            logger.error(f"[MCP] Exception: {e}")
            return None

    def get_quote(self) -> Optional[Dict[str, Any]]:
        """Get live price quote for XAUUSD."""
        try:
            result = self._run_mcp("quote_get", "--symbol", self.tv_symbol)
            if result:
                return {
                    "price": result.get("last", 0),
                    "bid": result.get("bid", 0),
                    "ask": result.get("ask", 0),
                    "volume": result.get("volume", 0),
                }
            return None
        except Exception as e:
            logger.error(f"[TV] quote_get failed: {e}")
            return None

    def get_indicators(self) -> Optional[Dict[str, Any]]:
        """Get all visible indicator values (VWAP, BB, SuperTrend, RSI, etc.)."""
        try:
            result = self._run_mcp("data_get_study_values")
            if result and isinstance(result, dict):
                return result
            return None
        except Exception as e:
            logger.error(f"[TV] data_get_study_values failed: {e}")
            return None

    def get_gom_data(self) -> Optional[Dict[str, Any]]:
        """Get GOM KOLA table data (verdict, scores, RSI, ST)."""
        try:
            result = self._run_mcp("data_get_pine_tables", "--study_filter", "GOM KOLA")
            if result and isinstance(result, dict):
                # Parse table rows into structured data
                return result
            return None
        except Exception as e:
            logger.error(f"[TV] data_get_pine_tables GOM failed: {e}")
            return None

    async def collect_tradingview_data(self) -> Dict[str, Any]:
        """Collect all TradingView data in parallel. Note: MCP may fail gracefully."""
        logger.info("[TV] Attempting TradingView data collection (MCP may not be available)...")

        # Run all MCP calls in parallel with fallback
        loop = asyncio.get_event_loop()
        quote_task = loop.run_in_executor(None, self.get_quote)
        indicators_task = loop.run_in_executor(None, self.get_indicators)
        gom_task = loop.run_in_executor(None, self.get_gom_data)

        quote = await quote_task
        indicators = await indicators_task
        gom = await gom_task

        # Log if any collection failed
        if not quote:
            logger.warning("[TV] Quote collection failed, will use AI server data only")
        if not indicators:
            logger.warning("[TV] Indicators collection failed")

        return {
            "quote": quote or {},
            "indicators": indicators or {},
            "gom": gom or {},
            "timestamp": datetime.utcnow().isoformat(),
        }

    # =========================================================================
    # ÉTAPE 2: Collecte AI Server
    # =========================================================================

    async def _get_ai_data(self, endpoint: str) -> Optional[Dict[str, Any]]:
        """Fetch data from AI server endpoint."""
        try:
            if not self.session:
                async with aiohttp.ClientSession() as session:
                    async with session.get(
                        f"{AI_SERVER_URL}{endpoint}",
                        timeout=aiohttp.ClientTimeout(total=10)
                    ) as resp:
                        if resp.status == 200:
                            return await resp.json()
            else:
                async with self.session.get(
                    f"{AI_SERVER_URL}{endpoint}",
                    timeout=aiohttp.ClientTimeout(total=10)
                ) as resp:
                    if resp.status == 200:
                        return await resp.json()
            return None
        except Exception as e:
            logger.warning(f"[AI] {endpoint} failed: {e}")
            return None

    async def get_gom_from_server(self) -> Optional[Dict[str, Any]]:
        """Get GOM KOLA data from AI server (/gom-verdict cache)."""
        try:
            return await self._get_ai_data(f"/gom-verdict?symbol={self.symbol}")
        except Exception as e:
            logger.warning(f"[AI] GOM fetch failed: {e}")
            return None

    async def collect_ai_server_data(self) -> Dict[str, Any]:
        """Collect all AI server data in parallel."""
        logger.info("[AI] Collecting AI server data...")

        # Fetch in parallel
        bias_task = self._get_ai_data(f"/session-bias?symbol={self.symbol}")
        order_task = self._get_ai_data(f"/pending-order?symbol={self.symbol}")
        report_task = self._get_ai_data(f"/tradingagents/report-status?symbol={self.symbol}")
        gom_task = self.get_gom_from_server()

        bias = await bias_task
        order = await order_task
        report = await report_task
        gom = await gom_task

        return {
            "bias": bias or {},
            "pending_order": order or {},
            "tradingagents_report": report or {},
            "gom": gom or {},
            "timestamp": datetime.utcnow().isoformat(),
        }

    # =========================================================================
    # ÉTAPE 3: Construire le message WhatsApp
    # =========================================================================

    def build_whatsapp_message(self, tv_data: Dict, ai_data: Dict) -> str:
        """Build unified WhatsApp message from collected data."""
        now = datetime.utcnow()
        timestamp = now.strftime("%H:%M UTC")
        date_str = now.strftime("%d/%m %H:%M UTC")

        quote = tv_data.get("quote", {})
        indicators = tv_data.get("indicators", {})
        gom_tv = tv_data.get("gom", {})

        bias = ai_data.get("bias", {})
        order = ai_data.get("pending_order", {})
        report = ai_data.get("tradingagents_report", {})
        gom_server = ai_data.get("gom", {})

        # Prefer server GOM if available (more reliable)
        gom = gom_server if gom_server else gom_tv

        # Extract values with fallbacks
        price = quote.get("price", "?")
        vwap = indicators.get("VWAP", "?")
        bb_upper = indicators.get("BB_Upper", "?")
        bb_mid = indicators.get("BB_Mid", "?")
        bb_lower = indicators.get("BB_Lower", "?")
        st_line = indicators.get("SuperTrend", "?")
        st_dir = indicators.get("ST_Direction", "?")

        gom_verdict = gom.get("verdict", "WAIT")
        gom_buy_score = gom.get("score_buy", "?")
        gom_sell_score = gom.get("score_sell", "?")
        gom_spike = gom.get("spike_pct", "?")
        gom_rsi = gom.get("rsi", "?")

        # Handle nested structure from /session-bias
        bias_data = bias.get("data", {})
        bias_dir = bias_data.get("direction", "NEUTRAL")
        bias_conf = int(bias_data.get("confidence", 0) * 100)
        bias_age_sec = bias_data.get("age_hours", "?")

        order_obj = order.get("order", {})
        order_active = order_obj and order_obj.get("status") != "closed"
        order_entry = order_obj.get("entry_price", "?")
        order_sl = order_obj.get("stop_loss", "?")
        order_tp = order_obj.get("take_profit", "?")

        report_dir = report.get("direction", "NEUTRAL") or "NEUTRAL"
        report_conf = int(report.get("confidence", 0) * 100)
        report_age_sec = report.get("age_minutes", "?")

        # Build message
        msg = f"""📊 TradBOT [{timestamp}]

*XAUUSD — Suivi 20min* | {date_str}
━━━━━━━━━━━━━━━━━━━━━━━━━
💰 *Prix live :* ${price}
📍 VWAP : ${vwap}
📊 BB : [{bb_lower} / {bb_mid} / {bb_upper}]
⚡ Supertrend : ${st_line} ({st_dir})
━━━━━━━━━━━━━━━━━━━━━━━━━
🔴/🟢 *Verdict GOM KOLA : {gom_verdict}*
   BUY={gom_buy_score} SELL={gom_sell_score} Spike={gom_spike}%
   RSI={gom_rsi}
━━━━━━━━━━━━━━━━━━━━━━━━━
🔴/🟢 *Biais session :* {bias_dir} {bias_conf}% | Age: {bias_age_sec}s
━━━━━━━━━━━━━━━━━━━━━━━━━
📦 *Ordre EA :* {'✅ Actif E=' + str(order_entry) + ' SL=' + str(order_sl) + ' TP=' + str(order_tp) if order_active else '📭 Aucun'}
━━━━━━━━━━━━━━━━━━━━━━━━━
🔴/🟢 *TradingAgents :* {report_dir} {report_conf}% | Age: {report_age_sec}s
━━━━━━━━━━━━━━━━━━━━━━━━━
🎯 *Décision:* {self._get_confluence_decision(gom_verdict, bias_dir, report_dir)}
━━━━━━━━━━━━━━━━━━━━━━━━━
_Prochain check dans 20 min_"""

        return msg

    def _get_confluence_decision(self, gom_verdict: str, bias_dir: str, report_dir: str) -> str:
        """Determine decision based on confluence."""
        signals = [gom_verdict, bias_dir, report_dir]
        buy_count = sum(1 for s in signals if s in ["BUY", "BULLISH"])
        sell_count = sum(1 for s in signals if s in ["SELL", "BEARISH"])

        if buy_count >= 2:
            return "🟢 SCALP BUY (confluence)"
        elif sell_count >= 2:
            return "🔴 SCALP SELL (confluence)"
        elif buy_count == 1 and sell_count == 0:
            return "🟡 ATTENDRE confirmation BUY"
        elif sell_count == 1 and buy_count == 0:
            return "🟡 ATTENDRE confirmation SELL"
        else:
            return "⏸️ ATTENDRE clarification"

    # =========================================================================
    # ÉTAPE 4: Envoyer le message
    # =========================================================================

    async def send_whatsapp_message(self, message: str) -> bool:
        """Send message via PsychoBot."""
        try:
            payload = {
                "phone": self.phone,
                "message": message
            }

            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: requests.post(
                    PSYCHOBOT_URL,
                    json=payload,
                    headers={"Content-Type": "application/json"},
                    timeout=10
                )
            )

            if response.status_code == 200:
                logger.info(f"[WhatsApp] ✅ Message sent to {self.phone}")
                return True
            else:
                logger.warning(f"[WhatsApp] HTTP {response.status_code}: {response.text[:200]}")
                return False

        except Exception as e:
            logger.error(f"[WhatsApp] Send failed: {e}")
            return False

    def save_message_to_log(self, message: str):
        """Fallback: Save message to log file."""
        logger.info(f"[Fallback] Saving message to log file...")
        with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
            f.write(f"\n\n{'='*80}\n")
            f.write(f"[FALLBACK] {datetime.utcnow().isoformat()}\n")
            f.write(f"{'='*80}\n")
            f.write(message)
            f.write(f"\n{'='*80}\n")
        logger.info("[Fallback] Message saved to log file")

    # =========================================================================
    # Main Execution
    # =========================================================================

    async def run_once(self):
        """Execute one full cycle: collect + build + send."""
        logger.info("=" * 80)
        logger.info(f"Starting XAUUSD monitoring cycle at {datetime.utcnow().isoformat()}")
        logger.info("=" * 80)

        try:
            # Step 1: Collect TradingView data
            tv_data = await self.collect_tradingview_data()
            logger.info(f"[TV] Collected: quote={bool(tv_data.get('quote'))}, indicators={bool(tv_data.get('indicators'))}, gom={bool(tv_data.get('gom'))}")

            # Step 2: Collect AI server data
            ai_available = True
            try:
                ai_data = await self.collect_ai_server_data()
                logger.info(f"[AI] Collected: bias={bool(ai_data.get('bias'))}, order={bool(ai_data.get('pending_order'))}, report={bool(ai_data.get('tradingagents_report'))}")
            except Exception as e:
                logger.warning(f"[AI] Server unavailable: {e}")
                ai_available = False
                ai_data = {"bias": {}, "pending_order": {}, "tradingagents_report": {}}

            # Step 3: Build message
            message = self.build_whatsapp_message(tv_data, ai_data)
            logger.info(f"[Message] Built ({len(message)} chars)")
            # Log full message to file
            with open("D:\\Dev\\TradBOT\\whatsapp_alerts.log", "a", encoding="utf-8") as f:
                f.write(f"\n{'='*80}\n[SENT MESSAGE]\n{'='*80}\n{message}\n{'='*80}\n")

            # Step 4: Send via WhatsApp
            if await self.send_whatsapp_message(message):
                logger.info("[Success] Message sent successfully")
            else:
                logger.warning("[Fallback] WhatsApp send failed, saving to log")
                self.save_message_to_log(message)

        except Exception as e:
            logger.error(f"[Fatal] Cycle failed: {e}")

        logger.info("=" * 80)

    async def run_loop(self):
        """Run continuous monitoring loop."""
        logger.info(f"Starting continuous XAUUSD monitoring (interval: {self.interval}s)")

        while True:
            try:
                await self.run_once()
            except Exception as e:
                logger.error(f"[Loop] Cycle failed: {e}")

            logger.info(f"[Loop] Sleeping for {self.interval}s...")
            await asyncio.sleep(self.interval)


async def main():
    parser = argparse.ArgumentParser(description="Unified XAUUSD Monitor")
    parser.add_argument("--interval", type=int, default=1200, help="Check interval in seconds (default: 1200 = 20 min)")
    parser.add_argument("--phone", default=DEFAULT_PHONE, help="WhatsApp phone number")
    parser.add_argument("--once", action="store_true", help="Run once and exit (instead of loop)")
    args = parser.parse_args()

    async with XAUUSDMonitor(phone=args.phone, interval=args.interval) as monitor:
        if args.once:
            await monitor.run_once()
        else:
            await monitor.run_loop()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
