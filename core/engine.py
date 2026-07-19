"""
Trading Engine — Orchestrateur central du système TradBOT Core
================================================================

Lie tous les modules core entre eux et avec le système d'agents existant.

Cycle de trading:
  1) Poll les verdicts GOM (GOMHandler)
  2) Scanne les patterns SMC (ChartPatternManager)
  3) Combine GOM + patterns → signaux exploitables
  4) Valide les risques (RiskManager)
  5) Exécute les ordres (OrderManager)
  6) Envoie les notifications (NotificationManager)
  7) Ferme les positions si verdict passé à WAIT
"""

import time
import logging
import threading
from typing import Dict, List, Optional, Any
from datetime import datetime, timezone
from dataclasses import dataclass

try:
    import MetaTrader5 as mt5
    _MT5_OK = True
except ImportError:
    mt5 = None
    _MT5_OK = False

from .order_manager import OrderManager, OrderRequest, OrderDirection, OrderResult
from .chart_patterns import ChartPatternManager, DetectedPattern, PatternType
from .gom_handler import GOMHandler, GOMSignal, GOMVerdict
from .risk_manager import RiskManager, RiskLevel
from .notification import NotificationManager, Notification, EventType
from .exceptions import OrderError, InvalidStopsError, PositionLimitError

logger = logging.getLogger("tradbot.engine")


@dataclass
class TrailingSymbolConfig:
    """Configuration trailing spécifique à un symbole (None = utiliser le défaut moteur)."""
    activation_pips: Optional[float] = None
    distance_pips: Optional[float] = None
    step_pips: Optional[float] = None

    def effective(self, default_cfg: "EngineConfig") -> dict:
        """Retourne les paramètres effectifs (symbolique ou défaut)."""
        return {
            "activation_pips": self.activation_pips if self.activation_pips is not None else default_cfg.trailing_activation_pips,
            "distance_pips": self.distance_pips if self.distance_pips is not None else default_cfg.trailing_distance_pips,
            "step_pips": self.step_pips if self.step_pips is not None else default_cfg.trailing_step_pips,
        }

    def to_dict(self) -> Dict:
        return {
            "activation_pips": self.activation_pips,
            "distance_pips": self.distance_pips,
            "step_pips": self.step_pips,
        }


@dataclass
class EngineConfig:
    """Configuration du moteur de trading."""
    scan_interval: float = 15.0           # Intervalle de scan (secondes)
    gom_min_coherence: float = 70.0       # Cohérence min GOM
    require_pattern_alignment: bool = True  # Patterns SMC requis
    min_signal_strength: float = 0.5      # Force de signal minimum
    enable_auto_close: bool = True        # Fermeture auto sur WAIT
    enable_auto_trade: bool = True        # Trading automatique
    max_spread_multiplier: float = 3.0    # Spread max x normal
    default_lot: float = 0.01             # Lot par défaut
    # Trailing stop
    trailing_activation_pips: float = 5.0   # Profit mini (pips) pour activer le trailing
    trailing_distance_pips: float = 3.0     # Distance SL sous le prix courant (pips)
    trailing_step_pips: float = 1.0         # Pas min de déplacement du SL (pips)


class TradingEngine:
    """
    Moteur de trading principal.

    Usage:
        engine = TradingEngine(phone="+229XXXXXXXX")
        engine.start()

        # En boucle, engine.run_cycle() est appelé automatiquement
    """

    def __init__(self, phone: str = "", config: Optional[EngineConfig] = None):
        self.config = config or EngineConfig()

        # Modules core
        self.pattern_manager = ChartPatternManager()
        self.gom_handler = GOMHandler(self.pattern_manager)
        self.order_manager = OrderManager()
        self.risk_manager = RiskManager()
        self.notifier = NotificationManager(phone=phone)

        # État
        self._running = False
        self._thread: Optional[threading.Thread] = None
        self._stop_event = threading.Event()
        self._cycle_count = 0
        self._last_positions: Dict[str, int] = {}  # symbol → ticket
        self._last_signals: List[GOMSignal] = []
        self._active_tickets: Dict[str, int] = {}  # symbol → ticket
        self._ticket_symbol: Dict[int, str] = {}  # ticket → symbol (reverse lookup)
        self._trail_levels: Dict[int, float] = {}  # ticket → dernier SL trailé
        self._trail_configs: Dict[str, TrailingSymbolConfig] = {}  # symbol → config perso

    # ──────────────────────────────────────────────────────────
    # Lifecycle
    # ──────────────────────────────────────────────────────────

    def start(self) -> None:
        """Démarre le moteur en arrière-plan."""
        if self._thread and self._thread.is_alive():
            logger.warning("Engine already running")
            return
        self._stop_event.clear()
        self._thread = threading.Thread(target=self._loop, daemon=True,
                                        name="tradbot-engine")
        self._thread.start()
        self._running = True
        logger.info(f"🚀 TradBOT Engine started (interval={self.config.scan_interval}s)")

    def stop(self) -> None:
        """Arrête le moteur."""
        self._stop_event.set()
        self._running = False
        logger.info("🛑 TradBOT Engine stopped")

    def run_once(self) -> Dict:
        """Exécute un cycle complet de trading. Retourne le rapport."""
        t0 = time.time()
        self._cycle_count += 1
        report = {
            "cycle": self._cycle_count,
            "timestamp": time.time(),
            "signals": [],
            "orders": [],
            "closes": [],
            "errors": [],
        }

        try:
            # 1. Rafraîchir les verdicts GOM et patterns
            signals = self.gom_handler.refresh()
            self._last_signals = signals

            # 2. Fermer les positions quand GOM passe à WAIT
            if self.config.enable_auto_close:
                closes = self._check_closes()
                report["closes"] = closes

            # 2.5 Trailing stop — sécuriser les gains
            trail_count = self._update_trailing_stops()
            report["trail_updates"] = trail_count

            # 3. Obtenir les signaux exploitables
            actionable = self.gom_handler.get_actionable_signals(
                min_coherence=self.config.gom_min_coherence,
                require_alignment=self.config.require_pattern_alignment
            )

            # 4. Filtrer par force de signal
            actionable = [s for s in actionable
                         if s.signal_strength >= self.config.min_signal_strength]

            report["signals"] = [
                {"symbol": s.symbol, "direction": s.direction,
                 "strength": round(s.signal_strength, 2),
                 "reason": s.reason}
                for s in actionable
            ]

            # 5. Exécuter les trades
            if self.config.enable_auto_trade:
                orders = self._execute_signals(actionable)
                report["orders"] = orders

        except Exception as e:
            logger.exception(f"Cycle error: {e}")
            report["errors"].append(str(e))

        report["duration_ms"] = round((time.time() - t0) * 1000, 1)
        return report

    def get_status(self) -> Dict:
        """Retourne l'état complet du moteur."""
        return {
            "running": self._running,
            "cycle": self._cycle_count,
            "config": {
                "scan_interval": self.config.scan_interval,
                "gom_min_coherence": self.config.gom_min_coherence,
                "require_pattern_alignment": self.config.require_pattern_alignment,
                "auto_trade": self.config.enable_auto_trade,
                "auto_close": self.config.enable_auto_close,
                "trailing": {
                    "activation_pips": self.config.trailing_activation_pips,
                    "distance_pips": self.config.trailing_distance_pips,
                    "step_pips": self.config.trailing_step_pips,
                },
            },
            "risk": self.risk_manager.get_status(),
            "active_positions": self.order_manager.get_open_positions(),
            "account": self.order_manager.get_account_info(),
            "active_signals": [
                {"symbol": s.symbol, "direction": s.direction,
                 "strength": round(s.signal_strength, 2),
                 "verdict": s.verdict.verdict,
                 "coherence": round(s.verdict.coherence_pct, 1)}
                for s in self._last_signals[:10]
            ],
            "trail_configs": {
                sym: tc.to_dict() for sym, tc in self._trail_configs.items()
            },
        }

    # ──────────────────────────────────────────────────────────
    # Trailing config per-symbol
    # ──────────────────────────────────────────────────────────

    def set_trail_config(self, symbol: str, activation: Optional[float] = None,
                         distance: Optional[float] = None,
                         step: Optional[float] = None) -> "TrailingSymbolConfig":
        """Définit la config trailing pour un symbole."""
        cfg = self._trail_configs.get(symbol, TrailingSymbolConfig())
        if activation is not None:
            cfg.activation_pips = activation
        if distance is not None:
            cfg.distance_pips = distance
        if step is not None:
            cfg.step_pips = step
        self._trail_configs[symbol] = cfg
        logger.info(f"Trailing config {symbol}: {cfg.to_dict()}")
        return cfg

    def get_trail_config(self, symbol: str) -> TrailingSymbolConfig:
        """Retourne la config trailing pour un symbole (ou config vide)."""
        return self._trail_configs.get(symbol, TrailingSymbolConfig())

    def remove_trail_config(self, symbol: str) -> bool:
        """Supprime la config perso → retour aux valeurs par défaut."""
        if symbol in self._trail_configs:
            del self._trail_configs[symbol]
            logger.info(f"Trailing config {symbol}: reset to default")
            return True
        return False

    def get_effective_trail_params(self, symbol: str) -> Dict:
        """Paramètres trailing effectifs pour un symbole."""
        cfg = self.get_trail_config(symbol)
        return cfg.effective(self.config)

    # ──────────────────────────────────────────────────────────
    # Cycle interne
    # ──────────────────────────────────────────────────────────

    def _loop(self) -> None:
        """Boucle principale du moteur."""
        while not self._stop_event.is_set():
            try:
                report = self.run_once()
                if report.get("orders"):
                    logger.info(f"Cycle #{self._cycle_count}: "
                                f"{len(report['orders'])} ordres, "
                                f"{len(report['closes'])} fermetures, "
                                f"{report['duration_ms']}ms")
            except Exception as e:
                logger.exception(f"Engine loop error: {e}")
            self._stop_event.wait(timeout=self.config.scan_interval)

    def _execute_signals(self, signals: List[GOMSignal]) -> List[Dict]:
        """Exécute les signaux exploitables."""
        orders = []
        for sig in signals:
            # Vérifier qu'on n'a pas déjà une position
            if self.order_manager.has_open_position(sig.symbol):
                logger.debug(f"Déjà en position sur {sig.symbol}, skip")
                continue

            # Vérifier les risques
            can_trade, reason = self.risk_manager.can_trade(sig.symbol)
            if not can_trade:
                logger.info(f"Risk gate: {sig.symbol} — {reason}")
                self.notifier.send_whatsapp(
                    f"⛔ Trade bloqué {sig.symbol}",
                    reason,
                    EventType.RISK_WARNING, sig.symbol, priority=1
                )
                continue

            # Vérifier le spread
            if not self._check_spread(sig.symbol):
                logger.warning(f"Spread trop large: {sig.symbol}")
                continue

            # Calculer la taille de position
            entry = sig.entry or sig.verdict.price or 0
            sl = sig.sl or 0
            sl_distance = abs(entry - sl) if entry and sl else 0
            lot = self.risk_manager.get_position_size(sig.symbol, sl_distance)

            direction = OrderDirection.BUY if sig.direction == "BUY" else OrderDirection.SELL

            req = OrderRequest(
                symbol=sig.symbol,
                direction=direction,
                volume=lot,
                entry_price=entry,
                stop_loss=sl,
                take_profit=sig.tp,
                comment=f"gom_{sig.verdict.verdict}_{int(time.time())}",
                magic=1001,
            )

            result = self.order_manager.market_order(req)

            if result.success:
                self.risk_manager.register_trade_time(sig.symbol)
                self._active_tickets[sig.symbol] = result.ticket
                self._ticket_symbol[result.ticket] = sig.symbol
                orders.append({
                    "symbol": sig.symbol,
                    "direction": sig.direction,
                    "ticket": result.ticket,
                    "price": result.price,
                    "sl": result.sl,
                    "tp": result.tp,
                    "lot": lot,
                })

                pattern_summary = ", ".join(
                    f"{p.pattern_type.value}" for p in sig.patterns[:3]
                ) if sig.patterns else "aucun"

                self.notifier.send_whatsapp(
                    f"✅ {sig.direction} {sig.symbol}",
                    f"Entrée @ {result.price:.5f} | "
                    f"SL={result.sl:.5f} TP={result.tp:.5f} | "
                    f"Lot={lot:.2f} | "
                    f"GOM={sig.verdict.verdict}({sig.verdict.coherence_pct:.0f}%) | "
                    f"Patterns=[{pattern_summary}] "
                    f"Force={sig.signal_strength:.0%}",
                    EventType.ORDER_PLACED, sig.symbol, priority=2
                )
            else:
                orders.append({
                    "symbol": sig.symbol,
                    "error": result.error,
                    "success": False,
                })
                self.notifier.send_whatsapp(
                    f"❌ Échec {sig.direction} {sig.symbol}",
                    result.error[:200],
                    EventType.ORDER_FAILED, sig.symbol, priority=2
                )

        return orders

    def _check_closes(self) -> List[Dict]:
        """Vérifie et ferme les positions sur verdict WAIT."""
        closes = []
        for symbol, ticket in list(self._active_tickets.items()):
            if self.gom_handler.should_close(symbol):
                # Vérifier que la position est toujours ouverte
                if not self.order_manager.has_open_position(symbol):
                    self._active_tickets.pop(symbol, None)
                    continue

                ok = self.order_manager.close_position(ticket)
                if ok:
                    closes.append({"symbol": symbol, "ticket": ticket, "reason": "GOM WAIT"})
                    self._active_tickets.pop(symbol, None)
                    self._trail_levels.pop(ticket, None)
                    self._ticket_symbol.pop(ticket, None)
                    self.notifier.send_whatsapp(
                        f"🔒 Fermeture {symbol}",
                        f"GOM passé à WAIT — position #{ticket} fermée",
                        EventType.ORDER_CLOSED, symbol, priority=1
                    )
                else:
                    logger.warning(f"Échec fermeture {symbol} ticket={ticket}")
        return closes

    def _update_trailing_stops(self) -> int:
        """Déplace le SL des positions en profit via OrderManager."""
        updates = 0
        positions = {p.get("ticket", 0): p
                     for p in self.order_manager.get_open_positions()}

        for symbol, ticket in list(self._active_tickets.items()):
            try:
                pos = positions.get(ticket)
                if not pos:
                    self._active_tickets.pop(symbol, None)
                    self._trail_levels.pop(ticket, None)
                    continue

                sinfo = self.order_manager.get_symbol_info(symbol)
                if not sinfo:
                    continue
                point = sinfo["point"]
                digits = sinfo["digits"]

                is_buy = pos.get("type", "").lower() == "buy"
                open_price = float(pos.get("price_open", 0))
                current_price = float(pos.get("price_current", 0))
                current_sl = float(pos.get("sl", 0))
                current_tp = float(pos.get("tp", 0))

                profit_pips = ((current_price - open_price) / point
                               if is_buy
                               else (open_price - current_price) / point)

                trail_params = self.get_effective_trail_params(symbol)
                activation = trail_params["activation_pips"]

                if profit_pips < activation:
                    continue

                distance = trail_params["distance_pips"] * point
                new_sl = (current_price - distance if is_buy
                          else current_price + distance)
                new_sl = round(new_sl, digits)

                min_step = trail_params["step_pips"] * point
                last_trail = self._trail_levels.get(ticket, 0.0)

                if is_buy:
                    if new_sl <= current_sl:
                        continue
                    if last_trail > 0 and (new_sl - last_trail) < min_step:
                        continue
                else:
                    if new_sl >= current_sl:
                        continue
                    if last_trail > 0 and (last_trail - new_sl) < min_step:
                        continue

                ok = self.order_manager.modify_position_sl_tp(
                    ticket, new_sl, current_tp
                )
                if ok:
                    self._trail_levels[ticket] = new_sl
                    updates += 1
                    logger.info(f"Trailing {symbol} ticket={ticket}: SL→{new_sl}")
                    # Notifier seulement au premier trailing de la position
                    if last_trail == 0:
                        self.notifier.send_whatsapp(
                            f"📈 Trailing activé {symbol}",
                            f"SL trailé @ {new_sl} | Actif={activation}pips Dist={trail_params['distance_pips']}pips",
                            EventType.ORDER_MODIFIED, symbol, priority=2
                        )
            except Exception as e:
                logger.debug(f"Trailing error {symbol}: {e}")
        return updates

    def _check_spread(self, symbol: str) -> bool:
        """Vérifie que le spread est acceptable."""
        if not _MT5_OK:
            return True
        try:
            info = mt5.symbol_info(symbol)
            if not info:
                return False
            tick = mt5.symbol_info_tick(symbol)
            if not tick:
                return False
            spread = (tick.ask - tick.bid) / info.point if info.point > 0 else 0
            avg_spread = getattr(info, "spread", 0) or 1
            if avg_spread > 0 and spread > avg_spread * self.config.max_spread_multiplier:
                logger.warning(f"Spread excessif {symbol}: {spread} (avg={avg_spread})")
                return False
            return True
        except Exception:
            return True

    # ──────────────────────────────────────────────────────────
    # Utilitaires (export pour agents existants)
    # ──────────────────────────────────────────────────────────

    def get_unified_intel(self) -> Dict:
        """Export unifié pour le système d'agents existant."""
        risk_status = self.risk_manager.get_status()
        return {
            "ts": time.time(),
            "risk": risk_status,
            "signals": [
                {"symbol": s.symbol, "direction": s.direction,
                 "strength": round(s.signal_strength, 2),
                 "verdict": s.verdict.verdict,
                 "patterns": [p.to_dict() for p in s.patterns]}
                for s in self._last_signals[:10]
            ],
            "positions": self.order_manager.get_open_positions(),
            "account": self.order_manager.get_account_info(),
        }
