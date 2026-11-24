"""Validation and normalization for candle batches received from MT5."""
from __future__ import annotations

import math
from collections.abc import Mapping, Sequence
from typing import Any

MAX_CANDLES_PER_UPLOAD = 10_000


def normalize_mt5_candles(candles: Any) -> tuple[list[tuple[int, float, float, float, float, float]], dict[str, int]]:
    """Return sorted, unique, geometrically valid OHLCV rows and drop counts.

    Input rows may be mappings with time/open/high/low/close/volume keys or
    positional sequences [time, open, high, low, close, volume?]. For duplicate
    timestamps, the last valid row in the submitted batch wins.
    """
    if not isinstance(candles, Sequence) or isinstance(candles, (str, bytes, bytearray)):
        raise ValueError("candles must be a list of rows")
    if len(candles) > MAX_CANDLES_PER_UPLOAD:
        raise ValueError(f"too many candles (max {MAX_CANDLES_PER_UPLOAD})")

    rows_by_time: dict[int, tuple[int, float, float, float, float, float]] = {}
    invalid = 0
    duplicates = 0

    for row in candles:
        try:
            if isinstance(row, Mapping):
                raw = (
                    row.get("time"), row.get("open"), row.get("high"),
                    row.get("low"), row.get("close"), row.get("volume", 0),
                )
            elif isinstance(row, Sequence) and not isinstance(row, (str, bytes, bytearray)) and len(row) >= 5:
                raw = (row[0], row[1], row[2], row[3], row[4], row[5] if len(row) > 5 else 0)
            else:
                invalid += 1
                continue

            values = [float(value) for value in raw]
            if not all(math.isfinite(value) for value in values):
                invalid += 1
                continue
            timestamp_float, open_, high, low, close, volume = values
            if timestamp_float <= 0 or not timestamp_float.is_integer():
                invalid += 1
                continue
            timestamp = int(timestamp_float)
            if min(open_, high, low, close) <= 0 or volume < 0:
                invalid += 1
                continue
            if high < max(open_, close, low) or low > min(open_, close, high):
                invalid += 1
                continue

            if timestamp in rows_by_time:
                duplicates += 1
            rows_by_time[timestamp] = (timestamp, open_, high, low, close, volume)
        except (TypeError, ValueError, OverflowError):
            invalid += 1

    rows = [rows_by_time[t] for t in sorted(rows_by_time)]
    if not rows:
        raise ValueError("no valid candles after validation")
    return rows, {"invalid_candles_dropped": invalid, "duplicate_candles_dropped": duplicates}
