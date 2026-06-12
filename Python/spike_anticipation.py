#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Spike Anticipation — Place limit orders AHEAD of price to catch spikes
Au lieu de placer à Entry exact, on anticipe d'un candlestick pour ne pas rater les mouvements rapides
"""

import logging
from typing import Dict, Any, Optional, Tuple
from datetime import datetime, timezone

logger = logging.getLogger(__name__)

class SpikeAnticipator:
    """Anticipate spikes and adjust limit order placement."""

    def __init__(self, anticipation_pips: float = 5.0):
        """
        Initialize spike anticipator.

        Args:
            anticipation_pips: Number of pips to advance the order (default: 5)
        """
        self.anticipation_pips = anticipation_pips

    def calculate_anticipation_entry(
        self,
        base_entry: float,
        action: str,
        pip_value: float = 0.0001,
        rsi: Optional[float] = None,
        volatility_regime: Optional[int] = None,
    ) -> Tuple[float, Dict[str, Any]]:
        """
        Calculate anticipation entry point ahead of base entry.

        For BUY: Place order ABOVE current price (anticipate upward spike)
        For SELL: Place order BELOW current price (anticipate downward spike)

        Args:
            base_entry: Original entry price from GOM
            action: "BUY" or "SELL"
            pip_value: Pip value for currency pair (default 0.0001 for most pairs)
            rsi: RSI value (if available, to adjust anticipation)
            volatility_regime: 0=low, 1=high (if available)

        Returns:
            Tuple of (anticipation_entry, metadata)
        """

        # Adjust anticipation based on market conditions
        base_pips = self.anticipation_pips

        # If RSI extreme, increase anticipation (spike likely)
        if rsi is not None:
            if rsi > 70 or rsi < 30:
                base_pips *= 1.5  # 50% more aggressive
                logger.info(f"[SPIKE] RSI extreme ({rsi:.0f}), increasing anticipation to {base_pips:.1f} pips")

        # If high volatility, increase anticipation
        if volatility_regime == 1:  # High volatility
            base_pips *= 1.25
            logger.info(f"[SPIKE] High volatility detected, anticipation: {base_pips:.1f} pips")

        # Calculate anticipation points
        anticipation_amount = base_pips * pip_value

        if action.upper() == "BUY":
            # For BUY, move entry UP to catch upward spike
            anticipation_entry = base_entry + anticipation_amount
            direction = "UP"
        else:  # SELL
            # For SELL, move entry DOWN to catch downward spike
            anticipation_entry = base_entry - anticipation_amount
            direction = "DOWN"

        metadata = {
            "base_entry": base_entry,
            "anticipation_entry": round(anticipation_entry, 5),
            "anticipation_distance_pips": base_pips,
            "anticipation_amount": round(anticipation_amount, 5),
            "direction": direction,
            "rsi_adjusted": rsi is not None and (rsi > 70 or rsi < 30),
            "volatility_adjusted": volatility_regime == 1,
        }

        return anticipation_entry, metadata

    def adjust_sl_tp_for_anticipation(
        self,
        base_sl: float,
        base_tp: float,
        base_entry: float,
        anticipation_entry: float,
        action: str,
    ) -> Tuple[float, float, Dict[str, Any]]:
        """
        Adjust SL/TP based on new anticipation entry point.

        Keep the same risk/reward ratio but adjusted for new entry.
        """

        if action.upper() == "BUY":
            # Distance from base to TP and SL
            tp_distance = base_tp - base_entry
            sl_distance = base_entry - base_sl

            # Apply same distances from anticipation entry
            new_tp = anticipation_entry + tp_distance
            new_sl = anticipation_entry - sl_distance
        else:  # SELL
            tp_distance = base_entry - base_tp
            sl_distance = base_sl - base_entry

            new_tp = anticipation_entry - tp_distance
            new_sl = anticipation_entry + sl_distance

        metadata = {
            "original_entry": base_entry,
            "anticipation_entry": anticipation_entry,
            "original_sl": base_sl,
            "adjusted_sl": round(new_sl, 5),
            "original_tp": base_tp,
            "adjusted_tp": round(new_tp, 5),
            "risk_distance_pips": abs(new_sl - anticipation_entry) / 0.0001,
            "reward_distance_pips": abs(new_tp - anticipation_entry) / 0.0001,
        }

        return new_sl, new_tp, metadata

    def should_anticipate(
        self,
        symbol: str,
        verdict_strength: str,
        recent_volatility: Optional[float] = None,
    ) -> bool:
        """
        Decide if spike anticipation should be applied.

        ALWAYS anticipate for PERFECT signals.
        Conditionally anticipate for GOOD/SELL based on volatility.
        """

        verdict_strength_upper = verdict_strength.upper()

        # Always anticipate for PERFECT signals
        if "PERFECT" in verdict_strength_upper:
            logger.info(f"[SPIKE] {symbol}: PERFECT signal → ANTICIPATE")
            return True

        # For GOOD signals, anticipate if high volatility
        if "GOOD" in verdict_strength_upper:
            if recent_volatility and recent_volatility > 0.015:  # >1.5% volatility
                logger.info(f"[SPIKE] {symbol}: GOOD signal + high volatility ({recent_volatility:.2%}) → ANTICIPATE")
                return True

        logger.debug(f"[SPIKE] {symbol}: {verdict_strength} signal → NO anticipation needed")
        return False

    def format_order_with_anticipation(
        self,
        symbol: str,
        action: str,
        base_entry: float,
        base_sl: float,
        base_tp: float,
        verdict_strength: str,
        rsi: Optional[float] = None,
        volatility_regime: Optional[int] = None,
    ) -> Dict[str, Any]:
        """
        Complete order formatting with spike anticipation applied.
        """

        # Check if anticipation should be applied
        if not self.should_anticipate(symbol, verdict_strength, volatility_regime):
            # Return original order
            return {
                "symbol": symbol,
                "action": action,
                "entry": base_entry,
                "sl": base_sl,
                "tp": base_tp,
                "anticipation_applied": False,
                "reason": "Signal strength or conditions do not warrant anticipation",
            }

        # Calculate anticipation entry
        anticipation_entry, entry_metadata = self.calculate_anticipation_entry(
            base_entry, action, rsi=rsi, volatility_regime=volatility_regime
        )

        # Adjust SL/TP
        new_sl, new_tp, sl_tp_metadata = self.adjust_sl_tp_for_anticipation(
            base_sl, base_tp, base_entry, anticipation_entry, action
        )

        return {
            "symbol": symbol,
            "action": action,
            "original_entry": base_entry,
            "entry": round(anticipation_entry, 5),
            "original_sl": base_sl,
            "sl": new_sl,
            "original_tp": base_tp,
            "tp": new_tp,
            "anticipation_applied": True,
            "anticipation_distance_pips": entry_metadata["anticipation_distance_pips"],
            "rsi": rsi,
            "volatility_regime": volatility_regime,
            "timestamp": datetime.now(timezone.utc).isoformat(),
        }


# Example usage
if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO)

    anticipator = SpikeAnticipator(anticipation_pips=5.0)

    # Test case 1: PERFECT BUY signal with high RSI
    print("\n" + "="*70)
    print("Test 1: PERFECT BUY (RSI=75, high volatility)")
    print("="*70)

    order1 = anticipator.format_order_with_anticipation(
        symbol="XAUUSD",
        action="BUY",
        base_entry=4216.45,
        base_sl=4200.00,
        base_tp=4240.00,
        verdict_strength="PERFECT BUY",
        rsi=75.0,
        volatility_regime=1,
    )

    print(f"Original Entry: {order1['original_entry']}")
    print(f"Anticipation Entry: {order1['entry']}")
    print(f"Distance: {order1['anticipation_distance_pips']:.1f} pips")
    print(f"Original SL: {order1['original_sl']}")
    print(f"Adjusted SL: {order1['sl']}")
    print(f"Original TP: {order1['original_tp']}")
    print(f"Adjusted TP: {order1['tp']}")

    # Test case 2: GOOD BUY with low volatility (no anticipation)
    print("\n" + "="*70)
    print("Test 2: GOOD BUY (RSI=50, low volatility)")
    print("="*70)

    order2 = anticipator.format_order_with_anticipation(
        symbol="BOOM 500",
        action="BUY",
        base_entry=5319.72,
        base_sl=5299.72,
        base_tp=5359.72,
        verdict_strength="GOOD BUY",
        rsi=50.0,
        volatility_regime=0,
    )

    print(f"Anticipation Applied: {order2['anticipation_applied']}")
    print(f"Reason: {order2['reason']}")

    # Test case 3: PERFECT SELL with low RSI
    print("\n" + "="*70)
    print("Test 3: PERFECT SELL (RSI=25)")
    print("="*70)

    order3 = anticipator.format_order_with_anticipation(
        symbol="BOOM 300",
        action="SELL",
        base_entry=1945.00,
        base_sl=1955.00,
        base_tp=1920.00,
        verdict_strength="PERFECT SELL",
        rsi=25.0,
    )

    print(f"Original Entry: {order3['original_entry']}")
    print(f"Anticipation Entry: {order3['entry']}")
    print(f"Direction: DOWN (anticipating downward spike)")
