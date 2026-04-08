"""
Validation finale des signaux BUY/SELL à partir de RSI, MACD (histogramme)
et Ichimoku (biais nuage / tenkan vs kijun), en complément des EMA déjà envoyées par l'EA.

Utilisé par ai_server (/decision, decision_simplified) pour renforcer ou forcer HOLD
si la confluence « cœur » est insuffisante.
"""
from __future__ import annotations

from typing import Any, Dict, List, Optional, Tuple


def _f(x: Any, default: float = 0.0) -> float:
    try:
        if x is None:
            return default
        return float(x)
    except (TypeError, ValueError):
        return default


def _votes_for_buy(
    rsi: float,
    macd_hist: Optional[float],
    ich_bias: int,
    ema_fast_m1: float,
    ema_slow_m1: float,
    ema_fast_h1: float,
    ema_slow_h1: float,
) -> Tuple[int, int, List[str]]:
    """Retourne (votes_pour, votes_contre, labels)."""
    pos = neg = 0
    labels: List[str] = []

    # --- RSI : éviter surachat pour BUY ; favoriser zone < 55 ou rebond depuis survente
    if rsi >= 75:
        neg += 1
        labels.append("RSI-")
    elif rsi <= 40 or (rsi < 55 and ema_fast_m1 >= ema_slow_m1):
        pos += 1
        labels.append("RSI+")
    else:
        labels.append("RSI~")

    # --- MACD histogramme (si fourni par l'EA) ; sinon proxy EMA M1
    if macd_hist is not None:
        if macd_hist > 0:
            pos += 1
            labels.append("MACD+")
        elif macd_hist < 0:
            neg += 1
            labels.append("MACD-")
        else:
            labels.append("MACD0")
    else:
        if ema_fast_m1 > ema_slow_m1 and ema_slow_m1 > 0:
            pos += 1
            labels.append("MACDpx+")
        elif ema_fast_m1 < ema_slow_m1:
            neg += 1
            labels.append("MACDpx-")
        else:
            labels.append("MACDpx~")

    # --- Ichimoku : biais explicite si fourni ; sinon proxy H1 EMA
    if ich_bias == 1:
        pos += 1
        labels.append("ICH+")
    elif ich_bias == -1:
        neg += 1
        labels.append("ICH-")
    else:
        if ema_fast_h1 > ema_slow_h1 and ema_slow_h1 > 0:
            pos += 1
            labels.append("ICHpx+")
        elif ema_fast_h1 < ema_slow_h1:
            neg += 1
            labels.append("ICHpx-")
        else:
            labels.append("ICHpx~")

    return pos, neg, labels


def _votes_for_sell(
    rsi: float,
    macd_hist: Optional[float],
    ich_bias: int,
    ema_fast_m1: float,
    ema_slow_m1: float,
    ema_fast_h1: float,
    ema_slow_h1: float,
) -> Tuple[int, int, List[str]]:
    pos = neg = 0
    labels: List[str] = []

    if rsi <= 25:
        neg += 1
        labels.append("RSI-")
    elif rsi >= 60 or (rsi > 45 and ema_fast_m1 <= ema_slow_m1):
        pos += 1
        labels.append("RSI+")
    else:
        labels.append("RSI~")

    if macd_hist is not None:
        if macd_hist < 0:
            pos += 1
            labels.append("MACD+")
        elif macd_hist > 0:
            neg += 1
            labels.append("MACD-")
        else:
            labels.append("MACD0")
    else:
        if ema_fast_m1 < ema_slow_m1 and ema_slow_m1 > 0:
            pos += 1
            labels.append("MACDpx+")
        elif ema_fast_m1 > ema_slow_m1:
            neg += 1
            labels.append("MACDpx-")
        else:
            labels.append("MACDpx~")

    if ich_bias == -1:
        pos += 1
        labels.append("ICH+")
    elif ich_bias == 1:
        neg += 1
        labels.append("ICH-")
    else:
        if ema_fast_h1 < ema_slow_h1 and ema_slow_h1 > 0:
            pos += 1
            labels.append("ICHpx+")
        elif ema_fast_h1 > ema_slow_h1:
            neg += 1
            labels.append("ICHpx-")
        else:
            labels.append("ICHpx~")

    return pos, neg, labels


def apply_core_indicator_confluence(
    request: Any,
    action: str,
    confidence: float,
    reason: str,
    min_votes: int = 2,
) -> Tuple[str, float, str, Dict[str, Any]]:
    """
    Si action est buy/sell, exige au moins `min_votes` votes « pour » sur le trio RSI/MACD/Ichi
    (avec votes « contre » qui peuvent faire échouer plus tôt).

    Retourne (action, confidence, reason, detail_dict).
    """
    a = (action or "hold").strip().lower()
    if a not in ("buy", "sell"):
        return action, confidence, reason, {"skipped": True, "reason": "not_buy_sell"}

    rsi = _f(getattr(request, "rsi", None), 50.0)
    macd_hist = getattr(request, "macd_histogram", None)
    if macd_hist is not None:
        macd_hist = _f(macd_hist, 0.0)
    ich_bias = int(getattr(request, "ichimoku_bias", 0) or 0)

    ema_fast_m1 = _f(getattr(request, "ema_fast_m1", None), 0.0)
    ema_slow_m1 = _f(getattr(request, "ema_slow_m1", None), 0.0)
    ema_fast_h1 = _f(getattr(request, "ema_fast_h1", None), 0.0)
    ema_slow_h1 = _f(getattr(request, "ema_slow_h1", None), 0.0)

    if a == "buy":
        pos, neg, labels = _votes_for_buy(
            rsi, macd_hist, ich_bias, ema_fast_m1, ema_slow_m1, ema_fast_h1, ema_slow_h1
        )
    else:
        pos, neg, labels = _votes_for_sell(
            rsi, macd_hist, ich_bias, ema_fast_m1, ema_slow_m1, ema_fast_h1, ema_slow_h1
        )

    detail: Dict[str, Any] = {
        "core_labels": labels,
        "votes_for": pos,
        "votes_against": neg,
        "min_votes_required": min_votes,
        "rsi": rsi,
        "macd_histogram": macd_hist,
        "ichimoku_bias": ich_bias,
    }

    # Deux votes « contre » forts → HOLD
    if neg >= 2:
        new_reason = f"{reason} | [Confluence: HOLD — contre x{neg} ({','.join(labels)})]"
        return "hold", min(float(confidence), 0.55), new_reason, detail

    if pos < min_votes:
        new_reason = f"{reason} | [Confluence: HOLD — votes {pos}<{min_votes} ({','.join(labels)})]"
        return "hold", min(float(confidence), 0.55), new_reason, detail

    new_reason = f"{reason} | [Confluence OK: {','.join(labels)}]"
    return action, float(confidence), new_reason, detail
