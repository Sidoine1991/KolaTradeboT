#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Refresh Loop — Force recalcul dashboard toutes les 5 minutes pour tous les symboles actifs.
Lance ce script en parallèle du pipeline pour garder les verdicts frais.
"""

import sys
import time
import logging
import requests
from datetime import datetime
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOGS_DIR = ROOT / "logs"
LOGS_DIR.mkdir(exist_ok=True)

AI_SERVER = "http://127.0.0.1:8000"
REFRESH_INTERVAL = 300  # 5 minutes

SYMBOLS = [
    "XAUUSD",
    "BOOM 1000 INDEX",
    "BOOM 500 INDEX",
    "BOOM 300 INDEX",
    "CRASH 1000 INDEX",
    "CRASH 500 INDEX",
    "CRASH 300 INDEX",
]

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOGS_DIR / "gom_refresh.log", encoding="utf-8", mode="a"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger(__name__)


def refresh_symbol(symbol: str) -> dict:
    """Force le recalcul du dashboard GOM pour un symbole."""
    try:
        resp = requests.get(
            f"{AI_SERVER}/gom-kola-dashboard",
            params={"symbol": symbol, "force_refresh": "true"},
            timeout=10,
        )
        if resp.status_code == 200:
            d = resp.json()
            verdict = d.get("verdict", "?")
            vnum = d.get("verdict_num", 0)
            coh = d.get("coherence_pct", 0)
            m1 = d.get("tf_m1_dir", "?")
            h4 = d.get("tf_h4_dir", "?")
            ts = d.get("timestamp", "")[:19]
            log.info(f"  {symbol:25s} | {verdict:15s} vnum={vnum:+d} | coh={coh:.0f}% | M1={m1} H4={h4} | ts={ts}")
            return d
        else:
            log.warning(f"  {symbol}: HTTP {resp.status_code}")
            return {}
    except Exception as e:
        log.warning(f"  {symbol}: erreur {e}")
        return {}


def refresh_all():
    """Rafraîchit tous les symboles et log un résumé."""
    log.info(f"=== GOM REFRESH {datetime.utcnow().strftime('%H:%M:%S')} UTC ===")
    results = {}
    for sym in SYMBOLS:
        d = refresh_symbol(sym)
        if d:
            results[sym] = d
    actifs = [(s, d["verdict"], d.get("coherence_pct", 0))
              for s, d in results.items() if d.get("verdict_num", 0) != 0]
    if actifs:
        log.info(f"  Signaux actifs ({len(actifs)}): " +
                 ", ".join(f"{s}={v}({c:.0f}%)" for s, v, c in actifs))
    else:
        log.info("  Aucun signal actif — tous WAIT")
    return results


def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--once", action="store_true", help="Un seul refresh")
    parser.add_argument("--interval", type=int, default=REFRESH_INTERVAL,
                        help="Intervalle en secondes (défaut: 300)")
    args = parser.parse_args()

    if args.once:
        refresh_all()
        return

    log.info(f"GOM Refresh Loop démarré — intervalle {args.interval}s")
    while True:
        refresh_all()
        log.info(f"  Prochain refresh dans {args.interval}s...")
        time.sleep(args.interval)


if __name__ == "__main__":
    main()
