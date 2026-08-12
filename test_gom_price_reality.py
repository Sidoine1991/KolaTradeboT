#!/usr/bin/env python3
"""Tests gardes cohérence verdict GOM vs prix M1 / post-spike."""

import os
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(ROOT, "python"))
sys.path.insert(0, ROOT)

from gom_pine_calculator import (
    apply_m1_momentum_to_scores,
    apply_price_reality_gate,
    enrich_m1_metrics,
    verdict_text_from_num,
)


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
    rec = {"symbol": "EURUSD", "tf_m1_dir": "BULL", "bars_since_spike": 21, "m1_opp_bars": 0}
    vn, reason = apply_price_reality_gate(rec, 3)
    assert vn == 0
    assert "20" in reason


def test_stale_spike_synth_degrades_to_simple():
    rec = {"symbol": "GainX 800", "tf_m1_dir": "BULL", "bars_since_spike": 47, "m1_opp_bars": 0}
    vn, reason = apply_price_reality_gate(rec, 3)
    assert vn == 1, f"expected BUY SIMPLE, got {vn} {reason}"
    assert "SIMPLE_synth" in reason


def test_unknown_spike_does_not_force_wait():
    rec = {
        "symbol": "Boom 500 Index",
        "bars_since_spike": -1,
        "tf_m1_dir": "BULL",
        "m1_opp_bars": 0,
        "price_direction_5b": 0.0002,
        "m1_momentum": 0.0002,
    }
    vn, reason = apply_price_reality_gate(rec, 2)
    assert vn == 2, f"expected GOOD to remain, got {vn} {reason}"


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


def test_gainx_price_down_demotes_not_wait():
    rec = {
        "symbol": "GainX 999",
        "tf_m1_dir": "NEUT",
        "bars_since_spike": 2,
        "m1_opp_bars": 0,
        "price_direction_5b": -0.002,
        "price_direction_3b": -0.0015,
    }
    vn, reason = apply_price_reality_gate(rec, 3)
    assert vn == 2, f"expected GOOD BUY, got {vn} {reason}"
    assert "price_down_synth" in reason


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


def test_m1_momentum_boosts_sell_on_downtrend():
    rec = {
        "symbol": "Boom 500 Index",
        "m1_momentum": -0.0012,
        "price_direction_1b": -0.0008,
        "price_direction_3b": -0.0010,
        "price_direction_5b": -0.0012,
    }
    sb, ss = apply_m1_momentum_to_scores(rec, 5.0, 4.0)
    assert ss > 4.0
    assert sb < 5.0


def test_enrich_m1_metrics_live_direction():
    closes = [100.0, 100.1, 100.2, 100.15, 100.05, 99.95]
    opens = [c - 0.02 for c in closes]
    highs = [c + 0.03 for c in closes]
    lows = [c - 0.03 for c in closes]
    rec: dict = {"symbol": "Crash 500 Index", "score_buy": 3.0, "score_sell": 5.0}
    enrich_m1_metrics(rec, closes, opens, highs, lows)
    assert rec.get("tf_m1_dir_live") == "BEAR"
    assert rec.get("price_direction_5b", 0) < 0


def test_m1_gate_adverse_only_not_range():
    """Range 20b élevée sans pullback adverse ne doit pas forcer WAIT."""
    import pandas as pd
    from gom_live_calculator import _attach_correction_cycle

    class FakeCalc:
        def _is_deriv_synthetic(self, symbol):
            return True

        def get_candles(self, symbol, tf, n, allow_deriv=True, broker=None):
            base = 1000.0
            n = 30
            # Prix au plus haut récent → adverse=0 pour BUY, range large
            closes = [base + 20.0] * n
            highs = [c + 2.0 for c in closes]
            lows = [c - 2.0 for c in closes]
            return pd.DataFrame({"close": closes, "high": highs, "low": lows, "open": closes})

    payload = {
        "verdict_num": 3,
        "verdict": "PERFECT BUY",
        "tf_h4_rsi": 50,
        "tf_h1_rsi": 50,
        "tf_d1_rsi": 50,
        "tf_m1_rsi": 50,
        "tf_m5_rsi": 50,
        "tf_m15_rsi": 50,
    }
    _attach_correction_cycle(payload, "PainX 1200", FakeCalc())
    assert payload.get("verdict_num") == 3, f"expected PERFECT kept, got {payload.get('verdict')}"
    assert payload.get("gate") != "m1_correction"


def test_poller_metadata_preserved_on_fast_path():
    os.environ.setdefault("GOM_USE_CORRECTION_WAIT_OVERLAY", "0")
    os.environ.setdefault("GOM_USE_PREDICTIVE_BLEND", "0")

    from ai_server import GomVerdictPayload, _gom_verdict_record_from_payload

    payload = GomVerdictPayload(
        symbol="Boom 500 Index",
        verdict="WAIT",
        verdict_num=0,
        score_buy=7.0,
        score_sell=3.0,
        source="mt5_live",
        gate="m1_correction",
        price_reality_reason="bars_since_spike=21>20",
        harmonized_m1=True,
        bars_since_spike=21,
        m1_opp_bars=4,
        price_direction_5b=-0.0004,
    )
    _sym, record = _gom_verdict_record_from_payload(payload, enrich_mt5=False)
    assert record.get("gate") == "m1_correction", record
    assert record.get("harmonized_m1") is True
    assert record.get("bars_since_spike") == 21
    assert record.get("price_direction_5b") == -0.0004


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
        test_unknown_spike_does_not_force_wait,
        test_micro_stairs_perfect_to_wait,
        test_price_strong_down_vs_buy,
        test_gainx_price_down_demotes_not_wait,
        test_m1_against_demotes_perfect,
        test_m1_momentum_boosts_sell_on_downtrend,
        test_enrich_m1_metrics_live_direction,
        test_m1_gate_adverse_only_not_range,
        test_poller_metadata_preserved_on_fast_path,
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
