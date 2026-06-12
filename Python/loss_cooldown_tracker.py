#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Loss Cooldown Tracker - 1 Hour Cooldown After 2 Consecutive Losses on Same Symbol
Prevents revenge trading after successive losses
"""

import json
import logging
from datetime import datetime, timedelta, timezone
from pathlib import Path

logger = logging.getLogger("loss_cooldown")

COOLDOWN_FILE = Path("data/loss_cooldown.json")
COOLDOWN_DURATION_SECONDS = 3600  # 1 hour
CONSECUTIVE_LOSS_THRESHOLD = 2  # 2 losses

class LossCooldownTracker:
    def __init__(self):
        self.cooldowns = self._load_cooldowns()
        self._cleanup_expired()

    def _load_cooldowns(self):
        """Load cooldown data from file"""
        if not COOLDOWN_FILE.exists():
            return {}
        try:
            with open(COOLDOWN_FILE, 'r') as f:
                return json.load(f)
        except Exception as e:
            logger.warning(f"Failed to load cooldown file: {e}")
            return {}

    def _save_cooldowns(self):
        """Save cooldown data to file"""
        try:
            COOLDOWN_FILE.parent.mkdir(parents=True, exist_ok=True)
            with open(COOLDOWN_FILE, 'w') as f:
                json.dump(self.cooldowns, f, indent=2)
        except Exception as e:
            logger.warning(f"Failed to save cooldown file: {e}")

    def _cleanup_expired(self):
        """Remove expired cooldowns"""
        now = datetime.now(timezone.utc).timestamp()
        expired = [k for k, v in self.cooldowns.items() if v.get("cooldown_until", 0) < now]
        for symbol in expired:
            del self.cooldowns[symbol]
        if expired:
            self._save_cooldowns()

    def record_loss(self, symbol):
        """Record a loss for symbol"""
        now = datetime.now(timezone.utc).isoformat()

        if symbol not in self.cooldowns:
            self.cooldowns[symbol] = {
                "consecutive_losses": 0,
                "last_loss": now,
                "cooldown_until": 0,
                "losses_list": []
            }

        self.cooldowns[symbol]["consecutive_losses"] += 1
        self.cooldowns[symbol]["last_loss"] = now
        self.cooldowns[symbol]["losses_list"].append(now)

        # Keep only last 10 losses
        self.cooldowns[symbol]["losses_list"] = self.cooldowns[symbol]["losses_list"][-10:]

        logger.info(f"[LOSS] {symbol}: Loss #{self.cooldowns[symbol]['consecutive_losses']} recorded")

        # Check if cooldown triggered
        if self.cooldowns[symbol]["consecutive_losses"] >= CONSECUTIVE_LOSS_THRESHOLD:
            self._trigger_cooldown(symbol)

        self._save_cooldowns()

    def record_win(self, symbol):
        """Record a win for symbol - resets counter"""
        if symbol in self.cooldowns:
            self.cooldowns[symbol]["consecutive_losses"] = 0
            logger.info(f"[WIN] {symbol}: Loss counter reset to 0")
            self._save_cooldowns()

    def _trigger_cooldown(self, symbol):
        """Trigger cooldown for symbol after 2 losses"""
        cooldown_until = datetime.now(timezone.utc).timestamp() + COOLDOWN_DURATION_SECONDS
        self.cooldowns[symbol]["cooldown_until"] = cooldown_until

        cooldown_time = datetime.fromtimestamp(cooldown_until, tz=timezone.utc).isoformat()
        logger.warning(f"🔴 [COOLDOWN] {symbol}: ACTIVATED after {CONSECUTIVE_LOSS_THRESHOLD} losses")
        logger.warning(f"   Cooldown until: {cooldown_time} (+1h)")
        logger.warning(f"   NO TRADING ON {symbol} DURING COOLDOWN")

        self._save_cooldowns()

    def is_in_cooldown(self, symbol):
        """Check if symbol is in cooldown"""
        if symbol not in self.cooldowns:
            return False

        cooldown_until = self.cooldowns[symbol].get("cooldown_until", 0)
        now = datetime.now(timezone.utc).timestamp()

        is_cooldown = cooldown_until > now

        if is_cooldown:
            remaining_seconds = int(cooldown_until - now)
            remaining_minutes = remaining_seconds // 60
            logger.warning(f"🔴 [COOLDOWN] {symbol}: IN COOLDOWN ({remaining_minutes}min remaining)")

        return is_cooldown

    def get_consecutive_losses(self, symbol):
        """Get consecutive loss count for symbol"""
        if symbol not in self.cooldowns:
            return 0
        return self.cooldowns[symbol].get("consecutive_losses", 0)

    def get_cooldown_info(self, symbol):
        """Get detailed cooldown info"""
        if symbol not in self.cooldowns:
            return {
                "symbol": symbol,
                "consecutive_losses": 0,
                "in_cooldown": False,
                "cooldown_until": None,
                "remaining_seconds": 0
            }

        data = self.cooldowns[symbol]
        now = datetime.now(timezone.utc).timestamp()
        cooldown_until = data.get("cooldown_until", 0)
        remaining = max(0, int(cooldown_until - now))

        return {
            "symbol": symbol,
            "consecutive_losses": data.get("consecutive_losses", 0),
            "in_cooldown": remaining > 0,
            "cooldown_until": datetime.fromtimestamp(cooldown_until, tz=timezone.utc).isoformat() if cooldown_until > 0 else None,
            "remaining_seconds": remaining,
            "remaining_minutes": remaining // 60,
            "last_loss": data.get("last_loss"),
            "losses_list": data.get("losses_list", [])[-5:]  # Last 5 losses
        }

    def reset_symbol(self, symbol):
        """Manually reset symbol cooldown"""
        if symbol in self.cooldowns:
            self.cooldowns[symbol]["consecutive_losses"] = 0
            self.cooldowns[symbol]["cooldown_until"] = 0
            logger.info(f"[RESET] {symbol}: Cooldown manually reset")
            self._save_cooldowns()


# Global instance
_tracker = None

def get_cooldown_tracker():
    """Get global cooldown tracker instance"""
    global _tracker
    if _tracker is None:
        _tracker = LossCooldownTracker()
    return _tracker


def check_symbol_cooldown(symbol):
    """Check if symbol is in cooldown (convenience function)"""
    tracker = get_cooldown_tracker()
    return tracker.is_in_cooldown(symbol)


def record_trade_result(symbol, is_win):
    """Record trade result (convenience function)"""
    tracker = get_cooldown_tracker()
    if is_win:
        tracker.record_win(symbol)
    else:
        tracker.record_loss(symbol)
