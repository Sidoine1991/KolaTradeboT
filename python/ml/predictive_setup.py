"""
Setup prédictif SMC multi-TF + orderflow pour dashboard agents et MT5.
Inspiré: structure H1/M15, zones OB/FVG, trajectoire, DOM, CVD, VWAP/POC.
"""

from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

PATH_FORECAST_BARS = 1000


def _atr(df: pd.DataFrame, n: int = 14) -> float:
    h, l, c = df["high"], df["low"], df["close"]
    tr = np.maximum(h - l, np.maximum(abs(h - c.shift()), abs(l - c.shift())))
    v = tr.rolling(n).mean().iloc[-1]
    if v is None or np.isnan(v):
        return float(c.iloc[-1] * 0.001)
    return float(v)


def _swing_structure(df: pd.DataFrame, lb: int = 5) -> Tuple[str, float, float]:
    """HH/HL = bullish, LL/LH = bearish, else NEUTRAL."""
    if df is None or len(df) < lb * 4:
        return "NEUTRAL", 0.0, 0.0

    highs: List[float] = []
    lows: List[float] = []
    for i in range(lb, len(df) - lb):
        hi = float(df["high"].iloc[i])
        lo = float(df["low"].iloc[i])
        if all(hi >= float(df["high"].iloc[i - k]) for k in range(1, lb + 1)) and all(
            hi >= float(df["high"].iloc[i + k]) for k in range(1, lb + 1)
        ):
            highs.append(hi)
        if all(lo <= float(df["low"].iloc[i - k]) for k in range(1, lb + 1)) and all(
            lo <= float(df["low"].iloc[i + k]) for k in range(1, lb + 1)
        ):
            lows.append(lo)

    if len(highs) < 2 or len(lows) < 2:
        return "NEUTRAL", highs[-1] if highs else 0.0, lows[-1] if lows else 0.0

    h1, h2 = highs[-1], highs[-2]
    l1, l2 = lows[-1], lows[-2]
    if h1 > h2 and l1 > l2:
        return "BULLISH", h1, l1
    if h1 < h2 and l1 < l2:
        return "BEARISH", h1, l1
    return "NEUTRAL", h1, l1


def _find_ob_zone(df: pd.DataFrame, bias: str) -> Optional[Dict[str, float]]:
    if df is None or len(df) < 10:
        return None
    for i in range(len(df) - 3, max(3, len(df) - 40), -1):
        o, h, l, c = (
            float(df["open"].iloc[i]),
            float(df["high"].iloc[i]),
            float(df["low"].iloc[i]),
            float(df["close"].iloc[i]),
        )
        nxt = float(df["close"].iloc[i + 1])
        if bias == "BULLISH" and c < o and nxt > h:
            return {"ob_high": h, "ob_low": l, "bar_index": i}
        if bias == "BEARISH" and c > o and nxt < l:
            return {"ob_high": h, "ob_low": l, "bar_index": i}
    return None


def _vwap(df: pd.DataFrame) -> float:
    if df is None or len(df) < 5 or "volume" not in df.columns:
        return float(df["close"].iloc[-1]) if df is not None and len(df) else 0.0
    tp = (df["high"] + df["low"] + df["close"]) / 3.0
    vol = df["volume"].astype(float).replace(0, np.nan)
    if vol.isna().all():
        return float(df["close"].iloc[-1])
    return float((tp * vol).sum() / vol.sum())


def _poc_from_profile(df: pd.DataFrame, bins: int = 40) -> float:
    if df is None or len(df) < 20:
        return 0.0
    lo = float(df["low"].min())
    hi = float(df["high"].max())
    if hi <= lo:
        return float(df["close"].iloc[-1])
    edges = np.linspace(lo, hi, bins + 1)
    vol = df["volume"].astype(float).values if "volume" in df.columns else np.ones(len(df))
    hist = np.zeros(bins)
    for i in range(len(df)):
        mid = (float(df["high"].iloc[i]) + float(df["low"].iloc[i])) / 2.0
        idx = min(bins - 1, max(0, int((mid - lo) / (hi - lo) * bins)))
        hist[idx] += vol[i] if i < len(vol) else 1.0
    best = int(np.argmax(hist))
    return float((edges[best] + edges[best + 1]) / 2.0)


def _build_dom(df_m1: pd.DataFrame, levels: int = 12) -> List[Dict[str, Any]]:
    if df_m1 is None or len(df_m1) < 5:
        return []
    px = float(df_m1["close"].iloc[-1])
    atr = _atr(df_m1)
    step = max(atr * 0.25, px * 0.0001)
    ladder: List[Dict[str, Any]] = []
    for i in range(levels, -levels - 1, -1):
        price = px + i * step
        bid_v = ask_v = 0.0
        for _, row in df_m1.tail(30).iterrows():
            if abs(float(row["low"]) - price) <= step:
                bid_v += float(row.get("volume", 1) or 1) * 0.6
            if abs(float(row["high"]) - price) <= step:
                ask_v += float(row.get("volume", 1) or 1) * 0.6
            if abs(float(row["close"]) - price) <= step:
                if float(row["close"]) >= float(row["open"]):
                    bid_v += float(row.get("volume", 1) or 1) * 0.4
                else:
                    ask_v += float(row.get("volume", 1) or 1) * 0.4
        ladder.append({
            "price": round(price, 5),
            "bid": round(bid_v, 0),
            "ask": round(ask_v, 0),
        })
    return ladder


def _time_sales(df_m1: pd.DataFrame, n: int = 15) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    if df_m1 is None:
        return out
    for _, row in df_m1.tail(n).iterrows():
        side = "BUY" if float(row["close"]) >= float(row["open"]) else "SELL"
        t = row.get("time")
        ts = t.isoformat() if hasattr(t, "isoformat") else str(t)
        out.append({
            "time": ts,
            "price": round(float(row["close"]), 5),
            "volume": round(float(row.get("volume", 0) or 0), 0),
            "side": side,
        })
    return out


def _cvd_series(df_m1: pd.DataFrame, n: int = 40) -> List[float]:
    if df_m1 is None or len(df_m1) < 5:
        return []
    cvd = 0.0
    series: List[float] = []
    for _, row in df_m1.tail(n).iterrows():
        vol = float(row.get("volume", 1) or 1)
        delta = vol if float(row["close"]) >= float(row["open"]) else -vol
        cvd += delta
        series.append(round(cvd, 2))
    return series


def _liquidity_map(df_m1: pd.DataFrame, bins: int = 24) -> List[Dict[str, Any]]:
    if df_m1 is None or len(df_m1) < 10:
        return []
    lo = float(df_m1["low"].tail(60).min())
    hi = float(df_m1["high"].tail(60).max())
    if hi <= lo:
        return []
    edges = np.linspace(lo, hi, bins + 1)
    hist = np.zeros(bins)
    vols = df_m1["volume"].astype(float).values if "volume" in df_m1.columns else np.ones(len(df_m1))
    for i in range(max(0, len(df_m1) - 60), len(df_m1)):
        mid = (float(df_m1["high"].iloc[i]) + float(df_m1["low"].iloc[i])) / 2.0
        idx = min(bins - 1, max(0, int((mid - lo) / (hi - lo) * bins)))
        hist[idx] += vols[i] if i < len(vols) else 1.0
    mx = float(hist.max()) if hist.max() > 0 else 1.0
    return [
        {
            "price": round(float((edges[i] + edges[i + 1]) / 2.0), 5),
            "intensity": round(float(hist[i] / mx), 3),
        }
        for i in range(bins)
    ]


def _project_path(
    price: float,
    direction: str,
    atr: float,
    bars: int = 30,
) -> List[Dict[str, Any]]:
    path: List[Dict[str, Any]] = []
    sign = 1.0 if direction == "BUY" else -1.0 if direction == "SELL" else 0.0
    for i in range(1, bars + 1):
        t = i / bars
        impulse = sign * atr * (0.35 + 0.9 * t)
        pullback = -sign * atr * 0.12 * math.sin(t * math.pi * 3)
        p = price + impulse + pullback
        path.append({"bar": i, "price": round(p, 5)})
    return path


def _project_path_m1(
    price: float,
    direction: str,
    atr: float,
    bars: int = PATH_FORECAST_BARS,
    df_m1: Optional[pd.DataFrame] = None,
    symbol: str = "",
    gom: Optional[Dict[str, Any]] = None,
) -> Tuple[List[Dict[str, Any]], List[float], List[float]]:
    """Trajectoire M1 longue — cognition forecast si dispo, sinon modèle analytique."""
    gom = gom or {}
    closes: List[float] = []
    q10: List[float] = []
    q90: List[float] = []
    try:
        if df_m1 is not None and len(df_m1) >= 50:
            from ml.cognition_forecast import forecast_200

            fc = forecast_200(
                df_m1,
                symbol or "SYM",
                "M1",
                horizon=bars,
                gom=gom,
                bc_confidence=float(gom.get("bc_confidence", 0) or 0),
            )
            if direction in ("BUY", "SELL") and fc.direction not in ("BUY", "SELL"):
                fc_dir = direction
            else:
                fc_dir = fc.direction if fc.direction in ("BUY", "SELL") else direction
            if fc_dir in ("BUY", "SELL") and fc.direction != fc_dir:
                sign = 1.0 if fc_dir == "BUY" else -1.0
                base = float(df_m1["close"].iloc[-1])
                closes = [base + sign * abs(c - base) for c in fc.closes]
                q10 = [base + sign * abs(q - base) for q in fc.q10]
                q90 = [base + sign * abs(q - base) for q in fc.q90]
            else:
                closes = list(fc.closes)
                q10 = list(fc.q10)
                q90 = list(fc.q90)
    except Exception:
        closes = []

    if not closes:
        closes = [p["price"] for p in _project_path(price, direction, atr, bars=bars)]
        q10 = [c - atr * 0.4 for c in closes]
        q90 = [c + atr * 0.4 for c in closes]

    path = [{"bar": i + 1, "price": round(c, 5)} for i, c in enumerate(closes[:bars])]
    return path, q10[:bars], q90[:bars]


def _infer_direction_at_index(df: pd.DataFrame, idx: int, default: str = "NEUTRAL") -> str:
    if df is None or idx < 16 or idx >= len(df):
        return default
    close = df["close"].astype(float)
    atr = _atr(df.iloc[: idx + 1])
    move = float(close.iloc[idx] - close.iloc[idx - 15])
    thr = max(atr * 0.08, 1e-8)
    if move > thr:
        return "BUY"
    if move < -thr:
        return "SELL"
    return default if default in ("BUY", "SELL") else "NEUTRAL"


def compute_path_concordance(
    df_m1: pd.DataFrame,
    path: List[Dict[str, Any]],
    trade_direction: str,
    atr: float,
    bars: int = PATH_FORECAST_BARS,
) -> Dict[str, Any]:
    """
    Probabilité que le prix respecte la trajectoire projetée.
    1) Backtest roulant : à chaque ancre historique, même formule de path → comparer au réel.
    2) Concordance trajectoire : quand le prix passé était sur le même niveau que le path actuel,
       le futur a-t-il suivi la suite du path ?
    """
    empty = {
        "concordance_pct": 0.0,
        "historical_respect_pct": 0.0,
        "trajectory_respect_pct": 0.0,
        "live_respect_pct": 0.0,
        "samples_historical": 0,
        "samples_trajectory": 0,
        "samples_live": 0,
        "path_bars": bars,
        "path_tf": "M1",
    }
    if df_m1 is None or len(df_m1) < 80 or not path:
        return empty

    if "time" in df_m1.columns:
        df_m1 = df_m1.sort_values("time").reset_index(drop=True)

    closes = df_m1["close"].astype(float).values
    n = len(closes)
    path_prices = [float(p.get("price", 0)) for p in path if p.get("price")]
    if not path_prices:
        return empty

    d = (trade_direction or "NEUTRAL").upper()
    max_fwd = min(bars, 120)

    # --- 1) Backtest roulant ---
    hist_hits = hist_total = 0
    anchor_stride = 15
    max_anchors = 60
    start_anchor = max(50, n - max_fwd - 1)
    end_anchor = max(50, n - 2500)
    anchors_done = 0
    for anchor in range(start_anchor, end_anchor, -anchor_stride):
        if anchors_done >= max_anchors:
            break
        local_dir = _infer_direction_at_index(df_m1, anchor, d)
        if local_dir == "NEUTRAL":
            local_dir = d if d in ("BUY", "SELL") else "BUY"
        local_atr = _atr(df_m1.iloc[max(0, anchor - 40): anchor + 1])
        fwd_bars = min(max_fwd, n - anchor - 1)
        if fwd_bars < 10:
            continue
        hist_path = _project_path(float(closes[anchor]), local_dir, local_atr, bars=fwd_bars)
        for j in range(1, len(hist_path) + 1):
            if anchor + j >= n:
                break
            pred = float(hist_path[j - 1]["price"])
            actual = float(closes[anchor + j])
            tol = local_atr * (0.22 + 0.78 * j / max(fwd_bars, 1))
            hist_total += 1
            if abs(actual - pred) <= tol:
                hist_hits += 1
        anchors_done += 1

    historical_pct = (hist_hits / hist_total * 100.0) if hist_total > 0 else 0.0

    # --- 2) Même trajectoire : prix passé sur le path actuel ---
    traj_hits = traj_total = 0
    tol_on_path = max(atr * 0.35, 1e-8)
    scan_start = max(0, n - min(2000, n - 20))
    for anchor in range(scan_start, n - 8):
        px = float(closes[anchor])
        for k, target in enumerate(path_prices[: min(200, len(path_prices))]):
            if abs(px - target) > tol_on_path:
                continue
            for fwd in range(1, min(25, n - anchor - 1, len(path_prices) - k)):
                pred_fwd = path_prices[k + fwd - 1] if (k + fwd - 1) < len(path_prices) else None
                if pred_fwd is None:
                    break
                actual_fwd = float(closes[anchor + fwd])
                tol = atr * (0.28 + 0.5 * fwd / 25.0)
                traj_total += 1
                if abs(actual_fwd - pred_fwd) <= tol:
                    traj_hits += 1

    trajectory_pct = (traj_hits / traj_total * 100.0) if traj_total > 0 else historical_pct

    # --- 3) Live : dernières bougies vs début du path ---
    live_hits = live_total = 0
    live_window = min(40, len(path_prices), n - 1)
    for j in range(1, live_window + 1):
        idx = n - live_window + j - 1
        if idx < 0 or idx >= n:
            continue
        pred = path_prices[j - 1]
        actual = float(closes[idx])
        tol = atr * (0.2 + 0.45 * j / max(live_window, 1))
        live_total += 1
        if abs(actual - pred) <= tol:
            live_hits += 1

    live_pct = (live_hits / live_total * 100.0) if live_total > 0 else 0.0

    if traj_total > 0 and hist_total > 0:
        combined = trajectory_pct * 0.45 + historical_pct * 0.35 + live_pct * 0.20
    elif traj_total > 0:
        combined = trajectory_pct * 0.65 + live_pct * 0.35
    elif hist_total > 0:
        combined = historical_pct * 0.75 + live_pct * 0.25
    else:
        combined = live_pct

    return {
        "concordance_pct": round(float(np.clip(combined, 0, 100)), 1),
        "historical_respect_pct": round(historical_pct, 1),
        "trajectory_respect_pct": round(trajectory_pct, 1),
        "live_respect_pct": round(live_pct, 1),
        "samples_historical": hist_total,
        "samples_trajectory": traj_total,
        "samples_live": live_total,
        "path_bars": bars,
        "path_tf": "M1",
    }


def apply_trade_projection(
    panel: Dict[str, Any],
    trade_direction: str,
    gom: Optional[Dict[str, Any]] = None,
    df_m1: Optional[pd.DataFrame] = None,
    path_bars: int = PATH_FORECAST_BARS,
) -> Dict[str, Any]:
    """Aligne direction affichée, SL/TP et trajectoire avec le signal trade effectif."""
    gom = gom or {}
    d = (trade_direction or "HOLD").upper()
    if d not in ("BUY", "SELL"):
        return panel

    price = float(panel.get("price") or gom.get("price") or gom.get("close") or 0)
    if price <= 0:
        return panel

    atr_m1 = _atr(df_m1) if df_m1 is not None and len(df_m1) >= 14 else 0.0
    atr = float(gom.get("atr") or gom.get("atr14") or atr_m1 or 0)
    if atr <= 0:
        atr = price * 0.001

    panel["direction"] = d
    panel["trade_direction"] = d

    setup_entry = float(gom.get("setup_entry") or 0)
    setup_sl = float(gom.get("setup_sl") or gom.get("sl") or 0)
    setup_tp1 = float(gom.get("setup_tp1") or gom.get("tp") or 0)
    setup_tp2 = float(gom.get("setup_tp2") or 0)

    entry = price
    sl = tp1 = tp2 = price

    use_setup = (
        setup_entry > 0 and setup_sl > 0 and setup_tp1 > 0
        and (
            (d == "BUY" and setup_tp1 > setup_entry and setup_sl < setup_entry)
            or (d == "SELL" and setup_tp1 < setup_entry and setup_sl > setup_entry)
        )
    )
    if use_setup:
        entry, sl, tp1 = setup_entry, setup_sl, setup_tp1
        tp2 = setup_tp2 if setup_tp2 > 0 else setup_tp1
    else:
        levels = panel.get("levels") or []
        lows = [float(l["price"]) for l in levels if l.get("price")]
        swing_low = min(lows) if lows else price - atr * 3
        swing_high = max(lows) if lows else price + atr * 3
        range_h = max(swing_high - swing_low, atr * 2)
        entry = price
        if d == "BUY":
            sl = round(min(swing_low - atr * 0.3, price - atr * 1.2), 5)
            tp1 = round(max(price + range_h * 0.45, price + atr * 1.5), 5)
            tp2 = round(max(price + range_h * 0.85, tp1 + atr), 5)
        else:
            sl = round(max(swing_high + atr * 0.3, price + atr * 1.2), 5)
            tp1 = round(min(price - range_h * 0.45, price - atr * 1.5), 5)
            tp2 = round(min(price - range_h * 0.85, tp1 - atr), 5)

    sym = str(panel.get("symbol") or gom.get("symbol") or "")
    path, q10, q90 = _project_path_m1(entry, d, atr, bars=path_bars, df_m1=df_m1, symbol=sym, gom=gom)

    concordance = (
        compute_path_concordance(df_m1, path, d, atr, bars=path_bars)
        if df_m1 is not None and len(df_m1) >= 120
        else {}
    )

    panel["projection"] = {
        "path": path,
        "path_bars": path_bars,
        "path_tf": "M1",
        "path_q10": [round(v, 5) for v in q10],
        "path_q90": [round(v, 5) for v in q90],
        "tp1": round(tp1, 5),
        "tp2": round(tp2, 5),
        "sl": round(sl, 5),
        "entry": round(entry, 5),
        "concordance": concordance,
    }
    return panel


def _enrich_orderflow_with_gom(orderflow: Dict[str, Any], gom: Dict[str, Any]) -> Dict[str, Any]:
    """Merge real GHOST/TV orderflow from GOM store when available."""
    ghost_delta = gom.get("ghost_delta")
    ghost_cvd = gom.get("ghost_cvd")
    ghost_buypct = gom.get("ghost_buypct")
    ghost_compass = gom.get("ghost_compass")
    gom_vwap = gom.get("vwap")

    has_ghost = any(v is not None for v in (ghost_delta, ghost_cvd, ghost_buypct, ghost_compass))

    if gom_vwap and float(gom_vwap) > 0:
        orderflow["vwap"] = round(float(gom_vwap), 5)
        orderflow["vwap_source"] = "gom"

    if has_ghost:
        orderflow["ghost"] = {
            "delta": ghost_delta,
            "cvd": ghost_cvd,
            "buypct": ghost_buypct,
            "compass": ghost_compass,
        }
        orderflow["source"] = "ghost"

        if ghost_cvd is not None:
            series = orderflow.get("cvd_series") or []
            if series:
                offset = float(ghost_cvd) - series[-1]
                orderflow["cvd_series"] = [round(v + offset, 2) for v in series]
            else:
                orderflow["cvd_series"] = [float(ghost_cvd)]

        if ghost_buypct is not None:
            bp = float(ghost_buypct)
            if bp >= 55:
                orderflow["trend_label"] = f"PRESSION ACHETEUSE ({bp:.0f}%)"
            elif bp <= 45:
                orderflow["trend_label"] = f"PRESSION VENDEUSE ({100 - bp:.0f}%)"
            else:
                orderflow["trend_label"] = f"EQUILIBRE ({bp:.0f}% buy)"

        if ghost_delta is not None:
            d = float(ghost_delta)
            orderflow["last_delta"] = {
                "side": "BUY" if d > 0 else "SELL" if d < 0 else "NEUTRAL",
                "delta": ghost_delta,
            }
    else:
        orderflow["source"] = "proxy"

    return orderflow


def build_predictive_panel(
    symbol: str,
    df_h1: Optional[pd.DataFrame],
    df_m15: Optional[pd.DataFrame],
    df_m5: Optional[pd.DataFrame],
    df_m1: Optional[pd.DataFrame],
    gom: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    gom = gom or {}
    base_df = df_m15 if df_m15 is not None and len(df_m15) >= 30 else df_m1
    if base_df is None or len(base_df) < 20:
        return {"ok": False, "symbol": symbol, "error": "candles_insuffisantes"}

    price = float(base_df["close"].iloc[-1])
    atr_m15 = _atr(base_df)

    h1_bias, h1_sh, h1_sl = _swing_structure(df_h1, lb=4) if df_h1 is not None else ("NEUTRAL", 0.0, 0.0)
    m15_bias, m15_sh, m15_sl = _swing_structure(df_m15 if df_m15 is not None else base_df, lb=3)
    m5_bias, _, _ = _swing_structure(df_m5 if df_m5 is not None else base_df, lb=3)

    # Setup haussier M15 dans structure H1 baissière = reversal play (image TikTok)
    play_bias = m15_bias
    if play_bias == "NEUTRAL":
        play_bias = "BULLISH" if float(base_df["close"].iloc[-1]) > float(base_df["close"].iloc[-8]) else "BEARISH"

    direction = "BUY" if play_bias == "BULLISH" else "SELL" if play_bias == "BEARISH" else "NEUTRAL"
    vn = int(gom.get("verdict_num", 0) or 0)
    if vn > 0:
        direction = "BUY"
    elif vn < 0:
        direction = "SELL"

    ob = _find_ob_zone(df_m15 if df_m15 is not None else base_df, play_bias)
    zones: List[Dict[str, Any]] = []
    if ob:
        zones.append({
            "type": "OB_BULL" if play_bias == "BULLISH" else "OB_BEAR",
            "high": round(ob["ob_high"], 5),
            "low": round(ob["ob_low"], 5),
            "tf": "M15",
        })

    swing_low = float(base_df["low"].tail(30).min())
    swing_high = float(base_df["high"].tail(30).max())
    range_h = swing_high - swing_low
    if direction == "BUY":
        sl = round(swing_low - atr_m15 * 0.3, 5)
        tp1 = round(price + range_h * 0.45, 5)
        tp2 = round(price + range_h * 0.85, 5)
    elif direction == "SELL":
        sl = round(swing_high + atr_m15 * 0.3, 5)
        tp1 = round(price - range_h * 0.45, 5)
        tp2 = round(price - range_h * 0.85, 5)
    else:
        sl = tp1 = tp2 = price

    path, _, _ = _project_path_m1(price, direction, atr_m15, bars=PATH_FORECAST_BARS, df_m1=df_m1, symbol=symbol, gom=gom)

    forming = (
        h1_bias != m15_bias
        and m15_bias in ("BULLISH", "BEARISH")
        and ob is not None
    )
    active = forming and direction in ("BUY", "SELL")
    alert = "ACTIVE" if active else "FORMING" if forming else "NONE"

    vwap = _vwap(df_m1 if df_m1 is not None else base_df)
    poc = _poc_from_profile(df_h1 if df_h1 is not None and len(df_h1) >= 20 else base_df)

    return {
        "ok": True,
        "symbol": symbol,
        "price": round(price, 5),
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "alert": alert,
        "direction": direction,
        "structure": {
            "h1": {
                "bias": h1_bias,
                "label": f"STRUCTURE {'BAISSIERE' if h1_bias == 'BEARISH' else 'HAUSSIERE' if h1_bias == 'BULLISH' else 'NEUTRE'} H1",
                "swing_high": round(h1_sh, 5) if h1_sh else None,
                "swing_low": round(h1_sl, 5) if h1_sl else None,
            },
            "m15": {
                "bias": m15_bias,
                "label": f"Structure {'haussiere' if m15_bias == 'BULLISH' else 'baissiere' if m15_bias == 'BEARISH' else 'neutre'} M15",
            },
            "m5": {"bias": m5_bias},
            "play": play_bias,
            "counter_trend": h1_bias != m15_bias and h1_bias != "NEUTRAL" and m15_bias != "NEUTRAL",
        },
        "zones": zones,
        "levels": [
            {"price": round(swing_low, 5), "label": "Low H1 - M15", "role": "support"},
            {"price": round(swing_high, 5), "label": "High récent", "role": "resistance"},
        ],
        "projection": {
            "path": path,
            "path_bars": PATH_FORECAST_BARS,
            "path_tf": "M1",
            "tp1": tp1,
            "tp2": tp2,
            "sl": sl,
            "entry": round(price, 5),
            "concordance": compute_path_concordance(df_m1, path, direction, atr_m15)
            if df_m1 is not None and len(df_m1) >= 120
            else {},
        },
        "orderflow": _enrich_orderflow_with_gom({
            "dom": _build_dom(df_m1),
            "time_sales": _time_sales(df_m1),
            "liquidity_map": _liquidity_map(df_m1),
            "cvd_series": _cvd_series(df_m1),
            "vwap": round(vwap, 5),
            "poc_htf": round(poc, 5),
            "trend_label": "TENDANCE VOLATIL" if atr_m15 / max(price, 1e-8) > 0.0015 else "TENDANCE CALME",
        }, gom),
        "gom": {
            "verdict": gom.get("verdict", "WAIT"),
            "verdict_num": vn,
            "coherence_pct": gom.get("coherence_pct", 0),
            "cog_direction": gom.get("cog_direction", "NEUTRAL"),
            "cog_direction_5m": gom.get("cog_direction_5m", gom.get("cog_direction", "NEUTRAL")),
            "cog_direction_15m": gom.get("cog_direction_15m", gom.get("cog_direction", "NEUTRAL")),
            "cog_confidence_pct": round(float(gom.get("cog_confidence", 0) or 0) * 100, 1),
            "cog_strength_pct": round(float(gom.get("cog_strength", 0) or 0) * 100, 1),
            "cog_short_agreement_pct": round(float(gom.get("cog_short_agreement", 0) or 0) * 100, 1),
        },
    }
