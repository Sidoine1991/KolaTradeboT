#!/usr/bin/env python3
"""
TV Snapshot Poller — Captures TradingView price + indicators + GOM levels
Writes to data/tv_snapshot.json for MT5 consumption
"""

import json
import time
import sys
import os
from datetime import datetime
from pathlib import Path

# Try to import MCP (if available)
try:
    from mcp_client import MCPClient
    HAS_MCP = True
except ImportError:
    HAS_MCP = False
    print("[TV-Poller] ⚠️  MCP not available — using fallback mode")


class TVSnapshotPoller:
    def __init__(self, symbol="Boom 500 Index", interval=5):
        self.symbol = symbol
        self.interval = interval
        self.data_dir = Path("data")
        self.output_file = self.data_dir / "tv_snapshot.json"

        if not self.data_dir.exists():
            self.data_dir.mkdir(parents=True, exist_ok=True)

        self.last_snapshot = {}
        self.mcp = MCPClient() if HAS_MCP else None

    def fetch_tv_data(self):
        """Fetch price + indicators from TradingView"""

        if self.mcp:
            try:
                # Get quote data
                quote = self.mcp.quote_get(self.symbol)

                # Get study values (RSI, Stochastic, etc.)
                study_values = self.mcp.data_get_study_values()

                # Get GOM levels (Order Blocks, FVG)
                gom_lines = self.mcp.data_get_pine_lines(study_filter="GOM")
                gom_labels = self.mcp.data_get_pine_labels(study_filter="GOM")

                # Get OHLCV summary
                ohlcv = self.mcp.data_get_ohlcv(count=20, summary=True)

                return self._build_snapshot(quote, study_values, gom_lines, gom_labels, ohlcv)

            except Exception as e:
                print(f"[TV-Poller] ❌ MCP fetch error: {e}", file=sys.stderr)
                return None
        else:
            # Fallback: Use cached/synthetic data
            return self._build_fallback_snapshot()

    def _build_snapshot(self, quote, study_values, gom_lines, gom_labels, ohlcv):
        """Build snapshot from MCP data"""

        snapshot = {
            "symbol": self.symbol,
            "timestamp": int(time.time()),

            # Price data
            "bid": quote.get("last", 0) if isinstance(quote, dict) else 0,
            "ask": quote.get("last", 0) + 0.01 if isinstance(quote, dict) else 0,
            "high20": ohlcv.get("high", 0) if isinstance(ohlcv, dict) else 0,
            "low20": ohlcv.get("low", 0) if isinstance(ohlcv, dict) else 0,
            "volume_avg": ohlcv.get("volume", 0) if isinstance(ohlcv, dict) else 0,

            # GOM verdict (from gom_signal.json if available)
            "gom_verdict": self._get_gom_verdict(),
            "gom_score": self._get_gom_score(),
            "gom_quality": self._get_gom_quality(),
            "gom_imbalance": self._get_gom_imbalance(),

            # Order Blocks from Pine labels
            "ob_bullish": self._extract_level_from_labels(gom_labels, "OB_Bull"),
            "ob_bearish": self._extract_level_from_labels(gom_labels, "OB_Bear"),

            # FVG from Pine lines
            "fvg_up": self._extract_level_from_lines(gom_lines, "FVG_Up"),
            "fvg_down": self._extract_level_from_lines(gom_lines, "FVG_Down"),

            # Indicators
            "rsi": study_values.get("RSI", 50) if isinstance(study_values, dict) else 50,
            "stoch_k": study_values.get("Stoch_K", 50) if isinstance(study_values, dict) else 50,
            "stoch_d": study_values.get("Stoch_D", 50) if isinstance(study_values, dict) else 50,
            "ema_8": study_values.get("EMA_8", 0) if isinstance(study_values, dict) else 0,
            "ema_21": study_values.get("EMA_21", 0) if isinstance(study_values, dict) else 0,

            # Multi-TF status
            "h4_trend": self._get_h4_trend(),
            "h1_structure": self._get_h1_structure(),
            "m15_alignment": self._get_m15_alignment(),
        }

        return snapshot

    def _build_fallback_snapshot(self):
        """Fallback: Return synthetic data"""

        return {
            "symbol": self.symbol,
            "timestamp": int(time.time()),
            "bid": 24550.25,
            "ask": 24550.50,
            "high20": 24560.0,
            "low20": 24540.0,
            "volume_avg": 2500,

            "gom_verdict": "WAIT",
            "gom_score": 0,
            "gom_quality": 0.0,
            "gom_imbalance": 0.0,

            "ob_bullish": 24545.0,
            "ob_bearish": 24555.0,
            "fvg_up": 24552.0,
            "fvg_down": 24548.0,

            "rsi": 50,
            "stoch_k": 50,
            "stoch_d": 50,
            "ema_8": 24550.0,
            "ema_21": 24549.0,

            "h4_trend": "NEUTRAL",
            "h1_structure": "CONSOLIDATION",
            "m15_alignment": "NONE",
        }

    def _get_gom_verdict(self):
        """Read verdict from gom_signal.json"""

        gom_file = self.data_dir / "gom_signal.json"
        try:
            if gom_file.exists():
                with open(gom_file, 'r') as f:
                    gom = json.load(f)
                    return gom.get("verdict", "WAIT")
        except:
            pass

        return "WAIT"

    def _get_gom_score(self):
        """Read score from gom_signal.json"""

        gom_file = self.data_dir / "gom_signal.json"
        try:
            if gom_file.exists():
                with open(gom_file, 'r') as f:
                    gom = json.load(f)
                    # Calculate score from quality/coherence
                    quality = gom.get("quality", 0)
                    coherence = gom.get("coherence", 0)
                    score = int((quality + coherence) / 25)  # Normalize to 0-7
                    return min(score, 7)
        except:
            pass

        return 0

    def _get_gom_quality(self):
        """Read quality from gom_signal.json"""

        gom_file = self.data_dir / "gom_signal.json"
        try:
            if gom_file.exists():
                with open(gom_file, 'r') as f:
                    gom = json.load(f)
                    return gom.get("quality", 0.0)
        except:
            pass

        return 0.0

    def _get_gom_imbalance(self):
        """Read imbalance from gom_signal.json"""

        gom_file = self.data_dir / "gom_signal.json"
        try:
            if gom_file.exists():
                with open(gom_file, 'r') as f:
                    gom = json.load(f)
                    return gom.get("imbalance", 0.0)
        except:
            pass

        return 0.0

    def _extract_level_from_labels(self, labels, label_key):
        """Extract price level from Pine labels"""

        if not isinstance(labels, dict):
            return 0.0

        for label in labels.get("data", []):
            if label_key in str(label.get("text", "")):
                try:
                    return float(label.get("price", 0))
                except:
                    pass

        return 0.0

    def _extract_level_from_lines(self, lines, line_key):
        """Extract price level from Pine lines"""

        if not isinstance(lines, list):
            return 0.0

        for line in lines:
            if line_key in str(line.get("label", "")):
                try:
                    return float(line.get("level", 0))
                except:
                    pass

        return 0.0

    def _get_h4_trend(self):
        """Detect H4 trend from EMA crossover"""

        # In real implementation: Check EMA 21/50 on H4
        # For now: return synthetic
        return "UP"

    def _get_h1_structure(self):
        """Detect H1 structure (impulsive vs corrective)"""

        # In real implementation: Count swings on H1
        # For now: return synthetic
        return "IMPULSIVE"

    def _get_m15_alignment(self):
        """Check M15 alignment with GOM"""

        verdict = self._get_gom_verdict()

        if verdict != "WAIT":
            return "GOM_ALIGNED"

        return "NONE"

    def poll(self):
        """Main polling loop"""

        print(f"[TV-Poller] Starting: symbol={self.symbol}, interval={self.interval}s")

        while True:
            try:
                snapshot = self.fetch_tv_data()

                if snapshot:
                    # Write to file
                    with open(self.output_file, 'w') as f:
                        json.dump(snapshot, f, indent=2)

                    # Log
                    gom = snapshot.get("gom_verdict", "WAIT")
                    quality = snapshot.get("gom_quality", 0)
                    rsi = snapshot.get("rsi", 50)
                    bid = snapshot.get("bid", 0)

                    print(f"[TV-Poller] {datetime.now().isoformat()} ✅ "
                          f"BID={bid:.2f} RSI={rsi:.0f} GOM={gom} Q={quality:.0f}%")

                time.sleep(self.interval)

            except KeyboardInterrupt:
                print("\n[TV-Poller] Shutdown")
                break

            except Exception as e:
                print(f"[TV-Poller] ❌ Error: {e}", file=sys.stderr)
                time.sleep(self.interval)


def main():
    """Entry point"""

    import argparse

    parser = argparse.ArgumentParser(description="TradingView Snapshot Poller")
    parser.add_argument("--symbol", default="Boom 500 Index", help="Symbol to poll")
    parser.add_argument("--interval", type=int, default=5, help="Poll interval (seconds)")

    args = parser.parse_args()

    poller = TVSnapshotPoller(symbol=args.symbol, interval=args.interval)
    poller.poll()


if __name__ == "__main__":
    main()
