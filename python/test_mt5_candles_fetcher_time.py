#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Regression checks for validating and applying MT5 broker clock offsets."""

import sys
from pathlib import Path

import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import mt5_candles_fetcher as fetcher  # noqa: E402


def test_calibrates_positive_broker_offset_only_from_fresh_tick():
    now = 1_800_000_000.0
    offset = fetcher._calibrate_server_utc_offset(now + 10_800 - 24, "test-positive", now)

    assert offset == 10_800
    assert now - ((now + 10_800 - 24) - offset) == 24


def test_calibrates_zero_offset_from_fresh_utc_tick():
    now = 1_800_000_000.0

    offset = fetcher._calibrate_server_utc_offset(now - 12, "test-utc", now)

    assert offset == 0


def test_does_not_infer_offset_from_stale_future_tick():
    now = 1_800_000_000.0

    offset = fetcher._calibrate_server_utc_offset(
        now + 10_800 - 600, "test-stale", now
    )

    assert offset is None


def test_cached_offset_corrects_timestamps_but_preserves_actual_staleness():
    now = 1_800_000_000.0
    broker = "test-cached-stale"
    fetcher._server_utc_offsets.pop(broker, None)
    fetcher._calibrate_server_utc_offset(now + 10_800 - 10, broker, now)

    stale_tick = now + 10_800 - 600
    offset = fetcher._calibrate_server_utc_offset(stale_tick, broker, now)

    assert offset == 10_800
    assert now - (stale_tick - offset) == 600


def test_rate_timestamps_are_shifted_to_utc_after_validated_calibration():
    frame = pd.DataFrame({"time": [1_800_000_000]})

    result = fetcher._mt5_rates_to_utc(frame, 10_800)

    assert result["time"].iloc[0] == pd.Timestamp("2027-01-15 05:00:00")
