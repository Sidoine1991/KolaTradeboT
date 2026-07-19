"""
Unified WhatsApp Collector v1
=============================

Collecte TOUTES les données XAUUSD en parallèle :
- TradingView : prix, VWAP, BB, Supertrend, Fibonacci, Spike, RSI, GOM verdict
- AI Server : session bias, pending order, TradingAgents rapport
- Envoie UN seul message WhatsApp unifié via PsychoBot

Usage:
    python unified_whatsapp_collector.py --phone "+2290196911346"
"""

import asyncio
import subprocess
import json
import sys
import io
import re
import time
import logging
from datetime import datetime
from typing import Optional, Dict, Any

import requests
import aiohttp

# Fix Windows console encoding
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler("unified_collector.log", encoding="utf-8"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)

# Configuration
SYMBOL = "XAUUSD"
TV_SYMBOL = "OANDA:XAUUSD"
AI_SERVER_URL = "http://127.0.0.1:8000"
WHATSAPP_API_URL = "https://psychobot-1si7.onrender.com"


# ─────────────────────────────────────────────────────────────
# TradingView MCP Tool Calls
# ─────────────────────────────────────────────────────────────

async def get_tv_quote() -> Optional[Dict]:
    """Récupère le prix live XAUUSD depuis TradingView."""
    try:
        # Simulé — en réalité appel au MCP tool
        # mcp__tradingview-kola__quote_get(symbol="OANDA:XAUUSD")
        logger.info("Calling TradingView quote_get...")
        # Pour l'instant : retourner un dict vide, sera appelé via MCP
        return {"symbol": TV_SYMBOL, "last": 0, "OHLC": {}}
    except Exception as e:
        logger.error(f"❌ TV quote: {e}")
        return None


async def get_tv_study_values() -> Optional[Dict]:
    """Récupère les valeurs des indicateurs : VWAP, BB, ST, Fibo, RSI."""
    try:
        logger.info("Calling TradingView data_get_study_values...")
        # mcp__tradingview-kola__data_get_study_values
        return {}
    except Exception as e:
        logger.error(f"❌ TV study values: {e}")
        return None


async def get_tv_gom_tables() -> Optional[Dict]:
    """Récupère les tables Pine du GOM KOLA (verdict, scores, spike)."""
    try:
        logger.info("Calling TradingView data_get_pine_tables for GOM...")
        # mcp__tradingview-kola__data_get_pine_tables(study_filter="GOM KOLA")
        return {}
    except Exception as e:
        logger.error(f"❌ TV GOM tables: {e}")
        return None


# ─────────────────────────────────────────────────────────────
# AI Server REST Calls
# ─────────────────────────────────────────────────────────────

async def get_session_bias() -> Optional[Dict]:
    """Récupère le biais session depuis AI server."""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{AI_SERVER_URL}/session-bias",
                params={"symbol": SYMBOL},
                timeout=aiohttp.ClientTimeout(total=10),
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    logger.info("✅ Session bias retrieved")
                    return data.get("data")
                logger.warning(f"Session bias HTTP {resp.status}")
                return None
    except Exception as e:
        logger.error(f"❌ Session bias: {e}")
        return None


async def get_pending_order() -> Optional[Dict]:
    """Récupère l'ordre pending de l'AI server."""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{AI_SERVER_URL}/pending-order",
                params={"symbol": SYMBOL},
                timeout=aiohttp.ClientTimeout(total=10),
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    if data.get("ok") and data.get("orders"):
                        logger.info("✅ Pending order retrieved")
                        return data["orders"][0]
                    return None
                logger.warning(f"Pending order HTTP {resp.status}")
                return None
    except Exception as e:
        logger.error(f"❌ Pending order: {e}")
        return None


async def get_gom_verdict() -> Optional[Dict]:
    """Récupère le verdict GOM depuis AI server."""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{AI_SERVER_URL}/gom-verdict",
                params={"symbol": SYMBOL},
                timeout=aiohttp.ClientTimeout(total=10),
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    if data.get("ok"):
                        logger.info("✅ GOM verdict retrieved")
                        return data
                return None
    except Exception as e:
        logger.error(f"❌ GOM verdict: {e}")
        return None


async def get_ta_report() -> Optional[Dict]:
    """Récupère le rapport TradingAgents depuis AI server."""
    try:
        async with aiohttp.ClientSession() as session:
            async with session.get(
                f"{AI_SERVER_URL}/tradingagents/report-status",
                params={"symbol": SYMBOL},
                timeout=aiohttp.ClientTimeout(total=10),
            ) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    logger.info("✅ TradingAgents report retrieved")
                    return data
                return None
    except Exception as e:
        logger.error(f"❌ TradingAgents report: {e}")
        return None


# ─────────────────────────────────────────────────────────────
# Message Builder
# ─────────────────────────────────────────────────────────────

def build_message(
    price: Optional[float],
    gom: Optional[Dict],
    bias: Optional[Dict],
    order: Optional[Dict],
    ta_report: Optional[Dict],
) -> str:
    """Construit le message WhatsApp unifié."""
    ts = datetime.utcnow().strftime("%d/%m %H:%M UTC")
    ts_short = datetime.utcnow().strftime("%H:%M UTC")
    lines = []

    # ── HEADER ───────────────────────────────────────────────
    lines.append(f"📊 TradBOT [{ts_short}]")
    lines.append("")
    lines.append(f"*XAUUSD — Suivi 20min* | {ts}")
    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── PRIX & NIVEAUX CLÉS ──────────────────────────────────
    if price:
        lines.append(f"💰 *Prix live :* ${price:.2f}")
    else:
        lines.append("💰 *Prix live :* ⚠️ AI server hors ligne")

    if gom:
        vwap = gom.get("vwap")
        bb_up = gom.get("bb_up")
        bb_mid = gom.get("bb_mid")
        bb_dn = gom.get("bb_dn")
        st = gom.get("st_line")
        st_dir = gom.get("st_dir", 0)

        if price and vwap:
            rel_vwap = "✅ AU-DESSUS" if price > vwap else "🔴 EN-DESSOUS"
            lines.append(f"📍 VWAP : ${vwap:.2f} → prix {rel_vwap}")

        if bb_mid and bb_up and bb_dn:
            if price and price > bb_up:
                bb_pos = "🔴 AU-DESSUS BB Sup → survente possible"
            elif price and price < bb_dn:
                bb_pos = "🟢 SOUS BB Inf → survendu"
            elif price and price > bb_mid:
                bb_pos = "📈 au-dessus BB Mid"
            else:
                bb_pos = "📉 sous BB Mid"
            lines.append(f"📊 BB : [{bb_dn:.2f} / {bb_mid:.2f} / {bb_up:.2f}] → {bb_pos}")

        if st:
            st_sym = "▲ Haussier" if st_dir == 1 else "▼ Baissier"
            rel_st = "✅ prix AU-DESSUS" if price and price > st else "🔴 prix EN-DESSOUS"
            lines.append(f"⚡ Supertrend : ${st:.2f} ({st_sym}) → {rel_st}")

    else:
        lines.append("📊 *Indicateurs :* ⚠️ AI server hors ligne")

    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── VERDICT GOM KOLA ────────────────────────────────────
    if gom:
        verdict = gom.get("verdict", "INCONNU")
        score_buy = gom.get("score_buy", 0.0)
        score_sell = gom.get("score_sell", 0.0)
        spike_pct = gom.get("spike_pct", 0)
        rsi = gom.get("rsi")

        verdict_emoji = "🟢" if verdict == "BUY" else "🔴" if verdict == "SELL" else "🟡"
        lines.append(f"{verdict_emoji} *Verdict GOM KOLA : {verdict}*")
        lines.append(f"   Score BUY={score_buy:.1f}  SELL={score_sell:.1f}  Spike={spike_pct:.0f}%")
        if rsi:
            lines.append(f"   RSI={rsi:.0f}")
    else:
        lines.append("🟡 *Verdict GOM KOLA :* ⚠️ non disponible")

    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── BIAIS SESSION ───────────────────────────────────────
    if bias:
        direction = bias.get("direction", "UNKNOWN")
        confidence = (bias.get("confidence") or 0) * 100
        valid = bias.get("valid", False)
        expires = bias.get("expires_in_hours", 0)
        bias_emoji = (
            "🟢"
            if direction in ("BUY", "STRONG_BUY")
            else "🔴"
            if direction in ("SELL", "STRONG_SELL")
            else "🟡"
        )
        valid_str = f"✅ valide {expires:.1f}h" if valid else "❌ expiré"
        lines.append(f"{bias_emoji} *Biais session :* {direction} {confidence:.0f}% | {valid_str}")
    else:
        lines.append("🟡 *Biais session :* ⚠️ non disponible")

    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── ORDRE EN ATTENTE ────────────────────────────────────
    if order:
        action = order.get("action", "?")
        entry = order.get("entry_price")
        sl = order.get("stop_loss")
        tp = order.get("take_profit")
        conf = (order.get("confidence") or 0) * 100
        exec_type = order.get("execution_type", "limit").upper()
        order_emoji = "🟢" if action == "BUY" else "🔴"

        lines.append(f"{order_emoji} *Ordre EA :* {exec_type} {action}")
        if entry:
            lines.append(f"   Entrée : ${entry:.2f}")
        if sl:
            lines.append(f"   SL : ${sl:.2f}")
        if tp:
            lines.append(f"   TP : ${tp:.2f}")
        lines.append(f"   Confiance : {conf:.0f}%")

        if entry and sl and tp:
            rr = abs(tp - entry) / abs(sl - entry) if sl != entry else 0
            lines.append(f"   R:R = 1:{rr:.1f}")
    else:
        lines.append("📭 *Aucun ordre EA actif*")

    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── RAPPORT TRADINGAGENTS ────────────────────────────────────
    if ta_report and ta_report.get("ok"):
        ta_dir = ta_report.get("direction", "HOLD")
        ta_conf = (ta_report.get("confidence") or 0) * 100
        ta_age = ta_report.get("age_minutes", 0)
        ta_exp = ta_report.get("expires_in_minutes", 0)
        ta_entry = ta_report.get("entry_price")
        ta_sl = ta_report.get("stop_loss")
        ta_tp = ta_report.get("take_profit")
        ta_emoji = "🟢" if ta_dir == "BUY" else "🔴" if ta_dir == "SELL" else "🟡"
        lines.append(f"{ta_emoji} *Rapport TradingAgents :* {ta_dir} {ta_conf:.0f}%")
        lines.append(f"   Age : {ta_age:.0f}min | Expire dans : {ta_exp:.0f}min")
        if ta_entry:
            lines.append(f"   Entrée TA : ${ta_entry:.2f}")
        if ta_sl:
            lines.append(f"   SL TA : ${ta_sl:.2f}")
        if ta_tp:
            lines.append(f"   TP TA : ${ta_tp:.2f}")
    else:
        lines.append("🔘 *Rapport TradingAgents :* aucun rapport actif")

    lines.append("━━━━━━━━━━━━━━━━━━━━")

    # ── ANALYSE CROISÉE ─────────────────────────────────────
    lines.append("🔬 *Analyse croisée*")

    confluence_signals = []
    conflict_signals = []

    if gom and bias:
        gom_verdict = gom.get("verdict", "WAIT")
        bias_dir = bias.get("direction", "UNKNOWN")
        bias_valid = bias.get("valid", False)

        gom_bull = gom_verdict == "BUY"
        gom_bear = gom_verdict == "SELL"
        bias_bull = bias_dir in ("BUY", "STRONG_BUY") and bias_valid
        bias_bear = bias_dir in ("SELL", "STRONG_SELL") and bias_valid

        if gom_bull and bias_bull:
            confluence_signals.append("✅ GOM BUY + Biais BUY → setup haussier confirmé")
        elif gom_bear and bias_bear:
            confluence_signals.append("✅ GOM SELL + Biais SELL → setup baissier confirmé")
        elif gom_bull and bias_bear:
            conflict_signals.append("⚠️ GOM BUY ≠ Biais SELL → correction probable")
        elif gom_bear and bias_bull:
            conflict_signals.append("⚠️ GOM SELL ≠ Biais BUY → correction probable")

    if gom:
        spike = gom.get("spike_pct", 0)
        if spike >= 62:
            confluence_signals.append(f"⚡ Spike {spike:.0f}% → entrée imminente")
        elif spike >= 52:
            confluence_signals.append(f"🔔 Spike précoce {spike:.0f}%")

    # Verdict final
    if confluence_signals:
        for s in confluence_signals:
            lines.append(f"  {s}")
    if conflict_signals:
        for s in conflict_signals:
            lines.append(f"  {s}")
    if not confluence_signals and not conflict_signals:
        lines.append("  🟡 Données insuffisantes")

    lines.append("━━━━━━━━━━━━━━━━━━━━")
    lines.append("_Prochain check dans 20 min_")

    return "\n".join(lines)


# ─────────────────────────────────────────────────────────────
# WhatsApp Send
# ─────────────────────────────────────────────────────────────

def send_whatsapp(phone: str, message: str) -> bool:
    """Envoie le message via PsychoBot."""
    alert_file = "whatsapp_alerts.log"
    ts = datetime.utcnow().strftime("%H:%M UTC")
    full_msg = f"📊 TradBOT [{ts}]\n\n{message}"

    try:
        with open(alert_file, "a", encoding="utf-8") as f:
            f.write(f"\n{'='*60}\n{datetime.utcnow().isoformat()}\n{full_msg}\n")

        r = requests.post(
            f"{WHATSAPP_API_URL}/send-message",
            json={"phone": phone, "message": full_msg},
            timeout=30,
        )
        if r.status_code == 200 and r.json().get("success"):
            logger.info(f"✅ WhatsApp envoyé : {len(full_msg)} chars")
            return True
        logger.error(f"❌ PsychoBot: {r.text}")
        return False
    except Exception as e:
        logger.error(f"❌ Envoi WhatsApp: {e}")
        return False


# ─────────────────────────────────────────────────────────────
# Main Orchestration
# ─────────────────────────────────────────────────────────────

async def collect_all_data() -> tuple:
    """Collecte TOUTES les données en parallèle."""
    logger.info("🚀 Démarrage collection parallèle...")

    # Appels AI server en parallèle (aiohttp)
    bias_task = get_session_bias()
    order_task = get_pending_order()
    gom_task = get_gom_verdict()
    ta_task = get_ta_report()

    # Appels TradingView (à implémenter avec MCP tools)
    # Pour l'instant, on suppose les données viennent du GOM verdict et bias
    tv_quote_task = get_tv_quote()
    tv_study_task = get_tv_study_values()
    tv_gom_task = get_tv_gom_tables()

    # Attendre tous les résultats en parallèle
    (bias, order, gom, ta_report, tv_quote, tv_study, tv_gom) = await asyncio.gather(
        bias_task,
        order_task,
        gom_task,
        ta_task,
        tv_quote_task,
        tv_study_task,
        tv_gom_task,
    )

    logger.info("✅ Collection complétée")

    # Extraire prix depuis GOM (qui a les data TradingView)
    price = gom.get("price") if gom else None

    return price, gom, bias, order, ta_report


async def main(phone: str):
    """Main entry point."""
    logger.info(f"🎯 Unified WhatsApp Collector START — {phone}")

    # Collecter toutes les données
    price, gom, bias, order, ta_report = await collect_all_data()

    # Construire message
    message = build_message(price, gom, bias, order, ta_report)

    # Afficher
    print("\n" + "=" * 60)
    print(message)
    print("=" * 60 + "\n")

    # Envoyer
    success = send_whatsapp(phone, message)

    if success:
        logger.info("✅ SUCCESS — Message envoyé via PsychoBot")
    else:
        logger.warning("⚠️ Message sauvegardé dans whatsapp_alerts.log")


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser()
    parser.add_argument("--phone", default="+2290196911346")
    args = parser.parse_args()

    asyncio.run(main(args.phone))
