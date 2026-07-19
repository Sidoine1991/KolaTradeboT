#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pipeline with Spike Anticipation — Place limit orders ahead of price to catch spikes
"""

import json
import requests
import logging
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Any, Optional

# Force UTF-8 on Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

from spike_anticipation import SpikeAnticipator

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler("logs/pipeline_spike_anticipation.log", encoding='utf-8', mode='a'),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(__name__)

AI_SERVER = "http://127.0.0.1:8000"

class PipelineWithSpikeAnticipation:
    """Trading pipeline with spike anticipation enabled."""

    def __init__(self):
        self.anticipator = SpikeAnticipator(anticipation_pips=5.0)
        self.orders_placed = 0
        self.spikes_anticipated = 0

    def place_order_with_anticipation(self, order_data: Dict[str, Any]) -> bool:
        """
        Place order with spike anticipation applied.

        Args:
            order_data: Dictionary with symbol, action, entry, sl, tp, etc.

        Returns:
            True if order placed successfully
        """

        try:
            symbol = order_data.get("symbol", "?")
            action = order_data.get("action", "?")
            base_entry = float(order_data.get("entry", 0.0))
            base_sl = float(order_data.get("sl", 0.0))
            base_tp = float(order_data.get("tp", 0.0))
            verdict = order_data.get("verdict", "GOOD")
            rsi = order_data.get("rsi")
            volatility = order_data.get("volatility_regime")

            # Apply spike anticipation
            anticipated_order = self.anticipator.format_order_with_anticipation(
                symbol=symbol,
                action=action,
                base_entry=base_entry,
                base_sl=base_sl,
                base_tp=base_tp,
                verdict_strength=verdict,
                rsi=rsi,
                volatility_regime=volatility,
            )

            if anticipated_order["anticipation_applied"]:
                log.info(
                    f"[SPIKE] {symbol}: Anticipation enabled "
                    f"({anticipated_order['anticipation_distance_pips']:.1f} pips ahead)"
                )
                self.spikes_anticipated += 1

                # Use anticipated prices
                entry = anticipated_order["entry"]
                sl = anticipated_order["sl"]
                tp = anticipated_order["tp"]
            else:
                entry = base_entry
                sl = base_sl
                tp = base_tp

            # Place order on server
            payload = {
                "symbol": symbol,
                "action": action,
                "entry": entry,
                "sl": sl,
                "tp": tp,
                "order_type": "limit",
                "source": "pipeline_spike_anticipation",
                "original_entry": base_entry,  # Include original for audit
                "anticipation_pips": anticipated_order.get("anticipation_distance_pips", 0),
            }

            r = requests.post(f"{AI_SERVER}/place-order", json=payload, timeout=5)

            if r.status_code == 200:
                log.info(f"[OK] {symbol} {action} @ {entry:.5f} placed (spike anticipation)")
                self.orders_placed += 1
                return True
            else:
                log.warning(f"[ERROR] Failed to place {symbol} order: HTTP {r.status_code}")
                return False

        except Exception as e:
            log.error(f"[ERROR] Exception placing order: {e}")
            return False

    def run_pipeline_with_anticipation(self) -> Dict[str, Any]:
        """Execute full pipeline with spike anticipation."""

        log.info("="*70)
        log.info("[START] Pipeline with Spike Anticipation")
        log.info("="*70)

        # Load GOM verdicts
        try:
            r = requests.get(f"{AI_SERVER}/gom-verdicts", timeout=5)
            if r.status_code != 200:
                log.error(f"Failed to load GOM verdicts: HTTP {r.status_code}")
                return {"error": "GOM load failed"}

            data = r.json()
            verdicts = data.get("verdicts", [])
            log.info(f"[OK] Loaded {len(verdicts)} GOM verdicts")

        except Exception as e:
            log.error(f"[ERROR] Loading verdicts: {e}")
            return {"error": str(e)}

        # Process with spike anticipation
        for i, verdict in enumerate(verdicts[:5], 1):  # Process top 5
            try:
                symbol = str(verdict.get("symbol", "?"))
                action = "BUY" if int(verdict.get("verdict_num", 0)) > 0 else "SELL"
                entry = float(verdict.get("entry", 0.0))
                sl = float(verdict.get("sl", 0.0))
                tp = float(verdict.get("tp", 0.0))
                verdict_str = verdict.get("verdict", "GOOD")
                rsi = float(verdict.get("tf_m5_rsi", 50.0))

                log.info(f"\n[{i}] {symbol} {action} @ {entry:.5f}")

                order = {
                    "symbol": symbol,
                    "action": action,
                    "entry": entry,
                    "sl": sl,
                    "tp": tp,
                    "verdict": verdict_str,
                    "rsi": rsi,
                    "volatility_regime": 1,  # Assume high for testing
                }

                self.place_order_with_anticipation(order)

            except Exception as e:
                log.error(f"[ERROR] Processing verdict {i}: {e}")

        result = {
            "status": "complete",
            "orders_placed": self.orders_placed,
            "spikes_anticipated": self.spikes_anticipated,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }

        log.info(f"\n[RESULT] Orders placed: {self.orders_placed}")
        log.info(f"[RESULT] Spikes anticipated: {self.spikes_anticipated}")
        log.info("="*70)

        return result


if __name__ == "__main__":
    pipeline = PipelineWithSpikeAnticipation()
    result = pipeline.run_pipeline_with_anticipation()
    print(json.dumps(result, indent=2))
