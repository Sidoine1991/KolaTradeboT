"""
Divergence trading strategy (production) for Deriv synthetic symbols.
div_score = EWM(dP + dQ + dR) with trend + volatility filters.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional, Tuple

import numpy as np
import pandas as pd

TRAIL_FACTOR = 1.2

DEFAULT_PARAMS: Dict[str, Any] = {
    "window": 14,
    "ema_fast": 50,
    "ema_slow": 200,
    "div_long": 0.15,
    "div_short": -0.15,
    "stop_mult": 1.5,
    "tp_mult": 2.5,
    "use_trend": True,
    "use_vol_filter": True,
    "min_vol": 0.005,
    "min_bars": 80,
    "min_confidence": 0.55,
}


@dataclass
class DivergenceSignal:
    action: str  # buy | sell | hold
    confidence: float
    reason: str
    stop_loss: Optional[float] = None
    take_profit: Optional[float] = None
    entry_price: Optional[float] = None
    div_score: float = 0.0
    metadata: Dict[str, Any] = field(default_factory=dict)


def compute_indicators(
    df: pd.DataFrame,
    window: int = 14,
    ema_fast: int = 50,
    ema_slow: int = 200,
) -> pd.DataFrame:
    """Compute divergence field and filters (requires OHLCV columns)."""
    d = df.copy()
    for col in ("Open", "High", "Low", "Close"):
        if col not in d.columns and col.lower() in d.columns:
            d[col] = d[col.lower()]

    if "Volume" not in d.columns:
        d["Volume"] = 1.0
    if "volume" in d.columns and "Volume" not in d.columns:
        d["Volume"] = d["volume"]

    roc = d["Close"].pct_change(window)
    roc_std = roc.rolling(window * 4).std()
    d["dP"] = (roc / (roc_std + 1e-9)).clip(-3, 3) / 3

    vm = d["Volume"].rolling(window * 3).mean()
    vs = d["Volume"].rolling(window * 3).std()
    d["dQ"] = ((d["Volume"] - vm) / (vs + 1e-9)).clip(-3, 3) / 3

    delta = d["Close"].diff()
    gain = delta.clip(lower=0).rolling(window).mean()
    loss = (-delta.clip(upper=0)).rolling(window).mean()
    d["RSI"] = 100 - (100 / (1 + gain / (loss + 1e-9)))
    d["dR"] = d["RSI"].diff(window) / 100

    d["div_raw"] = d["dP"] + d["dQ"] + d["dR"]
    d["div_score"] = d["div_raw"].ewm(span=5, adjust=False).mean()

    d["EMA_fast"] = d["Close"].ewm(span=ema_fast, adjust=False).mean()
    d["EMA_slow"] = d["Close"].ewm(span=ema_slow, adjust=False).mean()
    d["trend_up"] = (d["Close"] > d["EMA_fast"]) & (d["EMA_fast"] > d["EMA_slow"])
    d["trend_dn"] = (d["Close"] < d["EMA_fast"]) & (d["EMA_fast"] < d["EMA_slow"])

    tr = pd.concat(
        [
            d["High"] - d["Low"],
            (d["High"] - d["Close"].shift()).abs(),
            (d["Low"] - d["Close"].shift()).abs(),
        ],
        axis=1,
    ).max(axis=1)
    d["ATR"] = tr.rolling(window).mean()
    d["vol_regime"] = d["Close"].pct_change().rolling(20).std()
    d["div_confirm_up"] = (d["div_score"] > 0).rolling(3).sum() >= 2
    d["div_confirm_dn"] = (d["div_score"] < 0).rolling(3).sum() >= 2

    return d.dropna()


def candles_to_dataframe(candles: List[Any]) -> pd.DataFrame:
    """Build OHLCV DataFrame from MT5 recent_candles [{o,h,l,c}, ...]."""
    rows = []
    for c in candles:
        if hasattr(c, "o"):
            o, h, l, cl = float(c.o), float(c.h), float(c.l), float(c.c)
        elif isinstance(c, dict):
            o = float(c.get("o") or c.get("open") or 0)
            h = float(c.get("h") or c.get("high") or 0)
            l = float(c.get("l") or c.get("low") or 0)
            cl = float(c.get("c") or c.get("close") or 0)
        else:
            continue
        if cl <= 0:
            continue
        rows.append({"Open": o, "High": h, "Low": l, "Close": cl, "Volume": 1.0})
    if not rows:
        return pd.DataFrame()
    return pd.DataFrame(rows)


def evaluate_live_signal(
    df: pd.DataFrame,
    bid: Optional[float] = None,
    ask: Optional[float] = None,
    params: Optional[Dict[str, Any]] = None,
) -> DivergenceSignal:
    """Evaluate the latest bar only (live /decision path)."""
    p = {**DEFAULT_PARAMS, **(params or {})}
    min_bars = int(p.get("min_bars", 80))
    if df is None or len(df) < min_bars:
        return DivergenceSignal(
            action="hold",
            confidence=0.0,
            reason=f"Divergence: données insuffisantes ({len(df) if df is not None else 0}<{min_bars} barres)",
        )

    ind = compute_indicators(
        df,
        window=int(p["window"]),
        ema_fast=int(p["ema_fast"]),
        ema_slow=int(p["ema_slow"]),
    )
    if ind.empty:
        return DivergenceSignal(action="hold", confidence=0.0, reason="Divergence: indicateurs vides")

    row = ind.iloc[-1]
    div = float(row["div_score"])
    atr = float(row["ATR"]) if row["ATR"] > 0 else float(ind["Close"].iloc[-1]) * 0.01
    price = float(row["Close"])
    if ask and ask > 0 and bid and bid > 0:
        price = (bid + ask) / 2.0

    div_long = float(p["div_long"])
    div_short = float(p["div_short"])
    long_signal = bool(div > div_long and row["div_confirm_up"])
    short_signal = bool(div < div_short and row["div_confirm_dn"])

    if p.get("use_trend", True):
        long_signal = long_signal and bool(row["trend_up"])
        short_signal = short_signal and bool(row["trend_dn"])

    if p.get("use_vol_filter", True):
        min_vol = float(p.get("min_vol", 0.005))
        if float(row["vol_regime"]) < min_vol:
            long_signal = False
            short_signal = False

    action = "hold"
    if long_signal and not short_signal:
        action = "buy"
    elif short_signal and not long_signal:
        action = "sell"

    strength = min(1.0, abs(div) / max(abs(div_long), 0.05))
    conf = float(p.get("min_confidence", 0.55))
    if action != "hold":
        conf = min(0.92, conf + 0.25 * strength)

    stop_mult = float(p["stop_mult"])
    tp_mult = float(p["tp_mult"])
    sl = tp = None
    entry = price
    if action == "buy":
        sl = price - stop_mult * atr
        tp = price + tp_mult * atr
        if ask and ask > 0:
            entry = ask
    elif action == "sell":
        sl = price + stop_mult * atr
        tp = price - tp_mult * atr
        if bid and bid > 0:
            entry = bid

    reason = (
        f"Divergence div={div:.3f} "
        f"(seuils {div_short:.2f}/{div_long:.2f}) "
        f"trend_up={bool(row['trend_up'])} trend_dn={bool(row['trend_dn'])} "
        f"ATR={atr:.5f}"
    )
    if action == "hold":
        reason = f"Divergence HOLD: div={div:.3f} — pas de signal confirmé"

    return DivergenceSignal(
        action=action,
        confidence=conf if action != "hold" else max(0.35, conf * 0.6),
        reason=reason,
        stop_loss=round(sl, 5) if sl is not None else None,
        take_profit=round(tp, 5) if tp is not None else None,
        entry_price=round(entry, 5) if entry else None,
        div_score=div,
        metadata={
            "div_score": div,
            "div_long": div_long,
            "div_short": div_short,
            "atr": atr,
            "trend_up": bool(row["trend_up"]),
            "trend_dn": bool(row["trend_dn"]),
            "vol_regime": float(row["vol_regime"]),
            "params": {k: p[k] for k in ("window", "div_long", "div_short", "stop_mult", "tp_mult")},
        },
    )


def merge_divergence_into_decision(
    action: str,
    confidence: float,
    reason: str,
    stop_loss: Optional[float],
    take_profit: Optional[float],
    signal: DivergenceSignal,
    *,
    override_hold: bool = True,
    prefer_on_conflict: bool = False,
) -> Tuple[str, float, str, Optional[float], Optional[float], Dict[str, Any]]:
    """
    Fuse divergence signal with existing /decision output.
    Returns (action, confidence, reason, sl, tp, metadata_fragment).
    """
    meta: Dict[str, Any] = {"divergence": signal.metadata}
    meta["divergence"]["action"] = signal.action
    meta["divergence"]["confidence"] = signal.confidence

    if signal.action == "hold":
        reason += f" [Div: HOLD {signal.div_score:.3f}]"
        return action, confidence, reason, stop_loss, take_profit, meta

    d_action = signal.action
    d_conf = signal.confidence

    if action == "hold" and override_hold:
        action = d_action
        confidence = max(confidence, d_conf)
        reason += f" [Div déclenche {d_action.upper()} conf={d_conf:.2f}]"
    elif action == d_action:
        confidence = min(0.95, max(confidence, d_conf))
        reason += f" [Div aligné {d_action.upper()} +{d_conf:.2f}]"
    elif action in ("buy", "sell") and d_action != action:
        if prefer_on_conflict:
            action = d_action
            confidence = d_conf * 0.9
            reason += f" [Div prioritaire → {d_action.upper()}]"
        else:
            action = "hold"
            confidence = max(0.45, min(confidence, d_conf) * 0.85)
            reason += " [Div conflit → HOLD]"
    else:
        reason += f" [Div {d_action.upper()} ignoré (état={action})]"

    if signal.stop_loss and action == "buy" and (stop_loss is None or stop_loss <= 0):
        stop_loss = signal.stop_loss
    if signal.take_profit and action == "buy" and (take_profit is None or take_profit <= 0):
        take_profit = signal.take_profit
    if signal.stop_loss and action == "sell" and (stop_loss is None or stop_loss <= 0):
        stop_loss = signal.stop_loss
    if signal.take_profit and action == "sell" and (take_profit is None or take_profit <= 0):
        take_profit = signal.take_profit

    return action, confidence, reason, stop_loss, take_profit, meta
