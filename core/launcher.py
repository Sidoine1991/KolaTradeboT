#!/usr/bin/env python3
"""
Point d'entrée pour démarrer le TradBOT Core Engine.
Usage:
    python core/launcher.py                    # Démarrage auto
    python core/launcher.py --phone=+229XXXX   # Avec WhatsApp
    python core/launcher.py --no-trade          # Mode analyse seulement
    python core/launcher.py --interval=30        # Scan toutes les 30s
"""

import os
import sys
import time
import logging
import argparse
from pathlib import Path

# Ajouter la racine au path
_root = Path(__file__).resolve().parent.parent
if str(_root) not in sys.path:
    sys.path.insert(0, str(_root))

from core.engine import TradingEngine, EngineConfig


def setup_logging(level: str = "INFO"):
    logging.basicConfig(
        level=getattr(logging, level.upper(), logging.INFO),
        format="%(asctime)s [%(name)s] %(levelname)s - %(message)s",
        handlers=[
            logging.StreamHandler(sys.stdout),
            logging.FileHandler(_root / "logs" / "core_engine.log", encoding="utf-8"),
        ],
    )


def main():
    parser = argparse.ArgumentParser(description="TradBOT Core Engine")
    parser.add_argument("--phone", type=str, default=os.getenv("WHATSAPP_PHONE", ""),
                       help="WhatsApp phone number for alerts")
    parser.add_argument("--interval", type=float, default=15.0,
                       help="Scan interval in seconds (default: 15)")
    parser.add_argument("--no-trade", action="store_true",
                       help="Analysis only mode (no auto trading)")
    parser.add_argument("--no-pattern", action="store_true",
                       help="Disable pattern alignment requirement")
    parser.add_argument("--min-coherence", type=float, default=70.0,
                       help="Minimum GOM coherence (default: 70%)")
    parser.add_argument("--min-strength", type=float, default=0.5,
                       help="Minimum signal strength (default: 0.5)")
    parser.add_argument("--log-level", type=str, default="INFO",
                       help="Log level (DEBUG, INFO, WARNING, ERROR)")

    args = parser.parse_args()
    setup_logging(args.log_level)

    logger = logging.getLogger("tradbot.launcher")
    logger.info("=" * 60)
    logger.info("TradBOT Core Engine v1.0.0")
    logger.info("=" * 60)

    config = EngineConfig(
        scan_interval=args.interval,
        gom_min_coherence=args.min_coherence,
        require_pattern_alignment=not args.no_pattern,
        enable_auto_trade=not args.no_trade,
        min_signal_strength=args.min_strength,
    )

    engine = TradingEngine(phone=args.phone, config=config)
    engine.start()

    logger.info(f"Config:")
    logger.info(f"  Interval: {config.scan_interval}s")
    logger.info(f"  GOM min coherence: {config.gom_min_coherence}%")
    logger.info(f"  Patterns required: {config.require_pattern_alignment}")
    logger.info(f"  Auto trade: {config.enable_auto_trade}")
    logger.info(f"  Min signal strength: {config.min_signal_strength}")
    if args.phone:
        logger.info(f"  WhatsApp: {args.phone}")

    try:
        while True:
            time.sleep(30)
            status = engine.get_status()
            positions = len(status.get("active_positions", []))
            signals = len(status.get("active_signals", []))
            risk = status.get("risk", {})
            logger.info(
                f"Status: {positions} positions | "
                f"{signals} signaux | "
                f"PnL {risk.get('daily_pnl', 0):+.2f}$ | "
                f"Risk {risk.get('risk_level', '?')}"
            )
    except KeyboardInterrupt:
        logger.info("Arrêt demandé...")
        engine.stop()
        logger.info("Engine arrêté.")
        return 0


if __name__ == "__main__":
    sys.exit(main())
