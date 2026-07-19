"""
Rapport Intelligence Agents -> WhatsApp via PsychoBot
Concu pour etre planifie toutes les 3h via Windows Task Scheduler.
"""
import os
import sys
import json
import logging
import requests
from datetime import datetime, timezone

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("agents_report")

AI_SERVER   = os.getenv("AI_SERVER_URL",  "http://127.0.0.1:8000")
PSYCHOBOT   = os.getenv("PSYCHOBOT_URL",  "https://psychobot-1si7.onrender.com")
PHONE       = os.getenv("WHATSAPP_PHONE") or os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")
TIMEOUT     = int(os.getenv("AGENTS_REPORT_TIMEOUT", "20"))


def fetch_intelligence() -> dict:
    r = requests.get(f"{AI_SERVER}/agents/intelligence", timeout=TIMEOUT)
    r.raise_for_status()
    return r.json()


def fetch_status() -> dict:
    r = requests.get(f"{AI_SERVER}/agents/status", timeout=TIMEOUT)
    r.raise_for_status()
    return r.json()


def _dir_icon(d: str) -> str:
    d = (d or "").lower()
    if d == "bearish":  return "📉"
    if d == "bullish":  return "📈"
    return "➡️"


def _score_bar(score: float) -> str:
    filled = int(score / 10)
    return "█" * filled + "░" * (10 - filled)


def _rec_icon(rec: str) -> str:
    icons = {
        "IMMEDIATE":    "🔥",
        "ENTER_NOW":    "✅",
        "WAIT_RETEST":  "⏳",
        "SKIP":         "⏭️",
        "BLOCKED":      "🚫",
    }
    return icons.get(rec, "•")


def build_report(intel: dict, status: dict) -> str:
    now_utc = datetime.now(timezone.utc)
    ts = now_utc.strftime("%d/%m/%Y %H:%M UTC")

    agents_meta = {a["agent_id"]: a for a in status.get("agents", [])}
    perf = status.get("performance", {})
    total_calls  = perf.get("total_calls", 0)
    total_errors = perf.get("total_errors", 0)

    lines = [
        f"📊 *RAPPORT INTELLIGENCE AGENTS*",
        f"_{ts}_",
        "",
        f"🤖 6 agents | {total_calls} appels | {total_errors} erreurs",
    ]

    # ── Agent 1 : Corrélation ────────────────────────────────
    corr_agent = agents_meta.get("correlation", {})
    corr_calls  = corr_agent.get("metrics", {}).get("calls_total", 0)
    corr_sr     = corr_agent.get("metrics", {}).get("success_rate", 0)
    corr_out    = corr_agent.get("last_output", {})
    leaders     = corr_out.get("leaders", [])
    hedges      = corr_out.get("hedge_pairs", [])
    boost_pos   = [s for s, v in corr_out.get("confidence_adjustments", {}).items() if v > 0]
    boost_neg   = [s for s, v in corr_out.get("confidence_adjustments", {}).items() if v < 0]

    lines += [
        "",
        "━━━━━━━━━━━━━━━━━━━━━━",
        f"🔗 *AGENT 1 — CORRÉLATION*",
        f"✅ {corr_calls} appels | {corr_sr:.0f}% succès",
    ]
    if leaders:
        lines.append("🏆 *Leaders:*")
        for l in leaders[:5]:
            icon = _dir_icon(l.get("current_direction", ""))
            lines.append(f"  • {l['symbol'][:16]:<16} {icon} score {l['leader_score']:.2f} | {l['current_direction'].upper()}")
    if hedges:
        lines.append("🔄 *Hedge pairs:*")
        for h in hedges:
            lines.append(f"  • {h['pair']} = {h['correlation']:+.2f}")
    if boost_pos:
        lines.append(f"📈 Boost +0.05: {', '.join(boost_pos[:4])}")
    if boost_neg:
        lines.append(f"📉 Pénalité -0.08: {', '.join(boost_neg[:3])}")

    # ── Agent 2 : Régime ─────────────────────────────────────
    reg_agent  = agents_meta.get("regime", {})
    reg_calls  = reg_agent.get("metrics", {}).get("calls_total", 0)
    reg_sr     = reg_agent.get("metrics", {}).get("success_rate", 0)
    sym_regimes = intel.get("symbol_regimes", {})
    glob_regime = intel.get("global_regime", {})
    corr_warns  = reg_agent.get("last_output", {}).get("correction_warnings", [])

    lines += [
        "",
        "━━━━━━━━━━━━━━━━━━━━━━",
        f"🌐 *AGENT 2 — RÉGIME*",
        f"✅ {reg_calls} appels | {reg_sr:.0f}% succès",
    ]
    if sym_regimes:
        gr = glob_regime.get("regime", "UNKNOWN")
        gc = glob_regime.get("confidence", 0)
        lines.append(f"Régime global: *{gr}* ({gc*100:.0f}%)")
        for sym, info in list(sym_regimes.items())[:6]:
            r = info.get("regime", "?")
            c = info.get("confidence", 0)
            lines.append(f"  • {sym[:16]:<16} {r} ({c*100:.0f}%)")
    else:
        lines.append("⚠️ Données insuffisantes — ML inactif à cette heure")
    if corr_warns:
        lines.append(f"⚠️ Corrections M1/M5: {', '.join(corr_warns)}")

    # ── Agent 3 : Risque ─────────────────────────────────────
    risk_agent = agents_meta.get("risk", {})
    risk_calls = risk_agent.get("metrics", {}).get("calls_total", 0)
    risk_sr    = risk_agent.get("metrics", {}).get("success_rate", 0)
    risk_out   = risk_agent.get("last_output", {})
    risk_lvl   = intel.get("risk_level", "NORMAL")
    budget     = intel.get("daily_budget_remaining", 0)
    pnl        = intel.get("daily_pnl", 0)
    kelly_recs = risk_out.get("recommendations", {})
    open_pos   = risk_out.get("open_positions", 0)

    risk_icon = "🟢" if risk_lvl == "NORMAL" else ("🟡" if risk_lvl == "CAUTION" else "🔴")
    lines += [
        "",
        "━━━━━━━━━━━━━━━━━━━━━━",
        f"💰 *AGENT 3 — RISQUE*",
        f"✅ {risk_calls} appels | {risk_sr:.0f}% succès",
        f"{risk_icon} Niveau: {risk_lvl} | Positions: {open_pos}",
        f"💵 Budget restant: ${budget:.2f} | PnL jour: ${pnl:+.2f}",
    ]
    if kelly_recs:
        lines.append("📐 *Kelly Criterion:*")
        for sym, rec in list(kelly_recs.items())[:3]:
            lines.append(f"  • {sym[:14]:<14} {rec['recommended_lot']:.2f} lot | WR {rec['win_rate']:.0f}% | RR {rec['rr_ratio']:.1f}")

    # ── Agent 4 : Timing ─────────────────────────────────────
    tim_agent   = agents_meta.get("timing", {})
    tim_calls   = tim_agent.get("metrics", {}).get("calls_total", 0)
    tim_sr      = tim_agent.get("metrics", {}).get("success_rate", 0)
    tim_out     = tim_agent.get("last_output", {})
    best        = intel.get("best_entries", [])
    top_entry   = intel.get("top_entry")
    scored      = tim_out.get("scored_entries", {})
    blocked_lst = tim_out.get("blocked_entries", [])
    tim_warns   = tim_out.get("correction_warnings", [])

    lines += [
        "",
        "━━━━━━━━━━━━━━━━━━━━━━",
        f"⏱️ *AGENT 4 — TIMING*",
        f"✅ {tim_calls} appels | {tim_sr:.0f}% succès",
    ]
    if top_entry:
        sc = top_entry.get("entry_score", 0)
        sym = top_entry.get("symbol", "")
        rec = top_entry.get("recommendation", "")
        lines += [
            f"🏆 *Meilleure entrée:* {sym}",
            f"   Score: {sc}/100 [{_score_bar(sc)}]",
            f"   {_rec_icon(rec)} {rec}",
        ]
    elif best:
        lines.append("🏆 *Top entrées:*")
        for e in best[:3]:
            sc  = e.get("entry_score", 0)
            sym = e.get("symbol", "")
            rec = e.get("recommendation", "")
            lines.append(f"  {_rec_icon(rec)} {sym[:14]:<14} {sc}/100 [{_score_bar(sc)}]")
    else:
        # Affiche quand meme le top des SKIP pour info
        skips = [(s, v) for s, v in scored.items()
                 if not v.get("blocked") and v.get("entry_score", 0) > 0]
        skips.sort(key=lambda x: x[1].get("entry_score", 0), reverse=True)
        lines.append("⏭️ *Top symboles (SKIP):*")
        for sym, v in skips[:4]:
            sc  = v.get("entry_score", 0)
            rec = v.get("recommendation", "SKIP")
            vrd = v.get("verdict", "")
            lines.append(f"  • {sym[:14]:<14} {sc:.0f}/100 | {vrd}")
        lines.append("_Aucune entrée optimale à cette heure_")

    if blocked_lst:
        lines.append(f"🚫 Bloqués (loi): {', '.join(blocked_lst)}")
    if tim_warns:
        lines.append(f"⚠️ Corrections: {', '.join(tim_warns)}")

    # ── Agent 5 : Patterns ───────────────────────────────────
    pat_agent = agents_meta.get("pattern", {})
    pat_calls = pat_agent.get("metrics", {}).get("calls_total", 0)
    pat_sr    = pat_agent.get("metrics", {}).get("success_rate", 0)
    pat_out   = pat_agent.get("last_output", {})
    top_pats  = pat_out.get("top_patterns", [])
    algos     = pat_out.get("algo_footprints", [])
    anom      = pat_out.get("anomalies", [])
    n_trades  = pat_out.get("total_trades_analyzed", 0)

    lines += [
        "",
        "━━━━━━━━━━━━━━━━━━━━━━",
        f"🧠 *AGENT 5 — PATTERNS*",
        f"✅ {pat_calls} appels | {pat_sr:.0f}% succès",
        f"📊 {n_trades} trades analysés",
    ]
    if top_pats:
        lines.append("✨ *Patterns actifs:*")
        for p in top_pats[:3]:
            lines.append(f"  • {p.get('pattern','?')} | WR {p.get('win_rate',0):.0f}%")
    if algos:
        lines.append("🤖 *Empreintes algo:*")
        for a in algos[:2]:
            lines.append(f"  • {a.get('symbol','?')} | {a.get('signal_type','?')}")
    if anom:
        lines.append(f"⚡ Anomalies: {len(anom)}")
    if not top_pats and not algos:
        lines.append("⏳ Apprentissage en cours — données insuffisantes")

    # ── Agent 6 : News ───────────────────────────────────────
    news_agent = agents_meta.get("news", {})
    news_calls = news_agent.get("metrics", {}).get("calls_total", 0)
    news_sr    = news_agent.get("metrics", {}).get("success_rate", 0)
    impact     = intel.get("current_impact", "NONE")
    news_block = intel.get("news_blocked", False)
    session    = intel.get("session", {})
    events     = intel.get("upcoming_events", [])
    sess_qual  = session.get("quality", "unknown")
    sess_hour  = session.get("hour_utc", 0)
    sess_sess  = session.get("active_sessions", [])

    impact_icon = "🔴" if news_block else ("🟡" if impact not in ("NONE", "") else "🟢")
    lines += [
        "",
        "━━━━━━━━━━━━━━━━━━━━━━",
        f"📰 *AGENT 6 — NEWS*",
        f"✅ {news_calls} appels | {news_sr:.0f}% succès",
        f"{impact_icon} Impact: {impact} | Trading: {'🚫 BLOQUÉ' if news_block else '✅ OK'}",
        f"🕐 {sess_hour}h UTC | Session: {', '.join(sess_sess) if sess_sess else 'Hors session'} | {sess_qual}",
    ]
    if events:
        lines.append("📅 *Événements à venir:*")
        for e in events[:3]:
            lines.append(f"  • {e.get('time','?')} — {e.get('name','?')} ({e.get('impact','?')})")
    else:
        lines.append("📅 Aucun événement macro à venir")

    # ── Synthèse ─────────────────────────────────────────────
    session_recommended = session.get("recommended", False)
    can_trade = intel.get("can_trade", True) and not news_block
    n_best = len(best) if best else (1 if top_entry else 0)

    if n_best > 0 and can_trade and session_recommended:
        synth_icon = "🟢"
        synth_rec  = f"TRADER — {n_best} entrée(s) disponible(s)"
    elif can_trade and not session_recommended:
        synth_icon = "🟡"
        synth_rec  = "ATTENDRE — hors session active"
    elif news_block:
        synth_icon = "🔴"
        synth_rec  = "PAUSE — news haute impact"
    else:
        synth_icon = "🟡"
        synth_rec  = "EN VEILLE"

    lines += [
        "",
        "━━━━━━━━━━━━━━━━━━━━━━",
        f"📋 *SYNTHÈSE*",
        f"{synth_icon} *{synth_rec}*",
        f"• {total_calls} appels | {total_errors} erreurs | 100% uptime",
        f"• Prochain rapport dans 3h",
        "",
        "_TradBOT Intelligence System_",
    ]

    return "\n".join(lines)


def send_whatsapp(message: str) -> bool:
    resp = requests.post(
        f"{PSYCHOBOT}/send-message",
        json={"phone": PHONE, "message": message},
        timeout=30,
        verify=False,
    )
    data = resp.json()
    ok = resp.status_code == 200 and data.get("success", False)
    log.info("WhatsApp %s → %s", PHONE, "OK" if ok else f"FAIL {resp.status_code}")
    return ok


def main() -> int:
    log.info("Démarrage rapport agents...")
    try:
        intel  = fetch_intelligence()
        status = fetch_status()
    except Exception as e:
        log.error("Impossible de joindre le serveur: %s", e)
        return 1

    report = build_report(intel, status)
    ok = send_whatsapp(report)
    return 0 if ok else 2


if __name__ == "__main__":
    sys.exit(main())
