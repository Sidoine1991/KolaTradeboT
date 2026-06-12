#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM TradingView Sync - Generate Fresh Verdicts from Real-Time TradingView Data
Pulls live prices, indicators, and technical analysis from TradingView
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
        logging.FileHandler(log_dir / "gom_tv_sync.log"),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# TradingView MCP Server
TV_MCP_URL = os.getenv("TV_MCP_URL", "http://localhost:9001")
AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://localhost:8000")

SYMBOLS_TO_ANALYZE = [
    "XAUUSD", "EURUSD", "GBPUSD", "USDJPY",
    "BOOM 500 INDEX", "BOOM 1000 INDEX", "CRASH 500 INDEX", "CRASH 1000 INDEX",
    "BTC/USD", "ETH/USD"
]

def get_tv_live_data(symbol):
    """Fetch live TradingView data for symbol"""
    try:
        response = requests.post(
            f"{TV_MCP_URL}/api/data",
            json={"symbol": symbol, "resolution": "5"},
            timeout=5
        )
        if response.status_code == 200:
            return response.json()
    except Exception as e:
        logger.debug(f"TradingView data fetch failed for {symbol}: {e}")
    return None

def analyze_tv_data(symbol, tv_data):
    """Analyze TradingView data and generate verdict"""
    if not tv_data:
        return None

    # Extract key metrics
    close = tv_data.get("close", 0)
    rsi = tv_data.get("rsi", 50)
    macd = tv_data.get("macd", 0)
    bb_upper = tv_data.get("bb_upper", close)
    bb_lower = tv_data.get("bb_lower", close)

    # Simple verdict logic based on technicals
    verdict = "WAIT"
    direction = "NEUT"
    confidence = 50

    # RSI-based signals
    if rsi > 70:
        verdict = "WEAK SELL"
        direction = "SELL"
        confidence = 65
    elif rsi < 30:
        verdict = "WEAK BUY"
        direction = "BUY"
        confidence = 65
    elif rsi > 60:
        direction = "BUY"
        confidence = 60
    elif rsi < 40:
        direction = "SELL"
        confidence = 60

    # MACD confirmation
    if macd > 0 and direction == "BUY":
        confidence = min(95, confidence + 20)
        if confidence > 80:
            verdict = "PERFECT BUY" if confidence > 85 else "GOOD BUY"
    elif macd < 0 and direction == "SELL":
        confidence = min(95, confidence + 20)
        if confidence > 80:
            verdict = "PERFECT SELL" if confidence > 85 else "GOOD SELL"

    return {
        "symbol": symbol,
        "verdict": verdict,
        "direction": direction,
        "confidence_pct": confidence,
        "coherence_pct": confidence,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "source": "TradingView_Live",
        "rsi": rsi,
        "macd": macd,
        "close": close
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
            symbol = verdict.get("symbol", "?")
            v = verdict.get("verdict", "?")
            conf = verdict.get("confidence_pct", 0)
            logger.info(f"[TV] {symbol}: {v} ({conf}%) - Posted OK")
            return True
    except Exception as e:
        logger.warning(f"Failed to post verdict: {e}")
    return False

def run_tv_sync():
    """Run TradingView sync cycle"""
    logger.info("[TV] Starting TradingView data sync...")

    success_count = 0
    for symbol in SYMBOLS_TO_ANALYZE:
        tv_data = get_tv_live_data(symbol)
        if tv_data:
            verdict = analyze_tv_data(symbol, tv_data)
            if verdict and post_verdict(verdict):
                success_count += 1

    logger.info(f"[TV] Synced {success_count}/{len(SYMBOLS_TO_ANALYZE)} symbols from TradingView")
    return success_count

def main():
    logger.info("=" * 80)
    logger.info("GOM TradingView Sync - Fresh Live Verdicts")
    logger.info("=" * 80)

    if len(sys.argv) > 1 and sys.argv[1] == "--once":
        logger.info("[TV] Running single sync cycle...")
        run_tv_sync()
        logger.info("[TV] Sync complete")
    else:
        import time
        iteration = 0
        while True:
            iteration += 1
            logger.info(f"\n[TV] Iteration #{iteration}")
            run_tv_sync()
            logger.info("[TV] Waiting 5 minutes until next sync...")
            time.sleep(300)

if __name__ == "__main__":
    main()
