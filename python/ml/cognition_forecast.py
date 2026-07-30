"""
Cognition forecast — direction, force, 200 bougies OHLC + quantiles.
Intégré à ai_server + EA MT5 (SMC_FuturePath).
"""

from __future__ import annotations

import math
import os
import urllib.request
import urllib.parse
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
SHORT_HORIZON_5 = 5
SHORT_HORIZON_15 = 15


@dataclass
class ShortHorizonForecast:
    direction_5m: str
    direction_15m: str
    direction: str
    slope_5m: float
    slope_15m: float
    strength: float
    confidence: float
    agreement: float
    closes_15: List[float]
    signals: Dict[str, float]


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


def _rsi(close: pd.Series, n: int = 14) -> float:
    delta = close.diff()
    gain = delta.clip(lower=0).rolling(n).mean()
    loss = (-delta.clip(upper=0)).rolling(n).mean()
    rs = gain / loss.replace(0, np.nan)
    val = 100.0 - (100.0 / (1.0 + rs))
    last = val.iloc[-1]
    if last is None or np.isnan(last):
        return 50.0
    return float(last)


def _ema_series(close: pd.Series, n: int) -> pd.Series:
    return close.ewm(span=n, adjust=False).mean()


def _resample_m5(df: pd.DataFrame) -> pd.DataFrame:
    if len(df) < 30:
        return df
    work = df.copy()
    if "time" in work.columns:
        work = work.sort_values("time")
        work["time"] = pd.to_datetime(work["time"], utc=True, errors="coerce")
        work = work.dropna(subset=["time"]).set_index("time")
    else:
        work = work.reset_index(drop=True)
        work.index = pd.date_range(end=datetime.now(timezone.utc), periods=len(work), freq="min")
    ohlc = work.resample("5min").agg(
        {"open": "first", "high": "max", "low": "min", "close": "last"}
    ).dropna()
    if "volume" in work.columns:
        vol = work["volume"].resample("5min").sum()
        ohlc["volume"] = vol
    return ohlc.reset_index(drop=True)


def _dir_from_move(move: float, atr: float, min_atr_frac: float = 0.08) -> str:
    thr = max(atr * min_atr_frac, 1e-8)
    if move > thr:
        return "BUY"
    if move < -thr:
        return "SELL"
    return "NEUTRAL"


def _clip_score(v: float) -> float:
    return float(np.clip(v, -1.0, 1.0))


def forecast_short_horizon(
    df: pd.DataFrame,
    symbol: str,
    gom: Optional[Dict[str, Any]] = None,
    bc_confidence: float = 0.0,
) -> ShortHorizonForecast:
    """
    Prévision directionnelle 5/15 prochaines minutes (barres M1).
    Combine momentum, EMA M1/M5, RSI, patterns, volume — GOM en poids faible.
    """
    flat = ShortHorizonForecast(
        "NEUTRAL", "NEUTRAL", "NEUTRAL", 0.0, 0.0, 0.0, 0.3, 0.0, [], {}
    )
    if df is None or len(df) < 40:
        return flat

    if "time" in df.columns:
        df = df.sort_values("time").reset_index(drop=True)

    close = df["close"].astype(float)
    last_close = float(close.iloc[-1])
    atr = max(_atr(df), last_close * 1e-4)

    patterns, pat_bias, _ = _pattern_tags(df)
    _, gom_bias = _regime_from_gom(gom)
    gom_bias = _clip_score(gom_bias * 0.35)  # évite circularité GOM→COG→GOM
    mem_bias = _clip_score(memory_bias_for_symbol(symbol) * 0.5)

    ret5 = float(close.iloc[-1] - close.iloc[-6]) if len(close) > 6 else 0.0
    ret15 = float(close.iloc[-1] - close.iloc[-16]) if len(close) > 16 else 0.0
    mom5 = _clip_score(ret5 / atr)
    mom15 = _clip_score(ret15 / (atr * 1.5))

    ema9 = _ema_series(close, 9)
    ema21 = _ema_series(close, 21)
    ema_slope = float(ema9.iloc[-1] - ema9.iloc[-5]) if len(ema9) > 5 else 0.0
    ema_align = 1.0 if ema9.iloc[-1] > ema21.iloc[-1] else -1.0 if ema9.iloc[-1] < ema21.iloc[-1] else 0.0
    ema_score = _clip_score(ema_align * 0.55 + _clip_score(ema_slope / atr) * 0.45)

    rsi = _rsi(close)
    if rsi >= 60:
        rsi_score = _clip_score((rsi - 50) / 35.0)
    elif rsi <= 40:
        rsi_score = _clip_score((rsi - 50) / 35.0)
    else:
        rsi_score = 0.0

    vol_score = 0.0
    if "volume" in df.columns and len(df) >= 25:
        vol = df["volume"].astype(float)
        recent = float(vol.iloc[-5:].mean())
        base = float(vol.iloc[-25:-5].mean())
        if base > 0 and recent > base * 1.25:
            vol_score = _clip_score(mom5 * 0.8)

    m5_score = 0.0
    df_m5 = _resample_m5(df)
    if len(df_m5) >= 12:
        c5 = df_m5["close"].astype(float)
        e5_9 = _ema_series(c5, 9)
        e5_21 = _ema_series(c5, 21)
        px = float(c5.iloc[-1])
        ema5 = float(e5_9.iloc[-1])
        slope5 = float(e5_9.iloc[-1] - e5_9.iloc[-3]) if len(e5_9) > 3 else 0.0
        if px >= ema5 and e5_9.iloc[-1] > e5_21.iloc[-1]:
            m5_score = _clip_score(0.5 + slope5 / atr)
        elif px <= ema5 and e5_9.iloc[-1] < e5_21.iloc[-1]:
            m5_score = _clip_score(-0.5 + slope5 / atr)

    bc_mult = 1.0
    if bc_confidence >= 60:
        bc_mult = 1.06
    elif 0 < bc_confidence < 45:
        bc_mult = 0.92

    signals = {
        "mom5": mom5,
        "mom15": mom15,
        "ema_m1": ema_score,
        "rsi": rsi_score,
        "pattern": _clip_score(pat_bias * 2.5),
        "ema_m5": m5_score,
        "volume": vol_score,
        "gom": gom_bias,
        "memory": mem_bias,
    }

    weights = {
        "mom5": 0.22,
        "mom15": 0.18,
        "ema_m1": 0.18,
        "rsi": 0.10,
        "pattern": 0.10,
        "ema_m5": 0.14,
        "volume": 0.04,
        "gom": 0.02,
        "memory": 0.02,
    }
    raw = sum(signals[k] * weights[k] for k in weights) * bc_mult
    raw = _clip_score(raw)
    strength = float(abs(raw))

    # Projection 15 barres M1 — drift + retour micro vers EMA
    closes_15: List[float] = []
    prev = last_close
    ema_now = float(ema9.iloc[-1])
    for i in range(SHORT_HORIZON_15):
        t = (i + 1) / SHORT_HORIZON_15
        drift = raw * atr * (0.25 + 0.55 * t)
        pull = (ema_now - prev) * 0.08 * (1.0 - t)
        nxt = prev + drift + pull
        closes_15.append(nxt)
        prev = nxt

    slope_5m = closes_15[SHORT_HORIZON_5 - 1] - last_close
    slope_15m = closes_15[SHORT_HORIZON_15 - 1] - last_close
    dir_5m = _dir_from_move(slope_5m, atr)
    dir_15m = _dir_from_move(slope_15m, atr)

    bullish_votes = sum(1 for s in signals.values() if s > 0.12)
    bearish_votes = sum(1 for s in signals.values() if s < -0.12)
    agreement = abs(bullish_votes - bearish_votes) / max(1, len(signals))

    if raw > 0.10:
        direction = "BUY"
    elif raw < -0.10:
        direction = "SELL"
    elif dir_5m == dir_15m and dir_5m != "NEUTRAL":
        direction = dir_5m
    else:
        direction = "NEUTRAL"

    if dir_5m != "NEUTRAL" and dir_15m != "NEUTRAL" and dir_5m != dir_15m:
        strength *= 0.55
        agreement *= 0.5

    # Confiance = alignement des signaux avec la direction finale (0-1 → affiché en %)
    dir_sign = 1.0 if direction == "BUY" else -1.0 if direction == "SELL" else 0.0
    if dir_sign != 0.0:
        aligned_weight = sum(
            weights[k] for k in weights
            if (signals[k] > 0.05) == (dir_sign > 0) or abs(signals[k]) <= 0.05
        )
        conflict_weight = sum(
            weights[k] for k in weights
            if (signals[k] > 0.12 and dir_sign < 0) or (signals[k] < -0.12 and dir_sign > 0)
        )
        align_ratio = aligned_weight / max(sum(weights.values()), 1e-8)
        confidence = float(np.clip(
            0.32 + strength * 0.38 + agreement * 0.18 + align_ratio * 0.22 - conflict_weight * 0.35,
            0.15,
            0.96,
        ))
    else:
        confidence = float(np.clip(
            0.25 + strength * 0.25 + agreement * 0.15,
            0.15,
            0.55,
        ))
    confidence = float(np.clip(
        confidence + (bc_confidence / 100.0) * 0.06,
        0.15,
        0.96,
    ))

    return ShortHorizonForecast(
        direction_5m=dir_5m,
        direction_15m=dir_15m,
        direction=direction,
        slope_5m=float(slope_5m),
        slope_15m=float(slope_15m),
        strength=strength,
        confidence=confidence,
        agreement=float(agreement),
        closes_15=closes_15,
        signals=signals,
    )


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
    horizon = int(max(10, min(1500, horizon)))

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

    short = forecast_short_horizon(df, symbol, gom, bc_confidence)
    direction = short.direction
    strength = short.strength
    confidence = short.confidence

    if direction == "NEUTRAL":
        mem_bias = memory_bias_for_symbol(symbol)
        raw_force = pat_bias + gom_bias * 0.35 + mem_bias * 0.5
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
        confidence = float(np.clip(0.35 + strength * 0.45 + (bc_confidence / 100.0) * 0.15, 0.2, 0.92))

    max_drift = 4.0 * atr * max(strength, 0.15)
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
        if i < len(short.closes_15):
            c = short.closes_15[i]
            unc = atr * 0.35
        else:
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

    confidence = float(np.clip(confidence, 0.2, 0.94))

    fc = CognitionForecast200(
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
    return fc


def short_horizon_to_fields(sh: ShortHorizonForecast) -> Dict[str, Any]:
    conf_pct = round(sh.confidence * 100, 1)
    return {
        "cog_direction": sh.direction,
        "cog_direction_5m": sh.direction_5m,
        "cog_direction_15m": sh.direction_15m,
        "cog_slope_5m": round(sh.slope_5m, 6),
        "cog_slope_15m": round(sh.slope_15m, 6),
        "cog_strength": round(sh.strength, 4),
        "cog_confidence": round(sh.confidence, 4),
        "cog_confidence_pct": conf_pct,
        "cog_strength_pct": round(sh.strength * 100, 1),
        "cog_short_confidence": round(sh.confidence, 4),
        "cog_short_confidence_pct": conf_pct,
        "cog_short_agreement": round(sh.agreement, 4),
        "cog_short_agreement_pct": round(sh.agreement * 100, 1),
        "pred_path_short": sh.closes_15,
    }


def to_mt5_payload(
    fc: CognitionForecast200,
    bar_seconds: Optional[int] = None,
    short: Optional[ShortHorizonForecast] = None,
) -> Dict[str, Any]:
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

    payload = {
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
    if short is not None:
        payload.update(short_horizon_to_fields(short))
        if short.direction != "NEUTRAL":
            payload["cog_direction"] = short.direction
            payload["cog_strength"] = round(short.strength, 4)
            payload["cog_confidence"] = round(short.confidence, 4)
    return payload


def timeframe_bar_seconds(timeframe: str) -> int:
    tf = (timeframe or "M1").upper()
    mapping = {
        "M1": 60, "M5": 300, "M15": 900, "M30": 1800,
        "H1": 3600, "H4": 14400, "D1": 86400,
    }
    return mapping.get(tf, 60)


def get_historical_data_mt5(symbol: str, timeframe: str = "H1", count: int = 500):
    """Récupère les données historiques depuis MT5 via l'API HTTP."""
    import json
    try:
        port = os.environ.get("MT5_API_PORT", "5000")
        req = urllib.request.Request(
            f"http://127.0.0.1:{port}/api/rates?symbol={urllib.parse.quote(symbol)}&timeframe={timeframe}&count={count}",
            method="GET",
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        if not data.get("ok") or "rates" not in data:
            return None
        df = pd.DataFrame(data["rates"])
        if "time" in df.columns:
            df["time"] = pd.to_datetime(df["time"])
        return df
    except Exception:
        return None
