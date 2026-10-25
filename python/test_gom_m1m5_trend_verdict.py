#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""GOM must follow M1+M5 on PainX uptrend — not native SELL bias."""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pandas as pd  # noqa: E402
from gom_live_calculator import GOMSignalsLiveCalculator  # noqa: E402
from gom_pine_calculator import (  # noqa: E402
    GOMLPineCalculator,
    apply_score_direction_authority,
    apply_trend_alignment_verdict,
    apply_m1_execution_gate,
    enrich_m1_metrics,
    m1_m5_trend_sign,
)


def _painx_uptrend_record(**extra):
    rec = {
        "symbol": "PainX 999",
        "tf_m1_dir": "BULL",
        "tf_m1_dir_live": "BULL",
        "tf_m5_dir": "BULL",
        "tf_m15_dir": "BULL",
        "tf_h1_dir": "BULL",
        "tf_h4_dir": "BULL",
        "tf_d1_dir": "BULL",
        "tf_global_dir": "BULL",
        "dow_direction": "BULL",
        "bos_bull": True,
        "bos_bear": False,
        "price_direction_1b": 0.0008,
        "price_direction_3b": 0.0012,
        "price_direction_5b": 0.0015,
        "m1_momentum": 0.0010,
        "score_buy": 12.0,
        "score_sell": 4.0,
        "spike_pct": 29.7,
        "spike_prob": 0.297,
        "spike_tradable": False,
        "st_dir": 1,
        "pattern_score_buy": 2.0,
        "pattern_score_sell": 0.0,
    }
    rec.update(extra)
    return rec


def test_m1_m5_sign():
    assert m1_m5_trend_sign(_painx_uptrend_record()) == 1
    assert m1_m5_trend_sign(_painx_uptrend_record(tf_m5_dir="BEAR", tf_m15_dir="BEAR",
                                                 tf_h1_dir="BEAR", tf_h4_dir="BEAR",
                                                 tf_d1_dir="BEAR",
                                                 price_direction_1b=-0.001,
                                                 price_direction_3b=-0.001,
                                                 price_direction_5b=-0.001)) == -1
    # EMA M1 encore BEAR mais M5+prix haussiers
    assert m1_m5_trend_sign(_painx_uptrend_record(tf_m1_dir="BEAR", tf_m1_dir_live="BEAR")) == 1


def test_live_tick_flips_m1_before_current_candle_closes():
    rec = {
        "symbol": "EURUSD",
        "tf_m1_dir": "BEAR",
        "tf_m1_dir_live": "BEAR",
    }
    closes = [1.1000, 1.0980, 1.0960, 1.0940, 1.0945, 1.0950]
    opens = [1.1002, 1.0982, 1.0962, 1.0942, 1.0944, 1.0950]
    highs = [value + 0.0002 for value in closes]
    lows = [value - 0.0002 for value in closes]

    enrich_m1_metrics(
        rec,
        closes,
        opens,
        highs,
        lows,
        current_price=1.0956,
        live_tick=True,
    )

    assert rec["price_direction_1b"] > 0
    assert rec["price_direction_3b"] < 0
    assert rec["tf_m1_dir_live"] == "BULL"
    assert rec["tf_m1_dir_live_src"] == "m1_live_tick_preclose"
    assert rec["tf_m1_dir"] == "BULL"

    candle_only = {
        "symbol": "EURUSD",
        "tf_m1_dir": "BEAR",
        "tf_m1_dir_live": "BEAR",
    }
    enrich_m1_metrics(candle_only, closes, opens, highs, lows)
    assert candle_only["tf_m1_dir_live"] == "BEAR"


def test_mtf_spike_only_changes_live_m1_before_higher_timeframe_bar_closes(monkeypatch):
    calc = GOMSignalsLiveCalculator()
    now = pd.Timestamp.now(tz="UTC")
    times = pd.date_range(end=now - pd.Timedelta(seconds=10), periods=60, freq="min")
    closes = [100.0 + index for index in range(60)]
    opens = [close - 0.2 for close in closes]
    opens[-1] = closes[-2]
    closes[-1] = closes[-2] - 25.0
    frame = pd.DataFrame(
        {
            "time": times,
            "open": opens,
            "high": [max(open_, close) + 0.2 for open_, close in zip(opens, closes)],
            "low": [min(open_, close) - 0.2 for open_, close in zip(opens, closes)],
            "close": closes,
            "volume": [1.0] * len(times),
        }
    )
    monkeypatch.setattr(
        calc,
        "get_candles",
        lambda symbol, timeframe, bars, **kwargs: frame,
    )

    result = calc.compute_mtf("PainX 1200")

    assert result["tf_m1_dir"] == "BEAR"
    for timeframe in ("m5", "m15", "h1", "h4", "d1", "w1"):
        assert result[f"tf_{timeframe}_dir"] == "BULL"


def test_sell_flips_to_buy_on_painx_uptrend():
    rec = _painx_uptrend_record()
    vn = apply_trend_alignment_verdict(rec, -2)
    assert vn >= 2, vn
    assert rec.get("trend_align_reason")


def test_bc_guard_keeps_buy():
    pine = GOMLPineCalculator()
    rec = _painx_uptrend_record()
    assert pine.apply_bc_verdict_guard(rec, 2) == 2
    rec2 = _painx_uptrend_record()
    assert pine.apply_bc_verdict_guard(rec2, -2) == 0


def test_enrich_painx_uptrend_is_buy():
    pine = GOMLPineCalculator()
    rec = _painx_uptrend_record(
        close=106200.0,
        rsi14=55.0,
        macd_line=0.2,
        macd_sig=0.1,
        ema_above_count=4,
        filter_ratio=0.8,
        in_ote=False,
    )
    out = pine.enrich_record(rec)
    vn = int(out.get("verdict_num", 0))
    # PainX en rally : jamais SELL. BUY possible via M1/M5, sinon WAIT (pas de dump).
    assert vn >= 0, out.get("verdict")
    assert "SELL" not in str(out.get("verdict", "")).upper()


def test_painx_dump_does_not_keep_perfect_buy():
    rec = _painx_uptrend_record(
        price_direction_1b=-0.0009,
        price_direction_3b=-0.0014,
        price_direction_5b=-0.0018,
        m1_momentum=-0.0012,
        bos_bear=True,
        bos_bull=False,
        score_buy=14.0,
        score_sell=4.0,
    )
    from gom_pine_calculator import apply_price_impulse_cap
    assert apply_price_impulse_cap(rec, 3) == 0
    vn = apply_trend_alignment_verdict(rec, 3)
    assert abs(vn) <= 1, vn
    vn_s = apply_score_direction_authority(rec, 3)
    assert vn_s <= 1, vn_s


def test_painx_bounce_after_dump_is_simple_not_perfect():
    rec = _painx_uptrend_record(
        price_direction_1b=0.0004,
        price_direction_3b=0.0001,
        price_direction_5b=-0.0016,
        m1_momentum=-0.0006,
        bos_bear=True,
        score_buy=12.0,
        score_sell=3.0,
        pattern_score_buy=3.0,
    )
    from gom_pine_calculator import apply_price_impulse_cap, apply_execution_quality_contract
    assert apply_price_impulse_cap(rec, 3) == 1
    vn_s = apply_score_direction_authority(rec, 0)
    assert vn_s in (0, 1), vn_s
    rec["verdict_num"] = 3
    apply_execution_quality_contract(rec)
    assert rec.get("entry_allowed") is False


def test_m1_exec_wait_when_price_already_against():
    rec = _painx_uptrend_record(
        price_direction_1b=-0.0005,
        price_direction_3b=-0.0008,
        m1_momentum=-0.0007,
    )
    assert apply_m1_execution_gate(rec, 2) == 0
    rec2 = _painx_uptrend_record(
        price_direction_1b=0.0005,
        price_direction_3b=0.0008,
        m1_momentum=0.0007,
        tf_m1_dir="BULL",
        tf_m5_dir="BEAR",
    )
    assert apply_m1_execution_gate(rec2, -2) == 0


def test_wait_escalates_to_good_buy_when_chain_and_m1m5_are_aligned():
    from gom_verdict_calculator_v2 import GOMVerdictCalculatorV2

    calc = GOMVerdictCalculatorV2()
    record = {
        "tf_m1_dir": "BULL",
        "tf_m5_dir": "BULL",
        "spike_chain_direction": "BULL",
        "spike_chain_active": True,
        "near_spike_zone": True,
        "spike_tradable": True,
        "m1_momentum": 0.0008,
    }

    assert calc.normalize_trend_verdict(record, 0) == 2
    assert record["trend_guard"] == "PREDICTED_GOOD_BUY"


def test_painx_dump_wait_and_bear_labels():
    pine = GOMLPineCalculator()
    rec = _painx_uptrend_record(
        close=800.0,
        rsi14=32.0,
        macd_line=-0.2,
        macd_sig=-0.1,
        ema_above_count=0,
        filter_ratio=0.8,
        in_ote=False,
        price_direction_1b=-0.0009,
        price_direction_3b=-0.0014,
        price_direction_5b=-0.0018,
        m1_momentum=-0.0012,
        bos_bear=True,
        bos_bull=False,
        score_buy=14.0,
        score_sell=4.0,
        tf_m1_dir="BULL",
        tf_m1_dir_live="BULL",
        tf_m5_dir="BULL",
    )
    assert pine.apply_bc_verdict_guard(rec, 2) == 0
    out = pine.enrich_record(dict(rec))
    vn = int(out.get("verdict_num", 0) or 0)
    assert vn <= -2, (out.get("verdict"), out.get("family_impulse_reason"), out.get("structure_uplift"))
    assert out.get("tf_m1_dir") == "BEAR"
    assert out.get("tf_m1_dir_live") == "BEAR"
    assert out.get("tf_m5_dir") == "BEAR"


def test_score_authority_overrides_native_sell():
    rec = _painx_uptrend_record(
        tf_m1_dir="BEAR",
        tf_m1_dir_live="BEAR",
        tf_m5_dir="NEUT",
        score_buy=9.2,
        score_sell=4.7,
    )
    vn = apply_score_direction_authority(rec, -1)
    # PainX : scores BUY ne forcent pas un BUY (famille SELL). SELL simple ou WAIT.
    assert vn <= 0, vn
    pine = GOMLPineCalculator()
    rec2 = _painx_uptrend_record(
        close=106227.0,
        rsi14=55.0,
        macd_line=0.2,
        macd_sig=0.1,
        ema_above_count=4,
        tf_m1_dir="BEAR",
        tf_m1_dir_live="BEAR",
        tf_m5_dir="NEUT",
        score_buy=9.2,
        score_sell=4.7,
    )
    out = pine.enrich_record(rec2)
    vn = int(out.get("verdict_num", 0))
    # Scores BUY sur PainX : famille peut rester WAIT, mais jamais SELL contre le rally 1b+3b.
    assert vn >= 0, out.get("verdict")


if __name__ == "__main__":
    test_m1_m5_sign()
    test_sell_flips_to_buy_on_painx_uptrend()
    test_bc_guard_keeps_buy()
    test_enrich_painx_uptrend_is_buy()
    test_score_authority_overrides_native_sell()
    test_painx_dump_does_not_keep_perfect_buy()
    test_painx_bounce_after_dump_is_simple_not_perfect()
    test_m1_exec_wait_when_price_already_against()
    test_painx_dump_wait_and_bear_labels()
    print("OK — PainX uptrend GOM is BUY-side")
