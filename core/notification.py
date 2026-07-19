"""
Notification Manager — Alertes WhatsApp/Telegram/Console
===========================================================

Fonctionnalités:
  - Envoi WhatsApp via PsychoBot
  - Envoi Telegram (optionnel)
  - Notifications Console
  - Templates de messages pour chaque événement
  - Rate limiting des notifications
  - File d'attente avec retry
"""

import time
import logging
import requests
import urllib3
from dataclasses import dataclass, field
from typing import List, Dict, Optional
from collections import deque
from datetime import datetime, timezone
from enum import Enum

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

logger = logging.getLogger("tradbot.notification")

PSYCHOBOT_URL = "https://psychobot-1si7.onrender.com"

# ──────────────────────────────────────────────────────────────

class EventType(str, Enum):
    ORDER_PLACED = "order_placed"
    ORDER_FAILED = "order_failed"
    ORDER_CLOSED = "order_closed"
    STOP_LOSS_HIT = "stop_loss_hit"
    TAKE_PROFIT_HIT = "take_profit_hit"
    ORDER_MODIFIED = "order_modified"
    GOM_VERDICT_CHANGE = "gom_verdict_change"
    PATTERN_DETECTED = "pattern_detected"
    PATTERN_EXPIRED = "pattern_expired"
    RISK_WARNING = "risk_warning"
    DAILY_REPORT = "daily_report"
    ERROR = "error"
    INFO = "info"


@dataclass
class Notification:
    event_type: EventType
    title: str
    message: str
    symbol: str = ""
    priority: int = 0  # 0=low, 1=normal, 2=high
    timestamp: float = 0.0

    def format_whatsapp(self) -> str:
        """Formatte pour WhatsApp avec emojis."""
        emoji_map = {
            EventType.ORDER_PLACED: "✅",
            EventType.ORDER_FAILED: "❌",
            EventType.ORDER_CLOSED: "🔒",
            EventType.STOP_LOSS_HIT: "🛑",
            EventType.TAKE_PROFIT_HIT: "🎯",
            EventType.GOM_VERDICT_CHANGE: "🔄",
            EventType.PATTERN_DETECTED: "📊",
            EventType.PATTERN_EXPIRED: "💤",
            EventType.RISK_WARNING: "⚠️",
            EventType.DAILY_REPORT: "📋",
            EventType.ERROR: "🚨",
            EventType.INFO: "ℹ️",
        }
        emoji = emoji_map.get(self.event_type, "📢")
        ts = datetime.fromtimestamp(self.timestamp, tz=timezone.utc).strftime("%H:%M")
        lines = [
            f"{emoji} *{self.title}*",
            f"   {self.message}",
            f"   _{ts}_",
        ]
        return "\n".join(lines)


class NotificationManager:
    """
    Gère l'envoi de notifications sur tous les canaux.

    Règles:
      - Rate limit: max 1 msg/5s par canal
      - File d'attente avec retry (3 tentatives)
      - Pas de doublons dans les 60 dernières secondes
    """

    def __init__(self, phone: str = "", psychobot_url: str = PSYCHOBOT_URL):
        self.phone = phone
        self.psychobot_url = psychobot_url
        self._queue: deque = deque(maxlen=50)
        self._last_send: Dict[str, float] = {}
        self._recent_messages: Dict[str, float] = {}
        self._rate_limit_sec = 5.0
        self._dedup_sec = 60.0

    # ──────────────────────────────────────────────────────────
    # Public API
    # ──────────────────────────────────────────────────────────

    def send(self, notification: Notification) -> bool:
        """
        Envoie une notification sur tous les canaux disponibles.
        Retourne True si au moins un canal a réussi.
        """
        notification.timestamp = time.time()

        # Dedup: ignorer si message identique récent
        dedup_key = f"{notification.event_type.value}:{notification.title}:{notification.message[:50]}"
        if dedup_key in self._recent_messages:
            elapsed = time.time() - self._recent_messages[dedup_key]
            if elapsed < self._dedup_sec:
                logger.debug(f"Notification dédoublonnée: {dedup_key[:60]}")
                return False

        success = False
        if self.phone:
            if self._wa_send(notification):
                success = True
        self._console_send(notification)
        success = True

        self._recent_messages[dedup_key] = time.time()
        return success

    def send_whatsapp(self, title: str, message: str,
                      event_type: EventType = EventType.INFO,
                      symbol: str = "", priority: int = 0) -> bool:
        """Raccourci pour créer et envoyer une notification WhatsApp."""
        return self.send(Notification(
            event_type=event_type, title=title,
            message=message, symbol=symbol, priority=priority
        ))

    def send_raw_whatsapp(self, text: str) -> bool:
        """Envoie un texte brut WhatsApp."""
        if not self.phone:
            return False
        if not self._rate_ok("whatsapp"):
            self._queue.append(text)
            return False
        return self._wa_send_raw(text)

    def flush_queue(self) -> None:
        """Vide la file d'attente."""
        while self._queue:
            item = self._queue.popleft()
            if isinstance(item, Notification):
                self.send(item)
            else:
                self.send_raw_whatsapp(item)
            time.sleep(1)

    # ──────────────────────────────────────────────────────────
    # Canaux
    # ──────────────────────────────────────────────────────────

    def _wa_send(self, notification: Notification) -> bool:
        if not self._rate_ok("whatsapp"):
            self._queue.append(notification)
            return False

        text = notification.format_whatsapp()
        return self._wa_send_raw(text)

    def _wa_send_raw(self, text: str) -> bool:
        for attempt in range(3):
            try:
                r = requests.post(
                    f"{self.psychobot_url}/send-message",
                    json={"phone": self.phone, "message": text},
                    timeout=15,
                    verify=False,
                )
                if r.status_code == 200:
                    payload = r.json()
                    if payload.get("success", False):
                        self._last_send["whatsapp"] = time.time()
                        return True
                logger.warning(f"WhatsApp HTTP {r.status_code} (tentative {attempt + 1}/3): {r.text[:100]}")
            except Exception as e:
                logger.warning(f"WhatsApp error (tentative {attempt + 1}/3): {e}")
            time.sleep(3)
        logger.error("WhatsApp: 3 tentatives échouées")
        return False

    def _console_send(self, notification: Notification) -> None:
        logger.info(
            f"[{notification.event_type.value.upper()}] "
            f"{notification.title}: {notification.message[:200]}"
        )

    def _rate_ok(self, channel: str) -> bool:
        last = self._last_send.get(channel, 0)
        return time.time() - last >= self._rate_limit_sec
