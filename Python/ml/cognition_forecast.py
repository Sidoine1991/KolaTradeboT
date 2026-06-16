"""
Cognition forecast — direction, force, 200 bougies OHLC + quantiles.
Intégré à ai_server + EA MT5 (SMC_FuturePath).
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

try:
    from ml.pattern_memory import memory_bias_for_symbol
except ImportError:
    from python.ml.pattern_memory import memory_bias_for_symbol

DEFAULT_HORIZON = 200


@dataclass
class CognitionForecast200:
    symbol: str
    timeframe: str
    direction: str
    strength: float
    confidence: float
    atr: float
    closes: List[float]
    highs: List[float]
    lows: List[float]
    opens: List[float]
    q10: List[float]
    q90: List[float]
    patterns: List[str]
    regime: str
    horizon: int = DEFAULT_HORIZON


def _atr(df: pd.DataFrame, n: int = 14) -> float:
    h, l, c = df["high"], df["low"], df["close"]
    tr = np.maximum(h - l, np.maximum(abs(h - c.shift()), abs(l - c.shift())))
    val = tr.rolling(n).mean().iloc[-1]
    if val is None or np.isnan(val):
        return float(c.iloc[-1] * 0.001)
    return float(val)


def _pattern_tags(df: pd.DataFrame) -> Tuple[List[str], float, str]:
    tags: List[str] = []
    bias = 0.0
    if len(df) < 30:
        return tags, 0.0, "NEUTRAL"

    c0, c1 = df.iloc[-1], df.iloc[-2]
    body0 = abs(float(c0["close"]) - float(c0["open"]))
    rng20 = float(df["high"].tail(20).max() - df["low"].tail(20).min())
    rng5 = float(df["high"].tail(5).max() - df["low"].tail(5).min())

    if rng20 > 0 and rng5 < rng20 * 0.45:
        tags.append("COMPRESSION")
        bias += 0.05
    if rng20 > 0 and body0 > rng20 * 0.15:
        tags.append("EXPANSION")

    bull_engulf = (
        float(c1["close"]) < float(c1["open"])
        and float(c0["close"]) > float(c0["open"])
        and float(c0["open"]) <= float(c1["close"])
        and float(c0["close"]) >= float(c1["open"])
    )
    bear_engulf = (
        float(c1["close"]) > float(c1["open"])
        and float(c0["close"]) < float(c0["open"])
        and float(c0["open"]) >= float(c1["close"])
        and float(c0["close"]) <= float(c1["open"])
    )
    if bull_engulf:
        tags.append("BULL_ENGULF")
        bias += 0.12
    elif bear_engulf:
        tags.append("BEAR_ENGULF")
        bias -= 0.12

    hammer = (
        (min(float(c0["open"]), float(c0["close"])) - float(c0["low"])) >= body0 * 1.8
        and (float(c0["high"]) - max(float(c0["open"]), float(c0["close"]))) <= body0 * 0.6
    )
    shooting = (
        (float(c0["high"]) - max(float(c0["open"]), float(c0["close"]))) >= body0 * 1.8
        and (min(float(c0["open"]), float(c0["close"])) - float(c0["low"])) <= body0 * 0.6
    )
    if hammer and float(c0["close"]) > float(c0["open"]):
        tags.append("HAMMER")
        bias += 0.06
    elif shooting and float(c0["close"]) < float(c0["open"]):
        tags.append("SHOOTING_STAR")
        bias -= 0.06

    direction = "BUY" if bias > 0.08 else "SELL" if bias < -0.08 else "NEUTRAL"
    return tags, bias, direction


def _regime_from_gom(gom: Optional[Dict[str, Any]]) -> Tuple[str, float]:
    if not gom:
        return "UNKNOWN", 0.0
    vn = int(gom.get("verdict_num", 0) or 0)
    coh = float(gom.get("coherence_pct", 0) or 0) / 100.0
    if vn >= 2:
        return "BULL_IMPULSE", 0.25 + coh * 0.35
    if vn <= -2:
        return "BEAR_IMPULSE", -0.25 - coh * 0.35
    if vn == 1:
        return "BULL_GOOD", 0.12 + coh * 0.2
    if vn == -1:
        return "BEAR_GOOD", -0.12 - coh * 0.2
    return "WAIT", 0.0


def forecast_200(
    df: pd.DataFrame,
    symbol: str,
    timeframe: str = "M1",
    horizon: int = DEFAULT_HORIZON,
    gom: Optional[Dict[str, Any]] = None,
    bc_confidence: float = 0.0,
) -> CognitionForecast200:
    horizon = int(max(10, min(500, horizon)))

    if df is None or len(df) < 50:
        last = float(df["close"].iloc[-1]) if df is not None and len(df) else 0.0
        flat = [last] * horizon
        return CognitionForecast200(
            symbol, timeframe, "NEUTRAL", 0.0, 0.3, 0.0,
            flat, flat, flat, flat, flat, flat, [], "UNKNOWN", horizon,
        )

    if "time" in df.columns:
        df = df.sort_values("time").reset_index(drop=True)

    last_close = float(df["close"].iloc[-1])
    atr = max(_atr(df), last_close * 1e-4)

    patterns, pat_bias, pat_dir = _pattern_tags(df)
    regime, gom_bias = _regime_from_gom(gom)
    mem_bias = memory_bias_for_symbol(symbol)

    raw_force = pat_bias + gom_bias + mem_bias
    if bc_confidence >= 60:
        raw_force *= 1.08
    elif bc_confidence > 0 and bc_confidence < 45:
        raw_force *= 0.85

    strength = float(np.clip(abs(raw_force), 0.0, 1.0))
    if raw_force > 0.06:
        direction = "BUY"
    elif raw_force < -0.06:
        direction = "SELL"
    else:
        direction = pat_dir if pat_dir != "NEUTRAL" else "NEUTRAL"

    max_drift = 4.0 * atr * strength
    sign = 1.0 if direction == "BUY" else -1.0 if direction == "SELL" else 0.0

    closes: List[float] = []
    highs: List[float] = []
    lows: List[float] = []
    opens: List[float] = []
    q10: List[float] = []
    q90: List[float] = []

    rng = df["high"] - df["low"]
    wick_ratio = float(rng.tail(30).mean() / max(atr, 1e-8))

    prev_close = last_close
    for i in range(horizon):
        t = (i + 1) / horizon
        drift = sign * max_drift * (1.0 - math.exp(-3.5 * t))
        micro = math.sin(t * math.pi * 4.0) * atr * 0.15 * (1.0 - t)
        c = last_close + drift + micro
        unc = atr * (0.35 + 0.85 * t) * (1.1 - 0.3 * strength)

        o = prev_close
        h = max(o, c) + unc * wick_ratio * 0.4
        l = min(o, c) - unc * wick_ratio * 0.4

        closes.append(c)
        opens.append(o)
        highs.append(h)
        lows.append(l)
        q10.append(c - unc)
        q90.append(c + unc)
        prev_close = c

    confidence = float(np.clip(0.35 + strength * 0.45 + (bc_confidence / 100.0) * 0.15, 0.2, 0.92))

    return CognitionForecast200(
        symbol=symbol,
        timeframe=timeframe,
        direction=direction,
        strength=strength,
        confidence=confidence,
        atr=atr,
        closes=closes,
        highs=highs,
        lows=lows,
        opens=opens,
        q10=q10,
        q90=q90,
        patterns=patterns,
        regime=regime,
        horizon=horizon,
    )


def timeframe_bar_seconds(timeframe: str) -> int:
    tf = (timeframe or "M1").upper()
    mapping = {
        "M1": 60, "M5": 300, "M15": 900, "M30": 1800,
        "H1": 3600, "H4": 14400, "D1": 86400,
    }
    return mapping.get(tf, 60)


def to_mt5_payload(fc: CognitionForecast200, bar_seconds: Optional[int] = None) -> Dict[str, Any]:
    bar_sec = bar_seconds or timeframe_bar_seconds(fc.timeframe)
    candles = []
    for i in range(len(fc.closes)):
        candles.append({
            "t_offset_sec": (i + 1) * bar_sec,
            "open": fc.opens[i],
            "high": fc.highs[i],
            "low": fc.lows[i],
            "close": fc.closes[i],
            "q10": fc.q10[i],
            "q90": fc.q90[i],
        })

    return {
        "ok": True,
        "symbol": fc.symbol,
        "timeframe": fc.timeframe,
        "cog_direction": fc.direction,
        "cog_strength": round(fc.strength, 4),
        "cog_confidence": round(fc.confidence, 4),
        "cog_regime": fc.regime,
        "cog_patterns": fc.patterns,
        "cog_atr": fc.atr,
        "horizon": fc.horizon,
        "candles": candles,
        "pred_path_mid": fc.closes,
        "pred_path_up": fc.q90,
        "pred_path_dn": fc.q10,
        "cog_fc_open": fc.opens,
        "cog_fc_high": fc.highs,
        "cog_fc_low": fc.lows,
        "cog_fc_close": fc.closes,
        "cog_fc_q10": fc.q10,
        "cog_fc_q90": fc.q90,
    }
