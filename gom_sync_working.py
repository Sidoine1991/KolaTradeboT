#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Sync Working — Approche manuelle testée
============================================
Lance une boucle qui :
1. Vous demande de lancer manuellement la lecture GOM depuis Claude Code
2. Envoie le verdict à /gom-verdict

Pour utiliser :
  python gom_sync_working.py

Puis dans Claude Code :
  mcp__tradingview-kola__data_get_study_values
    → copier les valeurs dans gom_values.json
    → le script les lit et les envoie à /gom-verdict
"""

import json
import requests
import time
import logging
import sys
from pathlib import Path

LOG_DIR = Path(__file__).parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

# Reconfigurer stdout pour UTF-8
if sys.stdout.encoding.lower() != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [GOM-Sync] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_DIR / "gom_sync_working.log", encoding='utf-8'),
    ],
)
log = logging.getLogger()

API = "http://127.0.0.1:8000"
VALUES_FILE = Path(__file__).parent / "data" / "gom_values.json"
VALUES_FILE.parent.mkdir(exist_ok=True)


def read_gom_values() -> dict:
    """Lit les valeurs GOM depuis le fichier que Claude Code remplit."""
    try:
        if VALUES_FILE.exists():
            data = json.loads(VALUES_FILE.read_text(encoding="utf-8"))
            return data.get("values", {})
    except Exception as e:
        log.debug(f"read_gom_values error: {e}")
    return {}


def parse_verdict(gom_data: dict, symbol: str) -> dict:
    """Parse les données GOM en verdict avec tous les champs complétés."""
    try:
        # Les valeurs de MCP sont des strings avec virgules
        def to_float(s):
            if isinstance(s, str):
                s = s.replace(" ", "")  # Enlever espaces de milliers EN PREMIER
                s = s.replace(",", ".")  # PUIS convertir virgule décimale → point
            return float(s) if s else 0.0

        # NOUVELLES: Tendances par timeframe (depuis les plots ajoutés)
        tf_m1 = int(to_float(gom_data.get("tf_m1_dir", "0")))
        tf_m5 = int(to_float(gom_data.get("tf_m5_dir", "0")))
        tf_m15 = int(to_float(gom_data.get("tf_m15_dir", "0")))
        tf_h1 = int(to_float(gom_data.get("tf_h1_dir", "0")))

        verdict_num = to_float(gom_data.get("verdict_num", "0"))

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

        # Déterminer direction globale
        tf_dir_raw = gom_data.get("tf_global_dir", "0")
        if isinstance(tf_dir_raw, str):
            tf_dir_num = to_float(tf_dir_raw)
            tf_global_dir = "BEAR" if tf_dir_num < 0 else ("BULL" if tf_dir_num > 0 else "NEUTRAL")
        else:
            tf_global_dir = "NEUTRAL"

        return {
            "symbol": symbol,
            "verdict": verdict,
            "verdict_num": str(int(verdict_num)),
            "score_buy": str(to_float(gom_data.get("score_buy", "0"))),
            "score_sell": str(to_float(gom_data.get("score_sell", "0"))),
            "spike_pct": str(to_float(gom_data.get("spike_pct", "0"))),
            "vwap": str(to_float(gom_data.get("vwap", "0"))),
            "bb_up": str(to_float(gom_data.get("bb_up", "0"))),
            "bb_mid": str(to_float(gom_data.get("bb_mid", "0"))),
            "bb_dn": str(to_float(gom_data.get("bb_dn", "0"))),
            "st_line": str(to_float(gom_data.get("st_line", "0"))),
            "st_dir": str(int(to_float(gom_data.get("st_dir", "0")))),
            "rsi": str(to_float(gom_data.get("rsi", "50"))),
            "price": str(to_float(gom_data.get("price", gom_data.get("kola_buy", "0")))),
            "entry_quality": str(to_float(gom_data.get("entry_quality", "0"))),
            "coherence_pct": str(to_float(gom_data.get("coherence_pct", "0"))),
            "verdict_gap": str(to_float(gom_data.get("verdict_gap", "0"))),
            "kola_buy": str(to_float(gom_data.get("kola_buy", "0"))),
            "kola_sell": str(to_float(gom_data.get("kola_sell", "0"))),
            "kola_state": gom_data.get("kola_state", "---"),
            "tf_global_dir": tf_global_dir,
            "tf_global_strength": str(int(to_float(gom_data.get("tf_global_strength", "0")))),
            "tf_m1_dir": str(tf_m1),    # NOUVEAU
            "tf_m5_dir": str(tf_m5),    # NOUVEAU
            "tf_m15_dir": str(tf_m15),  # NOUVEAU
            "tf_h1_dir": str(tf_h1),    # NOUVEAU
            "setup_dir": str(int(to_float(gom_data.get("setup_dir", "0")))),
            "setup_entry": str(to_float(gom_data.get("setup_entry", "0"))),
            "setup_sl": str(to_float(gom_data.get("setup_sl", "0"))),
            "setup_tp1": str(to_float(gom_data.get("setup_tp1", "0"))),
            "setup_tp2": str(to_float(gom_data.get("setup_tp2", "0"))),
            "setup_rr": str(to_float(gom_data.get("setup_rr", "0"))),
            "ghost_delta": str(to_float(gom_data.get("ghost_delta", "0"))),
            "ghost_cvd": str(to_float(gom_data.get("ghost_cvd", "0"))),
            "ghost_buypct": str(to_float(gom_data.get("ghost_buypct", "0"))),
            "ghost_compass": str(to_float(gom_data.get("ghost_compass", "0"))),
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
                f"[OK] {payload['symbol']} > {payload['verdict']} "
                f"(buy={payload['score_buy']}, sell={payload['score_sell']})"
            )
            return True
        else:
            log.warning(f"❌ POST failed: {resp.status_code}")
            return False
    except Exception as e:
        log.warning(f"send_verdict error: {e}")
        return False


def generate_bb_prediction(current_bb_mid: float, current_bb_up: float, current_bb_dn: float, bars_ahead: int = 300) -> dict:
    """Génère une prédiction linéaire simple des Bollinger Bands pour N bougies."""
    # Extrapolation linéaire : même pente
    # (En production, tu pourrais utiliser un modèle ML)
    slope_mid = 0.0001  # Très petit, tendance plate
    slope_up = 0.0001
    slope_dn = 0.0001

    pred_mid = []
    pred_up = []
    pred_dn = []

    for i in range(1, bars_ahead):
        pred_mid.append(round(current_bb_mid + slope_mid * i, 2))
        pred_up.append(round(current_bb_up + slope_up * i, 2))
        pred_dn.append(round(current_bb_dn + slope_dn * i, 2))

    return {
        "pred_bb_mid": pred_mid[:100],  # Limiter à 100 points
        "pred_bb_up": pred_up[:100],
        "pred_bb_dn": pred_dn[:100],
    }


def main():
    log.info("=" * 70)
    log.info("[START] GOM Sync (Manual Mode)")
    log.info("=" * 70)
    log.info("")
    log.info("[INFO] INSTRUCTIONS:")
    log.info("1. Ouvrez TradingView sur le symbole cible (ex: Crash 1000)")
    log.info("2. Dans Claude Code, lancez:")
    log.info("   mcp__tradingview-kola__data_get_study_values")
    log.info("3. Copiez la sortie 'values' du study GOM")
    log.info("4. Sauvegardez-la dans:")
    log.info(f"   {VALUES_FILE}")
    log.info("   Format: {\"values\": {...}}")
    log.info("5. Le script lira et enverra automatiquement à /gom-verdict")
    log.info("")
    log.info("[WAIT] Attente des donnees GOM...")
    log.info("=" * 70)
    log.info("")

    last_hash = None
    cycle = 0

    while True:
        try:
            cycle += 1

            # Lire les données
            gom_data = read_gom_values()
            if not gom_data:
                if cycle % 6 == 0:  # Log tous les 60s
                    log.info(f"[WAIT] Attente... (cycle {cycle})")
                time.sleep(10)
                continue

            # Détecter changement
            current_hash = json.dumps(gom_data, sort_keys=True)
            if current_hash == last_hash:
                time.sleep(10)
                continue

            last_hash = current_hash

            # Extraire le symbole depuis les données ou utiliser un défaut
            symbol = gom_data.get("symbol", "Crash 1000 Index")

            # Parser et envoyer
            payload = parse_verdict(gom_data, symbol)
            if payload:
                # Ajouter les prédictions BB
                bb_mid = float(payload.get("bb_mid", 0.0))
                bb_up = float(payload.get("bb_up", 0.0))
                bb_dn = float(payload.get("bb_dn", 0.0))
                pred = generate_bb_prediction(bb_mid, bb_up, bb_dn, bars_ahead=300)
                payload.update(pred)

                send_verdict(payload)

            time.sleep(10)

        except KeyboardInterrupt:
            log.info("[STOP] Arret")
            break
        except Exception as e:
            log.error(f"[ERROR] {e}")
            time.sleep(10)


if __name__ == "__main__":
    main()
