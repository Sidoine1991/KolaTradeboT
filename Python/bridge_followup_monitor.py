# -*- coding: utf-8 -*-
"""
Suivi pending order + biais session — message WhatsApp unifié toutes les 10 minutes.

Usage:
  python python/bridge_followup_monitor.py --symbol "BOOM 600 INDEX" --interval 600
  python python/bridge_followup_monitor.py --symbol XAUUSD --phone +229...
"""

from __future__ import annotations

import argparse
import os
import sys
import time
from datetime import datetime
from typing import Any, Dict, Optional

import requests

from unified_bridge import format_unified_whatsapp, send_unified_whatsapp

_SERVER = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000").rstrip("/")
_PHONE = os.getenv("WHATSAPP_PHONE_NUMBER", "+2290196911346")


def _clean_symbol(s: str) -> str:
    import re
    u = s.strip().upper()
    u = re.sub(r"\(.*?\)", "", u).strip()
    u = re.sub(r"[—–→].*", "", u).strip()
    return u or s.upper()


def get_pending(symbol: str) -> Optional[Dict[str, Any]]:
    try:
        r = requests.get(
            f"{_SERVER}/pending-order",
            params={"symbol": symbol},
            timeout=8,
        )
        if r.status_code != 200:
            return None
        data = r.json()
        return data.get("order")
    except Exception:
        return None


def get_session_bias(symbol: str) -> Optional[Dict[str, Any]]:
    try:
        r = requests.get(
            f"{_SERVER}/session-bias",
            params={"symbol": symbol},
            timeout=8,
        )
        if r.status_code != 200:
            return None
        return r.json().get("data")
    except Exception:
        return None


def get_unified_state(symbol: str) -> Optional[Dict[str, Any]]:
    try:
        r = requests.get(
            f"{_SERVER}/bridge/unified-signal",
            params={"symbol": symbol},
            timeout=8,
        )
        if r.status_code == 200:
            return r.json().get("data")
    except Exception:
        pass
    return None


def build_followup_message(symbol: str) -> str:
    sym = _clean_symbol(symbol)
    pending = get_pending(sym)
    bias = get_session_bias(sym)
    state = get_unified_state(sym) or {}

    ts = datetime.utcnow().strftime("%Y-%m-%d %H:%M UTC")
    lines = [
        f"*SUIVI TradBOT* [{ts}]",
        f"Symbole: *{symbol}*",
        "",
    ]

    comp = state.get("comparison") or {}
    tv = state.get("tv_summary") or {}
    conf = state.get("confirmed") or {}

    if comp:
        lines.append(f"Convergence: {comp.get('verdict', '—')} — {comp.get('message', '')}")
    if tv.get("direction"):
        lines.append(f"TV SMC: {tv.get('direction')} | prix chart: {tv.get('current_price', '—')}")

    if bias:
        lines.append(
            f"Biais session: {bias.get('direction')} "
            f"({float(bias.get('confidence', 0)) * 100:.0f}%) "
            f"{'✅' if bias.get('valid') else '❌ expiré'}"
        )

    if pending:
        lines.extend([
            "",
            "━━━━━━━━━━━━━━━━━━━━",
            "*Pending order actif*",
            "━━━━━━━━━━━━━━━━━━━━",
            f"Action: {pending.get('action') or pending.get('recommendation')}",
            f"Entry: {pending.get('entry_price')}",
            f"SL: {pending.get('stop_loss')}",
            f"TP: {pending.get('take_profit')}",
            f"Lot: {pending.get('lot')}",
            f"Depuis: {pending.get('timestamp', '—')}",
        ])
    else:
        lines.append("\n⏸ Aucun pending order en file (exécuté ou non placé).")

    if conf:
        lines.append(
            f"\nSignal initial: {conf.get('recommendation')} "
            f"conf={float(conf.get('confidence', 0)):.0%}"
        )

    lines.append("\n_Prochain suivi dans 10 min_")
    return "\n".join(lines)


def main() -> None:
    p = argparse.ArgumentParser(description="Suivi bridge WhatsApp 10 min")
    p.add_argument("--symbol", "-s", default="XAUUSD")
    p.add_argument("--interval", "-i", type=int, default=600)
    p.add_argument("--phone", default=_PHONE)
    p.add_argument("--once", action="store_true", help="Un seul envoi puis quitter")
    args = p.parse_args()

    print(f"[followup] {args.symbol} | interval={args.interval}s | {args.phone}")

    while True:
        msg = build_followup_message(args.symbol)
        send_unified_whatsapp(msg, phone=args.phone)
        if args.once:
            break
        time.sleep(max(60, args.interval))


if __name__ == "__main__":
    main()
