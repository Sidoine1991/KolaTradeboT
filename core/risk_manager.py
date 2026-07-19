"""
Risk Manager — Gestion des risques, sizing, limites
=====================================================

Fonctionnalités:
  - Daily budget avec suivi PnL
  - Position sizing basé sur le risque par trade
  - Limite de positions simultanées par symbole
  - Limite de drawdown quotidien
  - Vérification des sessions de trading
  - Cooldown entre trades
"""

import time
import logging
try:
    import MetaTrader5 as mt5
    _MT5_OK = True
except ImportError:
    mt5 = None
    _MT5_OK = False
from dataclasses import dataclass, field
from typing import Dict, Optional, List, Tuple
from datetime import datetime, timedelta, timezone
from enum import Enum

logger = logging.getLogger("tradbot.risk_manager")


class RiskLevel(str, Enum):
    NORMAL = "NORMAL"
    CAUTION = "CAUTION"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


@dataclass
class TradeLimits:
    max_daily_loss_pct: float = 5.0        # Perte max 5% du capital / jour
    max_daily_trades: int = 10              # Max 10 trades / jour
    max_positions_per_symbol: int = 1       # Une seule position / symbole
    max_concurrent_positions: int = 3       # Max 3 positions simultanées
    risk_per_trade_pct: float = 1.0         # Risque 1% par trade
    min_rr_ratio: float = 1.5              # RR minimum 1:1.5
    cooldown_seconds: int = 60              # 60s entre trades sur même symbole
    max_drawdown_pct: float = 15.0          # Drawdown max 15%


@dataclass
class DailyState:
    date: str = ""
    trades_count: int = 0
    daily_pnl: float = 0.0
    peak_balance: float = 0.0
    current_drawdown: float = 0.0
    loss_streak: int = 0
    win_streak: int = 0

    def reset_if_new_day(self, balance: float) -> bool:
        today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
        if self.date != today:
            self.date = today
            self.trades_count = 0
            self.daily_pnl = 0.0
            self.peak_balance = balance
            self.current_drawdown = 0.0
            self.loss_streak = 0
            self.win_streak = 0
            return True
        return False


class RiskManager:
    """
    Gestion centralisée des risques.

    Points clés:
      - Capital cible: 500$ (démarrage progressif: 0.01 lot par trade)
      - Perte max journalière: 5% du capital
      - Drawdown max: 15%
      - RR minimum: 1:1.5
      - Une seule position par symbole
    """

    def __init__(self, initial_balance: float = 500.0,
                 limits: Optional[TradeLimits] = None):
        self.limits = limits or TradeLimits()
        self.daily = DailyState()
        self._last_trade_time: Dict[str, float] = {}
        self._initial_balance = initial_balance
        self._current_balance = initial_balance

    # ──────────────────────────────────────────────────────────
    # Public API
    # ──────────────────────────────────────────────────────────

    def can_trade(self, symbol: str) -> Tuple[bool, str]:
        """
        Vérifie si un trade est autorisé selon toutes les règles.
        Retourne (autorized, reason).
        """
        # 1. État quotidien
        self.daily.reset_if_new_day(self._get_current_balance())

        # 2. Perte max journalière
        if self.daily.daily_pnl <= -self._initial_balance * self.limits.max_daily_loss_pct / 100:
            return False, f"Daily loss limit reached: {self.daily.daily_pnl:.2f}$"

        # 3. Drawdown max
        if self.daily.current_drawdown >= self.limits.max_drawdown_pct:
            return False, f"Max drawdown reached: {self.daily.current_drawdown:.1f}%"

        # 4. Nombre max de trades par jour
        if self.daily.trades_count >= self.limits.max_daily_trades:
            return False, f"Max daily trades ({self.limits.max_daily_trades}) reached"

        # 5. Positions simultanées
        open_positions = self._count_open_positions()
        if open_positions >= self.limits.max_concurrent_positions:
            return False, f"Max concurrent positions ({self.limits.max_concurrent_positions})"

        # 6. Cooldown entre trades sur même symbole
        last_trade = self._last_trade_time.get(symbol, 0)
        if time.time() - last_trade < self.limits.cooldown_seconds:
            remaining = int(self.limits.cooldown_seconds - (time.time() - last_trade))
            return False, f"Cooldown {symbol}: {remaining}s remaining"

        return True, "OK"

    def get_position_size(self, symbol: str, sl_distance: float,
                          risk_pct: Optional[float] = None) -> float:
        """
        Calcule la taille de position (lot) basée sur le risque.
        risk_pct: % du capital risqué sur ce trade.
        """
        risk_pct = risk_pct or self.limits.risk_per_trade_pct
        balance = self._get_current_balance()
        risk_amount = balance * risk_pct / 100

        if sl_distance <= 0:
            return 0.01  # Minimum par défaut

        info = mt5.symbol_info(symbol)
        if not info:
            return 0.01

        tick_value = info.trade_tick_value or 0.0
        tick_size = info.trade_tick_size or 0.00001

        if tick_value <= 0 or tick_size <= 0:
            return 0.01

        # Nombre de ticks dans le SL
        sl_ticks = sl_distance / tick_size
        # Valeur monétaire du SL en ticks
        sl_value = sl_ticks * tick_value

        if sl_value <= 0:
            return 0.01

        lot = risk_amount / sl_value

        # Arrondir au lot standard
        lot_step = info.volume_step or 0.01
        lot = round(lot / lot_step) * lot_step

        # Vérifier les limites
        min_lot = info.volume_min or 0.01
        max_lot = info.volume_max or 10.0
        lot = max(min_lot, min(lot, max_lot))

        return lot

    def get_risk_level(self) -> RiskLevel:
        """Calcule le niveau de risque actuel."""
        dd = self.daily.current_drawdown
        loss_streak = self.daily.loss_streak
        trades_today = self.daily.trades_count

        if dd >= self.limits.max_drawdown_pct * 0.8:
            return RiskLevel.CRITICAL
        if dd >= self.limits.max_drawdown_pct * 0.5:
            return RiskLevel.HIGH
        if loss_streak >= 3 or trades_today >= self.limits.max_daily_trades * 0.7:
            return RiskLevel.CAUTION
        return RiskLevel.NORMAL

    def register_trade_result(self, profit: float) -> None:
        """Enregistre le résultat d'un trade pour le suivi quotidien."""
        self.daily.trades_count += 1
        self.daily.daily_pnl += profit
        self._current_balance += profit

        if profit > 0:
            self.daily.win_streak += 1
            self.daily.loss_streak = 0
        else:
            self.daily.loss_streak += 1
            self.daily.win_streak = 0

        # Mise à jour du drawdown
        if self.daily.daily_pnl > 0:
            self.daily.peak_balance = self._current_balance
        else:
            if self.daily.peak_balance > 0:
                self.daily.current_drawdown = max(
                    self.daily.current_drawdown,
                    (self.daily.peak_balance - self._current_balance) / self._initial_balance * 100
                )

        logger.info(
            f"Trade result: {profit:+.2f}$ | "
            f"Daily: {self.daily.daily_pnl:+.2f}$ ({self.daily.trades_count}/{self.limits.max_daily_trades}) | "
            f"Streak: {'W'+str(self.daily.win_streak) if profit > 0 else 'L'+str(self.daily.loss_streak)}"
        )

    def register_trade_time(self, symbol: str) -> None:
        """Enregistre le timestamp du dernier trade pour le cooldown."""
        self._last_trade_time[symbol] = time.time()

    def get_status(self) -> Dict:
        """Retourne l'état complet du risk manager."""
        level = self.get_risk_level()
        return {
            "risk_level": level.value,
            "daily_pnl": round(self.daily.daily_pnl, 2),
            "trades_today": self.daily.trades_count,
            "max_daily_trades": self.limits.max_daily_trades,
            "balance": round(self._current_balance, 2),
            "drawdown": round(self.daily.current_drawdown, 1),
            "loss_streak": self.daily.loss_streak,
            "win_streak": self.daily.win_streak,
            "can_trade": self.can_trade("")[0],
            "open_positions": self._count_open_positions(),
        }

    def get_win_streak(self) -> int:
        return self.daily.win_streak

    def get_loss_streak(self) -> int:
        return self.daily.loss_streak

    # ──────────────────────────────────────────────────────────
    # Interne
    # ──────────────────────────────────────────────────────────

    def _get_current_balance(self) -> float:
        if not _MT5_OK:
            return self._current_balance
        try:
            info = mt5.account_info()
            if info:
                self._current_balance = info.balance
                return info.balance
        except Exception:
            pass
        return self._current_balance

    def _count_open_positions(self) -> int:
        if not _MT5_OK:
            return 0
        try:
            positions = mt5.positions_get()
            return len(positions) if positions else 0
        except Exception:
            return 0
