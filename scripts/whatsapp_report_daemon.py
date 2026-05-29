#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
WhatsApp Report Daemon — Boucle autonome 20min
Envoie un message WhatsApp unifié toutes les 20 minutes
"""

import os
import sys
import time
import logging
from datetime import datetime, timezone
from pathlib import Path

from whatsapp_unified_report import UnifiedReportGenerator

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - [WhatsApp Daemon] - %(levelname)s - %(message)s'
)
logger = logging.getLogger("whatsapp_daemon")

_root_dir = Path(__file__).resolve().parent.parent
REPORT_INTERVAL = 20 * 60  # 20 minutes en secondes
CHECK_INTERVAL = 5  # Vérifier toutes les 5 sec (pour arrêt propre)


def format_time_until(seconds: int) -> str:
    """Formate le temps restant"""
    mins = seconds // 60
    secs = seconds % 60
    return f"{mins}m{secs:02d}s"


def main():
    """Boucle principale"""
    logger.info("=" * 60)
    logger.info("🚀 WhatsApp Report Daemon démarré")
    logger.info(f"⏰ Intervalle: {REPORT_INTERVAL // 60} minutes")
    logger.info("=" * 60)

    last_report_time = time.time() - REPORT_INTERVAL  # Forcer un rapport au démarrage
    iteration = 0

    try:
        while True:
            current_time = time.time()
            time_since_report = current_time - last_report_time
            time_until_report = REPORT_INTERVAL - time_since_report

            # Afficher le compte à rebours tous les 60 sec
            if int(time_since_report) % 60 == 0 or time_until_report <= 5:
                status_msg = f"⏳ Prochain rapport dans {format_time_until(int(time_until_report))}"
                if time_until_report <= 5:
                    status_msg = f"🔴 Rapport dans {format_time_until(int(time_until_report))}..."
                logger.info(status_msg)

            # Déclencher rapport si intervalle écoulé
            if time_since_report >= REPORT_INTERVAL:
                iteration += 1
                logger.info(f"\n{'='*60}")
                logger.info(f"📊 Rapport #{iteration} — {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}")
                logger.info(f"{'='*60}")

                try:
                    generator = UnifiedReportGenerator(symbol="OANDA:XAUUSD")
                    message = generator.run()

                    # Sauvegarder le dernier rapport
                    report_file = _root_dir / "last_whatsapp_report.txt"
                    with open(report_file, "w", encoding="utf-8") as f:
                        f.write(message)
                    logger.info(f"✅ Rapport #{iteration} généré et sauvegardé")

                except Exception as e:
                    logger.error(f"❌ Erreur rapport: {e}", exc_info=True)

                last_report_time = current_time
                logger.info("")

            # Vérifier l'arrêt tous les N secondes
            time.sleep(CHECK_INTERVAL)

    except KeyboardInterrupt:
        logger.info("\n" + "=" * 60)
        logger.info("🛑 Arrêt du daemon (Ctrl+C)")
        logger.info("=" * 60)
        sys.exit(0)
    except Exception as e:
        logger.error(f"❌ Erreur fatale: {e}", exc_info=True)
        sys.exit(1)


if __name__ == "__main__":
    main()
