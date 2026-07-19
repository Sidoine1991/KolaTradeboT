"""
Bridge — Intégration du Core Engine avec le système existant
===============================================================

Points d'intégration:
  - Agents: expose core engine outputs aux agents existants
  - AI Server: endpoints REST pour les données core
  - Dashboard: données temps réel pour l'UI
  - WhatsApp: notifs enrichies via le NotificationManager
"""

import time
import logging
from typing import Dict, List, Optional, Any

from .engine import TradingEngine, EngineConfig
from .order_manager import OrderManager, OrderRequest, OrderDirection
from .chart_patterns import ChartPatternManager, DetectedPattern, PatternType
from .gom_handler import GOMHandler, GOMSignal
from .risk_manager import RiskManager
from .notification import NotificationManager, EventType

logger = logging.getLogger("tradbot.bridge")

# Singleton
_engine: Optional[TradingEngine] = None


def get_engine(phone: str = "", auto_start: bool = False) -> TradingEngine:
    """Retourne l'instance unique du moteur."""
    global _engine
    if _engine is None:
        _engine = TradingEngine(phone=phone)
        if auto_start:
            _engine.start()
    return _engine


class CoreBridge:
    """
    Pont entre le Core Engine et le système existant (agents, ai_server).

    Méthodes appelables depuis:
      - agents/ (orchestrator, agents individuels)
      - ai_server.py (endpoints REST)
      - dashboard.py (données temps réel)
    """

    def __init__(self, engine: TradingEngine):
        self.engine = engine

    # ──────────────────────────────────────────────────────────
    # API pour les agents existants
    # ──────────────────────────────────────────────────────────

    def get_pattern_context(self, symbol: str) -> Dict:
        """
        Retourne le contexte patterns SMC pour un symbole.
        Utilisé par agent_timing.py et agent_pattern.py.
        """
        pm = self.engine.pattern_manager

        summary = pm.get_pattern_summary(symbol)

        # Scanner si pas de données récentes
        last_scan = pm._last_scan.get(symbol, 0)
        if time.time() - last_scan > 60:
            try:
                pm.scan_symbol(symbol, "M15")
                summary = pm.get_pattern_summary(symbol)
            except Exception:
                pass

        return summary

    def get_combined_signal(self, symbol: str) -> Dict:
        """
        Signal combiné GOM + patterns SMC.
        Utilisé pour la prise de décision finale.
        """
        signal = self.engine.gom_handler.get_signal(symbol)
        if not signal:
            return {"symbol": symbol, "actionable": False, "reason": "No signal"}

        return {
            "symbol": symbol,
            "actionable": signal.signal_strength >= self.engine.config.min_signal_strength,
            "direction": signal.direction,
            "strength": round(signal.signal_strength, 2),
            "verdict": signal.verdict.verdict,
            "coherence": round(signal.verdict.coherence_pct, 1),
            "patterns": [p.to_dict() for p in signal.patterns],
            "entry": signal.entry,
            "sl": signal.sl,
            "tp": signal.tp,
            "reason": signal.reason,
        }

    def get_all_signals(self) -> List[Dict]:
        """Tous les signaux pour le dashboard."""
        if not self.engine._last_signals:
            self.engine.gom_handler.refresh()
        return [
            {"symbol": s.symbol, "direction": s.direction,
             "strength": round(s.signal_strength, 2),
             "verdict": s.verdict.verdict,
             "coherence": round(s.verdict.coherence_pct, 1),
             "patterns": len(s.patterns),
             "entry": s.entry, "sl": s.sl, "tp": s.tp,
             "reason": s.reason}
            for s in self.engine._last_signals
        ]

    def get_risk_context(self) -> Dict:
        """Contexte risque pour agent_risk.py."""
        return self.engine.risk_manager.get_status()

    def get_order_context(self) -> Dict:
        """Contexte ordres pour le dashboard et agents."""
        return {
            "positions": self.engine.order_manager.get_open_positions(),
            "orders_history": self.engine.order_manager.get_orders_history(10),
            "active_tickets": self.engine._active_tickets,
        }

    # ──────────────────────────────────────────────────────────
    # API pour l'AI Server (endpoints REST)
    # ──────────────────────────────────────────────────────────

    def api_scan_patterns(self, symbol: str, timeframe: str = "M15") -> Dict:
        """Endpoint /api/core/scan-patterns."""
        try:
            patterns = self.engine.pattern_manager.scan_symbol(symbol, timeframe)
            return {
                "ok": True,
                "symbol": symbol,
                "timeframe": timeframe,
                "patterns": [p.to_dict() for p in patterns],
                "summary": self.engine.pattern_manager.get_pattern_summary(symbol),
            }
        except Exception as e:
            return {"ok": False, "error": str(e)}

    def api_get_signals(self) -> Dict:
        """Endpoint /api/core/signals."""
        return {
            "ok": True,
            "signals": self.get_all_signals(),
            "risk": self.engine.risk_manager.get_status(),
        }

    def api_place_order(self, params: Dict) -> Dict:
        """Endpoint /api/core/place-order."""
        try:
            symbol = params.get("symbol", "")
            direction = params.get("direction", "BUY")
            volume = float(params.get("volume", 0.01))
            sl = params.get("sl")
            tp = params.get("tp")

            req = OrderRequest(
                symbol=symbol,
                direction=OrderDirection.BUY if direction.upper() == "BUY" else OrderDirection.SELL,
                volume=volume,
                stop_loss=float(sl) if sl else None,
                take_profit=float(tp) if tp else None,
                comment=params.get("comment", "api_order"),
            )

            result = self.engine.order_manager.market_order(req)
            return {
                "ok": result.success,
                "ticket": result.ticket,
                "price": result.price,
                "error": result.error,
            }
        except Exception as e:
            return {"ok": False, "error": str(e)}

    def api_close_position(self, symbol: str) -> Dict:
        """Endpoint /api/core/close-position."""
        ticket = self.engine._active_tickets.get(symbol)
        if not ticket:
            return {"ok": False, "error": f"No active ticket for {symbol}"}

        ok = self.engine.order_manager.close_position(ticket)
        if ok:
            self.engine._active_tickets.pop(symbol, None)
        return {"ok": ok, "ticket": ticket}

    def api_engine_status(self) -> Dict:
        """Endpoint /api/core/status."""
        return {
            "ok": True,
            "status": self.engine.get_status(),
        }

    def api_risk_status(self) -> Dict:
        """Endpoint /api/core/risk."""
        return {"ok": True, **self.engine.risk_manager.get_status()}

    # ──────────────────────────────────────────────────────────
    # Nouveaux endpoints dashboard
    # ──────────────────────────────────────────────────────────

    def api_opportunities(self) -> Dict:
        """Top opportunités classées — signaux exploitables GOM+patterns."""
        signals = self.engine.gom_handler.get_actionable_signals()
        return {
            "ok": True,
            "opportunities": [
                {
                    "symbol": s.symbol,
                    "direction": s.direction,
                    "strength": round(s.signal_strength, 2),
                    "verdict": s.verdict.verdict,
                    "coherence": round(s.verdict.coherence_pct, 1),
                    "verts_num": s.verdict.verts_num,
                    "entry": s.entry,
                    "sl": s.sl,
                    "tp": s.tp,
                    "reason": s.reason,
                    "patterns": [p.to_dict() for p in s.patterns],
                    "has_position": s.symbol in self.engine._active_tickets,
                }
                for s in signals
            ],
            "total": len(signals),
            "timestamp": time.time(),
        }

    def api_symbol_deep(self, symbol: str) -> Dict:
        """Vue détaillée d'un symbole: patterns, GOM, risque, recommandation."""
        verdict = self.engine.gom_handler.get_verdict(symbol)
        signal = self.engine.gom_handler.get_signal(symbol)
        pm = self.engine.pattern_manager
        summary = pm.get_pattern_summary(symbol)

        # Scanner si périmé
        last = pm._last_scan.get(symbol, 0)
        if time.time() - last > 120:
            try:
                pm.scan_symbol(symbol, "M15")
                summary = pm.get_pattern_summary(symbol)
            except Exception:
                pass

        active_patterns = [p.to_dict() for p in pm._detected_patterns
                           if p.symbol == symbol and p.is_active]

        risk_status = self.engine.risk_manager.get_status()
        has_position = symbol in self.engine._active_tickets
        position_info = None
        if has_position:
            for p in self.engine.order_manager.get_open_positions():
                if p.get("symbol") == symbol:
                    position_info = p
                    break

        return {
            "ok": True,
            "symbol": symbol,
            "verdict": verdict.to_dict() if verdict else {"verdict": "WAIT"},
            "signal": {
                "strength": round(signal.signal_strength, 2),
                "direction": signal.direction,
                "entry": signal.entry,
                "sl": signal.sl,
                "tp": signal.tp,
                "reason": signal.reason,
            } if signal else None,
            "patterns": {
                "active": active_patterns,
                "summary": summary,
            },
            "risk": risk_status,
            "position": position_info,
            "has_position": has_position,
            "trailing": list(self.engine._trail_levels.keys()),
            "trailing_config": {
                "activation_pips": self.engine.config.trailing_activation_pips,
                "distance_pips": self.engine.config.trailing_distance_pips,
                "step_pips": self.engine.config.trailing_step_pips,
            },
            "timestamp": time.time(),
        }

    def api_multi_timeframe(self, symbol: str,
                             timeframes: Optional[List[str]] = None) -> Dict:
        """Analyse multi-timeframe d'un symbole."""
        if timeframes is None:
            timeframes = ["M5", "M15", "H1"]
        results = {}
        pm = self.engine.pattern_manager
        for tf in timeframes:
            try:
                patterns = pm.scan_symbol(symbol, tf)
                results[tf] = {
                    "patterns": [p.to_dict() for p in patterns],
                    "summary": pm.get_pattern_summary(symbol),
                }
            except Exception as e:
                results[tf] = {"error": str(e)}
        # Synthèse multi-TF
        directions = []
        for tf_data in results.values():
            s = tf_data.get("summary", {})
            d = s.get("overall_direction", "")
            if d:
                directions.append(d)
        bullish = sum(1 for d in directions if d == "BULLISH")
        bearish = sum(1 for d in directions if d == "BEARISH")

        return {
            "ok": True,
            "symbol": symbol,
            "timeframes": timeframes,
            "results": results,
            "synthesis": {
                "bullish_tfs": bullish,
                "bearish_tfs": bearish,
                "consensus": "BULLISH" if bullish > bearish else "BEARISH" if bearish > bullish else "NEUTRAL",
            },
            "timestamp": time.time(),
        }

    def api_positions(self) -> Dict:
        """Positions ouvertes avec PnL en temps réel + trailing status."""
        positions = self.engine.order_manager.get_open_positions()
        account = self.engine.order_manager.get_account_info()
        total_pnl = sum(float(p.get("profit", 0)) for p in positions)

        # Enrichir avec les niveaux trailés
        enriched = []
        for p in positions:
            ticket = p.get("ticket", 0)
            trailed_sl = self.engine._trail_levels.get(ticket)
            p["trailed_sl"] = trailed_sl
            p["is_trailing"] = trailed_sl is not None
            enriched.append(p)

        return {
            "ok": True,
            "positions": enriched,
            "total_pnl": round(total_pnl, 2),
            "total_positions": len(positions),
            "trailing_active": len(self.engine._trail_levels),
            "account": account,
            "timestamp": time.time(),
        }

    def api_portfolio(self) -> Dict:
        """Snapshot complet du portfolio: risque + positions + signaux."""
        signals = self.engine._last_signals
        return {
            "ok": True,
            "portfolio": {
                "risk": self.engine.risk_manager.get_status(),
                "positions": self.engine.order_manager.get_open_positions(),
                "account": self.engine.order_manager.get_account_info(),
                "active_signals": len(signals),
                "best_signals": [
                    {"symbol": s.symbol, "direction": s.direction,
                     "strength": round(s.signal_strength, 2), "verdict": s.verdict.verdict}
                    for s in (signals or [])[:5]
                ],
            },
            "timestamp": time.time(),
        }

    def api_order_history(self, limit: int = 20) -> Dict:
        """Historique des ordres récents."""
        return {
            "ok": True,
            "orders": self.engine.order_manager.get_orders_history(limit),
            "count": limit,
            "timestamp": time.time(),
        }

    def api_trail_config(self) -> Dict:
        """Toutes les configs trailing (globale + par symbole)."""
        return {
            "ok": True,
            "default": {
                "activation_pips": self.engine.config.trailing_activation_pips,
                "distance_pips": self.engine.config.trailing_distance_pips,
                "step_pips": self.engine.config.trailing_step_pips,
            },
            "per_symbol": {
                sym: cfg.to_dict()
                for sym, cfg in self.engine._trail_configs.items()
            },
        }

    def api_set_trail_config(self, symbol: str, activation: Optional[float] = None,
                             distance: Optional[float] = None,
                             step: Optional[float] = None) -> Dict:
        """Définit la config trailing pour un symbole."""
        cfg = self.engine.set_trail_config(symbol, activation, distance, step)
        return {
            "ok": True,
            "symbol": symbol,
            "config": cfg.to_dict(),
            "effective": self.engine.get_effective_trail_params(symbol),
        }

    def api_delete_trail_config(self, symbol: str) -> Dict:
        """Reset la config trailing d'un symbole (→ défaut moteur)."""
        ok = self.engine.remove_trail_config(symbol)
        return {
            "ok": ok,
            "symbol": symbol,
            "effective": self.engine.get_effective_trail_params(symbol),
        }

    # ──────────────────────────────────────────────────────────
    # API pour l'intégration agents existants
    # ──────────────────────────────────────────────────────────

    def enrich_verdict_with_patterns(self, verdicts: List[Dict]) -> List[Dict]:
        """
        Enrichit les verdicts GOM avec les patterns SMC.
        Utilisé par l'orchestrateur d'agents (orchestrator.py).
        """
        enriched = []
        for v in verdicts:
            symbol = v.get("symbol", "")
            signal = self.engine.gom_handler.get_signal(symbol)
            if signal:
                v["patterns"] = [p.to_dict() for p in signal.patterns]
                v["signal_strength"] = round(signal.signal_strength, 2)
                v["combined_direction"] = signal.direction
            enriched.append(v)
        return enriched
