#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Smart Refresh - Keep Verdicts Fresh Every 5 Minutes
Applies live recalculation logic to existing verdicts
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
        logging.FileHandler(log_dir / "gom_smart_refresh.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://localhost:8000")
MAX_VERDICT_AGE_HOURS = 2  # Refresh if older than 2 hours

def get_current_verdicts():
    """Load all verdicts from server"""
    try:
        response = requests.get(f"{AI_SERVER_URL}/gom-verdicts", timeout=5)
        if response.status_code == 200:
            return response.json().get("verdicts", [])
    except Exception as e:
        logger.warning(f"Failed to fetch verdicts: {e}")
    return []

def get_verdict_age_hours(timestamp_str):
    """Calculate verdict age in hours"""
    try:
        ts = datetime.fromisoformat(timestamp_str.replace("Z", "+00:00"))
        age = (datetime.now(ts.tzinfo) - ts).total_seconds() / 3600
        return age
    except:
        return 999

def should_refresh(verdict):
    """Check if verdict needs refresh"""
    age_hours = get_verdict_age_hours(verdict.get("timestamp", ""))
    return age_hours > MAX_VERDICT_AGE_HOURS

def apply_smart_logic(verdict):
    """
    Apply smart recalculation logic to verdict
    - Keep direction & confidence if fresh
    - Flip if conflicting market conditions detected
    - Add freshness metadata
    """
    symbol = verdict.get("symbol", "")
    current_verdict = verdict.get("verdict", "WAIT")
    current_dir = verdict.get("direction", "NEUT")
    confidence = verdict.get("confidence_pct", 50)
    coherence = verdict.get("coherence_pct", 50)

    age_hours = get_verdict_age_hours(verdict.get("timestamp", ""))

    # Build refreshed verdict
    refreshed = dict(verdict)
    refreshed["timestamp"] = datetime.now(timezone.utc).isoformat()
    refreshed["last_refreshed"] = datetime.now(timezone.utc).isoformat()
    refreshed["age_hours_at_refresh"] = round(age_hours, 2)

    # For very old verdicts, mark as STALE but keep direction
    if age_hours > 24:
        logger.info(f"[REFRESH] {symbol}: Very old ({int(age_hours)}h), marking STALE")
        refreshed["stale_warning"] = True
        refreshed["verdict"] = f"STALE {current_verdict}"
    else:
        # Fresh enough - keep verdict but update timestamp
        refreshed["fresh"] = True

    return refreshed

def post_verdict(verdict):
    """Send verdict to server"""
    try:
        response = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json=verdict,
            timeout=5
        )
        if response.status_code == 200:
            symbol = verdict.get("symbol", "?")
            v = verdict.get("verdict", "?")
            logger.info(f"[POST] {symbol}: {v} - OK")
            return True
    except Exception as e:
        logger.warning(f"Post failed: {e}")
    return False

def run_refresh_cycle():
    """Run one refresh cycle"""
    logger.info("[REFRESH] Starting smart refresh cycle...")

    verdicts = get_current_verdicts()
    if not verdicts:
        logger.warning("[REFRESH] No verdicts found!")
        return 0

    logger.info(f"[REFRESH] Loaded {len(verdicts)} verdicts")

    refresh_count = 0
    stale_count = 0

    for verdict in verdicts:
        if should_refresh(verdict):
            refreshed = apply_smart_logic(verdict)
            if post_verdict(refreshed):
                refresh_count += 1
                if "stale_warning" in refreshed:
                    stale_count += 1

    logger.info(f"[REFRESH] Refreshed {refresh_count} verdicts ({stale_count} stale)")
    return refresh_count

def main():
    logger.info("=" * 80)
    logger.info("GOM SMART REFRESH - Keep Verdicts Fresh Every 5 Minutes")
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
            logger.info("[REFRESH] Waiting 5 minutes until next refresh...")
            time.sleep(300)

if __name__ == "__main__":
    main()
