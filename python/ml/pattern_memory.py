"""
Mémoire épisodique — patterns + heures UTC par symbole.
Mise à jour après chaque trade fermé (deals-upload).
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

ROOT = Path(__file__).resolve().parents[2]
MEMORY_PATH = ROOT / "data" / "cognition_pattern_memory.json"


def _empty_memory() -> Dict[str, Any]:
    return {"updated_at": None, "symbols": {}}


def load_memory(path: Path = MEMORY_PATH) -> Dict[str, Any]:
    path = Path(path)
    if not path.is_file():
        return _empty_memory()
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return _empty_memory()


def save_memory(data: Dict[str, Any], path: Path = MEMORY_PATH) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data["updated_at"] = datetime.now(timezone.utc).isoformat()
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return path


def _hour_from_close_time(close_time: Optional[str]) -> int:
    if not close_time:
        return datetime.now(timezone.utc).hour
    try:
        ct = datetime.fromisoformat(str(close_time).replace("Z", "+00:00"))
        if ct.tzinfo is None:
            ct = ct.replace(tzinfo=timezone.utc)
        return ct.astimezone(timezone.utc).hour
    except Exception:
        return datetime.now(timezone.utc).hour


def update_pattern_memory(
    symbol: str,
    profit: float,
    direction: str = "UNKNOWN",
    patterns: Optional[List[str]] = None,
    hour_utc: Optional[int] = None,
    memory: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Enregistre un trade pour ajuster bias pattern/heure."""
    data = memory if memory is not None else load_memory()
    sym_key = (symbol or "").strip()
    if not sym_key:
        return data

    hour = hour_utc if hour_utc is not None else datetime.now(timezone.utc).hour
    sym = data.setdefault("symbols", {}).setdefault(sym_key, {"hours": {}, "patterns": {}, "directions": {}})

    h = sym["hours"].setdefault(str(int(hour) % 24), {"n": 0, "wins": 0, "net": 0.0})
    h["n"] = int(h.get("n", 0)) + 1
    h["net"] = round(float(h.get("net", 0.0)) + float(profit or 0.0), 4)
    if float(profit or 0.0) > 0:
        h["wins"] = int(h.get("wins", 0)) + 1

    d = (direction or "UNKNOWN").upper()
    dstat = sym["directions"].setdefault(d, {"n": 0, "net": 0.0})
    dstat["n"] = int(dstat.get("n", 0)) + 1
    dstat["net"] = round(float(dstat.get("net", 0.0)) + float(profit or 0.0), 4)

    for p in patterns or []:
        if not p:
            continue
        pstat = sym["patterns"].setdefault(str(p), {"n": 0, "net": 0.0})
        pstat["n"] = int(pstat.get("n", 0)) + 1
        pstat["net"] = round(float(pstat.get("net", 0.0)) + float(profit or 0.0), 4)

    save_memory(data)
    return data


def update_pattern_memory_from_deal(
    symbol: str,
    profit: float,
    is_win: Optional[bool] = None,
    close_time: Optional[str] = None,
    direction: str = "UNKNOWN",
    patterns: Optional[List[str]] = None,
) -> bool:
    if not symbol:
        return False
    update_pattern_memory(
        symbol,
        float(profit or 0.0),
        direction=direction,
        patterns=patterns,
        hour_utc=_hour_from_close_time(close_time),
    )
    return True


def memory_bias_for_symbol(symbol: str, hour_utc: Optional[int] = None) -> float:
    """
    Biais directionnel -1..+1 depuis mémoire épisodique (win rate heure + patterns).
    """
    data = load_memory()
    sym = data.get("symbols", {}).get(symbol.strip())
    if not sym:
        return 0.0

    hour = int(hour_utc if hour_utc is not None else datetime.now(timezone.utc).hour) % 24
    h = sym.get("hours", {}).get(str(hour), {})
    n = int(h.get("n", 0) or 0)
    if n < 2:
        return 0.0
    wins = int(h.get("wins", 0) or 0)
    win_rate = wins / max(1, n)
    net = float(h.get("net", 0.0) or 0.0)
    bias = (win_rate - 0.5) * 0.6
    if net > 0:
        bias += min(0.15, net * 0.05)
    elif net < 0:
        bias += max(-0.2, net * 0.05)
    return float(max(-0.35, min(0.35, bias)))
