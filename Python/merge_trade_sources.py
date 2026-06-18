#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Merge Trade Sources — Fusionne CSV validé (20) + MT5 logs (1120)
Stratégie: Les 20 validated sont prioritaires, MT5 ajoute les trades manquants
Résultat: SQLite unifié + CSV fusionné
"""

import sys
import io
import csv
import sqlite3
from pathlib import Path
from collections import defaultdict

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

VALIDATED_CSV = Path("D:/Dev/TradBOT/data/trade_journal.csv")  # 20 trades
MT5_CSV = Path("D:/Dev/TradBOT/data/trade_journal_complete.csv")  # 1120 trades
MERGED_CSV = Path("D:/Dev/TradBOT/data/trade_journal_merged.csv")
DB_FILE = Path("D:/Dev/TradBOT/data/trades_merged.db")
DB_FILE.parent.mkdir(exist_ok=True)

def read_csv_to_dict(csv_path: Path) -> dict:
    """Lit le CSV et retourne un dict par deal_ticket"""
    trades = {}
    try:
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            if not reader:
                return trades

            for row in reader:
                deal_ticket = row.get('deal_ticket', '').strip()
                if deal_ticket:
                    trades[deal_ticket] = row
    except Exception as e:
        print(f"⚠️  Error reading {csv_path}: {e}")

    return trades

def merge_trades():
    """Fusionne les deux sources"""
    print("\n" + "="*70)
    print("MERGING TRADE SOURCES")
    print("="*70 + "\n")

    # Lire les deux sources
    validated = read_csv_to_dict(VALIDATED_CSV)
    mt5_trades = read_csv_to_dict(MT5_CSV)

    print(f"✅ Validated trades (repo):  {len(validated)}")
    print(f"✅ MT5 trades (logs):        {len(mt5_trades)}")

    # Fusionner (validated en priorité)
    merged = {}

    # Ajouter d'abord les trades validés (source fiable)
    merged.update(validated)
    print(f"\n✅ Added {len(validated)} validated trades (priority)")

    # Ajouter les trades MT5 qui ne sont pas dans validated
    new_from_mt5 = 0
    for ticket, trade in mt5_trades.items():
        if ticket not in merged:
            merged[ticket] = trade
            new_from_mt5 += 1

    print(f"✅ Added {new_from_mt5} new trades from MT5 logs")
    print(f"\n📊 Total merged: {len(merged)} trades")

    # Écrire le CSV fusionné
    if merged and validated:
        # Utiliser les headers du CSV validé
        with open(VALIDATED_CSV, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            headers = reader.fieldnames
    else:
        headers = list(next(iter(merged.values())).keys()) if merged else []

    with open(MERGED_CSV, 'w', encoding='utf-8', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=headers)
        writer.writeheader()

        for ticket in sorted(merged.keys(), key=lambda x: int(x) if x.isdigit() else 0):
            writer.writerow(merged[ticket])

    print(f"✅ CSV merged: {MERGED_CSV}")

    return merged

def import_to_sqlite(trades: dict):
    """Importe les trades fusionnés dans SQLite"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # Créer la table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS trades (
            deal_ticket TEXT PRIMARY KEY,
            close_time TEXT,
            trade_date TEXT,
            hour_utc INTEGER,
            day_of_week TEXT,
            position_id TEXT,
            symbol TEXT,
            category TEXT,
            direction TEXT,
            volume REAL,
            open_time TEXT,
            close_time_full TEXT,
            open_price REAL,
            close_price REAL,
            profit REAL,
            swap REAL,
            commission REAL,
            net_profit REAL,
            duration_sec INTEGER,
            duration_min REAL,
            result TEXT,
            ai_confidence REAL,
            ai_action TEXT,
            balance REAL,
            equity REAL,
            daily_pnl REAL,
            ea_name TEXT,
            magic INTEGER,
            account TEXT,
            comment TEXT
        )
    """)

    imported = 0
    for ticket, trade in trades.items():
        try:
            cursor.execute("""
                INSERT OR REPLACE INTO trades VALUES (
                    ?,?,?,?,?,?,?,?,?,?,
                    ?,?,?,?,?,?,?,?,?,?,
                    ?,?,?,?,?,?,?,?,?,?
                )
            """, (
                ticket,
                trade.get('close_time', ''),
                trade.get('trade_date', ''),
                int(trade.get('hour_utc', 0) or 0),
                trade.get('day_of_week', ''),
                trade.get('position_id', ''),
                trade.get('symbol', ''),
                trade.get('category', ''),
                trade.get('direction', ''),
                float(trade.get('volume', 0) or 0),
                trade.get('open_time', ''),
                trade.get('close_time_full', ''),
                float(trade.get('open_price', 0) or 0),
                float(trade.get('close_price', 0) or 0),
                float(trade.get('profit', 0) or 0),
                float(trade.get('swap', 0) or 0),
                float(trade.get('commission', 0) or 0),
                float(trade.get('net_profit', 0) or 0),
                int(trade.get('duration_sec', 0) or 0),
                float(trade.get('duration_min', 0) or 0),
                trade.get('result', ''),
                float(trade.get('ai_confidence', 0) or 0),
                trade.get('ai_action', ''),
                float(trade.get('balance', 0) or 0),
                float(trade.get('equity', 0) or 0),
                float(trade.get('daily_pnl', 0) or 0),
                trade.get('ea_name', ''),
                int(trade.get('magic', 0) or 0),
                trade.get('account', ''),
                trade.get('comment', '')
            ))
            imported += 1
        except Exception as e:
            print(f"⚠️  Error importing {ticket}: {e}")

    conn.commit()
    conn.close()

    print(f"\n✅ Imported {imported} trades to SQLite")
    print(f"   Database: {DB_FILE}")

def generate_report():
    """Génère un rapport complet"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # Stats globales
    cursor.execute("SELECT COUNT(*) FROM trades")
    total = cursor.fetchone()[0]

    cursor.execute("SELECT SUM(net_profit) FROM trades WHERE net_profit IS NOT NULL")
    total_profit = cursor.fetchone()[0] or 0

    cursor.execute("SELECT AVG(net_profit) FROM trades WHERE net_profit IS NOT NULL")
    avg_profit = cursor.fetchone()[0] or 0

    # Par symbole
    cursor.execute("""
        SELECT symbol, COUNT(*),
               SUM(CASE WHEN net_profit > 0 THEN 1 ELSE 0 END),
               SUM(CASE WHEN net_profit < 0 THEN 1 ELSE 0 END),
               SUM(net_profit)
        FROM trades
        GROUP BY symbol
        ORDER BY COUNT(*) DESC
    """)
    by_symbol = cursor.fetchall()

    # Par date
    cursor.execute("""
        SELECT trade_date, COUNT(*),
               SUM(CASE WHEN net_profit > 0 THEN 1 ELSE 0 END),
               SUM(CASE WHEN net_profit < 0 THEN 1 ELSE 0 END),
               SUM(net_profit)
        FROM trades
        GROUP BY trade_date
        ORDER BY trade_date DESC
    """)
    by_date = cursor.fetchall()

    conn.close()

    # Print report
    report = []
    report.append("\n" + "="*70)
    report.append("MERGED TRADE JOURNAL — COMPLETE REPORT")
    report.append("="*70)

    report.append(f"\n📊 GLOBAL STATS")
    report.append(f"  Total Trades:      {total}")
    report.append(f"  Total Profit:      ${total_profit:.2f}")
    report.append(f"  Avg per Trade:     ${avg_profit:.2f}")

    report.append(f"\n📈 TOP SYMBOLS (by trade count)")
    for sym, count, wins, losses, profit in by_symbol[:15]:
        report.append(f"  {sym:25s} | Count: {count:4d} | Wins: {wins:4d} | Losses: {losses:4d} | P&L: ${profit or 0:8.2f}")

    report.append(f"\n📅 RECENT DATES (last 15 days)")
    for date, count, wins, losses, profit in by_date[:15]:
        report.append(f"  {date} | Count: {count:4d} | Wins: {wins:4d} | Losses: {losses:4d} | P&L: ${profit or 0:8.2f}")

    report.append("\n" + "="*70 + "\n")

    text = "\n".join(report)
    print(text)

    return text

def main():
    # Merge
    merged = merge_trades()

    # Import to SQLite
    import_to_sqlite(merged)

    # Report
    generate_report()

    print("✅ MERGE COMPLETE")
    print(f"   CSV:      {MERGED_CSV}")
    print(f"   Database: {DB_FILE}\n")

if __name__ == "__main__":
    main()
