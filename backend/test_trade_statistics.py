import unittest
from datetime import datetime, timezone

from backend.trade_statistics import build_strategy_trade_stats


class StrategyTradeStatsTests(unittest.TestCase):
    def test_aggregates_partial_closes_once_by_position_and_entry_source(self):
        now = datetime(2026, 11, 2, 15, tzinfo=timezone.utc)
        rows = [
            {
                "deal_ticket": 101,
                "position_id": 9001,
                "position_complete": False,
                "symbol": "PainX 400",
                "entry_comment": "SMVE SELL MKT @KOLA_SELL",
                "profit": -0.3,
                "open_time": "2026-11-02T14:00:00+00:00",
                "close_time": "2026-11-02T14:01:00+00:00",
            },
            {
                "deal_ticket": 102,
                "position_id": 9001,
                "position_complete": True,
                "symbol": "PainX 400",
                "entry_comment": "SMVE SELL MKT @KOLA_SELL",
                "profit": -0.5,
                "open_time": "2026-11-02T14:00:00+00:00",
                "close_time": "2026-11-02T14:02:00+00:00",
            },
            {
                "deal_ticket": 103,
                "position_id": 9002,
                "position_complete": True,
                "symbol": "PainX 400",
                "entry_comment": "DOW MARKET SELL",
                "profit": 1.2,
                "open_time": "2026-11-02T14:10:00+00:00",
                "close_time": "2026-11-02T14:15:00+00:00",
            },
        ]

        result = build_strategy_trade_stats(rows, now=now)
        by_strategy = {row["strategy"]: row for row in result["groups"]}

        self.assertEqual(by_strategy["KOLA"]["trades"], 1)
        self.assertEqual(by_strategy["KOLA"]["losses"], 1)
        self.assertEqual(by_strategy["KOLA"]["net_profit"], -0.8)
        self.assertEqual(by_strategy["DOW"]["wins"], 1)
        self.assertEqual(by_strategy["DOW"]["profit_factor"], None)

    def test_ignores_positions_that_are_not_fully_closed(self):
        result = build_strategy_trade_stats([
            {
                "position_id": 42,
                "position_complete": False,
                "symbol": "GainX 800",
                "entry_comment": "DOW MARKET BUY",
                "profit": 0.75,
            }
        ])

        self.assertEqual(result["groups"], [])


if __name__ == "__main__":
    unittest.main()
