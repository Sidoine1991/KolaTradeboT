"""
TradBOT Agent Orchestrator
Manages all 6 intelligence agents, their lifecycle, and produces
a unified intelligence report consumed by the dashboard and ai_server.

Peer wiring: each agent gets references to all others so they can
read peer outputs directly during their analyze() cycle.

WhatsApp loop: auto-sends the unified report every WHATSAPP_INTERVAL_H hours.
"""

import os
import time
import threading
import logging
import requests
from typing import Dict, Any, List, Optional

from .agent_correlation import SymbolCorrelationAgent
from .agent_regime import MarketRegimeAgent
from .agent_risk import RiskOptimizerAgent
from .agent_timing import EntryTimingAgent
from .agent_pattern import PatternEvolutionAgent
from .agent_news import MacroFilterAgent
from .agent_trading_agents import TradingAgentsDeepAnalyst

logger = logging.getLogger("tradbot.orchestrator")

# WhatsApp report config
_PSYCHOBOT   = os.getenv("PSYCHOBOT_URL", "https://psychobot-1si7.onrender.com")
_PHONE       = os.getenv("WHATSAPP_PHONE") or os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")
_WA_INTERVAL = int(os.getenv("AGENTS_REPORT_INTERVAL_H", "3")) * 3600  # default 3h


class AgentOrchestrator:
    """Central manager for all intelligence agents."""

    def __init__(self):
        self.agents = {
            "correlation":     SymbolCorrelationAgent(),
            "regime":          MarketRegimeAgent(),
            "risk":            RiskOptimizerAgent(),
            "timing":          EntryTimingAgent(),
            "pattern":         PatternEvolutionAgent(),
            "news":            MacroFilterAgent(),
            "trading_agents":  TradingAgentsDeepAnalyst(),
        }
        self._lock = threading.Lock()
        self._unified_report: Dict = {}
        self._last_unified_ts: float = 0.0
        self._wa_thread: Optional[threading.Thread] = None
        self._wa_stop = threading.Event()
        # Wire peer references so agents can read each other
        self._wire_peers()

    def _wire_peers(self) -> None:
        """Give every agent a reference to all other agents."""
        for agent in self.agents.values():
            agent.register_peers(self.agents)
        logger.info("Agent peer wiring complete (%d agents cross-linked)", len(self.agents))

    # ------------------------------------------------------------------
    # Lifecycle
    # ------------------------------------------------------------------

    def start_all(self):
        """Launch all agents as background daemon threads + WhatsApp loop."""
        for agent in self.agents.values():
            agent.start_background()
        logger.info("All %d agents started", len(self.agents))
        self._start_whatsapp_loop()

    def _start_whatsapp_loop(self) -> None:
        """Send a WhatsApp intelligence report every AGENTS_REPORT_INTERVAL_H hours."""
        if self._wa_thread and self._wa_thread.is_alive():
            return
        self._wa_stop.clear()
        self._wa_thread = threading.Thread(
            target=self._whatsapp_loop_guarded, daemon=True, name="agents-wa-report"
        )
        self._wa_thread.start()
        logger.info("WhatsApp report loop started (every %dh)", _WA_INTERVAL // 3600)

    def _whatsapp_loop_guarded(self) -> None:
        """Wrapper that auto-restarts the loop if it crashes."""
        while not self._wa_stop.is_set():
            try:
                self._whatsapp_loop()
            except Exception as exc:
                logger.error("WhatsApp loop crash inattendu: %s — redémarrage dans 60s", exc)
                self._wa_stop.wait(timeout=60)

    def stop_all(self):
        self._wa_stop.set()
        for agent in self.agents.values():
            agent.stop()

    # ------------------------------------------------------------------
    # WhatsApp report loop
    # ------------------------------------------------------------------

    def _whatsapp_loop(self) -> None:
        # Short warm-up so agents have at least one cycle of data before first send
        _WARMUP = min(120, _WA_INTERVAL)
        self._wa_stop.wait(timeout=_WARMUP)
        while not self._wa_stop.is_set():
            try:
                report = self._build_whatsapp_report()
                self._send_whatsapp(report)
            except Exception as exc:
                logger.warning("WhatsApp report failed: %s", exc)
            self._wa_stop.wait(timeout=_WA_INTERVAL)

    def send_whatsapp_report_now(self) -> bool:
        """Trigger an immediate report (called by API endpoint or tests)."""
        try:
            report = self._build_whatsapp_report()
            return self._send_whatsapp(report)
        except Exception as exc:
            logger.warning("send_whatsapp_report_now failed: %s", exc)
            return False

    def _send_whatsapp(self, message: str) -> bool:
        for attempt in range(3):
            try:
                resp = requests.post(
                    f"{_PSYCHOBOT}/send-message",
                    json={"phone": _PHONE, "message": message},
                    timeout=30,
                    verify=False,
                )
                try:
                    payload = resp.json()
                except Exception:
                    payload = {}
                ok = resp.status_code == 200 and payload.get("success", False)
                logger.info(
                    "WhatsApp report → %s (tentative %d/3)",
                    "OK" if ok else f"FAIL {resp.status_code}",
                    attempt + 1,
                )
                if ok:
                    return True
                logger.warning("WhatsApp HTTP %d, payload: %s", resp.status_code, payload)
            except Exception as exc:
                logger.warning("WhatsApp erreur (tentative %d/3): %s", attempt + 1, exc)
            if attempt < 2:
                time.sleep(5)
        logger.error("WhatsApp: 3 tentatives échouées — message non livré")
        return False

    def _build_whatsapp_report(self) -> str:
        """Build a concise French WhatsApp report from all agent outputs."""
        from datetime import datetime, timezone
        intel = self.get_unified_intelligence()
        ts = datetime.now(timezone.utc).strftime("%d/%m %H:%M UTC")

        lines = [
            f"📊 *RAPPORT AGENTS — {ts}*",
            "",
        ]

        # --- Regime (Agent 2) ---
        gr = intel.get("global_regime", {})
        gr_name = gr.get("regime", "UNKNOWN")
        gr_conf = gr.get("confidence", 0)
        regime_icon = {"TRENDING_UP": "📈", "TRENDING_DOWN": "📉", "RANGING": "↔️",
                       "VOLATILE": "⚡", "BREAKOUT": "🚀"}.get(gr_name, "🌐")
        lines += [
            f"{regime_icon} *Régime global:* {gr_name} ({gr_conf*100:.0f}%)",
        ]

        # Per-symbol regime for top 4
        _regime_icon = {
            "TRENDING_UP": "📈", "TRENDING_DOWN": "📉",
            "RANGING": "↔️", "VOLATILE": "⚡", "BREAKOUT": "🚀",
        }
        sym_regimes = intel.get("symbol_regimes", {})
        if sym_regimes:
            parts = []
            for s, i in list(sym_regimes.items())[:4]:
                r = i.get("regime", "?")
                parts.append(f"{s[:8]}{_regime_icon.get(r, '?')}")
            lines.append("  " + " | ".join(parts))

        # --- Risk (Agent 3) ---
        risk_icon = {"NORMAL": "🟢", "CAUTION": "🟡", "HIGH": "🟠", "CRITICAL": "🔴"}.get(
            intel.get("risk_level", "NORMAL"), "🟢"
        )
        can_trade = intel.get("can_trade", True)
        budget = intel.get("daily_budget_remaining", 0)
        pnl = intel.get("daily_pnl", 0)
        lines += [
            "",
            f"{risk_icon} *Risque:* {intel.get('risk_level','NORMAL')} | "
            f"{'✅ Trading OK' if can_trade else '🚫 Stop trading'}",
            f"💵 Budget: ${budget:.2f} | PnL: ${pnl:+.2f}",
        ]

        # --- News (Agent 6) ---
        impact = intel.get("current_impact", "NONE")
        news_blocked = intel.get("news_blocked", False)
        sess = intel.get("session", {})
        impact_icon = "🔴" if news_blocked else ("🟡" if impact not in ("NONE", "") else "🟢")
        lines += [
            "",
            f"{impact_icon} *News:* {impact} | Session: {', '.join(sess.get('active_sessions', [])) or 'Hors session'}",
        ]
        events = intel.get("upcoming_events", [])
        if events:
            ev = events[0]
            lines.append(f"  📅 {ev.get('time','?')} — {ev.get('name','?')} ({ev.get('impact','?')})")

        # --- Timing (Agent 4) — top entries ---
        best = intel.get("best_entries", [])
        top = intel.get("top_entry")
        lines.append("")
        if top:
            sc  = top.get("entry_score", 0)
            sym = top.get("symbol", "")
            rec = top.get("recommendation", "")
            rec_icon = {"IMMEDIATE": "🔥", "ENTER_NOW": "✅", "WAIT_RETEST": "⏳"}.get(rec, "•")
            lines += [
                f"⏱️ *Meilleure entrée:* {sym}",
                f"   {rec_icon} {rec} | {sc}/100",
            ]
        elif best:
            lines.append("⏱️ *Top entrées:*")
            for e in best[:3]:
                rec_icon = {"IMMEDIATE": "🔥", "ENTER_NOW": "✅", "WAIT_RETEST": "⏳"}.get(
                    e.get("recommendation", ""), "•"
                )
                lines.append(f"  {rec_icon} {e['symbol'][:14]} — {e['entry_score']}/100")
        else:
            lines.append("⏱️ _Aucune entrée optimale_")

        # --- TradingAgents Agent 7 deep analysis ---
        ta_intel = intel.get("trading_agents_analysis", {})
        if ta_intel.get("symbol") and ta_intel.get("direction") != "HOLD":
            ta_dir   = ta_intel["direction"]
            ta_conf  = ta_intel.get("confidence", 0)
            ta_boost = ta_intel.get("ta_confidence_boost", 0)
            ta_sym   = ta_intel["symbol"]
            ta_icon  = "📈" if ta_dir == "BUY" else "📉"
            ta_age_s = int(time.time() - ta_intel.get("_ts", time.time()))
            ta_age   = f"{ta_age_s // 60}min" if ta_age_s < 3600 else f"{ta_age_s // 3600}h"
            lines += [
                "",
                f"🧠 *TradingAgents (deep):* {ta_sym}",
                f"   {ta_icon} {ta_dir} | conf={ta_conf*100:.0f}% | boost=+{ta_boost:.0f}pts | il y a {ta_age}",
            ]
            if ta_intel.get("expert_analysis"):
                snippet = ta_intel["expert_analysis"][:120].replace("\n", " ")
                lines.append(f"   _{snippet}…_")

        # --- Peer interactions summary ---
        timing_ctx = self.agents["timing"].get_last_output().get("peer_context", {})
        risk_ctx   = self.agents["risk"].get_last_output().get("peer_context", {})
        peer_notes = []
        if timing_ctx.get("news_penalty", 0) > 0:
            peer_notes.append("news→timing: pénalité active")
        if risk_ctx.get("regime_pos_cap", 5) < 5:
            peer_notes.append(f"régime→risque: max {risk_ctx['regime_pos_cap']} positions")
        if timing_ctx.get("risk_strict_mode"):
            peer_notes.append("risque→timing: mode strict")
        if timing_ctx.get("ta7_boost", 0) > 0:
            peer_notes.append(f"TA7→timing: +{timing_ctx['ta7_boost']:.0f}pts sur {timing_ctx.get('ta7_symbol','?')}")
        if risk_ctx.get("ta7_wr_override", "none") != "none":
            peer_notes.append(f"TA7→risque: WR {risk_ctx['ta7_wr_override']}")
        if peer_notes:
            lines += ["", f"🔗 *Interactions:* {' | '.join(peer_notes)}"]

        # --- Correlation leaders ---
        leaders = intel.get("leaders", [])
        if leaders:
            top_leaders = [f"{l['symbol'][:8]}({l['leader_score']:.1f})" for l in leaders[:3]]
            lines += ["", f"🏆 *Leaders:* {', '.join(top_leaders)}"]

        # --- Synthèse ---
        session_ok = sess.get("recommended", False)
        n_best = len(best) if best else (1 if top else 0)
        if n_best > 0 and can_trade and session_ok and not news_blocked:
            synth = "🟢 TRADER"
        elif news_blocked:
            synth = "🔴 PAUSE NEWS"
        elif not can_trade:
            synth = "🔴 RISQUE ATTEINT"
        elif not session_ok:
            synth = "🟡 HORS SESSION"
        else:
            synth = "🟡 EN VEILLE"

        next_h = _WA_INTERVAL // 3600
        lines += [
            "",
            "━━━━━━━━━━━━",
            f"*{synth}*",
            f"_Prochain rapport dans {next_h}h — TradBOT_",
        ]
        return "\n".join(lines)

    def run_agent_once(self, agent_id: str) -> Dict:
        """Trigger a single agent synchronously and return its output."""
        agent = self.agents.get(agent_id)
        if not agent:
            return {"error": f"Unknown agent: {agent_id}"}
        return agent.run_once()

    def run_all_sequential(self):
        """Run all agents one by one with a short pause between each (avoids server saturation)."""
        for agent_id in self.agents:
            try:
                self.run_agent_once(agent_id)
                time.sleep(0.5)
            except Exception as e:
                logger.warning("run_all_sequential: agent %s error: %s", agent_id, e)

    # ------------------------------------------------------------------
    # Status & reporting
    # ------------------------------------------------------------------

    def get_all_status(self) -> List[Dict]:
        return [agent.get_status_dict() for agent in self.agents.values()]

    def get_agent_status(self, agent_id: str) -> Optional[Dict]:
        agent = self.agents.get(agent_id)
        return agent.get_status_dict() if agent else None

    def get_unified_intelligence(self) -> Dict:
        """
        Merge all agent outputs into a single intelligence package.
        This is what ai_server uses to augment its decisions.
        """
        outputs = {aid: agent.get_last_output() for aid, agent in self.agents.items()}

        correlation     = outputs.get("correlation", {})
        regime          = outputs.get("regime", {})
        risk            = outputs.get("risk", {})
        timing          = outputs.get("timing", {})
        pattern         = outputs.get("pattern", {})
        news            = outputs.get("news", {})
        trading_agents  = outputs.get("trading_agents", {})

        # Aggregate confidence modifier from all agents
        confidence_delta = 0.0
        confidence_delta += news.get("global_confidence_modifier", 0)
        confidence_delta += regime.get("global_regime", {}).get("info", {}).get("gate_modifier", 0)

        # Per-symbol confidence boosts from correlation
        sym_adj = correlation.get("confidence_adjustments", {})

        # Global lot modifier from news
        lot_modifier = news.get("global_lot_modifier", 1.0)

        # Can we trade?
        can_trade = risk.get("can_trade", True)
        news_block = news.get("current_impact") == "HIGH" and not news.get("trading_allowed", True)

        # Entry ranking
        best_entries = timing.get("best_entries", [])
        top_entry = best_entries[0] if best_entries else None

        report = {
            "ts": time.time(),
            "global_regime": regime.get("global_regime", {}),
            "symbol_regimes": regime.get("symbol_regimes", {}),
            "group_alignment": correlation.get("group_alignment", {}),
            "leaders": correlation.get("leaders", []),
            "hedge_pairs": correlation.get("hedge_pairs", []),
            "risk_level": risk.get("risk_level", "NORMAL"),
            "can_trade": can_trade and not news_block,
            "news_blocked": news_block,
            "current_impact": news.get("current_impact", "NONE"),
            "session": news.get("session", {}),
            "global_confidence_delta": round(confidence_delta, 3),
            "global_lot_modifier": round(lot_modifier, 2),
            "symbol_confidence_adjustments": sym_adj,
            "risk_recommendations": risk.get("recommendations", {}),
            "daily_pnl": risk.get("daily_pnl", 0),
            "daily_budget_remaining": risk.get("daily_budget_remaining", 0),
            "best_entries": best_entries,
            "top_entry": top_entry,
            "evolved_thresholds": pattern.get("evolved_thresholds", {}),
            "top_patterns": pattern.get("top_patterns", []),
            "anomalies": pattern.get("anomalies", []),
            "algo_footprints": pattern.get("algo_footprints", []),
            "upcoming_events": news.get("upcoming_events", []),
            "news_sentiment": news.get("news_sentiment", {}),
            "trading_agents_analysis": trading_agents,
        }
        self._unified_report = report
        self._last_unified_ts = time.time()
        return report

    def get_symbol_intelligence(self, symbol: str) -> Dict:
        """Return agent intelligence focused on a single symbol."""
        uni = self.get_unified_intelligence()
        return {
            "symbol": symbol,
            "regime": uni["symbol_regimes"].get(symbol, {}),
            "risk": uni["risk_recommendations"].get(symbol, {}),
            "confidence_adjustment": uni["symbol_confidence_adjustments"].get(symbol, 0.0),
            "evolved_threshold": uni["evolved_thresholds"].get(symbol, {}),
            "entry": next((e for e in uni["best_entries"] if e["symbol"] == symbol), {}),
            "global_confidence_delta": uni["global_confidence_delta"],
            "global_lot_modifier": uni["global_lot_modifier"],
            "can_trade": uni["can_trade"],
            "news_blocked": uni["news_blocked"],
        }

    def get_performance_summary(self) -> Dict:
        return {
            "agents": [
                {
                    "id": aid,
                    "name": agent.agent_name,
                    "status": agent.status.value,
                    "calls": agent.metrics.calls_total,
                    "success_rate": agent.metrics.success_rate,
                    "avg_latency_ms": agent.metrics.avg_latency_ms,
                    "last_run": agent.metrics.last_run_ts,
                    "last_error": agent.metrics.last_error,
                }
                for aid, agent in self.agents.items()
            ],
            "total_calls": sum(a.metrics.calls_total for a in self.agents.values()),
            "total_errors": sum(a.metrics.calls_error for a in self.agents.values()),
        }


# Singleton instance
_orchestrator: Optional[AgentOrchestrator] = None


def get_orchestrator() -> AgentOrchestrator:
    global _orchestrator
    if _orchestrator is None:
        _orchestrator = AgentOrchestrator()
    return _orchestrator
