#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Import Complete CSV → SQLite Database
Charge le CSV avec 1120 trades dans la base SQLite
"""

import sys
import io
import csv
import sqlite3
from pathlib import Path

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

CSV_FILE = Path("D:/Dev/TradBOT/data/trade_journal_complete.csv")
DB_FILE = Path("D:/Dev/TradBOT/data/trades_complete.db")
DB_FILE.parent.mkdir(exist_ok=True)

def init_database():
    """Crée la table SQLite"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

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
    conn.commit()
    conn.close()

def import_csv_to_db():
    """Importe le CSV dans SQLite"""
    init_database()
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    imported = 0
    with open(CSV_FILE, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                deal_ticket = row.get('deal_ticket', '')
                if not deal_ticket:
                    continue

                # Check if exists
                cursor.execute("SELECT 1 FROM trades WHERE deal_ticket = ?", (deal_ticket,))
                if cursor.fetchone():
                    continue

                cursor.execute("""
                    INSERT INTO trades (
                        deal_ticket, close_time, trade_date, hour_utc, day_of_week,
                        position_id, symbol, category, direction, volume,
                        open_time, close_time_full, open_price, close_price,
                        profit, swap, commission, net_profit,
                        duration_sec, duration_min, result,
                        ai_confidence, ai_action, balance, equity, daily_pnl,
                        ea_name, magic, account, comment
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    deal_ticket,
                    row.get('close_time', ''),
                    row.get('trade_date', ''),
                    int(row.get('hour_utc', 0) or 0),
                    row.get('day_of_week', ''),
                    row.get('position_id', ''),
                    row.get('symbol', ''),
                    row.get('category', ''),
                    row.get('direction', ''),
                    float(row.get('volume', 0) or 0),
                    row.get('open_time', ''),
                    row.get('close_time_full', ''),
                    float(row.get('open_price', 0) or 0),
                    float(row.get('close_price', 0) or 0),
                    float(row.get('profit', 0) or 0),
                    float(row.get('swap', 0) or 0),
                    float(row.get('commission', 0) or 0),
                    float(row.get('net_profit', 0) or 0),
                    int(row.get('duration_sec', 0) or 0),
                    float(row.get('duration_min', 0) or 0),
                    row.get('result', ''),
                    float(row.get('ai_confidence', 0) or 0),
                    row.get('ai_action', ''),
                    float(row.get('balance', 0) or 0),
                    float(row.get('equity', 0) or 0),
                    float(row.get('daily_pnl', 0) or 0),
                    row.get('ea_name', ''),
                    int(row.get('magic', 0) or 0),
                    row.get('account', ''),
                    row.get('comment', '')
                ))
                imported += 1

            except Exception as e:
                print(f"⚠️  Error importing trade {deal_ticket}: {e}")

    conn.commit()
    conn.close()
    return imported

def generate_report():
    """Génère un rapport sur les trades"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM trades")
    total = cursor.fetchone()[0]

    cursor.execute("""
        SELECT symbol, COUNT(*),
               SUM(CASE WHEN direction='BUY' THEN 1 ELSE 0 END),
               SUM(CASE WHEN direction='SELL' THEN 1 ELSE 0 END)
        FROM trades
        GROUP BY symbol
        ORDER BY COUNT(*) DESC
    """)
    by_symbol = cursor.fetchall()

    cursor.execute("""
        SELECT trade_date, COUNT(*),
               SUM(CASE WHEN direction='BUY' THEN 1 ELSE 0 END),
               SUM(CASE WHEN direction='SELL' THEN 1 ELSE 0 END)
        FROM trades
        GROUP BY trade_date
        ORDER BY trade_date DESC
    """)
    by_date = cursor.fetchall()

    conn.close()

    print("\n" + "="*70)
    print("COMPLETE TRADE JOURNAL — IMPORT REPORT")
    print("="*70)
    print(f"\n📊 GLOBAL STATS")
    print(f"  Total Trades:    {total}")

    print(f"\n📈 BY SYMBOL")
    for sym, count, buys, sells in by_symbol:
        print(f"  {sym:20s} | Total: {count:4d} | BUY: {buys:4d} | SELL: {sells:4d}")

    print(f"\n📅 BY DATE")
    for date, count, buys, sells in by_date:
        print(f"  {date} | Total: {count:4d} | BUY: {buys:4d} | SELL: {sells:4d}")

    print("\n" + "="*70 + "\n")

def main():
    print("\n" + "="*70)
    print("IMPORTING CSV TO SQLITE")
    print("="*70 + "\n")

    if not CSV_FILE.exists():
        print(f"❌ CSV file not found: {CSV_FILE}")
        return

    imported = import_csv_to_db()
    print(f"\n✅ Imported {imported} trades to SQLite")
    print(f"   Database: {DB_FILE}")

    generate_report()

if __name__ == "__main__":
    main()
