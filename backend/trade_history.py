import csv
import os
from datetime import datetime
from typing import Dict, List

TRADE_HISTORY_FILE = 'logs/trade_history.csv'
TRADE_HISTORY_FIELDS = [
    'timestamp', 'symbol', 'type', 'volume', 'entry_price', 'exit_price', 'open_time', 'close_time',
    'stop_loss', 'take_profit', 'result', 'confidence', 'reason', 'status'
]

def log_trade(trade: Dict):
    """Ajoute un trade à l'historique (CSV)"""
    os.makedirs(os.path.dirname(TRADE_HISTORY_FILE), exist_ok=True)
    file_exists = os.path.isfile(TRADE_HISTORY_FILE)
    with open(TRADE_HISTORY_FILE, 'a', newline='', encoding='utf-8') as csvfile:
        writer = csv.DictWriter(csvfile, fieldnames=TRADE_HISTORY_FIELDS)
        if not file_exists:
            writer.writeheader()
        # S'assurer que tous les champs sont présents
        row = {k: trade.get(k, '') for k in TRADE_HISTORY_FIELDS}
        writer.writerow(row)

def load_trade_history() -> List[Dict]:
    """Charge l'historique des trades depuis le CSV"""
    if not os.path.isfile(TRADE_HISTORY_FILE):
        return []
    with open(TRADE_HISTORY_FILE, 'r', newline='', encoding='utf-8') as csvfile:
        reader = csv.DictReader(csvfile)
        return list(reader) 