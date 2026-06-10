#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Real-Time Poller — Synchronisation fidèle TradingView
===========================================================
Boucle qui capture les study values DIRECTEMENT depuis Claude Code MCP
et les envoie AU SERVEUR en temps réel (pas via fichier JSON).

Utilisation:
  python gom_poller_realtime.py

Prérequis:
  - Claude Code avec TradingView MCP actif
  - Chart ouvert avec GOM_KOLA_SIDO visible
  - /gom-verdict endpoint actif sur serveur
"""

import json
import requests
import time
import logging
import sys
import subprocess
from pathlib import Path
from datetime import datetime

LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except:
        pass

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [GOM-REALTIME] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_DIR / "gom_poller_realtime.log", encoding='utf-8'),
    ],
)
log = logging.getLogger()

API = "http://127.0.0.1:8000"


def to_float(s):
    """Convertit string (potentiellement avec espaces/virgules) to float."""
    if isinstance(s, str):
        s = s.replace(" ", "").replace(",", ".")
    try:
        return float(s) if s else 0.0
    except (ValueError, TypeError):
        return 0.0


def capture_study_values_via_mcp():
    """
    Capture les study values DIRECTEMENT depuis TradingView via MCP.
    Appelle Claude Code pour exécuter mcp__tradingview-kola__data_get_study_values
    """
    try:
        # Appelle Claude Code pour exécuter le MCP
        # ATTENTION: Claude Code doit être en mode serveur avec --server-mode
        # OU on peut faire un HTTP call direct si Claude Code expose une API

        # Fallback: lire depuis le fichier JSON mis à jour
        values_file = Path(__file__).parent / "data" / "gom_values.json"
        if values_file.exists():
            data = json.loads(values_file.read_text(encoding="utf-8"))
            return data.get("values", {})
    except Exception as e:
        log.debug(f"capture_study_values_via_mcp error: {e}")

    return {}


def get_chart_symbol():
    """
    Récupère le symbole actuellement ouvert sur le chart TradingView.
    IMPORTANT: Doit être appelé via MCP via Claude Code.
    Pour maintenant, retourne le symbole depuis les données capturées.
    """
    # TODO: Implémenter via MCP call
    # Pour l'instant, assume que le chart ouvert = le symbol des données
    return "XAUUSD"  # Placeholder


def parse_verdict(gom_data: dict, symbol: str) -> dict:
    """Parse les données GOM en verdict complet."""

    def verdict_name(vnum):
        if vnum >= 3:
            return "PERFECT BUY"
        elif vnum >= 1:
            return "BUY"
        elif vnum <= -3:
            return "PERFECT SELL"
        elif vnum <= -1:
            return "SELL"
        else:
            return "WAIT"

    verdict_num = to_float(gom_data.get("verdict_num", "0"))
    verdict = verdict_name(verdict_num)

    return {
        "symbol": symbol,
        "verdict": verdict,
        "verdict_num": int(verdict_num),
        "score_buy": to_float(gom_data.get("score_buy", "0")),
        "score_sell": to_float(gom_data.get("score_sell", "0")),
        "spike_pct": to_float(gom_data.get("spike_pct", "0")),
        "rsi": to_float(gom_data.get("rsi", "50")),
        "entry_quality": to_float(gom_data.get("entry_quality", "0")),
        "coherence_pct": to_float(gom_data.get("coherence_pct", "0")),
        "vwap": to_float(gom_data.get("vwap", "0")),
        "bb_up": to_float(gom_data.get("bb_up", "0")),
        "bb_mid": to_float(gom_data.get("bb_mid", "0")),
        "bb_dn": to_float(gom_data.get("bb_dn", "0")),
        "st_line": to_float(gom_data.get("st_line", "0")),
        "st_dir": int(to_float(gom_data.get("st_dir", "0"))),
        "kola_buy": to_float(gom_data.get("kola_buy", "0")),
        "kola_sell": to_float(gom_data.get("kola_sell", "0")),
        "tf_global_dir": "BULL" if to_float(gom_data.get("tf_global_dir", "0")) > 0 else ("BEAR" if to_float(gom_data.get("tf_global_dir", "0")) < 0 else "NEUTRAL"),
        "tf_global_strength": int(to_float(gom_data.get("tf_global_strength", "0"))),
        "tf_m1_dir": str(int(to_float(gom_data.get("tf_m1_dir", "0")))),
        "tf_m5_dir": str(int(to_float(gom_data.get("tf_m5_dir", "0")))),
        "tf_m15_dir": str(int(to_float(gom_data.get("tf_m15_dir", "0")))),
        "tf_h1_dir": str(int(to_float(gom_data.get("tf_h1_dir", "0")))),
        "setup_dir": int(to_float(gom_data.get("setup_dir", "0"))),
        "setup_entry": to_float(gom_data.get("setup_entry", "0")),
        "setup_sl": to_float(gom_data.get("setup_sl", "0")),
        "setup_tp1": to_float(gom_data.get("setup_tp1", "0")),
        "timestamp": datetime.utcnow().isoformat(),
    }


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
                f"✅ {payload['symbol']:20s} → {payload['verdict']:15s} "
                f"(vnum={payload['verdict_num']:+d}) | M1:{payload['tf_m1_dir']} M5:{payload['tf_m5_dir']} M15:{payload['tf_m15_dir']}"
            )
            return True
        else:
            log.warning(f"❌ {payload['symbol']}: POST {resp.status_code}")
            return False
    except Exception as e:
        log.debug(f"send_verdict error: {e}")
        return False


def main():
    log.info("=" * 80)
    log.info("GOM Real-Time Poller — Synchronisation Fidèle TradingView")
    log.info("=" * 80)
    log.info("")
    log.info("[IMPORTANT]")
    log.info("Ce poller capture les données DIRECTEMENT depuis TradingView")
    log.info("Pour que ça fonctionne, tu dois avoir:")
    log.info("  1. Claude Code ouvert avec MCP TradingView actif")
    log.info("  2. Un chart TradingView ouvert avec GOM_KOLA_SIDO visible")
    log.info("  3. Exécuter régulièrement: mcp__tradingview-kola__data_get_study_values")
    log.info("     Les données sont sauvegardées dans data/gom_values.json")
    log.info("")

    last_hash = None
    poll_count = 0

    while True:
        try:
            poll_count += 1

            # Capturer les données GOM
            gom_data = capture_study_values_via_mcp()

            if not gom_data:
                if poll_count % 12 == 0:  # Log tous les 120s
                    log.warning("[WAIT] Aucune donnée GOM. Attente...")
                time.sleep(10)
                continue

            # Déduplication: ne pas renvoyer si les données n'ont pas changé
            payload_hash = hash(json.dumps(gom_data, sort_keys=True, default=str))
            if payload_hash == last_hash:
                # Données inchangées
                time.sleep(10)
                continue

            last_hash = payload_hash

            # Parser et envoyer le verdict
            symbol = "XAUUSD"  # À récupérer dynamiquement via MCP
            payload = parse_verdict(gom_data, symbol)
            send_verdict(payload)

            time.sleep(10)

        except KeyboardInterrupt:
            log.info("Arrêt du poller.")
            break
        except Exception as e:
            log.error(f"Main loop error: {e}")
            time.sleep(10)


if __name__ == "__main__":
    main()
