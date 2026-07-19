#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Autonomous Loops Manager — Intégration des boucles autonomes dans ai_server
Lance toutes les boucles (GOM poller, sync, pipeline, recycler) comme background tasks
"""

import asyncio
import logging
import subprocess
import sys
import time
from typing import Dict, Any, Optional
from datetime import datetime, timezone
from pathlib import Path

logger = logging.getLogger(__name__)

class AutonomousLoopsManager:
    """Manage all autonomous trading loops as background tasks."""

    def __init__(self):
        self.loops = {
            "gom_poller": {
                "script": "Python/gom_mt5_poller.py",
                "interval": 30,  # 30 seconds
                "enabled": False,
                "process": None,
                "last_run": None,
            },
            "gom_sync": {
                "script": "Python/gom_sync_with_report.py",
                "args": "--report",
                "interval": 600,  # 10 minutes
                "enabled": False,
                "process": None,
                "last_run": None,
            },
            "pipeline": {
                "script": "Python/pipeline_hourly_autonomous.py",
                "args": "--once",
                "interval": 3600,  # 1 hour
                "enabled": False,
                "process": None,
                "last_run": None,
            },
            "recycler": {
                "script": "Python/order_recycler.py",
                "args": None,
                "interval": 300,  # 5 minutes
                "enabled": False,
                "process": None,
                "last_run": None,
            },
        }
        self.running = False

    async def start_loop(self, loop_name: str) -> Dict[str, Any]:
        """Start a specific autonomous loop."""
        if loop_name not in self.loops:
            return {"error": f"Loop '{loop_name}' not found"}

        loop_config = self.loops[loop_name]
        loop_config["enabled"] = True
        logger.info(f"[LOOPS] Starting {loop_name} loop (interval: {loop_config['interval']}s)")

        return {
            "loop": loop_name,
            "status": "started",
            "interval": loop_config["interval"],
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

    async def stop_loop(self, loop_name: str) -> Dict[str, Any]:
        """Stop a specific autonomous loop."""
        if loop_name not in self.loops:
            return {"error": f"Loop '{loop_name}' not found"}

        loop_config = self.loops[loop_name]
        loop_config["enabled"] = False
        logger.info(f"[LOOPS] Stopped {loop_name} loop")

        return {
            "loop": loop_name,
            "status": "stopped",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

    async def run_loop_iteration(self, loop_name: str) -> Dict[str, Any]:
        """Execute one iteration of a loop."""
        if loop_name not in self.loops:
            return {"error": f"Loop '{loop_name}' not found"}

        loop_config = self.loops[loop_name]
        script = loop_config["script"]
        args = loop_config.get("args")

        try:
            cmd = [sys.executable, script]
            if args:
                cmd.append(args)

            logger.info(f"[LOOPS] Running {loop_name}: {' '.join(cmd)}")

            # Run in subprocess with timeout
            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=120  # 2 minute timeout
            )

            loop_config["last_run"] = datetime.now(timezone.utc).isoformat()

            return {
                "loop": loop_name,
                "status": "completed",
                "exit_code": result.returncode,
                "last_run": loop_config["last_run"],
                "stdout_lines": len(result.stdout.splitlines()),
                "stderr_lines": len(result.stderr.splitlines()),
                "timestamp": datetime.now(timezone.utc).isoformat()
            }

        except subprocess.TimeoutExpired:
            logger.error(f"[LOOPS] {loop_name} timeout (>120s)")
            return {
                "loop": loop_name,
                "status": "timeout",
                "error": "Execution exceeded 120s timeout",
                "timestamp": datetime.now(timezone.utc).isoformat()
            }
        except Exception as e:
            logger.error(f"[LOOPS] Error running {loop_name}: {e}")
            return {
                "loop": loop_name,
                "status": "error",
                "error": str(e),
                "timestamp": datetime.now(timezone.utc).isoformat()
            }

    async def autonomous_scheduler(self):
        """Background scheduler that runs all enabled loops at their intervals."""
        logger.info("[LOOPS] Autonomous scheduler started")
        self.running = True

        last_run = {name: 0 for name in self.loops}
        now = time.time()

        while self.running:
            current_time = time.time()

            for loop_name, config in self.loops.items():
                if not config["enabled"]:
                    continue

                interval = config["interval"]
                elapsed = current_time - last_run[loop_name]

                if elapsed >= interval:
                    logger.info(f"[LOOPS] Triggering {loop_name} (elapsed: {elapsed:.0f}s >= {interval}s)")
                    result = await self.run_loop_iteration(loop_name)
                    last_run[loop_name] = current_time

                    if result.get("status") == "error":
                        logger.error(f"[LOOPS] {loop_name} failed: {result.get('error')}")

            # Sleep briefly to avoid busy-waiting
            await asyncio.sleep(1)

    def get_status(self) -> Dict[str, Any]:
        """Get status of all loops."""
        loops_status = {}
        for name, config in self.loops.items():
            loops_status[name] = {
                "enabled": config["enabled"],
                "interval": config["interval"],
                "last_run": config["last_run"],
                "script": config["script"]
            }

        return {
            "scheduler_running": self.running,
            "loops": loops_status,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

    async def start_all_loops(self) -> Dict[str, Any]:
        """Start all autonomous loops."""
        for loop_name in self.loops:
            await self.start_loop(loop_name)

        # Start the scheduler
        asyncio.create_task(self.autonomous_scheduler())

        return {
            "status": "all_loops_started",
            "loops": list(self.loops.keys()),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }

    async def stop_all_loops(self) -> Dict[str, Any]:
        """Stop all autonomous loops."""
        self.running = False
        for loop_name in self.loops:
            await self.stop_loop(loop_name)

        return {
            "status": "all_loops_stopped",
            "timestamp": datetime.now(timezone.utc).isoformat()
        }


# Global instance
loops_manager = AutonomousLoopsManager()
