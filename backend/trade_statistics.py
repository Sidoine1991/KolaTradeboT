from __future__ import annotations

from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Iterable, Optional, Tuple


def _parse_time(value: Any) -> Optional[datetime]:
    if value is None or value == "":
        return None
    try:
        if isinstance(value, (int, float)):
            timestamp = float(value)
            if timestamp > 10**10:
                timestamp /= 1000.0
            return datetime.fromtimestamp(timestamp, timezone.utc)
        parsed = datetime.fromisoformat(str(value).replace("Z", "+00:00"))
        if parsed.tzinfo is None:
            return parsed.replace(tzinfo=timezone.utc)
        return parsed.astimezone(timezone.utc)
    except (OverflowError, OSError, TypeError, ValueError):
        return None


def _strategy_name(row: Dict[str, Any]) -> str:
    source = str(row.get("strategy") or row.get("entry_comment") or "").upper()
    if "PRE_SPIKE" in source or "PRE-SPIKE" in source:
        return "PRE_SPIKE"
    if "KOLA" in source:
        return "KOLA"
    if "DOW" in source:
        return "DOW"
    if "AUTOSCALP" in source:
        return "AUTOSCALP"
    if "GOM" in source or "SMVE" in source:
        return "GOM_LEVEL"
    return "UNKNOWN"


def _trade_identity(row: Dict[str, Any], index: int) -> Tuple[str, str]:
    position_id = row.get("position_id")
    if position_id not in (None, ""):
        return "position", str(position_id)
    ticket = row.get("deal_ticket")
    if ticket not in (None, ""):
        return "deal", str(ticket)
    return "row", str(index)


def build_strategy_trade_stats(
    rows: Iterable[Dict[str, Any]],
    days: int = 30,
    now: Optional[datetime] = None,
) -> Dict[str, Any]:
    """Aggregate net outcomes by completed position, symbol, and entry source."""
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        now = now.replace(tzinfo=timezone.utc)
    cutoff = now.astimezone(timezone.utc) - timedelta(days=max(1, days))
    trades: Dict[Tuple[str, str], Dict[str, Any]] = {}

    for index, row in enumerate(rows):
        if not isinstance(row, dict):
            continue
        try:
            profit = float(row.get("profit") or 0.0)
        except (TypeError, ValueError):
            continue
        identity = _trade_identity(row, index)
        trade = trades.get(identity)
        if trade is None:
            trade = {
                "symbol": str(row.get("symbol") or "UNKNOWN"),
                "strategy": _strategy_name(row),
                "profit": 0.0,
                "complete": identity[0] != "position",
                "open_time": None,
                "close_time": None,
            }
            trades[identity] = trade

        trade["profit"] += profit
        if row.get("position_complete") is True:
            trade["complete"] = True
        opened = _parse_time(row.get("open_time"))
        closed = _parse_time(row.get("close_time") or row.get("created_at"))
        if opened and (trade["open_time"] is None or opened < trade["open_time"]):
            trade["open_time"] = opened
        if closed and (trade["close_time"] is None or closed > trade["close_time"]):
            trade["close_time"] = closed

    groups: Dict[Tuple[str, str], Dict[str, Any]] = defaultdict(
        lambda: {
            "trades": 0,
            "wins": 0,
            "losses": 0,
            "breakeven": 0,
            "net_profit": 0.0,
            "gross_profit": 0.0,
            "gross_loss": 0.0,
            "duration_total_minutes": 0.0,
            "duration_count": 0,
        }
    )
    for trade in trades.values():
        if not trade["complete"]:
            continue
        closed = trade["close_time"]
        if closed and closed < cutoff:
            continue
        key = (trade["symbol"], trade["strategy"])
        stats = groups[key]
        profit = trade["profit"]
        stats["trades"] += 1
        stats["net_profit"] += profit
        if profit > 0:
            stats["wins"] += 1
            stats["gross_profit"] += profit
        elif profit < 0:
            stats["losses"] += 1
            stats["gross_loss"] += abs(profit)
        else:
            stats["breakeven"] += 1
        opened = trade["open_time"]
        if opened and closed and closed >= opened:
            stats["duration_total_minutes"] += (closed - opened).total_seconds() / 60.0
            stats["duration_count"] += 1

    result = []
    for (symbol, strategy), stats in groups.items():
        scored = stats["wins"] + stats["losses"]
        gross_loss = stats["gross_loss"]
        result.append({
            "symbol": symbol,
            "strategy": strategy,
            "trades": stats["trades"],
            "wins": stats["wins"],
            "losses": stats["losses"],
            "breakeven": stats["breakeven"],
            "win_rate_pct": round(stats["wins"] * 100.0 / scored, 2) if scored else 0.0,
            "net_profit": round(stats["net_profit"], 2),
            "gross_profit": round(stats["gross_profit"], 2),
            "gross_loss": round(gross_loss, 2),
            "profit_factor": round(stats["gross_profit"] / gross_loss, 3) if gross_loss else None,
            "average_profit": round(stats["net_profit"] / stats["trades"], 2),
            "average_duration_minutes": (
                round(stats["duration_total_minutes"] / stats["duration_count"], 2)
                if stats["duration_count"] else None
            ),
        })

    result.sort(key=lambda item: (item["symbol"], item["strategy"]))
    return {
        "period_days": max(1, days),
        "source": "local_trade_feedback",
        "groups": result,
    }
