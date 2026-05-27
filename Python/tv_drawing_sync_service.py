"""
TradingView Drawing Sync Service v1
====================================

Polls TradingView chart drawings every 5 seconds via MCP tools.
Detects user-drawn horizontal lines labeled "SL XAUUSD" or "TP XAUUSD".
Updates pending orders when drawings change.
Draws automatic SL/TP lines when orders are created.

Usage:
    python tv_drawing_sync_service.py --symbol XAUUSD --interval 5

Requirements:
    - TradingView Desktop running with MCP server
    - AI server running on http://127.0.0.1:8000
    - Node.js for MCP CLI tool
"""

import asyncio
import subprocess
import json
import sys
import io
import re
import time
import logging
from typing import Dict, Optional, List
from datetime import datetime

import aiohttp

# Fix Windows console encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("tv_drawing_sync.log", encoding="utf-8"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)

# Configuration
AI_SERVER_URL = "http://127.0.0.1:8000"
MCP_CLI_PATH = "D:/Dev/Depot Github/tradingview-mcp_kola/src/cli.mjs"


class TVDrawingSyncService:
    """Service de synchronisation des drawings TradingView avec les ordres pending."""

    def __init__(self, symbol: str, poll_interval: int = 5):
        self.symbol = symbol
        self.poll_interval = poll_interval
        self.last_drawings: Dict[str, float] = {}  # {entity_id: price}
        self.last_order_id: Optional[str] = None
        self.session: Optional[aiohttp.ClientSession] = None

    async def __aenter__(self):
        """Context manager entry."""
        self.session = aiohttp.ClientSession()
        return self

    async def __aexit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit."""
        if self.session:
            await self.session.close()

    # ─────────────────────────────────────────────────────────────
    # MCP Tool Wrappers
    # ─────────────────────────────────────────────────────────────

    def _run_mcp(self, *args: str) -> Optional[dict]:
        """Calls MCP CLI tool and returns JSON result."""
        try:
            cmd = f"node {MCP_CLI_PATH} " + " ".join(args)
            result = subprocess.run(
                cmd,
                shell=True,
                capture_output=True,
                text=True,
                timeout=10,
            )
            if result.returncode != 0:
                logger.warning(f"MCP error: {result.stderr[:200]}")
                return None

            try:
                return json.loads(result.stdout)
            except json.JSONDecodeError:
                logger.warning(f"MCP invalid JSON: {result.stdout[:200]}")
                return None
        except Exception as e:
            logger.error(f"❌ MCP call failed: {e}")
            return None

    def draw_list(self) -> List[dict]:
        """Gets all drawings on chart via draw_list MCP tool."""
        result = self._run_mcp("draw_list", "--format", "json")
        if result and isinstance(result, list):
            return result
        return []

    def draw_shape(
        self,
        shape_type: str,
        price: float,
        label: str,
        color: str = "white",
    ) -> bool:
        """Draws a shape on chart via draw_shape MCP tool."""
        result = self._run_mcp(
            "draw_shape",
            "--type", shape_type,
            "--price", str(price),
            "--label", label,
            "--color", color,
        )
        return result is not None

    def draw_remove_one(self, entity_id: str) -> bool:
        """Removes a drawing by entity_id via draw_remove_one MCP tool."""
        result = self._run_mcp("draw_remove_one", "--entity_id", entity_id)
        return result is not None

    # ─────────────────────────────────────────────────────────────
    # Drawing Analysis
    # ─────────────────────────────────────────────────────────────

    def identify_sltp_lines(self, drawings: List[dict]) -> Dict[str, dict]:
        """
        Identifies SL/TP/ENTRY lines by label pattern.
        Pattern: "SL SYMBOL", "TP SYMBOL", "ENTRY SYMBOL"
        """
        pattern = re.compile(
            rf"^(SL|TP|ENTRY)\s+{re.escape(self.symbol)}$",
            re.IGNORECASE
        )
        matched = {}

        for d in drawings:
            if d.get("type") != "horizontal_line":
                continue

            label = d.get("text", "").strip()
            match = pattern.match(label)
            if not match:
                continue

            line_type = match.group(1).upper()
            matched[line_type] = {
                "entity_id": d.get("entity_id"),
                "price": float(d.get("price", 0)),
                "label": label,
            }

        return matched

    # ─────────────────────────────────────────────────────────────
    # Order Management
    # ─────────────────────────────────────────────────────────────

    async def get_pending_order(self) -> Optional[dict]:
        """Fetches pending order for symbol from AI server."""
        if not self.session:
            return None

        try:
            async with self.session.get(
                f"{AI_SERVER_URL}/pending-order",
                params={"symbol": self.symbol},
                timeout=aiohttp.ClientTimeout(total=5),
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    if data.get("ok") and data.get("orders"):
                        return data["orders"][0]
        except Exception as e:
            logger.warning(f"Failed to fetch pending order: {e}")

        return None

    async def patch_order_sltp(
        self,
        order_id: str,
        stop_loss: Optional[float] = None,
        take_profit: Optional[float] = None,
    ) -> bool:
        """Updates SL/TP via PATCH /pending-order/{order_id}."""
        if not self.session:
            return False

        try:
            body = {
                "update_source": "tv_manual",
            }
            if stop_loss is not None:
                body["stop_loss"] = stop_loss
            if take_profit is not None:
                body["take_profit"] = take_profit

            async with self.session.patch(
                f"{AI_SERVER_URL}/pending-order/{order_id}",
                json=body,
                timeout=aiohttp.ClientTimeout(total=5),
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    if data.get("ok"):
                        logger.info(
                            f"✅ Patched order {order_id}: SL={stop_loss} TP={take_profit}"
                        )
                        return True

        except Exception as e:
            logger.error(f"Failed to patch order: {e}")

        return False

    # ─────────────────────────────────────────────────────────────
    # Drawing Sync
    # ─────────────────────────────────────────────────────────────

    async def draw_order_levels(
        self,
        entry: float,
        sl: float,
        tp: float,
    ) -> bool:
        """Draws ENTRY, SL, TP lines on chart."""
        success = True

        # Remove old lines first
        await self.clear_order_drawings()

        # Draw new lines
        lines = [
            ("horizontal_line", entry, f"ENTRY {self.symbol}", "blue"),
            ("horizontal_line", sl, f"SL {self.symbol}", "red"),
            ("horizontal_line", tp, f"TP {self.symbol}", "green"),
        ]

        for shape_type, price, label, color in lines:
            if self.draw_shape(shape_type, price, label, color):
                logger.info(f"📍 Drew {label} @ {price:.2f}")
            else:
                logger.warning(f"⚠️ Failed to draw {label}")
                success = False

        return success

    async def clear_order_drawings(self) -> bool:
        """Removes all ENTRY/SL/TP lines for this symbol."""
        try:
            drawings = self.draw_list()
            pattern = re.compile(
                rf"^(ENTRY|SL|TP)\s+{re.escape(self.symbol)}$",
                re.IGNORECASE
            )

            removed_count = 0
            for d in drawings:
                if d.get("type") != "horizontal_line":
                    continue

                label = d.get("text", "").strip()
                if pattern.match(label):
                    entity_id = d.get("entity_id")
                    if self.draw_remove_one(entity_id):
                        removed_count += 1
                        logger.debug(f"Removed drawing: {label}")

            if removed_count > 0:
                logger.info(f"🗑️ Cleared {removed_count} old drawings")
            return True

        except Exception as e:
            logger.error(f"Failed to clear drawings: {e}")
            return False

    # ─────────────────────────────────────────────────────────────
    # Main Loop
    # ─────────────────────────────────────────────────────────────

    async def sync_user_changes(self):
        """Polls drawings, detects changes, syncs to server."""
        try:
            # Get current drawings
            drawings = self.draw_list()
            sltp_lines = self.identify_sltp_lines(drawings)

            # Get pending order
            order = await self.get_pending_order()
            if not order:
                # No pending order — just clear drawings
                if self.last_drawings:
                    await self.clear_order_drawings()
                    self.last_drawings = {}
                return

            order_id = order.get("order_id")

            # Check for changes
            for line_type, line_info in sltp_lines.items():
                entity_id = line_info["entity_id"]
                price = line_info["price"]

                # Detect change
                if entity_id not in self.last_drawings or self.last_drawings[entity_id] != price:
                    # User dragged the line — sync to server
                    if line_type == "SL":
                        await self.patch_order_sltp(order_id, stop_loss=price)
                    elif line_type == "TP":
                        await self.patch_order_sltp(order_id, take_profit=price)

                    self.last_drawings[entity_id] = price

        except Exception as e:
            logger.error(f"Sync error: {e}")

    async def sync_order_changes(self):
        """
        Checks if pending order changed (new SL/TP from server).
        If so, updates drawings on chart.
        """
        try:
            order = await self.get_pending_order()
            if not order:
                return

            order_id = order.get("order_id")

            # New order?
            if order_id != self.last_order_id:
                logger.info(f"🆕 New order detected: {order_id}")
                self.last_order_id = order_id

                entry = order.get("entry_price")
                sl = order.get("stop_loss")
                tp = order.get("take_profit")

                if all([entry, sl, tp]):
                    await self.draw_order_levels(entry, sl, tp)
                    self.last_drawings = {}

            # Order SL/TP changed?
            elif order.get("last_sl_update") or order.get("last_tp_update"):
                source = order.get("sl_update_source") or order.get("tp_update_source", "")

                # Only sync if change came from EA (not from TV manual)
                if source == "ea_trailing":
                    logger.info(f"🔄 Order updated from EA ({source})")

                    entry = order.get("entry_price")
                    sl = order.get("stop_loss")
                    tp = order.get("take_profit")

                    if all([entry, sl, tp]):
                        await self.draw_order_levels(entry, sl, tp)
                        self.last_drawings = {}

        except Exception as e:
            logger.error(f"Order change sync error: {e}")

    async def run(self):
        """Main polling loop."""
        logger.info(
            f"🚀 TradingView Drawing Sync Service started — {self.symbol} "
            f"(poll interval: {self.poll_interval}s)"
        )

        while True:
            try:
                # Sync user manual changes to server
                await self.sync_user_changes()

                # Sync server order changes to drawings
                await self.sync_order_changes()

            except Exception as e:
                logger.error(f"❌ Loop error: {e}")

            await asyncio.sleep(self.poll_interval)


async def main(symbol: str = "XAUUSD", interval: int = 5):
    """Main entry point."""
    async with TVDrawingSyncService(symbol, interval) as service:
        try:
            await service.run()
        except KeyboardInterrupt:
            logger.info("👋 Shutting down...")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="TradingView Drawing Sync Service")
    parser.add_argument("--symbol", default="XAUUSD", help="Trading symbol (default: XAUUSD)")
    parser.add_argument("--interval", type=int, default=5, help="Poll interval in seconds (default: 5)")
    args = parser.parse_args()

    try:
        asyncio.run(main(args.symbol, args.interval))
    except KeyboardInterrupt:
        logger.info("Exited by user")
