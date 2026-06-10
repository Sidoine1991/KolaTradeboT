#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MCP GOM Bridge — Capture continu des verdicts GOM depuis TradingView
====================================================================
Utilise l'API MCP TradingView pour lire les données GOM de l'indicateur
et les stocker dans un cache persistant que le poller peut lire.

Flux :
  TradingView (MCP) data_get_study_values
              ↓
        Préparer payload GOM
              ↓
    Stocker dans mcp_bridge_store.json
              ↓
    gom_poller_robust.py le lit
"""

import json
import logging
import sys
import time
from pathlib import Path
from typing import Optional, Dict, Any
import socket

log = logging.getLogger("mcp_bridge")

# ══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ══════════════════════════════════════════════════════════════════════════════

STORE_DIR = Path(__file__).parent.parent / "data"
STORE_DIR.mkdir(parents=True, exist_ok=True)
STORE_FILE = STORE_DIR / "mcp_bridge_store.json"
LOG_DIR = Path(__file__).parent.parent / "logs"
LOG_DIR.mkdir(parents=True, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [MCP-Bridge] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_DIR / "mcp_gom_bridge.log", encoding="utf-8"),
    ],
)


# ══════════════════════════════════════════════════════════════════════════════
# MCP INTEGRATION (via subprocess appel aux outils MCP Claude Code)
# ══════════════════════════════════════════════════════════════════════════════


def call_mcp_tool(tool_name: str, **kwargs) -> Optional[Dict[str, Any]]:
    """
    Appelle un outil MCP TradingView via les APIs disponibles.
    Cette fonction utilise l'approche 'store' pour communiquer avec Claude Code.
    """
    try:
        # On va utiliser un processus externe pour appeler l'API MCP
        # via Claude Code (qui a accès aux outils MCP)
        import subprocess

        script = f"""
import sys
sys.path.insert(0, r'{Path(__file__).parent}')

try:
    # Import depuis ai_server si disponible
    from tradingview_mcp_bridge import call_tv_mcp
    result = call_tv_mcp('{tool_name}', {json.dumps(kwargs)})
    print(json.dumps(result or {{}}, default=str))
except Exception as e:
    print(json.dumps({{"error": str(e)}}, default=str))
"""

        result = subprocess.run(
            [sys.executable, "-c", script],
            capture_output=True,
            text=True,
            timeout=10,
        )

        if result.returncode == 0:
            return json.loads(result.stdout) if result.stdout.strip() else None
        else:
            log.warning(f"MCP tool {tool_name} stderr: {result.stderr}")
            return None
    except Exception as e:
        log.debug(f"call_mcp_tool {tool_name} error: {e}")
        return None


def read_gom_from_tradingview() -> Optional[Dict[str, Any]]:
    """
    Lit les données GOM directement depuis TradingView via MCP.
    Retourne les valeurs brutes du study GOM.
    """
    try:
        # Appeler data_get_study_values via MCP
        result = call_mcp_tool("data_get_study_values")

        if not result:
            log.debug("Pas de réponse MCP")
            return None

        # Parser la réponse
        studies = result.get("studies", [])
        if not studies:
            log.debug("Aucun study disponible")
            return None

        # Chercher le study GOM
        for study in studies:
            if "GOM" in study.get("name", ""):
                return study.get("values", {})

        log.debug("Study GOM non trouvé")
        return None

    except Exception as e:
        log.warning(f"read_gom_from_tradingview error: {e}")
        return None


def get_chart_info() -> Optional[Dict[str, str]]:
    """Récupère le symbole et la timeframe actuels du chart."""
    try:
        result = call_mcp_tool("chart_get_state")
        if result and result.get("symbol"):
            return {
                "symbol": result.get("symbol"),
                "resolution": result.get("resolution"),
            }
        return None
    except Exception as e:
        log.warning(f"get_chart_info error: {e}")
        return None


# ══════════════════════════════════════════════════════════════════════════════
# STORE MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════


def save_gom_to_store(gom_data: Dict[str, Any], symbol: str, resolution: str) -> bool:
    """Sauvegarde les données GOM dans le fichier de cache."""
    try:
        store = {
            "timestamp": time.time(),
            "symbol": symbol,
            "resolution": resolution,
            "last_gom_values": gom_data,
        }
        STORE_FILE.write_text(json.dumps(store, indent=2, default=str), encoding="utf-8")
        return True
    except Exception as e:
        log.warning(f"save_gom_to_store error: {e}")
        return False


def load_gom_from_store() -> Optional[Dict[str, Any]]:
    """Charge les dernières données GOM du cache."""
    try:
        if STORE_FILE.exists():
            return json.loads(STORE_FILE.read_text(encoding="utf-8"))
        return None
    except Exception as e:
        log.debug(f"load_gom_from_store error: {e}")
        return None


# ══════════════════════════════════════════════════════════════════════════════
# MAIN LOOP
# ══════════════════════════════════════════════════════════════════════════════


def bridge_loop(interval: int = 5, max_failures: int = 10) -> None:
    """Boucle principale du bridge MCP → cache."""
    log.info("🚀 MCP GOM Bridge démarré")
    log.info(f"   Cache: {STORE_FILE}")
    log.info(f"   Interval: {interval}s")
    log.info("=" * 70)

    failures = 0
    cycle = 0

    while True:
        try:
            cycle += 1
            log.debug(f"─── Cycle #{cycle} ───")

            # 1. Vérifier la connexion TradingView
            chart_info = get_chart_info()
            if not chart_info:
                log.warning("⚠️  Pas de connexion TradingView (ou pas de chart ouvert)")
                failures += 1
                if failures >= max_failures:
                    log.error("❌ Trop d'échecs consécutifs, redémarrage attendu...")
                    sys.exit(1)
                time.sleep(interval)
                continue

            failures = 0
            symbol = chart_info.get("symbol", "?")

            # 2. Lire les données GOM
            gom_data = read_gom_from_tradingview()
            if not gom_data:
                log.debug(f"ℹ️  Pas de données GOM pour {symbol}")
                time.sleep(interval)
                continue

            # 3. Sauvegarder dans le cache
            resolution = chart_info.get("resolution", "1")
            if save_gom_to_store(gom_data, symbol, resolution):
                verdict_num = gom_data.get("verdict_num", 0)
                score_buy = gom_data.get("score_buy", 0)
                score_sell = gom_data.get("score_sell", 0)
                log.info(
                    "✅ %s (M%s) → verdict=%.1f, buy=%.2f, sell=%.2f",
                    symbol,
                    resolution,
                    float(verdict_num) if verdict_num else 0,
                    float(score_buy) if score_buy else 0,
                    float(score_sell) if score_sell else 0,
                )

            time.sleep(interval)

        except KeyboardInterrupt:
            log.info("⏹️  Arrêt du bridge")
            break
        except Exception as e:
            log.error(f"Erreur boucle: {e}")
            failures += 1
            time.sleep(interval)


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="MCP GOM Bridge")
    parser.add_argument("--interval", type=int, default=5, help="Intervalle en secondes")
    args = parser.parse_args()

    bridge_loop(interval=args.interval)
