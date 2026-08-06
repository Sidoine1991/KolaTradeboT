#!/usr/bin/env python3
"""Tests gardes cohérence verdict GOM vs prix M1 / post-spike."""

import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, "python"))
sys.path.insert(0, ROOT)

from gom_pine_calculator import apply_price_reality_gate, verdict_text_from_num


def test_stale_spike_demotes_perfect():
    rec = {
        "tf_m1_dir": "BULL",
        "bars_since_spike": 11,
        "m1_opp_bars": 0,
        "price_direction_5b": 0.0002,
    }
    vn, reason = apply_price_reality_gate(rec, 3)
    assert vn == 2, f"expected GOOD, got {vn} {reason}"
    assert "stale" in reason


def test_stale_spike_force_wait():
    rec = {"tf_m1_dir": "BULL", "bars_since_spike": 16, "m1_opp_bars": 0}
    vn, reason = apply_price_reality_gate(rec, 3)
    assert vn == 0
    assert "15" in reason


def test_micro_stairs_perfect_to_wait():
    rec = {
        "tf_m1_dir": "BEAR",
        "bars_since_spike": 3,
        "m1_opp_bars": 4,
        "price_direction_5b": -0.0002,
    }
    vn, reason = apply_price_reality_gate(rec, 3)
    assert vn == 0
    assert "micro_stairs" in reason


def test_price_strong_down_vs_buy():
    rec = {
        "tf_m1_dir": "NEUT",
        "bars_since_spike": 2,
        "m1_opp_bars": 0,
        "price_direction_5b": -0.002,
    }
    vn, reason = apply_price_reality_gate(rec, 3)
    assert vn == 0
    assert "price_strong_down" in reason


def test_m1_against_demotes_perfect():
    rec = {
        "tf_m1_dir": "BEAR",
        "bars_since_spike": 4,
        "m1_opp_bars": 1,
        "price_direction_5b": -0.0003,
    }
    vn, reason = apply_price_reality_gate(rec, 3)
    assert vn == 2
    assert "m1_against" in reason


def test_finalize_synthetic_correction_wait():
    os.environ.setdefault("GOM_USE_CORRECTION_WAIT_OVERLAY", "1")
    os.environ.setdefault("GOM_USE_PREDICTIVE_BLEND", "0")
    os.environ.setdefault("GOM_FORCE_PINE_RECALC", "0")

    import ai_server

    from ai_server import _gom_finalize_verdict_pipeline

    out = {
        "verdict_num": 3,
        "verdict": "PERFECT BUY",
        "effective_verdict_num": 3,
        "effective_verdict": "PERFECT BUY",
        "tf_m1_dir": "BEAR",
        "tf_m5_dir": "BEAR",
        "bars_since_spike": 12,
        "m1_opp_bars": 4,
        "price_direction_5b": -0.0004,
        "symbol": "Boom 500 Index",
    }
    _gom_finalize_verdict_pipeline(out, "Boom 500 Index")
    vn = int(out.get("verdict_num", 0) or 0)
    assert vn != 3, f"PERFECT should not remain, got {vn} {out.get('verdict')}"


if __name__ == "__main__":
    tests = [
        test_stale_spike_demotes_perfect,
        test_stale_spike_force_wait,
        test_micro_stairs_perfect_to_wait,
        test_price_strong_down_vs_buy,
        test_m1_against_demotes_perfect,
        test_finalize_synthetic_correction_wait,
    ]
    failed = 0
    for t in tests:
        try:
            t()
            print(f"OK {t.__name__}")
        except Exception as e:
            failed += 1
            print(f"FAIL {t.__name__}: {e}")
    if failed:
        sys.exit(1)
    print("All GOM price-reality tests passed.")
