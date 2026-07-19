#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Pullback Alert Service — Receives events from SMC_Universal.mq5 and sends beautiful WhatsApp alerts
Integrates with existing gom_sync_with_report.py send_whatsapp_report() function
"""

import sys
import io
import json
import logging
from datetime import datetime
from typing import Dict, Optional
from pathlib import Path

# UTF-8 wrapper
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Setup logging
log_file = Path("D:/Dev/TradBOT/logs/pullback_alerts.log")
log_file.parent.mkdir(exist_ok=True, parents=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - pullback_service - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8', mode='a'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Import formatter
from pullback_alert_formatter import PullbackAlertFormatter, send_pullback_alert

class PullbackAlertService:
    """Service to handle Pullback events from MT5 and send WhatsApp alerts"""

    def __init__(self):
        self.formatter = PullbackAlertFormatter()
        self.last_alerts = {}  # Track timestamps to avoid spam

    def process_event(self, event: Dict) -> Optional[str]:
        """
        Process Pullback event from MT5 and return formatted message

        Event structure from SMC_Universal.mq5:
        {
            "phase": "pullback_start" | "pullback_detected" | "resumption_confirmed" | "trade_opened",
            "symbol": "Boom 150 Index",
            "direction": "BUY" | "SELL",
            "breakout_price": 1456.23,
            "pullback_pct": 0.92,
            "pullback_price": 1452.11,
            "entry_price": 1453.45,
            "sl": 1451.95,
            "tp": 1455.20,
            "lot": 0.01,
            "ticket": 12345,
            "risk_usd": 0.48,
            "reward_usd": 0.53,
            "gom_level": "PERFECT BUY",
            "gom_confidence": 0.85,
            "gom_coherence": 75.0,
            "ml_confidence": 0.80,
            "atr": 3.5,
            "signals": "EMA Cross + Volume Spike"
        }
        """

        phase = event.get("phase", "unknown")
        symbol = event.get("symbol", "N/A")
        direction = event.get("direction", "UNKNOWN")

        logger.info(f"[EVENT] {phase.upper()} — {symbol} {direction}")

        # Anti-spam: skip if same event within 5 seconds
        key = f"{phase}_{symbol}_{direction}"
        now = datetime.now().timestamp()
        last_time = self.last_alerts.get(key, 0)
        if now - last_time < 5:
            logger.warning(f"[SPAM] Skipped {key} (within 5sec debounce)")
            return None

        self.last_alerts[key] = now

        # Format message based on phase
        message = None

        if phase == "pullback_start":
            message = self.formatter.format_pullback_started(
                symbol=symbol,
                direction=direction,
                breakout_price=event.get("breakout_price", 0),
                pullback_min=event.get("pullback_min", 0.5),
                pullback_max=event.get("pullback_max", 1.5),
                gom_level=event.get("gom_level"),
                gom_confidence=event.get("gom_confidence"),
                coherence_pct=event.get("gom_coherence")
            )

        elif phase == "pullback_detected":
            message = self.formatter.format_pullback_detected(
                symbol=symbol,
                direction=direction,
                pullback_pct=event.get("pullback_pct", 0),
                pullback_price=event.get("pullback_price", 0),
                breakout_price=event.get("breakout_price", 0),
                atr=event.get("atr"),
                ml_confidence=event.get("ml_confidence")
            )

        elif phase == "resumption_confirmed":
            message = self.formatter.format_resumption_confirmed(
                symbol=symbol,
                direction=direction,
                entry_price=event.get("entry_price", 0),
                sl=event.get("sl", 0),
                tp=event.get("tp", 0),
                lot=event.get("lot", 0),
                signals_detail=event.get("signals", "EMA Cross + Volume Spike"),
                gom_coherence=event.get("gom_coherence"),
                gom_level_name=event.get("gom_level_name")
            )

        elif phase == "trade_opened":
            message = self.formatter.format_trade_opened(
                symbol=symbol,
                direction=direction,
                entry_price=event.get("entry_price", 0),
                sl=event.get("sl", 0),
                tp=event.get("tp", 0),
                lot=event.get("lot", 0),
                ticket=event.get("ticket", 0),
                risk_usd=event.get("risk_usd", 0),
                reward_usd=event.get("reward_usd", 0),
                gom_verdict=event.get("gom_level"),
                gom_confidence=event.get("gom_confidence"),
                entry_method="PULLBACK"
            )

        elif phase == "trade_failed":
            message = self.formatter.format_trade_failed(
                symbol=symbol,
                direction=direction,
                error_code=event.get("error_code", "UNKNOWN"),
                reason=event.get("error_reason", "Unknown reason")
            )

        if not message:
            logger.error(f"[ERROR] Unknown phase: {phase}")
            return None

        logger.info(f"[FORMAT] Message formatted successfully")
        return message

    def send_alert(self, message: str, send_function) -> bool:
        """Send formatted message via WhatsApp"""
        try:
            logger.info("[SEND] Sending via WhatsApp...")
            result = send_function(message)
            if result:
                logger.info("[OK] Alert sent successfully!")
            else:
                logger.warning("[WARN] send_whatsapp_report returned False")
            return result
        except Exception as e:
            logger.error(f"[ERROR] Send failed: {e}")
            return False


# Singleton instance
_service = PullbackAlertService()


def handle_pullback_event(event: Dict, send_function) -> Dict:
    """
    Main entry point: process event and send alert
    Returns status dict for FastAPI response
    """
    try:
        # Format message
        message = _service.process_event(event)
        if not message:
            return {
                "success": False,
                "error": "Could not format message (unknown phase or spam debounce)"
            }

        # Send via WhatsApp
        sent = _service.send_alert(message, send_function)

        return {
            "success": sent,
            "phase": event.get("phase"),
            "symbol": event.get("symbol"),
            "message_preview": message[:100] + "..." if len(message) > 100 else message
        }

    except Exception as e:
        logger.error(f"[ERROR] Exception in handle_pullback_event: {e}")
        return {
            "success": False,
            "error": str(e)
        }


if __name__ == "__main__":
    # Test locally
    logger.info("Starting Pullback Alert Service (test mode)")

    # Mock send function for testing
    def mock_send(msg):
        logger.info(f"[MOCK] Would send: {msg[:80]}...")
        return True

    # Test event
    test_event = {
        "phase": "pullback_start",
        "symbol": "Boom 150 Index",
        "direction": "BUY",
        "breakout_price": 1456.23,
        "pullback_min": 0.5,
        "pullback_max": 1.5,
        "gom_level": "PERFECT BUY",
        "gom_confidence": 0.85,
        "gom_coherence": 75.0
    }

    result = handle_pullback_event(test_event, mock_send)
    print(f"\nResult: {json.dumps(result, indent=2)}")
