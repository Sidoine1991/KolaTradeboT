#!/usr/bin/env python3
"""
GOM Sync Scheduler — Exécute gom_sync_with_report.py toutes les 10 minutes
"""

import schedule
import time
import subprocess
import logging
from pathlib import Path
from datetime import datetime

# Configuration logging
log_dir = Path("D:/Dev/TradBOT/logs")
log_dir.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - gom_scheduler - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_dir / 'gom_scheduler.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


def run_gom_report():
    """Exécute le rapport GOM"""
    try:
        logger.info("[SCHEDULER] Exécution du rapport GOM...")
        result = subprocess.run(
            ["python", "Python/gom_sync_with_report.py", "--report"],
            cwd="D:/Dev/TradBOT",
            capture_output=True,
            text=True,
            timeout=60
        )

        if result.returncode == 0:
            logger.info("[SCHEDULER] Rapport exécuté avec succès")
        else:
            logger.error(f"[SCHEDULER] Erreur: {result.stderr}")
    except Exception as e:
        logger.error(f"[SCHEDULER] Erreur exécution: {e}")


def main():
    """Boucle principale du scheduler"""
    logger.info("=" * 60)
    logger.info("[START] GOM Scheduler démarré")
    logger.info("[INTERVAL] Rapport toutes les 10 minutes")
    logger.info("=" * 60)

    # Planifier l'exécution toutes les 10 minutes
    schedule.every(10).minutes.do(run_gom_report)

    # Exécuter immédiatement au démarrage
    run_gom_report()

    # Boucle infinie
    try:
        while True:
            schedule.run_pending()
            time.sleep(60)  # Vérifier toutes les 60 secondes
    except KeyboardInterrupt:
        logger.info("[STOP] Scheduler arrêté (Ctrl+C)")


if __name__ == "__main__":
    main()
