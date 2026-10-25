"""Regression tests for live-price freshness and 5m spike confirmation."""

import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pandas as pd


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "python"))

from gom_live_calculator import df_is_current_price_fresh  # noqa: E402
from gom_pine_calculator import (  # noqa: E402
    apply_current_market_forecast_gate,
    apply_execution_quality_contract,
    blend_reactive_forecast_verdict,
    forecast_display_signal_num,
    m1_scalp_structure_confirmed,
    verdict_text_from_num,
)


def _record(**overrides):
    record = {
        "market_price": 1.25,
        "market_price_fresh": True,
        "market_price_time": datetime.now(timezone.utc).isoformat(),
        "forecast_horizon_minutes": 5,
        "cog_forecast_ready": True,
        "forecast_verdict_num": 2,
    }
    record.update(overrides)
    return record


def test_current_price_requires_timestamped_recent_m1_data():
    now = datetime.now(timezone.utc)
    fresh = pd.DataFrame(
        {"close": [1.0]},
        index=pd.DatetimeIndex(
            [(now - timedelta(seconds=60)).replace(tzinfo=None)], name="time"
        ),
    )
    stale = pd.DataFrame(
        {"close": [1.0]},
        index=pd.DatetimeIndex(
            [(now - timedelta(seconds=180)).replace(tzinfo=None)], name="time"
        ),
    )

    assert df_is_current_price_fresh(fresh)
    assert not df_is_current_price_fresh(stale)
    assert not df_is_current_price_fresh(pd.DataFrame({"close": [1.0]}))


def test_five_minute_forecast_confirms_or_caps_but_never_promotes():
    record = _record(forecast_verdict_num=2)

    assert verdict_text_from_num(1) == "BUY SIMPLE"
    assert verdict_text_from_num(-1) == "SELL SIMPLE"
    assert apply_current_market_forecast_gate(record, 3) == (
        2,
        "5m_forecast_magnitude_cap",
    )
    assert apply_current_market_forecast_gate(
        _record(
            forecast_verdict_num=3,
            tf_m1_dir_live="BULL",
            price_direction_1b=0.0002,
            price_direction_3b=0.0004,
        ),
        1,
    ) == (
        1,
        "5m_forecast_confirms",
    )
    assert blend_reactive_forecast_verdict(2, 3) == (2, "GOOD BUY")
    assert blend_reactive_forecast_verdict(0, 3) == (0, "WAIT")


def test_directional_forecast_is_display_only_when_reactive_gom_is_wait():
    assert forecast_display_signal_num(
        0, 3, market_price_fresh=True, forecast_ready=True, horizon_minutes=5
    ) == 1
    assert forecast_display_signal_num(
        0, -2, market_price_fresh=True, forecast_ready=True, horizon_minutes=5
    ) == -1
    assert forecast_display_signal_num(
        2, -2, market_price_fresh=True, forecast_ready=True, horizon_minutes=5
    ) == 0
    assert forecast_display_signal_num(
        0, 2, market_price_fresh=False, forecast_ready=True, horizon_minutes=5
    ) == 0
    assert forecast_display_signal_num(
        0, 2, market_price_fresh=True, forecast_ready=False, horizon_minutes=5
    ) == 0
    assert forecast_display_signal_num(
        0, 2, market_price_fresh=True, forecast_ready=True, horizon_minutes=15
    ) == 0
    assert forecast_display_signal_num(
        0, "invalid", market_price_fresh=True, forecast_ready=True, horizon_minutes=5
    ) == 0


def test_opposing_or_unconfirmed_five_minute_forecast_forces_wait():
    assert apply_current_market_forecast_gate(
        _record(forecast_verdict_num=-2), 2
    ) == (0, "5m_forecast_opposes_reactive_verdict")
    assert apply_current_market_forecast_gate(
        _record(forecast_verdict_num=0), 2
    ) == (2, "5m_forecast_unconfirmed")
    assert apply_current_market_forecast_gate(
        _record(forecast_horizon_minutes=15), 2
    ) == (2, "5m_forecast_unavailable")


def test_fresh_confirmed_m1_structure_allows_simple_without_5m_forecast():
    record = _record(
        forecast_horizon_minutes=0,
        cog_forecast_ready=False,
        tf_m1_dir_live="BULL",
        price_direction_1b=0.0002,
        price_direction_3b=0.0004,
        verdict_num=1,
    )

    assert m1_scalp_structure_confirmed(record, 1)
    assert apply_current_market_forecast_gate(record, 1) == (
        1,
        "5m_forecast_unavailable",
    )
    assert record["m1_scalp_simple_allowed"] is True

    apply_execution_quality_contract(record)
    assert record["entry_allowed"] is True


def test_m1_scalp_waits_when_price_flow_or_strong_forecast_disagrees():
    no_structure = _record(
        tf_m1_dir_live="BULL",
        price_direction_1b=0.0002,
        price_direction_3b=-0.0004,
        forecast_horizon_minutes=0,
        cog_forecast_ready=False,
    )
    assert apply_current_market_forecast_gate(no_structure, 1) == (
        0,
        "m1_scalp_structure_unconfirmed",
    )
    assert no_structure["m1_scalp_simple_allowed"] is False
    no_structure["verdict_num"] = 1
    apply_execution_quality_contract(no_structure)
    assert no_structure["entry_allowed"] is False

    strong_opposition = _record(
        tf_m1_dir_live="BULL",
        price_direction_1b=0.0002,
        price_direction_3b=0.0004,
        forecast_verdict_num=-2,
    )
    assert apply_current_market_forecast_gate(strong_opposition, 2) == (
        0,
        "5m_forecast_opposes_reactive_verdict",
    )


def test_weak_opposing_forecast_caps_to_simple_only_with_m1_structure():
    confirmed = _record(
        tf_m1_dir_live="BULL",
        price_direction_1b=0.0002,
        price_direction_3b=0.0004,
        forecast_verdict_num=-1,
    )
    assert apply_current_market_forecast_gate(confirmed, 3) == (
        1,
        "weak_opposing_5m_m1_structure",
    )
    assert confirmed["m1_scalp_simple_allowed"] is True

    unconfirmed = _record(
        tf_m1_dir_live="BULL",
        price_direction_1b=0.0002,
        price_direction_3b=-0.0004,
        forecast_verdict_num=-1,
    )
    assert apply_current_market_forecast_gate(unconfirmed, 3) == (
        0,
        "5m_forecast_opposes_reactive_verdict",
    )

    assert blend_reactive_forecast_verdict(
        3, -1, record=confirmed
    ) == (1, "BUY SIMPLE")
    assert blend_reactive_forecast_verdict(
        3, -2, record=confirmed
    ) == (0, "WAIT")


def test_weak_opposing_forecast_only_allows_native_spike_simple_with_d1_h4():
    record = _record(
        symbol="GainX 999",
        forecast_verdict_num=-1,
        tf_d1_dir="BULL",
        tf_h4_dir="BULL",
        spike_tradable=True,
    )

    assert apply_current_market_forecast_gate(record, 2) == (
        1,
        "weak_opposing_5m_with_native_spike_htf",
    )
    assert record["spike_htf_simple_allowed"] is True
    assert blend_reactive_forecast_verdict(2, -1, record=record) == (
        1,
        "BUY SIMPLE",
    )


def test_weak_forecast_spike_simple_fails_closed_without_htf_or_spike_proof():
    missing_htf = _record(
        symbol="GainX 999",
        forecast_verdict_num=-1,
        tf_d1_dir="BULL",
        tf_h4_dir="NEUT",
        spike_tradable=True,
    )
    missing_spike = _record(
        symbol="GainX 999",
        forecast_verdict_num=-1,
        tf_d1_dir="BULL",
        tf_h4_dir="BULL",
        spike_tradable=False,
    )
    strong_conflict = _record(
        symbol="GainX 999",
        forecast_verdict_num=-3,
        tf_d1_dir="BULL",
        tf_h4_dir="BULL",
        spike_tradable=True,
    )

    for record in (missing_htf, missing_spike, strong_conflict):
        assert apply_current_market_forecast_gate(record, 2) == (
            0,
            "5m_forecast_opposes_reactive_verdict",
        )
        assert record.get("spike_htf_simple_allowed") is not True


def test_weak_opposing_forecast_spike_simple_is_native_direction_only():
    record = _record(
        symbol="PainX 999",
        forecast_verdict_num=-1,
        tf_d1_dir="BEAR",
        tf_h4_dir="BEAR",
        spike_tradable=True,
    )

    assert apply_current_market_forecast_gate(record, 2) == (
        0,
        "5m_forecast_opposes_reactive_verdict",
    )

    native_sell = _record(
        symbol="PainX 999",
        forecast_verdict_num=1,
        tf_d1_dir="BEAR",
        tf_h4_dir="BEAR",
        spike_tradable=True,
    )
    assert apply_current_market_forecast_gate(native_sell, -2) == (
        -1,
        "weak_opposing_5m_with_native_spike_htf",
    )


def test_stale_price_or_timestamp_cannot_publish_directional_verdict():
    stale_time = (datetime.now(timezone.utc) - timedelta(seconds=120)).isoformat()
    assert apply_current_market_forecast_gate(
        _record(market_price_time=stale_time), 3
    ) == (0, "m1_market_price_missing_or_stale")
    assert apply_current_market_forecast_gate(
        _record(market_price_time=""), 3
    ) == (0, "m1_market_price_missing_or_stale")
    assert apply_current_market_forecast_gate(
        _record(market_price_fresh=False), 3
    ) == (0, "m1_market_price_missing_or_stale")


def test_dashboard_uses_canonical_signed_verdict_numbers():
    source = (ROOT / "dashboard" / "gom_dashboard.html").read_text(encoding="utf-8")
    for label in (
        "WAIT",
        "BUY SIMPLE",
        "GOOD BUY",
        "PERFECT BUY",
        "SELL SIMPLE",
        "GOOD SELL",
        "PERFECT SELL",
    ):
        assert label in source
    assert "v.verdict_num in [1, 2]" not in source
    assert "Prix marché:" in source
    assert "Forecast 5 min:" in source
    assert "v.signal_verdict_num" in source
    assert "EXÉCUTION BLOQUÉE" in source
    assert "signal_is_prediction_only" in source
    assert "lastVerdictsRenderKey" in source


def test_mt5_upload_supplies_utc_bar_times():
    uploader = (ROOT / "mt5" / "modules" / "MT5_Candles_Uploader.mqh").read_text(
        encoding="utf-8"
    )
    server = (ROOT / "ai_server.py").read_text(encoding="utf-8")

    assert "time_utc" in uploader
    assert "serverUtcOffset" not in uploader
    assert 'IntegerToString((long)rates[i].time) + ",";' in uploader
    assert "c.time_utc if c.time_utc is not None else c.time" in server
    assert "utc=True" in server
