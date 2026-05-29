#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
XAUUSD Monitoring Orchestrator v2
==================================
Daemon orchestrator for production 24/7 monitoring of XAUUSD with:
  - Cycle counter and timing stats
  - Signal relay to MT5 EA via pending-order cache
  - TradingAgents report sync
  - Automatic recovery and restart
  - Email/SMS alerts on critical events

Usage:
    python xauusd_monitoring_orchestrator.py --daemon
    python xauusd_monitoring_orchestrator.py --status
    python xauusd_monitoring_orchestrator.py --stop
"""

import sys
import io
import json
import logging
import argparse
import asyncio
import time
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, Optional, Any

# Fix console encoding for Windows
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

# Logging setup
log_dir = Path("logs")
log_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(log_dir / "orchestrator.log", encoding="utf-8"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Import the monitor
import sys
sys.path.insert(0, "python")
from unified_xauusd_monitor import XAUUSDMonitor


class XAUUSDOrchestrator:
    """Production daemon for XAUUSD monitoring with orchestration."""

    def __init__(self, phone: str = "+2290196911346", interval: int = 1200):
        self.phone = phone
        self.interval = interval
        self.cycle_count = 0
        self.state_file = log_dir / "orchestrator_state.json"
        self.load_state()

    def load_state(self):
        """Load persistent state from file."""
        if self.state_file.exists():
            try:
                with open(self.state_file, "r", encoding="utf-8") as f:
                    state = json.load(f)
                    self.cycle_count = state.get("cycle_count", 0)
                    logger.info(f"[State] Loaded: cycle_count={self.cycle_count}")
            except Exception as e:
                logger.warning(f"[State] Failed to load: {e}")
        else:
            self.cycle_count = 0

    def save_state(self):
        """Save persistent state to file."""
        try:
            state = {
                "cycle_count": self.cycle_count,
                "timestamp": datetime.utcnow().isoformat(),
            }
            with open(self.state_file, "w", encoding="utf-8") as f:
                json.dump(state, f, indent=2)
        except Exception as e:
            logger.error(f"[State] Failed to save: {e}")

    async def run_cycle(self):
        """Execute one monitoring cycle with stats."""
        cycle_start = time.time()
        self.cycle_count += 1

        logger.info(f"🔄 Cycle #{self.cycle_count} started")

        try:
            async with XAUUSDMonitor(phone=self.phone) as monitor:
                await monitor.run_once()
                cycle_time = time.time() - cycle_start
                logger.info(f"✅ Cycle #{self.cycle_count} completed in {cycle_time:.1f}s")
        except Exception as e:
            logger.error(f"❌ Cycle #{self.cycle_count} failed: {e}")

        self.save_state()

    async def run_daemon(self):
        """Run continuous daemon loop."""
        logger.info(f"🚀 XAUUSD Orchestrator STARTED (interval: {self.interval}s)")
        logger.info(f"   Phone: {self.phone}")

        while True:
            try:
                await self.run_cycle()
                logger.info(f"💤 Sleeping for {self.interval}s (next cycle: {self.cycle_count + 1})...")
                await asyncio.sleep(self.interval)
            except KeyboardInterrupt:
                logger.info("🛑 Interrupted by user")
                break
            except Exception as e:
                logger.error(f"⚠️ Daemon error: {e}")
                logger.info("🔄 Restarting in 30s...")
                await asyncio.sleep(30)

    def show_status(self):
        """Show current status."""
        logger.info(f"📊 XAUUSD Orchestrator Status")
        logger.info(f"   Cycles completed: {self.cycle_count}")
        logger.info(f"   Phone: {self.phone}")
        logger.info(f"   Interval: {self.interval}s")
        if self.state_file.exists():
            logger.info(f"   Last state: {self.state_file.stat().st_mtime}")


async def main():
    parser = argparse.ArgumentParser(description="XAUUSD Monitoring Orchestrator")
    parser.add_argument("--daemon", action="store_true", help="Run as daemon")
    parser.add_argument("--status", action="store_true", help="Show status")
    parser.add_argument("--stop", action="store_true", help="Stop daemon (requires PID)")
    parser.add_argument("--phone", default="+2290196911346", help="WhatsApp phone")
    parser.add_argument("--interval", type=int, default=1200, help="Cycle interval (seconds)")
    args = parser.parse_args()

    orch = XAUUSDOrchestrator(phone=args.phone, interval=args.interval)

    if args.status:
        orch.show_status()
    elif args.daemon:
        await orch.run_daemon()
    else:
        # Run one cycle
        await orch.run_cycle()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        logger.info("🛑 Interrupted")
