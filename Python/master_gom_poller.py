#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Master GOM Poller - Collecte pour TOUS les symbols avec TradeManager attaché
Lance une seule instance qui boucle sur tous les symbols
"""

import sys
import time
import logging
import argparse
import json
import requests
from datetime import datetime
from pathlib import Path

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [GOM-Master] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)
logger = logging.getLogger("GOM-Master")

# Configuration par défaut
DEFAULT_SYMBOLS = ["XAUUSD", "EURUSD", "GBPUSD"]
DEFAULT_INTERVAL = 30  # secondes
AI_SERVER = "http://127.0.0.1:8000"


def get_active_symbols():
    """
    Retourne les Top 3 symbols du scan matinal
    Lit le rapport de scan le plus récent et extrait les 3 symbols
    """
    try:
        from docx import Document

        scan_dir = Path("D:/Dev/TradBOT/reports/morning_scan")
        if not scan_dir.exists():
            logger.warning("Scan directory not found, using defaults")
            return DEFAULT_SYMBOLS

        # Récupérer le fichier de scan le plus récent
        reports = sorted(scan_dir.glob("*.docx"), key=lambda p: p.stat().st_mtime, reverse=True)
        if not reports:
            logger.warning("No scan reports found, using defaults")
            return DEFAULT_SYMBOLS

        latest_scan = reports[0]
        logger.info(f"📄 Loading Top 3 symbols from: {latest_scan.name}")

        # Extraire les symbols du rapport
        doc = Document(latest_scan)
        symbols = []

        for para in doc.paragraphs:
            text = para.text.strip()
            for sym in ["XAUUSD", "EURUSD", "GBPUSD", "BTCUSD", "AUDUSD", "NZDUSD", "USDJPY", "GBPJPY"]:
                if sym in text and sym not in symbols:
                    symbols.append(sym)
                    if len(symbols) >= 3:
                        break
            if len(symbols) >= 3:
                break

        if symbols:
            logger.info(f"✅ Top 3 symbols from scan: {symbols[:3]}")
            return symbols[:3]
        else:
            logger.warning("No symbols found in scan report, using defaults")
            return DEFAULT_SYMBOLS

    except ImportError:
        logger.warning("python-docx not installed, using defaults")
        return DEFAULT_SYMBOLS
    except Exception as e:
        logger.warning(f"Error reading scan report: {e}, using defaults")
        return DEFAULT_SYMBOLS


def collect_gom_data(symbol):
    """Collecte les données GOM pour un symbol via TradingView MCP"""
    try:
        # Appeler le poller existant pour chaque symbol
        # Ou faire l'appel MCP directement ici
        logger.info(f"Collecting GOM data for {symbol}...")

        # Pour l'instant, retourner des données stub
        # À l'avenir : appel MCP réel
        return {
            "symbol": symbol,
            "pred_path": "U" * 200,
            "atr": 15.32,
            "verdict": "WAIT",
            "timestamp": datetime.utcnow().isoformat()
        }
    except Exception as e:
        logger.error(f"Error collecting {symbol}: {e}")
        return None


def push_to_ai_server(symbol, gom_data, retries: int = 3, retry_delay: int = 5):
    """Push les données vers l'AI server avec retry automatique"""
    for attempt in range(1, retries + 1):
        try:
            # L'AI server récupère déjà les données via MCP
            # Ici on valide que les données sont disponibles
            resp = requests.get(
                f"{AI_SERVER}/gom-kola-dashboard?symbol={symbol}",
                timeout=20,
                verify=False
            )

            if resp.status_code == 200:
                data = resp.json()
                if data.get("ok") and data.get("pred_path"):
                    logger.info(f"✅ {symbol}: pred_path available ({len(data['pred_path'])} chars), ATR={data.get('atr', 'N/A')}")
                    return True
                else:
                    logger.warning(f"⚠️ {symbol}: Data incomplete")
                    return False
            else:
                logger.warning(f"⚠️ {symbol}: HTTP {resp.status_code}")
                return False

        except requests.exceptions.Timeout:
            if attempt < retries:
                logger.warning(f"⏱️ {symbol}: Timeout (attempt {attempt}/{retries}), retrying in {retry_delay}s...")
                time.sleep(retry_delay)
            else:
                logger.error(f"❌ {symbol}: Timeout after {retries} attempts")
                return False
        except requests.exceptions.ConnectionError as e:
            if attempt < retries:
                logger.warning(f"🔌 {symbol}: Connection error (attempt {attempt}/{retries}), retrying in {retry_delay}s...")
                time.sleep(retry_delay)
            else:
                logger.error(f"❌ {symbol}: Connection error after {retries} attempts: {e}")
                return False
        except Exception as e:
            logger.error(f"❌ {symbol}: Unexpected error: {e}")
            return False

    return False


def run_master_poller(symbols, interval):
    """Boucle principale - collecte pour tous les symbols"""
    logger.info(f"🚀 Master GOM Poller started")
    logger.info(f"   Symbols: {', '.join(symbols)}")
    logger.info(f"   Interval: {interval}s")
    logger.info(f"   AI Server: {AI_SERVER}")
    logger.info(f"   Flux: TradingView MCP → AI Server → TradeManager MT5")
    logger.info("")

    cycle = 0

    while True:
        try:
            cycle += 1
            logger.info(f"[Cycle {cycle}] Starting data collection...")

            success_count = 0
            total_count = len(symbols)

            # Collecter pour tous les symbols
            for symbol in symbols:
                try:
                    if push_to_ai_server(symbol, None, retries=3, retry_delay=5):
                        success_count += 1
                except Exception as e:
                    logger.error(f"🚨 Unhandled error for {symbol}: {e}")
                time.sleep(2)  # Petit délai entre les appels

            # Résumé du cycle
            logger.info(f"[Cycle {cycle}] Complete: {success_count}/{total_count} symbols OK")
            logger.info(f"[Cycle {cycle}] Next cycle in {interval}s...")
            logger.info("")

            time.sleep(interval)

        except KeyboardInterrupt:
            logger.info("⏹️ Master poller stopped by user")
            sys.exit(0)
        except Exception as e:
            logger.error(f"🚨 Fatal error in cycle: {e}, restarting in 10s...")
            time.sleep(10)


def main():
    parser = argparse.ArgumentParser(description="Master GOM Poller for multiple symbols")
    parser.add_argument("--symbols", type=str, default=None,
                       help="Override symbols (comma-separated). If not provided, loads from morning scan")
    parser.add_argument("--interval", type=int, default=DEFAULT_INTERVAL,
                       help=f"Collection interval in seconds (default: {DEFAULT_INTERVAL})")
    parser.add_argument("--once", action="store_true",
                       help="Run once and exit")

    args = parser.parse_args()

    # Parse symbols - si fournis en argument, utilise-les; sinon, lis le scan
    if args.symbols:
        symbols = [s.strip() for s in args.symbols.split(",")]
        logger.info(f"Using override symbols: {symbols}")
    else:
        symbols = get_active_symbols()  # Charge depuis le scan matinal

    logger.info("=" * 70)
    logger.info("MASTER GOM POLLER")
    logger.info("=" * 70)

    if args.once:
        logger.info("Running once mode...")
        for symbol in symbols:
            try:
                push_to_ai_server(symbol, None, retries=3, retry_delay=5)
            except Exception as e:
                logger.error(f"Error in once mode for {symbol}: {e}")
            time.sleep(2)
    else:
        run_master_poller(symbols, args.interval)


if __name__ == "__main__":
    main()
