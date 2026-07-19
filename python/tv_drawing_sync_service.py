#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TradingView Drawing Sync Service - Polls TradingView drawings and syncs SL/TP to AI server.
"""

import asyncio
import subprocess
import json
import re
import sys
import argparse
import logging
from typing import Dict, Optional, List
import aiohttp

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - [%(name)s] - %(levelname)s - %(message)s'
)
logger = logging.getLogger("TVDrawingSync")

AI_SERVER_URL = "http://127.0.0.1:8000"
MCP_CLI = "node D:/Dev/Depot\ Github/tradingview-mcp_kola/src/cli.mjs"


class TVDrawingSyncService:
    """Service that synchronizes TradingView drawings with pending orders."""

    def __init__(self, symbol: str, poll_interval: int = 5, ai_server_url: str = AI_SERVER_URL):
        self.symbol = symbol.upper()
        self.poll_interval = poll_interval
        self.ai_server_url = ai_server_url
        self.last_drawings: Dict[str, float] = {}

    async def call_mcp_tool(self, tool_name: str, args: str = "") -> Optional[str]:
        """Call an MCP tool via subprocess."""
        try:
            cmd = f'{MCP_CLI} {tool_name} {args}'
            logger.debug(f"Calling MCP: {cmd}")
            result = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)

            if result.returncode != 0:
                logger.warning(f"MCP tool {tool_name} failed: {result.stderr[:200]}")
                return None

            return result.stdout.strip()
        except subprocess.TimeoutExpired:
            logger.warning(f"MCP tool {tool_name} timeout")
            return None
        except Exception as e:
            logger.error(f"MCP tool error: {e}")
            return None

    async def poll_drawings(self) -> List[dict]:
        """Poll TradingView for horizontal lines."""
        try:
            output = await self.call_mcp_tool("data_get_pine_lines")
            if not output:
                return []

            lines = json.loads(output)
            if not isinstance(lines, list):
                return []

            horizontal = [l for l in lines if l.get("type") == "horizontal_line"]
            logger.debug(f"Polled {len(horizontal)} horizontal lines")
            return horizontal
        except json.JSONDecodeError:
            logger.warning("Failed to parse MCP response as JSON")
            return []
        except Exception as e:
            logger.error(f"Poll drawings error: {e}")
            return []

    def identify_sltp_lines(self, drawings: List[dict]) -> Dict[str, dict]:
        """Identify SL/TP/ENTRY lines by label."""
        pattern = re.compile(rf"^(SL|TP|ENTRY)\s+{re.escape(self.symbol)}$", re.IGNORECASE)
        matched = {}

        for drawing in drawings:
            text = drawing.get("text", "").strip()
            price = drawing.get("price")

            if pattern.match(text) and price is not None:
                line_type = text.split()[0].upper()
                matched[line_type] = {
                    "entity_id": drawing.get("entity_id"),
                    "price": float(price),
                    "text": text
                }

        return matched

    async def sync_to_server(self, line_type: str, price: float) -> bool:
        """PATCH /pending-order with new SL/TP."""
        try:
            async with aiohttp.ClientSession() as session:
                url = f"{self.ai_server_url}/pending-order/{self.symbol}"

                body = {
                    "stop_loss": price if line_type == "SL" else None,
                    "take_profit": price if line_type == "TP" else None,
                    "update_source": "tv_manual",
                    "reason": f"User-drawn {line_type} line"
                }

                body = {k: v for k, v in body.items() if v is not None}

                async with session.patch(url, json=body) as resp:
                    if resp.status == 200:
                        result = await resp.json()
                        if result.get("ok"):
                            logger.info(f"✅ Synced {line_type}={price:.2f} to {self.symbol}")
                            return True
                    else:
                        text = await resp.text()
                        logger.warning(f"HTTP {resp.status}: {text[:200]}")
        except Exception as e:
            logger.error(f"Sync error: {e}")

        return False

    async def check_and_sync(self) -> None:
        """Poll and sync changes."""
        try:
            drawings = await self.poll_drawings()
            sltp_lines = self.identify_sltp_lines(drawings)

            if not sltp_lines:
                if self.last_drawings:
                    logger.info(f"No SL/TP lines detected")
                    self.last_drawings.clear()
                return

            for line_type, line_info in sltp_lines.items():
                price = line_info["price"]
                old_price = self.last_drawings.get(line_type)

                if old_price is None:
                    logger.info(f"🆕 New {line_type} at {price:.2f}")
                    await self.sync_to_server(line_type, price)
                    self.last_drawings[line_type] = price
                elif abs(old_price - price) > 0.01:
                    logger.info(f"📍 {line_type}: {old_price:.2f} → {price:.2f}")
                    await self.sync_to_server(line_type, price)
                    self.last_drawings[line_type] = price

            removed = set(self.last_drawings.keys()) - set(sltp_lines.keys())
            if removed:
                logger.info(f"❌ Removed: {', '.join(removed)}")
                for t in removed:
                    del self.last_drawings[t]

        except Exception as e:
            logger.error(f"Check and sync error: {e}")

    async def run(self) -> None:
        """Main loop."""
        logger.info(f"🚀 TradingView Drawing Sync: {self.symbol} (interval={self.poll_interval}s)")
        logger.info(f"   Server: {self.ai_server_url}")

        while True:
            try:
                await self.check_and_sync()
            except KeyboardInterrupt:
                logger.info("Shutdown")
                break
            except Exception as e:
                logger.error(f"Loop error: {e}")

            await asyncio.sleep(self.poll_interval)


async def main():
    parser = argparse.ArgumentParser(description="TradingView Drawing Sync")
    parser.add_argument("--symbol", default="XAUUSD")
    parser.add_argument("--interval", type=int, default=5)
    parser.add_argument("--server", default=AI_SERVER_URL)
    args = parser.parse_args()

    service = TVDrawingSyncService(args.symbol, args.interval, args.server)
    await service.run()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("Terminated")
        sys.exit(0)
