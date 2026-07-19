# -*- coding: utf-8 -*-
"""
Fusion TradingAgents + TradingView MCP Kola — signal unifié, WhatsApp, pending order.
"""

from __future__ import annotations

import os
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

import requests
try:
    import ssl_patch  # noqa: F401 — SSL Windows fix
except ImportError:
    import urllib3
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

from tv_mcp_client import fetch_tradingview_analysis, summarize_tv_analysis

_SERVER_URL = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000").rstrip("/")
_WHATSAPP_URL = os.getenv("WHATSAPP_API_URL", "https://psychobot-1si7.onrender.com")
_PHONE = os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")


def normalize_direction(d: Optional[str]) -> str:
    if not d:
        return "NEUTRAL"
    u = str(d).upper().strip()
    if u in ("BUY", "STRONG_BUY", "LONG", "BUY_STOP_AFTER_SPIKE"):
        return "BUY"
    if u in ("SELL", "STRONG_SELL", "SHORT", "SELL_STOP_AFTER_SPIKE"):
        return "SELL"
    return "NEUTRAL"


def compare_ta_and_tv(
    ta_recommendation: str,
    tv_summary: Dict[str, Any],
) -> Dict[str, Any]:
    """Compare direction TradingAgents vs TradingView SMC."""
    ta_dir = normalize_direction(ta_recommendation)
    tv_dir = normalize_direction(tv_summary.get("direction"))

    # Spike synthétique peut renforcer
    spike_dir = normalize_direction(tv_summary.get("spike_direction"))
    if tv_dir == "NEUTRAL" and spike_dir != "NEUTRAL":
        tv_dir = spike_dir

    aligned = ta_dir == tv_dir and ta_dir in ("BUY", "SELL")
    partial = ta_dir in ("BUY", "SELL") and tv_dir == "NEUTRAL"

    if aligned:
        verdict = "ALIGNED"
        msg = f"TradingAgents {ta_dir} + TradingView {tv_dir} — même sens"
    elif partial:
        verdict = "TA_ONLY"
        msg = f"TradingAgents {ta_dir}, TradingView neutre — signal TA seul (prudence)"
    elif ta_dir in ("BUY", "SELL") and tv_dir in ("BUY", "SELL"):
        verdict = "CONFLICT"
        msg = f"CONFLIT: TradingAgents {ta_dir} vs TradingView {tv_dir}"
    else:
        verdict = "NO_TRADE"
        msg = "Pas de direction claire (HOLD / neutre)"

    confidence_boost = 0.0
    if aligned:
        conf = tv_summary.get("confluence_score") or 0
        confidence_boost = min(0.15, float(conf) / 7.0 * 0.15)

    return {
        "verdict": verdict,
        "aligned": aligned,
        "allow_pending": aligned,  # pending seulement si aligné
        "ta_direction": ta_dir,
        "tv_direction": tv_dir,
        "message": msg,
        "confidence_boost": confidence_boost,
    }


def merge_confirmed_with_tv(
    confirmed: Dict[str, Any],
    tv_summary: Dict[str, Any],
    comparison: Dict[str, Any],
) -> Dict[str, Any]:
    """Enrichit le signal confirmé avec niveaux TV si manquants."""
    out = dict(confirmed)
    if comparison.get("aligned"):
        base = float(out.get("confidence") or 0.75)
        out["confidence"] = min(0.98, base + comparison.get("confidence_boost", 0))

    setup_sl = tv_summary.get("stop_loss")
    setup_tp = tv_summary.get("take_profit")
    setup_entry = tv_summary.get("entry_price")

    if not out.get("entry_price") and setup_entry:
        out["entry_price"] = setup_entry
    if not out.get("stop_loss") and setup_sl:
        out["stop_loss"] = setup_sl
    if not out.get("take_profit") and setup_tp:
        out["take_profit"] = setup_tp

    out["tv_direction"] = comparison.get("tv_direction")
    out["tv_verdict"] = comparison.get("verdict")
    out["source"] = "unified_ta_tv"
    return out


def format_unified_whatsapp(
    symbol: str,
    ta_rec: str,
    ta_confidence: float,
    confirmed: Dict[str, Any],
    tv_summary: Dict[str, Any],
    comparison: Dict[str, Any],
    expert_snippet: str = "",
) -> str:
    """Message WhatsApp unique (TA + TV + niveaux + verdict)."""
    ts = datetime.utcnow().strftime("%H:%M UTC")
    entry = confirmed.get("entry_price")
    sl = confirmed.get("stop_loss")
    tp = confirmed.get("take_profit")
    lot = confirmed.get("lot")

    lines: List[str] = [
        f"*SIGNAL UNIFIÉ TradBOT* [{ts}]",
        f"Symbole: *{symbol}*",
        "",
        "━━━━━━━━━━━━━━━━━━━━",
        "📊 *TradingAgents*",
        "━━━━━━━━━━━━━━━━━━━━",
        f"Décision: *{ta_rec}* ({ta_confidence:.0%})",
        "",
        "━━━━━━━━━━━━━━━━━━━━",
        "📈 *TradingView (MCP Kola)*",
        "━━━━━━━━━━━━━━━━━━━━",
    ]

    if tv_summary.get("success"):
        lines.append(f"Direction SMC: *{tv_summary.get('direction', '—')}*")
        if tv_summary.get("bias_score") is not None:
            lines.append(f"Score biais: {tv_summary['bias_score']}")
        if tv_summary.get("structure_h1"):
            lines.append(f"Structure H1: {tv_summary['structure_h1']}")
        if tv_summary.get("structure_m15"):
            lines.append(f"Structure M15: {tv_summary['structure_m15']}")
        if tv_summary.get("spike_detected"):
            lines.append(
                f"Spike Z={tv_summary.get('spike_z')} → {tv_summary.get('spike_direction')}"
            )
        reasons = tv_summary.get("bias_reasons") or []
        if reasons:
            lines.append("Raisons: " + "; ".join(reasons[:4]))
    else:
        lines.append(f"⚠️ TV indisponible: {tv_summary.get('error', 'CDP / chart')}")

    lines.extend([
        "",
        "━━━━━━━━━━━━━━━━━━━━",
        "🔗 *Convergence*",
        "━━━━━━━━━━━━━━━━━━━━",
        f"{comparison.get('message', '—')}",
        f"Verdict: *{comparison.get('verdict', '—')}*",
        "",
    ])

    if comparison.get("allow_pending") and ta_rec in ("BUY", "SELL"):
        lines.extend([
            "━━━━━━━━━━━━━━━━━━━━",
            "💰 *Ordre proposé (pending MT5)*",
            "━━━━━━━━━━━━━━━━━━━━",
            f"Action: *{confirmed.get('recommendation', ta_rec)}*",
            f"Entry: *{entry}*" if entry else "Entry: marché",
            f"SL: *{sl}*" if sl else "SL: —",
            f"TP: *{tp}*" if tp else "TP: —",
            f"Lot: {lot}" if lot else "",
            f"Type: {confirmed.get('execution_type', 'market')}",
            "",
            "✅ Pending activé — suivi toutes les 10 min",
        ])
    else:
        lines.append("⏸ Pas d'ordre pending (pas de convergence TA/TV).")

    if expert_snippet:
        snip = expert_snippet.strip()[:400]
        lines.extend(["", "📝 *Note expert*", snip + ("…" if len(expert_snippet) > 400 else "")])

    lines.append("\n_Generated by TradBOT Bridge_")
    return "\n".join(lines)


def send_unified_whatsapp(message: str, phone: Optional[str] = None) -> bool:
    phone = phone or _PHONE
    try:
        r = requests.post(
            f"{_WHATSAPP_URL}/send-message",
            json={"phone": phone, "message": message},
            timeout=30,
            verify=False,
        )
        if r.status_code == 200 and r.json().get("success"):
            print("  [OK] WhatsApp unifié envoyé")
            return True
        print(f"  [!] WhatsApp: {r.status_code} {r.text[:200]}")
        return False
    except Exception as e:
        print(f"  [!] WhatsApp: {e}")
        return False


def push_unified_state(
    symbol: str,
    confirmed: Optional[Dict[str, Any]],
    tv_summary: Dict[str, Any],
    comparison: Dict[str, Any],
) -> bool:
    """Stocke l'état unifié sur ai_server pour le monitor 10 min."""
    payload = {
        "symbol": symbol,
        "confirmed": confirmed,
        "tv_summary": tv_summary,
        "comparison": comparison,
        "updated_at": datetime.utcnow().isoformat(),
    }
    try:
        r = requests.post(
            f"{_SERVER_URL}/bridge/unified-signal",
            json=payload,
            timeout=10,
        )
        return r.status_code == 200
    except Exception:
        return False


def run_tv_analysis_for_bridge(symbol: str) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    """Fetch + résumé TV pour le bridge."""
    cat = symbol.upper()
    mode = "both" if ("BOOM" in cat or "CRASH" in cat) else "smc"
    raw = fetch_tradingview_analysis(symbol, mode=mode)
    summary = summarize_tv_analysis(raw)
    return raw, summary


def resolve_conflict_loop(
    symbol: str,
    ta_rec: str,
    interval_sec: int = 300,
    max_retries: int = 3,
    phone: Optional[str] = None,
) -> bool:
    """
    Boucle bloquante de résolution conflit TA vs TV.
    Re-scanne TV toutes les interval_sec sec, jusqu'à max_retries fois.
    Retourne True si conflit résolu (ordre promu 'ready'), False si timeout.
    """
    import time as _time
    sym_clean = symbol.strip().upper()

    for attempt in range(1, max_retries + 1):
        mins = interval_sec // 60
        print(f"\n[bridge] Conflit — attente {mins}min avant re-scan TV "
              f"({attempt}/{max_retries})...")
        _time.sleep(interval_sec)

        print(f"[bridge] Re-scan TradingView #{attempt}/{max_retries}...")
        _, tv_summary = run_tv_analysis_for_bridge(symbol)
        comparison = compare_ta_and_tv(ta_rec, tv_summary)

        tv_dir  = comparison.get("tv_direction", "NEUTRAL")
        verdict = comparison.get("verdict", "UNKNOWN")
        print(f"  TV: {tv_dir} | TA: {ta_rec} | Verdict: {verdict}")

        if comparison.get("aligned"):
            # Promouvoir l'ordre
            try:
                requests.post(
                    f"{_SERVER_URL}/pending-order/resolve",
                    json={"symbol": sym_clean},
                    timeout=10,
                )
            except Exception as _e:
                print(f"  [WARN] resolve: {_e}")

            wa_msg = (
                f"*CONFLIT RESOLU - Ordre active* [{datetime.utcnow().strftime('%H:%M UTC')}]\n"
                f"Symbole: *{sym_clean}*\n"
                f"TA: {ta_rec} | TV: {tv_dir} -> *ALIGNES*\n"
                f"Ordre pending ACTIVE - TradeManager execute au marche (poll ~10s) + trailing"
            )
            send_unified_whatsapp(wa_msg, phone)
            print(f"  Conflit resolu (tentative #{attempt})")
            return True

        # Pas encore aligné
        remaining = (max_retries - attempt) * mins
        if remaining > 0:
            wa_msg = (
                f"*Refresh conflit #{attempt}/{max_retries}* "
                f"[{datetime.utcnow().strftime('%H:%M UTC')}]\n"
                f"Symbole: *{sym_clean}*\n"
                f"TA: {ta_rec} | TV: {tv_dir} | Verdict: {verdict}\n"
                f"Toujours en conflit - prochain check dans {mins}min"
            )
        else:
            wa_msg = (
                f"*Signal expire - conflit non resolu* "
                f"[{datetime.utcnow().strftime('%H:%M UTC')}]\n"
                f"Symbole: *{sym_clean}*\n"
                f"TA: {ta_rec} persistant mais TV reste {tv_dir}\n"
                f"Ordre SELL annule - attendre prochain signal bridge"
            )
        send_unified_whatsapp(wa_msg, phone)

    # Timeout — supprimer l'ordre conflict_pending
    try:
        requests.delete(
            f"{_SERVER_URL}/pending-order",
            params={"symbol": sym_clean},
            timeout=5,
        )
    except Exception:
        pass
    print(f"  [!] Conflit non resolu apres {max_retries} tentatives — ordre annule")
    return False
