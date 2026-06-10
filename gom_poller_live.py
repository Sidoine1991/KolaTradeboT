#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Live Poller — Lecture directe depuis TradingView MCP
=========================================================
Boucle continue qui :
1. Lance data_get_study_values via MCP (equivalent Claude Code)
2. Parse les valeurs GOM (incluant les nouvelles: tf_m1_dir, tf_m5_dir, tf_m15_dir, tf_h1_dir)
3. Envoie au /gom-verdict endpoint

Utilise Anthropic SDK pour accéder aux MCP tools.
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
    format="%(asctime)s [GOM-POLLER] %(message)s",
    handlers=[
        logging.StreamHandler(sys.stdout),
        logging.FileHandler(LOG_DIR / "gom_poller_live.log", encoding='utf-8'),
    ],
)
log = logging.getLogger()

API = "http://127.0.0.1:8000"

# Mapping: d1/d2/d3/d4 → timeframe names
TF_MAP = {
    "tf_m1_dir": "M1",
    "tf_m5_dir": "M5",
    "tf_m15_dir": "M15",
    "tf_h1_dir": "H1",
}


def call_mcp_data_get_study_values():
    """
    Appelle mcp__tradingview-kola__data_get_study_values via Claude Code CLI
    Retourne le dict 'values' depuis la réponse.
    """
    try:
        # Lance `claude code` pour exécuter l'outil MCP
        cmd = [
            "claude",
            "code",
            "run",
            "--mcp-call",
            "mcp__tradingview-kola__data_get_study_values"
        ]

        result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)

        if result.returncode != 0:
            log.warning(f"MCP call failed: {result.stderr[:200]}")
            return None

        # Parse la réponse JSON
        output = result.stdout.strip()
        if not output:
            log.warning("MCP call returned empty output")
            return None

        # Cherche le JSON dans la sortie
        try:
            data = json.loads(output)
            if "studies" in data and len(data["studies"]) > 0:
                return data["studies"][0].get("values", {})
        except json.JSONDecodeError:
            # Fallback: utiliser le fichier JSON existant
            try:
                values_file = Path(__file__).parent / "data" / "gom_values.json"
                if values_file.exists():
                    file_data = json.loads(values_file.read_text(encoding="utf-8"))
                    return file_data.get("values", {})
            except:
                pass

        return None
    except subprocess.TimeoutExpired:
        log.warning("MCP call timed out (15s)")
        return None
    except Exception as e:
        log.warning(f"MCP call error: {e}")
        return None


def to_float(s):
    """Convertit string (potentially with spaces/commas) to float."""
    if isinstance(s, str):
        s = s.replace(" ", "").replace(",", ".")
    try:
        return float(s) if s else 0.0
    except (ValueError, TypeError):
        return 0.0


def parse_verdict(gom_data: dict, symbol: str = "CRASH_1000") -> dict:
    """Parse les données GOM en verdict complet."""

    def verdict_name(vnum):
        if vnum >= 3:
            return "STRONG BUY"
        elif vnum >= 1:
            return "BUY"
        elif vnum <= -3:
            return "STRONG SELL"
        elif vnum <= -1:
            return "SELL"
        else:
            return "WAIT"

    verdict_num = to_float(gom_data.get("verdict_num", "0"))
    verdict = verdict_name(verdict_num)

    # Récupère les tendances par timeframe (nouvelles plots)
    tf_directions = {}
    for key, tf_name in TF_MAP.items():
        tf_dir_raw = to_float(gom_data.get(key, "0"))
        tf_directions[tf_name] = int(tf_dir_raw)

    return {
        "symbol": symbol,
        "verdict": verdict,
        "verdict_num": int(verdict_num),
        "score_buy": str(to_float(gom_data.get("score_buy", "0"))),
        "score_sell": str(to_float(gom_data.get("score_sell", "0"))),
        "spike_pct": str(to_float(gom_data.get("spike_pct", "0"))),
        "rsi": str(to_float(gom_data.get("rsi", "50"))),
        "entry_quality": str(to_float(gom_data.get("entry_quality", "0"))),
        "coherence_pct": str(to_float(gom_data.get("coherence_pct", "0"))),
        "vwap": str(to_float(gom_data.get("vwap", "0"))),
        "bb_up": str(to_float(gom_data.get("bb_up", "0"))),
        "bb_mid": str(to_float(gom_data.get("bb_mid", "0"))),
        "bb_dn": str(to_float(gom_data.get("bb_dn", "0"))),
        "st_line": str(to_float(gom_data.get("st_line", "0"))),
        "st_dir": str(int(to_float(gom_data.get("st_dir", "0")))),
        "kola_buy": str(to_float(gom_data.get("kola_buy", "0"))),
        "kola_sell": str(to_float(gom_data.get("kola_sell", "0"))),
        "tf_global_dir": str(int(to_float(gom_data.get("tf_global_dir", "0")))),
        "tf_global_strength": str(int(to_float(gom_data.get("tf_global_strength", "0")))),
        "tf_bull_count": str(int(to_float(gom_data.get("tf_bull_count", "0")))),
        "tf_bear_count": str(int(to_float(gom_data.get("tf_bear_count", "0")))),
        "tf_directions": tf_directions,  # NEW: M1, M5, M15, H1 individuelles
        "setup_dir": str(int(to_float(gom_data.get("setup_dir", "0")))),
        "setup_entry": str(to_float(gom_data.get("setup_entry", "0"))),
        "setup_sl": str(to_float(gom_data.get("setup_sl", "0"))),
        "setup_tp1": str(to_float(gom_data.get("setup_tp1", "0"))),
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
                f"✅ {payload['symbol']} → {payload['verdict']} "
                f"| TF: M1={payload['tf_directions'].get('M1','?')} "
                f"M5={payload['tf_directions'].get('M5','?')} "
                f"M15={payload['tf_directions'].get('M15','?')} "
                f"H1={payload['tf_directions'].get('H1','?')}"
            )
            return True
        else:
            log.warning(f"❌ POST {resp.status_code}: {resp.text[:100]}")
            return False
    except Exception as e:
        log.warning(f"send_verdict error: {e}")
        return False


def main():
    log.info("=" * 70)
    log.info("GOM Live Poller — TradingView MCP Integration")
    log.info("=" * 70)
    log.info("Polling TradingView GOM study values every 10 seconds...")
    log.info("")

    poll_interval = 10
    fail_count = 0

    while True:
        try:
            # 1. Lire les valeurs depuis TradingView
            gom_data = call_mcp_data_get_study_values()

            if not gom_data:
                fail_count += 1
                if fail_count % 6 == 0:  # Log tous les 60s
                    log.warning(f"[WAIT] No GOM data yet... (attempts: {fail_count})")
                time.sleep(poll_interval)
                continue

            fail_count = 0

            # 2. Parser le verdict
            payload = parse_verdict(gom_data, "CRASH_1000")

            # 3. Envoyer à l'API
            send_verdict(payload)

            time.sleep(poll_interval)

        except KeyboardInterrupt:
            log.info("Arrêt du poller.")
            break
        except Exception as e:
            log.error(f"Main loop error: {e}")
            time.sleep(poll_interval)


if __name__ == "__main__":
    main()
