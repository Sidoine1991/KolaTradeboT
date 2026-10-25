import numpy as np
import pandas as pd

from python.ml.cognition_forecast import (
    _closed_m1_bars,
    _forecast_components,
    forecast_200,
    forecast_short_horizon,
    to_mt5_payload,
)


def _market_data(count=260):
    x = np.arange(count, dtype=float)
    close = 1.1 + x * 0.0002 + np.sin(x / 5.0) * 0.0004
    open_ = np.r_[close[0], close[:-1]]
    return pd.DataFrame(
        {
            "time": pd.date_range("2026-01-01", periods=count, freq="min", tz="UTC"),
            "open": open_,
            "high": np.maximum(open_, close) + 0.0005,
            "low": np.minimum(open_, close) - 0.0005,
            "close": close,
            "volume": np.full(count, 100.0),
        }
    )


def test_forecast_components_combine_gom_price_action_and_patterns():
    signals = _forecast_components(
        {
            "verdict_num": -2,
            "coherence_pct": 80,
            "pa_trend": "UP",
            "pa_in_correction": True,
            "pattern_score_buy": 3,
            "pattern_score_sell": 0,
        }
    )

    assert signals["gom"] < 0
    assert signals["pure_price_action"] == 0.7 * 0.45
    assert signals["chartist_patterns"] > 0


def test_forecast_projects_exact_horizon_with_valid_ohlc_and_scenarios():
    forecast = forecast_200(
        _market_data(),
        "EURUSD",
        horizon=200,
        gom={
            "verdict_num": 2,
            "coherence_pct": 80,
            "pa_trend": "UP",
            "pattern_score_buy": 2.4,
            "pattern_score_sell": 0.2,
        },
    )

    assert forecast.horizon == 200
    for values in (
        forecast.opens,
        forecast.highs,
        forecast.lows,
        forecast.closes,
        forecast.q10,
        forecast.q90,
        forecast.scenario_bull,
        forecast.scenario_bear,
    ):
        assert len(values) == 200
        assert np.isfinite(values).all()
    assert all(
        low <= min(open_, close) <= max(open_, close) <= high
        for open_, high, low, close in zip(
            forecast.opens, forecast.highs, forecast.lows, forecast.closes
        )
    )
    assert forecast.components["pure_price_action"] > 0

    payload = to_mt5_payload(forecast)
    assert payload["cog_path_direction"] == forecast.direction
    assert payload["cog_component_scores"] == forecast.components
    assert payload["cog_bar_seconds"] == 60
    assert len(payload["cog_scenario_bull"]) == 200


def test_component_disagreement_reduces_alignment_and_confidence():
    data = _market_data()
    common = {"verdict_num": 2, "coherence_pct": 75, "pa_trend": "UP"}
    aligned = forecast_200(
        data,
        "EURUSD",
        horizon=50,
        gom={**common, "pattern_score_buy": 4, "pattern_score_sell": 0},
    )
    disagreement = forecast_200(
        data,
        "EURUSD",
        horizon=50,
        gom={**common, "pattern_score_buy": 0, "pattern_score_sell": 4},
    )

    assert aligned.component_alignment == 1.0
    assert disagreement.component_alignment < aligned.component_alignment
    assert disagreement.confidence < aligned.confidence


def test_short_forecast_ignores_the_forming_m1_bar():
    now = pd.Timestamp("2026-10-04T20:57:00Z")
    data = _market_data(60)
    data.loc[data.index[-1], "time"] = now
    data.loc[data.index[-1], ["open", "high", "low", "close"]] = [
        5.0, 10.0, 0.1, 8.0
    ]

    closed = _closed_m1_bars(data, now_utc=now + pd.Timedelta(seconds=20))

    assert len(closed) == len(data) - 1
    assert closed["time"].max() < now
    as_of = now + pd.Timedelta(seconds=20)
    forecast = forecast_short_horizon(data, "EURUSD", now_utc=as_of)
    closed_forecast = forecast_short_horizon(closed, "EURUSD", now_utc=as_of)
    assert forecast == closed_forecast


def test_short_forecast_is_not_circularly_weighted_by_current_gom():
    data = _market_data()
    bullish = forecast_short_horizon(
        data, "EURUSD", gom={"verdict_num": 3, "coherence_pct": 99},
        bc_confidence=100,
    )
    bearish = forecast_short_horizon(
        data, "EURUSD", gom={"verdict_num": -3, "coherence_pct": 99},
        bc_confidence=0,
    )

    assert bullish == bearish
    assert bullish.signals["gom"] == 0.0


def test_forecast_does_not_fabricate_bars_when_market_history_is_insufficient():
    forecast = forecast_200(_market_data(30), "EURUSD", horizon=200)

    assert forecast.horizon == 0
    assert forecast.closes == []
    assert to_mt5_payload(forecast)["candles"] == []
