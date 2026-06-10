#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Auto Poller — Synchronisation avec Morning Scan
====================================================
1. Récupère les symbols du morning_scan
2. Pour CHAQUE symbol:
   - Demande à Claude Code d'ouvrir le chart et lire le GOM_KOLA
   - Parse et envoie le verdict au serveur /gom-verdict

Utilisation:
  python gom_poller_auto.py --symbols XAUUSD,BTCUSD,CRASH_1000
  python gom_poller_auto.py  # Lit depuis morning_scan_results.json
"""

import json
import requests
import time
import logging
import sys
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
    format="%(asctime)s [GOM-AUTO] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_DIR / "gom_poller_auto.log", encoding='utf-8'),
    ],
)
log = logging.getLogger()

API = "http://127.0.0.1:8000"
SCAN_RESULTS_FILE = Path(__file__).parent / "data" / "morning_scan_results.json"


def to_float(s):
    """Convertit string (potentiellement avec espaces/virgules) to float."""
    if isinstance(s, str):
        s = s.replace(" ", "").replace(",", ".")
    try:
        return float(s) if s else 0.0
    except (ValueError, TypeError):
        return 0.0


def tv_to_mt5(symbol: str) -> str:
    """Convertit DERIV:BOOM_500_INDEX → Boom 500 Index."""
    mapping = {
        "DERIV:BOOM_1000_INDEX": "Boom 1000 Index",
        "DERIV:BOOM_500_INDEX": "Boom 500 Index",
        "DERIV:BOOM_300_INDEX": "Boom 300 Index",
        "DERIV:CRASH_1000_INDEX": "Crash 1000 Index",
        "DERIV:CRASH_500_INDEX": "Crash 500 Index",
        "DERIV:CRASH_300_INDEX": "Crash 300 Index",
    }
    return mapping.get(symbol, symbol)


def read_scan_results() -> list:
    """Récupère les symbols du dernier morning_scan."""
    try:
        if SCAN_RESULTS_FILE.exists():
            data = json.loads(SCAN_RESULTS_FILE.read_text(encoding="utf-8"))
            if isinstance(data, list):
                return data
            elif isinstance(data, dict) and "symbols" in data:
                return data.get("symbols", [])
    except Exception as e:
        log.debug(f"read_scan_results error: {e}")
    return []


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
                f"(vnum={payload['verdict_num']:+d}) "
                f"| M1:{payload['tf_m1_dir']} M5:{payload['tf_m5_dir']} "
                f"M15:{payload['tf_m15_dir']} H1:{payload['tf_h1_dir']}"
            )
            return True
        else:
            log.warning(f"❌ {payload['symbol']}: POST {resp.status_code}")
            return False
    except Exception as e:
        log.debug(f"send_verdict error: {e}")
        return False


def read_gom_values() -> dict:
    """Lit les valeurs GOM depuis data/gom_values.json."""
    values_file = Path(__file__).parent / "data" / "gom_values.json"
    try:
        if values_file.exists():
            data = json.loads(values_file.read_text(encoding="utf-8"))
            return data.get("values", {})
    except Exception as e:
        log.debug(f"read_gom_values error: {e}")
    return {}


def main():
    log.info("=" * 80)
    log.info("GOM Auto Poller — Synchronisation Morning Scan + TradingView")
    log.info("=" * 80)
    log.info("")

    # Instructions
    log.info("[INSTRUCTIONS]")
    log.info("1. Ouvre TradingView et le chart du PREMIER symbol de la liste")
    log.info("2. Ajoute le Pine Script 'GOM KOLA SIDO — Full Integration' au chart")
    log.info("3. Lance dans Claude Code: mcp__tradingview-kola__data_get_study_values")
    log.info("4. Copie les 'values' dans data/gom_values.json: {\"values\": {...}}")
    log.info("5. Le script lira et enverra les verdicts à /gom-verdict")
    log.info("")

    last_symbols = set()
    poll_count = 0

    while True:
        try:
            poll_count += 1

            # Récupérer les symbols du scan
            scan_symbols = read_scan_results()
            current_symbols = set(tv_to_mt5(s) if s.startswith("DERIV:") else s for s in scan_symbols)

            if not current_symbols:
                if poll_count % 12 == 0:  # Log tous les 120s
                    log.warning("[WAIT] Aucun symbol du scan. Attente...")
                time.sleep(10)
                continue

            # Si les symbols ont changé, log
            if current_symbols != last_symbols:
                log.info(f"📋 Symbols découverts ({len(current_symbols)}): {', '.join(sorted(current_symbols))}")
                last_symbols = current_symbols

            # Lire les données GOM une seule fois
            gom_data = read_gom_values()
            if not gom_data:
                if poll_count % 6 == 0:
                    log.warning("[WAIT] Pas de données GOM. Attente des données TradingView...")
                time.sleep(10)
                continue

            # Pour CHAQUE symbol du scan, envoyer le verdict
            # (utilise les mêmes données GOM, mais change le symbol en tête)
            for symbol in sorted(current_symbols):
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
