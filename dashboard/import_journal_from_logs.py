#!/usr/bin/env python3
"""
Importe l'historique des trades depuis les logs MT5 vers trade_journal.csv.

Usage:
  python dashboard/import_journal_from_logs.py
  python dashboard/import_journal_from_logs.py --logs path/to/20260616.log ...
"""
from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "data" / "trade_journal.csv"
MAGIC = 202502
EA_NAME = "SMC_Universal"

DEFAULT_LOGS = [
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\logs\20260608.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\logs\20260609.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\logs\20260610.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\logs\20260611.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\logs\20260612.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\logs\20260613.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\logs\20260614.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\logs\20260615.log"),
    Path(r"C:\Users\USER\AppData\Roaming\MetaQuotes\Terminal\E6E3D0917DD641581E4779524EB3B1AA\logs\20260616.log"),
]

CSV_HEADER = [
    "close_time", "trade_date", "hour_utc", "day_of_week", "deal_ticket", "position_id",
    "symbol", "category", "direction", "volume", "open_time", "close_time_full",
    "open_price", "close_price", "profit", "swap", "commission", "net_profit",
    "duration_sec", "duration_min", "result", "ai_confidence", "ai_action",
    "balance", "equity", "daily_pnl", "ea_name", "magic", "account", "comment",
]

DEAL_RE = re.compile(
    r"deal #(\d+) (buy|sell) ([\d.]+) (.+?) at ([\d.]+) done \(based on order #(\d+)\)",
    re.IGNORECASE,
)
CLOSE_RE = re.compile(
    r"close #(\d+) (buy|sell) ([\d.]+) (.+?) ([\d.]+)\s*$",
    re.IGNORECASE,
)
LINE_TIME_RE = re.compile(r"^\S+\s+\d+\s+(\d{2}:\d{2}:\d{2}\.\d+)")


def infer_category(symbol: str) -> str:
    s = symbol.upper()
    if "BOOM" in s or "CRASH" in s:
        return "BOOM_CRASH"
    if "VOLATILITY" in s or "STEP INDEX" in s or "RANGE BREAK" in s:
        return "VOLATILITY"
    if any(x in s for x in ("XAU", "GOLD", "XAG", "SILVER")):
        return "METAL"
    if any(x in s for x in ("BTC", "ETH", "SOL", "ADA", "BNB", "XRP", "DOT", "AVAX", "LTC", "LINK")):
        return "CRYPTO"
    if any(x in s for x in ("OIL", "COPPER", "BRENT", "WTI")):
        return "COMMODITY"
    if any(x in s for x in ("USD", "EUR", "GBP", "JPY", "CHF", "AUD", "NZD", "CAD")):
        return "FOREX"
    return "UNKNOWN"


def log_file_date(path: Path) -> datetime:
    m = re.search(r"(\d{8})", path.stem)
    if not m:
        raise ValueError(f"Date introuvable dans {path.name}")
    d = m.group(1)
    return datetime(int(d[0:4]), int(d[4:6]), int(d[6:8]))


def read_log_lines(path: Path) -> list[str]:
    for enc in ("utf-16", "utf-8", "latin-1"):
        try:
            return path.read_text(encoding=enc).splitlines()
        except (UnicodeDecodeError, UnicodeError):
            continue
    return []


def parse_log_file(path: Path) -> tuple[dict[int, dict], list[dict], list[dict]]:
    base_date = log_file_date(path)
    entries: dict[int, dict] = {}
    deals: list[dict] = []
    close_events: list[dict] = []

    for line in read_log_lines(path):
        if "Trades" not in line:
            continue

        tm = LINE_TIME_RE.search(line)
        if not tm:
            continue
        tpart = tm.group(1)
        try:
            h, m, s = tpart.split(":")
            sec = float(s)
            dt = base_date.replace(
                hour=int(h), minute=int(m), second=int(float(sec)), microsecond=int((sec % 1) * 1_000_000)
            )
        except ValueError:
            continue

        cm = CLOSE_RE.search(line)
        if cm:
            open_order = int(cm.group(1))
            entry_dir = cm.group(2).upper()
            vol = float(cm.group(3))
            symbol = cm.group(4).strip()
            entry_price = float(cm.group(5))
            close_events.append({
                "open_order": open_order,
                "entry_dir": entry_dir,
                "volume": vol,
                "symbol": symbol,
                "entry_price": entry_price,
                "close_request_time": dt,
            })
            continue

        dm = DEAL_RE.search(line)
        if not dm:
            continue

        deal_ticket = int(dm.group(1))
        direction = dm.group(2).upper()
        volume = float(dm.group(3))
        symbol = dm.group(4).strip()
        price = float(dm.group(5))
        order_id = int(dm.group(6))

        deal = {
            "time": dt,
            "deal_ticket": deal_ticket,
            "direction": direction,
            "volume": volume,
            "symbol": symbol,
            "price": price,
            "order_id": order_id,
        }
        deals.append(deal)

        if order_id not in entries:
            entries[order_id] = {
                "open_time": dt,
                "open_price": price,
                "direction": direction,
                "volume": volume,
                "symbol": symbol,
                "open_deal": deal_ticket,
            }

    return entries, deals, close_events


def match_trades_from_logs(log_paths: list[Path]) -> list[dict]:
    all_deals: list[dict] = []
    all_close_events: list[dict] = []
    entries_by_order: dict[int, dict] = {}

    for path in sorted(log_paths):
        if not path.exists():
            print(f"[skip] {path} introuvable")
            continue
        entries, deals, closes = parse_log_file(path)
        all_deals.extend(deals)
        all_close_events.extend(closes)
        entries_by_order.update(entries)
        print(f"[ok] {path.name}: {len(deals)} deals, {len(closes)} fermetures")

    all_deals.sort(key=lambda d: d["time"])

    trades: list[dict] = []
    used_close_deals: set[int] = set()

    for ev in sorted(all_close_events, key=lambda x: x["close_request_time"]):
        open_order = ev["open_order"]
        entry = entries_by_order.get(open_order)
        if not entry:
            entry = {
                "open_time": ev["close_request_time"] - timedelta(seconds=60),
                "open_price": ev["entry_price"],
                "direction": ev["entry_dir"],
                "volume": ev["volume"],
                "symbol": ev["symbol"],
                "open_deal": open_order,
            }

        close_dir = "SELL" if entry["direction"] == "BUY" else "BUY"
        close_deal = None
        window_end = ev["close_request_time"] + timedelta(seconds=120)
        for d in all_deals:
            if d["deal_ticket"] in used_close_deals:
                continue
            if d["time"] < ev["close_request_time"] - timedelta(seconds=2):
                continue
            if d["time"] > window_end:
                continue
            if d["symbol"] != ev["symbol"]:
                continue
            if abs(d["volume"] - ev["volume"]) > 0.001:
                continue
            if d["direction"] != close_dir:
                continue
            close_deal = d
            break

        if not close_deal:
            continue

        used_close_deals.add(close_deal["deal_ticket"])

        open_time = entry["open_time"]
        close_time = close_deal["time"]
        duration_sec = max(0, int((close_time - open_time).total_seconds()))
        symbol = ev["symbol"]
        category = infer_category(symbol)
        direction = entry["direction"]
        open_price = entry["open_price"]
        close_price = close_deal["price"]
        volume = ev["volume"]

        # PnL brut estimé (sera enrichi par MT5 si dispo)
        profit = _estimate_profit(symbol, direction, open_price, close_price, volume)

        trades.append({
            "close_time": close_time,
            "open_time": open_time,
            "deal_ticket": close_deal["deal_ticket"],
            "position_id": open_order,
            "symbol": symbol,
            "category": category,
            "direction": direction,
            "volume": volume,
            "open_price": open_price,
            "close_price": close_price,
            "profit": profit,
            "swap": 0.0,
            "commission": 0.0,
            "net_profit": profit,
            "duration_sec": duration_sec,
            "ai_confidence": 0.0,
            "ai_action": "",
            "comment": f"log_import:{log_file_date_from_time(close_time)}",
        })

    return trades


def log_file_date_from_time(dt: datetime) -> str:
    return dt.strftime("%Y%m%d")


def _estimate_profit(symbol: str, direction: str, open_p: float, close_p: float, vol: float) -> float:
    """Estimation simple — remplacée par MT5 si disponible."""
    diff = close_p - open_p if direction == "BUY" else open_p - close_p
    s = symbol.upper()
    if "XAU" in s or "GOLD" in s:
        return round(diff * vol * 100, 2)
    if "BOOM" in s or "CRASH" in s or "VOLATILITY" in s or "STEP" in s:
        return round(diff * vol, 2)
    if any(x in s for x in ("BTC", "ETH")):
        return round(diff * vol, 2)
    return round(diff * vol * 10000, 2)


def enrich_from_mt5(trades: list[dict], magic: int = MAGIC) -> list[dict]:
    try:
        import MetaTrader5 as mt5
    except ImportError:
        print("[warn] MetaTrader5 non installé — PnL estimé depuis les prix")
        return trades

    if not mt5.initialize():
        print("[warn] MT5 non disponible — PnL estimé depuis les prix")
        return trades

    try:
        deal_cache: dict[int, object] = {}
        enriched = 0
        skipped_magic = 0
        for t in trades:
            ticket = int(t["deal_ticket"])
            if ticket not in deal_cache:
                deals = mt5.history_deals_get(ticket=ticket)
                deal_cache[ticket] = deals[0] if deals else None
            d = deal_cache[ticket]
            if d is None:
                continue
            if d.magic != magic:
                skipped_magic += 1
                t["comment"] = f"log_import_magic_{d.magic}"
                continue
            profit = float(d.profit)
            swap = float(d.swap)
            commission = float(d.commission)
            t["profit"] = round(profit, 2)
            t["swap"] = round(swap, 2)
            t["commission"] = round(commission, 2)
            t["net_profit"] = round(profit + swap + commission, 2)
            t["position_id"] = int(d.position_id)
            t["comment"] = "mt5_log_import"
            enriched += 1
        print(f"[mt5] PnL exact: {enriched}/{len(trades)} | autre magic: {skipped_magic}")
        return trades
    finally:
        mt5.shutdown()


def build_csv_rows(trades: list[dict]) -> list[dict]:
    trades.sort(key=lambda t: t["close_time"])
    daily_pnl: dict[str, float] = defaultdict(float)

    rows: list[dict] = []
    for t in trades:
        close_dt: datetime = t["close_time"]
        open_dt: datetime = t["open_time"]
        trade_date = close_dt.strftime("%Y-%m-%d")
        net = t["net_profit"]
        daily_pnl[trade_date] += net
        result = "WIN" if net > 0 else ("LOSS" if net < 0 else "BE")
        dow = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][close_dt.weekday()]

        rows.append({
            "close_time": close_dt.strftime("%Y-%m-%d %H:%M:%S"),
            "trade_date": trade_date,
            "hour_utc": close_dt.hour,
            "day_of_week": dow,
            "deal_ticket": str(t["deal_ticket"]),
            "position_id": str(t["position_id"]),
            "symbol": t["symbol"],
            "category": t["category"],
            "direction": t["direction"],
            "volume": f"{t['volume']:.2f}",
            "open_time": open_dt.strftime("%Y-%m-%d %H:%M:%S"),
            "close_time_full": close_dt.strftime("%Y-%m-%d %H:%M:%S"),
            "open_price": f"{t['open_price']:.5f}".rstrip("0").rstrip("."),
            "close_price": f"{t['close_price']:.5f}".rstrip("0").rstrip("."),
            "profit": f"{t['profit']:.2f}",
            "swap": f"{t['swap']:.2f}",
            "commission": f"{t['commission']:.2f}",
            "net_profit": f"{net:.2f}",
            "duration_sec": str(t["duration_sec"]),
            "duration_min": f"{t['duration_sec'] / 60:.1f}",
            "result": result,
            "ai_confidence": f"{t['ai_confidence']:.4f}",
            "ai_action": t["ai_action"],
            "balance": "0.00",
            "equity": "0.00",
            "daily_pnl": f"{daily_pnl[trade_date]:.2f}",
            "ea_name": EA_NAME,
            "magic": str(MAGIC),
            "account": "",
            "comment": t.get("comment", "log_import"),
        })
    return rows


def write_csv(path: Path, rows: list[dict]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=CSV_HEADER)
        w.writeheader()
        w.writerows(rows)


def write_sqlite(path: Path, rows: list[dict]) -> None:
    import sqlite3
    path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(path)
    conn.execute("DROP TABLE IF EXISTS trades")
    conn.execute("""
        CREATE TABLE trades (
            close_time TEXT, trade_date TEXT, hour_utc INTEGER, day_of_week TEXT,
            deal_ticket TEXT, position_id TEXT, symbol TEXT, category TEXT,
            direction TEXT, volume TEXT, open_time TEXT, close_time_full TEXT,
            open_price TEXT, close_price TEXT, profit TEXT, swap TEXT, commission TEXT,
            net_profit TEXT, duration_sec TEXT, duration_min TEXT, result TEXT,
            ai_confidence TEXT, ai_action TEXT, balance TEXT, equity TEXT, daily_pnl TEXT,
            ea_name TEXT, magic TEXT, account TEXT, comment TEXT
        )
    """)
    cols = CSV_HEADER
    placeholders = ",".join("?" * len(cols))
    conn.executemany(
        f"INSERT INTO trades ({','.join(cols)}) VALUES ({placeholders})",
        [tuple(r[c] for c in cols) for r in rows],
    )
    conn.commit()
    conn.close()


def main() -> int:
    parser = argparse.ArgumentParser(description="Import journal depuis logs MT5")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--logs", nargs="*", type=Path, default=None)
    parser.add_argument("--magic", type=int, default=MAGIC)
    parser.add_argument("--no-mt5", action="store_true", help="Ne pas enrichir via MT5")
    args = parser.parse_args()

    log_paths = args.logs or DEFAULT_LOGS
    existing = [p for p in log_paths if p.exists()]
    if not existing:
        print("Aucun fichier log trouvé.")
        return 1

    trades = match_trades_from_logs(existing)
    print(f"Trades appariés depuis logs: {len(trades)}")

    if not args.no_mt5:
        trades = enrich_from_mt5(trades, magic=args.magic)

    rows = build_csv_rows(trades)
    write_csv(args.out, rows)
    sqlite_path = ROOT / "data" / "trades_merged.db"
    write_sqlite(sqlite_path, rows)

    cats = defaultdict(int)
    for r in rows:
        cats[r["category"]] += 1
    print(f"Ecrit {len(rows)} trades -> {args.out}")
    for cat, n in sorted(cats.items()):
        print(f"  {cat}: {n}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
