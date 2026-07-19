#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Sync Scheduler — Exécute gom_sync_with_report.py --report toutes les 10 minutes
Avec logging complet, timestamps, et gestion d'erreurs
"""

import subprocess
import time
import os
import sys
import logging
from datetime import datetime
from pathlib import Path

# Force UTF-8 on Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Configuration
TRADBOT_ROOT = Path("D:/Dev/TradBOT")
GOM_SYNC_SCRIPT = TRADBOT_ROOT / "Python" / "gom_sync_with_report.py"
LOGS_DIR = TRADBOT_ROOT / "logs"
LOOP_INTERVAL = 600  # 10 minutes en secondes

# Créer le dossier logs
LOGS_DIR.mkdir(parents=True, exist_ok=True)

# Configuration du logging
log_file = LOGS_DIR / "gom_sync_scheduler.log"
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s [%(levelname)s] %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8', mode='a'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)


def run_gom_sync():
    """Exécute gom_sync_with_report.py --report une fois"""
    try:
        logger.info("=" * 70)
        logger.info("🔄 Exécution: gom_sync_with_report.py --report")
        logger.info("=" * 70)

        # Lancer le script
        result = subprocess.run(
            [sys.executable, str(GOM_SYNC_SCRIPT), "--report"],
            cwd=str(TRADBOT_ROOT),
            capture_output=True,
            text=True,
            timeout=120  # Timeout 2 minutes max
        )

        # Afficher stdout
        if result.stdout:
            for line in result.stdout.split('\n'):
                if line.strip():
                    logger.info(f"[GOM] {line}")

        # Afficher stderr
        if result.stderr:
            for line in result.stderr.split('\n'):
                if line.strip():
                    logger.warning(f"[GOM-ERR] {line}")

        # Vérifier return code
        if result.returncode == 0:
            logger.info("✅ Exécution réussie (return code 0)")
            return True
        else:
            logger.error(f"❌ Exécution échouée (return code {result.returncode})")
            return False

    except subprocess.TimeoutExpired:
        logger.error("❌ Timeout — gom_sync_with_report.py a dépassé 120 secondes")
        return False
    except FileNotFoundError:
        logger.error(f"❌ Script non trouvé: {GOM_SYNC_SCRIPT}")
        return False
    except Exception as e:
        logger.error(f"❌ Erreur lors de l'exécution: {e}")
        return False


def scheduler_loop():
    """Boucle principale — exécute toutes les 10 minutes"""
    logger.info("=" * 70)
    logger.info("🚀 GOM SYNC SCHEDULER DÉMARRÉ")
    logger.info("=" * 70)
    logger.info(f"📁 Root: {TRADBOT_ROOT}")
    logger.info(f"📄 Script: {GOM_SYNC_SCRIPT}")
    logger.info(f"📊 Logs: {LOGS_DIR}")
    logger.info(f"⏰ Intervalle: {LOOP_INTERVAL}s (10 min)")
    logger.info("=" * 70)
    logger.info("")

    iteration = 0
    consecutive_errors = 0
    max_consecutive_errors = 5

    try:
        while True:
            iteration += 1
            ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')
            logger.info(f"[Itération {iteration}] {ts} — Démarrage synchronisation...")

            # Exécuter gom_sync
            success = run_gom_sync()

            if success:
                consecutive_errors = 0
            else:
                consecutive_errors += 1
                if consecutive_errors >= max_consecutive_errors:
                    logger.error(f"❌ {consecutive_errors} erreurs consécutives — arrêt")
                    break

            # Attendre 10 minutes
            logger.info(f"⏰ Prochain sync dans 10 minutes ({LOOP_INTERVAL}s)...")
            logger.info("")

            for i in range(LOOP_INTERVAL):
                if i % 60 == 0:  # Log toutes les minutes
                    remaining = LOOP_INTERVAL - i
                    logger.debug(f"  [{remaining}s restants]")
                time.sleep(1)

    except KeyboardInterrupt:
        logger.info("\n⏹️ Arrêt demandé (Ctrl+C)")
        logger.info("=" * 70)
    except Exception as e:
        logger.error(f"❌ Erreur critique: {e}")
        logger.error("=" * 70)


def run_once():
    """Mode unique — exécute une fois et quitte"""
    logger.info("=" * 70)
    logger.info("🔄 MODE UNIQUE — Exécution une seule fois")
    logger.info("=" * 70)

    success = run_gom_sync()

    logger.info("=" * 70)
    if success:
        logger.info("✅ Exécution unique terminée avec succès")
    else:
        logger.error("❌ Exécution unique échouée")
    logger.info("=" * 70)

    return 0 if success else 1


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="GOM Sync Scheduler — 10 minutes loop")
    parser.add_argument("--once", action="store_true", help="Exécuter une seule fois et quitter")
    parser.add_argument("--interval", type=int, default=600, help="Intervalle en secondes (défaut 600=10min)")
    args = parser.parse_args()

    if args.interval > 0:
        LOOP_INTERVAL = args.interval

    if args.once:
        sys.exit(run_once())
    else:
        scheduler_loop()
