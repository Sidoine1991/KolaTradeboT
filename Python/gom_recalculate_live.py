#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Recalculate Live - Generate Fresh Verdicts Based on Current Prices
Récalcule les verdicts GOM en temps réel sans dépendre de TradingView CDP
"""

import os
import sys
import json
import logging
import requests
from datetime import datetime, timezone
from pathlib import Path

log_dir = Path("logs")
log_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_dir / "gom_recalculate_live.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://localhost:8000")

def get_current_verdicts():
    """Load existing verdicts from server"""
    try:
        response = requests.get(f"{AI_SERVER_URL}/gom-verdicts", timeout=5)
        if response.status_code == 200:
            return response.json().get("verdicts", [])
    except Exception as e:
        logger.warning(f"Failed to fetch verdicts: {e}")
    return []

def get_market_data(symbol):
    """Fetch current market data for symbol"""
    try:
        # Try to get data from market endpoints
        response = requests.post(
            f"{AI_SERVER_URL}/decision",
            json={"symbol": symbol, "timestamp": datetime.now(timezone.utc).isoformat()},
            timeout=5
        )
        if response.status_code == 200:
            return response.json()
    except Exception as e:
        logger.debug(f"Market data fetch failed for {symbol}: {e}")
    return None

def recalculate_verdict(old_verdict, market_data):
    """
    Recalculate verdict based on current market data
    Apply fresh analysis logic
    """
    symbol = old_verdict.get("symbol", "")

    if not market_data:
        # Keep old verdict but mark as refreshed timestamp
        refreshed = dict(old_verdict)
        refreshed["timestamp"] = datetime.now(timezone.utc).isoformat()
        refreshed["refreshed"] = True
        refreshed["method"] = "timestamp_update"
        return refreshed

    # Extract market metrics
    ia_status_v2 = market_data.get("ia_status_v2", {})
    direction = ia_status_v2.get("direction", "NEUT")
    confidence = ia_status_v2.get("confidence_pct", 50)
    tf_alignment = market_data.get("tf_alignment", 0)
    coherence = market_data.get("coherence_pct", 0)

    # Calculate fresh verdict
    if direction == "NEUT" or confidence < 50:
        verdict = "WAIT"
    elif confidence >= 80 and tf_alignment >= 5:
        verdict = "PERFECT BUY" if direction == "BUY" else "PERFECT SELL"
    elif confidence >= 65 and tf_alignment >= 4:
        verdict = "GOOD BUY" if direction == "BUY" else "GOOD SELL"
    else:
        verdict = "WEAK BUY" if direction == "BUY" else "WEAK SELL"

    # Build refreshed verdict
    refreshed = dict(old_verdict)
    refreshed["verdict"] = verdict
    refreshed["direction"] = direction
    refreshed["confidence_pct"] = confidence
    refreshed["coherence_pct"] = coherence
    refreshed["tf_alignment"] = tf_alignment
    refreshed["timestamp"] = datetime.now(timezone.utc).isoformat()
    refreshed["refreshed"] = True
    refreshed["method"] = "market_recalculation"

    # Preserve multi-TF if available
    if "ia_status_v2" in market_data:
        refreshed["ia_status_v2"] = market_data["ia_status_v2"]

    return refreshed

def post_recalculated_verdict(verdict):
    """Send refreshed verdict to server"""
    try:
        response = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json=verdict,
            timeout=5
        )
        if response.status_code == 200:
            symbol = verdict.get("symbol", "?")
            v = verdict.get("verdict", "?")
            conf = verdict.get("confidence_pct", 0)
            method = verdict.get("method", "?")
            logger.info(f"[RECALC] {symbol}: {v} ({conf}%) via {method} - Posted ✓")
            return True
    except Exception as e:
        logger.warning(f"Failed to post verdict: {e}")
    return False

def run_recalculation():
    """Run one recalculation cycle"""
    logger.info("[RECALC] Starting verdict recalculation...")

    verdicts = get_current_verdicts()
    if not verdicts:
        logger.warning("[RECALC] No verdicts found!")
        return 0

    logger.info(f"[RECALC] Loaded {len(verdicts)} verdicts")

    recalc_count = 0
    for old_verdict in verdicts:
        symbol = old_verdict.get("symbol", "")
        if not symbol:
            continue

        # Get fresh market data
        market_data = get_market_data(symbol)

        # Recalculate verdict
        refreshed = recalculate_verdict(old_verdict, market_data)

        # Post updated verdict
        if post_recalculated_verdict(refreshed):
            recalc_count += 1

    logger.info(f"[RECALC] Recalculated {recalc_count}/{len(verdicts)} verdicts")
    return recalc_count

def main():
    logger.info("=" * 80)
    logger.info("GOM RECALCULATE LIVE - Fresh Verdicts from Current Market Data")
    logger.info("=" * 80)

    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        logger.info("[RECALC] Running single recalculation cycle...")
        run_recalculation()
        logger.info("[RECALC] Cycle complete")
    else:
        import time
        iteration = 0
        while True:
            iteration += 1
            logger.info(f"\n[RECALC] Iteration #{iteration}")
            run_recalculation()
            logger.info("[RECALC] Waiting 5 minutes until next recalculation...")
            time.sleep(300)

if __name__ == "__main__":
    main()
