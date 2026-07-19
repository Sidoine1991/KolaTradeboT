#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Simple Multi-Terminal Poller
=================================
Version simplifiée qui utilise le serveur AI existant
au lieu de recalculer localement (évite les problèmes de connexion MT5)

Flux:
    AI Server (localhost:8000) → /gom-verdict
        ↓
    Demande pour symboles Deriv ET Weltrade
        ↓
    Stocke en mémoire (g_gom_verdicts dans SMC_Universal)

Usage:
    python python/gom_poller_simple_multiterminal.py
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Tuple
from urllib.parse import quote

import requests

ROOT = Path(__file__).resolve().parent.parent
AI_SERVER_URL = "http://127.0.0.1:8000"

# Fenêtres de trading UTC par symbole (heure_début incluse, heure_fin exclusive).
# Basé sur analyse de ~6000 polls (2026-06-18/20) :
#   Weltrade PainX/GainX/FXVol → zone active 00h-16h (46-97%), morte 17h-23h (14-30%)
#   Deriv Boom/Crash/XAUUSD → géré côté ai_server (bc_heure gate)
_WELTRADE_WINDOWS: Dict[str, List[Tuple[int, int]]] = {
    "PAINX":  [(4, 16)],
    "GAINX":  [(4, 16)],
    "FXVOL":  [(4, 16)],
    "SFVVOL": [(4, 16)],
    "SFXVOL": [(4, 16)],
}


def _in_weltrade_window(symbol: str) -> bool:
    """Retourne False si le symbole Weltrade est hors de sa fenêtre horaire UTC."""
    utc_hour = datetime.now(timezone.utc).hour
    key = symbol.upper().replace(" ", "")
    for prefix, windows in _WELTRADE_WINDOWS.items():
        if key.startswith(prefix):
            in_window = any(start <= utc_hour < end for start, end in windows)
            if not in_window:
                log.warning(
                    "[GATE-SESSION] %s: heure UTC %02dh hors fenêtre propice %s — poll ignoré",
                    symbol, utc_hour, windows,
                )
            return in_window
    return True  # Symboles Deriv → pas de gate ici

(ROOT / "logs").mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [GOM-SimplePoller] %(message)s",
    handlers=[
        logging.StreamHandler(
            open(sys.stdout.fileno(), mode="w", encoding="utf-8", closefd=False)
        ),
        logging.FileHandler(str(ROOT / "logs" / "gom_simple_multiterminal_poller.log"), encoding="utf-8"),
    ],
)
log = logging.getLogger(__name__)

# Symboles à pollster
SYMBOLS = {
    "deriv": [
        "Boom 50 Index",
        "Boom 150 Index",
        "Boom 300 Index",
        "Boom 500 Index",
        "Boom 600 Index",
        "Boom 900 Index",
        "Boom 1000 Index",
        "Crash 150 Index",
        "Crash 500 Index",
        "Crash 1000 Index",
        "XAUUSD",
    ],
    "weltrade": [
        # Noms MT5 exacts sur terminal Weltrade (F016)
        "PainX 600",
        "PainX 1200",
        "GainX 400",
        "GainX 600",
        "GainX 800",
        "GainX 1200",
        "FX Vol 20",
    ]
}


def wait_for_ai_server(retries: int = 10, delay_sec: float = 3.0) -> bool:
    """Attend que ai_server soit disponible avant de poller."""
    for attempt in range(1, retries + 1):
        try:
            r = requests.get(f"{AI_SERVER_URL}/health", timeout=5)
            if r.status_code == 200:
                log.info("AI server OK (%s)", AI_SERVER_URL)
                return True
        except Exception as exc:
            log.warning("AI server indisponible (%d/%d): %s", attempt, retries, exc)
        time.sleep(delay_sec)
    return False


def poll_symbol(symbol: str, terminal: str) -> bool:
    """Récupère le verdict GOM pour un symbole via le serveur AI."""
    try:
        url = (
            f"{AI_SERVER_URL}/gom-verdict"
            f"?symbol={quote(symbol)}&chart_tf=M1&source=local"
        )
        r = requests.get(url, timeout=15)

        if r.status_code == 200:
            data = r.json()
            verdict = data.get("verdict") or data.get("action", "HOLD")
            vn = data.get("verdict_num", 0)
            coherence = data.get("coherence", data.get("gom_coherence", 0))

            log.info(
                "[%-9s] %-20s → %-13s vn=%s | coh=%s",
                terminal.upper(),
                symbol,
                verdict,
                vn,
                coherence,
            )
            return data.get("ok", True)
        else:
            log.warning("[%-9s] %-20s — HTTP %d", terminal.upper(), symbol, r.status_code)
            return False

    except Exception as e:
        log.error("[%-9s] %-20s — %s", terminal.upper(), symbol, e)
        return False


def run_tour() -> dict:
    """Un tour complet: tous les symboles, tous les terminaux."""
    if not wait_for_ai_server():
        log.error("AI server injoignable sur %s — tour annulé", AI_SERVER_URL)
        return {"deriv": 0, "weltrade": 0}

    log.info("═" * 70)
    log.info("TOUR: Polling Deriv + Weltrade symbols")
    log.info("═" * 70)

    results = {"deriv": 0, "weltrade": 0}

    # Poll Deriv symbols
    log.info("\n[1/2] Deriv Terminal...")
    for symbol in SYMBOLS["deriv"]:
        if poll_symbol(symbol, "deriv"):
            results["deriv"] += 1

    # Poll Weltrade symbols
    log.info("\n[2/2] Weltrade Terminal...")
    for symbol in SYMBOLS["weltrade"]:
        if not _in_weltrade_window(symbol):
            continue
        if poll_symbol(symbol, "weltrade"):
            results["weltrade"] += 1

    log.info("\n" + "─" * 70)
    log.info(
        "TOUR RESULT: Deriv %d/%d OK | Weltrade %d/%d OK",
        results["deriv"],
        len(SYMBOLS["deriv"]),
        results["weltrade"],
        len(SYMBOLS["weltrade"]),
    )
    log.info("─" * 70 + "\n")

    return results


def main():
    parser = argparse.ArgumentParser(description="GOM Simple Multi-Terminal Poller")
    parser.add_argument("--interval", type=int, default=30, help="Interval en secondes")
    parser.add_argument("--once", action="store_true", help="Un seul tour puis exit")

    args = parser.parse_args()

    log.info("═" * 70)
    log.info("GOM SIMPLE MULTI-TERMINAL POLLER")
    log.info("AI Server: %s", AI_SERVER_URL)
    log.info("Interval: %ds", args.interval)
    log.info("Mode: %s", "ONCE" if args.once else "LOOP")
    log.info("═" * 70 + "\n")

    if args.once:
        run_tour()
        return 0

    # Boucle infinie
    tour_num = 0
    try:
        while True:
            tour_num += 1
            log.info("TOUR #%d — %s", tour_num, datetime.now(timezone.utc).isoformat())

            try:
                run_tour()
            except Exception as e:
                log.error("TOUR FAILED: %s", e)
                traceback.print_exc()

            log.info("Waiting %ds before next tour...\n", args.interval)
            time.sleep(args.interval)

    except KeyboardInterrupt:
        log.info("\n[*] GOM Simple Multi-Terminal Poller stopped by user")
        return 0
    except Exception as e:
        log.error("FATAL: %s", e)
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
