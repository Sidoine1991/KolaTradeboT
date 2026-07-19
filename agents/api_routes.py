"""
FastAPI routes for the Agent Intelligence Layer.
Import and include this router in ai_server.py:

    from agents.api_routes import agent_router
    app.include_router(agent_router)
"""

from fastapi import APIRouter, HTTPException, BackgroundTasks
from typing import Optional
from .orchestrator import get_orchestrator

# Symbols that follow Boom/Crash unidirectional law (aligné EA + ai_server)
_BOOM_KEYWORDS  = ("BOOM", "GAINX", "TRENDX")
_CRASH_KEYWORDS = ("CRASH", "PAINX")

agent_router = APIRouter(prefix="/agents", tags=["Intelligence Agents"])


@agent_router.get("/status")
async def agents_status():
    """Return status + metrics for all 6 agents."""
    orch = get_orchestrator()
    return {
        "agents": orch.get_all_status(),
        "performance": orch.get_performance_summary(),
    }


@agent_router.get("/status/{agent_id}")
async def agent_status(agent_id: str):
    """Return status for a single agent."""
    orch = get_orchestrator()
    status = orch.get_agent_status(agent_id)
    if not status:
        raise HTTPException(404, f"Agent '{agent_id}' not found")
    return status


@agent_router.post("/run/{agent_id}")
async def run_agent(agent_id: str, background_tasks: BackgroundTasks):
    """Trigger a single agent cycle immediately (async)."""
    orch = get_orchestrator()
    if agent_id not in orch.agents:
        raise HTTPException(404, f"Agent '{agent_id}' not found")
    background_tasks.add_task(orch.run_agent_once, agent_id)
    return {"message": f"Agent {agent_id} triggered", "agent_id": agent_id}


@agent_router.post("/run-all")
async def run_all_agents(background_tasks: BackgroundTasks):
    """Trigger all agents sequentially in background (avoids flooding the server)."""
    orch = get_orchestrator()
    background_tasks.add_task(orch.run_all_sequential)
    return {"message": "All agents triggered (sequential)", "count": len(orch.agents)}


@agent_router.post("/run-all-parallel")
async def run_all_agents_parallel(background_tasks: BackgroundTasks):
    """Trigger all 6 agents in parallel (one thread per agent)."""
    orch = get_orchestrator()
    background_tasks.add_task(orch.run_all_parallel)
    return {"message": "All agents triggered (parallel)", "count": len(orch.agents)}


@agent_router.get("/intelligence")
async def get_unified_intelligence():
    """Return the full merged intelligence report from all agents."""
    orch = get_orchestrator()
    return orch.get_unified_intelligence()


@agent_router.get("/intelligence/{symbol}")
async def get_symbol_intelligence(symbol: str):
    """Return agent intelligence focused on a specific trading symbol."""
    orch = get_orchestrator()
    return orch.get_symbol_intelligence(symbol.upper())


@agent_router.get("/performance")
async def get_performance():
    """Return performance metrics for all agents."""
    orch = get_orchestrator()
    return orch.get_performance_summary()


@agent_router.post("/start")
async def start_agents():
    """Start all agent background loops."""
    orch = get_orchestrator()
    orch.start_all()
    return {"message": "All agents started"}


@agent_router.post("/stop")
async def stop_agents():
    """Stop all agent background loops."""
    orch = get_orchestrator()
    orch.stop_all()
    return {"message": "All agents stopped"}


@agent_router.post("/report-now")
async def whatsapp_report_now(background_tasks: BackgroundTasks):
    """Send the unified intelligence report to WhatsApp immediately."""
    orch = get_orchestrator()
    background_tasks.add_task(orch.send_whatsapp_report_now)
    return {"message": "Rapport WhatsApp en cours d'envoi"}


@agent_router.get("/gate/{symbol}")
async def agent_gate(symbol: str, direction: str = "", account_balance: float = 0.0):
    """
    EA-facing gate endpoint. Returns a single actionable verdict for the EA:
    - allowed: bool — whether to open a position
    - lot_multiplier: float — multiply the EA's calculated lot by this factor (0.0 = block)
    - recommended_lot: float — direct lot recommendation from Risk agent (0 = use EA's own)
    - confidence_boost: float — additive boost to EA's AI confidence (can be negative)
    - regime: str — current market regime for the symbol
    - entry_score: int — timing quality 0-100
    - recommendation: str — IMMEDIATE / ENTER_NOW / WAIT_RETEST / SKIP / BLOCKED
    - reasons: list[str] — human-readable explanation of each gate decision
    - correction_detected: bool — M1/M5 against main trend
    - news_blocked: bool — high-impact news window

    EA usage: GET /agents/gate/CRASH%20500%20INDEX?direction=SELL&account_balance=1000
    """
    orch = get_orchestrator()
    sym = symbol.upper().strip()
    direction = direction.upper().strip()
    intel = orch.get_symbol_intelligence(sym)

    reasons: list = []
    allowed = True
    lot_multiplier = 1.0
    confidence_boost = 0.0

    # ── 0a. News global lot modifier (macro context) ─────────────────
    global_lot_mod = float(intel.get("global_lot_modifier", 1.0))
    if global_lot_mod < 1.0:
        lot_multiplier = min(lot_multiplier, global_lot_mod)
        reasons.append(f"NEWS-LOT: macro lot modifier ×{global_lot_mod:.2f}")

    # ── 0b. Correlation per-symbol confidence adjustment ─────────────
    conf_adj = float(intel.get("confidence_adjustment", 0.0))
    if conf_adj != 0.0:
        confidence_boost += conf_adj
        label = f"+{conf_adj:.2f}" if conf_adj > 0 else f"{conf_adj:.2f}"
        reasons.append(f"CORR: correlation adjustment conf {label}")

    # ── 1. Boom/Crash law ────────────────────────────────────────────
    is_boom  = any(k in sym for k in _BOOM_KEYWORDS)
    is_crash = any(k in sym for k in _CRASH_KEYWORDS)
    if direction:
        if is_boom and direction == "SELL":
            allowed = False
            lot_multiplier = 0.0
            reasons.append("BLOCKED: Boom=BUY_ONLY — SELL interdit")
        elif is_crash and direction == "BUY":
            allowed = False
            lot_multiplier = 0.0
            reasons.append("BLOCKED: Crash=SELL_ONLY — BUY interdit")

    # ── 2. News gate ─────────────────────────────────────────────────
    news_blocked = intel.get("news_blocked", False)
    if news_blocked and allowed:
        allowed = False
        lot_multiplier = 0.0
        reasons.append("BLOCKED: événement macro haute impact en cours")

    # ── 3. Risk gate: daily budget ────────────────────────────────────
    risk = orch.agents["risk"].get_last_output() if "risk" in orch.agents else {}
    can_trade   = risk.get("can_trade", True)
    risk_level  = risk.get("risk_level", "NORMAL")
    daily_budget = float(risk.get("daily_budget_remaining", 999))
    if not can_trade and allowed:
        allowed = False
        lot_multiplier = 0.0
        reasons.append(f"BLOCKED: budget journalier épuisé (risk_level={risk_level})")
    elif risk_level == "HIGH" and allowed:
        lot_multiplier = min(lot_multiplier, 0.5)
        reasons.append("CAUTION: risk_level=HIGH → lot ×0.5")
    elif risk_level == "CAUTION" and allowed:
        lot_multiplier = min(lot_multiplier, 0.75)
        reasons.append("CAUTION: risk_level=CAUTION → lot ×0.75")

    # ── 4. Regime gate ───────────────────────────────────────────────
    regime_data = intel.get("regime", {})
    regime      = regime_data.get("regime", "UNKNOWN")
    regime_conf = float(regime_data.get("confidence", 0.5))
    correction  = regime_data.get("correction_detected", False)

    if regime == "RANGING" and regime_conf < 0.55 and allowed:
        lot_multiplier = min(lot_multiplier, 0.6)
        reasons.append(f"CAUTION: régime RANGING (conf={regime_conf:.0%}) → lot ×0.6")
    elif regime == "VOLATILE" and allowed:
        lot_multiplier = min(lot_multiplier, 0.5)
        reasons.append("CAUTION: régime VOLATILE → lot ×0.5")

    if correction and allowed:
        lot_multiplier = min(lot_multiplier, 0.75)
        confidence_boost -= 0.08
        reasons.append("CAUTION: correction M1/M5 détectée → lot ×0.75, conf -8%")

    # ── 5. Entry timing gate ─────────────────────────────────────────
    entry_data  = intel.get("entry", {})
    entry_score = int(entry_data.get("entry_score", 0))
    entry_rec   = entry_data.get("recommendation", "SKIP")

    if entry_rec == "BLOCKED":
        allowed = False
        lot_multiplier = 0.0
        reasons.append(f"BLOCKED: timing bloque ({entry_data.get('reason','')})")
    elif entry_score >= 75:
        confidence_boost += 0.10
        reasons.append(f"BOOST: entry_score={entry_score}/100 → conf +10%")
    elif entry_score >= 60:
        confidence_boost += 0.05
        reasons.append(f"OK: entry_score={entry_score}/100")
    elif entry_score > 0 and entry_score < 45 and allowed:
        lot_multiplier = min(lot_multiplier, 0.7)
        reasons.append(f"WEAK: entry_score={entry_score}/100 → lot ×0.7")

    # ── 6. Regime-direction alignment ────────────────────────────────
    if direction and regime in ("TRENDING_UP", "TRENDING_DOWN"):
        regime_dir = "BUY" if regime == "TRENDING_UP" else "SELL"
        if regime_dir == direction:
            confidence_boost += 0.05
            reasons.append(f"BOOST: direction alignée avec régime {regime}")
        else:
            confidence_boost -= 0.10
            lot_multiplier = min(lot_multiplier, 0.6)
            reasons.append(f"WARN: direction {direction} contre régime {regime} → conf -10%, lot ×0.6")

    # ── 7. Recommended lot from Risk agent ───────────────────────────
    recommendations = risk.get("recommendations", {})
    rec_lot = 0.0
    for k, v in recommendations.items():
        if k.upper() in sym or sym in k.upper():
            rec_lot = float(v.get("recommended_lot", 0))
            break

    # ── 8. Pattern evolved thresholds ────────────────────────────────
    evolved = intel.get("evolved_threshold", {})
    if evolved and allowed:
        min_coh = float(evolved.get("min_coherence", 0))
        min_gap = float(evolved.get("min_gap", 0))
        exp_wr  = float(evolved.get("expected_wr", 0))
        # Verify current entry coherence meets the learned threshold
        gom_data = orch.agents["timing"].get_last_output() or {}
        scored_entries = gom_data.get("scored_entries", {})
        sym_entry = scored_entries.get(sym, {})
        raw_coherence = float(sym_entry.get("coherence", 100))
        if min_coh > 0 and raw_coherence < min_coh:
            lot_multiplier = min(lot_multiplier, 0.6)
            reasons.append(f"PATTERN: coherence {raw_coherence:.0f}% < seuil appris {min_coh:.0f}% → lot ×0.6")
        elif min_coh > 0 and exp_wr >= 0.60:
            confidence_boost += 0.05
            reasons.append(f"PATTERN: pattern gagnant actif ({exp_wr:.0%} WR historique) → conf +5%")

    # ── Final recommendation ─────────────────────────────────────────
    if not allowed:
        final_rec = "BLOCKED"
    elif entry_rec in ("IMMEDIATE", "ENTER_NOW"):
        final_rec = entry_rec
    elif entry_rec == "WAIT_RETEST":
        final_rec = "WAIT_RETEST"
    else:
        final_rec = "SKIP" if entry_score < 45 else "ENTER_NOW"

    if not reasons:
        reasons.append("OK: tous les gates passés")

    return {
        "symbol": sym,
        "direction": direction,
        "allowed": allowed,
        "lot_multiplier": round(lot_multiplier, 2),
        "recommended_lot": round(rec_lot, 2),
        "confidence_boost": round(confidence_boost, 3),
        "regime": regime,
        "regime_confidence": round(regime_conf, 2),
        "entry_score": entry_score,
        "recommendation": final_rec,
        "correction_detected": correction,
        "news_blocked": news_blocked,
        "risk_level": risk_level,
        "daily_budget_remaining": round(daily_budget, 2),
        "reasons": reasons,
    }
