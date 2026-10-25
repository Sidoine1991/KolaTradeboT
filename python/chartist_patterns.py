#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Chartist pattern detector — setups exacts des figures Marker Maker Fx.
Utilisé par ai_server pour produire des ordres prêts à l'exécution EA.

v2 (2026-09) :
  - Ajout stratégie SMC_OTE (Optimal Trade Entry) en priorité #1 :
    zone Fibonacci 61.8%–79% du dernier swing, entrée sniper 70.5%,
    confluence OB / FVG / RSI / bougie de confirmation, et cascade
    de Take-Profits TP1..TPn par extension Fibonacci du swing
    (1.272 / 1.618 / 2.0 / 2.618 / 3.618 / 4.618).
  - ChartistOrder porte désormais une liste `tps` (TP1..TPn) et un
    `priority` utilisé pour trier/pondérer les figures entre elles.
  - Nouveau `compute_chartist_verdict()` : verdict GOM (WAIT / BUY /
    GOOD BUY / PERFECT BUY, et symétrique SELL) calculé à partir de
    TOUTES les figures détectées (confirmées + en watch), pas
    seulement de la meilleure — l'OTE a un poids renforcé.
  - Les structures classiques (flags/pennants, triangles, ranges,
    tête-épaules et triples sommets/creux) ne deviennent directionnelles
    qu'après une cassure de clôture confirmée.
"""
from __future__ import annotations

from dataclasses import dataclass, field, asdict
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple
import math
import numpy as np
import pandas as pd


# ── Extensions Fibonacci utilisées pour la cascade TP1..TPn (OTE) ──────────
# Alignées avec SMC_Universal.mq5 (OTE_TP1_Fibo=1.272, OTE_TP2_Fibo=1.618)
# puis prolongées pour offrir TP3..TP6 (schéma "Trade Analysis" : reward
# croissant, liquidité en cascade).
OTE_TP_RATIOS: Tuple[float, ...] = (1.272, 1.618, 2.0, 2.618, 3.618, 4.618)

# Niveaux de la zone OTE (retracement depuis l'extrême du swing)
OTE_FIB_618 = 0.618
OTE_FIB_705 = 0.705   # "sniper entry" — milieu de zone
OTE_FIB_790 = 0.790


@dataclass
class ChartistOrder:
    symbol: str
    pattern: str
    direction: str  # BUY / SELL
    entry: float
    sl: float
    tp: float
    score: float
    rr: float
    confirmed: bool
    reason: str
    zone_low: float = 0.0
    zone_high: float = 0.0
    timestamp: str = ""
    tps: List[float] = field(default_factory=list)     # TP1..TPn (tp == tps[0])
    priority: float = 1.0                                # poids relatif (OTE > reste)
    counter_trend: bool = False                          # figure opposée au sens natif du symbole

    def to_dict(self) -> Dict[str, Any]:
        d = asdict(self)
        d["action"] = self.direction
        d["status"] = "ready" if self.confirmed else "watch"
        d["source"] = "chartist"
        tps = self.tps or [self.tp]
        d["tps"] = tps
        for i, level in enumerate(tps, start=1):
            d[f"tp{i}"] = float(level)
        d["tp_count"] = len(tps)
        d["counter_trend"] = bool(self.counter_trend)
        return d


# ── Seuils spécifiques aux ordres CONTRE-TENDANCE (recouvrement de perte) ──
# Volontairement plus stricts que le seuil "ready" normal (0.70) : ce sont des
# ordres exceptionnels, pas systématiques (consigne explicite de l'utilisateur).
COUNTER_TREND_MIN_SCORE = 0.78
COUNTER_TREND_MIN_RR = 2.0


def _atr(high: np.ndarray, low: np.ndarray, close: np.ndarray, period: int = 14) -> float:
    if len(close) < period + 1:
        tr = np.maximum(high[1:] - low[1:], np.abs(close[1:] - close[:-1]))
        return float(np.mean(tr)) if len(tr) else 1e-9
    tr = np.maximum(
        high[1:] - low[1:],
        np.maximum(np.abs(high[1:] - close[:-1]), np.abs(low[1:] - close[:-1])),
    )
    return float(np.mean(tr[-period:])) if len(tr) >= period else float(np.mean(tr) if len(tr) else 1e-9)


def _swing_points(high: np.ndarray, low: np.ndarray, order: int = 3) -> Tuple[List[int], List[int]]:
    n = len(high)
    highs, lows = [], []
    for i in range(order, n - order):
        if high[i] >= np.max(high[i - order : i + order + 1]) and high[i] == np.max(high[i - order : i + 1]):
            highs.append(i)
        if low[i] <= np.min(low[i - order : i + order + 1]) and low[i] == np.min(low[i - order : i + 1]):
            lows.append(i)
    return highs, lows


def _rsi(close: np.ndarray, period: int = 14) -> np.ndarray:
    out = np.full(len(close), 50.0)
    if len(close) < period + 1:
        return out
    delta = np.diff(close)
    gain = np.where(delta > 0, delta, 0.0)
    loss = np.where(delta < 0, -delta, 0.0)
    avg_g = np.mean(gain[:period])
    avg_l = np.mean(loss[:period])
    for i in range(period, len(delta)):
        avg_g = (avg_g * (period - 1) + gain[i]) / period
        avg_l = (avg_l * (period - 1) + loss[i]) / period
        rs = avg_g / avg_l if avg_l > 1e-12 else 100.0
        out[i + 1] = 100.0 - (100.0 / (1.0 + rs))
    return out


def _pin_bar_bear(o, h, l, c) -> bool:
    body = abs(c - o)
    upper = h - max(o, c)
    lower = min(o, c) - l
    rng = h - l
    return rng > 0 and upper >= body * 1.8 and upper >= rng * 0.55 and lower <= body * 0.6


def _pin_bar_bull(o, h, l, c) -> bool:
    body = abs(c - o)
    upper = h - max(o, c)
    lower = min(o, c) - l
    rng = h - l
    return rng > 0 and lower >= body * 1.8 and lower >= rng * 0.55 and upper <= body * 0.6


def _engulf_bull(o1, c1, o2, c2) -> bool:
    return c1 < o1 and c2 > o2 and c2 >= o1 and o2 <= c1


def _engulf_bear(o1, c1, o2, c2) -> bool:
    return c1 > o1 and c2 < o2 and c2 <= o1 and o2 >= c1


def df_from_candles(candles: List[Dict[str, Any]]) -> Optional[pd.DataFrame]:
    if not candles or len(candles) < 30:
        return None
    rows = []
    for c in candles:
        try:
            rows.append({
                "open": float(c.get("open", c.get("o"))),
                "high": float(c.get("high", c.get("h"))),
                "low": float(c.get("low", c.get("l"))),
                "close": float(c.get("close", c.get("c"))),
                "volume": float(c.get("volume", c.get("v", 0)) or 0),
            })
        except Exception:
            continue
    if len(rows) < 30:
        return None
    return pd.DataFrame(rows)


# ─────────────────────────────────────────────────────────────────────────
# SMC_OTE — Optimal Trade Entry (priorité #1)
# ─────────────────────────────────────────────────────────────────────────

def _ote_zone(lo_p: float, hi_p: float, direction: str) -> Tuple[float, float, float]:
    """Retourne (bot, mid, top) de la zone OTE 61.8%-79% pour un swing lo_p->hi_p.
    mid = 70.5% ("sniper entry"). BUY = retracement depuis le haut du swing ;
    SELL = retracement depuis le bas du swing.
    """
    swing = hi_p - lo_p
    if direction == "BUY":
        top = hi_p - swing * OTE_FIB_618
        mid = hi_p - swing * OTE_FIB_705
        bot = hi_p - swing * OTE_FIB_790
    else:
        bot = lo_p + swing * OTE_FIB_618
        mid = lo_p + swing * OTE_FIB_705
        top = lo_p + swing * OTE_FIB_790
    return bot, mid, top


def _ote_take_profits(lo_p: float, hi_p: float, direction: str,
                       ratios: Tuple[float, ...] = OTE_TP_RATIOS) -> List[float]:
    """Cascade TP1..TPn par extension Fibonacci du swing lo_p->hi_p.
    BUY : TPn = lo_p + swing*ratio (au-dessus du swing high).
    SELL : TPn = hi_p - swing*ratio (au-dessous du swing low).
    """
    swing = hi_p - lo_p
    if direction == "BUY":
        return [float(lo_p + swing * r) for r in ratios]
    return [float(hi_p - swing * r) for r in ratios]


def _detect_ote(symbol: str, o, h, l, c, atr: float, sh: List[int], swing_lows: List[int],
                 rsi_arr: np.ndarray, ts: str, ok_dir) -> List["ChartistOrder"]:
    """Détecte l'entrée OTE (BUY et/ou SELL) avec confluence OB/FVG/RSI/bougie,
    et calcule la cascade TP1..TPn. C'est la figure prioritaire : elle reçoit
    `priority > 1.0` pour être privilégiée dans le tri et dans le verdict GOM.
    """
    n = len(c)
    last = float(c[-1])
    out: List[ChartistOrder] = []

    def confluence(direction: str, lo_i: int, hi_i: int, bot: float, top: float) -> Tuple[int, List[str]]:
        reasons: List[str] = []
        votes = 0
        # 1) Order Block : dernière bougie à contre-tendance dans/près de la zone
        for i in range(max(hi_i, lo_i) + 1, n - 1):
            if direction == "BUY" and c[i] < o[i] and l[i] <= top and h[i] >= bot:
                votes += 1
                reasons.append("OB")
                break
            if direction == "SELL" and c[i] > o[i] and l[i] <= top and h[i] >= bot:
                votes += 1
                reasons.append("OB")
                break
        # 2) FVG (imbalance) recoupant la zone
        for i in range(max(2, n - 20), n):
            if direction == "BUY" and l[i] > h[i - 2] and not (l[i] > top or h[i - 2] < bot):
                votes += 1
                reasons.append("FVG")
                break
            if direction == "SELL" and h[i] < l[i - 2] and not (h[i] < bot or l[i - 2] > top):
                votes += 1
                reasons.append("FVG")
                break
        # 3) RSI cohérent (pas d'extrême contraire) — cf OTE_RSI_BullMin/BearMax du EA
        rsi_now = float(rsi_arr[-1]) if len(rsi_arr) else 50.0
        if direction == "BUY" and 33.0 <= rsi_now <= 72.0:
            votes += 1
            reasons.append("RSI_ok")
        if direction == "SELL" and 28.0 <= rsi_now <= 67.0:
            votes += 1
            reasons.append("RSI_ok")
        return votes, reasons

    # ── BUY : swing low -> swing high, retracement dans la zone OTE ────────
    if ok_dir("BUY") and swing_lows:
        lo_i = swing_lows[-1]
        if n - lo_i > 4:
            hi_i = lo_i + int(np.argmax(h[lo_i:]))
            if hi_i > lo_i + 2:
                lo_p, hi_p = float(l[lo_i]), float(h[hi_i])
                swing = hi_p - lo_p
                if swing > atr * 1.0:
                    bot, mid, top = _ote_zone(lo_p, hi_p, "BUY")
                    in_zone = (bot - atr * 0.15) <= last <= (top + atr * 0.15)
                    touched = (hi_i + 1 < n) and (float(np.min(l[hi_i + 1:])) <= top + atr * 0.1)
                    if in_zone or touched:
                        votes, reasons = confluence("BUY", lo_i, hi_i, bot, top)
                        conf_candle = (
                            _pin_bar_bull(o[-1], h[-1], l[-1], c[-1])
                            or _engulf_bull(o[-2], c[-2], o[-1], c[-1])
                        )
                        if conf_candle:
                            reasons.append("confirm_candle")
                        confirmed = bool((in_zone or touched) and conf_candle)
                        entry = last if confirmed else mid
                        sl = bot - atr * 0.30
                        risk = entry - sl
                        if risk > atr * 0.15:
                            tps = _ote_take_profits(lo_p, hi_p, "BUY")
                            score = 0.76 + votes * 0.045 + (0.08 if conf_candle else 0.0)
                            out.append(ChartistOrder(
                                symbol=symbol, pattern="SMC_OTE", direction="BUY",
                                entry=float(entry), sl=float(sl), tp=float(tps[0]),
                                tps=tps, score=float(min(0.97, score)),
                                rr=float((tps[0] - entry) / risk), confirmed=confirmed,
                                reason="OTE 61.8-79% (sniper 70.5%) + " + (",".join(reasons) if reasons else "zone seule"),
                                zone_low=float(bot), zone_high=float(top), timestamp=ts,
                                priority=1.35,
                            ))

    # ── SELL : swing high -> swing low, retracement dans la zone OTE ───────
    if ok_dir("SELL") and sh:
        hi_i = sh[-1]
        if n - hi_i > 4:
            lo_i = hi_i + int(np.argmin(l[hi_i:]))
            if lo_i > hi_i + 2:
                hi_p, lo_p = float(h[hi_i]), float(l[lo_i])
                swing = hi_p - lo_p
                if swing > atr * 1.0:
                    bot, mid, top = _ote_zone(lo_p, hi_p, "SELL")
                    in_zone = (bot - atr * 0.15) <= last <= (top + atr * 0.15)
                    touched = (lo_i + 1 < n) and (float(np.max(h[lo_i + 1:])) >= bot - atr * 0.1)
                    if in_zone or touched:
                        votes, reasons = confluence("SELL", hi_i, lo_i, bot, top)
                        conf_candle = (
                            _pin_bar_bear(o[-1], h[-1], l[-1], c[-1])
                            or _engulf_bear(o[-2], c[-2], o[-1], c[-1])
                        )
                        if conf_candle:
                            reasons.append("confirm_candle")
                        confirmed = bool((in_zone or touched) and conf_candle)
                        entry = last if confirmed else mid
                        sl = top + atr * 0.30
                        risk = sl - entry
                        if risk > atr * 0.15:
                            tps = _ote_take_profits(lo_p, hi_p, "SELL")
                            score = 0.76 + votes * 0.045 + (0.08 if conf_candle else 0.0)
                            out.append(ChartistOrder(
                                symbol=symbol, pattern="SMC_OTE", direction="SELL",
                                entry=float(entry), sl=float(sl), tp=float(tps[0]),
                                tps=tps, score=float(min(0.97, score)),
                                rr=float((entry - tps[0]) / risk), confirmed=confirmed,
                                reason="OTE 61.8-79% (sniper 70.5%) + " + (",".join(reasons) if reasons else "zone seule"),
                                zone_low=float(bot), zone_high=float(top), timestamp=ts,
                                priority=1.35,
                            ))

    return out


def _breakout_order(
    symbol: str,
    pattern: str,
    direction: str,
    entry: float,
    boundary: float,
    height: float,
    atr: float,
    ts: str,
    reason: str,
    score: float = 0.78,
) -> Optional[ChartistOrder]:
    """Build a confirmed breakout order with a structure-based stop/target."""
    sign = 1.0 if direction == "BUY" else -1.0
    sl = boundary - sign * atr * 0.25
    risk = sign * (entry - sl)
    target_distance = max(height, atr)
    if risk <= atr * 0.05:
        return None
    tp = entry + sign * target_distance
    return ChartistOrder(
        symbol=symbol,
        pattern=pattern,
        direction=direction,
        entry=float(entry),
        sl=float(sl),
        tp=float(tp),
        tps=[float(tp)],
        score=score,
        rr=float(target_distance / risk),
        confirmed=True,
        reason=reason,
        zone_low=float(min(boundary, entry)),
        zone_high=float(max(boundary, entry)),
        timestamp=ts,
    )


def _detect_classic_breakout_patterns(
    symbol: str,
    h: np.ndarray,
    l: np.ndarray,
    c: np.ndarray,
    atr: float,
    swing_highs: List[int],
    swing_lows: List[int],
    ts: str,
) -> List[ChartistOrder]:
    """Detect classic price formations only on a closed-candle breakout."""
    n = len(c)
    if n < 24 or atr <= 0:
        return []
    out: List[ChartistOrder] = []
    last, previous = float(c[-1]), float(c[-2])
    buffer = atr * 0.05

    # Descending triangle: flat support, at least two lower highs, then break.
    if len(swing_highs) >= 2 and len(swing_lows) >= 2:
        tops = swing_highs[-3:]
        bottoms = swing_lows[-3:]
        top_values = [float(h[i]) for i in tops]
        bottom_values = [float(l[i]) for i in bottoms]
        support = float(np.mean(bottom_values))
        resistance = float(np.mean(top_values))
        lower_highs = all(
            top_values[i + 1] < top_values[i] - atr * 0.08
            for i in range(len(top_values) - 1)
        )
        flat_support = max(bottom_values) - min(bottom_values) <= atr * 0.55
        if (
            lower_highs and flat_support and resistance - support >= atr * 0.8
            and last < support - buffer and previous >= support - atr * 0.2
        ):
            order = _breakout_order(
                symbol, "DESCENDING_TRIANGLE_BREAKOUT", "SELL", last, support,
                resistance - support, atr, ts,
                "Lower highs + horizontal support + confirmed close below support",
            )
            if order:
                out.append(order)

    # Symmetrical triangle: converge lower highs/higher lows; direction is
    # assigned only after a close beyond the projected trendline.
    if len(swing_highs) >= 2 and len(swing_lows) >= 2:
        hi0, hi1 = swing_highs[-2:]
        lo0, lo1 = swing_lows[-2:]
        high0, high1 = float(h[hi0]), float(h[hi1])
        low0, low1 = float(l[lo0]), float(l[lo1])
        if high1 < high0 - atr * 0.08 and low1 > low0 + atr * 0.08:
            high_slope = (high1 - high0) / max(hi1 - hi0, 1)
            low_slope = (low1 - low0) / max(lo1 - lo0, 1)
            projected_high = high1 + high_slope * (n - 1 - hi1)
            projected_low = low1 + low_slope * (n - 1 - lo1)
            if projected_high - projected_low >= atr * 0.5:
                if last > projected_high + buffer and previous <= projected_high + atr * 0.2:
                    order = _breakout_order(
                        symbol, "SYMMETRICAL_TRIANGLE_BREAKOUT", "BUY", last,
                        projected_high, high0 - low0, atr, ts,
                        "Converging highs/lows + confirmed close above resistance",
                    )
                    if order:
                        out.append(order)
                elif last < projected_low - buffer and previous >= projected_low - atr * 0.2:
                    order = _breakout_order(
                        symbol, "SYMMETRICAL_TRIANGLE_BREAKOUT", "SELL", last,
                        projected_low, high0 - low0, atr, ts,
                        "Converging highs/lows + confirmed close below support",
                    )
                    if order:
                        out.append(order)

    # Rectangle/range: repeated horizontal reactions, no directional guess
    # before breakout.
    if len(swing_highs) >= 2 and len(swing_lows) >= 2:
        tops = [float(h[i]) for i in swing_highs[-3:]]
        bottoms = [float(l[i]) for i in swing_lows[-3:]]
        resistance, support = float(np.mean(tops)), float(np.mean(bottoms))
        if (
            max(tops) - min(tops) <= atr * 0.5
            and max(bottoms) - min(bottoms) <= atr * 0.5
            and resistance - support >= atr * 0.8
        ):
            if last > resistance + buffer and previous <= resistance + atr * 0.2:
                order = _breakout_order(
                    symbol, "RECTANGLE_BREAKOUT", "BUY", last, resistance,
                    resistance - support, atr, ts,
                    "Horizontal range + confirmed close above resistance",
                )
                if order:
                    out.append(order)
            elif last < support - buffer and previous >= support - atr * 0.2:
                order = _breakout_order(
                    symbol, "RECTANGLE_BREAKOUT", "SELL", last, support,
                    resistance - support, atr, ts,
                    "Horizontal range + confirmed close below support",
                )
                if order:
                    out.append(order)

    # Head-and-shoulders and triple tops/bottoms. Neckline breaks are required;
    # an unfinished silhouette remains a watch, never a directional order.
    if len(swing_highs) >= 3:
        peaks = swing_highs[-3:]
        p0, p1, p2 = (float(h[i]) for i in peaks)
        neckline_points = [
            float(np.min(l[peaks[i] : peaks[i + 1] + 1]))
            for i in range(2)
        ]
        if (
            peaks[1] - peaks[0] >= 3 and peaks[2] - peaks[1] >= 3
            and abs(p0 - p2) <= atr * 0.75
            and p1 >= max(p0, p2) + atr * 0.35
        ):
            x0, x1 = peaks[1], peaks[2]
            neck_slope = (neckline_points[1] - neckline_points[0]) / max(x1 - x0, 1)
            neckline = neckline_points[1] + neck_slope * (n - 1 - x1)
            if last < neckline - buffer and previous >= neckline - atr * 0.2:
                order = _breakout_order(
                    symbol, "HEAD_AND_SHOULDERS_TOP", "SELL", last, neckline,
                    p1 - neckline, atr, ts,
                    "Lower right shoulder + confirmed neckline break",
                    score=0.82,
                )
                if order:
                    out.append(order)
        if max(p0, p1, p2) - min(p0, p1, p2) <= atr * 0.55:
            neckline = float(min(neckline_points))
            if last < neckline - buffer and previous >= neckline - atr * 0.2:
                order = _breakout_order(
                    symbol, "TRIPLE_TOP_BREAKOUT", "SELL", last, neckline,
                    max(p0, p1, p2) - neckline, atr, ts,
                    "Three comparable highs + confirmed neckline break",
                    score=0.80,
                )
                if order:
                    out.append(order)

    if len(swing_lows) >= 3:
        troughs = swing_lows[-3:]
        p0, p1, p2 = (float(l[i]) for i in troughs)
        neckline_points = [
            float(np.max(h[troughs[i] : troughs[i + 1] + 1]))
            for i in range(2)
        ]
        if (
            troughs[1] - troughs[0] >= 3 and troughs[2] - troughs[1] >= 3
            and abs(p0 - p2) <= atr * 0.75
            and p1 <= min(p0, p2) - atr * 0.35
        ):
            x0, x1 = troughs[1], troughs[2]
            neck_slope = (neckline_points[1] - neckline_points[0]) / max(x1 - x0, 1)
            neckline = neckline_points[1] + neck_slope * (n - 1 - x1)
            if last > neckline + buffer and previous <= neckline + atr * 0.2:
                order = _breakout_order(
                    symbol, "INVERSE_HEAD_AND_SHOULDERS", "BUY", last, neckline,
                    neckline - p1, atr, ts,
                    "Higher right shoulder + confirmed neckline break",
                    score=0.82,
                )
                if order:
                    out.append(order)
        if max(p0, p1, p2) - min(p0, p1, p2) <= atr * 0.55:
            neckline = float(max(neckline_points))
            if last > neckline + buffer and previous <= neckline + atr * 0.2:
                order = _breakout_order(
                    symbol, "TRIPLE_BOTTOM_BREAKOUT", "BUY", last, neckline,
                    neckline - min(p0, p1, p2), atr, ts,
                    "Three comparable lows + confirmed neckline break",
                    score=0.80,
                )
                if order:
                    out.append(order)

    # Bull/bear flags and pennants: a strong pole, a shallow counter-trend
    # consolidation, then a close through its boundary in pole direction.
    if n >= 24:
        consolidation_start = n - 7
        pole_start = n - 17
        pole_end = consolidation_start
        cons_slice = slice(consolidation_start, n - 1)
        pole_move = float(c[pole_end] - c[pole_start])
        cons_high = float(np.max(h[cons_slice]))
        cons_low = float(np.min(l[cons_slice]))
        cons_width = cons_high - cons_low
        if abs(pole_move) >= atr * 2.5 and cons_width <= abs(pole_move) * 0.8:
            direction = "BUY" if pole_move > 0 else "SELL"
            pole_extreme = float(np.max(h[pole_start:pole_end + 1])) if pole_move > 0 else float(np.min(l[pole_start:pole_end + 1]))
            retrace = (
                (pole_extreme - cons_low) / abs(pole_move)
                if pole_move > 0
                else (cons_high - pole_extreme) / abs(pole_move)
            )
            closes = c[consolidation_start:n - 1]
            slope = float(np.polyfit(np.arange(len(closes)), closes, 1)[0]) if len(closes) >= 3 else 0.0
            against_slope = slope < 0 if pole_move > 0 else slope > 0
            breakout = (
                (last > cons_high + buffer and previous <= cons_high + atr * 0.2)
                if pole_move > 0
                else (last < cons_low - buffer and previous >= cons_low - atr * 0.2)
            )
            if 0.12 <= retrace <= 0.65 and against_slope and breakout:
                first_half = h[consolidation_start:consolidation_start + 3].max() - l[consolidation_start:consolidation_start + 3].min()
                second_half = h[consolidation_start + 3:n - 1].max() - l[consolidation_start + 3:n - 1].min()
                pattern = (
                    "BULL_PENNANT_BREAKOUT" if pole_move > 0 else "BEAR_PENNANT_BREAKOUT"
                ) if second_half < first_half * 0.85 else (
                    "BULL_FLAG_BREAKOUT" if pole_move > 0 else "BEAR_FLAG_BREAKOUT"
                )
                boundary = cons_high if pole_move > 0 else cons_low
                order = _breakout_order(
                    symbol, pattern, direction, last, boundary, abs(pole_move),
                    atr, ts, "Impulse pole + counter-trend consolidation + confirmed breakout",
                    score=0.80,
                )
                if order:
                    out.append(order)

    return out


def detect_all_patterns(symbol: str, df: pd.DataFrame, native_dir: str = "") -> List[ChartistOrder]:
    """
    Detecte les structures classiques confirmées (flags/pennants, triangles,
    ranges, tête-épaules, triples tops/bottoms) et les figures SMC/candles.
    native_dir: 'BUY' / 'SELL' / '' pour filtrer GainX/PainX.

    SMC_OTE est calculée en premier et reçoit un `priority` > 1.0 : elle est
    privilégiée dans le tri final ET dans compute_chartist_verdict().
    """
    if df is None or len(df) < 40:
        return []
    o = df["open"].astype(float).to_numpy()
    h = df["high"].astype(float).to_numpy()
    l = df["low"].astype(float).to_numpy()
    c = df["close"].astype(float).to_numpy()
    n = len(c)
    atr = max(_atr(h, l, c), 1e-9)
    sh, swing_lows = _swing_points(h, l, order=3)
    rsi_arr = _rsi(c, 14)
    last = c[-1]
    orders: List[ChartistOrder] = []
    ts = datetime.now(timezone.utc).isoformat()

    def ok_dir(d: str) -> bool:
        # NOTE (2026-09) : ne filtre plus par sens natif à la détection.
        # On détecte désormais les figures dans les DEUX sens pour tous les
        # symboles (y compris GainX/Boom/PainX/Crash) ; le filtrage
        # "contre-tendance = exceptionnel" est appliqué APRÈS coup, une fois
        # tous les orders construits (voir plus bas : marquage
        # `counter_trend` + seuils COUNTER_TREND_MIN_SCORE/RR). Ça permet de
        # continuer à détecter normalement les figures dans le sens natif
        # (comportement inchangé) tout en gardant, séparément, les figures
        # contre-tendance de très haute qualité pour du recouvrement de perte
        # ponctuel — jamais systématique.
        return True

    # ── 0) SMC_OTE — Optimal Trade Entry (PRIORITÉ) ─────────────────────
    orders.extend(_detect_ote(symbol, o, h, l, c, atr, sh, swing_lows, rsi_arr, ts, ok_dir))
    orders.extend(
        _detect_classic_breakout_patterns(symbol, h, l, c, atr, sh, swing_lows, ts)
    )

    # ── 1) ASCENDING TRIANGLE (BUY) ─────────────────────────────────────
    if len(sh) >= 3 and len(swing_lows) >= 2:
        tops = sh[-3:]
        top_prices = [h[i] for i in tops]
        flat = max(top_prices) - min(top_prices) <= atr * 0.55
        lows_idx = swing_lows[-3:] if len(swing_lows) >= 3 else swing_lows[-2:]
        ascending = all(l[lows_idx[i]] < l[lows_idx[i + 1]] + atr * 0.15 for i in range(len(lows_idx) - 1))
        res = float(np.mean(top_prices))
        height = res - min(l[i] for i in lows_idx)
        broke = last > res + atr * 0.05 and c[-2] <= res + atr * 0.2
        if flat and ascending and height > atr * 0.8 and ok_dir("BUY"):
            score = 0.72 + (0.1 if broke else 0.0)
            entry = last if broke else res
            sl = float(min(l[i] for i in lows_idx[-2:])) - atr * 0.15
            tp = entry + height
            rr = abs(tp - entry) / max(abs(entry - sl), 1e-9)
            orders.append(ChartistOrder(
                symbol=symbol, pattern="ASCENDING_TRIANGLE", direction="BUY",
                entry=float(entry), sl=float(sl), tp=float(tp), tps=[float(tp)],
                score=min(0.95, score),
                rr=float(rr), confirmed=bool(broke), reason="Resistance plate + HL + breakout h",
                zone_low=float(min(l[i] for i in lows_idx)), zone_high=float(res), timestamp=ts,
            ))

    # ── 2) DOUBLE BOTTOM + RETEST (BUY) ─────────────────────────────────
    if len(swing_lows) >= 2:
        i1, i2 = swing_lows[-2], swing_lows[-1]
        if i2 - i1 >= 5:
            l1, l2 = float(l[i1]), float(l[i2])
            mid_hi = float(np.max(h[i1:i2 + 1]))
            tol = atr * 0.7
            similar = abs(l1 - l2) <= tol
            neck = mid_hi
            broke = last > neck and c[-2] <= neck + atr * 0.15
            retest = broke and (np.min(l[-5:]) <= neck + atr * 0.25) and last >= neck - atr * 0.1
            if similar and mid_hi - max(l1, l2) > atr * 0.9 and ok_dir("BUY"):
                conf = broke or retest
                entry = last if conf else neck
                sl = min(l1, l2) - atr * 0.2
                risk = abs(entry - sl)
                tp = entry + risk * 4.0  # RR 1:4 schema
                score = 0.7 + (0.12 if retest else 0.05 if broke else 0.0)
                orders.append(ChartistOrder(
                    symbol=symbol, pattern="DOUBLE_BOTTOM_RETEST", direction="BUY",
                    entry=float(entry), sl=float(sl), tp=float(tp), tps=[float(tp)],
                    score=min(0.95, score),
                    rr=4.0, confirmed=bool(conf), reason="Double bottom + breakout/retest RR1:4",
                    zone_low=float(min(l1, l2)), zone_high=float(neck), timestamp=ts,
                ))

    # ── 3) REVERSAL HH FAIL + BOS (SELL) ────────────────────────────────
    if len(sh) >= 3:
        a, b = sh[-2], sh[-1]
        ha, hb = float(h[a]), float(h[b])
        fail = hb <= ha + atr * 0.15 and _pin_bar_bear(o[b], h[b], l[b], c[b]) or (hb < ha and c[b] < o[b])
        seg_low = float(np.min(l[a:b + 1])) if b > a else float(l[b])
        bos = last < seg_low - atr * 0.05
        if (fail or hb <= ha) and bos and ok_dir("SELL"):
            entry = last
            sl = max(ha, hb) + atr * 0.2
            risk = abs(sl - entry)
            tp1 = entry - risk * 1.5
            tp2 = entry - risk * 3.0
            orders.append(ChartistOrder(
                symbol=symbol, pattern="REVERSAL_HH_FAIL_BOS", direction="SELL",
                entry=float(entry), sl=float(sl), tp=float(tp1), tps=[float(tp1), float(tp2)],
                score=0.82,
                rr=3.0, confirmed=True, reason="HH fail + BOS sell area TP1/TP2",
                zone_low=float(seg_low), zone_high=float(max(ha, hb)), timestamp=ts,
            ))

    # ── 4) RSI TRENDLINE BREAKOUT (SELL) ────────────────────────────────
    if len(rsi_arr) >= 40 and ok_dir("SELL"):
        rsi_now = rsi_arr[-1]
        slope_up = rsi_arr[-15] < rsi_arr[-8] < max(rsi_arr[-7:-2]) if len(rsi_arr) > 15 else False
        broke_rsi = slope_up and rsi_now < rsi_arr[-3] and rsi_now < 65 and max(rsi_arr[-12:]) >= 68
        if len(swing_lows) >= 1:
            support = float(l[swing_lows[-1]])
            price_break = last < support
        else:
            support = float(np.min(l[-10:]))
            price_break = last < support
        if broke_rsi and price_break:
            entry = last
            sl = float(np.max(h[-15:])) + atr * 0.15
            risk = abs(sl - entry)
            tp = entry - risk * 2.5
            orders.append(ChartistOrder(
                symbol=symbol, pattern="RSI_TRENDLINE_BREAKOUT", direction="SELL",
                entry=float(entry), sl=float(sl), tp=float(tp), tps=[float(tp)],
                score=0.8,
                rr=2.5, confirmed=True, reason="RSI TL break OB zone + price TL break",
                zone_low=float(support), zone_high=float(sl), timestamp=ts,
            ))

    # ── 5) FIB 50% + ORDER BLOCK (BUY bias after bullish leg) ───────────
    if len(swing_lows) >= 1 and len(sh) >= 1 and ok_dir("BUY"):
        lo_i = swing_lows[-1]
        if n - lo_i > 5:
            hi_i = lo_i + int(np.argmax(h[lo_i:]))
            if hi_i > lo_i + 3:
                lo_p, hi_p = float(l[lo_i]), float(h[hi_i])
                rng = hi_p - lo_p
                if rng > atr * 1.2:
                    fib50 = hi_p - rng * 0.5
                    in_zone = abs(last - fib50) <= atr * 0.6 or (l[-1] <= fib50 <= h[-1])
                    react = c[-1] > o[-1] and c[-1] > fib50 - atr * 0.2
                    if in_zone:
                        entry = last
                        sl = lo_p - atr * 0.15
                        risk = abs(entry - sl)
                        tp = entry + risk * 5.0  # RR 1:5
                        orders.append(ChartistOrder(
                            symbol=symbol, pattern="FIB50_ORDER_BLOCK", direction="BUY",
                            entry=float(entry), sl=float(sl), tp=float(tp), tps=[float(tp)],
                            score=0.78 if react else 0.65,
                            rr=5.0, confirmed=bool(react),
                            reason="50% Fib zone + OB reaction RR1:5",
                            zone_low=float(fib50 - atr * 0.3), zone_high=float(fib50 + atr * 0.3),
                            timestamp=ts,
                        ))

    # ── 6) DEMAND AREA + IMBALANCE (BUY) ────────────────────────────────
    if n >= 30 and ok_dir("BUY"):
        for i in range(n - 20, n - 3):
            body = c[i] - o[i]
            if body > atr * 0.9:
                if i > 0 and l[i] > h[i - 1]:
                    dem_low, dem_high = float(l[i]), float(h[i])
                    touched = np.min(l[i + 1 :]) <= dem_high and last >= dem_low - atr * 0.1
                    if touched and last > dem_low:
                        entry = last
                        sl = dem_low - atr * 0.2
                        risk = abs(entry - sl)
                        tp = entry + risk * 5.0
                        orders.append(ChartistOrder(
                            symbol=symbol, pattern="DEMAND_IMBALANCE", direction="BUY",
                            entry=float(entry), sl=float(sl), tp=float(tp), tps=[float(tp)],
                            score=0.8,
                            rr=5.0, confirmed=True, reason="Demand retest after imbalance 5R",
                            zone_low=dem_low, zone_high=dem_high, timestamp=ts,
                        ))
                        break

    # ── 7) SMC BOS + FVG + BULLISH OB ───────────────────────────────────
    if len(sh) >= 2 and len(swing_lows) >= 1 and ok_dir("BUY"):
        prev_high = float(h[sh[-2]])
        bos = last > prev_high and c[-2] <= prev_high + atr * 0.2
        fvg_low = fvg_high = None
        for i in range(max(2, n - 15), n):
            if l[i] > h[i - 2]:
                fvg_low, fvg_high = float(h[i - 2]), float(l[i])
        ob_low = ob_high = None
        for i in range(n - 12, n - 1):
            if c[i] < o[i] and c[i + 1] > o[i + 1] and (c[i + 1] - o[i + 1]) > atr * 0.5:
                ob_low, ob_high = float(l[i]), float(h[i])
        if bos and ob_low is not None:
            in_ob = l[-1] <= ob_high and last >= ob_low
            entry = last
            sl = ob_low - atr * 0.15
            risk = abs(entry - sl)
            tp = entry + risk * 3.0
            orders.append(ChartistOrder(
                symbol=symbol, pattern="SMC_BOS_FVG_OB", direction="BUY",
                entry=float(entry), sl=float(sl), tp=float(tp), tps=[float(tp)],
                score=0.85 if (fvg_low is not None and in_ob) else 0.72,
                rr=3.0, confirmed=bool(in_ob or bos),
                reason="BOS + FVG + Bullish OB retest",
                zone_low=float(ob_low), zone_high=float(ob_high), timestamp=ts,
            ))

    # ── 8) BEARISH CONFIRMATIONS AT RESISTANCE / OB (SELL) ─────────────
    if n >= 5 and ok_dir("SELL"):
        if sh:
            res = float(h[sh[-1]])
            near = abs(h[-1] - res) <= atr * 0.5 or abs(h[-2] - res) <= atr * 0.5
            conf = (
                _pin_bar_bear(o[-1], h[-1], l[-1], c[-1])
                or _engulf_bear(o[-2], c[-2], o[-1], c[-1])
                or (abs(h[-1] - h[-2]) <= atr * 0.15 and c[-1] < o[-1] and c[-2] < o[-2])  # tweezer top
            )
            if near and conf and last < res:
                entry = last
                sl = res + atr * 0.25
                risk = abs(sl - entry)
                tp = entry - risk * 2.5
                orders.append(ChartistOrder(
                    symbol=symbol, pattern="BEARISH_OB_CONFIRM", direction="SELL",
                    entry=float(entry), sl=float(sl), tp=float(tp), tps=[float(tp)],
                    score=0.78,
                    rr=2.5, confirmed=True, reason="Pin/Engulf/Tweezer at resistance OB",
                    zone_low=float(res - atr), zone_high=float(res), timestamp=ts,
                ))

    # ── 9) BULLISH REJECTION PATTERNS (BUY) ─────────────────────────────
    if n >= 5 and ok_dir("BUY"):
        three_soldiers = all(c[-i] > o[-i] and c[-i] > c[-i - 1] for i in range(1, 4)) if n >= 4 else False
        morning = (
            c[-3] < o[-3]
            and abs(c[-2] - o[-2]) < atr * 0.25
            and c[-1] > o[-1]
            and c[-1] > (o[-3] + c[-3]) / 2
        )
        tweezer_bot = abs(l[-1] - l[-2]) <= atr * 0.15 and c[-1] > o[-1]
        engulf = _engulf_bull(o[-2], c[-2], o[-1], c[-1])
        pin = _pin_bar_bull(o[-1], h[-1], l[-1], c[-1])
        if three_soldiers or morning or tweezer_bot or engulf or pin:
            entry = last
            sl = float(np.min(l[-4:])) - atr * 0.15
            risk = abs(entry - sl)
            tp = entry + risk * 2.5
            name = (
                "THREE_SOLDIERS" if three_soldiers else
                "MORNING_STAR" if morning else
                "BULLISH_ENGULFING" if engulf else
                "TWEEZER_BOTTOMS" if tweezer_bot else "PIN_BAR_BULL"
            )
            orders.append(ChartistOrder(
                symbol=symbol, pattern=name, direction="BUY",
                entry=float(entry), sl=float(sl), tp=float(tp), tps=[float(tp)],
                score=0.74,
                rr=2.5, confirmed=True, reason=f"Bullish rejection pattern {name}",
                zone_low=float(sl), zone_high=float(entry), timestamp=ts,
            ))

    # ── 10) TRENDLINE BREAK + RETEST (SELL example schema) ──────────────
    if len(swing_lows) >= 3 and ok_dir("SELL"):
        x0, x1 = swing_lows[-3], swing_lows[-1]
        y0, y1 = float(l[x0]), float(l[x1])
        if y1 > y0 and x1 > x0:
            slope = (y1 - y0) / (x1 - x0)
            proj = y1 + slope * (n - 1 - x1)
            broken = last < proj - atr * 0.1 and c[-2] >= proj - atr * 0.3
            retested = broken and np.max(h[-4:]) >= proj - atr * 0.25
            if broken:
                entry = last
                sl = float(np.max(h[-6:])) + atr * 0.15
                risk = abs(sl - entry)
                tp = entry - risk * 2.5
                orders.append(ChartistOrder(
                    symbol=symbol, pattern="TRENDLINE_BREAK_RETEST", direction="SELL",
                    entry=float(entry), sl=float(sl), tp=float(tp), tps=[float(tp)],
                    score=0.8 if retested else 0.7,
                    rr=2.5, confirmed=bool(retested or broken),
                    reason="Trendline break + retest fail",
                    zone_low=float(proj - atr), zone_high=float(proj + atr), timestamp=ts,
                ))

    # ── Marquage + filtrage CONTRE-TENDANCE (GainX/Boom SELL, PainX/Crash BUY) ──
    # Une figure dont le sens est opposé au sens natif du symbole est un ordre
    # de recouvrement de perte EXCEPTIONNEL, pas une entrée normale :
    #   - elle est marquée `counter_trend=True`
    #   - elle n'est conservée QUE si elle est confirmée (pas "watch"),
    #     avec un score et un RR nettement supérieurs au seuil normal
    #     (COUNTER_TREND_MIN_SCORE / COUNTER_TREND_MIN_RR)
    # Les figures dans le sens natif ne sont pas affectées : comportement
    # identique à avant pour la logique GOM chartiste normale.
    if native_dir:
        filtered: List[ChartistOrder] = []
        for ord_ in orders:
            if ord_.direction.upper() == native_dir.upper():
                filtered.append(ord_)
                continue
            ord_.counter_trend = True
            if (ord_.confirmed and ord_.score >= COUNTER_TREND_MIN_SCORE
                    and ord_.rr >= COUNTER_TREND_MIN_RR):
                filtered.append(ord_)
            # sinon : figure contre-tendance trop faible → écartée silencieusement
        orders = filtered

    # Tri final : figures confirmées d'abord, puis score pondéré par priorité
    # (SMC_OTE, priority=1.35, remonte donc naturellement en tête dès qu'elle
    # est présente et confirmée — "on privilégie les entrées OTE").
    orders.sort(key=lambda x: (x.confirmed, x.priority * x.score), reverse=True)
    return orders


def native_direction_for_symbol(symbol: str) -> str:
    s = (symbol or "").upper().replace(" ", "")
    if any(x in s for x in ("GAINX", "BOOM", "BULL")):
        return "BUY"
    if any(x in s for x in ("PAINX", "CRASH", "BEAR")):
        return "SELL"
    return ""


# ─────────────────────────────────────────────────────────────────────────
# VERDICT GOM — agrège TOUTES les figures détectées (pas seulement `best`)
# ─────────────────────────────────────────────────────────────────────────

_VERDICT_TEXT = {
    3: "PERFECT BUY", 2: "GOOD BUY", 1: "BUY",
    0: "WAIT",
    -1: "SELL", -2: "GOOD SELL", -3: "PERFECT SELL",
}


def chartist_verdict_text(verdict_num: int) -> str:
    return _VERDICT_TEXT.get(int(verdict_num), "WAIT")


def compute_chartist_verdict(orders: List[ChartistOrder]) -> Dict[str, Any]:
    """Calcule un verdict GOM (-3..+3, WAIT/BUY/GOOD BUY/PERFECT BUY et
    symétrique SELL) à partir de TOUTES les figures chartistes détectées
    (confirmées ET en watch), utilisées comme votes pondérés — pas
    uniquement la meilleure figure.

    Pondération de chaque figure : score * priority * (1.0 si confirmée
    sinon 0.45 — une figure en watch pèse moins qu'une figure validée).
    SMC_OTE porte priority=1.35 et est donc structurellement privilégiée,
    conformément à la consigne "privilégier les entrées OTE".

    Les figures `counter_trend=True` (recouvrement de perte exceptionnel,
    sens opposé au sens natif GainX/Boom/PainX/Crash) sont EXCLUES de ce
    vote : elles ne doivent jamais influencer le verdict GOM chartiste
    normal, sous peine de rendre systématique ce qui doit rester
    exceptionnel. Elles sont exposées séparément par `analyze_symbol_candles`.
    """
    voting_orders = [o for o in orders if not getattr(o, "counter_trend", False)]
    if not voting_orders:
        return {
            "verdict": "WAIT", "verdict_num": 0,
            "score_buy": 0.0, "score_sell": 0.0, "gap": 0.0,
            "ote_confirmed_buy": False, "ote_confirmed_sell": False,
            "contributors": [],
        }

    score_buy = 0.0
    score_sell = 0.0
    confirmed_buy = 0
    confirmed_sell = 0
    ote_confirmed_buy = False
    ote_confirmed_sell = False
    contributors: List[Dict[str, Any]] = []

    for o in voting_orders:
        weight = o.score * o.priority * (1.0 if o.confirmed else 0.45)
        if o.direction.upper() == "BUY":
            score_buy += weight
            if o.confirmed:
                confirmed_buy += 1
                if o.pattern == "SMC_OTE":
                    ote_confirmed_buy = True
        else:
            score_sell += weight
            if o.confirmed:
                confirmed_sell += 1
                if o.pattern == "SMC_OTE":
                    ote_confirmed_sell = True
        contributors.append({
            "pattern": o.pattern, "direction": o.direction, "confirmed": o.confirmed,
            "score": round(o.score, 3), "priority": o.priority, "weight": round(weight, 3),
        })

    gap = score_buy - score_sell
    total = score_buy + score_sell
    sign = 1 if gap > 0 else (-1 if gap < 0 else 0)

    if sign == 0:
        vn = 0
    else:
        has_confirmed_dir = confirmed_buy > 0 if sign > 0 else confirmed_sell > 0
        has_ote_dir = ote_confirmed_buy if sign > 0 else ote_confirmed_sell
        n_confirmed_dir = confirmed_buy if sign > 0 else confirmed_sell
        ag = abs(gap)
        if not has_confirmed_dir:
            # Aucune figure confirmée dans le sens du gap → pas d'entrée, juste WAIT
            vn = 0
        elif ag >= 1.6 and has_ote_dir and total >= 2.0:
            vn = 3 * sign   # PERFECT — OTE confirmée + dominance nette
        elif ag >= 1.0 and (has_ote_dir or n_confirmed_dir >= 2):
            vn = 2 * sign   # GOOD — OTE confirmée seule, ou >=2 figures confirmées
        else:
            vn = 1 * sign   # BUY/SELL simple

    return {
        "verdict": chartist_verdict_text(vn),
        "verdict_num": int(vn),
        "score_buy": round(score_buy, 3),
        "score_sell": round(score_sell, 3),
        "gap": round(gap, 3),
        "ote_confirmed_buy": ote_confirmed_buy,
        "ote_confirmed_sell": ote_confirmed_sell,
        "contributors": contributors,
    }


def blend_chartist_with_gom(gom_verdict_num: int, chartist_verdict_num: int) -> Tuple[int, str]:
    """Fusionne le verdict GOM principal (indicateurs/MTF, gom_pine_calculator)
    avec le verdict chartiste (figures + OTE). Optionnel : à appeler côté
    ai_server si vous voulez que les figures chartistes influencent le
    verdict final envoyé à l'EA, sans modifier gom_pine_calculator.py.

    Règle : accord des deux → on renforce (max des deux + éventuellement
    +1 si les deux étaient déjà >=2). Désaccord → on retombe sur le GOM
    principal, sauf si le chartiste est PERFECT (|3|) et le GOM est WAIT.
    """
    g = int(gom_verdict_num or 0)
    ch = int(chartist_verdict_num or 0)
    if g == 0 and ch == 0:
        return 0, "WAIT"
    g_sign = 1 if g > 0 else (-1 if g < 0 else 0)
    ch_sign = 1 if ch > 0 else (-1 if ch < 0 else 0)
    if g_sign != 0 and ch_sign != 0 and g_sign == ch_sign:
        base = max(abs(g), abs(ch))
        bonus = 1 if (abs(g) >= 2 and abs(ch) >= 2) else 0
        vn = g_sign * min(3, base + bonus)
        return vn, chartist_verdict_text(vn)
    if g_sign == 0 and abs(ch) == 3:
        return ch, chartist_verdict_text(ch)
    if g_sign != 0 and ch_sign != 0 and g_sign != ch_sign:
        # désaccord franc : on ne force pas un sens, on reste prudent
        if abs(g) >= 2:
            return g, chartist_verdict_text(g)
        return 0, "WAIT"
    return g, chartist_verdict_text(g)


def analyze_symbol_candles(symbol: str, candles: List[Dict[str, Any]]) -> Dict[str, Any]:
    df = df_from_candles(candles)
    if df is None:
        return {"ok": False, "symbol": symbol, "orders": [], "message": "not enough candles"}
    native = native_direction_for_symbol(symbol)
    found = detect_all_patterns(symbol, df, native_dir=native)

    native_found = [o for o in found if not o.counter_trend]
    ct_found = [o for o in found if o.counter_trend]

    ready = [o.to_dict() for o in native_found if o.confirmed and o.score >= 0.70]
    watch = [o.to_dict() for o in native_found if not o.confirmed]
    # Contre-tendance : déjà filtrées à COUNTER_TREND_MIN_SCORE/RR et
    # confirmées uniquement (voir detect_all_patterns) → toutes "ready".
    ct_ready = [o.to_dict() for o in ct_found]
    verdict = compute_chartist_verdict(found)
    return {
        "ok": True,
        "symbol": symbol,
        "native_direction": native or "BOTH",
        "orders": ready,
        "watch": watch,
        "count_ready": len(ready),
        "best": ready[0] if ready else None,
        # Figures CONTRE-TENDANCE (recouvrement de perte exceptionnel) :
        # exposées séparément, jamais mélangées à `orders`/`best` normaux,
        # et jamais prises en compte dans le verdict GOM ci-dessous.
        "counter_trend_orders": ct_ready,
        "count_counter_trend": len(ct_ready),
        "best_counter_trend": ct_ready[0] if ct_ready else None,
        # Verdict GOM calculé sur les figures natives (confirmées + watch),
        # avec priorité structurelle à SMC_OTE. Inchangé par la fonctionnalité
        # contre-tendance.
        "verdict": verdict["verdict"],
        "verdict_num": verdict["verdict_num"],
        "score_buy": verdict["score_buy"],
        "score_sell": verdict["score_sell"],
        "gom_verdict_detail": verdict,
    }
