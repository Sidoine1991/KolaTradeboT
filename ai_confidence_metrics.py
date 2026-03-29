"""
Métriques alternatives pour la confiance des décisions IA (hors heuristique linéaire classique).

- margin_ratio : pureté directionnelle = |buy - sell| / (buy + sell) — pénalise les signaux contradictoires.
- logistic_margin : sigmoïde sur l'écart |buy - sell| — sépare mieux fort/faible.
- tf_entropy : 1 - entropie normalisée sur la répartition M1/M5/H1 (haussier/baissier/neutre).
- blend : mélange pondéré legacy + alternative.
"""

from __future__ import annotations

import math
import os
from typing import Tuple


def get_confidence_mode() -> str:
    return (os.getenv("AI_CONFIDENCE_MODE") or "legacy").strip().lower()


def get_blend_weight() -> float:
    try:
        w = float(os.getenv("AI_CONFIDENCE_BLEND", "0.4"))
    except (TypeError, ValueError):
        w = 0.4
    return max(0.0, min(1.0, w))


def confidence_margin_ratio(
    buy_score: float,
    sell_score: float,
    lo: float = 0.35,
    hi: float = 0.92,
) -> float:
    """
    Confiance = lo + (hi-lo) * pureté, avec pureté = |buy-sell| / (buy+sell).
    Si aucun signal cumulé, retour proche du neutre.
    """
    b = max(0.0, float(buy_score))
    s = max(0.0, float(sell_score))
    tot = b + s
    if tot < 1e-12:
        return (lo + hi) / 2.0
    purity = abs(b - s) / tot
    return lo + purity * (hi - lo)


def confidence_logistic_margin(
    buy_score: float,
    sell_score: float,
    lo: float = 0.35,
    hi: float = 0.92,
    steepness: float = 5.0,
    midpoint: float = 0.35,
) -> float:
    """
    Sigmoïde sur m = |buy - sell| (typiquement 0 ~ 0.9+ selon pondérations EA).
    """
    m = abs(float(buy_score) - float(sell_score))
    t = 1.0 / (1.0 + math.exp(-steepness * (m - midpoint)))
    return lo + t * (hi - lo)


def _safe_entropy_trinary(bullish: int, bearish: int, neutral: int) -> float:
    """Entropie Shannon normalisée sur [0,1] pour 3 classes (max = log2(3))."""
    n = max(0, int(bullish)) + max(0, int(bearish)) + max(0, int(neutral))
    if n <= 0:
        return 1.0
    p1 = max(0, int(bullish)) / n
    p2 = max(0, int(bearish)) / n
    p3 = max(0, int(neutral)) / n
    h = 0.0
    for p in (p1, p2, p3):
        if p > 1e-15:
            h -= p * math.log(p, 2)
    h_max = math.log(3.0, 2)
    return h / h_max if h_max > 0 else 0.0


def confidence_tf_entropy(
    bullish_tfs: int,
    bearish_tfs: int,
    total_tfs: int = 3,
    lo: float = 0.15,
    hi: float = 0.98,
) -> float:
    """
    Plus la répartition haussier/baissier/neutre est concentrée, plus la confiance est haute.
    """
    b = max(0, int(bullish_tfs))
    br = max(0, int(bearish_tfs))
    t = max(1, int(total_tfs))
    neutral = max(0, t - b - br)
    u = _safe_entropy_trinary(b, br, neutral)
    return lo + (1.0 - u) * (hi - lo)


def legacy_simplified_confidence(buy_score: float, sell_score: float, base_action: str) -> float:
    """Reproduit la formule actuelle de decision_simplified pour buy/sell."""
    if base_action == "buy":
        return 0.5 + (float(buy_score) - float(sell_score)) / 2.0
    if base_action == "sell":
        return 0.5 + (float(sell_score) - float(buy_score)) / 2.0
    return 0.5


def compute_simplified_confidence(
    buy_score: float,
    sell_score: float,
    base_action: str,
) -> Tuple[float, str]:
    """
    Retourne (confiance, libellé du mode effectif).
    Modes : legacy, margin_ratio, logistic, entropy_ema (nécessite votes — utiliser l'autre overload).
    """
    mode = get_confidence_mode()
    if base_action not in ("buy", "sell"):
        return legacy_simplified_confidence(buy_score, sell_score, base_action), "legacy_hold"

    leg = legacy_simplified_confidence(buy_score, sell_score, base_action)

    if mode == "legacy":
        return leg, "legacy"

    if mode == "margin_ratio":
        return confidence_margin_ratio(buy_score, sell_score), "margin_ratio"

    if mode == "logistic":
        return confidence_logistic_margin(buy_score, sell_score), "logistic_margin"

    if mode == "blend":
        w = get_blend_weight()
        alt = confidence_margin_ratio(buy_score, sell_score)
        return (1.0 - w) * leg + w * alt, f"blend(leg+margin,w={w:.2f})"

    if mode == "blend_logistic":
        w = get_blend_weight()
        alt = confidence_logistic_margin(buy_score, sell_score)
        return (1.0 - w) * leg + w * alt, f"blend(leg+logistic,w={w:.2f})"

    return leg, "legacy_unknown_mode"


def compute_simplified_confidence_with_tf_entropy(
    buy_score: float,
    sell_score: float,
    base_action: str,
    ema_votes_bull: int,
    ema_votes_bear: int,
    total_emas: int = 3,
) -> Tuple[float, str]:
    """
    Mode entropy_ema : combine scores d'entrée (legacy) avec entropie sur les 3 EMA M1/M5/H1.
    """
    mode = get_confidence_mode()
    leg, tag = compute_simplified_confidence(buy_score, sell_score, base_action)
    if mode != "entropy_ema":
        return leg, tag

    ent = confidence_tf_entropy(ema_votes_bull, ema_votes_bear, total_emas)
    w = get_blend_weight()
    mixed = (1.0 - w) * leg + w * ent
    return mixed, f"entropy_ema(blend w={w:.2f})"


def count_ema_direction_votes(
    ema_fast_m1,
    ema_slow_m1,
    ema_fast_m5,
    ema_slow_m5,
    ema_fast_h1,
    ema_slow_h1,
) -> Tuple[int, int]:
    """Compte haussier / baissier pour M1, M5, H1 lorsque les deux EMA sont définis et > 0."""
    bull = bear = 0
    pairs = [
        (ema_fast_m1, ema_slow_m1),
        (ema_fast_m5, ema_slow_m5),
        (ema_fast_h1, ema_slow_h1),
    ]
    for f, s in pairs:
        try:
            ff = float(f) if f is not None else 0.0
            ss = float(s) if s is not None else 0.0
        except (TypeError, ValueError):
            continue
        if ss <= 0 and ff <= 0:
            continue
        if ff > ss:
            bull += 1
        elif ff < ss:
            bear += 1
    return bull, bear
