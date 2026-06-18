#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Import Complete MT5 Logs (20260608-20260616) → Unified Trade Journal CSV
Extraits TOUS les trades fermés depuis les logs MT5 journaliers
Format: deal # XXXXX [buy|sell] 0.XX SYMBOL at PRICE [done|closed]
"""

import sys
import io
import re
import csv
from pathlib import Path
from datetime import datetime

if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Configuration
MT5_LOGS_DIR = Path("C:/Users/USER/AppData/Roaming/MetaQuotes/Terminal/E6E3D0917DD641581E4779524EB3B1AA/logs")
CSV_FILE = Path("D:/Dev/TradBOT/data/trade_journal_complete.csv")
CSV_FILE.parent.mkdir(exist_ok=True)

# Pattern pour extraire les trades fermés
TRADE_PATTERN = r"deal\s+#(\d+)\s+(buy|sell)\s+([\d.]+)\s+(\w+)\s+at\s+([\d.]+)\s+(?:done|closed)"

def extract_trades_from_mt5_log(log_file: Path) -> list[dict]:
    """Extrait les trades fermés depuis un log MT5"""
    trades = []

    try:
        # Essayer différents encodages
        for encoding in ('utf-16', 'utf-16-le', 'utf-8', 'latin-1'):
            try:
                with open(log_file, 'r', encoding=encoding, errors='ignore') as f:
                    content = f.read()

                # Chercher tous les trades fermés
                matches = re.finditer(TRADE_PATTERN, content, re.IGNORECASE)

                for match in matches:
                    deal_id = match.group(1)
                    direction = match.group(2).upper()
                    volume = float(match.group(3))
                    symbol = match.group(4)
                    price = float(match.group(5))

                    # Extraire la date du log (depuis le nom du fichier)
                    log_date = log_file.stem  # e.g., "20260608"
                    if len(log_date) == 8:
                        try:
                            date_obj = datetime.strptime(log_date, "%Y%m%d")
                            trade_date = date_obj.strftime("%Y-%m-%d")
                            hour_utc = date_obj.hour
                        except:
                            trade_date = log_date
                            hour_utc = 0
                    else:
                        trade_date = log_date
                        hour_utc = 0

                    trade = {
                        'deal_ticket': deal_id,
                        'close_time': f"{trade_date} 00:00:00",
                        'trade_date': trade_date,
                        'hour_utc': hour_utc,
                        'day_of_week': date_obj.strftime("%a") if len(log_date) == 8 else "",
                        'position_id': deal_id,
                        'symbol': symbol,
                        'category': infer_category(symbol),
                        'direction': direction,
                        'volume': volume,
                        'open_time': f"{trade_date} 00:00:00",
                        'close_time_full': f"{trade_date} 00:00:00",
                        'open_price': price,
                        'close_price': price,
                        'profit': 0,
                        'swap': 0,
                        'commission': 0,
                        'net_profit': 0,
                        'duration_sec': 0,
                        'duration_min': 0,
                        'result': 'BE',
                        'ai_confidence': 0,
                        'ai_action': '',
                        'balance': 0,
                        'equity': 0,
                        'daily_pnl': 0,
                        'ea_name': 'SMC_Universal',
                        'magic': 0,
                        'account': '',
                        'comment': 'mt5_log_import'
                    }
                    trades.append(trade)

                if trades:
                    print(f"✅ Extracted {len(trades)} trades from {log_file.name}")
                    return trades

            except (UnicodeDecodeError, UnicodeError):
                continue

        print(f"⚠️  No trades extracted from {log_file.name}")
        return []

    except Exception as e:
        print(f"❌ Error reading {log_file.name}: {e}")
        return []

def infer_category(symbol: str) -> str:
    s = symbol.upper()
    if "BOOM" in s or "CRASH" in s:
        return "BOOM_CRASH"
    if any(x in s for x in ("XAU", "GOLD", "XAG", "SILVER")):
        return "METAL"
    if any(x in s for x in ("BTC", "ETH", "SOL", "ADA", "BNB", "XRP", "DOT")):
        return "CRYPTO"
    if any(x in s for x in ("USD", "EUR", "GBP", "JPY", "CHF", "AUD", "NZD", "CAD")):
        return "FOREX"
    return "UNKNOWN"

def main():
    print("\n" + "="*70)
    print("IMPORTING COMPLETE MT5 LOGS (20260608-20260616)")
    print("="*70 + "\n")

    if not MT5_LOGS_DIR.exists():
        print(f"❌ MT5 logs directory not found: {MT5_LOGS_DIR}")
        return

    # Lister tous les fichiers logs
    log_files = sorted(MT5_LOGS_DIR.glob("2026*.log"))
    print(f"Found {len(log_files)} log files\n")

    # Extraire les trades de tous les logs
    all_trades = {}
    total_extracted = 0

    for log_file in log_files:
        print(f"Processing {log_file.name}...")
        trades = extract_trades_from_mt5_log(log_file)

        for trade in trades:
            key = trade['deal_ticket']
            if key not in all_trades:
                all_trades[key] = trade
                total_extracted += 1

    print(f"\n✅ Total trades extracted: {total_extracted}")

    # Écrire le CSV
    if all_trades:
        fieldnames = [
            'close_time', 'trade_date', 'hour_utc', 'day_of_week',
            'deal_ticket', 'position_id', 'symbol', 'category', 'direction', 'volume',
            'open_time', 'close_time_full', 'open_price', 'close_price',
            'profit', 'swap', 'commission', 'net_profit',
            'duration_sec', 'duration_min', 'result',
            'ai_confidence', 'ai_action', 'balance', 'equity', 'daily_pnl',
            'ea_name', 'magic', 'account', 'comment'
        ]

        print(f"\nWriting to CSV: {CSV_FILE}")
        with open(CSV_FILE, 'w', encoding='utf-8', newline='') as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()

            for ticket in sorted(all_trades.keys(), key=lambda x: int(x)):
                writer.writerow(all_trades[ticket])

        print(f"✅ CSV written with {len(all_trades)} trades")

        # Résumé par symbole
        print(f"\n📊 SUMMARY BY SYMBOL:")
        by_symbol = {}
        for trade in all_trades.values():
            sym = trade['symbol']
            if sym not in by_symbol:
                by_symbol[sym] = 0
            by_symbol[sym] += 1

        for sym in sorted(by_symbol.keys()):
            print(f"  {sym:20s} | {by_symbol[sym]:4d} trades")
    else:
        print("❌ No trades extracted from any log files")

    print("\n" + "="*70 + "\n")

if __name__ == "__main__":
    main()
