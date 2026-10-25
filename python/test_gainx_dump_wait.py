#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GainX dump + DOW BEAR must be WAIT, never GOOD BUY."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gom_pine_calculator import (  # noqa: E402
    GOMLPineCalculator,
    apply_correction_gate,
    apply_family_native_impulse,
    apply_mtf_structure_floor,
)


def _rec(**extra):
    rec = {
        "symbol": "GainX 999",
        "tf_m1_dir": "BEAR",
        "tf_m1_dir_live": "BEAR",
        "tf_m5_dir": "BEAR",
        "tf_m15_dir": "BEAR",
        "dow_direction": "BEAR",
        "bos_bear": True,
        "bos_bull": False,
        "price_direction_1b": -0.0010,
        "price_direction_3b": -0.0018,
        "price_direction_5b": -0.0022,
        "m1_momentum": -0.0014,
        "score_buy": 8.0,
        "score_sell": 3.0,
    }
    rec.update(extra)
    return rec


def test_family_dump_kills_buy():
    assert apply_family_native_impulse(_rec(), 2) == 0
    assert apply_family_native_impulse(_rec(), 3) == 0
    assert apply_family_native_impulse(_rec(), 0) == 0


def test_family_one_green_candle_not_enough_if_dow_bear():
    rec = _rec(price_direction_1b=0.0004, price_direction_3b=-0.0010)
    assert apply_family_native_impulse(rec, 0) == 0


def test_correction_dump_is_wait():
    rec = _rec()
    assert apply_correction_gate(rec, 2) == 0


def test_mtf_floor_no_buy_on_dump():
    assert apply_mtf_structure_floor(_rec(), 2) <= 0


def test_enrich_gainx_dump_is_wait():
    pine = GOMLPineCalculator()
    out = pine.enrich_record(
        _rec(
            close=83120.0,
            rsi14=38.0,
            macd_line=-0.3,
            macd_sig=-0.1,
            ema_above_count=1,
            filter_ratio=0.7,
        )
    )
    vn = int(out.get("verdict_num", 0) or 0)
    assert vn <= 0, (out.get("verdict"), out.get("family_impulse_reason"), out.get("structure_uplift"))
    assert "BUY" not in str(out.get("verdict", "")).upper()


if __name__ == "__main__":
    test_family_dump_kills_buy()
    test_family_one_green_candle_not_enough_if_dow_bear()
    test_correction_dump_is_wait()
    test_mtf_floor_no_buy_on_dump()
    test_enrich_gainx_dump_is_wait()
    print("ok")
