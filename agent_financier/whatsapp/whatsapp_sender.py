#!/usr/bin/env python3
"""whatsapp_sender.py – Envoi via WhatsApp."""
import logging
import os
from typing import List
from mcp_bridge import TradingViewSetup

logger = logging.getLogger(__name__)


class WhatsAppSender:
    def __init__(self):
        self.account_sid = os.environ.get("TWILIO_ACCOUNT_SID")
        self.auth_token = os.environ.get("TWILIO_AUTH_TOKEN")
        self.from_number = os.environ.get("TWILIO_WHATSAPP_FROM", "whatsapp:+14155238886")
        self.to_number = os.environ.get("WHATSAPP_TO")
        self._client = None
        if self.account_sid and self.auth_token:
            from twilio.rest import Client
            self._client = Client(self.account_sid, self.auth_token)

    def send_daily_report(self, setups: List[TradingViewSetup], chart_paths: List[str]) -> List[str]:
        if not self._client:
            logger.info("Mode simulation – pas d'envoi réel")
            print("=== MESSAGE WHATSAPP ===")
            for s in setups:
                print(f"{s.symbol} {s.direction} @ {s.entry:.5f} (SL:{s.stop_loss:.5f} TP:{s.take_profit:.5f})")
            return []
        # TODO: implémenter l'envoi Twilio
        return []
