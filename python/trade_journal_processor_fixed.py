#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Trade Journal Processor (Fixed) — Lit le CSV MT5 et traite les trades fermés
Version améliorée avec gestion d'erreur flexible des colonnes
"""

import csv
import json
import sqlite3
from pathlib import Path
from datetime import datetime, timezone
import logging
import sys
import io

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Configuration
CSV_FILE = Path("D:/Dev/TradBOT/data/trade_journal.csv")
DB_FILE = Path("D:/Dev/TradBOT/data/trades.db")
LOGS_DIR = Path("D:/Dev/TradBOT/logs")

# Setup logging
LOGS_DIR.mkdir(exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - trade_journal_fixed - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOGS_DIR / "trade_journal_processor_fixed.log", encoding='utf-8', mode='a')
    ]
)
logger = logging.getLogger(__name__)

def init_database():
    """Initialise la base de données SQLite"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    cursor.execute("""
        CREATE TABLE IF NOT EXISTS trades (
            deal_ticket INTEGER PRIMARY KEY,
            close_time TEXT,
            trade_date TEXT,
            hour_utc INTEGER,
            day_of_week TEXT,
            position_id INTEGER,
            symbol TEXT,
            category TEXT,
            direction TEXT,
            volume REAL,
            open_time TEXT,
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
            account INTEGER,
            comment TEXT
        )
    """)
    conn.commit()
    conn.close()

def process_trades():
    """Traite les trades du CSV"""
    init_database()

    if not CSV_FILE.exists():
        logger.error(f"CSV not found: {CSV_FILE}")
        return 0

    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    imported = 0
    with open(CSV_FILE, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        logger.info(f"Read {len(list(csv.DictReader(open(CSV_FILE, 'r', encoding='utf-8'))))} trades from CSV")

        # Re-read for actual processing
        with open(CSV_FILE, 'r', encoding='utf-8') as f2:
            reader = csv.DictReader(f2)
            for row in reader:
                try:
                    deal_ticket = int(row.get('deal_ticket', 0))
                    if not deal_ticket:
                        continue

                    # Check if already exists
                    cursor.execute("SELECT 1 FROM trades WHERE deal_ticket = ?", (deal_ticket,))
                    if cursor.fetchone():
                        continue

                    # Insert trade
                    cursor.execute("""
                        INSERT INTO trades (
                            deal_ticket, close_time, trade_date, hour_utc, day_of_week,
                            position_id, symbol, category, direction, volume,
                            open_time, open_price, close_price, profit, swap,
                            commission, net_profit, duration_sec, duration_min, result,
                            ai_confidence, ai_action, balance, equity, daily_pnl,
                            ea_name, magic, account, comment
                        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                    """, (
                        deal_ticket,
                        row.get('close_time', ''),
                        row.get('trade_date', ''),
                        int(row.get('hour_utc', 0) or 0),
                        row.get('day_of_week', ''),
                        int(row.get('position_id', 0) or 0),
                        row.get('symbol', ''),
                        row.get('category', ''),
                        row.get('direction', ''),
                        float(row.get('volume', 0) or 0),
                        row.get('open_time', ''),
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
                        int(row.get('account', 0) or 0),
                        row.get('comment', '')
                    ))
                    imported += 1

                except Exception as e:
                    logger.error(f"Error importing trade {row.get('deal_ticket', 'N/A')}: {e}")
                    continue

    conn.commit()
    conn.close()
    return imported

def generate_report():
    """Génère un rapport sur les trades"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    # Get stats
    cursor.execute("SELECT COUNT(*) FROM trades")
    total_trades = cursor.fetchone()[0]

    cursor.execute("SELECT SUM(net_profit) FROM trades")
    total_profit = cursor.fetchone()[0] or 0

    cursor.execute("SELECT AVG(net_profit) FROM trades WHERE net_profit IS NOT NULL")
    avg_profit = cursor.fetchone()[0] or 0

    # By symbol
    cursor.execute("""
        SELECT symbol, COUNT(*), SUM(net_profit),
               SUM(CASE WHEN net_profit > 0 THEN 1 ELSE 0 END),
               SUM(CASE WHEN net_profit < 0 THEN 1 ELSE 0 END)
        FROM trades
        GROUP BY symbol
        ORDER BY symbol
    """)
    by_symbol = cursor.fetchall()

    conn.close()

    # Print report
    report = []
    report.append("\n╔════════════════════════════════════════════════════════════╗")
    report.append("║  TRADE JOURNAL REPORT                                      ║")
    report.append("╚════════════════════════════════════════════════════════════╝")
    report.append(f"\n📊 STATS GLOBALES")
    report.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    report.append(f"Total Trades:     {total_trades}")
    report.append(f"Total Profit:     ${total_profit:.2f}")
    report.append(f"Avg per Trade:    ${avg_profit:.2f}")
    report.append(f"\n🎯 RÉSULTATS")
    report.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    report.append(f"\n📈 PAR SYMBOLE")
    report.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

    for sym, count, profit, wins, losses in by_symbol:
        report.append(f"{sym:20s} | Trades: {count:3d} | Wins: {wins:2d} | Losses: {losses:2d} | Profit: ${profit or 0:.2f}")

    report.append("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    report.append(f"Timestamp: {datetime.now(timezone.utc).isoformat()}")
    report.append(f"Database: {DB_FILE}\n")

    text = "\n".join(report)
    logger.info(text)
    print(text)

def main():
    logger.info("=" * 60)
    logger.info("Starting Trade Journal Processor (Fixed)")
    logger.info("=" * 60)

    imported = process_trades()
    logger.info(f"✅ Imported {imported} new trades to database")

    generate_report()

    logger.info("✅ Processing complete")
    logger.info("=" * 60)

if __name__ == "__main__":
    main()
