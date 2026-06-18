#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Import All Daily Logs → Unified Trade Journal
Fusionne TOUS les fichiers logs quotidiens (tradbot_execute_YYYYMMDD_*.log)
dans une seule base de données SQLite + CSV unifié
"""

import sys
import io
import re
import sqlite3
import json
from pathlib import Path
from datetime import datetime
import logging

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Configuration
LOGS_DIR = Path("D:/Dev/TradBOT/logs")
DB_FILE = Path("D:/Dev/TradBOT/data/trades_unified.db")
CSV_FILE = Path("D:/Dev/TradBOT/data/trade_journal_unified.csv")
LOGS_DIR.mkdir(exist_ok=True)
DB_FILE.parent.mkdir(exist_ok=True)

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - import_all_logs - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOGS_DIR / "import_all_daily_logs.log", encoding='utf-8', mode='a')
    ]
)
logger = logging.getLogger(__name__)

class NoEmojiHandler(logging.StreamHandler):
    def emit(self, record):
        msg = record.getMessage()
        ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"{ts} - {record.levelname} - {msg}")

logger.addHandler(NoEmojiHandler())

def init_database():
    """Initialise la base de données SQLite"""
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
            comment TEXT,
            source_file TEXT,
            import_date TEXT
        )
    """)
    conn.commit()
    conn.close()

def extract_trades_from_log(log_file: Path) -> list[dict]:
    """Extrait les trades des logs tradbot_execute"""
    trades = []
    try:
        with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()

        # Pattern pour détecter les trades JSON
        pattern = r'"trade":\s*\{[^}]+\}'
        matches = re.findall(pattern, content)

        for match in matches:
            try:
                # Essayer de parser le JSON partiel
                trade_json = '{' + match + '}'
                trade = json.loads(trade_json)
                trades.append(trade)
            except:
                pass

        # Alternative: chercher les lignes avec "deal_ticket" ou "symbol"
        for line in content.split('\n'):
            if '"deal_ticket"' in line and '"symbol"' in line:
                try:
                    trade = json.loads(line)
                    if trade not in trades:
                        trades.append(trade)
                except:
                    pass

    except Exception as e:
        logger.warning(f"Error reading {log_file}: {e}")

    return trades

def import_trades_from_logs() -> int:
    """Importe tous les trades depuis les logs journaliers"""
    init_database()
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    imported = 0
    processed_files = []

    # Trouver tous les fichiers logs tradbot_execute_*.log
    log_files = sorted(LOGS_DIR.glob("tradbot_execute_*.log"))
    logger.info(f"Found {len(log_files)} log files to process")

    for log_file in log_files:
        logger.info(f"Processing {log_file.name}...")
        trades = extract_trades_from_log(log_file)

        if not trades:
            logger.warning(f"  No trades found in {log_file.name}")
            continue

        logger.info(f"  Found {len(trades)} trades in {log_file.name}")

        for trade in trades:
            try:
                deal_ticket = trade.get('deal_ticket') or trade.get('ticket')
                if not deal_ticket:
                    continue

                deal_ticket = str(deal_ticket)

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
                        ea_name, magic, account, comment, source_file, import_date
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, (
                    deal_ticket,
                    trade.get('close_time', ''),
                    trade.get('trade_date', ''),
                    int(trade.get('hour_utc', 0) or 0),
                    trade.get('day_of_week', ''),
                    str(trade.get('position_id', '') or ''),
                    trade.get('symbol', ''),
                    trade.get('category', ''),
                    trade.get('direction', ''),
                    float(trade.get('volume', 0) or 0),
                    trade.get('open_time', ''),
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
                    trade.get('ea_name', 'SMC_Universal'),
                    int(trade.get('magic', 0) or 0),
                    str(trade.get('account', '') or ''),
                    trade.get('comment', ''),
                    log_file.name,
                    datetime.now().isoformat()
                ))
                imported += 1

            except Exception as e:
                logger.warning(f"  Error importing trade {deal_ticket}: {e}")

        processed_files.append(log_file.name)
        conn.commit()

    conn.close()
    return imported

def export_to_csv():
    """Exporte tous les trades depuis DB vers CSV"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM trades ORDER BY close_time")
    rows = cursor.fetchall()
    conn.close()

    if not rows:
        logger.warning("No trades in database to export")
        return 0

    # Récupérer les noms de colonnes
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()
    cursor.execute("PRAGMA table_info(trades)")
    columns = [row[1] for row in cursor.fetchall()]
    conn.close()

    # Écrire CSV
    import csv
    with open(CSV_FILE, 'w', encoding='utf-8', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(columns)
        writer.writerows(rows)

    logger.info(f"Exported {len(rows)} trades to {CSV_FILE}")
    return len(rows)

def generate_summary():
    """Génère un résumé des trades importés"""
    conn = sqlite3.connect(DB_FILE)
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM trades")
    total = cursor.fetchone()[0]

    cursor.execute("SELECT SUM(net_profit) FROM trades")
    total_profit = cursor.fetchone()[0] or 0

    cursor.execute("""
        SELECT symbol, COUNT(*), SUM(net_profit),
               SUM(CASE WHEN net_profit > 0 THEN 1 ELSE 0 END),
               SUM(CASE WHEN net_profit < 0 THEN 1 ELSE 0 END)
        FROM trades
        GROUP BY symbol
        ORDER BY symbol
    """)
    by_symbol = cursor.fetchall()

    cursor.execute("""
        SELECT trade_date, COUNT(*), SUM(net_profit)
        FROM trades
        GROUP BY trade_date
        ORDER BY trade_date DESC
    """)
    by_date = cursor.fetchall()

    conn.close()

    # Print summary
    report = []
    report.append("\n" + "="*70)
    report.append("UNIFIED TRADE JOURNAL SUMMARY (ALL DAILY LOGS)")
    report.append("="*70)
    report.append(f"\n📊 GLOBAL STATS")
    report.append(f"  Total Trades:      {total}")
    report.append(f"  Total Profit:      ${total_profit:.2f}")
    report.append(f"  Avg per Trade:     ${(total_profit/total if total else 0):.2f}")

    report.append(f"\n📈 BY SYMBOL (Top 10)")
    for sym, count, profit, wins, losses in by_symbol[:10]:
        report.append(f"  {sym:25s} | Trades: {count:3d} | Wins: {wins:2d} | Losses: {losses:2d} | Profit: ${profit or 0:.2f}")

    report.append(f"\n📅 BY DATE (Last 10)")
    for date, count, profit in by_date[:10]:
        report.append(f"  {date} | Trades: {count:3d} | Profit: ${profit or 0:.2f}")

    report.append("\n" + "="*70 + "\n")

    text = "\n".join(report)
    logger.info(text)
    print(text)

def main():
    logger.info("="*70)
    logger.info("Starting Unified Trade Journal Import (All Daily Logs)")
    logger.info("="*70)

    imported = import_trades_from_logs()
    logger.info(f"[OK] Imported {imported} trades from daily logs")

    exported = export_to_csv()
    logger.info(f"[OK] Exported {exported} trades to CSV")

    generate_summary()

    logger.info("="*70)

if __name__ == "__main__":
    main()
