#!/usr/bin/env python3
"""
Serveur local pour le dashboard journal de trades TradBOT.
Lit le CSV écrit par MT5 (Common/Files/TradBOT/trade_journal.csv)
et expose une API JSON pour le dashboard HTML interactif.
"""
from __future__ import annotations

import csv
import json
import os
import sys
from collections import defaultdict
from datetime import datetime
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

PORT = int(os.environ.get("TRADBOT_DASHBOARD_PORT", "8765"))
ROOT = Path(__file__).resolve().parent
REPO_DATA = ROOT.parent / "data" / "trade_journal.csv"


def find_mt5_journal_path() -> Path | None:
    """Cherche trade_journal.csv dans Common/Files MT5."""
    appdata = os.environ.get("APPDATA")
    if appdata:
        common = Path(appdata) / "MetaQuotes" / "Terminal" / "Common" / "Files" / "TradBOT"
        main = common / "trade_journal.csv"
        if main.exists():
            return main
    # Fallback copie locale dans le repo
    if REPO_DATA.exists():
        return REPO_DATA
    return None


def resolve_csv_path() -> Path:
    env = os.environ.get("TRADBOT_JOURNAL_CSV")
    if env:
        p = Path(env)
        if p.exists():
            return p
    found = find_mt5_journal_path()
    if found:
        return found
    # Créer un fichier vide avec en-tête pour démo
    REPO_DATA.parent.mkdir(parents=True, exist_ok=True)
    if not REPO_DATA.exists():
        header = (
            "close_time,trade_date,hour_utc,day_of_week,deal_ticket,position_id,symbol,"
            "category,direction,volume,open_time,close_time_full,open_price,close_price,"
            "profit,swap,commission,net_profit,duration_sec,duration_min,result,"
            "ai_confidence,ai_action,balance,equity,daily_pnl,ea_name,magic,account,comment"
        )
        REPO_DATA.write_text(header + "\n", encoding="utf-8")
    return REPO_DATA


CSV_PATH = resolve_csv_path()


def _f(val: str, default: float = 0.0) -> float:
    try:
        return float(val) if val else default
    except ValueError:
        return default


def load_trades() -> list[dict]:
    if not CSV_PATH.exists():
        return []
    trades: list[dict] = []
    with CSV_PATH.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if not row.get("symbol"):
                continue
            trades.append({
                "close_time": row.get("close_time", ""),
                "trade_date": row.get("trade_date", ""),
                "hour_utc": int(row.get("hour_utc") or 0),
                "day_of_week": row.get("day_of_week", ""),
                "deal_ticket": row.get("deal_ticket", ""),
                "position_id": row.get("position_id", ""),
                "symbol": row.get("symbol", ""),
                "category": row.get("category", ""),
                "direction": row.get("direction", ""),
                "volume": _f(row.get("volume", "0")),
                "open_time": row.get("open_time", ""),
                "close_time_full": row.get("close_time_full", row.get("close_time", "")),
                "open_price": _f(row.get("open_price", "0")),
                "close_price": _f(row.get("close_price", "0")),
                "profit": _f(row.get("profit", "0")),
                "swap": _f(row.get("swap", "0")),
                "commission": _f(row.get("commission", "0")),
                "net_profit": _f(row.get("net_profit", "0")),
                "duration_sec": int(_f(row.get("duration_sec", "0"))),
                "duration_min": _f(row.get("duration_min", "0")),
                "result": row.get("result", ""),
                "ai_confidence": _f(row.get("ai_confidence", "0")),
                "ai_action": row.get("ai_action", ""),
                "balance": _f(row.get("balance", "0")),
                "equity": _f(row.get("equity", "0")),
                "daily_pnl": _f(row.get("daily_pnl", "0")),
                "ea_name": row.get("ea_name", ""),
                "magic": row.get("magic", ""),
                "account": row.get("account", ""),
                "comment": row.get("comment", ""),
            })
    return trades


def filter_trades(trades: list[dict], params: dict) -> list[dict]:
    out = trades
    if params.get("symbol"):
        sym = params["symbol"][0].upper()
        out = [t for t in out if t["symbol"].upper() == sym]
    if params.get("category"):
        cat = params["category"][0].upper()
        out = [t for t in out if t["category"].upper() == cat]
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
        # Group by "CATEGORY:SYMBOL" for proper categorization
        sym = t["symbol"]
        cat = t["category"] or "UNKNOWN"
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

        cat = t["category"] or "UNKNOWN"
        by_category[cat]["trades"] += 1
        by_category[cat]["pnl"] += t["net_profit"]
        if t["net_profit"] > 0:
            by_category[cat]["wins"] += 1

    # Courbe d'équité cumulative
    equity = 0.0
    equity_curve = []
    for t in trades:
        equity += t["net_profit"]
        equity_curve.append({
            "time": t["close_time"],
            "equity": round(equity, 2),
            "symbol": t["symbol"],
        })

    def wr(block: dict) -> dict:
        for k, v in block.items():
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


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt: str, *args) -> None:
        pass  # silencieux

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

        if parsed.path == "/api/status":
            mtime = CSV_PATH.stat().st_mtime if CSV_PATH.exists() else 0
            return self._json({
                "csv_path": str(CSV_PATH),
                "csv_exists": CSV_PATH.exists(),
                "last_modified": datetime.fromtimestamp(mtime).isoformat() if mtime else None,
                "trade_count": len(load_trades()),
            })

        if parsed.path == "/api/trades":
            trades = filter_trades(load_trades(), params)
            return self._json({"trades": trades, "count": len(trades)})

        if parsed.path == "/api/metrics":
            trades = filter_trades(load_trades(), params)
            return self._json(compute_metrics(trades))

        if parsed.path == "/api/trades.csv":
            if not CSV_PATH.exists():
                self.send_error(404)
                return
            return self._file(CSV_PATH, "text/csv; charset=utf-8")

        self.send_error(404)


def main() -> None:
    global CSV_PATH
    CSV_PATH = resolve_csv_path()
    print("=" * 60)
    print("TradBOT — Dashboard Journal de Trades")
    print(f"  CSV  : {CSV_PATH}")
    print(f"  URL  : http://127.0.0.1:{PORT}/")
    print(f"  API  : http://127.0.0.1:{PORT}/api/metrics")
    print("=" * 60)
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nArrêt.")
        server.shutdown()


if __name__ == "__main__":
    main()
