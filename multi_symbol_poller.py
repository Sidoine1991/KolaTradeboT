#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Multi-Symbol GOM Poller — Automatise la lecture GOM pour TOUS les symboles MT5
=============================================================================
Détecte les symboles actuellement ouverts sur MT5 et envoie les verdicts GOM
pour chaque symbole sans intervention manuelle.

Flux :
  Symboles MT5 detectés → TradingView chart basculé → GOM lu → /gom-verdict
"""

import json
import logging
import sys
import time
from pathlib import Path
from typing import List, Dict, Any

import requests

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

AI_SERVER_URL = "http://127.0.0.1:8000"
LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

# Symboles MT5 → TradingView
MT5_TO_TV = {
    "XAUUSD": "OANDA:XAUUSD",
    "XAGUSD": "OANDA:XAGUSD",
    "EURUSD": "OANDA:EURUSD",
    "GBPUSD": "OANDA:GBPUSD",
    "BTCUSD": "BITSTAMP:BTCUSD",
    "ETHUSD": "BITSTAMP:ETHUSD",
    "Crash 1000 Index": "DERIV:CRASH_1000_INDEX",
    "Crash 500 Index": "DERIV:CRASH_500_INDEX",
    "Boom 1000 Index": "DERIV:BOOM_1000_INDEX",
    "Boom 500 Index": "DERIV:BOOM_500_INDEX",
}

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [Multi-Poller] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_DIR / "multi_symbol_poller.log", encoding="utf-8"),
    ],
)
log = logging.getLogger()


# ══════════════════════════════════════════════════════════════════════════════
# FONCTIONS
# ══════════════════════════════════════════════════════════════════════════════


def get_symbols_from_file() -> List[str]:
    """Lit la liste des symboles actuellement actifs."""
    try:
        # Lire depuis un fichier que MT5 écrit (ou garder une liste statique)
        symbols_file = Path(__file__).parent / "data" / "active_symbols.json"
        if symbols_file.exists():
            data = json.loads(symbols_file.read_text(encoding="utf-8"))
            return data.get("symbols", list(MT5_TO_TV.keys()))
    except Exception as e:
        log.debug(f"Erreur lecture symboles: {e}")
    return list(MT5_TO_TV.keys())


def get_gom_for_symbol(symbol: str) -> Dict[str, Any]:
    """Récupère le verdict GOM pour un symbole depuis le serveur."""
    try:
        resp = requests.get(
            f"{AI_SERVER_URL}/gom-verdict?symbol={symbol}",
            timeout=5,
        )
        if resp.status_code == 200:
            return resp.json()
        return {}
    except Exception as e:
        log.warning(f"get_gom_for_symbol {symbol}: {e}")
        return {}


def send_gom_signal(symbol: str, gom_data: Dict[str, Any]) -> bool:
    """Envoie un signal GOM pour un symbole donné."""
    try:
        # Les données viennent déjà du serveur, les envoyer à nouveau pour synchronisation
        resp = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json={"symbol": symbol, **gom_data},
            timeout=5,
        )
        if resp.status_code in (200, 201):
            log.info(
                "[OK] %s → verdict=%s (buy=%.2f, sell=%.2f)",
                symbol,
                gom_data.get("verdict", "?"),
                float(gom_data.get("score_buy", 0)),
                float(gom_data.get("score_sell", 0)),
            )
            return True
    except Exception as e:
        log.warning(f"send_gom_signal {symbol}: {e}")
    return False


def poller_loop(interval: int = 15, max_symbols: int = 10) -> None:
    """Boucle principale : poll tous les symboles."""
    log.info("=" * 70)
    log.info("[START] Multi-Symbol GOM Poller")
    log.info("   Interval: %ds | Max symbols: %d", interval, max_symbols)
    log.info("=" * 70)

    cycle = 0
    while True:
        try:
            cycle += 1
            log.info("--- Cycle #%d ---", cycle)

            # 1. Récupérer les symboles MT5 actuels
            symbols = get_symbols_from_file()
            if not symbols:
                log.warning("[WARN] Aucun symbole detecté")
                time.sleep(interval)
                continue

            # Limiter pour ne pas saturer
            symbols = symbols[:max_symbols]
            log.info("[INFO] %d symboles à traiter", len(symbols))

            # 2. Pour chaque symbole, récupérer et envoyer le verdict GOM
            success_count = 0
            for sym in symbols:
                gom_data = get_gom_for_symbol(sym)
                if gom_data and gom_data.get("ok"):
                    if send_gom_signal(sym, gom_data):
                        success_count += 1
                else:
                    log.debug("[MISS] %s - pas de données", sym)

            log.info("[STATS] Cycle #%d: %d/%d réussis", cycle, success_count, len(symbols))

            time.sleep(interval)

        except KeyboardInterrupt:
            log.info("[STOP] Arrêt")
            break
        except Exception as e:
            log.error(f"[ERROR] {e}")
            time.sleep(interval)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Multi-Symbol GOM Poller")
    parser.add_argument("--interval", type=int, default=15, help="Intervalle en secondes")
    parser.add_argument("--symbols", type=int, default=10, help="Nombre max de symboles")
    args = parser.parse_args()

    poller_loop(interval=args.interval, max_symbols=args.symbols)
