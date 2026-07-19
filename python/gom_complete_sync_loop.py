#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Complete Sync Loop - Every 10 Minutes
Combines: Load → Refresh → Report → WhatsApp
"""

import os
import sys
import json
import logging
import requests
import subprocess
from datetime import datetime, timezone
from pathlib import Path

log_dir = Path("logs")
log_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_dir / "gom_complete_sync.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://localhost:8000")

def run_command(cmd, description):
    """Run a Python script and return status"""
    logger.info(f"[{description}] Starting...")
    try:
        result = subprocess.run(
            cmd,
            shell=True,
            capture_output=True,
            text=True,
            timeout=120
        )
        if result.returncode == 0:
            logger.info(f"[{description}] Completed OK")
            return True
        else:
            logger.warning(f"[{description}] Failed with code {result.returncode}")
            if result.stderr:
                logger.warning(f"  Error: {result.stderr[:200]}")
            return False
    except Exception as e:
        logger.error(f"[{description}] Exception: {e}")
        return False

def run_complete_cycle():
    """Run complete GOM sync cycle"""
    timestamp = datetime.now(timezone.utc).isoformat()
    logger.info("")
    logger.info("=" * 80)
    logger.info(f"[CYCLE] Starting complete GOM sync cycle - {timestamp}")
    logger.info("=" * 80)

    steps_ok = 0
    total_steps = 2

    # Step 1: Smart Refresh (mark stale verdicts)
    if run_command(
        "python Python/gom_smart_refresh.py --once",
        "STEP 1: SMART REFRESH"
    ):
        steps_ok += 1

    # Step 2: GOM Sync with Report (send verdicts + WhatsApp)
    if run_command(
        "python Python/gom_sync_with_report.py --report",
        "STEP 2: GOM SYNC & REPORT"
    ):
        steps_ok += 1

    logger.info("")
    logger.info(f"[CYCLE] Completed: {steps_ok}/{total_steps} steps OK")
    logger.info("=" * 80)

    return steps_ok == total_steps

def main():
    logger.info("")
    logger.info("=" * 80)
    logger.info("GOM COMPLETE SYNC LOOP - Every 10 Minutes")
    logger.info("=" * 80)

    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        logger.info("[MAIN] Running single cycle...")
        run_complete_cycle()
        logger.info("[MAIN] Cycle complete")
    else:
        import time
        iteration = 0
        while True:
            iteration += 1
            logger.info(f"\n[MAIN] Iteration #{iteration}")
            run_complete_cycle()
            logger.info("[MAIN] Waiting 10 minutes until next cycle...")
            time.sleep(600)

if __name__ == "__main__":
    main()
