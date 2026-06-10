#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Multi-Symbol Poller
=======================
Boucle continue qui:
1. Itère sur une liste de symbols
2. Pour chaque symbol, lit les valeurs GOM depuis data/gom_values.json
3. Parse et envoie les verdicts au serveur /gom-verdict

Utilisation:
  python gom_poller_multisymbol.py

Prérequis:
  - TradingView charts ouverts pour chaque symbol avec GOM_KOLA_SIDO visible
  - data/gom_values.json mis à jour manuellement OU via gom_sync_working.py
"""

import json
import requests
import time
import logging
import sys
from pathlib import Path
from datetime import datetime
from collections import defaultdict

LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

if sys.stdout.encoding and sys.stdout.encoding.lower() != 'utf-8':
    try:
        sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    except:
        pass

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [GOM-MULTI] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_DIR / "gom_poller_multisymbol.log", encoding='utf-8'),
    ],
)
log = logging.getLogger()

API = "http://127.0.0.1:8000"
VALUES_FILE = Path(__file__).parent / "data" / "gom_values.json"
VALUES_FILE.parent.mkdir(exist_ok=True)

# Symbols à poller — ajoute les tiens ici
SYMBOLS_TO_POLL = {
    "Crash 1000 Index": "CRASH_1000",
    "Boom 1000 Index": "BOOM_1000",
    "XAUUSD": "XAUUSD",
    "BTCUSD": "BTCUSD",
}

# Cache: dernier hash envoyé par symbol (pour éviter doublons)
last_hash = defaultdict(str)


def to_float(s):
    """Convertit string (potentiellement avec espaces/virgules) to float."""
    if isinstance(s, str):
        s = s.replace(" ", "").replace(",", ".")
    try:
        return float(s) if s else 0.0
    except (ValueError, TypeError):
        return 0.0


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
                f"(buy={payload['score_buy']:5.2f}, sell={payload['score_sell']:5.2f}) "
                f"| TF: M1={payload['tf_m1_dir']} M5={payload['tf_m5_dir']} "
                f"M15={payload['tf_m15_dir']} H1={payload['tf_h1_dir']}"
            )
            return True
        else:
            log.warning(f"❌ POST failed {resp.status_code}: {resp.text[:100]}")
            return False
    except Exception as e:
        log.warning(f"send_verdict error: {e}")
        return False


def read_gom_values() -> dict:
    """Lit les valeurs GOM depuis le fichier."""
    try:
        if VALUES_FILE.exists():
            data = json.loads(VALUES_FILE.read_text(encoding="utf-8"))
            return data.get("values", {})
    except Exception as e:
        log.debug(f"read_gom_values error: {e}")
    return {}


def main():
    log.info("=" * 80)
    log.info("GOM Multi-Symbol Poller — TradBOT")
    log.info("=" * 80)
    log.info(f"Symbols à poller: {list(SYMBOLS_TO_POLL.keys())}")
    log.info("Polling interval: 10 secondes")
    log.info("")

    poll_count = 0

    while True:
        try:
            poll_count += 1
            gom_data = read_gom_values()

            if not gom_data:
                # Attendre les données
                if poll_count % 6 == 0:  # Log tous les 60s
                    log.warning("[WAIT] Pas de données GOM. Attente...")
                time.sleep(10)
                continue

            # Pour chaque symbol, envoyer le verdict
            for mt5_symbol, _ in SYMBOLS_TO_POLL.items():
                payload = parse_verdict(gom_data, mt5_symbol)

                # Déduplication : ne pas renvoyer si les données n'ont pas changé
                payload_hash = hash(json.dumps(payload, sort_keys=True, default=str))
                if payload_hash == last_hash[mt5_symbol]:
                    continue  # Données identiques, skip

                last_hash[mt5_symbol] = payload_hash
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
