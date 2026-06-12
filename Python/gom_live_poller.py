#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Live Poller - Generate Fresh Verdicts Every 5 Minutes
Pulls real-time data from TradingView and calculates verdicts on-the-fly
"""

import os
import sys
import json
import logging
import requests
from datetime import datetime, timezone
from pathlib import Path

# Setup logging
log_dir = Path("logs")
log_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_dir / "gom_live_poller.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Symbols to analyze
SYMBOLS = [
    "XAUUSD", "EURUSD", "GBPUSD", "USDJPY", "AUDUSD",
    "BOOM 500 INDEX", "BOOM 1000 INDEX", "BOOM 300 INDEX",
    "CRASH 500 INDEX", "CRASH 1000 INDEX", "CRASH 300 INDEX",
    "BTC/USD", "ETH/USD"
]

AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://localhost:8000")

def get_live_analysis(symbol):
    """Fetch live analysis from AI Server"""
    try:
        payload = {
            "symbol": symbol,
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        response = requests.post(
            f"{AI_SERVER_URL}/decision",
            json=payload,
            timeout=10
        )
        if response.status_code == 200:
            return response.json()
        else:
            logger.debug(f"[LIVE] {symbol} returned {response.status_code}")
    except Exception as e:
        logger.warning(f"[LIVE] Failed to fetch {symbol}: {e}")
    return None

def calculate_verdict(analysis):
    """Calculate verdict from live analysis"""
    if not analysis:
        return None

    # Extract key metrics
    ia_status_v2 = analysis.get("ia_status_v2", {})
    direction = ia_status_v2.get("direction", "NEUT")
    confidence = ia_status_v2.get("confidence_pct", 50)

    tf_alignment = analysis.get("tf_alignment", 0)
    coherence = analysis.get("coherence_pct", 0)

    # Determine verdict
    if direction == "NEUT" or confidence < 50:
        verdict = "WAIT"
    elif confidence >= 80 and tf_alignment >= 5:
        verdict = "PERFECT BUY" if direction == "BUY" else "PERFECT SELL"
    elif confidence >= 65 and tf_alignment >= 4:
        verdict = "GOOD BUY" if direction == "BUY" else "GOOD SELL"
    else:
        verdict = "WEAK BUY" if direction == "BUY" else "WEAK SELL"

    return {
        "symbol": analysis.get("symbol"),
        "verdict": verdict,
        "direction": direction,
        "confidence_pct": confidence,
        "coherence_pct": coherence,
        "tf_alignment": tf_alignment,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "ia_status_v2": ia_status_v2
    }

def post_verdict(verdict):
    """Send verdict to AI Server"""
    try:
        response = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json=verdict,
            timeout=5
        )
        if response.status_code == 200:
            logger.info(f"[LIVE] {verdict['symbol']} -> {verdict['verdict']} ({verdict['confidence_pct']}%)")
            return True
    except Exception as e:
        logger.warning(f"[LIVE] Failed to post {verdict['symbol']}: {e}")
    return False

def run_live_poll():
    """Run one cycle of live polling"""
    logger.info("[LIVE] Starting live verdict generation...")

    fresh_count = 0
    for symbol in SYMBOLS:
        analysis = get_live_analysis(symbol)
        if analysis:
            verdict = calculate_verdict(analysis)
            if verdict and post_verdict(verdict):
                fresh_count += 1

    logger.info(f"[LIVE] Generated {fresh_count}/{len(SYMBOLS)} fresh verdicts")
    return fresh_count

def main():
    logger.info("=" * 80)
    logger.info("GOM LIVE POLLER - Fresh Verdicts Every 5 Minutes")
    logger.info("=" * 80)

    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        # Single execution
        logger.info("[LIVE] Running single poll cycle...")
        run_live_poll()
        logger.info("[LIVE] Poll cycle complete")
    else:
        # Continuous loop every 5 minutes
        import time
        iteration = 0
        while True:
            iteration += 1
            logger.info(f"\n[LIVE] Iteration #{iteration}")
            run_live_poll()
            logger.info("[LIVE] Waiting 5 minutes until next poll...")
            time.sleep(300)  # 5 minutes

if __name__ == "__main__":
    main()
