#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Sync Loop Daemon — Exécute synchronisation GOM + WhatsApp toutes les 10 minutes
Affiche rapports, logs timestampés, maintient l'historique
"""

import subprocess
import time
import logging
import sys
from datetime import datetime
from pathlib import Path
import io

# Fix UTF-8 encoding on Windows
if sys.platform == 'win32':
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8', errors='replace')

# Setup logging
log_dir = Path("logs")
log_dir.mkdir(exist_ok=True)

# Configure UTF-8 for file handler
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_dir / "gom_sync_daemon.log", encoding='utf-8'),
        logging.StreamHandler()  # Also print to console
    ]
)

log = logging.getLogger("gom_sync_daemon")

def run_gom_sync():
    """Exécute GOM sync une fois"""
    log.info("=" * 60)
    log.info("🟢 DÉMARRAGE GOM SYNC")
    log.info("=" * 60)

    try:
        result = subprocess.run(
            ["python", "Python/gom_sync_with_report.py", "--report"],
            capture_output=True,
            text=True,
            timeout=60
        )

        if result.stdout:
            log.info(result.stdout)
        if result.stderr:
            log.warning(result.stderr)

        if result.returncode == 0:
            log.info("✅ GOM Sync exécuté avec succès")
        else:
            log.error(f"❌ GOM Sync échoué (returncode={result.returncode})")

    except subprocess.TimeoutExpired:
        log.error("❌ GOM Sync timeout (>60s)")
    except Exception as e:
        log.error(f"❌ GOM Sync erreur: {e}")

    log.info("=" * 60)

def main():
    """Boucle principale — Exécute toutes les 10 minutes"""
    log.info("🚀 GOM Sync Daemon STARTED")
    log.info("   Interval: 10 minutes")
    log.info("   Logs: logs/gom_sync_daemon.log")
    log.info("")

    iteration = 0

    try:
        while True:
            iteration += 1
            log.info(f"\n[Iteration #{iteration}] {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

            run_gom_sync()

            # Attendre 10 minutes (600 secondes)
            log.info(f"⏳ Prochaine exécution dans 10 minutes...")
            log.info("")

            for i in range(600, 0, -60):
                time.sleep(60)
                if i > 0:
                    log.debug(f"   {i}s restant...")

    except KeyboardInterrupt:
        log.info("\n⛔ GOM Sync Daemon ARRÊTÉ (Ctrl+C)")
    except Exception as e:
        log.error(f"⛔ GOM Sync Daemon erreur fatale: {e}")

if __name__ == "__main__":
    main()
