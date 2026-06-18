#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Restore Trade Journal Header — Régénère le CSV avec header correct
et ajoute tous les trades manquants à partir du fichier sans header
"""

import sys
import io
import csv
from pathlib import Path
from datetime import datetime

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

CSV_FILE = Path("D:/Dev/TradBOT/data/trade_journal.csv")
BACKUP_FILE = Path("D:/Dev/TradBOT/data/trade_journal_backup.csv")

FIELDNAMES = [
    'close_time', 'trade_date', 'hour_utc', 'day_of_week',
    'deal_ticket', 'position_id', 'symbol', 'category', 'direction', 'volume',
    'open_time', 'close_time_full', 'open_price', 'close_price',
    'profit', 'swap', 'commission', 'net_profit',
    'duration_sec', 'duration_min', 'result',
    'ai_confidence', 'ai_action', 'balance', 'equity', 'daily_pnl',
    'ea_name', 'magic', 'account', 'comment'
]

def restore_csv():
    """Restaure le CSV en :
    1. Backup du fichier actuel
    2. Lecture des données sans header
    3. Réécriture avec header correct
    """

    print("\n[STEP 1] Backup du fichier actuel...")
    if CSV_FILE.exists() and not BACKUP_FILE.exists():
        import shutil
        shutil.copy(CSV_FILE, BACKUP_FILE)
        print(f"✅ Backup créé: {BACKUP_FILE}")

    # Lire les données sans header
    print("\n[STEP 2] Lecture des données sans header...")
    data_rows = []
    try:
        with open(CSV_FILE, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            for row in reader:
                if len(row) >= 29:  # Vérifier qu'on a assez de colonnes
                    data_rows.append(row)
        print(f"✅ {len(data_rows)} trades lus")
    except Exception as e:
        print(f"❌ Erreur lecture: {e}")
        return False

    # Réécrire avec header
    print("\n[STEP 3] Réécriture avec header correct...")
    try:
        with open(CSV_FILE, 'w', encoding='utf-8', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=FIELDNAMES)
            writer.writeheader()

            for row in data_rows:
                try:
                    record = {
                        FIELDNAMES[i]: row[i] if i < len(row) else ''
                        for i in range(len(FIELDNAMES))
                    }
                    writer.writerow(record)
                except Exception as e:
                    print(f"⚠️  Erreur ligne: {e}")

        print(f"✅ CSV restauré avec {len(data_rows)} trades + header")
    except Exception as e:
        print(f"❌ Erreur écriture: {e}")
        return False

    # Vérifier la restauration
    print("\n[STEP 4] Vérification...")
    try:
        with open(CSV_FILE, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            trades = list(reader)

        symbols = {}
        total_profit = 0
        for trade in trades:
            sym = trade.get('symbol', 'N/A')
            if sym not in symbols:
                symbols[sym] = {'count': 0, 'profit': 0}
            symbols[sym]['count'] += 1
            try:
                profit = float(trade.get('net_profit', 0) or 0)
                symbols[sym]['profit'] += profit
                total_profit += profit
            except:
                pass

        print(f"\n📊 Résumé:")
        print(f"  Total trades: {len(trades)}")
        print(f"  Symboles uniques: {len(symbols)}")
        print(f"  Profit total: ${total_profit:.2f}")
        print(f"\n  Trades par symbole:")
        for sym in sorted(symbols.keys()):
            data = symbols[sym]
            print(f"    {sym:20s} | {data['count']:2d} trades | ${data['profit']:8.2f}")

        return True
    except Exception as e:
        print(f"❌ Erreur vérification: {e}")
        return False

if __name__ == "__main__":
    print("\n" + "="*60)
    print("TRADE JOURNAL CSV HEADER RESTORATION")
    print("="*60)

    success = restore_csv()

    print("\n" + "="*60)
    if success:
        print("✅ CSV restauré avec succès")
        print(f"Fichier: {CSV_FILE}")
        print(f"Backup: {BACKUP_FILE}")
    else:
        print("❌ Restauration échouée")
    print("="*60 + "\n")

