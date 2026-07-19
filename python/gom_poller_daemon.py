#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Poller Daemon — Tourne 24/7 en arrière-plan
Met à jour gom_signal.json toutes les 30 secondes
Calcule automatiquement verdict_num, score_buy, score_sell localement
"""
import json
import time
import logging
import sys
from pathlib import Path
from datetime import datetime, timezone

# Fix encoding for Windows
if sys.stdout.encoding != 'utf-8':
    sys.stdout.reconfigure(encoding='utf-8')

# Import local calculator
sys.path.insert(0, str(Path(__file__).parent))
from gom_local_calculator import GOMLocalCalculator

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler("logs/gom_poller_daemon.log", encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(__name__)

GOM_SIGNAL_FILE = Path("data/gom_signal.json")
POLL_INTERVAL = 30  # 30 secondes

def load_gom_data():
    """Charge les données GOM locales."""
    try:
        if GOM_SIGNAL_FILE.exists():
            return json.loads(GOM_SIGNAL_FILE.read_text(encoding="utf-8"))
    except Exception as e:
        log.error(f"Erreur lecture GOM: {e}")
    return {}

def update_timestamp(data):
    """Met à jour les timestamps pour indiquer fraîcheur des données."""
    for sym in data:
        if "timestamp" not in data[sym] or not data[sym]["timestamp"]:
            data[sym]["timestamp"] = datetime.now(timezone.utc).isoformat()
    return data

def calculate_verdicts(data):
    """Calcule les verdicts localement pour tous les symboles."""
    calc = GOMLocalCalculator()
    for symbol in data:
        try:
            record = data[symbol]
            enriched = calc.enrich_record(record)
            data[symbol] = enriched
        except Exception as e:
            log.warning(f"Erreur calcul {symbol}: {e}")
    return data

def main():
    """Boucle principale du poller."""
    log.info("=" * 70)
    log.info("🚀 GOM Poller Daemon démarré")
    log.info(f"   Interval: {POLL_INTERVAL}s")
    log.info(f"   Fichier: {GOM_SIGNAL_FILE}")
    log.info("=" * 70)

    cycle = 0
    while True:
        cycle += 1
        try:
            # Charger GOM
            data = load_gom_data()

            if not data:
                log.warning(f"⚠️  Cycle #{cycle}: Aucune donnée GOM")
                time.sleep(POLL_INTERVAL)
                continue

            # Mettre à jour timestamps
            data = update_timestamp(data)

            # Calculer les verdicts localement
            data = calculate_verdicts(data)

            # Sauvegarder
            GOM_SIGNAL_FILE.write_text(json.dumps(data, indent=2, ensure_ascii=False))

            # Log résumé
            buy_count = sum(1 for s in data if data[s].get("verdict_num", 0) > 0)
            sell_count = sum(1 for s in data if data[s].get("verdict_num", 0) < 0)
            wait_count = sum(1 for s in data if data[s].get("verdict_num", 0) == 0)

            log.info(f"✅ Cycle #{cycle} — BUY:{buy_count} SELL:{sell_count} WAIT:{wait_count} ({len(data)} total)")

            time.sleep(POLL_INTERVAL)

        except KeyboardInterrupt:
            log.info("\n⏹  Arrêt utilisateur")
            break
        except Exception as e:
            log.error(f"❌ Erreur cycle: {e}")
            time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    main()
