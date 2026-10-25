"""Tests du prix de marché live et du gate de timing GOM."""
from __future__ import annotations

import os
import sys
import unittest
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gom_live_calculator import apply_live_quote_to_record  # noqa: E402
from gom_pine_calculator import apply_current_market_forecast_gate  # noqa: E402
from gom_verdict_calculator_v2 import GOMVerdictCalculatorV2  # noqa: E402


class VerdictLabelTests(unittest.TestCase):
    def test_all_public_verdict_labels_are_explicit(self):
        calc = GOMVerdictCalculatorV2()
        self.assertEqual(
            [calc.calculate_verdict_text(vn) for vn in (0, 1, 2, 3, -1, -2, -3)],
            [
                "WAIT",
                "BUY SIMPLE",
                "GOOD BUY",
                "PERFECT BUY",
                "SELL SIMPLE",
                "GOOD SELL",
                "PERFECT SELL",
            ],
        )


class LiveQuoteTests(unittest.TestCase):
    def test_fresh_mt5_quote_replaces_candle_price_and_exposes_spread(self):
        record = {"market_price": 101.0, "market_price_source": "m1_candle_close"}
        updated = apply_live_quote_to_record(
            record,
            {
                "price": 100.5,
                "bid": 100.0,
                "ask": 101.0,
                "timestamp": 999.0,
                "source": "mt5_tick_mid",
            },
            now=1000.0,
        )

        self.assertTrue(updated)
        self.assertEqual(record["market_price"], 100.5)
        self.assertEqual(record["market_bid"], 100.0)
        self.assertEqual(record["market_ask"], 101.0)
        self.assertEqual(record["market_price_source"], "mt5_tick_mid")
        self.assertTrue(record["market_price_fresh"])

    def test_stale_quote_does_not_replace_existing_price(self):
        record = {"market_price": 101.0, "market_price_source": "m1_candle_close"}
        updated = apply_live_quote_to_record(
            record,
            {"price": 100.5, "timestamp": 800.0, "source": "mt5_tick_last"},
            now=1000.0,
        )

        self.assertFalse(updated)
        self.assertEqual(record["market_price"], 101.0)
        self.assertEqual(record["market_price_source"], "m1_candle_close")

    def test_unnormalized_weltrade_tick_is_treated_fresh(self):
        record = {"market_price": 101.0, "market_price_source": "m1_candle_close"}
        updated = apply_live_quote_to_record(
            record,
            {
                "price": 37287.69,
                "bid": 37287.0,
                "ask": 37288.0,
                "timestamp": 1.0,
                "source": "mt5_tick_mid_unnormalized",
            },
            now=1_700_000_000.0,
        )

        self.assertTrue(updated)
        self.assertTrue(record["market_price_fresh"])
        self.assertEqual(record["market_price_age_sec"], 0.0)
        self.assertEqual(record["market_price"], 37287.69)


class MarketTimingGateTests(unittest.TestCase):
    def setUp(self):
        now = datetime.now(timezone.utc)
        self.record = {
            "market_price": 100.5,
            "market_price_fresh": True,
            "market_price_time": now.isoformat(),
            "forecast_horizon_minutes": 5,
            "cog_forecast_ready": True,
            "forecast_verdict_num": 2,
        }

    def test_fresh_price_and_aligned_forecast_cap_verdict_magnitude(self):
        verdict, reason = apply_current_market_forecast_gate(self.record, 3)

        self.assertEqual(verdict, 2)
        self.assertEqual(reason, "5m_forecast_magnitude_cap")
        self.assertEqual(self.record["market_timing_status"], "CAPPED_BY_5M_FORECAST")

    def test_opposed_forecast_forces_wait(self):
        self.record["forecast_verdict_num"] = -2

        verdict, reason = apply_current_market_forecast_gate(self.record, 2)

        self.assertEqual(verdict, 0)
        self.assertEqual(reason, "5m_forecast_opposes_reactive_verdict")

    def test_stale_price_forces_wait(self):
        old = datetime.fromtimestamp(1, tz=timezone.utc)
        self.record["market_price_time"] = old.isoformat()

        verdict, reason = apply_current_market_forecast_gate(self.record, 2)

        self.assertEqual(verdict, 0)
        self.assertEqual(reason, "m1_market_price_missing_or_stale")

    def test_unnormalized_source_keeps_good_verdict(self):
        old = datetime.fromtimestamp(1, tz=timezone.utc)
        self.record["market_price_time"] = old.isoformat()
        self.record["market_price_source"] = "mt5_tick_mid_unnormalized"

        verdict, reason = apply_current_market_forecast_gate(self.record, 3)

        self.assertNotEqual(verdict, 0)
        self.assertTrue(self.record["market_price_fresh"])


if __name__ == "__main__":
    unittest.main()
