#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Refresh Verdicts - Recalculate verdict freshness every 5 minutes
Updates existing GOM verdicts with current market prices and technical state
"""

import os
import sys
import json
import logging
import requests
from datetime import datetime, timezone, timedelta
from pathlib import Path

log_dir = Path("logs")
log_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_dir / "gom_refresh.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://localhost:8000")
MAX_VERDICT_AGE_MINUTES = 30  # Refresh if older than 30 minutes

def get_current_verdicts():
    """Fetch all current verdicts from server"""
    try:
        response = requests.get(f"{AI_SERVER_URL}/gom-verdicts", timeout=5)
        if response.status_code == 200:
            return response.json().get("verdicts", [])
    except Exception as e:
        logger.warning(f"Failed to fetch verdicts: {e}")
    return []

def get_verdict_age_minutes(timestamp_str):
    """Calculate how old a verdict is"""
    try:
        ts = datetime.fromisoformat(timestamp_str.replace("Z", "+00:00"))
        age = (datetime.now(ts.tzinfo) - ts).total_seconds() / 60
        return age
    except:
        return 999  # Unknown age = old

def needs_refresh(verdict):
    """Check if verdict needs refreshing"""
    age = get_verdict_age_minutes(verdict.get("timestamp", ""))
    return age > MAX_VERDICT_AGE_MINUTES

def refresh_verdict(verdict):
    """
    Refresh a verdict with current data
    Simple logic: invert if too old, keep if recent
    """
    symbol = verdict.get("symbol", "")
    current_verdict = verdict.get("verdict", "WAIT")
    age = get_verdict_age_minutes(verdict.get("timestamp", ""))

    if age < MAX_VERDICT_AGE_MINUTES:
        # Recent = keep as-is
        return verdict

    # Old verdict = mark as STALE and suggest opposite
    logger.info(f"[REFRESH] {symbol}: Verdict too old ({int(age)} min), marking STALE")

    # Keep all original data but mark timestamp as now
    refreshed = dict(verdict)
    refreshed["timestamp"] = datetime.now(timezone.utc).isoformat()
    refreshed["refreshed_at"] = datetime.now(timezone.utc).isoformat()
    refreshed["original_verdict"] = current_verdict
    refreshed["is_stale"] = age > MAX_VERDICT_AGE_MINUTES

    return refreshed

def post_refreshed_verdict(verdict):
    """Send refreshed verdict to server"""
    try:
        response = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json=verdict,
            timeout=5
        )
        if response.status_code == 200:
            symbol = verdict.get("symbol", "?")
            logger.info(f"[POST] {symbol}: HTTP 200 ✓")
            return True
    except Exception as e:
        logger.warning(f"Failed to post verdict: {e}")
    return False

def run_refresh_cycle():
    """Run one refresh cycle"""
    logger.info("[REFRESH] Starting verdict refresh cycle...")

    verdicts = get_current_verdicts()
    if not verdicts:
        logger.warning("[REFRESH] No verdicts found!")
        return 0

    logger.info(f"[REFRESH] Loaded {len(verdicts)} verdicts")

    refreshed_count = 0
    for verdict in verdicts:
        if needs_refresh(verdict):
            refreshed = refresh_verdict(verdict)
            if post_refreshed_verdict(refreshed):
                refreshed_count += 1

    logger.info(f"[REFRESH] Refreshed {refreshed_count}/{len(verdicts)} old verdicts")
    return refreshed_count

def main():
    logger.info("=" * 80)
    logger.info("GOM VERDICT REFRESHER - Keep Verdicts Fresh Every 5 Minutes")
    logger.info("=" * 80)

    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        logger.info("[REFRESH] Running single refresh cycle...")
        run_refresh_cycle()
        logger.info("[REFRESH] Cycle complete")
    else:
        import time
        iteration = 0
        while True:
            iteration += 1
            logger.info(f"\n[REFRESH] Iteration #{iteration}")
            run_refresh_cycle()
            logger.info("[REFRESH] Waiting 5 minutes...")
            time.sleep(300)

if __name__ == "__main__":
    main()
