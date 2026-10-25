"""Regression tests for confirmed classical chart patterns and GOM integration."""

import sys
from pathlib import Path

import numpy as np
import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))

import gom_live_calculator as live  # noqa: E402
from chartist_patterns import (  # noqa: E402
    ChartistOrder,
    _detect_classic_breakout_patterns,
)


def _ohlc(size=30, base=100.0):
    close = np.full(size, base, dtype=float)
    high = close + 0.4
    low = close - 0.4
    return high, low, close


def test_descending_triangle_needs_a_closed_support_break():
    high, low, close = _ohlc()
    high[[6, 14, 22]] = [110.0, 108.0, 106.0]
    low[[9, 17, 24]] = [100.0, 100.1, 100.0]
    close[-2:] = [100.0, 99.5]

    found = _detect_classic_breakout_patterns(
        "EURUSD", high, low, close, 2.0, [6, 14, 22], [9, 17, 24], "now"
    )

    assert any(
        order.pattern == "DESCENDING_TRIANGLE_BREAKOUT"
        and order.direction == "SELL"
        and order.confirmed
        for order in found
    )

    close[-1] = 100.2
    unbroken = _detect_classic_breakout_patterns(
        "EURUSD", high, low, close, 2.0, [6, 14, 22], [9, 17, 24], "now"
    )
    assert not any(order.pattern == "DESCENDING_TRIANGLE_BREAKOUT" for order in unbroken)


def test_head_and_shoulders_requires_neckline_confirmation():
    high, low, close = _ohlc()
    close[:] = 107.5
    high[:] = 107.9
    low[:] = 107.1
    high[[5, 12, 19]] = [110.0, 114.0, 110.2]
    low[6:13] = np.linspace(104.5, 103.8, 7)
    low[13:20] = np.linspace(104.0, 103.5, 7)
    close[-2:] = [103.2, 102.5]
    high[-2:] = [103.6, 102.9]
    low[-2:] = [102.8, 102.4]

    found = _detect_classic_breakout_patterns(
        "EURUSD", high, low, close, 2.0, [5, 12, 19], [], "now"
    )

    assert any(
        order.pattern == "HEAD_AND_SHOULDERS_TOP"
        and order.direction == "SELL"
        and order.confirmed
        and order.sl > order.entry > order.tp
        for order in found
    )


def test_symmetrical_triangle_and_rectangle_wait_for_directional_breakout():
    high, low, close = _ohlc()
    high[[6, 14]] = [112.0, 110.0]
    low[[9, 17]] = [100.0, 102.0]
    close[-2:] = [105.0, 107.0]
    triangle = _detect_classic_breakout_patterns(
        "EURUSD", high, low, close, 2.0, [6, 14], [9, 17], "now"
    )
    assert any(
        order.pattern == "SYMMETRICAL_TRIANGLE_BREAKOUT"
        and order.direction == "BUY"
        and order.confirmed
        for order in triangle
    )

    high, low, close = _ohlc()
    high[[6, 14, 22]] = [110.0, 110.2, 109.9]
    low[[9, 17, 24]] = [100.0, 100.1, 100.2]
    close[-2:] = [105.0, 111.0]
    rectangle = _detect_classic_breakout_patterns(
        "EURUSD", high, low, close, 2.0, [6, 14, 22], [9, 17, 24], "now"
    )
    assert any(
        order.pattern == "RECTANGLE_BREAKOUT"
        and order.direction == "BUY"
        and order.confirmed
        for order in rectangle
    )


def test_bull_flag_requires_impulse_consolidation_and_breakout():
    high, low, close = _ohlc(size=30)
    close[13:24] = np.linspace(100.0, 110.0, 11)
    high[13:24] = close[13:24] + 0.5
    low[13:24] = close[13:24] - 0.5
    close[23:29] = [109.0, 108.5, 108.0, 107.5, 107.0, 106.8]
    high[23:29] = close[23:29] + 0.4
    low[23:29] = close[23:29] - 0.4
    close[-2:] = [107.0, 111.0]
    high[-2:] = [107.4, 111.4]
    low[-2:] = [106.6, 110.6]

    found = _detect_classic_breakout_patterns(
        "EURUSD", high, low, close, 2.0, [], [], "now"
    )

    assert any(
        order.pattern in {"BULL_FLAG_BREAKOUT", "BULL_PENNANT_BREAKOUT"}
        and order.direction == "BUY"
        and order.confirmed
        for order in found
    )


def test_confirmed_structural_patterns_contribute_to_live_gom_scores(monkeypatch):
    calc = live.GOMSignalsLiveCalculator()
    candles = pd.DataFrame({
        "open": np.linspace(100.0, 101.0, 60),
        "high": np.linspace(100.5, 101.5, 60),
        "low": np.linspace(99.5, 100.5, 60),
        "close": np.linspace(100.1, 101.1, 60),
        "volume": np.ones(60),
    })
    calc.get_candles = lambda *args, **kwargs: candles
    monkeypatch.setattr(
        live,
        "detect_all_patterns",
        lambda *args, **kwargs: [
            ChartistOrder(
                symbol="EURUSD",
                pattern="DESCENDING_TRIANGLE_BREAKOUT",
                direction="SELL",
                entry=100.0,
                sl=101.0,
                tp=98.0,
                score=0.8,
                rr=2.0,
                confirmed=True,
                reason="confirmed breakout",
            )
        ],
    )
    record = {"price_direction_5b": 0}

    calc._apply_pattern_confluence("EURUSD", record)

    assert record["pattern_score_sell"] > 0
    assert "DESCENDING_TRIANGLE_BREAKOUT@M1" in record["pattern_bear_hits"]
