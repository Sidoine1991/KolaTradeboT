"""
Unit tests for XAUUSD monitoring system.

pytest tests/test_xauusd_monitor.py -v
"""

import pytest
import asyncio
import json
from datetime import datetime
from pathlib import Path
import sys

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / "python"))

from unified_xauusd_monitor import XAUUSDMonitor


class TestXAUUSDMonitor:
    """Test XAUUSD monitor functionality."""

    @pytest.fixture
    async def monitor(self):
        """Create monitor instance."""
        async with XAUUSDMonitor(phone="+test") as m:
            yield m

    @pytest.mark.asyncio
    async def test_monitor_initialization(self):
        """Test monitor initializes correctly."""
        async with XAUUSDMonitor(phone="+1234567890") as monitor:
            assert monitor.phone == "+1234567890"
            assert monitor.interval == 1200
            assert monitor.symbol == "OR"
            assert monitor.tv_symbol == "OANDA:XAUUSD"

    def test_format_numbers(self):
        """Test number formatting helper."""
        async def run_test():
            async with XAUUSDMonitor() as monitor:
                # Build a sample message to test fmt function
                tv_data = {"quote": {}, "indicators": {}, "gom": {}}
                ai_data = {
                    "bias": {"data": {"direction": "NEUTRAL", "confidence": 0}},
                    "pending_order": {},
                    "tradingagents_report": {},
                    "gom": {}
                }
                msg = monitor.build_whatsapp_message(tv_data, ai_data)

                # Should contain message header
                assert "XAUUSD" in msg
                assert "Suivi 20min" in msg
                assert "Décision:" in msg

        asyncio.run(run_test())

    def test_message_structure(self):
        """Test message has all required sections."""
        async def run_test():
            async with XAUUSDMonitor() as monitor:
                tv_data = {
                    "quote": {"price": 2456.78},
                    "indicators": {
                        "VWAP": 2456.50,
                        "BB_Upper": 2467.50,
                        "BB_Mid": 2451.00,
                        "BB_Lower": 2445.20,
                        "SuperTrend": 2448.30,
                        "ST_Direction": "UP"
                    },
                    "gom": {
                        "verdict": "BUY",
                        "score_buy": 7.2,
                        "score_sell": 2.1,
                        "spike_pct": 65,
                        "rsi": 72
                    }
                }
                ai_data = {
                    "bias": {
                        "data": {
                            "direction": "BULLISH",
                            "confidence": 0.85,
                            "age_hours": 2.5
                        }
                    },
                    "pending_order": {
                        "ok": True,
                        "order": {
                            "action": "BUY",
                            "entry_price": 2455.00,
                            "stop_loss": 2440.00,
                            "take_profit": 2470.00,
                            "status": "open"
                        }
                    },
                    "tradingagents_report": {
                        "ok": True,
                        "direction": "BUY",
                        "confidence": 0.82,
                        "age_minutes": 5,
                        "expires_in_minutes": 55
                    },
                    "gom": {}
                }

                msg = monitor.build_whatsapp_message(tv_data, ai_data)

                # Check all sections
                assert "Prix live" in msg
                assert "VWAP" in msg
                assert "Bollinger" in msg or "BB" in msg
                assert "Supertrend" in msg
                assert "Verdict GOM" in msg
                assert "BUY" in msg
                assert "Biais session" in msg
                assert "Ordre EA" in msg
                assert "TradingAgents" in msg
                assert "Décision:" in msg

        asyncio.run(run_test())

    def test_confluence_decision(self):
        """Test confluence decision logic."""
        async def run_test():
            async with XAUUSDMonitor() as monitor:
                # Both BUY
                dec = monitor._get_confluence_decision("BUY", "BULLISH", "BUY")
                assert "confluence" in dec.lower() or "BUY" in dec

                # Conflicting signals
                dec = monitor._get_confluence_decision("BUY", "BEARISH", "SELL")
                assert "attendre" in dec.lower() or "conflicting" in dec.lower()

                # Neutral/WAIT
                dec = monitor._get_confluence_decision("WAIT", "NEUTRAL", "NEUTRAL")
                assert "attendre" in dec.lower() or "clarification" in dec.lower()

        asyncio.run(run_test())

    def test_none_handling(self):
        """Test handling of None/missing data."""
        async def run_test():
            async with XAUUSDMonitor() as monitor:
                # All None
                tv_data = {"quote": None, "indicators": None, "gom": None}
                ai_data = {
                    "bias": None,
                    "pending_order": None,
                    "tradingagents_report": None,
                    "gom": None
                }

                # Should not raise exception
                msg = monitor.build_whatsapp_message(tv_data, ai_data)
                assert isinstance(msg, str)
                assert len(msg) > 0
                assert "XAUUSD" in msg

        asyncio.run(run_test())


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
