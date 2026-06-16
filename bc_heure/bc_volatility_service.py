"""
Service Boom/Crash — heures UTC à forte volatilité (bc_heure).
Expose JSON pour ai_server + EA MT5.
"""

from __future__ import annotations

import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from bc_heure.boom_crash_analyzer import (  # noqa: E402
    BOOM_CRASH_SYMBOLS,
    COLLECTION_TIME,
    USE_SIMULATION,
    compute_confidence_scores,
    find_optimal_windows,
    generate_realistic_historical_data,
    DerivTickCollector,
)

DEFAULT_JSON = ROOT / "data" / "bc_volatility.json"
LEARNINGS_JSON = ROOT / "data" / "bc_spike_learnings.json"
FEEDBACK_JSONL = ROOT / "data" / "trade_feedback.jsonl"
MIN_CONFIDENCE_TRADE = 60.0
LEARNING_WEIGHT = 0.40  # poids des trades/spikes réels vs profil de base
MIN_SAMPLES_ADJUST = 2

# MT5 / Deriv display names → clé analyseur (tier le plus proche)
MT5_TO_BC_KEY: Dict[str, str] = {
    "BOOM1000": "BOOM1000",
    "BOOM900": "BOOM1000",
    "BOOM600": "BOOM500",
    "BOOM500": "BOOM500",
    "BOOM300": "BOOM300",
    "BOOM200": "BOOM200",
    "BOOM150": "BOOM100",
    "BOOM100": "BOOM100",
    "CRASH1000": "CRASH1000",
    "CRASH900": "CRASH1000",
    "CRASH600": "CRASH500",
    "CRASH500": "CRASH500",
    "CRASH300": "CRASH300",
    "CRASH200": "CRASH200",
    "CRASH150": "CRASH100",
    "CRASH100": "CRASH100",
}


def normalize_mt5_symbol(symbol: str) -> str:
    s = re.sub(r"[^A-Za-z0-9]", "", (symbol or "").upper())
    if not s:
        return ""
    m = re.match(r"(BOOM|CRASH)(\d+)", s)
    if m:
        return f"{m.group(1)}{m.group(2)}"
    return s


def mt5_to_bc_key(symbol: str) -> Optional[str]:
    key = normalize_mt5_symbol(symbol)
    if key in MT5_TO_BC_KEY:
        return MT5_TO_BC_KEY[key]
    if key in BOOM_CRASH_SYMBOLS:
        return key
    return None


def run_analysis(app_id: str = "1089", duration: int = COLLECTION_TIME) -> Dict[str, Any]:
    """Collecte (live ou simulée) + scores de confiance par heure UTC."""
    hourly_data: Dict[str, Any] = {}
    source = ""
    live_ok = False

    if not USE_SIMULATION:
        try:
            collector = DerivTickCollector(app_id, duration)
            live_ok = collector.run()
            if live_ok:
                hourly_data = collector.compute_hourly_volatility()
                source = f"websocket_live_ticks={sum(len(v) for v in collector.ticks.values())}"
        except Exception as exc:
            source = f"websocket_error:{exc}"

    if not live_ok or not hourly_data:
        hourly_data = generate_realistic_historical_data()
        source = "simulated_calibrated_patterns"

    scored = compute_confidence_scores(hourly_data)
    windows = find_optimal_windows(scored)

    tradeable_count = sum(
        1
        for sym_hours in scored.values()
        for h in sym_hours.values()
        if h.get("tradeable")
    )

    return {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "source": source,
        "duration_sec": duration,
        "min_confidence_trade": MIN_CONFIDENCE_TRADE,
        "tradeable_hours_total": tradeable_count,
        "symbols": list(scored.keys()),
        "hourly": scored,
        "windows": windows,
        "mt5_aliases": MT5_TO_BC_KEY,
    }


def export_json(path: Path, payload: Optional[Dict[str, Any]] = None) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = payload or run_analysis()
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return path


def load_json(path: Path = DEFAULT_JSON) -> Dict[str, Any]:
    path = Path(path)
    if not path.is_file():
        export_json(path)
    return json.loads(path.read_text(encoding="utf-8"))


def load_learnings(path: Path = LEARNINGS_JSON) -> Dict[str, Any]:
    path = Path(path)
    if not path.is_file():
        return {"updated_at": None, "hours": {}}
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {"updated_at": None, "hours": {}}


def save_learnings(data: Dict[str, Any], path: Path = LEARNINGS_JSON) -> Path:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    data["updated_at"] = datetime.now(timezone.utc).isoformat()
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    return path


def _hour_bucket(hours: Dict[str, Any], hour: int) -> Dict[str, Any]:
    key = str(int(hour) % 24)
    if key not in hours:
        hours[key] = {
            "samples": 0,
            "wins": 0,
            "losses": 0,
            "net_profit": 0.0,
            "spike_hits": 0,
        }
    return hours[key]


def _is_spike_capture(profit: float, duration_sec: Optional[float]) -> bool:
    if profit >= 1.0:
        return True
    if profit >= 0.35 and duration_sec is not None and duration_sec <= 180:
        return True
    return False


def record_trade_outcome(
    symbol: str,
    profit: float,
    *,
    hour_utc: Optional[int] = None,
    is_win: Optional[bool] = None,
    open_time: Optional[str] = None,
    close_time: Optional[str] = None,
    learnings: Optional[Dict[str, Any]] = None,
) -> bool:
    """
    Enregistre un trade clôturé pour ajuster les plages horaires au fil du temps.
    Retourne True si une entrée a été ajoutée.
    """
    bc_key = mt5_to_bc_key(symbol)
    if not bc_key:
        return False

    hour = hour_utc
    if hour is None and close_time:
        try:
            ct = datetime.fromisoformat(str(close_time).replace("Z", "+00:00"))
            if ct.tzinfo is None:
                ct = ct.replace(tzinfo=timezone.utc)
            hour = ct.astimezone(timezone.utc).hour
        except Exception:
            hour = datetime.now(timezone.utc).hour
    if hour is None:
        hour = datetime.now(timezone.utc).hour

    duration_sec = None
    if open_time and close_time:
        try:
            ot = datetime.fromisoformat(str(open_time).replace("Z", "+00:00"))
            ct = datetime.fromisoformat(str(close_time).replace("Z", "+00:00"))
            duration_sec = max(0.0, (ct - ot).total_seconds())
        except Exception:
            duration_sec = None

    p = float(profit or 0.0)
    win = bool(is_win) if is_win is not None else (p > 0)

    data = learnings if learnings is not None else load_learnings()
    sym_hours = data.setdefault("hours", {}).setdefault(bc_key, {})
    bucket = _hour_bucket(sym_hours, int(hour) % 24)
    bucket["samples"] = int(bucket.get("samples", 0)) + 1
    bucket["net_profit"] = round(float(bucket.get("net_profit", 0.0)) + p, 4)
    if win:
        bucket["wins"] = int(bucket.get("wins", 0)) + 1
    else:
        bucket["losses"] = int(bucket.get("losses", 0)) + 1
    if _is_spike_capture(p, duration_sec):
        bucket["spike_hits"] = int(bucket.get("spike_hits", 0)) + 1

    save_learnings(data)
    return True


def apply_learnings_to_scored(
    scored: Dict[str, Any],
    learnings: Dict[str, Any],
    weight: float = LEARNING_WEIGHT,
) -> Dict[str, Any]:
    """Fusionne profil horaire de base + statistiques trades/spikes observées."""
    out = json.loads(json.dumps(scored))  # deep copy
    for bc_key, sym_hours in (learnings.get("hours") or {}).items():
        if bc_key not in out:
            continue
        for hour_key, stats in sym_hours.items():
            try:
                hour = int(hour_key)
            except (TypeError, ValueError):
                continue
            hslot = out[bc_key].get(hour) or out[bc_key].get(str(hour))
            if not hslot:
                continue
            samples = int(stats.get("samples", 0) or 0)
            if samples < MIN_SAMPLES_ADJUST:
                continue
            wins = int(stats.get("wins", 0) or 0)
            losses = int(stats.get("losses", 0) or 0)
            netp = float(stats.get("net_profit", 0.0) or 0.0)
            spike_hits = int(stats.get("spike_hits", 0) or 0)
            win_rate = wins / max(1, wins + losses)

            adj = (win_rate - 0.5) * 30.0
            if netp > 0:
                adj += min(12.0, netp * 2.5)
            else:
                adj += max(-18.0, netp * 2.5)
            if spike_hits >= 2:
                adj += min(8.0, spike_hits * 1.5)

            base_conf = float(hslot.get("confidence", 50.0) or 50.0)
            merged = max(1.0, min(99.0, base_conf + adj * weight))
            hslot["confidence"] = round(merged, 1)
            hslot["tradeable"] = merged >= MIN_CONFIDENCE_TRADE
            hslot["rating"] = rating_from_conf(merged)
            hslot["learning_samples"] = samples
            hslot["learning_adj"] = round(adj * weight, 1)
            hslot["learning_spike_hits"] = spike_hits
            hslot["learning_win_rate"] = round(win_rate, 3)
    return out


def ingest_feedback_jsonl(path: Path = FEEDBACK_JSONL) -> int:
    """Bootstrap learnings depuis data/trade_feedback.jsonl (local)."""
    path = Path(path)
    if not path.is_file():
        return 0
    learnings = load_learnings()
    count = 0
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        sym = row.get("symbol") or ""
        if not mt5_to_bc_key(sym):
            continue
        if record_trade_outcome(
            sym,
            float(row.get("profit") or 0.0),
            is_win=row.get("is_win"),
            open_time=row.get("open_time"),
            close_time=row.get("close_time"),
            learnings=learnings,
        ):
            count += 1
    return count


def get_merged_cache(path: Path = DEFAULT_JSON) -> Dict[str, Any]:
    """Cache horaire = profil base + ajustements trades/spikes."""
    data = load_json(path)
    learnings = load_learnings()
    if learnings.get("hours"):
        data["hourly"] = apply_learnings_to_scored(data.get("hourly", {}), learnings)
        data["windows"] = find_optimal_windows(data["hourly"])
        data["learnings_updated_at"] = learnings.get("updated_at")
        data["learnings_applied"] = True
    else:
        data["learnings_applied"] = False
    return data


def get_bc_hour_status(
    symbol: str,
    hour_utc: Optional[int] = None,
    cache: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Statut heure courante pour un symbole MT5 Boom/Crash.
    Retourne champs plats pour payload GOM / EA.
    """
    bc_key = mt5_to_bc_key(symbol)
    if not bc_key:
        return {"bc_applicable": False}

    data = cache or get_merged_cache()
    hour = hour_utc if hour_utc is not None else datetime.now(timezone.utc).hour
    hour = int(hour) % 24

    hourly = data.get("hourly", {})
    sym_hours = hourly.get(bc_key, {})
    hour_stats = sym_hours.get(hour) or sym_hours.get(str(hour)) or {}

    windows = data.get("windows", {}).get(bc_key, [])
    best = windows[0] if windows else {}

    confidence = float(hour_stats.get("confidence", 0) or 0)
    tradeable = bool(hour_stats.get("tradeable", confidence >= MIN_CONFIDENCE_TRADE))

    return {
        "bc_applicable": True,
        "bc_mapped_key": bc_key,
        "bc_hour_utc": hour,
        "bc_confidence": round(confidence, 1),
        "bc_tradeable": tradeable,
        "bc_session": str(hour_stats.get("session", classify_session(hour))),
        "bc_rating": str(hour_stats.get("rating", rating_from_conf(confidence))),
        "bc_vol_score": float(hour_stats.get("vol_score", 0) or 0),
        "bc_window_start": best.get("start", ""),
        "bc_window_end": best.get("end", ""),
        "bc_window_avg_conf": float(best.get("avg_conf", 0) or 0),
        "bc_data_source": data.get("source", ""),
        "bc_generated_at": data.get("generated_at", ""),
        "bc_learning_samples": int(hour_stats.get("learning_samples", 0) or 0),
        "bc_learning_adj": float(hour_stats.get("learning_adj", 0) or 0),
        "bc_learnings_applied": bool(data.get("learnings_applied", False)),
    }


def classify_session(hour: int) -> str:
    if hour in range(12, 16):
        return "Overlap_L_NY"
    if hour in range(7, 16):
        return "Londres"
    if hour in range(12, 21):
        return "New_York"
    if hour in range(21, 23):
        return "Dead_Zone"
    if hour in range(0, 9):
        return "Tokyo"
    return "Unknown"


def rating_from_conf(confidence: float) -> str:
    if confidence >= 80:
        return "★★★"
    if confidence >= 60:
        return "★★"
    if confidence >= 40:
        return "★"
    return "✗"


def recommend_symbols_now(cache: Optional[Dict[str, Any]] = None, min_conf: float = MIN_CONFIDENCE_TRADE) -> list:
    """Symboles BC tradeables à l'heure UTC courante."""
    data = cache or get_merged_cache()
    hour = datetime.now(timezone.utc).hour
    out = []
    for bc_key in data.get("hourly", {}):
        st = get_bc_hour_status(bc_key, hour_utc=hour, cache=data)
        if st.get("bc_tradeable") and st.get("bc_confidence", 0) >= min_conf:
            out.append({"key": bc_key, "confidence": st["bc_confidence"], "session": st["bc_session"]})
    out.sort(key=lambda x: x["confidence"], reverse=True)
    return out


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Export bc_volatility.json pour TradBOT")
    parser.add_argument("--export", default=str(DEFAULT_JSON), help="Chemin JSON de sortie")
    parser.add_argument("--duration", type=int, default=COLLECTION_TIME)
    parser.add_argument("--app-id", default="1089")
    args = parser.parse_args()

    payload = run_analysis(app_id=args.app_id, duration=args.duration)
    out_path = export_json(Path(args.export), payload)
    print(f"OK export: {out_path} ({len(payload['hourly'])} symboles, source={payload['source']})")
