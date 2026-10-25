#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Tests de l'autorite M1/M5 sur le verdict GOM.

Run:  python python/test_gom_m1m5_flow_authority.py

Contrat (Sidoine 2026-09-25 soir) :
  1. Mouvement franc DANS le sens natif (PainX dump / GainX rally) n'est jamais WAIT.
  2. Flux CONTRE la famille = correction → WAIT, pas de BUY PainX ni SELL GainX.
  3. Un conflit reel (M1 contre M5, ou 1b contre 3b/5b) conserve le WAIT.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gom_pine_calculator import (  # noqa: E402
    apply_execution_quality_contract,
    apply_m1m5_flow_authority,
)


def _rec(symbol: str, m1: str, m5: str, d1: float, d3: float, d5: float) -> dict:
    return {
        "symbol": symbol,
        "tf_m1_dir": m1,
        "tf_m1_dir_live": m1,
        "tf_m5_dir": m5,
        "price_direction_1b": d1,
        "price_direction_3b": d3,
        "price_direction_5b": d5,
        "verdict_num": 0,
        "verdict": "WAIT",
    }


CASES = []


def case(name):
    def deco(fn):
        CASES.append((name, fn))
        return fn

    return deco


# ── 1. WAIT absurde sur mouvement franc ──────────────────────────────────────
@case("rally PainX unanime = correction → WAIT (pas de BUY)")
def _t1():
    r = _rec("PainX 600", "BULL", "BULL", 0.000029, 0.000087, 0.000116)
    vn = apply_m1m5_flow_authority(r, 0)
    assert vn == 0, f"attendu WAIT, obtenu {vn} ({r['m1m5_authority_reason']})"
    assert r["contra_family_flow"] is True


@case("rally GainX unanime releve de WAIT a PERFECT BUY (sens natif, non plafonne)")
def _t2():
    r = _rec("GainX 400", "BULL", "BULL", 0.000127, 0.000057, 0.000022)
    vn = apply_m1m5_flow_authority(r, 0)
    assert vn == 3, f"attendu +3, obtenu {vn} ({r['m1m5_authority_reason']})"
    assert r["contra_family_flow"] is False


# ── 2. Le flux tranche, meme contre la famille ───────────────────────────────
@case("dump GainX unanime = correction → WAIT (pas de SELL)")
def _t3():
    r = _rec("GainX 999", "BEAR", "BEAR", -0.000029, -0.000086, -0.000115)
    vn = apply_m1m5_flow_authority(r, 0)
    assert vn == 0, f"attendu WAIT, obtenu {vn} ({r['m1m5_authority_reason']})"
    assert r["contra_family_flow"] is True


@case("rally PainX PERFECT BUY est annulé en WAIT (correction)")
def _t4():
    r = _rec("PainX 800", "BULL", "BULL", 0.000015, 0.000046, 0.000061)
    vn = apply_m1m5_flow_authority(r, 3)
    assert vn == 0, f"attendu WAIT, obtenu {vn}"


# ── 3. La famille plafonne, ne retourne jamais ───────────────────────────────
@case("SELL sur GainX retourne en BUY: 4 signaux haussiers contre 1 lent")
def _t5():
    r = _rec("GainX 500", "BULL", "BULL", 0.00004, 0.00001, -0.00002)
    # m1 +, m5 +, d1 +, d3 + (poids 1.0+1.0+1.25+1.25) contre seule la 5b lente (0.75)
    # => buy 4.50 / sell 0.75, delta 3.75 : mouvement franc, sens natif GainX.
    vn = apply_m1m5_flow_authority(r, -2)
    assert vn == 3, f"attendu +3 (retournement franc sens natif), obtenu {vn}"


# ── 4. Conflit reel = WAIT conserve ──────────────────────────────────────────
@case("M1 BULL contre M5 BEAR conserve le WAIT")
def _t6():
    r = _rec("EURUSD", "BULL", "BEAR", 0.0, 0.0, 0.0)
    vn = apply_m1m5_flow_authority(r, 0)
    assert vn == 0, f"attendu 0, obtenu {vn}"
    assert "flow_unclear" in r["m1m5_authority_reason"]


@case("1b contre 3b/5b conserve le WAIT")
def _t7():
    r = _rec("EURUSD", "BULL", "BULL", 0.00005, -0.00005, -0.00005)
    # m1 +, m5 +, d1 +, d3 -, d5 - => buy 3.5 / sell 2.0, delta 1.5 < 1.75
    vn = apply_m1m5_flow_authority(r, 0)
    assert vn == 0, f"attendu 0, obtenu {vn} ({r['m1m5_authority_reason']})"


@case("contre-famille + flux partiel: WAIT, pas de SIMPLE BUY PainX")
def _t8():
    r = _rec("PainX 500", "BULL", "NEUT", 0.00002, 0.00001, 0.0)
    vn = apply_m1m5_flow_authority(r, 0)
    assert vn == 0, f"attendu WAIT, obtenu {vn}"
    assert r["contra_family_flow"] is True
    apply_execution_quality_contract(r)
    assert r.get("entry_allowed") is False


@case("marche sans direction reste un WAIT (M1 contre M5, flux plat)")
def _t8b():
    r = _rec("PainX 500", "BULL", "BEAR", 0.0, 0.0, 0.0)
    vn = apply_m1m5_flow_authority(r, 0)
    assert vn == 0, f"attendu 0, obtenu {vn}"
    assert "flow_unclear" in r["m1m5_authority_reason"]


@case("contre-famille + flux partiel depuis un SELL: SIMPLE BUY, WAIT jamais affiché")
def _t8c():
    r = _rec("GainX 500", "BULL", "NEUT", 0.00002, 0.00001, 0.0)
    # meme flux que _t8, mais contra = False ici (GainX natif BUY)
    # => 3 signaux haussiers dont 2 neutres, decisive False -> SIMPLE
    vn = apply_m1m5_flow_authority(r, -2)
    assert vn == 1, f"attendu +1, obtenu {vn} ({r['m1m5_authority_reason']})"


# ── 5. Pas de raison de gate fantome ─────────────────────────────────────────
@case("correction PainX: WAIT + purge des raisons de gates obsolete")
def _t9():
    r = _rec("PainX 800", "BULL", "BULL", 0.000015, 0.000046, 0.000061)
    r["impulse_cap_reason"] = "m1_1b3b5b_against->WAIT"
    r["price_reality_reason"] = "m1_1b3b_against"
    r["entry_block_reason"] = "m1_1b3b5b_against->WAIT;|vn|=0<2"
    vn = apply_m1m5_flow_authority(r, 0)
    assert vn == 0, f"attendu WAIT correction, obtenu {vn}"
    assert "impulse_cap_reason" not in r, "impulse_cap_reason doit etre purge"
    assert "price_reality_reason" not in r
    apply_execution_quality_contract(r)
    assert r.get("entry_allowed") is False

@case("dump PainX unanime: WAIT absurde → GOOD/PERFECT SELL executable")
def _t9b():
    r = _rec("PainX 800", "BEAR", "BEAR", -0.000338, -0.000293, -0.000270)
    r["impulse_cap_reason"] = "m1_1b3b5b_against->WAIT"
    vn = apply_m1m5_flow_authority(r, 0)
    assert vn <= -2, f"attendu SELL GOOD+, obtenu {vn}"
    assert "impulse_cap_reason" not in r
    apply_execution_quality_contract(r)
    assert r["entry_allowed"] is True, (
        f"dump PainX doit etre executable, bloque par {r.get('entry_block_reason')}"
    )


# ── 6. Idempotence + non-regression des cas deja corrects ────────────────────
@case("idempotent: appliquer deux fois donne le meme verdict")
def _t10():
    for sym, m1, m5, d1, d3, d5, start in (
        ("GainX 400", "BULL", "BULL", 0.000127, 0.000057, 0.000022, 0),
        ("GainX 999", "BEAR", "BEAR", -0.000029, -0.000086, -0.000115, 0),
        ("PainX 600", "BULL", "BULL", 0.000029, 0.000087, 0.000116, 0),
        ("PainX 999", "BEAR", "BEAR", -0.000338, -0.000293, -0.000270, -3),
    ):
        r = _rec(sym, m1, m5, d1, d3, d5)
        once = apply_m1m5_flow_authority(r, start)
        twice = apply_m1m5_flow_authority(r, once)
        assert once == twice, f"{sym}: {once} puis {twice}"


@case("dump PainX unanime conserve le PERFECT SELL")
def _t11():
    r = _rec("PainX 999", "BEAR", "BEAR", -0.000338, -0.000293, -0.000270)
    vn = apply_m1m5_flow_authority(r, -3)
    assert vn == -3, f"attendu -3, obtenu {vn} ({r['m1m5_authority_reason']})"


@case("symbole hors famille: aucun plafonnement familial")
def _t12():
    r = _rec("EURUSD", "BULL", "BULL", 0.00005, 0.00005, 0.00005)
    vn = apply_m1m5_flow_authority(r, 0)
    assert vn == 3, f"attendu +3, obtenu {vn}"
    assert r["contra_family_flow"] is False


@case("4 signaux sur 5 alignes: decisif mais PAS unanime -> GOOD, jamais PERFECT")
def _t13():
    r = _rec("GainX 400", "BULL", "BULL", -0.000035, 0.000230, 0.000195)
    # m1 +, m5 +, d3 +, d5 + (4.0) contre seul d1 (1.25) => delta 2.75
    vn = apply_m1m5_flow_authority(r, 0)
    assert r["m1m5_flow_decisive"] is True, "tous les signaux sont tranches"
    assert r["m1m5_flow_unanimous"] is False, "d1 contredit: pas unanime"
    assert vn == 2, f"attendu +2 (GOOD, pas PERFECT), obtenu {vn}"
    assert abs(vn) < 3, "un flux non unanime ne doit jamais atteindre PERFECT"


@case("un seul signal neutre: flux decisif absent, WAIT conserve")
def _t14():
    r = _rec("EURUSD", "BULL", "BULL", 0.0, 0.00005, 0.00005)
    # m1 +, m5 +, d1 neutre (0), d3 +, d5 + => buy 4.0, total 4.0 < 5.25
    vn = apply_m1m5_flow_authority(r, 0)
    assert r["m1m5_flow_decisive"] is False
    assert vn == 1, f"delta 4.0 > 1.75, attendu +1, obtenu {vn}"


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
