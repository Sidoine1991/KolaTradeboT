# -*- coding: utf-8 -*-
"""
GOM path prediction — séquence directionnelle sur N bougies futures.
Partagé entre ai_server.py et gom_verdict_poller.py (miroir logique Pine).
"""
from __future__ import annotations

import math
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple
from uuid import uuid4


def _clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))


def compute_path_directions(
    *,
    horizon: int = 200,
    score_buy: float = 0.0,
    score_sell: float = 0.0,
    verdict_gap: float = 0.0,
    st_dir: int = 0,
    tf_global_dir: Optional[str] = None,
    tf_bull_count: int = 0,
    tf_bear_count: int = 0,
    bos_bull: bool = False,
    bos_bear: bool = False,
    choch_bull: bool = False,
    choch_bear: bool = False,
    dc_sig: float = 0.0,
    kc_pos: float = 0.0,
    ema_ribbon: int = 2,
) -> str:
    """Retourne une chaîne de longueur `horizon` avec U/D/N."""
    gd = 0
    if tf_global_dir:
        g = tf_global_dir.upper()
        gd = 1 if g == "BULL" else -1 if g == "BEAR" else 0
    elif tf_bull_count or tf_bear_count:
        gd = 1 if tf_bull_count > tf_bear_count + 1 else -1 if tf_bear_count > tf_bull_count + 1 else 0

    side = 1 if score_buy > score_sell else -1 if score_sell > score_buy else 0
    gap_n = _clamp(verdict_gap / 3.5, 0.0, 1.0) if verdict_gap else _clamp(abs(score_buy - score_sell) / 3.5, 0.0, 1.0)

    path_base = 0.0
    path_base += gd * 0.32
    path_base += side * gap_n * 0.28
    path_base += (1 if st_dir > 0 else -1 if st_dir < 0 else 0) * 0.14
    path_base += (0.10 if bos_bull else 0.0) + (-0.10 if bos_bear else 0.0)
    path_base += (0.08 if choch_bull else 0.0) + (-0.08 if choch_bear else 0.0)
    if tf_bull_count or tf_bear_count:
        path_base += ((tf_bull_count - tf_bear_count) / 7.0) * 0.12
    path_base += _clamp(dc_sig, -1.0, 1.0) * 0.06
    path_base += (0.05 if kc_pos > 0.2 else -0.05 if kc_pos < -0.2 else 0.0)
    path_base += (0.06 if ema_ribbon >= 3 else -0.06 if ema_ribbon <= 1 else 0.0)
    path_base = _clamp(path_base, -1.0, 1.0)

    chars: List[str] = []
    for step in range(1, horizon + 1):
        decay = 1.0 - (step / (horizon * 1.15))
        micro = math.sin(step * 0.29 + path_base * 2.0) * 0.11
        sc = path_base * decay + micro
        if sc > 0.055:
            chars.append("U")
        elif sc < -0.055:
            chars.append("D")
        else:
            chars.append("N")
    return "".join(chars)


def _collect_sr_levels(record: Dict[str, Any], base_price: float) -> Tuple[List[float], List[float]]:
    supports: List[float] = []
    resistances: List[float] = []
    for key in ("kola_buy", "bb_dn", "fib_382", "fib_500", "fib_618", "setup_sl"):
        v = float(record.get(key) or 0)
        if v > 0 and v < base_price:
            supports.append(v)
    for key in ("kola_sell", "bb_up", "fib_618", "fib_786", "setup_tp1", "setup_entry"):
        v = float(record.get(key) or 0)
        if v > 0 and v > base_price:
            resistances.append(v)
    supports = sorted(set(round(x, 8) for x in supports), reverse=True)
    resistances = sorted(set(round(x, 8) for x in resistances))
    return supports, resistances


def apply_sr_retest_to_path(
    path_dirs: str,
    base_price: float,
    atr_value: float,
    record: Optional[Dict[str, Any]] = None,
    *,
    step_atr_mult: float = 0.16,
) -> str:
    """Ajuste U/D/N aux retests support/résistance (KOLA, BB, Fib)."""
    if not path_dirs or base_price <= 0:
        return path_dirs
    rec = record or {}
    supports, resistances = _collect_sr_levels(rec, base_price)
    if not supports and not resistances:
        return path_dirs

    step_px = max(atr_value, base_price * 0.0001) * step_atr_mult
    tol = step_px * 0.35
    y = float(base_price)
    out: List[str] = []

    for ch in path_dirs:
        d = 1 if ch == "U" else -1 if ch == "D" else 0
        ny = y + d * step_px
        snapped = False

        if d > 0 and resistances:
            for r in resistances:
                if y <= r + tol and ny >= r - tol:
                    ny = r - step_px * 0.08
                    out.extend(["N", "D"])
                    snapped = True
                    break
        elif d < 0 and supports:
            for s in supports:
                if ny <= s + tol and y >= s - tol:
                    ny = s + step_px * 0.08
                    out.extend(["N", "U"])
                    snapped = True
                    break

        if not snapped:
            out.append(ch)
        y = ny

    result = "".join(out)
    if len(result) > len(path_dirs):
        result = result[: len(path_dirs)]
    elif len(result) < len(path_dirs):
        result += path_dirs[len(result) :]
    return result


def compute_setup_probabilities(path_dirs: str, setup_dir: int = 0) -> Dict[str, float]:
    summ = path_summary(path_dirs)
    horizon = max(1, summ["pred_horizon"])
    buy_prob = summ["pred_bull"] / horizon
    sell_prob = summ["pred_bear"] / horizon
    valid_prob = buy_prob if setup_dir == 1 else sell_prob if setup_dir == -1 else max(buy_prob, sell_prob)
    net = int(summ["pred_net"])
    if setup_dir == 1 and net > 0:
        valid_prob = min(0.97, valid_prob * 1.12)
    elif setup_dir == -1 and net < 0:
        valid_prob = min(0.97, valid_prob * 1.12)
    return {
        "setup_buy_prob": round(buy_prob, 4),
        "setup_sell_prob": round(sell_prob, 4),
        "setup_valid_prob": round(valid_prob, 4),
    }


def path_summary(path_dirs: str) -> Dict[str, Any]:
    bulls = path_dirs.count("U")
    bears = path_dirs.count("D")
    neut = path_dirs.count("N")
    horizon = len(path_dirs) or 1
    return {
        "pred_horizon": len(path_dirs),
        "pred_bull": bulls,
        "pred_bear": bears,
        "pred_neut": neut,
        "pred_net": bulls - bears,
        "pred_bias": (bulls - bears) / horizon,
        "pred_path": path_dirs,
    }


def path_to_ohlc_candles(
    path_dirs: str,
    base_price: float,
    atr_value: float,
    *,
    step_atr_mult: float = 0.16,
    bar_seconds: int = 60,
) -> List[Dict[str, Any]]:
    """Projette OHLC par pas directionnel (pour prediction_candles)."""
    if not path_dirs or base_price <= 0:
        return []
    atr = max(atr_value, base_price * 0.0001)
    step_px = atr * step_atr_mult
    t0 = int(datetime.now(timezone.utc).timestamp())
    y = float(base_price)
    rows: List[Dict[str, Any]] = []
    for i, ch in enumerate(path_dirs, start=1):
        d = 1 if ch == "U" else -1 if ch == "D" else 0
        o = y
        c = y + d * step_px
        h = max(o, c) + (step_px * 0.15 if d >= 0 else step_px * 0.05)
        l = min(o, c) - (step_px * 0.05 if d >= 0 else step_px * 0.15)
        conf = 0.55 + 0.35 * (1.0 if d != 0 else 0.0)
        rows.append({
            "time": t0 + i * bar_seconds,
            "open": round(o, 8),
            "high": round(h, 8),
            "low": round(l, 8),
            "close": round(c, 8),
            "confidence": round(conf, 4),
            "phase": "gom_path",
            "structure_tag": ch,
            "level_ref": round(c, 8),
        })
        y = c
    return rows


def infer_tv_setup_from_gom(record: Dict[str, Any]) -> Dict[str, Any]:
    """
    Reconstruit le tableau SETUP si les plots Pine ne sont pas encore lus par le poller
    (même logique que GOM_KOLA_SIDO.pine : OB + gap scores).
    """
    out = dict(record)
    if int(out.get("setup_dir") or 0) != 0 and float(out.get("setup_entry") or 0) > 0:
        return out

    sb = float(out.get("score_buy") or 0)
    ss = float(out.get("score_sell") or 0)
    gap = float(out.get("verdict_gap") or abs(sb - ss))
    price = float(out.get("price") or 0)
    kola_buy = float(out.get("kola_buy") or 0)
    kola_sell = float(out.get("kola_sell") or 0)
    if price <= 0 or gap < 0.8:
        return out

    atr_est = price * 0.0012 if ("XAU" in str(out.get("symbol", "")).upper() or "GOLD" in str(out.get("symbol", "")).upper()) else price * 0.0008

    bb_up = float(out.get("bb_up") or 0)
    bb_dn = float(out.get("bb_dn") or 0)

    if sb >= ss and kola_buy > 0:
        # Entry sous le prix (BuyLimit). max(..., price) provoquait Invalid price en MT5.
        entry_cand = kola_buy
        if bb_up > 0 and bb_up < price - price * 0.00005:
            entry_cand = bb_up
        elif bb_dn > 0 and bb_dn < price:
            entry_cand = max(bb_dn, kola_buy)
        entry = min(entry_cand, price - atr_est * 0.08)
        if entry <= 0 or entry >= price:
            entry = kola_buy
        sl = kola_buy - atr_est * 0.12
        risk = entry - sl
        if risk <= price * 0.00005:
            return out
        out.update({
            "setup_dir": 1,
            "setup_type": "OB_BULL",
            "setup_entry": round(entry, 3),
            "setup_sl": round(sl, 3),
            "setup_tp1": round(entry + risk, 3),
            "setup_tp2": round(entry + risk * 1.5, 3),
            "setup_rr": 1.0,
            "setup_confirm": out.get("setup_confirm") or "",
            "setup_inferred": True,
        })
    elif ss > sb and kola_sell > 0:
        entry_cand = kola_sell
        if bb_dn > 0 and bb_dn > price + price * 0.00005:
            entry_cand = bb_dn
        elif bb_up > 0 and bb_up > price:
            entry_cand = min(bb_up, kola_sell)
        entry = max(entry_cand, price + atr_est * 0.08)
        if entry <= 0 or entry <= price:
            entry = kola_sell
        sl = kola_sell + atr_est * 0.12
        risk = sl - entry
        if risk <= price * 0.00005:
            return out
        out.update({
            "setup_dir": -1,
            "setup_type": "OB_BEAR",
            "setup_entry": round(entry, 3),
            "setup_sl": round(sl, 3),
            "setup_tp1": round(entry - risk, 3),
            "setup_tp2": round(entry - risk * 1.5, 3),
            "setup_rr": 1.0,
            "setup_confirm": out.get("setup_confirm") or "",
            "setup_inferred": True,
        })
    return out


def apply_path_to_gom_record(record: Dict[str, Any], path_dirs: Optional[str] = None) -> Dict[str, Any]:
    """
    Enrichit le record GOM avec le chemin prédit et ajuste scores/verdict.
  """
    if not path_dirs:
        path_dirs = compute_path_directions(
            horizon=int(record.get("pred_horizon") or 200),
            score_buy=float(record.get("score_buy") or 0),
            score_sell=float(record.get("score_sell") or 0),
            verdict_gap=float(record.get("verdict_gap") or 0),
            st_dir=int(record.get("st_dir") or 0),
            tf_global_dir=record.get("tf_global_dir"),
            tf_bull_count=int(record.get("tf_bull_count") or 0),
            tf_bear_count=int(record.get("tf_bear_count") or 0),
        )

    base_price = float(record.get("price") or 0)
    atr_est = base_price * 0.0012 if base_price > 0 else 1.0
    if "XAU" in str(record.get("symbol", "")).upper() or "GOLD" in str(record.get("symbol", "")).upper():
        atr_est = base_price * 0.0012
    elif base_price > 0:
        atr_est = base_price * 0.0008
    path_dirs = apply_sr_retest_to_path(path_dirs, base_price, atr_est, record)

    summ = path_summary(path_dirs)
    out = {**record, **summ}
    out.update(compute_setup_probabilities(path_dirs, int(record.get("setup_dir") or 0)))

    sb = float(out.get("score_buy") or 0)
    ss = float(out.get("score_sell") or 0)
    bias = float(summ["pred_bias"])
    adj = abs(bias) * 2.2
    if bias > 0.10:
        sb += adj
        ss -= adj * 0.35
    elif bias < -0.10:
        ss += adj
        sb -= adj * 0.35

    gap = abs(sb - ss)
    out["score_buy"] = round(sb, 2)
    out["score_sell"] = round(ss, 2)
    out["verdict_gap"] = round(gap, 2)

    # Recalcul verdict_num / label si chemin fort
    vnum = int(out.get("verdict_num") or 0)
    coherence = float(out.get("coherence_pct") or 0) / 100.0 if float(out.get("coherence_pct") or 0) > 1 else float(out.get("coherence_pct") or 0)
    coherence_ok = coherence >= 0.40 or gap >= 1.65

    if sb > ss and gap >= 4.0 and coherence_ok:
        vnum, verdict = 3, "PERFECT BUY"
    elif sb > ss and gap >= 2.5 and coherence_ok:
        vnum, verdict = 2, "GOOD BUY"
    elif sb > ss and gap >= 1.2 and coherence_ok:
        vnum, verdict = 1, "BUY"
    elif ss > sb and gap >= 4.0 and coherence_ok:
        vnum, verdict = -3, "PERFECT SELL"
    elif ss > sb and gap >= 2.5 and coherence_ok:
        vnum, verdict = -2, "GOOD SELL"
    elif ss > sb and gap >= 1.2 and coherence_ok:
        vnum, verdict = -1, "SELL"
    else:
        verdict = out.get("verdict") or "WAIT"
        if vnum == 0:
            verdict = "WAIT"

    # Affaiblir verdict si chemin contredit fortement
    if vnum > 0 and summ["pred_net"] < -25:
        vnum = max(1, vnum - 1)
        verdict = "BUY" if vnum == 1 else "GOOD BUY" if vnum == 2 else verdict
    elif vnum < 0 and summ["pred_net"] > 25:
        vnum = min(-1, vnum + 1)
        verdict = "SELL" if vnum == -1 else "GOOD SELL" if vnum == -2 else verdict

    out["verdict_num"] = vnum
    out["verdict"] = verdict
    out["path_guided"] = True
    return out
