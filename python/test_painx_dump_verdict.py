#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""PainX dump live must not stay WAIT (GOM = SELL/GOOD/PERFECT)."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gom_pine_calculator import (  # noqa: E402
    GOMLPineCalculator,
    apply_family_native_impulse,
    apply_mtf_structure_floor,
    apply_regime_forecast_to_record,
    m1_m5_trend_sign,
)


def _dump_record(**extra):
    rec = {
        "symbol": "PainX 400",
        "tf_m1_dir": "BULL",
        "tf_m1_dir_live": "BULL",
        "tf_m5_dir": "BULL",
        "tf_m15_dir": "BEAR",
        "tf_h1_dir": "BEAR",
        "tf_h4_dir": "BEAR",
        "tf_d1_dir": "BEAR",
        "dow_direction": "BEAR",
        "bos_bear": True,
        "bos_bull": False,
        "price_direction_1b": -0.0012,
        "price_direction_3b": -0.0020,
        "price_direction_5b": -0.0024,
        "m1_momentum": -0.0015,
        "score_buy": 4.0,
        "score_sell": 9.0,
        "spike_tradable": False,
        "spike_prob": 0.28,
    }
    rec.update(extra)
    return rec


def test_dump_overrides_stale_m1_bull_labels():
    rec = _dump_record()
    assert m1_m5_trend_sign(rec) == -1
    vn = apply_family_native_impulse(rec, 0)
    assert vn <= -2, vn


def test_dump_family_kills_buy_and_sells():
    rec = _dump_record()
    assert apply_family_native_impulse(rec, 2) == 0
    rec2 = _dump_record()
    assert apply_family_native_impulse(rec2, 0) <= -2


def test_mtf_floor_dump():
    rec = _dump_record()
    assert apply_mtf_structure_floor(rec, 0) <= -2


def test_regime_then_family_dump():
    rec = _dump_record(verdict_num=0, verdict="WAIT")
    apply_regime_forecast_to_record(rec)
    vn = apply_family_native_impulse(rec, int(rec.get("verdict_num", 0) or 0))
    assert vn <= -2, rec


def test_enrich_painx_dump_is_sell():
    pine = GOMLPineCalculator()
    rec = _dump_record(
        close=89360.0,
        rsi14=32.0,
        macd_line=-0.4,
        macd_sig=-0.1,
        ema_above_count=1,
        filter_ratio=0.7,
        in_ote=True,
    )
    out = pine.enrich_record(rec)
    vn = int(out.get("verdict_num", 0) or 0)
    assert vn <= -2, (out.get("verdict"), out.get("family_impulse_reason"), out.get("structure_uplift"))
    assert "BUY" not in str(out.get("verdict", "")).upper()


def test_painx_bounce_is_wait_not_buy():
    from gom_pine_calculator import apply_m1m5_flow_authority

    rec = _dump_record(
        price_direction_1b=0.0004,
        price_direction_3b=0.0006,
        price_direction_5b=-0.0010,
        tf_m1_dir="BULL",
        tf_m1_dir_live="BULL",
    )
    assert apply_family_native_impulse(rec, 0) == 0
    rec2 = _dump_record(
        price_direction_1b=0.0004,
        price_direction_3b=0.0006,
        price_direction_5b=0.0008,
        tf_m1_dir="BULL",
        tf_m1_dir_live="BULL",
        tf_m5_dir="BULL",
    )
    vn = apply_m1m5_flow_authority(rec2, 0)
    assert vn == 0, vn
    vn2 = apply_family_native_impulse(rec2, vn)
    assert vn2 == 0, vn2


if __name__ == "__main__":
    test_dump_overrides_stale_m1_bull_labels()
    test_dump_family_kills_buy_and_sells()
    test_mtf_floor_dump()
    test_regime_then_family_dump()
    test_enrich_painx_dump_is_sell()
    test_painx_bounce_is_wait_not_buy()
    print("ok")
