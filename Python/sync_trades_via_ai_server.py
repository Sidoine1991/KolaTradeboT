#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Sync Trades via AI Server — Récupère l'historique des trades depuis MT5
via l'AI server qui a accès aux données MT5 (HistorySelect)
"""

import requests
import csv
import json
from pathlib import Path
from datetime import datetime, timezone, timedelta
import logging

# Configuration
AI_SERVER = "http://127.0.0.1:8000"
CSV_FILE = Path("D:/Dev/TradBOT/data/trade_journal.csv")
LOGS_DIR = Path("D:/Dev/TradBOT/logs")

# Setup logging
LOGS_DIR.mkdir(exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - sync_trades_ai - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOGS_DIR / "sync_trades_ai_server.log", encoding='utf-8', mode='a')
    ]
)
logger = logging.getLogger(__name__)

def get_trades_from_ai_server(days_back=30):
    """Récupère l'historique des trades depuis l'AI server"""
    try:
        # L'AI server peut exposer un endpoint /trade-history ou /trade-export
        # qui utilise HistorySelect() et retourne les données
        url = f"{AI_SERVER}/trade-history"
        params = {
            "days_back": days_back,
            "format": "json"
        }

        logger.info(f"Requesting trades from {url} for {days_back} days...")
        response = requests.get(url, params=params, timeout=10)

        if response.status_code == 200:
            data = response.json()
            trades = data.get("trades", [])
            logger.info(f"✅ Retrieved {len(trades)} trades from AI server")
            return trades
        else:
            logger.warning(f"AI server returned {response.status_code}")
            return []

    except requests.exceptions.ConnectionError:
        logger.warning(f"AI server not available at {AI_SERVER}")
        return []
    except Exception as e:
        logger.error(f"Error getting trades from AI server: {e}")
        return []

def write_trades_to_csv(trades):
    """Écrit les trades dans le CSV"""
    if not trades:
        logger.warning("No trades to write")
        return 0

    # Lire les trades existants
    existing_tickets = set()
    if CSV_FILE.exists():
        try:
            with open(CSV_FILE, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row.get('deal_ticket'):
                        existing_tickets.add(row['deal_ticket'])
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
                deal_ticket = str(trade.get('deal_ticket', ''))
                if deal_ticket in existing_tickets:
                    continue

                try:
                    close_time = trade.get('close_time', datetime.now(timezone.utc).isoformat())
                    if isinstance(close_time, str):
                        close_dt = datetime.fromisoformat(close_time.replace('Z', '+00:00'))
                    else:
                        close_dt = datetime.now(timezone.utc)

                    row = {
                        'close_time': close_dt.strftime('%Y-%m-%d %H:%M:%S'),
                        'trade_date': close_dt.strftime('%Y-%m-%d'),
                        'hour_utc': close_dt.hour,
                        'day_of_week': close_dt.strftime('%a'),
                        'deal_ticket': deal_ticket,
                        'position_id': trade.get('position_id', deal_ticket),
                        'symbol': trade.get('symbol', ''),
                        'category': trade.get('category', 'UNKNOWN'),
                        'direction': trade.get('direction', '').upper(),
                        'volume': float(trade.get('volume', 0)) if trade.get('volume') else 0,
                        'open_time': trade.get('open_time', close_dt.strftime('%Y-%m-%d %H:%M:%S')),
                        'close_time_full': close_dt.strftime('%Y-%m-%d %H:%M:%S'),
                        'open_price': float(trade.get('open_price', 0)) if trade.get('open_price') else 0,
                        'close_price': float(trade.get('close_price', 0)) if trade.get('close_price') else 0,
                        'profit': float(trade.get('profit', 0)) if trade.get('profit') else 0,
                        'swap': float(trade.get('swap', 0)) if trade.get('swap') else 0,
                        'commission': float(trade.get('commission', 0)) if trade.get('commission') else 0,
                        'net_profit': float(trade.get('net_profit', 0)) if trade.get('net_profit') else 0,
                        'duration_sec': int(trade.get('duration_sec', 0)) if trade.get('duration_sec') else 0,
                        'duration_min': float(trade.get('duration_min', 0)) if trade.get('duration_min') else 0,
                        'result': trade.get('result', 'BE'),
                        'ai_confidence': float(trade.get('ai_confidence', 0)) if trade.get('ai_confidence') else 0,
                        'ai_action': trade.get('ai_action', ''),
                        'balance': float(trade.get('balance', 0)) if trade.get('balance') else 0,
                        'equity': float(trade.get('equity', 0)) if trade.get('equity') else 0,
                        'daily_pnl': float(trade.get('daily_pnl', 0)) if trade.get('daily_pnl') else 0,
                        'ea_name': trade.get('ea_name', 'SMC_Universal'),
                        'magic': int(trade.get('magic', 0)) if trade.get('magic') else 0,
                        'account': int(trade.get('account', 0)) if trade.get('account') else 0,
                        'comment': trade.get('comment', '')
                    }
                    writer.writerow(row)
                    written += 1
                except Exception as e:
                    logger.error(f"Error writing trade {deal_ticket}: {e}")

    except Exception as e:
        logger.error(f"Error writing CSV: {e}")

    return written

def main():
    """Exécution principale"""
    logger.info("=" * 60)
    logger.info("Starting Trade Sync via AI Server")

    # Récupérer les trades depuis AI server
    trades = get_trades_from_ai_server(days_back=30)

    # Écrire dans le CSV
    written = write_trades_to_csv(trades)
    logger.info(f"✅ Wrote {written} new trades to CSV")

    logger.info("✅ Sync complete")
    logger.info("=" * 60)

if __name__ == "__main__":
    main()
