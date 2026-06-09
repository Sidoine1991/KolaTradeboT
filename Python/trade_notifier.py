#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Trade Notifier — surveille l'exécution et la fermeture des trades.
Envoie une notif WhatsApp à chaque événement clé :
  - Ordre exécuté (pending → plus de pending)
  - Trade fermé (profit/perte via /mt5/deals-upload ou polling positions)
  - Suivi toutes les N minutes avec P&L courant

Usage:
  python Python/trade_notifier.py --symbol XAUUSD --direction BUY --entry 4444.36 --sl 4431.87 --tp 4465.79
"""

import sys
import os
import io
import time
import json
import argparse
import logging
import requests
from datetime import datetime, timezone
from pathlib import Path

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8")

_HERE    = Path(__file__).resolve().parent
_ROOT    = _HERE.parent
_LOG_DIR = _ROOT / "logs"
_LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [Notifier] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(_LOG_DIR / "trade_notifier.log", encoding="utf-8"),
    ],
)
log = logging.getLogger("notifier")

_SERVER       = os.getenv("AI_SERVER_URL",        "http://127.0.0.1:8000").rstrip("/")
_PSYCHOBOT    = os.getenv("PSYCHOBOT_URL",         "https://psychobot-1si7.onrender.com")
_PHONE        = os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")
_POLL_SEC     = 15       # check toutes les 15s si exécuté
_FOLLOWUP_SEC = 600      # suivi P&L toutes les 10min
_MAX_WAIT_SEC = 1800     # 30min max pour l'exécution


def _wa(msg: str) -> bool:
    try:
        r = requests.post(
            f"{_PSYCHOBOT}/send-message",
            json={"phone": _PHONE, "message": msg},
            timeout=10, verify=False,
        )
        return r.status_code == 200
    except Exception as e:
        log.warning("WhatsApp non envoyé: %s", e)
        return False


def _get_pending(symbol: str) -> dict | None:
    try:
        r = requests.get(f"{_SERVER}/pending-order",
                         params={"symbol": symbol}, timeout=5)
        if r.status_code == 200:
            d = r.json()
            return d.get("order") if d.get("ok") else None
    except Exception:
        pass
    return None


def _get_gom(symbol: str) -> dict:
    try:
        r = requests.get(f"{_SERVER}/gom-verdict",
                         params={"symbol": symbol}, timeout=5)
        if r.status_code == 200:
            return r.json()
    except Exception:
        pass
    return {}


def _get_deals(symbol: str, since_ts: float) -> list:
    """Récupère les deals MT5 uploadés via /mt5/deals-upload depuis since_ts."""
    try:
        r = requests.get(f"{_SERVER}/mt5/deals-upload",
                         params={"symbol": symbol}, timeout=5)
        if r.status_code == 200:
            deals = r.json().get("deals", [])
            return [d for d in deals if float(d.get("timestamp", 0)) >= since_ts]
    except Exception:
        pass
    return []


def _pnl_from_gom(symbol: str, direction: str, entry: float) -> str:
    """Estime le P&L courant depuis le prix GOM."""
    gom = _get_gom(symbol)
    price = gom.get("price")
    if not price:
        return "P&L: N/A (prix non disponible)"
    price = float(price)
    diff  = (price - entry) if direction == "BUY" else (entry - price)
    emoji = "🟢" if diff >= 0 else "🔴"
    return f"P&L courant: {emoji} {diff:+.2f} pts ({price:.2f} actuel)"


def watch(symbol: str, direction: str, entry: float,
          sl: float, tp: float, lot: float):

    log.info("Surveillance: %s %s entry=%.2f SL=%.2f TP=%.2f lot=%s",
             symbol, direction, entry, sl, tp, lot)

    now_ts     = time.time()
    executed   = False
    closed     = False
    exec_time  = None
    last_followup = now_ts

    # ── Phase 1 : attendre exécution ──────────────────────────────
    log.info("Phase 1: attente exécution (max %ds)...", _MAX_WAIT_SEC)
    deadline = now_ts + _MAX_WAIT_SEC

    while not executed and time.time() < deadline:
        time.sleep(_POLL_SEC)
        pending = _get_pending(symbol)

        if pending is None:
            # Pending disparu → ordre exécuté (EA l'a consommé)
            executed  = True
            exec_time = time.time()
            elapsed   = int(exec_time - now_ts)
            gom       = _get_gom(symbol)
            price_now = gom.get("price", entry)

            log.info("✅ Exécuté après %ds", elapsed)
            dir_emoji = "🟢" if direction == "BUY" else "🔴"
            _wa(
                f"*TradBOT — Ordre exécuté* ✅\n"
                f"_{datetime.now(timezone.utc).strftime('%H:%M UTC')}_\n\n"
                f"{dir_emoji} *{symbol}* {direction}\n"
                f"Entry : *{entry}*\n"
                f"SL    : {sl}\n"
                f"TP    : {tp}\n"
                f"Lot   : {lot}\n"
                f"Prix  : {price_now}\n\n"
                f"Suivi P&L toutes les 10min."
            )
            break

        # Pendant l'attente : suivi périodique si order toujours là
        if time.time() - last_followup >= _FOLLOWUP_SEC:
            pnl_str = _pnl_from_gom(symbol, direction, entry)
            gom     = _get_gom(symbol)
            log.info("Suivi attente: order toujours pending | %s", pnl_str)
            _wa(
                f"*TradBOT — Suivi* [{datetime.now(timezone.utc).strftime('%H:%M UTC')}]\n"
                f"{symbol} {direction} — *En attente d'exécution*\n"
                f"Entry cible: {entry}\n"
                f"{pnl_str}\n"
                f"GOM: {gom.get('verdict','?')} ({gom.get('score_buy',0):.1f}↑/{gom.get('score_sell',0):.1f}↓)"
            )
            last_followup = time.time()

    if not executed:
        log.warning("Timeout — ordre non exécuté après %ds", _MAX_WAIT_SEC)
        _wa(
            f"*TradBOT — ⚠️ Ordre non exécuté*\n"
            f"{symbol} {direction} toujours pending après 30 minutes.\n"
            f"Vérifier MT5 manuellement."
        )
        return

    # ── Phase 2 : surveiller jusqu'à fermeture ────────────────────
    log.info("Phase 2: surveillance P&L jusqu'à fermeture...")
    last_followup = time.time()
    peak_pnl      = 0.0

    while not closed:
        time.sleep(_POLL_SEC)

        gom       = _get_gom(symbol)
        price_now = gom.get("price")
        if not price_now:
            continue
        price_now = float(price_now)

        pnl_pts = (price_now - entry) if direction == "BUY" else (entry - price_now)
        if pnl_pts > peak_pnl:
            peak_pnl = pnl_pts

        # Vérifier si TP ou SL touché
        tp_hit = (direction == "BUY"  and price_now >= tp) or \
                 (direction == "SELL" and price_now <= tp)
        sl_hit = (direction == "BUY"  and price_now <= sl) or \
                 (direction == "SELL" and price_now >= sl)

        if tp_hit or sl_hit:
            closed     = True
            result     = "TP ✅ PROFIT" if tp_hit else "SL ❌ PERTE"
            pnl_usd    = round(pnl_pts * lot * 100, 2)
            emoji      = "🟢💰" if tp_hit else "🔴💸"
            log.info("Trade fermé: %s | P&L=%.2f pts ($%.2f)", result, pnl_pts, pnl_usd)

            _wa(
                f"*TradBOT — Trade fermé* {emoji}\n"
                f"_{datetime.now(timezone.utc).strftime('%H:%M UTC')}_\n\n"
                f"*{symbol}* {direction} → *{result}*\n\n"
                f"Entry  : {entry}\n"
                f"Sortie : {price_now:.2f}\n"
                f"P&L    : *{pnl_pts:+.2f} pts* (~${pnl_usd:+.2f})\n"
                f"Peak   : +{peak_pnl:.2f} pts\n"
                f"Lot    : {lot}"
            )
            break

        # Suivi périodique P&L
        if time.time() - last_followup >= _FOLLOWUP_SEC:
            emoji = "🟢" if pnl_pts >= 0 else "🔴"
            sl_dist = abs(price_now - sl)
            tp_dist = abs(tp - price_now)
            log.info("P&L: %+.2f pts | prix=%.2f | SL à %.2f | TP à %.2f",
                     pnl_pts, price_now, sl_dist, tp_dist)
            _wa(
                f"*TradBOT — Suivi trade* [{datetime.now(timezone.utc).strftime('%H:%M UTC')}]\n"
                f"{emoji} *{symbol}* {direction}\n\n"
                f"Prix actuel : {price_now:.2f}\n"
                f"P&L         : *{pnl_pts:+.2f} pts*\n"
                f"→ SL dans   : {sl_dist:.2f} pts\n"
                f"→ TP dans   : {tp_dist:.2f} pts\n"
                f"Peak        : +{peak_pnl:.2f} pts\n"
                f"GOM         : {gom.get('verdict','?')} score={gom.get('score_buy',0):.1f}"
            )
            last_followup = time.time()


def main():
    parser = argparse.ArgumentParser(description="Trade Notifier — suivi exécution et fermeture")
    parser.add_argument("--symbol",    required=True)
    parser.add_argument("--direction", required=True, choices=["BUY","SELL"])
    parser.add_argument("--entry",     type=float, required=True)
    parser.add_argument("--sl",        type=float, required=True)
    parser.add_argument("--tp",        type=float, required=True)
    parser.add_argument("--lot",       type=float, default=0.01)
    args = parser.parse_args()

    watch(
        symbol    = args.symbol.upper(),
        direction = args.direction.upper(),
        entry     = args.entry,
        sl        = args.sl,
        tp        = args.tp,
        lot       = args.lot,
    )


if __name__ == "__main__":
    main()
