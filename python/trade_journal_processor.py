#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Trade Journal Processor — Lit le CSV MT5 et traite les trades fermés
Synchronise avec la base de données et génère des rapports
"""

import csv
import json
import sqlite3
from pathlib import Path
from datetime import datetime, timezone
import logging

# Configuration
CSV_FILE = Path("D:/Dev/TradBOT/data/trade_journal.csv")
DB_FILE = Path("D:/Dev/TradBOT/data/trades.db")
LOGS_DIR = Path("D:/Dev/TradBOT/logs")

# Setup logging
LOGS_DIR.mkdir(exist_ok=True)
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - trade_journal - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOGS_DIR / "trade_journal_processor.log", encoding='utf-8', mode='a')
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
            comment TEXT,
            imported_at TEXT
        )
    """)

    conn.commit()
    return conn

def read_csv():
    """Lit le fichier CSV MT5"""
    if not CSV_FILE.exists():
        logger.warning(f"CSV file not found: {CSV_FILE}")
        return []

    trades = []
    try:
        with open(CSV_FILE, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                if row.get('deal_ticket'):  # Sauter les lignes vides
                    trades.append(row)
        logger.info(f"Read {len(trades)} trades from CSV")
        return trades
    except Exception as e:
        logger.error(f"Error reading CSV: {e}")
        return []

def import_trades_to_db(trades):
    """Importe les trades dans la base de données"""
    if not trades:
        logger.warning("No trades to import")
        return 0

    conn = init_database()
    cursor = conn.cursor()

    imported = 0
    for trade in trades:
        try:
            # Vérifier si le trade existe déjà
            cursor.execute("SELECT deal_ticket FROM trades WHERE deal_ticket = ?",
                         (trade.get('deal_ticket'),))
            if cursor.fetchone():
                continue  # Trade déjà importé

            # Insérer le trade
            cursor.execute("""
                INSERT INTO trades (
                    deal_ticket, close_time, trade_date, hour_utc, day_of_week,
                    position_id, symbol, category, direction, volume,
                    open_time, open_price, close_price, profit, swap, commission,
                    net_profit, duration_sec, duration_min, result,
                    ai_confidence, ai_action, balance, equity, daily_pnl,
                    ea_name, magic, account, comment, imported_at
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """, (
                trade.get('deal_ticket'),
                trade.get('close_time'),
                trade.get('trade_date'),
                int(trade.get('hour_utc', 0)) if trade.get('hour_utc') else 0,
                trade.get('day_of_week'),
                int(trade.get('position_id', 0)) if trade.get('position_id') else 0,
                trade.get('symbol'),
                trade.get('category'),
                trade.get('direction'),
                float(trade.get('volume', 0)) if trade.get('volume') else 0,
                trade.get('open_time'),
                float(trade.get('open_price', 0)) if trade.get('open_price') else 0,
                float(trade.get('close_price', 0)) if trade.get('close_price') else 0,
                float(trade.get('profit', 0)) if trade.get('profit') else 0,
                float(trade.get('swap', 0)) if trade.get('swap') else 0,
                float(trade.get('commission', 0)) if trade.get('commission') else 0,
                float(trade.get('net_profit', 0)) if trade.get('net_profit') else 0,
                int(trade.get('duration_sec', 0)) if trade.get('duration_sec') else 0,
                float(trade.get('duration_min', 0)) if trade.get('duration_min') else 0,
                trade.get('result'),
                float(trade.get('ai_confidence', 0)) if trade.get('ai_confidence') else 0,
                trade.get('ai_action'),
                float(trade.get('balance', 0)) if trade.get('balance') else 0,
                float(trade.get('equity', 0)) if trade.get('equity') else 0,
                float(trade.get('daily_pnl', 0)) if trade.get('daily_pnl') else 0,
                trade.get('ea_name'),
                int(trade.get('magic', 0)) if trade.get('magic') else 0,
                int(trade.get('account', 0)) if trade.get('account') else 0,
                trade.get('comment'),
                datetime.now(timezone.utc).isoformat()
            ))
            imported += 1
        except Exception as e:
            logger.error(f"Error importing trade {trade.get('deal_ticket')}: {e}")

    conn.commit()
    conn.close()
    return imported

def generate_report():
    """Génère un rapport des trades"""
    conn = sqlite3.connect(DB_FILE)
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    # Stats globales
    cursor.execute("SELECT COUNT(*) as total, SUM(net_profit) as total_profit FROM trades")
    stats = cursor.fetchone()

    total_trades = stats['total'] or 0
    total_profit = stats['total_profit'] or 0.0
    avg_profit = total_profit / total_trades if total_trades > 0 else 0.0

    # Wins vs Losses
    cursor.execute("""
        SELECT
            result,
            COUNT(*) as count,
            SUM(net_profit) as total,
            AVG(net_profit) as avg
        FROM trades
        GROUP BY result
    """)
    results = cursor.fetchall()

    # Par symbole
    cursor.execute("""
        SELECT
            symbol,
            COUNT(*) as count,
            SUM(net_profit) as total,
            AVG(net_profit) as avg
        FROM trades
        GROUP BY symbol
        ORDER BY total DESC
    """)
    by_symbol = cursor.fetchall()

    # Rapport
    report = f"""
╔════════════════════════════════════════════════════════════╗
║  TRADE JOURNAL REPORT                                      ║
╚════════════════════════════════════════════════════════════╝

📊 STATS GLOBALES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total Trades:     {total_trades}
Total Profit:     ${total_profit:.2f}
Avg per Trade:    ${avg_profit:.2f}

🎯 RÉSULTATS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

    for row in results:
        if row['result']:
            report += f"{row['result']:6s}: {row['count']:3d} trades | Profit: ${row['total']:10.2f} | Avg: ${row['avg']:.2f}\n"

    report += f"""
📈 PAR SYMBOLE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

    for row in by_symbol:
        report += f"{row['symbol']:20s}: {row['count']:3d} trades | Profit: ${row['total']:10.2f} | Avg: ${row['avg']:.2f}\n"

    report += f"""
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Timestamp: {datetime.now(timezone.utc).isoformat()}
Database: {DB_FILE}
"""

    logger.info(report)
    return report

def main():
    """Exécution principale"""
    logger.info("=" * 60)
    logger.info("Starting Trade Journal Processor")

    # Initialiser la DB
    init_database()

    # Lire le CSV
    trades = read_csv()

    # Importer en DB
    imported = import_trades_to_db(trades)
    logger.info(f"✅ Imported {imported} new trades to database")

    # Générer rapport
    generate_report()

    logger.info("✅ Processing complete")
    logger.info("=" * 60)

if __name__ == "__main__":
    main()
