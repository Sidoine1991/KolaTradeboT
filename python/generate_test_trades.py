#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate Test Trades — Crée des données de test dans le CSV
pour pouvoir tester le système complet sans attendre les vrais trades
"""

import sys
import io
import csv
from pathlib import Path
from datetime import datetime, timezone, timedelta
import random

# Force UTF-8
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

CSV_FILE = Path("D:/Dev/TradBOT/data/trade_journal.csv")

def generate_test_trades(count=20):
    """Génère des trades de test"""
    trades = []
    now = datetime.now(timezone.utc)
    symbols = ["XAUUSD", "BOOM 500 INDEX", "CRASH 500 INDEX", "BTCUSD", "ETHUSD"]

    for i in range(count):
        entry_price = random.uniform(100, 10000)
        close_price = entry_price + random.uniform(-50, 50)
        volume = random.choice([0.01, 0.05, 0.10, 0.20])
        profit = (close_price - entry_price) * volume

        trade_time = now - timedelta(hours=random.randint(1, 72))

        trades.append({
            'close_time': trade_time.strftime('%Y-%m-%d %H:%M:%S'),
            'trade_date': trade_time.strftime('%Y-%m-%d'),
            'hour_utc': trade_time.hour,
            'day_of_week': trade_time.strftime('%a'),
            'deal_ticket': 5569230000 + i,
            'position_id': 5569230000 + i,
            'symbol': random.choice(symbols),
            'category': random.choice(['METAL', 'BOOM_CRASH', 'CRYPTO', 'FOREX']),
            'direction': random.choice(['BUY', 'SELL']),
            'volume': f"{volume:.2f}",
            'open_time': (trade_time - timedelta(minutes=random.randint(5, 120))).strftime('%Y-%m-%d %H:%M:%S'),
            'close_time_full': trade_time.strftime('%Y-%m-%d %H:%M:%S'),
            'open_price': f"{entry_price:.2f}",
            'close_price': f"{close_price:.2f}",
            'profit': f"{profit:.2f}",
            'swap': f"{random.uniform(-1, 1):.2f}",
            'commission': f"{random.uniform(-2, 0):.2f}",
            'net_profit': f"{profit + random.uniform(-2, 1):.2f}",
            'duration_sec': random.randint(300, 7200),
            'duration_min': f"{random.randint(5, 120):.1f}",
            'result': 'WIN' if profit > 0 else ('LOSS' if profit < 0 else 'BE'),
            'ai_confidence': f"{random.uniform(50, 95):.1f}",
            'ai_action': random.choice(['buy', 'sell', 'hold']),
            'balance': f"{random.uniform(50000, 100000):.2f}",
            'equity': f"{random.uniform(50000, 105000):.2f}",
            'daily_pnl': f"{random.uniform(-500, 1000):.2f}",
            'ea_name': 'SMC_Universal',
            'magic': 123456,
            'account': 12345678,
            'comment': f'Test trade #{i+1}'
        })

    return trades

def write_test_trades():
    """Écrit les trades de test dans le CSV"""
    trades = generate_test_trades(20)

    fieldnames = [
        'close_time', 'trade_date', 'hour_utc', 'day_of_week',
        'deal_ticket', 'position_id', 'symbol', 'category', 'direction', 'volume',
        'open_time', 'close_time_full', 'open_price', 'close_price',
        'profit', 'swap', 'commission', 'net_profit',
        'duration_sec', 'duration_min', 'result',
        'ai_confidence', 'ai_action', 'balance', 'equity', 'daily_pnl',
        'ea_name', 'magic', 'account', 'comment'
    ]

    # Lire l'existant (pour éviter les doublons)
    existing = set()
    if CSV_FILE.exists():
        try:
            with open(CSV_FILE, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row.get('deal_ticket'):
                        existing.add(row['deal_ticket'])
        except:
            pass

    # Écrire les nouveaux trades
    written = 0
    with open(CSV_FILE, 'a', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)

        for trade in trades:
            ticket = str(trade['deal_ticket'])
            if ticket not in existing:
                writer.writerow(trade)
                written += 1

    return written

if __name__ == "__main__":
    print("\n" + "="*60)
    print("GENERATING TEST TRADES")
    print("="*60 + "\n")

    written = write_test_trades()
    print(f"✅ Generated {written} test trades\n")

    print(f"CSV: {CSV_FILE}")
    print(f"Trades: {written}")
    print("\nNow run: python Python/trade_journal_processor.py\n")
