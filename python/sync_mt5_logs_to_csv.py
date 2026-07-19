#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sync MT5 Logs to CSV — Extrait les trades fermés depuis les logs MT5
et les exporte dans le CSV trade_journal
"""

import re
import csv
from pathlib import Path
from datetime import datetime, timezone
import logging

# Configuration
MT5_LOGS_DIR = Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\logs")
CSV_FILE = Path("D:/Dev/TradBOT/data/trade_journal.csv")
LOGS_DIR = Path("D:/Dev/TradBOT/logs")

# Setup logging
LOGS_DIR.mkdir(exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - sync_logs - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOGS_DIR / "sync_mt5_logs.log", encoding='utf-8', mode='a')
    ]
)
logger = logging.getLogger(__name__)

# Regex pour extraire les deals fermés des logs
# Format: "deal # 5569239183 sell 0.04 XAUUSD at 4313.30 done"
DEAL_PATTERN = re.compile(
    r'deal\s+#(\d+)\s+(buy|sell)\s+([\d.]+)\s+([A-Z0-9\s]+?)\s+at\s+([\d.]+)\s+done'
)

# Regex pour les clôtures (close order)
# Format: "market sell 0.04 XAUUSD, close # 5688142034 buy 0.04 XAUUSD 4314.89"
CLOSE_PATTERN = re.compile(
    r'market\s+(buy|sell)\s+([\d.]+)\s+([A-Z0-9\s]+?),\s+close\s+#(\d+)\s+(buy|sell)\s+([\d.]+)\s+([A-Z0-9\s]+?)\s+([\d.]+)'
)

def read_log_files():
    """Lit tous les fichiers de logs MT5"""
    if not MT5_LOGS_DIR.exists():
        logger.error(f"MT5 logs directory not found: {MT5_LOGS_DIR}")
        return []

    log_files = sorted(MT5_LOGS_DIR.glob("2026*.log"), reverse=True)
    logger.info(f"Found {len(log_files)} log files")

    trades = []
    for log_file in log_files:
        logger.info(f"Reading: {log_file.name}")
        try:
            # MT5 logs are UTF-16
            with open(log_file, 'r', encoding='utf-16', errors='ignore') as f:
                content = f.read()

            # Extraire tous les deals
            deals = DEAL_PATTERN.findall(content)
            closes = CLOSE_PATTERN.findall(content)

            logger.info(f"  Found {len(deals)} deals, {len(closes)} closes")
            trades.extend((deals, closes, log_file.name))

        except Exception as e:
            logger.error(f"Error reading {log_file.name}: {e}")

    return trades

def parse_deals_and_closes(all_data):
    """Apparie les deals d'ouverture avec les clôtures"""
    trades = []

    # Groupe par magique/account (on va supposer un seul account pour simplifier)
    open_deals = {}  # order_id → deal info
    close_info = {}  # deal_id → close info

    if not isinstance(all_data, list) or len(all_data) < 3:
        return trades

    deals = all_data[0]
    closes = all_data[1]
    log_name = all_data[2]

    # Parser les deals d'ouverture
    for deal in deals:
        deal_id, direction, volume, symbol, price = deal
        open_deals[deal_id] = {
            'direction': direction.upper(),
            'volume': float(volume),
            'symbol': symbol.strip(),
            'open_price': float(price),
        }

    # Parser les clôtures
    for close in closes:
        close_dir, close_vol, close_sym, open_order_id, open_dir, open_vol, open_sym, close_price = close
        close_info[open_order_id] = {
            'close_direction': close_dir.upper(),
            'close_volume': float(close_vol),
            'close_price': float(close_price),
        }

    # Appairer ouvertures avec clôtures
    for order_id, close in close_info.items():
        if order_id in open_deals:
            trade = {
                **open_deals[order_id],
                **close,
                'deal_id': order_id,
                'log_file': log_name,
            }
            trades.append(trade)

    return trades

def write_to_csv(trades):
    """Écrit les trades dans le CSV"""
    if not trades:
        logger.warning("No trades to write")
        return 0

    # Lire les deals existants pour éviter les doublons
    existing_deals = set()
    if CSV_FILE.exists():
        try:
            with open(CSV_FILE, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row.get('deal_ticket'):
                        existing_deals.add(row['deal_ticket'])
        except Exception as e:
            logger.warning(f"Error reading existing CSV: {e}")

    # Écrire les nouveaux trades
    written = 0
    try:
        with open(CSV_FILE, 'a', encoding='utf-8', newline='') as f:
            fieldnames = [
                'close_time', 'trade_date', 'hour_utc', 'day_of_week',
                'deal_ticket', 'position_id', 'symbol', 'category', 'direction', 'volume',
                'open_time', 'close_time_full', 'open_price', 'close_price',
                'profit', 'swap', 'commission', 'net_profit',
                'duration_sec', 'duration_min', 'result',
                'ai_confidence', 'ai_action', 'balance', 'equity', 'daily_pnl',
                'ea_name', 'magic', 'account', 'comment'
            ]
            writer = csv.DictWriter(f, fieldnames=fieldnames)

            for trade in trades:
                deal_id = str(trade.get('deal_id', ''))
                if deal_id in existing_deals:
                    continue  # Skip duplicates

                now = datetime.now(timezone.utc)
                row = {
                    'close_time': now.strftime('%Y-%m-%d %H:%M:%S'),
                    'trade_date': now.strftime('%Y-%m-%d'),
                    'hour_utc': now.hour,
                    'day_of_week': now.strftime('%a'),
                    'deal_ticket': deal_id,
                    'position_id': deal_id,  # Use deal_id as position_id
                    'symbol': trade.get('symbol', ''),
                    'category': 'UNKNOWN',  # Would need to determine from symbol
                    'direction': trade.get('direction', ''),
                    'volume': trade.get('volume', 0),
                    'open_time': now.strftime('%Y-%m-%d %H:%M:%S'),
                    'close_time_full': now.strftime('%Y-%m-%d %H:%M:%S'),
                    'open_price': trade.get('open_price', 0),
                    'close_price': trade.get('close_price', 0),
                    'profit': (trade.get('close_price', 0) - trade.get('open_price', 0)) * trade.get('volume', 0),
                    'swap': 0,
                    'commission': 0,
                    'net_profit': (trade.get('close_price', 0) - trade.get('open_price', 0)) * trade.get('volume', 0),
                    'duration_sec': 0,
                    'duration_min': 0,
                    'result': 'WIN' if (trade.get('close_price', 0) - trade.get('open_price', 0)) > 0 else ('LOSS' if (trade.get('close_price', 0) - trade.get('open_price', 0)) < 0 else 'BE'),
                    'ai_confidence': 0,
                    'ai_action': '',
                    'balance': 0,
                    'equity': 0,
                    'daily_pnl': (trade.get('close_price', 0) - trade.get('open_price', 0)) * trade.get('volume', 0),
                    'ea_name': 'SMC_Universal',
                    'magic': 123456,
                    'account': 0,
                    'comment': f"From {trade.get('log_file', '')}"
                }
                writer.writerow(row)
                written += 1

    except Exception as e:
        logger.error(f"Error writing CSV: {e}")

    return written

def main():
    """Exécution principale"""
    logger.info("=" * 60)
    logger.info("Starting MT5 Logs Sync")

    # Lire les logs
    all_data = read_log_files()

    if not all_data:
        logger.warning("No log data found")
        logger.info("=" * 60)
        return

    # Parser les deals
    trades = parse_deals_and_closes(all_data)
    logger.info(f"Parsed {len(trades)} complete trades (open + close pairs)")

    # Écrire dans le CSV
    written = write_to_csv(trades)
    logger.info(f"✅ Wrote {written} new trades to CSV")

    logger.info("✅ Sync complete")
    logger.info("=" * 60)

if __name__ == "__main__":
    main()
