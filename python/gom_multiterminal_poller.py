#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Multi-Terminal Poller
==========================
Récupère les données GOM depuis DEUX terminaux MT5:
  1. Terminal Deriv (D0E8209F52F57601B1E8F35F5DF18F14)
  2. Terminal Weltrade (F016FF5B93786543B564E81A925D7066)

Flux:
    MT5 Deriv (candles OHLC)
        ↓
    gom_live_calculator.py calcul local
        ↓
    POST /gom-verdict (ai_server :8000)
        ↓
    [Símbolos Deriv: Boom/Crash/Volatility]
    ────────────────────────────────────

    MT5 Weltrade (candles OHLC)
        ↓
    gom_live_calculator.py calcul local
        ↓
    POST /gom-verdict (ai_server :8000)
        ↓
    [Símbolos Weltrade: PAINX/GAINX/FXVOL]

Usage:
    python python/gom_multiterminal_poller.py                # boucle 30s, tous terminaux
    python python/gom_multiterminal_poller.py --once          # un seul calcul
    python python/gom_multiterminal_poller.py --interval 60
"""

from __future__ import annotations

import argparse
import logging
import sys
import time
import traceback
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import requests

ROOT = Path(__file__).resolve().parent.parent
for p in (str(ROOT), str(ROOT / "python")):
    if p not in sys.path:
        sys.path.insert(0, p)

AI_SERVER_URL = "http://127.0.0.1:8000"

# Terminaux MT5 configurés
TERMINALS = {
    "deriv": {
        "path": "D:\\Program Files\\MetaTrader 5 - Deriv",
        "symbols": ["Boom 1000 Index", "Boom 500 Index", "Crash 1000 Index", "Crash 500 Index", "XAUUSD"],
        "enabled": True,
    },
    "weltrade": {
        "path": "D:\\Program Files\\MetaTrader 5 - Copie",
        "symbols": [
            "PainX 600",
            "PainX 1200",
            "GainX 400",
            "GainX 600",
            "GainX 800",
            "GainX 1200",
            "FX Vol 20",
            "SFV Vol",
        ],
        "enabled": True,
    }
}

(ROOT / "logs").mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [GOM-MultiTerminal] %(message)s",
    handlers=[
        logging.StreamHandler(
            open(sys.stdout.fileno(), mode="w", encoding="utf-8", closefd=False)
        ),
        logging.FileHandler(str(ROOT / "logs" / "gom_multiterminal_poller.log"), encoding="utf-8"),
    ],
)
log = logging.getLogger(__name__)


def _push_verdict(payload: Dict[str, Any]) -> bool:
    """Pousse le verdict GOM vers le serveur IA."""
    try:
        r = requests.post(f"{AI_SERVER_URL}/gom-verdict", json=payload, timeout=10)
        if r.ok and r.json().get("ok"):
            log.info(
                "✅ %-20s [%-10s] → %-13s buy=%.1f sell=%.1f coh=%.0f%%",
                payload["symbol"],
                payload.get("terminal", "?"),
                payload["verdict"],
                payload.get("score_buy", 0),
                payload.get("score_sell", 0),
                payload.get("coherence_pct", 0),
            )
            return True
        log.error("❌ /gom-verdict HTTP %s: %s", r.status_code, r.text[:200])
        return False
    except Exception as exc:
        log.error("❌ push %s: %s", payload.get("symbol"), exc)
        return False


_WELTRADE_UTC_PREFIXES = ("PAINX", "GAINX", "FXVOL", "SFVVOL")


def _weltrade_gate_open(symbol: str) -> bool:
    """Retourne False si le symbole Weltrade est hors fenêtre 04h-23h UTC."""
    from datetime import datetime, timezone
    sym = symbol.upper().replace(" ", "")
    for prefix in _WELTRADE_UTC_PREFIXES:
        if sym.startswith(prefix):
            h = datetime.now(timezone.utc).hour
            in_window = 4 <= h < 23
            if not in_window:
                log.info("[GATE] %s: UTC %02dh hors 04h-23h — poll ignore", symbol, h)
            return in_window
    return True


def poll_terminal(terminal_name: str, symbols: List[str]) -> int:
    """Récupère les verdicts GOM pour un terminal MT5."""
    log.info("─── Poll [%s] : %d symboles ───", terminal_name.upper(), len(symbols))

    try:
        # Importe la calculatrice GOM
        from gom_live_calculator import GOMSignalsLiveCalculator

        calc = GOMSignalsLiveCalculator()

        ok_count = 0
        for symbol in symbols:
            if not _weltrade_gate_open(symbol):
                continue
            try:
                # Calcule le verdict GOM pour ce symbole
                resp = calc.build_api_response(symbol)
                if not resp.get("ok"):
                    log.warning("⚠️  %-20s SKIP — %s", symbol, resp.get("error", "no candles"))
                    continue

                # Récupère le payload et ajoute les champs requis
                payload = resp.get("data", {})
                payload["symbol"] = symbol          # IMPORTANT: API requires this
                payload["terminal"] = terminal_name

                # Pousse vers /gom-verdict
                if _push_verdict(payload):
                    ok_count += 1

            except Exception as e:
                log.error("❌ %s: %s", symbol, e)
                traceback.print_exc()

        log.info("─── [%s] terminé : %d/%d OK ───", terminal_name.upper(), ok_count, len(symbols))
        return ok_count

    except Exception as e:
        log.error("❌ poll_terminal [%s]: %s", terminal_name, e)
        traceback.print_exc()
        return 0


def run_tour(terminal_list: List[str]) -> Dict[str, int]:
    """Un tour complet sur tous les terminaux."""
    results: Dict[str, int] = {}

    for term_name in terminal_list:
        if term_name not in TERMINALS:
            log.warning("⚠️  Terminal inconnu: %s", term_name)
            continue

        term_config = TERMINALS[term_name]
        if not term_config.get("enabled"):
            log.debug("⏸  Terminal [%s] désactivé", term_name)
            continue

        symbols = term_config.get("symbols", [])
        ok_count = poll_terminal(term_name, symbols)
        results[term_name] = ok_count

    return results


def main():
    parser = argparse.ArgumentParser(description="GOM Multi-Terminal Poller")
    parser.add_argument("--interval", type=int, default=30, help="Interval en secondes")
    parser.add_argument("--once", action="store_true", help="Un seul tour puis exit")
    parser.add_argument("--terminals", type=str, default="deriv,weltrade", help="Terminaux à pollster (csv)")

    args = parser.parse_args()

    terminal_list = [t.strip() for t in args.terminals.split(",") if t.strip()]

    log.info("═══════════════════════════════════════════════════════")
    log.info("GOM Multi-Terminal Poller démarré")
    log.info("Terminaux: %s", ", ".join(t.upper() for t in terminal_list))
    log.info("Interval: %ds", args.interval)
    log.info("═══════════════════════════════════════════════════════")

    if args.once:
        results = run_tour(terminal_list)
        total_ok = sum(results.values())
        log.info("[FINAL] Total OK: %d", total_ok)
        return 0

    # Boucle infinie
    tour_num = 0
    try:
        while True:
            tour_num += 1
            log.info("\n[Tour %d] Démarrage à %s", tour_num, datetime.now(timezone.utc).isoformat())

            results = run_tour(terminal_list)
            total_ok = sum(results.values())

            log.info("[Tour %d] Résumé: %s | Total OK: %d", tour_num, results, total_ok)
            log.info("Pause %ds avant prochain tour...\n", args.interval)

            time.sleep(args.interval)

    except KeyboardInterrupt:
        log.info("\n[*] GOM Multi-Terminal Poller arrêté par l'utilisateur")
        return 0
    except Exception as e:
        log.error("❌ Erreur fatale: %s", e)
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
