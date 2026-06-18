#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Sync Daemon — Exécute la synchronisation GOM toutes les 10 minutes
Remplace Windows Task Scheduler avec une boucle Python autonome
"""

import sys
import io
import time
import subprocess
import logging
from pathlib import Path
from datetime import datetime, timezone

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

LOGS_DIR = Path("D:/Dev/TradBOT/logs")
LOGS_DIR.mkdir(exist_ok=True)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - GOM_DAEMON - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOGS_DIR / "gom_sync_daemon.log", encoding='utf-8', mode='a'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

INTERVAL_SECONDS = 600  # 10 minutes
SCRIPT_PATH = Path("D:/Dev/TradBOT/Python/gom_sync_with_report.py")

def run_gom_sync():
    """Exécute une synchronisation GOM"""
    try:
        logger.info("[GOM] Starting sync cycle...")
        result = subprocess.run(
            [sys.executable, str(SCRIPT_PATH), "--report"],
            cwd="D:/Dev/TradBOT",
            capture_output=True,
            text=True,
            timeout=300  # 5 minutes timeout
        )

        if result.returncode == 0:
            logger.info("[GOM] Sync completed successfully")
            # Log last few lines of output
            lines = result.stdout.split('\n')
            for line in lines[-5:]:
                if line.strip():
                    logger.info(f"[GOM] {line}")
        else:
            logger.error(f"[GOM] Sync failed with code {result.returncode}")
            if result.stderr:
                logger.error(f"[GOM] Error: {result.stderr[:500]}")

    except subprocess.TimeoutExpired:
        logger.error("[GOM] Sync timed out after 5 minutes")
    except Exception as e:
        logger.error(f"[GOM] Exception: {e}")

def main():
    logger.info("="*70)
    logger.info("GOM SYNC DAEMON STARTED")
    logger.info("="*70)
    logger.info(f"Interval: {INTERVAL_SECONDS} seconds (10 minutes)")
    logger.info(f"Script:   {SCRIPT_PATH}")
    logger.info(f"Logs:     {LOGS_DIR / 'gom_sync.log'}")
    logger.info("")

    run_count = 0
    start_time = datetime.now(timezone.utc)

    try:
        while True:
            run_count += 1
            elapsed = (datetime.now(timezone.utc) - start_time).total_seconds()
            elapsed_hours = elapsed / 3600

            logger.info("")
            logger.info("="*70)
            logger.info(f"[CYCLE #{run_count}] Starting GOM sync (uptime: {elapsed_hours:.1f}h)")
            logger.info("="*70)

            run_gom_sync()

            logger.info(f"[CYCLE] Next run in {INTERVAL_SECONDS} seconds...")
            logger.info("")

            time.sleep(INTERVAL_SECONDS)

    except KeyboardInterrupt:
        logger.info("")
        logger.info("="*70)
        logger.info("GOM SYNC DAEMON STOPPED (Ctrl+C)")
        logger.info("="*70)
        logger.info(f"Ran {run_count} cycles over {elapsed_hours:.1f} hours")
        sys.exit(0)

    except Exception as e:
        logger.error(f"Fatal error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
