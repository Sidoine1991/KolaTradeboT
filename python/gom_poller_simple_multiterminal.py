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
import os
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Dict, List, Optional, Tuple
from urllib.parse import quote

import requests
from requests.adapters import HTTPAdapter

ROOT = Path(__file__).resolve().parent.parent
AI_SERVER_URL = os.getenv("AI_SERVER_URL", "http://127.0.0.1:8000").rstrip("/")
HEALTH_RETRIES = int(os.getenv("GOM_HEALTH_RETRIES", "2"))
HEALTH_TIMEOUT_SEC = float(os.getenv("GOM_HEALTH_TIMEOUT_SEC", "2"))
HEALTH_DELAY_SEC = float(os.getenv("GOM_HEALTH_DELAY_SEC", "1"))
POLL_TIMEOUT_SEC = float(os.getenv("GOM_POLL_TIMEOUT_SEC", "12"))
BACKOFF_MIN_SEC = float(os.getenv("GOM_AI_BACKOFF_MIN_SEC", "15"))
BACKOFF_MAX_SEC = float(os.getenv("GOM_AI_BACKOFF_MAX_SEC", "120"))

# Session HTTP sans retry urllib3 (évite "Max retries exceeded" + attente inutile)
_HTTP = requests.Session()
_HTTP.mount("http://", HTTPAdapter(max_retries=0))
_HTTP.mount("https://", HTTPAdapter(max_retries=0))

# Circuit breaker ai_server
_ai_down_since: Optional[float] = None
_ai_backoff_sec: float = 0.0
_ai_last_warn: float = 0.0

# Fenêtres de trading UTC par symbole (heure_début incluse, heure_fin exclusive).
# Basé sur analyse de ~6000 polls (2026-06-18/20) :
#   Weltrade PainX/GainX/FXVol → zone active 00h-16h (46-97%), morte 17h-23h (14-30%)
#   Deriv Boom/Crash/XAUUSD → géré côté ai_server (bc_heure gate)
#   Exness → Forex/Métaux 24h, Crypto 24h, indices horaires marché
_WELTRADE_WINDOWS: Dict[str, List[Tuple[int, int]]] = {
    "PAINX":  [(4, 23)],
    "GAINX":  [(4, 23)],
    "FXVOL":  [(4, 23)],
    "SFVVOL": [(4, 23)],
    "SFXVOL": [(4, 23)],
}
# Exness: pas de gate horaire (Forex/Métaux 24/5, Crypto 24/7)
_EXNESS_WINDOWS: Dict[str, List[Tuple[int, int]]] = {}


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
    return True  # Symboles Deriv/Exness → pas de gate ici

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
        "Boom 200 Index",
        "Boom 300 Index",
        "Boom 500 Index",
        "Boom 600 Index",
        "Boom 900 Index",
        "Boom 1000 Index",
        "Crash 50 Index",
        "Crash 150 Index",
        "Crash 200 Index",
        "Crash 300 Index",
        "Crash 500 Index",
        "Crash 600 Index",
        "Crash 900 Index",
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
        "SFV Vol",
        "SFX Vol",
    ],
    "exness": [
        # Exness: symboles sans suffixe (le serveur normalise XAUUSD.m → XAUUSD)
        "XAUUSD",
        "EURUSD",
        "GBPUSD",
        "USDJPY",
        "USDCHF",
        "AUDUSD",
        "USDCAD",
        "NZDUSD",
        "EURGBP",
        "EURJPY",
        "GBPJPY",
        "EURAUD",
        "GBPAUD",
        "AUDJPY",
    ],
}


def _is_connection_refused(exc: Exception) -> bool:
    msg = str(exc).lower()
    return (
        "10061" in msg
        or "refused" in msg
        or "econnrefused" in msg
        or "failed to establish a new connection" in msg
    )


def _circuit_open() -> bool:
    global _ai_down_since, _ai_backoff_sec
    if _ai_down_since is None or _ai_backoff_sec <= 0:
        return False
    elapsed = time.monotonic() - _ai_down_since
    return elapsed < _ai_backoff_sec


def _circuit_remaining_sec() -> int:
    if _ai_down_since is None or _ai_backoff_sec <= 0:
        return 0
    return max(0, int(_ai_backoff_sec - (time.monotonic() - _ai_down_since)))


def _mark_ai_down(reason: str) -> None:
    global _ai_down_since, _ai_backoff_sec, _ai_last_warn
    now = time.monotonic()
    if _ai_down_since is None:
        _ai_backoff_sec = BACKOFF_MIN_SEC
    else:
        _ai_backoff_sec = min(BACKOFF_MAX_SEC, max(BACKOFF_MIN_SEC, _ai_backoff_sec * 2))
    _ai_down_since = now
    if now - _ai_last_warn >= 30:
        _ai_last_warn = now
        log.warning(
            "AI server DOWN — %s | backoff %ds (relance: python ai_server.py)",
            reason,
            int(_ai_backoff_sec),
        )


def _mark_ai_up() -> None:
    global _ai_down_since, _ai_backoff_sec, _ai_last_warn
    if _ai_down_since is not None:
        log.info("AI server de retour (%s)", AI_SERVER_URL)
    _ai_down_since = None
    _ai_backoff_sec = 0.0
    _ai_last_warn = 0.0


def wait_for_ai_server(
    retries: int = HEALTH_RETRIES,
    delay_sec: float = HEALTH_DELAY_SEC,
    timeout_sec: float = HEALTH_TIMEOUT_SEC,
) -> bool:
    """Vérifie ai_server — fail-fast si port refusé ou circuit ouvert."""
    global _ai_last_warn

    if _circuit_open():
        remaining = _circuit_remaining_sec()
        if time.monotonic() - _ai_last_warn >= 30:
            _ai_last_warn = time.monotonic()
            log.warning(
                "AI server circuit OPEN — skip health (%ds restant) | %s",
                remaining,
                AI_SERVER_URL,
            )
        return False

    last_exc: Optional[Exception] = None
    for attempt in range(1, retries + 1):
        try:
            r = _HTTP.get(f"{AI_SERVER_URL}/health", timeout=timeout_sec)
            if r.status_code == 200:
                _mark_ai_up()
                return True
            last_exc = RuntimeError(f"HTTP {r.status_code}")
        except Exception as exc:
            last_exc = exc
            if _is_connection_refused(exc):
                _mark_ai_down("connexion refusée (ai_server arrêté?)")
                return False
            if attempt < retries:
                time.sleep(delay_sec)

    reason = str(last_exc) if last_exc else "health check failed"
    _mark_ai_down(reason[:120])
    return False


def poll_symbol(symbol: str, terminal: str) -> bool:
    """Récupère le verdict GOM pour un symbole via le serveur AI."""
    try:
        url = (
            f"{AI_SERVER_URL}/gom-verdict"
            f"?symbol={quote(symbol)}&chart_tf=M1&source=local"
        )
        r = _HTTP.get(url, timeout=POLL_TIMEOUT_SEC)

        if r.status_code == 200:
            data = r.json()
            verdict = data.get("verdict") or data.get("action", "HOLD")
            vn = data.get("verdict_num", 0)
            coherence = data.get("coherence_pct", 0)

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
        if _is_connection_refused(e):
            _mark_ai_down("connexion refusée pendant poll")
        log.error("[%-9s] %-20s — %s", terminal.upper(), symbol, e)
        return False


def run_tour() -> dict:
    """Un tour complet: tous les symboles, tous les terminaux."""
    if not wait_for_ai_server():
        return {"deriv": 0, "weltrade": 0, "exness": 0, "skipped": True}

    log.info("═" * 70)
    log.info("TOUR: Polling Deriv + Weltrade + Exness symbols")
    log.info("═" * 70)

    results = {"deriv": 0, "weltrade": 0, "exness": 0}

    # Poll Deriv symbols
    log.info("\n[1/3] Deriv Terminal...")
    for symbol in SYMBOLS["deriv"]:
        if poll_symbol(symbol, "deriv"):
            results["deriv"] += 1

    # Poll Weltrade symbols
    log.info("\n[2/3] Weltrade Terminal...")
    for symbol in SYMBOLS["weltrade"]:
        if not _in_weltrade_window(symbol):
            continue
        if poll_symbol(symbol, "weltrade"):
            results["weltrade"] += 1

    # Poll Exness symbols
    log.info("\n[3/3] Exness Terminal...")
    for symbol in SYMBOLS["exness"]:
        if poll_symbol(symbol, "exness"):
            results["exness"] += 1

    log.info("\n" + "─" * 70)
    log.info(
        "TOUR RESULT: Deriv %d/%d | Weltrade %d/%d | Exness %d/%d",
        results["deriv"],
        len(SYMBOLS["deriv"]),
        results["weltrade"],
        len(SYMBOLS["weltrade"]),
        results["exness"],
        len(SYMBOLS["exness"]),
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
                results = run_tour()
            except Exception as e:
                log.error("TOUR FAILED: %s", e)
                traceback.print_exc()
                results = {"skipped": True}

            if results.get("skipped"):
                wait_sec = max(args.interval, _circuit_remaining_sec() or BACKOFF_MIN_SEC)
                log.info("Tour ignoré (ai_server) — pause %ds\n", wait_sec)
                time.sleep(wait_sec)
                continue

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
