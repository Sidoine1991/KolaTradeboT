#!/usr/bin/env python3
"""
Serveur dashboard journal TradBOT.
Sources (par priorité) :
  1. Common/Files/TradBOT/trade_journal.csv  (écrit par SMC_Universal)
  2. data/trade_journal.csv                    (copie repo)
  3. Sync live depuis MT5 si CSV vide ou --sync-mt5
"""
from __future__ import annotations

import csv
import json
import os
import re
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get("TRADBOT_DASHBOARD_PORT", "8765"))
MAGIC = int(os.environ.get("TRADBOT_EA_MAGIC", "202502"))
ROOT = Path(__file__).resolve().parent
REPO_DATA = ROOT.parent / "data" / "trade_journal.csv"

CSV_HEADER = (
    "close_time,trade_date,hour_utc,day_of_week,deal_ticket,position_id,symbol,"
    "category,direction,volume,open_time,close_time_full,open_price,close_price,"
    "profit,swap,commission,net_profit,duration_sec,duration_min,result,"
    "ai_confidence,ai_action,balance,equity,daily_pnl,ea_name,magic,account,comment"
)


def infer_category(symbol: str) -> str:
    s = symbol.upper()
    if "BOOM" in s or "CRASH" in s:
        return "BOOM_CRASH"
    if "VOLATILITY" in s or "RANGE BREAK" in s or "STEP INDEX" in s:
        return "VOLATILITY"
    if any(x in s for x in ("XAU", "GOLD", "XAG", "SILVER")):
        return "METAL"
    if any(x in s for x in ("BTC", "ETH", "SOL", "ADA", "BNB", "XRP", "DOT", "AVAX", "MATIC", "LINK", "LTC")):
        return "CRYPTO"
    if any(x in s for x in ("OIL", "COPPER", "BRENT", "WTI")):
        return "COMMODITY"
    if any(x in s for x in ("USD", "EUR", "GBP", "JPY", "CHF", "AUD", "NZD", "CAD")):
        return "FOREX"
    return "UNKNOWN"


def _f(val: str | float | None, default: float = 0.0) -> float:
    try:
        return float(val) if val not in (None, "") else default
    except (ValueError, TypeError):
        return default


def common_journal_path() -> Path:
    appdata = os.environ.get("APPDATA", "")
    return Path(appdata) / "MetaQuotes" / "Terminal" / "Common" / "Files" / "TradBOT" / "trade_journal.csv"


def discover_csv_paths() -> list[Path]:
    paths: list[Path] = []
    env = os.environ.get("TRADBOT_JOURNAL_CSV")
    if env:
        p = Path(env)
        if p.exists():
            paths.append(p)

    # Repo data (import logs) en priorité si rempli
    if REPO_DATA.exists() and REPO_DATA.stat().st_size > 400:
        paths.append(REPO_DATA)

    common = common_journal_path()
    if common.exists():
        paths.append(common)

    if REPO_DATA.exists() and REPO_DATA not in paths:
        paths.append(REPO_DATA)

    # Ancien format terminal-local (SMC_Universal_Trade_Journal_*.csv)
    appdata = os.environ.get("APPDATA", "")
    if appdata:
        terminal_root = Path(appdata) / "MetaQuotes" / "Terminal"
        if terminal_root.exists():
            for p in terminal_root.rglob("SMC_Universal_Trade_Journal_*.csv"):
                if p not in paths:
                    paths.append(p)
            daily = terminal_root / "Common" / "Files" / "TradBOT" / "daily"
            if daily.exists():
                for p in daily.glob("trade_journal_*.csv"):
                    if p not in paths:
                        paths.append(p)

    return paths


def resolve_primary_csv_path() -> Path:
    env = os.environ.get("TRADBOT_JOURNAL_CSV")
    if env:
        return Path(env)
    if REPO_DATA.exists() and REPO_DATA.stat().st_size > 400:
        return REPO_DATA
    common = common_journal_path()
    common.parent.mkdir(parents=True, exist_ok=True)
    if not REPO_DATA.exists():
        REPO_DATA.parent.mkdir(parents=True, exist_ok=True)
        REPO_DATA.write_text(CSV_HEADER + "\n", encoding="utf-8")
    return common if common.exists() else REPO_DATA


CSV_PATH = resolve_primary_csv_path()

_CACHE: dict = {"trades": [], "ts": 0.0, "ttl": 8.0}


def _cache_valid() -> bool:
    import time
    return bool(_CACHE["trades"]) and (time.time() - _CACHE["ts"]) < _CACHE["ttl"]


def _set_cache(trades: list[dict]) -> list[dict]:
    import time
    _CACHE["trades"] = trades
    _CACHE["ts"] = time.time()
    return trades


def _parse_dt(s: str) -> datetime | None:
    if not s:
        return None
    s = s.strip().replace(".", "-")
    for fmt in (
        "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M",
        "%d-%m-%Y %H:%M:%S", "%d-%m-%Y %H:%M",
    ):
        try:
            return datetime.strptime(s[:19], fmt)
        except ValueError:
            continue
    return None


def normalize_row(row: dict) -> dict | None:
    # Format standard (TradBOT/trade_journal.csv)
    symbol = (row.get("symbol") or row.get("Symbol") or "").strip()
    if not symbol:
        return None

    category = (row.get("category") or row.get("Category") or "").strip().upper()
    if not category:
        category = infer_category(symbol)

    close_raw = row.get("close_time") or row.get("close_time_full") or row.get("CloseTime") or ""
    close_dt = _parse_dt(close_raw)
    trade_date = row.get("trade_date") or (close_dt.strftime("%Y-%m-%d") if close_dt else "")
    hour_utc = int(row.get("hour_utc") or (close_dt.hour if close_dt else 0))

    net = row.get("net_profit")
    if net in (None, ""):
        net = _f(row.get("profit") or row.get("Profit")) + _f(row.get("swap")) + _f(row.get("commission"))
    else:
        net = _f(net)

    result = (row.get("result") or row.get("Status") or "").upper()
    if not result or result == "CLOSED":
        result = "WIN" if net > 0 else ("LOSS" if net < 0 else "BE")

    deal = str(row.get("deal_ticket") or row.get("Ticket") or row.get("ticket") or "")
    pos = str(row.get("position_id") or row.get("position") or "")

    return {
        "close_time": close_raw,
        "trade_date": trade_date,
        "hour_utc": hour_utc,
        "day_of_week": row.get("day_of_week", ""),
        "deal_ticket": deal,
        "position_id": pos,
        "symbol": symbol,
        "category": category,
        "direction": (row.get("direction") or row.get("Direction") or "").upper(),
        "volume": _f(row.get("volume") or row.get("Volume")),
        "open_time": row.get("open_time") or row.get("OpenTime") or "",
        "close_time_full": row.get("close_time_full") or close_raw,
        "open_price": _f(row.get("open_price") or row.get("OpenPrice")),
        "close_price": _f(row.get("close_price") or row.get("ClosePrice")),
        "profit": _f(row.get("profit") or row.get("Profit")),
        "swap": _f(row.get("swap")),
        "commission": _f(row.get("commission")),
        "net_profit": net,
        "duration_sec": int(_f(row.get("duration_sec"))),
        "duration_min": _f(row.get("duration_min")),
        "result": result,
        "ai_confidence": _f(row.get("ai_confidence") or row.get("AIConfidence")) / (100 if _f(row.get("AIConfidence")) > 1 else 1),
        "ai_action": row.get("ai_action") or row.get("AIAction") or "",
        "balance": _f(row.get("balance")),
        "equity": _f(row.get("equity")),
        "daily_pnl": _f(row.get("daily_pnl")),
        "ea_name": row.get("ea_name") or row.get("EA") or "SMC_Universal",
        "magic": str(row.get("magic") or row.get("Magic") or MAGIC),
        "account": str(row.get("account") or ""),
        "comment": row.get("comment") or "",
    }


def _trade_key(t: dict) -> str:
    if t.get("deal_ticket"):
        return f"deal:{t['deal_ticket']}"
    return f"{t.get('symbol')}:{t.get('close_time')}:{t.get('net_profit')}"


def _read_csv_rows(path: Path) -> list[dict]:
    for encoding in ("utf-8-sig", "utf-8", "utf-16", "latin-1"):
        try:
            with path.open("r", encoding=encoding, newline="") as f:
                return list(csv.DictReader(f))
        except (UnicodeDecodeError, UnicodeError):
            continue
    return []


def load_trades_from_csv_files() -> list[dict]:
    merged: dict[str, dict] = {}
    for path in discover_csv_paths():
        try:
            for row in _read_csv_rows(path):
                t = normalize_row(row)
                if t:
                    merged[_trade_key(t)] = t
        except OSError:
            continue
    trades = list(merged.values())
    trades.sort(key=lambda x: x.get("close_time", ""))
    return trades


def load_trades_from_sqlite() -> list[dict]:
    """Charge les trades depuis la base SQLite fusionnée"""
    try:
        import sqlite3
        db_path = Path(__file__).parent.parent / "data" / "trades_merged.db"
        if not db_path.exists():
            return []

        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        cursor.execute("""
            SELECT close_time, trade_date, hour_utc, day_of_week, deal_ticket, position_id,
                   symbol, category, direction, volume, open_time, close_time_full,
                   open_price, close_price, profit, swap, commission, net_profit,
                   duration_sec, duration_min, result, ai_confidence, ai_action,
                   balance, equity, daily_pnl, ea_name, magic, account, comment
            FROM trades ORDER BY close_time DESC
        """)

        trades = []
        for row in cursor.fetchall():
            trades.append({
                "close_time": row[0],
                "trade_date": row[1],
                "hour_utc": row[2],
                "day_of_week": row[3],
                "deal_ticket": row[4],
                "position_id": row[5],
                "symbol": row[6],
                "category": row[7],
                "direction": row[8],
                "volume": row[9],
                "open_time": row[10],
                "close_time_full": row[11],
                "open_price": row[12],
                "close_price": row[13],
                "profit": row[14],
                "swap": row[15],
                "commission": row[16],
                "net_profit": row[17],
                "duration_sec": row[18],
                "duration_min": row[19],
                "result": row[20],
                "ai_confidence": row[21],
                "ai_action": row[22],
                "balance": row[23],
                "equity": row[24],
                "daily_pnl": row[25],
                "ea_name": row[26],
                "magic": row[27],
                "account": row[28],
                "comment": row[29],
            })

        conn.close()
        return trades
    except Exception as e:
        logger.warning(f"Error loading from SQLite: {e}")
        return []

def load_trades_from_mt5(days: int = 30) -> list[dict]:
    try:
        import MetaTrader5 as mt5
    except ImportError:
        return []

    if not mt5.initialize():
        return []

    try:
        utc_from = datetime.now(timezone.utc) - timedelta(days=days)
        deals = mt5.history_deals_get(utc_from, datetime.now(timezone.utc))
        if deals is None:
            return []

        # Grouper par position_id
        by_pos: dict[int, list] = defaultdict(list)
        for d in deals:
            if d.magic != MAGIC:
                continue
            by_pos[d.position_id].append(d)

        trades: list[dict] = []
        for pos_id, pos_deals in by_pos.items():
            ins = [d for d in pos_deals if d.entry == mt5.DEAL_ENTRY_IN]
            outs = [d for d in pos_deals if d.entry in (mt5.DEAL_ENTRY_OUT, mt5.DEAL_ENTRY_INOUT)]
            if not outs:
                continue

            close_deal = outs[-1]
            open_deal = ins[0] if ins else None
            symbol = close_deal.symbol
            category = infer_category(symbol)
            close_dt = datetime.fromtimestamp(close_deal.time, tz=timezone.utc)
            open_dt = datetime.fromtimestamp(open_deal.time, tz=timezone.utc) if open_deal else close_dt

            profit = sum(d.profit for d in outs)
            swap = sum(d.swap for d in outs)
            commission = sum(d.commission for d in outs)
            net = profit + swap + commission
            duration_sec = max(0, int((close_dt - open_dt).total_seconds()))

            trades.append({
                "close_time": close_dt.strftime("%Y-%m-%d %H:%M:%S"),
                "trade_date": close_dt.strftime("%Y-%m-%d"),
                "hour_utc": close_dt.hour,
                "day_of_week": close_dt.strftime("%a"),
                "deal_ticket": str(close_deal.ticket),
                "position_id": str(pos_id),
                "symbol": symbol,
                "category": category,
                "direction": "BUY" if (open_deal and open_deal.type == mt5.DEAL_TYPE_BUY) else "SELL",
                "volume": float(open_deal.volume if open_deal else close_deal.volume),
                "open_time": open_dt.strftime("%Y-%m-%d %H:%M:%S"),
                "close_time_full": close_dt.strftime("%Y-%m-%d %H:%M:%S"),
                "open_price": float(open_deal.price if open_deal else 0),
                "close_price": float(close_deal.price),
                "profit": round(profit, 2),
                "swap": round(swap, 2),
                "commission": round(commission, 2),
                "net_profit": round(net, 2),
                "duration_sec": duration_sec,
                "duration_min": round(duration_sec / 60, 1),
                "result": "WIN" if net > 0 else ("LOSS" if net < 0 else "BE"),
                "ai_confidence": 0.0,
                "ai_action": "",
                "balance": 0.0,
                "equity": 0.0,
                "daily_pnl": 0.0,
                "ea_name": "SMC_Universal",
                "magic": str(MAGIC),
                "account": str(close_deal.ticket),
                "comment": "mt5_sync",
            })

        trades.sort(key=lambda x: x["close_time"])
        return trades
    finally:
        mt5.shutdown()


def load_trades() -> list[dict]:
    if _cache_valid():
        return _CACHE["trades"]

    # 1) CSV (import logs MT5 / journal EA) — source principale
    csv_trades = load_trades_from_csv_files()
    if csv_trades:
        for t in csv_trades:
            if not t.get("category"):
                t["category"] = infer_category(t["symbol"])
        csv_trades = sync_today_log_trades(csv_trades)
        print(f"[Journal] CSV: {len(csv_trades)} trades")
        return _set_cache(csv_trades)

    # 2) SQLite fusionné (legacy)
    sqlite_trades = load_trades_from_sqlite()
    if sqlite_trades:
        for t in sqlite_trades:
            if not t.get("category"):
                t["category"] = infer_category(t["symbol"])
        print(f"[Journal] SQLite: {len(sqlite_trades)} trades")
        return _set_cache(sqlite_trades)

    # 3) MT5 live
    mt5_trades = load_trades_from_mt5(days=30)
    if mt5_trades:
        print(f"[Journal] Sync MT5 -> {len(mt5_trades)} trades (magic={MAGIC})")
    return _set_cache(mt5_trades)


def load_gom_verdicts() -> list[dict]:
    """Charge les verdicts GOM depuis gom_signal.json"""
    gom_file = Path(__file__).parent.parent / "data" / "gom_signal.json"
    if not gom_file.exists():
        return []

    try:
        with open(gom_file, "r", encoding="utf-8") as f:
            data = json.load(f)
            verdicts = data.get("verdicts", []) if isinstance(data, dict) else data
            return verdicts if isinstance(verdicts, list) else []
    except (json.JSONDecodeError, IOError):
        return []


def load_gom_summary() -> dict:
    """Charge un résumé des verdicts GOM + historique trades"""
    verdicts = load_gom_verdicts()
    trades = load_trades()

    # Résumé des verdicts actuels
    verdict_summary = {
        "total_verdicts": len(verdicts),
        "buys": sum(1 for v in verdicts if v.get("verdict_num", 0) in (1, 2)),
        "sells": sum(1 for v in verdicts if v.get("verdict_num", 0) in (3, 4)),
        "symbols": list(set(v.get("symbol", "N/A") for v in verdicts))
    }

    # Résumé des trades (dernières 24h et derniers 7j)
    now = datetime.now(timezone.utc)
    last_24h = now - timedelta(hours=24)
    last_7d = now - timedelta(days=7)

    trades_24h = []
    trades_7d = []

    for t in trades:
        try:
            trade_dt = _parse_dt(t.get("close_time", ""))
            if trade_dt:
                if trade_dt >= last_24h:
                    trades_24h.append(t)
                if trade_dt >= last_7d:
                    trades_7d.append(t)
        except:
            pass

    metrics_24h = compute_metrics(trades_24h)
    metrics_7d = compute_metrics(trades_7d)

    return {
        "verdicts": verdict_summary,
        "metrics_24h": {
            "total_trades": metrics_24h["total_trades"],
            "wins": metrics_24h["wins"],
            "losses": metrics_24h["losses"],
            "win_rate": metrics_24h["win_rate"],
            "net_pnl": metrics_24h["net_pnl"],
        },
        "metrics_7d": {
            "total_trades": metrics_7d["total_trades"],
            "wins": metrics_7d["wins"],
            "losses": metrics_7d["losses"],
            "win_rate": metrics_7d["win_rate"],
            "net_pnl": metrics_7d["net_pnl"],
        },
        "timestamp": now.isoformat(),
    }


def filter_trades(trades: list[dict], params: dict) -> list[dict]:
    out = trades
    if params.get("symbol"):
        sym = params["symbol"][0].upper()
        out = [t for t in out if t["symbol"].upper() == sym]
    if params.get("category"):
        cat = params["category"][0].upper()
        out = [t for t in out if (t.get("category") or infer_category(t["symbol"])).upper() == cat]
    if params.get("direction"):
        d = params["direction"][0].upper()
        out = [t for t in out if t["direction"].upper() == d]
    if params.get("result"):
        r = params["result"][0].upper()
        out = [t for t in out if t["result"].upper() == r]
    if params.get("date_from"):
        df = params["date_from"][0]
        out = [t for t in out if t["trade_date"] >= df]
    if params.get("date_to"):
        dt = params["date_to"][0]
        out = [t for t in out if t["trade_date"] <= dt]
    if params.get("hour"):
        h = int(params["hour"][0])
        out = [t for t in out if t["hour_utc"] == h]
    return out


def compute_metrics(trades: list[dict]) -> dict:
    if not trades:
        return {
            "total_trades": 0, "wins": 0, "losses": 0, "breakeven": 0,
            "win_rate": 0, "net_pnl": 0, "gross_profit": 0, "gross_loss": 0,
            "avg_win": 0, "avg_loss": 0, "profit_factor": 0,
            "best_trade": 0, "worst_trade": 0, "avg_duration_min": 0,
            "by_symbol": {}, "by_hour": {}, "by_day": {}, "by_category": {},
            "equity_curve": [], "daily_pnl": {},
        }

    for t in trades:
        if not t.get("category"):
            t["category"] = infer_category(t["symbol"])

    wins = [t for t in trades if t["net_profit"] > 0]
    losses = [t for t in trades if t["net_profit"] < 0]
    be = [t for t in trades if t["net_profit"] == 0]

    gross_profit = sum(t["net_profit"] for t in wins)
    gross_loss = abs(sum(t["net_profit"] for t in losses))
    net_pnl = sum(t["net_profit"] for t in trades)

    by_symbol: dict[str, dict] = defaultdict(lambda: {"trades": 0, "wins": 0, "pnl": 0.0, "category": ""})
    by_hour: dict[int, dict] = defaultdict(lambda: {"trades": 0, "wins": 0, "pnl": 0.0})
    by_day: dict[str, dict] = defaultdict(lambda: {"trades": 0, "wins": 0, "pnl": 0.0})
    by_category: dict[str, dict] = defaultdict(lambda: {"trades": 0, "wins": 0, "pnl": 0.0})
    daily_pnl: dict[str, float] = defaultdict(float)

    for t in trades:
        sym = t["symbol"]
        cat = t["category"] or infer_category(sym)
        sym_key = f"{cat}:{sym}"
        by_symbol[sym_key]["trades"] += 1
        by_symbol[sym_key]["pnl"] += t["net_profit"]
        by_symbol[sym_key]["category"] = cat
        if t["net_profit"] > 0:
            by_symbol[sym_key]["wins"] += 1

        h = t["hour_utc"]
        by_hour[h]["trades"] += 1
        by_hour[h]["pnl"] += t["net_profit"]
        if t["net_profit"] > 0:
            by_hour[h]["wins"] += 1

        d = t["trade_date"]
        by_day[d]["trades"] += 1
        by_day[d]["pnl"] += t["net_profit"]
        if t["net_profit"] > 0:
            by_day[d]["wins"] += 1
        daily_pnl[d] += t["net_profit"]

        by_category[cat]["trades"] += 1
        by_category[cat]["pnl"] += t["net_profit"]
        if t["net_profit"] > 0:
            by_category[cat]["wins"] += 1

    equity = 0.0
    equity_curve = []
    for t in trades:
        equity += t["net_profit"]
        equity_curve.append({"time": t["close_time"], "equity": round(equity, 2), "symbol": t["symbol"]})

    def wr(block: dict) -> dict:
        for v in block.values():
            v["win_rate"] = round(v["wins"] / v["trades"] * 100, 1) if v["trades"] else 0
            v["pnl"] = round(v["pnl"], 2)
        return dict(block)

    return {
        "total_trades": len(trades),
        "wins": len(wins),
        "losses": len(losses),
        "breakeven": len(be),
        "win_rate": round(len(wins) / len(trades) * 100, 1) if trades else 0,
        "net_pnl": round(net_pnl, 2),
        "gross_profit": round(gross_profit, 2),
        "gross_loss": round(gross_loss, 2),
        "avg_win": round(gross_profit / len(wins), 2) if wins else 0,
        "avg_loss": round(-gross_loss / len(losses), 2) if losses else 0,
        "profit_factor": round(gross_profit / gross_loss, 2) if gross_loss > 0 else (999.0 if gross_profit > 0 else 0),
        "best_trade": round(max(t["net_profit"] for t in trades), 2),
        "worst_trade": round(min(t["net_profit"] for t in trades), 2),
        "avg_duration_min": round(sum(t["duration_min"] for t in trades) / len(trades), 1),
        "by_symbol": wr(by_symbol),
        "by_hour": wr({str(k): v for k, v in sorted(by_hour.items())}),
        "by_day": wr(dict(sorted(by_day.items()))),
        "by_category": wr(by_category),
        "equity_curve": equity_curve,
        "daily_pnl": {k: round(v, 2) for k, v in sorted(daily_pnl.items())},
    }


def compute_recommendations(trades: list[dict], top_n: int = 3, min_trades: int = 8) -> dict:
    """Top symboles à trader selon l'historique journal."""
    if not trades:
        return {"top_symbols": [], "min_trades": min_trades}

    sym_stats: dict[str, dict] = defaultdict(lambda: {
        "trades": 0, "wins": 0, "pnl": 0.0, "gross_win": 0.0, "gross_loss": 0.0,
        "category": "", "hours": defaultdict(lambda: {"trades": 0, "wins": 0, "pnl": 0.0}),
        "directions": defaultdict(lambda: {"trades": 0, "wins": 0, "pnl": 0.0}),
        "durations": [],
    })

    for t in trades:
        sym = t["symbol"]
        cat = t.get("category") or infer_category(sym)
        s = sym_stats[sym]
        s["trades"] += 1
        s["category"] = cat
        s["pnl"] += t["net_profit"]
        if t["net_profit"] > 0:
            s["wins"] += 1
            s["gross_win"] += t["net_profit"]
        elif t["net_profit"] < 0:
            s["gross_loss"] += abs(t["net_profit"])

        h = int(t.get("hour_utc") or 0)
        s["hours"][h]["trades"] += 1
        s["hours"][h]["pnl"] += t["net_profit"]
        if t["net_profit"] > 0:
            s["hours"][h]["wins"] += 1

        d = (t.get("direction") or "").upper()
        if d:
            s["directions"][d]["trades"] += 1
            s["directions"][d]["pnl"] += t["net_profit"]
            if t["net_profit"] > 0:
                s["directions"][d]["wins"] += 1

        if t.get("duration_min"):
            s["durations"].append(float(t["duration_min"]))

    ranked: list[dict] = []
    for sym, s in sym_stats.items():
        if s["trades"] < min_trades:
            continue
        wr = s["wins"] / s["trades"] * 100
        pf = s["gross_win"] / s["gross_loss"] if s["gross_loss"] > 0 else (99.0 if s["gross_win"] > 0 else 0)
        avg_dur = sum(s["durations"]) / len(s["durations"]) if s["durations"] else 0

        # Score composite 0-100
        score = (
            min(wr, 100) * 0.35
            + min(pf, 3.0) / 3.0 * 100 * 0.25
            + (20 if s["pnl"] > 0 else 0)
            + min(s["trades"], 40) / 40 * 100 * 0.20
        )

        # Top 3 heures UTC propices (min 3 trades/heure)
        best_hours = []
        for h, hs in sorted(s["hours"].items(), key=lambda x: (-x[1]["wins"] / max(x[1]["trades"], 1), -x[1]["pnl"])):
            if hs["trades"] < 3:
                continue
            hwr = round(hs["wins"] / hs["trades"] * 100, 1)
            best_hours.append({
                "hour_utc": h,
                "label": f"{h:02d}h-{h+1:02d}h UTC",
                "trades": hs["trades"],
                "win_rate": hwr,
                "pnl": round(hs["pnl"], 2),
            })
            if len(best_hours) >= 3:
                break

        # Direction optimale
        best_dir = "BUY"
        best_dir_wr = 0.0
        for d, ds in s["directions"].items():
            if ds["trades"] >= 3:
                dwr = ds["wins"] / ds["trades"] * 100
                if dwr > best_dir_wr:
                    best_dir_wr = dwr
                    best_dir = d

        ranked.append({
            "symbol": sym,
            "category": s["category"],
            "score": round(score, 1),
            "trades": s["trades"],
            "win_rate": round(wr, 1),
            "net_pnl": round(s["pnl"], 2),
            "profit_factor": round(min(pf, 99), 2),
            "avg_duration_min": round(avg_dur, 1),
            "best_direction": best_dir,
            "direction_win_rate": round(best_dir_wr, 1),
            "best_hours": best_hours,
            "entry_tip": _entry_tip(sym, s["category"], best_dir, best_hours, avg_dur),
        })

    ranked.sort(key=lambda x: (-x["score"], -x["net_pnl"]))
    return {
        "top_symbols": ranked[:top_n],
        "eligible_count": len(ranked),
        "min_trades": min_trades,
        "generated_at": datetime.now().isoformat(),
    }


def _entry_tip(sym: str, cat: str, direction: str, hours: list, avg_dur: float) -> str:
    parts = []
    if cat == "BOOM_CRASH":
        parts.append("Boom: BUY only | Crash: SELL only")
    if hours:
        hl = ", ".join(h["label"] for h in hours[:2])
        parts.append(f"Fenêtres actives: {hl}")
    if direction:
        parts.append(f"Direction historique: {direction}")
    if avg_dur > 0:
        parts.append(f"Durée moy. {avg_dur:.0f} min")
    return " · ".join(parts) if parts else "Données insuffisantes"


def sync_today_log_trades(existing: list[dict]) -> list[dict]:
    """Ajoute les trades du log MT5 du jour non encore dans le CSV."""
    try:
        from import_journal_from_logs import match_trades_from_logs, DEFAULT_LOGS
    except ImportError:
        return existing

    today = datetime.now().strftime("%Y%m%d")
    today_logs = [p for p in DEFAULT_LOGS if today in p.stem]
    if not today_logs:
        appdata = os.environ.get("APPDATA", "")
        if appdata:
            terminal = Path(appdata) / "MetaQuotes" / "Terminal"
            today_logs = list(terminal.rglob(f"{today}.log"))
    if not today_logs:
        return existing

    fresh = match_trades_from_logs(today_logs)
    if not fresh:
        return existing

    keys = {f"{t.get('deal_ticket')}:{t.get('symbol')}:{t.get('close_time')}" for t in existing}
    added = 0
    merged = list(existing)
    for t in fresh:
        k = f"{t.get('deal_ticket')}:{t.get('symbol')}:{t.get('close_time')}"
        if k not in keys:
            merged.append({
                "close_time": t["close_time"].strftime("%Y-%m-%d %H:%M:%S") if hasattr(t["close_time"], "strftime") else str(t["close_time"]),
                "trade_date": t.get("trade_date") or "",
                "hour_utc": t.get("hour_utc", 0),
                "day_of_week": "",
                "deal_ticket": str(t.get("deal_ticket", "")),
                "position_id": str(t.get("position_id", "")),
                "symbol": t["symbol"],
                "category": t.get("category") or infer_category(t["symbol"]),
                "direction": t.get("direction", ""),
                "volume": t.get("volume", 0),
                "open_time": t["open_time"].strftime("%Y-%m-%d %H:%M:%S") if hasattr(t.get("open_time"), "strftime") else str(t.get("open_time", "")),
                "close_time_full": t["close_time"].strftime("%Y-%m-%d %H:%M:%S") if hasattr(t["close_time"], "strftime") else str(t["close_time"]),
                "open_price": t.get("open_price", 0),
                "close_price": t.get("close_price", 0),
                "profit": t.get("profit", 0),
                "swap": t.get("swap", 0),
                "commission": t.get("commission", 0),
                "net_profit": t.get("net_profit", 0),
                "duration_sec": t.get("duration_sec", 0),
                "duration_min": t.get("duration_min", 0),
                "result": t.get("result", ""),
                "ai_confidence": 0,
                "ai_action": "",
                "balance": 0,
                "equity": 0,
                "daily_pnl": 0,
                "ea_name": "SMC_Universal",
                "magic": str(MAGIC),
                "account": "",
                "comment": "log_today_sync",
            })
            keys.add(k)
            added += 1
    if added:
        print(f"[Journal] +{added} trades depuis log du jour")
        merged.sort(key=lambda x: x.get("close_time", ""))
    return merged


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        pass

    def _cors(self) -> None:
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _json(self, data: object, code: int = 200) -> None:
        body = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self._cors()
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _file(self, path: Path, content_type: str) -> None:
        if not path.exists():
            self.send_error(404)
            return
        body = path.read_bytes()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self._cors()
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_GET(self) -> None:
        parsed = urlparse(self.path)
        params = parse_qs(parsed.query)

        if parsed.path in ("/", "/index.html"):
            return self._file(ROOT / "trade_journal.html", "text/html; charset=utf-8")

        if parsed.path == "/gom":
            return self._file(ROOT / "gom_dashboard.html", "text/html; charset=utf-8")

        if parsed.path == "/api/status":
            trades = load_trades()
            sources = [str(p) for p in discover_csv_paths()]
            cats = defaultdict(int)
            for t in trades:
                cats[t.get("category") or infer_category(t["symbol"])] += 1
            return self._json({
                "csv_path": str(CSV_PATH),
                "csv_sources": sources,
                "trade_count": len(trades),
                "categories": dict(cats),
                "mt5_sync": any(t.get("comment") == "mt5_sync" for t in trades),
            })

        if parsed.path == "/api/trades":
            trades = filter_trades(load_trades(), params)
            return self._json({"trades": trades, "count": len(trades)})

        if parsed.path == "/api/metrics":
            trades = filter_trades(load_trades(), params)
            return self._json(compute_metrics(trades))

        if parsed.path == "/api/recommendations":
            trades = load_trades()
            cat = params.get("category", [None])[0]
            if cat:
                trades = [t for t in trades if (t.get("category") or infer_category(t["symbol"])).upper() == cat.upper()]
            return self._json(compute_recommendations(trades))

        if parsed.path == "/api/trades.csv":
            if not CSV_PATH.exists():
                self.send_error(404)
                return
            return self._file(CSV_PATH, "text/csv; charset=utf-8")

        if parsed.path == "/api/gom-verdicts":
            verdicts = load_gom_verdicts()
            return self._json({"verdicts": verdicts, "count": len(verdicts)})

        if parsed.path == "/api/gom-summary":
            summary = load_gom_summary()
            return self._json(summary)

        self.send_error(404)


def main() -> None:
    global CSV_PATH
    CSV_PATH = resolve_primary_csv_path()
    trades = load_trades()
    boom = [t for t in trades if (t.get("category") or infer_category(t["symbol"])) == "BOOM_CRASH"]
    print("=" * 60)
    print("TradBOT — Dashboard Journal de Trades")
    print(f"  CSV cible : {CSV_PATH}")
    print(f"  Sources   : {len(discover_csv_paths())} fichier(s)")
    print(f"  Trades    : {len(trades)} total | {len(boom)} Boom/Crash")
    print(f"  URL       : http://127.0.0.1:{PORT}/")
    print("=" * 60)
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nArrêt.")
        server.shutdown()


if __name__ == "__main__":
    main()
