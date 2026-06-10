#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
GOM Sync + WhatsApp Report — Boucle 10 minutes
Charge gom_signal.json, parse les verdicts, envoie rapport WhatsApp
"""

import json
import time
import os
import sys
import requests
import logging
from datetime import datetime
from pathlib import Path

# Force UTF-8 on Windows
if sys.platform == 'win32':
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding='utf-8')

# Configuration
GOM_FILE = Path("D:/Dev/TradBOT/data/gom_signal.json")
AI_SERVER = "http://127.0.0.1:8000"
LOGS_DIR = Path("D:/Dev/TradBOT/logs")
LOOP_INTERVAL = 600  # 10 minutes en secondes

# Créer le dossier logs s'il n'existe pas
LOGS_DIR.mkdir(exist_ok=True)

# Configuration du logging
log_file = LOGS_DIR / f"gom_sync_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - gom_sync - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8')
    ]
)
logger = logging.getLogger(__name__)

# Ajouter stdout handler sans emojis pour Windows console
class NoEmojiHandler(logging.StreamHandler):
    def emit(self, record):
        msg = record.getMessage()
        msg = msg.replace('🔄', '[SYNC]').replace('✅', '[OK]').replace('❌', '[ERROR]')
        msg = msg.replace('⚠️', '[WARN]').replace('📊', '[REPORT]').replace('📋', '[LOG]')
        msg = msg.replace('📁', '[DIR]').replace('🌐', '[NET]').replace('📤', '[SEND]')
        msg = msg.replace('🚀', '[START]').replace('⏹️', '[STOP]').replace('⏰', '[WAIT]')
        ts = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        print(f"{ts} - {record.levelname} - {msg}")

logger.addHandler(NoEmojiHandler())

# Mapping des emojis
EMOJI_MAP = {
    3: "🟢",    # PERFECT BUY
    2: "🟢",    # GOOD BUY
    1: "🟢",    # BUY
    -1: "🔴",   # SELL
    -2: "🔴",   # GOOD SELL
    -3: "🔴",   # PERFECT SELL
    0: "⚪"     # WAIT
}

# Mapping des actions
ACTION_MAP = {
    3: "PERFECT BUY",
    2: "GOOD BUY",
    1: "BUY",
    -1: "SELL",
    -2: "GOOD SELL",
    -3: "PERFECT SELL",
    0: "WAIT"
}


def load_gom_signals():
    """Charge les verdicts GOM depuis gom_signal.json"""
    try:
        with open(GOM_FILE, 'r', encoding='utf-8') as f:
            data = json.load(f)

        verdicts = []

        # gom_signal.json peut avoir plusieurs formats:
        if isinstance(data, dict):
            # Format 1: {verdicts: [...]}
            if 'verdicts' in data:
                verdicts = data['verdicts']
            # Format 2: {symbol: verdict, symbol: verdict, ...}
            else:
                verdicts = [v for k, v in data.items() if isinstance(v, dict)]
        elif isinstance(data, list):
            # Format 3: Direct list
            verdicts = data

        logger.info(f"[OK] Charge {len(verdicts)} verdicts GOM depuis {GOM_FILE}")
        return verdicts
    except Exception as e:
        logger.error(f"[ERROR] Erreur chargement GOM: {e}")
        return []


def build_report(verdicts):
    """Construit un rapport formaté avec les verdicts actifs"""
    active_verdicts = [v for v in verdicts if v.get('verdict_num', 0) != 0]

    if not active_verdicts:
        logger.warning("⚠️ Aucun verdict actif")
        return None

    lines = []
    lines.append("🎯 **GOM VERDICTS REPORT** 📊")
    lines.append("=" * 50)

    for v in active_verdicts:
        symbol = v.get('symbol', 'N/A')
        verdict_num = v.get('verdict_num', 0)
        entry = v.get('entry', 0)
        sl = v.get('sl', 0)
        tp = v.get('tp', 0)
        gap = v.get('verdict_gap', 0)
        coherence = v.get('coherence_pct', 0)

        emoji = EMOJI_MAP.get(verdict_num, "⚪")
        action = ACTION_MAP.get(verdict_num, "WAIT")

        line = f"{emoji} **{symbol}** — {action}"
        line += f"\n   Entry: {entry:.2f} | SL: {sl:.2f} | TP: {tp:.2f}"
        line += f"\n   Gap: {gap:.2f} | Coherence: {coherence:.0f}%\n"

        lines.append(line)

    lines.append("=" * 50)
    lines.append(f"📅 {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}")

    report = "\n".join(lines)
    logger.info(f"📋 Rapport construit ({len(active_verdicts)} signaux actifs)")
    return report


def send_whatsapp_report(report):
    """Envoie le rapport via WhatsApp (endpoint ai_server)"""
    if not report:
        return False

    try:
        url = f"{AI_SERVER}/notify-whatsapp"
        payload = {"message": report}

        response = requests.post(url, json=payload, timeout=5)

        if response.status_code == 200:
            logger.info(f"✅ Rapport WhatsApp envoyé (HTTP 200)")
            return True
        else:
            logger.warning(f"⚠️ WhatsApp HTTP {response.status_code}: {response.text}")
            return False

    except requests.exceptions.RequestException as e:
        logger.error(f"❌ Erreur WhatsApp: {e}")
        return False


def sync_verdicts_to_ai_server(verdicts):
    """Envoie chaque verdict via POST /gom-verdict à ai_server (optionnel)"""
    try:
        url = f"{AI_SERVER}/gom-verdict"

        for v in verdicts:
            verdict_num = v.get('verdict_num', 0)
            if verdict_num == 0:
                continue  # Skip WAIT signals

            try:
                response = requests.post(url, json=v, timeout=5)
                if response.status_code == 200:
                    symbol = v.get('symbol', 'N/A')
                    action = ACTION_MAP.get(verdict_num, "WAIT")
                    logger.info(f"📤 {symbol} → {action} (HTTP 200)")
                else:
                    logger.debug(f"⚠️ POST /gom-verdict HTTP {response.status_code}")
            except Exception as e:
                logger.debug(f"Erreur sync verdict: {e}")

    except Exception as e:
        logger.error(f"❌ Erreur sync verdicts: {e}")


def main_loop():
    """Boucle principale — exécute toutes les 10 minutes"""
    logger.info("🚀 GOM Sync + WhatsApp Report démarré (10 min loop)")
    logger.info(f"📁 GOM File: {GOM_FILE}")
    logger.info(f"🌐 AI Server: {AI_SERVER}")
    logger.info(f"📋 Logs: {LOGS_DIR}")
    logger.info("=" * 60)

    iteration = 0

    try:
        while True:
            iteration += 1
            logger.info(f"\n[Itération {iteration}] 🔄 Synchronisation GOM...")

            # Charger les verdicts GOM
            verdicts = load_gom_signals()

            if verdicts:
                # Sync to ai_server (optionnel)
                sync_verdicts_to_ai_server(verdicts)

                # Construire et envoyer rapport
                report = build_report(verdicts)
                if report:
                    send_whatsapp_report(report)

            logger.info(f"⏰ Prochain sync dans 10 min ({LOOP_INTERVAL}s)...")
            time.sleep(LOOP_INTERVAL)

    except KeyboardInterrupt:
        logger.info("\n⏹️ Arrêt demandé (Ctrl+C)")
    except Exception as e:
        logger.error(f"❌ Erreur boucle: {e}")


def run_once():
    """Exécute une seule synchronisation (--report)"""
    logger.info("🔄 Exécution unique GOM sync...")

    verdicts = load_gom_signals()

    if verdicts:
        sync_verdicts_to_ai_server(verdicts)
        report = build_report(verdicts)
        if report:
            logger.info("\n📋 RAPPORT:")
            logger.info(report)
            send_whatsapp_report(report)

    logger.info("✅ Exécution unique terminée")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--report":
        # Mode unique
        run_once()
    else:
        # Mode boucle 10 minutes
        main_loop()
