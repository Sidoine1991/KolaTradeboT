#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Poller Simple — Synchronise verdicts TradingView → ai_server
"""
import requests
import time
import logging
from pathlib import Path

LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [Poller] %(message)s",
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler(LOG_DIR / "poller_simple.log"),
    ],
)
log = logging.getLogger()

API = "http://127.0.0.1:8000"
MCP_BRIDGE_FILE = Path(__file__).parent / "data" / "mcp_bridge_store.json"


def get_gom_from_mcp() -> dict:
    """Récupère les données GOM via MCP (hardcoded pour maintenant)."""
    # Simule l'appel MCP data_get_study_values
    # En production, ce serait via Claude Code MCP
    try:
        import subprocess
        import json

        script = """
import sys
# Simule Claude Code MCP appel
# data_get_study_values() → retourne les valeurs du study GOM
result = {
    "success": True,
    "study_count": 1,
    "studies": [{
        "name": "GOM KOLA SIDO",
        "values": {
            "verdict_num": "0.0",
            "score_buy": "3.32",
            "score_sell": "4.1",
            "rsi": "44.68",
            "tf_global_dir": "-1",
            "setup_dir": "0",
            "kola_buy": "6011.57",
            "entry_quality": "19.69",
            "coherence_pct": "50.0"
        }
    }]
}
import json
print(json.dumps(result))
"""

        proc = subprocess.run(
            [sys.executable, "-c", script],
            capture_output=True,
            text=True,
            timeout=5,
        )

        if proc.returncode == 0:
            data = json.loads(proc.stdout)
            if data.get("studies"):
                return data["studies"][0].get("values", {})
    except Exception as e:
        log.debug(f"get_gom_from_mcp error: {e}")

    return {}


def parse_verdict(gom_data: dict, symbol: str) -> dict:
    """Convertit les données GOM en payload /gom-verdict."""
    try:
        verdict_num = float(gom_data.get("verdict_num", 0))

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
            "verdict_num": str(verdict_num),
            "score_buy": gom_data.get("score_buy", "0"),
            "score_sell": gom_data.get("score_sell", "0"),
            "price": gom_data.get("kola_buy", "0"),
            "quality": gom_data.get("entry_quality", "0"),
            "coherence": gom_data.get("coherence_pct", "0"),
            "tf_global_dir": gom_data.get("tf_global_dir", "0"),
            "setup_dir": gom_data.get("setup_dir", "0"),
            "rsi": gom_data.get("rsi", "0"),
        }
    except Exception as e:
        log.warning(f"parse_verdict error: {e}")
        return {}


def send_verdict(payload: dict) -> bool:
    """Envoie le verdict à /gom-verdict."""
    try:
        resp = requests.post(
            f"{API}/gom-verdict",
            json=payload,
            timeout=5,
        )
        if resp.status_code in (200, 201):
            log.info(
                f"✅ {payload['symbol']} → {payload['verdict']} "
                f"(buy={payload['score_buy']}, sell={payload['score_sell']})"
            )
            return True
        else:
            log.warning(f"❌ POST failed: {resp.status_code}")
            return False
    except Exception as e:
        log.warning(f"send_verdict error: {e}")
        return False


def main():
    log.info("=" * 70)
    log.info("🚀 Poller Simple démarré")
    log.info("   Flux: (MCP) → GOM values → /gom-verdict → SMC_Universal")
    log.info("=" * 70)

    # Pour test : hardcoder le symbole actuel
    symbol = "Crash 1000 Index"

    try:
        while True:
            try:
                # Lire GOM depuis MCP
                gom_data = get_gom_from_mcp()
                if not gom_data:
                    log.debug("Pas de données GOM")
                    time.sleep(10)
                    continue

                # Parser le verdict
                payload = parse_verdict(gom_data, symbol)
                if not payload:
                    time.sleep(10)
                    continue

                # Envoyer à /gom-verdict
                send_verdict(payload)

                time.sleep(10)

            except Exception as e:
                log.error(f"Erreur boucle: {e}")
                time.sleep(10)

    except KeyboardInterrupt:
        log.info("⏹️  Arrêt")


if __name__ == "__main__":
    main()
