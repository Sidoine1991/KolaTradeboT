#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Poller Robuste — Synchronise verdicts TradingView → MT5
============================================================
Lit le verdict GOM depuis le chart TradingView actuel,
l'envoie à /gom-verdict pour que SMC_Universal le reçoive.

Flux :
  TradingView (MCP) → GOM study values
                   ↓
                /gom-verdict (ai_server)
                   ↓
            SMC_Universal EA
"""

import json
import logging
import sys
import time
from pathlib import Path
from typing import Optional, Dict, Any

import requests

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

AI_SERVER_URL = "http://127.0.0.1:8000"
MCP_PORT = 9222  # Port CDP TradingView
LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

# Mapping MT5 → TradingView ticker
MT5_TO_TV = {
    "XAUUSD": "OANDA:XAUUSD",
    "XAGUSD": "OANDA:XAGUSD",
    "EURUSD": "OANDA:EURUSD",
    "GBPUSD": "OANDA:GBPUSD",
    "USDJPY": "OANDA:USDJPY",
    "BTCUSD": "BITSTAMP:BTCUSD",
    "ETHUSD": "BITSTAMP:ETHUSD",
    "Crash 1000 Index": "DERIV:CRASH_1000_INDEX",
    "Crash 500 Index": "DERIV:CRASH_500_INDEX",
    "Boom 1000 Index": "DERIV:BOOM_1000_INDEX",
    "Boom 500 Index": "DERIV:BOOM_500_INDEX",
}

# ══════════════════════════════════════════════════════════════════════════════
# LOGGING
# ══════════════════════════════════════════════════════════════════════════════

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [GOM-Poller] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_DIR / "gom_poller_robust.log", encoding="utf-8"),
    ],
)
log = logging.getLogger("gom_poller")


# ══════════════════════════════════════════════════════════════════════════════
# API CALLS
# ══════════════════════════════════════════════════════════════════════════════


def get_chart_state() -> Optional[Dict[str, Any]]:
    """Récupère l'état actuel du chart TradingView via MCP."""
    try:
        # Appel MCP local pour obtenir l'état du chart
        # Note: On utilise une approche simple en lisant depuis le store de bridge
        import requests
        from urllib.parse import urljoin

        # L'ai_server maintient un cache des données MCP
        resp = requests.get(
            urljoin(AI_SERVER_URL, "/health"),
            timeout=5,
        )
        if resp.status_code != 200:
            return None
        return {"connected": True}
    except Exception as e:
        log.debug(f"get_chart_state error: {e}")
        return None


def read_gom_via_file() -> Optional[Dict[str, Any]]:
    """Lit les données GOM depuis le fichier de cache MCP bridge."""
    try:
        bridge_file = Path(__file__).parent / "data" / "mcp_bridge_store.json"
        if not bridge_file.exists():
            return None

        data = json.loads(bridge_file.read_text(encoding="utf-8"))
        return data.get("last_gom_values", {})
    except Exception as e:
        log.debug(f"read_gom_via_file error: {e}")
        return None


def parse_gom_to_verdict(gom_data: Dict[str, Any], symbol: str) -> Dict[str, Any]:
    """Convertit les données brutes GOM en format /gom-verdict."""
    try:
        verdict_num = float(gom_data.get("verdict_num", 0))
        score_buy = float(gom_data.get("score_buy", 0))
        score_sell = float(gom_data.get("score_sell", 0))

        # Logique verdict simple
        if verdict_num > 1:
            verdict = "STRONG BUY"
        elif verdict_num > 0:
            verdict = "BUY"
        elif verdict_num < -1:
            verdict = "STRONG SELL"
        elif verdict_num < 0:
            verdict = "SELL"
        else:
            verdict = "NEUTRAL"

        return {
            "symbol": symbol,
            "verdict": verdict,
            "verdict_num": verdict_num,
            "score_buy": score_buy,
            "score_sell": score_sell,
            "price": float(gom_data.get("kola_buy", 0)) or float(
                gom_data.get("kola_sell", 0)
            ),
            "quality": float(gom_data.get("entry_quality", 0)),
            "coherence": float(gom_data.get("coherence_pct", 0)),
            "tf_global_dir": int(gom_data.get("tf_global_dir", 0)),
            "setup_dir": int(gom_data.get("setup_dir", 0)),
            "rsi": float(gom_data.get("rsi", 0)),
        }
    except Exception as e:
        log.warning(f"parse_gom_to_verdict error: {e}")
        return {}


def push_verdict_to_server(payload: Dict[str, Any]) -> bool:
    """Envoie le verdict GOM vers /gom-verdict de l'ai_server."""
    try:
        resp = requests.post(
            f"{AI_SERVER_URL}/gom-verdict",
            json=payload,
            timeout=5,
        )
        if resp.status_code in (200, 201):
            log.info(
                "✅ %s → verdict=%s (buy=%.2f, sell=%.2f)",
                payload.get("symbol"),
                payload.get("verdict"),
                payload.get("score_buy"),
                payload.get("score_sell"),
            )
            return True
        else:
            log.warning(
                "⚠️  POST /gom-verdict failed: %d → %s", resp.status_code, resp.text[:100]
            )
            return False
    except Exception as e:
        log.warning(f"push_verdict_to_server error: {e}")
        return False


# ══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ══════════════════════════════════════════════════════════════════════════════


def get_current_symbol() -> Optional[str]:
    """Détecte le symbole MT5 actuellement ouvert sur le chart TradingView."""
    try:
        bridge_file = Path(__file__).parent / "data" / "mcp_bridge_store.json"
        if bridge_file.exists():
            data = json.loads(bridge_file.read_text(encoding="utf-8"))
            # Extraire le symbole depuis les données GOM
            symbol = data.get("symbol")
            if symbol:
                return symbol
    except Exception:
        pass
    return None


def poller_loop(interval: int = 10, max_retries: int = 3) -> None:
    """Boucle principale du poller GOM."""
    log.info("🚀 GOM Poller démarré (interval=%ds)", interval)
    log.info("   Flux: TradingView (MCP) → /gom-verdict → SMC_Universal")
    log.info("=" * 70)

    retry_count = 0
    while True:
        try:
            # 1. Vérifier connexion ai_server
            try:
                resp = requests.get(f"{AI_SERVER_URL}/health", timeout=3)
                if resp.status_code != 200:
                    raise Exception(f"AI server unhealthy: {resp.status_code}")
            except Exception as e:
                log.warning(f"⚠️  AI Server not ready: {e}")
                retry_count += 1
                if retry_count >= max_retries:
                    log.error("❌ Max retries reached, exiting")
                    sys.exit(1)
                time.sleep(5)
                continue

            retry_count = 0

            # 2. Lire les données GOM depuis le fichier de cache
            gom_data = read_gom_via_file()
            if not gom_data:
                log.debug("ℹ️  Pas de données GOM dans cache, attente...")
                time.sleep(interval)
                continue

            # 3. Extraire le symbole MT5 actuel
            symbol = get_current_symbol()
            if not symbol:
                log.debug("ℹ️  Symbole MT5 non détecté")
                time.sleep(interval)
                continue

            # 4. Parser et envoyer le verdict
            payload = parse_gom_to_verdict(gom_data, symbol)
            if payload:
                push_verdict_to_server(payload)

            time.sleep(interval)

        except KeyboardInterrupt:
            log.info("⏹️  Arrêt du poller")
            break
        except Exception as e:
            log.error(f"Erreur boucle principale: {e}")
            time.sleep(interval)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="GOM Poller Robuste")
    parser.add_argument("--interval", type=int, default=10, help="Intervalle en secondes")
    parser.add_argument("--retries", type=int, default=3, help="Retries max")
    args = parser.parse_args()

    poller_loop(interval=args.interval, max_retries=args.retries)
