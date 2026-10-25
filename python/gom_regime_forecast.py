#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Régime marché + prévision directionnelle sur bougies M1 réelles.

Ce n'est PAS une prédiction exacte des 5 prochaines minutes ni des 100
prochaines bougies. C'est un biais probabiliste : pente, structure HH/HL,
compression ATR, aligné avec le flux 1b/3b. L'EA n'exécute que si ce biais
et le verdict GOM ont le même signe.
"""
from __future__ import annotations

from typing import Any, Dict, List, Sequence, Tuple


def _fseq(xs: Sequence[Any], n: int = 120) -> List[float]:
    out: List[float] = []
    for x in xs[-n:]:
        try:
            v = float(x)
        except (TypeError, ValueError):
            continue
        if v > 0.0:
            out.append(v)
    return out


def _atr(highs: List[float], lows: List[float], closes: List[float], n: int = 14) -> float:
    if len(closes) < 3 or len(highs) != len(closes) or len(lows) != len(closes):
        return 0.0
    trs: List[float] = []
    for i in range(1, len(closes)):
        tr = max(
            highs[i] - lows[i],
            abs(highs[i] - closes[i - 1]),
            abs(lows[i] - closes[i - 1]),
        )
        trs.append(tr)
    if not trs:
        return 0.0
    w = trs[-n:] if len(trs) >= n else trs
    return sum(w) / float(len(w))


def _ema(vals: List[float], n: int) -> float:
    if not vals:
        return 0.0
    k = 2.0 / (n + 1.0)
    e = vals[0]
    for v in vals[1:]:
        e = v * k + e * (1.0 - k)
    return e


def _slope(vals: List[float]) -> float:
    n = len(vals)
    if n < 2:
        return 0.0
    xm = (n - 1) / 2.0
    ym = sum(vals) / float(n)
    num = sum((i - xm) * (vals[i] - ym) for i in range(n))
    den = sum((i - xm) ** 2 for i in range(n)) or 1.0
    return num / den


def _structure_sign(highs: List[float], lows: List[float]) -> int:
    """+1 HH+HL, -1 LH+LL, 0 range/chop. Pivots 2 barres, bougies closes."""
    if len(highs) < 12:
        return 0
    sh: List[float] = []
    sl: List[float] = []
    # skip last bar (en formation)
    end = len(highs) - 1
    for i in range(2, end - 2):
        if highs[i] >= highs[i - 1] and highs[i] >= highs[i - 2] and highs[i] > highs[i + 1]:
            sh.append(highs[i])
        if lows[i] <= lows[i - 1] and lows[i] <= lows[i - 2] and lows[i] < lows[i + 1]:
            sl.append(lows[i])
    if len(sh) < 2 or len(sl) < 2:
        return 0
    hh = sh[-1] > sh[-2]
    hl = sl[-1] > sl[-2]
    lh = sh[-1] < sh[-2]
    ll = sl[-1] < sl[-2]
    if hh and hl:
        return 1
    if lh and ll:
        return -1
    return 0


def classify_regime(
    closes: List[float], highs: List[float], lows: List[float]
) -> Tuple[str, int, float]:
    """Retourne (regime, bias +1/-1/0, atr)."""
    if len(closes) < 16:
        return "UNKNOWN", 0, 0.0
    atr = _atr(highs, lows, closes, 14)
    atr50 = _atr(highs, lows, closes, min(50, len(closes) - 1))
    e8 = _ema(closes, 8)
    e21 = _ema(closes, min(21, len(closes)))
    sl5 = _slope(closes[-5:])
    sl20 = _slope(closes[-20:] if len(closes) >= 20 else closes)
    st = _structure_sign(highs, lows)
    last_body = abs(closes[-1] - closes[-2]) if len(closes) >= 2 else 0.0
    impulse = atr > 0 and last_body >= atr * 1.15
    compressed = atr50 > 0 and atr < atr50 * 0.72

    bias = 0
    if e8 > e21 and sl20 > 0:
        bias = 1
    elif e8 < e21 and sl20 < 0:
        bias = -1
    if st != 0:
        # Note : la structure (HH/HL vs LH/LL) a toujours priorite sur
        # EMA/pente quand elle est tranchee, y compris en cas de conflit.
        bias = st

    if impulse and bias != 0:
        return ("IMPULSE_UP" if bias > 0 else "IMPULSE_DOWN"), bias, atr
    if compressed:
        return "COMPRESSION", bias, atr
    if bias > 0 and st >= 0:
        return "TREND_UP", 1, atr
    if bias < 0 and st <= 0:
        return "TREND_DOWN", -1, atr
    if abs(sl5) < (atr * 0.06 if atr > 0 else 1e-9) and st == 0:
        return "RANGE", 0, atr
    return "RANGE", bias, atr


def forecast_direction(closes: List[float], atr: float, horizon: int) -> Tuple[str, float]:
    """Biais extrapolé depuis la pente passée; ce n'est pas un forecast futur."""
    if len(closes) < max(6, horizon // 8):
        return "NEUT", 0.0
    win = closes[-min(len(closes), max(horizon, 8)) :]
    sl = _slope(win)
    thr = (atr * (0.08 if horizon <= 8 else 0.035)) if atr > 0 else 0.0
    mag = abs(sl)
    conf = 0.0 if thr <= 0 else min(1.0, mag / (thr * 2.5))
    if mag < thr:
        return "NEUT", conf * 0.4
    return ("BUY" if sl > 0 else "SELL"), conf


def apply_regime_forecast_gate(record: Dict[str, Any], verdict_num: int) -> int:
    vn = int(verdict_num or 0)
    closes = _fseq(record.get("_m1_closes") or [])
    highs = _fseq(record.get("_m1_highs") or [])
    lows = _fseq(record.get("_m1_lows") or [])
    if len(closes) < 16:
        record["gom_regime"] = str(record.get("gom_regime") or "UNKNOWN")
        record["gom_forecast_5m"] = "NEUT"
        record["gom_forecast_100"] = "NEUT"
        return vn
    # Bougie 0 souvent en formation : structure/pente sur closes uniquement.
    if len(closes) > 20:
        closes = closes[:-1]
        if len(highs) == len(closes) + 1:
            highs = highs[:-1]
        if len(lows) == len(closes) + 1:
            lows = lows[:-1]

    if len(highs) != len(closes) or len(lows) != len(closes):
        n = min(len(closes), len(highs) if highs else len(closes), len(lows) if lows else len(closes))
        closes, highs, lows = closes[-n:], (highs or closes)[-n:], (lows or closes)[-n:]

    regime, bias, atr = classify_regime(closes, highs, lows)
    d5, c5 = forecast_direction(closes, atr, 5)
    d100, c100 = forecast_direction(closes, atr, 100)
    if regime == "RANGE" and d100 != "NEUT" and c100 < 0.35:
        d100, c100 = "NEUT", c100 * 0.5

    d1 = float(record.get("price_direction_1b", 0) or 0)
    d3 = float(record.get("price_direction_3b", 0) or 0)
    candle_sign = 0
    if d1 > 0 and d3 > 0:
        candle_sign = 1
    elif d1 < 0 and d3 < 0:
        candle_sign = -1

    def _dir_sign(s: str) -> int:
        u = str(s).upper()
        if u == "BUY":
            return 1
        if u == "SELL":
            return -1
        return 0

    s5 = _dir_sign(d5)
    s100 = _dir_sign(d100)
    vsign = 1 if vn > 0 else (-1 if vn < 0 else 0)
    mag = abs(vn)
    reason = f"{regime} 5m={d5}@{c5:.2f} 100={d100}@{c100:.2f}"

    # Compression / range : pas de PERFECT, souvent WAIT si bougies mixtes
    if regime in ("RANGE", "COMPRESSION") and candle_sign == 0:
        mag = min(mag, 1) if mag else 0
        if mag == 0:
            reason += " ->WAIT chop"
            vn = 0
        else:
            vn = vsign * mag
            reason += " ->SIMPLE max"
    elif regime in ("RANGE", "COMPRESSION") and mag >= 3:
        mag = 2
        vn = vsign * mag
        reason += " ->cap GOOD"
    elif vn == 0 and candle_sign != 0:
        # Dump/rally franc : RANGE ne doit pas coller WAIT (cas PainX 400).
        sym_u = str(record.get("symbol", "") or "").upper()
        crash_fam = "PAIN" in sym_u or "CRASH" in sym_u
        boom_fam = "GAIN" in sym_u or "BOOM" in sym_u
        if crash_fam and candle_sign < 0:
            vn = -2
            reason += " ->GOOD dump live (RANGE ignoré)"
        elif boom_fam and candle_sign > 0:
            vn = 2
            reason += " ->GOOD rally live (RANGE ignoré)"
        elif candle_sign == s5 and s5 != 0:
            vn = s5 * 2
            reason += " ->GOOD flux+5m (RANGE ignoré)"

    vsign = 1 if vn > 0 else (-1 if vn < 0 else 0)
    mag = abs(vn)

    # 5 minutes : si le court terme contredit le verdict, l'EA ne doit pas trader
    # -- mais seulement si ce signal 5m est lui-meme fiable (c5 significatif).
    # Avant : n'importe quel s5 (meme a confiance quasi nulle, fenetre de 8
    # bougies tres bruitee) annulait totalement un PERFECT/GOOD confirme
    # ailleurs dans le pipeline -> WAIT en exces, deconnecte du prix reel.
    C5_VETO_MIN_CONF = 0.30
    if s5 != 0 and vsign != 0 and s5 != vsign:
        dump_holds = candle_sign < 0 and vsign < 0
        rally_holds = candle_sign > 0 and vsign > 0
        if dump_holds or rally_holds:
            reason += " ->5m contre mais flux 1b+3b tient, ignore veto"
        elif c5 >= C5_VETO_MIN_CONF:
            vn = 0
            reason += " ->WAIT 5m contre verdict"
        elif mag >= 3:
            vn = vsign * 2
            reason += " ->SIMPLE->GOOD 5m faible conf, pas de WAIT total"
        else:
            reason += " ->5m contre verdict mais conf trop faible, ignore"
    elif s5 != 0 and vsign == 0 and candle_sign == s5 and regime.startswith("TREND"):
        vn = s5 * 2
        reason += " ->GOOD aligné régime+5m"
    elif s5 != 0 and vsign == 0 and candle_sign == s5 and regime.startswith("IMPULSE"):
        vn = s5 * 2
        reason += " ->GOOD impulse 5m"

    vsign = 1 if vn > 0 else (-1 if vn < 0 else 0)
    mag = abs(vn)

    # PERFECT seulement si 5m + bougies + (100b même signe ou NEUT) + tendance
    if mag >= 3:
        ok_5 = s5 == 0 or s5 == vsign
        ok_c = candle_sign == 0 or candle_sign == vsign
        ok_100 = s100 == 0 or s100 == vsign
        ok_reg = regime.startswith("TREND") or regime.startswith("IMPULSE")
        if not (ok_5 and ok_c and ok_100 and ok_reg and c5 >= 0.45):
            mag = 2
            vn = vsign * mag
            reason += " ->PERFECT refusé (pas d'accord 5m/100/bougies)"

    # 100 bougies contre 5m : court terme seulement (GOOD max)
    if s5 != 0 and s100 != 0 and s5 != s100 and abs(vn) >= 3:
        vn = s5 * 2
        reason += " ->GOOD (5m vs 100 divergents)"

    record["gom_regime"] = regime
    record["gom_forecast_kind"] = "historical_slope_bias"
    record["gom_forecast_5m"] = d5
    record["gom_forecast_100"] = d100
    record["gom_slope_bias_5m"] = d5
    record["gom_slope_bias_100"] = d100
    record["gom_slope_bias_conf_5m"] = round(c5, 3)
    record["gom_forecast_conf"] = round(max(c5, c100 * 0.6), 3)
    record["gom_forecast_conf_5m"] = round(c5, 3)
    record["gom_forecast_conf_100"] = round(c100, 3)
    record["gom_regime_bias"] = int(bias)
    record["gom_regime_reason"] = reason
    cog5 = "BUY" if d5 == "BUY" else ("SELL" if d5 == "SELL" else "NEUTRAL")
    record["cog_regime"] = regime
    record["gom_slope_bias_direction_5m"] = cog5
    return int(vn)
