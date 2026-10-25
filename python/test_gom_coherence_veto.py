#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests du veto de coherence GOMVerdictCalculatorV2.

Run:  python python/test_gom_coherence_veto.py

Contrat arbitre le 2026-09-25 :
  1. La coherence se mesure DANS LE SENS du verdict (plus de biais acheteur).
  2. Elle plafonne la magnitude, elle n'annule plus un gap franc.
  3. Seul "petit gap + aucun alignement" reste un WAIT.
  4. Les 6 indicateurs sont signes et discriminant reellement.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gom_verdict_calculator_v2 import GOMVerdictCalculatorV2  # noqa: E402


def _rec(**kw) -> dict:
    """Record neutre (tous les indicateurs neutres) + overrides."""
    base = {
        "st_dir": 0,
        "vwap_dist_pct": 0.0,
        "vwap_mag": 0.0,
        "macd_line": 0.0,
        "rsi14": 50.0,
        "kc_pos": 0.0,
        "dc_sig": 0.0,
    }
    base.update(kw)
    return base


def _bull(**kw) -> dict:
    # kc_pos=0.5 / bb_pctb=0.5 : un trend propre n'est pas "trop etire", donc
    # Keltner reste neutre -> 5/6 alignes, net 0.833 (strong).
    return _rec(st_dir=1, vwap_dist_pct=0.001, macd_line=10.0,
                rsi14=60.0, kc_pos=0.5, bb_pctb=0.5, dc_sig=1.0, **kw)


def _bear(**kw) -> dict:
    return _rec(st_dir=-1, vwap_dist_pct=-0.001, macd_line=-10.0,
                rsi14=40.0, kc_pos=-0.5, bb_pctb=0.5, dc_sig=-1.0, **kw)


CALC = GOMVerdictCalculatorV2()
CASES = []


def case(name):
    def deco(fn):
        CASES.append((name, fn))
        return fn

    return deco


# ── 1. Plus de biais acheteur dans la metrique ───────────────────────────────
@case("downtrend propre : la coherence SELL est aussi forte que la BUY")
def _t1():
    buy_info = CALC.coherence_for_direction(_bull(), 1)
    sell_info = CALC.coherence_for_direction(_bear(), -1)
    assert sell_info["aligned"] == buy_info["aligned"] == 5, (buy_info, sell_info)
    assert sell_info["net"] == buy_info["net"] == 5 / 6


@case("un downtrend net n'est plus 'incoherent' a cause des seuils acheteurs")
def _t2():
    ok, ratio = CALC.check_coherence(_bear(), -1)
    assert ok is True, f"downtrend complet doit etre coherent, ratio={ratio}"
    assert abs(ratio - 5 / 6) < 1e-9, ratio


@case("marche sans consensus : (False, 0.0), pas un ratio flatteur")
def _t3():
    ok, ratio = CALC.check_coherence(_rec(), 0)
    assert ok is False
    assert ratio == 0.0


# ── 2. Les indicateurs signes discriminant ──────────────────────────────────
@case("RSI : exces vus comme le scorer (75 = surachat SELL, 25 = survente BUY)")
def _t4():
    # rsi >= 70 sort de la bande BUY 50-70 et ne laisse qu'un point SELL
    assert CALC._indicator_votes(_rec(rsi14=75.0))["rsi"] == -1
    # rsi <= 30 : survente, seul point BUY
    assert CALC._indicator_votes(_rec(rsi14=25.0))["rsi"] == 1
    # momentum dans les bandes du scorer
    assert CALC._indicator_votes(_rec(rsi14=60.0))["rsi"] == 1
    assert CALC._indicator_votes(_rec(rsi14=40.0))["rsi"] == -1
    # rsi == 50 : neutre (le scorer n'accorde aucun point)
    assert CALC._indicator_votes(_rec(rsi14=50.0))["rsi"] == 0


@case("Keltner/BB : les exces sont mean-reversion comme les seuils 0.22/0.78")
def _t5():
    # trop etire au-dessus -> SELL, trop vendu en dessous -> BUY
    assert CALC._indicator_votes(_rec(kc_pos=0.9))["keltner"] == -1
    assert CALC._indicator_votes(_rec(kc_pos=-0.9))["keltner"] == 1
    # le centre du canal est neutre
    assert CALC._indicator_votes(_rec(kc_pos=0.0))["keltner"] == 0
    # bb_pctb pilote aussi (memes seuils que le scorer)
    assert CALC._indicator_votes(_rec(kc_pos=0.0, bb_pctb=0.9))["keltner"] == -1
    assert CALC._indicator_votes(_rec(kc_pos=0.0, bb_pctb=0.1))["keltner"] == 1


@case("VWAP utilise vwap_dist_pct (signe), pas vwap_mag (amplitude)")
def _t6():
    assert CALC._indicator_votes(_rec(vwap_mag=0.9, vwap_dist_pct=-0.001))["vwap"] == -1
    assert CALC._indicator_votes(_rec(vwap_mag=0.9, vwap_dist_pct=0.001))["vwap"] == 1


@case("MACD se lit contre sa signal, comme le scorer (macd_line vs macd_sig)")
def _t6b():
    assert CALC._indicator_votes(_rec(macd_line=5.0, macd_sig=1.0))["macd"] == 1
    assert CALC._indicator_votes(_rec(macd_line=1.0, macd_sig=5.0))["macd"] == -1
    # sans signal (0.0), c'est le signe de la ligne qui tranche
    assert CALC._indicator_votes(_rec(macd_line=-3.0))["macd"] == -1


@case("indicateurs contre le sens : net negatif et opposed_majority")
def _t7():
    info = CALC.coherence_for_direction(_bull(), -1)
    assert info["opposed"] == 5, info
    assert info["net"] == -5 / 6, info
    assert info["opposed_majority"] is True
    assert info["ok"] is False


@case("surachat contre un BUY : la coherence ne doit PAS valider (GainX 400)")
def _t7b():
    # rsi 71 (surachat -> SELL), bb_pctb 1.21 (au-dessus bande haute -> SELL)
    rec = _rec(st_dir=1, vwap_dist_pct=0.001, macd_line=10.0, macd_sig=1.0,
               rsi14=71.0, kc_pos=2.2, bb_pctb=1.21, dc_sig=1.0)
    info = CALC.coherence_for_direction(rec, 1)
    assert info["opposed"] >= 2, info
    assert info["ok"] is False, (
        f"un BUY en surachat ne doit pas s'auto-valider: {info}"
    )


# ── 3. Le veto devient un plafond de magnitude ───────────────────────────────
@case("gap 20 + coherence nulle : GOOD au lieu de WAIT (l'echappement est vivant)")
def _t8():
    rec = _rec()  # tous neutres
    vn = CALC.calculate_verdict_num(9.8, 2.9, False, 6.9, rec)
    assert vn == 2, f"attendu +2, obtenu {vn} ({rec.get('coherence_reason')})"
    assert "->GOOD" in rec["coherence_reason"]


@case("gap 20 SELL + coherence nulle : GOOD SELL, symetrique")
def _t9():
    rec = _rec()
    vn = CALC.calculate_verdict_num(3.7, 12.26, False, 8.56, rec)
    assert vn == -2, f"attendu -2, obtenu {vn} ({rec.get('coherence_reason')})"


@case("gap >= 4 + coherence forte : PERFECT")
def _t10():
    rec = _bull()
    vn = CALC.calculate_verdict_num(10.0, 2.0, True, 8.0, rec)
    assert vn == 3, f"attendu +3, obtenu {vn} ({rec.get('coherence_reason')})"


@case("gap >= 4 + tous les indicateurs contre : plafonne a SIMPLE, jamais PERFECT")
def _t11():
    rec = _bear()
    vn = CALC.calculate_verdict_num(10.0, 2.0, False, 8.0, rec)
    assert vn == 1, f"attendu +1, obtenu {vn} ({rec.get('coherence_reason')})"
    assert "opposed" in rec["coherence_reason"]


@case("gap 3 + coherence nulle : SIMPLE, plus WAIT")
def _t12():
    rec = _rec()
    vn = CALC.calculate_verdict_num(5.0, 2.0, False, 3.0, rec)
    assert vn == 1, f"attendu +1, obtenu {vn} ({rec.get('coherence_reason')})"


@case("gap 3 + coherence ok : GOOD")
def _t13():
    rec = _bull()
    vn = CALC.calculate_verdict_num(5.0, 2.0, True, 3.0, rec)
    assert vn == 2, f"attendu +2, obtenu {vn}"


# ── 4. Seul le vrai marche indecis reste WAIT ───────────────────────────────
@case("petit gap + aucun alignement : WAIT (seul WAIT legitime)")
def _t14():
    rec = _rec()
    vn = CALC.calculate_verdict_num(1.0, 0.0, False, 1.0, rec)
    assert vn == 0, f"attendu 0, obtenu {vn} ({rec.get('coherence_reason')})"
    assert "WAIT" in rec["coherence_reason"]


@case("petit gap + coherence ok : SIMPLE")
def _t15():
    rec = _bull()
    # gap 1.5 (> 1.2) avec les 6 indicateurs alignes
    vn = CALC.calculate_verdict_num(1.5, 0.0, True, 1.5, rec)
    assert vn == 1, f"attendu +1, obtenu {vn}"


@case("gap sous le seuil BUY/SELL : WAIT")
def _t16():
    rec = _bull()
    vn = CALC.calculate_verdict_num(1.0, 0.9, True, 0.1, rec)
    assert vn == 0, f"attendu 0, obtenu {vn}"


@case("scores egaux : WAIT, pas de direction a mesurer")
def _t17():
    rec = _bull()
    vn = CALC.calculate_verdict_num(5.0, 5.0, True, 0.0, rec)
    assert vn == 0, f"attendu 0, obtenu {vn}"


@case("monotonie: la pyramide est croissante et symetrique sur les deux sens")
def _t18():
    gaps = (0.5, 1.0, 1.2, 1.5, 2.0, 2.5, 3.0, 4.0, 6.0, 10.0)
    # Indicateurs NEUTRES : rien n'aligne, seul le gap parle.
    # Sous 2.5 le marche reste indecis (WAIT), au-dessus le gap suffit.
    buy = [CALC.calculate_verdict_num(1.0, 0.0, False, g, _rec()) for g in gaps]
    assert buy == [0, 0, 0, 0, 0, 1, 1, 2, 2, 2], buy
    sell = [CALC.calculate_verdict_num(0.0, 1.0, False, g, _rec()) for g in gaps]
    assert sell == [-v for v in buy], f"asymetrique: {sell} vs {buy}"

    # Indicateurs ALIGNES : la pyramide monte d'un cran partout.
    buy_aligned = [CALC.calculate_verdict_num(1.0, 0.0, True, g, _bull()) for g in gaps]
    assert buy_aligned == [0, 0, 1, 1, 1, 2, 2, 3, 3, 3], buy_aligned
    sell_aligned = [CALC.calculate_verdict_num(0.0, 1.0, True, g, _bear()) for g in gaps]
    assert sell_aligned == [-v for v in buy_aligned], sell_aligned

    # Indicateurs OPPOSES : plafonne a SIMPLE, jamais PERFECT.
    buy_opposed = [CALC.calculate_verdict_num(1.0, 0.0, False, g, _bear()) for g in gaps]
    assert max(buy_opposed) == 1, f"jamais au-dela de SIMPLE: {buy_opposed}"


@case("record sans indicateurs : degrade proprement, pas de crash")
def _t19():
    vn = CALC.calculate_verdict_num(9.0, 1.0, False, 8.0, {})
    assert vn == 2, f"attendu +2, obtenu {vn}"
    assert CALC.calculate_verdict_num(9.0, 1.0, False, 8.0, None) == 2


@case("valeurs non numeriques : fallback sur les defauts, pas d'exception")
def _t20():
    rec = _rec(st_dir="BULL", macd_line="n/a", rsi14=None, kc_pos="x", dc_sig=None)
    info = CALC.coherence_for_direction(rec, 1)
    assert 0 <= info["ratio"] <= 1.0
    assert CALC.calculate_verdict_num(9.0, 1.0, False, 8.0, rec) in (1, 2, 3)


def main() -> int:
    failures = []
    for name, fn in CASES:
        try:
            fn()
            print(f"  PASS  {name}")
        except AssertionError as exc:
            failures.append((name, str(exc)))
            print(f"  FAIL  {name}\n        {exc}")
        except Exception as exc:  # noqa: BLE001
            failures.append((name, f"{type(exc).__name__}: {exc}"))
            print(f"  ERROR {name}\n        {type(exc).__name__}: {exc}")
    print()
    print(f"{len(CASES) - len(failures)}/{len(CASES)} OK")
    if failures:
        print("\nECHECS:")
        for name, msg in failures:
            print(f"  - {name}: {msg}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
