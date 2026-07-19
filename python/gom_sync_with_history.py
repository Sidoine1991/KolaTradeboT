#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Sync + Trade History — Charge les verdicts GOM + historique complet des trades
Récupère TOUS les symboles et TOUTES les dates, pas seulement les verdicts actuels
"""

import json
import time
import os
import sys
import requests
import logging
from datetime import datetime, timezone, timedelta
from pathlib import Path

# Force UTF-8 on Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Configuration
AI_SERVER = "http://127.0.0.1:8000"
LOGS_DIR = Path("D:/Dev/TradBOT/logs")
LOOP_INTERVAL = 600  # 10 minutes

LOGS_DIR.mkdir(exist_ok=True)

# Setup logging
log_file = LOGS_DIR / "gom_sync_history.log"
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - gom_history - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8', mode='a')
    ]
)
logger = logging.getLogger(__name__)

# Console handler
class NoEmojiHandler(logging.StreamHandler):
    def emit(self, record):
        msg = record.getMessage()
        msg = msg.replace('🔄', '[SYNC]').replace('✅', '[OK]').replace('❌', '[ERROR]')
        ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"{ts} - {record.levelname} - {msg}")

logger.addHandler(NoEmojiHandler())

def get_all_verdicts():
    """Récupère TOUS les verdicts: actuels + historique"""
    verdicts = []

    # 1. Récupérer les verdicts actuels
    try:
        r = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=10)
        if r.status_code == 200:
            data = r.json()
            current_verdicts = data.get("verdicts", data) if isinstance(data, dict) else data
            if isinstance(current_verdicts, list):
                verdicts.extend(current_verdicts)
                logger.info(f"[OK] Loaded {len(current_verdicts)} current verdicts from server")
    except Exception as e:
        logger.warning(f"[WARN] Error fetching current verdicts: {e}")

    # 2. Récupérer l'historique complet
    try:
        r = requests.get(f"{AI_SERVER}/trade-history?days_back=30", timeout=10)
        if r.status_code == 200:
            data = r.json()
            history_trades = data.get("trades", [])

            # Convertir les trades en format verdict
            for trade in history_trades:
                verdict = {
                    "symbol": trade.get("symbol", ""),
                    "verdict": "CLOSED",  # Mark as historical
                    "verdict_num": 0,
                    "entry": trade.get("open_price", 0),
                    "close_price": trade.get("close_price", 0),
                    "profit": trade.get("net_profit", 0),
                    "sl": trade.get("sl", 0),
                    "tp": trade.get("tp", 0),
                    "direction": trade.get("direction", ""),
                    "timestamp": trade.get("close_time", ""),
                    "is_historical": True
                }
                verdicts.append(verdict)

            logger.info(f"[OK] Loaded {len(history_trades)} historical trades from server")
    except Exception as e:
        logger.warning(f"[WARN] Error fetching trade history: {e}")

    return verdicts

def build_report(verdicts):
    """Construit un rapport avec les verdicts + historique"""
    if not verdicts:
        logger.warning("No verdicts found")
        return None

    lines = []
    lines.append("🎯 **GOM VERDICTS + TRADE HISTORY REPORT**")
    lines.append("=" * 60)
    lines.append(f"\nTotal Verdicts: {len(verdicts)}")

    # Grouper par symbole
    by_symbol = {}
    for v in verdicts:
        sym = v.get("symbol", "N/A")
        if sym not in by_symbol:
            by_symbol[sym] = []
        by_symbol[sym].append(v)

    lines.append(f"Unique Symbols: {len(by_symbol)}\n")

    # Afficher un résumé par symbole
    for sym in sorted(by_symbol.keys()):
        items = by_symbol[sym]
        wins = sum(1 for v in items if v.get("profit", 0) > 0)
        losses = sum(1 for v in items if v.get("profit", 0) < 0)
        total_profit = sum(v.get("profit", 0) for v in items)

        lines.append(f"{sym:20s} | Trades: {len(items):2d} | Wins: {wins:2d} | Losses: {losses:2d} | Profit: ${total_profit:8.2f}")

    lines.append("=" * 60)
    lines.append(f"Generated: {datetime.now(timezone.utc).isoformat()}")

    report = "\n".join(lines)
    logger.info(f"\n[LOG] RAPPORT:\n{report}")
    return report

def main():
    """Main execution"""
    logger.info("=" * 60)
    logger.info("Starting GOM Sync + Trade History")

    # Get all verdicts (current + historical)
    verdicts = get_all_verdicts()
    logger.info(f"[OK] Total verdicts/trades: {len(verdicts)}")

    # Build and display report
    report = build_report(verdicts)

    if report:
        logger.info(f"[OK] Report generated with {len(verdicts)} items")
    else:
        logger.warning("[WARN] No report generated")

    logger.info("=" * 60)

if __name__ == "__main__":
    main()
