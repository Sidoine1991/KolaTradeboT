#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Import MT5 trade history into trades.db via the MetaTrader5 Python API.

Usage:
    python import_mt5_history.py [--terminal PATH] [--from-date YYYY-MM-DD]

Connects to the running MT5 terminal (default: whichever is active),
fetches all closed deals (entry=OUT), and inserts them into trades.db
skipping duplicates by deal_ticket.
"""

import sys
import os
import sqlite3
import logging
import argparse
from concurrent.futures import ThreadPoolExecutor, TimeoutError as FuturesTimeoutError
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

_MT5_CALL_TIMEOUT = 15.0  # secondes max par appel MT5 bloquant
_MT5_EXECUTOR = ThreadPoolExecutor(max_workers=1, thread_name_prefix="mt5_import")

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
logger = logging.getLogger("mt5_import")

try:
    import MetaTrader5 as mt5
except ImportError:
    logger.error("MetaTrader5 package not installed: pip install MetaTrader5")
    sys.exit(1)

_HERE = Path(__file__).parent.parent
DB_PATH = os.getenv("TRADES_DB_PATH", str(_HERE / "data" / "trades.db"))


def _category_from_symbol(symbol: str) -> str:
    sym_upper = symbol.upper()
    if "BOOM" in sym_upper or "CRASH" in sym_upper:
        return "BOOM_CRASH"
    if "VOLATILITY" in sym_upper or "VOL" in sym_upper:
        return "VOLATILITY"
    if any(x in sym_upper for x in ["BTC", "ETH", "XRP", "SOL", "ADA"]):
        return "CRYPTO"
    if "XAU" in sym_upper or "GOLD" in sym_upper or "XAG" in sym_upper:
        return "METALS"
    # Forex pairs: 6 letters like EURUSD, GBPJPY
    if len(symbol.replace(" ", "")) == 6 and symbol.replace(" ", "").isalpha():
        return "FOREX"
    return "OTHER"


def _get_or_create_db() -> sqlite3.Connection:
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH, timeout=10)
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_trades_close_time ON trades(close_time)
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_trades_ticket ON trades(deal_ticket)
    """)
    conn.execute("""
        CREATE TABLE IF NOT EXISTS trades (
            deal_ticket   INTEGER PRIMARY KEY,
            close_time    TEXT,
            trade_date    TEXT,
            hour_utc      INTEGER,
            day_of_week   TEXT,
            position_id   INTEGER,
            symbol        TEXT,
            category      TEXT,
            direction     TEXT,
            volume        REAL,
            open_time     TEXT,
            open_price    REAL,
            close_price   REAL,
            profit        REAL,
            swap          REAL,
            commission    REAL,
            net_profit    REAL,
            duration_sec  INTEGER,
            duration_min  REAL,
            result        TEXT,
            ai_confidence REAL DEFAULT 0,
            ai_action     TEXT DEFAULT '',
            balance       REAL DEFAULT 0,
            equity        REAL DEFAULT 0,
            daily_pnl     REAL DEFAULT 0,
            ea_name       TEXT DEFAULT 'SMC_Universal',
            magic         INTEGER DEFAULT 0,
            account       INTEGER DEFAULT 0,
            comment       TEXT DEFAULT '',
            imported_at   TEXT
        )
    """)
    conn.commit()
    return conn


def _existing_tickets(conn: sqlite3.Connection) -> set:
    cur = conn.execute("SELECT deal_ticket FROM trades")
    return {row[0] for row in cur.fetchall()}


def _last_close_time(conn: sqlite3.Connection) -> Optional[datetime]:
    """Retourne la date du dernier trade importé, pour ne fetcher que les nouveaux."""
    cur = conn.execute("SELECT MAX(close_time) FROM trades")
    row = cur.fetchone()
    if row and row[0]:
        try:
            dt = datetime.strptime(row[0], "%Y-%m-%d %H:%M:%S").replace(tzinfo=timezone.utc)
            # Recul 5 min pour éviter de rater un deal sur la fenêtre limite
            from datetime import timedelta
            return dt - timedelta(minutes=5)
        except Exception:
            pass
    return None


def _mt5_call(fn, *args, timeout: float = _MT5_CALL_TIMEOUT):
    """Appel MT5 avec timeout pour éviter le blocage indéfini."""
    future = _MT5_EXECUTOR.submit(fn, *args)
    try:
        return future.result(timeout=timeout)
    except FuturesTimeoutError:
        logger.warning("MT5 call timeout (%.0fs): %s", timeout, getattr(fn, "__name__", str(fn)))
        return None
    except Exception as e:
        logger.debug("MT5 call error %s: %s", getattr(fn, "__name__", str(fn)), e)
        return None


def import_from_mt5(terminal_path: Optional[str] = None, from_date: Optional[datetime] = None) -> int:
    if from_date is None:
        from_date = datetime(2026, 1, 1, tzinfo=timezone.utc)

    init_kwargs = {}
    if terminal_path:
        init_kwargs["path"] = terminal_path

    ok = _mt5_call(mt5.initialize, **init_kwargs)
    if not ok:
        logger.error("MT5 initialize failed or timeout: %s", mt5.last_error())
        return 0

    try:
        acct = _mt5_call(mt5.account_info)
        if acct:
            logger.info("Connected: account=%s server=%s", acct.login, acct.server)
        else:
            logger.warning("No account info available")

        # Optimisation : ne fetcher que depuis le dernier trade connu (évite de recharger tout l'historique)
        conn_check = _get_or_create_db()
        last_dt = _last_close_time(conn_check)
        conn_check.close()
        if last_dt is not None and from_date < last_dt:
            from_date = last_dt
            logger.debug("Fetch MT5 depuis %s (dernier trade DB)", from_date.strftime("%Y-%m-%d %H:%M:%S"))

        to_date = datetime.now(tz=timezone.utc)
        deals = _mt5_call(
            mt5.history_deals_get,
            from_date.replace(tzinfo=None),
            to_date.replace(tzinfo=None),
            timeout=20.0,
        )
        if deals is None or len(deals) == 0:
            logger.debug("No deals returned from MT5 for window %s -> now", from_date.strftime("%Y-%m-%d %H:%M"))
            return 0

        logger.info("Total deals from MT5: %d", len(deals))

        # Build open-deal lookup for position metadata (open price, open time, direction)
        open_deals = {}
        for d in deals:
            if d.entry == mt5.DEAL_ENTRY_IN and d.symbol:
                open_deals[d.position_id] = d

        close_deals = [d for d in deals if d.entry == mt5.DEAL_ENTRY_OUT and d.symbol]
        logger.info("Close deals (entry=OUT): %d", len(close_deals))

        if not close_deals:
            return 0

        conn = _get_or_create_db()
        # Ne vérifier que les tickets de la fenêtre fetchée — pas toute la table
        fetched_tickets = {d.ticket for d in close_deals}
        placeholders = ",".join("?" * len(fetched_tickets))
        cur = conn.execute(
            f"SELECT deal_ticket FROM trades WHERE deal_ticket IN ({placeholders})",
            list(fetched_tickets)
        )
        existing = {row[0] for row in cur.fetchall()}
        logger.info("Already in DB: %d / %d fetched", len(existing), len(close_deals))

        inserted = 0
        skipped = 0
        imported_at = datetime.now(tz=timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

        for cd in close_deals:
            if cd.ticket in existing:
                skipped += 1
                continue

            close_dt = datetime.fromtimestamp(cd.time, tz=timezone.utc)
            od = open_deals.get(cd.position_id)

            if od:
                open_dt = datetime.fromtimestamp(od.time, tz=timezone.utc)
                open_price = od.price
                # When closing, type=BUY-to-close means original was SELL; SELL-to-close means BUY
                direction = "SELL" if cd.type == mt5.DEAL_TYPE_BUY else "BUY"
                volume = od.volume
                duration_sec = int(cd.time - od.time)
            else:
                open_dt = close_dt
                open_price = 0.0
                direction = "BUY" if cd.type == mt5.DEAL_TYPE_SELL else "SELL"
                volume = cd.volume
                duration_sec = 0

            net_profit = cd.profit + cd.swap + cd.commission
            result = "WIN" if net_profit > 0 else ("LOSS" if net_profit < 0 else "BE")
            category = _category_from_symbol(cd.symbol)
            magic = cd.magic if cd.magic else 0
            account = acct.login if acct else 0

            conn.execute("""
                INSERT OR IGNORE INTO trades
                (deal_ticket, close_time, trade_date, hour_utc, day_of_week,
                 position_id, symbol, category, direction, volume,
                 open_time, open_price, close_price,
                 profit, swap, commission, net_profit,
                 duration_sec, duration_min, result,
                 ai_confidence, ai_action, balance, equity, daily_pnl,
                 ea_name, magic, account, comment, imported_at)
                VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
            """, (
                cd.ticket,
                close_dt.strftime("%Y-%m-%d %H:%M:%S"),
                close_dt.strftime("%Y-%m-%d"),
                close_dt.hour,
                close_dt.strftime("%a"),
                cd.position_id,
                cd.symbol,
                category,
                direction,
                volume,
                open_dt.strftime("%Y-%m-%d %H:%M:%S"),
                open_price,
                cd.price,
                cd.profit,
                cd.swap,
                cd.commission,
                net_profit,
                duration_sec,
                round(duration_sec / 60.0, 1),
                result,
                0.0,
                "",
                0.0,
                0.0,
                0.0,
                "SMC_Universal",
                magic,
                account,
                cd.comment or "",
                imported_at
            ))
            inserted += 1

        conn.commit()
        conn.close()
        logger.info("Import complete: %d inserted, %d skipped (already in DB)", inserted, skipped)
        return inserted

    finally:
        mt5.shutdown()


def print_summary(db_path: str = DB_PATH) -> None:
    conn = sqlite3.connect(db_path)
    rows = conn.execute("""
        SELECT symbol, COUNT(*) as n,
               ROUND(100.0 * SUM(CASE WHEN result='WIN' THEN 1 ELSE 0 END) / COUNT(*), 1) as wr
        FROM trades GROUP BY symbol ORDER BY n DESC
    """).fetchall()
    print(f"\n{'Symbol':<30} {'Trades':>6} {'WR%':>6}")
    print("-" * 45)
    for sym, n, wr in rows:
        print(f"{sym:<30} {n:>6} {wr:>5.1f}%")
    total = conn.execute("SELECT COUNT(*) FROM trades").fetchone()[0]
    print(f"\nTotal: {total} trades in {db_path}")
    conn.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import MT5 trade history into trades.db")
    parser.add_argument("--terminal", help="Path to terminal64.exe (if not default)", default=None)
    parser.add_argument("--from-date", help="Import from date YYYY-MM-DD (default: 2026-01-01)", default="2026-01-01")
    args = parser.parse_args()

    from_date = datetime.strptime(args.from_date, "%Y-%m-%d").replace(tzinfo=timezone.utc)
    n = import_from_mt5(terminal_path=args.terminal, from_date=from_date)
    print(f"\nImported {n} new trades")
    print_summary()
